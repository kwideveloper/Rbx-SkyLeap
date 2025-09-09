-- Central animation id registry for SkyLeap actions
-- Edit these ids to update animations globally.

local ContentProvider = game:GetService("ContentProvider")

local Animations = {
	-- Movement actions (leave empty string to use default Roblox character animations)
	Dash = "rbxassetid://109076026405774",

	-- Zipline
	ZiplineStart = "rbxassetid://126089819563027",
	ZiplineLoop = "rbxassetid://108110533497477",
	ZiplineEnd = "rbxassetid://94363874797651",

	-- Hook / Grapple
	HookStart = "rbxassetid://126089819563027",
	HookLoop = "rbxassetid://108110533497477",
	HookFinish = "rbxassetid://94363874797651",

	-- Slide
	SlideStart = "rbxassetid://76415278161766",
	SlideLoop = "",
	SlideEnd = "",

	-- Jump / Air
	JumpStart = "", -- custom jump start animation
	Jump = "",
	-- Fall = "rbxassetid://128424180385734", -- optional fall animation (when falling without jumping)
	Fall = "rbxassetid://86469067910082", -- optional fall animation (when falling without jumping)
	Rise = "", -- optional rise animation (when going up after jump or on launch pads)
	LandRoll = "rbxassetid://138804567004011", -- landing roll after high fall
	-- Jump: 129493509839673
	DoubleJump = "rbxassetid://75232104377563", -- optional; fallback to Jump if empty

	Run = "rbxassetid://91478114539329", -- Replace in the Animate file found in: StarterPlayer/StarterCharacterScripts/Animate/run

	-- Run / Locomotion
	-- Default Run: 91478114539329
	-- Fast run: 123068310096943
	-- Normal run: 104728963373684
	-- Naruto run: 122746804022977
	-- Weird run: 77511870808805

	Walk = "rbxassetid://101897812185829", -- Replace in the Animate file found in: StarterPlayer/StarterCharacterScripts/Animate/walk

	-- Default Walk: 101897812185829
	-- Normal walk: 95528593238099
	-- Weird Walk: 89764452033789
	-- Zombie Walk: 81321492147665
	-- Lady walk: 104181332449335

	-- Wall interactions
	WallRunLoop = "",
	WallRunLeft = "rbxassetid://90977169166235", -- Wall running on left wall
	WallRunRight = "rbxassetid://100356862362375", -- Wall running on right wall
	WallJump = "rbxassetid://125842455228311", -- Preparation animation for Wall Jump

	-- Vertical Climb
	VerticalClimb = "rbxassetid://114927643133024", -- vertical wall climbing animation
	-- Default: 107697509448004
	-- Original: 74696284153822

	-- Vaults
	Vault_Monkey = "rbxassetid://117183115010634",
	Vault_1_Hand = "rbxassetid://102031472499990",
	Front_Flip = "rbxassetid://110118657343120",
	Jump_Over = "rbxassetid://113615223410633", -- MODIFY

	-- Vault_Dash = "",
	-- Vault_TwoHanded = "",

	-- Mantle (ledge grab)
	Mantle = "rbxassetid://82189151823059",

	-- Ledge Hang (hanging from ledge)
	LedgeHangStart = "rbxassetid://82144582851439", -- animation when starting to hang
	LedgeHangLoop = "rbxassetid://91323918920205", -- idle hanging animation (ledge idle)
	LedgeHangMove = "", -- moving left/right while hanging
	LedgeHangLeft = "rbxassetid://134252704996098", -- moving left while hanging
	LedgeHangRight = "rbxassetid://140051038203928", -- moving right while hanging
	LedgeHangUp = "rbxassetid://106579117059480", -- jumping up from hang

	-- Climb (optional)
	ClimbStart = "",
	ClimbLoop = "",
	ClimbEnd = "",
	-- Custom climb directional animations
	ClimbUp = "rbxassetid://82912869497397", -- upward climbing animation
	ClimbDown = "", -- downward climbing animation
	ClimbLeft = "", -- climbing left animation
	ClimbRight = "", -- climbing right animation
	ClimbIdle = "", -- idle climbing animation (when not moving)

	-- Crawl / Prone (Press Z)
	Crawl = "rbxassetid://75303378392203",
	-- Optional split variants; if left empty, code will fallback to `Crawl`
	CrawlIdle = "rbxassetid://122469032691633",
	CrawlMove = "rbxassetid://75303378392203",
}

-- Internal cache of Animation instances by name
local animationCache = {}

-- Returns a reusable Animation instance for the given configured name
function Animations.get(name)
	local id = Animations[name]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local inst = animationCache[name]
	if inst == nil then
		inst = Instance.new("Animation")
		inst.AnimationId = id
		animationCache[name] = inst
	else
		-- Keep id in sync if table changed at runtime
		if inst.AnimationId ~= id then
			inst.AnimationId = id
		end
	end
	return inst
end

-- Check if an animation is configured (has a valid ID)
function Animations.isConfigured(name)
	local id = Animations[name]
	return type(id) == "string" and id ~= ""
end

-- Returns an array of all configured Animation instances (non-empty ids)
function Animations.getAll()
	local list = {}
	for key, value in pairs(Animations) do
		if type(value) == "string" and value ~= "" then
			local inst = Animations.get(key)
			if inst then
				table.insert(list, inst)
			end
		end
	end
	return list
end

-- Returns the appropriate climb animation based on movement direction
function Animations.getClimbAnimation(moveDirection)
	if not moveDirection or moveDirection.Magnitude < 0.01 then
		-- Idle climbing
		local idleAnim = Animations.get("ClimbIdle")
		if idleAnim then
			return idleAnim
		end
		-- Fallback to ClimbLoop if ClimbIdle not configured
		return Animations.get("ClimbLoop")
	end

	-- Determine dominant direction
	local absX = math.abs(moveDirection.X)
	local absY = math.abs(moveDirection.Y)
	local absZ = math.abs(moveDirection.Z)

	if absY > absX and absY > absZ then
		-- Vertical movement dominant
		if moveDirection.Y > 0 then
			local upAnim = Animations.get("ClimbUp")
			if upAnim then
				return upAnim
			end
		else
			local downAnim = Animations.get("ClimbDown")
			if downAnim then
				return downAnim
			end
		end
	elseif absX > absZ then
		-- Horizontal X movement dominant
		if moveDirection.X > 0 then
			local rightAnim = Animations.get("ClimbRight")
			if rightAnim then
				return rightAnim
			end
		else
			local leftAnim = Animations.get("ClimbLeft")
			if leftAnim then
				return leftAnim
			end
		end
	else
		-- Horizontal Z movement dominant (forward/back)
		-- For now, use the general ClimbLoop for forward/back movement
		return Animations.get("ClimbLoop")
	end

	-- Fallback to general ClimbLoop
	return Animations.get("ClimbLoop")
end

-- Returns the appropriate climb animation and its configured speed
function Animations.getClimbAnimationWithSpeed(moveDirection)
	local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
	local anim = Animations.getClimbAnimation(moveDirection)
	local speed = 1.0

	if not anim then
		return nil, 1.0
	end

	-- Determine animation type and get corresponding speed
	if not moveDirection or moveDirection.Magnitude < 0.01 then
		-- Idle climbing
		local idleAnim = Animations.get("ClimbIdle")
		if idleAnim and idleAnim == anim then
			speed = Config.ClimbAnimationSpeed.ClimbIdle or Config.ClimbAnimationSpeed.Default
		else
			speed = Config.ClimbAnimationSpeed.Default
		end
	else
		-- Determine dominant direction
		local absX = math.abs(moveDirection.X)
		local absY = math.abs(moveDirection.Y)
		local absZ = math.abs(moveDirection.Z)

		if absY > absX and absY > absZ then
			-- Vertical movement dominant
			if moveDirection.Y > 0 then
				local upAnim = Animations.get("ClimbUp")
				if upAnim and upAnim == anim then
					speed = Config.ClimbAnimationSpeed.ClimbUp or Config.ClimbAnimationSpeed.Default
				else
					speed = Config.ClimbAnimationSpeed.Default
				end
			else
				local downAnim = Animations.get("ClimbDown")
				if downAnim and downAnim == anim then
					speed = Config.ClimbAnimationSpeed.ClimbDown or Config.ClimbAnimationSpeed.Default
				else
					speed = Config.ClimbAnimationSpeed.Default
				end
			end
		elseif absX > absZ then
			-- Horizontal X movement dominant
			if moveDirection.X > 0 then
				local rightAnim = Animations.get("ClimbRight")
				if rightAnim and rightAnim == anim then
					speed = Config.ClimbAnimationSpeed.ClimbRight or Config.ClimbAnimationSpeed.Default
				else
					speed = Config.ClimbAnimationSpeed.Default
				end
			else
				local leftAnim = Animations.get("ClimbLeft")
				if leftAnim and leftAnim == anim then
					speed = Config.ClimbAnimationSpeed.ClimbLeft or Config.ClimbAnimationSpeed.Default
				else
					speed = Config.ClimbAnimationSpeed.Default
				end
			end
		else
			-- Horizontal Z movement dominant or default
			speed = Config.ClimbAnimationSpeed.Default
		end
	end

	return anim, speed
end

-- ============================================================================
-- VAULT ANIMATION SYSTEM
-- ============================================================================
-- This system provides random selection of vault animations with premium feature toggle
-- and fallback support for graceful degradation

-- Returns a random vault animation based on configuration
-- Supports premium feature toggle and fallback animation
function Animations.getRandomVaultAnimation()
	local Config = require(game:GetService("ReplicatedStorage").Movement.Config)

	-- Check if random vault animations are enabled (Premium Feature)
	if not Config.VaultRandomAnimationsEnabled then
		-- Premium feature disabled, use fallback animation
		local fallbackAnim = Animations.get(Config.VaultFallbackAnimation)
		if fallbackAnim then
			return fallbackAnim, Config.VaultFallbackAnimation
		end
		return nil, nil
	end

	-- Get available vault animation keys
	local availableKeys = Config.VaultAnimationKeys or {}
	if #availableKeys == 0 then
		-- No animations configured, use fallback
		local fallbackAnim = Animations.get(Config.VaultFallbackAnimation)
		if fallbackAnim then
			return fallbackAnim, Config.VaultFallbackAnimation
		end
		return nil, nil
	end

	-- Filter out animations that are not configured (empty strings)
	local validKeys = {}
	for _, key in ipairs(availableKeys) do
		if Animations.isConfigured(key) then
			table.insert(validKeys, key)
		end
	end

	if #validKeys == 0 then
		-- No valid animations found, use fallback
		local fallbackAnim = Animations.get(Config.VaultFallbackAnimation)
		if fallbackAnim then
			return fallbackAnim, Config.VaultFallbackAnimation
		end
		return nil, nil
	end

	-- Select random animation from valid options
	local randomIndex = math.random(1, #validKeys)
	local selectedKey = validKeys[randomIndex]
	local selectedAnim = Animations.get(selectedKey)

	return selectedAnim, selectedKey
end

-- Returns a specific vault animation by name
-- Useful for testing or when you need a specific animation
function Animations.getVaultAnimation(animationName)
	if not animationName then
		return Animations.getRandomVaultAnimation()
	end

	if Animations.isConfigured(animationName) then
		return Animations.get(animationName), animationName
	end

	-- Fallback to random selection if specific animation not found
	return Animations.getRandomVaultAnimation()
end

-- Check if vault animation system is available
function Animations.isVaultAnimationSystemAvailable()
	local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
	return Config.VaultRandomAnimationsEnabled and #(Config.VaultAnimationKeys or {}) > 0
end

-- ============================================================================
-- VAULT ANIMATION UTILITY FUNCTIONS
-- ============================================================================

-- Add a new vault animation with custom duration (runtime configuration)
-- @param animationName: The name/key for the animation
-- @param animationId: The Roblox asset ID for the animation
-- @param customDuration: Optional custom duration (uses default if not provided)
function Animations.addVaultAnimation(animationName, animationId, customDuration)
	local Config = require(game:GetService("ReplicatedStorage").Movement.Config)

	-- Add to Animations table
	Animations[animationName] = animationId

	-- Add to available keys if not already present
	local keys = Config.VaultAnimationKeys or {}
	local alreadyExists = false
	for _, key in ipairs(keys) do
		if key == animationName then
			alreadyExists = true
			break
		end
	end
	if not alreadyExists then
		table.insert(keys, animationName)
		Config.VaultAnimationKeys = keys
	end

	-- Add custom duration if provided
	if customDuration then
		Config.VaultAnimationCustomDurations = Config.VaultAnimationCustomDurations or {}
		Config.VaultAnimationCustomDurations[animationName] = customDuration
	end

	-- Clear cache for this animation to force reload
	if animationCache[animationName] then
		animationCache[animationName]:Destroy()
		animationCache[animationName] = nil
	end

	return true
end

-- Remove a vault animation from the system
-- @param animationName: The name/key of the animation to remove
function Animations.removeVaultAnimation(animationName)
	local Config = require(game:GetService("ReplicatedStorage").Movement.Config)

	-- Remove from Animations table
	Animations[animationName] = nil

	-- Remove from available keys
	local keys = Config.VaultAnimationKeys or {}
	for i, key in ipairs(keys) do
		if key == animationName then
			table.remove(keys, i)
			break
		end
	end
	Config.VaultAnimationKeys = keys

	-- Remove custom duration
	if Config.VaultAnimationCustomDurations then
		Config.VaultAnimationCustomDurations[animationName] = nil
	end

	-- Clear cache
	if animationCache[animationName] then
		animationCache[animationName]:Destroy()
		animationCache[animationName] = nil
	end

	return true
end

-- Get the duration that will be used for a specific vault animation
-- @param animationName: The name of the animation
-- @return: duration in seconds
function Animations.getVaultAnimationDuration(animationName)
	local Config = require(game:GetService("ReplicatedStorage").Movement.Config)

	-- Check for custom duration first
	if Config.VaultAnimationCustomDurations and Config.VaultAnimationCustomDurations[animationName] then
		return Config.VaultAnimationCustomDurations[animationName]
	end

	-- Return default duration
	return Config.VaultAnimationDuration or 0.8
end

-- ============================================================================
-- VAULT ANIMATION PLAYBACK CONTROL
-- ============================================================================
-- This system ensures vault animations play completely with configurable duration

-- Play a vault animation with guaranteed completion and configurable duration
-- @param animator: The Humanoid's Animator instance
-- @param animationName: The name of the vault animation to play
-- @param options: Optional table with additional settings
--   - priority: AnimationPriority (default: Action)
--   - onComplete: function - callback when animation finishes
--   - debug: boolean (default: false) - enable debug logging
--
-- @return: AnimationTrack if successful, nil if failed
-- @return: string - error message if failed
function Animations.playVaultAnimationWithDuration(animator, animationName, options)
	-- Validate inputs
	if not animator or not animationName then
		return nil, "Invalid parameters: animator and animationName are required"
	end

	-- Check if animation is configured
	if not Animations.isConfigured(animationName) then
		return nil, "Vault animation not configured: " .. tostring(animationName)
	end

	-- Get configuration for duration control
	local Config = require(game:GetService("ReplicatedStorage").Movement.Config)

	-- Get custom duration for this specific animation, fallback to default
	local targetDuration = Config.VaultAnimationCustomDurations and Config.VaultAnimationCustomDurations[animationName]
		or Config.VaultAnimationDuration
		or 0.8

	-- Set default options
	options = options or {}
	local priority = options.priority or Enum.AnimationPriority.Action
	local onComplete = options.onComplete
	local debug = options.debug or false

	if debug then
		print("[Vault Animation] " .. animationName .. " - Using duration:", string.format("%.2f", targetDuration), "s")
	end

	-- Use the global playWithDuration function for guaranteed completion
	local animTrack, errorMsg = Animations.playWithDuration(animator, animationName, targetDuration, {
		priority = priority,
		suppressDefault = true, -- Suppress Roblox default animations
		onComplete = onComplete,
		debug = debug,
	})

	return animTrack, errorMsg
end

-- Play a random vault animation with guaranteed completion
-- @param animator: The Humanoid's Animator instance
-- @param options: Optional table with additional settings
--
-- @return: AnimationTrack if successful, nil if failed
-- @return: string - error message if failed
function Animations.playRandomVaultAnimationWithDuration(animator, options)
	local animInst, animName = Animations.getRandomVaultAnimation()
	if not animInst then
		return nil, "No vault animation available"
	end

	-- Use the specific animation name for better tracking
	options = options or {}
	options.debug = options.debug or false

	if options.debug then
		print("[Vault Animation] Selected random animation:", animName)
	end

	-- Pass the animation name so it can use custom duration
	return Animations.playVaultAnimationWithDuration(animator, animName, options)
end

-- Preload all configured animations (client or server)
function Animations.preload()
	local assets = Animations.getAll()
	if #assets == 0 then
		return
	end
	pcall(function()
		ContentProvider:PreloadAsync(assets)
	end)
end

-- ============================================================================
-- GLOBAL ANIMATION SPEED CONTROL FUNCTION
-- ============================================================================
-- This function provides a unified way to control animation speed and duration
-- across all movement systems (Hook, Zipline, Vault, etc.)
--
-- IMPORTANT: If an animation is not configured (empty string in Animations table),
-- this function returns nil, nil (no error) to allow graceful fallback to Roblox defaults.
-- Use Animations.tryPlayWithDuration() for clearer handling of optional animations.
--
-- @param animator: The Humanoid's Animator instance
-- @param animationName: The name of the animation (e.g., "HookStart", "ZiplineEnd")
-- @param targetDurationSeconds: The exact duration you want the animation to play (in seconds)
-- @param options: Optional table with additional settings
--   - priority: AnimationPriority (default: Action)
--   - looped: boolean (default: false)
--   - suppressDefault: boolean (default: true) - suppress fall/jump/land animations
--   - onComplete: function - callback when animation finishes
--   - debug: boolean (default: false) - enable debug logging
--
-- @return: AnimationTrack if successful, nil if failed or not configured
-- @return: string - error message if failed, nil if not configured (fallback to Roblox defaults)
function Animations.playWithDuration(animator, animationName, targetDurationSeconds, options)
	-- Validate inputs
	if not animator or not animationName or not targetDurationSeconds then
		return nil, "Invalid parameters: animator, animationName, and targetDurationSeconds are required"
	end

	-- Check if animation is configured
	if not Animations.isConfigured(animationName) then
		-- Return nil without error for unconfigured animations (fallback to Roblox defaults)
		-- This allows the system to gracefully fall back to Roblox default animations
		return nil, nil
	end

	-- Get animation instance
	local animation = Animations.get(animationName)
	if not animation then
		return nil, "Animation not found: " .. tostring(animationName)
	end

	-- Set default options
	options = options or {}
	local priority = options.priority or Enum.AnimationPriority.Action
	local looped = options.looped or false
	local suppressDefault = options.suppressDefault ~= false -- default to true
	local onComplete = options.onComplete
	local debug = options.debug or false

	-- Load animation track
	local animTrack = animator:LoadAnimation(animation)
	if not animTrack then
		return nil, "Failed to load animation track"
	end

	-- Configure animation track
	animTrack.Looped = looped
	animTrack.Priority = priority

	-- Calculate speed multiplier for target duration
	local originalDuration = animTrack.Length
	local speedMultiplier = originalDuration / targetDurationSeconds

	-- Clamp speed multiplier to reasonable limits (0.1x to 10x)
	speedMultiplier = math.clamp(speedMultiplier, 0.1, 10.0)

	-- Debug logging (disabled for production)
	-- if debug then
	-- 	print(
	-- 		"[Animations] " .. animationName .. " - Original Duration:",
	-- 		originalDuration,
	-- 		"seconds",
	-- 		"| Target Duration:",
	-- 		targetDurationSeconds,
	-- 		"seconds",
	-- 		"| Speed Multiplier:",
	-- 		speedMultiplier,
	-- 		"x",
	-- 		"| Expected Duration:",
	-- 		originalDuration / speedMultiplier,
	-- 		"seconds"
	-- 	)
	-- end

	-- Suppress default animations if requested
	if suppressDefault then
		local humanoid = animator.Parent
		if humanoid and humanoid:IsA("Humanoid") then
			local originalAnim = humanoid:GetPlayingAnimationTracks()
			for _, track in ipairs(originalAnim) do
				if track.Animation and track.Animation.AnimationId then
					local animId = string.lower(tostring(track.Animation.AnimationId))
					if animId:find("fall") or animId:find("jump") or animId:find("land") then
						track:Stop(0.1)
					end
				end
			end
		end
	end

	-- Play animation with correct speed (Play first, then AdjustSpeed)
	animTrack:Play()
	animTrack:AdjustSpeed(speedMultiplier)

	-- Debug logging (disabled for production)
	-- if debug then
	-- 	print("[Animations] " .. animationName .. " - Speed after Play + AdjustSpeed:", animTrack.Speed)
	-- end

	-- Verify animation started successfully
	if not animTrack.IsPlaying then
		animTrack:Destroy()
		return nil, "Animation failed to start"
	end

	-- Set up completion tracking if callback provided
	if onComplete and not looped then
		task.spawn(function()
			local startTime = os.clock()
			while animTrack and animTrack.IsPlaying do
				task.wait(0.1)
			end
			local endTime = os.clock()
			local actualDuration = endTime - startTime

			-- Debug logging (disabled for production)
			-- if debug then
			-- 	print(
			-- 		"[Animations] " .. animationName .. " - Completed in",
			-- 		actualDuration,
			-- 		"seconds (expected:",
			-- 		targetDurationSeconds,
			-- 		"seconds)"
			-- 	)
			-- end

			-- Call completion callback
			if onComplete then
				pcall(onComplete, actualDuration, targetDurationSeconds)
			end
		end)
	end

	return animTrack
end

-- ============================================================================
-- HELPER FUNCTION FOR OPTIONAL ANIMATIONS
-- ============================================================================
-- This function is useful for animations that are optional (like loop animations)
-- It returns nil, nil if the animation is not configured, allowing graceful fallback
--
-- @param animator: The Humanoid's Animator instance
-- @param animationName: The name of the animation
-- @param targetDurationSeconds: The exact duration you want the animation to play
-- @param options: Optional table with additional settings
--
-- @return: AnimationTrack if successful, nil if failed or not configured
-- @return: string - error message if failed, nil if not configured (fallback to Roblox defaults)
function Animations.tryPlayWithDuration(animator, animationName, targetDurationSeconds, options)
	local animTrack, errorMsg = Animations.playWithDuration(animator, animationName, targetDurationSeconds, options)

	-- If errorMsg is nil, it means the animation is not configured (not an error)
	-- If errorMsg is a string, it means there was a real error
	return animTrack, errorMsg
end

return Animations
