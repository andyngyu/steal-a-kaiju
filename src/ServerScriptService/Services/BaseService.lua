-- Plots and pens: assigns a plot per player, builds the pen fence for the owner's level, handles Upgrade Pen,
-- and keeps the registry of what's in each pen (saved in data.Pen.Items, models kept in sync here).
-- Player attributes: PlotId, PenLevel, PenCount, PenCapacity (level capacity + BonusPenCapacity, a perk set by
-- GamePassService). Plot attributes: OwnerUserId, PenLevel (+ StealService's LockedUntil, LockCooldownUntil,
-- ProtectedUntil, cleared when the plot is released).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BaseConfig = require(ReplicatedStorage.Shared.Config.BaseConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local PenGeometry = require(ReplicatedStorage.Shared.Util.PenGeometry)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local PenBuilder = require(ServerScriptService.Lib.PenBuilder)

local DataService = require(script.Parent.DataService)

local BaseService = {}

local plots = {} -- plot models, closest to the lane first
local ownerOf = {} -- [plot] = player
local plotOf = {} -- [player] = plot
local itemModels = {} -- [player] = { [itemId] = model }
local gameEvent

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Base]", ...)
	end
end

local function setOwnerLabels(plot, text)
	for _, d in plot.Arch.Board:GetDescendants() do
		if d:IsA("TextLabel") then
			d.Text = text
		end
	end
end

local function updateSign(plot, level)
	local board = plot.UpgradeSign.Board
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	local prompt = board.UpgradePrompt
	local levels = BaseConfig.Levels
	if not level then
		gui.Levels.Text = "Unclaimed"
		gui.PriceFrame.Price.Text = "-"
		prompt.Enabled = false
	elseif level >= #levels then
		gui.Levels.Text = "Level " .. level .. " (Max)"
		gui.PriceFrame.Price.Text = "MAX"
		prompt.Enabled = false
	else
		local cost = levels[level + 1].Cost
		gui.Levels.Text = string.format("Level %d > Level %d", level, level + 1)
		gui.PriceFrame.Price.Text = Format.Money(cost)
		prompt.ObjectText = "Level " .. (level + 1) .. ": " .. Format.Money(cost)
		prompt.Enabled = true
	end
end

local function buildPen(plot, level)
	local old = plot:FindFirstChild("Pen")
	if old then
		old:Destroy()
	end
	PenBuilder.Build(plot, level).Parent = plot
	plot:SetAttribute("PenLevel", level)
end

-- Pen level capacity plus the Bigger Pen perk.
local function capacityOf(player, data)
	local bonus = player:GetAttribute("BonusPenCapacity")
	bonus = type(bonus) == "number" and math.max(0, math.floor(bonus)) or 0
	return PenGeometry.Level(data.Pen.Level).Capacity + bonus
end

local function publishCounts(player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local count = 0
	for _ in data.Pen.Items do
		count += 1
	end
	player:SetAttribute("PenLevel", data.Pen.Level)
	player:SetAttribute("PenCount", count)
	player:SetAttribute("PenCapacity", capacityOf(player, data))
end

local function spawnAtBase(player, character)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local pos = PenGeometry.ToWorld(plot, 0, 8) + Vector3.new(0, 3.5, 0)
	local inward = PenGeometry.Frame(plot).LookVector
	character:WaitForChild("HumanoidRootPart")
	task.defer(function()
		if character.Parent then
			character:PivotTo(CFrame.lookAt(pos, pos - inward))
		end
	end)
end

local function assign(player)
	for _, plot in plots do
		if not ownerOf[plot] then
			ownerOf[plot] = player
			plotOf[player] = plot
			itemModels[player] = {}
			plot:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
			setOwnerLabels(plot, player.DisplayName .. "'s Pen")
			return plot
		end
	end
	warn("[BaseService] no free plot for", player.Name)
	return nil
end

local function release(player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	for _, model in itemModels[player] or {} do
		model:Destroy()
	end
	itemModels[player] = nil
	ownerOf[plot] = nil
	plotOf[player] = nil
	plot:SetAttribute("OwnerUserId", nil)
	for _, attr in { "LockedUntil", "LockCooldownUntil", "ProtectedUntil" } do
		plot:SetAttribute(attr, nil)
	end
	setOwnerLabels(plot, "PLOT " .. plot:GetAttribute("PlotId"))
	buildPen(plot, 1)
	updateSign(plot, nil)
end

function BaseService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	for _, plot in workspace:WaitForChild("Map"):WaitForChild("Plots"):GetChildren() do
		if plot:GetAttribute("PlotId") then
			table.insert(plots, plot)
			buildPen(plot, 1)
			updateSign(plot, nil)
			plot.UpgradeSign.Board.UpgradePrompt.Triggered:Connect(function(player)
				if ownerOf[plot] == player then
					BaseService:TryUpgrade(player)
				else
					gameEvent:FireClient(player, "NotYourPen", {})
				end
			end)
		end
	end
	-- the Upgrade Pen sign's price button (UpgradeSignsController): the only requirement is the cost (TryUpgrade
	-- checks it); no distance or treadmill-level checks
	ReplicatedStorage.Remotes:WaitForChild("UpgradePen").OnServerEvent:Connect(function(player)
		if plotOf[player] then
			BaseService:TryUpgrade(player)
		end
	end)
	-- hand out the plots nearest the lane first
	table.sort(plots, function(a, b)
		local ax, bx = a:GetAttribute("PenOrigin").X, b:GetAttribute("PenOrigin").X
		if ax ~= bx then
			return ax > bx
		end
		return a:GetAttribute("PlotId") < b:GetAttribute("PlotId")
	end)
end

function BaseService:Start()
	local function onPlayer(player)
		assign(player)
		player:GetAttributeChangedSignal("BonusPenCapacity"):Connect(function()
			publishCounts(player)
		end)
		player.CharacterAdded:Connect(function(character)
			spawnAtBase(player, character)
		end)
		if player.Character then
			spawnAtBase(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(release)

	DataService:OnLoaded(function(player, data)
		local plot = plotOf[player]
		if not plot then
			return
		end
		data.Pen.Level = math.clamp(data.Pen.Level, 1, #BaseConfig.Levels)
		buildPen(plot, data.Pen.Level)
		updateSign(plot, data.Pen.Level)
		publishCounts(player)
	end)
end

function BaseService:GetPlot(player)
	return plotOf[player]
end

function BaseService:GetLevel(player)
	local data = DataService:Get(player)
	return data and data.Pen.Level or 1
end

-- Pen-local (x, d) of a world position for this player's pen.
function BaseService:ToPenLocal(player, position)
	return PenGeometry.ToLocal(plotOf[player], position)
end

function BaseService:PenToWorld(player, x, d)
	return PenGeometry.ToWorld(plotOf[player], x, d)
end

function BaseService:IsInOwnPen(player, position, inset)
	local plot = plotOf[player]
	if not plot then
		return false
	end
	local x, d = PenGeometry.ToLocal(plot, position)
	return PenGeometry.Contains(self:GetLevel(player), x, d, inset)
end

function BaseService:HasRoom(player)
	local data = DataService:Get(player)
	if not data then
		return false
	end
	local count = 0
	for _ in data.Pen.Items do
		count += 1
	end
	return count < capacityOf(player, data)
end

-- How many eggs + kaiju fit in the player's pen right now (level + perks).
function BaseService:GetCapacity(player)
	local data = DataService:Get(player)
	return data and capacityOf(player, data) or 0
end

-- Footprint radius of an egg of this rarity and size roll.
local function eggRadius(rarityId, size)
	local rarity = EggConfig.RarityById[rarityId or "Common"]
	return EggConfig.Size.X * (rarity and rarity.EggScale or 1) * (size or 1) / 2
end

-- Nearest spot to (x, d) inside the pen that keeps eggs apart (bigger eggs need more room). Returns x, d or nil.
function BaseService:FindFreeSpot(player, x, d, size, rarityId)
	local data = DataService:Get(player)
	if not data then
		return nil
	end
	local level = data.Pen.Level
	local myRadius = eggRadius(rarityId, size)
	local inset = math.max(BaseConfig.Drop.Inset, myRadius + 0.5)
	local gap = math.max(0, BaseConfig.Drop.Spacing - EggConfig.Size.X)
	local spacing = BaseConfig.Drop.Spacing * math.max(1, size or 1)
	local function free(cx, cd)
		if not PenGeometry.Contains(level, cx, cd, inset) then
			return false
		end
		for _, entry in data.Pen.Items do
			if entry.Kind == "Egg" then
				local need = myRadius + eggRadius(entry.Rarity, entry.Size) + gap
				if (Vector2.new(entry.X, entry.D) - Vector2.new(cx, cd)).Magnitude < need then
					return false
				end
			end
		end
		return true
	end
	x, d = PenGeometry.Clamp(level, x, d, inset)
	if free(x, d) then
		return x, d
	end
	for ring = 1, 4 do
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local cx, cd = x + math.cos(a) * spacing * ring, d + math.sin(a) * spacing * ring
			if free(cx, cd) then
				return cx, cd
			end
		end
	end
	return nil
end

-- Pen insets can't exceed half the pen (huge kaiju in a small pen just stay near the middle).
local function fitInset(level, inset)
	return math.min(inset, level.Width / 2 - 1, level.Depth / 2 - 1)
end

-- World position pulled inside the player's pen, `inset` studs from the fence.
function BaseService:ClampToPen(player, position, inset)
	local plot = plotOf[player]
	if not plot then
		return position
	end
	local levelId = self:GetLevel(player)
	local x, d = PenGeometry.ToLocal(plot, position)
	x, d = PenGeometry.Clamp(levelId, x, d, fitInset(PenGeometry.Level(levelId), inset))
	return PenGeometry.ToWorld(plot, x, d)
end

-- Random walkable point in the pen (for kaiju).
function BaseService:RandomSpot(player, inset, near, maxDist)
	local level = PenGeometry.Level(self:GetLevel(player))
	inset = fitInset(level, inset)
	local rng = Random.new()
	local x = rng:NextNumber(-level.Width / 2 + inset, level.Width / 2 - inset)
	local d = rng:NextNumber(inset, level.Depth - inset)
	if near and maxDist then
		local nx, nd = self:ToPenLocal(player, near)
		local v = Vector2.new(x - nx, d - nd)
		if v.Magnitude > maxDist then
			v = v.Unit * maxDist
			x, d = PenGeometry.Clamp(self:GetLevel(player), nx + v.X, nd + v.Y, inset)
		end
	end
	return self:PenToWorld(player, x, d)
end

-- Puts an entry (saved) and its model (world) into the pen under `id`, replacing what was there.
function BaseService:SetItem(player, id, model, entry)
	local data = DataService:Get(player)
	local models = itemModels[player]
	if not (data and models) then
		if model then
			model:Destroy()
		end
		return false
	end
	local old = models[id]
	if old and old ~= model then
		old:Destroy()
	end
	models[id] = model
	data.Pen.Items[id] = entry
	publishCounts(player)
	return true
end

-- Takes an item's model out of the world but keeps it in the save (StealService: it's being carried off).
function BaseService:DetachModel(player, id)
	local models = itemModels[player]
	if models and models[id] then
		models[id]:Destroy()
		models[id] = nil
	end
end

function BaseService:RemoveItem(player, id)
	local data = DataService:Get(player)
	local models = itemModels[player]
	if models and models[id] then
		models[id]:Destroy()
		models[id] = nil
	end
	if data then
		data.Pen.Items[id] = nil
	end
	publishCounts(player)
end

function BaseService:GetItem(player, id)
	local data = DataService:Get(player)
	return data and data.Pen.Items[id], itemModels[player] and itemModels[player][id]
end

-- fn(id, entry, model) for every saved item in the player's pen.
function BaseService:ForEachItem(player, fn)
	local data = DataService:Get(player)
	if not data then
		return
	end
	for id, entry in data.Pen.Items do
		fn(id, entry, itemModels[player] and itemModels[player][id])
	end
end

-- Next pen level; paid in cash unless `free`. False when maxed, unaffordable or the player's data/plot isn't ready.
local function upgrade(player, free)
	local data = DataService:Get(player)
	local plot = plotOf[player]
	if not (data and plot) then
		return false
	end
	local nextLevel = BaseConfig.Levels[data.Pen.Level + 1]
	if not nextLevel then
		return false
	end
	local EconomyService = require(script.Parent.EconomyService)
	if not free and not EconomyService:TrySpend(player, nextLevel.Cost) then
		gameEvent:FireClient(player, "NotEnoughCash", { Cost = nextLevel.Cost })
		return false
	end
	data.Pen.Level += 1
	buildPen(plot, data.Pen.Level)
	updateSign(plot, data.Pen.Level)
	publishCounts(player)
	DataService:Save(player)
	gameEvent:FireClient(player, "PenUpgraded", { Level = data.Pen.Level })
	log(player.Name, free and "was granted pen level" or "upgraded pen to", data.Pen.Level)
	return true
end

-- The Upgrade Pen sign: next level for its cash cost.
function BaseService:TryUpgrade(player)
	return upgrade(player, false)
end

-- Next level with no cash (a Robux upgrade from GamePassService's receipt handler). False when maxed or not ready.
function BaseService:GrantUpgrade(player)
	return upgrade(player, true)
end

return BaseService
