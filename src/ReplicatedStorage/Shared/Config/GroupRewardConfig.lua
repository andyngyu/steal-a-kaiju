--!strict
-- Group reward bundle (ServerScriptService.Services.GroupRewardService; the golden Rumblerex NPC in the Kaiju Market
-- opens KaijuUI GroupRewardController). Join the group, claim once per account:
return table.freeze({
	GroupId = 702204099,
	GroupName = "Aries Inc",

	Cash = 10000,
	Speed = 2000,
	Luck = 1.25, -- a luck source (LuckService "GroupReward") for as long as the player stays in the group
	Pet = table.freeze({
		Species = "Rumblerex",
		Variant = "Golden", -- Shared.Util.GoldVariant recolours it
		DisplayName = "Golden Rumblerex",
		CashPerSecond = 100, -- fixed income (KaijuStats: FixedCashPerSecond, still grows with feeding levels)
	}),
})
