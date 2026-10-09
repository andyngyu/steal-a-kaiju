--!strict
-- Every kaiju species. Names are placeholders (Andy can rename DisplayName freely; keep the key stable once players own them).
-- Biome = "Any" means it can hatch from that rarity's eggs in every biome (used for Secret).
-- Model = name under ServerStorage.Assets.Kaiju; until it exists a blocky placeholder is built from Archetype/Color/Accent.
-- Species is rolled when an egg lands in a pen (from eggs of the same biome + rarity), so HatchSeconds is per species.
-- Scale is a per-species art tweak only; rarity (EggConfig KaijuScale) and the size roll handle how big a kaiju looks.
local hex = Color3.fromHex

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
		CashPerSecond = cps,
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

	-- Secret (placeholder species so Secret eggs have something to hatch into)
	Prismling = k("Prismling", "Secret", "Any", "Lizard", 5000, 600, "FFFFFF", "FF4DFF"),
}

return table.freeze(species)
