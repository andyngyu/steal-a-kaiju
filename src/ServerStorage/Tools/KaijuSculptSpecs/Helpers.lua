-- Shared building blocks for the sculpted kaiju specs (see Tools.KaijuSculpt for the K API). Build space: feet on
-- y = 0, facing -Z, +X = the kaiju's left. The body plans use these palette keys: Hide, HideDark, HideLight, Back,
-- Belly, Belly2, Claw, ClawTip, Tooth, Mouth, Eye, Socket (species add their own for armour, crystals, glow).
local H = {}

local rad = math.rad

-- skin by angle round a tube (0 = top) and ring: dark stripe down the spine, dark bands down the flanks every `every`
-- rings, plain flanks, lighter lower flanks
function H.skin(opts)
	opts = opts or {}
	local stripe, band, flank, every = opts.stripe or 44, opts.band or 84, opts.flank or 104, opts.every or 3
	local back, hide, light, bandKey = opts.back or "Back", opts.hide or "Hide", opts.light or "HideLight", opts.bandKey or opts.back or "Back"
	return function(th, ring)
		local a = math.deg(math.abs(th))
		if a < stripe then
			return back
		elseif a < band then
			return ring % every == 0 and bandKey or hide
		elseif a < flank then
			return hide
		end
		return light
	end
end

function H.plates(w, n, t)
	return { w = w, n = n, t = t or 0.13, lift = 8, jitter = 1, sink = 0.5, overlap = 1.12 }
end

-- shaggy fur: long tiles hanging back along the tube, lifted and tousled
function H.fur(w, n, l, lift)
	return { w = w, n = n, l = l, t = 0.11, lift = lift or 18, jitter = 5, sink = 0.4, overlap = 1.22 }
end

-- half-buried stones (or any keys) in rows along a tube at the given angles
function H.studs(K, group, samples, thetas, every, size, from, to, keys)
	keys = keys or { "Rock", "Rock", "RockLight" }
	local s, k = from, 0
	while s <= to + 1e-3 do
		local smp = K:at(samples, s)
		for idx, th0 in thetas do
			local pos, nrm = K:surface(smp, th0 + rad(K:rand(-6, 6)), 0.02)
			local along = (smp.T - nrm * smp.T:Dot(nrm)).Unit
			local r = size * K:rand(0.8, 1.15) * math.sqrt(smp.rx / 0.9)
			local cf = CFrame.fromMatrix(pos, nrm:Cross(along), nrm) * CFrame.Angles(rad(K:rand(-20, 20)), rad(K:rand(0, 90)), rad(K:rand(-20, 20)))
			K:block(group, keys[(k + idx) % #keys + 1], cf, Vector3.new(r, r * 0.7, r))
		end
		s += every
		k += 1
	end
end

-- plates down one side of a limb tube (theta 0 = the front for limbs built with ref = X)
function H.scutes(K, group, samples, from, to, count, w, l, key, theta)
	for i = 0, count - 1 do
		local smp = K:at(samples, from + (to - from) * (count > 1 and i / (count - 1) or 0))
		K:tile(group, key, smp, theta or 0, w * (1 - 0.12 * i), l, 0.1, 10, 2, 0.35)
	end
end

-- a limb as straight tubes between joint points (crisp elbows and knees): pts = { { x, y, z, r }, ... };
-- opts: core (key), cores (per segment), tiles (per segment), color, step, ref
function H.limb(K, group, pts, opts)
	opts = opts or {}
	local out = {}
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		out[i] = K:tube(group, {
			{ a[1], a[2], a[3], rx = a[4], ru = a[5] or a[4], rd = a[5] or a[4] },
			{ b[1], b[2], b[3], rx = b[4], ru = b[5] or b[4], rd = b[5] or b[4] },
		}, {
			step = opts.step or 0.32,
			ref = opts.ref or Vector3.xAxis,
			core = (opts.cores and opts.cores[i]) or opts.core or "Hide",
			coreScale = opts.coreScale or 0.98,
			tile = opts.tiles and opts.tiles[i] or nil,
			color = opts.color,
		})
	end
	return out
end

-- a cube turned so one corner points along d with its tip at `tip`: a faceted point (crystal tips, horn points)
local CORNER = CFrame.fromAxisAngle(Vector3.new(-1, 1, 0).Unit, math.acos(-1 / math.sqrt(3)))
function H.point(K, group, key, tip, d, s)
	d = d.Unit
	local centre = tip - d * s * math.sqrt(3) / 2
	return K:block(group, key, CFrame.lookAt(centre, centre + d) * CORNER, Vector3.new(s, s, s))
end

-- a fan of hooked claws side by side across `side`, pointing along `fwd`, curling down.
-- opts: n, spread (studs between outer claws), fan (degrees), droop, len, w, curl (degrees), keys
function H.claws(K, group, base, fwd, side, opts)
	fwd, side = fwd.Unit, side.Unit
	local down = fwd:Cross(side).Unit
	local n = opts.n or 3
	for i = 1, n do
		local f = n > 1 and (i - 1) / (n - 1) - 0.5 or 0
		local d = (CFrame.fromAxisAngle(down, rad(f * (opts.fan or 30))) * fwd)
		d = (d + down * (opts.droop or 0.3)).Unit
		local w = opts.w or 0.07
		K:chain(group, opts.keys or { "Claw", "Claw", "ClawTip" }, base + side * f * (opts.spread or 0.16), d, down:Cross(d), { n = 3, len = opts.len or 0.34, w0 = w, w1 = w * 0.65, bend = -(opts.curl or 26) })
	end
end

-- a narrow glowing slit in a dark socket; cf faces out of the face (its -Z), local X along the slit
function H.eye(K, group, cf, w, h, eyeKey, socketKey)
	K:block(group, socketKey or "Socket", cf, Vector3.new(w * 1.35, h * 2.2, 0.06))
	K:block(group, eyeKey or "Eye", cf * CFrame.new(0, 0, -0.03), Vector3.new(w, h, 0.04))
end

-- n teeth from p0 to p1 pointing along dir, flat across `across`; alternate teeth a little shorter
function H.teeth(K, group, key, p0, p1, n, dir, across, h, thick)
	for i = 0, n - 1 do
		local p = p0:Lerp(p1, n > 1 and i / (n - 1) or 0)
		K:spike(group, key or "Tooth", p, dir, across, i % 2 == 0 and h or h * 0.78, thick or 0.05)
	end
end

-- a crystal cluster: `count` faceted shards (square shafts turned 45 degrees, pointed tips) fanning out from base
-- around `normal`; the first shard is the tallest and straightest
function H.crystal(K, group, keys, base, normal, size, count, spread)
	normal = normal.Unit
	local a = math.abs(normal.Y) < 0.9 and normal:Cross(Vector3.yAxis).Unit or Vector3.xAxis
	local b = normal:Cross(a).Unit
	local turn = K:rand(0, math.pi * 2)
	for i = 1, count do
		local ang = turn + (i - 1) / math.max(count - 1, 1) * math.pi * 2 + K:rand(-0.3, 0.3)
		local radial = a * math.cos(ang) + b * math.sin(ang)
		local tilt = i == 1 and rad(K:rand(0, 8)) or rad((spread or 30) * K:rand(0.7, 1.15))
		local d = (normal * math.cos(tilt) + radial * math.sin(tilt)).Unit
		local h = size * (i == 1 and 1 or K:rand(0.45, 0.75))
		local w = math.max(h * 0.28, 0.06)
		local p = base + (i == 1 and Vector3.zero or radial * size * 0.16)
		local key = keys[(i - 1) % #keys + 1]
		local X = (radial - d * radial:Dot(d))
		X = X.Magnitude > 1e-3 and X.Unit or a
		K:block(group, key, CFrame.fromMatrix(p + d * h * 0.36, X, d) * CFrame.Angles(0, rad(45), 0), Vector3.new(w, h * 0.72, w))
		H.point(K, group, key, p + d * h, d, w * 0.92)
	end
end

-- crystal clusters along a tube's top (and optionally its flanks): opts.from / to / every / size(u) / count / keys /
-- thetas (angles round the tube; default just the top) / lean (degrees back)
function H.crystalRidge(K, group, samples, opts)
	local from, to = opts.from or 0, opts.to or samples.total
	local n = math.max(0, math.floor((to - from) / opts.every + 0.5))
	for k = 0, n do
		local u = n > 0 and k / n or 0
		local smp = K:at(samples, from + (to - from) * u)
		local size = type(opts.size) == "function" and opts.size(u) or opts.size
		for _, th in opts.thetas or { 0 } do
			local pos, nrm = K:surface(smp, th, size * 0.12)
			local lean = rad(opts.lean or 18)
			local dir = (nrm * math.cos(lean) + smp.T * math.sin(lean)).Unit
			H.crystal(K, group, opts.keys, pos, dir, th == 0 and size or size * (opts.sideScale or 0.6), th == 0 and (opts.count or 4) or math.max(2, (opts.count or 4) - 2), opts.spread)
		end
	end
end

-- a licking flame: blocks bending side to side up from base, dark at the root and hot at the tip (neon keys)
function H.flame(K, group, keys, base, dir, side, h, w, wiggle)
	local n = #keys
	local seg = h / n
	local p, d = base, dir.Unit
	for i = 1, n do
		local f = (i - 1) / n
		local ww = w * (1 - f * 0.6)
		local X = (side - d * side:Dot(d)).Unit
		if i == n then
			H.point(K, group, keys[i], p + d * seg * 1.1, d, ww * 0.95)
		else
			K:block(group, keys[i], CFrame.fromMatrix(p + d * seg / 2, X, d) * CFrame.Angles(0, rad(45), 0), Vector3.new(ww, seg * 1.15, ww))
			p += d * seg
		end
		d = (CFrame.fromAxisAngle(X:Cross(d), rad((i % 2 == 0 and 1 or -1) * (wiggle or 22))) * d).Unit
	end
end

-- ------------------------------------------------------------------------------------------------------------------
-- Rex body plan (Biped): a heavy tyrant lizard. Big head on a short thick neck, deep chest, huge thighs, little
-- two-clawed arms, long thick tail sweeping to its right. Groups / joints match H.REX_JOINTS. P (all optional):
--   tiles = { torso, neck, tail } (tile tables), belly = belly table, color = skin fn, core = core key,
--   crest(K, torso, neck, tail) for the spine, head(K, hcf, hp, hv) for horns / extras on the head,
--   jawExtra(K, jcf), extras(K, parts) for everything else (parts = { torso, neck, tail, thighs = { L, R } }),
--   thighArmour (key), brow (key), mouthGlow (key for the palate / tongue), legCore / footCore (keys), tailTip (keys)
H.REX_HEAD = CFrame.new(0, 3.66, -1.5) * CFrame.Angles(rad(-8), 0, 0)
H.REX_HINGE = Vector3.new(0, -0.16, -0.2)
H.REX_JOINTS = {
	Head = { 0, 3.22, -0.78 },
	Jaw = H.REX_HEAD * H.REX_HINGE,
	LegL = { 0.86, 2.7, 0.5 },
	LegR = { -0.86, 2.7, 0.5 },
	ArmL = { 0.78, 2.95, -1.12 },
	ArmR = { -0.78, 2.95, -1.12 },
	Tail = { 0, 2.8, 1.1 },
}

function H.rex(K, P)
	P = P or {}
	local tiles = P.tiles or {}
	local belly = P.belly or { key = "Belly", key2 = "Belly2", arc = 48, t = 0.14, wide = 1.15 }
	local color = P.color or H.skin()
	local core = P.core or "Hide"
	local torso = K:tube("Body", {
		{ 0, 3.12, -0.82, rx = 0.92, ru = 0.86, rd = 1.0 },
		{ 0, 2.96, -0.24, rx = 1.08, ru = 0.94, rd = 1.12 },
		{ 0, 2.82, 0.36, rx = 1.04, ru = 0.9, rd = 0.98 },
		{ 0, 2.76, 0.86, rx = 0.94, ru = 0.82, rd = 0.8 },
		{ 0, 2.74, 1.22, rx = 0.78, ru = 0.7, rd = 0.62 },
	}, { step = 0.44, core = core, coreCap = P.coreCap, coreScale = P.coreScale or 0.9, tile = tiles.torso or H.plates(0.74), belly = belly, color = color })
	local neck = K:tube("Head", {
		{ 0, 3.6, -1.48, rx = 0.6, ru = 0.58, rd = 0.66 },
		{ 0, 3.48, -1.16, rx = 0.7, ru = 0.66, rd = 0.76 },
		{ 0, 3.22, -0.76, rx = 0.84, ru = 0.8, rd = 0.9 },
	}, { step = 0.36, core = core, coreCap = P.coreCap, coreScale = P.coreScale or 0.9, tile = tiles.neck or H.plates(0.66), belly = belly, color = color })
	local tail = K:tube("Tail", {
		{ 0, 2.8, 1.1, rx = 0.76, ru = 0.7, rd = 0.64 },
		{ -0.04, 2.7, 1.72, rx = 0.58, ru = 0.54, rd = 0.48 },
		{ -0.3, 2.42, 2.26, rx = 0.42, ru = 0.39, rd = 0.35 },
		{ -0.78, 2.14, 2.64, rx = 0.28, ru = 0.26, rd = 0.24 },
		{ -1.3, 1.94, 2.86, rx = 0.17, ru = 0.16, rd = 0.15 },
		{ -1.8, 1.88, 2.92, rx = 0.09, ru = 0.09, rd = 0.08 },
	}, { step = 0.38, core = core, coreCap = P.coreCap, coreScale = P.coreScale or 0.9, tile = tiles.tail or H.plates(0.56, 5), belly = { key = belly.key, key2 = belly.key2, arc = 46, t = 0.12, wide = 1.15 }, color = color, trim = 0.14 })
	local thighs = {}
	for _, x in { 1, -1 } do
		local g = x == 1 and "LegL" or "LegR"
		local dz = x == 1 and -0.14 or 0.18 -- the left foot a little ahead
		local leg = H.limb(K, g, {
			{ 0.86 * x, 2.82, 0.5, 0.68, 0.74 },
			{ 1.08 * x, 2.1, 0.22 + dz * 0.4, 0.6, 0.64 },
			{ 1.14 * x, 1.6, 0.0 + dz * 0.7, 0.44, 0.46 },
			{ 1.14 * x, 0.66, 0.54 + dz, 0.27 },
			{ 1.14 * x, 0.2, 0.16 + dz, 0.22 },
		}, { step = 0.34, cores = { P.legCore or "Hide", P.legCore or "Hide", P.legCore or "Hide", P.footCore or "HideDark" } })
		thighs[g .. "Shin"] = leg[3]
		thighs[g] = leg[1]
		K:tile(g, "HideDark", K:at(leg[1], leg[1].total * 0.5), rad(25) * x, 0.8, 0.8, 0.14, 8, 2, 0.4)
		K:tile(g, "Hide", K:at(leg[2], leg[2].total * 0.5), rad(-10) * x, 0.62, 0.56, 0.13, 8, 2, 0.4)
		K:tile(g, P.thighArmour or "Armour", K:at(leg[1], leg[1].total * 0.42), rad(95) * x, 0.78, 0.72, 0.15, 4, 2, 0.45)
		H.scutes(K, g, leg[3], 0.2, leg[3].total - 0.14, 3, 0.4, 0.36, "HideDark")
		local fz = dz - 0.04
		K:block(g, P.footCore or "HideDark", CFrame.new(1.14 * x, 0.15, fz - 0.06) * CFrame.Angles(0, rad(-6 * x), 0), Vector3.new(0.64, 0.3, 0.74))
		for t = -1, 1 do
			local dirT = CFrame.Angles(0, rad(t * 20 - 6 * x), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
			local base = Vector3.new(1.14 * x + t * 0.2, 0.12, fz - 0.34)
			K:block(g, "Hide", CFrame.lookAt(base + dirT * 0.17, base + dirT * 2), Vector3.new(0.19, 0.2, 0.4))
			K:chain(g, { "Claw", "Claw", "ClawTip" }, base + dirT * 0.36 + Vector3.new(0, 0.03, 0), (dirT - Vector3.new(0, 0.25, 0)).Unit, dirT:Cross(Vector3.yAxis), { n = 3, len = 0.34, w0 = 0.1, w1 = 0.06, bend = -28 })
		end
		-- small but wicked arms, two hooked claws
		local ga = x == 1 and "ArmL" or "ArmR"
		H.limb(K, ga, {
			{ 0.78 * x, 2.98, -1.12, 0.24 },
			{ 0.94 * x, 2.6, -1.34, 0.18 },
			{ 0.88 * x, 2.5, -1.64, 0.14 },
		}, { step = 0.22 })
		K:block(ga, "Hide", CFrame.lookAt(Vector3.new(0.88 * x, 2.48, -1.66), Vector3.new(0.88 * x, 2.4, -2.4)), Vector3.new(0.2, 0.14, 0.2))
		H.claws(K, ga, Vector3.new(0.88 * x, 2.46, -1.74), Vector3.new(0, -0.2, -1), Vector3.xAxis, { n = 2, spread = 0.1, fan = 20, len = 0.26, w = 0.06, curl = 30 })
	end

	-- head (head space: origin at the back of the skull, facing -Z, glaring down a little)
	local HEAD = H.REX_HEAD
	local function hcf(px, py, pz, ax, ay, az)
		return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
	end
	local function hp(px, py, pz)
		return HEAD * Vector3.new(px, py, pz)
	end
	local function hv(px, py, pz)
		return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
	end
	K:block("Head", "Hide", hcf(0, 0.22, -0.38), Vector3.new(1.02, 0.72, 0.84))
	K:block("Head", "Hide", hcf(0, 0.12, -1.08), Vector3.new(0.84, 0.52, 0.8))
	K:block("Head", "Hide", hcf(0, 0.07, -1.62, -4, 0, 0), Vector3.new(0.7, 0.44, 0.42))
	K:block("Head", P.mouthGlow or "Mouth", hcf(0, -0.16, -1.05), Vector3.new(0.74, 0.06, 1.3))
	for i, z in { -0.1, -0.44, -0.8, -1.12, -1.44, -1.7 } do
		local w = ({ 0.8, 0.84, 0.46, 0.42, 0.38, 0.32 })[i]
		local y = z > -0.74 and 0.58 or (z > -1.4 and 0.38 or 0.29)
		K:block("Head", "Back", hcf(0, y, z, -10 + K:rand(-3, 3), K:rand(-3, 3), 0), Vector3.new(w, 0.09, 0.36))
	end
	for _, x in { 1, -1 } do
		K:block("Head", "Hide", hcf(0.5 * x, 0.0, -0.34, 0, -10 * x, 6 * x), Vector3.new(0.34, 0.62, 0.76))
		K:block("Head", "HideDark", hcf(0.26 * x, 0.36, -1.06, -2, 0, -30 * x), Vector3.new(0.26, 0.12, 0.74))
		K:block("Head", "HideDark", hcf(0.21 * x, 0.27, -1.6, -6, 0, -30 * x), Vector3.new(0.22, 0.1, 0.42))
		K:block("Head", P.brow or "Armour", hcf(0.31 * x, 0.6, -0.74, -8, -12 * x, 15 * x), Vector3.new(0.46, 0.2, 0.54))
		H.eye(K, "Head", hcf(0.47 * x, 0.38, -0.8, 0, -30 * x, 12 * x), 0.2, 0.06)
		K:spike("Head", "Armour", hp(0.6 * x, -0.04, -0.12), hv(0.6 * x, 0.1, 0.8), hv(0, 1, 0), 0.26, 0.09)
		K:spike("Head", "ArmourLight", hp(0.58 * x, 0.22, -0.02), hv(0.5 * x, 0.35, 0.8), hv(0, 1, 0), 0.2, 0.08)
		H.teeth(K, "Head", "Tooth", hp(0.38 * x, -0.17, -0.62), hp(0.3 * x, -0.15, -1.74), 8, hv(0, -1, 0.12), hv(1, 0, 0), 0.13, 0.07)
	end
	H.teeth(K, "Head", "Tooth", hp(-0.18, -0.15, -1.82), hp(0.18, -0.15, -1.82), 3, hv(0, -1, 0.1), hv(0, 0, 1), 0.1, 0.06)
	if P.head then
		P.head(K, hcf, hp, hv)
	end

	-- lower jaw, half open: big teeth up both sides, pale throat, tongue
	local JAW = HEAD * CFrame.new(H.REX_HINGE) * CFrame.Angles(rad(-16), 0, 0)
	local function jcf(px, py, pz, ax, ay, az)
		return JAW * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
	end
	K:block("Jaw", "Hide", jcf(0, -0.15, -0.8), Vector3.new(0.8, 0.3, 1.5))
	K:block("Jaw", "Hide", jcf(0, -0.13, -1.55), Vector3.new(0.62, 0.28, 0.3))
	K:block("Jaw", "Belly", jcf(0, -0.31, -0.75), Vector3.new(0.64, 0.06, 1.3))
	K:block("Jaw", P.mouthGlow or "Mouth", jcf(0, 0.01, -0.85), Vector3.new(0.6, 0.05, 1.2))
	for _, x in { 1, -1 } do
		H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.33 * x, 0, -0.55), JAW * Vector3.new(0.26 * x, 0, -1.56), 7, JAW:VectorToWorldSpace(Vector3.new(0, 1, -0.1)).Unit, JAW:VectorToWorldSpace(Vector3.xAxis), 0.1, 0.06)
		K:block("Jaw", "Armour", jcf(0.41 * x, -0.2, -0.42, K:rand(-20, 20), K:rand(0, 60), K:rand(-20, 20)), Vector3.new(0.16, 0.12, 0.16))
	end
	if P.jawExtra then
		P.jawExtra(K, jcf)
	end

	local parts = { torso = torso, neck = neck, tail = tail, thighs = thighs }
	if P.crest then
		P.crest(K, torso, neck, tail)
	end
	local tip = K:at(tail, tail.total)
	K:chain("Tail", P.tailTip or { "Armour", "ArmourLight" }, tip.p - tip.T * 0.14, tip.T, tip.U, { n = 2, len = 0.4, w0 = 0.15, w1 = 0.09, bend = 0 })
	if P.extras then
		P.extras(K, parts)
	end
	return parts
end

-- ------------------------------------------------------------------------------------------------------------------
-- Ape body plan (Knuckle): a hulking gorilla knuckle-walking forward. A broad shaggy mantle over the shoulders, huge
-- arms planted on the knuckles, short legs, a leathery chest, a low head with a crest, heavy brow, sunken glowing
-- eyes and bared fangs. Keys: Fur, FurDark, FurLight (fur shades), Skin, SkinDark (face, chest, hands), Armour,
-- ArmourLight, Tooth, Mouth, Eye, Socket, Claw, ClawTip. P (all optional):
--   back = key for the saddle down the spine (a silverback's grey), armour(K, parts) for shoulder / forearm armour,
--   head(K, hcf, hp, hv) for crest / horns, extras(K, parts), ears = true, tail = { keys } (a tail curling up),
--   furLift (degrees), crest = keys for the sagittal crest, core / coreScale / limbCore / overlap (a glowing core
--   showing between smaller fur plates: molten or charged beasts)
H.APE_HEAD = CFrame.new(0, 3.24, -1.14) * CFrame.Angles(rad(-4), 0, 0)
H.APE_HINGE = Vector3.new(0, -0.22, -0.18)
H.APE_JOINTS = {
	Head = { 0, 3.0, -0.72 },
	Jaw = H.APE_HEAD * H.APE_HINGE,
	ArmL = { 1.2, 3.02, -0.5 },
	ArmR = { -1.2, 3.02, -0.5 },
	LegL = { 0.62, 1.72, 0.58 },
	LegR = { -0.62, 1.72, 0.58 },
	EarL = H.APE_HEAD * Vector3.new(0.48, 0.16, -0.3),
	EarR = H.APE_HEAD * Vector3.new(-0.48, 0.16, -0.3),
	Tail = { 0, 1.8, 0.95 },
	Cloud = { 0, 4.5, 0.3 },
}

function H.ape(K, P)
	P = P or {}
	local lift = P.furLift or 14
	local back = P.back or "FurDark"
	local function furTile(w, n, l, lf)
		local t = H.fur(w, n, l, lf)
		t.overlap = P.overlap or t.overlap
		return t
	end
	-- fur shingles only over the back and outer arcs; the chest and belly stay bare leathery skin
	local function fur(th, ring)
		local a = math.deg(math.abs(th))
		if a < 38 then
			return back
		elseif a < 118 then
			return ring % 2 == 0 and "Fur" or "FurDark"
		end
		return nil
	end
	-- limbs (theta 0 = the front): a shaggy fringe down the back and outside, the front left smooth
	local function fringe(th, ring)
		local a = math.deg(math.abs(th))
		if a < 70 then
			return nil
		end
		return ring % 2 == 0 and "Fur" or "FurDark"
	end
	-- torso: a barrel leaning forward, shoulders high, hips low; a mantle of fur across the shoulders
	local torso = K:tube("Body", {
		{ 0, 3.08, -0.6, rx = 1.12, ru = 0.92, rd = 1.0 },
		{ 0, 2.74, -0.02, rx = 1.1, ru = 0.94, rd = 1.06 },
		{ 0, 2.22, 0.46, rx = 0.96, ru = 0.86, rd = 0.86 },
		{ 0, 1.8, 0.72, rx = 0.8, ru = 0.72, rd = 0.7 },
	}, { step = 0.42, core = P.core or "Fur", coreScale = P.coreScale or 0.96, tile = furTile(0.66, 7, 0.7, lift), color = fur })
	local mantle = K:tube("Body", {
		{ -1.0, 3.3, -0.46, rx = 0.56, ru = 0.6, rd = 0.5 },
		{ 0, 3.5, -0.4, rx = 0.66, ru = 0.66, rd = 0.56 },
		{ 1.0, 3.3, -0.46, rx = 0.56, ru = 0.6, rd = 0.5 },
	}, { step = 0.42, ref = Vector3.zAxis, core = P.core or "Fur", coreScale = P.coreScale or 0.96, tile = furTile(0.62, 6, 0.6, lift + 4), color = function(th, ring) local a = math.deg(math.abs(th)) return a > 130 and nil or (a < 50 and back or (ring % 2 == 0 and "Fur" or "FurDark")) end })
	-- bare chest: two heavy pecs and rows of abdominal plates on the front of the barrel
	for _, x in { 1, -1 } do
		K:tile("Body", "Skin", K:at(torso, 0.22), rad(180 - 34) * x, 0.86, 0.8, 0.16, 6, 2, 0.4)
	end
	for i, f in { 0.62, 0.98, 1.32 } do
		for _, x in { 1, -1 } do
			K:tile("Body", "SkinDark", K:at(torso, f), rad(180 - 14) * x, 0.5 - i * 0.04, 0.34, 0.12, 6, 2, 0.4)
		end
	end
	local parts = { torso = torso, mantle = mantle, arms = {}, legs = {} }
	for _, x in { 1, -1 } do
		-- arms: massive, planted on the knuckles a little ahead of the shoulders
		local ga = x == 1 and "ArmL" or "ArmR"
		local arm = H.limb(K, ga, {
			{ 1.2 * x, 3.1, -0.5, 0.58 },
			{ 1.56 * x, 1.86, -0.56, 0.48 },
			{ 1.46 * x, 0.72, -0.78, 0.42 },
		}, { step = 0.42, cores = { P.limbCore or "Fur", P.limbCore or "Fur" }, tiles = { furTile(0.6, 6, 0.62, lift), furTile(0.56, 6, 0.56, lift) }, color = fringe })
		parts.arms[ga] = arm
		-- a tuft hanging off the elbow
		local el = K:at(arm[1], arm[1].total)
		for k = 1, 3 do
			local pos, nrm = K:surface(el, rad(150 + k * 14) * x, 0.05)
			K:chain(ga, { "FurDark", "Fur" }, pos, (nrm + Vector3.new(0, -0.9, 0.4)).Unit, el.R, { n = 2, len = 0.42 - k * 0.06, w0 = 0.2, w1 = 0.12, bend = 0, tip = false, depth = 1.6 })
		end
		-- fist on its knuckles: leathery hand, thick fingers folded under
		K:block(ga, "Skin", CFrame.new(1.44 * x, 0.36, -0.82) * CFrame.Angles(0, rad(-8 * x), 0), Vector3.new(0.66, 0.6, 0.66))
		for f = -1.5, 1.5 do
			K:block(ga, "SkinDark", CFrame.new(1.44 * x + f * 0.15, 0.13, -1.06) * CFrame.Angles(rad(K:rand(-6, 6)), rad(-8 * x), 0), Vector3.new(0.14, 0.24, 0.26))
		end
		-- legs: short and bowed, flat leathery feet
		local g = x == 1 and "LegL" or "LegR"
		local leg = H.limb(K, g, {
			{ 0.62 * x, 1.84, 0.58, 0.5 },
			{ 0.88 * x, 1.06, 0.2, 0.42 },
			{ 0.82 * x, 0.36, 0.62, 0.32 },
		}, { step = 0.42, cores = { P.limbCore or "Fur", P.limbCore or "FurDark" }, tiles = { furTile(0.56, 6, 0.56, lift), nil }, color = fringe })
		parts.legs[g] = leg
		K:block(g, "SkinDark", CFrame.new(0.84 * x, 0.14, 0.42) * CFrame.Angles(0, rad(-10 * x), 0), Vector3.new(0.56, 0.28, 0.86))
		for f = -1, 1 do
			K:block(g, "Skin", CFrame.new(0.84 * x + f * 0.16 - 0.05 * x, 0.12, 0.0) * CFrame.Angles(0, rad(-10 * x + f * 8), 0), Vector3.new(0.15, 0.2, 0.22))
		end
	end

	-- head (head space: origin at the back of the skull, facing -Z)
	local HEAD = H.APE_HEAD
	local function hcf(px, py, pz, ax, ay, az)
		return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
	end
	local function hp(px, py, pz)
		return HEAD * Vector3.new(px, py, pz)
	end
	local function hv(px, py, pz)
		return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
	end
	-- skull and crest, leathery face, heavy brow, wide muzzle
	K:block("Head", "FurDark", hcf(0, 0.18, -0.26), Vector3.new(1.0, 0.84, 0.8))
	K:block("Head", "Fur", hcf(0, 0.5, -0.12, -14, 0, 0), Vector3.new(0.5, 0.36, 0.64))
	for i, z in { 0.05, -0.18, -0.42 } do
		K:block("Head", (P.crest and P.crest[i]) or "FurDark", hcf(0, 0.68 + (i == 2 and 0.06 or 0), z, -18 + i * 6, 0, 0), Vector3.new(0.2, 0.36 - i * 0.04, 0.34))
	end
	K:block("Head", "Skin", hcf(0, 0.06, -0.6), Vector3.new(0.78, 0.56, 0.2))
	K:block("Head", "SkinDark", hcf(0, 0.38, -0.66, -6, 0, 0), Vector3.new(0.9, 0.2, 0.32))
	for _, x in { 1, -1 } do
		K:block("Head", "SkinDark", hcf(0.24 * x, 0.42, -0.72, -10, -10 * x, 12 * x), Vector3.new(0.42, 0.16, 0.26))
		H.eye(K, "Head", hcf(0.21 * x, 0.25, -0.72, 0, -14 * x, 10 * x), 0.15, 0.05)
		-- fur framing the face, cheek tufts
		K:block("Head", "Fur", hcf(0.47 * x, 0.02, -0.42, 0, -16 * x, 8 * x), Vector3.new(0.18, 0.62, 0.5))
		K:block("Head", "FurLight", hcf(0.5 * x, -0.24, -0.36, 10, -20 * x, 14 * x), Vector3.new(0.16, 0.34, 0.44))
	end
	K:block("Head", "Skin", hcf(0, -0.04, -0.82), Vector3.new(0.62, 0.36, 0.4))
	K:block("Head", "SkinDark", hcf(0, 0.1, -1.0, -10, 0, 0), Vector3.new(0.4, 0.22, 0.12))
	for _, x in { 1, -1 } do
		K:block("Head", "Socket", hcf(0.1 * x, 0.08, -1.06), Vector3.new(0.1, 0.07, 0.04))
		-- fangs: big canines over the lower lip
		K:spike("Head", "Tooth", hp(0.2 * x, -0.2, -0.96), hv(0, -1, -0.05), hv(0, 0, 1), 0.15, 0.06)
	end
	K:block("Head", "Mouth", hcf(0, -0.22, -0.84), Vector3.new(0.48, 0.08, 0.3))
	H.teeth(K, "Head", "Tooth", hp(-0.12, -0.2, -0.99), hp(0.12, -0.2, -0.99), 3, hv(0, -1, 0), hv(0, 0, 1), 0.07, 0.05)
	-- jaw: heavy, slightly dropped, lower fangs
	local JAW = HEAD * CFrame.new(H.APE_HINGE) * CFrame.Angles(rad(-10), 0, 0)
	K:block("Jaw", "Skin", JAW * CFrame.new(0, -0.1, -0.58), Vector3.new(0.6, 0.22, 0.56))
	K:block("Jaw", "Fur", JAW * CFrame.new(0, -0.16, -0.3), Vector3.new(0.74, 0.26, 0.5))
	K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.02, -0.6), Vector3.new(0.44, 0.04, 0.42))
	for _, x in { 1, -1 } do
		K:spike("Jaw", "Tooth", JAW * Vector3.new(0.19 * x, 0.0, -0.8), JAW:VectorToWorldSpace(Vector3.new(0, 1, 0.05)).Unit, JAW:VectorToWorldSpace(Vector3.zAxis), 0.13, 0.06)
	end
	H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(-0.1, 0, -0.84), JAW * Vector3.new(0.1, 0, -0.84), 3, JAW:VectorToWorldSpace(Vector3.new(0, 1, 0)).Unit, JAW:VectorToWorldSpace(Vector3.zAxis), 0.06, 0.05)
	if P.ears then
		for _, x in { 1, -1 } do
			local g = x == 1 and "EarL" or "EarR"
			K:block(g, "SkinDark", hcf(0.5 * x, 0.16, -0.3, 0, -20 * x, 0), Vector3.new(0.1, 0.26, 0.22))
			K:block(g, "Fur", hcf(0.47 * x, 0.18, -0.24, 0, -20 * x, 0), Vector3.new(0.08, 0.32, 0.28))
		end
	end
	if P.head then
		P.head(K, hcf, hp, hv)
	end
	if P.tail then
		parts.tail = K:tube("Tail", {
			{ 0, 1.84, 0.9, rx = 0.2, ru = 0.2 },
			{ 0, 1.9, 1.5, rx = 0.17, ru = 0.17 },
			{ 0.1, 2.5, 1.9, rx = 0.14, ru = 0.14 },
			{ 0.06, 3.0, 1.66, rx = 0.1, ru = 0.1 },
		}, { step = 0.26, core = "FurDark", coreScale = 0.95, tile = H.fur(0.3, 4, 0.34, lift), color = limbFur })
	end
	if P.armour then
		P.armour(K, parts)
	end
	if P.extras then
		P.extras(K, parts, hcf, hp, hv)
	end
	return parts
end

-- a zigzag lightning bolt from p0 to p1: thin neon segments kinking across `side`
function H.bolt(K, group, key, p0, p1, side, kinks, width, amp)
	kinks = kinks or 4
	local pts = { p0 }
	for i = 1, kinks - 1 do
		local f = i / kinks
		table.insert(pts, p0:Lerp(p1, f) + side * (i % 2 == 0 and -1 or 1) * (amp or 0.12) * K:rand(0.7, 1.2))
	end
	table.insert(pts, p1)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local d = b - a
		K:block(group, key, CFrame.lookAt((a + b) / 2, b), Vector3.new(width or 0.06, width or 0.06, d.Magnitude + (width or 0.06)))
	end
end

-- a storm cloud: overlapping dark puffs around `centre` (size = half extents), bolts hanging out of its belly
function H.cloud(K, group, keys, centre, size, puffs, boltKey, bolts)
	for i = 1, puffs do
		local o = Vector3.new(K:rand(-1, 1) * size.X, K:rand(-0.4, 1) * size.Y, K:rand(-1, 1) * size.Z)
		local s = math.min(size.X, size.Z) * K:rand(0.55, 0.9)
		K:block(group, keys[(i - 1) % #keys + 1], CFrame.new(centre + o) * CFrame.Angles(rad(K:rand(-12, 12)), rad(K:rand(0, 90)), rad(K:rand(-12, 12))), Vector3.new(s, s * 0.7, s))
	end
	for i = 1, bolts or 0 do
		local top = centre + Vector3.new(K:rand(-0.6, 0.6) * size.X, -size.Y * 0.3, K:rand(-0.6, 0.6) * size.Z)
		H.bolt(K, group, boltKey, top, top + Vector3.new(K:rand(-0.2, 0.2), -size.Y * K:rand(1.4, 2.0), K:rand(-0.2, 0.2)), Vector3.xAxis, 3, 0.07, 0.1)
	end
end

-- glowing cracks running along a tube: at each angle a zigzag of thin neon slivers laid into the surface between
-- `from` and `to` (molten seams, frost cracks, energy veins)
function H.cracks(K, group, key, samples, thetas, from, to, seg, width, lift)
	seg = seg or 0.3
	lift = lift or 0.03
	for _, th0 in thetas do
		local s, k = from, 0
		local prev
		while s <= to + 1e-3 do
			local th = th0 + rad((k % 2 == 0 and 1 or -1) * 9 + K:rand(-4, 4))
			local pos = K:surface(K:at(samples, s), th, -lift)
			if prev then
				K:block(group, key, CFrame.lookAt((prev + pos) / 2, pos), Vector3.new(width or 0.07, width or 0.07, (pos - prev).Magnitude + (width or 0.07)))
			end
			prev = pos
			s += seg
			k += 1
		end
	end
end

-- a quadruped leg through joint points (crisp joints, last point = the ankle) ending in a foot with claws.
-- opts: everything H.limb takes, plus foot = { size = Vector3, key }, toes, claw = { len, w, curl }, yaw (degrees the
-- foot turns out)
function H.quadLeg(K, group, pts, opts)
	local segs = H.limb(K, group, pts, opts)
	local last = pts[#pts]
	local x, z = last[1], last[3]
	local foot = opts.foot or {}
	local fs = foot.size or Vector3.new(0.5, 0.24, 0.6)
	local yaw = rad((opts.yaw or 0) * (x >= 0 and -1 or 1))
	local turn = CFrame.Angles(0, yaw, 0)
	local fwd = turn:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local centre = Vector3.new(x, fs.Y / 2, z) + fwd * fs.Z * 0.22
	K:block(group, foot.key or "HideDark", CFrame.new(centre) * turn, fs)
	-- ankle: close the gap between the last limb point and the top of the foot
	if last[2] > fs.Y then
		local top = Vector3.new(x, fs.Y * 0.7, z)
		local ank = Vector3.new(x, last[2], z)
		K:block(group, (opts.cores and opts.cores[#opts.cores]) or opts.core or "Hide", CFrame.lookAt((top + ank) / 2, ank) * CFrame.Angles(0, 0, rad(45)), Vector3.new(last[4] * 1.3, last[4] * 1.3, (ank - top).Magnitude + last[4]))
	end
	if opts.toes ~= 0 then
		local claw = opts.claw or {}
		H.claws(K, group, centre + fwd * fs.Z * 0.45 + Vector3.new(0, -fs.Y * 0.1, 0), fwd, turn:VectorToWorldSpace(Vector3.xAxis), { n = opts.toes or 3, spread = fs.X * 0.72, fan = 34, droop = 0.4, len = claw.len or 0.26, w = claw.w or 0.08, curl = claw.curl or 30, keys = claw.keys })
	end
	return segs
end

-- a tapered rod of blocks following a smooth curve through `pts` (tusks, curled horns), ending in a point
function H.curve(K, group, keys, pts, w0, w1, step)
	local nodes = {}
	for i, p in pts do
		nodes[i] = { p.X, p.Y, p.Z, rx = 0.1 }
	end
	local samples = K:path(nodes, step or 0.18)
	local n = #samples
	for i = 1, n - 1 do
		local a, b = samples[i], samples[i + 1]
		local f = (i - 1) / math.max(n - 2, 1)
		local w = w0 + (w1 - w0) * f
		local key = keys[math.min(#keys, 1 + math.floor(f * #keys))]
		if i == n - 1 then
			H.point(K, group, key, b.p + b.T * w * 0.6, b.T, w * 0.95)
		end
		K:block(group, key, CFrame.lookAt((a.p + b.p) / 2, b.p) * CFrame.Angles(0, 0, rad(45)), Vector3.new(w, w, (b.p - a.p).Magnitude + w * 0.5))
	end
end

-- ------------------------------------------------------------------------------------------------------------------
-- Crab body plan (Scuttle): a wide armoured carapace with a spiked rim, eye stalks with glowing eyes, two big serrated
-- pincers held up and three jointed legs a side. Keys: Shell, ShellDark, ShellLight, Belly, Armour, ArmourLight, Spike,
-- SpikeTip, Claw (pincer), ClawDark, Tooth, Mouth, Eye, Socket. P: core / coreScale / overlap (glowing seams), crest(K,
-- shell) for crystals / spikes on top, rim = spikes round the rim (default true)
H.CRAB_JOINTS = {
	ClawL = { 1.0, 1.08, -0.5 },
	ClawR = { -1.0, 1.08, -0.5 },
	EyeL = { 0.3, 1.5, -0.66 },
	EyeR = { -0.3, 1.5, -0.66 },
	LegAL = { 1.02, 1.1, -0.32 },
	LegAR = { -1.02, 1.1, -0.32 },
	LegBL = { 1.1, 1.1, 0.14 },
	LegBR = { -1.1, 1.1, 0.14 },
	LegCL = { 1.02, 1.1, 0.58 },
	LegCR = { -1.02, 1.1, 0.58 },
}

function H.crab(K, P)
	P = P or {}
	local function shellColor(th, ring)
		local a = math.deg(math.abs(th))
		if a < 30 then
			return "ShellDark"
		elseif a < 70 then
			return ring % 2 == 0 and "Shell" or "ShellDark"
		end
		return "ShellLight"
	end
	local shell = K:tube("Body", {
		{ 0, 1.22, -0.66, rx = 0.92, ru = 0.4, rd = 0.32 },
		{ 0, 1.34, -0.1, rx = 1.24, ru = 0.56, rd = 0.38 },
		{ 0, 1.32, 0.4, rx = 1.2, ru = 0.52, rd = 0.38 },
		{ 0, 1.2, 0.82, rx = 0.86, ru = 0.4, rd = 0.32 },
	}, { step = 0.34, core = P.core or "ShellDark", coreCap = P.core and "ShellDark" or nil, coreScale = P.coreScale or 0.74, tile = { w = 0.56, t = 0.14, lift = 6, jitter = 2, sink = 0.5, overlap = P.overlap or 1.1 }, belly = { key = "Belly", key2 = "Belly", arc = 60, t = 0.1, wide = 1.05 }, color = shellColor })
	-- a ring of spikes round the rim of the carapace
	if P.rim ~= false then
		for s = 0.1, shell.total - 0.1, 0.3 do
			local smp = K:at(shell, s)
			for _, x in { 1, -1 } do
				local pos, nrm = K:surface(smp, rad(82) * x, 0.05)
				K:chain("Body", { "Spike", "SpikeTip" }, pos, (nrm + smp.U * 0.2 + smp.T * 0.15).Unit, smp.T, { n = 2, len = 0.34, w0 = 0.15, w1 = 0.09, bend = 0, tipH = 0.1 })
			end
		end
		for _, x in { -0.5, -0.17, 0.17, 0.5 } do
			local smp = K:at(shell, 0.05)
			local pos = smp.p + smp.R * x * smp.rx * (smp.R.X < 0 and -1 or 1) + smp.U * 0.06
			K:chain("Body", { "Spike", "SpikeTip" }, pos, (Vector3.new(0, 0.25, -1) + Vector3.new(x * 0.6, 0, 0)).Unit, Vector3.xAxis, { n = 2, len = 0.3, w0 = 0.13, w1 = 0.08, bend = 0, tipH = 0.09 })
		end
	end
	-- close the front of the carapace with a sloped face plate, mouthparts under it
	local f0 = K:at(shell, 0)
	K:block("Body", "ShellDark", CFrame.lookAt(f0.p + f0.U * 0.04, f0.p + f0.U * 0.04 - Vector3.new(0, 0.35, 1)), Vector3.new(f0.rx * 1.9, (f0.ru + f0.rd) * 0.95, 0.24))
	K:block("Body", "Shell", CFrame.lookAt(f0.p + f0.U * 0.28 - f0.T * 0.08, f0.p + f0.U * 0.28 - f0.T * 0.08 - Vector3.new(0, -0.4, 1)), Vector3.new(f0.rx * 1.6, 0.16, 0.3))
	K:block("Body", "Mouth", CFrame.new(0, 1.02, -0.86), Vector3.new(0.6, 0.18, 0.12))
	H.teeth(K, "Body", "Tooth", Vector3.new(-0.22, 1.1, -0.9), Vector3.new(0.22, 1.1, -0.9), 4, Vector3.new(0, -1, -0.2).Unit, Vector3.zAxis, 0.07, 0.04)
	for _, x in { 1, -1 } do
		K:block("Body", "ShellDark", CFrame.new(0.16 * x, 0.96, -0.9) * CFrame.Angles(rad(10), 0, rad(14 * x)), Vector3.new(0.18, 0.26, 0.1))
		-- eye stalks
		local ge = x == 1 and "EyeL" or "EyeR"
		K:tube(ge, {
			{ 0.3 * x, 1.42, -0.62, rx = 0.09 },
			{ 0.38 * x, 1.86, -0.76, rx = 0.07 },
		}, { step = 0.2, ref = Vector3.xAxis, core = "ShellDark", coreScale = 0.98 })
		K:block(ge, "Socket", CFrame.new(0.39 * x, 1.94, -0.78) * CFrame.Angles(0, rad(45), 0), Vector3.new(0.17, 0.15, 0.17))
		H.point(K, ge, "Eye", Vector3.new(0.4 * x, 2.06, -0.82), Vector3.new(0.2 * x, 1, -0.3), 0.12)
		K:block(ge, "Eye", CFrame.new(0.39 * x, 1.96, -0.86), Vector3.new(0.12, 0.06, 0.04))
		-- the pincer arm: shoulder, forearm, the claw held up and forward
		local gc = x == 1 and "ClawL" or "ClawR"
		H.limb(K, gc, {
			{ 1.0 * x, 1.1, -0.5, 0.2 },
			{ 1.42 * x, 1.18, -0.86, 0.18 },
			{ 1.48 * x, 1.24, -1.24, 0.17 },
		}, { step = 0.22, cores = { "ShellDark", "Shell" } })
		local palm = CFrame.lookAt(Vector3.new(1.5 * x, 1.34, -1.5), Vector3.new(1.46 * x, 1.48, -2.4)) * CFrame.Angles(0, 0, rad(-20 * x))
		K:block(gc, "Claw", palm, Vector3.new(0.66, 0.62, 0.78))
		K:block(gc, "ClawDark", palm * CFrame.new(0, 0, 0.34), Vector3.new(0.54, 0.52, 0.22))
		K:block(gc, "Claw", palm * CFrame.new(0, 0.22, 0.02) * CFrame.Angles(rad(-8), 0, 0), Vector3.new(0.5, 0.2, 0.7))
		-- fixed lower finger and the moving upper finger, teeth along their inner edges
		local fingerFwd = palm:VectorToWorldSpace(Vector3.new(0, 0, -1))
		local up = palm:VectorToWorldSpace(Vector3.yAxis)
		local side = palm:VectorToWorldSpace(Vector3.xAxis)
		K:chain(gc, { "Claw", "Claw", "ClawDark" }, palm * Vector3.new(0, -0.18, -0.36), (fingerFwd - up * 0.1).Unit, side, { n = 3, len = 0.84, w0 = 0.34, w1 = 0.14, bend = 14, depth = 0.8 })
		K:chain(gc, { "Claw", "Claw", "ClawDark" }, palm * Vector3.new(0, 0.2, -0.3), (fingerFwd + up * 0.45).Unit, side, { n = 3, len = 0.74, w0 = 0.28, w1 = 0.13, bend = -20, depth = 0.8 })
		H.teeth(K, gc, "Tooth", palm * Vector3.new(0, -0.02, -0.46), palm * Vector3.new(0, 0.0, -0.94), 4, up, side, 0.07, 0.045)
		-- the walking legs: out and up to the knee, then down to a pointed tip
		for i, z in { -0.32, 0.14, 0.58 } do
			local g = "Leg" .. ({ "A", "B", "C" })[i] .. (x == 1 and "L" or "R")
			local spread = ({ -0.3, 0.02, 0.36 })[i]
			local knee = Vector3.new((1.72 + (i == 2 and 0.1 or 0)) * x, 1.46, z + spread)
			local foot = Vector3.new((2.06 + (i == 2 and 0.1 or 0)) * x, 0.14, z + spread * 1.8)
			H.limb(K, g, {
				{ 1.02 * x, 1.12, z, 0.16 },
				{ knee.X, knee.Y, knee.Z, 0.13 },
				{ foot.X, foot.Y + 0.2, foot.Z, 0.08 },
			}, { step = 0.24, cores = { "Shell", "ShellDark" } })
			K:block(g, "Spike", CFrame.lookAt(knee, knee + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.16, 0.16, 0.16))
			H.point(K, g, "SpikeTip", foot + Vector3.new(0, -0.02, 0), Vector3.new(0.1 * x, -1, 0), 0.12)
		end
	end
	if P.crest then
		P.crest(K, shell)
	end
	return shell
end

-- ------------------------------------------------------------------------------------------------------------------
-- Serpent body plan (Slither): a thick armoured serpent along +Z in segments Seg1..Seg4 + Tail (the slither wave turns
-- each about its joint), a neck rearing up like a cobra into a horned dragon head with frills, long fangs, a half-open
-- jaw and a forked tongue (Tongue flicks). Keys: Hide, HideDark, HideLight, Back, Belly, Belly2, Horn, HornLight,
-- Tooth, Mouth, Tongue, Eye, Socket. P: color, crest(K, segs) (segs = { Seg1 = samples, ..., Neck = samples }),
-- head(K, hcf, hp, hv), core / coreScale / coreCap / overlap
H.SERPENT_HEAD = CFrame.new(0, 2.34, -1.14) * CFrame.Angles(rad(-14), 0, 0)
H.SERPENT_HINGE = Vector3.new(0, -0.14, -0.12)
H.SERPENT_JOINTS = {
	Neck = { 0, 0.6, 0.05 },
	Seg1 = { 0, 0.6, 0.3 },
	Seg2 = { 0, 0.6, 1.3 },
	Seg3 = { 0, 0.6, 2.3 },
	Seg4 = { 0, 0.6, 3.25 },
	Tail = { 0, 0.6, 4.1 },
	Head = { 0, 2.18, -0.98 },
	Jaw = H.SERPENT_HEAD * H.SERPENT_HINGE,
	Tongue = H.SERPENT_HEAD * Vector3.new(0, -0.16, -0.9),
}
H.SERPENT_PARENTS = { Seg2 = "Seg1", Seg3 = "Seg2", Seg4 = "Seg3", Tail = "Seg4", Head = "Neck", Jaw = "Head", Tongue = "Head" }

function H.serpent(K, P)
	P = P or {}
	local color = P.color or H.skin({ stripe = 34, band = 80, flank = 110, every = 2 })
	local tile = { w = 0.46, t = 0.12, lift = 7, jitter = 1.5, sink = 0.5, overlap = P.overlap or 1.1 }
	local belly = { key = "Belly", key2 = "Belly2", arc = 46, t = 0.12, wide = 1.1 }
	local function seg(group, z0, z1, r0, r1, extra)
		return K:tube(group, {
			{ 0, 0.6 - (0.58 - r0), z0, rx = r0, ru = r0 * 0.94, rd = r0 * 0.86 },
			{ 0, 0.6 - (0.58 - (r0 + r1) / 2), (z0 + z1) / 2, rx = (r0 + r1) / 2, ru = (r0 + r1) / 2 * 0.94, rd = (r0 + r1) / 2 * 0.86 },
			{ 0, 0.6 - (0.58 - r1), z1, rx = r1, ru = r1 * 0.94, rd = r1 * 0.86 },
		}, { step = 0.34, core = P.core or "Hide", coreCap = P.coreCap, coreScale = P.coreScale or 0.76, tile = tile, belly = belly, color = color, trim = extra })
	end
	local segs = {}
	segs.Seg1 = seg("Seg1", 0.12, 1.42, 0.58, 0.56)
	segs.Seg2 = seg("Seg2", 1.22, 2.42, 0.56, 0.5)
	segs.Seg3 = seg("Seg3", 2.22, 3.38, 0.5, 0.42)
	segs.Seg4 = seg("Seg4", 3.18, 4.22, 0.42, 0.32)
	segs.Tail = K:tube("Tail", {
		{ 0, 0.6 - 0.26, 4.04, rx = 0.32, ru = 0.3, rd = 0.28 },
		{ 0.06, 0.24, 4.7, rx = 0.2, ru = 0.19, rd = 0.17 },
		{ 0.18, 0.18, 5.3, rx = 0.08, ru = 0.08, rd = 0.07 },
	}, { step = 0.3, core = P.core or "Hide", coreCap = P.coreCap, coreScale = P.coreScale or 0.76, tile = { w = 0.36, n = 5, t = 0.1, lift = 7, jitter = 1.5, sink = 0.5, overlap = P.overlap or 1.1 }, belly = belly, color = color, trim = 0.08 })
	-- the neck rears up from the front of the coil to the head (path runs head -> body so its scales lean back)
	segs.Neck = K:tube("Neck", {
		{ 0, 2.2, -0.98, rx = 0.4, ru = 0.38, rd = 0.42 },
		{ 0, 1.66, -0.84, rx = 0.46, ru = 0.44, rd = 0.48 },
		{ 0, 0.98, -0.42, rx = 0.52, ru = 0.5, rd = 0.52 },
		{ 0, 0.62, 0.26, rx = 0.56, ru = 0.54, rd = 0.5 },
	}, { step = 0.32, core = P.core or "Hide", coreCap = P.coreCap, coreScale = P.coreScale or 0.76, tile = tile, belly = belly, color = color })
	if P.crest then
		P.crest(K, segs)
	end

	-- head: a horned dragon-serpent skull, long fangs, frills fanning back from the jaw
	local HEAD = H.SERPENT_HEAD
	local function hcf(px, py, pz, ax, ay, az)
		return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
	end
	local function hp(px, py, pz)
		return HEAD * Vector3.new(px, py, pz)
	end
	local function hv(px, py, pz)
		return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
	end
	K:block("Head", "Hide", hcf(0, 0.12, -0.28), Vector3.new(0.72, 0.5, 0.62))
	K:block("Head", "Hide", hcf(0, 0.03, -0.86), Vector3.new(0.52, 0.34, 0.66))
	K:block("Head", "HideDark", hcf(0, 0.0, -1.26, -4, 0, 0), Vector3.new(0.42, 0.28, 0.24))
	K:block("Head", "Mouth", hcf(0, -0.13, -0.8), Vector3.new(0.46, 0.05, 0.9))
	K:block("Head", "Back", hcf(0, 0.38, -0.3, -10, 0, 0), Vector3.new(0.5, 0.1, 0.56))
	K:block("Head", "Back", hcf(0, 0.21, -0.86, -8, 0, 0), Vector3.new(0.3, 0.08, 0.6))
	for _, x in { 1, -1 } do
		K:block("Head", "HideDark", hcf(0.15 * x, 0.18, -0.9, -3, 0, -28 * x), Vector3.new(0.18, 0.08, 0.6))
		K:block("Head", "Horn", hcf(0.22 * x, 0.38, -0.56, -8, -12 * x, 16 * x), Vector3.new(0.32, 0.13, 0.36))
		H.eye(K, "Head", hcf(0.3 * x, 0.24, -0.6, 0, -30 * x, 12 * x), 0.16, 0.045)
		-- swept-back horns, a smaller pair under them
		K:chain("Head", { "Horn", "Horn", "HornLight", "HornLight" }, hp(0.24 * x, 0.4, -0.2), hv(0.35 * x, 0.45, 0.82), hv(1, 0, 0), { n = 4, len = 1.05, w0 = 0.17, w1 = 0.07, bend = 10 })
		K:chain("Head", { "Horn", "HornLight" }, hp(0.32 * x, 0.18, -0.08), hv(0.55 * x, 0.15, 0.82), hv(0, 1, 0), { n = 2, len = 0.5, w0 = 0.12, w1 = 0.07, bend = 0 })
		-- frill spines fanning back from the jaw
		for k = 0, 2 do
			K:chain("Head", { "HideDark", "HornLight" }, hp(0.34 * x, -0.06 - k * 0.1, -0.2 + k * 0.08), hv(0.6 * x, 0.2 - k * 0.35, 0.8), hv(0, 0, 1), { n = 2, len = 0.46 - k * 0.08, w0 = 0.09, w1 = 0.06, bend = 0 })
		end
		-- the long fangs and a row of teeth
		K:spike("Head", "Tooth", hp(0.17 * x, -0.14, -1.18), hv(0, -1, 0.05), hv(0, 0, 1), 0.2, 0.06)
		H.teeth(K, "Head", "Tooth", hp(0.22 * x, -0.15, -0.52), hp(0.19 * x, -0.15, -1.02), 4, hv(0, -1, 0), hv(1, 0, 0), 0.07, 0.04)
	end
	if P.head then
		P.head(K, hcf, hp, hv)
	end
	local JAW = HEAD * CFrame.new(H.SERPENT_HINGE) * CFrame.Angles(rad(-22), 0, 0)
	K:block("Jaw", "Hide", JAW * CFrame.new(0, -0.08, -0.52), Vector3.new(0.48, 0.16, 1.02))
	K:block("Jaw", "Belly", JAW * CFrame.new(0, -0.17, -0.46), Vector3.new(0.38, 0.04, 0.86))
	K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.54), Vector3.new(0.4, 0.04, 0.9))
	for _, x in { 1, -1 } do
		K:spike("Jaw", "Tooth", JAW * Vector3.new(0.15 * x, 0, -0.96), JAW:VectorToWorldSpace(Vector3.yAxis).Unit, JAW:VectorToWorldSpace(Vector3.zAxis), 0.12, 0.05)
		H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.19 * x, 0, -0.3), JAW * Vector3.new(0.16 * x, 0, -0.8), 4, JAW:VectorToWorldSpace(Vector3.yAxis), JAW:VectorToWorldSpace(Vector3.xAxis), 0.06, 0.04)
	end
	-- forked tongue, lying in the mouth and poking out past the fangs
	local T0 = HEAD * CFrame.new(0, -0.18, -0.7) * CFrame.Angles(rad(-10), 0, 0)
	K:block("Tongue", "Tongue", T0, Vector3.new(0.08, 0.04, 0.74))
	for _, x in { 1, -1 } do
		K:block("Tongue", "Tongue", T0 * CFrame.new(0.04 * x, 0, -0.46) * CFrame.Angles(0, rad(-14 * x), 0), Vector3.new(0.05, 0.035, 0.22))
	end
	return segs
end

return H
