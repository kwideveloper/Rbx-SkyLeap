-- Basic player data and leaderstats for progression

local Players = game:GetService("Players")

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
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end
