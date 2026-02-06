--[[
	GUID.lua
	Utility module for generating unique identifiers
	Used for pet instance IDs and transaction tracking
--]]

local HttpService = game:GetService("HttpService")

local GUID = {}

-- Generate a new GUID (UUID v4 style)
function GUID:Generate()
	-- Use Roblox's HttpService to generate a UUID
	local success, uuid = pcall(function()
		return HttpService:GenerateGUID(false)
	end)
	
	if success then
		return uuid
	end
	
	-- Fallback manual generation if HttpService fails
	return self:GenerateManual()
end

-- Manual GUID generation (fallback)
function GUID:GenerateManual()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	local result = string.gsub(template, "[xy]", function(c)
		local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
		return string.format("%x", v)
	end)
	return result
end

-- Generate a short unique ID (for less critical uses)
function GUID:GenerateShort()
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	local result = ""
	
	for i = 1, 12 do
		local randomIndex = math.random(1, #chars)
		result = result .. string.sub(chars, randomIndex, randomIndex)
	end
	
	return result
end

-- Generate a sequential ID with prefix
local sequentialCounters = {}
function GUID:GenerateSequential(prefix)
	prefix = prefix or "ID"
	sequentialCounters[prefix] = (sequentialCounters[prefix] or 0) + 1
	return prefix .. "_" .. tostring(sequentialCounters[prefix]) .. "_" .. tostring(tick())
end

-- Validate if string is a valid GUID format
function GUID:IsValid(guid)
	if typeof(guid) ~= "string" then
		return false
	end
	
	-- Check basic UUID format (8-4-4-4-12 hex digits)
	local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
	return string.match(guid, pattern) ~= nil
end

-- Extract timestamp from GUID (if using sequential format)
function GUID:ExtractTimestamp(guid)
	if typeof(guid) ~= "string" then
		return nil
	end
	
	-- Try to extract timestamp from sequential format
	local timestamp = string.match(guid, "_(%d+%.?%d*)$")
	if timestamp then
		return tonumber(timestamp)
	end
	
	return nil
end

return GUID
