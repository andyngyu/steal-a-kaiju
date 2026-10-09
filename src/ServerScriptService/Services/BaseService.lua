-- Assigns plots, spawns players at their base, and tracks what sits on each Nest Pad.
-- Player attribute: PlotId. Plot model attribute: OwnerUserId.
local Players = game:GetService("Players")

local BaseService = {}

local plots = {} -- sorted list of plot models
local ownerOf = {} -- [plotModel] = player
local plotOf = {} -- [player] = plotModel
local padEggs = {} -- [player] = { [padIndex] = eggModel }

local function setLabels(plot, text)
	local arch = plot:FindFirstChild("Arch")
	local board = arch and arch:FindFirstChild("Board")
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
	local mat = plot:FindFirstChild("EntranceMat")
	local zone = plot:FindFirstChild("Zone")
	if not (mat and zone) then
		return
	end
	local entrance = mat.Entrance.WorldPosition
	local inward = Vector3.new(0, 0, zone.Position.Z - entrance.Z).Unit
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
			padEggs[player] = {}
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
	for _, egg in padEggs[player] or {} do
		egg:Destroy()
	end
	padEggs[player] = nil
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
	local zone = plot and plot:FindFirstChild("Zone")
	return zone ~= nil and insideZone(zone, position)
end

-- Returns padIndex, padPart for the first empty pad, or nil if the base is full.
function BaseService:FindEmptyPad(player)
	local plot = plotOf[player]
	local eggs = padEggs[player]
	if not (plot and eggs) then
		return nil
	end
	local pads = plot.NestPads:GetChildren()
	table.sort(pads, function(a, b)
		return a:GetAttribute("PadIndex") < b:GetAttribute("PadIndex")
	end)
	for _, pad in pads do
		local i = pad:GetAttribute("PadIndex")
		if not eggs[i] then
			return i, pad
		end
	end
	return nil
end

function BaseService:SetPadEgg(player, padIndex, egg)
	local eggs = padEggs[player]
	if eggs then
		eggs[padIndex] = egg
	end
end

function BaseService:GetPadEggs(player)
	return padEggs[player]
end

return BaseService
