-- Basic wall running helper

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
local WallMemory = require(game:GetService("ReplicatedStorage").Movement.WallMemory)

local WallRun = {}
local active = {}
local cooldownUntil = {}
local WallMemory = require(game:GetService("ReplicatedStorage").Movement.WallMemory)

local function getCharacterParts(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function findWall(rootPart)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rootPart.Parent }
	params.IgnoreWater = Config.RaycastIgnoreWater

	local directions = {
		rootPart.CFrame.RightVector,
		-rootPart.CFrame.RightVector,
	}

	for _, dir in ipairs(directions) do
		local result = workspace:Raycast(rootPart.Position, dir * Config.WallDetectionDistance, params)
		if result and result.Instance and result.Instance.CanCollide then
			local inst = result.Instance
			local climbable = inst:GetAttribute("Climbable") or inst:GetAttribute("climbable")
			local wallJumpAttr = inst:GetAttribute("WallJump")
			-- Wall run is disabled if wall is climbable or explicitly has WallJump = false
			local wallRunAllowed = not (climbable == true or wallJumpAttr == false)
			if wallRunAllowed then
				return {
					normal = result.Normal,
					position = result.Position,
					instance = inst,
				}
			end
		end
	end

	return nil
end

function WallRun.tryStart(character)
	local now = os.clock()
	local untilTime = cooldownUntil[character]
	if untilTime and now < untilTime then
		return false
	end
	if active[character] then
		return false
	end
	local rootPart, humanoid = getCharacterParts(character)
	if not rootPart or not humanoid then
		return false
	end

	if humanoid.MoveDirection.Magnitude < 0.1 then
		return false
	end

	local currentSpeed = rootPart.AssemblyLinearVelocity.Magnitude
	if currentSpeed < Config.WallRunMinSpeed then
		return false
	end

	local hit = findWall(rootPart)
	if not hit then
		return false
	end

	humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
	local originalWalkSpeed = humanoid.WalkSpeed
	local originalJumpPower = humanoid.JumpPower
	local originalAutoRotate = humanoid.AutoRotate
	humanoid.WalkSpeed = Config.WallRunSpeed
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	local token = {}
	active[character] = {
		humanoid = humanoid,
		originalWalkSpeed = originalWalkSpeed,
		originalJumpPower = originalJumpPower,
		originalAutoRotate = originalAutoRotate,
		token = token,
		lastWallNormal = hit.normal,
	}

	task.delay(Config.WallRunMaxDurationSeconds, function()
		local data = active[character]
		if data and data.token == token then
			if data.humanoid and data.humanoid.Parent then
				data.humanoid.WalkSpeed = data.originalWalkSpeed or Config.BaseWalkSpeed
				data.humanoid.JumpPower = data.originalJumpPower or 50
				data.humanoid.AutoRotate = data.originalAutoRotate ~= nil and data.originalAutoRotate or true
				data.humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			end
			active[character] = nil
		end
	end)

	return true
end

function WallRun.stop(character)
	local data = active[character]
	if not data then
		return
	end
	if data.humanoid and data.humanoid.Parent then
		data.humanoid.WalkSpeed = data.originalWalkSpeed or Config.BaseWalkSpeed
		data.humanoid.JumpPower = data.originalJumpPower or 50
		data.humanoid.AutoRotate = data.originalAutoRotate ~= nil and data.originalAutoRotate or true
		data.humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
	end
	active[character] = nil
end

function WallRun.isActive(character)
	return active[character] ~= nil
end

function WallRun.maintain(character)
	local data = active[character]
	if not data then
		return false
	end
	local rootPart, humanoid = getCharacterParts(character)
	if not rootPart or not humanoid then
		WallRun.stop(character)
		return false
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		WallRun.stop(character)
		WallMemory.clear(character)
		return false
	end
	if humanoid.MoveDirection.Magnitude < 0.1 then
		WallRun.stop(character)
		return false
	end
	local hit = findWall(rootPart)
	if not hit then
		WallRun.stop(character)
		return false
	end
	data.lastWallNormal = hit.normal
	-- Compute tangent along the wall to move forward while sticking slightly and falling slowly
	local normal = hit.normal
	local move = humanoid.MoveDirection
	if move.Magnitude < 0.05 then
		move = rootPart.CFrame.LookVector
	end
	local projected = move - (move:Dot(normal)) * normal
	if projected.Magnitude < 0.05 then
		local fallback = normal:Cross(Vector3.yAxis)
		if fallback.Magnitude < 0.05 then
			fallback = normal:Cross(Vector3.xAxis)
		end
		projected = fallback
	end
	local tangent = projected.Unit

	-- Orientation along the wall direction
	local up = Vector3.yAxis
	local look = tangent
	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + look, up)

	local horizontal = tangent * Config.WallRunSpeed + (-normal * Config.WallStickVelocity)
	local newVel = Vector3.new(horizontal.X, -Config.WallRunDownSpeed, horizontal.Z)
	rootPart.AssemblyLinearVelocity = newVel
	return true
end

function WallRun.tryHop(character)
	local data = active[character]
	if not data then
		return false
	end
	local rootPart, humanoid = getCharacterParts(character)
	if not rootPart or not humanoid then
		return false
	end
	local normal = data.lastWallNormal or rootPart.CFrame.RightVector
	-- Use camera-facing direction projected off the wall to push towards where the player is looking
	local camera = workspace.CurrentCamera
	local camForward = camera and camera.CFrame.LookVector or rootPart.CFrame.LookVector
	local projectedForward = camForward - (camForward:Dot(normal)) * normal
	if projectedForward.Magnitude < 0.05 then
		local fallback = rootPart.CFrame.LookVector - (rootPart.CFrame.LookVector:Dot(normal)) * normal
		projectedForward = fallback.Magnitude > 0.05 and fallback or (normal:Cross(Vector3.yAxis))
	end
	projectedForward = projectedForward.Unit

	local away = normal * Config.WallJumpImpulseAway
	local forwardBoost = projectedForward * Config.WallHopForwardBoost
	local carry = rootPart.AssemblyLinearVelocity * 0.25
	local horizontalCarry = Vector3.new(carry.X, 0, carry.Z)

	local upBoost = Vector3.new(0, Config.WallJumpImpulseUp * 0.6, 0)
	rootPart.AssemblyLinearVelocity = horizontalCarry + away + forwardBoost + upBoost
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	WallRun.stop(character)
	-- mark this wall as used so the next hop must be from a different wall
	local wallInstance = nil
	do
		-- Try to recast to get the instance we hopped from
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { rootPart.Parent }
		params.IgnoreWater = Config.RaycastIgnoreWater
		local result = workspace:Raycast(rootPart.Position - normal, normal * 2, params)
		wallInstance = result and result.Instance or nil
	end
	if wallInstance then
		WallMemory.setLast(character, wallInstance)
	end
	cooldownUntil[character] = os.clock() + 0.45
	return true
end

function WallRun.isNearWall(character)
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end
	local hit = findWall(rootPart)
	return hit ~= nil
end

return WallRun
