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

## 4. Zipline Attributes

**On Model named "Zipline" - Attributes:**
- `Speed` (number)  
  *Travel speed along the rope.*

- `HeadOffset` (number)  
  *Vertical offset to hang below the line.*

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

## 7. Zipline Attributes

**Zipline Models (Model named "Zipline"):**
- `Speed` (number)
  *Travel speed along the zipline rope.*

- `HeadOffset` (number)
  *Vertical offset to hang below the zipline.*

---

# UI Tags & Components

## 8. Currency Display Tags

**UI Elements (TextLabel/TextButton):**
- `Coin` (Tag)  - Automatically displays and updates player's coin balance
- `Diamond` (Tag) - Automatically displays and updates player's diamond balance

**Features:**
- Auto-formats numbers with abbreviations (1k, 100k, 1M, etc.)
- Syncs with server currency updates
- Supports animated value changes
- Works with reward animations and visual effects

---

## 9. Menu System Tags

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

## 10. Special Movement Tags

**Parts/Models for Enhanced Movement:**
- `Ledge` (Tag) - Enables automatic ledge hang detection
- `LedgeFace` (String) (Attribute) - The face to which the player will grab - Values: Front,Back,Left,Right
- `Hookable` (Tag) - Allows grappling hook attachment
- `HookIgnoreLOS` (Tag) - Ignores line-of-sight blocking for grappling hook

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

### Notes

- Attributes are read on the touched/cast Part and up to a few ancestors (Models) where relevant
- Surfaces must also satisfy global rules (e.g., near-vertical normal for wallrun/walljump/mantle)
- UI tags are automatically detected and bound by respective client scripts
- All numeric attributes support decimal values unless otherwise specified
- CollectionService tags are case-sensitive
- Use `SharedUtils.getAttributeOrDefault()` in custom scripts for consistent attribute reading
