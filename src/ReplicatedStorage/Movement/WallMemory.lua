-- Stores the last wall instance a character wall-jumped from.

local WallMemory = {}

local lastWallByCharacter = {}

function WallMemory.getLast(character)
	return lastWallByCharacter[character]
end

function WallMemory.setLast(character, wallInstance)
	lastWallByCharacter[character] = wallInstance
end

function WallMemory.clear(character)
	lastWallByCharacter[character] = nil
end

return WallMemory
