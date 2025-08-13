-- Dash and slide abilities

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
local Animations = require(game:GetService("ReplicatedStorage").Movement.Animations)

local Abilities = {}

local lastDashTick = 0
local lastSlideTick = 0
local originalPhysByPart = {}

local function getCharacterParts(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function setCharacterFriction(character, friction, frictionWeight)
	originalPhysByPart[character] = originalPhysByPart[character] or {}
	local store = originalPhysByPart[character]
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			if store[part] == nil then
				store[part] = part.CustomPhysicalProperties
			end
			local current = part.CustomPhysicalProperties
			local density = current and current.Density or 1
			local elasticity = current and current.Elasticity or 0
			local elasticityWeight = current and current.ElasticityWeight or 0
			part.CustomPhysicalProperties =
				PhysicalProperties.new(density, friction, elasticity, frictionWeight, elasticityWeight)
		end
	end
end

local function restoreCharacterFriction(character)
	local store = originalPhysByPart[character]
	if not store then
		return
	end
	for part, phys in pairs(store) do
		if part and part:IsA("BasePart") then
			part.CustomPhysicalProperties = phys
		end
	end
	originalPhysByPart[character] = nil
end

function Abilities.isDashReady()
	local now = os.clock()
	return (now - lastDashTick) >= Config.DashCooldownSeconds
end

function Abilities.isSlideReady()
	local now = os.clock()
	return (now - lastSlideTick) >= (Config.SlideCooldownSeconds or 0)
end

function Abilities.tryDash(character)
	local now = os.clock()
	if now - lastDashTick < Config.DashCooldownSeconds then
		return false
	end

	local rootPart, humanoid = getCharacterParts(character)
	if not rootPart or not humanoid then
		return false
	end

	lastDashTick = now

	-- Ground dash: set a target horizontal velocity and zero vertical velocity to ignore gravity
	local moveDir = (humanoid.MoveDirection.Magnitude > 0.05) and humanoid.MoveDirection or rootPart.CFrame.LookVector
	moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
	if moveDir.Magnitude < 0.05 then
		moveDir = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	end
	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
	end

	-- Completamente horizontal, sin componente vertical (ignorando la gravedad)
	local desiredHorizontal = moveDir * Config.DashSpeed
	local desiredVel = Vector3.new(desiredHorizontal.X, 0, desiredHorizontal.Z)
	rootPart.AssemblyLinearVelocity = desiredVel

	-- Play dash animation if available (uses preloaded cache if present)
	do
		local humanoid = humanoid
		local animInst = Animations and Animations.get and Animations.get("Dash")
		if humanoid and animInst then
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid
			local track = nil
			pcall(function()
				track = animator:LoadAnimation(animInst)
			end)
			if track then
				track.Priority = Enum.AnimationPriority.Action
				-- Match animation playback to dash duration if possible
				local playbackSpeed = 1.0
				local dashDur = Config.DashDurationSeconds or 0
				local length = 0
				pcall(function()
					length = track.Length or 0
				end)
				if dashDur > 0 and length > 0 then
					playbackSpeed = length / dashDur
				end
				track.Looped = false
				track.TimePosition = 0
				track:Play(0.05, 1, playbackSpeed)
				task.delay(Config.DashDurationSeconds + 0.25, function()
					pcall(function()
						track:Stop(0.1)
					end)
				end)
			end
		end
	end

	-- Guardar el estado original de las propiedades de física y configurar el personaje
	local originalAutoRotate = humanoid.AutoRotate
	-- Temporarily reduce friction to 0 on all character parts to achieve consistent ground dash
	setCharacterFriction(character, 0, 0)
	humanoid.AutoRotate = false

	-- Desactivar temporalmente la gravedad configurando un estado especial para el humanoid
	local originalState = humanoid:GetState()
	humanoid:ChangeState(Enum.HumanoidStateType.Physics) -- Este estado nos permite tener control completo sobre la física

	local stillValid = true
	task.delay(Config.DashDurationSeconds, function()
		stillValid = false
		humanoid.AutoRotate = originalAutoRotate
		restoreCharacterFriction(character)

		-- Restaurar el comportamiento normal de la gravedad después del dash
		if humanoid and humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end)

	-- Actualizar constantemente la velocidad durante el dash para mantener el movimiento perfectamente horizontal
	task.spawn(function()
		local t0 = os.clock()
		while stillValid and (os.clock() - t0) < Config.DashDurationSeconds do
			rootPart.AssemblyLinearVelocity = desiredVel -- Mantener velocidad horizontal constante sin componente vertical
			task.wait()
		end
	end)

	return true
end

function Abilities.slide(character)
	local now = os.clock()
	if (now - lastSlideTick) < (Config.SlideCooldownSeconds or 0) then
		return function() end
	end
	local rootPart, humanoid = getCharacterParts(character)
	if not rootPart or not humanoid then
		return function() end
	end

	local originalWalkSpeed = humanoid.WalkSpeed
	local originalHipHeight = humanoid.HipHeight

	humanoid.WalkSpeed = originalWalkSpeed + Config.SlideSpeedBoost
	humanoid.HipHeight = math.max(0, originalHipHeight + Config.SlideHipHeightDelta)

	-- Optional slide animations: Start -> Loop -> End
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local startId = Animations and Animations.SlideStart or ""
	local loopId = Animations and Animations.SlideLoop or ""
	local endId = Animations and Animations.SlideEnd or ""
	local startTrack, loopTrack

	local function playTrack(id, looped)
		if not id or id == "" then
			return nil
		end
		local anim
		if Animations and Animations.get then
			-- Find the configured key that matches this id to reuse cached instances
			for key, value in pairs(Animations) do
				if type(value) == "string" and value == id then
					anim = Animations.get(key)
					break
				end
			end
		end
		if not anim then
			anim = Instance.new("Animation")
			anim.AnimationId = id
		end
		local track
		pcall(function()
			track = animator:LoadAnimation(anim)
		end)
		if not track then
			return nil
		end
		track.Priority = Enum.AnimationPriority.Movement
		track.Looped = looped and true or false
		track:Play(0.05, 1, 1.0)
		return track
	end

	-- Play Start then Loop (if provided). If only Start exists, it will play once.
	if startId ~= "" then
		startTrack = playTrack(startId, false)
		if startTrack and loopId ~= "" then
			-- When start ends, begin loop
			startTrack.Stopped:Connect(function()
				if loopTrack == nil then
					loopTrack = playTrack(loopId, true)
				end
			end)
		end
	elseif loopId ~= "" then
		loopTrack = playTrack(loopId, true)
	end

	local endSlide = function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalWalkSpeed
			humanoid.HipHeight = originalHipHeight
		end
		-- Stop loop and optionally play end
		if startTrack then
			pcall(function()
				startTrack:Stop(0.05)
			end)
		end
		if loopTrack then
			pcall(function()
				loopTrack:Stop(0.05)
			end)
			loopTrack = nil
		end
		if endId ~= "" then
			playTrack(endId, false)
		end
	end

	lastSlideTick = now
	task.delay(Config.SlideDurationSeconds, endSlide)
	return endSlide
end

return Abilities
