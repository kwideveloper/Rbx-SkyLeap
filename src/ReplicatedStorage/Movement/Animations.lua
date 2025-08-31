-- Central animation id registry for SkyLeap actions
-- Edit these ids to update animations globally.

local ContentProvider = game:GetService("ContentProvider")

local Animations = {
	-- Movement actions (leave empty string to use default Roblox character animations)
	Dash = "rbxassetid://109076026405774",

	-- Zipline
	ZiplineStart = "rbxassetid://126089819563027",
	ZiplineLoop = "",
	ZiplineEnd = "rbxassetid://94363874797651",

	-- Hook / Grapple
	HookStart = "rbxassetid://126089819563027",
	HookLoop = "",
	HookFinish = "rbxassetid://94363874797651",

	-- Slide
	SlideStart = "rbxassetid://76415278161766",
	SlideLoop = "",
	SlideEnd = "",

	-- Jump / Air
	JumpStart = "", -- custom jump start animation
	Jump = "",
	-- Fall = "rbxassetid://128424180385734", -- optional fall animation (when falling without jumping)
	Fall = "", -- optional fall animation (when falling without jumping)
	Rise = "", -- optional rise animation (when going up after jump or on launch pads)
	LandRoll = "rbxassetid://138804567004011", -- landing roll after high fall
	DoubleJump = "", -- optional; fallback to Jump if empty

	-- Run / Locomotion
	Run = "rbxassetid://129741854679661",

	-- Wall interactions
	WallRunLoop = "",
	WallJump = "rbxassetid://125842455228311", -- Preparation animation for Wall Jump

	-- Vertical Climb
	VerticalClimb = "rbxassetid://74696284153822", -- vertical wall climbing animation

	-- Vaults
	Vault_Speed = "rbxassetid://89523136070071",
	-- Vault_Lazy = "",
	-- Vault_Kong = "",
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

	-- Crawl / Prone (hold Z)
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
