# Animation Speed Control Examples

This document shows how to use the new global animation function `Animations.playWithDuration()` for controlling animation speed and duration across all movement systems.

## 🎯 **Function Signature**

```lua
local Animations = require(game:GetService("ReplicatedStorage").Movement.Animations)

local animTrack, errorMsg = Animations.playWithDuration(
    animator,           -- The Humanoid's Animator instance
    animationName,      -- The name of the animation (e.g., "HookStart", "ZiplineEnd")
    targetDurationSeconds, -- The exact duration you want the animation to play (in seconds)
    options             -- Optional table with additional settings
)
```

## 🚀 **Basic Usage Examples**

### **1. Simple Animation with Duration Control**

```lua
local humanoid = character:FindFirstChildOfClass("Humanoid")
local animator = humanoid:FindFirstChild("Animator")

if animator then
    local animTrack, errorMsg = Animations.playWithDuration(
        animator,
        "HookStart",
        0.5, -- Animation will play for exactly 0.5 seconds
        {
            debug = true -- Enable debug logging
        }
    )
    
    if not animTrack then
        print("Animation failed:", errorMsg)
    end
end
```

### **2. Animation with Completion Callback**

```lua
local animTrack, errorMsg = Animations.playWithDuration(
    animator,
    "HookFinish",
    2.0, -- Animation will play for exactly 2 seconds
    {
        debug = true,
        onComplete = function(actualDuration, expectedDuration)
            print("Animation completed in", actualDuration, "seconds (expected:", expectedDuration, "seconds)")
            -- Do something when animation finishes
        end
    }
)
```

### **3. Looped Animation (No Duration Control)**

```lua
local animTrack, errorMsg = Animations.playWithDuration(
    animator,
    "HookLoop",
    1.0, -- No duration control for looped animations
    {
        looped = true,
        debug = false
    }
)
```

### **4. Custom Priority and No Default Animation Suppression**

```lua
local animTrack, errorMsg = Animations.playWithDuration(
    animator,
    "Vault_Speed",
    1.5, -- Animation will play for exactly 1.5 seconds
    {
        priority = Enum.AnimationPriority.Core,
        suppressDefault = false, -- Don't suppress fall/jump/land animations
        debug = true
    }
)
```

## 🎮 **Real-World Examples from the Codebase**

### **Hook System**

```lua
-- HookStart animation
local animTrack, errorMsg = Animations.playWithDuration(
    animator,
    "HookStart",
    Config.HookStartDurationSeconds or 1.0,
    {
        debug = true,
        onComplete = function(actualDuration, expectedDuration)
            print("[Hook] HookStart - Animation completed in", actualDuration, "seconds (expected:", expectedDuration, "seconds)")
        end
    }
)

-- HookFinish animation
local finishTrack, errorMsg = Animations.playWithDuration(
    animator,
    "HookFinish",
    Config.HookFinishDurationSeconds or 0.5,
    {
        debug = true,
        onComplete = function(actualDuration, expectedDuration)
            print("[Hook] HookFinish - Animation completed in", actualDuration, "seconds (expected:", expectedDuration, "seconds)")
        end
    }
)
```

### **Zipline System**

```lua
-- ZiplineStart animation
local animTrack, errorMsg = Animations.playWithDuration(
    animator,
    "ZiplineStart",
    Config.ZiplineStartDurationSeconds or 0.2,
    {
        debug = true,
        onComplete = function(actualDuration, expectedDuration)
            print("[Zipline] ZiplineStart - Animation completed in", actualDuration, "seconds (expected:", expectedDuration, "seconds)")
        end
    }
)

-- ZiplineEnd animation
local endTrack, errorMsg = Animations.playWithDuration(
    animator,
    "ZiplineEnd",
    Config.ZiplineEndDurationSeconds or 0.2,
    {
        debug = true,
        onComplete = function(actualDuration, expectedDuration)
            print("[Zipline] ZiplineEnd - Animation completed in", actualDuration, "seconds (expected:", expectedDuration, "seconds)")
        end
    }
)
```

## ⚙️ **Options Reference**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `priority` | `Enum.AnimationPriority` | `Action` | Animation priority level |
| `looped` | `boolean` | `false` | Whether the animation should loop |
| `suppressDefault` | `boolean` | `true` | Suppress fall/jump/land animations |
| `onComplete` | `function` | `nil` | Callback when animation finishes |
| `debug` | `boolean` | `false` | Enable debug logging |

## 🔧 **How It Works**

1. **Speed Calculation**: `SpeedMultiplier = OriginalDuration / TargetDuration`
2. **Animation Loading**: Loads the animation from the registry
3. **Configuration**: Sets priority, looped state, and other properties
4. **Default Suppression**: Stops fall/jump/land animations if requested
5. **Speed Application**: `Play()` first, then `AdjustSpeed()` for reliable speed control
6. **Completion Tracking**: Monitors animation completion and calls callback
7. **Error Handling**: Returns error messages for debugging

## 📊 **Debug Output Example**

```
[Animations] HookStart - Original Duration: 2.43 seconds | Target Duration: 0.5 seconds | Speed Multiplier: 4.87 x | Expected Duration: 0.5 seconds
[Animations] HookStart - Speed after Play + AdjustSpeed: 4.87
[Animations] HookStart - Completed in 0.46 seconds (expected: 0.5 seconds)
```

## 🎯 **Benefits**

- ✅ **Unified Interface**: Same function for all animation systems
- ✅ **Reliable Speed Control**: Uses the proven Play() + AdjustSpeed() method
- ✅ **Automatic Duration**: Animations play for exactly the configured time
- ✅ **Error Handling**: Clear error messages for debugging
- ✅ **Callback Support**: Execute code when animations complete
- ✅ **Debug Logging**: Optional detailed logging for development
- ✅ **Default Suppression**: Automatically handles animation conflicts
- ✅ **Reusable**: Write once, use everywhere

## 🚀 **Migration Guide**

### **Before (Old Way)**
```lua
local animTrack = animator:LoadAnimation(animation)
animTrack.Looped = false
animTrack.Priority = Enum.AnimationPriority.Action

-- Manual speed calculation
local targetDuration = 0.5
local originalDuration = animTrack.Length
local speedMultiplier = originalDuration / targetDuration
speedMultiplier = math.clamp(speedMultiplier, 0.1, 10.0)

-- Manual animation suppression
local originalAnim = humanoid:GetPlayingAnimationTracks()
for _, track in ipairs(originalAnim) do
    if track.Animation and track.Animation.AnimationId then
        local animId = string.lower(track.Animation.AnimationId)
        if animId:find("fall") or animId:find("jump") or animId:find("land") then
            track:Stop(0.1)
        end
    end
end

-- Manual speed application
animTrack:Play()
animTrack:AdjustSpeed(speedMultiplier)
```

### **After (New Way)**
```lua
local animTrack, errorMsg = Animations.playWithDuration(
    animator,
    "HookStart",
    0.5,
    {
        debug = true,
        onComplete = function(actualDuration, expectedDuration)
            print("Animation completed in", actualDuration, "seconds")
        end
    }
)
```

**That's it!** The new function handles everything automatically. 🎉
