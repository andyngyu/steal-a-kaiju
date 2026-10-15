local rad = math.rad
local H = require(script.Parent.Helpers)

-- Storm Spires / Rare / storm: the thunderram, an armoured ram-beast. A massive charcoal body on thick legs with cloven
-- hooves, its fleece a thundercloud: dark heaped storm puffs, lighter on top, yellow-white lightning glimmering deep in
-- the folds and forking down its flanks. Iron plates over the shoulders and an iron boss on the forehead. The head is
-- lowered to charge: a long Roman-nosed muzzle, a storm-wool beard, horizontal yellow goat eyes under a heavy brow,
-- and two giant curled copper horns wound with dark coil bands like tesla coils, electric blue arcing between the tips.
local HEAD = CFrame.new(0, 2.16, -1.66) * CFrame.Angles(rad(-14), 0, 0)
local HINGE = Vector3.new(0, -0.22, -0.3)
local HS = 1.15

local function hj(v)
	return HEAD.Position + (HEAD * v - HEAD.Position) * HS
end

return {
	Seed = 621,
	Vary = 0.05,
	Scale = 1.0,
	Gait = "Trot",
	Emotes = { "Look", "Paw", "PlayBow" },
	Palette = {
		Hide = { "3A3E46", Material = "Slate" },
		HideDark = { "24272E", Material = "Slate" },
		HideLight = { "5A606C", Material = "Slate" },
		Back = { "1C1E24", Material = "Slate" },
		Belly = "6A707C",
		Belly2 = "5A606C",
		Wool = "4A505E",
		WoolDark = "30353F",
		WoolLight = "707888",
		WoolDeep = "1E2128",
		Armour = { "4A4E58", Material = "Slate" },
		ArmourLight = { "6A707C", Material = "Slate" },
		Copper = "C27A3A",
		CopperDark = "8A5226",
		CopperLight = "E4A464",
		Coil = "4E2E16",
		Spark = { "FFE680", Neon = true },
		Arc = { "4AC8FF", Neon = true },
		Hoof = "1A1A1E",
		Nose = "141418",
		Mouth = "3A1A2A",
		Tooth = "E8E4D8",
		Eye = { "FFD84A", Neon = true },
		Socket = "0A0C10",
		Claw = "1A1A1E",
		ClawTip = "3A3A40",
	},
	Joints = {
		Head = { 0, 2.04, -1.0 },
		Jaw = hj(HINGE),
		EarL = hj(Vector3.new(0.38, 0.08, -0.12)),
		EarR = hj(Vector3.new(-0.38, 0.08, -0.12)),
		LegFL = { 0.52, 1.86, -0.86 },
		LegFR = { -0.52, 1.86, -0.86 },
		LegBL = { 0.5, 1.84, 0.86 },
		LegBR = { -0.5, 1.84, 0.86 },
		Tail = { 0, 2.0, 1.32 },
	},
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 30, band = 70, flank = 106, every = 3, upper = "HideDark" })
		local belly = { key = "Belly", key2 = "Belly2", arc = 40, t = 0.1, wide = 1.1 }
		local body = K:tube("Body", {
			{ 0, 2.0, -0.92, rx = 0.78, ru = 0.8, rd = 0.76 },
			{ 0, 2.06, -0.3, rx = 0.86, ru = 0.86, rd = 0.82 },
			{ 0, 1.96, 0.42, rx = 0.78, ru = 0.74, rd = 0.72 },
			{ 0, 1.9, 1.02, rx = 0.66, ru = 0.62, rd = 0.6 },
		}, { step = 0.3, core = "HideDark", coreScale = 0.9, tile = H.plates(0.42, nil, 0.12), belly = belly, color = skin })
		local neck = K:tube("Head", {
			{ 0, 2.14, -1.6, rx = 0.42, ru = 0.42, rd = 0.46 },
			{ 0, 2.14, -1.3, rx = 0.54, ru = 0.54, rd = 0.56 },
			{ 0, 2.04, -0.96, rx = 0.66, ru = 0.68, rd = 0.66 },
		}, { step = 0.24, core = "HideDark", coreScale = 0.9, tile = H.plates(0.36, nil, 0.11), belly = belly, color = skin })

		-- the thundercloud fleece: heaped storm puffs, lighter on top, lightning glimmering in the folds
		local function fleece(g, smps, from, to, every, thetas, size)
			local k = 0
			for s = from, to, every do
				local smp = K:at(smps, s + K:rand(-0.04, 0.04))
				for _, t0 in thetas do
					local th = rad(t0 + K:rand(-8, 8))
					local pos, nrm = K:surface(smp, th, -0.14)
					local a = math.abs(t0)
					local key = a < 30 and (k % 2 == 0 and "WoolLight" or "Wool") or (a < 62 and (k % 3 == 0 and "WoolLight" or "Wool") or (k % 2 == 0 and "WoolDark" or "Wool"))
					local sz = size * K:rand(0.8, 1.15) * (a > 70 and 0.85 or 1)
					K:block(g, key, CFrame.new(pos + nrm * sz * 0.12) * CFrame.Angles(rad(K:rand(-20, 20)), rad(K:rand(0, 90)), rad(K:rand(-20, 20))), Vector3.new(sz, sz * 0.78, sz))
					if k % 4 == 2 then
						-- lightning flickering out between the puffs
						local p2 = K:surface(smp, th + rad(16), -0.3)
						local side = nrm:Cross(smp.T).Unit
						H.bolt(K, g, "Spark", p2 - smp.T * 0.26 + side * 0.1, p2 + smp.T * 0.26 - side * 0.1, side, 4, 0.07, 0.08)
					end
					k += 1
				end
			end
		end
		fleece("Body", body, 0.12, body.total - 0.06, 0.26, { -84, -60, -34, -10, 14, 38, 62, 86 }, 0.56)
		fleece("Head", neck, 0.34, neck.total - 0.02, 0.22, { -70, -40, -12, 16, 44, 72 }, 0.44)
		-- the deep dark underside of the cloud along the flanks, bolts forking down out of it
		for _, x in { 1, -1 } do
			for s = 0.3, body.total - 0.3, 0.5 do
				local smp = K:at(body, s)
				local pos, nrm = K:surface(smp, rad(96) * x, -0.1)
				K:block("Body", "WoolDeep", CFrame.new(pos) * CFrame.Angles(0, rad(K:rand(0, 90)), 0), Vector3.new(0.4, 0.24, 0.4))
			end
			for _, s in { 0.5, 1.3 } do
				local smp = K:at(body, s)
				local pos = K:surface(smp, rad(100) * x, 0.02)
				H.bolt(K, "Body", "Spark", pos, pos + Vector3.new(0.12 * x, -0.62, 0.08), smp.T, 4, 0.05, 0.08)
			end
			-- iron plates over the shoulders, under the fleece edge
			for i, o in { { 0.1, 74, 0.6 }, { 0.36, 82, 0.52 } } do
				K:tile("Body", i == 1 and "Armour" or "ArmourLight", K:at(body, o[1]), rad(o[2]) * x, o[3], o[3] * 0.9, 0.14, 10, 2, -0.2)
			end
		end
		-- a short storm-wool tail
		H.cloud(K, "Tail", { "Wool", "WoolLight", "WoolDark" }, Vector3.new(0, 2.06, 1.46), Vector3.new(0.2, 0.18, 0.2), 6, "Spark", 1)

		-- thick legs on cloven hooves, storm-wool cuffs at the top
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.52 * x, 1.86, -0.86, 0.36 },
				{ 0.56 * x, 1.04, -0.84, 0.26 },
				{ 0.54 * x, 0.32, -0.92, 0.2 },
			}, { step = 0.26, cores = { "Hide", "HideDark" }, tiles = { H.plates(0.3, 5, 0.1), nil }, color = skin, foot = { size = Vector3.new(0.38, 0.28, 0.42), key = "Hoof" }, toes = 2, claw = { len = 0.1, w = 0.16, curl = 0 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.5 * x, 1.84, 0.86, 0.4 },
				{ 0.54 * x, 1.24, 0.62, 0.3 },
				{ 0.54 * x, 0.66, 1.0, 0.2 },
				{ 0.54 * x, 0.28, 0.9, 0.18 },
			}, { step = 0.26, cores = { "Hide", "HideDark", "HideDark" }, tiles = { H.plates(0.32, 5, 0.1), nil, nil }, color = skin, foot = { size = Vector3.new(0.38, 0.28, 0.42), key = "Hoof" }, toes = 2, claw = { len = 0.1, w = 0.16, curl = 0 } })
			-- iron shin guards on the forelegs
			K:block(x == 1 and "LegFL" or "LegFR", "Armour", CFrame.new(0.55 * x, 0.72, -1.06) * CFrame.Angles(rad(-4), 0, 0), Vector3.new(0.34, 0.6, 0.1))
			for _, leg in { { x == 1 and "LegFL" or "LegFR", Vector3.new(0.54 * x, 1.6, -0.86) }, { x == 1 and "LegBL" or "LegBR", Vector3.new(0.52 * x, 1.56, 0.8) } } do
				H.cloud(K, leg[1], { "Wool", "WoolDark", "WoolLight" }, leg[2], Vector3.new(0.26, 0.16, 0.26), 5)
			end
		end

		-- head: lowered to charge
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
			K:block("Head", "Hide", hcf(0, 0.12, -0.28), Vector3.new(0.74, 0.62, 0.62))
			-- the iron boss on the forehead
			K:block("Head", "Armour", hcf(0, 0.4, -0.38, -10, 0, 0), Vector3.new(0.64, 0.22, 0.56))
			K:block("Head", "ArmourLight", hcf(0, 0.32, -0.66, -38, 0, 0), Vector3.new(0.5, 0.16, 0.3))
			-- a long Roman-nosed muzzle
			K:block("Head", "Hide", hcf(0, 0.0, -0.86, -6, 0, 0), Vector3.new(0.5, 0.46, 0.58))
			K:block("Head", "HideLight", hcf(0, 0.22, -0.88, -12, 0, 0), Vector3.new(0.3, 0.12, 0.58))
			K:block("Head", "Nose", hcf(0, -0.04, -1.18, -8, 0, 0), Vector3.new(0.44, 0.38, 0.14))
			K:block("Head", "Mouth", hcf(0, -0.2, -0.9), Vector3.new(0.4, 0.04, 0.54))
			for _, x in { 1, -1 } do
				K:block("Head", "Socket", hcf(0.11 * x, 0.02, -1.25, -8, 0, 0), Vector3.new(0.08, 0.12, 0.04))
				K:block("Head", "HideDark", hcf(0.3 * x, 0.36, -0.5, -6, -14 * x, 20 * x), Vector3.new(0.26, 0.12, 0.3))
				H.eye(K, "Head", hcf(0.37 * x, 0.22, -0.5, 0, -44 * x, 0), 0.17, 0.05)
				K:block("Head", "Hide", hcf(0.36 * x, 0.0, -0.3, 0, -8 * x, 0), Vector3.new(0.14, 0.4, 0.5))
				-- the giant curled copper horn: back, down and round past the cheek, tip forward and out
				local pts = {}
				for i = 0, 12 do
					local f = i / 12
					local th = -0.12 * math.pi + f * math.pi * 1.74
					local r = 0.44 - 0.22 * f
					pts[i + 1] = hp((0.3 + 0.5 * f) * x, 0.06 + r * math.cos(th), -0.02 + r * math.sin(th))
				end
				local nodes = {}
				for i, p in pts do
					local r = 0.24 - 0.18 * (i - 1) / (#pts - 1)
					nodes[i] = { p.X, p.Y, p.Z, rx = r, ru = r, rd = r }
				end
				K:tube("Head", nodes, { step = 0.1, core = "Copper", coreScale = 1.0 })
				local last = pts[#pts]
				H.point(K, "Head", "CopperLight", last + (last - pts[#pts - 1]).Unit * 0.12, last - pts[#pts - 1], 0.12)
				-- dark coil bands wound round it
				local smps = K:path(nodes, 0.06)
				for s = 0.14, smps.total * 0.84, 0.15 do
					local smp = K:at(smps, s)
					local w = (0.24 - 0.18 * (s / smps.total)) * 2
					K:block("Head", "Coil", CFrame.lookAt(smp.p, smp.p + smp.T), Vector3.new(w * 0.92, w * 0.92, 0.05))
					K:block("Head", "Coil", CFrame.lookAt(smp.p, smp.p + smp.T) * CFrame.Angles(0, 0, rad(45)), Vector3.new(w * 0.92, w * 0.92, 0.05))
				end
				local tip = pts[#pts]
				K:block("Head", "Arc", CFrame.new(tip), Vector3.new(0.12, 0.12, 0.12))
				-- a storm-wool beard and a wool cap between the horns
				K:chain("Head", { "Wool", "WoolDark", "WoolDark" }, hp(0.08 * x, -0.24, -0.7), hv(0.1 * x, -1, 0.3), hv(1, 0, 0), { n = 3, len = 0.4, w0 = 0.16, w1 = 0.1, bend = 0 })
				local g = x == 1 and "EarL" or "EarR"
				K:chain(g, { "HideDark", "Hide" }, hp(0.38 * x, 0.08, -0.12), hv(0.9 * x, -0.35, 0.25), hv(0, 1, 0), { n = 2, len = 0.32, w0 = 0.16, w1 = 0.1, bend = 0, depth = 0.5 })
			end
			H.cloud(K, "Head", { "WoolLight", "Wool" }, hp(0, 0.6, -0.12), Vector3.new(0.2, 0.1, 0.18), 4)
			-- electric blue arcing between the horn tips, across the brow
			local function tipOf(x)
				local th = math.pi * 1.62
				local r = 0.22
				return hp(0.8 * x, 0.06 + r * math.cos(th), -0.02 + r * math.sin(th))
			end
			H.bolt(K, "Head", "Arc", tipOf(1), tipOf(-1), hv(0, 1, 0), 6, 0.045, 0.1)
			for _, x in { 1, -1 } do
				H.bolt(K, "Head", "Spark", tipOf(x), hp(0.2 * x, 0.46, -0.5), hv(0, 0, 1), 3, 0.035, 0.06)
			end
			-- the lower jaw
			local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-10), 0, 0)
			K:block("Jaw", "Hide", JAW * CFrame.new(0, -0.08, -0.4), Vector3.new(0.42, 0.16, 0.64))
			K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.42), Vector3.new(0.34, 0.04, 0.56))
			for _, x in { 1, -1 } do
				H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.14 * x, 0, -0.5), JAW * Vector3.new(0.12 * x, 0, -0.68), 2, JAW:VectorToWorldSpace(Vector3.yAxis), JAW:VectorToWorldSpace(Vector3.xAxis), 0.06, 0.05)
			end
			for _, x in { -1, 0, 1 } do
				K:chain("Jaw", { "WoolDark", "Wool", "WoolLight" }, JAW * Vector3.new(x * 0.1, -0.12, -0.5), JAW:VectorToWorldSpace(Vector3.new(x * 0.15, -1, 0.35)).Unit, JAW:VectorToWorldSpace(Vector3.xAxis), { n = 3, len = 0.42, w0 = 0.15, w1 = 0.09, bend = 0 })
			end
		end)
	end,
}
