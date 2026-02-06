--[[
	LeaderboardService.lua
	Handles all leaderboard functionality with caching and update intervals
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Import configurations
local CurrencyConfig = require(ReplicatedStorage.Shared.Configs.CurrencyConfig)
local DataService = require(script.Parent.DataService)

-- LeaderboardService module
local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

-- Leaderboard categories
local CATEGORIES = {
	"Clicks",
	"Gems",
	"EggsOpened",
	"Rebirths",
}

-- Configuration
local CONFIG = {
	MaxLeaderboardEntries = 100,
	UpdateIntervals = {
		Clicks = 5,      -- 5 seconds (frequently changing)
		Gems = 10,       -- 10 seconds
		EggsOpened = 15, -- 15 seconds
		Rebirths = 30,   -- 30 seconds (rarely changing)
	},
	CacheExpiry = 60, -- Seconds before cache is considered stale
}

-- Private variables
local leaderboardCache = {} -- Cached leaderboard data
local lastUpdateTimes = {} -- Last update time per category
local updateConnections = {} -- Active update connections

-- Initialize LeaderboardService
function LeaderboardService:Initialize()
	self:SetupRemoteEvents()
	self:StartUpdateLoops()
	print("[LeaderboardService] Initialized successfully")
end

-- Setup remote events
function LeaderboardService:SetupRemoteEvents()
	local remotes = ReplicatedStorage.Shared.Remotes
	
	-- Request leaderboard data
	local requestLeaderboardRemote = Instance.new("RemoteEvent")
	requestLeaderboardRemote.Name = "RequestLeaderboard"
	requestLeaderboardRemote.Parent = remotes
	
	requestLeaderboardRemote.OnServerEvent:Connect(function(player, category)
		local leaderboard = self:GetLeaderboard(category)
		self:SendLeaderboardToClient(player, category, leaderboard)
	end)
	
	-- Search leaderboard
	local searchLeaderboardRemote = Instance.new("RemoteEvent")
	searchLeaderboardRemote.Name = "SearchLeaderboard"
	searchLeaderboardRemote.Parent = remotes
	
	searchLeaderboardRemote.OnServerEvent:Connect(function(player, category, searchTerm)
		local results = self:SearchLeaderboard(category, searchTerm)
		if self.LeaderboardUpdateRemote then
			self.LeaderboardUpdateRemote:FireClient(player, "SearchResults", category, results)
		end
	end)
	
	-- Leaderboard update remote (server to client)
	local leaderboardUpdateRemote = Instance.new("RemoteEvent")
	leaderboardUpdateRemote.Name = "LeaderboardUpdated"
	leaderboardUpdateRemote.Parent = remotes
	self.LeaderboardUpdateRemote = leaderboardUpdateRemote
end

-- Start update loops for each category
function LeaderboardService:StartUpdateLoops()
	for _, category in ipairs(CATEGORIES) do
		spawn(function()
			while true do
				local interval = CONFIG.UpdateIntervals[category] or 30
				wait(interval)
				self:UpdateLeaderboard(category)
			end
		end)
	end
end

-- Update a specific leaderboard category
function LeaderboardService:UpdateLeaderboard(category)
	local stats = DataService:GetLeaderboardStats(category)
	
	-- Format values and add rank badges
	local formattedStats = {}
	for rank, entry in ipairs(stats) do
		if rank > CONFIG.MaxLeaderboardEntries then
			break
		end
		
		local formattedValue = self:FormatLeaderboardValue(entry.Value, category)
		local rankBadge = self:GetRankBadge(rank)
		
		table.insert(formattedStats, {
			Rank = rank,
			UserId = entry.UserId,
			Username = entry.Username,
			Value = entry.Value,
			FormattedValue = formattedValue,
			RankBadge = rankBadge,
			IsTop3 = rank <= 3,
		})
	end
	
	-- Update cache
	leaderboardCache[category] = {
		Data = formattedStats,
		LastUpdate = os.time(),
	}
	
	lastUpdateTimes[category] = os.time()
	
	-- Notify all players of update
	self:BroadcastLeaderboardUpdate(category, formattedStats)
	
	return formattedStats
end

-- Get leaderboard for a category (from cache or fresh)
function LeaderboardService:GetLeaderboard(category)
	local cache = leaderboardCache[category]
	
	-- Check if cache is valid
	if cache and cache.LastUpdate then
		local age = os.time() - cache.LastUpdate
		if age < CONFIG.CacheExpiry then
			return cache.Data
		end
	end
	
	-- Update if cache is stale or missing
	return self:UpdateLeaderboard(category)
end

-- Format leaderboard value based on category
function LeaderboardService:FormatLeaderboardValue(value, category)
	if category == "Clicks" or category == "Gems" then
		return CurrencyConfig:FormatAmount(value, category)
	elseif category == "EggsOpened" then
		return tostring(value) .. " Eggs"
	elseif category == "Rebirths" then
		return tostring(value) .. " Rebirths"
	end
	return tostring(value)
end

-- Get rank badge for position
function LeaderboardService:GetRankBadge(rank)
	if rank == 1 then
		return {
			Icon = "rbxassetid://GOLD_BADGE",
			Color = Color3.fromRGB(255, 215, 0),
			Name = "1st",
		}
	elseif rank == 2 then
		return {
			Icon = "rbxassetid://SILVER_BADGE",
			Color = Color3.fromRGB(192, 192, 192),
			Name = "2nd",
		}
	elseif rank == 3 then
		return {
			Icon = "rbxassetid://BRONZE_BADGE",
			Color = Color3.fromRGB(205, 127, 50),
			Name = "3rd",
		}
	else
		return {
			Icon = "",
			Color = Color3.fromRGB(255, 255, 255),
			Name = tostring(rank) .. "th",
		}
	end
end

-- Send leaderboard to client
function LeaderboardService:SendLeaderboardToClient(player, category, leaderboard)
	if self.LeaderboardUpdateRemote then
		-- Get player's rank in this category
		local playerRank = self:GetPlayerRank(player, category)
		
		self.LeaderboardUpdateRemote:FireClient(player, "FullUpdate", category, {
			Leaderboard = leaderboard,
			PlayerRank = playerRank,
			LastUpdate = lastUpdateTimes[category] or os.time(),
			NextUpdate = (lastUpdateTimes[category] or os.time()) + CONFIG.UpdateIntervals[category],
		})
	end
end

-- Broadcast leaderboard update to all players
function LeaderboardService:BroadcastLeaderboardUpdate(category, leaderboard)
	if self.LeaderboardUpdateRemote then
		for _, player in ipairs(Players:GetPlayers()) do
			local playerRank = self:GetPlayerRank(player, category)
			
			self.LeaderboardUpdateRemote:FireClient(player, "Update", category, {
				Leaderboard = leaderboard,
				PlayerRank = playerRank,
				LastUpdate = lastUpdateTimes[category] or os.time(),
				NextUpdate = (lastUpdateTimes[category] or os.time()) + CONFIG.UpdateIntervals[category],
			})
		end
	end
end

-- Get player's rank in a category
function LeaderboardService:GetPlayerRank(player, category)
	local data = DataService:GetPlayerData(player)
	if not data then return nil end
	
	local value = 0
	if category == "Clicks" then
		value = data.Stats.TotalClicks
	elseif category == "Gems" then
		value = data.Currencies.Gems
	elseif category == "EggsOpened" then
		value = data.Stats.EggsOpened
	elseif category == "Rebirths" then
		value = data.Stats.Rebirths
	end
	
	-- Count how many players have higher values
	local rank = 1
	for _, entry in ipairs(DataService:GetLeaderboardStats(category)) do
		if entry.UserId ~= player.UserId then
			if entry.Value > value then
				rank = rank + 1
			end
		end
	end
	
	return {
		Rank = rank,
		Value = value,
		FormattedValue = self:FormatLeaderboardValue(value, category),
	}
end

-- Search leaderboard for a player
function LeaderboardService:SearchLeaderboard(category, searchTerm)
	local leaderboard = self:GetLeaderboard(category)
	local results = {}
	
	searchTerm = string.lower(searchTerm)
	
	for _, entry in ipairs(leaderboard) do
		if string.find(string.lower(entry.Username), searchTerm) then
			table.insert(results, entry)
		end
	end
	
	return results
end

-- Get top players for a category
function LeaderboardService:GetTopPlayers(category, count)
	count = count or 10
	local leaderboard = self:GetLeaderboard(category)
	
	local topPlayers = {}
	for i = 1, math.min(count, #leaderboard) do
		table.insert(topPlayers, leaderboard[i])
	end
	
	return topPlayers
end

-- Get leaderboard statistics
function LeaderboardService:GetLeaderboardStats(category)
	local leaderboard = self:GetLeaderboard(category)
	
	if #leaderboard == 0 then
		return {
			TotalEntries = 0,
			AverageValue = 0,
			TopValue = 0,
		}
	end
	
	local totalValue = 0
	local topValue = leaderboard[1].Value
	
	for _, entry in ipairs(leaderboard) do
		totalValue = totalValue + entry.Value
	end
	
	return {
		TotalEntries = #leaderboard,
		AverageValue = math.floor(totalValue / #leaderboard),
		TopValue = topValue,
	}
end

-- Get time until next update
function LeaderboardService:GetTimeUntilUpdate(category)
	local lastUpdate = lastUpdateTimes[category] or 0
	local interval = CONFIG.UpdateIntervals[category] or 30
	local timeElapsed = os.time() - lastUpdate
	
	return math.max(0, interval - timeElapsed)
end

-- Force refresh all leaderboards
function LeaderboardService:ForceRefreshAll()
	for _, category in ipairs(CATEGORIES) do
		self:UpdateLeaderboard(category)
	end
end

-- Get all available categories
function LeaderboardService:GetCategories()
	return CATEGORIES
end

-- Initialize on module load
LeaderboardService:Initialize()

return LeaderboardService
