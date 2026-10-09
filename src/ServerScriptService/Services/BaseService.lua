-- Assigns plots, spawns players at their base, and owns what sits on each Nest Pad.
-- Pad contents are persisted in DataService data.Pads[tostring(i)]; the in-world model is kept in sync here.
-- Player attribute: PlotId. Plot model attribute: OwnerUserId.
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local BaseService = {}

local plots = {} -- sorted list of plot models
local ownerOf = {} -- [plotModel] = player
local plotOf = {} -- [player] = plotModel
local padModels = {} -- [player] = { [padIndex] = model }

local function setLabels(plot, text)
	local board = plot:FindFirstChild("Arch") and plot.Arch:FindFirstChild("Board")
	if not board then
		return
	end
	for _, d in board:GetDescendants() do
		if d:IsA("TextLabel") then
			d.Text = text
		end
	end
end

local function insideZone(zone, pos)
	local p = zone.CFrame:PointToObjectSpace(pos)
	local h = zone.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function spawnAtBase(player, character)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local entrance = plot.EntranceMat.Entrance.WorldPosition
	local inward = Vector3.new(0, 0, plot.Zone.Position.Z - entrance.Z).Unit
	local pos = entrance + inward * 10 + Vector3.new(0, 3.5, 0)
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
			padModels[player] = {}
			plot:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
			setLabels(plot, player.DisplayName .. "'s Base")
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
	for _, model in padModels[player] or {} do
		model:Destroy()
	end
	padModels[player] = nil
	ownerOf[plot] = nil
	plotOf[player] = nil
	plot:SetAttribute("OwnerUserId", nil)
	setLabels(plot, "PLOT " .. plot:GetAttribute("PlotId"))
end

function BaseService:Init()
	for _, plot in workspace:WaitForChild("Map"):WaitForChild("Plots"):GetChildren() do
		if plot:GetAttribute("PlotId") then
			table.insert(plots, plot)
		end
	end
	table.sort(plots, function(a, b)
		return a:GetAttribute("PlotId") < b:GetAttribute("PlotId")
	end)
end

function BaseService:Start()
	local function onPlayer(player)
		assign(player)
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
end

function BaseService:GetPlot(player)
	return plotOf[player]
end

function BaseService:IsInOwnPlot(player, position)
	local plot = plotOf[player]
	return plot ~= nil and insideZone(plot.Zone, position)
end

function BaseService:GetPadPart(player, padIndex)
	local plot = plotOf[player]
	return plot and plot.NestPads:FindFirstChild("Pad" .. padIndex)
end

-- Direction a model on this plot should face (towards the path).
function BaseService:GetFacing(player)
	local plot = plotOf[player]
	return plot and Vector3.new(0, 0, -plot:GetAttribute("Side")) or -Vector3.zAxis
end

-- Returns padIndex, padPart for the first empty pad, or nil if the base is full or data isn't loaded.
function BaseService:FindEmptyPad(player)
	local plot = plotOf[player]
	local data = DataService:Get(player)
	if not (plot and data) then
		return nil
	end
	local pads = plot.NestPads:GetChildren()
	table.sort(pads, function(a, b)
		return a:GetAttribute("PadIndex") < b:GetAttribute("PadIndex")
	end)
	for _, pad in pads do
		local i = pad:GetAttribute("PadIndex")
		if data.Pads[tostring(i)] == nil then
			return i, pad
		end
	end
	return nil
end

-- Puts an entry (saved) and its model (world) on a pad, replacing whatever was there.
function BaseService:SetPad(player, padIndex, model, entry)
	local data = DataService:Get(player)
	local models = padModels[player]
	if not (data and models) then
		if model then
			model:Destroy()
		end
		return false
	end
	local old = models[padIndex]
	if old and old ~= model then
		old:Destroy()
	end
	models[padIndex] = model
	data.Pads[tostring(padIndex)] = entry
	return true
end

function BaseService:GetPadModel(player, padIndex)
	local models = padModels[player]
	return models and models[padIndex]
end

-- Iterates saved pad entries: fn(padIndex, entry, model).
function BaseService:ForEachPad(player, fn)
	local data = DataService:Get(player)
	if not data then
		return
	end
	for key, entry in data.Pads do
		local i = tonumber(key)
		fn(i, entry, padModels[player] and padModels[player][i])
	end
end

return BaseService
