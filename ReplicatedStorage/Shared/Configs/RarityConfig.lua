--[[
	RarityConfig.lua
	Configuration for all rarity tiers in the egg opening system
	Contains drop chances, multipliers, colors, and visual effects
--]]

local RarityConfig = {
	-- Rarity tier definitions
	Tiers = {
		Common = {
			Id = "Common",
			DisplayName = "Common",
			Color = Color3.fromRGB(169, 169, 169), -- Gray
			GlowColor = Color3.fromRGB(200, 200, 200),
			BaseChance = 50, -- 50%
			LuckMultiplier = 1,
			GlowIntensity = 0.2,
			ParticleCount = 5,
			SoundId = "rbxassetid://COMMON_SOUND",
			HasScreenFlash = false,
			HasCameraShake = false,
			ServerNotification = false,
			GlobalAnnouncement = false,
		},
		Uncommon = {
			Id = "Uncommon",
			DisplayName = "Uncommon",
			Color = Color3.fromRGB(50, 205, 50), -- Green
			GlowColor = Color3.fromRGB(100, 255, 100),
			BaseChance = 30, -- 30%
			LuckMultiplier = 2,
			GlowIntensity = 0.4,
			ParticleCount = 10,
			SoundId = "rbxassetid://UNCOMMON_SOUND",
			HasScreenFlash = false,
			HasCameraShake = false,
			ServerNotification = false,
			GlobalAnnouncement = false,
		},
		Rare = {
			Id = "Rare",
			DisplayName = "Rare",
			Color = Color3.fromRGB(30, 144, 255), -- Blue
			GlowColor = Color3.fromRGB(100, 180, 255),
			BaseChance = 15, -- 15%
			LuckMultiplier = 5,
			GlowIntensity = 0.6,
			ParticleCount = 20,
			SoundId = "rbxassetid://RARE_SOUND",
			HasScreenFlash = false,
			HasCameraShake = false,
			ServerNotification = false,
			GlobalAnnouncement = false,
		},
		Epic = {
			Id = "Epic",
			DisplayName = "Epic",
			Color = Color3.fromRGB(148, 0, 211), -- Purple
			GlowColor = Color3.fromRGB(200, 100, 255),
			BaseChance = 4, -- 4%
			LuckMultiplier = 15,
			GlowIntensity = 0.8,
			ParticleCount = 35,
			SoundId = "rbxassetid://EPIC_SOUND",
			HasScreenFlash = true,
			HasCameraShake = false,
			ServerNotification = false,
			GlobalAnnouncement = false,
		},
		Legendary = {
			Id = "Legendary",
			DisplayName = "Legendary",
			Color = Color3.fromRGB(255, 215, 0), -- Gold
			GlowColor = Color3.fromRGB(255, 255, 150),
			BaseChance = 0.9, -- 0.9%
			LuckMultiplier = 50,
			GlowIntensity = 1.0,
			ParticleCount = 60,
			SoundId = "rbxassetid://LEGENDARY_SOUND",
			HasScreenFlash = true,
			HasCameraShake = true,
			CameraShakeIntensity = 0.3,
			ServerNotification = false,
			GlobalAnnouncement = false,
		},
		Mythic = {
			Id = "Mythic",
			DisplayName = "Mythic",
			Color = Color3.fromRGB(255, 0, 255), -- Magenta
			GlowColor = Color3.fromRGB(255, 150, 255),
			BaseChance = 0.09, -- 0.09%
			LuckMultiplier = 200,
			GlowIntensity = 1.2,
			ParticleCount = 100,
			SoundId = "rbxassetid://MYTHIC_SOUND",
			HasScreenFlash = true,
			HasCameraShake = true,
			CameraShakeIntensity = 0.5,
			ServerNotification = true,
			GlobalAnnouncement = false,
			AuraParticles = true,
		},
		Secret = {
			Id = "Secret",
			DisplayName = "Secret",
			Color = Color3.fromRGB(255, 0, 0), -- Red
			GlowColor = Color3.fromRGB(255, 100, 100),
			BaseChance = 0.01, -- 0.01%
			LuckMultiplier = 1000,
			GlowIntensity = 1.5,
			ParticleCount = 200,
			SoundId = "rbxassetid://SECRET_SOUND",
			HasScreenFlash = true,
			HasCameraShake = true,
			CameraShakeIntensity = 0.8,
			ServerNotification = true,
			GlobalAnnouncement = true,
			AuraParticles = true,
			RainbowEffects = true,
		},
	},

	-- Order of rarities for display/sorting
	RarityOrder = {
		"Common",
		"Uncommon", 
		"Rare",
		"Epic",
		"Legendary",
		"Mythic",
		"Secret",
	},

	-- Pity system configuration
	PitySystem = {
		Enabled = true,
		GuaranteedLegendaryAfter = 100, -- Guaranteed Legendary after 100 opens without one
		GuaranteedMythicAfter = 500,   -- Guaranteed Mythic after 500 opens without one
		GuaranteedSecretAfter = 2000,  -- Guaranteed Secret after 2000 opens without one
	},

	-- Luck boost configuration
	LuckBoosts = {
		Basic = {
			Name = "Basic Luck",
			Multiplier = 2,
			Duration = 300, -- 5 minutes
		},
		Super = {
			Name = "Super Luck",
			Multiplier = 5,
			Duration = 600, -- 10 minutes
		},
		Ultra = {
			Name = "Ultra Luck",
			Multiplier = 10,
			Duration = 900, -- 15 minutes
		},
	},
}

-- Helper function to get rarity by ID
function RarityConfig:GetRarity(rarityId)
	return self.Tiers[rarityId]
end

-- Helper function to get rarity color
function RarityConfig:GetRarityColor(rarityId)
	local rarity = self.Tiers[rarityId]
	return rarity and rarity.Color or Color3.fromRGB(255, 255, 255)
end

-- Helper function to get rarity display name
function RarityConfig:GetRarityDisplayName(rarityId)
	local rarity = self.Tiers[rarityId]
	return rarity and rarity.DisplayName or rarityId
end

-- Calculate total weight for weighted random selection
function RarityConfig:CalculateTotalWeight(petPool, luckMultiplier)
	luckMultiplier = luckMultiplier or 1
	local totalWeight = 0
	
	for _, pet in ipairs(petPool) do
		local rarity = self.Tiers[pet.Rarity]
		if rarity then
			-- Apply luck multiplier to rarity weight
			local adjustedWeight = rarity.BaseChance * luckMultiplier
			totalWeight = totalWeight + adjustedWeight
		end
	end
	
	return totalWeight
end

return RarityConfig
