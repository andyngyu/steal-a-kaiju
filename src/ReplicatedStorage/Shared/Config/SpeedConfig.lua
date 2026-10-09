--!strict
-- Player Speed (WalkSpeed). Speed = BaseSpeed + trained (treadmill) + Level * Upgrade.SpeedPerLevel, capped at MaxSpeed.
-- Biome RecommendedSpeed values live in BiomeConfig; guardian chase speeds are tuned against them.
local Speed = {
	BaseSpeed = 16,
	MaxSpeed = 80,

	Upgrade = table.freeze({
		SpeedPerLevel = 2,
		BaseCost = 50, -- price of the first upgrade
		CostGrowth = 1.5, -- each upgrade costs this much more than the last
		MaxLevel = 30,
		CooldownSeconds = 0.25,
	}),

	Treadmill = table.freeze({
		SpeedPerSecond = 0.1, -- gained while running on the belt
		MaxTrained = 10, -- treadmill can add at most this much Speed
		BeltSpeed = 13, -- studs/s the belt pushes backwards; standing still slides you off
		CheckInterval = 0.5,
	}),
}

-- Rounds prices to friendly numbers: 2 significant figures (113 -> 110, 1922 -> 1900).
local function friendly(n: number): number
	if n < 100 then
		return math.floor(n / 5 + 0.5) * 5
	end
	local mag = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / mag + 0.5) * mag
end

-- Cost to go from `level` to `level + 1` (level starts at 0). nil when maxed.
function Speed.UpgradeCost(level: number): number?
	if level >= Speed.Upgrade.MaxLevel then
		return nil
	end
	return friendly(Speed.Upgrade.BaseCost * Speed.Upgrade.CostGrowth ^ level)
end

function Speed.Total(trained: number, level: number): number
	return math.min(Speed.MaxSpeed, Speed.BaseSpeed + trained + level * Speed.Upgrade.SpeedPerLevel)
end

return table.freeze(Speed)
