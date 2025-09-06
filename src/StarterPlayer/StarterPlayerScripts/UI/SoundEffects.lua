-- SoundEffects.lua
-- Sound effects system for MenuAnimator

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Config = require(script.Parent.Config)
local Utils = require(script.Parent.Utils)

local SoundEffects = {}

-- Sound effects system
local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:FindFirstChild("PlayerScripts")

local backgroundMusicGroup = nil
local sfxGroup = nil
local soundEffectActive = false
local originalVolumesCaptured = false -- Flag to track if we captured original volumes
local isRestoringVolumes = false -- Flag to prevent listener updates during volume restoration
local originalMusicVolumes = {} -- Store original volumes (captured once)
local originalSFXVolume = 0.5
local originalBGVolume = 0.5 -- Separate variable for BG Music when it's a SoundGroup

-- Function to check if a button has the "MenuButton" tag
local function isMenuButton(button)
	return CollectionService:HasTag(button, "MenuButton")
end

-- Sound effects functions
local function initializeSoundGroups()
	if not PlayerScripts then
		return
	end

	local soundsFolder = PlayerScripts:FindFirstChild("Sounds")
	if not soundsFolder then
		return
	end

	backgroundMusicGroup = soundsFolder:FindFirstChild("BackgroundMusic")
	sfxGroup = soundsFolder:FindFirstChild("SFX")

	-- Add listeners for volume changes to capture dynamic volume updates
	if backgroundMusicGroup then
		if backgroundMusicGroup:IsA("SoundGroup") then
			backgroundMusicGroup:GetPropertyChangedSignal("Volume"):Connect(function()
				-- Only update original volume if:
				-- 1. Effects are not active (no system changes happening)
				-- 2. Volumes haven't been captured yet (initial setup)
				-- 3. We're not in the middle of restoring volumes
				if not soundEffectActive and not originalVolumesCaptured and not isRestoringVolumes then
					-- Update original volume when user changes it BEFORE we capture (for next effect application)
					local oldValue = originalBGVolume
					originalBGVolume = backgroundMusicGroup.Volume
				end
			end)
		elseif backgroundMusicGroup:IsA("Folder") then
			for _, sound in ipairs(backgroundMusicGroup:GetChildren()) do
				if sound:IsA("Sound") then
					sound:GetPropertyChangedSignal("Volume"):Connect(function()
						if not soundEffectActive and not originalVolumesCaptured and not isRestoringVolumes then
							local oldValue = originalMusicVolumes[sound] or 0
							originalMusicVolumes[sound] = sound.Volume
						end
					end)
				end
			end
		end
	end

	if sfxGroup and sfxGroup:IsA("SoundGroup") then
		sfxGroup:GetPropertyChangedSignal("Volume"):Connect(function()
			if not soundEffectActive and not originalVolumesCaptured and not isRestoringVolumes then
				local oldValue = originalSFXVolume
				originalSFXVolume = sfxGroup.Volume
			end
		end)
	end

	-- Capture initial volumes to ensure we have the correct baseline
	if backgroundMusicGroup and backgroundMusicGroup:IsA("SoundGroup") and not originalVolumesCaptured then
		originalBGVolume = backgroundMusicGroup.Volume
	end

	if sfxGroup and sfxGroup:IsA("SoundGroup") and not originalVolumesCaptured then
		originalSFXVolume = sfxGroup.Volume
	end

	-- Sound groups are now initialized but volumes are captured dynamically when effects are applied
end

function SoundEffects.applyClubEffects(enable)
	if not backgroundMusicGroup and not sfxGroup then
		warn("[Sound] No sound groups found")
		return
	end

	if enable and not soundEffectActive then
		-- Enable existing MenuOpened equalizer effects
		local function enableMenuEffect(soundGroup)
			if not soundGroup then
				return
			end

			local menuEffect = soundGroup:FindFirstChild("MenuOpened")
			if menuEffect and menuEffect:IsA("EqualizerSoundEffect") then
				menuEffect.Enabled = true
			end
		end

		-- Enable effects on both groups
		enableMenuEffect(backgroundMusicGroup)
		enableMenuEffect(sfxGroup)

		-- CAPTURE ORIGINAL VOLUMES ONLY ONCE (like blur/FOV system)
		-- Only capture if we haven't captured them before (first time EVER activating effects)
		if not originalVolumesCaptured then
			if backgroundMusicGroup then
				if backgroundMusicGroup:IsA("SoundGroup") then
					originalBGVolume = backgroundMusicGroup.Volume
				end
			end

			if sfxGroup and sfxGroup:IsA("SoundGroup") then
				originalSFXVolume = sfxGroup.Volume
			end

			originalVolumesCaptured = true -- Mark as captured for this session
		end

		-- Reduce volume by 0.2 (less reduction for more noticeable effects) from ORIGINAL values with smooth transition
		local volumeTweenDuration = 0.5 -- Duration for volume transitions

		if backgroundMusicGroup then
			if backgroundMusicGroup:IsA("SoundGroup") then
				local targetVolume = math.max(0, originalBGVolume - Config.VOLUME_TO_REDUCE)
				local volumeTween =
					Utils.createTween(backgroundMusicGroup, { Volume = targetVolume }, volumeTweenDuration)
				volumeTween:Play()
			end
		end

		if sfxGroup and sfxGroup:IsA("SoundGroup") then
			local targetVolume = math.max(0, originalSFXVolume - Config.VOLUME_TO_REDUCE)
			local volumeTween = Utils.createTween(sfxGroup, { Volume = targetVolume }, volumeTweenDuration)
			volumeTween:Play()
		end

		soundEffectActive = true
	elseif not enable and soundEffectActive then
		-- Disable existing MenuOpened equalizer effects
		local function disableMenuEffect(soundGroup)
			if not soundGroup then
				return
			end

			local menuEffect = soundGroup:FindFirstChild("MenuOpened")
			if menuEffect and menuEffect:IsA("EqualizerSoundEffect") then
				menuEffect.Enabled = false
			end
		end

		disableMenuEffect(backgroundMusicGroup)
		disableMenuEffect(sfxGroup)

		-- Set flag to prevent listeners from updating during restoration
		isRestoringVolumes = true

		-- Restore ORIGINAL volumes (the volumes before effects were applied) with smooth transition
		local volumeTweenDuration = 0.5 -- Duration for volume transitions

		if backgroundMusicGroup then
			if backgroundMusicGroup:IsA("SoundGroup") then
				local volumeTween =
					Utils.createTween(backgroundMusicGroup, { Volume = originalBGVolume }, volumeTweenDuration)
				volumeTween:Play()
			end
		end

		if sfxGroup and sfxGroup:IsA("SoundGroup") then
			local volumeTween = Utils.createTween(sfxGroup, { Volume = originalSFXVolume }, volumeTweenDuration)
			volumeTween:Play()
		end

		-- Clear original music volumes (individual sounds)
		originalMusicVolumes = {}
		-- NOTE: originalSFXVolume and originalBGVolume stay as captured values
		-- NOTE: originalVolumesCaptured stays true so we keep the captured state across menu transitions

		-- Reset restoration flag
		isRestoringVolumes = false

		soundEffectActive = false
	end
end

function SoundEffects.updateSoundEffects(menuStates, openMenus)
	-- Check if any MenuButton-controlled menus are open
	local hasOpenMenuButtonMenus = false
	for menu, state in pairs(menuStates) do
		if state.isOpen then
			-- Check if this menu is controlled by a MenuButton-tagged button
			local controllingButton = openMenus[menu]
			if controllingButton and isMenuButton(controllingButton) then
				hasOpenMenuButtonMenus = true
				break
			end
		end
	end

	-- Apply or remove sound effects based on MenuButton menu state only
	if hasOpenMenuButtonMenus and not soundEffectActive then
		SoundEffects.applyClubEffects(true)
	elseif not hasOpenMenuButtonMenus and soundEffectActive then
		SoundEffects.applyClubEffects(false)
	end
end

-- Initialize sound groups
function SoundEffects.initialize()
	initializeSoundGroups()
end

return SoundEffects
