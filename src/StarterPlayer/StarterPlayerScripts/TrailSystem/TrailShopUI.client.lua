-- Client-side trail shop UI system
-- Handles trail purchasing, equipping, and UI updates

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Hide Trail template
local trailTemplate = playerGui:WaitForChild("Shop").CanvasGroup.Frame.Content.Cosmetics.Core.Template
trailTemplate.Visible = false

-- Wait for modules
local TrailConfig =
	require(ReplicatedStorage:WaitForChild("Cosmetics"):WaitForChild("TrailSystem"):WaitForChild("TrailConfig"))

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PurchaseTrail = Remotes:WaitForChild("PurchaseTrail")
local EquipTrail = Remotes:WaitForChild("EquipTrail")
local GetTrailData = Remotes:WaitForChild("GetTrailData")
local TrailEquipped = Remotes:WaitForChild("TrailEquipped")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI State
local shopUI = nil
local trailFrames = {}
local currentEquippedTrail = "default"
local ownedTrails = {}
local allTrails = {}

-- Animation settings
local ANIMATION_DURATION = 0.3
local TWEEN_INFO = TweenInfo.new(ANIMATION_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Helper function to find UI elements
local function findUIElement(parent, name)
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name then
			return child
		end
	end
	return nil
end

-- Helper function to create trail frame UI using existing template
local function createTrailFrame(trailData, parent)
	-- Find the template
	local template = parent:FindFirstChild("Template")
	if not template then
		warn("Template not found in Cosmetics folder!")
		return nil
	end

	-- Clone the template
	local frame = template:Clone()
	frame.Name = "TrailFrame_" .. trailData.id
	frame.Visible = false -- Will be made visible when data is loaded
	frame.Parent = parent

	-- Update trail name
	local nameLabel = frame:FindFirstChild("Name")
	if nameLabel then
		nameLabel.Text = trailData.name
		-- Apply rarity color to name background
		nameLabel.BackgroundColor3 = TrailConfig.RarityColors[trailData.rarity] or Color3.fromRGB(255, 255, 255)
	end

	-- Update trail color
	local colorFrame = frame:FindFirstChild("Frame")
	if colorFrame then
		local colorElement = colorFrame:FindFirstChild("Color")
		if colorElement then
			colorElement.BackgroundColor3 = trailData.color
		end
	end

	-- Update price
	local info = frame:FindFirstChild("Info")
	if info then
		local price = info:FindFirstChild("Price")
		if price then
			local priceLabel = price:FindFirstChild("TextLabel")
			if priceLabel then
				priceLabel.Text = tostring(trailData.price)
			end

			-- Update currency icons
			local coinsIcon = price:FindFirstChild("Coins")
			local diamondsIcon = price:FindFirstChild("Diamonds")

			if coinsIcon and diamondsIcon then
				-- Hide both icons first
				coinsIcon.Visible = false
				diamondsIcon.Visible = false

				-- Show the appropriate icon based on currency
				if trailData.currency == "Coins" then
					coinsIcon.Visible = true
				elseif trailData.currency == "Diamonds" then
					diamondsIcon.Visible = true
				end
			end
		end

		-- Update rarity
		local rarity = info:FindFirstChild("Rarity")
		if rarity then
			rarity.Text = trailData.rarity
			rarity.TextColor3 = TrailConfig.RarityColors[trailData.rarity] or Color3.fromRGB(255, 255, 255)
		end
	end

	-- Get buttons
	local buyButton = frame:FindFirstChild("Buy")
	local equipButton = frame:FindFirstChild("Equip")

	return frame, buyButton, equipButton
end

-- Update trail frame based on ownership and equipment status
local function updateTrailFrame(trailId, frame)
	local trailData = TrailConfig.getTrailById(trailId)
	if not trailData or not frame then
		return
	end

	local isOwned = ownedTrails[trailId] or false
	local isEquipped = (currentEquippedTrail == trailId)

	-- Default trail is always owned, but only equipped if it's the current equipped trail
	if trailId == "default" then
		isOwned = true
		-- Don't force isEquipped = true, let it be determined by currentEquippedTrail
	end

	local buyButton = frame:FindFirstChild("Buy")
	local equipButton = frame:FindFirstChild("Equip")

	-- Hide/show price section based on ownership
	local info = frame:FindFirstChild("Info")
	if info then
		local price = info:FindFirstChild("Price")
		if price then
			-- Hide price section if owned (including default trail)
			price.Visible = not isOwned
		end
	end

	if buyButton and equipButton then
		if isOwned then
			-- Owned: hide buy button, show equip button
			buyButton.Visible = false
			equipButton.Visible = true

			if isEquipped then
				equipButton.Text = "Equipped"
				equipButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			else
				equipButton.Text = "Equip"
				equipButton.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
			end
		else
			-- Not owned: show buy button, hide equip button
			buyButton.Visible = true
			equipButton.Visible = false
		end
	end
end

-- Handle trail purchase
local function purchaseTrail(trailId)
	local trailData = TrailConfig.getTrailById(trailId)
	if not trailData then
		return
	end

	-- Get frame reference
	local frame = trailFrames[trailId]

	-- Call server
	local success, result = pcall(function()
		return PurchaseTrail:InvokeServer(trailId)
	end)

	if success and result.success then
		-- Update local state
		ownedTrails[trailId] = true
		updateTrailFrame(trailId, frame)
	else
		-- Show error message
		local errorMsg = result and result.reason or "Purchase failed"
		print("Purchase failed: " .. errorMsg)

		-- Reset button state
		if frame then
			local buyButton = frame:FindFirstChild("Buy")
			if buyButton then
				buyButton.Text = "Buy"
				buyButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
			end
		end
	end
end

-- Handle trail equipment
local function equipTrail(trailId)
	local trailData = TrailConfig.getTrailById(trailId)
	if not trailData then
		return
	end

	-- Get frame reference
	local frame = trailFrames[trailId]

	-- Call server
	local success, result = pcall(function()
		return EquipTrail:InvokeServer(trailId)
	end)

	if success and result.success then
		-- Update local state
		currentEquippedTrail = trailId

		-- Trail is automatically saved on server side

		-- Update all frames
		for id, frame in pairs(trailFrames) do
			updateTrailFrame(id, frame)
		end

		-- Show success message
		print("Successfully equipped " .. trailData.name .. "!")
	else
		-- Show error message
		local errorMsg = result and result.reason or "Equipment failed"
		print("Equipment failed: " .. errorMsg)

		-- Reset button state
		if frame then
			local equipButton = frame:FindFirstChild("Equip")
			if equipButton then
				equipButton.Text = "Equip"
				equipButton.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
			end
		end
	end
end

-- Initialize trail shop UI
local function initializeTrailShop()
	-- Find the shop UI (assuming it exists as shown in the image)
	local shop = playerGui:FindFirstChild("Shop")
	if not shop then
		warn("Shop UI not found! Please ensure the Shop UI exists in PlayerGui")
		return
	end

	local canvasGroup = shop:FindFirstChild("CanvasGroup")
	if not canvasGroup then
		warn("Shop CanvasGroup not found!")
		return
	end

	local mainFrame = canvasGroup:FindFirstChild("Frame")
	if not mainFrame then
		warn("Shop main Frame not found!")
		return
	end

	local content = mainFrame:FindFirstChild("Content")
	if not content then
		warn("Shop Content not found!")
		return
	end

	local cosmetics = content:FindFirstChild("Cosmetics").Core
	if not cosmetics then
		warn("Shop Cosmetics not found!")
		return
	end

	-- Store references for later use
	shopUI = {
		shop = shop,
		canvasGroup = canvasGroup,
		mainFrame = mainFrame,
		content = content,
		cosmetics = cosmetics,
	}

	-- Clear existing trail frames
	for _, child in ipairs(cosmetics:GetChildren()) do
		if child.Name:find("TrailFrame_") then
			child:Destroy()
		end
	end
end

-- Create trail frames after data is loaded
local function createTrailFrames()
	if not shopUI or not shopUI.cosmetics then
		warn("Shop UI not initialized!")
		return
	end

	local cosmetics = shopUI.cosmetics

	-- Create trail frames for each trail
	for _, trailData in ipairs(TrailConfig.Trails) do
		local frame, buyButton, equipButton = createTrailFrame(trailData, cosmetics)
		if frame then
			trailFrames[trailData.id] = frame

			-- Connect button events
			if buyButton then
				buyButton.MouseButton1Click:Connect(function()
					purchaseTrail(trailData.id)
				end)
			end

			if equipButton then
				equipButton.MouseButton1Click:Connect(function()
					equipTrail(trailData.id)
				end)
			end
		end
	end
end

-- Load trail data from server
local function loadTrailData()
	local success, result = pcall(function()
		return GetTrailData:InvokeServer()
	end)

	if success and result.success then
		-- Update local state
		ownedTrails = {}
		for _, trailId in ipairs(result.ownedTrails) do
			ownedTrails[trailId] = true
		end
		-- Always ensure default trail is owned
		ownedTrails["default"] = true
		currentEquippedTrail = result.equippedTrail or "default"

		-- Create frames now that we have data
		createTrailFrames()

		-- Update all frames and make them visible
		for trailId, frame in pairs(trailFrames) do
			updateTrailFrame(trailId, frame)
			-- Show the frame now that data is loaded
			frame.Visible = true
		end
	else
		warn("Failed to load trail data: " .. (result and result.reason or "Unknown error"))
		-- Create frames anyway with default state if server data fails
		createTrailFrames()
		for trailId, frame in pairs(trailFrames) do
			updateTrailFrame(trailId, frame)
			frame.Visible = true
		end
	end
end

-- Listen for trail equipment updates
TrailEquipped.OnClientEvent:Connect(function(player, trailId)
	-- Only update if it's for the local player
	if player == Players.LocalPlayer then
		currentEquippedTrail = trailId

		-- Update all frames
		for id, frame in pairs(trailFrames) do
			updateTrailFrame(id, frame)
		end
	end
end)

-- Initialize when player data is ready
local function onPlayerDataReady()
	-- Reduce wait time - only wait for essential systems
	task.wait(0.5)
	initializeTrailShop()

	-- Load data immediately after UI is created
	task.wait(0.2)
	loadTrailData()
end

-- Start initialization
if player.Character then
	onPlayerDataReady()
else
	player.CharacterAdded:Connect(onPlayerDataReady)
end
