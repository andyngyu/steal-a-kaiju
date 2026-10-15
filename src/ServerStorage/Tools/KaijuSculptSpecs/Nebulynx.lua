local rad = math.rad
local H = require(script.Parent.Helpers)

-- Cosmic Rift / Uncommon / void: the nebulynx, a lynx made of night sky. A lean, long-legged cat crouched to pounce,
-- its indigo coat swept by a big spiral nebula on each flank in teal and rose, flecked with stars, a lavender belly, a
-- ruff round the neck, a short bobbed tail with a dark tip. Long crystal claws. Face: a sleek cat skull with a short
-- dark muzzle, glowing teal eyes under a dark brow, a lynx's cheek ruffs flaring out, tall forward-facing ears with
-- rose insides and long black tufts, long fangs.
local HEAD = CFrame.new(0, 1.84, -1.6) * CFrame.Angles(rad(-8), 0, 0)
local HINGE = Vector3.new(0, -0.14, -0.12)
local HS = 1.15

local function hj(v)
	return HEAD.Position + (HEAD * v - HEAD.Position) * HS
end

return {
	Seed = 711,
	Vary = 0.04,
	Scale = 1.1,
	Gait = "Trot",
	Emotes = { "Look", "PlayBow", "Paw" },
	Palette = {
		Fur = "3E3476",
		FurDark = "2A225A",
		FurLight = "5C4E9C",
		Belly = "B4A6DC",
		Belly2 = "A092CC",
		Teal = "2EB4B0",
		TealLight = "7EE4DA",
		Rose = "DC5C8C",
		RoseLight = "F4A2BE",
		Star = { "FFF4FF", Neon = true },
		Crystal = "D0C2FF",
		CrystalDark = "8A72E0",
		Muzzle = "1E1838",
		Nose = "0A0810",
		Tooth = "EEE8F4",
		Mouth = "4A1A44",
		Eye = { "5AF2E6", Neon = true },
		Socket = "07050C",
		Claw = "D0C2FF",
		ClawTip = "F4EEFF",
	},
	Joints = {
		Head = { 0, 1.84, -1.1 },
		Jaw = hj(HINGE),
		EarL = hj(Vector3.new(0.24, 0.3, -0.06)),
		EarR = hj(Vector3.new(-0.24, 0.3, -0.06)),
		LegFL = { 0.42, 1.7, -0.86 },
		LegFR = { -0.42, 1.7, -0.86 },
		LegBL = { 0.4, 1.66, 0.96 },
		LegBR = { -0.4, 1.66, 0.96 },
		Tail = { 0, 1.72, 1.18 },
	},
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		-- the coat: a dark stripe down the spine, and on each flank a big spiral nebula in teal and rose, its arms
		-- winding out from a bright centre; plain indigo fur round it
		local function coat(th, ring, smp)
			local a = math.abs(th)
			if a < rad(24) then
				return "FurDark"
			end
			if not smp then
				return "Fur"
			end
			local y = (a - rad(78)) * smp.rx
			local z = smp.p.Z - 0.15
			local r = math.sqrt(y * y + z * z)
			if r < 1.25 and a < rad(135) then
				if r < 0.2 then
					return "TealLight"
				end
				local s = math.sin(2 * math.atan2(y, z) - r * 4.5)
				if s > 0.3 then
					return r < 0.6 and "RoseLight" or "Rose"
				elseif s > -0.35 then
					return r < 0.6 and "TealLight" or "Teal"
				end
				return "FurDark"
			end
			return ring % 2 == 0 and "Fur" or "FurLight"
		end
		local belly = { key = "Belly", key2 = "Belly2", arc = 40, t = 0.09, wide = 1.05 }
		local body = K:tube("Body", {
			{ 0, 1.78, -0.96, rx = 0.5, ru = 0.52, rd = 0.56 },
			{ 0, 1.76, -0.3, rx = 0.52, ru = 0.5, rd = 0.5 },
			{ 0, 1.68, 0.46, rx = 0.46, ru = 0.42, rd = 0.38 },
			{ 0, 1.72, 1.08, rx = 0.46, ru = 0.44, rd = 0.42 },
		}, { step = 0.2, core = "FurDark", coreScale = 0.86, tile = { w = 0.22, l = 0.26, t = 0.09, lift = 6, jitter = 2, sink = 0.45, overlap = 1.18 }, belly = belly, color = coat })
		local neck = K:tube("Head", {
			{ 0, 1.86, -1.58, rx = 0.32, ru = 0.32, rd = 0.34 },
			{ 0, 1.86, -1.32, rx = 0.4, ru = 0.4, rd = 0.44 },
			{ 0, 1.8, -1.0, rx = 0.5, ru = 0.52, rd = 0.56 },
		}, { step = 0.2, core = "FurDark", coreScale = 0.86, tile = H.fur(0.22, nil, 0.26, 8), belly = belly, color = function(th, ring)
			return math.abs(th) < rad(24) and "FurDark" or (ring % 2 == 0 and "Fur" or "FurLight")
		end })
		-- stars flecked through the coat, more of them in the nebulae
		for i = 1, 34 do
			local x = i % 2 == 0 and 1 or -1
			local smp = K:at(body, K:rand(0.2, 1.9))
			local pos = K:surface(smp, rad(K:rand(50, 115)) * x, -0.11)
			local s = i % 5 == 0 and 0.11 or 0.07
			K:block("Body", "Star", CFrame.new(pos) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(s, s, s))
		end
		-- a ruff round the neck
		for k = 0, 9 do
			local th = rad(-150 + k * 33)
			local smp = K:at(neck, neck.total - 0.12)
			local pos, nrm = K:surface(smp, th, 0.02)
			K:chain("Head", { "Fur", k % 3 == 0 and "Teal" or "FurLight", "Belly" }, pos, (nrm * 0.6 + smp.T).Unit, smp.R, { n = 3, len = 0.3, w0 = 0.12, w1 = 0.06, bend = 0, depth = 0.5 })
		end
		-- a short bobbed tail with a dark tip
		K:chain("Tail", { "Fur", "FurLight", "FurDark" }, Vector3.new(0, 1.82, 1.14), Vector3.new(0, 0.55, 1).Unit, Vector3.xAxis, { n = 3, len = 0.5, w0 = 0.22, w1 = 0.16, bend = 10, tip = false })

		-- long legs, big paws with long crystal claws
		local function legFur(_, ring)
			return ring % 2 == 0 and "Fur" or "FurLight"
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

		-- head: a sleek cat skull, a short dark muzzle, glowing eyes, cheek ruffs, tufted ears
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
			-- a smooth rounded cranium tapering forward
			K:block("Head", "Fur", hcf(0, 0.12, -0.2), Vector3.new(0.62, 0.44, 0.56))
			K:block("Head", "Fur", hcf(0, 0.14, -0.22, 0, 0, 45), Vector3.new(0.46, 0.46, 0.52))
			K:block("Head", "FurDark", hcf(0, 0.34, -0.24, -10, 0, 0), Vector3.new(0.3, 0.08, 0.48))
			K:block("Head", "Fur", hcf(0, 0.08, -0.48, -8, 0, 0), Vector3.new(0.5, 0.34, 0.24))
			-- the dark brow line over the eyes
			K:block("Head", "FurDark", hcf(0, 0.28, -0.54, -10, 0, 0), Vector3.new(0.5, 0.08, 0.1))
			-- a short dark muzzle with whisker pads and a dark nose
			K:block("Head", "Muzzle", hcf(0, -0.04, -0.66), Vector3.new(0.32, 0.22, 0.22))
			for _, x in { 1, -1 } do
				K:block("Head", "Muzzle", hcf(0.09 * x, -0.07, -0.72), Vector3.new(0.16, 0.15, 0.14))
			end
			K:block("Head", "Nose", hcf(0, 0.05, -0.78, -12, 0, 0), Vector3.new(0.12, 0.07, 0.06))
			K:block("Head", "FurDark", hcf(0, 0.12, -0.68, -14, 0, 0), Vector3.new(0.12, 0.06, 0.22))
			K:block("Head", "Mouth", hcf(0, -0.16, -0.62), Vector3.new(0.28, 0.04, 0.24))
			for _, x in { 1, -1 } do
				-- big almond eyes slanting up, a dark rim and a tear-line down from each
				K:block("Head", "FurDark", hcf(0.18 * x, 0.18, -0.56, 0, -22 * x, 16 * x), Vector3.new(0.24, 0.12, 0.05))
				H.eye(K, "Head", hcf(0.18 * x, 0.18, -0.59, 0, -22 * x, 16 * x), 0.18, 0.07)
				K:block("Head", "FurDark", hcf(0.14 * x, 0.02, -0.6, 0, -16 * x, -14 * x), Vector3.new(0.04, 0.2, 0.04))
				-- cheeks, then the lynx's ruff flaring out and down from them
				K:block("Head", "FurLight", hcf(0.28 * x, -0.02, -0.38, 0, -12 * x, 0), Vector3.new(0.16, 0.3, 0.36))
				for k = 0, 2 do
					K:chain("Head", { "FurLight", "Belly", "Belly" }, hp(0.32 * x, -0.04 - k * 0.07, -0.34 + k * 0.08), hv(0.75 * x, -0.45 - k * 0.25, 0.35), hv(0, 0, 1), { n = 3, len = 0.38 - k * 0.04, w0 = 0.15, w1 = 0.06, bend = 0, depth = 0.45 })
				end
				-- long fangs
				H.fang(K, "Head", "Tooth", hp(0.08 * x, -0.15, -0.72), hv(0, -1, -0.05), 0.22, 0.05)
				-- tall triangular ears facing forward, rose inside, a long black tuft at the tip
				local g = x == 1 and "EarL" or "EarR"
				local base, up = hp(0.24 * x, 0.3, -0.06), hv(0.28 * x, 1, 0.05)
				K:plate(g, { "Fur", "FurDark", "FurDark" }, base, up, hv(x, 0, 0), { h = 0.5, w = 0.38, t = 0.07, n = 3, lean = 6, shift = 0.06 })
				K:block(g, "Rose", CFrame.fromMatrix(base + up * 0.2 + hv(0, 0, -1) * 0.05, hv(x, 0, 0):Cross(up).Unit * x, up), Vector3.new(0.03, 0.26, 0.18))
				K:chain(g, { "FurDark", "FurDark", "FurDark" }, base + up * 0.48, hv(0.1 * x, 1, 0.08), hv(0, 0, 1), { n = 3, len = 0.32, w0 = 0.06, w1 = 0.035, bend = -10 })
			end
			local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-14), 0, 0)
			K:block("Jaw", "Fur", JAW * CFrame.new(0, -0.07, -0.34), Vector3.new(0.36, 0.13, 0.5))
			K:block("Jaw", "Belly", JAW * CFrame.new(0, -0.12, -0.3), Vector3.new(0.3, 0.06, 0.44))
			K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.36), Vector3.new(0.28, 0.04, 0.44))
			for _, x in { 1, -1 } do
				H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.11 * x, 0, -0.2), JAW * Vector3.new(0.09 * x, 0, -0.5), 3, JAW:VectorToWorldSpace(Vector3.yAxis), JAW:VectorToWorldSpace(Vector3.xAxis), 0.05, 0.035)
			end
		end)
	end,
}
