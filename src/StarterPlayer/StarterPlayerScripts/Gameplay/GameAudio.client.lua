-- GameAudio: all music, ambience and sound effects. Client-only and purely cosmetic: it listens to Remotes.GameEvent,
-- UIApi signals, replicated attributes (guardian State, OnTreadmill, EatAt, LeveledAt) and KaijuMotion.EmoteStarted.
-- It never changes game state. Every id / volume / pitch lives in ReplicatedStorage.Shared.Config.SoundConfig.
--   UI       hover + click on every button (cloned rows too), panel open / close, card arrows, proximity prompts
--   events   purchases, upgrades, eggs, hatch reveals, errors / warnings, getting caught, escaping
--   world    guardian snore / roar / stomps and kaiju emote voices (3D), feeding munches, level-ups, treadmill loop
--   music    one track per zone (Hub + each biome) that crossfades as you walk, chase music, ducking during hatches
--   ambience per-biome beds and random gusts
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")
local ContentProvider = game:GetService("ContentProvider")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local SoundConfig = require(Config:WaitForChild("SoundConfig"))
local BiomeConfig = require(Config:WaitForChild("BiomeConfig"))
local EggConfig = require(Config:WaitForChild("EggConfig"))
local KaijuMotion = require(script.Parent:WaitForChild("KaijuMotion"))
local gameEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GameEvent")

local player = Players.LocalPlayer
local rng = Random.new()
local S = SoundConfig.Sounds

---------------------------------------------------------------- sound groups
local groups = {}
for name, volume in SoundConfig.Groups do
	local g = SoundService:FindFirstChild(name)
	if not (g and g:IsA("SoundGroup")) then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Volume = volume
		g.Parent = SoundService
	end
	groups[name] = g
end
-- music runs through a child group so hatch reveals can duck it without touching the Music level
local musicDuck = Instance.new("SoundGroup")
musicDuck.Name = "MusicDuck"
musicDuck.Volume = 1
musicDuck.Parent = groups.Music

local folder2D = Instance.new("Folder")
folder2D.Name = "GameAudio2D"
folder2D.Parent = SoundService

---------------------------------------------------------------- core playback
local function contentId(id)
	if type(id) == "table" then
		id = id[rng:NextInteger(1, #id)]
	end
	return "rbxassetid://" .. tostring(id)
end

local lastPlayed = {}
local function offCooldown(key, def)
	local now = os.clock()
	local last = lastPlayed[key]
	if last and now - last < (def.Cooldown or 0.03) then
		return false
	end
	lastPlayed[key] = now
	return true
end

local function build(def, opts)
	opts = opts or {}
	local s = Instance.new("Sound")
	s.SoundId = contentId(def.Id)
	s.Volume = (def.Volume or 0.5) * (opts.Volume or 1)
	local vary = def.Vary or 0
	s.PlaybackSpeed = (def.Pitch or 1) * (opts.Pitch or 1) * (1 + rng:NextNumber(-vary, vary))
	s.SoundGroup = groups[def.Group or "SFX"] or groups.SFX
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = def.MinDist or 10
	s.RollOffMaxDistance = def.MaxDist or 100
	return s
end

local function fire(s, def)
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	if def.MaxSeconds then
		task.delay(def.MaxSeconds, function()
			if s.Parent then
				local tw = TweenService:Create(s, TweenInfo.new(0.6), { Volume = 0 })
				tw:Play()
				tw.Completed:Wait()
				s:Destroy()
			end
		end)
	end
	task.delay(30, function() -- safety net for clips that never load / never end
		if s.Parent then
			s:Destroy()
		end
	end)
	return s
end

-- 2D one-shot by key. opts: Volume / Pitch multipliers, Force = ignore cooldown.
local function play(key, opts)
	local def = S[key]
	if not def or not (opts and opts.Force or offCooldown(key, def)) then
		return nil
	end
	local s = build(def, opts)
	s.Parent = folder2D
	return fire(s, def)
end

-- 3D one-shot by key, emitted from a BasePart or Attachment.
local function playAt(key, where, opts)
	local def = S[key]
	if not def or not (where and where.Parent) or not (opts and opts.Force or offCooldown(key, def)) then
		return nil
	end
	local s = build(def, opts)
	s.Parent = where
	return fire(s, def)
end

-- 3D one-shot at a world position (temporary attachment on Terrain).
local function playAtPosition(key, pos, opts)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain
	task.delay(8, function()
		att:Destroy()
	end)
	return playAt(key, att, opts)
end

-- raw def (ambience gusts) as a 2D one-shot
local function playDef(def)
	local s = build(def)
	s.Parent = folder2D
	return fire(s, def)
end

local fades = {}
local function fadeTo(s, volume, seconds)
	if fades[s] then
		fades[s]:Cancel()
	end
	if volume > 0 and not s.IsPlaying then
		s:Resume()
		if not s.IsPlaying then
			s:Play()
		end
	end
	local tw = TweenService:Create(s, TweenInfo.new(seconds or 1, Enum.EasingStyle.Sine), { Volume = volume })
	fades[s] = tw
	tw.Completed:Once(function(state)
		if fades[s] == tw then
			fades[s] = nil
		end
		if state == Enum.PlaybackState.Completed and volume <= 0 and s.Parent then
			s:Pause()
		end
	end)
	tw:Play()
end

local function makeLoop(def, parent, groupOverride)
	local s = build(def)
	s.Looped = true
	s.Volume = 0
	if groupOverride then
		s.SoundGroup = groups[groupOverride] or s.SoundGroup
	end
	s.Parent = parent or folder2D
	return s
end

local function emitterOf(model)
	if model:IsA("BasePart") then
		return model
	end
	return model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Root")
		or model:FindFirstChildWhichIsA("BasePart", true)
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------- preload (audio must be preloaded as Sound instances;
-- warns in Output, naming the SoundConfig key, if an id can't load, e.g. it was removed from the Creator Store)
task.spawn(function()
	local holder = Instance.new("Folder")
	holder.Name = "Preload"
	local list, keyOf = {}, {}
	local function add(id, key)
		if type(id) == "table" then
			for _, v in id do
				add(v, key)
			end
			return
		end
		local c = "rbxassetid://" .. tostring(id)
		if not keyOf[c] then
			keyOf[c] = key
			local s = Instance.new("Sound")
			s.SoundId = c
			s.Parent = holder
			table.insert(list, s)
		end
	end
	for key, def in S do
		add(def.Id, key)
	end
	for zone, def in SoundConfig.Ambience do
		for _, key in { "Bed", "Beds", "Gusts" } do
			local v = def[key]
			if type(v) == "table" then
				for _, layer in (v[1] and v or { v }) do
					add(layer.Id, "Ambience." .. zone .. "." .. key)
				end
			end
		end
	end
	holder.Parent = SoundService
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
	local deadline = os.clock() + 20
	while os.clock() < deadline do
		local pending = false
		for _, s in list do
			if not s.IsLoaded then
				pending = true
				break
			end
		end
		if not pending then
			break
		end
		task.wait(0.5)
	end
	for _, s in list do
		if not s.IsLoaded then
			warn("[GameAudio] sound didn't load: " .. s.SoundId .. " (SoundConfig: " .. keyOf[s.SoundId] .. ")")
		end
	end
	holder:Destroy()
end)

---------------------------------------------------------------- music
local musicTracks = {}
local currentMusic
for key, def in SoundConfig.Music do
	local s = Instance.new("Sound")
	s.Name = "Music_" .. key
	s.Volume = 0
	s.SoundGroup = musicDuck
	s.Parent = folder2D
	local track = { sound = s, volume = def.Volume or 0.35 }
	if def.Playlist and #def.Playlist > 0 then
		-- a playlist: songs in turn, starting at a random one; each song has its own (levelled) volume
		local list = def.Playlist
		s.Looped = #list == 1
		track.index = rng:NextInteger(1, #list)
		local function load(i)
			s.SoundId = contentId(list[i].Id)
			track.volume = list[i].Volume or def.Volume or 0.25
		end
		load(track.index)
		s.Ended:Connect(function()
			track.index = track.index % #list + 1
			load(track.index)
			task.delay(def.Gap or 2, function()
				if currentMusic == key and not s.IsPlaying then
					s.Volume = 0
					s.TimePosition = 0
					s:Play()
					fadeTo(s, track.volume, 1.5)
				end
			end)
		end)
	else
		s.SoundId = contentId(def.Id)
		s.Looped = true
	end
	musicTracks[key] = track
end

-- Zones without a SoundConfig.Music entry are music-free (ambience only): every track fades out there.
local function setMusic(key)
	if key == currentMusic then
		return
	end
	currentMusic = key
	for k, track in musicTracks do
		if k == key then
			if k == "Chase" then
				track.sound.TimePosition = 0 -- chase always starts from the top
			end
			fadeTo(track.sound, track.volume, k == "Chase" and 0.4 or SoundConfig.MusicFade)
		else
			fadeTo(track.sound, 0, SoundConfig.MusicFade)
		end
	end
end

local function duckMusic(on)
	TweenService:Create(musicDuck, TweenInfo.new(on and 0.3 or 1.2), { Volume = on and SoundConfig.DuckDuringHatch or 1 }):Play()
end

---------------------------------------------------------------- ambience
-- Each zone can have looping beds (Bed = one, Beds = a list) and one-shot layers (Gusts = one or a list), each
-- gust layer on its own random timer (Every = { min, max } seconds).
local function layers(v)
	if type(v) ~= "table" then
		return {}
	end
	return v[1] and v or { v }
end

local beds = {} -- { zone, sound, volume }
for zone, a in SoundConfig.Ambience do
	for _, def in layers(a.Bed) do
		table.insert(beds, { zone = zone, sound = makeLoop(def, folder2D, "Ambience"), volume = def.Volume or 0.2 })
	end
	for _, def in layers(a.Beds) do
		table.insert(beds, { zone = zone, sound = makeLoop(def, folder2D, "Ambience"), volume = def.Volume or 0.2 })
	end
end

local currentAmbience
local function setAmbience(zone)
	if zone == currentAmbience then
		return
	end
	currentAmbience = zone
	for _, bed in beds do
		fadeTo(bed.sound, bed.zone == zone and bed.volume or 0, 2)
	end
end

for zone, a in SoundConfig.Ambience do
	for _, gust in layers(a.Gusts) do
		gust.Group = gust.Group or "Ambience"
		task.spawn(function()
			while true do
				local every = gust.Every or { 5, 10 }
				task.wait(rng:NextNumber(every[1], every[2]))
				if currentAmbience == zone then
					playDef(gust)
				end
			end
		end)
	end
end

---------------------------------------------------------------- zones (map runs along +X: hub -> safe line -> biomes)
local safeX = 302
-- Zones come from the lane's Zone parts (each carries its BiomeId and spans its biome's X range), so they always match
-- the built map. (They used to be summed from BiomeConfig lengths plus a 3-stud border the map doesn't have, which
-- drifted 3 studs further out per biome.)
local laneZones = {}
local function readZones()
	local map = workspace:FindFirstChild("Map")
	local lane = map and map:FindFirstChild("Lane")
	local list = {}
	if lane then
		for _, m in lane:GetChildren() do
			local z = m:FindFirstChild("Zone")
			if z and z:IsA("BasePart") then
				table.insert(list, { x0 = z.Position.X - z.Size.X / 2, x1 = z.Position.X + z.Size.X / 2, id = z:GetAttribute("BiomeId") or m.Name })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.x0 < b.x0
	end)
	laneZones = list
end
task.spawn(function()
	local map = workspace:WaitForChild("Map", 30)
	if not map then
		return
	end
	safeX = map:GetAttribute("SafeZoneX") or (map:FindFirstChild("SafeZoneLine") and map.SafeZoneLine.Position.X) or safeX
	local lane = map:WaitForChild("Lane", 30)
	if lane then
		readZones()
		lane.ChildAdded:Connect(function()
			task.wait(1)
			readZones()
		end)
		lane.ChildRemoved:Connect(readZones)
	end
end)
local function zoneAt(x)
	if x < safeX then
		return "Hub"
	end
	local last
	for _, z in laneZones do
		last = z.id
		if x < z.x1 then
			return z.id
		end
	end
	if last then
		return last
	end
	-- map not read yet: sum the open biomes' lengths
	local x0 = safeX
	for _, biome in BiomeConfig.List do
		last = biome.Id
		x0 += biome.Length
		if x < x0 then
			return biome.Id
		end
	end
	return last
end

---------------------------------------------------------------- guardians
local guardians = {} -- [model] = state
local chaseHoldUntil = 0

local function isChased()
	if not player:GetAttribute("CarryingEgg") then
		return false
	end
	if os.clock() < chaseHoldUntil then
		return true
	end
	local from = player:GetAttribute("CarryingFromBiome")
	for model, g in guardians do
		local target = model:GetAttribute("TargetUserId") -- every player has a guardian of their own (GuardianService)
		if g.state == "Chasing" and (target == player.UserId or (target == nil and (not from or model:GetAttribute("BiomeId") == from))) then
			return true
		end
	end
	return false
end

local function addGuardian(model)
	if not model:IsA("Model") or guardians[model] then
		return
	end
	local root = model.PrimaryPart or model:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local pitch = SoundConfig.GuardianPitch[model:GetAttribute("BiomeId") or ""] or 1
	local snoreDef = S.GuardianSnore
	local g = { root = root, pitch = pitch, state = nil, nextStomp = 0 }
	g.snore = makeLoop(snoreDef, root)
	g.snore.PlaybackSpeed = (snoreDef.Pitch or 1) * pitch
	guardians[model] = g
	-- KaijuFX marks every footfall (local attribute StepAt): stomp in time with the feet from then on
	model:GetAttributeChangedSignal("StepAt"):Connect(function()
		g.footfalls = true
		local now = os.clock()
		if (g.state == "Chasing" or g.state == "Returning") and now - (g.lastStomp or 0) > 0.16 then
			g.lastStomp = now
			playAt("GuardianStomp", root, {
				Pitch = pitch,
				Volume = g.state == "Chasing" and 1 or 0.55,
				Force = true,
			})
		end
	end)

	local function onState(initial)
		local state = model:GetAttribute("State")
		local prev = g.state
		g.state = state
		if g.snore.Parent then
			fadeTo(g.snore, state == "Sleeping" and snoreDef.Volume or 0, 0.6)
		end
		if initial then
			return
		end
		if state == "Waking" or (state == "Chasing" and prev ~= "Waking" and prev ~= "Chasing") then
			playAt("GuardianRoar", root, { Pitch = pitch, Force = true })
		elseif state == "Returning" and prev == "Chasing" then
			playAt("GuardianGrumble", root, { Pitch = pitch, Force = true })
		end
	end
	model:GetAttributeChangedSignal("State"):Connect(function()
		onState(false)
	end)
	onState(true)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			guardians[model] = nil
		end
	end)
end

local function stepGuardians()
	local now = os.clock()
	for _, g in guardians do
		if (g.state == "Chasing" or g.state == "Returning") and g.root.Parent and not g.footfalls then
			local v = g.root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			if speed > 3 and now >= g.nextStomp then
				playAt("GuardianStomp", g.root, {
					Pitch = g.pitch,
					Volume = g.state == "Chasing" and 1 or 0.55,
					Force = true,
				})
				g.nextStomp = now + math.clamp(9 / speed, 0.22, 0.75) / g.pitch
			end
		end
	end
end

---------------------------------------------------------------- kaiju (emote voices, hatch pops, level-ups)
local lastEmoteSound = 0
KaijuMotion.EmoteStarted:Connect(function(model, emote)
	local key = SoundConfig.Emotes[emote]
	if not (key and model and model.Parent) then
		return
	end
	local now = os.clock()
	if key ~= "Eat" and now - lastEmoteSound < 0.35 then
		return -- keep a pen full of kaiju from turning into noise
	end
	local part = emitterOf(model)
	if not part then
		return
	end
	lastEmoteSound = now
	local big = math.clamp(model:GetAttribute("VisualScale") or 1, 0.4, 4)
	playAt(key, part, {
		Pitch = math.clamp(1 / math.sqrt(big), 0.6, 1.5),
		Volume = math.clamp(0.75 + 0.25 * big, 0.7, 1.4),
		Force = true,
	})
end)

local function onKaijuAdded(model)
	if not model:IsA("Model") then
		return
	end
	task.wait() -- let attributes and parts arrive
	local now = serverNow()
	local mine = model:GetAttribute("OwnerUserId") == player.UserId
	local leveledAt = model:GetAttribute("LeveledAt")
	local spawnedAt = model:GetAttribute("SpawnedAt")
	if leveledAt and now - leveledAt < 3 then
		local root = model:WaitForChild("Root", 5) or emitterOf(model)
		if root then
			task.wait(0.1)
			playAt("LevelUp", root, { Force = true })
			if mine then
				play("TrailUnlock", { Volume = 0.8 })
			end
		end
	elseif spawnedAt and now - spawnedAt < 2.5 and not mine then
		-- someone else's hatch nearby (your own hatch gets the full reveal instead)
		local part = emitterOf(model)
		if part then
			playAt("EggCrack", part, { Force = true })
			playAt("HatchBurst", part, { Volume = 0.6, Force = true })
		end
	end
end

local kaijuFolder
local function findKaiju(kaijuId)
	if not kaijuFolder then
		return nil
	end
	for _, m in kaijuFolder:GetChildren() do
		if m:GetAttribute("KaijuId") == kaijuId then
			return m
		end
	end
	return nil
end

task.spawn(function()
	local runtime = workspace:WaitForChild("Runtime")
	task.spawn(function()
		local folder = runtime:WaitForChild("Guardians")
		folder.ChildAdded:Connect(addGuardian)
		for _, m in folder:GetChildren() do
			task.spawn(addGuardian, m)
		end
	end)
	kaijuFolder = runtime:WaitForChild("Kaiju")
	kaijuFolder.ChildAdded:Connect(onKaijuAdded)
end)

---------------------------------------------------------------- game events
local revealQueue = {}

local function rarityPitch(rarity)
	return SoundConfig.RarityPitch[rarity or ""] or 1
end
local function warnSound()
	play("Warn")
end
local function errorSound()
	play("Error")
end
local function upgraded()
	play("Purchase")
	play("Build")
	task.delay(0.35, play, "Success")
end

local handlers = {
	EggPickedUp = function(d)
		play("EggPickup", { Pitch = rarityPitch(d.Rarity) })
		play("EggSparkle", { Pitch = rarityPitch(d.Rarity) })
	end,
	GuardianAwake = function()
		chaseHoldUntil = os.clock() + 2
	end,
	Caught = function()
		chaseHoldUntil = 0
		play("CaughtHit")
		play("Knockback")
	end,
	GuardianGaveUp = function()
		chaseHoldUntil = 0
		play("Escaped")
	end,
	EggDropped = function()
		task.delay(0.2, play, "EggDrop")
	end,
	EggPlaced = function()
		play("EggPlace")
		play("CutePop")
	end,
	EggReady = function()
		play("EggReady")
	end,
	EggHatched = function(d)
		table.insert(revealQueue, d)
	end,
	HatchAnnouncement = function(d)
		if d.UserId ~= player.UserId then
			play("HatchOther")
		end
	end,
	PenUpgraded = upgraded,
	TreadmillUpgraded = upgraded,
	SpeedBought = function()
		play("Purchase")
		play("SpeedUp")
	end,
	FoodBought = function()
		play("Purchase")
	end,
	TrailBought = function()
		play("Purchase")
		play("TrailUnlock")
	end,
	TrailEquipped = function()
		play("TrailEquip")
	end,
	OfflineEarnings = function()
		play("Welcome")
		task.delay(0.5, play, "Coins")
	end,
	KaijuSold = function(d)
		if d.OwnerUserId == player.UserId then
			play("Coins")
			play("Purchase")
			task.delay(0.25, play, "Success")
		elseif typeof(d.Position) == "Vector3" then
			playAtPosition("Coins", d.Position, { Force = true })
		end
	end,
	KaijuFed = function(d)
		local model = findKaiju(d.KaijuId)
		local part = model and emitterOf(model)
		if part then
			playAt("FoodToss", part, { Force = true })
		end
	end,
	NotEnoughCash = errorSound,
	CantTeleport = errorSound,
	PenFull = warnSound,
	NotYourPen = warnSound,
	NotYourEgg = warnSound,
	SpeedMaxed = warnSound,
	TreadmillMaxed = warnSound,
	TreadmillCarrying = warnSound,
	NoFood = warnSound,
	KaijuMaxLevel = warnSound,
}

gameEvent.OnClientEvent:Connect(function(name, data)
	local handler = handlers[name]
	if handler then
		local ok, err = pcall(handler, type(data) == "table" and data or {})
		if not ok then
			warn("[GameAudio] " .. tostring(name) .. ": " .. tostring(err))
		end
	end
end)

---------------------------------------------------------------- UI: every button, panels, hatch reveal
local hooked = setmetatable({}, { __mode = "k" })
local function hookButton(b)
	if hooked[b] then
		return
	end
	hooked[b] = true
	b.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			play("Hover")
		end
	end)
	b.Activated:Connect(function()
		local n = b.Name
		if n == "Close" then
			return -- PanelClosed plays the close sound
		elseif n == "LeftArrow" or n == "RightArrow" then
			play("Arrow")
		else
			play("Click")
		end
	end)
end

local function watchGui(gui)
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiButton") then
			hookButton(d)
		end
	end
	gui.DescendantAdded:Connect(function(d)
		if d:IsA("GuiButton") then
			hookButton(d)
		end
	end)
end

local playerGui = player:WaitForChild("PlayerGui")
for _, gui in playerGui:GetChildren() do
	watchGui(gui)
end
playerGui.ChildAdded:Connect(watchGui)

task.spawn(function()
	local gui = playerGui:WaitForChild("KaijuUI", 60)
	if not gui then
		return
	end
	local ok, UIApi = pcall(require, gui:WaitForChild("UIApi"))
	if ok and type(UIApi) == "table" and UIApi.PanelOpened then
		local lastOpenAt = 0
		UIApi.PanelOpened:Connect(function()
			lastOpenAt = os.clock()
			play("PanelOpen")
		end)
		UIApi.PanelClosed:Connect(function()
			task.defer(function()
				if os.clock() - lastOpenAt > 0.05 then -- switching panels closes the old one first; stay quiet then
					play("PanelClose")
				end
			end)
		end)
	else
		warn("[GameAudio] couldn't hook UIApi panel signals")
	end

	-- hatch reveal (built by HatchRevealController); each reveal shows the frame once, in event order
	local reveal = gui:WaitForChild("HatchReveal", 60)
	if not reveal then
		return
	end
	reveal:GetPropertyChangedSignal("Visible"):Connect(function()
		if reveal.Visible then
			local data = table.remove(revealQueue, 1) or {}
			duckMusic(true)
			-- short layered celebration that grows with rarity (SoundConfig.HatchTiers); no long fanfares
			local r = EggConfig.RarityById[data.Rarity or ""]
			local order = r and r.Order or 1
			local tiers = SoundConfig.HatchTiers or {}
			local pitch = rarityPitch(data.Rarity)
			play("EggCrack", { Force = true })
			play("HatchBurst", { Force = true, Pitch = pitch })
			task.delay(0.15, play, "Success", { Force = true, Pitch = pitch })
			task.delay(0.3, play, "EggSparkle", { Force = true, Pitch = pitch })
			if order >= (tiers.Chime or 2) then
				task.delay(0.2, play, "HatchChime", { Force = true, Pitch = pitch })
			end
			if order >= (tiers.Ding or 4) then
				task.delay(0.35, play, "HatchDing", { Force = true, Pitch = pitch })
				task.delay(0.35, play, "CutePop", { Force = true })
			end
			if order >= (tiers.Gliss or 5) then
				play("HatchGliss", { Force = true })
			end
		else
			task.delay(0.35, function()
				if not reveal.Visible then
					duckMusic(false)
				end
			end)
		end
	end)
end)

---------------------------------------------------------------- proximity prompts
local holdSound
ProximityPromptService.PromptShown:Connect(function()
	play("PromptShown")
end)
ProximityPromptService.PromptButtonHoldBegan:Connect(function()
	holdSound = play("PromptHold", { Force = true })
end)
ProximityPromptService.PromptButtonHoldEnded:Connect(function()
	if holdSound and holdSound.Parent then
		holdSound:Destroy()
	end
	holdSound = nil
end)
ProximityPromptService.PromptTriggered:Connect(function()
	play("PromptDone")
end)

---------------------------------------------------------------- Robux purchases
pcall(function()
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, purchased)
		if purchased and userId == player.UserId then
			play("Purchase")
			play("Success")
		end
	end)
end)
pcall(function()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, _, purchased)
		if purchased and who == player then
			play("Purchase")
			play("Success")
		end
	end)
end)

---------------------------------------------------------------- treadmill loop
local treadLoop = makeLoop(S.Treadmill, folder2D)
local function onTreadmill()
	fadeTo(treadLoop, player:GetAttribute("OnTreadmill") and S.Treadmill.Volume or 0, 0.4)
end
player:GetAttributeChangedSignal("OnTreadmill"):Connect(onTreadmill)
if player:GetAttribute("OnTreadmill") then
	onTreadmill()
end

---------------------------------------------------------------- per-frame: teleports, guardian stomps, zone music
local lastPos
player.CharacterAdded:Connect(function()
	lastPos = nil
end)

local zoneTimer = 0
RunService.Heartbeat:Connect(function(dt)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local p = hrp.Position
		if lastPos and dt > 0 and (p - lastPos).Magnitude > 40 and (p - lastPos).Magnitude / dt > 800 then
			play("Teleport")
			task.delay(0.12, play, "CutePop")
		end
		lastPos = p
	end

	stepGuardians()

	zoneTimer += dt
	if zoneTimer >= 0.25 then
		zoneTimer = 0
		local zone = hrp and zoneAt(hrp.Position.X) or currentAmbience or "Hub"
		setMusic(isChased() and "Chase" or zone)
		setAmbience(zone)
	end
end)
