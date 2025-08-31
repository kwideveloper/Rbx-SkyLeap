# Animation Handling Guide

This document explains how to properly handle animations in the SkyLeap movement system, including optional animations and fallback to Roblox defaults.

## 🎯 **Animation Configuration Types**

### **1. Required Animations**
These animations MUST be configured and will show errors if missing:
- `HookStart` - Animation when starting to hook
- `HookFinish` - Animation when finishing hook
- `ZiplineStart` - Animation when starting zipline
- `ZiplineEnd` - Animation when ending zipline

### **2. Optional Animations**
These animations can be left empty and will gracefully fallback to Roblox defaults:
- `HookLoop` - Loop animation while hooking (optional)
- `ZiplineLoop` - Loop animation while on zipline (optional)
- `Vault_Lazy`, `Vault_Kong` - Alternative vault animations (optional)

## 🚀 **Function Usage Patterns**

### **For Required Animations (use `playWithDuration`)**
```lua
local animTrack, errorMsg = Animations.playWithDuration(
    animator,
    "HookStart",
    Config.HookStartDurationSeconds,
    { debug = true }
)

if not animTrack then
    print("ERROR:", errorMsg) -- This will always show an error
end
```

### **For Optional Animations (use `tryPlayWithDuration`)**
```lua
local animTrack, errorMsg = Animations.tryPlayWithDuration(
    animator,
    "HookLoop",
    1.0,
    { looped = true }
)

if animTrack then
    -- Animation was configured and loaded successfully
    st.animTrack = animTrack
elseif errorMsg then
    -- Real error occurred (animation failed to load)
    print("ERROR:", errorMsg)
else
    -- Animation not configured, fallback to Roblox defaults
    print("No loop animation configured, using Roblox defaults")
end
```

## 🔧 **Current Configuration Status**

Based on your current `Animations.lua`:

```lua
-- Hook / Grapple
HookStart = "rbxassetid://126089819563027",    -- ✅ CONFIGURED
HookLoop = "",                                  -- ❌ NOT CONFIGURED (optional)
HookFinish = "rbxassetid://94363874797651",     -- ✅ CONFIGURED

-- Zipline
ZiplineStart = "rbxassetid://126089819563027", -- ✅ CONFIGURED
ZiplineLoop = "",                               -- ❌ NOT CONFIGURED (optional)
ZiplineEnd = "rbxassetid://94363874797651",     -- ✅ CONFIGURED
```

## 🎮 **How Fallback Works**

### **When HookLoop is not configured:**
1. `Animations.playWithDuration()` returns `nil, nil`
2. System detects `errorMsg` is `nil` (not configured)
3. Shows info message: "No loop animation configured, using Roblox defaults"
4. Roblox default animations (running, idle, etc.) continue normally
5. **No errors are shown** - system continues working

### **When HookLoop is configured but fails:**
1. `Animations.playWithDuration()` returns `nil, "error message"`
2. System detects `errorMsg` is a string (real error)
3. Shows error message: "HookLoop - ERROR: error message"
4. System may not work as expected

## 🛠️ **Best Practices**

### **1. Always check both return values**
```lua
local animTrack, errorMsg = Animations.playWithDuration(...)

if animTrack then
    -- Success
elseif errorMsg then
    -- Real error - handle it
    print("ERROR:", errorMsg)
else
    -- Not configured - use fallback
    print("Using Roblox defaults")
end
```

### **2. Use appropriate function for the use case**
```lua
-- For required animations (will always show error if missing)
local animTrack, errorMsg = Animations.playWithDuration(...)

-- For optional animations (graceful fallback if not configured)
local animTrack, errorMsg = Animations.tryPlayWithDuration(...)
```

### **3. Handle loop animations gracefully**
```lua
-- In your movement system
if data.animTrack and data.animTrack.IsPlaying then
    -- Check if start animation finished
    if not data.animTrack.Looped and data.animTrack.TimePosition >= data.animTrack.Length - 0.1 then
        -- Start animation finished, try to start loop
        data.animTrack:Stop()
        data.animTrack = nil

        local loopTrack, errorMsg = Animations.tryPlayWithDuration(
            humanoid:FindFirstChild("Animator"),
            "HookLoop", -- or "ZiplineLoop"
            1.0,
            { looped = true, debug = false }
        )
        
        if loopTrack then
            data.animTrack = loopTrack
        elseif errorMsg then
            print("Loop animation failed:", errorMsg)
        else
            print("No loop animation configured, using Roblox defaults")
        end
    end
end
```

## 🎯 **Why This System is Better**

### **Before (Old System)**
- ❌ Errors when animations missing
- ❌ System breaks if loop animation fails
- ❌ No graceful fallback
- ❌ Confusing error messages

### **After (New System)**
- ✅ Graceful fallback to Roblox defaults
- ✅ Clear distinction between "not configured" and "failed"
- ✅ System continues working even without optional animations
- ✅ Informative messages instead of errors
- ✅ Consistent behavior across all movement systems

## 🔄 **Migration from Old System**

### **Old Code:**
```lua
local animTrack = animator:LoadAnimation(animation)
if not animTrack then
    print("ERROR: Failed to load animation") -- Always shows error
end
```

### **New Code:**
```lua
local animTrack, errorMsg = Animations.playWithDuration(...)
if not animTrack then
    if errorMsg then
        print("ERROR:", errorMsg) -- Real error
    else
        print("Animation not configured, using defaults") -- Not configured
    end
end
```

## 🎉 **Result**

Now when you use Hook or Zipline:
1. **Start animations** will play with configured duration
2. **Loop animations** will gracefully fallback to Roblox defaults if not configured
3. **Finish animations** will play with configured duration
4. **No errors** will break the system
5. **Roblox default animations** will continue working normally

The system is now robust and handles all animation scenarios gracefully! 🚀
