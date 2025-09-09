-- MenuAnimator.client.lua
-- Main MenuAnimator system that coordinates all modules
-- Handles UI animations and interactions for buttons with ObjectValue "Open" and StringValue "Animate" children

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- Import modules
local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)
local AnimationPresets = require(script.Parent.AnimationPresets)
local CameraEffects = require(script.Parent.CameraEffects)
local SoundEffects = require(script.Parent.SoundEffects)
local MenuManager = require(script.Parent.MenuManager)
local ButtonAnimations = require(script.Parent.ButtonAnimations)
local GeneralButtonAnimations = require(script.Parent.GeneralButtonAnimations)
local MenuAnimations = require(script.Parent.MenuAnimations)
local MenuAnimationsOut = require(script.Parent.MenuAnimationsOut)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
local PlayerScripts = LocalPlayer:FindFirstChild("PlayerScripts")

local allCloseButtons = PlayerGui:GetChildren()

-- Animation states
local elementStates = {}
local menuStates = {}

-- Menu monitoring system
local menuListeners = {} -- Track listeners for menu changes
local monitoredMenus = {} -- Track which menus we're monitoring

-- Get references to shared state tables
local openMenus = MenuManager.getOpenMenusTable()
local buttonStates = MenuManager.getButtonStatesTable()
local menuOriginalPositions = MenuManager.getMenuOriginalPositionsTable()

-- Function to check if a menu is currently open/visible
local function isMenuOpen(menu)
	if not menu then
		return false
	end

	-- Check if menu is a CanvasGroup
	if menu:IsA("CanvasGroup") then
		-- For CanvasGroup, check if it's actually visible (not just transparent)
		local isOpen = menu.GroupTransparency < 1 and menu.Visible
		return isOpen
	end

	-- For regular UI elements, check if they're visible AND have a reasonable size
	local isVisible = menu.Visible
	local hasSize = menu.Size.X.Offset > 0 or menu.Size.X.Scale > 0
	local isOpen = isVisible and hasSize
	return isOpen
end

-- Function to check if a button has the "MenuButton" tag
local function isMenuButton(button)
	return CollectionService:HasTag(button, "MenuButton")
end

-- Function to check if a menu is a settings menu
local function isSettingsMenu(menu)
	if not menu then
		return false
	end

	-- Check if the menu's parent is named "Settings" (ScreenGui)
	local parent = menu.Parent
	if parent and parent.Name == "Settings" then
		return true
	end

	-- Fallback: check menu name for backward compatibility
	return menu.Name == "Settings" or menu.Name:lower():find("settings")
end

-- Handle menu opening/closing buttons
local function setupMenuButton(button)
	local hasOpen = false
	local hasClose = false

	-- Check for Open values (can have multiple)
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("ObjectValue") and child.Name == "Open" and child.Value then
			hasOpen = true
			break
		end
	end

	-- Check for Close values (can have multiple)
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("ObjectValue") and child.Name == "Close" and child.Value then
			hasClose = true
			break
		end
	end

	if not hasOpen and not hasClose then
		return
	end

	-- Setup for Open functionality
	if hasOpen then
		local targetMenus = MenuManager.getAllTargetMenus(button)
		if #targetMenus == 0 then
			return
		end

		-- Check for position override
		local positionValue = button:FindFirstChild("Position")
		local animationDirection = "Top" -- Default (from bottom to top)
		if positionValue and positionValue:IsA("StringValue") then
			animationDirection = positionValue.Value
		end

		-- Create menu states for each target menu
		local menuStatesForButton = {}
		for _, targetMenu in ipairs(targetMenus) do
			-- Save the original position when setting up the menu
			Utils.saveMenuOriginalPosition(targetMenu, menuOriginalPositions)

			local menuState = {
				isOpen = false,
				originalPosition = Utils.getMenuOriginalPosition(targetMenu, menuOriginalPositions),
				canvasGroup = targetMenu,
			}
			menuStatesForButton[targetMenu] = menuState
			menuStates[targetMenu] = menuState -- Use targetMenu as key for unique state tracking
		end

		button.MouseButton1Click:Connect(function()
			-- Check for Toggle BoolValue to prevent closing when already active
			local toggleValue = button:FindFirstChild("Toggle")
			local hasToggleOff = toggleValue and toggleValue:IsA("BoolValue") and not toggleValue.Value

			-- Check if any target menu is currently open (both in state and visually)
			local anyMenuOpen = false
			for _, targetMenu in ipairs(targetMenus) do
				local menuState = menuStatesForButton[targetMenu]
				local isVisuallyOpen = isMenuOpen(targetMenu)

				-- If menu is visually open but state says closed, sync the state
				if isVisuallyOpen and menuState and not menuState.isOpen then
					menuState.isOpen = true
					MenuManager.setOpenMenus(targetMenu, button)
				end

				if (menuState and menuState.isOpen) or isVisuallyOpen then
					anyMenuOpen = true
					break
				end
			end

			-- If Toggle is false and any menu is open, don't do anything
			if hasToggleOff and anyMenuOpen then
				return -- Don't close or re-open, just return
			end

			-- Determine if we're opening or closing based on visual state
			local isOpening = not anyMenuOpen

			if isOpening then
				-- Close all other menus first, but only if this button has "MenuButton" tag
				-- This prevents buttons without "MenuButton" tag from closing other menus
				if isMenuButton(button) then
					for _, targetMenu in ipairs(targetMenus) do
						MenuManager.closeAllOtherMenus(
							targetMenu,
							button,
							menuStates,
							function()
								CameraEffects.updateCameraEffects(menuStates, openMenus)
							end,
							function()
								SoundEffects.updateSoundEffects(menuStates, openMenus)
							end,
							function(menu, direction, state)
								MenuAnimations.closeMenu(menu, direction, state, menuOriginalPositions)
							end,
							elementStates,
							function(button)
								GeneralButtonAnimations.deactivateButtonActiveStyle(button)
							end
						)
					end
				end

				-- Open all target menus
				local firstMenuOpened = false
				for _, targetMenu in ipairs(targetMenus) do
					local menuState = menuStatesForButton[targetMenu]
					if not menuState.isOpen then
						menuState.isOpen = true
						MenuManager.setOpenMenus(targetMenu, button)

						-- Apply camera and sound effects immediately when first menu is opened
						-- Only apply effects if the button has "MenuButton" tag
						if not firstMenuOpened and isMenuButton(button) then
							CameraEffects.updateCameraEffects(menuStates, openMenus)
							SoundEffects.updateSoundEffects(menuStates, openMenus)
							firstMenuOpened = true
						end
						MenuAnimations.openMenu(
							targetMenu,
							animationDirection,
							menuState,
							button,
							menuOriginalPositions
						)
					end
				end

				-- Set button as active
				MenuManager.setButtonActive(button, elementStates)

				-- Also set the button state in our monitoring system
				if isMenuButton(button) then
					local elementState = elementStates[button]
					if elementState then
						elementState.isActive = true
					end
				else
					local generalElementStates = GeneralButtonAnimations.getElementStates()
					local elementState = generalElementStates[button]
					if elementState then
						elementState.isActive = true
					end
				end
			else
				-- Close all target menus, but check Toggle setting first
				local shouldClose = true

				-- If Toggle is false, don't close menus that are already open
				if hasToggleOff then
					shouldClose = false -- Don't close if Toggle is false
				end

				if shouldClose then
					local firstMenuClosed = false
					for _, targetMenu in ipairs(targetMenus) do
						local menuState = menuStatesForButton[targetMenu]
						-- Close menu if it's open in state OR visually open
						local isVisuallyOpen = isMenuOpen(targetMenu)
						if (menuState and menuState.isOpen) or isVisuallyOpen then
							-- Update state
							if menuState then
								menuState.isOpen = false
							end
							MenuManager.clearOpenMenus(targetMenu)

							-- Apply camera and sound effects immediately when first menu is closed
							-- Only apply effects if the button that opened this menu has "MenuButton" tag
							if not firstMenuClosed and isMenuButton(button) then
								CameraEffects.updateCameraEffects(menuStates, openMenus)
								SoundEffects.updateSoundEffects(menuStates, openMenus)
								firstMenuClosed = true
							end

							-- Use default slide_bottom animation for close from open button
							MenuAnimationsOut.closeMenu(targetMenu, "slide_bottom", menuState, menuOriginalPositions)
						end
					end

					-- Reset button state
					MenuManager.resetButtonState(button, elementStates)

					-- Also reset the button state in our monitoring system
					if isMenuButton(button) then
						local elementState = elementStates[button]
						if elementState then
							elementState.isActive = false
						end
					else
						local generalElementStates = GeneralButtonAnimations.getElementStates()
						local elementState = generalElementStates[button]
						if elementState then
							elementState.isActive = false
						end
					end
				end
			end
		end)
	end

	-- Setup for Close functionality
	if hasClose then
		local closeTargets = {}
		for _, child in ipairs(button:GetChildren()) do
			if child:IsA("ObjectValue") and child.Name == "Close" and child.Value then
				table.insert(closeTargets, child.Value)
			end
		end

		button.MouseButton1Click:Connect(function()
			local effectsUpdated = false
			for _, target in ipairs(closeTargets) do
				-- Find the button that opened this menu (if any) - defined outside if block
				local openingButton = openMenus[target]

				-- Check if menu is currently open (either in menuStates or visible)
				local isMenuOpen = false
				local menuState = menuStates[target] -- Use target menu as key

				if menuState and menuState.isOpen then
					isMenuOpen = true
				elseif target:IsA("CanvasGroup") then
					isMenuOpen = target.GroupTransparency < 1
				else
					isMenuOpen = target.Visible
				end

				if isMenuOpen then
					-- Mark as closed first
					if menuState then
						menuState.isOpen = false
					end
					MenuManager.clearOpenMenus(target)

					-- Update camera and sound effects immediately when first menu is closed
					-- Only apply effects if the button that opened this menu has "MenuButton" tag
					if not effectsUpdated and openingButton and isMenuButton(openingButton) then
						CameraEffects.updateCameraEffects(menuStates, openMenus)
						SoundEffects.updateSoundEffects(menuStates, openMenus)
						effectsUpdated = true
					end

					-- Get custom close animation from button
					local animateOutValue = button:FindFirstChild("AnimateOut")
					local animationName = "slide_bottom" -- Default animation

					if animateOutValue and animateOutValue:IsA("StringValue") then
						animationName = animateOutValue.Value
					end

					-- Close the menu with custom animation
					if menuState then
						-- Use existing menu state for animation
						MenuAnimationsOut.closeMenu(target, animationName, menuState, menuOriginalPositions)
					else
						-- Create temporary state for animation if none exists
						local tempState = {
							canvasGroup = target:IsA("CanvasGroup") and target or target,
							originalPosition = target.Position,
						}
						MenuAnimationsOut.closeMenu(target, animationName, tempState, menuOriginalPositions)
					end

					-- Reset button state if we found the opening button
					-- This works regardless of whether the opening button has "MenuButton" tag
					if openingButton then
						if isMenuButton(openingButton) then
							MenuManager.resetButtonState(openingButton, elementStates)
						else
							-- Reset general button state
							GeneralButtonAnimations.deactivateButtonActiveStyle(openingButton)
						end
					end
				else
					-- If menu is not open, just ensure it's hidden
					if target:IsA("CanvasGroup") then
						target.GroupTransparency = 1
					else
						target.Visible = false
					end
					-- Update camera and sound effects immediately
					-- Only apply effects if there was an opening button with "MenuButton" tag
					if not effectsUpdated and openingButton and isMenuButton(openingButton) then
						CameraEffects.updateCameraEffects(menuStates, openMenus)
						SoundEffects.updateSoundEffects(menuStates, openMenus)
						effectsUpdated = true
					end
				end
			end
		end)
	end
end

-- Function to check if a button has StringValue "Animate" with value "Active" or "All"
local function hasActiveAnimation(button)
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("StringValue") and child.Name == "Animate" then
			if child.Value == "Active" or child.Value == "All" then
				return true
			end
		end
	end
	return false
end

-- Function to monitor menu changes and update button states
local function monitorMenuChanges(menu, button)
	if monitoredMenus[menu] then
		return -- Already monitoring this menu
	end

	monitoredMenus[menu] = true

	-- Function to check and update button state
	local function updateButtonState()
		local isOpen = isMenuOpen(menu)

		if isOpen then
			-- Activate button
			if isMenuButton(button) then
				-- Use MenuButton activation system with gradient support
				local elementState = elementStates[button]
				if elementState then
					elementState.isActive = true

					-- Apply size and rotation animation
					Utils.createHoverTween(button, {
						Size = UDim2.new(
							elementState.originalSize.X.Scale * Config.ACTIVATE_SCALE,
							elementState.originalSize.X.Offset * Config.ACTIVATE_SCALE,
							elementState.originalSize.Y.Scale * Config.ACTIVATE_SCALE,
							elementState.originalSize.Y.Offset * Config.ACTIVATE_SCALE
						),
						Rotation = Config.ACTIVATE_ROTATION,
					}):Play()

					-- Handle Icon gradient
					local icon = button:FindFirstChild("Icon")
					if icon and icon:FindFirstChild("UIGradient") then
						icon.UIGradient.Offset = Vector2.new(0, 0.5)
					end

					-- Handle UIStroke gradient animation
					local uiStroke = button:FindFirstChild("UIStroke")
					if uiStroke and uiStroke:FindFirstChild("UIGradient") then
						uiStroke.UIGradient.Enabled = true
						-- Create gradient rotation tween
						local gradientTween = Utils.createTween(
							uiStroke.UIGradient,
							{ Rotation = 180 },
							3,
							Enum.EasingStyle.Linear,
							Enum.EasingDirection.InOut,
							-1
						)
						gradientTween:Play()
						-- Store tween reference for cleanup
						elementState.gradientTween = gradientTween
					end

					-- Set ZIndex to 100 for active state
					button.ZIndex = 100
				end
				buttonStates[button] = true
			else
				local generalElementStates = GeneralButtonAnimations.getElementStates()
				local elementState = generalElementStates[button]
				if elementState then
					elementState.isActive = true
					local frame = button:FindFirstChild("Frame")
					if frame then
						local frameActiveTween = Utils.createTween(frame, {
							Position = UDim2.new(0, -2, 0, 2),
						}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
						frameActiveTween:Play()
					end
					button.ZIndex = 75
				end
			end
		else
			-- Deactivate button
			if isMenuButton(button) then
				-- Use MenuButton deactivation system with gradient cleanup
				local elementState = elementStates[button]
				if elementState then
					elementState.isActive = false

					-- Apply deactivate animation
					Utils.createHoverTween(button, {
						Size = elementState.originalSize,
						Rotation = elementState.originalRotation,
					}):Play()

					-- Restore Icon gradient
					local icon = button:FindFirstChild("Icon")
					if icon and icon:FindFirstChild("UIGradient") then
						icon.UIGradient.Offset = Vector2.new(1, 1)
					end

					-- Stop and disable UIStroke gradient
					local uiStroke = button:FindFirstChild("UIStroke")
					if uiStroke and uiStroke:FindFirstChild("UIGradient") then
						uiStroke.UIGradient.Enabled = false
						if elementState.gradientTween then
							elementState.gradientTween:Cancel()
							elementState.gradientTween = nil
						end
					end

					-- Restore original ZIndex
					button.ZIndex = elementState.originalZIndex
				end
				buttonStates[button] = false
			else
				GeneralButtonAnimations.deactivateButtonActiveStyle(button)
			end
		end
	end

	-- Set up listeners based on menu type
	if menu:IsA("CanvasGroup") then
		-- Monitor GroupTransparency and Visible changes
		local connection1 = menu:GetPropertyChangedSignal("GroupTransparency"):Connect(updateButtonState)
		local connection2 = menu:GetPropertyChangedSignal("Visible"):Connect(updateButtonState)

		menuListeners[menu] = { connection1, connection2 }
	else
		-- Monitor Visible and Size changes
		local connection1 = menu:GetPropertyChangedSignal("Visible"):Connect(updateButtonState)
		local connection2 = menu:GetPropertyChangedSignal("Size"):Connect(updateButtonState)

		menuListeners[menu] = { connection1, connection2 }
	end

	-- Initial check
	updateButtonState()
end

-- Function to automatically activate buttons whose menus are already open
local function checkAndActivateOpenMenus()
	local buttonsProcessed = 0
	local totalButtons = 0
	local buttonsWithAnimate = 0
	local buttonsWithOpen = 0

	-- Get all buttons in PlayerGui
	for _, descendant in ipairs(PlayerGui:GetDescendants()) do
		if descendant:IsA("TextButton") or descendant:IsA("ImageButton") then
			totalButtons = totalButtons + 1

			-- Check for Animate StringValue
			local hasActiveAnimate = hasActiveAnimation(descendant)
			if hasActiveAnimate then
				buttonsWithAnimate = buttonsWithAnimate + 1
				-- Show what Animate value this button has
				for _, child in ipairs(descendant:GetChildren()) do
					if child:IsA("StringValue") and child.Name == "Animate" then
					end
				end
			else
				-- Check what Animate values this button has
				for _, child in ipairs(descendant:GetChildren()) do
					if child:IsA("StringValue") and child.Name == "Animate" then
					end
				end
			end

			-- Check for Open ObjectValue
			local hasOpen = false
			for _, child in ipairs(descendant:GetChildren()) do
				if child:IsA("ObjectValue") and child.Name == "Open" and child.Value then
					hasOpen = true
					buttonsWithOpen = buttonsWithOpen + 1
				end
			end

			-- Only process buttons that have BOTH Animate StringValue with "Active" or "All" AND Open ObjectValue
			if hasActiveAnimate and hasOpen then
				-- Check for Open values
				for _, child in ipairs(descendant:GetChildren()) do
					if child:IsA("ObjectValue") and child.Name == "Open" and child.Value then
						-- Set up monitoring for this menu-button pair
						monitorMenuChanges(child.Value, descendant)
						buttonsProcessed = buttonsProcessed + 1
					end
				end
			end
		end
	end
end

-- Function to clean up menu listeners
local function cleanupMenuListeners()
	for menu, connections in pairs(menuListeners) do
		for _, connection in ipairs(connections) do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end
	end
	menuListeners = {}
	monitoredMenus = {}
end

-- Initialize system
local function initialize()
	-- Wait for PlayerGui to be fully loaded
	PlayerGui:FindFirstChild("ScreenGui")
	for _, button in ipairs(allCloseButtons) do
		if button:IsA("TextButton") or button:IsA("ImageButton") and button.Name == "Close" then
		end
	end

	-- Initialize camera settings
	CameraEffects.initialize()

	-- Initialize sound groups
	SoundEffects.initialize()

	-- Setup buttons with menu functionality and animations
	local function setupButton(button)
		if button:IsA("TextButton") or button:IsA("ImageButton") then
			-- Check if button has ObjectValue "Open" for menu functionality
			local hasOpen = false
			for _, child in ipairs(button:GetChildren()) do
				if child:IsA("ObjectValue") and child.Name == "Open" and child.Value then
					hasOpen = true
					break
				end
			end

			-- Check if button has ObjectValue "Close" for menu functionality
			local hasClose = false
			for _, child in ipairs(button:GetChildren()) do
				if child:IsA("ObjectValue") and child.Name == "Close" and child.Value then
					hasClose = true
					break
				end
			end

			-- Check if button has StringValue "Animate" for animations
			local hasAnimate = false
			for _, child in ipairs(button:GetChildren()) do
				if child:IsA("StringValue") and child.Name == "Animate" then
					hasAnimate = true
					break
				end
			end

			-- Setup menu functionality if it has Open or Close ObjectValue
			if hasOpen or hasClose then
				setupMenuButton(button)
			end

			-- Setup animations if it has Animate StringValue
			if hasAnimate then
				-- Use different animation systems based on MenuButton tag
				if isMenuButton(button) then
					-- Use MenuButton animations for elements with MenuButton tag
					ButtonAnimations.setupAnimatedElement(button, elementStates)
				else
					-- Use general animations for elements without MenuButton tag
					GeneralButtonAnimations.setupAnimatedElement(button)
				end
			end
		end
	end

	-- Check all descendants of PlayerGui
	for _, descendant in ipairs(PlayerGui:GetDescendants()) do
		setupButton(descendant)
	end

	-- Listen for new buttons
	PlayerGui.DescendantAdded:Connect(function(descendant)
		setupButton(descendant)

		-- Also check if this new button needs menu monitoring
		if descendant:IsA("TextButton") or descendant:IsA("ImageButton") then
			local hasActiveAnimate = hasActiveAnimation(descendant)
			if hasActiveAnimate then
				for _, child in ipairs(descendant:GetChildren()) do
					if child:IsA("ObjectValue") and child.Name == "Open" and child.Value then
						monitorMenuChanges(child.Value, descendant)
					end
				end
			end
		end
	end)

	-- Check for already open menus and activate corresponding buttons
	-- Wait longer to ensure all UI is loaded
	wait(2)
	checkAndActivateOpenMenus()

	-- Also check again after a longer delay to catch any late-loading UI
	spawn(function()
		wait(5)
		checkAndActivateOpenMenus()
	end)
end

-- Force camera effects test
_G.ForceCameraEffects = function(enable)
	if enable then
		CameraEffects.forceCameraEffects(true)
	else
		CameraEffects.forceCameraEffects(false)
	end
end

-- Test FOV override system
_G.TestFovOverride = function(enable, fovValue)
	if enable then
		CameraEffects.testFovOverride(true, fovValue)
	else
		CameraEffects.testFovOverride(false, 70)
	end
end

-- Cleanup function for menu listeners
_G.CleanupMenuListeners = function()
	cleanupMenuListeners()
end

-- Start the system
initialize()
