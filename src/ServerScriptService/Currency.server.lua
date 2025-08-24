-- TEMPORARY: Central currency manager (anti-cheat disabled for debugging)
-- Will re-enable security once basic functionality is working

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerProfile = require(ServerScriptService:WaitForChild("PlayerProfile"))
-- TEMPORARY: AntiCheat disabled for debugging
-- local AntiCheat = require(ServerScriptService:WaitForChild("AntiCheat"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StyleCommit = Remotes:WaitForChild("StyleCommit")
local CurrencyUpdated = Remotes:WaitForChild("CurrencyUpdated")
local RequestBalances = Remotes:WaitForChild("RequestBalances")
local RequestSpend = Remotes:WaitForChild("RequestSpendCurrency")

local CurrencyConfig = require(ReplicatedStorage:WaitForChild("Currency"):WaitForChild("Config"))

-- Security configuration
local MAX_STYLE_PER_COMMIT = 500 -- Maximum style points per single commit
local MIN_COMMIT_INTERVAL = 2 -- Minimum seconds between commits
local MAX_COMMITS_PER_MINUTE = 15 -- Maximum commits per minute per player

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

local function calculateStyleAward(amount)
	local per = tonumber(CurrencyConfig.CoinsPerStylePoint or 0) or 0
	local bonus = 0

	if amount >= (CurrencyConfig.StyleOutstandingThreshold or 1e9) then
		bonus = math.floor((CurrencyConfig.OutstandingBonusCoins or 0) + 0.5)
	elseif amount >= (CurrencyConfig.StyleGreatThreshold or 1e9) then
		bonus = math.floor((CurrencyConfig.GreatBonusCoins or 0) + 0.5)
	elseif amount >= (CurrencyConfig.StyleGoodThreshold or 1e9) then
		bonus = math.floor((CurrencyConfig.GoodBonusCoins or 0) + 0.5)
	end

	local award = math.floor(amount * per + bonus + 0.5)

	if CurrencyConfig.CommitAwardCoinCap then
		award = math.min(award, CurrencyConfig.CommitAwardCoinCap)
	end

	return math.max(0, award)
end

Players.PlayerAdded:Connect(function(player)
	print(string.format("[CURRENCY DEBUG] Player %s joined, loading profile...", player.Name))

	-- Add debug to see what balances are loaded
	local c, g = PlayerProfile.getBalances(player.UserId)
	print(string.format("[CURRENCY DEBUG] Player %s balances - Coins: %d, Diamonds: %d", player.Name, c, g))

	refreshLeaderstats(player)
	print(string.format("[CURRENCY DEBUG] Player %s leaderstats created/updated", player.Name))
end)

-- TEMPORARY: Award coins when style is committed (anti-cheat disabled)
StyleCommit.OnServerEvent:Connect(function(player, amount)
	-- TEMPORARY: Anti-cheat validation disabled for debugging
	-- if not AntiCheat.validateStyleCommit(player, amount) then
	-- 	warn(string.format("[SECURITY] Blocked suspicious StyleCommit from %s: %s", player.Name, tostring(amount)))
	-- 	return
	-- end

	amount = tonumber(amount) or 0
	if amount <= 0 then
		return
	end

	-- Calculate award using secure function
	local award = calculateStyleAward(amount)
	print(string.format("[CURRENCY DEBUG] Player: %s, StyleAmount: %d, Award: %d", player.Name, amount, award))

	if award > 0 then
		local newCoins = select(1, PlayerProfile.addCoins(player.UserId, award))
		refreshLeaderstats(player)
		CurrencyUpdated:FireClient(player, { Coins = newCoins, AwardedCoins = award })

		-- Log for monitoring
		print(string.format("[CURRENCY] %s earned %d coins from %d style points", player.Name, award, amount))
	else
		print(string.format("[CURRENCY DEBUG] No award calculated for %s (amount: %d)", player.Name, amount))
	end
end)

-- Balance request
RequestBalances.OnServerInvoke = function(player)
	print(string.format("[CURRENCY DEBUG] Balance request from %s", player.Name))
	local c, g = PlayerProfile.getBalances(player.UserId)
	print(string.format("[CURRENCY DEBUG] Returning balances to %s - Coins: %d, Diamonds: %d", player.Name, c, g))
	return { Coins = c, Diamonds = g }
end

-- FIXED: Spend request with proper validation
RequestSpend.OnServerInvoke = function(player, payload)
	if type(payload) ~= "table" then
		return { success = false, reason = "InvalidPayload" }
	end

	local currency = tostring(payload.currency)
	local amount = tonumber(payload.amount) or 0

	-- Validation
	if amount <= 0 then
		return { success = false, reason = "InvalidAmount" }
	end

	if currency ~= "Coins" and currency ~= "Diamonds" then
		return { success = false, reason = "InvalidCurrency" }
	end

	-- TEMPORARY: Additional security disabled for debugging
	local MAX_SPEND_PER_REQUEST = 1000000 -- 1M coins/diamonds max per request
	if amount > MAX_SPEND_PER_REQUEST then
		-- AntiCheat.logSuspiciousActivity(player, "InvalidRequests", {
		-- 	type = "ExcessiveSpend",
		-- 	amount = amount,
		-- 	maxAllowed = MAX_SPEND_PER_REQUEST,
		-- })
		warn(string.format("[CURRENCY] Excessive spend attempt from %s: %d", player.Name, amount))
		return { success = false, reason = "ExcessiveAmount" }
	end

	local ok, newCoins, newDiamonds = PlayerProfile.trySpend(player.UserId, currency, amount)
	if not ok then
		return { success = false, reason = "InsufficientFunds" }
	end

	refreshLeaderstats(player)
	CurrencyUpdated:FireClient(player, { Coins = newCoins, Diamonds = newDiamonds })

	-- Log significant spending
	if amount > 10000 then
		print(string.format("[CURRENCY] %s spent %d %s", player.Name, amount, currency))
	end

	return { success = true, Coins = newCoins, Diamonds = newDiamonds }
end
