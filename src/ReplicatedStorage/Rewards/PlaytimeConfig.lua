-- Playtime rewards configuration
-- Each entry: { seconds = 600, type = "Coins"|"Diamonds", amount = 3000, image = "rbxassetid://..." }

local Config = {}

-- Reasonable early-game economy based on style-to-coin conversion and session pacing
-- Goal: first 30–60 minutes produce several small dopamine hits, then scale upwards
-- Balanced reward curve with progressive scaling and better value distribution
-- Goal: Smooth progression with meaningful rewards that encourage continued play
Config.Rewards = {
	-- Early game: Quick wins to hook players (5-15 min)
	{ seconds = 60 * 5, type = "Coins", amount = 500, image = "rbxassetid://127484940327901" }, -- 100 coins/min
	{ seconds = 60 * 10, type = "Coins", amount = 1250, image = "rbxassetid://127484940327901" }, -- 125 coins/min
	{ seconds = 60 * 15, type = "Diamonds", amount = 25, image = "rbxassetid://134526683895571" }, -- ~1.67 diamonds/min

	-- Mid game: Building momentum (25-45 min)
	{ seconds = 60 * 25, type = "Coins", amount = 1800, image = "rbxassetid://127484940327901" }, -- 72 coins/min
	{ seconds = 60 * 35, type = "Coins", amount = 2500, image = "rbxassetid://127484940327901" }, -- ~71.4 coins/min
	{ seconds = 60 * 45, type = "Diamonds", amount = 50, image = "rbxassetid://134526683895571" }, -- ~1.11 diamonds/min

	-- Late game: Premium rewards for dedicated players (60-120 min)
	{ seconds = 60 * 60, type = "Coins", amount = 4000, image = "rbxassetid://127484940327901" }, -- ~66.7 coins/min
	{ seconds = 60 * 75, type = "Coins", amount = 5500, image = "rbxassetid://127484940327901" }, -- ~73.3 coins/min
	{ seconds = 60 * 90, type = "Diamonds", amount = 100, image = "rbxassetid://134526683895571" }, -- ~1.11 diamonds/min
	{ seconds = 60 * 120, type = "Coins", amount = 8000, image = "rbxassetid://127484940327901" }, -- ~66.7 coins/min
}

function Config.formatReward(entry)
	local qty = tonumber(entry.amount) or 0
	local t = tostring(entry.type or "Coins")
	local comma = tostring(qty):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return string.format("%s %s", comma, t)
end

return Config
