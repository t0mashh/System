--[[
	PetConfig.lua
	Configuration for all pet types and their stats
--]]

local PetConfig = {
	-- Pet type definitions
	Pets = {
		-- Common Pets
		Dog = {
			Id = "Dog",
			DisplayName = "Dog",
			Description = "A loyal companion.",
			Rarity = "Common",
			ModelName = "DogModel",
			BaseStats = {
				ClicksMultiplier = 1.1,
				GemsMultiplier = 1.0,
			},
			MaxLevel = 100,
			LevelUpBonus = {
				ClicksMultiplier = 0.01,
				GemsMultiplier = 0.005,
			},
			FusionMultiplier = 1.5,
			Tradeable = true,
		},
		Cat = {
			Id = "Cat",
			DisplayName = "Cat",
			Description = "A curious feline friend.",
			Rarity = "Common",
			ModelName = "CatModel",
			BaseStats = {
				ClicksMultiplier = 1.1,
				GemsMultiplier = 1.0,
			},
			MaxLevel = 100,
			LevelUpBonus = {
				ClicksMultiplier = 0.01,
				GemsMultiplier = 0.005,
			},
			FusionMultiplier = 1.5,
			Tradeable = true,
		},
		-- Uncommon Pets
		Bunny = {
			Id = "Bunny",
			DisplayName = "Bunny",
			Description = "A cute hopping friend.",
			Rarity = "Uncommon",
			ModelName = "BunnyModel",
			BaseStats = {
				ClicksMultiplier = 1.25,
				GemsMultiplier = 1.1,
			},
			MaxLevel = 100,
			LevelUpBonus = {
				ClicksMultiplier = 0.015,
				GemsMultiplier = 0.008,
			},
			FusionMultiplier = 1.6,
			Tradeable = true,
		},
		Fox = {
			Id = "Fox",
			DisplayName = "Fox",
			Description = "A clever forest dweller.",
			Rarity = "Uncommon",
			ModelName = "FoxModel",
			BaseStats = {
				ClicksMultiplier = 1.3,
				GemsMultiplier = 1.1,
			},
			MaxLevel = 100,
			LevelUpBonus = {
				ClicksMultiplier = 0.015,
				GemsMultiplier = 0.008,
			},
			FusionMultiplier = 1.6,
			Tradeable = true,
		},
		-- Rare Pets
		Wolf = {
			Id = "Wolf",
			DisplayName = "Wolf",
			Description = "A fierce pack hunter.",
			Rarity = "Rare",
			ModelName = "WolfModel",
			BaseStats = {
				ClicksMultiplier = 1.5,
				GemsMultiplier = 1.2,
			},
			MaxLevel = 100,
			LevelUpBonus = {
				ClicksMultiplier = 0.02,
				GemsMultiplier = 0.01,
			},
			FusionMultiplier = 1.7,
			Tradeable = true,
		},
		Bear = {
			Id = "Bear",
			DisplayName = "Bear",
			Description = "A powerful forest guardian.",
			Rarity = "Rare",
			ModelName = "BearModel",
			BaseStats = {
				ClicksMultiplier = 1.6,
				GemsMultiplier = 1.25,
			},
			MaxLevel = 100,
			LevelUpBonus = {
				ClicksMultiplier = 0.02,
				GemsMultiplier = 0.012,
			},
			FusionMultiplier = 1.7,
			Tradeable = true,
		},
		-- Epic Pets
		Lion = {
			Id = "Lion",
			DisplayName = "Lion",
			Description = "The king of beasts.",
			Rarity = "Epic",
			ModelName = "LionModel",
			BaseStats = {
				ClicksMultiplier = 2.0,
				GemsMultiplier = 1.5,
			},
			MaxLevel = 100,
			LevelUpBonus = {
				ClicksMultiplier = 0.03,
				GemsMultiplier = 0.02,
			},
			FusionMultiplier = 1.8,
			Tradeable = true,
		},
		-- Legendary Pets
		Dragon = {
			Id = "Dragon",
			DisplayName = "Dragon",
			Description = "An ancient and powerful creature.",
			Rarity = "Legendary",
			ModelName = "DragonModel",
			BaseStats = {
				ClicksMultiplier = 3.0,
				GemsMultiplier = 2.0,
			},
			MaxLevel = 100,
			LevelUpBonus = {
				ClicksMultiplier = 0.05,
				GemsMultiplier = 0.03,
			},
			FusionMultiplier = 2.0,
			Tradeable = true,
			PassiveAbility = {
				Name = "Dragon's Might",
				Description = "10% chance to double click value",
				Chance = 0.1,
			},
		},
		-- Mythic Pets
		Phoenix = {
			Id = "Phoenix",
			DisplayName = "Phoenix",
			Description = "A mythical bird of fire and rebirth.",
			Rarity = "Mythic",
			ModelName = "PhoenixModel",
			BaseStats = {
				ClicksMultiplier = 5.0,
				GemsMultiplier = 3.5,
			},
			MaxLevel = 100,
			LevelUpBonus = {
				ClicksMultiplier = 0.08,
				GemsMultiplier = 0.05,
			},
			FusionMultiplier = 2.5,
			Tradeable = true,
			PassiveAbility = {
				Name = "Rebirth Flames",
				Description = "25% chance to triple click value",
				Chance = 0.25,
			},
			ActiveAbility = {
				Name = "Inferno",
				Description = "Instantly gain 100x clicks (Cooldown: 5 minutes)",
				Cooldown = 300,
			},
		},
		-- Secret Pets
		Unicorn = {
			Id = "Unicorn",
			DisplayName = "Unicorn",
			Description = "A legendary creature of pure magic.",
			Rarity = "Secret",
			ModelName = "UnicornModel",
			BaseStats = {
				ClicksMultiplier = 10.0,
				GemsMultiplier = 7.0,
			},
			MaxLevel = 100,
			LevelUpBonus = {
				ClicksMultiplier = 0.15,
				GemsMultiplier = 0.1,
			},
			FusionMultiplier = 3.0,
			Tradeable = true,
			PassiveAbility = {
				Name = "Rainbow Blessing",
				Description = "50% chance to 5x click value",
				Chance = 0.5,
			},
			ActiveAbility = {
				Name = "Prismatic Surge",
				Description = "Instantly gain 1000x clicks (Cooldown: 10 minutes)",
				Cooldown = 600,
			},
		},
	},

	-- Equipment settings
	EquipmentSettings = {
		MaxEquippedPets = 4,
		OrbitRadius = 5,
		OrbitSpeed = 1,
		OrbitHeight = 2,
		PetsFacePlayer = true,
	},

	-- Fusion settings
	FusionSettings = {
		RequiredDuplicates = 3, -- Need 3 of same pet to fuse
		SuccessRate = 1.0, -- 100% success for basic fusion
		StatMultiplier = 1.5, -- Fused pet gets 1.5x stats
		MaxFusionLevel = 5, -- Max fusion tier (Gold, Diamond, etc.)
	},

	-- Leveling settings
	LevelingSettings = {
		XPPerClick = 1,
		XPFormula = "Base * (Level ^ 1.5)",
		MaxLevel = 100,
	},
}

-- Helper function to get pet by ID
function PetConfig:GetPet(petId)
	return self.Pets[petId]
end

-- Helper function to get pet stats at specific level
function PetConfig:GetPetStatsAtLevel(petId, level)
	local pet = self.Pets[petId]
	if not pet then return nil end
	
	level = math.min(level, pet.MaxLevel)
	local levelBonus = level - 1
	
	return {
		ClicksMultiplier = pet.BaseStats.ClicksMultiplier + (pet.LevelUpBonus.ClicksMultiplier * levelBonus),
		GemsMultiplier = pet.BaseStats.GemsMultiplier + (pet.LevelUpBonus.GemsMultiplier * levelBonus),
	}
end

-- Helper function to get pets by rarity
function PetConfig:GetPetsByRarity(rarity)
	local pets = {}
	for petId, petData in pairs(self.Pets) do
		if petData.Rarity == rarity then
			table.insert(pets, petData)
		end
	end
	return pets
end

-- Calculate XP required for next level
function PetConfig:GetXPForLevel(currentLevel)
	if currentLevel >= self.LevelingSettings.MaxLevel then
		return nil
	end
	return math.floor(100 * (currentLevel ^ 1.5))
end

return PetConfig
