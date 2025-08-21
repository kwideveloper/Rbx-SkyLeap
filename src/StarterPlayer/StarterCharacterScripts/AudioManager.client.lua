-- Centralized audio manager for player SFX/music

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Movement.Config)
local Grapple = require(ReplicatedStorage.Movement.Grapple)

local player = Players.LocalPlayer

local state = {
	character = nil,
	humanoid = nil,
	root = nil,
	prevCombo = 0,
	commitActive = false,
	comboToken = 0,
	wasGrounded = true,
	-- Managed crawl loop sound instance
	crawlLoop = nil,
}

local function getSfxFolder()
	local ps = player:FindFirstChild("PlayerScripts") or player:WaitForChild("PlayerScripts")
	local soundsRoot = ps and ps:FindFirstChild("Sounds")
	local sfx = soundsRoot and soundsRoot:FindFirstChild("SFX")
	local playerFolder = sfx and sfx:FindFirstChild("Player")
	return playerFolder
end

-- Forward declare so it can be used above its definition
local getTemplate

local function getOrCreateCrawlLoop()
	local root = state.root
	if not root then
		return nil
	end
	if state.crawlLoop and state.crawlLoop.Parent then
		return state.crawlLoop
	end
	local template = getTemplate("Crawl")
	if not template then
		return nil
	end
	local s = template:Clone()
	s.Name = "CrawlLoop"
	s.Looped = true
	s.Parent = root
	-- Ensure it does not auto-play on creation; only play when moving
	s.Playing = false
	pcall(function()
		s:Pause()
	end)
	state.crawlLoop = s
	return s
end

local function destroyCrawlLoop()
	local s = state.crawlLoop
	if s then
		pcall(function()
			s:Stop()
			s:Destroy()
		end)
	end
	state.crawlLoop = nil
end

getTemplate = function(name)
	local folder = getSfxFolder()
	if not folder then
		return nil
	end
	local inst = folder:FindFirstChild(name)
	if inst and inst:IsA("Sound") and inst.IsLoaded == true then
		return inst
	end
	return nil
end

local function playOneShot(name, playbackSpeed)
	local root = state.root
	if not root then
		return
	end
	local template = getTemplate(name)
	if not template then
		return
	end
	local s = template:Clone()
	s.Name = template.Name
	s.Parent = root
	if typeof(playbackSpeed) == "number" and playbackSpeed > 0 then
		s.PlaybackSpeed = playbackSpeed
	end
	pcall(function()
		s:Play()
	end)
	s.Ended:Connect(function()
		pcall(function()
			s:Destroy()
		end)
	end)
	task.delay(6, function()
		pcall(function()
			if s and s.Parent then
				s:Destroy()
			end
		end)
	end)
end

-- Replace the default "Running" sound SoundId; let Roblox handle playback
local function overrideDefaultRunningSound(root)
	local function apply(sound)
		local tpl = getTemplate("Running")
		if tpl then
			sound.SoundId = tpl.SoundId
			sound.Volume = tpl.Volume
			pcall(function()
				sound.RollOffMaxDistance = tpl.RollOffMaxDistance
			end)
		else
			-- Fallback
			sound.SoundId = "rbxassetid://132180178897218"
			sound.Volume = 0.1
			pcall(function()
				sound.RollOffMaxDistance = 60
			end)
		end
	end
	local running = root:FindFirstChild("Running")
	if running and running:IsA("Sound") then
		apply(running)
	else
		task.spawn(function()
			local s = root:WaitForChild("Running", 5)
			if s and s:IsA("Sound") then
				apply(s)
			end
		end)
	end
	root.DescendantAdded:Connect(function(d)
		if d:IsA("Sound") and d.Name == "Running" then
			apply(d)
		end
	end)
end

local function disableDefaultFootsteps(humanoid)
	-- Roblox humanoids typically use internal footstep sounds; ensure they are not playing accidentally
	-- We keep the default Running sound (we override its SoundId). Mute any legacy custom run loops.
	local root = state.root
	if not root then
		return
	end
	for _, ch in ipairs(root:GetChildren()) do
		if ch:IsA("Sound") and ch.Name ~= "Running" then
			if ch.Name:lower():find("run") then
				ch.Playing = false
				ch.Volume = 0
			end
		end
	end
end

local function purgeComboClones()
	local root = state.root
	if not root then
		return
	end
	for _, d in ipairs(root:GetChildren()) do
		if d:IsA("Sound") and d.Name == "Combo" then
			pcall(function()
				d:Stop()
				d:Destroy()
			end)
		end
	end
end

local function bindJumpSounds(humanoid)
	if not humanoid then
		return
	end
	humanoid.StateChanged:Connect(function(_old, new)
		if new == Enum.HumanoidStateType.Jumping then
			-- First jump from ground -> Jump; any jump while airborne -> DoubleJump
			if state.wasGrounded then
				playOneShot("Jump")
			else
				playOneShot("DoubleJump")
			end
			state.wasGrounded = false
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			state.wasGrounded = true
		elseif new == Enum.HumanoidStateType.Freefall then
			state.wasGrounded = false
		end
	end)
end

local function setup()
	state.character = player.Character or player.CharacterAdded:Wait()
	state.humanoid = state.character:WaitForChild("Humanoid")
	state.root = state.character:WaitForChild("HumanoidRootPart")
	state.prevCombo = 0
	state.commitActive = false
	state.comboToken = state.comboToken or 0
	state.wasGrounded = true
	disableDefaultFootsteps(state.humanoid)
	overrideDefaultRunningSound(state.root)
	bindJumpSounds(state.humanoid)

	player.CharacterAdded:Connect(function(char)
		-- Cleanup any lingering crawl loop from previous character
		do
			local prev = state.crawlLoop
			if prev then
				pcall(function()
					prev:Stop()
					prev:Destroy()
				end)
			end
			state.crawlLoop = nil
		end
		state.character = char
		state.humanoid = char:WaitForChild("Humanoid")
		state.root = char:WaitForChild("HumanoidRootPart")
		state.prevCombo = 0
		state.commitActive = false
		state.comboToken = (state.comboToken or 0) + 1
		state.wasGrounded = true
		disableDefaultFootsteps(state.humanoid)
		overrideDefaultRunningSound(state.root)
		bindJumpSounds(state.humanoid)
	end)

	-- Adjust playback speed of default Running sound based on sprint state
	RunService.RenderStepped:Connect(function()
		local root = state.root
		if not root then
			return
		end
		local running = root:FindFirstChild("Running")
		local cs = ReplicatedStorage:FindFirstChild("ClientState")
		local isSprinting = cs and cs:FindFirstChild("IsSprinting") and cs.IsSprinting.Value or false
		local isCrawling = cs and cs:FindFirstChild("IsCrawling") and cs.IsCrawling.Value or false
		if running and running:IsA("Sound") then
			local desired = isSprinting and 1.35 or 0.85
			if math.abs((running.PlaybackSpeed or 1) - desired) > 1e-3 then
				running.PlaybackSpeed = desired
			end
			-- Mute default Running while crawling
			running.Volume = isCrawling and 0 or 0.2
		end

		-- Remove stray one-shot Crawl clones (safety)
		for _, d in ipairs(root:GetChildren()) do
			if d:IsA("Sound") and d.Name == "Crawl" then
				pcall(function()
					d:Stop()
					d:Destroy()
				end)
			end
		end

		-- Crawl loop management
		local humanoid = state.humanoid
		local moving = humanoid and humanoid.MoveDirection and (humanoid.MoveDirection.Magnitude > 0.05) or false
		if isCrawling then
			local loop = getOrCreateCrawlLoop()
			if loop then
				-- Speed up with Shift while crawling
				local shiftDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				local targetSpeed = shiftDown and 1.35 or 1.0
				if math.abs((loop.PlaybackSpeed or 1) - targetSpeed) > 1e-3 then
					loop.PlaybackSpeed = targetSpeed
				end
				if moving then
					if not loop.IsPlaying then
						local ok = pcall(function()
							loop:Resume()
						end)
						if not ok then
							pcall(function()
								loop:Play()
							end)
						end
					end
				else
					if loop.IsPlaying then
						pcall(function()
							loop:Pause()
						end)
					end
				end
			end
		else
			destroyCrawlLoop()
		end

		-- Hook/Grapple SFX on start
		local char = state.character
		if char then
			state._prevHookActive = state._prevHookActive or false
			local active = Grapple.isActive and Grapple.isActive(char) or false
			if active and not state._prevHookActive then
				playOneShot("Hook")
			end
			state._prevHookActive = active
		end
	end)

	-- Listen to ClientState booleans for one-shot SFX
	local cs = ReplicatedStorage:FindFirstChild("ClientState")
	if cs then
		local function bindBool(name, soundName)
			local v = cs:FindFirstChild(name)
			if v and v:IsA("BoolValue") then
				v.Changed:Connect(function()
					if v.Value == true then
						playOneShot(soundName)
					end
				end)
			end
		end
		bindBool("IsDashing", "Dash")
		bindBool("IsSliding", "Slide")
		bindBool("IsVaulting", "Vault")
		bindBool("IsMantling", "Mantle")
		-- Climb start
		local climb = cs:FindFirstChild("IsClimbing")
		if climb and climb:IsA("BoolValue") then
			climb.Changed:Connect(function()
				if climb.Value then
					playOneShot("Climb")
				end
			end)
		end
		-- Crawl enter: handled by managed loop; no one-shot
		local crawl = cs:FindFirstChild("IsCrawling")
		if crawl and crawl:IsA("BoolValue") then
			crawl.Changed:Connect(function()
				if not crawl.Value then
					destroyCrawlLoop()
				end
			end)
		end
		-- WallJump signal (optional BoolValue in ClientState)
		local wj = cs:FindFirstChild("IsWallJumping")
		if wj and wj:IsA("BoolValue") then
			wj.Changed:Connect(function()
				if wj.Value then
					playOneShot("WallJump")
				end
			end)
		end
		-- DoubleJump explicit signal (from ParkourController)
		local dj = cs:FindFirstChild("IsDoubleJumping")
		if dj and dj:IsA("BoolValue") then
			dj.Changed:Connect(function()
				if dj.Value then
					playOneShot("DoubleJump")
				end
			end)
		end
		-- Combo commit flash -> final sound and lock; cancel pending combo ticks and purge clones
		local comboFlash = cs:FindFirstChild("StyleCommittedFlash")
		if comboFlash and comboFlash:IsA("BoolValue") then
			comboFlash.Changed:Connect(function()
				if comboFlash.Value then
					playOneShot("StyleEnd")
					state.prevCombo = 0
					state.commitActive = true
					state.comboToken = (state.comboToken or 0) + 1
					purgeComboClones()
				end
			end)
		end
		-- Combo increment sound with progressive pitch, once per +1; muted while commitActive until StyleCombo==0
		local comboVal = cs:FindFirstChild("StyleCombo")
		if comboVal and comboVal:IsA("NumberValue") then
			comboVal.Changed:Connect(function()
				local cur = comboVal.Value or 0
				local prev = state.prevCombo or 0
				if state.commitActive then
					state.prevCombo = cur
					if cur == 0 then
						state.commitActive = false
						state.prevCombo = 0
					end
					return
				end
				if cur <= 0 then
					state.prevCombo = 0
					return
				end
				if cur > prev then
					local stepSize = 0.05
					local plays = cur - prev
					local token = state.comboToken or 0
					for i = 1, plays do
						local rank = prev + i
						local pitch = 1 + (stepSize * rank)
						task.delay((i - 1) * 0.03, function()
							if state.commitActive then
								return
							end
							if token ~= (state.comboToken or 0) then
								return
							end
							playOneShot("Combo", pitch)
						end)
					end
				end
				state.prevCombo = cur
			end)
		end
	end

	-- LaunchPad SFX via remote
	pcall(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local pad = remotes and remotes:FindFirstChild("PadTriggered")
		if pad and pad:IsA("RemoteEvent") then
			pad.OnClientEvent:Connect(function()
				playOneShot("LaunchPad")
			end)
		end
	end)
end

setup()
