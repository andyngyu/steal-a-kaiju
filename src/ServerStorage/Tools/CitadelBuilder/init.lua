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

-- the walls and towers are in the child module Walls; the Grand Gate and the Keep in Gate and Keep (shared kit: Kit)

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
		if z + 30 <= -85 or z >= 85 then -- the Keep stands in the middle
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
