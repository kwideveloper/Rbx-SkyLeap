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

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
local PlayerScripts = LocalPlayer:FindFirstChild("PlayerScripts")

local allCloseButtons = PlayerGui:GetChildren()

-- Animation states
local elementStates = {}
local menuStates = {}

-- Get references to shared state tables
local openMenus = MenuManager.getOpenMenusTable()
local buttonStates = MenuManager.getButtonStatesTable()
local menuOriginalPositions = MenuManager.getMenuOriginalPositionsTable()

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

			-- If Toggle is false and any target menu is already open, don't do anything
			if hasToggleOff then
				local anyMenuOpen = false
				for _, targetMenu in ipairs(targetMenus) do
					local menuState = menuStatesForButton[targetMenu]
					if menuState and menuState.isOpen then
						anyMenuOpen = true
						break
					end
				end
				if anyMenuOpen then
					return -- Don't close or re-open, just return
				end
			end

			local isOpening = false

			-- Check if we're opening or closing
			for _, targetMenu in ipairs(targetMenus) do
				local menuState = menuStatesForButton[targetMenu]
				if not menuState.isOpen then
					isOpening = true
					break
				end
			end

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
			else
				-- Close all target menus, but check Toggle setting first
				local shouldClose = true

				-- If Toggle is false, don't close menus that are already open
				if hasToggleOff then
					local anyMenuOpen = false
					for _, targetMenu in ipairs(targetMenus) do
						local menuState = menuStatesForButton[targetMenu]
						if menuState and menuState.isOpen then
							anyMenuOpen = true
							break
						end
					end
					if anyMenuOpen then
						shouldClose = false -- Don't close if Toggle is false and menus are open
					end
				end

				if shouldClose then
					local firstMenuClosed = false
					for _, targetMenu in ipairs(targetMenus) do
						local menuState = menuStatesForButton[targetMenu]
						if menuState.isOpen then
							menuState.isOpen = false
							MenuManager.clearOpenMenus(targetMenu)

							-- Apply camera and sound effects immediately when first menu is closed
							-- Only apply effects if the button that opened this menu has "MenuButton" tag
							if not firstMenuClosed and isMenuButton(button) then
								CameraEffects.updateCameraEffects(menuStates, openMenus)
								SoundEffects.updateSoundEffects(menuStates, openMenus)
								firstMenuClosed = true
							end

							MenuAnimations.closeMenu(targetMenu, animationDirection, menuState, menuOriginalPositions)
						end
					end

					-- Reset button state
					MenuManager.resetButtonState(button, elementStates)
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

					-- Close the menu with animation
					if menuState then
						-- Use existing menu state for animation
						local direction = "Top" -- Default direction
						MenuAnimations.closeMenu(target, direction, menuState, menuOriginalPositions)
					else
						-- Create temporary state for animation if none exists
						local tempState = {
							canvasGroup = target:IsA("CanvasGroup") and target or target,
							originalPosition = target.Position,
						}
						local direction = "Top" -- Default direction
						MenuAnimations.closeMenu(target, direction, tempState, menuOriginalPositions)
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

-- Initialize system
local function initialize()
	-- Wait for PlayerGui to be fully loaded
	PlayerGui:FindFirstChild("ScreenGui")
	for _, button in ipairs(allCloseButtons) do
		if button:IsA("TextButton") or button:IsA("ImageButton") and button.Name == "Close" then
			print("Close button found:", button)
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

-- Start the system
initialize()
