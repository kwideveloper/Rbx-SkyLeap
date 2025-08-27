-- Powerups system for SkyLeap (Client-side)
-- Handles powerup detection and communicates with server
local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
local SharedUtils = require(game:GetService("ReplicatedStorage").SharedUtils)
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FX = require(ReplicatedStorage.Movement.FX)

local Powerups = {}

local player = Players.LocalPlayer

-- Remote events (wait for them to be created by server)
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

-- Debouncing system to prevent multiple rapid touches of same powerup
local touchDebounce = {}
local DEBOUNCE_TIME = 0.1 -- Very short debounce to prevent rapid touch events

-- Helper function to check if a part is on touch debounce
local function isOnTouchDebounce(part)
	local key = tostring(part)
	local lastTouch = touchDebounce[key]
	if not lastTouch then
		return false
	end
	return (os.clock() - lastTouch) < DEBOUNCE_TIME
end

-- Helper function to set part on touch debounce
local function setTouchDebounce(part)
	touchDebounce[tostring(part)] = os.clock()
end

-- Helper function to check if a part is on server cooldown (for UI feedback)
local function isOnServerCooldown(part)
	local cooldownTime = SharedUtils.getAttributeOrDefault(part, "Cooldown", Config.PowerupCooldownSecondsDefault)
	return SharedUtils.isOnCooldown(tostring(part), cooldownTime)
end

-- Helper function to set server cooldown (called when server confirms activation)
local function setServerCooldown(part)
	SharedUtils.setCooldown(tostring(part))
end

-- Helper function to get remaining cooldown time (for UI feedback)
function Powerups.getRemainingCooldown(part)
	local cooldownTime = SharedUtils.getAttributeOrDefault(part, "Cooldown", Config.PowerupCooldownSecondsDefault)
	return SharedUtils.getRemainingCooldown(tostring(part), cooldownTime)
end

-- Handle powerup activation notification from server
powerupActivated.OnClientEvent:Connect(function(powerupTag, success, partName, quantity, partPosition)
	-- Apply locally regardless of success for responsiveness; server guards cooldowns
	local cs = Powerups.getClientState()
	if cs then
		if powerupTag == "AddStamina" then
			local stamina = cs:FindFirstChild("Stamina")
			local maxStamina = cs:FindFirstChild("MaxStamina")
			if stamina then
				local maxVal = (maxStamina and maxStamina.Value)
					or require(ReplicatedStorage.Movement.Config).StaminaMax
				local pct = tonumber(quantity)
					or require(ReplicatedStorage.Movement.Config).PowerupStaminaPercentDefault
				local add = (pct / 100) * maxVal
				stamina.Value = math.min(maxVal, stamina.Value + add)
			end
		elseif powerupTag == "AddJump" then
			local dj = cs:FindFirstChild("DoubleJumpCharges")
			if dj and dj.Value <= 0 then
				dj.Value = math.min(
					require(ReplicatedStorage.Movement.Config).DoubleJumpMax or 1,
					tonumber(quantity) or require(ReplicatedStorage.Movement.Config).PowerupJumpCountDefault
				)
			end
		elseif powerupTag == "AddDash" then
			local Abilities = require(ReplicatedStorage.Movement.Abilities)
			local character = player.Character
			if character and Abilities and Abilities.resetAirDashCharges and Abilities.addAirDashCharge then
				if not (Abilities.isDashAvailable and Abilities.isDashAvailable(character)) then
					Abilities.resetAirDashCharges(character)
					local q = tonumber(quantity) or require(ReplicatedStorage.Movement.Config).PowerupDashCountDefault
					for i = 2, q do
						Abilities.addAirDashCharge(character, 1)
					end
				end
			end
		elseif powerupTag == "AddAllSkills" then
			local stamina = cs:FindFirstChild("Stamina")
			local maxStamina = cs:FindFirstChild("MaxStamina")
			local dj = cs:FindFirstChild("DoubleJumpCharges")
			if stamina and maxStamina then
				stamina.Value = maxStamina.Value
			end
			if dj then
				dj.Value = require(ReplicatedStorage.Movement.Config).DoubleJumpMax or 1
			end
			local Abilities = require(ReplicatedStorage.Movement.Abilities)
			local character = player.Character
			if character and Abilities and Abilities.resetAirDashCharges then
				Abilities.resetAirDashCharges(character)
			end
		end
	end

	-- Now set the server cooldown since server confirmed the powerup was processed
	-- Find the part by name in workspace (this is for UI feedback)
	local function findPartByName(name)
		for _, part in ipairs(workspace:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == name then
				local hasValidTag = SharedUtils.getFirstValidTag(part, POWERUP_TAGS)
				if hasValidTag then
					return part
				end
			end
		end
		return nil
	end

	local part = findPartByName(partName)
	if part then
		setServerCooldown(part)
	end

	-- One-shot FX for powerup pickup using new FX system
	if partPosition then
		FX.playPowerupPickup(player.Character, partPosition)
	end
end)

-- Handle when local player's character touches a powerup part
local function onPartTouched(hit, part)
	-- Only handle touches from the local player's character
	local character = hit.Parent
	if character ~= player.Character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- Check if part is on server cooldown (real cooldown from previous use)
	if isOnServerCooldown(part) then
		return
	end

	-- Check if part is on touch debounce (prevent rapid multiple touches)
	if isOnTouchDebounce(part) then
		return
	end

	-- Get first valid powerup tag (optimized)
	local powerupTag = SharedUtils.getFirstValidTag(part, POWERUP_TAGS)

	if not powerupTag then
		return
	end

	-- Set short touch debounce to prevent rapid multiple touch events
	setTouchDebounce(part)

	-- Send touch request to server for validation and effect application
	powerupTouched:FireServer(part)
end

-- Initialize powerup system
function Powerups.init()
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

-- Clean up function (optional, for memory management)
function Powerups.cleanup()
	-- Clear SharedUtils cache for this module
	SharedUtils.clearTagCache()
end

-- Debug function to check powerup status
function Powerups.debugPowerupStatus(part)
	if not part then
		return
	end

	local cooldownRemaining = Powerups.getRemainingCooldown(part)
	local quantity = part:GetAttribute("Quantity")
	local customCooldown = part:GetAttribute("Cooldown")

	SharedUtils.debugPrint("POWERUPS", "=== Powerup Debug (Client) ===")
	SharedUtils.debugPrint("POWERUPS", "Part: " .. part.Name)
	SharedUtils.debugPrint("POWERUPS", "Tags: " .. table.concat(CollectionService:GetTags(part), ", "))
	SharedUtils.debugPrint(
		"POWERUPS",
		"Quantity attribute: " .. (quantity and tostring(quantity) or "nil (using default)")
	)
	SharedUtils.debugPrint(
		"POWERUPS",
		"Cooldown attribute: " .. (customCooldown and tostring(customCooldown) or "nil (using global default)")
	)
	SharedUtils.debugPrint("POWERUPS", "Server cooldown remaining: " .. tostring(cooldownRemaining) .. " seconds")
	SharedUtils.debugPrint("POWERUPS", "Is on server cooldown: " .. tostring(isOnServerCooldown(part)))
	SharedUtils.debugPrint("POWERUPS", "Is on touch debounce: " .. tostring(isOnTouchDebounce(part)))
end

-- Get client state for local player
function Powerups.getClientState()
	return ReplicatedStorage:FindFirstChild("ClientState")
end

return Powerups
