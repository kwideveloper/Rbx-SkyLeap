-- AnimationOutExamples.lua
-- Example implementations of different close animations
-- This file shows how to set up various close button configurations

--[[
EXAMPLE 1: Basic Close Button with Slide Down Animation
Button Setup:
- ObjectValue "Close" → Points to MenuFrame
- StringValue "AnimateOut" → "slide_bottom"

This creates a button that closes the menu with a slide down animation.
]]

--[[
EXAMPLE 2: Close Button with Fade Animation
Button Setup:
- ObjectValue "Close" → Points to PopupFrame
- StringValue "AnimateOut" → "fade"

This creates a button that closes the popup with a fade out animation.
]]

--[[
EXAMPLE 3: Close Button with Slide Left Animation
Button Setup:
- ObjectValue "Close" → Points to SidePanel
- StringValue "AnimateOut" → "slide_left"

This creates a button that closes the side panel with a slide left animation.
]]

--[[
EXAMPLE 4: Close Button with Scale Down Animation
Button Setup:
- ObjectValue "Close" → Points to ModalDialog
- StringValue "AnimateOut" → "scale_down"

This creates a button that closes the modal with a scale down animation.
]]

--[[
EXAMPLE 5: Close Button with Bounce Animation
Button Setup:
- ObjectValue "Close" → Points to GameOverScreen
- StringValue "AnimateOut" → "bounce"

This creates a button that closes the game over screen with a bounce animation.
]]

--[[
EXAMPLE 6: Close Button with No Animation
Button Setup:
- ObjectValue "Close" → Points to LoadingScreen
- StringValue "AnimateOut" → "none"

This creates a button that closes the loading screen immediately without animation.
]]

--[[
EXAMPLE 7: Multiple Close Targets with Different Animations
Button Setup:
- ObjectValue "Close" → Points to MenuFrame1
- ObjectValue "Close" → Points to MenuFrame2
- StringValue "AnimateOut" → "slide_bottom"

This creates a button that closes multiple menus with the same animation.
Note: All targets will use the same animation specified in AnimateOut.
]]

--[[
EXAMPLE 8: Close Button with Custom Animation (Elastic)
Button Setup:
- ObjectValue "Close" → Points to SettingsPanel
- StringValue "AnimateOut" → "elastic"

This creates a button that closes the settings panel with an elastic animation.
]]

--[[
EXAMPLE 9: Close Button with Fade Scale Animation
Button Setup:
- ObjectValue "Close" → Points to InfoPopup
- StringValue "AnimateOut" → "fade_scale"

This creates a button that closes the info popup with a fade and scale animation.
]]

--[[
EXAMPLE 10: Close Button with Slide Right Animation
Button Setup:
- ObjectValue "Close" → Points to RightSidebar
- StringValue "AnimateOut" → "slide_right"

This creates a button that closes the right sidebar with a slide right animation.
]]

--[[
USAGE NOTES:

1. The "AnimateOut" StringValue is optional. If not present, defaults to "slide_bottom"
2. The "Close" ObjectValue is required and must point to a valid GuiObject
3. All animations automatically handle:
   - CanvasGroup transparency
   - UIStroke transparency
   - Menu visibility
   - Position restoration
4. Animations work with any GuiObject type (Frame, CanvasGroup, etc.)
5. Multiple close targets will all use the same animation type
6. The system is fully compatible with existing menu functionality
]]

--[[
PERFORMANCE CONSIDERATIONS:

1. Use "none" for frequently closed elements to avoid animation overhead
2. Use "fade" for simple, fast animations
3. Use "slide_bottom" as default for most cases
4. Use "bounce" or "elastic" sparingly for special effects
5. All animations are optimized and won't cause performance issues
]]

return {}
