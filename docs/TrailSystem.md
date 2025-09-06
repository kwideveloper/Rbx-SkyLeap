# Trail System Documentation

## Overview

The Trail System allows players to purchase and equip different colored trails that appear when they run. The system is fully integrated with the existing currency system and provides a scalable way to add new trail cosmetics.

## System Architecture

### Server-Side Components

1. **TrailSystem.server.lua** - Main server-side handler for trail purchases and equipment
2. **PlayerProfile.lua** - Updated with trail ownership and equipment functions
3. **Remotes.server.lua** - Added trail-related remote events and functions

### Client-Side Components

1. **TrailShopUI.client.lua** - Handles the shop UI for purchasing and equipping trails
2. **SpeedTrail.client.lua** - Modified to use equipped trail colors
3. **TrailConfig.lua** - Configuration module with all available trails

### Shared Components

1. **TrailConfig.lua** - Contains all trail definitions, prices, and properties

## Trail Configuration

### Adding New Trails

To add a new trail, edit `src/ReplicatedStorage/Cosmetics/TrailConfig.lua`:

```lua
{
    id = "unique_trail_id",
    name = "Display Name",
    color = Color3.fromRGB(255, 100, 200),
    price = 500,
    currency = "Coins", -- or "Diamonds"
    rarity = "Common", -- "Common", "Rare", "Epic", "Legendary"
    description = "Trail description for UI"
}
```

### Special Trail Effects

The system supports special effects for certain trails:

- **Rainbow**: Cycles through all colors
- **Cosmic**: Purple with shifting intensity
- **Plasma**: Orange with pulsing intensity

To create a special effect trail, use one of these IDs and the system will automatically apply the effect.

## UI Integration

### Shop UI Structure

The system expects the following UI structure in PlayerGui:

```
PlayerGui/
└── Shop/
    └── CanvasGroup/
        └── Frame/
            └── Content/
                └── Cosmetics/
                    └── [Trail frames will be created here]
```

### Trail Frame Structure

Each trail frame contains:
- **Preview**: Color display showing the trail color
- **Name**: Trail name label
- **Rarity**: Rarity indicator with color coding
- **Price**: Price display with currency
- **Buy Button**: Purchases the trail (hidden when owned)
- **Equip Button**: Equips the trail (hidden when not owned)

## API Reference

### Server Functions

#### PlayerProfile.ownsTrail(userId, trailId)
- **Parameters**: userId (string), trailId (string)
- **Returns**: boolean
- **Description**: Checks if a player owns a specific trail

#### PlayerProfile.purchaseTrail(userId, trailId)
- **Parameters**: userId (string), trailId (string)
- **Returns**: boolean
- **Description**: Marks a trail as owned by the player

#### PlayerProfile.equipTrail(userId, trailId)
- **Parameters**: userId (string), trailId (string)
- **Returns**: boolean, string
- **Description**: Equips a trail for the player

#### PlayerProfile.getEquippedTrail(userId)
- **Parameters**: userId (string)
- **Returns**: string
- **Description**: Gets the currently equipped trail ID

#### PlayerProfile.getOwnedTrails(userId)
- **Parameters**: userId (string)
- **Returns**: table
- **Description**: Gets list of owned trail IDs

### Remote Events

#### PurchaseTrail
- **Type**: RemoteFunction
- **Parameters**: trailId (string)
- **Returns**: {success: boolean, reason: string, message: string}
- **Description**: Purchases a trail for the current player

#### EquipTrail
- **Type**: RemoteFunction
- **Parameters**: trailId (string)
- **Returns**: {success: boolean, reason: string, message: string}
- **Description**: Equips a trail for the current player

#### GetTrailData
- **Type**: RemoteFunction
- **Parameters**: none
- **Returns**: {success: boolean, ownedTrails: table, equippedTrail: string, allTrails: table}
- **Description**: Gets all trail data for the current player

#### TrailEquipped
- **Type**: RemoteEvent
- **Parameters**: trailId (string)
- **Description**: Fired when a trail is equipped

## Security Features

### Purchase Protection
- Rate limiting: Maximum 10 purchases per minute per player
- Cooldown: 1 second between purchases
- Validation: Server-side verification of ownership and funds

### Data Integrity
- All trail ownership and equipment data is stored in PlayerProfile
- Force saves for critical operations (purchases, equipment changes)
- Server-side validation for all operations

## Performance Considerations

### Client-Side
- Trail colors are cached to avoid repeated lookups
- Special effects use efficient color calculations
- UI updates are batched to prevent spam

### Server-Side
- Purchase attempts are rate-limited
- DataStore operations are optimized with batching
- Critical operations use force saves

## Customization

### Adding New Rarities
1. Add rarity to `TrailConfig.RarityColors`
2. Update trail definitions to use new rarity
3. UI will automatically display the new rarity color

### Modifying Trail Effects
Edit the `getCurrentTrailColor()` function in `SpeedTrail.client.lua` to add new special effects.

### Changing Default Trail
Modify the `default` trail in `TrailConfig.lua` or change the fallback in `getCurrentTrailColor()`.

## Troubleshooting

### Common Issues

1. **Trail not appearing**: Check if the trail is equipped and the character has the required attachments
2. **Purchase failing**: Verify the player has sufficient currency and the trail isn't already owned
3. **UI not updating**: Ensure the shop UI structure matches the expected hierarchy

### Debug Information

The system logs significant purchases and equipment changes. Check the server console for:
- Purchase confirmations
- Equipment changes
- Error messages

## Future Enhancements

Potential improvements for the trail system:
- Trail animations and particles
- Trail sound effects
- Seasonal trail events
- Trail trading between players
- Trail customization options (width, transparency, etc.)
