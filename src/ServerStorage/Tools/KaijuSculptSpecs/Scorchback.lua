local rad = math.rad
local H = require(script.Parent.Helpers)

-- Lava Lagoon / Rare / fire: a volcanic ankylosaur, a walking lava field. A wide dome of basalt armour plates with
-- magma glowing in every seam, rows of flank spikes, a beaked horned head with ember eyes, stout pillar legs and a
-- massive basalt tail club split by molten cracks.
local HEAD = CFrame.new(0, 1.32, -1.32) * CFrame.Angles(rad(-6), 0, 0)

return {
	Seed = 83,
	Vary = 0.03,
	Gait = "Crawl",
	Emotes = { "Look", "TailSwing" },
	Palette = {
		Hide = { "2E2725", Material = "Basalt" },
		HideDark = { "1E1918", Material = "Basalt" },
		HideLight = { "4A3B34", Material = "Basalt" },
		Back = { "161212", Material = "Basalt" },
		Belly = { "5A2C1C", Material = "Basalt" },
		Belly2 = { "44210F", Material = "Basalt" },
		Magma = { "E2470F", Neon = true },
		MagmaHot = { "FF7A1A", Neon = true },
		Armour = { "35302E", Material = "Basalt" },
		ArmourLight = { "554A42", Material = "Basalt" },
		Tooth = "E2D2B4",
		Mouth = { "C8380C", Neon = true },
		Eye = { "FFAA22", Neon = true },
		Socket = "0C0909",
		Claw = "151214",
		ClawTip = "6A5A50",
		Spike = { "7C7066", Material = "Basalt" },
	},
	Joints = {
		Head = { 0, 1.42, -0.98 },
		LegFL = { 0.82, 1.24, -0.62 },
		LegFR = { -0.82, 1.24, -0.62 },
		LegBL = { 0.82, 1.24, 1.12 },
		LegBR = { -0.82, 1.24, 1.12 },
		Tail = { 0, 1.46, 1.42 },
	},
	Build = function(K)
		local function shell(th, ring)
			local a = math.deg(math.abs(th))
			if a < 34 then
				return "Back"
			elseif a < 92 then
				return ring % 2 == 0 and "HideDark" or "Hide"
			end
			return "HideLight"
		end
		local crust = { w = 0.86, l = 0.44, t = 0.18, lift = 4, jitter = 1, sink = 0.5, overlap = 0.9 }
		local body = K:tube("Body", {
			{ 0, 1.42, -0.92, rx = 0.92, ru = 0.66, rd = 0.5 },
			{ 0, 1.64, -0.2, rx = 1.26, ru = 0.86, rd = 0.6 },
			{ 0, 1.64, 0.62, rx = 1.26, ru = 0.86, rd = 0.6 },
			{ 0, 1.48, 1.34, rx = 1.0, ru = 0.7, rd = 0.54 },
		}, { step = 0.46, core = "Magma", coreCap = "HideDark", coreScale = 0.55, tile = crust, belly = { key = "Belly", key2 = "Belly2", arc = 58, t = 0.14, wide = 1.05 }, color = shell })
		local tail = K:tube("Tail", {
			{ 0, 1.46, 1.3, rx = 0.62, ru = 0.5, rd = 0.42 },
			{ 0.06, 1.3, 2.0, rx = 0.42, ru = 0.36, rd = 0.32 },
			{ 0.24, 1.1, 2.6, rx = 0.26, ru = 0.24, rd = 0.22 },
			{ 0.48, 0.98, 3.0, rx = 0.2, ru = 0.2, rd = 0.18 },
		}, { step = 0.4, core = "Magma", coreCap = "HideDark", coreScale = 0.55, tile = { w = 0.5, n = 5, l = 0.36, t = 0.14, lift = 5, jitter = 2.5, sink = 0.5, overlap = 0.86 }, belly = { key = "Belly", key2 = "Belly2", arc = 50, t = 0.12, wide = 1.05 }, color = shell })
		-- armour: a central row of plates with molten tips, studs, and long spikes jutting from the flanks
		K:ridge("Body", body, { style = "plate", keys = { "Armour", "ArmourLight", "MagmaHot" }, from = 0.3, to = body.total - 0.3, every = 0.44, height = function(u) return 0.36 + 0.1 * math.sin(u * math.pi) end, thick = 0.18, lean = 10 })
		H.studs(K, "Body", body, { rad(38), rad(-38) }, 0.44, 0.3, 0.3, body.total - 0.3, { "Armour", "ArmourLight" })
		for s = 0.2, body.total - 0.1, 0.4 do
			local smp = K:at(body, s)
			for _, x in { 1, -1 } do
				local pos, nrm = K:surface(smp, rad(84) * x, 0.06)
				local big = math.abs(s - body.total * 0.3) < 0.3
				K:chain("Body", { "Spike", "Spike", "MagmaHot" }, pos, (nrm + smp.T * 0.45 + smp.U * 0.45).Unit, smp.T, { n = 3, len = big and 1.0 or 0.72, w0 = 0.17, w1 = 0.09, bend = 0, tipH = 0.12 })
			end
		end
		for s = 0.2, tail.total - 0.2, 0.4 do
			local smp = K:at(tail, s)
			for _, x in { 1, -1 } do
				local pos, nrm = K:surface(smp, rad(80) * x, 0.04)
				K:chain("Tail", { "Spike", "MagmaHot" }, pos, (nrm + smp.T * 0.4).Unit, smp.T, { n = 2, len = 0.46 * (1 - s / tail.total) + 0.2, w0 = 0.13, w1 = 0.08, bend = 0, tipH = 0.1 })
			end
		end
		-- the club: basalt lobes split by molten cracks, studded with knobs
		local tip = K:at(tail, tail.total)
		local club = CFrame.lookAt(tip.p + tip.T * 0.4, tip.p + tip.T * 2)
		K:block("Tail", "Magma", club, Vector3.new(1.2, 0.8, 0.9))
		K:block("Tail", "Armour", club * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, rad(8)), Vector3.new(1.0, 0.7, 1.08))
		for _, x in { 1, -1 } do
			K:block("Tail", x == 1 and "ArmourLight" or "Armour", club * CFrame.new(0.62 * x, -0.04, 0.06) * CFrame.Angles(rad(K:rand(-8, 8)), rad(18 * x), rad(-10 * x)), Vector3.new(0.72, 0.68, 0.86))
			H.point(K, "Tail", "Spike", club * Vector3.new(1.08 * x, 0.02, 0.0), club:VectorToWorldSpace(Vector3.new(x, 0.15, 0)), 0.3)
		end
		H.point(K, "Tail", "Spike", club * Vector3.new(0, 0.56, 0.1), club:VectorToWorldSpace(Vector3.new(0, 1, 0.2)), 0.28)
		-- stout pillar legs with blunt claws
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.82 * x, 1.24, -0.62, 0.42 },
				{ 1.02 * x, 0.72, -0.72, 0.36 },
				{ 1.02 * x, 0.26, -0.7, 0.32 },
			}, { step = 0.3, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.6, 0.22, 0.58), key = "HideDark" }, yaw = 10, claw = { len = 0.18, w = 0.1, curl = 20 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.82 * x, 1.24, 1.12, 0.48 },
				{ 1.06 * x, 0.74, 1.0, 0.4 },
				{ 1.04 * x, 0.26, 1.12, 0.34 },
			}, { step = 0.3, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.64, 0.22, 0.62), key = "HideDark" }, yaw = 12, claw = { len = 0.18, w = 0.1, curl = 20 } })
			H.cracks(K, x == 1 and "LegBL" or "LegBR", "Magma", K:path({ { 0.82 * x, 1.24, 1.12 }, { 1.06 * x, 0.74, 1.0 } }, 0.2, Vector3.xAxis), {}, 0, 0)
		end

		-- head: low and wide, a hooked beak, two pairs of horns off the back of the skull, a heavy brow
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.08, -0.26), Vector3.new(0.9, 0.48, 0.62))
		K:block("Head", "Hide", hcf(0, -0.02, -0.72), Vector3.new(0.64, 0.38, 0.44))
		K:block("Head", "Armour", hcf(0, -0.06, -1.0, 8, 0, 0), Vector3.new(0.48, 0.32, 0.22))
		K:block("Head", "Mouth", hcf(0, -0.2, -0.8), Vector3.new(0.5, 0.05, 0.36))
		K:block("Head", "Armour", hcf(0, 0.34, -0.3, -8, 0, 0), Vector3.new(0.7, 0.12, 0.5))
		K:block("Head", "ArmourLight", hcf(0, 0.22, -0.7, -12, 0, 0), Vector3.new(0.46, 0.1, 0.36))
		for _, x in { 1, -1 } do
			K:block("Head", "Armour", hcf(0.26 * x, 0.32, -0.56, -8, -12 * x, 16 * x), Vector3.new(0.34, 0.14, 0.34))
			H.eye(K, "Head", hcf(0.36 * x, 0.18, -0.58, 0, -32 * x, 12 * x), 0.15, 0.045)
			K:chain("Head", { "Spike", "Spike", "MagmaHot" }, hp(0.42 * x, 0.24, -0.04), hv(0.65 * x, 0.2, 0.7), hv(0, 1, 0), { n = 3, len = 0.6, w0 = 0.18, w1 = 0.09, bend = -12 * x })
			K:chain("Head", { "Armour", "ArmourLight" }, hp(0.42 * x, -0.12, -0.16), hv(0.75 * x, -0.3, 0.5), hv(0, 1, 0), { n = 2, len = 0.4, w0 = 0.15, w1 = 0.09, bend = 0 })
			H.teeth(K, "Head", "Tooth", hp(0.24 * x, -0.2, -0.62), hp(0.18 * x, -0.2, -0.94), 3, hv(0, -1, 0), hv(1, 0, 0), 0.06, 0.04)
		end
	end,
}
