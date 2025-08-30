-- Zipline module: ride along RopeConstraint between two attachments

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
local CollectionService = game:GetService("CollectionService")
local Animations = require(game:GetService("ReplicatedStorage").Movement.Animations)

local Zipline = {}

-- Track active rides per character
local active = {}

local function getCharacterParts(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function stopZiplineAnimation(character)
	local data = active[character]
	if data and data.animTrack then
		if data.animTrack.IsPlaying then
			data.animTrack:Stop()
		end
		data.animTrack = nil
	end
end

-- Find the closest rope setup near the character. We look for any object tagged with the configured zipline tag
-- that contains a RopeConstraint with two attachments.
local function findNearestRope(rootPart)
	local closest, closestDistSq = nil, math.huge

	-- Find all objects tagged with the configured zipline tag
	local tagName = Config.ZiplineTagName or "Zipline"
	local ziplineObjects = CollectionService:GetTagged(tagName)

	if #ziplineObjects == 0 then
		return nil
	end

	-- Look for ROPECONSTRAINTS within each tagged object
	for _, ziplineObject in ipairs(ziplineObjects) do
		if ziplineObject:IsDescendantOf(workspace) then
			for _, constraint in ipairs(ziplineObject:GetDescendants()) do
				if constraint:IsA("RopeConstraint") then
					constraint.Visible = true
					local a0 = constraint.Attachment0
					local a1 = constraint.Attachment1
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
								rope = constraint,
								model = ziplineObject, -- Store reference to the tagged object to access attributes
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

	-- Start zipline animation using the new global function
	local animator = humanoid:FindFirstChild("Animator")
	if animator then
		local animTrack, errorMsg =
			Animations.playWithDuration(animator, "ZiplineStart", Config.ZiplineStartDurationSeconds or 0.2, {
				debug = true,
				onComplete = function(actualDuration, expectedDuration)
					print(
						"[Zipline] ZiplineStart - Animation completed in",
						actualDuration,
						"seconds (expected:",
						expectedDuration,
						"seconds)"
					)
				end,
			})

		if animTrack then
			-- Store animation track for cleanup
			local token = {}
			active[character] = {
				a0 = info.a0,
				a1 = info.a1,
				t = info.t,
				dirSign = dirSign,
				token = token,
				model = info.model, -- Store reference to the model to access its Speed attribute
				animTrack = animTrack,
			}
		else
			local token = {}
			active[character] = {
				a0 = info.a0,
				a1 = info.a1,
				t = info.t,
				dirSign = dirSign,
				token = token,
				model = info.model, -- Store reference to the model to access its Speed attribute
			}
		end
	else
		local token = {}
		active[character] = {
			a0 = info.a0,
			a1 = info.a1,
			t = info.t,
			dirSign = dirSign,
			token = token,
			model = info.model, -- Store reference to the model to access its Speed attribute
		}
	end
	return true
end

function Zipline.stop(character)
	local data = active[character]
	if not data then
		return
	end

	-- Play zipline end animation before cleanup using the new global function
	if data.animTrack then
		local _, humanoid = getCharacterParts(character)
		if humanoid then
			local animator = humanoid:FindFirstChild("Animator")
			if animator then
				local endTrack, errorMsg =
					Animations.playWithDuration(animator, "ZiplineEnd", Config.ZiplineEndDurationSeconds or 0.2, {
						debug = true,
						onComplete = function(actualDuration, expectedDuration)
							print(
								"[Zipline] ZiplineEnd - Animation completed in",
								actualDuration,
								"seconds (expected:",
								expectedDuration,
								"seconds)"
							)
						end,
					})

				if not endTrack then
					print("[Zipline] ZiplineEnd - ERROR:", errorMsg)
				end
			end
		end

		-- Stop current animation
		if data.animTrack.IsPlaying then
			data.animTrack:Stop()
		end
		data.animTrack = nil
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

	-- Handle zipline animation transitions
	if data.animTrack and data.animTrack.IsPlaying then
		-- Check if ZiplineStart animation has finished (non-looped animation)
		if not data.animTrack.Looped and data.animTrack.TimePosition >= data.animTrack.Length - 0.1 then
			-- ZiplineStart animation finished, start ZiplineLoop
			data.animTrack:Stop()
			data.animTrack = nil

			-- Use the new global animation function for ZiplineLoop
			local loopTrack, errorMsg = Animations.playWithDuration(
				humanoid:FindFirstChild("Animator"),
				"ZiplineLoop",
				1.0, -- No duration control needed for loop
				{
					looped = true,
					debug = false, -- No debug needed for loop
				}
			)

			if loopTrack then
				data.animTrack = loopTrack
			else
				print("[Zipline] ZiplineLoop - ERROR:", errorMsg)
			end
		end
	end

	-- Move parameter t along rope
	-- Get speed from the model first, then from Config, or default value
	local speed = 40 -- Default value

	-- Check if the model has the Speed attribute
	if data.model and data.model:GetAttribute("Speed") ~= nil then
		speed = data.model:GetAttribute("Speed")
	else
		-- If it doesn't have the attribute, use the global configuration
		speed = Config.ZiplineSpeed or speed
	end

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

	-- Adjust vertical position so the head is below the line
	-- Check if the model has a custom HeadOffset attribute
	local headOffset = 5 -- Default value

	if data.model and data.model:GetAttribute("HeadOffset") ~= nil then
		headOffset = data.model:GetAttribute("HeadOffset")
	else
		-- If it doesn't have the attribute, use the global configuration
		headOffset = Config.ZiplineHeadOffset or headOffset
	end

	local adjustedPos = pos - Vector3.new(0, headOffset, 0)

	-- Stick slightly to the rope and apply forward velocity
	local horizontal = forward * speed + Vector3.new(0, -0.5, 0)
	root.CFrame = CFrame.lookAt(adjustedPos, adjustedPos + forward, Vector3.yAxis)
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

-- Clean up all active zipline animations (useful for cleanup)
function Zipline.cleanupAll()
	for character, _ in pairs(active) do
		stopZiplineAnimation(character)
	end
	active = {}
end

return Zipline
