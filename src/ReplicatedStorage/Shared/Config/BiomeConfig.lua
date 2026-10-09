--!strict
-- Biomes along the lane, in order from the bases outward.
-- Length is in studs along the lane. NestAt is how far into the biome the nest sits (0 = entrance, 1 = far end).
-- Guardian speeds are tuned so a player running straight at RecommendedSpeed (carry-slowed) just escapes.
local hex = Color3.fromHex

export type Guardian = {
	WalkSpeed: number, -- chase speed
	ReturnSpeed: number, -- walking home
	WakeDelay: number, -- roar time before the chase starts
	CatchDistance: number,
	DetectionRadius: number, -- while awake, re-targets egg carriers from its nest within this range
	MaxChaseSeconds: number,
	Knockback: number,
	Scale: number,
}

export type Biome = {
	Id: string,
	Order: number,
	DisplayName: string,
	RecommendedSpeed: number,
	Length: number,
	NestAt: number,
	Decor: string, -- "Plains" | "Lava" | "Frost"
	GroundA: Color3,
	GroundB: Color3,
	Wall: Color3,
	WallCap: Color3,
	Border: Color3,
	Guardian: Guardian,
}

local list: { Biome } = {
	{
		Id = "PebblePlains",
		Order = 1,
		DisplayName = "Pebble Plains",
		RecommendedSpeed = 16,
		Length = 120,
		NestAt = 0.4,
		Decor = "Plains",
		GroundA = hex("63D93C"),
		GroundB = hex("55CB30"),
		Wall = hex("C98A4B"),
		WallCap = hex("4FC22A"),
		Border = hex("B9EF8F"),
		Guardian = {
			WalkSpeed = 20,
			ReturnSpeed = 10,
			WakeDelay = 0.6,
			CatchDistance = 7,
			DetectionRadius = 45,
			MaxChaseSeconds = 15,
			Knockback = 70,
			Scale = 1,
		},
	},
	{
		Id = "LavaLagoon",
		Order = 2,
		DisplayName = "Lava Lagoon",
		RecommendedSpeed = 28,
		Length = 140,
		NestAt = 0.55,
		Decor = "Lava",
		GroundA = hex("F2C46B"),
		GroundB = hex("E8B456"),
		Wall = hex("D9A35C"),
		WallCap = hex("6B4A3A"),
		Border = hex("FFE2A8"),
		Guardian = {
			WalkSpeed = 32,
			ReturnSpeed = 14,
			WakeDelay = 0.6,
			CatchDistance = 8,
			DetectionRadius = 55,
			MaxChaseSeconds = 15,
			Knockback = 80,
			Scale = 1.15,
		},
	},
	{
		Id = "FrostfangPeaks",
		Order = 3,
		DisplayName = "Frostfang Peaks",
		RecommendedSpeed = 40,
		Length = 160,
		NestAt = 0.55,
		Decor = "Frost",
		GroundA = hex("F4FAFF"),
		GroundB = hex("E0EEFA"),
		Wall = hex("9CB8D6"),
		WallCap = hex("FFFFFF"),
		Border = hex("BFE6FF"),
		Guardian = {
			WalkSpeed = 44,
			ReturnSpeed = 18,
			WakeDelay = 0.6,
			CatchDistance = 9,
			DetectionRadius = 65,
			MaxChaseSeconds = 15,
			Knockback = 90,
			Scale = 1.3,
		},
	},
}

local byId: { [string]: Biome } = {}
for _, biome in list do
	table.freeze(biome.Guardian)
	byId[biome.Id] = table.freeze(biome)
end

return table.freeze({
	List = table.freeze(list),
	ById = table.freeze(byId),
})
