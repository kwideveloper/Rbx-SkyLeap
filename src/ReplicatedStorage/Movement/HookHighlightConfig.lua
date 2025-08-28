-- Hook Highlight Configuration
-- Customize the visual appearance of hook highlights when they're in view

local HookHighlightConfig = {}

-- Highlight Colors
HookHighlightConfig.Colors = {
	-- Primary highlight colors
	PRIMARY = {
		FILL = Color3.fromRGB(0, 255, 255), -- Cyan fill
		OUTLINE = Color3.fromRGB(0, 200, 200), -- Darker cyan outline
	},

	-- Alternative color schemes
	ALTERNATIVE_1 = {
		FILL = Color3.fromRGB(255, 255, 0), -- Yellow fill
		OUTLINE = Color3.fromRGB(200, 200, 0), -- Darker yellow outline
	},

	ALTERNATIVE_2 = {
		FILL = Color3.fromRGB(0, 255, 0), -- Green fill
		OUTLINE = Color3.fromRGB(0, 200, 0), -- Darker green outline
	},

	ALTERNATIVE_3 = {
		FILL = Color3.fromRGB(255, 0, 255), -- Magenta fill
		OUTLINE = Color3.fromRGB(200, 0, 200), -- Darker magenta outline
	},

	-- Cooldown state colors (when hook is on cooldown)
	COOLDOWN = {
		FILL = Color3.fromRGB(255, 100, 100), -- Light red fill
		OUTLINE = Color3.fromRGB(200, 50, 50), -- Darker red outline
	},
}

-- Highlight Properties
HookHighlightConfig.Properties = {
	-- Transparency settings
	FILL_TRANSPARENCY = 0.3, -- Fill transparency (0 = opaque, 1 = invisible)
	OUTLINE_TRANSPARENCY = 0.0, -- Outline transparency (0 = opaque, 1 = invisible)

	-- Depth and rendering
	DEPTH_MODE = Enum.HighlightDepthMode.AlwaysOnTop, -- AlwaysOnTop, Occluded, or Never
	ENABLED = true, -- Whether highlights are enabled by default

	-- Animation settings
	PULSE_ENABLED = false, -- Enable pulsing animation
	PULSE_SPEED = 2.0, -- Pulses per second
	PULSE_INTENSITY = 0.2, -- How much the transparency varies during pulse
}

-- Performance Settings
HookHighlightConfig.Performance = {
	MAX_HIGHLIGHTS = 50, -- Maximum number of highlights to create
	UPDATE_RATE = 60, -- How often to update highlights (FPS)
	ENABLE_CULLING = true, -- Disable highlights for far hooks
	CULLING_DISTANCE = 200, -- Distance at which to cull highlights
	BATCH_UPDATE = true, -- Update highlights in batches for performance
	BATCH_SIZE = 10, -- Number of highlights to update per frame
}

-- Visual Effects
HookHighlightConfig.Effects = {
	-- Glow effect
	GLOW_ENABLED = true, -- Enable glow effect around highlighted hooks
	GLOW_COLOR = Color3.fromRGB(0, 255, 255), -- Glow color
	GLOW_INTENSITY = 0.5, -- Glow intensity (0 to 1)

	-- Pulse effect
	PULSE_ENABLED = true, -- Enable pulsing transparency
	PULSE_SPEED = 1.5, -- Pulse speed in Hz
	PULSE_MIN_ALPHA = 0.1, -- Minimum transparency during pulse
	PULSE_MAX_ALPHA = 0.5, -- Maximum transparency during pulse
}

-- Hook Detection Settings
HookHighlightConfig.Detection = {
	-- Tags to look for
	HOOK_TAGS = { "Hookable", "GrapplePoint" }, -- Tags that identify hookable objects

	-- Range and visibility
	MAX_RANGE = 90, -- Maximum distance to show highlights
	REQUIRE_LINE_OF_SIGHT = true, -- Only highlight hooks that are visible
	IGNORE_TAGS = { "HookIgnoreLOS" }, -- Tags that ignore line of sight checks

	-- Priority system
	PRIORITY_BY_DISTANCE = true, -- Prioritize closer hooks
	PRIORITY_BY_ANGLE = false, -- Prioritize hooks in front of player
	ANGLE_WEIGHT = 0.3, -- Weight for angle-based priority (0 to 1)
}

-- Helper function to get current color scheme
function HookHighlightConfig.getCurrentColors()
	return HookHighlightConfig.Colors.PRIMARY
end

-- Helper function to get cooldown colors
function HookHighlightConfig.getCooldownColors()
	return HookHighlightConfig.Colors.COOLDOWN
end

-- Helper function to get color scheme by name
function HookHighlightConfig.getColorScheme(schemeName)
	if schemeName and HookHighlightConfig.Colors[schemeName] then
		return HookHighlightConfig.Colors[schemeName]
	end
	return HookHighlightConfig.Colors.PRIMARY -- Default to primary colors
end

-- Helper function to get property value
function HookHighlightConfig.getProperty(propertyName)
	return HookHighlightConfig.Properties[propertyName]
end

-- Helper function to get performance setting
function HookHighlightConfig.getPerformanceSetting(settingName)
	return HookHighlightConfig.Performance[settingName]
end

-- Helper function to get effect setting
function HookHighlightConfig.getEffectSetting(settingName)
	return HookHighlightConfig.Effects[settingName]
end

-- Helper function to get detection setting
function HookHighlightConfig.getDetectionSetting(settingName)
	return HookHighlightConfig.Detection[settingName]
end

return HookHighlightConfig
