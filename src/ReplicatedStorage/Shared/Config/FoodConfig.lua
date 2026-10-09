--!strict
-- Kaiju food (bought at the Food stall in the Kaiju Market) and kaiju levels.
-- Feeding gives XP; every level above 1 adds IncomePerLevel of the kaiju's income and SizePerLevel of its size,
-- up to MaxLevel. Kaiju income = species CashPerSecond x size roll x IncomeMultiplier(level) (see Shared.Util.KaijuStats).
local hex = Color3.fromHex

export type Food = { Id: string, Order: number, DisplayName: string, Price: number, XP: number, Color: Color3 }

local foods: { Food } = {
	{ Id = "Kibble", Order = 1, DisplayName = "Kaiju Kibble", Price = 100, XP = 10, Color = hex("C98A4B") },
	{ Id = "Drumstick", Order = 2, DisplayName = "Meaty Drumstick", Price = 1200, XP = 100, Color = hex("C2603A") },
	{ Id = "LavaPepper", Order = 3, DisplayName = "Lava Pepper", Price = 15000, XP = 1000, Color = hex("FF5A1F") },
	{ Id = "FrostFish", Order = 4, DisplayName = "Frost Fish", Price = 150000, XP = 8000, Color = hex("5AD1FF") },
	{ Id = "GoldenSteak", Order = 5, DisplayName = "Golden Steak", Price = 1500000, XP = 60000, Color = hex("FFD23F") },
	{ Id = "CosmicCandy", Order = 6, DisplayName = "Cosmic Candy", Price = 12000000, XP = 400000, Color = hex("D78CFF") },
}

local byId: { [string]: Food } = {}
for _, f in foods do
	byId[f.Id] = table.freeze(f)
end

local MAX_LEVEL = 50
local XP_BASE = 30 -- XP from level 1 to 2
local XP_GROWTH = 1.13 -- each level needs this much more XP than the last (about 91,600 XP from 1 to 50)
local INCOME_PER_LEVEL = 0.1 -- +10% of base income per level (level 50 = 5.9x)
local SIZE_PER_LEVEL = 0.012 -- +1.2% size per level (level 50 = 1.59x)

-- XP needed to go from `level` to `level + 1`; nil at MaxLevel.
local function xpToNext(level: number): number?
	if level >= MAX_LEVEL then
		return nil
	end
	return math.floor(XP_BASE * XP_GROWTH ^ (level - 1))
end

return table.freeze({
	Foods = table.freeze(foods), -- in shop order, cheapest first
	ById = table.freeze(byId),

	MaxLevel = MAX_LEVEL,
	XPToNext = xpToNext,
	IncomeMultiplier = function(level: number): number
		return 1 + INCOME_PER_LEVEL * (math.clamp(level, 1, MAX_LEVEL) - 1)
	end,
	SizeMultiplier = function(level: number): number
		return 1 + SIZE_PER_LEVEL * (math.clamp(level, 1, MAX_LEVEL) - 1)
	end,
	MaxVisualScale = 8, -- cap on rarity x size roll x level growth so giant leveled kaiju still fit in a pen

	MaxBuy = 100, -- most food bought in one purchase
	MaxFeed = 100, -- most food fed in one go
	FeedHoldSeconds = 0.25,
	LevelUpRespawnDelay = 0.6, -- the kaiju grows (model rebuilt bigger) after the food lands
})
