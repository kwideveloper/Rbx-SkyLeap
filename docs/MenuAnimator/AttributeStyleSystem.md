# Attribute Style System

The Attribute Style System provides a clean and efficient way to manage button styles using attributes instead of multiple StringValues. This system offers better performance, cleaner code, and easier maintenance.

## Overview

The Attribute Style System allows you to configure button styles directly through attributes, eliminating the need for multiple StringValue children. It supports both preset styles and custom style strings.

## Setup

### Basic Configuration

Set attributes directly on your buttons:

```lua
-- Button with hover, click, and active styles
button:SetAttribute("HoverStyle", "ScaleUp")
button:SetAttribute("ClickStyle", "Press")
button:SetAttribute("ActiveStyle", "Elevated")
```

### Target UI Styling

For styling external UI elements, use the `Target` ObjectValue and target-specific attributes:

```lua
-- Target UI element
local targetValue = Instance.new("ObjectValue")
targetValue.Name = "Target"
targetValue.Value = backgroundFrame
targetValue.Parent = button

-- Target styles
button:SetAttribute("TargetHoverStyle", "Glow")
button:SetAttribute("TargetClickStyle", "Flash")
button:SetAttribute("TargetActiveStyle", "Glowing")
```

### Custom Styles

You can also use custom style strings:

```lua
-- Custom hover style
button:SetAttribute("HoverStyle", "{ Size = UDim2.new(1.1, 0, 1.1, 0), BackgroundTransparency = 0.05 }")

-- Custom target style
button:SetAttribute("TargetHoverStyle", "{ Thickness = 3, Transparency = 0.2 }")
```

## Available Attributes

### Button Styles
- `HoverStyle` - Style applied on mouse hover
- `ClickStyle` - Style applied on mouse click
- `ActiveStyle` - Style applied when button's menu is active

### Target Styles
- `TargetHoverStyle` - Target UI style on button hover
- `TargetClickStyle` - Target UI style on button click
- `TargetActiveStyle` - Target UI style when button's menu is active

## Professional Presets

### Hover Presets

#### GuiObject Presets
- `ScaleUp` - Scales button to 105%
- `ScaleDown` - Scales button to 98%
- `Elevate` - Moves button up 2 pixels
- `Brighten` - Reduces background transparency
- `Pulse` - Subtle scale and transparency change
- `SlideUp` - Slides button up 1 pixel
- `Rotate` - Rotates button 2 degrees

#### UIStroke Presets
- `Glow` - Increases thickness and reduces transparency
- `Bright` - Reduces transparency
- `Thick` - Increases thickness

#### UIGradient Presets
- `Rotate` - Rotates gradient 15 degrees
- `Brighten` - Adjusts gradient offset

### Click Presets

#### GuiObject Presets
- `Press` - Quick scale down to 95%
- `DeepPress` - Scale down to 90% with position change
- `Squash` - Horizontal stretch effect
- `Flash` - Bright background flash
- `BounceDown` - Bounce down effect
- `QuickRotate` - Quick rotation with scale
- `Squeeze` - Vertical squeeze effect
- `Pop` - Scale up with transparency

#### UIStroke Presets
- `Press` - Reduces thickness
- `Flash` - Full opacity flash

#### UIGradient Presets
- `Flash` - Resets rotation

### Active Presets

#### GuiObject Presets
- `Elevated` - Permanently elevated position
- `Glowing` - Glowing border effect
- `PulseGlow` - Pulsing glow effect
- `Bright` - Bright background
- `Highlighted` - Subtle highlight
- `Selected` - Selected state appearance
- `ActiveGlow` - Active glow effect
- `Premium` - Premium active state

#### UIStroke Presets
- `Glowing` - Thick glowing border
- `Bright` - Bright border

#### UIGradient Presets
- `Active` - Rotated gradient
- `Premium` - Premium gradient effect

## Examples

### Basic Button Setup
```lua
local button = Instance.new("TextButton")
button.Name = "MyButton"

-- Set styles using attributes
button:SetAttribute("HoverStyle", "ScaleUp")
button:SetAttribute("ClickStyle", "Press")
button:SetAttribute("ActiveStyle", "Elevated")
```

### Button with Target Styling
```lua
local button = Instance.new("TextButton")
local backgroundFrame = Instance.new("Frame")

-- Target UI element
local targetValue = Instance.new("ObjectValue")
targetValue.Name = "Target"
targetValue.Value = backgroundFrame
targetValue.Parent = button

-- Button styles
button:SetAttribute("HoverStyle", "ScaleUp")
button:SetAttribute("ClickStyle", "Press")

-- Target styles
button:SetAttribute("TargetHoverStyle", "Glow")
button:SetAttribute("TargetClickStyle", "Flash")
button:SetAttribute("TargetActiveStyle", "Glowing")
```

### Mixed Configuration
```lua
-- Button scales on hover
button:SetAttribute("HoverStyle", "ScaleUp")

-- UIStroke glows on hover
button:SetAttribute("TargetHoverStyle", "Glow")

-- Custom click effect
button:SetAttribute("ClickStyle", "{ Size = UDim2.new(0.9, 0, 0.9, 0), Rotation = -3 }")
```

### Advanced Configuration
```lua
-- Multiple target elements
local button = Instance.new("TextButton")
local backgroundFrame = Instance.new("Frame")
local stroke = Instance.new("UIStroke")

-- Target the background
local targetValue = Instance.new("ObjectValue")
targetValue.Name = "Target"
targetValue.Value = backgroundFrame
targetValue.Parent = button

-- Button styles
button:SetAttribute("HoverStyle", "ScaleUp")
button:SetAttribute("ClickStyle", "Press")
button:SetAttribute("ActiveStyle", "Elevated")

-- Background styles
button:SetAttribute("TargetHoverStyle", "Brighten")
button:SetAttribute("TargetClickStyle", "Flash")

-- Stroke styles (would need separate target setup)
-- This would require a different approach for multiple targets
```

## Animation Behavior

### Hover Effects
- **Duration**: 0.2 seconds
- **Easing**: Quadratic Out
- **Trigger**: Mouse enter/leave
- **Restoration**: Automatic to original state

### Click Effects
- **Duration**: 0.1 seconds
- **Easing**: Quadratic Out
- **Trigger**: Mouse down/up
- **Restoration**: Automatic to original state

### Active Effects
- **Duration**: 0.3 seconds
- **Easing**: Quadratic Out
- **Trigger**: Menu open/close
- **Restoration**: Automatic when menu closes

## Integration with Menu System

The Attribute Style System automatically integrates with the MenuAnimator system:

1. **Active Effects**: Applied when associated menu is open
2. **Automatic Cleanup**: Styles are restored when menus close
3. **State Synchronization**: Active styles sync with menu states
4. **Performance Optimized**: Only applies effects when needed

## Best Practices

### 1. Use Appropriate Presets
- Choose presets that match your UI style
- Test different combinations for best results
- Consider the target UI element type

### 2. Performance Considerations
- Use simple effects for frequently used buttons
- Avoid complex effects on many buttons simultaneously
- Test performance on lower-end devices

### 3. Visual Consistency
- Use consistent effects across similar buttons
- Match hover and click effects thematically
- Ensure active states are clearly distinguishable

### 4. Code Organization
- Set attributes in a centralized location
- Use consistent naming conventions
- Document your style choices

## Migration from StringValues

### Before (StringValues)
```lua
-- Old way with StringValues
local hoverValue = Instance.new("StringValue")
hoverValue.Name = "HoverStyle"
hoverValue.Value = "scale_up"
hoverValue.Parent = button

local clickValue = Instance.new("StringValue")
clickValue.Name = "ClickStyle"
clickValue.Value = "press"
clickValue.Parent = button
```

### After (Attributes)
```lua
-- New way with attributes
button:SetAttribute("HoverStyle", "ScaleUp")
button:SetAttribute("ClickStyle", "Press")
```

### Benefits of Migration
- **Cleaner Code**: No need to create multiple StringValues
- **Better Performance**: Direct attribute access
- **Easier Maintenance**: All configuration in one place
- **Reduced Memory**: No extra objects in the tree

## Troubleshooting

### Styles Not Working
1. Check that the attribute names are correct
2. Verify the preset names use CamelCase
3. Ensure the button is a GuiButton
4. Check that the Target ObjectValue points to a valid UI element

### Performance Issues
1. Use lighter presets for better performance
2. Avoid applying effects to many buttons simultaneously
3. Check for memory leaks in long-running sessions

### Style Conflicts
1. Attribute styles work alongside StringValue styles
2. Active styles take precedence over hover/click
3. Original styles are always restored properly

## Advanced Usage

### Dynamic Style Changes
```lua
-- Change styles at runtime
button:SetAttribute("HoverStyle", "ScaleDown")
button:SetAttribute("ClickStyle", "Squash")
```

### Conditional Styles
```lua
-- Different styles based on conditions
if button:GetAttribute("IsSpecial") then
    button:SetAttribute("HoverStyle", "Premium")
else
    button:SetAttribute("HoverStyle", "ScaleUp")
end
```

### Style Validation
```lua
-- Check if button has styles configured
local hasHover = button:GetAttribute("HoverStyle")
local hasClick = button:GetAttribute("ClickStyle")
local hasActive = button:GetAttribute("ActiveStyle")

if hasHover or hasClick or hasActive then
    print("Button has styles configured")
end
```

---

*For more information, see the [Button Style Presets](ButtonStylePresets.md) documentation.*
