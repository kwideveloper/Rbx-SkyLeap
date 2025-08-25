-- ClimbUI.client.lua - Shows "Climb" or "Zipline" text when near appropriate objects

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Movement modules
local Climb = require(ReplicatedStorage.Movement.Climb)
local Zipline = require(ReplicatedStorage.Movement.Zipline)

-- Get the interaction UI template from ReplicatedStorage
local InteractionGui = ReplicatedStorage:WaitForChild("UI"):WaitForChild("InteractionGui")

-- UI references (will be cloned to player's PlayerGui)
local interactionUI = nil
local textLabel = nil

-- State tracking
local currentlyShowing = nil -- nil, "Climb", or "Zipline"
local lastCharacter = nil

local function getCharacter()
	return player.Character
end

local function showUI(text)
	if not interactionUI or not textLabel then
		return
	end

	if currentlyShowing == text then
		return -- Already showing this text
	end

	currentlyShowing = text
	textLabel.Text = text
	interactionUI.Enabled = true

	print("[ClimbUI] Showing:", text)
end

local function hideUI()
	if not interactionUI then
		return
	end

	if currentlyShowing == nil then
		return -- Already hidden
	end

	currentlyShowing = nil
	interactionUI.Enabled = false

	print("[ClimbUI] Hidden")
end

local function attachUIToCharacter(character)
	if not interactionUI then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		interactionUI.Parent = humanoidRootPart
		print("[ClimbUI] UI attached to character:", character.Name)
	end
end

local function updateUI()
	local character = getCharacter()
	if not character then
		hideUI()
		return
	end

	-- Check if character changed (respawned)
	if character ~= lastCharacter then
		lastCharacter = character
		if interactionUI then
			attachUIToCharacter(character)
		end
	end

	-- Check current active states first (higher priority)
	local isZiplining = Zipline.isActive(character)
	local isClimbing = Climb.isActive(character)

	-- Check proximity to ziplines and climbable walls
	local nearZipline = Zipline.isNear(character)
	local nearClimbable = Climb.isNearClimbable(character)

	-- Priority: Active states > Proximity > None
	if isZiplining then
		showUI("Press (E) to Release")
	elseif isClimbing then
		showUI("Press (E) to Release")
	elseif nearZipline then
		showUI("Press (E) to Zipline")
	elseif nearClimbable then
		showUI("Press (E) to Climb")
	else
		hideUI()
	end
end

local function setupUI()
	-- Clone the UI template from ReplicatedStorage
	local templateUI = InteractionGui
	if templateUI then
		interactionUI = templateUI:Clone()
		textLabel = interactionUI.Frame.TextLabel

		-- Initially disabled
		interactionUI.Enabled = false
		print("[ClimbUI] UI cloned successfully")
		return true
	else
		warn("[ClimbUI] Could not find UI template")
		return false
	end
end

-- Initialize when player spawns
local function onCharacterAdded(character)
	print("[ClimbUI] Character spawned, setting up UI...")

	-- Wait for character to fully load
	character:WaitForChild("HumanoidRootPart")

	-- Setup UI if not already done
	if not interactionUI then
		local success = setupUI()
		if not success then
			warn("[ClimbUI] Failed to setup UI")
			return
		end
	end

	-- Attach UI to character
	attachUIToCharacter(character)

	print("[ClimbUI] UI ready for character:", character.Name)
end

-- Connect events
if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Main update loop
RunService.RenderStepped:Connect(updateUI)

print("[ClimbUI] Client script loaded successfully")
