-- Speed is a currency (like Cash) with no limit, earned only by running on your personal treadmill (TreadmillService):
-- every second you gain TreadmillConfig.GainPerSecond x your treadmill level's Multiplier x your equipped trail's
-- SpeedMultiplier. Your real running speed (Humanoid WalkSpeed) follows your Speed on a gentle, uncapped curve
-- (SpeedConfig.RunSpeed: +RunSpeedPerTenfold each time your Speed grows tenfold).
-- Saved as data.Speed.Trained (the Speed balance; the key name is kept from the old system). Saves from before the
-- currency (no data.Speed.Version) are converted once so the player keeps the running speed their training gave them.
-- Player attributes: Speed (balance), TrainedSpeed (same value, for older scripts), RunSpeed and BaseWalkSpeed (walk
--   speed; EggService applies BaseWalkSpeed with the carry slowdown), TrailSpeedMultiplier, TreadmillMultiplier,
--   SpeedGainMultiplier (trail x treadmill).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local TreadmillConfig = require(ReplicatedStorage.Shared.Config.TreadmillConfig)
local TrailConfig = require(ReplicatedStorage.Shared.Config.TrailConfig)

local DataService = require(script.Parent.DataService)

local SpeedService = {}

local DATA_VERSION = 3 -- 2 = Speed currency, 3 = all Speed values x100

local function trailMultiplier(data)
	local trail = TrailConfig.ById[data.Trails and data.Trails.Equipped or ""]
	return trail and trail.SpeedMultiplier or 1
end

local function treadmillMultiplier(data)
	local level = TreadmillConfig.Levels[data.Treadmill and data.Treadmill.Level or 0]
	return level and level.Multiplier or 1
end

-- timed Speed Gain Boost from the daily reward (DailyRewardService sets DailySpeedBoost while it runs)
-- and the treadmill lightning bolt (TreadmillService sets LightningBoost while its LightningBoostUntil runs)
local function dailyBoost(player)
	local b = player:GetAttribute("DailySpeedBoost")
	local m = type(b) == "number" and b > 0 and b or 1
	local l = player:GetAttribute("LightningBoost")
	if type(l) == "number" and l > 0 then
		m *= l
	end
	return m
end

local function publish(player, data)
	local points = data.Speed.Trained
	local run = SpeedConfig.RunSpeed(points)
	local shown = math.floor(points * 100 + 0.5) / 100
	local trail, treadmill = trailMultiplier(data), treadmillMultiplier(data)
	player:SetAttribute("Speed", shown)
	player:SetAttribute("TrainedSpeed", shown)
	player:SetAttribute("RunSpeed", run)
	player:SetAttribute("TrailSpeedMultiplier", trail)
	player:SetAttribute("TreadmillMultiplier", treadmill)
	player:SetAttribute("SpeedGainMultiplier", trail * treadmill * dailyBoost(player))
	player:SetAttribute("BaseWalkSpeed", run)
end

-- Running speed (WalkSpeed before the carry slowdown).
function SpeedService:GetSpeed(player)
	local data = DataService:Get(player)
	return data and SpeedConfig.RunSpeed(data.Speed.Trained) or SpeedConfig.BaseSpeed
end

-- Speed balance (the currency).
function SpeedService:GetPoints(player)
	local data = DataService:Get(player)
	return data and data.Speed.Trained or 0
end

-- Trail x treadmill multiplier on Speed earned.
function SpeedService:GetGainMultiplier(player)
	local data = DataService:Get(player)
	return data and trailMultiplier(data) * treadmillMultiplier(data) * dailyBoost(player) or 1
end

-- Re-publishes Speed (TrailService after a trail is equipped, TreadmillService after an upgrade).
function SpeedService:Refresh(player)
	local data = DataService:Get(player)
	if data then
		publish(player, data)
	end
end

-- Adds Speed (no limit). Returns the new balance.
-- Huge balances: a number only keeps ~16 significant digits, so at e.g. 1e22 a treadmill tick (~1e5) rounded away to
-- nothing and Speed never went up. Gains too small to register are carried over per player until they add up to
-- something the balance can hold.
local carry = {} -- [player] = Speed gained but not yet big enough to show on the balance
function SpeedService:AddSpeed(player, amount)
	local data = DataService:Get(player)
	if not data or amount <= 0 then
		return data and data.Speed.Trained or 0
	end
	local old = data.Speed.Trained
	local total = (carry[player] or 0) + amount
	local new = old + total
	if new == old then
		carry[player] = total
		return old
	end
	carry[player] = math.max(0, total - (new - old)) -- what rounding left out this time
	data.Speed.Trained = new
	publish(player, data)
	DataService:Save(player)
	return data.Speed.Trained
end

-- Old API (capped training); Speed no longer has a cap, so this just adds it.
function SpeedService:AddTrained(player, amount, _cap)
	SpeedService:AddSpeed(player, amount)
	return false
end

-- Studio testing only (DevService guards it): sets the Speed balance.
function SpeedService:SetTrainedForTesting(player, value)
	local data = DataService:Get(player)
	if data then
		data.Speed.Trained = math.max(0, value)
		publish(player, data)
	end
end

function SpeedService:Start()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		carry[player] = nil
	end)
	DataService:OnLoaded(function(player, data)
		local s = data.Speed
		if (s.Version or 1) < 2 then
			-- old system: run speed = 16 + treadmill training + bought upgrades; keep that running speed
			local oldRun = math.min(80, SpeedConfig.BaseSpeed + (tonumber(s.Trained) or 0) + (tonumber(s.Level) or 0) * SpeedConfig.LegacySpeedPerLevel)
			s.Trained = SpeedConfig.PointsForRunSpeed(oldRun)
			s.Level = 0
		elseif s.Version < 3 then
			-- Speed values were scaled up 100x
			s.Trained = (tonumber(s.Trained) or 0) * 100
		end
		s.Version = DATA_VERSION
		s.Trained = math.max(0, tonumber(s.Trained) or 0)
		publish(player, data)
	end)
end

return SpeedService
