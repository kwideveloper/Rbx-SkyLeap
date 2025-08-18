-- LaunchPad server logic: propel players when touching parts with Attribute LaunchPad=true

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Movement.Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PadTriggered = Remotes:WaitForChild("PadTriggered")

local recentLaunch = {} -- [character] = cooldownUntil (global)
local recentByPad = {} -- [character] = { [pad] = cooldownUntil }
local launchLock = {} -- short reentry lock per character

local function isCharacter(part)
	if not part then
		return nil
	end
	local character = part:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	return character, humanoid
end

local function applyLaunch(character, humanoid, pad)
	-- Cooldown per character to avoid re-triggering multiple frames
	local now = os.clock()
	-- Hard short lock to prevent multiple Touched in same frame
	local lockUntil = launchLock[character] or 0
	if now < lockUntil then
		return
	end
	-- Resolve cooldown seconds with safe fallback when attribute is missing or <= 0
	local cdAttr = tonumber(pad:GetAttribute("CooldownSeconds"))
	local cdSec = (cdAttr and cdAttr > 0) and cdAttr or (Config.LaunchPadCooldownSeconds or 0.35)
	-- Character-level cooldown (global)
	local untilTs = recentLaunch[character] or 0
	if now < untilTs then
		return
	end
	-- Character + Pad cooldown (per-pad)
	recentByPad[character] = recentByPad[character] or {}
	local untilPad = recentByPad[character][pad] or 0
	if now < untilPad then
		return
	end
	-- Set both cooldowns and set lock (lock at least 0.3s or 25% of cd)
	recentLaunch[character] = now + cdSec
	recentByPad[character][pad] = now + cdSec
	launchLock[character] = now + math.max(0.3, cdSec * 0.25)

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local upSpeed = tonumber(pad:GetAttribute("UpSpeed")) or Config.LaunchPadUpSpeed or 80
	local fwdSpeed = tonumber(pad:GetAttribute("ForwardSpeed")) or (Config.LaunchPadForwardSpeed or 90)
	local fwdSpeedOriginal = fwdSpeed -- keep original studs (distance) when distance mode is on
	local carry = tonumber(pad:GetAttribute("CarryFactor")) or (Config.LaunchPadCarryFactor or 0.25)
	local minUp = tonumber(pad:GetAttribute("UpLift")) or (Config.LaunchPadMinUpLift or 0)

	local vel = root.AssemblyLinearVelocity
	local carryVel = vel * math.clamp(carry, 0, 1)

	-- Compose impulse from both components
	local upDir = Vector3.yAxis -- world-up for deterministic vertical
	local fwdDir = pad.CFrame.LookVector
	local forwardHoriz = Vector3.new(fwdDir.X, 0, fwdDir.Z)
	if forwardHoriz.Magnitude > 0 then
		forwardHoriz = forwardHoriz.Unit
	end
	local forwardHorizToSend = forwardHoriz -- send to client
	-- Precompute horizontal decomposition (along pad and perpendicular)
	local velHoriz = Vector3.new(vel.X, 0, vel.Z)
	local along = 0
	local perp = velHoriz
	if forwardHoriz.Magnitude > 0 then
		along = velHoriz:Dot(forwardHoriz)
		perp = velHoriz - forwardHoriz * along
	end
	-- Distance mode disabled: treat attributes as simple velocity adds
	local upAddMag = math.max(0, upSpeed)
	local fwdAddMag = math.max(0, fwdSpeed)
	local add = (upDir * upAddMag) + (forwardHoriz * fwdAddMag)

	-- Ensure a minimum upward impulse always for consistent lift
	local needUp = math.max(0, minUp - add.Y)
	if needUp > 0 then
		add = add + Vector3.new(0, needUp, 0)
	end

	local newHoriz = perp + forwardHoriz * (along + fwdAddMag)
	-- Always elevate by at least the computed vertical impulse
	local newVy = math.max(vel.Y + upAddMag, upAddMag)
	-- If grounded, enforce minimum uplift to detach
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		newVy = math.max(newVy, (minUp or 0))
	end
	local newVel = Vector3.new(newHoriz.X, newVy, newHoriz.Z)

	-- Debug logging
	pcall(function()
		local cfg = require(game:GetService("ReplicatedStorage").Movement.Config)
		if cfg.DebugLaunchPad then
			print(
				string.format(
					"[LaunchPad] part=%s upSpeed=%.2f fwdSpeed=%.2f minUp=%.2f cd=%.2f",
					pad:GetFullName(),
					upSpeed,
					fwdSpeed,
					minUp,
					cdSec
				)
			)
			print(
				string.format(
					"[LaunchPad] velIn=(%.2f,%.2f,%.2f) horizAlong=%.2f horizPerpMag=%.2f",
					vel.X,
					vel.Y,
					vel.Z,
					along,
					perp.Magnitude
				)
			)
			print(
				string.format(
					"[LaunchPad] newVel=(%.2f,%.2f,%.2f) newHorizMag=%.2f",
					newVel.X,
					newVel.Y,
					newVel.Z,
					newHoriz.Magnitude
				)
			)
		end
	end)
	root.AssemblyLinearVelocity = newVel

	-- Put humanoid into Freefall to avoid ground friction suppressing the impulse
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end)

	-- Notify client to allow chaining (only count if followed by a valid action)
	local player = game:GetService("Players"):GetPlayerFromCharacter(character)
	if player then
		pcall(function()
			PadTriggered:FireClient(player, newVel)
		end)
	end
end

local function onPadTouched(pad, other)
	if not other or not other:IsA("BasePart") then
		return
	end
	local character, humanoid = isCharacter(other)
	if not character then
		return
	end
	if pad:GetAttribute("LaunchPad") ~= true then
		return
	end
	applyLaunch(character, humanoid, pad)
end

local function hookPad(pad)
	if not pad:IsA("BasePart") then
		return
	end
	if pad.Touched then
		pad.Touched:Connect(function(other)
			onPadTouched(pad, other)
		end)
	end
end

-- Connect existing pads
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and d:GetAttribute("LaunchPad") == true then
		hookPad(d)
	end
end

-- Connect future pads and attribute changes
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("BasePart") then
		if d:GetAttribute("LaunchPad") == true then
			hookPad(d)
		else
			d:GetAttributeChangedSignal("LaunchPad"):Connect(function()
				if d:GetAttribute("LaunchPad") == true then
					hookPad(d)
				end
			end)
		end
	end
end)

-- Fallback overlap detection so anchored pads work even if Touched doesn't fire
local accum = 0
RunService.Heartbeat:Connect(function(dt)
	accum = accum + dt
	if accum < 0.05 then
		return
	end
	accum = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		local character = plr.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if root and humanoid then
				-- Overlap pass: catch proximity with anchored pads reliably
				local overlapParams = OverlapParams.new()
				overlapParams.FilterType = Enum.RaycastFilterType.Exclude
				overlapParams.FilterDescendantsInstances = { character }
				overlapParams.RespectCanCollide = false
				local size = (root.Size or Vector3.new(2, 2, 1)) + Vector3.new(4, 5, 4)
				local parts = workspace:GetPartBoundsInBox(root.CFrame, size, overlapParams)
				local launched = false
				for _, p in ipairs(parts) do
					if p and typeof(p.GetAttribute) == "function" and p:GetAttribute("LaunchPad") == true then
						applyLaunch(character, humanoid, p)
						launched = true
						break
					end
				end
				-- Downward raycast: detect pad directly under the player (thin pads)
				if not launched then
					local rayParams = RaycastParams.new()
					rayParams.FilterType = Enum.RaycastFilterType.Exclude
					rayParams.FilterDescendantsInstances = { character }
					rayParams.IgnoreWater = true
					local origin = root.Position
					local dir = Vector3.new(0, -6, 0)
					local result = workspace:Raycast(origin, dir, rayParams)
					if result and result.Instance and typeof(result.Instance.GetAttribute) == "function" then
						if result.Instance:GetAttribute("LaunchPad") == true then
							applyLaunch(character, humanoid, result.Instance)
						end
					end
				end
			end
		end
	end
end)
