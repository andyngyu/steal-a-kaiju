-- Shared builder for the new biomes (CanyonBuilder.VenomJungle / SunkenAbyss / StormSpires / CosmicRift call it with
-- their theme). Same studded kit and layout grammar as the refined first three, so they belong to the same game:
--   ground in irregular patches (blending in from the previous biome at the border), a path with slabs that forks round
--   the nest, an optional sunk liquid (toxic pools, tide pools, puddles, void pools), layered strata cliffs with the
--   theme's own trim per column, ridges and far ranges, the theme's features, a themed nest (the NestSite contract is
--   untouched: only NestArt is rebuilt), the theme's gate, and - while the biome is Locked in BiomeConfig - a COMING SOON
--   field with an invisible wall in the gate (delete Gate.ComingSoon to open it).
-- th (theme): seed, half (zone half-width, <= 94), edgeN / edgeS ({x, distance} points), paths ({x, z, width} polylines),
--   rock (4 tones + accent), slabs (colours), slabChance, ground(ctx, x, z, n, n2) -> Color3, cap(ctx, x, rng) ->
--   Color3, tint(x, color)?, height(ctx, side, x, n) -> number (0 = open), ridge(ctx, side, x, n), farHeight(ctx, side,
--   x, n), ridgeFront(ctx, side, x)?, liquid = { gap(x, z) (< 0 inside), color(ctx, x, z, n), neon, transparency, top,
--   bed, overPath (the liquid runs across the path too: the theme bridges it) }, ridgeCap(ctx, x, rng)? (the ridges'
--   and far ranges' caps, when they differ from the cliffs'), init(ctx)?, column(ctx, col, side)?, rugged (ridges and far
--   ranges as T.massif crags instead of flat-topped slabs), farRock (a paler palette for the far ranges, so landmarks
--   stand out against them), lock(ctx, comingSoonModel, gx)? (the theme's own field, lock, signs and kaiju
--   silhouette; the invisible Barrier is always built here),
--   features(ctx), nest(ctx, art, centre), gate(ctx, gateModel), accent, gateOpenH
return function(b, K, T, th)
	local P = K.P
	local model = b.model
	local rng = Random.new(th.seed)
	local XA, XB = b.x0, b.x1
	local HALF = th.half or 90
	local report = {}
	local ctx = { b = b, K = K, T = T, P = P, rng = rng, XA = XA, XB = XB, HALF = HALF, report = report, th = th }

	---------------------------------------------------------------- layout helpers
	local edge = { [1] = T.edge(th.edgeN), [-1] = T.edge(th.edgeS) }
	ctx.edge = edge
	local function pathGap(x, z)
		local best = math.huge
		for _, p in th.paths do
			local d, half = T.polyDistance(p, x, z)
			best = math.min(best, d - half)
		end
		return best
	end
	ctx.pathGap = pathGap
	local nest = model:FindFirstChild("NestSite")
	local NEST = nest:GetPivot().Position
	ctx.NEST = NEST
	function ctx.nearNest(x, z, r)
		return (Vector3.new(x, 0, z) - Vector3.new(NEST.X, 0, NEST.Z)).Magnitude < r
	end
	ctx.liquidGap = th.liquid and th.liquid.gap or function()
		return math.huge
	end
	function ctx.isLiquid(x, z)
		return ctx.liquidGap(x, z) < 0 and (th.liquid.overPath or pathGap(x, z) > 0)
	end
	-- 1 right at the border with the previous biome, fading to 0 over blendLen studs
	function ctx.blend(x)
		return math.clamp(1 - (x - XA) / (th.blendLen or 26), 0, 1)
	end
	function ctx.inside(x, z, margin)
		local side = z >= 0 and 1 or -1
		return math.abs(z) < edge[side](x) - (margin or 0)
	end
	function ctx.rockAt(pos, t)
		local c = T.tone(th.rock, pos, 0.2 + t * 0.6, rng)
		return th.tint and th.tint(pos.X, c) or c
	end
	function ctx.light(part, color, range, brightness)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness or 1.5
		l.Shadows = false
		l.Parent = part
		return l
	end
	-- a ParticleEmitter (default sparkle texture). o: colors {c0, c1}, size {s0, s1}, rate, speed {a, b}, life {a, b},
	-- spread, accel (Vector3), light (emission), dir (NormalId), transparency {t0, t1}
	function ctx.emit(part, o)
		local e = Instance.new("ParticleEmitter")
		e.Name = o.name or "Particles"
		local c = o.colors or { Color3.new(1, 1, 1), Color3.new(1, 1, 1) }
		e.Color = ColorSequence.new(c[1], c[2] or c[1])
		local s = o.size or { 0.4, 0.1 }
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s[1]), NumberSequenceKeypoint.new(1, s[2] or s[1]) })
		local t = o.transparency or { 0, 1 }
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, t[1]), NumberSequenceKeypoint.new(0.75, t[1] + (t[2] - t[1]) * 0.4), NumberSequenceKeypoint.new(1, t[2]) })
		e.Rate = o.rate or 5
		local sp = o.speed or { 1, 3 }
		e.Speed = NumberRange.new(sp[1], sp[2] or sp[1])
		local lf = o.life or { 2, 4 }
		e.Lifetime = NumberRange.new(lf[1], lf[2] or lf[1])
		e.SpreadAngle = Vector2.new(o.spread or 30, o.spread or 30)
		e.Acceleration = o.accel or Vector3.zero
		e.LightEmission = o.light or 0.5
		e.EmissionDirection = o.dir or Enum.NormalId.Top
		if o.lockedToPart then
			e.LockedToPart = true
		end
		e.Parent = part
		return e
	end
	-- an invisible anchor part (for lights / particles)
	function ctx.anchor(parent, pos, size)
		return K.part(parent, "Anchor", size or Vector3.new(1, 1, 1), CFrame.new(pos), P.Iron, { solid = false, transparency = 1, shadow = false })
	end
	-- an octagonal voxel slab (two crossed squares) centred on c.X, c.Z from y0 to y1
	function ctx.octagon(parent, name, c, r, y0, y1, color, o)
		local w = r * 2 * 0.9
		local a = K.part(parent, name, Vector3.new(w, y1 - y0, w), CFrame.new(c.X, (y0 + y1) / 2, c.Z), color, o)
		K.part(parent, name, Vector3.new(w, y1 - y0, w), CFrame.new(c.X, (y0 + y1) / 2, c.Z) * CFrame.Angles(0, math.rad(45), 0), color, o)
		return a
	end
	-- a voxel sphere (octagon slices); colorAt(t) with t 0 (bottom) .. 1 (top)
	function ctx.sphere(parent, name, c, R, colorAt, o)
		local n = math.max(4, math.floor(R / 5))
		for i = 0, n - 1 do
			local y0 = -R + 2 * R * i / n
			local y1 = -R + 2 * R * (i + 1) / n
			local ym = (y0 + y1) / 2
			local r = math.sqrt(math.max(R * R - ym * ym, 1))
			ctx.octagon(parent, name, Vector3.new(c.X, 0, c.Z), r, c.Y + y0, c.Y + y1, colorAt((i + 0.5) / n), o)
		end
	end
	-- a stepped dome (mushroom caps, bells): from r at its rim up h, in steps
	function ctx.dome(parent, name, c, r, h, steps, colorAt, o)
		for i = 0, steps - 1 do
			local t = i / steps
			local rr = r * math.sqrt(1 - t * t)
			ctx.octagon(parent, name, c, math.max(rr, r * 0.15), c.Y + h * t, c.Y + h * (t + 1 / steps), colorAt(t), o)
		end
	end
	-- a crystal: a tilted prism and its tip, standing on base
	function ctx.crystal(parent, base, h, w, color, tip, neon, tilt)
		local m = K.model(parent, "Crystal")
		local cf = CFrame.new(base) * (tilt or CFrame.Angles(math.rad(rng:NextNumber(-18, 18)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-18, 18))))
		K.part(m, "Crystal", Vector3.new(w, h * 0.72, w), cf * CFrame.new(0, h * 0.34, 0) * CFrame.Angles(0, math.rad(45), 0), color, { neon = neon, solid = false })
		K.part(m, "CrystalTip", Vector3.new(w * 0.58, h * 0.36, w * 0.58), cf * CFrame.new(0, h * 0.82, 0) * CFrame.Angles(0, math.rad(45), 0), tip or color, { neon = neon, solid = false })
		return m
	end
	-- a hanging strand (vine, rope, tentacle) from top straight down, with leaves / beads every few studs
	function ctx.strand(parent, top, len, color, leaf, w)
		w = w or 0.9
		K.box(parent, "Strand", top.X - w / 2, top.X + w / 2, top.Y - len, top.Y, top.Z - w / 2, top.Z + w / 2, color, { solid = false, shadow = false })
		if leaf then
			for j = 1, math.floor(len / 3.2) do
				local y = top.Y - j * 3.2 + rng:NextNumber(-0.6, 0.6)
				local dx = (j % 2 == 0) and 1 or -1
				K.box(parent, "Leaf", top.X + dx * 0.4 - 1, top.X + dx * 0.4 + 1, y - 0.6, y + 0.6, top.Z - 0.4, top.Z + 0.4, leaf, { solid = false, shadow = false })
			end
		end
	end

	-- real fire: an invisible anchor with a Fire in the theme's colours and a light
	function ctx.fire(parent, pos, size, c1, c2, lightColor, range)
		local a = ctx.anchor(parent, pos)
		local f = Instance.new("Fire")
		f.Size = size
		f.Heat = size * 0.8
		f.Color = c1
		f.SecondaryColor = c2 or c1
		f.Parent = a
		ctx.light(a, lightColor or c1, range or size * 4, 1.6)
		return a
	end
	-- a Kit plaque (Antique lettering) recoloured: style = { board, frame, line, text, neon }
	function ctx.plaque(parent, cf, w, h, text, style)
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
	-- a light the client keeps on from far away (WorldCuller reads KeyLight): landmarks that must read from the gate
	function ctx.keyLight(part, color, range, brightness)
		local l = ctx.light(part, color, range, brightness)
		l:SetAttribute("KeyLight", true)
		return l
	end
	-- a kaiju asset as a dark, shadowy silhouette with glowing eyes, standing at `at` facing `facing`, `height` tall.
	-- o: body (Color3), eye (Color3), transparency. Returns the model and its eye parts.
	function ctx.silhouette(parent, assetName, at, facing, height, o)
		o = o or {}
		local src = game:GetService("ServerStorage").Assets.Kaiju:FindFirstChild(assetName)
		if not src then
			return nil, {}
		end
		local k = src:Clone()
		for a in k:GetAttributes() do
			k:SetAttribute(a, nil)
		end
		local root = k.PrimaryPart
		local body = o.body or Color3.fromHex("0E0F12")
		local lift = o.lift or Color3.fromHex("2A2D34")
		local eyes = {}
		for _, d in k:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = false, false, false, false
				if d == root or d.Name:find("Closed") then
					d.Transparency = 1
				elseif d.Name:find("Eye") then
					d.Color = o.eye or Color3.new(1, 1, 1)
					d.Material = Enum.Material.Neon
					d.Transparency = 0
					table.insert(eyes, d)
				else
					local c = d.Color
					d.Color = body:Lerp(lift, math.clamp(0.299 * c.R + 0.587 * c.G + 0.114 * c.B, 0, 1))
					d.Material = Enum.Material.SmoothPlastic
					d.Transparency = o.transparency or 0
					if d:IsA("MeshPart") then
						d.TextureID = ""
					end
				end
			elseif d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("LuaSourceContainer") or d:IsA("GuiBase3d") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("Humanoid") or d:IsA("AnimationController") then
				d:Destroy()
			end
		end
		local _, s0 = k:GetBoundingBox()
		k:ScaleTo(k:GetScale() * height / s0.Y)
		k:PivotTo(CFrame.lookAt(at, at + Vector3.new(facing.X, 0, facing.Z)))
		local cf, s = k:GetBoundingBox()
		k:PivotTo(k:GetPivot() + Vector3.new(at.X - cf.X, at.Y - (cf.Y - s.Y / 2), at.Z - cf.Z))
		k.Name = "Silhouette"
		k.Parent = parent
		-- the eyes burn: a soft halo round each, and a light on the face
		for i, e in eyes do
			local g = e:Clone()
			g.Name = "EyeGlow"
			g:ClearAllChildren()
			g.Size = e.Size * 1.9
			g.Transparency = 0.55
			g.Parent = e.Parent
			if i == 1 then
				ctx.keyLight(e, o.eye or Color3.new(1, 1, 1), math.clamp(height * 0.35, 10, 24), 2.5)
			end
		end
		return k, eyes
	end
	if th.init then
		th.init(ctx)
	end

	---------------------------------------------------------------- clear the old version
	for _, n in { "Refined", "Gate" } do
		local old = model:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local floor = model:FindFirstChild("Floor")
	for _, t in floor:GetChildren() do
		t:Destroy()
	end
	local zone = model:FindFirstChild("Zone")
	zone.Size = Vector3.new(zone.Size.X, zone.Size.Y, HALF * 2)
	model:SetAttribute("Refined", true)
	local root = K.model(model, "Refined")
	ctx.root = root
	function ctx.sub(name)
		return root:FindFirstChild(name) or K.model(root, name)
	end

	---------------------------------------------------------------- ground and liquid
	local function keep(x, z)
		local side = z >= 0 and 1 or -1
		return math.abs(z) < edge[side](x) + 8
	end
	local nGround = T.ground(floor, {
		x0 = XA,
		x1 = XB,
		z0 = -(HALF + 8),
		z1 = HALF + 8,
		keep = function(x, z)
			return keep(x, z) and not ctx.isLiquid(x, z)
		end,
		color = function(x, z)
			return th.ground(ctx, x, z, T.n01(x / 14 + th.seed * 0.013, z / 14 + 0.6, 0.7), T.n01(x / 9 + 4.4 + th.seed * 0.007, z / 9 - 1.2, 0.2))
		end,
		fine = function(x, z)
			return pathGap(x, z) <= 0 and not ctx.nearNest(x, z, 11)
		end,
	})
	local nLiquid = 0
	if th.liquid then
		local liq = ctx.sub("Liquid")
		nLiquid = T.ground(liq, {
			name = "Liquid",
			x0 = XA,
			x1 = XB,
			z0 = -(HALF + 8),
			z1 = HALF + 8,
			top = th.liquid.top or -0.6,
			keep = function(x, z)
				return keep(x, z) and ctx.isLiquid(x, z)
			end,
			color = function(x, z)
				return th.liquid.color(ctx, x, z, T.n01(x / 6 + 1.3, z / 6 + 7.1, 0.9))
			end,
		})
		for _, p in liq:GetChildren() do
			if p:IsA("BasePart") then
				if th.liquid.neon then
					p.Material = Enum.Material.Neon
				end
				p.Transparency = th.liquid.transparency or 0
				p.CastShadow = false
				if th.liquid.neon or (th.liquid.transparency or 0) > 0 then
					for _, t in p:GetChildren() do
						t:Destroy()
					end
				end
			end
		end
		if th.liquid.bed then
			-- a bed under see-through liquid
			for _, p in liq:GetChildren() do
				if p:IsA("BasePart") and p.Name == "Liquid" then
					local s = p.Size
					K.part(liq, "LiquidBed", Vector3.new(s.X, 0.6, s.Z), p.CFrame * CFrame.new(0, -s.Y / 2 - 0.3 - 1, 0), th.liquid.bed, { studs = K.TOP })
				end
			end
		end
	end
	table.insert(report, nGround .. " ground, " .. nLiquid .. " liquid pieces")

	---------------------------------------------------------------- path slabs
	local path = ctx.sub("Path")
	for pi, p in th.paths do
		for i = 1, #p - 1 do
			local a, c = Vector3.new(p[i][1], 0, p[i][2]), Vector3.new(p[i + 1][1], 0, p[i + 1][2])
			local d = c - a
			local L = d.Magnitude
			local across = Vector3.new(-d.Z, 0, d.X).Unit
			local t = rng:NextNumber(0, 2)
			while t < L do
				local half = (p[i][3] + (p[i + 1][3] - p[i][3]) * t / L) / 2
				local at = a + d.Unit * t + across * rng:NextNumber(-(half - 2.2), half - 2.2)
				if rng:NextNumber() < (th.slabChance or 0.6) and not ctx.nearNest(at.X, at.Z, 13) and ctx.liquidGap(at.X, at.Z) > 1 then
					local sz = Vector3.new(rng:NextNumber(2.4, 3.8), 0.26, rng:NextNumber(2.2, 3.2))
					local s = K.part(path, "Flagstone", sz, CFrame.new(at.X, 0.07, at.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), th.slabs[rng:NextInteger(1, #th.slabs)], { studs = K.TOP, solid = false })
					for _, tx in s:GetChildren() do
						tx.StudsPerTileU, tx.StudsPerTileV = 2, 2
					end
				end
				t += pi >= 5 and 3.6 or 4.4
			end
		end
	end

	---------------------------------------------------------------- cliffs, walls, ridges
	local cliffs, walls, back = ctx.sub("Cliffs"), ctx.sub("Walls"), ctx.sub("Back")
	local tops, allCols = {}, {}
	local function capColor(x, r)
		return th.cap(ctx, x, r)
	end
	local ridgeCap = th.ridgeCap and function(x, r)
		return th.ridgeCap(ctx, x, r)
	end or capColor
	for _, side in { 1, -1 } do
		local cols = T.cliffRow(cliffs, {
			side = side,
			xa = XA,
			xb = XB,
			edge = edge[side],
			height = function(x)
				return th.height(ctx, side, x, T.n01(x / 18 + (side > 0 and 2.7 or 6.1) + th.seed * 0.01, side * 3.9, 0.4))
			end,
			pal = th.rock,
			capColor = capColor,
			tint = th.tint,
			rng = rng,
			href = 100,
		})
		T.walls(walls, cols, side, 100)
		allCols[side] = cols
		for _, c in cols do
			if c.h > 0 then
				table.insert(tops, { side = side, x = (c.x0 + c.x1) / 2, y = c.top + 1.4, z0 = c.lastFront + 3, z1 = c.back - 3 })
				if th.column then
					th.column(ctx, c, side)
				end
			end
		end
		local ridgeFn = th.rugged and T.massif or T.ridgeRow
		local row2 = ridgeFn(back, {
			side = side,
			xa = XA,
			xb = XB,
			minW = 12,
			maxW = 20,
			slice = { 16, 26 },
			front = function(x)
				return th.ridgeFront and th.ridgeFront(ctx, side, x) or edge[side](x) + 22
			end,
			back = function()
				return 214
			end,
			height = function(x)
				return th.ridge(ctx, side, x, T.n01(x / 25 + side * 4.7 + th.seed * 0.01, 2.9, side))
			end,
			layers = 2,
			pal = th.rock,
			capColor = ridgeCap,
			tint = th.tint,
			rng = rng,
			href = 150,
		})
		for _, c in row2 do
			if c.crestZ0 then
				table.insert(tops, { side = side, x = (c.x0 + c.x1) / 2, y = c.top, z0 = c.crestZ0 + 2, z1 = c.crestZ1 - 2, big = true })
			else
				table.insert(tops, { side = side, x = (c.x0 + c.x1) / 2, y = c.top, z0 = c.front + 4, z1 = math.min(c.back - 4, c.front + 30), big = true })
			end
		end
		ridgeFn(back, {
			side = side,
			xa = XA,
			xb = XB + (b.next and 0 or 60),
			minW = 24,
			maxW = 38,
			slice = { 26, 40 },
			front = function()
				return 204
			end,
			back = function()
				return 330
			end,
			height = function(x)
				return th.farHeight(ctx, side, x, T.n01(x / 39 + side * 2.3 + th.seed * 0.01, 7.7, side))
			end,
			layers = 2,
			far = true,
			pal = th.farRock or th.rock,
			capColor = ridgeCap,
			tint = th.tint,
			rng = rng,
			href = 190,
		})
	end
	ctx.tops, ctx.cols = tops, allCols
	function ctx.nearestCol(side, x, minH)
		local best, bd
		for _, c in allCols[side] do
			local d = math.abs((c.x0 + c.x1) / 2 - x)
			if c.h > (minH or 30) and c.layers and #c.layers >= 3 and (not bd or d < bd) then
				best, bd = c, d
			end
		end
		return best
	end

	---------------------------------------------------------------- the theme's features, nest and gate
	th.features(ctx)
	local oldArt = nest:FindFirstChild("NestArt")
	if oldArt then
		oldArt:Destroy()
	end
	local art = K.model(nest, "NestArt")
	th.nest(ctx, art, NEST)
	local gate = K.model(model, "Gate")
	th.gate(ctx, gate)

	---------------------------------------------------------------- Coming Soon (while the biome is locked)
	if b.Locked then
		local cs = K.model(gate, "ComingSoon")
		local gx = XA
		local wall = K.box(cs, "Barrier", gx - 0.5, gx + 0.5, -2, 110, -HALF - 6, HALF + 6, P.Iron, { transparency = 1 })
		for _, t in wall:GetChildren() do
			t:Destroy()
		end
		wall.CanQuery, wall.CastShadow = false, false
		if th.lock then
			th.lock(ctx, cs, gx)
		else
		local field = K.box(cs, "Field", gx - 0.25, gx + 0.25, 0, th.gateOpenH or 60, -56, 56, th.accent, { neon = true, transparency = 0.93, solid = false, shadow = false })
		-- a brighter rim round the field
		for _, e in { { 0, 0.6, -56, 56 }, { (th.gateOpenH or 60) - 0.6, th.gateOpenH or 60, -56, 56 }, { 0, th.gateOpenH or 60, -56, -55.4 }, { 0, th.gateOpenH or 60, 55.4, 56 } } do
			K.box(cs, "FieldRim", gx - 0.3, gx + 0.3, e[1], e[2], e[3], e[4], th.accent, { neon = true, transparency = 0.35, solid = false, shadow = false })
		end
		ctx.emit(field, { colors = { th.accent, Color3.new(1, 1, 1) }, size = { 0.5, 0.1 }, rate = 30, speed = { 0.5, 1.5 }, life = { 2, 3.5 }, spread = 180, light = 1, dir = Enum.NormalId.Left })
		for _, f in { -1, 1 } do
			local x = gx + f * 1.3
			K.sign(cs, "ComingSoon", CFrame.lookAt(Vector3.new(x, 24, 0), Vector3.new(x + f * 20, 24, 0)), 42, 9, "COMING SOON")
			K.sign(cs, "ComingSoonName", CFrame.lookAt(Vector3.new(x, 14.5, 0), Vector3.new(x + f * 20, 14.5, 0)), 30, 4.6, string.upper(b.DisplayName or b.Id), { cream = true })
		end
		end
	end

	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	table.insert(report, (b.DisplayName or b.Id) .. " now " .. n .. " parts")
	return table.concat(report, "; ")
end
