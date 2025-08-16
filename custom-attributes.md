# Structure Attributes Reference

This document lists optional Attributes that we can set on Parts/Models to customize movement and responsiveness.

Recommended Animations Events
Jump = Movement (bucle)
JumpStart = Action (one-shot)
Vault = Action (Allways)
LandRoll = Action (one-shot)
Dash/Slide one-shot = Action
Everything else “of locomotion” = Movement

---

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

**Pads (BasePart):**
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

**On Model named "Zipline":**
- `Speed` (number)  
  *Travel speed along the rope.*

- `HeadOffset` (number)  
  *Vertical offset to hang below the line.*

---

### Notes

- Attributes are read on the touched/cast Part and up to a few ancestors (Models) where relevant.
- Surfaces must also satisfy global rules (e.g., near-vertical normal for wallrun/walljump/mantle).
