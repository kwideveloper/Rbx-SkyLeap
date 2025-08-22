-- Server-side powerup system for SkyLeap
-- Handles powerup logic securely and prevents client-side exploitation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- Import movement config
local Config = require(ReplicatedStorage:WaitForChild("Movement"):WaitForChild("Config"))

-- Remote events
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local powerupTouched = remotes:WaitForChild("PowerupTouched")
local powerupActivated = remotes:WaitForChild("PowerupActivated")

-- Cooldown tracking per part instance
local partCooldowns = {} -- [part] = lastUsedTime

-- Valid powerup tags
local POWERUP_TAGS = {
	"AddStamina",
	"AddJump",
	"AddDash",
	"AddAllSkills",
}

-- Helper function to get attribute value with fallback to default
local function getAttributeOrDefault(part, attributeName, defaultValue)
	local value = part:GetAttribute(attributeName)
	if value == nil then
		return defaultValue
	end
	return value
end

-- Helper function to check if a part is on cooldown
local function isOnCooldown(part)
	local lastUsed = partCooldowns[part]
	if not lastUsed then
		return false
	end

	local cooldownTime = getAttributeOrDefault(part, "Cooldown", Config.PowerupCooldownSecondsDefault)
	local timeSinceUsed = os.clock() - lastUsed

	return timeSinceUsed < cooldownTime
end

-- Helper function to set part on cooldown
local function setCooldown(part)
	partCooldowns[part] = os.clock()
end

-- Get existing ClientState folder (created by ParkourController)
local function getClientState()
	local clientState = ReplicatedStorage:FindFirstChild("ClientState")
	if clientState then
		print("[POWERUP SERVER DEBUG] ClientState children:")
		for _, child in ipairs(clientState:GetChildren()) do
			print("[POWERUP SERVER DEBUG]   -", child.Name, ":", child.ClassName)
		end
	end
	return clientState
end

-- Add stamina to player
local function addStamina(player, part)
	local clientState = getClientState()
	print("[POWERUP SERVER DEBUG] ClientState found:", clientState ~= nil)

	if not clientState then
		print("[POWERUP SERVER DEBUG] No ClientState found!")
		return false
	end

	local staminaValue = clientState:FindFirstChild("Stamina")
	local maxStaminaValue = clientState:FindFirstChild("MaxStamina")

	print("[POWERUP SERVER DEBUG] Stamina value found:", staminaValue ~= nil)
	print("[POWERUP SERVER DEBUG] Max stamina value found:", maxStaminaValue ~= nil)

	if staminaValue then
		print("[POWERUP SERVER DEBUG] Current stamina:", staminaValue.Value)
	end

	if not staminaValue then
		print("[POWERUP SERVER DEBUG] No stamina value found in ClientState!")
		return false
	end

	-- Get quantity from attribute or use default percentage
	local percentage = getAttributeOrDefault(part, "Quantity", Config.PowerupStaminaPercentDefault)
	print("[POWERUP SERVER DEBUG] Stamina percentage to add:", percentage)

	-- Calculate stamina to add (percentage of max stamina)
	local maxStamina = maxStaminaValue and maxStaminaValue.Value or Config.StaminaMax
	local staminaToAdd = (percentage / 100) * maxStamina
	print("[POWERUP SERVER DEBUG] Stamina to add:", staminaToAdd)

	-- Add stamina without exceeding max
	local newStamina = math.min(maxStamina, staminaValue.Value + staminaToAdd)
	staminaValue.Value = newStamina

	print("[POWERUP SERVER DEBUG] New stamina value:", newStamina)

	return true
end

-- Add jump ability to player
local function addJump(player, part)
	local clientState = getClientState()
	print("[POWERUP SERVER DEBUG] [JUMP] ClientState found:", clientState ~= nil)

	if not clientState then
		print("[POWERUP SERVER DEBUG] [JUMP] No ClientState found!")
		return false
	end

	local doubleJumpCharges = clientState:FindFirstChild("DoubleJumpCharges")
	print("[POWERUP SERVER DEBUG] [JUMP] DoubleJumpCharges found:", doubleJumpCharges ~= nil)

	if doubleJumpCharges then
		print("[POWERUP SERVER DEBUG] [JUMP] Current charges:", doubleJumpCharges.Value)
	end

	if not doubleJumpCharges then
		print("[POWERUP SERVER DEBUG] [JUMP] No DoubleJumpCharges found in ClientState!")
		return false
	end

	-- Get quantity from attribute or use default
	local quantity = getAttributeOrDefault(part, "Quantity", Config.PowerupJumpCountDefault)
	print("[POWERUP SERVER DEBUG] [JUMP] Quantity to add:", quantity)

	-- Only add if player doesn't have double jump charges
	if doubleJumpCharges.Value <= 0 then
		doubleJumpCharges.Value = math.min(Config.DoubleJumpMax or 1, quantity)
		print("[POWERUP SERVER DEBUG] [JUMP] Added jump charges, new value:", doubleJumpCharges.Value)
		return true
	end

	print("[POWERUP SERVER DEBUG] [JUMP] Player already has jump charges, consuming powerup")
	-- Consume powerup even if no effect was applied
	return false
end

-- Add dash ability to player
local function addDash(player, part)
	local character = player.Character
	print("[POWERUP SERVER DEBUG] [DASH] Character found:", character ~= nil)

	if not character then
		print("[POWERUP SERVER DEBUG] [DASH] No character found!")
		return false
	end

	-- Use existing Abilities module functions
	local Abilities = require(ReplicatedStorage.Movement.Abilities)
	print("[POWERUP SERVER DEBUG] [DASH] Abilities module loaded:", Abilities ~= nil)

	if not Abilities or not Abilities.addAirDashCharge or not Abilities.isDashAvailable then
		print("[POWERUP SERVER DEBUG] [DASH] Abilities module functions not available!")
		return false
	end

	-- Get quantity from attribute or use default
	local quantity = getAttributeOrDefault(part, "Quantity", Config.PowerupDashCountDefault)
	print("[POWERUP SERVER DEBUG] [DASH] Quantity to add:", quantity)

	-- Check current dash availability
	local isDashAvailable = Abilities.isDashAvailable(character)
	print("[POWERUP SERVER DEBUG] [DASH] Is dash currently available:", isDashAvailable)

	-- Only add if player doesn't have air dash charges available
	if not isDashAvailable then
		print("[POWERUP SERVER DEBUG] [DASH] Adding dash charges...")
		-- Reset charges first, then add the specified amount
		Abilities.resetAirDashCharges(character)
		for i = 2, quantity do -- Start from 2 since resetAirDashCharges already adds 1
			Abilities.addAirDashCharge(character, 1)
		end
		print("[POWERUP SERVER DEBUG] [DASH] Dash charges added successfully")
		return true
	end

	print("[POWERUP SERVER DEBUG] [DASH] Player already has dash available, consuming powerup")
	-- Consume powerup even if no effect was applied
	return false
end

-- Restore all abilities like touching ground + full stamina
local function addAllSkills(player, part)
	local character = player.Character
	if not character then
		return false
	end

	local clientState = getClientState()
	if not clientState then
		return false
	end

	local staminaValue = clientState:FindFirstChild("Stamina")
	local maxStaminaValue = clientState:FindFirstChild("MaxStamina")
	local doubleJumpCharges = clientState:FindFirstChild("DoubleJumpCharges")

	if not staminaValue then
		return false
	end

	-- Restore full stamina
	local maxStamina = maxStaminaValue and maxStaminaValue.Value or Config.StaminaMax
	staminaValue.Value = maxStamina

	-- Restore double jump charges
	if doubleJumpCharges then
		doubleJumpCharges.Value = Config.DoubleJumpMax or 1
	end

	-- Restore air dash charges using existing functions
	local Abilities = require(ReplicatedStorage.Movement.Abilities)
	if Abilities and Abilities.resetAirDashCharges then
		Abilities.resetAirDashCharges(character)
	end

	return true
end

-- Handle powerup effect based on tag
local function handlePowerupEffect(player, part, tag)
	if tag == "AddStamina" then
		return addStamina(player, part)
	elseif tag == "AddJump" then
		return addJump(player, part)
	elseif tag == "AddDash" then
		return addDash(player, part)
	elseif tag == "AddAllSkills" then
		return addAllSkills(player, part)
	end

	return false
end

-- Validate that player can actually touch the part (anti-exploit)
local function validateTouch(player, part)
	local character = player.Character
	if not character then
		return false
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return false
	end

	-- Check distance (basic exploit prevention)
	local distance = (humanoidRootPart.Position - part.Position).Magnitude
	local maxDistance = 50 -- Maximum reasonable touch distance

	if distance > maxDistance then
		warn("Player " .. player.Name .. " attempted to touch powerup from too far away: " .. distance)
		return false
	end

	return true
end

-- Handle powerup touch request from client
powerupTouched.OnServerEvent:Connect(function(player, part)
	print("[POWERUP SERVER DEBUG] Touch request from", player.Name, "for part:", part and part.Name or "NIL")

	-- Validate the part exists and is a powerup
	if not part or not part:IsA("BasePart") or not part.Parent then
		print("[POWERUP SERVER DEBUG] Invalid part")
		return
	end

	-- Validate touch distance
	if not validateTouch(player, part) then
		print("[POWERUP SERVER DEBUG] Touch validation failed")
		return
	end

	-- Check if part is on cooldown
	if isOnCooldown(part) then
		print("[POWERUP SERVER DEBUG] Part is on cooldown")
		return
	end

	-- Get all tags for this part and check if any are powerup tags
	local tags = CollectionService:GetTags(part)
	print("[POWERUP SERVER DEBUG] Part tags:", table.concat(tags, ", "))
	local powerupTag = nil

	for _, tag in ipairs(tags) do
		for _, validTag in ipairs(POWERUP_TAGS) do
			if tag == validTag then
				powerupTag = tag
				break
			end
		end
		if powerupTag then
			break
		end
	end

	if not powerupTag then
		print("[POWERUP SERVER DEBUG] No valid powerup tag found")
		return
	end

	print("[POWERUP SERVER DEBUG] Processing powerup:", powerupTag)

	-- Apply powerup effect
	local success = handlePowerupEffect(player, part, powerupTag)
	print("[POWERUP SERVER DEBUG] Effect success:", success)

	-- Set cooldown regardless of success (powerup is consumed)
	setCooldown(part)

	-- Compute quantity to send to client for local application
	local qty = 0
	if powerupTag == "AddStamina" then
		qty = getAttributeOrDefault(part, "Quantity", Config.PowerupStaminaPercentDefault)
	elseif powerupTag == "AddJump" then
		qty = getAttributeOrDefault(part, "Quantity", Config.PowerupJumpCountDefault)
	elseif powerupTag == "AddDash" then
		qty = getAttributeOrDefault(part, "Quantity", Config.PowerupDashCountDefault)
	end

	-- Notify client with payload
	powerupActivated:FireClient(player, powerupTag, success, part.Name, qty)
end)

-- Handle when a character touches a powerup part (server-side detection as backup)
local function onPartTouched(hit, part)
	-- Check if the hit is a character part
	local character = hit.Parent
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local player = Players:GetPlayerFromCharacter(character)

	if not humanoid or not player then
		return
	end

	-- Check if part is on cooldown
	if isOnCooldown(part) then
		return
	end

	-- Get all tags for this part and check if any are powerup tags
	local tags = CollectionService:GetTags(part)
	local powerupTag = nil

	for _, tag in ipairs(tags) do
		for _, validTag in ipairs(POWERUP_TAGS) do
			if tag == validTag then
				powerupTag = tag
				break
			end
		end
		if powerupTag then
			break
		end
	end

	if not powerupTag then
		return
	end

	-- Apply powerup effect
	local success = handlePowerupEffect(player, part, powerupTag)

	-- Set cooldown regardless of success (powerup is consumed)
	setCooldown(part)

	-- Compute quantity to send to client for local application
	local qty2 = 0
	if powerupTag == "AddStamina" then
		qty2 = getAttributeOrDefault(part, "Quantity", Config.PowerupStaminaPercentDefault)
	elseif powerupTag == "AddJump" then
		qty2 = getAttributeOrDefault(part, "Quantity", Config.PowerupJumpCountDefault)
	elseif powerupTag == "AddDash" then
		qty2 = getAttributeOrDefault(part, "Quantity", Config.PowerupDashCountDefault)
	end

	-- Notify client with payload
	powerupActivated:FireClient(player, powerupTag, success, part.Name, qty2)
end

-- Initialize powerup system
local function initializePowerups()
	-- Set up touched events for all existing powerup parts
	for _, tag in ipairs(POWERUP_TAGS) do
		local parts = CollectionService:GetTagged(tag)
		for _, part in ipairs(parts) do
			if part:IsA("BasePart") then
				part.Touched:Connect(function(hit)
					onPartTouched(hit, part)
				end)
			end
		end

		-- Set up events for newly tagged parts
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			if part:IsA("BasePart") then
				part.Touched:Connect(function(hit)
					onPartTouched(hit, part)
				end)
			end
		end)
	end
end

-- Note: ClientState cleanup is handled by ParkourController

-- Initialize the system
initializePowerups()

print("Powerup system initialized successfully!")
