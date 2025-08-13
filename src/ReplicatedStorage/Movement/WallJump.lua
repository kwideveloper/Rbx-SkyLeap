-- Wall jumping helper

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
local WallMemory = require(game:GetService("ReplicatedStorage").Movement.WallMemory)
local Animations = require(game:GetService("ReplicatedStorage").Movement.Animations)
local WallRun = require(game:GetService("ReplicatedStorage").Movement.WallRun)
local Climb = require(game:GetService("ReplicatedStorage").Movement.Climb)

local WallJump = {}

local lastJumpTick = 0
local activeAnimationTracks = {} -- To follow character active by character
local activeWallSlides = {} -- To follow characters that are on Wall Slide
local stopWallSlide -- forward declaration
local slideCooldownUntil = {} -- Cooldown to prevent immediate re-entering slide after jumping

-- Configurable parameters for the wall slide
local WALL_SLIDE_FALL_SPEED = Config.WallSlideFallSpeed -- Fall speed during the wall slide
local WALL_STICK_VELOCITY = Config.WallSlideStickVelocity -- Force with which the character sticks to the wall
local WALL_SLIDE_MAX_DURATION = Config.WallSlideMaxDurationSeconds -- Maximum duration of Wall Slide

local function getCharacterParts(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function isCharacterAirborne(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	return humanoid.FloorMaterial == Enum.Material.Air
end

-- Modified function to verify if a wall is appropriate for wall slide
-- (It should not be climbable and should allow Wall Jump)
local function findNearbyWallForSlide(rootPart)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rootPart.Parent }
	params.IgnoreWater = Config.RaycastIgnoreWater

	local offsets = {
		rootPart.CFrame.RightVector,
		-rootPart.CFrame.RightVector,
		rootPart.CFrame.LookVector,
		-rootPart.CFrame.LookVector,
	}

	for _, dir in ipairs(offsets) do
		local result = workspace:Raycast(rootPart.Position, dir * (Config.WallSlideDetectionDistance or 4), params)
		if result and result.Instance and result.Instance.CanCollide then
			local inst = result.Instance
			-- Allow slide also on climate surfaces; just exclude whether walljump == fals
			local wallJumpAttr = inst:GetAttribute("WallJump")
			if wallJumpAttr ~= false then
				return result
			end
		end
	end

	return nil
end

-- The original Findarbywall function remains for other functionalities
local function findNearbyWall(rootPart)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rootPart.Parent }
	params.IgnoreWater = Config.RaycastIgnoreWater

	local offsets = {
		rootPart.CFrame.RightVector,
		-rootPart.CFrame.RightVector,
		rootPart.CFrame.LookVector,
		-rootPart.CFrame.LookVector,
	}

	for _, dir in ipairs(offsets) do
		local result = workspace:Raycast(rootPart.Position, dir * (Config.WallSlideDetectionDistance or 4), params)
		if result and result.Instance and result.Instance.CanCollide then
			local inst = result.Instance
			-- WallJump is allowed by default; disallow only if attribute explicitly false
			local wallJumpAttr = inst:GetAttribute("WallJump")
			if wallJumpAttr ~= false then
				return result
			end
		end
	end

	return nil
end

-- Function to reproduce Walljump animation
local function playWallJumpAnimation(character)
	if not character then
		return nil
	end

	-- Stop any previous animation of Wall Jump
	if activeAnimationTracks[character] then
		pcall(function()
			activeAnimationTracks[character]:Stop(0.1)
		end)
		activeAnimationTracks[character] = nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid

	local animInst = Animations.get("WallJump")
	if not animInst then
		return nil
	end

	local track = nil
	pcall(function()
		track = animator:LoadAnimation(animInst)
	end)

	if track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		-- Play paused and seek to the last frame to hold pose
		track:Play(0.05, 1, 0)
		local function snapToLastFrame()
			local len = track.Length or 0
			if len and len > 0 then
				local epsilon = 1 / 30
				pcall(function()
					track.TimePosition = math.max(0, len - epsilon)
					track:AdjustSpeed(0)
				end)
				return true
			end
			return false
		end
		if not snapToLastFrame() then
			-- Fallback if length not ready yet
			local conn
			conn = track:GetPropertyChangedSignal("Length"):Connect(function()
				if snapToLastFrame() and conn then
					conn:Disconnect()
					conn = nil
				end
			end)
			task.delay(0.2, function()
				if conn then
					conn:Disconnect()
					conn = nil
					snapToLastFrame()
				end
			end)
		end
		activeAnimationTracks[character] = track
		return track
	end

	return nil
end

-- Verify if we must activate the wall slide
local function shouldActivateWallSlide(character)
	-- Just activate the wall slide if the character is in the air and near an appropriate wall
	if not character then
		return false
	end

	-- If there are active co -procown, not activate
	local now = os.clock()
	local untilT = slideCooldownUntil[character]
	if untilT and now < untilT then
		return false
	end

	-- If the wallrun is active, we do not activate the wall slide
	if WallRun.isActive(character) then
		return false
	end

	-- If the Climb is active, we do not activate the wall slide (but we do allow close to climbable)
	if Climb.isActive(character) then
		return false
	end

	-- Verify if it is in the air
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local isAirborne = isCharacterAirborne(character)
	if not isAirborne then
		return false
	end

	--Verify if it is close to an appropriate wall for wall slide
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local hit = findNearbyWallForSlide(root)
	return hit ~= nil
end

-- Start the wall slide for a character (following a pattern similar to wallrun)
local function startWallSlide(character, hitResult)
	if not character or not hitResult then
		return
	end

	local root, humanoid = getCharacterParts(character)
	if not root or not humanoid then
		return
	end

	-- Change to state that allows us to better control the movement
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- Save original values
	local originalGravity = workspace.Gravity
	local token = {} -- Token to identify this Wall Slide session

	-- Save information from the Wall Slide
	activeWallSlides[character] = {
		wallNormal = hitResult.Normal,
		startTime = os.clock(),
		hitInstance = hitResult.Instance,
		token = token,
		humanoid = humanoid,
	}

	-- Reproduce animation
	playWallJumpAnimation(character)

	-- Configure a maximum timer for the wall slide
	task.delay(WALL_SLIDE_MAX_DURATION, function()
		local data = activeWallSlides[character]
		if data and data.token == token then
			stopWallSlide(character)
		end
	end)
end

-- Stop the Wall Slide for a character
stopWallSlide = function(character)
	if not character then
		return
	end

	local data = activeWallSlides[character]
	if not data then
		return
	end

	-- Restore the state of the humanoid
	if data.humanoid and data.humanoid.Parent then
		data.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	-- Clean
	activeWallSlides[character] = nil

	-- Stop animation
	if activeAnimationTracks[character] then
		pcall(function()
			activeAnimationTracks[character]:Stop(0.1)
		end)
		activeAnimationTracks[character] = nil
	end
end

-- Updates the Physics of the Wall Slide (similar to the Mainintin of Wallrun)
function WallJump.updateWallSlide(character, dt)
	if not character or not activeWallSlides[character] then
		return
	end

	-- If the wallrun is active, we stop the wall slide
	if WallRun.isActive(character) then
		stopWallSlide(character)
		return
	end

	-- If the climb is active, we stop the wall slide (we allow close to climate)
	if Climb.isActive(character) then
		stopWallSlide(character)
		return
	end

	local root, humanoid = getCharacterParts(character)
	if not root or not humanoid then
		stopWallSlide(character)
		return
	end

	-- If player initiated a jump, immediately stop sliding
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or humanoid.Jump == true then
		stopWallSlide(character)
		return false
	end

	-- Verify if you are still in the air
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		stopWallSlide(character)
		-- Ensure normal walking state resumes on ground
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
		return false
	end

	-- Verify if it is still close to an appropriate wall for wall slide
	local hit = findNearbyWallForSlide(root)
	if not hit then
		stopWallSlide(character)
		return false
	end

	local data = activeWallSlides[character]

	-- Update the normal wall
	local normal = hit.Normal
	data.wallNormal = normal

	-- Calculate the stick towards the wall (similar to wallrun)
	local stickForce = -normal * WALL_STICK_VELOCITY

	-- Calculate the new speed with controlled drop and stick to the wall, but if the player presses Space, avoid strong glue
	local newVelocity = Vector3.new(stickForce.X, -WALL_SLIDE_FALL_SPEED, stickForce.Z)

	-- Early exit based on ground proximity (1 stud from feet)
	do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.IgnoreWater = Config.RaycastIgnoreWater
		local rayDist = 4
		local ground = workspace:Raycast(root.Position, Vector3.new(0, -rayDist, 0), params)
		if ground then
			local feetY = root.Position.Y - ((root.Size and root.Size.Y or 2) * 0.5)
			local verticalGap = feetY - ground.Position.Y
			if verticalGap <= 1.0 then
				stopWallSlide(character)
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
				return false
			end
		end
	end

	-- Apply the new speed
	root.AssemblyLinearVelocity = newVelocity

	-- Orient character to face the wall (stable up axis)
	local lookDir = -normal
	root.CFrame = CFrame.lookAt(root.Position, root.Position + lookDir, Vector3.yAxis)

	return true
end

function WallJump.isNearWall(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local hit = findNearbyWall(root)

	-- For the Slide Wall, we use the specialized function that now allows weather walls
	local hitForSlide = findNearbyWallForSlide(root)

	-- Verify if we must activate the wall slide
	local shouldActivate = shouldActivateWallSlide(character)

	-- If it must be activated and is not active, start it
	if shouldActivate and not activeWallSlides[character] and hitForSlide then
		startWallSlide(character, hitForSlide)
	-- If it should not be activated but it is active, stop it
	elseif not shouldActivate and activeWallSlides[character] then
		stopWallSlide(character)
	end

	return hit ~= nil
end

function WallJump.isWallSliding(character)
	return activeWallSlides[character] ~= nil
end

function WallJump.stopSlide(character)
	stopWallSlide(character)
end

function WallJump.getNearbyWall(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local hit = findNearbyWall(root)
	return hit and hit.Instance or nil
end

function WallJump.tryJump(character)
	local now = os.clock()
	if now - lastJumpTick < Config.WallJumpCooldownSeconds then
		return false
	end

	local rootPart, humanoid = getCharacterParts(character)
	if not rootPart or not humanoid then
		return false
	end

	local hit = findNearbyWall(rootPart)
	if not hit then
		return false
	end
	local last = WallMemory.getLast(character)
	if last and last == hit.Instance then
		return false
	end

	lastJumpTick = now

	-- Stop wall slide first so our Jumping state is not overridden
	if activeWallSlides[character] then
		stopWallSlide(character)
	end

	local away = hit.Normal * Config.WallJumpImpulseAway
	local up = Vector3.new(0, Config.WallJumpImpulseUp, 0)

	-- Reset vertical velocity to avoid "moon jump" stacking
	local vel = rootPart.AssemblyLinearVelocity
	vel = Vector3.new(vel.X, 0, vel.Z)
	rootPart.AssemblyLinearVelocity = vel + away + up
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	WallMemory.setLast(character, hit.Instance)

	-- Prevent immediate re-entering wall slide after jumping
	slideCooldownUntil[character] = os.clock() + ((Config.WallJumpCooldownSeconds or 0.2) + 0.2)

	return true
end

return WallJump
