--!strict
-- Personal treadmills: one per base. Level 0 = locked (a hologram shows where it will go). Buying Level 1 unlocks it.
-- While a player runs on their treadmill they earn Speed (a currency, no limit): GainPerSecond x the level's Multiplier
-- x their trail's SpeedMultiplier, every second. Each level doubles the gain.
local hex = Color3.fromHex

export type Theme = {
	Frame: Color3,
	Trim: Color3,
	Belt: Color3,
	Chevron: Color3,
	Screen: Color3,
	NeonTrim: boolean, -- glowing side strips
	Sparkles: boolean,
	Fire: boolean,
	Plates: boolean, -- glowing kaiju plates on the console
}

export type Level = {
	Name: string,
	Cost: number,
	Multiplier: number, -- Speed gain multiplier (each level doubles it)
	BeltSpeed: number, -- visual belt speed while running (studs/s)
	RunAnimSpeed: number, -- run animation playback speed
	Theme: Theme,
}

local levels: { Level } = {
	{
		Name = "Rookie", Cost = 1000, Multiplier = 1, BeltSpeed = 8, RunAnimSpeed = 1.1,
		Theme = { Frame = hex("2B2D3A"), Trim = hex("C9CED8"), Belt = hex("1C1C24"), Chevron = hex("8A90A0"), Screen = hex("6BE04A"), NeonTrim = false, Sparkles = false, Fire = false, Plates = false },
	},
	{
		Name = "Sporty", Cost = 25000, Multiplier = 2, BeltSpeed = 11, RunAnimSpeed = 1.25,
		Theme = { Frame = hex("1F2A44"), Trim = hex("3FA9FF"), Belt = hex("141A2B"), Chevron = hex("3FA9FF"), Screen = hex("3FA9FF"), NeonTrim = true, Sparkles = false, Fire = false, Plates = false },
	},
	{
		Name = "Golden", Cost = 100000, Multiplier = 4, BeltSpeed = 14, RunAnimSpeed = 1.4,
		Theme = { Frame = hex("1A1A1F"), Trim = hex("FFC93C"), Belt = hex("222226"), Chevron = hex("FFE27A"), Screen = hex("FFC93C"), NeonTrim = true, Sparkles = true, Fire = false, Plates = false },
	},
	{
		Name = "Blaze", Cost = 400000, Multiplier = 8, BeltSpeed = 17, RunAnimSpeed = 1.55,
		Theme = { Frame = hex("2A1414"), Trim = hex("FF8A1F"), Belt = hex("1E1010"), Chevron = hex("FF5A1F"), Screen = hex("FF8A1F"), NeonTrim = true, Sparkles = true, Fire = true, Plates = false },
	},
	{
		Name = "Kaiju", Cost = 1500000, Multiplier = 16, BeltSpeed = 20, RunAnimSpeed = 1.7,
		Theme = { Frame = hex("1A1033"), Trim = hex("B05CFF"), Belt = hex("120A26"), Chevron = hex("6BE04A"), Screen = hex("6BE04A"), NeonTrim = true, Sparkles = true, Fire = false, Plates = true },
	},
}

for _, l in levels do
	table.freeze(l.Theme)
	table.freeze(l)
end

return table.freeze({
	Levels = table.freeze(levels),
	GainPerSecond = 100, -- Speed per second on a x1 treadmill with no trail bonus
	CheckInterval = 0.5, -- training tick
	RunPromptDistance = 9,

	-- Lightning bolt (TreadmillService + KaijuUI TreadmillLightningController): while running, a bolt pops up on screen
	-- every LightningEverySeconds; clicking it within LightningWindowSeconds multiplies Speed gains by LightningBoost
	-- for LightningBoostSeconds. The next bolt comes LightningEverySeconds after this one is clicked or missed.
	LightningEverySeconds = 20,
	LightningWindowSeconds = 6,
	LightningBoost = 4,
	LightningBoostSeconds = 5,
	LightningAnimMultiplier = 1.8, -- run animation + belt play this much faster during the boost (Gameplay.SpeedFX)

	-- client VFX pacing
	PopupEveryTicks = 4, -- one "+Speed" popup (and ground ring) per this many training ticks, showing the total
})
