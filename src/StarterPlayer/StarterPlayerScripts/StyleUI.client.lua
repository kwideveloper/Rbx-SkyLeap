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

local styleFrame = root:FindFirstChild("Style")
local scoreLabel

do
	local scope = styleFrame or root
	scoreLabel = scope:FindFirstChild("Score")
end

local comboFrame = root:FindFirstChild("Combo")

local multLabel = comboFrame:FindFirstChild("Multiplier")

local comboLabel = comboFrame:FindFirstChild("Combo")

-- Compact combo timeout ring at top-right of root
local comboRing = root:FindFirstChild("ComboRing")
local comboRingTicks = {}
local TOTAL_TICKS = 12
if not comboRing then
	comboRing = Instance.new("Frame")
	comboRing.Name = "ComboRing"
	comboRing.Size = UDim2.new(0, 26, 0, 26)
	comboRing.Position = UDim2.new(1, -34, 0, 6)
	comboRing.BackgroundTransparency = 1
	comboRing.Parent = root
	-- Background ring stroke
	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundTransparency = 1
	bg.Parent = comboRing
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(40, 60, 90)
	stroke.Transparency = 0.3
	stroke.Parent = bg
	-- Build tick holders
	for i = 1, TOTAL_TICKS do
		local holder = Instance.new("Frame")
		holder.Name = "H" .. i
		holder.Size = UDim2.new(1, 0, 1, 0)
		holder.BackgroundTransparency = 1
		holder.Rotation = (i - 1) * (360 / TOTAL_TICKS)
		holder.Parent = comboRing
		local tick = Instance.new("Frame")
		tick.Name = "T"
		tick.AnchorPoint = Vector2.new(0.5, 0)
		tick.Position = UDim2.new(0.5, 0, 0, 2)
		tick.Size = UDim2.new(0, 3, 0, 7)
		tick.BackgroundColor3 = Color3.fromRGB(120, 220, 255)
		tick.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = tick
		tick.Parent = holder
		comboRingTicks[i] = tick
	end
else
	-- Rebind existing ticks if present
	comboRingTicks = {}
	for i = 1, TOTAL_TICKS do
		local h = comboRing:FindFirstChild("H" .. i)
		local t = h and h:FindFirstChild("T")
		if t then
			comboRingTicks[i] = t
		end
	end
end

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

local function spawnComboPopup(text, amount)
	amount = tonumber(amount) or 1
	local label = Instance.new("TextLabel")
	label.Name = "ComboPopup"
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 26
	-- Color scales to stronger orange as amount increases
	local t = math.clamp((amount - 1) / 4, 0, 1)
	local r1, g1, b1 = 255, 160, 60
	local r2, g2, b2 = 255, 100, 30
	local r = math.floor(r1 + (r2 - r1) * t + 0.5)
	local g = math.floor(g1 + (g2 - g1) * t + 0.5)
	local b = math.floor(b1 + (b2 - b1) * t + 0.5)
	label.TextColor3 = Color3.fromRGB(r, g, b)
	label.TextTransparency = 0.2
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.ZIndex = 10

	-- Randomized spawn near center (bounded area)
	local dxScale = (math.random(-8, 8)) / 100 -- +/- 0.08
	local dyScale = (math.random(-6, 6)) / 100 -- +/- 0.06
	local dxOffset = math.random(-20, 20) -- pixels
	local dyOffset = math.random(-12, 12)
	label.Position = UDim2.new(0.5 + dxScale, dxOffset, 0.40 + dyScale, dyOffset)
	label.Rotation = math.random(-8, 8)
	label.Parent = screenGui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = math.clamp(2 + (amount - 1) * 0.4, 2, 4)
	stroke.Color = Color3.fromRGB(40, 24, 8)
	stroke.Transparency = 0.2
	stroke.Parent = label

	local scale = Instance.new("UIScale")
	local base = 0.28
	local grow = 0.04 * (amount - 1)
	scale.Scale = base + grow
	scale.Parent = label

	-- Randomized diagonal travel
	local dirX = (math.random(0, 1) == 0) and -1 or 1
	local travelX = dirX * math.random(40, 100) -- px
	local travelY = -math.random(80, 160) -- upwards

	local p1 = UDim2.new(
		label.Position.X.Scale,
		label.Position.X.Offset + math.floor(travelX * 0.4 + 0.5),
		label.Position.Y.Scale,
		label.Position.Y.Offset + math.floor(travelY * 0.5 + 0.5)
	)
	local p2 = UDim2.new(
		label.Position.X.Scale,
		label.Position.X.Offset + travelX,
		label.Position.Y.Scale,
		label.Position.Y.Offset + travelY
	)

	local tIn = TweenInfo.new(0.10 + math.random() * 0.04, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tMid = TweenInfo.new(0.12 + math.random() * 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tOut = TweenInfo.new(0.28 + math.random() * 0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	-- Pop in (grow and move slightly)
	local pop = 1.02 + math.min(0.08 * (amount - 1), 0.18)
	TweenService:Create(scale, tIn, { Scale = pop }):Play()
	TweenService:Create(label, tIn, { TextTransparency = 0, Position = p1 }):Play()
	TweenService:Create(stroke, tIn, { Transparency = 0.08 }):Play()

	-- Slight settle
	task.delay(tIn.Time, function()
		local settle = 0.92 + math.min(0.06 * (amount - 1), 0.12)
		TweenService:Create(scale, tMid, { Scale = settle }):Play()
	end)

	-- Drift out and fade (move further on a diagonal path)
	task.delay(tIn.Time + tMid.Time + 0.10, function()
		local endScale = 0.68 + math.min(0.05 * (amount - 1), 0.10)
		TweenService:Create(scale, tOut, { Scale = endScale }):Play()
		TweenService:Create(label, tOut, { TextTransparency = 1, Position = p2, Rotation = label.Rotation + dirX * 6 })
			:Play()
		TweenService:Create(stroke, tOut, { Transparency = 1 }):Play()
		task.delay(tOut.Time + 0.05, function()
			label:Destroy()
		end)
	end)
end

local shownScore = 0
local lastCombo = 0
local lastMult = 1
local lastScore = 0

-- Aggregate quick combo increases into a single popup within a short window
local COMBO_POPUP_WINDOW = (require(ReplicatedStorage.Movement.Config).StyleComboPopupWindowSeconds or 0.25)
local comboPopupAcc = 0
local comboPopupSeq = 0
local function scheduleComboPopup()
	comboPopupSeq = comboPopupSeq + 1
	local mySeq = comboPopupSeq
	task.delay(COMBO_POPUP_WINDOW, function()
		if mySeq == comboPopupSeq and comboPopupAcc > 0 then
			spawnComboPopup("+" .. tostring(comboPopupAcc) .. " COMBO", comboPopupAcc)
			comboPopupAcc = 0
		end
	end)
end

-- ClientState bindings for combo timeout
local clientState = ReplicatedStorage:WaitForChild("ClientState")
local comboRemainV = clientState:FindFirstChild("StyleComboTimeRemaining")
local comboMaxV = clientState:FindFirstChild("StyleComboTimeMax")
local function colorForTimerRatio(r)
	if r >= 0.66 then
		return Color3.fromRGB(120, 220, 255)
	elseif r >= 0.33 then
		return Color3.fromRGB(245, 180, 60)
	else
		return Color3.fromRGB(255, 90, 90)
	end
end

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
	end

	-- Multiplier and combo updates
	multLabel.Text = string.format("x%.2f", mult)
	comboLabel.Text = string.format("Combo: %d", combo)

	-- Bumps on increases
	if combo > lastCombo then
		tweenTextBump(comboLabel)
		local inc = math.max(1, combo - lastCombo)
		comboPopupAcc = comboPopupAcc + inc
		scheduleComboPopup()
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

	-- Update ring ticks based on remaining time
	if comboRing and comboRingTicks and comboRemainV and comboMaxV then
		local max = (comboMaxV.Value or 3)
		local remain = (comboRemainV.Value or 0)
		if combo > 0 and max > 0 then
			comboRing.Visible = true
			local t = math.clamp(remain / max, 0, 1)
			local lit = math.clamp(math.floor(t * TOTAL_TICKS + 0.5), 0, TOTAL_TICKS)
			for i = 1, TOTAL_TICKS do
				local tick = comboRingTicks[i]
				if tick then
					if i <= lit then
						tick.BackgroundColor3 = colorForTimerRatio(t)
						tick.BackgroundTransparency = 0
					else
						tick.BackgroundColor3 = Color3.fromRGB(80, 90, 120)
						tick.BackgroundTransparency = 0.5
					end
				end
			end
		else
			comboRing.Visible = false
		end
	end
end

RunService.RenderStepped:Connect(step)

-- Avoid false trigger on respawn
Players.LocalPlayer.CharacterAdded:Connect(function()
	lastMult = 1
	shownScore = 0
	lastScore = 0
end)
