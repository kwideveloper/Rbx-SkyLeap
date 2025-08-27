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
	return clientState
end

-- Add stamina to player
local function addStamina(player, part)
	local cs = getClientState()
	if not cs then
		return false
	end

	local staminaValue = cs:FindFirstChild("Stamina")
	local maxStaminaValue = cs:FindFirstChild("MaxStamina")
	if not staminaValue then
		return false
	end

	-- Get quantity from attribute or use default percentage
	local percentage = SharedUtils.getAttributeOrDefault(part, "Quantity", Config.PowerupStaminaPercentDefault)

	-- Calculate stamina to add (percentage of max stamina)
	local maxStamina = maxStaminaValue and maxStaminaValue.Value or Config.StaminaMax
	local staminaToAdd = (percentage / 100) * maxStamina

	-- Add to current stamina, capped at max
	local newStamina = math.min(maxStamina, staminaValue.Value + staminaToAdd)
	staminaValue.Value = newStamina
	return true
end

-- Add jump charges to player
local function addJump(player, part)
	local cs = getClientState()
	if not cs then
		return false
	end

	local doubleJumpCharges = cs:FindFirstChild("DoubleJumpCharges")
	if not doubleJumpCharges then
		return false
	end

	-- Get quantity from attribute or use default
	local quantity = SharedUtils.getAttributeOrDefault(part, "Quantity", Config.PowerupJumpCountDefault)

	-- Only add if player doesn't have double jump charges
	if doubleJumpCharges.Value <= 0 then
		doubleJumpCharges.Value = math.min(Config.DoubleJumpMax or 1, quantity)
		return true
	else
		return false
	end
end

-- Add dash charges to player
local function addDash(player, part)
	local cs = getClientState()
	if not cs then
		return false
	end

	-- Try to access Abilities through the Abilities module in ReplicatedStorage
	local abilitiesModule = ReplicatedStorage:FindFirstChild("Movement")
		and ReplicatedStorage.Movement:FindFirstChild("Abilities")
	local Abilities = abilitiesModule and require(abilitiesModule) or nil

	if not Abilities then
		return false
	end

	if not (Abilities.isDashAvailable and Abilities.grantDash) then
		return false
	end

	-- Get quantity from attribute or use default
	local quantity = SharedUtils.getAttributeOrDefault(part, "Quantity", Config.PowerupDashCountDefault)

	-- Check current dash availability
	local character = player.Character
	if not character then
		return false
	end

	local isDashAvailable = Abilities.isDashAvailable(character)

	-- Only grant if player doesn't have dash available
	if not isDashAvailable then
		Abilities.grantDash(character, quantity)
		return true
	else
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
	-- Validate the part exists and is a powerup
	if not part or not part:IsA("BasePart") or not part.Parent then
		return
	end

	-- Enhanced touch validation
	if not validateTouch(player, part) then
		return
	end

	-- Check if part is on cooldown
	if isOnCooldown(part) then
		return
	end

	-- Get first valid powerup tag (optimized)
	local powerupTag = SharedUtils.getFirstValidTag(part, POWERUP_TAGS)

	if not powerupTag then
		return
	end

	-- Apply powerup effect
	local success = handlePowerupEffect(player, part, powerupTag)

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
