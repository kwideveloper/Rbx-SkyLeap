-- Attaches a one-shot dash effect from ReplicatedStorage/FX/Dash (ParticleEmitters) to the character

local DashVfx = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function findDashTemplate()
	local fx = ReplicatedStorage:FindFirstChild("FX")
	if not fx then
		return nil
	end
	local dash = fx:FindFirstChild("Dash")
	return dash
end

function DashVfx.playFor(character, duration)
	local template = findDashTemplate()
	if not template then
		return
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	-- Create a temporary attachment on the root to host particle emitters
	local attach = Instance.new("Attachment")
	attach.Name = "DashVfxAttach"
	attach.Parent = root

	local emitters = {}
	for _, child in ipairs(template:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			local pe = child:Clone()
			pe.Parent = attach
			pe.Enabled = true
			table.insert(emitters, pe)
		end
	end

	local life = duration or 0.2
	for _, pe in ipairs(emitters) do
		local burst = pe.Rate > 0 and math.max(1, math.ceil(pe.Rate * life)) or 10
		pe:Emit(burst)
	end

	task.delay(life, function()
		if attach.Parent then
			attach:Destroy()
		end
	end)
end

function DashVfx.playSlideFor(character, duration)
	-- Reuse the same FX, but allow a slightly longer duration if provided
	return DashVfx.playFor(character, duration)
end

return DashVfx
