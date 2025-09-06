-- GeneralButtonAnimations.lua
-- Animation system for buttons with StringValue "Animate" that DON'T have "MenuButton" tag

local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)

local GeneralButtonAnimations = {}

-- Animation states for general buttons
local generalElementStates = {}

-- Handle animated elements (Hover, Click, Active) for non-MenuButton elements
function GeneralButtonAnimations.setupAnimatedElement(element)
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
		-- Store original frame and shadow positions for animations
		originalFramePosition = nil,
		originalShadowPosition = nil,
	}
	generalElementStates[element] = state

	-- Find the frame and shadow inside the button for animations
	local frame = element:FindFirstChild("Frame")
	local shadow = element:FindFirstChild("Shadow")
	if frame then
		state.originalFramePosition = frame.Position
	end
	if shadow then
		state.originalShadowPosition = shadow.Position
	end

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
			elseif child.Value == "All" then
				hasHover = true
				hasClick = true
				hasActive = true
			end
		end
	end

	-- Store tween references for cancellation
	local currentHoverTweens = {}

	-- Setup hover animations - Jump up and bounce down effect
	if hasHover then
		element.MouseEnter:Connect(function()
			if not state.isActive then
				-- Cancel any existing hover animations
				for _, tween in pairs(currentHoverTweens) do
					if tween and tween.Cancel then
						tween:Cancel()
					end
				end
				currentHoverTweens = {}
				-- Update the state reference as well
				state.hoverTweens = currentHoverTweens

				-- Phase 1: Jump up animation
				local jumpUpTween = Utils.createTween(element, {
					Position = UDim2.new(
						state.originalPosition.X.Scale,
						state.originalPosition.X.Offset,
						state.originalPosition.Y.Scale,
						state.originalPosition.Y.Offset - 6 -- Jump up 6 pixels
					),
				}, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				jumpUpTween:Play()
				currentHoverTweens.jumpUp = jumpUpTween

				-- Animate frame and shadow with the jump up
				if frame then
					local frameJumpUpTween = Utils.createTween(frame, {
						Position = UDim2.new(
							frame.Position.X.Scale,
							frame.Position.X.Offset,
							frame.Position.Y.Scale,
							frame.Position.Y.Offset - 3 -- Frame jumps up with button
						),
					}, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					frameJumpUpTween:Play()
					currentHoverTweens.frameJumpUp = frameJumpUpTween
				end

				if shadow then
					local shadowJumpUpTween = Utils.createTween(shadow, {
						Position = UDim2.new(
							shadow.Position.X.Scale,
							shadow.Position.X.Offset,
							shadow.Position.Y.Scale,
							shadow.Position.Y.Offset - 3 -- Shadow jumps up with button
						),
					}, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					shadowJumpUpTween:Play()
					currentHoverTweens.shadowJumpUp = shadowJumpUpTween
				end

				-- Phase 2: Bounce down to original position with subtle bounce
				jumpUpTween.Completed:Connect(function()
					local bounceDownTween = Utils.createTween(element, {
						Position = UDim2.new(
							state.originalPosition.X.Scale,
							state.originalPosition.X.Offset,
							state.originalPosition.Y.Scale,
							state.originalPosition.Y.Offset + 2 -- Slight overshoot for bounce effect
						),
					}, 0.1, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
					bounceDownTween:Play()
					currentHoverTweens.bounceDown = bounceDownTween

					-- Bounce frame and shadow down
					if frame then
						local frameBounceTween = Utils.createTween(frame, {
							Position = UDim2.new(
								state.originalFramePosition.X.Scale,
								state.originalFramePosition.X.Offset,
								state.originalFramePosition.Y.Scale,
								state.originalFramePosition.Y.Offset + 2 -- Slight overshoot
							),
						}, 0.1, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
						frameBounceTween:Play()
						currentHoverTweens.frameBounce = frameBounceTween
					end

					if shadow then
						local shadowBounceTween = Utils.createTween(shadow, {
							Position = UDim2.new(
								state.originalShadowPosition.X.Scale,
								state.originalShadowPosition.X.Offset,
								state.originalShadowPosition.Y.Scale,
								state.originalShadowPosition.Y.Offset + 2 -- Slight overshoot
							),
						}, 0.1, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
						shadowBounceTween:Play()
						currentHoverTweens.shadowBounce = shadowBounceTween
					end

					-- Phase 3: Settle to final position
					bounceDownTween.Completed:Connect(function()
						local settleTween = Utils.createTween(element, {
							Position = state.originalPosition,
						}, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
						settleTween:Play()
						currentHoverTweens.settle = settleTween

						-- Settle frame and shadow to final positions
						if frame then
							local frameSettleTween = Utils.createTween(frame, {
								Position = state.originalFramePosition,
							}, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
							frameSettleTween:Play()
							currentHoverTweens.frameSettle = frameSettleTween
						end

						if shadow then
							local shadowSettleTween = Utils.createTween(shadow, {
								Position = state.originalShadowPosition,
							}, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
							shadowSettleTween:Play()
							currentHoverTweens.shadowSettle = shadowSettleTween
						end
					end)
				end)

				-- Set ZIndex for hover effect
				element.ZIndex = 50

				-- Update the state reference with current tweens
				state.hoverTweens = currentHoverTweens
			end
		end)

		element.MouseLeave:Connect(function()
			if not state.isActive then
				-- Cancel any ongoing hover animations
				for _, tween in pairs(currentHoverTweens) do
					if tween and tween.Cancel then
						tween:Cancel()
					end
				end
				currentHoverTweens = {}
				-- Update the state reference as well
				state.hoverTweens = currentHoverTweens

				-- Immediately reset to original position (no animation on leave)
				element.Position = state.originalPosition
				if frame then
					frame.Position = state.originalFramePosition
				end
				if shadow then
					shadow.Position = state.originalShadowPosition
				end

				-- Restore original ZIndex
				element.ZIndex = state.originalZIndex
			end
		end)
	end

	-- Setup click animations - Animate frame position only
	if hasClick then
		element.MouseButton1Click:Connect(function()
			if not state.isActive then
				-- Cancel any ongoing hover animations
				if state.hoverTweens then
					for _, tween in pairs(state.hoverTweens) do
						if tween and tween.Cancel then
							tween:Cancel()
						end
					end
				end

				-- Reset button to original position immediately
				element.Position = state.originalPosition
				if frame then
					frame.Position = state.originalFramePosition
				end
				if shadow then
					shadow.Position = state.originalShadowPosition
				end

				-- Only animate frame position, don't change button size
				if frame then
					local frameClickTween = Utils.createTween(frame, {
						Position = UDim2.new(0, -2, 0, 2), -- Move frame to specified position
					}, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					frameClickTween:Play()

					-- Wait for click animation to complete
					frameClickTween.Completed:Wait()

					-- Return frame to original position
					local frameUpTween = Utils.createTween(frame, {
						Position = state.originalFramePosition,
					}, 0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
					frameUpTween:Play()
				end
			end
		end)
	end

	-- Setup active animations - Keep frame in clicked position
	if hasActive then
		element.MouseButton1Click:Connect(function()
			-- Check for Toggle BoolValue to prevent deactivation
			local toggleValue = element:FindFirstChild("Toggle")
			local hasToggleOff = toggleValue and toggleValue:IsA("BoolValue") and not toggleValue.Value

			-- If Toggle is false and already active, don't deactivate
			if hasToggleOff and state.isActive then
				return -- Don't deactivate if Toggle is false and already active
			end

			-- Cancel any ongoing hover animations to prevent conflicts
			-- Reset button to original position immediately
			element.Position = state.originalPosition
			if frame then
				frame.Position = state.originalFramePosition
			end
			if shadow then
				shadow.Position = state.originalShadowPosition
			end

			state.isActive = not state.isActive

			if state.isActive then
				-- Active state - only move frame, don't change button size
				if frame then
					local frameActiveTween = Utils.createTween(frame, {
						Position = UDim2.new(0, -2, 0, 2),
					}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					frameActiveTween:Play()
				end

				-- Set ZIndex for active state
				element.ZIndex = 75
			else
				-- Deactivate state - return frame to original position
				if frame then
					local frameDeactivateTween = Utils.createTween(frame, {
						Position = state.originalFramePosition,
					}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					frameDeactivateTween:Play()
				end

				-- Restore original ZIndex
				element.ZIndex = state.originalZIndex
			end
		end)
	end

	-- Store hover tween references in state for access from active animations
	state.hoverTweens = currentHoverTweens
end

-- Function to deactivate active state when menu closes
function GeneralButtonAnimations.deactivateButtonActiveStyle(button)
	local elementState = generalElementStates[button]

	if elementState then
		elementState.isActive = false

		-- Apply deactivate animation
		Utils.createHoverTween(button, {
			Size = elementState.originalSize,
			Rotation = elementState.originalRotation,
		}):Play()

		-- Find and deactivate active elements
		local frame = button:FindFirstChild("Frame")
		local shadow = button:FindFirstChild("Shadow")
		local icon = button:FindFirstChild("Icon")

		-- Return frame to original position
		if frame and elementState.originalFramePosition then
			local frameTween = Utils.createTween(frame, {
				Position = elementState.originalFramePosition,
			}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			frameTween:Play()
		end

		-- Return shadow to original position
		if shadow and elementState.originalShadowPosition then
			local shadowTween = Utils.createTween(shadow, {
				Position = elementState.originalShadowPosition,
			}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			shadowTween:Play()
		end

		-- Restore icon
		if icon then
			local iconTween = Utils.createTween(icon, {
				Size = UDim2.new(1, 0, 1, 0),
				Rotation = 0,
			}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			iconTween:Play()
		end

		-- Restore original ZIndex
		button.ZIndex = elementState.originalZIndex
	end
end

-- Function to get element states (for external access)
function GeneralButtonAnimations.getElementStates()
	return generalElementStates
end

return GeneralButtonAnimations
