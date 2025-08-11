-- Wall jumping helper

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
local WallMemory = require(game:GetService("ReplicatedStorage").Movement.WallMemory)

local WallJump = {}

local lastJumpTick = 0

local function getCharacterParts(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
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

function WallJump.isNearWall(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local hit = findNearbyWall(root)
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
	return true
end

return WallJump
