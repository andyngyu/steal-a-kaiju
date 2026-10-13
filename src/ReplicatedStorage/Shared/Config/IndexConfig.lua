--!strict
-- Kaiju Index rewards (Services.IndexService, the UI's Index panel).
-- Every species you discover can be claimed once for Cash + Speed. Claiming every species of an area (a biome; Secret
-- kaiju that hatch anywhere count as their own "Secret" area) multiplies all your cash income by AreaCashMultiplier,
-- for good. Areas stack: 1 area x1.5, 2 areas x2.25, 3 areas x3.375 ...
local IndexConfig = {
	CashRewardSeconds = 300, -- cash reward = the species' base CashPerSecond x this
	SpeedRewardBase = 1000, -- Speed reward for a Common...
	SpeedRewardGrowth = 3, -- ...x this for each rarity step up (Uncommon 3K, Rare 9K, Epic 27K ...)
	AreaCashMultiplier = 1.5, -- cash income multiplier per completed area (stacks)
}

-- (cash, speed) for claiming a species. kaiju = its KaijuConfig entry, rarityOrder = EggConfig rarity Order (1 = Common).
function IndexConfig.Reward(kaiju: any, rarityOrder: number): (number, number)
	local cash = math.floor((kaiju.CashPerSecond or 0) * IndexConfig.CashRewardSeconds)
	local speed = math.floor(IndexConfig.SpeedRewardBase * IndexConfig.SpeedRewardGrowth ^ math.max(0, rarityOrder - 1))
	return cash, speed
end

-- The area a species belongs to ("Any" = the Secret area).
function IndexConfig.AreaOf(kaiju: any): string
	return kaiju.Biome or "Any"
end

return table.freeze(IndexConfig)
