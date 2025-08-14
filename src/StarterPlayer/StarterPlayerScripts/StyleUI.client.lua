-- Temporary Style UI: now switches to use existing StarterGui/StyleUI when present

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function getClientState()
	local folder = ReplicatedStorage:FindFirstChild("ClientState")
	return folder,
		folder and folder:FindFirstChild("StyleScore") or nil,
		folder and folder:FindFirstChild("StyleCombo") or nil,
		folder and folder:FindFirstChild("StyleMultiplier") or nil,
		folder and folder:FindFirstChild("StyleCommittedAmount") or nil,
		folder and folder:FindFirstChild("StyleCommittedFlash") or nil
end

local screenGui = playerGui:WaitForChild("StyleUI")
screenGui.ResetOnSpawn = false

local root = screenGui:WaitForChild("Root")

do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(70, 140, 255)
	stroke.Transparency = 0.25
	stroke.Parent = root
end

local title = root:FindFirstChild("Title")

local leftStack = root:FindFirstChild("Left")
local scoreLabelShadow
do
	local scope = leftStack or root
	scoreLabelShadow = scope:FindFirstChild("ScoreShadow")
end

local scoreLabel
do
	local scope = leftStack or root
	scoreLabel = scope:FindFirstChild("Score")
end

local rightStack = root:FindFirstChild("Right")

local multLabel = rightStack:FindFirstChild("Multiplier")

local comboLabel = rightStack:FindFirstChild("Combo")

local baseTextSize = setmetatable({}, { __mode = "k" })
local function tweenTextBump(label)
	if not label then
		return
	end
	-- Cache the original text size per label to avoid cumulative drift
	if not baseTextSize[label] then
		baseTextSize[label] = label.TextSize
	end
	if label.TextScaled then
		-- If TextScaled is enabled, bump color/transparency instead of TextSize
		local orig = label.TextColor3
		local bright = Color3.new(math.min(1, orig.R + 0.25), math.min(1, orig.G + 0.25), math.min(1, orig.B + 0.25))
		local infoIn = TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		local infoOut = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(label, infoIn, { TextColor3 = bright, TextTransparency = 0 }):Play()
		task.delay(0.12, function()
			TweenService:Create(label, infoOut, { TextColor3 = orig }):Play()
		end)
		return
	end
	local baseSize = baseTextSize[label]
	local bumpSize = math.max(1, math.floor(baseSize * 1.16 + 0.5))
	local infoIn = TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local infoOut = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, infoIn, { TextSize = bumpSize }):Play()
	task.delay(0.12, function()
		TweenService:Create(label, infoOut, { TextSize = baseSize }):Play()
	end)
end

local function getLeaderboardAnchor()
	-- Try to find a target UI element; otherwise use top-right corner in pixels
	local lb = playerGui:FindFirstChild("Leaderboard")
	if lb and lb:IsA("ScreenGui") then
		local pos = lb.AbsolutePosition or Vector2.new(screenGui.AbsoluteSize.X - 40, 40)
		return UDim2.fromOffset(pos.X + 20, pos.Y + 20)
	end
	return UDim2.fromOffset(screenGui.AbsoluteSize.X - 40, 40)
end

local function getScoreAnchor()
	if scoreLabel then
		local p = scoreLabel.AbsolutePosition
		local s = scoreLabel.AbsoluteSize
		return UDim2.fromOffset(p.X + s.X - 80, p.Y + s.Y * 0.5)
	end
	-- fallback center-top
	return UDim2.fromOffset(screenGui.AbsoluteSize.X * 0.5, 40)
end

local function spawnScoreFly(text)
	local fly = Instance.new("TextLabel")
	fly.Name = "FlyScore"
	fly.BackgroundTransparency = 1
	fly.Text = text
	fly.Font = Enum.Font.GothamBlack
	fly.TextSize = 28
	fly.TextColor3 = Color3.fromRGB(255, 230, 120)
	fly.AnchorPoint = Vector2.new(0.5, 0.5)
	fly.Position = getScoreAnchor()
	fly.Parent = screenGui
	-- First rise up slowly, then fly to leaderboard
	local rise = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local target = getLeaderboardAnchor()
	local afterRisePos = UDim2.fromOffset(fly.Position.X.Offset, fly.Position.Y.Offset - 22)
	TweenService:Create(fly, rise, { Position = afterRisePos, TextTransparency = 0 }):Play()
	task.delay(0.36, function()
		local flyInfo = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(fly, flyInfo, { Position = target, TextTransparency = 0.1 }):Play()
		task.delay(0.56, function()
			local out = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(fly, out, { TextTransparency = 1 }):Play()
			task.delay(0.26, function()
				fly:Destroy()
			end)
		end)
	end)
end

local shownScore = 0
local lastCombo = 0
local lastMult = 1
local lastScore = 0

local function step()
	local folder, scoreV, comboV, multV, committedAmount, committedFlash = getClientState()
	if not folder then
		return
	end
	local score = scoreV and scoreV.Value or 0
	local combo = comboV and comboV.Value or 0
	local mult = multV and multV.Value or 1

	-- Smooth score display (formatted to 2 decimals)
	local target = math.floor(score + 0.5)
	if shownScore ~= target then
		local delta = target - shownScore
		local stepAmount = math.clamp(math.abs(delta) * 0.2, 1, 1000)
		if delta > 0 then
			shownScore = math.min(target, shownScore + stepAmount)
		else
			shownScore = math.max(target, shownScore - stepAmount)
		end
		local txt = string.format("%.2f", shownScore)
		scoreLabel.Text = txt
		scoreLabelShadow.Text = txt
	end

	-- Multiplier and combo updates
	multLabel.Text = string.format("x%.2f", mult)
	comboLabel.Text = string.format("Combo: %d", combo)

	-- Bumps on increases
	if combo > lastCombo then
		tweenTextBump(comboLabel)
	end
	if mult > lastMult then
		tweenTextBump(multLabel)
	end

	-- Combo break detection: previous mult > 1 and now == 1
	if committedFlash and committedFlash.Value == true then
		local amt = committedAmount and committedAmount.Value or score
		if (amt or 0) > 0.01 then
			tweenTextBump(scoreLabel)
			spawnScoreFly(string.format("%.2f", amt))
		end
	end

	lastScore = score
	lastCombo = combo
	lastMult = mult
end

RunService.RenderStepped:Connect(step)

-- Avoid false trigger on respawn
Players.LocalPlayer.CharacterAdded:Connect(function()
	lastMult = 1
	shownScore = 0
	lastScore = 0
end)
