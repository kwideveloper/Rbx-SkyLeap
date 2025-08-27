-- ZiplineInitializer: Automatically creates RopeConstraints for objects tagged with "Zipline"
-- Searches for 2 attachments within the tagged object and creates a RopeConstraint between them

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Movement.Config)
local TAG_NAME = Config.ZiplineTagName or "Zipline"

local ZiplineInitializer = {}

-- Function to find 2 attachments within a zipline object
local function findAttachments(ziplineObject)
	local attachments = {}

	-- Search for all attachments within the zipline object (including descendants)
	for _, descendant in ipairs(ziplineObject:GetDescendants()) do
		if descendant:IsA("Attachment") then
			table.insert(attachments, descendant)
		end
	end

	-- Return the first 2 attachments found (or nil if less than 2)
	if #attachments >= 2 then
		return attachments[1], attachments[2]
	else
		return nil, nil
	end
end

-- Function to create RopeConstraint for a zipline object
local function createRopeConstraint(ziplineObject)
	-- Check if a RopeConstraint already exists
	local existingRope = ziplineObject:FindFirstChildOfClass("RopeConstraint")
	if existingRope then
		warn("ZiplineInitializer: RopeConstraint already exists in", ziplineObject:GetFullName())
		return existingRope
	end

	-- Find attachments
	local attachment0, attachment1 = findAttachments(ziplineObject)
	if not attachment0 or not attachment1 then
		warn("ZiplineInitializer: Could not find 2 attachments in", ziplineObject:GetFullName())
		return nil
	end

	-- Create RopeConstraint
	local ropeConstraint = Instance.new("RopeConstraint")
	ropeConstraint.Name = "ZiplineRope"
	ropeConstraint.Attachment0 = attachment0
	ropeConstraint.Attachment1 = attachment1
	ropeConstraint.Length = (attachment0.WorldPosition - attachment1.WorldPosition).Magnitude
	ropeConstraint.Visible = true

	-- Add to the root zipline object (where the tag is)
	ropeConstraint.Parent = ziplineObject
	return ropeConstraint
end

-- Function to initialize a zipline object
local function initializeZipline(ziplineObject)
	if not ziplineObject:IsDescendantOf(workspace) then
		return
	end

	local ropeConstraint = createRopeConstraint(ziplineObject)
	if not ropeConstraint then
		warn("ZiplineInitializer: Failed to initialize zipline for", ziplineObject:GetFullName())
	end
end

-- Function to handle when an object is tagged
local function onTagged(instance)
	-- Accept any instance type that can have children (BasePart, Model, Folder, etc.)
	if instance:IsA("BasePart") or instance:IsA("Model") or instance:IsA("Folder") or instance:IsA("MeshPart") then
		initializeZipline(instance)
	end
end

-- Function to handle when an object is untagged (cleanup if needed)
local function onUntagged(instance)
	-- Could add cleanup logic here if needed
	local ropeConstraint = instance:FindFirstChildOfClass("RopeConstraint")
	if ropeConstraint then
		ropeConstraint:Destroy()
	end
end

-- Initialize existing ziplines on server start
local function initializeExistingZiplines(instance)
	local taggedInstances = CollectionService:GetTagged(TAG_NAME)
	for _, instance in ipairs(taggedInstances) do
		initializeZipline(instance)
	end
end

-- Check if auto-initialization is enabled
if Config.ZiplineAutoInitialize then
	-- Connect to CollectionService events
	CollectionService:GetInstanceAddedSignal(TAG_NAME):Connect(onTagged)
	CollectionService:GetInstanceRemovedSignal(TAG_NAME):Connect(onUntagged)

	-- Initialize existing ziplines
	initializeExistingZiplines()
end

return ZiplineInitializer
-- Searches for 2 attachments within the tagged object and creates a RopeConstraint between them
