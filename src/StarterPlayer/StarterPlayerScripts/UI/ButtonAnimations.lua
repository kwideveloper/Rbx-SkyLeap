-- ButtonAnimations.lua
-- Button animation system for MenuAnimator - ONLY for elements with "MenuButton" tag

local CollectionService = game:GetService("CollectionService")
local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)

local ButtonAnimations = {}

-- Handle animated elements (Hover, Click, Active) - ONLY for MenuButton elements
function ButtonAnimations.setupAnimatedElement(element, elementStates)
	-- Safety check: ensure element exists and is valid
	if not element or not element:IsA("GuiObject") then
		return
	end

	-- Only handle elements with "MenuButton" tag
	if not CollectionService:HasTag(element, "MenuButton") then
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
				local hoverTween = Utils.createHoverTween(element, {
					Size = UDim2.new(
						state.originalSize.X.Scale * Config.HOVER_SCALE,
						state.originalSize.X.Offset * Config.HOVER_SCALE,
						state.originalSize.Y.Scale * Config.HOVER_SCALE,
						state.originalSize.Y.Offset * Config.HOVER_SCALE
					),
					Rotation = Config.HOVER_ROTATION,
				})
				hoverTween:Play()
				-- Animate icon (If exists)
				if icon then
					local tween = Utils.createTween(
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
				local leaveTween = Utils.createHoverTween(element, {
					Size = state.originalSize,
					Rotation = state.originalRotation,
				})
				leaveTween:Play()
				-- Restore original ZIndex

				-- Animate icon (If exists)
				if icon then
					local tween = Utils.createTween(
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
				local clickDownTween = Utils.createClickTween(element, {
					Position = UDim2.new(
						state.originalPosition.X.Scale,
						state.originalPosition.X.Offset,
						state.originalPosition.Y.Scale,
						state.originalPosition.Y.Offset + Config.CLICK_Y_OFFSET
					),
					Size = UDim2.new(
						state.originalSize.X.Scale * Config.CLICK_SCALE,
						state.originalSize.X.Offset * Config.CLICK_SCALE,
						state.originalSize.Y.Scale * Config.CLICK_SCALE,
						state.originalSize.Y.Offset * Config.CLICK_SCALE
					),
				})

				clickDownTween:Play()
				clickDownTween.Completed:Wait()

				-- Click up animation with bounce
				local clickUpTween = Utils.createClickTween(element, {
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
		activeGradientTween = Utils.createTween(
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
				Utils.createHoverTween(element, {
					Size = UDim2.new(
						state.originalSize.X.Scale * Config.ACTIVATE_SCALE,
						state.originalSize.X.Offset * Config.ACTIVATE_SCALE,
						state.originalSize.Y.Scale * Config.ACTIVATE_SCALE,
						state.originalSize.Y.Offset * Config.ACTIVATE_SCALE
					),
					Rotation = Config.ACTIVATE_ROTATION,
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
				Utils.createHoverTween(element, {
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

return ButtonAnimations
