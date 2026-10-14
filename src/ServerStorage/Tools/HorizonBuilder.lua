-- Edit-time builder for the world's surroundings (workspace.Map.Horizon), so no view ends in empty sky or a sheer drop
-- into nothing: the map becomes a mountainous island in a sea.
--   Sea        deep water to the horizon (top at y -36, under every cliff and wall), lighter shallows round the island
--   Foothills  hills and a sandy shore hugging the island's outer edges, coloured per area (green by the Citadel and
--              Pebble Plains, dark basalt by Lava Lagoon, snow by Frostfang Peaks, jungle by Venom Jungle, blue rock and
--              coral by Sunken Abyss, slate by Storm Spires, violet by Cosmic Rift); the east end follows the canyon's end
--   Mountains  a ring of huge, hazy stepped mountains far out, snow-capped where they're tallest
-- Nothing here collides, casts shadows or can be clicked.
--   require(game.ServerStorage.Tools.HorizonBuilder:Clone()).Build()
local ServerStorage = game:GetService("ServerStorage")
local K = require(ServerStorage.Tools.CitadelBuilder.Kit)
local hex = Color3.fromHex

local H = {}

local SEA = -36
local FAR = { solid = false, shadow = false }

local function flat(p)
	p.CanQuery = false
	p.CastShadow = false
	return p
end

-- 0..1 noise along a line
local function T01(t, s)
	return math.clamp(math.noise(t, s * 1.7 + 0.3, 0.42) * 1.6 + 0.5, 0, 1)
end

local function canyonEnd()
	local lane = workspace.Map:FindFirstChild("Lane")
	local x = 830
	for _, m in lane and lane:GetChildren() or {} do
		local z = m:FindFirstChild("Zone")
		if z then
			x = math.max(x, z.Position.X + z.Size.X / 2)
		end
	end
	return x
end

local function area(x)
	if x < 452 then
		return { body = hex("B07A42"), cap = hex("5BBF35"), cap2 = hex("4FB52C"), shore = hex("E3D2A0") }
	elseif x < 627 then
		return { body = hex("3A2C2A"), cap = hex("2E2220"), cap2 = hex("4A3834"), shore = hex("5A4E4A") }
	elseif x < 827 then
		return { body = hex("829EB8"), cap = hex("FFFFFF"), cap2 = hex("E8F3FF"), shore = hex("DCE8F2") }
	elseif x < 1052 then
		return { body = hex("3B4434"), cap = hex("2F7A36"), cap2 = hex("276030"), shore = hex("6B5E44") }
	elseif x < 1302 then
		return { body = hex("23405A"), cap = hex("2F8C78"), cap2 = hex("2A6E70"), shore = hex("8FA8A4") }
	elseif x < 1577 then
		return { body = hex("3A4150"), cap = hex("2F3644"), cap2 = hex("4B5363"), shore = hex("5E6676") }
	end
	return { body = hex("221A3D"), cap = hex("3D2E63"), cap2 = hex("5A2F8A"), shore = hex("2E2450") }
end

function H.Build()
	local map = workspace.Map
	local old = map:FindFirstChild("Horizon")
	if old then
		old:Destroy()
	end
	K.reset()
	local root = K.model(map, "Horizon")
	local rng = Random.new(1717)
	local X0, X1 = -420, canyonEnd() + 150
	-------------------------------------------------------------- sea
	local sea = K.model(root, "Sea")
	for x = -2600, 4400, 2000 do
		for z = -3000, 2999, 2000 do
			flat(K.box(sea, "Sea", x, x + 2000, SEA - 4, SEA, z, z + 2000, hex("2F7FBF"), FAR))
		end
	end
	flat(K.box(sea, "Shallows", X0 - 80, math.min(X1 + 80, X0 + 2000), SEA - 3.9, SEA + 0.1, -480, 480, hex("46A6D6"), FAR))
	-------------------------------------------------------------- foothills and shore, round the island
	local hills = K.model(root, "Foothills")
	local function hill(x0, x1, z0, z1, h, a, kind)
		if kind == "shore" then
			flat(K.box(hills, "Shore", x0, x1, SEA - 6, SEA + h, z0, z1, a.shore, { studs = K.TOP, solid = false, shadow = false }))
		else
			flat(K.box(hills, "Hill", x0, x1, SEA - 6, h, z0, z1, a.body, { studs = K.SIDES, solid = false, shadow = false }))
			flat(K.box(hills, "HillCap", x0 - 0.5, x1 + 0.5, h, h + 2, z0, z1, rng:NextNumber() < 0.5 and a.cap or a.cap2, { studs = K.ALL, solid = false, shadow = false }))
		end
	end
	for _, s in { 1, -1 } do
		local x = X0
		while x < X1 do
			local w = rng:NextInteger(36, 60)
			local x1 = math.min(x + w, X1)
			local a = area((x + x1) / 2)
			local inner = math.floor(18 + T01(x / 60, s) * 46)
			local mid = math.floor(-8 + T01(x / 45 + 3, s) * 24)
			local z = 296
			hill(x, x1, s * z, s * (z + rng:NextInteger(44, 60)), inner, a)
			hill(x, x1, s * (z + 40), s * (z + rng:NextInteger(80, 96)), mid, a)
			hill(x - 2, x1 + 2, s * (z + 70), s * (z + rng:NextInteger(116, 136)), 2, a, "shore")
			x = x1
		end
	end
	for _, e in { { X0 - 1, -1 }, { X1 + 1, 1 } } do
		local z = -430
		while z < 430 do
			local w = rng:NextInteger(36, 60)
			local z1 = math.min(z + w, 430)
			local a = area(e[1])
			local x0 = e[1]
			local d = e[2]
			hill(x0 - d * 4, x0 + d * rng:NextInteger(44, 60), z, z1, math.floor(18 + T01(z / 60, d) * 46), a)
			hill(x0 + d * 36, x0 + d * rng:NextInteger(80, 96), z, z1, math.floor(-8 + T01(z / 45 + 3, d) * 24), a)
			hill(x0 + d * 66, x0 + d * rng:NextInteger(116, 136), z, z1, 2, a, "shore")
			z = z1
		end
	end
	-------------------------------------------------------------- far mountains
	local mts = K.model(root, "Mountains")
	local cx = (X0 + X1) / 2
	local BODY = { hex("5F7A6B"), hex("6B8576"), hex("778F82"), hex("8399A0") }
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local r = rng:NextNumber(1700, 2300)
		local mx, mz = cx + math.cos(a) * r * 1.25, math.sin(a) * r
		local base = rng:NextNumber(520, 900)
		local ht = rng:NextNumber(300, 680)
		local steps = 7
		for k = 0, steps - 1 do
			local t = k / steps
			local w = base * (1 - t * 0.86)
			local ox, oz = rng:NextNumber(-0.06, 0.06) * w, rng:NextNumber(-0.06, 0.06) * w
			local snow = ht > 470 and k >= steps - 2
			local color = snow and hex("EEF3F7") or BODY[math.min(#BODY, k + 1)]
			local y0, y1 = SEA - 6 + (ht + 6) * t, SEA + ht * (k + 1) / steps
			local sx, sz = math.min(w, 2040), math.min(w * rng:NextNumber(0.75, 1.1), 2040)
			flat(K.part(mts, "Mountain", Vector3.new(sx, y1 - y0, sz), CFrame.new(mx + ox, (y0 + y1) / 2, mz + oz) * CFrame.Angles(0, a, 0), color, FAR))
		end
	end
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("Horizon: %d parts (island x %d..%d)", n, X0, X1)
end


return H
