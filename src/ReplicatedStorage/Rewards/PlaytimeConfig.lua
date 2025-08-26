-- Playtime rewards configuration
-- Each entry: { seconds = 600, type = "Coins"|"Diamonds", amount = 3000, image = "rbxassetid://..." }

local Config = {}

-- Reasonable early-game economy based on style-to-coin conversion and session pacing
-- Goal: first 30–60 minutes produce several small dopamine hits, then scale upwards
-- Balanced reward curve with progressive scaling and better value distribution
-- Goal: Smooth progression with meaningful rewards that encourage continued play
Config.Rewards = {
	-- Early game: Quick wins to hook players (5-15 min)
	{ seconds = 60 * 5, type = "Coins", amount = 1000, image = "rbxassetid://127484940327901" }, -- 200 coins/min
	{ seconds = 60 * 10, type = "Coins", amount = 2500, image = "rbxassetid://127484940327901" }, -- 250 coins/min
	{ seconds = 60 * 15, type = "Diamonds", amount = 50, image = "rbxassetid://134526683895571" }, -- ~3.33 diamonds/min

	-- Mid game: Building momentum (25-45 min)
	{ seconds = 60 * 25, type = "Coins", amount = 6500, image = "rbxassetid://127484940327901" }, -- 260 coins/min
	{ seconds = 60 * 35, type = "Coins", amount = 9500, image = "rbxassetid://127484940327901" }, -- 271 coins/min
	{ seconds = 60 * 45, type = "Diamonds", amount = 120, image = "rbxassetid://134526683895571" }, -- ~2.67 diamonds/min

	-- Late game: Premium rewards for dedicated players (60-120 min)
	{ seconds = 60 * 60, type = "Coins", amount = 12500, image = "rbxassetid://127484940327901" }, -- 208 coins/min
	{ seconds = 60 * 75, type = "Coins", amount = 16000, image = "rbxassetid://127484940327901" }, -- 213 coins/min
	{ seconds = 60 * 90, type = "Diamonds", amount = 250, image = "rbxassetid://134526683895571" }, -- ~2.78 diamonds/min
	{ seconds = 60 * 120, type = "Coins", amount = 22000, image = "rbxassetid://127484940327901" }, -- 183 coins/min
}

function Config.formatReward(entry)
	local qty = tonumber(entry.amount) or 0
	local t = tostring(entry.type or "Coins")
	local comma = tostring(qty):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return string.format("%s %s", comma, t)
end

return Config
