-- Climb prompt billboard UI. Creates a small UI over the player's head and
-- binds it to ReplicatedStorage/ClientState/ClimbPrompt (StringValue).
-- Later, you can replace this runtime-created UI with your own by placing a
-- `BillboardGui` named `ClimbPromptGui` under the character's Head. This
-- script will detect and use it instead of creating a new one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LOCAL_PLAYER = Players.LocalPlayer

local function getClientPromptValue()
	local folder = ReplicatedStorage:FindFirstChild("ClientState")
	if not folder then
		return nil
	end
	local value = folder:FindFirstChild("ClimbPrompt")
	return value
end

local function getExistingBillboard()
	local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")
	local folder = playerGui:FindFirstChild("BillboardGui")
	if folder then
		local gui = folder:FindFirstChild("ClimbPromptGui")
		if gui and gui:IsA("BillboardGui") then
			return gui
		end
	end
	-- Fallback: search in all descendants
	for _, d in ipairs(playerGui:GetDescendants()) do
		if d:IsA("BillboardGui") and d.Name == "ClimbPromptGui" then
			return d
		end
	end
	return nil
end

local function bindPromptToCharacter(character)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	-- Try to clone from PlayerGui template into Head to ensure it's attached
	local template = getExistingBillboard()
	if not template then
		return
	end
	-- Ensure the template in PlayerGui stays hidden so it does not render at origin
	template.Enabled = false
	local gui = template:Clone()
	gui.Name = "ClimbPromptGui"
	gui.Adornee = head
	gui.Parent = head
	gui.Enabled = false
	-- Try to find a label named "Text", or any TextLabel descendant
	local label = gui:FindFirstChild("Text")
	if not label then
		for _, descendant in ipairs(gui:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				label = descendant
				break
			end
		end
	end
	local value = getClientPromptValue()
	if not label or not value then
		return
	end

	-- Fade helpers (0.15s)
	local defaults = {}
	local function fallbackVisibleBackground(alpha)
		if alpha == nil then
			return 0.2
		end
		if alpha > 0.95 then
			return 0.2
		end
		return alpha
	end

	local function captureDefaultsFor(guiObject)
		if defaults[guiObject] then
			return
		end
		if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") then
			if guiObject:IsA("TextLabel") then
				defaults[guiObject] = {
					-- If template has fully hidden values (1), fall back to visible defaults
					TextTransparency = 0,
				}
			else
				defaults[guiObject] = {
					-- If template has fully hidden values (1), fall back to visible defaults
					TextTransparency = 0,
					BackgroundTransparency = fallbackVisibleBackground(guiObject.BackgroundTransparency),
				}
			end
		elseif guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
			defaults[guiObject] = {
				ImageTransparency = 0,
				BackgroundTransparency = fallbackVisibleBackground(guiObject.BackgroundTransparency),
			}
		elseif guiObject:IsA("Frame") then
			defaults[guiObject] = {
				BackgroundTransparency = fallbackVisibleBackground(guiObject.BackgroundTransparency),
			}
		end
	end

	local function setTransparencyInstant(alpha)
		for _, d in ipairs(gui:GetDescendants()) do
			if d:IsA("GuiObject") then
				captureDefaultsFor(d)
				local def = defaults[d]
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					if def and def.TextTransparency ~= nil then
						d.TextTransparency = alpha
					end
					if def and def.BackgroundTransparency ~= nil then
						d.BackgroundTransparency = math.clamp(alpha, 0, 1)
					end
				elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
					if def and def.ImageTransparency ~= nil then
						d.ImageTransparency = alpha
					end
					if def and def.BackgroundTransparency ~= nil then
						d.BackgroundTransparency = math.clamp(alpha, 0, 1)
					end
				elseif d:IsA("Frame") then
					if def and def.BackgroundTransparency ~= nil then
						d.BackgroundTransparency = math.clamp(alpha, 0, 1)
					end
				end
			end
		end
	end

	local function tweenToDefaults(duration)
		for _, d in ipairs(gui:GetDescendants()) do
			if d:IsA("GuiObject") then
				local def = defaults[d]
				if def then
					if def.TextTransparency ~= nil then
						TweenService:Create(d, TweenInfo.new(duration), { TextTransparency = def.TextTransparency })
							:Play()
					end
					if def.ImageTransparency ~= nil then
						TweenService:Create(d, TweenInfo.new(duration), { ImageTransparency = def.ImageTransparency })
							:Play()
					end
					if def.BackgroundTransparency ~= nil then
						TweenService
							:Create(d, TweenInfo.new(duration), { BackgroundTransparency = def.BackgroundTransparency })
							:Play()
					end
				end
			end
		end
	end

	local function tweenToHidden(duration)
		for _, d in ipairs(gui:GetDescendants()) do
			if d:IsA("GuiObject") then
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					TweenService
						:Create(d, TweenInfo.new(duration), { TextTransparency = 1, BackgroundTransparency = 1 })
						:Play()
				elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
					TweenService
						:Create(d, TweenInfo.new(duration), { ImageTransparency = 1, BackgroundTransparency = 1 })
						:Play()
				elseif d:IsA("Frame") then
					TweenService:Create(d, TweenInfo.new(duration), { BackgroundTransparency = 1 }):Play()
				end
			end
		end
	end

	local function fadeIn()
		gui.Enabled = true
		gui.Adornee = head
		setTransparencyInstant(1)
		tweenToDefaults(0.15)
	end

	local function fadeOut()
		tweenToHidden(0.15)
		task.delay(0.16, function()
			gui.Enabled = false
			gui.Adornee = head
		end)
	end

	-- Initial and reactive apply
	local function apply(val)
		label.Text = val
		if val ~= nil and val ~= "" then
			fadeIn()
		else
			fadeOut()
		end
	end
	apply(value.Value)

	value.Changed:Connect(function()
		apply(value.Value)
	end)
end

local function onCharacterAdded(character)
	-- Delay a frame to ensure Head exists
	task.defer(function()
		bindPromptToCharacter(character)
	end)
end

LOCAL_PLAYER.CharacterAdded:Connect(onCharacterAdded)
if LOCAL_PLAYER.Character then
	onCharacterAdded(LOCAL_PLAYER.Character)
end
