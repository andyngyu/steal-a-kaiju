-- Player auras (StarterPlayerScripts.Gameplay.AuraFX): every trail (TrailConfig id) gives its wearer a matching aura in
-- the Sung Jin-Woo / Shadow Monarch style - dark smoky flames behind the body rimmed with glowing flames in the trail's
-- colour, crackling energy, rising energy lines, glowing eyes. It idles quietly while you move and powers up when you
-- stand still ("aura farming").
-- Layers by tier: glowing flames (all), shadow flames + rising lines + glowing eyes (2+), outline + crackle + ground
-- swirl + smoke pool (3+), spinning crescents (4+), shockwave rings (5+).
-- Style fields (anything missing comes from the trail itself):
--   Tier           1-7 (default: the trail's rarity order)
--   Colors         glowing flame colours from the hot core outwards (default: the trail's Colors)
--   Glow           outline, energy and light colour (default: the trail's Color); the shadow flames are a very dark
--                  shade of it
--   Flames         { moving, farming }: glowing flames per second over the whole body; FlameSize scales them
--   Shadow         { moving, farming }: dark shadow flames per second
--   Smoke          soft smoke wisps instead of fire
--   LightEmission  1 = glowing fire; lower keeps dark colours dark (void)
--   Ribbons        energy streaks spiralling round the body while farming; RibbonsMoving while moving
--   Extra          "Dust" | "Leaves" | "Snow" | "Void" | "Lightning" | "Embers" | "Sparkles"
--   Rainbow        every colour cycles through the rainbow
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local EggConfig = require(Config:WaitForChild("EggConfig"))

local AuraConfig = {}

AuraConfig.Farm = {
	StillSpeed = 1.5, -- studs/s: slower than this counts as standing still
	Delay = 0.8, -- seconds still before the aura starts powering up
	RampSeconds = 1.4, -- seconds to reach full power
}
AuraConfig.Range = 150 -- auras further than this from the camera go quiet
AuraConfig.MaxOutlines = 5 -- outlines are Highlights; Roblox draws at most 31 at once and kaiju use some too
AuraConfig.ReducedScale = 0.35 -- particle rates with the Reduced Effects setting

-- White VFX textures (tinted per trail), from free Creator Store kits: Axoie's Auras (by louthebeast2019, "free to
-- use") and "Lighting aura vfx" (lightning flipbook). Swap any id here to restyle every aura.
AuraConfig.Textures = {
	Wisp = "rbxassetid://7216854921", -- smoky flame wisp: shadow flames
	Flame = "rbxassetid://7216855238", -- flame tongue with a bright core: glowing flames
	Smoke = "rbxassetid://1525327413", -- cloudy puff: smoke pool at the feet
	Crackle = "rbxassetid://7216850580", -- electric crackle round the body
	Streak = "rbxassetid://12363818232", -- thin rising energy line
	Crescent = "rbxassetid://12402878232", -- crescent swirl round the body
	Swirl = "rbxassetid://5726444189", -- spiral on the ground
	Ring = "rbxassetid://8084911316", -- thin ring: shockwaves
	Flare = "rbxassetid://1454292685", -- star flare: glowing eyes
	Lightning = "rbxassetid://11564576961", -- 4x4 lightning flipbook
}

AuraConfig.Styles = {
	PebbleDust = { Tier = 1, Flames = { 0, 16 }, FlameSize = 0.9, Smoke = true, Extra = "Dust" },
	JungleLeaf = { Tier = 2, Flames = { 6, 28 }, Ribbons = 1, Extra = "Leaves" },
	FrostBreath = { Tier = 3, Flames = { 10, 36 }, Ribbons = 2, Extra = "Snow" },
	VoidPlasma = {
		Tier = 4,
		Flames = { 12, 42 },
		Ribbons = 2,
		Extra = "Void",
		Colors = { "F0C8FF", "B05CFF", "5A1FB8", "1A0638" },
		LightEmission = 0.45,
	},
	ThunderGold = { Tier = 5, Flames = { 14, 46 }, Ribbons = 3, RibbonsMoving = 1, Extra = "Lightning" },
	MagmaRoar = {
		Tier = 6,
		Flames = { 18, 58 },
		FlameSize = 1.25,
		Ribbons = 3,
		RibbonsMoving = 1,
		Extra = "Embers",
		Colors = { "FFF2A0", "FFB21F", "FF5A1F", "B8200F" },
	},
	PrismRainbow = { Tier = 7, Flames = { 18, 62 }, FlameSize = 1.15, Ribbons = 4, RibbonsMoving = 2, Extra = "Sparkles", Rainbow = true },
}

local function color(c)
	return typeof(c) == "Color3" and c or Color3.fromHex(c)
end

-- The full style for a TrailConfig entry: its Styles entry with the gaps filled from the trail (colours, tier from
-- rarity), or one built from the trail alone for a trail that has no entry yet.
function AuraConfig.ForTrail(trail)
	local base = AuraConfig.Styles[trail.Id] or {}
	local rarity = EggConfig.RarityById[trail.Rarity or ""]
	local tier = base.Tier or (rarity and rarity.Order) or 1
	local style = {}
	for k, v in base do
		style[k] = v
	end
	style.Tier = tier
	style.Flames = base.Flames or { tier * 2, 12 + tier * 7 }
	style.Shadow = base.Shadow or { tier * 1.5, 8 + tier * 4 }
	style.Ribbons = base.Ribbons or (tier >= 2 and math.min(4, math.ceil(tier / 2)) or 0)
	style.RibbonsMoving = base.RibbonsMoving or 0
	style.FlameSize = base.FlameSize or 1
	style.LightEmission = base.LightEmission or 1
	local colors = {}
	for _, c in base.Colors or trail.Colors or { trail.Color or "FFFFFF" } do
		table.insert(colors, color(c))
	end
	style.Colors = colors
	style.Glow = color(base.Glow or trail.Color or colors[math.min(2, #colors)])
	return style
end

return AuraConfig
