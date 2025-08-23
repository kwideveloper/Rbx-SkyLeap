-- Basic player data and leaderstats for progression

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerProfile = require(ServerScriptService:WaitForChild("PlayerProfile"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local comboReport = remotes:WaitForChild("MaxComboReport")
local styleCommit = remotes:WaitForChild("StyleCommit")
local audioLoaded = remotes:WaitForChild("AudioSettingsLoaded")
local setAudio = remotes:WaitForChild("SetAudioSettings")

local sessionState = {}

local function onPlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = 1
	level.Parent = stats

	local xp = Instance.new("NumberValue")
	xp.Name = "XP"
	xp.Value = 0
	xp.Parent = stats

	-- Total Style points (accumulated across runs; volatile until DataStore is added)
	local style = Instance.new("NumberValue")
	style.Name = "Style"
	style.Value = 0
	style.Parent = stats

	-- Load persisted values into leaderstats
	local p = PlayerProfile.load(player.UserId)
	-- Send audio settings to client on join (defaults 0.5 if nil)
	local settings = p.settings or {}
	audioLoaded:FireClient(player, {
		music = tonumber(settings.musicVolume) or 0.5,
		sfx = tonumber(settings.sfxVolume) or 0.5,
	})

	local maxCombo = Instance.new("IntValue")
	maxCombo.Name = "MaxCombo"
	maxCombo.Value = tonumber((p.stats and p.stats.maxCombo) or 0)
	maxCombo.Parent = stats

	-- TimePlayed is tracked internally but not shown in leaderstats

	-- (MaxCombo/TimePlayed already set from PlayerProfile above)

	-- Track session timing for 10-minute heartbeats and immediate leave update
	sessionState[player] = {
		lastCheckpoint = os.time(),
		alive = true,
		pendingMaxCombo = tonumber((p.stats and p.stats.maxCombo) or 0),
		lastSavedMaxCombo = tonumber((p.stats and p.stats.maxCombo) or 0),
	}

	-- Heartbeat: every 10 minutes, add to TimePlayed and persist
	task.spawn(function()
		while player.Parent and sessionState[player] and sessionState[player].alive do
			task.wait(600)
			if not (player.Parent and sessionState[player] and sessionState[player].alive) then
				break
			end
			-- Update TimePlayed in profile (10 minutes)
			local added = 10
			PlayerProfile.addTimePlayed(player.UserId, added)
			sessionState[player].lastCheckpoint = os.time()
		end
	end)
end
-- Client requests to persist audio settings; only save if changed vs stored
setAudio.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" then
		return
	end
	local music = tonumber(payload.music)
	local sfx = tonumber(payload.sfx)
	if not music and not sfx then
		return
	end
	local profile = PlayerProfile.load(player.UserId)
	profile.settings = profile.settings
		or {
			cameraFov = profile.settings and profile.settings.cameraFov or nil,
			uiScale = profile.settings and profile.settings.uiScale or nil,
		}
	local changed = false
	if music ~= nil then
		music = math.clamp(music, 0, 1)
		if profile.settings.musicVolume ~= music then
			profile.settings.musicVolume = music
			changed = true
		end
	end
	if sfx ~= nil then
		sfx = math.clamp(sfx, 0, 1)
		if profile.settings.sfxVolume ~= sfx then
			profile.settings.sfxVolume = sfx
			changed = true
		end
	end
	if changed then
		PlayerProfile.save(player.UserId)
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	-- Stop heartbeat for this player
	if sessionState[player] then
		sessionState[player].alive = false
	end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	-- Flush residual time since last checkpoint (in minutes)
	if sessionState[player] and sessionState[player].lastCheckpoint then
		local minutes = math.floor(math.max(0, os.time() - sessionState[player].lastCheckpoint) / 60)
		if minutes > 0 then
			PlayerProfile.addTimePlayed(player.UserId, minutes)
		end
	end
	-- Persist MaxCombo on leave as well (best effort), using buffered session max if available
	local mc = stats:FindFirstChild("MaxCombo")
	local pending = sessionState[player] and sessionState[player].pendingMaxCombo or (mc and mc.Value) or 0
	if pending and pending > 0 then
		PlayerProfile.setMaxComboIfHigher(player.UserId, pending)
	end
	-- Cleanup
	sessionState[player] = nil
	-- Save and release profile
	PlayerProfile.release(player.UserId)
end)

-- Accept client reports of current combo value, but DO NOT persist immediately.
-- We will persist on style commit to avoid DataStore throttling.
comboReport.OnServerEvent:Connect(function(player, reported)
	local value = tonumber(reported) or 0
	if value <= 0 then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local mc = stats:FindFirstChild("MaxCombo")
	if not mc then
		mc = Instance.new("IntValue")
		mc.Name = "MaxCombo"
		mc.Value = 0
		mc.Parent = stats
	end
	-- Update visible leaderstat without DataStore write
	if value > mc.Value then
		mc.Value = value
	end
	-- Buffer the highest combo seen until commit
	local ss = sessionState[player]
	if ss then
		ss.pendingMaxCombo = math.max(ss.pendingMaxCombo or 0, value)
	end
end)

-- Persist buffered MaxCombo when the style chain is committed
styleCommit.OnServerEvent:Connect(function(player)
	local ss = sessionState[player]
	if not ss then
		return
	end
	local toSave = tonumber(ss.pendingMaxCombo) or 0
	if toSave > 0 and toSave > (ss.lastSavedMaxCombo or 0) then
		ss.lastSavedMaxCombo = toSave
		PlayerProfile.setMaxComboIfHigher(player.UserId, toSave)
	end
end)
