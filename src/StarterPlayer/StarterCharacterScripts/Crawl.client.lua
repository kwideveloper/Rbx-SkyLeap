-- Crawl toggle (Z) for SkyLeap
-- Resizes `CollisionPart` height, raises it by +1 stud via joint while crawling, and plays crawl animations

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Movement.Config)
local Animations = require(ReplicatedStorage.Movement.Animations)

local LOCAL_PLAYER = Players.LocalPlayer

local function getCharacter()
	local character = LOCAL_PLAYER.Character or LOCAL_PLAYER.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")
	return character, humanoid, root
end

local state = {
	character = nil,
	humanoid = nil,
	root = nil,
	isCrawling = false,
	conn = nil,
	origWalkSpeed = nil,
	origCameraOffset = nil,
	collisionPart = nil,
	origCollisionSize = nil,
	collisionJoint = nil,
	origJointC0 = nil,
	origJointC1 = nil,
	wantExit = false,
	tracks = {
		idle = nil,
		move = nil,
	},
}

local function loadTracks()
	if not state.humanoid then
		return
	end
	local idleAnim = Animations.get("CrawlIdle")
	local moveAnim = Animations.get("CrawlMove")
	if idleAnim then
		state.tracks.idle = state.humanoid:LoadAnimation(idleAnim)
		state.tracks.idle.Priority = Enum.AnimationPriority.Movement
	end
	if moveAnim then
		state.tracks.move = state.humanoid:LoadAnimation(moveAnim)
		state.tracks.move.Priority = Enum.AnimationPriority.Movement
	end
end

local function stopAllTracks()
	for _, t in pairs(state.tracks) do
		if t then
			pcall(function()
				t:Stop(0.15)
			end)
		end
	end
end

local function playIdle()
	if state.tracks.move and state.tracks.move.IsPlaying then
		state.tracks.move:Stop(0.1)
	end
	if state.tracks.idle and not state.tracks.idle.IsPlaying then
		state.tracks.idle:Play(0.1, 1, 1)
	end
end

local function playMove()
	if state.tracks.idle and state.tracks.idle.IsPlaying then
		state.tracks.idle:Stop(0.1)
	end
	if state.tracks.move and not state.tracks.move.IsPlaying then
		state.tracks.move:Play(0.1, 1, 1)
	end
end

local function findCollisionPart()
	if not state.character then
		return nil
	end
	-- Respect a pre-existing character hitbox named `CollisionPart`
	return state.character:FindFirstChild("CollisionPart")
end

-- Note: Do not reposition `CollisionPart` during crawl to avoid pulling the character assembly downward

local function hasStandClearance()
	local root = state.root
	local cp = state.collisionPart
	if not root then
		return true
	end
	local currentHeight = (cp and cp.Size and cp.Size.Y) or (Config.CrawlRootHeight or 2)
	local standHeight = (state.origCollisionSize and state.origCollisionSize.Y)
	if type(standHeight) ~= "number" or standHeight <= 0 then
		standHeight = Config.CrawlStandUpHeight or 2
	end
	local extra = math.max(0, standHeight - currentHeight)
	if extra <= 0.05 then
		return true
	end
	local side = Config.CrawlStandProbeSideWidth or (root.Size and root.Size.X) or 1
	local forward = Config.CrawlStandProbeForwardDepth or 0.25
	local up = root.CFrame.UpVector
	local right = root.CFrame.RightVector
	local look = root.CFrame.LookVector
	local center = root.Position + up * (currentHeight * 0.5 + extra * 0.5) + look * (forward * 0.5)
	local boxCFrame = CFrame.fromMatrix(center, right, up, look)
	local size = Vector3.new(side, extra, forward)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { state.character }
	params.RespectCanCollide = true
	local parts = workspace:GetPartBoundsInBox(boxCFrame, size, params)
	return #parts == 0
end

local function exitCrawl()
	if not state.isCrawling then
		return
	end
	state.isCrawling = false
	state.wantExit = false
	-- Update ClientState to sync with other systems
	local cs = game:GetService("ReplicatedStorage"):FindFirstChild("ClientState")
	local isCrawlingValue = cs and cs:FindFirstChild("IsCrawling")
	if isCrawlingValue then
		isCrawlingValue.Value = false
	end
	if state.conn then
		state.conn:Disconnect()
		state.conn = nil
	end
	if state.collisionPart and state.origCollisionSize then
		state.collisionPart.Size = state.origCollisionSize
	end
	-- Restore joint offset if we adjusted it
	if state.collisionJoint then
		local j = state.collisionJoint
		pcall(function()
			if state.origJointC0 then
				j.C0 = state.origJointC0
			end
			if state.origJointC1 then
				j.C1 = state.origJointC1
			end
		end)
	end
	stopAllTracks()
	if state.humanoid then
		state.humanoid.WalkSpeed = state.origWalkSpeed or state.humanoid.WalkSpeed
		-- Restore jump height
		state.humanoid.JumpHeight = 7.2 -- Default Roblox jump height
		-- Smooth camera offset back out of crawl
		do
			local start = state.humanoid.CameraOffset
			local target = state.origCameraOffset or Vector3.new()
			local dur = math.max(0, Config.CrawlCameraLerpSeconds or 0.12)
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < dur do
					local alpha = (os.clock() - t0) / math.max(dur, 0.001)
					alpha = math.clamp(alpha, 0, 1)
					local y = start.Y + (target.Y - start.Y) * alpha
					state.humanoid.CameraOffset = Vector3.new(0, y, 0)
					RunService.Heartbeat:Wait()
				end
				state.humanoid.CameraOffset = target
			end)
		end
	end
	-- Clear references for next character
	state.collisionPart = nil
	state.origCollisionSize = nil
	state.collisionJoint = nil
	state.origJointC0 = nil
	state.origJointC1 = nil
end

local function enterCrawl(autoActivated)
	if state.isCrawling then
		return
	end
	if not state.humanoid or not state.root then
		return
	end
	if state.humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	state.isCrawling = true
	state.wantExit = autoActivated or false -- If auto-activated, set wantExit to true for auto-exit
	state.origWalkSpeed = state.humanoid.WalkSpeed
	state.origCameraOffset = state.humanoid.CameraOffset
	state.humanoid.WalkSpeed = Config.CrawlSpeed or 10
	-- Update ClientState to sync with other systems
	local cs = game:GetService("ReplicatedStorage"):FindFirstChild("ClientState")
	local isCrawlingValue = cs and cs:FindFirstChild("IsCrawling")
	if isCrawlingValue then
		isCrawlingValue.Value = true
	end
	-- Disable sprint state when entering crawl to prevent speed ramping
	local isSprintingValue = cs and cs:FindFirstChild("IsSprinting")
	if isSprintingValue then
		isSprintingValue.Value = false
	end
	-- Smooth camera offset into crawl
	do
		local start = state.humanoid.CameraOffset
		local target = Vector3.new(0, Config.ProneCameraOffsetY or -2.5, 0)
		local dur = math.max(0, Config.CrawlCameraLerpSeconds or 0.12)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < dur do
				local alpha = (os.clock() - t0) / math.max(dur, 0.001)
				alpha = math.clamp(alpha, 0, 1)
				local y = start.Y + (target.Y - start.Y) * alpha
				state.humanoid.CameraOffset = Vector3.new(0, y, 0)
				RunService.Heartbeat:Wait()
			end
			state.humanoid.CameraOffset = target
		end)
	end
	state.collisionPart = findCollisionPart()
	if state.collisionPart then
		-- Check if we're being activated from slide system
		local cs = game:GetService("ReplicatedStorage"):FindFirstChild("ClientState")
		local slideOriginalSize = cs and cs:FindFirstChild("SlideOriginalSize")
		if slideOriginalSize and slideOriginalSize.Value and autoActivated then
			-- Use the original size from slide system
			state.origCollisionSize = slideOriginalSize.Value
		elseif not state.origCollisionSize then
			-- Use current size as fallback
			state.origCollisionSize = state.collisionPart.Size
		end
	end
	if state.collisionPart and state.origCollisionSize then
		local newY = math.max(Config.CrawlRootHeight or 2, 0.5)
		state.collisionPart.Size = Vector3.new(state.origCollisionSize.X, newY, state.origCollisionSize.Z)
	end
	-- Try to raise CollisionPart by +1 stud using its joint (no anchoring/decouple)
	if not state.collisionJoint and state.collisionPart then
		local chosen = nil
		for _, d in ipairs(state.character:GetDescendants()) do
			if d:IsA("Weld") or d:IsA("Motor6D") then
				if d.Part0 == state.collisionPart or d.Part1 == state.collisionPart then
					chosen = d
					-- Prefer joint connected directly to HumanoidRootPart if multiple
					local other = (d.Part0 == state.collisionPart) and d.Part1 or d.Part0
					if other == state.root then
						break
					end
				end
			end
		end
		if chosen then
			state.collisionJoint = chosen
			state.origJointC0 = chosen.C0
			state.origJointC1 = chosen.C1
			-- Apply +1 stud along joint's local up towards world Y (approx)
			if chosen.Part0 == state.collisionPart then
				chosen.C0 = chosen.C0 * CFrame.new(0, 1, 0)
			else
				chosen.C1 = chosen.C1 * CFrame.new(0, 1, 0)
			end
		end
	end
	-- Drive animations each frame and keep alignment
	if state.conn then
		state.conn:Disconnect()
	end
	state.conn = RunService.Heartbeat:Connect(function()
		-- Auto-exit when leaving ground
		if state.humanoid.FloorMaterial == Enum.Material.Air then
			return -- wait until airborne settles; exit in Heartbeat below for reliability
		end
		-- Handle crawl speed based on sprint input
		local isSprintPressed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		local targetSpeed = isSprintPressed and (Config.CrawlRunSpeed or 20) or (Config.CrawlSpeed or 10)
		-- Force crawl speed every frame to prevent other systems from overriding it
		-- Also disable sprint state to prevent ParkourController from ramping speed
		local cs = game:GetService("ReplicatedStorage"):FindFirstChild("ClientState")
		local isSprintingValue = cs and cs:FindFirstChild("IsSprinting")
		if isSprintingValue and isSprintingValue.Value then
			isSprintingValue.Value = false
		end
		state.humanoid.WalkSpeed = targetSpeed
		-- Disable jumping while crawling
		state.humanoid.JumpHeight = 0
		local moving = state.humanoid.MoveDirection and state.humanoid.MoveDirection.Magnitude > 0.05
		if moving then
			playMove()
		else
			playIdle()
		end
		-- If user requested exit, attempt auto-stand when there is clearance
		if state.wantExit and hasStandClearance() then
			exitCrawl()
		end
	end)
	-- Separate check to exit safely when airborne
	RunService.Heartbeat:Wait()
	if state.isCrawling and state.humanoid.FloorMaterial == Enum.Material.Air then
		-- Exit if we immediately became airborne
		exitCrawl()
	end
end

local function onInputBegan(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Z then
		if state.isCrawling then
			-- Request exit: only stand when clearance is available
			state.wantExit = true
			-- Try immediate exit if clear now
			if hasStandClearance() then
				exitCrawl()
			end
		else
			enterCrawl(false) -- false = manually activated
		end
	end
end

local function setup()
	state.character, state.humanoid, state.root = getCharacter()
	Animations.preload()
	loadTracks()
	-- Reset on death/respawn
	state.humanoid.Died:Connect(function()
		exitCrawl()
	end)
	LOCAL_PLAYER.CharacterAdded:Connect(function()
		exitCrawl()
		state.character, state.humanoid, state.root = getCharacter()
		loadTracks()
	end)
	UserInputService.InputBegan:Connect(onInputBegan)
	-- Safety: leave crawl if we jump or become airborne
	RunService.Heartbeat:Connect(function()
		if state.isCrawling and state.humanoid and state.humanoid.FloorMaterial == Enum.Material.Air then
			exitCrawl()
		end
	end)

	-- Listen for automatic crawl activation from slide system
	local function checkForAutoCrawl()
		local cs = game:GetService("ReplicatedStorage"):FindFirstChild("ClientState")
		if cs then
			local shouldActivateCrawl = cs:FindFirstChild("ShouldActivateCrawl")
			if shouldActivateCrawl and shouldActivateCrawl.Value and not state.isCrawling then
				shouldActivateCrawl.Value = false
				enterCrawl(true) -- true = auto-activated
			end
		end
	end

	-- Check for auto-crawl every frame
	RunService.Heartbeat:Connect(checkForAutoCrawl)
end

setup()
