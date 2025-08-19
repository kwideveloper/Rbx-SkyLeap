-- Movement configuration constants for SkyLeap

local Config = {}

-- Core humanoid speeds
Config.BaseWalkSpeed = 25 -- 20
Config.SprintWalkSpeed = 50 -- 30
-- Sprint acceleration ramp
Config.SprintAccelSeconds = 0.60 -- 0.45 time to reach full sprint speed
Config.SprintDecelSeconds = 0.25 -- 0.20 time to return to base speed (when releasing sprint)

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
Config.DashImpulse = 60
Config.DashCooldownSeconds = 0 -- 1.25
Config.DashStaminaCost = 20
Config.DashVfxDuration = 0.2
Config.DashDurationSeconds = 0.18 -- 0.18
Config.DashSpeed = 70

-- Double Jump
Config.DoubleJumpEnabled = true
Config.DoubleJumpMax = 1 -- extra jumps allowed while airborne
Config.DoubleJumpStaminaCost = 15
Config.DoubleJumpImpulse = 50 -- vertical speed applied on double jump

-- Air dash charges (per airtime)
Config.DashAirChargesDefault = 1
Config.DashAirChargesMax = 1

-- Slide
Config.SlideDurationSeconds = 0.5
-- Distance-based ground slide: total horizontal distance traveled over the slide duration
Config.SlideDistanceStuds = 10
-- Extra forward burst at the start of the slide (studs/s added, decays over SlideImpulseSeconds)
Config.SlideForwardImpulse = 60
Config.SlideImpulseSeconds = 0.15
Config.SlideSpeedBoost = 0
-- Jump carry from slide (percentages of current horizontal speed)
-- Example: if speed=50 and VerticalPercent=0.3 -> +15 studs/s vertical on jump frame
Config.SlideJumpVerticalPercent = 0.30 -- 0..1 fraction of horizontal speed added to vertical
Config.SlideJumpHorizontalPercent = 0.15 -- 0..1 fraction added to horizontal magnitude
Config.SlideFrictionMultiplier = 0.5
Config.SlideHipHeightDelta = -1.2
Config.SlideStaminaCost = 12
Config.SlideVfxDuration = 0.25
Config.SlideCooldownSeconds = 0.75 -- 1.0

-- Prone / Crawl
Config.ProneWalkSpeed = 8
Config.ProneHipHeightDelta = -2.2
Config.ProneCameraOffsetY = -2.5
Config.DebugProne = false
-- Crouch clearance probe (reduces false positives against front walls)
Config.CrawlStandProbeSideWidth = 0.8 -- studs, sideways width of clearance box
Config.CrawlStandProbeForwardDepth = 0.25 -- studs, forward depth of clearance box (keep small to ignore front walls)
-- Obstacle local-collision toggles during vault/mantle (safer default: don't modify obstacles)
Config.VaultDisableObstacleLocal = false
Config.MantleDisableObstacleLocal = false
-- Crawl geometry/speed
Config.CrawlRootHeight = 0 -- studs height for HumanoidRootPart while crawling
Config.CrawlSpeed = 8
Config.CrawlStandUpHeight = 2.2
Config.CrawlAutoEnabled = true
Config.CrawlAutoSampleSeconds = 0.12
Config.CrawlAutoGroundOnly = true

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
Config.WallJumpImpulseUp = 50
Config.WallJumpImpulseAway = 100 -- 65
Config.WallJumpCooldownSeconds = 0.2
Config.WallJumpStaminaCost = 14
Config.WallJumpCarryFactor = 0.25
Config.WallRunLockAfterWallJumpSeconds = 0
Config.AirControlUnlockAfterWallJumpSeconds = 0
-- Camera nudge assists
Config.CameraNudgeWallJumpSeconds = 0.2
Config.CameraNudgeWallJumpFraction = 0.45 -- 0..1 blend towards away direction
-- [Removed] Camera nudge during wall slide
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
-- Surface verticality filter (dot with world up): allow only near-vertical walls for wall mechanics
Config.SurfaceVerticalDotMin = 1 -- legacy; prefer SurfaceVerticalDotMax below
-- Use SurfaceVerticalDotMax for acceptance threshold. Lower means stricter vertical (e.g., 0.1 ≈ within ~6°).
Config.SurfaceVerticalDotMax = 0.1

-- Air jump (while falling, no wall): upward and forward boosts
Config.AirJumpImpulseUp = 50
Config.AirJumpForwardBoost = 20

-- Zipline
Config.ZiplineSpeed = 45
Config.ZiplineDetectionDistance = 7
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
Config.BunnyHopBaseBoost = 2 -- base horizontal speed added on perfect hop
Config.BunnyHopPerStackBoost = 2 -- extra per additional stack
Config.BunnyHopMomentumBonusBase = 3 -- 7
Config.BunnyHopMomentumBonusPerStack = 2 -- 5
Config.BunnyHopDirectionCarry = 0 -- INSTA REDIRECT=0 | 0..1 how much to preserve current travel direction over input
Config.BunnyHopOppositeCancel = 1 -- 0..1 how much to cancel backward component vs desired direction on hop
Config.BunnyHopPerpDampOnFlip = 1 -- 0..1 how much to damp perpendicular component when flipping direction (only when opposite)
-- Hard reorientation on hop: completely retarget horizontal velocity to desired direction, preserving magnitude
Config.BunnyHopReorientHard = false
Config.BunnyHopLockSeconds = 0.6 -- brief window to lock horizontal velocity to the reoriented vector
Config.BunnyHopMaxAddPerHop = 5 -- studs/s maximum speed added in a single hop
Config.BunnyHopTotalSpeedCap = 85 -- studs/s horizontal cap after applying hop (fallbacks to AirControlTotalSpeedCap)

-- Air control (Quake/CS-style)
Config.AirControlEnabled = true
Config.AirControlUseCameraFacing = true -- when no MoveDirection, use camera facing
Config.AirControlAccelerate = 30 -- 60 acceleration rate along wish dir (per second)
Config.AirStrafeAccelerate = 220 -- 90 extra accel when strafing (low dot with velocity)
Config.AirControlMaxWishSpeed = 42 -- max speed contributed along wish dir
Config.AirControlMaxAddPerTick = 18 -- safety cap per frame on speed added
Config.AirControlTotalSpeedCap = 85 -- overall air speed cap (horizontal)

-- LaunchPad (trampoline) defaults
Config.LaunchPadUpSpeed = 80
Config.LaunchPadForwardSpeed = 0
Config.LaunchPadCarryFactor = 1 -- 0..1 how much of current velocity to preserve
Config.LaunchPadCooldownSeconds = 0 -- 0.35
Config.LaunchPadMinUpLift = 0 -- 12  -- ensures detachment from ground even on forward pads
-- If true, interpret UpSpeed/ForwardSpeed as distances (studs). We'll convert to velocities.
Config.LaunchPadDistanceMode = false
Config.LaunchPadMinFlightTime = 0.25 -- seconds for forward travel conversion
-- Default flight time when UpSpeed==0 to map ForwardSpeed to exact distance
Config.LaunchPadDefaultForwardFlightTime = 1.0 -- seconds

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
Config.StyleVaultBonus = 12
Config.StyleGroundSlideBonus = 8
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

-- Wall jump control gating
Config.WallJumpAirControlSuppressSeconds = 0.2

-- Vault (parkour over low obstacles)
Config.VaultEnabled = true
Config.VaultDetectionDistance = 4.5
Config.VaultMinHeight = 3 -- studs above feet
Config.VaultMaxHeight = 5 -- studs above feet
Config.VaultMinSpeed = 24 -- require decent speed (sprinting)
Config.VaultUpBoost = 0
Config.VaultForwardBoost = 40 -- base minimum forward speed to ensure clearance
Config.VaultDurationSeconds = 0.18 -- shorter for snappier feel
Config.VaultPreserveSpeed = true -- preserve current horizontal speed if higher than base
Config.VaultCooldownSeconds = 0.6
-- Config.VaultAnimationKeys = { "Vault_Speed", "Vault_Lazy", "Vault_Kong", "Vault_Dash", "Vault_TwoHanded" }
Config.VaultAnimationKeys = { "Vault_Speed" }
Config.DebugVault = false
-- Dynamic vault clearance: how many studs above obstacle top we aim to pass
Config.VaultClearanceStuds = 1.5
-- Heights (fractions of root height) to probe obstacle front for estimating top
Config.VaultSampleHeights = { 0.2, 0.4, 0.6, 0.85 }
-- Forward-biased vault tuning
Config.VaultForwardGainPerHeight = 2.5 -- extra forward speed per stud of obstacle height
Config.VaultUpMin = 8
Config.VaultUpMax = 26
-- Retarget authored vault (3 studs) to any obstacle height
Config.VaultCanonicalHeightStuds = 3.0
Config.VaultAlignBlendSeconds = 0.06
Config.VaultAlignHoldSeconds = 0.0
Config.VaultUseGroundHeight = true -- if true, measure obstacle height from ground under player instead of HRP feet
Config.VaultApproachSpeedMin = 6
Config.VaultFacingDotMin = 0.35
Config.VaultApproachDotMin = 0.35
Config.VaultForwardUseHeight = false -- if true, adds VaultForwardGainPerHeight * needUp to forward speed; else constant boost

-- Mantle (ledge grab over medium obstacles)
Config.MantleEnabled = true
Config.MantleDetectionDistance = 4 -- 4.5 -- forward ray distance to detect a ledge
-- Height window relative to root (waist): if obstacle top is within [min, max], allow mantle
Config.MantleMinAboveWaist = 0 -- 0
Config.MantleMaxAboveWaist = 10
Config.MantleForwardOffset = 0.5 -- 1.2 -- how far onto the platform to place the character
Config.MantleUpClearance = 1.5 -- 1.5 -- extra vertical clearance above top to ensure space
Config.MantleDurationSeconds = 0.35 -- 0.22 -- baseline; may be overridden by preserve-speed
Config.MantlePreserveSpeed = true
Config.MantleMinHorizontalSpeed = 24 -- studs/s floor while mantling
Config.MantleCooldownSeconds = 0.35
Config.MantleStaminaCost = 10
-- Mantle approach gating: require facing and velocity towards wall
Config.MantleApproachSpeedMin = 6 -- min horizontal speed towards wall to allow mantle
Config.MantleFacingDotMin = 0.35 -- dot(root forward, towards-wall) >= this
Config.MantleApproachDotMin = 0.35 -- dot(velocity, towards-wall) >= this
Config.MantleWallSlideSuppressSeconds = 0.6 -- extra window after mantle to suppress wall slide
Config.MantleGroundedConfirmSeconds = 1 -- require being grounded this long before re-enabling wall slide
Config.MantleUseMoveDirFallback = true
Config.MantleSpeedRelaxDot = 0.9
Config.MantleSpeedRelaxFactor = 0.4

-- Trails
Config.TrailEnabled = true
Config.TrailBodyPartName = "UpperTorso" -- fallback to "Torso" then HRP
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

-- Grapple / Hook
Config.GrappleEnabled = true
Config.GrappleMaxDistance = 120
Config.GrapplePullForce = 6000
Config.GrappleReelSpeed = 28
Config.GrappleRopeVisible = true
Config.GrappleRopeThickness = 0.06

-- Hand trails
Config.TrailHandsEnabled = true
Config.TrailHandsScale = 0.6 -- width/transparency scaling relative to main trail
Config.TrailHandsLifetimeFactor = 0.5 -- lifetime relative to main trail
Config.TrailHandsSizeFactor = 2.15 -- extra width factor vs main-scaled width

-- Debug flags
Config.DebugLaunchPad = false
Config.DebugLandingRoll = false

return Config
