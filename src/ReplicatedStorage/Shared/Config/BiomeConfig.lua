--!strict
-- Biomes along the lane, in order from the bases outward.
-- Length is in studs along the lane. NestAt is how far into the biome the nest sits (0 = entrance, 1 = far wall).
export type Biome = {
	Id: string,
	Order: number,
	DisplayName: string,
	RecommendedSpeed: number,
	Length: number,
	NestAt: number,
	GroundColor: Color3,
	WallColor: Color3,
}

local list: { Biome } = {
	{
		Id = "PebblePlains",
		Order = 1,
		DisplayName = "Pebble Plains",
		RecommendedSpeed = 16,
		Length = 110,
		NestAt = 0.4,
		GroundColor = Color3.fromHex("6BE04A"),
		WallColor = Color3.fromHex("8A9A7B"),
	},
	{
		Id = "LavaLagoon",
		Order = 2,
		DisplayName = "Lava Lagoon",
		RecommendedSpeed = 28,
		Length = 130,
		NestAt = 0.55,
		GroundColor = Color3.fromHex("FF8A1F"),
		WallColor = Color3.fromHex("6B3A2A"),
	},
	{
		Id = "FrostfangPeaks",
		Order = 3,
		DisplayName = "Frostfang Peaks",
		RecommendedSpeed = 40,
		Length = 150,
		NestAt = 0.55,
		GroundColor = Color3.fromHex("8FD3FF"),
		WallColor = Color3.fromHex("5A7A99"),
	},
}

local byId: { [string]: Biome } = {}
for _, biome in list do
	byId[biome.Id] = table.freeze(biome)
end

return table.freeze({
	List = table.freeze(list),
	ById = table.freeze(byId),
})
