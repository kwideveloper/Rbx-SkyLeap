local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Movement.Config)
local Grapple = require(ReplicatedStorage.Movement.Grapple)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function getHookUI()
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	return pg:FindFirstChild("HookUI")
end

local function ensureArrow()
	local hookUI = getHookUI()
	if not hookUI then
		return nil
	end
	local arrow = hookUI:FindFirstChild("Indicator")
	if arrow and arrow:IsA("GuiObject") then
		return arrow
	end
	return nil
end

local function isInRange(character, part)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and part and part:IsA("BasePart") and part:IsDescendantOf(workspace)) then
		return false
	end
	local range = Config.HookAutoRange or 90
	return (part.Position - root.Position).Magnitude <= range
end

local function getBestTargetInRange(character)
	local best, bestDist
	for _, part in ipairs(CollectionService:GetTagged(Config.HookTag or "Hookable")) do
		if isInRange(character, part) then
			local d = (part.Position - character.HumanoidRootPart.Position).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = part, d
			end
		end
	end
	return best
end

local function getOriginalColor(arrow: GuiObject)
	local saved = arrow:GetAttribute("_ArrowOrigColor3")
	if typeof(saved) == "Color3" then
		return saved
	end
	local c = arrow.BackgroundColor3
	arrow:SetAttribute("_ArrowOrigColor3", c)
	return c
end

local function setArrowState(arrow: GuiObject, isCooldown: boolean)
	if isCooldown then
		arrow.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	else
		arrow.BackgroundColor3 = getOriginalColor(arrow)
	end
end

local function pointArrowAtWorld(arrow: GuiObject, worldPos: Vector3)
	local viewport = camera.ViewportSize
	local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
	local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
	local pos2 = Vector2.new(screenPos.X, screenPos.Y)
	local dir = pos2 - center
	if
		onScreen
		and screenPos.Z > 0
		and pos2.X >= 0
		and pos2.X <= viewport.X
		and pos2.Y >= 0
		and pos2.Y <= viewport.Y
	then
		arrow.Visible = false
		return true -- on-screen
	end
	-- If target is behind the camera, flip the direction
	if screenPos.Z < 0 then
		dir = -dir
	end
	-- Clamp to screen edge with margin
	local margin = 24
	local half = Vector2.new(viewport.X * 0.5 - margin, viewport.Y * 0.5 - margin)
	if dir.Magnitude < 1e-3 then
		dir = Vector2.new(0, -1)
	end
	local scale = math.max(math.abs(dir.X) / half.X, math.abs(dir.Y) / half.Y, 1)
	local edgePos = center + dir / scale
	arrow.Position = UDim2.fromOffset(edgePos.X, edgePos.Y)
	arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90 -- assumes arrow points up
	arrow.Visible = true
	return false -- off-screen
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not (character and camera) then
		return
	end
	local arrow = ensureArrow()
	if not arrow then
		return
	end
	local target = getBestTargetInRange(character)
	if not target then
		arrow.Visible = false
		return
	end
	-- Color red while on cooldown, else original color
	local isCd = Grapple.getPartCooldownRemaining(target) > 0
	setArrowState(arrow, isCd)
	local onScreen = pointArrowAtWorld(arrow, target.Position)
	-- While arrow is showing (off-screen), hide the default content Frame inside HookUI; show it when on-screen
	local hookUI = getHookUI()
	if hookUI then
		local content = hookUI:FindFirstChild("Frame")
		if content and content:IsA("GuiObject") then
			if not onScreen then
				content.Visible = false
				arrow.Visible = true
			else
				content.Visible = true
				arrow.Visible = false
			end
		end
	end
end)
