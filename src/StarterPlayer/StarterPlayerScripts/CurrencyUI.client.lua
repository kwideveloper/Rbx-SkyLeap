-- Currency UI binder: auto-binds TextLabels/TextButtons tagged as "Coin" or "Diamond"
-- Updates text to current balances and stays in sync via remotes

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CurrencyUpdated = Remotes:WaitForChild("CurrencyUpdated")
local RequestBalances = Remotes:WaitForChild("RequestBalances")

local CurrencyConfig = require(ReplicatedStorage:WaitForChild("Currency"):WaitForChild("Config"))

local state = {
	coins = 0,
	diamonds = 0,
}

local function isTextObject(inst)
	return inst and (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox"))
end

local bound = setmetatable({}, { __mode = "k" })

local function updateInstance(inst)
	if not isTextObject(inst) then
		return
	end
	if CollectionService:HasTag(inst, "Coin") then
		inst.Text = CurrencyConfig.formatCoins(state.coins)
		bound[inst] = true
	end
	if CollectionService:HasTag(inst, "Diamond") then
		inst.Text = CurrencyConfig.formatDiamonds(state.diamonds)
		bound[inst] = true
	end
end

local function updateAll()
	for _, tag in ipairs({ "Coin", "Diamond" }) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			updateInstance(inst)
		end
	end
end

-- Hook into tag changes dynamically
local function onInstanceAdded(inst)
	updateInstance(inst)
	inst.AncestryChanged:Connect(function()
		if not inst:IsDescendantOf(game) then
			bound[inst] = nil
		end
	end)
end

CollectionService:GetInstanceAddedSignal("Coin"):Connect(onInstanceAdded)
CollectionService:GetInstanceAddedSignal("Diamond"):Connect(onInstanceAdded)

-- Initial balances request
local function syncBalances()
	local ok, result = pcall(function()
		return RequestBalances:InvokeServer()
	end)
	if ok and type(result) == "table" then
		state.coins = tonumber(result.Coins) or state.coins
		state.diamonds = tonumber(result.Diamonds) or state.diamonds
		updateAll()
	end
end

syncBalances()

-- React to server updates
CurrencyUpdated.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.Coins ~= nil then
		state.coins = tonumber(payload.Coins) or state.coins
	end
	if payload.Diamonds ~= nil then
		state.diamonds = tonumber(payload.Diamonds) or state.diamonds
	end
	updateAll()
end)

-- Run a delayed update once PlayerGui likely mounted
task.delay(0.5, updateAll)
