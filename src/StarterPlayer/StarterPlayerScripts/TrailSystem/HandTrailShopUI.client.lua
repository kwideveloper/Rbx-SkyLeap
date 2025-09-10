-- Client-side hand trail shop UI system
-- Handles hand trail purchasing, equipping, and UI updates using existing template

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Hide Hand trail template
local handTrailTemplate = playerGui
	:WaitForChild("Shop").CanvasGroup.Frame.Content.Cosmetics.Hands.ScrollingFrame
	:FindFirstChild("Template", true)
handTrailTemplate.Visible = false

-- Wait for modules
local HandTrailConfig =
	require(ReplicatedStorage:WaitForChild("Cosmetics"):WaitForChild("TrailSystem"):WaitForChild("HandTrailConfig"))

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PurchaseHandTrail = Remotes:WaitForChild("PurchaseHandTrail")
local EquipHandTrail = Remotes:WaitForChild("EquipHandTrail")
local GetHandTrailData = Remotes:WaitForChild("GetHandTrailData")
local HandTrailEquipped = Remotes:WaitForChild("HandTrailEquipped")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI State
local shopUI = nil
local handTrailFrames = {}
local currentEquippedHandTrail = "default"
local ownedHandTrails = {}
local allHandTrails = {}

-- Purchase protection
local purchaseInProgress = {}
local equipInProgress = {}
local PURCHASE_COOLDOWN = 2 -- 2 seconds cooldown between purchases

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

-- Helper function to create hand trail frame UI using existing template
local function createHandTrailFrame(trailData, parent)
	-- Find the template
	local template = parent:FindFirstChild("Template", true)
	if not template then
		warn("Hand trail template not found in Hands folder!")
		return nil
	end

	-- Clone the template
	local frame = template:Clone()
	frame.Name = "HandTrailFrame_" .. trailData.id
	frame.Visible = false -- Will be made visible when data is loaded
	frame.Parent = parent

	-- Update trail name
	local nameLabel = frame:FindFirstChild("Name")
	if nameLabel then
		nameLabel.Text = trailData.name
		-- Apply rarity color to name background
		nameLabel.BackgroundColor3 = HandTrailConfig.RarityColors[trailData.rarity] or Color3.fromRGB(255, 255, 255)
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
			rarity.TextColor3 = HandTrailConfig.RarityColors[trailData.rarity] or Color3.fromRGB(255, 255, 255)
		end
	end

	-- Get buttons
	local buyButton = frame:FindFirstChild("Buy")
	local equipButton = frame:FindFirstChild("Equip")

	return frame, buyButton, equipButton
end

-- Update hand trail frame based on ownership and equipment status
local function updateHandTrailFrame(trailId, frame)
	local trailData = HandTrailConfig.getHandTrailById(trailId)
	if not trailData or not frame then
		return
	end

	local isOwned = ownedHandTrails[trailId] or false
	local isEquipped = (currentEquippedHandTrail == trailId)

	-- Default trail is always owned, but only equipped if it's the current equipped trail
	if trailId == "default" then
		isOwned = true
		-- Don't force isEquipped = true, let it be determined by currentEquippedHandTrail
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

-- Handle hand trail purchase
local function purchaseHandTrail(trailId)
	local trailData = HandTrailConfig.getHandTrailById(trailId)
	if not trailData then
		return
	end

	-- Check if purchase is already in progress for this trail
	if purchaseInProgress[trailId] then
		print("Hand trail purchase already in progress for " .. trailData.name)
		return
	end

	-- Check if trail is already owned
	if ownedHandTrails[trailId] then
		print("Hand trail " .. trailData.name .. " is already owned")
		return
	end

	-- Get frame reference
	local frame = handTrailFrames[trailId]
	if not frame then
		warn("Frame not found for hand trail: " .. trailId)
		return
	end

	-- Mark purchase as in progress
	purchaseInProgress[trailId] = true

	-- Update button to show loading state
	local buyButton = frame:FindFirstChild("Buy")
	if buyButton then
		buyButton.Text = "Purchasing..."
		buyButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		buyButton.Active = false -- Disable button during purchase
	end

	-- Call server
	local success, result = pcall(function()
		return PurchaseHandTrail:InvokeServer(trailId)
	end)

	-- Clear purchase in progress flag
	purchaseInProgress[trailId] = nil

	if success and result.success then
		-- Update local state
		ownedHandTrails[trailId] = true
		updateHandTrailFrame(trailId, frame)

		-- Show success message
		print("Successfully purchased " .. trailData.name .. " hand trail!")
	else
		-- Show error message
		local errorMsg = result and result.reason or "Purchase failed"
		print("Hand trail purchase failed: " .. errorMsg)

		-- Reset button state
		if buyButton then
			buyButton.Text = "Buy"
			buyButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
			buyButton.Active = true -- Re-enable button
		end
	end
end

-- Handle hand trail equipment
local function equipHandTrail(trailId)
	local trailData = HandTrailConfig.getHandTrailById(trailId)
	if not trailData then
		return
	end

	-- Check if already equipped
	if currentEquippedHandTrail == trailId then
		print("Hand trail " .. trailData.name .. " is already equipped")
		return
	end

	-- Check if equipment is already in progress for this trail
	if equipInProgress[trailId] then
		print("Hand trail equipment already in progress for " .. trailData.name)
		return
	end

	-- Get frame reference
	local frame = handTrailFrames[trailId]
	if not frame then
		warn("Frame not found for hand trail: " .. trailId)
		return
	end

	-- Mark equipment as in progress
	equipInProgress[trailId] = true

	-- Update button to show loading state
	local equipButton = frame:FindFirstChild("Equip")
	if equipButton then
		equipButton.Text = "Equipping..."
		equipButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		equipButton.Active = false -- Disable button during equipment
	end

	-- Call server
	local success, result = pcall(function()
		return EquipHandTrail:InvokeServer(trailId)
	end)

	-- Clear equipment in progress flag
	equipInProgress[trailId] = nil

	if success and result.success then
		-- Update local state
		currentEquippedHandTrail = trailId

		-- Update all frames
		for id, frame in pairs(handTrailFrames) do
			updateHandTrailFrame(id, frame)
		end

		-- Show success message
		print("Successfully equipped " .. trailData.name .. " hand trail!")
	else
		-- Show error message
		local errorMsg = result and result.reason or "Equipment failed"
		print("Hand trail equipment failed: " .. errorMsg)

		-- Reset button state
		if equipButton then
			equipButton.Text = "Equip"
			equipButton.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
			equipButton.Active = true -- Re-enable button
		end
	end
end

-- Initialize hand trail shop UI
local function initializeHandTrailShop()
	-- Find the shop UI
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

	local cosmetics = content:FindFirstChild("Cosmetics")
	if not cosmetics then
		warn("Shop Cosmetics not found!")
		return
	end

	local hands = cosmetics:FindFirstChild("Hands")
	if not hands then
		warn("Shop Hands not found!")
		return
	end

	local handsScrollingFrame = hands:FindFirstChild("ScrollingFrame")
	if not handsScrollingFrame then
		warn("Shop Hands ScrollingFrame not found!")
		return
	end

	-- Store references for later use
	shopUI = {
		shop = shop,
		canvasGroup = canvasGroup,
		mainFrame = mainFrame,
		content = content,
		cosmetics = cosmetics,
		hands = hands,
		handsScrollingFrame = handsScrollingFrame,
	}

	-- Clear existing hand trail frames
	for _, child in ipairs(handsScrollingFrame:GetChildren()) do
		if child.Name:find("HandTrailFrame_") then
			child:Destroy()
		end
	end
end

-- Create hand trail frames after data is loaded
local function createHandTrailFrames()
	if not shopUI or not shopUI.handsScrollingFrame then
		warn("Hand trail shop UI not initialized!")
		return
	end

	local handsScrollingFrame = shopUI.handsScrollingFrame

	-- Create hand trail frames for each hand trail
	for _, trailData in ipairs(HandTrailConfig.HandTrails) do
		local frame, buyButton, equipButton = createHandTrailFrame(trailData, handsScrollingFrame)
		if frame then
			handTrailFrames[trailData.id] = frame

			-- Connect button events
			if buyButton then
				buyButton.MouseButton1Click:Connect(function()
					purchaseHandTrail(trailData.id)
				end)
			end

			if equipButton then
				equipButton.MouseButton1Click:Connect(function()
					equipHandTrail(trailData.id)
				end)
			end
		end
	end
end

-- Load hand trail data from server
local function loadHandTrailData()
	local success, result = pcall(function()
		return GetHandTrailData:InvokeServer()
	end)

	if success and result.success then
		-- Update local state
		ownedHandTrails = {}
		for _, trailId in ipairs(result.ownedHandTrails) do
			ownedHandTrails[trailId] = true
		end
		-- Always ensure default trail is owned
		ownedHandTrails["default"] = true
		currentEquippedHandTrail = result.equippedHandTrail or "default"

		-- Create frames now that we have data
		createHandTrailFrames()

		-- Update all frames and make them visible
		for trailId, frame in pairs(handTrailFrames) do
			updateHandTrailFrame(trailId, frame)
			-- Show the frame now that data is loaded
			frame.Visible = true
		end
	else
		warn("Failed to load hand trail data: " .. (result and result.reason or "Unknown error"))
		-- Create frames anyway with default state if server data fails
		createHandTrailFrames()
		for trailId, frame in pairs(handTrailFrames) do
			updateHandTrailFrame(trailId, frame)
			frame.Visible = true
		end
	end
end

-- Listen for hand trail equipment updates
HandTrailEquipped.OnClientEvent:Connect(function(player, trailId)
	-- Only update if it's for the local player
	if player == Players.LocalPlayer then
		currentEquippedHandTrail = trailId

		-- Update all frames
		for id, frame in pairs(handTrailFrames) do
			updateHandTrailFrame(id, frame)
		end
	end
end)

-- Initialize when player data is ready
local function onPlayerDataReady()
	-- Reduce wait time - only wait for essential systems
	task.wait(0.5)
	initializeHandTrailShop()

	-- Load data immediately after UI is created
	task.wait(0.2)
	loadHandTrailData()
end

-- Start initialization
if player.Character then
	onPlayerDataReady()
else
	player.CharacterAdded:Connect(onPlayerDataReady)
end
