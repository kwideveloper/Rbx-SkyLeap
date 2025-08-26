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
	-- Use server time to prevent player manipulation of system clock
	-- os.time() returns the server's current time, not the player's local time
	local serverTime = os.time() -- Server time (cannot be manipulated by players)
	local serverDate = os.date("*t", serverTime) -- Server local date

	-- Check if we're past 11:59:59 PM (23:59:59) for the current server day
	-- Use a more robust check to avoid edge cases with server time precision
	local currentHour = serverDate.hour
	local currentMin = serverDate.min
	local currentSec = serverDate.sec

	local dayKey
	local isEndOfDay = (currentHour == 23 and currentMin == 59 and currentSec >= 55) -- Changed from 59 to 55 for safety margin

	if isEndOfDay then
		-- Past 23:59:55, use next day (giving 5 second buffer to avoid timing issues)
		dayKey = string.format("%04d%02d%02d", serverDate.year, serverDate.month, serverDate.day + 1)
	else
		-- Before 23:59:55, use current day
		dayKey = string.format("%04d%02d%02d", serverDate.year, serverDate.month, serverDate.day)
	end

	p.rewards = p.rewards or { playtimeClaimed = {}, lastPlaytimeDay = nil, playtimeAccumulatedSeconds = 0 }

	local lastDay = p.rewards.lastPlaytimeDay
	local accBeforeReset = tonumber(p.rewards.playtimeAccumulatedSeconds) or 0

	if lastDay ~= dayKey then
		p.rewards.playtimeClaimed = {}
		p.rewards.lastPlaytimeDay = dayKey
		p.rewards.playtimeAccumulatedSeconds = 0
		PlayerProfile.save(userId)
	end

	local acc = tonumber(p.rewards.playtimeAccumulatedSeconds) or 0
	local playing = 0

	-- Find current session for this user (more robust search)
	for plr, s in pairs(SESSIONS) do
		if plr and plr.UserId == userId and s and s.start then
			local sessionTime = math.max(0, os.time() - s.start)
			playing = sessionTime
			break
		end
	end

	local total = acc + playing
	return total
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
		local remaining = entry.seconds - elapsed
		local isClaimable = not claimed[i] and elapsed >= entry.seconds

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
	local userId = plr.UserId
	local currentTime = os.time()

	-- Load current profile to check existing time and validate data integrity
	local prof = PlayerProfile.load(userId)
	local existingAccumulated = 0

	if prof and prof.rewards then
		existingAccumulated = tonumber(prof.rewards.playtimeAccumulatedSeconds) or 0

		-- Validate that the accumulated time is reasonable (not negative, not excessively high)
		if existingAccumulated < 0 then
			prof.rewards.playtimeAccumulatedSeconds = 0
			PlayerProfile.save(userId)
			existingAccumulated = 0
		elseif existingAccumulated > 86400 then -- More than 24 hours in a single day
			prof.rewards.playtimeAccumulatedSeconds = 86400
			PlayerProfile.save(userId)
			existingAccumulated = 86400
		end
	end

	SESSIONS[plr] = { start = currentTime }
end)

-- Clean up sessions when players leave (save data immediately before cleanup)
Players.PlayerRemoving:Connect(function(plr)
	if SESSIONS[plr] and SESSIONS[plr].start then
		local sessionStart = SESSIONS[plr].start
		local currentTime = os.time()
		local delta = math.max(0, currentTime - sessionStart)

		local prof = PlayerProfile.load(plr.UserId)
		prof.rewards = prof.rewards or { playtimeClaimed = {}, lastPlaytimeDay = nil, playtimeAccumulatedSeconds = 0 }

		local accumulatedBefore = tonumber(prof.rewards.playtimeAccumulatedSeconds) or 0
		local accumulatedAfter = accumulatedBefore + delta

		prof.rewards.playtimeAccumulatedSeconds = accumulatedAfter
		PlayerProfile.save(plr.UserId)
	end
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

				local accumulatedBefore = tonumber(prof.rewards.playtimeAccumulatedSeconds) or 0
				local accumulatedAfter = accumulatedBefore + delta

				prof.rewards.playtimeAccumulatedSeconds = accumulatedAfter
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

-- Debug function to check current playtime status
local DebugGetStatus = Remotes:WaitForChild("DebugGetPlaytimeStatus")
DebugGetStatus.OnServerInvoke = function(player)
	local userId = player.UserId
	local prof = PlayerProfile.load(userId)

	local result = {
		userId = userId,
		playerName = player.Name,
		serverTime = os.time(),
		sessionInfo = "No active session",
	}

	-- Check if player has active session
	for plr, s in pairs(SESSIONS) do
		if plr.UserId == userId and s.start then
			result.sessionInfo =
				string.format("Active session started at %d (%d seconds ago)", s.start, os.time() - s.start)
			break
		end
	end

	-- Profile information
	if prof and prof.rewards then
		result.profileInfo = {
			lastPlaytimeDay = prof.rewards.lastPlaytimeDay or "Never",
			playtimeAccumulatedSeconds = tonumber(prof.rewards.playtimeAccumulatedSeconds) or 0,
			claimedRewards = prof.rewards.playtimeClaimed or {},
		}
	else
		result.profileInfo = "No profile data"
	end

	-- Calculate current elapsed time
	local elapsed = getElapsedFor(userId)
	result.calculatedElapsed = elapsed

	-- Format times for readability
	local function formatTime(seconds)
		local h = math.floor(seconds / 3600)
		local m = math.floor((seconds % 3600) / 60)
		local s = seconds % 60
		if h > 0 then
			return string.format("%dh %dm %ds", h, m, s)
		else
			return string.format("%dm %ds", m, s)
		end
	end

	result.formattedElapsed = formatTime(elapsed)
	if result.profileInfo ~= "No profile data" then
		result.formattedAccumulated = formatTime(result.profileInfo.playtimeAccumulatedSeconds)
	end

	return result
end
