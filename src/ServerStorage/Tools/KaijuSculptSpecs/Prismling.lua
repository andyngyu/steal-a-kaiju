local rad = math.rad
local H = require(script.Parent.Helpers)

-- Any biome / Secret / crystal: a sleek crystal raptor that bends light. Obsidian-violet plated hide striped in black,
-- prismatic shards (magenta, cyan, violet, gold) bursting along its spine, quilled down its arms and fanned into a
-- blade at the tail tip, a crown of crystals, long sickle claws, magenta eyes.
local HEAD = CFrame.new(0, 3.4, -1.28) * CFrame.Angles(rad(-6), 0, 0)
local HINGE = Vector3.new(0, -0.12, -0.16)

return {
	Seed = 53,
	Vary = 0.05,
	Gait = "Biped",
	Emotes = { "Look", "Roar" },
	Palette = {
		Hide = "3C3550",
		HideDark = "2A243B",
		HideLight = "625979",
		Back = "16111E",
		Belly = "ADA4C2",
		Belly2 = "8F86A8",
		Magenta = { "C43CFF", Material = "Glass" },
		Cyan = { "2CCBFF", Material = "Glass" },
		Violet = { "6C4CFF", Material = "Glass" },
		Gold = { "FFBE34", Material = "Glass" },
		Glow = { "6FE6FF", Neon = true },
		Tooth = "F4F2F8",
		Claw = "15111C",
		ClawTip = "E6E0FF",
		Mouth = "3C1838",
		Eye = { "FF4FE8", Neon = true },
		Socket = "120E1C",
	},
	Joints = {
		Head = { 0, 2.66, -0.6 },
		Jaw = HEAD * HINGE,
		LegL = { 0.5, 2.46, 0.42 },
		LegR = { -0.5, 2.46, 0.42 },
		ArmL = { 0.5, 2.6, -0.66 },
		ArmR = { -0.5, 2.6, -0.66 },
		Tail = { 0, 2.56, 0.78 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 36, band = 90, every = 2 })
		local PRISM = { "Magenta", "Cyan", "Violet", "Gold", "Glow" }
		local function prism(i)
			return { PRISM[(i - 1) % 4 + 1], PRISM[i % 4 + 1], "Glow", PRISM[(i + 1) % 4 + 1] }
		end
		local belly = { key = "Belly", key2 = "Belly2", arc = 46, t = 0.11, wide = 1.1 }
		-- lean torso held level, an S-curved neck, a long stiff tail held high
		local torso = K:tube("Body", {
			{ 0, 2.62, -0.62, rx = 0.56, ru = 0.54, rd = 0.62 },
			{ 0, 2.56, -0.12, rx = 0.66, ru = 0.6, rd = 0.7 },
			{ 0, 2.54, 0.4, rx = 0.62, ru = 0.56, rd = 0.58 },
			{ 0, 2.56, 0.8, rx = 0.5, ru = 0.46, rd = 0.44 },
		}, { step = 0.36, core = "Hide", coreScale = 0.9, tile = H.plates(0.5, nil, 0.11), belly = belly, color = skin })
		local neck = K:tube("Head", {
			{ 0, 3.36, -1.22, rx = 0.32, ru = 0.3, rd = 0.34 },
			{ 0, 3.06, -1.02, rx = 0.36, ru = 0.34, rd = 0.38 },
			{ 0, 2.74, -0.62, rx = 0.46, ru = 0.44, rd = 0.5 },
		}, { step = 0.3, core = "Hide", coreScale = 0.9, tile = H.plates(0.4, nil, 0.1), belly = belly, color = skin })
		local tail = K:tube("Tail", {
			{ 0, 2.58, 0.7, rx = 0.48, ru = 0.44, rd = 0.42 },
			{ 0, 2.66, 1.46, rx = 0.34, ru = 0.32, rd = 0.3 },
			{ -0.1, 2.76, 2.2, rx = 0.22, ru = 0.21, rd = 0.2 },
			{ -0.34, 2.84, 2.86, rx = 0.12, ru = 0.12, rd = 0.11 },
			{ -0.6, 2.9, 3.28, rx = 0.06, ru = 0.06, rd = 0.06 },
		}, { step = 0.32, core = "Hide", coreScale = 0.9, tile = H.plates(0.36, 4, 0.1), belly = belly, color = skin, trim = 0.1 })
		-- prism shards bursting along the spine; a fan of blades at the tail tip
		local s, i = 0.2, 0
		for _, part in { { "Head", neck, 0.42, 0.12 }, { "Body", torso, 0.8, 0.0 }, { "Tail", tail, 0.62, 0.0 } } do
			local group, samples, size = part[1], part[2], part[3]
			local n = math.floor((samples.total - 0.3) / 0.4)
			for k = 0, n do
				i += 1
				local u = n > 0 and k / n or 0
				local smp = K:at(samples, 0.18 + (samples.total - 0.4) * u)
				local pos, nrm = K:surface(smp, 0, 0.04)
				local sz = group == "Tail" and size * (1 - u) + 0.14 or (group == "Body" and size * (0.75 + 0.35 * math.sin(u * math.pi)) or size)
				H.crystal(K, group, prism(i), pos, (nrm + smp.T * 0.4).Unit, sz, group == "Body" and 4 or 3, 30)
			end
		end
		local tip = K:at(tail, tail.total)
		for j = 1, 3 do
			local d = CFrame.fromAxisAngle(tip.U, rad((j - 2) * 28)) * tip.T
			K:chain("Tail", { prism(j)[1], prism(j)[2], "Glow" }, tip.p - tip.T * 0.1, (d + tip.U * 0.15).Unit, tip.U, { n = 3, len = 0.62 - math.abs(j - 2) * 0.16, w0 = 0.13, w1 = 0.07, bend = 0 })
		end

		for _, x in { 1, -1 } do
			-- long digitigrade legs, a raised sickle claw on each foot
			local g = x == 1 and "LegL" or "LegR"
			local dz = x == 1 and -0.12 or 0.14
			local leg = H.limb(K, g, {
				{ 0.5 * x, 2.56, 0.42, 0.46, 0.52 },
				{ 0.64 * x, 1.96, 0.18 + dz * 0.4, 0.4, 0.44 },
				{ 0.66 * x, 1.52, -0.02 + dz * 0.7, 0.28 },
				{ 0.66 * x, 0.62, 0.46 + dz, 0.17 },
				{ 0.66 * x, 0.16, 0.1 + dz, 0.14 },
			}, { step = 0.3, cores = { "Hide", "Hide", "HideDark", "Back" } })
			K:tile(g, "HideDark", K:at(leg[1], leg[1].total * 0.5), rad(25) * x, 0.56, 0.6, 0.12, 8, 2, 0.4)
			K:tile(g, "Back", K:at(leg[1], leg[1].total * 0.45), rad(95) * x, 0.5, 0.5, 0.12, 6, 2, 0.4)
			H.scutes(K, g, leg[3], 0.16, leg[3].total - 0.12, 3, 0.3, 0.3, "HideDark")
			local fz = dz - 0.02
			K:block(g, "Back", CFrame.new(0.66 * x, 0.12, fz - 0.06), Vector3.new(0.34, 0.22, 0.46))
			for t = -1, 1, 2 do
				local dirT = CFrame.Angles(0, rad(t * 14 - 4 * x), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
				local base = Vector3.new(0.66 * x + t * 0.1, 0.1, fz - 0.24)
				K:block(g, "HideDark", CFrame.lookAt(base + dirT * 0.13, base + dirT * 2), Vector3.new(0.13, 0.14, 0.3))
				K:chain(g, { "Claw", "ClawTip" }, base + dirT * 0.28, (dirT - Vector3.new(0, 0.3, 0)).Unit, dirT:Cross(Vector3.yAxis), { n = 2, len = 0.18, w0 = 0.07, w1 = 0.05, bend = -30 })
			end
			-- the sickle claw, held up off the ground
			K:chain(g, { "Claw", "Claw", "ClawTip" }, Vector3.new(0.66 * x, 0.24, fz - 0.14), Vector3.new(0, 1, -0.55).Unit, Vector3.xAxis, { n = 3, len = 0.44, w0 = 0.09, w1 = 0.055, bend = 32 })

			-- long grasping arms with crystal quills and three long claws
			local ga = x == 1 and "ArmL" or "ArmR"
			local arm = H.limb(K, ga, {
				{ 0.5 * x, 2.62, -0.66, 0.2 },
				{ 0.7 * x, 2.18, -0.58, 0.15 },
				{ 0.64 * x, 2.0, -1.06, 0.12 },
			}, { step = 0.22 })
			K:block(ga, "HideDark", CFrame.lookAt(Vector3.new(0.64 * x, 1.98, -1.1), Vector3.new(0.64 * x, 1.9, -1.8)), Vector3.new(0.18, 0.12, 0.2))
			H.claws(K, ga, Vector3.new(0.64 * x, 1.96, -1.18), Vector3.new(0, -0.3, -1), Vector3.xAxis, { n = 3, spread = 0.14, fan = 26, len = 0.38, w = 0.055, curl = 30 })
			for q = 1, 3 do
				local smp = K:at(arm[2], arm[2].total * (q - 0.5) / 3)
				local pos, nrm = K:surface(smp, rad(110) * x, 0.02)
				K:chain(ga, { PRISM[(q + (x == 1 and 0 or 2)) % 4 + 1], "Glow" }, pos, (nrm + smp.T * 1.2 + Vector3.new(0, 0.4, 0)).Unit, smp.T, { n = 2, len = 0.34 - q * 0.04, w0 = 0.07, w1 = 0.045, bend = 0 })
			end
		end

		-- head: long narrow snout, a crown of crystals, narrow magenta eyes under a dark brow
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.12, -0.28), Vector3.new(0.62, 0.46, 0.58))
		K:block("Head", "Hide", hcf(0, 0.04, -0.84), Vector3.new(0.44, 0.32, 0.66))
		K:block("Head", "Hide", hcf(0, 0.0, -1.28, -4, 0, 0), Vector3.new(0.34, 0.26, 0.32))
		K:block("Head", "Mouth", hcf(0, -0.11, -0.84), Vector3.new(0.38, 0.05, 0.92))
		for j, z in { -0.1, -0.4, -0.72, -1.02, -1.26 } do
			local w = ({ 0.5, 0.5, 0.3, 0.28, 0.24 })[j]
			local y = z > -0.55 and 0.36 or (z > -1.16 and 0.2 or 0.13)
			K:block("Head", "Back", hcf(0, y, z, -10, 0, 0), Vector3.new(w, 0.07, 0.3))
		end
		for _, x in { 1, -1 } do
			K:block("Head", "Hide", hcf(0.3 * x, -0.02, -0.26, 0, -10 * x, 6 * x), Vector3.new(0.2, 0.38, 0.5))
			K:block("Head", "HideDark", hcf(0.15 * x, 0.2, -0.86, -2, 0, -30 * x), Vector3.new(0.16, 0.08, 0.62))
			K:block("Head", "Back", hcf(0.21 * x, 0.36, -0.52, -8, -12 * x, 16 * x), Vector3.new(0.3, 0.13, 0.36))
			H.eye(K, "Head", hcf(0.3 * x, 0.24, -0.56, 0, -30 * x, 12 * x), 0.15, 0.045)
			H.teeth(K, "Head", "Tooth", hp(0.21 * x, -0.12, -0.42), hp(0.15 * x, -0.11, -1.36), 8, hv(0, -1, 0.12), hv(1, 0, 0), 0.075, 0.04)
			H.crystal(K, "Head", prism(x == 1 and 1 or 3), hp(0.22 * x, 0.36, -0.2), hv(0.4 * x, 0.75, 0.55), 0.44, 3, 22)
		end
		H.crystal(K, "Head", prism(2), hp(0, 0.38, -0.02), hv(0, 0.8, 0.6), 0.5, 3, 18)
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-14), 0, 0)
		local function jcf(px, py, pz) return JAW * CFrame.new(px, py, pz) end
		K:block("Jaw", "Hide", jcf(0, -0.1, -0.66), Vector3.new(0.42, 0.16, 1.22))
		K:block("Jaw", "Belly", jcf(0, -0.19, -0.6), Vector3.new(0.34, 0.05, 1.0))
		K:block("Jaw", "Mouth", jcf(0, 0.0, -0.68), Vector3.new(0.32, 0.04, 1.0))
		for _, x in { 1, -1 } do
			H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.17 * x, 0, -0.4), JAW * Vector3.new(0.13 * x, 0, -1.22), 6, JAW:VectorToWorldSpace(Vector3.new(0, 1, -0.1)).Unit, JAW:VectorToWorldSpace(Vector3.xAxis), 0.065, 0.04)
		end
	end,
}
