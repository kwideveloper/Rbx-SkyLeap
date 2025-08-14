-- Basic player data and leaderstats for progression

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerProfile = require(ServerScriptService:WaitForChild("PlayerProfile"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local comboReport = remotes:WaitForChild("MaxComboReport")

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
	-- Persist MaxCombo on leave as well (best effort)
	local mc = stats:FindFirstChild("MaxCombo")
	if mc then
		PlayerProfile.setMaxComboIfHigher(player.UserId, mc.Value)
	end
	-- Cleanup
	sessionState[player] = nil
	-- Save and release profile
	PlayerProfile.release(player.UserId)
end)

-- Accept client reports of new max combo values
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
	local newMax = PlayerProfile.setMaxComboIfHigher(player.UserId, value)
	if newMax > mc.Value then
		mc.Value = newMax
	end
end)
