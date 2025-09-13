# MenuAnimator System Documentation

## Overview

The MenuAnimator system is a comprehensive UI animation and menu management system for Roblox that provides automatic menu opening/closing animations, button state management, and real-time menu monitoring. It supports both manual menu control and automatic detection of open menus.

## Features

- **Automatic Menu Detection**: Detects when menus are already open and activates corresponding buttons
- **Real-time Monitoring**: Monitors menu state changes and updates button states automatically
- **Dual Animation Systems**: Supports both MenuButton-tagged elements and general button animations
- **Gradient Animations**: Provides animated gradients for active button states
- **Toggle Support**: Respects Toggle BoolValue settings for menu behavior
- **Multiple Animation Types**: Supports various animation presets for menu transitions
- **Interactive Style System**: Professional hover, click, and active effects using attributes or StringValues
- **Button Style Presets**: Ready-to-use style configurations for different button interactions
- **Smooth Animations**: TweenService-powered transitions for fluid UI interactions
- **Target Style Support**: Apply styles to external UI elements when menus are active

## System Architecture

### Core Components

1. **MenuAnimator.client.lua** - Main system coordinator
2. **MenuManager.lua** - Menu state management
3. **ButtonAnimations.lua** - MenuButton-tagged element animations
4. **GeneralButtonAnimations.lua** - General button animations
5. **MenuAnimations.lua** - Menu opening animations
6. **MenuAnimationsOut.lua** - Menu closing animations

### Style System Components

1. **AttributeStyleManager.lua** - Modern attribute-based style management
2. **ButtonStylePresets.lua** - Professional style preset definitions
3. **StyleManager.lua** - Target UI element styling system

## Setup Requirements

### For Menu Buttons

To create a button that opens/closes menus, add these children to your button:

#### Required Children:
- **ObjectValue** named `"Open"` - Points to the menu to open/close
- **StringValue** named `"Animate"` with value `"Active"` or `"All"`

#### Optional Children:
- **BoolValue** named `"Toggle"` - If `false`, prevents closing when menu is open
- **StringValue** named `"Position"` - Animation direction (default: "Top")
- **StringValue** named `"Animation"` - Custom animation preset

#### Interactive Style Attributes:
- **Attribute** `"HoverStyle"` - Preset name for hover effect (e.g., "ScaleUp")
- **Attribute** `"ClickStyle"` - Preset name for click effect (e.g., "Press")
- **Attribute** `"ActiveStyle"` - Preset name for active state (e.g., "Elevated")

#### Target Style Children:
- **ObjectValue** named `"Target"` - Points to external UI element to style
- **StringValue** named `"Style"` - Custom style properties in Lua table format

### For Close Buttons

To create a button that closes specific menus:

#### Required Children:
- **ObjectValue** named `"Close"` - Points to the menu to close

#### Optional Children:
- **StringValue** named `"AnimateOut"` - Custom close animation preset

## Button Types

### 1. MenuButton Tagged Elements

Buttons with the `"MenuButton"` CollectionService tag use the advanced animation system:

**Features:**
- Gradient animations on active state
- Icon gradient effects
- UIStroke gradient rotation
- Enhanced visual feedback

**Setup:**
```lua
-- Add CollectionService tag
CollectionService:AddTag(button, "MenuButton")

-- Add required children
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetMenu
openValue.Parent = button

local animateValue = Instance.new("StringValue")
animateValue.Name = "Animate"
animateValue.Value = "Active" -- or "All"
animateValue.Parent = button
```

### 2. General Buttons

Buttons without the `"MenuButton"` tag use the general animation system:

**Features:**
- Frame position animations
- Basic hover effects
- Click animations
- Active state management
- Interactive style system support
- Target style system support

**Setup:**
```lua
-- Add required children (same as MenuButton)
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetMenu
openValue.Parent = button

local animateValue = Instance.new("StringValue")
animateValue.Name = "Animate"
animateValue.Value = "Active" -- or "All"
animateValue.Parent = button

-- Add interactive styles (modern approach)
button:SetAttribute("HoverStyle", "ScaleUp")
button:SetAttribute("ClickStyle", "Press")
button:SetAttribute("ActiveStyle", "Elevated")

-- Or using helper function
_G.StyleButton("ButtonName", "ScaleUp", "Press", "Elevated")
```

## Animation System

### Menu Opening Animations

The system supports various animation presets for menu opening:

**Available Presets:**
- `slide_up` - Menu slides up from bottom
- `slide_down` - Menu slides down from top
- `slide_left` - Menu slides in from right
- `slide_right` - Menu slides in from left
- `fade_in` - Menu fades in
- `scale_in` - Menu scales in from center
- `bounce_in` - Menu bounces in
- `elastic_in` - Menu uses elastic animation

**Custom Animation:**
```lua
-- Add to menu
local animationValue = Instance.new("StringValue")
animationValue.Name = "Animation"
animationValue.Value = "slide_up"
animationValue.Parent = menu
```

### Menu Closing Animations

The system provides extensive animation options for menu closing:

#### Slide Animations
- `slide_top` - Menu slides up and disappears
- `slide_bottom` - Menu slides down and disappears (default)
- `slide_left` - Menu slides left and disappears
- `slide_right` - Menu slides right and disappears

#### Fade Animations
- `fade` - Menu fades out in place
- `fade_scale` - Menu fades out while scaling down

#### Scale Animations
- `scale_up` - Menu scales up and fades out
- `scale_down` - Menu scales down and fades out

#### Special Animations
- `bounce` - Menu bounces down and disappears
- `elastic` - Menu slides down with elastic effect

#### No Animation
- `none` - Menu disappears immediately without animation

**Custom Close Animation:**
```lua
-- Add to close button
local animateOutValue = Instance.new("StringValue")
animateOutValue.Name = "AnimateOut"
animateOutValue.Value = "slide_left" -- or any other preset
animateOutValue.Parent = closeButton
```

**Default Behavior:**
- If no "AnimateOut" StringValue is found, uses `slide_bottom` animation
- If "AnimateOut" is set to "none", menu disappears immediately
- All animations respect the menu's original position and restore it after completion

## Interactive Style System

The MenuAnimator system includes a powerful interactive style system that provides professional hover, click, and active effects for buttons.

### Style Setup

```lua
-- Using button attributes (recommended)
button:SetAttribute("HoverStyle", "ScaleUp")
button:SetAttribute("ClickStyle", "Press")
button:SetAttribute("ActiveStyle", "Elevated")
```

#### Helper Function
```lua
-- Quick setup using global helper
_G.StyleButton("ButtonName", "ScaleUp", "Press", "Elevated")
```

### Available Style Presets

#### Hover Effects
- `ScaleUp` - Scales button to 105%
- `ScaleDown` - Scales button to 98%
- `Elevate` - Moves button up 2 pixels
- `Brighten` - Reduces background transparency
- `Glow` - Increases thickness (for UIStroke)
- `Pulse` - Subtle scale and transparency change
- `SlideUp` - Slides button up 1 pixel
- `Rotate` - Rotates button 2 degrees

#### Click Effects
- `Press` - Quick scale down to 95%
- `DeepPress` - Scale down to 90% with position change
- `Squash` - Horizontal stretch effect
- `Flash` - Bright background flash
- `BounceDown` - Bounce down effect
- `QuickRotate` - Quick rotation with scale
- `Squeeze` - Vertical squeeze effect
- `Pop` - Scale up with transparency

#### Active Effects
- `Elevated` - Permanently elevated position
- `Glowing` - Glowing border effect
- `PulseGlow` - Pulsing glow effect
- `Bright` - Bright background
- `Highlighted` - Subtle highlight
- `Selected` - Selected state appearance
- `ActiveGlow` - Active glow effect
- `Premium` - Premium active state

### Animation Behavior

- **Smooth Transitions**: Properties like `Size`, `Position`, `Transparency` animate smoothly (0.2s default)
- **Immediate Changes**: Properties like `ZIndex` apply instantly
- **Automatic Cleanup**: Styles are restored when interactions end
- **Performance Optimized**: Only tweenable properties are animated

## Menu Detection System

### Automatic Detection

The system automatically detects when menus are open and activates corresponding buttons:

**Detection Methods:**
- **CanvasGroup**: Checks `GroupTransparency < 1` and `Visible = true`
- **Regular UI**: Checks `Visible = true` and valid size

**Supported Menu Types:**
- CanvasGroup elements
- Frame elements
- Any GuiObject with proper visibility

### Real-time Monitoring

The system monitors menu state changes in real-time:

**Monitored Properties:**
- `GroupTransparency` (for CanvasGroup)
- `Visible` (for all UI elements)
- `Size` (for regular UI elements)

**Automatic Updates:**
- Button states update when menu visibility changes
- Gradient animations start/stop based on menu state
- Visual feedback remains synchronized

## Configuration

### Animation Settings

Customize animation behavior through menu attributes:

```lua
-- Animation duration (seconds)
menu:SetAttribute("AnimationDuration", 0.5)

-- Easing style
menu:SetAttribute("AnimationEasing", "Quad")

-- Easing direction
menu:SetAttribute("AnimationEasingDirection", "Out")
```

### Button Behavior

Control button behavior with BoolValue settings:

```lua
-- Prevent closing when menu is open
local toggleValue = Instance.new("BoolValue")
toggleValue.Name = "Toggle"
toggleValue.Value = false -- Prevents closing
toggleValue.Parent = button
```

## Usage Examples

### Basic Menu Button

```lua
-- Create a button that opens a menu
local button = Instance.new("TextButton")
button.Name = "MenuButton"
button.Parent = parentGui

-- Add CollectionService tag for advanced animations
CollectionService:AddTag(button, "MenuButton")

-- Add required children
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetMenu
openValue.Parent = button

local animateValue = Instance.new("StringValue")
animateValue.Name = "Animate"
animateValue.Value = "Active"
animateValue.Parent = button

-- Add interactive styles (modern approach)
button:SetAttribute("HoverStyle", "ScaleUp")
button:SetAttribute("ClickStyle", "Press")
button:SetAttribute("ActiveStyle", "Elevated")
```

### Close Button

```lua
-- Create a close button
local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.Parent = parentGui

-- Add close target
local closeValue = Instance.new("ObjectValue")
closeValue.Name = "Close"
closeValue.Value = targetMenu
closeValue.Parent = closeButton

-- Optional: Custom close animation
local animateOutValue = Instance.new("StringValue")
animateOutValue.Name = "AnimateOut"
animateOutValue.Value = "slide_left" -- or any other preset
animateOutValue.Parent = closeButton
```

### Animation Selection Guide

**For Different UI Elements:**

- **Main Menus**: Use `slide_bottom` (feels natural and intuitive)
- **Side Panels**: Use `slide_left` or `slide_right` (matches panel direction)
- **Overlays/Popups**: Use `fade` or `fade_scale` (subtle and professional)
- **Loading Screens**: Use `none` (instant feedback)
- **Playful Interactions**: Use `bounce` or `elastic` (engaging and fun)
- **Modal Dialogs**: Use `scale_down` (draws attention to closure)

### Toggle Button

```lua
-- Create a toggle button (can't be closed by clicking)
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Parent = parentGui

-- Add CollectionService tag
CollectionService:AddTag(toggleButton, "MenuButton")

-- Add required children
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetMenu
openValue.Parent = toggleButton

local animateValue = Instance.new("StringValue")
animateValue.Name = "Animate"
animateValue.Value = "Active"
animateValue.Parent = toggleButton

-- Prevent closing when menu is open
local toggleValue = Instance.new("BoolValue")
toggleValue.Name = "Toggle"
toggleValue.Value = false
toggleValue.Parent = toggleButton
```

### Button with Interactive Styles

```lua
-- Create a styled button
local styledButton = Instance.new("TextButton")
styledButton.Name = "StyledButton"
styledButton.Parent = parentGui

-- Add basic menu functionality
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetMenu
openValue.Parent = styledButton

local animateValue = Instance.new("StringValue")
animateValue.Name = "Animate"
animateValue.Value = "Active"
animateValue.Parent = styledButton

-- Add interactive styles using attributes
styledButton:SetAttribute("HoverStyle", "Pulse")
styledButton:SetAttribute("ClickStyle", "DeepPress")
styledButton:SetAttribute("ActiveStyle", "Glowing")

-- Or use the helper function
_G.StyleButton("StyledButton", "Pulse", "DeepPress", "Glowing")
```

### Button with Target Styling

```lua
-- Create a button that styles another UI element
local styleButton = Instance.new("TextButton")
styleButton.Name = "StyleButton"
styleButton.Parent = parentGui

-- Basic menu setup
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetMenu
openValue.Parent = styleButton

local animateValue = Instance.new("StringValue")
animateValue.Name = "Animate"
animateValue.Value = "Active"
animateValue.Parent = styleButton

-- Target styling setup
local targetValue = Instance.new("ObjectValue")
targetValue.Name = "Target"
targetValue.Value = backgroundFrame -- UI element to style
targetValue.Parent = styleButton

local styleValue = Instance.new("StringValue")
styleValue.Name = "Style"
styleValue.Value = "{ BackgroundColor3 = Color3.fromRGB(100, 200, 255), BackgroundTransparency = 0.1 }"
styleValue.Parent = styleButton

-- Add interactive styles to the button itself
styleButton:SetAttribute("HoverStyle", "ScaleUp")
styleButton:SetAttribute("ClickStyle", "Press")
```

## Advanced Features

### Multiple Menu Support

A single button can control multiple menus:

```lua
-- Add multiple Open ObjectValues
local openValue1 = Instance.new("ObjectValue")
openValue1.Name = "Open"
openValue1.Value = menu1
openValue1.Parent = button

local openValue2 = Instance.new("ObjectValue")
openValue2.Name = "Open"
openValue2.Value = menu2
openValue2.Parent = button
```

### Custom Animation Direction

```lua
-- Set custom animation direction
local positionValue = Instance.new("StringValue")
positionValue.Name = "Position"
positionValue.Value = "Left" -- or "Right", "Top", "Bottom"
positionValue.Parent = button
```

### Menu Ignoring

Prevent certain menus from closing when opening others:

```lua
-- Add Ignore ObjectValue
local ignoreValue = Instance.new("ObjectValue")
ignoreValue.Name = "Ignore"
ignoreValue.Value = menuToIgnore
ignoreValue.Parent = button
```

## Troubleshooting

### Common Issues

1. **Button not activating when menu is open**
   - Ensure the button has `StringValue "Animate"` with value `"Active"` or `"All"`
   - Check that the `ObjectValue "Open"` points to the correct menu

2. **Menu not closing when button is clicked**
   - Verify the menu is detected as open (check `GroupTransparency` and `Visible`)
   - Ensure `Toggle` BoolValue is not set to `false`

3. **Gradient not working**
   - Make sure the button has the `"MenuButton"` CollectionService tag
   - Check that the button has `UIStroke` with `UIGradient` child

4. **Animation not playing**
   - Verify the animation preset exists in `AnimationPresets.lua`
   - Check that the menu has proper `CanvasGroup` or `Frame` structure

### Debug Functions

The system provides global debug functions:

```lua
-- Clean up all menu listeners
_G.CleanupMenuListeners()

-- Force camera effects (for testing)
_G.ForceCameraEffects(true)

-- Test FOV override
_G.TestFovOverride(true, 80)

-- Style system debug functions
_G.StyleButton(buttonName, hoverStyle, clickStyle, activeStyle) -- Quick setup
_G.TestAttributeStyles() -- Find buttons with style attributes
```

## Best Practices

1. **Use CollectionService tags** for buttons that need advanced animations
2. **Set proper Toggle values** to control menu behavior
3. **Use appropriate animation presets** for your UI style
4. **Test with different menu states** to ensure proper detection
5. **Clean up listeners** when removing UI elements
6. **Use consistent naming** for ObjectValue and StringValue children
7. **Use attribute-based styles** (modern approach) for better performance
8. **Choose appropriate style presets** based on your UI design
9. **Test interactive styles** on different button types
10. **Use the helper function** `_G.StyleButton()` for quick setup
11. **Combine interactive styles with target styling** for rich interactions

## Animation Technical Details

### Menu Opening Animations
- Animations work with both CanvasGroup and regular GuiObjects
- Original positions are saved and restored after animation
- Multiple animation presets available with customizable properties
- Smooth transitions with configurable easing styles
- Support for custom animation directions (Top, Bottom, Left, Right)

### Menu Closing Animations
- Animations work with both CanvasGroup and regular GuiObjects
- UIStroke elements are automatically animated to fade out
- Menu visibility is properly managed after animation completion
- Original positions are restored after animation
- Multiple animation types: slide, fade, scale, bounce, elastic
- Performance optimized with parallel tween execution
- Automatic cleanup prevents memory leaks

### Animation Properties
Each animation type has configurable properties:
- **Duration**: How long the animation takes (default: 0.3 seconds)
- **Easing Style**: How the animation accelerates/decelerates (Quad, Bounce, Elastic, etc.)
- **Easing Direction**: Direction of the easing curve (In, Out, InOut)

## Performance Considerations

- The system uses efficient property change listeners
- Menu state is cached to prevent unnecessary calculations
- Gradient animations are optimized with proper cleanup
- Real-time monitoring only affects buttons with `"Animate"` values
- All animations are optimized for performance
- Multiple tweens run in parallel when possible
- Animations automatically clean up after completion
- No memory leaks from abandoned tweens

## Style Customization System

The MenuAnimator system includes comprehensive styling capabilities through two main systems:

### 1. Interactive Style System

Provides professional hover, click, and active effects for buttons using predefined presets.

#### Modern Attribute-Based Setup
```lua
-- Quick setup using attributes
button:SetAttribute("HoverStyle", "ScaleUp")
button:SetAttribute("ClickStyle", "Press")
button:SetAttribute("ActiveStyle", "Elevated")

-- Or using helper function
_G.StyleButton("ButtonName", "ScaleUp", "Press", "Elevated")
```

#### Available Presets
- **Hover**: `ScaleUp`, `ScaleDown`, `Elevate`, `Brighten`, `Glow`, `Pulse`, `SlideUp`, `Rotate`
- **Click**: `Press`, `DeepPress`, `Squash`, `Flash`, `BounceDown`, `QuickRotate`, `Squeeze`, `Pop`
- **Active**: `Elevated`, `Glowing`, `PulseGlow`, `Bright`, `Highlighted`, `Selected`, `ActiveGlow`, `Premium`

### 2. Target Style System

Allows buttons to modify external UI elements when their menus are active.

#### Basic Setup
```lua
-- Target styling setup
local targetValue = Instance.new("ObjectValue")
targetValue.Name = "Target"
targetValue.Value = backgroundFrame -- UI element to style
targetValue.Parent = button

local styleValue = Instance.new("StringValue")
styleValue.Name = "Style"
styleValue.Value = "{ BackgroundColor3 = Color3.fromRGB(100, 200, 255), BackgroundTransparency = 0.1 }"
styleValue.Parent = button
```

#### Supported Properties
- **Colors**: `BackgroundColor3`, `TextColor3`, `BorderColor3`, `ImageColor3`
- **Transparency**: `BackgroundTransparency`, `TextTransparency`, `ImageTransparency`
- **Size/Position**: `Size`, `Position`, `AnchorPoint`, `Rotation`
- **Text**: `TextSize`, `Font`, `TextStrokeTransparency`
- **Other**: `BorderSizePixel`, `ZIndex`, `Visible`

### Combined Usage Example

```lua
-- Create a button with both interactive and target styles
local button = Instance.new("TextButton")
button.Name = "StyledMenuButton"
button.Parent = parentGui

-- Basic menu functionality
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetMenu
openValue.Parent = button

-- Interactive styles (for the button itself)
button:SetAttribute("HoverStyle", "Pulse")
button:SetAttribute("ClickStyle", "DeepPress")
button:SetAttribute("ActiveStyle", "Glowing")

-- Target styles (for external UI elements)
local targetValue = Instance.new("ObjectValue")
targetValue.Name = "Target"
targetValue.Value = backgroundFrame
targetValue.Parent = button

local styleValue = Instance.new("StringValue")
styleValue.Name = "Style"
styleValue.Value = "{ BackgroundColor3 = Color3.fromRGB(100, 200, 255), BackgroundTransparency = 0.1 }"
styleValue.Parent = button
```

For detailed information, see:
- [Interactive Styles Documentation](docs/MenuAnimator/InteractiveStyles.md)
- [Button Style Presets Documentation](docs/MenuAnimator/ButtonStylePresets.md)
- [StyleManager Documentation](docs/StyleManager.md)

## Integration with Other Systems

The MenuAnimator system integrates seamlessly with:
- Camera effects system
- Sound effects system
- Custom animation presets
- UI layout systems
- Interactive style system (hover, click, active effects)
- Target style system (external UI element styling)
- Button style presets (professional ready-to-use effects)
- CollectionService tagging
- TweenService for smooth animations

This makes it a powerful foundation for complex UI interactions in Roblox games.
