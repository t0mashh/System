--[[
	Main.client.lua
	Main client initialization script for the Egg Opening System
	Loads and initializes all client controllers
--]]

local Players = game:GetService("Players")
local StarterPlayerScripts = game:GetService("StarterPlayerScripts")

local player = Players.LocalPlayer

print("=" .. string.rep("=", 50))
print("  EGG OPENING SYSTEM - CLIENT INITIALIZATION")
print("=" .. string.rep("=", 50))
print("")

-- Load and initialize all controllers
local function initializeControllers()
	local clientFolder = StarterPlayerScripts:FindFirstChild("Client")
	if not clientFolder then
		warn("[Client Main] Client folder not found!")
		return
	end
	
	local controllersFolder = clientFolder:FindFirstChild("Controllers")
	if not controllersFolder then
		warn("[Client Main] Controllers folder not found!")
		return
	end
	
	local controllers = {}
	local controllerOrder = {
		"UIController",
		"EggOpeningController",
	}
	
	print("[Client Main] Loading controllers...")
	print("")
	
	for _, controllerName in ipairs(controllerOrder) do
		local controllerModule = controllersFolder:FindFirstChild(controllerName)
		if controllerModule then
			local success, controller = pcall(function()
				return require(controllerModule)
			end)
			
			if success then
				controllers[controllerName] = controller
				print("  [OK] " .. controllerName)
			else
				warn("  [FAIL] " .. controllerName .. ": " .. tostring(controller))
			end
		else
			warn("  [MISSING] " .. controllerName)
		end
	end
	
	print("")
	print("[Client Main] All controllers loaded successfully")
	
	return controllers
end

-- Setup click handler
local function setupClickHandler()
	local UserInputService = game:GetService("UserInputService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remotes = ReplicatedStorage.Shared.Remotes
	
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		-- Check for click (mouse or touch)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		   input.UserInputType == Enum.UserInputType.Touch then
			
			-- Send click to server
			remotes.Click:FireServer()
		end
	end)
	
	print("[Client Main] Click handler initialized")
end

-- Main initialization
local function main()
	print("")
	print("Initializing Egg Opening System Client...")
	print("")
	
	-- Wait for player to be ready
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	
	-- Initialize controllers
	local controllers = initializeControllers()
	
	-- Setup click handler
	setupClickHandler()
	
	print("")
	print("=" .. string.rep("=", 50))
	print("  CLIENT READY")
	print("=" .. string.rep("=", 50))
	print("")
	
	-- Store controllers globally for debugging
	_G.EggSystemControllers = controllers
end

-- Run main initialization
main()
