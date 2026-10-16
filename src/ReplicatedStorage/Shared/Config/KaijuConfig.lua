--!strict
-- Every kaiju species. Names are placeholders (Andy can rename DisplayName freely; keep the key stable once players own them).
-- Biome = "Any" means it can hatch from that rarity's eggs in every biome (used for Secret).
-- Model = name under ServerStorage.Assets.Kaiju; until it exists a blocky placeholder is built from Archetype/Color/Accent.
-- Species is rolled when an egg lands in a pen (from eggs of the same biome + rarity), so HatchSeconds is per species.
-- Scale is a per-species art tweak only; rarity (EggConfig KaijuScale) and the size roll handle how big a kaiju looks.
-- How each kaiju moves lives in ReplicatedStorage.KaijuAnimation (Config.Creatures; a species with no entry there gets a
-- profile from its model's Gait attribute, stamped by the asset builders).
local hex = Color3.fromHex

-- Global pet income buff: every species' CashPerSecond below is multiplied by this (selling and Index rewards follow
-- income, so they rise with it).
local INCOME_BUFF = 1.15

export type Kaiju = {
	DisplayName: string,
	Rarity: string,
	Biome: string,
	Archetype: string, -- "Lizard" | "Quadruped" | "Ape" | "Serpent" | "CrabBug"
	CashPerSecond: number,
	HatchSeconds: number,
	Model: string,
	Scale: number,
	Color: Color3, -- placeholder body colour
	Accent: Color3, -- placeholder glow/accent colour
}

local function k(display, rarity, biome, archetype, cps, hatch, color, accent, scale): Kaiju
	return table.freeze({
		DisplayName = display,
		Rarity = rarity,
		Biome = biome,
		Archetype = archetype,
		CashPerSecond = math.floor(cps * INCOME_BUFF * 100 + 0.5) / 100, -- rounded to cents
		HatchSeconds = hatch,
		Model = (display:gsub(" ", "")),
		Scale = scale or 1,
		Color = hex(color),
		Accent = hex(accent),
	})
end

local species: { [string]: Kaiju } = {
	-- Pebble Plains
	Pebblesaur = k("Pebblesaur", "Common", "PebblePlains", "Lizard", 2, 20, "8FA37A", "C9D1B8"),
	Chompling = k("Chompling", "Common", "PebblePlains", "Quadruped", 3, 20, "4DBB45", "FFEBC2"),
	Bonkey = k("Bonkey", "Uncommon", "PebblePlains", "Ape", 6, 40, "A0703F", "FFD9A0"),
	Tuskit = k("Tuskit", "Rare", "PebblePlains", "Quadruped", 15, 75, "9C7B6A", "FFF4D6"),
	Rumblerex = k("Rumblerex", "Epic", "PebblePlains", "Lizard", 40, 120, "4DBB45", "B05CFF"),
	Thunderback = k("Thunderback", "Legendary", "PebblePlains", "Ape", 100, 180, "3A4A8C", "FFD23F"),

	-- Lava Lagoon
	Magmite = k("Magmite", "Common", "LavaLagoon", "CrabBug", 8, 20, "3B2A2A", "FF6A1F"),
	CinderToad = k("Cinder Toad", "Uncommon", "LavaLagoon", "Quadruped", 18, 40, "7A4A3A", "FFB15C"),
	Scorchback = k("Scorchback", "Rare", "LavaLagoon", "Quadruped", 45, 75, "5C4A3A", "FF8A1F"),
	BlazeBonkey = k("Blaze Bonkey", "Epic", "LavaLagoon", "Ape", 110, 120, "B5452A", "FFC93C"),
	MoltenRex = k("Molten Rex", "Legendary", "LavaLagoon", "Lizard", 280, 180, "2E2424", "FF5A1F"),
	InfernoSerpent = k("Inferno Serpent", "Mythic", "LavaLagoon", "Serpent", 700, 300, "C2361F", "FFD23F"),

	-- Frostfang Peaks
	Snowpup = k("Snowpup", "Common", "FrostfangPeaks", "Quadruped", 25, 20, "F4FAFF", "8FD3FF"),
	GlacierCrab = k("Glacier Crab", "Uncommon", "FrostfangPeaks", "CrabBug", 55, 40, "8FD3FF", "E6F7FF"),
	Frostrhino = k("Frostrhino", "Rare", "FrostfangPeaks", "Quadruped", 140, 75, "B8C8D8", "6FE0FF"),
	Brrrilla = k("Brrrilla", "Epic", "FrostfangPeaks", "Ape", 350, 120, "EAF2FA", "5AA9FF"),
	IcebreakerRex = k("Icebreaker Rex", "Legendary", "FrostfangPeaks", "Lizard", 900, 180, "6FA8DC", "DFF6FF"),
	AuroraSerpent = k("Aurora Serpent", "Mythic", "FrostfangPeaks", "Serpent", 2200, 300, "3B4FA8", "6BFFB8"),

	-- Venom Jungle (income x3 Frostfang's per rarity)
	Vinewhip = k("Vinewhip", "Common", "VenomJungle", "Lizard", 75, 20, "4C7838", "58D22E"),
	Shroomhog = k("Shroomhog", "Uncommon", "VenomJungle", "Quadruped", 165, 40, "6E5138", "C77DFF"),
	Mantisaur = k("Mantisaur", "Rare", "VenomJungle", "Quadruped", 420, 75, "4E7A38", "62D42E"),
	Sabrejag = k("Sabrejag", "Epic", "VenomJungle", "Quadruped", 1050, 120, "3E6A34", "F0E8D0"),
	Toxitops = k("Toxitops", "Legendary", "VenomJungle", "Quadruped", 2700, 180, "52783A", "B04CFF"),
	Hydravine = k("Hydravine", "Mythic", "VenomJungle", "Serpent", 6600, 300, "4A7636", "E0408A"),

	-- Sunken Abyss (income x3 Venom Jungle's per rarity)
	Lurkfin = k("Lurkfin", "Common", "SunkenAbyss", "Lizard", 225, 20, "2A5E6C", "E8708C"),
	Barnaclaw = k("Barnaclaw", "Uncommon", "SunkenAbyss", "CrabBug", 495, 40, "1E4A58", "F07A3A"),
	Hammerjaw = k("Hammerjaw", "Rare", "SunkenAbyss", "Ape", 1260, 75, "5C7E88", "22C4E8"),
	Krakling = k("Krakling", "Epic", "SunkenAbyss", "Quadruped", 3150, 120, "58348A", "1AA6D8"),
	Megajaw = k("Megajaw", "Legendary", "SunkenAbyss", "Quadruped", 8100, 180, "5A6C78", "E6ECE6"),
	Tidewyrm = k("Tidewyrm", "Mythic", "SunkenAbyss", "Serpent", 19800, 300, "1E8088", "E8506E"),

	-- Storm Spires (income x3 Sunken Abyss's per rarity)
	Sparkit = k("Sparkit", "Common", "StormSpires", "Quadruped", 675, 20, "3E4048", "F0B448"),
	Voltbeak = k("Voltbeak", "Uncommon", "StormSpires", "Lizard", 1485, 40, "3E4A60", "FFC93A"),
	Thunderram = k("Thunderram", "Rare", "StormSpires", "Quadruped", 3780, 75, "3A3E46", "C27A3A"),
	Stormgriff = k("Stormgriff", "Epic", "StormSpires", "Quadruped", 9450, 120, "5A6070", "C08A4A"),
	Voltkirin = k("Voltkirin", "Legendary", "StormSpires", "Quadruped", 24300, 180, "3A3C44", "E0B040"),
	RaijinWyrm = k("Raijin Wyrm", "Mythic", "StormSpires", "Serpent", 59400, 300, "5A606C", "D8A830"),

	-- Cosmic Rift (income x3 Storm Spires's per rarity)
	Starmite = k("Starmite", "Common", "CosmicRift", "Quadruped", 2025, 20, "4E3A82", "B8A4FF"),
	Nebulynx = k("Nebulynx", "Uncommon", "CosmicRift", "Quadruped", 4455, 40, "3E3476", "2EB4B0"),
	Cometshell = k("Cometshell", "Rare", "CosmicRift", "Quadruped", 11340, 75, "5A5084", "6CCBFF"),
	Quasarab = k("Quasarab", "Epic", "CosmicRift", "CrabBug", 28350, 120, "263C96", "C8D4FF"),
	Astrodon = k("Astrodon", "Legendary", "CosmicRift", "Quadruped", 72900, 180, "4E3A86", "D8AC4C"),
	AstralWyrm = k("Astral Wyrm", "Mythic", "CosmicRift", "Quadruped", 178200, 300, "241C3A", "E050C8"),

	-- Secret (placeholder species so Secret eggs have something to hatch into)
	Prismling = k("Prismling", "Secret", "Any", "Lizard", 5000, 600, "FFFFFF", "FF4DFF"),
}

return table.freeze(species)
