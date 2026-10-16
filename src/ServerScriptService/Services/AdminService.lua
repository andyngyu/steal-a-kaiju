-- Admin panel commands (list and who's an admin: Shared.Config.AdminConfig; the panel is KaijuUI AdminPanelController).
-- Remotes.AdminCommand (RemoteFunction): (commandId, targetUserId?, params {string}) -> ok, message
-- Every call is checked here: non-admins get nothing. Admins get player attribute IsAdmin = true (shows the panel).
-- Everything an admin does is printed to the server output as "[Admin] <who> <command> ...".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local AdminConfig = require(Config.AdminConfig)
local DevConfig = require(Config.DevConfig)
local DayNightConfig = require(Config.DayNightConfig)
local EggConfig = require(Config.EggConfig)
local BiomeConfig = require(Config.BiomeConfig)
local TrailConfig = require(Config.TrailConfig)
local MutationConfig = require(Config.MutationConfig)
local WeatherConfig = require(Config.WeatherConfig)
local KaijuConfig = require(Config.KaijuConfig)
local PenGeometry = require(ReplicatedStorage.Shared.Util.PenGeometry)
local HttpService = game:GetService("HttpService")
local EggModel = require(game:GetService("ServerScriptService").Lib.EggModel)

local Services = script.Parent
local DataService = require(Services.DataService)
local EconomyService = require(Services.EconomyService)
local SpeedService = require(Services.SpeedService)
local TrailService = require(Services.TrailService)
local BaseService = require(Services.BaseService)
local HatchService = require(Services.HatchService)
local EggService = require(Services.EggService)
local KaijuService = require(Services.KaijuService)
local LuckService = require(Services.LuckService)
local WeatherService = require(Services.WeatherService)
local TreadmillService = require(Services.TreadmillService)
local DailyRewardService = require(Services.DailyRewardService)
local GroupRewardService = require(Services.GroupRewardService)
local PetService = require(Services.PetService)

local AdminService = {}

local admins = {} -- [player] = true
local lastCall = {} -- [player] = os.clock()
local gameEvent

local function isAdmin(player)
	if DevConfig.InStudio then
		return true
	end
	if table.find(AdminConfig.UserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= AdminConfig.MinGroupRank
end

local function hrpOf(player)
	local char = player and player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function teleport(player, cframe)
	local char = player.Character
	if not (char and hrpOf(player)) then
		return false
	end
	char:PivotTo(cframe)
	return true
end

local function number(text)
	local n = tonumber((tostring(text or ""):gsub(",", "")))
	return n and n == n and n or nil
end

-- "Shocked" -> "Shocked"; "None" / unknown -> nil, ok (false when the text isn't a mutation at all)
local function mutationOf(text)
	text = tostring(text or "")
	if text == "" or text == "None" then
		return nil, true
	end
	for id in MutationConfig.ById do
		if string.lower(id) == string.lower(text) then
			return id, true
		end
	end
	return nil, false
end

-- A ready-to-hatch egg from any biome in the target's pen (same as the /egg dev command, which is Pebble Plains only),
-- optionally mutated. Returns ok, message.
local function spawnEgg(player, rarityText, sizeText, mutationText, biomeText)
	local biomeId = "PebblePlains"
	if biomeText and biomeText ~= "" then
		biomeId = nil
		for id in BiomeConfig.ById do
			if string.lower(id) == string.lower(tostring(biomeText)) then
				biomeId = id
			end
		end
		if not biomeId then
			return false, "Unknown biome " .. tostring(biomeText)
		end
	end
	local rarityId
	for _, r in EggConfig.Rarities do
		if string.lower(r.Id) == string.lower(tostring(rarityText)) then
			rarityId = r.Id
		end
	end
	if not rarityId then
		return false, "Unknown rarity " .. tostring(rarityText)
	end
	local size = number(sizeText) or EggModel.RollSize()
	size = math.clamp(size, 0.5, 10)
	if not BaseService:GetPlot(player) then
		return false, player.Name .. " has no base yet"
	end
	if not BaseService:HasRoom(player) then
		return false, player.Name .. "'s pen is full"
	end
	local level = PenGeometry.Level(BaseService:GetLevel(player))
	local x, d = BaseService:FindFreeSpot(player, 0, level.Depth / 2, size, rarityId)
	if not x then
		return false, "No free spot in " .. player.Name .. "'s pen"
	end
	local egg = EggModel.Build(biomeId, rarityId, nil, size)
	local id = egg:GetAttribute("EggId")
	if not HatchService:PlaceEgg(player, egg, x, d, nil) then
		egg:Destroy()
		return false, "Couldn't place the egg"
	end
	local entry = BaseService:GetItem(player, id)
	if entry then
		entry.HatchAt = os.time()
	end
	local mutation = mutationOf(mutationText)
	if mutation then
		HatchService:MutatePenEgg(player, id, mutation)
	end
	return true, string.format("Put a ready %s%s %s egg (%.2fx) in %s's pen", mutation and (mutation .. " ") or "", rarityId, biomeId, size, player.Name)
end

-- Any kaiju for the target: into their pen at a random spot (as if just hatched), or their inventory when the pen is
-- full. Size 0.5-10 (default 1). Returns ok, message.
local function spawnPet(player, speciesText, sizeText, mutationText)
	local species
	for id, k in KaijuConfig do
		if type(k) == "table" and k.Rarity and (string.lower(id) == string.lower(tostring(speciesText))
			or string.lower(k.DisplayName or "") == string.lower(tostring(speciesText))) then
			species = id
		end
	end
	if not species then
		return false, "Unknown pet " .. tostring(speciesText)
	end
	local mutation, validMutation = mutationOf(mutationText)
	if not validMutation then
		return false, "Unknown mutation " .. tostring(mutationText)
	end
	local size = math.clamp(number(sizeText) or 1, 0.5, 10)
	if not (DataService:Get(player) and BaseService:GetPlot(player)) then
		return false, player.Name .. "'s base isn't ready yet"
	end
	local cfg = KaijuConfig[species]
	local id = HttpService:GenerateGUID(false)
	local entry = {
		Kind = "Kaiju",
		KaijuId = id,
		Species = species,
		Rarity = cfg.Rarity,
		BiomeId = cfg.Biome ~= "Any" and cfg.Biome or "PebblePlains",
		HatchedAt = os.time(),
		Size = size,
		Level = 1,
		XP = 0,
		Mutation = mutation,
	}
	local name = string.format("%s%s (%.2fx)", mutation and (mutation .. " ") or "", cfg.DisplayName or species, size)
	if BaseService:HasRoom(player) and HatchService:SpawnItem(player, id, entry) then
		EconomyService:Publish(player)
		DataService:Save(player)
		return true, "Spawned " .. name .. " in " .. player.Name .. "'s pen"
	end
	if PetService:AddToInventory(player, id, entry) then
		return true, player.Name .. "'s pen is full: " .. name .. " went to their inventory"
	end
	return false, "Couldn't spawn that pet"
end

local function areaCFrame(caller, area)
	if area == "Base" then
		local plot = BaseService:GetPlot(caller)
		local spot = plot and (plot:FindFirstChild("EntranceMat") or plot:FindFirstChild("Zone"))
		return spot and CFrame.new(spot.Position + Vector3.new(0, 4, 0))
	end
	local lane = workspace.Map:FindFirstChild("Lane")
	local biome = lane and lane:FindFirstChild(area)
	local center = biome and biome:FindFirstChild("NestSite") and biome.NestSite:FindFirstChild("Center")
	if center then
		local p = (center:IsA("BasePart") and center.Position or center:GetPivot().Position) + Vector3.new(-16, 4, 0)
		return CFrame.lookAt(p, p + Vector3.xAxis)
	end
	return nil
end

-- [id] = function(caller, target, params) -> ok, message
local COMMANDS = {
	GiveCash = function(_, target, p)
		local amount = number(p[1])
		if not (amount and amount > 0) then
			return false, "Enter an amount"
		end
		EconomyService:AddCash(target, math.floor(amount))
		return true, "Gave " .. target.Name .. " $" .. math.floor(amount)
	end,
	GiveSpeed = function(_, target, p)
		local amount = number(p[1])
		if not (amount and amount > 0) then
			return false, "Enter an amount"
		end
		SpeedService:AddSpeed(target, math.floor(amount))
		return true, "Gave " .. target.Name .. " " .. math.floor(amount) .. " Speed"
	end,
	UnlockTrails = function(_, target)
		for _, trail in TrailConfig.List do
			TrailService:Grant(target, trail.Id)
		end
		return true, "Unlocked every trail for " .. target.Name
	end,
	SpawnEgg = function(_, target, p)
		return spawnEgg(target, p[2], nil, p[3], p[1])
	end,
	SpawnSizedEgg = function(_, target, p)
		return spawnEgg(target, p[2], p[3], nil, p[1])
	end,
	HatchEggsNow = function(_, target)
		local data = DataService:Get(target)
		local ids = {}
		for id, entry in (data and data.Pen and data.Pen.Items) or {} do
			if entry.Kind == "Egg" and not entry.StolenBy then
				table.insert(ids, id)
			end
		end
		local n = 0
		for _, id in ids do
			if HatchService:HatchNow(target, id) then
				n += 1
			end
		end
		return n > 0, n > 0 and string.format("Hatching %d of %s's eggs", n, target.Name) or (target.Name .. " has no eggs to hatch")
	end,

	-- boosts
	SetLuck = function(_, target, p)
		local m = number((tostring(p[1] or ""):gsub("^x", "")))
		if not (m and m >= 1 and m <= 100) then
			return false, "Pick a luck amount"
		end
		LuckService:SetSource(target, "Admin", m ~= 1 and m or nil) -- until they leave
		return true, string.format("%s's Luck is now x%s (admin x%s until they leave)", target.Name, tostring(target:GetAttribute("Luck")), tostring(m))
	end,
	DailyBoost = function(_, target, p)
		local kind = tostring(p[1] or "")
		local minutes = number(p[2]) or 10
		if not (minutes > 0 and minutes <= 600) then
			return false, "Minutes must be 1-600"
		end
		local mult = kind == "Luck" and 1.5 or 2
		if not DailyRewardService:GrantBoost(target, kind, mult, math.floor(minutes * 60)) then
			return false, "Couldn't give that boost"
		end
		return true, string.format("Gave %s a x%s %s boost for %d min", target.Name, tostring(mult), kind, minutes)
	end,
	LightningBoost = function(_, target)
		TreadmillService:GrantLightning(target)
		return true, "Gave " .. target.Name .. " the x4 lightning boost"
	end,
	LightningBolt = function(_, target)
		if not TreadmillService:SpawnBolt(target) then
			return false, target.Name .. " isn't on their treadmill"
		end
		return true, "A lightning bolt popped up for " .. target.Name
	end,

	-- pets
	SpawnPet = function(_, target, p)
		return spawnPet(target, p[1], p[2], p[3])
	end,

	-- mutations
	MutatePenEggs = function(_, target, p)
		local mutation = mutationOf(p[1])
		if not mutation then
			return false, "Pick a mutation"
		end
		local data = DataService:Get(target)
		local ids = {}
		for id, entry in (data and data.Pen and data.Pen.Items) or {} do
			if entry.Kind == "Egg" and not entry.Mutation and not entry.StolenBy then
				table.insert(ids, id)
			end
		end
		local n = 0
		for _, id in ids do
			if HatchService:MutatePenEgg(target, id, mutation) then
				n += 1
			end
		end
		return n > 0, n > 0 and string.format("Made %d of %s's eggs %s", n, target.Name, mutation) or (target.Name .. " has no unmutated eggs")
	end,
	MutatePets = function(_, target, p)
		local mutation, valid = mutationOf(p[1])
		if not valid then
			return false, "Pick a mutation"
		end
		local list = {}
		BaseService:ForEachItem(target, function(id, entry, model)
			if entry.Kind == "Kaiju" and not entry.StolenBy and not (model and model:GetAttribute("StealBy")) then
				table.insert(list, { id = id, entry = entry })
			end
		end)
		for _, k in list do
			k.entry.Mutation = mutation
			KaijuService:Refresh(target, k.id, k.entry)
		end
		EconomyService:Publish(target)
		DataService:Save(target)
		return #list > 0, #list > 0 and string.format("%s %d of %s's equipped pets", mutation and ("Made " .. mutation .. ":") or "Cleared mutations on", #list, target.Name)
			or (target.Name .. " has no equipped pets")
	end,
	MutateNests = function(_, _, p)
		local mutation = mutationOf(p[1])
		if not mutation then
			return false, "Pick a mutation"
		end
		local n = 0
		for _, nest in EggService:GetNestEggs() do
			if not nest.egg:GetAttribute("Mutation") and EggService:MutateEgg(nest.egg, mutation) then
				n += 1
			end
		end
		return n > 0, n > 0 and string.format("Made %d nest eggs %s", n, mutation) or "No unmutated nest eggs (night?)"
	end,

	-- weather
	StartWeather = function(_, _, p)
		local seconds = number(p[2])
		seconds = seconds and math.clamp(seconds, 10, 3600) or nil
		local id = WeatherService:Force(nil, tostring(p[1] or ""), seconds)
		if not id then
			return false, "Unknown weather " .. tostring(p[1])
		end
		local e = WeatherConfig.ById[id]
		return true, string.format("%s started%s", e and e.DisplayName or id, seconds and (" for " .. seconds .. " s") or "")
	end,
	StopWeather = function()
		if not WeatherService:GetCurrent() then
			return false, "No weather is running"
		end
		WeatherService:Stop()
		return true, "Weather stopped"
	end,

	-- rewards
	ResetDaily = function(_, target)
		return DailyRewardService:ResetForTesting(target), target.Name .. " can claim today's daily reward again"
	end,
	ResetGroupReward = function(_, target)
		return GroupRewardService:ResetForTesting(target), target.Name .. " can claim the group reward again"
	end,
	NightNow = function()
		workspace:SetAttribute("DayNightEpoch", workspace:GetServerTimeNow() + 0.5 - DayNightConfig.DaySeconds)
		return true, "Night falls - every nest is resetting"
	end,
	DayNow = function()
		workspace:SetAttribute("DayNightEpoch", workspace:GetServerTimeNow())
		return true, "It's day - the 5 minute timer restarted"
	end,
	Announce = function(caller, _, p)
		local text = tostring(p[1] or ""):sub(1, 200)
		if text:match("^%s*$") then
			return false, "Type a message"
		end
		gameEvent:FireAllClients("DevNotice", { Text = text, Kind = "warn" })
		return true, "Announced to everyone"
	end,
	GoArea = function(caller, _, p)
		local cf = areaCFrame(caller, tostring(p[1]))
		if not cf then
			return false, "Unknown area " .. tostring(p[1])
		end
		return teleport(caller, cf), "Teleported to " .. tostring(p[1])
	end,
	GoTo = function(caller, target)
		local hrp = hrpOf(target)
		if not hrp or target == caller then
			return false, "Pick someone else"
		end
		return teleport(caller, hrp.CFrame * CFrame.new(0, 0, 5)), "Teleported to " .. target.Name
	end,
	Bring = function(caller, target)
		local hrp = hrpOf(caller)
		if not hrp or target == caller then
			return false, "Pick someone else"
		end
		return teleport(target, hrp.CFrame * CFrame.new(0, 0, -5)), "Brought " .. target.Name
	end,
	Respawn = function(_, target)
		target:LoadCharacter()
		return true, "Respawned " .. target.Name
	end,
	Kick = function(caller, target, p)
		if target == caller then
			return false, "You can't kick yourself"
		end
		local reason = tostring(p[1] or "")
		target:Kick(reason ~= "" and reason or "Kicked by an admin.")
		return true, "Kicked " .. target.Name
	end,
	WipeData = function(caller, target)
		DataService:Wipe(target, target == caller and "Your data was wiped. Rejoin to start fresh."
			or "Your data was reset by an admin. Rejoin to start fresh.")
		return true, "Wiped " .. target.Name .. "'s data"
	end,
}

local function run(caller, id, targetUserId, params)
	if not admins[caller] then
		return false, "Not an admin"
	end
	local now = os.clock()
	if lastCall[caller] and now - lastCall[caller] < 0.25 then
		return false, "Slow down"
	end
	lastCall[caller] = now
	local command = type(id) == "string" and AdminConfig.ById[id]
	local fn = command and COMMANDS[id]
	if not fn then
		return false, "Unknown command"
	end
	local target = caller
	if command.Target then
		target = typeof(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId) or caller
		if not target then
			return false, "That player left"
		end
	end
	local clean = {}
	if type(params) == "table" then
		for i = 1, 4 do
			clean[i] = params[i] ~= nil and tostring(params[i]):sub(1, 200) or nil
		end
	end
	local ok, a, b = pcall(fn, caller, target, clean)
	if not ok then
		warn("[Admin]", caller.Name, id, "failed:", a)
		return false, "Error: " .. tostring(a)
	end
	print("[Admin]", caller.Name, id, command.Target and ("-> " .. target.Name) or "", table.concat(clean, " "), "|", tostring(b))
	return a == true, tostring(b or "")
end

function AdminService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local remote = ReplicatedStorage.Remotes:FindFirstChild("AdminCommand") or Instance.new("RemoteFunction")
	remote.Name = "AdminCommand"
	remote.OnServerInvoke = run
	remote.Parent = ReplicatedStorage.Remotes
end

function AdminService:Start()
	local function onPlayer(player)
		if isAdmin(player) then
			admins[player] = true
			player:SetAttribute("IsAdmin", true)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		admins[p] = nil
		lastCall[p] = nil
	end)
end

return AdminService
