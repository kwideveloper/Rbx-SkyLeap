# UI Particle System

## 📋 General Description

This system allows creating animated particle effects in Roblox's user interface (UI). Particles are automatically generated from any `ImageLabel` that has the "Particle" tag and offer complete control over their appearance, movement, and behavior.

## 🎯 Main Features

- ✅ **TweenService-based**: Smooth and optimized animations
- ✅ **Automatic pooling**: Efficient instance reuse for better performance
- ✅ **Attribute system**: Easy configuration through instance attributes
- ✅ **Multiple spawn areas**: Precise control over where particles appear
- ✅ **Advanced easing**: More than 10 types of animations available
- ✅ **Stagger system**: Control timing between particles
- ✅ **UIScale scaling**: Smooth scaling without distortion
- ✅ **Smart positioning**: Particles appear inside from edges for natural effects

## 🚀 Quick Start

### 1. Create a Particle Image

```lua
-- Create ImageLabel in your UI
local particleImage = Instance.new("ImageLabel")
particleImage.Image = "rbxassetid://6023426926" -- Your image
particleImage.Size = UDim2.new(0, 20, 0, 20)
particleImage.AnchorPoint = Vector2.new(0.5, 0.5)
particleImage.BackgroundTransparency = 1
particleImage.Parent = yourFrame -- Container where particles will appear
```

### 2. Add Tag and Configure

```lua
-- Add the "Particle" tag
local CollectionService = game:GetService("CollectionService")
CollectionService:AddTag(particleImage, "Particle")

-- Configure attributes (optional)
particleImage:SetAttribute("Particles", 5)        -- 5 particles
particleImage:SetAttribute("VisibleTime", 1.0)    -- 1 second visible
particleImage:SetAttribute("EasingStyle", "Bounce") -- Bounce effect
particleImage:SetAttribute("Area", "Top")         -- Appear from top
```

## ⚙️ Configuration Attributes

### Basic Attributes

| Attribute | Type | Default Value | Description |
|-----------|------|---------------|-------------|
| `Particles` | Number | 20 | Maximum number of active particles |
| `Lifetime` | Number | 5.0 | Total duration of animations (scale/rotation/movement) in seconds |
| `MaxScale` | Number | Original size | Maximum scale factor (1.0 = original size) |
| `RotationSpeed` | Number | 120 | Rotation speed in degrees per second |
| `Speed` | Number | 100 | Movement speed (affects random drift) |

### Timing Attributes

| Attribute | Type | Default Value | Description |
|-----------|------|---------------|-------------|
| `Cooldown` | Number | 1.0 | Seconds between particle group spawns |
| `VisibleTime` | Number | 0.25 | Time in seconds that particle stays fully visible |
| `Staggered` | Boolean | false | If `true`, particles appear staggered |
| `StaggerPercent` | Number | 0.4 | Percentage of total time to wait before spawning next particle (0.1-1.0) |

### Appearance Attributes

| Attribute | Type | Default Value | Description |
|-----------|------|---------------|-------------|
| `EasingStyle` | String | "Quart" | Animation style (see list below) |
| `EasingDirection` | String | "Out" | Easing direction: "In", "Out", "InOut" |
| `Area` | String | "All" | Area where particles appear (see list below) |

## 🎨 Available Easing Styles

| Style | Description |
|-------|-------------|
| `Linear` | No acceleration |
| `Sine` | Smooth and natural |
| `Back` | Back bounce effect |
| `Bounce` | Bounce effect |
| `Elastic` | Elastic effect |
| `Quad` | Quadratic acceleration |
| `Quart` | Quartic acceleration |
| `Quint` | Quintic acceleration |
| `Exponential` | Exponential acceleration |
| `Circular` | Circular acceleration |

## 📍 Spawn Areas

| Area | Description |
|------|-------------|
| `All` | Particles appear anywhere in the container |
| `Border` | Particles appear on edges (top, right, bottom, left) |
| `Center` | Particles appear in the center of the container |
| `Top` | Particles appear inside from top edge |
| `Right` | Particles appear inside from right edge |
| `Left` | Particles appear inside from left edge |
| `Bottom` | Particles appear inside from bottom edge |

## ⏱️ Timing System

### Animation Sequence

1. **Fade-in** (0.2s): Particle appears gradually (transparency 1 → 0)
2. **Visible** (configurable): Particle stays fully visible
3. **Fade-out** (0.3s): Particle disappears gradually (transparency 0 → 1)

### Total Timing
```
Total time = 0.2s + VisibleTime + 0.3s
```

### Example with VisibleTime = 0.5s
```
0.0s  →  0.2s  →  0.7s  →  1.0s
Fade-in   Visible  Fade-out
(0.2s)    (0.5s)   (0.3s)
```

## 🎮 Practical Examples

### Basic Sparkle Particles

```lua
local sparkle = Instance.new("ImageLabel")
sparkle.Image = "rbxassetid://6023426926"
sparkle.Size = UDim2.new(0, 24, 0, 24)
sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
sparkle.BackgroundTransparency = 1
sparkle.Parent = yourFrame

CollectionService:AddTag(sparkle, "Particle")

-- Basic configuration
sparkle:SetAttribute("Particles", 3)
sparkle:SetAttribute("VisibleTime", 1.0)
sparkle:SetAttribute("EasingStyle", "Bounce")
```

### Particles Emerging from Top

```lua
local particle = Instance.new("ImageLabel")
particle.Image = "rbxassetid://85601264783180"
particle.Size = UDim2.new(0, 20, 0, 20)
particle.AnchorPoint = Vector2.new(0.5, 0.5)
particle.BackgroundTransparency = 1
particle.Parent = yourFrame

CollectionService:AddTag(particle, "Particle")

-- Configuration for emerging particles
particle:SetAttribute("Area", "Top")
particle:SetAttribute("Particles", 5)
particle:SetAttribute("VisibleTime", 0.8)
particle:SetAttribute("Staggered", true)
particle:SetAttribute("StaggerPercent", 0.6)
particle:SetAttribute("EasingStyle", "Back")
particle:SetAttribute("EasingDirection", "Out")
```

### Smoke Particles

```lua
local smoke = Instance.new("ImageLabel")
smoke.Image = "rbxassetid://123456789" -- Your smoke image
smoke.Size = UDim2.new(0, 32, 0, 32)
smoke.AnchorPoint = Vector2.new(0.5, 0.5)
smoke.BackgroundTransparency = 1
smoke.Parent = yourFrame

CollectionService:AddTag(smoke, "Particle")

-- Configuration for smoke
smoke:SetAttribute("Area", "Bottom")
smoke:SetAttribute("Particles", 8)
smoke:SetAttribute("VisibleTime", 2.0)
smoke:SetAttribute("RotationSpeed", 45)
smoke:SetAttribute("Speed", 150)
smoke:SetAttribute("MaxScale", 2.5)
smoke:SetAttribute("EasingStyle", "Exponential")
smoke:SetAttribute("EasingDirection", "InOut")
```

## 🎛️ Control API

```lua
-- Manual control
_G.ParticleAPI.startEmission(container, config) -- Start manual emission
_G.ParticleAPI.stopEmission(container)          -- Stop emission
_G.ParticleAPI.getStats()                       -- Get statistics
```

## 🔧 Advanced Configuration

### Pooling System

The system automatically reuses particles to optimize performance:

- ✅ **Automatic creation**: New particles are created only when necessary
- ✅ **Reuse**: Finished particles are recycled for future use
- ✅ **Automatic cleanup**: Memory is freed when particles finish

### Performance Optimizations

- **TweenService**: Animations optimized by Roblox
- **Smart pooling**: Avoids constant creation/destruction
- **Precise timing**: Efficient callbacks for recycling
- **Controlled memory**: Instances are reused automatically

## 🚨 Important Notes

### Limitations

- Particles require a container (Frame) as parent
- Images must have `BackgroundTransparency = 1`
- Attributes are optional (use default values)
- The system works only on the client

### Recommendations

- ✅ Use images with transparent background
- ✅ Set `AnchorPoint` to (0.5, 0.5) for better rotation
- ✅ Adjust `ZIndex` to control depth
- ✅ Test different combinations of easing and timing
- ✅ Use reasonable values for `Particles` (max. 50-100)

## 🎯 Use Cases

### UI Effects
- ✨ **Sparkles**: To highlight important elements
- 💎 **Gems**: For rewards or collectibles
- 💰 **Coins**: For monetary effects
- ⭐ **Stars**: For ratings or achievements
- 🎊 **Confetti**: For celebrations

### Interactive States
- 🔄 **Loading**: Loading indicators
- ✅ **Success**: Success confirmations
- ❌ **Error**: Error indicators
- ⚠️ **Warning**: Important alerts
- 🎯 **Focus**: Selected elements

### Environmental
- ❄️ **Snow**: Winter effects
- 🔥 **Fire**: Heat effects
- 💨 **Smoke**: Atmospheric effects
- 🌊 **Water**: Water effects
- 🌸 **Petals**: Natural effects

## 📚 Related Documentation

- [CustomAttributesAndTags.md](CustomAttributesAndTags.md) - Attribute system
- [AnimationHandling.md](AnimationHandling.md) - Animation handling
- [AnimationExamples.md](AnimationExamples.md) - Animation examples

---

*Last updated: $(date)*
