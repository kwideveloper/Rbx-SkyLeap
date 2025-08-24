-- Debug buttons for Playtime Rewards testing

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Create simple debug UI
local debugGui = Instance.new("ScreenGui")
debugGui.Name = "PlaytimeDebug"
debugGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
debugGui.Parent = playerGui

-- Container frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 200)
frame.Position = UDim2.new(0, 10, 0, 200) -- Top left area
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(100, 100, 100)
frame.Parent = debugGui

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 0)
title.Text = "PLAYTIME DEBUG"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextStrokeTransparency = 0
title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
title.TextScaled = true
title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

-- Reset button
local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.new(1, -20, 0, 40)
resetBtn.Position = UDim2.new(0, 10, 0, 40)
resetBtn.Text = "RESET ALL REWARDS"
resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resetBtn.TextStrokeTransparency = 0
resetBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
resetBtn.TextScaled = true
resetBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
resetBtn.Font = Enum.Font.SourceSansBold
resetBtn.Parent = frame

-- Unlock next button
local unlockBtn = Instance.new("TextButton")
unlockBtn.Size = UDim2.new(1, -20, 0, 40)
unlockBtn.Position = UDim2.new(0, 10, 0, 90)
unlockBtn.Text = "UNLOCK NEXT REWARD"
unlockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
unlockBtn.TextStrokeTransparency = 0
unlockBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
unlockBtn.TextScaled = true
unlockBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
unlockBtn.Font = Enum.Font.SourceSansBold
unlockBtn.Parent = frame

-- Test animation button
local testBtn = Instance.new("TextButton")
testBtn.Size = UDim2.new(1, -20, 0, 40)
testBtn.Position = UDim2.new(0, 10, 0, 140)
testBtn.Text = "TEST COIN ANIMATION"
testBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
testBtn.TextStrokeTransparency = 0
testBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
testBtn.TextScaled = true
testBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 200)
testBtn.Font = Enum.Font.SourceSansBold
testBtn.Parent = frame

-- Button functions
resetBtn.MouseButton1Click:Connect(function()
	print("DEBUG: Resetting all playtime rewards...")
	local debugResetRemote = Remotes:FindFirstChild("DebugResetPlaytime")
	if debugResetRemote then
		local success, result = pcall(function()
			return debugResetRemote:InvokeServer()
		end)
		if success then
			print("DEBUG: Reset successful!")
		else
			print("DEBUG: Reset failed:", result)
		end
	else
		print("DEBUG: DebugResetPlaytime remote not found!")
	end
end)

unlockBtn.MouseButton1Click:Connect(function()
	print("DEBUG: Unlocking next reward...")
	local debugUnlockRemote = Remotes:FindFirstChild("DebugUnlockNext")
	if debugUnlockRemote then
		local success, result = pcall(function()
			return debugUnlockRemote:InvokeServer()
		end)
		if success then
			print("DEBUG: Unlock successful!")
			-- Trigger UI refresh for PlayTimeRewards
			task.defer(function()
				local playtimeGui = playerGui:FindFirstChild("PlayTimeRewards")
				if playtimeGui then
					-- Trigger re-render by temporarily hiding and showing
					playtimeGui.Enabled = false
					task.wait(0.1)
					playtimeGui.Enabled = true
				end
			end)
		else
			print("DEBUG: Unlock failed:", result)
		end
	else
		print("DEBUG: DebugUnlockNext remote not found!")
	end
end)

-- Test coin animation directly
testBtn.MouseButton1Click:Connect(function()
	print("DEBUG: Testing coin animation directly...")

	-- Create test coins in center of screen
	local screenSize = workspace.CurrentCamera.ViewportSize
	local centerX = screenSize.X / 2
	local centerY = screenSize.Y / 2

	for i = 1, 5 do
		task.spawn(function()
			task.wait(i * 0.1)

			-- Create a bright, visible test coin
			local testGui = Instance.new("ScreenGui")
			testGui.Name = "TestCoinDebug"
			testGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			testGui.Parent = playerGui

			local coin = Instance.new("ImageLabel")
			coin.Size = UDim2.new(0, 50, 0, 50)
			coin.Position = UDim2.new(0, centerX - 25, 0, centerY - 25)
			coin.Image = "rbxassetid://127484940327901"
			coin.BackgroundColor3 = Color3.fromRGB(255, 255, 0) -- Bright yellow background
			coin.BackgroundTransparency = 0.5
			coin.BorderSizePixel = 3
			coin.BorderColor3 = Color3.fromRGB(255, 0, 0) -- Red border
			coin.ZIndex = 1000
			coin.Parent = testGui

			print("DEBUG: Created test coin", i, "at", centerX, centerY)

			-- Move it to random position
			local randomX = math.random(100, screenSize.X - 100)
			local randomY = math.random(100, screenSize.Y - 100)

			local tween = game:GetService("TweenService"):Create(
				coin,
				TweenInfo.new(1.0, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0, randomX, 0, randomY) }
			)

			tween.Completed:Connect(function()
				task.wait(1)
				testGui:Destroy()
			end)

			tween:Play()
		end)
	end
end)

print("DEBUG: Playtime debug buttons loaded!")
