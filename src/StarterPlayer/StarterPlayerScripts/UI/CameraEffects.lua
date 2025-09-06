-- CameraEffects.lua
-- Camera effects system for MenuAnimator

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)

local CameraEffects = {}

-- Camera effects system
local camera = Workspace.CurrentCamera
local blurEffect = nil
local cameraEffectActive = false

-- Camera effects functions
local function createBlurEffect()
	if blurEffect then
		return
	end

	blurEffect = Instance.new("BlurEffect")
	blurEffect.Size = 0
	blurEffect.Parent = camera
end

local function ensureClientStateFolder()
	local cs = ReplicatedStorage:FindFirstChild("ClientState")
	if not cs then
		cs = Instance.new("Folder")
		cs.Name = "ClientState"
		cs.Parent = ReplicatedStorage
	end
	return cs
end

local function setFovOverride(enable, fovValue)
	local cs = ensureClientStateFolder()

	-- Create or update CameraFovOverrideActive
	local fovOverrideActive = cs:FindFirstChild("CameraFovOverrideActive")
	if not fovOverrideActive then
		fovOverrideActive = Instance.new("BoolValue")
		fovOverrideActive.Name = "CameraFovOverrideActive"
		fovOverrideActive.Parent = cs
	end
	fovOverrideActive.Value = enable

	-- Create or update CameraFovOverrideValue
	local fovOverrideValue = cs:FindFirstChild("CameraFovOverrideValue")
	if not fovOverrideValue then
		fovOverrideValue = Instance.new("NumberValue")
		fovOverrideValue.Name = "CameraFovOverrideValue"
		fovOverrideValue.Parent = cs
	end
	fovOverrideValue.Value = fovValue
end

-- Function to check if a button has the "MenuButton" tag
-- This identifies buttons that control main menu navigation
local function isMenuButton(button)
	return CollectionService:HasTag(button, "MenuButton")
end

function CameraEffects.applyCameraEffects(enable)
	if not camera then
		return
	end

	-- Create blur effect if it doesn't exist
	if not blurEffect then
		createBlurEffect()
	end

	local targetBlurSize = enable and Config.BLUR_SIZE or 0

	-- Animate blur
	local blurTween = Utils.createTween(blurEffect, { Size = targetBlurSize }, Config.CAMERA_EFFECT_DURATION)
	blurTween:Play()

	-- Set FOV override using ClientState system (integrates with CameraDynamics)
	if enable then
		setFovOverride(true, Config.MENU_FOV)
	else
		setFovOverride(false, Config.DEFAULT_FOV)
	end

	-- Store effect state
	cameraEffectActive = enable
end

function CameraEffects.updateCameraEffects(menuStates, openMenus)
	-- Check if any MenuButton-controlled menus are open
	local hasOpenMenuButtonMenus = false
	local openMenuButtonCount = 0
	local openMenuButtonNames = {}

	for menu, menuState in pairs(menuStates) do
		if menuState.isOpen then
			-- Check if this menu is controlled by a MenuButton-tagged button
			local controllingButton = openMenus[menu]
			if controllingButton and isMenuButton(controllingButton) then
				hasOpenMenuButtonMenus = true
				openMenuButtonCount = openMenuButtonCount + 1
				table.insert(openMenuButtonNames, menu.Name or "UnnamedMenu")
			end
		end
	end

	-- Apply or remove camera effects based on MenuButton menu state only
	if hasOpenMenuButtonMenus and not cameraEffectActive then
		CameraEffects.applyCameraEffects(true)
	elseif not hasOpenMenuButtonMenus and cameraEffectActive then
		CameraEffects.applyCameraEffects(false)
	end
end

-- Initialize camera settings
function CameraEffects.initialize()
	if camera then
		-- Set initial FOV override to ensure CameraDynamics integration
		setFovOverride(false, Config.DEFAULT_FOV)
	end
end

-- Test functions
function CameraEffects.forceCameraEffects(enable)
	if enable then
		CameraEffects.applyCameraEffects(true)
	else
		CameraEffects.applyCameraEffects(false)
	end
end

function CameraEffects.testFovOverride(enable, fovValue)
	if enable then
		setFovOverride(true, fovValue)
	else
		setFovOverride(false, 70)
	end
end

return CameraEffects
