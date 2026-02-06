--[[
	EggService.lua
	Handles all egg-related operations including opening, validation, and result calculation
	Server-authoritative only - all critical operations happen here
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import configurations and modules
local EggConfig = require(ReplicatedStorage.Shared.Configs.EggConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Configs.RarityConfig)
local PetConfig = require(ReplicatedStorage.Shared.Configs.PetConfig)
local CurrencyConfig = require(ReplicatedStorage.Shared.Configs.CurrencyConfig)
local WeightedRandom = require(ReplicatedStorage.Shared.Modules.WeightedRandom)
local GUID = require(ReplicatedStorage.Shared.Modules.GUID)

-- Import services
local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local AntiCheatService = require(script.Parent.AntiCheatService)

-- EggService module
local EggService = {}
EggService.__index = EggService

-- Private variables
local openingCooldowns = {} -- Track player egg opening cooldowns
local activeOpenings = {} -- Track active egg openings per player

-- Initialize EggService
function EggService:Initialize()
	self:SetupRemoteEvents()
	print("[EggService] Initialized successfully")
end

-- Setup remote events
function EggService:SetupRemoteEvents()
	local remotes = ReplicatedStorage.Shared.Remotes
	
	-- Request egg opening
	local openEggRemote = Instance.new("RemoteEvent")
	openEggRemote.Name = "RequestOpenEgg"
	openEggRemote.Parent = remotes
	
	openEggRemote.OnServerEvent:Connect(function(player, eggId)
		self:HandleOpenEggRequest(player, eggId)
	end)
	
	-- Egg opened result (server to client)
	local eggOpenedRemote = Instance.new("RemoteEvent")
	eggOpenedRemote.Name = "EggOpened"
	eggOpenedRemote.Parent = remotes
	self.EggOpenedRemote = eggOpenedRemote
	
	-- Egg opening progress (server to client)
	local eggProgressRemote = Instance.new("RemoteEvent")
	eggProgressRemote.Name = "EggOpeningProgress"
	eggProgressRemote.Parent = remotes
	self.EggProgressRemote = eggProgressRemote
end

-- Handle egg opening request from client
function EggService:HandleOpenEggRequest(player, eggId)
	-- Validate request with AntiCheat
	local canOpen, reason = self:ValidateOpenRequest(player, eggId)
	
	if not canOpen then
		-- Notify client of failure
		if self.EggOpenedRemote then
			self.EggOpenedRemote:FireClient(player, false, reason)
		end
		return false, reason
	end
	
	-- Get egg configuration
	local eggConfig = EggConfig:GetEgg(eggId)
	if not eggConfig then
		return false, "Invalid egg"
	end
	
	-- Deduct currency
	local cost = eggConfig.Cost.Amount
	local currencyType = eggConfig.Cost.Currency
	
	local spendSuccess = CurrencyService:SpendCurrency(player, currencyType, cost)
	if not spendSuccess then
		return false, "Insufficient currency"
	end
	
	-- Set cooldown
	openingCooldowns[player.UserId] = tick()
	activeOpenings[player.UserId] = true
	
	-- Start opening sequence
	self:StartEggOpeningSequence(player, eggId, eggConfig)
	
	return true
end

-- Validate egg opening request
function EggService:ValidateOpenRequest(player, eggId)
	-- Check if player exists
	if not player or not player.Parent then
		return false, "Player not found"
	end
	
	-- Check AntiCheat status
	if AntiCheatService:IsPlayerFlagged(player) then
		return false, "Account under review"
	end
	
	-- Check if already opening an egg
	if activeOpenings[player.UserId] then
		return false, "Already opening an egg"
	end
	
	-- Check cooldown
	local lastOpen = openingCooldowns[player.UserId] or 0
	local timeSinceLastOpen = tick() - lastOpen
	if timeSinceLastOpen < EggConfig.OpeningSettings.Cooldown then
		return false, "Opening on cooldown"
	end
	
	-- Validate egg exists
	local eggConfig = EggConfig:GetEgg(eggId)
	if not eggConfig then
		return false, "Invalid egg type"
	end
	
	-- Check currency
	local cost = eggConfig.Cost.Amount
	local currencyType = eggConfig.Cost.Currency
	
	if not CurrencyService:CanAfford(player, currencyType, cost) then
		return false, "Insufficient " .. currencyType
	end
	
	-- Check inventory space
	local data = DataService:GetPlayerData(player)
	if data then
		local currentPets = #data.Inventory.Pets
		local maxSlots = data.Inventory.MaxSlots + data.Inventory.ExpandedSlots
		if currentPets >= maxSlots then
			return false, "Inventory full"
		end
	end
	
	return true
end

-- Start egg opening sequence
function EggService:StartEggOpeningSequence(player, eggId, eggConfig)
	-- Notify client to start animation
	if self.EggProgressRemote then
		self.EggProgressRemote:FireClient(player, "Start", eggId, eggConfig.AnimationDuration)
	end
	
	-- Calculate result immediately (server-side only)
	local result = self:CalculateEggResult(player, eggId)
	
	-- Wait for animation duration
	spawn(function()
		wait(eggConfig.AnimationDuration)
		
		-- Process the result
		self:ProcessEggResult(player, eggId, result)
		
		-- Clear active opening
		activeOpenings[player.UserId] = nil
	end)
	
	-- Send animation stage updates
	spawn(function()
		local stages = {
			{ Name = "Pulse", Time = 0 },
			{ Name = "Shake", Time = eggConfig.AnimationDuration * 0.3 },
			{ Name = "Crack", Time = eggConfig.AnimationDuration * 0.5 },
			{ Name = "Glow", Time = eggConfig.AnimationDuration * 0.7 },
			{ Name = "Explode", Time = eggConfig.AnimationDuration * 0.85 },
		}
		
		for _, stage in ipairs(stages) do
			wait(stage.Time)
			if self.EggProgressRemote and activeOpenings[player.UserId] then
				self.EggProgressRemote:FireClient(player, "Stage", stage.Name)
			end
		end
	end)
end

-- Calculate egg opening result (server-side only)
function EggService:CalculateEggResult(player, eggId)
	local eggConfig = EggConfig:GetEgg(eggId)
	if not eggConfig then return nil end
	
	-- Get player's luck multipliers
	local luckMultiplier = self:GetPlayerLuckMultiplier(player)
	
	-- Get pity counters
	local data = DataService:GetPlayerData(player)
	local pityCounters = data and data.Pity or {}
	
	-- Build pet pool with rarity info
	local petPool = {}
	for _, petEntry in ipairs(eggConfig.PetPool) do
		table.insert(petPool, {
			Item = petEntry,
			Weight = petEntry.Weight,
			Rarity = petEntry.Rarity,
		})
	end
	
	-- Select pet using weighted random with pity
	local selectedPetEntry = WeightedRandom:SelectWithPity(
		petPool, 
		pityCounters, 
		RarityConfig.PitySystem
	)
	
	if not selectedPetEntry then
		-- Fallback to first pet in pool
		selectedPetEntry = eggConfig.PetPool[1]
	end
	
	-- Get rarity info
	local rarityInfo = RarityConfig:GetRarity(selectedPetEntry.Rarity)
	
	-- Generate pet instance
	local petInstance = self:GeneratePetInstance(player, selectedPetEntry.PetId, selectedPetEntry.Rarity)
	
	return {
		PetInstance = petInstance,
		PetId = selectedPetEntry.PetId,
		Rarity = selectedPetEntry.Rarity,
		RarityInfo = rarityInfo,
		LuckMultiplier = luckMultiplier,
	}
end

-- Generate a new pet instance
function EggService:GeneratePetInstance(player, petId, rarity)
	local petConfig = PetConfig:GetPet(petId)
	if not petConfig then return nil end
	
	local instanceId = GUID:Generate()
	local now = os.time()
	
	local petInstance = {
		InstanceId = instanceId,
		PetId = petId,
		DisplayName = petConfig.DisplayName,
		Rarity = rarity,
		Level = 1,
		XP = 0,
		FusionTier = 1, -- 1 = Normal, 2 = Gold, 3 = Diamond, etc.
		IsEquipped = false,
		IsFavorite = false,
		AcquisitionTime = now,
		AcquisitionMethod = "Egg",
		OriginalOwner = player.UserId,
		TradeHistory = {},
		Stats = {
			ClicksMultiplier = petConfig.BaseStats.ClicksMultiplier,
			GemsMultiplier = petConfig.BaseStats.GemsMultiplier,
		},
	}
	
	return petInstance
end

-- Process egg opening result
function EggService:ProcessEggResult(player, eggId, result)
	if not result or not result.PetInstance then
		if self.EggOpenedRemote then
			self.EggOpenedRemote:FireClient(player, false, "Failed to generate pet")
		end
		return false
	end
	
	-- Add pet to inventory
	local addSuccess = DataService:AddPetToInventory(player, result.PetInstance)
	if not addSuccess then
		if self.EggOpenedRemote then
			self.EggOpenedRemote:FireClient(player, false, "Failed to add pet to inventory")
		end
		return false
	end
	
	-- Update pity counters
	local rarity = result.Rarity
	if rarity == "Legendary" or rarity == "Mythic" or rarity == "Secret" then
		-- Reset pity for this rarity and lower
		if rarity == "Secret" then
			DataService:ResetPity(player, "Secret")
			DataService:ResetPity(player, "Mythic")
			DataService:ResetPity(player, "Legendary")
		elseif rarity == "Mythic" then
			DataService:ResetPity(player, "Mythic")
			DataService:ResetPity(player, "Legendary")
		else
			DataService:ResetPity(player, "Legendary")
		end
	else
		-- Increment pity counters
		DataService:IncrementPity(player, "Legendary")
		DataService:IncrementPity(player, "Mythic")
		DataService:IncrementPity(player, "Secret")
	end
	
	-- Increment eggs opened stat
	DataService:IncrementEggsOpened(player)
	
	-- Send result to client
	if self.EggOpenedRemote then
		self.EggOpenedRemote:FireClient(player, true, {
			PetInstance = result.PetInstance,
			PetId = result.PetId,
			Rarity = result.Rarity,
			RarityInfo = {
				DisplayName = result.RarityInfo.DisplayName,
				Color = result.RarityInfo.Color,
				GlowColor = result.RarityInfo.GlowColor,
				GlowIntensity = result.RarityInfo.GlowIntensity,
				ParticleCount = result.RarityInfo.ParticleCount,
				HasScreenFlash = result.RarityInfo.HasScreenFlash,
				HasCameraShake = result.RarityInfo.HasCameraShake,
			},
		})
	end
	
	-- Handle special rarity announcements
	if result.RarityInfo.ServerNotification then
		self:SendServerNotification(player, result)
	end
	
	if result.RarityInfo.GlobalAnnouncement then
		self:SendGlobalAnnouncement(player, result)
	end
	
	return true
end

-- Get player's total luck multiplier
function EggService:GetPlayerLuckMultiplier(player)
	local data = DataService:GetPlayerData(player)
	if not data then return 1 end
	
	local multiplier = 1
	
	-- Apply active luck boosts
	for boostId, boostData in pairs(data.ActiveLuckBoosts or {}) do
		if boostData.ExpiresAt > os.time() then
			multiplier = multiplier * boostData.Multiplier
		end
	end
	
	-- Apply gamepass/VIP bonuses here if implemented
	
	return multiplier
end

-- Send server-wide notification for rare pets
function EggService:SendServerNotification(player, result)
	local message = player.Name .. " hatched a " .. result.Rarity .. " " .. result.PetInstance.DisplayName .. "!"
	
	-- Notify all players
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			-- You would use your notification system here
			-- For now, we'll use a remote event
			local notificationRemote = ReplicatedStorage.Shared.Remotes:FindFirstChild("ServerNotification")
			if notificationRemote then
				notificationRemote:FireClient(otherPlayer, message, result.RarityInfo.Color)
			end
		end
	end
end

-- Send global announcement for Secret pets
function EggService:SendGlobalAnnouncement(player, result)
	local message = "🎉 " .. player.Name .. " discovered a SECRET " .. result.PetInstance.DisplayName .. "! 🎉"
	
	-- Notify all players with special formatting
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		local announcementRemote = ReplicatedStorage.Shared.Remotes:FindFirstChild("GlobalAnnouncement")
		if announcementRemote then
			announcementRemote:FireClient(otherPlayer, message, result.RarityInfo.Color)
		end
	end
end

-- Get player's egg opening cooldown remaining
function EggService:GetCooldownRemaining(player)
	local lastOpen = openingCooldowns[player.UserId] or 0
	local elapsed = tick() - lastOpen
	local remaining = math.max(0, EggConfig.OpeningSettings.Cooldown - elapsed)
	return remaining
end

-- Check if player is currently opening an egg
function EggService:IsOpeningEgg(player)
	return activeOpenings[player.UserId] == true
end

-- Force cancel active opening (for admin purposes)
function EggService:CancelOpening(player)
	activeOpenings[player.UserId] = nil
end

-- Get available eggs for player
function EggService:GetAvailableEggs(player)
	local availableEggs = {}
	
	for eggId, eggConfig in pairs(EggConfig.Eggs) do
		local canAfford = CurrencyService:CanAfford(player, eggConfig.Cost.Currency, eggConfig.Cost.Amount)
		
		table.insert(availableEggs, {
			Id = eggId,
			DisplayName = eggConfig.DisplayName,
			Description = eggConfig.Description,
			Cost = eggConfig.Cost,
			CanAfford = canAfford,
			AnimationDuration = eggConfig.AnimationDuration,
		})
	end
	
	return availableEggs
end

-- Initialize on module load
EggService:Initialize()

return EggService
