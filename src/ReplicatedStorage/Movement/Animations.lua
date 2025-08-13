-- Central animation id registry for SkyLeap actions
-- Edit these ids to update animations globally.

local ContentProvider = game:GetService("ContentProvider")

local Animations = {
	-- Movement actions (leave empty string to use default Roblox character animations)
	Dash = "rbxassetid://109076026405774",

	-- Zipline
	ZiplineStart = "",
	ZiplineLoop = "",
	ZiplineEnd = "",

	-- Slide
	SlideStart = "rbxassetid://101238020195899",
	SlideLoop = "",
	SlideEnd = "",

	-- Jump / Air
	Jump = "",

	-- Run / Locomotion
	Run = "rbxassetid://129741854679661",

	-- Wall interactions
	WallRunLoop = "",
	WallJump = "",

	-- Climb (optional)
	ClimbStart = "",
	ClimbLoop = "",
	ClimbEnd = "",

	-- Crouch / Prone (hold Z)
	Crouch = "",
}

-- Internal cache of Animation instances by name
local animationCache = {}

-- Returns a reusable Animation instance for the given configured name
function Animations.get(name)
	local id = Animations[name]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local inst = animationCache[name]
	if inst == nil then
		inst = Instance.new("Animation")
		inst.AnimationId = id
		animationCache[name] = inst
	else
		-- Keep id in sync if table changed at runtime
		if inst.AnimationId ~= id then
			inst.AnimationId = id
		end
	end
	return inst
end

-- Returns an array of all configured Animation instances (non-empty ids)
function Animations.getAll()
	local list = {}
	for key, value in pairs(Animations) do
		if type(value) == "string" and value ~= "" then
			local inst = Animations.get(key)
			if inst then
				table.insert(list, inst)
			end
		end
	end
	return list
end

-- Preload all configured animations (client or server)
function Animations.preload()
	local assets = Animations.getAll()
	if #assets == 0 then
		return
	end
	pcall(function()
		ContentProvider:PreloadAsync(assets)
	end)
end

return Animations
