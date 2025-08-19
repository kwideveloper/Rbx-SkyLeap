local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Movement.Config)
local Grapple = require(ReplicatedStorage.Movement.Grapple)

if not (Config.HookCooldownLabels == true) then
	return
end

local player = Players.LocalPlayer

-- Templates live in ReplicatedStorage/UI/Hook
local templatesFolder = ReplicatedStorage:FindFirstChild("UI")
local hookFolder = templatesFolder and templatesFolder:FindFirstChild("Hook")
local templateBillboard = hookFolder and hookFolder:FindFirstChild("HookCDLabel")
local templateHighlight = hookFolder and hookFolder:FindFirstChild("Highlight")

local function ensureInstances(part)
	local gui = part:FindFirstChild("HookCDLabel")
	if not gui then
		if not templateBillboard or not templateBillboard:IsA("BillboardGui") then
			return nil, nil
		end
		gui = templateBillboard:Clone()
		gui.Adornee = part
		gui.Parent = part
	end
	local hi = part:FindFirstChildOfClass("Highlight")
	if not hi then
		if not templateHighlight or not templateHighlight:IsA("Highlight") then
			return gui, nil
		end
		hi = templateHighlight:Clone()
		hi.Parent = part
	end
	return gui, hi
end

local function setHighlightEnabled(part, enabled)
	local hi = part:FindFirstChildOfClass("Highlight")
	if hi then
		hi.Enabled = enabled
	end
end

local function setLabel(part, text, visible)
	local gui = part:FindFirstChild("HookCDLabel")
	if not gui then
		return
	end
	local label = gui:FindFirstChildWhichIsA("TextLabel", true)
	if not label then
		return
	end
	label.Text = text or ""
	gui.Enabled = visible and true or false
end

local function inRange(character, part)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local range = Config.HookAutoRange or 90
	return (part.Position - root.Position).Magnitude <= range
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	for _, part in ipairs(CollectionService:GetTagged(Config.HookTag or "Hookable")) do
		if not part:IsA("BasePart") or not part:IsDescendantOf(workspace) then
			continue
		end
		local inR = character and inRange(character, part) or false
		local remaining = Grapple.getPartCooldownRemaining(part)
		if remaining > 0 then
			-- Always show countdown seconds regardless of range; no highlight while on cooldown
			ensureInstances(part)
			setHighlightEnabled(part, false)
			setLabel(part, string.format("%.1f", remaining), true)
		else
			-- Hide text when ready; highlight only when in range
			setLabel(part, nil, false)
			if inR then
				ensureInstances(part)
				setHighlightEnabled(part, true)
			else
				setHighlightEnabled(part, false)
			end
		end
	end
end)
