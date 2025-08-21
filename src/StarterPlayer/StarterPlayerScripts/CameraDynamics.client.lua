-- CameraDynamics: dynamic FOV, subtle shake, and wind feedback based on speed
-- Place under StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Movement.Config)

if Config.CameraDynamicsEnabled == false then
	return
end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local terrain = workspace:FindFirstChildOfClass("Terrain")

local state = {
	character = nil,
	humanoid = nil,
	root = nil,
	baseFov = Config.CameraBaseFov or 70,
	maxFov = Config.CameraMaxFov or 84,
	fovLerpRate = math.max(0.01, Config.CameraFovLerpPerSecond or 6),
	fovLerpUp = math.max(0.01, Config.CameraFovLerpUpPerSecond or (Config.CameraFovLerpPerSecond or 6)),
	fovLerpDown = math.max(0.01, Config.CameraFovLerpDownPerSecond or (Config.CameraFovLerpPerSecond or 6)),
	fovUpDegPerSec = math.max(0, Config.CameraFovUpDegPerSecond or 0),
	fovDownDegPerSec = math.max(0, Config.CameraFovDownDegPerSecond or 0),
	fovSprintBonus = Config.CameraFovSprintBonus or 0,
	shakeAmpMin = Config.CameraShakeAmplitudeMinDeg or 0,
	shakeAmpMax = Config.CameraShakeAmplitudeMaxDeg or 1.0,
	shakeFreq = Config.CameraShakeFrequencyHz or 7.0,
	shakeSprintMul = Config.CameraShakeSprintMultiplier or 1.5,
	shakeAirMul = Config.CameraShakeAirborneMultiplier or 0.8,
	windEnabled = Config.SpeedWindEnabled ~= false,
	noiseT = 0,
}

-- Wind Lines System (based on Dylian1235's approach with Trails)
local windLines = {}
local lastWindSpawn = 0

local function createSpeedWindLine(speed)
	if not camera or speed <= 0 or not state.root then
		return
	end

	-- Get camera and character positions
	local cameraCFrame = camera.CFrame
	local characterPos = state.root.Position

	-- Calculate direction from camera towards character (where the wind should flow)
	local cameraToCharacter = (characterPos - cameraCFrame.Position).Unit

	-- Calculate spawn position: in front of camera but scattered around the view
	local minDist = Config.SpeedWindLinesSpawnDistanceMin or 20
	local maxDist = Config.SpeedWindLinesSpawnDistanceMax or 45
	local spawnDistance = math.random(minDist, maxDist)

	local maxAngleX = Config.SpeedWindLinesSpawnAngleX or 35
	local maxAngleY = Config.SpeedWindLinesSpawnAngleY or 50
	local angleX = math.rad(math.random(-maxAngleX, maxAngleX))
	local angleY = math.rad(math.random(-maxAngleY, maxAngleY))

	-- Add forward offset to push lines further ahead
	local forwardOffset = Config.SpeedWindLinesSpawnForwardOffset or 15

	-- Spawn position is offset from camera with some randomness, plus forward push
	local spawnOffset = (cameraCFrame * CFrame.Angles(angleX, angleY, 0) * CFrame.new(0, 0, spawnDistance)).Position
	local spawnPos = cameraCFrame.Position
		+ (spawnOffset - cameraCFrame.Position)
		+ (cameraCFrame.LookVector * forwardOffset)

	-- Create attachments for the trail
	local attachment0 = Instance.new("Attachment")
	local attachment1 = Instance.new("Attachment")

	-- Create trail with configurable appearance
	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.FaceCamera = true

	-- Configurable color
	local windColor = Config.SpeedWindLinesColor or Color3.new(0.7, 0.8, 1)
	trail.Color = ColorSequence.new(windColor)

	-- Configurable transparency
	local opacityStart = Config.SpeedWindLinesOpacityStart or 0.4
	local opacityEnd = Config.SpeedWindLinesOpacityEnd or 1.0
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opacityStart),
		NumberSequenceKeypoint.new(1, opacityEnd),
	})

	-- Configurable width scaling
	local widthStart = Config.SpeedWindLinesWidthStart or 0.3
	local widthMiddle = Config.SpeedWindLinesWidthMiddle or 1.2
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, widthStart),
		NumberSequenceKeypoint.new(0.3, widthMiddle),
		NumberSequenceKeypoint.new(0.7, widthMiddle),
		NumberSequenceKeypoint.new(1, widthStart),
	})

	-- Configurable length based on speed
	local lengthBase = Config.SpeedWindLinesLengthBase or 18
	local lengthSpeedFactor = Config.SpeedWindLinesLengthSpeedFactor or 0.25
	local lengthMin = Config.SpeedWindLinesLengthMin or 12
	local lengthMax = Config.SpeedWindLinesLengthMax or 35
	local trailLength = math.clamp(lengthBase + speed * lengthSpeedFactor, lengthMin, lengthMax)

	trail.MinLength = 0
	trail.MaxLength = trailLength
	trail.Lifetime = 0.6
	trail.Parent = attachment0

	-- Set initial positions
	local offset = Vector3.new(0, 0.05, 0)
	attachment0.WorldPosition = spawnPos
	attachment1.WorldPosition = spawnPos + offset

	-- Parent to terrain for performance
	attachment0.Parent = terrain
	attachment1.Parent = terrain

	-- Calculate wind direction: from spawn position towards character (simulating wind flowing past camera)
	local windDirection = cameraToCharacter

	-- Configurable wind speed
	local speedFactor = Config.SpeedWindLinesSpeedFactor or 0.3
	local speedVariation = Config.SpeedWindLinesSpeedVariation or 0.2
	local baseWindSpeed = speed * speedFactor
	local windSpeed = baseWindSpeed + (math.random(-speedVariation, speedVariation) * baseWindSpeed)
	windSpeed = math.max(windSpeed, 5) -- minimum speed

	-- Configurable lifetime
	local lifetimeMin = Config.SpeedWindLinesLifetimeMin or 0.8
	local lifetimeMax = Config.SpeedWindLinesLifetimeMax or 1.3
	local lifetime = math.random(lifetimeMin * 100, lifetimeMax * 100) * 0.01

	-- Store wind line data with initial direction frozen
	local windLine = {
		attachment0 = attachment0,
		attachment1 = attachment1,
		trail = trail,
		startTime = tick(),
		lifetime = lifetime,
		initialPosition = spawnPos, -- fixed spawn position
		direction = windDirection, -- direction flows from camera towards character
		speed = windSpeed,
		seed = math.random(1, 1000) * 0.1,
		maxLength = trailLength,
	}

	table.insert(windLines, windLine)
end

local function updateSpeedWindLines()
	local currentTime = tick()

	-- Update existing wind lines
	for i = #windLines, 1, -1 do
		local windLine = windLines[i]
		local aliveTime = currentTime - windLine.startTime

		-- Remove expired wind lines
		if aliveTime >= windLine.lifetime then
			if windLine.attachment0 and windLine.attachment0.Parent then
				windLine.attachment0:Destroy()
			end
			if windLine.attachment1 and windLine.attachment1.Parent then
				windLine.attachment1:Destroy()
			end
			if windLine.trail and windLine.trail.Parent then
				windLine.trail:Destroy()
			end
			table.remove(windLines, i)
		else
			-- Keep the line moving in its original direction for straight lines
			local moveDistance = windLine.speed * aliveTime
			local basePos = windLine.initialPosition + (windLine.direction * moveDistance)

			-- Update position with configurable wave motion for natural feel
			local waveSpeed = Config.SpeedWindLinesWaveSpeed or 0.15
			local seededTime = (currentTime + windLine.seed) * (windLine.speed * waveSpeed)

			-- Configurable wave amplitudes
			local waveAmpX = Config.SpeedWindLinesWaveAmplitudeX or 1.0
			local waveAmpY = Config.SpeedWindLinesWaveAmplitudeY or 1.5
			local waveAmpZ = Config.SpeedWindLinesWaveAmplitudeZ or 0.8

			-- Apply subtle wave motion in world space (not camera relative to avoid curves)
			local waveMotion = Vector3.new(
				math.sin(seededTime) * waveAmpX,
				math.sin(seededTime * 0.7) * waveAmpY,
				math.sin(seededTime * 1.3) * waveAmpZ
			)

			local newPos = basePos + waveMotion

			windLine.attachment0.WorldPosition = newPos
			windLine.attachment1.WorldPosition = newPos + Vector3.new(0, 0.05, 0)

			-- Fade trail length over time for smooth disappearance
			local fadeFactor = 1 - (aliveTime / windLine.lifetime)
			windLine.trail.MaxLength = windLine.maxLength * fadeFactor
		end
	end
end

local function updateSpeedWind(speed)
	-- Check if wind lines are enabled
	if not (Config.SpeedWindLinesEnabled ~= false and state.windEnabled) then
		return
	end

	local minSpeed = Config.SpeedWindLinesMinSpeed or 18
	local maxSpeed = Config.SpeedWindLinesMaxSpeed or 80

	if speed >= minSpeed then
		local currentTime = tick()
		local speedFrac = math.clamp((speed - minSpeed) / (maxSpeed - minSpeed), 0, 1)

		-- Calculate spawn rate based on speed using new config
		local minRate = Config.SpeedWindLinesRateMin or 12
		local maxRate = Config.SpeedWindLinesRateMax or 35
		local spawnRate = minRate + (maxRate - minRate) * speedFrac
		local timeBetweenSpawns = 1 / spawnRate

		-- Spawn new wind lines
		if currentTime - lastWindSpawn >= timeBetweenSpawns then
			createSpeedWindLine(speed)
			lastWindSpawn = currentTime
		end
	end

	-- Always update existing wind lines
	updateSpeedWindLines()
end

local function ensureClientStateFolder()
	local cs = ReplicatedStorage:FindFirstChild("ClientState")
	if not cs then
		cs = Instance.new("Folder")
		cs.Name = "ClientState"
		cs.Parent = ReplicatedStorage
	end
	return cs
end

local function getCharacter()
	local char = player.Character or player.CharacterAdded:Wait()
	local humanoid = char:WaitForChild("Humanoid")
	local root = char:WaitForChild("HumanoidRootPart")
	return char, humanoid, root
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smoothTowards(cur, target, rate, dt)
	local alpha = 1 - math.exp(-rate * dt)
	return lerp(cur, target, alpha)
end

-- Simple 1D noise using sin/cos blend
local function noise1(t)
	return math.sin(t * 1.7) * 0.6 + math.cos(t * 2.3) * 0.4
end

local function getClientMomentum()
	local cs = ensureClientStateFolder()
	local v = cs:FindFirstChild("Momentum")
	return (v and v.Value) or 0
end

local function getClientSpeed()
	local cs = ensureClientStateFolder()
	local v = cs:FindFirstChild("Speed")
	return (v and v.Value) or nil
end

local function cleanupWindLines()
	for _, windLine in ipairs(windLines) do
		if windLine.attachment0 and windLine.attachment0.Parent then
			windLine.attachment0:Destroy()
		end
		if windLine.attachment1 and windLine.attachment1.Parent then
			windLine.attachment1:Destroy()
		end
		if windLine.trail and windLine.trail.Parent then
			windLine.trail:Destroy()
		end
	end
	table.clear(windLines)
end

local function setup()
	state.character, state.humanoid, state.root = getCharacter()
	-- Ensure baseline FOV
	if camera then
		camera.FieldOfView = state.baseFov
	end
	-- Reset on respawn
	Players.LocalPlayer.CharacterAdded:Connect(function()
		state.character, state.humanoid, state.root = getCharacter()
		-- Clean up old wind lines
		cleanupWindLines()
		if camera then
			camera.FieldOfView = state.baseFov
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not (camera and state.root and state.humanoid) then
			return
		end
		local v = state.root.AssemblyLinearVelocity
		local horizSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
		local fullSpeed = getClientSpeed() or v.Magnitude
		local vy = v.Y
		local cs = ensureClientStateFolder()
		local isSprinting = (cs:FindFirstChild("IsSprinting") and cs.IsSprinting.Value) or false
		local airborne = state.humanoid.FloorMaterial == Enum.Material.Air
		local momentum = getClientMomentum()

		-- FOV cap: allow high speeds (hooks/pads) to exceed base max by extraFromSpeed
		local extraFromSpeed = Config.CameraFovExtraFromSpeed
		if extraFromSpeed == nil then
			extraFromSpeed = state.fovSprintBonus or 0
		end
		local fovCap = state.maxFov + math.max(0, extraFromSpeed)

		-- FOV target based on combined metric: full speed (same as HUD SpeedText) and momentum
		local sMin = Config.CameraFovSpeedMin or 10
		local sMax = math.max(Config.CameraFovSpeedMax or 80, Config.AirControlTotalSpeedCap or 85)
		local speedFrac = math.clamp((fullSpeed - sMin) / math.max(1, (sMax - sMin)), 0, 1)
		local momFrac = math.clamp((momentum or 0) / math.max(1, (Config.MomentumMax or 100)), 0, 1)
		local baseWM = math.clamp(Config.CameraFovMomentumWeight or 0.7, 0, 1)
		-- Gate momentum influence by current speed so FOV drops quickly when speed is low
		local gatedWM = baseWM * speedFrac
		local mixFrac = math.clamp((speedFrac * (1 - gatedWM)) + (momFrac * gatedWM), 0, 1)
		local baseTarget
		if fullSpeed <= sMin * 0.9 then
			-- Hard reset to base when below threshold to avoid long tails
			baseTarget = state.baseFov
		else
			baseTarget = lerp(state.baseFov, fovCap, mixFrac)
		end
		-- Smooth sprint bonus by speed to avoid discrete step at base+bonus
		local sprintWeight = (isSprinting and speedFrac) or 0
		local targetFov = math.min(fovCap, baseTarget + (state.fovSprintBonus * sprintWeight))

		-- Asymmetric smoothing: ramp up slower, decay faster
		local cur = camera.FieldOfView
		local rate = (targetFov < cur) and state.fovLerpDown or state.fovLerpUp
		local smoothed = smoothTowards(cur, targetFov, rate, dt)
		-- Linear clamp (deg/s) to guarantee prompt decay
		local maxDelta = (targetFov < cur) and (state.fovDownDegPerSec * dt) or (state.fovUpDegPerSec * dt)
		if state.fovDownDegPerSec > 0 or state.fovUpDegPerSec > 0 then
			local delta = smoothed - cur
			local clamped
			if delta > 0 then
				clamped = math.min(delta, maxDelta)
			else
				clamped = math.max(delta, -maxDelta)
			end
			camera.FieldOfView = cur + clamped
		else
			camera.FieldOfView = smoothed
		end

		-- Subtle procedural shake only while falling downward
		if Config.CameraShakeEnabled ~= false then
			if airborne and vy < -0.5 then
				state.noiseT = state.noiseT + dt * (state.shakeFreq or 7)
				local n1 = noise1(state.noiseT)
				local n2 = noise1(state.noiseT * 0.7 + 1.234)
				local n3 = noise1(state.noiseT * 1.3 + 2.468)
				local ampBase = lerp(state.shakeAmpMin, state.shakeAmpMax, mixFrac)
				local pitch = math.rad(ampBase * n1)
				local yaw = math.rad(ampBase * n2 * 0.5)
				local roll = math.rad(ampBase * n3 * 0.7)
				local cf = camera.CFrame
				camera.CFrame = cf * CFrame.Angles(pitch, yaw, roll)
			end
		end

		-- Wind feedback when fast
		if state.windEnabled then
			updateSpeedWind(fullSpeed)
		end
	end)
end

setup()
