--!strict
-- Eggs: rarities, per-biome rarity weights, size rolls, nest respawns, carrying and pickup rules.
--
-- Size system: every egg rolls a size (SizeTiers). The egg is physically that much bigger, the kaiju that hatches
-- inherits it (+/- KaijuSizeJitter) and earns CashPerSecond x size. Rarity adds a visual-only scale on top
-- (EggScale / KaijuScale), so rarer kaiju look bigger without double-counting money.
local hex = Color3.fromHex

export type Rarity = { Id: string, Order: number, Color: Color3, Glow: boolean, EggScale: number, KaijuScale: number, Aura: boolean }

local rarities: { Rarity } = {
	{ Id = "Common", Order = 1, Color = hex("B8C0CC"), Glow = false, EggScale = 1, KaijuScale = 1, Aura = false },
	{ Id = "Uncommon", Order = 2, Color = hex("5FD35F"), Glow = false, EggScale = 1.05, KaijuScale = 1.12, Aura = false },
	{ Id = "Rare", Order = 3, Color = hex("3FA9FF"), Glow = false, EggScale = 1.1, KaijuScale = 1.25, Aura = false },
	{ Id = "Epic", Order = 4, Color = hex("B05CFF"), Glow = true, EggScale = 1.18, KaijuScale = 1.45, Aura = false },
	{ Id = "Legendary", Order = 5, Color = hex("FFC93C"), Glow = true, EggScale = 1.28, KaijuScale = 1.7, Aura = true },
	{ Id = "Mythic", Order = 6, Color = hex("FF4D8D"), Glow = true, EggScale = 1.4, KaijuScale = 2.0, Aura = true },
	{ Id = "Secret", Order = 7, Color = hex("FFFFFF"), Glow = true, EggScale = 1.55, KaijuScale = 2.4, Aura = true }, -- rainbow in the art pass
}

local byId: { [string]: Rarity } = {}
for _, r in rarities do
	byId[r.Id] = table.freeze(r)
end

-- Size rolls. Size is a multiplier on egg/kaiju size AND income. Name shows on labels ("Giant Rare Egg").
local sizeTiers = {
	{ Name = "", Weight = 70, Min = 0.9, Max = 1.15 },
	{ Name = "Big", Weight = 20, Min = 1.4, Max = 1.7 },
	{ Name = "Huge", Weight = 8, Min = 1.9, Max = 2.3 },
	{ Name = "Giant", Weight = 2, Min = 2.6, Max = 3.0 },
}
for _, t in sizeTiers do
	table.freeze(t)
end

local function tierName(size: number): string
	local name = ""
	for _, t in sizeTiers do
		if size >= t.Min - 0.05 then
			name = t.Name
		end
	end
	return name
end

-- Who gets the big hatch (longer build-up, light pillar, banner) and a server-wide chat announcement.
local announce = table.freeze({
	MinRarityOrder = 4, -- Epic and up
	MinSize = 1.85, -- or Huge/Giant of any rarity
})

local function isGrand(rarityId: string, size: number): boolean
	local r = byId[rarityId]
	return (r ~= nil and r.Order >= announce.MinRarityOrder) or size >= announce.MinSize
end

return table.freeze({
	Rarities = table.freeze(rarities),
	RarityById = table.freeze(byId),

	SizeTiers = table.freeze(sizeTiers),
	SizeTierName = tierName, -- size -> "" | "Big" | "Huge" | "Giant"
	KaijuSizeJitter = 0.06, -- hatched kaiju size = egg size x (1 +/- this)

	Announce = announce,
	IsGrand = isGrand, -- (rarityId, size) -> true for Epic+ or Huge+ hatches

	-- Relative weights per biome (they do not need to sum to 100).
	Weights = table.freeze({
		PebblePlains = table.freeze({ Common = 60, Uncommon = 25, Rare = 10, Epic = 4, Legendary = 1, Secret = 0.05 }),
		LavaLagoon = table.freeze({ Common = 40, Uncommon = 30, Rare = 17, Epic = 8, Legendary = 4, Mythic = 1, Secret = 0.1 }),
		FrostfangPeaks = table.freeze({ Common = 25, Uncommon = 30, Rare = 22, Epic = 13, Legendary = 7, Mythic = 3, Secret = 0.2 }),
	}),

	-- Placeholder shell colour per biome; the crack band uses the rarity colour.
	ShellColors = table.freeze({
		PebblePlains = hex("E9F5D8"),
		LavaLagoon = hex("F7D2A6"),
		FrostfangPeaks = hex("E6F4FF"),
	}),

	Size = Vector3.new(2.2, 2.8, 2.2),

	Nest = table.freeze({
		EggsPerNest = 4, -- eggs sitting on a nest at once (max = EggSpawn attachments)
		RespawnSeconds = 10, -- after an egg is taken, a new one appears this much later
	}),

	Pickup = table.freeze({
		MaxDistance = 12, -- server-side distance check (studs)
		PromptDistance = 10,
		HoldSeconds = 0.3,
		CooldownSeconds = 0.5,
	}),

	Carry = table.freeze({
		SpeedMultiplier = 0.85,
		OverheadOffset = 4.4, -- studs above HumanoidRootPart for a normal egg
		HeadClearance = 3.0, -- bigger eggs sit with their bottom this far above the HumanoidRootPart
	}),

	Ground = table.freeze({
		DespawnSeconds = 20, -- a dropped egg nobody grabs disappears after this
	}),

	StunSecondsAfterCatch = 1.0, -- can't grab eggs right after being caught
})
