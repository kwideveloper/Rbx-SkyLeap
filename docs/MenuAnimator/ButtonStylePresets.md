# Button Style Presets

Professional style presets for hover, click, and active button states. These presets provide ready-to-use visual effects that can be applied to any button or UI element.

## Overview

Button Style Presets are pre-configured style combinations that provide professional visual feedback for user interactions. They are optimized for performance and visual appeal.

## Preset Categories

### Hover Presets
Applied when the mouse enters or leaves a button.

### Click Presets
Applied when a button is pressed or released.

### Active Presets
Applied when a button's associated menu is open.

## Hover Effects

### GuiObject Hover Effects

#### `ScaleUp`
**Effect**: Scales button to 105% of original size
**Use Case**: Subtle emphasis on hover
**Properties**:
- `Size = UDim2.new(1.05, 0, 1.05, 0)`
- `ZIndex = 5`

#### `ScaleDown`
**Effect**: Scales button to 98% of original size
**Use Case**: Subtle shrink effect
**Properties**:
- `Size = UDim2.new(0.98, 0, 0.98, 0)`
- `ZIndex = 5`

#### `Elevate`
**Effect**: Moves button up 2 pixels
**Use Case**: Floating effect
**Properties**:
- `Position = UDim2.new(0, 0, 0, -2)`
- `ZIndex = 5`

#### `Brighten`
**Effect**: Reduces background transparency
**Use Case**: Highlight effect
**Properties**:
- `BackgroundTransparency = 0.1`
- `ZIndex = 5`

#### `Pulse`
**Effect**: Subtle scale and transparency change
**Use Case**: Attention-grabbing effect
**Properties**:
- `Size = UDim2.new(1.02, 0, 1.02, 0)`
- `BackgroundTransparency = 0.05`
- `ZIndex = 5`

#### `SlideUp`
**Effect**: Slides button up 1 pixel
**Use Case**: Smooth movement
**Properties**:
- `Position = UDim2.new(0, 0, 0, -1)`
- `ZIndex = 5`

#### `Rotate`
**Effect**: Rotates button 2 degrees
**Use Case**: Playful interaction
**Properties**:
- `Rotation = 2`
- `ZIndex = 5`

### UIStroke Hover Effects

#### `Glow`
**Effect**: Increases thickness and reduces transparency
**Use Case**: Glowing border on hover
**Properties**:
- `Thickness = 3`
- `Transparency = 0.3`
- `Enabled = true`

#### `Bright`
**Effect**: Reduces transparency
**Use Case**: Brighter border on hover
**Properties**:
- `Transparency = 0.1`
- `Enabled = true`

#### `Thick`
**Effect**: Increases thickness
**Use Case**: Thicker border on hover
**Properties**:
- `Thickness = 4`
- `Enabled = true`

### UIGradient Hover Effects

#### `Rotate`
**Effect**: Rotates gradient 15 degrees
**Use Case**: Dynamic gradient on hover
**Properties**:
- `Rotation = 15`
- `Enabled = true`

#### `Brighten`
**Effect**: Adjusts gradient offset
**Use Case**: Brighter gradient on hover
**Properties**:
- `Offset = Vector2.new(0, 0.3)`
- `Enabled = true`

## Click Effects

### GuiObject Click Effects

#### `Press`
**Effect**: Quick scale down to 95%
**Use Case**: Standard button press
**Properties**:
- `Size = UDim2.new(0.95, 0, 0.95, 0)`
- `ZIndex = 10`

#### `DeepPress`
**Effect**: Scale down to 90% with position change
**Use Case**: Strong press feedback
**Properties**:
- `Size = UDim2.new(0.9, 0, 0.9, 0)`
- `Position = UDim2.new(0, 0, 0, 2)`
- `ZIndex = 10`

#### `Squash`
**Effect**: Horizontal stretch effect
**Use Case**: Squash animation
**Properties**:
- `Size = UDim2.new(1.1, 0, 0.9, 0)`
- `ZIndex = 10`

#### `Flash`
**Effect**: Bright background flash
**Use Case**: Attention-grabbing click
**Properties**:
- `BackgroundTransparency = 0`
- `ZIndex = 10`

#### `BounceDown`
**Effect**: Bounce down effect
**Use Case**: Bouncy interaction
**Properties**:
- `Position = UDim2.new(0, 0, 0, 3)`
- `Size = UDim2.new(0.98, 0, 0.98, 0)`
- `ZIndex = 10`

#### `QuickRotate`
**Effect**: Quick rotation with scale
**Use Case**: Dynamic click feedback
**Properties**:
- `Rotation = -5`
- `Size = UDim2.new(0.97, 0, 0.97, 0)`
- `ZIndex = 10`

#### `Squeeze`
**Effect**: Vertical squeeze effect
**Use Case**: Squeeze animation
**Properties**:
- `Size = UDim2.new(0.85, 0, 1.05, 0)`
- `ZIndex = 10`

#### `Pop`
**Effect**: Scale up with transparency
**Use Case**: Pop effect
**Properties**:
- `Size = UDim2.new(1.08, 0, 1.08, 0)`
- `BackgroundTransparency = 0.02`
- `ZIndex = 10`

### UIStroke Click Effects

#### `Press`
**Effect**: Reduces thickness
**Use Case**: Pressed border effect
**Properties**:
- `Thickness = 2`
- `Enabled = true`

#### `Flash`
**Effect**: Full opacity flash
**Use Case**: Bright flash on click
**Properties**:
- `Transparency = 0`
- `Enabled = true`

### UIGradient Click Effects

#### `Flash`
**Effect**: Resets rotation
**Use Case**: Gradient reset on click
**Properties**:
- `Rotation = 0`
- `Enabled = true`

## Active Effects

### GuiObject Active Effects

#### `Elevated`
**Effect**: Permanently elevated position
**Use Case**: Active button state
**Properties**:
- `Position = UDim2.new(0, 0, 0, -3)`
- `ZIndex = 15`

#### `Glowing`
**Effect**: Glowing border effect
**Use Case**: Active with border
**Properties**:
- `Thickness = 4`
- `Transparency = 0.1`
- `ZIndex = 15`

#### `PulseGlow`
**Effect**: Pulsing glow effect
**Use Case**: Animated active state
**Properties**:
- `Thickness = 3`
- `Transparency = 0.2`
- `ZIndex = 15`

#### `Bright`
**Effect**: Bright background
**Use Case**: Clear active indication
**Properties**:
- `BackgroundTransparency = 0`
- `ZIndex = 15`

#### `Highlighted`
**Effect**: Subtle highlight
**Use Case**: Subtle active state
**Properties**:
- `BackgroundTransparency = 0.05`
- `ZIndex = 15`

#### `Selected`
**Effect**: Selected state appearance
**Use Case**: Selection indication
**Properties**:
- `Size = UDim2.new(1.02, 0, 1.02, 0)`
- `Position = UDim2.new(0, 0, 0, -1)`
- `ZIndex = 15`

#### `ActiveGlow`
**Effect**: Active glow effect
**Use Case**: Strong active indication
**Properties**:
- `Thickness = 5`
- `Transparency = 0.05`
- `ZIndex = 15`

#### `Premium`
**Effect**: Premium active state
**Use Case**: Premium features
**Properties**:
- `Size = UDim2.new(1.03, 0, 1.03, 0)`
- `Position = UDim2.new(0, 0, 0, -2)`
- `BackgroundTransparency = 0.02`
- `ZIndex = 15`

### UIStroke Active Effects

#### `Glowing`
**Effect**: Thick glowing border
**Use Case**: Active border indication
**Properties**:
- `Thickness = 5`
- `Transparency = 0.1`
- `Enabled = true`

#### `Bright`
**Effect**: Bright border
**Use Case**: Clear active border
**Properties**:
- `Transparency = 0.05`
- `Enabled = true`

### UIGradient Active Effects

#### `Active`
**Effect**: Rotated gradient
**Use Case**: Active gradient state
**Properties**:
- `Rotation = 45`
- `Enabled = true`

#### `Premium`
**Effect**: Premium gradient effect
**Use Case**: Premium active gradient
**Properties**:
- `Offset = Vector2.new(0, 0.5)`
- `Enabled = true`

## Usage Examples

### Basic Button Setup
```lua
-- Hover effect
local hoverValue = Instance.new("StringValue")
hoverValue.Name = "HoverStyle"
hoverValue.Value = "ScaleUp"
hoverValue.Parent = button

-- Click effect
local clickValue = Instance.new("StringValue")
clickValue.Name = "ClickStyle"
clickValue.Value = "Press"
clickValue.Parent = button
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
hoverValue.Value = "Glow"
hoverValue.Parent = button
```

### Mixed Effects
```lua
-- Button scales on hover
local buttonHover = Instance.new("StringValue")
buttonHover.Name = "HoverStyle"
buttonHover.Value = "ScaleUp"
buttonHover.Parent = button

-- UIStroke glows on hover
local strokeTarget = Instance.new("ObjectValue")
strokeTarget.Name = "Target"
strokeTarget.Value = button.UIStroke
strokeTarget.Parent = button

local strokeHover = Instance.new("StringValue")
strokeHover.Name = "HoverStyle"
strokeHover.Value = "Glow"
strokeHover.Parent = button
```

## Customization

### Creating Custom Presets
```lua
-- Add custom preset to ButtonStylePresets.lua
ButtonStylePresets.Hover.custom_effect = {
    Size = "UDim2.new(1.1, 0, 1.1, 0)",
    Rotation = 5,
    BackgroundTransparency = 0.05,
    ZIndex = 5
}
```

### Modifying Existing Presets
```lua
-- Override existing preset
ButtonStylePresets.Hover.scale_up = {
    Size = "UDim2.new(1.2, 0, 1.2, 0)", -- Increased scale
    ZIndex = 5
}
```

## Performance Considerations

### Lightweight Presets
- `scale_up` - Minimal performance impact
- `brighten` - Very lightweight
- `slide_up` - Efficient position change

### Moderate Presets
- `pulse` - Multiple property changes
- `rotate` - Rotation calculation
- `elevate` - Position and ZIndex changes

### Heavy Presets
- `premium` - Multiple complex changes
- `pulse_glow` - Continuous animation
- `active_glow` - Thick border rendering

## Best Practices

### 1. Choose Appropriate Presets
- Use simple presets for frequently used buttons
- Reserve complex presets for special interactions
- Match preset complexity to UI importance

### 2. Performance Optimization
- Avoid using heavy presets on many buttons
- Test performance on lower-end devices
- Consider using custom lightweight presets

### 3. Visual Consistency
- Use consistent presets across similar buttons
- Create a preset style guide for your project
- Test presets in different UI contexts

### 4. Accessibility
- Ensure presets don't interfere with usability
- Provide clear visual feedback
- Test with different UI scales

## Troubleshooting

### Preset Not Working
1. Check that the preset name is correct
2. Verify the target UI element type is supported
3. Ensure the button has the correct StringValue setup

### Performance Issues
1. Switch to lighter presets
2. Reduce the number of simultaneous effects
3. Check for memory leaks

### Visual Issues
1. Test presets with your UI design
2. Adjust preset values if needed
3. Consider custom presets for specific needs

---

*For more information, see the [Interactive Styles](InteractiveStyles.md) documentation.*
