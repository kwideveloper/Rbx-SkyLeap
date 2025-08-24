-- Shared configuration for currency awards, caps, and formatting

local Config = {}

-- Award conversion from committed style points
Config.CoinsPerStylePoint = 0.2

-- Thresholds for bonus coins on commit
Config.StyleGoodThreshold = 150
Config.GoodBonusCoins = 20

Config.StyleGreatThreshold = 400
Config.GreatBonusCoins = 60

Config.StyleOutstandingThreshold = 1000
Config.OutstandingBonusCoins = 200

-- Safety caps
Config.CommitAwardCoinCap = 5000

-- Client text formatting
function Config.formatCoins(amount)
	amount = tonumber(amount) or 0
	return tostring(amount)
end

function Config.formatDiamonds(amount)
	amount = tonumber(amount) or 0
	return tostring(amount)
end

return Config
