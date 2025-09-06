-- ParticleSystem.client.lua
-- Self-contained client-side UI Particle System
-- Automatically initializes and manages particle effects

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Particle System Configuration
local DEFAULT_CONFIG = {
	MAX_PARTICLES = 20,
	LIFETIME = 5.0,
	MAX_SCALE = 1.0, -- Will be set to original image size by default
	ROTATION_SPEED = 120, -- degrees per second
	SPEED = 100, -- pixels per second
	DELAY_BETWEEN_SPAWNS = 0.2, -- seconds
	COOLDOWN = 1.0, -- seconds between particle spawns
	AREA = "All", -- Where particles spawn: "All", "Border", "Center", "Top", "Right", "Left", "Bottom". Border/edges appear inside from edges
	EASING_STYLE = "Quart", -- TweenService easing style: "Linear", "Sine", "Back", "Bounce", "Elastic", "Quad", "Quart", "Quint", "Exponential", "Circ"
	EASING_DIRECTION = "Out", -- TweenService easing direction: "In", "Out", "InOut"
	STAGGERED = false, -- If true, particles appear staggered (one by one); if false, all at once
	STAGGER_PERCENT = 0.4, -- Percentage of lifetime to wait before spawning next particle (0.1 = 10%, 0.5 = 50%)
	VISIBLE_TIME = 0.25, -- Time in seconds that particle stays fully visible AFTER fade-in completes (independent of Lifetime)
}

-- Pool configuration for memory management
local POOL_CONFIG = {
	MAX_POOL_SIZE = 100, -- Maximum number of particles that can be stored in the pool
}

-- Update throttling configuration
local UPDATE_CONFIG = {
	UPDATE_INTERVAL = 1 / 30, -- Update at 30 FPS instead of 60 FPS to reduce CPU usage
}

-- Culling configuration for performance
local CULLING_CONFIG = {
	ENABLE_CONTAINER_CULLING = true, -- Disable updates for invisible containers
}

-- System state
local activeParticles = {}
local particlePool = {} -- Pool for reusing particles
local isInitialized = false

-- Particle System Functions
local ParticleSystem = {}

-- Function to convert string easing to TweenService enum
local function getEasingStyle(style)
	local styleMap = {
		["Linear"] = Enum.EasingStyle.Linear,
		["Sine"] = Enum.EasingStyle.Sine,
		["Back"] = Enum.EasingStyle.Back,
		["Bounce"] = Enum.EasingStyle.Bounce,
		["Elastic"] = Enum.EasingStyle.Elastic,
		["Quad"] = Enum.EasingStyle.Quad,
		["Quart"] = Enum.EasingStyle.Quart,
		["Quint"] = Enum.EasingStyle.Quint,
		["Exponential"] = Enum.EasingStyle.Exponential, -- Correct name
		["Circular"] = Enum.EasingStyle.Circular,
	}
	return styleMap[style] or Enum.EasingStyle.Quart
end

local function getEasingDirection(direction)
	local directionMap = {
		["In"] = Enum.EasingDirection.In,
		["Out"] = Enum.EasingDirection.Out,
		["InOut"] = Enum.EasingDirection.InOut,
	}
	return directionMap[direction] or Enum.EasingDirection.Out
end

-- Optimized tween creation helper to batch similar operations
local function createOptimizedTweens(particleImage, config, totalParticleTime)
	local easingStyle = getEasingStyle(config.EASING_STYLE)
	local easingDirection = getEasingDirection(config.EASING_DIRECTION)

	-- Create tweens with optimized settings
	local uiScale = particleImage:FindFirstChild("UIScale")
	local scaleTween = TweenService:Create(
		uiScale,
		TweenInfo.new(totalParticleTime, easingStyle, easingDirection),
		{ Scale = config.MAX_SCALE }
	)

	-- Transparency timing
	local fadeInTime = 0.2
	local visibleTime = config.VISIBLE_TIME
	local fadeOutTime = 0.3

	local fadeInTween = TweenService:Create(
		particleImage,
		TweenInfo.new(fadeInTime, easingStyle, easingDirection),
		{ ImageTransparency = 0 }
	)

	local fadeOutTween = TweenService:Create(
		particleImage,
		TweenInfo.new(fadeOutTime, easingStyle, easingDirection),
		{ ImageTransparency = 1 }
	)

	local rotationTween = TweenService:Create(
		particleImage,
		TweenInfo.new(totalParticleTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ Rotation = config.ROTATION_SPEED * totalParticleTime }
	)

	-- Movement with random velocity
	local velocityX = (math.random() - 0.5) * config.SPEED / 1000
	local velocityY = (math.random() - 0.5) * config.SPEED / 1000
	local currentPos = particleImage.Position
	local targetPos = UDim2.new(
		currentPos.X.Scale + velocityX * totalParticleTime,
		currentPos.X.Offset,
		currentPos.Y.Scale + velocityY * totalParticleTime,
		currentPos.Y.Offset
	)

	local movementTween = TweenService:Create(
		particleImage,
		TweenInfo.new(totalParticleTime, easingStyle, easingDirection),
		{ Position = targetPos }
	)

	return {
		scale = scaleTween,
		fadeIn = fadeInTween,
		fadeOut = fadeOutTween,
		rotation = rotationTween,
		movement = movementTween,
	}
end

-- Function to get random position based on area type
local function getRandomPositionInArea(area, containerSize)
	local randomX, randomY = 0, 0

	if area == "All" then
		-- Random position anywhere in the container
		randomX = math.random(0, 100) / 100
		randomY = math.random(0, 100) / 100
	elseif area == "Border" then
		-- Only on the edges, particles appear at edge with minimal offset
		local edge = math.random(1, 4) -- 1=top, 2=right, 3=bottom, 4=left
		if edge == 1 then -- Top edge
			randomX = math.random(0, 100) / 100 -- Full width
			randomY = math.random(0, 5) / 100 -- Inside from top edge
		elseif edge == 2 then -- Right edge
			randomX = math.random(95, 98) / 100 -- Inside from right edge
			randomY = math.random(0, 100) / 100 -- Full height
		elseif edge == 3 then -- Bottom edge
			randomX = math.random(0, 100) / 100 -- Full width
			randomY = math.random(95, 98) / 100 -- Inside from bottom edge
		elseif edge == 4 then -- Left edge
			randomX = math.random(2, 5) / 100 -- Inside from left edge
			randomY = math.random(0, 100) / 100 -- Full height
		end
	elseif area == "Center" then
		-- Only in the center area
		randomX = math.random(30, 70) / 100 -- Center 40%
		randomY = math.random(30, 70) / 100 -- Center 40%
	elseif area == "Top" then
		-- Only on top edge, particles appear inside from edge
		randomX = math.random(0, 100) / 100 -- Full width
		randomY = math.random(0, 5) / 100 -- Inside from top edge
	elseif area == "Right" then
		-- Only on right edge, particles appear inside from edge
		randomX = math.random(95, 98) / 100 -- Inside from right edge
		randomY = math.random(0, 100) / 100 -- Full height
	elseif area == "Left" then
		-- Only on left edge, particles appear inside from edge
		randomX = math.random(2, 5) / 100 -- Inside from left edge
		randomY = math.random(0, 100) / 100 -- Full height
	elseif area == "Bottom" then
		-- Only on bottom edge, particles appear inside from edge
		randomX = math.random(0, 100) / 100 -- Full width
		randomY = math.random(95, 98) / 100 -- Inside from bottom edge
	else
		-- Fallback to "All" if invalid area
		randomX = math.random(0, 100) / 100
		randomY = math.random(0, 100) / 100
	end

	return randomX, randomY
end

function ParticleSystem.init()
	if isInitialized then
		return
	end

	-- Set up automatic detection of tagged elements
	CollectionService:GetInstanceAddedSignal("Particle"):Connect(function(element)
		if element:IsA("GuiObject") then
			ParticleSystem.createEmitterForImage(element)
		end
	end)

	-- Check for existing tagged elements
	for _, element in ipairs(CollectionService:GetTagged("Particle")) do
		if element:IsA("GuiObject") then
			ParticleSystem.createEmitterForImage(element)
		end
	end

	isInitialized = true
end

function ParticleSystem.createEmitterForImage(image)
	-- Simple particle creation
	local container = image.Parent
	if not container then
		return
	end

	local config = DEFAULT_CONFIG

	-- Read all the new attributes
	config.SPEED = image:GetAttribute("Speed") or config.SPEED
	config.LIFETIME = image:GetAttribute("Lifetime") or config.LIFETIME
	config.MAX_PARTICLES = image:GetAttribute("Particles") or config.MAX_PARTICLES
	config.ROTATION_SPEED = image:GetAttribute("RotationSpeed") or config.ROTATION_SPEED
	config.COOLDOWN = image:GetAttribute("Cooldown") or config.COOLDOWN
	config.AREA = image:GetAttribute("Area") or config.AREA
	config.EASING_STYLE = image:GetAttribute("EasingStyle") or config.EASING_STYLE
	config.EASING_DIRECTION = image:GetAttribute("EasingDirection") or config.EASING_DIRECTION
	config.STAGGERED = image:GetAttribute("Staggered") or config.STAGGERED
	config.STAGGER_PERCENT = image:GetAttribute("StaggerPercent") or config.STAGGER_PERCENT
	config.VISIBLE_TIME = image:GetAttribute("VisibleTime") or config.VISIBLE_TIME

	-- For MaxScale, if not specified, use the original image size as default
	local maxScale = image:GetAttribute("MaxScale")
	if maxScale then
		config.MAX_SCALE = maxScale
	else
		-- Use original image size as default max scale
		local originalSize = math.max(image.AbsoluteSize.X, image.AbsoluteSize.Y)
		config.MAX_SCALE = originalSize / 20 -- Normalize to base size of 20
	end

	-- Store the image ID from the original element
	local imageID = image.Image

	-- Hide the original image (only particles should be visible)
	image.Visible = false

	-- Create simple emitter with original image reference and ID
	ParticleSystem.startEmission(container, config, image, imageID)
end

function ParticleSystem.startEmission(container, config, originalImage, imageID)
	config = config or DEFAULT_CONFIG

	local emitter = {
		container = container,
		config = config,
		particles = {},
		activeParticles = 0, -- Count of currently active particles
		isEmitting = true,
		lastSpawn = 0,
		totalSpawned = 0,
		originalImage = originalImage, -- Store reference to original image
		imageID = imageID, -- Store the image ID explicitly
		lastUpdate = 0, -- For throttling updates
	}

	-- Start emission loop with higher frequency for smoother animations
	emitter.connection = RunService.Heartbeat:Connect(function(dt)
		if emitter.isEmitting then
			ParticleSystem.updateEmitter(emitter, dt)
		end
	end)

	table.insert(activeParticles, emitter)
end

function ParticleSystem.spawnParticle(emitter)
	local particle, particleImage

	-- Check if we have a reusable particle in the pool
	if #particlePool > 0 then
		particle = table.remove(particlePool)
		particleImage = particle.image

		-- Reset particle properties
		particleImage.Visible = true
		particleImage.ImageTransparency = 1 -- Start invisible
		particleImage.Parent = emitter.container

		-- Reset UIScale
		local uiScale = particleImage:FindFirstChild("UIScale")
		if uiScale then
			uiScale.Scale = 0 -- Start at size 0
		else
			-- Create UIScale if it doesn't exist
			uiScale = Instance.new("UIScale")
			uiScale.Scale = 0
			uiScale.Parent = particleImage
		end

		-- Reset rotation
		particleImage.Rotation = 0
	else
		-- Create a new ImageLabel for the particle
		particleImage = Instance.new("ImageLabel")

		-- Set the image ID directly from the stored ID
		if emitter.imageID then
			particleImage.Image = emitter.imageID
		else
			-- Fallback: create a simple colored particle
			local colors = {
				Color3.fromRGB(255, 100, 100), -- Red
				Color3.fromRGB(100, 255, 100), -- Green
				Color3.fromRGB(100, 100, 255), -- Blue
				Color3.fromRGB(255, 255, 100), -- Yellow
				Color3.fromRGB(255, 100, 255), -- Magenta
				Color3.fromRGB(100, 255, 255), -- Cyan
			}
			particleImage.BackgroundColor3 = colors[math.random(1, #colors)]
			particleImage.BackgroundTransparency = 1 -- Always 1 as requested
		end

		-- Override particle-specific properties
		particleImage.Size = UDim2.new(0, 20, 0, 20) -- Base size
		particleImage.ImageTransparency = 1 -- Start invisible
		particleImage.AnchorPoint = Vector2.new(0.5, 0.5)
		particleImage.ZIndex = 100 -- Make sure particles are on top
		particleImage.Visible = true
		particleImage.BackgroundTransparency = 1 -- Always 1 as requested
		particleImage.Rotation = 0

		-- Create UIScale for scaling the particle
		local uiScale = Instance.new("UIScale")
		uiScale.Scale = 0 -- Start at size 0
		uiScale.Parent = particleImage

		-- Copy other properties from original image if available
		if emitter.originalImage then
			particleImage.ImageColor3 = emitter.originalImage.ImageColor3
		end

		particleImage.Parent = emitter.container

		-- Create particle data object
		particle = {
			image = particleImage,
			config = emitter.config,
			emitter = emitter,
			isActive = true,
		}
	end

	-- Random position based on area configuration
	local randomX, randomY = getRandomPositionInArea(emitter.config.AREA, emitter.container.AbsoluteSize)
	particleImage.Position = UDim2.new(randomX, 0, randomY, 0)

	-- Create tweens using optimized batch function
	local totalParticleTime = 0.2 + emitter.config.VISIBLE_TIME + 0.3 -- fadeIn + visible + fadeOut
	local visibleTime = emitter.config.VISIBLE_TIME -- Time to stay visible after fade-in completes

	-- Use optimized tween creation
	particle.tweens = createOptimizedTweens(particleImage, emitter.config, totalParticleTime)

	-- Start all tweens
	particle.tweens.scale:Play()
	particle.tweens.rotation:Play()
	particle.tweens.movement:Play()

	-- Start fade in, wait visible time after fade-in completes, then fade out
	particle.tweens.fadeIn:Play()
	particle.tweens.fadeIn.Completed:Connect(function()
		-- Wait for the specified visible time after fade-in is complete
		task.wait(visibleTime)
		-- Then start fade out
		particle.tweens.fadeOut:Play()
	end)

	-- Set up completion callback for fade-out (when particle is completely gone)
	particle.tweens.fadeOut.Completed:Connect(function()
		-- Recycle particle when fade-out completes
		particleImage.Visible = false
		particleImage.Parent = nil

		-- Only add to pool if we haven't exceeded the maximum pool size
		if #particlePool < POOL_CONFIG.MAX_POOL_SIZE then
			table.insert(particlePool, particle)
		else
			-- Pool is full, destroy the particle instead of recycling
			particle.image:Destroy()
		end

		emitter.activeParticles = emitter.activeParticles - 1

		-- Remove from active particles list
		for i = #emitter.particles, 1, -1 do
			if emitter.particles[i] == particle then
				table.remove(emitter.particles, i)
				break
			end
		end
	end)

	emitter.activeParticles = emitter.activeParticles + 1
	table.insert(emitter.particles, particle)
end

function ParticleSystem.updateEmitter(emitter, dt)
	local now = os.clock()

	-- Throttle updates to reduce CPU usage
	emitter.lastUpdate = emitter.lastUpdate + dt
	if emitter.lastUpdate < UPDATE_CONFIG.UPDATE_INTERVAL then
		return
	end
	emitter.lastUpdate = 0

	-- Container culling: skip updates if container is not visible
	if CULLING_CONFIG.ENABLE_CONTAINER_CULLING and emitter.container then
		if not emitter.container:IsDescendantOf(game) or not emitter.container.Visible then
			return
		end
	end

	-- Initialize staggered spawning variables if not set
	if not emitter.staggeredSpawned then
		emitter.staggeredSpawned = 0 -- How many particles spawned in current group
		emitter.staggeredStartTime = 0 -- When current group started
		emitter.staggeredParticleTimes = {} -- Track when each particle in the group was spawned
	end

	-- Spawn new particles up to the maximum limit with cooldown
	if now - emitter.lastSpawn >= emitter.config.COOLDOWN then
		if emitter.activeParticles < emitter.config.MAX_PARTICLES then
			if emitter.config.STAGGERED then
				-- Staggered spawning: spawn particles in groups
				if emitter.staggeredSpawned == 0 then
					-- Start new group
					emitter.staggeredStartTime = now
					emitter.staggeredSpawned = 1
					emitter.staggeredParticleTimes = { now } -- Track first particle spawn time
					ParticleSystem.spawnParticle(emitter)
					emitter.totalSpawned = emitter.totalSpawned + 1
					emitter.lastSpawn = now -- Set cooldown for next group
				else
					-- Continue current group - check if the NEXT particle should spawn
					-- We need to check if the most recently spawned particle has reached the stagger percentage
					local lastParticleIndex = emitter.staggeredSpawned
					local lastParticleSpawnTime = emitter.staggeredParticleTimes[lastParticleIndex]
					local timeSinceLastSpawn = now - lastParticleSpawnTime
					-- Calculate stagger time based on particle's total time (fade-in + visible + fade-out)
					local particleTotalTime = 0.2 + emitter.config.VISIBLE_TIME + 0.3 -- fadeIn + visible + fadeOut
					local staggerTime = particleTotalTime * emitter.config.STAGGER_PERCENT

					-- Only spawn the next particle if the last one has reached the stagger percentage
					if
						timeSinceLastSpawn >= staggerTime
						and emitter.staggeredSpawned < emitter.config.MAX_PARTICLES
					then
						emitter.staggeredSpawned = emitter.staggeredSpawned + 1
						emitter.staggeredParticleTimes[emitter.staggeredSpawned] = now -- Track new particle spawn time
						ParticleSystem.spawnParticle(emitter)
						emitter.totalSpawned = emitter.totalSpawned + 1
					end
				end

				-- Check if group is complete
				if emitter.staggeredSpawned >= emitter.config.MAX_PARTICLES then
					emitter.staggeredSpawned = 0 -- Reset for next group
					emitter.staggeredParticleTimes = {} -- Clear particle times
				end
			else
				-- Non-staggered spawning: spawn multiple particles at once
				if emitter.config.AREA ~= "All" then
					local particlesToSpawn = math.min(emitter.config.MAX_PARTICLES - emitter.activeParticles, 3)
					for i = 1, particlesToSpawn do
						ParticleSystem.spawnParticle(emitter)
						emitter.totalSpawned = emitter.totalSpawned + 1
					end
				else
					-- For "All" area, spawn one particle at a time
					ParticleSystem.spawnParticle(emitter)
					emitter.totalSpawned = emitter.totalSpawned + 1
				end
				emitter.lastSpawn = now
			end
		end
	end

	-- No need to update particles manually - TweenService handles it automatically
end

function ParticleSystem.stopEmission(container)
	for i, emitter in ipairs(activeParticles) do
		if emitter.container == container then
			emitter.isEmitting = false
			if emitter.connection then
				emitter.connection:Disconnect()
				emitter.connection = nil
			end
			-- Cancel all tweens and recycle particles to the pool
			for _, particle in ipairs(emitter.particles) do
				if particle.tweens then
					-- Cancel all tweens and clear connections
					for tweenName, tween in pairs(particle.tweens) do
						if tween then
							tween:Cancel()
							particle.tweens[tweenName] = nil
						end
					end
					-- Clear the tweens table
					particle.tweens = nil
				end

				if particle.image then
					particle.image.Visible = false
					particle.image.Parent = nil
					-- Only add to pool if we haven't exceeded the maximum pool size
					if #particlePool < POOL_CONFIG.MAX_POOL_SIZE then
						table.insert(particlePool, particle)
					else
						-- Pool is full, destroy the particle
						particle.image:Destroy()
					end
				end
			end
			-- Clear the particles array
			emitter.particles = {}
			table.remove(activeParticles, i)
			break
		end
	end
end

function ParticleSystem.getStats()
	local totalParticles = 0
	for _, emitter in ipairs(activeParticles) do
		totalParticles = totalParticles + #emitter.particles
	end

	return {
		isInitialized = isInitialized,
		activeEmitters = #activeParticles,
		totalParticles = totalParticles,
	}
end

function ParticleSystem.cleanup()
	for _, emitter in ipairs(activeParticles) do
		if emitter.connection then
			emitter.connection:Disconnect()
			emitter.connection = nil
		end
		for _, particle in ipairs(emitter.particles) do
			-- Cancel and clean up tweens
			if particle.tweens then
				for tweenName, tween in pairs(particle.tweens) do
					if tween then
						tween:Cancel()
					end
				end
				particle.tweens = nil
			end
			-- Destroy particle image
			if particle.image then
				particle.image:Destroy()
			end
		end
		-- Clear emitter data
		emitter.particles = nil
	end
	activeParticles = {}
	-- Clear the pool and destroy all pooled particles
	for _, particle in ipairs(particlePool) do
		if particle and particle.image then
			particle.image:Destroy()
		end
	end
	particlePool = {}
	isInitialized = false
end

-- Initialize particle system
local function initializeParticleSystem()
	if isInitialized then
		return
	end

	-- Wait for PlayerGui to be fully loaded
	if not PlayerGui then
		task.wait(0.5)
		initializeParticleSystem()
		return
	end

	-- Initialize the particle system
	local success, error = pcall(function()
		ParticleSystem.init()
	end)

	if success then
		isInitialized = true

		-- Set up cleanup on player leaving
		LocalPlayer:GetPropertyChangedSignal("Parent"):Connect(function()
			if LocalPlayer.Parent == nil then
				ParticleSystem.cleanup()
			end
		end)
	else
		warn("[ParticleSystem] Client initialization failed:", error)
		task.wait(1)
		initializeParticleSystem()
	end
end

-- Utility functions for developers
local ParticleAPI = {}

-- Trigger particles manually
function ParticleAPI.triggerParticles(container, config)
	if not isInitialized then
		warn("[ParticleSystem] System not initialized yet")
		return nil
	end

	return ParticleSystem.startEmission(container, config)
end

-- Start emission
function ParticleAPI.startEmission(container, config)
	if not isInitialized then
		warn("[ParticleSystem] System not initialized yet")
		return nil
	end

	return ParticleSystem.startEmission(container, config)
end

-- Stop emission
function ParticleAPI.stopEmission(container)
	if not isInitialized then
		warn("[ParticleSystem] System not initialized yet")
		return
	end

	ParticleSystem.stopEmission(container)
end

-- Get system stats
function ParticleAPI.getStats()
	if not isInitialized then
		return { isInitialized = false }
	end

	return ParticleSystem.getStats()
end

-- Enable/disable debug mode
function ParticleAPI.setDebug(enabled)
	-- Debug mode functionality can be added here if needed
end

-- Expose API globally for development
_G.ParticleAPI = ParticleAPI

-- Core particle system functions

-- Initialize when player joins
LocalPlayer.CharacterAdded:Wait()
task.wait(1) -- Wait a bit for UI to load
initializeParticleSystem()

--[[
[ParticleSystem] Client script loaded!
Available commands:
  _G.ParticleAPI.startEmission(container, config) - Manual emission
  _G.ParticleAPI.stopEmission(container) - Stop emission
  _G.ParticleAPI.getStats() - Get system statistics

Particle Attributes (set on ImageLabel with 'Particle' tag):

  - Particles (Number) - Maximum number of particles (default: 20)
  - Lifetime (Number) - How long each particle lives in seconds (default: 5.0)
  - MaxScale (Number) - Maximum scale factor (default: original image size)
  - RotationSpeed (Number) - Rotation speed in degrees/second (default: 120)
  - Speed (Number) - Movement speed (default: 100)
  - Cooldown (Number) - Seconds between particle spawns (default: 1.0)
  - Area (String) - Where particles spawn: 'All', 'Border', 'Center', 'Top', 'Right', 'Left', 'Bottom' (default: 'All'). Border/edges appear inside from edges
  - EasingStyle (String) - TweenService easing style: 'Linear', 'Sine', 'Back', 'Bounce', 'Elastic', 'Quad', 'Quart', 'Quint', 'Exponential', 'Circular' (default: 'Quart')
  - EasingDirection (String) - TweenService easing direction: 'In', 'Out', 'InOut' (default: 'Out')
  - Staggered (Boolean) - If true, particles appear in groups; if false, all at once (default: false)
  - StaggerPercent (Number) - Percentage of lifetime to wait before spawning next particle (0.1-1.0, default: 0.4)
  - VisibleTime (Number) - Time in seconds that particle stays fully visible AFTER fade-in completes (independent of Lifetime, default: 0.25)
]]
