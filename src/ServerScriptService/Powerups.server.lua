-- SECURE VERSION: Server-side powerup system with enhanced validation
-- Replaces Powerups.server.lua with security enhancements

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

-- Import movement config, shared utilities, and anti-cheat
local Config = require(ReplicatedStorage:WaitForChild("Movement"):WaitForChild("Config"))
local SharedUtils = require(ReplicatedStorage:WaitForChild("SharedUtils"))
local AntiCheat = require(game:GetService("ServerScriptService"):WaitForChild("AntiCheat"))

-- Remote events
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local powerupTouched = remotes:WaitForChild("PowerupTouched")
local powerupActivated = remotes:WaitForChild("PowerupActivated")

-- Valid powerup tags
local POWERUP_TAGS = {
	"AddStamina",
	"AddJump",
	"AddDash",
	"AddAllSkills",
}

-- Enhanced security configuration
local MAX_POWERUP_TOUCH_DISTANCE = 50 -- Maximum distance for valid touch
local POWERUP_SPAM_PROTECTION = {} -- [player][part] = lastTouchTime
local SPAM_PROTECTION_WINDOW = 0.5 -- 500ms between touches of same powerup

-- Helper function to check if a part is on cooldown
local function isOnCooldown(part)
	local cooldownTime = SharedUtils.getAttributeOrDefault(part, "Cooldown", Config.PowerupCooldownSecondsDefault)
	return SharedUtils.isOnCooldown(tostring(part), cooldownTime)
end

-- Helper function to set part on cooldown
local function setCooldown(part)
	SharedUtils.setCooldown(tostring(part))
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
	local cs = getClientState()
	if not cs then
		print("[POWERUP SERVER DEBUG] No ClientState found!")
		return false
	end

	local staminaValue = cs:FindFirstChild("Stamina")
	local maxStaminaValue = cs:FindFirstChild("MaxStamina")
	if not staminaValue then
		print("[POWERUP SERVER DEBUG] No stamina value found in ClientState!")
		return false
	end

	-- Get quantity from attribute or use default percentage
	local percentage = SharedUtils.getAttributeOrDefault(part, "Quantity", Config.PowerupStaminaPercentDefault)
	print("[POWERUP SERVER DEBUG] Stamina percentage to add:", percentage)

	-- Calculate stamina to add (percentage of max stamina)
	local maxStamina = maxStaminaValue and maxStaminaValue.Value or Config.StaminaMax
	local staminaToAdd = (percentage / 100) * maxStamina

	-- Add to current stamina, capped at max
	local newStamina = math.min(maxStamina, staminaValue.Value + staminaToAdd)
	staminaValue.Value = newStamina

	print("[POWERUP SERVER DEBUG] Stamina updated:", staminaValue.Value)
	return true
end

-- Add jump charges to player
local function addJump(player, part)
	local cs = getClientState()
	if not cs then
		print("[POWERUP SERVER DEBUG] [JUMP] No ClientState found!")
		return false
	end

	local doubleJumpCharges = cs:FindFirstChild("DoubleJumpCharges")
	if not doubleJumpCharges then
		print("[POWERUP SERVER DEBUG] [JUMP] No DoubleJumpCharges found in ClientState!")
		return false
	end

	-- Get quantity from attribute or use default
	local quantity = SharedUtils.getAttributeOrDefault(part, "Quantity", Config.PowerupJumpCountDefault)
	print("[POWERUP SERVER DEBUG] [JUMP] Quantity to add:", quantity)

	-- Only add if player doesn't have double jump charges
	if doubleJumpCharges.Value <= 0 then
		doubleJumpCharges.Value = math.min(Config.DoubleJumpMax or 1, quantity)
		print("[POWERUP SERVER DEBUG] [JUMP] Jump charges granted:", doubleJumpCharges.Value)
		return true
	else
		print("[POWERUP SERVER DEBUG] [JUMP] Player already has jump charges:", doubleJumpCharges.Value)
		return false
	end
end

-- Add dash charges to player
local function addDash(player, part)
	local cs = getClientState()
	if not cs then
		print("[POWERUP SERVER DEBUG] [DASH] No ClientState found!")
		return false
	end

	-- Try to access Abilities through the Abilities module in ReplicatedStorage
	local abilitiesModule = ReplicatedStorage:FindFirstChild("Movement")
		and ReplicatedStorage.Movement:FindFirstChild("Abilities")
	local Abilities = abilitiesModule and require(abilitiesModule) or nil

	if not Abilities then
		print("[POWERUP SERVER DEBUG] [DASH] Abilities module not found!")
		return false
	end

	if not (Abilities.isDashAvailable and Abilities.grantDash) then
		print("[POWERUP SERVER DEBUG] [DASH] Abilities module functions not available!")
		return false
	end

	-- Get quantity from attribute or use default
	local quantity = SharedUtils.getAttributeOrDefault(part, "Quantity", Config.PowerupDashCountDefault)
	print("[POWERUP SERVER DEBUG] [DASH] Quantity to add:", quantity)

	-- Check current dash availability
	local character = player.Character
	if not character then
		return false
	end

	local isDashAvailable = Abilities.isDashAvailable(character)
	print("[POWERUP SERVER DEBUG] [DASH] Is dash currently available:", isDashAvailable)

	-- Only grant if player doesn't have dash available
	if not isDashAvailable then
		Abilities.grantDash(character, quantity)
		print("[POWERUP SERVER DEBUG] [DASH] Dash charges granted")
		return true
	else
		print("[POWERUP SERVER DEBUG] [DASH] Player already has dash available")
		return false
	end
end

-- Add all skills to player
local function addAllSkills(player, part)
	local success = true

	-- Get quantities from attributes
	local staminaAdd = SharedUtils.getAttributeOrDefault(part, "Quantity", Config.PowerupStaminaPercentDefault)
	local jumpAdd = SharedUtils.getAttributeOrDefault(part, "Quantity", Config.PowerupJumpCountDefault)
	local dashAdd = SharedUtils.getAttributeOrDefault(part, "Quantity", Config.PowerupDashCountDefault)

	-- Add stamina
	if not addStamina(player, part) then
		success = false
	end

	-- Add jump charges
	if not addJump(player, part) then
		-- For AddAllSkills, we still want to grant jump even if player has some
		local cs = getClientState()
		if cs then
			local doubleJumpCharges = cs:FindFirstChild("DoubleJumpCharges")
			if doubleJumpCharges then
				doubleJumpCharges.Value = Config.DoubleJumpMax or 1
				print("[POWERUP SERVER DEBUG] [ALL SKILLS] Jump charges set to max:", doubleJumpCharges.Value)
			end
		end
	end

	-- Add dash charges
	if not addDash(player, part) then
		-- For AddAllSkills, we still want to grant dash
		local abilitiesModule = ReplicatedStorage:FindFirstChild("Movement")
			and ReplicatedStorage.Movement:FindFirstChild("Abilities")
		local Abilities = abilitiesModule and require(abilitiesModule) or nil
		if Abilities and Abilities.grantDash and player.Character then
			Abilities.grantDash(player.Character, dashAdd)
			print("[POWERUP SERVER DEBUG] [ALL SKILLS] Dash granted")
		end
	end

	return success
end

-- Handle powerup effect
local function handlePowerupEffect(player, part, powerupTag)
	if powerupTag == "AddStamina" then
		return addStamina(player, part)
	elseif powerupTag == "AddJump" then
		return addJump(player, part)
	elseif powerupTag == "AddDash" then
		return addDash(player, part)
	elseif powerupTag == "AddAllSkills" then
		return addAllSkills(player, part)
	end
	return false
end

-- ENHANCED: Touch validation with spam protection
local function validateTouch(player, part)
	-- Use AntiCheat system for rate limiting
	if not AntiCheat.validatePowerupTouch(player, part) then
		return false
	end

	local character = player.Character
	if not (character and character:FindFirstChild("HumanoidRootPart")) then
		return false
	end

	-- Individual powerup spam protection
	local userId = player.UserId
	if not POWERUP_SPAM_PROTECTION[userId] then
		POWERUP_SPAM_PROTECTION[userId] = {}
	end

	local partKey = tostring(part)
	local lastTouch = POWERUP_SPAM_PROTECTION[userId][partKey]
	local now = os.clock()

	if lastTouch and (now - lastTouch) < SPAM_PROTECTION_WINDOW then
		print(string.format("[POWERUP SERVER DEBUG] Spam protection triggered for %s on %s", player.Name, part.Name))
		return false
	end

	POWERUP_SPAM_PROTECTION[userId][partKey] = now

	-- Distance validation
	local hrp = character.HumanoidRootPart
	local distance = (hrp.Position - part.Position).Magnitude

	if distance > MAX_POWERUP_TOUCH_DISTANCE then
		AntiCheat.logSuspiciousActivity(player, "PowerupSpam", {
			type = "InvalidDistance",
			distance = distance,
			maxAllowed = MAX_POWERUP_TOUCH_DISTANCE,
			partName = part.Name,
		})
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

	-- Enhanced touch validation
	if not validateTouch(player, part) then
		print("[POWERUP SERVER DEBUG] Touch validation failed")
		return
	end

	-- Check if part is on cooldown
	if isOnCooldown(part) then
		print("[POWERUP SERVER DEBUG] Part is on cooldown")
		return
	end

	-- Get first valid powerup tag (optimized)
	local powerupTag = SharedUtils.getFirstValidTag(part, POWERUP_TAGS)
	print("[POWERUP SERVER DEBUG] Part tags:", table.concat(CollectionService:GetTags(part), ", "))

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
		qty = SharedUtils.getAttributeOrDefault(part, "Quantity", Config.PowerupStaminaPercentDefault)
	elseif powerupTag == "AddJump" then
		qty = SharedUtils.getAttributeOrDefault(part, "Quantity", Config.PowerupJumpCountDefault)
	elseif powerupTag == "AddDash" then
		qty = SharedUtils.getAttributeOrDefault(part, "Quantity", Config.PowerupDashCountDefault)
	end

	-- Notify client with payload (include part position for FX)
	local partPosition = part.Position
	powerupActivated:FireClient(player, powerupTag, success, part.Name, qty, partPosition)
end)

-- Cleanup spam protection on player leave
Players.PlayerRemoving:Connect(function(player)
	POWERUP_SPAM_PROTECTION[player.UserId] = nil
end)
