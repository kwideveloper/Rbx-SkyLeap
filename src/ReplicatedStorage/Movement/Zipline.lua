-- Zipline module: ride along RopeConstraint between two attachments

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)

local Zipline = {}

-- Track active rides per character
local active = {}

local function getCharacterParts(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

-- Find the closest rope setup near the character. We assume the world has a folder named `Ziplines`
-- that contains models with two endpoints which have `Attachment` objects connected by a `RopeConstraint` on one side.
local function findNearestRope(rootPart)
	local ziplinesFolder = workspace:FindFirstChild("Ziplines")
	if not ziplinesFolder then
		return nil
	end
	local closest, closestDistSq = nil, math.huge
	for _, model in ipairs(ziplinesFolder:GetDescendants()) do
		if model:IsA("RopeConstraint") then
			local a0 = model.Attachment0
			local a1 = model.Attachment1
			if a0 and a1 and a0.Parent and a1.Parent then
				local p0 = a0.WorldPosition
				local p1 = a1.WorldPosition
				-- Measure distance to the rope segment
				local p = rootPart.Position
				local ap = p - p0
				local ab = p1 - p0
				local t = 0
				local abLenSq = ab:Dot(ab)
				if abLenSq > 0 then
					t = math.clamp(ap:Dot(ab) / abLenSq, 0, 1)
				end
				local closestPoint = p0 + ab * t
				local distSq = (p - closestPoint).Magnitude ^ 2
				if distSq < closestDistSq then
					closestDistSq = distSq
					closest = {
						rope = model,
						a0 = a0,
						a1 = a1,
						p0 = p0,
						p1 = p1,
						t = t,
						closestPoint = closestPoint,
					}
				end
			end
		end
	end
	if not closest then
		return nil
	end
	local distance = (rootPart.Position - closest.closestPoint).Magnitude
	if distance <= (Config.ZiplineDetectionDistance or 5) then
		return closest
	end
	return nil
end

local function computeRopePoint(a0, a1, alpha)
	local p0 = a0.WorldPosition
	local p1 = a1.WorldPosition
	local dir = (p1 - p0)
	return p0 + dir * alpha, dir
end

function Zipline.isNear(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	return findNearestRope(root) ~= nil
end

function Zipline.isActive(character)
	return active[character] ~= nil
end

function Zipline.tryStart(character)
	if active[character] then
		return false
	end
	local root, humanoid = getCharacterParts(character)
	if not root or not humanoid then
		return false
	end
	local info = findNearestRope(root)
	if not info then
		return false
	end

	humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
	humanoid.AutoRotate = false

	-- Bidirectional: choose direction based on where the player is looking.
	local p0, p1 = info.p0, info.p1
	local ropeDir = (p1 - p0)
	local ropeDirUnit = ropeDir.Magnitude > 0 and ropeDir.Unit or Vector3.new(1, 0, 0)
	-- Use character orientation instead of camera
	local look = root.CFrame.LookVector
	local dot = look:Dot(ropeDirUnit)
	local dirSign = (dot >= 0) and 1 or -1
	-- If looking almost perpendicular, fall back to downhill
	if math.abs(dot) < 0.05 then
		dirSign = (p0.Y > p1.Y) and 1 or -1
	end

	local token = {}
	active[character] = {
		a0 = info.a0,
		a1 = info.a1,
		t = info.t,
		dirSign = dirSign,
		token = token,
	}
	return true
end

function Zipline.stop(character)
	local data = active[character]
	if not data then
		return
	end
	local _, humanoid = getCharacterParts(character)
	if humanoid then
		humanoid.AutoRotate = true
		-- Ensure we leave the non-physics state so jumping works immediately
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	active[character] = nil
end

-- Update zipline motion. Returns true if still active.
function Zipline.maintain(character, dt)
	local data = active[character]
	if not data then
		return false
	end
	local root, humanoid = getCharacterParts(character)
	if not root or not humanoid then
		Zipline.stop(character)
		return false
	end

	-- Move parameter t along rope
	local speed = Config.ZiplineSpeed or 40
	local p0 = data.a0.WorldPosition
	local p1 = data.a1.WorldPosition
	local length = (p1 - p0).Magnitude
	if length < 0.1 then
		Zipline.stop(character)
		return false
	end
	local deltaT = (speed * dt) / length
	data.t = data.t + deltaT * data.dirSign
	data.t = math.clamp(data.t, 0, 1)

	local pos, dir = computeRopePoint(data.a0, data.a1, data.t)
	local forward = dir.Unit * data.dirSign

	-- Stick slightly to the rope and apply forward velocity
	local horizontal = forward * speed + Vector3.new(0, -0.5, 0)
	root.CFrame = CFrame.lookAt(pos, pos + forward, Vector3.yAxis)
	root.AssemblyLinearVelocity = horizontal

	-- Detach at ends; keep a small upward nudge so jump feels responsive on exit
	if data.t <= 0.001 or data.t >= 0.999 then
		local _, humanoid = getCharacterParts(character)
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
		Zipline.stop(character)
		return false
	end
	return true
end

return Zipline
