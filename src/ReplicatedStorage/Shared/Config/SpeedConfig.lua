--!strict
-- Speed is a currency (like Cash) with no upper limit. The only way to earn it is running on your personal treadmill:
-- each second you gain TreadmillConfig.GainPerSecond x the treadmill level's Multiplier x the equipped trail's
-- SpeedMultiplier (see SpeedService / TreadmillService).
-- Your actual running speed (Humanoid WalkSpeed) follows your Speed on a gentle curve with no cap:
--   RunSpeed = BaseSpeed + RunSpeedPerTenfold x log10(Speed / Unit)     (Speed below Unit = BaseSpeed)
-- so every time your Speed grows tenfold you run RunSpeedPerTenfold faster:
--   100 -> 16,  1K -> 31,  10K -> 46,  100K -> 61,  1M -> 76,  1B -> 121,  1T -> 166 ...
-- Biome RecommendedSpeed values (BiomeConfig) are run speeds; signs show them in Speed via PointsForRunSpeed.
local Speed = {
	BaseSpeed = 16, -- run speed until you have Unit Speed
	Unit = 100, -- Speed where the curve starts (bigger = bigger numbers for the same running speed)
	RunSpeedPerTenfold = 15, -- extra run speed each time Speed grows 10x
	MaxRunSpeed = 500, -- physics safety only

	-- old saves (before the currency) stored bought upgrade levels worth this much run speed each
	LegacySpeedPerLevel = 2,
}

-- Running speed (WalkSpeed) for a Speed balance.
function Speed.RunSpeed(points: number): number
	if points <= Speed.Unit then
		return Speed.BaseSpeed
	end
	return math.min(Speed.MaxRunSpeed, Speed.BaseSpeed + Speed.RunSpeedPerTenfold * math.log10(points / Speed.Unit))
end

-- Speed balance needed to run at `runSpeed`.
function Speed.PointsForRunSpeed(runSpeed: number): number
	if runSpeed <= Speed.BaseSpeed then
		return 0
	end
	return Speed.Unit * 10 ^ ((runSpeed - Speed.BaseSpeed) / Speed.RunSpeedPerTenfold)
end

return table.freeze(Speed)
