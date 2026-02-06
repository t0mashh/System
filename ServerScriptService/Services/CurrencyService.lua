--[[
	CurrencyService.lua
	Handles all currency operations including earning, spending, and rebirth
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import configurations
local CurrencyConfig = require(ReplicatedStorage.Shared.Configs.CurrencyConfig)
local DataService = require(script.Parent.DataService)

-- CurrencyService module
local CurrencyService = {}
CurrencyService.__index = CurrencyService

-- Private variables
local clickCooldowns = {} -- Track player click cooldowns
local passiveIncomeConnections = {}

-- Initialize CurrencyService
function CurrencyService:Initialize()
	-- Set up remote events
	self:SetupRemoteEvents()
	
	print("[CurrencyService] Initialized successfully")
end

-- Setup remote events for client communication
function CurrencyService:SetupRemoteEvents()
	local remotes = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage:FindFirstChild("Shared")
	end
	
	-- Click remote
	local clickRemote = Instance.new("RemoteEvent")
	clickRemote.Name = "Click"
	clickRemote.Parent = remotes
	
	clickRemote.OnServerEvent:Connect(function(player)
		self:ProcessClick(player)
	end)
	
	-- Rebirth remote
	local rebirthRemote = Instance.new("RemoteEvent")
	rebirthRemote.Name = "RequestRebirth"
	rebirthRemote.Parent = remotes
	
	rebirthRemote.OnServerEvent:Connect(function(player)
		self:ProcessRebirth(player)
	end)
	
	-- Currency update remote (server to client)
	local currencyUpdateRemote = Instance.new("RemoteEvent")
	currencyUpdateRemote.Name = "CurrencyUpdated"
	currencyUpdateRemote.Parent = remotes
	self.CurrencyUpdateRemote = currencyUpdateRemote
end

-- Process a player click
function CurrencyService:ProcessClick(player)
	-- Check click cooldown (anti-auto-clicker)
	local now = tick()
	local lastClick = clickCooldowns[player.UserId] or 0
	local timeSinceLastClick = now - lastClick
	
	if timeSinceLastClick < (1 / CurrencyConfig.ClickSettings.MaxClicksPerSecond) then
		-- Clicking too fast, ignore
		return
	end
	
	clickCooldowns[player.UserId] = now
	
	-- Get equipped pets for multipliers
	local equippedPets = DataService:GetEquippedPets(player)
	local totalMultiplier = 1
	
	for _, pet in ipairs(equippedPets) do
		local PetConfig = require(ReplicatedStorage.Shared.Configs.PetConfig)
		local petConfig = PetConfig:GetPet(pet.PetId)
		if petConfig then
			local stats = PetConfig:GetPetStatsAtLevel(pet.PetId, pet.Level or 1)
			if stats then
				totalMultiplier = totalMultiplier + (stats.ClicksMultiplier - 1)
			end
		end
	end
	
	-- Calculate click value
	local baseValue = CurrencyConfig.ClickSettings.BaseClickValue
	local clickValue = math.floor(baseValue * totalMultiplier)
	
	-- Add currency
	DataService:AddCurrency(player, "Clicks", clickValue)
	DataService:AddClick(player)
	
	-- Notify client
	self:NotifyCurrencyUpdate(player, "Clicks", DataService:GetCurrency(player, "Clicks"))
	
	return clickValue
end

-- Get player's current currency amounts
function CurrencyService:GetPlayerCurrencies(player)
	return {
		Clicks = DataService:GetCurrency(player, "Clicks"),
		Gems = DataService:GetCurrency(player, "Gems"),
	}
end

-- Check if player can afford something
function CurrencyService:CanAfford(player, currencyType, amount)
	local currentAmount = DataService:GetCurrency(player, currencyType)
	return currentAmount >= amount
end

-- Spend currency (returns true if successful)
function CurrencyService:SpendCurrency(player, currencyType, amount)
	if amount <= 0 then return true end
	
	local success = DataService:RemoveCurrency(player, currencyType, amount)
	if success then
		self:NotifyCurrencyUpdate(player, currencyType, DataService:GetCurrency(player, currencyType))
	end
	
	return success
end

-- Award currency to player
function CurrencyService:AwardCurrency(player, currencyType, amount)
	if amount <= 0 then return false end
	
	local success = DataService:AddCurrency(player, currencyType, amount)
	if success then
		self:NotifyCurrencyUpdate(player, currencyType, DataService:GetCurrency(player, currencyType))
	end
	
	return success
end

-- Process rebirth
function CurrencyService:ProcessRebirth(player)
	local data = DataService:GetPlayerData(player)
	if not data then return false end
	
	local totalClicks = data.Stats.TotalClicks
	local rebirthCount = data.Stats.Rebirths
	
	-- Check minimum clicks requirement
	if totalClicks < CurrencyConfig.Rebirth.MinClicksForRebirth then
		return false, "Not enough clicks for rebirth"
	end
	
	-- Calculate gems to award
	local gemsToAward = CurrencyConfig:CalculateRebirthGems(totalClicks, rebirthCount)
	
	-- Perform rebirth
	local success = DataService:PerformRebirth(player, gemsToAward)
	
	if success then
		-- Notify client
		self:NotifyCurrencyUpdate(player, "Clicks", 0)
		self:NotifyCurrencyUpdate(player, "Gems", DataService:GetCurrency(player, "Gems"))
		
		return true, gemsToAward
	end
	
	return false, "Rebirth failed"
end

-- Get rebirth info for player
function CurrencyService:GetRebirthInfo(player)
	local data = DataService:GetPlayerData(player)
	if not data then return nil end
	
	local totalClicks = data.Stats.TotalClicks
	local rebirthCount = data.Stats.Rebirths
	local gemsOnRebirth = CurrencyConfig:CalculateRebirthGems(totalClicks, rebirthCount)
	
	return {
		CurrentRebirths = rebirthCount,
		TotalClicks = totalClicks,
		MinClicksRequired = CurrencyConfig.Rebirth.MinClicksForRebirth,
		GemsOnRebirth = gemsOnRebirth,
		CanRebirth = totalClicks >= CurrencyConfig.Rebirth.MinClicksForRebirth,
	}
end

-- Notify client of currency update
function CurrencyService:NotifyCurrencyUpdate(player, currencyType, newAmount)
	if self.CurrencyUpdateRemote then
		self.CurrencyUpdateRemote:FireClient(player, currencyType, newAmount)
	end
end

-- Setup passive income for player (based on equipped pets)
function CurrencyService:SetupPassiveIncome(player)
	-- Remove existing connection if any
	if passiveIncomeConnections[player.UserId] then
		passiveIncomeConnections[player.UserId]:Disconnect()
		passiveIncomeConnections[player.UserId] = nil
	end
	
	local connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
		local equippedPets = DataService:GetEquippedPets(player)
		local hasPassivePets = false
		local passiveAmount = 0
		
		for _, pet in ipairs(equippedPets) do
			local PetConfig = require(ReplicatedStorage.Shared.Configs.PetConfig)
			local petConfig = PetConfig:GetPet(pet.PetId)
			if petConfig and petConfig.PassiveAbility then
				hasPassivePets = true
				-- Calculate passive income based on pet stats
				local stats = PetConfig:GetPetStatsAtLevel(pet.PetId, pet.Level or 1)
				if stats then
					passiveAmount = passiveAmount + (stats.ClicksMultiplier * 0.1) -- 10% of multiplier as passive
				end
			end
		end
		
		if hasPassivePets and passiveAmount > 0 then
			-- Apply passive income (scaled by delta time)
			local income = math.floor(passiveAmount * dt)
			if income > 0 then
				DataService:AddCurrency(player, "Clicks", income)
			end
		end
	end)
	
	passiveIncomeConnections[player.UserId] = connection
end

-- Clean up when player leaves
function CurrencyService:CleanupPlayer(player)
	if passiveIncomeConnections[player.UserId] then
		passiveIncomeConnections[player.UserId]:Disconnect()
		passiveIncomeConnections[player.UserId] = nil
	end
	
	clickCooldowns[player.UserId] = nil
end

-- Initialize on module load
CurrencyService:Initialize()

-- Connect to player leaving
Players.PlayerRemoving:Connect(function(player)
	CurrencyService:CleanupPlayer(player)
end)

return CurrencyService
