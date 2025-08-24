-- Currency UI binder: auto-binds TextLabels/TextButtons tagged as "Coin" or "Diamond"
-- Updates text to current balances and stays in sync via remotes

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CurrencyUpdated = Remotes:WaitForChild("CurrencyUpdated")
local RequestBalances = Remotes:WaitForChild("RequestBalances")

local CurrencyConfig = require(ReplicatedStorage:WaitForChild("Currency"):WaitForChild("Config"))

local state = {
	coins = 0,
	diamonds = 0,
	-- Animated display values
	displayCoins = 0,
	displayDiamonds = 0,
	coinAnim = nil,
	diamondAnim = nil,
}

local COIN_IMAGE = "rbxassetid://127484940327901"
local playerGui = player:WaitForChild("PlayerGui")

-- Cache original text colors and active color tokens per label for safe revert
local baseTextColor = setmetatable({}, { __mode = "k" })
local colorToken = setmetatable({}, { __mode = "k" })

-- UI SFX helpers: expects PlayerScripts/Sounds/SFX/UI/{CoinSpawn,CoinArrive}
local function getUiSfxTemplate(name)
	local ps = player:FindFirstChild("PlayerScripts") or player:WaitForChild("PlayerScripts")
	local root = ps and ps:FindFirstChild("Sounds")
	local sfx = root and root:FindFirstChild("SFX")
	local ui = sfx and sfx:FindFirstChild("UI")
	if not ui then
		return nil
	end
	local inst = ui:FindFirstChild(name)
	if inst and inst:IsA("Sound") then
		return inst
	end
	return nil
end

local function playUiSfx(name, speed)
	local tpl = getUiSfxTemplate(name)
	if not tpl then
		return
	end
	local s = tpl:Clone()
	s.Name = tpl.Name
	s.Parent = playerGui -- 2D UI sound
	if typeof(speed) == "number" and speed > 0 then
		s.PlaybackSpeed = speed
	end
	pcall(function()
		s:Play()
	end)
	s.Ended:Connect(function()
		pcall(function()
			s:Destroy()
		end)
	end)
	-- Failsafe cleanup
	task.delay(6, function()
		pcall(function()
			if s and s.Parent then
				s:Destroy()
			end
		end)
	end)
end

local function isTextObject(inst)
	return inst and (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox"))
end

local bound = setmetatable({}, { __mode = "k" })

local function updateInstance(inst)
	if not isTextObject(inst) then
		return
	end
	if CollectionService:HasTag(inst, "Coin") then
		inst.Text = CurrencyConfig.formatCoins(state.displayCoins)
		bound[inst] = true
	end
	if CollectionService:HasTag(inst, "Diamond") then
		inst.Text = CurrencyConfig.formatDiamonds(state.displayDiamonds)
		bound[inst] = true
	end
end

local function updateAll()
	for _, tag in ipairs({ "Coin", "Diamond" }) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			updateInstance(inst)
		end
	end
end

-- Hook into tag changes dynamically
local function onInstanceAdded(inst)
	updateInstance(inst)
	inst.AncestryChanged:Connect(function()
		if not inst:IsDescendantOf(game) then
			bound[inst] = nil
		end
	end)
end

CollectionService:GetInstanceAddedSignal("Coin"):Connect(onInstanceAdded)
CollectionService:GetInstanceAddedSignal("Diamond"):Connect(onInstanceAdded)

-- Initial balances request
local function syncBalances()
	local ok, result = pcall(function()
		return RequestBalances:InvokeServer()
	end)
	if ok and type(result) == "table" then
		state.coins = tonumber(result.Coins) or state.coins
		state.diamonds = tonumber(result.Diamonds) or state.diamonds
		state.displayCoins = state.coins
		state.displayDiamonds = state.diamonds
		if state.coinAnim then
			state.coinAnim.Value = state.displayCoins
		end
		if state.diamondAnim then
			state.diamondAnim.Value = state.displayDiamonds
		end
		updateAll()
	end
end

syncBalances()

-- React to server updates
CurrencyUpdated.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	local coinsTarget = nil
	if payload.Coins ~= nil then
		coinsTarget = tonumber(payload.Coins) or state.coins
		state.coins = coinsTarget
	end
	if payload.Diamonds ~= nil then
		local target = tonumber(payload.Diamonds) or state.diamonds
		state.diamonds = target
		animateDiamondsTo(target)
	end
	if payload.AwardedCoins and (payload.AwardedCoins > 0) then
		-- Visual feedback for awarded coins; increment as coins arrive
		spawnCoinBurst(payload.AwardedCoins, coinsTarget)
	else
		-- No arrival animation; tween numbers directly
		if coinsTarget ~= nil then
			animateCoinsTo(coinsTarget)
		end
	end
	updateAll()
end)

-- Run a delayed update once PlayerGui likely mounted
task.delay(0.5, updateAll)

-- VFX helpers
local function getTopScreenGui(inst)
	local cur = inst
	while cur and cur.Parent do
		if cur:IsA("ScreenGui") and cur:IsDescendantOf(playerGui) then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

local function getCoinAnchor()
	-- Prefer PlayerGui/Currency and a Coin-tagged text inside it
	local currencyGui = playerGui:FindFirstChild("Currency")
	if currencyGui and currencyGui:IsA("ScreenGui") then
		for _, inst in ipairs(CollectionService:GetTagged("Coin")) do
			if
				inst:IsDescendantOf(currencyGui)
				and inst:IsA("GuiObject")
				and inst.AbsoluteSize.X > 0
				and inst.AbsoluteSize.Y > 0
			then
				local pos = inst.AbsolutePosition
				local size = inst.AbsoluteSize
				local center = UDim2.fromOffset(pos.X + size.X * 0.5, pos.Y + size.Y * 0.5)
				return currencyGui, center, { pos = pos, size = size }, inst
			end
		end
		-- Fallback: target top-right corner within Currency gui
		local sz = currencyGui.AbsoluteSize
		return currencyGui, UDim2.fromOffset(sz.X - 60, 50), nil, nil
	end
	-- Otherwise, use the first Coin-tagged instance under PlayerGui
	local fallback = nil
	for _, inst in ipairs(CollectionService:GetTagged("Coin")) do
		if
			inst:IsDescendantOf(playerGui)
			and inst:IsA("GuiObject")
			and inst.AbsoluteSize.X > 0
			and inst.AbsoluteSize.Y > 0
		then
			local pos = inst.AbsolutePosition
			local size = inst.AbsoluteSize
			local center = UDim2.fromOffset(pos.X + size.X * 0.5, pos.Y + size.Y * 0.5)
			local gui = getTopScreenGui(inst)
			if gui then
				return gui, center, { pos = pos, size = size }, inst
			end
		end
		fallback = fallback or getTopScreenGui(inst)
	end
	-- Fallback to any ScreenGui
	local any = fallback or playerGui:FindFirstChildOfClass("ScreenGui")
	if any then
		local sz = any.AbsoluteSize
		return any, UDim2.fromOffset(sz.X - 60, 50), nil, nil
	end
	return nil, UDim2.fromOffset(0, 0), nil, nil
end

local function spawnCoinAt(parent, fromPos, toPos, baseSize, onArrive)
	local img = Instance.new("ImageLabel")
	img.Name = "CoinFly"
	img.BackgroundTransparency = 1
	img.Image = COIN_IMAGE
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Size = UDim2.fromOffset(baseSize, baseSize)
	img.Position = fromPos
	img.ImageTransparency = 1
	img.ZIndex = 20
	img.Parent = parent

	local scale = Instance.new("UIScale")
	scale.Scale = 0.4 + math.random() * 0.2
	scale.Parent = img

	local tIn = TweenInfo.new(0.12 + math.random() * 0.06, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local pop = 1.15 + math.random() * 0.2
	TweenService:Create(scale, tIn, { Scale = pop }):Play()
	TweenService:Create(img, tIn, { ImageTransparency = 0 }):Play()

	local tFly = TweenInfo.new(0.80 + math.random() * 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local mid = UDim2.fromOffset(
		(fromPos.X.Offset + toPos.X.Offset) * 0.5 + math.random(-40, 40),
		(fromPos.Y.Offset + toPos.Y.Offset) * 0.5 + math.random(-20, 30)
	)
	TweenService:Create(img, tFly, { Position = mid }):Play()
	-- finish to target and fade
	task.delay(tFly.Time, function()
		local tOut = TweenInfo.new(0.25 + math.random() * 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(img, tOut, { Position = toPos, ImageTransparency = 0.2 }):Play()
		task.delay(tOut.Time + 0.02, function()
			if type(onArrive) == "function" then
				onArrive()
			end
			img:Destroy()
		end)
	end)
end

local function bumpCoinLabel(targetInst)
	if not (targetInst and targetInst:IsA("GuiObject")) then
		return
	end
	local scaler = targetInst:FindFirstChild("_CoinBumpScale")
	if not scaler then
		scaler = Instance.new("UIScale")
		scaler.Name = "_CoinBumpScale"
		scaler.Scale = 1
		scaler.Parent = targetInst
	end
	local tIn = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tOut = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(scaler, tIn, { Scale = 1.12 }):Play()
	task.delay(tIn.Time + 0.01, function()
		TweenService:Create(scaler, tOut, { Scale = 1.0 }):Play()
	end)
	-- Green flash for dopamine, then return to original
	local isText = targetInst:IsA("TextLabel") or targetInst:IsA("TextButton") or targetInst:IsA("TextBox")
	if isText then
		baseTextColor[targetInst] = baseTextColor[targetInst] or targetInst.TextColor3
		local orig = baseTextColor[targetInst]
		local bright = Color3.fromRGB(120, 255, 150)
		local flashIn = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local flashOut = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local token = (colorToken[targetInst] or 0) + 1
		colorToken[targetInst] = token
		TweenService:Create(targetInst, flashIn, { TextColor3 = bright }):Play()
		task.delay(flashIn.Time + 0.05, function()
			if colorToken[targetInst] == token then
				TweenService:Create(targetInst, flashOut, { TextColor3 = orig }):Play()
			end
		end)
	end
end

function spawnCoinBurst(amount, finalTotal)
	local parent, target, rect, targetInst = getCoinAnchor()
	if not parent then
		return
	end
	-- Spawn sound when coins appear
	playUiSfx("CoinSpawn", 1.0)
	-- If we know the final total, let numbers rise as coins arrive
	local endTotal = tonumber(finalTotal or state.coins) or state.coins
	local startValue = math.max(0, (endTotal or 0) - (amount or 0))
	state.displayCoins = startValue
	updateAll()
	local sz = parent.AbsoluteSize
	local center = UDim2.fromOffset(sz.X * 0.5, sz.Y * 0.42)
	local count = math.clamp(math.min(amount, 18), 1, 18)
	local baseSize = 20
	-- Evenly distribute amount across coins
	local per = math.floor(amount / count)
	local remainder = amount - (per * count)
	local arrived = 0
	-- Total popup under the burst origin; stays visible until all coins arrive
	local txt = Instance.new("TextLabel")
	txt.Name = "CoinAwardText"
	txt.BackgroundTransparency = 1
	txt.Text = "+" .. tostring(amount)
	txt.Font = Enum.Font.GothamBlack
	txt.TextSize = 28
	txt.TextColor3 = Color3.fromRGB(255, 235, 120)
	txt.AnchorPoint = Vector2.new(0.5, 0.5)
	local belowCenter = UDim2.fromOffset(center.X.Offset, center.Y.Offset + 48)
	txt.Position = belowCenter
	txt.ZIndex = 21
	txt.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(40, 24, 8)
	stroke.Transparency = 0.15
	stroke.Parent = txt
	local s = Instance.new("UIScale")
	s.Scale = 0.8
	s.Parent = txt
	local tIn = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(s, tIn, { Scale = 1.12 }):Play()
	local tOut = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for i = 1, count do
		local spreadX = math.random(-120, 120)
		local spreadY = math.random(-80, 60)
		local from = UDim2.fromOffset(center.X.Offset + spreadX, center.Y.Offset + spreadY)
		local addThis = per + ((i <= remainder) and 1 or 0)
		spawnCoinAt(parent, from, target, baseSize + math.random(-4, 8), function()
			playUiSfx("CoinArrive", 1.0)
			state.displayCoins = (state.displayCoins or 0) + addThis
			updateAll()
			bumpCoinLabel(targetInst)
			arrived = arrived + 1
			if arrived == count then
				state.displayCoins = endTotal
				updateAll()
				-- Ensure final color is restored to the original base color
				if
					targetInst
					and (targetInst:IsA("TextLabel") or targetInst:IsA("TextButton") or targetInst:IsA("TextBox"))
				then
					local base = baseTextColor and baseTextColor[targetInst]
					if base then
						targetInst.TextColor3 = base
					end
				end
				-- Fade and cleanup popup now that all coins have arrived
				local endPos = UDim2.fromOffset(belowCenter.X.Offset, belowCenter.Y.Offset - 18)
				if txt and txt.Parent then
					TweenService:Create(txt, tOut, { TextTransparency = 1, Position = endPos }):Play()
				end
				if stroke and stroke.Parent then
					TweenService:Create(stroke, tOut, { Transparency = 1 }):Play()
				end
				task.delay(tOut.Time + 0.02, function()
					if txt and txt.Parent then
						txt:Destroy()
					end
				end)
			end
		end)
	end
end

-- Animated value helpers
local function ensureAnimValues()
	if not state.coinAnim then
		local nv = Instance.new("NumberValue")
		nv.Value = state.displayCoins or 0
		nv:GetPropertyChangedSignal("Value"):Connect(function()
			state.displayCoins = math.floor(nv.Value + 0.5)
			updateAll()
		end)
		state.coinAnim = nv
	end
	if not state.diamondAnim then
		local nv = Instance.new("NumberValue")
		nv.Value = state.displayDiamonds or 0
		nv:GetPropertyChangedSignal("Value"):Connect(function()
			state.displayDiamonds = math.floor(nv.Value + 0.5)
			updateAll()
		end)
		state.diamondAnim = nv
	end
end

function animateCoinsTo(target)
	ensureAnimValues()
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(state.coinAnim, info, { Value = tonumber(target) or 0 }):Play()
end

function animateDiamondsTo(target)
	ensureAnimValues()
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(state.diamondAnim, info, { Value = tonumber(target) or 0 }):Play()
end
