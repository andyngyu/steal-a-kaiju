-- Pen eggs: species roll on placement, countdown, owner hatches it by hand once ready, then it becomes a wandering kaiju.
-- Restores pen contents from saved data on join.
-- Size: the egg's Size roll is saved on the entry; the kaiju hatches at that size +/- EggConfig.KaijuSizeJitter, and its
-- income is CashPerSecond x Size. Grand hatches (EggConfig.IsGrand: Epic+ or Huge+) get a longer build-up
-- (BaseConfig.Hatch.GrandAnimSeconds) and are announced to everyone (GameEvent "HatchAnnouncement").
-- Pen egg model attributes: State="Pen", ItemId, OwnerUserId, PlacedAt, HatchAt (os.time; compare with workspace:GetServerTimeNow()),
--   Ready (bool), HatchStartedAt (server time, hatch animation running), HatchAnim (its length in seconds),
--   HatchGrand (bool), DropFrom (Vector3) + DroppedAt (server time) for the toss arc.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage.Shared.Config
local KaijuConfig = require(Config.KaijuConfig)
local EggConfig = require(Config.EggConfig)
local BaseConfig = require(Config.BaseConfig)
local DevConfig = require(Config.DevConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local EggModel = require(game:GetService("ServerScriptService").Lib.EggModel)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local KaijuService = require(script.Parent.KaijuService)

local HatchService = {}

local rng = Random.new()
local gameEvent
local eggFolder

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Hatch]", ...)
	end
end

-- Species from the egg's biome + rarity. Falls back to biome "Any" (Secret), then to lower rarities in the same biome.
function HatchService:RollSpecies(biomeId, rarityId)
	local order = EggConfig.RarityById[rarityId].Order
	for o = order, 1, -1 do
		local rarity = EggConfig.Rarities[o].Id
		local list = {}
		for id, cfg in KaijuConfig do
			if cfg.Rarity == rarity and (cfg.Biome == biomeId or cfg.Biome == "Any") then
				table.insert(list, id)
			end
		end
		if #list > 0 then
			table.sort(list)
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

local function countdown(egg, entry)
	local rarityId = entry.Rarity
	local rarity = EggConfig.RarityById[rarityId]
	local bb = Instance.new("BillboardGui")
	bb.Name = "Countdown"
	bb.Size = UDim2.fromOffset(170, 64)
	bb.StudsOffsetWorldSpace = Vector3.new(0, egg.PrimaryPart.Size.Y / 2 + 1.8, 0)
	bb.MaxDistance = 80 + egg.PrimaryPart.Size.Y * 10
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = bb
	for order, spec in { { "Title", EggModel.Label(rarityId, entry.Size), rarity.Color, 0.45 }, { "Time", "", Color3.new(1, 1, 1), 0.55 } } do
		local l = Instance.new("TextLabel")
		l.Name = spec[1]
		l.LayoutOrder = order
		l.Size = UDim2.new(1, 0, spec[4], 0)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = spec[3]
		l.TextStrokeTransparency = 0.15
		l.Text = spec[2]
		l.Parent = bb
	end
	bb.Parent = egg.PrimaryPart
end

local function tryHatch(owner, id, player)
	if player ~= owner then
		gameEvent:FireClient(player, "NotYourEgg", {})
		return
	end
	local entry, egg = BaseService:GetItem(owner, id)
	if not (entry and egg and entry.Kind == "Egg") or os.time() < entry.HatchAt or egg:GetAttribute("HatchStartedAt") then
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - egg.PrimaryPart.Position).Magnitude - egg.PrimaryPart.Size.X / 2 > BaseConfig.Hatch.PromptDistance + 4 then
		return
	end
	local jitter = EggConfig.KaijuSizeJitter
	local size = math.floor((entry.Size or 1) * rng:NextNumber(1 - jitter, 1 + jitter) * 100 + 0.5) / 100
	local grand = EggConfig.IsGrand(KaijuConfig[entry.Species].Rarity, size)
	local anim = grand and BaseConfig.Hatch.GrandAnimSeconds or BaseConfig.Hatch.AnimSeconds
	egg:SetAttribute("HatchAnim", anim)
	egg:SetAttribute("HatchGrand", grand)
	egg:SetAttribute("HatchStartedAt", workspace:GetServerTimeNow())
	egg.PrimaryPart.Prompt.Enabled = false
	local spot = egg.PrimaryPart.Position
	task.delay(anim, function()
		local still = BaseService:GetItem(owner, id)
		if still ~= entry or owner.Parent ~= Players then
			return
		end
		local kaijuEntry = {
			Kind = "Kaiju",
			KaijuId = id,
			Species = entry.Species,
			Rarity = KaijuConfig[entry.Species].Rarity,
			BiomeId = entry.BiomeId,
			HatchedAt = os.time(),
			Size = size,
		}
		local kaiju = KaijuService:Spawn(owner, id, kaijuEntry, spot, true)
		BaseService:SetItem(owner, id, kaiju, kaijuEntry)
		local data = DataService:Get(owner)
		data.Stats.EggsHatched += 1
		DataService:Save(owner)
		local tier = EggConfig.SizeTierName(size)
		local payload = {
			ItemId = id,
			Species = entry.Species,
			Rarity = kaijuEntry.Rarity,
			Size = size,
			SizeTier = tier,
			CashPerSecond = KaijuConfig[entry.Species].CashPerSecond * size,
			Grand = grand,
		}
		gameEvent:FireClient(owner, "EggHatched", payload)
		if grand then
			gameEvent:FireAllClients("HatchAnnouncement", {
				UserId = owner.UserId,
				PlayerName = owner.DisplayName,
				Species = entry.Species,
				DisplayName = KaijuConfig[entry.Species].DisplayName,
				Rarity = kaijuEntry.Rarity,
				Size = size,
				SizeTier = tier,
			})
		end
		log(owner.Name, "hatched", tier, entry.Species, "size", size)
	end)
end

-- Same as the owner holding the Hatch prompt (used by Studio test commands).
function HatchService:TryHatch(player, id)
	tryHatch(player, id, player)
end

local function showEgg(player, id, egg, entry, fromPos)
	local pos = BaseService:PenToWorld(player, entry.X, entry.D)
	EggModel.SetPhysics(egg, true)
	egg:PivotTo(CFrame.new(pos + Vector3.new(0, egg.PrimaryPart.Size.Y / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	egg:SetAttribute("State", "Pen")
	egg:SetAttribute("ItemId", id)
	egg:SetAttribute("OwnerUserId", player.UserId)
	egg:SetAttribute("PlacedAt", entry.PlacedAt)
	egg:SetAttribute("HatchAt", entry.HatchAt)
	egg:SetAttribute("Ready", os.time() >= entry.HatchAt)
	if fromPos then
		egg:SetAttribute("DropFrom", fromPos)
		egg:SetAttribute("DroppedAt", workspace:GetServerTimeNow())
	end
	local prompt = egg.PrimaryPart.Prompt
	prompt.ActionText = "Hatch"
	prompt.ObjectText = EggModel.Label(entry.Rarity, entry.Size)
	prompt.HoldDuration = BaseConfig.Hatch.HoldSeconds
	prompt.MaxActivationDistance = BaseConfig.Hatch.PromptDistance + egg.PrimaryPart.Size.X / 2
	prompt.Enabled = os.time() >= entry.HatchAt
	prompt.Triggered:Connect(function(who)
		tryHatch(player, id, who)
	end)
	countdown(egg, entry)
	local time = egg.PrimaryPart.Countdown.Time
	if os.time() >= entry.HatchAt then
		time.Text = "Ready!"
		time.TextColor3 = Color3.fromHex("6BE04A")
	else
		time.Text = Format.Duration(entry.HatchAt - os.time())
	end
	egg.Parent = eggFolder
end

-- Called by EggService when a carried egg is dropped inside the owner's pen at pen-local (x, d).
-- `egg` is a fresh server-owned model; fromPos is where it was carried (for the toss animation).
function HatchService:PlaceEgg(player, egg, x, d, fromPos)
	local now = os.time()
	local id = egg:GetAttribute("EggId")
	local biomeId, rarity = egg:GetAttribute("BiomeId"), egg:GetAttribute("Rarity")
	local species = self:RollSpecies(biomeId, rarity)
	local entry = {
		Kind = "Egg",
		EggId = id,
		BiomeId = biomeId,
		Rarity = rarity,
		Species = species,
		PlacedAt = now,
		HatchAt = now + hatchSeconds(species),
		X = x,
		D = d,
		Size = egg:GetAttribute("Size") or 1,
	}
	showEgg(player, id, egg, entry, fromPos)
	if not BaseService:SetItem(player, id, egg, entry) then
		return false
	end
	local data = DataService:Get(player)
	data.Stats.EggsDelivered += 1
	DataService:Save(player)
	log(player.Name, "placed", rarity, "egg ->", species, "ready in", entry.HatchAt - now, "s")
	return true
end

local function restore(player, data)
	if not BaseService:GetPlot(player) then
		return
	end
	for id, entry in data.Pen.Items do
		if not KaijuConfig[entry.Species] then
			warn("[HatchService] dropping unknown species", entry.Species)
			data.Pen.Items[id] = nil
			continue
		end
		if entry.Kind == "Egg" then
			local egg = EggModel.Build(entry.BiomeId, entry.Rarity, id, entry.Size)
			showEgg(player, id, egg, entry, nil)
			BaseService:SetItem(player, id, egg, entry)
		else
			local spot = BaseService:RandomSpot(player, BaseConfig.Wander.Inset)
			BaseService:SetItem(player, id, KaijuService:Spawn(player, id, entry, spot, false), entry)
		end
	end
	log("restored pen for", player.Name)
end

function HatchService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local runtime = workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = workspace
	eggFolder = runtime:FindFirstChild("Eggs") or Instance.new("Folder")
	eggFolder.Name = "Eggs"
	eggFolder.Parent = runtime
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
			BaseService:ForEachItem(player, function(_, entry, egg)
				if entry.Kind ~= "Egg" or not egg or egg:GetAttribute("HatchStartedAt") then
					return
				end
				local label = egg.PrimaryPart:FindFirstChild("Countdown")
				local left = entry.HatchAt - now
				if left > 0 then
					if label then
						label.Time.Text = Format.Duration(left)
					end
				elseif not egg:GetAttribute("Ready") or not egg.PrimaryPart.Prompt.Enabled then
					egg:SetAttribute("Ready", true)
					egg.PrimaryPart.Prompt.Enabled = true
					if label then
						label.Time.Text = "Ready!"
						label.Time.TextColor3 = Color3.fromHex("6BE04A")
					end
					gameEvent:FireClient(player, "EggReady", { Rarity = entry.Rarity })
				end
			end)
		end
	end)
end

return HatchService
