-- Utils.lua
-- Utility functions for MenuAnimator system

local TweenService = game:GetService("TweenService")
local Config = require(script.Parent.Config)

local Utils = {}

-- Utility functions
function Utils.createTween(instance, properties, duration, easingStyle, easingDirection, repeatCount)
	easingStyle = easingStyle or Enum.EasingStyle.Back
	easingDirection = easingDirection or Enum.EasingDirection.Out
	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection, repeatCount or 0)
	return TweenService:Create(instance, tweenInfo, properties)
end

function Utils.createBounceTween(instance, originalPosition)
	local tweenInfo =
		TweenInfo.new(Config.BOUNCE_DURATION, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.3)
	return TweenService:Create(instance, tweenInfo, { Position = originalPosition })
end

function Utils.createHoverTween(instance, properties)
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0)
	return TweenService:Create(instance, tweenInfo, properties)
end

function Utils.createClickTween(instance, properties)
	local tweenInfo = TweenInfo.new(Config.ANIMATION_DURATION * 0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	return TweenService:Create(instance, tweenInfo, properties)
end

-- Menu position management functions
function Utils.saveMenuOriginalPosition(menu, menuOriginalPositions)
	if not menuOriginalPositions[menu] then
		menuOriginalPositions[menu] = menu.Position
	end
end

function Utils.getMenuOriginalPosition(menu, menuOriginalPositions)
	return menuOriginalPositions[menu] or menu.Position
end

function Utils.moveMenuDown(menu, menuOriginalPositions)
	local originalPos = Utils.getMenuOriginalPosition(menu, menuOriginalPositions)

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

-- Direction utility functions
function Utils.getOppositeDirection(direction)
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

function Utils.getStartPosition(originalPos, direction)
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

function Utils.getEndPosition(originalPos, direction)
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

return Utils
