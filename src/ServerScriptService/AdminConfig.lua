-- Configure admin users here. Do NOT hardcode in code paths; keep all IDs in this single place.
-- Fill with Roblox UserIds, e.g., {12345678, 987654321}

local AdminConfig = {}

AdminConfig.AllowedUserIds = { "1518482854" }

function AdminConfig.isAdminUserId(userId)
	for _, id in ipairs(AdminConfig.AllowedUserIds) do
		if id == userId then
			return true
		end
	end
	return false
end

return AdminConfig
