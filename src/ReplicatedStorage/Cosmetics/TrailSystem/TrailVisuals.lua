-- Unified trail system that works on both client and server
-- Handles trail creation, color management, and visual effects

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import required modules
local TrailConfig = require(script.Parent.TrailConfig)
local Config = require(ReplicatedStorage.Movement.Config)

-- Determine if this is running on client or server
local isClient = RunService:IsClient()
local isServer = RunService:IsServer()

-- Trail system variables
local trailColorCache = {}
local rainbowTime = 0
local currentEquippedTrail = "default"

-- Trail instances storage
local trailInstances = {}
local playerTrailData = {} -- Store equipped trail per player
local OtherTrailStates = {}

-- Configuration (using original Movement Config values)
local TRAIL_CONFIG = {
	TrailBodyPartName = Config.TrailBodyPartName or "UpperTorso",
	TrailAttachmentNameA = Config.TrailAttachmentNameA or "TrailA",
	TrailAttachmentNameB = Config.TrailAttachmentNameB or "TrailB",
	TrailAttachmentNameL = "TrailL",
	TrailAttachmentNameR = "TrailR",
	TrailLifeTime = Config.TrailLifeTime or 0.5,
	TrailWidth = Config.TrailWidth or 0.3,
	TrailSpeedMin = Config.TrailSpeedMin or 10,
	TrailSpeedMax = Config.TrailSpeedMax or 80,
	TrailBaseTransparency = Config.TrailBaseTransparency or 0.6,
	TrailMinTransparency = Config.TrailMinTransparency or 0.2,
	-- Hand trails configuration
	TrailHandsEnabled = Config.TrailHandsEnabled or true,
	TrailHandsScale = Config.TrailHandsScale or 0.6,
	TrailHandsLifetimeFactor = Config.TrailHandsLifetimeFactor or 0.5,
	TrailHandsSizeFactor = Config.TrailHandsSizeFactor or 2.15,
	-- Trail particles configuration
	TrailParticlesEnabled = Config.TrailParticlesEnabled or true,
	TrailParticlesTexture = Config.TrailParticlesTexture or "rbxassetid://85601264783180",
	TrailParticlesLifetime = Config.TrailParticlesLifetime or 1.2,
	TrailParticlesRate = Config.TrailParticlesRate or 3,
	TrailParticlesEmissionDirection = Config.TrailParticlesEmissionDirection or "Back",
	TrailParticlesSpeedMin = Config.TrailParticlesSpeedMin or 8,
	TrailParticlesSizeMin = Config.TrailParticlesSizeMin or 0.5,
	TrailParticlesSizeMax = Config.TrailParticlesSizeMax or 1.0,
	TrailParticlesTransparencyStart = Config.TrailParticlesTransparencyStart or 0,
	TrailParticlesTransparencyMid = Config.TrailParticlesTransparencyMid or 0.3,
	TrailParticlesTransparencyEnd = Config.TrailParticlesTransparencyEnd or 1,
}

-- Helper functions
local function getTrailBodyPart(char)
	local preferred = TRAIL_CONFIG.TrailBodyPartName or "UpperTorso"
	local part = char:FindFirstChild(preferred)
		or char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("Torso")
		or char:FindFirstChild("HumanoidRootPart")
	return part
end

local function ensureAttachments(char)
	local part = getTrailBodyPart(char)
	if not part then
		return nil
	end
	local a = part:FindFirstChild(TRAIL_CONFIG.TrailAttachmentNameA or "TrailA")
	local b = part:FindFirstChild(TRAIL_CONFIG.TrailAttachmentNameB or "TrailB")
	if not a then
		a = Instance.new("Attachment")
		a.Name = TRAIL_CONFIG.TrailAttachmentNameA or "TrailA"
		a.Position = Vector3.new(0, 0.9, -0.5)
		a.Parent = part
	end
	if not b then
		b = Instance.new("Attachment")
		b.Name = TRAIL_CONFIG.TrailAttachmentNameB or "TrailB"
		b.Position = Vector3.new(0, -0.9, 0.5)
		b.Parent = part
	end
	return a, b
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
	return Color3.new(lerp(c1.R, c2.R, t), lerp(c1.G, c2.G, t), lerp(c1.B, c2.B, t))
end

-- Get the current trail color based on equipped trail
local function getCurrentTrailColor(player)
	local equippedTrail = currentEquippedTrail
	if player and isServer then
		equippedTrail = playerTrailData[player] or "default"
	end

	local trailData = TrailConfig.getTrailById(equippedTrail)
	if not trailData then
		if isServer then
			warn(
				"[TrailVisuals] Trail data not found for:",
				equippedTrail,
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
	if isServer then
		-- Less verbose logging on server
		return trailData.color
	else
		return trailData.color
	end
end

-- Update trail color and transparency (using original logic)
local function updateTrailColor(trail, speed, player)
	if not trail then
		return
	end

	local color = getCurrentTrailColor(player)

	-- Use original speed-based transparency logic
	local speedFactor = math.clamp(
		(speed - TRAIL_CONFIG.TrailSpeedMin) / (TRAIL_CONFIG.TrailSpeedMax - TRAIL_CONFIG.TrailSpeedMin),
		0,
		1
	)
	local transparency = TRAIL_CONFIG.TrailBaseTransparency
		- (speedFactor * (TRAIL_CONFIG.TrailBaseTransparency - TRAIL_CONFIG.TrailMinTransparency))

	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- Create particle system for trail
local function createTrailParticles(char)
	if not TRAIL_CONFIG.TrailParticlesEnabled then
		return nil
	end

	local part = getTrailBodyPart(char)
	if not part then
		return nil
	end

	-- Create attachment for particles
	local particleAttachment = part:FindFirstChild("TrailParticles")
	if not particleAttachment then
		particleAttachment = Instance.new("Attachment")
		particleAttachment.Name = "TrailParticles"
		particleAttachment.Position = Vector3.new(0, 0, -0.5) -- Slightly behind the character
		particleAttachment.Parent = part
	end

	-- Create particle emitter
	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Parent = particleAttachment
	particleEmitter.Texture = TRAIL_CONFIG.TrailParticlesTexture
	particleEmitter.Lifetime = NumberRange.new(TRAIL_CONFIG.TrailParticlesLifetime)
	particleEmitter.Rate = TRAIL_CONFIG.TrailParticlesRate
	particleEmitter.EmissionDirection = Enum.NormalId[TRAIL_CONFIG.TrailParticlesEmissionDirection]
	particleEmitter.Enabled = false -- Start disabled
	particleEmitter.Color = ColorSequence.new(Color3.new(1, 1, 1)) -- White particles by default
	particleEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, TRAIL_CONFIG.TrailParticlesSizeMin),
		NumberSequenceKeypoint.new(0.5, TRAIL_CONFIG.TrailParticlesSizeMax),
		NumberSequenceKeypoint.new(1, TRAIL_CONFIG.TrailParticlesSizeMin),
	})
	particleEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, TRAIL_CONFIG.TrailParticlesTransparencyStart),
		NumberSequenceKeypoint.new(0.5, TRAIL_CONFIG.TrailParticlesTransparencyMid),
		NumberSequenceKeypoint.new(1, TRAIL_CONFIG.TrailParticlesTransparencyEnd),
	})
	particleEmitter.SpreadAngle = Vector2.new(15, 15)
	particleEmitter.Speed = NumberRange.new(2, 5)

	return particleEmitter
end

-- Create trail for a character
local function createTrail(char)
	if not char then
		return
	end

	local attachA, attachB = ensureAttachments(char)
	if not attachA or not attachB then
		return
	end

	-- Main trail (using original config)
	local trail = Instance.new("Trail")
	trail.Attachment0 = attachA
	trail.Attachment1 = attachB
	trail.FaceCamera = true
	trail.Lifetime = TRAIL_CONFIG.TrailLifeTime
	trail.MinLength = 0.1
	trail.WidthScale = NumberSequence.new(TRAIL_CONFIG.TrailWidth)
	trail.Transparency = NumberSequence.new(1)
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	trail.Parent = char

	-- Hand trails (only if enabled)
	local leftHand = char:FindFirstChild("LeftHand")
	local rightHand = char:FindFirstChild("RightHand")

	if TRAIL_CONFIG.TrailHandsEnabled and leftHand then
		local handA_L = leftHand:FindFirstChild(TRAIL_CONFIG.TrailAttachmentNameL or "TrailL")
		if not handA_L then
			handA_L = Instance.new("Attachment")
			handA_L.Name = TRAIL_CONFIG.TrailAttachmentNameL or "TrailL"
			handA_L.Position = Vector3.new(0, 0.1, 0)
			handA_L.Parent = leftHand
		end

		local handB_L = leftHand:FindFirstChild("TrailB_L")
		if not handB_L then
			handB_L = Instance.new("Attachment")
			handB_L.Name = "TrailB_L"
			handB_L.Position = Vector3.new(0, -0.1, 0)
			handB_L.Parent = leftHand
		end

		local handTrailL = Instance.new("Trail")
		handTrailL.Attachment0 = handA_L
		handTrailL.Attachment1 = handB_L
		handTrailL.FaceCamera = true
		handTrailL.Lifetime = TRAIL_CONFIG.TrailLifeTime * TRAIL_CONFIG.TrailHandsLifetimeFactor
		handTrailL.MinLength = 0.05
		handTrailL.WidthScale = NumberSequence.new(
			TRAIL_CONFIG.TrailWidth * TRAIL_CONFIG.TrailHandsScale * TRAIL_CONFIG.TrailHandsSizeFactor
		)
		handTrailL.Transparency = NumberSequence.new(1)
		handTrailL.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		handTrailL.Parent = leftHand
	end

	if TRAIL_CONFIG.TrailHandsEnabled and rightHand then
		local handA_R = rightHand:FindFirstChild(TRAIL_CONFIG.TrailAttachmentNameR or "TrailR")
		if not handA_R then
			handA_R = Instance.new("Attachment")
			handA_R.Name = TRAIL_CONFIG.TrailAttachmentNameR or "TrailR"
			handA_R.Position = Vector3.new(0, 0.1, 0)
			handA_R.Parent = rightHand
		end

		local handB_R = rightHand:FindFirstChild("TrailB_R")
		if not handB_R then
			handB_R = Instance.new("Attachment")
			handB_R.Name = "TrailB_R"
			handB_R.Position = Vector3.new(0, -0.1, 0)
			handB_R.Parent = rightHand
		end

		local handTrailR = Instance.new("Trail")
		handTrailR.Attachment0 = handA_R
		handTrailR.Attachment1 = handB_R
		handTrailR.FaceCamera = true
		handTrailR.Lifetime = TRAIL_CONFIG.TrailLifeTime * TRAIL_CONFIG.TrailHandsLifetimeFactor
		handTrailR.MinLength = 0.05
		handTrailR.WidthScale = NumberSequence.new(
			TRAIL_CONFIG.TrailWidth * TRAIL_CONFIG.TrailHandsScale * TRAIL_CONFIG.TrailHandsSizeFactor
		)
		handTrailR.Transparency = NumberSequence.new(1)
		handTrailR.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		handTrailR.Parent = rightHand
	end

	-- Create particle system
	local particleEmitter = createTrailParticles(char)

	-- Store trail instances
	trailInstances[char] = {
		main = trail,
		leftHand = leftHand and leftHand:FindFirstChildOfClass("Trail"),
		rightHand = rightHand and rightHand:FindFirstChildOfClass("Trail"),
		particles = particleEmitter,
	}

	return trail
end

-- Update trail for a character
local function updateTrail(char, speed, player)
	if not char then
		return
	end

	local instances = trailInstances[char]
	if not instances then
		return
	end

	-- Update main trail
	if instances.main then
		updateTrailColor(instances.main, speed, player)
	end

	-- Update hand trails (use same speed as main trail)
	if instances.leftHand then
		updateTrailColor(instances.leftHand, speed, player)
	end
	if instances.rightHand then
		updateTrailColor(instances.rightHand, speed, player)
	end

	-- Update particles based on speed
	if instances.particles then
		local shouldEmit = speed >= TRAIL_CONFIG.TrailParticlesSpeedMin
		instances.particles.Enabled = shouldEmit
		-- Particles keep their default color (white) as configured in createTrailParticles
	end
end

-- Clean up trail for a character
local function cleanupTrail(char)
	if not char then
		return
	end

	local instances = trailInstances[char]
	if instances then
		if instances.main then
			instances.main:Destroy()
		end
		if instances.leftHand then
			instances.leftHand:Destroy()
		end
		if instances.rightHand then
			instances.rightHand:Destroy()
		end
		if instances.particles then
			instances.particles:Destroy()
		end
		trailInstances[char] = nil
	end
end

-- Set equipped trail
local function setEquippedTrail(trailId, player)
	local targetTrailId = trailId or "default"

	if isServer then
		-- Server: Store per-player trail data
		if player then
			playerTrailData[player] = targetTrailId
		end
	else
		-- Client: Only update local trail if it's for the local player
		if player == Players.LocalPlayer then
			currentEquippedTrail = targetTrailId
		end
	end

	-- Update all existing trails
	for char, instances in pairs(trailInstances) do
		local charPlayer = isServer and Players:GetPlayerFromCharacter(char) or nil
		local trailPlayer = player or charPlayer

		if instances.main then
			updateTrailColor(instances.main, TRAIL_CONFIG.TrailSpeedMax * 0.6, trailPlayer)
		end
		if instances.leftHand then
			updateTrailColor(instances.leftHand, TRAIL_CONFIG.TrailSpeedMax * 0.6, trailPlayer)
		end
		if instances.rightHand then
			updateTrailColor(instances.rightHand, TRAIL_CONFIG.TrailSpeedMax * 0.6, trailPlayer)
		end
	end
end

-- Get current equipped trail
local function getEquippedTrail()
	return currentEquippedTrail
end

-- Main update loop (client only)
if isClient then
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	-- Note: Trails are now created by the server for all players
	-- Client doesn't need to create trails as they replicate from server

	-- Update loop
	RunService.Heartbeat:Connect(function()
		if character and character.Parent then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				local velocity = humanoidRootPart.Velocity
				local speed = velocity.Magnitude

				updateTrail(character, speed, player)
			end
		end
	end)

	-- Handle character respawning
	player.CharacterAdded:Connect(function(newCharacter)
		character = newCharacter
		humanoid = character:WaitForChild("Humanoid")
		-- Server will create trails automatically
	end)

	-- Listen for trail equipment updates
	local TrailEquipped = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TrailEquipped")
	TrailEquipped.OnClientEvent:Connect(function(targetPlayer, trailId)
		-- Only update local trail data if it's for the local player
		if targetPlayer == Players.LocalPlayer then
			setEquippedTrail(trailId, targetPlayer)
		end
		-- Server handles all trail updates, client just needs to know the equipped trail
	end)
end

-- Server-side: Handle all players
if isServer then
	local activePlayers = {} -- Track active players for trail updates
	local updateConnection -- Store the update loop connection

	local lastUpdateTimes = {} -- Track last update time per player
	local UPDATE_INTERVAL = 0.1 -- Update trails every 100ms instead of every frame
	local SPEED_THRESHOLD = 1 -- Only update if speed changed significantly

	local function startTrailUpdateLoop()
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

			-- Update trails for all active players with optimizations
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
							updateTrail(player.Character, speed, player)
							lastUpdateTimes[player] = { speed = speed, time = tick() }
						end
					end
				end
			end
		end)
	end

	local function stopTrailUpdateLoop()
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

			-- Create trail for the player
			createTrail(character)

			-- Set default trail if not set
			if not playerTrailData[player] then
				playerTrailData[player] = "default"
			end

			-- Start update loop if this is the first player
			if not updateConnection then
				startTrailUpdateLoop()
			end

			-- Reduced logging for performance
		end)

		player.CharacterRemoving:Connect(function(character)
			cleanupTrail(character)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		activePlayers[player] = nil
		playerTrailData[player] = nil
		lastUpdateTimes[player] = nil -- Clean up update tracking

		if player.Character then
			cleanupTrail(player.Character)
		end

		-- Stop update loop if no active players
		if next(activePlayers) == nil then
			stopTrailUpdateLoop()
		end
	end)

	-- Listen for trail equipment updates
	local TrailEquipped = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TrailEquipped")
	TrailEquipped.OnServerEvent:Connect(function(player, trailId)
		-- Update trail for this player
		setEquippedTrail(trailId, player)
		if player.Character then
			-- Force immediate update by resetting update tracking
			lastUpdateTimes[player] = nil
			-- Update the player's trail immediately
			updateTrail(player.Character, TRAIL_CONFIG.TrailSpeedMax * 0.6, player)
		end
	end)

	-- Initialize existing players
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			activePlayers[player] = true
			createTrail(player.Character)
			-- Initialize trail data for existing players
			if not playerTrailData[player] then
				playerTrailData[player] = "default"
			end
			-- Force initial trail update
			updateTrail(player.Character, 0, player)
		end
	end

	-- Start update loop if there are players
	if next(activePlayers) ~= nil then
		startTrailUpdateLoop()
	end
end

-- Export functions for external use
return {
	createTrail = createTrail,
	updateTrail = updateTrail,
	cleanupTrail = cleanupTrail,
	setEquippedTrail = setEquippedTrail,
	getEquippedTrail = getEquippedTrail,
	getCurrentTrailColor = getCurrentTrailColor,
}
