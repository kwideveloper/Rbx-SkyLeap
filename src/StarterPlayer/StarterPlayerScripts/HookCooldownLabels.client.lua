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

-- Store cooldown labels for each hook
local hookCooldownLabels = {}

-- Animation settings
local ANIMATION_SETTINGS = {
	BOUNCE_IN = {
		Duration = 0.4,
		EasingStyle = Enum.EasingStyle.Bounce,
		EasingDirection = Enum.EasingDirection.Out,
	},
	BOUNCE_OUT = {
		Duration = 0.3,
		EasingStyle = Enum.EasingStyle.Back,
		EasingDirection = Enum.EasingDirection.In,
	},
	FADE_IN = {
		Duration = 0.2,
		EasingStyle = Enum.EasingStyle.Quad,
		EasingDirection = Enum.EasingDirection.Out,
	},
	FADE_OUT = {
		Duration = 0.15,
		EasingStyle = Enum.EasingStyle.Quad,
		EasingDirection = Enum.EasingDirection.In,
	},
}

-- Function to get the BillboardGui template from ReplicatedStorage
local function getBillboardGuiTemplate()
	local uiFolder = ReplicatedStorage:FindFirstChild("UI")
	if not uiFolder then
		warn("HookCooldownLabels: UI folder not found in ReplicatedStorage")
		return nil
	end

	local hookFolder = uiFolder:FindFirstChild("Hook")
	if not hookFolder then
		warn("HookCooldownLabels: Hook folder not found in UI")
		return nil
	end

	local billboardGui = hookFolder:FindFirstChild("BillboardGui")
	if not billboardGui then
		warn("HookCooldownLabels: BillboardGui template not found")
		return nil
	end

	print("HookCooldownLabels: Found BillboardGui template:", billboardGui:GetFullName())
	return billboardGui
end

-- Function to create a cooldown label for a hook
local function createCooldownLabel(hookPart)
	if hookCooldownLabels[hookPart] then
		print("HookCooldownLabels: Label already exists for hook:", hookPart:GetFullName())
		return hookCooldownLabels[hookPart]
	end

	local template = getBillboardGuiTemplate()
	if not template then
		warn("HookCooldownLabels: BillboardGui template not found")
		return nil
	end

	print("HookCooldownLabels: Creating label for hook:", hookPart:GetFullName())

	-- Clone the template
	local cooldownLabel = template:Clone()
	cooldownLabel.Name = "HookCooldownLabel"

	-- Set the parent to the hook part
	cooldownLabel.Parent = hookPart

	-- Get the TextLabel
	local textLabel = cooldownLabel:FindFirstChild("TextLabel")
	if not textLabel then
		warn("HookCooldownLabels: TextLabel not found in BillboardGui template")
		cooldownLabel:Destroy()
		return nil
	end

	-- Initialize the label with current cooldown status
	local cooldownRemaining = Grapple.getPartCooldownRemaining(hookPart)
	if cooldownRemaining > 0 then
		textLabel.Text = formatTimeRemaining(cooldownRemaining)
		-- Show immediately if on cooldown
		cooldownLabel.Enabled = true
		cooldownLabel.Size = UDim2.new(0, 100, 0, 40) -- Full size
		textLabel.TextTransparency = 0
	else
		textLabel.Text = "Ready!"
		-- Hide if not on cooldown
		cooldownLabel.Enabled = false
		cooldownLabel.Size = UDim2.new(0, 0, 0, 0) -- Hidden size
		textLabel.TextTransparency = 1
	end

	-- Store the label
	hookCooldownLabels[hookPart] = {
		billboardGui = cooldownLabel,
		textLabel = textLabel,
		isVisible = (cooldownRemaining > 0),
		lastUpdate = os.clock(),
	}

	print(
		"HookCooldownLabels: Successfully created label for hook:",
		hookPart:GetFullName(),
		"cooldown:",
		cooldownRemaining
	)
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

-- Function to animate the label in with bounce effect
local function animateLabelIn(labelData)
	if labelData.isVisible then
		return
	end

	local billboardGui = labelData.billboardGui
	local textLabel = labelData.textLabel

	-- Reset scale and transparency for animation
	billboardGui.Size = UDim2.new(0, 0, 0, 0)
	textLabel.TextTransparency = 1

	-- Enable the label
	billboardGui.Enabled = true

	-- Animate scale with bounce
	local scaleTween = TweenService:Create(
		billboardGui,
		TweenInfo.new(
			ANIMATION_SETTINGS.BOUNCE_IN.Duration,
			ANIMATION_SETTINGS.BOUNCE_IN.EasingStyle,
			ANIMATION_SETTINGS.BOUNCE_IN.EasingDirection
		),
		{ Size = UDim2.new(0, 100, 0, 40) } -- Adjust size as needed
	)

	-- Animate text transparency
	local textTween = TweenService:Create(
		textLabel,
		TweenInfo.new(
			ANIMATION_SETTINGS.FADE_IN.Duration,
			ANIMATION_SETTINGS.FADE_IN.EasingStyle,
			ANIMATION_SETTINGS.FADE_IN.EasingDirection
		),
		{ TextTransparency = 0 }
	)

	-- Start animations
	scaleTween:Play()
	textTween:Play()

	labelData.isVisible = true
	print("HookCooldownLabels: Animated label IN for hook:", labelData.billboardGui.Parent:GetFullName())
end

-- Function to animate the label out
local function animateLabelOut(labelData)
	if not labelData.isVisible then
		return
	end

	local billboardGui = labelData.billboardGui
	local textLabel = labelData.textLabel

	-- Animate scale out
	local scaleTween = TweenService:Create(
		billboardGui,
		TweenInfo.new(
			ANIMATION_SETTINGS.BOUNCE_OUT.Duration,
			ANIMATION_SETTINGS.BOUNCE_OUT.EasingStyle,
			ANIMATION_SETTINGS.BOUNCE_OUT.EasingDirection
		),
		{ Size = UDim2.new(0, 0, 0, 0) }
	)

	-- Animate text transparency out
	local textTween = TweenService:Create(
		textLabel,
		TweenInfo.new(
			ANIMATION_SETTINGS.FADE_OUT.Duration,
			ANIMATION_SETTINGS.FADE_OUT.EasingStyle,
			ANIMATION_SETTINGS.FADE_OUT.EasingDirection
		),
		{ TextTransparency = 1 }
	)

	-- Start animations
	scaleTween:Play()
	textTween:Play()

	-- Disable after animation
	scaleTween.Completed:Connect(function()
		billboardGui.Enabled = false
		labelData.isVisible = false
		print("HookCooldownLabels: Animated label OUT for hook:", billboardGui.Parent:GetFullName())
	end)
end

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

-- Function to update cooldown labels
local function updateCooldownLabels()
	if not Config.HookCooldownLabels then
		print("HookCooldownLabels: System disabled in config")
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local currentTime = os.clock()

	-- Debug: Print current state
	print("HookCooldownLabels: Updating labels...")
	print("Total hooks with labels:", #hookCooldownLabels)

	-- First, ensure ALL hooks in range have labels created
	print("HookCooldownLabels: Checking for hooks to create labels...")
	local totalHooks = #CollectionService:GetTagged(Config.HookTag or "Hookable")
	print("HookCooldownLabels: Total hooks with tag:", totalHooks)

	for _, hookPart in ipairs(CollectionService:GetTagged(Config.HookTag or "Hookable")) do
		if hookPart:IsDescendantOf(workspace) and not hookCooldownLabels[hookPart] then
			-- Check if hook is in range
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local distance = (hookPart.Position - root.Position).Magnitude
				local range = Config.HookAutoRange or 90

				print("HookCooldownLabels: Hook", hookPart:GetFullName(), "distance:", distance, "range:", range)

				if distance <= range then
					-- Create label for this hook
					print("HookCooldownLabels: Creating label for new hook in range:", hookPart:GetFullName())
					createCooldownLabel(hookPart)
				else
					print("HookCooldownLabels: Hook", hookPart:GetFullName(), "out of range")
				end
			else
				print("HookCooldownLabels: No HumanoidRootPart found")
			end
		else
			if hookCooldownLabels[hookPart] then
				print("HookCooldownLabels: Hook", hookPart:GetFullName(), "already has label")
			else
				print("HookCooldownLabels: Hook", hookPart:GetFullName(), "not in workspace")
			end
		end
	end

	-- Now update all existing labels
	for hookPart, labelData in pairs(hookCooldownLabels) do
		if not hookPart:IsDescendantOf(workspace) then
			-- Hook was removed, clean up
			print("HookCooldownLabels: Removing label for destroyed hook:", hookPart:GetFullName())
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

			if not isInRange then
				-- Hook is out of range, hide label
				if labelData.isVisible then
					print("HookCooldownLabels: Hiding label for hook out of range:", hookPart:GetFullName())
					animateLabelOut(labelData)
				end
			else
				-- Hook is in range, check cooldown status
				local cooldownRemaining = Grapple.getPartCooldownRemaining(hookPart)
				print(
					"HookCooldownLabels: Hook",
					hookPart:GetFullName(),
					"cooldown remaining:",
					cooldownRemaining,
					"type:",
					typeof(cooldownRemaining)
				)

				-- Debug: Check if Grapple module is working
				if typeof(cooldownRemaining) ~= "number" then
					print("HookCooldownLabels: WARNING - cooldownRemaining is not a number:", cooldownRemaining)
					cooldownRemaining = 0 -- Default to 0 if there's an error
				end

				if cooldownRemaining > 0 then
					-- Hook is on cooldown, show label
					if not labelData.isVisible then
						print("HookCooldownLabels: Showing label for hook:", hookPart:GetFullName())
						animateLabelIn(labelData)
					end

					-- Update text if enough time has passed (avoid constant updates)
					if currentTime - labelData.lastUpdate > 0.1 then
						local formattedTime = formatTimeRemaining(cooldownRemaining)
						labelData.textLabel.Text = formattedTime
						labelData.lastUpdate = currentTime
						print("HookCooldownLabels: Updated text for", hookPart:GetFullName(), "to:", formattedTime)
					end
				else
					-- Hook is ready, hide label
					if labelData.isVisible then
						print("HookCooldownLabels: Hiding label for hook:", hookPart:GetFullName())
						animateLabelOut(labelData)
					end
				end
			end
		end
	end

	print("HookCooldownLabels: Total hooks with labels:", #hookCooldownLabels)
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

-- Main update loop (every 0.1 seconds for better performance)
local lastUpdate = 0
RunService.RenderStepped:Connect(function()
	local currentTime = os.clock()
	if currentTime - lastUpdate >= 0.1 then -- Update every 0.1 seconds
		updateCooldownLabels()
		lastUpdate = currentTime
	end
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

print("HookCooldownLabels: System initialized and ready")
print("HookCooldownLabels: Config.HookCooldownLabels =", Config.HookCooldownLabels)
print("HookCooldownLabels: Config.HookTag =", Config.HookTag or "Hookable")
print("HookCooldownLabels: Config.HookAutoRange =", Config.HookAutoRange or 90)
