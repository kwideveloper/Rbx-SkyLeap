-- TrailManager.client.lua
-- Manages both Core and Hands trails independently
-- Handles purchasing, equipping, and UI updates for both trail types

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TrailManager = {}

-- Wait for modules
local UnifiedTrailConfig =
	require(ReplicatedStorage:WaitForChild("Cosmetics"):WaitForChild("TrailSystem"):WaitForChild("UnifiedTrailConfig"))

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PurchaseTrail = Remotes:WaitForChild("PurchaseTrail")
local EquipTrail = Remotes:WaitForChild("EquipTrail")
local GetTrailData = Remotes:WaitForChild("GetTrailData")
local TrailEquipped = Remotes:WaitForChild("TrailEquipped")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Trail types
local TRAIL_TYPES = UnifiedTrailConfig.TRAIL_TYPES

-- UI State
local shopUI = nil
local trailFrames = {
	[TRAIL_TYPES.CORE] = {},
	[TRAIL_TYPES.HANDS] = {},
}
local currentEquippedTrails = {
	[TRAIL_TYPES.CORE] = "default",
	[TRAIL_TYPES.HANDS] = "default",
}
local ownedTrails = {
	[TRAIL_TYPES.CORE] = {},
	[TRAIL_TYPES.HANDS] = {},
}
-- Get all trails for both types
local allTrails = {
	[TRAIL_TYPES.CORE] = UnifiedTrailConfig.getTrailsByType(TRAIL_TYPES.CORE),
	[TRAIL_TYPES.HANDS] = UnifiedTrailConfig.getTrailsByType(TRAIL_TYPES.HANDS),
}

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

-- Helper function to get trail template for specific type
local function getTrailTemplate(trailType)
	local shopUI = playerGui:WaitForChild("Shop")
	local cosmeticsFrame = shopUI.CanvasGroup.Frame.Content.Cosmetics

	if trailType == TRAIL_TYPES.CORE then
		return cosmeticsFrame.Core:FindFirstChild("Template", true)
	elseif trailType == TRAIL_TYPES.HANDS then
		return cosmeticsFrame.Hands.ScrollingFrame:FindFirstChild("Template")
	end
	return nil
end

-- Helper function to create trail frame UI using existing template
local function createTrailFrame(trailData, parent, trailType)
	local template = getTrailTemplate(trailType)
	if not template then
		warn("Template not found for trail type:", trailType)
		return nil
	end

	local trailFrame = template:Clone()
	trailFrame.Name = trailData.id
	trailFrame.Visible = true
	trailFrame.Parent = parent

	-- Update UI elements
	local nameLabel = trailFrame:FindFirstChild("NameLabel")
	local priceLabel = trailFrame:FindFirstChild("PriceLabel")
	local colorPreview = trailFrame:FindFirstChild("ColorPreview")
	local equipButton = trailFrame:FindFirstChild("EquipButton")
	local purchaseButton = trailFrame:FindFirstChild("PurchaseButton")
	local ownedLabel = trailFrame:FindFirstChild("OwnedLabel")

	if nameLabel then
		nameLabel.Text = trailData.name
	end

	if priceLabel then
		if trailData.price == 0 then
			priceLabel.Text = "FREE"
			priceLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		else
			priceLabel.Text = trailData.price .. " " .. trailData.currency
			priceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	if colorPreview then
		colorPreview.BackgroundColor3 = trailData.color
	end

	-- Check if owned
	local isOwned = ownedTrails[trailType][trailData.id] or false
	local isEquipped = currentEquippedTrails[trailType] == trailData.id

	if isOwned then
		if equipButton then
			equipButton.Visible = true
			equipButton.Text = isEquipped and "EQUIPPED" or "EQUIP"
			equipButton.BackgroundColor3 = isEquipped and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(50, 150, 255)
		end
		if purchaseButton then
			purchaseButton.Visible = false
		end
		if ownedLabel then
			ownedLabel.Visible = true
		end
	else
		if equipButton then
			equipButton.Visible = false
		end
		if purchaseButton then
			purchaseButton.Visible = true
			purchaseButton.Text = "BUY " .. trailData.price .. " " .. trailData.currency
		end
		if ownedLabel then
			ownedLabel.Visible = false
		end
	end

	-- Connect button events
	if equipButton then
		equipButton.MouseButton1Click:Connect(function()
			TrailManager.equipTrail(trailData.id, trailType)
		end)
	end

	if purchaseButton then
		purchaseButton.MouseButton1Click:Connect(function()
			TrailManager.purchaseTrail(trailData.id, trailType)
		end)
	end

	return trailFrame
end

-- Function to populate trail UI for specific type
function TrailManager.populateTrailUI(trailType)
	local shopUI = playerGui:WaitForChild("Shop")
	local cosmeticsFrame = shopUI.CanvasGroup.Frame.Content.Cosmetics

	local parentFrame = nil
	if trailType == TRAIL_TYPES.CORE then
		parentFrame = cosmeticsFrame.Core
	elseif trailType == TRAIL_TYPES.HANDS then
		parentFrame = cosmeticsFrame.Hands.ScrollingFrame
	end

	if not parentFrame then
		warn("Parent frame not found for trail type:", trailType)
		return
	end

	-- Clear existing trail frames
	for _, frame in pairs(trailFrames[trailType]) do
		if frame and frame.Parent then
			frame:Destroy()
		end
	end
	trailFrames[trailType] = {}

	-- Create trail frames
	for _, trailData in ipairs(allTrails[trailType]) do
		local trailFrame = createTrailFrame(trailData, parentFrame, trailType)
		if trailFrame then
			trailFrames[trailType][trailData.id] = trailFrame
		end
	end
end

-- Function to purchase a trail
function TrailManager.purchaseTrail(trailId, trailType)
	local trailData = UnifiedTrailConfig.getTrailById(trailId, trailType)

	if not trailData then
		warn("Trail not found:", trailId, "for type:", trailType)
		return
	end

	-- Call server to purchase
	PurchaseTrail:FireServer(trailId, trailType)
end

-- Function to equip a trail
function TrailManager.equipTrail(trailId, trailType)
	if not ownedTrails[trailType][trailId] then
		warn("Trail not owned:", trailId, "for type:", trailType)
		return
	end

	-- Call server to equip
	EquipTrail:FireServer(trailId, trailType)
end

-- Function to update trail UI after purchase/equip
function TrailManager.updateTrailUI(trailId, trailType, isOwned, isEquipped)
	local trailFrame = trailFrames[trailType][trailId]
	if not trailFrame then
		return
	end

	-- Update owned status
	if isOwned then
		ownedTrails[trailType][trailId] = true
	end

	-- Update equipped status
	if isEquipped then
		currentEquippedTrails[trailType] = trailId
	end

	-- Update UI elements
	local equipButton = trailFrame:FindFirstChild("EquipButton")
	local purchaseButton = trailFrame:FindFirstChild("PurchaseButton")
	local ownedLabel = trailFrame:FindFirstChild("OwnedLabel")

	if isOwned then
		if equipButton then
			equipButton.Visible = true
			equipButton.Text = isEquipped and "EQUIPPED" or "EQUIP"
			equipButton.BackgroundColor3 = isEquipped and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(50, 150, 255)
		end
		if purchaseButton then
			purchaseButton.Visible = false
		end
		if ownedLabel then
			ownedLabel.Visible = true
		end
	else
		if equipButton then
			equipButton.Visible = false
		end
		if purchaseButton then
			purchaseButton.Visible = true
		end
		if ownedLabel then
			ownedLabel.Visible = false
		end
	end

	-- Update all other trail frames to show correct equipped state
	for id, frame in pairs(trailFrames[trailType]) do
		if id ~= trailId then
			local otherEquipButton = frame:FindFirstChild("EquipButton")
			if otherEquipButton and otherEquipButton.Visible then
				otherEquipButton.Text = "EQUIP"
				otherEquipButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
			end
		end
	end
end

-- Function to initialize trail system
function TrailManager.initialize()
	-- Wait for shop UI to be ready
	shopUI = playerGui:WaitForChild("Shop")

	-- Hide templates
	local coreTemplate = getTrailTemplate(TRAIL_TYPES.CORE)
	local handsTemplate = getTrailTemplate(TRAIL_TYPES.HANDS)

	if coreTemplate then
		coreTemplate.Visible = false
	end
	if handsTemplate then
		handsTemplate.Visible = false
	end

	-- Populate both trail UIs
	TrailManager.populateTrailUI(TRAIL_TYPES.CORE)
	TrailManager.populateTrailUI(TRAIL_TYPES.HANDS)

	-- Connect to server events
	TrailEquipped.OnClientEvent:Connect(function(trailId, trailType, isOwned, isEquipped)
		TrailManager.updateTrailUI(trailId, trailType, isOwned, isEquipped)
	end)

	-- Get initial trail data
	GetTrailData:FireServer()
end

-- Function to get current equipped trail for specific type
function TrailManager.getEquippedTrail(trailType)
	return currentEquippedTrails[trailType]
end

-- Function to check if trail is owned for specific type
function TrailManager.isTrailOwned(trailId, trailType)
	return ownedTrails[trailType][trailId] or false
end

-- Export trail types for external use
TrailManager.TRAIL_TYPES = TRAIL_TYPES

return TrailManager
