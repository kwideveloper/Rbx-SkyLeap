-- Server-side LedgeHang synchronization system
-- Handles multiplayer synchronization of ledge hanging state and movement

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LedgeHangStart = Remotes:WaitForChild("LedgeHangStart")
local LedgeHangMove = Remotes:WaitForChild("LedgeHangMove")
local LedgeHangStop = Remotes:WaitForChild("LedgeHangStop")

-- Store active ledge hangs for each player
local activeHangs = {} -- [player] = hangData

-- LedgeHang data structure
local function createHangData(character, hangPosition, ledgeY, forwardDirection, surfaceNormal, ledgeInstance)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	return {
		character = character,
		hangPosition = hangPosition,
		ledgeY = ledgeY,
		forwardDirection = forwardDirection,
		surfaceNormal = surfaceNormal,
		ledgeInstance = ledgeInstance,
		startTime = os.clock(),
		lastMoveTime = os.clock(),
	}
end

-- Handle ledge hang start
LedgeHangStart.OnServerEvent:Connect(
	function(player, hangPosition, ledgeY, forwardDirection, surfaceNormal, ledgeInstance)
		local character = player.Character
		if not character then
			return
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			return
		end

		-- Validate the ledge hang request
		-- Basic validation - you can add more sophisticated checks here
		if not hangPosition or not ledgeY or not forwardDirection then
			return
		end

		-- Calculate precise ledge edge position using the character's approach position
		-- This ensures the character grabs exactly at the edge where they reached the ledge
		local characterHalfHeight = (root.Size and root.Size.Y or 2) * 0.5
		-- Use the ledgeY passed as parameter (already calculated correctly in detection)
		-- Don't recalculate as it might use wall position instead of ledge position

		local characterPos = root.Position
		local ledgeSize = ledgeInstance.Size
		local ledgeCFrame = ledgeInstance.CFrame

		-- Calculate ledge edge position based on LedgeFace attribute
		local Config = require(game:GetService("ReplicatedStorage").Movement.Config)
		local actualHangPosition = Vector3.new(characterPos.X, characterPos.Y, characterPos.Z)
		local ledgeFace = ledgeInstance:GetAttribute("LedgeFace")

		if ledgeFace then
			local localPos = ledgeCFrame:PointToObjectSpace(characterPos)
			local localLedgePos

			if ledgeFace == "Front" then
				localLedgePos = Vector3.new(localPos.X, ledgeSize.Y / 2, ledgeSize.Z / 2)
			elseif ledgeFace == "Back" then
				localLedgePos = Vector3.new(localPos.X, ledgeSize.Y / 2, -ledgeSize.Z / 2)
			elseif ledgeFace == "Left" then
				localLedgePos = Vector3.new(-ledgeSize.X / 2, ledgeSize.Y / 2, localPos.Z)
			elseif ledgeFace == "Right" then
				localLedgePos = Vector3.new(ledgeSize.X / 2, ledgeSize.Y / 2, localPos.Z)
			else
				localLedgePos = Vector3.new(localPos.X, ledgeSize.Y / 2, localPos.Z)
			end

			local ledgePos = ledgeCFrame:PointToWorldSpace(localLedgePos)
			-- Apply LedgeHangDistance to move away from wall and LedgeHangDropDistance to position below ledge
			local hangDistance = Config.LedgeHangDistance or 1.2
			local dropDistance = Config.LedgeHangDropDistance or 0.8
			local awayFromWall = surfaceNormal * hangDistance
			actualHangPosition = Vector3.new(
				ledgePos.X + awayFromWall.X,
				ledgeY - characterHalfHeight - dropDistance,
				ledgePos.Z + awayFromWall.Z
			)
		else
			-- Fallback: use hit position if no LedgeFace attribute
			local localPos = ledgeCFrame:PointToObjectSpace(hangPosition)
			local localLedgePos = Vector3.new(localPos.X, ledgeSize.Y / 2, localPos.Z)
			local ledgePos = ledgeCFrame:PointToWorldSpace(localLedgePos)
			-- Apply LedgeHangDistance to move away from wall and LedgeHangDropDistance to position below ledge
			local hangDistance = Config.LedgeHangDistance or 1.2
			local dropDistance = Config.LedgeHangDropDistance or 0.8
			local awayFromWall = surfaceNormal * hangDistance
			actualHangPosition = Vector3.new(
				ledgePos.X + awayFromWall.X,
				ledgeY - characterHalfHeight - dropDistance,
				ledgePos.Z + awayFromWall.Z
			)
		end

		-- Calculate ledge offset for proper orientation
		local ledgeOffset = CFrame.lookAt(actualHangPosition, actualHangPosition - surfaceNormal)

		-- Create hang data
		local hangData =
			createHangData(character, actualHangPosition, ledgeY, forwardDirection, surfaceNormal, ledgeInstance)
		if not hangData then
			return
		end

		-- Store the hang state
		activeHangs[player] = hangData

		-- Set character state on server
		humanoid.AutoRotate = false
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)

		-- Position character on server at their actual position
		root.CFrame = CFrame.lookAt(actualHangPosition, actualHangPosition + forwardDirection)
		root.AssemblyLinearVelocity = Vector3.new()
		root.Anchored = true

		-- Disable collisions for other parts
		for _, part in ipairs(character:GetChildren()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.CanCollide = false
			end
		end

		-- Broadcast to all other clients using actual position
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer ~= player then
				LedgeHangStart:FireClient(
					otherPlayer,
					player,
					actualHangPosition,
					ledgeY,
					forwardDirection,
					surfaceNormal
				)
			end
		end

		print("[LedgeHangSync] Player", player.Name, "started ledge hang at", actualHangPosition)
	end
)

-- Handle ledge hang movement
LedgeHangMove.OnServerEvent:Connect(function(player, newPosition, forwardDirection)
	local hangData = activeHangs[player]
	if not hangData then
		return
	end

	local character = player.Character
	if not character then
		activeHangs[player] = nil
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		activeHangs[player] = nil
		return
	end

	-- Update hang data
	hangData.hangPosition = newPosition
	hangData.forwardDirection = forwardDirection
	hangData.lastMoveTime = os.clock()

	-- Update character position on server
	root.CFrame = CFrame.lookAt(newPosition, newPosition + forwardDirection)

	-- Update hang data position
	hangData.hangPosition = newPosition

	-- Broadcast movement to all other clients
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			LedgeHangMove:FireClient(otherPlayer, player, newPosition, forwardDirection)
		end
	end
end)

-- Handle ledge hang stop
LedgeHangStop.OnServerEvent:Connect(function(player, isManualRelease)
	local hangData = activeHangs[player]
	if not hangData then
		return
	end

	local character = player.Character
	if not character then
		activeHangs[player] = nil
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		activeHangs[player] = nil
		return
	end

	-- Restore character state
	humanoid.AutoRotate = true
	root.Anchored = false

	-- Restore collisions
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = true
		end
	end

	-- Clear hang data
	activeHangs[player] = nil

	-- Broadcast stop to all other clients
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			LedgeHangStop:FireClient(otherPlayer, player, isManualRelease)
		end
	end

	print("[LedgeHangSync] Player", player.Name, "stopped ledge hang (manual:", isManualRelease, ")")
end)

-- Cleanup when player leaves
Players.PlayerRemoving:Connect(function(player)
	activeHangs[player] = nil
end)

-- Cleanup when character is removed
Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function(character)
		activeHangs[player] = nil
	end)
end)

-- Periodic cleanup for orphaned hang states
RunService.Heartbeat:Connect(function()
	local currentTime = os.clock()
	for player, hangData in pairs(activeHangs) do
		-- Clean up if no movement for 10 seconds (likely disconnected)
		if currentTime - hangData.lastMoveTime > 10 then
			activeHangs[player] = nil
			print("[LedgeHangSync] Cleaned up orphaned hang state for", player.Name)
		end
	end
end)

print("[LedgeHangSync] Server-side LedgeHang synchronization system loaded")
