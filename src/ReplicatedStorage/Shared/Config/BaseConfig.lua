--!strict
-- Player pens: upgrade levels, dropping eggs, hatching and kaiju wandering.
-- Pen size is measured from the front fence (entrance side) inward: Width across, Depth away from the path.
-- The last level's size must fit inside MapConfig.Plots.LotWidth/LotDepth.
export type Level = { Width: number, Depth: number, Capacity: number, Cost: number }

local levels: { Level } = {
	{ Width = 40, Depth = 40, Capacity = 6, Cost = 0 },
	{ Width = 48, Depth = 50, Capacity = 9, Cost = 750 },
	{ Width = 56, Depth = 60, Capacity = 12, Cost = 7500 },
	{ Width = 64, Depth = 70, Capacity = 16, Cost = 75000 },
	{ Width = 70, Depth = 80, Capacity = 20, Cost = 750000 },
}
for _, l in levels do
	table.freeze(l)
end

return table.freeze({
	Levels = table.freeze(levels), -- Capacity = eggs + kaiju in the pen

	Drop = table.freeze({
		MaxDistance = 16, -- how far from the player a click can place an egg (further clicks are pulled in)
		Inset = 3, -- eggs stay this far inside the fence
		Spacing = 3.2, -- minimum gap between eggs in a pen
		CooldownSeconds = 0.3,
	}),

	Hatch = table.freeze({
		AnimSeconds = 1.6, -- shake + burst before the kaiju appears
		GrandAnimSeconds = 3.4, -- longer build-up for Epic+ / Huge+ hatches (EggConfig.IsGrand)
		PromptDistance = 10,
		HoldSeconds = 0.5,
	}),

	Wander = table.freeze({
		Speed = 4, -- studs per second
		MaxLeg = 18, -- longest single walk
		MinPause = 2,
		MaxPause = 6,
		Inset = 4, -- grows with the kaiju's footprint so big ones stay off the fence
		MaxSpeedScale = 1.8, -- bigger kaiju take longer strides: speed x min(sqrt(scale), this)
	}),

	IncomePopupSeconds = 3, -- "+$" popup interval over each kaiju
})
