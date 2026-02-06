--[[
	UIController.lua
	Main UI controller handling all UI interactions and updates
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage.Shared.Remotes

-- UIController module
local UIController = {}
UIController.__index = UIController

-- UI References (will be connected to actual UI elements)
local uiReferences = {
	CurrencyDisplay = nil,
	EggOpeningFrame = nil,
	InventoryFrame = nil,
	LeaderboardFrame = nil,
	NotificationFrame = nil,
}

-- State
local state = {
	CurrentCurrencies = {
		Clicks = 0,
		Gems = 0,
	},
	IsEggOpening = false,
	CurrentInventory = nil,
	CurrentLeaderboard = nil,
}

-- Initialize UIController
function UIController:Initialize()
	self:SetupRemoteListeners()
	self:SetupUIReferences()
	self:RequestInitialData()
	print("[UIController] Initialized")
end

-- Setup remote event listeners
function UIController:SetupRemoteListeners()
	-- Currency updates
	remotes.CurrencyUpdated.OnClientEvent:Connect(function(currencyType, newAmount)
		self:OnCurrencyUpdated(currencyType, newAmount)
	end)
	
	-- Egg opening progress
	remotes.EggOpeningProgress.OnClientEvent:Connect(function(eventType, data, duration)
		self:OnEggOpeningProgress(eventType, data, duration)
	end)
	
	-- Egg opened result
	remotes.EggOpened.OnClientEvent:Connect(function(success, result)
		self:OnEggOpened(success, result)
	end)
	
	-- Inventory updates
	remotes.InventoryUpdated.OnClientEvent:Connect(function(inventory)
		self:OnInventoryUpdated(inventory)
	end)
	
	-- Pet updates
	remotes.PetUpdated.OnClientEvent:Connect(function(eventType, data)
		self:OnPetUpdated(eventType, data)
	end)
	
	-- Leaderboard updates
	remotes.LeaderboardUpdated.OnClientEvent:Connect(function(eventType, category, data)
		self:OnLeaderboardUpdated(eventType, category, data)
	end)
	
	-- Trade updates
	remotes.TradeUpdated.OnClientEvent:Connect(function(eventType, data)
		self:OnTradeUpdated(eventType, data)
	end)
	
	-- Notifications
	remotes.ServerNotification.OnClientEvent:Connect(function(message, color)
		self:ShowNotification(message, color, "Server")
	end)
	
	remotes.GlobalAnnouncement.OnClientEvent:Connect(function(message, color)
		self:ShowGlobalAnnouncement(message, color)
	end)
end

-- Setup UI references (connect to actual UI elements)
function UIController:SetupUIReferences()
	-- This will be populated when UI assets are provided
	-- For now, create placeholder references
	
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Wait for UI to load
	local mainUI = playerGui:WaitForChild("MainUI", 5)
	if mainUI then
		uiReferences.CurrencyDisplay = mainUI:FindFirstChild("CurrencyDisplay")
		uiReferences.EggOpeningFrame = mainUI:FindFirstChild("EggOpeningFrame")
		uiReferences.InventoryFrame = mainUI:FindFirstChild("InventoryFrame")
		uiReferences.LeaderboardFrame = mainUI:FindFirstChild("LeaderboardFrame")
		uiReferences.NotificationFrame = mainUI:FindFirstChild("NotificationFrame")
	end
end

-- Request initial data from server
function UIController:RequestInitialData()
	-- Request inventory
	remotes.RequestInventory:FireServer()
	
	-- Request leaderboards
	for _, category in ipairs({"Clicks", "Gems", "EggsOpened", "Rebirths"}) do
		remotes.RequestLeaderboard:FireServer(category)
	end
end

-- Currency update handler
function UIController:OnCurrencyUpdated(currencyType, newAmount)
	local oldAmount = state.CurrentCurrencies[currencyType] or 0
	state.CurrentCurrencies[currencyType] = newAmount
	
	-- Update UI
	if uiReferences.CurrencyDisplay then
		local currencyLabel = uiReferences.CurrencyDisplay:FindFirstChild(currencyType .. "Label")
		if currencyLabel then
			-- Animate the change
			self:AnimateNumberChange(currencyLabel, oldAmount, newAmount, currencyType)
		end
	end
	
	print("[UI] Currency updated: " .. currencyType .. " = " .. tostring(newAmount))
end

-- Animate number change
function UIController:AnimateNumberChange(label, oldValue, newValue, currencyType)
	local duration = 0.5
	local startTime = tick()
	
	-- Format function
	local function formatValue(value)
		local CurrencyConfig = require(ReplicatedStorage.Shared.Configs.CurrencyConfig)
		return CurrencyConfig:FormatAmount(value, currencyType)
	end
	
	-- Tween the value
	spawn(function()
		while tick() - startTime < duration do
			local progress = (tick() - startTime) / duration
			local currentValue = oldValue + (newValue - oldValue) * progress
			label.Text = formatValue(currentValue)
			wait()
		end
		label.Text = formatValue(newValue)
	end)
	
	-- Bounce animation
	local bounceTween = TweenService:Create(
		label,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(label.Size.X.Scale * 1.1, 0, label.Size.Y.Scale * 1.1, 0) }
	)
	bounceTween:Play()
	
	bounceTween.Completed:Connect(function()
		local returnTween = TweenService:Create(
			label,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(label.Size.X.Scale / 1.1, 0, label.Size.Y.Scale / 1.1, 0) }
		)
		returnTween:Play()
	end)
end

-- Egg opening progress handler
function UIController:OnEggOpeningProgress(eventType, data, duration)
	if eventType == "Start" then
		state.IsEggOpening = true
		self:ShowEggOpeningAnimation(data, duration)
	elseif eventType == "Stage" then
		self:UpdateEggOpeningStage(data)
	end
end

-- Show egg opening animation
function UIController:ShowEggOpeningAnimation(eggId, duration)
	if uiReferences.EggOpeningFrame then
		uiReferences.EggOpeningFrame.Visible = true
		
		-- Start animation sequence
		-- This will be customized based on UI assets
		print("[UI] Starting egg opening animation for: " .. eggId)
	end
end

-- Update egg opening stage
function UIController:UpdateEggOpeningStage(stageName)
	print("[UI] Egg opening stage: " .. stageName)
	
	-- Update visual based on stage
	if uiReferences.EggOpeningFrame then
		local stageIndicator = uiReferences.EggOpeningFrame:FindFirstChild("StageIndicator")
		if stageIndicator then
			stageIndicator.Text = stageName
		end
	end
end

-- Egg opened result handler
function UIController:OnEggOpened(success, result)
	state.IsEggOpening = false
	
	if success then
		-- Show pet reveal
		self:ShowPetReveal(result)
	else
		-- Show error
		self:ShowNotification("Egg opening failed: " .. tostring(result), Color3.fromRGB(255, 0, 0), "Error")
	end
	
	-- Hide egg opening frame
	if uiReferences.EggOpeningFrame then
		wait(3) -- Show result for 3 seconds
		uiReferences.EggOpeningFrame.Visible = false
	end
end

-- Show pet reveal animation
function UIController:ShowPetReveal(result)
	local petData = result.PetInstance
	local rarityInfo = result.RarityInfo
	
	print("[UI] Pet revealed: " .. petData.DisplayName .. " (" .. result.Rarity .. ")")
	
	-- Show notification based on rarity
	if result.Rarity == "Legendary" or result.Rarity == "Mythic" or result.Rarity == "Secret" then
		self:ShowNotification(
			"You hatched a " .. result.Rarity .. " " .. petData.DisplayName .. "!",
			rarityInfo.Color,
			"RareHatch"
		)
	end
	
	-- Play rarity-specific effects
	self:PlayRarityEffects(result.Rarity, rarityInfo)
end

-- Play rarity-specific visual effects
function UIController:PlayRarityEffects(rarity, rarityInfo)
	-- Screen flash for Epic+
	if rarityInfo.HasScreenFlash then
		self:FlashScreen(rarityInfo.Color)
	end
	
	-- Camera shake for Legendary+
	if rarityInfo.HasCameraShake then
		self:ShakeCamera(rarityInfo.CameraShakeIntensity or 0.3)
	end
end

-- Flash screen effect
function UIController:FlashScreen(color)
	local playerGui = player:WaitForChild("PlayerGui")
	local flash = Instance.new("Frame")
	flash.Name = "ScreenFlash"
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 0
	flash.ZIndex = 100
	flash.Parent = playerGui:FindFirstChildOfClass("ScreenGui") or playerGui
	
	-- Fade out
	local fadeTween = TweenService:Create(
		flash,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	fadeTween:Play()
	
	fadeTween.Completed:Connect(function()
		flash:Destroy()
	end)
end

-- Camera shake effect
function UIController:ShakeCamera(intensity)
	local camera = workspace.CurrentCamera
	local originalCFrame = camera.CFrame
	
	local shakeDuration = 0.5
	local startTime = tick()
	
	spawn(function()
		while tick() - startTime < shakeDuration do
			local offset = Vector3.new(
				(math.random() - 0.5) * intensity,
				(math.random() - 0.5) * intensity,
				0
			)
			camera.CFrame = originalCFrame * CFrame.new(offset)
			wait()
		end
		camera.CFrame = originalCFrame
	end)
end

-- Inventory update handler
function UIController:OnInventoryUpdated(inventory)
	state.CurrentInventory = inventory
	
	if uiReferences.InventoryFrame then
		-- Update inventory display
		print("[UI] Inventory updated: " .. tostring(inventory.UsedSlots) .. "/" .. tostring(inventory.MaxSlots + inventory.ExpandedSlots))
	end
end

-- Pet update handler
function UIController:OnPetUpdated(eventType, data)
	if eventType == "Equipped" then
		print("[UI] Pet equipped: " .. tostring(data))
	elseif eventType == "Unequipped" then
		print("[UI] Pet unequipped: " .. tostring(data))
	elseif eventType == "Fused" then
		self:ShowNotification("Pets fused successfully!", Color3.fromRGB(0, 255, 0), "Success")
	elseif eventType == "Sold" then
		self:ShowNotification("Pet sold for " .. tostring(data) .. " Clicks", Color3.fromRGB(255, 255, 0), "Info")
	elseif eventType == "FavoriteToggled" then
		print("[UI] Pet favorite toggled: " .. tostring(data))
	elseif eventType == "XPAdded" then
		print("[UI] Pet XP added")
	end
end

-- Leaderboard update handler
function UIController:OnLeaderboardUpdated(eventType, category, data)
	if eventType == "FullUpdate" or eventType == "Update" then
		state.CurrentLeaderboard = state.CurrentLeaderboard or {}
		state.CurrentLeaderboard[category] = data
		
		print("[UI] Leaderboard updated: " .. category)
	end
end

-- Trade update handler
function UIController:OnTradeUpdated(eventType, data)
	if eventType == "TradeRequest" then
		-- Show trade request dialog
		print("[UI] Trade request from: " .. data.RequesterName)
	elseif eventType == "TradeStarted" then
		print("[UI] Trade started")
	elseif eventType == "TradeUpdated" then
		print("[UI] Trade updated")
	elseif eventType == "TradeCompleted" then
		self:ShowNotification("Trade completed successfully!", Color3.fromRGB(0, 255, 0), "Success")
	elseif eventType == "TradeCancelled" then
		self:ShowNotification("Trade cancelled by " .. data.CancelledBy, Color3.fromRGB(255, 0, 0), "Info")
	elseif eventType == "TradeFailed" then
		self:ShowNotification("Trade failed: " .. data.Reason, Color3.fromRGB(255, 0, 0), "Error")
	end
end

-- Show notification
function UIController:ShowNotification(message, color, notificationType)
	color = color or Color3.fromRGB(255, 255, 255)
	
	print("[Notification] " .. message)
	
	if uiReferences.NotificationFrame then
		-- Create notification element
		local notification = Instance.new("Frame")
		notification.Name = "Notification"
		notification.Size = UDim2.new(0, 300, 0, 60)
		notification.Position = UDim2.new(1, 320, 0.8, 0)
		notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		notification.BorderSizePixel = 0
		notification.Parent = uiReferences.NotificationFrame
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = notification
		
		local textLabel = Instance.new("TextLabel")
		textLabel.Name = "Message"
		textLabel.Size = UDim2.new(1, -20, 1, -10)
		textLabel.Position = UDim2.new(0, 10, 0, 5)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = message
		textLabel.TextColor3 = color
		textLabel.TextScaled = true
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextWrapped = true
		textLabel.Parent = notification
		
		-- Slide in animation
		local slideIn = TweenService:Create(
			notification,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(1, -320, 0.8, 0) }
		)
		slideIn:Play()
		
		-- Auto remove after delay
		spawn(function()
			wait(4)
			
			local slideOut = TweenService:Create(
				notification,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.new(1, 320, 0.8, 0) }
			)
			slideOut:Play()
			
			slideOut.Completed:Wait()
			notification:Destroy()
		end)
	end
end

-- Show global announcement (for Secret pets)
function UIController:ShowGlobalAnnouncement(message, color)
	print("[Global Announcement] " .. message)
	
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create announcement frame
	local announcement = Instance.new("Frame")
	announcement.Name = "GlobalAnnouncement"
	announcement.Size = UDim2.new(1, 0, 0, 80)
	announcement.Position = UDim2.new(0, 0, -0.15, 0)
	announcement.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	announcement.BorderSizePixel = 0
	announcement.ZIndex = 200
	announcement.Parent = playerGui:FindFirstChildOfClass("ScreenGui") or playerGui
	
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color or Color3.fromRGB(255, 0, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 50, 50)),
		ColorSequenceKeypoint.new(1, color or Color3.fromRGB(255, 0, 0)),
	})
	gradient.Parent = announcement
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Message"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = message
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextSize = 24
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.Parent = announcement
	
	-- Drop in animation
	local dropIn = TweenService:Create(
		announcement,
		TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, 0, 0, 0) }
	)
	dropIn:Play()
	
	-- Stay visible then slide out
	spawn(function()
		wait(5)
		
		local slideOut = TweenService:Create(
			announcement,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0, 0, -0.15, 0) }
		)
		slideOut:Play()
		
		slideOut.Completed:Wait()
		announcement:Destroy()
	end)
end

-- Public API for UI interaction
function UIController:OpenEgg(eggId)
	if state.IsEggOpening then
		return false, "Already opening an egg"
	end
	
	remotes.RequestOpenEgg:FireServer(eggId)
	return true
end

function UIController:EquipPet(petInstanceId)
	remotes.EquipPet:FireServer(petInstanceId)
end

function UIController:UnequipPet(petInstanceId)
	remotes.UnequipPet:FireServer(petInstanceId)
end

function UIController:SellPet(petInstanceId)
	remotes.SellPet:FireServer(petInstanceId)
end

function UIController:FusePets(petInstanceIds)
	remotes.FusePets:FireServer(petInstanceIds)
end

function UIController:ToggleFavorite(petInstanceId)
	remotes.ToggleFavorite:FireServer(petInstanceId)
end

function UIController:SortInventory(sortType)
	remotes.SortInventory:FireServer(sortType)
end

function UIController:FilterInventory(filterType, filterValue)
	remotes.FilterInventory:FireServer(filterType, filterValue)
end

function UIController:SearchInventory(searchTerm)
	remotes.SearchInventory:FireServer(searchTerm)
end

function UIController:RequestTrade(targetPlayer)
	remotes.RequestTrade:FireServer(targetPlayer)
end

function UIController:RequestRebirth()
	remotes.RequestRebirth:FireServer()
end

-- Initialize on module load
UIController:Initialize()

return UIController
