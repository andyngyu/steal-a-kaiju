-- Client-side culling for the big static scenery (performance; nothing on the server changes):
--   * detail groups (the Citadel's interior and walls, each biome's decor, props, trees, paths, flows and scatter) are
--     taken out of this client's workspace while the camera and the character are both far along the canyon from them,
--     and put back before either gets close (only this client's copy: other players and the server are unaffected).
--     Each open biome's silhouette - floor, cliffs, ridges, gate, volcano, glacier, lava - always stays, so the view down
--     the canyon (through the Grand Gate, past the Maw) never shows a gap. The biomes past Frostfang (Venom Jungle,
--     Sunken Abyss, Storm Spires, Cosmic Rift) also take their whole body away while the camera is far back down the
--     canyon, where the haze hides them anyway (each one appears well before it could be seen clearly).
--   * lights, particles, fire and smoke in the Citadel and the canyon switch off beyond FX_RANGE from the camera; key
--     lights (attribute KeyLight: the lights on landmarks that must read from a gate) reach KEY_RANGE
-- Never touched: Zone, NestSite, Sign, Border (scripts read them), the market, plots, leaderboards, statues, Horizon.
-- Groups are ranges along X (the map runs along +X); "show" when the camera or the character is inside [x0, x1]. A
-- biome's range comes from its lane's Zone: from `before` studs ahead of its start to `after` studs past its end.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local map = workspace:WaitForChild("Map")

local FX_RANGE = 200
local KEY_RANGE = 650
local CHECK_EVERY = 0.4
local BATCH = 600 -- parts moved per frame while a group switches
local MARGIN = 25 -- hysteresis: a group shown once stays until the camera is this much further out

local KEEP = { Zone = true, NestSite = true, Sign = true, Border = true }

local function find(path)
	local node = map
	for part in path:gmatch("[^%.]+") do
		node = node and node:WaitForChild(part, 10)
	end
	return node
end

-- { name, paths (relative to Map), show range on X (x0 / x1, or lane + before / after), except = child names to leave
-- alone }
local function detail(biome, extra)
	local t = { "Lane." .. biome .. ".Decor" }
	for _, n in extra do
		table.insert(t, "Lane." .. biome .. ".Refined." .. n)
	end
	return t
end
-- a biome's body: its floor, its gate and the named Refined parts (cliffs, walls, ridges, landmarks)
local function body(biome, extra)
	local t = { "Lane." .. biome .. ".Floor", "Lane." .. biome .. ".Gate" }
	for _, n in extra do
		table.insert(t, "Lane." .. biome .. ".Refined." .. n)
	end
	return t
end
local GROUPS = {
	{ name = "CitadelInside", paths = { "Citadel.Gardens", "Citadel.Avenue", "Citadel.Frames", "Citadel.Hall" }, x0 = -math.huge, x1 = 470 },
	{ name = "CitadelWalls", paths = { "Citadel.Walls", "Citadel.Towers", "Citadel.Backdrop" }, x0 = -math.huge, x1 = 640 },
	{ name = "PebbleDetail", paths = detail("PebblePlains", { "Scatter", "Greenery", "Fossils", "Path", "Transition" }), lane = "PebblePlains", before = 700, after = 250 },
	{ name = "LavaDetail", paths = detail("LavaLagoon", { "Scatter", "Heights", "Path", "Flows", "Transition", "Bridge" }), lane = "LavaLagoon", before = 150, after = 320 },
	{ name = "FrostDetail", paths = detail("FrostfangPeaks", { "Scatter", "Pines", "Path", "Ice" }), lane = "FrostfangPeaks", before = 130, after = 370 },
	{ name = "VenomDetail", paths = detail("VenomJungle", { "Scatter", "Greenery", "Path", "Flows", "Vines", "Fungi", "Bridge", "Courtyard", "Bridges", "Floor" }), lane = "VenomJungle", before = 180, after = 200 },
	{ name = "VenomBody", paths = body("VenomJungle", { "Liquid", "Cliffs", "Walls", "Back", "Temple", "Mushrooms" }), lane = "VenomJungle", before = 380, after = math.huge },
	{ name = "AbyssDetail", paths = detail("SunkenAbyss", { "Scatter", "Life", "Path", "Reef", "Weed", "Jellyfish", "Ruins" }), lane = "SunkenAbyss", before = 170, after = 180 },
	{ name = "AbyssBody", paths = body("SunkenAbyss", { "Liquid", "Cliffs", "Walls", "Back", "Whale", "Wreck" }), lane = "SunkenAbyss", before = 370, after = math.huge },
	{ name = "StormDetail", paths = detail("StormSpires", { "Scatter", "Path", "Scorch", "Coils", "Altar", "Slate" }), lane = "StormSpires", before = 170, after = 175 },
	{ name = "StormBody", paths = body("StormSpires", { "Liquid", "Cliffs", "Walls", "Back", "Spires", "Islands", "Sky" }), lane = "StormSpires", before = 400, after = math.huge },
	{ name = "CosmicDetail", paths = detail("CosmicRift", { "Scatter", "Path", "Heights", "Plinths" }), lane = "CosmicRift", before = 180, after = math.huge },
	{ name = "CosmicBody", paths = body("CosmicRift", { "Liquid", "Cliffs", "Walls", "Back", "Sky", "Rift", "VoidGate" }), lane = "CosmicRift", before = 430, after = math.huge },
}

-- a biome group's range from its lane's Zone
local function placeGroup(g)
	if not g.lane then
		return
	end
	local zone = find("Lane." .. g.lane .. ".Zone")
	if zone then
		g.x0 = zone.Position.X - zone.Size.X / 2 - g.before
		g.x1 = zone.Position.X + zone.Size.X / 2 + g.after
	else
		g.x0, g.x1 = -math.huge, math.huge -- no zone: never cull it
	end
end

-- collect a group's parts (and where they live) once; returns { {part, parent} }
local function collect(group)
	local list = {}
	local function walk(inst)
		for _, c in inst:GetChildren() do
			if KEEP[c.Name] or (group.except and group.except[c.Name]) then
				continue
			end
			if c:IsA("BasePart") then
				table.insert(list, { c, c.Parent })
			end
			if #c:GetChildren() > 0 and not c:IsA("BasePart") then
				walk(c)
			end
		end
	end
	for _, path in group.paths do
		local root = find(path)
		if root then
			walk(root)
		end
	end
	return list
end

local queue = {} -- pending { group, show }
local function request(g, show)
	if g.target == show then
		return
	end
	g.target = show
	g.cursor = 1
	table.insert(queue, g)
end

local function inRange(g, x, margin)
	return x >= g.x0 - margin and x <= g.x1 + margin
end

task.spawn(function()
	-- let the map finish arriving, then build the groups
	task.wait(4)
	for _, g in GROUPS do
		placeGroup(g)
		g.parts = collect(g)
		g.shown = true
		g.target = true
	end
	-- the FX list
	local fx = {}
	local function addFx(d)
		if d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") then
			local host = d.Parent
			if host and host:IsA("BasePart") then
				table.insert(fx, { d, host, d.Enabled, d:GetAttribute("KeyLight") and KEY_RANGE or FX_RANGE })
			end
		end
	end
	for _, root in { map:FindFirstChild("Citadel"), map:FindFirstChild("Lane") } do
		for _, d in root and root:GetDescendants() or {} do
			addFx(d)
		end
	end

	-- the switching itself, spread over frames
	RunService.Heartbeat:Connect(function()
		local budget = BATCH
		while budget > 0 and #queue > 0 do
			local g = queue[1]
			local show = g.target
			while budget > 0 and g.cursor <= #g.parts do
				local e = g.parts[g.cursor]
				pcall(function()
					e[1].Parent = show and e[2] or nil
				end)
				g.cursor += 1
				budget -= 1
			end
			if g.cursor > #g.parts then
				g.shown = show
				table.remove(queue, 1)
			end
		end
	end)

	while true do
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local charX = root and root.Position.X or camPos.X
		for _, g in GROUPS do
			local margin = g.target and MARGIN or 0
			local want = inRange(g, camPos.X, margin) or inRange(g, charX, margin)
			request(g, want)
		end
		for _, e in fx do
			local d, host, base, range = e[1], e[2], e[3], e[4]
			if base then
				local on = (host.Position - camPos).Magnitude < range
				if d.Enabled ~= on then
					d.Enabled = on
				end
			end
		end
		task.wait(CHECK_EVERY)
	end
end)
