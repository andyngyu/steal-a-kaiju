--!strict
-- Luck maths shared by the server (rolls) and the client (showing odds). See Shared.Config.LuckConfig.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local LuckConfig = require(Config:WaitForChild("LuckConfig"))
local EggConfig = require(Config:WaitForChild("EggConfig"))
local KaijuConfig = require(Config:WaitForChild("KaijuConfig"))

local Luck = {}

export type Odds = { { Rarity: string, Chance: number } }

-- Rarities a biome's eggs can hatch into (species exist for it there, or in "Any" for Secret).
local available: { [string]: { [string]: boolean } } = {}
local function hasSpecies(biomeId: string, rarityId: string): boolean
	local byBiome = available[biomeId]
	if not byBiome then
		byBiome = {}
		for _, cfg in KaijuConfig do
			if cfg.Biome == biomeId or cfg.Biome == "Any" then
				byBiome[cfg.Rarity] = true
			end
		end
		available[biomeId] = byBiome
	end
	return byBiome[rarityId] == true
end

function Luck.Clamp(luck: number?): number
	if type(luck) ~= "number" or luck ~= luck then
		return LuckConfig.Base
	end
	return math.clamp(luck, 0, LuckConfig.Max)
end

-- Hatch odds for an egg of `eggRarity` from `biomeId` at this Luck: the egg's rarity and every rarer one the biome
-- has species for, chances summing to 1, most common first.
function Luck.HatchOdds(biomeId: string, eggRarity: string, luck: number?): Odds
	luck = Luck.Clamp(luck)
	local H = LuckConfig.Hatch
	local base = EggConfig.RarityById[eggRarity]
	local baseOrder = base and base.Order or 1
	local step = math.min(H.MaxStep, (H.UpgradeStep[baseOrder] or H.UpgradeStep[#H.UpgradeStep]) * luck)
	local list = {}
	local total = 0
	local weight = 1
	for order = baseOrder, #EggConfig.Rarities do
		local r = EggConfig.Rarities[order]
		local w = weight
		if r.Id == "Secret" and order > baseOrder then
			w *= H.SecretFactor
		end
		if order == baseOrder or hasSpecies(biomeId, r.Id) then
			table.insert(list, { Rarity = r.Id, Chance = w })
			total += w
		end
		weight *= step
	end
	if #list == 0 or not hasSpecies(biomeId, list[1].Rarity) then
		-- an egg rarity the biome has no species for keeps the old fallback (HatchService picks a lower one)
		return { { Rarity = eggRarity, Chance = 1 } }
	end
	for _, entry in list do
		entry.Chance /= total
	end
	return list
end

-- Rolls the hatched rarity for an egg (rng: a Random).
function Luck.RollHatchRarity(rng: Random, biomeId: string, eggRarity: string, luck: number?): string
	local odds = Luck.HatchOdds(biomeId, eggRarity, luck)
	local pick = rng:NextNumber()
	for _, entry in odds do
		pick -= entry.Chance
		if pick <= 0 then
			return entry.Rarity
		end
	end
	return odds[#odds].Rarity
end

-- Chance a weather mutation with base chance `baseChance` (0-1) hits at this Luck: Luck counts as that many tries.
function Luck.MutationChance(baseChance: number, luck: number?): number
	luck = Luck.Clamp(luck)
	local p = math.clamp(baseChance, 0, 1)
	return math.min(LuckConfig.Mutation.MaxChance, 1 - (1 - p) ^ luck)
end

function Luck.RollMutation(rng: Random, baseChance: number, luck: number?): boolean
	return rng:NextNumber() < Luck.MutationChance(baseChance, luck)
end

-- "x1", "x1.25", "x12.5"
function Luck.Format(luck: number?): string
	local v = math.floor(Luck.Clamp(luck) * 100 + 0.5) / 100
	local s = string.format("%.2f", v)
	return "x" .. (s:gsub("0+$", ""):gsub("%.$", ""))
end

return Luck
