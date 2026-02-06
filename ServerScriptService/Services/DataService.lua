--[[
	DataService.lua
	Core service for player data management, persistence, and caching
	Handles all player data operations with automatic saving
--]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Configuration
local CONFIG = {
	DataStoreName = "EggSystemData_v1",
	BackupDataStoreName = "EggSystemBackup_v1",
	AutoSaveInterval = 300, -- 5 minutes
	MaxDataSize = 4000000, -- 4MB limit
	UseCompression = true,
}

-- Player data template
local PLAYER_DATA_TEMPLATE = {
	-- Currency
	Currencies = {
		Clicks = 0,
		Gems = 0,
	},
	
	-- Statistics
	Stats = {
		TotalClicks = 0,
		TotalGemsEarned = 0,
		EggsOpened = 0,
		Rebirths = 0,
		PetsCollected = 0,
		PlayTime = 0, -- in seconds
		LastLogin = 0,
	},
	
	-- Inventory
	Inventory = {
		Pets = {}, -- Array of pet instances
		MaxSlots = 100,
		ExpandedSlots = 0,
	},
	
	-- Equipment
	Equipment = {
		EquippedPets = {}, -- Array of equipped pet instance IDs (max 4)
	},
	
	-- Pity system tracking
	Pity = {
		OpensSinceLegendary = 0,
		OpensSinceMythic = 0,
		OpensSinceSecret = 0,
	},
	
	-- Luck boosts
	ActiveLuckBoosts = {},
	
	-- Settings
	Settings = {
		AutoDeleteCommon = false,
		AutoDeleteUncommon = false,
		NotificationsEnabled = true,
		SoundEnabled = true,
		MusicEnabled = true,
	},
	
	-- Anti-cheat tracking
	AntiCheat = {
		SuspiciousActivityCount = 0,
		LastWarningTime = 0,
		ClickHistory = {}, -- Recent click timestamps
	},
	
	-- Version for data migration
	DataVersion = 1,
}

-- DataService module
local DataService = {}
DataService.__index = DataService

-- Private variables
local playerDataCache = {}
local dataStore = nil
local backupDataStore = nil
local autoSaveConnections = {}
local isStudio = RunService:IsStudio()

-- Initialize DataService
function DataService:Initialize()
	local success, err = pcall(function()
		dataStore = DataStoreService:GetDataStore(CONFIG.DataStoreName)
		backupDataStore = DataStoreService:GetDataStore(CONFIG.BackupDataStoreName)
	end)
	
	if not success then
		warn("[DataService] Failed to initialize DataStores: " .. tostring(err))
		-- Continue in studio without data persistence
		if isStudio then
			warn("[DataService] Running in Studio mode without persistence")
		end
	end
	
	-- Set up player events
	Players.PlayerAdded:Connect(function(player)
		self:LoadPlayerData(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		self:SavePlayerData(player, true)
	end)
	
	-- Auto-save loop
	spawn(function()
		while true do
			wait(CONFIG.AutoSaveInterval)
			self:AutoSaveAll()
		end
	end)
	
	print("[DataService] Initialized successfully")
end

-- Load player data from DataStore
function DataService:LoadPlayerData(player)
	local userId = player.UserId
	local key = tostring(userId)
	
	local data = nil
	local success, err = pcall(function()
		if dataStore then
			data = dataStore:GetAsync(key)
		end
	end)
	
	if not success then
		warn("[DataService] Failed to load data for " .. player.Name .. ": " .. tostring(err))
		-- Try backup
		success, err = pcall(function()
			if backupDataStore then
				data = backupDataStore:GetAsync(key)
			end
		end)
		
		if not success then
			warn("[DataService] Backup load also failed: " .. tostring(err))
		end
	end
	
	-- Create new data if none exists or migrate existing data
	if not data then
		data = self:CreateNewPlayerData()
		print("[DataService] Created new data for " .. player.Name)
	else
		data = self:MigrateData(data)
	end
	
	-- Set last login time
	data.Stats.LastLogin = os.time()
	
	-- Cache the data
	playerDataCache[userId] = {
		Data = data,
		Player = player,
		LastSave = tick(),
		IsDirty = false,
	}
	
	-- Set up auto-save for this player
	self:SetupAutoSave(player)
	
	print("[DataService] Loaded data for " .. player.Name)
	return data
end

-- Create new player data from template
function DataService:CreateNewPlayerData()
	local data = HttpService:JSONDecode(HttpService:JSONEncode(PLAYER_DATA_TEMPLATE))
	return data
end

-- Migrate data to current version
function DataService:MigrateData(data)
	if not data.DataVersion then
		data.DataVersion = 1
	end
	
	-- Add missing fields from template
	for key, value in pairs(PLAYER_DATA_TEMPLATE) do
		if data[key] == nil then
			if typeof(value) == "table" then
				data[key] = HttpService:JSONDecode(HttpService:JSONEncode(value))
			else
				data[key] = value
			end
		elseif typeof(value) == "table" and typeof(data[key]) == "table" then
			-- Recursively check nested tables
			for subKey, subValue in pairs(value) do
				if data[key][subKey] == nil then
					if typeof(subValue) == "table" then
						data[key][subKey] = HttpService:JSONDecode(HttpService:JSONEncode(subValue))
					else
						data[key][subKey] = subValue
					end
				end
			end
		end
	end
	
	return data
end

-- Save player data to DataStore
function DataService:SavePlayerData(player, isLeaving)
	local userId = player.UserId
	local key = tostring(userId)
	local cacheEntry = playerDataCache[userId]
	
	if not cacheEntry then
		warn("[DataService] No cached data for " .. player.Name)
		return false
	end
	
	local data = cacheEntry.Data
	
	-- Update play time
	if cacheEntry.LastSave then
		local timeSinceLastSave = tick() - cacheEntry.LastSave
		data.Stats.PlayTime = data.Stats.PlayTime + math.floor(timeSinceLastSave)
	end
	
	local success, err = pcall(function()
		if dataStore then
			dataStore:SetAsync(key, data)
		end
		
		-- Also save to backup
		if backupDataStore then
			backupDataStore:SetAsync(key, data)
		end
	end)
	
	if success then
		cacheEntry.LastSave = tick()
		cacheEntry.IsDirty = false
		
		if not isLeaving then
			print("[DataService] Saved data for " .. player.Name)
		end
	else
		warn("[DataService] Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
	
	if isLeaving then
		playerDataCache[userId] = nil
	end
	
	return success
end

-- Auto-save all players
function DataService:AutoSaveAll()
	for userId, cacheEntry in pairs(playerDataCache) do
		if cacheEntry.IsDirty then
			local player = cacheEntry.Player
			if player and player.Parent then
				self:SavePlayerData(player, false)
			end
		end
	end
end

-- Setup auto-save for a player
function DataService:SetupAutoSave(player)
	local connection = game:GetService("RunService").Heartbeat:Connect(function()
		local cacheEntry = playerDataCache[player.UserId]
		if cacheEntry and cacheEntry.IsDirty then
			local timeSinceSave = tick() - cacheEntry.LastSave
			if timeSinceSave >= CONFIG.AutoSaveInterval then
				self:SavePlayerData(player, false)
			end
		end
	end)
	
	autoSaveConnections[player.UserId] = connection
end

-- Get player data
function DataService:GetPlayerData(player)
	local cacheEntry = playerDataCache[player.UserId]
	if cacheEntry then
		return cacheEntry.Data
	end
	return nil
end

-- Update player data (marks as dirty for auto-save)
function DataService:UpdatePlayerData(player, updateFunction)
	local cacheEntry = playerDataCache[player.UserId]
	if not cacheEntry then
		warn("[DataService] Cannot update data for " .. player.Name .. " - no cached data")
		return false
	end
	
	local success, err = pcall(function()
		updateFunction(cacheEntry.Data)
	end)
	
	if success then
		cacheEntry.IsDirty = true
		return true
	else
		warn("[DataService] Failed to update data for " .. player.Name .. ": " .. tostring(err))
		return false
	end
end

-- Get specific currency amount
function DataService:GetCurrency(player, currencyType)
	local data = self:GetPlayerData(player)
	if data and data.Currencies then
		return data.Currencies[currencyType] or 0
	end
	return 0
end

-- Add currency to player
function DataService:AddCurrency(player, currencyType, amount)
	if amount <= 0 then return false end
	
	return self:UpdatePlayerData(player, function(data)
		local currentAmount = data.Currencies[currencyType] or 0
		local maxAmount = math.huge
		
		-- Check currency config for max
		local CurrencyConfig = require(game.ReplicatedStorage.Shared.Configs.CurrencyConfig)
		local currencyConfig = CurrencyConfig:GetCurrency(currencyType)
		if currencyConfig then
			maxAmount = currencyConfig.MaxAmount
		end
		
		data.Currencies[currencyType] = math.min(currentAmount + amount, maxAmount)
		
		-- Update stats
		if currencyType == "Gems" then
			data.Stats.TotalGemsEarned = data.Stats.TotalGemsEarned + amount
		end
	end)
end

-- Remove currency from player
function DataService:RemoveCurrency(player, currencyType, amount)
	if amount <= 0 then return false end
	
	local currentAmount = self:GetCurrency(player, currencyType)
	if currentAmount < amount then
		return false -- Insufficient funds
	end
	
	return self:UpdatePlayerData(player, function(data)
		data.Currencies[currencyType] = (data.Currencies[currencyType] or 0) - amount
	end)
end

-- Add pet to inventory
function DataService:AddPetToInventory(player, petInstance)
	return self:UpdatePlayerData(player, function(data)
		table.insert(data.Inventory.Pets, petInstance)
		data.Stats.PetsCollected = data.Stats.PetsCollected + 1
	end)
end

-- Remove pet from inventory
function DataService:RemovePetFromInventory(player, petInstanceId)
	return self:UpdatePlayerData(player, function(data)
		for i, pet in ipairs(data.Inventory.Pets) do
			if pet.InstanceId == petInstanceId then
				table.remove(data.Inventory.Pets, i)
				return true
			end
		end
		return false
	end)
end

-- Get pet from inventory
function DataService:GetPetFromInventory(player, petInstanceId)
	local data = self:GetPlayerData(player)
	if not data then return nil end
	
	for _, pet in ipairs(data.Inventory.Pets) do
		if pet.InstanceId == petInstanceId then
			return pet
		end
	end
	return nil
end

-- Equip a pet
function DataService:EquipPet(player, petInstanceId)
	local data = self:GetPlayerData(player)
	if not data then return false end
	
	-- Check if already equipped
	for _, equippedId in ipairs(data.Equipment.EquippedPets) do
		if equippedId == petInstanceId then
			return false -- Already equipped
		end
	end
	
	-- Check max equipped limit
	if #data.Equipment.EquippedPets >= 4 then
		return false -- Max pets equipped
	end
	
	-- Verify pet exists in inventory
	local petExists = false
	for _, pet in ipairs(data.Inventory.Pets) do
		if pet.InstanceId == petInstanceId then
			petExists = true
			pet.IsEquipped = true
			break
		end
	end
	
	if not petExists then
		return false
	end
	
	return self:UpdatePlayerData(player, function(data)
		table.insert(data.Equipment.EquippedPets, petInstanceId)
	end)
end

-- Unequip a pet
function DataService:UnequipPet(player, petInstanceId)
	return self:UpdatePlayerData(player, function(data)
		for i, equippedId in ipairs(data.Equipment.EquippedPets) do
			if equippedId == petInstanceId then
				table.remove(data.Equipment.EquippedPets, i)
				
				-- Update pet equipped status
				for _, pet in ipairs(data.Inventory.Pets) do
					if pet.InstanceId == petInstanceId then
						pet.IsEquipped = false
						break
					end
				end
				return true
			end
		end
		return false
	end)
end

-- Get equipped pets
function DataService:GetEquippedPets(player)
	local data = self:GetPlayerData(player)
	if not data then return {} end
	
	local equippedPets = {}
	for _, petInstanceId in ipairs(data.Equipment.EquippedPets) do
		local pet = self:GetPetFromInventory(player, petInstanceId)
		if pet then
			table.insert(equippedPets, pet)
		end
	end
	return equippedPets
end

-- Increment pity counter
function DataService:IncrementPity(player, rarity)
	return self:UpdatePlayerData(player, function(data)
		if rarity == "Legendary" then
			data.Pity.OpensSinceLegendary = data.Pity.OpensSinceLegendary + 1
		elseif rarity == "Mythic" then
			data.Pity.OpensSinceMythic = data.Pity.OpensSinceMythic + 1
		elseif rarity == "Secret" then
			data.Pity.OpensSinceSecret = data.Pity.OpensSinceSecret + 1
		end
	end)
end

-- Reset pity counter
function DataService:ResetPity(player, rarity)
	return self:UpdatePlayerData(player, function(data)
		if rarity == "Legendary" then
			data.Pity.OpensSinceLegendary = 0
		elseif rarity == "Mythic" then
			data.Pity.OpensSinceMythic = 0
		elseif rarity == "Secret" then
			data.Pity.OpensSinceSecret = 0
		end
	end)
end

-- Add click to stats
function DataService:AddClick(player)
	return self:UpdatePlayerData(player, function(data)
		data.Stats.TotalClicks = data.Stats.TotalClicks + 1
	end)
end

-- Increment eggs opened
function DataService:IncrementEggsOpened(player)
	return self:UpdatePlayerData(player, function(data)
		data.Stats.EggsOpened = data.Stats.EggsOpened + 1
	end)
end

-- Perform rebirth
function DataService:PerformRebirth(player, gemsAwarded)
	return self:UpdatePlayerData(player, function(data)
		data.Stats.Rebirths = data.Stats.Rebirths + 1
		data.Currencies.Clicks = 0 -- Reset clicks
		data.Currencies.Gems = data.Currencies.Gems + gemsAwarded
		data.Stats.TotalGemsEarned = data.Stats.TotalGemsEarned + gemsAwarded
	end)
end

-- Get leaderboard stats
function DataService:GetLeaderboardStats(category)
	local stats = {}
	
	for userId, cacheEntry in pairs(playerDataCache) do
		local player = cacheEntry.Player
		local data = cacheEntry.Data
		
		if player and data then
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
			
			table.insert(stats, {
				UserId = userId,
				Username = player.Name,
				Value = value,
			})
		end
	end
	
	-- Sort by value descending
	table.sort(stats, function(a, b)
		return a.Value > b.Value
	end)
	
	return stats
end

-- Shutdown handler
function DataService:OnShutdown()
	print("[DataService] Shutdown initiated, saving all player data...")
	
	for userId, cacheEntry in pairs(playerDataCache) do
		local player = cacheEntry.Player
		if player then
			self:SavePlayerData(player, true)
		end
	end
	
	print("[DataService] All player data saved")
end

-- Initialize on module load
DataService:Initialize()

-- Bind to game close
game:BindToClose(function()
	DataService:OnShutdown()
end)

return DataService
