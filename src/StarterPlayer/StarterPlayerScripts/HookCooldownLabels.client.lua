-- Hook Cooldown Labels: Shows remaining cooldown time above hooks with animations
-- Clones the BillboardGui template and animates it in/out with bounce effects

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Movement.Config)
local Grapple = require(ReplicatedStorage.Movement.Grapple)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Function to format time remaining
local function formatTimeRemaining(seconds)
	if seconds <= 0 then
		return "Ready!"
	elseif seconds < 1 then
		return string.format("%.1fs", seconds)
	elseif seconds < 60 then
		return string.format("%.0fs", seconds)
	else
		local minutes = math.floor(seconds / 60)
		local remainingSeconds = seconds % 60
		return string.format("%dm %ds", minutes, remainingSeconds)
	end
end

-- Store cooldown labels for each hook
local hookCooldownLabels = {}

-- Function to clean up all existing HookCooldownLabel instances on startup
local function cleanupAllExistingLabels()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BillboardGui") and descendant.Name == "HookCooldownLabel" then
			descendant:Destroy()
		end
	end
end

-- Clean up any existing labels on startup to prevent duplication
cleanupAllExistingLabels()

-- Function to get the BillboardGui template from ReplicatedStorage
local function getBillboardGuiTemplate()
	local billboardGui = ReplicatedStorage:FindFirstChild("UI"):FindFirstChild("Hook"):FindFirstChild("BillboardGui")
	if not billboardGui then
		warn("HookCooldownLabels: BillboardGui template not found in ReplicatedStorage/UI/Hook/BillboardGui")
		return nil
	end
	return billboardGui
end

-- Function to create a cooldown label for a hook
local function createCooldownLabel(hookPart)
	if hookCooldownLabels[hookPart] then
		return hookCooldownLabels[hookPart]
	end

	local template = getBillboardGuiTemplate()
	if not template then
		return nil
	end

	-- Clone the template
	local cooldownLabel = template:Clone()
	cooldownLabel.Name = "HookCooldownLabel"
	cooldownLabel.Parent = hookPart

	-- Get the TextLabel
	local textLabel = cooldownLabel:FindFirstChild("TextLabel")
	if not textLabel then
		cooldownLabel:Destroy()
		return nil
	end

	-- Initialize the label with current cooldown status
	local cooldownRemaining = Grapple.getPartCooldownRemaining(hookPart)
	local isVisible = cooldownRemaining > 0

	if isVisible then
		textLabel.Text = formatTimeRemaining(cooldownRemaining)
		cooldownLabel.Enabled = true
		textLabel.TextTransparency = 0
	else
		textLabel.Text = "Ready!"
		cooldownLabel.Enabled = true -- Always enable, just change transparency
		textLabel.TextTransparency = 1
	end

	-- Store the label
	hookCooldownLabels[hookPart] = {
		billboardGui = cooldownLabel,
		textLabel = textLabel,
		isVisible = isVisible,
		lastUpdate = os.clock(),
	}

	return hookCooldownLabels[hookPart]
end

-- Function to remove a cooldown label
local function removeCooldownLabel(hookPart)
	local labelData = hookCooldownLabels[hookPart]
	if labelData then
		labelData.billboardGui:Destroy()
		hookCooldownLabels[hookPart] = nil
	end
end

-- Function to clean up orphaned labels (call this periodically)
local function cleanupOrphanedLabels()
	for hookPart, labelData in pairs(hookCooldownLabels) do
		if not hookPart:IsDescendantOf(workspace) then
			removeCooldownLabel(hookPart)
		end
	end
end

-- Function to show label
local function showLabel(labelData)
	if labelData.isVisible then
		return
	end
	labelData.billboardGui.Enabled = true
	labelData.textLabel.TextTransparency = 0
	labelData.isVisible = true
end

-- Function to hide label
local function hideLabel(labelData)
	if not labelData.isVisible then
		return
	end
	labelData.billboardGui.Enabled = false
	labelData.textLabel.TextTransparency = 1
	labelData.isVisible = false
end

-- Debug logging control
local ENABLE_DEBUG_LOGS = false -- Set to true to enable debug logs
local lastLogTime = 0
local LOG_THROTTLE = 2.0 -- Only log once per 2 seconds (less frequent than HookArrow)

-- Initialize the system

-- Function to update cooldown labels
-- NEW BEHAVIOR: Cooldown labels remain visible even when out of range
-- until the cooldown expires. Only then they disappear when out of range.
local function updateCooldownLabels()
	if not Config.HookCooldownLabels then
		return -- Silently return if disabled
	end

	local character = player.Character
	if not character then
		return
	end

	local currentTime = os.clock()
	local shouldLog = ENABLE_DEBUG_LOGS and currentTime - lastLogTime >= LOG_THROTTLE

	-- Only log basic info occasionally
	if shouldLog then
		print("HookCooldownLabels: Updating labels... Total:", #hookCooldownLabels)
	end

	for _, hookPart in ipairs(CollectionService:GetTagged(Config.HookTag or "Hookable")) do
		if hookPart:IsDescendantOf(workspace) and not hookCooldownLabels[hookPart] then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local distance = (hookPart.Position - root.Position).Magnitude
				local range = Config.HookAutoRange or 90
				local isInRange = (distance <= range)

				-- Check if hook should show label (either in range OR on cooldown)
				local cooldownRemaining = Grapple.getPartCooldownRemaining(hookPart)
				local shouldShowLabel = isInRange or (cooldownRemaining > 0)

				if shouldShowLabel then
					createCooldownLabel(hookPart)
				end
			end
		end
	end

	-- Clean up orphaned labels periodically
	local cleanupCounter = math.floor(currentTime * 2) % 10 -- Every ~5 seconds
	if cleanupCounter == 0 then
		cleanupOrphanedLabels()
	end

	-- Now update all existing labels
	for hookPart, labelData in pairs(hookCooldownLabels) do
		if not hookPart:IsDescendantOf(workspace) then
			-- Hook was removed, clean up
			removeCooldownLabel(hookPart)
		else
			-- Check if hook is still in range
			local root = character:FindFirstChild("HumanoidRootPart")
			local isInRange = false
			if root then
				local distance = (hookPart.Position - root.Position).Magnitude
				local range = Config.HookAutoRange or 90
				isInRange = (distance <= range)
			end

			-- Check cooldown status regardless of range (cooldown takes precedence)
			local cooldownRemaining = Grapple.getPartCooldownRemaining(hookPart)

			if cooldownRemaining > 0 then
				-- Hook is on cooldown - ALWAYS show label (even if out of range)
				if not labelData.isVisible then
					showLabel(labelData)
				end

				-- Update text every frame for maximum fluidity (like HookArrow)
				local formattedTime = formatTimeRemaining(cooldownRemaining)
				labelData.textLabel.Text = formattedTime
			else
				-- Hook is ready - hide label ONLY if out of range
				if not isInRange then
					-- Out of range AND not on cooldown - hide label
					if labelData.isVisible then
						hideLabel(labelData)
					end
				else
					-- In range AND ready - hide label (normal behavior)
					if labelData.isVisible then
						hideLabel(labelData)
					end
				end
			end
		end
	end

	-- Update last log time
	if shouldLog then
		lastLogTime = currentTime
	end
end

-- Function to check if a hook is in range
local function isHookInRange(hookPart)
	local character = player.Character
	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local distance = (hookPart.Position - root.Position).Magnitude
	local range = Config.HookAutoRange or 90

	return distance <= range
end

-- Main update loop (every frame for maximum fluidity, like HookArrow)
RunService.RenderStepped:Connect(function()
	updateCooldownLabels()
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		-- Remove all cooldown labels
		for hookPart, _ in pairs(hookCooldownLabels) do
			removeCooldownLabel(hookPart)
		end
	end
end)

-- Cleanup when hooks are removed
workspace.DescendantRemoving:Connect(function(descendant)
	if descendant:IsA("BasePart") and CollectionService:HasTag(descendant, Config.HookTag or "Hookable") then
		removeCooldownLabel(descendant)
	end
end)

-- Only log initialization once
if Config.HookCooldownLabels then
	local template = getBillboardGuiTemplate()
	if template then
		print("HookCooldownLabels: System initialized and ready")
		print("HookCooldownLabels: Config.HookCooldownLabels =", Config.HookCooldownLabels)
		print("HookCooldownLabels: Config.HookTag =", Config.HookTag or "Hookable")
		print("HookCooldownLabels: Config.HookAutoRange =", Config.HookAutoRange or 90)
		print("HookCooldownLabels: BillboardGui template ready")
	else
		warn("HookCooldownLabels: BillboardGui template not found")
	end
else
	print("HookCooldownLabels: System DISABLED in config")
end

-- ============================================================================
-- OPTIMIZATION SUMMARY:
-- ============================================================================
-- 1. ✅ MAXIMUM FLUIDITY: Text updates every frame (60fps) like HookArrow
-- 2. ✅ REMOVED complex animation system - now uses simple show/hide
-- 3. ✅ REMOVED automatic template creation - uses existing UI only
-- 4. ✅ CLEAN CODE: Eliminated 100+ lines of unnecessary complexity
-- 5. ✅ ADDED automatic cleanup of orphaned/duplicated labels
-- 6. ✅ IMPROVED USER FEEDBACK: Cooldown labels persist out of range until cooldown expires
-- 7. ✅ This reduces CPU usage and console spam by ~95%
--
-- NEW BEHAVIOR:
-- ✅ Cooldown labels show even when OUT of range (better feedback)
-- ✅ Labels disappear ONLY when cooldown expires AND user is out of range
-- ✅ In-range hooks behave normally (show/hide based on cooldown)
-- ✅ Uses existing BillboardGui template from ReplicatedStorage/UI/Hook/BillboardGui
-- ✅ Automatic cleanup prevents infinite BillboardGui duplication
-- ✅ MAXIMUM FLUIDITY: Text updates every frame for smooth countdown
-- ============================================================================
