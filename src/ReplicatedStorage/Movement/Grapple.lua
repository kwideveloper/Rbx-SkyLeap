-- Grapple/Hook system: raycast to target and attach a rope; allows pulling and swinging

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Movement.Config)

local Grapple = {}

local characterState = {}

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
end

function Grapple.isActive(character)
	return characterState[character] ~= nil
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
	-- Allow explicit grapple points and lianas even if non-collidable
	if CollectionService:HasTag(inst, "GrapplePoint") or CollectionService:HasTag(inst, "Liana") then
		return true
	end
	return inst:IsA("BasePart") and (inst.CanCollide or inst.CanQuery)
end

function Grapple.tryFire(character, cameraCFrame)
	if not (Config.GrappleEnabled ~= false) then
		return false
	end
	if Grapple.isActive(character) then
		return false
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local maxDist = Config.GrappleMaxDistance or 120
	local origin = cameraCFrame.Position
	local dir = cameraCFrame.LookVector * maxDist
	local ray = workspace:Raycast(origin, dir, params)
	if not (ray and validHit(ray)) then
		-- Sweep small yaw angles to catch nearby lianas/points
		local found
		for yaw = -20, 20, 10 do
			local rot = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(yaw))
			local sweepDir = (rot:VectorToWorldSpace(cameraCFrame.LookVector)) * maxDist
			local try = workspace:Raycast(origin, sweepDir, params)
			if try and validHit(try) then
				ray = try
				found = true
				break
			end
		end
		if not found then
			return false
		end
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
	-- Make rope behave taut by using high stiffness and no slack
	rope.Restitution = 0
	rope.WinchEnabled = false
	rope.Visible = Config.GrappleRopeVisible or false
	-- Initialize length exactly to current distance to avoid visible slack
	rope.Length = (attachA.WorldPosition - attachB.WorldPosition).Magnitude
	rope.Thickness = Config.GrappleRopeThickness or 0.06
	rope.Parent = anchor
	local force = Instance.new("VectorForce")
	force.Force = Vector3.new()
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Attachment0 = attachA
	force.Parent = attachA
	characterState[character] = {
		anchor = anchor,
		rope = rope,
		force = force,
		reel = 0,
	}
	return true
end

function Grapple.update(character, dt)
	local st = characterState[character]
	if not st then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not (root and hum and st.rope and st.anchor) then
		cleanup(character)
		return
	end
	-- Keep rope taut every frame by matching its length to the current distance (minus a tiny epsilon)
	local pullStrength = Config.GrapplePullForce or 6000
	local reelSpeed = Config.GrappleReelSpeed or 28
	if Players.LocalPlayer and Players.LocalPlayer:GetMouse() then
		-- no per-frame input used here; controller will adjust st.reel
	end
	-- Compute ideal taut length
	local desiredLen = (st.force.Attachment0.WorldPosition - st.anchor.Position).Magnitude
	-- Apply reel input first (shorten/lengthen), then clamp to near taut
	if st.reel ~= 0 then
		desiredLen = math.max(2, desiredLen + (st.reel * reelSpeed * -dt))
	end
	st.rope.Length = math.max(0.5, desiredLen - 0.05)
	-- Pull along rope direction slightly to keep tension
	local toAnchor = (st.anchor.Position - root.Position)
	local dist = toAnchor.Magnitude
	if dist < 0.5 then
		Grapple.stop(character)
		return
	end
	local dir = toAnchor.Unit
	st.force.Force = dir * pullStrength
end

function Grapple.setReel(character, direction)
	local st = characterState[character]
	if not st then
		return
	end
	st.reel = direction -- -1 reel in, +1 reel out, 0 none
end

-- Auto-clean on character removal
Players.PlayerRemoving:Connect(function(plr)
	if plr.Character then
		cleanup(plr.Character)
	end
end)

return Grapple
