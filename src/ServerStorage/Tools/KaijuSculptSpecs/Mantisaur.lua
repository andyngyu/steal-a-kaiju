local rad = math.rad
local H = require(script.Parent.Helpers)

-- Venom Jungle / Rare / poison: a mantis lizard. A heavy lizard on four powerful sprawled legs, its torso reared up
-- like a mantis's, holding two raptorial forelimbs folded and raised to strike, each ending in a huge serrated
-- bone-white scythe blade with a glowing venom groove. Jungle-green scales under bark-brown armour bands edged in
-- lime, bold purple fins down the back, a long tail with leaf plates. Face: an armoured wedge head, a heavy brow over
-- small lime eyes, a purple blade crest, a toothy half-open jaw.
local HEAD = CFrame.new(0, 3.62, -1.58) * CFrame.Angles(rad(-22), 0, 0)
local SKULL = { 0.68, 0.46, 0.56 }
local SH = { 0.48, 2.9, -1.04 } -- the left shoulder

return {
	Seed = 417,
	Vary = 0.05,
	Gait = "Crawl",
	Emotes = { "Look", "ClawSnap", "Roar" },
	Palette = {
		Hide = { "527E3A", Material = "Slate" },
		HideDark = { "35582A", Material = "Slate" },
		HideLight = { "74A04C", Material = "Slate" },
		Back = { "5A3E26", Material = "Wood" },
		Belly = "CFC690",
		Belly2 = "B4AA72",
		Armour = { "6A5236", Material = "Slate" },
		ArmourLight = { "8E7650", Material = "Slate" },
		Edge = { "A8FF3A", Neon = true },
		Venom = { "A8FF3A", Neon = true },
		Spine = "7A2CB8",
		SpineTip = "C9A8F0",
		Blade = "EDE6CC",
		BladeDark = "A89C78",
		Joint = "2A2018",
		Tooth = "E8E4C8",
		Mouth = "5A1A30",
		Eye = { "C6FF3A", Neon = true },
		Socket = "0E1408",
		Claw = "241C14",
		ClawTip = "D0C8A0",
	},
	Joints = {
		Head = { 0, 3.22, -1.2 },
		Jaw = HEAD * Vector3.new(0, 0, -SKULL[3] * 0.25),
		LegFL = { 0.6, 1.42, -0.4 },
		LegFR = { -0.6, 1.42, -0.4 },
		LegBL = { 0.62, 1.44, 0.84 },
		LegBR = { -0.62, 1.44, 0.84 },
		ClawL = SH,
		ClawR = { -SH[1], SH[2], SH[3] },
		Tail = { 0, 1.46, 0.8 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 32, band = 86, flank = 106, every = 2 })
		local crust = { w = 0.46, l = 0.32, t = 0.12, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.9 }
		local belly = { key = "Belly", key2 = "Belly2", arc = 40, t = 0.11, wide = 1.05 }
		local function tube(group, nodes, tile)
			return K:tube(group, nodes, { step = 0.3, core = "HideDark", coreScale = 0.86, tile = tile or crust, belly = belly, color = skin })
		end
		-- the lizard body, low and heavy
		local body = tube("Body", {
			{ 0, 1.48, -0.46, rx = 0.62, ru = 0.56, rd = 0.6 },
			{ 0, 1.52, 0.2, rx = 0.68, ru = 0.6, rd = 0.62 },
			{ 0, 1.46, 0.84, rx = 0.56, ru = 0.5, rd = 0.52 },
		})
		-- the torso reared up from its front, head first so the scales lean down
		local torso = tube("Body", {
			{ 0, 3.12, -1.16, rx = 0.42, ru = 0.42, rd = 0.46 },
			{ 0, 2.5, -0.98, rx = 0.52, ru = 0.5, rd = 0.56 },
			{ 0, 1.86, -0.68, rx = 0.6, ru = 0.56, rd = 0.62 },
		})
		local neck = tube("Head", {
			{ 0, 3.56, -1.44, rx = 0.28, ru = 0.28, rd = 0.3 },
			{ 0, 3.36, -1.3, rx = 0.36, ru = 0.36, rd = 0.38 },
			{ 0, 3.14, -1.18, rx = 0.42, ru = 0.42, rd = 0.44 },
		})
		local tail = tube("Tail", {
			{ 0, 1.46, 0.8, rx = 0.48, ru = 0.44, rd = 0.42 },
			{ 0, 1.36, 1.5, rx = 0.36, ru = 0.34, rd = 0.32 },
			{ 0.1, 1.18, 2.2, rx = 0.24, ru = 0.22, rd = 0.2 },
			{ 0.3, 1.0, 2.8, rx = 0.14, ru = 0.13, rd = 0.12 },
			{ 0.6, 0.9, 3.22, rx = 0.07, ru = 0.07, rd = 0.06 },
		}, { w = 0.36, n = 5, l = 0.28, t = 0.1, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.9 })
		-- bark armour bands round the reared torso, each edged in glowing lime
		for s = 0.12, torso.total - 0.1, 0.28 do
			local smp = K:at(torso, s)
			for k = -2, 2 do
				K:tile("Body", k % 2 == 0 and "Armour" or "ArmourLight", smp, rad(k * 32), 0.4, 0.2, 0.1, 12, 2, -0.4)
			end
			local pos, nrm = K:surface(smp, 0, -0.2)
			K:block("Body", "Edge", CFrame.fromMatrix(pos, smp.R, nrm), Vector3.new(0.56, 0.04, 0.05))
		end
		-- bold purple fins down the back and the tail, bark plates either side
		K:ridge("Body", body, { every = 0.3, height = function(u) return 0.46 - u * 0.12 end, thick = 0.08, key = "Spine", tip = "SpineTip", lean = 30, sink = 0.85, style = "plate", width = 0.7 })
		K:ridge("Tail", tail, { to = tail.total * 0.8, every = 0.3, height = function(u) return 0.36 - u * 0.24 end, thick = 0.07, key = "Spine", tip = "SpineTip", lean = 34, sink = 0.85, style = "plate", width = 0.7 })
		for _, seg in { { "Body", body }, { "Tail", tail } } do
			for s = 0.12, seg[2].total * 0.85, 0.34 do
				local smp = K:at(seg[2], s)
				for _, x in { 1, -1 } do
					K:tile(seg[1], "Back", smp, rad(30) * x, smp.rx * 0.6, 0.3, 0.1, 6, 3, 0.3)
				end
			end
		end
		for _, x in { 1, -1 } do
			H.vein(K, "Body", "Venom", body, rad(76) * x, 0.1, body.total - 0.1, { width = 0.06, height = 0.07, lift = 0.02, wander = 16, forks = 1 })
		end

		-- four powerful sprawled legs
		local function limb(_, ring)
			return ring % 2 == 0 and "Hide" or "HideDark"
		end
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.6 * x, 1.44, -0.4, 0.36 },
				{ 0.9 * x, 0.92, -0.56, 0.3 },
				{ 0.88 * x, 0.3, -0.5, 0.22 },
			}, { step = 0.24, cores = { "Hide", "HideDark" }, tiles = { crust, nil }, color = limb, foot = { size = Vector3.new(0.48, 0.24, 0.52), key = "HideDark" }, toes = 3, yaw = 14, claw = { len = 0.26, w = 0.08, curl = 30 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.62 * x, 1.46, 0.84, 0.42 },
				{ 0.9 * x, 0.98, 0.6, 0.34 },
				{ 0.9 * x, 0.56, 1.0, 0.25 },
				{ 0.88 * x, 0.22, 0.92, 0.2 },
			}, { step = 0.24, cores = { "Hide", "HideDark", "HideDark" }, tiles = { crust, nil, nil }, color = limb, foot = { size = Vector3.new(0.5, 0.24, 0.56), key = "HideDark" }, toes = 3, yaw = 10, claw = { len = 0.26, w = 0.08, curl = 30 } })
			K:tile(x == 1 and "LegBL" or "LegBR", "Armour", K:at(K:path({ { 0.62 * x, 1.46, 0.84, rx = 0.42 }, { 0.9 * x, 0.98, 0.6, rx = 0.34 } }, 0.2), 0.3), rad(90) * x, 0.5, 0.42, 0.12, 6, 2, 0.4)
		end

		-- the raptorial forelimbs: upper arm raised forward, forearm folded down, a huge serrated scythe blade
		for _, x in { 1, -1 } do
			local g = x == 1 and "ClawL" or "ClawR"
			local sh = Vector3.new(SH[1] * x, SH[2], SH[3])
			local el = Vector3.new(0.74 * x, 3.46, -1.66)
			local wr = Vector3.new(0.74 * x, 2.66, -1.92)
			local arm = H.limb(K, g, { { sh.X, sh.Y, sh.Z, 0.24 }, { el.X, el.Y, el.Z, 0.2 }, { wr.X, wr.Y, wr.Z, 0.16 } }, { step = 0.2, cores = { "Hide", "Armour" }, tiles = { crust, nil } })
			K:block(g, "Armour", CFrame.new(el) * CFrame.Angles(rad(30), 0, 0), Vector3.new(0.34, 0.3, 0.34))
			K:block(g, "Armour", CFrame.lookAt(el:Lerp(wr, 0.5) + Vector3.new(0.08 * x, 0, -0.04), wr) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.26, 0.26, (wr - el).Magnitude * 0.9))
			-- spines down the inner edge of the forearm
			for k = 1, 4 do
				local p = el:Lerp(wr, k / 5) + Vector3.new(0, 0, -0.1)
				K:chain(g, { "BladeDark", "Blade" }, p, Vector3.new(-0.2 * x, 0.2, -1).Unit, Vector3.yAxis, { n = 2, len = 0.26, w0 = 0.07, w1 = 0.04, bend = 0 })
			end
			-- the scythe: wide at the wrist, sweeping forward and up, teeth along its inner edge, a venom groove
			local pts = { wr, wr + Vector3.new(0.02 * x, -0.32, -0.46), wr + Vector3.new(0.04 * x, -0.2, -1.16), wr + Vector3.new(0.04 * x, 0.36, -1.66), wr + Vector3.new(0.02 * x, 0.86, -1.72) }
			H.curve(K, g, { "BladeDark", "Blade", "Blade", "Blade" }, pts, 0.3, 0.07, 0.11)
			H.curve(K, g, { "BladeDark", "Blade" }, { pts[2] + Vector3.new(0, 0.12, 0), pts[3] + Vector3.new(0, 0.16, 0), pts[4] + Vector3.new(0, 0.06, 0.1) }, 0.2, 0.06, 0.11)
			H.curve(K, g, { "Venom" }, { pts[2] + Vector3.new(0.1 * x, 0.04, 0), pts[3] + Vector3.new(0.1 * x, 0.06, 0), pts[4] + Vector3.new(0.08 * x, 0, 0.1) }, 0.05, 0.04, 0.12)
			for k = 1, 7 do
				local f = k / 8
				local p = f < 0.5 and pts[2]:Lerp(pts[3], f * 2) or pts[3]:Lerp(pts[4], (f - 0.5) * 2)
				K:spike(g, "Blade", p + Vector3.new(0, 0.16, 0), Vector3.new(0, 1, 0.4).Unit, Vector3.zAxis, 0.16, 0.05)
			end
		end

		-- the head: armoured wedge, heavy brow over small lime eyes, purple blade crest
		local R = H.reptileHead(K, {
			frame = HEAD,
			skull = SKULL,
			snout = { 0.52, 0.36, 0.48 },
			tip = { 0.4, 0.28, 0.28 },
			open = 26,
			teeth = { 0.1, 0.06 },
			brow = "Armour",
			browSize = { 0.4, 0.2, 0.44 },
			eye = { 0.14, 0.045 },
			cheek = 0.26,
		})
		K:plate("Head", { "Armour", "ArmourLight", "Spine" }, R.p(0, R.top - 0.02, -0.5), R.v(0, 1, 0.1), R.v(0, 0, 1), { h = 0.34, w = 0.7, t = 0.12, n = 3, lean = 30 })
		K:plate("Head", { "Spine", "Spine", "SpineTip" }, R.p(0, R.top, -0.1), R.v(0, 1, 0.3), R.v(0, 0, 1), { h = 0.7, w = 0.66, t = 0.08, n = 3, lean = 40 })
		for _, x in { 1, -1 } do
			K:block("Head", "ArmourLight", R.cf(0.22 * x, R.top + 0.02, -0.82, -14, 0, 14 * x), Vector3.new(0.24, 0.1, 0.4))
			K:spike("Head", "Armour", R.p(0.34 * x, R.top - 0.06, -0.12), R.v(0.6 * x, 0.6, 0.5), R.v(0, 0, 1), 0.26, 0.08)
		end
		K:ridge("Head", neck, { every = 0.16, height = 0.18, thick = 0.06, key = "Spine", tip = "SpineTip", lean = 40, sink = 0.8 })
	end,
}
