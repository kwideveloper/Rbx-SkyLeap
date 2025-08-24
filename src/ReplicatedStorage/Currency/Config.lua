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
local function formatNumberWithAbbreviation(amount)
	amount = tonumber(amount) or 0

	if amount >= 1000000000 then
		local truncated = math.floor(amount / 1000000000 * 10) / 10
		return string.format("%.1fB", truncated):gsub("%.0", "")
	elseif amount >= 1000000 then
		local truncated = math.floor(amount / 1000000 * 10) / 10
		return string.format("%.1fM", truncated):gsub("%.0", "")
	elseif amount >= 1000 then
		local truncated = math.floor(amount / 1000 * 10) / 10
		return string.format("%.1fK", truncated):gsub("%.0", "")
	else
		return tostring(amount)
	end
end

function Config.formatCoins(amount)
	return formatNumberWithAbbreviation(amount)
end

function Config.formatDiamonds(amount)
	return formatNumberWithAbbreviation(amount)
end

return Config
