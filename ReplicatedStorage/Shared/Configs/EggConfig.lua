--[[
	EggConfig.lua
	Configuration for all egg types and their associated pet pools
--]]

local EggConfig = {
	-- Egg type definitions
	Eggs = {
		BasicEgg = {
			Id = "BasicEgg",
			DisplayName = "Basic Egg",
			Description = "A simple egg containing common pets.",
			Cost = {
				Currency = "Clicks",
				Amount = 100,
			},
			AnimationDuration = 2, -- seconds
			ModelName = "BasicEggModel",
			CrackStages = 3,
			PetPool = {
				{ PetId = "Dog", Rarity = "Common", Weight = 50 },
				{ PetId = "Cat", Rarity = "Common", Weight = 50 },
				{ PetId = "Bunny", Rarity = "Uncommon", Weight = 30 },
				{ PetId = "Fox", Rarity = "Uncommon", Weight = 30 },
				{ PetId = "Wolf", Rarity = "Rare", Weight = 15 },
				{ PetId = "Bear", Rarity = "Rare", Weight = 15 },
				{ PetId = "Lion", Rarity = "Epic", Weight = 4 },
				{ PetId = "Dragon", Rarity = "Legendary", Weight = 0.9 },
				{ PetId = "Phoenix", Rarity = "Mythic", Weight = 0.09 },
				{ PetId = "Unicorn", Rarity = "Secret", Weight = 0.01 },
			},
			AvailableIn = {
				StarterArea = true,
			},
		},
		WoodEgg = {
			Id = "WoodEgg",
			DisplayName = "Wood Egg",
			Description = "An egg made of wood, containing forest creatures.",
			Cost = {
				Currency = "Clicks",
				Amount = 500,
			},
			AnimationDuration = 2.5,
			ModelName = "WoodEggModel",
			CrackStages = 3,
			PetPool = {
				{ PetId = "Squirrel", Rarity = "Common", Weight = 50 },
				{ PetId = "Rabbit", Rarity = "Common", Weight = 50 },
				{ PetId = "Deer", Rarity = "Uncommon", Weight = 30 },
				{ PetId = "Owl", Rarity = "Uncommon", Weight = 30 },
				{ PetId = "Raccoon", Rarity = "Rare", Weight = 15 },
				{ PetId = "Hedgehog", Rarity = "Rare", Weight = 15 },
				{ PetId = "Wolf", Rarity = "Epic", Weight = 4 },
				{ PetId = "Moose", Rarity = "Legendary", Weight = 0.9 },
				{ PetId = "Ent", Rarity = "Mythic", Weight = 0.09 },
				{ PetId = "ForestSpirit", Rarity = "Secret", Weight = 0.01 },
			},
			AvailableIn = {
				ForestArea = true,
			},
		},
		FireEgg = {
			Id = "FireEgg",
			DisplayName = "Fire Egg",
			Description = "A burning egg containing fire elementals.",
			Cost = {
				Currency = "Clicks",
				Amount = 2000,
			},
			AnimationDuration = 3,
			ModelName = "FireEggModel",
			CrackStages = 4,
			PetPool = {
				{ PetId = "FireLizard", Rarity = "Common", Weight = 50 },
				{ PetId = "FlamePup", Rarity = "Common", Weight = 50 },
				{ PetId = "EmberFox", Rarity = "Uncommon", Weight = 30 },
				{ PetId = "MagmaSlime", Rarity = "Uncommon", Weight = 30 },
				{ PetId = "FireWolf", Rarity = "Rare", Weight = 15 },
				{ PetId = "LavaGolem", Rarity = "Rare", Weight = 15 },
				{ PetId = "PhoenixHatchling", Rarity = "Epic", Weight = 4 },
				{ PetId = "InfernoDragon", Rarity = "Legendary", Weight = 0.9 },
				{ PetId = "SolarPhoenix", Rarity = "Mythic", Weight = 0.09 },
				{ PetId = "EternalFlame", Rarity = "Secret", Weight = 0.01 },
			},
			AvailableIn = {
				VolcanoArea = true,
			},
		},
		IceEgg = {
			Id = "IceEgg",
			DisplayName = "Ice Egg",
			Description = "A frozen egg containing ice creatures.",
			Cost = {
				Currency = "Clicks",
				Amount = 5000,
			},
			AnimationDuration = 3,
			ModelName = "IceEggModel",
			CrackStages = 4,
			PetPool = {
				{ PetId = "SnowBunny", Rarity = "Common", Weight = 50 },
				{ PetId = "IcePenguin", Rarity = "Common", Weight = 50 },
				{ PetId = "ArcticFox", Rarity = "Uncommon", Weight = 30 },
				{ PetId = "SnowOwl", Rarity = "Uncommon", Weight = 30 },
				{ PetId = "FrostWolf", Rarity = "Rare", Weight = 15 },
				{ PetId = "IceGolem", Rarity = "Rare", Weight = 15 },
				{ PetId = "BlizzardBear", Rarity = "Epic", Weight = 4 },
				{ PetId = "FrostDragon", Rarity = "Legendary", Weight = 0.9 },
				{ PetId = "AuroraSpirit", Rarity = "Mythic", Weight = 0.09 },
				{ PetId = "AbsoluteZero", Rarity = "Secret", Weight = 0.01 },
			},
			AvailableIn = {
				IceArea = true,
			},
		},
		CrystalEgg = {
			Id = "CrystalEgg",
			DisplayName = "Crystal Egg",
			Description = "A mystical egg containing rare crystal pets.",
			Cost = {
				Currency = "Gems",
				Amount = 50,
			},
			AnimationDuration = 3.5,
			ModelName = "CrystalEggModel",
			CrackStages = 4,
			PetPool = {
				{ PetId = "CrystalSlime", Rarity = "Uncommon", Weight = 30 },
				{ PetId = "GemPup", Rarity = "Uncommon", Weight = 30 },
				{ PetId = "QuartzFox", Rarity = "Rare", Weight = 15 },
				{ PetId = "AmethystWolf", Rarity = "Rare", Weight = 15 },
				{ PetId = "DiamondDragon", Rarity = "Epic", Weight = 4 },
				{ PetId = "EmeraldGolem", Rarity = "Legendary", Weight = 0.9 },
				{ PetId = "RubyPhoenix", Rarity = "Mythic", Weight = 0.09 },
				{ PetId = "PrismaticBeing", Rarity = "Secret", Weight = 0.01 },
			},
			AvailableIn = {
				CrystalCave = true,
			},
		},
		LegendaryEgg = {
			Id = "LegendaryEgg",
			DisplayName = "Legendary Egg",
			Description = "An ancient egg with increased legendary chances.",
			Cost = {
				Currency = "Gems",
				Amount = 200,
			},
			AnimationDuration = 4,
			ModelName = "LegendaryEggModel",
			CrackStages = 5,
			PetPool = {
				{ PetId = "AncientWolf", Rarity = "Rare", Weight = 15 },
				{ PetId = "MysticBear", Rarity = "Rare", Weight = 15 },
				{ PetId = "RoyalLion", Rarity = "Epic", Weight = 4 },
				{ PetId = "CelestialDragon", Rarity = "Legendary", Weight = 5 }, -- Increased chance
				{ PetId = "CosmicPhoenix", Rarity = "Legendary", Weight = 5 }, -- Increased chance
				{ PetId = "EternalGuardian", Rarity = "Mythic", Weight = 0.5 },
				{ PetId = "VoidWalker", Rarity = "Secret", Weight = 0.05 },
			},
			AvailableIn = {
				LegendaryShop = true,
			},
		},
	},

	-- Egg opening settings
	OpeningSettings = {
		Cooldown = 0.5, -- seconds between openings
		MaxConcurrentOpenings = 1, -- per player
		AutoDeleteDuplicates = false,
		ShowRarityOnOpen = true,
	},

	-- Animation settings
	AnimationSettings = {
		ShakeIntensity = 0.1,
		ShakeFrequency = 20,
		GlowPulseSpeed = 2,
		ExplosionParticleCount = 50,
		PetFloatHeight = 5,
		PetFloatDuration = 3,
	},
}

-- Helper function to get egg by ID
function EggConfig:GetEgg(eggId)
	return self.Eggs[eggId]
end

-- Helper function to get all eggs available in a specific area
function EggConfig:GetEggsInArea(areaName)
	local eggs = {}
	for eggId, eggData in pairs(self.Eggs) do
		if eggData.AvailableIn and eggData.AvailableIn[areaName] then
			table.insert(eggs, eggData)
		end
	end
	return eggs
end

-- Helper function to get all eggs that cost a specific currency
function EggConfig:GetEggsByCurrency(currencyType)
	local eggs = {}
	for eggId, eggData in pairs(self.Eggs) do
		if eggData.Cost and eggData.Cost.Currency == currencyType then
			table.insert(eggs, eggData)
		end
	end
	return eggs
end

-- Calculate total weight of pet pool for weighted random
function EggConfig:CalculatePoolWeight(petPool)
	local totalWeight = 0
	for _, pet in ipairs(petPool) do
		totalWeight = totalWeight + pet.Weight
	end
	return totalWeight
end

return EggConfig
