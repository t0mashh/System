--[[
	EggOpeningController.lua
	Client-side controller for egg opening animations and effects
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage.Shared.Remotes

-- Import configurations
local RarityConfig = require(ReplicatedStorage.Shared.Configs.RarityConfig)
local EggConfig = require(ReplicatedStorage.Shared.Configs.EggConfig)

-- EggOpeningController module
local EggOpeningController = {}
EggOpeningController.__index = EggOpeningController

-- State
local isOpening = false
local currentEggModel = nil
local animationConnection = nil

-- Initialize EggOpeningController
function EggOpeningController:Initialize()
	self:SetupRemoteListeners()
	print("[EggOpeningController] Initialized")
end

-- Setup remote listeners
function EggOpeningController:SetupRemoteListeners()
	remotes.EggOpeningProgress.OnClientEvent:Connect(function(eventType, data, duration)
		self:HandleProgressEvent(eventType, data, duration)
	end)
	
	remotes.EggOpened.OnClientEvent:Connect(function(success, result)
		if success then
			self:ShowPetReveal(result)
		end
	end)
end

-- Handle progress events from server
function EggOpeningController:HandleProgressEvent(eventType, data, duration)
	if eventType == "Start" then
		self:StartOpeningSequence(data, duration)
	elseif eventType == "Stage" then
		self:UpdateStage(data)
	end
end

-- Start the opening sequence
function EggOpeningController:StartOpeningSequence(eggId, duration)
	if isOpening then return end
	
	isOpening = true
	
	local eggConfig = EggConfig:GetEgg(eggId)
	if not eggConfig then
		isOpening = false
		return
	end
	
	-- Create egg model
	self:CreateEggModel(eggConfig)
	
	-- Start animation loop
	self:StartAnimationLoop(duration)
	
	print("[EggOpening] Started opening sequence for: " .. eggId)
end

-- Create the egg model
function EggOpeningController:CreateEggModel(eggConfig)
	-- Remove existing model
	if currentEggModel then
		currentEggModel:Destroy()
	end
	
	-- Create new egg model
	local egg = Instance.new("Model")
	egg.Name = "OpeningEgg"
	
	-- Main egg part
	local mainPart = Instance.new("Part")
	mainPart.Name = "EggMain"
	mainPart.Size = Vector3.new(4, 5, 4)
	mainPart.Shape = Enum.PartType.Ball
	mainPart.Anchored = true
	mainPart.CanCollide = false
	mainPart.Material = Enum.Material.SmoothPlastic
	mainPart.Color = Color3.fromRGB(200, 200, 200)
	mainPart.Parent = egg
	
	egg.PrimaryPart = mainPart
	
	-- Position in front of camera
	local camera = workspace.CurrentCamera
	local position = camera.CFrame.Position + (camera.CFrame.LookVector * 10)
	egg:SetPrimaryPartCFrame(CFrame.new(position))
	
	egg.Parent = workspace
	currentEggModel = egg
	
	return egg
end

-- Start the animation loop
function EggOpeningController:StartAnimationLoop(duration)
	local startTime = tick()
	local camera = workspace.CurrentCamera
	
	animationConnection = RunService.RenderStepped:Connect(function()
		if not currentEggModel or not isOpening then
			if animationConnection then
				animationConnection:Disconnect()
			end
			return
		end
		
		local elapsed = tick() - startTime
		local progress = elapsed / duration
		
		if progress >= 1 then
			if animationConnection then
				animationConnection:Disconnect()
			end
			return
		end
		
		-- Keep egg in front of camera
		local targetPosition = camera.CFrame.Position + (camera.CFrame.LookVector * 10)
		local currentPosition = currentEggModel.PrimaryPart.Position
		local newPosition = currentPosition:Lerp(targetPosition, 0.1)
		
		currentEggModel:SetPrimaryPartCFrame(CFrame.new(newPosition))
	end)
end

-- Update animation stage
function EggOpeningController:UpdateStage(stageName)
	if not currentEggModel then return end
	
	local mainPart = currentEggModel.PrimaryPart
	
	if stageName == "Pulse" then
		-- Gentle pulsing glow
		self:CreateGlowEffect(mainPart, Color3.fromRGB(255, 255, 200), 0.5)
		
	elseif stageName == "Shake" then
		-- Intense shaking
		self:StartShakeAnimation(mainPart, 0.2)
		
	elseif stageName == "Crack" then
		-- Show cracks
		self:CreateCrackEffects(mainPart)
		
	elseif stageName == "Glow" then
		-- Light emission from cracks
		self:IntensifyGlow(mainPart, Color3.fromRGB(255, 255, 255), 1.0)
		
	elseif stageName == "Explode" then
		-- Particle explosion
		self:CreateExplosionEffect(mainPart.Position)
		
		-- Hide egg
		if currentEggModel then
			currentEggModel:Destroy()
			currentEggModel = nil
		end
	end
	
	print("[EggOpening] Stage: " .. stageName)
end

-- Create glow effect
function EggOpeningController:CreateGlowEffect(part, color, intensity)
	local glow = Instance.new("PointLight")
	glow.Name = "EggGlow"
	glow.Color = color
	glow.Brightness = intensity
	glow.Range = 10
	glow.Parent = part
	
	-- Pulsing animation
	spawn(function()
		while glow and glow.Parent do
			local tween = TweenService:Create(
				glow,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Brightness = intensity * 1.5 }
			)
			tween:Play()
			tween.Completed:Wait()
			
			if not glow or not glow.Parent then break end
			
			tween = TweenService:Create(
				glow,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Brightness = intensity }
			)
			tween:Play()
			tween.Completed:Wait()
		end
	end)
end

-- Start shake animation
function EggOpeningController:StartShakeAnimation(part, intensity)
	local originalCFrame = part.CFrame
	
	spawn(function()
		while part and part.Parent and isOpening do
			local offset = Vector3.new(
				(math.random() - 0.5) * intensity,
				(math.random() - 0.5) * intensity,
				(math.random() - 0.5) * intensity
			)
			part.CFrame = originalCFrame * CFrame.new(offset)
			wait(0.05)
		end
		
		-- Reset position
		if part and part.Parent then
			part.CFrame = originalCFrame
		end
	end)
end

-- Create crack effects
function EggOpeningController:CreateCrackEffects(part)
	-- Create crack decals
	for i = 1, 3 do
		local crack = Instance.new("Decal")
		crack.Name = "Crack" .. i
		crack.Texture = "rbxassetid://CRACK_TEXTURE" -- Replace with actual crack texture
		crack.Face = Enum.NormalId[{"Front", "Back", "Left", "Right", "Top", "Bottom"}[math.random(1, 6)]]
		crack.Parent = part
		
		-- Fade in
		crack.Transparency = 1
		local fadeTween = TweenService:Create(
			crack,
			TweenInfo.new(0.3),
			{ Transparency = 0 }
		)
		fadeTween:Play()
	end
end

-- Intensify glow
function EggOpeningController:IntensifyGlow(part, color, intensity)
	local glow = part:FindFirstChild("EggGlow")
	if glow then
		local tween = TweenService:Create(
			glow,
			TweenInfo.new(0.5),
			{ 
				Color = color,
				Brightness = intensity,
				Range = 20
			}
		)
		tween:Play()
	end
end

-- Create explosion effect
function EggOpeningController:CreateExplosionEffect(position)
	-- Particle burst
	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	particleEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	particleEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	particleEmitter.Lifetime = NumberRange.new(1, 2)
	particleEmitter.Rate = 0
	particleEmitter.Speed = NumberRange.new(10, 20)
	particleEmitter.SpreadAngle = Vector2.new(180, 180)
	particleEmitter.Acceleration = Vector3.new(0, -20, 0)
	particleEmitter.Drag = 2
	
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	particleEmitter.Parent = attachment
	
	-- Emit particles
	particleEmitter:Emit(50)
	
	-- Clean up
	Debris:AddItem(attachment, 3)
	
	-- Screen flash
	self:FlashScreen()
end

-- Flash screen
function EggOpeningController:FlashScreen()
	local playerGui = player:WaitForChild("PlayerGui")
	
	local flash = Instance.new("Frame")
	flash.Name = "ExplosionFlash"
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 0
	flash.ZIndex = 100
	flash.Parent = playerGui:FindFirstChildOfClass("ScreenGui") or playerGui
	
	local fadeTween = TweenService:Create(
		flash,
		TweenInfo.new(0.5),
		{ BackgroundTransparency = 1 }
	)
	fadeTween:Play()
	
	fadeTween.Completed:Connect(function()
		flash:Destroy()
	end)
end

-- Show pet reveal
function EggOpeningController:ShowPetReveal(result)
	local petData = result.PetInstance
	local rarityInfo = result.RarityInfo
	
	-- Create pet model
	local petModel = self:CreatePetModel(petData, rarityInfo)
	
	-- Animate pet emergence
	self:AnimatePetEmergence(petModel, rarityInfo)
	
	-- Play rarity effects
	self:PlayRarityEffects(result.Rarity, rarityInfo)
	
	isOpening = false
end

-- Create pet model
function EggOpeningController:CreatePetModel(petData, rarityInfo)
	local pet = Instance.new("Part")
	pet.Name = "RevealedPet"
	pet.Size = Vector3.new(3, 3, 3)
	pet.Shape = Enum.PartType.Ball
	pet.Anchored = true
	pet.CanCollide = false
	pet.Material = Enum.Material.Neon
	pet.Color = rarityInfo.Color
	
	-- Add glow
	local glow = Instance.new("PointLight")
	glow.Color = rarityInfo.GlowColor
	glow.Brightness = rarityInfo.GlowIntensity
	glow.Range = 15
	glow.Parent = pet
	
	-- Position in front of camera
	local camera = workspace.CurrentCamera
	local position = camera.CFrame.Position + (camera.CFrame.LookVector * 10) + Vector3.new(0, 5, 0)
	pet.CFrame = CFrame.new(position)
	pet.Parent = workspace
	
	return pet
end

-- Animate pet emergence
function EggOpeningController:AnimatePetEmergence(petModel, rarityInfo)
	local startPosition = petModel.Position
	local endPosition = startPosition + Vector3.new(0, 3, 0)
	
	-- Float up
	local floatTween = TweenService:Create(
		petModel,
		TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = endPosition }
	)
	floatTween:Play()
	
	-- Spin
	spawn(function()
		while petModel and petModel.Parent do
			petModel.CFrame = petModel.CFrame * CFrame.Angles(0, math.rad(2), 0)
			wait()
		end
	end)
	
	-- Fade out after delay
	spawn(function()
		wait(3)
		
		if petModel and petModel.Parent then
			local fadeTween = TweenService:Create(
				petModel,
				TweenInfo.new(1),
				{ Transparency = 1 }
			)
			fadeTween:Play()
			fadeTween.Completed:Wait()
			
			if petModel then
				petModel:Destroy()
			end
		end
	end)
end

-- Play rarity-specific effects
function EggOpeningController:PlayRarityEffects(rarity, rarityInfo)
	-- Screen flash for Epic+
	if rarityInfo.HasScreenFlash then
		self:RarityFlashScreen(rarityInfo.Color)
	end
	
	-- Camera shake for Legendary+
	if rarityInfo.HasCameraShake then
		self:ShakeCamera(rarityInfo.CameraShakeIntensity or 0.3)
	end
	
	-- Particles for high rarities
	if rarityInfo.ParticleCount and rarityInfo.ParticleCount > 20 then
		self:CreateRarityParticles(rarityInfo)
	end
end

-- Rarity flash screen
function EggOpeningController:RarityFlashScreen(color)
	local playerGui = player:WaitForChild("PlayerGui")
	
	local flash = Instance.new("Frame")
	flash.Name = "RarityFlash"
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 0.5
	flash.ZIndex = 100
	flash.Parent = playerGui:FindFirstChildOfClass("ScreenGui") or playerGui
	
	local fadeTween = TweenService:Create(
		flash,
		TweenInfo.new(1),
		{ BackgroundTransparency = 1 }
	)
	fadeTween:Play()
	
	fadeTween.Completed:Connect(function()
		flash:Destroy()
	end)
end

-- Shake camera
function EggOpeningController:ShakeCamera(intensity)
	local camera = workspace.CurrentCamera
	local originalCFrame = camera.CFrame
	
	spawn(function()
		local startTime = tick()
		while tick() - startTime < 0.5 do
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

-- Create rarity particles
function EggOpeningController:CreateRarityParticles(rarityInfo)
	local camera = workspace.CurrentCamera
	local position = camera.CFrame.Position + (camera.CFrame.LookVector * 10)
	
	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Color = ColorSequence.new(rarityInfo.Color)
	particleEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	particleEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	particleEmitter.Lifetime = NumberRange.new(2, 4)
	particleEmitter.Rate = rarityInfo.ParticleCount / 10
	particleEmitter.Speed = NumberRange.new(5, 10)
	particleEmitter.SpreadAngle = Vector2.new(180, 180)
	particleEmitter.Acceleration = Vector3.new(0, -10, 0)
	
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	particleEmitter.Parent = attachment
	
	-- Stop emitting after a few seconds
	spawn(function()
		wait(3)
		if particleEmitter then
			particleEmitter.Enabled = false
		end
		wait(5)
		if attachment then
			attachment:Destroy()
		end
	end)
end

-- Initialize on module load
EggOpeningController:Initialize()

return EggOpeningController
