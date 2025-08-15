-- Dash and slide abilities

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
local Animations = require(game:GetService("ReplicatedStorage").Movement.Animations)

local Abilities = {}

local lastDashTick = 0
local lastSlideTick = 0
local lastVaultTick = 0
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

-- Vault helpers
local function raycastForward(root, distance)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent }
	params.IgnoreWater = true
	local origin = root.Position + Vector3.new(0, (root.Size and root.Size.Y or 2) * 0.25, 0)
	return workspace:Raycast(origin, root.CFrame.LookVector * distance, params)
end

local function isVaultCandidate(root, humanoid)
	if not (Config.VaultEnabled ~= false) then
		return false
	end
	if humanoid.WalkSpeed < (Config.VaultMinSpeed or 24) then
		return false
	end
	local res = raycastForward(root, Config.VaultDetectionDistance or 4.5)
	if not res or not res.Instance then
		return false
	end
	local hit = res.Instance
	if not hit.CanCollide then
		return false
	end
	local feetY = root.Position.Y - ((root.Size and root.Size.Y or 2) * 0.5)
	local topY = res.Position.Y
	local h = topY - feetY
	local minH = Config.VaultMinHeight or 1.0
	local maxH = Config.VaultMaxHeight or 4.0
	if h < minH or h > maxH then
		return false
	end
	return true, res
end

local function pickVaultAnimation()
	local keys = Config.VaultAnimationKeys or {}
	if #keys == 0 then
		return nil
	end
	local idx = math.random(1, #keys)
	local key = keys[idx]
	return Animations and Animations.get and Animations.get(key) or nil
end

-- Collision toggling for vault
local originalCollisionByPart = {}

local function disableCharacterCollision(character)
	originalCollisionByPart[character] = originalCollisionByPart[character] or {}
	local store = originalCollisionByPart[character]
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			if store[part] == nil then
				store[part] = part.CanCollide
			end
			part.CanCollide = false
		end
	end
end

local function restoreCharacterCollision(character)
	local store = originalCollisionByPart[character]
	if not store then
		return
	end
	for part, prev in pairs(store) do
		if part and part:IsA("BasePart") then
			part.CanCollide = prev
		end
	end
	originalCollisionByPart[character] = nil
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

	--Completely horizontal, without vertical component (ignoring gravity)
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

	-- Save the original status of physics properties and configure the character
	local originalAutoRotate = humanoid.AutoRotate
	-- Temporarily reduce friction to 0 on all character parts to achieve consistent ground dash
	setCharacterFriction(character, 0, 0)
	humanoid.AutoRotate = false

	-- Temporarily disable gravity by configuring a special state for humans
	local originalState = humanoid:GetState()
	humanoid:ChangeState(Enum.HumanoidStateType.Physics) -- This state allows us to have complete control over physics

	local stillValid = true
	task.delay(Config.DashDurationSeconds, function()
		stillValid = false
		humanoid.AutoRotate = originalAutoRotate
		restoreCharacterFriction(character)

		-- Restore the normal behavior of gravity after Dash
		if humanoid and humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end)

	-- Constantly update the speed during the Dash to maintain the perfectly horizontal movement
	task.spawn(function()
		local t0 = os.clock()
		while stillValid and (os.clock() - t0) < Config.DashDurationSeconds do
			rootPart.AssemblyLinearVelocity = desiredVel -- Maintain constant horizontal speed without vertical component
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

local function getParts(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

-- Compute the world-space top Y of an obstacle (single part or model) using its bounding box
local function computeObstacleTopY(inst)
	if inst and inst:IsA("BasePart") then
		local cf = inst.CFrame
		local size = inst.Size
		local topWorld = cf.Position + (cf.UpVector * (size.Y * 0.5))
		return topWorld.Y
	end
	-- Fallback: if not a BasePart, use position Y
	return (inst and inst.Position and inst.Position.Y) or 0
end

local function sampleObstacleTopY(root, distance)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent }
	params.IgnoreWater = true
	local samples = Config.VaultSampleHeights or { 0.15, 0.35, 0.55, 0.75, 0.9 }
	local bestY = nil
	local bestRes = nil
	-- Try a fan of yaw offsets to be tolerant to small aim misalignments
	local yawOffsets = { 0, math.rad(12), -math.rad(12), math.rad(22), -math.rad(22) }
	for _, frac in ipairs(samples) do
		for _, yaw in ipairs(yawOffsets) do
			local dir = (
				CFrame.fromMatrix(Vector3.new(), root.CFrame.XVector, root.CFrame.YVector, root.CFrame.ZVector)
				* CFrame.Angles(0, yaw, 0)
			).LookVector
			-- If player is too close, ray from slightly behind the root to avoid starting inside the obstacle
			local backOffset = dir * -0.8
			local origin = root.Position + Vector3.new(0, (root.Size and root.Size.Y or 2) * frac, 0) + backOffset
			local res = workspace:Raycast(origin, dir * (distance + 0.8), params)
			if res and res.Instance then
				local topY = computeObstacleTopY(res.Instance)
				if (not bestY) or (topY > bestY) then
					bestY = topY
					bestRes = res
				end
			end
		end
	end
	return bestY, bestRes
end

-- Three-ray detector: feet, mid, and head
local function detectObstacleWithThreeRays(root, distance)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent }
	params.IgnoreWater = true

	local halfH = (root.Size and root.Size.Y or 2) * 0.5
	local look = root.CFrame.LookVector
	local back = -look

	local points = {
		{ name = "feet", pos = root.Position + Vector3.new(0, -halfH + 0.1, 0) },
		{ name = "mid", pos = root.Position },
		{ name = "head", pos = root.Position + Vector3.new(0, halfH - 0.1, 0) },
	}

	for _, p in ipairs(points) do
		local origin = p.pos + back * 0.6
		local res = workspace:Raycast(origin, look * (distance + 0.6), params)
		if res and res.Instance then
			local topY = computeObstacleTopY(res.Instance)
			return topY, res
		end
	end

	return nil, nil
end

-- Fallback detection using a box overlap directly in front of the root (helps when rays start inside the wall)
local function boxDetectFrontTopY(root, distance)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { root.Parent }
	overlap.RespectCanCollide = false
	local forward = root.CFrame.LookVector
	local height = (root.Size and root.Size.Y or 2)
	local center = root.CFrame * CFrame.new(0, 0, math.clamp(distance * 0.5, 0.75, distance))
	local size = Vector3.new(3.0, height * 1.3, math.max(2.0, distance + 0.5))
	local parts = workspace:GetPartBoundsInBox(center, size, overlap)
	local bestY, bestPart = nil, nil
	for _, p in ipairs(parts) do
		if p then
			-- Keep only parts that are generally in front of us
			local toPart = (p.Position - root.Position)
			if toPart:Dot(forward) > 0 then
				local topY = computeObstacleTopY(p)
				if (not bestY) or (topY > bestY) then
					bestY = topY
					bestPart = p
				end
			end
		end
	end
	if bestPart then
		return bestY, { Instance = bestPart, Position = bestPart.Position, Normal = -forward }
	end
	return nil, nil
end

local function isVaultCandidate(root, humanoid)
	if not (Config.VaultEnabled ~= false) then
		return false
	end
	if humanoid.WalkSpeed < (Config.VaultMinSpeed or 24) then
		return false
	end
	-- Primary detector: explicit feet/mid/head rays
	local topY, res = detectObstacleWithThreeRays(root, Config.VaultDetectionDistance or 4.5)
	if not res or not res.Instance or not topY then
		-- Secondary: widen with multi-sample ray fan
		topY, res = sampleObstacleTopY(root, Config.VaultDetectionDistance or 4.5)
	end
	if not res or not res.Instance or not topY then
		-- Fallback: box overlap front detection
		local topY2, res2 = boxDetectFrontTopY(root, Config.VaultDetectionDistance or 4.5)
		if not res2 or not res2.Instance or not topY2 then
			-- Fallback 2: recent touched collidable part from client state (handles CanQuery=false)
			local folder = game:GetService("ReplicatedStorage"):FindFirstChild("ClientState")
			local partVal = folder and folder:FindFirstChild("VaultTouchPart")
			local timeVal = folder and folder:FindFirstChild("VaultTouchTime")
			local posVal = folder and folder:FindFirstChild("VaultTouchPos")
			local touchedPart = partVal and partVal.Value or nil
			local touchedWhen = timeVal and timeVal.Value or 0
			local touchedPos = posVal and posVal.Value or nil
			local recent = touchedPart and ((os.clock() - touchedWhen) < 0.35)
			if recent and touchedPart and touchedPart.Parent and touchedPart.CanCollide then
				local topY3 = computeObstacleTopY(touchedPart)
				local res3 = {
					Instance = touchedPart,
					Position = touchedPos or touchedPart.Position,
					Normal = -root.CFrame.LookVector,
				}
				topY, res = topY3, res3
			else
				return false
			end
		else
			topY, res = topY2, res2
		end
	end
	local hit = res.Instance
	-- Attribute check: only block if attribute explicitly set to false; missing or true are allowed
	local function getVaultAttr(inst)
		local cur = inst
		for _ = 1, 4 do
			if not cur then
				break
			end
			if typeof(cur.GetAttribute) == "function" then
				local val = cur:GetAttribute("Vault")
				if val ~= nil then
					return val
				end
			end
			cur = cur.Parent
		end
		return nil
	end
	local vattr = getVaultAttr(hit)
	if vattr == false then
		return false
	end
	if not hit.CanCollide then
		return false
	end
	local feetY = root.Position.Y - ((root.Size and root.Size.Y or 2) * 0.5)
	local h = topY - feetY
	local minH = Config.VaultMinHeight or 1.0
	local maxH = Config.VaultMaxHeight or 4.0
	if h < minH or h > maxH then
		return false
	end
	-- Always log a concise candidate line for troubleshooting high obstacles
	local spd = humanoid and humanoid.WalkSpeed or 0
	return true, res, topY
end

local function pickVaultAnimation()
	local keys = Config.VaultAnimationKeys or {}
	if #keys == 0 then
		return nil
	end
	local idx = math.random(1, #keys)
	local key = keys[idx]
	return Animations and Animations.get and Animations.get(key) or nil
end

function Abilities.tryVault(character)
	local now = os.clock()
	if (now - lastVaultTick) < (Config.VaultCooldownSeconds or 0.6) then
		return false
	end
	local root, humanoid = getParts(character)
	if not root or not humanoid then
		return false
	end
	local ok, res, topY = isVaultCandidate(root, humanoid)
	if not ok then
		return false
	end
	lastVaultTick = now

	-- Dynamic clearance: compute Y velocity so that current position will rise above topY + clearance
	local clearance = Config.VaultClearanceStuds or 1.5
	local desiredY = topY + clearance
	local curY = root.Position.Y
	local needUp = math.max(0, desiredY - curY)
	-- Physics-based vertical speed: v = sqrt(2 * g * height)
	local g = workspace and workspace.Gravity or 196.2
	local requiredUp = math.sqrt(math.max(0, 2 * g * needUp))
	local upMin = Config.VaultUpMin or 8
	local upMax = Config.VaultUpMax -- optional cap
	local upV = math.max(requiredUp, upMin)
	-- If a cap exists but is below the physics requirement, prefer the requirement to ensure clearance
	local forwardBase = (Config.VaultForwardBoost or 26)
	local forwardGain = (Config.VaultForwardGainPerHeight or 2.5) * needUp
	local forward = root.CFrame.LookVector * (forwardBase + forwardGain)
	local up = Vector3.new(0, upV, 0)
	root.AssemblyLinearVelocity = Vector3.new(forward.X, up.Y, forward.Z)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	-- Disable collisions during vault to ensure smooth pass-through
	disableCharacterCollision(character)

	-- Also disable collision/touch on the obstacle locally so this client never collides during vault
	local obstaclePart = res.Instance
	local obstaclePrevCanCollide
	local obstaclePrevCanTouch
	local obstaclePrevByPart = {}
	local obstacleParts = {}
	local function gatherObstacleParts(inst)
		local node = inst
		local model = nil
		for _ = 1, 5 do
			if not node then
				break
			end
			if node:IsA("Model") then
				model = node
				break
			end
			node = node.Parent
		end
		if model then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					table.insert(obstacleParts, d)
				end
			end
		else
			if inst and inst:IsA("BasePart") then
				table.insert(obstacleParts, inst)
			end
		end
	end
	gatherObstacleParts(obstaclePart)
	pcall(function()
		-- Keep single-part fields for backward compatibility
		if obstaclePart then
			obstaclePrevCanCollide = obstaclePart.CanCollide
			obstaclePrevCanTouch = obstaclePart.CanTouch
		end
		for _, p in ipairs(obstacleParts) do
			obstaclePrevByPart[p] = { collide = p.CanCollide, touch = p.CanTouch }
			p.CanCollide = false
			p.CanTouch = false
		end
	end)

	-- Maintain a consistent horizontal velocity during the vault to guarantee clearing the obstacle
	local horizontalVel = Vector3.new(forward.X, 0, forward.Z)
	local stillVaulting = true
	task.spawn(function()
		local t0 = os.clock()
		local dur = Config.VaultDurationSeconds or 0.35
		while stillVaulting and (os.clock() - t0) < dur do
			-- keep horizontal speed; let vertical be driven by physics/retargeting
			local vy = root.AssemblyLinearVelocity.Y
			root.AssemblyLinearVelocity = Vector3.new(horizontalVel.X, vy, horizontalVel.Z)
			task.wait()
		end
	end)

	-- Set vaulting flag to gate other mechanics on the client
	local rs = game:GetService("ReplicatedStorage")
	local cs = rs:FindFirstChild("ClientState")
	if cs then
		local v = cs:FindFirstChild("IsVaulting")
		if not v then
			v = Instance.new("BoolValue")
			v.Name = "IsVaulting"
			v.Value = false
			v.Parent = cs
		end
		v.Value = true
	end

	-- Align root height to retarget authored 3-stud motion to current obstacle height
	do
		local canon = Config.VaultCanonicalHeightStuds or 3.0
		local alignBlend = Config.VaultAlignBlendSeconds or 0.12
		local alignHold = Config.VaultAlignHoldSeconds or 0.08
		-- Compute feet height at animation start
		local halfH = (root.Size and root.Size.Y or 2) * 0.5
		local feetY0 = root.Position.Y - halfH
		-- World Y where the authored 3-stud top would be
		local canonicalTopWorldY = feetY0 + canon
		-- Desired top world Y (real obstacle top + clearance)
		local desiredTopWorldY = topY + (Config.VaultClearanceStuds or 1.5)
		-- Delta we need to shift the whole pose by to match authored motion to real top
		local deltaY = desiredTopWorldY - canonicalTopWorldY
		local startCF = root.CFrame
		local targetCF = startCF + Vector3.new(0, deltaY, 0)
		local releasedHeight = false
		local t0 = os.clock()
		task.spawn(function()
			-- Blend a small vertical CF offset, then hold briefly
			while (os.clock() - t0) < alignBlend do
				local alpha = math.clamp((os.clock() - t0) / alignBlend, 0, 1)
				root.CFrame = startCF:Lerp(targetCF, alpha)
				task.wait()
			end
			-- Hold Y at or above target for a short window, or until released
			local holdUntil = os.clock() + alignHold
			while stillVaulting and not releasedHeight and os.clock() < holdUntil do
				root.CFrame = CFrame.new(root.Position.X, math.max(root.Position.Y, targetCF.Y), root.Position.Z)
					* CFrame.fromMatrix(Vector3.new(), root.CFrame.XVector, root.CFrame.YVector, root.CFrame.ZVector)
				task.wait()
			end
			-- Extra guard: if no markers, keep floor on Y for part of the vault duration
			local guardUntil = os.clock() + (Config.VaultDurationSeconds or 0.35) * 0.6
			while stillVaulting and not releasedHeight and os.clock() < guardUntil do
				root.CFrame = CFrame.new(root.Position.X, math.max(root.Position.Y, targetCF.Y), root.Position.Z)
					* CFrame.fromMatrix(Vector3.new(), root.CFrame.XVector, root.CFrame.YVector, root.CFrame.ZVector)
				task.wait()
			end
		end)
	end

	local animInst = pickVaultAnimation()
	if animInst then
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
		local track
		pcall(function()
			track = animator:LoadAnimation(animInst)
		end)
		if track then
			track.Priority = Enum.AnimationPriority.Movement
			track:Play(0.05, 1, 1)
			-- Hand IK setup (simple target holders)
			local targetsFolder = workspace:FindFirstChild("VaultTargets") or Instance.new("Folder")
			targetsFolder.Name = "VaultTargets"
			targetsFolder.Parent = workspace
			local function makeTarget(name, pos)
				local p = Instance.new("Part")
				p.Name = name
				p.Size = Vector3.new(0.2, 0.2, 0.2)
				p.Transparency = 1
				p.CanCollide = false
				p.Anchored = true
				p.CFrame = CFrame.new(pos)
				p.Parent = targetsFolder
				local a = Instance.new("Attachment")
				a.Name = "Attach"
				a.Parent = p
				return p, a
			end
			-- Compute two hand points along the obstacle top edge
			local hitPos = res.Position
			local normal = res.Normal
			local tangent = Vector3.yAxis:Cross(normal)
			if tangent.Magnitude < 0.05 then
				tangent = Vector3.xAxis:Cross(normal)
			end
			tangent = tangent.Unit
			local topYAdj = topY + 0.05
			local center = Vector3.new(hitPos.X, topYAdj, hitPos.Z) - (normal * 0.15)
			local handOffset = 0.5
			local leftPos = center - (tangent * handOffset)
			local rightPos = center + (tangent * handOffset)
			local leftPart, leftAttach = makeTarget("VaultHandL", leftPos)
			local rightPart, rightAttach = makeTarget("VaultHandR", rightPos)

			local function setupIK(side, chainRootName, endEffName, attach)
				local ik = Instance.new("IKControl")
				ik.Name = "IK_Vault_" .. side
				ik.Type = Enum.IKControlType.Position
				ik.ChainRoot = humanoid.Parent:FindFirstChild(chainRootName)
				ik.EndEffector = humanoid.Parent:FindFirstChild(endEffName)
				ik.Target = attach
				pcall(function()
					ik.Priority = Enum.IKPriority.Body
				end)
				ik.Enabled = false
				ik.Weight = 0
				ik.Parent = humanoid
				return ik
			end
			local ikL = setupIK("L", "LeftUpperArm", "LeftHand", leftAttach)
			local ikR = setupIK("R", "RightUpperArm", "RightHand", rightAttach)

			local function cleanupIK()
				pcall(function()
					ikL.Enabled = false
					ikL:Destroy()
				end)
				pcall(function()
					ikR.Enabled = false
					ikR:Destroy()
				end)
				pcall(function()
					leftPart:Destroy()
				end)
				pcall(function()
					rightPart:Destroy()
				end)
			end

			local ended = false
			local function endVault()
				if ended then
					return
				end
				ended = true
				stillVaulting = false
				cleanupIK()
				restoreCharacterCollision(character)
				-- Restore obstacle collision/touch locally
				pcall(function()
					for part, prev in pairs(obstaclePrevByPart) do
						if part and part.Parent then
							if prev.collide ~= nil then
								part.CanCollide = prev.collide
							end
							if prev.touch ~= nil then
								part.CanTouch = prev.touch
							end
						end
					end
				end)
				-- Clear vaulting flag
				local cs2 = game:GetService("ReplicatedStorage"):FindFirstChild("ClientState")
				local v2 = cs2 and cs2:FindFirstChild("IsVaulting")
				if v2 then
					v2.Value = false
				end
			end

			-- Marker-driven if present; else time-based fallback
			local hasMarkers = false
			pcall(function()
				if track:GetMarkerReachedSignal("Grab") then
					hasMarkers = true
				end
			end)
			if hasMarkers then
				track:GetMarkerReachedSignal("Grab"):Connect(function()
					ikL.Enabled = true
					ikR.Enabled = true
					ikL.Weight = 1
					ikR.Weight = 1
				end)
				track:GetMarkerReachedSignal("Pass"):Connect(function()
					ikL.Weight = 0.6
					ikR.Weight = 0.6
					releasedHeight = true
				end)
				track:GetMarkerReachedSignal("Release"):Connect(function()
					ikL.Weight = 0
					ikR.Weight = 0
					ikL.Enabled = false
					ikR.Enabled = false
					cleanupIK()
					releasedHeight = true
					endVault()
				end)
			else
				-- Fallback timeline: enable/hold/disable
				task.delay(0.08, function()
					ikL.Enabled = true
					ikR.Enabled = true
					ikL.Weight = 1
					ikR.Weight = 1
					task.delay(0.18, function()
						ikL.Weight = 0.6
						ikR.Weight = 0.6
						releasedHeight = true
						task.delay(0.12, function()
							ikL.Weight = 0
							ikR.Weight = 0
							ikL.Enabled = false
							ikR.Enabled = false
							cleanupIK()
							endVault()
						end)
					end)
				end)
			end

			track.Stopped:Connect(function()
				endVault()
			end)
			task.delay(Config.VaultDurationSeconds or 0.35, function()
				pcall(function()
					track:Stop(0.1)
				end)
				endVault()
			end)
		end
	else
		-- No animation: still restore collisions after duration
		local ended = false
		local function endVaultNoAnim()
			if ended then
				return
			end
			ended = true
			stillVaulting = false
			restoreCharacterCollision(character)
			-- Restore obstacle collision/touch locally
			pcall(function()
				for part, prev in pairs(obstaclePrevByPart) do
					if part and part.Parent then
						if prev.collide ~= nil then
							part.CanCollide = prev.collide
						end
						if prev.touch ~= nil then
							part.CanTouch = prev.touch
						end
					end
				end
			end)
			local cs2 = game:GetService("ReplicatedStorage"):FindFirstChild("ClientState")
			local v2 = cs2 and cs2:FindFirstChild("IsVaulting")
			if v2 then
				v2.Value = false
			end
		end
		task.delay(Config.VaultDurationSeconds or 0.35, function()
			endVaultNoAnim()
		end)
	end
	return true
end

return Abilities
