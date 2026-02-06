--[[
	PetService.lua
	Handles all pet-related operations including equipment, leveling, and fusion
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Import configurations
local PetConfig = require(ReplicatedStorage.Shared.Configs.PetConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Configs.RarityConfig)
local DataService = require(script.Parent.DataService)

-- PetService module
local PetService = {}
PetService.__index = PetService

-- Private variables
local equippedPetModels = {} -- Track equipped pet models per player
local petOrbitConnections = {}

-- Initialize PetService
function PetService:Initialize()
	self:SetupRemoteEvents()
	self:StartOrbitUpdateLoop()
	print("[PetService] Initialized successfully")
end

-- Setup remote events
function PetService:SetupRemoteEvents()
	local remotes = ReplicatedStorage.Shared.Remotes
	
	-- Equip pet
	local equipRemote = Instance.new("RemoteEvent")
	equipRemote.Name = "EquipPet"
	equipRemote.Parent = remotes
	
	equipRemote.OnServerEvent:Connect(function(player, petInstanceId)
		local success, result = self:EquipPet(player, petInstanceId)
		if success then
			self:NotifyPetEquipped(player, petInstanceId)
		end
		return success, result
	end)
	
	-- Unequip pet
	local unequipRemote = Instance.new("RemoteEvent")
	unequipRemote.Name = "UnequipPet"
	unequipRemote.Parent = remotes
	
	unequipRemote.OnServerEvent:Connect(function(player, petInstanceId)
		local success = self:UnequipPet(player, petInstanceId)
		if success then
			self:NotifyPetUnequipped(player, petInstanceId)
		end
		return success
	end)
	
	-- Fuse pets
	local fuseRemote = Instance.new("RemoteEvent")
	fuseRemote.Name = "FusePets"
	fuseRemote.Parent = remotes
	
	fuseRemote.OnServerEvent:Connect(function(player, petInstanceIds)
		local success, result = self:FusePets(player, petInstanceIds)
		return success, result
	end)
	
	-- Sell pet
	local sellRemote = Instance.new("RemoteEvent")
	sellRemote.Name = "SellPet"
	sellRemote.Parent = remotes
	
	sellRemote.OnServerEvent:Connect(function(player, petInstanceId)
		local success, result = self:SellPet(player, petInstanceId)
		return success, result
	end)
	
	-- Toggle favorite
	local favoriteRemote = Instance.new("RemoteEvent")
	favoriteRemote.Name = "ToggleFavorite"
	favoriteRemote.Parent = remotes
	
	favoriteRemote.OnServerEvent:Connect(function(player, petInstanceId)
		local success = self:ToggleFavorite(player, petInstanceId)
		return success
	end)
	
	-- Pet update remote (server to client)
	local petUpdateRemote = Instance.new("RemoteEvent")
	petUpdateRemote.Name = "PetUpdated"
	petUpdateRemote.Parent = remotes
	self.PetUpdateRemote = petUpdateRemote
end

-- Equip a pet
function PetService:EquipPet(player, petInstanceId)
	-- Get player data
	local data = DataService:GetPlayerData(player)
	if not data then return false, "No player data" end
	
	-- Check max equipped limit
	if #data.Equipment.EquippedPets >= PetConfig.EquipmentSettings.MaxEquippedPets then
		return false, "Maximum pets already equipped"
	end
	
	-- Find pet in inventory
	local pet = DataService:GetPetFromInventory(player, petInstanceId)
	if not pet then
		return false, "Pet not found in inventory"
	end
	
	-- Check if already equipped
	if pet.IsEquipped then
		return false, "Pet already equipped"
	end
	
	-- Equip the pet
	local success = DataService:EquipPet(player, petInstanceId)
	if success then
		-- Spawn pet model
		self:SpawnEquippedPetModel(player, pet)
		return true, pet
	end
	
	return false, "Failed to equip pet"
end

-- Unequip a pet
function PetService:UnequipPet(player, petInstanceId)
	local success = DataService:UnequipPet(player, petInstanceId)
	if success then
		-- Remove pet model
		self:RemoveEquippedPetModel(player, petInstanceId)
		return true
	end
	return false
end

-- Spawn equipped pet model for a player
function PetService:SpawnEquippedPetModel(player, pet)
	if not equippedPetModels[player.UserId] then
		equippedPetModels[player.UserId] = {}
	end
	
	-- Remove existing model if any
	if equippedPetModels[player.UserId][pet.InstanceId] then
		equippedPetModels[player.UserId][pet.InstanceId]:Destroy()
	end
	
	-- Get pet configuration
	local petConfig = PetConfig:GetPet(pet.PetId)
	if not petConfig then return end
	
	-- Create pet model (this would use actual models from ServerStorage)
	-- For now, create a placeholder part
	local petModel = Instance.new("Part")
	petModel.Name = pet.DisplayName
	petModel.Size = Vector3.new(2, 2, 2)
	petModel.Shape = Enum.PartType.Ball
	petModel.Anchored = true
	petModel.CanCollide = false
	
	-- Set color based on rarity
	local rarityInfo = RarityConfig:GetRarity(pet.Rarity)
	if rarityInfo then
		petModel.Color = rarityInfo.Color
		petModel.Material = Enum.Material.Neon
	end
	
	-- Store model reference
	equippedPetModels[player.UserId][pet.InstanceId] = petModel
	petModel.Parent = workspace
	
	return petModel
end

-- Remove equipped pet model
function PetService:RemoveEquippedPetModel(player, petInstanceId)
	if equippedPetModels[player.UserId] and equippedPetModels[player.UserId][petInstanceId] then
		equippedPetModels[player.UserId][petInstanceId]:Destroy()
		equippedPetModels[player.UserId][petInstanceId] = nil
	end
end

-- Start orbit update loop for equipped pets
function PetService:StartOrbitUpdateLoop()
	RunService.Heartbeat:Connect(function(dt)
		for userId, petModels in pairs(equippedPetModels) do
			local player = Players:GetPlayerByUserId(userId)
			if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local hrp = player.Character.HumanoidRootPart
				local equippedPets = DataService:GetEquippedPets(player)
				local petCount = #equippedPets
				
				if petCount > 0 then
					local orbitRadius = PetConfig.EquipmentSettings.OrbitRadius
					local orbitSpeed = PetConfig.EquipmentSettings.OrbitSpeed
					local orbitHeight = PetConfig.EquipmentSettings.OrbitHeight
					
					-- Calculate time-based angle
					local timeOffset = tick() * orbitSpeed
					
					for i, pet in ipairs(equippedPets) do
						local model = petModels[pet.InstanceId]
						if model then
							-- Calculate position in orbit
							local angle = (timeOffset + (i * (2 * math.pi / petCount))) % (2 * math.pi)
							local x = math.cos(angle) * orbitRadius
							local z = math.sin(angle) * orbitRadius
							
							local targetPosition = hrp.Position + Vector3.new(x, orbitHeight, z)
							model.Position = targetPosition
							
							-- Face player if enabled
							if PetConfig.EquipmentSettings.PetsFacePlayer then
								model.CFrame = CFrame.lookAt(model.Position, hrp.Position)
							end
						end
					end
				end
			end
		end
	end)
end

-- Fuse multiple pets into a stronger version
function PetService:FusePets(player, petInstanceIds)
	if #petInstanceIds < PetConfig.FusionSettings.RequiredDuplicates then
		return false, "Not enough pets to fuse"
	end
	
	-- Get pets from inventory
	local petsToFuse = {}
	local basePetId = nil
	
	for _, petInstanceId in ipairs(petInstanceIds) do
		local pet = DataService:GetPetFromInventory(player, petInstanceId)
		if not pet then
			return false, "Pet not found: " .. petInstanceId
		end
		
		if pet.IsEquipped then
			return false, "Cannot fuse equipped pets"
		end
		
		if pet.IsFavorite then
			return false, "Cannot fuse favorited pets"
		end
		
		-- All pets must be the same type
		if basePetId == nil then
			basePetId = pet.PetId
		elseif pet.PetId ~= basePetId then
			return false, "All pets must be the same type"
		end
		
		table.insert(petsToFuse, pet)
	end
	
	-- Check fusion tier limit
	local basePet = petsToFuse[1]
	if basePet.FusionTier >= PetConfig.FusionSettings.MaxFusionLevel then
		return false, "Pet already at maximum fusion tier"
	end
	
	-- Calculate success (always succeeds for now)
	local success = math.random() <= PetConfig.FusionSettings.SuccessRate
	if not success then
		return false, "Fusion failed"
	end
	
	-- Remove old pets
	for _, pet in ipairs(petsToFuse) do
		DataService:RemovePetFromInventory(player, pet.InstanceId)
	end
	
	-- Create fused pet
	local fusedPet = self:CreateFusedPet(basePet)
	
	-- Add to inventory
	DataService:AddPetToInventory(player, fusedPet)
	
	-- Notify client
	if self.PetUpdateRemote then
		self.PetUpdateRemote:FireClient(player, "Fused", fusedPet)
	end
	
	return true, fusedPet
end

-- Create a fused version of a pet
function PetService:CreateFusedPet(basePet)
	local petConfig = PetConfig:GetPet(basePet.PetId)
	if not petConfig then return nil end
	
	local fusedPet = {
		InstanceId = require(ReplicatedStorage.Shared.Modules.GUID):Generate(),
		PetId = basePet.PetId,
		DisplayName = basePet.DisplayName,
		Rarity = basePet.Rarity,
		Level = math.min(basePet.Level + 5, petConfig.MaxLevel), -- Bonus levels
		XP = 0,
		FusionTier = basePet.FusionTier + 1,
		IsEquipped = false,
		IsFavorite = false,
		AcquisitionTime = os.time(),
		AcquisitionMethod = "Fusion",
		OriginalOwner = basePet.OriginalOwner,
		TradeHistory = {},
		Stats = {
			ClicksMultiplier = basePet.Stats.ClicksMultiplier * PetConfig.FusionSettings.StatMultiplier,
			GemsMultiplier = basePet.Stats.GemsMultiplier * PetConfig.FusionSettings.StatMultiplier,
		},
	}
	
	return fusedPet
end

-- Sell a pet for currency
function PetService:SellPet(player, petInstanceId)
	local pet = DataService:GetPetFromInventory(player, petInstanceId)
	if not pet then
		return false, "Pet not found"
	end
	
	if pet.IsEquipped then
		return false, "Cannot sell equipped pets"
	end
	
	if pet.IsFavorite then
		return false, "Cannot sell favorited pets"
	end
	
	-- Calculate sell value based on rarity and level
	local sellValue = self:CalculateSellValue(pet)
	
	-- Remove pet
	local removeSuccess = DataService:RemovePetFromInventory(player, petInstanceId)
	if not removeSuccess then
		return false, "Failed to remove pet"
	end
	
	-- Award currency
	local CurrencyService = require(script.Parent.CurrencyService)
	CurrencyService:AwardCurrency(player, "Clicks", sellValue)
	
	-- Notify client
	if self.PetUpdateRemote then
		self.PetUpdateRemote:FireClient(player, "Sold", petInstanceId, sellValue)
	end
	
	return true, sellValue
end

-- Calculate sell value for a pet
function PetService:CalculateSellValue(pet)
	local baseValue = 100
	
	-- Rarity multiplier
	local rarityMultipliers = {
		Common = 1,
		Uncommon = 2,
		Rare = 5,
		Epic = 15,
		Legendary = 50,
		Mythic = 200,
		Secret = 1000,
	}
	
	local rarityMultiplier = rarityMultipliers[pet.Rarity] or 1
	local levelBonus = pet.Level * 10
	local fusionBonus = (pet.FusionTier - 1) * 100
	
	return math.floor((baseValue * rarityMultiplier) + levelBonus + fusionBonus)
end

-- Toggle favorite status
function PetService:ToggleFavorite(player, petInstanceId)
	local data = DataService:GetPlayerData(player)
	if not data then return false end
	
	for _, pet in ipairs(data.Inventory.Pets) do
		if pet.InstanceId == petInstanceId then
			pet.IsFavorite = not pet.IsFavorite
			
			-- Notify client
			if self.PetUpdateRemote then
				self.PetUpdateRemote:FireClient(player, "FavoriteToggled", petInstanceId, pet.IsFavorite)
			end
			
			return true
		end
	end
	
	return false
end

-- Add XP to a pet
function PetService:AddPetXP(player, petInstanceId, xpAmount)
	local pet = DataService:GetPetFromInventory(player, petInstanceId)
	if not pet then return false end
	
	local petConfig = PetConfig:GetPet(pet.PetId)
	if not petConfig then return false end
	
	-- Check if already max level
	if pet.Level >= petConfig.MaxLevel then
		return false
	end
	
	-- Add XP
	pet.XP = pet.XP + xpAmount
	
	-- Check for level up
	local xpNeeded = PetConfig:GetXPForLevel(pet.Level)
	local leveledUp = false
	
	while pet.XP >= xpNeeded and pet.Level < petConfig.MaxLevel do
		pet.XP = pet.XP - xpNeeded
		pet.Level = pet.Level + 1
		leveledUp = true
		
		-- Update stats
		pet.Stats.ClicksMultiplier = pet.Stats.ClicksMultiplier + petConfig.LevelUpBonus.ClicksMultiplier
		pet.Stats.GemsMultiplier = pet.Stats.GemsMultiplier + petConfig.LevelUpBonus.GemsMultiplier
		
		-- Get XP needed for next level
		xpNeeded = PetConfig:GetXPForLevel(pet.Level)
	end
	
	-- Mark data as dirty
	DataService:UpdatePlayerData(player, function(data)
		-- Data already modified above, just marking dirty
	end)
	
	-- Notify client
	if self.PetUpdateRemote then
		self.PetUpdateRemote:FireClient(player, "XPAdded", petInstanceId, xpAmount, leveledUp)
	end
	
	return true
end

-- Get total multiplier from all equipped pets
function PetService:GetTotalEquippedMultipliers(player)
	local equippedPets = DataService:GetEquippedPets(player)
	local totalClicksMultiplier = 1
	local totalGemsMultiplier = 1
	
	for _, pet in ipairs(equippedPets) do
		totalClicksMultiplier = totalClicksMultiplier + (pet.Stats.ClicksMultiplier - 1)
		totalGemsMultiplier = totalGemsMultiplier + (pet.Stats.GemsMultiplier - 1)
	end
	
	return {
		ClicksMultiplier = totalClicksMultiplier,
		GemsMultiplier = totalGemsMultiplier,
	}
end

-- Notify client of pet equipped
function PetService:NotifyPetEquipped(player, petInstanceId)
	if self.PetUpdateRemote then
		self.PetUpdateRemote:FireClient(player, "Equipped", petInstanceId)
	end
end

-- Notify client of pet unequipped
function PetService:NotifyPetUnequipped(player, petInstanceId)
	if self.PetUpdateRemote then
		self.PetUpdateRemote:FireClient(player, "Unequipped", petInstanceId)
	end
end

-- Clean up when player leaves
function PetService:CleanupPlayer(player)
	-- Remove all equipped pet models
	if equippedPetModels[player.UserId] then
		for _, model in pairs(equippedPetModels[player.UserId]) do
			if model then
				model:Destroy()
			end
		end
		equippedPetModels[player.UserId] = nil
	end
end

-- Initialize on module load
PetService:Initialize()

-- Connect to player leaving
Players.PlayerRemoving:Connect(function(player)
	PetService:CleanupPlayer(player)
end)

return PetService
