-- Admin server-side handler: creates RemoteEvents and secures toggles

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConfig = require(script.Parent:WaitForChild("AdminConfig"))

local function ensureFolder(parent, name)
    local folder = parent:FindFirstChild(name)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = parent
    end
    return folder
end

local function ensureRemoteEvent(parent, name)
    local remote = parent:FindFirstChild(name)
    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = parent
    end
    return remote
end

local adminFolder = ensureFolder(ReplicatedStorage, "Admin")
local toggleInfiniteStamina = ensureRemoteEvent(adminFolder, "ToggleInfiniteStamina")

toggleInfiniteStamina.OnServerEvent:Connect(function(player)
    if not AdminConfig.isAdminUserId(player.UserId) then
        return
    end
    local flags = ensureFolder(player, "_AdminFlags")
    local flag = flags:FindFirstChild("InfiniteStamina")
    if not flag then
        flag = Instance.new("BoolValue")
        flag.Name = "InfiniteStamina"
        flag.Value = false
        flag.Parent = flags
    end
    flag.Value = not flag.Value
end)

Players.PlayerAdded:Connect(function(player)
    ensureFolder(player, "_AdminFlags")
end)
for _, p in ipairs(Players:GetPlayers()) do
    ensureFolder(p, "_AdminFlags")
end


