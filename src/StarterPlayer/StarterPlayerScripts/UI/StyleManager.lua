-- StyleManager.lua
-- Handles custom style modifications for UI elements when buttons are active
-- Allows buttons to modify specific UI elements when their associated menu is open

local TweenService = game:GetService("TweenService")

local StyleManager = {}

-- Style states storage
local styleStates = {} -- Track original styles and active styles for target UIs
local activeStyleButtons = {} -- Track which buttons are currently applying styles

-- Common style properties that can be modified
-- This is a comprehensive list, but the system will dynamically check if properties exist
local COMMON_STYLE_PROPERTIES = {
	-- GuiObject properties
	"BackgroundColor3",
	"BackgroundTransparency",
	"BorderColor3",
	"BorderSizePixel",
	"TextColor3",
	"TextTransparency",
	"TextStrokeTransparency",
	"TextStrokeColor3",
	"TextSize",
	"Font",
	"Size",
	"Position",
	"Rotation",
	"AnchorPoint",
	"ZIndex",
	"Visible",
	"Transparency",
	"ImageColor3",
	"ImageTransparency",
	"ScaleType",
	"SliceCenter",
	"SliceScale",
	"TileSize",
	-- UIComponent properties (UIStroke, UIGradient, etc.)
	"Color",
	"Thickness",
	"Enabled",
	"Offset",
	"ColorSequence",
	"TransparencySequence",
	-- UIGradient specific
	"GradientRotation",
	-- UIStroke specific
	"ApplyStrokeMode",
	-- UIAspectRatioConstraint
	"AspectRatio",
	"AspectType",
	"DominantAxis",
	-- UISizeConstraint
	"MaxSize",
	"MinSize",
	-- UICorner
	"CornerRadius",
	-- UIPadding
	"PaddingBottom",
	"PaddingLeft",
	"PaddingRight",
	"PaddingTop",
}

-- Parse style string from StringValue
local function parseStyleString(styleString)
	-- Simple parser for style strings
	-- Expected format: { key1 = value1, key2 = value2, ... }

	-- Remove whitespace and braces
	local cleanString = styleString:gsub("^%s*{", ""):gsub("}%s*$", ""):gsub("^%s*", ""):gsub("%s*$", "")

	if cleanString == "" then
		return {}
	end

	local result = {}

	-- Split by commas, but be careful with nested structures
	local parts = {}
	local current = ""
	local depth = 0
	local inString = false
	local stringChar = nil

	for i = 1, #cleanString do
		local char = cleanString:sub(i, i)

		if not inString then
			if char == '"' or char == "'" then
				inString = true
				stringChar = char
			elseif char == "{" or char == "(" then
				depth = depth + 1
			elseif char == "}" or char == ")" then
				depth = depth - 1
			elseif char == "," and depth == 0 then
				local cleanPart = current:gsub("^%s*", ""):gsub("%s*$", "")
				table.insert(parts, cleanPart)
				current = ""
			else
				current = current .. char
			end
		else
			if char == stringChar and cleanString:sub(i - 1, i - 1) ~= "\\" then
				inString = false
				stringChar = nil
			end
			current = current .. char
		end
	end

	if current ~= "" then
		local cleanPart = current:gsub("^%s*", ""):gsub("%s*$", "")
		table.insert(parts, cleanPart)
	end

	-- Parse each key-value pair
	for _, part in ipairs(parts) do
		local key, value = part:match("^([^=]+)=(.+)$")
		if key and value then
			key = key:gsub("^%s*", ""):gsub("%s*$", "")
			value = value:gsub("^%s*", ""):gsub("%s*$", "")

			-- Parse value based on type
			local parsedValue = nil

			-- Boolean values
			if value == "true" then
				parsedValue = true
			elseif value == "false" then
				parsedValue = false
			-- String values
			elseif value:match('^".*"$') or value:match("^'.*'$") then
				parsedValue = value:sub(2, -2)
			-- Number values
			elseif value:match("^%-?%d+%.?%d*$") then
				parsedValue = tonumber(value)
			-- Enum values (simplified)
			elseif value:match("^Enum%.") then
				-- For now, skip complex enum parsing
				-- This would need more sophisticated parsing
				-- Skip this value
				-- Color3 values (simplified)
			elseif value:match("^Color3%.") then
				-- For now, skip complex Color3 parsing
				-- This would need more sophisticated parsing
				-- Skip this value
				-- UDim2 values (simplified)
			elseif value:match("^UDim2%.") then
				-- For now, skip complex UDim2 parsing
				-- This would need more sophisticated parsing
				-- Skip this value
				-- Vector2 values (simplified)
			elseif value:match("^Vector2%.") then
				-- For now, skip complex Vector2 parsing
				-- This would need more sophisticated parsing
				-- Skip this value
			else
				-- Try to parse as a number
				local num = tonumber(value)
				if num then
					parsedValue = num
				else
					-- Skip unknown values
					-- Skip this value
				end
			end

			-- Only add to result if we successfully parsed the value
			if parsedValue ~= nil then
				result[key] = parsedValue
			end
		end
	end

	return result
end

-- Save original style properties of a UI element
local function saveOriginalStyle(targetUI)
	if not targetUI or not targetUI:IsA("Instance") then
		return false
	end

	if not styleStates[targetUI] then
		styleStates[targetUI] = {
			original = {},
			active = {},
			appliedBy = nil,
		}
	end

	-- Save original properties dynamically
	-- First try common properties
	for _, property in ipairs(COMMON_STYLE_PROPERTIES) do
		local success, value = pcall(function()
			return targetUI[property]
		end)

		if success and value ~= nil then
			styleStates[targetUI].original[property] = value
		end
	end

	-- Also save any properties that might be in the style table but not in our common list
	-- This allows for custom properties that we might not have anticipated
	if styleStates[targetUI].active then
		for property, _ in pairs(styleStates[targetUI].active) do
			local success, value = pcall(function()
				return targetUI[property]
			end)

			if success and value ~= nil and not styleStates[targetUI].original[property] then
				styleStates[targetUI].original[property] = value
			end
		end
	end

	return true
end

-- Apply custom style to target UI
local function applyCustomStyle(targetUI, styleTable, button)
	if not targetUI or not targetUI:IsA("Instance") then
		return false
	end

	-- Save original style if not already saved
	if not styleStates[targetUI] then
		saveOriginalStyle(targetUI)
	end

	-- Store active style and button reference
	styleStates[targetUI].active = styleTable
	styleStates[targetUI].appliedBy = button

	-- Apply each style property
	for property, value in pairs(styleTable) do
		-- Check if the property exists and is writable
		local success, currentValue = pcall(function()
			return targetUI[property]
		end)

		if success then
			-- Property exists, check if it's writable
			local writeSuccess = pcall(function()
				targetUI[property] = value
			end)

			if writeSuccess then
				-- Property is writable, apply with appropriate animation
				if
					property == "BackgroundTransparency"
					or property == "TextTransparency"
					or property == "ImageTransparency"
					or property == "Transparency"
					or property == "Thickness"
				then
					-- Create smooth transition for numeric properties
					local tween = TweenService:Create(
						targetUI,
						TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ [property] = value }
					)
					tween:Play()
				else
					-- Apply immediately for other properties
					targetUI[property] = value
				end
			else
				-- Property exists but is not writable, skip silently
				-- This can happen with read-only properties
			end
		else
			-- Property doesn't exist on this object, skip silently
			-- This allows for flexible style definitions across different object types
			-- No warning needed - this is expected behavior for cross-object style definitions
		end
	end

	-- Track this button as having an active style
	activeStyleButtons[button] = targetUI

	return true
end

-- Restore original style of target UI
local function restoreOriginalStyle(targetUI)
	if not targetUI or not styleStates[targetUI] then
		return false
	end

	local originalStyle = styleStates[targetUI].original

	-- Restore each original property with smooth transition
	for property, value in pairs(originalStyle) do
		-- Check if the property still exists and is writable
		local success, currentValue = pcall(function()
			return targetUI[property]
		end)

		if success then
			-- Property exists, check if it's writable
			local writeSuccess = pcall(function()
				targetUI[property] = value
			end)

			if writeSuccess then
				-- Property is writable, restore with appropriate animation
				if
					property == "BackgroundTransparency"
					or property == "TextTransparency"
					or property == "ImageTransparency"
					or property == "Transparency"
					or property == "Thickness"
				then
					-- Create smooth transition for numeric properties
					local tween = TweenService:Create(
						targetUI,
						TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ [property] = value }
					)
					tween:Play()
				else
					-- Apply immediately for other properties
					targetUI[property] = value
				end
			end
		end
	end

	-- Clear active style
	styleStates[targetUI].active = {}
	styleStates[targetUI].appliedBy = nil

	return true
end

-- Check if button has style configuration
local function hasStyleConfiguration(button)
	if not button or not button:IsA("GuiObject") then
		return false
	end

	local targetValue = button:FindFirstChild("Target")
	local styleValue = button:FindFirstChild("Style")

	-- Check if both values exist and are correct types
	if not targetValue or not targetValue:IsA("ObjectValue") then
		return false
	end

	if not styleValue or not styleValue:IsA("StringValue") then
		return false
	end

	-- Check if target value has a value (can be nil during loading)
	if not targetValue.Value then
		return false
	end

	-- Check if style string is not empty
	if not styleValue.Value or styleValue.Value == "" then
		return false
	end

	return true
end

-- Apply style when button becomes active
function StyleManager.applyButtonStyle(button)
	if not hasStyleConfiguration(button) then
		return false
	end

	print("🎨 StyleManager: Applying styles to button:", button.Name)

	local targetValue = button:FindFirstChild("Target")
	local styleValue = button:FindFirstChild("Style")

	local targetUI = targetValue.Value
	local styleString = styleValue.Value

	-- Enhanced validation
	if not targetUI then
		-- Target UI is nil, skip silently (might be loading)
		return false
	end

	-- Check if target UI is a valid Instance for styling
	if not targetUI:IsA("Instance") then
		-- Target UI exists but is not a valid Instance
		warn("StyleManager: Target UI is not a valid Instance. Expected Instance, got:", type(targetUI))
		return false
	end

	-- Check if target UI is still valid (not destroyed)
	if not targetUI.Parent then
		-- Target UI has been destroyed, skip silently
		return false
	end

	local styleTable = parseStyleString(styleString)
	if not next(styleTable) then
		return false
	end

	return applyCustomStyle(targetUI, styleTable, button)
end

-- Remove style when button becomes inactive
function StyleManager.removeButtonStyle(button)
	if not activeStyleButtons[button] then
		return false
	end

	print("🔄 StyleManager: Removing styles from button:", button.Name)

	local targetUI = activeStyleButtons[button]
	restoreOriginalStyle(targetUI)

	-- Remove from active tracking
	activeStyleButtons[button] = nil

	return true
end

-- Clean up styles for a specific button
function StyleManager.cleanupButtonStyles(button)
	if activeStyleButtons[button] then
		StyleManager.removeButtonStyle(button)
	end
end

-- Clean up all styles
function StyleManager.cleanupAllStyles()
	for button, targetUI in pairs(activeStyleButtons) do
		restoreOriginalStyle(targetUI)
	end
	activeStyleButtons = {}
	styleStates = {}
end

-- Clean up styles for destroyed UIs
function StyleManager.cleanupDestroyedUIs()
	local cleanedButtons = {}

	for button, targetUI in pairs(activeStyleButtons) do
		-- Check if target UI still exists and has a parent
		if not targetUI or not targetUI.Parent then
			-- UI has been destroyed, clean it up
			cleanedButtons[button] = true
			styleStates[targetUI] = nil
		end
	end

	-- Remove cleaned buttons from active tracking
	for button, _ in pairs(cleanedButtons) do
		activeStyleButtons[button] = nil
	end
end

-- Get style state for debugging
function StyleManager.getStyleStates()
	return styleStates
end

-- Get active style buttons for debugging
function StyleManager.getActiveStyleButtons()
	return activeStyleButtons
end

return StyleManager
