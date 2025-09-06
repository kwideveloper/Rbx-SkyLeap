-- HookSystemOptimizer.client.lua
-- Centralized hook system management for better performance and reduced duplication

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Movement.Config)
local player = Players.LocalPlayer

-- Cache for hook parts to avoid repeated CollectionService calls
local hookCache = {}
local lastCacheUpdate = 0
local CACHE_UPDATE_INTERVAL = 1.0 -- Update cache every second

-- Function to get cached hooks with automatic cache refresh
local function getHooksCached()
	local currentTime = os.clock()
	if currentTime - lastCacheUpdate >= CACHE_UPDATE_INTERVAL then
		hookCache = CollectionService:GetTagged(Config.HookTag or "Hookable")
		lastCacheUpdate = currentTime
	end
	return hookCache
end

-- Function to check if a part is in range (optimized version)
local function isInRangeOptimized(character, part, range)
	if not character or not part or not part:IsA("BasePart") or not part:IsDescendantOf(workspace) then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local distance = (part.Position - root.Position).Magnitude
	-- Get custom range for this hookable part (in studs)
	local customRange = part and part:GetAttribute("HookRange")
	local effectiveRange = (typeof(customRange) == "number" and customRange > 0) and customRange
		or (range or Config.HookDefaultRange or 90)
	return distance <= effectiveRange
end

-- Function to find the best target in range (optimized)
local function getBestTargetInRangeOptimized(character, hooks)
	local best, bestDist

	for _, part in ipairs(hooks) do
		-- Get custom range for this hookable part (in studs)
		local customRange = part and part:GetAttribute("HookRange")
		local range = (typeof(customRange) == "number" and customRange > 0) and customRange
			or (Config.HookDefaultRange or 90)

		if isInRangeOptimized(character, part, range) then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local d = (part.Position - root.Position).Magnitude
				if not bestDist or d < bestDist then
					best, bestDist = part, d
				end
			end
		end
	end
	return best
end

-- Function to get all hooks in range (optimized)
local function getHooksInRangeOptimized(character)
	local hooks = getHooksCached()
	local hooksInRange = {}

	for _, part in ipairs(hooks) do
		-- Get custom range for this hookable part (in studs)
		local customRange = part and part:GetAttribute("HookRange")
		local range = (typeof(customRange) == "number" and customRange > 0) and customRange
			or (Config.HookDefaultRange or 90)

		if isInRangeOptimized(character, part, range) then
			table.insert(hooksInRange, part)
		end
	end

	return hooksInRange
end

-- Export functions for use by other hook scripts
local HookSystemOptimizer = {
	getHooksCached = getHooksCached,
	isInRangeOptimized = isInRangeOptimized,
	getBestTargetInRangeOptimized = getBestTargetInRangeOptimized,
	getHooksInRangeOptimized = getHooksInRangeOptimized,
}

-- Initialize cache on startup
getHooksCached()

return HookSystemOptimizer
