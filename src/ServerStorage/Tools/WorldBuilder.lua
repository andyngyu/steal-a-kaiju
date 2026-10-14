-- Edit-time builder for the new world (see Tools.WorldLayout for the measurements).
--   local W = require(game.ServerStorage.Tools.WorldBuilder:Clone())
--   W.Blockout()        grey true-scale block-out of the whole world, 3000 studs above the map (Workspace.WorldBlockout)
--   W.ClearBlockout()
-- The block-out is only for reviewing layout and scale: nothing in it collides or is used by the game.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

local W = {}
local OY = 0 -- vertical offset of the build
local hex = Color3.fromHex
local GRAY = hex("8A8D92")
local AMBER = hex("E8A33D")

local function part(parent, name, size, cf, color, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency = o.transparency or 0
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	if o.shape then
		p.Shape = o.shape
	end
	p.Parent = parent
	return p
end

-- axis-aligned box from its min / max corners (y measured from the build's ground)
local function box(parent, name, x0, x1, y0, y1, z0, z1, color, o)
	return part(parent, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), CFrame.new((x0 + x1) / 2, OY + (y0 + y1) / 2, (z0 + z1) / 2), color, o)
end

local function cylinder(parent, name, x, z, y0, h, r, color, o)
	o = o or {}
	o.shape = Enum.PartType.Cylinder
	return part(parent, name, Vector3.new(h, r * 2, r * 2), CFrame.new(x, OY + y0 + h / 2, z) * CFrame.Angles(0, 0, math.rad(90)), color, o)
end

local function label(p, face, text, color)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 8
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Text = text
	t.Parent = g
	g.Parent = p
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- stepped square cone (volcanoes, temples, peaks)
local function cone(parent, name, cx, cz, y0, w0, w1, h, steps, color, top)
	for i = 0, steps - 1 do
		local t = i / steps
		local w = w0 + (w1 - w0) * t
		box(parent, name, cx - w / 2, cx + w / 2, y0 + h * t, y0 + h * (i + 1) / steps, cz - w / 2, cz + w / 2, (i == steps - 1 and top) or color)
	end
end

------------------------------------------------------------------------------- the Citadel
local function buildHub(root, L)
	local H = L.Hub
	local f = folder(root, "Citadel")
	local stone, stoneLight = hex("8F8A80"), hex("A39E92")
	box(f, "Ground", H.x0, H.x1, -1, 0, -H.halfZ, H.halfZ, hex("8FA285"))
	box(f, "Avenue", -12, H.x1, 0, 0.3, -H.avenueHalf, H.avenueHalf, hex("CFC6B0"))
	cylinder(f, "Plaza", H.plaza.X, H.plaza.Z, 0, 0.4, H.plazaR, hex("D6CDB6"))
	cylinder(f, "Fountain", H.plaza.X, H.plaza.Z, 0.4, 2.5, H.fountainR, hex("7FB6D6"))
	-- the colossal statue: plinth + a placeholder figure, 65 tall
	cylinder(f, "StatuePlinth", H.plaza.X, H.plaza.Z, 0, 14, 10, stoneLight)
	box(f, "Statue", H.plaza.X - 9, H.plaza.X + 9, 14, H.statueH, H.plaza.Z - 7, H.plaza.Z + 7, hex("C9A64A"))
	box(f, "StatueHead", H.plaza.X - 16, H.plaza.X - 4, 50, H.statueH - 2, H.plaza.Z - 6, H.plaza.Z + 6, hex("C9A64A"))
	-- bazaar stalls
	for n, p in H.stalls do
		local s = box(f, "Stall" .. n, p.X - 7, p.X + 7, 0, 12, p.Z - 6, p.Z + 6, hex("B07A4A"))
		box(f, "Awning", p.X - 8, p.X + 8, 12, 13.2, p.Z - 7, p.Z + 7, n == "Food" and hex("FF8A1F") or n == "Trail" and hex("3FA9FF") or n == "Sell" and hex("2FBF71") or hex("D9A520"))
		label(s, Enum.NormalId.Top, n)
	end
	-- Hall of Champions: a colonnade arc on the plaza's west side, roofed
	for k = 0, 8 do
		local a = math.rad(130 + k * 12.5)
		local cx, cz = H.plaza.X + math.cos(a) * H.hallR, H.plaza.Z + math.sin(a) * H.hallR
		cylinder(f, "Column", cx, cz, 0, 34, 2.4, stoneLight)
	end
	for k = 0, 7 do
		local a = math.rad(136 + k * 12.5)
		local cx, cz = H.plaza.X + math.cos(a) * H.hallR, H.plaza.Z + math.sin(a) * H.hallR
		part(f, "HallRoof", Vector3.new(18, 3, 10), CFrame.new(cx, OY + 35.5, cz) * CFrame.Angles(0, -a + math.pi / 2, 0), stone)
	end
	-- plots: lot outline + gatehouse in the plot colour
	local colors = { hex("FF4D5E"), hex("3FA9FF"), hex("FFD23F"), hex("B05CFF"), hex("FF8A1F"), hex("2FD3B5") }
	for i, lx in H.lots do
		for _, side in { -1, 1 } do
			local idx = side < 0 and i or i + 3
			local zFront, zBack = side * H.lotFront, side * (H.lotFront + H.lotD)
			box(f, "Lot" .. idx, lx, lx + H.lotW, 0, 0.5, math.min(zFront, zBack), math.max(zFront, zBack), colors[idx], { transparency = 0.4 })
			local gx = lx + H.lotW / 2
			box(f, "Gatehouse", gx - 11, gx - 5, 0, 16, side * H.lotFront - 3, side * H.lotFront + 3, stoneLight)
			box(f, "Gatehouse", gx + 5, gx + 11, 0, 16, side * H.lotFront - 3, side * H.lotFront + 3, stoneLight)
			local top = box(f, "Gatehouse", gx - 11, gx + 11, 16, 21, side * H.lotFront - 3.5, side * H.lotFront + 3.5, colors[idx])
			label(top, side < 0 and Enum.NormalId.Back or Enum.NormalId.Front, "PLOT " .. idx)
		end
	end
	-- fortress walls and towers
	box(f, "WallN", H.x0, H.x1 - 30, 0, H.wallH, H.halfZ - H.wallT, H.halfZ, stone)
	box(f, "WallS", H.x0, H.x1 - 30, 0, H.wallH, -H.halfZ, -H.halfZ + H.wallT, stone)
	box(f, "WallW", H.x0 - H.wallT, H.x0, 0, H.wallH, -H.halfZ, H.halfZ, stone)
	for _, tx in H.towersX do
		for _, side in { -1, 1 } do
			local zc = side * (H.halfZ - H.wallT / 2)
			box(f, "Tower", tx - H.towerW / 2, tx + H.towerW / 2, 0, H.towerH, zc - H.towerW / 2, zc + H.towerW / 2, stoneLight)
			box(f, "TowerRoof", tx - H.towerW / 2 - 2, tx + H.towerW / 2 + 2, H.towerH, H.towerH + 4, zc - H.towerW / 2 - 2, zc + H.towerW / 2 + 2, hex("8A3B2E"))
		end
	end
	for _, zc in { -70, 70 } do
		box(f, "Tower", H.x0 - H.wallT - 8, H.x0 + 8, 0, H.towerH, zc - 12, zc + 12, stoneLight)
	end
	-- the Grand Gate on the safe line: twin towers, a lintel with "THE WILDLANDS", portcullis slot
	local G = H.gate
	local gx0, gx1 = G.x - G.depth / 2, G.x + G.depth / 2
	for _, side in { -1, 1 } do
		box(f, "GateTower", gx0, gx1, 0, G.h, side > 0 and G.towerZ[1] or -G.towerZ[2], side > 0 and G.towerZ[2] or -G.towerZ[1], stoneLight)
		-- walls joining the gate towers to the citadel walls and the canyon cliffs
		box(f, "GateWall", gx0 - 30, gx0 + 2, 0, H.wallH, side > 0 and G.towerZ[2] or -H.halfZ, side > 0 and H.halfZ or -G.towerZ[2], stone)
	end
	local lintel = box(f, "GateLintel", gx0, gx1, 52, G.h, -G.towerZ[1], G.towerZ[1], stoneLight)
	label(lintel, Enum.NormalId.Left, "THE WILDLANDS", hex("F6D27A"))
	box(f, "Portcullis", G.x - 1, G.x + 1, 44, 52, -L.GateOpenHalf, L.GateOpenHalf, hex("3A3A42"))
	box(f, "SafeLine", G.x - 2, G.x + 2, 0, 0.4, -L.GateOpenHalf, L.GateOpenHalf, hex("E0AD35"))
end

------------------------------------------------------------------------------- landmarks (placeholders at true scale)
local landmarks = {}

function landmarks.Skull(f, b, lm)
	local cx = b.x0 + lm.at * b.Length
	local s = lm.side or 1
	box(f, "Skull", cx - 26, cx + 26, 12, 70, s * 52, s * 110, AMBER)
	box(f, "Jaw", cx - 22, cx + 22, 2, 12, s * 56, s * 106, AMBER)
	for _, dx in { -12, 12 } do
		box(f, "Eye", cx + dx - 5, cx + dx + 5, 42, 54, s * 50, s * 52, hex("262826"))
	end
	box(f, "Waterfall", cx - 16, cx - 9, 0, 46, s * 47, s * 50, hex("9FDCFF"), { transparency = 0.25 })
end

function landmarks.Volcano(f, b, lm)
	local cx = b.x0 + lm.at * b.Length
	cone(f, "Volcano", cx, -290, 0, 400, 80, 320, 10, AMBER, hex("FF6A1A"))
end

function landmarks.Glacier(f, b, lm)
	local cx = b.x0 + lm.at * b.Length
	local s = lm.side or 1
	box(f, "FrozenKaiju", cx - 40, cx + 30, 6, 96, s * 72, s * 112, hex("24395A"))
	box(f, "Glacier", cx - 70, cx + 70, 0, 120, s * 52, s * 150, hex("BFE7FF"), { transparency = 0.45 })
end

function landmarks.Mushrooms(f, b)
	local spots = { { 0.18, -50, 72 }, { 0.33, 56, 98 }, { 0.5, 84, 116 }, { 0.62, -84, 104 }, { 0.8, 52, 80 } }
	for _, sp in spots do
		local x, z, h = b.x0 + sp[1] * b.Length, sp[2], sp[3]
		cylinder(f, "Stalk", x, z, 0, h, 4, hex("EFE3C8"))
		cylinder(f, "Cap", x, z, h, 10, 24 + h * 0.08, AMBER)
	end
	-- the ruined temple courtyard round the nest: a low stepped wall with a gap facing the bases
	for k = 0, 11 do
		local a = math.rad(k * 30)
		if math.abs(math.cos(a) + 1) > 0.15 then
			part(f, "TempleWall", Vector3.new(10, 10, 4), CFrame.new(b.nestX + math.cos(a) * 24, OY + 5, math.sin(a) * 24) * CFrame.Angles(0, -a + math.pi / 2, 0), hex("8C8A6A"))
		end
	end
	-- vine bridges overhead
	box(f, "VineBridge", b.x0 + 0.28 * b.Length - 2, b.x0 + 0.28 * b.Length + 2, 52, 54, -95, 95, hex("2F6B2A"))
	box(f, "VineBridge", b.x0 + 0.72 * b.Length - 2, b.x0 + 0.72 * b.Length + 2, 64, 66, -95, 95, hex("2F6B2A"))
end

function landmarks.WhaleRibs(f, b, lm)
	local x0 = b.x0 + (lm.at - 0.12) * b.Length
	for k = 0, 6 do
		local x = x0 + k * 13
		for _, side in { -1, 1 } do
			box(f, "Rib", x - 2.5, x + 2.5, 0, 40, side > 0 and 52 or -58, side > 0 and 58 or -52, AMBER)
			box(f, "Rib", x - 2.5, x + 2.5, 40, 56, side > 0 and 36 or -54, side > 0 and 54 or -36, AMBER)
			box(f, "Rib", x - 2.5, x + 2.5, 56, 66, side > 0 and 14 or -38, side > 0 and 38 or -14, AMBER)
		end
		box(f, "Rib", x - 2.5, x + 2.5, 64, 70, -16, 16, AMBER)
	end
	box(f, "Spine", x0 - 6, x0 + 6 * 13 + 6, 70, 76, -4, 4, AMBER)
	box(f, "WhaleSkull", x0 - 40, x0 - 6, 0, 36, -80, -52, AMBER)
	-- the shipwreck on the north edge
	local sx = b.x0 + 0.78 * b.Length
	box(f, "Wreck", sx - 32, sx + 32, 0, 18, 50, 78, hex("6B4C36"))
	box(f, "Mast", sx - 1.5, sx + 1.5, 18, 90, 62, 65, hex("4A3526"))
end

function landmarks.Islands(f, b)
	local isl = { { 0.18, -30, 70, 40 }, { 0.36, 30, 110, 60 }, { 0.55, -20, 150, 80 }, { 0.72, 40, 95, 46 }, { 0.88, -36, 125, 54 } }
	for _, it in isl do
		local x, z, y, w = b.x0 + it[1] * b.Length, it[2], it[3], it[4]
		box(f, "Island", x - w / 2, x + w / 2, y, y + 8, z - w * 0.35, z + w * 0.35, AMBER)
		box(f, "IslandRoot", x - w * 0.3, x + w * 0.3, y - 14, y, z - w * 0.22, z + w * 0.22, hex("5A6375"))
	end
	for k = 0, 5 do
		local x = b.x0 + (0.1 + k * 0.16) * b.Length
		local z = (k % 2 == 0) and -80 or 80
		box(f, "LightningRod", x - 2, x + 2, 0, 100, z - 2, z + 2, hex("2B303A"))
		box(f, "RodTip", x - 3, x + 3, 100, 106, z - 3, z + 3, hex("FFE14A"), { material = Enum.Material.Neon })
	end
end

function landmarks.VoidGate(f, b)
	local x = b.x1 - 30
	local R, cy = 78, 92
	for k = 0, 31 do
		local a = k / 32 * math.pi * 2
		local y, z = cy + math.sin(a) * R, math.cos(a) * R
		if y > 2 then
			box(f, "VoidRing", x - 5, x + 5, y - 7, y + 7, z - 7, z + 7, k % 2 == 0 and hex("B45CFF") or hex("FF5CC8"), { material = Enum.Material.Neon })
		end
	end
	cylinder(f, "Planet", b.x0 + 120, 260, 260, 80, 60, hex("6A4BD0"))
	for k = 0, 9 do
		local sx = b.x0 + 30 + k * 26
		local sz = (k % 2 == 0) and -40 or 44
		box(f, "Shard", sx - 2, sx + 2, 20 + (k % 3) * 30, 34 + (k % 3) * 30, sz - 2, sz + 2, hex("FF5CC8"), { material = Enum.Material.Neon })
	end
end

------------------------------------------------------------------------------- the canyon
local function buildBiome(root, L, b)
	local f = folder(root, b.Id)
	local floor = GRAY:Lerp(b.GroundA, 0.45)
	box(f, "Floor", b.x0, b.x1, -1, 0, -L.LaneHalf, L.LaneHalf, floor)
	box(f, "Trail", b.x0, b.x1, 0, 0.2, -L.PathHalf, L.PathHalf, floor:Lerp(Color3.new(1, 1, 1), 0.25))
	-- three cliff tiers on each side, in blocky segments
	for _, side in { -1, 1 } do
		for x = b.x0, b.x1 - 0.01, L.Segment do
			local x1 = math.min(x + L.Segment, b.x1)
			for tier, t in L.Tiers do
				local h = math.floor(L.CliffHeight(tier, x, side, b.Order) * L.WindowFactor(b, x + L.Segment / 2, side, tier) / 2 + 0.5) * 2
				local c = GRAY:Lerp(b.Wall, 0.55 - tier * 0.1):Lerp(Color3.new(0, 0, 0), (tier - 1) * 0.08)
				local z0, z1 = side * t.z0, side * t.z1
				box(f, "Tier" .. tier, x, x1, 0, h, math.min(z0, z1), math.max(z0, z1), c)
				if tier < 3 then
					box(f, "Cap", x, x1, h, h + 2, math.min(z0, z1), math.max(z0, z1), b.WallCap)
				end
			end
		end
	end
	-- nest
	cylinder(f, "Nest", b.nestX, 0, 0, 2, 9, hex("F2E7CF"))
	box(f, "GuardianBed", b.nestX + 10, b.nestX + 18, 0, 1.5, -4, 4, hex("2B2B33"))
	-- entrance gate (the Grand Gate is the first biome's)
	if b.Order > 1 then
		local gh = b.layout.gateH
		local gc = GRAY:Lerp(b.Accent or b.Border, 0.55)
		for _, side in { -1, 1 } do
			box(f, "GatePillar", b.x0 - 8, b.x0 + 8, 0, gh, side > 0 and L.GateOpenHalf or -78, side > 0 and 78 or -L.GateOpenHalf, gc)
		end
		local lintel = box(f, "GateLintel", b.x0 - 8, b.x0 + 8, gh - 14, gh, -L.GateOpenHalf, L.GateOpenHalf, gc)
		local speed = ({ PebblePlains = "ANY SPEED", LavaLagoon = "25K SPEED", FrostfangPeaks = "150K SPEED", VenomJungle = "1M SPEED", SunkenAbyss = "6M SPEED", StormSpires = "40M SPEED", CosmicRift = "250M SPEED" })[b.Id] or ""
		label(lintel, Enum.NormalId.Left, string.upper(b.DisplayName) .. "  \u{2022}  " .. speed)
		if b.Locked then
			local bar = box(f, "ComingSoon", b.x0 + 8, b.x0 + 10, 0, gh - 14, -L.GateOpenHalf, L.GateOpenHalf, hex("FF4D4D"), { transparency = 0.55 })
			label(bar, Enum.NormalId.Left, "COMING SOON")
		end
	end
	local lm = b.layout.landmark
	if lm and landmarks[lm.kind] then
		landmarks[lm.kind](folder(f, "Landmark"), b, lm)
	end
end

------------------------------------------------------------------------------- entry points
function W.ClearBlockout()
	local old = workspace:FindFirstChild("WorldBlockout")
	if old then
		old:Destroy()
	end
end

function W.Blockout(originY)
	W.ClearBlockout()
	OY = originY or 3000
	local L = fresh(ServerStorage.Tools.WorldLayout)
	local root = Instance.new("Model")
	root.Name = "WorldBlockout"
	root:SetAttribute("OriginY", OY)
	buildHub(root, L)
	local biomes = L.Biomes()
	for _, b in biomes do
		buildBiome(root, L, b)
	end
	-- the end of the world: a towering crystal wall behind the Void Gate
	local endX = biomes[#biomes].x1
	box(root, "WorldEnd", endX, endX + 12, 0, 200, -330, 330, hex("2A1F45"))
	root.Parent = workspace
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return string.format("WorldBlockout: %d parts, x %d..%d, at y %d", n, L.Hub.x0, endX, OY)
end

return W
