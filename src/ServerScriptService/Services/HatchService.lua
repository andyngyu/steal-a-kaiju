-- Pen eggs: species roll on placement, countdown, owner hatches it by hand once ready, then it becomes a wandering kaiju.
-- Restores pen contents from saved data on join.
-- Size: the egg's Size roll is saved on the entry; the kaiju hatches at that size +/- EggConfig.KaijuSizeJitter, and its
-- income is CashPerSecond x Size. Grand hatches (EggConfig.IsGrand: Epic+ or Huge+) get a longer build-up
-- (BaseConfig.Hatch.GrandAnimSeconds) and are announced to everyone (GameEvent "HatchAnnouncement").
-- Pen egg model attributes: State="Pen", ItemId, OwnerUserId, PlacedAt, HatchAt (os.time; compare with workspace:GetServerTimeNow()),
--   Ready (bool), HatchStartedAt (server time, hatch animation running), HatchAnim (its length in seconds),
--   HatchGrand (bool), DropFrom (Vector3) + DroppedAt (server time) for the toss arc.
-- GiveEgg (store bundles, rewards) drops an egg from the sky straight into the pen, ignoring the pen's capacity so a
-- paid egg is never refused; fires GameEvent EggGiven {ItemId, BiomeId, Rarity, Size, SizeTier}.
-- Auto Hatch setting (SettingsService "AutoHatch"): ready eggs hatch by themselves, one per second per player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = ReplicatedStorage.Shared.Config
local KaijuConfig = require(Config.KaijuConfig)
local EggConfig = require(Config.EggConfig)
local BaseConfig = require(Config.BaseConfig)
local DevConfig = require(Config.DevConfig)
local BiomeConfig = require(Config.BiomeConfig)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local PenGeometry = require(ReplicatedStorage.Shared.Util.PenGeometry)
local KaijuStats = require(ReplicatedStorage.Shared.Util.KaijuStats)

local EggModel = require(game:GetService("ServerScriptService").Lib.EggModel)

local DataService = require(script.Parent.DataService)
local BaseService = require(script.Parent.BaseService)
local KaijuService = require(script.Parent.KaijuService)
local IndexService = require(script.Parent.IndexService)

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

-- fromMenu: the UI's Eggs panel (Remotes.HatchEgg) hatches from any distance; the prompt needs the owner nearby.
local function tryHatch(owner, id, player, fromMenu)
	if player ~= owner then
		gameEvent:FireClient(player, "NotYourEgg", {})
		return
	end
	local entry, egg = BaseService:GetItem(owner, id)
	if not (entry and egg and entry.Kind == "Egg") or os.time() < entry.HatchAt or egg:GetAttribute("HatchStartedAt") then
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not fromMenu and (not hrp or (hrp.Position - egg.PrimaryPart.Position).Magnitude - egg.PrimaryPart.Size.X / 2 > BaseConfig.Hatch.PromptDistance + 4) then
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
			Level = 1,
			XP = 0,
		}
		local kaiju = KaijuService:Spawn(owner, id, kaijuEntry, spot, true)
		BaseService:SetItem(owner, id, kaiju, kaijuEntry)
		local data = DataService:Get(owner)
		data.Stats.EggsHatched += 1
		local isNew = IndexService:Record(owner, entry.Species, size)
		DataService:Save(owner)
		local tier = EggConfig.SizeTierName(size)
		local payload = {
			ItemId = id,
			Species = entry.Species,
			Rarity = kaijuEntry.Rarity,
			Size = size,
			SizeTier = tier,
			CashPerSecond = KaijuStats.EntryCashPerSecond(kaijuEntry),
			Grand = grand,
			New = isNew, -- first of this species for this player (Kaiju Index)
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
-- Gifted eggs (GiveEgg) don't count towards Stats.EggsDelivered.
function HatchService:PlaceEgg(player, egg, x, d, fromPos, gifted)
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
	if not gifted then
		DataService:Get(player).Stats.EggsDelivered += 1
	end
	DataService:Save(player)
	log(player.Name, gifted and "was given" or "placed", rarity, "egg ->", species, "ready in", entry.HatchAt - now, "s")
	return true
end

local SIZE_MIN, SIZE_MAX = math.huge, 0
for _, t in EggConfig.SizeTiers do
	SIZE_MIN = math.min(SIZE_MIN, t.Min)
	SIZE_MAX = math.max(SIZE_MAX, t.Max)
end

-- Puts a new egg into the player's pen (it falls from the sky onto the free spot nearest the middle). size is optional
-- (a normal roll when nil). Returns the egg's item id, or nil for an unknown biome/rarity or when the player's data or
-- plot isn't ready yet (call again later - a dev product receipt should return NotProcessedYet).
function HatchService:GiveEgg(player, biomeId, rarityId, size)
	if not (BiomeConfig.ById[biomeId] and EggConfig.RarityById[rarityId]) then
		warn("[HatchService] GiveEgg: unknown biome or rarity", biomeId, rarityId)
		return nil
	end
	if not (DataService:Get(player) and BaseService:GetPlot(player)) then
		return nil
	end
	size = type(size) == "number" and math.clamp(size, SIZE_MIN, SIZE_MAX) or EggModel.RollSize()
	local middle = PenGeometry.Level(BaseService:GetLevel(player)).Depth / 2
	local x, d = BaseService:FindFreeSpot(player, 0, middle, size, rarityId)
	if not x then
		x, d = 0, middle -- packed with eggs: share the middle rather than lose a purchase
	end
	local egg = EggModel.Build(biomeId, rarityId, nil, size)
	local id = egg:GetAttribute("EggId")
	local sky = BaseService:PenToWorld(player, x, d) + Vector3.new(0, 30, 0)
	if not self:PlaceEgg(player, egg, x, d, sky, true) then
		return nil
	end
	gameEvent:FireClient(player, "EggGiven", {
		ItemId = id,
		BiomeId = biomeId,
		Rarity = rarityId,
		Size = size,
		SizeTier = EggConfig.SizeTierName(size),
	})
	return id
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
	ReplicatedStorage.Remotes:WaitForChild("HatchEgg").OnServerEvent:Connect(function(player, id)
		if type(id) == "string" then
			tryHatch(player, id, player, true)
		end
	end)
	local runtime = workspace:FindFirstChild("Runtime") or Instance.new("Folder")
	runtime.Name = "Runtime"
	runtime.Parent = workspace
	eggFolder = runtime:FindFirstChild("Eggs") or Instance.new("Folder")
	eggFolder.Name = "Eggs"
	eggFolder.Parent = runtime
end

function HatchService:Start()
	DataService:OnLoaded(restore)

	local settingsModule = script.Parent:FindFirstChild("SettingsService")
	local SettingsService = settingsModule and require(settingsModule)
	local function autoHatch(player)
		return SettingsService ~= nil and SettingsService:Get(player, "AutoHatch") == true
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		local now = os.time()
		for _, player in Players:GetPlayers() do
			local auto = autoHatch(player)
			local autoId = nil
			BaseService:ForEachItem(player, function(id, entry, egg)
				if entry.Kind ~= "Egg" or not egg or egg:GetAttribute("HatchStartedAt") then
					return
				end
				if auto and not autoId and now >= entry.HatchAt and egg:GetAttribute("Ready") then
					autoId = id
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
			if autoId then
				tryHatch(player, autoId, player, true)
			end
		end
	end)
end

return HatchService
