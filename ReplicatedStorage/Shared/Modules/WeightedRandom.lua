--[[
	WeightedRandom.lua
	Utility module for weighted random selection
	Used for egg opening rarity/pet selection
--]]

local WeightedRandom = {}

-- Select a random item from a weighted pool
-- pool: array of { Item = any, Weight = number }
-- luckMultiplier: optional multiplier for weights (default 1)
-- returns: selected item, index, and calculated weight
function WeightedRandom:Select(pool, luckMultiplier)
	luckMultiplier = luckMultiplier or 1
	
	if #pool == 0 then
		return nil, nil, 0
	end
	
	-- Calculate total weight with luck multiplier
	local totalWeight = 0
	local weightedItems = {}
	
	for i, entry in ipairs(pool) do
		local weight = entry.Weight * luckMultiplier
		totalWeight = totalWeight + weight
		table.insert(weightedItems, {
			Item = entry.Item or entry,
			Weight = weight,
			OriginalWeight = entry.Weight,
			Index = i,
		})
	end
	
	if totalWeight <= 0 then
		return nil, nil, 0
	end
	
	-- Generate random value
	local randomValue = math.random() * totalWeight
	
	-- Find selected item
	local currentWeight = 0
	for _, weightedItem in ipairs(weightedItems) do
		currentWeight = currentWeight + weightedItem.Weight
		if randomValue <= currentWeight then
			return weightedItem.Item, weightedItem.Index, weightedItem.Weight
		end
	end
	
	-- Fallback to last item (shouldn't happen with valid data)
	return weightedItems[#weightedItems].Item, 
	       weightedItems[#weightedItems].Index, 
	       weightedItems[#weightedItems].Weight
end

-- Select multiple unique items from a weighted pool
-- count: number of items to select
-- allowDuplicates: whether to allow selecting the same item multiple times
function WeightedRandom:SelectMultiple(pool, count, allowDuplicates, luckMultiplier)
	luckMultiplier = luckMultiplier or 1
	allowDuplicates = allowDuplicates or false
	
	if #pool == 0 or count <= 0 then
		return {}
	end
	
	local results = {}
	local availablePool = {}
	
	-- Copy pool
	for i, entry in ipairs(pool) do
		table.insert(availablePool, {
			Item = entry.Item or entry,
			Weight = entry.Weight,
			Index = i,
		})
	end
	
	for i = 1, count do
		if #availablePool == 0 then
			break
		end
		
		-- Calculate total weight
		local totalWeight = 0
		for _, entry in ipairs(availablePool) do
			totalWeight = totalWeight + (entry.Weight * luckMultiplier)
		end
		
		if totalWeight <= 0 then
			break
		end
		
		-- Select random item
		local randomValue = math.random() * totalWeight
		local currentWeight = 0
		local selectedIndex = nil
		
		for j, entry in ipairs(availablePool) do
			currentWeight = currentWeight + (entry.Weight * luckMultiplier)
			if randomValue <= currentWeight then
				table.insert(results, entry.Item)
				selectedIndex = j
				break
			end
		end
		
		-- Remove selected item if duplicates not allowed
		if not allowDuplicates and selectedIndex then
			table.remove(availablePool, selectedIndex)
		end
	end
	
	return results
end

-- Select with pity system
-- pool: array of { Item = any, Weight = number, Rarity = string }
-- pityCounters: table with OpensSinceLegendary, OpensSinceMythic, OpensSinceSecret
-- pityConfig: configuration for pity thresholds
function WeightedRandom:SelectWithPity(pool, pityCounters, pityConfig)
	pityCounters = pityCounters or {}
	pityConfig = pityConfig or {}
	
	local adjustedPool = {}
	
	for _, entry in ipairs(pool) do
		local adjustedWeight = entry.Weight
		local rarity = entry.Rarity
		
		-- Apply pity adjustments
		if rarity == "Legendary" and pityCounters.OpensSinceLegendary then
			if pityCounters.OpensSinceLegendary >= (pityConfig.GuaranteedLegendaryAfter or 100) then
				adjustedWeight = adjustedWeight * 10 -- 10x weight when pity triggered
			end
		elseif rarity == "Mythic" and pityCounters.OpensSinceMythic then
			if pityCounters.OpensSinceMythic >= (pityConfig.GuaranteedMythicAfter or 500) then
				adjustedWeight = adjustedWeight * 10
			end
		elseif rarity == "Secret" and pityCounters.OpensSinceSecret then
			if pityCounters.OpensSinceSecret >= (pityConfig.GuaranteedSecretAfter or 2000) then
				adjustedWeight = adjustedWeight * 10
			end
		end
		
		table.insert(adjustedPool, {
			Item = entry.Item or entry,
			Weight = adjustedWeight,
			OriginalWeight = entry.Weight,
			Rarity = rarity,
		})
	end
	
	return self:Select(adjustedPool)
end

-- Roll for rarity using standard weights
-- rarityWeights: table with rarity names as keys and weights as values
-- returns: selected rarity name
function WeightedRandom:RollRarity(rarityWeights)
	local pool = {}
	
	for rarity, weight in pairs(rarityWeights) do
		table.insert(pool, {
			Item = rarity,
			Weight = weight,
		})
	end
	
	local selectedRarity = self:Select(pool)
	return selectedRarity
end

-- Test function to verify distribution
function WeightedRandom:TestDistribution(pool, iterations)
	iterations = iterations or 10000
	
	local results = {}
	
	for i = 1, iterations do
		local item = self:Select(pool)
		if item then
			local key = tostring(item)
			results[key] = (results[key] or 0) + 1
		end
	end
	
	-- Convert to percentages
	for key, count in pairs(results) do
		results[key] = {
			Count = count,
			Percentage = (count / iterations) * 100,
		}
	end
	
	return results
end

return WeightedRandom
