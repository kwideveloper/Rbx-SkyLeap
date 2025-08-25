local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerProfile = require(ServerScriptService:WaitForChild("PlayerProfile"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RF_Request = Remotes:WaitForChild("PlaytimeRequest")
local RF_Claim = Remotes:WaitForChild("PlaytimeClaim")

local CurrencyUpdated = Remotes:WaitForChild("CurrencyUpdated")

local RewardsConfig = require(ReplicatedStorage:WaitForChild("Rewards"):WaitForChild("PlaytimeConfig"))

local SESSIONS = {}

local function getElapsedFor(userId)
	local p = PlayerProfile.load(userId)
	local today = os.date("!*t")
	local dayKey = string.format("%04d%02d%02d", today.year, today.month, today.day)
	p.rewards = p.rewards or { playtimeClaimed = {}, lastPlaytimeDay = nil, playtimeAccumulatedSeconds = 0 }
	if p.rewards.lastPlaytimeDay ~= dayKey then
		p.rewards.playtimeClaimed = {}
		p.rewards.lastPlaytimeDay = dayKey
		p.rewards.playtimeAccumulatedSeconds = 0
		PlayerProfile.save(userId)
	end
	local acc = tonumber(p.rewards.playtimeAccumulatedSeconds) or 0
	local playing = 0
	for plr, s in pairs(SESSIONS) do
		if plr.UserId == userId and s.start then
			playing = math.max(0, os.time() - s.start)
			break
		end
	end
	return acc + playing
end

local function serializeFor(player)
	local userId = player.UserId
	local elapsed = getElapsedFor(userId)
	local claimed = {}
	local prof = PlayerProfile.load(userId)
	if prof.rewards and prof.rewards.playtimeClaimed then
		for k, v in pairs(prof.rewards.playtimeClaimed) do
			if v == true then
				claimed[tonumber(k)] = true
			end
		end
	end
	-- Determine the next unclaimed index (smallest time requirement that's not claimed)
	local nextIndex = nil
	local smallestTime = math.huge
	for i = 1, #(RewardsConfig.Rewards or {}) do
		if not claimed[i] then
			local reqTime = tonumber(RewardsConfig.Rewards[i].seconds) or math.huge
			if reqTime < smallestTime then
				smallestTime = reqTime
				nextIndex = i
			end
		end
	end
	local list = {}
	for i, entry in ipairs(RewardsConfig.Rewards or {}) do
		table.insert(list, {
			index = i,
			seconds = entry.seconds,
			type = entry.type,
			amount = entry.amount,
			image = entry.image,
			claimed = claimed[i] == true,
			next = (nextIndex == i),
		})
	end
	return { elapsed = elapsed, rewards = list }
end

RF_Request.OnServerInvoke = function(player)
	return serializeFor(player)
end

RF_Claim.OnServerInvoke = function(player, index)
	index = tonumber(index)
	if not index then
		return { ok = false, reason = "BadIndex" }
	end
	local def = RewardsConfig.Rewards[index]
	if not def then
		return { ok = false, reason = "NotFound" }
	end
	if PlayerProfile.isPlaytimeClaimed(player.UserId, index) then
		return { ok = false, reason = "AlreadyClaimed" }
	end
	local elapsed = getElapsedFor(player.UserId)
	if elapsed < (tonumber(def.seconds) or math.huge) then
		return { ok = false, reason = "NotReady" }
	end
	-- Grant reward
	local kind = tostring(def.type)
	local amount = math.max(0, math.floor(tonumber(def.amount) or 0))
	local newCoins, newDiamonds
	if kind == "Coins" then
		newCoins = select(1, PlayerProfile.addCoins(player.UserId, amount))
		newDiamonds = select(2, PlayerProfile.getBalances(player.UserId))
	elseif kind == "Diamonds" then
		newCoins, newDiamonds = PlayerProfile.addDiamonds(player.UserId, amount)
	else
		return { ok = false, reason = "BadType" }
	end
	PlayerProfile.markPlaytimeClaimed(player.UserId, index)
	-- Don't send AwardedCoins for playtime rewards since they handle their own animations
	CurrencyUpdated:FireClient(player, { Coins = newCoins, Diamonds = newDiamonds, FromPlaytime = true })
	return { ok = true, Coins = newCoins, Diamonds = newDiamonds }
end

Players.PlayerAdded:Connect(function(plr)
	SESSIONS[plr] = { start = os.time() }
end)

-- Clean up sessions when players leave (but don't save data - handled by 30s auto-save)
Players.PlayerRemoving:Connect(function(plr)
	SESSIONS[plr] = nil
end)

task.spawn(function()
	while true do
		task.wait(30)
		for plr, s in pairs(SESSIONS) do
			if plr.Parent and s.start then
				local delta = math.max(0, os.time() - s.start)
				s.start = os.time()
				local prof = PlayerProfile.load(plr.UserId)
				prof.rewards = prof.rewards
					or { playtimeClaimed = {}, lastPlaytimeDay = nil, playtimeAccumulatedSeconds = 0 }
				prof.rewards.playtimeAccumulatedSeconds = (tonumber(prof.rewards.playtimeAccumulatedSeconds) or 0)
					+ delta
				PlayerProfile.save(plr.UserId)
			end
		end
	end
end)

-- Debug functions
local DebugResetPlaytime = Remotes:WaitForChild("DebugResetPlaytime")
local DebugUnlockNext = Remotes:WaitForChild("DebugUnlockNext")

DebugResetPlaytime.OnServerInvoke = function(player)
	print("DEBUG: Resetting playtime rewards for", player.Name)
	local prof = PlayerProfile.load(player.UserId)
	if prof.rewards then
		prof.rewards.playtimeClaimed = {}
		prof.rewards.playtimeAccumulatedSeconds = 0
		prof.rewards.lastLoginDay = nil
		PlayerProfile.save(player.UserId)
		print("DEBUG: Reset complete for", player.Name)
		return { success = true }
	end
	return { success = false, reason = "Profile not found" }
end

DebugUnlockNext.OnServerInvoke = function(player)
	print("DEBUG: Unlocking next reward for", player.Name)
	local prof = PlayerProfile.load(player.UserId)
	if prof.rewards then
		-- Get current accumulated time
		local currentTime = tonumber(prof.rewards.playtimeAccumulatedSeconds) or 0

		-- Add 10 minutes (600 seconds) to current time
		local newTime = currentTime + 600
		prof.rewards.playtimeAccumulatedSeconds = newTime
		PlayerProfile.save(player.UserId)

		-- Find how many rewards this unlocks
		local unlockedCount = 0
		for i, def in ipairs(RewardsConfig.Rewards or {}) do
			if newTime >= (tonumber(def.seconds) or 0) then
				unlockedCount = unlockedCount + 1
			else
				break
			end
		end

		print(
			"DEBUG: Added 10 minutes. Total time:",
			newTime,
			"seconds. Unlocked rewards:",
			unlockedCount,
			"for",
			player.Name
		)
		return { success = true, totalTime = newTime, unlockedCount = unlockedCount }
	end
	return { success = false, reason = "Profile not found" }
end
