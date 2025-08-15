-- Stores the last wall instance a character wall-jumped from.

local WallMemory = {}

local lastWallByCharacter = {}
local wallChainCountByCharacter = {}

function WallMemory.getLast(character)
	return lastWallByCharacter[character]
end

function WallMemory.setLast(character, wallInstance)
	lastWallByCharacter[character] = wallInstance
end

function WallMemory.clear(character)
	lastWallByCharacter[character] = nil
	wallChainCountByCharacter[character] = 0
end

function WallMemory.getChainCount(character)
	return wallChainCountByCharacter[character] or 0
end

function WallMemory.bumpChain(character, wallInstance)
	if not character then
		return 0
	end
	local last = lastWallByCharacter[character]
	if last and wallInstance and last == wallInstance then
		wallChainCountByCharacter[character] = (wallChainCountByCharacter[character] or 0) + 1
	else
		lastWallByCharacter[character] = wallInstance
		wallChainCountByCharacter[character] = 1
	end
	return wallChainCountByCharacter[character]
end

return WallMemory
