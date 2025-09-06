-- AnimationPresets.lua
-- Animation presets for easy configuration

local AnimationPresets = {}

-- Animation presets for easy configuration
AnimationPresets.PRESETS = {
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

return AnimationPresets
