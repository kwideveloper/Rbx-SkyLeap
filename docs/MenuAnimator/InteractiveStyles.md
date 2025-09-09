# Interactive Styles System

The Interactive Styles system provides professional hover, click, and active state effects for buttons and UI elements. It includes pre-built presets and custom style support.

## Overview

Interactive Styles automatically detect button interactions and apply appropriate visual feedback. The system supports:

- **Hover Effects**: Applied when mouse enters/leaves button
- **Click Effects**: Applied when button is pressed/released
- **Active Effects**: Applied when button's associated menu is open

## Setup

### Basic Configuration

Set attributes on any button for interactive effects:

```lua
-- Hover effect (preset name)
button:SetAttribute("HoverStyle", "ScaleUp")

-- Click effect (preset name)
button:SetAttribute("ClickStyle", "Press")

-- Active effect (preset name)
button:SetAttribute("ActiveStyle", "Elevated")
```

### Helper Function

Use the global helper function for quick setup:

```lua
-- Quick setup using global helper
_G.StyleButton("ButtonName", "ScaleUp", "Press", "Elevated")
```

### Target UI Element

For effects on external UI elements, use ObjectValue:

```lua
-- Target external UI element
local targetValue = Instance.new("ObjectValue")
targetValue.Name = "Target"
targetValue.Value = backgroundFrame -- or UIStroke, UIGradient, etc.
targetValue.Parent = button
```

## Professional Presets

### Hover Presets

**For GuiObject:**
- `ScaleUp` - Scales button to 105%
- `ScaleDown` - Scales button to 98%
- `Elevate` - Moves button up 2 pixels
- `Brighten` - Reduces background transparency
- `Pulse` - Subtle scale and transparency change
- `SlideUp` - Slides button up 1 pixel
- `Rotate` - Rotates button 2 degrees

**For UIStroke:**
- `Glow` - Increases thickness and reduces transparency
- `Bright` - Reduces transparency
- `Thick` - Increases thickness

**For UIGradient:**
- `Rotate` - Rotates gradient 15 degrees
- `Brighten` - Adjusts gradient offset

### Click Presets

**For GuiObject:**
- `Press` - Quick scale down to 95%
- `DeepPress` - Scale down to 90% with position change
- `Squash` - Horizontal stretch effect
- `Flash` - Bright background flash
- `BounceDown` - Bounce down effect
- `QuickRotate` - Quick rotation with scale
- `Squeeze` - Vertical squeeze effect
- `Pop` - Scale up with transparency

**For UIStroke:**
- `Press` - Reduces thickness
- `Flash` - Full opacity flash

**For UIGradient:**
- `Flash` - Resets rotation

### Active Presets

**For GuiObject:**
- `Elevated` - Permanently elevated position
- `Glowing` - Glowing border effect
- `PulseGlow` - Pulsing glow effect
- `Bright` - Bright background
- `Highlighted` - Subtle highlight
- `Selected` - Selected state appearance
- `ActiveGlow` - Active glow effect
- `Premium` - Premium active state

**For UIStroke:**
- `Glowing` - Thick glowing border
- `Bright` - Bright border

**For UIGradient:**
- `Active` - Rotated gradient
- `Premium` - Premium gradient effect

## Custom Styles

You can also use custom style strings instead of preset names:

```lua
-- Custom hover style
local hoverValue = Instance.new("StringValue")
hoverValue.Name = "HoverStyle"
hoverValue.Value = "{ Size = UDim2.new(1.1, 0, 1.1, 0), BackgroundTransparency = 0.05 }"
hoverValue.Parent = button

-- Custom click style
local clickValue = Instance.new("StringValue")
clickValue.Name = "ClickStyle"
hoverValue.Value = "{ Size = UDim2.new(0.9, 0, 0.9, 0), Rotation = -3 }"
clickValue.Parent = button
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

## Examples

### Professional Button Setup
```lua
local button = Instance.new("TextButton")
button.Name = "ProfessionalButton"

-- Target UI element
local targetValue = Instance.new("ObjectValue")
targetValue.Name = "Target"
targetValue.Value = button -- Self-targeting
targetValue.Parent = button

-- Hover effect
local hoverValue = Instance.new("StringValue")
hoverValue.Name = "HoverStyle"
button:SetAttribute("HoverStyle", "ScaleUp")
hoverValue.Parent = button

-- Click effect
local clickValue = Instance.new("StringValue")
clickValue.Name = "ClickStyle"
button:SetAttribute("ClickStyle", "Press")
clickValue.Parent = button

-- Active effect
local activeValue = Instance.new("StringValue")
activeValue.Name = "ActiveStyle"
button:SetAttribute("ActiveStyle", "Elevated")
activeValue.Parent = button
```

### UIStroke Effects
```lua
-- Target the UIStroke
local targetValue = Instance.new("ObjectValue")
targetValue.Name = "Target"
targetValue.Value = button.UIStroke
targetValue.Parent = button

-- Glow on hover
local hoverValue = Instance.new("StringValue")
hoverValue.Name = "HoverStyle"
hoverValue.Value = "glow"
hoverValue.Parent = button

-- Flash on click
local clickValue = Instance.new("StringValue")
clickValue.Name = "ClickStyle"
clickValue.Value = "flash"
clickValue.Parent = button
```

### Mixed Effects
```lua
-- Button scales on hover
local buttonHover = Instance.new("StringValue")
buttonHover.Name = "HoverStyle"
buttonHover.Value = "scale_up"
buttonHover.Parent = button

-- UIStroke glows on hover
local strokeTarget = Instance.new("ObjectValue")
strokeTarget.Name = "Target"
strokeTarget.Value = button.UIStroke
strokeTarget.Parent = button

local strokeHover = Instance.new("StringValue")
strokeHover.Name = "HoverStyle"
strokeHover.Value = "glow"
strokeHover.Parent = button
```

## Integration with Menu System

Interactive Styles automatically integrate with the MenuAnimator system:

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

### 4. Accessibility
- Ensure effects don't interfere with usability
- Provide clear visual feedback
- Test with different UI scales

## Troubleshooting

### Effects Not Working
1. Check that the button has the correct StringValue names
2. Verify the Target ObjectValue points to a valid UI element
3. Ensure the button is a GuiButton (TextButton, ImageButton, etc.)

### Performance Issues
1. Reduce the number of simultaneous effects
2. Use simpler presets for better performance
3. Check for memory leaks in long-running sessions

### Style Conflicts
1. Interactive styles work alongside custom styles
2. Active styles take precedence over hover/click
3. Original styles are always restored properly

## Advanced Usage

### Custom Animation Durations
```lua
-- Custom style with specific duration
local customStyle = "{ Size = UDim2.new(1.1, 0, 1.1, 0), Duration = 0.5 }"
```

### Conditional Effects
```lua
-- Different effects based on button state
if button:GetAttribute("IsSpecial") then
    hoverValue.Value = "premium"
else
    button:SetAttribute("HoverStyle", "ScaleUp")
end
```

### Dynamic Target Switching
```lua
-- Change target based on conditions
if someCondition then
    targetValue.Value = button.UIStroke
else
    targetValue.Value = button
end
```

---

*For more information, see the [Button Style Presets](ButtonStylePresets.md) documentation.*
