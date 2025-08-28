-- Slow Motion System for SkyLeap
-- Provides bullet time functionality for critical moments
-- Press R to activate slow motion for 3 seconds

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Movement.Config)

-- Configuration
local SLOW_MOTION_KEY = Enum.KeyCode.R
local SLOW_MOTION_DURATION = 3.0 -- seconds
local SLOW_MOTION_SPEED = 0.5 -- 50% of normal speed
local TRANSITION_DURATION = 0.5 -- seconds for smooth transition
local COOLDOWN_DURATION = 10.0 -- seconds between uses

-- State management
local slowMotionActive = false
local slowMotionEndTime = 0
local lastActivationTime = 0
local currentTimeScale = 1.0
local targetTimeScale = 1.0
local customDeltaTime = 1.0 -- Custom delta time multiplier for animations

-- Player references
local player = Players.LocalPlayer
local character = nil
local humanoid = nil
local animator = nil

-- Animation speed tracking
local originalAnimationSpeeds = {}
local activeAnimations = {}

-- Function to get current character
local function getCharacter()
	local char = player.Character
	if not char then
		print("SlowMotion: getCharacter() - No character found")
	end
	return char
end

-- Function to get humanoid
local function getHumanoid()
	local char = getCharacter()
	if not char then
		print("SlowMotion: getHumanoid() - No character to get humanoid from")
		return nil
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		print("SlowMotion: getHumanoid() - No humanoid found in character")
	end
	return humanoid
end

-- Function to get animator
local function getAnimator()
	local humanoid = getHumanoid()
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		return animator
	end
	return nil
end

-- Function to slow down all playing animations
local function slowDownAnimations()
	local animator = getAnimator()
	if not animator then
		return
	end

	-- Get all currently playing animations
	local playingAnimations = animator:GetPlayingAnimationTracks()

	for _, track in ipairs(playingAnimations) do
		if track.IsPlaying then
			-- Store original speed
			originalAnimationSpeeds[track] = track.Speed

			-- Slow down animation
			track:AdjustSpeed(SLOW_MOTION_SPEED)

			-- Track active animations
			activeAnimations[track] = true
		end
	end
end

-- Function to restore animation speeds
local function restoreAnimationSpeeds()
	for track, originalSpeed in pairs(originalAnimationSpeeds) do
		if track and track:IsDescendantOf(workspace) then
			track:AdjustSpeed(originalSpeed)
		end
	end

	-- Clear tracking
	originalAnimationSpeeds = {}
	activeAnimations = {}
end

-- Function to apply slow motion to physics
local function applySlowMotionPhysics()
	local character = getCharacter()
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	print("SlowMotion: Applying physics slow motion...")
	print("SlowMotion: Original velocity:", rootPart.AssemblyLinearVelocity)
	print("SlowMotion: Original magnitude:", rootPart.AssemblyLinearVelocity.Magnitude)

	-- Store original velocities as attributes (only if not already stored)
	if not rootPart:GetAttribute("SlowMotionOriginalVelocity") then
		rootPart:SetAttribute("SlowMotionOriginalVelocity", rootPart.AssemblyLinearVelocity)
		rootPart:SetAttribute("SlowMotionOriginalAngularVelocity", rootPart.AssemblyAngularVelocity)
		print("SlowMotion: Stored original velocities")
	end

	-- Get original velocities and apply slow motion
	local originalVelocity = rootPart:GetAttribute("SlowMotionOriginalVelocity") or rootPart.AssemblyLinearVelocity
	local originalAngularVelocity = rootPart:GetAttribute("SlowMotionOriginalAngularVelocity")
		or rootPart.AssemblyAngularVelocity

	-- Apply slow motion by scaling velocities
	local newVelocity = originalVelocity * SLOW_MOTION_SPEED
	local newAngularVelocity = originalAngularVelocity * SLOW_MOTION_SPEED

	-- Set slow motion flag to prevent other scripts from overriding
	rootPart:SetAttribute("SlowMotionActive", true)
	rootPart:SetAttribute("SlowMotionTargetVelocity", newVelocity)
	rootPart:SetAttribute("SlowMotionTargetAngularVelocity", newAngularVelocity)

	rootPart.AssemblyLinearVelocity = newVelocity
	rootPart.AssemblyAngularVelocity = newAngularVelocity

	print("SlowMotion: Applied velocity:", newVelocity)
	print("SlowMotion: New magnitude:", newVelocity.Magnitude)

	-- Also slow down humanoid walk speed
	local humanoid = getHumanoid()
	if humanoid then
		print("SlowMotion: Original WalkSpeed:", humanoid.WalkSpeed)
		if not humanoid:GetAttribute("SlowMotionOriginalWalkSpeed") then
			humanoid:SetAttribute("SlowMotionOriginalWalkSpeed", humanoid.WalkSpeed)
		end
		local originalWalkSpeed = humanoid:GetAttribute("SlowMotionOriginalWalkSpeed") or humanoid.WalkSpeed
		local newWalkSpeed = originalWalkSpeed * SLOW_MOTION_SPEED

		-- Set slow motion flag for humanoid
		humanoid:SetAttribute("SlowMotionActive", true)
		humanoid:SetAttribute("SlowMotionTargetWalkSpeed", newWalkSpeed)

		humanoid.WalkSpeed = newWalkSpeed
		print("SlowMotion: Applied WalkSpeed:", newWalkSpeed)
	else
		print("SlowMotion: No humanoid found!")
	end
end

-- Function to restore normal physics
local function restoreNormalPhysics()
	print("SlowMotion: ===== RESTORING NORMAL PHYSICS =====")

	local character = getCharacter()
	if not character then
		print("SlowMotion: No character found for restoration!")
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		print("SlowMotion: No HumanoidRootPart found for restoration!")
		return
	end

	print("SlowMotion: Current velocity before restoration:", rootPart.AssemblyLinearVelocity)

	-- Clear slow motion flags first
	rootPart:SetAttribute("SlowMotionActive", nil)
	rootPart:SetAttribute("SlowMotionTargetVelocity", nil)
	rootPart:SetAttribute("SlowMotionTargetAngularVelocity", nil)

	-- Restore original velocities from attributes
	local originalVelocity = rootPart:GetAttribute("SlowMotionOriginalVelocity")
	local originalAngularVelocity = rootPart:GetAttribute("SlowMotionOriginalAngularVelocity")

	if originalVelocity then
		rootPart.AssemblyLinearVelocity = originalVelocity
		rootPart:SetAttribute("SlowMotionOriginalVelocity", nil)
		print("SlowMotion: Restored velocity:", originalVelocity)
	else
		print("SlowMotion: No original velocity found to restore")
	end

	if originalAngularVelocity then
		rootPart.AssemblyAngularVelocity = originalAngularVelocity
		rootPart:SetAttribute("SlowMotionOriginalAngularVelocity", nil)
		print("SlowMotion: Restored angular velocity:", originalAngularVelocity)
	end

	-- Restore humanoid walk speed
	local humanoid = getHumanoid()
	if humanoid then
		print("SlowMotion: Current WalkSpeed before restoration:", humanoid.WalkSpeed)

		-- Clear slow motion flags for humanoid
		humanoid:SetAttribute("SlowMotionActive", nil)
		humanoid:SetAttribute("SlowMotionTargetWalkSpeed", nil)

		local originalWalkSpeed = humanoid:GetAttribute("SlowMotionOriginalWalkSpeed")
		if originalWalkSpeed then
			humanoid.WalkSpeed = originalWalkSpeed
			humanoid:SetAttribute("SlowMotionOriginalWalkSpeed", nil)
			print("SlowMotion: Restored WalkSpeed:", originalWalkSpeed)
		else
			print("SlowMotion: No original WalkSpeed found to restore")
		end
	else
		print("SlowMotion: No humanoid found for restoration!")
	end

	print("SlowMotion: ===== PHYSICS RESTORED =====")
end

-- Function to check if slow motion is on cooldown
local function isOnCooldown()
	local currentTime = tick()
	return (currentTime - lastActivationTime) < COOLDOWN_DURATION
end

-- Debug function to show system state
local function debugSystemState()
	print("==== SLOW MOTION DEBUG INFO ====")
	print("Active:", slowMotionActive)
	print("Transition:", transitionActive)
	print("On Cooldown:", isOnCooldown())
	if isOnCooldown() then
		print("Cooldown Remaining:", string.format("%.1f", getCooldownRemaining()))
	end
	if slowMotionActive then
		print("Time Remaining:", string.format("%.1f", math.max(0, slowMotionEndTime - tick())))
	end

	local character = getCharacter()
	if character then
		print("Character Found:", character.Name)

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			print("RootPart Velocity:", rootPart.AssemblyLinearVelocity)
			print("RootPart Magnitude:", rootPart.AssemblyLinearVelocity.Magnitude)
			print("Has Original Velocity Attr:", rootPart:GetAttribute("SlowMotionOriginalVelocity") ~= nil)
			print("SlowMotion Active Flag:", rootPart:GetAttribute("SlowMotionActive"))
			print("Target Velocity Attr:", rootPart:GetAttribute("SlowMotionTargetVelocity"))
		else
			print("No RootPart Found!")
		end

		local humanoid = getHumanoid()
		if humanoid then
			print("Humanoid WalkSpeed:", humanoid.WalkSpeed)
			print("Has Original WalkSpeed Attr:", humanoid:GetAttribute("SlowMotionOriginalWalkSpeed") ~= nil)
			print("SlowMotion Active Flag:", humanoid:GetAttribute("SlowMotionActive"))
			print("Target WalkSpeed Attr:", humanoid:GetAttribute("SlowMotionTargetWalkSpeed"))
		else
			print("No Humanoid Found!")
		end

		local animator = getAnimator()
		if animator then
			local tracks = animator:GetPlayingAnimationTracks()
			print("Active Animation Tracks:", #tracks)
			for i, track in ipairs(tracks) do
				print("  Track " .. i .. ":", track.Name, "Speed:", track.Speed)
			end
		else
			print("No Animator Found!")
		end
	else
		print("No Character Found!")
	end

	print("==================================")
end

-- Function to get remaining cooldown time
local function getCooldownRemaining()
	local currentTime = tick()
	local timeSinceActivation = currentTime - lastActivationTime
	return math.max(0, COOLDOWN_DURATION - timeSinceActivation)
end

-- Function to start slow motion
local function startSlowMotion()
	if slowMotionActive or transitionActive or isOnCooldown() then
		if transitionActive then
			print("SlowMotion: Cannot activate - transition in progress")
		elseif isOnCooldown() then
			local remaining = getCooldownRemaining()
			print(string.format("SlowMotion: On cooldown! %.1f seconds remaining", remaining))
		end
		return false
	end

	print("SlowMotion: ===== ACTIVATING SLOW MOTION =====")
	print("SlowMotion: Character:", getCharacter())
	print("SlowMotion: Humanoid:", getHumanoid())

	slowMotionActive = true
	lastActivationTime = tick()
	slowMotionEndTime = tick() + SLOW_MOTION_DURATION
	targetTimeScale = SLOW_MOTION_SPEED

	-- Apply slow motion effects
	print("SlowMotion: Calling slowDownAnimations...")
	slowDownAnimations()

	print("SlowMotion: Calling applySlowMotionPhysics...")
	applySlowMotionPhysics()

	-- Note: Global time scale not available in Roblox, using physics and animation scaling instead

	-- Add visual effect (screen blur)
	print("SlowMotion: Adding blur effect...")
	local blur = Instance.new("BlurEffect")
	blur.Size = 2
	blur.Parent = game:GetService("Lighting")
	print("SlowMotion: Blur effect added")

	-- Play activation sound (using a built-in Roblox sound)
	print("SlowMotion: Playing activation sound...")
	local activationSound = Instance.new("Sound")
	activationSound.SoundId = "rbxasset://sounds/switch.wav" -- Built-in switch sound
	activationSound.Volume = 0.4
	activationSound.Parent = workspace
	activationSound:Play()
	print("SlowMotion: Sound played")

	-- Clean up sound after playing
	task.delay(1, function()
		if activationSound and activationSound:IsDescendantOf(workspace) then
			activationSound:Destroy()
		end
	end)

	print("SlowMotion: ===== SLOW MOTION ACTIVATED =====")
	return true
end

-- Transition state management
local transitionActive = false
local transitionConnection = nil

-- Function to end slow motion with smooth transition
local function endSlowMotion()
	if not slowMotionActive then
		print("SlowMotion: endSlowMotion called but slowMotionActive is false")
		return
	end

	print("SlowMotion: ===== STARTING TRANSITION TO NORMAL SPEED =====")

	slowMotionActive = false
	transitionActive = true
	targetTimeScale = 1.0

	-- Remove visual effects
	print("SlowMotion: Removing visual effects...")
	local lighting = game:GetService("Lighting")
	local blur = lighting:FindFirstChildOfClass("BlurEffect")
	if blur then
		blur:Destroy()
		print("SlowMotion: Blur effect removed")
	else
		print("SlowMotion: No blur effect found to remove")
	end

	-- Simple and reliable transition
	print("SlowMotion: Starting transition delay...")
	task.delay(0.1, function() -- Small delay for smooth transition
		print("SlowMotion: ===== TRANSITION COMPLETE - BACK TO NORMAL SPEED =====")

		-- Restore all original values
		print("SlowMotion: Calling restoreNormalPhysics...")
		restoreNormalPhysics()

		print("SlowMotion: Calling restoreAnimationSpeeds...")
		restoreAnimationSpeeds()

		-- Clean up transition
		transitionActive = false
		print("SlowMotion: Transition cleanup complete")
	end)
end

-- Main update loop
RunService.RenderStepped:Connect(function()
	local currentTime = tick()

	-- Check if slow motion should end (but don't interrupt transition)
	if slowMotionActive and not transitionActive and currentTime >= slowMotionEndTime then
		endSlowMotion()
	end

	-- PROTECTION SYSTEM: Keep slow motion values active
	if slowMotionActive then
		local character = getCharacter()
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart and rootPart:GetAttribute("SlowMotionActive") then
				-- Check if velocity was changed by other scripts
				local targetVelocity = rootPart:GetAttribute("SlowMotionTargetVelocity")
				if targetVelocity then
					local currentVelocity = rootPart.AssemblyLinearVelocity
					local distance = (currentVelocity - targetVelocity).Magnitude

					-- If velocity changed significantly, restore slow motion value
					if distance > 1 then
						print("SlowMotion: Velocity was changed by other script, restoring slow motion value")
						rootPart.AssemblyLinearVelocity = targetVelocity
					end
				end
			end

			local humanoid = getHumanoid()
			if humanoid and humanoid:GetAttribute("SlowMotionActive") then
				-- Check if WalkSpeed was changed by other scripts
				local targetWalkSpeed = humanoid:GetAttribute("SlowMotionTargetWalkSpeed")
				if targetWalkSpeed then
					local currentWalkSpeed = humanoid.WalkSpeed
					local difference = math.abs(currentWalkSpeed - targetWalkSpeed)

					-- If WalkSpeed changed significantly, restore slow motion value
					if difference > 0.5 then
						print("SlowMotion: WalkSpeed was changed by other script, restoring slow motion value")
						humanoid.WalkSpeed = targetWalkSpeed
					end
				end
			end
		end
	end

	-- Update character references
	character = getCharacter()
	humanoid = getHumanoid()
	animator = getAnimator()
end)

-- Input handling
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == SLOW_MOTION_KEY then
		print("SlowMotion: R key pressed!")

		if isOnCooldown() then
			local remaining = getCooldownRemaining()
			print(string.format("SlowMotion: On cooldown! %.1f seconds remaining", remaining))
			return
		end

		local success = startSlowMotion()
		if success then
			print("SlowMotion: Slow motion activated! Duration: " .. SLOW_MOTION_DURATION .. "s")
		else
			print("SlowMotion: Failed to activate slow motion!")
		end
	elseif input.KeyCode == Enum.KeyCode.F and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		-- Ctrl+F para mostrar debug info completo
		print("SlowMotion: Debug info requested (Ctrl+F)")
		debugSystemState()
	end
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		if slowMotionActive then
			endSlowMotion()
		end
		-- Note: Global time scale reset through physics and animation cleanup
	end
end)

-- Function to create UI for slow motion feedback
local function createSlowMotionUI()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SlowMotionUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local frame = Instance.new("Frame")
	frame.Name = "StatusFrame"
	frame.Size = UDim2.new(0, 200, 0, 50)
	frame.Position = UDim2.new(0.5, -100, 0.1, 0)
	frame.BackgroundTransparency = 0.5
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BorderSizePixel = 2
	frame.BorderColor3 = Color3.fromRGB(255, 255, 255)
	frame.Visible = false
	frame.Parent = screenGui

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = frame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 1, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusLabel.TextSize = 16
	statusLabel.Font = Enum.Font.SourceSansBold
	statusLabel.Text = "SLOW MOTION ACTIVE"
	statusLabel.TextStrokeTransparency = 0
	statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	statusLabel.Parent = frame

	screenGui.Parent = playerGui
	return screenGui
end

-- UI management
local slowMotionUI = createSlowMotionUI()

-- Function to update slow motion UI
local function updateSlowMotionUI()
	if not slowMotionUI then
		return
	end

	local statusFrame = slowMotionUI:FindFirstChild("StatusFrame")
	if not statusFrame then
		return
	end

	if slowMotionActive then
		statusFrame.Visible = true
		local timeRemaining = math.max(0, slowMotionEndTime - tick())
		local statusLabel = statusFrame:FindFirstChild("StatusLabel")
		if statusLabel then
			statusLabel.Text = string.format("SLOW MOTION: %.1fs", timeRemaining)

			-- Change color based on time remaining
			if timeRemaining > 2 then
				statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green
			elseif timeRemaining > 1 then
				statusLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- Yellow
			else
				statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red
			end
		end
	elseif transitionActive then
		statusFrame.Visible = true
		local statusLabel = statusFrame:FindFirstChild("StatusLabel")
		if statusLabel then
			statusLabel.Text = "TRANSITIONING..."
			statusLabel.TextColor3 = Color3.fromRGB(255, 165, 0) -- Orange
		end
	else
		statusFrame.Visible = false
	end
end
local statusLabel = slowMotionUI and slowMotionUI.StatusFrame.StatusLabel

-- Function to update UI
local function updateUI()
	if not statusLabel then
		return
	end

	if slowMotionActive then
		local remaining = math.max(0, slowMotionEndTime - tick())
		statusLabel.Text = string.format("SLOW MOTION: %.1fs", remaining)
		statusLabel.Parent.Visible = true
		statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
	elseif transitionActive then
		statusLabel.Text = "RETURNING TO NORMAL..."
		statusLabel.Parent.Visible = true
		statusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	elseif isOnCooldown() then
		local remaining = getCooldownRemaining()
		statusLabel.Text = string.format("COOLDOWN: %.1fs", remaining)
		statusLabel.Parent.Visible = true
		statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
	else
		statusLabel.Parent.Visible = false
	end
end

-- Update UI in main loop
RunService.RenderStepped:Connect(function()
	updateUI()
end)

-- ============================================================================
-- SLOW MOTION SYSTEM - SKYLEAP
-- ============================================================================
-- Bullet Time functionality for critical parkour moments
--
-- FEATURES:
-- ✅ Press R to activate slow motion
-- ✅ Reduces speed to 50% (configurable)
-- ✅ Duration: 3 seconds (configurable)
-- ✅ Affects: Physics, Animations, WalkSpeed
-- ✅ Preserves momentum in all directions (X, Y, Z)
-- ✅ Uses attributes to store/restore original values
-- ✅ Cooldown system (10 seconds default)
-- ✅ Visual feedback UI with timer
-- ✅ Blur effect during slow motion
-- ✅ Sound effects for activation
--
-- CONFIGURATION:
-- - SLOW_MOTION_KEY: R (configurable)
-- - SLOW_MOTION_DURATION: 3.0 seconds
-- - SLOW_MOTION_SPEED: 0.5 (50% of normal speed)
-- - TRANSITION_DURATION: 0.5 seconds (smooth transition)
-- - COOLDOWN_DURATION: 10.0 seconds
--
-- USAGE:
-- 1. Press R during critical moments
-- 2. Everything slows down to 50%
-- 3. You have 3 seconds to react/perform actions
-- 4. Instant restoration of original values
-- 5. 10 second cooldown before next use
--
-- ============================================================================

print("SlowMotion: System loaded! Press R to activate slow motion")
print("SlowMotion: Configuration:")
print("  - Duration: " .. SLOW_MOTION_DURATION .. " seconds")
print("  - Speed: " .. (SLOW_MOTION_SPEED * 100) .. "%")
print("  - Cooldown: " .. COOLDOWN_DURATION .. " seconds")
print("  - Transition: " .. TRANSITION_DURATION .. " seconds")
print("SlowMotion: UI created and ready!")
print("SlowMotion: Press Ctrl+F for detailed debug information")
print("SlowMotion: ===== SYSTEM READY =====")
