--!strict
-- Server-wide weather events (ServerScriptService.Services.WeatherService runs them, StarterPlayerScripts.Gameplay.
-- WeatherFX draws them, KaijuUI WeatherController shows the banner + countdown).
-- Every IntervalSeconds (random in the range) one event is picked by Weight and runs for DurationSeconds. While it runs:
--   * everyone's Luck is multiplied by Luck (LuckService source "Weather")
--   * every TickSeconds each nest egg mutates with chance NestChance and each pen egg with PenChance. Luck applies to
--     both (1 - (1 - p) ^ Luck): pen eggs use the owner's Luck, nest eggs the Luck of the luckiest player near them
--     (or the event's Luck if higher). Strikes also aim at eggs near lucky players more often. An egg keeps the first
--     mutation it gets.
--   Icon (emoji) is only a text fallback; the UI shows UIConfig.Images.Weather_<Id> / MutationConfig.Images.
--   * WeatherEggEvery: a "weather egg" - one nest egg is mutated for sure and announced to the server
--   * Strikes (Thunderstorm lightning, Meteor Shower meteors, Crystal Hail chunks) hit nest eggs and mutate them on
--     the spot, plus land around players for show (hail knocks you back a little, never off your egg)
--   * GuardianSpeed multiplies the guardians' walk / chase speed (Blizzard slower, Blood Moon faster)
-- Owner / Studio chat command: /weather <name>  (/weather stop, /weather list)
-- Workspace attributes: WeatherId, WeatherStartedAt, WeatherEndsAt (server time), NextWeatherAt, WeatherGuardianSpeed.
local WeatherConfig = {}

WeatherConfig.FirstEventSeconds = { 150, 240 } -- after the server starts
WeatherConfig.IntervalSeconds = { 900, 1200 } -- from the end of one event to the start of the next
WeatherConfig.TickSeconds = 4
WeatherConfig.PenChanceScale = 1 -- extra knob on every PenChance

WeatherConfig.Events = {
	{
		Id = "GoldenSunshower", DisplayName = "Golden Sunshower", Mutation = "Golden", Weight = 30,
		DurationSeconds = { 180, 240 }, Luck = 1.25, NestChance = 0.012, PenChance = 0.006, WeatherEggEvery = 40,
		Color = "#FFD23F", Accent = "#FFF3A6", Icon = "☀️",
		Blurb = "Golden rain is falling! Eggs can turn Golden (x1.5 income)",
	},
	{
		Id = "Thunderstorm", DisplayName = "Thunderstorm", Mutation = "Shocked", Weight = 26,
		DurationSeconds = { 180, 240 }, Luck = 1.25, NestChance = 0.008, PenChance = 0.004, WeatherEggEvery = 45,
		Strike = { Kind = "Lightning", Every = { 5, 9 }, EggChance = 0.45 },
		Color = "#5AD8FF", Accent = "#C9F6FF", Icon = "⚡",
		Blurb = "Lightning is striking the nests! Struck eggs become Shocked (x2)",
	},
	{
		Id = "Blizzard", DisplayName = "Blizzard", Mutation = "Frozen", Weight = 20,
		DurationSeconds = { 180, 240 }, Luck = 1.25, NestChance = 0.008, PenChance = 0.004, WeatherEggEvery = 45,
		GuardianSpeed = 0.85, Color = "#9FE8FF", Accent = "#F0FBFF", Icon = "❄️",
		Blurb = "A blizzard rolls in! Eggs can freeze solid (x2) and guardians slow down",
	},
	{
		Id = "MeteorShower", DisplayName = "Meteor Shower", Mutation = "Molten", Weight = 16,
		DurationSeconds = { 180, 240 }, Luck = 1.5, NestChance = 0.006, PenChance = 0.003, WeatherEggEvery = 50,
		Strike = { Kind = "Meteor", Every = { 4, 8 }, EggChance = 0.4 },
		Color = "#FF6A1F", Accent = "#FFD08A", Icon = "☄️",
		Blurb = "Meteors are falling! Eggs they hit turn Molten (x2.5)",
	},
	{
		Id = "CrystalHail", DisplayName = "Crystal Hail", Mutation = "Diamond", Weight = 12,
		DurationSeconds = { 150, 210 }, Luck = 1.5, NestChance = 0.005, PenChance = 0.0025, WeatherEggEvery = 55,
		Strike = { Kind = "Hail", Every = { 3, 6 }, EggChance = 0.3, Knockback = 38 },
		Color = "#B8F4FF", Accent = "#FFFFFF", Icon = "💎",
		Blurb = "Crystal hail! Eggs can turn to Diamond (x3) - watch your head",
	},
	{
		Id = "RainbowAurora", DisplayName = "Rainbow Aurora", Mutation = "Rainbow", Weight = 6,
		DurationSeconds = { 150, 210 }, Luck = 2, NestChance = 0.004, PenChance = 0.002, WeatherEggEvery = 60,
		Color = "#FF8AF0", Accent = "#B8FFE0", Icon = "🌈", Rainbow = true,
		Blurb = "A Rainbow Aurora lights the sky! 2x Luck - eggs can turn Rainbow (x4)",
	},
	{
		Id = "BloodMoon", DisplayName = "Blood Moon", Mutation = "Bloodmoon", Weight = 4,
		DurationSeconds = { 150, 180 }, Luck = 1.5, NestChance = 0.003, PenChance = 0.0015, WeatherEggEvery = 60,
		GuardianSpeed = 1.15, Color = "#FF1F3D", Accent = "#FF9AA6", Icon = "🩸",
		Blurb = "The Blood Moon rises... guardians are angrier, eggs can turn Bloodmoon (x5)",
	},
	{
		Id = "KaijuEclipse", DisplayName = "Kaiju Eclipse", Mutation = "Galaxy", Weight = 1,
		DurationSeconds = { 150, 180 }, Luck = 3, NestChance = 0.003, PenChance = 0.0015, WeatherEggEvery = 60,
		Color = "#9B5CFF", Accent = "#E2D1FF", Icon = "🌌", Announce = true,
		Blurb = "KAIJU ECLIPSE! 3x Luck - eggs can turn Galaxy (x8)",
	},
}

WeatherConfig.ById = {}
for _, e in WeatherConfig.Events do
	WeatherConfig.ById[e.Id] = e
end

-- Finds an event by id or (part of) its name, ignoring case and spaces: "blood", "kaijueclipse", "Meteor Shower".
function WeatherConfig.Find(text: string): any
	local q = string.lower((text:gsub("%s", "")))
	if q == "" then
		return nil
	end
	for _, e in WeatherConfig.Events do
		if string.lower(e.Id) == q or string.lower((e.DisplayName:gsub("%s", ""))) == q then
			return e
		end
	end
	for _, e in WeatherConfig.Events do
		if string.find(string.lower(e.Id), q, 1, true) or string.lower(e.Mutation) == q then
			return e
		end
	end
	return nil
end

return WeatherConfig
