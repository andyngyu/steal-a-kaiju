--!strict
-- Eggs: rarities, per-biome rarity weights, nest respawns, carrying and pickup rules.
local hex = Color3.fromHex

export type Rarity = { Id: string, Order: number, Color: Color3, Glow: boolean }

local rarities: { Rarity } = {
	{ Id = "Common", Order = 1, Color = hex("B8C0CC"), Glow = false },
	{ Id = "Uncommon", Order = 2, Color = hex("5FD35F"), Glow = false },
	{ Id = "Rare", Order = 3, Color = hex("3FA9FF"), Glow = false },
	{ Id = "Epic", Order = 4, Color = hex("B05CFF"), Glow = true },
	{ Id = "Legendary", Order = 5, Color = hex("FFC93C"), Glow = true },
	{ Id = "Mythic", Order = 6, Color = hex("FF4D8D"), Glow = true },
	{ Id = "Secret", Order = 7, Color = hex("FFFFFF"), Glow = true }, -- rainbow in the art pass
}

local byId: { [string]: Rarity } = {}
for _, r in rarities do
	byId[r.Id] = table.freeze(r)
end

return table.freeze({
	Rarities = table.freeze(rarities),
	RarityById = table.freeze(byId),

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
		OverheadOffset = 4.4, -- studs above HumanoidRootPart
	}),

	Ground = table.freeze({
		DespawnSeconds = 20, -- a dropped egg nobody grabs disappears after this
	}),

	StunSecondsAfterCatch = 1.0, -- can't grab eggs right after being caught
})
