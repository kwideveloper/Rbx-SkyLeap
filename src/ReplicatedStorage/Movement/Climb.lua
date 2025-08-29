-- Wall climbing on parts with Attribute 'climbable' == true

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
local WallMemory = require(game:GetService("ReplicatedStorage").Movement.WallMemory)

local Climb = {}

local active = {}

local function cleanupClimbAnimations(character)
	pcall(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				-- Stop any climb animations that might be running
				local stoppedCount = 0
				for _, track in pairs(animator:GetPlayingAnimationTracks()) do
					if track.Animation and track.Animation.AnimationId then
						local animId = tostring(track.Animation.AnimationId)
						-- Check for various climb-related animation names
						if
							string.find(animId, "Climb")
							or string.find(animId, "climb")
							or string.find(animId, "Climbing")
							or string.find(animId, "climbing")
							or string.find(animId, "Wall")
							or string.find(animId, "wall")
						then
							track:Stop(0.05) -- Stop immediately
							stoppedCount = stoppedCount + 1
							if Config.DebugClimb then
								print("[Climb] Stopped animation:", animId)
							end
						end
					end
				end

				-- Also try to stop any animations by name that might be running
				if stoppedCount == 0 then
					-- Force stop all animations if no specific ones were found
					for _, track in pairs(animator:GetPlayingAnimationTracks()) do
						track:Stop(0.05)
						if Config.DebugClimb then
							print(
								"[Climb] Force stopped animation:",
								track.Animation and track.Animation.Name or "Unknown"
							)
						end
					end
				end

				if Config.DebugClimb then
					print("[Climb] Cleanup completed - stopped", stoppedCount, "animations")
				end
			end
		end
	end)
end

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

	-- Check if player is on ground and too close to wall
	local isOnGround = humanoid.FloorMaterial ~= Enum.Material.Air
	if isOnGround then
		local hit = findClimbable(root)
		if hit then
			local toWall = (hit.Position - root.Position)
			local toWallHoriz = Vector3.new(toWall.X, 0, toWall.Z)
			local distanceToWall = toWallHoriz.Magnitude

			-- If too close to wall from ground, require some upward movement to start climbing
			local minWallDistance = Config.ClimbMinGroundDistance or 1.5
			if distanceToWall < minWallDistance then
				if Config.DebugClimb then
					print(
						"[Climb] Player too close to wall from ground, distance:",
						distanceToWall,
						"min required:",
						minWallDistance
					)
				end
				return false
			end
		end
	end

	local hit = findClimbable(root)
	if not hit then
		return false
	end

	-- Store previous state for proper restoration
	local prevState = humanoid:GetState()
	local prevWalkSpeed = humanoid.WalkSpeed
	local prevJumpPower = humanoid.JumpPower
	local prevAutoRotate = humanoid.AutoRotate

	humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
	humanoid.AutoRotate = false
	active[character] = {
		normal = hit.Normal,
		instance = hit.Instance,
		antiGravity = nil,
		attachment = nil,
		prevState = prevState,
		prevWalkSpeed = prevWalkSpeed,
		prevJumpPower = prevJumpPower,
		prevAutoRotate = prevAutoRotate,
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
		print("[Climb] tryStart on", tostring(hit.Instance), "normal", hit.Normal, "from ground:", isOnGround)
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
		-- Restore all previous states properly
		humanoid.AutoRotate = data.prevAutoRotate or true
		humanoid.WalkSpeed = data.prevWalkSpeed or 16
		humanoid.JumpPower = data.prevJumpPower or 50

		-- Force restore normal physics state
		humanoid:ChangeState(Enum.HumanoidStateType.Running)

		-- Ensure physics are properly enabled
		if root then
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			-- Small delay to ensure state change is processed
			task.spawn(function()
				task.wait(0.1)
				if humanoid and humanoid.Parent then
					-- Force a physics update
					humanoid:ChangeState(Enum.HumanoidStateType.Running)
					if Config.DebugClimb then
						print("[Climb] Physics state restored for character:", character.Name)
					end
				end
			end)
		end
	end

	-- Clean up physics objects
	if data and data.antiGravity then
		data.antiGravity:Destroy()
	end
	if data and data.attachment then
		data.attachment:Destroy()
	end

	-- Clean up any climb animations
	cleanupClimbAnimations(character)

	active[character] = nil

	if Config.DebugClimb then
		print("[Climb] stop - all states restored")
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

	-- Check if player is too close to ground level
	local isTooCloseToGround = false
	if Config.ClimbGroundProximityCheck then
		-- Only check ground proximity when moving downward or if explicitly enabled
		local shouldCheckGround = true
		if Config.ClimbGroundCheckOnlyWhenDescending then
			-- Get input direction to determine if we should check ground
			local inputV = 0
			if typeof(input) == "table" then
				inputV = input.v or 0
			end
			shouldCheckGround = inputV < 0 -- Only check when moving down
		end

		if shouldCheckGround then
			pcall(function()
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { root.Parent }
				params.IgnoreWater = true

				-- Use a more intelligent ground detection that considers the climbing context
				local groundCheck = workspace:Raycast(root.Position, Vector3.new(0, -3, 0), params)
				if groundCheck then
					local distanceToGround = root.Position.Y - groundCheck.Position.Y
					local minGroundDistance = Config.ClimbMinGroundDistance or 2.0

					-- Additional validation: check if we're actually hitting the real ground
					-- and not just a wall or obstacle below us
					local isRealGround = false
					if groundCheck.Instance then
						-- Check if the hit surface is actually ground-like
						local normal = groundCheck.Normal
						local groundNormalThreshold = Config.ClimbGroundNormalThreshold or 0.7
						local isHorizontal = math.abs(normal:Dot(Vector3.yAxis)) > groundNormalThreshold

						-- Also check if we're not hitting the same wall we're climbing
						local excludeClimbingWall = Config.ClimbGroundExcludeClimbingWall ~= false
						local isNotClimbingWall = true
						if excludeClimbingWall then
							isNotClimbingWall = groundCheck.Instance ~= data.instance
						end

						isRealGround = isHorizontal and isNotClimbingWall
					end

					-- Only consider it "too close to ground" if it's actually ground and we're close
					if distanceToGround < minGroundDistance and isRealGround then
						isTooCloseToGround = true
						if Config.DebugClimb then
							print(
								"[Climb] Too close to ground, distance:",
								distanceToGround,
								"min required:",
								minGroundDistance,
								"surface:",
								groundCheck.Instance.Name
							)
						end
					elseif Config.DebugClimb and distanceToGround < minGroundDistance then
						-- Log when we're close to something but it's not ground
						print(
							"[Climb] Close to surface but not ground - distance:",
							distanceToGround,
							"surface:",
							groundCheck.Instance.Name,
							"isGround:",
							isRealGround
						)
					end
				end
			end)
		end
	end

	-- Check if player is very close to a ledge edge during climb
	-- This prevents automatic mantle execution while still allowing manual input
	local isNearLedgeEdge = false
	local shouldLimitMovement = false
	local shouldAutoDisableClimbForMantle = false

	-- First, check if we should auto-disable climb to allow mantle execution
	if Config.ClimbMantleIntegrationEnabled and Config.ClimbAutoDisableForMantle then
		pcall(function()
			local Abilities = require(game:GetService("ReplicatedStorage").Movement.Abilities)
			if Abilities and Abilities.detectLedgeForMantle then
				local ledgeOk, hitRes, topY = Abilities.detectLedgeForMantle(root)
				if ledgeOk then
					-- Check if the ledge is at the correct distance for mantle execution
					local toWall = (hitRes.Position - root.Position)
					local toWallHoriz = Vector3.new(toWall.X, 0, toWall.Z)
					local distanceToLedge = toWallHoriz.Magnitude
					local ledgeHeightDiff = topY - root.Position.Y

					-- Use mantle configuration to determine when to auto-disable climb
					local mantleDetectionDistance = Config.MantleDetectionDistance or 4.0
					local mantleMaxAboveWaist = Config.MantleAboveWaistWhileClimbing or 5.0

					-- Check if we're at the perfect distance for mantle execution
					if distanceToLedge <= mantleDetectionDistance and ledgeHeightDiff <= mantleMaxAboveWaist then
						shouldAutoDisableClimbForMantle = true
						if Config.DebugClimb then
							print(
								"[Climb] Auto-disable for mantle (climbing) - distance:",
								distanceToLedge,
								"height diff:",
								ledgeHeightDiff,
								"mantle detection distance:",
								mantleDetectionDistance,
								"mantle above waist while climbing:",
								mantleMaxAboveWaist
							)
						end
					end
				end
			end
		end)
	end

	-- If we should auto-disable climb for mantle, do it immediately
	if shouldAutoDisableClimbForMantle then
		if Config.DebugClimb then
			print("[Climb] Auto-disabling climb to allow mantle execution")
		end
		Climb.stop(character)
		return -- Exit the maintain function
	end

	-- Then check for ledge edge detection (if enabled)
	if
		Config.ClimbMantleIntegrationEnabled
		and Config.ClimbLedgeEdgeDetectionEnabled
		and not Config.ClimbLedgeEdgeDetectionCompletelyDisabled
	then
		pcall(function()
			local Abilities = require(game:GetService("ReplicatedStorage").Movement.Abilities)
			if Abilities and Abilities.detectLedgeForMantle then
				local ledgeOk, hitRes, topY = Abilities.detectLedgeForMantle(root)
				if ledgeOk then
					-- Check if the ledge is very close and at appropriate height for mantle
					local toWall = (hitRes.Position - root.Position)
					local toWallHoriz = Vector3.new(toWall.X, 0, toWall.Z)
					local distanceToLedge = toWallHoriz.Magnitude
					local ledgeHeightDiff = topY - root.Position.Y

					-- Use configuration values for edge detection
					local edgeDistance = Config.ClimbLedgeEdgeDetectionDistance or 1.5
					local edgeHeightRange = Config.ClimbLedgeEdgeHeightRange or { 0, 3 }
					local restrictiveDistance = Config.ClimbLedgeEdgeRestrictiveDistance or 0.2
					local movementLimitThreshold = Config.ClimbLedgeEdgeMovementLimitThreshold or 0.3

					-- Mark as near edge if within detection range
					if
						distanceToLedge < edgeDistance
						and ledgeHeightDiff >= edgeHeightRange[1]
						and ledgeHeightDiff <= edgeHeightRange[2]
					then
						isNearLedgeEdge = true

						-- Only limit movement if extremely close (more restrictive)
						if distanceToLedge < movementLimitThreshold then
							shouldLimitMovement = true
						end

						if Config.DebugClimb then
							print(
								"[Climb] Near ledge edge detected - distance:",
								distanceToLedge,
								"height diff:",
								ledgeHeightDiff,
								"detection threshold:",
								edgeDistance,
								"movement limit threshold:",
								movementLimitThreshold,
								"will limit movement:",
								shouldLimitMovement
							)
						end
					end
				end
			end
		end)
	end

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

	-- If too close to ground, limit downward movement
	if isTooCloseToGround and v < 0 then
		local groundMovementLimit = Config.ClimbGroundMovementLimit or 0.2
		v = math.max(v, -groundMovementLimit) -- Allow slight downward movement but not much
		if Config.DebugClimb then
			print("[Climb] Limiting downward movement near ground to:", groundMovementLimit)
		end
	end

	-- If near ledge edge, limit upward movement to prevent automatic mantle
	if shouldLimitMovement and v > 0 then
		local movementLimit = Config.ClimbLedgeEdgeMovementLimit or 0.3
		v = math.min(v, movementLimit) -- Reduce upward movement when near ledge edge
		if Config.DebugClimb then
			print("[Climb] Limiting upward movement near ledge edge to:", movementLimit)
		end
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

	-- Drain stamina; if depleted, stop climbing immediately
	do
		local folder = game:GetService("ReplicatedStorage"):FindFirstChild("ClientState")
		local staminaValue = folder and folder:FindFirstChild("Stamina")
		if staminaValue then
			-- Approximate dt using Heartbeat delta from RunService if not passed here
			local hb = game:GetService("RunService").Heartbeat:Wait()
			local delta = typeof(hb) == "number" and hb or 0.016
			staminaValue.Value = math.max(0, staminaValue.Value - (Config.ClimbStaminaDrainPerSecond * delta))
			if staminaValue.Value <= 0 then
				Climb.stop(character)
				return false
			end
		end
	end
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
