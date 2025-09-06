-- MenuManager.lua
-- Menu management system for MenuAnimator

local CollectionService = game:GetService("CollectionService")
local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)
local AnimationPresets = require(script.Parent.AnimationPresets)

local MenuManager = {}

-- Menu management system
local openMenus = {} -- Track which menus are currently open {menu = button}
local buttonStates = {} -- Track button active states {button = isActive}
local menuOriginalPositions = {} -- Store original positions of menus {menu = originalPosition}

-- Function to check if a button has the "MenuButton" tag
local function isMenuButton(button)
	return CollectionService:HasTag(button, "MenuButton")
end

-- Function to get animation configuration for a menu
local function getMenuAnimationConfig(menu, button)
	-- Check for Animation StringValue on the menu itself
	local animationValue = menu:FindFirstChild("Animation")
	if animationValue and animationValue:IsA("StringValue") then
		local presetName = animationValue.Value
		if AnimationPresets.PRESETS[presetName] then
			return AnimationPresets.PRESETS[presetName]
		end
	end

	-- Check for Animation StringValue on the button
	if button then
		local buttonAnimationValue = button:FindFirstChild("Animation")
		if buttonAnimationValue and buttonAnimationValue:IsA("StringValue") then
			local presetName = buttonAnimationValue.Value
			if AnimationPresets.PRESETS[presetName] then
				return AnimationPresets.PRESETS[presetName]
			end
		end
	end

	-- Fallback to default animation
	return AnimationPresets.PRESETS.SLIDE_UP
end

-- Function to get custom animation settings from attributes
local function getCustomAnimationSettings(menu)
	local settings = {}

	-- Duration override
	local durationValue = menu:GetAttribute("AnimationDuration")
	if durationValue then
		settings.duration = durationValue
	end

	-- Easing style override
	local easingValue = menu:GetAttribute("AnimationEasing")
	if easingValue then
		settings.easingStyle = easingValue
	end

	-- Easing direction override
	local easingDirectionValue = menu:GetAttribute("AnimationEasingDirection")
	if easingDirectionValue then
		settings.easingDirection = easingDirectionValue
	end

	return settings
end

-- Menu management functions
-- Function to deactivate button's "Active" style (for when menu closes externally)
local function deactivateButtonActiveStyle(button, elementStates)
	local elementState = elementStates[button]

	-- Always try to deactivate, regardless of current isActive state
	if elementState then
		elementState.isActive = false

		-- Apply deactivate animation
		Utils.createHoverTween(button, {
			Size = elementState.originalSize,
			Rotation = elementState.originalRotation,
		}):Play()

		-- Find and deactivate active elements
		local icon = button:FindFirstChild("Icon")
		local uiStroke = button:FindFirstChild("UIStroke")

		if icon then
			-- Restore hover State for Icon
			icon.UIGradient.Offset = Vector2.new(1, 1)
		end

		if uiStroke and uiStroke.UIGradient then
			uiStroke.UIGradient.Enabled = false
		end

		-- Restore original ZIndex
		button.ZIndex = elementState.originalZIndex
	end
end

function MenuManager.resetButtonState(button, elementStates)
	if buttonStates[button] then
		local elementState = elementStates[button]
		if elementState then
			elementState.isActive = false
			Utils.createHoverTween(button, {
				Size = elementState.originalSize,
				Rotation = elementState.originalRotation,
			}):Play()

			-- Restore original ZIndex
			button.ZIndex = elementState.originalZIndex
		end
		buttonStates[button] = false
	end

	-- Also deactivate any active style
	deactivateButtonActiveStyle(button, elementStates)
end

function MenuManager.setButtonActive(button, elementStates)
	if not buttonStates[button] then
		local elementState = elementStates[button]
		if elementState then
			elementState.isActive = true
			Utils.createHoverTween(button, {
				Size = UDim2.new(
					elementState.originalSize.X.Scale * Config.ACTIVATE_SCALE,
					elementState.originalSize.X.Offset * Config.ACTIVATE_SCALE,
					elementState.originalSize.Y.Scale * Config.ACTIVATE_SCALE,
					elementState.originalSize.Y.Offset * Config.ACTIVATE_SCALE
				),
				Rotation = Config.ACTIVATE_ROTATION,
			}):Play()

			-- Set ZIndex to 100 for active state
			button.ZIndex = 100
		end
		buttonStates[button] = true
	end
end

function MenuManager.getAllTargetMenus(button)
	local menus = {}
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("ObjectValue") and child.Name == "Open" and child.Value then
			table.insert(menus, child.Value)
		end
	end
	return menus
end

function MenuManager.getOpenMenus(button)
	local openMenusList = {}
	for menu, associatedButton in pairs(openMenus) do
		if associatedButton ~= button then
			table.insert(openMenusList, menu)
		end
	end
	return openMenusList
end

function MenuManager.getIgnoredMenus(button)
	local ignoredMenus = {}
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("ObjectValue") and child.Name == "Ignore" and child.Value then
			table.insert(ignoredMenus, child.Value)
		end
	end
	return ignoredMenus
end

function MenuManager.shouldIgnoreMenu(menu, ignoredMenus)
	for _, ignoredMenu in ipairs(ignoredMenus) do
		if ignoredMenu == menu then
			return true
		end
	end
	return false
end

-- Function to get all open menus controlled by MenuButton-tagged buttons
-- This ensures we only close menus controlled by main navigation buttons
function MenuManager.getMenuButtonControlledMenus(button)
	local menuButtonMenus = {}
	for menu, associatedButton in pairs(openMenus) do
		if associatedButton ~= button and isMenuButton(associatedButton) then
			table.insert(menuButtonMenus, menu)
		end
	end
	return menuButtonMenus
end

function MenuManager.closeAllOtherMenus(
	exceptMenu,
	button,
	menuStates,
	updateCameraEffects,
	updateSoundEffects,
	closeMenu,
	elementStates,
	resetGeneralButton
)
	-- NEW LOGIC: Only close menus controlled by buttons with "MenuButton" tag
	local menusToClose = MenuManager.getMenuButtonControlledMenus(button)
	local ignoredMenus = MenuManager.getIgnoredMenus(button)
	local firstMenuClosed = false

	for _, menu in ipairs(menusToClose) do
		if menu ~= exceptMenu and not MenuManager.shouldIgnoreMenu(menu, ignoredMenus) then
			local associatedButton = openMenus[menu]
			if associatedButton and menuStates[menu] then
				-- Mark as closed first
				local state = menuStates[menu]
				state.isOpen = false
				openMenus[menu] = nil

				-- Apply camera and sound effects immediately when first menu is closed
				-- Only apply effects if the button that opened this menu has "MenuButton" tag
				if not firstMenuClosed and isMenuButton(associatedButton) then
					updateCameraEffects()
					updateSoundEffects()
					firstMenuClosed = true
				end

				-- Close the menu
				local direction = "Top" -- Default direction, could be enhanced to store direction per menu
				closeMenu(menu, direction, state)

				-- Reset button state based on button type
				if isMenuButton(associatedButton) then
					MenuManager.resetButtonState(associatedButton, elementStates)
				elseif resetGeneralButton then
					-- Reset general button state using callback
					resetGeneralButton(associatedButton)
				end
			end
		end
	end
end

-- Getters for external access
function MenuManager.getOpenMenusTable()
	return openMenus
end

function MenuManager.getButtonStatesTable()
	return buttonStates
end

function MenuManager.getMenuOriginalPositionsTable()
	return menuOriginalPositions
end

-- Setters for external access
function MenuManager.setOpenMenus(menu, button)
	openMenus[menu] = button
end

function MenuManager.clearOpenMenus(menu)
	openMenus[menu] = nil
end

-- Animation configuration functions
function MenuManager.getMenuAnimationConfig(menu, button)
	return getMenuAnimationConfig(menu, button)
end

function MenuManager.getCustomAnimationSettings(menu)
	return getCustomAnimationSettings(menu)
end

return MenuManager
