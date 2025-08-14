-- Simple client leaderboard UI bound to ReplicatedStorage.Leaderboard

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local lbFolder = ReplicatedStorage:WaitForChild("Leaderboard")

local gui = Instance.new("ScreenGui")
gui.Name = "Leaderboard"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "Root"
frame.Size = UDim2.new(0, 240, 0, 210)
frame.Position = UDim2.new(1, -260, 0, 20)
frame.BackgroundTransparency = 0.35
frame.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
frame.BorderSizePixel = 0
frame.Parent = gui

do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -12, 0, 22)
title.Position = UDim2.new(0, 6, 0, 6)
title.BackgroundTransparency = 1
title.Text = "Top Style"
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(200, 220, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Left
list.VerticalAlignment = Enum.VerticalAlignment.Top
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = frame

local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, -12, 1, -36)
content.Position = UDim2.new(0, 6, 0, 30)
content.BackgroundTransparency = 1
content.Parent = frame

local function render()
	content:ClearAllChildren()
	local entries = {}
	for _, v in ipairs(lbFolder:GetChildren()) do
		if v:IsA("NumberValue") then
			table.insert(entries, { key = v.Name, value = v.Value })
		end
	end
	table.sort(entries, function(a, b)
		return a.value > b.value
	end)
	local limit = math.min(10, #entries)
	for i = 1, limit do
		local e = entries[i]
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 18)
		row.BackgroundTransparency = 1
		local name = "User " .. e.key
		local plr = Players:GetPlayerByUserId(tonumber(e.key) or 0)
		if plr then
			name = plr.DisplayName .. " (@" .. plr.Name .. ")"
		end
		row.Text = string.format("%d. %s  -  %.2f", i, name, e.value)
		row.Font = Enum.Font.Gotham
		row.TextSize = 14
		row.TextColor3 = Color3.fromRGB(235, 245, 255)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = i
		row.Parent = content
	end
end

lbFolder.ChildAdded:Connect(render)
lbFolder.ChildRemoved:Connect(render)
for _, v in ipairs(lbFolder:GetChildren()) do
	if v:IsA("NumberValue") then
		v:GetPropertyChangedSignal("Value"):Connect(render)
	end
end
render()
