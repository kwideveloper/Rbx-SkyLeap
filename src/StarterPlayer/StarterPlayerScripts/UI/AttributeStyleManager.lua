-- AttributeStyleManager.lua
-- Handles button styles using attributes instead of StringValues
-- Provides a cleaner and more efficient way to manage button interactions

local TweenService = game:GetService("TweenService")
local ButtonStylePresets = require(script.Parent.ButtonStylePresets)

local AttributeStyleManager = {}

-- Style states for interactive elements
local styleStates = {} -- Track original styles and connections
local activeStyles = {} -- Track currently active styles

-- Get target type for appropriate preset selection
local function getTargetType(targetUI)
	if targetUI:IsA("UIStroke") then
		return "UIStroke"
	elseif targetUI:IsA("UIGradient") then
		return "UIGradient"
	else
		return "GuiObject"
	end
end

-- Parse style string (reuse from StyleManager)
local function parseStyleString(styleString)
	local cleanString = styleString:gsub("^%s*{", ""):gsub("}%s*$", ""):gsub("^%s*", ""):gsub("%s*$", "")

	if cleanString == "" then
		return {}
	end

	local result = {}
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

	for _, part in ipairs(parts) do
		local key, value = part:match("^([^=]+)=(.+)$")
		if key and value then
			key = key:gsub("^%s*", ""):gsub("%s*$", "")
			value = value:gsub("^%s*", ""):gsub("%s*$", "")

			local parsedValue = nil

			if value == "true" then
				parsedValue = true
			elseif value == "false" then
				parsedValue = false
			elseif value:match('^".*"$') or value:match("^'.*'$") then
				parsedValue = value:sub(2, -2)
			elseif value:match("^%-?%d+%.?%d*$") then
				parsedValue = tonumber(value)
			else
				local num = tonumber(value)
				if num then
					parsedValue = num
				end
			end

			if parsedValue ~= nil then
				result[key] = parsedValue
			end
		end
	end

	return result
end

-- Apply style with animation
local function applyStyleWithAnimation(targetUI, styleTable, duration)
	duration = duration or 0.2

	-- Check which properties can be tweened
	local tweenableProperties = {}
	local instantProperties = {}

	for property, value in pairs(styleTable) do
		local success, currentValue = pcall(function()
			return targetUI[property]
		end)

		if success then
			-- Check if property can be tweened
			if
				property == "BackgroundTransparency"
				or property == "TextTransparency"
				or property == "ImageTransparency"
				or property == "Transparency"
				or property == "Thickness"
				or property == "Size"
				or property == "Position"
				or property == "Rotation"
			then
				tweenableProperties[property] = value
			else
				instantProperties[property] = value
			end
		end
	end

	-- Apply instant properties first
	for property, value in pairs(instantProperties) do
		local writeSuccess = pcall(function()
			targetUI[property] = value
		end)
	end

	-- Apply tweenable properties with animation
	if next(tweenableProperties) then
		print("🎬 AttributeStyleManager: Creating tween for properties:", tweenableProperties)
		local tween = TweenService:Create(
			targetUI,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			tweenableProperties
		)
		tween:Play()
		print("✅ AttributeStyleManager: Tween started")
	else
		print("⚠️ AttributeStyleManager: No tweenable properties found")
	end
end

-- Restore original style
local function restoreOriginalStyle(targetUI, originalStyle, duration)
	duration = duration or 0.2

	-- Check which properties can be tweened
	local tweenableProperties = {}
	local instantProperties = {}

	for property, value in pairs(originalStyle) do
		local success, currentValue = pcall(function()
			return targetUI[property]
		end)

		if success then
			-- Check if property can be tweened
			if
				property == "BackgroundTransparency"
				or property == "TextTransparency"
				or property == "ImageTransparency"
				or property == "Transparency"
				or property == "Thickness"
				or property == "Size"
				or property == "Position"
				or property == "Rotation"
			then
				tweenableProperties[property] = value
			else
				instantProperties[property] = value
			end
		end
	end

	-- Apply instant properties first
	for property, value in pairs(instantProperties) do
		local writeSuccess = pcall(function()
			targetUI[property] = value
		end)
	end

	-- Apply tweenable properties with animation
	if next(tweenableProperties) then
		local tween = TweenService:Create(
			targetUI,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			tweenableProperties
		)
		tween:Play()
	end
end

-- Save original style of a UI element
local function saveOriginalStyle(targetUI)
	local originalStyle = {}
	for _, property in ipairs({
		"BackgroundColor3",
		"BackgroundTransparency",
		"BorderColor3",
		"BorderSizePixel",
		"TextColor3",
		"TextTransparency",
		"Size",
		"Position",
		"Rotation",
		"AnchorPoint",
		"ZIndex",
		"Visible",
		"Transparency",
		"ImageColor3",
		"ImageTransparency",
		"Color",
		"Thickness",
		"Enabled",
		"Offset",
		"Rotation",
	}) do
		local success, value = pcall(function()
			return targetUI[property]
		end)

		if success and value ~= nil then
			originalStyle[property] = value
		end
	end
	return originalStyle
end

-- Check if button has style configuration
local function hasStyleConfiguration(button)
	local hoverStyle = button:GetAttribute("HoverStyle")
	local clickStyle = button:GetAttribute("ClickStyle")
	local activeStyle = button:GetAttribute("ActiveStyle")
	local targetHoverStyle = button:GetAttribute("TargetHoverStyle")
	local targetClickStyle = button:GetAttribute("TargetClickStyle")
	local targetActiveStyle = button:GetAttribute("TargetActiveStyle")

	local hasAnyStyle = hoverStyle
		or clickStyle
		or activeStyle
		or targetHoverStyle
		or targetClickStyle
		or targetActiveStyle

	-- Only log if button has styles configured
	if hasAnyStyle then
		print("🎨 AttributeStyleManager: Found styles for", button.Name)
		if hoverStyle then
			print("  - HoverStyle:", hoverStyle)
		end
		if clickStyle then
			print("  - ClickStyle:", clickStyle)
		end
		if activeStyle then
			print("  - ActiveStyle:", activeStyle)
		end
		if targetHoverStyle then
			print("  - TargetHoverStyle:", targetHoverStyle)
		end
		if targetClickStyle then
			print("  - TargetClickStyle:", targetClickStyle)
		end
		if targetActiveStyle then
			print("  - TargetActiveStyle:", targetActiveStyle)
		end
	end

	return hasAnyStyle
end

-- Setup styles for a button
function AttributeStyleManager.setupButtonStyles(button)
	if not hasStyleConfiguration(button) then
		return false
	end

	print("✅ AttributeStyleManager: Setting up styles for button:", button.Name)

	-- Initialize state tracking
	if not styleStates[button] then
		styleStates[button] = {
			original = {},
			targetOriginal = {},
			connections = {},
		}
	end

	-- Save original button style
	styleStates[button].original = saveOriginalStyle(button)

	-- Save original target style if exists
	local targetValue = button:FindFirstChild("Target")
	if targetValue and targetValue:IsA("ObjectValue") and targetValue.Value then
		styleStates[button].targetOriginal = saveOriginalStyle(targetValue.Value)
	end

	-- Setup hover effects
	local hoverStyle = button:GetAttribute("HoverStyle")
	print("🎨 AttributeStyleManager: HoverStyle for", button.Name, ":", hoverStyle)

	if hoverStyle then
		local styleTable = nil

		-- Check if it's a preset name
		if not hoverStyle:match("{") then
			local targetType = getTargetType(button)
			print("🎨 AttributeStyleManager: Getting preset for", hoverStyle, "type:", targetType)
			styleTable = ButtonStylePresets.getPreset("Hover", hoverStyle, targetType)
			print("🎨 AttributeStyleManager: Preset result:", styleTable)
		else
			-- Parse custom style
			styleTable = parseStyleString(hoverStyle)
		end

		if styleTable then
			print("✅ AttributeStyleManager: Setting up hover connections for", button.Name)
			print("🎨 StyleTable:", styleTable)
			local connection = button.MouseEnter:Connect(function()
				print("🖱️ AttributeStyleManager: MouseEnter triggered for", button.Name)
				applyStyleWithAnimation(button, styleTable, 0.2)
			end)
			table.insert(styleStates[button].connections, connection)

			local connection2 = button.MouseLeave:Connect(function()
				print("🖱️ AttributeStyleManager: MouseLeave triggered for", button.Name)
				restoreOriginalStyle(button, styleStates[button].original, 0.2)
			end)
			table.insert(styleStates[button].connections, connection2)
		else
			print("❌ AttributeStyleManager: No styleTable found for hover style:", hoverStyle)
		end
	else
		print("❌ AttributeStyleManager: No HoverStyle attribute found for", button.Name)
	end

	-- Setup target hover effects
	local targetHoverStyle = button:GetAttribute("TargetHoverStyle")
	if targetHoverStyle and targetValue and targetValue.Value then
		local styleTable = nil

		if not targetHoverStyle:match("{") then
			local targetType = getTargetType(targetValue.Value)
			styleTable = ButtonStylePresets.getPreset("Hover", targetHoverStyle, targetType)
		else
			styleTable = parseStyleString(targetHoverStyle)
		end

		if styleTable then
			local connection = button.MouseEnter:Connect(function()
				applyStyleWithAnimation(targetValue.Value, styleTable, 0.2)
			end)
			table.insert(styleStates[button].connections, connection)

			local connection2 = button.MouseLeave:Connect(function()
				restoreOriginalStyle(targetValue.Value, styleStates[button].targetOriginal, 0.2)
			end)
			table.insert(styleStates[button].connections, connection2)
		end
	end

	-- Setup click effects
	local clickStyle = button:GetAttribute("ClickStyle")
	if clickStyle then
		local styleTable = nil

		if not clickStyle:match("{") then
			local targetType = getTargetType(button)
			styleTable = ButtonStylePresets.getPreset("Click", clickStyle, targetType)
		else
			styleTable = parseStyleString(clickStyle)
		end

		if styleTable then
			local connection = button.MouseButton1Down:Connect(function()
				applyStyleWithAnimation(button, styleTable, 0.1)
			end)
			table.insert(styleStates[button].connections, connection)

			local connection2 = button.MouseButton1Up:Connect(function()
				restoreOriginalStyle(button, styleStates[button].original, 0.1)
			end)
			table.insert(styleStates[button].connections, connection2)
		end
	end

	-- Setup target click effects
	local targetClickStyle = button:GetAttribute("TargetClickStyle")
	if targetClickStyle and targetValue and targetValue.Value then
		local styleTable = nil

		if not targetClickStyle:match("{") then
			local targetType = getTargetType(targetValue.Value)
			styleTable = ButtonStylePresets.getPreset("Click", targetClickStyle, targetType)
		else
			styleTable = parseStyleString(targetClickStyle)
		end

		if styleTable then
			local connection = button.MouseButton1Down:Connect(function()
				applyStyleWithAnimation(targetValue.Value, styleTable, 0.1)
			end)
			table.insert(styleStates[button].connections, connection)

			local connection2 = button.MouseButton1Up:Connect(function()
				restoreOriginalStyle(targetValue.Value, styleStates[button].targetOriginal, 0.1)
			end)
			table.insert(styleStates[button].connections, connection2)
		end
	end

	return true
end

-- Apply active style
function AttributeStyleManager.applyActiveStyle(button)
	if not styleStates[button] then
		return false
	end

	local activeStyle = button:GetAttribute("ActiveStyle")
	local targetActiveStyle = button:GetAttribute("TargetActiveStyle")
	local targetValue = button:FindFirstChild("Target")

	-- Apply button active style
	if activeStyle then
		local styleTable = nil

		if not activeStyle:match("{") then
			local targetType = getTargetType(button)
			styleTable = ButtonStylePresets.getPreset("Active", activeStyle, targetType)
		else
			styleTable = parseStyleString(activeStyle)
		end

		if styleTable then
			applyStyleWithAnimation(button, styleTable, 0.3)
			activeStyles[button] = { target = button, style = "active" }
		end
	end

	-- Apply target active style
	if targetActiveStyle and targetValue and targetValue.Value then
		local styleTable = nil

		if not targetActiveStyle:match("{") then
			local targetType = getTargetType(targetValue.Value)
			styleTable = ButtonStylePresets.getPreset("Active", targetActiveStyle, targetType)
		else
			styleTable = parseStyleString(targetActiveStyle)
		end

		if styleTable then
			applyStyleWithAnimation(targetValue.Value, styleTable, 0.3)
			activeStyles[button] = { target = targetValue.Value, style = "targetActive" }
		end
	end

	return true
end

-- Remove active style
function AttributeStyleManager.removeActiveStyle(button)
	if not styleStates[button] then
		return false
	end

	local activeStyle = button:GetAttribute("ActiveStyle")
	local targetActiveStyle = button:GetAttribute("TargetActiveStyle")
	local targetValue = button:FindFirstChild("Target")

	-- Remove button active style
	if activeStyle then
		restoreOriginalStyle(button, styleStates[button].original, 0.3)
	end

	-- Remove target active style
	if targetActiveStyle and targetValue and targetValue.Value then
		restoreOriginalStyle(targetValue.Value, styleStates[button].targetOriginal, 0.3)
	end

	activeStyles[button] = nil
	return true
end

-- Clean up styles for a button
function AttributeStyleManager.cleanupButtonStyles(button)
	if styleStates[button] then
		-- Disconnect all connections
		for _, connection in ipairs(styleStates[button].connections) do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end

		-- Remove from tracking
		styleStates[button] = nil
		activeStyles[button] = nil
	end
end

-- Clean up all styles
function AttributeStyleManager.cleanupAllStyles()
	for button, _ in pairs(styleStates) do
		AttributeStyleManager.cleanupButtonStyles(button)
	end
	styleStates = {}
	activeStyles = {}
end

-- Get available presets for a type
function AttributeStyleManager.getAvailablePresets(type, targetType)
	return ButtonStylePresets.getAvailablePresets(type, targetType)
end

-- Get style state for debugging
function AttributeStyleManager.getStyleStates()
	return styleStates
end

return AttributeStyleManager
