-- AuraConfig: the player aura that comes with each trail (drawn by StarterPlayerScripts.Gameplay.AuraFX).
-- Remade from scratch on 16 Oct 2026. Auras are built from EFFECTS, not pictures:
--   particles using Roblox's own fire / smoke / spark / sparkle textures, glowing 3D pieces that float round you
--   (rocks, ice crystals, plasma orbs, prism shards), procedural lightning, spiralling energy ribbons, a light and an
--   outline. Nothing is drawn flat on the ground and there are no big flat images. Only three small themed textures
--   are used (leaves, snowflakes, butterflies).
-- Auras idle quietly while you move and power up while you stand still ("aura farming"), with a burst at full power.
-- The old auras are backed up in ServerStorage.Backups.Auras_BeforeRemake_2026-10-16.
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

-- the only image textures auras use (small themed particles)
local function id(n)
	return "rbxassetid://" .. n
end
AuraConfig.Textures = {
	Leaf = id(122342824323639), -- veined leaf
	Snowflake = id(86390398432271), -- six-point snowflake
	Butterfly = id(104124430420287), -- 4x4 butterfly flapping flipbook
	Star = id(14198353638), -- small 4-point twinkle
}

--[[ Each style is a list of Elements, drawn in order. Rates are { moving, farming } particles per second; Count is
{ moving, farming } pieces. Colours: a hex string, a list of hex strings (a gradient), or a palette word -
"Glow" (the style's Glow), "Light", "Deep", "Dark", "White", "Rainbow" (cycles; only in Rainbow styles).
  Smoke    smoke rising from your feet           Color, Dark (non-glowing), Alpha, Size, Rise, Rate
  Flames   fire licking off your body            Color (hot -> cool), Size, Brightness, Rate (per body part)
  Embers   spark streaks shooting up off you     Color, Size, Rate
  Motes    glowing dust drifting round you       Color, Size, Rate
  Glints   little white star twinkles            Rate
  Drift    themed particles swirling or falling  Texture (Leaf / Snowflake / Butterfly), Color, Glow, Fall, Size, Rate
  Drips    hot drops running off you             Color, Rate
  Chips    gravel kicked up from your feet       Color, Rate
  Cloud    dark puffs gathering over your head   Color, Rate
  Pieces   3D pieces floating round you          Shape (Rock / Crystal / Orb / Shard), Count, Color, Material,
                                                 Core (a glowing inner colour for rocks), Size, Radius, Speed, Bob,
                                                 Height, Lift (rise while farming), Spin, Trail (a light streak)
  Ribbons  energy streaks spiralling round you   Count, Color
  Arcs     lightning crackling round your body   Color, Every = { moving, farming } seconds (nil = never), Width,
                                                 Length, Bolts
  Strike   a bolt from the sky                   Color, Every (seconds while farming; it also strikes on power-up)
Style fields: Tier (1-8, scales the light), Glow, Rainbow, Outline (false or { Fill = "Dark" | "Light", FillMax }),
Elements. A trail with no style gets embers, motes and ribbons in its own colour. ]]
AuraConfig.Styles = {
	PebbleDust = {
		Tier = 1,
		Glow = "D8D2C4",
		Outline = false,
		Elements = {
			{ Type = "Smoke", Color = { "E6DAC0", "A89A7C" }, Dark = true, Alpha = 0.5, Rate = { 2, 9 } },
			{ Type = "Chips", Color = { "8A7A62", "5E5244" }, Rate = { 1, 8 } },
			{ Type = "Pieces", Shape = "Rock", Count = { 0, 5 }, Color = "7A6A58", Material = "Slate", Size = 1,
				Radius = 2.1, Speed = 0.6, Bob = 0.25, Height = -0.4, Lift = 1.3, Spin = 0.6 },
			{ Type = "Motes", Color = { "FFF2D6", "D8C9A8" }, Size = 0.8, Rate = { 0, 8 } },
		},
	},
	JungleLeaf = {
		Tier = 2,
		Glow = "5CFF52",
		Outline = {},
		Elements = {
			{ Type = "Drift", Texture = "Leaf", Color = { "8CFF6A", "3FBF3A" }, Size = 1, Rate = { 1, 9 } },
			{ Type = "Motes", Color = { "F4FF9A", "8CFF6A" }, Size = 1.1, Rate = { 2, 14 } },
			{ Type = "Drift", Texture = "Butterfly", Color = "White", Size = 1.3, Rate = { 0, 1.2 } },
			{ Type = "Embers", Color = { "E8FFB0", "5CFF52" }, Size = 0.8, Rate = { 0, 12 } },
			{ Type = "Ribbons", Count = { 0, 2 }, Color = { "C8FF9A", "5CFF52" } },
		},
	},
	FrostBreath = {
		Tier = 3,
		Glow = "7FD0FF",
		Outline = { Fill = "Light", FillMax = 0.72 },
		Elements = {
			{ Type = "Smoke", Color = { "FFFFFF", "DFF4FF" }, Alpha = 0.6, Rise = 0.5, Rate = { 2, 8 } },
			{ Type = "Pieces", Shape = "Crystal", Count = { 0, 6 }, Color = "BFEFFF", Size = 1, Radius = 1.9, Speed = 0.9,
				Bob = 0.3, Height = 0, Lift = 0.6, Spin = 1 },
			{ Type = "Drift", Texture = "Snowflake", Color = { "FFFFFF", "BFEFFF" }, Glow = true, Fall = true, Size = 0.8,
				Rate = { 2, 10 } },
			{ Type = "Motes", Color = { "FFFFFF", "BFEFFF" }, Size = 0.8, Rate = { 3, 20 } },
			{ Type = "Glints", Rate = { 1, 10 } },
			{ Type = "Embers", Color = { "FFFFFF", "7FD0FF" }, Size = 0.8, Rate = { 0, 16 } },
		},
	},
	VoidPlasma = {
		Tier = 4,
		Glow = "B05CFF",
		Outline = { Fill = "Dark", FillMax = 0.55 },
		Elements = {
			{ Type = "Smoke", Color = { "3A0F6E", "0E0320" }, Dark = true, Alpha = 0.45, Size = 1.1, Rate = { 2, 10 } },
			{ Type = "Pieces", Shape = "Orb", Count = { 1, 4 }, Color = "D9A8FF", Size = 1, Radius = 1.8, Speed = 1.6,
				Bob = 0.6, Height = 0.2, Lift = 0.3, Trail = true },
			{ Type = "Arcs", Color = { "F0D8FF", "B05CFF" }, Every = { nil, 0.45 }, Width = 0.12, Length = 2.2 },
			{ Type = "Embers", Color = { "F0D8FF", "B05CFF" }, Rate = { 2, 26 } },
			{ Type = "Motes", Color = { "E6CCFF", "8A3DFF" }, Rate = { 3, 18 } },
		},
	},
	ThunderGold = {
		Tier = 5,
		Glow = "FFD23F",
		Outline = { Fill = "Light", FillMax = 0.8 },
		Elements = {
			{ Type = "Cloud", Color = { "5A6078", "2A2F44" }, Rate = { 0, 8 } },
			{ Type = "Flames", Color = { "FFF6C0", "FFD23F", "FF9E1F" }, Size = 1, Rate = { 0.5, 6 } },
			{ Type = "Arcs", Color = { "FFFFFF", "FFE45A" }, Every = { 1.2, 0.22 }, Width = 0.14, Length = 2.6, Bolts = 3 },
			{ Type = "Strike", Color = { "FFFFFF", "FFE45A" }, Every = 2.6 },
			{ Type = "Embers", Color = { "FFF6C0", "FFC21F" }, Rate = { 4, 34 } },
			{ Type = "Ribbons", Count = { 0, 2 }, Color = { "FFF6C0", "FFD23F" } },
			{ Type = "Glints", Rate = { 1, 8 } },
		},
	},
	MagmaRoar = {
		Tier = 6,
		Glow = "FF6A1F",
		Outline = { Fill = "Dark", FillMax = 0.62 },
		Elements = {
			{ Type = "Smoke", Color = { "3A1208", "120604" }, Dark = true, Alpha = 0.4, Size = 1.2, Rate = { 3, 12 } },
			{ Type = "Flames", Color = { "FFF2C0", "FF8A1F", "C42A10" }, Size = 1.2, Rate = { 2, 10 } },
			{ Type = "Pieces", Shape = "Rock", Count = { 0, 4 }, Color = "2A1610", Material = "Basalt", Core = "FF6A1F",
				Size = 0.9, Radius = 2, Speed = 0.8, Bob = 0.3, Height = -0.2, Lift = 1, Spin = 0.8 },
			{ Type = "Embers", Color = { "FFE08A", "FF6A1F" }, Rate = { 4, 34 } },
			{ Type = "Drips", Color = { "FFE08A", "FF6A1F", "B81E00" }, Rate = { 0, 6 } },
		},
	},
	PrismRainbow = {
		Tier = 7,
		Glow = "FF8AE0",
		Rainbow = true,
		Outline = { Fill = "Light", FillMax = 0.75 },
		Elements = {
			{ Type = "Pieces", Shape = "Shard", Count = { 2, 7 }, Color = "Rainbow", Size = 1, Radius = 2, Speed = 1.1,
				Bob = 0.4, Height = 0.1, Lift = 0.5, Spin = 2 },
			{ Type = "Ribbons", Count = { 1, 3 }, Color = "Rainbow" },
			{ Type = "Motes", Color = "Rainbow", Rate = { 4, 24 } },
			{ Type = "Embers", Color = "Rainbow", Rate = { 3, 28 } },
			{ Type = "Glints", Rate = { 2, 14 } },
		},
	},
	ShadowMonarch = {
		Tier = 8,
		Glow = "8A3DFF",
		Outline = { Fill = "Dark", FillMax = 0.45 },
		Elements = {
			{ Type = "Smoke", Color = { "14081F", "000000" }, Dark = true, Alpha = 0.12, Size = 1.4, Rate = { 4, 16 } },
			{ Type = "Flames", Color = { "E6D4FF", "8A3DFF", "2A1050" }, Size = 1.1, Rate = { 1, 8 } },
			{ Type = "Embers", Color = { "E6D4FF", "8A3DFF" }, Rate = { 3, 32 } },
			{ Type = "Arcs", Color = { "E6D4FF", "8A3DFF" }, Every = { nil, 0.6 }, Width = 0.1, Length = 2 },
			{ Type = "Motes", Color = { "B07CFF", "3A1A6E" }, Size = 0.9, Rate = { 0, 12 } },
			{ Type = "Ribbons", Count = { 0, 2 }, Color = { "E6D4FF", "8A3DFF" } },
		},
	},
}

local FALLBACK = {
	Outline = {},
	Elements = {
		{ Type = "Embers", Color = { "Light", "Glow" }, Rate = { 2, 22 } },
		{ Type = "Motes", Color = { "Light", "Glow" }, Rate = { 2, 14 } },
		{ Type = "Ribbons", Count = { 0, 2 }, Color = { "Light", "Glow" } },
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
