-- MenuAnimator.client.lua
-- Handles UI animations and interactions for buttons with ObjectValue "Open" and StringValue "Animate" children
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

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

-- Animation presets for easy configuration
local ANIMATION_PRESETS = {
	-- Slide animations
	SLIDE_UP = { type = "slide", direction = "Top", duration = 0.4 },
	SLIDE_DOWN = { type = "slide", direction = "Bottom", duration = 0.4 },
	SLIDE_LEFT = { type = "slide", direction = "Left", duration = 0.4 },
	SLIDE_RIGHT = { type = "slide", direction = "Right", duration = 0.4 },

	-- Fast slide animations
	SLIDE_UP_FAST = { type = "slide", direction = "Top", duration = 0.25 },
	SLIDE_DOWN_FAST = { type = "slide", direction = "Bottom", duration = 0.25 },
	SLIDE_LEFT_FAST = { type = "slide", direction = "Left", duration = 0.25 },
	SLIDE_RIGHT_FAST = { type = "slide", direction = "Right", duration = 0.25 },

	-- Fade animations
	FADE_IN = { type = "fade", direction = "Center", duration = 0.3 },
	FADE_IN_FAST = { type = "fade", direction = "Center", duration = 0.15 },
	FADE_IN_SLOW = { type = "fade", direction = "Center", duration = 0.6 },

	-- Scale animations
	SCALE_IN = { type = "scale", direction = "Center", duration = 0.4 },
	SCALE_IN_FAST = { type = "scale", direction = "Center", duration = 0.2 },
	SCALE_IN_SLOW = { type = "scale", direction = "Center", duration = 0.8 },

	-- Bounce animations
	BOUNCE_UP = { type = "bounce", direction = "Top", duration = 0.5 },
	BOUNCE_DOWN = { type = "bounce", direction = "Bottom", duration = 0.5 },

	-- Custom combinations
	SLIDE_FADE_UP = { type = "slide_fade", direction = "Top", duration = 0.4 },
	SCALE_FADE_IN = { type = "scale_fade", direction = "Center", duration = 0.4 },
}

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
local menuOriginalPositions = {} -- Store original positions of menus {menu = originalPosition}

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

-- Menu position management functions
local function saveMenuOriginalPosition(menu)
	if not menuOriginalPositions[menu] then
		menuOriginalPositions[menu] = menu.Position
	end
end

local function getMenuOriginalPosition(menu)
	return menuOriginalPositions[menu] or menu.Position
end

-- Function to get animation configuration for a menu
local function getMenuAnimationConfig(menu, button)
	-- Check for Animation StringValue on the menu itself
	local animationValue = menu:FindFirstChild("Animation")
	if animationValue and animationValue:IsA("StringValue") then
		local presetName = animationValue.Value
		if ANIMATION_PRESETS[presetName] then
			return ANIMATION_PRESETS[presetName]
		end
	end

	-- Check for Animation StringValue on the button
	if button then
		local buttonAnimationValue = button:FindFirstChild("Animation")
		if buttonAnimationValue and buttonAnimationValue:IsA("StringValue") then
			local presetName = buttonAnimationValue.Value
			if ANIMATION_PRESETS[presetName] then
				return ANIMATION_PRESETS[presetName]
			end
		end
	end

	-- Fallback to default animation
	return ANIMATION_PRESETS.SLIDE_UP
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

local function moveMenuDown(menu)
	local originalPos = getMenuOriginalPosition(menu)

	-- Wait for the menu to be properly loaded and have valid sizes
	if not menu.Parent or not menu.AbsoluteSize or menu.AbsoluteSize.Y == 0 then
		-- Fallback: move down by a fixed amount if we can't calculate properly
		menu.Position =
			UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale + 0.1, originalPos.Y.Offset)
		return
	end

	local menuSize = menu.AbsoluteSize.Y
	local parentSize = menu.Parent.AbsoluteSize.Y

	if parentSize > 0 then
		-- Move down by 1x the menu height
		local newYScale = originalPos.Y.Scale + (menuSize / parentSize)
		local newYOffset = originalPos.Y.Offset
		menu.Position = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, newYScale, newYOffset)
	else
		-- Fallback for edge cases
		menu.Position =
			UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale + 0.1, originalPos.Y.Offset)
	end
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

-- Function to check if a button has the "MenuButton" tag
-- This identifies buttons that control main menu navigation
local function isMenuButton(button)
	return CollectionService:HasTag(button, "MenuButton")
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
	-- Check if any MenuButton-controlled menus are open
	local hasOpenMenuButtonMenus = false
	local openMenuButtonCount = 0
	local openMenuButtonNames = {}

	for menu, menuState in pairs(menuStates) do
		if menuState.isOpen then
			-- Check if this menu is controlled by a MenuButton-tagged button
			local controllingButton = openMenus[menu]
			if controllingButton and isMenuButton(controllingButton) then
				hasOpenMenuButtonMenus = true
				openMenuButtonCount = openMenuButtonCount + 1
				table.insert(openMenuButtonNames, menu.Name or "UnnamedMenu")
			end
		end
	end

	-- Apply or remove camera effects based on MenuButton menu state only
	if hasOpenMenuButtonMenus and not cameraEffectActive then
		applyCameraEffects(true)
	elseif not hasOpenMenuButtonMenus and cameraEffectActive then
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
	-- Check if any MenuButton-controlled menus are open
	local hasOpenMenuButtonMenus = false
	for menu, state in pairs(menuStates) do
		if state.isOpen then
			-- Check if this menu is controlled by a MenuButton-tagged button
			local controllingButton = openMenus[menu]
			if controllingButton and isMenuButton(controllingButton) then
				hasOpenMenuButtonMenus = true
				break
			end
		end
	end

	-- Apply or remove sound effects based on MenuButton menu state only
	if hasOpenMenuButtonMenus and not soundEffectActive then
		applyClubEffects(true)
	elseif not hasOpenMenuButtonMenus and soundEffectActive then
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

		if uiStroke and uiStroke.UIGradient then
			uiStroke.UIGradient.Enabled = false
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

-- Function to get all open menus controlled by MenuButton-tagged buttons
-- This ensures we only close menus controlled by main navigation buttons
local function getMenuButtonControlledMenus(button)
	local menuButtonMenus = {}
	for menu, associatedButton in pairs(openMenus) do
		if associatedButton ~= button and isMenuButton(associatedButton) then
			table.insert(menuButtonMenus, menu)
		end
	end
	return menuButtonMenus
end

local function closeAllOtherMenus(exceptMenu, button)
	-- NEW LOGIC: Only close menus controlled by buttons with "MenuButton" tag
	local menusToClose = getMenuButtonControlledMenus(button)
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
				-- Only apply effects if the button that opened this menu has "MenuButton" tag
				if not firstMenuClosed and isMenuButton(associatedButton) then
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
	-- Safety check: ensure element exists and is valid
	if not element or not element:IsA("GuiObject") then
		return
	end

	local state = {
		isActive = false,
		originalSize = element.Size,
		originalPosition = element.Position,
		originalRotation = element.Rotation or 0,
		originalZIndex = element.Parent and element.Parent.ZIndex or 1,
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

	local activeGradientTween = nil
	local uiStroke = element:FindFirstChild("UIStroke")
	if uiStroke and uiStroke:FindFirstChild("UIGradient") then
		activeGradientTween = createTween(
			uiStroke.UIGradient,
			{ Rotation = 180 },
			3,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.InOut,
			-1
		)
	end

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
				if uiStroke and uiStroke:FindFirstChild("UIGradient") and activeGradientTween then
					uiStroke.UIGradient.Enabled = true
					if activeGradientTween.Play then
						activeGradientTween:Play()
					end
				end
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

				if uiStroke and uiStroke:FindFirstChild("UIGradient") and activeGradientTween then
					uiStroke.UIGradient.Enabled = false
					if activeGradientTween.Cancel then
						activeGradientTween:Cancel()
					end
				end

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
			-- Save the original position when setting up the menu
			saveMenuOriginalPosition(targetMenu)

			local menuState = {
				isOpen = false,
				originalPosition = getMenuOriginalPosition(targetMenu),
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
						closeAllOtherMenus(targetMenu, button)
					end
				end

				-- Open all target menus
				local firstMenuOpened = false
				for _, targetMenu in ipairs(targetMenus) do
					local menuState = menuStatesForButton[targetMenu]
					if not menuState.isOpen then
						menuState.isOpen = true
						openMenus[targetMenu] = button

						-- Apply camera and sound effects immediately when first menu is opened
						-- Only apply effects if the button has "MenuButton" tag
						if not firstMenuOpened and isMenuButton(button) then
							updateCameraEffects()
							updateSoundEffects()
							firstMenuOpened = true
						end
						openMenu(targetMenu, animationDirection, menuState, button)
					end
				end

				-- Set button as active
				setButtonActive(button)
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
							openMenus[targetMenu] = nil

							-- Apply camera and sound effects immediately when first menu is closed
							-- Only apply effects if the button that opened this menu has "MenuButton" tag
							if not firstMenuClosed and isMenuButton(button) then
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
					openMenus[target] = nil

					-- Update camera and sound effects immediately when first menu is closed
					-- Only apply effects if the button that opened this menu has "MenuButton" tag
					if not effectsUpdated and openingButton and isMenuButton(openingButton) then
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
					-- This works regardless of whether the opening button has "MenuButton" tag
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
					-- Only apply effects if there was an opening button with "MenuButton" tag
					if not effectsUpdated and openingButton and isMenuButton(openingButton) then
						updateCameraEffects()
						updateSoundEffects()
						effectsUpdated = true
					end
				end
			end
		end)
	end
end

-- Specialized animation functions for different types
local function playSlideAnimation(menu, state, config, customSettings)
	local originalPosition = getMenuOriginalPosition(menu)
	local startPosition

	-- Set initial state
	if state.canvasGroup:IsA("CanvasGroup") then
		state.canvasGroup.GroupTransparency = 1
	else
		menu.Visible = false
	end

	-- Calculate start position based on direction
	if config.direction == "Top" then
		startPosition = UDim2.new(
			originalPosition.X.Scale,
			originalPosition.X.Offset,
			originalPosition.Y.Scale - 1,
			originalPosition.Y.Offset
		)
	elseif config.direction == "Bottom" then
		startPosition = UDim2.new(
			originalPosition.X.Scale,
			originalPosition.X.Offset,
			originalPosition.Y.Scale + 1,
			originalPosition.Y.Offset
		)
	elseif config.direction == "Left" then
		startPosition = UDim2.new(
			originalPosition.X.Scale - 1,
			originalPosition.X.Offset,
			originalPosition.Y.Scale,
			originalPosition.Y.Offset
		)
	elseif config.direction == "Right" then
		startPosition = UDim2.new(
			originalPosition.X.Scale + 1,
			originalPosition.X.Offset,
			originalPosition.Y.Scale,
			originalPosition.Y.Offset
		)
	else
		startPosition = UDim2.new(
			originalPosition.X.Scale,
			originalPosition.X.Offset,
			originalPosition.Y.Scale - 1,
			originalPosition.Y.Offset
		)
	end

	menu.Position = startPosition

	local duration = customSettings.duration or config.duration or MENU_ANIMATION_DURATION
	local moveTween = createTween(menu, { Position = originalPosition }, duration)

	local fadeTween
	if state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = createTween(state.canvasGroup, { GroupTransparency = 0 }, duration)
	else
		menu.Visible = true
	end

	if fadeTween then
		fadeTween:Play()
	end
	moveTween:Play()

	local hasStroke = state.canvasGroup:FindFirstChild("UIStroke")
	if hasStroke then
		local fadeStroke = createTween(hasStroke, { Transparency = 0 }, duration)
		fadeStroke:Play()
	end

	return moveTween
end

local function playFadeAnimation(menu, state, config, customSettings)
	local originalPosition = getMenuOriginalPosition(menu)

	-- Set initial state
	if state.canvasGroup:IsA("CanvasGroup") then
		state.canvasGroup.GroupTransparency = 1
	else
		menu.Visible = false
	end

	menu.Position = originalPosition

	local duration = customSettings.duration or config.duration or MENU_ANIMATION_DURATION
	local fadeTween

	if state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = createTween(state.canvasGroup, { GroupTransparency = 0 }, duration)
	else
		menu.Visible = true
	end

	if fadeTween then
		fadeTween:Play()
	end

	local hasStroke = state.canvasGroup:FindFirstChild("UIStroke")
	if hasStroke then
		local fadeStroke = createTween(hasStroke, { Transparency = 0 }, duration)
		fadeStroke:Play()
	end

	return fadeTween or { Completed = { Wait = function() end } }
end

local function playScaleAnimation(menu, state, config, customSettings)
	local originalPosition = getMenuOriginalPosition(menu)

	-- Set initial state
	if state.canvasGroup:IsA("CanvasGroup") then
		state.canvasGroup.GroupTransparency = 1
	else
		menu.Visible = false
	end

	menu.Position = originalPosition

	local duration = customSettings.duration or config.duration or MENU_ANIMATION_DURATION
	local scaleTween = createTween(menu, { Size = menu.Size }, duration)

	local fadeTween
	if state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = createTween(state.canvasGroup, { GroupTransparency = 0 }, duration)
	else
		menu.Visible = true
	end

	if fadeTween then
		fadeTween:Play()
	end
	scaleTween:Play()

	local hasStroke = state.canvasGroup:FindFirstChild("UIStroke")
	if hasStroke then
		local fadeStroke = createTween(hasStroke, { Transparency = 0 }, duration)
		fadeStroke:Play()
	end

	return scaleTween
end

function openMenu(menu, direction, state, button)
	-- Ensure the menu is visible before starting animation
	if menu:IsA("GuiObject") and menu.Visible ~= nil then
		menu.Visible = true
	end

	-- Get animation configuration for this menu
	local animationConfig = getMenuAnimationConfig(menu, button)
	local customSettings = getCustomAnimationSettings(menu)

	local animationTween

	-- Execute the appropriate animation based on type
	if animationConfig.type == "slide" then
		animationTween = playSlideAnimation(menu, state, animationConfig, customSettings)
	elseif animationConfig.type == "fade" then
		animationTween = playFadeAnimation(menu, state, animationConfig, customSettings)
	elseif animationConfig.type == "scale" then
		animationTween = playScaleAnimation(menu, state, animationConfig, customSettings)
	elseif animationConfig.type == "bounce" then
		animationTween = playSlideAnimation(menu, state, animationConfig, customSettings)
	else
		-- Default to slide animation
		animationTween = playSlideAnimation(menu, state, animationConfig, customSettings)
	end

	-- Bounce effect at the end for slide animations
	if animationConfig.type == "slide" or animationConfig.type == "bounce" then
		local originalPosition = getMenuOriginalPosition(menu)
		animationTween.Completed:Wait()
		createBounceTween(menu, originalPosition):Play()
	end
end

function closeMenu(menu, direction, state)
	-- Get animation configuration for this menu
	local animationConfig = getMenuAnimationConfig(menu)
	local customSettings = getCustomAnimationSettings(menu)

	local duration = customSettings.duration or MENU_CLOSE_ANIMATION_DURATION
	local currentPosition = menu.Position
	local originalPosition = getMenuOriginalPosition(menu)
	local endPosition

	-- Calculate end position for closing animation
	if menu.Parent and menu.AbsoluteSize and menu.AbsoluteSize.Y > 0 and menu.Parent.AbsoluteSize.Y > 0 then
		local menuSize = menu.AbsoluteSize.Y
		local parentSize = menu.Parent.AbsoluteSize.Y
		local endYScale = currentPosition.Y.Scale + (menuSize / parentSize)
		endPosition = UDim2.new(currentPosition.X.Scale, currentPosition.X.Offset, endYScale, currentPosition.Y.Offset)
	else
		-- Fallback for edge cases
		endPosition = UDim2.new(
			currentPosition.X.Scale,
			currentPosition.X.Offset,
			currentPosition.Y.Scale + 0.1,
			currentPosition.Y.Offset
		)
	end

	-- Animate down
	local moveTween =
		createTween(menu, { Position = endPosition }, duration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

	local fadeTween
	if state and state.canvasGroup and state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = createTween(
			state.canvasGroup,
			{ GroupTransparency = 1 },
			duration,
			Enum.EasingStyle.Exponential,
			Enum.EasingDirection.Out
		)
	elseif menu:IsA("CanvasGroup") then
		-- If no state but menu is CanvasGroup, animate it directly
		fadeTween = createTween(
			menu,
			{ GroupTransparency = 1 },
			duration,
			Enum.EasingStyle.Exponential,
			Enum.EasingDirection.Out
		)
	else
		-- For non-CanvasGroup, the Visible=false will be handled at the end of all animations
	end

	local hasStroke = menu:FindFirstChild("UIStroke")

	if hasStroke then
		local fadeStroke = createTween(
			hasStroke,
			{ Transparency = 1 },
			duration,
			Enum.EasingStyle.Exponential,
			Enum.EasingDirection.Out
		)
		fadeStroke:Play()
	end

	if fadeTween then
		fadeTween:Play()
	end
	moveTween:Play()

	-- Handle animation completion
	local function onAnimationComplete()
		-- Reset to original position
		menu.Position = originalPosition

		-- Set Visible = false for all menu types at the end of animation
		if menu:IsA("GuiObject") and menu.Visible ~= nil then
			menu.Visible = false
		end
	end

	-- Connect to the main animation completion
	if fadeTween then
		-- If there's a fade animation, wait for both to complete
		local animationsCompleted = 0
		local totalAnimations = 2

		local function checkCompletion()
			animationsCompleted = animationsCompleted + 1
			if animationsCompleted >= totalAnimations then
				onAnimationComplete()
			end
		end

		fadeTween.Completed:Connect(checkCompletion)
		moveTween.Completed:Connect(checkCompletion)
	else
		-- Only move animation, connect directly
		moveTween.Completed:Connect(onAnimationComplete)
	end
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
