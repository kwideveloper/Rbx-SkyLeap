-- MenuAnimator.client.lua
-- Handles UI animations and interactions for buttons with ObjectValue "Open" and StringValue "Animate" children
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
local PlayerScripts = LocalPlayer:FindFirstChild("PlayerScripts")

local allCloseButtons = PlayerGui:GetChildren()

-- Configuration constants
local HOVER_SCALE = 1.08
local HOVER_ROTATION = 3
local CLICK_Y_OFFSET = 3
local CLICK_SCALE = 0.95
local ACTIVATE_ROTATION = -3
local ACTIVATE_SCALE = 1.12
local ANIMATION_DURATION = 0.25
local MENU_ANIMATION_DURATION = 0.4 -- 0.4
local MENU_CLOSE_ANIMATION_DURATION = 0.25 -- Tiempo más rápido para cerrar el menú
local BOUNCE_DURATION = 0.15
local VOLUME_TO_REDUCE = 0.1

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

-- Sound effects system
local backgroundMusicGroup = nil
local sfxGroup = nil
local soundEffectActive = false
local originalVolumesCaptured = false -- Flag to track if we captured original volumes
local isRestoringVolumes = false -- Flag to prevent listener updates during volume restoration
local originalMusicVolumes = {} -- Store original volumes (captured once)
local originalSFXVolume = 0.5
local originalBGVolume = 0.5 -- Separate variable for BG Music when it's a SoundGroup

-- Utility functions
local function createTween(instance, properties, duration, easingStyle, easingDirection, repeatCount)
	easingStyle = easingStyle or Enum.EasingStyle.Back
	easingDirection = easingDirection or Enum.EasingDirection.Out
	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection, repeatCount or 0)
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

-- Sound effects functions
local function initializeSoundGroups()
	if not PlayerScripts then
		return
	end

	local soundsFolder = PlayerScripts:FindFirstChild("Sounds")
	if not soundsFolder then
		return
	end

	backgroundMusicGroup = soundsFolder:FindFirstChild("BackgroundMusic")
	sfxGroup = soundsFolder:FindFirstChild("SFX")

	-- Add listeners for volume changes to capture dynamic volume updates
	if backgroundMusicGroup then
		if backgroundMusicGroup:IsA("SoundGroup") then
			backgroundMusicGroup:GetPropertyChangedSignal("Volume"):Connect(function()
				-- Only update original volume if:
				-- 1. Effects are not active (no system changes happening)
				-- 2. Volumes haven't been captured yet (initial setup)
				-- 3. We're not in the middle of restoring volumes
				if not soundEffectActive and not originalVolumesCaptured and not isRestoringVolumes then
					-- Update original volume when user changes it BEFORE we capture (for next effect application)
					local oldValue = originalBGVolume
					originalBGVolume = backgroundMusicGroup.Volume
				end
			end)
		elseif backgroundMusicGroup:IsA("Folder") then
			for _, sound in ipairs(backgroundMusicGroup:GetChildren()) do
				if sound:IsA("Sound") then
					sound:GetPropertyChangedSignal("Volume"):Connect(function()
						if not soundEffectActive and not originalVolumesCaptured and not isRestoringVolumes then
							local oldValue = originalMusicVolumes[sound] or 0
							originalMusicVolumes[sound] = sound.Volume
						end
					end)
				end
			end
		end
	end

	if sfxGroup and sfxGroup:IsA("SoundGroup") then
		sfxGroup:GetPropertyChangedSignal("Volume"):Connect(function()
			if not soundEffectActive and not originalVolumesCaptured and not isRestoringVolumes then
				local oldValue = originalSFXVolume
				originalSFXVolume = sfxGroup.Volume
			end
		end)
	end

	-- Capture initial volumes to ensure we have the correct baseline
	if backgroundMusicGroup and backgroundMusicGroup:IsA("SoundGroup") and not originalVolumesCaptured then
		originalBGVolume = backgroundMusicGroup.Volume
	end

	if sfxGroup and sfxGroup:IsA("SoundGroup") and not originalVolumesCaptured then
		originalSFXVolume = sfxGroup.Volume
	end

	-- Sound groups are now initialized but volumes are captured dynamically when effects are applied
end

local function applyClubEffects(enable)
	if not backgroundMusicGroup and not sfxGroup then
		warn("[Sound] No sound groups found")
		return
	end

	if enable and not soundEffectActive then
		-- Enable existing MenuOpened equalizer effects
		local function enableMenuEffect(soundGroup)
			if not soundGroup then
				return
			end

			local menuEffect = soundGroup:FindFirstChild("MenuOpened")
			if menuEffect and menuEffect:IsA("EqualizerSoundEffect") then
				menuEffect.Enabled = true
			end
		end

		-- Enable effects on both groups
		enableMenuEffect(backgroundMusicGroup)
		enableMenuEffect(sfxGroup)

		-- CAPTURE ORIGINAL VOLUMES ONLY ONCE (like blur/FOV system)
		-- Only capture if we haven't captured them before (first time EVER activating effects)
		if not originalVolumesCaptured then
			if backgroundMusicGroup then
				if backgroundMusicGroup:IsA("SoundGroup") then
					originalBGVolume = backgroundMusicGroup.Volume
				end
			end

			if sfxGroup and sfxGroup:IsA("SoundGroup") then
				originalSFXVolume = sfxGroup.Volume
			end

			originalVolumesCaptured = true -- Mark as captured for this session
		end

		-- Reduce volume by 0.2 (less reduction for more noticeable effects) from ORIGINAL values with smooth transition
		local volumeTweenDuration = 0.5 -- Duration for volume transitions

		if backgroundMusicGroup then
			if backgroundMusicGroup:IsA("SoundGroup") then
				local targetVolume = math.max(0, originalBGVolume - VOLUME_TO_REDUCE)
				local volumeTween = createTween(backgroundMusicGroup, { Volume = targetVolume }, volumeTweenDuration)
				volumeTween:Play()
			end
		end

		if sfxGroup and sfxGroup:IsA("SoundGroup") then
			local targetVolume = math.max(0, originalSFXVolume - VOLUME_TO_REDUCE)
			local volumeTween = createTween(sfxGroup, { Volume = targetVolume }, volumeTweenDuration)
			volumeTween:Play()
		end

		soundEffectActive = true
	elseif not enable and soundEffectActive then
		-- Disable existing MenuOpened equalizer effects
		local function disableMenuEffect(soundGroup)
			if not soundGroup then
				return
			end

			local menuEffect = soundGroup:FindFirstChild("MenuOpened")
			if menuEffect and menuEffect:IsA("EqualizerSoundEffect") then
				menuEffect.Enabled = false
			end
		end

		disableMenuEffect(backgroundMusicGroup)
		disableMenuEffect(sfxGroup)

		-- Set flag to prevent listeners from updating during restoration
		isRestoringVolumes = true

		-- Restore ORIGINAL volumes (the volumes before effects were applied) with smooth transition
		local volumeTweenDuration = 0.5 -- Duration for volume transitions

		if backgroundMusicGroup then
			if backgroundMusicGroup:IsA("SoundGroup") then
				local volumeTween =
					createTween(backgroundMusicGroup, { Volume = originalBGVolume }, volumeTweenDuration)
				volumeTween:Play()
			end
		end

		if sfxGroup and sfxGroup:IsA("SoundGroup") then
			local volumeTween = createTween(sfxGroup, { Volume = originalSFXVolume }, volumeTweenDuration)
			volumeTween:Play()
		end

		-- Clear original music volumes (individual sounds)
		originalMusicVolumes = {}
		-- NOTE: originalSFXVolume and originalBGVolume stay as captured values
		-- NOTE: originalVolumesCaptured stays true so we keep the captured state across menu transitions

		-- Reset restoration flag
		isRestoringVolumes = false

		soundEffectActive = false
	end
end

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

local function updateSoundEffects()
	-- Check if any non-settings menus are open - apply effects for any menu except settings
	local hasNonSettingsMenus = false
	for menu, state in pairs(menuStates) do
		if state.isOpen and not isSettingsMenu(menu) then
			hasNonSettingsMenus = true
			break
		end
	end

	-- Apply or remove sound effects based on non-settings menu state
	if hasNonSettingsMenus and not soundEffectActive then
		applyClubEffects(true)
	elseif not hasNonSettingsMenus and soundEffectActive then
		applyClubEffects(false)
	end
end

-- Menu management functions
-- Function to deactivate button's "Active" style (for when menu closes externally)
local function deactivateButtonActiveStyle(button)
	local elementState = elementStates[button]

	-- Always try to deactivate, regardless of current isActive state
	if elementState then
		elementState.isActive = false

		-- Apply deactivate animation
		createHoverTween(button, {
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

		if uiStroke then
			button.UIStroke.UIGradient.Enabled = false
		end

		-- Restore original ZIndex
		button.ZIndex = elementState.originalZIndex
	end
end

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

	-- Also deactivate any active style
	deactivateButtonActiveStyle(button)
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

				-- Apply camera and sound effects immediately when first menu is closed
				if not firstMenuClosed then
					updateCameraEffects()
					updateSoundEffects()
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

-- Handle animated elements (Hover, Click, Active)
local function setupAnimatedElement(element)
	local state = {
		isActive = false,
		originalSize = element.Size,
		originalPosition = element.Position,
		originalRotation = element.Rotation or 0,
		originalZIndex = element.Parent.ZIndex,
	}
	elementStates[element] = state

	-- Check for animation types by looking for StringValue children named "Animate"
	local hasHover = false
	local hasClick = false
	local hasActive = false
	local icon = element:FindFirstChild("Icon")

	for _, child in ipairs(element:GetChildren()) do
		if child:IsA("StringValue") and child.Name == "Animate" then
			if child.Value == "Hover" then
				hasHover = true
			elseif child.Value == "Click" then
				hasClick = true
			elseif child.Value == "Active" then
				hasActive = true
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
				-- Animate icon (If exists)
				if icon then
					local tween = createTween(
						icon.UIGradient,
						{ Offset = Vector2.new(0, 0.5) },
						0.2,
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.InOut
					)
					tween:Play()
				end
				---

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

				-- Animate icon (If exists)
				if icon then
					local tween = createTween(
						icon.UIGradient,
						{ Offset = Vector2.new(1, 1) },
						0.2,
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.Out
					)
					tween:Play()
				end
				--
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

	local activeGradientTween = createTween(
		element.UIStroke.UIGradient,
		{ Rotation = 180 },
		3,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut,
		-1
	)

	-- Setup active animations
	if hasActive then
		element.MouseButton1Click:Connect(function()
			state.isActive = not state.isActive

			if state.isActive then
				-- Active state with enhanced animation
				createHoverTween(element, {
					Size = UDim2.new(
						state.originalSize.X.Scale * ACTIVATE_SCALE,
						state.originalSize.X.Offset * ACTIVATE_SCALE,
						state.originalSize.Y.Scale * ACTIVATE_SCALE,
						state.originalSize.Y.Offset * ACTIVATE_SCALE
					),
					Rotation = ACTIVATE_ROTATION,
				}):Play()

				-- Setting hover State for Icon
				if icon then
					icon.UIGradient.Offset = Vector2.new(0, 0.5)
				end

				-- Active Gradient
				element.UIStroke.UIGradient.Enabled = true
				activeGradientTween:Play()
				--

				-- Set ZIndex to 100 for active state
				element.ZIndex = 100
			else
				-- Deactivate state
				createHoverTween(element, {
					Size = state.originalSize,
					Rotation = state.originalRotation,
				}):Play()

				if icon then
					-- Restore hover State for Icon
					icon.UIGradient.Offset = Vector2.new(1, 1)
				end

				element.UIStroke.UIGradient.Enabled = false
				activeGradientTween:Cancel()

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

						-- Apply camera and sound effects immediately when first menu is opened
						if not firstMenuOpened then
							updateCameraEffects()
							updateSoundEffects()
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

						-- Apply camera and sound effects immediately when first menu is closed
						if not firstMenuClosed then
							updateCameraEffects()
							updateSoundEffects()
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
					-- Find the button that opened this menu (if any)
					local openingButton = openMenus[target]

					-- Mark as closed first
					if menuState then
						menuState.isOpen = false
					end
					openMenus[target] = nil

					-- Update camera and sound effects immediately when first menu is closed
					if not effectsUpdated then
						updateCameraEffects()
						updateSoundEffects()
						effectsUpdated = true
					end

					-- Close the menu with animation
					if menuState then
						-- Use existing menu state for animation
						local direction = "Top" -- Default direction
						closeMenu(target, direction, menuState)
					else
						-- Create temporary state for animation if none exists
						local tempState = {
							canvasGroup = target:IsA("CanvasGroup") and target or target,
							originalPosition = target.Position,
						}
						local direction = "Top" -- Default direction
						closeMenu(target, direction, tempState)
					end

					-- Reset button state if we found the opening button
					if openingButton then
						resetButtonState(openingButton)
					end
				else
					-- If menu is not open, just ensure it's hidden
					if target:IsA("CanvasGroup") then
						target.GroupTransparency = 1
					else
						target.Visible = false
					end
					-- Update camera and sound effects immediately
					if not effectsUpdated then
						updateCameraEffects()
						updateSoundEffects()
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
	if state and state.canvasGroup and state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = createTween(
			state.canvasGroup,
			{ GroupTransparency = 1 },
			MENU_CLOSE_ANIMATION_DURATION,
			Enum.EasingStyle.Exponential,
			Enum.EasingDirection.Out
		)
	elseif menu:IsA("CanvasGroup") then
		-- If no state but menu is CanvasGroup, animate it directly
		fadeTween = createTween(
			menu,
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

	local hasStroke = menu:FindFirstChild("UIStroke")

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
		if state and state.originalPosition then
			menu.Position = state.originalPosition
		end
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
	for _, button in ipairs(allCloseButtons) do
		if button:IsA("TextButton") or button:IsA("ImageButton") and button.Name == "Close" then
			print("Close button found:", button)
		end
	end

	-- Initialize camera settings
	if camera then
		-- Set initial FOV override to ensure CameraDynamics integration
		setFovOverride(false, DEFAULT_FOV)
	end

	-- Initialize sound groups
	initializeSoundGroups()

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
				setupAnimatedElement(button)
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
