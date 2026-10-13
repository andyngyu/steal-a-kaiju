-- Daily rewards (ServerScriptService.Services.DailyRewardService; UI: KaijuUI DailyPanel / Controllers.DailyRewardController,
-- which opens on join). One claim per UTC day. Each claim rolls ONE reward from Rewards (by Weight).
-- Streak = the leaderboard's day streak (Services.LeaderboardService, player attribute Streak): every day in a row adds
-- StreakStep to the bonus, up to MaxStreakDays. The bonus multiplies Cash / Speed amounts and boost durations.
local DailyRewardConfig = {
	StreakStep = 0.1, -- +10% per day in a row
	MaxStreakDays = 31, -- bonus stops growing here (x4.0)
	WeekLength = 7, -- the panel shows the streak a week at a time
}

-- Cash / Speed: a random amount between Min and Max, or (if bigger) your income/gain for a random number of seconds
-- in IncomeSeconds / GainSeconds, so the reward keeps up as you progress. Boosts: Multiplier for Minutes (x bonus);
-- claiming a boost you already have adds the time and keeps the higher multiplier.
DailyRewardConfig.Rewards = {
	{ Id = "Cash", Weight = 30, Name = "Cash", Min = 5000, Max = 25000, IncomeSeconds = { 300, 900 } },
	{ Id = "Speed", Weight = 30, Name = "Speed", Min = 2000, Max = 10000, GainSeconds = { 180, 600 } },
	{ Id = "LuckBoost", Weight = 14, Name = "Luck Boost", Multiplier = 1.5, Minutes = 10 },
	{ Id = "CashBoost", Weight = 13, Name = "Money Boost", Multiplier = 2, Minutes = 10 },
	{ Id = "SpeedBoost", Weight = 13, Name = "Speed Gain Boost", Multiplier = 2, Minutes = 10 },
}

DailyRewardConfig.ById = {}
for _, r in DailyRewardConfig.Rewards do
	DailyRewardConfig.ById[r.Id] = r
end

-- Bonus multiplier for a streak of `days`.
function DailyRewardConfig.Bonus(days: number): number
	days = math.clamp(math.floor(days or 1), 1, DailyRewardConfig.MaxStreakDays)
	return math.floor((1 + DailyRewardConfig.StreakStep * (days - 1)) * 100 + 0.5) / 100
end

-- The UTC day number (the day a claim counts for).
function DailyRewardConfig.Day(unix: number?): number
	return math.floor((unix or os.time()) / 86400)
end

return DailyRewardConfig
