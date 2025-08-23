-- MenuAnimator: opens/closes Settings with bounce, blur, and FOV override
--
-- Usage (short):
--   local pg = game.Players.LocalPlayer.PlayerGui
--   local btn = pg.UIButtons.CanvasGroup.Config
--   local frame = pg.Settings.Frame
--   -- Registers a toggle on click; duration=0.55s; animation "bounce" (default)
--   _G.MenuAnimator.register(btn, frame, 0.55, "bounce", { fovDelta = -15, blurSize = 18 })
--
--   -- Direct control (no button):
--   -- _G.MenuAnimator.openFrame(frame, 0.55, { animType = "slide" })
--   -- _G.MenuAnimator.closeFrame(frame, 0.25)
--   -- _G.MenuAnimator.toggleFrame(frame, 0.55)
--
-- API:
--   register(button, frame, durationSec, animType?, opts?)
--   openFrame(frame, durationSec, opts?)
--   closeFrame(frame, durationSec, opts?)
--   toggleFrame(frame, durationSec, opts?)
--   animType: "bounce" (default) | "slide"; opts: { fovDelta=-10, blurSize=18, closeDuration?, noOverlayChange? }

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function ensureClientState()
	local cs = ReplicatedStorage:FindFirstChild("ClientState")
	if not cs then
		cs = Instance.new("Folder")
		cs.Name = "ClientState"
		cs.Parent = ReplicatedStorage
	end
	local function ensure(name, class)
		local v = cs:FindFirstChild(name)
		if not v then
			v = Instance.new(class)
			v.Name = name
			v.Parent = cs
		end
		return v
	end
	local active = ensure("CameraFovOverrideActive", "BoolValue")
	local value = ensure("CameraFovOverrideValue", "NumberValue")
	return cs, active, value
end

local function ensureBlur()
	local blur = game:GetService("Lighting"):FindFirstChildOfClass("BlurEffect")
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Size = 0
		blur.Parent = game:GetService("Lighting")
	end
	return blur
end

local function getSettingsFrame()
	local pg = player:WaitForChild("PlayerGui")
	-- Adjust names if needed; current assumption: PlayerGui.Settings.Frame
	local settings = pg:FindFirstChild("Settings") or pg:WaitForChild("Settings")
	local frame = settings:FindFirstChild("Frame") or settings:WaitForChild("Frame")
	return frame
end

local function isSettingsFrame(frame)
	local ok = pcall(function()
		return frame == getSettingsFrame()
	end)
	return ok and frame == getSettingsFrame() or false
end

local function tween(inst, props, info)
	local t =
		TweenService:Create(inst, info or TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local state = {
	prevFov = nil,
	openFrames = {}, -- [Frame] = true
	openCount = 0,
	currentFrame = nil, -- currently visible menu frame (single-active)
	actionToken = 0,
	fovActive = false,
	musicDuckActive = false,
	prevMusicGroupVolume = nil,
	nsOpenCount = 0, -- non-settings menus open count
}

local frameToButton = {} -- map menu frame -> associated ImageButton
local buttonActiveOverride = {} -- map ImageButton -> boolean forcing active style
local buttonToFrame = {} -- map ImageButton -> menu frame

-- Ensure a UIScale exists on a button for smooth scaling
local function ensureUiScale(inst)
	local s = inst:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Scale = 1
		s.Parent = inst
	end
	return s
end

-- Music helpers ---------------------------------------------------------------
local function getMusicGroup()
	return SoundService:FindFirstChild("BackgroundMusic") or SoundService:FindFirstChild("Music")
end

local function getMusicTracksFolder()
	local ps = player:FindFirstChild("PlayerScripts") or player:WaitForChild("PlayerScripts")
	local soundsRoot = ps:FindFirstChild("Sounds") or ps:WaitForChild("Sounds")
	return soundsRoot:FindFirstChild("BackgroundMusic") or soundsRoot:WaitForChild("BackgroundMusic")
end

local function ensureReverbOnTrack(track)
	if not (track and track:IsA("Sound")) then
		return
	end
	local eff = track:FindFirstChild("MenuReverb")
	if not eff then
		eff = Instance.new("ReverbSoundEffect")
		eff.Name = "MenuReverb"
		eff.Parent = track
	end
	-- Softer, shorter reverb (roughly half the previous intensity)
	eff.Density = 0.3
	eff.DecayTime = 0.9
	eff.Diffusion = 0.4
	eff.DryLevel = 0
	-- Reduce wet mix further (more negative = quieter wet signal)
	eff.WetLevel = -14
	return eff
end

local function setMusicDuck(active)
	local group = getMusicGroup()
	local DUCK_DELTA = 0.2
	local DUCK_TIME = 0.2
	-- Volume ducking on group if available; else per track (tweened)
	if active then
		if not state.musicDuckActive then
			-- Store prev group volume if exists and tween to ducked level
			if group then
				state.prevMusicGroupVolume = group.Volume
				local target = math.max(0, (group.Volume or 0.5) - DUCK_DELTA)
				TweenService:Create(
					group,
					TweenInfo.new(DUCK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Volume = target }
				):Play()
			else
				-- Per track fallback (tween)
				local folder = getMusicTracksFolder()
				for _, s in ipairs(folder:GetChildren()) do
					if s:IsA("Sound") then
						local target = math.max(0, (s.Volume or 0.5) - DUCK_DELTA)
						TweenService:Create(
							s,
							TweenInfo.new(DUCK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ Volume = target }
						):Play()
					end
				end
			end
			-- Enable reverb on all tracks
			local folder = getMusicTracksFolder()
			for _, s in ipairs(folder:GetChildren()) do
				if s:IsA("Sound") then
					local eff = ensureReverbOnTrack(s)
					if eff then
						eff.Enabled = true
					end
				end
			end
			state.musicDuckActive = true
		end
	else
		if state.musicDuckActive then
			-- Restore group volume or per track (tween)
			if group and state.prevMusicGroupVolume ~= nil then
				TweenService:Create(
					group,
					TweenInfo.new(DUCK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Volume = state.prevMusicGroupVolume }
				):Play()
				state.prevMusicGroupVolume = nil
			else
				local folder = getMusicTracksFolder()
				for _, s in ipairs(folder:GetChildren()) do
					if s:IsA("Sound") then
						local target = math.clamp((s.Volume or 0.5) + DUCK_DELTA, 0, 1)
						TweenService:Create(
							s,
							TweenInfo.new(DUCK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ Volume = target }
						):Play()
					end
				end
			end
			-- Disable reverb effects
			local folder = getMusicTracksFolder()
			for _, s in ipairs(folder:GetChildren()) do
				if s:IsA("Sound") then
					local eff = s:FindFirstChild("MenuReverb")
					if eff then
						eff.Enabled = false
					end
				end
			end
			state.musicDuckActive = false
		end
	end
end

-- Immediate click feedback: quick pop + rotate, then settle based on willOpen
local function playClickFeedback(button, willOpen)
	if not (button and button:IsA("ImageButton")) then
		return
	end
	local scale = ensureUiScale(button)
	-- quick pop
	local popScale = TweenService:Create(
		scale,
		TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.15 }
	)
	local popRot = TweenService:Create(
		button,
		TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Rotation = -18 }
	)
	popScale.Completed:Connect(function()
		local targetScale = willOpen and 1.10 or 1.00
		local targetRot = willOpen and -10 or 0
		TweenService
			:Create(
				scale,
				TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = targetScale }
			)
			:Play()
		TweenService
			:Create(
				button,
				TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Rotation = targetRot }
			)
			:Play()
	end)
	popScale:Play()
	popRot:Play()
end

local function setButtonActiveVisual(button, active)
	if not button or not button:IsA("ImageButton") then
		return
	end
	local scale = ensureUiScale(button)
	local duration = active and 0.25 or 0.12
	local targetScale = active and 1.1 or 1.0
	local targetRot = active and -10 or 0
	local tScale = TweenService:Create(
		scale,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = targetScale }
	)
	local tRot = TweenService:Create(
		button,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Rotation = targetRot }
	)
	tScale:Play()
	tRot:Play()
end

local function setFovOverrideActive(active, targetFov)
	local _, activeV, valueV = ensureClientState()
	activeV.Value = active and true or false
	if targetFov then
		valueV.Value = targetFov
	end
end

local function applyGlobalOverlays(active, opts)
	local blur = ensureBlur()
	if active then
		-- Blur in
		tween(
			blur,
			{ Size = tonumber(opts.blurSize) or 18 },
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		)
		-- FOV override (only once)
		if not state.fovActive then
			local cur = camera and camera.FieldOfView or 70
			local delta = tonumber(opts.fovDelta) or -10
			local target = math.max(10, cur + delta)
			setFovOverrideActive(true, target)
			state.fovActive = true
		end
		-- Music duck + reverb only if any non-settings menu is open
		if state.nsOpenCount > 0 then
			if not state.musicDuckActive then
				setMusicDuck(true)
			end
		else
			if state.musicDuckActive then
				setMusicDuck(false)
			end
		end
	else
		-- Remove blur and release override
		tween(blur, { Size = 0 }, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
		setFovOverrideActive(false)
		state.fovActive = false
		-- Restore music
		setMusicDuck(false)
	end
end

local function computePositions()
	local center = UDim2.new(0.5, 0, 0.5, 0)
	local below = UDim2.new(0.5, 0, 1.2, 0)
	local overshoot = UDim2.new(0.5, 0, 0.44, 0) -- slightly above center (0.44 < 0.5)
	return center, below, overshoot
end

-- Generic open/close/toggle for any frame
local function openFrame(frame, durationSec, opts)
	if not frame or not frame:IsA("GuiObject") then
		return
	end
	opts = opts or {}
	durationSec = tonumber(durationSec) or 0.52 -- total bounce time
	if state.openFrames[frame] then
		return
	end
	state.openFrames[frame] = true
	state.openCount += 1
	if not isSettingsFrame(frame) then
		state.nsOpenCount = (state.nsOpenCount or 0) + 1
	end
	if state.openCount == 1 and not opts.noOverlayChange then
		applyGlobalOverlays(true, opts)
	end
	local center, below, overshoot = computePositions()
	frame.Visible = true
	frame.Position = below
	local animType = tostring(opts.animType or "bounce"):lower()
	if animType == "slide" then
		tween(frame, { Position = center }, TweenInfo.new(durationSec, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	else
		local upTime = math.max(0.1, durationSec * 0.62)
		local settleTime = math.max(0.08, durationSec - upTime)
		tween(frame, { Position = overshoot }, TweenInfo.new(upTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)).Completed:Wait()
		tween(frame, { Position = center }, TweenInfo.new(settleTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end
	-- Token gate: only mark as current if this is the latest action
	local token = opts._token
	if token and token ~= state.actionToken then
		return
	end
	state.currentFrame = frame
	-- Apply active button visuals if mapped
	local btn = frameToButton[frame]
	if btn then
		buttonActiveOverride[btn] = true
		setButtonActiveVisual(btn, true)
	end
	-- If overlays were already active (e.g., Settings open), ensure music duck is toggled according to nsOpenCount
	if state.openCount > 0 then
		if state.nsOpenCount > 0 and not state.musicDuckActive then
			setMusicDuck(true)
		elseif state.nsOpenCount == 0 and state.musicDuckActive then
			setMusicDuck(false)
		end
	end
end

local function closeFrame(frame, durationSec, opts)
	if not frame or not frame:IsA("GuiObject") then
		return
	end
	opts = opts or {}
	durationSec = tonumber(durationSec) or 0.25
	if not state.openFrames[frame] then
		return
	end
	-- If this is the last open menu and we are allowed to change overlays, start restoring FOV immediately
	if state.openCount == 1 and not opts.noOverlayChange then
		if not opts._token or opts._token == state.actionToken then
			setFovOverrideActive(false)
			state.fovActive = false
		end
	end
	-- Track non-settings count
	if not isSettingsFrame(frame) then
		state.nsOpenCount = math.max(0, (state.nsOpenCount or 0) - 1)
	end
	state.openFrames[frame] = nil
	state.openCount = math.max(0, state.openCount - 1)
	local _, below = computePositions()
	local animType = tostring(opts.animType or "bounce"):lower()
	local easing = (animType == "slide") and Enum.EasingStyle.Quad or Enum.EasingStyle.Quad
	tween(frame, { Position = below }, TweenInfo.new(durationSec, easing, Enum.EasingDirection.In)).Completed:Wait()
	frame.Visible = false
	if state.currentFrame == frame then
		state.currentFrame = nil
	end
	-- Deactivate button visual if mapped
	local btn = frameToButton[frame]
	if btn then
		buttonActiveOverride[btn] = false
		setButtonActiveVisual(btn, false)
	end
	-- Token gate for overlay changes
	local token = opts._token
	if state.openCount == 0 and not opts.noOverlayChange and (not token or token == state.actionToken) then
		applyGlobalOverlays(false, opts)
	else
		-- Overlays still active (e.g., Settings still open). Ensure music duck reflects nsOpenCount
		if state.nsOpenCount == 0 and state.musicDuckActive then
			setMusicDuck(false)
		elseif state.nsOpenCount > 0 and not state.musicDuckActive then
			setMusicDuck(true)
		end
	end
end

local function toggleFrame(frame, durationSec, opts)
	opts = opts or {}
	-- New action token for this toggle
	state.actionToken = (state.actionToken or 0) + 1
	local token = state.actionToken
	if state.openFrames[frame] then
		opts._token = token
		closeFrame(frame, (opts and opts.closeDuration) or 0.25, opts)
	else
		-- Determine if there was already any open before switching
		local hadOpen = state.openCount > 0
		-- Close all other open frames quickly and keep overlays
		for other in pairs(state.openFrames) do
			if other ~= frame then
				closeFrame(
					other,
					(opts and opts.switchCloseDuration) or 0.15,
					{ animType = opts.animType or "bounce", noOverlayChange = true, _token = token }
				)
			end
		end
		-- Open target, keep overlays if others were open (hadOpen)
		local openOpts = {
			animType = opts.animType or "bounce",
			noOverlayChange = hadOpen or opts.noOverlayChange or false,
			fovDelta = opts.fovDelta or -10,
			blurSize = opts.blurSize or 18,
			_token = token,
		}
		openFrame(frame, durationSec, openOpts)
	end
end

-- Settings wrappers (use the generic functions)
local function openSettings()
	local frame = getSettingsFrame()
	openFrame(frame, 0.52, { fovDelta = -15, blurSize = 18 })
end

local function closeSettings()
	local frame = getSettingsFrame()
	closeFrame(frame, 0.25, { blurSize = 18 })
end

local function toggleSettings()
	local frame = getSettingsFrame()
	-- Delegate to generic toggle with switch behavior and preserved overlays
	toggleFrame(frame, 0.35, { animType = "bounce", fovDelta = -15, blurSize = 18, switchCloseDuration = 0.15 })
end

-- Expose simple input bindings: you can wire these to your UI buttons
local function bindButtons()
	local frame = getSettingsFrame()
	-- If you have dedicated open/close buttons, hook them here; placeholder names:
	local openBtn = frame:FindFirstChild("OpenButton")
	local closeBtn = frame:FindFirstChild("CloseButton")
	if openBtn and openBtn:IsA("GuiButton") then
		openBtn.MouseButton1Click:Connect(toggleSettings)
	end
	if closeBtn and closeBtn:IsA("GuiButton") then
		closeBtn.MouseButton1Click:Connect(function()
			closeFrame(frame, 0.25, {})
		end)
	end
	-- Also bind global UI button at PlayerGui/UIButtons/CanvasGroup/Config
	task.spawn(function()
		local pg = player:WaitForChild("PlayerGui")
		local uiButtons = pg:FindFirstChild("UIButtons") or pg:WaitForChild("UIButtons", 5)
		if uiButtons then
			local canvas = uiButtons:FindFirstChild("CanvasGroup") or uiButtons:WaitForChild("CanvasGroup", 5)
			if canvas then
				-- Helper to get nested ImageButton inside a named container frame
				local function findButton(containerName)
					local container = canvas:FindFirstChild(containerName) or canvas:WaitForChild(containerName, 5)
					if not container then
						return nil
					end
					local btn = container:FindFirstChild("Button")
					if btn and btn:IsA("ImageButton") then
						return btn
					end
					-- fallback: find any ImageButton descendant
					for _, d in ipairs(container:GetDescendants()) do
						if d:IsA("ImageButton") then
							return d
						end
					end
					return nil
				end

				local configBtn = findButton("Config")
				if configBtn then
					-- Map settings frame to config button and hook
					frameToButton[frame] = configBtn
					buttonToFrame[configBtn] = frame
					configBtn.MouseButton1Click:Connect(function()
						local willOpen = not state.openFrames[frame]
						-- Pre-apply active override for consistent leave behavior
						if willOpen then
							buttonActiveOverride[configBtn] = true
						else
							buttonActiveOverride[configBtn] = false
						end
						playClickFeedback(configBtn, willOpen)
						toggleSettings()
					end)
				end
				-- Quests button -> open PlayerGui.Quests.Frame
				local questsBtn = findButton("Quests")
				if questsBtn then
					local questsGui = pg:FindFirstChild("Quests") or pg:WaitForChild("Quests", 5)
					local questsFrame = questsGui
						and (questsGui:FindFirstChild("Frame") or questsGui:WaitForChild("Frame", 5))
					if questsFrame and questsFrame:IsA("GuiObject") then
						frameToButton[questsFrame] = questsBtn
						buttonToFrame[questsBtn] = questsFrame
						-- Auto-bind CloseButton inside quests menu
						local qb = questsFrame:FindFirstChild("CloseButton", true)
						if qb and qb:IsA("GuiButton") then
							qb.MouseButton1Click:Connect(function()
								closeFrame(questsFrame, 0.25, {})
							end)
						end
						questsBtn.MouseButton1Click:Connect(function()
							local willOpen = not state.openFrames[questsFrame]
							buttonActiveOverride[questsBtn] = willOpen
							playClickFeedback(questsBtn, willOpen)
							toggleFrame(
								questsFrame,
								0.35,
								{ animType = "bounce", fovDelta = -15, blurSize = 18, switchCloseDuration = 0.15 }
							)
						end)
					end
				end
				-- Shop button -> open PlayerGui.Shop.CanvasGroup
				local shopBtn = findButton("Shop")
				if shopBtn then
					local shopGui = pg:FindFirstChild("Shop") or pg:WaitForChild("Shop", 5)
					local shopFrame = shopGui
						and (shopGui:FindFirstChild("CanvasGroup") or shopGui:WaitForChild("CanvasGroup", 5))
					if shopFrame and shopFrame:IsA("GuiObject") then
						frameToButton[shopFrame] = shopBtn
						buttonToFrame[shopBtn] = shopFrame
						-- Auto-bind CloseButton inside shop menu
						local cb = shopFrame:FindFirstChild("CloseButton", true)
						if cb and cb:IsA("GuiButton") then
							cb.MouseButton1Click:Connect(function()
								closeFrame(shopFrame, 0.25, {})
							end)
						end
						shopBtn.MouseButton1Click:Connect(function()
							local willOpen = not state.openFrames[shopFrame]
							buttonActiveOverride[shopBtn] = willOpen
							playClickFeedback(shopBtn, willOpen)
							toggleFrame(
								shopFrame,
								0.35,
								{ animType = "bounce", fovDelta = -15, blurSize = 18, switchCloseDuration = 0.15 }
							)
						end)
					end
				end
			end
		end
	end)
end

-- Optional: expose to _G for quick hooking from other scripts
_G.MenuAnimator = {
	open = openSettings,
	close = closeSettings,
	toggle = toggleSettings,
	openFrame = openFrame,
	closeFrame = closeFrame,
	toggleFrame = toggleFrame,
	register = function(button, frame, durationSec, animType, opts)
		if not (button and button:IsA("GuiButton")) then
			return
		end
		frameToButton[frame] = button
		if button:IsA("ImageButton") then
			buttonToFrame[button] = frame
		end
		button.MouseButton1Click:Connect(function()
			local options = opts or {}
			options.animType = animType or options.animType or "bounce"
			options.switchCloseDuration = options.switchCloseDuration or 0.15
			local willOpen = not state.openFrames[frame]
			if button:IsA("ImageButton") then
				buttonActiveOverride[button] = willOpen
				playClickFeedback(button, willOpen)
			end
			toggleFrame(frame, durationSec, options)
		end)
	end,
}

-- Auto-bind
task.defer(bindButtons)

-- Hover animations for UIButtons/CanvasGroup ImageButtons ---------------------
local function ensureUiScale(inst)
	local s = inst:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Scale = 1
		s.Parent = inst
	end
	return s
end

local function bindHoverAnimations()
	local pg = player:WaitForChild("PlayerGui")
	local uiButtons = pg:FindFirstChild("UIButtons") or pg:WaitForChild("UIButtons", 5)
	if not uiButtons then
		return
	end
	local canvas = uiButtons:FindFirstChild("CanvasGroup") or uiButtons:WaitForChild("CanvasGroup", 5)
	if not canvas then
		return
	end

	local function hook(btn)
		if not (btn and btn:IsA("ImageButton")) then
			return
		end
		local scale = ensureUiScale(btn)
		local tScale
		local tRot
		btn.MouseEnter:Connect(function()
			if tScale then
				tScale:Cancel()
			end
			if tRot then
				tRot:Cancel()
			end
			-- Hover: scale up; rotation only if active
			local targetScale = 1.1
			local targetRot = buttonActiveOverride[btn] and -10 or 0
			tScale = TweenService:Create(
				scale,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = targetScale }
			)
			tRot = TweenService:Create(
				btn,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Rotation = targetRot }
			)
			tScale:Play()
			tRot:Play()
		end)
		btn.MouseLeave:Connect(function()
			if tScale then
				tScale:Cancel()
			end
			if tRot then
				tRot:Cancel()
			end
			-- If forced active, keep active visuals on leave; else restore normal
			local targetScale = buttonActiveOverride[btn] and 1.1 or 1.0
			local targetRot = buttonActiveOverride[btn] and -10 or 0
			tScale = TweenService:Create(
				scale,
				TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = targetScale }
			)
			tRot = TweenService:Create(
				btn,
				TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Rotation = targetRot }
			)
			tScale:Play()
			tRot:Play()
		end)
	end

	-- Hook nested buttons: look for CanvasGroup/*/Button
	for _, child in ipairs(canvas:GetChildren()) do
		local btn = child:FindFirstChild("Button")
		if btn and btn:IsA("ImageButton") then
			hook(btn)
		end
	end
	canvas.DescendantAdded:Connect(function(d)
		if d:IsA("ImageButton") and d.Name == "Button" then
			hook(d)
		end
	end)
end

task.defer(bindHoverAnimations)
