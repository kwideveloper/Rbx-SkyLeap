-- Server-side simple leaderboard for total style points

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerProfile = require(ServerScriptService:WaitForChild("PlayerProfile"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local styleCommit = remotes:WaitForChild("StyleCommit")
-- Currency is handled in Currency.server.lua

-- Mirror total style into default Roblox leaderstats as NumberValue "Style"
local function loadStyleTotal(player)
	local p = PlayerProfile.load(player.UserId)
	return tonumber((p.stats and p.stats.styleTotal) or 0)
end

Players.PlayerAdded:Connect(function(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local style = stats:FindFirstChild("Style")
	if not style then
		style = Instance.new("NumberValue")
		style.Name = "Style"
		style.Value = 0
		style.Parent = stats
	end
	local total = loadStyleTotal(player)
	style.Value = total
	-- Also ensure MaxCombo/TimePlayed are materialized from profile if PlayerData didn't run yet
	local prof = PlayerProfile.load(player.UserId)
	if not stats:FindFirstChild("MaxCombo") then
		local mc = Instance.new("IntValue")
		mc.Name = "MaxCombo"
		mc.Value = tonumber((prof.stats and prof.stats.maxCombo) or 0)
		mc.Parent = stats
	end
	-- TimePlayed is tracked internally but not shown in leaderstats
end)

-- No explicit save here; PlayerProfile.addStyleTotal already persists on commit

styleCommit.OnServerEvent:Connect(function(player, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local style = stats:FindFirstChild("Style")
	if not style then
		style = Instance.new("NumberValue")
		style.Name = "Style"
		style.Value = 0
		style.Parent = stats
	end
	style.Value = style.Value + amount
	-- Save asynchronously (fire-and-forget); PlayerRemoving persists too
	-- Mirror into PlayerProfile styleTotal for unified access (single source of truth)
	PlayerProfile.addStyleTotal(player.UserId, amount)
end)
