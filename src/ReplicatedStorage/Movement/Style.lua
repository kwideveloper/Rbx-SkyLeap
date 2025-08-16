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
		lastEventTick = 0,
		actionRing = {}, -- recent actions for variety window
		repeatCount = 0,
		lastAction = nil,
		lastEventTimeByName = {},
		lastWallJumpTick = 0,
		wallJumpStreak = 0,
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
	state.actionRing = {}
	state.repeatCount = 0
	state.lastAction = nil
end

-- Tick updates per frame based on movement context
-- ctx = { dt, speed, airborne, wallRun, sliding, climbing }
function Style.tick(state, ctx)
	if not (Config.StyleEnabled ~= false) then
		return state
	end
	local dt = ctx.dt or 0
	local speed = ctx.speed or 0
	local scoreOnlyActive = false
	local comboActive = false

	local speedThresh = Config.StyleSpeedThreshold or 18
	if speed >= speedThresh then
		-- Running should not maintain the combo; only add score when combo is active
		scoreOnlyActive = true
		if (state.combo or 0) >= 1 then
			local basePerSec = Config.StylePerSecondBase or 5
			local speedFactor = Config.StyleSpeedFactor or 0.1
			addScore(state, (basePerSec + (speed * speedFactor)) * dt)
		end
	end

	if ctx.wallRun then
		comboActive = true
		local perSec = Config.StyleWallRunPerSecond or 10
		if (state.combo or 0) >= 1 then
			addScore(state, perSec * dt)
		end
	end
	if ctx.airborne then
		comboActive = true
		local perSec = Config.StyleAirTimePerSecond or 6
		if (state.combo or 0) >= 1 then
			addScore(state, perSec * dt)
		end
	end

	if comboActive then
		state.flowTime = (state.flowTime or 0) + dt
		state.lastActiveTick = os.clock()
	else
		-- Break if inactive beyond timeout
		local timeout = Config.StyleBreakTimeoutSeconds or 3
		if (os.clock() - (state.lastActiveTick or 0)) > timeout then
			breakCombo(state)
		end
	end

	return state
end

local function pushAction(state, name)
	local window = Config.StyleVarietyWindow or 6
	local ring = state.actionRing or {}
	table.insert(ring, name)
	while #ring > window do
		table.remove(ring, 1)
	end
	state.actionRing = ring
	if state.lastAction == name then
		state.repeatCount = (state.repeatCount or 0) + 1
	else
		state.repeatCount = 1
		state.lastAction = name
	end
end

local function isChained(state)
	local window = Config.ComboChainWindowSeconds or 3
	return (os.clock() - (state.lastEventTick or 0)) <= window
end

local function grantVarietyBonusIfAny(state)
	local ring = state.actionRing or {}
	local set = {}
	for _, a in ipairs(ring) do
		set[a] = true
	end
	local distinct = 0
	for _ in pairs(set) do
		distinct = distinct + 1
	end
	if distinct >= (Config.StyleVarietyDistinctThreshold or 4) then
		addScore(state, Config.StyleCreativityBonus or 20)
		-- clear ring to avoid spamming bonus each event; keep last action info
		state.actionRing = {}
	end
end

function Style.addEvent(state, event, magnitude)
	if not (Config.StyleEnabled ~= false) then
		return state
	end
	-- Dedupe: ignore duplicate event calls in the same small frame window
	local lastByName = state.lastEventTimeByName or {}
	local now = os.clock()
	local lastT = lastByName[event]
	if lastT and (now - lastT) < 0.1 then
		return state
	end
	lastByName[event] = now
	state.lastEventTimeByName = lastByName
	local bonus = 0
	if event == "BunnyHop" then
		local base = Config.StyleBunnyHopBonusBase or 50
		local per = Config.StyleBunnyHopBonusPerStack or 25
		bonus = base + per * math.max(0, (magnitude or 1) - 1)
		pushAction(state, "BunnyHop")
	elseif event == "Dash" then
		-- Only count dash if chained from previous action within window
		if isChained(state) then
			bonus = Config.StyleDashBonus or 8
			pushAction(state, "Dash")
		end
	elseif event == "WallJump" then
		bonus = Config.StyleWallJumpBonus or 15
		-- Add streak scaling for rapid consecutive walljumps
		local chainWin = Config.StyleWallJumpChainWindowSeconds or 0.6
		if (now - (state.lastWallJumpTick or 0)) <= chainWin then
			state.wallJumpStreak = math.min((state.wallJumpStreak or 0) + 1, 100)
		else
			state.wallJumpStreak = 1
		end
		local extra = (Config.StyleWallJumpStreakBonusPer or 4) * math.max(0, (state.wallJumpStreak or 1) - 1)
		local cap = Config.StyleWallJumpStreakMaxBonus or 20
		bonus = bonus + math.min(cap, extra)
		state.lastWallJumpTick = now
		pushAction(state, "WallJump")
	elseif event == "WallRun" then
		bonus = Config.StyleWallRunEventBonus or 10
		pushAction(state, "WallRun")
	elseif event == "WallSlide" then
		-- Only counts when chained
		if isChained(state) then
			bonus = Config.StyleWallSlideBonus or 10
			pushAction(state, "WallSlide")
		end
	elseif event == "Pad" then
		-- Only counts when chained with a subsequent action within the chain window.
		-- The client sets lastEventTick on pad trigger, and the next qualifying action will allow this to contribute.
		if isChained(state) then
			bonus = Config.StylePadChainBonus or 5
			pushAction(state, "Pad")
		end
	elseif event == "Vault" then
		bonus = Config.StyleVaultBonus or 12
		pushAction(state, "Vault")
	elseif event == "Mantle" then
		-- Treat mantle similar to vault for scoring
		bonus = Config.StyleVaultBonus or 12
		pushAction(state, "Mantle")
	elseif event == "GroundSlide" then
		bonus = Config.StyleGroundSlideBonus or 8
		pushAction(state, "GroundSlide")
	elseif event == "ZiplineExit" then
		-- Only counts when chained into a follow-up (e.g., wallrun, walljump, pad)
		if isChained(state) then
			pushAction(state, "Zipline")
		end
	end
	-- Anti-repeat: do not grow combo if same action repeated too many times in a row
	local repeatLimit = Config.StyleRepeatLimit or 3
	if state.repeatCount and state.repeatCount > repeatLimit then
		bonus = 0
	end
	if bonus > 0 then
		addScore(state, bonus)
		bumpCombo(state, 1)
		grantVarietyBonusIfAny(state)
		state.lastEventTick = os.clock()
		state.lastActiveTick = os.clock()
	end
	return state
end

return Style
