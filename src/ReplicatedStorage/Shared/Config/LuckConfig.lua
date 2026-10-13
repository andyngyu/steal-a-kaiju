--!strict
-- Luck: one player stat (player attribute Luck, a multiplier: 1 = normal) that every RNG roll in the game can read.
-- Set by LuckService on the server from all luck sources (game passes + timed luck from GamePassService today; add
-- more with LuckService:SetSource). The maths lives in Shared.Util.Luck so the server and the UI agree.
--
-- Where Luck is used:
--   Hatching   (HatchService) an egg's rarity is the minimum: the hatch can also roll any rarer tier that species
--              exist for in that biome. Each tier above the egg's own is UpgradeStep[eggOrder] x Luck times as
--              likely as the tier below it (capped at MaxStep), so rarer eggs climb further and Luck climbs further.
--   Egg size   (EggService) Luck - 1 extra size rolls (keep the biggest) when an egg lands in your pen.
--   Mutations  (the upcoming weather events) a mutation with base chance p hits with 1 - (1 - p) ^ Luck, i.e. Luck
--              counts as that many tries (capped at Mutation.MaxChance). Use LuckService:RollMutation.

return table.freeze({
	Base = 1, -- everyone's Luck before any boosts
	Max = 100, -- safety cap on the combined stat

	Hatch = table.freeze({
		-- chance multiplier per tier above the egg's own rarity, by the egg's rarity Order (1 Common ... 6 Mythic).
		-- e.g. a Common egg: Uncommon is 0.12x as likely as Common, Rare 0.12x as likely as Uncommon, ...
		UpgradeStep = table.freeze({ 0.12, 0.16, 0.2, 0.25, 0.3, 0.35 }),
		SecretFactor = 0.04, -- Secret is this much rarer again than its step would make it
		MaxStep = 0.85, -- Luck can't push a step above this (the egg's own rarity always stays the likeliest)
	}),

	Mutation = table.freeze({
		MaxChance = 0.95,
	}),
})
