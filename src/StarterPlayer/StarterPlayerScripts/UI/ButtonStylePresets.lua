-- ButtonStylePresets.lua
-- Professional style presets for hover, click, and active states
-- Provides ready-to-use style configurations for different button interactions

local ButtonStylePresets = {}

-- Professional hover effects
ButtonStylePresets.Hover = {
	-- Scale up with smooth transition
	ScaleUp = {
		Size = UDim2.new(1.05, 0, 1.05, 0),
		ZIndex = 5,
	},

	-- Scale down for subtle effect
	ScaleDown = {
		Size = UDim2.new(0.98, 0, 0.98, 0),
		ZIndex = 5,
	},

	-- Elevate with shadow effect
	Elevate = {
		Position = UDim2.new(0, 0, 0, -2),
		ZIndex = 5,
	},

	-- Brighten background
	Brighten = {
		BackgroundTransparency = 0.1,
		ZIndex = 5,
	},

	-- Glow effect (for UIStroke)
	Glow = {
		Thickness = 3,
		Transparency = 0.3,
		ZIndex = 5,
	},

	-- Pulse effect
	Pulse = {
		Size = UDim2.new(1.02, 0, 1.02, 0),
		BackgroundTransparency = 0.05,
		ZIndex = 5,
	},

	-- Slide up
	SlideUp = {
		Position = UDim2.new(0, 0, 0, -1),
		ZIndex = 5,
	},

	-- Rotate slightly
	Rotate = {
		Rotation = 2,
		ZIndex = 5,
	},
}

-- Professional click effects
ButtonStylePresets.Click = {
	-- Quick scale down
	Press = {
		Size = UDim2.new(0.95, 0, 0.95, 0),
		ZIndex = 10,
	},

	-- Deep press
	DeepPress = {
		Size = UDim2.new(0.9, 0, 0.9, 0),
		Position = UDim2.new(0, 0, 0, 2),
		ZIndex = 10,
	},

	-- Squash effect
	Squash = {
		Size = UDim2.new(1.1, 0, 0.9, 0),
		ZIndex = 10,
	},

	-- Bright flash
	Flash = {
		BackgroundTransparency = 0,
		ZIndex = 10,
	},

	-- Bounce down
	BounceDown = {
		Position = UDim2.new(0, 0, 0, 3),
		Size = UDim2.new(0.98, 0, 0.98, 0),
		ZIndex = 10,
	},

	-- Quick rotate
	QuickRotate = {
		Rotation = -5,
		Size = UDim2.new(0.97, 0, 0.97, 0),
		ZIndex = 10,
	},

	-- Squeeze
	Squeeze = {
		Size = UDim2.new(0.85, 0, 1.05, 0),
		ZIndex = 10,
	},

	-- Pop effect
	Pop = {
		Size = UDim2.new(1.08, 0, 1.08, 0),
		BackgroundTransparency = 0.02,
		ZIndex = 10,
	},
}

-- Professional active effects
ButtonStylePresets.Active = {
	-- Permanently elevated
	Elevated = {
		Position = UDim2.new(0, 0, 0, -3),
		ZIndex = 15,
	},

	-- Glowing border
	Glowing = {
		Thickness = 4,
		Transparency = 0.1,
		ZIndex = 15,
	},

	-- Pulsing glow
	PulseGlow = {
		Thickness = 3,
		Transparency = 0.2,
		ZIndex = 15,
	},

	-- Bright active state
	Bright = {
		BackgroundTransparency = 0,
		ZIndex = 15,
	},

	-- Highlighted
	Highlighted = {
		BackgroundTransparency = 0.05,
		ZIndex = 15,
	},

	-- Selected state
	Selected = {
		Size = UDim2.new(1.02, 0, 1.02, 0),
		Position = UDim2.new(0, 0, 0, -1),
		ZIndex = 15,
	},

	-- Active glow
	ActiveGlow = {
		Thickness = 5,
		Transparency = 0.05,
		ZIndex = 15,
	},

	-- Premium active
	Premium = {
		Size = UDim2.new(1.03, 0, 1.03, 0),
		Position = UDim2.new(0, 0, 0, -2),
		BackgroundTransparency = 0.02,
		ZIndex = 15,
	},
}

-- UIStroke specific presets
ButtonStylePresets.UIStroke = {
	Hover = {
		Glow = {
			Thickness = 3,
			Transparency = 0.3,
			Enabled = true,
		},
		Bright = {
			Transparency = 0.1,
			Enabled = true,
		},
		Thick = {
			Thickness = 4,
			Enabled = true,
		},
	},

	Click = {
		Press = {
			Thickness = 2,
			Enabled = true,
		},
		Flash = {
			Transparency = 0,
			Enabled = true,
		},
	},

	Active = {
		Glowing = {
			Thickness = 5,
			Transparency = 0.1,
			Enabled = true,
		},
		Bright = {
			Transparency = 0.05,
			Enabled = true,
		},
	},
}

-- UIGradient specific presets
ButtonStylePresets.UIGradient = {
	Hover = {
		Rotate = {
			Rotation = 15,
			Enabled = true,
		},
		Brighten = {
			Offset = Vector2.new(0, 0.3),
			Enabled = true,
		},
	},

	Click = {
		Flash = {
			Rotation = 0,
			Enabled = true,
		},
	},

	Active = {
		Active = {
			Rotation = 45,
			Enabled = true,
		},
		Premium = {
			Offset = Vector2.new(0, 0.5),
			Enabled = true,
		},
	},
}

-- Get preset by type and name
function ButtonStylePresets.getPreset(type, name, targetType)
	if type == "Hover" then
		if targetType == "UIStroke" then
			return ButtonStylePresets.UIStroke.Hover[name]
		elseif targetType == "UIGradient" then
			return ButtonStylePresets.UIGradient.Hover[name]
		else
			return ButtonStylePresets.Hover[name]
		end
	elseif type == "Click" then
		if targetType == "UIStroke" then
			return ButtonStylePresets.UIStroke.Click[name]
		elseif targetType == "UIGradient" then
			return ButtonStylePresets.UIGradient.Click[name]
		else
			return ButtonStylePresets.Click[name]
		end
	elseif type == "Active" then
		if targetType == "UIStroke" then
			return ButtonStylePresets.UIStroke.Active[name]
		elseif targetType == "UIGradient" then
			return ButtonStylePresets.UIGradient.Active[name]
		else
			return ButtonStylePresets.Active[name]
		end
	end
	return nil
end

-- Get all available presets for a type
function ButtonStylePresets.getAvailablePresets(type, targetType)
	if type == "Hover" then
		if targetType == "UIStroke" then
			return ButtonStylePresets.UIStroke.Hover
		elseif targetType == "UIGradient" then
			return ButtonStylePresets.UIGradient.Hover
		else
			return ButtonStylePresets.Hover
		end
	elseif type == "Click" then
		if targetType == "UIStroke" then
			return ButtonStylePresets.UIStroke.Click
		elseif targetType == "UIGradient" then
			return ButtonStylePresets.UIGradient.Click
		else
			return ButtonStylePresets.Click
		end
	elseif type == "Active" then
		if targetType == "UIStroke" then
			return ButtonStylePresets.UIStroke.Active
		elseif targetType == "UIGradient" then
			return ButtonStylePresets.UIGradient.Active
		else
			return ButtonStylePresets.Active
		end
	end
	return {}
end

return ButtonStylePresets
