--!strict
-- Map layout, in studs. The map runs along +X: spawn plaza -> base district (plots on both sides of the path) -> safe-zone line -> biome lane.
-- After changing values, rebuild in Studio's command bar:
--   require(game.ServerStorage.Tools.MapBuilder:Clone()).Build()
local hex = Color3.fromHex

return table.freeze({
	StartingWalkSpeed = 16, -- Roblox default; SpeedService takes over in Phase 4
	TileSize = 12, -- checker tile size for ground
	DecorSeed = 7,

	Palette = table.freeze({
		GrassA = hex("63D93C"),
		GrassB = hex("55CB30"),
		PathA = hex("8FE65E"),
		PathB = hex("82DD50"),
		Dirt = hex("C98A4B"),
		DirtDark = hex("A86E38"),
		GrassCap = hex("4FC22A"),
		Wood = hex("B8682E"),
		WoodDark = hex("5E4636"),
		Cream = hex("FFF4D6"),
	}),

	SpawnPlaza = table.freeze({
		Size = 48,
		Color = hex("E8E2D0"),
	}),

	Path = table.freeze({
		Width = 32,
	}),

	Plots = table.freeze({
		PerSide = 3, -- 2 sides, so 6 plots
		Width = 56, -- along the path
		Depth = 64, -- away from the path
		Gap = 22, -- between neighbouring plots
		FirstOffset = 16, -- from the plaza edge to the first plot
		Setback = 8, -- from the path edge to the plot front
		EntranceWidth = 16, -- opening in the front fence
		FenceHeight = 3.5,
		PostSpacing = 8,
		NestPads = table.freeze({ Columns = 4, Rows = 2, Size = 8, Spacing = 12, BackInset = 10 }),
		Colors = table.freeze({
			hex("FF4D5E"),
			hex("3FA9FF"),
			hex("FFD23F"),
			hex("B05CFF"),
			hex("FF8A1F"),
			hex("2FD3B5"),
		}),
	}),

	Treadmill = table.freeze({
		Size = Vector3.new(10, 1, 24),
	}),

	Hub = table.freeze({
		Margin = 28, -- open ground between plots and the cliff wall
		WallHeight = 28,
		WallThickness = 8,
	}),

	Lane = table.freeze({
		GapAfterPlots = 14, -- path length between the last plot and the safe-zone line
		Width = 80,
		WallHeight = 34,
		WallThickness = 8,
		BorderWidth = 3, -- strip between biomes
		ClearPathWidth = 30, -- centre strip kept free of decorations
		NestRadius = 9,
		GuardianOffset = 5, -- guardian sleeps this far behind the nest edge (eggs at its feet)
		EggSpawnsPerNest = 6,
	}),

	StudTexture = "rbxassetid://6372755229",
})
