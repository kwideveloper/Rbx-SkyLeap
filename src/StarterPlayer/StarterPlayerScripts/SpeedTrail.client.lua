-- Client trail that scales with speed and changes color/transparency

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Movement.Config)

local player = Players.LocalPlayer

local character
local trail
local attachA
local attachB
local handTrailL
local handTrailR
local handA_L
local handB_L
local handA_R
local handB_R

local OtherTrailStates = {}

local function getTrailBodyPart(char)
	local preferred = Config.TrailBodyPartName or "UpperTorso"
	local part = char:FindFirstChild(preferred)
		or char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("Torso")
		or char:FindFirstChild("HumanoidRootPart")
	return part
end

local function ensureAttachments(char)
	local part = getTrailBodyPart(char)
	if not part then
		return nil
	end
	local a = part:FindFirstChild(Config.TrailAttachmentNameA or "TrailA")
	local b = part:FindFirstChild(Config.TrailAttachmentNameB or "TrailB")
	if not a then
		a = Instance.new("Attachment")
		a.Name = Config.TrailAttachmentNameA or "TrailA"
		a.Position = Vector3.new(0, 0.9, -0.5)
		a.Parent = part
	end
	if not b then
		b = Instance.new("Attachment")
		b.Name = Config.TrailAttachmentNameB or "TrailB"
		b.Position = Vector3.new(0, -0.9, 0.5)
		b.Parent = part
	end
	return a, b
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
	return Color3.new(lerp(c1.R, c2.R, t), lerp(c1.G, c2.G, t), lerp(c1.B, c2.B, t))
end

local function destroyOtherState(char)
	local st = OtherTrailStates[char]
	if not st then
		return
	end
	if st.trail then
		st.trail:Destroy()
	end
	if st.handTrailL then
		st.handTrailL:Destroy()
	end
	if st.handTrailR then
		st.handTrailR:Destroy()
	end
	OtherTrailStates[char] = nil
end

local function setupOther(char)
	if not (Config.TrailEnabled ~= false) then
		return
	end
	if not char or not char.Parent then
		return
	end
	if Players.LocalPlayer.Character == char then
		return
	end
	if OtherTrailStates[char] then
		return
	end
	local a, b = ensureAttachments(char)
	if not (a and b) then
		return
	end
	local tr = Instance.new("Trail")
	tr.Attachment0 = a
	tr.Attachment1 = b
	tr.Enabled = true
	tr.LightEmission = 0.75
	tr.Lifetime = Config.TrailLifeTime or 0.25
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Config.TrailBaseTransparency or 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	tr.Color = ColorSequence.new(Config.TrailColorMin or Color3.fromRGB(90, 170, 255))
	tr.WidthScale = NumberSequence.new(Config.TrailWidth or 0.3)
	tr.Parent = char

	local handL, handR
	if Config.TrailHandsEnabled then
		local left = char:FindFirstChild("LeftHand")
			or char:FindFirstChild("LeftLowerArm")
			or char:FindFirstChild("Left Arm")
		local right = char:FindFirstChild("RightHand")
			or char:FindFirstChild("RightLowerArm")
			or char:FindFirstChild("Right Arm")
		if left and right then
			local handA_L = left:FindFirstChild("TrailA") or Instance.new("Attachment")
			handA_L.Name = "TrailA"
			handA_L.Position = Vector3.new(0, 0.2, 0)
			handA_L.Parent = left
			local handB_L = left:FindFirstChild("TrailB") or Instance.new("Attachment")
			handB_L.Name = "TrailB"
			handB_L.Position = Vector3.new(0, -0.2, 0)
			handB_L.Parent = left
			handL = Instance.new("Trail")
			handL.Attachment0 = handA_L
			handL.Attachment1 = handB_L
			handL.LightEmission = tr.LightEmission
			handL.Lifetime = (tr.Lifetime or (Config.TrailLifeTime or 0.25)) * (Config.TrailHandsLifetimeFactor or 0.5)
			handL.Transparency = tr.Transparency
			handL.Color = tr.Color
			handL.WidthScale = NumberSequence.new(
				(Config.TrailWidth or 0.3) * (Config.TrailHandsScale or 0.6) * (Config.TrailHandsSizeFactor or 1.15)
			)
			handL.Enabled = true
			handL.Parent = left
			local handA_R = right:FindFirstChild("TrailA") or Instance.new("Attachment")
			handA_R.Name = "TrailA"
			handA_R.Position = Vector3.new(0, 0.2, 0)
			handA_R.Parent = right
			local handB_R = right:FindFirstChild("TrailB") or Instance.new("Attachment")
			handB_R.Name = "TrailB"
			handB_R.Position = Vector3.new(0, -0.2, 0)
			handB_R.Parent = right
			handR = Instance.new("Trail")
			handR.Attachment0 = handA_R
			handR.Attachment1 = handB_R
			handR.LightEmission = tr.LightEmission
			handR.Lifetime = (tr.Lifetime or (Config.TrailLifeTime or 0.25)) * (Config.TrailHandsLifetimeFactor or 0.5)
			handR.Transparency = tr.Transparency
			handR.Color = tr.Color
			handR.WidthScale = NumberSequence.new(
				(Config.TrailWidth or 0.3) * (Config.TrailHandsScale or 0.6) * (Config.TrailHandsSizeFactor or 1.15)
			)
			handR.Enabled = true
			handR.Parent = right
		end
	end

	OtherTrailStates[char] = { trail = tr, handTrailL = handL, handTrailR = handR }

	char.AncestryChanged:Connect(function(_, parent)
		if not parent then
			destroyOtherState(char)
		end
	end)
end

-- Setup for other players present at start
for _, plr in ipairs(Players:GetPlayers()) do
	if plr ~= player then
		if plr.Character then
			setupOther(plr.Character)
		end
		plr.CharacterAdded:Connect(function(char)
			setupOther(char)
		end)
		plr.CharacterRemoving:Connect(function(char)
			destroyOtherState(char)
		end)
	end
end

-- Listen for players joining later
Players.PlayerAdded:Connect(function(plr)
	if plr == player then
		return
	end
	plr.CharacterAdded:Connect(function(char)
		setupOther(char)
	end)
	plr.CharacterRemoving:Connect(function(char)
		destroyOtherState(char)
	end)
end)

local function setup(char)
	character = char
	if not (Config.TrailEnabled ~= false) then
		return
	end
	attachA, attachB = ensureAttachments(char)
	if not (attachA and attachB) then
		return
	end
	if trail then
		trail:Destroy()
		trail = nil
	end
	trail = Instance.new("Trail")
	trail.Attachment0 = attachA
	trail.Attachment1 = attachB
	trail.Enabled = true
	trail.LightEmission = 0.75
	trail.Lifetime = Config.TrailLifeTime or 0.25
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Config.TrailBaseTransparency or 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = ColorSequence.new(Config.TrailColorMin or Color3.fromRGB(90, 170, 255))
	trail.WidthScale = NumberSequence.new(Config.TrailWidth or 0.3)
	trail.Parent = char

	-- Optional hand trails
	if Config.TrailHandsEnabled then
		local left = char:FindFirstChild("LeftHand")
			or char:FindFirstChild("LeftLowerArm")
			or char:FindFirstChild("Left Arm")
		local right = char:FindFirstChild("RightHand")
			or char:FindFirstChild("RightLowerArm")
			or char:FindFirstChild("Right Arm")
		if left and right then
			-- Left
			handA_L = left:FindFirstChild("TrailA") or Instance.new("Attachment")
			handA_L.Name = "TrailA"
			handA_L.Position = Vector3.new(0, 0.2, 0)
			handA_L.Parent = left
			handB_L = left:FindFirstChild("TrailB") or Instance.new("Attachment")
			handB_L.Name = "TrailB"
			handB_L.Position = Vector3.new(0, -0.2, 0)
			handB_L.Parent = left
			if handTrailL then
				handTrailL:Destroy()
			end
			handTrailL = Instance.new("Trail")
			handTrailL.Attachment0 = handA_L
			handTrailL.Attachment1 = handB_L
			handTrailL.LightEmission = trail.LightEmission
			handTrailL.Lifetime = (trail.Lifetime or (Config.TrailLifeTime or 0.25))
				* (Config.TrailHandsLifetimeFactor or 0.5)
			handTrailL.Transparency = trail.Transparency
			handTrailL.Color = trail.Color
			handTrailL.WidthScale = NumberSequence.new(
				(Config.TrailWidth or 0.3) * (Config.TrailHandsScale or 0.6) * (Config.TrailHandsSizeFactor or 1.15)
			)
			handTrailL.Enabled = true
			handTrailL.Parent = left
			-- Right
			handA_R = right:FindFirstChild("TrailA") or Instance.new("Attachment")
			handA_R.Name = "TrailA"
			handA_R.Position = Vector3.new(0, 0.2, 0)
			handA_R.Parent = right
			handB_R = right:FindFirstChild("TrailB") or Instance.new("Attachment")
			handB_R.Name = "TrailB"
			handB_R.Position = Vector3.new(0, -0.2, 0)
			handB_R.Parent = right
			if handTrailR then
				handTrailR:Destroy()
			end
			handTrailR = Instance.new("Trail")
			handTrailR.Attachment0 = handA_R
			handTrailR.Attachment1 = handB_R
			handTrailR.LightEmission = trail.LightEmission
			handTrailR.Lifetime = (trail.Lifetime or (Config.TrailLifeTime or 0.25))
				* (Config.TrailHandsLifetimeFactor or 0.5)
			handTrailR.Transparency = trail.Transparency
			handTrailR.Color = trail.Color
			handTrailR.WidthScale = NumberSequence.new(
				(Config.TrailWidth or 0.3) * (Config.TrailHandsScale or 0.6) * (Config.TrailHandsSizeFactor or 1.15)
			)
			handTrailR.Enabled = true
			handTrailR.Parent = right
		end
	end
end

player.CharacterAdded:Connect(setup)
if player.Character then
	setup(player.Character)
end

RunService.RenderStepped:Connect(function()
	-- Update local character
	if trail and character then
		local root = character:FindFirstChild("HumanoidRootPart")
		local hum = character:FindFirstChildOfClass("Humanoid")
		if root and hum then
			local speed = root.AssemblyLinearVelocity.Magnitude
			local sMin = Config.TrailSpeedMin or 10
			local sMax = Config.TrailSpeedMax or 80
			local t = 0
			if sMax > sMin then
				t = math.clamp((speed - sMin) / (sMax - sMin), 0, 1)
			end
			local alpha = lerp(Config.TrailBaseTransparency or 0.6, Config.TrailMinTransparency or 0.15, t)
			trail.Transparency =
				NumberSequence.new({ NumberSequenceKeypoint.new(0, alpha), NumberSequenceKeypoint.new(1, 1) })
			local cMin = Config.TrailColorMin or Color3.fromRGB(90, 170, 255)
			local cMax = Config.TrailColorMax or Color3.fromRGB(255, 100, 180)
			trail.Color = ColorSequence.new(lerpColor(cMin, cMax, t))
			trail.WidthScale = NumberSequence.new(lerp(Config.TrailWidth or 0.3, (Config.TrailWidth or 0.3) * 1.8, t))
			local widthHand = lerp(
				(Config.TrailWidth or 0.3) * (Config.TrailHandsScale or 0.6) * (Config.TrailHandsSizeFactor or 1.15),
				(Config.TrailWidth or 0.3)
					* (Config.TrailHandsScale or 0.6)
					* (Config.TrailHandsSizeFactor or 1.15)
					* 1.6,
				t
			)
			local alphaHand =
				lerp(Config.TrailBaseTransparency or 0.6, math.max((Config.TrailMinTransparency or 0.15), 0.25), t)
			if handTrailL then
				handTrailL.WidthScale = NumberSequence.new(widthHand)
				handTrailL.Transparency =
					NumberSequence.new({ NumberSequenceKeypoint.new(0, alphaHand), NumberSequenceKeypoint.new(1, 1) })
				handTrailL.Color = ColorSequence.new(lerpColor(cMin, cMax, t))
			end
			if handTrailR then
				handTrailR.WidthScale = NumberSequence.new(widthHand)
				handTrailR.Transparency =
					NumberSequence.new({ NumberSequenceKeypoint.new(0, alphaHand), NumberSequenceKeypoint.new(1, 1) })
				handTrailR.Color = ColorSequence.new(lerpColor(cMin, cMax, t))
			end
		end
	end
	-- Update other players
	local sMin = Config.TrailSpeedMin or 10
	local sMax = Config.TrailSpeedMax or 80
	local cMin = Config.TrailColorMin or Color3.fromRGB(90, 170, 255)
	local cMax = Config.TrailColorMax or Color3.fromRGB(255, 100, 180)
	for char, st in pairs(OtherTrailStates) do
		if st and st.trail and char.Parent then
			local root = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildOfClass("Humanoid")
			if root and hum then
				local speed = root.AssemblyLinearVelocity.Magnitude
				local t = 0
				if sMax > sMin then
					t = math.clamp((speed - sMin) / (sMax - sMin), 0, 1)
				end
				local alpha = lerp(Config.TrailBaseTransparency or 0.6, Config.TrailMinTransparency or 0.15, t)
				st.trail.Transparency =
					NumberSequence.new({ NumberSequenceKeypoint.new(0, alpha), NumberSequenceKeypoint.new(1, 1) })
				st.trail.Color = ColorSequence.new(lerpColor(cMin, cMax, t))
				st.trail.WidthScale =
					NumberSequence.new(lerp(Config.TrailWidth or 0.3, (Config.TrailWidth or 0.3) * 1.8, t))
				local widthHand = lerp(
					(Config.TrailWidth or 0.3) * (Config.TrailHandsScale or 0.6) * (Config.TrailHandsSizeFactor or 1.15),
					(Config.TrailWidth or 0.3)
						* (Config.TrailHandsScale or 0.6)
						* (Config.TrailHandsSizeFactor or 1.15)
						* 1.6,
					t
				)
				local alphaHand =
					lerp(Config.TrailBaseTransparency or 0.6, math.max((Config.TrailMinTransparency or 0.15), 0.25), t)
				if st.handTrailL then
					st.handTrailL.WidthScale = NumberSequence.new(widthHand)
					st.handTrailL.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, alphaHand),
						NumberSequenceKeypoint.new(1, 1),
					})
					st.handTrailL.Color = ColorSequence.new(lerpColor(cMin, cMax, t))
				end
				if st.handTrailR then
					st.handTrailR.WidthScale = NumberSequence.new(widthHand)
					st.handTrailR.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, alphaHand),
						NumberSequenceKeypoint.new(1, 1),
					})
					st.handTrailR.Color = ColorSequence.new(lerpColor(cMin, cMax, t))
				end
			end
		end
	end
end)
