--!strict
-- Character trails (Trails stall in the Kaiju Market + the UI's POWERS panel). A trail multiplies the Speed you earn on
-- your treadmill (SpeedMultiplier: 1.5x for the first trail, +0.5x for each one after). Price 0 = free, owned by everyone.
-- Fields used by the UI's TrailShopController: Id, DisplayName, Rarity, SpeedMultiplier, Price, RobuxPrice, ProductId, Color, Image.
-- RobuxPrice/ProductId stay 0 until developer products exist. Colors/Lifetime/Width/LightEmission shape the Trail instance.
export type Trail = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	SpeedMultiplier: number,
	Price: number,
	RobuxPrice: number,
	ProductId: number,
	Color: string,
	Image: string,
	Colors: { string },
	Lifetime: number,
	Width: number,
	LightEmission: number,
}

local list: { Trail } = {
	{
		Id = "PebbleDust", DisplayName = "Pebble Dust", Rarity = "Common", SpeedMultiplier = 1.5,
		Price = 0, RobuxPrice = 0, ProductId = 0, Color = "#D8D2C4", Image = "rbxassetid://95996213097474",
		Colors = { "#F2EBDD", "#B8B0A0" }, Lifetime = 0.45, Width = 1.2, LightEmission = 0.1,
	},
	{
		Id = "JungleLeaf", DisplayName = "Jungle Leaf", Rarity = "Uncommon", SpeedMultiplier = 2,
		Price = 7500, RobuxPrice = 0, ProductId = 0, Color = "#5CFF52", Image = "rbxassetid://128021259197051",
		Colors = { "#B6FF8C", "#2FC22A" }, Lifetime = 0.55, Width = 1.3, LightEmission = 0.3,
	},
	{
		Id = "FrostBreath", DisplayName = "Frost Breath", Rarity = "Rare", SpeedMultiplier = 2.5,
		Price = 40000, RobuxPrice = 0, ProductId = 0, Color = "#5DB8FF", Image = "rbxassetid://128712832847063",
		Colors = { "#E6F7FF", "#5DB8FF", "#2B6FE0" }, Lifetime = 0.65, Width = 1.4, LightEmission = 0.5,
	},
	{
		Id = "VoidPlasma", DisplayName = "Void Plasma", Rarity = "Epic", SpeedMultiplier = 3,
		Price = 150000, RobuxPrice = 0, ProductId = 0, Color = "#C77DFF", Image = "rbxassetid://75463398401743",
		Colors = { "#F0C8FF", "#B05CFF", "#5A1FB8" }, Lifetime = 0.75, Width = 1.5, LightEmission = 0.7,
	},
	{
		Id = "ThunderGold", DisplayName = "Thunder Gold", Rarity = "Legendary", SpeedMultiplier = 3.5,
		Price = 600000, RobuxPrice = 0, ProductId = 0, Color = "#FFD23F", Image = "rbxassetid://92419407207451",
		Colors = { "#FFFFFF", "#FFE24A", "#FFA000" }, Lifetime = 0.85, Width = 1.6, LightEmission = 0.9,
	},
	{
		Id = "MagmaRoar", DisplayName = "Magma Roar", Rarity = "Mythic", SpeedMultiplier = 4,
		Price = 2500000, RobuxPrice = 0, ProductId = 0, Color = "#FF5A1F", Image = "rbxassetid://70944715659654",
		Colors = { "#FFE24A", "#FF8A1F", "#E8301A", "#5A1A10" }, Lifetime = 0.95, Width = 1.8, LightEmission = 1,
	},
	{
		Id = "PrismRainbow", DisplayName = "Prism Rainbow", Rarity = "Secret", SpeedMultiplier = 4.5,
		Price = 15000000, RobuxPrice = 0, ProductId = 0, Color = "#FF8AE0", Image = "",
		Colors = { "#FF4D4D", "#FFB84D", "#FFF04D", "#4DFF88", "#4DB8FF", "#C44DFF" }, Lifetime = 1.1, Width = 2, LightEmission = 0.35, -- higher glow washes the rainbow out to white
	},
	{
		Id = "ShadowMonarch", DisplayName = "Shadow Monarch", Rarity = "Secret", SpeedMultiplier = 5,
		Price = 50000000, RobuxPrice = 0, ProductId = 0, Color = "#8A3DFF", Image = "",
		-- bright violet at the player fading through deep purple to black (matches its shop picture); low glow keeps the
		-- dark end dark
		Colors = { "#E6D4FF", "#8A3DFF", "#2A1050", "#000000" }, Lifetime = 1.2, Width = 2.1, LightEmission = 0.3,
	},
}

local byId: { [string]: Trail } = {}
for _, t in list do
	byId[t.Id] = table.freeze(t)
end

return table.freeze({
	List = table.freeze(list),
	ById = table.freeze(byId),
})
