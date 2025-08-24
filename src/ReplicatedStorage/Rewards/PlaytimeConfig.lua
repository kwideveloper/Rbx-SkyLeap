-- Playtime rewards configuration
-- Each entry: { seconds = 600, type = "Coins"|"Diamonds", amount = 3000, image = "rbxassetid://..." }

local Config = {}

-- Reasonable early-game economy based on style-to-coin conversion and session pacing
-- Goal: first 30–60 minutes produce several small dopamine hits, then scale upwards
Config.Rewards = {
	{ seconds = 60 * 5, type = "Coins", amount = 1000, image = "rbxassetid://127484940327901" },
	{ seconds = 60 * 10, type = "Coins", amount = 3000, image = "rbxassetid://127484940327901" },
	{ seconds = 60 * 15, type = "Diamonds", amount = 50, image = "rbxassetid://134526683895571" },
	{ seconds = 60 * 25, type = "Coins", amount = 5000, image = "rbxassetid://127484940327901" },
	{ seconds = 60 * 35, type = "Coins", amount = 8000, image = "rbxassetid://127484940327901" },
	{ seconds = 60 * 45, type = "Diamonds", amount = 120, image = "rbxassetid://134526683895571" },
	{ seconds = 60 * 60, type = "Coins", amount = 15000, image = "rbxassetid://127484940327901" },
	{ seconds = 60 * 75, type = "Coins", amount = 20000, image = "rbxassetid://127484940327901" },
	{ seconds = 60 * 90, type = "Diamonds", amount = 300, image = "rbxassetid://134526683895571" },
	{ seconds = 60 * 120, type = "Coins", amount = 30000, image = "rbxassetid://127484940327901" },
}

function Config.formatReward(entry)
	local qty = tonumber(entry.amount) or 0
	local t = tostring(entry.type or "Coins")
	local comma = tostring(qty):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return string.format("%s %s", comma, t)
end

return Config
