-- Player Speed = (SpeedConfig.BaseSpeed + treadmill training + bought upgrades) x equipped trail's SpeedMultiplier,
-- capped at SpeedConfig.MaxSpeed (training/upgrades saved in data.Speed, trail in data.Trails, see TrailService).
-- Publishes the BaseWalkSpeed attribute; EggService applies it to the Humanoid (with the carry slowdown).
-- Training comes from TreadmillService (personal treadmills) via :AddTrained.
-- Buying: the Speed stall prompt in the Kaiju Market, or Remotes.BuySpeed (no arguments) for the UI.
-- Player attributes: Speed, SpeedLevel, TrainedSpeed, TrailSpeedMultiplier, NextSpeedCost (nil when maxed), BaseWalkSpeed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local TreadmillConfig = require(ReplicatedStorage.Shared.Config.TreadmillConfig)
local TrailConfig = require(ReplicatedStorage.Shared.Config.TrailConfig)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local SpeedService = {}

local gameEvent
local lastBuy = {} -- [player] = os.clock()

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Speed]", ...)
	end
end

local function round1(n)
	return math.floor(n * 10 + 0.5) / 10
end

local function trailMultiplier(data)
	local trail = TrailConfig.ById[data.Trails and data.Trails.Equipped or ""]
	return trail and trail.SpeedMultiplier or 1
end

local function totalSpeed(data)
	local s = data.Speed
	return math.min(SpeedConfig.MaxSpeed, SpeedConfig.Total(s.Trained, s.Level) * trailMultiplier(data))
end

local function publish(player, data)
	local s = data.Speed
	local speed = totalSpeed(data)
	player:SetAttribute("Speed", round1(speed))
	player:SetAttribute("SpeedLevel", s.Level)
	player:SetAttribute("TrainedSpeed", round1(s.Trained))
	player:SetAttribute("TrailSpeedMultiplier", trailMultiplier(data))
	player:SetAttribute("NextSpeedCost", SpeedConfig.UpgradeCost(s.Level))
	player:SetAttribute("BaseWalkSpeed", speed)
end

function SpeedService:GetSpeed(player)
	local data = DataService:Get(player)
	return data and totalSpeed(data) or SpeedConfig.BaseSpeed
end

-- Re-publishes Speed (TrailService calls this after a trail is equipped).
function SpeedService:Refresh(player)
	local data = DataService:Get(player)
	if data then
		publish(player, data)
	end
end

function SpeedService:TryBuy(player)
	local now = os.clock()
	if lastBuy[player] and now - lastBuy[player] < SpeedConfig.Upgrade.CooldownSeconds then
		return false
	end
	lastBuy[player] = now
	local data = DataService:Get(player)
	if not data then
		return false
	end
	local s = data.Speed
	local cost = SpeedConfig.UpgradeCost(s.Level)
	if not cost or SpeedConfig.Total(s.Trained, s.Level) >= SpeedConfig.MaxSpeed then
		gameEvent:FireClient(player, "SpeedMaxed", {})
		return false
	end
	if not EconomyService:TrySpend(player, cost) then
		gameEvent:FireClient(player, "NotEnoughCash", { Cost = cost })
		return false
	end
	s.Level += 1
	publish(player, data)
	DataService:Save(player)
	local speed = totalSpeed(data)
	gameEvent:FireClient(player, "SpeedBought", { Speed = speed, Level = s.Level })
	log(player.Name, "bought speed level", s.Level, "->", speed)
	return true
end

-- Adds treadmill training up to `cap`. Returns true once the cap is reached.
function SpeedService:AddTrained(player, amount, cap)
	local data = DataService:Get(player)
	if not data then
		return false
	end
	local s = data.Speed
	if s.Trained < cap then
		s.Trained = math.min(cap, s.Trained + amount)
		publish(player, data)
		DataService:Save(player)
	end
	return s.Trained >= cap
end

-- Studio testing only (DevService guards it).
function SpeedService:SetTrainedForTesting(player, value)
	local data = DataService:Get(player)
	if data then
		data.Speed.Trained = math.max(0, value)
		publish(player, data)
	end
end

function SpeedService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local map = workspace:WaitForChild("Map")
	map:WaitForChild("SpeedShop").Board.BuyPrompt.Triggered:Connect(function(player)
		SpeedService:TryBuy(player)
	end)
	ReplicatedStorage.Remotes.BuySpeed.OnServerEvent:Connect(function(player)
		SpeedService:TryBuy(player)
	end)
end

function SpeedService:Start()
	DataService:OnLoaded(function(player, data)
		local s = data.Speed
		local levels = TreadmillConfig.Levels
		s.Trained = math.clamp(s.Trained, 0, levels[#levels].MaxTrained)
		s.Level = math.clamp(s.Level, 0, SpeedConfig.Upgrade.MaxLevel)
		publish(player, data)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
	end)
end

return SpeedService
