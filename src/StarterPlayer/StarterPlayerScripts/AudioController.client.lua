local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")
local settingsUI = playerGui:WaitForChild("Settings")
local frame = settingsUI:WaitForChild("Frame")
local configsFrame = frame:WaitForChild("Configs")

------------ ? Background Music ------------

-- Folder containing sounds
local soundsFolder = playerScripts:WaitForChild("Sounds"):WaitForChild("BackgroundMusic")

-- List to store sounds
local soundList = {}
for _, sound in pairs(soundsFolder:GetChildren()) do
	if sound:IsA("Sound") then
		table.insert(soundList, sound)
	end
end

-- Function to shuffle the sound list (Fisher-Yates Shuffle)
local function shuffleTable(t)
	for i = #t, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
end

-- Current playlist
local currentPlaylist = {}

-- Function to start the playback
local function playNextSound()
	if #currentPlaylist == 0 then
		-- If the list is empty, shuffle again
		currentPlaylist = soundList
		shuffleTable(currentPlaylist)
	end

	-- Take the first sound from the list and play it
	local nextSound = table.remove(currentPlaylist, 1)
	nextSound:Play()

	-- Wait for the sound to end before playing the next one
	nextSound.Ended:Connect(playNextSound)
end

-- Start playback when the game starts
playNextSound()

------------? Background Music ------------

------------ ? Sounds Controller ------------

-- Function to handle the slider per group
local function handleSlider(groupUI, target)
	local circle = groupUI:FindFirstChild("Circle", true)
	local dragDetector = circle:FindFirstChild("UIDragDetector", true)
	local slider = dragDetector.Parent.Parent -- Slider frame
	local textInput = groupUI:FindFirstChild("TextInput", true)
	if not textInput then
		for _, d in ipairs(groupUI:GetDescendants()) do
			if d:IsA("TextBox") then
				textInput = d
				break
			end
		end
	end
	local sliderContainer = slider.Parent
	-- Step configuration: 0..1 in 0.1 increments
	local steps = 11

	-- Compute clamped bounds so the circle never goes outside the slider
	local function computeBounds()
		local anchorX = circle.AnchorPoint.X or 0.5
		local leftMargin = circle.AbsoluteSize.X * anchorX
		local rightMargin = circle.AbsoluteSize.X * (1 - anchorX)
		local minX = leftMargin
		local maxX = math.max(minX, slider.AbsoluteSize.X - rightMargin)
		return minX, maxX
	end

	local function applyTargetVolume(ratio)
		if target and target:IsA("SoundGroup") then
			target.Volume = ratio
		elseif target and target:IsA("Folder") then
			for _, ch in ipairs(target:GetChildren()) do
				if ch:IsA("Sound") then
					ch.Volume = ratio
				end
			end
		end
	end

	local function setUIFromRatio(ratio)
		ratio = math.clamp(ratio, 0, 1)
		-- snap to 0.1
		local snapped = math.floor(ratio * 10 + 0.5) / 10
		local minX, maxX = computeBounds()
		local x = minX + (maxX - minX) * snapped
		circle.Position = UDim2.new(0, math.floor(x + 0.5), circle.Position.Y.Scale, circle.Position.Y.Offset)
		if textInput and textInput:IsA("TextBox") then
			local new = string.format("%.1f", snapped)
			if textInput.Text ~= new then
				textInput.Text = new
			end
		end
		applyTargetVolume(snapped)
	end

	-- Initialize from current volume
	local initial = 0.5
	if target and target:IsA("SoundGroup") then
		initial = tonumber(target.Volume) or 0.5
	elseif target and target:IsA("Folder") then
		for _, ch in ipairs(target:GetChildren()) do
			if ch:IsA("Sound") then
				initial = tonumber(ch.Volume) or 0.5
				break
			end
		end
	end
	setUIFromRatio(initial)

	-- Drag handler
	dragDetector.DragContinue:Connect(function(pos)
		-- pos is a Vector2
		local minX, maxX = computeBounds()
		local localX = math.clamp(pos.X - slider.AbsolutePosition.X, minX, maxX)
		local ratio = 0
		if maxX > minX then
			ratio = (localX - minX) / (maxX - minX)
		end
		setUIFromRatio(ratio)
	end)

	-- Text input handler
	if textInput and textInput:IsA("TextBox") then
		textInput.FocusLost:Connect(function()
			local n = tonumber(textInput.Text)
			if n == nil then
				-- revert to current UI
				local xOffset = circle.Position.X.Offset
				local minX, maxX = computeBounds()
				local cur = 0
				if maxX > minX then
					cur = (xOffset - minX) / (maxX - minX)
				end
				textInput.Text = string.format("%.1f", math.floor(math.clamp(cur, 0, 1) * 10 + 0.5) / 10)
				return
			end
			n = math.clamp(n, 0, 1)
			-- snap to 0.1
			n = math.floor(n * 10 + 0.5) / 10
			setUIFromRatio(n)
		end)
	end

	return {
		setRatio = function(r)
			setUIFromRatio(tonumber(r) or 0.5)
		end,
		getRatio = function()
			local xOffset = circle.Position.X.Offset
			local minX, maxX = computeBounds()
			local cur = 0
			if maxX > minX then
				cur = (xOffset - minX) / (maxX - minX)
			end
			-- snap to 0.1
			return math.floor(math.clamp(cur, 0, 1) * 10 + 0.5) / 10
		end,
	}
end

local musicController = configsFrame:WaitForChild("Music")
local musicSoundGroup = playerScripts:WaitForChild("Sounds"):WaitForChild("BackgroundMusic")

local sfxController = configsFrame:WaitForChild("Sounds")
local sfxSoundGroup = playerScripts:WaitForChild("Sounds"):WaitForChild("SFX")

local musicUI = handleSlider(musicController, musicSoundGroup)
local sfxUI = handleSlider(sfxController, sfxSoundGroup)

-- Persist settings to backend when user leaves or when values change (debounced)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local audioLoaded = remotes:WaitForChild("AudioSettingsLoaded")
local setAudio = remotes:WaitForChild("SetAudioSettings")

local current = { music = 0.5, sfx = 0.5 }
local lastSaved = { music = nil, sfx = nil }
local saveDebounce = false

local function readGroups()
	local musicAny = 0.5
	if musicSoundGroup and musicSoundGroup:IsA("Folder") then
		for _, ch in ipairs(musicSoundGroup:GetChildren()) do
			if ch:IsA("Sound") then
				musicAny = tonumber(ch.Volume) or musicAny
				break
			end
		end
	elseif musicSoundGroup and musicSoundGroup:IsA("SoundGroup") then
		musicAny = tonumber(musicSoundGroup.Volume) or musicAny
	end
	local sfxAny = 0.5
	if sfxSoundGroup and sfxSoundGroup:IsA("SoundGroup") then
		sfxAny = tonumber(sfxSoundGroup.Volume) or sfxAny
	end
	return musicAny, sfxAny
end

local function maybeSave()
	if saveDebounce then
		return
	end
	saveDebounce = true
	task.delay(0.5, function()
		saveDebounce = false
		if current.music ~= lastSaved.music or current.sfx ~= lastSaved.sfx then
			setAudio:FireServer({ music = current.music, sfx = current.sfx })
			lastSaved.music = current.music
			lastSaved.sfx = current.sfx
		end
	end)
end

-- Apply loaded defaults from server
audioLoaded.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	local m = tonumber(payload.music) or 0.5
	local s = tonumber(payload.sfx) or 0.5
	-- Drive UI by simulating set ratio
	current.music = math.clamp(m, 0, 1)
	current.sfx = math.clamp(s, 0, 1)
	-- Update UI controls
	if musicUI and musicUI.setRatio then
		musicUI.setRatio(current.music)
	end
	if sfxUI and sfxUI.setRatio then
		sfxUI.setRatio(current.sfx)
	end
	-- Directly set groups as well
	if musicSoundGroup and musicSoundGroup:IsA("Folder") then
		for _, ch in ipairs(musicSoundGroup:GetChildren()) do
			if ch:IsA("Sound") then
				ch.Volume = current.music
			end
		end
	end
	if sfxSoundGroup and sfxSoundGroup:IsA("SoundGroup") then
		sfxSoundGroup.Volume = current.sfx
	end
	-- Save initial values as lastSaved to prevent immediate writeback
	lastSaved.music = current.music
	lastSaved.sfx = current.sfx
end)

-- Track changes by polling group values briefly after interactions
task.spawn(function()
	while true do
		task.wait(0.5)
		local m, s = readGroups()
		m = math.floor(math.clamp(m, 0, 1) * 10 + 0.5) / 10
		s = math.floor(math.clamp(s, 0, 1) * 10 + 0.5) / 10
		if math.abs((current.music or 0.5) - m) > 1e-3 then
			current.music = m
			maybeSave()
		end
		if math.abs((current.sfx or 0.5) - s) > 1e-3 then
			current.sfx = s
			maybeSave()
		end
	end
end)
------------ ? Sounds Controller ------------
