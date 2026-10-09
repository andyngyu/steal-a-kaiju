--!strict
-- Kaiju food (bought in the Kaiju Food shop at the Food stall in the Kaiju Market) and kaiju levels.
-- Feeding gives XP; every level above 1 adds IncomePerLevel of the kaiju's income and SizePerLevel of its size,
-- up to MaxLevel. Kaiju income = species CashPerSecond x size roll x IncomeMultiplier(level) (see Shared.Util.KaijuStats).
--
-- Stock: the shop restocks every RestockSeconds on one clock for every server. Each restock rolls, per food, whether it's
-- in stock (Stock.Chance) and how many (Stock.Min..Max) - the same roll everywhere (RollStock(cycle)), so a rare
-- Cosmic Candy restock is news for everyone. Each player then buys from their own copy of that stock.
local hex = Color3.fromHex

export type Stock = { Chance: number, Min: number, Max: number }
export type Food = { Id: string, Order: number, DisplayName: string, Price: number, XP: number, Color: Color3, Stock: Stock }

local foods: { Food } = {
	{ Id = "Kibble", Order = 1, DisplayName = "Kaiju Kibble", Price = 100, XP = 10, Color = hex("C98A4B"), Stock = { Chance = 1, Min = 25, Max = 40 } },
	{ Id = "Drumstick", Order = 2, DisplayName = "Meaty Drumstick", Price = 1200, XP = 100, Color = hex("C2603A"), Stock = { Chance = 1, Min = 10, Max = 20 } },
	{ Id = "LavaPepper", Order = 3, DisplayName = "Lava Pepper", Price = 15000, XP = 1000, Color = hex("FF5A1F"), Stock = { Chance = 0.75, Min = 3, Max = 8 } },
	{ Id = "FrostFish", Order = 4, DisplayName = "Frost Fish", Price = 150000, XP = 8000, Color = hex("5AD1FF"), Stock = { Chance = 0.5, Min = 1, Max = 4 } },
	{ Id = "GoldenSteak", Order = 5, DisplayName = "Golden Steak", Price = 1500000, XP = 60000, Color = hex("FFD23F"), Stock = { Chance = 0.25, Min = 1, Max = 2 } },
	{ Id = "CosmicCandy", Order = 6, DisplayName = "Cosmic Candy", Price = 12000000, XP = 400000, Color = hex("D78CFF"), Stock = { Chance = 0.1, Min = 1, Max = 1 } },
}

local RESTOCK_SECONDS = 300

-- What restock number `cycle` (floor(unix time / RestockSeconds)) puts in the shop: { [foodId] = count, 0 = sold out }.
local function rollStock(cycle: number): { [string]: number }
	local stock = {}
	for _, f in foods do
		local rng = Random.new(cycle * 1000 + f.Order * 7 + 13)
		local s = f.Stock
		stock[f.Id] = rng:NextNumber() < s.Chance and rng:NextInteger(s.Min, s.Max) or 0
	end
	return stock
end

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

	RestockSeconds = RESTOCK_SECONDS,
	RollStock = rollStock,
	RareStockChance = 0.3, -- a restock with a food rarer than this in stock is announced to everyone

	MaxBuy = 100, -- most food bought in one purchase
	MaxFeed = 100, -- most food fed in one go
	FeedHoldSeconds = 0.25,
	LevelUpRespawnDelay = 0.6, -- the kaiju grows (model rebuilt bigger) after the food lands
})
