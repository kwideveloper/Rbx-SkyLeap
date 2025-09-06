-- MenuAnimations.lua
-- Menu animation system for MenuAnimator

local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)
local MenuManager = require(script.Parent.MenuManager)

local MenuAnimations = {}

-- Specialized animation functions for different types
function MenuAnimations.playSlideAnimation(menu, state, config, customSettings, menuOriginalPositions)
	local originalPosition = Utils.getMenuOriginalPosition(menu, menuOriginalPositions)
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

	local duration = customSettings.duration or config.duration or Config.MENU_ANIMATION_DURATION
	local moveTween = Utils.createTween(menu, { Position = originalPosition }, duration)

	local fadeTween
	if state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = Utils.createTween(state.canvasGroup, { GroupTransparency = 0 }, duration)
	else
		menu.Visible = true
	end

	if fadeTween then
		fadeTween:Play()
	end
	moveTween:Play()

	local hasStroke = state.canvasGroup:FindFirstChild("UIStroke")
	if hasStroke then
		local fadeStroke = Utils.createTween(hasStroke, { Transparency = 0 }, duration)
		fadeStroke:Play()
	end

	return moveTween
end

function MenuAnimations.playFadeAnimation(menu, state, config, customSettings, menuOriginalPositions)
	local originalPosition = Utils.getMenuOriginalPosition(menu, menuOriginalPositions)

	-- Set initial state
	if state.canvasGroup:IsA("CanvasGroup") then
		state.canvasGroup.GroupTransparency = 1
	else
		menu.Visible = false
	end

	menu.Position = originalPosition

	local duration = customSettings.duration or config.duration or Config.MENU_ANIMATION_DURATION
	local fadeTween

	if state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = Utils.createTween(state.canvasGroup, { GroupTransparency = 0 }, duration)
	else
		menu.Visible = true
	end

	if fadeTween then
		fadeTween:Play()
	end

	local hasStroke = state.canvasGroup:FindFirstChild("UIStroke")
	if hasStroke then
		local fadeStroke = Utils.createTween(hasStroke, { Transparency = 0 }, duration)
		fadeStroke:Play()
	end

	return fadeTween or { Completed = { Wait = function() end } }
end

function MenuAnimations.playScaleAnimation(menu, state, config, customSettings, menuOriginalPositions)
	local originalPosition = Utils.getMenuOriginalPosition(menu, menuOriginalPositions)

	-- Set initial state
	if state.canvasGroup:IsA("CanvasGroup") then
		state.canvasGroup.GroupTransparency = 1
	else
		menu.Visible = false
	end

	menu.Position = originalPosition

	local duration = customSettings.duration or config.duration or Config.MENU_ANIMATION_DURATION
	local scaleTween = Utils.createTween(menu, { Size = menu.Size }, duration)

	local fadeTween
	if state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = Utils.createTween(state.canvasGroup, { GroupTransparency = 0 }, duration)
	else
		menu.Visible = true
	end

	if fadeTween then
		fadeTween:Play()
	end
	scaleTween:Play()

	local hasStroke = state.canvasGroup:FindFirstChild("UIStroke")
	if hasStroke then
		local fadeStroke = Utils.createTween(hasStroke, { Transparency = 0 }, duration)
		fadeStroke:Play()
	end

	return scaleTween
end

function MenuAnimations.openMenu(menu, direction, state, button, menuOriginalPositions)
	-- Ensure the menu is visible before starting animation
	if menu:IsA("GuiObject") and menu.Visible ~= nil then
		menu.Visible = true
	end

	-- Get animation configuration for this menu
	local animationConfig = MenuManager.getMenuAnimationConfig(menu, button)
	local customSettings = MenuManager.getCustomAnimationSettings(menu)

	local animationTween

	-- Execute the appropriate animation based on type
	if animationConfig.type == "slide" then
		animationTween =
			MenuAnimations.playSlideAnimation(menu, state, animationConfig, customSettings, menuOriginalPositions)
	elseif animationConfig.type == "fade" then
		animationTween =
			MenuAnimations.playFadeAnimation(menu, state, animationConfig, customSettings, menuOriginalPositions)
	elseif animationConfig.type == "scale" then
		animationTween =
			MenuAnimations.playScaleAnimation(menu, state, animationConfig, customSettings, menuOriginalPositions)
	elseif animationConfig.type == "bounce" then
		animationTween =
			MenuAnimations.playSlideAnimation(menu, state, animationConfig, customSettings, menuOriginalPositions)
	else
		-- Default to slide animation
		animationTween =
			MenuAnimations.playSlideAnimation(menu, state, animationConfig, customSettings, menuOriginalPositions)
	end

	-- Bounce effect at the end for slide animations
	if animationConfig.type == "slide" or animationConfig.type == "bounce" then
		local originalPosition = Utils.getMenuOriginalPosition(menu, menuOriginalPositions)
		animationTween.Completed:Wait()
		Utils.createBounceTween(menu, originalPosition):Play()
	end
end

function MenuAnimations.closeMenu(menu, direction, state, menuOriginalPositions)
	-- Get animation configuration for this menu
	local animationConfig = MenuManager.getMenuAnimationConfig(menu)
	local customSettings = MenuManager.getCustomAnimationSettings(menu)

	local duration = customSettings.duration or Config.MENU_CLOSE_ANIMATION_DURATION
	local currentPosition = menu.Position
	local originalPosition = Utils.getMenuOriginalPosition(menu, menuOriginalPositions)
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
	local moveTween = Utils.createTween(
		menu,
		{ Position = endPosition },
		duration,
		Enum.EasingStyle.Exponential,
		Enum.EasingDirection.Out
	)

	local fadeTween
	if state and state.canvasGroup and state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = Utils.createTween(
			state.canvasGroup,
			{ GroupTransparency = 1 },
			duration,
			Enum.EasingStyle.Exponential,
			Enum.EasingDirection.Out
		)
	elseif menu:IsA("CanvasGroup") then
		-- If no state but menu is CanvasGroup, animate it directly
		fadeTween = Utils.createTween(
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
		local fadeStroke = Utils.createTween(
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

return MenuAnimations
