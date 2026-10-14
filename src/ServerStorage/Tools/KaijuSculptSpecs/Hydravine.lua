local rad = math.rad
local H = require(script.Parent.Helpers)

-- Venom Jungle / Mythic / poison: a three-headed vine hydra. A huge serpent body lying in a thick coil, scales shading
-- from bark-brown and dark green on the back to a pale belly, wound with thorned vines, glowing lime seams sunk in the
-- flanks, roots spreading from its belly into the ground. Three long thick necks rear high out of the front of the coil
-- and fan out wide, each with its own big head: in the middle a giant flytrap maw (two leaf jaws lined with spines,
-- a dark recessed throat glowing magenta at the rims), on the left a fanged viper dripping venom, on the right a head
-- crowned with a great poison bloom. Heavy brows, small lime eyes, purple spines down every neck.
local HF = CFrame.new(0, 3.72, -1.34) * CFrame.Angles(rad(-8), 0, 0) -- the flytrap's hinge
local SIDE = 1.25 -- the side heads' size (about 80% of the flytrap head)

local function sideFrame(x)
	return CFrame.lookAt(Vector3.new(2.0 * x, 3.46, -0.86), Vector3.new(2.62 * x, 3.22, -2.04))
end

return {
	Seed = 449,
	Vary = 0.05,
	Scale = 1.25,
	Gait = "Slither",
	Emotes = { "RearUp", "Look" },
	Palette = {
		Hide = { "4A7636", Material = "Slate" },
		HideDark = { "2C4622", Material = "Slate" },
		HideLight = { "88AC58", Material = "Slate" },
		Back = { "33241A", Material = "Wood" },
		Bark = { "6A4A2E", Material = "Wood" },
		Belly = "DCD4A2",
		Belly2 = "C4BC88",
		SeamLip = { "1C2814", Material = "Slate" },
		Vine = "3E6024",
		Leaf = "6FAA38",
		LeafDark = "4A8028",
		Thorn = "D8C8A0",
		Spine = "7A2CB8",
		SpineTip = "C9A8F0",
		Petal = "8A34C8",
		Petal2 = "B8308A",
		PetalDark = "5E2392",
		Venom = { "58D22E", Neon = true },
		MawGlow = { "E0408A", Neon = true },
		MawDeep = "3A0A1E",
		MawMid = "7A1A44",
		MawLip = "B0306A",
		Cilia = "D6DC8A",
		CiliaTip = "F2F0D0",
		Fang = "F0E8D0",
		Tooth = "EEE8D0",
		Mouth = "2A1A12",
		MouthGlow = { "58D22E", Neon = true },
		Eye = { "6FE83A", Neon = true },
		Socket = "0C1208",
	},
	Joints = {
		Neck = { 0, 0.72, 0.05 },
		Seg1 = { 0, 0.72, 0.3 },
		Seg2 = { 0, 0.7, 1.44 },
		Seg3 = { 0, 0.64, 2.62 },
		Seg4 = { 0, 0.56, 3.72 },
		Tail = { 0, 0.46, 4.72 },
		Head = { 0, 3.62, -1.22 },
		Jaw = HF.Position,
		Tongue = HF * Vector3.new(0, 0, -0.6),
	},
	Parents = H.SERPENT_PARENTS,
	Build = function(K)
		local skin = H.skin({ stripe = 32, band = 66, flank = 104, every = 2, upper = "HideDark" })
		local crust = { w = 0.62, l = 0.44, t = 0.14, lift = 6, jitter = 2, sink = 0.5, overlap = 0.95 }
		local belly = { key = "Belly", key2 = "Belly2", arc = 44, t = 0.12, wide = 1.1 }
		local function tube(group, nodes, tile)
			return K:tube(group, nodes, { step = 0.42, core = "HideDark", coreScale = 0.8, tile = tile or crust, belly = belly, color = skin })
		end
		-- thorned vines wound round a tube, leaves on them
		local function vines(group, samples, turns, from, to)
			local n = math.floor((to - from) / 0.2)
			for i = 0, n do
				local s = from + (to - from) * i / n
				local smp = K:at(samples, s)
				local th = i / n * math.pi * 2 * turns
				local pos, nrm = K:surface(smp, th, -0.06)
				local dir = (smp.T * 0.7 + (smp.U * math.cos(th + math.pi / 2) + smp.R * math.sin(th + math.pi / 2)) * 0.7).Unit
				K:block(group, "Vine", CFrame.lookAt(pos, pos + dir), Vector3.new(0.14, 0.14, 0.22))
				if i % 4 == 0 then
					K:block(group, i % 8 == 0 and "Leaf" or "LeafDark", CFrame.fromMatrix(pos + nrm * 0.08, dir, nrm) * CFrame.Angles(0, rad(35), 0), Vector3.new(0.32, 0.04, 0.18))
				elseif i % 4 == 2 then
					K:spike(group, "Thorn", pos, nrm, dir, 0.16, 0.05)
				end
			end
		end
		local function dress(group, samples, spineH, veins)
			K:ridge(group, samples, { every = 0.42, height = spineH, thick = 0.12, key = "Spine", tip = "SpineTip", lean = 34, sink = 0.85 })
			if veins then
				for _, x in { 1, -1 } do
					H.vein(K, group, "Venom", samples, rad(78) * x, 0.08, samples.total - 0.08, { width = 0.08, height = 0.12, lift = 0.05, wander = 16, step = 0.36, lip = "SeamLip", lipW = 0.08 })
				end
			end
		end

		-- the coil: four thick segments and the tail (lying on the ground)
		local function seg(group, z0, z1, r0, r1, trim)
			return tube(group, {
				{ 0, r0 * 0.94, z0, rx = r0, ru = r0 * 0.94, rd = r0 * 0.84 },
				{ 0, (r0 + r1) / 2 * 0.94, (z0 + z1) / 2, rx = (r0 + r1) / 2, ru = (r0 + r1) / 2 * 0.94, rd = (r0 + r1) / 2 * 0.84 },
				{ 0, r1 * 0.94, z1, rx = r1, ru = r1 * 0.94, rd = r1 * 0.84 },
			})
		end
		local segs = {
			Seg1 = seg("Seg1", 0.1, 1.56, 0.8, 0.76),
			Seg2 = seg("Seg2", 1.34, 2.78, 0.76, 0.68),
			Seg3 = seg("Seg3", 2.56, 3.86, 0.68, 0.56),
			Seg4 = seg("Seg4", 3.66, 4.86, 0.56, 0.42),
		}
		segs.Tail = tube("Tail", {
			{ 0, 0.4, 4.66, rx = 0.42, ru = 0.4, rd = 0.36 },
			{ 0.1, 0.28, 5.4, rx = 0.26, ru = 0.24, rd = 0.22 },
			{ 0.3, 0.18, 6.1, rx = 0.1, ru = 0.1, rd = 0.09 },
		}, { w = 0.4, n = 5, l = 0.3, t = 0.11, lift = 6, jitter = 2, sink = 0.5, overlap = 0.95 })
		for g, smps in segs do
			dress(g, smps, g == "Tail" and 0.22 or 0.36, g ~= "Tail" and g ~= "Seg4")
			if g ~= "Seg4" then
				vines(g, smps, 1.2, 0.05, smps.total - (g == "Tail" and 0.3 or 0.05))
			end
		end
		-- roots spreading from under the front coils into the ground
		for i, r in { { "Seg1", 0.4, 1 }, { "Seg1", 1.1, -1 }, { "Seg2", 0.5, 1 }, { "Seg2", 1.2, -1 }, { "Seg1", 0.8, -1 }, { "Seg2", 0.9, 1 } } do
			local smp = K:at(segs[r[1]], r[2])
			local x = r[3]
			local p0 = smp.p + smp.R * x * smp.rx * 0.8 - smp.U * smp.rd * 0.5
			local out = (smp.R * x + smp.T * (i % 2 == 0 and 0.4 or -0.3)).Unit
			local pts = { p0, p0 + out * 0.6 + Vector3.new(0, -0.18, 0), p0 + out * 1.2 + Vector3.new(0, -0.34, 0), p0 + out * 1.7 + Vector3.new(0, -0.42, 0) }
			for j = 1, #pts do
				pts[j] = Vector3.new(pts[j].X, math.max(pts[j].Y, 0.06), pts[j].Z)
			end
			H.curve(K, r[1], { "Bark", "Bark", "Back", "Venom" }, pts, 0.24, 0.07, 0.14)
		end

		-- the three necks rearing high out of the front of the coil (head end first, so the scales lean back)
		local neck = tube("Neck", {
			{ 0, 3.62, -1.22, rx = 0.44, ru = 0.42, rd = 0.46 },
			{ 0, 3.0, -1.14, rx = 0.52, ru = 0.5, rd = 0.54 },
			{ 0, 2.2, -0.86, rx = 0.6, ru = 0.58, rd = 0.62 },
			{ 0, 1.38, -0.42, rx = 0.68, ru = 0.66, rd = 0.68 },
			{ 0, 0.86, 0.12, rx = 0.74, ru = 0.72, rd = 0.7 },
		})
		dress("Neck", neck, 0.4, true)
		vines("Neck", neck, 1.6, 0.4, neck.total - 0.1)
		for _, x in { 1, -1 } do
			local F = sideFrame(x)
			local sn = tube("Neck", {
				{ F.Position.X, F.Position.Y, F.Position.Z, rx = 0.42, ru = 0.4, rd = 0.44 },
				{ 1.86 * x, 2.7, -0.66, rx = 0.5, ru = 0.48, rd = 0.52 },
				{ 1.38 * x, 1.86, -0.36, rx = 0.56, ru = 0.54, rd = 0.56 },
				{ 0.7 * x, 1.06, -0.02, rx = 0.62, ru = 0.6, rd = 0.6 },
				{ 0.2 * x, 0.74, 0.42, rx = 0.64, ru = 0.62, rd = 0.6 },
			})
			dress("Neck", sn, 0.32)
		end

		-- a side head (built SIDE times bigger round its neck end): a wedge skull under a heavy brow, small lime eyes, horns,
		-- an open mouth glowing lime deep inside
		local function sideHead(F, x, extra)
			K:scaled(F.Position, SIDE, function()
			local function cf(px, py, pz, ax, ay, az)
				return F * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
			end
			local function p(px, py, pz)
				return F * Vector3.new(px, py, pz)
			end
			local function v(px, py, pz)
				return F:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
			end
			K:block("Neck", "Hide", cf(0, 0.14, -0.28), Vector3.new(0.72, 0.52, 0.62))
			K:block("Neck", "Hide", cf(0, 0.06, -0.86), Vector3.new(0.54, 0.36, 0.7))
			K:block("Neck", "HideDark", cf(0, 0.04, -1.28, -4, 0, 0), Vector3.new(0.42, 0.28, 0.24))
			K:block("Neck", "Back", cf(0, 0.42, -0.36, -10, 0, 0), Vector3.new(0.54, 0.1, 0.6))
			K:block("Neck", "Mouth", cf(0, -0.14, -0.8), Vector3.new(0.46, 0.05, 0.9))
			K:block("Neck", "MouthGlow", cf(0, -0.15, -0.44), Vector3.new(0.2, 0.05, 0.24))
			K:block("Neck", "Hide", cf(0, -0.34, -0.72, 26, 0, 0), Vector3.new(0.46, 0.16, 0.9))
			for _, sx in { 1, -1 } do
				K:block("Neck", "Bark", cf(0.24 * sx, 0.4, -0.6, -8, -14 * sx, 22 * sx), Vector3.new(0.32, 0.16, 0.36))
				H.eye(K, "Neck", cf(0.3 * sx, 0.24, -0.66, 0, -30 * sx, 12 * sx), 0.13, 0.04)
				K:chain("Neck", { "Spine", "Spine", "SpineTip" }, p(0.22 * sx, 0.44, -0.2), v(0.32 * sx, 0.5, 0.8), v(1, 0, 0), { n = 3, len = 0.8, w0 = 0.14, w1 = 0.07, bend = 10 })
			end
			extra(cf, p, v)
			end)
		end
		-- left: the fanged viper, venom dripping from long fangs
		sideHead(sideFrame(1), 1, function(cf, p, v)
			for _, sx in { 1, -1 } do
				H.curve(K, "Neck", { "Fang", "Fang", "Fang" }, { p(0.18 * sx, -0.12, -1.06), p(0.2 * sx, -0.4, -1.12), p(0.17 * sx, -0.66, -1.04) }, 0.11, 0.04, 0.1)
				K:block("Neck", "Venom", CFrame.new(p(0.17 * sx, -0.78, -1.0)), Vector3.new(0.06, 0.12, 0.06))
				K:block("Neck", "Venom", CFrame.new(p(0.17 * sx, -0.98, -0.98)), Vector3.new(0.04, 0.16, 0.04))
				H.teeth(K, "Neck", "Tooth", p(0.22 * sx, -0.15, -0.5), p(0.19 * sx, -0.15, -0.98), 4, v(0, -1, 0), v(1, 0, 0), 0.08, 0.04)
			end
		end)
		-- right: crowned with a great poison bloom
		sideHead(sideFrame(-1), -1, function(cf, p, v)
			local c = p(0, 0.5, -0.06)
			for k = 0, 9 do
				local a = k / 10 * math.pi * 2
				local dir = v(math.cos(a), 0.9 + math.sin(a) * 0.35, math.sin(a) * 0.8 + 0.3)
				local across = dir:Cross(v(0, 1, 0))
				across = across.Magnitude > 1e-3 and across.Unit or v(1, 0, 0)
				local nrm = across:Cross(dir).Unit
				local key = k % 3 == 0 and "Petal2" or (k % 2 == 0 and "Petal" or "PetalDark")
				for j, sg in { { 0.22, 0.32 }, { 0.5, 0.5 }, { 0.78, 0.3 } } do
					K:block("Neck", key, CFrame.fromMatrix(c + dir * 0.95 * sg[1], across, nrm), Vector3.new(sg[2], 0.07, 0.34))
				end
				K:block("Neck", "Venom", CFrame.fromMatrix(c + dir * 0.5 + nrm * 0.04, across, nrm), Vector3.new(0.05, 0.03, 0.6))
			end
			local up, fwd = v(0, 1, 0), v(0, 0, -1)
			K:block("Neck", "Spine", CFrame.lookAt(c + up * 0.04, c + up * 0.04 + fwd, up) * CFrame.Angles(0, rad(45), 0), Vector3.new(0.3, 0.14, 0.3))
			K:block("Neck", "Venom", CFrame.lookAt(c + up * 0.1, c + up * 0.1 + fwd, up), Vector3.new(0.14, 0.08, 0.14))
			for _, sx in { 1, -1 } do
				H.teeth(K, "Neck", "Tooth", p(0.22 * sx, -0.15, -0.5), p(0.19 * sx, -0.15, -1.02), 5, v(0, -1, 0), v(1, 0, 0), 0.1, 0.05)
			end
		end)

		-- the middle head: a giant flytrap maw on a heavy bulb, small eyes under a bark brow on top
		K:block("Head", "Hide", HF * CFrame.new(0, 0.04, 0.22), Vector3.new(0.92, 0.86, 0.62))
		K:block("Head", "Back", HF * CFrame.new(0, 0.46, 0.2) * CFrame.Angles(rad(-10), 0, 0), Vector3.new(0.76, 0.14, 0.54))
		for _, sx in { 1, -1 } do
			K:block("Head", "Bark", HF * CFrame.new(0.3 * sx, 0.5, -0.02) * CFrame.Angles(rad(-8), rad(-14 * sx), rad(22 * sx)), Vector3.new(0.36, 0.16, 0.36))
			H.eye(K, "Head", HF * CFrame.new(0.38 * sx, 0.38, -0.06) * CFrame.Angles(0, rad(-34 * sx), rad(12 * sx)), 0.13, 0.04)
			K:chain("Head", { "Spine", "Spine", "SpineTip" }, HF * Vector3.new(0.28 * sx, 0.52, 0.3), HF:VectorToWorldSpace(Vector3.new(0.4 * sx, 0.6, 0.7)).Unit, HF:VectorToWorldSpace(Vector3.xAxis), { n = 3, len = 0.9, w0 = 0.16, w1 = 0.07, bend = 8 })
		end
		H.flytrap(K, { head = "Head", jaw = "Jaw", frame = HF * CFrame.new(0, 0, -0.06), size = 1.0, open = 24, keys = { shell = "Hide", shellDark = "HideDark", glow = "MawGlow", deep = "MawDeep", lining = "MawMid", lip = "MawLip", tooth = "Cilia", spine = "Cilia", spineTip = "CiliaTip" } })
		-- nectar dripping inside the maw (the tongue group)
		K:block("Tongue", "Venom", HF * CFrame.new(0, -0.06, -0.62), Vector3.new(0.12, 0.08, 0.5))
		K:block("Tongue", "Venom", HF * CFrame.new(0.1, -0.24, -0.9), Vector3.new(0.05, 0.26, 0.05))
	end,
}
