local rad = math.rad
local H = require(script.Parent.Helpers)

-- Sunken Abyss / Rare / water: the hammerjaw, a hammerhead shark built like a gorilla. A huge chest and shoulders on
-- knuckle-walking arms, short legs, steel-blue shark skin darkening to navy along the back and fading to a white belly,
-- a tall dorsal fin, fins down the backs of the forearms, a crescent shark tail. Gill slits on the neck glow cyan from
-- inside. Face: the wide flat hammer with a small cyan eye under a heavy brow at each end, glowing sensory pores along
-- its front edge, and under it a mouth of serrated teeth in rows.
local HEAD = CFrame.new(0, 3.86, -1.78) * CFrame.Angles(rad(-4), 0, 0)
local HINGE = Vector3.new(0, -0.24, -0.42)

return {
	Seed = 517,
	Vary = 0.04,
	Gait = "Knuckle",
	Emotes = { "Look", "ChestBeat" },
	Palette = {
		Hide = { "4E6E80", Material = "Slate" },
		HideDark = { "2E4A5C", Material = "Slate" },
		HideLight = { "8AA6B4", Material = "Slate" },
		Back = { "18293A", Material = "Slate" },
		Belly = "E4EAE4",
		Belly2 = "CCD4CE",
		Fin = { "2A4458", Material = "Slate" },
		FinDark = { "16263A", Material = "Slate" },
		Scar = "A8BCC4",
		Glow = { "1AA6D8", Neon = true },
		SeamLip = { "08141C", Material = "Slate" },
		Tooth = "F0F2EA",
		Mouth = "3A0E1A",
		Eye = { "22C4E8", Neon = true },
		Socket = "060C10",
	},
	Joints = {
		Head = { 0, 3.72, -1.2 },
		Jaw = HEAD * HINGE,
		ArmL = { 1.36, 3.72, -0.5 },
		ArmR = { -1.36, 3.72, -0.5 },
		LegL = { 0.66, 2.0, 0.5 },
		LegR = { -0.66, 2.0, 0.5 },
		Tail = { 0, 2.2, 0.8 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		-- a raked shark fin: stacked boards from the base up, the leading edge sweeping back, thin across
		local function fin(g, base, up, along, height, length, thick, n)
			n = n or 7
			local side = along:Cross(up).Unit
			for i = 0, n - 1 do
				local f = i / n
				local front = -length * 0.5 + f * length * 0.95
				local back = length * 0.5 + f * length * 0.18
				local c = base + up * height * (f + 0.5 / n) + along * (front + back) / 2
				K:block(g, "Fin", CFrame.fromMatrix(c, along, up, side), Vector3.new(math.max(back - front, 0.12), height / n * 1.15, thick * (1 - f * 0.5)))
				K:block(g, "FinDark", CFrame.fromMatrix(c + along * (front - (front + back) / 2 + 0.08), along, up, side), Vector3.new(0.18, height / n * 1.15, thick * (1 - f * 0.5) + 0.02))
			end
		end
		local skin = H.skin({ stripe = 34, band = 70, flank = 104, every = 3, upper = "HideDark" })
		local smooth = { w = 0.62, n = nil, t = 0.1, lift = 2, jitter = 0.5, sink = 0.55, overlap = 1.06 }
		local belly = { key = "Belly", key2 = "Belly2", arc = 58, t = 0.12, wide = 1.1 }
		-- a huge chest and shoulders leaning forward, tapering to small hips
		local torso = K:tube("Body", {
			{ 0, 3.5, -0.62, rx = 1.2, ru = 1.0, rd = 1.06 },
			{ 0, 3.18, 0.0, rx = 1.24, ru = 1.02, rd = 1.06 },
			{ 0, 2.64, 0.42, rx = 0.98, ru = 0.86, rd = 0.86 },
			{ 0, 2.12, 0.62, rx = 0.76, ru = 0.66, rd = 0.62 },
		}, { step = 0.4, core = "Hide", coreScale = 0.92, tile = smooth, belly = belly, color = skin })
		-- a thick neck thrusting the head forward
		K:tube("Head", {
			{ 0, 3.86, -1.66, rx = 0.66, ru = 0.6, rd = 0.66 },
			{ 0, 3.72, -1.2, rx = 0.86, ru = 0.78, rd = 0.84 },
			{ 0, 3.58, -0.66, rx = 0.98, ru = 0.88, rd = 0.94 },
		}, { step = 0.3, core = "Hide", coreScale = 0.92, tile = smooth, belly = belly, color = skin })
		-- the tall dorsal fin, raked back: a thin tapering blade, wide along the spine
		local top = K:at(torso, 0.7)
		local pos = K:surface(top, 0, 0.12)
		fin("Body", pos, Vector3.yAxis, Vector3.new(top.T.X, 0, top.T.Z).Unit, 1.8, 1.5, 0.18, 9)
		-- gill slits down each side of the neck, glowing from inside
		for _, x in { 1, -1 } do
			for k = 0, 3 do
				local smp = K:at(torso, 0.12 + k * 0.2)
				local p, n = K:surface(smp, rad(68) * x, -0.04)
				local F = CFrame.fromMatrix(p, smp.T, n)
				K:block("Body", "SeamLip", F, Vector3.new(0.12, 0.08, 0.72 - k * 0.06))
				K:block("Body", "Glow", F * CFrame.new(0, -0.01, 0), Vector3.new(0.05, 0.08, 0.6 - k * 0.06))
			end
			-- old scars raked across the flank
			for k = 0, 2 do
				local smp = K:at(torso, 0.9 + k * 0.16)
				local p, n = K:surface(smp, rad(96) * x, -0.06)
				K:block("Body", "Scar", CFrame.fromMatrix(p, smp.T, n) * CFrame.Angles(0, rad(35), 0), Vector3.new(0.05, 0.05, 0.5))
			end
		end
		-- arms: massive, knuckle-walking, a fin down the back of each forearm
		for _, x in { 1, -1 } do
			local g = x == 1 and "ArmL" or "ArmR"
			local arm, fc = H.apeArm(K, g, x, {
				pts = { { 1.36, 3.72, -0.5, 0.58 }, { 1.94, 2.3, -0.56, 0.5 }, { 1.84, 0.86, -0.8, 0.46 } },
				fist = Vector3.new(0.8, 0.72, 0.8),
				fistY = 0.42,
				core = "Hide",
				fistKey = "HideDark",
				knuckleKey = "Back",
				fur = { w = 0.56, n = 6, t = 0.12, lift = 5, jitter = 1, sink = 0.5, overlap = 1.08 },
				foreFur = { w = 0.52, n = 6, t = 0.12, lift = 5, jitter = 1, sink = 0.5, overlap = 1.08 },
				color = function(th) return math.abs(th) < rad(70) and "Hide" or "HideDark" end,
			})
			local fore = arm[2]
			local mid = K:at(fore, fore.total * 0.4)
			local fp, fn = K:surface(mid, rad(180), 0.02)
			K:plate(g, { "FinDark", "Fin" }, fp, (fn + Vector3.new(0, 0, 0.6)).Unit, -mid.T, { h = 0.7, w = 0.7, t = 0.08, n = 2, lean = 40 })
			-- legs: short and bowed, flat feet
			local lg = x == 1 and "LegL" or "LegR"
			H.limb(K, lg, {
				{ 0.66 * x, 2.0, 0.5, 0.56 },
				{ 0.92 * x, 1.14, 0.22, 0.46 },
				{ 0.86 * x, 0.38, 0.52, 0.34 },
			}, { step = 0.42, cores = { "Hide", "HideDark" }, tiles = { { w = 0.56, n = 6, t = 0.12, lift = 5, jitter = 1, sink = 0.5, overlap = 1.08 }, nil }, color = function(_, ring) return ring % 2 == 0 and "Hide" or "HideDark" end })
			K:block(lg, "HideDark", CFrame.new(0.88 * x, 0.15, 0.36) * CFrame.Angles(0, rad(-10 * x), 0), Vector3.new(0.62, 0.3, 0.92))
		end
		-- a crescent shark tail rising off the hips
		local tail = K:tube("Tail", {
			{ 0, 2.2, 0.7, rx = 0.42, ru = 0.4, rd = 0.38 },
			{ 0, 2.3, 1.4, rx = 0.3, ru = 0.3, rd = 0.28 },
			{ 0, 2.56, 1.96, rx = 0.18, ru = 0.18, rd = 0.17 },
		}, { step = 0.3, core = "Hide", coreScale = 0.92, tile = { w = 0.36, n = 5, t = 0.1, lift = 5, jitter = 1, sink = 0.5, overlap = 1.08 }, color = skin, trim = 0.05 })
		local tip = K:at(tail, tail.total)
		local flat = Vector3.new(tip.T.X, 0, tip.T.Z).Unit
		fin("Tail", tip.p - Vector3.new(0, 0.08, 0), (Vector3.yAxis + flat * 0.55).Unit, (flat - Vector3.yAxis * 0.55).Unit, 1.4, 0.7, 0.14, 6)
		fin("Tail", tip.p + Vector3.new(0, 0.08, 0), (-Vector3.yAxis + flat * 0.5).Unit, (flat + Vector3.yAxis * 0.5).Unit, 0.9, 0.55, 0.12, 4)

		-- the hammerhead (origin at the back of the head, facing -Z)
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.08, -0.3), Vector3.new(0.96, 0.72, 0.8))
		-- the hammer: a wide flat blade swept slightly back at the ends
		K:block("Head", "Hide", hcf(0, 0.28, -0.84), Vector3.new(1.6, 0.32, 0.7))
		K:block("Head", "HideDark", hcf(0, 0.46, -0.82), Vector3.new(0.5, 0.06, 0.6))
		K:block("Head", "HideLight", hcf(0, 0.11, -0.84), Vector3.new(1.5, 0.04, 0.6))
		for _, x in { 1, -1 } do
			K:block("Head", "Hide", hcf(1.12 * x, 0.28, -0.72, 0, -14 * x, 0), Vector3.new(0.86, 0.3, 0.6))
			K:block("Head", "HideLight", hcf(0.62 * x, 0.45, -0.8, 0, -6 * x, 0), Vector3.new(0.5, 0.05, 0.5))
			K:block("Head", "HideLight", hcf(1.1 * x, 0.12, -0.72, 0, -14 * x, 0), Vector3.new(0.78, 0.04, 0.5))
			K:block("Head", "HideDark", hcf(1.56 * x, 0.28, -0.6, 0, -14 * x, 0), Vector3.new(0.18, 0.36, 0.58))
			-- the eye at the end of the hammer, looking out and forward, under a heavy brow
			H.eye(K, "Head", hcf(1.66 * x, 0.3, -0.66, 0, -70 * x, 0), 0.15, 0.055)
			K:block("Head", "Back", hcf(1.56 * x, 0.47, -0.66, 0, -14 * x, 16 * x), Vector3.new(0.34, 0.11, 0.54))
		end
		-- glowing sensory pores along the front edge of the hammer, each in a dark pit
		for k = -7, 7 do
			local x = k * 0.2
			local z = -1.2 + math.abs(x) * 0.24
			local F = hcf(x, 0.26, z, 0, -14 * (x > 0 and 1 or x < 0 and -1 or 0), 0)
			K:block("Head", "SeamLip", F, Vector3.new(0.09, 0.09, 0.06))
			K:block("Head", "Glow", F * CFrame.new(0, 0, -0.01), Vector3.new(0.045, 0.045, 0.06))
		end
		-- the snout under the hammer and a mouth of serrated teeth in two rows
		K:block("Head", "Hide", hcf(0, -0.02, -0.92), Vector3.new(0.78, 0.34, 0.5))
		K:block("Head", "Mouth", hcf(0, -0.2, -0.78), Vector3.new(0.74, 0.04, 0.56))
		H.teeth(K, "Head", "Tooth", hp(-0.34, -0.19, -1.12), hp(0.34, -0.19, -1.12), 7, hv(0, -1, 0.1), hv(0, 0, 1), 0.15, 0.06)
		H.teeth(K, "Head", "Tooth", hp(-0.28, -0.19, -0.98), hp(0.28, -0.19, -0.98), 6, hv(0, -1, 0.2), hv(0, 0, 1), 0.1, 0.05)
		for _, x in { 1, -1 } do
			H.teeth(K, "Head", "Tooth", hp(0.38 * x, -0.19, -0.56), hp(0.37 * x, -0.19, -1.04), 4, hv(0, -1, 0), hv(1, 0, 0), 0.12, 0.05)
		end
		-- the lower jaw, dropped open
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-20), 0, 0)
		K:block("Jaw", "Hide", JAW * CFrame.new(0, -0.1, -0.36), Vector3.new(0.8, 0.22, 0.74))
		K:block("Jaw", "Belly", JAW * CFrame.new(0, -0.21, -0.34), Vector3.new(0.66, 0.04, 0.64))
		K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.38), Vector3.new(0.68, 0.04, 0.64))
		local up = JAW:VectorToWorldSpace(Vector3.yAxis)
		H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(-0.32, 0, -0.7), JAW * Vector3.new(0.32, 0, -0.7), 7, up, JAW:VectorToWorldSpace(Vector3.zAxis), 0.13, 0.055)
		for _, x in { 1, -1 } do
			H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.36 * x, 0, -0.16), JAW * Vector3.new(0.35 * x, 0, -0.62), 4, up, JAW:VectorToWorldSpace(Vector3.xAxis), 0.11, 0.05)
		end
	end,
}
