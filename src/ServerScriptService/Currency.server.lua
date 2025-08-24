-- Central currency manager: balances, awards, spending, leaderstats sync

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerProfile = require(ServerScriptService:WaitForChild("PlayerProfile"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StyleCommit = Remotes:WaitForChild("StyleCommit")
local CurrencyUpdated = Remotes:WaitForChild("CurrencyUpdated")
local RequestBalances = Remotes:WaitForChild("RequestBalances")
local RequestSpend = Remotes:WaitForChild("RequestSpendCurrency")

local CurrencyConfig = require(ReplicatedStorage:WaitForChild("Currency"):WaitForChild("Config"))

local function ensureLeaderstats(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local coins = stats:FindFirstChild("Coins")
	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = 0
		coins.Parent = stats
	end
	local diamonds = stats:FindFirstChild("Diamonds")
	if not diamonds then
		diamonds = Instance.new("IntValue")
		diamonds.Name = "Diamonds"
		diamonds.Value = 0
		diamonds.Parent = stats
	end
	return stats
end

local function refreshLeaderstats(player)
	local stats = ensureLeaderstats(player)
	local c, g = PlayerProfile.getBalances(player.UserId)
	local ci = stats:FindFirstChild("Coins")
	local gi = stats:FindFirstChild("Diamonds")
	if ci then
		ci.Value = tonumber(c) or 0
	end
	if gi then
		gi.Value = tonumber(g) or 0
	end
end

Players.PlayerAdded:Connect(function(player)
	refreshLeaderstats(player)
end)

-- Award coins when style is committed
StyleCommit.OnServerEvent:Connect(function(player, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then
		return
	end
	local award = 0
	do
		local per = tonumber(CurrencyConfig.CoinsPerStylePoint or 0) or 0
		local bonus = 0
		if amount >= (CurrencyConfig.StyleOutstandingThreshold or 1e9) then
			bonus = math.floor((CurrencyConfig.OutstandingBonusCoins or 0) + 0.5)
		elseif amount >= (CurrencyConfig.StyleGreatThreshold or 1e9) then
			bonus = math.floor((CurrencyConfig.GreatBonusCoins or 0) + 0.5)
		elseif amount >= (CurrencyConfig.StyleGoodThreshold or 1e9) then
			bonus = math.floor((CurrencyConfig.GoodBonusCoins or 0) + 0.5)
		end
		award = math.floor(amount * per + bonus + 0.5)
		if CurrencyConfig.CommitAwardCoinCap then
			award = math.min(award, CurrencyConfig.CommitAwardCoinCap)
		end
		award = math.max(0, award)
	end
	if award > 0 then
		local newCoins = select(1, PlayerProfile.addCoins(player.UserId, award))
		refreshLeaderstats(player)
		CurrencyUpdated:FireClient(player, { Coins = newCoins, AwardedCoins = award })
	end
end)

-- Balance request
RequestBalances.OnServerInvoke = function(player)
	local c, g = PlayerProfile.getBalances(player.UserId)
	return { Coins = c, Diamonds = g }
end

-- Spend request
RequestSpend.OnServerInvoke = function(player, payload)
	if type(payload) ~= "table" then
		return { success = false, reason = "InvalidPayload" }
	end
	local currency = tostring(payload.currency)
	local amount = tonumber(payload.amount) or 0
	if amount <= 0 then
		return { success = false, reason = "InvalidAmount" }
	end
	if currency ~= "Coins" and currency ~= "Diamonds" then
		return { success = false, reason = "InvalidCurrency" }
	end
	local ok, newCoins, newDiamonds = PlayerProfile.trySpend(player.UserId, currency, amount)
	if not ok then
		return { success = false, reason = "InsufficientFunds" }
	end
	refreshLeaderstats(player)
	CurrencyUpdated:FireClient(player, { Coins = newCoins, Diamonds = newDiamonds })
	return { success = true, Coins = newCoins, Diamonds = newDiamonds }
end
