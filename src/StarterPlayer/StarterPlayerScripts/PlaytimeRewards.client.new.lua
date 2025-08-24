-- PlayTime Rewards UI binder: clones Template cards, keeps countdowns live,
-- adjusts ScrollingFrame.CanvasSize, and handles claim actions.
-- Now uses the global RewardAnimations system

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RF_Request = Remotes:WaitForChild("PlaytimeRequest")
local RF_Claim = Remotes:WaitForChild("PlaytimeClaim")

local RewardsConfig = require(ReplicatedStorage:WaitForChild("Rewards"):WaitForChild("PlaytimeConfig"))

-- Import global reward animation system
local RewardAnimations = require(ReplicatedStorage:WaitForChild("Currency"):WaitForChild("RewardAnimations"))

-- Global state variables
local allCards = {}
local baseElapsed = 0
local renderClock = 0
local gradientTweens = {} -- To track gradient rotation tweens

-- Forward declaration for render function
local render

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%02d:%02d:%02d", h, m, s)
	end
	return string.format("%02d:%02d", m, s)
end

local function getGui()
	local root = playerGui:FindFirstChild("PlayTimeRewards")
	if not root then
		return nil
	end
	local frame = root:FindFirstChild("Frame")
	local scroll = frame and frame:FindFirstChild("ScrollingFrame")
	return root, frame, scroll
end

local function applyState(container, state, remaining, showButtonTime)
	-- All active/claimable cards have opaque background, others transparent
	container.BackgroundTransparency = (state == "Active" or state == "Claimable") and 0 or 1
	local claimedGrad = container:FindFirstChild("ClaimedGradient")
	local activeGrad = container:FindFirstChild("ActiveGradient")
	local activeText = container:FindFirstChild("Time")
	if state == "Active" or state == "Claimable" or state == "Completed" then
		container.BackgroundTransparency = 0
		activeText.TextTransparency = 1
	end

	if claimedGrad and claimedGrad:IsA("UIGradient") then
		claimedGrad.Enabled = (state == "Completed")
	end
	if activeGrad and activeGrad:IsA("UIGradient") then
		-- All claimable items have ActiveGradient, only next shows button time
		local shouldEnable = (state == "Active" or state == "Claimable")
		activeGrad.Enabled = shouldEnable

		-- Start infinite rotation for claimable items
		if shouldEnable and state == "Claimable" then
			if not gradientTweens[activeGrad] then
				local tweenInfo = TweenInfo.new(
					2, -- Duration (2 seconds for full rotation)
					Enum.EasingStyle.Linear,
					Enum.EasingDirection.InOut,
					-1, -- Infinite repetitions
					false
				)
				local goal = { Rotation = 360 }
				local tween = TweenService:Create(activeGrad, tweenInfo, goal)
				gradientTweens[activeGrad] = tween
				tween:Play()
			end
		else
			-- Stop rotation if not claimable
			if gradientTweens[activeGrad] then
				gradientTweens[activeGrad]:Cancel()
				gradientTweens[activeGrad] = nil
				activeGrad.Rotation = 0
			end
		end
	end
	local completedMark = container:FindFirstChild("Completed")
	local image = container:FindFirstChild("Image")
	if completedMark and completedMark:IsA("ImageLabel") then
		completedMark.ImageTransparency = (state == "Completed") and 0 or 1
		image.ImageTransparency = (state == "Completed") and 0.3 or 0
	end
	local btn
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("TextButton") then
			btn = d
			break
		end
	end
	if btn then
		local tf = btn:FindFirstChild("TextFrame")
		local tl = tf and tf:FindFirstChildWhichIsA("TextLabel")
		if tl then
			if state == "Completed" then
				tl.Text = "CLAIMED"
			elseif state == "Claimable" then
				tl.Text = "CLAIM"
			elseif state == "Active" then
				if showButtonTime then
					tl.Text = formatTime(remaining or 0)
				else
					tl.Text = "WAITING"
				end
			else
				tl.Text = "WAITING"
			end
		end
		if tf then
			if state == "Claimable" then
				tf.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
			else
				-- Reset to default color for non-claimable states
				tf.BackgroundColor3 = Color3.fromRGB(60, 60, 60) -- Default gray color, adjust as needed
			end
		end
		btn.Active = (state == "Claimable")
		btn.AutoButtonColor = (state == "Claimable")
	end
end

local function updateNotificationBadge(claimableCount)
	-- Find notification badge in the specific path: PlayerGui/UIButtons/CanvasGroup/PlayTimeRewards/Button/Notification
	local uiButtons = playerGui:FindFirstChild("UIButtons")
	if not uiButtons then
		return
	end

	local canvasGroup = uiButtons:FindFirstChild("CanvasGroup")
	if not canvasGroup then
		return
	end

	local playTimeRewards = canvasGroup:FindFirstChild("PlayTimeRewards")
	if not playTimeRewards then
		return
	end

	local button = playTimeRewards:FindFirstChild("Button")
	if not button then
		return
	end

	local notification = button:FindFirstChild("Notification")
	if not notification then
		return
	end

	local textLabel = notification:FindFirstChild("TextLabel")

	if claimableCount > 0 then
		notification.Visible = true
		if textLabel and textLabel:IsA("TextLabel") then
			textLabel.Text = tostring(claimableCount)
		end
	else
		notification.Visible = false
	end
end

local function adjustCanvas(container)
	local scroll = container:FindFirstChild("ScrollingFrame")
	if not scroll then
		return
	end
	local layout = scroll:FindFirstChildOfClass("UIGridLayout") or scroll:FindFirstChildOfClass("UIListLayout")
	if not layout then
		return
	end
	local function apply()
		local size = layout.AbsoluteContentSize
		scroll.CanvasSize = UDim2.new(0, size.X, 0, size.Y + 40)
	end
	apply()
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(apply)
end

local function ensureCountdownLoop()
	if allCards._loop then
		return
	end
	allCards._loop = true
	RunService.Heartbeat:Connect(function()
		if not next(allCards) then
			return
		end
		local curElapsed = baseElapsed + (os.clock() - renderClock)
		for card, meta in pairs(allCards) do
			if type(meta) == "table" and card and card.Parent then
				if not meta.claimed then
					local remain = math.max(0, (meta.seconds or 0) - curElapsed)
					if meta.timeLabel then
						meta.timeLabel.Text = formatTime(remain)
					end
					if meta.state == "Active" and meta.isNext then
						if meta.buttonLabel and meta.showButtonTime then
							meta.buttonLabel.Text = formatTime(remain)
						end
						if remain <= 0 then
							meta.state = "Claimable"
							applyState(card, "Claimable", 0, meta.showButtonTime)
							if meta.button and not meta._boundClaim then
								meta._boundClaim = true
								meta.button.MouseButton1Click:Connect(function()
									local ok, res = pcall(function()
										return RF_Claim:InvokeServer(meta.index)
									end)
									if ok and type(res) == "table" and res.ok then
										-- Use global animation system
										RewardAnimations.spawnRewardBurst(
											meta.rewardAmount,
											meta.rewardType,
											nil,
											meta.button
										)

										-- Re-render after successful claim
										task.defer(function()
											task.wait(0.1)
											-- Clear this card from the loop and trigger a fresh render
											allCards[card] = nil
											task.defer(function()
												if render then
													render()
												end
											end)
										end)
									end
								end)
							end
						end
					end
				end
			end
		end
	end)
end

render = function()
	local ok, payload = pcall(function()
		return RF_Request:InvokeServer()
	end)
	if not ok or type(payload) ~= "table" then
		return
	end
	baseElapsed = tonumber(payload.elapsed) or 0
	renderClock = os.clock()
	local root, frame, scroll = getGui()
	if not (frame or scroll) then
		return
	end
	local parentContainer = scroll or frame
	local template
	for _, child in ipairs(parentContainer:GetChildren()) do
		if child:IsA("Frame") and CollectionService:HasTag(child, "Template") then
			template = child
			break
		end
	end
	if not template then
		template = parentContainer:FindFirstChild("Template")
	end
	if not template then
		return
	end
	-- Remove only previously created cards; keep layout/UI objects intact
	for _, ch in ipairs(parentContainer:GetChildren()) do
		if ch ~= template and ch:GetAttribute("IsPlaytimeCard") == true then
			ch:Destroy()
		end
	end
	for k in pairs(allCards) do
		if k ~= "_loop" then
			allCards[k] = nil
		end
	end

	-- Count claimable rewards for notification badge (all that reached 0 time)
	local claimableCount = 0
	for _, r in ipairs(payload.rewards or {}) do
		if not r.claimed then
			local remaining = math.max(0, (r.seconds or 0) - baseElapsed)
			if remaining <= 0 then
				claimableCount = claimableCount + 1
			end
		end
	end

	for _, r in ipairs(payload.rewards or {}) do
		local clone = template:Clone()
		clone.Name = "Reward_" .. tostring(r.index)
		clone.Visible = true
		clone:SetAttribute("IsPlaytimeCard", true)
		clone.Parent = parentContainer
		local img = clone:FindFirstChild("Image")
		if img and img:IsA("ImageLabel") and r.image then
			img.Image = r.image
		end
		local rewardText = clone:FindFirstChild("Reward")
		if rewardText and rewardText:IsA("TextLabel") then
			rewardText.Text = RewardsConfig.formatReward({ amount = r.amount, type = r.type })
		end
		local timeText = clone:FindFirstChild("Time")
		local remaining = math.max(0, (r.seconds or 0) - baseElapsed)
		if timeText and timeText:IsA("TextLabel") then
			timeText.Text = formatTime(remaining)
		end
		local state = "Waiting"
		if r.claimed then
			state = "Completed"
		else
			if remaining <= 0 then
				state = "Claimable" -- All that reached time are claimable
			elseif r.next then
				state = "Active" -- Only next in sequence shows as active
			else
				state = "Waiting" -- Future rewards show waiting
			end
		end
		applyState(clone, state, remaining, r.next == true)
		local btn
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("TextButton") then
				btn = d
			end
		end
		if state == "Claimable" then
			if btn then
				btn.MouseButton1Click:Connect(function()
					print("DEBUG: Claim button clicked for reward", r.index, r.amount, r.type)
					local ok, res = pcall(function()
						return RF_Claim:InvokeServer(r.index)
					end)
					print("DEBUG: Claim response", ok, res)
					if ok and type(res) == "table" and res.ok then
						print("DEBUG: Triggering animation for", r.amount, r.type)
						-- Use global animation system
						RewardAnimations.spawnRewardBurst(r.amount, r.type, nil, btn)

						-- Re-render after successful claim
						task.defer(function()
							task.wait(0.1)
							-- Get fresh data from server and re-render
							local ok2, payload2 = pcall(function()
								return RF_Request:InvokeServer()
							end)
							if ok2 and type(payload2) == "table" then
								-- Clear current cards and re-render with fresh data
								for k in pairs(allCards) do
									if k ~= "_loop" then
										allCards[k] = nil
									end
								end
								-- Trigger a fresh render by calling the render function at the bottom
								task.defer(function()
									if render then
										render()
									end
								end)
							end
						end)
					end
				end)
			end
		end
		allCards[clone] = {
			index = r.index,
			seconds = r.seconds,
			timeLabel = timeText,
			button = btn,
			state = state,
			claimed = (state == "Completed"),
			isNext = (r.next == true),
			showButtonTime = (r.next == true),
			rewardType = r.type,
			rewardAmount = r.amount,
			buttonLabel = (function()
				local tf = btn and btn:FindFirstChild("TextFrame")
				return tf and tf:FindFirstChildWhichIsA("TextLabel") or nil
			end)(),
		}
	end
	if frame then
		adjustCanvas(frame)
	end
	ensureCountdownLoop()

	-- Update notification badge
	updateNotificationBadge(claimableCount)
end

-- Render on spawn and when the GUI appears
render()
playerGui.ChildAdded:Connect(function(child)
	if child.Name == "PlayTimeRewards" then
		task.defer(render)
	end
end)
