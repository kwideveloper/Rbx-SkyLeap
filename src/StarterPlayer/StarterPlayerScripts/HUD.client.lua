-- Simple HUD for stamina and speed, adjusted to existing UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Use the prebuilt interface: ScreenGui "Stamina" with Frame "Container"
local screenGui = playerGui:WaitForChild("Stamina")
local container = screenGui:WaitForChild("Container")
local barBg = container:WaitForChild("StaminaBg")
local speedText = container:WaitForChild("SpeedText")
local barLabel = container:WaitForChild("StaminaLabel")

-- Ensure a fill frame exists inside StaminaBg
local barFill = barBg:FindFirstChild("StaminaFill")
if not barFill then
	barFill = Instance.new("Frame")
	barFill.Name = "StaminaFill"
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
end

-- Optional: show costs next to label
local costsText = container:FindFirstChild("CostsText")
if not costsText then
	costsText = Instance.new("TextLabel")
	costsText.Name = "CostsText"
	costsText.Size = UDim2.new(0, 240, 0, 16)
	costsText.Position = UDim2.new(0, 0, 0, -36)
	costsText.BackgroundTransparency = 1
	costsText.Font = Enum.Font.Gotham
	costsText.TextSize = 12
	costsText.TextColor3 = Color3.fromRGB(170, 170, 170)
	costsText.TextXAlignment = Enum.TextXAlignment.Left
	costsText.Text = ""
	costsText.Parent = container
end

local function formatCosts()
	local C = require(ReplicatedStorage.Movement.Config)
	return string.format(
		"Q Dash:%d  C Slide:%d  Space Wall:%d",
		C.DashStaminaCost or 0,
		C.SlideStaminaCost or 0,
		C.WallJumpStaminaCost or 0
	)
end

local function flashBar(color)
	local original = barFill.BackgroundColor3
	barFill.BackgroundColor3 = color
	TweenService:Create(barFill, TweenInfo.new(0.4), { BackgroundColor3 = original }):Play()
end

local function colorForStaminaRatio(r)
	-- Green (high) > Yellow (mid) > Orange (low) > Red (very low)
	if r >= 0.7 then
		return Color3.fromRGB(0, 200, 120)
	elseif r >= 0.45 then
		return Color3.fromRGB(235, 200, 60)
	elseif r >= 0.25 then
		return Color3.fromRGB(255, 140, 0)
	else
		return Color3.fromRGB(220, 60, 60)
	end
end

local function getClientState()
	local folder = ReplicatedStorage:FindFirstChild("ClientState")
	return folder,
		folder and folder:FindFirstChild("Stamina") or nil,
		folder and folder:FindFirstChild("Speed") or nil,
		folder and folder:FindFirstChild("IsSprinting") or nil,
		folder and folder:FindFirstChild("IsSliding") or nil,
		folder and folder:FindFirstChild("IsAirborne") or nil,
		folder and folder:FindFirstChild("IsWallRunning") or nil
end

-- Action icons (UI elements) - use existing UI only
local iconsFrame = container:WaitForChild("ActionIcons")

local dashIcon = iconsFrame:WaitForChild("Dash")
local slideIcon = iconsFrame:WaitForChild("Slide")
local wallIcon = iconsFrame:WaitForChild("Wall")

-- Preserve original frame BG configured in Studio; toggle frame BG color per availability
local frameDefaults = {}
local function captureFrameDefaults(frame)
	frameDefaults[frame] = frame.BackgroundColor3
	return frameDefaults[frame]
end

local function setIconState(frame, enabled)
	if typeof(frame) ~= "Instance" then
		return
	end
	local defaultBg = frameDefaults[frame] or captureFrameDefaults(frame)
	if enabled then
		frame.BackgroundColor3 = defaultBg
	else
		frame.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	end
end

local function update()
	local folder, staminaValue, speedValue, isSprinting, isSliding, isAirborne, isWallRunning = getClientState()
	if not folder then
		return
	end
	local staminaCurrent = staminaValue and staminaValue.Value or 0
	local C = require(ReplicatedStorage.Movement.Config)
	local staminaMax = C.StaminaMax
	local ratio = 0
	if staminaMax > 0 then
		ratio = math.clamp(staminaCurrent / staminaMax, 0, 1)
	end
	barFill.Size = UDim2.new(ratio, 0, 1, 0)
	barFill.BackgroundColor3 = colorForStaminaRatio(ratio)
	speedText.Text = string.format("Speed: %d", speedValue and math.floor(speedValue.Value + 0.5) or 0)
	costsText.Text = formatCosts()

	-- Visual feedback when stamina insuficiente (< min de cualquiera de los costos)
	local minCost = math.min(C.DashStaminaCost or 0, C.SlideStaminaCost or 0, C.WallJumpStaminaCost or 0)
	if staminaCurrent < minCost then
		flashBar(Color3.fromRGB(220, 80, 80))
	end

	-- Icons enabled/disabled based on stamina, state, and cooldowns
	local Abilities = require(ReplicatedStorage.Movement.Abilities)
	local canDash = staminaCurrent >= (C.DashStaminaCost or 0)
		and Abilities.isDashReady()
		and not (isWallRunning and isWallRunning.Value)
	local canSlide = (isSprinting and isSprinting.Value)
		and staminaCurrent >= (C.SlideStaminaCost or 0)
		and not (isWallRunning and isWallRunning.Value)
		and not (isAirborne and isAirborne.Value)
	-- Wall jump/hop available if near a wall (airborne not required)
	local nearWall = false
	do
		local WallRun = require(ReplicatedStorage.Movement.WallRun)
		local WallJump = require(ReplicatedStorage.Movement.WallJump)
		local player = game:GetService("Players").LocalPlayer
		local character = player.Character
		if character then
			nearWall = WallRun.isNearWall(character) or WallJump.isNearWall(character)
			-- Respect one-jump-per-wall rule: if the nearby wall is the same as the last used, disable icon until reset
			local WallMemory = require(ReplicatedStorage.Movement.WallMemory)
			local last = WallMemory.getLast(character)
			local currentWall = WallJump.getNearbyWall(character)
			if last and currentWall and last == currentWall then
				nearWall = false
			end
		end
	end
	local canWall = staminaCurrent >= (C.WallJumpStaminaCost or 0) and nearWall
	setIconState(dashIcon, canDash)
	setIconState(slideIcon, canSlide)
	setIconState(wallIcon, canWall)
end

-- Heartbeat-driven update for snappy UI
game:GetService("RunService").RenderStepped:Connect(update)
