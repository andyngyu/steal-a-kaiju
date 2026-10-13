local rad = math.rad
local spec

-- Pebble Plains / Common / earth: a rock-armoured theropod (ceratosaur-like) stalking low and forward. Olive hide with
-- a dark stripe down the spine and dark bands down the flanks, pale segmented belly, stepped slate plates from the skull
-- to the tail tip, pebble osteoderms down the flanks, a nose horn and swept-back brow horns, narrow amber eyes under a
-- heavy stone brow, a half-open jaw full of teeth, the tail sweeping out to one side.
do
	local HEAD = CFrame.new(0, 3.18, -1.62) * CFrame.Angles(rad(-12), 0, 0)
	local HINGE = Vector3.new(0, -0.14, -0.14)

	-- skin by angle round the body (0 = top) and ring: dark stripe down the spine, dark bands down the flanks every
	-- third ring, olive flanks, lighter lower flanks
	local function skin(th, ring)
		local a = math.deg(math.abs(th))
		if a < 44 then
			return "Back"
		elseif a < 84 then
			return ring % 3 == 0 and "Back" or "Hide"
		elseif a < 104 then
			return "Hide"
		end
		return "HideLight"
	end
	local function limb(_, ring)
		return ring % 3 == 0 and "HideDark" or "Hide"
	end

	spec = {
		Seed = 11,
		Vary = 0.07,
		Gait = "Biped",
		Emotes = { "Look", "Roar" },
		Palette = {
			Hide = "4E5D3B",
			HideLight = "7A8260",
			HideDark = "36412A",
			Back = "232B1C",
			Belly = "BBAE8A",
			Belly2 = "9F936F",
			Rock = { "8A8475", Material = "Slate" },
			RockLight = { "B4AD99", Material = "Slate" },
			RockDark = { "57534A", Material = "Slate" },
			Tooth = "EDE6D2",
			Claw = "3A342D",
			ClawTip = "CFC5AA",
			Mouth = "541C1C",
			Eye = { "FF9A1A", Neon = true },
			Socket = "12170E",
		},
		Joints = {
			Head = { 0, 2.9, -0.82 },
			Jaw = HEAD * HINGE,
			LegL = { 0.76, 2.3, 0.48 },
			LegR = { -0.76, 2.3, 0.48 },
			ArmL = { 0.78, 2.6, -0.82 },
			ArmR = { -0.78, 2.6, -0.82 },
			Tail = { 0, 2.42, 0.9 },
		},
		Parents = { Jaw = "Head" },
		Build = function(K)
			local function plates(w, n)
				return { w = w, n = n, t = 0.13, lift = 8, jitter = 1, sink = 0.5, overlap = 1.12 }
			end
			local BELLY = { key = "Belly", key2 = "Belly2", arc = 48, t = 0.13, wide = 1.15 }
			-- torso pitched up toward the shoulders: deep chest, heavy hips; thick neck rising from the chest (moves with
			-- the head); long tail held off the ground, sweeping out to the kaiju's right
			local torso = K:tube("Body", {
				{ 0, 2.86, -0.86, rx = 0.8, ru = 0.74, rd = 0.86 },
				{ 0, 2.66, -0.36, rx = 0.94, ru = 0.82, rd = 1.0 },
				{ 0, 2.5, 0.16, rx = 0.92, ru = 0.8, rd = 0.86 },
				{ 0, 2.42, 0.62, rx = 0.86, ru = 0.74, rd = 0.7 },
				{ 0, 2.38, 1.0, rx = 0.7, ru = 0.62, rd = 0.56 },
			}, { step = 0.42, core = "Hide", coreScale = 0.9, tile = plates(0.7), belly = BELLY, color = skin })
			local neck = K:tube("Head", {
				{ 0, 3.12, -1.62, rx = 0.44, ru = 0.42, rd = 0.46 },
				{ 0, 3.06, -1.3, rx = 0.52, ru = 0.5, rd = 0.56 },
				{ 0, 2.9, -0.86, rx = 0.66, ru = 0.62, rd = 0.7 },
			}, { step = 0.36, core = "Hide", coreScale = 0.9, tile = plates(0.6), belly = BELLY, color = skin })
			local tail = K:tube("Tail", {
				{ 0, 2.42, 0.9, rx = 0.66, ru = 0.6, rd = 0.56 },
				{ -0.04, 2.34, 1.56, rx = 0.5, ru = 0.46, rd = 0.42 },
				{ -0.28, 2.1, 2.14, rx = 0.37, ru = 0.34, rd = 0.31 },
				{ -0.72, 1.82, 2.58, rx = 0.25, ru = 0.23, rd = 0.21 },
				{ -1.22, 1.64, 2.8, rx = 0.15, ru = 0.14, rd = 0.13 },
				{ -1.66, 1.6, 2.86, rx = 0.08, ru = 0.08, rd = 0.07 },
			}, { step = 0.36, core = "Hide", coreScale = 0.9, tile = plates(0.5, 5), belly = { key = "Belly", key2 = "Belly2", arc = 44, t = 0.11 }, color = skin, trim = 0.14 })

			-- the crest: stepped slate plates, tallest over the shoulders, from the neck to the tail tip
			local KEYS = { "RockDark", "Rock", "RockLight" }
			K:ridge("Head", neck, { style = "plate", keys = KEYS, from = 0.08, to = neck.total - 0.12, every = 0.34, height = function(u) return 0.42 + 0.2 * u end, thick = 0.15, lean = 16 })
			K:ridge("Body", torso, { style = "plate", keys = KEYS, from = 0.16, to = torso.total - 0.18, every = 0.42, height = function(u) return 0.74 + 0.24 * math.sin(u * math.pi) - 0.2 * u end, thick = 0.17, lean = 14 })
			K:ridge("Tail", tail, { style = "plate", keys = KEYS, from = 0.16, to = tail.total - 0.2, every = 0.36, height = function(u) return 0.14 + 0.5 * (1 - u) ^ 1.15 end, thick = function(u) return 0.15 - 0.06 * u end, lean = 22 })

			local tip = K:at(tail, tail.total)
			K:chain("Tail", { "Rock", "RockLight" }, tip.p - tip.T * 0.12, tip.T, tip.U, { n = 2, len = 0.34, w0 = 0.13, w1 = 0.08, bend = 0 })

			-- pebble osteoderms: a row of half-buried stones down each flank and along the tail
			local function pebbles(group, samples, thetas, every, size, from, to)
				local s, k = from, 0
				while s <= to do
					local smp = K:at(samples, s)
					for idx, th0 in thetas do
						local pos, nrm = K:surface(smp, th0 + rad(K:rand(-6, 6)), 0.02)
						local along = (smp.T - nrm * smp.T:Dot(nrm)).Unit
						local r = size * K:rand(0.8, 1.15) * math.sqrt(smp.rx / 0.9)
						local cf = CFrame.fromMatrix(pos, nrm:Cross(along), nrm) * CFrame.Angles(rad(K:rand(-20, 20)), rad(K:rand(0, 90)), rad(K:rand(-20, 20)))
						K:block(group, (k + idx) % 3 == 0 and "RockLight" or "Rock", cf, Vector3.new(r, r * 0.7, r))
					end
					s += every
					k += 1
				end
			end
			pebbles("Body", torso, { rad(78), rad(-78) }, 0.5, 0.26, 0.35, torso.total - 0.3)
			pebbles("Tail", tail, { rad(72), rad(-72) }, 0.46, 0.2, 0.25, tail.total * 0.55)

			-- scutes: dark plates down the front of a limb (theta 0 = the front for limbs built with ref = X)
			local function scutes(group, samples, from, to, count, w, l, key)
				for i = 0, count - 1 do
					local smp = K:at(samples, from + (to - from) * (count > 1 and i / (count - 1) or 0))
					K:tile(group, key or "HideDark", smp, 0, w * (1 - 0.12 * i), l, 0.1, 10, 2, 0.35)
				end
			end

			for _, x in { 1, -1 } do
				-- hind legs: massive thighs, shins angled back, a wide clawed foot; the left foot a little ahead
				local g = x == 1 and "LegL" or "LegR"
				local dz = x == 1 and -0.12 or 0.16
				local thigh = K:tube(g, {
					{ 0.76 * x, 2.36, 0.5, rx = 0.56, ru = 0.62, rd = 0.56 },
					{ 0.96 * x, 1.82, 0.22 + dz * 0.4, rx = 0.52, ru = 0.56, rd = 0.5 },
					{ 1.04 * x, 1.36, -0.02 + dz * 0.7, rx = 0.38, ru = 0.4, rd = 0.36 },
				}, { step = 0.34, ref = Vector3.xAxis, core = "Hide", coreScale = 1.0 })
				-- broad muscle plates over the front and outside of the thigh
				K:tile(g, "HideDark", K:at(thigh, thigh.total * 0.45), rad(25) * x, 0.66, 0.7, 0.13, 8, 2, 0.4)
				K:tile(g, "Hide", K:at(thigh, thigh.total * 0.7), rad(-10) * x, 0.5, 0.5, 0.12, 8, 2, 0.4)
				local shin = K:tube(g, {
					{ 1.04 * x, 1.42, -0.04 + dz * 0.7, rx = 0.33, ru = 0.33 },
					{ 1.04 * x, 0.56, 0.42 + dz, rx = 0.22, ru = 0.22 },
				}, { step = 0.3, ref = Vector3.xAxis, core = "Hide", coreScale = 0.98 })
				scutes(g, shin, 0.18, shin.total - 0.12, 3, 0.36, 0.34)
				K:tube(g, {
					{ 1.04 * x, 0.6, 0.42 + dz, rx = 0.21, ru = 0.21 },
					{ 1.04 * x, 0.2, 0.12 + dz, rx = 0.18, ru = 0.18 },
				}, { step = 0.4, ref = Vector3.xAxis, core = "Back", coreScale = 0.98 })
				-- stone armour on the outer thigh
				K:tile(g, "Rock", K:at(thigh, thigh.total * 0.3), rad(95) * x, 0.66, 0.62, 0.15, 12, 3, 0.25)
				local fz = dz - 0.02
				K:block(g, "Back", CFrame.new(1.04 * x, 0.13, fz - 0.06) * CFrame.Angles(0, rad(-6 * x), 0), Vector3.new(0.52, 0.26, 0.62))
				for t = -1, 1 do
					local dirT = CFrame.Angles(0, rad(t * 20 - 6 * x), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
					local base = Vector3.new(1.04 * x + t * 0.16, 0.1, fz - 0.28)
					K:block(g, "Hide", CFrame.lookAt(base + dirT * 0.15, base + dirT * 2), Vector3.new(0.15, 0.17, 0.34))
					K:chain(g, { "Claw", "Claw", "ClawTip" }, base + dirT * 0.3 + Vector3.new(0, 0.03, 0), (dirT - Vector3.new(0, 0.25, 0)).Unit, dirT:Cross(Vector3.yAxis), { n = 3, len = 0.3, w0 = 0.085, w1 = 0.05, bend = -28 })
				end

				-- arms: muscular, held forward and ready, three long hooked claws; a stone plate on the shoulder
				local ga = x == 1 and "ArmL" or "ArmR"
				K:tube(ga, {
					{ 0.78 * x, 2.6, -0.82, rx = 0.32, ru = 0.32 },
					{ 1.0 * x, 2.08, -0.96, rx = 0.25, ru = 0.25 },
				}, { step = 0.26, ref = Vector3.xAxis, core = "Hide", coreScale = 0.98 })
				local fore = K:tube(ga, {
					{ 1.0 * x, 2.1, -0.94, rx = 0.23, ru = 0.23 },
					{ 0.95 * x, 1.9, -1.4, rx = 0.18, ru = 0.18 },
				}, { step = 0.24, ref = Vector3.xAxis, core = "Hide", coreScale = 0.98 })
				K:block(ga, "Hide", CFrame.lookAt(Vector3.new(0.95 * x, 1.87, -1.45), Vector3.new(0.95 * x, 1.8, -2.2)), Vector3.new(0.26, 0.16, 0.26))
				for c = -1, 1 do
					local d = Vector3.new(c * 0.28, -0.25, -1).Unit
					K:chain(ga, { "Claw", "Claw", "ClawTip" }, Vector3.new(0.95 * x + c * 0.08, 1.85, -1.56), d, d:Cross(Vector3.yAxis), { n = 3, len = 0.38, w0 = 0.07, w1 = 0.045, bend = -26 })
				end
				K:block(ga, "Rock", CFrame.new(0.92 * x, 2.72, -0.82) * CFrame.Angles(rad(-10), 0, rad(-28 * x)), Vector3.new(0.46, 0.13, 0.54))
				K:block(ga, "RockDark", CFrame.new(1.04 * x, 2.1, -0.92) * CFrame.Angles(rad(-20), 0, rad(-50 * x)), Vector3.new(0.26, 0.1, 0.3))
			end

			-- head (head space: origin at the back of the skull, facing -Z, glaring down a little)
			local function hcf(px, py, pz, ax, ay, az)
				return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
			end
			local function hp(px, py, pz)
				return HEAD * Vector3.new(px, py, pz)
			end
			local function hv(px, py, pz)
				return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
			end
			-- cranium, snout, muzzle; the palate shows through the half-open mouth
			K:block("Head", "Hide", hcf(0, 0.16, -0.32), Vector3.new(0.78, 0.48, 0.62))
			K:block("Head", "Hide", hcf(0, 0.05, -0.82), Vector3.new(0.58, 0.38, 0.52))
			K:block("Head", "Hide", hcf(0, 0.0, -1.18, -4, 0, 0), Vector3.new(0.46, 0.32, 0.32))
			K:block("Head", "Mouth", hcf(0, -0.17, -0.8), Vector3.new(0.48, 0.06, 0.86))
			-- dark scales over the cranium and down the snout's ridge
			for i, z in { -0.08, -0.36, -0.68, -0.94, -1.18 } do
				local w = ({ 0.62, 0.66, 0.34, 0.3, 0.26 })[i]
				local y = z > -0.6 and 0.42 or (z > -1.06 and 0.25 or 0.17)
				K:block("Head", "Back", hcf(0, y, z, -10 + K:rand(-3, 3), K:rand(-3, 3), 0), Vector3.new(w, 0.08, 0.32))
			end
			-- crest plates on the skull leading into the neck's
			for i, z in { -0.28, -0.02 } do
				K:plate("Head", KEYS, hp(0, 0.4, z), hv(0, 1, 0.2), hv(0, -0.2, 1), { h = 0.34 + i * 0.06, w = 0.24, t = 0.13, n = 2, lean = 18 })
			end
			-- nose horn
			K:chain("Head", { "Rock", "Rock", "RockLight" }, hp(0, 0.2, -1.04), hv(0, 1, -0.3), hv(1, 0, 0), { n = 3, len = 0.42, w0 = 0.2, w1 = 0.1, bend = 16 })
			for _, x in { 1, -1 } do
				-- jaw muscles flaring wide at the back: a wedge-shaped face
				K:block("Head", "Hide", hcf(0.42 * x, -0.02, -0.26, 0, -10 * x, 6 * x), Vector3.new(0.28, 0.46, 0.6))
				-- beveled snout edges: a ridged, roof-shaped muzzle
				K:block("Head", "HideDark", hcf(0.17 * x, 0.2, -0.84, -2, 0, -30 * x), Vector3.new(0.2, 0.1, 0.5))
				K:block("Head", "HideDark", hcf(0.13 * x, 0.13, -1.16, -6, 0, -30 * x), Vector3.new(0.17, 0.09, 0.3))
				-- heavy stone brow: a V that overhangs the eyes
				K:block("Head", "RockDark", hcf(0.25 * x, 0.44, -0.58, -8, -12 * x, 16 * x), Vector3.new(0.4, 0.17, 0.44))
				-- a dark socket and a narrow glowing slit tucked under the brow
				K:block("Head", "Socket", hcf(0.36 * x, 0.3, -0.62, 0, -32 * x, 12 * x), Vector3.new(0.23, 0.11, 0.06))
				K:block("Head", "Eye", hcf(0.36 * x, 0.3, -0.65, 0, -32 * x, 12 * x), Vector3.new(0.17, 0.05, 0.04))
				-- swept-back brow horns
				K:chain("Head", { "Rock", "Rock", "RockLight" }, hp(0.32 * x, 0.5, -0.44), hv(0.25 * x, 0.7, 0.66), hv(1, 0, 0), { n = 3, len = 0.5, w0 = 0.17, w1 = 0.1, bend = 12 })
				-- cheek spikes flaring out behind the jaw
				K:spike("Head", "RockLight", hp(0.52 * x, -0.04, -0.06), hv(0.65 * x, 0.1, 0.75), hv(0, 1, 0), 0.2, 0.08)
				K:spike("Head", "Rock", hp(0.5 * x, 0.18, 0.02), hv(0.55 * x, 0.35, 0.75), hv(0, 1, 0), 0.16, 0.07)
				-- upper teeth along the snout and muzzle
				local n = 0
				for z = -0.48, -1.3, -0.135 do
					n += 1
					local half = z > -1.06 and 0.26 or 0.19
					K:spike("Head", "Tooth", hp(half * x, -0.15, z), hv(0, -1, 0.15), hv(1, 0, 0), n % 2 == 0 and 0.075 or 0.095, 0.05)
				end
			end
			for _, x in { -0.12, 0, 0.12 } do
				K:spike("Head", "Tooth", hp(x, -0.13, -1.31), hv(0, -1, 0.1), hv(0, 0, 1), 0.08, 0.05)
			end

			-- lower jaw, half open: teeth up both sides, pale throat, dark tongue
			local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-13), 0, 0)
			local function jcf(px, py, pz, ax, ay, az)
				return JAW * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
			end
			K:block("Jaw", "Hide", jcf(0, -0.1, -0.6), Vector3.new(0.58, 0.2, 1.12))
			K:block("Jaw", "Hide", jcf(0, -0.08, -1.12), Vector3.new(0.44, 0.2, 0.22))
			K:block("Jaw", "Belly", jcf(0, -0.21, -0.55), Vector3.new(0.46, 0.06, 0.92))
			K:block("Jaw", "Mouth", jcf(0, 0.01, -0.62), Vector3.new(0.42, 0.04, 0.9))
			for _, x in { 1, -1 } do
				for z = -0.5, -1.1, -0.15 do
					K:spike("Jaw", "Tooth", JAW * Vector3.new(0.23 * x, 0, z), JAW:VectorToWorldSpace(Vector3.new(0, 1, -0.1)).Unit, JAW:VectorToWorldSpace(Vector3.xAxis), 0.07, 0.045)
				end
				K:block("Jaw", "Rock", jcf(0.3 * x, -0.14, -0.3, K:rand(-20, 20), K:rand(0, 60), K:rand(-20, 20)), Vector3.new(0.13, 0.1, 0.13))
			end
		end,
	}
end


return spec
