-- Player auras (StarterPlayerScripts.Gameplay.AuraFX): every trail (TrailConfig id) gives its wearer a matching aura.
-- It idles quietly while you move and powers up when you stand still ("aura farming").
-- Style fields (anything missing comes from the trail itself):
--   Tier           1-7, how much switches on: glowing outline from 3 (from 2 while farming), ground streaks from 4,
--                  ground shockwaves from 5
--   Colors         flame colours from the hot core outwards (default: the trail's Colors)
--   Glow           outline + light colour (default: the trail's Color)
--   Flames         { moving, farming }: flame wisps per second over the whole body; FlameSize scales them
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
