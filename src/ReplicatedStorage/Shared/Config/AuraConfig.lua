-- Player auras (StarterPlayerScripts.Gameplay.AuraFX): every trail (TrailConfig id) gives its wearer an aura in that
-- trail's own theme. It idles quietly while you move and powers up when you stand still ("aura farming"), with a burst
-- when it reaches full power and a glowing sigil on the ground under you. Every aura draws its own textures - no two
-- auras share a particle image.
--   PebbleDust     rolling dust, textured rocks levitating off the ground, gravel hopping, a cracked ground
--   JungleLeaf     a whirlwind of leaves, butterflies, grass sprouting at your feet, fireflies, a laurel sigil
--   FrostBreath    an icy cloud behind you, frost mist, falling snowflakes, ice crystals, frosty breath puffs, ice rings, an ice shatter, a
--                  frozen body and a snowflake sigil
--   VoidPlasma     a spiral-galaxy portal behind you, purple void wisps, orbiting plasma orbs, dark stars pulled in,
--                  ornate moons and a void hole underfoot
--   ThunderGold    a storm cloud overhead that strikes lightning, a golden power column, lightning, crackle, energy
--                  lines, sparks, gold shockwaves, a radial lightning burst and a sun sigil
--   MagmaRoar      dark red flames, real fire flipbook flames, fire geysers, embers, a roaring shockwave, magma
--                  explosions and glowing lava cracks
--   PrismRainbow   a rainbow halo, light rays, prism orbs and stars, rainbow crescents, glass shards, a prism burst and
--                  a mandala sigil (every colour cycles)
--   ShadowMonarch  Sung Jin-Woo: a black spiky shadow aura, violet spiky flames, glowing eyes, shadow smoke and tendrils,
--                  a shadow vortex, violet lightning, crescents, the Monarch's eye and a crown sigil
-- Daylight rule: dark shapes behind + bright additive layers in front read on any background; pale additive colours on
-- their own disappear against the bright grass.
-- Style fields:
--   Tier           1-8: scales the light; from 3 the outline also shows (faintly) while moving
--   Glow           energy colour: outline, light, ribbons and the "Glow" layers
--   Back           dark backdrop colours ("Dark" layers; default: a near-black shade of Glow)
--   Tongue         flame colours, hot core outwards ("Flame" layers; default: light / Glow / deep shades of Glow)
--   Colors         colours for "Trail" layers (default: the trail's Colors)
--   Layers         AuraFX recipe names, drawn in this order (see RECIPES in AuraFX)
--   Rates          optional { [recipe] = { moving, farming } } overrides
--   Outline        false, or { Fill = "Dark" | "Light" | nil, FillMax = body tint transparency at full power }
--   Eyes           glowing eye slits while farming
--   Ribbons        { moving, farming }: energy streaks spiralling round the body
--   RibbonTexture  Textures key for the ribbons (none: a plain glow)
--   Sigil          ground decal while farming: { Texture = Textures key, Size = studs, Spin = degrees/s,
--                  Alpha = transparency at full power, Color = hex | "Glow", Brightness, Lit = lit by the sun }
--   Rainbow        every colour cycles through the rainbow (the trail itself too)
--   Plus           VFX-playbook extras: { Base = dark smoke under the feet, Circle (+ Spin, Alpha, CircleSize) = magic
--                  circle, Glitter (+ GlitterRole) = rising sparkles, Flare (+ FlareEvery) = lens-flare pops, Halo = stacked rings }
-- A trail with no entry here gets glowing flames + energy lines in its own colour.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local EggConfig = require(Config:WaitForChild("EggConfig"))

local AuraConfig = {}

AuraConfig.Farm = {
	StillSpeed = 1.5, -- studs/s: slower than this counts as standing still
	Delay = 0.8, -- seconds still before the aura starts powering up
	RampSeconds = 1.4, -- seconds to reach full power
}
AuraConfig.Range = 150 -- auras further than this from the camera go quiet (and fade out with distance before that)
AuraConfig.MaxOutlines = 5 -- outlines are Highlights; Roblox draws at most 31 at once and kaiju use some too
AuraConfig.ReducedScale = 0.35 -- particle rates with the Reduced Effects setting

-- VFX textures, mostly from the VFX Studio library (white unless noted, tinted per aura), plus Axoie's Auras (by
-- louthebeast2019, "free to use") and "Lighting aura vfx". Each aura has its own set; swap an id here to restyle it.
local function id(n)
	return "rbxassetid://" .. n
end
AuraConfig.Textures = {
	-- fallback aura (trails with no style)
	Blob = id(1084962479), -- soft white disc: flame tongues
	-- Pebble Dust
	DustCloud = id(291880914), -- billowing dust puff
	Boulders = id(13495110752), -- 4x4 sheet of outlined cartoon rocks
	Gravel = id(131917326401050), -- 2x2 sheet of shaded pebble clusters (full colour)
	Debris = id(93490537679985), -- scattered rubble bits
	GroundCrack = id(14166324267), -- dark cracked-ground decal
	-- Jungle Leaf
	Leaf = id(122342824323639), -- veined leaf
	Butterfly = id(104124430420287), -- 4x4 butterfly flapping flipbook
	Grass = id(421935851), -- grass tuft
	Firefly = id(6673021984), -- soft glow dot
	WindSwirl = id(5726444189), -- wind swirl on the ground
	Laurel = id(12402911865), -- laurel wreath sigil
	JungleRibbon = id(14684195806), -- soft lens flare
	-- Frost Breath
	FrostMist = id(4510290214), -- soft cold mist
	Snowflake = id(86390398432271), -- six-point snowflake
	IceCrystal = id(7245988767), -- diamond crystal
	Breath = id(7216854921), -- smoky wisp: frosty breath
	IceRing = id(7136551175), -- jagged frost ring
	IceShatter = id(15553173363), -- 4x4 sheet of shaded shards
	FrostSigil = id(12403143548), -- snowflake hex sigil
	FrostRibbon = id(119645012596917), -- thin bright streak
	-- Void Plasma
	VoidRift = id(12389944306), -- spiral galaxy portal
	VoidWisp = id(303195022), -- twisting wisp
	PlasmaOrb = id(14163208805), -- purple plasma orb (full colour, black background)
	DarkStar = id(72740225235951), -- black four-point star
	Moon = id(12402930237), -- ornate crescent moon
	VoidHole = id(71146205854637), -- spiky dark hole
	VoidRibbon = id(81079569898896), -- dark tear with prismatic edges
	-- Thunder Gold
	StormCloud = id(13525831027), -- cartoon cloud puff
	Bolt = id(1463939561), -- branching lightning bolt
	GoldColumn = id(530839385), -- rising aura column
	Lightning = id(11564576961), -- 4x4 lightning flipbook
	Crackle = id(7216850580), -- electric crackle
	Streak = id(12363818232), -- thin rising energy line
	Spark = id(108004780142990), -- lens-flare streak
	GoldRing = id(12386383371), -- golden shock ring (full colour)
	ThunderBurst = id(332491482), -- radial lightning burst
	SunSigil = id(12402928708), -- ornate sun sigil
	ThunderRibbon = id(12402856928), -- small bolt
	-- Magma Roar
	MagmaFire = "rbxasset://textures/particles/fire_main.dds", -- dark roiling flames
	FireFlip = id(13857087542), -- 4x4 flame flipbook (full colour)
	FirePuff = id(77332357852233), -- 2x2 sheet of fire puffs (full colour)
	Embers = "rbxasset://textures/particles/fire_sparks_main.dds",
	MagmaBurst = id(15811794808), -- magma explosion (full colour)
	RoarRing = id(12402900657), -- thick spiky shock ring
	LavaCracks = id(10365551764), -- burst of ground cracks
	MagmaRibbon = id(3052949762), -- thin flare
	-- Prism Rainbow
	RainbowHalo = id(14242380855), -- rainbow swirl ring (full colour)
	LightRays = id(12402889473), -- fan of light rays
	PrismOrb = id(14199216697), -- chromatic orb (full colour)
	PrismStar = id(14221474657), -- chromatic star (full colour)
	RainbowCrescent = id(14198091244), -- rainbow crescent (full colour, black background)
	GlassShards = id(14221378803), -- shattered glass
	PrismBurst = id(76815628297122), -- prismatic flare burst (full colour)
	PrismSigil = id(12403146281), -- mandala sigil
	PrismRibbon = id(97418539353815), -- prismatic glitter
	-- Shadow Monarch
	ShadowSpikes = id(250186345), -- spiky aura silhouette
	BlueFlame = id(1360388830), -- spiky aura flames
	ShadowSmoke = id(1525327413), -- cloudy puff
	ShadowVortex = id(243432382), -- dark swirl
	Tendril = id(16034294138), -- smoky tendrils
	ShadowBolt = id(11736666805), -- branching lightning
	Crescent = id(12402878232), -- crescent swirl
	MonarchEye = id(12403137010), -- eye in a hexagram
	CrownSigil = id(12402881551), -- spiked crown ring sigil
}

AuraConfig.Styles = {
	PebbleDust = {
		Tier = 1,
		Plus = { Base = "rbxassetid://2671910894", BaseAlpha = 0.6, Circle = "rbxassetid://93520831389146", Alpha = 0.6, Spin = 0, Glitter = "rbxassetid://12386363554" }, -- playbook extras (AuraFX plusLayers)
		Glow = "D8D2C4",
		Layers = { "DustCloud", "Boulders", "Gravel", "Debris" },
		Outline = false,
		Ribbons = { 0, 0 },
		Sigil = { Texture = "GroundCrack", Size = 6, Spin = 0, Alpha = 0.2, Color = "6B5A44", Lit = true },
	},
	JungleLeaf = {
		Tier = 2,
		Plus = { Base = "rbxassetid://12302665387", Circle = "rbxassetid://17522429817", Alpha = 0.55, Spin = 14, Glitter = "rbxassetid://90431684950883" }, -- playbook extras (AuraFX plusLayers)
		Glow = "5CFF52",
		Layers = { "WindSwirl", "Grass", "LeafWhirl", "Butterflies", "Fireflies" },
		Outline = {},
		Ribbons = { 0, 1 },
		RibbonTexture = "JungleRibbon",
		Sigil = { Texture = "Laurel", Size = 5.5, Spin = 12, Alpha = 0.2, Color = "6CFF4A", Brightness = 1.4 },
	},
	FrostBreath = {
		Tier = 3,
		Plus = { Base = "rbxassetid://883906867", Circle = "rbxassetid://7136554315", Alpha = 0.45, Spin = -12, Glitter = "rbxassetid://115439406679930", Flare = "rbxassetid://14197626379", FlareEvery = 1.2 }, -- playbook extras (AuraFX plusLayers)
		Glow = "7FD0FF",
		Layers = { "FrostBack", "FrostMist", "FrostVapor", "IceCrystals", "Snowflakes", "FrostBreathPuff", "IceRing", "IceShatter" },
		Outline = { Fill = "Light", FillMax = 0.72 },
		Ribbons = { 0, 2 },
		RibbonTexture = "FrostRibbon",
		Sigil = { Texture = "FrostSigil", Size = 6, Spin = -10, Alpha = 0.05, Color = "4FC3FF", Brightness = 2 },
	},
	VoidPlasma = {
		Tier = 4,
		Plus = { Base = "rbxassetid://14242201435", BaseAlpha = 0.35, Circle = "rbxassetid://72827670246026", Alpha = 0.4, Spin = -22, Glitter = "rbxassetid://134563328683175", Flare = "rbxassetid://105068602933805", FlareEvery = 1 }, -- playbook extras (AuraFX plusLayers)
		Glow = "B05CFF",
		Back = { "3A0F6E", "0E0320" },
		Layers = { "VoidRift", "VoidWisps", "PlasmaOrbs", "DarkStars", "Moons" },
		Outline = { Fill = "Dark", FillMax = 0.55 },
		Ribbons = { 0, 2 },
		RibbonTexture = "VoidRibbon",
		Sigil = { Texture = "VoidHole", Size = 6.5, Spin = -25, Alpha = 0.05, Color = "3A1060", Brightness = 1 },
	},
	ThunderGold = {
		Tier = 5,
		Plus = { Base = "rbxassetid://140591030585994", Circle = "rbxassetid://14186586240", Alpha = 0.35, Spin = 26, Glitter = "rbxassetid://106213021633252", Flare = "rbxassetid://14198353638", FlareEvery = 0.7 }, -- playbook extras (AuraFX plusLayers)
		Glow = "FFD23F",
		Back = { "2A2F44", "0A0C14" },
		Layers = {
			"GoldColumn", "StormCloud", "CloudBolts", "Lightning", "Crackle", "EnergyLines", "Sparks",
			"GoldRing", "ThunderBurst",
		},
		Outline = { Fill = "Light", FillMax = 0.8 },
		Ribbons = { 1, 3 },
		RibbonTexture = "ThunderRibbon",
		Sigil = { Texture = "SunSigil", Size = 6.5, Spin = 18, Alpha = 0.15, Color = "FFD23F", Brightness = 2 },
	},
	MagmaRoar = {
		Tier = 6,
		Plus = { Base = "rbxassetid://291880914", BaseAlpha = 0.4, Circle = "rbxassetid://92861858089952", Alpha = 0.3, Spin = 0, CircleSize = 7.5, Glitter = "rbxassetid://133778217916173", GlitterRole = "Flame", Flare = "rbxassetid://11425477167", FlareEvery = 0.8 }, -- playbook extras (AuraFX plusLayers)
		Glow = "FF6A1F",
		Back = { "C42A10", "5A0C04" },
		Colors = { "FFF2A0", "FFB21F", "FF5A1F", "B8200F" },
		Layers = { "MagmaBack", "FireFlames", "FireGeysers", "Embers", "RoarWave", "MagmaBurst" },
		Outline = { Fill = "Dark", FillMax = 0.62 },
		Ribbons = { 1, 3 },
		RibbonTexture = "MagmaRibbon",
		Sigil = { Texture = "LavaCracks", Size = 7.5, Spin = 0, Alpha = 0, Color = "FF8A1F", Brightness = 3 },
	},
	PrismRainbow = {
		Tier = 7,
		Plus = { Base = "rbxassetid://131828635123418", BaseAlpha = 0.55, Circle = "rbxassetid://17522428195", Alpha = 0.35, Spin = 30, Glitter = "rbxassetid://73385444872956", GlitterRole = "Trail", Flare = "rbxassetid://14969367343", FlareEvery = 0.6, Halo = "rbxassetid://7504062906" }, -- playbook extras (AuraFX plusLayers)
		Glow = "FF8AE0",
		Layers = { "LightRays", "RainbowHalo", "PrismOrbs", "PrismStars", "RainbowCrescents", "GlassShards", "PrismBurst" },
		Outline = { Fill = "Light", FillMax = 0.75 },
		Ribbons = { 2, 4 },
		RibbonTexture = "PrismRibbon",
		Sigil = { Texture = "PrismSigil", Size = 6.5, Spin = 24, Alpha = 0.15, Color = "Glow", Brightness = 1.8 },
		Rainbow = true,
	},
	ShadowMonarch = {
		Tier = 8,
		Plus = { Base = "rbxassetid://121422036988178", BaseAlpha = 0.25, Circle = "rbxassetid://90549255948014", Alpha = 0.35, Spin = -18, Glitter = "rbxassetid://94431438472232", Flare = "rbxassetid://17062454806", FlareEvery = 0.6, Halo = "rbxassetid://7136539160" }, -- playbook extras (AuraFX plusLayers)
		Glow = "8A3DFF", -- the violet of its shop picture
		Layers = {
			"ShadowSpikes", "ShadowSmoke", "ShadowVortex", "BlueFlames", "ShadowTendrils", "ShadowBolts", "Crescents",
			"MonarchEye",
		},
		Outline = { Fill = "Dark", FillMax = 0.45 },
		Eyes = false, -- glowing eye slits removed at the designer's request
		Ribbons = { 1, 3 },
		Sigil = { Texture = "CrownSigil", Size = 7, Spin = -14, Alpha = 0.1, Color = "8A3DFF", Brightness = 2 },
	},
}

local function color(c)
	return typeof(c) == "Color3" and c or Color3.fromHex(c)
end

-- The full style for a TrailConfig entry: its Styles entry with colours resolved, or a simple glowing aura in the
-- trail's own colour for a trail that has no entry yet.
function AuraConfig.ForTrail(trail)
	local base = AuraConfig.Styles[trail.Id]
	local rarity = EggConfig.RarityById[trail.Rarity or ""]
	local style = {}
	for k, v in base or { Layers = { "Tongues", "EnergyLines" }, Outline = {}, Ribbons = { 0, 2 } } do
		style[k] = v
	end
	style.Tier = style.Tier or (rarity and rarity.Order) or 1
	style.Ribbons = style.Ribbons or { 0, 0 }
	style.Rates = style.Rates or {}
	local colors = {}
	for _, c in style.Colors or trail.Colors or { trail.Color or "FFFFFF" } do
		table.insert(colors, color(c))
	end
	style.Colors = colors
	style.Glow = color(style.Glow or trail.Color or colors[math.min(2, #colors)])
	for _, key in { "Back", "Tongue" } do
		if style[key] then
			local list = {}
			for _, c in style[key] do
				table.insert(list, color(c))
			end
			style[key] = list
		end
	end
	return style
end

return AuraConfig
