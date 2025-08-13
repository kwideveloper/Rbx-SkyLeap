-- Momentum tracking utilities

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)

local Momentum = {}

function Momentum.create()
	local state = {
		value = 0,
	}

	return state
end

function Momentum.addFromSpeed(momentumState, speed)
	local delta = speed * Config.MomentumIncreaseFactor
	momentumState.value = momentumState.value + delta
	if momentumState.value > Config.MomentumMax then
		momentumState.value = Config.MomentumMax
	end
	return momentumState.value
end

function Momentum.decay(momentumState, dt)
	momentumState.value = momentumState.value - (Config.MomentumDecayPerSecond * dt)
	if momentumState.value < 0 then
		momentumState.value = 0
	end
	return momentumState.value
end

-- Apply a direct momentum bonus (e.g., from bunny hops)
function Momentum.addBonus(momentumState, amount)
	if not amount or amount == 0 then
		return momentumState.value
	end
	momentumState.value = momentumState.value + amount
	if momentumState.value > Config.MomentumMax then
		momentumState.value = Config.MomentumMax
	elseif momentumState.value < 0 then
		momentumState.value = 0
	end
	return momentumState.value
end

return Momentum
