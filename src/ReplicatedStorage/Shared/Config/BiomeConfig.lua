--!strict
-- Biomes along the lane, in order from the bases outward.
-- Length is in studs along the lane. NestAt is how far into the biome the nest sits (0 = entrance, 1 = far end).
-- Guardian speeds are tuned so a player running straight at RecommendedSpeed (carry-slowed) just escapes.
--   All     every biome, open or locked, in lane order (the map builders lay out all of them)
--   List    the OPEN biomes only (Locked ~= true): everything at runtime walks this one (nests, guardians, zones, UI),
--           so a locked biome sits behind its "Coming Soon" gate and nothing spawns there
--   ById    every biome by id (open and locked)
-- RecommendedSpeed is a running speed: RunSpeed = 16 + 15 * log10(Speed / 100) (Shared.Config.SpeedConfig).
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
	Decor: string, -- "Plains" | "Lava" | "Frost" | "Jungle" | "Abyss" | "Storm" | "Cosmic" (art theme)
	Accent: Color3?, -- signature colour (gate trim, banners, UI)
	Locked: boolean?, -- true until the biome's kaiju exist: its gate is closed and nothing spawns there
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
		Accent = hex("86CF5F"),
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
		Accent = hex("FF6A1A"),
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
		Accent = hex("8FD8FF"),
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
	{
		Id = "VenomJungle",
		Order = 4,
		DisplayName = "Venom Jungle",
		RecommendedSpeed = 76, -- 1M Speed
		Length = 225,
		NestAt = 0.55,
		Decor = "Jungle",
		GroundA = hex("3D7B31"),
		GroundB = hex("36702B"),
		Wall = hex("5F6B4A"),
		WallCap = hex("3FA34A"),
		Border = hex("9DFF3A"),
		Accent = hex("7DFF4A"),
		Locked = true,
		Guardian = {
			WalkSpeed = 41,
			ReturnSpeed = 66,
			WakeDelay = 0.6,
			CatchDistance = 10,
			DetectionRadius = 75,
			MaxChaseSeconds = 15,
			Knockback = 100,
			HaulSpeed = 14,
			Scale = 1.45,
		},
	},
	{
		Id = "SunkenAbyss",
		Order = 5,
		DisplayName = "Sunken Abyss",
		RecommendedSpeed = 87.672, -- 6M Speed
		Length = 250,
		NestAt = 0.55,
		Decor = "Abyss",
		GroundA = hex("557780"),
		GroundB = hex("4C6C75"),
		Wall = hex("2B4F6E"),
		WallCap = hex("FF6FA8"),
		Border = hex("6FF2FF"),
		Accent = hex("6FF2FF"),
		Locked = true,
		Guardian = {
			WalkSpeed = 50,
			ReturnSpeed = 78,
			WakeDelay = 0.6,
			CatchDistance = 11,
			DetectionRadius = 85,
			MaxChaseSeconds = 15,
			Knockback = 110,
			HaulSpeed = 16,
			Scale = 1.6,
		},
	},
	{
		Id = "StormSpires",
		Order = 6,
		DisplayName = "Storm Spires",
		RecommendedSpeed = 100.031, -- 40M Speed
		Length = 275,
		NestAt = 0.55,
		Decor = "Storm",
		GroundA = hex("4B5363"),
		GroundB = hex("434B5A"),
		Wall = hex("59637A"),
		WallCap = hex("2F3644"),
		Border = hex("FFE14A"),
		Accent = hex("FFE14A"),
		Locked = true,
		Guardian = {
			WalkSpeed = 59,
			ReturnSpeed = 90,
			WakeDelay = 0.6,
			CatchDistance = 12,
			DetectionRadius = 95,
			MaxChaseSeconds = 15,
			Knockback = 120,
			HaulSpeed = 18,
			Scale = 1.75,
		},
	},
	{
		Id = "CosmicRift",
		Order = 7,
		DisplayName = "Cosmic Rift",
		RecommendedSpeed = 111.969, -- 250M Speed
		Length = 300,
		NestAt = 0.55,
		Decor = "Cosmic",
		GroundA = hex("16102A"),
		GroundB = hex("120D23"),
		Wall = hex("2A1F45"),
		WallCap = hex("B45CFF"),
		Border = hex("FF5CC8"),
		Accent = hex("B45CFF"),
		Locked = true,
		Guardian = {
			WalkSpeed = 68,
			ReturnSpeed = 102,
			WakeDelay = 0.6,
			CatchDistance = 13,
			DetectionRadius = 105,
			MaxChaseSeconds = 15,
			Knockback = 130,
			HaulSpeed = 20,
			Scale = 1.9,
		},
	},
}

local byId: { [string]: Biome } = {}
local open: { Biome } = {}
for _, biome in list do
	table.freeze(biome.Guardian)
	byId[biome.Id] = table.freeze(biome)
	if not biome.Locked then
		table.insert(open, biome)
	end
end

return table.freeze({
	All = table.freeze(list),
	List = table.freeze(open),
	ById = table.freeze(byId),
})
