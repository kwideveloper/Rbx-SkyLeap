-- MenuAnimator.client.lua
-- Handles UI animations and interactions for elements with specific tags and values
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")

-- Configuration constants
local HOVER_SCALE = 1.08
local HOVER_ROTATION = 2
local CLICK_Y_OFFSET = 3
local CLICK_SCALE = 0.95
local ACTIVATE_ROTATION = -8
local ACTIVATE_SCALE = 1.12
local ANIMATION_DURATION = 0.25
local MENU_ANIMATION_DURATION = 0.4 -- 0.4
local MENU_CLOSE_ANIMATION_DURATION = 0.25 -- Tiempo más rápido para cerrar el menú
local BOUNCE_DURATION = 0.15

-- Camera effects constants
local BLUR_SIZE = 15 -- Maximum blur size when menu is open
local DEFAULT_FOV = 70 -- Default camera FOV
local MENU_FOV = 50 -- FOV when menu is open
local CAMERA_EFFECT_DURATION = 0.5 -- Duration for camera effects

-- Animation states
local elementStates = {}
local menuStates = {}

-- Menu management system
local openMenus = {} -- Track which menus are currently open {menu = button}
local buttonStates = {} -- Track button active states {button = isActive}

-- Camera effects system
local camera = Workspace.CurrentCamera
local blurEffect = nil
local cameraEffectActive = false

-- Utility functions
local function createTween(instance, properties, duration, easingStyle, easingDirection)
	easingStyle = easingStyle or Enum.EasingStyle.Back
	easingDirection = easingDirection or Enum.EasingDirection.Out
	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
	return TweenService:Create(instance, tweenInfo, properties)
end

local function createBounceTween(instance, originalPosition)
	local tweenInfo = TweenInfo.new(BOUNCE_DURATION, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.3)
	return TweenService:Create(instance, tweenInfo, { Position = originalPosition })
end

local function createHoverTween(instance, properties)
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0)
	return TweenService:Create(instance, tweenInfo, properties)
end

local function createClickTween(instance, properties)
	local tweenInfo = TweenInfo.new(ANIMATION_DURATION * 0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	return TweenService:Create(instance, tweenInfo, properties)
end

-- Camera effects functions
local function createBlurEffect()
	if blurEffect then
		return
	end

	blurEffect = Instance.new("BlurEffect")
	blurEffect.Size = 0
	blurEffect.Parent = camera
end

local function ensureClientStateFolder()
	local cs = ReplicatedStorage:FindFirstChild("ClientState")
	if not cs then
		cs = Instance.new("Folder")
		cs.Name = "ClientState"
		cs.Parent = ReplicatedStorage
	end
	return cs
end

local function setFovOverride(enable, fovValue)
	local cs = ensureClientStateFolder()

	-- Create or update CameraFovOverrideActive
	local fovOverrideActive = cs:FindFirstChild("CameraFovOverrideActive")
	if not fovOverrideActive then
		fovOverrideActive = Instance.new("BoolValue")
		fovOverrideActive.Name = "CameraFovOverrideActive"
		fovOverrideActive.Parent = cs
	end
	fovOverrideActive.Value = enable

	-- Create or update CameraFovOverrideValue
	local fovOverrideValue = cs:FindFirstChild("CameraFovOverrideValue")
	if not fovOverrideValue then
		fovOverrideValue = Instance.new("NumberValue")
		fovOverrideValue.Name = "CameraFovOverrideValue"
		fovOverrideValue.Parent = cs
	end
	fovOverrideValue.Value = fovValue
end

local function applyCameraEffects(enable)
	if not camera then
		return
	end

	-- Create blur effect if it doesn't exist
	if not blurEffect then
		createBlurEffect()
	end

	local targetBlurSize = enable and BLUR_SIZE or 0

	-- Animate blur
	local blurTween = createTween(blurEffect, { Size = targetBlurSize }, CAMERA_EFFECT_DURATION)
	blurTween:Play()

	-- Set FOV override using ClientState system (integrates with CameraDynamics)
	if enable then
		setFovOverride(true, MENU_FOV)
	else
		setFovOverride(false, DEFAULT_FOV)
	end

	-- Store effect state
	cameraEffectActive = enable
end

local function updateCameraEffects()
	-- Check if any menus are open by checking menu states
	local hasOpenMenus = false
	local openMenuCount = 0
	local totalMenus = 0
	local openMenuNames = {}

	for menu, menuState in pairs(menuStates) do
		totalMenus = totalMenus + 1
		if menuState.isOpen then
			hasOpenMenus = true
			openMenuCount = openMenuCount + 1
			table.insert(openMenuNames, menu.Name or "UnnamedMenu")
		end
	end

	-- Apply or remove camera effects based on menu state
	if hasOpenMenus and not cameraEffectActive then
		applyCameraEffects(true)
	elseif not hasOpenMenus and cameraEffectActive then
		applyCameraEffects(false)
	end
end

-- Menu management functions
local function resetButtonState(button)
	if buttonStates[button] then
		local elementState = elementStates[button]
		if elementState then
			elementState.isActive = false
			createHoverTween(button, {
				Size = elementState.originalSize,
				Rotation = elementState.originalRotation,
			}):Play()

			-- Restore original ZIndex
			button.ZIndex = elementState.originalZIndex
		end
		buttonStates[button] = false
	end
end

local function setButtonActive(button)
	if not buttonStates[button] then
		local elementState = elementStates[button]
		if elementState then
			elementState.isActive = true
			createHoverTween(button, {
				Size = UDim2.new(
					elementState.originalSize.X.Scale * ACTIVATE_SCALE,
					elementState.originalSize.X.Offset * ACTIVATE_SCALE,
					elementState.originalSize.Y.Scale * ACTIVATE_SCALE,
					elementState.originalSize.Y.Offset * ACTIVATE_SCALE
				),
				Rotation = ACTIVATE_ROTATION,
			}):Play()

			-- Set ZIndex to 100 for active state
			button.ZIndex = 100
		end
		buttonStates[button] = true
	end
end

local function getAllTargetMenus(button)
	local menus = {}
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("ObjectValue") and child.Name == "Open" and child.Value then
			table.insert(menus, child.Value)
		end
	end
	return menus
end

local function getOpenMenus(button)
	local openMenusList = {}
	for menu, associatedButton in pairs(openMenus) do
		if associatedButton ~= button then
			table.insert(openMenusList, menu)
		end
	end
	return openMenusList
end

local function getIgnoredMenus(button)
	local ignoredMenus = {}
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("ObjectValue") and child.Name == "Ignore" and child.Value then
			table.insert(ignoredMenus, child.Value)
		end
	end
	return ignoredMenus
end

local function shouldIgnoreMenu(menu, ignoredMenus)
	for _, ignoredMenu in ipairs(ignoredMenus) do
		if ignoredMenu == menu then
			return true
		end
	end
	return false
end

local function closeAllOtherMenus(exceptMenu, button)
	local menusToClose = getOpenMenus(button)
	local ignoredMenus = getIgnoredMenus(button)
	local firstMenuClosed = false

	for _, menu in ipairs(menusToClose) do
		if menu ~= exceptMenu and not shouldIgnoreMenu(menu, ignoredMenus) then
			local associatedButton = openMenus[menu]
			if associatedButton and menuStates[menu] then
				-- Mark as closed first
				local state = menuStates[menu]
				state.isOpen = false
				openMenus[menu] = nil

				-- Apply camera effects immediately when first menu is closed
				if not firstMenuClosed then
					updateCameraEffects()
					firstMenuClosed = true
				end

				-- Close the menu
				local direction = "Top" -- Default direction, could be enhanced to store direction per menu
				closeMenu(menu, direction, state)

				-- Reset button state
				resetButtonState(associatedButton)
			end
		end
	end
end

-- Handle animated elements (Hover, Click, Activate)
local function setupAnimatedElement(element)
	local state = {
		isActive = false,
		originalSize = element.Size,
		originalPosition = element.Position,
		originalRotation = element.Rotation or 0,
		originalZIndex = element.Parent.ZIndex,
	}
	elementStates[element] = state

	-- Check for animation types
	local hasHover = false
	local hasClick = false
	local hasActivate = false

	for _, child in ipairs(element:GetChildren()) do
		if child:IsA("StringValue") then
			if child.Value == "Hover" then
				hasHover = true
			elseif child.Value == "Click" then
				hasClick = true
			elseif child.Value == "Activate" then
				hasActivate = true
			end
		end
	end

	-- Setup hover animations
	if hasHover then
		element.MouseEnter:Connect(function()
			if not state.isActive then
				local hoverTween = createHoverTween(element, {
					Size = UDim2.new(
						state.originalSize.X.Scale * HOVER_SCALE,
						state.originalSize.X.Offset * HOVER_SCALE,
						state.originalSize.Y.Scale * HOVER_SCALE,
						state.originalSize.Y.Offset * HOVER_SCALE
					),
					Rotation = HOVER_ROTATION,
				})
				hoverTween:Play()

				-- Set ZIndex to 100 for hover effect
				element.Parent.ZIndex = 100
			end
		end)

		element.MouseLeave:Connect(function()
			if not state.isActive then
				local leaveTween = createHoverTween(element, {
					Size = state.originalSize,
					Rotation = state.originalRotation,
				})
				leaveTween:Play()

				-- Restore original ZIndex
				element.Parent.ZIndex = state.originalZIndex
			end
		end)
	end

	-- Setup click animations
	if hasClick then
		element.MouseButton1Click:Connect(function()
			if not state.isActive then
				-- Click down animation
				local clickDownTween = createClickTween(element, {
					Position = UDim2.new(
						state.originalPosition.X.Scale,
						state.originalPosition.X.Offset,
						state.originalPosition.Y.Scale,
						state.originalPosition.Y.Offset + CLICK_Y_OFFSET
					),
					Size = UDim2.new(
						state.originalSize.X.Scale * CLICK_SCALE,
						state.originalSize.X.Offset * CLICK_SCALE,
						state.originalSize.Y.Scale * CLICK_SCALE,
						state.originalSize.Y.Offset * CLICK_SCALE
					),
				})

				clickDownTween:Play()
				clickDownTween.Completed:Wait()

				-- Click up animation with bounce
				local clickUpTween = createClickTween(element, {
					Position = state.originalPosition,
					Size = state.originalSize,
				})
				clickUpTween:Play()
			end
		end)
	end

	-- Setup activate animations
	if hasActivate then
		element.MouseButton1Click:Connect(function()
			state.isActive = not state.isActive

			if state.isActive then
				-- Activate state with enhanced animation
				createHoverTween(element, {
					Size = UDim2.new(
						state.originalSize.X.Scale * ACTIVATE_SCALE,
						state.originalSize.X.Offset * ACTIVATE_SCALE,
						state.originalSize.Y.Scale * ACTIVATE_SCALE,
						state.originalSize.Y.Offset * ACTIVATE_SCALE
					),
					Rotation = ACTIVATE_ROTATION,
				}):Play()

				-- Set ZIndex to 100 for active state
				element.ZIndex = 100
			else
				-- Deactivate state
				createHoverTween(element, {
					Size = state.originalSize,
					Rotation = state.originalRotation,
				}):Play()

				-- Restore original ZIndex
				element.ZIndex = state.originalZIndex
			end
		end)
	end
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
		local targetMenus = getAllTargetMenus(button)
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
			local menuState = {
				isOpen = false,
				originalPosition = targetMenu.Position,
				canvasGroup = targetMenu,
			}
			menuStatesForButton[targetMenu] = menuState
			menuStates[targetMenu] = menuState -- Use targetMenu as key for unique state tracking
		end

		button.MouseButton1Click:Connect(function()
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
				-- Close all other menus first
				for _, targetMenu in ipairs(targetMenus) do
					closeAllOtherMenus(targetMenu, button)
				end

				-- Open all target menus
				local firstMenuOpened = false
				for _, targetMenu in ipairs(targetMenus) do
					local menuState = menuStatesForButton[targetMenu]
					if not menuState.isOpen then
						menuState.isOpen = true
						openMenus[targetMenu] = button

						-- Apply camera effects immediately when first menu is opened
						if not firstMenuOpened then
							updateCameraEffects()
							firstMenuOpened = true
						end
						openMenu(targetMenu, animationDirection, menuState)
					end
				end

				-- Set button as active
				setButtonActive(button)
			else
				-- Close all target menus
				local firstMenuClosed = false
				for _, targetMenu in ipairs(targetMenus) do
					local menuState = menuStatesForButton[targetMenu]
					if menuState.isOpen then
						menuState.isOpen = false
						openMenus[targetMenu] = nil

						-- Apply camera effects immediately when first menu is closed
						if not firstMenuClosed then
							updateCameraEffects()
							firstMenuClosed = true
						end

						closeMenu(targetMenu, animationDirection, menuState)
					end
				end

				-- Reset button state
				resetButtonState(button)
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
				-- Find the button that opened this menu
				local openingButton = openMenus[target]
				if openingButton then
					local menuState = menuStates[target] -- Use target menu as key
					if menuState and menuState.isOpen then
						-- Mark as closed first
						menuState.isOpen = false
						openMenus[target] = nil

						-- Update camera effects immediately when first menu is closed
						if not effectsUpdated then
							updateCameraEffects()
							effectsUpdated = true
						end

						-- Close the menu with animation if it's a CanvasGroup
						local direction = "Top" -- Default direction
						closeMenu(target, direction, menuState)

						-- Reset button state
						resetButtonState(openingButton)
					else
						-- If not a CanvasGroup or no animation state, just hide it
						if target:IsA("CanvasGroup") then
							target.GroupTransparency = 1
						else
							target.Visible = false
						end
						-- Update camera effects immediately
						if not effectsUpdated then
							updateCameraEffects()
							effectsUpdated = true
						end
					end
				else
					-- If no opening button found, just hide it
					if target:IsA("CanvasGroup") then
						target.GroupTransparency = 1
					else
						target.Visible = false
					end
					-- Update camera effects immediately
					if not effectsUpdated then
						updateCameraEffects()
						effectsUpdated = true
					end
				end
			end
		end)
	end
end

function openMenu(menu, direction, state)
	-- Set initial state - handle both CanvasGroup and regular GuiObjects
	if state.canvasGroup:IsA("CanvasGroup") then
		state.canvasGroup.GroupTransparency = 1
	else
		menu.Visible = false
	end

	-- Move to center of screen
	local centerPosition = UDim2.new(0.5, 0, 0.5, 0)
	local startPosition = getStartPosition(centerPosition, direction)
	menu.Position = startPosition

	-- Animate in
	local moveTween = createTween(menu, { Position = centerPosition }, MENU_ANIMATION_DURATION)

	local fadeTween
	if state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = createTween(state.canvasGroup, { GroupTransparency = 0 }, MENU_ANIMATION_DURATION)
	else
		-- For non-CanvasGroup, just make it visible immediately
		menu.Visible = true
	end

	if fadeTween then
		fadeTween:Play()
	end
	moveTween:Play()

	local hasStroke = state.canvasGroup:FindFirstChild("UIStroke")

	if hasStroke then
		local fadeStroke = createTween(hasStroke, { Transparency = 0 }, MENU_ANIMATION_DURATION)
		fadeStroke:Play()
	end

	-- Bounce effect at the end
	moveTween.Completed:Wait()
	createBounceTween(menu, centerPosition):Play()
end

function closeMenu(menu, direction, state)
	-- Get the opposite direction for closing animation
	local closeDirection = getOppositeDirection(direction)
	local endPosition = getStartPosition(menu.Position, closeDirection)

	-- Animate out
	local moveTween = createTween(
		menu,
		{ Position = endPosition },
		MENU_CLOSE_ANIMATION_DURATION,
		Enum.EasingStyle.Exponential,
		Enum.EasingDirection.Out
	)

	local fadeTween
	if state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = createTween(
			state.canvasGroup,
			{ GroupTransparency = 1 },
			MENU_CLOSE_ANIMATION_DURATION,
			Enum.EasingStyle.Exponential,
			Enum.EasingDirection.Out
		)
	else
		-- For non-CanvasGroup, just hide it at the end of movement
		moveTween.Completed:Connect(function()
			menu.Visible = false
		end)
	end

	local hasStroke = state.canvasGroup:FindFirstChild("UIStroke")

	if hasStroke then
		local fadeStroke = createTween(
			hasStroke,
			{ Transparency = 1 },
			MENU_CLOSE_ANIMATION_DURATION,
			Enum.EasingStyle.Exponential,
			Enum.EasingDirection.Out
		)
		fadeStroke:Play()
	end

	if fadeTween then
		fadeTween:Play()
	end
	moveTween:Play()

	-- Reset to original position after animation
	moveTween.Completed:Connect(function()
		menu.Position = state.originalPosition
	end)
end

function getOppositeDirection(direction)
	if direction == "Top" then
		return "Top" -- If it appears from bottom to center, it should disappear from center to bottom
	elseif direction == "Bottom" then
		return "Bottom" -- If it appears from top to center, it should disappear from center to top
	elseif direction == "Left" then
		return "Left" -- If it appears from right to center, it should disappear from center to right
	elseif direction == "Right" then
		return "Right" -- If it appears from left to center, it should disappear from center to left
	end
	return "Top" -- Default: appears from bottom, disappears to bottom
end

function getStartPosition(originalPos, direction)
	if direction == "Top" then
		return UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale, originalPos.Y.Offset + 80)
	elseif direction == "Bottom" then
		return UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale, originalPos.Y.Offset - 80)
	elseif direction == "Left" then
		return UDim2.new(originalPos.X.Scale, originalPos.X.Offset - 80, originalPos.Y.Scale, originalPos.Y.Offset)
	elseif direction == "Right" then
		return UDim2.new(originalPos.X.Scale, originalPos.X.Offset + 80, originalPos.Y.Scale, originalPos.Y.Offset)
	end
	return UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale, originalPos.Y.Offset + 80) -- Default bottom to top
end

function getEndPosition(originalPos, direction)
	if direction == "Top" then
		return UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale, originalPos.Y.Offset - 80)
	elseif direction == "Bottom" then
		return UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale, originalPos.Y.Offset + 80)
	elseif direction == "Left" then
		return UDim2.new(originalPos.X.Scale, originalPos.X.Offset + 80, originalPos.Y.Scale, originalPos.Y.Offset)
	elseif direction == "Right" then
		return UDim2.new(originalPos.X.Scale, originalPos.X.Offset - 80, originalPos.Y.Scale, originalPos.Y.Offset)
	end
	return UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale, originalPos.Y.Offset - 80) -- Default bottom to top
end

-- Initialize system
local function initialize()
	-- Wait for PlayerGui to be fully loaded
	PlayerGui:FindFirstChild("ScreenGui")

	-- Initialize camera settings
	if camera then
		-- Set initial FOV override to ensure CameraDynamics integration
		setFovOverride(false, DEFAULT_FOV)
	end

	-- Setup animated elements
	CollectionService:GetInstanceAddedSignal("Animated"):Connect(function(element)
		if element:IsA("GuiObject") then
			setupAnimatedElement(element)
		end
	end)

	-- Setup existing animated elements
	for _, element in ipairs(CollectionService:GetTagged("Animated")) do
		if element:IsA("GuiObject") then
			setupAnimatedElement(element)
		end
	end

	-- Setup menu buttons
	local function setupButton(button)
		if button:IsA("TextButton") or button:IsA("ImageButton") then
			setupMenuButton(button)
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
		applyCameraEffects(true)
	else
		applyCameraEffects(false)
	end
end

-- Test FOV override system
_G.TestFovOverride = function(enable, fovValue)
	if enable then
		setFovOverride(true, fovValue)
	else
		setFovOverride(false, 70)
	end
end

-- Start the system
initialize()
