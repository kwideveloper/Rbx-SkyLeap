-- Simple HUD for stamina and speed, adjusted to existing UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI bindings (rebound after respawn if ScreenGui has ResetOnSpawn=true)
local screenGui
local container
local barBg
local speedText
local barLabel
local barFill
local costsText
local iconsFrame
local dashIcon
local slideIcon
local wallIcon

local function bindUi()
	-- Attempt to (re)bind all references; do not create UI elements
	local sg = playerGui:FindFirstChild("Stamina") or playerGui:WaitForChild("Stamina")
	screenGui = sg
	container = screenGui:FindFirstChild("Container") or screenGui:WaitForChild("Container")
	barBg = container:FindFirstChild("StaminaBg") or container:WaitForChild("StaminaBg")
	speedText = container:FindFirstChild("SpeedText") or container:WaitForChild("SpeedText")
	barLabel = container:FindFirstChild("StaminaLabel") or container:WaitForChild("StaminaLabel")
	barFill = barBg:FindFirstChild("StaminaFill") -- must exist in UI
	costsText = container:FindFirstChild("CostsText") -- optional
	iconsFrame = container:FindFirstChild("ActionIcons") -- optional
	dashIcon = iconsFrame and iconsFrame:FindFirstChild("Dash") or nil
	slideIcon = iconsFrame and iconsFrame:FindFirstChild("Slide") or nil
	wallIcon = iconsFrame and iconsFrame:FindFirstChild("Wall") or nil

	-- Rebind again if ScreenGui gets replaced on next spawn
	screenGui.AncestryChanged:Connect(function()
		if not screenGui:IsDescendantOf(playerGui) then
			task.defer(bindUi)
		end
	end)
end

bindUi()

-- Rebind when a new Stamina gui is added (covers ResetOnSpawn=true)
playerGui.ChildAdded:Connect(function(child)
	if child.Name == "Stamina" then
		bindUi()
	end
end)

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
	if not barFill then
		return
	end
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
	if not screenGui or not container or not barBg or not speedText or not barLabel then
		return
	end
	if not barFill then
		-- Wait for UI to include fill; skip until it exists
		barFill = barBg:FindFirstChild("StaminaFill")
		if not barFill then
			return
		end
	end
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
	if costsText then
		costsText.Text = formatCosts()
	end

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
		and Abilities.isSlideReady()
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
	if dashIcon then
		setIconState(dashIcon, canDash)
	end
	if slideIcon then
		setIconState(slideIcon, canSlide)
	end
	if wallIcon then
		setIconState(wallIcon, canWall)
	end
end

-- Heartbeat-driven update for snappy UI
game:GetService("RunService").RenderStepped:Connect(update)
