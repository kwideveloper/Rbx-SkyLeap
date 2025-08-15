-- LaunchPad server logic: propel players when touching parts with Attribute LaunchPad=true

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Movement.Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PadTriggered = Remotes:WaitForChild("PadTriggered")

local recentLaunch = {} -- [character] = cooldownUntil

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
	local untilTs = recentLaunch[character] or 0
	if now < untilTs then
		return
	end
	recentLaunch[character] = now
		+ (tonumber(pad:GetAttribute("CooldownSeconds")) or Config.LaunchPadCooldownSeconds or 0.35)

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local upSpeed = tonumber(pad:GetAttribute("UpSpeed")) or Config.LaunchPadUpSpeed or 80
	local fwdSpeed = tonumber(pad:GetAttribute("ForwardSpeed")) or (Config.LaunchPadForwardSpeed or 90)
	local carry = tonumber(pad:GetAttribute("CarryFactor")) or (Config.LaunchPadCarryFactor or 0.25)
	local minUp = tonumber(pad:GetAttribute("UpLift")) or (Config.LaunchPadMinUpLift or 0)

	local vel = root.AssemblyLinearVelocity
	local carryVel = vel * math.clamp(carry, 0, 1)

	-- Compose impulse from both components
	local upDir = pad.CFrame.UpVector
	local fwdDir = pad.CFrame.LookVector
	local forwardHoriz = Vector3.new(fwdDir.X, 0, fwdDir.Z)
	if forwardHoriz.Magnitude > 0 then
		forwardHoriz = forwardHoriz.Unit
	end
	local add = (upDir * math.max(0, upSpeed)) + (forwardHoriz * math.max(0, fwdSpeed))

	-- Ensure a minimum upward impulse to detach from ground when touching anchored pads
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		local needUp = math.max(0, minUp - add.Y)
		if needUp > 0 then
			add = add + Vector3.new(0, needUp, 0)
		end
	end

	local newVel = carryVel + add
	root.AssemblyLinearVelocity = newVel

	-- Put humanoid into Freefall to avoid ground friction suppressing the impulse
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end)

	-- Notify client to allow chaining (only count if followed by a valid action)
	local player = game:GetService("Players"):GetPlayerFromCharacter(character)
	if player then
		pcall(function()
			PadTriggered:FireClient(player)
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
