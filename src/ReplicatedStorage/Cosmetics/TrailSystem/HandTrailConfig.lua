-- Hand trail configuration module with all available hand trail colors and prices
-- This module defines all purchasable hand trail cosmetics and their properties

local HandTrailConfig = {}

-- Hand trail data structure
-- Each hand trail has: id, name, color, price, currency, rarity, description
HandTrailConfig.HandTrails = {
	-- Default hand trail (free)
	{
		id = "default",
		name = "Classic White",
		color = Color3.fromRGB(255, 255, 255),
		price = 0,
		currency = "Coins",
		rarity = "Common",
		description = "The classic white hand trail that never goes out of style.",
	},

	-- Basic colored hand trails (Coins)
	{
		id = "red",
		name = "Crimson Fists",
		color = Color3.fromRGB(255, 50, 50),
		price = 300,
		currency = "Coins",
		rarity = "Common",
		description = "Bold red energy that flows from your hands.",
	},
	{
		id = "blue",
		name = "Ocean Waves",
		color = Color3.fromRGB(50, 150, 255),
		price = 300,
		currency = "Coins",
		rarity = "Common",
		description = "Cool blue waves that follow your hand movements.",
	},
	{
		id = "green",
		name = "Nature's Touch",
		color = Color3.fromRGB(50, 255, 100),
		price = 300,
		currency = "Coins",
		rarity = "Common",
		description = "Vibrant green energy that pulses with life.",
	},
	{
		id = "purple",
		name = "Royal Energy",
		color = Color3.fromRGB(150, 50, 255),
		price = 300,
		currency = "Coins",
		rarity = "Common",
		description = "Purple majesty that emanates from your fingertips.",
	},
	{
		id = "orange",
		name = "Sunset Glow",
		color = Color3.fromRGB(255, 150, 50),
		price = 300,
		currency = "Coins",
		rarity = "Common",
		description = "Warm orange energy that lights up your path.",
	},
	{
		id = "yellow",
		name = "Electric Touch",
		color = Color3.fromRGB(255, 255, 50),
		price = 300,
		currency = "Coins",
		rarity = "Common",
		description = "Electric yellow energy that crackles with power.",
	},

	-- Premium hand trails (Diamonds)
	{
		id = "rainbow",
		name = "Rainbow Spectrum",
		color = Color3.fromRGB(255, 100, 200), -- Will be handled specially for rainbow effect
		price = 75,
		currency = "Diamonds",
		rarity = "Rare",
		description = "A mesmerizing rainbow trail that cycles through all colors.",
	},
	{
		id = "gold",
		name = "Golden Touch",
		color = Color3.fromRGB(255, 215, 0),
		price = 100,
		currency = "Diamonds",
		rarity = "Rare",
		description = "Luxurious gold energy that shines with prestige.",
	},
	{
		id = "silver",
		name = "Silver Streak",
		color = Color3.fromRGB(192, 192, 192),
		price = 100,
		currency = "Diamonds",
		rarity = "Rare",
		description = "Elegant silver energy that glistens with sophistication.",
	},
	{
		id = "neon_cyan",
		name = "Neon Cyan",
		color = Color3.fromRGB(0, 255, 255),
		price = 125,
		currency = "Diamonds",
		rarity = "Epic",
		description = "Bright neon cyan that glows with futuristic energy.",
	},
	{
		id = "neon_pink",
		name = "Neon Pink",
		color = Color3.fromRGB(255, 0, 255),
		price = 125,
		currency = "Diamonds",
		rarity = "Epic",
		description = "Vibrant neon pink that pulses with electric energy.",
	},
	{
		id = "neon_green",
		name = "Neon Green",
		color = Color3.fromRGB(0, 255, 0),
		price = 125,
		currency = "Diamonds",
		rarity = "Epic",
		description = "Electric neon green that radiates with power.",
	},

	-- Legendary hand trails (High Diamond cost)
	{
		id = "void",
		name = "Void Touch",
		color = Color3.fromRGB(20, 20, 20),
		price = 300,
		currency = "Diamonds",
		rarity = "Legendary",
		description = "Dark void energy that consumes light from your hands.",
	},
	{
		id = "cosmic",
		name = "Cosmic Energy",
		color = Color3.fromRGB(100, 50, 200), -- Will be handled specially for cosmic effect
		price = 400,
		currency = "Diamonds",
		rarity = "Legendary",
		description = "Galactic energy that swirls with the power of the cosmos.",
	},
	{
		id = "plasma",
		name = "Plasma Fists",
		color = Color3.fromRGB(255, 100, 0), -- Will be handled specially for plasma effect
		price = 500,
		currency = "Diamonds",
		rarity = "Legendary",
		description = "Superheated plasma that burns with the intensity of a star.",
	},
}

-- Helper functions
function HandTrailConfig.getHandTrailById(id)
	for _, trail in ipairs(HandTrailConfig.HandTrails) do
		if trail.id == id then
			return trail
		end
	end
	return nil
end

function HandTrailConfig.getHandTrailsByRarity(rarity)
	local trails = {}
	for _, trail in ipairs(HandTrailConfig.HandTrails) do
		if trail.rarity == rarity then
			table.insert(trails, trail)
		end
	end
	return trails
end

function HandTrailConfig.getHandTrailsByCurrency(currency)
	local trails = {}
	for _, trail in ipairs(HandTrailConfig.HandTrails) do
		if trail.currency == currency then
			table.insert(trails, trail)
		end
	end
	return trails
end

function HandTrailConfig.getDefaultHandTrail()
	return HandTrailConfig.getHandTrailById("default")
end

-- Rarity colors for UI display (same as core trails)
HandTrailConfig.RarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(50, 150, 255),
	Epic = Color3.fromRGB(150, 50, 255),
	Legendary = Color3.fromRGB(255, 150, 50),
}

-- Currency icons (same as core trails)
HandTrailConfig.CurrencyIcons = {
	Coins = "rbxasset://textures/ui/GuiImagePlaceholder.png", -- Replace with actual coin icon
	Diamonds = "rbxasset://textures/ui/GuiImagePlaceholder.png", -- Replace with actual diamond icon
}

return HandTrailConfig
