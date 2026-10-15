local rad = math.rad
local H = require(script.Parent.Helpers)

-- Cosmic Rift / Mythic / void: the astral wyrm, a star dragon. A powerful four-legged dragon with a long neck and tail,
-- void-black scales flecked with stars, a violet belly, a nebula glowing pink and violet in its chest. Two huge
-- constellation wings: black membranes stretched between long bones, pinned with bright stars joined by glowing lines
-- like star charts. Head: a horned dragon skull crowned with long silver horns and crystal shards, starlight eyes, a
-- fanged jaw glowing deep inside.
local HEAD = CFrame.new(0, 4.0, -2.3) * CFrame.Angles(rad(-8), 0, 0)
local SKULL = { 0.64, 0.5, 0.6 }
local WING_ROOT = Vector3.new(0.5, 2.9, -0.5)

return {
	Seed = 751,
	Vary = 0.04,
	Scale = 1.25,
	Gait = "Trot",
	Emotes = { "Look", "PlayBow", "Paw" },
	Palette = {
		Hide = { "241C3A", Material = "Slate" },
		HideDark = { "130F20", Material = "Slate" },
		HideLight = { "3C3260", Material = "Slate" },
		Back = { "0B0912", Material = "Slate" },
		Belly = "5A4A88",
		Belly2 = "4A3C74",
		Membrane = "120E1E",
		MembraneLight = "241C3A",
		Bone = { "3C3260", Material = "Slate" },
		Star = { "FFF4FF", Neon = true },
		Line = { "C8B0FF", Neon = true },
		Nebula = { "E050C8", Neon = true },
		NebulaViolet = { "8A5CFF", Neon = true },
		Horn = "CCC4E4",
		HornLight = "F0ECFF",
		Crystal = "B8A4FF",
		CrystalDark = "7A62D0",
		CrystalLight = "DCD0FF",
		Tooth = "EEE8F4",
		Mouth = { "8A3AD0", Neon = true },
		Eye = { "E8DCFF", Neon = true },
		Socket = "07050C",
		Claw = "141018",
		ClawTip = "D8D0EC",
	},
	Joints = {
		Head = { 0, 2.9, -1.2 },
		Jaw = HEAD * Vector3.new(0, 0, -SKULL[3] * 0.25),
		LegFL = { 0.46, 2.3, -0.92 },
		LegFR = { -0.46, 2.3, -0.92 },
		LegBL = { 0.46, 2.26, 0.96 },
		LegBR = { -0.46, 2.26, 0.96 },
		Tail = { 0, 2.3, 1.3 },
		WingL = { WING_ROOT.X, WING_ROOT.Y, WING_ROOT.Z },
		WingR = { -WING_ROOT.X, WING_ROOT.Y, WING_ROOT.Z },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 30, band = 72, flank = 106, every = 3, upper = "HideDark" })
		local belly = { key = "Belly", key2 = "Belly2", arc = 40, t = 0.1, wide = 1.1 }
		local scales = { w = 0.34, t = 0.1, lift = 7, jitter = 1, sink = 0.5, overlap = 1.12 }
		local body = K:tube("Body", {
			{ 0, 2.4, -1.02, rx = 0.66, ru = 0.66, rd = 0.74 },
			{ 0, 2.36, -0.36, rx = 0.72, ru = 0.66, rd = 0.74 },
			{ 0, 2.3, 0.44, rx = 0.62, ru = 0.58, rd = 0.6 },
			{ 0, 2.28, 1.1, rx = 0.52, ru = 0.5, rd = 0.48 },
		}, { step = 0.28, core = "HideDark", coreScale = 0.86, tile = scales, belly = belly, color = skin })
		local neck = K:tube("Head", {
			{ 0, 3.96, -2.26, rx = 0.3, ru = 0.3, rd = 0.32 },
			{ 0, 3.6, -2.0, rx = 0.36, ru = 0.36, rd = 0.4 },
			{ 0, 3.12, -1.6, rx = 0.46, ru = 0.46, rd = 0.52 },
			{ 0, 2.6, -1.1, rx = 0.62, ru = 0.62, rd = 0.68 },
		}, { step = 0.24, core = "HideDark", coreScale = 0.86, tile = { w = 0.28, t = 0.09, lift = 7, jitter = 1, sink = 0.5, overlap = 1.12 }, belly = belly, color = skin })
		local tail = K:tube("Tail", {
			{ 0, 2.3, 1.24, rx = 0.44, ru = 0.42, rd = 0.4 },
			{ 0, 2.08, 2.0, rx = 0.32, ru = 0.3, rd = 0.28 },
			{ -0.2, 1.7, 2.8, rx = 0.22, ru = 0.2, rd = 0.19 },
			{ -0.6, 1.4, 3.4, rx = 0.14, ru = 0.13, rd = 0.12 },
			{ -1.0, 1.3, 3.76, rx = 0.07, ru = 0.07, rd = 0.06 },
		}, { step = 0.26, core = "HideDark", coreScale = 0.88, tile = { w = 0.26, n = 5, t = 0.08, lift = 7, jitter = 1, sink = 0.5, overlap = 1.12 }, belly = belly, color = skin, trim = 0.08 })
		-- stars flecked over the scales
		for _, seg in { { "Body", body, 26 }, { "Head", neck, 12 }, { "Tail", tail, 12 } } do
			local g, smps, n = seg[1], seg[2], seg[3]
			for i = 1, n do
				local smp = K:at(smps, K:rand(0.1, smps.total - 0.1))
				local pos = K:surface(smp, rad(K:rand(-110, 110)), -0.12)
				local s = i % 5 == 0 and 0.12 or 0.07
				K:block(g, "Star", CFrame.new(pos) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(s, s, s))
			end
		end
		-- dark spines down the back, crystal-tipped
		K:ridge("Head", neck, { every = 0.26, height = function(u) return 0.26 + u * 0.1 end, thick = 0.09, key = "Back", tip = "Crystal", lean = 36, sink = 0.85 })
		K:ridge("Body", body, { every = 0.3, height = function(u) return 0.4 - u * 0.12 end, thick = 0.11, key = "Back", tip = "Crystal", lean = 30, sink = 0.85 })
		K:ridge("Tail", tail, { to = tail.total * 0.8, every = 0.3, height = function(u) return 0.3 - u * 0.2 end, thick = 0.09, key = "Back", tip = "Crystal", lean = 36, sink = 0.85 })
		-- a crystal blade at the tail tip
		local tip = K:at(tail, tail.total)
		H.crystal(K, "Tail", { "Crystal", "CrystalLight", "CrystalDark" }, tip.p, tip.T, 0.5, 3, 16)
		-- the nebula glowing in its chest, pink and violet, seen through the scales
		for k, o in { { 0.2, 180, 0.5, "Nebula" }, { 0.45, 160, 0.38, "NebulaViolet" }, { 0.45, 200, 0.38, "NebulaViolet" }, { 0.05, 150, 0.3, "Nebula" }, { 0.05, 210, 0.3, "Nebula" } } do
			local smp = K:at(neck, neck.total - o[1])
			local pos, nrm = K:surface(smp, rad(o[2]), -0.02)
			K:block("Head", o[4], CFrame.fromMatrix(pos, nrm:Cross(smp.T).Unit, nrm) * CFrame.Angles(0, rad(k * 20), 0), Vector3.new(o[3], 0.08, o[3] * 0.8))
		end
		K:block("Head", "Star", CFrame.new(K:surface(K:at(neck, neck.total - 0.25), math.pi, -0.08)) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.16, 0.16, 0.16))

		-- four strong legs with hooked claws
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.46 * x, 2.32, -0.92, 0.34 },
				{ 0.56 * x, 1.36, -0.84, 0.25 },
				{ 0.54 * x, 0.34, -1.0, 0.19 },
			}, { step = 0.24, cores = { "Hide", "HideDark" }, tiles = { scales, nil }, color = skin, foot = { size = Vector3.new(0.46, 0.22, 0.52), key = "HideDark" }, toes = 4, claw = { len = 0.3, w = 0.08, curl = 44 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.46 * x, 2.28, 0.96, 0.42 },
				{ 0.54 * x, 1.56, 0.66, 0.3 },
				{ 0.54 * x, 0.78, 1.1, 0.2 },
				{ 0.54 * x, 0.3, 1.0, 0.17 },
			}, { step = 0.24, cores = { "Hide", "HideDark", "HideDark" }, tiles = { scales, nil, nil }, color = skin, foot = { size = Vector3.new(0.46, 0.22, 0.52), key = "HideDark" }, toes = 4, claw = { len = 0.3, w = 0.08, curl = 44 } })
		end

		-- the constellation wings: an arm of bone up to the wrist, long finger bones fanning from it, black membranes
		-- between them pinned with stars that are joined by glowing lines
		for _, x in { 1, -1 } do
			local g = x == 1 and "WingL" or "WingR"
			local root = Vector3.new(WING_ROOT.X * x, WING_ROOT.Y, WING_ROOT.Z)
			local elbow = root + Vector3.new(0.9 * x, 1.0, 0.3)
			local wrist = elbow + Vector3.new(1.0 * x, 0.6, -0.2)
			H.limb(K, g, { { root.X, root.Y, root.Z, 0.18 }, { elbow.X, elbow.Y, elbow.Z, 0.14 }, { wrist.X, wrist.Y, wrist.Z, 0.1 } }, { step = 0.22, core = "Bone" })
			local spars = { { root + Vector3.new(0, -0.2, 1.1), root + Vector3.new(0.3 * x, -0.1, 1.3) } }
			local stars = {}
			for i = 1, 4 do
				local f = (i - 1) / 3
				local d = Vector3.new((1 - f * 0.7) * x, 0.55 - f * 1.35, 0.15 + f * 1.1).Unit
				local len = 2.8 - f * 0.7
				K:chain(g, { "Bone", "Bone", "HideLight" }, wrist, d, Vector3.new(0, 0, 1):Cross(d).Magnitude > 0.1 and Vector3.zAxis or Vector3.xAxis, { n = 3, len = len, w0 = 0.12, w1 = 0.06, bend = 0, tip = false })
				table.insert(spars, 1, { wrist, wrist + d * len })
				table.insert(stars, wrist + d * len)
				table.insert(stars, wrist + d * len * 0.55)
			end
			-- the trailing spar: the arm itself (root to wrist) closes the wing against the body
			table.insert(spars, { root + Vector3.new(0, -0.1, 0.5), wrist })
			-- membranes between consecutive spars
			for i = 1, #spars - 1 do
				local A, B = spars[i], spars[i + 1]
				for k, f in { 0.18, 0.4, 0.62, 0.84, 0.98 } do
					local a = A[1]:Lerp(A[2], f)
					local b = B[1]:Lerp(B[2], f)
					local across = b - a
					local along = (A[2] - A[1]).Unit
					local nrm = across:Cross(along)
					if nrm.Magnitude > 1e-3 then
						nrm = nrm.Unit
						if nrm.Y < 0 then
							nrm = -nrm
						end
						local span = (A[2] - A[1]).Magnitude
						K:block(g, (i + k) % 2 == 0 and "Membrane" or "MembraneLight", CFrame.fromMatrix((a + b) / 2, across.Unit, nrm), Vector3.new(across.Magnitude + 0.1, 0.05, span * 0.24))
					end
				end
			end
			-- the constellation: bright stars on the bones and membrane, thick glowing lines joining them
			table.insert(stars, elbow + Vector3.new(0, 0.05, 0))
			table.insert(stars, wrist + Vector3.new(0, 0.05, 0))
			local order = { 9, 10, 1, 2, 3, 4, 5, 6, 7, 8 }
			local prev
			for _, idx in order do
				local p = stars[idx] + Vector3.new(0, 0.06, 0)
				K:block(g, "Star", CFrame.new(p) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.24, 0.24, 0.24))
				if prev then
					K:block(g, "Line", CFrame.lookAt((prev + p) / 2, p) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.14, 0.14, (p - prev).Magnitude))
				end
				prev = p
			end
		end

		-- head: a horned dragon skull, a crown of silver horns and crystal shards, starlight eyes
		local R = H.reptileHead(K, {
			frame = HEAD,
			skull = SKULL,
			snout = { 0.5, 0.38, 0.56 },
			tip = { 0.42, 0.32, 0.3 },
			open = 22,
			teeth = { 0.11, 0.06 },
			brow = "Back",
			browSize = { 0.3, 0.15, 0.4 },
			eye = { 0.17, 0.06 },
			cheek = 0.24,
		})
		for _, x in { 1, -1 } do
			-- long silver horns swept back, a shorter pair beneath them
			H.curve(K, "Head", { "Horn", "Horn", "HornLight" }, { R.p(0.2 * x, R.top - 0.04, -0.2), R.p(0.38 * x, R.top + 0.3, 0.2), R.p(0.5 * x, R.top + 0.5, 0.8), R.p(0.54 * x, R.top + 0.5, 1.3) }, 0.2, 0.06, 0.12)
			K:chain("Head", { "Horn", "HornLight" }, R.p(0.3 * x, 0.12, -0.04), R.v(0.6 * x, 0.1, 0.8), R.v(0, 1, 0), { n = 2, len = 0.5, w0 = 0.12, w1 = 0.07, bend = 0 })
			-- frill spines fanning back from the jaw hinge
			for k = 0, 2 do
				K:chain("Head", { "HideDark", "Crystal" }, R.p(0.32 * x, -0.04 - k * 0.1, -0.12 + k * 0.06), R.v(0.6 * x, 0.15 - k * 0.3, 0.8), R.v(0, 0, 1), { n = 2, len = 0.44 - k * 0.08, w0 = 0.09, w1 = 0.06, bend = 0 })
			end
		end
		H.crystal(K, "Head", { "Crystal", "CrystalLight", "CrystalDark", "Crystal" }, R.p(0, R.top, -0.3), R.v(0, 1, 0.4), 0.46, 4, 24)
		K:block("Head", "Star", R.cf(0, R.top + 0.02, -0.56), Vector3.new(0.1, 0.06, 0.1))
	end,
}
