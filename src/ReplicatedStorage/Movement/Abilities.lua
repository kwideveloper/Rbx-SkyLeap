-- Dash and slide abilities

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)

local Abilities = {}

local lastDashTick = 0

local function getCharacterParts(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

function Abilities.isDashReady()
	local now = os.clock()
	return (now - lastDashTick) >= Config.DashCooldownSeconds
end

function Abilities.tryDash(character)
	local now = os.clock()
	if now - lastDashTick < Config.DashCooldownSeconds then
		return false
	end

	local rootPart, humanoid = getCharacterParts(character)
	if not rootPart or not humanoid then
		return false
	end

	lastDashTick = now
	local forward = rootPart.CFrame.LookVector
	rootPart.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity + (forward * Config.DashImpulse)
	return true
end

function Abilities.slide(character)
	local rootPart, humanoid = getCharacterParts(character)
	if not rootPart or not humanoid then
		return function() end
	end

	local originalWalkSpeed = humanoid.WalkSpeed
	local originalHipHeight = humanoid.HipHeight

	humanoid.WalkSpeed = originalWalkSpeed + Config.SlideSpeedBoost
	humanoid.HipHeight = math.max(0, originalHipHeight + Config.SlideHipHeightDelta)

	local endSlide = function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalWalkSpeed
			humanoid.HipHeight = originalHipHeight
		end
	end

	task.delay(Config.SlideDurationSeconds, endSlide)
	return endSlide
end

return Abilities
