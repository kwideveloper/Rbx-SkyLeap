-- Movement configuration constants for SkyLeap

local Config = {}

-- Core humanoid speeds
Config.BaseWalkSpeed = 20
Config.SprintWalkSpeed = 30

-- Stamina
Config.StaminaMax = 100
Config.SprintDrainPerSecond = 20
Config.StaminaRegenPerSecond = 40
Config.SprintStartThreshold = 20 -- minimum stamina required to start sprinting

-- Momentum system
Config.MomentumIncreaseFactor = 0.08
Config.MomentumDecayPerSecond = 4
Config.MomentumMax = 100
Config.MomentumSuperJumpThreshold = 65
Config.MomentumAirDashThreshold = 45

-- Dash
Config.DashImpulse = 40
Config.DashCooldownSeconds = 1.25
Config.DashStaminaCost = 20

-- Slide
Config.SlideDurationSeconds = 0.5
Config.SlideSpeedBoost = 10
Config.SlideFrictionMultiplier = 0.5
Config.SlideHipHeightDelta = -1.2
Config.SlideStaminaCost = 12

-- Wall run
-- Wall running configuration:
-- WallRunMaxDurationSeconds: Maximum time (in seconds) a player can wall run before being forced off.
Config.WallRunMaxDurationSeconds = 1.75
Config.WallRunMinSpeed = 25
-- WallRunSpeed: The speed at which the player moves while wall running.
Config.WallRunSpeed = 30
-- WallDetectionDistance: The distance (in studs) to check for a wall when attempting to start a wall run.
Config.WallDetectionDistance = 2

-- WallRunDownSpeed: The downward velocity applied to the player while wall running (controls how quickly they slide down).
Config.WallRunDownSpeed = 3

-- WallStickVelocity: The force applied to keep the player attached to the wall during a wall run.
Config.WallStickVelocity = 4

-- Wall hop (Space while wall running)
Config.WallHopForwardBoost = 18

-- Wall jump
Config.WallJumpImpulseUp = 40
Config.WallJumpImpulseAway = 30
Config.WallJumpCooldownSeconds = 0.35
Config.WallJumpStaminaCost = 18

-- Climb
Config.ClimbDetectionDistance = 4
Config.ClimbSpeed = 12
Config.ClimbStickVelocity = 4
Config.ClimbStaminaDrainPerSecond = 8
-- Minimum stamina required to start climbing
Config.ClimbMinStamina = 10
Config.DebugClimb = true

-- Raycast
Config.RaycastIgnoreWater = true

return Config
