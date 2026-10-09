-- Player Speed = SpeedConfig.BaseSpeed + treadmill training + bought upgrades (saved in data.Speed).
-- Publishes the BaseWalkSpeed attribute; EggService applies it to the Humanoid (with the carry slowdown).
-- Training comes from TreadmillService (personal treadmills) via :AddTrained.
-- Buying: the Speed Shop kiosk prompt, or Remotes.BuySpeed (no arguments) for the UI's Shop button.
-- Player attributes: Speed, SpeedLevel, TrainedSpeed, NextSpeedCost (nil when maxed), BaseWalkSpeed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local TreadmillConfig = require(ReplicatedStorage.Shared.Config.TreadmillConfig)
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

local function publish(player, data)
	local s = data.Speed
	local speed = SpeedConfig.Total(s.Trained, s.Level)
	player:SetAttribute("Speed", round1(speed))
	player:SetAttribute("SpeedLevel", s.Level)
	player:SetAttribute("TrainedSpeed", round1(s.Trained))
	player:SetAttribute("NextSpeedCost", SpeedConfig.UpgradeCost(s.Level))
	player:SetAttribute("BaseWalkSpeed", speed)
end

function SpeedService:GetSpeed(player)
	local data = DataService:Get(player)
	return data and SpeedConfig.Total(data.Speed.Trained, data.Speed.Level) or SpeedConfig.BaseSpeed
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
	local speed = SpeedConfig.Total(s.Trained, s.Level)
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
