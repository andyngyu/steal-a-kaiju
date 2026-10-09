-- Player auras (StarterPlayerScripts.Gameplay.AuraFX): every trail (TrailConfig id) gives its wearer an aura in that
-- trail's own theme. It idles quietly while you move and powers up when you stand still ("aura farming"), with a burst
-- when it reaches full power.
--   PebbleDust     dust haze, pebbles levitating off the ground
--   JungleLeaf     forest-green flames with lime tongues, leaves whirling round the body, fireflies
--   FrostBreath    white-ice flame tongues, frost mist pooling at the feet, ice shards, snowfall, frost rings, a
--                  frosted body
--   VoidPlasma     a dark vortex underfoot, deep purple flames, plasma orbs, void motes pulled into the body,
--                  crescents, stars
--   ThunderGold    storm-cloud flames with gold tongues, rising energy lines, lightning bolts, sparks, crackle,
--                  shockwaves
--   MagmaRoar      dark red flames with roaring fire tongues, embers, a lava swirl underfoot, shockwaves, a charred body
--   PrismRainbow   rainbow flame tongues, prism sparkles, light rays, crescents, shockwaves (every colour cycles)
--   ShadowMonarch  Sung Jin-Woo: black shadow flames, blue flame tongues, glowing eyes, a dark silhouette, smoke pool,
--                  ground swirl, energy lines, crackle, crescents, shockwaves
-- Daylight rule: dark backdrop flames behind + bright additive tongues in front read on any background; pale additive
-- colours on their own disappear against the bright grass.
-- Style fields:
--   Tier       1-8: scales the light; from 3 the outline also shows (faintly) while moving
--   Glow       energy colour: outline, light, ribbons and the "Glow" layers
--   Back       backdrop flame colours ("Dark" layers; default: a near-black shade of Glow)
--   Tongue     flame tongue colours, hot core outwards ("Flame" layers; default: light / Glow / deep shades of Glow)
--   Colors     colours for "Trail" layers (default: the trail's Colors)
--   Layers     AuraFX recipe names, drawn in this order (see RECIPES in AuraFX)
--   Rates      optional { [recipe] = { moving, farming } } overrides
--   Outline    false, or { Fill = "Dark" | "Light" | nil, FillMax = body tint transparency at full power }
--   Eyes       glowing eye slits while farming
--   Ribbons    { moving, farming }: energy streaks spiralling round the body
--   Rainbow    every colour cycles through the rainbow (the trail itself too)
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

-- White VFX textures (tinted per aura), from free Creator Store kits: Axoie's Auras (by louthebeast2019, "free to
-- use") and "Lighting aura vfx" (lightning flipbook). Swap any id here to restyle every aura that uses it.
AuraConfig.Textures = {
	Blob = "rbxassetid://1084962479", -- soft white disc: glowing flame tongues, plasma orbs
	Wisp = "rbxassetid://7216854921", -- smoky wisp: icy vapour, nature wisps
	Smoke = "rbxassetid://1525327413", -- cloudy puff: smoke pool, dust
	Crackle = "rbxassetid://7216850580", -- electric crackle round the body
	Streak = "rbxassetid://12363818232", -- thin rising energy line
	Crescent = "rbxassetid://12402878232", -- crescent swirl round the body
	Swirl = "rbxassetid://5726444189", -- spiral on the ground
	Ring = "rbxassetid://8084911316", -- thin ring: shockwaves, frost rings
	Lightning = "rbxassetid://11564576961", -- 4x4 lightning flipbook
}

AuraConfig.Styles = {
	PebbleDust = {
		Tier = 1,
		Glow = "D8D2C4",
		Layers = { "Dust", "Pebbles" },
		Outline = false,
		Ribbons = { 0, 0 },
	},
	JungleLeaf = {
		Tier = 2,
		Glow = "5CFF52",
		Back = { "2C6E1E", "0E2A0A" },
		Tongue = { "E6FFB0", "7CFF4A", "2FC22A" },
		Layers = { "Backdrop", "Tongues", "Leaves", "Fireflies" },
		Rates = { Backdrop = { 2, 12 }, Tongues = { 4, 24 } },
		Outline = {},
		Ribbons = { 0, 1 },
	},
	FrostBreath = {
		Tier = 3,
		Glow = "7FD0FF",
		Tongue = { "FFFFFF", "9FE6FF", "3DA8FF" },
		Layers = { "FrostMist", "Tongues", "IceShards", "Snowfall", "FrostRing" },
		Rates = { Tongues = { 6, 40 } },
		Outline = { Fill = "Light", FillMax = 0.72 },
		Ribbons = { 0, 2 },
	},
	VoidPlasma = {
		Tier = 4,
		Glow = "B05CFF",
		Back = { "3A0F6E", "0E0320" },
		Layers = { "VoidVortex", "Backdrop", "PlasmaOrbs", "VoidMotes", "Crescents", "Stars" },
		Rates = { Backdrop = { 3, 18 } },
		Outline = { Fill = "Dark", FillMax = 0.55 },
		Ribbons = { 0, 2 },
	},
	ThunderGold = {
		Tier = 5,
		Glow = "FFD23F",
		Back = { "2A2F44", "0A0C14" },
		Tongue = { "FFFFFF", "FFE24A", "FFA000" },
		Layers = { "Backdrop", "Tongues", "EnergyLines", "Lightning", "Sparks", "Crackle", "Shockwave" },
		Rates = { Backdrop = { 3, 16 }, Tongues = { 4, 22 } },
		Outline = { Fill = "Light", FillMax = 0.8 },
		Ribbons = { 1, 3 },
	},
	MagmaRoar = {
		Tier = 6,
		Glow = "FF6A1F",
		Back = { "7A1408", "2A0602" },
		Tongue = { "FFF2A0", "FFB21F", "FF5A1F" },
		Colors = { "FFF2A0", "FFB21F", "FF5A1F", "B8200F" },
		Layers = { "Backdrop", "Tongues", "Embers", "LavaSwirl", "Shockwave" },
		Outline = { Fill = "Dark", FillMax = 0.62 },
		Ribbons = { 1, 3 },
	},
	PrismRainbow = {
		Tier = 7,
		Glow = "FF8AE0",
		Layers = { "Tongues", "Prisms", "LightRays", "Crescents", "Shockwave" },
		Outline = { Fill = "Light", FillMax = 0.75 },
		Ribbons = { 2, 4 },
		Rainbow = true,
	},
	ShadowMonarch = {
		Tier = 8,
		Glow = "3D8BFF",
		Layers = { "Backdrop", "SmokePool", "Tongues", "GroundSwirl", "EnergyLines", "Crackle", "Crescents", "Shockwave" },
		Outline = { Fill = "Dark", FillMax = 0.45 },
		Eyes = true,
		Ribbons = { 1, 3 },
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
