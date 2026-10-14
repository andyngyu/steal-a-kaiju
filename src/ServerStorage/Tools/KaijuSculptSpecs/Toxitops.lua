local rad = math.rad
local H = require(script.Parent.Helpers)

-- Venom Jungle / Legendary / poison: a venom ceratopsian. A massive horned dinosaur on pillar legs, its head carried
-- low behind a huge bony frill. The frill is ringed with spikes and studded with glowing venom sacs (purple bulbs with
-- lime cores) and its rim drips toxin; three long horns (two over the brows, one on the nose) are stained purple at
-- the tips. Mottled moss-green hide over grey-green armour scutes down the back, a pale belly, a thick armoured tail.
-- Face: a hooked parrot beak, narrow lime eyes under heavy brow horns.
local HEAD = CFrame.new(0, 1.74, -1.76) * CFrame.Angles(rad(-14), 0, 0)
local HINGE = Vector3.new(0, -0.24, -0.4)

return {
	Seed = 433,
	Vary = 0.05,
	Gait = "Amble",
	Emotes = { "Look", "Wiggle" },
	Palette = {
		Hide = "4A6234",
		HideDark = "334626",
		HideLight = "6C8448",
		Back = "23301A",
		Belly = "B0AA7A",
		Belly2 = "9A9466",
		Scute = "5E6A54",
		ScuteLight = "7E8A70",
		Frill = "3E5230",
		FrillDark = "2A3A20",
		FrillRim = "5A2A70",
		Horn = "D6CCA8",
		HornBase = "8A8060",
		HornTip = "8A3CC0",
		Sac = { "9A3CE0", Neon = true },
		SacCore = { "B4FF3A", Neon = true },
		Drip = { "9DFF3A", Neon = true },
		Beak = "2A2420",
		Tooth = "E2DAC0",
		Mouth = "4A1A26",
		Eye = { "C6FF3A", Neon = true },
		Socket = "0C1008",
		Claw = "262018",
		ClawTip = "8A8068",
	},
	Joints = {
		Head = { 0, 1.78, -1.2 },
		Jaw = HEAD * HINGE,
		LegFL = { 0.7, 1.5, -0.72 },
		LegFR = { -0.7, 1.5, -0.72 },
		LegBL = { 0.72, 1.62, 0.98 },
		LegBR = { -0.72, 1.62, 0.98 },
		Tail = { 0, 1.84, 1.46 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 40, band = 84, flank = 110, every = 2 })
		local belly = { key = "Belly", key2 = "Belly2", arc = 46, t = 0.12, wide = 1.1 }
		-- a massive body, the hips higher than the shoulders
		local body = K:tube("Body", {
			{ 0, 1.72, -1.04, rx = 0.84, ru = 0.78, rd = 0.8 },
			{ 0, 1.9, -0.3, rx = 1.0, ru = 0.94, rd = 0.9 },
			{ 0, 2.0, 0.5, rx = 0.98, ru = 0.92, rd = 0.86 },
			{ 0, 1.92, 1.22, rx = 0.74, ru = 0.68, rd = 0.62 },
		}, { step = 0.36, core = "Hide", coreScale = 0.78, tile = H.plates(0.5, nil, 0.13), belly = belly, color = skin })
		-- armour scutes down the back in three rows
		for s = 0.2, body.total - 0.1, 0.34 do
			local smp = K:at(body, s)
			for _, th in { 0, -32, 32 } do
				local pos, nrm = K:surface(smp, rad(th), 0.02)
				K:plate("Body", { "Scute", "ScuteLight" }, pos, nrm, smp.T, { h = th == 0 and 0.3 or 0.2, w = 0.4, t = 0.12, n = 2, lean = 24 })
			end
		end
		-- a thick armoured tail
		local tail = K:tube("Tail", {
			{ 0, 1.86, 1.4, rx = 0.56, ru = 0.52, rd = 0.48 },
			{ 0, 1.66, 2.0, rx = 0.38, ru = 0.36, rd = 0.32 },
			{ -0.12, 1.28, 2.5, rx = 0.22, ru = 0.2, rd = 0.18 },
			{ -0.3, 0.92, 2.8, rx = 0.1, ru = 0.1, rd = 0.09 },
		}, { step = 0.3, core = "Hide", coreScale = 0.84, tile = H.plates(0.36, 5, 0.11), belly = belly, color = skin, trim = 0.08 })
		K:ridge("Tail", tail, { to = tail.total - 0.2, every = 0.26, height = function(u) return 0.26 - u * 0.14 end, thick = 0.12, key = "Scute", tip = "ScuteLight", lean = 36, sink = 0.85 })
		-- the short thick neck up to the head
		K:tube("Head", {
			{ 0, 1.8, -1.66, rx = 0.5, ru = 0.5, rd = 0.5 },
			{ 0, 1.76, -1.3, rx = 0.66, ru = 0.64, rd = 0.66 },
			{ 0, 1.72, -0.92, rx = 0.78, ru = 0.74, rd = 0.76 },
		}, { step = 0.26, core = "Hide", coreScale = 0.82, tile = H.plates(0.42, nil, 0.12), color = skin })
		-- pillar legs, broad feet, blunt hoof-claws
		local function limb(_, ring)
			return ring % 2 == 0 and "Hide" or "HideDark"
		end
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.7 * x, 1.52, -0.72, 0.42 },
				{ 0.82 * x, 0.92, -0.82, 0.34 },
				{ 0.8 * x, 0.3, -0.74, 0.3 },
			}, { step = 0.28, cores = { "Hide", "HideDark" }, tiles = { H.plates(0.32, 5, 0.1), nil }, color = limb, foot = { size = Vector3.new(0.58, 0.26, 0.56), key = "Back" }, toes = 3, claw = { len = 0.14, w = 0.12, curl = 12 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.72 * x, 1.64, 0.98, 0.5 },
				{ 0.82 * x, 1.0, 0.82, 0.4 },
				{ 0.8 * x, 0.3, 1.0, 0.32 },
			}, { step = 0.28, cores = { "Hide", "HideDark" }, tiles = { H.plates(0.34, 5, 0.1), nil }, color = limb, foot = { size = Vector3.new(0.6, 0.26, 0.58), key = "Back" }, toes = 3, claw = { len = 0.14, w = 0.12, curl = 12 } })
		end

		-- head: a long skull with a hooked beak, the great frill behind it, three horns
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.12, -0.3), Vector3.new(0.82, 0.62, 0.7))
		K:block("Head", "Hide", hcf(0, 0.0, -0.84), Vector3.new(0.6, 0.5, 0.6))
		K:block("Head", "Hide", hcf(0, 0.0, -0.84, 0, 0, 45), Vector3.new(0.44, 0.44, 0.56))
		K:block("Head", "HideDark", hcf(0, 0.28, -0.6, -12, 0, 0), Vector3.new(0.56, 0.12, 0.7))
		-- the hooked beak
		K:block("Head", "Beak", hcf(0, -0.08, -1.26), Vector3.new(0.4, 0.38, 0.36))
		K:block("Head", "Beak", hcf(0, -0.24, -1.42, 30, 0, 0), Vector3.new(0.3, 0.22, 0.2))
		K:block("Head", "Mouth", hcf(0, -0.26, -0.86), Vector3.new(0.44, 0.04, 0.6))
		for _, x in { 1, -1 } do
			K:block("Head", "HideLight", hcf(0.4 * x, -0.04, -0.34, 0, -10 * x, 6 * x), Vector3.new(0.18, 0.5, 0.56))
			K:block("Head", "Back", hcf(0.28 * x, 0.36, -0.56, -6, -14 * x, 20 * x), Vector3.new(0.28, 0.12, 0.3))
			H.eye(K, "Head", hcf(0.36 * x, 0.24, -0.6, 0, -36 * x, 14 * x), 0.17, 0.05)
			-- brow horns sweeping forward
			H.curve(K, "Head", { "HornBase", "Horn", "Horn", "HornTip" }, { hp(0.3 * x, 0.42, -0.42), hp(0.42 * x, 0.92, -0.62), hp(0.46 * x, 1.32, -1.02), hp(0.4 * x, 1.52, -1.5) }, 0.22, 0.06, 0.14)
			-- cheek horns
			K:spike("Head", "Horn", hp(0.46 * x, -0.1, -0.2), hv(1 * x, -0.2, 0.2), hv(0, 1, 0), 0.3, 0.1)
		end
		-- the nose horn
		H.curve(K, "Head", { "HornBase", "Horn", "HornTip" }, { hp(0, 0.2, -1.12), hp(0, 0.52, -1.24), hp(0, 0.76, -1.2) }, 0.18, 0.06, 0.12)
		-- the frill: a fan of bony plates rising behind the skull, spiked rim, glowing venom sacs
		local N = 11
		local ribs = {}
		for i = 0, N - 1 do
			local a = rad(-95 + 190 * i / (N - 1))
			local dir = hv(math.sin(a) * 1.1, math.cos(a) * 1.0 + 0.4, 0.55)
			local base = hp(math.sin(a) * 0.3, 0.2 + math.cos(a) * 0.22, 0.02)
			local len = 1.15 + math.cos(a) * 0.25
			ribs[i + 1] = { base = base, dir = dir, len = len }
			K:chain("Head", { "FrillDark", "Frill", "FrillDark" }, base, dir, hv(0, 0, 1), { n = 3, len = len, w0 = 0.2, w1 = 0.14, bend = 0, tip = false, depth = 0.6 })
			-- the rim spike
			local tip = base + dir * len
			K:spike("Head", i % 2 == 0 and "Horn" or "HornTip", tip, dir, hv(0, 0, 1), 0.26, 0.09)
			K:block("Head", "FrillRim", CFrame.lookAt(tip - dir * 0.08, tip + dir), Vector3.new(0.24, 0.1, 0.14))
		end
		for i = 1, N - 1 do
			local a, b = ribs[i], ribs[i + 1]
			for k, f in { 0.32, 0.62, 0.9 } do
				local pa, pb = a.base + a.dir * a.len * f, b.base + b.dir * b.len * f
				local across = pb - pa
				local nrm = across:Cross(a.dir).Unit
				if nrm:Dot(hv(0, 0, -1)) < 0 then
					nrm = -nrm
				end
				K:block("Head", (i + k) % 2 == 0 and "Frill" or "FrillDark", CFrame.fromMatrix((pa + pb) / 2, across.Unit, nrm), Vector3.new(across.Magnitude + 0.08, 0.08, a.len * 0.36))
				-- the venom sacs, on the front face of the frill
				if k == 2 and i % 2 == 1 then
					local c = (pa + pb) / 2 + nrm * 0.08
					K:block("Head", "Sac", CFrame.fromMatrix(c, across.Unit, nrm) * CFrame.Angles(0, rad(45), 0), Vector3.new(0.22, 0.12, 0.22))
					K:block("Head", "SacCore", CFrame.fromMatrix(c + nrm * 0.06, across.Unit, nrm), Vector3.new(0.1, 0.06, 0.1))
				elseif k == 3 and i % 3 == 0 then
					K:block("Head", "Drip", CFrame.new((pa + pb) / 2 + nrm * 0.06 - Vector3.new(0, 0.1, 0)), Vector3.new(0.05, 0.16, 0.05))
				end
			end
		end
		-- the lower beak
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-12), 0, 0)
		K:block("Jaw", "Hide", JAW * CFrame.new(0, -0.1, -0.46), Vector3.new(0.5, 0.2, 0.8))
		K:block("Jaw", "Beak", JAW * CFrame.new(0, -0.08, -0.94), Vector3.new(0.32, 0.18, 0.24))
		K:block("Jaw", "Belly", JAW * CFrame.new(0, -0.2, -0.42), Vector3.new(0.4, 0.04, 0.66))
		K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.5), Vector3.new(0.38, 0.04, 0.7))
	end,
}
