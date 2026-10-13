--!strict
-- Biomes along the lane, in order from the bases outward.
-- Length is in studs along the lane. NestAt is how far into the biome the nest sits (0 = entrance, 1 = far end).
-- Guardian speeds are tuned so a player running straight at RecommendedSpeed (carry-slowed) just escapes.
local hex = Color3.fromHex

export type Guardian = {
	WalkSpeed: number, -- base chase speed (GuardianService speeds up to keep pace with faster players)
	ReturnSpeed: number, -- walking home
	WakeDelay: number, -- roar time before the chase starts
	CatchDistance: number,
	DetectionRadius: number, -- while awake, re-targets egg carriers from its nest within this range
	MaxChaseSeconds: number,
	Knockback: number, -- how hard a caught player is flung back toward the safe zone
	HaulSpeed: number?, -- dragging a dropped egg home (slow, so players can catch up and grab it back)
	-- optional chase scaling (GuardianService defaults when left out): how hard it keeps pace with the player
	TrailPace: number?, -- fraction of the player's pace once on their heels
	MaxCatchup: number?, -- most it runs above the player's pace while closing a gap (fraction of their pace)
	CatchupPerStud: number?, -- extra studs/s per stud of gap
	UnderspeedBoost: number?, -- pace multiple against a player below RecommendedSpeed
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
		Length = 150,
		NestAt = 0.4,
		Decor = "Plains",
		GroundA = hex("63D93C"),
		GroundB = hex("55CB30"),
		Wall = hex("C98A4B"),
		WallCap = hex("4FC22A"),
		Border = hex("B9EF8F"),
		Guardian = {
			WalkSpeed = 11,
			ReturnSpeed = 30,
			-- the first zone is gentle: it hangs back a little and closes gaps slowly
			TrailPace = 0.85,
			MaxCatchup = 0.1,
			CatchupPerStud = 0.35,
			UnderspeedBoost = 1.3,
			WakeDelay = 0.6,
			CatchDistance = 7,
			DetectionRadius = 45,
			MaxChaseSeconds = 15,
			Knockback = 70,
			HaulSpeed = 8,
			Scale = 1,
		},
	},
	{
		Id = "LavaLagoon",
		Order = 2,
		DisplayName = "Lava Lagoon",
		RecommendedSpeed = 51.9691, -- 25K Speed
		Length = 175,
		NestAt = 0.55,
		Decor = "Lava",
		GroundA = hex("5A4642"),
		GroundB = hex("4E3C39"),
		Wall = hex("6E4A3C"),
		WallCap = hex("2E2220"),
		Border = hex("FF8A3D"),
		Guardian = {
			WalkSpeed = 23,
			ReturnSpeed = 42,
			WakeDelay = 0.6,
			CatchDistance = 8,
			DetectionRadius = 55,
			MaxChaseSeconds = 15,
			Knockback = 80,
			HaulSpeed = 10,
			Scale = 1.15,
		},
	},
	{
		Id = "FrostfangPeaks",
		Order = 3,
		DisplayName = "Frostfang Peaks",
		RecommendedSpeed = 63.641368, -- 150K Speed
		Length = 200,
		NestAt = 0.55,
		Decor = "Frost",
		GroundA = hex("F4FAFF"),
		GroundB = hex("E0EEFA"),
		Wall = hex("A3C6E6"),
		WallCap = hex("FFFFFF"),
		Border = hex("BFE6FF"),
		Guardian = {
			WalkSpeed = 32,
			ReturnSpeed = 54,
			WakeDelay = 0.6,
			CatchDistance = 9,
			DetectionRadius = 65,
			MaxChaseSeconds = 15,
			Knockback = 90,
			HaulSpeed = 12,
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
