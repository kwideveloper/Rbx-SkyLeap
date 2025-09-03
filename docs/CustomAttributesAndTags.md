# SkyLeap Attributes & Tags Reference

This document lists all Attributes and CollectionService Tags used in SkyLeap to customize movement, UI behavior, and game mechanics.

## Animation Events Reference

**Recommended Animation Events:**
- `Jump` = Movement (loop)
- `JumpStart` = Action (one-shot)
- `Vault` = Action (always)
- `LandRoll` = Action (one-shot)
- `Dash/Slide` = Action (one-shot)
- Everything else "of locomotion" = Movement

---

# Part Attributes & Tags

## 1. Wall & Surface Attributes

**Walls (BasePart/Model):**
- `WallJump` (bool)  
  *If false, disallows Wall Jump/Wall Slide on this surface.*

- `WallRun` (bool)  
  *If true on a climbable surface, allows Wall Run anyway (overrides climbable block for wallrun only).*

- `WallRunSpeedMultiplier` (number)  
  *Multiplies the player's current horizontal speed once when starting wallrun to set target wallrun speed.*

- `WallJumpUpMultiplier` (number)  
  *Multiplies Config.WallJumpImpulseUp on this wall.*

- `WallJumpAwayMultiplier` (number)  
  *Multiplies Config.WallJumpImpulseAway on this wall.*

- `Climbable` (bool) / `climbable` (bool)  
  *If true, allows Climb module to attach. WallRun defaults to disallow on climbable unless WallRun==true.*

**Ledge Surfaces (Parts/Models):**
- `Mantle` (bool)  
  *If false, mantle is disabled on this surface (even if geometry fits).*

**Obstacles in Front of the Player:**
- `Vault` (bool)  
  *If true, enables Vault detection on that obstacle. Without this, vault is ignored.*

---

## 2. Floor & Volume Attributes

**Parts (floor/volumes):**
- `Stamina` (Tag) **UPDATED: Now uses CollectionService tag instead of attribute**
  *If tagged, standing/touching this part enables stamina regeneration even if airborne.*

---

## 3. LaunchPad Attributes

**Pads (BasePart) - Attributes:**
- `LaunchPad` (Tag)  
  *Enables launch behavior on touch/overlap.*

- `UpSpeed` (number)  
  *Upward speed component used by the pad.*

- `ForwardSpeed` (number)  
  *Horizontal forward speed component along pad's LookVector.*

- `CooldownSeconds` (number)  
  *Per-character cooldown between triggers.*

- `CarryFactor` (number 0..1)  
  *Fraction of current velocity preserved when launching.*

- `UpLift` (number)  
  *Minimum upward impulse to ensure detaching from ground.*

---

## 4. Zipline Tags & Attributes

**Zipline Objects (BasePart/Model/Folder/MeshPart with "Zipline" Tag) - Setup:**
- `Zipline` (Tag) - Automatically creates RopeConstraint and enables zipline functionality
- Objects must contain at least 2 Attachment objects as descendants (anywhere in hierarchy)
- RopeConstraint is automatically created in the root object (where the tag is) between first 2 attachments found
- RopeConstraint is created with Visible = true by default

**Zipline Attributes (on the tagged object):**
- `Speed` (number)  
  *Travel speed along the rope. Default: 45*

- `HeadOffset` (number)  
  *Vertical offset to hang below the line. Default: 5*

---

## 5. Powerup Attributes

**Powerup Parts (BasePart with CollectionService Tags):**

### Powerup Tags:
- `AddStamina` - Restores player stamina when touched
- `AddJump` - Grants extra jump charges when touched
- `AddDash` - Grants extra dash charges when touched  
- `AddAllSkills` - Restores all abilities when touched

### Powerup Attributes:
- `Quantity` (number)
  *Amount to restore (percentage for stamina, count for jumps/dashes). Uses defaults from Config if not set.*

- `Cooldown` (number)
  *Cooldown time in seconds before powerup can be used again. Default: 2 seconds.*

**Example Setup:**
```lua
-- Create a stamina powerup that restores 50% stamina with 5-second cooldown
part:SetAttribute("Quantity", 50)
part:SetAttribute("Cooldown", 5)
CollectionService:AddTag(part, "AddStamina")
```

--- 

## 6. Breakable Platform Attributes

**Breakable Platforms (BasePart):**
- `Breakable` (Tag) **UPDATED: Now uses CollectionService tag instead of attribute**
  *If tagged, enables breakable platform behavior on touch.*

- `TimeToDissapear` (number)
  *Fade-out duration in seconds when breaking.*

- `TimeToAppear` (number)
  *Delay before reappearing + fade-in duration.*

- `Cooldown` (number)
  *Time in seconds before platform respawns. Default: 0.6.*

**Auto-set Attributes (for internal use):**
- `OriginalSize`, `OriginalTransparency`, `OriginalCanCollide`, `OriginalAnchored`

---

## 7. Zipline Configuration

**System Configuration (in Movement/Config.lua):**
- `ZiplineTagName` (string) - Tag name used to identify zipline objects. Default: "Zipline"
- `ZiplineAutoInitialize` (bool) - Whether to automatically create RopeConstraints for tagged objects. Default: true
- `ZiplineSpeed` (number) - Default travel speed along zipline ropes. Default: 45
- `ZiplineDetectionDistance` (number) - Maximum distance to detect zipline proximity. Default: 7
- `ZiplineHeadOffset` (number) - Default vertical offset to hang below the line. Default: 5

## 8. Hook Highlight Configuration

**System Configuration (in Movement/HookHighlightConfig.lua):**
- **Colors:** Customizable fill and outline colors for normal and cooldown states
- **Properties:** Transparency, depth mode, and animation settings
- **Performance:** Culling distance, batch updates, and maximum highlight count
- **Effects:** Glow and pulse effects (optional)
- **Detection:** Range, line of sight requirements, and priority system

**Example Setup:**
```lua
-- Change to yellow color scheme
local colors = HookHighlightConfig.getColorScheme("ALTERNATIVE_1")
-- Enable pulse effect
HookHighlightConfig.Effects.PULSE_ENABLED = true
-- Adjust performance settings
HookHighlightConfig.Performance.CULLING_DISTANCE = 150
```

## 9. Hook Cooldown Labels Configuration

**Hook Cooldown Labels System:**
- **Template**: Uses BillboardGui from ReplicatedStorage/UI/Hook/BillboardGui
- **Animation**: Bounce-in effect (0.4s), smooth fade-out (0.3s)
- **Range**: Only shows for hooks within Config.HookDefaultRange (default: 90 studs)
- **Formatting**: Smart time display (seconds, minutes, "Ready!")
- **Performance**: Updates every 0.1 seconds to avoid constant text changes
- **Auto-cleanup**: Removes labels when hooks are destroyed or out of range

**Configuration Options:**
- **Config.HookCooldownLabels** (bool): Enable/disable the entire system
- **Config.HookDefaultRange** (number): Maximum distance to show labels
- **Config.HookTag** (string): Tag to identify hookable objects (default: "Hookable")

**Customization:**
- Modify the BillboardGui template in ReplicatedStorage/UI/Hook/BillboardGui
- Adjust animation timing in HookCooldownLabels.client.lua
- Change text formatting in the formatTimeRemaining function

---

## 10. Hook Custom Attributes (Per-Object Configuration)

**Hookable Objects (BasePart/Model with "Hookable" Tag) - Custom Attributes:**

### Per-Hook Speed Configuration:
- `HookMaxApproachSpeed` (number) **NEW**
  *Custom approach speed in studs/second for this specific hook. Overrides Config.HookMaxApproachSpeed.*
  *Example: 150 (faster approach) or 80 (slower approach)*

### Per-Hook Range Configuration:
- `HookRange` (number) **NEW**
  *Custom hook range in studs (radius from hook center). Overrides Config.HookDefaultRange.*
  *Example: 120 (longer range) or 50 (shorter range)*

### Per-Hook Detach Configuration:
- `HookAutoDetachDistance` (number) **NEW**
  *Custom auto-detach distance in studs from hook target. Overrides Config.HookAutoDetachDistance.*
  *Example: 40 (detach farther) or 20 (detach closer)*

### Per-Hook Cooldown Configuration:
- `HookCooldownSeconds` (number) **NEW**
  *Custom cooldown time in seconds for this specific hook. Overrides Config.HookCooldownSeconds.*
  *Example: 3.0 (shorter cooldown) or 10.0 (longer cooldown)*

**Example Setup for Custom Hook:**
```lua
-- Create a fast-approach, short-range hook
local hookPart = Instance.new("Part")
hookPart.Name = "FastHook"
CollectionService:AddTag(hookPart, "Hookable")

-- Set custom attributes
hookPart:SetAttribute("HookMaxApproachSpeed", 200) -- Fast approach
hookPart:SetAttribute("HookRange", 60) -- Short range
hookPart:SetAttribute("HookAutoDetachDistance", 25) -- Close detach
hookPart:SetAttribute("HookCooldownSeconds", 2.0) -- Quick cooldown
```

**Default Values (from Config.lua):**
- `HookMaxApproachSpeed`: 120 studs/second
- `HookDefaultRange`: 90 studs radius
- `HookAutoDetachDistance`: 30 studs
- `HookCooldownSeconds`: 5.5 seconds

**Debug Configuration:**
- Enable `Config.DebugHookCooldownLogs = true` in Movement/Config.lua to see detailed logging
- Debug logs will show distance calculations, custom vs default values, and range checks

**Range Visualization System:**
The hook system includes an automatic range visualization system that works through CollectionService tags. Simply add the appropriate tags to your hookable parts to see their ranges in real-time.

**Visualization Tags:**
- **ShowRanges**: Shows both detection and detach ranges
- **ShowRange**: Shows only the detection range (where hook can be activated)
- **ShowDetach**: Shows only the detach range (where hook auto-disconnects)

**How to Use:**
1. Add the "Hookable" tag to your part
2. Add one of the visualization tags:
   - `ShowRanges` - Shows both ranges
   - `ShowRange` - Shows only detection range
   - `ShowDetach` - Shows only detach range
3. The ranges will appear automatically as colored areas

**Visual Appearance:**
- **Detection Range**: Blue neon sphere (shows where hook can be activated)
- **Detach Range**: Red neon sphere (shows where hook will auto-disconnect)
- **Perfect Spheres**: Each range is a perfect 3D sphere centered exactly on the hookable part
- **Exact Studs**: The sphere radius matches exactly the stud values in attributes
- **Real-time Updates**: Ranges update automatically when you change attributes in play mode

**Example Setup:**
```lua
-- In Roblox Studio, select your hookable part and add these tags:
-- 1. "Hookable" (required for hook functionality)
-- 2. "ShowRanges" (shows both detection and detach ranges)

-- Or use CollectionService in a script:
local CollectionService = game:GetService("CollectionService")
local myHookPart = workspace.MyHookPart

CollectionService:AddTag(myHookPart, "Hookable")
CollectionService:AddTag(myHookPart, "ShowRanges")
```

**Example debug output:**
```
[Hook] Custom range check - Hook: MyHook, Distance: 45.20, CustomRange: 50.00, DefaultRange: 90.00, InRange: YES
[Hook] Approach speed - Hook: MyHook, CustomSpeed: 200, FinalSpeed: 200.00
[Hook] Detach distance - Hook: MyHook, CustomDistance: 25, FinalDistance: 25.00
[Hook] Detach check - Distance: 24.50, AutoDetachDistance: 25.00, ShouldDetach: NO
```

**Notes:**
- All custom attributes are optional - if not set, system uses Config defaults
- Values must be positive numbers greater than 0
- Custom attributes are read from the hookable part itself (not ancestors)
- System prioritizes per-hook attributes over global Config values
- Enable debug logging to verify distance calculations are working correctly

---

# UI Tags & Components

## 11. Currency Display Tags

**UI Elements (TextLabel/TextButton):**
- `Coin` (Tag)  - Automatically displays and updates player's coin balance
- `Diamond` (Tag) - Automatically displays and updates player's diamond balance

**Features:**
- Auto-formats numbers with abbreviations (1k, 100k, 1M, etc.)
- Syncs with server currency updates
- Supports animated value changes
- Works with reward animations and visual effects

---

## 12. Menu System Components

**Interactive UI Elements (TextButton/ImageButton):**
- Buttons automatically detected by their internal structure (no tags required)
- System looks for specific child objects to determine functionality

**Required Children for Menu Buttons:**
- `Open` (ObjectValue) - Points to the Frame/GuiObject to open/close
- `Ignore` (ObjectValue, optional) - Points to frames that should stay open when this menu opens
- `Position` (StringValue, optional) - Animation direction: "Top", "Bottom", "Left", "Right" (default: "Top")

**Animation Children (StringValue named "Animate"):**
- `Animate` (StringValue) with Value: "Hover" - Enables hover animations (scale + rotation)
- `Animate` (StringValue) with Value: "Click" - Enables click animations (position + scale bounce)
- `Animate` (StringValue) with Value: "Active" - Enables active state animations (toggle state)

**Features:**
- Automatic menu switching (closes other menus when opening new ones)
- Visual feedback with scaling and rotation animations
- FOV changes and blur effects
- Music ducking and reverb effects
- Supports nested menu hierarchies
- No CollectionService tags required - fully automatic detection

**Example Setup:**
```lua
-- Button setup
local button = -- your TextButton or ImageButton
local targetFrame = -- the Frame you want to open/close

-- Create ObjectValue pointing to target frame (REQUIRED for menu functionality)
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetFrame
openValue.Parent = button

-- Create animation StringValues (OPTIONAL - only if you want animations)
local hoverAnimate = Instance.new("StringValue")
hoverAnimate.Name = "Animate"
hoverAnimate.Value = "Hover"
hoverAnimate.Parent = button

local clickAnimate = Instance.new("StringValue")
clickAnimate.Name = "Animate"
clickAnimate.Value = "Click"
clickAnimate.Parent = button

local activeAnimate = Instance.new("StringValue")
activeAnimate.Name = "Animate"
activeAnimate.Value = "Active"
activeAnimate.Parent = button

-- Optional: Set animation direction
local positionValue = Instance.new("StringValue")
positionValue.Name = "Position"
positionValue.Value = "Top" -- or "Bottom", "Left", "Right"
positionValue.Parent = button
```

**Animation Types Explained:**
- **Hover**: Scales button to 1.08x and rotates 2° when mouse enters, returns to normal when mouse leaves
- **Click**: Creates bounce effect with position offset and scale reduction when clicked
- **Active**: Toggles between normal and active state (1.12x scale, -8° rotation) when clicked

**Common Use Cases:**

1. **Simple Menu Button (No Animations):**
```lua
-- Just add the Open ObjectValue - no animations
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetFrame
openValue.Parent = button
```

2. **Animated Menu Button (All Animations):**
```lua
-- Add menu functionality
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetFrame
openValue.Parent = button

-- Add all animation types
local animations = {"Hover", "Click", "Active"}
for _, animType in ipairs(animations) do
    local animateValue = Instance.new("StringValue")
    animateValue.Name = "Animate"
    animateValue.Value = animType
    animateValue.Parent = button
end
```

3. **Close Button (No Menu Opening):**
```lua
-- Close buttons don't need Open ObjectValue, just Close ObjectValue
local closeValue = Instance.new("ObjectValue")
closeValue.Name = "Close"
closeValue.Value = targetFrame
closeValue.Parent = button

-- Optional: Add click animation for feedback
local clickAnimate = Instance.new("StringValue")
clickAnimate.Name = "Animate"
clickAnimate.Value = "Click"
clickAnimate.Parent = button
```

4. **Toggle Button (Active State Only):**
```lua
-- For buttons that toggle states but don't open menus
local activeAnimate = Instance.new("StringValue")
activeAnimate.Name = "Animate"
activeAnimate.Value = "Active"
activeAnimate.Parent = button
```

**System Behavior:**
- Buttons are automatically detected when PlayerGui loads or when new UI elements are added
- No manual setup required - just add the appropriate child objects
- System handles all menu management, camera effects, and sound effects automatically
- Multiple buttons can open the same menu
- Menus automatically close when opening new ones (unless in Ignore list)

---

## 13. Special Movement Tags

**Parts/Models for Enhanced Movement:**
- `Ledge` (Tag) - Enables automatic ledge hang detection
- `LedgeFace` (String) (Attribute) - The face to which the player will grab - Values: Front,Back,Left,Right
- `Hookable` (Tag) - Allows grappling hook attachment
- `HookIgnoreLOS` (Tag) - Ignores line-of-sight blocking for grappling hook

**Hook Highlight System:**
- Automatically highlights the nearest hookable object when in range
- Highlight color changes based on cooldown state (cyan when ready, red when on cooldown)
- Configurable colors, transparency, and visual effects
- Performance optimized with culling and batch updates

**Hook Cooldown Labels:**
- Automatically displays remaining cooldown time above hooks when they're on cooldown
- Uses the BillboardGui template from ReplicatedStorage/UI/Hook/BillboardGui
- Animates in with bounce effect when cooldown starts
- Animates out with smooth transition when cooldown ends
- Shows formatted time (e.g., "5.5s", "1m 30s", "Ready!")
- Only visible for hooks within range (Config.HookDefaultRange)
- Automatically clones and manages labels for all hookable objects

---

## 14. Tag vs Attribute Migration Guide

**Recent Updates - Tags vs Attributes:**

### Migrated to Tags (Better Performance):
- **`Stamina`** (Tag) - Was: `Stamina = true` attribute → Now: CollectionService tag
- **`Breakable`** (Tag) - Was: `Breakable = true` attribute → Now: CollectionService tag

### Migration Instructions:
```lua
-- OLD WAY (Attributes) - No longer supported
part:SetAttribute("Stamina", true) -- ❌ Don't use
part:SetAttribute("Breakable", true) -- ❌ Don't use

-- NEW WAY (Tags) - Recommended
CollectionService:AddTag(part, "Stamina") -- ✅ Use this
CollectionService:AddTag(part, "Breakable") -- ✅ Use this
```

### Why Tags are Better:
- **Performance**: Faster lookups, less memory usage
- **Consistency**: Same system as Hookable, Zipline, etc.
- **Flexibility**: Can be managed from CollectionService window
- **Future-proof**: Easier to extend and maintain

---

# Advanced Configuration

## Performance Optimization

**SharedUtils Integration:**
All systems use `SharedUtils.lua` for:
- Cached tag lookups (reduces CollectionService calls)
- Shared attribute reading functions
- Optimized cooldown management
- Number formatting utilities

## Debug Features

**Debug Attributes:**
Many systems support debug flags in `Movement/Config.lua`:
- `DebugVault`, `DebugClimb`, `DebugLedgeHang`
- `DebugHookCooldownLogs`
- `DebugLaunchPad`, `DebugLandingRoll`

---

---

## Testing the Updated Tag System

**How to Test:**
1. **Create a Stamina Object:**
   ```lua
   -- Create a stamina restoration object
   local staminaPart = Instance.new("Part")
   staminaPart.Name = "StaminaPad"
   staminaPart.Position = Vector3.new(0, 5, 0)
   staminaPart.Size = Vector3.new(10, 1, 10)
   staminaPart.Anchored = true
   staminaPart.Parent = workspace
   CollectionService:AddTag(staminaPart, "Stamina") -- Add Stamina tag
   ```

2. **Create a Breakable Platform:**
   ```lua
   -- Create a breakable platform
   local breakablePart = Instance.new("Part")
   breakablePart.Name = "BreakablePlatform"
   breakablePart.Position = Vector3.new(0, 10, 0)
   breakablePart.Size = Vector3.new(8, 1, 8)
   breakablePart.Anchored = true
   breakablePart.Parent = workspace
   CollectionService:AddTag(breakablePart, "Breakable") -- Add Breakable tag
   ```

3. **Create a Zipline Object:**
   - Create a Model, Folder, or BasePart in your workspace
   - Add the "Zipline" tag using CollectionService or Studio tools
   - Add at least 2 Attachment objects as children (anywhere in the hierarchy)

4. **Server Initialization:**
   - The ZiplineInitializer.server.lua script will automatically:
     - Find the 2 attachments within the tagged object (anywhere in hierarchy)
     - Create a RopeConstraint in the root object (where the tag is) with Visible = true
     - Set Attachment0 and Attachment1 properties to link the found attachments

5. **Expected Behavior:**
   - RopeConstraint appears automatically in the root object (where the tag is)
   - Players can use E to zipline when near the rope
   - Custom Speed and HeadOffset attributes work as before

**Example Setup:**
```lua
-- Create a simple zipline setup
local ziplineModel = Instance.new("Model")
ziplineModel.Name = "Ziplinexd" -- Name doesn't matter anymore
ziplineModel.Parent = workspace

-- Add the tag
CollectionService:AddTag(ziplineModel, "Zipline")

-- Create attachments anywhere in the hierarchy
local attachment0 = Instance.new("Attachment")
attachment0.Position = Vector3.new(0, 10, 0)
attachment0.Parent = ziplineModel -- Can be anywhere in the hierarchy

local attachment1 = Instance.new("Attachment")
attachment1.Position = Vector3.new(50, 10, 0)
attachment1.Parent = ziplineModel -- Can be anywhere in the hierarchy

-- The RopeConstraint will be created automatically in the root "Ziplinexd" model
-- with Visible = true, linking the two attachments found
```

## Testing the Hook Cooldown Labels System

**How to Test:**
1. **Ensure BillboardGui Template Exists:**
   - Verify that ReplicatedStorage/UI/Hook/BillboardGui exists
   - The template should contain a TextLabel for displaying cooldown text

2. **Hook Setup:**
   - Create BaseParts with the "Hookable" tag
   - Position them within range of the player (Config.HookDefaultRange = 90 studs)

3. **Expected Behavior:**
   - When a hook is used, it goes on cooldown (Config.HookCooldownSeconds = 5.5s)
   - A cooldown label appears above the hook with bounce animation
   - Text shows remaining time (e.g., "5.5s", "4.2s", "Ready!")
   - Label animates out smoothly when cooldown ends
   - Labels only appear for hooks within range

**Example Setup:**
```lua
-- Create a hookable object
local hookPart = Instance.new("Part")
hookPart.Name = "HookPoint"
hookPart.Position = Vector3.new(0, 10, 0)
hookPart.Size = Vector3.new(2, 2, 2)
hookPart.Parent = workspace

-- Add the Hookable tag
CollectionService:AddTag(hookPart, "Hookable")

-- The HookCooldownLabels system will automatically:
-- - Create a label when the hook is in range
-- - Show cooldown time when the hook is used
-- - Animate the label in/out with bounce effects
-- - Clean up when the hook is destroyed or out of range
```

**Troubleshooting:**
- Check that Config.HookCooldownLabels = true in Movement/Config.lua
- Verify the BillboardGui template exists in ReplicatedStorage/UI/Hook/
- Ensure hooks have the "Hookable" tag
- Check that hooks are within Config.HookDefaultRange distance

---

### Notes

- **Tags vs Attributes**: New systems prefer CollectionService tags over attributes for better performance
- **Migrated Systems**: Stamina and Breakable now use tags instead of boolean attributes
- **Hook Customization**: Per-hook attributes allow fine-tuned control of hook behavior
- **Backward Compatibility**: Old attribute-based systems still work but tags are preferred
- **Performance**: Tags are more efficient than attributes for boolean checks
- Attributes are read on the touched/cast Part and up to a few ancestors (Models) where relevant
- Surfaces must also satisfy global rules (e.g., near-vertical normal for wallrun/walljump/mantle)
- UI tags are automatically detected and bound by respective client scripts
- All numeric attributes support decimal values unless otherwise specified
- CollectionService tags are case-sensitive
- Use `SharedUtils.getAttributeOrDefault()` in custom scripts for consistent attribute reading
