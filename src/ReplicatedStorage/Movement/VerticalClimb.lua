-- Vertical wall climb: short upward run when sprinting straight into a wall

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Movement.Config)

local VerticalClimb = {}

local active = {}
local cooldownUntil = setmetatable({}, { __mode = "k" })

local function getParts(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function findFrontWall(root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent }
	params.IgnoreWater = Config.RaycastIgnoreWater
	local dist = Config.VerticalClimbDetectionDistance or 3.5
	local look = root.CFrame.LookVector
	local origins = {
		root.Position,
		root.Position + Vector3.new(0, 1.4, 0),
		root.Position + Vector3.new(0, -1.0, 0),
		root.Position + (root.CFrame.RightVector * 0.6),
		root.Position - (root.CFrame.RightVector * 0.6),
	}
	local best
	for _, o in ipairs(origins) do
		local h = workspace:Raycast(o, look * dist, params)
		if h and h.Instance and h.Instance.CanCollide then
			best = h
			break
		end
	end
	if not best then
		return nil
	end
	-- Require facing mostly toward wall to avoid side taps
	local facing = look:Dot(-best.Normal)
	if facing < 0.5 then
		return nil
	end
	return best
end

function VerticalClimb.isActive(character)
	return active[character] ~= nil
end

function VerticalClimb.tryStart(character)
	if not (Config.VerticalClimbEnabled ~= false) then
		return false
	end
	local root, humanoid = getParts(character)
	if not root or not humanoid then
		return false
	end
	if cooldownUntil[character] and os.clock() < cooldownUntil[character] then
		return false
	end
	local speed = root.AssemblyLinearVelocity.Magnitude
	if speed < (Config.VerticalClimbMinSpeed or 18) then
		return false
	end
	local hit = findFrontWall(root)
	if not hit then
		return false
	end
	active[character] = {
		t0 = os.clock(),
		dir = root.CFrame.LookVector,
		normal = hit.Normal,
	}
	return true
end

function VerticalClimb.maintain(character, dt)
	local st = active[character]
	if not st then
		return false
	end
	local root, humanoid = getParts(character)
	if not root or not humanoid then
		active[character] = nil
		return false
	end
	-- stop if grounded or time exceeded
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		active[character] = nil
		cooldownUntil[character] = os.clock() + (Config.VerticalClimbCooldownSeconds or 0.6)
		return false
	end
	local dur = Config.VerticalClimbDurationSeconds or 0.45
	if (os.clock() - st.t0) > dur then
		active[character] = nil
		cooldownUntil[character] = os.clock() + (Config.VerticalClimbCooldownSeconds or 0.6)
		return false
	end
	-- re-confirm wall and refresh normal for stability
	local hit = findFrontWall(root)
	if not hit then
		active[character] = nil
		cooldownUntil[character] = os.clock() + (Config.VerticalClimbCooldownSeconds or 0.6)
		return false
	end
	st.normal = hit.Normal
	-- stick lightly to wall and add upward velocity
	local up = Vector3.new(0, Config.VerticalClimbUpSpeed or 28, 0)
	local stick = -st.normal * (Config.VerticalClimbStickVelocity or 6)
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(stick.X, math.max(v.Y, up.Y), stick.Z)
	-- opportunistic mantle when reachable
	local Abilities = require(ReplicatedStorage.Movement.Abilities)
	if Abilities and Abilities.isMantleCandidate and Abilities.tryMantle then
		if Abilities.isMantleCandidate(character) then
			if Abilities.tryMantle(character) then
				active[character] = nil
				cooldownUntil[character] = os.clock() + (Config.VerticalClimbCooldownSeconds or 0.6)
				return false
			end
		end
	end
	return true
end

return VerticalClimb
