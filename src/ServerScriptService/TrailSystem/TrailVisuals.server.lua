-- Server-side trail system using the unified TrailVisuals module
-- This ensures all players can see each other's equipped trails

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import the unified trail system
local TrailVisuals = require(ReplicatedStorage:WaitForChild("TrailSystem"):WaitForChild("TrailVisuals"))

-- The unified system handles everything automatically
-- No additional code needed - TrailVisuals.lua handles:
-- - Trail creation for all players
-- - Trail updates when players equip trails
-- - Trail cleanup when players leave
-- - Synchronization across all clients

print("[TrailVisuals] Server-side unified trail system loaded successfully")
