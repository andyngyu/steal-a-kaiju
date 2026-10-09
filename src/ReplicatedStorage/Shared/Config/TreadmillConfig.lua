--!strict
-- Personal treadmills: one per base. Level 0 = locked (a hologram shows where it will go). Buying Level 1 unlocks it.
-- While a player runs on their treadmill they gain SpeedPerSecond until the treadmill bonus reaches MaxTrained.
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
	SpeedPerSecond: number,
	MaxTrained: number,
	BeltSpeed: number, -- visual belt speed while running (studs/s)
	RunAnimSpeed: number, -- run animation playback speed
	Theme: Theme,
}

local levels: { Level } = {
	{
		Name = "Rookie", Cost = 5000, SpeedPerSecond = 0.15, MaxTrained = 10, BeltSpeed = 8, RunAnimSpeed = 1.1,
		Theme = { Frame = hex("2B2D3A"), Trim = hex("C9CED8"), Belt = hex("1C1C24"), Chevron = hex("8A90A0"), Screen = hex("6BE04A"), NeonTrim = false, Sparkles = false, Fire = false, Plates = false },
	},
	{
		Name = "Sporty", Cost = 25000, SpeedPerSecond = 0.25, MaxTrained = 18, BeltSpeed = 11, RunAnimSpeed = 1.25,
		Theme = { Frame = hex("1F2A44"), Trim = hex("3FA9FF"), Belt = hex("141A2B"), Chevron = hex("3FA9FF"), Screen = hex("3FA9FF"), NeonTrim = true, Sparkles = false, Fire = false, Plates = false },
	},
	{
		Name = "Golden", Cost = 100000, SpeedPerSecond = 0.4, MaxTrained = 26, BeltSpeed = 14, RunAnimSpeed = 1.4,
		Theme = { Frame = hex("1A1A1F"), Trim = hex("FFC93C"), Belt = hex("222226"), Chevron = hex("FFE27A"), Screen = hex("FFC93C"), NeonTrim = true, Sparkles = true, Fire = false, Plates = false },
	},
	{
		Name = "Blaze", Cost = 400000, SpeedPerSecond = 0.6, MaxTrained = 34, BeltSpeed = 17, RunAnimSpeed = 1.55,
		Theme = { Frame = hex("2A1414"), Trim = hex("FF8A1F"), Belt = hex("1E1010"), Chevron = hex("FF5A1F"), Screen = hex("FF8A1F"), NeonTrim = true, Sparkles = true, Fire = true, Plates = false },
	},
	{
		Name = "Kaiju", Cost = 1500000, SpeedPerSecond = 0.9, MaxTrained = 42, BeltSpeed = 20, RunAnimSpeed = 1.7,
		Theme = { Frame = hex("1A1033"), Trim = hex("B05CFF"), Belt = hex("120A26"), Chevron = hex("6BE04A"), Screen = hex("6BE04A"), NeonTrim = true, Sparkles = true, Fire = false, Plates = true },
	},
}

for _, l in levels do
	table.freeze(l.Theme)
	table.freeze(l)
end

return table.freeze({
	Levels = table.freeze(levels),
	CheckInterval = 0.5, -- training tick
	RunPromptDistance = 9,
})
