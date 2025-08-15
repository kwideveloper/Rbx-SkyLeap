-- Movement configuration constants for SkyLeap

local Config = {}

-- Core humanoid speeds
Config.BaseWalkSpeed = 20
Config.SprintWalkSpeed = 30

-- Stamina
Config.StaminaMax = 400 -- 200
Config.SprintDrainPerSecond = 20 -- 20
Config.StaminaRegenPerSecond = 80 -- 40
Config.SprintStartThreshold = 20 -- minimum stamina required to start sprinting

-- Momentum system
Config.MomentumIncreaseFactor = 0.08
Config.MomentumDecayPerSecond = 4
Config.MomentumMax = 100
Config.MomentumSuperJumpThreshold = 65
Config.MomentumAirDashThreshold = 45

-- Dash
Config.DashImpulse = 50
Config.DashCooldownSeconds = 1.25
Config.DashStaminaCost = 20
Config.DashVfxDuration = 0.2
Config.DashDurationSeconds = 0.18
Config.DashSpeed = 70

-- Slide
Config.SlideDurationSeconds = 0.5
Config.SlideSpeedBoost = 10
Config.SlideFrictionMultiplier = 0.5
Config.SlideHipHeightDelta = -1.2
Config.SlideStaminaCost = 12
Config.SlideVfxDuration = 0.25
Config.SlideCooldownSeconds = 1.0

-- Prone (lie down / crawl)
Config.ProneWalkSpeed = 8
Config.ProneHipHeightDelta = -2.2
Config.ProneCameraOffsetY = -2.5
Config.DebugProne = false

-- Wall run
-- Wall running configuration:
-- WallRunMaxDurationSeconds: Maximum time (in seconds) a player can wall run before being forced off.
Config.WallRunMaxDurationSeconds = 1.75
Config.WallRunMinSpeed = 25
-- WallRunSpeed: The speed at which the player moves while wall running.
Config.WallRunSpeed = 30
-- WallDetectionDistance: The distance (in studs) to check for a wall when attempting to start a wall run.
Config.WallDetectionDistance = 4

-- WallRunDownSpeed: The downward velocity applied to the player while wall running (controls how quickly they slide down).
Config.WallRunDownSpeed = 3

-- WallStickVelocity: The force applied to keep the player attached to the wall during a wall run.
Config.WallStickVelocity = 4

-- Wall hop (Space while wall running)
Config.WallHopForwardBoost = 18

-- Wall jump
Config.WallJumpImpulseUp = 45
Config.WallJumpImpulseAway = 100 -- 65
Config.WallJumpCooldownSeconds = 0.2
Config.WallJumpStaminaCost = 14
Config.WallJumpCarryFactor = 0.25
Config.WallRunLockAfterWallJumpSeconds = 0.45
-- Camera nudge assists
Config.CameraNudgeWallJumpSeconds = 0.2
Config.CameraNudgeWallJumpFraction = 0.45 -- 0..1 blend towards away direction
Config.CameraNudgeWallSlideSeconds = 0.25
Config.CameraNudgeWallSlideFraction = 0.35
Config.CameraNudgeWallSlideDelaySeconds = 1.2
-- Camera nudge after wall jump (subtle assist to show away direction)
Config.CameraNudgeWallJumpSeconds = 0.2
Config.CameraNudgeWallJumpFraction = 0.45 -- 0..1 blend towards away direction

-- Wall slide
Config.WallSlideFallSpeed = 5
Config.WallSlideStickVelocity = 4 -- 4
Config.WallSlideMaxDurationSeconds = 100 -- 100
Config.WallSlideDetectionDistance = 4 -- 4
Config.WallSlideGroundProximityStuds = 5 -- distance from feet to ground to exit slide
Config.WallSlideDrainPerSecond = Config.SprintDrainPerSecond * 0.5

-- Climb
Config.ClimbDetectionDistance = 4
Config.ClimbSpeed = 12
Config.ClimbStickVelocity = 3
Config.ClimbStaminaDrainPerSecond = 8
-- Minimum stamina required to start climbing
Config.ClimbMinStamina = 10
Config.DebugClimb = false

-- Raycast
Config.RaycastIgnoreWater = true

-- Air jump (while falling, no wall): upward and forward boosts
Config.AirJumpImpulseUp = 50
Config.AirJumpForwardBoost = 20

-- Zipline
Config.ZiplineSpeed = 45
Config.ZiplineDetectionDistance = 5
Config.ZiplineStickVelocity = 6
Config.ZiplineEndDetachDistance = 2

-- Camera alignment (body yaw + head tracking)
Config.CameraAlignEnabled = false
Config.CameraAlignBodyLerpAlpha = 0.25 -- 0..1 per frame smoothing for body yaw
Config.CameraAlignHeadEnabled = true
Config.CameraAlignHeadYawDeg = 60
Config.CameraAlignHeadPitchDeg = 30
Config.CameraAlignBodyYawDeg = 45

-- Bunny hop
Config.BunnyHopWindowSeconds = 0.12 -- 0.12 time after landing to count as a perfect hop
Config.BunnyHopMaxStacks = 3
Config.BunnyHopBaseBoost = 20 -- base horizontal speed added on perfect hop
Config.BunnyHopPerStackBoost = 20 -- extra per additional stack
Config.BunnyHopMomentumBonusBase = 12
Config.BunnyHopMomentumBonusPerStack = 4
Config.BunnyHopDirectionCarry = 0.85 -- 0.85--  0..1 how much to preserve current travel direction over input

-- Air control (Quake/CS-style)
Config.AirControlEnabled = true
Config.AirControlUseCameraFacing = true -- when no MoveDirection, use camera facing
Config.AirControlAccelerate = 20 -- 60 acceleration rate along wish dir (per second)
Config.AirStrafeAccelerate = 190 -- 90 extra accel when strafing (low dot with velocity)
Config.AirControlMaxWishSpeed = 45 -- max speed contributed along wish dir
Config.AirControlMaxAddPerTick = 20 -- safety cap per frame on speed added
Config.AirControlTotalSpeedCap = 85 -- overall air speed cap (horizontal)

-- LaunchPad (trampoline) defaults
Config.LaunchPadUpSpeed = 80
Config.LaunchPadForwardSpeed = 0
Config.LaunchPadCarryFactor = 0 -- 0..1 how much of current velocity to preserve
Config.LaunchPadCooldownSeconds = 0.35
Config.LaunchPadMinUpLift = 12 -- ensures detachment from ground even on forward pads

-- Style / Combo system
Config.StyleEnabled = true
Config.StylePerSecondBase = 5
Config.StyleSpeedFactor = 0.12
Config.StyleSpeedThreshold = 18
Config.StyleAirTimePerSecond = 6
Config.StyleWallRunPerSecond = 10 -- per-second scoring aligns with Wallrun: 10 points
Config.StyleWallRunEventBonus = 10 -- on start of a wallrun, as a discrete action
Config.StyleBreakTimeoutSeconds = 3.0 -- break combo if no valid action in this time
Config.StyleMultiplierStep = 0.10 -- x1.1, x1.2, etc.
Config.StyleMultiplierMax = 5.0
-- Action bonuses
Config.StyleBunnyHopBonusBase = 5 -- per jump
Config.StyleBunnyHopBonusPerStack = 5
Config.StyleDashBonus = 8 -- counts only when chained
Config.StyleWallJumpBonus = 15
Config.StyleWallSlideBonus = 10 -- counts only when chained
Config.StylePadChainBonus = 5 -- counts only when chained
-- Combo/variety rules
Config.ComboChainWindowSeconds = 3.0 -- window to chain dependent actions (dash, pad, wallslide, zipline)
Config.StyleRepeatLimit = 3 -- identical consecutive actions beyond this won't bump combo
Config.StyleVarietyWindow = 6 -- last N actions to consider for variety
Config.StyleVarietyDistinctThreshold = 4 -- distinct actions in window to grant bonus
Config.StyleCreativityBonus = 20
-- WallJump streak scaling (more points for fast consecutive walljumps, combo still +1 each)
Config.StyleWallJumpChainWindowSeconds = 0.6
Config.StyleWallJumpStreakBonusPer = 4
Config.StyleWallJumpStreakMaxBonus = 20
Config.StyleRequireSprint = true
Config.StyleCommitInactivitySeconds = 3.0
-- Anti-abuse: max consecutive chain actions on the same wall surface before requiring variety
Config.MaxWallChainPerSurface = 3
Config.StyleComboPopupWindowSeconds = 0.2 -- time to aggregate combo increases into a single popup

-- Trails
Config.TrailEnabled = true
Config.TrailAttachmentNameA = "TrailA"
Config.TrailAttachmentNameB = "TrailB"
Config.TrailBaseTransparency = 0.6
Config.TrailMinTransparency = 0.2
Config.TrailColorMin = Color3.fromRGB(90, 170, 255)
Config.TrailColorMax = Color3.fromRGB(255, 100, 180)
Config.TrailLifeTime = 0.30 -- 0.25
Config.TrailWidth = 0.3 -- 0.3
Config.TrailSpeedMin = 10 -- 10
Config.TrailSpeedMax = 80 -- 80

-- Hand trails
Config.TrailHandsEnabled = true
Config.TrailHandsScale = 0.6 -- width/transparency scaling relative to main trail
Config.TrailHandsLifetimeFactor = 0.5 -- lifetime relative to main trail
Config.TrailHandsSizeFactor = 2.15 -- extra width factor vs main-scaled width

return Config
