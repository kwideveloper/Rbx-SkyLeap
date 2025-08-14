-- Style / Combo tracking utilities

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Movement.Config)

local Style = {}

function Style.create()
	local state = {
		score = 0,
		combo = 0,
		multiplier = 1.0,
		flowTime = 0,
		lastActiveTick = os.clock(),
	}
	return state
end

local function addScore(state, amount)
	if amount <= 0 then
		return
	end
	local mul = state.multiplier or 1
	state.score = state.score + (amount * mul)
end

local function bumpCombo(state, inc)
	state.combo = (state.combo or 0) + (inc or 1)
	local step = Config.StyleMultiplierStep or 0.25
	local maxMul = Config.StyleMultiplierMax or 4.0
	state.multiplier = math.min(maxMul, (state.multiplier or 1) + step)
end

local function breakCombo(state)
	state.combo = 0
	state.multiplier = 1.0
	state.flowTime = 0
end

-- Tick updates per frame based on movement context
-- ctx = { dt, speed, airborne, wallRun, sliding, climbing }
function Style.tick(state, ctx)
	if not (Config.StyleEnabled ~= false) then
		return state
	end
	local dt = ctx.dt or 0
	local speed = ctx.speed or 0
	local active = false

	local speedThresh = Config.StyleSpeedThreshold or 18
	if speed >= speedThresh then
		active = true
		local basePerSec = Config.StylePerSecondBase or 5
		local speedFactor = Config.StyleSpeedFactor or 0.1
		addScore(state, (basePerSec + (speed * speedFactor)) * dt)
	end

	if ctx.wallRun then
		active = true
		local perSec = Config.StyleWallRunPerSecond or 10
		addScore(state, perSec * dt)
	end
	if ctx.airborne then
		active = true
		local perSec = Config.StyleAirTimePerSecond or 6
		addScore(state, perSec * dt)
	end

	if active then
		state.flowTime = (state.flowTime or 0) + dt
		state.lastActiveTick = os.clock()
	else
		-- Break if inactive beyond timeout
		local timeout = Config.StyleBreakTimeoutSeconds or 0.65
		if (os.clock() - (state.lastActiveTick or 0)) > timeout then
			breakCombo(state)
		end
	end

	return state
end

function Style.addEvent(state, event, magnitude)
	if not (Config.StyleEnabled ~= false) then
		return state
	end
	local bonus = 0
	if event == "BunnyHop" then
		local base = Config.StyleBunnyHopBonusBase or 50
		local per = Config.StyleBunnyHopBonusPerStack or 25
		bonus = base + per * math.max(0, (magnitude or 1) - 1)
	elseif event == "Dash" then
		bonus = Config.StyleDashBonus or 20
	elseif event == "WallJump" then
		bonus = Config.StyleWallJumpBonus or 30
	end
	if bonus > 0 then
		addScore(state, bonus)
		bumpCombo(state, 1)
	end
	return state
end

return Style
