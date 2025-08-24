-- Centralized player profile management using a single DataStore schema

local DataStoreService = game:GetService("DataStoreService")

local PROFILE_STORE_NAME = "SkyLeap_Profiles_v1"
local store = DataStoreService:GetDataStore(PROFILE_STORE_NAME)

local PlayerProfile = {}

local ACTIVE = {}

local function defaultProfile()
	return {
		version = 1,
		stats = {
			level = 1,
			xp = 0,
			styleTotal = 0,
			maxCombo = 0,
			timePlayedMinutes = 0,
			coins = 0,
			diamonds = 0,
		},
		progression = {
			unlockedAbilities = {},
		},
		cosmetics = {
			owned = {},
			equipped = {
				outfitId = nil,
				trailId = nil,
			},
		},
		purchases = {
			developerProducts = {},
			gamePasses = {},
		},
		rewards = {
			playtimeClaimed = {}, -- [index]=true for claimed rewards
			lastPlaytimeDay = nil, -- YYYYMMDD string for daily reset
			playtimeAccumulatedSeconds = 0, -- accumulated play seconds for the day
		},
		settings = {
			cameraFov = nil,
			uiScale = nil,
		},
		meta = {
			createdAt = os.time(),
			updatedAt = os.time(),
		},
	}
end

local function migrate(profile)
	if type(profile) ~= "table" then
		return defaultProfile()
	end
	-- Example migration hook; bump as schema evolves
	profile.version = profile.version or 1
	profile.stats = profile.stats or {}
	profile.stats.level = profile.stats.level or 1
	profile.stats.xp = profile.stats.xp or 0
	profile.stats.styleTotal = profile.stats.styleTotal or 0
	profile.stats.maxCombo = profile.stats.maxCombo or 0
	profile.stats.timePlayedMinutes = profile.stats.timePlayedMinutes or 0
	profile.stats.coins = profile.stats.coins or 0
	profile.stats.diamonds = profile.stats.diamonds or 0
	profile.progression = profile.progression or { unlockedAbilities = {} }
	profile.cosmetics = profile.cosmetics or { owned = {}, equipped = { outfitId = nil, trailId = nil } }
	profile.purchases = profile.purchases or { developerProducts = {}, gamePasses = {} }
	profile.settings = profile.settings or { cameraFov = nil, uiScale = nil }
	profile.rewards = profile.rewards or { playtimeClaimed = {}, lastPlaytimeDay = nil, playtimeAccumulatedSeconds = 0 }
	profile.rewards.playtimeClaimed = profile.rewards.playtimeClaimed or {}
	profile.rewards.lastPlaytimeDay = profile.rewards.lastPlaytimeDay or nil
	profile.rewards.playtimeAccumulatedSeconds = tonumber(profile.rewards.playtimeAccumulatedSeconds) or 0
	profile.meta = profile.meta or { createdAt = os.time(), updatedAt = os.time() }
	return profile
end

local function keyFor(userId)
	return "u:" .. tostring(userId)
end

function PlayerProfile.load(userId)
	if ACTIVE[userId] then
		return ACTIVE[userId]
	end
	local loaded
	local ok, err = pcall(function()
		loaded = store:UpdateAsync(keyFor(userId), function(old)
			old = migrate(old or defaultProfile())
			old.meta.updatedAt = os.time()
			return old
		end)
	end)
	if not ok then
		-- Fallback to defaults in-memory; will try save later
		loaded = defaultProfile()
	end
	ACTIVE[userId] = loaded
	return loaded
end

function PlayerProfile.save(userId)
	local data = ACTIVE[userId]
	if not data then
		return
	end
	data.meta.updatedAt = os.time()
	pcall(function()
		store:SetAsync(keyFor(userId), data)
	end)
end

function PlayerProfile.release(userId)
	PlayerProfile.save(userId)
	ACTIVE[userId] = nil
end

function PlayerProfile.addTimePlayed(userId, minutes)
	minutes = tonumber(minutes) or 0
	if minutes <= 0 then
		return 0
	end
	local newTotal = 0
	pcall(function()
		store:UpdateAsync(keyFor(userId), function(old)
			old = migrate(old or defaultProfile())
			old.stats.timePlayedMinutes = (old.stats.timePlayedMinutes or 0) + minutes
			old.meta.updatedAt = os.time()
			newTotal = old.stats.timePlayedMinutes
			return old
		end)
	end)
	local cached = ACTIVE[userId]
	if cached then
		cached.stats.timePlayedMinutes = newTotal
	end
	return newTotal
end

function PlayerProfile.setMaxComboIfHigher(userId, value)
	value = tonumber(value) or 0
	if value <= 0 then
		return 0
	end
	local newMax = 0
	pcall(function()
		store:UpdateAsync(keyFor(userId), function(old)
			old = migrate(old or defaultProfile())
			if value > (old.stats.maxCombo or 0) then
				old.stats.maxCombo = value
				old.meta.updatedAt = os.time()
			end
			newMax = old.stats.maxCombo or 0
			return old
		end)
	end)
	-- Also reflect in cache if present
	local cached = ACTIVE[userId]
	if cached then
		cached.stats.maxCombo = math.max(cached.stats.maxCombo or 0, newMax)
	end
	return newMax
end

function PlayerProfile.addStyleTotal(userId, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then
		return 0
	end
	local newTotal = 0
	pcall(function()
		store:UpdateAsync(keyFor(userId), function(old)
			old = migrate(old or defaultProfile())
			old.stats.styleTotal = (old.stats.styleTotal or 0) + amount
			old.meta.updatedAt = os.time()
			newTotal = old.stats.styleTotal
			return old
		end)
	end)
	local cached = ACTIVE[userId]
	if cached then
		cached.stats.styleTotal = newTotal
	end
	return newTotal
end

-- Currency helpers
function PlayerProfile.getBalances(userId)
	local prof = PlayerProfile.load(userId)
	local coins = tonumber((prof.stats and prof.stats.coins) or 0) or 0
	local diamonds = tonumber((prof.stats and prof.stats.diamonds) or 0) or 0
	return coins, diamonds
end

function PlayerProfile.addCoins(userId, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount == 0 then
		return PlayerProfile.getBalances(userId)
	end
	local newCoins = 0
	pcall(function()
		store:UpdateAsync(keyFor(userId), function(old)
			old = migrate(old or defaultProfile())
			old.stats.coins = math.max(0, math.floor((old.stats.coins or 0) + amount))
			old.meta.updatedAt = os.time()
			newCoins = old.stats.coins
			return old
		end)
	end)
	local cached = ACTIVE[userId]
	if cached then
		cached.stats.coins = newCoins
	end
	local _, diamonds = PlayerProfile.getBalances(userId)
	return newCoins, diamonds
end

function PlayerProfile.addDiamonds(userId, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount == 0 then
		return PlayerProfile.getBalances(userId)
	end
	local newDiamonds = 0
	pcall(function()
		store:UpdateAsync(keyFor(userId), function(old)
			old = migrate(old or defaultProfile())
			old.stats.diamonds = math.max(0, math.floor((old.stats.diamonds or 0) + amount))
			old.meta.updatedAt = os.time()
			newDiamonds = old.stats.diamonds
			return old
		end)
	end)
	local cached = ACTIVE[userId]
	if cached then
		cached.stats.diamonds = newDiamonds
	end
	local coins = select(1, PlayerProfile.getBalances(userId))
	return coins, newDiamonds
end

function PlayerProfile.trySpend(userId, currency, amount)
	currency = tostring(currency)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return false, PlayerProfile.getBalances(userId)
	end
	local success = false
	local balances = { coins = 0, diamonds = 0 }
	pcall(function()
		store:UpdateAsync(keyFor(userId), function(old)
			old = migrate(old or defaultProfile())
			local field = (currency == "Coins") and "coins" or (currency == "Diamonds") and "diamonds" or nil
			if not field then
				return old
			end
			local current = math.floor(old.stats[field] or 0)
			if current >= amount then
				old.stats[field] = current - amount
				old.meta.updatedAt = os.time()
				success = true
				balances.coins = math.floor(old.stats.coins or 0)
				balances.diamonds = math.floor(old.stats.diamonds or 0)
			end
			return old
		end)
	end)
	if success then
		local cached = ACTIVE[userId]
		if cached then
			cached.stats.coins = balances.coins
			cached.stats.diamonds = balances.diamonds
		end
		return true, balances.coins, balances.diamonds
	end
	return false, PlayerProfile.getBalances(userId)
end

-- Rewards helpers
function PlayerProfile.isPlaytimeClaimed(userId, index)
	index = tonumber(index)
	if not index then
		return false
	end
	local prof = PlayerProfile.load(userId)
	local t = (prof.rewards and prof.rewards.playtimeClaimed) or {}
	return t[index] == true
end

function PlayerProfile.markPlaytimeClaimed(userId, index)
	index = tonumber(index)
	if not index then
		return false
	end
	local ok = false
	pcall(function()
		store:UpdateAsync(keyFor(userId), function(old)
			old = migrate(old or defaultProfile())
			old.rewards = old.rewards or { playtimeClaimed = {} }
			old.rewards.playtimeClaimed = old.rewards.playtimeClaimed or {}
			old.rewards.playtimeClaimed[index] = true
			old.meta.updatedAt = os.time()
			ok = true
			return old
		end)
	end)
	local cached = ACTIVE[userId]
	if cached then
		cached.rewards = cached.rewards or { playtimeClaimed = {} }
		cached.rewards.playtimeClaimed[index] = true
	end
	return ok
end

return PlayerProfile
