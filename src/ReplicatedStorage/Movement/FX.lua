-- FX Configuration and Management for SkyLeap
-- Centralizes all visual effects configuration and provides helper functions

local FX = {}

-- FX Configuration: maps actions to FX paths and properties
FX.Config = {
	-- Movement FX
	Run = {
		path = "ReplicatedStorage/FX/Run",
		type = "loop", -- continuous while running
		anchor = "feet", -- position at character feet
		enabled = true,
	},

	Jump = {
		path = "ReplicatedStorage/FX/Jump",
		type = "oneshot", -- single emission
		anchor = "feet",
		enabled = true,
	},

	DoubleJump = {
		path = "ReplicatedStorage/FX/DoubleJump",
		type = "oneshot",
		anchor = "feet",
		enabled = true,
		scale = 1.2, -- slightly bigger than regular jump
	},

	Land = {
		path = "ReplicatedStorage/FX/Land",
		type = "oneshot",
		anchor = "feet",
		enabled = true,
	},

	HardLand = {
		path = "ReplicatedStorage/FX/HardLand", -- for high falls
		type = "oneshot",
		anchor = "feet",
		enabled = true,
		scale = 1.5,
	},

	Roll = {
		path = "ReplicatedStorage/FX/Roll", -- landing roll from high fall
		type = "oneshot",
		anchor = "center", -- at character center during roll
		enabled = true,
	},

	-- Advanced Movement FX
	Dash = {
		path = "ReplicatedStorage/FX/Dash",
		type = "oneshot",
		anchor = "center",
		enabled = true,
		duration = 0.5, -- how long the effect lasts
	},

	AirDash = {
		path = "ReplicatedStorage/FX/AirDash",
		type = "oneshot",
		anchor = "center",
		enabled = true,
	},

	Slide = {
		path = "ReplicatedStorage/FX/Slide",
		type = "loop", -- continuous while sliding
		anchor = "feet",
		enabled = true,
	},

	WallRun = {
		path = "ReplicatedStorage/FX/WallRun",
		type = "loop",
		anchor = "feet",
		enabled = true,
	},

	WallJump = {
		path = "ReplicatedStorage/FX/WallJump",
		type = "oneshot",
		anchor = "feet",
		enabled = true,
	},

	-- Interaction FX
	PowerupPickup = {
		path = "ReplicatedStorage/FX/PowerupPickup",
		type = "oneshot",
		anchor = "custom", -- uses provided position
		enabled = true,
		scale = 1.5, -- bigger than character FX
	},

	LaunchPad = {
		path = "ReplicatedStorage/FX/LaunchPad",
		type = "oneshot",
		anchor = "custom", -- at launchpad position
		enabled = true,
		scale = 2.0,
	},

	-- Parkour FX
	Vault = {
		path = "ReplicatedStorage/FX/Vault",
		type = "oneshot",
		anchor = "center",
		enabled = true,
	},

	Mantle = {
		path = "ReplicatedStorage/FX/Mantle",
		type = "oneshot",
		anchor = "hands", -- at hand/ledge position
		enabled = true,
	},

	Climb = {
		path = "ReplicatedStorage/FX/Climb",
		type = "loop", -- while climbing
		anchor = "hands",
		enabled = true,
	},

	-- Zipline FX
	ZiplineStart = {
		path = "ReplicatedStorage/FX/ZiplineStart",
		type = "oneshot",
		anchor = "hands",
		enabled = true,
	},

	ZiplineTravel = {
		path = "ReplicatedStorage/FX/ZiplineTravel",
		type = "loop", -- while on zipline
		anchor = "hands",
		enabled = true,
	},

	ZiplineEnd = {
		path = "ReplicatedStorage/FX/ZiplineEnd",
		type = "oneshot",
		anchor = "center",
		enabled = true,
	},

	-- Grapple FX
	GrappleShoot = {
		path = "ReplicatedStorage/FX/GrappleShoot",
		type = "oneshot",
		anchor = "hands",
		enabled = true,
	},

	GrappleHit = {
		path = "ReplicatedStorage/FX/GrappleHit",
		type = "oneshot",
		anchor = "custom", -- at grapple hit point
		enabled = true,
	},

	GrappleSwing = {
		path = "ReplicatedStorage/FX/GrappleSwing",
		type = "loop", -- while swinging
		anchor = "hands",
		enabled = true,
	},

	-- Style/Combo FX
	StyleCombo = {
		path = "ReplicatedStorage/FX/StyleCombo",
		type = "oneshot",
		anchor = "center",
		enabled = true,
		scale = function(comboLevel)
			return 1.0 + (comboLevel * 0.2)
		end, -- scales with combo
	},

	StyleBreak = {
		path = "ReplicatedStorage/FX/StyleBreak", -- when combo breaks
		type = "oneshot",
		anchor = "center",
		enabled = true,
	},
}

-- Anchor position calculators
local function getAnchorPosition(character, anchorType, customPosition)
	if customPosition then
		return customPosition
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if anchorType == "feet" then
		local feetOffset = humanoid and humanoid.HipHeight or 3
		return root.Position - Vector3.new(0, feetOffset, 0)
	elseif anchorType == "center" then
		return root.Position
	elseif anchorType == "hands" then
		-- Approximate hand position (slightly forward and up from center)
		local cf = root.CFrame
		return cf.Position + cf.LookVector * 1 + Vector3.new(0, 1, 0)
	else
		return root.Position -- fallback to center
	end
end

-- Main FX playing function
function FX.play(fxName, character, customPosition, overrideScale)
	local config = FX.Config[fxName]
	if not config or not config.enabled then
		return
	end

	-- Get FX template
	local pathParts = string.split(config.path, "/")
	local fxFolder = game
	for _, part in ipairs(pathParts) do
		fxFolder = fxFolder:FindFirstChild(part)
		if not fxFolder then
			print("[FX] Path not found:", config.path, "at part:", part)
			return
		end
	end

	-- Calculate position
	local fxPosition = getAnchorPosition(character, config.anchor, customPosition)
	if not fxPosition then
		print("[FX] Could not determine position for FX:", fxName)
		return
	end

	-- Create FX anchor
	local fxAnchor = Instance.new("Part")
	fxAnchor.Name = "FXAnchor_" .. fxName
	fxAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
	fxAnchor.Transparency = 1
	fxAnchor.CanCollide = false
	fxAnchor.Anchored = true
	fxAnchor.Position = fxPosition
	fxAnchor.Parent = workspace

	-- Clone and setup FX
	local fxInstance = fxFolder:Clone()
	fxInstance.Name = "FX_" .. fxName .. "_" .. tick()
	fxInstance.Parent = fxAnchor

	-- Apply scaling
	local scale = overrideScale or config.scale or 1
	if type(scale) == "function" then
		scale = scale() -- call function to get dynamic scale
	end

	print("[FX] Playing:", fxName, "at:", fxPosition, "scale:", scale)

	-- Process FX components
	for _, descendant in ipairs(fxInstance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			-- Scale particle properties
			if scale ~= 1 and descendant.Size then
				local sizeSeq = descendant.Size
				local newKeypoints = {}
				for _, keypoint in ipairs(sizeSeq.Keypoints) do
					table.insert(
						newKeypoints,
						NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope)
					)
				end
				descendant.Size = NumberSequence.new(newKeypoints)
			end

			-- Configure emission
			descendant.Enabled = true
			if config.type == "oneshot" then
				local burst = tonumber(descendant:GetAttribute("Burst") or 30)
				descendant:Emit(burst * scale)
				descendant.Enabled = false -- disable after burst
			end
			-- For loop type, leave enabled (will be managed by stop function)
		elseif descendant:IsA("Sound") then
			descendant:Play()
		end
	end

	-- Handle cleanup/management based on type
	if config.type == "oneshot" then
		-- Auto-cleanup after duration
		local lifetime = config.duration or 3
		task.delay(lifetime, function()
			if fxAnchor then
				fxAnchor:Destroy()
			end
		end)
		return nil -- no handle needed for oneshot
	else
		-- Return handle for loop FX so it can be stopped
		return {
			anchor = fxAnchor,
			instance = fxInstance,
			name = fxName,
			stop = function()
				if fxAnchor then
					-- Disable all emitters
					for _, desc in ipairs(fxInstance:GetDescendants()) do
						if desc:IsA("ParticleEmitter") then
							desc.Enabled = false
						end
					end
					-- Cleanup after particles finish
					task.delay(2, function()
						if fxAnchor then
							fxAnchor:Destroy()
						end
					end)
				end
			end,
		}
	end
end

-- Convenience functions for common FX
function FX.playJump(character)
	FX.play("Jump", character)
end

function FX.playDoubleJump(character)
	FX.play("DoubleJump", character)
end

function FX.playLanding(character, hardLanding)
	if hardLanding then
		FX.play("HardLand", character)
	else
		FX.play("Land", character)
	end
end

function FX.playRoll(character)
	FX.play("Roll", character)
end

function FX.playDash(character, isAirDash)
	if isAirDash then
		FX.play("AirDash", character)
	else
		FX.play("Dash", character)
	end
end

function FX.playPowerupPickup(character, powerupPosition)
	FX.play("PowerupPickup", character, powerupPosition)
end

function FX.playLaunchPad(character, launchPadPosition)
	FX.play("LaunchPad", character, launchPadPosition)
end

function FX.playStyleCombo(character, comboLevel)
	local config = FX.Config.StyleCombo
	if config.scale and type(config.scale) == "function" then
		local scale = config.scale(comboLevel)
		FX.play("StyleCombo", character, nil, scale)
	else
		FX.play("StyleCombo", character)
	end
end

-- Loop FX management
local activeLoopFX = {} -- [character] = {fxName = handle}

function FX.startLoop(fxName, character)
	FX.stopLoop(fxName, character) -- stop any existing

	local handle = FX.play(fxName, character)
	if handle then
		if not activeLoopFX[character] then
			activeLoopFX[character] = {}
		end
		activeLoopFX[character][fxName] = handle
	end
end

function FX.stopLoop(fxName, character)
	if activeLoopFX[character] and activeLoopFX[character][fxName] then
		activeLoopFX[character][fxName].stop()
		activeLoopFX[character][fxName] = nil
	end
end

function FX.stopAllLoops(character)
	if activeLoopFX[character] then
		for fxName, handle in pairs(activeLoopFX[character]) do
			handle.stop()
		end
		activeLoopFX[character] = {}
	end
end

-- Cleanup when character is removed
game.Players.PlayerRemoving:Connect(function(player)
	if player.Character and activeLoopFX[player.Character] then
		FX.stopAllLoops(player.Character)
		activeLoopFX[player.Character] = nil
	end
end)

return FX
