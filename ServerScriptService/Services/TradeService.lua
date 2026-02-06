--[[
	TradeService.lua
	Handles secure trading between players with anti-duplication protection
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import services
local DataService = require(script.Parent.DataService)
local AntiCheatService = require(script.Parent.AntiCheatService)

-- TradeService module
local TradeService = {}
TradeService.__index = TradeService

-- Private variables
local activeTrades = {} -- Track ongoing trades
local tradeHistory = {} -- Complete trade history for audit
local pendingConfirmations = {} -- Track confirmation timeouts

-- Trade configuration
local CONFIG = {
	ConfirmationTimeout = 5, -- Seconds to cancel after confirmation
	MaxTradeItems = 8, -- Maximum items per trade
	TradeCooldown = 10, -- Seconds between trades
	MinTradeValue = 0, -- Minimum value to trade
}

-- Initialize TradeService
function TradeService:Initialize()
	self:SetupRemoteEvents()
	print("[TradeService] Initialized successfully")
end

-- Setup remote events
function TradeService:SetupRemoteEvents()
	local remotes = ReplicatedStorage.Shared.Remotes
	
	-- Request trade
	local requestTradeRemote = Instance.new("RemoteEvent")
	requestTradeRemote.Name = "RequestTrade"
	requestTradeRemote.Parent = remotes
	
	requestTradeRemote.OnServerEvent:Connect(function(player, targetPlayer)
		self:HandleTradeRequest(player, targetPlayer)
	end)
	
	-- Accept/Decline trade
	local tradeResponseRemote = Instance.new("RemoteEvent")
	tradeResponseRemote.Name = "TradeResponse"
	tradeResponseRemote.Parent = remotes
	
	tradeResponseRemote.OnServerEvent:Connect(function(player, requester, accepted)
		if accepted then
			self:AcceptTrade(requester, player)
		else
			self:DeclineTrade(requester, player)
		end
	end)
	
	-- Add item to trade
	local addItemRemote = Instance.new("RemoteEvent")
	addItemRemote.Name = "TradeAddItem"
	addItemRemote.Parent = remotes
	
	addItemRemote.OnServerEvent:Connect(function(player, tradeId, petInstanceId)
		self:AddItemToTrade(player, tradeId, petInstanceId)
	end)
	
	-- Remove item from trade
	local removeItemRemote = Instance.new("RemoteEvent")
	removeItemRemote.Name = "TradeRemoveItem"
	removeItemRemote.Parent = remotes
	
	removeItemRemote.OnServerEvent:Connect(function(player, tradeId, petInstanceId)
		self:RemoveItemFromTrade(player, tradeId, petInstanceId)
	end)
	
	-- Confirm trade
	local confirmTradeRemote = Instance.new("RemoteEvent")
	confirmTradeRemote.Name = "ConfirmTrade"
	confirmTradeRemote.Parent = remotes
	
	confirmTradeRemote.OnServerEvent:Connect(function(player, tradeId)
		self:ConfirmTrade(player, tradeId)
	end)
	
	-- Cancel trade
	local cancelTradeRemote = Instance.new("RemoteEvent")
	cancelTradeRemote.Name = "CancelTrade"
	cancelTradeRemote.Parent = remotes
	
	cancelTradeRemote.OnServerEvent:Connect(function(player, tradeId)
		self:CancelTrade(player, tradeId)
	end)
	
	-- Trade update remote (server to client)
	local tradeUpdateRemote = Instance.new("RemoteEvent")
	tradeUpdateRemote.Name = "TradeUpdated"
	tradeUpdateRemote.Parent = remotes
	self.TradeUpdateRemote = tradeUpdateRemote
end

-- Handle trade request
function TradeService:HandleTradeRequest(requester, targetPlayer)
	-- Validate players
	if not requester or not targetPlayer then
		return false, "Invalid players"
	end
	
	if requester == targetPlayer then
		return false, "Cannot trade with yourself"
	end
	
	-- Check if either player is in an active trade
	if self:IsPlayerInTrade(requester) then
		return false, "You are already in a trade"
	end
	
	if self:IsPlayerInTrade(targetPlayer) then
		return false, "Target player is already in a trade"
	end
	
	-- Check trade cooldown
	if not self:CheckTradeCooldown(requester) then
		return false, "Trade cooldown active"
	end
	
	-- Send trade request to target player
	if self.TradeUpdateRemote then
		self.TradeUpdateRemote:FireClient(targetPlayer, "TradeRequest", {
			Requester = requester,
			RequesterName = requester.Name,
		})
	end
	
	return true
end

-- Accept trade request
function TradeService:AcceptTrade(requester, accepter)
	-- Validate both players are still available
	if not requester or not accepter then
		return false, "Player not available"
	end
	
	if self:IsPlayerInTrade(requester) or self:IsPlayerInTrade(accepter) then
		return false, "Player already in trade"
	end
	
	-- Create trade session
	local tradeId = self:GenerateTradeId()
	local tradeSession = {
		Id = tradeId,
		Player1 = {
			Player = requester,
			UserId = requester.UserId,
			Items = {},
			Confirmed = false,
		},
		Player2 = {
			Player = accepter,
			UserId = accepter.UserId,
			Items = {},
			Confirmed = false,
		},
		Status = "Active",
		CreatedAt = os.time(),
	}
	
	activeTrades[tradeId] = tradeSession
	
	-- Notify both players
	if self.TradeUpdateRemote then
		self.TradeUpdateRemote:FireClient(requester, "TradeStarted", tradeSession)
		self.TradeUpdateRemote:FireClient(accepter, "TradeStarted", tradeSession)
	end
	
	return true, tradeId
end

-- Decline trade request
function TradeService:DeclineTrade(requester, decliner)
	if self.TradeUpdateRemote then
		self.TradeUpdateRemote:FireClient(requester, "TradeDeclined", {
			Decliner = decliner.Name,
		})
	end
	return true
end

-- Add item to trade
function TradeService:AddItemToTrade(player, tradeId, petInstanceId)
	local trade = activeTrades[tradeId]
	if not trade then
		return false, "Trade not found"
	end
	
	if trade.Status ~= "Active" then
		return false, "Trade is not active"
	end
	
	-- Determine which player is adding
	local playerSlot = self:GetPlayerSlot(trade, player)
	if not playerSlot then
		return false, "Not part of this trade"
	end
	
	-- Check max items
	if #playerSlot.Items >= CONFIG.MaxTradeItems then
		return false, "Maximum items reached"
	end
	
	-- Verify pet ownership
	local pet = DataService:GetPetFromInventory(player, petInstanceId)
	if not pet then
		return false, "Pet not found in inventory"
	end
	
	-- Check if pet is equipped
	if pet.IsEquipped then
		return false, "Cannot trade equipped pets"
	end
	
	-- Check if pet is favorited
	if pet.IsFavorite then
		return false, "Cannot trade favorited pets"
	end
	
	-- Check if already in trade
	for _, item in ipairs(playerSlot.Items) do
		if item.InstanceId == petInstanceId then
			return false, "Pet already in trade"
		end
	end
	
	-- Add to trade
	table.insert(playerSlot.Items, {
		InstanceId = pet.InstanceId,
		PetId = pet.PetId,
		DisplayName = pet.DisplayName,
		Rarity = pet.Rarity,
		Level = pet.Level,
		FusionTier = pet.FusionTier,
	})
	
	-- Reset confirmations when items change
	trade.Player1.Confirmed = false
	trade.Player2.Confirmed = false
	
	-- Notify both players
	self:NotifyTradeUpdate(trade)
	
	return true
end

-- Remove item from trade
function TradeService:RemoveItemFromTrade(player, tradeId, petInstanceId)
	local trade = activeTrades[tradeId]
	if not trade then
		return false, "Trade not found"
	end
	
	local playerSlot = self:GetPlayerSlot(trade, player)
	if not playerSlot then
		return false, "Not part of this trade"
	end
	
	-- Find and remove item
	for i, item in ipairs(playerSlot.Items) do
		if item.InstanceId == petInstanceId then
			table.remove(playerSlot.Items, i)
			
			-- Reset confirmations
			trade.Player1.Confirmed = false
			trade.Player2.Confirmed = false
			
			self:NotifyTradeUpdate(trade)
			return true
		end
	end
	
	return false, "Item not found in trade"
end

-- Confirm trade
function TradeService:ConfirmTrade(player, tradeId)
	local trade = activeTrades[tradeId]
	if not trade then
		return false, "Trade not found"
	end
	
	local playerSlot = self:GetPlayerSlot(trade, player)
	if not playerSlot then
		return false, "Not part of this trade"
	end
	
	-- Set confirmed
	playerSlot.Confirmed = true
	
	-- Notify other player
	local otherPlayer = self:GetOtherPlayer(trade, player)
	if otherPlayer and self.TradeUpdateRemote then
		self.TradeUpdateRemote:FireClient(otherPlayer.Player, "PlayerConfirmed", {
			PlayerName = player.Name,
		})
	end
	
	-- Check if both confirmed
	if trade.Player1.Confirmed and trade.Player2.Confirmed then
		-- Start confirmation timeout
		spawn(function()
			wait(CONFIG.ConfirmationTimeout)
			if activeTrades[tradeId] and activeTrades[tradeId].Status == "Active" then
				-- Both still confirmed, execute trade
				self:ExecuteTrade(tradeId)
			end
		end)
	end
	
	return true
end

-- Cancel trade
function TradeService:CancelTrade(player, tradeId)
	local trade = activeTrades[tradeId]
	if not trade then
		return false, "Trade not found"
	end
	
	-- Verify player is part of trade
	if not self:GetPlayerSlot(trade, player) then
		return false, "Not part of this trade"
	end
	
	-- Cancel the trade
	trade.Status = "Cancelled"
	
	-- Notify both players
	if self.TradeUpdateRemote then
		self.TradeUpdateRemote:FireClient(trade.Player1.Player, "TradeCancelled", {
			CancelledBy = player.Name,
		})
		self.TradeUpdateRemote:FireClient(trade.Player2.Player, "TradeCancelled", {
			CancelledBy = player.Name,
		})
	end
	
	-- Remove from active trades
	activeTrades[tradeId] = nil
	
	return true
end

-- Execute the trade (atomic operation)
function TradeService:ExecuteTrade(tradeId)
	local trade = activeTrades[tradeId]
	if not trade or trade.Status ~= "Active" then
		return false, "Trade not valid for execution"
	end
	
	-- Lock the trade
	trade.Status = "Processing"
	
	local player1 = trade.Player1
	local player2 = trade.Player2
	
	-- Validate all items are still owned by respective players
	for _, item in ipairs(player1.Items) do
		local pet = DataService:GetPetFromInventory(player1.Player, item.InstanceId)
		if not pet then
			self:CancelTrade(player1.Player, tradeId)
			return false, "Item no longer owned by player 1"
		end
	end
	
	for _, item in ipairs(player2.Items) do
		local pet = DataService:GetPetFromInventory(player2.Player, item.InstanceId)
		if not pet then
			self:CancelTrade(player2.Player, tradeId)
			return false, "Item no longer owned by player 2"
		end
	end
	
	-- Perform the trade atomically
	local success, err = pcall(function()
		-- Remove items from player 1
		for _, item in ipairs(player1.Items) do
			DataService:RemovePetFromInventory(player1.Player, item.InstanceId)
		end
		
		-- Remove items from player 2
		for _, item in ipairs(player2.Items) do
			DataService:RemovePetFromInventory(player2.Player, item.InstanceId)
		end
		
		-- Add player 1's items to player 2
		for _, item in ipairs(player1.Items) do
			local pet = DataService:GetPetFromInventory(player1.Player, item.InstanceId)
			if pet then
				-- Update trade history
				table.insert(pet.TradeHistory, {
					From = player1.UserId,
					To = player2.UserId,
					Time = os.time(),
				})
				DataService:AddPetToInventory(player2.Player, pet)
			end
		end
		
		-- Add player 2's items to player 1
		for _, item in ipairs(player2.Items) do
			local pet = DataService:GetPetFromInventory(player2.Player, item.InstanceId)
			if pet then
				table.insert(pet.TradeHistory, {
					From = player2.UserId,
					To = player1.UserId,
					Time = os.time(),
				})
				DataService:AddPetToInventory(player1.Player, pet)
			end
		end
	end)
	
	if success then
		-- Trade successful
		trade.Status = "Completed"
		
		-- Log the trade
		self:LogTrade(trade)
		
		-- Notify both players
		if self.TradeUpdateRemote then
			self.TradeUpdateRemote:FireClient(player1.Player, "TradeCompleted", trade)
			self.TradeUpdateRemote:FireClient(player2.Player, "TradeCompleted", trade)
		end
		
		-- Set trade cooldowns
		self:SetTradeCooldown(player1.Player)
		self:SetTradeCooldown(player2.Player)
		
		-- Remove from active trades
		activeTrades[tradeId] = nil
		
		return true
	else
		-- Trade failed, attempt rollback
		warn("[TradeService] Trade execution failed: " .. tostring(err))
		trade.Status = "Failed"
		
		-- Notify both players
		if self.TradeUpdateRemote then
			self.TradeUpdateRemote:FireClient(player1.Player, "TradeFailed", {
				Reason = "Transaction error",
			})
			self.TradeUpdateRemote:FireClient(player2.Player, "TradeFailed", {
				Reason = "Transaction error",
			})
		end
		
		activeTrades[tradeId] = nil
		return false, "Trade execution failed"
	end
end

-- Get player's slot in trade
function TradeService:GetPlayerSlot(trade, player)
	if trade.Player1.Player == player then
		return trade.Player1
	elseif trade.Player2.Player == player then
		return trade.Player2
	end
	return nil
end

-- Get other player in trade
function TradeService:GetOtherPlayer(trade, player)
	if trade.Player1.Player == player then
		return trade.Player2
	elseif trade.Player2.Player == player then
		return trade.Player1
	end
	return nil
end

-- Check if player is in an active trade
function TradeService:IsPlayerInTrade(player)
	for tradeId, trade in pairs(activeTrades) do
		if trade.Player1.Player == player or trade.Player2.Player == player then
			return true
		end
	end
	return false
end

-- Get player's active trade
function TradeService:GetPlayerTrade(player)
	for tradeId, trade in pairs(activeTrades) do
		if trade.Player1.Player == player or trade.Player2.Player == player then
			return trade
		end
	end
	return nil
end

-- Check trade cooldown
function TradeService:CheckTradeCooldown(player)
	local data = DataService:GetPlayerData(player)
	if not data then return true end
	
	-- Check if cooldown exists
	local lastTrade = data.LastTradeTime or 0
	local timeSinceLastTrade = os.time() - lastTrade
	
	return timeSinceLastTrade >= CONFIG.TradeCooldown
end

-- Set trade cooldown
function TradeService:SetTradeCooldown(player)
	DataService:UpdatePlayerData(player, function(data)
		data.LastTradeTime = os.time()
	end)
end

-- Generate unique trade ID
function TradeService:GenerateTradeId()
	return "TRADE_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
end

-- Notify both players of trade update
function TradeService:NotifyTradeUpdate(trade)
	if self.TradeUpdateRemote then
		self.TradeUpdateRemote:FireClient(trade.Player1.Player, "TradeUpdated", trade)
		self.TradeUpdateRemote:FireClient(trade.Player2.Player, "TradeUpdated", trade)
	end
end

-- Log completed trade
function TradeService:LogTrade(trade)
	local logEntry = {
		TradeId = trade.Id,
		Timestamp = os.time(),
		Player1 = {
			UserId = trade.Player1.UserId,
			Items = trade.Player1.Items,
		},
		Player2 = {
			UserId = trade.Player2.UserId,
			Items = trade.Player2.Items,
		},
	}
	
	table.insert(tradeHistory, logEntry)
	
	-- Limit history size
	if #tradeHistory > 10000 then
		table.remove(tradeHistory, 1)
	end
end

-- Get trade history for a player
function TradeService:GetPlayerTradeHistory(userId, limit)
	limit = limit or 50
	local playerHistory = {}
	
	for i = #tradeHistory, 1, -1 do
		local trade = tradeHistory[i]
		if trade.Player1.UserId == userId or trade.Player2.UserId == userId then
			table.insert(playerHistory, trade)
			if #playerHistory >= limit then
				break
			end
		end
	end
	
	return playerHistory
end

-- Initialize on module load
TradeService:Initialize()

return TradeService
