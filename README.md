# Egg Opening System for Roblox

A comprehensive, production-ready egg opening system with pets, heavily inspired by Bubble Gum Simulator. Built with scalability, security, and extensibility in mind.

## Features

### Core Systems
- **7-Tier Rarity System**: Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret
- **Multi-Currency Economy**: Clicks (primary) and Gems (premium)
- **Pet Collection & Equipment**: Up to 4 pets equipped with orbital follower behavior
- **Inventory Management**: 100+ slots with sorting, filtering, and search
- **Rebirth System**: Prestige mechanic with gem rewards

### Security Features
- **Server-Authoritative Design**: All critical operations validated server-side
- **Anti-Cheat System**: Click rate limiting, position validation, currency sanity checks
- **Anti-Dupe Protection**: Unique GUIDs for all pets, atomic transactions, trade validation
- **Comprehensive Logging**: Detection levels with automatic enforcement

### Social Features
- **Leaderboards**: Clicks, Gems, Eggs Opened, Rebirths with live updates
- **Trading System**: Secure two-party confirmation with 5-second cancellation window
- **Server Notifications**: Mythic+ pet discoveries announced to all players
- **Global Announcements**: Secret pet discoveries broadcast globally

## Project Structure

```
RobloxEggSystem/
├── ReplicatedStorage/
│   └── Shared/
│       ├── Configs/
│       │   ├── RarityConfig.lua      # Rarity definitions & effects
│       │   ├── EggConfig.lua         # Egg types & pet pools
│       │   ├── PetConfig.lua         # Pet stats & abilities
│       │   └── CurrencyConfig.lua    # Currency & rebirth settings
│       ├── Modules/
│       │   ├── WeightedRandom.lua    # Weighted selection algorithm
│       │   └── GUID.lua              # Unique ID generation
│       └── Remotes/                  # RemoteEvents (auto-created)
├── ServerScriptService/
│   ├── Services/
│   │   ├── DataService.lua           # Player data persistence
│   │   ├── CurrencyService.lua       # Currency operations
│   │   ├── EggService.lua            # Egg opening logic
│   │   ├── PetService.lua            # Pet equipment & fusion
│   │   ├── InventoryService.lua      # Inventory management
│   │   ├── AntiCheatService.lua      # Security & detection
│   │   ├── TradeService.lua          # Secure trading
│   │   └── LeaderboardService.lua    # Leaderboard system
│   └── Main.server.lua               # Server initialization
├── StarterPlayerScripts/
│   └── Client/
│       ├── Controllers/
│       │   ├── UIController.lua      # Main UI handler
│       │   └── EggOpeningController.lua # Egg animation controller
│       └── Main.client.lua           # Client initialization
└── StarterGui/
    └── UI/                             # UI assets (to be provided)
```

## Rarity System

| Rarity | Color | Base Chance | Multiplier | Effects |
|--------|-------|-------------|------------|---------|
| Common | Gray | 50% | 1x | Minimal glow |
| Uncommon | Green | 30% | 2x | Subtle glow |
| Rare | Blue | 15% | 5x | Moderate glow |
| Epic | Purple | 4% | 15x | Screen flash |
| Legendary | Gold | 0.9% | 50x | Camera shake |
| Mythic | Magenta | 0.09% | 200x | Server notification |
| Secret | Red | 0.01% | 1000x | Global announcement |

## Pity System

- **Legendary**: Guaranteed after 100 opens without one
- **Mythic**: Guaranteed after 500 opens without one
- **Secret**: Guaranteed after 2000 opens without one

## API Reference

### Client to Server Remotes

```lua
-- Currency
remotes.Click:FireServer()                                    -- Process a click
remotes.RequestRebirth:FireServer()                           -- Request rebirth

-- Eggs
remotes.RequestOpenEgg:FireServer(eggId)                      -- Open an egg

-- Pets
remotes.EquipPet:FireServer(petInstanceId)                    -- Equip a pet
remotes.UnequipPet:FireServer(petInstanceId)                  -- Unequip a pet
remotes.FusePets:FireServer({petInstanceId1, ...})           -- Fuse pets
remotes.SellPet:FireServer(petInstanceId)                     -- Sell a pet
remotes.ToggleFavorite:FireServer(petInstanceId)              -- Toggle favorite

-- Inventory
remotes.RequestInventory:FireServer()                         -- Get inventory
remotes.SortInventory:FireServer(sortType)                    -- Sort inventory
remotes.FilterInventory:FireServer(filterType, filterValue)   -- Filter inventory
remotes.SearchInventory:FireServer(searchTerm)                -- Search inventory
remotes.ExpandInventory:FireServer(slotAmount)                -- Expand slots

-- Trading
remotes.RequestTrade:FireServer(targetPlayer)                 -- Request trade
remotes.TradeResponse:FireServer(requester, accepted)         -- Respond to trade
remotes.TradeAddItem:FireServer(tradeId, petInstanceId)       -- Add item to trade
remotes.TradeRemoveItem:FireServer(tradeId, petInstanceId)    -- Remove item
remotes.ConfirmTrade:FireServer(tradeId)                      -- Confirm trade
remotes.CancelTrade:FireServer(tradeId)                       -- Cancel trade

-- Leaderboard
remotes.RequestLeaderboard:FireServer(category)               -- Get leaderboard
remotes.SearchLeaderboard:FireServer(category, searchTerm)    -- Search leaderboard
```

### Server to Client Remotes

```lua
-- Currency
remotes.CurrencyUpdated.OnClientEvent:Connect(function(currencyType, newAmount)
    -- Update currency display
end)

-- Eggs
remotes.EggOpeningProgress.OnClientEvent:Connect(function(eventType, data, duration)
    -- Handle opening animation stages
end)

remotes.EggOpened.OnClientEvent:Connect(function(success, result)
    -- Handle egg result
end)

-- Inventory
remotes.InventoryUpdated.OnClientEvent:Connect(function(inventory)
    -- Update inventory display
end)

-- Pets
remotes.PetUpdated.OnClientEvent:Connect(function(eventType, data)
    -- Handle pet updates
end)

-- Leaderboard
remotes.LeaderboardUpdated.OnClientEvent:Connect(function(eventType, category, data)
    -- Update leaderboard display
end)

-- Trading
remotes.TradeUpdated.OnClientEvent:Connect(function(eventType, data)
    -- Handle trade updates
end)

-- Notifications
remotes.ServerNotification.OnClientEvent:Connect(function(message, color)
    -- Show server notification
end)

remotes.GlobalAnnouncement.OnClientEvent:Connect(function(message, color)
    -- Show global announcement
end)
```

## Configuration

### Adding New Eggs

Edit `ReplicatedStorage/Shared/Configs/EggConfig.lua`:

```lua
Eggs = {
    MyNewEgg = {
        Id = "MyNewEgg",
        DisplayName = "My New Egg",
        Description = "Description here",
        Cost = {
            Currency = "Clicks",
            Amount = 1000,
        },
        AnimationDuration = 3,
        ModelName = "MyNewEggModel",
        CrackStages = 4,
        PetPool = {
            { PetId = "Pet1", Rarity = "Common", Weight = 50 },
            { PetId = "Pet2", Rarity = "Rare", Weight = 15 },
            -- ... more pets
        },
    },
}
```

### Adding New Pets

Edit `ReplicatedStorage/Shared/Configs/PetConfig.lua`:

```lua
Pets = {
    MyNewPet = {
        Id = "MyNewPet",
        DisplayName = "My New Pet",
        Description = "Description here",
        Rarity = "Legendary",
        ModelName = "MyNewPetModel",
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
    },
}
```

## Installation

1. Copy all files to your Roblox game
2. Ensure folder structure matches the project layout
3. The system auto-initializes on server start
4. UI assets need to be provided (Phase 6 checkpoint)

## Security Considerations

- All currency transactions are server-validated
- Egg results are calculated server-side only
- Click rates are monitored and limited
- Position changes are validated
- Inventory integrity is checked regularly
- Trade transactions are atomic with rollback capability

## Performance Optimization

- Data is cached and auto-saved every 5 minutes
- Leaderboards update at different intervals based on volatility
- Particle effects use object pooling
- Inventory uses lazy loading
- Client-side animations are lightweight

## Future Expansion

The system is designed for easy expansion:
- Modular egg registration
- Plugin architecture for pet abilities
- Event system for seasonal content
- Configurable game balance values
- API hooks for external integrations

---

## Phase 6 Checkpoint - WAITING FOR USER UI ASSETS

We have reached the UI integration phase. To proceed with Phase 6, please provide:

1. **Egg Opening Interface Layout**
   - How the egg opening screen should look
   - Position of egg model, animation elements
   - Result display layout

2. **Inventory Screen Design**
   - Grid layout for pet slots
   - Equipped pets display
   - Sort/filter controls
   - Pet detail popup design

3. **Leaderboard Visual Style**
   - List layout and styling
   - Rank badges design
   - Player entry format

4. **Notification/Popup Designs**
   - Notification style and position
   - Global announcement format
   - Error/success message styling

5. **Overall Color Scheme and Visual Theme**
   - Primary/secondary colors
   - Font preferences
   - Button styles
   - Frame/background styling

Please provide screenshots or detailed descriptions of your UI design before proceeding with Phase 6 implementation.
