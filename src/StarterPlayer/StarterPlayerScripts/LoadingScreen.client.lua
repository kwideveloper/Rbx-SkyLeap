local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Config = require(game.ReplicatedStorage.Movement.Config)

local player = Players.LocalPlayer
local loadingScreenGui = player:WaitForChild("PlayerGui"):WaitForChild("LoadingScreen")
local background = loadingScreenGui:WaitForChild("Background")
local mainContainer = loadingScreenGui:WaitForChild("MainContainer")
local logo = mainContainer:WaitForChild("Logo")
local gameTitle = mainContainer:WaitForChild("GameTitle")
local loadingText = mainContainer:WaitForChild("LoadingText")
local progressContainer = mainContainer:WaitForChild("ProgressContainer")
local progressBar = progressContainer:WaitForChild("ProgressBar")

local globalTweenDuration = 0.5
local logoTween
local gameTitleTween
local loadingTime = Config.LoadingScreenDuration or 4

if not Config.LoadingScreenEnabled then
	mainContainer.GroupTransparency = 1
	background.BackgroundTransparency = 1
	return
end

local function createTween(instance, delay, target, duration)
	local tweenInfo =
		TweenInfo.new(duration or globalTweenDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, delay)
	local tween = TweenService:Create(instance, tweenInfo, target)
	tween:Play()
	return tween -- Return the tween so we can listen to its completion
end

local function simulateTextProgress()
	local texts = {
		"Loading resources...",
		"Verifying game files..",
		"Initializing environment...",
		"Checking map integrity...",
		"Preparing dynamic platforms...",
		"Loading parkour system...",
		"Loading animations...",
		"Setting up player data...",
		"Syncing with server...",
		"Finalizing assets...",
		"Ready to leap!",
	}

	local totalTexts = #texts
	local interval = loadingTime / totalTexts

	-- Subtle text fade animation using TweenService
	local function animateTextFadeOutIn(newText)
		local fadeOutTween = TweenService:Create(
			loadingText,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 1 }
		)
		local fadeInTween = TweenService:Create(
			loadingText,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 0 }
		)

		fadeOutTween.Completed:Connect(function()
			loadingText.Text = newText
			fadeInTween:Play()
		end)
		fadeOutTween:Play()
	end

	coroutine.wrap(function()
		for i, text in ipairs(texts) do
			if i == 1 then
				loadingText.TextTransparency = 1
				loadingText.Text = text
				TweenService:Create(
					loadingText,
					TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ TextTransparency = 0 }
				):Play()
			else
				animateTextFadeOutIn(text)
			end
			wait(interval)
		end
	end)()
end

local function animateLoadingScreen()
	createTween(background, 0, { BackgroundTransparency = 0 })
	local logoTween = createTween(logo, 0.2, { ImageTransparency = 0 })

	-- When logo animation completes, start game title animation
	logoTween.Completed:Connect(function()
		createTween(gameTitle, 0, { TextTransparency = 0 }).Completed:Connect(function()
			createTween(progressContainer, 0, { GroupTransparency = 0 }).Completed:Connect(function()
				local progressBarTween = createTween(progressBar, 0, { Size = UDim2.fromScale(1, 1) }, loadingTime)
				simulateTextProgress()
				progressBarTween.Completed:Connect(function()
					createTween(mainContainer, 0.5, { GroupTransparency = 1 })
					createTween(background, 0.5, { BackgroundTransparency = 1 }).Completed:Connect(function()
						loadingScreenGui:Destroy()
					end)
				end)
			end)
		end)
	end)
end

animateLoadingScreen()
