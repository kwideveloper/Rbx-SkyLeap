-- Powerups system for SkyLeap (Client-side)
-- Handles powerup detection and communicates with server

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Powerups = {}

local player = Players.LocalPlayer

-- Remote events (wait for them to be created by server)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local powerupTouched = remotes:WaitForChild("PowerupTouched")
local powerupActivated = remotes:WaitForChild("PowerupActivated")

-- Local cooldown tracking for UI feedback (server is authoritative)
local localPartCooldowns = {} -- [part] = lastUsedTime

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

-- Helper function to check if a part is on local cooldown (for UI feedback)
local function isOnLocalCooldown(part)
	local lastUsed = localPartCooldowns[part]
	if not lastUsed then
		return false
	end

	local cooldownTime = getAttributeOrDefault(part, "Cooldown", Config.PowerupCooldownSecondsDefault)
	local timeSinceUsed = os.clock() - lastUsed

	return timeSinceUsed < cooldownTime
end

-- Helper function to set part on local cooldown (for UI feedback)
local function setLocalCooldown(part)
	localPartCooldowns[part] = os.clock()
end

-- Helper function to get remaining cooldown time (for UI feedback)
function Powerups.getRemainingCooldown(part)
	local lastUsed = localPartCooldowns[part]
	if not lastUsed then
		return 0
	end

	local cooldownTime = getAttributeOrDefault(part, "Cooldown", Config.PowerupCooldownSecondsDefault)
	local timeSinceUsed = os.clock() - lastUsed
	local remaining = cooldownTime - timeSinceUsed

	return math.max(0, remaining)
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
	-- One-shot FX for powerup pickup at the powerup location
	pcall(function()
		local fxFolder = ReplicatedStorage:FindFirstChild("FX")
		local template = fxFolder and fxFolder:FindFirstChild("DoubleJump")
		if template and partPosition then
			-- Create invisible part at powerup position for FX anchor
			local fxAnchor = Instance.new("Part")
			fxAnchor.Name = "PowerupFXAnchor"
			fxAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
			fxAnchor.Transparency = 1
			fxAnchor.CanCollide = false
			fxAnchor.Anchored = true
			fxAnchor.Position = partPosition
			fxAnchor.Parent = workspace

			local inst = template:Clone()
			inst.Name = "OneShot_Powerup"
			inst.Parent = fxAnchor

			-- Scale up the effect to be bigger than the powerup
			for _, d in ipairs(inst:GetDescendants()) do
				if d:IsA("ParticleEmitter") then
					local burst = tonumber(d:GetAttribute("Burst") or 30)
					-- Make powerup pickup effect more prominent
					d:Emit(burst * 2)
					-- Scale up size if possible
					if d.Size then
						d.Size = NumberSequence.new(d.Size.Keypoints[1].Value * 1.5)
					end
				elseif d:IsA("Sound") then
					d:Play()
				end
			end

			task.delay(3, function()
				if fxAnchor then
					fxAnchor:Destroy()
				end
			end)
		end
	end)
	if success then
		print("Powerup activated:", powerupTag, "from", partName, "qty:", quantity)
	else
		print("Powerup consumed (server no-op), applied locally:", powerupTag, "from", partName, "qty:", quantity)
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

	-- Debug: Print touch information
	print("[POWERUP DEBUG] Touched part:", part.Name)
	print("[POWERUP DEBUG] Part tags:", table.concat(CollectionService:GetTags(part), ", "))

	-- Check if part is on local cooldown (for immediate feedback)
	if isOnLocalCooldown(part) then
		print("[POWERUP DEBUG] Part is on cooldown, ignoring")
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
		print("[POWERUP DEBUG] No valid powerup tag found")
		return
	end

	print("[POWERUP DEBUG] Valid powerup found! Tag:", powerupTag)

	-- Set local cooldown for immediate feedback
	setLocalCooldown(part)

	-- Send touch request to server for validation and effect application
	powerupTouched:FireServer(part)
end

-- Initialize powerup system
function Powerups.init()
	print("[POWERUP DEBUG] Initializing powerup system...")

	-- Set up touched events for all existing powerup parts
	for _, tag in ipairs(POWERUP_TAGS) do
		local parts = CollectionService:GetTagged(tag)
		print("[POWERUP DEBUG] Found", #parts, "parts with tag", tag)

		for _, part in ipairs(parts) do
			if part:IsA("BasePart") then
				print("[POWERUP DEBUG] Registering part:", part.Name, "with tag:", tag)
				part.Touched:Connect(function(hit)
					onPartTouched(hit, part)
				end)
			end
		end

		-- Set up events for newly tagged parts
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			if part:IsA("BasePart") then
				print("[POWERUP DEBUG] New part tagged:", part.Name, "with tag:", tag)
				part.Touched:Connect(function(hit)
					onPartTouched(hit, part)
				end)
			end
		end)
	end

	print("[POWERUP DEBUG] Powerup system initialization complete")
end

-- Clean up function (optional, for memory management)
function Powerups.cleanup()
	localPartCooldowns = {}
end

-- Debug function to check powerup status
function Powerups.debugPowerupStatus(part)
	if not part then
		return
	end

	local cooldownRemaining = Powerups.getRemainingCooldown(part)
	local quantity = part:GetAttribute("Quantity")
	local customCooldown = part:GetAttribute("Cooldown")

	print("=== Powerup Debug (Client) ===")
	print("Part:", part.Name)
	print("Tags:", table.concat(CollectionService:GetTags(part), ", "))
	print("Quantity attribute:", quantity or "nil (using default)")
	print("Cooldown attribute:", customCooldown or "nil (using global default)")
	print("Local cooldown remaining:", cooldownRemaining, "seconds")
	print("Is on local cooldown:", isOnLocalCooldown(part))
end

-- Get client state for local player
function Powerups.getClientState()
	return ReplicatedStorage:FindFirstChild("ClientState")
end

return Powerups
