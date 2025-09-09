# StyleManager System

The StyleManager system allows buttons to dynamically modify the visual style of specific UI elements when their associated menu is open. This provides a powerful way to create contextual UI changes and visual feedback.

## Overview

When a button with an "Open" ObjectValue has its menu visible, the StyleManager can apply custom styles to **any Roblox Instance** specified by a "Target" ObjectValue. This includes GuiObjects, UIComponents (UIStroke, UIGradient, etc.), and any other Instance with modifiable properties. The styles are defined in a "Style" StringValue using Lua table syntax.

## Setup

### Button Configuration

To enable custom styling, a button needs three specific children:

1. **ObjectValue "Open"** - Points to the menu that controls the button's active state
2. **ObjectValue "Target"** - Points to the UI element that will receive the custom style
3. **StringValue "Style"** - Contains the style properties in Lua table format

```lua
-- Example button setup
local button = Instance.new("TextButton")
button.Name = "MenuButton"

-- Menu reference
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetMenu
openValue.Parent = button

-- Target UI element
local targetValue = Instance.new("ObjectValue")
targetValue.Name = "Target"
targetValue.Value = backgroundFrame
targetValue.Parent = button

-- Style configuration
local styleValue = Instance.new("StringValue")
styleValue.Name = "Style"
styleValue.Value = "{ BackgroundColor3 = Color3.fromRGB(100, 200, 255), BackgroundTransparency = 0.1, TextColor3 = Color3.fromRGB(255, 255, 255) }"
styleValue.Parent = button
```

## Style Properties

The StyleManager supports **any property** that exists on the target Instance. It dynamically detects and applies properties, making it compatible with:

### GuiObject Properties

**Color Properties**
- `BackgroundColor3` - Background color
- `TextColor3` - Text color
- `BorderColor3` - Border color
- `TextStrokeColor3` - Text stroke color
- `ImageColor3` - Image color (for ImageLabel/ImageButton)

### Transparency Properties
- `BackgroundTransparency` - Background transparency
- `TextTransparency` - Text transparency
- `TextStrokeTransparency` - Text stroke transparency
- `ImageTransparency` - Image transparency
- `Transparency` - General transparency

### Size and Position
- `Size` - UI element size
- `Position` - UI element position
- `AnchorPoint` - UI element anchor point
- `Rotation` - UI element rotation

### Text Properties
- `TextSize` - Text size
- `Font` - Text font
- `TextStrokeTransparency` - Text stroke transparency

### Image Properties
- `ScaleType` - Image scale type
- `SliceCenter` - Image slice center
- `SliceScale` - Image slice scale
- `TileSize` - Image tile size

**Other Properties**
- `BorderSizePixel` - Border size
- `ZIndex` - Z-index layering
- `Visible` - Visibility

### UIComponent Properties

**UIStroke Properties**
- `Color` - Stroke color
- `Thickness` - Stroke thickness
- `Transparency` - Stroke transparency
- `Enabled` - Stroke enabled state
- `ApplyStrokeMode` - How stroke is applied

**UIGradient Properties**
- `ColorSequence` - Color sequence
- `TransparencySequence` - Transparency sequence
- `Offset` - Gradient offset
- `Rotation` - Gradient rotation
- `Enabled` - Gradient enabled state

**UICorner Properties**
- `CornerRadius` - Corner radius

**UIPadding Properties**
- `PaddingBottom` - Bottom padding
- `PaddingLeft` - Left padding
- `PaddingRight` - Right padding
- `PaddingTop` - Top padding

**UIAspectRatioConstraint Properties**
- `AspectRatio` - Aspect ratio value
- `AspectType` - Aspect ratio type
- `DominantAxis` - Dominant axis

**UISizeConstraint Properties**
- `MaxSize` - Maximum size
- `MinSize` - Minimum size

### Custom Properties

The system is **completely flexible** and can handle any property that exists on the target Instance. If a property doesn't exist, it's silently skipped. If a property is read-only, it's also silently skipped. This allows for maximum compatibility across different object types.

### Property Compatibility Guide

**For UIStroke (UIComponent):**
- ✅ `Color` - Stroke color
- ✅ `Thickness` - Stroke thickness  
- ✅ `Transparency` - Stroke transparency
- ✅ `Enabled` - Stroke enabled state
- ❌ `BackgroundColor3` - Not available (use `Color` instead)
- ❌ `Size` - Not available
- ❌ `Position` - Not available

**For GuiObject (Frame, TextButton, etc.):**
- ✅ `BackgroundColor3` - Background color
- ✅ `BackgroundTransparency` - Background transparency
- ✅ `Size` - UI size
- ✅ `Position` - UI position
- ✅ `TextColor3` - Text color (for text elements)
- ❌ `Color` - Not available (use `BackgroundColor3` instead)
- ❌ `Thickness` - Not available

**For UIGradient (UIComponent):**
- ✅ `ColorSequence` - Color sequence
- ✅ `TransparencySequence` - Transparency sequence
- ✅ `Offset` - Gradient offset
- ✅ `Rotation` - Gradient rotation
- ✅ `Enabled` - Gradient enabled state
- ❌ `BackgroundColor3` - Not available
- ❌ `Size` - Not available

## Style String Format

The style string uses a simplified Lua table syntax that's parsed by the StyleManager:

### Supported Value Types

**Boolean Values** (no quotes needed):
```lua
"{ Enabled = true, Visible = false }"
```

**String Values** (quotes required):
```lua
"{ Text = 'Hello World', Font = 'GothamBold' }"
```

**Number Values** (no quotes needed):
```lua
"{ Thickness = 2, Transparency = 0.5, TextSize = 18 }"
```

**Color3 Values** (simplified format):
```lua
"{ BackgroundColor3 = Color3.fromRGB(255, 0, 0) }"
```

### Examples

```lua
-- Basic example
"{ BackgroundColor3 = Color3.fromRGB(255, 0, 0), BackgroundTransparency = 0.2 }"

-- UIStroke example
"{ Enabled = true, Color = Color3.fromRGB(255, 255, 0), Thickness = 3 }"

-- Mixed types example
"{ 
    BackgroundColor3 = Color3.fromRGB(100, 200, 255), 
    BackgroundTransparency = 0.1, 
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 18,
    Thickness = 2,
    Enabled = true
}"
```

### Important Notes

- **Booleans**: Use `true` or `false` without quotes
- **Strings**: Use single or double quotes around text values
- **Numbers**: No quotes needed for numeric values
- **Complex Objects**: Color3, UDim2, Vector2, and Enum values are supported but may need specific formatting
- **Whitespace**: Spaces around `=` and `,` are optional but recommended for readability

## Animation Behavior

### Smooth Transitions
Properties that support smooth transitions are automatically animated:
- `BackgroundTransparency`
- `TextTransparency`
- `ImageTransparency`
- `Transparency`

These properties use a 0.3-second quadratic easing transition.

### Immediate Changes
Other properties are applied immediately for instant visual feedback.

## Usage Examples

### Example 1: Highlight Background
```lua
-- When menu is open, highlight the background
local styleValue = Instance.new("StringValue")
styleValue.Name = "Style"
styleValue.Value = "{ BackgroundColor3 = Color3.fromRGB(50, 150, 255), BackgroundTransparency = 0.2 }"
styleValue.Parent = button
```

### Example 2: Change Text Appearance
```lua
-- When menu is open, change text style
local styleValue = Instance.new("StringValue")
styleValue.Name = "Style"
styleValue.Value = "{ TextColor3 = Color3.fromRGB(255, 255, 0), TextSize = 20, Font = Enum.Font.GothamBold }"
styleValue.Parent = button
```

### Example 3: Resize and Reposition
```lua
-- When menu is open, resize and move the element
local styleValue = Instance.new("StringValue")
styleValue.Name = "Style"
styleValue.Value = "{ Size = UDim2.new(0, 300, 0, 100), Position = UDim2.new(0, 50, 0, 50) }"
styleValue.Parent = button
```

### Example 4: UIStroke Styling
```lua
-- When menu is open, modify UIStroke properties
-- NOTE: UIStroke doesn't have BackgroundColor3, use Color instead
local styleValue = Instance.new("StringValue")
styleValue.Name = "Style"
styleValue.Value = "{ 
    Color = Color3.fromRGB(255, 255, 0), 
    Thickness = 3, 
    Transparency = 0.2,
    Enabled = true
}"
styleValue.Parent = button
```

### Example 5: UIGradient Styling
```lua
-- When menu is open, modify UIGradient properties
local styleValue = Instance.new("StringValue")
styleValue.Name = "Style"
styleValue.Value = "{ 
    ColorSequence = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 255))
    }),
    Rotation = 45,
    Enabled = true
}"
styleValue.Parent = button
```

### Example 6: UICorner Styling
```lua
-- When menu is open, modify UICorner properties
local styleValue = Instance.new("StringValue")
styleValue.Name = "Style"
styleValue.Value = "{ 
    CornerRadius = UDim.new(0, 20)
}"
styleValue.Parent = button
```

### Example 7: Complex Multi-Component Styling
```lua
-- When menu is open, apply multiple style changes across different components
local styleValue = Instance.new("StringValue")
styleValue.Name = "Style"
styleValue.Value = "{ 
    BackgroundColor3 = Color3.fromRGB(255, 100, 100), 
    BackgroundTransparency = 0.1, 
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 16,
    Font = Enum.Font.Gotham,
    BorderSizePixel = 2,
    BorderColor3 = Color3.fromRGB(255, 255, 255),
    ZIndex = 10
}"
styleValue.Parent = button
```

## Integration with MenuAnimator

The StyleManager automatically integrates with the MenuAnimator system:

1. **Automatic Detection**: When a button has both "Open" and "Target" ObjectValues, the system automatically monitors the menu state
2. **State Synchronization**: Styles are applied when the menu becomes visible and removed when it becomes hidden
3. **Cleanup**: All styles are properly cleaned up when the system shuts down

## Best Practices

### 1. Use Smooth Transitions
Prefer properties that support smooth transitions for better user experience:
```lua
-- Good: Smooth transition
"{ BackgroundTransparency = 0.2 }"

-- Less ideal: Immediate change
"{ Size = UDim2.new(0, 200, 0, 50) }"
```

### 2. Keep Styles Simple
Avoid overly complex style changes that might confuse users:
```lua
-- Good: Clear visual change
"{ BackgroundColor3 = Color3.fromRGB(100, 200, 255) }"

-- Avoid: Too many changes at once
"{ BackgroundColor3 = Color3.fromRGB(100, 200, 255), TextColor3 = Color3.fromRGB(255, 0, 0), Size = UDim2.new(0, 200, 0, 50), Position = UDim2.new(0, 10, 0, 10), Rotation = 5 }"
```

### 3. Test Different States
Ensure styles work well in both active and inactive states:
- Test with menus opening and closing
- Verify styles are properly restored
- Check for any visual glitches

### 4. Use Appropriate Colors
Choose colors that provide good contrast and visual feedback:
```lua
-- Good: High contrast
"{ BackgroundColor3 = Color3.fromRGB(50, 150, 255), TextColor3 = Color3.fromRGB(255, 255, 255) }"

-- Avoid: Low contrast
"{ BackgroundColor3 = Color3.fromRGB(100, 100, 100), TextColor3 = Color3.fromRGB(110, 110, 110) }"
```

## Troubleshooting

### Common Issues

1. **Style Not Applied**
   - Check that the "Target" ObjectValue points to a valid GuiObject
   - Verify the "Style" StringValue contains valid Lua table syntax
   - Ensure the menu is actually open/visible

2. **Style Not Removed**
   - Check that the menu is properly closed
   - Verify the button's "Open" ObjectValue is correctly configured

3. **Invalid Style String**
   - Use proper Lua table syntax
   - Ensure all property names are correct
   - Check that property values are valid for the target UI element

### Debug Information

The StyleManager provides debug functions:
```lua
-- Get current style states
local styleStates = StyleManager.getStyleStates()

-- Get active style buttons
local activeButtons = StyleManager.getActiveStyleButtons()
```

## Performance Considerations

- Styles are only applied when menus are actually open
- Original styles are cached to avoid repeated property access
- Smooth transitions are optimized for performance
- Automatic cleanup prevents memory leaks
- Only one style can be applied per target UI element at a time

## Future Enhancements

Potential future improvements:
- Support for custom easing styles
- Animation duration configuration
- Style inheritance and cascading
- Conditional style application
- Style presets and templates
