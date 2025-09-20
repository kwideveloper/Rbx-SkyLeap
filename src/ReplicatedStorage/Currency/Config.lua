-- Shared configuration for currency awards, caps, and formatting

local Config = {}
local SharedUtils = require(script.Parent.Parent.SharedUtils)

-- Award conversion from committed style points (REDUCED TO 1/3)
Config.CoinsPerStylePoint = 0.067

-- Thresholds for bonus coins on commit (REDUCED TO 1/3)
Config.StyleGoodThreshold = 150
Config.GoodBonusCoins = 7

Config.StyleGreatThreshold = 400
Config.GreatBonusCoins = 20

Config.StyleOutstandingThreshold = 1000
Config.OutstandingBonusCoins = 67

-- Safety caps (REDUCED TO 1/3)
-- Config.CommitAwardCoinCap = 5000
Config.CommitAwardCoinCap = 1667

-- Client text formatting (using SharedUtils for consistency)
function Config.formatCoins(amount)
	return SharedUtils.formatNumberWithAbbreviation(amount)
end

function Config.formatDiamonds(amount)
	return SharedUtils.formatNumberWithAbbreviation(amount)
end

return Config
