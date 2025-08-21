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

local player = Players.LocalPlayer

local state = {
	momentum = Momentum.create(),
	stamina = Stamina.create(),
	sliding = false,
	slideEnd = nil,
	crawling = false,
	shouldActivateCrawl = false,
	sprintHeld = false,
	keys = { W = false, A = false, S = false, D = false },
	clientStateFolder = nil,
	staminaValue = nil,
	speedValue = nil,
	momentumValue = nil,
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
	_airDashResetDone = false,
	doubleJumpCharges = 0,
	_groundedSince = nil,
	_groundResetDone = false,
}

local function setProxyWorldY(proxy, targetY)
	if not proxy then
		return
	end
	if proxy:IsA("Attachment") then
		local p = proxy.Position
		-- only raise, never push down
		if p.Y < targetY then
			proxy.Position = Vector3.new(p.X, targetY, p.Z)
		end
		return
	end
	if proxy:IsA("BasePart") then
		-- Keep the bottom of the part at Y=targetY regardless of its size
		local halfY = proxy.Size.Y * 0.5
		local desiredCenterY = targetY + halfY
		local currentCenterY = proxy.Position.Y
		local deltaY = desiredCenterY - currentCenterY
		if math.abs(deltaY) > 1e-3 then
			proxy.CFrame = proxy.CFrame + Vector3.new(0, deltaY, 0)
		end
	end
end

local function setProxyFollowRootAtY(character, proxy, targetBottomY)
	if not (character and proxy and proxy:IsA("BasePart")) then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local rx, ry, rz = root.CFrame:ToOrientation()
	local halfY = proxy.Size.Y * 0.5
	local desiredCenterY = targetBottomY + halfY
	local pos = Vector3.new(root.Position.X, desiredCenterY, root.Position.Z)
	proxy.CFrame = CFrame.new(pos) * CFrame.fromOrientation(rx, ry, rz)
end

local function disableProxyWelds(proxy)
	if not (proxy and proxy:IsA("BasePart")) then
		return {}
	end
	local disabled = {}
	for _, ch in ipairs(proxy:GetChildren()) do
		if ch:IsA("WeldConstraint") then
			if ch.Enabled then
				ch.Enabled = false
				table.insert(disabled, ch)
			end
		end
	end
	return disabled
end

local function restoreProxyWelds(list)
	if not list then
		return
	end
	for _, w in ipairs(list) do
		if w and w.Parent and w:IsA("WeldConstraint") then
			w.Enabled = true
		end
	end
end

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
			-- No longer refilling dash/double jump on airtime; reset only on ground contact
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
			-- Mark grounded time; actual reset is handled by dwell check in RenderStepped
			state._groundedSince = os.clock()
			state._groundResetDone = false
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
	if state.isCrawlingValue then
		state.isCrawlingValue.Value = false
	end
	if state.shouldActivateCrawlValue then
		state.shouldActivateCrawlValue.Value = false
	end
	if state.slideOriginalSizeValue then
		state.slideOriginalSizeValue.Value = Vector3.new(2, 4, 1) -- Default size
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

	-- Audio managed by AudioManager.client.lua
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

	local momentumValue = folder:FindFirstChild("Momentum")
	if not momentumValue then
		momentumValue = Instance.new("NumberValue")
		momentumValue.Name = "Momentum"
		momentumValue.Parent = folder
	end
	state.momentumValue = momentumValue

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

	-- Ensure IsDashing exists for audio/events
	local isDashing = folder:FindFirstChild("IsDashing")
	if not isDashing then
		isDashing = Instance.new("BoolValue")
		isDashing.Name = "IsDashing"
		isDashing.Parent = folder
	end

	local isCrawling = folder:FindFirstChild("IsCrawling")
	if not isCrawling then
		isCrawling = Instance.new("BoolValue")
		isCrawling.Name = "IsCrawling"
		isCrawling.Parent = folder
	end
	state.isCrawlingValue = isCrawling

	local shouldActivateCrawl = folder:FindFirstChild("ShouldActivateCrawl")
	if not shouldActivateCrawl then
		shouldActivateCrawl = Instance.new("BoolValue")
		shouldActivateCrawl.Name = "ShouldActivateCrawl"
		shouldActivateCrawl.Parent = folder
	end
	state.shouldActivateCrawlValue = shouldActivateCrawl

	local slideOriginalSize = folder:FindFirstChild("SlideOriginalSize")
	if not slideOriginalSize then
		slideOriginalSize = Instance.new("Vector3Value")
		slideOriginalSize.Name = "SlideOriginalSize"
		slideOriginalSize.Parent = folder
	end
	state.slideOriginalSizeValue = slideOriginalSize

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
		comboRemain.Value = Config.StyleBreakTimeoutSeconds or 3
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

	-- New: IsDoubleJumping for audio
	local isDoubleJumping = folder:FindFirstChild("IsDoubleJumping")
	if not isDoubleJumping then
		isDoubleJumping = Instance.new("BoolValue")
		isDoubleJumping.Name = "IsDoubleJumping"
		isDoubleJumping.Value = false
		isDoubleJumping.Parent = folder
	end
	state.isDoubleJumpingValue = isDoubleJumping
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
		-- Ground slide: only while sprinting and not in conflicting states
		local character = getCharacter()
		if character then
			if not (Zipline.isActive(character) or Climb.isActive(character) or WallRun.isActive(character)) then
				if not (WallJump.isWallSliding and WallJump.isWallSliding(character)) then
					local Abilities = require(ReplicatedStorage.Movement.Abilities)
					local humanoid = getHumanoid(character)
					local isMoving = humanoid and humanoid.MoveDirection and humanoid.MoveDirection.Magnitude > 0
					local grounded = humanoid and (humanoid.FloorMaterial ~= Enum.Material.Air)
					local sprinting = state.stamina.isSprinting and state.sprintHeld and isMoving
					if
						grounded
						and not state.sliding
						and ((Config.SlideRequireSprint ~= false and sprinting) or (Config.SlideRequireSprint == false and isMoving))
						and Abilities.isSlideReady()
					then
						-- Consume stamina for slide
						local staminaCost = Config.SlideStaminaCost or 12
						state.stamina.current = math.max(0, state.stamina.current - staminaCost)

						local endFn = Abilities.slide(character)
						if type(endFn) == "function" then
							-- Add to Style/Combo system
							if state.style then
								local Style = require(ReplicatedStorage.Movement.Style)
								Style.addEvent(state.style, "GroundSlide", 1)
							end

							state.sliding = true
							state.slideEnd = function()
								state.sliding = false
								pcall(endFn)
							end
							-- Auto-clear after the slide duration (cooldown is separate and handled by Abilities.isSlideReady)
							task.delay((Config.SlideDurationSeconds or 0.5), function()
								if state.sliding and state.slideEnd then
									state.slideEnd()
									state.slideEnd = nil
								end
							end)
						end
					end
				end
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
	elseif input.KeyCode == Enum.KeyCode.R then
		-- Grapple/Hook toggle
		local cam = workspace.CurrentCamera
		if cam then
			if Grapple.isActive(character) then
				Grapple.stop(character)
			else
				Grapple.tryFire(character, cam.CFrame)
			end
		end
	elseif input.KeyCode == Enum.KeyCode.Space then
		local humanoid = getHumanoid(character)
		-- Block jump while crawling
		do
			local cs = ReplicatedStorage:FindFirstChild("ClientState")
			local isCrawlingVal = cs and cs:FindFirstChild("IsCrawling")
			if isCrawlingVal and isCrawlingVal.Value == true then
				return
			end
		end
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
							-- Signal double jump for audio
							pcall(function()
								local cs = ReplicatedStorage:FindFirstChild("ClientState")
								if not cs then
									cs = Instance.new("Folder")
									cs.Name = "ClientState"
									cs.Parent = ReplicatedStorage
								end
								local dj = cs:FindFirstChild("IsDoubleJumping")
								if not dj then
									dj = Instance.new("BoolValue")
									dj.Name = "IsDoubleJumping"
									dj.Value = false
									dj.Parent = cs
								end
								dj.Value = true
								task.delay(0.05, function()
									if dj then
										dj.Value = false
									end
								end)
							end)
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

	-- Sprinting and stamina updates (do not override WalkSpeed while sliding or crawling; Slide/Crawl manage it)
	local isCrawlingNow = (state.isCrawlingValue and state.isCrawlingValue.Value) or false
	if isCrawlingNow then
		-- Ensure sprint state is fully disabled while crawling to prevent speed ramp from fighting crawl speeds
		if state.stamina.isSprinting then
			Stamina.setSprinting(state.stamina, false)
			state._sprintRampT0 = nil
			state._sprintDecelT0 = nil
			state._sprintBaseSpeed = nil
		end
		-- Skip any WalkSpeed overrides while crawling
	end
	if not state.sliding and not isCrawlingNow then
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
	if not state.sliding and not isCrawlingNow then
		if not stillSprinting and humanoid.WalkSpeed ~= Config.BaseWalkSpeed then
			humanoid.WalkSpeed = Config.BaseWalkSpeed
		end
	end

	-- Audio managed by AudioManager.client.lua

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
	if state.momentumValue then
		state.momentumValue.Value = state.momentum.value or 0
	end
	if state.isSprintingValue then
		state.isSprintingValue.Value = state.stamina.isSprinting
	end
	if state.isSlidingValue then
		state.isSlidingValue.Value = state.sliding
	end
	-- Do not overwrite IsCrawling here; Crawl system manages this BoolValue

	-- Check if crawl should be activated automatically (e.g., after slide with no clearance)
	if state.shouldActivateCrawlValue and state.shouldActivateCrawlValue.Value then
		print("[ParkourController] ShouldActivateCrawl detected, activating crawl mode") -- Debug
		state.shouldActivateCrawlValue.Value = false
		if not state.crawling then
			-- Activate crawl mode automatically
			state.crawling = true
			print("[ParkourController] Crawl state set to true") -- Debug
			-- Also trigger the crawl system if available
			-- Note: Crawl is a local script, not a module, so we can't require it directly
			-- The crawl state is already set to true, which should trigger the crawl system
			print("[ParkourController] Crawl state activated, crawl system should handle the rest") -- Debug
		else
			print("[ParkourController] Already crawling, skipping activation") -- Debug
		end
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

-- Grounded dwell confirmation for refilling double jump and air dash
RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local inSpecial = false
	do
		local cs = ReplicatedStorage:FindFirstChild("ClientState")
		local isMantling = cs and cs:FindFirstChild("IsMantling")
		local isVaulting = cs and cs:FindFirstChild("IsVaulting")
		inSpecial = (
			WallRun.isActive(character)
			or (WallJump.isWallSliding and WallJump.isWallSliding(character))
			or Climb.isActive(character)
			or Zipline.isActive(character)
			or (isMantling and isMantling.Value)
			or (isVaulting and isVaulting.Value)
		)
	end
	if grounded and not inSpecial then
		state._groundedSince = state._groundedSince or os.clock()
		local dwell = Config.GroundedRefillDwellSeconds or 0.06
		if not state._groundResetDone and (os.clock() - (state._groundedSince or 0)) >= dwell then
			local Abilities = require(ReplicatedStorage.Movement.Abilities)
			if Abilities and Abilities.resetAirDashCharges then
				Abilities.resetAirDashCharges(character)
			end
			local maxDJ = Config.DoubleJumpMax or 0
			if Config.DoubleJumpEnabled and maxDJ > 0 then
				state.doubleJumpCharges = maxDJ
			else
				state.doubleJumpCharges = 0
			end
			state._groundResetDone = true
		end
	else
		state._groundedSince = nil
		state._groundResetDone = false
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
