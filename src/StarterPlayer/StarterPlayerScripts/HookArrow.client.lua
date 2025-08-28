local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Movement.Config)
local Grapple = require(ReplicatedStorage.Movement.Grapple)
local HookHighlightConfig = require(ReplicatedStorage.Movement.HookHighlightConfig)

local billboardGui = ReplicatedStorage:WaitForChild("UI"):WaitForChild("Hook"):WaitForChild("BillboardGui")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function getHookUI()
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	return pg:FindFirstChild("HookUI")
end

local function ensureArrow()
	local hookUI = getHookUI()
	if not hookUI then
		return nil
	end
	local arrow = hookUI:FindFirstChild("Indicator")
	if arrow and arrow:IsA("GuiObject") then
		return arrow
	end
	return nil
end

local function isInRange(character, part)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and part and part:IsA("BasePart") and part:IsDescendantOf(workspace)) then
		return false
	end
	local range = Config.HookAutoRange or 90
	return (part.Position - root.Position).Magnitude <= range
end

-- Store highlights for hooks to avoid creating duplicates
local hookHighlights = {}

local function createHookHighlight(hookPart)
	if billboardGui then
		local billboardGuiClone = billboardGui:Clone()
		billboardGuiClone.Parent = hookPart
	end

	if hookHighlights[hookPart] then
		return hookHighlights[hookPart]
	end

	local colors = HookHighlightConfig.getCurrentColors()
	local highlight = Instance.new("Highlight")
	highlight.Name = "HookHighlight"
	highlight.FillColor = colors.FILL
	highlight.OutlineColor = colors.OUTLINE
	highlight.FillTransparency = HookHighlightConfig.getProperty("FILL_TRANSPARENCY")
	highlight.OutlineTransparency = HookHighlightConfig.getProperty("OUTLINE_TRANSPARENCY")
	highlight.DepthMode = HookHighlightConfig.getProperty("DEPTH_MODE")
	highlight.Enabled = HookHighlightConfig.getProperty("ENABLED")
	highlight.Parent = hookPart

	hookHighlights[hookPart] = highlight
	return highlight
end

local function removeHookHighlight(hookPart)
	local highlight = hookHighlights[hookPart]
	if highlight then
		highlight:Destroy()
		hookHighlights[hookPart] = nil
	end
end

local function formatTimeRemaining(seconds)
	local minutes = math.floor(seconds / 60)
	local remainingSeconds = seconds % 60
	return string.format("%02d:%02d", minutes, remainingSeconds)
end

local function showCooldownLabel(hookPart, cooldownRemaining)
	local label = hookPart:FindFirstChild("BillboardGui"):FindFirstChild("TextLabel")
	if label then
		label.Text = formatTimeRemaining(cooldownRemaining)
	end
end

local function hideCooldownLabel(hookPart)
	local label = hookPart:FindFirstChild("BillboardGui")
	if label then
		label.Enabled = false
	else
		return
	end
end

local function updateHookHighlights(character, bestTarget)
	-- Get all hooks in range
	local hooksInRange = {}
	for _, part in ipairs(CollectionService:GetTagged(Config.HookTag or "Hookable")) do
		if isInRange(character, part) then
			table.insert(hooksInRange, part)
		end
	end

	-- Update or create highlights for all hooks in range
	for _, hookPart in ipairs(hooksInRange) do
		local highlight = hookHighlights[hookPart]
		if not highlight then
			-- Create new highlight for this hook
			highlight = createHookHighlight(hookPart)
		end

		-- Always update colors based on cooldown state
		local isOnCooldown = Grapple.getPartCooldownRemaining(hookPart) > 0
		local cooldownRemaining = Grapple.getPartCooldownRemaining(hookPart)

		if isOnCooldown then
			-- Use cooldown colors
			local cooldownColors = HookHighlightConfig.getCooldownColors()
			highlight.FillColor = cooldownColors.FILL
			highlight.OutlineColor = cooldownColors.OUTLINE
			-- Ensure highlight is visible for cooldown state
			highlight.Enabled = true
			print("HookArrow: Hook", hookPart:GetFullName(), "ON COOLDOWN - Color set to RED, Enabled = true")
			showCooldownLabel(hookPart, cooldownRemaining)
		else
			-- Use normal colors
			local normalColors = HookHighlightConfig.getCurrentColors()
			highlight.FillColor = normalColors.FILL
			highlight.OutlineColor = normalColors.OUTLINE
			-- Ensure highlight is visible for normal state
			highlight.Enabled = true
			print("HookArrow: Hook", hookPart:GetFullName(), "READY - Color set to CYAN, Enabled = true")
			hideCooldownLabel(hookPart)
		end

		-- Show highlight for best target, dim for others
		local isBestTarget = (hookPart == bestTarget)
		if isBestTarget then
			-- Make best target more prominent
			highlight.FillTransparency = HookHighlightConfig.getProperty("FILL_TRANSPARENCY")
			print(
				"HookArrow: Hook",
				hookPart:GetFullName(),
				"is BEST TARGET - Transparency:",
				HookHighlightConfig.getProperty("FILL_TRANSPARENCY")
			)
		else
			-- Show other hooks but with higher transparency
			highlight.FillTransparency = math.min(0.8, HookHighlightConfig.getProperty("FILL_TRANSPARENCY") + 0.3)
			print(
				"HookArrow: Hook",
				hookPart:GetFullName(),
				"is OTHER - Transparency:",
				math.min(0.8, HookHighlightConfig.getProperty("FILL_TRANSPARENCY") + 0.3)
			)
		end

		print(
			"HookArrow: Final state for",
			hookPart:GetFullName(),
			"- Enabled:",
			highlight.Enabled,
			"FillColor:",
			highlight.FillColor,
			"Transparency:",
			highlight.FillTransparency
		)
	end

	-- Disable highlights for hooks that are no longer in range
	for hookPart, highlight in pairs(hookHighlights) do
		if not hookPart:IsDescendantOf(workspace) then
			-- Hook was removed, clean up
			removeHookHighlight(hookPart)
		else
			-- Check if this hook is still in range
			local stillInRange = false
			for _, inRangeHook in ipairs(hooksInRange) do
				if inRangeHook == hookPart then
					stillInRange = true
					break
				end
			end

			if not stillInRange then
				-- Hook is no longer in range, hide highlight
				highlight.Enabled = false
			end
		end
	end
end

local function getBestTargetInRange(character)
	local best, bestDist
	for _, part in ipairs(CollectionService:GetTagged(Config.HookTag or "Hookable")) do
		if isInRange(character, part) then
			local d = (part.Position - character.HumanoidRootPart.Position).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = part, d
			end
		end
	end
	return best
end

local function getOriginalColor(arrow: GuiObject)
	local saved = arrow:GetAttribute("_ArrowOrigColor3")
	if typeof(saved) == "Color3" then
		return saved
	end
	local c = arrow.BackgroundColor3
	arrow:SetAttribute("_ArrowOrigColor3", c)
	return c
end

local function setArrowState(arrow: GuiObject, isCooldown: boolean)
	if isCooldown then
		arrow.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	else
		arrow.BackgroundColor3 = getOriginalColor(arrow)
	end
end

local function pointArrowAtWorld(arrow: GuiObject, worldPos: Vector3)
	local viewport = camera.ViewportSize
	local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
	local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
	local pos2 = Vector2.new(screenPos.X, screenPos.Y)
	local dir = pos2 - center
	if
		onScreen
		and screenPos.Z > 0
		and pos2.X >= 0
		and pos2.X <= viewport.X
		and pos2.Y >= 0
		and pos2.Y <= viewport.Y
	then
		arrow.Visible = false
		return true -- on-screen
	end
	-- If target is behind the camera, flip the direction
	if screenPos.Z < 0 then
		dir = -dir
	end
	-- Clamp to screen edge with margin
	local margin = 24
	local half = Vector2.new(viewport.X * 0.5 - margin, viewport.Y * 0.5 - margin)
	if dir.Magnitude < 1e-3 then
		dir = Vector2.new(0, -1)
	end
	local scale = math.max(math.abs(dir.X) / half.X, math.abs(dir.Y) / half.Y, 1)
	local edgePos = center + dir / scale
	arrow.Position = UDim2.fromOffset(edgePos.X, edgePos.Y)
	arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90 -- assumes arrow points up
	arrow.Visible = true
	return false -- off-screen
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not (character and camera) then
		return
	end
	local arrow = ensureArrow()
	if not arrow then
		return
	end
	local target = getBestTargetInRange(character)
	if not target then
		arrow.Visible = false
		-- No target, disable all highlights but keep them for when they come back in range
		for hookPart, highlight in pairs(hookHighlights) do
			if highlight and highlight:IsDescendantOf(workspace) then
				highlight.Enabled = false
			end
		end
		return
	end

	-- Update hook highlights based on current best target
	updateHookHighlights(character, target)

	-- Color red while on cooldown, else original color
	local isCd = Grapple.getPartCooldownRemaining(target) > 0
	setArrowState(arrow, isCd)
	local onScreen = pointArrowAtWorld(arrow, target.Position)
	-- While arrow is showing (off-screen), hide the default content Frame inside HookUI; show it when on-screen
	local hookUI = getHookUI()
	if hookUI then
		local content = hookUI:FindFirstChild("Frame")
		if content and content:IsA("GuiObject") then
			if not onScreen then
				content.Visible = false
				arrow.Visible = true
			else
				content.Visible = true
				arrow.Visible = false
			end
		end
	end
end)

-- Cleanup highlights when player leaves
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		-- Remove all highlights when player leaves
		for hookPart, highlight in pairs(hookHighlights) do
			removeHookHighlight(hookPart)
		end
	end
end)
