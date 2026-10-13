-- Server-wide weather events and egg mutations (Shared.Config.WeatherConfig / MutationConfig).
-- One event at a time: picked by Weight every IntervalSeconds, runs DurationSeconds. While it runs:
--   Luck       everyone's Luck x event.Luck (LuckService source "Weather")
--   Mutations  every TickSeconds: nest eggs (EggService:MutateEgg) and incubating pen eggs (HatchService:MutatePenEgg,
--              the owner's Luck applies) can catch the event's mutation; an egg keeps the first one it gets.
--              Nest eggs use the Luck of the luckiest player near them (NEARBY_LUCK_STUDS), or the event's own Luck if
--              that's higher / nobody is close - so Luck boosts (passes, daily boosts, group reward) raise the chance
--              of the eggs you're hunting. Strikes also aim at eggs near lucky players more often.
--   Weather egg every WeatherEggEvery seconds one nest egg is mutated for sure (GameEvent WeatherEggSpawned to all)
--   Strikes    lightning / meteors / crystal hail (event.Strike) hit nest eggs (mutating them) or land near players;
--              GameEvent WeatherStrike {Kind, Position, Delay, Mutation?} so clients draw it. Hail knocks back a little.
--   Guardians  workspace attribute WeatherGuardianSpeed (GuardianService multiplies guardian speeds by it)
-- Nothing mutates during the night reset (the nests are empty).
-- Workspace attributes: WeatherId, WeatherStartedAt, WeatherEndsAt (server time), NextWeatherAt.
-- GameEvents (all clients): WeatherStarted {Id, EndsAt, Forced}, WeatherEnded {Id}, WeatherEggSpawned {Mutation, Rarity,
--   BiomeId, SizeTier}, WeatherStrike. To the owner: PenEggMutated (HatchService).
-- Chat (game owner, or anyone in Studio with DevConfig.AdminCommands): /weather <name> [seconds], /weather stop,
--   /weather list, /weather next   (names: WeatherConfig.Find - "thunder", "blood", "eclipse"...)
-- Command bar: game.ServerStorage.DevHooks.Call:Invoke(userId, "WeatherService", "Force", "Thunderstorm", 120)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Debris = game:GetService("Debris")

local Config = ReplicatedStorage.Shared.Config
local WeatherConfig = require(Config.WeatherConfig)
local MutationConfig = require(Config.MutationConfig)
local DevConfig = require(Config.DevConfig)
local EggConfig = require(Config.EggConfig)
local Luck = require(ReplicatedStorage.Shared.Util.Luck)

local LuckService = require(script.Parent.LuckService)
local EggService = require(script.Parent.EggService)
local HatchService = require(script.Parent.HatchService)
local DataService = require(script.Parent.DataService)

local WeatherService = {}

local rng = Random.new()
local gameEvent
local current -- the running event's config, or nil
local endsAt = 0
local nextAt = 0
local tickAt, eggAt, strikeAt = 0, 0, 0

local function log(...)
	if DevConfig.VerboseLogging then
		print("[Weather]", ...)
	end
end

local function between(range)
	return rng:NextNumber(range[1], range[2])
end

local function pickEvent()
	local total = 0
	for _, e in WeatherConfig.Events do
		total += e.Weight
	end
	local pick = rng:NextNumber() * total
	for _, e in WeatherConfig.Events do
		pick -= e.Weight
		if pick <= 0 then
			return e
		end
	end
	return WeatherConfig.Events[1]
end

local function setLuck(player)
	LuckService:SetSource(player, "Weather", current and current.Luck or nil)
end

local function stopEvent(reason)
	if not current then
		return
	end
	local id = current.Id
	current = nil
	workspace:SetAttribute("WeatherId", nil)
	workspace:SetAttribute("WeatherStartedAt", nil)
	workspace:SetAttribute("WeatherEndsAt", nil)
	workspace:SetAttribute("WeatherGuardianSpeed", nil)
	for _, p in Players:GetPlayers() do
		setLuck(p)
	end
	nextAt = workspace:GetServerTimeNow() + between(WeatherConfig.IntervalSeconds)
	workspace:SetAttribute("NextWeatherAt", nextAt)
	gameEvent:FireAllClients("WeatherEnded", { Id = id })
	log(id, "ended", reason or "")
end

local function startEvent(e, duration, forced)
	if current then
		stopEvent("replaced")
	end
	local now = workspace:GetServerTimeNow()
	current = e
	endsAt = now + (duration or between(e.DurationSeconds))
	tickAt = now + WeatherConfig.TickSeconds
	eggAt = now + math.min(12, (e.WeatherEggEvery or 60) * 0.3)
	strikeAt = now + 2.5
	workspace:SetAttribute("WeatherId", e.Id)
	workspace:SetAttribute("WeatherStartedAt", now)
	workspace:SetAttribute("WeatherEndsAt", endsAt)
	workspace:SetAttribute("WeatherGuardianSpeed", e.GuardianSpeed)
	workspace:SetAttribute("NextWeatherAt", nil)
	for _, p in Players:GetPlayers() do
		setLuck(p)
	end
	gameEvent:FireAllClients("WeatherStarted", { Id = e.Id, EndsAt = endsAt, Forced = forced == true })
	log(e.Id, "started for", math.floor(endsAt - now), "s")
end

local function unmutatedNestEggs()
	local list = {}
	for _, n in EggService:GetNestEggs() do
		if not n.egg:GetAttribute("Mutation") then
			table.insert(list, n)
		end
	end
	return list
end

-- The Luck that applies to a nest egg: the luckiest player within NEARBY_LUCK_STUDS (their Luck already includes the
-- weather's own boost), never less than the event's Luck.
local NEARBY_LUCK_STUDS = 70
local function nearbyLuck(position, eventLuck)
	local best = eventLuck or 1
	for _, p in Players:GetPlayers() do
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - position).Magnitude <= NEARBY_LUCK_STUDS then
			best = math.max(best, LuckService:Get(p))
		end
	end
	return best
end

local function mutationTick()
	if EggService:IsNight() then
		return
	end
	local e = current
	-- nest eggs: the Luck of whoever is hunting near them (see nearbyLuck)
	for _, n in unmutatedNestEggs() do
		if rng:NextNumber() < Luck.MutationChance(e.NestChance, nearbyLuck(n.position, e.Luck)) then
			EggService:MutateEgg(n.egg, e.Mutation)
		end
	end
	-- pen eggs: the owner's Luck (which already includes the weather boost)
	local penChance = e.PenChance * WeatherConfig.PenChanceScale
	for _, player in Players:GetPlayers() do
		local data = DataService:Get(player)
		local items = data and data.Pen and data.Pen.Items
		if items then
			local ids = {}
			for id, entry in items do
				if entry.Kind == "Egg" and not entry.Mutation and not entry.StolenBy then
					table.insert(ids, id)
				end
			end
			for _, id in ids do
				if LuckService:RollMutation(player, penChance) then
					HatchService:MutatePenEgg(player, id, e.Mutation)
				end
			end
		end
	end
end

local function weatherEgg()
	if EggService:IsNight() then
		return
	end
	local list = unmutatedNestEggs()
	if #list == 0 then
		return
	end
	-- lean towards the rarer eggs: best of two picks
	local a, b = list[rng:NextInteger(1, #list)], list[rng:NextInteger(1, #list)]
	local function order(n)
		local r = EggConfig.RarityById[n.egg:GetAttribute("Rarity")]
		return r and r.Order or 0
	end
	local n = order(b) > order(a) and b or a
	if EggService:MutateEgg(n.egg, current.Mutation, true) then
		gameEvent:FireAllClients("WeatherEggSpawned", {
			Mutation = current.Mutation,
			Rarity = n.egg:GetAttribute("Rarity"),
			BiomeId = n.biomeId,
			SizeTier = n.egg:GetAttribute("SizeTier"),
		})
	end
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(pos)
	local ignore = { workspace:FindFirstChild("Runtime") }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), groundParams)
	return hit and hit.Position or Vector3.new(pos.X, 0, pos.Z)
end

local STRIKE_DELAY = { Lightning = 0.35, Meteor = 1.6, Hail = 0.9 }

local function knockback(position, strength)
	for _, player in Players:GetPlayers() do
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local flat = Vector3.new(hrp.Position.X - position.X, 0, hrp.Position.Z - position.Z)
			if flat.Magnitude < 7 and math.abs(hrp.Position.Y - position.Y) < 8 then
				local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
				local att = hrp:FindFirstChild("RootAttachment")
				if att then
					local lv = Instance.new("LinearVelocity")
					lv.Name = "HailKnock"
					lv.Attachment0 = att
					lv.RelativeTo = Enum.ActuatorRelativeTo.World
					lv.MaxForce = math.huge
					lv.VectorVelocity = dir * strength + Vector3.new(0, strength * 0.4, 0)
					lv.Parent = hrp
					Debris:AddItem(lv, 0.15)
				end
				gameEvent:FireClient(player, "HailHit", {})
			end
		end
	end
end

local function strike()
	local s = current.Strike
	local kind = s.Kind
	local delay = STRIKE_DELAY[kind] or 0.5
	local target, pos
	if not EggService:IsNight() and rng:NextNumber() < s.EggChance then
		local list = unmutatedNestEggs()
		if #list > 0 then
			-- pick weighted by the Luck near each egg: lucky hunters see more strikes on their eggs
			local total, weights = 0, {}
			for i, n in list do
				weights[i] = nearbyLuck(n.position, current.Luck)
				total += weights[i]
			end
			local pick = rng:NextNumber() * total
			target = list[#list]
			for i, n in list do
				pick -= weights[i]
				if pick <= 0 then
					target = n
					break
				end
			end
			pos = target.position - Vector3.new(0, target.egg.PrimaryPart.Size.Y / 2, 0)
		end
	end
	if not pos then
		-- for show, near someone (or a random nest when nobody's around)
		local players = Players:GetPlayers()
		local p = #players > 0 and players[rng:NextInteger(1, #players)]
		local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local a = rng:NextNumber(0, math.pi * 2)
			local r = kind == "Hail" and rng:NextNumber(2, 14) or rng:NextNumber(10, 40)
			pos = groundAt(hrp.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		else
			return
		end
	end
	local mutation = current.Mutation
	gameEvent:FireAllClients("WeatherStrike", { Kind = kind, Position = pos, Delay = delay, Mutation = target and mutation or nil })
	task.delay(delay, function()
		if target and current and current.Mutation == mutation then
			EggService:MutateEgg(target.egg, mutation)
		end
		if kind == "Hail" and s.Knockback then
			knockback(pos, s.Knockback)
		end
	end)
end

-- ---------- control ----------

-- Starts an event now (replacing any running one). `who` is ignored (DevHooks.Call passes a player first).
function WeatherService:Force(_who, idOrName, seconds)
	local e = WeatherConfig.ById[idOrName or ""] or (type(idOrName) == "string" and WeatherConfig.Find(idOrName))
	if not e then
		return false
	end
	startEvent(e, tonumber(seconds), true)
	return e.Id
end

function WeatherService:Stop()
	stopEvent("stopped")
	return true
end

function WeatherService:GetCurrent()
	return current and current.Id or nil, endsAt
end

local function canControl(player)
	if DevConfig.AdminCommands then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank >= 255
end

local function notify(player, text, kind)
	gameEvent:FireClient(player, "DevNotice", { Text = text, Kind = kind })
end

local function names()
	local list = {}
	for _, e in WeatherConfig.Events do
		table.insert(list, e.DisplayName)
	end
	return table.concat(list, ", ")
end

local function command(caller, args)
	if not canControl(caller) then
		return
	end
	local first = args[1] and string.lower(args[1]) or ""
	if first == "" or first == "list" or first == "help" then
		notify(caller, "/weather <name> [seconds] | stop | next. Events: " .. names(), "info")
	elseif first == "stop" or first == "clear" or first == "off" then
		if current then
			notify(caller, "Stopped " .. current.DisplayName .. ".", "info")
			stopEvent("command")
		else
			notify(caller, "No weather running.", "warn")
		end
	elseif first == "next" or first == "random" then
		startEvent(pickEvent(), nil, true)
		notify(caller, "Started " .. current.DisplayName .. ".", "info")
	else
		local seconds = tonumber(args[#args])
		if seconds then
			table.remove(args, #args)
		end
		local e = WeatherConfig.Find(table.concat(args, ""))
		if not e then
			notify(caller, "No weather called \"" .. table.concat(args, " ") .. "\". Events: " .. names(), "warn")
			return
		end
		startEvent(e, seconds and math.clamp(seconds, 10, 1800) or nil, true)
		notify(caller, "Started " .. e.DisplayName .. " for " .. math.floor(endsAt - workspace:GetServerTimeNow()) .. "s.", "info")
	end
end

function WeatherService:Init()
	gameEvent = ReplicatedStorage.Remotes:WaitForChild("GameEvent")
	local cmd = Instance.new("TextChatCommand")
	cmd.Name = "WeatherCommand"
	cmd.PrimaryAlias = "/weather"
	cmd.Triggered:Connect(function(textSource, message)
		local caller = textSource and Players:GetPlayerByUserId(textSource.UserId)
		if not caller then
			return
		end
		local args = string.split(message, " ")
		table.remove(args, 1)
		for i = #args, 1, -1 do
			if args[i] == "" then
				table.remove(args, i)
			end
		end
		task.spawn(command, caller, args)
	end)
	cmd.Parent = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
end

function WeatherService:Start()
	nextAt = workspace:GetServerTimeNow() + between(WeatherConfig.FirstEventSeconds)
	workspace:SetAttribute("NextWeatherAt", nextAt)
	Players.PlayerAdded:Connect(function(player)
		setLuck(player)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local now = workspace:GetServerTimeNow()
		if current then
			if now >= endsAt then
				stopEvent("time")
				return
			end
			if now >= tickAt then
				tickAt = now + WeatherConfig.TickSeconds
				local ok, err = pcall(mutationTick)
				if not ok then
					warn("[Weather] tick:", err)
				end
			end
			if current.WeatherEggEvery and now >= eggAt then
				eggAt = now + current.WeatherEggEvery * rng:NextNumber(0.85, 1.15)
				local ok, err = pcall(weatherEgg)
				if not ok then
					warn("[Weather] weather egg:", err)
				end
			end
			if current.Strike and now >= strikeAt then
				strikeAt = now + between(current.Strike.Every)
				local ok, err = pcall(strike)
				if not ok then
					warn("[Weather] strike:", err)
				end
			end
		elseif now >= nextAt then
			startEvent(pickEvent())
		end
	end)
end

return WeatherService
