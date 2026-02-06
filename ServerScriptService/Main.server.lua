--[[
	Main.server.lua
	Main server initialization script for the Egg Opening System
	Loads and initializes all services
--]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("=" .. string.rep("=", 50))
print("  EGG OPENING SYSTEM - SERVER INITIALIZATION")
print("=" .. string.rep("=", 50))
print("")

-- Ensure ReplicatedStorage structure exists
local function setupReplicatedStorage()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if not shared then
		shared = Instance.new("Folder")
		shared.Name = "Shared"
		shared.Parent = ReplicatedStorage
	end
	
	local configs = shared:FindFirstChild("Configs")
	if not configs then
		configs = Instance.new("Folder")
		configs.Name = "Configs"
		configs.Parent = shared
	end
	
	local modules = shared:FindFirstChild("Modules")
	if not modules then
		modules = Instance.new("Folder")
		modules.Name = "Modules"
		modules.Parent = shared
	end
	
	local remotes = shared:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = shared
	end
	
	print("[Main] ReplicatedStorage structure verified")
end

-- Load and initialize all services
local function initializeServices()
	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	if not servicesFolder then
		warn("[Main] Services folder not found!")
		return
	end
	
	local services = {}
	local serviceOrder = {
		"DataService",
		"CurrencyService",
		"AntiCheatService",
		"PetService",
		"InventoryService",
		"EggService",
		"TradeService",
		"LeaderboardService",
	}
	
	print("[Main] Loading services...")
	print("")
	
	for _, serviceName in ipairs(serviceOrder) do
		local serviceModule = servicesFolder:FindFirstChild(serviceName)
		if serviceModule then
			local success, service = pcall(function()
				return require(serviceModule)
			end)
			
			if success then
				services[serviceName] = service
				print("  [OK] " .. serviceName)
			else
				warn("  [FAIL] " .. serviceName .. ": " .. tostring(service))
			end
		else
			warn("  [MISSING] " .. serviceName)
		end
	end
	
	print("")
	print("[Main] All services loaded successfully")
	
	return services
end

-- Setup notification remotes
local function setupNotificationRemotes()
	local remotes = ReplicatedStorage.Shared.Remotes
	
	-- Server notification (for Mythic+ pets)
	local serverNotification = Instance.new("RemoteEvent")
	serverNotification.Name = "ServerNotification"
	serverNotification.Parent = remotes
	
	-- Global announcement (for Secret pets)
	local globalAnnouncement = Instance.new("RemoteEvent")
	globalAnnouncement.Name = "GlobalAnnouncement"
	globalAnnouncement.Parent = remotes
	
	print("[Main] Notification remotes created")
end

-- Player join handler
local function onPlayerJoined(player)
	print("[Main] Player joined: " .. player.Name .. " (" .. player.UserId .. ")")
	
	-- Wait for data to load
	local dataService = require(ServerScriptService.Services.DataService)
	local data = dataService:GetPlayerData(player)
	
	if data then
		print("[Main] Data loaded for: " .. player.Name)
		
		-- Setup passive income
		local currencyService = require(ServerScriptService.Services.CurrencyService)
		currencyService:SetupPassiveIncome(player)
	else
		warn("[Main] Failed to load data for: " .. player.Name)
	end
end

-- Player leave handler
local function onPlayerLeft(player)
	print("[Main] Player left: " .. player.Name)
end

-- Main initialization
local function main()
	print("")
	print("Initializing Egg Opening System...")
	print("")
	
	-- Setup structure
	setupReplicatedStorage()
	
	-- Initialize services
	local services = initializeServices()
	
	-- Setup notification remotes
	setupNotificationRemotes()
	
	-- Connect player events
	Players.PlayerAdded:Connect(onPlayerJoined)
	Players.PlayerRemoving:Connect(onPlayerLeft)
	
	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerJoined(player)
	end
	
	print("")
	print("=" .. string.rep("=", 50))
	print("  SYSTEM READY")
	print("=" .. string.rep("=", 50))
	print("")
end

-- Run main initialization
main()
