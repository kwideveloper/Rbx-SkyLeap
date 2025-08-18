## Air Dash Power-up (add extra dash in mid-air)

This project already supports air dash charges:
- Config keys: `DashAirChargesDefault`, `DashAirChargesMax`
- API: `Abilities.resetAirDashCharges(character)`, `Abilities.addAirDashCharge(character, amount)`

### Quick setup (attribute-based pickup)
1) Create a Part in Workspace that will act as a pickup.
2) In Properties, add a Number attribute:
   - Name: `DashAdd`
   - Value: how many extra air dashes to grant (e.g., 1)
3) Add this server script (place in `ServerScriptService` as `DashRefill.server.lua`) to grant charges on touch:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Abilities = require(ReplicatedStorage.Movement.Abilities)

local CHARGE_ATTR = "DashAdd"       -- Number attribute on the pickup part
local COOLDOWN_ATTR = "CooldownSeconds" -- Optional per-part cooldown

local recentByPart = {} -- [character] = { [part] = cooldownUntil }

local function isCharacter(part)
    local model = part and part:FindFirstAncestorOfClass("Model")
    if not model then return nil end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    return model, humanoid
end

local function hookPickup(pickup)
    if not pickup:IsA("BasePart") then return end
    pickup.Touched:Connect(function(other)
        local character, _ = isCharacter(other)
        if not character then return end
        local add = tonumber(pickup:GetAttribute(CHARGE_ATTR)) or 1
        if add <= 0 then return end

        local now = os.clock()
        recentByPart[character] = recentByPart[character] or {}
        local cd = tonumber(pickup:GetAttribute(COOLDOWN_ATTR)) or 0.5
        local untilTs = recentByPart[character][pickup] or 0
        if now < untilTs then return end
        recentByPart[character][pickup] = now + cd

        Abilities.addAirDashCharge(character, add)
    end)
end

-- Hook existing and future pickups (Parts with DashAdd attribute)
for _, d in ipairs(workspace:GetDescendants()) do
    if d:IsA("BasePart") and d:GetAttribute(CHARGE_ATTR) ~= nil then
        hookPickup(d)
    end
end
workspace.DescendantAdded:Connect(function(d)
    if d:IsA("BasePart") and d:GetAttribute(CHARGE_ATTR) ~= nil then
        hookPickup(d)
    end
end)
```

### Notes
- Increase `DashAirChargesMax` in `ReplicatedStorage/Movement/Config.lua` if you want to allow stacking more than the default.
- To fully refill on grab (instead of adding), call `Abilities.resetAirDashCharges(character)` in the handler.
- You can swap the attribute for a CollectionService tag if you prefer tagging pickups.


