--[[
	InventoryService.lua
	Handles inventory management including sorting, filtering, and slot management
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import configurations
local PetConfig = require(ReplicatedStorage.Shared.Configs.PetConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Configs.RarityConfig)
local DataService = require(script.Parent.DataService)

-- InventoryService module
local InventoryService = {}
InventoryService.__index = InventoryService

-- Initialize InventoryService
function InventoryService:Initialize()
	self:SetupRemoteEvents()
	print("[InventoryService] Initialized successfully")
end

-- Setup remote events
function InventoryService:SetupRemoteEvents()
	local remotes = ReplicatedStorage.Shared.Remotes
	
	-- Request inventory data
	local requestInventoryRemote = Instance.new("RemoteEvent")
	requestInventoryRemote.Name = "RequestInventory"
	requestInventoryRemote.Parent = remotes
	
	requestInventoryRemote.OnServerEvent:Connect(function(player)
		local inventory = self:GetPlayerInventory(player)
		self:SendInventoryToClient(player, inventory)
	end)
	
	-- Sort inventory
	local sortRemote = Instance.new("RemoteEvent")
	sortRemote.Name = "SortInventory"
	sortRemote.Parent = remotes
	
	sortRemote.OnServerEvent:Connect(function(player, sortType)
		local sortedInventory = self:SortInventory(player, sortType)
		self:SendInventoryToClient(player, sortedInventory)
	end)
	
	-- Filter inventory
	local filterRemote = Instance.new("RemoteEvent")
	filterRemote.Name = "FilterInventory"
	filterRemote.Parent = remotes
	
	filterRemote.OnServerEvent:Connect(function(player, filterType, filterValue)
		local filteredInventory = self:FilterInventory(player, filterType, filterValue)
		self:SendInventoryToClient(player, filteredInventory)
	end)
	
	-- Search inventory
	local searchRemote = Instance.new("RemoteEvent")
	searchRemote.Name = "SearchInventory"
	searchRemote.Parent = remotes
	
	searchRemote.OnServerEvent:Connect(function(player, searchTerm)
		local searchResults = self:SearchInventory(player, searchTerm)
		self:SendInventoryToClient(player, searchResults)
	end)
	
	-- Expand inventory slots
	local expandRemote = Instance.new("RemoteEvent")
	expandRemote.Name = "ExpandInventory"
	expandRemote.Parent = remotes
	
	expandRemote.OnServerEvent:Connect(function(player, slotAmount)
		local success, result = self:ExpandInventorySlots(player, slotAmount)
		return success, result
	end)
	
	-- Inventory update remote (server to client)
	local inventoryUpdateRemote = Instance.new("RemoteEvent")
	inventoryUpdateRemote.Name = "InventoryUpdated"
	inventoryUpdateRemote.Parent = remotes
	self.InventoryUpdateRemote = inventoryUpdateRemote
end

-- Get player's full inventory
function InventoryService:GetPlayerInventory(player)
	local data = DataService:GetPlayerData(player)
	if not data then return nil end
	
	local inventory = {
		Pets = data.Inventory.Pets,
		EquippedPets = data.Equipment.EquippedPets,
		MaxSlots = data.Inventory.MaxSlots,
		ExpandedSlots = data.Inventory.ExpandedSlots,
		UsedSlots = #data.Inventory.Pets,
		AvailableSlots = (data.Inventory.MaxSlots + data.Inventory.ExpandedSlots) - #data.Inventory.Pets,
	}
	
	return inventory
end

-- Send inventory to client
function InventoryService:SendInventoryToClient(player, inventory)
	if self.InventoryUpdateRemote then
		self.InventoryUpdateRemote:FireClient(player, inventory)
	end
end

-- Sort inventory
function InventoryService:SortInventory(player, sortType)
	local data = DataService:GetPlayerData(player)
	if not data then return nil end
	
	local pets = data.Inventory.Pets
	
	if sortType == "Rarity" then
		-- Sort by rarity (highest first)
		table.sort(pets, function(a, b)
			local rarityOrder = RarityConfig.RarityOrder
			local aIndex = table.find(rarityOrder, a.Rarity) or 0
			local bIndex = table.find(rarityOrder, b.Rarity) or 0
			return aIndex > bIndex
		end)
	elseif sortType == "RarityAsc" then
		-- Sort by rarity (lowest first)
		table.sort(pets, function(a, b)
			local rarityOrder = RarityConfig.RarityOrder
			local aIndex = table.find(rarityOrder, a.Rarity) or 0
			local bIndex = table.find(rarityOrder, b.Rarity) or 0
			return aIndex < bIndex
		end)
	elseif sortType == "Name" then
		-- Sort by name (A-Z)
		table.sort(pets, function(a, b)
			return a.DisplayName < b.DisplayName
		end)
	elseif sortType == "NameDesc" then
		-- Sort by name (Z-A)
		table.sort(pets, function(a, b)
			return a.DisplayName > b.DisplayName
		end)
	elseif sortType == "Level" then
		-- Sort by level (highest first)
		table.sort(pets, function(a, b)
			return a.Level > b.Level
		end)
	elseif sortType == "LevelAsc" then
		-- Sort by level (lowest first)
		table.sort(pets, function(a, b)
			return a.Level < b.Level
		end)
	elseif sortType == "Acquisition" then
		-- Sort by acquisition time (newest first)
		table.sort(pets, function(a, b)
			return a.AcquisitionTime > b.AcquisitionTime
		end)
	elseif sortType == "AcquisitionAsc" then
		-- Sort by acquisition time (oldest first)
		table.sort(pets, function(a, b)
			return a.AcquisitionTime < b.AcquisitionTime
		end)
	elseif sortType == "FusionTier" then
		-- Sort by fusion tier (highest first)
		table.sort(pets, function(a, b)
			return a.FusionTier > b.FusionTier
		end)
	end
	
	return self:GetPlayerInventory(player)
end

-- Filter inventory
function InventoryService:FilterInventory(player, filterType, filterValue)
	local data = DataService:GetPlayerData(player)
	if not data then return nil end
	
	local allPets = data.Inventory.Pets
	local filteredPets = {}
	
	if filterType == "Rarity" then
		-- Filter by rarity
		for _, pet in ipairs(allPets) do
			if pet.Rarity == filterValue then
				table.insert(filteredPets, pet)
			end
		end
	elseif filterType == "Equipped" then
		-- Filter by equipped status
		for _, pet in ipairs(allPets) do
			if pet.IsEquipped == filterValue then
				table.insert(filteredPets, pet)
			end
		end
	elseif filterType == "Tradeable" then
		-- Filter by tradeable status
		for _, pet in ipairs(allPets) do
			local petConfig = PetConfig:GetPet(pet.PetId)
			if petConfig and petConfig.Tradeable == filterValue then
				table.insert(filteredPets, pet)
			end
		end
	elseif filterType == "Favorite" then
		-- Filter by favorite status
		for _, pet in ipairs(allPets) do
			if pet.IsFavorite == filterValue then
				table.insert(filteredPets, pet)
			end
		end
	elseif filterType == "FusionTier" then
		-- Filter by fusion tier
		for _, pet in ipairs(allPets) do
			if pet.FusionTier == filterValue then
				table.insert(filteredPets, pet)
			end
		end
	end
	
	return {
		Pets = filteredPets,
		EquippedPets = data.Equipment.EquippedPets,
		MaxSlots = data.Inventory.MaxSlots,
		ExpandedSlots = data.Inventory.ExpandedSlots,
		UsedSlots = #allPets,
		AvailableSlots = (data.Inventory.MaxSlots + data.Inventory.ExpandedSlots) - #allPets,
		IsFiltered = true,
		FilterType = filterType,
		FilterValue = filterValue,
	}
end

-- Search inventory by name
function InventoryService:SearchInventory(player, searchTerm)
	local data = DataService:GetPlayerData(player)
	if not data then return nil end
	
	searchTerm = string.lower(searchTerm)
	local allPets = data.Inventory.Pets
	local searchResults = {}
	
	for _, pet in ipairs(allPets) do
		local petName = string.lower(pet.DisplayName)
		if string.find(petName, searchTerm) then
			table.insert(searchResults, pet)
		end
	end
	
	return {
		Pets = searchResults,
		EquippedPets = data.Equipment.EquippedPets,
		MaxSlots = data.Inventory.MaxSlots,
		ExpandedSlots = data.Inventory.ExpandedSlots,
		UsedSlots = #allPets,
		AvailableSlots = (data.Inventory.MaxSlots + data.Inventory.ExpandedSlots) - #allPets,
		IsSearch = true,
		SearchTerm = searchTerm,
	}
end

-- Expand inventory slots
function InventoryService:ExpandInventorySlots(player, slotAmount)
	slotAmount = slotAmount or 50 -- Default expansion size
	
	local data = DataService:GetPlayerData(player)
	if not data then return false, "No player data" end
	
	local maxExpansion = 500 -- Maximum additional slots
	local currentExpansion = data.Inventory.ExpandedSlots
	
	if currentExpansion + slotAmount > maxExpansion then
		slotAmount = maxExpansion - currentExpansion
	end
	
	if slotAmount <= 0 then
		return false, "Maximum expansion reached"
	end
	
	-- Calculate cost (increasing cost per expansion)
	local expansionCount = currentExpansion / 50
	local costPerSlot = 100 * (expansionCount + 1)
	local totalCost = costPerSlot * slotAmount
	
	-- Check if player can afford
	local CurrencyService = require(script.Parent.CurrencyService)
	if not CurrencyService:CanAfford(player, "Gems", totalCost) then
		return false, "Insufficient Gems"
	end
	
	-- Deduct currency
	local spendSuccess = CurrencyService:SpendCurrency(player, "Gems", totalCost)
	if not spendSuccess then
		return false, "Failed to spend Gems"
	end
	
	-- Add slots
	local success = DataService:UpdatePlayerData(player, function(data)
		data.Inventory.ExpandedSlots = data.Inventory.ExpandedSlots + slotAmount
	end)
	
	if success then
		return true, {
			NewMaxSlots = data.Inventory.MaxSlots + data.Inventory.ExpandedSlots,
			SlotsAdded = slotAmount,
			Cost = totalCost,
		}
	end
	
	return false, "Failed to expand inventory"
end

-- Get inventory statistics
function InventoryService:GetInventoryStats(player)
	local data = DataService:GetPlayerData(player)
	if not data then return nil end
	
	local pets = data.Inventory.Pets
	local stats = {
		TotalPets = #pets,
		EquippedPets = #data.Equipment.EquippedPets,
		RarityCounts = {},
		TotalClicksMultiplier = 1,
		TotalGemsMultiplier = 1,
	}
	
	-- Count pets by rarity
	for _, pet in ipairs(pets) do
		stats.RarityCounts[pet.Rarity] = (stats.RarityCounts[pet.Rarity] or 0) + 1
		
		-- Add multipliers if equipped
		if pet.IsEquipped then
			stats.TotalClicksMultiplier = stats.TotalClicksMultiplier + (pet.Stats.ClicksMultiplier - 1)
			stats.TotalGemsMultiplier = stats.TotalGemsMultiplier + (pet.Stats.GemsMultiplier - 1)
		end
	end
	
	return stats
end

-- Check if inventory has space
function InventoryService:HasInventorySpace(player)
	local data = DataService:GetPlayerData(player)
	if not data then return false end
	
	local currentPets = #data.Inventory.Pets
	local maxSlots = data.Inventory.MaxSlots + data.Inventory.ExpandedSlots
	
	return currentPets < maxSlots
end

-- Get inventory space info
function InventoryService:GetInventorySpaceInfo(player)
	local data = DataService:GetPlayerData(player)
	if not data then return nil end
	
	return {
		UsedSlots = #data.Inventory.Pets,
		MaxSlots = data.Inventory.MaxSlots,
		ExpandedSlots = data.Inventory.ExpandedSlots,
		TotalSlots = data.Inventory.MaxSlots + data.Inventory.ExpandedSlots,
		AvailableSlots = (data.Inventory.MaxSlots + data.Inventory.ExpandedSlots) - #data.Inventory.Pets,
	}
end

-- Notify inventory update to client
function InventoryService:NotifyInventoryUpdate(player)
	local inventory = self:GetPlayerInventory(player)
	self:SendInventoryToClient(player, inventory)
end

-- Initialize on module load
InventoryService:Initialize()

return InventoryService
