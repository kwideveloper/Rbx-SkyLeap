-- Stamina handling utilities

local Config = require(game:GetService("ReplicatedStorage").Movement.Config)

local Stamina = {}

function Stamina.create()
	return {
		current = Config.StaminaMax,
		isSprinting = false,
	}
end

function Stamina.canStartSprint(stamina)
	return stamina.current >= Config.SprintStartThreshold
end

function Stamina.setSprinting(stamina, enabled)
	stamina.isSprinting = enabled and Stamina.canStartSprint(stamina)
	return stamina.isSprinting
end

function Stamina.tick(stamina, dt)
	if stamina.isSprinting then
		stamina.current = stamina.current - (Config.SprintDrainPerSecond * dt)
		if stamina.current <= 0 then
			stamina.current = 0
			stamina.isSprinting = false
		end
	else
		stamina.current = stamina.current + (Config.StaminaRegenPerSecond * dt)
		if stamina.current > Config.StaminaMax then
			stamina.current = Config.StaminaMax
		end
	end
	return stamina.current, stamina.isSprinting
end

-- Tick with explicit control over whether regeneration is allowed.
-- Draining still occurs when sprinting, but regen only happens when allowRegen is true.
function Stamina.tickWithGate(stamina, dt, allowRegen, isMoving)
	if stamina.isSprinting and (isMoving ~= false) then
		stamina.current = stamina.current - (Config.SprintDrainPerSecond * dt)
		if stamina.current <= 0 then
			stamina.current = 0
			stamina.isSprinting = false
		end
	elseif allowRegen then
		stamina.current = stamina.current + (Config.StaminaRegenPerSecond * dt)
		if stamina.current > Config.StaminaMax then
			stamina.current = Config.StaminaMax
		end
	end
	return stamina.current, stamina.isSprinting
end

return Stamina
