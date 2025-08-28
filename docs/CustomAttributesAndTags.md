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
- `Stamina` (bool)  
  *If true, standing/touching this part enables stamina regeneration even if airborne.*

---

## 3. LaunchPad Attributes

**Pads (BasePart) - Attributes:**
- `LaunchPad` (bool)  
  *Enables launch behavior on touch/overlap.*

- `UpSpeed` (number)  
  *Upward speed component used by the pad.*

- `ForwardSpeed` (number)  
  *Horizontal forward speed component along pad's LookVector.*

- `CarryFactor` (number 0..1)  
  *Fraction of current velocity preserved when launching.*

- `UpLift` (number)  
  *Minimum upward impulse to ensure detaching from ground.*

- `CooldownSeconds` (number)  
  *Per-character cooldown between triggers.*

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
- `Breakable` (bool)
  *If true, enables breakable platform behavior on touch.*

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
- **Range**: Only shows for hooks within Config.HookAutoRange (default: 90 studs)
- **Formatting**: Smart time display (seconds, minutes, "Ready!")
- **Performance**: Updates every 0.1 seconds to avoid constant text changes
- **Auto-cleanup**: Removes labels when hooks are destroyed or out of range

**Configuration Options:**
- **Config.HookCooldownLabels** (bool): Enable/disable the entire system
- **Config.HookAutoRange** (number): Maximum distance to show labels
- **Config.HookTag** (string): Tag to identify hookable objects (default: "Hookable")

**Customization:**
- Modify the BillboardGui template in ReplicatedStorage/UI/Hook/BillboardGui
- Adjust animation timing in HookCooldownLabels.client.lua
- Change text formatting in the formatTimeRemaining function

---

# UI Tags & Components

## 10. Currency Display Tags

**UI Elements (TextLabel/TextButton):**
- `Coin` (Tag)  - Automatically displays and updates player's coin balance
- `Diamond` (Tag) - Automatically displays and updates player's diamond balance

**Features:**
- Auto-formats numbers with abbreviations (1k, 100k, 1M, etc.)
- Syncs with server currency updates
- Supports animated value changes
- Works with reward animations and visual effects

---

## 11. Menu System Tags

**Interactive UI Elements (TextButton/ImageButton):**
- `OpenMenu` (Tag) - Makes button automatically open/close associated menu frame

**Required Children for OpenMenu buttons:**
- `Open` (ObjectValue) - Points to the Frame/GuiObject to open/close
- `Ignore` (ObjectValue, optional) - Points to frames that should stay open when this menu opens

**Features:**
- Automatic menu switching (closes other menus when opening new ones)
- Visual feedback with scaling and rotation animations
- FOV changes and blur effects
- Music ducking and reverb effects
- Supports nested menu hierarchies

**Example Setup:**
```lua
-- Button setup
local button = -- your TextButton or ImageButton
local targetFrame = -- the Frame you want to open/close

-- Create ObjectValue pointing to target frame
local openValue = Instance.new("ObjectValue")
openValue.Name = "Open"
openValue.Value = targetFrame
openValue.Parent = button

-- Add the tag
CollectionService:AddTag(button, "OpenMenu")
```

---

## 12. Special Movement Tags

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
- Only visible for hooks within range (Config.HookAutoRange)
- Automatically clones and manages labels for all hookable objects

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

## Testing the Zipline Tag System

**How to Test:**
1. **Create a Zipline Object:**
   - Create a Model, Folder, or BasePart in your workspace
   - Add the "Zipline" tag using CollectionService or Studio tools
   - Add at least 2 Attachment objects as children (anywhere in the hierarchy)

2. **Server Initialization:**
   - The ZiplineInitializer.server.lua script will automatically:
     - Find the 2 attachments within the tagged object (anywhere in hierarchy)
     - Create a RopeConstraint in the root object (where the tag is) with Visible = true
     - Set Attachment0 and Attachment1 properties to link the found attachments

3. **Expected Behavior:**
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
   - Position them within range of the player (Config.HookAutoRange = 90 studs)

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
- Check that hooks are within Config.HookAutoRange distance

---

### Notes

- Attributes are read on the touched/cast Part and up to a few ancestors (Models) where relevant
- Surfaces must also satisfy global rules (e.g., near-vertical normal for wallrun/walljump/mantle)
- UI tags are automatically detected and bound by respective client scripts
- All numeric attributes support decimal values unless otherwise specified
- CollectionService tags are case-sensitive
- Use `SharedUtils.getAttributeOrDefault()` in custom scripts for consistent attribute reading
