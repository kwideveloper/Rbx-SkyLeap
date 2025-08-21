-- Ledge Hanging system: allows player to hang from edges and move horizontally
-- Triggered when mantle fails due to insufficient clearance above

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
local Animations = require(game:GetService("ReplicatedStorage").Movement.Animations)
local RunService = game:GetService("RunService")

local LedgeHang = {}

local activeHangs = {} -- [character] = hangData

local function getCharacterParts(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

-- Check if there's enough clearance above for a full mantle
local function hasEnoughClearanceAbove(root, ledgeY, forwardDirection)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent }
	params.IgnoreWater = true

	local halfHeight = (root.Size and root.Size.Y or 2) * 0.5
	local requiredClearance = Config.LedgeHangMinClearance or 3.5 -- studs above ledge
	local checkHeight = ledgeY + requiredClearance

	-- Check multiple points above the ledge for obstacles
	local checkPoints = {
		Vector3.new(0, 0, 0), -- center
		Vector3.new(0.8, 0, 0), -- left
		Vector3.new(-0.8, 0, 0), -- right
		forwardDirection * 0.5, -- slightly forward
	}

	for _, offset in ipairs(checkPoints) do
		local checkPos = Vector3.new(root.Position.X + offset.X, checkHeight, root.Position.Z + offset.Z)
		local hit = workspace:Raycast(checkPos, Vector3.new(0, -requiredClearance, 0), params)
		if hit and hit.Position.Y > ledgeY + 0.5 then
			return false -- obstacle found above
		end
	end

	return true
end

-- Detect ledge for hanging (similar to mantle detection but with clearance check)
function LedgeHang.detectLedgeForHang(character)
	local root, humanoid = getCharacterParts(character)
	if not root or not humanoid then
		return false
	end

	-- Use similar detection as mantle but check clearance
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = Config.RaycastIgnoreWater

	local origin = root.Position
	local forward = root.CFrame.LookVector
	local distance = Config.LedgeHangDetectionDistance or 3.5

	local hit = workspace:Raycast(origin, forward * distance, params)
	if not hit or not hit.Instance or not hit.Instance.CanCollide then
		return false
	end

	-- Find top of the obstacle
	local topY = nil
	local checkOrigin = Vector3.new(hit.Position.X, hit.Position.Y + 5, hit.Position.Z)
	local downRay = workspace:Raycast(checkOrigin, Vector3.new(0, -10, 0), params)
	if downRay then
		topY = downRay.Position.Y
	end

	if not topY then
		return false
	end

	-- Check if ledge is at appropriate height
	local waistY = root.Position.Y
	local aboveWaist = topY - waistY
	local minH = Config.LedgeHangMinHeight or 1.5
	local maxH = Config.LedgeHangMaxHeight or 4.0

	if aboveWaist < minH or aboveWaist > maxH then
		return false
	end

	-- Check if there's insufficient clearance above (this makes it a hang candidate)
	local forwardDir = Vector3.new(forward.X, 0, forward.Z).Unit
	if hasEnoughClearanceAbove(root, topY, forwardDir) then
		return false -- enough clearance, should use mantle instead
	end

	return true, hit, topY, forwardDir
end

-- Alternative tryStart that uses mantle detection data (more reliable)
function LedgeHang.tryStartFromMantleData(character, hitRes, ledgeY)
	if activeHangs[character] then
		return false
	end

	local root, humanoid = getCharacterParts(character)
	if not root or not humanoid then
		return false
	end

	-- Calculate forward direction from hit
	local toWall = (hitRes.Position - root.Position)
	local forwardDir = Vector3.new(toWall.X, 0, toWall.Z)
	if forwardDir.Magnitude > 0.01 then
		forwardDir = forwardDir.Unit
	else
		forwardDir = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	end

	return LedgeHang.startHang(character, hitRes, ledgeY, forwardDir)
end

function LedgeHang.tryStart(character)
	if activeHangs[character] then
		return false
	end

	local ok, hitRes, ledgeY, forwardDir = LedgeHang.detectLedgeForHang(character)
	if not ok then
		return false
	end

	return LedgeHang.startHang(character, hitRes, ledgeY, forwardDir)
end

-- Common hang start logic
function LedgeHang.startHang(character, hitRes, ledgeY, forwardDir)
	local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
	local root, humanoid = getCharacterParts(character)
	if not root or not humanoid then
		return false
	end

	if Config.DebugLedgeHang then
		print(string.format("[LedgeHang] Starting hang at ledgeY=%.2f", ledgeY))
	end

	-- Position character hanging from ledge
	local halfHeight = (root.Size and root.Size.Y or 2) * 0.5
	local hangDistance = Config.LedgeHangDistance or 1.2
	local hangY = ledgeY - halfHeight - (Config.LedgeHangDropDistance or 0.8)

	local hangPos = Vector3.new(
		hitRes.Position.X - forwardDir.X * hangDistance,
		hangY,
		hitRes.Position.Z - forwardDir.Z * hangDistance
	)

	-- Create hang state
	local hangData = {
		ledgePosition = hitRes.Position,
		ledgeY = ledgeY,
		forwardDirection = forwardDir,
		surfaceNormal = hitRes.Normal,
		originalAutoRotate = humanoid.AutoRotate,
		originalWalkSpeed = humanoid.WalkSpeed,
		startTime = os.clock(),
	}

	activeHangs[character] = hangData

	-- Set character state
	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
	root.CFrame = CFrame.new(hangPos, hangPos + forwardDir)
	root.AssemblyLinearVelocity = Vector3.new()

	-- Play ledge hang start animation
	local startTrack = nil
	local loopTrack = nil
	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid

		-- Stop any mantle animations that might be playing
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if track.Name and string.find(track.Name:lower(), "mantle") then
				track:Stop(0.1)
			end
		end

		-- Play hang start animation
		local startAnim = Animations.get("LedgeHangStart")
		if startAnim then
			startTrack = animator:LoadAnimation(startAnim)
			if startTrack then
				startTrack.Priority = Enum.AnimationPriority.Action
				startTrack.Looped = false
				startTrack:Play()

				-- When start ends, play loop animation
				startTrack.Stopped:Connect(function()
					local loopAnim = Animations.get("LedgeHangLoop")
					if loopAnim and activeHangs[character] then
						loopTrack = animator:LoadAnimation(loopAnim)
						if loopTrack then
							loopTrack.Priority = Enum.AnimationPriority.Action
							loopTrack.Looped = true
							loopTrack:Play()
						end
					end
				end)
			end
		else
			-- Fallback to loop animation if no start animation
			local loopAnim = Animations.get("LedgeHangLoop")
			if loopAnim then
				loopTrack = animator:LoadAnimation(loopAnim)
				if loopTrack then
					loopTrack.Priority = Enum.AnimationPriority.Action
					loopTrack.Looped = true
					loopTrack:Play()
				end
			end
		end

		-- Store animation tracks in hang data for cleanup
		hangData.startTrack = startTrack
		hangData.loopTrack = loopTrack
	end)

	-- Mark hang time for cooldown
	LedgeHang.markHangTime(character)

	-- Set hang flag for other systems
	pcall(function()
		local rs = game:GetService("ReplicatedStorage")
		local cs = rs:FindFirstChild("ClientState") or Instance.new("Folder")
		if not cs.Parent then
			cs.Name = "ClientState"
			cs.Parent = rs
		end
		local flag = cs:FindFirstChild("IsLedgeHanging")
		if not flag then
			flag = Instance.new("BoolValue")
			flag.Name = "IsLedgeHanging"
			flag.Value = false
			flag.Parent = cs
		end
		flag.Value = true
	end)

	return true
end

function LedgeHang.stop(character)
	local hangData = activeHangs[character]
	if not hangData then
		return
	end

	local root, humanoid = getCharacterParts(character)
	if humanoid then
		humanoid.AutoRotate = hangData.originalAutoRotate
		humanoid.WalkSpeed = hangData.originalWalkSpeed or Config.BaseWalkSpeed
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	-- Stop hang animations
	pcall(function()
		if hangData.startTrack then
			hangData.startTrack:Stop(0.1)
		end
		if hangData.loopTrack then
			hangData.loopTrack:Stop(0.1)
		end
		if hangData.moveTrack then
			hangData.moveTrack:Stop(0.1)
		end
	end)

	activeHangs[character] = nil

	-- Clear hang flag
	pcall(function()
		local rs = game:GetService("ReplicatedStorage")
		local cs = rs:FindFirstChild("ClientState")
		local flag = cs and cs:FindFirstChild("IsLedgeHanging")
		if flag then
			flag.Value = false
		end
	end)
end

function LedgeHang.isActive(character)
	return activeHangs[character] ~= nil
end

-- Update hanging position and handle horizontal movement
function LedgeHang.maintain(character, moveDirection)
	local hangData = activeHangs[character]
	if not hangData then
		return false
	end

	local root, humanoid = getCharacterParts(character)
	if not root or not humanoid then
		LedgeHang.stop(character)
		return false
	end

	-- Check for timeout
	local maxDuration = Config.LedgeHangMaxDurationSeconds or 10
	if os.clock() - hangData.startTime > maxDuration then
		if Config.DebugLedgeHang then
			print("[LedgeHang] Timeout reached, auto-releasing with cooldown")
		end
		-- Mark hang time to prevent immediate re-hang
		LedgeHang.markHangTime(character)
		LedgeHang.stop(character)
		return false
	end

	-- Handle horizontal movement along the ledge
	local rightVector = hangData.forwardDirection:Cross(Vector3.yAxis)
	local horizontalInput = Vector3.new()
	local isMoving = false

	if moveDirection and moveDirection.Magnitude > 0.1 then
		-- Project input onto ledge-relative directions
		local rightDot = moveDirection:Dot(rightVector)
		horizontalInput = rightVector * rightDot
		isMoving = math.abs(rightDot) > 0.1
	end

	-- Handle movement animation
	pcall(function()
		if isMoving and not hangData.isPlayingMoveAnim then
			-- Start move animation
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local animator = humanoid:FindFirstChildOfClass("Animator")
				if animator and hangData.loopTrack then
					hangData.loopTrack:Stop(0.1)
				end

				local moveAnim = Animations.get("LedgeHangMove")
				if moveAnim and animator then
					hangData.moveTrack = animator:LoadAnimation(moveAnim)
					if hangData.moveTrack then
						hangData.moveTrack.Priority = Enum.AnimationPriority.Action
						hangData.moveTrack.Looped = true
						hangData.moveTrack:Play()
						hangData.isPlayingMoveAnim = true
					end
				end
			end
		elseif not isMoving and hangData.isPlayingMoveAnim then
			-- Stop move animation, resume loop
			if hangData.moveTrack then
				hangData.moveTrack:Stop(0.1)
				hangData.moveTrack = nil
			end
			hangData.isPlayingMoveAnim = false

			-- Resume loop animation
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local animator = humanoid:FindFirstChildOfClass("Animator")
				local loopAnim = Animations.get("LedgeHangLoop")
				if loopAnim and animator then
					hangData.loopTrack = animator:LoadAnimation(loopAnim)
					if hangData.loopTrack then
						hangData.loopTrack.Priority = Enum.AnimationPriority.Action
						hangData.loopTrack.Looped = true
						hangData.loopTrack:Play()
					end
				end
			end
		end
	end)

	-- Move along the ledge
	local moveSpeed = Config.LedgeHangMoveSpeed or 8
	local currentPos = root.Position
	local newPos = currentPos + horizontalInput * moveSpeed * (1 / 60) -- assume 60fps for now

	-- Keep at consistent distance from wall and height
	local halfHeight = (root.Size and root.Size.Y or 2) * 0.5
	local hangDistance = Config.LedgeHangDistance or 1.2
	local hangY = hangData.ledgeY - halfHeight - (Config.LedgeHangDropDistance or 0.8)

	local wallPos = Vector3.new(
		newPos.X + hangData.forwardDirection.X * hangDistance,
		hangData.ledgeY,
		newPos.Z + hangData.forwardDirection.Z * hangDistance
	)

	newPos = Vector3.new(newPos.X, hangY, newPos.Z)

	-- Update position
	root.CFrame = CFrame.new(newPos, newPos + hangData.forwardDirection)
	root.AssemblyLinearVelocity = Vector3.new()

	return true
end

-- Try to mantle up from hanging position
function LedgeHang.tryMantleUp(character)
	local hangData = activeHangs[character]
	if not hangData then
		return false
	end

	local root = getCharacterParts(character)
	if not root then
		return false
	end

	-- Check if there's now enough clearance above
	if hasEnoughClearanceAbove(root, hangData.ledgeY, hangData.forwardDirection) then
		-- Mark the hang time for cooldown purposes
		LedgeHang.markHangTime(character)
		LedgeHang.stop(character)
		-- Trigger normal mantle
		local Abilities = require(game:GetService("ReplicatedStorage").Movement.Abilities)
		return Abilities.tryMantle(character)
	end

	return false
end

-- Directional jump from ledge hang
function LedgeHang.tryDirectionalJump(character, direction)
	local hangData = activeHangs[character]
	if not hangData then
		return false
	end

	local root, humanoid = getCharacterParts(character)
	if not root or not humanoid then
		return false
	end

	-- Check stamina cost - simplified for now, we'll integrate with ParkourController stamina later
	local jumpCost = Config.LedgeHangJumpStaminaCost or 10

	if Config.DebugLedgeHang then
		print(string.format("[LedgeHang] Attempting directional jump: %s, cost: %d", direction, jumpCost))
		print(
			string.format(
				"[LedgeHang] Config values - Up:%s, Side:%s, Back:%s, WallSep:%s",
				tostring(Config.LedgeHangJumpUpForce),
				tostring(Config.LedgeHangJumpSideForce),
				tostring(Config.LedgeHangJumpBackForce),
				tostring(Config.LedgeHangWallSeparationForce)
			)
		)
	end

	-- Calculate impulse direction and force
	local impulseDirection = Vector3.new()
	local force = 0

	-- Use player's current facing direction for lateral movement (more intuitive)
	local playerForward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local playerRight = playerForward:Cross(Vector3.yAxis).Unit

	-- For forward/back, use the hang orientation (wall direction)
	local hangForward = hangData.forwardDirection

	if direction == "up" then
		-- W + Space: Jump straight up with slight forward momentum relative to wall
		impulseDirection = Vector3.new(hangForward.X * 0.3, 1.0, hangForward.Z * 0.3)
		force = Config.LedgeHangJumpUpForce or 120
		if Config.DebugLedgeHang then
			print(
				string.format("[LedgeHang] UP force: Config=%s, final=%d", tostring(Config.LedgeHangJumpUpForce), force)
			)
		end
	elseif direction == "left" then
		-- A + Space: Jump left + slightly backward (combines lateral + back movement)
		local leftComponent = Vector3.new(-playerRight.X * 0.8, 0.3, -playerRight.Z * 0.8)
		local backComponent = Vector3.new(-hangForward.X * 0.3, 0, -hangForward.Z * 0.3)
		impulseDirection = leftComponent + backComponent
		force = Config.LedgeHangJumpSideForce or 120
		if Config.DebugLedgeHang then
			print(
				string.format(
					"[LedgeHang] LEFT force: Config=%s, final=%d",
					tostring(Config.LedgeHangJumpSideForce),
					force
				)
			)
			print(
				string.format(
					"[LedgeHang] LEFT components - lateral:(%.2f,%.2f,%.2f) + back:(%.2f,%.2f,%.2f)",
					leftComponent.X,
					leftComponent.Y,
					leftComponent.Z,
					backComponent.X,
					backComponent.Y,
					backComponent.Z
				)
			)
		end
	elseif direction == "right" then
		-- D + Space: Jump right + slightly backward (combines lateral + back movement)
		local rightComponent = Vector3.new(playerRight.X * 0.8, 0.3, playerRight.Z * 0.8)
		local backComponent = Vector3.new(-hangForward.X * 0.3, 0, -hangForward.Z * 0.3)
		impulseDirection = rightComponent + backComponent
		force = Config.LedgeHangJumpSideForce or 120
		if Config.DebugLedgeHang then
			print(
				string.format(
					"[LedgeHang] RIGHT force: Config=%s, final=%d",
					tostring(Config.LedgeHangJumpSideForce),
					force
				)
			)
			print(
				string.format(
					"[LedgeHang] RIGHT components - lateral:(%.2f,%.2f,%.2f) + back:(%.2f,%.2f,%.2f)",
					rightComponent.X,
					rightComponent.Y,
					rightComponent.Z,
					backComponent.X,
					backComponent.Y,
					backComponent.Z
				)
			)
		end
	elseif direction == "back" then
		-- S + Space: Jump backward from wall
		impulseDirection = Vector3.new(-hangForward.X * 0.8, 0.3, -hangForward.Z * 0.8)
		force = Config.LedgeHangJumpBackForce or 120
		if Config.DebugLedgeHang then
			print(
				string.format(
					"[LedgeHang] BACK force: Config=%s, final=%d",
					tostring(Config.LedgeHangJumpBackForce),
					force
				)
			)
		end
	else
		return false -- invalid direction
	end

	-- Normalize the direction but keep reasonable magnitude
	if impulseDirection.Magnitude > 0 then
		impulseDirection = impulseDirection.Unit
	else
		return false
	end

	if Config.DebugLedgeHang then
		print(
			string.format(
				"[LedgeHang] Direction calc - playerForward:(%.2f,%.2f,%.2f), playerRight:(%.2f,%.2f,%.2f)",
				playerForward.X,
				playerForward.Y,
				playerForward.Z,
				playerRight.X,
				playerRight.Y,
				playerRight.Z
			)
		)
		print(string.format("[LedgeHang] hangForward:(%.2f,%.2f,%.2f)", hangForward.X, hangForward.Y, hangForward.Z))
		print(
			string.format(
				"[LedgeHang] Raw impulse direction before normalize:(%.2f,%.2f,%.2f)",
				impulseDirection.X,
				impulseDirection.Y,
				impulseDirection.Z
			)
		)
		print(
			string.format(
				"[LedgeHang] Final impulse direction: (%.2f,%.2f,%.2f)",
				impulseDirection.X,
				impulseDirection.Y,
				impulseDirection.Z
			)
		)
	end

	-- Mark hang time and stop hanging
	LedgeHang.markHangTime(character)
	LedgeHang.stop(character)

	-- Simple physics setup (same as S+Space)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	-- Calculate wall separation force (push away from wall)
	local wallSeparationForce = Vector3.new(0, 0, 0)
	if hangData and hangData.forwardDirection then
		-- For side jumps, disable wall separation since we use backward component instead
		local separationMagnitude = Config.LedgeHangWallSeparationForce or 30
		if direction == "left" or direction == "right" then
			separationMagnitude = 0 -- No wall separation for side jumps (backward component handles separation)
		end
		wallSeparationForce = hangData.forwardDirection * separationMagnitude

		if Config.DebugLedgeHang then
			print(
				string.format(
					"[LedgeHang] Wall separation: Config=%s, final=%.1f",
					tostring(Config.LedgeHangWallSeparationForce),
					separationMagnitude
				)
			)
			print(
				string.format(
					"[LedgeHang] Wall separation force vector: (%.2f,%.2f,%.2f)",
					wallSeparationForce.X,
					wallSeparationForce.Y,
					wallSeparationForce.Z
				)
			)
		end
	end

	-- For side jumps, disable wallslide for 0.25 seconds to allow separation
	if direction == "left" or direction == "right" then
		pcall(function()
			local WallJump = require(game:GetService("ReplicatedStorage").Movement.WallJump)

			-- Stop current wallslide
			if WallJump.isWallSliding and WallJump.isWallSliding(character) then
				WallJump.stopSlide(character)
				if Config.DebugLedgeHang then
					print("[LedgeHang] Stopping wallslide for side jump")
				end
			end

			-- Set wallslide suppression flag for 0.25 seconds
			local rs = game:GetService("ReplicatedStorage")
			local cs = rs:FindFirstChild("ClientState") or Instance.new("Folder")
			if not cs.Parent then
				cs.Name = "ClientState"
				cs.Parent = rs
			end

			local suppressFlag = cs:FindFirstChild("SuppressWallSlide")
			if not suppressFlag then
				suppressFlag = Instance.new("BoolValue")
				suppressFlag.Name = "SuppressWallSlide"
				suppressFlag.Value = false
				suppressFlag.Parent = cs
			end

			suppressFlag.Value = true
			if Config.DebugLedgeHang then
				print("[LedgeHang] Wallslide DISABLED immediately for side jump")
			end

			-- Re-enable wallslide after 0.25 seconds
			task.delay(0.25, function()
				if suppressFlag and suppressFlag.Parent then
					suppressFlag.Value = false
					if Config.DebugLedgeHang then
						print("[LedgeHang] Wallslide RE-ENABLED after 0.25s")
					end
				end
			end)
		end)
	end

	-- Apply impulse with wall separation (simple method like S+Space)
	local baseVelocity = impulseDirection * force
	local finalVelocity = baseVelocity + wallSeparationForce
	root.AssemblyLinearVelocity = finalVelocity

	-- Apply multiple times aggressively to counteract velocity reduction
	task.wait()
	root.AssemblyLinearVelocity = finalVelocity

	-- Apply every 0.05 seconds for the first 0.2 seconds to maintain horizontal momentum
	for i = 1, 4 do
		task.delay(i * 0.05, function()
			if root and root.Parent then
				-- Only reapply if velocity has been significantly reduced
				local currentVel = root.AssemblyLinearVelocity
				if currentVel.Magnitude < finalVelocity.Magnitude * 0.7 then
					if Config.DebugLedgeHang then
						print(
							string.format(
								"[LedgeHang] Reapplying velocity at %.2fs - was %.1f, applying %.1f",
								i * 0.05,
								currentVel.Magnitude,
								finalVelocity.Magnitude
							)
						)
					end
					root.AssemblyLinearVelocity = finalVelocity
				end
			end
		end)
	end

	task.delay(0.1, function()
		if root and root.Parent then
			-- Boost the impulse if velocity was reduced
			local currentVel = root.AssemblyLinearVelocity
			if currentVel.Magnitude < finalVelocity.Magnitude * 0.5 then
				if Config.DebugLedgeHang then
					print(
						string.format(
							"[LedgeHang] Velocity was reduced to %.2f, re-applying boost",
							currentVel.Magnitude
						)
					)
				end
				root.AssemblyLinearVelocity = finalVelocity
			end
		end
	end)

	-- Note: Stamina deduction will be handled by ParkourController

	if Config.DebugLedgeHang then
		print(string.format("[LedgeHang] Directional jump: %s, force: %.1f", direction, force))
		print(
			string.format(
				"[LedgeHang] Final velocity applied: (%.2f,%.2f,%.2f), magnitude: %.2f",
				finalVelocity.X,
				finalVelocity.Y,
				finalVelocity.Z,
				finalVelocity.Magnitude
			)
		)

		-- Monitor velocity after a short delay to see if something is interfering
		task.delay(0.2, function()
			if root and root.Parent then
				local currentVel = root.AssemblyLinearVelocity
				print(
					string.format(
						"[LedgeHang] Velocity after 0.2s: (%.2f,%.2f,%.2f), magnitude: %.2f",
						currentVel.X,
						currentVel.Y,
						currentVel.Z,
						currentVel.Magnitude
					)
				)
			end
		end)
	end

	return true
end

-- Mark hang time in ParkourController state for cooldown
function LedgeHang.markHangTime(character)
	pcall(function()
		local rs = game:GetService("ReplicatedStorage")
		local cs = rs:FindFirstChild("ClientState")
		if cs then
			local lastHangTime = cs:FindFirstChild("LastLedgeHangTime")
			if not lastHangTime then
				lastHangTime = Instance.new("NumberValue")
				lastHangTime.Name = "LastLedgeHangTime"
				lastHangTime.Value = 0
				lastHangTime.Parent = cs
			end
			lastHangTime.Value = os.clock()
		end
	end)
end

return LedgeHang
