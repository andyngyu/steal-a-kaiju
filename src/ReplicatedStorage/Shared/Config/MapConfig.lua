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
		Size = 64,
		Color = hex("E8E2D0"),
	}),

	Path = table.freeze({
		Width = 40,
	}),

	Plots = table.freeze({
		PerSide = 3, -- 2 sides, so 6 plots
		LotWidth = 70, -- space reserved per plot along the path (max pen width, see BaseConfig)
		LotDepth = 80, -- space reserved away from the path (max pen depth)
		Gap = 26, -- between neighbouring lots
		FirstOffset = 26, -- from the plaza edge to the first lot
		Setback = 14, -- from the path edge to the pen front
		EntranceWidth = 16, -- opening in the front fence
		FenceHeight = 3.5,
		PostSpacing = 8,
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
		Size = Vector3.new(14, 1, 30), -- X = belt width, Z = belt length (runs along the map's X axis)
	}),

	Hub = table.freeze({
		Margin = 36, -- open ground between lots and the cliff wall
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
