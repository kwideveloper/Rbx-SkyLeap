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

return Momentum
