-- Kit for the Kaiju Citadel's hero pieces (CitadelBuilder.Gate, CitadelBuilder.Keep), in the game's studded-voxel look
-- (SmoothPlastic + the stud texture):
--   * stone: three greys in large irregular patches (K.stone samples a noise field in world space, so neighbouring
--     stones share a tone over roughly 3-5 stones), on a height gradient - a dark blue-grey band along the foot fading to
--     light grey near the top. Tan is used only as trim: arch voussoirs, keystones, jambs, window frames, merlon caps.
--   * weathering (moss, vines, stains, cracks, missing blocks), kaiju motifs (claw gouges, the trophy skull), egg motifs
--     (finials and carvings), banners in several designs, carved plaques in the Antique font, torches and braziers.
-- Face helpers take a face CFrame: origin on the face, look vector = the face's outward normal, local X along the face.
local CollectionService = game:GetService("CollectionService")

local K = {}

local hex = Color3.fromHex
local N = Enum.NormalId
K.N = N
K.STUD = "rbxassetid://6372755229"
K.ALL = { N.Top, N.Front, N.Back, N.Left, N.Right }
K.ALLB = { N.Top, N.Bottom, N.Front, N.Back, N.Left, N.Right }
K.SIDES = { N.Front, N.Back, N.Left, N.Right }
K.TOP = { N.Top }
K.FRONT = { N.Front }
K.WIND_TAG = "CitadelWind" -- banners and flags; a client script can sway them

local P = {
	-- stone: light grey, mid grey, dark blue-grey, and tan (trim only); Base is the darker footing course
	Light = hex("CBC8C0"),
	Mid = hex("A5A39D"),
	Blue = hex("717989"),
	Tan = hex("C3A983"),
	Base = hex("5E636E"),
	Slate = hex("34333A"),
	-- weathering
	Moss = hex("5E8B3A"),
	MossDark = hex("47702D"),
	Vine = hex("3E6B29"),
	Leaf = hex("5B9A38"),
	Stain = hex("2A2826"),
	Crack = hex("2B2724"),
	Socket = hex("1A1614"),
	-- citadel colours
	Navy = hex("25244B"),
	NavyLight = hex("37356C"),
	Gold = hex("E7B53D"),
	GoldPale = hex("F4D57E"),
	Bronze = hex("A2652B"),
	Red = hex("8E1E25"),
	RedDark = hex("5F141A"),
	Iron = hex("35373D"),
	IronLight = hex("5B5E67"),
	Timber = hex("5C3B23"),
	TimberDark = hex("3F2817"),
	Bone = hex("E3D9C1"),
	BoneShade = hex("C7B894"),
	BoneDark = hex("9D8E6F"),
	Tooth = hex("F4EEDD"),
	Ember = hex("FF6F1C"),
	WindowGlow = hex("C9741F"),
	FlameA = hex("FF6A12"),
	FlameB = hex("FFA41F"),
	FlameC = hex("FFD45A"),
	SignGold = hex("F2C14E"),
	SignCream = hex("F3E6C4"),
	Ink = hex("1E140C"),
}
K.P = P

------------------------------------------------------------------------------- basics
local made = 0
function K.reset()
	made = 0
end
function K.count()
	return made
end

function K.studs(p, faces)
	for _, f in faces do
		local t = Instance.new("Texture")
		t.Texture = K.STUD
		t.Face = f
		t.StudsPerTileU = 4
		t.StudsPerTileV = 4
		t.Color3 = Color3.new(0, 0, 0)
		t.Transparency = 0.82
		t.Parent = p
	end
end

-- o: studs = faces, solid = false (no collision / queries), neon, transparency, shape, shadow = false
function K.part(parent, name, size, cf, color, o)
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
		K.studs(p, o.studs)
	end
	p.Parent = parent
	made += 1
	if made % 300 == 0 then
		task.wait()
	end
	return p
end

-- axis-aligned block from its min / max corners
function K.box(parent, name, x0, x1, y0, y1, z0, z1, color, o)
	if x0 > x1 then
		x0, x1 = x1, x0
	end
	if y0 > y1 then
		y0, y1 = y1, y0
	end
	if z0 > z1 then
		z0, z1 = z1, z0
	end
	return K.part(parent, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, o)
end

function K.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function K.face(pos, normal)
	return CFrame.lookAt(pos, pos + normal)
end

-- local X on a face frame of a world point (for placing things at known world coordinates)
function K.lx(F, wx, wz)
	return F:PointToObjectSpace(Vector3.new(wx, F.Position.Y, wz)).X
end

function K.wind(m)
	CollectionService:AddTag(m, K.WIND_TAG)
end

------------------------------------------------------------------------------- stone colour
local PATCH = 30 -- noise scale in studs: patches come out about 3-5 stones across

local function shade(c, k)
	if k >= 0 then
		return c:Lerp(Color3.new(1, 1, 1), k)
	end
	return c:Lerp(Color3.new(0, 0, 0), -k)
end
K.shade = shade

-- the stone colour at world position pos, t = height fraction of the building (0 = its foot, 1 = its top): the dark
-- blue-grey foot band, then patches of blue-grey / mid grey / light grey that get lighter with height. rng adds a
-- faint per-stone shade so the joints still read inside a patch.
function K.stone(pos, t, rng)
	local c
	if t < 0.06 then
		c = P.Blue
	else
		local n = math.clamp(math.noise(pos.X / PATCH + 0.37, pos.Y / (PATCH * 0.8) + 0.11, pos.Z / PATCH + 17.3) * 1.7, -0.5, 0.5)
		local score = t * 0.75 + n * 0.6 -- blue-grey low down, mid grey through the middle, light grey patches up top
		c = score < 0.2 and P.Blue or (score < 0.58 and P.Mid or P.Light)
	end
	return shade(c, rng and rng:NextNumber(-0.035, 0.035) or 0)
end

------------------------------------------------------------------------------- masonry
-- A solid block built from irregular courses of studded stones. cf = centre of the block's bottom face (yaw only),
-- size = (width along local X, height, depth along local Z). Each course (courseMin..courseMax tall) is cut into
-- stones (stoneMin..stoneMax long) that run the block's full depth, alternately along X and along Z (o.axis = "X" or
-- "Z" fixes it). Colours come from K.stone over the height band o.t0..o.t1.
function K.masonry(parent, name, cf, size, rng, o)
	o = o or {}
	local t0, t1 = o.t0 or 0, o.t1 or 1
	local W, H, D = size.X, size.Y, size.Z
	local cmin, cmax = o.courseMin or 4, o.courseMax or 8
	local smin, smax = o.stoneMin or 10, o.stoneMax or 26
	local faces = o.faces or K.SIDES
	local y, k = 0, o.phase or 0
	while y < H - 0.01 do
		local ch = math.min(H - y, rng:NextInteger(math.floor(cmin / 2), math.floor(cmax / 2)) * 2)
		if H - y - ch < cmin * 0.6 then
			ch = H - y
		end
		local alongX = o.axis == "X" or (o.axis == nil and k % 2 == 0)
		local L = alongX and W or D
		local pos = 0
		while pos < L - 0.01 do
			local sl = math.min(L - pos, rng:NextInteger(math.floor(smin / 2), math.floor(smax / 2)) * 2)
			if L - pos - sl < smin * 0.6 then
				sl = L - pos
			end
			local centre = alongX and Vector3.new(-W / 2 + pos + sl / 2, y + ch / 2, 0) or Vector3.new(0, y + ch / 2, -D / 2 + pos + sl / 2)
			local sz = alongX and Vector3.new(sl, ch, D) or Vector3.new(W, ch, sl)
			local at = cf * CFrame.new(centre)
			local c = K.stone(at.Position, t0 + (t1 - t0) * (y + ch / 2) / H, rng)
			local isTop = y + ch >= H - 0.01
			K.part(parent, name, sz, at, c, { studs = (isTop and o.topStuds) and K.ALL or faces, solid = o.solid })
			pos += sl
		end
		y += ch
		k += 1
	end
end

-- Plus-shaped (notched octagon) tower of studded courses: two crossed bars per course.
-- o: t0/t1, name, windows = { normals } (slits, or lit windows with o.glow), roofH, roofN, trim (spire band colour),
-- egg (finial size), flag (colour), noFlag
function K.crossTower(parent, cx, cz, D, H, rng, o)
	o = o or {}
	local m = K.model(parent, o.name or "Tower")
	local nb = math.floor(D * 0.6 / 2 + 0.5) * 2
	K.box(m, "Footing", cx - D / 2 - 1, cx + D / 2 + 1, -40, 4, cz - nb / 2 - 1, cz + nb / 2 + 1, P.Base, { studs = K.SIDES })
	K.box(m, "Footing", cx - nb / 2 - 1, cx + nb / 2 + 1, -40, 4, cz - D / 2 - 1, cz + D / 2 + 1, P.Base, { studs = K.SIDES })
	local y = 4
	local t0, t1 = o.t0 or 0, o.t1 or 0.9
	while y < H - 0.01 do
		local ch = math.min(H - y, rng:NextInteger(3, 5) * 2)
		if H - y - ch < 4 then
			ch = H - y
		end
		local t = t0 + (t1 - t0) * (y + ch / 2) / H
		K.part(m, "Stone", Vector3.new(D, ch, nb), CFrame.new(cx, y + ch / 2, cz), K.stone(Vector3.new(cx + D / 4, y, cz), t, rng), { studs = K.SIDES })
		K.part(m, "Stone", Vector3.new(nb, ch, D), CFrame.new(cx, y + ch / 2, cz), K.stone(Vector3.new(cx, y, cz + D / 4), t, rng), { studs = K.SIDES })
		y += ch
	end
	for _, by in { math.floor(H * 0.38), math.floor(H * 0.72) } do
		K.part(m, "Band", Vector3.new(D + 1.2, 2, nb + 1.2), CFrame.new(cx, by, cz), P.Mid, { studs = K.SIDES, solid = false })
		K.part(m, "Band", Vector3.new(nb + 1.2, 2, D + 1.2), CFrame.new(cx, by, cz), P.Mid, { studs = K.SIDES, solid = false })
	end
	for _, n in o.windows or {} do
		local F = K.face(Vector3.new(cx + n.X * D / 2, 0, cz + n.Z * D / 2), n)
		if o.glow then
			K.window(m, F, 0, H * 0.48, 4, 12, true)
			K.window(m, F, 0, H * 0.78, 4, 12, true)
		else
			K.slit(m, F, 0, H * 0.5, 1.8, 7, rng)
			K.slit(m, F, 0, H * 0.8, 1.8, 7, rng)
		end
		K.weather(m, F, nb, H, rng, { moss = 2, vines = rng:NextNumber() < 0.6 and 1 or 0, vineTop = H - 1, cracks = 1, holes = 0, yMin = 6 })
	end
	local pw = D + 3
	K.masonry(m, "Parapet", CFrame.new(cx, H, cz), Vector3.new(pw, 5, pw), rng, { t0 = 0.95, t1 = 1, courseMin = 6, courseMax = 6, stoneMin = 10, stoneMax = 20, topStuds = true })
	K.merlonRect(m, cx, cz, pw / 2, pw / 2, H + 5, 3, 4.5, 2.4, rng, 0.95)
	local top = K.spire(m, cx, cz, H + 5, D - 3, D - 3, o.roofH or 60, o.roofN or 11, o.trim or P.Bronze)
	local _, eggTop = K.egg(m, Vector3.new(cx, top, cz), o.egg or 4.5, P.Gold, P.Red)
	if not o.noFlag then
		K.flagPole(m, Vector3.new(cx, eggTop, cz), 16, 10, 6, o.flag or P.Red, P.Gold)
	end
	return m, eggTop
end

------------------------------------------------------------------------------- roofs, battlements, turrets
-- tall pointed roof: n stepped tiers from w0 x d0 at y0, h tall; navy tones, every third step a trim band
function K.spire(parent, cx, cz, y0, w0, d0, h, n, trim)
	local sh = h / n
	for i = 0, n - 1 do
		local f = 1 - i / n
		local w, d = math.max(1.4, w0 * f), math.max(1.4, d0 * f)
		if i == 0 then
			w, d = w + 2, d + 2 -- eaves
		end
		local c = (trim and i % 3 == 1) and trim or (i % 2 == 0 and P.Navy or P.NavyLight)
		K.box(parent, "Roof", cx - w / 2, cx + w / 2, y0 + i * sh, y0 + (i + 1) * sh, cz - d / 2, cz + d / 2, c, { studs = K.ALL, solid = i == 0 })
	end
	return y0 + h
end

-- battlements from p0 to p1 (y ignored): stone merlons mw long, mh tall, md deep, about gap apart, each with a tan cap
function K.merlonLine(parent, p0, p1, y0, mw, mh, md, rng, gap, t)
	local d = Vector3.new(p1.X - p0.X, 0, p1.Z - p0.Z)
	local len = d.Magnitude
	if len < mw then
		return
	end
	local dir = d.Unit
	local n = math.max(1, math.floor((len + gap) / (mw + gap)))
	local step = n > 1 and (len - mw) / (n - 1) or 0
	local body = mh - 0.9
	for i = 0, n - 1 do
		local base = Vector3.new(p0.X, y0, p0.Z) + dir * (mw / 2 + i * step)
		local rot = CFrame.lookAt(base, base + dir) * CFrame.Angles(0, math.rad(90), 0)
		K.part(parent, "Merlon", Vector3.new(mw, body, md), rot * CFrame.new(0, body / 2, 0), K.stone(base, t or 0.92, rng), { studs = K.SIDES })
		K.part(parent, "MerlonCap", Vector3.new(mw + 0.5, 0.9, md + 0.5), rot * CFrame.new(0, body + 0.45, 0), P.Tan, { studs = K.ALL, solid = false })
	end
end

-- battlements round a rectangle (centre cx, cz; half sizes hx, hz); every corner covered once
function K.merlonRect(parent, cx, cz, hx, hz, y, mw, mh, md, rng, t)
	local c = { Vector3.new(cx - hx, 0, cz - hz), Vector3.new(cx + hx, 0, cz - hz), Vector3.new(cx + hx, 0, cz + hz), Vector3.new(cx - hx, 0, cz + hz) }
	local centre = Vector3.new(cx, 0, cz)
	for i = 1, 4 do
		local a, b = c[i], c[i % 4 + 1]
		local dir = (b - a).Unit
		local inward = (centre - (a + b) / 2).Unit
		K.merlonLine(parent, a + inward * md / 2, b + inward * md / 2 - dir * md, y, mw, mh, md, rng, 2.5, t)
	end
end

-- corbel teeth under an overhanging parapet: blocks every ~step along p0 -> p1, their tops at y, sticking out along out
function K.corbels(parent, p0, p1, y, out, step, rng, t)
	local d = Vector3.new(p1.X - p0.X, 0, p1.Z - p0.Z)
	local n = math.max(1, math.floor(d.Magnitude / step))
	for i = 0, n do
		local c = Vector3.new(p0.X, y - 1.6, p0.Z) + d * (i / n) + out * 1.2
		K.part(parent, "Corbel", Vector3.new(2.2, 3.2, 2.2), CFrame.new(c), K.stone(c, t or 0.85, rng), { studs = K.ALL, solid = false })
	end
end

-- small corbelled turret (bartizan) standing on base: stepped corbel, body, capped corner merlons, pointed roof, egg
function K.bartizan(parent, base, rng, o)
	o = o or {}
	local m = K.model(parent, "Turret")
	local x, y, z = base.X, base.Y, base.Z
	local W = o.w or 8
	for i, w in { W * 0.4, W * 0.7, W * 1.05 } do
		K.box(m, "Corbel", x - w / 2, x + w / 2, y + (i - 1) * 2, y + i * 2, z - w / 2, z + w / 2, K.stone(base, 0.7, rng), { studs = K.SIDES, solid = false })
	end
	local bodyH = o.h or 22
	K.box(m, "Body", x - W / 2, x + W / 2, y + 6, y + 6 + bodyH, z - W / 2, z + W / 2, K.stone(base + Vector3.new(0, 10, 0), 0.85, rng), { studs = K.SIDES })
	local by = y + 6 + bodyH * 0.45
	K.box(m, "Band", x - W / 2 - 0.5, x + W / 2 + 0.5, by, by + 1.6, z - W / 2 - 0.5, z + W / 2 + 0.5, P.Mid, { solid = false })
	local top = y + 6 + bodyH
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local mx, mz = x + sx * (W / 2 - 1), z + sz * (W / 2 - 1)
			K.box(m, "Merlon", mx - 1, mx + 1, top, top + 1.8, mz - 1, mz + 1, P.Light, { studs = K.SIDES })
			K.box(m, "MerlonCap", mx - 1.25, mx + 1.25, top + 1.8, top + 2.6, mz - 1.25, mz + 1.25, P.Tan, { solid = false })
		end
	end
	local roofTop = K.spire(m, x, z, top, W - 2, W - 2, o.roofH or 16, 6, o.trim or P.Bronze)
	K.egg(m, Vector3.new(x, roofTop, z), 2.2, P.Gold)
	return m
end

------------------------------------------------------------------------------- eggs
local EGG = { 0.6, 0.84, 0.97, 1, 0.96, 0.86, 0.68, 0.42 }
local EGG_SMALL = { 0.72, 1, 0.94, 0.72, 0.4 }

-- egg finial standing on pos (bottom centre); returns the model and its top height
function K.egg(parent, pos, s, color, band)
	local m = K.model(parent, "Egg")
	local rows = s < 3 and EGG_SMALL or EGG
	local rh = s * 1.32 / #rows
	for i, wf in rows do
		local w = s * wf
		K.part(m, "Egg", Vector3.new(w, rh, w), CFrame.new(pos + Vector3.new(0, (i - 0.5) * rh, 0)), (band and i == 3) and band or color, { studs = K.ALL, solid = false })
	end
	return m, pos.Y + s * 1.32
end

-- egg carved in relief on a face, (x, y) = its bottom centre, s = its width scale, in a darker niche
function K.eggRelief(parent, F, x, y, s, color, band)
	local rows = { 0.62, 0.9, 1, 0.97, 0.86, 0.66, 0.36 }
	local rh = s * 0.19
	K.part(parent, "EggNiche", Vector3.new(s * 0.98, s * 1.52, 0.2), F * CFrame.new(x, y + s * 0.66, -0.08), P.Base, { solid = false })
	for i, wf in rows do
		K.part(parent, "EggCarving", Vector3.new(s * 0.74 * wf, rh, 0.7), F * CFrame.new(x, y + (i - 0.5) * rh, -0.3), (band and i == 3) and band or color, { studs = K.FRONT, solid = false })
	end
end

------------------------------------------------------------------------------- face details
-- proud stones scattered over a face (w x h, t0..t1 its height band): the patch colour there, a shade darker
function K.accents(parent, F, w, h, n, rng, t0, t1, o)
	o = o or {}
	local yMin = o.yMin or 0
	for i = 1, n do
		local sw = rng:NextInteger(2, 4) * 2
		local sh = rng:NextInteger(1, 2) * 2
		if w > sw + 2 and h - yMin > sh + 2 then
			local x = math.floor(rng:NextNumber(-w / 2 + sw / 2, w / 2 - sw / 2) / 2 + 0.5) * 2
			local y = math.floor(rng:NextNumber(yMin + sh / 2, h - sh / 2) / 2 + 0.5) * 2
			local at = F * CFrame.new(x, y, -0.3 - (i % 3) * 0.07)
			K.part(parent, "Stone", Vector3.new(sw, sh, 0.8), at, shade(K.stone(at.Position, t0 + (t1 - t0) * y / h), -0.07), { studs = K.FRONT, solid = false })
		end
	end
end

-- arrow slit (dark recess) on a tan sill, with a rain stain under it
function K.slit(parent, F, x, y, w, h, rng)
	K.part(parent, "Slit", Vector3.new(w, h, 0.3), F * CFrame.new(x, y + h / 2, -0.1), P.Socket, { solid = false })
	K.part(parent, "Sill", Vector3.new(w + 1.2, 0.7, 1), F * CFrame.new(x, y - 0.35, -0.45), P.Tan, { solid = false })
	local len = rng and rng:NextNumber(7, 14) or 10
	K.part(parent, "Stain", Vector3.new(w + 0.4, len, 0.2), F * CFrame.new(x, y - 0.7 - len / 2, -0.12), P.Stain, { solid = false, transparency = 0.55, shadow = false })
end

-- arched window (bottom centre at x, y) in a tan frame; glow = lit from inside (warm neon)
function K.window(parent, F, x, y, w, h, glow)
	local inner = glow and P.WindowGlow or P.Socket
	local o = { neon = glow or nil, solid = false }
	local arch = w * 0.35
	K.part(parent, "Window", Vector3.new(w, h - arch, 0.3), F * CFrame.new(x, y + (h - arch) / 2, -0.1), inner, o)
	K.part(parent, "Window", Vector3.new(w * 0.6, arch, 0.3), F * CFrame.new(x, y + h - arch / 2, -0.1), inner, o)
	K.part(parent, "Sill", Vector3.new(w + 2, 0.9, 1.3), F * CFrame.new(x, y - 0.45, -0.55), P.Tan, { studs = K.TOP, solid = false })
	for _, sx in { -1, 1 } do
		K.part(parent, "WindowFrame", Vector3.new(0.9, h - arch, 0.9), F * CFrame.new(x + sx * (w / 2 + 0.45), y + (h - arch) / 2, -0.35), P.Tan, { solid = false })
	end
	K.part(parent, "WindowArch", Vector3.new(w * 0.6 + 1.8, 1.2, 1), F * CFrame.new(x, y + h + 0.6, -0.4), P.Tan, { solid = false })
	K.part(parent, "Stain", Vector3.new(w * 0.7, 6, 0.2), F * CFrame.new(x, y - 3.9, -0.12), P.Stain, { solid = false, transparency = 0.6, shadow = false })
end

-- weathering on a face of w x h: moss along the foot, vines hanging from vineTop, stains, cracks, missing blocks
function K.weather(parent, F, w, h, rng, o)
	o = o or {}
	local yMin = o.yMin or 0
	for i = 1, (o.moss or math.floor(w / 14)) do
		local mw = rng:NextInteger(2, 5) * 2
		local mh = rng:NextInteger(1, 3) * 2
		if w > mw + 1 then
			local x = rng:NextNumber(-w / 2 + mw / 2, w / 2 - mw / 2)
			local y0 = o.mossY or 0
			K.part(parent, "Moss", Vector3.new(mw, mh, 0.9), F * CFrame.new(x, y0 + mh / 2, -0.35 - (i % 3) * 0.08), i % 3 == 0 and P.MossDark or P.Moss, { studs = K.FRONT, solid = false })
			if mw > 4 and rng:NextNumber() < 0.6 then
				K.part(parent, "Moss", Vector3.new(mw - 4, 2, 0.9), F * CFrame.new(x + rng:NextInteger(-1, 1), y0 + mh + 1, -0.42), P.Moss, { studs = K.FRONT, solid = false })
			end
		end
	end
	for _ = 1, (o.vines or 0) do
		local x = rng:NextNumber(-w / 2 + 3, w / 2 - 3)
		local top = o.vineTop or h
		local len = rng:NextNumber((top - yMin) * 0.15, (top - yMin) * 0.4)
		K.part(parent, "Vine", Vector3.new(1, len, 0.5), F * CFrame.new(x, top - len / 2, -0.4), P.Vine, { solid = false })
		for j = 1, math.floor(len / 5) do
			K.part(parent, "Leaf", Vector3.new(2.2, 1.6, 0.7), F * CFrame.new(x + (j % 2 == 0 and 1 or -1), top - j * 5 + rng:NextNumber(-1, 1), -0.55), P.Leaf, { solid = false })
		end
	end
	for _, p in o.stains or {} do
		local len = rng:NextNumber(8, 16)
		K.part(parent, "Stain", Vector3.new(p.w or 2, len, 0.2), F * CFrame.new(p.x, p.y - len / 2, -0.12), P.Stain, { solid = false, transparency = 0.55, shadow = false })
	end
	for _ = 1, (o.cracks or 1) do
		-- a crack carved into the stone: a stepped run of small set-in blocks a few shades darker than the stone there
		local x = math.floor(rng:NextNumber(-w * 0.4, w * 0.4) / 1.2) * 1.2
		local y = math.floor(rng:NextNumber(math.max(yMin, h * 0.2), h * 0.8) / 1.2) * 1.2
		local dir = rng:NextNumber() < 0.5 and -1 or 1
		local dark = shade(K.stone((F * CFrame.new(x, y, 0)).Position, y / h), -0.3)
		for j = 0, rng:NextInteger(3, 5) do
			local tall = j % 2 == 0
			local size = tall and Vector3.new(1.2, 2.4, 0.4) or Vector3.new(2.4, 1.2, 0.4)
			K.part(parent, "Crack", size, F * CFrame.new(x, y, -0.1 - (j % 2) * 0.06), dark, { solid = false, shadow = false })
			x += dir * (tall and 1.2 or 1.8)
			y -= tall and 1.8 or 1.2
		end
	end
	for _ = 1, (o.holes or 1) do
		local hw, hh = rng:NextInteger(2, 3) * 2, rng:NextInteger(1, 2) * 2
		local x, y = rng:NextNumber(-w * 0.4, w * 0.4), rng:NextNumber(math.max(yMin, h * 0.2), h * 0.8)
		K.part(parent, "MissingBlock", Vector3.new(hw, hh, 0.2), F * CFrame.new(x, y, -0.12), P.Socket, { solid = false, shadow = false })
		K.part(parent, "BrokenEdge", Vector3.new(hw * 0.5, 1, 0.6), F * CFrame.new(x + hw * 0.3, y - hh / 2 - 0.5, -0.3), P.Light, { solid = false })
	end
end

-- four parallel gouges raked diagonally across a face, centred at (x, y); len = the longest gouge
function K.claws(parent, F, x, y, len, rng)
	local ang = math.rad(-28)
	local ax, ay = math.cos(ang), math.sin(ang)
	for i = -1.5, 1.5 do
		local off = i * 7.5
		local l = len * (1 - math.abs(i) * 0.14)
		local c = F * CFrame.new(x + off * ax, y + off * ay + math.abs(i) * 2, 0) * CFrame.Angles(0, 0, ang)
		K.part(parent, "Gouge", Vector3.new(3.2, l, 0.3), c * CFrame.new(0, 0, -0.1), P.Crack, { solid = false, shadow = false })
		K.part(parent, "GougeEdge", Vector3.new(1, l * 0.92, 0.8), c * CFrame.new(2.1, 0, -0.35), P.Light, { solid = false })
		K.part(parent, "GougeEdge", Vector3.new(0.8, l * 0.84, 0.6), c * CFrame.new(-2, -l * 0.04, -0.25), P.Mid, { solid = false })
	end
end

------------------------------------------------------------------------------- signs, banners, flags
-- carved plaque: dark slate (or dark timber with o.wood) in a stone (or iron) frame with an inner gold line, gold
-- studs on the corners and Antique lettering in gold (o.cream: cream) with a dark stroke. cf faces the reader.
function K.sign(parent, name, cf, w, h, text, o)
	o = o or {}
	local m = K.model(parent, name)
	local board = K.part(m, "Board", Vector3.new(w, h, 1), cf, o.wood and P.TimberDark or P.Slate, { solid = false })
	local fw = math.max(0.8, h * 0.1)
	local fc = o.wood and P.Iron or P.Mid
	for _, e in {
		{ 0, h / 2 + fw / 2, w + fw * 2, fw },
		{ 0, -h / 2 - fw / 2, w + fw * 2, fw },
		{ w / 2 + fw / 2, 0, fw, h },
		{ -w / 2 - fw / 2, 0, fw, h },
	} do
		K.part(m, "Frame", Vector3.new(e[3], e[4], 1.8), cf * CFrame.new(e[1], e[2], -0.1), fc, { studs = K.FRONT, solid = false })
	end
	local g, inset = math.max(0.25, h * 0.04), h * 0.08
	for _, e in {
		{ 0, h / 2 - inset, w - inset * 2, g },
		{ 0, -h / 2 + inset, w - inset * 2, g },
		{ w / 2 - inset, 0, g, h - inset * 2 },
		{ -w / 2 + inset, 0, g, h - inset * 2 },
	} do
		K.part(m, "GoldLine", Vector3.new(e[3], e[4], 0.2), cf * CFrame.new(e[1], e[2], -0.55), P.Gold, { solid = false })
	end
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			K.part(m, "Stud", Vector3.new(fw * 1.3, fw * 1.3, 0.6), cf * CFrame.new(sx * (w / 2 + fw / 2), sy * (h / 2 + fw / 2), -1.1), P.Gold, { solid = false })
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = math.clamp(math.floor(110 / h), 4, 40) -- scaled text tops out at 100 px
	gui.LightInfluence = 0
	gui:SetAttribute("NoAutoGradient", true) -- WorldTextController leaves the carved lettering alone
	local l = Instance.new("TextLabel")
	l.Name = "Label"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(0.92, 0.8)
	l.Position = UDim2.fromScale(0.04, 0.1)
	l.Font = Enum.Font.Antique
	l.TextScaled = true
	l.TextColor3 = o.cream and P.SignCream or P.SignGold
	l.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = P.Ink
	stroke.Thickness = 3
	stroke.Parent = l
	l.Parent = gui
	gui.Parent = board
	return m
end

-- hanging banner: cf = the rod's centre, look vector = the side it faces. d = { cloth, trim, mark (emblem colour),
-- emblem = "claw" | "egg" | "skull" | "chevron" | "diamond", tail = "swallow" | "point" }
function K.banner(parent, cf, w, h, d)
	local m = K.model(parent, "Banner")
	K.part(m, "Rod", Vector3.new(w + 2, 0.9, 0.9), cf, P.Bronze, { solid = false })
	for _, sx in { -1, 1 } do
		K.part(m, "RodKnob", Vector3.new(1.5, 1.5, 1.5), cf * CFrame.new(sx * (w / 2 + 1.6), 0, 0), P.Gold, { solid = false })
	end
	local tail = math.min(6, h * 0.16)
	local body = h - tail
	local top = -0.45
	K.part(m, "Cloth", Vector3.new(w, body, 0.4), cf * CFrame.new(0, top - body / 2, 0), d.cloth, { solid = false })
	if d.tail == "point" then
		K.part(m, "Tail", Vector3.new(w * 0.66, tail * 0.5, 0.4), cf * CFrame.new(0, top - body - tail * 0.25, 0), d.cloth, { solid = false })
		K.part(m, "Tail", Vector3.new(w * 0.3, tail * 0.5, 0.4), cf * CFrame.new(0, top - body - tail * 0.75, 0), d.cloth, { solid = false })
	else
		for _, sx in { -1, 1 } do
			K.part(m, "Tail", Vector3.new(w * 0.4, tail, 0.4), cf * CFrame.new(sx * w * 0.3, top - body - tail / 2, 0), d.cloth, { solid = false })
		end
	end
	if d.trim then
		local tw = math.max(0.6, w * 0.07)
		for _, sx in { -1, 1 } do
			K.part(m, "Trim", Vector3.new(tw, body, 0.5), cf * CFrame.new(sx * (w / 2 - tw / 2), top - body / 2, -0.05), d.trim, { solid = false })
		end
		K.part(m, "Trim", Vector3.new(w, tw, 0.5), cf * CFrame.new(0, top - tw / 2 - h * 0.08, -0.05), d.trim, { solid = false })
	end
	local ey = top - body * 0.52
	local mk, e = d.mark or P.Gold, math.min(w * 0.6, body * 0.4)
	local function ep(nm, size, x, y, rot, col)
		local c = cf * CFrame.new(x, y, -0.12)
		if rot then
			c = c * CFrame.Angles(0, 0, rot)
		end
		K.part(m, nm, size, c, col or mk, { solid = false })
	end
	if d.emblem == "claw" then
		for i = -1, 1 do
			ep("Claw", Vector3.new(e * 0.14, e * (1 - math.abs(i) * 0.15), 0.4), i * e * 0.28, ey, math.rad(-18))
		end
	elseif d.emblem == "egg" then
		local rows = { 0.6, 0.88, 1, 0.96, 0.84, 0.62, 0.34 }
		local rh = e * 0.19
		for i, wf in rows do
			ep("Egg", Vector3.new(e * 0.72 * wf, rh, 0.4), 0, ey - e * 0.66 + (i - 0.5) * rh)
		end
	elseif d.emblem == "skull" then
		ep("Skull", Vector3.new(e * 0.62, e * 0.42, 0.4), 0, ey + e * 0.12)
		ep("Skull", Vector3.new(e * 0.4, e * 0.2, 0.4), 0, ey - e * 0.18)
		for _, sx in { -1, 1 } do
			K.part(m, "SkullEye", Vector3.new(e * 0.14, e * 0.12, 0.45), cf * CFrame.new(sx * e * 0.14, ey + e * 0.1, -0.16), d.cloth, { solid = false })
			ep("Horn", Vector3.new(e * 0.1, e * 0.42, 0.4), sx * e * 0.36, ey + e * 0.42, math.rad(-sx * 28))
		end
	elseif d.emblem == "chevron" then
		for _, sx in { -1, 1 } do
			ep("Chevron", Vector3.new(e * 0.16, e * 0.75, 0.4), sx * e * 0.22, ey, math.rad(sx * 40))
		end
	else
		ep("Diamond", Vector3.new(e * 0.5, e * 0.5, 0.4), 0, ey, math.rad(45))
	end
	K.wind(m)
	return m
end

-- flagpole standing on base, the flag flying towards +X (the same way everywhere)
function K.flagPole(parent, base, poleH, fw, fh, cloth, stripe)
	local m = K.model(parent, "FlagPole")
	K.part(m, "Pole", Vector3.new(0.8, poleH, 0.8), CFrame.new(base + Vector3.new(0, poleH / 2, 0)), P.IronLight, { solid = false })
	K.part(m, "PoleCap", Vector3.new(1.4, 1.4, 1.4), CFrame.new(base + Vector3.new(0, poleH + 0.7, 0)), P.Gold, { solid = false })
	local fm = K.model(m, "Flag")
	local fc = base + Vector3.new(0.4 + fw / 2, poleH - fh / 2 - 0.6, 0)
	K.part(fm, "Cloth", Vector3.new(fw, fh, 0.3), CFrame.new(fc), cloth, { solid = false })
	if stripe then
		K.part(fm, "Stripe", Vector3.new(fw, fh * 0.22, 0.36), CFrame.new(fc), stripe, { solid = false })
	end
	K.wind(fm)
	return m
end

------------------------------------------------------------------------------- fire
-- real fire: an invisible anchor at pos (the base of the flames) carrying a Fire effect and a warm orange PointLight
function K.flame(parent, pos, s, range)
	s = s or 1
	local a = K.part(parent, "Flame", Vector3.new(1, 1, 1), CFrame.new(pos + Vector3.new(0, 0.5, 0)), P.FlameA, { solid = false, transparency = 1, shadow = false })
	local fire = Instance.new("Fire")
	fire.Size = math.clamp(6 * s, 2, 30)
	fire.Heat = math.clamp(11 * s, 4, 25)
	fire.Color = Color3.fromRGB(255, 138, 36)
	fire.SecondaryColor = Color3.fromRGB(255, 62, 12)
	fire.Parent = a
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 148, 64)
	l.Range = range or math.max(14, 20 * s)
	l.Brightness = 1.8
	l.Shadows = false
	l.Parent = a
	return a
end

-- iron fire bowl on a stone foot, standing on pos
function K.brazier(parent, pos, s)
	s = s or 1
	local m = K.model(parent, "Brazier")
	local x, y, z = pos.X, pos.Y, pos.Z
	K.box(m, "Foot", x - 2.6 * s, x + 2.6 * s, y, y + 1.2 * s, z - 2.6 * s, z + 2.6 * s, P.Base, { studs = K.ALL })
	K.box(m, "Stem", x - 1.2 * s, x + 1.2 * s, y + 1.2 * s, y + 6 * s, z - 1.2 * s, z + 1.2 * s, P.Iron, { studs = K.SIDES })
	K.box(m, "Bowl", x - 3.4 * s, x + 3.4 * s, y + 6 * s, y + 8 * s, z - 3.4 * s, z + 3.4 * s, P.Iron, { studs = K.SIDES })
	K.box(m, "BowlRim", x - 3.8 * s, x + 3.8 * s, y + 8 * s, y + 8.6 * s, z - 3.8 * s, z + 3.8 * s, P.Bronze, { solid = false })
	K.box(m, "Coals", x - 3 * s, x + 3 * s, y + 8.6 * s, y + 9 * s, z - 3 * s, z + 3 * s, P.Ember, { neon = true, solid = false })
	K.flame(m, Vector3.new(x, y + 9 * s, z), s * 1.1, 26 * s)
	return m
end

-- wall torch: iron bracket out of the face at (x, y), a timber stick leaning out, an iron cup and a flame
function K.torch(parent, F, x, y)
	local m = K.model(parent, "Torch")
	K.part(m, "Bracket", Vector3.new(1.6, 2.4, 0.6), F * CFrame.new(x, y, -0.3), P.Iron, { solid = false })
	K.part(m, "Arm", Vector3.new(0.6, 0.6, 2.6), F * CFrame.new(x, y - 0.4, -1.6), P.Iron, { solid = false })
	K.part(m, "Stick", Vector3.new(0.8, 3.6, 0.8), F * CFrame.new(x, y + 0.8, -2.8) * CFrame.Angles(math.rad(-12), 0, 0), P.Timber, { solid = false })
	K.part(m, "Cup", Vector3.new(1.4, 0.8, 1.4), F * CFrame.new(x, y + 2.6, -3.15), P.Iron, { solid = false })
	K.part(m, "Embers", Vector3.new(1, 0.3, 1), F * CFrame.new(x, y + 3.1, -3.15), P.Ember, { neon = true, solid = false })
	K.flame(m, (F * CFrame.new(x, y + 3.1, -3.2)).Position, 0.6, 20)
	return m
end

------------------------------------------------------------------------------- gate furniture
-- iron portcullis in the plane x = xc across z -half..half, from y0 (spike tips) up to y1
function K.portcullis(parent, xc, half, y0, y1)
	local m = K.model(parent, "Portcullis")
	for z = -half + 3, half - 3, 6 do
		K.box(m, "Bar", xc - 0.7, xc + 0.7, y0 + 2, y1, z - 0.7, z + 0.7, P.Iron, { solid = false })
		K.box(m, "Spike", xc - 0.4, xc + 0.4, y0, y0 + 2, z - 0.4, z + 0.4, P.IronLight, { solid = false })
	end
	for y = y0 + 4, y1 - 2, 6 do
		K.box(m, "Band", xc - 1, xc + 1, y, y + 1.6, -half, half, P.IronLight, { studs = K.SIDES, solid = false })
	end
	return m
end

-- iron-banded timber gate leaf lying flat against a face; F = the face frame at the leaf's bottom centre
function K.gateLeaf(parent, F, w, h)
	local m = K.model(parent, "GateLeaf")
	local planks = math.max(3, math.floor(w / 9))
	local pw = w / planks
	for i = 0, planks - 1 do
		K.part(m, "Plank", Vector3.new(pw, h, 1.4), F * CFrame.new(-w / 2 + (i + 0.5) * pw, h / 2, -0.7), i % 2 == 0 and P.Timber or P.TimberDark, { studs = K.FRONT })
	end
	for _, y in { h * 0.1, h * 0.36, h * 0.62, h * 0.86 } do
		K.part(m, "IronBand", Vector3.new(w, 2.4, 0.6), F * CFrame.new(0, y, -1.65), P.Iron, { solid = false })
		for i = 1, planks - 1, 2 do
			K.part(m, "Rivet", Vector3.new(1, 1, 0.4), F * CFrame.new(-w / 2 + i * pw, y, -2.05), P.Bronze, { solid = false })
		end
	end
	for _, sx in { -1, 1 } do
		K.part(m, "IronEdge", Vector3.new(2, h, 0.6), F * CFrame.new(sx * (w / 2 - 1), h / 2, -1.7), P.Iron, { solid = false })
	end
	local rp = F * CFrame.new(w * 0.32, h * 0.48, -2.1)
	K.part(m, "RingPlate", Vector3.new(3.6, 3.6, 0.4), rp, P.Bronze, { solid = false })
	for _, e in { { 0, -4.4, 4.6, 0.8 }, { 0, -0.6, 4.6, 0.8 }, { -1.9, -2.5, 0.8, 4.6 }, { 1.9, -2.5, 0.8, 4.6 } } do
		K.part(m, "Ring", Vector3.new(e[3], e[4], 0.8), rp * CFrame.new(e[1], e[2], -0.3), P.IronLight, { solid = false })
	end
	return m
end

------------------------------------------------------------------------------- the kaiju crest
-- The citadel's emblem: a carved golden kaiju head (horns, V brow, ember eyes, snout, fangs, jaw) on a deep red shield
-- with a gold border. cf = the centre of the shield's face on the wall, look vector = outwards; s = scale (1: the
-- shield is 33 wide and about 40 tall, the horns reach 6 above it).
function K.crest(parent, cf, s)
	s = s or 1
	local m = K.model(parent, "KaijuCrest")
	local function cp(name, size, pos, color, rot, o)
		local c = cf * CFrame.new(pos * s)
		if rot then
			c = c * rot
		end
		return K.part(m, name, size * s, c, color, o or { studs = K.FRONT, solid = false })
	end
	-- the shield: gold behind, deep red in front, stepping to a point
	local field = { { 30, 26, 4 }, { 24, 4, -11 }, { 16, 4, -15 }, { 8, 3, -18.5 } } -- { width, height, centre y }
	for i, r in field do
		cp("CrestBorder", Vector3.new(r[1] + 3.2, r[2] + (i == 1 and 3.2 or 0), 1), Vector3.new(0, r[3], -0.5), P.Gold)
		cp("CrestField", Vector3.new(r[1], r[2], 1), Vector3.new(0, r[3], -1.2), P.Red)
	end
	cp("CrestBorder", Vector3.new(4.4, 1.6, 1), Vector3.new(0, -20.8, -0.5), P.Gold)
	-- the golden head, carved in relief (deep gold body, bright gold ridges)
	cp("Cranium", Vector3.new(12, 10, 2), Vector3.new(0, 6, -2.6), P.GoldPale)
	cp("Snout", Vector3.new(8, 6, 2.6), Vector3.new(0, -0.5, -2.9), P.Gold)
	cp("Jaw", Vector3.new(7, 2, 2), Vector3.new(0, -7.2, -2.6), P.Bronze)
	for _, sx in { -1, 1 } do
		cp("Horn", Vector3.new(2.4, 11, 2), Vector3.new(sx * 7.6, 15, -2.4), P.Gold, CFrame.Angles(0, 0, -sx * math.rad(28)))
		cp("HornTip", Vector3.new(1.4, 5, 1.8), Vector3.new(sx * 11.2, 22, -2.4), P.GoldPale, CFrame.Angles(0, 0, -sx * math.rad(38)))
		cp("Brow", Vector3.new(7, 2, 2.6), Vector3.new(sx * 3.8, 9.2, -3.8), P.Gold, CFrame.Angles(0, 0, sx * math.rad(15)))
		cp("Eye", Vector3.new(3.4, 1.4, 0.6), Vector3.new(sx * 3.8, 6.4, -3.7), P.Ember, nil, { neon = true, solid = false })
		cp("Nostril", Vector3.new(1.2, 1, 0.4), Vector3.new(sx * 1.6, 1.4, -4.3), P.RedDark)
		cp("CheekSpike", Vector3.new(2, 5, 1.6), Vector3.new(sx * 7.4, 1.5, -2.4), P.Gold, CFrame.Angles(0, 0, sx * math.rad(30)))
	end
	for _, x in { -3, -1, 1, 3 } do
		cp("Fang", Vector3.new(1.2, math.abs(x) == 3 and 3.4 or 2.4, 1), Vector3.new(x, math.abs(x) == 3 and -4.9 or -4.4, -3.2), P.GoldPale)
	end
	for _, sx in { -1, 1 } do
		cp("Rivet", Vector3.new(2, 2, 0.6), Vector3.new(sx * 13, 15.5, -2), P.Gold)
	end
	return m
end

------------------------------------------------------------------------------- the kaiju skull trophy
-- A front-facing kaiju skull that reads from below and far away: deep dark eye sockets with embers inside under a
-- heavy V brow, cheekbones, a short muzzle with a dark nasal cavity on its front, a row of upper teeth, the lower jaw
-- dropped open with its own teeth over a dark mouth, horns sweeping up and back, on a red shield bolted to the wall.
-- cf = the mount point on the wall, look vector = the way the skull faces. s = scale (1: cranium 34 wide, the face
-- 20 out from the wall, the muzzle front 32 out, horn tips 53 above the mount).
function K.skull(parent, cf, s)
	s = s or 1
	local m = K.model(parent, "KaijuSkull")
	local FLAT = { solid = false, shadow = false }
	local function sp(name, size, pos, color, rot, o)
		local c = cf * CFrame.new(pos * s)
		if rot then
			c = c * rot
		end
		return K.part(m, name, size * s, c, color, o or { studs = K.ALL, solid = false })
	end
	-- the trophy board
	sp("Shield", Vector3.new(54, 40, 1.6), Vector3.new(0, 6, -0.8), P.Red, nil, { studs = K.FRONT, solid = false })
	sp("Shield", Vector3.new(40, 6, 1.6), Vector3.new(0, -17, -0.8), P.Red, nil, { studs = K.FRONT, solid = false })
	sp("ShieldRim", Vector3.new(57, 1.6, 1.2), Vector3.new(0, 26.8, -1.4), P.Gold)
	for _, sx in { -1, 1 } do
		sp("ShieldRim", Vector3.new(1.6, 40, 1.2), Vector3.new(sx * 27.8, 6, -1.4), P.Gold)
		sp("Bolt", Vector3.new(3, 3, 1), Vector3.new(sx * 23, 22, -1.9), P.Iron)
		sp("Bolt", Vector3.new(3, 3, 1), Vector3.new(sx * 23, -9, -1.9), P.Iron)
	end
	-- cranium, dome, crest
	sp("Cranium", Vector3.new(34, 26, 20), Vector3.new(0, 9, -10), P.Bone)
	sp("Dome", Vector3.new(26, 6, 16), Vector3.new(0, 24, -9), P.Bone)
	sp("Crest", Vector3.new(8, 6, 14), Vector3.new(0, 29, -8), P.BoneShade)
	sp("Crest", Vector3.new(4, 4, 10), Vector3.new(0, 33, -6), P.BoneDark)
	-- the face: deep sockets framed by temples, a heavy V brow and cheekbones, embers far inside
	for _, sx in { -1, 1 } do
		sp("EyeSocket", Vector3.new(10.5, 12, 0.3), Vector3.new(sx * 8.75, 11, -20.15), P.Socket, nil, FLAT)
		sp("Ember", Vector3.new(3.6, 2.4, 0.4), Vector3.new(sx * 8.75, 10.5, -20.45), P.Ember, nil, { neon = true, solid = false })
		sp("Temple", Vector3.new(4, 14, 6), Vector3.new(sx * 16, 10, -23), P.BoneShade)
		sp("Brow", Vector3.new(18, 6, 9), Vector3.new(sx * 9, 19.5, -24.5), P.BoneShade, CFrame.Angles(0, 0, math.rad(sx * 10)))
		sp("Cheekbone", Vector3.new(13, 5, 5), Vector3.new(sx * 11, 2.5, -22.5), P.Bone)
		sp("CheekFlare", Vector3.new(5, 6, 8), Vector3.new(sx * 19, 2, -17), P.BoneShade)
		sp("Strap", Vector3.new(3, 1.2, 18), Vector3.new(sx * 9, 27.6, -9), P.Iron)
	end
	sp("BrowKnot", Vector3.new(7, 5, 8), Vector3.new(0, 17, -25), P.BoneShade)
	sp("NoseBridge", Vector3.new(7, 10, 5), Vector3.new(0, 11, -22.5), P.Bone)
	sp("FaceGap", Vector3.new(9, 5, 0.3), Vector3.new(0, 2.5, -20.15), P.Socket, nil, FLAT)
	-- the muzzle with the nasal cavity (split by a thin septum) on its front and the upper teeth along its edge
	sp("Muzzle", Vector3.new(26, 11, 12), Vector3.new(0, -6.5, -26), P.Bone)
	sp("Nasal", Vector3.new(8, 3, 0.3), Vector3.new(0, -4.5, -32.15), P.Socket, nil, FLAT)
	sp("Nasal", Vector3.new(4.5, 2.2, 0.3), Vector3.new(0, -2.2, -32.15), P.Socket, nil, FLAT)
	sp("Septum", Vector3.new(1.2, 4.4, 0.5), Vector3.new(0, -3.6, -32.3), P.BoneShade, nil, FLAT)
	sp("MouthShadow", Vector3.new(24, 14, 0.6), Vector3.new(0, -19, -22), P.Socket, nil, FLAT)
	for i = -4, 4 do
		local canine = math.abs(i) == 4
		local len = canine and 8 or (math.abs(i) == 3 and 5 or 4)
		local w = canine and 2.4 or 1.9
		sp("Tooth", Vector3.new(w, len, w), Vector3.new(i * 2.75, -12 - len / 2, -30.8), P.Tooth)
	end
	-- cracks: stepped runs of set-in darker bone blocks
	for j = 0, 3 do
		sp("Crack", j % 2 == 0 and Vector3.new(1.2, 0.4, 2.4) or Vector3.new(2.4, 0.4, 1.2), Vector3.new(-8 + j * 1.6, 27.1, -4 - j * 1.8), P.BoneDark, nil, FLAT)
		sp("Crack", j % 2 == 0 and Vector3.new(1.2, 2.4, 0.4) or Vector3.new(2.4, 1.2, 0.4), Vector3.new(7 + j * 1.5, -2.5 - j * 1.8, -32.1), P.BoneDark, nil, FLAT)
	end
	-- the lower jaw, dropped open, teeth up
	local J = cf * CFrame.new(Vector3.new(0, -12, -6) * s) * CFrame.Angles(math.rad(-24), 0, 0)
	local function jp(name, size, pos, color)
		return K.part(m, name, size * s, J * CFrame.new(pos * s), color, { studs = K.ALL, solid = false })
	end
	for _, sx in { -1, 1 } do
		jp("Jaw", Vector3.new(5, 5, 26), Vector3.new(sx * 10.5, -2.5, -13), P.BoneShade)
	end
	jp("Chin", Vector3.new(26, 5, 5), Vector3.new(0, -2.5, -26), P.BoneShade)
	for i = -3, 3 do
		local canine = math.abs(i) == 3
		local len = canine and 6.5 or 4
		local w = canine and 2.2 or 1.7
		jp("LowerTooth", Vector3.new(w, len, w), Vector3.new(i * 3.2, len / 2, -26.6), P.Tooth)
	end
	-- horns: chains of tapering blocks sweeping up and back, bronze-ringed at the root; short cheek horns
	local function chain(pts, widths, c0, c1, ring)
		for i = 1, #pts - 1 do
			local a, b = cf * (pts[i] * s), cf * (pts[i + 1] * s)
			local d = b - a
			local mid = (a + b) / 2
			local w = widths[i] * s
			K.part(m, "Horn", Vector3.new(w, d.Magnitude + w * 0.5, w), CFrame.lookAt(mid, mid + d) * CFrame.Angles(math.rad(90), 0, 0), i <= #pts / 2 and c0 or c1, { studs = K.SIDES, solid = false })
			if ring and i == 1 then
				local at = a + d.Unit * 2 * s
				K.part(m, "HornRing", Vector3.new(w + 1.6 * s, 2.2 * s, w + 1.6 * s), CFrame.lookAt(at, at + d) * CFrame.Angles(math.rad(90), 0, 0), P.Bronze, { studs = K.SIDES, solid = false })
			end
		end
	end
	for _, sx in { -1, 1 } do
		chain({ Vector3.new(sx * 13, 18, -8), Vector3.new(sx * 20, 26, -6), Vector3.new(sx * 25, 35, -5), Vector3.new(sx * 26, 45, -4), Vector3.new(sx * 23, 53, -3) }, { 7, 6, 4.8, 3.6 }, P.BoneShade, P.BoneDark, true)
		chain({ Vector3.new(sx * 19, 2, -16), Vector3.new(sx * 26, 5, -14), Vector3.new(sx * 31, 10, -12) }, { 4.5, 3 }, P.BoneShade, P.BoneDark, false)
	end
	return m
end

return K
