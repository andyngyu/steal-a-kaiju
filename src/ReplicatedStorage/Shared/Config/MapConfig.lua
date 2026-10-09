--!strict
-- Greybox layout, in studs. The map runs along +X: spawn plaza -> main road lined with plots -> biome lane.
-- After changing values, rebuild in Studio's command bar:
--   require(game.ServerStorage.Tools.MapBuilder:Clone()).Build()
return table.freeze({
	StartingWalkSpeed = 16, -- Roblox default; SpeedService takes over in Phase 4

	SpawnPlaza = table.freeze({
		Size = 56,
		Color = Color3.fromHex("FFF4D6"),
	}),

	Road = table.freeze({
		Width = 28,
		Color = Color3.fromHex("7A7F8C"),
	}),

	Plots = table.freeze({
		PerSide = 3, -- 2 sides, so 6 plots
		Width = 36, -- along the road
		Depth = 44, -- away from the road
		Gap = 6, -- between neighbouring plots
		FirstOffset = 6, -- from the plaza edge to the first plot
		Setback = 4, -- from the road edge to the plot front
		FloorHeight = 0.6,
		WallHeight = 4,
		NestPads = table.freeze({ Columns = 4, Rows = 2, Size = 6, Spacing = 8 }),
		Colors = table.freeze({
			Color3.fromHex("FF4D5E"),
			Color3.fromHex("3FA9FF"),
			Color3.fromHex("FFD23F"),
			Color3.fromHex("B05CFF"),
			Color3.fromHex("FF8A1F"),
			Color3.fromHex("2FD3B5"),
		}),
	}),

	Treadmill = table.freeze({
		Size = Vector3.new(10, 1, 24),
	}),

	Lane = table.freeze({
		GapAfterPlots = 8, -- road length between the last plot and the lane entrance
		Width = 72,
		SideWallHeight = 18,
		CrossWallHeight = 30,
		WallThickness = 4,
		GateWidth = 28,
		NestRadius = 10,
		EggSpawnsPerNest = 6,
	}),

	BoundaryMargin = 24, -- open ground around the playable area
	StudTexture = "rbxassetid://6372755229",
})
