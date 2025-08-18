-- Prototype In-Game Shop (UI + client logic)
-- Note: This prototype builds the full UI at runtime for quick iteration.
-- In production, you can replace dynamic creation with prebuilt UI and keep the logic.
-- Server integration: expects Remotes in ReplicatedStorage/Remotes (see below).

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Remotes (to be provided in the experience; referenced-only here)
-- Expected:
-- Remotes.ShopGetCatalog (RemoteFunction) -> returns { items = { ... }, currencies = { Coins=number, Premium=number }, owned = { [itemId]=true }, equipped = { [slot]=itemId } }
-- Remotes.ShopPurchase (RemoteFunction) -> args: itemId, returns { ok=true, currencies, owned }
-- Remotes.ShopEquip (RemoteFunction) -> args: itemId, returns { ok=true, equipped }
-- Remotes.ShopServerPush (RemoteEvent) -> server-to-client inventory/currency updates (optional)
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local RF_GetCatalog = Remotes and Remotes:FindFirstChild("ShopGetCatalog")
local RF_Purchase = Remotes and Remotes:FindFirstChild("ShopPurchase")
local RF_Equip = Remotes and Remotes:FindFirstChild("ShopEquip")
local RE_Push = Remotes and Remotes:FindFirstChild("ShopServerPush")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Theme
local Theme = {
	Bg = Color3.fromRGB(16, 18, 24),
	Panel = Color3.fromRGB(26, 30, 38),
	Panel2 = Color3.fromRGB(32, 38, 48),
	Accent = Color3.fromRGB(90, 170, 255),
	Accent2 = Color3.fromRGB(255, 100, 180),
	Text = Color3.fromRGB(230, 240, 255),
	TextDim = Color3.fromRGB(150, 165, 190),
	Good = Color3.fromRGB(60, 200, 120),
	Warn = Color3.fromRGB(245, 180, 60),
	Bad = Color3.fromRGB(230, 80, 80),
}

-- Local state (synced with server when available)
local Catalog = {
	-- Minimal sample data for offline demo (server can override completely)
	items = {
		{
			id = "skin_neon",
			name = "Neon Runner",
			price = 800,
			currency = "Coins",
			type = "Skins",
			rarity = "Epic",
			desc = "Futuristic neon outfit.",
		},
		{
			id = "trail_ion",
			name = "Ion Trail",
			price = 300,
			currency = "Coins",
			type = "Trails",
			rarity = "Rare",
			desc = "Electric ionized trail.",
		},
		{
			id = "emote_flip",
			name = "Flip Emote",
			price = 120,
			currency = "Coins",
			type = "Emotes",
			rarity = "Common",
			desc = "Show off with a flip!",
		},
		{
			id = "boost_x2",
			name = "2x Style 10m",
			price = 40,
			currency = "Premium",
			type = "Boosts",
			rarity = "Epic",
			desc = "Double style gain for 10 minutes.",
		},
		{
			id = "power_dash",
			name = "Dash Charge+1",
			price = 500,
			currency = "Coins",
			type = "Powerups",
			rarity = "Legendary",
			desc = "+1 air dash charge permanently.",
		},
	},
	currencies = { Coins = 1000, Premium = 20 },
	owned = {},
	equipped = {},
}

local UI = {
	gui = nil,
	root = nil,
	tabs = {},
	currentTab = "All",
	searchText = "",
	grid = nil,
	itemTemplate = nil,
	detail = {},
	currency = {},
}

-- Utilities
local function make(instance, props, children)
	local obj = Instance.new(instance)
	for k, v in pairs(props or {}) do
		obj[k] = v
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	return obj
end

local function uiStroke(parent, thickness, color, trans)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 1
	s.Color = color or Theme.Accent
	s.Transparency = trans or 0
	s.Parent = parent
	return s
end

local function uiCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

-- Data accessors
local function getFilteredItems()
	local list = {}
	local activeTab = UI.currentTab or "All"
	local search = string.lower(UI.searchText or "")
	for _, it in ipairs(Catalog.items or {}) do
		local okTab = (activeTab == "All") or (it.type == activeTab)
		local okText = (search == "") or string.find(string.lower(it.name), search, 1, true)
		if okTab and okText then
			table.insert(list, it)
		end
	end
	-- sort by rarity then price ascending
	local rarityRank = { Common = 1, Rare = 2, Epic = 3, Legendary = 4 }
	table.sort(list, function(a, b)
		local ra, rb = rarityRank[a.rarity] or 0, rarityRank[b.rarity] or 0
		if ra ~= rb then
			return ra > rb
		end
		return (a.price or 0) < (b.price or 0)
	end)
	return list
end

local function refreshCurrencies()
	if UI.currency.coins then
		UI.currency.coins.Text = tostring(Catalog.currencies.Coins or 0)
	end
	if UI.currency.premium then
		UI.currency.premium.Text = tostring(Catalog.currencies.Premium or 0)
	end
end

-- Server sync (safe fallbacks)
local function serverFetch()
	if RF_GetCatalog and RF_GetCatalog:IsA("RemoteFunction") then
		local ok, res = pcall(function()
			return RF_GetCatalog:InvokeServer()
		end)
		if ok and typeof(res) == "table" then
			Catalog.items = res.items or Catalog.items
			Catalog.currencies = res.currencies or Catalog.currencies
			Catalog.owned = res.owned or Catalog.owned
			Catalog.equipped = res.equipped or Catalog.equipped
		end
	end
end

local function serverPurchase(item)
	if not item then
		return
	end
	if RF_Purchase and RF_Purchase:IsA("RemoteFunction") then
		local ok, res = pcall(function()
			return RF_Purchase:InvokeServer(item.id)
		end)
		if ok and typeof(res) == "table" and res.ok then
			Catalog.currencies = res.currencies or Catalog.currencies
			Catalog.owned[item.id] = true
			refreshCurrencies()
			return true
		end
		return false
	else
		-- Offline demo: spend locally if enough
		local bal = Catalog.currencies[item.currency] or 0
		if bal >= (item.price or 0) then
			Catalog.currencies[item.currency] = bal - (item.price or 0)
			Catalog.owned[item.id] = true
			refreshCurrencies()
			return true
		end
		return false
	end
end

local function serverEquip(item)
	if not item then
		return
	end
	if RF_Equip and RF_Equip:IsA("RemoteFunction") then
		local ok, res = pcall(function()
			return RF_Equip:InvokeServer(item.id)
		end)
		if ok and typeof(res) == "table" and res.ok then
			Catalog.equipped = res.equipped or Catalog.equipped
			return true
		end
		return false
	else
		-- Offline: mark as equipped in slot by type
		Catalog.equipped[item.type] = item.id
		return true
	end
end

-- UI Builders
local function buildHeader(parent)
	local header = make("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = parent,
	})
	uiCorner(header, 10)
	uiStroke(header, 1, Theme.Panel2, 0.3)

	local title = make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.4, 0, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		Text = "SkyLeap Shop",
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})

	local coinsIcon = make("ImageLabel", {
		Name = "CoinsIcon",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 22, 0, 22),
		Position = UDim2.new(1, -220, 0.5, -11),
		Image = "rbxassetid://6035052237",
		ImageColor3 = Theme.Warn,
		Parent = header,
	})
	local coinsLabel = make("TextLabel", {
		Name = "Coins",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 80, 0, 24),
		Position = UDim2.new(1, -190, 0.5, -12),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Text,
		Text = "0",
		Parent = header,
	})
	UI.currency.coins = coinsLabel

	local premIcon = make("ImageLabel", {
		Name = "PremIcon",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 22, 0, 22),
		Position = UDim2.new(1, -110, 0.5, -11),
		Image = "rbxassetid://6035053640",
		ImageColor3 = Theme.Accent2,
		Parent = header,
	})
	local premLabel = make("TextLabel", {
		Name = "Premium",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 60, 0, 24),
		Position = UDim2.new(1, -80, 0.5, -12),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Text,
		Text = "0",
		Parent = header,
	})
	UI.currency.premium = premLabel

	local closeBtn = make("TextButton", {
		Name = "Close",
		Size = UDim2.new(0, 36, 0, 36),
		Position = UDim2.new(1, -44, 0.5, -18),
		BackgroundColor3 = Theme.Panel2,
		Text = "✕",
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.Text,
		Parent = header,
	})
	uiCorner(closeBtn, 8)
	uiStroke(closeBtn, 1, Theme.Panel, 0.4)
	closeBtn.MouseButton1Click:Connect(function()
		if UI.gui then
			UI.gui.Enabled = false
		end
	end)

	return header
end

local function buildTabs(parent)
	local bar = make("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.new(0, 0, 0, 60),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local cats = { "All", "Skins", "Trails", "Emotes", "Boosts", "Powerups" }
	local x = 12
	for _, name in ipairs(cats) do
		local btn = make("TextButton", {
			Name = name,
			BackgroundColor3 = Theme.Panel,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 120, 0, 34),
			Position = UDim2.new(0, x, 0, 0),
			Text = name,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = Theme.TextDim,
			Parent = bar,
		})
		uiCorner(btn, 8)
		uiStroke(btn, 1, Theme.Panel2, 0.3)
		btn.MouseButton1Click:Connect(function()
			UI.currentTab = name
			for _, b in pairs(UI.tabs) do
				b.TextColor3 = Theme.TextDim
				b.BackgroundColor3 = Theme.Panel
			end
			btn.TextColor3 = Theme.Text
			btn.BackgroundColor3 = Theme.Panel2
			-- refresh grid
			if UI.grid then
				UI.grid:ClearAllChildren()
			end
			UI.itemTemplate = nil
			RunService.Heartbeat:Wait()
			-- repopulate
			local items = getFilteredItems()
			for _, it in ipairs(items) do
				local card = UI.itemTemplate and UI.itemTemplate:Clone() or nil
				if not card then
					card = make("Frame", {
						Name = "Card",
						Size = UDim2.new(0, 190, 0, 220),
						BackgroundColor3 = Theme.Panel,
						BorderSizePixel = 0,
						Parent = UI.grid,
					})
					uiCorner(card, 10)
					uiStroke(card, 1, Theme.Panel2, 0.4)
					local nameL = make("TextLabel", {
						Name = "Name",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, -16, 0, 22),
						Position = UDim2.new(0, 8, 0, 10),
						Font = Enum.Font.GothamBold,
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = Theme.Text,
						Text = "",
						Parent = card,
					})
					local image = make("ImageLabel", {
						Name = "Icon",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, -20, 0, 120),
						Position = UDim2.new(0, 10, 0, 40),
						Image = "rbxassetid://6034767617",
						ImageColor3 = Theme.Accent,
						Parent = card,
					})
					local price = make("TextLabel", {
						Name = "Price",
						BackgroundTransparency = 1,
						Size = UDim2.new(1, -16, 0, 22),
						Position = UDim2.new(0, 8, 1, -30),
						Font = Enum.Font.GothamBold,
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = Theme.Text,
						Text = "",
						Parent = card,
					})
					local buy = make("TextButton", {
						Name = "Buy",
						BackgroundColor3 = Theme.Accent,
						Size = UDim2.new(0, 64, 0, 26),
						Position = UDim2.new(1, -72, 1, -34),
						Text = "Buy",
						TextSize = 14,
						Font = Enum.Font.GothamBold,
						TextColor3 = Color3.new(1, 1, 1),
						Parent = card,
					})
					uiCorner(buy, 6)
					UI.itemTemplate = card:Clone()
				end
				card.Name = "Card_" .. it.id
				card.Parent = UI.grid
				card.Name.Text = it.name
				card.Price.Text = string.format("%s %d", it.currency == "Premium" and "★" or "●", it.price)
				local owned = Catalog.owned[it.id] == true
				card.Buy.Text = owned and "Equip" or "Buy"
				card.Buy.BackgroundColor3 = owned and Theme.Good or Theme.Accent
				card.Buy.MouseButton1Click:Connect(function()
					if Catalog.owned[it.id] then
						if serverEquip(it) then
							-- brief pulse
							TweenService:Create(card.Buy, TweenInfo.new(0.15), { BackgroundColor3 = Theme.Panel2 })
								:Play()
							task.delay(0.16, function()
								card.Buy.BackgroundColor3 = Theme.Good
							end)
						end
					else
						if serverPurchase(it) then
							card.Buy.Text = "Equip"
							card.Buy.BackgroundColor3 = Theme.Good
						else
							TweenService:Create(card.Buy, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Bad }):Play()
							task.delay(0.12, function()
								card.Buy.BackgroundColor3 = Theme.Accent
							end)
						end
					end
				end)
			end
		end)
		UI.tabs[name] = btn
		x = x + 128
	end
	-- Activate initial tab
	if UI.tabs[UI.currentTab] then
		UI.tabs[UI.currentTab].MouseButton1Click:Fire()
	end
	return bar
end

local function buildSearch(parent)
	local bar = make("TextBox", {
		Name = "Search",
		Size = UDim2.new(0, 280, 0, 30),
		Position = UDim2.new(0, 16, 0, 104),
		BackgroundColor3 = Theme.Panel,
		Text = "",
		PlaceholderText = "Search items...",
		TextSize = 16,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.TextDim,
		Parent = parent,
	})
	uiCorner(bar, 8)
	uiStroke(bar, 1, Theme.Panel2, 0.3)
	bar.FocusLost:Connect(function()
		UI.searchText = bar.Text or ""
		-- simulate clicking current tab to refresh
		if UI.tabs[UI.currentTab] then
			UI.tabs[UI.currentTab].MouseButton1Click:Fire()
		end
	end)
	return bar
end

local function buildGrid(parent)
	local gridHolder = make("Frame", {
		Name = "GridHolder",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 144),
		Size = UDim2.new(1, -32, 1, -160),
		Parent = parent,
	})
	local scroller = make("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 6,
		Parent = gridHolder,
	})
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 190, 0, 220)
	layout.CellPadding = UDim2.new(0, 12, 0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroller
	scroller.ChildAdded:Connect(function()
		RunService.Heartbeat:Wait()
		local content = layout.AbsoluteContentSize
		scroller.CanvasSize = UDim2.new(0, 0, 0, content.Y + 12)
	end)
	UI.grid = scroller
	return scroller
end

local function buildRoot()
	local gui = make("ScreenGui", {
		Name = "ShopUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = playerGui,
	})

	local root = make("Frame", {
		Name = "Root",
		Size = UDim2.new(0, 900, 0, 600),
		Position = UDim2.new(0.5, -450, 0.5, -300),
		BackgroundColor3 = Theme.Bg,
		BorderSizePixel = 0,
		Parent = gui,
	})
	uiCorner(root, 12)
	uiStroke(root, 1, Theme.Panel2, 0.4)

	UI.gui = gui
	UI.root = root

	buildHeader(root)
	buildTabs(root)
	buildSearch(root)
	buildGrid(root)

	return gui
end

-- Toggle binds
local function toggle()
	if not UI.gui then
		buildRoot()
	end
	if UI.gui then
		UI.gui.Enabled = not UI.gui.Enabled
		if UI.gui.Enabled then
			serverFetch()
			refreshCurrencies()
			-- refresh grid via current tab
			if UI.tabs[UI.currentTab] then
				UI.tabs[UI.currentTab].MouseButton1Click:Fire()
			end
		end
	end
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		toggle()
	end
end)

-- Server push hook (optional)
if RE_Push and RE_Push:IsA("RemoteEvent") then
	RE_Push.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" then
			if payload.currencies then
				Catalog.currencies = payload.currencies
				refreshCurrencies()
			end
			if payload.owned then
				Catalog.owned = payload.owned
			end
			if payload.equipped then
				Catalog.equipped = payload.equipped
			end
			-- refresh visible grid
			if UI.tabs[UI.currentTab] then
				UI.tabs[UI.currentTab].MouseButton1Click:Fire()
			end
		end
	end)
end

-- Auto-build quietly (kept disabled by default). Press B to open.
buildRoot()
