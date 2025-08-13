-- Wall jumping helper

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
local WallMemory = require(game:GetService("ReplicatedStorage").Movement.WallMemory)
local Animations = require(game:GetService("ReplicatedStorage").Movement.Animations)

local WallJump = {}

local lastJumpTick = 0
local activeAnimationTracks = {} -- To follow character active by character

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
		local result = workspace:Raycast(rootPart.Position, dir * 4, params)
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
		track.Looped = false
		track:Play(0.1, 1, 1)
		activeAnimationTracks[character] = track
		return track
	end

	return nil
end

-- Verify whether we should show the animation of Wall Jump
local function shouldShowWallJumpAnimation(character)
	-- Just show animation if the character is in the air and near a wall
	if not character then
		return false
	end

	-- Verify if it is in the air
	local isAirborne = isCharacterAirborne(character)
	if not isAirborne then
		return false
	end

	-- Verify if it is close to a wall
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local hit = findNearbyWall(root)
	return hit ~= nil
end

function WallJump.isNearWall(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local hit = findNearbyWall(root)

	-- Verify if we must show animation
	local shouldShow = shouldShowWallJumpAnimation(character)

	-- If it must be shown and there is no active animation, reproduce it
	if shouldShow and not activeAnimationTracks[character] then
		playWallJumpAnimation(character)
	-- If it should not be shown but there is an active animation, stop it
	elseif not shouldShow and activeAnimationTracks[character] then
		pcall(function()
			activeAnimationTracks[character]:Stop(0.1)
		end)
		activeAnimationTracks[character] = nil
	end

	return hit ~= nil
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

	local away = hit.Normal * Config.WallJumpImpulseAway
	local up = Vector3.new(0, Config.WallJumpImpulseUp, 0)

	-- Reset vertical velocity to avoid "moon jump" stacking
	local vel = rootPart.AssemblyLinearVelocity
	vel = Vector3.new(vel.X, 0, vel.Z)
	rootPart.AssemblyLinearVelocity = vel + away + up
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	WallMemory.setLast(character, hit.Instance)

	-- Stop the preparation animation when making the jump
	if activeAnimationTracks[character] then
		pcall(function()
			activeAnimationTracks[character]:Stop(0.1)
		end)
		activeAnimationTracks[character] = nil
	end

	return true
end

return WallJump
