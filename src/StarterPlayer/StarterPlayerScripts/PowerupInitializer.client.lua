-- PowerupInitializer: Initializes the powerup system
-- This script ensures the powerup system is properly set up when player spawns

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Powerups = require(ReplicatedStorage.Movement.Powerups)
local player = Players.LocalPlayer

-- Initialize powerup system when player spawns
local function onCharacterAdded(character)
	-- Wait a moment to ensure all systems are loaded
	task.wait(0.1)

	-- Initialize powerup system
	Powerups.init()

	print("[PowerupInitializer] Powerup system initialized for", character.Name)
end

-- Connect to character spawning
if player.Character then
	onCharacterAdded(player.Character)
end

player.CharacterAdded:Connect(onCharacterAdded)
