local rad = math.rad
local H = require(script.Parent.Helpers)

-- Sunken Abyss / Rare / water: the hammerjaw, a hammerhead shark built like a gorilla. Real gorilla anatomy: a massive
-- hump of shoulder muscle rising above the head, a deep chest, a narrow waist and small hips on short bowed legs, long
-- thick arms planted on huge knuckles, hunched so the head hangs forward between the shoulders. Steel grey-teal shark
-- skin darkening to navy along the back, a white chest and belly, a tall raked dorsal fin on the hump, fins down the
-- backs of the forearms, a crescent tail. Gill slits glow cyan from inside. Head: the wide flat T-hammer with a glowing
-- eye in each tip and sensory pores along its front edge; like a real hammerhead the mouth is underneath it, a crescent
-- of serrated teeth set back under the blade, the lower jaw hanging open below.
local HEAD = CFrame.new(0, 3.5, -1.62) * CFrame.Angles(rad(-6), 0, 0)
local HINGE = Vector3.new(0, -0.1, -0.18)

return {
	Seed = 517,
	Vary = 0.04,
	Gait = "Knuckle",
	Emotes = { "Look", "ChestBeat" },
	Palette = {
		Hide = { "5C7E88", Material = "Slate" },
		HideDark = { "34505C", Material = "Slate" },
		HideLight = { "A8BEC2", Material = "Slate" },
		Back = { "18293A", Material = "Slate" },
		Belly = "E4EAE4",
		Belly2 = "CCD4CE",
		Fin = { "2A4458", Material = "Slate" },
		FinDark = { "16263A", Material = "Slate" },
		Scar = "A8BCC4",
		Glow = { "1AA6D8", Neon = true },
		SeamLip = { "08141C", Material = "Slate" },
		Gum = "8A3A4E",
		Tooth = "F0F2EA",
		Mouth = "3A0E1A",
		Eye = { "22C4E8", Neon = true },
		Socket = "060C10",
	},
	Joints = {
		Head = { 0, 3.6, -1.18 },
		Jaw = HEAD * HINGE,
		ArmL = { 1.72, 4.0, -0.5 },
		ArmR = { -1.72, 4.0, -0.5 },
		LegL = { 0.62, 2.15, 0.72 },
		LegR = { -0.62, 2.15, 0.72 },
		Tail = { 0, 2.25, 0.85 },
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
		local smooth = { w = 0.64, t = 0.1, lift = 2, jitter = 0.5, sink = 0.55, overlap = 1.06 }
		local belly = { key = "Belly2", key2 = "HideLight", arc = 40, t = 0.12, wide = 1.0 }
		local function limbColor(th)
			return math.abs(th) < rad(70) and "Hide" or "HideDark"
		end
		-- the torso: a deep chest high at the front, pinching in to a narrow waist, small hips
		local torso = K:tube("Body", {
			{ 0, 3.78, -0.72, rx = 1.26, ru = 1.04, rd = 1.12 },
			{ 0, 3.42, -0.06, rx = 1.18, ru = 1.02, rd = 1.0 },
			{ 0, 2.82, 0.42, rx = 0.78, ru = 0.72, rd = 0.7 },
			{ 0, 2.2, 0.66, rx = 0.86, ru = 0.72, rd = 0.68 },
		}, { step = 0.4, core = "Hide", coreScale = 0.92, tile = smooth, belly = belly, color = skin })
		-- the massive shoulder hump: a great bar of muscle across the shoulders rising above the head
		local mantle = K:tube("Body", {
			{ -1.72, 3.98, -0.46, rx = 0.8, ru = 0.84, rd = 0.68 },
			{ 0, 4.42, -0.36, rx = 0.98, ru = 0.94, rd = 0.74 },
			{ 1.72, 3.98, -0.46, rx = 0.8, ru = 0.84, rd = 0.68 },
		}, { step = 0.4, ref = Vector3.zAxis, core = "Hide", coreScale = 0.92, tile = smooth, color = function(th)
			local a = math.deg(math.abs(th))
			return a < 40 and "Back" or (a < 100 and "HideDark" or "Hide")
		end })
		-- a short thick neck, hunched down and forward into the head
		K:tube("Head", {
			{ 0, 3.5, -1.5, rx = 0.62, ru = 0.42, rd = 0.6 },
			{ 0, 3.62, -1.06, rx = 0.86, ru = 0.6, rd = 0.84 },
		}, { step = 0.26, core = "Hide", coreScale = 0.92, tile = smooth, color = function(th)
			return math.abs(th) < rad(60) and "HideDark" or "Hide"
		end })
		-- the tall dorsal fin rising off the hump, raked back
		local hump = K:at(mantle, mantle.total * 0.5)
		fin("Body", hump.p + Vector3.new(0, hump.ru * 0.86, 0.1), Vector3.yAxis, Vector3.zAxis, 1.7, 1.4, 0.18, 9)
		-- gill slits down each side of the chest, glowing from inside; old scars on the flanks
		for _, x in { 1, -1 } do
			for k = 0, 3 do
				local smp = K:at(torso, 0.18 + k * 0.2)
				local p, n = K:surface(smp, rad(66) * x, -0.04)
				local F = CFrame.fromMatrix(p, smp.T, n)
				K:block("Body", "SeamLip", F, Vector3.new(0.12, 0.08, 0.72 - k * 0.06))
				K:block("Body", "Glow", F * CFrame.new(0, -0.01, 0), Vector3.new(0.05, 0.08, 0.6 - k * 0.06))
			end
			for k = 0, 2 do
				local smp = K:at(torso, 1.0 + k * 0.16)
				local p, n = K:surface(smp, rad(96) * x, -0.06)
				K:block("Body", "Scar", CFrame.fromMatrix(p, smp.T, n) * CFrame.Angles(0, rad(35), 0), Vector3.new(0.05, 0.05, 0.5))
			end
		end
		for _, x in { 1, -1 } do
			-- long thick arms planted on huge knuckles, a fin down the back of each forearm
			local g = x == 1 and "ArmL" or "ArmR"
			local arm = H.apeArm(K, g, x, {
				pts = { { 1.72, 4.0, -0.5, 0.74 }, { 2.32, 2.46, -0.62, 0.6 }, { 2.14, 0.98, -0.96, 0.54 } },
				fist = Vector3.new(0.98, 0.86, 0.98),
				fistY = 0.46,
				core = "Hide",
				fistKey = "HideDark",
				knuckleKey = "Back",
				fur = smooth,
				foreFur = smooth,
				color = limbColor,
			})
			-- a bulging bicep and forearm mass
			local upper = arm[1]
			K:tile(g, "Hide", K:at(upper, upper.total * 0.45), 0, 1.0, 0.9, 0.18, 6, 1, 0.4)
			local fore = arm[2]
			local mid = K:at(fore, fore.total * 0.35)
			local fp, fn = K:surface(mid, rad(180), 0.02)
			K:plate(g, { "FinDark", "Fin" }, fp, (fn + Vector3.new(0, 0, 0.6)).Unit, -mid.T, { h = 0.8, w = 0.8, t = 0.08, n = 2, lean = 40 })
			-- short bowed legs, flat feet
			local lg = x == 1 and "LegL" or "LegR"
			H.limb(K, lg, {
				{ 0.62 * x, 2.15, 0.72, 0.58 },
				{ 0.98 * x, 1.2, 0.42, 0.48 },
				{ 0.9 * x, 0.4, 0.76, 0.36 },
			}, { step = 0.42, cores = { "Hide", "HideDark" }, tiles = { smooth, nil }, color = limbColor })
			K:block(lg, "HideDark", CFrame.new(0.92 * x, 0.15, 0.58) * CFrame.Angles(0, rad(-10 * x), 0), Vector3.new(0.66, 0.3, 0.96))
		end
		-- a crescent shark tail off the hips
		local tail = K:tube("Tail", {
			{ 0, 2.25, 0.8, rx = 0.44, ru = 0.42, rd = 0.4 },
			{ 0, 2.36, 1.5, rx = 0.3, ru = 0.3, rd = 0.28 },
			{ 0, 2.62, 2.06, rx = 0.18, ru = 0.18, rd = 0.17 },
		}, { step = 0.3, core = "Hide", coreScale = 0.92, tile = { w = 0.36, n = 5, t = 0.1, lift = 2, jitter = 0.5, sink = 0.55, overlap = 1.06 }, color = skin, trim = 0.05 })
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
		-- a rounded head root behind the blade, tapering into it (no flat face)
		K:block("Head", "HideDark", hcf(0, 0.12, -0.3), Vector3.new(0.82, 0.4, 0.62))
		K:block("Head", "HideDark", hcf(0, 0.12, -0.3, 0, 0, 45), Vector3.new(0.42, 0.42, 0.58))
		-- the hammer: a wide flat T reaching well past the shoulders, the wings swept slightly back, navy on top,
		-- steel underneath, a glowing eye in a socket at each tip
		K:block("Head", "Hide", hcf(0, 0.28, -0.84), Vector3.new(2.2, 0.36, 0.76))
		K:block("Head", "Back", hcf(0, 0.47, -0.84), Vector3.new(2.0, 0.05, 0.66))
		K:block("Head", "HideLight", hcf(0, 0.09, -0.84), Vector3.new(2.1, 0.04, 0.66))
		for _, x in { 1, -1 } do
			K:block("Head", "Hide", hcf(1.62 * x, 0.28, -0.7, 0, -14 * x, 0), Vector3.new(1.3, 0.34, 0.64))
			K:block("Head", "Back", hcf(1.6 * x, 0.46, -0.7, 0, -14 * x, 0), Vector3.new(1.2, 0.05, 0.54))
			K:block("Head", "HideLight", hcf(1.6 * x, 0.1, -0.7, 0, -14 * x, 0), Vector3.new(1.2, 0.04, 0.54))
			K:block("Head", "HideDark", hcf(2.26 * x, 0.28, -0.52, 0, -14 * x, 0), Vector3.new(0.34, 0.44, 0.66))
			K:block("Head", "HideDark", hcf(2.26 * x, 0.28, -0.52, 0, -14 * x, 45), Vector3.new(0.34, 0.34, 0.6))
			K:block("Head", "Back", hcf(2.24 * x, 0.52, -0.56, 0, -14 * x, 14 * x), Vector3.new(0.42, 0.12, 0.62))
			K:block("Head", "Socket", hcf(2.3 * x, 0.3, -0.86, 0, -30 * x, 0), Vector3.new(0.36, 0.22, 0.12))
			H.eye(K, "Head", hcf(2.3 * x, 0.3, -0.93, 0, -30 * x, 0), 0.26, 0.1)
		end
		-- glowing sensory pores along the front edge of the hammer, each in a dark pit
		for k = -10, 10 do
			local x = k * 0.21
			local ax = math.abs(x)
			local z = ax < 0.95 and -1.23 or (-1.04 + (ax - 1.55) * 0.25)
			local F = hcf(x, 0.26, z, 0, ax < 0.95 and 0 or -14 * (x > 0 and 1 or -1), 0)
			K:block("Head", "SeamLip", F, Vector3.new(0.09, 0.09, 0.06))
			K:block("Head", "Glow", F * CFrame.new(0, 0, -0.01), Vector3.new(0.045, 0.045, 0.06))
		end
		-- the mouth underneath the hammer, set back from its front edge like a real hammerhead's: a crescent of gums
		-- and serrated teeth hanging down from the blade's underside
		K:block("Head", "Mouth", hcf(0, 0.04, -0.66), Vector3.new(0.9, 0.06, 0.5))
		for k = -5, 5 do
			local f = k / 5
			local x = math.sin(f * 1.2) * 0.52
			local z = -0.86 + (1 - math.cos(f * 1.2)) * 0.36
			K:block("Head", "Gum", hcf(x, 0.05, z), Vector3.new(0.14, 0.06, 0.14))
			K:spike("Head", "Tooth", hp(x, 0.03, z), hv(0, -1, -0.15), hv(math.cos(f * 1.2), 0, -math.sin(f * 1.2)), 0.17 * (k % 2 == 0 and 1 or 0.8), 0.06)
		end
		-- the lower jaw hinged under the head root, hanging open beneath the blade, a crescent of teeth pointing up
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-28), 0, 0)
		K:block("Jaw", "Hide", JAW * CFrame.new(0, -0.12, -0.42), Vector3.new(0.92, 0.24, 0.86))
		K:block("Jaw", "Belly", JAW * CFrame.new(0, -0.25, -0.4), Vector3.new(0.78, 0.04, 0.76))
		K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.42), Vector3.new(0.78, 0.04, 0.74))
		local up = JAW:VectorToWorldSpace(Vector3.yAxis)
		for k = -5, 5 do
			local f = k / 5
			local x = math.sin(f * 1.2) * 0.42
			local z = -0.8 + (1 - math.cos(f * 1.2)) * 0.32
			K:block("Jaw", "Gum", JAW * CFrame.new(x, 0.02, z), Vector3.new(0.13, 0.05, 0.13))
			K:spike("Jaw", "Tooth", JAW * Vector3.new(x, 0.03, z), up, JAW:VectorToWorldSpace(Vector3.new(math.cos(f * 1.2), 0, -math.sin(f * 1.2))), 0.15 * (k % 2 == 0 and 1 or 0.8), 0.055)
		end
	end,
}
