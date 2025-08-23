-- Creates RemoteEvents used by the game at runtime

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function ensureRemoteEvent(parent, name)
	local remote = parent:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = parent
	end
	return remote
end

local function ensureRemoteFunction(parent, name)
	local remote = parent:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = parent
	end
	return remote
end

local remotesFolder = ensureFolder(ReplicatedStorage, "Remotes")
ensureRemoteEvent(remotesFolder, "DashActivated")
ensureRemoteEvent(remotesFolder, "MomentumUpdated")
ensureRemoteEvent(remotesFolder, "StyleCommit")
ensureRemoteEvent(remotesFolder, "MaxComboReport")
ensureRemoteEvent(remotesFolder, "PadTriggered")
ensureRemoteEvent(remotesFolder, "RopeAttach")
ensureRemoteEvent(remotesFolder, "RopeRelease")
ensureRemoteEvent(remotesFolder, "PowerupTouched")
ensureRemoteEvent(remotesFolder, "PowerupActivated")
-- Audio settings remotes
ensureRemoteEvent(remotesFolder, "AudioSettingsLoaded")
ensureRemoteEvent(remotesFolder, "SetAudioSettings")
