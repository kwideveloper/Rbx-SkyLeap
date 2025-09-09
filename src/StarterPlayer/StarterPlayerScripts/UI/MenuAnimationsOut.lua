-- MenuAnimationsOut.lua
-- Menu close animation system with customizable exit animations
-- Supports different animation types: slide, fade, scale, and custom directions

local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)
local MenuManager = require(script.Parent.MenuManager)

local MenuAnimationsOut = {}

-- Animation types and their configurations
local ANIMATION_TYPES = {
	-- Slide animations
	["slide_top"] = {
		type = "slide",
		direction = "top",
		duration = Config.MENU_CLOSE_ANIMATION_DURATION,
		easingStyle = Enum.EasingStyle.Exponential,
		easingDirection = Enum.EasingDirection.Out,
	},
	["slide_bottom"] = {
		type = "slide",
		direction = "bottom",
		duration = Config.MENU_CLOSE_ANIMATION_DURATION,
		easingStyle = Enum.EasingStyle.Exponential,
		easingDirection = Enum.EasingDirection.Out,
	},
	["slide_left"] = {
		type = "slide",
		direction = "left",
		duration = Config.MENU_CLOSE_ANIMATION_DURATION,
		easingStyle = Enum.EasingStyle.Exponential,
		easingDirection = Enum.EasingDirection.Out,
	},
	["slide_right"] = {
		type = "slide",
		direction = "right",
		duration = Config.MENU_CLOSE_ANIMATION_DURATION,
		easingStyle = Enum.EasingStyle.Exponential,
		easingDirection = Enum.EasingDirection.Out,
	},

	-- Fade animations
	["fade"] = {
		type = "fade",
		duration = Config.MENU_CLOSE_ANIMATION_DURATION,
		easingStyle = Enum.EasingStyle.Exponential,
		easingDirection = Enum.EasingDirection.Out,
	},
	["fade_scale"] = {
		type = "fade_scale",
		duration = Config.MENU_CLOSE_ANIMATION_DURATION,
		easingStyle = Enum.EasingStyle.Exponential,
		easingDirection = Enum.EasingDirection.Out,
	},

	-- Scale animations
	["scale_up"] = {
		type = "scale",
		direction = "up",
		duration = Config.MENU_CLOSE_ANIMATION_DURATION,
		easingStyle = Enum.EasingStyle.Exponential,
		easingDirection = Enum.EasingDirection.Out,
	},
	["scale_down"] = {
		type = "scale",
		direction = "down",
		duration = Config.MENU_CLOSE_ANIMATION_DURATION,
		easingStyle = Enum.EasingStyle.Exponential,
		easingDirection = Enum.EasingDirection.Out,
	},

	-- Special animations
	["bounce"] = {
		type = "bounce",
		duration = Config.MENU_CLOSE_ANIMATION_DURATION,
		easingStyle = Enum.EasingStyle.Bounce,
		easingDirection = Enum.EasingDirection.Out,
	},
	["elastic"] = {
		type = "elastic",
		duration = Config.MENU_CLOSE_ANIMATION_DURATION,
		easingStyle = Enum.EasingStyle.Elastic,
		easingDirection = Enum.EasingDirection.Out,
	},
}

-- Get animation configuration by name
function MenuAnimationsOut.getAnimationConfig(animationName)
	return ANIMATION_TYPES[animationName] or ANIMATION_TYPES["slide_bottom"]
end

-- Calculate end position for slide animations
local function calculateSlideEndPosition(menu, direction, originalPosition)
	local currentPosition = menu.Position
	local endPosition

	if direction == "top" then
		endPosition = UDim2.new(
			currentPosition.X.Scale,
			currentPosition.X.Offset,
			currentPosition.Y.Scale - 1,
			currentPosition.Y.Offset
		)
	elseif direction == "bottom" then
		-- Use the existing logic for bottom slide
		if menu.Parent and menu.AbsoluteSize and menu.AbsoluteSize.Y > 0 and menu.Parent.AbsoluteSize.Y > 0 then
			local menuSize = menu.AbsoluteSize.Y
			local parentSize = menu.Parent.AbsoluteSize.Y
			local endYScale = currentPosition.Y.Scale + (menuSize / parentSize)
			endPosition =
				UDim2.new(currentPosition.X.Scale, currentPosition.X.Offset, endYScale, currentPosition.Y.Offset)
		else
			endPosition = UDim2.new(
				currentPosition.X.Scale,
				currentPosition.X.Offset,
				currentPosition.Y.Scale + 0.1,
				currentPosition.Y.Offset
			)
		end
	elseif direction == "left" then
		endPosition = UDim2.new(
			currentPosition.X.Scale - 1,
			currentPosition.X.Offset,
			currentPosition.Y.Scale,
			currentPosition.Y.Offset
		)
	elseif direction == "right" then
		endPosition = UDim2.new(
			currentPosition.X.Scale + 1,
			currentPosition.X.Offset,
			currentPosition.Y.Scale,
			currentPosition.Y.Offset
		)
	else
		-- Default to bottom
		endPosition = UDim2.new(
			currentPosition.X.Scale,
			currentPosition.X.Offset,
			currentPosition.Y.Scale + 0.1,
			currentPosition.Y.Offset
		)
	end

	return endPosition
end

-- Calculate end scale for scale animations
local function calculateScaleEndValue(menu, direction)
	local currentScale = menu.Size
	local endScale

	if direction == "up" then
		endScale = UDim2.new(
			currentScale.X.Scale * 1.2,
			currentScale.X.Offset,
			currentScale.Y.Scale * 1.2,
			currentScale.Y.Offset
		)
	elseif direction == "down" then
		endScale = UDim2.new(
			currentScale.X.Scale * 0.8,
			currentScale.X.Offset,
			currentScale.Y.Scale * 0.8,
			currentScale.Y.Offset
		)
	else
		-- Default to down
		endScale = UDim2.new(
			currentScale.X.Scale * 0.8,
			currentScale.X.Offset,
			currentScale.Y.Scale * 0.8,
			currentScale.Y.Offset
		)
	end

	return endScale
end

-- Play slide animation
function MenuAnimationsOut.playSlideAnimation(menu, state, config, customSettings, menuOriginalPositions)
	local originalPosition = Utils.getMenuOriginalPosition(menu, menuOriginalPositions)
	local endPosition = calculateSlideEndPosition(menu, config.direction, originalPosition)
	local duration = customSettings.duration or config.duration or Config.MENU_CLOSE_ANIMATION_DURATION

	-- Create move tween
	local moveTween =
		Utils.createTween(menu, { Position = endPosition }, duration, config.easingStyle, config.easingDirection)

	-- Create fade tween
	local fadeTween
	if state and state.canvasGroup and state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = Utils.createTween(
			state.canvasGroup,
			{ GroupTransparency = 1 },
			duration,
			config.easingStyle,
			config.easingDirection
		)
	elseif menu:IsA("CanvasGroup") then
		fadeTween =
			Utils.createTween(menu, { GroupTransparency = 1 }, duration, config.easingStyle, config.easingDirection)
	end

	-- Handle stroke
	local hasStroke = menu:FindFirstChild("UIStroke")
	local strokeTween
	if hasStroke then
		strokeTween =
			Utils.createTween(hasStroke, { Transparency = 1 }, duration, config.easingStyle, config.easingDirection)
	end

	-- Play all tweens
	if fadeTween then
		fadeTween:Play()
	end
	if strokeTween then
		strokeTween:Play()
	end
	moveTween:Play()

	return moveTween, fadeTween, strokeTween
end

-- Play fade animation
function MenuAnimationsOut.playFadeAnimation(menu, state, config, customSettings, menuOriginalPositions)
	local duration = customSettings.duration or config.duration or Config.MENU_CLOSE_ANIMATION_DURATION

	-- Create fade tween
	local fadeTween
	if state and state.canvasGroup and state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = Utils.createTween(
			state.canvasGroup,
			{ GroupTransparency = 1 },
			duration,
			config.easingStyle,
			config.easingDirection
		)
	elseif menu:IsA("CanvasGroup") then
		fadeTween =
			Utils.createTween(menu, { GroupTransparency = 1 }, duration, config.easingStyle, config.easingDirection)
	end

	-- Handle stroke
	local hasStroke = menu:FindFirstChild("UIStroke")
	local strokeTween
	if hasStroke then
		strokeTween =
			Utils.createTween(hasStroke, { Transparency = 1 }, duration, config.easingStyle, config.easingDirection)
	end

	-- Play all tweens
	if fadeTween then
		fadeTween:Play()
	end
	if strokeTween then
		strokeTween:Play()
	end

	return fadeTween, strokeTween
end

-- Play fade with scale animation
function MenuAnimationsOut.playFadeScaleAnimation(menu, state, config, customSettings, menuOriginalPositions)
	local originalPosition = Utils.getMenuOriginalPosition(menu, menuOriginalPositions)
	local endScale = calculateScaleEndValue(menu, "down")
	local duration = customSettings.duration or config.duration or Config.MENU_CLOSE_ANIMATION_DURATION

	-- Create scale tween
	local scaleTween =
		Utils.createTween(menu, { Size = endScale }, duration, config.easingStyle, config.easingDirection)

	-- Create fade tween
	local fadeTween
	if state and state.canvasGroup and state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = Utils.createTween(
			state.canvasGroup,
			{ GroupTransparency = 1 },
			duration,
			config.easingStyle,
			config.easingDirection
		)
	elseif menu:IsA("CanvasGroup") then
		fadeTween =
			Utils.createTween(menu, { GroupTransparency = 1 }, duration, config.easingStyle, config.easingDirection)
	end

	-- Handle stroke
	local hasStroke = menu:FindFirstChild("UIStroke")
	local strokeTween
	if hasStroke then
		strokeTween =
			Utils.createTween(hasStroke, { Transparency = 1 }, duration, config.easingStyle, config.easingDirection)
	end

	-- Play all tweens
	if fadeTween then
		fadeTween:Play()
	end
	if strokeTween then
		strokeTween:Play()
	end
	scaleTween:Play()

	return scaleTween, fadeTween, strokeTween
end

-- Play scale animation
function MenuAnimationsOut.playScaleAnimation(menu, state, config, customSettings, menuOriginalPositions)
	local originalPosition = Utils.getMenuOriginalPosition(menu, menuOriginalPositions)
	local endScale = calculateScaleEndValue(menu, config.direction)
	local duration = customSettings.duration or config.duration or Config.MENU_CLOSE_ANIMATION_DURATION

	-- Create scale tween
	local scaleTween =
		Utils.createTween(menu, { Size = endScale }, duration, config.easingStyle, config.easingDirection)

	-- Create fade tween
	local fadeTween
	if state and state.canvasGroup and state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = Utils.createTween(
			state.canvasGroup,
			{ GroupTransparency = 1 },
			duration,
			config.easingStyle,
			config.easingDirection
		)
	elseif menu:IsA("CanvasGroup") then
		fadeTween =
			Utils.createTween(menu, { GroupTransparency = 1 }, duration, config.easingStyle, config.easingDirection)
	end

	-- Handle stroke
	local hasStroke = menu:FindFirstChild("UIStroke")
	local strokeTween
	if hasStroke then
		strokeTween =
			Utils.createTween(hasStroke, { Transparency = 1 }, duration, config.easingStyle, config.easingDirection)
	end

	-- Play all tweens
	if fadeTween then
		fadeTween:Play()
	end
	if strokeTween then
		strokeTween:Play()
	end
	scaleTween:Play()

	return scaleTween, fadeTween, strokeTween
end

-- Play bounce animation
function MenuAnimationsOut.playBounceAnimation(menu, state, config, customSettings, menuOriginalPositions)
	local originalPosition = Utils.getMenuOriginalPosition(menu, menuOriginalPositions)
	local endPosition = calculateSlideEndPosition(menu, "bottom", originalPosition)
	local duration = customSettings.duration or config.duration or Config.MENU_CLOSE_ANIMATION_DURATION

	-- Create move tween with bounce
	local moveTween =
		Utils.createTween(menu, { Position = endPosition }, duration, config.easingStyle, config.easingDirection)

	-- Create fade tween
	local fadeTween
	if state and state.canvasGroup and state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = Utils.createTween(
			state.canvasGroup,
			{ GroupTransparency = 1 },
			duration,
			config.easingStyle,
			config.easingDirection
		)
	elseif menu:IsA("CanvasGroup") then
		fadeTween =
			Utils.createTween(menu, { GroupTransparency = 1 }, duration, config.easingStyle, config.easingDirection)
	end

	-- Handle stroke
	local hasStroke = menu:FindFirstChild("UIStroke")
	local strokeTween
	if hasStroke then
		strokeTween =
			Utils.createTween(hasStroke, { Transparency = 1 }, duration, config.easingStyle, config.easingDirection)
	end

	-- Play all tweens
	if fadeTween then
		fadeTween:Play()
	end
	if strokeTween then
		strokeTween:Play()
	end
	moveTween:Play()

	return moveTween, fadeTween, strokeTween
end

-- Play elastic animation
function MenuAnimationsOut.playElasticAnimation(menu, state, config, customSettings, menuOriginalPositions)
	local originalPosition = Utils.getMenuOriginalPosition(menu, menuOriginalPositions)
	local endPosition = calculateSlideEndPosition(menu, "bottom", originalPosition)
	local duration = customSettings.duration or config.duration or Config.MENU_CLOSE_ANIMATION_DURATION

	-- Create move tween with elastic
	local moveTween =
		Utils.createTween(menu, { Position = endPosition }, duration, config.easingStyle, config.easingDirection)

	-- Create fade tween
	local fadeTween
	if state and state.canvasGroup and state.canvasGroup:IsA("CanvasGroup") then
		fadeTween = Utils.createTween(
			state.canvasGroup,
			{ GroupTransparency = 1 },
			duration,
			config.easingStyle,
			config.easingDirection
		)
	elseif menu:IsA("CanvasGroup") then
		fadeTween =
			Utils.createTween(menu, { GroupTransparency = 1 }, duration, config.easingStyle, config.easingDirection)
	end

	-- Handle stroke
	local hasStroke = menu:FindFirstChild("UIStroke")
	local strokeTween
	if hasStroke then
		strokeTween =
			Utils.createTween(hasStroke, { Transparency = 1 }, duration, config.easingStyle, config.easingDirection)
	end

	-- Play all tweens
	if fadeTween then
		fadeTween:Play()
	end
	if strokeTween then
		strokeTween:Play()
	end
	moveTween:Play()

	return moveTween, fadeTween, strokeTween
end

-- Main function to close menu with custom animation
function MenuAnimationsOut.closeMenu(menu, animationName, state, menuOriginalPositions)
	-- Handle "None" animation - just hide immediately
	if animationName == "none" then
		if state and state.canvasGroup and state.canvasGroup:IsA("CanvasGroup") then
			state.canvasGroup.GroupTransparency = 1
		elseif menu:IsA("CanvasGroup") then
			menu.GroupTransparency = 1
		end

		if menu:IsA("GuiObject") and menu.Visible ~= nil then
			menu.Visible = false
		end
		return
	end

	-- Get animation configuration
	local config = MenuAnimationsOut.getAnimationConfig(animationName)
	local customSettings = MenuManager.getCustomAnimationSettings(menu)

	local originalPosition = Utils.getMenuOriginalPosition(menu, menuOriginalPositions)
	local mainTween, fadeTween, strokeTween

	-- Execute the appropriate animation
	if config.type == "slide" then
		mainTween, fadeTween, strokeTween =
			MenuAnimationsOut.playSlideAnimation(menu, state, config, customSettings, menuOriginalPositions)
	elseif config.type == "fade" then
		fadeTween, strokeTween =
			MenuAnimationsOut.playFadeAnimation(menu, state, config, customSettings, menuOriginalPositions)
	elseif config.type == "fade_scale" then
		mainTween, fadeTween, strokeTween =
			MenuAnimationsOut.playFadeScaleAnimation(menu, state, config, customSettings, menuOriginalPositions)
	elseif config.type == "scale" then
		mainTween, fadeTween, strokeTween =
			MenuAnimationsOut.playScaleAnimation(menu, state, config, customSettings, menuOriginalPositions)
	elseif config.type == "bounce" then
		mainTween, fadeTween, strokeTween =
			MenuAnimationsOut.playBounceAnimation(menu, state, config, customSettings, menuOriginalPositions)
	elseif config.type == "elastic" then
		mainTween, fadeTween, strokeTween =
			MenuAnimationsOut.playElasticAnimation(menu, state, config, customSettings, menuOriginalPositions)
	else
		-- Default to slide bottom
		mainTween, fadeTween, strokeTween =
			MenuAnimationsOut.playSlideAnimation(menu, state, config, customSettings, menuOriginalPositions)
	end

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
	if fadeTween and mainTween then
		-- If there are multiple tweens, wait for both to complete
		local animationsCompleted = 0
		local totalAnimations = 2

		local function checkCompletion()
			animationsCompleted = animationsCompleted + 1
			if animationsCompleted >= totalAnimations then
				onAnimationComplete()
			end
		end

		fadeTween.Completed:Connect(checkCompletion)
		mainTween.Completed:Connect(checkCompletion)
	elseif fadeTween then
		-- Only fade animation
		fadeTween.Completed:Connect(onAnimationComplete)
	elseif mainTween then
		-- Only main animation
		mainTween.Completed:Connect(onAnimationComplete)
	else
		-- No animations, complete immediately
		onAnimationComplete()
	end
end

-- Get list of available animation types
function MenuAnimationsOut.getAvailableAnimations()
	local animations = {}
	for name, _ in pairs(ANIMATION_TYPES) do
		table.insert(animations, name)
	end
	table.insert(animations, "none")
	return animations
end

return MenuAnimationsOut
