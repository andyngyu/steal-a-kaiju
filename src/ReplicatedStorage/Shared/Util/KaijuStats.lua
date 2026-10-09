--!strict
-- One place for what a kaiju is worth and how big it looks, from its species, size roll and level.
--   CashPerSecond = species CashPerSecond x size x FoodConfig.IncomeMultiplier(level)
--   VisualScale   = species Scale x rarity KaijuScale x size x FoodConfig.SizeMultiplier(level), capped at MaxVisualScale
--   SellPrice     = CashPerSecond x EconomyConfig.SellMultiplier
local Config = script.Parent.Parent.Config
local KaijuConfig = require(Config.KaijuConfig)
local EggConfig = require(Config.EggConfig)
local FoodConfig = require(Config.FoodConfig)
local EconomyConfig = require(Config.EconomyConfig)

local KaijuStats = {}

function KaijuStats.CashPerSecond(species: string, size: number?, level: number?): number
	local cfg = KaijuConfig[species]
	if not cfg then
		return 0
	end
	return cfg.CashPerSecond * (size or 1) * FoodConfig.IncomeMultiplier(level or 1)
end

function KaijuStats.VisualScale(species: string, size: number?, level: number?): number
	local cfg = KaijuConfig[species]
	if not cfg then
		return 1
	end
	local rarity = EggConfig.RarityById[cfg.Rarity]
	local scale = (cfg.Scale or 1) * (rarity and rarity.KaijuScale or 1) * (size or 1) * FoodConfig.SizeMultiplier(level or 1)
	return math.min(scale, FoodConfig.MaxVisualScale)
end

function KaijuStats.SellPrice(species: string, size: number?, level: number?): number
	return math.floor(KaijuStats.CashPerSecond(species, size, level) * EconomyConfig.SellMultiplier)
end

-- Same values for a saved pen entry.
function KaijuStats.EntryCashPerSecond(entry: { [string]: any }): number
	return KaijuStats.CashPerSecond(entry.Species, entry.Size, entry.Level)
end

return KaijuStats
