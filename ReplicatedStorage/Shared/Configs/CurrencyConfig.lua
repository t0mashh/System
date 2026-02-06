--[[
	CurrencyConfig.lua
	Configuration for all currency types and their properties
--]]

local CurrencyConfig = {
	-- Currency type definitions
	Currencies = {
		Clicks = {
			Id = "Clicks",
			DisplayName = "Clicks",
			Symbol = "",
			Suffix = " Clicks",
			Color = Color3.fromRGB(255, 255, 255), -- White
			Icon = "rbxassetid://CLICKS_ICON",
			MaxAmount = math.huge, -- Unlimited
			Tradeable = false,
			EarnMethods = {
				ManualClick = true,
				PetMultiplier = true,
				PassiveGeneration = true,
			},
			CompactDisplay = true, -- Use K, M, B suffixes
		},
		Gems = {
			Id = "Gems",
			DisplayName = "Gems",
			Symbol = "",
			Suffix = " Gems",
			Color = Color3.fromRGB(0, 255, 255), -- Cyan
			Icon = "rbxassetid://GEMS_ICON",
			MaxAmount = 999999999, -- Cap for anti-cheat
			Tradeable = true,
			EarnMethods = {
				Rebirth = true,
				RarePetDiscovery = true,
				Achievements = true,
			},
			CompactDisplay = true,
		},
	},

	-- Rebirth system configuration
	Rebirth = {
		Enabled = true,
		Formula = function(totalClicks, rebirthCount)
			-- Gems awarded = (Total Clicks / 1,000,000) × Rebirth Multiplier
			local rebirthMultiplier = 1 + (rebirthCount * 0.1)
			return math.floor((totalClicks / 1000000) * rebirthMultiplier)
		end,
		MinClicksForRebirth = 1000000, -- 1 million clicks minimum
		ResetClicksOnRebirth = true,
		KeepInventoryOnRebirth = true,
		KeepGemsOnRebirth = true,
		RebirthMultiplierIncrement = 0.1, -- 10% increase per rebirth
	},

	-- Click earning configuration
	ClickSettings = {
		BaseClickValue = 1,
		MaxClicksPerSecond = 15, -- Anti-cheat rate limit
		AutoClickerDetectionThreshold = 12, -- Clicks per second that trigger suspicion
		PassiveGenerationInterval = 1, -- Seconds between passive clicks
	},

	-- Currency display formatting
	Formatting = {
		Suffixes = {
			{ Value = 1e3, Suffix = "K" },
			{ Value = 1e6, Suffix = "M" },
			{ Value = 1e9, Suffix = "B" },
			{ Value = 1e12, Suffix = "T" },
			{ Value = 1e15, Suffix = "Qa" },
			{ Value = 1e18, Suffix = "Qi" },
		},
		DecimalPlaces = 2,
	},
}

-- Helper function to format currency amount with suffixes
function CurrencyConfig:FormatAmount(amount, currencyId)
	local currency = self.Currencies[currencyId]
	if not currency then return tostring(amount) end
	
	if not currency.CompactDisplay or amount < 1000 then
		return tostring(math.floor(amount)) .. currency.Suffix
	end
	
	-- Find appropriate suffix
	local suffix = ""
	local divisor = 1
	for _, suffixData in ipairs(self.Formatting.Suffixes) do
		if amount >= suffixData.Value then
			suffix = suffixData.Suffix
			divisor = suffixData.Value
		else
			break
		end
	end
	
	local formattedValue = amount / divisor
	local decimalPlaces = self.Formatting.DecimalPlaces
	
	-- Reduce decimal places for larger numbers
	if formattedValue >= 100 then
		decimalPlaces = 1
	elseif formattedValue >= 1000 then
		decimalPlaces = 0
	end
	
	return string.format("%." .. decimalPlaces .. "f", formattedValue) .. suffix .. currency.Suffix
end

-- Helper function to get currency by ID
function CurrencyConfig:GetCurrency(currencyId)
	return self.Currencies[currencyId]
end

-- Helper function to check if currency is tradeable
function CurrencyConfig:IsTradeable(currencyId)
	local currency = self.Currencies[currencyId]
	return currency and currency.Tradeable or false
end

-- Calculate rebirth rewards
function CurrencyConfig:CalculateRebirthGems(totalClicks, rebirthCount)
	if not self.Rebirth.Enabled then
		return 0
	end
	
	if totalClicks < self.Rebirth.MinClicksForRebirth then
		return 0
	end
	
	return self.Rebirth.Formula(totalClicks, rebirthCount)
end

return CurrencyConfig
