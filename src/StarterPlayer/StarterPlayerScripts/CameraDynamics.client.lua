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

local state = {
	character = nil,
	humanoid = nil,
	root = nil,
	baseFov = Config.CameraBaseFov or 70,
	maxFov = Config.CameraMaxFov or 84,
	fovLerpRate = math.max(0.01, Config.CameraFovLerpPerSecond or 6),
	fovSprintBonus = Config.CameraFovSprintBonus or 0,
	shakeAmpMin = Config.CameraShakeAmplitudeMinDeg or 0,
	shakeAmpMax = Config.CameraShakeAmplitudeMaxDeg or 1.0,
	shakeFreq = Config.CameraShakeFrequencyHz or 7.0,
	shakeSprintMul = Config.CameraShakeSprintMultiplier or 1.5,
	shakeAirMul = Config.CameraShakeAirborneMultiplier or 0.8,
	windEnabled = Config.SpeedWindEnabled ~= false,
	noiseT = 0,
	fxPart = nil,
	fxAttachment = nil,
	windEmitter = nil,
}

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

local function ensureWindRig()
	if not state.windEnabled then
		return nil, nil
	end
	if state.fxPart and state.fxPart.Parent and state.windEmitter and state.windEmitter.Parent then
		return state.fxPart, state.windEmitter
	end
	local part = Instance.new("Part")
	part.Name = "CameraFX"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Locked = true
	part.Parent = workspace
	local att = Instance.new("Attachment")
	att.Name = "FX"
	att.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Wind"
	emitter.LightInfluence = 0
	emitter.ZOffset = 0
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.LockedToPart = false
	emitter.Enabled = true
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 - (Config.SpeedWindOpacity or 0.35)),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(1, 0.04),
	})
	emitter.Texture = "rbxassetid://2416355141" -- soft streak
	emitter.Lifetime = NumberRange.new(Config.SpeedWindLifetime or 0.15)
	emitter.Rate = 0 -- manual emit
	emitter.Speed = NumberRange.new(0, 0)
	emitter.Rotation = NumberRange.new(0, 0)
	emitter.RotSpeed = NumberRange.new(0, 0)
	emitter.SpreadAngle = Vector2.new(0, 0)
	emitter.Parent = att
	state.fxPart = part
	state.fxAttachment = att
	state.windEmitter = emitter
	return part, emitter
end

local function emitWind(speed, dt)
	local part, emitter = ensureWindRig()
	if not (part and emitter and camera) then
		return
	end
	-- Place rig in front of camera and orient with it
	local c = camera.CFrame
	local look = c.LookVector
	local pos = c.Position + look * 2
	part.CFrame = CFrame.new(pos, pos + look)
	-- Adjust acceleration backwards
	emitter.Acceleration = (Config.SpeedWindAccelFactor or 28) * -look
	-- Compute emission count
	local minSpeed = Config.SpeedWindMinSpeed or 24
	local maxSpeed = Config.SpeedWindMaxSpeed or 85
	local frac = math.clamp((speed - minSpeed) / math.max(1, (maxSpeed - minSpeed)), 0, 1)
	if frac <= 0 then
		return
	end
	local rateMin = Config.SpeedWindRateMin or 6
	local rateMax = Config.SpeedWindRateMax or 50
	local rate = lerp(rateMin, rateMax, frac) -- particles per second
	local count = math.clamp(math.floor(rate * dt + 0.5), 0, 80)
	if count <= 0 then
		return
	end
	-- Emit with slight angle jitter by brief spread tweaks
	local spreadX = (Config.SpeedWindSpreadX or 0.4) * 30 -- degrees approx
	local spreadY = (Config.SpeedWindSpreadY or 0.6) * 30
	emitter.SpreadAngle = Vector2.new(spreadX, spreadY)
	emitter:Emit(count)
end

local function getClientMomentum()
	local cs = ensureClientStateFolder()
	local v = cs:FindFirstChild("Momentum")
	return (v and v.Value) or 0
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
		local vy = v.Y
		local cs = ensureClientStateFolder()
		local isSprinting = (cs:FindFirstChild("IsSprinting") and cs.IsSprinting.Value) or false
		local airborne = state.humanoid.FloorMaterial == Enum.Material.Air
		local momentum = getClientMomentum()

		-- FOV target based on combined metric: horizontal speed and momentum
		local sMin = Config.CameraFovSpeedMin or 10
		local sMax = math.max(Config.CameraFovSpeedMax or 80, Config.AirControlTotalSpeedCap or 85)
		local speedFrac = math.clamp((horizSpeed - sMin) / math.max(1, (sMax - sMin)), 0, 1)
		local momFrac = math.clamp((momentum or 0) / math.max(1, (Config.MomentumMax or 100)), 0, 1)
		local mixFrac = math.clamp((speedFrac * 0.6) + (momFrac * 0.4), 0, 1)
		local baseTarget = lerp(state.baseFov, state.maxFov, mixFrac)
		local targetFov = baseTarget + (isSprinting and state.fovSprintBonus or 0)
		-- Clamp to safe range
		targetFov = math.clamp(targetFov, state.baseFov, state.maxFov + math.max(0, state.fovSprintBonus))
		camera.FieldOfView = smoothTowards(camera.FieldOfView, targetFov, state.fovLerpRate, dt)

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
			emitWind(horizSpeed, dt)
		end
	end)
end

setup()
