-- Robux store, run by ServerScriptService.Services.GamePassService.
--   GamePass = bought once, perks for life. Bundle = developer product, can be bought again.
-- IDs come from the Creator Dashboard (the experience > Monetization > Passes / Developer Products). 0 = not created yet,
-- so nothing can be bought. The UI prompts the IDs in StarterGui.KaijuUI.UIConfig (StoreItems, UpgradeRobux); the server
-- uses an ID from here when it's set, otherwise the UI's, so filling in UIConfig alone is enough.
-- Robux trails use TrailConfig's own ProductId.
local StoreConfig = {}

StoreConfig.Items = {
	{
		Id = "DoubleCash",
		Kind = "GamePass",
		GamePassId = 0,
		RobuxPrice = 199,
		DisplayName = "x2 Cash",
		Perks = { CashMultiplier = 2 },
	},
	{
		Id = "BiggerPen",
		Kind = "GamePass",
		GamePassId = 0,
		RobuxPrice = 149,
		DisplayName = "Bigger Pen",
		Perks = { BonusPenCapacity = 5 },
	},
	{
		Id = "VIP",
		Kind = "GamePass",
		GamePassId = 0,
		RobuxPrice = 399,
		DisplayName = "VIP",
		Perks = { VIP = true, EggLuckMultiplier = 1.15 }, -- permanent small luck boost + chat tag
	},
	{
		Id = "StarterBundle",
		Kind = "Bundle",
		ProductId = 0,
		RobuxPrice = 99,
		DisplayName = "Starter Bundle",
		Grant = { Cash = 25000, Egg = { BiomeId = "PebblePlains", Rarity = "Rare" } }, -- egg size: normal roll
	},
	{
		Id = "LuckBundle",
		Kind = "Bundle",
		ProductId = 0,
		RobuxPrice = 79,
		DisplayName = "Luck Bundle",
		Grant = { LuckMultiplier = 2, LuckSeconds = 30 * 60 }, -- buying again adds another 30 minutes
	},
}

StoreConfig.ById = {}
for _, item in StoreConfig.Items do
	StoreConfig.ById[item.Id] = item
end

-- Robux button on the Upgrade Pen / Treadmill signs: one developer product per target level (prices are display only).
StoreConfig.Upgrades = {
	Pen = {
		[2] = { ProductId = 0, RobuxPrice = 29 },
		[3] = { ProductId = 0, RobuxPrice = 79 },
		[4] = { ProductId = 0, RobuxPrice = 149 },
		[5] = { ProductId = 0, RobuxPrice = 299 },
	},
	Treadmill = {
		[1] = { ProductId = 0, RobuxPrice = 19 },
		[2] = { ProductId = 0, RobuxPrice = 49 },
		[3] = { ProductId = 0, RobuxPrice = 99 },
		[4] = { ProductId = 0, RobuxPrice = 199 },
		[5] = { ProductId = 0, RobuxPrice = 399 },
	},
}

-- VIP chat tag (StarterPlayerScripts.Gameplay.StoreFX)
StoreConfig.VIPTag = { Text = "VIP", Color = "#FFD23F" }

return StoreConfig
