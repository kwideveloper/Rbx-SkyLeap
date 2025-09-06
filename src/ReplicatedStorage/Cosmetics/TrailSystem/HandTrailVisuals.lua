-- Hand trail system that works on both client and server
-- Handles hand trail creation, color management, and visual effects
-- Separate from core trail system for independent customization

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import required modules
local HandTrailConfig = require(script.Parent.HandTrailConfig)
local Config = require(ReplicatedStorage.Movement.Config)

-- Determine if this is running on client or server
local isClient = RunService:IsClient()
local isServer = RunService:IsServer()

-- Hand trail system variables
local handTrailColorCache = {}
local rainbowTime = 0
local currentEquippedHandTrail = "default"

-- Hand trail instances storage
local handTrailInstances = {}
local playerHandTrailData = {} -- Store equipped hand trail per player

-- Configuration for hand trails
local HAND_TRAIL_CONFIG = {
	TrailAttachmentNameL = "HandTrailL",
	TrailAttachmentNameR = "HandTrailR",
	TrailLifeTime = Config.TrailLifeTime or 0.5,
	TrailWidth = Config.TrailWidth or 0.3,
	TrailSpeedMin = Config.TrailSpeedMin or 10,
	TrailSpeedMax = Config.TrailSpeedMax or 80,
	TrailBaseTransparency = Config.TrailBaseTransparency or 0.6,
	TrailMinTransparency = Config.TrailMinTransparency or 0.2,
	-- Hand trails specific configuration
	TrailHandsScale = Config.TrailHandsScale or 0.6,
	TrailHandsLifetimeFactor = Config.TrailHandsLifetimeFactor or 0.5,
	TrailHandsSizeFactor = Config.TrailHandsSizeFactor or 2.15,
}

-- Helper functions
local function getHandParts(char)
	local leftHand = char:FindFirstChild("LeftHand")
	local rightHand = char:FindFirstChild("RightHand")
	return leftHand, rightHand
end

local function ensureHandAttachments(char)
	local leftHand, rightHand = getHandParts(char)
	if not leftHand or not rightHand then
		return nil, nil
	end

	-- Left hand attachments
	local handA_L = leftHand:FindFirstChild(HAND_TRAIL_CONFIG.TrailAttachmentNameL)
	if not handA_L then
		handA_L = Instance.new("Attachment")
		handA_L.Name = HAND_TRAIL_CONFIG.TrailAttachmentNameL
		handA_L.Position = Vector3.new(0, 0.1, 0)
		handA_L.Parent = leftHand
	end

	local handB_L = leftHand:FindFirstChild("HandTrailB_L")
	if not handB_L then
		handB_L = Instance.new("Attachment")
		handB_L.Name = "HandTrailB_L"
		handB_L.Position = Vector3.new(0, -0.1, 0)
		handB_L.Parent = leftHand
	end

	-- Right hand attachments
	local handA_R = rightHand:FindFirstChild(HAND_TRAIL_CONFIG.TrailAttachmentNameR)
	if not handA_R then
		handA_R = Instance.new("Attachment")
		handA_R.Name = HAND_TRAIL_CONFIG.TrailAttachmentNameR
		handA_R.Position = Vector3.new(0, 0.1, 0)
		handA_R.Parent = rightHand
	end

	local handB_R = rightHand:FindFirstChild("HandTrailB_R")
	if not handB_R then
		handB_R = Instance.new("Attachment")
		handB_R.Name = "HandTrailB_R"
		handB_R.Position = Vector3.new(0, -0.1, 0)
		handB_R.Parent = rightHand
	end

	return handA_L, handB_L, handA_R, handB_R
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Get the current hand trail color based on equipped hand trail
local function getCurrentHandTrailColor(player)
	local equippedHandTrail = currentEquippedHandTrail
	if player and isServer then
		equippedHandTrail = playerHandTrailData[player] or "default"
	end

	local trailData = HandTrailConfig.getHandTrailById(equippedHandTrail)
	if not trailData then
		if isServer then
			warn(
				"[HandTrailVisuals] Hand trail data not found for:",
				equippedHandTrail,
				"player:",
				player and player.Name or "unknown"
			)
		end
		return Color3.fromRGB(255, 255, 255) -- Default white
	end

	-- Handle special effects
	if trailData.id == "rainbow" then
		rainbowTime = rainbowTime + 0.02
		local hue = (rainbowTime * 50) % 360
		return Color3.fromHSV(hue / 360, 1, 1)
	elseif trailData.id == "cosmic" then
		local time = tick() * 2
		local intensity = (math.sin(time) + 1) / 2
		return Color3.fromRGB(128 + intensity * 127, 0, 255)
	elseif trailData.id == "plasma" then
		local time = tick() * 3
		local intensity = (math.sin(time) + 1) / 2
		return Color3.fromRGB(255, 100 + intensity * 155, 0)
	end

	-- Return the trail's base color
	return trailData.color
end

-- Update hand trail color and transparency
local function updateHandTrailColor(trail, speed, player)
	if not trail then
		return
	end

	local color = getCurrentHandTrailColor(player)

	-- Use speed-based transparency logic
	local speedFactor = math.clamp(
		(speed - HAND_TRAIL_CONFIG.TrailSpeedMin) / (HAND_TRAIL_CONFIG.TrailSpeedMax - HAND_TRAIL_CONFIG.TrailSpeedMin),
		0,
		1
	)
	local transparency = HAND_TRAIL_CONFIG.TrailBaseTransparency
		- (speedFactor * (HAND_TRAIL_CONFIG.TrailBaseTransparency - HAND_TRAIL_CONFIG.TrailMinTransparency))

	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- Create hand trails for a character
local function createHandTrails(char)
	if not char then
		return
	end

	local leftHand, rightHand = getHandParts(char)
	if not leftHand or not rightHand then
		return
	end

	local handA_L, handB_L, handA_R, handB_R = ensureHandAttachments(char)
	if not handA_L or not handB_L or not handA_R or not handB_R then
		return
	end

	-- Left hand trail
	local handTrailL = Instance.new("Trail")
	handTrailL.Attachment0 = handA_L
	handTrailL.Attachment1 = handB_L
	handTrailL.FaceCamera = true
	handTrailL.Lifetime = HAND_TRAIL_CONFIG.TrailLifeTime * HAND_TRAIL_CONFIG.TrailHandsLifetimeFactor
	handTrailL.MinLength = 0.05
	handTrailL.WidthScale = NumberSequence.new(
		HAND_TRAIL_CONFIG.TrailWidth * HAND_TRAIL_CONFIG.TrailHandsScale * HAND_TRAIL_CONFIG.TrailHandsSizeFactor
	)
	handTrailL.Transparency = NumberSequence.new(1)
	handTrailL.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	handTrailL.Parent = leftHand

	-- Right hand trail
	local handTrailR = Instance.new("Trail")
	handTrailR.Attachment0 = handA_R
	handTrailR.Attachment1 = handB_R
	handTrailR.FaceCamera = true
	handTrailR.Lifetime = HAND_TRAIL_CONFIG.TrailLifeTime * HAND_TRAIL_CONFIG.TrailHandsLifetimeFactor
	handTrailR.MinLength = 0.05
	handTrailR.WidthScale = NumberSequence.new(
		HAND_TRAIL_CONFIG.TrailWidth * HAND_TRAIL_CONFIG.TrailHandsScale * HAND_TRAIL_CONFIG.TrailHandsSizeFactor
	)
	handTrailR.Transparency = NumberSequence.new(1)
	handTrailR.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	handTrailR.Parent = rightHand

	-- Store hand trail instances
	handTrailInstances[char] = {
		leftHand = handTrailL,
		rightHand = handTrailR,
	}

	return handTrailL, handTrailR
end

-- Update hand trails for a character
local function updateHandTrails(char, speed, player)
	if not char then
		return
	end

	local instances = handTrailInstances[char]
	if not instances then
		return
	end

	-- Update hand trails
	if instances.leftHand then
		updateHandTrailColor(instances.leftHand, speed, player)
	end
	if instances.rightHand then
		updateHandTrailColor(instances.rightHand, speed, player)
	end
end

-- Clean up hand trails for a character
local function cleanupHandTrails(char)
	if not char then
		return
	end

	local instances = handTrailInstances[char]
	if instances then
		if instances.leftHand then
			instances.leftHand:Destroy()
		end
		if instances.rightHand then
			instances.rightHand:Destroy()
		end
		handTrailInstances[char] = nil
	end
end

-- Set equipped hand trail
local function setEquippedHandTrail(trailId, player)
	local targetTrailId = trailId or "default"

	if isServer then
		-- Server: Store per-player hand trail data
		if player then
			playerHandTrailData[player] = targetTrailId
		end
	else
		-- Client: Only update local hand trail if it's for the local player
		if player == Players.LocalPlayer then
			currentEquippedHandTrail = targetTrailId
		end
	end

	-- Update all existing hand trails
	for char, instances in pairs(handTrailInstances) do
		local charPlayer = isServer and Players:GetPlayerFromCharacter(char) or nil
		local trailPlayer = player or charPlayer

		if instances.leftHand then
			updateHandTrailColor(instances.leftHand, HAND_TRAIL_CONFIG.TrailSpeedMax * 0.6, trailPlayer)
		end
		if instances.rightHand then
			updateHandTrailColor(instances.rightHand, HAND_TRAIL_CONFIG.TrailSpeedMax * 0.6, trailPlayer)
		end
	end
end

-- Get current equipped hand trail
local function getEquippedHandTrail()
	return currentEquippedHandTrail
end

-- Main update loop (client only)
if isClient then
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	-- Update loop
	RunService.Heartbeat:Connect(function()
		if character and character.Parent then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				local velocity = humanoidRootPart.Velocity
				local speed = velocity.Magnitude

				updateHandTrails(character, speed, player)
			end
		end
	end)

	-- Handle character respawning
	player.CharacterAdded:Connect(function(newCharacter)
		character = newCharacter
		humanoid = character:WaitForChild("Humanoid")
		-- Server will create hand trails automatically
	end)

	-- Listen for hand trail equipment updates
	local HandTrailEquipped = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HandTrailEquipped")
	HandTrailEquipped.OnClientEvent:Connect(function(targetPlayer, trailId)
		-- Only update local hand trail data if it's for the local player
		if targetPlayer == Players.LocalPlayer then
			setEquippedHandTrail(trailId, targetPlayer)
		end
	end)
end

-- Server-side: Handle all players
if isServer then
	local activePlayers = {} -- Track active players for hand trail updates
	local updateConnection -- Store the update loop connection

	local lastUpdateTimes = {} -- Track last update time per player
	local UPDATE_INTERVAL = 0.1 -- Update hand trails every 100ms instead of every frame
	local SPEED_THRESHOLD = 1 -- Only update if speed changed significantly

	local function startHandTrailUpdateLoop()
		if updateConnection then
			updateConnection:Disconnect()
		end

		local lastUpdate = 0
		updateConnection = RunService.Heartbeat:Connect(function(deltaTime)
			lastUpdate = lastUpdate + deltaTime

			-- Only update at specified interval for performance
			if lastUpdate < UPDATE_INTERVAL then
				return
			end
			lastUpdate = 0

			-- Update hand trails for all active players with optimizations
			for player, _ in pairs(activePlayers) do
				if player.Character and player.Character.Parent then
					local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
					if humanoidRootPart then
						local velocity = humanoidRootPart.Velocity
						local speed = velocity.Magnitude

						-- Only update if speed changed significantly or enough time passed
						local lastSpeed = lastUpdateTimes[player] and lastUpdateTimes[player].speed or 0
						local timeSinceLastUpdate = lastUpdateTimes[player] and (tick() - lastUpdateTimes[player].time)
							or UPDATE_INTERVAL

						if math.abs(speed - lastSpeed) > SPEED_THRESHOLD or timeSinceLastUpdate >= UPDATE_INTERVAL then
							updateHandTrails(player.Character, speed, player)
							lastUpdateTimes[player] = { speed = speed, time = tick() }
						end
					end
				end
			end
		end)
	end

	local function stopHandTrailUpdateLoop()
		if updateConnection then
			updateConnection:Disconnect()
			updateConnection = nil
		end
	end

	Players.PlayerAdded:Connect(function(player)
		activePlayers[player] = true

		player.CharacterAdded:Connect(function(character)
			-- Wait a bit for character to fully load
			task.wait(1)

			-- Create hand trails for the player
			createHandTrails(character)

			-- Set default hand trail if not set
			if not playerHandTrailData[player] then
				playerHandTrailData[player] = "default"
			end

			-- Start update loop if this is the first player
			if not updateConnection then
				startHandTrailUpdateLoop()
			end
		end)

		player.CharacterRemoving:Connect(function(character)
			cleanupHandTrails(character)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		activePlayers[player] = nil
		playerHandTrailData[player] = nil
		lastUpdateTimes[player] = nil -- Clean up update tracking

		if player.Character then
			cleanupHandTrails(player.Character)
		end

		-- Stop update loop if no active players
		if next(activePlayers) == nil then
			stopHandTrailUpdateLoop()
		end
	end)

	-- Listen for hand trail equipment updates
	local HandTrailEquipped = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("HandTrailEquipped")
	HandTrailEquipped.OnServerEvent:Connect(function(player, trailId)
		-- Update hand trail for this player
		setEquippedHandTrail(trailId, player)
		if player.Character then
			-- Force immediate update by resetting update tracking
			lastUpdateTimes[player] = nil
			-- Update the player's hand trails immediately
			updateHandTrails(player.Character, HAND_TRAIL_CONFIG.TrailSpeedMax * 0.6, player)
		end
	end)

	-- Initialize existing players
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			activePlayers[player] = true
			createHandTrails(player.Character)
			-- Initialize hand trail data for existing players
			if not playerHandTrailData[player] then
				playerHandTrailData[player] = "default"
			end
			-- Force initial hand trail update
			updateHandTrails(player.Character, 0, player)
		end
	end

	-- Start update loop if there are players
	if next(activePlayers) ~= nil then
		startHandTrailUpdateLoop()
	end
end

-- Export functions for external use
return {
	createHandTrails = createHandTrails,
	updateHandTrails = updateHandTrails,
	cleanupHandTrails = cleanupHandTrails,
	setEquippedHandTrail = setEquippedHandTrail,
	getEquippedHandTrail = getEquippedHandTrail,
	getCurrentHandTrailColor = getCurrentHandTrailColor,
}
