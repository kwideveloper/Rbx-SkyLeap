-- Shows the player's body in first-person when zoomed fully in, without forcing first-person.
-- Keeps free camera zoom; only overrides LocalTransparencyModifier while at min zoom.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Movement.Config)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Helper: classify torso/neck/upper-body accessories we want to hide in FP
local function isTorsoAccessoryType(t: Enum.AccessoryType?): boolean
	if t == nil then
		return false
	end
	return t == Enum.AccessoryType.Jacket
		or t == Enum.AccessoryType.Shirt
		or t == Enum.AccessoryType.Sweater
		or t == Enum.AccessoryType.DressSkirt
		or t == Enum.AccessoryType.Neck
		or t == Enum.AccessoryType.Shoulder
		or t == Enum.AccessoryType.Front
		or t == Enum.AccessoryType.Back
		or t == Enum.AccessoryType.Waist
end

local character: Model? = nil
local humanoid: Humanoid? = nil

type Connection = RBXScriptConnection

local state = {
	parts = {} :: { BasePart },
	transparencyConns = {} :: { [BasePart]: { Connection } },
	isShowingBody = false,
	charConns = {} :: { Connection },
	appliedFPZ = false,
	headPart = nil :: BasePart?,
	headDecals = {} :: { Decal },
	headOrigDecalTransparency = {} :: { [Decal]: number },
	headHidden = false,
	headAttachmentNames = {} :: { [string]: boolean },
	headAccessoryParts = {} :: { BasePart },
	headAccessorySet = {} :: { [BasePart]: boolean },
	otherAccessoryParts = {} :: { BasePart },
	otherWrapLayers = {} :: { WrapLayer },
	otherWrapOrigEnabled = {} :: { [WrapLayer]: boolean },
	headAccessoryAccs = {} :: { [Accessory]: boolean },
	headWrapLayers = {} :: { WrapLayer },
	headWrapOrigEnabled = {} :: { [WrapLayer]: boolean },
	limbAccessoryParts = {} :: { BasePart },
	prevZoomedIn = false,
}

local function disconnectConnections(connsTbl: { [any]: { Connection } } | { Connection })
	if connsTbl then
		if typeof(connsTbl) == "table" then
			for key, value in pairs(connsTbl) do
				if typeof(value) == "table" then
					for _, c in ipairs(value) do
						pcall(function()
							if c and c.Disconnect then
								c:Disconnect()
							end
						end)
					end
				elseif typeof(value) == "Instance" or typeof(value) == "RBXScriptConnection" then
					pcall(function()
						if (value :: any).Disconnect then
							(value :: any):Disconnect()
						end
					end)
				end
				connsTbl[key] = nil
			end
		end
	end
end

local function collectCharacterParts(char: Model): { BasePart }
	local parts = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			-- Build limb-only set if configured
			local include = false
			if Config.FirstPersonShowWholeBody then
				include = (d.Name ~= "Head") and (d:FindFirstAncestorOfClass("Accessory") == nil)
			else
				-- Limbs-only: include any limb segment (R6/R15) and exclude accessories
				local n = d.Name
				local isLimb = (
					string.find(n, "Arm")
					or string.find(n, "Hand")
					or string.find(n, "Leg")
					or string.find(n, "Foot")
				) ~= nil
				if isLimb and (d:FindFirstAncestorOfClass("Accessory") == nil) then
					include = true
				end
			end
			if include then
				table.insert(parts, d)
			end
		end
	end
	return parts
end

local function clearPartListeners()
	for part, conns in pairs(state.transparencyConns) do
		for _, c in ipairs(conns) do
			pcall(function()
				if c and c.Disconnect then
					c:Disconnect()
				end
			end)
		end
		state.transparencyConns[part] = nil
	end
end

local function collectHeadInfo(char: Model)
	state.headPart = char:FindFirstChild("Head") :: BasePart?
	state.headDecals = {}
	state.headOrigDecalTransparency = {}
	state.headAttachmentNames = {}
	if state.headPart then
		-- Record all attachment names on the head to match accessory handles
		for _, att in ipairs(state.headPart:GetChildren()) do
			if att:IsA("Attachment") then
				state.headAttachmentNames[att.Name] = true
			end
		end
		for _, d in ipairs(state.headPart:GetDescendants()) do
			if d:IsA("Decal") then
				table.insert(state.headDecals, d)
				state.headOrigDecalTransparency[d] = d.Transparency
			end
		end
	end
end

local function collectHeadAccessoryParts(char: Model)
	state.headAccessoryParts = {}
	state.headAccessorySet = {}
	state.headAccessoryAccs = {}
	state.headWrapLayers = {}
	state.headWrapOrigEnabled = {}
	if not state.headAttachmentNames then
		return
	end
	for _, acc in ipairs(char:GetChildren()) do
		if acc:IsA("Accessory") then
			-- Only hide specific accessory categories for head
			local accTypeOk = false
			pcall(function()
				local t = acc.AccessoryType
				if
					t == Enum.AccessoryType.Hat
					or t == Enum.AccessoryType.Hair
					or t == Enum.AccessoryType.Face
					or t == Enum.AccessoryType.Eyelash
					or t == Enum.AccessoryType.Eyebrow
				then
					accTypeOk = true
				end
			end)
			if not accTypeOk then
				continue
			end
			local handle = acc:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local isHeadAttached = false
				-- 1) Attachment name match
				for _, att in ipairs(handle:GetChildren()) do
					if att:IsA("Attachment") and state.headAttachmentNames[att.Name] then
						isHeadAttached = true
						break
					end
				end
				-- 2) Weld link to head
				if not isHeadAttached and state.headPart then
					for _, j in ipairs(handle:GetDescendants()) do
						if j:IsA("Weld") or j:IsA("Motor6D") then
							local p0 = (j :: any).Part0
							local p1 = (j :: any).Part1
							if p0 == state.headPart or p1 == state.headPart then
								isHeadAttached = true
								break
							end
						elseif j:IsA("WeldConstraint") then
							local p0 = (j :: any).Part0
							local p1 = (j :: any).Part1
							if p0 == state.headPart or p1 == state.headPart then
								isHeadAttached = true
								break
							end
						end
						if isHeadAttached then
							break
						end
					end
				end
				-- 3) Distance heuristic fallback
				if not isHeadAttached and state.headPart then
					local maxDist = (Config.FirstPersonHeadAccessoryMaxDistance ~= nil)
							and Config.FirstPersonHeadAccessoryMaxDistance
						or 3
					local ok, dist = pcall(function()
						return (handle.Position - state.headPart.Position).Magnitude
					end)
					if ok and dist <= maxDist then
						isHeadAttached = true
					end
				end
				if isHeadAttached then
					state.headAccessoryAccs[acc] = true
					-- Collect all BaseParts under this accessory to hide/show locally
					for _, d in ipairs(acc:GetDescendants()) do
						if d:IsA("BasePart") then
							table.insert(state.headAccessoryParts, d)
							state.headAccessorySet[d] = true
						end
					end
				end
			end
		end
	end
	-- Collect WrapLayers under these accessories (layered clothing)
	for acc, _ in pairs(state.headAccessoryAccs) do
		for _, d in ipairs(acc:GetDescendants()) do
			if d:IsA("WrapLayer") then
				table.insert(state.headWrapLayers, d)
				state.headWrapOrigEnabled[d] = d.Enabled
			end
		end
	end
end

local function collectOtherAccessoryParts(char: Model)
	state.otherAccessoryParts = {}
	state.otherWrapLayers = {}
	state.otherWrapOrigEnabled = {}
	for _, acc in ipairs(char:GetChildren()) do
		if acc:IsA("Accessory") then
			local accType: Enum.AccessoryType? = nil
			pcall(function()
				accType = acc.AccessoryType
			end)
			local shouldHide = isTorsoAccessoryType(accType)
			if shouldHide then
				for _, d in ipairs(acc:GetDescendants()) do
					if d:IsA("BasePart") and not state.headAccessorySet[d] then
						table.insert(state.otherAccessoryParts, d)
					end
					if d:IsA("WrapLayer") and not state.headAccessoryAccs[acc] then
						table.insert(state.otherWrapLayers, d)
						state.otherWrapOrigEnabled[d] = d.Enabled
					end
				end
			end
		end
	end
end

local function collectLimbAccessoryParts(char: Model)
	state.limbAccessoryParts = {}
	local limbKeywords = { "Hand", "Arm", "Foot", "Leg" }
	for _, acc in ipairs(char:GetChildren()) do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local attachesToLimb = false
				for _, att in ipairs(handle:GetChildren()) do
					if att:IsA("Attachment") then
						for _, key in ipairs(limbKeywords) do
							if string.find(att.Name, key) then
								attachesToLimb = true
								break
							end
						end
					end
					if attachesToLimb then
						for _, d in ipairs(acc:GetDescendants()) do
							if d:IsA("BasePart") then
								table.insert(state.limbAccessoryParts, d)
							end
						end
					end
				end
			end
		end
	end
end

local function updateHeadVisibility(hide: boolean)
	if not state.headPart then
		return
	end
	if hide then
		if not state.headHidden then
			-- Make head invisible locally; also hide face decals locally
			state.headPart.LocalTransparencyModifier = 1
			for _, decal in ipairs(state.headDecals) do
				-- Store original if not yet stored
				if state.headOrigDecalTransparency[decal] == nil then
					state.headOrigDecalTransparency[decal] = decal.Transparency
				end
				decal.Transparency = 1
			end
			state.headHidden = true
		end
	else
		if state.headHidden then
			-- Restore visibility
			state.headPart.LocalTransparencyModifier = 0
			for _, decal in ipairs(state.headDecals) do
				local orig = state.headOrigDecalTransparency[decal]
				if typeof(orig) == "number" then
					decal.Transparency = orig
				end
			end
			state.headHidden = false
		end
	end
end

local function updateHeadAccessoriesVisibility(hide: boolean)
	for _, part in ipairs(state.headAccessoryParts) do
		if hide then
			part.LocalTransparencyModifier = 1
		else
			part.LocalTransparencyModifier = 0
		end
	end
end

local function updateOtherAccessoriesVisibility(zoomedIn: boolean)
	for _, part in ipairs(state.otherAccessoryParts) do
		-- Hide only torso/neck/torso-adjacent accessories in first-person
		part.LocalTransparencyModifier = zoomedIn and 1 or 0
	end
end

local function updateLimbAccessoriesVisibility(zoomedIn: boolean)
	for _, part in ipairs(state.limbAccessoryParts) do
		if zoomedIn then
			part.LocalTransparencyModifier = part.Transparency
		else
			part.LocalTransparencyModifier = 0
		end
	end
end

local function ensurePartListeners(parts: { BasePart })
	clearPartListeners()
	for _, part in ipairs(parts) do
		state.transparencyConns[part] = {}
		-- Keep LocalTransparencyModifier equal to actual Transparency while visible
		local c1 = part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
			if state.isShowingBody then
				part.LocalTransparencyModifier = part.Transparency
			end
		end)
		local c2 = part:GetPropertyChangedSignal("Transparency"):Connect(function()
			if state.isShowingBody then
				part.LocalTransparencyModifier = part.Transparency
			end
		end)
		table.insert(state.transparencyConns[part], c1)
		table.insert(state.transparencyConns[part], c2)
	end
end

local function setBodyVisible(visible: boolean)
	if state.isShowingBody == visible then
		return
	end
	state.isShowingBody = visible
	for _, part in ipairs(state.parts) do
		if visible then
			part.LocalTransparencyModifier = part.Transparency
		else
			part.LocalTransparencyModifier = 0
		end
	end
	if visible then
		ensurePartListeners(state.parts)
	else
		clearPartListeners()
	end
end

local function isZoomedFullyIn(): boolean
	if not camera then
		return false
	end
	local distance = (camera.Focus.Position - camera.CFrame.Position).Magnitude
	local threshold = (player.CameraMinZoomDistance or 0.5) + 0.05
	return distance <= threshold
end

local function onCharacterAdded(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid")

	-- Refresh character-bound connections
	disconnectConnections(state.charConns)
	state.charConns = {}

	-- Rebuild tracked parts and set initial visibility
	state.parts = collectCharacterParts(char)
	collectHeadInfo(char)
	collectHeadAccessoryParts(char)
	collectOtherAccessoryParts(char)
	collectLimbAccessoryParts(char)
	setBodyVisible(isZoomedFullyIn())

	-- Track new/removed parts
	local conAdded = char.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") and desc.Name ~= "Head" then
			table.insert(state.parts, desc)
			if state.isShowingBody then
				desc.LocalTransparencyModifier = desc.Transparency
			end
			ensurePartListeners(state.parts)
		end
		-- Track decals added under head for local hiding in FP
		if desc:IsA("Decal") and state.headPart and desc:IsDescendantOf(state.headPart) then
			state.headOrigDecalTransparency[desc] = desc.Transparency
			table.insert(state.headDecals, desc)
		end
		-- Track new accessories or attachments that may tie to head
		if desc:IsA("Accessory") or (desc:IsA("Attachment") and desc.Parent and desc.Parent:IsA("BasePart")) then
			collectHeadAccessoryParts(char)
			collectOtherAccessoryParts(char)
			collectLimbAccessoryParts(char)
		end
	end)
	local conRemoving = char.DescendantRemoving:Connect(function(desc)
		if desc:IsA("BasePart") then
			for i = #state.parts, 1, -1 do
				if state.parts[i] == desc then
					table.remove(state.parts, i)
					break
				end
			end
			state.transparencyConns[desc] = nil
		end
		if desc == state.headPart then
			state.headPart = nil
			state.headDecals = {}
			state.headOrigDecalTransparency = {}
			state.headHidden = false
		end
		if desc:IsA("Accessory") then
			collectHeadAccessoryParts(char)
			collectOtherAccessoryParts(char)
		end
	end)
	state.charConns = { conAdded, conRemoving }

	-- Prevent vehicle seats from hijacking camera
	if camera then
		camera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
			local subj = camera.CameraSubject
			if subj and subj:IsA("VehicleSeat") and humanoid then
				camera.CameraSubject = humanoid
			end
		end)
	end
end

-- Character lifecycle
do
	local char = player.Character or player.CharacterAdded:Wait()
	onCharacterAdded(char)
	player.CharacterAdded:Connect(onCharacterAdded)
end

-- Per-frame: toggle body visibility based on zoom level
RunService.RenderStepped:Connect(function()
	local zoomedIn = isZoomedFullyIn()
	setBodyVisible(zoomedIn)
	updateHeadVisibility(zoomedIn)
	updateHeadAccessoriesVisibility(zoomedIn)
	updateOtherAccessoriesVisibility(zoomedIn)
	updateLimbAccessoriesVisibility(zoomedIn)

	-- One-time logs on transition into/out of max zoom to verify behavior
	if camera then
		local distance = (camera.Focus.Position - camera.CFrame.Position).Magnitude
		local threshold = (player.CameraMinZoomDistance or 0.5) + 0.05
		if zoomedIn ~= state.prevZoomedIn then
			if zoomedIn then
				-- Refresh head + accessories on transition, then hide with logs
				if character then
					collectHeadInfo(character)
					collectHeadAccessoryParts(character)
				end
				updateHeadVisibility(true)
				updateHeadAccessoriesVisibility(true)
				local shown = 0
				for _, p in ipairs(state.headAccessoryParts) do
					local acc = p:FindFirstAncestorOfClass("Accessory")
					shown += 1
					if shown >= 5 then
						break
					end
				end
			end
			state.prevZoomedIn = zoomedIn
		end
	end

	-- Nudge camera slightly forward only when fully zoomed in by adjusting Humanoid.CameraOffset.Z
	-- This coexists with our other systems that tween Y (we preserve their Y each frame).
	if humanoid then
		local currentOffset = humanoid.CameraOffset
		if zoomedIn then
			local fpZ = (Config.FirstPersonForwardOffsetZ ~= nil) and Config.FirstPersonForwardOffsetZ or -1
			if math.abs((currentOffset.Z - fpZ)) > 1e-3 or not state.appliedFPZ then
				humanoid.CameraOffset = Vector3.new(0, currentOffset.Y, fpZ)
				state.appliedFPZ = true
			end
		else
			if state.appliedFPZ then
				-- restore Z to 0, keep Y from other systems
				humanoid.CameraOffset = Vector3.new(0, currentOffset.Y, 0)
				state.appliedFPZ = false
			end
		end
	end
end)
