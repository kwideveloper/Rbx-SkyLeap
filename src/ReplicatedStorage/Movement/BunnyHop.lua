-- Bunny hop mechanic: perfect jump right after landing grants speed and momentum boost

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Movement.Config)
local Momentum = require(ReplicatedStorage.Movement.Momentum)

local BunnyHop = {}

local perCharacter = {}

local function getParts(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function ensureState(character)
	perCharacter[character] = perCharacter[character]
		or { stacks = 0, lastLandTick = 0, conn = nil, landWindowActive = false }
	return perCharacter[character]
end

function BunnyHop.setup(character)
	local state = ensureState(character)
	local _root, humanoid = getParts(character)
	if not humanoid then
		return
	end
	if state.conn then
		state.conn:Disconnect()
		state.conn = nil
	end
	state.stacks = 0
	state.lastLandTick = 0
	state.conn = humanoid.StateChanged:Connect(function(old, new)
		if
			new == Enum.HumanoidStateType.Landed
			or (new == Enum.HumanoidStateType.Running and old == Enum.HumanoidStateType.Freefall)
		then
			state.lastLandTick = os.clock()
			state.landWindowActive = true
			-- Auto-break the chain if the player does not jump within the window
			local thisLand = state.lastLandTick
			task.delay((Config.BunnyHopWindowSeconds or 0.12) + 0.02, function()
				if state and perCharacter[character] and state.lastLandTick == thisLand and state.landWindowActive then
					state.stacks = 0
					state.landWindowActive = false
				end
			end)
		end
	end)
end

function BunnyHop.teardown(character)
	local state = perCharacter[character]
	if not state then
		return
	end
	if state.conn then
		state.conn:Disconnect()
		state.conn = nil
	end
	perCharacter[character] = nil
end

function BunnyHop.resetStacks(character)
	local state = ensureState(character)
	state.stacks = 0
end

-- Call on Space pressed while grounded; applies boost if within timing window
function BunnyHop.tryApplyOnJump(character, momentumState)
	local state = ensureState(character)
	local root, humanoid = getParts(character)
	if not root or not humanoid then
		return 0
	end
	-- Only consider when actually grounded
	if humanoid.FloorMaterial == Enum.Material.Air then
		return 0
	end

	local now = os.clock()
	local withinWindow = state.landWindowActive
		and ((now - (state.lastLandTick or 0)) <= (Config.BunnyHopWindowSeconds or 0.12))
	if not withinWindow then
		-- Not a perfect hop: chain breaks
		state.stacks = 0
		return 0
	end

	-- Compute next stack
	local maxStacks = Config.BunnyHopMaxStacks or 3
	state.stacks = math.clamp((state.stacks or 0) + 1, 1, maxStacks)

	-- Determine horizontal preference directions
	local moveDir = (humanoid.MoveDirection.Magnitude > 0.05) and humanoid.MoveDirection or root.CFrame.LookVector
	moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
	else
		-- No intent; fall back to current travel
		moveDir = Vector3.new(0, 0, 0)
	end

	local vel = root.AssemblyLinearVelocity
	local horiz = Vector3.new(vel.X, 0, vel.Z)
	local horizMag = horiz.Magnitude
	if horizMag < 0.05 and moveDir.Magnitude == 0 then
		-- No movement and no intent: skip
		return 0
	end

	local travelDir = (horizMag > 0.05) and horiz.Unit or moveDir
	local carry = math.clamp((Config.BunnyHopDirectionCarry or 0.75), 0, 1)
	local blended = (travelDir * carry) + (moveDir * (1 - carry))
	if blended.Magnitude > 0 then
		blended = blended.Unit
	else
		blended = moveDir.Magnitude > 0 and moveDir or travelDir
	end

	local newHoriz
	if Config.BunnyHopReorientHard then
		-- Hard reorientation: keep magnitude, replace direction with intent (or blended if no input)
		local baseDir = (moveDir.Magnitude > 0.01) and moveDir or blended
		if baseDir.Magnitude > 0 then
			newHoriz = baseDir.Unit * horizMag
		else
			newHoriz = horiz
		end
	else
		-- Soft redirection (previous logic)
		if moveDir.Magnitude > 0.01 and horizMag > 0.01 then
			local intentDot = moveDir:Dot(horiz.Unit)
			if intentDot < -0.2 then
				local perp = horiz - (horiz.Unit:Dot(moveDir) * moveDir * horizMag)
				local perpDamp = math.clamp(Config.BunnyHopPerpDampOnFlip or 0.4, 0, 1)
				local desiredMag = horizMag
				newHoriz = moveDir * desiredMag + perp * (1 - perpDamp)
			else
				local oppositeCancel = math.clamp(Config.BunnyHopOppositeCancel or 0.6, 0, 1)
				local backDot = (-moveDir):Dot(horiz.Unit)
				if backDot > 0 then
					local cancelMag = backDot * horizMag * oppositeCancel
					horiz = horiz + (moveDir * cancelMag)
				end
				newHoriz = horiz
			end
		else
			newHoriz = horiz
		end
	end

	-- Additive impulse along blended direction
	local bonus = (Config.BunnyHopBaseBoost or 6) + (Config.BunnyHopPerStackBoost or 3) * (state.stacks - 1)
	local maxAdd = math.max(0, Config.BunnyHopMaxAddPerHop or bonus)
	local delta = blended * math.min(bonus, maxAdd)
	newHoriz = newHoriz + delta
	-- Clamp total horizontal speed
	local cap = (Config.BunnyHopTotalSpeedCap or Config.AirControlTotalSpeedCap or 999)
	local nhMag = Vector3.new(newHoriz.X, 0, newHoriz.Z).Magnitude
	if nhMag > cap then
		newHoriz = newHoriz.Unit * cap
	end
	root.AssemblyLinearVelocity = Vector3.new(newHoriz.X, vel.Y, newHoriz.Z)

	-- Briefly lock horizontal to eliminate drift/drag before physics applies, for an instant redirection feel
	local lockDur = math.max(0, Config.BunnyHopLockSeconds or 0)
	if lockDur > 0 then
		local startT = os.clock()
		task.spawn(function()
			while (os.clock() - startT) < lockDur do
				local curV = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(newHoriz.X, curV.Y, newHoriz.Z)
				task.wait()
			end
		end)
	end

	-- Momentum bonus
	if momentumState and Momentum.addBonus then
		local mBonus = (Config.BunnyHopMomentumBonusBase or 4)
			+ (Config.BunnyHopMomentumBonusPerStack or 2) * (state.stacks - 1)
		Momentum.addBonus(momentumState, mBonus)
	end

	-- Consume this landing window
	state.landWindowActive = false

	-- Publish HUD signals if present
	local rs = game:GetService("ReplicatedStorage")
	local folder = rs:FindFirstChild("ClientState")
	if folder then
		local stacksVal = folder:FindFirstChild("BunnyHopStacks")
		local flashVal = folder:FindFirstChild("BunnyHopFlash")
		local styleScore = folder:FindFirstChild("StyleScore")
		local styleCombo = folder:FindFirstChild("StyleCombo")
		if stacksVal then
			stacksVal.Value = state.stacks
		end
		if flashVal then
			flashVal.Value = true
			task.delay(0.05, function()
				if flashVal and flashVal.Parent then
					flashVal.Value = false
				end
			end)
		end
	end

	return state.stacks or 1
end

return BunnyHop
