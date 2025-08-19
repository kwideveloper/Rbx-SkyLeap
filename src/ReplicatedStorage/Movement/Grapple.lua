-- Grapple/Hook system: raycast to target and attach a rope; allows pulling and swinging

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Movement.Config)

local Grapple = {}

local characterState = {}
local hookCooldownUntil = setmetatable({}, { __mode = "k" })

local function isPlayerDescendant(instance)
	while instance do
		if instance:IsA("Model") and instance:FindFirstChildOfClass("Humanoid") then
			return game:GetService("Players"):GetPlayerFromCharacter(instance) ~= nil
		end
		instance = instance.Parent
	end
	return false
end

local function ensureRootAttachment(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local a = root:FindFirstChild("GrappleA")
	if not a then
		a = Instance.new("Attachment")
		a.Name = "GrappleA"
		a.Position = Vector3.new(0, 0.5, -0.2)
		a.Parent = root
	end
	return a
end

local function createAnchorAt(position)
	local p = Instance.new("Part")
	p.Name = "GrappleAnchor"
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Position = position
	p.Parent = workspace
	local attach = Instance.new("Attachment")
	attach.Name = "GrappleB"
	attach.Parent = p
	return p, attach
end

local function cleanup(char)
	local st = characterState[char]
	if not st then
		return
	end
	if st.rope then
		st.rope:Destroy()
	end
	if st.anchor and st.anchor.Parent == workspace then
		st.anchor:Destroy()
	end
	if st.force then
		st.force:Destroy()
	end
	characterState[char] = nil
end

function Grapple.stop(character)
	cleanup(character)
	local player = Players.LocalPlayer
	if player then
		local ui = player:FindFirstChildOfClass("PlayerGui") and player.PlayerGui:FindFirstChild("HookUI")
		if ui then
			ui.Enabled = false
		end
	end
	hookCooldownUntil[character] = os.clock() + (Config.HookCooldownSeconds or 1.0)
end

function Grapple.isActive(character)
	return characterState[character] ~= nil
end

-- Returns remaining cooldown seconds (> 0 when on cooldown), or 0 if ready
function Grapple.getCooldownRemaining(character)
	local untilTime = hookCooldownUntil[character]
	if not untilTime then
		return 0
	end
	local remaining = untilTime - os.clock()
	return remaining > 0 and remaining or 0
end

local function validHit(hit)
	if not hit or not hit.Instance then
		return false
	end
	local inst = hit.Instance
	if isPlayerDescendant(inst) then
		return false
	end
	if CollectionService:HasTag(inst, "NoGrapple") then
		return false
	end
	if
		CollectionService:HasTag(inst, (Config.HookTag or "Hookable"))
		or CollectionService:HasTag(inst, "GrapplePoint")
	then
		return true
	end
	return inst:IsA("BasePart") and (inst.CanCollide or inst.CanQuery)
end

local function findTaggedAncestor(inst, tag)
	local current = inst
	while current do
		if current:IsA("BasePart") and CollectionService:HasTag(current, tag) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function buildRaycastParamsForLOS(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local ignore = { character }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character and plr.Character ~= character then
			table.insert(ignore, plr.Character)
		end
	end
	local ignoreTag = Config.HookIgnoreTag or "HookIgnoreLOS"
	for _, inst in ipairs(CollectionService:GetTagged(ignoreTag)) do
		table.insert(ignore, inst)
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function hasClearLineOfSight(character, fromPos, targetPart)
	if not (character and fromPos and targetPart and targetPart:IsDescendantOf(workspace)) then
		return false
	end
	local dir = targetPart.Position - fromPos
	if dir.Magnitude < 0.1 then
		return true
	end
	local params = buildRaycastParamsForLOS(character)
	local hit = workspace:Raycast(fromPos, dir, params)
	if not hit then
		return true
	end
	-- Clear if we hit the target part (or its ancestors)
	local h = hit.Instance
	while h do
		if h == targetPart then
			return true
		end
		h = h.Parent
	end
	return false
end

local function findAutoTarget(character)
	local player = Players.LocalPlayer
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local tag = Config.HookTag or "Hookable"
	local range = Config.HookAutoRange or 90
	local best, bestDist
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		if inst and inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			local d = (inst.Position - root.Position).Magnitude
			if d <= range then
				local requireLOS = (Config.HookRequireLineOfSight ~= false)
				if (not requireLOS) or hasClearLineOfSight(character, root.Position, inst) then
					if not bestDist or d < bestDist then
						best, bestDist = inst, d
					end
				end
			end
		end
	end
	if player and player.PlayerGui then
		local ui = player.PlayerGui:FindFirstChild("HookUI")
		if ui then
			ui.Enabled = best ~= nil
		end
	end
	if best then
		return CFrame.lookAt(root.Position, best.Position), best
	end
	return nil, nil
end

function Grapple.tryFire(character, cameraCFrame)
	if not (Config.GrappleEnabled ~= false) then
		return false
	end
	if Grapple.isActive(character) then
		return false
	end
	if hookCooldownUntil[character] and os.clock() < hookCooldownUntil[character] then
		return false
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local params = buildRaycastParamsForLOS(character)
	local maxDist = Config.GrappleMaxDistance or 120
	-- Require a valid auto target in range; if none, do not fire
	local autoCam, targetPart = findAutoTarget(character)
	if not autoCam then
		return false
	end
	local origin = autoCam.Position
	local dir = autoCam.LookVector * maxDist
	local ray = workspace:Raycast(origin, dir, params)
	if not (ray and validHit(ray)) then
		return false
	end
	local hookTag = Config.HookTag or "Hookable"
	local hookablePart = findTaggedAncestor(ray.Instance, hookTag)
	-- If LOS was blocked and we didn't hit a Hookable, do not fire
	if not hookablePart or (targetPart and hookablePart ~= targetPart) then
		return false
	end
	local attachA = ensureRootAttachment(character)
	if not attachA then
		return false
	end
	local anchor, attachB = createAnchorAt(ray.Position)
	local rope = Instance.new("RopeConstraint")
	rope.Attachment0 = attachA
	rope.Attachment1 = attachB
	rope.Visible = Config.GrappleRopeVisible or false
	rope.Restitution = 0
	rope.WinchEnabled = false
	rope.Visible = Config.GrappleRopeVisible or false
	rope.Length = (attachA.WorldPosition - attachB.WorldPosition).Magnitude
	rope.Thickness = Config.GrappleRopeThickness or 0.06
	rope.Parent = anchor
	local force = Instance.new("VectorForce")
	force.Force = Vector3.new()
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Attachment0 = attachA
	force.Parent = attachA
	local maxApproachSpeed = (hookablePart and tonumber(hookablePart:GetAttribute("HookMaxApproachSpeed")))
	if not maxApproachSpeed or maxApproachSpeed <= 0 then
		maxApproachSpeed = Config.HookMaxApproachSpeed or 120
	end
	local autoDetachDistance = (hookablePart and tonumber(hookablePart:GetAttribute("HookAutoDetachDistance")))
	if not autoDetachDistance or autoDetachDistance <= 0 then
		autoDetachDistance = Config.HookAutoDetachDistance or 10
	end
	characterState[character] = {
		anchor = anchor,
		rope = rope,
		force = force,
		reel = 0,
		targetPart = hookablePart,
		maxApproachSpeed = maxApproachSpeed,
		autoDetachDistance = autoDetachDistance,
	}
	local player = Players.LocalPlayer
	if player and player.PlayerGui then
		local ui = player.PlayerGui:FindFirstChild("HookUI")
		if ui then
			ui.Enabled = true
		end
	end
	return true
end

function Grapple.update(character, dt)
	local st = characterState[character]
	if not st then
		findAutoTarget(character)
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not (root and hum and st.rope and st.anchor) then
		cleanup(character)
		return
	end
	local pullStrength = Config.GrapplePullForce or 6000
	local reelSpeed = Config.GrappleReelSpeed or 28
	local desiredLen = (st.force.Attachment0.WorldPosition - st.anchor.Position).Magnitude
	if st.reel ~= 0 then
		desiredLen = math.max(2, desiredLen + (st.reel * reelSpeed * -dt))
	end
	st.rope.Length = math.max(0.5, desiredLen - 0.05)
	local toAnchor = (st.anchor.Position - root.Position)
	local dist = toAnchor.Magnitude
	local autoDetachDistance = (st.autoDetachDistance or Config.HookAutoDetachDistance or 10)
	if dist <= autoDetachDistance then
		Grapple.stop(character)
		return
	end
	local dir = toAnchor.Unit
	local currentVel = root.AssemblyLinearVelocity
	local speedAlong = dir:Dot(currentVel)
	local maxApproachSpeed = (st.maxApproachSpeed or Config.HookMaxApproachSpeed or 120)
	if speedAlong >= maxApproachSpeed then
		st.force.Force = Vector3.new()
	else
		st.force.Force = dir * pullStrength
	end
end

function Grapple.setReel(character, direction)
	local st = characterState[character]
	if not st then
		return
	end
	st.reel = direction -- -1 reel in, +1 reel out, 0 none
end

Players.PlayerRemoving:Connect(function(plr)
	if plr.Character then
		cleanup(plr.Character)
	end
end)

return Grapple
