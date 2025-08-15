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
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StyleCommit = Remotes:WaitForChild("StyleCommit")
local MaxComboReport = Remotes:WaitForChild("MaxComboReport")
local PadTriggered = Remotes:WaitForChild("PadTriggered")

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
}

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

local function tryPlayProneAnimation(humanoid)
	local rs = game:GetService("ReplicatedStorage")
	local animationsFolder = rs:FindFirstChild("Animations")
	if not animationsFolder then
		return nil
	end
	local anim = animationsFolder:FindFirstChild("Prone") or animationsFolder:FindFirstChild("Crawl")
	if not anim or not anim:IsA("Animation") then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Movement
	track:Play(0.15, 1, 1)
	return track
end

local function enterProne(character)
	if state.proneActive then
		return
	end
	local humanoid = getHumanoid(character)
	-- Disallow prone during slide/wallrun/climb
	if state.sliding or WallRun.isActive(character) or Climb.isActive(character) then
		return
	end
	state.proneOriginalWalkSpeed = humanoid.WalkSpeed
	state.proneOriginalHipHeight = humanoid.HipHeight
	state.proneOriginalCameraOffset = humanoid.CameraOffset
	humanoid.WalkSpeed = Config.ProneWalkSpeed
	humanoid.HipHeight = math.max(0, state.proneOriginalHipHeight + (Config.ProneHipHeightDelta or 0))
	humanoid.CameraOffset = Vector3.new(0, (Config.ProneCameraOffsetY or -2.5), 0)
	-- Optional animation if present
	if state.proneTrack then
		pcall(function()
			state.proneTrack:Stop(0.1)
		end)
		state.proneTrack = nil
	end
	state.proneTrack = tryPlayProneAnimation(humanoid)
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
				state.stamina.current = math.max(0, state.stamina.current - Config.SlideStaminaCost)
				DashVfx.playSlideFor(character, Config.SlideVfxDuration)
				task.delay(Config.SlideDurationSeconds, function()
					state.sliding = false
					if state.slideEnd then
						state.slideEnd()
					end
					state.slideEnd = nil
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
		state.proneHeld = true
		enterProne(character)
	elseif input.KeyCode == Enum.KeyCode.Space then
		local humanoid = getHumanoid(character)
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
	if input.KeyCode == Enum.KeyCode.Z then
		state.proneHeld = false
		local character = player.Character
		if character then
			exitProne(character)
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

	local speed = root.AssemblyLinearVelocity.Magnitude
	if humanoid.MoveDirection.Magnitude > 0 then
		Momentum.addFromSpeed(state.momentum, speed)
	else
		Momentum.decay(state.momentum, dt)
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

	-- Sprinting and stamina updates
	if state.sprintHeld then
		if not state.stamina.isSprinting then
			if Stamina.setSprinting(state.stamina, true) then
				humanoid.WalkSpeed = Config.SprintWalkSpeed
			end
		end
	else
		if state.stamina.isSprinting then
			Stamina.setSprinting(state.stamina, false)
			humanoid.WalkSpeed = Config.BaseWalkSpeed
		end
	end

	-- Prone posture enforcement (hold-to-stay)
	if state.proneHeld then
		-- If player started an incompatible state, leave prone
		if state.sliding or WallRun.isActive(character) or Climb.isActive(character) then
			state.proneHeld = false
			exitProne(character)
		else
			if not state.proneActive then
				enterProne(character)
			end
			-- Keep speed and hip height constrained while prone
			humanoid.WalkSpeed = Config.ProneWalkSpeed
			if state.proneOriginalHipHeight ~= nil then
				humanoid.HipHeight = math.max(0, state.proneOriginalHipHeight + (Config.ProneHipHeightDelta or 0))
			end
			proneDebugTicker = proneDebugTicker + dt
			if proneDebugTicker > 0.5 then
				proneDebugTicker = 0
				warn(
					"[Prone] tick held=true active=",
					state.proneActive,
					" ws=",
					humanoid.WalkSpeed,
					" hip=",
					humanoid.HipHeight
				)
			end
		end
	else
		if state.proneActive then
			exitProne(character)
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
		local _cur, s = Stamina.tickWithGate(state.stamina, dt, allowRegen)
		stillSprinting = s
	end
	if not stillSprinting and humanoid.WalkSpeed ~= Config.BaseWalkSpeed then
		humanoid.WalkSpeed = Config.BaseWalkSpeed
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

	-- Wall run requires sprint and stamina, and being near a wall; simulate real wall stick/run
	if
		not Zipline.isActive(character)
		and state.sprintHeld
		and state.stamina.isSprinting
		and state.stamina.current > 0
		and humanoid.FloorMaterial == Enum.Material.Air
		and not Climb.isActive(character)
	then
		-- Exit prone if attempting wall behavior
		if state.proneActive then
			exitProne(character)
		end
		-- If slide is active, stop it because wall run has priority
		if WallJump.isWallSliding and WallJump.isWallSliding(character) then
			WallJump.stopSlide(character)
		end
		if WallRun.isActive(character) then
			WallRun.maintain(character)
		else
			WallRun.tryStart(character)
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
	then
		-- Do not start slide if sprinting (wallrun has priority) or if out of stamina
		if (not state.sprintHeld) and state.stamina.current > 0 then
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
	AirControl.apply(character, dt)
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
		local nowActive = WallRun.isActive(character)
		if nowActive and not wasActive then
			-- If Pad happened just before wallrun, count Pad as chained first
			local chainWin = Config.ComboChainWindowSeconds or 3
			if state.pendingPadTick and (os.clock() - state.pendingPadTick) <= chainWin then
				Style.addEvent(state.style, "Pad", 1)
				state.pendingPadTick = nil
			end
			onWallRunStart()
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
			local chainWin = Config.ComboChainWindowSeconds or 3
			if state.pendingPadTick and (os.clock() - state.pendingPadTick) <= chainWin then
				Style.addEvent(state.style, "Pad", 1)
				state.pendingPadTick = nil
			end
			Style.addEvent(state.style, "Dash", 1)
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
				local chainWin = Config.ComboChainWindowSeconds or 3
				if state.pendingPadTick and (os.clock() - state.pendingPadTick) <= chainWin then
					Style.addEvent(state.style, "Pad", 1)
					state.pendingPadTick = nil
				end
				Style.addEvent(state.style, "WallJump", 1)
			end
			return ok
		end
	end
end

-- Wall slide counts only when chained; we signal start when sliding becomes active
do
	if WallJump.isWallSliding then
		local prev = false
		RunService.RenderStepped:Connect(function()
			local character = player.Character
			if not character then
				return
			end
			local active = WallJump.isWallSliding(character) or false
			if active and not prev then
				local chainWin = Config.ComboChainWindowSeconds or 3
				if state.pendingPadTick and (os.clock() - state.pendingPadTick) <= chainWin then
					Style.addEvent(state.style, "Pad", 1)
					state.pendingPadTick = nil
				end
				Style.addEvent(state.style, "WallSlide", 1)
			end
			prev = active
		end)
	end
end

-- Pad trigger from server; do NOT bump combo immediately. Only make it eligible for chaining.
PadTriggered.OnClientEvent:Connect(function()
	-- Remember pad time; consume on the next qualifying action within chain window
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
