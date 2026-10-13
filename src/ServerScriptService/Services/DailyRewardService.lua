-- Daily rewards: one claim per UTC day, rolling one reward from Shared.Config.DailyRewardConfig (Cash, Speed, or a timed
-- Luck / Money / Speed Gain boost). The streak bonus comes from the leaderboard's day streak (LeaderboardService:GetStreak),
-- so the Streak board and the daily rewards always show the same number.
-- Remotes.ClaimDaily (RemoteFunction): () -> ok, result | reason
--   result = { Id, Name, Amount?, Multiplier?, Seconds?, Streak, Bonus }   reason = "Claimed" | "NotReady" | "Busy"
-- Saved: data.Daily = { LastClaimDay, Claims, Boosts = { [kind] = { M, Until } } }  (kind = Luck | Cash | Speed)
-- Player attributes: DailyCanClaim, DailyNextAt (unix time of the next claim), DailyStreak, DailyBonus,
--   Daily<Kind>Boost (multiplier, only while active) + Daily<Kind>BoostUntil (unix time).
-- Boosts plug into: LuckService source "DailyBoost"; EconomyService's cash multiplier (DailyCashBoost);
-- SpeedService:GetGainMultiplier / SpeedGainMultiplier (DailySpeedBoost).
-- GameEvent DailyBoostEnded { Kind } when a boost runs out (toast).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local DailyRewardConfig = require(ReplicatedStorage.Shared.Config.DailyRewardConfig)
local TreadmillConfig = require(ReplicatedStorage.Shared.Config.TreadmillConfig)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local SpeedService = require(script.Parent.SpeedService)
local LuckService = require(script.Parent.LuckService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local DailyRewardService = {}

local BOOST_KIND = { LuckBoost = "Luck", CashBoost = "Cash", SpeedBoost = "Speed" }
local rng = Random.new()
local busy = {}
local gameEvent

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Daily]", ...)
	end
end

local function dailyOf(player)
	local data = DataService:Get(player)
	if not data then
		return nil
	end
	data.Daily = data.Daily or { LastClaimDay = 0, Claims = 0, Boosts = {} }
	data.Daily.Boosts = data.Daily.Boosts or {}
	return data.Daily, data
end

local function streakOf(player)
	return LeaderboardService:GetStreak(player) or player:GetAttribute("Streak") or 1
end

-- nice round numbers: 3 significant digits
local function roundNice(n)
	if n < 1000 then
		return math.floor(n + 0.5)
	end
	local p = 10 ^ (math.floor(math.log10(n)) - 2)
	return math.floor(n / p + 0.5) * p
end

local function publish(player)
	local daily = dailyOf(player)
	if not daily then
		return
	end
	local day = DailyRewardConfig.Day()
	local streak = streakOf(player)
	player:SetAttribute("DailyCanClaim", daily.LastClaimDay ~= day)
	player:SetAttribute("DailyNextAt", daily.LastClaimDay == day and (day + 1) * 86400 or os.time())
	player:SetAttribute("DailyStreak", streak)
	player:SetAttribute("DailyBonus", DailyRewardConfig.Bonus(streak))
end

-- boosts -----------------------------------------------------------------------------------------------------------
local function applyBoost(player, kind, m, untilT)
	local active = m and untilT and untilT > os.time()
	player:SetAttribute("Daily" .. kind .. "Boost", active and m or nil)
	player:SetAttribute("Daily" .. kind .. "BoostUntil", active and untilT or nil)
	if kind == "Luck" then
		LuckService:SetSource(player, "DailyBoost", active and m or nil)
	elseif kind == "Speed" then
		SpeedService:Refresh(player)
	elseif kind == "Cash" then
		EconomyService:Publish(player)
	end
end

local function addBoost(player, kind, multiplier, seconds)
	local daily = dailyOf(player)
	local now = os.time()
	local b = daily.Boosts[kind]
	local from = (b and b.Until > now) and b.Until or now
	local m = (b and b.Until > now) and math.max(b.M, multiplier) or multiplier
	daily.Boosts[kind] = { M = m, Until = from + seconds }
	applyBoost(player, kind, m, from + seconds)
end

local function checkExpired(player)
	local daily = dailyOf(player)
	if not daily then
		return
	end
	local now = os.time()
	for kind, b in daily.Boosts do
		if b.Until <= now then
			daily.Boosts[kind] = nil
			applyBoost(player, kind, nil, nil)
			gameEvent:FireClient(player, "DailyBoostEnded", { Kind = kind })
		end
	end
end

-- claiming ---------------------------------------------------------------------------------------------------------
local function roll()
	local total = 0
	for _, r in DailyRewardConfig.Rewards do
		total += r.Weight
	end
	local pick = rng:NextNumber(0, total)
	for _, r in DailyRewardConfig.Rewards do
		pick -= r.Weight
		if pick <= 0 then
			return r
		end
	end
	return DailyRewardConfig.Rewards[1]
end

function DailyRewardService:Claim(player)
	local daily, data = dailyOf(player)
	if not daily then
		return false, "NotReady"
	end
	if busy[player] then
		return false, "Busy"
	end
	local day = DailyRewardConfig.Day()
	if daily.LastClaimDay == day then
		return false, "Claimed"
	end
	busy[player] = true
	daily.LastClaimDay = day
	daily.Claims = (daily.Claims or 0) + 1

	local streak = streakOf(player)
	local bonus = DailyRewardConfig.Bonus(streak)
	local reward = roll()
	local result = { Id = reward.Id, Name = reward.Name, Streak = streak, Bonus = bonus }
	if reward.Id == "Cash" then
		local fromIncome = EconomyService:GetCashPerSecond(player) * rng:NextNumber(reward.IncomeSeconds[1], reward.IncomeSeconds[2])
		local amount = roundNice(math.max(rng:NextNumber(reward.Min, reward.Max), fromIncome) * bonus)
		EconomyService:AddCash(player, amount)
		result.Amount = amount
	elseif reward.Id == "Speed" then
		local perSecond = TreadmillConfig.GainPerSecond * SpeedService:GetGainMultiplier(player)
		local fromGain = perSecond * rng:NextNumber(reward.GainSeconds[1], reward.GainSeconds[2])
		local amount = roundNice(math.max(rng:NextNumber(reward.Min, reward.Max), fromGain) * bonus)
		SpeedService:AddSpeed(player, amount)
		result.Amount = amount
	else
		local seconds = math.floor(reward.Minutes * 60 * bonus)
		addBoost(player, BOOST_KIND[reward.Id], reward.Multiplier, seconds)
		result.Multiplier = reward.Multiplier
		result.Seconds = seconds
	end
	publish(player)
	DataService:Save(player)
	busy[player] = nil
	log(player.Name, "claimed", reward.Id, result.Amount or result.Multiplier, "streak", streak, "bonus", bonus)
	return true, result
end

-- Admin panel: lets the player claim today's reward again.
function DailyRewardService:ResetForTesting(player)
	local daily = dailyOf(player)
	if not daily then
		return false
	end
	daily.LastClaimDay = 0
	publish(player)
	DataService:Save(player)
	return true
end

-- Admin panel: a timed boost now (kind = Luck | Cash | Speed), same as rolling it from the daily reward.
function DailyRewardService:GrantBoost(player, kind, multiplier, seconds)
	if not dailyOf(player) or not (kind == "Luck" or kind == "Cash" or kind == "Speed") then
		return false
	end
	addBoost(player, kind, multiplier, seconds)
	DataService:Save(player)
	return true
end

function DailyRewardService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local remote = ReplicatedStorage.Remotes:FindFirstChild("ClaimDaily") or Instance.new("RemoteFunction")
	remote.Name = "ClaimDaily"
	remote.OnServerInvoke = function(player)
		return DailyRewardService:Claim(player)
	end
	remote.Parent = ReplicatedStorage.Remotes
end

function DailyRewardService:Start()
	DataService:OnLoaded(function(player)
		local daily = dailyOf(player)
		for kind, b in daily.Boosts do
			if b.Until > os.time() then
				applyBoost(player, kind, b.M, b.Until)
			else
				daily.Boosts[kind] = nil
			end
		end
		publish(player)
		-- the leaderboard streak loads from its own DataStore; publish again once it's in
		if not player:GetAttribute("LeaderboardStatsLoaded") then
			local conn
			conn = player:GetAttributeChangedSignal("LeaderboardStatsLoaded"):Connect(function()
				conn:Disconnect()
				publish(player)
			end)
		end
		player:GetAttributeChangedSignal("Streak"):Connect(function()
			publish(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
	-- boosts running out, and a new day starting while players are online
	task.spawn(function()
		local lastDay = DailyRewardConfig.Day()
		while true do
			task.wait(1)
			local day = DailyRewardConfig.Day()
			for _, player in Players:GetPlayers() do
				if DataService:Get(player) then
					checkExpired(player)
					if day ~= lastDay then
						publish(player)
					end
				end
			end
			lastDay = day
		end
	end)
end

return DailyRewardService
