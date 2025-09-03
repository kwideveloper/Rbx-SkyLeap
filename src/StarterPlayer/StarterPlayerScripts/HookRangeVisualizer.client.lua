-- Hook Range Visualizer - Client-side script for visualizing hook ranges
-- Automatically shows ranges based on CollectionService tags

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Movement"):WaitForChild("Config"))

local HookRangeVisualizer = {}

-- Visual range parts storage
local visualParts = {}

-- Function to get effective range from hook part
local function getEffectiveRange(hookPart, rangeType)
	if rangeType == "detection" then
		local customRange = hookPart:GetAttribute("HookRange")
		return (typeof(customRange) == "number" and customRange > 0) and customRange or (Config.HookAutoRange or 90)
	elseif rangeType == "detach" then
		local customRange = hookPart:GetAttribute("HookAutoDetachDistance")
		return (typeof(customRange) == "number" and customRange > 0) and customRange
			or (Config.HookAutoDetachDistance or 30)
	end
	return 0
end

-- Function to create area visualizer (full area, not lines)
local function createAreaVisualizer(hookPart, rangeType, range)
	local visualizerName = rangeType == "detection" and "DetectionRange" or "DetachRange"

	-- Remove existing visualizer
	local existingVisualizer = hookPart:FindFirstChild(visualizerName)
	if existingVisualizer then
		existingVisualizer:Destroy()
	end

	-- Create area visualizer
	local areaPart = Instance.new("Part")
	areaPart.Name = visualizerName
	areaPart.Size = Vector3.new(range * 2, range * 2, range * 2) -- Full 3D sphere coverage
	areaPart.Position = hookPart.Position -- Exact center of hookable
	areaPart.Anchored = true
	areaPart.CanCollide = false
	areaPart.Material = Enum.Material.Neon
	areaPart.Transparency = 0.8
	areaPart.Shape = Enum.PartType.Ball -- Make it a perfect sphere

	-- Set colors based on range type
	if rangeType == "detection" then
		areaPart.BrickColor = BrickColor.new("Bright blue")
	else
		areaPart.BrickColor = BrickColor.new("Bright red")
	end

	areaPart.Parent = hookPart

	-- Store reference for cleanup
	if not visualParts[hookPart] then
		visualParts[hookPart] = {}
	end
	visualParts[hookPart][rangeType] = areaPart

	return areaPart
end

-- Function to update visualizer when attributes change
local function updateVisualizer(hookPart, rangeType)
	if not visualParts[hookPart] or not visualParts[hookPart][rangeType] then
		return
	end

	local range = getEffectiveRange(hookPart, rangeType)
	local visualizer = visualParts[hookPart][rangeType]

	-- Update size and position
	visualizer.Size = Vector3.new(range * 2, range * 2, range * 2)
	visualizer.Position = hookPart.Position -- Keep exact center
end

-- Function to create visualizers for a hook part
local function createVisualizers(hookPart)
	-- Check which tags are present
	local showRanges = CollectionService:HasTag(hookPart, "ShowRanges")
	local showDetach = CollectionService:HasTag(hookPart, "ShowDetach")
	local showRange = CollectionService:HasTag(hookPart, "ShowRange")

	-- Create detection range visualizer
	if showRanges or showRange then
		local detectionRange = getEffectiveRange(hookPart, "detection")
		createAreaVisualizer(hookPart, "detection", detectionRange)
	end

	-- Create detach range visualizer
	if showRanges or showDetach then
		local detachRange = getEffectiveRange(hookPart, "detach")
		createAreaVisualizer(hookPart, "detach", detachRange)
	end
end

-- Function to remove visualizers for a hook part
local function removeVisualizers(hookPart)
	if visualParts[hookPart] then
		for rangeType, visualizer in pairs(visualParts[hookPart]) do
			if visualizer and visualizer.Parent then
				visualizer:Destroy()
			end
		end
		visualParts[hookPart] = nil
	end
end

-- Function to handle hook part added
local function onHookPartAdded(hookPart)
	-- Wait a frame to ensure attributes are loaded
	task.wait()
	createVisualizers(hookPart)
end

-- Function to handle hook part removed
local function onHookPartRemoved(hookPart)
	removeVisualizers(hookPart)
end

-- Function to handle attribute changes
local function onAttributeChanged(hookPart, attributeName)
	-- Check if this is a hook-related attribute
	if attributeName == "HookRange" or attributeName == "HookAutoDetachDistance" then
		-- Determine which visualizers to update
		local showRanges = CollectionService:HasTag(hookPart, "ShowRanges")
		local showDetach = CollectionService:HasTag(hookPart, "ShowDetach")
		local showRange = CollectionService:HasTag(hookPart, "ShowRange")

		-- Update detection range if needed
		if (showRanges or showRange) and attributeName == "HookRange" then
			updateVisualizer(hookPart, "detection")
		end

		-- Update detach range if needed
		if (showRanges or showDetach) and attributeName == "HookAutoDetachDistance" then
			updateVisualizer(hookPart, "detach")
		end
	end
end

-- Function to handle tag changes
local function onTagAdded(hookPart, tagName)
	if tagName == "ShowRanges" or tagName == "ShowDetach" or tagName == "ShowRange" then
		-- Recreate all visualizers for this hook
		removeVisualizers(hookPart)
		createVisualizers(hookPart)
	end
end

local function onTagRemoved(hookPart, tagName)
	if tagName == "ShowRanges" or tagName == "ShowDetach" or tagName == "ShowRange" then
		-- Recreate all visualizers for this hook
		removeVisualizers(hookPart)
		createVisualizers(hookPart)
	end
end

-- Initialize the visualizer system
local function initialize()
	-- Connect to CollectionService events
	CollectionService:GetInstanceAddedSignal("Hookable"):Connect(onHookPartAdded)
	CollectionService:GetInstanceRemovedSignal("Hookable"):Connect(onHookPartRemoved)

	-- Connect to tag events
	CollectionService:GetInstanceAddedSignal("ShowRanges"):Connect(function(instance)
		if CollectionService:HasTag(instance, "Hookable") then
			onTagAdded(instance, "ShowRanges")
		end
	end)

	CollectionService:GetInstanceRemovedSignal("ShowRanges"):Connect(function(instance)
		if CollectionService:HasTag(instance, "Hookable") then
			onTagRemoved(instance, "ShowRanges")
		end
	end)

	CollectionService:GetInstanceAddedSignal("ShowDetach"):Connect(function(instance)
		if CollectionService:HasTag(instance, "Hookable") then
			onTagAdded(instance, "ShowDetach")
		end
	end)

	CollectionService:GetInstanceRemovedSignal("ShowDetach"):Connect(function(instance)
		if CollectionService:HasTag(instance, "Hookable") then
			onTagRemoved(instance, "ShowDetach")
		end
	end)

	CollectionService:GetInstanceAddedSignal("ShowRange"):Connect(function(instance)
		if CollectionService:HasTag(instance, "Hookable") then
			onTagAdded(instance, "ShowRange")
		end
	end)

	CollectionService:GetInstanceRemovedSignal("ShowRange"):Connect(function(instance)
		if CollectionService:HasTag(instance, "Hookable") then
			onTagRemoved(instance, "ShowRange")
		end
	end)

	-- Connect to attribute changed events for existing hooks
	for _, hookPart in ipairs(CollectionService:GetTagged("Hookable")) do
		hookPart.AttributeChanged:Connect(function(attributeName)
			onAttributeChanged(hookPart, attributeName)
		end)

		-- Create visualizers for existing hooks
		createVisualizers(hookPart)
	end

	print("[HookRangeVisualizer] Initialized - Hook range visualization system active")
end

-- Start the system
initialize()

return HookRangeVisualizer
