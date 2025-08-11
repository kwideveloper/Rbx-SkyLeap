-- Wall climbing on parts with Attribute 'climbable' == true

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
local WallMemory = require(game:GetService("ReplicatedStorage").Movement.WallMemory)

local Climb = {}

local active = {}

local function getParts(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function findClimbable(root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent }
	params.IgnoreWater = true

	local directions = {
		root.CFrame.RightVector,
		-root.CFrame.RightVector,
		root.CFrame.LookVector,
		-root.CFrame.LookVector,
	}

	for _, dir in ipairs(directions) do
		local result = workspace:Raycast(root.Position, dir * Config.ClimbDetectionDistance, params)
		if result and result.Instance and result.Instance:GetAttribute("Climbable") == true then
			return result
		end
	end
	return nil
end

function Climb.tryStart(character)
	if active[character] then
		return false
	end
	local root, humanoid = getParts(character)
	if not root or not humanoid then
		return false
	end
	local hit = findClimbable(root)
	if not hit then
		return false
	end

	humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
	humanoid.AutoRotate = false
	active[character] = {
		normal = hit.Normal,
		instance = hit.Instance,
		antiGravity = nil,
		attachment = nil,
	}
	-- Freeze in place until input provided; prevent gravity drift
	root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	-- Add anti-gravity to eliminate slow vertical drift
	local attach = Instance.new("Attachment")
	attach.Name = "ClimbAttach"
	attach.Parent = root
	local vf = Instance.new("VectorForce")
	vf.Name = "ClimbAntiGravity"
	vf.Attachment0 = attach
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity, 0)
	vf.Parent = root
	active[character].attachment = attach
	active[character].antiGravity = vf
	if Config.DebugClimb then
		print("[Climb] tryStart on", tostring(hit.Instance), "normal", hit.Normal)
	end
	return true
end

function Climb.stop(character)
	local data = active[character]
	if not data then
		return
	end
	local root, humanoid = getParts(character)
	if humanoid then
		humanoid.AutoRotate = true
	end
	local data = active[character]
	if data and data.antiGravity then
		data.antiGravity:Destroy()
	end
	if data and data.attachment then
		data.attachment:Destroy()
	end
	active[character] = nil
	if Config.DebugClimb then
		print("[Climb] stop")
	end
end

function Climb.isActive(character)
	return active[character] ~= nil
end

function Climb.isNearClimbable(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local hit = findClimbable(root)
	return hit ~= nil
end

function Climb.maintain(character, input)
	local data = active[character]
	if not data then
		return false
	end
	local root, humanoid = getParts(character)
	if not root or not humanoid then
		Climb.stop(character)
		return false
	end

	-- Recheck the wall and stick to it
	local hit = findClimbable(root)
	if not hit or hit.Instance ~= data.instance then
		Climb.stop(character)
		return false
	end
	data.normal = hit.Normal

	-- Movement axes relative to character orientation but constrained to wall plane
	local n = data.normal
	local right = root.CFrame.RightVector
	right = (right - n * right:Dot(n))
	if right.Magnitude > 0.001 then
		right = right.Unit
	else
		right = (n:Cross(Vector3.yAxis)).Magnitude > 0.01 and n:Cross(Vector3.yAxis).Unit or n:Cross(Vector3.xAxis).Unit
	end

	-- Vertical axis should be world up to ensure W is always upward
	local up = Vector3.yAxis

	local h = 0
	local v = 0
	if typeof(input) == "table" then
		h = input.h or 0
		v = input.v or 0
	end

	local desired = (right * h + up * v) * Config.ClimbSpeed
	-- Only apply stick if we are further than a small threshold from the wall
	local stick = Vector3.new(0, 0, 0)
	do
		local offset = (hit.Position - root.Position)
		local dist = offset.Magnitude
		if dist > 1 then
			stick = -n * Config.ClimbStickVelocity
		end
	end

	-- Keep position when no input: if no keys pressed, zero desired movement
	if math.abs(h) < 0.01 and math.abs(v) < 0.01 then
		desired = Vector3.new(0, 0, 0)
	end
	-- Prevent gravity from pulling down by overwriting vertical component when no vertical input
	if math.abs(v) < 0.01 then
		desired = Vector3.new(desired.X, 0, desired.Z)
	end
	local newVel = Vector3.new(desired.X + stick.X, desired.Y + stick.Y, desired.Z + stick.Z)
	root.AssemblyLinearVelocity = newVel
	-- Keep anti-gravity force updated in case mass/gravity change
	local ag = active[character].antiGravity
	if ag then
		ag.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity, 0)
	end
	if Config.DebugClimb then
		print(string.format("[Climb] v=%.2f h=%.2f vel=(%.2f, %.2f, %.2f)", v, h, newVel.X, newVel.Y, newVel.Z))
	end

	-- Orient character to face the wall
	root.CFrame = CFrame.lookAt(root.Position, root.Position - n, Vector3.yAxis)
	return true
end

function Climb.tryHop(character)
	local data = active[character]
	if not data then
		return false
	end
	local root, humanoid = getParts(character)
	if not root or not humanoid then
		return false
	end

	local normal = data.normal or root.CFrame.RightVector
	-- Use camera facing projected away from the wall for forward boost
	local camera = workspace.CurrentCamera
	local camForward = camera and camera.CFrame.LookVector or root.CFrame.LookVector
	local projectedForward = camForward - (camForward:Dot(normal)) * normal
	if projectedForward.Magnitude < 0.05 then
		projectedForward = root.CFrame.LookVector - (root.CFrame.LookVector:Dot(normal)) * normal
	end
	projectedForward = projectedForward.Magnitude > 0 and projectedForward.Unit or root.CFrame.LookVector

	-- Compose impulse
	local away = normal * Config.WallJumpImpulseAway
	local forwardBoost = projectedForward * Config.WallHopForwardBoost
	local upBoost = Vector3.new(0, Config.WallJumpImpulseUp * 0.6, 0)

	local vel = root.AssemblyLinearVelocity
	vel = Vector3.new(vel.X, 0, vel.Z)
	root.AssemblyLinearVelocity = vel + away + forwardBoost + upBoost
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

	-- Mark this wall so we cannot hop again from the exact same instance mid-air
	if data.instance then
		WallMemory.setLast(character, data.instance)
	end

	Climb.stop(character)
	return true
end

return Climb
