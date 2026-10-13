-- Shared helpers for the per-rarity egg specs (Tools.EggSpecs<Biome>, built by Tools.BiomeArtBuilder.BuildEgg): the egg's
-- shape, positions on it, raised panels, glowing grooves, tapered horns and tusks, voxel crystals, bushes and vines, and
-- the family gem. Everything returns Tools.KaijuBuilder shapes, so it all ends up as clean voxels.
-- The egg's front is -Z, its bottom sits at y = 0 and the shell fills EggConfig.Size (2.2 x 2.8 x 2.2).
-- Angles round the egg: a = 0 is the front, + towards +X. Arc coordinates on the shell: s = a * radius(y) (studs along
-- the surface from the front line, + towards +X) and y; masks get (s, y, a, p).
local Kit = {}

Kit.V = 0.1
local V = Kit.V
local rad, deg = math.rad, math.deg

local E1C, E1R = Vector3.new(0, 1.3, 0), Vector3.new(1.1, 1.3, 1.1)
local E2C, E2R = Vector3.new(0, 1.55, 0), Vector3.new(0.92, 1.25, 0.92)
Kit.LO, Kit.HI = Vector3.new(-1.9, 0, -1.9), Vector3.new(1.9, 3.6, 1.9)
Kit.TOP = 2.8

function Kit.radii(y)
	local r1 = E1R.X * math.sqrt(math.max(0, 1 - ((y - E1C.Y) / E1R.Y) ^ 2))
	local r2 = E2R.X * math.sqrt(math.max(0, 1 - ((y - E2C.Y) / E2R.Y) ^ 2))
	return r1, r2
end

-- radius of the shell at height y
function Kit.surface(y)
	return math.max(Kit.radii(y))
end

-- horizontal unit direction at angle a
function Kit.dir(a)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

-- point on (or `out` studs off) the shell at angle a, height y
function Kit.at(a, y, out)
	return Kit.dir(a) * (Kit.surface(y) + (out or 0)) + Vector3.new(0, y, 0)
end

-- degrees the shell's normal leans away from straight up at height y (0 = top, 90 = sideways, >90 = underside)
function Kit.normalTilt(y)
	local r1, r2 = Kit.radii(y)
	local h, v
	if r1 >= r2 then
		h, v = r1 / E1R.X ^ 2, (y - E1C.Y) / E1R.Y ^ 2
	else
		h, v = r2 / E2R.X ^ 2, (y - E2C.Y) / E2R.Y ^ 2
	end
	return deg(math.atan2(h, v))
end

function Kit.eul(cf)
	local x, y, z = cf:ToOrientation()
	return { deg(x), deg(y), deg(z) }
end

-- orientation whose +Y leans `tilt` degrees outwards at angle a, spun `spin` degrees about itself, then `extra`
function Kit.lean(a, tilt, spin, extra)
	return Kit.eul(CFrame.Angles(0, -a, 0) * CFrame.Angles(rad(-tilt), 0, 0) * CFrame.Angles(0, rad(spin or 0), 0) * (extra or CFrame.identity))
end

-- the up axis of Kit.lean(a, tilt)
function Kit.leanUp(a, tilt)
	return Vector3.yAxis * math.cos(rad(tilt)) + Kit.dir(a) * math.sin(rad(tilt))
end

-- inside the egg grown by `out` studs (negative shrinks it)
function Kit.inEgg(p, out)
	local g = Vector3.one * (out or 0)
	local d = (p - E1C) / (E1R + g)
	if d:Dot(d) <= 1 then
		return true
	end
	d = (p - E2C) / (E2R + g)
	return d:Dot(d) <= 1
end

-- arc coordinates of a point: s (studs along the shell from the front line), y, a
function Kit.arc(p)
	local a = math.atan2(p.X, -p.Z)
	return a * Kit.surface(p.Y), p.Y, a
end

-- smallest signed angle between two angles
function Kit.da(a, b)
	return (a - b + math.pi) % (math.pi * 2) - math.pi
end

function Kit.shell(color)
	return {
		{ Group = "Shell", Color = color, Kind = "Ellipsoid", C = E1C, R = E1R },
		{ Group = "Shell", Color = color, Kind = "Ellipsoid", C = E2C, R = E2R },
	}
end

-- a panel raised `out` studs off the shell wherever mask(s, y, a, p) holds (solid: it recolours the shell beneath too)
function Kit.panel(color, out, mask, group)
	return {
		Group = group or "Shell",
		Color = color,
		Kind = "Custom",
		Lo = Kit.LO,
		Hi = Kit.HI,
		Inside = function(p)
			if not Kit.inEgg(p, out) then
				return false
			end
			local s, y, a = Kit.arc(p)
			return mask(s, y, a, p)
		end,
	}
end

-- recolour the shell's skin (and raised panels on it) wherever mask(s, y, a, p) holds
function Kit.paint(color, mask, reach)
	reach = reach or V * 2.5
	return {
		Group = "Shell",
		Color = color,
		Kind = "Custom",
		Paint = true,
		Lo = Kit.LO,
		Hi = Kit.HI,
		Inside = function(p)
			if not Kit.inEgg(p, reach) then
				return false
			end
			local s, y, a = Kit.arc(p)
			return mask(s, y, a, p)
		end,
	}
end

-- split a path of {a, y} points into short segments (long chords would sink into the shell)
local function segments(points)
	local out = {}
	for i = 1, #points - 1 do
		local p, q = points[i], points[i + 1]
		local m = { (p[1] + q[1]) / 2, (p[2] + q[2]) / 2 }
		table.insert(out, { p, m })
		table.insert(out, { m, q })
	end
	return out
end

-- a glowing crack cut into the shell through {a, y} points: `w` = half width; `glow` lines it, `core` runs down the middle
function Kit.groove(shapes, points, w, glow, core)
	local segs = segments(points)
	for _, s in segs do
		table.insert(shapes, { Group = "Shell", Kind = "Capsule", Carve = true, A = Kit.at(s[1][1], s[1][2], 0.04), B = Kit.at(s[2][1], s[2][2], 0.04), R = w })
	end
	for _, s in segs do
		table.insert(shapes, { Group = "Shell", Color = glow, Kind = "Capsule", Paint = true, A = Kit.at(s[1][1], s[1][2], 0.02), B = Kit.at(s[2][1], s[2][2], 0.02), R = w + V * 0.9 })
	end
	if core then
		for _, s in segs do
			table.insert(shapes, { Group = "Shell", Color = core, Kind = "Capsule", Paint = true, A = Kit.at(s[1][1], s[1][2], 0.04 - w), B = Kit.at(s[2][1], s[2][2], 0.04 - w), R = V * 1.1 })
		end
	end
end

-- a raised stripe painted along the shell through {a, y} points (solid, `out` studs proud)
function Kit.ridge(shapes, points, w, color, out, group)
	for _, s in segments(points) do
		table.insert(shapes, { Group = group or "Shell", Color = color, Kind = "Capsule", A = Kit.at(s[1][1], s[1][2], (out or V) - w), B = Kit.at(s[2][1], s[2][2], (out or V) - w), R = w })
	end
end

-- a tapered chain of capsules: pts = { { position, radius, colour }, ... } (horns, tusks, trunks, tails, tufts)
function Kit.chain(shapes, group, pts)
	for i = 1, #pts - 1 do
		local p, q = pts[i], pts[i + 1]
		table.insert(shapes, { Group = group, Color = p[3], Kind = "Capsule", A = p[1], B = q[1], RA = p[2], RB = q[2] })
	end
end

-- a horn growing out of the shell at (a, y): leans `tilt` from upright towards the outside, bends `bend` degrees more
-- along its length; colours run base -> tip
function Kit.horn(shapes, group, a, y, len, r0, tilt, bend, colors, side)
	local pts = {}
	local p = Kit.at(a, y, -r0 * 0.6)
	local n = #colors
	local steps = math.max(n, 4)
	for k = 0, steps do
		local t = k / steps
		local up = Kit.leanUp(a + (side or 0) * t * 0.3, tilt + bend * t)
		table.insert(pts, { p, r0 * (1 - t * 0.85), colors[math.min(n, 1 + math.floor(t * n))] })
		p = p + up * (len / steps)
	end
	Kit.chain(shapes, group, pts)
end

-- a voxel crystal standing on `base`, leaning `tilt` at angle a: a square column (deep colour low, main colour high)
-- with a pointed tip
function Kit.crystal(shapes, group, base, a, tilt, w, h, deep, main, tip)
	local up = Kit.leanUp(a, tilt)
	local rot = Kit.lean(a, tilt, 45)
	table.insert(shapes, { Group = group, Color = deep, Kind = "Box", C = base + up * (h * 0.25), S = { w, h * 0.5, w }, Rot = rot })
	table.insert(shapes, { Group = group, Color = main, Kind = "Box", C = base + up * (h * 0.62), S = { w, h * 0.26, w }, Rot = rot })
	table.insert(shapes, { Group = group, Color = tip, Kind = "Capsule", A = base + up * (h * 0.72), B = base + up * (h * 1.02), RA = w * 0.6, RB = V * 0.3 })
end

-- a round leafy bush (dark body, lighter crown) at `c`
function Kit.bush(shapes, c, size, dark, mid, light, group)
	group = group or "Leaves"
	table.insert(shapes, { Group = group, Color = dark, Kind = "Ellipsoid", C = c, R = { size, size * 0.62, size } })
	table.insert(shapes, { Group = group, Color = mid, Kind = "Ellipsoid", C = c + Vector3.new(0, size * 0.3, 0), R = { size * 0.78, size * 0.5, size * 0.78 } })
	table.insert(shapes, { Group = group, Color = light, Kind = "Ellipsoid", Paint = true, C = c + Vector3.new(0, size * 0.62, 0), R = { size * 0.55, size * 0.22, size * 0.55 } })
end

-- leafy bushes round the base of the egg
function Kit.bushRing(shapes, n, size, phase, skip)
	for k = 0, n - 1 do
		local a = (k + (phase or 0)) / n * math.pi * 2
		if not (skip and skip(a)) then
			local s = size * (k % 2 == 0 and 1 or 0.82)
			local c = Kit.dir(a) * (Kit.surface(0.16) + s * 0.55) + Vector3.new(0, s * 0.45, 0)
			Kit.bush(shapes, c, s, "LeafDark", "Leaf", "LeafLight")
		end
	end
end

-- A cup of leaves the egg sits in: a collar hugging the shell up to `top`, `thick` studs proud and flaring out a little,
-- dark below and lighter along the rim (horizontal colour steps keep the brick count down), with `lobes` flat pointed
-- leaf tips standing round the rim.
function Kit.leafCollar(shapes, top, lobes, thick)
	top, lobes, thick = top or 0.3, lobes or 9, thick or 0.09
	table.insert(shapes, { Group = "Leaves", Color = "LeafDark", Kind = "Custom", Lo = Kit.LO, Hi = Kit.HI, Inside = function(p)
		return p.Y < top and Kit.inEgg(p, thick + p.Y * 0.15)
	end })
	table.insert(shapes, { Group = "Leaves", Color = "Leaf", Kind = "Custom", Paint = true, Lo = Kit.LO, Hi = Kit.HI, Inside = function(p)
		return p.Y >= top - 0.13 and p.Y < top and not Kit.inEgg(p, thick * 0.3)
	end })
	for k = 0, lobes - 1 do
		local a = (k + 0.5) / lobes * math.pi * 2
		local tilt = 18
		local up = Kit.leanUp(a, tilt)
		local base = Kit.dir(a) * (Kit.surface(top) + thick + 0.02) + Vector3.new(0, top - 0.06, 0)
		table.insert(shapes, { Group = "Leaves", Color = k % 2 == 0 and "Leaf" or "LeafLight", Kind = "Box", C = base + up * 0.1, S = { 0.32, 0.32, 0.1 }, Rot = Kit.lean(a, tilt, 0, CFrame.Angles(0, 0, math.rad(45))) })
	end
end

-- a small two-leaf sprout on the top
function Kit.sprout(shapes, top)
	top = top or Kit.TOP
	table.insert(shapes, { Group = "Sprout", Color = "Stem", Kind = "Capsule", A = Vector3.new(0, top - 0.05, 0), B = Vector3.new(0.02, top + 0.2, 0), R = 0.06 })
	for _, side in { 1, -1 } do
		local c = Vector3.new(side * 0.2, top + 0.26 + (side > 0 and 0.03 or 0), 0)
		table.insert(shapes, { Group = "Sprout", Color = side > 0 and "Leaf" or "LeafDark", Kind = "Ellipsoid", C = c, R = { 0.2, 0.06, 0.13 }, Rot = { 0, 0, side * 22 } })
		table.insert(shapes, { Group = "Sprout", Color = "LeafLight", Kind = "Ellipsoid", Paint = true, C = c + Vector3.new(side * 0.03, 0.04, 0), R = { 0.12, 0.04, 0.06 }, Rot = { 0, 0, side * 22 } })
	end
end

-- a vine wrapped round the egg at height y(a) = y0 + amp * sin(waves * a + phase), with leaves every `every` radians
-- (skip(a) leaves a gap, e.g. behind a trunk)
function Kit.vine(shapes, y0, amp, waves, every, skip)
	local n = 36
	local function y(a)
		return y0 + amp * math.sin(waves * a)
	end
	for k = 0, n - 1 do
		local a0, a1 = k / n * math.pi * 2, (k + 1) / n * math.pi * 2
		if not (skip and (skip(a0) or skip(a1))) then
			table.insert(shapes, { Group = "Vine", Color = "Vine", Kind = "Capsule", A = Kit.at(a0, y(a0), 0.02), B = Kit.at(a1, y(a1), 0.02), R = 0.06 })
		end
	end
	local k = 0
	for a = every / 2, math.pi * 2, every do
		if not (skip and skip(a)) then
			k += 1
			local side = k % 2 == 0 and 1 or -1
			local c = Kit.at(a, y(a) + side * 0.1, 0.1)
			table.insert(shapes, { Group = "Vine", Color = k % 3 == 0 and "LeafDark" or "Leaf", Kind = "Ellipsoid", C = c, R = { 0.13, 0.08, 0.13 } })
			table.insert(shapes, { Group = "Vine", Color = "LeafLight", Kind = "Ellipsoid", Paint = true, C = c + Vector3.new(0, 0.05, 0), R = { 0.09, 0.04, 0.09 } })
		end
	end
end

-- The family gem: a faceted voxel diamond on the front at height gy (half-diagonal R) in a raised frame of parts named
-- "Band" (Lib.EggModel tints them with the rarity colour), with four rays off its points for the top rarities.
-- Palette keys: Band, Socket, Gem, GemDeep, GemLight, GemCore.
function Kit.gem(shapes, gy, R, rays)
	local frame = R + 0.14
	local function front(p)
		local r = Kit.surface(p.Y)
		return -math.sqrt(math.max(0, r * r - p.X * p.X))
	end
	local reach = frame + 0.35
	local lo, hi = Vector3.new(-reach, gy - reach, -1.9), Vector3.new(reach, gy + reach, 0)
	local function l1(p)
		return math.abs(p.X) + math.abs(p.Y - gy)
	end
	-- raised frame
	table.insert(shapes, { Group = "Gem", Color = "Band", Kind = "Custom", Lo = lo, Hi = hi, Inside = function(p)
		if l1(p) > frame then
			return false
		end
		local z = front(p)
		return p.Z >= z - 0.15 and p.Z <= z + 0.14
	end })
	-- dark socket inside the frame
	table.insert(shapes, { Group = "Gem", Color = "Socket", Kind = "Custom", Lo = lo, Hi = hi, Inside = function(p)
		if l1(p) > R + 0.02 then
			return false
		end
		local z = front(p)
		return p.Z >= z - 0.04 and p.Z <= z + 0.14
	end })
	-- the gem itself: a low pyramid standing out of the socket
	table.insert(shapes, { Group = "Gem", Color = "Gem", Kind = "Custom", Lo = lo, Hi = hi, Inside = function(p)
		local l = l1(p)
		if l > R - V * 0.6 then
			return false
		end
		local z = front(p)
		return p.Z >= z - (0.08 + 0.17 * (1 - l / R)) and p.Z <= z + 0.12
	end })
	-- facets: deep lower right, light upper left, a white-hot core
	table.insert(shapes, { Group = "Gem", Color = "GemDeep", Kind = "Custom", Paint = true, Lo = lo, Hi = hi, Inside = function(p)
		return l1(p) < R and p.Y < gy - V * 0.4 and p.X < V * 0.4
	end })
	table.insert(shapes, { Group = "Gem", Color = "GemLight", Kind = "Custom", Paint = true, Lo = lo, Hi = hi, Inside = function(p)
		return l1(p) < R and p.Y > gy + V * 0.4 and p.X > -V * 0.4
	end })
	table.insert(shapes, { Group = "Gem", Color = "GemCore", Kind = "Custom", Paint = true, Lo = lo, Hi = hi, Inside = function(p)
		return math.abs(p.X - R * 0.12) + math.abs(p.Y - gy - R * 0.12) < R * 0.3
	end })
	if rays then
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local cx, cy = d[1] * (frame + 0.12), gy + d[2] * (frame + 0.12)
			table.insert(shapes, { Group = "Gem", Color = "Band", Kind = "Custom", Lo = lo, Hi = hi, Inside = function(p)
				if math.abs(p.X - cx) + math.abs(p.Y - cy) > 0.12 then
					return false
				end
				local z = front(p)
				return p.Z >= z - 0.1 and p.Z <= z + 0.14
			end })
		end
	end
end

-- particle presets for spec.FX (BiomeArtBuilder.BuildEgg puts them on the shell)
Kit.SPARKLE = "rbxassetid://14197626379"
Kit.GLITTER = "rbxassetid://106213021633252"
Kit.SPARK = "rbxassetid://278520320"
Kit.MOTE = "rbxassetid://134563328683175"

function Kit.twinkle(colors, rate, size)
	return { Texture = Kit.SPARKLE, Colors = colors, Rate = rate or 1.5, Size = { size or 0.45, 0 }, Lifetime = { 0.5, 0.9 }, Speed = { 0, 0.2 }, RotSpeed = { -90, 90 }, LightEmission = 1 }
end

return Kit
