-- Anti-Cheat system for SkyLeap
-- Monitors suspicious activity and implements security measures

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local AntiCheat = {}

-- Configuration
local SUSPICIOUS_ACTIVITY_LOG = {}
local BAN_THRESHOLDS = {
	StyleCommitSpam = 5, -- 5 suspicious commits = ban
	PowerupSpam = 10, -- 10 powerup spam attempts = ban
	InvalidRequests = 20, -- 20 invalid requests = ban
	RateLimitViolation = 3, -- 3 rate limit violations = temporary ban
}

local TEMP_BANS = {} -- [userId] = unbanTime
local RATE_LIMITS = {
	StyleCommit = { window = 2, maxCount = 15 }, -- 15 commits per 2 seconds max
	PowerupTouch = { window = 1, maxCount = 5 }, -- 5 powerup touches per second max
}

local playerRateLimits = {} -- [userId][action] = {timestamps = {}, violations = 0}

-- Utility functions
local function cleanOldEntries(userId, action, window)
	if not playerRateLimits[userId] or not playerRateLimits[userId][action] then
		return
	end

	local now = os.clock()
	local timestamps = playerRateLimits[userId][action].timestamps
	local cleaned = {}

	for _, timestamp in ipairs(timestamps) do
		if (now - timestamp) < window then
			table.insert(cleaned, timestamp)
		end
	end

	playerRateLimits[userId][action].timestamps = cleaned
end

-- Rate limiting system
function AntiCheat.checkRateLimit(player, action)
	local userId = player.UserId
	local now = os.clock()

	if not RATE_LIMITS[action] then
		return true -- No rate limit configured for this action
	end

	local config = RATE_LIMITS[action]

	-- Initialize player data
	if not playerRateLimits[userId] then
		playerRateLimits[userId] = {}
	end
	if not playerRateLimits[userId][action] then
		playerRateLimits[userId][action] = { timestamps = {}, violations = 0 }
	end

	local actionData = playerRateLimits[userId][action]

	-- Clean old entries
	cleanOldEntries(userId, action, config.window)

	-- Check if within limit
	if #actionData.timestamps >= config.maxCount then
		-- Rate limit violation
		actionData.violations = actionData.violations + 1

		AntiCheat.logSuspiciousActivity(player, "RateLimitViolation", {
			action = action,
			attempts = #actionData.timestamps,
			maxAllowed = config.maxCount,
			window = config.window,
			totalViolations = actionData.violations,
		})

		return false
	end

	-- Add timestamp
	table.insert(actionData.timestamps, now)
	return true
end

-- Logging system
function AntiCheat.logSuspiciousActivity(player, activityType, details)
	local userId = player.UserId
	local now = os.time()

	-- Check temporary ban
	if TEMP_BANS[userId] and TEMP_BANS[userId] > now then
		player:Kick("Temporary ban active. Try again later.")
		return
	end

	if not SUSPICIOUS_ACTIVITY_LOG[userId] then
		SUSPICIOUS_ACTIVITY_LOG[userId] = {}
	end

	local entry = {
		type = activityType,
		details = details,
		timestamp = now,
		playerName = player.Name,
	}

	table.insert(SUSPICIOUS_ACTIVITY_LOG[userId], entry)

	-- Log for analysis
	warn(
		string.format(
			"[ANTI-CHEAT] %s (%d): %s - %s",
			player.Name,
			userId,
			activityType,
			HttpService:JSONEncode(details)
		)
	)

	-- Check if should be banned
	local typeCount = 0
	for _, log in ipairs(SUSPICIOUS_ACTIVITY_LOG[userId]) do
		if log.type == activityType and (now - log.timestamp) < 3600 then -- last hour
			typeCount = typeCount + 1
		end
	end

	if typeCount >= (BAN_THRESHOLDS[activityType] or 999) then
		AntiCheat.banPlayer(player, activityType)
	end
end

-- Ban system
function AntiCheat.banPlayer(player, reason)
	local userId = player.UserId

	warn(string.format("[ANTI-CHEAT] BANNING PLAYER: %s (%d) - Reason: %s", player.Name, userId, reason))

	-- Temporary ban for rate limit violations
	if reason == "RateLimitViolation" then
		TEMP_BANS[userId] = os.time() + 300 -- 5 minutes
		player:Kick("Temporary ban for suspicious activity. Wait 5 minutes before rejoining.")
	else
		-- Permanent ban for serious exploits
		player:Kick("Banned for exploiting. Contact support if you believe this is an error.")
		-- TODO: Integrate with persistent ban system
	end
end

-- Validation functions
function AntiCheat.validateStyleCommit(player, amount)
	if not AntiCheat.checkRateLimit(player, "StyleCommit") then
		return false
	end

	amount = tonumber(amount) or 0

	-- Validate range
	local MAX_STYLE_PER_COMMIT = 500 -- Reasonable limit per commit
	if amount <= 0 or amount > MAX_STYLE_PER_COMMIT then
		AntiCheat.logSuspiciousActivity(player, "StyleCommitSpam", {
			sentAmount = amount,
			maxAllowed = MAX_STYLE_PER_COMMIT,
		})
		return false
	end

	-- Additional validation: check if amount is realistic based on time
	local userId = player.UserId
	if not playerRateLimits[userId] then
		playerRateLimits[userId] = {}
	end
	if not playerRateLimits[userId].lastStyleCommit then
		playerRateLimits[userId].lastStyleCommit = os.clock()
		return true
	end

	local timeSinceLastCommit = os.clock() - playerRateLimits[userId].lastStyleCommit
	local maxReasonableAmount = timeSinceLastCommit * 50 -- Max 50 style points per second

	if amount > maxReasonableAmount and timeSinceLastCommit < 10 then
		AntiCheat.logSuspiciousActivity(player, "StyleCommitSpam", {
			sentAmount = amount,
			timeSinceLastCommit = timeSinceLastCommit,
			maxReasonableAmount = maxReasonableAmount,
		})
		return false
	end

	playerRateLimits[userId].lastStyleCommit = os.clock()
	return true
end

function AntiCheat.validatePowerupTouch(player, part)
	if not AntiCheat.checkRateLimit(player, "PowerupTouch") then
		return false
	end

	-- Additional powerup-specific validation
	local character = player.Character
	if not (character and character:FindFirstChild("HumanoidRootPart")) then
		return false
	end

	local hrp = character.HumanoidRootPart
	local distance = (hrp.Position - part.Position).Magnitude
	local MAX_POWERUP_TOUCH_DISTANCE = 50 -- studs

	if distance > MAX_POWERUP_TOUCH_DISTANCE then
		AntiCheat.logSuspiciousActivity(player, "PowerupSpam", {
			distance = distance,
			maxAllowed = MAX_POWERUP_TOUCH_DISTANCE,
			partName = part.Name,
		})
		return false
	end

	return true
end

-- Cleanup system
local function cleanupOldLogs()
	local now = os.time()
	local ONE_DAY = 86400

	for userId, logs in pairs(SUSPICIOUS_ACTIVITY_LOG) do
		local cleaned = {}
		for _, log in ipairs(logs) do
			if (now - log.timestamp) < ONE_DAY then
				table.insert(cleaned, log)
			end
		end
		SUSPICIOUS_ACTIVITY_LOG[userId] = cleaned
	end

	-- Clean temporary bans
	for userId, unbanTime in pairs(TEMP_BANS) do
		if now > unbanTime then
			TEMP_BANS[userId] = nil
		end
	end
end

-- Player cleanup
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	playerRateLimits[userId] = nil
	-- Keep logs for analysis but clean rate limit data
end)

-- Periodic cleanup
task.spawn(function()
	while true do
		task.wait(300) -- Run every 5 minutes
		cleanupOldLogs()
	end
end)

-- Debug commands (only in Studio)
if RunService:IsStudio() then
	function AntiCheat.debugGetPlayerLogs(userId)
		return SUSPICIOUS_ACTIVITY_LOG[userId] or {}
	end

	function AntiCheat.debugClearPlayerLogs(userId)
		SUSPICIOUS_ACTIVITY_LOG[userId] = nil
		playerRateLimits[userId] = nil
		TEMP_BANS[userId] = nil
	end

	function AntiCheat.debugGetStats()
		local stats = {
			totalPlayers = 0,
			playersWithLogs = 0,
			totalLogs = 0,
			tempBans = 0,
		}

		for userId, logs in pairs(SUSPICIOUS_ACTIVITY_LOG) do
			stats.totalPlayers = stats.totalPlayers + 1
			if #logs > 0 then
				stats.playersWithLogs = stats.playersWithLogs + 1
				stats.totalLogs = stats.totalLogs + #logs
			end
		end

		for userId, _ in pairs(TEMP_BANS) do
			stats.tempBans = stats.tempBans + 1
		end

		return stats
	end
end

return AntiCheat
