-- Sunken Abyss (x 1052..1302), built by CanyonBuilder.NewBiome: a drained sea floor between deep-blue cliffs crusted
-- with coral.
--   Ground     blue-grey sea sand with pale ripples, dark silt and seaweed; Venom's mud and grass giving way to wet sand at
--              the border; a pale sand road; clear tide pools
--   Whale      a whale's ribcage arching over the path like a tunnel (spine, vertebrae, barnacles, weed), its skull in
--              the south pocket
--   Wreck      a galleon half-sunk in the north pocket: tilted hull, broken masts, torn sail, lit stern windows, an open
--              treasure chest
--   Life       kelp forests, coral reefs (branching, brain, tube, fan), floating jellyfish lanterns, bubbling vents, light
--              shafts slanting down from above
--   Nest       a giant open clam in the ruins of a drowned temple (broken marble columns, a mosaic floor)
--   Gate       the Coral Gate: rock pillars and a rock arch crusted with coral, a clam with a glowing pearl on top, the
--              name hanging on chains
local hex = Color3.fromHex

return function(b, K, T)
	local P = K.P
	local XA, XB = b.x0, b.x1
	local NX = XA + (b.NestAt or 0.55) * (XB - XA)
	local C, rng

	---------------------------------------------------------------- colours
	local ROCK = { hex("1B2D40"), hex("23405A"), hex("2E5470"), hex("41708A"), accent = hex("2A6670") }
	local SAND = { hex("5E8590"), hex("557780"), hex("4C6C75"), hex("688F98") }
	local RIPPLE = { hex("8FA8A4"), hex("9FB5AE") }
	local SILT = hex("3E5A63")
	local WEEDBED = { hex("2F6B5A"), hex("3A7A60") }
	local ROAD = { hex("9DB2AC"), hex("8EA6A1"), hex("A9BDB6") }
	local MOSAIC = { hex("D9E4DC"), hex("4FA3A8"), hex("BFD3CC"), hex("2F7F8A") }
	local WETMUD = { hex("3D6B33"), hex("4A5A40"), hex("5A6E62") } -- Venom's grass and mud turning to wet sand
	local SLABS = { hex("7A8F94"), hex("6A8085"), hex("8C9FA3") }
	local WATER = { hex("2E9FC4"), hex("2690B5"), hex("37AEDB") }
	local CAPS = { hex("2F9C80"), hex("2A8A74"), hex("3BA5A0"), hex("E0609A"), hex("E07A4C"), hex("8E5FD6") }
	local RIDGECAPS = { hex("2F8C78"), hex("2A7A6A"), hex("357F84"), hex("2F7A6E"), hex("2A6E70") }
	local CYAN = hex("6FF2FF")
	local BONE = { hex("D8D0BC"), hex("C8BEA6"), hex("B3A88E") }
	local BARNACLE = { hex("9AA6A4"), hex("7F8C8A") }
	local WEED = hex("3E6B3A")
	local KELP = { hex("4A7A34"), hex("5A8A30"), hex("6B8A2C") }
	local MARBLE = { hex("D6E0DA"), hex("C2D0CA"), hex("AEBFB8") }
	local TIMBERS = { hex("5A4A3A"), hex("4A3C2E"), hex("62523C") }
	local SAIL = hex("BDB59C")
	local GOLD = hex("FFC94A")
	local CORAL = {
		{ base = hex("E0609A"), tip = hex("FFB3D4") },
		{ base = hex("E07A4C"), tip = hex("FFC79A") },
		{ base = hex("8E5FD6"), tip = hex("D2B8FF") },
		{ base = hex("2F9C80"), tip = hex("9CF2D8") },
		{ base = hex("E8C14A"), tip = hex("FFF0B0") },
	}
	local JELLY = {
		{ bell = hex("5FD8F0"), top = hex("A8F4FF"), core = hex("E8FFFF"), light = CYAN },
		{ bell = hex("F070C0"), top = hex("FFB3E0"), core = hex("FFE6F4"), light = hex("FF7ACB") },
		{ bell = hex("A070F0"), top = hex("D6B8FF"), core = hex("F0E6FF"), light = hex("B47CFF") },
	}

	---------------------------------------------------------------- layout
	local POOLS = { { 1082, 72, 7 }, { 1150, -58, 8 }, { 1226, 58, 7 }, { 1272, -70, 8 } }
	local function liquidGap(x, z)
		local g = math.huge
		for _, p in POOLS do
			local d = math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2)
			g = math.min(g, d - p[3] * (0.85 + 0.3 * T.n01(x / 5 + p[1], z / 5, 6.1)))
		end
		return g
	end
	local RIB0, RIB1 = 1106, 1160 -- the whale's ribcage over the path
	local WRECK = Vector3.new(1267, 0, 80)
	local function nearWreck(x, z, m)
		return x > 1232 - (m or 0) and x < 1292 + (m or 0) and z > 52 - (m or 0)
	end

	---------------------------------------------------------------- shapes
	local function kelp(parent, at, h)
		local m = K.model(parent, "Kelp")
		local n = math.clamp(math.floor(h / 5), 3, 7)
		local pts, widths = {}, {}
		local x, z = at.X, at.Z
		for i = 0, n do
			table.insert(pts, Vector3.new(x, at.Y + h * i / n, z))
			x += rng:NextNumber(-1.2, 1.2)
			z += rng:NextNumber(-1.2, 1.2)
			if i < n then
				table.insert(widths, 1.1 - 0.5 * i / n)
			end
		end
		T.chain(m, "KelpStalk", pts, widths, { KELP[1], KELP[2] }, { solid = false, shadow = false })
		for i = 2, n, 2 do
			K.part(m, "KelpBlade", Vector3.new(0.3, h / n * 0.9, 2), CFrame.new(pts[i]) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.new(0, 0, 1.1) * CFrame.Angles(math.rad(30), 0, 0), KELP[3], { solid = false, shadow = false })
		end
		local tip = pts[#pts]
		K.box(m, "Bulb", tip.X - 0.6, tip.X + 0.6, tip.Y - 0.4, tip.Y + 0.8, tip.Z - 0.6, tip.Z + 0.6, KELP[3], { solid = false, shadow = false })
		return m
	end
	local function coral(parent, at, s, kind)
		local m = K.model(parent, "Coral")
		kind = kind or rng:NextInteger(1, 4)
		local col = CORAL[rng:NextInteger(1, #CORAL)]
		if kind == 1 then -- branching
			for _ = 1, 3 do
				local a = rng:NextNumber(0, math.pi * 2)
				local p1 = at + Vector3.new(math.cos(a) * 0.8, 2.2, math.sin(a) * 0.8) * s
				local p2 = p1 + Vector3.new(math.cos(a) * 1.2, 1.8, math.sin(a) * 1.2) * s
				T.chain(m, "Branch", { at, p1, p2 }, { 0.75 * s, 0.55 * s }, { col.base, col.tip }, { solid = false })
			end
		elseif kind == 2 then -- brain
			C.dome(m, "Brain", at - Vector3.new(0, 0.3, 0), 2.2 * s, 1.8 * s, 2, function(t)
				return t < 0.4 and col.base or col.tip
			end, { studs = K.ALL, solid = false })
		elseif kind == 3 then -- tubes
			for _ = 1, rng:NextInteger(3, 5) do
				local ox, oz = rng:NextNumber(-1.2, 1.2) * s, rng:NextNumber(-1.2, 1.2) * s
				local h = rng:NextNumber(1.5, 4) * s
				local w = rng:NextNumber(0.6, 1) * s
				K.box(m, "Tube", at.X + ox - w / 2, at.X + ox + w / 2, at.Y - 0.2, at.Y + h, at.Z + oz - w / 2, at.Z + oz + w / 2, col.base, { solid = false })
				K.box(m, "TubeRim", at.X + ox - w / 2 - 0.1, at.X + ox + w / 2 + 0.1, at.Y + h, at.Y + h + 0.3, at.Z + oz - w / 2 - 0.1, at.Z + oz + w / 2 + 0.1, col.tip, { solid = false })
			end
		else -- fans
			for _ = 1, 2 do
				K.part(m, "Fan", Vector3.new(3.4 * s, 3 * s, 0.25), CFrame.new(at + Vector3.new(0, 1.5 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-12, 12))), col.base, { solid = false })
			end
		end
		return m
	end
	local function jelly(parent, at, r, look)
		local m = K.model(parent, "Jellyfish")
		C.dome(m, "Bell", at, r, r * 0.8, 2, function(t)
			return t < 0.5 and look.bell or look.top
		end, { neon = true, transparency = 0.25, solid = false, shadow = false })
		local core = K.box(m, "Core", at.X - r * 0.35, at.X + r * 0.35, at.Y + 0.2, at.Y + r * 0.5, at.Z - r * 0.35, at.Z + r * 0.35, look.core, { neon = true, solid = false, shadow = false })
		C.octagon(m, "Rim", at, r * 1.04, at.Y - 0.4, at.Y + 0.1, look.bell, { neon = true, transparency = 0.45, solid = false, shadow = false })
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			local p = at + Vector3.new(math.cos(a) * r * 0.55, -0.4, math.sin(a) * r * 0.55)
			local len = rng:NextNumber(r * 1.4, r * 3)
			K.box(m, "Tentacle", p.X - 0.15, p.X + 0.15, p.Y - len, p.Y, p.Z - 0.15, p.Z + 0.15, look.bell, { neon = true, transparency = 0.3, solid = false, shadow = false })
		end
		C.light(core, look.light, r * 4 + 6, 1.2)
		return m
	end
	local function vent(parent, at)
		local m = K.model(parent, "BubbleVent")
		local r = rng:NextNumber(1.2, 2)
		C.octagon(m, "VentRim", at, r, -0.2, 0.5, C.rockAt(at, 0.2), { studs = K.TOP, solid = false })
		C.octagon(m, "VentHole", at, r * 0.55, 0.45, 0.56, hex("0E1A24"), { solid = false })
		local a = C.anchor(m, at + Vector3.new(0, 0.8, 0), Vector3.new(r, 0.2, r))
		C.emit(a, { name = "Bubbles", colors = { hex("E8FFFF"), hex("9FE8FF") }, size = { 0.3, 0.6 }, rate = 6, speed = { 3, 6 }, life = { 3, 6 }, spread = 10, accel = Vector3.new(0, 1.5, 0), light = 0.3, transparency = { 0.2, 1 } })
		return m
	end
	local function barnacles(parent, p, n, spread)
		for _ = 1, n do
			local q = p + Vector3.new(rng:NextNumber(-spread, spread), rng:NextNumber(-spread, spread) * 0.5, rng:NextNumber(-spread, spread))
			local s = rng:NextNumber(0.4, 0.8)
			K.box(parent, "Barnacle", q.X - s, q.X + s, q.Y - s * 0.6, q.Y + s * 0.6, q.Z - s, q.Z + s, BARNACLE[rng:NextInteger(1, 2)], { solid = false, shadow = false })
		end
	end

	-- the whale: ribs arching over the path from RIB0 to RIB1, the spine along their tops, the tail sweeping down north
	local function whale(parent)
		local m = K.model(parent, "WhaleRibs")
		local spine = {}
		local x = RIB0 - 8
		while x <= RIB1 + 6 do
			local y = 40 + 3 * math.sin((x - RIB0) / (RIB1 - RIB0) * math.pi)
			table.insert(spine, Vector3.new(x, y, 0))
			K.box(m, "Vertebra", x - 1.8, x + 1.8, y - 1.5, y + 2.5, -2.4, 2.4, BONE[2], { studs = K.SIDES, solid = false })
			K.box(m, "Spike", x - 0.6, x + 0.6, y + 2.5, y + 5, -0.8, 0.8, BONE[1], { solid = false })
			x += 4.5
		end
		T.chain(m, "Spine", spine, { 2.4 }, { BONE[1] })
		local i = 0
		for rx = RIB0, RIB1, 9 do
			local top = 40 + 3 * math.sin((rx - RIB0) / (RIB1 - RIB0) * math.pi)
			local R = top + 6
			T.arcBone(m, Vector3.new(rx, -6, 0), math.pi / 2, R, 90, 176, 3.2, 2, { BONE[1], BONE[2] }, 5)
			T.arcBone(m, Vector3.new(rx, -6, 0), math.pi / 2, R, 90, 4, 3.2, 2, { BONE[1], BONE[2] }, 5)
			i += 1
			-- barnacles and hanging weed
			for _, s in { -1, 1 } do
				local a = math.rad(rng:NextNumber(110, 150))
				local p = Vector3.new(rx, -6 + R * math.sin(a), s * R * math.abs(math.cos(a)))
				barnacles(m, p, 2, 1.2)
				if rng:NextNumber() < 0.6 then
					C.strand(m, p - Vector3.new(0, 1, 0), rng:NextNumber(3, 9), WEED, KELP[3], 0.6)
				end
			end
		end
		-- the tail: the spine sweeping down to the sand in the north clearing, flukes half-buried
		local last = spine[#spine]
		local tail = { last, last + Vector3.new(6, -6, 6), last + Vector3.new(12, -18, 16), last + Vector3.new(16, -32, 26), Vector3.new(last.X + 18, 1, 38) }
		T.chain(m, "Tail", tail, { 2.2, 2, 1.8, 1.6 }, { BONE[1], BONE[2] })
		for k = 2, #tail - 1 do
			K.box(m, "Vertebra", tail[k].X - 1.6, tail[k].X + 1.6, tail[k].Y - 1.6, tail[k].Y + 1.6, tail[k].Z - 1.6, tail[k].Z + 1.6, BONE[2], { solid = false })
		end
		local fl = tail[#tail]
		for _, s in { -1, 1 } do
			K.part(m, "Fluke", Vector3.new(10, 1.2, 3.6), CFrame.new(fl + Vector3.new(s * 4, 0.2, 2)) * CFrame.Angles(0, s * math.rad(30), 0), BONE[3], { studs = K.TOP, solid = false })
		end
		return m
	end

	-- the whale's skull, fallen in the south pocket: cranium, crest, long rostrum, the jawbones lying beside it
	local function whaleSkull(parent, cf)
		local m = K.model(parent, "WhaleSkull")
		local function p(name, size, off, color)
			return K.part(m, name, size, cf * CFrame.new(off), color, { studs = K.SIDES, solid = false })
		end
		p("Cranium", Vector3.new(20, 9, 14), Vector3.new(0, 3.5, -4), BONE[1])
		p("Crest", Vector3.new(14, 3, 10), Vector3.new(0, 8.5, -2), BONE[2])
		p("Rostrum", Vector3.new(9, 4, 22), Vector3.new(0, 2, -21), BONE[1])
		p("RostrumTip", Vector3.new(6, 3, 6), Vector3.new(0, 1.6, -34), BONE[2])
		for _, sx in { -1, 1 } do
			p("EyeSocket", Vector3.new(0.6, 4, 5), Vector3.new(sx * 10.1, 4, -8), P.Socket)
			p("Cheek", Vector3.new(4, 4, 10), Vector3.new(sx * 9, 1.5, -10), BONE[2])
			T.chain(m, "Jawbone", { cf:PointToWorldSpace(Vector3.new(sx * 8, 0.8, -4)), cf:PointToWorldSpace(Vector3.new(sx * 13, 1.2, -20)), cf:PointToWorldSpace(Vector3.new(sx * 11, 1, -38)) }, { 2.4, 2 }, { BONE[2], BONE[1] })
		end
		barnacles(m, cf:PointToWorldSpace(Vector3.new(4, 8, -6)), 5, 3)
		coral(m, cf:PointToWorldSpace(Vector3.new(-4, 10, -2)), 1.1, 1)
		coral(m, cf:PointToWorldSpace(Vector3.new(3, 4, -24)), 0.9, 3)
		C.strand(m, cf:PointToWorldSpace(Vector3.new(-10, 6, -12)), 5, WEED, KELP[3], 0.6)
		return m
	end

	-- a galleon half-sunk in the sand: strakes of timber, a dark hold, stern castle with lit windows, broken masts
	local function shipwreck(parent, base, yaw)
		local m = K.model(parent, "Shipwreck")
		local L, W = 46, 15
		-- lying broadside to the lane, rolled so its deck and the hole in its side face the way past
		local F = CFrame.new(base + Vector3.new(0, -2.5, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-18), 0, math.rad(9))
		local function beam(u)
			local t = (u + 1) / 2
			local s = math.sin(math.pi * math.clamp(t * 0.92 + 0.04, 0, 1))
			if u > 0 then
				s *= 1 - u * u * 0.35
			end
			return W / 2 * s ^ 0.6
		end
		for k = 0, 4 do
			local y = k * 2.1
			local spread = 0.55 + 0.45 * (k / 4)
			for _, side in { -1, 1 } do
				local prev
				for i = 0, 6 do
					local u = -1 + 2 * i / 6
					local pt = F:PointToWorldSpace(Vector3.new(u * L / 2 * (k == 0 and 0.9 or 1), y, side * beam(u) * spread))
					-- a hole stove in the side
					local hole = side < 0 and k >= 2 and (i == 3 or i == 4)
					if prev and not hole then
						T.chain(m, "Strake", { prev, pt }, { 2.2 }, { TIMBERS[k % 3 + 1] }, { studs = K.SIDES, solid = false })
					end
					prev = pt
				end
			end
		end
		K.part(m, "Hold", Vector3.new(L * 0.72, 6, W * 0.55), F * CFrame.new(-2, 3.4, 0), hex("1E160F"), { solid = false })
		for dx = -21, -12, 2.4 do
			K.part(m, "Deck", Vector3.new(2, 0.5, W * 0.8), F * CFrame.new(dx, 8.6, 0), TIMBERS[3], { studs = K.TOP, solid = false })
		end
		K.part(m, "SternCastle", Vector3.new(9, 6, W * 0.78), F * CFrame.new(-L / 2 + 6, 11.6, 0), TIMBERS[2], { studs = K.SIDES, solid = false })
		K.part(m, "SternRail", Vector3.new(9.4, 1, W * 0.82), F * CFrame.new(-L / 2 + 6, 15, 0), TIMBERS[1], { solid = false })
		local win
		for _, wz in { -3.5, 0, 3.5 } do
			win = K.part(m, "Window", Vector3.new(0.3, 2, 1.8), F * CFrame.new(-L / 2 + 1.4, 11.8, wz), hex("FFB85A"), { neon = true, solid = false, shadow = false })
		end
		C.light(win, hex("FFB85A"), 18, 1.2)
		K.part(m, "Mast", Vector3.new(1.6, 24, 1.6), F * CFrame.new(1, 17, 0) * CFrame.Angles(math.rad(-22), 0, math.rad(6)), TIMBERS[1], { studs = K.SIDES, solid = false })
		local yard = F * CFrame.new(1, 17, 0) * CFrame.Angles(math.rad(-22), 0, math.rad(6)) * CFrame.new(0, 8, 0)
		K.part(m, "Yard", Vector3.new(1, 1, 15), yard * CFrame.Angles(0, 0, math.rad(12)), TIMBERS[2], { solid = false })
		K.part(m, "Sail", Vector3.new(0.25, 8, 11), yard * CFrame.new(0.4, -4.4, 1.5) * CFrame.Angles(math.rad(8), 0, 0), SAIL, { solid = false })
		K.part(m, "SailTatter", Vector3.new(0.25, 3, 4), yard * CFrame.new(0.4, -9.6, -2.6) * CFrame.Angles(math.rad(-10), 0, 0), SAIL, { solid = false })
		K.part(m, "MastStump", Vector3.new(1.4, 7, 1.4), F * CFrame.new(15, 11, 0) * CFrame.Angles(0, 0, math.rad(-10)), TIMBERS[2], { solid = false })
		T.chain(m, "Bowsprit", { F:PointToWorldSpace(Vector3.new(L / 2 - 1, 7.5, 0)), F:PointToWorldSpace(Vector3.new(L / 2 + 9, 12, 0)) }, { 1.2 }, { TIMBERS[1] })
		for i = 1, 5 do
			local u = -0.7 + i * 0.25
			K.part(m, "GunPort", Vector3.new(1.6, 1.3, 0.5), F * CFrame.new(u * L / 2, 5.4, beam(u) * 0.9 + 1), hex("15100B"), { solid = false })
			K.part(m, "GunPort", Vector3.new(1.6, 1.3, 0.5), F * CFrame.new(u * L / 2, 5.4, -(beam(u) * 0.9 + 1)), hex("15100B"), { solid = false })
		end
		for _ = 1, 6 do
			local u = rng:NextNumber(-0.8, 0.8)
			local side = rng:NextNumber() < 0.5 and -1 or 1
			C.strand(m, F:PointToWorldSpace(Vector3.new(u * L / 2, 8.4, side * beam(u) * 1.02)), rng:NextNumber(2, 5), WEED, KELP[3], 0.5)
		end
		barnacles(m, F:PointToWorldSpace(Vector3.new(6, 2, 7)), 6, 3)
		-- built at 1:1, then scaled up so it reads as a galleon, not a rowing boat; still sunk into the sand
		local S = 1.45
		m:ScaleTo(m:GetScale() * S)
		for _, t in m:GetDescendants() do
			if t:IsA("Texture") then
				t.StudsPerTileU *= S
				t.StudsPerTileV *= S
			end
		end
		local bb, size = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + Vector3.new(base.X - bb.X, -4 - (bb.Y - size.Y / 2), base.Z - bb.Z))
		return m
	end

	-- the clam: two ribbed shells, the upper one raised; o.pearl adds a glowing pearl. hinge = the back middle, dir = the
	-- way it opens (flat), s = scale
	local function clam(parent, hinge, dir, s, open, o)
		o = o or {}
		local m = K.model(parent, "Clam")
		local fwd = Vector3.new(dir.X, 0, dir.Z).Unit
		local right = Vector3.new(-fwd.Z, 0, fwd.X)
		local SHELL = { hex("F2D8DE"), hex("E6B8C6"), hex("D99AB0") }
		for _, upper in { false, true } do
			for i = -2, 2 do
				local phi = math.rad(i * 26)
				local d = fwd * math.cos(phi) + right * math.sin(phi)
				if upper then
					d = d * math.cos(open) + Vector3.new(0, math.sin(open), 0) * math.cos(phi)
				end
				local len = (9 - math.abs(i) * 0.8) * s
				local c = hinge + d * len / 2 + Vector3.new(0, upper and 0.6 * s or 0.3 * s, 0)
				K.part(m, upper and "UpperShell" or "LowerShell", Vector3.new(1.9 * s, 0.8 * s, len), CFrame.lookAt(c, c + d), SHELL[(i + 3) % 3 + 1], { studs = K.TOP, solid = false })
			end
		end
		if o.pearl then
			local pc = hinge + fwd * 4.2 * s + Vector3.new(0, 2.2 * s, 0)
			C.sphere(m, "Pearl", pc, 2.2 * s, function()
				return hex("EFFFFF")
			end, { neon = true, solid = false, shadow = false })
			C.light(C.anchor(m, pc), CYAN, 14 * s + 10, 2)
		end
		return m
	end

	---------------------------------------------------------------- the theme
	local th = {
		seed = 5521,
		half = 92,
		accent = CYAN,
		gateOpenH = 60,
		blendLen = 26,
		rock = ROCK,
		slabs = SLABS,
		slabChance = 0.4,
		edgeN = { { 1052, 65 }, { 1062, 66 }, { 1072, 76 }, { 1086, 88 }, { 1104, 90 }, { 1116, 78 }, { 1128, 68 }, { 1142, 70 }, { 1156, 80 }, { 1172, 92 }, { 1208, 92 }, { 1220, 80 }, { 1232, 72 }, { 1244, 80 }, { 1256, 90 }, { 1278, 90 }, { 1290, 72 }, { 1297, 66 }, { 1302, 65 } },
		edgeS = { { 1052, 65 }, { 1064, 64 }, { 1076, 70 }, { 1090, 82 }, { 1106, 84 }, { 1118, 72 }, { 1130, 64 }, { 1146, 66 }, { 1160, 76 }, { 1176, 84 }, { 1204, 84 }, { 1216, 74 }, { 1230, 66 }, { 1244, 72 }, { 1258, 88 }, { 1274, 90 }, { 1288, 74 }, { 1296, 66 }, { 1302, 65 } },
		paths = {
			{ { 1052, 0, 14 }, { 1068, 6, 12 }, { 1084, 10, 12 }, { 1100, 4, 12 }, { 1116, -6, 12 }, { 1132, -10, 12 }, { 1148, -6, 12 }, { 1162, 0, 12 }, { 1172, 0, 12 } },
			{ { 1172, 0, 8 }, { 1175, 14, 7 }, { 1182, 26, 7 }, { 1197, 26, 7 }, { 1204, 14, 7 }, { 1207, 0, 8 } },
			{ { 1172, 0, 8 }, { 1175, -14, 7 }, { 1182, -26, 7 }, { 1197, -26, 7 }, { 1204, -14, 7 }, { 1207, 0, 8 } },
			{ { 1207, 0, 12 }, { 1222, 8, 12 }, { 1238, 10, 12 }, { 1254, 2, 12 }, { 1270, -8, 12 }, { 1286, -4, 12 }, { 1302, 0, 13 } },
			{ { 1250, 4, 6 }, { 1252, 36, 6 }, { 1250, 54, 6 } }, -- up to the wreck
			{ { 1100, 4, 6 }, { 1098, -36, 6 }, { 1097, -52, 6 } }, -- down to the whale's skull
		},
		liquid = {
			gap = liquidGap,
			transparency = 0.3,
			top = -0.5,
			bed = hex("2A4652"),
			color = function(_, _, _, n)
				return WATER[math.clamp(math.floor(n * 3) + 1, 1, 3)]
			end,
		},
	}

	function th.init(ctx)
		C, rng = ctx, ctx.rng
	end

	function th.ground(ctx, x, z, n, n2)
		local dn = math.sqrt((x - NX) ^ 2 + z * z)
		if dn < 17.5 then
			-- the drowned temple's mosaic: rings of white and teal
			local ring = math.floor(dn / 4)
			return MOSAIC[(ring + (n > 0.55 and 1 or 0)) % #MOSAIC + 1]
		end
		if ctx.pathGap(x, z) <= 0 then
			return ROAD[math.clamp(math.floor(n * 3) + 1, 1, 3)]
		end
		local f = ctx.blend(x)
		if f > 0 and n2 < f * 1.3 - 0.1 then
			return WETMUD[n2 < f * 0.6 - 0.2 and 1 or (n < 0.5 and 2 or 3)]
		end
		if ctx.liquidGap(x, z) < 2.2 then
			return SILT
		end
		local side = z >= 0 and 1 or -1
		if math.abs(z) > ctx.edge[side](x) - 9 and n2 < 0.4 then
			return WEEDBED[n < 0.5 and 1 or 2]
		end
		-- ripples: thin pale bands across the sand
		if math.abs(math.sin(x / 5.5 + z / 14 + n * 2)) > 0.93 and n2 > 0.3 then
			return RIPPLE[n < 0.5 and 1 or 2]
		end
		if n2 < 0.14 then
			return SILT
		end
		return SAND[math.clamp(math.floor(n * 4) + 1, 1, 4)]
	end

	function th.cap(ctx, x, r)
		local f = ctx.blend(x)
		if r:NextNumber() < f * f * 1.6 then
			return hex("2F7A36") -- Venom's moss still on the first cliffs
		end
		return CAPS[r:NextInteger(1, #CAPS)]
	end

	function th.ridgeCap(_, _, r)
		return RIDGECAPS[r:NextInteger(1, #RIDGECAPS)]
	end

	function th.tint(x, c)
		local f = math.clamp(1 - (x - XA) / 34, 0, 1)
		return f > 0 and c:Lerp(hex("3B4434"), f * 0.5) or c
	end

	function th.height(_, side, x, n)
		local h = 46 + n * 30
		if side > 0 and x > 1236 and x < 1288 then
			h = 28 + n * 10 -- low behind the wreck, so its masts show against the sky
		end
		if x < 1070 then
			h = math.max(h, 66 + n * 10)
		elseif x > 1286 then
			h = math.max(h, 64 + n * 10)
		end
		return math.floor(h / 2 + 0.5) * 2
	end

	function th.ridge(_, side, x, n)
		if side > 0 and x > 1230 and x < 1294 then
			return math.floor(36 + n * 12)
		end
		return math.floor(62 + n * 40)
	end

	function th.farHeight(_, _, _, n)
		return math.floor(120 + n * 70)
	end

	function th.column(ctx, c, side)
		-- coral and barnacles on the ledges, weed hanging off the caps, glowing anemones in the cracks
		if rng:NextNumber() < 0.35 and #c.layers >= 2 then
			local L = c.layers[rng:NextInteger(2, #c.layers)]
			local below = c.layers[table.find(c.layers, L) - 1]
			if L.f - below.f >= 2.5 then
				coral(ctx.sub("Reef"), Vector3.new(rng:NextNumber(c.x0 + 1, c.x1 - 1), L.yb + 0.3, side * (below.f + (L.f - below.f) / 2)), rng:NextNumber(0.6, 1), rng:NextInteger(1, 3))
			end
		end
		if rng:NextNumber() < 0.4 then
			local top = c.layers[#c.layers]
			ctx.strand(ctx.sub("Weed"), Vector3.new(rng:NextNumber(c.x0 + 0.8, c.x1 - 0.8), c.top + 0.6, side * (c.lastFront - 0.4)), math.min(c.top - top.yb + 2, rng:NextNumber(4, 11)), WEED, KELP[3])
		end
		if rng:NextNumber() < 0.12 then
			local L = c.layers[rng:NextInteger(1, #c.layers)]
			local ax, ay = rng:NextNumber(c.x0 + 1, c.x1 - 1), rng:NextNumber(L.yb + 1, math.max(L.yb + 1.1, L.yt - 1.5))
			for k = 0, 2 do
				K.box(ctx.sub("Weed"), "Anemone", ax + k * 0.9 - 0.3, ax + k * 0.9 + 0.3, ay, ay + rng:NextNumber(0.8, 1.6), side * (L.f - 0.5), side * (L.f + 0.1), k % 2 == 0 and CYAN or hex("FF7ACB"), { neon = true, solid = false, shadow = false })
			end
		end
	end

	---------------------------------------------------------------- features
	function th.features(ctx)
		local scatter, life = ctx.sub("Scatter"), ctx.sub("Life")
		whale(ctx.sub("Whale"))
		whaleSkull(ctx.sub("Whale"), CFrame.lookAt(Vector3.new(1097, -0.6, -92), Vector3.new(1092, -0.6, 0)))
		local wm = shipwreck(ctx.sub("Wreck"), WRECK, math.rad(-8))
		-- the treasure spilled beside it
		local tc = Vector3.new(1241, 0, 58)
		local chest = K.model(wm, "Treasure")
		K.box(chest, "Chest", tc.X - 2, tc.X + 2, 0, 2.4, tc.Z - 1.4, tc.Z + 1.4, TIMBERS[3], { studs = K.SIDES, solid = false })
		K.box(chest, "ChestBand", tc.X - 2.1, tc.X + 2.1, 1.6, 2, tc.Z - 1.5, tc.Z + 1.5, GOLD, { solid = false })
		K.part(chest, "Lid", Vector3.new(4.2, 0.6, 3), CFrame.new(tc.X, 3.2, tc.Z + 1.6) * CFrame.Angles(math.rad(-65), 0, 0), TIMBERS[2], { solid = false })
		local coin
		for _ = 1, 9 do
			local q = tc + Vector3.new(rng:NextNumber(-3.4, 3.4), 0, rng:NextNumber(-3.6, 1))
			coin = K.box(chest, "Coin", q.X - 0.45, q.X + 0.45, 0, rng:NextNumber(0.2, 0.9), q.Z - 0.45, q.Z + 0.45, GOLD, { neon = true, solid = false, shadow = false })
		end
		K.box(chest, "Gold", tc.X - 1.7, tc.X + 1.7, 2, 2.6, tc.Z - 1.1, tc.Z + 1.1, GOLD, { neon = true, solid = false, shadow = false })
		ctx.light(coin, GOLD, 14, 1.2)

		-- kelp forests along the margins and up on the heights
		local nKelp = 0
		for _, side in { 1, -1 } do
			local x = XA + 14
			while x < XB - 10 do
				local e = ctx.edge[side](x)
				if not (side > 0 and nearWreck(x, 80)) and not (x > 1084 and x < 1112 and side < 0) then
					for _ = 1, rng:NextInteger(1, 3) do
						local kx, kz = x + rng:NextNumber(-4, 4), side * (e - rng:NextNumber(2, 8))
						if ctx.pathGap(kx, kz) > 3 and ctx.liquidGap(kx, kz) > 1 then
							kelp(life, Vector3.new(kx, 0, kz), rng:NextNumber(12, 30))
							nKelp += 1
						end
					end
				end
				x += rng:NextNumber(9, 15)
			end
		end
		for _, t in ctx.tops do
			if t.z1 > t.z0 and rng:NextNumber() < (t.big and 0.45 or 0.3) then
				local at = Vector3.new(t.x + rng:NextNumber(-3, 3), t.y - 0.3, t.side * rng:NextNumber(t.z0, t.z1))
				if rng:NextNumber() < 0.55 then
					kelp(life, at, t.big and rng:NextNumber(20, 36) or rng:NextNumber(10, 20))
				else
					coral(life, at, t.big and rng:NextNumber(1.6, 2.4) or rng:NextNumber(1.1, 1.6))
				end
				nKelp += 1
			end
		end
		table.insert(ctx.report, nKelp .. " kelp / coral on the heights")

		-- reefs, vents, boulders on the floor
		local function spot(margin, nestR)
			for _ = 1, 40 do
				local x, z = rng:NextNumber(XA + 6, XB - 6), rng:NextNumber(-90, 90)
				if ctx.inside(x, z, margin) and ctx.pathGap(x, z) > 2.5 and ctx.liquidGap(x, z) > 2 and not ctx.nearNest(x, z, nestR or 22) and not nearWreck(x, z, 4) then
					return x, z
				end
			end
		end
		for i = 1, 26 do
			local x, z = spot(2)
			if x then
				local reef = K.model(scatter, "Reef")
				for _ = 1, rng:NextInteger(2, 4) do
					coral(reef, Vector3.new(x + rng:NextNumber(-3, 3), 0, z + rng:NextNumber(-3, 3)), rng:NextNumber(0.8, 1.5))
				end
			end
			if i <= 9 then
				x, z = spot(4)
				if x then
					vent(scatter, Vector3.new(x, 0, z))
				end
			end
			if i <= 10 then
				x, z = spot(4)
				if x then
					local r = rng:NextNumber(1.4, 3)
					local bm = T.boulder(scatter, Vector3.new(x, 0, z), r, ctx.rockAt, rng, { solid = r > 2.2 })
					barnacles(bm, Vector3.new(x, r * 1.2, z), 3, r * 0.6)
				end
			end
			if i <= 7 then
				x, z = spot(3)
				if x then
					local sh = K.model(scatter, "Shell")
					local yaw = rng:NextNumber(0, math.pi * 2)
					clam(sh, Vector3.new(x, 0, z), Vector3.new(math.cos(yaw), 0, math.sin(yaw)), rng:NextNumber(0.25, 0.4), math.rad(rng:NextNumber(10, 40)))
				end
			end
		end
		-- starfish and urchins
		for _ = 1, 12 do
			local x, z = spot(1, 18)
			if x then
				local yaw = rng:NextNumber(0, math.pi)
				if rng:NextNumber() < 0.6 then
					local c = ({ hex("FF7A4A"), hex("E0609A"), hex("FFC94A") })[rng:NextInteger(1, 3)]
					for k = 0, 4 do
						local a = yaw + k / 5 * math.pi * 2
						K.part(scatter, "StarArm", Vector3.new(0.7, 0.3, 1.8), CFrame.new(x + math.cos(a) * 0.8, 0.15, z + math.sin(a) * 0.8) * CFrame.Angles(0, -a + math.pi / 2, 0), c, { solid = false, shadow = false })
					end
				else
					K.box(scatter, "Urchin", x - 0.8, x + 0.8, 0, 1.2, z - 0.8, z + 0.8, hex("2A1F3D"), { solid = false })
					for k = 0, 3 do
						local a = yaw + k / 4 * math.pi * 2
						K.part(scatter, "Spine", Vector3.new(0.2, 0.2, 3), CFrame.new(x, 0.7, z) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(25), 0, 0), hex("4A3A6A"), { solid = false, shadow = false })
					end
				end
			end
		end

		-- jellyfish lanterns drifting over the lane
		local sky = ctx.sub("Jellyfish")
		local nJ = 0
		for _ = 1, 40 do
			if nJ >= 13 then
				break
			end
			local x, z = rng:NextNumber(XA + 14, XB - 10), rng:NextNumber(-60, 60)
			local y = rng:NextNumber(14, 42)
			if not (x > RIB0 - 6 and x < RIB1 + 6 and y > 26 and math.abs(z) < 30) then
				jelly(sky, Vector3.new(x, y, z), rng:NextNumber(1.8, 3.6), JELLY[rng:NextInteger(1, #JELLY)])
				nJ += 1
			end
		end
		-- light falling in slanting shafts from far above
		for _ = 1, 7 do
			local x, z = rng:NextNumber(XA + 20, XB - 20), rng:NextNumber(-50, 50)
			local len = 150
			local dir = Vector3.new(0.35, 1, 0.18).Unit
			local c = Vector3.new(x, 0, z) + dir * len / 2
			K.part(sky, "LightShaft", Vector3.new(rng:NextNumber(4, 8), len, rng:NextNumber(2, 3.5)), CFrame.lookAt(c, c + dir) * CFrame.Angles(math.rad(90), 0, 0), hex("CFF8FF"), { neon = true, transparency = 0.93, solid = false, shadow = false })
		end
	end

	---------------------------------------------------------------- the nest: a giant open clam among drowned columns
	function th.nest(ctx, art, c)
		local base = Vector3.new(c.X, 0, c.Z)
		-- the lower shell as a ring of ribs round the eggs, the upper raised behind them (north)
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			K.part(art, "ShellRim", Vector3.new(1.4, 1, 4.6), CFrame.new(c.X + math.cos(a) * 7, 0.45, c.Z + math.sin(a) * 7) * CFrame.Angles(0, -a, 0), k % 2 == 0 and hex("F2D8DE") or hex("E6B8C6"), { studs = K.TOP, solid = false })
		end
		ctx.octagon(art, "ShellBed", base, 6.6, -0.05, 0.25, hex("F7E8EC"), { studs = K.TOP, solid = false })
		clam(art, base + Vector3.new(0, 0, 8.5), Vector3.new(0, 0, -1), 1.3, math.rad(62))
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2 + 0.3
			local px, pz = c.X + math.cos(a) * 9.6, c.Z + math.sin(a) * 9.6
			K.box(art, "Pearl", px - 0.55, px + 0.55, 0, 1.1, pz - 0.55, pz + 0.55, hex("EFFFFF"), { neon = true, solid = false, shadow = false })
		end
		ctx.light(ctx.anchor(art, Vector3.new(c.X, 3, c.Z)), CYAN, 16, 0.9)
		-- the drowned temple round it: marble columns (some broken), a statue's head, the mosaic floor (ground)
		local cy = ctx.sub("Ruins")
		local heights = { 16, 7, 13, 5, 18, 10 }
		for k, deg in { 60, 90, 120, 240, 270, 300 } do
			local a = math.rad(deg)
			local px, pz = NX + math.cos(a) * 15.6, math.sin(a) * 15.6
			local h = heights[k]
			K.box(cy, "ColumnBase", px - 2, px + 2, 0, 1.2, pz - 2, pz + 2, MARBLE[2], { studs = K.ALL, solid = false })
			for _, rot in { 0, 45 } do
				K.part(cy, "Column", Vector3.new(2.6, h, 2.6), CFrame.new(px, 1.2 + h / 2, pz) * CFrame.Angles(0, math.rad(rot), 0), MARBLE[rot == 0 and 1 or 3], { solid = false })
			end
			if h >= 13 then
				K.box(cy, "Capital", px - 2.1, px + 2.1, 1.2 + h, 2.6 + h, pz - 2.1, pz + 2.1, MARBLE[2], { studs = K.ALL, solid = false })
				coral(cy, Vector3.new(px, 2.6 + h, pz), 0.7, rng:NextInteger(1, 3))
			else
				barnacles(cy, Vector3.new(px, 1.2 + h, pz), 3, 1)
				local ra = a + rng:NextNumber(-0.5, 0.5)
				K.part(cy, "Drum", Vector3.new(2.6, 2.6, 5), CFrame.new(px + math.cos(ra) * 4.2, 1.1, pz + math.sin(ra) * 4.2) * CFrame.Angles(0, -ra + math.pi / 2, math.rad(rng:NextNumber(-10, 10))), MARBLE[1], { studs = K.SIDES, solid = false })
			end
			if k % 2 == 1 then
				C.strand(cy, Vector3.new(px + 1.4, 1 + h, pz), h * 0.5, WEED, KELP[3], 0.5)
			end
		end
		-- a statue's head, toppled, half in the sand south-west of the clam
		local hp = Vector3.new(NX - 22, 0, -30)
		K.part(cy, "StatueHead", Vector3.new(6, 7, 6), CFrame.new(hp + Vector3.new(0, 2.6, 0)) * CFrame.Angles(math.rad(12), math.rad(30), math.rad(-20)), MARBLE[2], { studs = K.SIDES, solid = false })
		K.part(cy, "StatueCrown", Vector3.new(6.6, 1.6, 6.6), CFrame.new(hp + Vector3.new(0, 2.6, 0)) * CFrame.Angles(math.rad(12), math.rad(30), math.rad(-20)) * CFrame.new(0, 3.8, 0), hex("6FBFBF"), { solid = false })
		barnacles(cy, hp + Vector3.new(1, 4, 1), 4, 2)
	end

	---------------------------------------------------------------- the Coral Gate
	function th.gate(ctx, g)
		local gx = XA
		for _, s in { -1, 1 } do
			local y, i = -2, 0
			local prevHw
			while y < 56 do
				local lh = rng:NextInteger(7, 11)
				local hw = 13.5 - i * 0.9 + rng:NextNumber(-0.8, 0.8)
				local zin = 59 + rng:NextNumber(-0.5, 1.5) + i * 0.3
				local mid = y + lh / 2
				K.box(g, "Pillar", gx - hw, gx + hw, y, y + lh, s * zin, s * (zin + 32 - i), ctx.rockAt(Vector3.new(gx, mid, s * 70), mid / 90), { studs = K.SIDES })
				-- coral on the ledge where the block above steps in
				if prevHw and prevHw - hw > 0.6 then
					for _, fx in { -1, 1 } do
						if rng:NextNumber() < 0.7 then
							coral(g, Vector3.new(gx + fx * (hw + (prevHw - hw) / 2), y + 0.1, s * rng:NextNumber(zin + 3, zin + 18)), rng:NextNumber(0.8, 1.3))
						end
					end
				end
				prevHw = hw
				y += lh
				i += 1
			end
			barnacles(g, Vector3.new(gx - 12, 20, s * 64), 6, 4)
			for _ = 1, 3 do
				ctx.strand(g, Vector3.new(gx + (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(10, 12.5), rng:NextNumber(30, 54), s * rng:NextNumber(60, 64)), rng:NextNumber(4, 10), WEED, KELP[3])
			end
		end
		-- the arch: rock blocks on an arc from pillar to pillar, crusted with coral, weed hanging under it
		local R, cy = 64, 30
		local pts = {}
		for a = 18, 162, 9 do
			local r = math.rad(a)
			table.insert(pts, Vector3.new(gx, cy + R * math.sin(r), R * math.cos(r)))
		end
		local tones = {}
		for k = 1, #pts - 1 do
			tones[k] = ctx.rockAt(pts[k], 0.3 + 0.4 * (k % 3) / 2)
		end
		local widths = {}
		for k = 1, #pts - 1 do
			widths[k] = 11 - math.sin(math.pi * (k - 0.5) / (#pts - 1)) * 2
		end
		for k = 1, #pts - 1 do
			T.chain(g, "Arch", { pts[k], pts[k + 1] }, { widths[k] }, { tones[k] }, { studs = K.SIDES, solid = false })
		end
		for k = 2, #pts - 1, 2 do
			local p = pts[k]
			local up = (p - Vector3.new(gx, cy, 0)).Unit
			if math.abs(p.Z) > 10 then
				coral(g, p + up * 4.6, rng:NextNumber(1.1, 1.6), rng:NextInteger(1, 3))
			end
			ctx.strand(g, p - up * 5.2, rng:NextNumber(3, 9), WEED, KELP[3])
		end
		-- the clam on the keystone, its pearl glowing
		clam(g, Vector3.new(gx + 3, cy + R + 4.6, 0), Vector3.new(-1, 0, 0), 1.25, math.rad(52), { pearl = true })
		-- the name, hanging on chains under the keystone
		local py = 79
		ctx.plaque(g, CFrame.lookAt(Vector3.new(gx - 1, py, 0), Vector3.new(gx - 30, py, 0)), 46, 7, "SUNKEN ABYSS", { board = hex("10283A"), frame = BONE[1], line = CYAN, text = hex("CFFBFF"), neon = true })
		for _, cz in { -18, 18 } do
			local y = py + 4.3
			local k = 0
			while y < cy + R - 4.5 do
				if k % 2 == 0 then
					K.box(g, "ChainLink", gx - 1.3, gx - 0.7, y, y + 1.4, cz - 0.5, cz + 0.5, P.IronLight, { solid = false })
				else
					K.box(g, "ChainLink", gx - 1.5, gx - 0.5, y, y + 1.4, cz - 0.15, cz + 0.15, P.Iron, { solid = false })
				end
				y += 1.2
				k += 1
			end
		end
		-- an old anchor dropped against the south pillar, chain trailing
		local an = K.model(g, "Anchor")
		local A = CFrame.new(gx - 15, 9, -62) * CFrame.Angles(0, 0, math.rad(-14))
		K.part(an, "Shank", Vector3.new(1.6, 16, 1.6), A, P.Iron, { studs = K.SIDES, solid = false })
		K.part(an, "Stock", Vector3.new(1.2, 1.2, 9), A * CFrame.new(0, 7, 0), P.IronLight, { solid = false })
		K.part(an, "Ring", Vector3.new(0.6, 2.4, 2.4), A * CFrame.new(0, 9, 0), P.IronLight, { solid = false })
		for _, sz in { -1, 1 } do
			K.part(an, "Arm", Vector3.new(1.4, 7, 1.4), A * CFrame.new(0, -6.2, sz * 2.6) * CFrame.Angles(math.rad(sz * 50), 0, 0), P.Iron, { solid = false })
			K.part(an, "Fluke", Vector3.new(1.2, 2.6, 3), A * CFrame.new(0, -4.4, sz * 5) * CFrame.Angles(math.rad(sz * 50), 0, 0), P.IronLight, { solid = false })
		end
		barnacles(an, (A * CFrame.new(0, -2, 0)).Position, 4, 1.4)
	end

	return require(script.Parent.NewBiome)(b, K, T, th)
end
