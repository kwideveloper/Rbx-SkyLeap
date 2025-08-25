-- InteractionGui.lua - Creates a ScreenGui for interaction prompts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function createInteractionUI()
	-- Create the main ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InteractionGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = ReplicatedStorage

	-- Create the main frame
	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Size = UDim2.new(0, 250, 0, 60)
	frame.Position = UDim2.new(0.5, -125, 0.8, 0) -- Center bottom of screen
	frame.BackgroundTransparency = 0.2
	frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	-- Add stroke outline
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0.3, 0.7, 1) -- Blue accent
	stroke.Thickness = 2
	stroke.Parent = frame

	-- Create the text label
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "TextLabel"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "Press E to interact"
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.Parent = frame

	-- Initially disabled
	screenGui.Enabled = false

	print("[InteractionGui] Created interaction UI in ReplicatedStorage")
	return screenGui
end

-- Create the UI when this module is required
local interactionUI = createInteractionUI()

return {
	UI = interactionUI,
	Frame = interactionUI.Frame,
	TextLabel = interactionUI.Frame.TextLabel,
}
