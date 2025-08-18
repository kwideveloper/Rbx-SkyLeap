-- Disable collisions between player characters while keeping world collisions intact

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local GROUP_NAME = "PlayersNoCollide"

local function ensureCollisionGroup()
	-- Create the group if missing
	local ok, groups = pcall(function()
		return PhysicsService:GetRegisteredCollisionGroups()
	end)
	local found = false
	if ok then
		for _, g in ipairs(groups) do
			if g.name == GROUP_NAME then
				found = true
				break
			end
		end
	end
	if not found then
		pcall(function()
			PhysicsService:RegisterCollisionGroup(GROUP_NAME)
		end)
	end
	-- Ensure players in this group do not collide with each other
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(GROUP_NAME, GROUP_NAME, false)
	end)
end

local function setPartGroupIfBasePart(instance)
	if instance and instance:IsA("BasePart") then
		instance.CollisionGroup = GROUP_NAME
	end
end

local function applyCharacterNoCollide(character)
	if not character then
		return
	end
	-- Initial pass over existing descendants
	for _, descendant in ipairs(character:GetDescendants()) do
		setPartGroupIfBasePart(descendant)
	end
	-- Handle parts added later (e.g., accessories)
	character.DescendantAdded:Connect(function(descendant)
		setPartGroupIfBasePart(descendant)
	end)
end

-- Initialize group
ensureCollisionGroup()

-- Hook existing players (if any) then future joins
for _, plr in ipairs(Players:GetPlayers()) do
	if plr.Character then
		applyCharacterNoCollide(plr.Character)
	end
	plr.CharacterAdded:Connect(function(char)
		applyCharacterNoCollide(char)
	end)
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		applyCharacterNoCollide(char)
	end)
end)
