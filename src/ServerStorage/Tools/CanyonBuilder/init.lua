-- Edit-time builder for the canyon (Map.Lane, everything past the safe line), in each biome's own studded-voxel look:
-- the same SmoothPlastic + stud texture, and the colours of its old walls (Dirt / Band / Cap). It reworks a biome's lane
-- model IN PLACE and keeps every contract scripts use (Zone with BiomeId, NestSite + attachments, Sign, Floor tiles):
--   Widen    the floor grows from z +-55 to +-65 (same 12-stud checker, same two colours); decor that hugged the old
--            walls (|z| >= 46: wall rocks, vines, lava falls, icicles, back-row trees) moves out with them; Zone and
--            Border become 130 wide (GuardianService / DayNightService read the lane width from the Zone)
--   Cliffs   the old 44-tall walls are replaced by tiered cliffs: T1 is the old wall moved out (z 65..75, 44 tall, Band +
--            Cap, so the wall decor still lines up), then three stepped tiers behind it (to ~78, ~114, ~165 tall), blocky
--            heights per 24-stud segment, strata bands, caps; they dip at gates, drop for vista windows (WorldLayout)
--            and open into notches where a landmark is set into the cliff (an invisible wall keeps the lane closed)
--   Gate     the biome's entrance gate in its own style (Lava: Obsidian Maw, Frost: Frozen Fangs); Pebble Plains' gate
--            is the Citadel's Grand Gate
--   Landmark Pebble Plains: Titan's Skull with a waterfall from its eye; Lava Lagoon: an erupting volcano through a
--            vista window; Frostfang Peaks: a kaiju frozen in a glacier
--   Dress    more of the biome's own props: clones of its decor along the widened margins and up on the cliff tops
--   EndCap   closes the canyon after the last open biome (step 4 replaces it with the next biome's gate)
--   local B = require(game.ServerStorage.Tools.CanyonBuilder:Clone())
--   B.Build({ "PebblePlains" })                         every section for that biome
--   B.Build({ "LavaLagoon" }, { "Cliffs", "Gate" })      just those sections
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function fresh(module)
	local copy = module:Clone()
	local result = require(copy)
	copy:Destroy()
	return result
end

local K = require(ServerStorage.Tools.CitadelBuilder.Kit)
local P = K.P
local hex = Color3.fromHex

local B = {}

B.HALF = 65 -- lane half-width (was 55)
local OLD = 55
local SHIFT = B.HALF - OLD
local T1Z, T1H = 10, 44 -- the first tier: the old wall, moved out
local TIERS = {
	{ z0 = 75, z1 = 115, h = { 56, 82 }, seg = 12 },
	{ z0 = 115, z1 = 175, h = { 84, 124 }, seg = 16 },
	{ z0 = 175, z1 = 300, h = { 120, 175 }, seg = 30, far = true },
}
local WINDOW_SCALE = { 0.4, 0.3, 0.22 }

local DEFAULT = {
	PebblePlains = { dirt = hex("C98A4B"), band = hex("A06E3C"), cap = hex("4FC22A") },
	LavaLagoon = { dirt = hex("6E4A3C"), band = hex("583B30"), cap = hex("2E2220") },
	FrostfangPeaks = { dirt = hex("A3C6E6"), band = hex("829EB8"), cap = hex("FFFFFF") },
}

-- where a landmark is set into the cliff: no T1 / T2 there, an invisible wall instead
local NOTCHES = {
	PebblePlains = { { side = 1, x0 = 357, x1 = 433, wall = 59 } }, -- wall: just in front of the skull's snout
	FrostfangPeaks = { { side = 1, x0 = 729, x1 = 813 } },
}

-- props cloned from the biome's own decor: margin = along the widened edge, top = up on the cliffs (scale)
local DRESS = {
	PebblePlains = {
		margin = { "Bush", "BerryBush", "Boulder", "FlowersRed", "FlowersPink", "FlowersMixed", "Mushroom" },
		top = { { "Tree", 2.2 }, { "Tree", 2.6 }, { "Bush", 2.5 }, { "Boulder", 3 } },
	},
	LavaLagoon = {
		margin = { "LavaRock", "EmberPlant", "MagmaCrystal", "EmberPlant" },
		top = { { "ObsidianSpire", 2.4 }, { "CharredTree", 2.4 }, { "MagmaCrystal", 3 }, { "LavaRock", 3 } },
	},
	FrostfangPeaks = {
		margin = { "IceRock", "FrostBush", "SnowMound", "IceCrystal", "FrostBush" },
		top = { { "SnowPine", 2.4 }, { "SnowPine", 2.8 }, { "IceSpire", 2.4 }, { "IceCrystal", 3 } },
	},
}

------------------------------------------------------------------------------- the biomes
local function biomes()
	local L = fresh(ServerStorage.Tools.WorldLayout)
	local BiomeConfig = fresh(ReplicatedStorage.Shared.Config.BiomeConfig)
	local lane = workspace.Map.Lane
	local out = {}
	for _, cfg in BiomeConfig.All do
		local model = lane:FindFirstChild(cfg.Id)
		local zone = model and model:FindFirstChild("Zone")
		if zone then
			local e = table.clone(cfg)
			e.model = model
			e.x0 = zone.Position.X - zone.Size.X / 2
			e.x1 = zone.Position.X + zone.Size.X / 2
			e.layout = L.Biome[cfg.Id] or {}
			local nest = model:FindFirstChild("NestSite")
			e.nestX = nest and nest:GetPivot().X or (e.x0 + e.x1) / 2
			table.insert(out, e)
		end
	end
	table.sort(out, function(a, b)
		return a.x0 < b.x0
	end)
	for i, e in out do
		e.index = i
		e.prev, e.next = out[i - 1], out[i + 1]
		-- the first biome starts inside the Citadel's Grand Gate tunnel (x 290..350): its edges start after it
		local gate = workspace.Map:FindFirstChild("Citadel") and workspace.Map.Citadel:FindFirstChild("GrandGate")
		e.xs = (i == 1 and gate) and 350 or e.x0
	end
	return out
end

local function palette(b)
	local p = table.clone(DEFAULT[b.Id] or DEFAULT.PebblePlains)
	local model = b.model
	for _, k in { "dirt", "band", "cap" } do
		local v = model:GetAttribute("Palette_" .. k)
		if typeof(v) == "Color3" then
			p[k] = v
		end
	end
	local w = model:FindFirstChild("WallN")
	if w then
		for name, k in { Dirt = "dirt", Band = "band", Cap = "cap" } do
			local part = w:FindFirstChild(name)
			if part then
				p[k] = part.Color
			end
		end
	end
	for k, v in p do
		model:SetAttribute("Palette_" .. k, v)
	end
	p.deep = p.dirt:Lerp(p.band, 0.5)
	return p
end

local function inNotch(b, side, x0, x1)
	for _, n in NOTCHES[b.Id] or {} do
		if n.side == side and x1 > n.x0 and x0 < n.x1 then
			return n
		end
	end
	return nil
end

-- [a, b] minus the notches on that side
local function spans(b, side, a, z)
	local cuts = {}
	for _, n in NOTCHES[b.Id] or {} do
		if n.side == side then
			table.insert(cuts, n)
		end
	end
	table.sort(cuts, function(p, q)
		return p.x0 < q.x0
	end)
	local out, cur = {}, a
	for _, n in cuts do
		if n.x0 > cur then
			table.insert(out, { cur, math.min(n.x0, z) })
		end
		cur = math.max(cur, n.x1)
	end
	if cur < z then
		table.insert(out, { cur, z })
	end
	return out
end

------------------------------------------------------------------------------- widen
function B.Widen(b)
	local model = b.model
	if model:GetAttribute("Widened") then
		return "already widened"
	end
	local floor = model:FindFirstChild("Floor")
	-- 1) the floor: one new row of tiles on each side, the opposite colour of the tile next to it
	local colsN, colsS = {}, {}
	local template
	for _, t in floor:GetDescendants() do
		if t:IsA("BasePart") then
			template = template or t
			local top = t.Position.Z + t.Size.Z / 2
			local bottom = t.Position.Z - t.Size.Z / 2
			if math.abs(top - OLD) < 0.01 then
				table.insert(colsN, t)
			elseif math.abs(bottom + OLD) < 0.01 then
				table.insert(colsS, t)
			end
		end
	end
	local colours = {}
	for _, t in floor:GetDescendants() do
		if t:IsA("BasePart") then
			colours[t.Color:ToHex()] = t.Color
		end
	end
	local pair = {}
	for _, c in colours do
		table.insert(pair, c)
	end
	local function other(c)
		for _, q in pair do
			if q:ToHex() ~= c:ToHex() then
				return q
			end
		end
		return c
	end
	local added = 0
	for s, cols in { [1] = colsN, [-1] = colsS } do
		for _, t in cols do
			local x0, x1 = t.Position.X - t.Size.X / 2, t.Position.X + t.Size.X / 2
			if x1 > b.xs + 0.01 then
				x0 = math.max(x0, b.xs)
				local n = t:Clone()
				n.Size = Vector3.new(x1 - x0, t.Size.Y, SHIFT)
				n.CFrame = CFrame.new((x0 + x1) / 2, t.Position.Y, s * (OLD + SHIFT / 2))
				n.Color = other(t.Color)
				n:SetAttribute("Widened", true)
				n.Parent = t.Parent
				added += 1
			end
		end
	end
	-- 2) decor that hugged the old walls moves out with them
	local moved = 0
	local decor = model:FindFirstChild("Decor")
	for _, d in decor and decor:GetChildren() or {} do
		local cf
		if d:IsA("Model") then
			cf = d:GetPivot()
		elseif d:IsA("BasePart") then
			cf = d.CFrame
		end
		if cf then
			local bbCf = d:IsA("Model") and d:GetBoundingBox() or cf
			if math.abs(bbCf.Z) >= 46 and bbCf.X >= b.xs then
				local s = bbCf.Z > 0 and 1 or -1
				if d:IsA("Model") then
					d:PivotTo(cf + Vector3.new(0, 0, s * SHIFT))
				else
					d.CFrame = cf + Vector3.new(0, 0, s * SHIFT)
				end
				moved += 1
			end
		end
	end
	-- 3) the zone and the border strip are as wide as the lane
	local zone = model:FindFirstChild("Zone")
	zone.Size = Vector3.new(zone.Size.X, zone.Size.Y, B.HALF * 2)
	local border = model:FindFirstChild("Border")
	if border then
		border.Size = Vector3.new(border.Size.X, border.Size.Y, B.HALF * 2)
	end
	model:SetAttribute("Widened", true)
	return string.format("%d floor tiles added, %d decor moved out", added, moved)
end

------------------------------------------------------------------------------- cliffs
local function tierHeight(b, tier, x, side)
	local t = TIERS[tier]
	local n = math.noise(x / 60 + (b.index or 1) * 0.37, side * 3.1 + tier * 7.7, 0.5) + math.noise(x / 17 + tier * 1.3, side * 5.3 + (b.index or 1), 0.5) * 0.45
	local k = math.clamp(n * 1.4 + 0.5, 0, 1)
	local h = t.h[1] + (t.h[2] - t.h[1]) * k
	-- a vista window towards a landmark behind the cliffs
	local w = b.layout.window
	if w and w.side == side then
		local d = math.abs(x - (b.x0 + w.at * (b.x1 - b.x0)))
		if d < w.half then
			local edge = math.clamp((w.half - d) / 18, 0, 1)
			h = h * (1 - (1 - WINDOW_SCALE[tier]) * edge)
		end
	end
	-- the cliffs dip where a gate stands, so it shows against the sky
	for _, gx in { b.x0, b.x1 } do
		if math.abs(x - gx) < 26 then
			h = math.min(h, tier == 1 and 52 or (tier == 2 and 74 or h))
		end
	end
	return math.max(T1H + 4, math.floor(h / 2 + 0.5) * 2)
end

-- the height of the tier block a point x stands on (the same segments B.Cliffs builds)
local function segHeight(b, tier, x, side)
	local t = TIERS[tier]
	local s0 = tier == 1 and b.xs or b.x0
	while s0 < b.x1 - 0.01 do
		local s1 = math.min(s0 + t.seg, b.x1)
		if b.x1 - s1 < 8 then
			s1 = b.x1
		end
		if x < s1 then
			return tierHeight(b, tier, (s0 + s1) / 2, side)
		end
		s0 = s1
	end
	return tierHeight(b, tier, x, side)
end

local function cliffBlock(m, name, x0, x1, h, z0, z1, side, pal, o)
	o = o or {}
	local body = o.color or pal.dirt
	local y0 = o.y0 or 0
	local opt = { studs = o.far and { K.N.Front, K.N.Back } or K.SIDES, solid = o.solid, shadow = o.far and false or nil }
	K.box(m, name, x0, x1, y0, h, side * z0, side * z1, body, opt)
	K.box(m, name .. "Cap", x0 - 0.5, x1 + 0.5, h, h + 2, side * (z0 - 1), side * (z1 + 0.5), pal.cap, { studs = o.far and K.TOP or K.ALL, solid = o.solid, shadow = o.far and false or nil })
end

function B.Cliffs(b)
	local model = b.model
	local pal = palette(b)
	for _, n in { "WallN", "WallS", "Cliffs" } do
		local old = model:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local m = K.model(model, "Cliffs")
	local rng = Random.new(b.index * 97)
	local H = B.HALF
	for _, s in { -1, 1 } do
		-- T1: the old wall at the new edge (Dirt, Band, Cap, studs as before); collides
		for _, sp in spans(b, s, b.xs, b.x1) do
			K.box(m, "Dirt", sp[1], sp[2], 0, T1H, s * H, s * (H + T1Z), pal.dirt, { studs = K.SIDES })
			K.box(m, "Band", sp[1] - 0.1, sp[2] + 0.1, 0, 2, s * (H - 0.1), s * (H + T1Z + 0.1), pal.band)
			K.box(m, "Cap", sp[1] - 1, sp[2] + 1, T1H, T1H + 2, s * (H - 1), s * (H + T1Z + 1), pal.cap, { studs = K.ALL })
		end
		-- T2..T4: stepped tiers, blocky heights, strata, a jagged front
		for tier, t in TIERS do
			local xa = tier == 1 and b.xs or b.x0
			local x = xa
			while x < b.x1 - 0.01 do
				local x1 = math.min(x + t.seg, b.x1)
				if b.x1 - x1 < 8 then
					x1 = b.x1
				end
				if not (tier == 1 and inNotch(b, s, x, x1)) then
					local h = tierHeight(b, tier, (x + x1) / 2, s)
					local jag = (tier < 3) and rng:NextInteger(0, 2) * 2 or 0
					local z0 = t.z0 + jag
					local tone = t.far and pal.deep or pal.dirt:Lerp(pal.band, (tier - 1) * 0.18)
					cliffBlock(m, "Tier" .. (tier + 1), x, x1, h, z0, t.z1, s, pal, { color = tone, solid = false, far = t.far, y0 = t.far and -40 or 0 })
					-- now and then a rock pillar standing up out of the tier's front edge
					if tier == 2 and rng:NextNumber() < 0.22 then
						local px = rng:NextNumber(x + 2, math.max(x + 2.1, x1 - 8))
						local ph = h + rng:NextInteger(8, 20) * 2
						local pw = rng:NextInteger(3, 5) * 2
						cliffBlock(m, "Pillar", px, px + pw, ph, z0 + 2, z0 + 2 + pw, s, pal, { color = pal.dirt, solid = false, y0 = h - 2 })
						K.box(m, "PillarBand", px - 0.1, px + pw + 0.1, ph - 8, ph - 6, s * (z0 + 1.9), s * (z0 + 2.1 + pw), pal.band, { solid = false })
					end
					if not t.far then
						-- a strata band across the front, and now and then a proud ledge stone
						local sy = math.floor(h * rng:NextNumber(0.35, 0.6))
						K.box(m, "Strata", x, x1, sy, sy + 2, s * (z0 - 0.4), s * (z0 + 2), pal.band, { solid = false })
						if rng:NextNumber() < 0.45 then
							local lx = rng:NextNumber(x + 3, math.max(x + 3.1, x1 - 9))
							local ly = math.floor(h * rng:NextNumber(0.55, 0.8))
							K.box(m, "Ledge", lx, lx + 6, ly, ly + 3, s * (z0 - 2.5), s * (z0 + 1), pal.dirt, { studs = K.ALL, solid = false })
							K.box(m, "LedgeCap", lx - 0.3, lx + 6.3, ly + 3, ly + 3.8, s * (z0 - 2.8), s * (z0 + 1), pal.cap, { studs = K.TOP, solid = false })
						end
					end
				end
				x = x1
			end
		end
		-- invisible walls close the lane where a landmark notch opens the cliff
		for _, n in NOTCHES[b.Id] or {} do
			if n.side == s then
				local wz = n.wall or H
				local w = K.box(m, "InvisibleWall", n.x0, n.x1, 0, 90, s * wz, s * (wz + 2), pal.dirt, { transparency = 1 })
				w.CanQuery = false
				w.CastShadow = false
				for _, tx in w:GetChildren() do
					tx:Destroy()
				end
			end
		end
	end
	return m
end

------------------------------------------------------------------------------- plaques
-- a Kit plaque recoloured to the biome's style
local function plaque(parent, cf, w, h, text, style)
	local s = K.sign(parent, "GatePlaque", cf, w, h, text)
	for _, d in s:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Board" then
				d.Color = style.board
			elseif d.Name == "Frame" then
				d.Color = style.frame
			elseif d.Name == "GoldLine" or d.Name == "Stud" then
				d.Color = style.line
				if style.neon then
					d.Material = Enum.Material.Neon
				end
			end
		elseif d:IsA("TextLabel") then
			d.TextColor3 = style.text
		end
	end
	return s
end

-- a chain of tapering blocks through points (a fang, a horn, a tusk)
local function chain(m, name, pts, widths, colors, o)
	for i = 1, #pts - 1 do
		local a, c = pts[i], pts[i + 1]
		local d = c - a
		local w = widths[i]
		local mid = (a + c) / 2
		K.part(m, name, Vector3.new(w, d.Magnitude + w * 0.5, w), CFrame.lookAt(mid, mid + d) * CFrame.Angles(math.rad(90), 0, 0), colors[(i - 1) % #colors + 1], o or { studs = K.SIDES, solid = false })
	end
end

local function light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = part
	return l
end

------------------------------------------------------------------------------- gates
local GATES = {}

-- Lava Lagoon: the Obsidian Maw - a lava kaiju's jaws in obsidian: lower fangs either side, the upper jaw across the
-- lane with hanging teeth, glowing eyes and magma veins
function GATES.LavaLagoon(f, b, pal, rng)
	local m = K.model(f, "ObsidianMaw")
	local gx = b.x0
	local OB, OB2, OB3 = hex("231C22"), hex("2F2530"), hex("43363F")
	local MAG, MAG2 = hex("FF6A1A"), hex("FFB347")
	for _, s in { -1, 1 } do
		local steps = { { 0, 36, 65, 96, 24 }, { 36, 62, 64, 88, 19 }, { 62, 82, 62, 80, 14 }, { 82, 94, 61, 72, 9 } } -- clear of the lane (|z| < 65) below head height
		for i, st in steps do
			K.box(m, "LowerFang", gx - st[5] / 2, gx + st[5] / 2, st[1], st[2], s * st[3], s * st[4], i % 2 == 1 and OB or OB2, { studs = K.ALL })
		end
		K.box(m, "FangTip", gx - 2.5, gx + 2.5, 94, 99, s * 62, s * 67, OB3, { studs = K.ALL, solid = false })
		-- magma veins zigzagging up the lane-facing side
		local vy, vx = 4, gx - 4
		for j = 1, 6 do
			local len = rng:NextNumber(9, 14)
			local zf = (vy < 36 and 64) or (vy < 62 and 63) or 62
			K.box(m, "MagmaVein", vx - 0.7, vx + 0.7, vy, vy + len, s * (zf - 0.3), s * (zf + 0.2), j % 2 == 0 and MAG2 or MAG, { neon = true, solid = false })
			vy += len - 1
			vx = math.clamp(vx + rng:NextNumber(-5, 5), gx - 6, gx + 6)
		end
		local ember = K.box(m, "Embers", gx - 6, gx + 6, 36, 37, s * 63.6, s * 65, MAG, { neon = true, solid = false })
		light(ember, MAG, 30, 1.4)
	end
	-- the upper jaw across the lane, its teeth hanging down on both faces
	K.box(m, "UpperJaw", gx - 13, gx + 13, 94, 110, -98, 98, OB, { studs = K.ALL })
	K.box(m, "JawRidge", gx - 11, gx + 11, 110, 118, -60, 60, OB2, { studs = K.ALL, solid = false })
	for _, xf in { gx - 12, gx + 12 } do
		for i, z in { -52, -38, -24, -10, 10, 24, 38, 52 } do
			local len = (i % 2 == 0) and 14 or 9
			K.box(m, "Tooth", xf - 1.8, xf + 1.8, 94 - len, 94, z - 1.8, z + 1.8, OB3, { studs = K.SIDES, solid = false })
			K.box(m, "ToothTip", xf - 0.9, xf + 0.9, 94 - len - 3, 94 - len, z - 0.9, z + 0.9, OB2, { solid = false })
			if len > 10 then
				K.box(m, "LavaDrip", xf - 0.5, xf + 0.5, 94 - len - 4.2, 94 - len - 3, z - 0.5, z + 0.5, MAG2, { neon = true, solid = false })
			end
		end
	end
	-- the maw's brow, burning eyes and swept-back horns, facing the way in
	K.box(m, "Brow", gx - 9, gx + 9, 118, 124, -34, 34, OB, { studs = K.ALL, solid = false })
	for _, s in { -1, 1 } do
		K.box(m, "Eye", gx - 11.3, gx - 10.9, 112, 115.5, s * 12, s * 26, MAG2, { neon = true, solid = false })
		K.box(m, "Eye", gx + 10.9, gx + 11.3, 112, 115.5, s * 12, s * 26, MAG2, { neon = true, solid = false })
		chain(m, "Horn", { Vector3.new(gx, 120, s * 30), Vector3.new(gx + 4, 132, s * 40), Vector3.new(gx + 9, 140, s * 52), Vector3.new(gx + 15, 144, s * 62) }, { 8, 6, 4 }, { OB2, OB, OB3 })
	end
	-- the roof of the mouth: dark, with thin magma seams glowing down at the lane
	for _, sz in { -36, -12, 12, 36 } do
		local seam = K.box(m, "JawSeam", gx - 9, gx + 9, 93.6, 94, sz - 0.8, sz + 0.8, MAG, { neon = true, solid = false })
		if sz == 12 then
			light(seam, MAG, 50, 1.6)
		end
	end
	plaque(m, CFrame.lookAt(Vector3.new(gx - 13.6, 102, 0), Vector3.new(gx - 30, 102, 0)), 64, 11, "LAVA LAGOON", { board = OB2, frame = OB3, line = MAG, text = MAG2, neon = true })
	return m
end

-- Frostfang Peaks: the Frozen Fangs - two huge ice tusks curving in over the lane from snowy pedestals, an ice
-- lintel between their tips hung with icicles, crystals on top
function GATES.FrostfangPeaks(f, b, pal, rng)
	local m = K.model(f, "FrozenFangs")
	local gx = b.x0
	local ICE, ICE2, SNOW, DEEP, GLOW = pal.dirt, hex("BFE6FF"), hex("FFFFFF"), pal.band, hex("8FD8FF")
	for _, s in { -1, 1 } do
		K.box(m, "Pedestal", gx - 14, gx + 14, 0, 22, s * 65, s * 98, DEEP, { studs = K.ALL })
		K.box(m, "PedestalSnow", gx - 15, gx + 15, 22, 25, s * 64.5, s * 99, SNOW, { studs = K.ALL })
		chain(m, "Fang", {
			Vector3.new(gx, 22, s * 86),
			Vector3.new(gx, 44, s * 84),
			Vector3.new(gx, 64, s * 79),
			Vector3.new(gx, 82, s * 72),
			Vector3.new(gx, 96, s * 63),
			Vector3.new(gx, 104, s * 54),
		}, { 16, 14, 12, 10, 7 }, { ICE2, ICE, ICE2, ICE, ICE2 }, { studs = K.SIDES })
		-- a smaller fang beside it, and frost crystals at the foot
		chain(m, "SmallFang", { Vector3.new(gx + 9, 22, s * 94), Vector3.new(gx + 10, 40, s * 90), Vector3.new(gx + 11, 54, s * 84), Vector3.new(gx + 11, 62, s * 77) }, { 7, 5.5, 4 }, { ICE, ICE2, SNOW })
		for k = 0, 2 do
			local cz = s * (70 + k * 8)
			local c = K.part(m, "Crystal", Vector3.new(2.2, 7 + k * 2, 2.2), CFrame.new(gx - 12, 27 + k, cz) * CFrame.Angles(0, 0, math.rad(15 - k * 12)), GLOW, { neon = true, solid = false })
			if k == 1 then
				light(c, GLOW, 22, 1.2)
			end
		end
	end
	K.box(m, "Lintel", gx - 11, gx + 11, 96, 110, -60, 60, ICE2, { studs = K.ALL, solid = false })
	K.box(m, "LintelSnow", gx - 12, gx + 12, 110, 113, -62, 62, SNOW, { studs = K.ALL, solid = false })
	for _, xf in { gx - 10.5, gx + 10.5 } do
		for i, z in { -54, -42, -30, -18, -6, 6, 18, 30, 42, 54 } do
			local len = (i % 3 == 0) and 12 or ((i % 2 == 0) and 8 or 5)
			K.box(m, "Icicle", xf - 1.2, xf + 1.2, 96 - len, 96, z - 1.2, z + 1.2, i % 2 == 0 and ICE or SNOW, { solid = false })
			K.box(m, "IcicleTip", xf - 0.5, xf + 0.5, 96 - len - 2.5, 96 - len, z - 0.5, z + 0.5, ICE2, { solid = false })
		end
	end
	for i, z in { -40, -20, 0, 20, 40 } do
		local c = K.part(m, "TopCrystal", Vector3.new(3, 9 + (i % 2) * 5, 3), CFrame.new(gx, 117 + (i % 2) * 2, z) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, math.rad(rng:NextNumber(-14, 14))), GLOW, { neon = true, solid = false })
		if i == 3 then
			light(c, GLOW, 40, 1.4)
		end
	end
	plaque(m, CFrame.lookAt(Vector3.new(gx - 11.6, 103, 0), Vector3.new(gx - 30, 103, 0)), 70, 10, "FROSTFANG PEAKS", { board = hex("1D3A5C"), frame = SNOW, line = GLOW, text = hex("E8F6FF"), neon = true })
	return m
end

function B.Gate(b)
	local model = b.model
	local old = model:FindFirstChild("Gate")
	if old then
		old:Destroy()
	end
	if not GATES[b.Id] then
		return "no gate (" .. b.Id .. ")"
	end
	local f = K.model(model, "Gate")
	GATES[b.Id](f, b, palette(b), Random.new(b.index * 31))
	return f
end

------------------------------------------------------------------------------- landmarks
local LAND = {}

-- Pebble Plains: Titan's Skull - a huge fossil kaiju skull set into the north cliff, moss on its crown, a waterfall
-- pouring from its eye over the snout into a pool at the edge of the lane
function LAND.PebblePlains(f, b, pal, rng)
	local m = K.model(f, "TitanSkull")
	local x = b.x0 + 0.62 * (b.x1 - b.x0)
	local FOSSIL = { Bone = hex("D8CCAE"), BoneShade = hex("BBAE8C"), BoneDark = hex("8C7F62"), Tooth = hex("EDE4CC") }
	-- the rock it is set into: a back mass and two banks framing it
	K.box(m, "Rock", 357, 433, 0, 50, 92, 118, pal.dirt, { studs = K.SIDES })
	K.box(m, "RockCap", 356.5, 433.5, 50, 52, 91, 118.5, pal.cap, { studs = K.ALL })
	for _, bx in { { 357, 371 }, { 419, 433 } } do
		K.box(m, "Bank", bx[1], bx[2], 0, 40, 65, 92, pal.dirt, { studs = K.SIDES })
		K.box(m, "BankCap", bx[1] - 0.5, bx[2] + 0.5, 40, 42, 64, 92, pal.cap, { studs = K.ALL })
		K.box(m, "BankBand", bx[1] - 0.1, bx[2] + 0.1, 0, 2, 64.9, 92, pal.band)
	end
	local sk = K.skull(m, CFrame.lookAt(Vector3.new(x, 40, 104), Vector3.new(x, 40, 0)), 1.4)
	local REMOVE = { Shield = true, ShieldRim = true, Bolt = true, Strap = true, HornRing = true }
	for _, d in sk:GetDescendants() do
		if d:IsA("BasePart") then
			if REMOVE[d.Name] then
				d:Destroy()
			elseif d.Name == "Ember" then
				d.Color = P.Socket
				d.Material = Enum.Material.SmoothPlastic
			elseif d.Color == P.Bone then
				d.Color = FOSSIL.Bone
			elseif d.Color == P.BoneShade then
				d.Color = FOSSIL.BoneShade
			elseif d.Color == P.BoneDark then
				d.Color = FOSSIL.BoneDark
			elseif d.Color == P.Tooth then
				d.Color = FOSSIL.Tooth
			end
		end
	end
	-- sit it on the ground
	local cf, size = sk:GetBoundingBox()
	sk:PivotTo(sk:GetPivot() + Vector3.new(0, 0.5 - (cf.Y - size.Y / 2), 0))
	-- moss on the crown and brow, vines hanging off the cheeks
	local cranium = sk:FindFirstChild("Cranium")
	if cranium then
		local top = cranium.Position.Y + cranium.Size.Y / 2
		for i = 1, 5 do
			local mx = cranium.Position.X + rng:NextNumber(-cranium.Size.X * 0.4, cranium.Size.X * 0.4)
			local mz = cranium.Position.Z + rng:NextNumber(-cranium.Size.Z * 0.4, cranium.Size.Z * 0.3)
			local w = rng:NextInteger(3, 6) * 2
			K.box(m, "Moss", mx - w / 2, mx + w / 2, top - 0.2, top + 1.2, mz - w / 3, mz + w / 3, i % 2 == 0 and P.Moss or P.MossDark, { studs = K.TOP, solid = false })
		end
	end
	for _, d in sk:GetChildren() do
		if d:IsA("BasePart") and d.Name == "CheekFlare" then
			local p0 = d.Position + Vector3.new(0, -d.Size.Y / 2, -d.Size.Z / 2 + 0.6)
			for j = 0, 3 do
				K.box(m, "Vine", p0.X - 0.5, p0.X + 0.5, p0.Y - 3 - j * 3, p0.Y - j * 3, p0.Z - 0.4, p0.Z + 0.4, P.Vine, { solid = false })
				K.box(m, "Leaf", p0.X - 1.2 + (j % 2) * 1.4, p0.X + (j % 2) * 1.4, p0.Y - 2 - j * 3, p0.Y - 0.8 - j * 3, p0.Z - 0.6, p0.Z + 0.2, P.Leaf, { solid = false })
			end
		end
	end
	-- the waterfall: out of the eye, over the snout, down into a pool
	local eye, muzzle
	for _, d in sk:GetChildren() do
		if d:IsA("BasePart") and d.Name == "EyeSocket" and (not eye or d.Position.X < eye.Position.X) then
			eye = d
		elseif d:IsA("BasePart") and d.Name == "Muzzle" then
			muzzle = d
		end
	end
	if eye and muzzle then
		local WATER, FOAM = hex("5BC4F0"), hex("EAF8FF")
		local wo = { transparency = 0.25, solid = false, shadow = false }
		local ex, ey, ez = eye.Position.X, eye.Position.Y - 1, eye.Position.Z - 0.6
		local mtop = muzzle.Position.Y + muzzle.Size.Y / 2
		local mfront = muzzle.Position.Z - muzzle.Size.Z / 2
		K.box(m, "Waterfall", ex - 2.4, ex + 2.4, mtop, ey, ez - 1.2, ez, WATER, wo)
		K.box(m, "Waterfall", ex - 2.4, ex + 2.4, mtop, mtop + 0.5, mfront, ez, WATER, wo)
		K.box(m, "Waterfall", ex - 2.8, ex + 2.8, 0, mtop + 0.5, mfront - 1.6, mfront, WATER, wo)
		K.box(m, "Foam", ex - 3.4, ex + 3.4, mtop - 0.2, mtop + 1, mfront - 2, mfront + 0.4, FOAM, { solid = false, shadow = false })
		K.box(m, "Pool", ex - 10, ex + 9, 0, 0.35, mfront - 12, mfront + 3, WATER, { transparency = 0.2, solid = false, shadow = false, studs = K.TOP })
		K.box(m, "Foam", ex - 4.5, ex + 4.5, 0.2, 0.9, mfront - 4, mfront - 0.2, FOAM, { solid = false, shadow = false })
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			local px, pz = ex - 0.5 + math.cos(a) * 11, mfront - 4.5 + math.sin(a) * 8
			K.box(m, "PoolStone", px - 1.6, px + 1.6, 0, 1.2, pz - 1.4, pz + 1.4, i % 2 == 0 and P.Mid or P.Light, { studs = K.ALL, solid = false })
		end
	end
	return m
end

-- Lava Lagoon: an erupting volcano on the southern skyline, framed by a vista window in the cliffs
function LAND.LavaLagoon(f, b, pal, rng)
	local m = K.model(f, "Volcano")
	local x = b.x0 + 0.6 * (b.x1 - b.x0)
	local zc = -300
	local STEPS, W0, W1, HT = 13, 330, 70, 300
	local ROCK = { hex("2A2124"), hex("3A2A28"), pal.cap, hex("4A3430") }
	local MAG, MAG2 = hex("FF6A1A"), hex("FFB347")
	local sh = HT / STEPS
	local tops = {}
	for i = 0, STEPS - 1 do
		local t = i / STEPS
		local w = W0 + (W1 - W0) * t
		local ox, oz = rng:NextNumber(-6, 6) * (1 - t), rng:NextNumber(-6, 6) * (1 - t)
		K.box(m, "Slope", x + ox - w / 2, x + ox + w / 2, i * sh - (i == 0 and 40 or 0), (i + 1) * sh, zc + oz - w / 2, zc + oz + w / 2, ROCK[i % #ROCK + 1], { studs = { K.N.Back, K.N.Left, K.N.Right, K.N.Top }, solid = false, shadow = false })
		tops[i] = { y = (i + 1) * sh, z = zc + oz + w / 2, w = w, x = x + ox }
	end
	-- two lava rivers cascading down the steps on the side facing the lane
	for r, start in { -14, 16 } do
		local rx = x + start
		for i = STEPS - 1, 0, -1 do
			local st = tops[i]
			rx = math.clamp(rx + rng:NextNumber(-7, 7) + (start > 0 and 1.5 or -1.5), st.x - st.w / 2 + 6, st.x + st.w / 2 - 6)
			local w = 6 + (STEPS - i) * 0.6
			K.box(m, "LavaRiver", rx - w / 2, rx + w / 2, st.y - sh, st.y + 0.2, st.z - 0.2, st.z + 0.6, (i + r) % 2 == 0 and MAG or MAG2, { neon = true, solid = false })
			if i < STEPS - 1 then
				local above = tops[i + 1]
				K.box(m, "LavaRiver", rx - w / 2, rx + w / 2, st.y - 0.1, st.y + 0.3, above.z - 0.4, st.z + 0.6, MAG, { neon = true, solid = false })
			end
		end
	end
	-- the crater: a glowing core, fire and smoke, a big warm light
	local top = tops[STEPS - 1]
	local core = K.box(m, "Crater", top.x - 24, top.x + 24, HT - 4, HT + 2, zc - 24, zc + 24, MAG, { neon = true, solid = false })
	K.box(m, "CraterRim", top.x - 37, top.x + 37, HT, HT + 6, zc + 26, zc + 36, ROCK[1], { studs = K.ALL, solid = false })
	K.box(m, "CraterRim", top.x - 37, top.x + 37, HT, HT + 8, zc - 36, zc - 26, ROCK[2], { studs = K.ALL, solid = false })
	light(core, MAG, 60, 3)
	local fire = Instance.new("Fire")
	fire.Size = 30
	fire.Heat = 25
	fire.Color = Color3.fromRGB(255, 120, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 60, 10)
	fire.Parent = core
	local smoke = Instance.new("Smoke")
	smoke.Size = 60
	smoke.RiseVelocity = 25
	smoke.Opacity = 0.18
	smoke.Color = Color3.fromRGB(70, 60, 60)
	smoke.Parent = core
	return m
end

-- Frostfang Peaks: a giant kaiju frozen in a glacier set into the north cliff
function LAND.FrostfangPeaks(f, b, pal, rng)
	local m = K.model(f, "FrozenKaiju")
	local x = b.x0 + 0.72 * (b.x1 - b.x0)
	local ICE, ICE2, SNOW, DEEP, GLOW = pal.dirt, hex("BFE6FF"), hex("FFFFFF"), pal.band, hex("8FD8FF")
	local X0, X1 = x - 42, x + 42
	K.box(m, "Pedestal", X0, X1, 0, 14, 65, 152, DEEP, { studs = K.ALL })
	K.box(m, "PedestalSnow", X0 - 0.5, X1 + 0.5, 14, 15, 64.5, 152, SNOW, { studs = K.TOP })
	for _, px in { { X0, X0 + 8 }, { X1 - 8, X1 } } do
		K.box(m, "IceColumn", px[1], px[2], 15, 112, 65, 152, ICE, { studs = K.ALL })
		K.box(m, "ColumnSnow", px[1] - 0.5, px[2] + 0.5, 112, 115, 64.5, 152, SNOW, { studs = K.ALL })
	end
	K.box(m, "BackIce", X0 + 8, X1 - 8, 15, 120, 100, 152, ICE, { studs = K.SIDES })
	K.box(m, "BackSnow", X0 + 7.5, X1 - 7.5, 120, 123, 99.5, 152, SNOW, { studs = K.ALL })
	-- the frozen kaiju: Icebreaker Rex, huge, its colours turned to deep ice blues, eyes still glowing
	local src = ServerStorage.Assets.Kaiju:FindFirstChild("IcebreakerRex")
	if src then
		local k = src:Clone()
		for a in k:GetAttributes() do
			k:SetAttribute(a, nil)
		end
		local root = k.PrimaryPart
		local DARK, LIGHT = hex("1C3354"), hex("6F97C4")
		for _, d in k:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
				if d == root then
					d.Transparency = 1
				elseif d.Material == Enum.Material.Neon then
					d.Color = d.Name:find("Eye") and GLOW or LIGHT
				else
					local c = d.Color
					d.Color = DARK:Lerp(LIGHT, math.clamp(0.299 * c.R + 0.587 * c.G + 0.114 * c.B, 0, 1))
				end
			elseif d:IsA("JointInstance") or d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") then
				d:Destroy()
			end
		end
		k:ScaleTo(k:GetScale() * 12)
		k:PivotTo(CFrame.lookAt(Vector3.new(x, 15, 112), Vector3.new(x, 15, 0)))
		local kcf, ks = k:GetBoundingBox()
		k:PivotTo(k:GetPivot() + Vector3.new(0, 15.2 - (kcf.Y - ks.Y / 2), 70 - (kcf.Z - ks.Z / 2)))
		k.Name = "FrozenIcebreaker"
		k.Parent = m
	end
	-- the clear ice in front, frost streaks over it, icicles off its top, crystals
	K.box(m, "ClearIce", X0 + 8, X1 - 8, 15, 100, 66, 100, ICE2, { transparency = 0.62, solid = false, shadow = false, studs = { K.N.Front } })
	K.box(m, "ClearIceSnow", X0 + 7.5, X1 - 7.5, 100, 103, 65.5, 100, SNOW, { studs = K.ALL, solid = false })
	for i = 1, 7 do
		local sx = rng:NextNumber(X0 + 12, X1 - 12)
		local sy = rng:NextNumber(24, 90)
		K.box(m, "FrostStreak", sx - rng:NextNumber(2, 6), sx + rng:NextNumber(2, 6), sy, sy + rng:NextNumber(1, 3), 65.6, 66, SNOW, { transparency = 0.45, solid = false, shadow = false })
	end
	for ix = X0 + 2, X1 - 2, 5 do
		local len = rng:NextInteger(3, 9)
		K.box(m, "Icicle", ix - 1, ix + 1, 100 - len, 100, 65.5, 67.5, ICE2, { solid = false })
	end
	for i = 0, 5 do
		local cx = X0 + 10 + i * 13
		local c = K.part(m, "Crystal", Vector3.new(3, 10 + (i % 2) * 6, 3), CFrame.new(cx, 108 + (i % 2) * 3, 82 + (i % 3) * 8) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), 0, math.rad(rng:NextNumber(-15, 15))), GLOW, { neon = true, solid = false })
		if i == 2 then
			light(c, GLOW, 40, 1.2)
		end
	end
	return m
end

function B.Landmark(b)
	local model = b.model
	local old = model:FindFirstChild("Landmark")
	if old then
		old:Destroy()
	end
	if not LAND[b.Id] then
		return "no landmark (" .. b.Id .. ")"
	end
	local f = K.model(model, "Landmark")
	LAND[b.Id](f, b, palette(b), Random.new(b.index * 53))
	return f
end

------------------------------------------------------------------------------- dress
local function cloneProp(src, scale, cf)
	local c = src:Clone()
	if scale and scale ~= 1 then
		c:ScaleTo(c:GetScale() * scale)
		for _, t in c:GetDescendants() do
			if t:IsA("Texture") then
				t.StudsPerTileU *= scale
				t.StudsPerTileV *= scale
			end
		end
	end
	c:PivotTo(cf)
	local bb, size = c:GetBoundingBox()
	c:PivotTo(c:GetPivot() + Vector3.new(0, cf.Y - (bb.Y - size.Y / 2), 0))
	return c
end

function B.Dress(b)
	local model = b.model
	local old = model:FindFirstChild("Dress")
	if old then
		old:Destroy()
	end
	local spec = DRESS[b.Id]
	if not spec then
		return "no dress (" .. b.Id .. ")"
	end
	local decor = model:FindFirstChild("Decor")
	local pool = {}
	for _, d in decor:GetChildren() do
		if d:IsA("Model") then
			pool[d.Name] = pool[d.Name] or {}
			table.insert(pool[d.Name], d)
		end
	end
	local f = Instance.new("Folder")
	f.Name = "Dress"
	local rng = Random.new(b.index * 211)
	local count = 0
	local function pick(name)
		local list = pool[name]
		return list and list[rng:NextInteger(1, #list)]
	end
	for _, s in { -1, 1 } do
		-- along the widened margin (the band the wall decor moved out of)
		local n = math.floor((b.x1 - b.xs) / 16)
		for i = 1, n do
			local x = b.xs + (i - 0.5) * (b.x1 - b.xs) / n + rng:NextNumber(-4, 4)
			local z = s * rng:NextNumber(44, 54)
			local near = math.abs(x - b.nestX) < 18 or inNotch(b, s, x - 14, x + 14) or math.abs(x - b.x0) < 16 or math.abs(x - b.x1) < 16
			local src = pick(spec.margin[rng:NextInteger(1, #spec.margin)])
			if src and not near then
				cloneProp(src, rng:NextNumber(1, 1.4), CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)).Parent = f
				count += 1
			end
		end
		-- up on the tiers
		for tier = 1, 3 do
			local t = TIERS[tier]
			local x = b.x0 + rng:NextNumber(4, 12)
			while x < b.x1 - 6 do
				local e = spec.top[rng:NextInteger(1, #spec.top)]
				local src = pick(e[1])
				local h = segHeight(b, tier, x, s)
				local z = s * rng:NextNumber(t.z0 + 6, math.min(t.z1 - 8, t.z0 + (tier == 3 and 40 or 30)))
				local win = b.layout.window and b.layout.window.side == s and math.abs(x - (b.x0 + b.layout.window.at * (b.x1 - b.x0))) < b.layout.window.half + 10
				if src and not win and not (tier == 1 and inNotch(b, s, x - 10, x + 10)) and x > (tier == 1 and b.xs or b.x0) + 4 then
					cloneProp(src, e[2] * (1 + (tier - 1) * 0.35), CFrame.new(x, h + 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)).Parent = f
					count += 1
				end
				x += tier == 3 and rng:NextNumber(26, 40) or rng:NextNumber(11, 19)
			end
		end
	end
	f.Parent = model
	return count .. " props"
end

------------------------------------------------------------------------------- the end of the open canyon
function B.EndCap(b)
	local lane = workspace.Map.Lane
	for _, n in { "EndWall", "EndCap" } do
		local old = lane:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local pal = palette(b)
	local m = K.model(lane, "EndCap")
	local x = b.x1
	K.box(m, "Dirt", x, x + 10, 0, T1H, -B.HALF - 11, B.HALF + 11, pal.dirt, { studs = K.SIDES })
	K.box(m, "Band", x - 0.1, x + 10.1, 0, 2, -B.HALF - 11, B.HALF + 11, pal.band)
	K.box(m, "Cap", x - 1, x + 11, T1H, T1H + 2, -B.HALF - 12, B.HALF + 12, pal.cap, { studs = K.ALL })
	cliffBlock(m, "Mass", x + 10, x + 60, 92, -175, 175, 1, pal, { solid = false })
	cliffBlock(m, "Mass", x + 60, x + 140, 150, -300, 300, 1, pal, { color = pal.deep, solid = false, far = true, y0 = -40 })
	return m
end

------------------------------------------------------------------------------- entry point
local ORDER = { "Widen", "Cliffs", "Gate", "Landmark", "Dress" }

function B.Build(ids, sections)
	local list = biomes()
	local report = {}
	K.reset()
	for _, b in list do
		if table.find(ids, b.Id) then
			for _, sec in ORDER do
				if not sections or table.find(sections, sec) then
					local ok, res = pcall(B[sec], b)
					table.insert(report, b.Id .. "." .. sec .. ": " .. (ok and (typeof(res) == "Instance" and "built" or tostring(res)) or ("ERROR " .. tostring(res))))
					task.wait()
				end
			end
			-- the canyon closes after the last open biome
			local BiomeConfig = fresh(ReplicatedStorage.Shared.Config.BiomeConfig)
			local open = BiomeConfig.List
			if open[#open] and open[#open].Id == b.Id and (not sections or table.find(sections, "EndCap")) then
				local ok, res = pcall(B.EndCap, b)
				table.insert(report, b.Id .. ".EndCap: " .. (ok and "built" or ("ERROR " .. tostring(res))))
			end
		end
	end
	table.insert(report, K.count() .. " parts made")
	return table.concat(report, "\n")
end

return B
