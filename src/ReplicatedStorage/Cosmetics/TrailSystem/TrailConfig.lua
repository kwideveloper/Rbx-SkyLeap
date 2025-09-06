-- Trail configuration module with all available trail colors and prices
-- This module defines all purchasable trail cosmetics and their properties

local TrailConfig = {}

-- Trail data structure
-- Each trail has: id, name, color, price, currency, rarity, description
TrailConfig.Trails = {
	-- Default trail (free)
	{
		id = "default",
		name = "Classic White",
		color = Color3.fromRGB(255, 255, 255),
		price = 0,
		currency = "Coins",
		rarity = "Common",
		description = "The classic white trail that never goes out of style.",
	},

	-- Basic colored trails (Coins)
	{
		id = "red",
		name = "Crimson Rush",
		color = Color3.fromRGB(255, 50, 50),
		price = 500,
		currency = "Coins",
		rarity = "Common",
		description = "A bold red trail that screams speed and power.",
	},
	{
		id = "blue",
		name = "Ocean Flow",
		color = Color3.fromRGB(50, 150, 255),
		price = 500,
		currency = "Coins",
		rarity = "Common",
		description = "Cool blue waves that flow with your movement.",
	},
	{
		id = "green",
		name = "Forest Sprint",
		color = Color3.fromRGB(50, 255, 100),
		price = 500,
		currency = "Coins",
		rarity = "Common",
		description = "Nature's speed in a vibrant green trail.",
	},
	{
		id = "purple",
		name = "Royal Velocity",
		color = Color3.fromRGB(150, 50, 255),
		price = 500,
		currency = "Coins",
		rarity = "Common",
		description = "Purple majesty that follows your every move.",
	},
	{
		id = "orange",
		name = "Sunset Dash",
		color = Color3.fromRGB(255, 150, 50),
		price = 500,
		currency = "Coins",
		rarity = "Common",
		description = "Warm orange glow that lights up your path.",
	},
	{
		id = "yellow",
		name = "Lightning Bolt",
		color = Color3.fromRGB(255, 255, 50),
		price = 500,
		currency = "Coins",
		rarity = "Common",
		description = "Electric yellow energy that crackles with speed.",
	},

	-- Premium trails (Diamonds)
	{
		id = "rainbow",
		name = "Rainbow Spectrum",
		color = Color3.fromRGB(255, 100, 200), -- Will be handled specially for rainbow effect
		price = 100,
		currency = "Diamonds",
		rarity = "Rare",
		description = "A mesmerizing rainbow trail that cycles through all colors.",
	},
	{
		id = "gold",
		name = "Golden Glory",
		color = Color3.fromRGB(255, 215, 0),
		price = 150,
		currency = "Diamonds",
		rarity = "Rare",
		description = "Luxurious gold trail that shines with prestige.",
	},
	{
		id = "silver",
		name = "Silver Streak",
		color = Color3.fromRGB(192, 192, 192),
		price = 150,
		currency = "Diamonds",
		rarity = "Rare",
		description = "Elegant silver trail that glistens with sophistication.",
	},
	{
		id = "neon_cyan",
		name = "Neon Cyan",
		color = Color3.fromRGB(0, 255, 255),
		price = 200,
		currency = "Diamonds",
		rarity = "Epic",
		description = "Bright neon cyan that glows with futuristic energy.",
	},
	{
		id = "neon_pink",
		name = "Neon Pink",
		color = Color3.fromRGB(255, 0, 255),
		price = 200,
		currency = "Diamonds",
		rarity = "Epic",
		description = "Vibrant neon pink that pulses with electric energy.",
	},
	{
		id = "neon_green",
		name = "Neon Green",
		color = Color3.fromRGB(0, 255, 0),
		price = 200,
		currency = "Diamonds",
		rarity = "Epic",
		description = "Electric neon green that radiates with power.",
	},

	-- Legendary trails (High Diamond cost)
	{
		id = "void",
		name = "Void Walker",
		color = Color3.fromRGB(20, 20, 20),
		price = 500,
		currency = "Diamonds",
		rarity = "Legendary",
		description = "Dark void energy that consumes light itself.",
	},
	{
		id = "cosmic",
		name = "Cosmic Storm",
		color = Color3.fromRGB(100, 50, 200), -- Will be handled specially for cosmic effect
		price = 750,
		currency = "Diamonds",
		rarity = "Legendary",
		description = "Galactic energy that swirls with the power of the cosmos.",
	},
	{
		id = "plasma",
		name = "Plasma Core",
		color = Color3.fromRGB(255, 100, 0), -- Will be handled specially for plasma effect
		price = 1000,
		currency = "Diamonds",
		rarity = "Legendary",
		description = "Superheated plasma that burns with the intensity of a star.",
	},
}

-- Helper functions
function TrailConfig.getTrailById(id)
	for _, trail in ipairs(TrailConfig.Trails) do
		if trail.id == id then
			return trail
		end
	end
	return nil
end

function TrailConfig.getTrailsByRarity(rarity)
	local trails = {}
	for _, trail in ipairs(TrailConfig.Trails) do
		if trail.rarity == rarity then
			table.insert(trails, trail)
		end
	end
	return trails
end

function TrailConfig.getTrailsByCurrency(currency)
	local trails = {}
	for _, trail in ipairs(TrailConfig.Trails) do
		if trail.currency == currency then
			table.insert(trails, trail)
		end
	end
	return trails
end

function TrailConfig.getDefaultTrail()
	return TrailConfig.getTrailById("default")
end

-- Rarity colors for UI display
TrailConfig.RarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(50, 150, 255),
	Epic = Color3.fromRGB(150, 50, 255),
	Legendary = Color3.fromRGB(255, 150, 50),
}

-- Currency icons (you'll need to set these up in your UI)
TrailConfig.CurrencyIcons = {
	Coins = "rbxasset://textures/ui/GuiImagePlaceholder.png", -- Replace with actual coin icon
	Diamonds = "rbxasset://textures/ui/GuiImagePlaceholder.png", -- Replace with actual diamond icon
}

return TrailConfig
