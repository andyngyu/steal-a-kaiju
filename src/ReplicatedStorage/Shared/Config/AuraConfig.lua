-- AuraConfig: the player aura that comes with each trail (drawn by StarterPlayerScripts.Gameplay.AuraFX).
-- Remade from scratch again on 16 Oct 2026, this time with textures from the VFX Studio plugin library only.
-- Auras are layered EFFECTS: animated flipbook flames and smoke, body-aura flame sheets, lightning flashes, spinning
-- crescents, vortexes, sparks, glints, lens flares, drifting leaves and ice flecks, plus glowing 3D pieces floating
-- round you, procedural lightning, energy ribbons, a light and an outline. Nothing is drawn flat on the ground.
-- Auras idle quietly while you move and power up while you stand still ("aura farming"), with a burst at full power.
-- Older auras are backed up in ServerStorage.Backups.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local EggConfig = require(Config:WaitForChild("EggConfig"))

local AuraConfig = {}

AuraConfig.Farm = {
	StillSpeed = 1.5, -- studs/s: slower than this counts as standing still
	Delay = 0.8, -- seconds still before the aura starts powering up
	RampSeconds = 1.4, -- seconds to reach full power
}
AuraConfig.Range = 150 -- auras further than this from the camera go quiet (and fade with distance before that)
AuraConfig.MaxOutlines = 5 -- outlines are Highlights; Roblox draws at most 31 at once and kaiju use some too
AuraConfig.ReducedScale = 0.35 -- particle rates with the Reduced Effects setting

-- The texture library: every aura texture comes from the VFX Studio plugin (Textures tab). Grid = flipbook layout.
local function T(n, grid)
	return { Id = "rbxassetid://" .. n, Grid = grid }
end
AuraConfig.Textures = {
	-- smoke
	SmokePuff = T(11632052078, "Grid8x8"), -- Smoke: "Cartoony smoke" flipbook
	SmokeSoft = T(4510290214), -- Smoke: soft cloud
	SmokeBillow = T(291880914), -- Fire: puffy billow
	Wisp = T(16843373901, "Grid4x4"), -- Smoke: curling wisp
	WispBlur = T(101845528452864, "Grid4x4"), -- Energy: blurred wisp
	Dust = T(243474653), -- Smoke: dirt smudge (brown)
	-- fire
	FlameTongue = T(13504062786, "Grid2x2"), -- Fire: white flame tongue flipbook
	FlameAura = T(250186345), -- Energy: spiky body-aura flame
	FlameAura2 = T(1360388830), -- Energy: spiky body-aura flame (tall)
	FlameSoft = T(530839385), -- Energy: soft aura flame
	FireBits = T(13857087542, "Grid4x4"), -- Fire: orange flame flipbook (already coloured)
	FireBlast = T(77332357852233, "Grid2x2"), -- Fire: orange fireball flipbook (already coloured)
	-- light
	Star4 = T(12386386944), -- Flare: 4-point star
	Star4b = T(12402859532), -- Flare: sharp 4-point star
	StarSoft = T(5946093983), -- Spec: soft 4-point star
	StarThin = T(18964234996, "Grid2x2"), -- Star: thin 4-point twinkle
	Rays = T(12386392796), -- Flare: starburst rays
	LensStreak = T(3052949762), -- Flare: anamorphic lens streak
	Glow = T(12402851670), -- Spec: soft round glow
	Dot = T(12386378844), -- Spec: tiny dot
	Needle = T(5889875399), -- Spec: needle
	Diamond = T(7245988767), -- Spec: diamond / ice fleck
	SparkleDust = T(106619264450203, "Grid4x4"), -- Spec: sparkle-dust cluster
	Chroma = T(123976237730601), -- Star: 6-point star with rainbow edges (already coloured)
	-- lightning
	BoltZig = T(882168791), -- Lightning: zig-zag
	BoltBranch = T(1463939561), -- Lightning: branching bolt
	BoltBall = T(332491482), -- Lightning: ball lightning
	BoltFlash = T(12517923720, "Grid4x4"), -- Lightning: animated zig-zag
	-- slashes and swirls
	Crescent = T(12402858850), -- Slashes: crescent arc
	CrescentFlip = T(128480930120243, "Grid4x4"), -- Slashes: sweeping crescent flipbook
	Air = T(14187131206), -- Slashes: air crescent
	DarkVoid = T(243432382), -- Swirl: dark vortex
	SwirlBall = T(72827670246026), -- Swirl: swirling ball
	RainbowSwirl = T(14242380855), -- Swirl: rainbow vortex (already coloured)
	-- impacts and bits
	Flash = T(12156297119, "Grid4x4"), -- Spec: flash burst flipbook
	Burst = T(12402852980), -- Impact: star burst
	RingBurst = T(12402874202), -- Impact: radial burst
	Debris = T(15553173363, "Grid4x4"), -- Impact: rock chunks (one per frame)
	Shards = T(121986846908310), -- Swirl: shard debris
	Leaf = T(122342824323639), -- Other: veined leaf
	Bubble = T(10789587520), -- Spec: bubble
}

--[[ Each style is a list of Elements, drawn in order. Rates are { moving, farming } particles per second, Count is
{ moving, farming } pieces, Burst is how many fire on power-up. Colours: a hex string, a list of hex strings (a
gradient), or a palette word - "Glow" (the style's Glow), "Light", "Deep", "Dark", "White", "Rainbow" (cycles).

Type = "FX" is one particle layer: Preset picks the behaviour, Tex any texture above (each preset has a default).
  Backdrop  dark smoke behind the body (makes the bright layers pop)    Alpha
  Mist      smoke rising from your feet                                Alpha, Rise, Glow
  Flame     flame tongues licking up round the body
  Sheet     a big body-aura flame behind you (anime power-up aura)     Alpha
  Wisp      wisps curling up off you                                   Dark, Alpha
  Spark     streaks shooting up off you
  Glint     star twinkles on the body
  Flare     anamorphic lens streaks
  Mote      glowing dust drifting round you
  Drift     themed bits floating or falling (leaves, ice flecks)      Glow, Fall
  Bolt      lightning flashing over the body
  Slash     crescents sweeping round you                              Spin
  Vortex    a slow vortex behind you                                  Alpha, Glow
  Debris    rock chunks kicked up from your feet
  Drip      hot drops running off you
  Cloud     puffs gathering over your head
  Pop       power-up only: a flash at the centre                      (uses Burst)
  Every FX layer also takes Color, Size, Rate, Burst, LE (light emission 0-1), Brightness.
Other types:
  Pieces   3D pieces floating round you   Shape (Rock / Crystal / Orb / Shard), Count, Color, Material, Core (a glowing
                                          inner colour for rocks), Size, Radius, Speed, Bob, Height, Lift, Spin, Trail
  Ribbons  energy streaks spiralling round you   Count, Color
  Arcs     lightning crackling round your body   Color, Every = { moving, farming } seconds (nil = never), Width,
                                                 Length, Bolts
  Strike   a bolt from the sky                   Color, Every (seconds while farming; it also strikes on power-up)
Style fields: Tier (1-8, scales the light), Glow, Rainbow, Outline (false or { Fill = "Dark" | "Light", FillMax }),
Elements. A trail with no style gets sparks, motes, glints and ribbons in its own colour. ]]
AuraConfig.Styles = {
	-- Common: earthy dust, kicked-up rocks and pebbles floating round you
	PebbleDust = {
		Tier = 1,
		Glow = "D8D2C4",
		Outline = false,
		Elements = {
			{ Type = "FX", Preset = "Mist", Tex = "Dust", Color = { "FFF4DE", "C8B48E" }, Alpha = 0.35, Rate = { 3, 12 } },
			{ Type = "FX", Preset = "Mist", Tex = "SmokeBillow", Color = { "E8DCC4", "A8987A" }, Alpha = 0.55, Size = 0.8,
				Rate = { 1, 6 } },
			{ Type = "FX", Preset = "Debris", Color = { "9A8668", "6A5A46" }, Rate = { 1, 10 }, Burst = 14 },
			{ Type = "Pieces", Shape = "Rock", Count = { 0, 5 }, Color = "7A6A58", Material = "Slate", Size = 1,
				Radius = 2.1, Speed = 0.6, Bob = 0.25, Height = -0.4, Lift = 1.3, Spin = 0.6 },
			{ Type = "FX", Preset = "Mote", Tex = "Dot", Color = { "FFF2D6", "D8C9A8" }, Rate = { 0, 10 } },
			{ Type = "FX", Preset = "Pop", Tex = "RingBurst", Color = { "FFF4DE", "C8B48E" }, Size = 0.9, Burst = 1 },
		},
	},
	-- Uncommon: leaves swirling up in green wisps, fireflies and twinkles
	JungleLeaf = {
		Tier = 2,
		Glow = "5CFF52",
		Outline = {},
		Elements = {
			{ Type = "FX", Preset = "Wisp", Color = { "C8FF9A", "3FBF3A" }, Alpha = 0.35, Rate = { 1, 10 } },
			{ Type = "FX", Preset = "Drift", Tex = "Leaf", Color = { "9CFF6A", "3FBF3A" }, Size = 1.1, Rate = { 2, 12 },
				Burst = 10 },
			{ Type = "FX", Preset = "Mote", Tex = "Glow", Color = { "F4FF9A", "8CFF6A" }, Size = 1.1, Rate = { 2, 16 } },
			{ Type = "FX", Preset = "Glint", Tex = "StarSoft", Color = { "FFFFFF", "C8FF9A" }, Rate = { 1, 8 } },
			{ Type = "FX", Preset = "Spark", Color = { "E8FFB0", "5CFF52" }, Size = 0.8, Rate = { 0, 14 } },
			{ Type = "Ribbons", Count = { 0, 2 }, Color = { "C8FF9A", "5CFF52" } },
			{ Type = "FX", Preset = "Pop", Tex = "SparkleDust", Color = { "F4FF9A", "5CFF52" }, Burst = 2 },
		},
	},
	-- Rare: freezing mist, ice crystals and ice flecks, white twinkles and lens flares
	FrostBreath = {
		Tier = 3,
		Glow = "7FD0FF",
		Outline = { Fill = "Light", FillMax = 0.72 },
		Elements = {
			{ Type = "FX", Preset = "Mist", Tex = "SmokeSoft", Color = { "FFFFFF", "CFEFFF" }, Alpha = 0.45, Rise = 0.5,
				Glow = true, Rate = { 2, 10 } },
			{ Type = "FX", Preset = "Wisp", Color = { "FFFFFF", "9FDCFF" }, Alpha = 0.4, Size = 0.9, Rate = { 0, 8 } },
			{ Type = "Pieces", Shape = "Crystal", Count = { 0, 6 }, Color = "BFEFFF", Size = 1, Radius = 1.9, Speed = 0.9,
				Bob = 0.3, Height = 0, Lift = 0.6, Spin = 1 },
			{ Type = "FX", Preset = "Drift", Tex = "Diamond", Color = { "FFFFFF", "BFEFFF" }, Glow = true, Fall = true,
				Size = 0.6, Rate = { 3, 14 }, Burst = 12 },
			{ Type = "FX", Preset = "Glint", Tex = "Star4", Color = { "FFFFFF", "BFEFFF" }, Rate = { 1, 12 } },
			{ Type = "FX", Preset = "Flare", Color = { "FFFFFF", "9FDCFF" }, Rate = { 0, 1.5 }, Burst = 2 },
			{ Type = "FX", Preset = "Spark", Color = { "FFFFFF", "7FD0FF" }, Size = 0.8, Rate = { 0, 16 } },
			{ Type = "FX", Preset = "Pop", Tex = "Rays", Color = { "FFFFFF", "9FDCFF" }, Burst = 1 },
		},
	},
	-- Epic: a dark vortex behind you, plasma orbs, purple lightning
	VoidPlasma = {
		Tier = 4,
		Glow = "B05CFF",
		Outline = { Fill = "Dark", FillMax = 0.55 },
		Elements = {
			{ Type = "FX", Preset = "Vortex", Tex = "DarkVoid", Color = { "5A1F9E", "1A0638" }, Alpha = 0.35,
				Rate = { 0.6, 1.6 } },
			{ Type = "FX", Preset = "Backdrop", Color = { "3A0F6E", "0E0320" }, Alpha = 0.45, Rate = { 3, 12 } },
			{ Type = "Pieces", Shape = "Orb", Count = { 1, 4 }, Color = "D9A8FF", Size = 1, Radius = 1.8, Speed = 1.6,
				Bob = 0.6, Height = 0.2, Lift = 0.3, Trail = true },
			{ Type = "FX", Preset = "Bolt", Tex = "BoltBall", Color = { "F0D8FF", "B05CFF" }, Rate = { 0, 5 }, Burst = 4 },
			{ Type = "Arcs", Color = { "F0D8FF", "B05CFF" }, Every = { nil, 0.45 }, Width = 0.12, Length = 2.2 },
			{ Type = "FX", Preset = "Spark", Color = { "F0D8FF", "B05CFF" }, Rate = { 2, 26 } },
			{ Type = "FX", Preset = "Mote", Tex = "Glow", Color = { "E6CCFF", "8A3DFF" }, Rate = { 3, 16 } },
			{ Type = "FX", Preset = "Pop", Tex = "SwirlBall", Color = { "F0D8FF", "B05CFF" }, Burst = 1 },
		},
	},
	-- Legendary: a golden anime power-up flame, storm cloud, lightning flashes and a strike from the sky
	ThunderGold = {
		Tier = 5,
		Glow = "FFD23F",
		Outline = { Fill = "Light", FillMax = 0.8 },
		Elements = {
			{ Type = "FX", Preset = "Cloud", Color = { "5A6078", "2A2F44" }, Rate = { 0, 8 } },
			{ Type = "FX", Preset = "Sheet", Tex = "FlameAura", Color = { "FFF6C0", "FFD23F", "FF9E1F" }, Alpha = 0.3,
				Rate = { 0, 9 }, Burst = 3 },
			{ Type = "FX", Preset = "Flame", Color = { "FFF6C0", "FFD23F", "FF9E1F" }, Size = 0.9, Rate = { 3, 30 } },
			{ Type = "FX", Preset = "Bolt", Tex = "BoltFlash", Color = { "FFFFFF", "FFE45A" }, Rate = { 1, 7 }, Burst = 5 },
			{ Type = "Arcs", Color = { "FFFFFF", "FFE45A" }, Every = { 1.2, 0.22 }, Width = 0.14, Length = 2.6, Bolts = 3 },
			{ Type = "Strike", Color = { "FFFFFF", "FFE45A" }, Every = 2.6 },
			{ Type = "FX", Preset = "Spark", Color = { "FFF6C0", "FFC21F" }, Rate = { 4, 34 } },
			{ Type = "FX", Preset = "Glint", Tex = "Star4b", Color = { "FFFFFF", "FFF0A0" }, Rate = { 1, 8 } },
			{ Type = "FX", Preset = "Pop", Tex = "Flash", Color = { "FFFFFF", "FFE45A" }, Size = 1.2, Burst = 1 },
			{ Type = "FX", Preset = "Flare", Color = { "FFFFFF", "FFE45A" }, Size = 1.4, Rate = { 0, 0 }, Burst = 2 },
		},
	},
	-- Mythic: a roaring fire with black smoke, magma rocks, embers and dripping lava
	MagmaRoar = {
		Tier = 6,
		Glow = "FF6A1F",
		Outline = { Fill = "Dark", FillMax = 0.62 },
		Elements = {
			{ Type = "FX", Preset = "Backdrop", Color = { "3A1208", "120604" }, Alpha = 0.3, Size = 1.1, Rate = { 4, 14 } },
			{ Type = "FX", Preset = "Flame", Tex = "FireBits", Color = "White", Size = 1.2, LE = 0.35, Rate = { 6, 30 } },
			{ Type = "FX", Preset = "Flame", Color = { "FFF2C0", "FF8A1F", "C42A10" }, Size = 1, Rate = { 4, 24 } },
			{ Type = "Pieces", Shape = "Rock", Count = { 0, 4 }, Color = "2A1610", Material = "Basalt", Core = "FF6A1F",
				Size = 0.9, Radius = 2, Speed = 0.8, Bob = 0.3, Height = -0.2, Lift = 1, Spin = 0.8 },
			{ Type = "FX", Preset = "Spark", Color = { "FFE08A", "FF6A1F" }, Rate = { 4, 34 } },
			{ Type = "FX", Preset = "Drip", Color = { "FFE08A", "FF6A1F", "B81E00" }, Rate = { 0, 6 } },
			{ Type = "FX", Preset = "Pop", Tex = "FireBlast", Color = "White", Size = 1.1, LE = 0.4, Burst = 2 },
			{ Type = "FX", Preset = "Debris", Color = { "3A2418", "1A0E08" }, Rate = { 0, 0 }, Burst = 10 },
		},
	},
	-- Secret: rainbow prism shards, a rainbow vortex, chromatic stars and ribbons
	PrismRainbow = {
		Tier = 7,
		Glow = "FF8AE0",
		Rainbow = true,
		Outline = { Fill = "Light", FillMax = 0.75 },
		Elements = {
			{ Type = "FX", Preset = "Vortex", Tex = "RainbowSwirl", Color = "White", Alpha = 0.45, Glow = true,
				Rate = { 0, 1.4 } },
			{ Type = "Pieces", Shape = "Shard", Count = { 2, 7 }, Color = "Rainbow", Size = 1, Radius = 2, Speed = 1.1,
				Bob = 0.4, Height = 0.1, Lift = 0.5, Spin = 2 },
			{ Type = "Ribbons", Count = { 1, 3 }, Color = "Rainbow" },
			{ Type = "FX", Preset = "Glint", Tex = "Chroma", Color = "White", Size = 1.2, Rate = { 2, 12 } },
			{ Type = "FX", Preset = "Mote", Tex = "Glow", Color = "Rainbow", Rate = { 4, 22 } },
			{ Type = "FX", Preset = "Spark", Color = "Rainbow", Rate = { 3, 28 } },
			{ Type = "FX", Preset = "Flare", Color = { "FFFFFF", "FFD6F4" }, Rate = { 0, 1.2 }, Burst = 2 },
			{ Type = "FX", Preset = "Pop", Tex = "SparkleDust", Color = "Rainbow", Size = 1.2, Burst = 2 },
		},
	},
	-- Secret: a black-violet power aura with dark flames, curling shadow wisps and sweeping crescents
	ShadowMonarch = {
		Tier = 8,
		Glow = "8A3DFF",
		Outline = { Fill = "Dark", FillMax = 0.45 },
		Elements = {
			{ Type = "FX", Preset = "Backdrop", Color = { "14081F", "000000" }, Alpha = 0.2, Size = 1.25, Rate = { 5, 16 } },
			{ Type = "FX", Preset = "Sheet", Tex = "FlameAura2", Color = { "B88CFF", "6A2DDB", "2A1050" }, Alpha = 0.3,
				LE = 0.35, Rate = { 0, 8 }, Burst = 3 },
			{ Type = "FX", Preset = "Flame", Color = { "E6D4FF", "8A3DFF", "2A1050" }, Size = 1.05, Rate = { 4, 32 } },
			{ Type = "FX", Preset = "Wisp", Tex = "WispBlur", Color = { "2A1050", "000000" }, Dark = true, Alpha = 0.25,
				Rate = { 1, 10 } },
			{ Type = "FX", Preset = "Slash", Tex = "CrescentFlip", Color = { "E6D4FF", "8A3DFF" }, Rate = { 0, 2.2 }, Burst = 3 },
			{ Type = "FX", Preset = "Spark", Color = { "E6D4FF", "8A3DFF" }, Rate = { 3, 30 } },
			{ Type = "Arcs", Color = { "E6D4FF", "8A3DFF" }, Every = { nil, 0.6 }, Width = 0.1, Length = 2 },
			{ Type = "Ribbons", Count = { 0, 2 }, Color = { "E6D4FF", "8A3DFF" } },
			{ Type = "FX", Preset = "Pop", Tex = "DarkVoid", Color = { "8A3DFF", "14081F" }, Size = 1.4, LE = 0.2, Burst = 1 },
		},
	},
}

local FALLBACK = {
	Outline = {},
	Elements = {
		{ Type = "FX", Preset = "Spark", Color = { "Light", "Glow" }, Rate = { 2, 22 } },
		{ Type = "FX", Preset = "Mote", Tex = "Glow", Color = { "Light", "Glow" }, Rate = { 2, 14 } },
		{ Type = "FX", Preset = "Glint", Color = { "White", "Light" }, Rate = { 1, 6 } },
		{ Type = "Ribbons", Count = { 0, 2 }, Color = { "Light", "Glow" } },
		{ Type = "FX", Preset = "Pop", Tex = "Burst", Color = { "Light", "Glow" }, Burst = 1 },
	},
}

local function color(c)
	if typeof(c) == "Color3" then
		return c
	end
	local ok, col = pcall(Color3.fromHex, tostring(c or "FFFFFF"))
	return ok and col or Color3.new(1, 1, 1)
end

-- The aura style for a trail (the shop uses .Glow for its "+ AURA" tag).
function AuraConfig.ForTrail(trail)
	local base = AuraConfig.Styles[trail.Id] or FALLBACK
	local rarity = EggConfig.RarityById[trail.Rarity or ""]
	local style = {}
	for k, v in base do
		style[k] = v
	end
	style.Id = trail.Id
	style.Tier = style.Tier or (rarity and rarity.Order) or 1
	style.Glow = color(style.Glow or trail.Color or (trail.Colors and trail.Colors[math.min(2, #trail.Colors)]))
	return style
end

return AuraConfig
