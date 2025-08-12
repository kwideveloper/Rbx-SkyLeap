-- Client-side parkour controller (module-style to be loaded from StarterCharacterScripts)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Movement.Config)
local Momentum = require(ReplicatedStorage.Movement.Momentum)
local Stamina = require(ReplicatedStorage.Movement.Stamina)
local Abilities = require(ReplicatedStorage.Movement.Abilities)
local DashVfx = require(ReplicatedStorage.Movement.DashVfx)
local WallRun = require(ReplicatedStorage.Movement.WallRun)
local WallJump = require(ReplicatedStorage.Movement.WallJump)
local WallMemory = require(ReplicatedStorage.Movement.WallMemory)
local Climb = require(ReplicatedStorage.Movement.Climb)

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

	local isClimbing = folder:FindFirstChild("IsClimbing")
	if not isClimbing then
		isClimbing = Instance.new("BoolValue")
		isClimbing.Name = "IsClimbing"
		isClimbing.Parent = folder
	end
	state.isClimbingValue = isClimbing

	local climbPrompt = folder:FindFirstChild("ClimbPrompt")
	if not climbPrompt then
		climbPrompt = Instance.new("StringValue")
		climbPrompt.Name = "ClimbPrompt"
		climbPrompt.Value = ""
		climbPrompt.Parent = folder
	end
	state.climbPromptValue = climbPrompt
end

ensureClientState()

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	setupCharacter(player.Character)
end

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
		-- Toggle climb on climbable walls
		if Climb.isActive(character) then
			Climb.stop(character)
		else
			if state.stamina.current >= Config.ClimbMinStamina then
				if Climb.tryStart(character) then
					-- start draining immediately on start tick
					state.stamina.current = state.stamina.current - (Config.ClimbStaminaDrainPerSecond * 0.1)
					if state.stamina.current < 0 then
						state.stamina.current = 0
					end
				end
			end
		end
	elseif input.KeyCode == Enum.KeyCode.Z then
		state.proneHeld = true
		enterProne(character)
	elseif input.KeyCode == Enum.KeyCode.Space then
		local humanoid = getHumanoid(character)
		if Climb.isActive(character) then
			if state.stamina.current >= Config.WallJumpStaminaCost then
				if Climb.tryHop(character) then
					state.stamina.current = math.max(0, state.stamina.current - Config.WallJumpStaminaCost)
				end
			end
		elseif WallRun.isActive(character) then
			-- Hop off the wall and stop sticking
			if state.stamina.current >= Config.WallJumpStaminaCost then
				if WallRun.tryHop(character) then
					state.stamina.current = math.max(0, state.stamina.current - Config.WallJumpStaminaCost)
				end
			end
		else
			local airborne = (humanoid.FloorMaterial == Enum.Material.Air)
			if airborne then
				-- Preserve original behavior: try wall jump whenever airborne and near a wall
				if state.stamina.current >= Config.WallJumpStaminaCost then
					if WallJump.tryJump(character) then
						state.stamina.current = math.max(0, state.stamina.current - Config.WallJumpStaminaCost)
						-- Do not mark usedCoyoteJump here; allow normal wall-jump chaining (WallMemory prevents spam)
						return
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
	if state.isClimbingValue then
		state.isClimbingValue.Value = Climb.isActive(character)
	end
	-- Show climb prompt when near climbable and with enough stamina
	if state.climbPromptValue then
		local nearClimbable = (not Climb.isActive(character)) and Climb.isNearClimbable(character)
		if nearClimbable and state.stamina.current >= Config.ClimbMinStamina then
			state.climbPromptValue.Value = "Press E to Climb"
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

	-- Wall run requires sprint held and being near a wall; simulate real wall stick/run
	if state.sprintHeld and humanoid.FloorMaterial == Enum.Material.Air and not Climb.isActive(character) then
		-- Exit prone if attempting wall behavior
		if state.proneActive then
			exitProne(character)
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
end)

-- Apply climb velocities before physics integrates gravity
RunService.Stepped:Connect(function(_time, dt)
	local character = player.Character
	if not character then
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
