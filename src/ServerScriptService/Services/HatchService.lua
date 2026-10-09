-- Pad eggs: species roll on placement, countdown, hatch into a kaiju display. Restores pads from saved data on join.
-- Timestamps are os.time() (Unix seconds); clients can compare HatchAt with workspace:GetServerTimeNow().
-- Egg model attributes on pads: State="Pad", OwnerUserId, PadIndex, PlacedAt, HatchAt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = ReplicatedStorage.Shared.Config
local KaijuConfig = require(Config.KaijuConfig)
local EggConfig = require(Config.EggConfig)
local DevConfig = require(Config.DevConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Lib = game:GetService("ServerScriptService").Lib
local EggModel = require(Lib.EggModel)
local KaijuModel = require(Lib.KaijuModel)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)

local HatchService = {}

local rng = Random.new()
local gameEvent
local runtime

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Hatch]", ...)
	end
end

local function runtimeFolder(name)
	local f = runtime:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = runtime
	end
	return f
end

-- Species from the egg's biome + rarity. Falls back to biome "Any" (Secret), then to lower rarities in the same biome.
function HatchService:RollSpecies(biomeId, rarityId)
	local function pool(rarity, anyBiome)
		local list = {}
		for id, cfg in KaijuConfig do
			if cfg.Rarity == rarity and (cfg.Biome == biomeId or (anyBiome and cfg.Biome == "Any")) then
				table.insert(list, id)
			end
		end
		table.sort(list)
		return list
	end
	local order = EggConfig.RarityById[rarityId].Order
	for o = order, 1, -1 do
		local list = pool(EggConfig.Rarities[o].Id, true)
		if #list > 0 then
			return list[rng:NextInteger(1, #list)]
		end
	end
	error("no kaiju available for " .. biomeId)
end

local function hatchSeconds(species)
	if DevConfig.FastHatch then
		return DevConfig.FastHatchSeconds
	end
	return KaijuConfig[species].HatchSeconds
end

local function padTop(pad)
	return pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
end

local function countdown(egg)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Countdown"
	bb.Size = UDim2.fromOffset(120, 40)
	bb.StudsOffsetWorldSpace = Vector3.new(0, EggConfig.Size.Y / 2 + 1.4, 0)
	bb.MaxDistance = 80
	local l = Instance.new("TextLabel")
	l.Name = "Time"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	l.Text = ""
	l.Parent = bb
	bb.Parent = egg.PrimaryPart
	return l
end

local function placeEggModel(player, padIndex, egg, entry)
	local pad = BaseService:GetPadPart(player, padIndex)
	EggModel.SetPhysics(egg, true)
	egg:PivotTo(CFrame.new(padTop(pad) + Vector3.new(0, EggConfig.Size.Y / 2, 0)))
	egg:SetAttribute("State", "Pad")
	egg:SetAttribute("OwnerUserId", player.UserId)
	egg:SetAttribute("PadIndex", padIndex)
	egg:SetAttribute("PlacedAt", entry.PlacedAt)
	egg:SetAttribute("HatchAt", entry.HatchAt)
	local prompt = egg.PrimaryPart:FindFirstChild("Prompt")
	if prompt then
		prompt.Enabled = false -- stealing from bases comes in Phase 7
	end
	countdown(egg)
	egg.Parent = runtimeFolder("Eggs")
end

local function placeKaijuModel(player, padIndex, entry)
	local pad = BaseService:GetPadPart(player, padIndex)
	local model = KaijuModel.Build(entry.Species)
	local top = padTop(pad)
	model:PivotTo(CFrame.lookAt(top, top + BaseService:GetFacing(player)))
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PadIndex", padIndex)
	model:SetAttribute("KaijuId", entry.KaijuId)
	model.Parent = runtimeFolder("Kaiju")
	return model
end

-- Called by EggService when a carried egg is delivered. `egg` is a fresh server-owned model.
function HatchService:PlaceEgg(player, padIndex, egg)
	local now = os.time()
	local biomeId, rarity = egg:GetAttribute("BiomeId"), egg:GetAttribute("Rarity")
	local species = self:RollSpecies(biomeId, rarity)
	local entry = {
		Kind = "Egg",
		EggId = egg:GetAttribute("EggId"),
		BiomeId = biomeId,
		Rarity = rarity,
		Species = species,
		PlacedAt = now,
		HatchAt = now + hatchSeconds(species),
	}
	placeEggModel(player, padIndex, egg, entry)
	if not BaseService:SetPad(player, padIndex, egg, entry) then
		return false
	end
	local data = DataService:Get(player)
	data.Stats.EggsDelivered += 1
	DataService:Save(player)
	log(player.Name, "placed", rarity, "egg on pad", padIndex, "->", species, "in", entry.HatchAt - now, "s")
	return true
end

local function hatch(player, padIndex, entry)
	local kaijuEntry = {
		Kind = "Kaiju",
		KaijuId = entry.EggId,
		Species = entry.Species,
		Rarity = KaijuConfig[entry.Species].Rarity,
		BiomeId = entry.BiomeId,
		HatchedAt = entry.HatchAt,
	}
	local model = placeKaijuModel(player, padIndex, kaijuEntry)
	BaseService:SetPad(player, padIndex, model, kaijuEntry)
	local data = DataService:Get(player)
	data.Stats.EggsHatched += 1
	DataService:Save(player)
	gameEvent:FireClient(player, "EggHatched", { PadIndex = padIndex, Species = entry.Species, Rarity = kaijuEntry.Rarity })
	log(player.Name, "hatched", entry.Species, "on pad", padIndex)
end

local function restore(player, data)
	if not BaseService:GetPlot(player) then
		return
	end
	for key, entry in data.Pads do
		local i = tonumber(key)
		if not (i and BaseService:GetPadPart(player, i)) or not KaijuConfig[entry.Species] then
			warn("[HatchService] dropping invalid pad entry", key, entry.Species)
			data.Pads[key] = nil
			continue
		end
		if entry.Kind == "Egg" then
			local egg = EggModel.Build(entry.BiomeId, entry.Rarity, entry.EggId)
			placeEggModel(player, i, egg, entry)
			BaseService:SetPad(player, i, egg, entry)
		else
			BaseService:SetPad(player, i, placeKaijuModel(player, i, entry), entry)
		end
	end
	log("restored pads for", player.Name)
end

function HatchService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	runtime = workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = workspace
end

function HatchService:Start()
	DataService:OnLoaded(restore)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		local now = os.time()
		for _, player in Players:GetPlayers() do
			local due = {}
			BaseService:ForEachPad(player, function(i, entry, model)
				if entry.Kind ~= "Egg" then
					return
				end
				local left = entry.HatchAt - now
				if left <= 0 then
					table.insert(due, { i, entry })
				elseif model then
					local label = model.PrimaryPart:FindFirstChild("Countdown") and model.PrimaryPart.Countdown.Time
					if label then
						label.Text = Format.Clock(left)
					end
				end
			end)
			for _, d in due do
				local ok, err = pcall(hatch, player, d[1], d[2])
				if not ok then
					warn("[HatchService] hatch failed:", err)
				end
			end
		end
	end)
end

return HatchService
