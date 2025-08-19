-- Client-side parkour controller (module-style to be loaded from StarterCharacterScripts)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Movement.Config)
local Animations = require(ReplicatedStorage.Movement.Animations)
local Momentum = require(ReplicatedStorage.Movement.Momentum)
local Stamina = require(ReplicatedStorage.Movement.Stamina)
local Abilities = require(ReplicatedStorage.Movement.Abilities)
local DashVfx = require(ReplicatedStorage.Movement.DashVfx)
local WallRun = require(ReplicatedStorage.Movement.WallRun)
local WallJump = require(ReplicatedStorage.Movement.WallJump)
local WallMemory = require(ReplicatedStorage.Movement.WallMemory)
local Climb = require(ReplicatedStorage.Movement.Climb)
local Zipline = require(ReplicatedStorage.Movement.Zipline)
local BunnyHop = require(ReplicatedStorage.Movement.BunnyHop)
local AirControl = require(ReplicatedStorage.Movement.AirControl)
local Style = require(ReplicatedStorage.Movement.Style)
local Grapple = require(ReplicatedStorage.Movement.Grapple)
local VerticalClimb = require(ReplicatedStorage.Movement.VerticalClimb)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StyleCommit = Remotes:WaitForChild("StyleCommit")
local MaxComboReport = Remotes:WaitForChild("MaxComboReport")
local PadTriggered = Remotes:WaitForChild("PadTriggered")

-- Helper to check vertical clearance to stand from crawl
local function buildPlayerCharacterExcludeList(selfCharacter)
	local list = { selfCharacter }
	for _, plr in ipairs(Players:GetPlayers()) do
		local ch = plr.Character
		if ch and ch ~= selfCharacter then
			table.insert(list, ch)
		end
	end
	return list
end

local function hasClearanceToStand(character)
	local torso = character
		and (
			character:FindFirstChild("LowerTorso")
			or character:FindFirstChild("Torso")
			or character:FindFirstChild("UpperTorso")
		)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local sensor = torso or root
	if not sensor then
		return true
	end
	local up = Vector3.yAxis
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = buildPlayerCharacterExcludeList(character)
	params.IgnoreWater = true
	local clearance = Config.CrawlStandUpHeight or 2
	-- Raycast: start a hair below the torso top to avoid starting inside a roof
	local origin = sensor.Position + (up * (math.max(0.1, (sensor.Size.Y * 0.5) - 0.05)))
	local hit = workspace:Raycast(origin, up * (clearance + 0.1), params)
	-- Fallback: Overlap a box above the torso if ray missed (handles thin/inside cases)
	local boxBlocked = false
	local boxCount = 0
	local boxSizeY = clearance
	local boxCenterY = origin.Y + (clearance * 0.5)
	if not hit then
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = buildPlayerCharacterExcludeList(character)
		overlap.RespectCanCollide = true
		local baseSize = (root and root.Size) or sensor.Size or Vector3.new(2, 2, 1)
		-- Use narrow sideways width and very shallow forward depth so front walls don't count as overhead
		local side = Config.CrawlStandProbeSideWidth or math.max(0.6, baseSize.X * 0.4)
		local depth = Config.CrawlStandProbeForwardDepth or 0.25
		local size = Vector3.new(math.max(0.4, side), boxSizeY, math.max(0.2, depth))
		-- Slightly pull the probe back towards the character's center to avoid entering the front wall
		local back = -sensor.CFrame.LookVector
		local center = Vector3.new(sensor.Position.X, boxCenterY, sensor.Position.Z) + (back * (depth * 0.5))
		local parts = workspace:GetPartBoundsInBox(CFrame.new(center), size, overlap)
		boxCount = parts and #parts or 0
		boxBlocked = (boxCount > 0)
	end
	if Config.DebugProne then
		local hitName = hit and hit.Instance and hit.Instance:GetFullName() or "nil"
		local partName = sensor and sensor.Name or "nil"
		print(
			"[Crawl] hasClearanceToStand part=",
			partName,
			"originY=",
			origin.Y,
			"clearance=",
			clearance,
			"rayHit=",
			hitName,
			"boxCount=",
			boxCount,
			"boxBlocked=",
			boxBlocked,
			"boxCenterY=",
			boxCenterY,
			"boxSizeY=",
			boxSizeY
		)
	end
	return (hit == nil) and (boxBlocked == false)
end

local function dbgProne(...)
	if Config.DebugProne then
		print("[Crawl]", ...)
	end
end

local player = Players.LocalPlayer
local proneDebugTicker = 0

local state = {
	momentum = Momentum.create(),
	stamina = Stamina.create(),
	sliding = false,
	slideEnd = nil,
	sprintHeld = false,
	proneHeld = false,
	proneActive = false,
	proneOriginalWalkSpeed = nil,
	proneOriginalHipHeight = nil,
	proneOriginalCameraOffset = nil,
	proneTrack = nil,
	keys = { W = false, A = false, S = false, D = false },
	clientStateFolder = nil,
	staminaValue = nil,
	speedValue = nil,
	bunnyHopStacksValue = nil,
	bunnyHopFlashValue = nil,
	style = Style.create(),
	styleScoreValue = nil,
	styleComboValue = nil,
	styleMultiplierValue = nil,
	styleLastMult = 1,
	maxComboSession = 0,
	styleCommitFlashValue = nil,
	styleCommitAmountValue = nil,
	pendingPadTick = nil,
	wallAttachLockedUntil = nil,
	crawling = false,
	_crawlOrigWalkSpeed = nil,
	_crawlUseJumpPower = nil,
	_crawlOrigJumpPower = nil,
	_crawlOrigJumpHeight = nil,
	_crawlOrigRootSize = nil,
	_proneClearFrames = 0,
	_airDashResetDone = false,
	doubleJumpCharges = 0,
}

-- Per-wall chain anti-abuse: track consecutive chain actions on the same wall
local wallChain = { currentWall = nil, count = 0 }
local function resetWallChain()
	wallChain.currentWall = nil
	wallChain.count = 0
end

-- Reset chain when grounded
RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
		resetWallChain()
	end
end)

local function getNearbyWallInstance()
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local dirs = { root.CFrame.RightVector, -root.CFrame.RightVector, root.CFrame.LookVector, -root.CFrame.LookVector }
	for _, d in ipairs(dirs) do
		local r = workspace:Raycast(root.Position, d * (Config.WallSlideDetectionDistance or 4), params)
		if r and r.Instance and r.Instance.CanCollide then
			return r.Instance
		end
	end
	return nil
end

local function maybeConsumePadThenBump(eventName)
	local chainWin = Config.ComboChainWindowSeconds or 3
	if state.pendingPadTick and (os.clock() - state.pendingPadTick) <= chainWin then
		Style.addEvent(state.style, "Pad", 1)
		state.pendingPadTick = nil
	end
	-- Enforce per-wall chain cap
	local maxPerWall = Config.MaxWallChainPerSurface or 3
	if eventName == "WallJump" or eventName == "WallSlide" or eventName == "WallRun" then
		local wall = getNearbyWallInstance()
		if wall then
			if wallChain.currentWall == wall then
				wallChain.count = wallChain.count + 1
			else
				wallChain.currentWall = wall
				wallChain.count = 1
			end
			if wallChain.count > maxPerWall then
				return -- suppress further combo bumps on this wall until reset by ground
			end
		end
	end
	Style.addEvent(state.style, eventName, 1)
end

local function getCharacter()
	local character = player.Character or player.CharacterAdded:Wait()
	return character
end

local function getHumanoid(character)
	return character:WaitForChild("Humanoid")
end

local function setupCharacter(character)
	local humanoid = getHumanoid(character)
	humanoid.WalkSpeed = Config.BaseWalkSpeed
	-- Preload configured animations on character spawn to avoid first-play hitches
	task.spawn(function()
		Animations.preload()
	end)

	-- Hook fall detection for landing roll
	local humanoid = getHumanoid(character)
	local lastAirY = nil
	local minRollDrop = 20 -- studs; can be moved to Config later if needed
	local rollPending = false
	local jumpLoopTrack = nil
	humanoid.StateChanged:Connect(function(old, new)
		if new == Enum.HumanoidStateType.Freefall then
			local root = character:FindFirstChild("HumanoidRootPart")
			-- Track peak height during this airborne phase for reliable roll on high launches
			local y = root and root.Position.Y or nil
			lastAirY = y
			state._peakAirY = y
			rollPending = true
			-- Start jump loop while airborne if configured (only if no vault/mantle/wallrun/slide/zipline)
			local allowJumpLoop = not (state.isVaultingValue and state.isVaultingValue.Value)
			local jumpAnim = allowJumpLoop and Animations and Animations.get and Animations.get("Jump") or nil
			if jumpAnim then
				local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
				animator.Parent = humanoid
				if not jumpLoopTrack then
					pcall(function()
						jumpLoopTrack = animator:LoadAnimation(jumpAnim)
					end)
				end
				if jumpLoopTrack then
					jumpLoopTrack.Priority = Enum.AnimationPriority.Movement
					jumpLoopTrack.Looped = true
					if not jumpLoopTrack.IsPlaying then
						jumpLoopTrack:Play(0.05, 1, 1.0)
					end
				end
			end
			-- If any action blocks air loop, stop it
			if (state.isVaultingValue and state.isVaultingValue.Value) and jumpLoopTrack then
				pcall(function()
					jumpLoopTrack:Stop(0.05)
				end)
				jumpLoopTrack = nil
			end
			-- Reset air dash charges once per airtime
			if not state._airDashResetDone then
				state._airDashResetDone = true
				local Abilities = require(ReplicatedStorage.Movement.Abilities)
				if Abilities and Abilities.resetAirDashCharges then
					Abilities.resetAirDashCharges(character)
				end
				-- Double jump: refill per airtime
				local maxDJ = Config.DoubleJumpMax or 0
				if Config.DoubleJumpEnabled and maxDJ > 0 then
					state.doubleJumpCharges = maxDJ
				else
					state.doubleJumpCharges = 0
				end
			end
		elseif new == Enum.HumanoidStateType.Jumping then
			-- Play one-shot JumpStart, then transition to Jump loop (unless blocked)
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid
			local startAnim = Animations and Animations.get and Animations.get("JumpStart")
			local loopAllowed = not (state.isVaultingValue and state.isVaultingValue.Value)
			local loopAnim = loopAllowed and Animations and Animations.get and Animations.get("Jump") or nil
			local startTrack
			-- Carry part of slide momentum into jump (extra vertical and horizontal)
			do
				local root = character:FindFirstChild("HumanoidRootPart")
				if root then
					local v = root.AssemblyLinearVelocity
					local horiz = Vector3.new(v.X, 0, v.Z)
					local spd = horiz.Magnitude
					local upGain = (Config.SlideJumpVerticalPercent or 0.30) * spd
					local fwdGain = (Config.SlideJumpHorizontalPercent or 0.15) * spd
					local dir = nil
					if spd > 0.05 then
						dir = horiz.Unit
					else
						dir = Vector3.new(
							character.PrimaryPart.CFrame.LookVector.X,
							0,
							character.PrimaryPart.CFrame.LookVector.Z
						)
						if dir.Magnitude > 0.01 then
							dir = dir.Unit
						end
					end
					-- One-frame injection to shape jump start
					local vy = v.Y + upGain
					local vxz = dir * (Vector3.new(v.X, 0, v.Z).Magnitude + fwdGain)
					root.AssemblyLinearVelocity = Vector3.new(vxz.X, vy, vxz.Z)
				end
			end
			if startAnim then
				pcall(function()
					startTrack = animator:LoadAnimation(startAnim)
				end)
			end
			if startTrack then
				startTrack.Priority = Enum.AnimationPriority.Action
				startTrack.Looped = false
				startTrack:Play(0.05, 1, 1.0)
				startTrack.Stopped:Connect(function()
					if humanoid.FloorMaterial == Enum.Material.Air and loopAllowed and loopAnim then
						if not jumpLoopTrack then
							pcall(function()
								jumpLoopTrack = animator:LoadAnimation(loopAnim)
							end)
						end
						if jumpLoopTrack then
							jumpLoopTrack.Priority = Enum.AnimationPriority.Movement
							jumpLoopTrack.Looped = true
							if not jumpLoopTrack.IsPlaying then
								jumpLoopTrack:Play(0.05, 1, 1.0)
							end
						end
					end
				end)
			else
				if loopAllowed and loopAnim then
					if not jumpLoopTrack then
						pcall(function()
							jumpLoopTrack = animator:LoadAnimation(loopAnim)
						end)
					end
					if jumpLoopTrack then
						jumpLoopTrack.Priority = Enum.AnimationPriority.Movement
						jumpLoopTrack.Looped = true
						if not jumpLoopTrack.IsPlaying then
							jumpLoopTrack:Play(0.05, 1, 1.0)
						end
					end
				end
			end
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			-- Allow next airtime to reset dash charges again
			state._airDashResetDone = false
			-- Double jump tracker cleared on landing
			state.doubleJumpCharges = 0
			local root = character:FindFirstChild("HumanoidRootPart")
			if rollPending and root and lastAirY then
				local peakY = state._peakAirY or lastAirY
				local drop = math.max(0, (peakY - root.Position.Y))
				local cfgDbg = require(ReplicatedStorage.Movement.Config).DebugLandingRoll
				if cfgDbg then
					print(
						string.format(
							"[LandingRoll] peakY=%.2f y=%.2f drop=%.2f threshold=%d",
							peakY,
							root.Position.Y,
							drop,
							20
						)
					)
				end
				if drop >= minRollDrop then
					-- Play LandRoll animation if configured
					local anim = Animations and Animations.get and Animations.get("LandRoll")
					if anim then
						local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
						animator.Parent = humanoid
						local track
						pcall(function()
							track = animator:LoadAnimation(anim)
						end)
						if track then
							track.Priority = Enum.AnimationPriority.Action
							track.Looped = false
							track:Play(0.05, 1, 1.0)
						end
					end
				end
			end
			rollPending = false
			state._peakAirY = nil
			lastAirY = nil
			-- Stop jump loop on landing/running
			if jumpLoopTrack then
				pcall(function()
					jumpLoopTrack:Stop(0.1)
				end)
				jumpLoopTrack = nil
			end
		end
	end)
	-- Setup stamina touch tracking for parts with attribute Stamina=true (works even for CanQuery=false when CanTouch is true)
	state.staminaTouched = {}
	state.staminaTouchCount = 0
	if state.touchConns then
		for _, c in ipairs(state.touchConns) do
			if c then
				c:Disconnect()
			end
		end
	end
	state.touchConns = {}

	local function onTouched(other)
		if other and typeof(other.GetAttribute) == "function" and other:GetAttribute("Stamina") == true then
			if not state.staminaTouched[other] then
				state.staminaTouched[other] = 1
				state.staminaTouchCount = state.staminaTouchCount + 1
			end
		end
		-- Publish last collidable touch for vault fallback detection (handles CanQuery=false parts)
		if other and other:IsA("BasePart") and other.CanCollide then
			local folder = state.clientStateFolder
			if folder then
				local partVal = folder:FindFirstChild("VaultTouchPart")
				if not partVal then
					partVal = Instance.new("ObjectValue")
					partVal.Name = "VaultTouchPart"
					partVal.Parent = folder
				end
				local timeVal = folder:FindFirstChild("VaultTouchTime")
				if not timeVal then
					timeVal = Instance.new("NumberValue")
					timeVal.Name = "VaultTouchTime"
					timeVal.Parent = folder
				end
				local posVal = folder:FindFirstChild("VaultTouchPos")
				if not posVal then
					posVal = Instance.new("Vector3Value")
					posVal.Name = "VaultTouchPos"
					posVal.Parent = folder
				end
				partVal.Value = other
				timeVal.Value = os.clock()
				posVal.Value = other.Position
			end
		end
	end
	local function onTouchEnded(other)
		if other and state.staminaTouched[other] then
			state.staminaTouched[other] = nil
			state.staminaTouchCount = math.max(0, state.staminaTouchCount - 1)
		end
	end

	local function hookPart(part)
		if not part:IsA("BasePart") then
			return
		end
		table.insert(state.touchConns, part.Touched:Connect(onTouched))
		if part.TouchEnded then
			table.insert(state.touchConns, part.TouchEnded:Connect(onTouchEnded))
		end
	end

	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then
			hookPart(d)
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			hookPart(d)
		end
	end)

	-- Reset transient state on spawn and publish clean HUD states
	state.sprintHeld = false
	state.sliding = false
	state.slideEnd = nil
	state.proneHeld = false
	state.proneActive = false
	state.proneOriginalWalkSpeed = nil
	state.proneOriginalHipHeight = nil
	if state.stamina then
		state.stamina.current = Config.StaminaMax
		state.stamina.isSprinting = false
	end
	if state.staminaValue then
		state.staminaValue.Value = state.stamina.current
	end
	if state.isSprintingValue then
		state.isSprintingValue.Value = false
	end
	if state.isSlidingValue then
		state.isSlidingValue.Value = false
	end
	if state.isAirborneValue then
		state.isAirborneValue.Value = false
	end
	if state.isWallRunningValue then
		state.isWallRunningValue.Value = false
	end
	if state.isClimbingValue then
		state.isClimbingValue.Value = false
	end
	-- Initialize bunny hop listener for this character
	BunnyHop.setup(character)
end
local function ensureClientState()
	local folder = ReplicatedStorage:FindFirstChild("ClientState")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClientState"
		folder.Parent = ReplicatedStorage
	end
	state.clientStateFolder = folder

	local staminaValue = folder:FindFirstChild("Stamina")
	if not staminaValue then
		staminaValue = Instance.new("NumberValue")
		staminaValue.Name = "Stamina"
		staminaValue.Parent = folder
	end
	state.staminaValue = staminaValue

	local speedValue = folder:FindFirstChild("Speed")
	if not speedValue then
		speedValue = Instance.new("NumberValue")
		speedValue.Name = "Speed"
		speedValue.Parent = folder
	end
	state.speedValue = speedValue

	local isSprinting = folder:FindFirstChild("IsSprinting")
	if not isSprinting then
		isSprinting = Instance.new("BoolValue")
		isSprinting.Name = "IsSprinting"
		isSprinting.Parent = folder
	end
	state.isSprintingValue = isSprinting

	local isSliding = folder:FindFirstChild("IsSliding")
	if not isSliding then
		isSliding = Instance.new("BoolValue")
		isSliding.Name = "IsSliding"
		isSliding.Parent = folder
	end
	state.isSlidingValue = isSliding

	local isAirborne = folder:FindFirstChild("IsAirborne")
	if not isAirborne then
		isAirborne = Instance.new("BoolValue")
		isAirborne.Name = "IsAirborne"
		isAirborne.Parent = folder
	end
	state.isAirborneValue = isAirborne

	local isWallRunning = folder:FindFirstChild("IsWallRunning")
	if not isWallRunning then
		isWallRunning = Instance.new("BoolValue")
		isWallRunning.Name = "IsWallRunning"
		isWallRunning.Parent = folder
	end
	state.isWallRunningValue = isWallRunning

	local isWallSliding = folder:FindFirstChild("IsWallSliding")
	if not isWallSliding then
		isWallSliding = Instance.new("BoolValue")
		isWallSliding.Name = "IsWallSliding"
		isWallSliding.Parent = folder
	end
	state.isWallSlidingValue = isWallSliding

	local isMantling = folder:FindFirstChild("IsMantling")
	if not isMantling then
		isMantling = Instance.new("BoolValue")
		isMantling.Name = "IsMantling"
		isMantling.Value = false
		isMantling.Parent = folder
	end
	state.isMantlingValue = isMantling

	local isClimbing = folder:FindFirstChild("IsClimbing")
	if not isClimbing then
		isClimbing = Instance.new("BoolValue")
		isClimbing.Name = "IsClimbing"
		isClimbing.Parent = folder
	end
	state.isClimbingValue = isClimbing

	local isZiplining = folder:FindFirstChild("IsZiplining")
	if not isZiplining then
		isZiplining = Instance.new("BoolValue")
		isZiplining.Name = "IsZiplining"
		isZiplining.Parent = folder
	end
	state.isZipliningValue = isZiplining

	local isVaulting = folder:FindFirstChild("IsVaulting")
	if not isVaulting then
		isVaulting = Instance.new("BoolValue")
		isVaulting.Name = "IsVaulting"
		isVaulting.Parent = folder
	end
	state.isVaultingValue = isVaulting

	local climbPrompt = folder:FindFirstChild("ClimbPrompt")
	if not climbPrompt then
		climbPrompt = Instance.new("StringValue")
		climbPrompt.Name = "ClimbPrompt"
		climbPrompt.Value = ""
		climbPrompt.Parent = folder
	end
	state.climbPromptValue = climbPrompt

	-- Bunny hop HUD bindings
	local bhStacks = folder:FindFirstChild("BunnyHopStacks")
	if not bhStacks then
		bhStacks = Instance.new("NumberValue")
		bhStacks.Name = "BunnyHopStacks"
		bhStacks.Value = 0
		bhStacks.Parent = folder
	end
	state.bunnyHopStacksValue = bhStacks

	local bhFlash = folder:FindFirstChild("BunnyHopFlash")
	if not bhFlash then
		bhFlash = Instance.new("BoolValue")
		bhFlash.Name = "BunnyHopFlash"
		bhFlash.Value = false
		bhFlash.Parent = folder
	end
	state.bunnyHopFlashValue = bhFlash

	-- Style HUD values
	local styleScore = folder:FindFirstChild("StyleScore")
	if not styleScore then
		styleScore = Instance.new("NumberValue")
		styleScore.Name = "StyleScore"
		styleScore.Value = 0
		styleScore.Parent = folder
	end
	state.styleScoreValue = styleScore

	local styleCombo = folder:FindFirstChild("StyleCombo")
	if not styleCombo then
		styleCombo = Instance.new("NumberValue")
		styleCombo.Name = "StyleCombo"
		styleCombo.Value = 0
		styleCombo.Parent = folder
	end
	state.styleComboValue = styleCombo

	local styleMult = folder:FindFirstChild("StyleMultiplier")
	if not styleMult then
		styleMult = Instance.new("NumberValue")
		styleMult.Name = "StyleMultiplier"
		styleMult.Value = 1
		styleMult.Parent = folder
	end
	state.styleMultiplierValue = styleMult

	-- Style commit UI signals
	local styleCommitAmount = folder:FindFirstChild("StyleCommittedAmount")
	if not styleCommitAmount then
		styleCommitAmount = Instance.new("NumberValue")
		styleCommitAmount.Name = "StyleCommittedAmount"
		styleCommitAmount.Value = 0
		styleCommitAmount.Parent = folder
	end
	state.styleCommitAmountValue = styleCommitAmount

	local styleCommitFlash = folder:FindFirstChild("StyleCommittedFlash")
	if not styleCommitFlash then
		styleCommitFlash = Instance.new("BoolValue")
		styleCommitFlash.Name = "StyleCommittedFlash"
		styleCommitFlash.Value = false
		styleCommitFlash.Parent = folder
	end
	state.styleCommitFlashValue = styleCommitFlash

	-- Combo timeout HUD bindings
	local comboRemain = folder:FindFirstChild("StyleComboTimeRemaining")
	if not comboRemain then
		comboRemain = Instance.new("NumberValue")
		comboRemain.Name = "StyleComboTimeRemaining"
		comboRemain.Value = 0
		comboRemain.Parent = folder
	end
	state.styleComboTimeRemaining = comboRemain

	local comboMax = folder:FindFirstChild("StyleComboTimeMax")
	if not comboMax then
		comboMax = Instance.new("NumberValue")
		comboMax.Name = "StyleComboTimeMax"
		comboMax.Value = Config.StyleBreakTimeoutSeconds or 3
		comboMax.Parent = folder
	end
	state.styleComboTimeMax = comboMax
end

ensureClientState()

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	setupCharacter(player.Character)
end
player.CharacterAdded:Connect(function()
	-- Reset style session state hard on respawn to avoid zero-point commit visuals
	state.style = Style.create()
	if state.styleScoreValue then
		state.styleScoreValue.Value = 0
	end
	if state.styleComboValue then
		state.styleComboValue.Value = 0
	end
	if state.styleMultiplierValue then
		state.styleMultiplierValue.Value = 1
	end
end)
player.CharacterRemoving:Connect(function(char)
	BunnyHop.teardown(char)
end)

-- Ensure camera align caches base motors on spawn
-- (Removed CameraAlign setup; head tracking handled by HeadTracking.client.lua)

local function tryPlayProneAnimation(humanoid, key)
	-- Prefer configured Crouch animation from Animations registry
	local anim = nil
	if key and Animations and Animations.get then
		anim = Animations.get(key)
	end
	if not anim then
		anim = Animations and Animations.get and Animations.get("Crouch") or nil
	end
	if not anim then
		-- Fallback: legacy folder-based animations if present
		local rs = game:GetService("ReplicatedStorage")
		local animationsFolder = rs:FindFirstChild("Animations")
		if animationsFolder then
			anim = animationsFolder:FindFirstChild("Prone") or animationsFolder:FindFirstChild("Crawl")
		end
		if not anim then
			return nil
		end
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local track
	pcall(function()
		track = animator:LoadAnimation(anim)
	end)
	if not track then
		return nil
	end
	track.Priority = Enum.AnimationPriority.Movement
	track.Looped = true
	track:Play(0.1, 1, 1.0)
	return track
end

local function startCrawl(character)
	if state.crawling then
		return
	end
	local humanoid = getHumanoid(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	-- Block if not grounded or conflicting states
	if humanoid.FloorMaterial == Enum.Material.Air then
		if Config.DebugProne then
			dbgProne("startCrawl rejected: airborne")
		end
		return
	end
	if
		state.sliding
		or WallRun.isActive(character)
		or Climb.isActive(character)
		or (state.isMantlingValue and state.isMantlingValue.Value)
		or Zipline.isActive(character)
	then
		return
	end
	-- Begin crawl via Abilities (sets mask)
	if not Abilities.crawlBegin(character) then
		return
	end
	state.crawling = true
	-- Save originals
	state._crawlOrigWalkSpeed = humanoid.WalkSpeed
	state._crawlUseJumpPower = humanoid.UseJumpPower
	state._crawlOrigJumpPower = humanoid.JumpPower
	state._crawlOrigJumpHeight = humanoid.JumpHeight
	-- Speed and jump
	local crawlSpeed = Config.CrawlSpeed
		or math.max(2, math.floor((state._crawlOrigWalkSpeed or Config.BaseWalkSpeed) * 0.5))
	humanoid.WalkSpeed = crawlSpeed
	if humanoid.UseJumpPower then
		humanoid.JumpPower = 0
	else
		humanoid.JumpHeight = 0
	end
	-- Play crouch/crawl loop animation
	if state.proneTrack then
		pcall(function()
			state.proneTrack:Stop(0.1)
		end)
		state.proneTrack = nil
	end
	local desiredKey = nil
	do
		local root = character:FindFirstChild("HumanoidRootPart")
		local moving = false
		if root then
			local v = root.AssemblyLinearVelocity
			local horiz = Vector3.new(v.X, 0, v.Z)
			local threshold = Config.CrawlAnimMoveThreshold or 0.1
			moving = (horiz.Magnitude > threshold)
		end
		if moving and Animations and Animations.get and Animations.get("CrouchMove") then
			desiredKey = "CrouchMove"
		elseif (not moving) and Animations and Animations.get and Animations.get("CrouchIdle") then
			desiredKey = "CrouchIdle"
		else
			desiredKey = "Crouch"
		end
	end
	state.proneTrack = tryPlayProneAnimation(humanoid, desiredKey)
	state.proneTrackKey = desiredKey
	if state.proneTrack then
		state.proneTrack.Looped = true
	end
end

local function stopCrawl(character)
	if not state.crawling then
		return
	end
	state.crawling = false
	local humanoid = getHumanoid(character)
	-- End crawl via Abilities (removes proxy and restores collisions)
	Abilities.crawlEnd(character)
	if humanoid then
		if state._crawlOrigWalkSpeed ~= nil then
			humanoid.WalkSpeed = state._crawlOrigWalkSpeed
		end
		if state._crawlUseJumpPower then
			if state._crawlOrigJumpPower ~= nil then
				humanoid.JumpPower = state._crawlOrigJumpPower
			end
		else
			if state._crawlOrigJumpHeight ~= nil then
				humanoid.JumpHeight = state._crawlOrigJumpHeight
			end
		end
	end
	-- Stop crawl animation
	if state.proneTrack then
		pcall(function()
			state.proneTrack:Stop(0.15)
		end)
		state.proneTrack = nil
	end
	-- Clear saved originals
	state._crawlOrigWalkSpeed = nil
	state._crawlUseJumpPower = nil
	state._crawlOrigJumpPower = nil
	state._crawlOrigJumpHeight = nil
end

local function enterProne(character)
	if state.proneActive then
		return
	end
	local humanoid = getHumanoid(character)
	-- Disallow prone during slide/wallrun/climb/mantle/zipline
	if
		state.sliding
		or WallRun.isActive(character)
		or Climb.isActive(character)
		or (state.isMantlingValue and state.isMantlingValue.Value)
		or Zipline.isActive(character)
	then
		return
	end
	state.proneOriginalWalkSpeed = humanoid.WalkSpeed
	state.proneOriginalHipHeight = humanoid.HipHeight
	state.proneOriginalCameraOffset = humanoid.CameraOffset
	humanoid.WalkSpeed = Config.ProneWalkSpeed
	humanoid.HipHeight = math.max(0, state.proneOriginalHipHeight + (Config.ProneHipHeightDelta or 0))
	humanoid.CameraOffset = Vector3.new(0, (Config.ProneCameraOffsetY or -2.5), 0)
	-- Optional animation if present (loop while held Z)
	if state.proneTrack then
		pcall(function()
			state.proneTrack:Stop(0.1)
		end)
		state.proneTrack = nil
	end
	local desiredKey = nil
	do
		local root = character:FindFirstChild("HumanoidRootPart")
		local moving = false
		if root then
			local v = root.AssemblyLinearVelocity
			local horiz = Vector3.new(v.X, 0, v.Z)
			local threshold = Config.CrawlAnimMoveThreshold or 0.1
			moving = (horiz.Magnitude > threshold)
		end
		if moving and Animations and Animations.get and Animations.get("CrouchMove") then
			desiredKey = "CrouchMove"
		elseif (not moving) and Animations and Animations.get and Animations.get("CrouchIdle") then
			desiredKey = "CrouchIdle"
		else
			desiredKey = "Crouch"
		end
	end
	state.proneTrack = tryPlayProneAnimation(humanoid, desiredKey)
	state.proneTrackKey = desiredKey
	state.proneActive = true
end

local function exitProne(character)
	if not state.proneActive then
		return
	end
	local humanoid = getHumanoid(character)
	if state.proneOriginalWalkSpeed ~= nil then
		humanoid.WalkSpeed = state.proneOriginalWalkSpeed
	end
	if state.proneOriginalHipHeight ~= nil then
		humanoid.HipHeight = state.proneOriginalHipHeight
	end
	if state.proneOriginalCameraOffset ~= nil then
		humanoid.CameraOffset = state.proneOriginalCameraOffset
	else
		humanoid.CameraOffset = Vector3.new()
	end
	if state.proneTrack then
		pcall(function()
			state.proneTrack:Stop(0.2)
		end)
		state.proneTrack = nil
	end
	state.proneTrackKey = nil
	state.proneActive = false
	state.proneOriginalWalkSpeed = nil
	state.proneOriginalHipHeight = nil
	state.proneOriginalCameraOffset = nil
end

-- Inputs
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then
		return
	end

	local character = getCharacter()

	if input.KeyCode == Enum.KeyCode.Q then
		-- Dash: only spend stamina if dash actually triggers (respects cooldown)
		if state.stamina.current >= Config.DashStaminaCost then
			local character = getCharacter()
			if not character then
				return
			end
			-- Disable dash during wall slide, wall run, vault, mantle
			if WallJump.isWallSliding and WallJump.isWallSliding(character) then
				return
			end
			if WallRun.isActive(character) then
				return
			end
			local cs = ReplicatedStorage:FindFirstChild("ClientState")
			local isVaulting = cs and cs:FindFirstChild("IsVaulting")
			local isMantling = cs and cs:FindFirstChild("IsMantling")
			if (isVaulting and isVaulting.Value) or (isMantling and isMantling.Value) then
				return
			end
			if Abilities.tryDash(character) then
				state.stamina.current = math.max(0, state.stamina.current - Config.DashStaminaCost)
				DashVfx.playFor(character, Config.DashVfxDuration)
			end
		end
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		state.sprintHeld = true
	elseif input.KeyCode == Enum.KeyCode.C then
		-- Slide only while sprinting
		local humanoid = getHumanoid(character)
		-- Disable slide while airborne and during wall run
		if WallRun.isActive(character) or Climb.isActive(character) or state.proneActive then
			return
		end
		if humanoid.FloorMaterial == Enum.Material.Air then
			return
		end
		if
			state.stamina.isSprinting
			and humanoid.MoveDirection.Magnitude > 0
			and state.stamina.current >= Config.SlideStaminaCost
			and Abilities.isSlideReady()
		then
			if not state.sliding then
				state.sliding = true
				state.slideEnd = Abilities.slide(character)
				-- Count slide into combo points
				Style.addEvent(state.style, "GroundSlide", 1)
				state.stamina.current = math.max(0, state.stamina.current - Config.SlideStaminaCost)
				DashVfx.playSlideFor(character, Config.SlideVfxDuration)
				task.delay(Config.SlideDurationSeconds, function()
					state.sliding = false
					if state.slideEnd then
						state.slideEnd()
					end
					state.slideEnd = nil
					-- If we are under a low obstacle after sliding, auto-crawl until there is space
					local c = player.Character
					if c and (not hasClearanceToStand(c)) then
						dbgProne("Slide ended under obstacle -> entering crawl")
						state.proneHeld = true
						startCrawl(c)
					end
				end)
			end
		end
	elseif input.KeyCode == Enum.KeyCode.E then
		-- Zipline takes priority when near a rope
		if Zipline.isActive(character) then
			Zipline.stop(character)
		elseif Zipline.isNear(character) then
			-- stop incompatible states
			if Climb.isActive(character) then
				Climb.stop(character)
			end
			if WallRun.isActive(character) then
				WallRun.stop(character)
			end
			if WallJump.isWallSliding and WallJump.isWallSliding(character) then
				WallJump.stopSlide(character)
			end
			state.sliding = false
			state.sprintHeld = false
			Zipline.tryStart(character)
		else
			-- Toggle climb on climbable walls
			if Climb.isActive(character) then
				Climb.stop(character)
			else
				if state.stamina.current >= Config.ClimbMinStamina then
					-- stop any wall slide to allow climbing to take over immediately
					if WallJump.isWallSliding and WallJump.isWallSliding(character) then
						WallJump.stopSlide(character)
					end
					if Climb.tryStart(character) then
						-- start draining immediately on start tick
						state.stamina.current = state.stamina.current - (Config.ClimbStaminaDrainPerSecond * 0.1)
						if state.stamina.current < 0 then
							state.stamina.current = 0
						end
					end
				end
			end
		end
	elseif input.KeyCode == Enum.KeyCode.Z then
		local character = getCharacter()
		local humanoid = character and getHumanoid(character)
		if not humanoid or humanoid.FloorMaterial == Enum.Material.Air then
			if Config.DebugProne then
				dbgProne("Ignored Z: airborne or no humanoid")
			end
			return
		end
		state.proneHeld = true
		startCrawl(character)
	elseif input.KeyCode == Enum.KeyCode.R then
		-- Grapple/Hook
		local cam = workspace.CurrentCamera
		if cam then
			Grapple.tryFire(character, cam.CFrame)
		end
	elseif input.KeyCode == Enum.KeyCode.Space then
		local humanoid = getHumanoid(character)
		-- JumpStart now plays on Humanoid.StateChanged (Jumping)
		-- If dashing or sliding, cancel those states to avoid animation overlap
		pcall(function()
			local Abilities = require(ReplicatedStorage.Movement.Abilities)
			if Abilities and Abilities.cancelDash then
				Abilities.cancelDash(character)
			end
		end)
		if state.sliding and state.slideEnd then
			state.sliding = false
			state.slideEnd()
			state.slideEnd = nil
		end
		if Zipline.isActive(character) then
			-- Jump off the zipline. Force a jump frame after detaching
			Zipline.stop(character)
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.defer(function()
				if humanoid and humanoid.Parent then
					humanoid.Jump = true
				end
			end)
		elseif Climb.isActive(character) then
			if state.stamina.current >= Config.WallJumpStaminaCost then
				if Climb.tryHop(character) then
					state.stamina.current = math.max(0, state.stamina.current - Config.WallJumpStaminaCost)
				end
			end
		elseif WallRun.isActive(character) or (WallJump.isWallSliding and WallJump.isWallSliding(character)) then
			-- Hop off the wall and stop sticking
			if state.stamina.current >= Config.WallJumpStaminaCost then
				if WallRun.tryHop(character) then
					state.stamina.current = math.max(0, state.stamina.current - Config.WallJumpStaminaCost)
				end
				-- If wall slide is active, attempt wall jump via WallJump.tryJump
				if WallJump.isWallSliding and WallJump.isWallSliding(character) then
					if WallJump.tryJump(character) then
						state.stamina.current = math.max(0, state.stamina.current - Config.WallJumpStaminaCost)
					end
				end
			end
		else
			-- Attempt vault if a low obstacle is in front
			local didVault = Abilities.tryVault(character)
			if didVault then
				return
			end
			-- (Mantle is now automatic; Space remains reserved for walljump/vault)
			local airborne = (humanoid.FloorMaterial == Enum.Material.Air)
			if airborne then
				-- Airborne: if near wall and can enter slide immediately, prefer starting slide first and block jump until pose snaps
				if state.stamina.current >= Config.WallJumpStaminaCost then
					if WallJump.isNearWall(character) then
						-- isNearWall will start slide; rely on WallJump.tryJump to enforce animReady gating on next press
						return
					else
						if WallJump.tryJump(character) then
							state.stamina.current = math.max(0, state.stamina.current - Config.WallJumpStaminaCost)
							return
						end
					end
				end
				-- Double Jump: if enabled and charges remain, consume one and apply impulse
				if Config.DoubleJumpEnabled and (state.doubleJumpCharges or 0) > 0 then
					if state.stamina.current >= (Config.DoubleJumpStaminaCost or 0) then
						-- Disallow double jump during zipline/climb/active wallrun/slide
						if
							not Zipline.isActive(character)
							and not Climb.isActive(character)
							and not WallRun.isActive(character)
							and not (WallJump.isWallSliding and WallJump.isWallSliding(character))
						then
							-- Velocity: keep horizontal, set vertical to desired impulse
							local v = character.HumanoidRootPart.AssemblyLinearVelocity
							local horiz = Vector3.new(v.X, 0, v.Z)
							local vy = math.max(Config.DoubleJumpImpulse or 50, 0)
							character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(horiz.X, vy, horiz.Z)
							-- Play optional double jump animation
							local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
							animator.Parent = humanoid
							local djAnim = Animations
								and Animations.get
								and (Animations.get("DoubleJump") or Animations.get("Jump"))
							if djAnim then
								pcall(function()
									local tr = animator:LoadAnimation(djAnim)
									if tr then
										tr.Priority = Enum.AnimationPriority.Action
										tr.Looped = false
										tr:Play(0.05, 1, 1.0)
									end
								end)
							end
							-- Spend resources
							state.doubleJumpCharges = math.max(0, (state.doubleJumpCharges or 0) - 1)
							state.stamina.current =
								math.max(0, state.stamina.current - (Config.DoubleJumpStaminaCost or 0))
							-- Update style (treat as Jump event)
							Style.addEvent(state.style, "DoubleJump", 1)
							return
						end
					end
				end
			end
			-- If grounded and sprinting, attempt bunny hop boost on perfect timing
			if (not airborne) and state.stamina.isSprinting then
				local stacks = BunnyHop.tryApplyOnJump(character, state.momentum)
				if type(stacks) == "number" and stacks > 0 then
					Style.addEvent(state.style, "BunnyHop", stacks)
					if state.styleScoreValue then
						state.styleScoreValue.Value = math.floor(state.style.score + 0.5)
					end
					if state.styleComboValue then
						state.styleComboValue.Value = state.style.combo or 0
					end
				end
			end
		end
	end
	-- Track movement keys for climb independent of camera
	if input.KeyCode == Enum.KeyCode.W then
		state.keys.W = true
	end
	if input.KeyCode == Enum.KeyCode.A then
		state.keys.A = true
	end
	if input.KeyCode == Enum.KeyCode.S then
		state.keys.S = true
	end
	if input.KeyCode == Enum.KeyCode.D then
		state.keys.D = true
	end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
	if gpe then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		state.sprintHeld = false
	end
	if input.KeyCode == Enum.KeyCode.R then
		local c = player.Character
		if c then
			Grapple.stop(c)
		end
	end
	if input.KeyCode == Enum.KeyCode.Z then
		state.proneHeld = false
		local character = player.Character
		if character then
			-- If no clearance above, keep crawling
			local canStand = hasClearanceToStand(character)
			dbgProne("Z released; canStand=", canStand, "state.crawling=", state.crawling)
			if canStand then
				stopCrawl(character)
			else
				state.proneHeld = true -- keep holding logically until clearance
			end
		end
	end
	if input.KeyCode == Enum.KeyCode.W then
		state.keys.W = false
	end
	if input.KeyCode == Enum.KeyCode.A then
		state.keys.A = false
	end
	if input.KeyCode == Enum.KeyCode.S then
		state.keys.S = false
	end
	if input.KeyCode == Enum.KeyCode.D then
		state.keys.D = false
	end
end)

-- Continuous updates
RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end

	-- Initialize debounce counter
	state._proneClearFrames = state._proneClearFrames or 0
	local neededClearFrames = 3

	local speed = root.AssemblyLinearVelocity.Magnitude
	if humanoid.MoveDirection.Magnitude > 0 then
		Momentum.addFromSpeed(state.momentum, speed)
	else
		Momentum.decay(state.momentum, dt)
	end

	-- Track peak height while airborne to trigger landing roll reliably (e.g., after LaunchPads)
	if humanoid.FloorMaterial == Enum.Material.Air then
		local y = root.Position.Y
		if state._peakAirY == nil or y > (state._peakAirY or -math.huge) then
			state._peakAirY = y
		end
	end

	-- Style/Combo tick
	local styleCtx = {
		dt = dt,
		speed = speed,
		airborne = (humanoid.FloorMaterial == Enum.Material.Air),
		wallRun = WallRun.isActive(character),
		sliding = state.sliding,
		climbing = Climb.isActive(character),
	}
	-- Gate style by sprint requirement
	local sprintGate = true
	if Config.StyleRequireSprint then
		sprintGate = state.stamina.isSprinting == true
	end
	if sprintGate then
		Style.tick(state.style, styleCtx)
	end
	if state.styleScoreValue then
		local s = state.style.score or 0
		state.styleScoreValue.Value = math.floor((s * 100) + 0.5) / 100
	end
	if state.styleComboValue then
		state.styleComboValue.Value = state.style.combo or 0
	end
	-- Track session max combo and report when it increases
	local comboNow = state.style.combo or 0
	if comboNow > (state.maxComboSession or 0) then
		state.maxComboSession = comboNow
		pcall(function()
			MaxComboReport:FireServer(state.maxComboSession)
		end)
	end

	-- Count chained per-event actions into the combo system
	-- Dash chained into something else
	if Abilities.isDashReady and not Abilities.isDashReady() then
		-- dash just used recently, Style.addEvent("Dash") is handled when input triggers; ensure we set lastEventTick
	end
	if state.styleMultiplierValue then
		local mul = state.style.multiplier or 1
		-- Round to 2 decimals for cleaner UI/inspectors
		state.styleMultiplierValue.Value = math.floor((mul * 100) + 0.5) / 100
	end

	-- Detect multiplier break to commit and reset Style
	local prevMult = state.styleLastMult or 1
	local curMult = state.style.multiplier or 1

	-- Also commit if no style input for X seconds (inactivity), but only if a combo existed
	local commitByInactivity = false
	local timeout = Config.StyleCommitInactivitySeconds or 1.0
	if timeout > 0 and (os.clock() - (state.style.lastActiveTick or 0)) >= timeout then
		commitByInactivity = (state.style.combo or 0) > 0
	end

	if (prevMult > 1.01 and curMult <= 1.01) or commitByInactivity then
		local commitAmount = math.floor(((state.style.score or 0) * 100) + 0.5) / 100
		if commitAmount > 0 then
			pcall(function()
				StyleCommit:FireServer(commitAmount)
			end)
			-- Pulse UI signal for animation
			if state.styleCommitAmountValue then
				state.styleCommitAmountValue.Value = commitAmount
			end
			if state.styleCommitFlashValue then
				state.styleCommitFlashValue.Value = true
				task.delay(0.05, function()
					if state.styleCommitFlashValue then
						state.styleCommitFlashValue.Value = false
					end
				end)
			end
		end
		-- Reset session style
		state.style.score = 0
		state.style.combo = 0
		state.style.multiplier = 1
		state.style.flowTime = 0
		if state.styleScoreValue then
			state.styleScoreValue.Value = 0
		end
		if state.styleComboValue then
			state.styleComboValue.Value = 0
		end
		if state.styleMultiplierValue then
			state.styleMultiplierValue.Value = 1
		end
	end
	state.styleLastMult = curMult

	-- Sprinting and stamina updates (do not override WalkSpeed while sliding; Abilities.slide manages it)
	if not state.sliding then
		local isMoving = (humanoid.MoveDirection and humanoid.MoveDirection.Magnitude > 0) or false
		if state.sprintHeld and isMoving then
			if not state.stamina.isSprinting then
				if Stamina.setSprinting(state.stamina, true) then
					-- start ramp towards sprint speed
					state._sprintRampT0 = os.clock()
					state._sprintBaseSpeed = humanoid.WalkSpeed
				end
			else
				-- ramp up while holding sprint
				local t0 = state._sprintRampT0 or os.clock()
				local base = state._sprintBaseSpeed or Config.BaseWalkSpeed
				local dur = math.max(0.01, Config.SprintAccelSeconds or 0.3)
				local alpha = math.clamp((os.clock() - t0) / dur, 0, 1)
				humanoid.WalkSpeed = base + (Config.SprintWalkSpeed - base) * alpha
			end
		else
			if state.stamina.isSprinting then
				-- ramp down to base speed
				local t0 = state._sprintDecelT0 or os.clock()
				state._sprintDecelT0 = t0
				local cur = humanoid.WalkSpeed
				local dur = math.max(0.01, Config.SprintDecelSeconds or 0.2)
				local alpha = math.clamp((os.clock() - t0) / dur, 0, 1)
				humanoid.WalkSpeed = cur + (Config.BaseWalkSpeed - cur) * alpha
				if alpha >= 1 then
					Stamina.setSprinting(state.stamina, false)
					state._sprintRampT0 = nil
					state._sprintDecelT0 = nil
					state._sprintBaseSpeed = nil
				end
			else
				-- ensure at base
				humanoid.WalkSpeed = Config.BaseWalkSpeed
				state._sprintRampT0 = nil
				state._sprintDecelT0 = nil
				state._sprintBaseSpeed = nil
			end
		end
	end

	-- Crawl (hold-to-stay)
	if state.proneHeld then
		-- If player started uncompatible state, end crawl
		if
			state.sliding
			or WallRun.isActive(character)
			or Climb.isActive(character)
			or (state.isMantlingValue and state.isMantlingValue.Value)
			or Zipline.isActive(character)
		then
			state.proneHeld = false
			state._proneClearFrames = 0
			stopCrawl(character)
		else
			-- If left the ground, end manual crouch (Z rule)
			if humanoid.FloorMaterial == Enum.Material.Air then
				if state.crawling then
					if Config.DebugProne then
						dbgProne("End crawl: became airborne")
					end
					state.proneHeld = false
					state._proneClearFrames = 0
					stopCrawl(character)
				end
			else
				if not state.crawling then
					startCrawl(character)
				end
				-- Auto-stand when space available for several consecutive frames
				if state.crawling and not UserInputService:IsKeyDown(Enum.KeyCode.Z) then
					if hasClearanceToStand(character) then
						state._proneClearFrames = (state._proneClearFrames or 0) + 1
						if state._proneClearFrames >= neededClearFrames then
							if Config.DebugProne then
								dbgProne("Auto-stand after", state._proneClearFrames, "clear frames")
							end
							state.proneHeld = false
							state._proneClearFrames = 0
							stopCrawl(character)
						end
					else
						state._proneClearFrames = 0
					end
				end
			end
		end
	else
		if state.crawling then
			-- Try to stand up only if space exists (and keep requiring consecutive frames)
			if hasClearanceToStand(character) then
				state._proneClearFrames = (state._proneClearFrames or 0) + 1
				if state._proneClearFrames >= neededClearFrames then
					state._proneClearFrames = 0
					stopCrawl(character)
				end
			else
				state._proneClearFrames = 0
				state.proneHeld = true -- remain crawling until free
			end
		end
	end

	-- Stamina gate: regen when on ground OR touching any part with attribute Stamina=true (collidable or not)
	local allowRegen = (humanoid.FloorMaterial ~= Enum.Material.Air)
	if state.staminaTouchCount and state.staminaTouchCount > 0 then
		allowRegen = true
	else
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Exclude
			overlapParams.FilterDescendantsInstances = { character }
			overlapParams.RespectCanCollide = false
			local expand = Vector3.new(2, 3, 2)
			local parts =
				workspace:GetPartBoundsInBox(root.CFrame, (root.Size or Vector3.new(2, 2, 1)) + expand, overlapParams)
			for _, p in ipairs(parts) do
				if p and typeof(p.GetAttribute) == "function" and p:GetAttribute("Stamina") == true then
					allowRegen = true
					break
				end
			end
		end
	end
	local stillSprinting
	do
		local _cur, s = Stamina.tickWithGate(
			state.stamina,
			dt,
			allowRegen,
			(humanoid.MoveDirection and humanoid.MoveDirection.Magnitude > 0)
		)
		stillSprinting = s
	end
	if not state.sliding then
		if not stillSprinting and humanoid.WalkSpeed ~= Config.BaseWalkSpeed then
			humanoid.WalkSpeed = Config.BaseWalkSpeed
		end
	end

	-- Swap crouch animations based on movement (idle vs move variants)
	if state.proneTrack and (state.crawling or state.proneActive) then
		local root = character:FindFirstChild("HumanoidRootPart")
		local moving = false
		if root then
			local v = root.AssemblyLinearVelocity
			local horiz = Vector3.new(v.X, 0, v.Z)
			local threshold = Config.CrawlAnimMoveThreshold or 0.1
			moving = (horiz.Magnitude > threshold)
		end
		local desiredKey
		if moving and Animations and Animations.get and Animations.get("CrouchMove") then
			desiredKey = "CrouchMove"
		elseif (not moving) and Animations and Animations.get and Animations.get("CrouchIdle") then
			desiredKey = "CrouchIdle"
		else
			desiredKey = "Crouch"
		end
		if desiredKey ~= state.proneTrackKey then
			pcall(function()
				state.proneTrack:Stop(0.1)
			end)
			state.proneTrack = tryPlayProneAnimation(humanoid, desiredKey)
			if state.proneTrack then
				state.proneTrack.Looped = true
			end
			state.proneTrackKey = desiredKey
		end
	end

	-- Wall slide stamina drain (half sprint rate) while active
	if WallJump.isWallSliding and WallJump.isWallSliding(character) then
		local drain = (Config.WallSlideDrainPerSecond or (Config.SprintDrainPerSecond * 0.5)) * dt
		state.stamina.current = math.max(0, state.stamina.current - drain)
		if state.stamina.current <= 0 then
			-- stop slide when out of stamina
			if WallJump.stopSlide then
				WallJump.stopSlide(character)
			end
		end
	end

	-- Publish client state for HUD
	if state.staminaValue then
		state.staminaValue.Value = state.stamina.current
	end
	if state.speedValue then
		state.speedValue.Value = speed
	end
	if state.isSprintingValue then
		state.isSprintingValue.Value = state.stamina.isSprinting
	end
	if state.isSlidingValue then
		state.isSlidingValue.Value = state.sliding
	end
	if state.isAirborneValue then
		state.isAirborneValue.Value = (humanoid.FloorMaterial == Enum.Material.Air)
	end
	if state.isWallRunningValue then
		state.isWallRunningValue.Value = WallRun.isActive(character)
	end
	if state.isWallSlidingValue then
		state.isWallSlidingValue.Value = (WallJump.isWallSliding and WallJump.isWallSliding(character)) or false
	end
	if state.isClimbingValue then
		state.isClimbingValue.Value = Climb.isActive(character)
	end
	if state.isZipliningValue then
		state.isZipliningValue.Value = Zipline.isActive(character)
	end

	-- Publish combo timeout progress for HUD
	if state.styleComboValue and state.styleComboTimeRemaining and state.styleComboTimeMax then
		local timeout = Config.StyleBreakTimeoutSeconds or 3
		state.styleComboTimeMax.Value = timeout
		local combo = state.style.combo or 0
		if combo > 0 then
			local remain = math.max(0, timeout - (os.clock() - (state.style.lastActiveTick or 0)))
			state.styleComboTimeRemaining.Value = remain
		else
			state.styleComboTimeRemaining.Value = 0
		end
	end

	-- (Head/camera alignment handled by HeadTracking.client.lua)
	-- Show climb prompt when near climbable and with enough stamina
	if state.climbPromptValue then
		local show = ""
		if (not Zipline.isActive(character)) and Zipline.isNear(character) then
			show = "Press E to Zipline"
		else
			local nearClimbable = (not Climb.isActive(character)) and Climb.isNearClimbable(character)
			if nearClimbable and state.stamina.current >= Config.ClimbMinStamina then
				show = "Press E to Climb"
			end
		end
		if show ~= "" then
			state.climbPromptValue.Value = show
		else
			state.climbPromptValue.Value = ""
		end
	end
	-- Climb state and stamina drain
	local move = { h = 0, v = 0 }
	if Climb.isActive(character) then
		-- WASD strictly by keys, relative to character orientation but not camera
		move.h = (state.keys.D and 1 or 0) - (state.keys.A and 1 or 0)
		move.v = (state.keys.W and 1 or 0) - (state.keys.S and 1 or 0)
		local ok = Climb.maintain(character, move)
		-- Drain stamina every frame while active (even without movement)
		state.stamina.current = state.stamina.current - (Config.ClimbStaminaDrainPerSecond * dt)
		if Config.DebugClimb then
			print(string.format("[Climb] active=%s stamina=%.1f", tostring(ok), state.stamina.current))
		end
		if state.stamina.current <= 0 then
			state.stamina.current = 0
			Climb.stop(character)
		end
		-- Disable sprint while climbing
		if state.stamina.isSprinting then
			Stamina.setSprinting(state.stamina, false)
			humanoid.WalkSpeed = Config.BaseWalkSpeed
		end
	end

	-- Vertical climb: sprinting straight into a wall grants a brief upward run
	if humanoid.FloorMaterial == Enum.Material.Air and state.sprintHeld and state.stamina.isSprinting then
		if VerticalClimb.isActive(character) then
			VerticalClimb.maintain(character, dt)
		else
			VerticalClimb.tryStart(character)
		end
	end

	-- Wall run requires sprint, movement, stamina, airborne, and no climb. Do not break wall slide unless wallrun actually starts.
	local wantWallRun = (
		not Zipline.isActive(character)
		and state.sprintHeld
		and state.stamina.isSprinting
		and (humanoid.MoveDirection and humanoid.MoveDirection.Magnitude > 0)
		and state.stamina.current > 0
		and humanoid.FloorMaterial == Enum.Material.Air
		and not Climb.isActive(character)
	)
	if wantWallRun then
		-- Exit prone if attempting wall behavior
		if state.proneActive then
			exitProne(character)
		end
		if WallRun.isActive(character) then
			WallRun.maintain(character)
		else
			local started = WallRun.tryStart(character)
			if started and (WallJump.isWallSliding and WallJump.isWallSliding(character)) then
				WallJump.stopSlide(character)
			end
		end
	else
		if WallRun.isActive(character) then
			WallRun.stop(character)
		end
		-- Reset wall jump memory on ground so player can reuse same wall after landing
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			WallMemory.clear(character)
		end
	end

	-- Maintain Wall Slide when airborne near walls (independent of sprint)
	if
		humanoid.FloorMaterial == Enum.Material.Air
		and not Zipline.isActive(character)
		and not Climb.isActive(character)
		and not (state.isMantlingValue and state.isMantlingValue.Value)
	then
		-- Do not start slide if sprinting (wallrun has priority) or if out of stamina
		local suppressUntil = state.wallSlideSuppressUntil or 0
		local suppressedFlag = (state.wallSlideSuppressed == true)
		local canStartSlide = (not suppressedFlag) and (os.clock() >= suppressUntil)
		-- Extra gating: only attempt slide proximity if there is no mantle candidate ahead
		local blockByMantleCandidate = false
		if Abilities.isMantleCandidate then
			blockByMantleCandidate = Abilities.isMantleCandidate(character) == true
		end
		-- Extra: while mantling or within a small window after, completely disable isNearWall to avoid edge flickers on curved surfaces
		if not state.sprintHeld and state.stamina.current > 0 and canStartSlide and not blockByMantleCandidate then
			-- Proximity check will internally start/stop slide as needed
			WallJump.isNearWall(character)
		end
		-- If slide is active, maintain physics only if we have stamina; otherwise stop
		if WallJump.isWallSliding and WallJump.isWallSliding(character) then
			if state.stamina.current > 0 then
				WallJump.updateWallSlide(character, dt)
			else
				WallJump.stopSlide(character)
			end
		end
	end

	-- Apply Quake/CS-style air control after other airborne logic
	local acUnlock = (
		state.wallAttachLockedUntil
		and (
			state.wallAttachLockedUntil
			- (Config.WallRunLockAfterWallJumpSeconds or 0.35)
			+ (Config.AirControlUnlockAfterWallJumpSeconds or 0.12)
		)
	) or 0
	if (not state.wallAttachLockedUntil) or (os.clock() >= acUnlock) then
		local allowAC = true
		if state._suppressAirControlUntil and os.clock() < state._suppressAirControlUntil then
			allowAC = false
		end
		if allowAC then
			AirControl.apply(character, dt)
		end
	end

	-- Global unfreeze/cleanup watchdog: ensure AutoRotate and animations aren't left frozen after actions
	local anyActionActive = false
	if WallRun.isActive(character) then
		anyActionActive = true
	end
	if WallJump.isWallSliding and WallJump.isWallSliding(character) then
		anyActionActive = true
	end
	if Climb.isActive(character) then
		anyActionActive = true
	end
	if Zipline.isActive(character) then
		anyActionActive = true
	end
	if state.isMantlingValue and state.isMantlingValue.Value then
		anyActionActive = true
	end
	if not anyActionActive then
		-- Safety: ensure collisions are restored after any action that might have disabled them
		pcall(function()
			local Abilities = require(ReplicatedStorage.Movement.Abilities)
			if Abilities and Abilities.ensureCollisions then
				Abilities.ensureCollisions(character)
			end
		end)
		-- Restore autorotate if disabled by previous action
		if humanoid.AutoRotate == false then
			humanoid.AutoRotate = true
		end
		-- Restore safe humanoid state from RunningNoPhysics if not in any action
		local hs = humanoid:GetState()
		if hs == Enum.HumanoidStateType.RunningNoPhysics then
			if humanoid.FloorMaterial == Enum.Material.Air then
				humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			else
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
			end
		end
		-- Stop frozen zero-speed tracks if any
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local tracks = animator:GetPlayingAnimationTracks()
			for _, tr in ipairs(tracks) do
				local ok, spd = pcall(function()
					return tr.Speed
				end)
				if ok and (spd == 0) then
					pcall(function()
						tr:Stop(0.1)
					end)
				end
			end
		end
	end

	-- Auto-vault while sprinting towards low obstacle
	if Config.VaultEnabled ~= false then
		local isMovingForward = humanoid.MoveDirection.Magnitude > 0.1
		local isGrounded = (humanoid.FloorMaterial ~= Enum.Material.Air)
		if isGrounded and isMovingForward and state.stamina.isSprinting then
			if Abilities.tryVault(character) then
				Style.addEvent(state.style, "Vault", 1)
			end
		end
	end

	-- Auto-mantle: when airborne, moving forward (by input or velocity), near a ledge at mantle height
	if Config.MantleEnabled ~= false then
		local airborne = (humanoid.FloorMaterial == Enum.Material.Air)
		local movingForward = humanoid.MoveDirection.Magnitude > 0.1
		-- Allow mantle to trigger purely from velocity (e.g., after walljumps without input)
		local movingByVelocity = false
		do
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local v = root.AssemblyLinearVelocity
				local horiz = Vector3.new(v.X, 0, v.Z)
				if horiz.Magnitude > 2 then
					local fwd = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
					if fwd.Magnitude > 0.01 then
						movingByVelocity = (fwd.Unit:Dot(horiz.Unit) > 0.3)
					end
				end
			end
		end
		local movingAny = movingForward or movingByVelocity
		-- Do not mantle during incompatible states
		if airborne and movingAny and (not Zipline.isActive(character)) and (not Climb.isActive(character)) then
			if state.stamina.current >= (Config.MantleStaminaCost or 0) then
				local didMantle = false
				if Abilities.tryMantle then
					didMantle = Abilities.tryMantle(character)
					if not didMantle then
					end
				end
				if didMantle then
					state.stamina.current = math.max(0, state.stamina.current - (Config.MantleStaminaCost or 0))
					Style.addEvent(state.style, "Mantle", 1)
					-- Suppress wall slide immediately and for an extra window; clear after grounded confirm
					state.wallSlideSuppressed = true
					state.wallSlideSuppressUntil = os.clock() + (Config.MantleWallSlideSuppressSeconds or 0.6)
					-- Stop any current wall slide / wall run to avoid conflicts
					if WallJump.isWallSliding and WallJump.isWallSliding(character) then
						WallJump.stopSlide(character)
					end
					if WallRun.isActive(character) then
						WallRun.stop(character)
					end
					-- HUD flag (optional)
					if state.isMantlingValue then
						state.isMantlingValue.Value = true
					end
				end
			end
		end
	end
end)

-- Per-frame updates for added systems

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	if character then
		Grapple.update(character, dt)
		-- (rope swing removed)
	end
end)
-- Chain-sensitive action events to Style
local function onWallRunStart()
	Style.addEvent(state.style, "WallRun", 1)
end

-- Hook wallrun transitions by polling state change
do
	local wasActive = false
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		if not character then
			return
		end
		if state.wallAttachLockedUntil and os.clock() < state.wallAttachLockedUntil then
			wasActive = false
			return
		end
		local nowActive = WallRun.isActive(character)
		if nowActive and not wasActive then
			maybeConsumePadThenBump("WallRun")
		end
		wasActive = nowActive
	end)
end

-- Dash is fired in InputBegan when Abilities.tryDash succeeds; count it as chained
-- We emit the Style event immediately after a successful dash
do
	local oldTryDash = Abilities.tryDash
	Abilities.tryDash = function(character)
		local ok = oldTryDash(character)
		if ok then
			maybeConsumePadThenBump("Dash")
		end
		return ok
	end
end

-- Wall jump: count each successful tryJump
do
	local oldTryJump = WallJump.tryJump
	if oldTryJump then
		WallJump.tryJump = function(character)
			local ok = oldTryJump(character)
			if ok then
				-- Lock wall attach for a short window to preserve jump impulse when still facing the wall
				state.wallAttachLockedUntil = os.clock() + (Config.WallRunLockAfterWallJumpSeconds or 0.25)
				-- Removed camera nudge on walljump per request
				maybeConsumePadThenBump("WallJump")
				-- Suppress air control briefly to prevent immediate input from reducing away impulse
				state._suppressAirControlUntil = os.clock() + (Config.WallJumpAirControlSuppressSeconds or 0.2)
			end
			return ok
		end
	end
end

-- During lock window prevent wallrun/wallslide from being started
RunService.RenderStepped:Connect(function()
	if state.wallAttachLockedUntil and os.clock() < state.wallAttachLockedUntil then
		-- Stop active wallrun
		local character = player.Character
		if character and WallRun.isActive and WallRun.isActive(character) then
			WallRun.stop(character)
		end
		-- Optionally suppress air control override for a brief moment after walljump
		local lock = (Config.WallRunLockAfterWallJumpSeconds or 0.35)
		if lock > 0 then
			-- NOP: AirControl.apply uses MoveDirection/camera; we rely on our short lock and fixed velocity to dominate initial frames
		end
	end
	-- Mantle grounded confirmation: only clear suppression after being grounded for X seconds
	local groundedConfirm = Config.MantleGroundedConfirmSeconds or 0.2
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local airborne = (humanoid.FloorMaterial == Enum.Material.Air)
		if not airborne then
			-- Start or continue grounded timer
			state._mantleGroundedSince = state._mantleGroundedSince or os.clock()
			local okToClear = (os.clock() - (state._mantleGroundedSince or 0)) >= groundedConfirm
			if okToClear then
				state.wallSlideSuppressUntil = 0
				state.wallSlideSuppressed = false
			end
		else
			-- Reset timer while airborne
			state._mantleGroundedSince = nil
		end
	end
end)

-- Wall slide counts only when chained; we signal start when sliding becomes active
do
	if WallJump.isWallSliding then
		local prev = false
		local nudgeT0 = 0
		RunService.RenderStepped:Connect(function()
			local character = player.Character
			if not character then
				return
			end
			if state.wallAttachLockedUntil and os.clock() < state.wallAttachLockedUntil then
				prev = false
				return
			end
			local active = WallJump.isWallSliding(character) or false
			if active and not prev then
				maybeConsumePadThenBump("WallSlide")
				nudgeT0 = os.clock()
			end
			-- (camera nudge during wall slide removed)
			prev = active
		end)
	end
end

-- Pad trigger from server; do NOT bump combo immediately. Only make it eligible for chaining.
PadTriggered.OnClientEvent:Connect(function(newVel)
	-- Client-side application to ensure impulse even if Touched misses a frame
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and typeof(newVel) == "Vector3" then
		if humanoid then
			pcall(function()
				humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			end)
		end
		pcall(function()
			root.CFrame = root.CFrame + Vector3.new(0, 0.05, 0)
		end)
		root.AssemblyLinearVelocity = newVel
	end
	-- Mark as eligible for chaining
	state.pendingPadTick = os.clock()
end)

-- Apply climb velocities before physics integrates gravity
RunService.Stepped:Connect(function(_time, dt)
	local character = player.Character
	if not character then
		return
	end
	-- Apply zipline/ climb velocities before physics
	if Zipline.isActive(character) then
		Zipline.maintain(character, dt)
		return
	end
	if not Climb.isActive(character) then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end

	local move = { h = 0, v = 0 }
	move.h = (state.keys.D and 1 or 0) - (state.keys.A and 1 or 0)
	move.v = (state.keys.W and 1 or 0) - (state.keys.S and 1 or 0)
	Climb.maintain(character, move)
end)

-- Low-frequency auto clearance sampler (passive)
local _autoCrawlT0 = 0
RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	if Config.CrawlAutoEnabled == false then
		return
	end
	local now = os.clock()
	local interval = Config.CrawlAutoSampleSeconds or 0.12
	if (now - _autoCrawlT0) < interval then
		return
	end
	_autoCrawlT0 = now
	-- Skip if incompatible actions
	if
		state.sliding
		or WallRun.isActive(character)
		or Climb.isActive(character)
		or (state.isMantlingValue and state.isMantlingValue.Value)
		or Zipline.isActive(character)
	then
		return
	end
	-- Optional: ground-only to avoid catching ceilings mid-air
	if (Config.CrawlAutoGroundOnly ~= false) and humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	-- If there is NO clearance and we are not crawling, auto-enter crawl and hold until free
	if not state.crawling and not state.proneHeld then
		if not hasClearanceToStand(character) then
			if Config.DebugProne then
				dbgProne("Auto-crawl: detected low clearance nearby")
			end
			state.proneHeld = true
			startCrawl(character)
		end
	end
end)
