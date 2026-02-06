--[[
	AntiCheatService.lua
	Comprehensive anti-cheat system with detection, logging, and enforcement
	All critical validations happen server-side
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Import configurations
local CurrencyConfig = require(ReplicatedStorage.Shared.Configs.CurrencyConfig)
local DataService = require(script.Parent.DataService)

-- AntiCheatService module
local AntiCheatService = {}
AntiCheatService.__index = AntiCheatService

-- Detection levels
local DETECTION_LEVELS = {
	SUSPICIOUS = 1,    -- Logging and monitoring
	PROBABLE = 2,      -- Kick with warning
	CONFIRMED = 3,     -- 24-hour temporary ban
	SEVERE = 4,        -- Permanent ban
}

-- Private variables
local playerClickHistory = {} -- Track click timestamps per player
local playerSuspicionScores = {} -- Track suspicion scores
local flaggedPlayers = {} -- List of flagged players
local detectionLogs = {} -- Log of all detections
local rateLimiters = {} -- Rate limiting for various actions

-- Configuration
local CONFIG = {
	MaxClicksPerSecond = 15,
	AutoClickerThreshold = 12, -- Clicks per second that trigger suspicion
	ClickPatternVariance = 0.1, -- Minimum variance expected in human clicking
	MaxCurrencyPerMinute = 1000000, -- Maximum reasonable currency gain
	MaxPositionDelta = 100, -- Maximum position change per second
	InventoryValidationInterval = 60, -- Seconds between inventory checks
	SuspicionThreshold = 100, -- Score before action is taken
	LogRetentionDays = 30,
}

-- Initialize AntiCheatService
function AntiCheatService:Initialize()
	self:SetupPlayerTracking()
	self:StartValidationLoops()
	print("[AntiCheatService] Initialized successfully")
end

-- Setup player tracking
function AntiCheatService:SetupPlayerTracking()
	Players.PlayerAdded:Connect(function(player)
		self:InitializePlayerTracking(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		self:CleanupPlayerTracking(player)
	end)
	
	-- Initialize tracking for existing players
	for _, player in ipairs(Players:GetPlayers()) do
		self:InitializePlayerTracking(player)
	end
end

-- Initialize tracking for a player
function AntiCheatService:InitializePlayerTracking(player)
	local userId = player.UserId
	
	playerClickHistory[userId] = {
		Timestamps = {},
		LastClickTime = 0,
		ClickCount = 0,
	}
	
	playerSuspicionScores[userId] = 0
	rateLimiters[userId] = {}
	
	-- Track position for teleport detection
	spawn(function()
		while player and player.Parent do
			self:TrackPlayerPosition(player)
			wait(1)
		end
	end)
end

-- Cleanup player tracking
function AntiCheatService:CleanupPlayerTracking(player)
	local userId = player.UserId
	
	playerClickHistory[userId] = nil
	playerSuspicionScores[userId] = nil
	rateLimiters[userId] = nil
end

-- Start validation loops
function AntiCheatService:StartValidationLoops()
	-- Inventory validation loop
	spawn(function()
		while true do
			wait(CONFIG.InventoryValidationInterval)
			self:ValidateAllInventories()
		end
	end)
	
	-- Currency sanity check loop
	spawn(function()
		while true do
			wait(60)
			self:CheckCurrencySanity()
		end
	end)
end

-- Validate click rate
function AntiCheatService:ValidateClickRate(player)
	local userId = player.UserId
	local history = playerClickHistory[userId]
	
	if not history then
		return true
	end
	
	local now = tick()
	local recentClicks = 0
	local oneSecondAgo = now - 1
	
	-- Count clicks in last second
	for i = #history.Timestamps, 1, -1 do
		if history.Timestamps[i] >= oneSecondAgo then
			recentClicks = recentClicks + 1
		else
			-- Remove old timestamps
			table.remove(history.Timestamps, i)
		end
	end
	
	-- Record this click
	table.insert(history.Timestamps, now)
	history.LastClickTime = now
	history.ClickCount = history.ClickCount + 1
	
	-- Check if clicking too fast
	if recentClicks > CONFIG.MaxClicksPerSecond then
		self:LogDetection(player, "ClickRateExceeded", {
			ClicksPerSecond = recentClicks,
			Threshold = CONFIG.MaxClicksPerSecond,
		}, DETECTION_LEVELS.PROBABLE)
		return false
	end
	
	-- Check for auto-clicker pattern (too consistent)
	if recentClicks >= CONFIG.AutoClickerThreshold then
		local variance = self:CalculateClickVariance(history.Timestamps)
		if variance < CONFIG.ClickPatternVariance then
			self:LogDetection(player, "AutoClickerPattern", {
				Variance = variance,
				Threshold = CONFIG.ClickPatternVariance,
			}, DETECTION_LEVELS.SUSPICIOUS)
		end
	end
	
	return true
end

-- Calculate variance in click timestamps
function AntiCheatService:CalculateClickVariance(timestamps)
	if #timestamps < 3 then
		return 1 -- Not enough data
	end
	
	-- Calculate intervals between clicks
	local intervals = {}
	for i = 2, #timestamps do
		local interval = timestamps[i] - timestamps[i-1]
		table.insert(intervals, interval)
	end
	
	-- Calculate mean
	local sum = 0
	for _, interval in ipairs(intervals) do
		sum = sum + interval
	end
	local mean = sum / #intervals
	
	-- Calculate variance
	local varianceSum = 0
	for _, interval in ipairs(intervals) do
		varianceSum = varianceSum + math.abs(interval - mean)
	end
	
	return varianceSum / #intervals
end

-- Track player position for teleport detection
function AntiCheatService:TrackPlayerPosition(player)
	if not player.Character then return end
	
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local currentPosition = hrp.Position
	local lastPosition = player:GetAttribute("LastTrackedPosition")
	local lastTime = player:GetAttribute("LastTrackedTime") or tick()
	
	if lastPosition then
		local deltaTime = tick() - lastTime
		local distance = (currentPosition - lastPosition).Magnitude
		local speed = distance / deltaTime
		
		-- Check for impossible movement
		if speed > CONFIG.MaxPositionDelta then
			self:LogDetection(player, "ImpossibleMovement", {
				Speed = speed,
				MaxAllowed = CONFIG.MaxPositionDelta,
				Distance = distance,
			}, DETECTION_LEVELS.PROBABLE)
		end
	end
	
	player:SetAttribute("LastTrackedPosition", currentPosition)
	player:SetAttribute("LastTrackedTime", tick())
end

-- Validate currency transaction
function AntiCheatService:ValidateCurrencyTransaction(player, currencyType, amount, transactionType)
	-- Check for negative amounts
	if amount < 0 then
		self:LogDetection(player, "NegativeCurrencyTransaction", {
			Currency = currencyType,
			Amount = amount,
			Type = transactionType,
		}, DETECTION_LEVELS.SEVERE)
		return false
	end
	
	-- Check for unreasonable amounts
	local data = DataService:GetPlayerData(player)
	if data then
		local currentAmount = data.Currencies[currencyType] or 0
		
		if transactionType == "Add" then
			-- Check if adding would exceed maximum
			local CurrencyConfig = require(ReplicatedStorage.Shared.Configs.CurrencyConfig)
			local currencyConfig = CurrencyConfig:GetCurrency(currencyType)
			
			if currencyConfig and currentAmount + amount > currencyConfig.MaxAmount then
				self:LogDetection(player, "CurrencyCapExceeded", {
					Currency = currencyType,
					Current = currentAmount,
					AttemptedAdd = amount,
					Max = currencyConfig.MaxAmount,
				}, DETECTION_LEVELS.CONFIRMED)
				return false
			end
		elseif transactionType == "Remove" then
			-- Check for overspending
			if amount > currentAmount then
				self:LogDetection(player, "OverspendAttempt", {
					Currency = currencyType,
					Current = currentAmount,
					AttemptedSpend = amount,
				}, DETECTION_LEVELS.SEVERE)
				return false
			end
		end
	end
	
	return true
end

-- Validate inventory operation
function AntiCheatService:ValidateInventoryOperation(player, operation, petInstanceId)
	local data = DataService:GetPlayerData(player)
	if not data then
		return false, "No player data"
	end
	
	if operation == "Add" then
		-- Check inventory space
		local currentPets = #data.Inventory.Pets
		local maxSlots = data.Inventory.MaxSlots + data.Inventory.ExpandedSlots
		
		if currentPets >= maxSlots then
			return false, "Inventory full"
		end
	elseif operation == "Remove" or operation == "Equip" or operation == "Unequip" then
		-- Verify pet exists
		local petExists = false
		for _, pet in ipairs(data.Inventory.Pets) do
			if pet.InstanceId == petInstanceId then
				petExists = true
				break
			end
		end
		
		if not petExists then
			self:LogDetection(player, "InvalidPetOperation", {
				Operation = operation,
				PetInstanceId = petInstanceId,
			}, DETECTION_LEVELS.SEVERE)
			return false, "Pet not found"
		end
	end
	
	return true
end

-- Validate egg opening request
function AntiCheatService:ValidateEggOpening(player, eggId)
	-- Check rate limit
	if not self:CheckRateLimit(player, "EggOpen", 0.5) then
		self:LogDetection(player, "EggOpenRateLimit", {}, DETECTION_LEVELS.SUSPICIOUS)
		return false, "Rate limited"
	end
	
	return true
end

-- Check rate limit for an action
function AntiCheatService:CheckRateLimit(player, actionType, cooldown)
	local userId = player.UserId
	
	if not rateLimiters[userId] then
		rateLimiters[userId] = {}
	end
	
	local lastAction = rateLimiters[userId][actionType] or 0
	local timeSinceLastAction = tick() - lastAction
	
	if timeSinceLastAction < cooldown then
		return false
	end
	
	rateLimiters[userId][actionType] = tick()
	return true
end

-- Validate all inventories
function AntiCheatService:ValidateAllInventories()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService:GetPlayerData(player)
		if data then
			self:ValidatePlayerInventory(player, data)
		end
	end
end

-- Validate a single player's inventory
function AntiCheatService:ValidatePlayerInventory(player, data)
	local pets = data.Inventory.Pets
	local instanceIds = {}
	
	for _, pet in ipairs(pets) do
		-- Check for duplicate instance IDs
		if instanceIds[pet.InstanceId] then
			self:LogDetection(player, "DuplicatePetInstanceId", {
				InstanceId = pet.InstanceId,
				PetId = pet.PetId,
			}, DETECTION_LEVELS.SEVERE)
			
			-- Generate new ID for duplicate
			pet.InstanceId = require(ReplicatedStorage.Shared.Modules.GUID):Generate()
		else
			instanceIds[pet.InstanceId] = true
		end
		
		-- Validate pet data integrity
		if not pet.PetId or not pet.Rarity or not pet.Level then
			self:LogDetection(player, "CorruptedPetData", {
				InstanceId = pet.InstanceId,
			}, DETECTION_LEVELS.CONFIRMED)
		end
	end
	
	-- Validate equipped pets exist in inventory
	for _, equippedId in ipairs(data.Equipment.EquippedPets) do
		local found = false
		for _, pet in ipairs(pets) do
			if pet.InstanceId == equippedId then
				found = true
				break
			end
		end
		
		if not found then
			self:LogDetection(player, "EquippedPetNotInInventory", {
				EquippedId = equippedId,
			}, DETECTION_LEVELS.SEVERE)
		end
	end
end

-- Check currency sanity across all players
function AntiCheatService:CheckCurrencySanity()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService:GetPlayerData(player)
		if data then
			-- Check for negative currencies
			for currencyType, amount in pairs(data.Currencies) do
				if amount < 0 then
					self:LogDetection(player, "NegativeCurrency", {
						Currency = currencyType,
						Amount = amount,
					}, DETECTION_LEVELS.SEVERE)
					
					-- Correct the value
					data.Currencies[currencyType] = 0
				end
			end
		end
	end
end

-- Log a detection event
function AntiCheatService:LogDetection(player, detectionType, details, level)
	level = level or DETECTION_LEVELS.SUSPICIOUS
	
	local logEntry = {
		Timestamp = os.time(),
		UserId = player.UserId,
		Username = player.Name,
		DetectionType = detectionType,
		Details = details,
		Level = level,
	}
	
	table.insert(detectionLogs, logEntry)
	
	-- Add to player's suspicion score
	local suspicionValue = level * 10
	playerSuspicionScores[player.UserId] = (playerSuspicionScores[player.UserId] or 0) + suspicionValue
	
	-- Print to console
	print(string.format(
		"[AntiCheat] Detection: %s | Player: %s | Level: %d | Score: %d",
		detectionType,
		player.Name,
		level,
		playerSuspicionScores[player.UserId]
	))
	
	-- Take action if threshold reached
	if playerSuspicionScores[player.UserId] >= CONFIG.SuspicionThreshold then
		self:TakeAction(player, level)
	end
	
	-- Store in player data for review
	DataService:UpdatePlayerData(player, function(data)
		data.AntiCheat.SuspiciousActivityCount = data.AntiCheat.SuspiciousActivityCount + 1
		data.AntiCheat.LastWarningTime = os.time()
	end)
end

-- Take action based on detection level
function AntiCheatService:TakeAction(player, level)
	if level == DETECTION_LEVELS.SUSPICIOUS then
		-- Just monitoring, no action needed
		return
	elseif level == DETECTION_LEVELS.PROBABLE then
		-- Kick with warning
		player:Kick("Unusual activity detected. Please avoid using automation tools.")
	elseif level == DETECTION_LEVELS.CONFIRMED then
		-- Flag for ban and kick
		flaggedPlayers[player.UserId] = {
			FlaggedAt = os.time(),
			Reason = "Confirmed cheating",
			Duration = 86400, -- 24 hours
		}
		player:Kick("Cheating detected. Your account has been suspended for 24 hours.")
	elseif level == DETECTION_LEVELS.SEVERE then
		-- Permanent ban
		flaggedPlayers[player.UserId] = {
			FlaggedAt = os.time(),
			Reason = "Severe cheating",
			Duration = -1, -- Permanent
		}
		player:Kick("Severe cheating detected. Your account has been permanently banned.")
	end
end

-- Check if player is flagged
function AntiCheatService:IsPlayerFlagged(player)
	return flaggedPlayers[player.UserId] ~= nil
end

-- Get player's suspicion score
function AntiCheatService:GetSuspicionScore(player)
	return playerSuspicionScores[player.UserId] or 0
end

-- Get detection logs (for admin review)
function AntiCheatService:GetDetectionLogs(playerFilter, levelFilter, timeRange)
	local filteredLogs = {}
	
	for _, log in ipairs(detectionLogs) do
		local include = true
		
		if playerFilter and log.UserId ~= playerFilter then
			include = false
		end
		
		if levelFilter and log.Level < levelFilter then
			include = false
		end
		
		if timeRange and log.Timestamp < timeRange then
			include = false
		end
		
		if include then
			table.insert(filteredLogs, log)
		end
	end
	
	return filteredLogs
end

-- Clear old logs
function AntiCheatService:ClearOldLogs()
	local cutoffTime = os.time() - (CONFIG.LogRetentionDays * 86400)
	local newLogs = {}
	
	for _, log in ipairs(detectionLogs) do
		if log.Timestamp >= cutoffTime then
			table.insert(newLogs, log)
		end
	end
	
	detectionLogs = newLogs
end

-- Initialize on module load
AntiCheatService:Initialize()

return AntiCheatService
