local rad = math.rad
local H = require(script.Parent.Helpers)

-- Cosmic Rift / Uncommon / void: the nebulynx, a lynx made of night sky. A lean, long-legged cat crouched to pounce,
-- its black fur swirled with clouds of violet and pink nebula and flecked with stars, a thick ruff round the neck, a
-- short tail. Long crystal claws. Face: a broad cat skull, tall tufted ears tipped with starlight, a scowling brow over
-- glowing pink eyes, long fangs.
local HEAD = CFrame.new(0, 1.84, -1.6) * CFrame.Angles(rad(-10), 0, 0)
local HINGE = Vector3.new(0, -0.14, -0.12)
local HS = 1.2

local function hj(v)
	return HEAD.Position + (HEAD * v - HEAD.Position) * HS
end

return {
	Seed = 711,
	Vary = 0.05,
	Scale = 1.1,
	Gait = "Trot",
	Emotes = { "Look", "PlayBow", "Paw" },
	Palette = {
		Fur = "241C36",
		FurDark = "120E1C",
		FurLight = "3A2E58",
		Face = "6E5C9A",
		FaceLight = "A898D0",
		Nebula = "6A3AB8",
		NebulaPink = "C2489E",
		NebulaLight = "9A6AE0",
		Belly = "3A2C58",
		Belly2 = "30244A",
		Star = { "FFF4FF", Neon = true },
		Glow = { "FF5AD8", Neon = true },
		Crystal = "D0C2FF",
		CrystalDark = "8A72E0",
		Muzzle = "8C7CB8",
		Nose = "0A0810",
		Tooth = "EEE8F4",
		Mouth = "4A1A44",
		Eye = { "FF7AE8", Neon = true },
		Socket = "07050C",
		Claw = "D0C2FF",
		ClawTip = "F4EEFF",
	},
	Joints = {
		Head = { 0, 1.84, -1.1 },
		Jaw = hj(HINGE),
		EarL = hj(Vector3.new(0.26, 0.36, 0.0)),
		EarR = hj(Vector3.new(-0.26, 0.36, 0.0)),
		LegFL = { 0.42, 1.7, -0.86 },
		LegFR = { -0.42, 1.7, -0.86 },
		LegBL = { 0.4, 1.66, 0.96 },
		LegBR = { -0.4, 1.66, 0.96 },
		Tail = { 0, 1.72, 1.18 },
	},
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		-- black fur swirled with nebula clouds: the colour drifts in patches along the body and round it
		local function nebula(th, ring, smp)
			local a = math.abs(th)
			if a > rad(118) then
				return ring % 2 == 0 and "FurLight" or "Fur"
			end
			local z = smp and smp.p.Z or 0
			local n = math.sin(z * 4.2 + th * 2.6) + math.sin(z * 2.3 - th * 3.8 + 1.3)
			if n > 1.1 then
				return "NebulaPink"
			elseif n > 0.5 then
				return "Nebula"
			elseif n > 0.15 then
				return "NebulaLight"
			end
			return ring % 2 == 0 and "Fur" or (a < rad(30) and "FurDark" or "FurLight")
		end
		local belly = { key = "Belly", key2 = "Belly2", arc = 36, t = 0.09, wide = 1.05 }
		local body = K:tube("Body", {
			{ 0, 1.78, -0.96, rx = 0.5, ru = 0.52, rd = 0.56 },
			{ 0, 1.76, -0.3, rx = 0.52, ru = 0.5, rd = 0.5 },
			{ 0, 1.68, 0.46, rx = 0.44, ru = 0.42, rd = 0.38 },
			{ 0, 1.72, 1.08, rx = 0.46, ru = 0.44, rd = 0.42 },
		}, { step = 0.26, core = "FurDark", coreScale = 0.86, tile = H.fur(0.3, nil, 0.36, 16), belly = belly, color = nebula })
		local neck = K:tube("Head", {
			{ 0, 1.86, -1.58, rx = 0.32, ru = 0.32, rd = 0.34 },
			{ 0, 1.86, -1.32, rx = 0.4, ru = 0.4, rd = 0.44 },
			{ 0, 1.8, -1.0, rx = 0.5, ru = 0.52, rd = 0.56 },
		}, { step = 0.2, core = "FurDark", coreScale = 0.86, tile = H.fur(0.24, nil, 0.26, 8), belly = belly, color = nebula })
		-- stars flecked through the fur, the brightest in the nebula patches
		for i = 1, 30 do
			local onNeck = i % 4 == 0
			local smps = onNeck and neck or body
			local smp = K:at(smps, K:rand(0.1, smps.total - 0.1))
			local pos = K:surface(smp, rad(K:rand(-110, 110)), -0.12)
			local s = i % 5 == 0 and 0.11 or 0.07
			K:block(onNeck and "Head" or "Body", "Star", CFrame.new(pos) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(s, s, s))
		end
		-- a thick ruff round the neck, the fur standing out in points
		for k = 0, 9 do
			local th = rad(-150 + k * 33)
			local smp = K:at(neck, neck.total - 0.12)
			local pos, nrm = K:surface(smp, th, 0.02)
			K:chain("Head", { "FurDark", k % 3 == 0 and "Nebula" or "Fur", "FurLight" }, pos, (nrm * 0.6 + smp.T).Unit, smp.R, { n = 3, len = 0.32, w0 = 0.12, w1 = 0.06, bend = 0, depth = 0.5 })
		end
		-- a short bobbed tail with a starlit tip
		K:chain("Tail", { "Fur", "Nebula", "FurDark" }, Vector3.new(0, 1.82, 1.14), Vector3.new(0, 0.55, 1).Unit, Vector3.xAxis, { n = 3, len = 0.5, w0 = 0.22, w1 = 0.16, bend = 10, tip = false })
		K:block("Tail", "Star", CFrame.new(0, 2.12, 1.58) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.12, 0.12, 0.12))

		-- long legs, big paws with long crystal claws
		local function legFur(th, ring)
			return ring % 2 == 0 and "Fur" or "FurDark"
		end
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.42 * x, 1.72, -0.86, 0.32 },
				{ 0.48 * x, 0.98, -0.8, 0.22 },
				{ 0.46 * x, 0.3, -0.96, 0.17 },
			}, { step = 0.24, cores = { "Fur", "FurDark" }, tiles = { H.fur(0.2, 5, 0.24, 6), nil }, color = legFur, foot = { size = Vector3.new(0.42, 0.2, 0.46), key = "FurDark" }, toes = 4, claw = { len = 0.3, w = 0.07, curl = 40 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.4 * x, 1.68, 0.96, 0.36 },
				{ 0.46 * x, 1.1, 0.66, 0.26 },
				{ 0.46 * x, 0.56, 1.08, 0.17 },
				{ 0.46 * x, 0.2, 0.98, 0.15 },
			}, { step = 0.24, cores = { "Fur", "FurDark", "FurDark" }, tiles = { H.fur(0.22, 5, 0.26, 6), nil, nil }, color = legFur, foot = { size = Vector3.new(0.4, 0.2, 0.46), key = "FurDark" }, toes = 4, claw = { len = 0.28, w = 0.065, curl = 40 } })
		end

		-- head: a broad cat skull, tall tufted ears, a scowl, long fangs
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:scaled(HEAD.Position, HS, function()
			K:block("Head", "Fur", hcf(0, 0.14, -0.24), Vector3.new(0.82, 0.56, 0.62))
			K:block("Head", "Fur", hcf(0, 0.16, -0.26, 0, 0, 45), Vector3.new(0.58, 0.58, 0.56))
			K:block("Head", "Nebula", hcf(0, 0.42, -0.32, -18, 0, 0), Vector3.new(0.46, 0.1, 0.44))
			-- a pale face mask round the eyes and down the muzzle, so the face reads against the dark fur
			K:block("Head", "Face", hcf(0, 0.12, -0.52), Vector3.new(0.74, 0.4, 0.06))
			K:block("Head", "Muzzle", hcf(0, -0.04, -0.66), Vector3.new(0.6, 0.38, 0.42))
			K:block("Head", "Face", hcf(0, 0.16, -0.68, -10, 0, 0), Vector3.new(0.24, 0.14, 0.44))
			K:block("Head", "Nose", hcf(0, 0.08, -0.9, -10, 0, 0), Vector3.new(0.2, 0.11, 0.08))
			K:block("Head", "Mouth", hcf(0, -0.2, -0.6), Vector3.new(0.46, 0.04, 0.44))
			K:block("Head", "FurDark", hcf(0, 0.32, -0.53, -6, 0, 0), Vector3.new(0.7, 0.12, 0.16))
			for _, x in { 1, -1 } do
				K:block("Head", "FurDark", hcf(0.2 * x, 0.35, -0.54, -6, -10 * x, 18 * x), Vector3.new(0.36, 0.15, 0.3))
				H.eye(K, "Head", hcf(0.24 * x, 0.2, -0.6, 0, -24 * x, 18 * x), 0.2, 0.07)
				K:block("Head", "FaceLight", hcf(0.15 * x, -0.08, -0.77), Vector3.new(0.28, 0.28, 0.3))
				-- nebula markings swirling across the cheek and up over the skull, stars in them
				K:block("Head", "Nebula", hcf(0.42 * x, 0.12, -0.3, 0, -8 * x, -24 * x), Vector3.new(0.05, 0.16, 0.5))
				K:block("Head", "NebulaPink", hcf(0.42 * x, 0.26, -0.16, 0, -8 * x, -38 * x), Vector3.new(0.05, 0.12, 0.36))
				K:block("Head", "NebulaLight", hcf(0.41 * x, -0.04, -0.2, 0, -8 * x, 10 * x), Vector3.new(0.05, 0.1, 0.4))
				K:block("Head", "Star", hcf(0.44 * x, 0.18, -0.36), Vector3.new(0.06, 0.06, 0.06))
				-- dark tear-lines down from the eyes
				K:block("Head", "FurDark", hcf(0.2 * x, 0.04, -0.62, 0, -20 * x, -20 * x), Vector3.new(0.05, 0.22, 0.06))
				-- lynx cheek ruffs fanning out below the ears
				for k = 0, 2 do
					K:chain("Head", { "Fur", k == 1 and "NebulaLight" or "FurLight" }, hp(0.38 * x, 0.04 - k * 0.1, -0.24), hv(0.85 * x, -0.3 - k * 0.2, 0.4), hv(0, 0, 1), { n = 2, len = 0.34, w0 = 0.14, w1 = 0.07, bend = 0, depth = 0.5 })
				end
				-- long fangs over the lower lip
				H.fang(K, "Head", "Tooth", hp(0.15 * x, -0.2, -0.78), hv(0, -1, -0.05), 0.3, 0.06)
				-- tall pointed ears with starlit tufts
				local g = x == 1 and "EarL" or "EarR"
				-- broad triangular ears facing forward, a nebula-pink inner ear, a long black tuft tipped with a star
				K:plate(g, { "Fur", "FurDark", "FurDark" }, hp(0.26 * x, 0.3, -0.02), hv(0.3 * x, 1, 0.1), hv(x, 0, 0), { h = 0.62, w = 0.44, t = 0.09, n = 3, lean = 6, shift = 0.08 })
				K:block(g, "NebulaPink", hcf(0.3 * x, 0.52, -0.08, 0, 0, -18 * x), Vector3.new(0.22, 0.3, 0.04))
				K:chain(g, { "FurDark", "FurDark", "FurDark" }, hp(0.42 * x, 0.88, -0.02), hv(0.15 * x, 1, 0.05), hv(0, 0, 1), { n = 3, len = 0.3, w0 = 0.07, w1 = 0.04, bend = -10 })
			end
			local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-16), 0, 0)
			K:block("Jaw", "Fur", JAW * CFrame.new(0, -0.08, -0.38), Vector3.new(0.48, 0.16, 0.6))
			K:block("Jaw", "Muzzle", JAW * CFrame.new(0, -0.1, -0.64), Vector3.new(0.38, 0.18, 0.16))
			K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.4), Vector3.new(0.38, 0.04, 0.52))
			for _, x in { 1, -1 } do
				H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.15 * x, 0, -0.2), JAW * Vector3.new(0.13 * x, 0, -0.56), 3, JAW:VectorToWorldSpace(Vector3.yAxis), JAW:VectorToWorldSpace(Vector3.xAxis), 0.06, 0.04)
			end
		end)
	end,
}
