-- Personal treadmills, one per base. Level 0 = locked (hologram); the TreadmillSign unlocks and upgrades it.
-- Running: the owner uses Run on their treadmill. Their HumanoidRootPart is anchored on the belt (no physics jitter);
-- clients play the run animation and scroll the belt (Gameplay.SpeedFX). The server adds Speed every CheckInterval
-- up to the level's MaxTrained. Leaving: jump (client fires Remotes.Treadmill "Stop"), use the prompt again, die, or leave.
-- Player attributes: TreadmillLevel, OnTreadmill. Treadmill model attributes: Level, Ghost, Runner (UserId while running).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TreadmillConfig = require(ReplicatedStorage.Shared.Config.TreadmillConfig)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local TreadmillBuilder = require(game:GetService("ServerScriptService").Lib.TreadmillBuilder)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local EconomyService = require(script.Parent.EconomyService)
local SpeedService = require(script.Parent.SpeedService)

local TreadmillService = {}

local LEVELS = TreadmillConfig.Levels
local gameEvent
local plots = {}
local running = {} -- [player] = { plot, model, maxed }
local ownerPlot = {} -- [player] = plot (kept here so leaving doesn't depend on BaseService's handler order)

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Treadmill]", ...)
	end
end

local function getLevel(player)
	local data = DataService:Get(player)
	return data and data.Treadmill.Level or 0
end

local function updateSign(plot, level, owned)
	local board = plot.TreadmillSign.Board
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	local prompt = board.TreadmillPrompt
	if not owned then
		gui.Levels.Text = "Unclaimed"
		gui.PriceFrame.Price.Text = "-"
		prompt.Enabled = false
	elseif level == 0 then
		gui.Levels.Text = "Unlock: " .. LEVELS[1].Name
		gui.PriceFrame.Price.Text = Format.Money(LEVELS[1].Cost)
		prompt.ActionText = "Unlock Treadmill"
		prompt.ObjectText = Format.Money(LEVELS[1].Cost)
		prompt.Enabled = true
	elseif level < #LEVELS then
		local nextLevel = LEVELS[level + 1]
		gui.Levels.Text = string.format("Lv %d > Lv %d", level, level + 1)
		gui.PriceFrame.Price.Text = Format.Money(nextLevel.Cost)
		prompt.ActionText = "Upgrade Treadmill"
		prompt.ObjectText = nextLevel.Name .. ": " .. Format.Money(nextLevel.Cost)
		prompt.Enabled = true
	else
		gui.Levels.Text = "Lv " .. level .. " (Max)"
		gui.PriceFrame.Price.Text = "MAX"
		prompt.Enabled = false
	end
end

function TreadmillService:Stop(player)
	local r = running[player]
	if not r then
		return
	end
	running[player] = nil
	if player.Parent == Players then
		player:SetAttribute("OnTreadmill", nil)
	end
	if r.model.Parent then
		r.model:SetAttribute("Runner", nil)
		local prompt = r.model.Deck:FindFirstChild("RunPrompt")
		if prompt then
			prompt.ActionText = "Run"
		end
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = false
		if r.model.Parent then
			char:PivotTo(r.model:GetPivot() * CFrame.new(0, 3.5, 7.5)) -- step off behind the belt
		end
	end
end

function TreadmillService:BeginRun(player, plot)
	local model = plot:FindFirstChild("Treadmill")
	if not model or model:GetAttribute("Ghost") or BaseService:GetPlot(player) ~= plot or getLevel(player) < 1 then
		return
	end
	if model:GetAttribute("Runner") then
		return
	end
	if player:GetAttribute("CarryingEgg") then
		gameEvent:FireClient(player, "TreadmillCarrying", {})
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp and hum.Health > 0) then
		return
	end
	local point = model.Deck.RunPoint.WorldPosition
	local pos = point + Vector3.new(0, hum.HipHeight + hrp.Size.Y / 2, 0)
	hrp.Anchored = true
	char:PivotTo(CFrame.lookAt(pos, pos + model:GetPivot().LookVector))
	running[player] = { plot = plot, model = model }
	player:SetAttribute("OnTreadmill", true)
	model:SetAttribute("Runner", player.UserId)
	model.Deck.RunPrompt.ActionText = "Stop"
	log(player.Name, "started running on level", getLevel(player))
end

local function placeModel(plot, level)
	local old = plot:FindFirstChild("Treadmill")
	if old then
		old:Destroy()
	end
	local spot = plot.TreadmillSpot
	local model = level > 0 and TreadmillBuilder.Build(level) or TreadmillBuilder.BuildGhost()
	model.WorldPivot = CFrame.new() -- built around the origin with feet at y = 0
	model:PivotTo(CFrame.new(spot.Position.X, 0, spot.Position.Z) * spot.CFrame.Rotation)
	model.Parent = plot
	local prompt = model.Deck:FindFirstChild("RunPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			if running[player] then
				TreadmillService:Stop(player)
			else
				TreadmillService:BeginRun(player, plot)
			end
		end)
	end
	return model
end

function TreadmillService:TryBuy(player)
	local data = DataService:Get(player)
	local plot = BaseService:GetPlot(player)
	if not (data and plot) then
		return false
	end
	local nextLevel = LEVELS[data.Treadmill.Level + 1]
	if not nextLevel then
		return false
	end
	if not EconomyService:TrySpend(player, nextLevel.Cost) then
		gameEvent:FireClient(player, "NotEnoughCash", { Cost = nextLevel.Cost })
		return false
	end
	self:Stop(player)
	data.Treadmill.Level += 1
	placeModel(plot, data.Treadmill.Level)
	updateSign(plot, data.Treadmill.Level, true)
	player:SetAttribute("TreadmillLevel", data.Treadmill.Level)
	DataService:Save(player)
	gameEvent:FireClient(player, "TreadmillUpgraded", { Level = data.Treadmill.Level, Name = nextLevel.Name })
	log(player.Name, "treadmill now level", data.Treadmill.Level)
	return true
end

function TreadmillService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	for _, plot in workspace:WaitForChild("Map"):WaitForChild("Plots"):GetChildren() do
		if not plot:FindFirstChild("TreadmillSpot") then
			continue
		end
		table.insert(plots, plot)
		placeModel(plot, 0)
		updateSign(plot, 0, false)
		plot.TreadmillSign.Board.TreadmillPrompt.Triggered:Connect(function(player)
			if BaseService:GetPlot(player) == plot then
				TreadmillService:TryBuy(player)
			else
				gameEvent:FireClient(player, "NotYourPen", {})
			end
		end)
	end
	ReplicatedStorage.Remotes.Treadmill.OnServerEvent:Connect(function(player, action)
		if action == "Stop" then
			TreadmillService:Stop(player)
		end
	end)
end

function TreadmillService:Start()
	DataService:OnLoaded(function(player, data)
		data.Treadmill.Level = math.clamp(data.Treadmill.Level, 0, #LEVELS)
		player:SetAttribute("TreadmillLevel", data.Treadmill.Level)
		local plot = BaseService:GetPlot(player)
		if plot then
			ownerPlot[player] = plot
			placeModel(plot, data.Treadmill.Level)
			updateSign(plot, data.Treadmill.Level, true)
		end
	end)

	local function onPlayer(player)
		player.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid")
			hum.Died:Connect(function()
				TreadmillService:Stop(player)
			end)
		end)
		player.CharacterRemoving:Connect(function()
			TreadmillService:Stop(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local plot = ownerPlot[player]
		ownerPlot[player] = nil
		TreadmillService:Stop(player)
		if plot then
			placeModel(plot, 0)
			updateSign(plot, 0, false)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TreadmillConfig.CheckInterval then
			return
		end
		local step = acc
		acc = 0
		for player, r in running do
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not (hrp and hrp.Anchored and r.model.Parent) then
				TreadmillService:Stop(player)
				continue
			end
			local level = LEVELS[getLevel(player)]
			if level and SpeedService:AddTrained(player, level.SpeedPerSecond * step, level.MaxTrained) and not r.maxed then
				r.maxed = true
				local nextLevel = LEVELS[getLevel(player) + 1]
				gameEvent:FireClient(player, "TreadmillMaxed", { Max = level.MaxTrained, Level = getLevel(player), NextName = nextLevel and nextLevel.Name })
			end
		end
	end)
end

return TreadmillService
