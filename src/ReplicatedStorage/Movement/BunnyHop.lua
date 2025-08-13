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
		return false
	end
	-- Only consider when actually grounded
	if humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end

	local now = os.clock()
	local withinWindow = state.landWindowActive
		and ((now - (state.lastLandTick or 0)) <= (Config.BunnyHopWindowSeconds or 0.12))
	if not withinWindow then
		-- Not a perfect hop: chain breaks
		state.stacks = 0
		return false
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
		return false
	end

	local travelDir = (horizMag > 0.05) and horiz.Unit or moveDir
	local carry = math.clamp((Config.BunnyHopDirectionCarry or 0.75), 0, 1)
	local blended = (travelDir * carry) + (moveDir * (1 - carry))
	if blended.Magnitude > 0 then
		blended = blended.Unit
	else
		blended = travelDir
	end

	-- Additive impulse along blended direction; preserve perpendicular momentum
	local bonus = (Config.BunnyHopBaseBoost or 6) + (Config.BunnyHopPerStackBoost or 3) * (state.stacks - 1)
	local delta = blended * bonus
	local newHoriz = horiz + delta
	root.AssemblyLinearVelocity = Vector3.new(newHoriz.X, vel.Y, newHoriz.Z)

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

	return true
end

return BunnyHop
