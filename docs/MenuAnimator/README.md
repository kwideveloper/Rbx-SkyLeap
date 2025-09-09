# MenuAnimator System Documentation

Welcome to the complete MenuAnimator system documentation. This system provides a comprehensive solution for UI animations, interactions, and styling in Roblox.

## System Overview

The MenuAnimator system is a modular, professional-grade UI animation and interaction system designed for Roblox games. It provides:

- **Menu Animations**: Smooth opening and closing animations for menus
- **Button Interactions**: Professional hover, click, and active state effects
- **Custom Styling**: Dynamic style modifications for UI elements
- **Interactive Styles**: Pre-built professional style presets
- **Real-time Monitoring**: Automatic detection and application of styles

## Documentation Structure

### Core Components
- **[MenuAnimator System](MenuAnimatorSystem.md)** - Main system overview and setup
- **[Style Manager](StyleManager.md)** - Custom style modifications
- **[Interactive Styles](InteractiveStyles.md)** - Hover, click, and active effects
- **[Attribute Style System](AttributeStyleSystem.md)** - Clean attribute-based styling
- **[Button Style Presets](ButtonStylePresets.md)** - Professional style presets

### Advanced Features
- **[Animation System](AnimationSystem.md)** - Animation presets and customization
- **[Integration Guide](IntegrationGuide.md)** - How to integrate with other systems
- **[Best Practices](BestPractices.md)** - Recommended usage patterns
- **[Troubleshooting](Troubleshooting.md)** - Common issues and solutions

## Quick Start

### Basic Menu Setup
```lua
-- Create a button with menu functionality
local button = Instance.new("TextButton")
button.Name = "MenuButton"

-- Menu reference
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetMenu
openValue.Parent = button

-- Animation type
local animateValue = Instance.new("StringValue")
animateValue.Name = "Animate"
animateValue.Value = "Active"
animateValue.Parent = button
```

### Interactive Styles (Attributes - Recommended)
```lua
-- Add hover effect
button:SetAttribute("HoverStyle", "ScaleUp")

-- Add click effect
button:SetAttribute("ClickStyle", "Press")

-- Add active effect
button:SetAttribute("ActiveStyle", "Elevated")
```

### Interactive Styles (StringValues - Legacy)
```lua
-- Add hover effect
local hoverValue = Instance.new("StringValue")
hoverValue.Name = "HoverStyle"
hoverValue.Value = "ScaleUp" -- Preset name
hoverValue.Parent = button

-- Add click effect
local clickValue = Instance.new("StringValue")
clickValue.Name = "ClickStyle"
clickValue.Value = "Press" -- Preset name
clickValue.Parent = button

-- Add active effect
local activeValue = Instance.new("StringValue")
activeValue.Name = "ActiveStyle"
activeValue.Value = "Elevated" -- Preset name
activeValue.Parent = button
```

### Custom Styling
```lua
-- Target UI element
local targetValue = Instance.new("ObjectValue")
targetValue.Name = "Target"
targetValue.Value = backgroundFrame
targetValue.Parent = button

-- Custom styles
local styleValue = Instance.new("StringValue")
styleValue.Name = "Style"
styleValue.Value = "{ BackgroundColor3 = Color3.fromRGB(255, 0, 0), BackgroundTransparency = 0.1 }"
styleValue.Parent = button
```

## System Architecture

```
MenuAnimator System
├── Core System
│   ├── MenuAnimator.client.lua
│   ├── MenuManager.lua
│   └── Utils.lua
├── Animation System
│   ├── AnimationPresets.lua
│   ├── MenuAnimations.lua
│   └── MenuAnimationsOut.lua
├── Style System
│   ├── StyleManager.lua
│   ├── InteractiveStyleManager.lua
│   └── ButtonStylePresets.lua
└── Button System
    ├── ButtonAnimations.lua
    └── GeneralButtonAnimations.lua
```

## Features

### ✅ Menu Animations
- Smooth slide, fade, and scale animations
- Customizable animation presets
- Automatic menu state management
- Real-time menu monitoring

### ✅ Interactive Styles
- Professional hover effects
- Responsive click animations
- Dynamic active states
- Pre-built style presets

### ✅ Custom Styling
- Dynamic style modifications
- Universal property support
- Automatic style restoration
- Cross-object compatibility

### ✅ Button System
- Tag-based button detection
- Gradient animations
- State management
- Event handling

## Getting Help

- **Documentation**: Check the specific component documentation
- **Examples**: See the examples in each documentation file
- **Troubleshooting**: Check the troubleshooting guide
- **Best Practices**: Follow the recommended usage patterns

## Version Information

- **Current Version**: 2.0.0
- **Last Updated**: 2024
- **Compatibility**: Roblox Studio 2024+

---

*This documentation is part of the SkyLeap project's MenuAnimator system.*
