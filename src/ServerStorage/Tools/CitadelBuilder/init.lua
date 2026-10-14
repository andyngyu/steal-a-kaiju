-- Edit-time builder for the Kaiju Citadel (the hub) in the game's studded-voxel look: SmoothPlastic blocks with the stud
-- texture (like the checker ground and the canyon walls), warm light stone, navy-purple roofs and gold trim (the colours
-- of the KAIJU MARKET sign and the leaderboard frames). It edits workspace.Map in place:
--   Map.Ground        regenerated over the citadel's footprint: grass checker, stone paving on the avenue and the hall floor
--   Map.Walls         removed (the old dirt walls); Map.Citadel replaces them:
--     Walls, Towers   45-tall curtain walls with battlements, pilasters and banners; towers with stepped roofs and flags
--     GrandGate       on the safe line (x 302): gatehouse tunnel, huge towers, portcullis, skull trophy (child module Gate)
--     Keep            the landmark keep at the west end of the avenue, behind the Hall (child module Keep)
--     Hall            the Hall of Champions round the leaderboards (the boards themselves stay exactly where they are)
--     Statues         two colossal golden kaiju in fountains, one each side of the spawn
--     Avenue          curbs, braziers and banner poles between the plots
--     Backdrop        green hills behind the walls (no collision, no shadows)
--   Map.Plots.PlotN.Arch   the two pillars become little stone gatehouse towers; the Board and its labels are untouched
-- Nothing scripts look up is renamed or moved (Leaderboards, Market, Spawn, SafeZoneLine, Lane, the plots' parts).
--   require(game.ServerStorage.Tools.CitadelBuilder:Clone()).Build()                 everything
--   require(game.ServerStorage.Tools.CitadelBuilder:Clone()).Build({ "GrandGate" })  just those sections
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Kit)

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

local C = {}

local hex = Color3.fromHex
local N = Enum.NormalId
local STUD = "rbxassetid://6372755229"
local ALL = { N.Top, N.Front, N.Back, N.Left, N.Right }
local ALLB = { N.Top, N.Bottom, N.Front, N.Back, N.Left, N.Right }
local SIDES = { N.Front, N.Back, N.Left, N.Right }
local TOP = { N.Top }

local P = {
	StoneA = hex("D2CBBB"),
	StoneB = hex("BDB4A1"),
	StoneDark = hex("8A7460"),
	StoneDeep = hex("6E5A4A"),
	Navy = hex("2B1B4D"),
	NavyLight = hex("3E2C6E"),
	Gold = hex("FFD23F"),
	GoldDeep = hex("E0A526"),
	Iron = hex("3A3A42"),
	IronLight = hex("6A6A75"),
	PaveA = hex("DDD6C4"),
	PaveB = hex("CBC3AF"),
	GrassA = hex("63D93C"),
	GrassB = hex("55CB30"),
	Dirt = hex("C98A4B"),
	DirtDark = hex("B07A42"),
	GrassCap = hex("4FC22A"),
	GrassCapDark = hex("5BBF35"),
	Water = hex("4FB0E6"),
	FlameA = hex("FF6A12"),
	FlameB = hex("FFA41F"),
	FlameC = hex("FFD45A"),
	Eye = hex("FF5A12"),
	Tooth = hex("FFF4D6"),
}
C.Palette = P

local WALL_H = 45
local WALL_T = 8
local HALL = Vector3.new(-28, 0, 0) -- centre of the leaderboards' arc (the six floor boards stand 62 studs out)

------------------------------------------------------------------------------- helpers
local made = 0

local function studs(p, faces)
	for _, f in faces do
		local t = Instance.new("Texture")
		t.Texture = STUD
		t.Face = f
		t.StudsPerTileU = 4
		t.StudsPerTileV = 4
		t.Color3 = Color3.new(0, 0, 0)
		t.Transparency = 0.82
		t.Parent = p
	end
end

-- o: studs = faces, solid = false (no collision / queries), neon, transparency, shape, shadow = false
local function part(parent, name, size, cf, color, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = o.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local solid = o.solid ~= false
	p.CanCollide = solid
	p.CanQuery = solid
	p.CanTouch = false
	if o.neon or o.shadow == false then
		p.CastShadow = false
	end
	if o.transparency then
		p.Transparency = o.transparency
	end
	if o.shape then
		p.Shape = o.shape
	end
	if o.studs then
		studs(p, o.studs)
	end
	p.Parent = parent
	made += 1
	if made % 300 == 0 then
		task.wait()
	end
	return p
end

-- axis-aligned block from its min / max corners
local function box(parent, name, x0, x1, y0, y1, z0, z1, color, o)
	if x0 > x1 then
		x0, x1 = x1, x0
	end
	if z0 > z1 then
		z0, z1 = z1, z0
	end
	return part(parent, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, o)
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- navy board with a gold frame and gold text on its Front face (cf's look vector points at the reader);
-- WorldTextController adds the gradient and outline in game
local function sign(parent, name, cf, w, h, text)
	local m = model(parent, name)
	local b = part(m, "Board", Vector3.new(w, h, 0.8), cf, P.Navy)
	local t = 0.8
	part(m, "Trim", Vector3.new(w + t * 2, t, 1.2), cf * CFrame.new(0, h / 2 + t / 2, 0), P.Gold, { solid = false })
	part(m, "Trim", Vector3.new(w + t * 2, t, 1.2), cf * CFrame.new(0, -h / 2 - t / 2, 0), P.Gold, { solid = false })
	part(m, "Trim", Vector3.new(t, h, 1.2), cf * CFrame.new(w / 2 + t / 2, 0, 0), P.Gold, { solid = false })
	part(m, "Trim", Vector3.new(t, h, 1.2), cf * CFrame.new(-w / 2 - t / 2, 0, 0), P.Gold, { solid = false })
	local g = Instance.new("SurfaceGui")
	g.Face = N.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = math.clamp(math.floor(110 / h), 4, 30) -- scaled text tops out at 100 px, so ~110 px of board height
	g.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Name = "Label"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(0.94, 0.84)
	l.Position = UDim2.fromScale(0.03, 0.08)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = P.Gold
	l.Text = text
	l.Parent = g
	g.Parent = b
	return m
end

-- three stacked neon blocks and a warm light; pos = the bottom of the flame
local function flame(parent, pos, s, light)
	s = s or 1
	local a = part(parent, "Flame", Vector3.new(3.4, 3, 3.4) * s, CFrame.new(pos + Vector3.new(0, 1.5 * s, 0)) * CFrame.Angles(0, math.rad(45), 0), P.FlameA, { neon = true, solid = false })
	part(parent, "Flame", Vector3.new(2.3, 2.6, 2.3) * s, CFrame.new(pos + Vector3.new(0.2 * s, 3.6 * s, -0.1 * s)) * CFrame.Angles(0, math.rad(20), 0), P.FlameB, { neon = true, solid = false })
	part(parent, "Flame", Vector3.new(1.2, 1.8, 1.2) * s, CFrame.new(pos + Vector3.new(-0.1 * s, 5.5 * s, 0.2 * s)) * CFrame.Angles(0, math.rad(60), 0), P.FlameC, { neon = true, solid = false })
	if light ~= false then
		local l = Instance.new("PointLight")
		l.Color = hex("FF9A40")
		l.Range = 18 * s
		l.Brightness = 1.4
		l.Shadows = false
		l.Parent = a
	end
end

local function brazier(parent, x, z, y0, s)
	s = s or 1
	local m = model(parent, "Brazier")
	box(m, "Base", x - 2.8 * s, x + 2.8 * s, y0, y0 + 1.5 * s, z - 2.8 * s, z + 2.8 * s, P.StoneDark, { studs = ALL })
	box(m, "Pillar", x - 1.7 * s, x + 1.7 * s, y0 + 1.5 * s, y0 + 8.5 * s, z - 1.7 * s, z + 1.7 * s, P.StoneB, { studs = SIDES })
	box(m, "Bowl", x - 3 * s, x + 3 * s, y0 + 8.5 * s, y0 + 10.5 * s, z - 3 * s, z + 3 * s, P.StoneDark, { studs = SIDES })
	box(m, "Rim", x - 3.3 * s, x + 3.3 * s, y0 + 10.5 * s, y0 + 11.1 * s, z - 3.3 * s, z + 3.3 * s, P.Gold, { solid = false })
	flame(m, Vector3.new(x, y0 + 11.1 * s, z), s)
	return m
end

-- a fire bowl on a bracket sticking out of a wall face at x = xFace, pointing -X
local function sconce(parent, xFace, z, y)
	local m = model(parent, "Sconce")
	box(m, "Bracket", xFace - 3, xFace, y - 2.2, y, z - 1.3, z + 1.3, P.StoneDark, { studs = ALL, solid = false })
	box(m, "Bowl", xFace - 5.2, xFace - 0.6, y, y + 1.6, z - 2.3, z + 2.3, P.StoneDark, { studs = SIDES, solid = false })
	box(m, "Rim", xFace - 5.4, xFace - 0.4, y + 1.6, y + 2, z - 2.5, z + 2.5, P.Gold, { solid = false })
	flame(m, Vector3.new(xFace - 2.9, y + 2, z), 0.75)
end

-- hanging banner: cf = the rod's centre, its look vector = the side the banner faces; w wide, h long, with an optional
-- colour band, a diamond emblem and a swallowtail
local function banner(parent, cf, w, h, cloth, band, emblem)
	local m = model(parent, "Banner")
	part(m, "Rod", Vector3.new(w + 2, 0.8, 0.8), cf, P.Gold, { solid = false })
	local tail = math.min(3.5, h * 0.18)
	local body = h - tail
	part(m, "Cloth", Vector3.new(w, body, 0.4), cf * CFrame.new(0, -body / 2 - 0.4, 0), cloth, { solid = false })
	for _, sx in { -1, 1 } do
		part(m, "Tail", Vector3.new(w * 0.4, tail, 0.4), cf * CFrame.new(sx * w * 0.3, -body - 0.4 - tail / 2, 0), cloth, { solid = false })
	end
	if band then
		part(m, "Band", Vector3.new(w, math.max(1, h * 0.1), 0.5), cf * CFrame.new(0, -h * 0.16, -0.05), band, { solid = false })
	end
	if emblem then
		local e = math.min(w * 0.42, h * 0.2)
		part(m, "Emblem", Vector3.new(e, e, 0.5), cf * CFrame.new(0, -h * 0.46, -0.05) * CFrame.Angles(0, 0, math.rad(45)), emblem, { solid = false })
	end
	return m
end

-- a row of battlement blocks from p0 to p1 (y ignored): mw long, mh tall, md deep, about gap apart
local function merlonLine(parent, p0, p1, y0, mw, mh, md, color, gap)
	local d = Vector3.new(p1.X - p0.X, 0, p1.Z - p0.Z)
	local len = d.Magnitude
	if len < mw then
		return
	end
	local dir = d.Unit
	local n = math.max(1, math.floor((len + gap) / (mw + gap)))
	local step = n > 1 and (len - mw) / (n - 1) or 0
	for i = 0, n - 1 do
		local c = Vector3.new(p0.X, y0 + mh / 2, p0.Z) + dir * (mw / 2 + i * step)
		part(parent, "Merlon", Vector3.new(mw, mh, md), CFrame.lookAt(c, c + dir) * CFrame.Angles(0, math.rad(90), 0), color, { studs = ALL })
	end
end

-- battlements round a rectangle (centre cx, cz; half sizes hx, hz); every corner is covered exactly once
local function merlonRect(parent, cx, cz, hx, hz, y, mw, mh, md, color)
	local c = { Vector3.new(cx - hx, 0, cz - hz), Vector3.new(cx + hx, 0, cz - hz), Vector3.new(cx + hx, 0, cz + hz), Vector3.new(cx - hx, 0, cz + hz) }
	local centre = Vector3.new(cx, 0, cz)
	for i = 1, 4 do
		local a, b = c[i], c[i % 4 + 1]
		local dir = (b - a).Unit
		local inward = (centre - (a + b) / 2).Unit
		merlonLine(parent, a + inward * md / 2, b + inward * md / 2 - dir * md, y, mw, mh, md, color, 2.5)
	end
end

------------------------------------------------------------------------------- ground
-- 12-stud checker tiles (same grid and greens as before) over x -120..302, z -160..160; the avenue (x > 0, |z| < 20) and
-- the hall floor (inside 74 studs of the leaderboards' centre, west of the market) are paved in two-tone stone.
local function buildGround(map)
	local ground = map:FindFirstChild("Ground")
	if ground then
		ground:ClearAllChildren()
	else
		ground = folder(map, "Ground")
	end
	local xs = {}
	for x = -120, 288, 12 do
		table.insert(xs, x)
	end
	table.insert(xs, 300)
	table.insert(xs, 302)
	local zs = { -160, 160, -20, 20 }
	for z = -156, 156, 12 do
		table.insert(zs, z)
	end
	table.sort(zs)
	for i = 1, #xs - 1 do
		local x0, x1 = xs[i], xs[i + 1]
		local xc = (x0 + x1) / 2
		for j = 1, #zs - 1 do
			local z0, z1 = zs[j], zs[j + 1]
			local zc = (z0 + z1) / 2
			local odd = (math.floor(xc / 12) + math.floor(zc / 12)) % 2 == 1
			local paved = (xc > 0 and math.abs(zc) < 20) or (xc < -36 and (Vector3.new(xc, 0, zc) - HALL).Magnitude < 74)
			local color = paved and (odd and P.PaveB or P.PaveA) or (odd and P.GrassB or P.GrassA)
			box(ground, "Tile", x0, x1, -2, 0, z0, z1, color, { studs = TOP })
		end
	end
end

------------------------------------------------------------------------------- walls
-- straight curtain wall along the line a -> b (ground level), outward = unit vector away from the courtyard
local function curtain(parent, name, a, b, outward, accents, o)
	o = o or {}
	local m = model(parent, name)
	local T = WALL_T
	local L = (b - a).Magnitude
	local mid = (a + b) / 2
	local frame = CFrame.lookAt(mid, mid + outward) -- local +Z faces the courtyard, local X runs along the wall
	local function lp(nm, size, pos, color, opt)
		return part(m, nm, size, frame * CFrame.new(pos), color, opt)
	end
	lp("Wall", Vector3.new(L, WALL_H, T), Vector3.new(0, WALL_H / 2, 0), P.StoneA, { studs = { N.Back, N.Top } })
	lp("Base", Vector3.new(L, 5, 1.2), Vector3.new(0, 2.5, T / 2 + 0.6), P.StoneDark, { studs = { N.Back, N.Top } })
	lp("Course", Vector3.new(L, 2, 1.2), Vector3.new(0, 35, T / 2 + 0.6), P.StoneDark, { studs = { N.Back, N.Top }, solid = false })
	lp("Coping", Vector3.new(L, 1.5, T + 1.2), Vector3.new(0, WALL_H + 0.75, 0), P.StoneB, { studs = { N.Back, N.Top } })
	local edge = -T / 2 + 1.25
	merlonLine(m, frame:PointToWorldSpace(Vector3.new(-L / 2, 0, edge)), frame:PointToWorldSpace(Vector3.new(L / 2, 0, edge)), WALL_H + 1.5, 4, 5, 2.5, P.StoneA, 3)
	local bays = math.max(1, math.floor(L / 36 + 0.5))
	local bay = L / bays
	for i = 0, bays do
		lp("Pilaster", Vector3.new(4, 34, 1.6), Vector3.new(-L / 2 + i * bay, 17, T / 2 + 0.8), P.StoneB, { studs = { N.Back, N.Left, N.Right } })
	end
	if accents then
		local k = o.colorPhase or 0
		for i = 0, bays - 1 do
			local x = -L / 2 + (i + 0.5) * bay
			local world = frame:PointToWorldSpace(Vector3.new(x, 0, 0))
			local hidden = o.skip and o.skip(world)
			if i % 2 == 0 and not hidden then
				k += 1
				banner(m, frame * CFrame.new(x, 33.2, T / 2 + 1.4) * CFrame.Angles(0, math.pi, 0), 8, 18, P.Navy, accents[(k - 1) % #accents + 1], P.Gold)
			end
		end
	end
	return m
end

local function buildWalls(root, map, ctx)
	local f = folder(root, "Walls")
	local A = ctx.accents
	curtain(f, "WallNorth", Vector3.new(-124, 0, 162), Vector3.new(304, 0, 162), Vector3.new(0, 0, 1), A, { colorPhase = 0 })
	curtain(f, "WallSouth", Vector3.new(-124, 0, -162), Vector3.new(304, 0, -162), Vector3.new(0, 0, -1), A, { colorPhase = 3 })
	-- the west wall runs into the Keep's front corner towers (z +-71)
	curtain(f, "WallWestN", Vector3.new(-120, 0, 70), Vector3.new(-120, 0, 166), Vector3.new(-1, 0, 0), A, { colorPhase = 5 })
	curtain(f, "WallWestS", Vector3.new(-120, 0, -166), Vector3.new(-120, 0, -70), Vector3.new(-1, 0, 0), A, { colorPhase = 6 })
	curtain(f, "WallEastN", Vector3.new(300, 0, 92), Vector3.new(300, 0, 166), Vector3.new(1, 0, 0), A, { colorPhase = 1 })
	curtain(f, "WallEastS", Vector3.new(300, 0, -166), Vector3.new(300, 0, -92), Vector3.new(1, 0, 0), A, { colorPhase = 2 })
end

------------------------------------------------------------------------------- towers
-- square tower: plinth, body, band, arrow slits, corbelled top with battlements, stepped navy roof, gold finial and flag
local function tower(parent, cx, cz, W, H, flagColor, o)
	o = o or {}
	local m = model(parent, o.name or "Tower")
	local h2 = W / 2
	box(m, "Plinth", cx - h2 - 1.5, cx + h2 + 1.5, 0, 6, cz - h2 - 1.5, cz + h2 + 1.5, P.StoneDark, { studs = ALL })
	box(m, "Body", cx - h2, cx + h2, 6, H, cz - h2, cz + h2, P.StoneA, { studs = SIDES })
	local bandY = math.floor(H * 0.5)
	box(m, "Band", cx - h2 - 0.6, cx + h2 + 0.6, bandY, bandY + 2, cz - h2 - 0.6, cz + h2 + 0.6, P.StoneDark, { studs = ALL, solid = false })
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local x, z = cx + d[1] * (h2 + 0.1), cz + d[2] * (h2 + 0.1)
		for _, y in { H * 0.32, H * 0.74 } do
			part(m, "Slit", Vector3.new(d[1] ~= 0 and 0.4 or 1.6, 6, d[2] ~= 0 and 0.4 or 1.6), CFrame.new(x, y, z), P.Navy, { solid = false })
		end
	end
	local cw = h2 + 1.6
	box(m, "Corbel", cx - cw, cx + cw, H, H + 3, cz - cw, cz + cw, P.StoneB, { studs = ALLB })
	merlonRect(m, cx, cz, cw, cw, H + 3, 3, 4.5, 2.5, P.StoneA)
	local steps, stepH = o.steps or 4, o.stepH or 4.5
	for i = 0, steps - 1 do
		local w = (W - 3) * (1 - i / (steps + 0.6))
		box(m, "Roof", cx - w / 2, cx + w / 2, H + 3 + i * stepH, H + 3 + (i + 1) * stepH, cz - w / 2, cz + w / 2, i % 2 == 0 and P.Navy or P.NavyLight, { studs = ALL })
	end
	local top = H + 3 + steps * stepH
	box(m, "Finial", cx - 1.2, cx + 1.2, top, top + 3, cz - 1.2, cz + 1.2, P.Gold, { studs = ALL })
	box(m, "FlagPole", cx - 0.35, cx + 0.35, top + 3, top + 13, cz - 0.35, cz + 0.35, P.GoldDeep, { solid = false })
	box(m, "Flag", cx + 0.35, cx + 7.35, top + 8.6, top + 12.6, cz - 0.15, cz + 0.15, flagColor, { solid = false })
	return m
end

local function buildTowers(root, map, ctx)
	local f = folder(root, "Towers")
	local list = {
		{ -120, 162, 24, 62 },
		{ -120, -162, 24, 62 },
		{ 300, 162, 24, 62 },
		{ 300, -162, 24, 62 },
		{ -15, 162, 22, 58 },
		{ 90, 162, 22, 58 },
		{ 195, 162, 22, 58 },
		{ -15, -162, 22, 58 },
		{ 90, -162, 22, 58 },
		{ 195, -162, 22, 58 },
		{ -120, 118, 22, 58 },
		{ -120, -118, 22, 58 },
	}
	for i, t in list do
		tower(f, t[1], t[2], t[3], t[4], ctx.accents[(i - 1) % #ctx.accents + 1])
	end
end

-- the Grand Gate and the Keep are in the child modules Gate and Keep (shared kit: Kit)

------------------------------------------------------------------------------- Hall of Champions
local function buildHall(root, map, ctx)
	local f = model(root, "Hall")
	local R0, R1 = 67, 71
	local segs, span = 20, math.rad(124)
	local dt = span / segs
	for i = 0, segs - 1 do
		local th = -span / 2 + (i + 0.5) * dt
		local dir = Vector3.new(-math.cos(th), 0, math.sin(th))
		local h = math.abs(math.deg(th)) < 19 and 36 or 44 -- lower behind the Rewards board
		local pos = HALL + dir * (R0 + R1) / 2
		local frame = CFrame.lookAt(pos, pos + dir) -- local +Z faces the plaza
		local len = 2 * R1 * math.sin(dt / 2) + 0.3
		part(f, "HallWall", Vector3.new(len, h, R1 - R0), frame * CFrame.new(0, h / 2, 0), P.StoneA, { studs = { N.Back, N.Top } })
		part(f, "HallBase", Vector3.new(len, 4, 1), frame * CFrame.new(0, 2, (R1 - R0) / 2 + 0.5), P.StoneDark, { studs = { N.Back, N.Top } })
		part(f, "HallTrim", Vector3.new(len + 0.2, 0.8, R1 - R0 + 0.6), frame * CFrame.new(0, h + 0.4, 0), P.Gold, { studs = TOP })
	end
	-- columns in the gaps between the boards and at both ends
	for _, deg in { 19.5, 39, 58.5 } do
		for _, s in { -1, 1 } do
			local th = math.rad(deg * s)
			local dir = Vector3.new(-math.cos(th), 0, math.sin(th))
			local pos = HALL + dir * 65.3
			local frame = CFrame.lookAt(pos, pos + dir)
			part(f, "ColumnBase", Vector3.new(5, 2, 5), frame * CFrame.new(0, 1, 0), P.StoneDark, { studs = ALL })
			part(f, "Column", Vector3.new(3.4, 44, 3.4), frame * CFrame.new(0, 24, 0), P.StoneB, { studs = SIDES })
			part(f, "Capital", Vector3.new(5, 2, 5), frame * CFrame.new(0, 47, 0), P.Gold, { studs = ALL })
		end
	end
	-- stone pedestals under the six floor boards (they used to float); a shelf under the Rewards board
	local boards = map:FindFirstChild("Leaderboards")
	if boards then
		for _, b in boards:GetChildren() do
			if b:IsA("Model") then
				local cf, size = b:GetBoundingBox()
				local bottom = cf.Y - size.Y / 2
				local look = b:GetPivot().LookVector
				local flat = Vector3.new(look.X, 0, look.Z).Unit
				if bottom > 4 and bottom < 16 then
					local base = CFrame.lookAt(Vector3.new(cf.X, 0, cf.Z), Vector3.new(cf.X, 0, cf.Z) + flat)
					local ph = bottom - 0.5
					part(f, "Pedestal", Vector3.new(15, ph, 3), base * CFrame.new(0, ph / 2, 0), P.StoneDark, { studs = ALL })
					part(f, "PedestalTrim", Vector3.new(17, 0.5, 3.6), base * CFrame.new(0, ph + 0.25, 0), P.Gold, { studs = TOP })
				elseif bottom >= 16 then
					local edge = cf * CFrame.new(0, -size.Y / 2, 0)
					box(f, "Shelf", -106, edge.X + 1.5, edge.Y - 2.4, edge.Y - 0.3, -size.X / 2 - 0.6, size.X / 2 + 0.6, P.StoneB, { studs = ALLB })
					box(f, "ShelfTrim", edge.X - 0.5, edge.X + 1.8, edge.Y - 0.3, edge.Y + 0.1, -size.X / 2 - 0.6, size.X / 2 + 0.6, P.Gold, { solid = false })
				end
			end
		end
	end
	for _, s in { -1, 1 } do
		local th = math.rad(64 * s)
		local p = HALL + Vector3.new(-math.cos(th), 0, math.sin(th)) * 66
		brazier(f, p.X, p.Z, 0, 1.15)
	end
end

------------------------------------------------------------------------------- the two colossal statues
-- Gilds a kaiju for a statue: like Util.GoldVariant (each brick's brightness picks a shade of gold, so the pattern still
-- reads) but the darkest bricks become bronze instead of near-black, which looked like holes at statue scale; glowing
-- (Neon) bricks keep glowing in warm gold.
local GILD_DEEP, GILD_MID, GILD_PALE = Color3.fromRGB(168, 104, 22), Color3.fromRGB(236, 166, 32), Color3.fromRGB(255, 226, 112)
local function gild(model)
	local root = model.PrimaryPart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root and d.Transparency < 1 then
			if d.Material == Enum.Material.Neon then
				d.Color = hex("FFB52E")
			else
				local c = d.Color
				local t = math.clamp((0.299 * c.R + 0.587 * c.G + 0.114 * c.B - 0.05) / 0.75, 0, 1)
				d.Color = t < 0.5 and GILD_DEEP:Lerp(GILD_MID, t * 2) or GILD_MID:Lerp(GILD_PALE, (t - 0.5) * 2)
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
			end
		elseif d:IsA("Texture") or d:IsA("Decal") then
			d.Color3 = Color3.fromRGB(255, 214, 110)
		end
	end
end

local function statue(parent, kaijuName, cx, cz, scale, title, lookAt)
	local m = model(parent, "Statue_" .. kaijuName)
	local centre = Vector3.new(cx, 0, cz)
	local dir = Vector3.new(lookAt.X - cx, 0, lookAt.Z - cz).Unit
	local F = CFrame.lookAt(centre, centre + dir)
	-- fountain: a voxel ring of stone on a 4-stud grid (runs merged), a dark floor and water
	local R0, R1, cell = 23, 28, 4
	for gz = -R1, R1 - cell, cell do
		local run
		for gx = -R1, R1, cell do
			local inRing = false
			if gx < R1 then
				local r = math.sqrt((gx + cell / 2) ^ 2 + (gz + cell / 2) ^ 2)
				inRing = r <= R1 and r > R0
			end
			if inRing and not run then
				run = gx
			elseif not inRing and run then
				box(m, "Basin", cx + run, cx + gx, 0, 3, cz + gz, cz + gz + cell, ((gz // cell) % 2 == 0) and P.StoneB or P.StoneA, { studs = ALL })
				run = nil
			end
		end
	end
	part(m, "BasinFloor", Vector3.new(0.3, 49, 49), CFrame.new(cx, 0.15, cz) * CFrame.Angles(0, 0, math.rad(90)), P.StoneDeep, { shape = Enum.PartType.Cylinder })
	part(m, "Water", Vector3.new(2, 49, 49), CFrame.new(cx, 1.3, cz) * CFrame.Angles(0, 0, math.rad(90)), P.Water, { shape = Enum.PartType.Cylinder, transparency = 0.25, solid = false, shadow = false })
	-- stepped plinth, turned with the statue, a name plaque on its front
	local function lp(nm, size, y, color, o)
		return part(m, nm, size, F * CFrame.new(0, y, 0), color, o)
	end
	lp("Plinth", Vector3.new(26, 6, 26), 3, P.StoneDark, { studs = ALL })
	lp("Plinth", Vector3.new(22, 8, 22), 10, P.StoneA, { studs = ALL })
	lp("PlinthTrim", Vector3.new(23.2, 1, 23.2), 14.5, P.Gold, { studs = ALL })
	lp("Plinth", Vector3.new(19, 3, 19), 16.5, P.StoneB, { studs = ALL })
	sign(m, "Plaque", F * CFrame.new(0, 10, -11.5), 15, 3.6, title)
	-- lanterns round the basin, on the plinth's diagonals (clear of the plaque)
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local at = F:PointToWorldSpace(Vector3.new(math.cos(a) * 31, 0, math.sin(a) * 31))
		local x, z = at.X, at.Z
		box(m, "LanternPost", x - 0.7, x + 0.7, 0, 10, z - 0.7, z + 0.7, P.Navy, { studs = SIDES })
		box(m, "LanternBase", x - 1.6, x + 1.6, 10, 10.6, z - 1.6, z + 1.6, P.Gold, { solid = false })
		local core = box(m, "Lantern", x - 1.1, x + 1.1, 10.6, 13.2, z - 1.1, z + 1.1, P.FlameC, { neon = true, solid = false })
		box(m, "LanternCap", x - 1.7, x + 1.7, 13.2, 14, z - 1.7, z + 1.7, P.Gold, { solid = false })
		local l = Instance.new("PointLight")
		l.Color = hex("FFC870")
		l.Range = 14
		l.Brightness = 1.2
		l.Parent = core
	end
	-- the statue: the real sculpted kaiju, gilded and scaled up, with every gameplay attribute stripped
	local src = ServerStorage:FindFirstChild("Assets") and ServerStorage.Assets.Kaiju:FindFirstChild(kaijuName)
	if not src then
		warn("[Citadel] no kaiju asset " .. kaijuName)
		return m
	end
	local s = src:Clone()
	for k in s:GetAttributes() do
		s:SetAttribute(k, nil)
	end
	for _, d in s:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("JointInstance") or d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	gild(s)
	s.Name = "Golden" .. kaijuName
	s:ScaleTo(scale)
	s:PivotTo(F * CFrame.new(0, 18, 0))
	local bb, size = s:GetBoundingBox()
	s:PivotTo(s:GetPivot() + Vector3.new(0, 18 - (bb.Y - size.Y / 2), 0))
	s.Parent = m
	return m
end

local function buildStatues(root, map, ctx)
	local f = folder(root, "Statues")
	local target = Vector3.new(10, 0, 0) -- both face the spot where the market meets the avenue
	statue(f, "Thunderback", -50, 108, 8, "THUNDERBACK", target)
	statue(f, "IcebreakerRex", -50, -108, 9.5, "ICEBREAKER REX", target)
end

------------------------------------------------------------------------------- the avenue
local function bannerPole(parent, x, z, armDir, side)
	local m = model(parent, "BannerPole")
	box(m, "Base", x - 1.6, x + 1.6, 0, 1.2, z - 1.6, z + 1.6, P.StoneDark, { studs = ALL })
	box(m, "Pole", x - 0.6, x + 0.6, 1.2, 30, z - 0.6, z + 0.6, P.Navy, { studs = SIDES })
	box(m, "Cap", x - 1.1, x + 1.1, 30, 32.2, z - 1.1, z + 1.1, P.Gold, { studs = ALL })
	box(m, "Arm", x, x + armDir * 8.5, 27.4, 28.4, z - 0.4, z + 0.4, P.Gold, { solid = false })
	local bx = x + armDir * 4.8
	banner(m, CFrame.lookAt(Vector3.new(bx, 27, z), Vector3.new(bx, 27, z - side * 10)), 6.5, 15, P.Navy, P.Gold, P.Gold)
end

local function buildAvenue(root, map, ctx)
	local f = folder(root, "Avenue")
	for _, s in { -1, 1 } do
		box(f, "Curb", 0, 289, 0, 0.35, s * 20, s * 21.4, P.StoneDark, { studs = TOP, solid = false })
	end
	for _, x in { 14, 109, 205 } do
		for _, s in { -1, 1 } do
			brazier(f, x, s * 24, 0, 1)
		end
	end
	for _, gx in { 109, 205 } do
		for _, s in { -1, 1 } do
			bannerPole(f, gx - 9, s * 29, 1, s)
			bannerPole(f, gx + 9, s * 29, -1, s)
		end
	end
end

------------------------------------------------------------------------------- plot gatehouses (in each Plot's Arch)
local function buildGatehouses(root, map, ctx)
	local plots = map:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		local arch = plot:FindFirstChild("Arch")
		local origin = plot:GetAttribute("PenOrigin")
		local side = plot:GetAttribute("Side")
		local color = plot:GetAttribute("Color") or P.Gold
		if arch and origin and side then
			for _, c in arch:GetChildren() do
				if c.Name:sub(1, 9) == "Gatehouse" then
					c:Destroy()
				end
			end
			local cx, fz, a = origin.X, origin.Z, -side -- a: from the fence towards the avenue
			local z0, z1 = fz + a * 0.3, fz + a * 4.3
			local zc = (z0 + z1) / 2
			local pillars, flags = {}, {}
			for _, c in arch:GetChildren() do
				if c.Name == "Pillar" then
					table.insert(pillars, c)
				elseif c.Name == "Flag" then
					table.insert(flags, c)
				end
			end
			table.sort(pillars, function(p, q)
				return p.Position.X < q.Position.X
			end)
			table.sort(flags, function(p, q)
				return p.Position.X < q.Position.X
			end)
			for i, sx in { -1, 1 } do
				local tx = cx + sx * 10.2
				local pil = pillars[i]
				if pil then
					for _, t in pil:GetChildren() do
						if t:IsA("Texture") then
							t:Destroy()
						end
					end
					pil.Size = Vector3.new(4, 15, 4)
					pil.CFrame = CFrame.new(tx, 7.5, zc)
					pil.Color = P.StoneA
					pil.Material = Enum.Material.SmoothPlastic
					studs(pil, SIDES)
				end
				box(arch, "GatehouseBand", tx - 2.3, tx + 2.3, 4, 5.2, zc - 2.3, zc + 2.3, color, { solid = false })
				box(arch, "GatehouseCap", tx - 2.7, tx + 2.7, 15, 16.5, zc - 2.7, zc + 2.7, P.StoneB, { studs = ALLB })
				for _, mx in { -1, 1 } do
					for _, mz in { -1, 1 } do
						box(arch, "GatehouseMerlon", tx + mx * 2.7 - 1.4, tx + mx * 2.7 + 1.4, 16.5, 18.5, zc + mz * 2.7 - 1.4, zc + mz * 2.7 + 1.4, P.StoneA, { studs = ALL })
					end
				end
				box(arch, "GatehousePole", tx - 0.25, tx + 0.25, 16.5, 24, zc - 0.25, zc + 0.25, P.GoldDeep, { solid = false })
				local fl = flags[i]
				if fl then
					fl.Size = Vector3.new(0.2, 2.6, 4)
					fl.CFrame = CFrame.new(tx, 22.6, zc + a * 2.2)
				end
			end
			box(arch, "GatehouseLintel", cx - 12.2, cx + 12.2, 11.7, 14.2, z0, z1, P.StoneB, { studs = ALLB })
			box(arch, "GatehouseTrim", cx - 12.2, cx + 12.2, 11.1, 11.7, z0, z1, color, { solid = false })
		end
	end
end

------------------------------------------------------------------------------- backdrop hills
local function hillHeight(x, z, lo, hi, seed)
	local n = math.noise(x / 70 + seed * 0.37, z / 70, 0.5)
	local k = math.clamp(n + 0.5, 0, 1)
	return math.floor((lo + (hi - lo) * k) / 2 + 0.5) * 2
end

local function buildBackdrop(root, map, ctx)
	local f = folder(root, "Backdrop")
	local function hill(x0, x1, z0, z1, h, tier)
		local body = tier == 1 and P.Dirt or P.DirtDark
		local cap = tier == 1 and P.GrassCap or P.GrassCapDark
		box(f, "Hill", x0, x1, -60, h, z0, z1, body, { studs = SIDES, solid = false, shadow = false })
		box(f, "HillCap", x0 - 1, x1 + 1, h, h + 2, z0 - 1, z1 + 1, cap, { studs = ALL, solid = false, shadow = false })
	end
	for _, s in { -1, 1 } do
		for x = -130, 301, 30 do
			local x1 = math.min(x + 30, 302)
			hill(x, x1, s * 172, s * 250, hillHeight(x, s * 200, 50, 86, 1), 1)
			hill(x, x1, s * 250, s * 340, hillHeight(x, s * 300, 96, 150, 2), 2)
		end
	end
	for z = -340, 339, 30 do
		if z + 30 <= -70 or z >= 70 then -- the Keep stands in the middle
			hill(-250, -130, z, z + 30, hillHeight(-190, z, 50, 86, 3), 1)
		end
		hill(-340, -250, z, z + 30, hillHeight(-300, z, 96, 150, 4), 2)
	end
end

------------------------------------------------------------------------------- entry point
local SECTIONS = {
	{ "Ground", buildGround },
	{ "Walls", buildWalls },
	{ "Towers", buildTowers },
	{
		"GrandGate",
		function(root, map, ctx)
			return require(script.Gate)(root, map, ctx, Kit)
		end,
	},
	{
		"Keep",
		function(root, map, ctx)
			return require(script.Keep)(root, map, ctx, Kit)
		end,
	},
	{ "Hall", buildHall },
	{ "Statues", buildStatues },
	{ "Avenue", buildAvenue },
	{ "Gatehouses", buildGatehouses },
	{ "Backdrop", buildBackdrop },
}

function C.Build(only)
	local map = workspace:FindFirstChild("Map")
	assert(map, "no workspace.Map")
	local BiomeConfig = fresh(ReplicatedStorage.Shared.Config.BiomeConfig)
	local ctx = { accents = {} }
	for _, b in BiomeConfig.All do
		table.insert(ctx.accents, b.Accent or b.Border or P.Gold)
	end
	local root = map:FindFirstChild("Citadel")
	if not root then
		root = folder(map, "Citadel")
	end
	made = 0
	Kit.reset()
	local done = {}
	for _, sec in SECTIONS do
		local name, build = sec[1], sec[2]
		if not only or table.find(only, name) then
			local old = root:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			if name == "Ground" then
				build(map)
			else
				build(root, map, ctx)
			end
			table.insert(done, name)
			task.wait()
		end
	end
	-- the old dirt walls are replaced by the citadel walls
	local oldWalls = map:FindFirstChild("Walls")
	if oldWalls and (not only or table.find(only, "Walls")) then
		oldWalls:Destroy()
	end
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("Citadel: built %s (%d new parts this run, %d in Map.Citadel)", table.concat(done, ", "), made + Kit.count(), n)
end

return C
