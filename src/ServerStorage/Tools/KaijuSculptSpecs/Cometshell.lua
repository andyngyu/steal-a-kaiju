local rad = math.rad
local H = require(script.Parent.Helpers)

-- Cosmic Rift / Rare / void: the cometshell, a tortoise carrying a comet. A heavy, low tortoise on four stumpy
-- pillar legs, its high domed shell a lump of cratered space rock in dark violet-grey, the front rim blazing with icy
-- white comet fire that streams back over the dome, a long glowing comet tail fanning up and away behind it, star
-- specks in the rock. Head: a heavy armoured tortoise head on a thick neck, a hooked dark beak, glowing magenta eyes
-- under a rocky brow.
local HEAD = CFrame.new(0, 1.34, -1.72) * CFrame.Angles(rad(-6), 0, 0)

return {
	Seed = 721,
	Vary = 0.05,
	Scale = 1.0,
	Gait = "Amble",
	Emotes = { "Look", "Wiggle" },
	Palette = {
		Hide = { "3A3448", Material = "Slate" },
		HideDark = { "221E2C", Material = "Slate" },
		HideLight = { "5A5068", Material = "Slate" },
		Back = { "18141F", Material = "Slate" },
		Belly = { "4A4058", Material = "Slate" },
		Belly2 = { "3E3550", Material = "Slate" },
		Rock = { "463E58", Material = "Basalt" },
		RockDark = { "2A2436", Material = "Basalt" },
		RockLight = { "6A6080", Material = "Basalt" },
		Crater = { "16121C", Material = "Basalt" },
		Blaze = { "6CCBFF", Neon = true },
		BlazeHot = { "E8F8FF", Neon = true },
		Comet = { "5AB4FF", Neon = true, Transparency = 0.15 },
		CometFade = { "9A7AFF", Neon = true, Transparency = 0.35 },
		Star = { "FFF4FF", Neon = true },
		Beak = "1A1620",
		Tooth = "D8D0E0",
		Mouth = "3A1438",
		Eye = { "FF40E0", Neon = true },
		Socket = "07050C",
		Claw = "141018",
		ClawTip = "8A82A0",
	},
	Joints = {
		Head = { 0, 1.2, -1.26 },
		LegFL = { 0.92, 1.02, -0.74 },
		LegFR = { -0.92, 1.02, -0.74 },
		LegBL = { 0.9, 1.0, 0.86 },
		LegBR = { -0.9, 1.0, 0.86 },
		Tail = { 0, 2.2, 1.2 },
	},
	Build = function(K)
		-- the shell: a high dome of cratered rock over a flat rim
		local function rock(th, ring)
			local a = math.deg(math.abs(th))
			if a > 118 then
				return nil
			end
			return (ring + math.floor(a / 30)) % 3 == 0 and "RockLight" or ((ring + math.floor(a / 30)) % 3 == 1 and "Rock" or "RockDark")
		end
		local shell = K:tube("Body", {
			{ 0, 1.4, -1.06, rx = 0.92, ru = 0.62, rd = 0.32 },
			{ 0, 1.5, -0.42, rx = 1.32, ru = 1.04, rd = 0.42 },
			{ 0, 1.5, 0.36, rx = 1.36, ru = 1.08, rd = 0.42 },
			{ 0, 1.42, 1.0, rx = 1.08, ru = 0.78, rd = 0.36 },
			{ 0, 1.34, 1.3, rx = 0.66, ru = 0.42, rd = 0.3 },
		}, { step = 0.3, core = "RockDark", coreScale = 0.72, tile = { w = 0.46, t = 0.18, lift = 2, jitter = 4, sink = 0.45, overlap = 1.12 }, color = rock })
		-- the rim of the shell, a lip of dark rock all round, and the belly plate under it
		for i = 0, 17 do
			local a = i / 18 * math.pi * 2
			local p = Vector3.new(math.sin(a) * 1.34, 1.08, math.cos(a) * 1.36 + 0.12)
			K:block("Body", i % 2 == 0 and "RockDark" or "Rock", CFrame.new(p) * CFrame.Angles(0, a, 0), Vector3.new(0.52, 0.2, 0.4))
		end
		K:block("Body", "Belly", CFrame.new(0, 1.0, 0.12), Vector3.new(2.2, 0.18, 2.3))
		-- craters pocking the dome: a dark pit in a raised ring, a few with glowing star specks
		for i, o in { { 0.6, 30, 0.42 }, { 1.2, -24, 0.36 }, { 1.8, 46, 0.3 }, { 0.9, -62, 0.32 }, { 2.1, -10, 0.28 }, { 1.5, 70, 0.26 }, { 0.3, -40, 0.24 } } do
			local smp = K:at(shell, o[1])
			local pos, nrm = K:surface(smp, rad(o[2]), 0.06)
			local F = CFrame.fromMatrix(pos, nrm:Cross(smp.T).Unit, nrm)
			local s = o[3]
			for k = 0, 5 do
				local a = k / 6 * math.pi * 2
				K:block("Body", "RockLight", F * CFrame.new(math.cos(a) * s * 0.5, 0.02, math.sin(a) * s * 0.5) * CFrame.Angles(0, -a, 0), Vector3.new(s * 0.3, 0.1, s * 0.5))
			end
			K:block("Body", "Crater", F * CFrame.new(0, 0.01, 0), Vector3.new(s * 0.62, 0.08, s * 0.62))
			if i % 2 == 1 then
				K:block("Body", "Star", F * CFrame.new(0, 0.05, 0) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.09, 0.09, 0.09))
			end
		end
		-- the comet head: the front rim of the dome blazing with icy fire that streams back over the top
		for i = -3, 3 do
			local smp = K:at(shell, 0.3)
			local pos, nrm = K:surface(smp, rad(i * 22), 0.02)
			local back = (smp.T + nrm * 0.35).Unit
			K:chain("Body", { "BlazeHot", "Blaze", "Comet" }, pos, (nrm * 0.5 + back).Unit, smp.R, { n = 3, len = 1.3 - math.abs(i) * 0.14, w0 = 0.36, w1 = 0.12, bend = -14, depth = 0.8 })
		end
		for i = -2, 2 do
			local smp = K:at(shell, 0.12)
			local pos = K:surface(smp, rad(i * 26), -0.04)
			K:block("Body", i % 2 == 0 and "BlazeHot" or "Blaze", CFrame.new(pos) * CFrame.Angles(rad(45), rad(K:rand(0, 90)), 0), Vector3.new(0.3, 0.3, 0.3))
		end
		-- the comet tail: long glowing streamers fanning up and away behind the shell
		local root = Vector3.new(0, 2.2, 1.1)
		for i = -3, 3 do
			local d = CFrame.Angles(0, rad(i * 9), 0):VectorToWorldSpace(Vector3.new(0, 0.55 - math.abs(i) * 0.06, 1).Unit)
			local len = 3.4 - math.abs(i) * 0.36
			K:chain("Tail", { "BlazeHot", "Blaze", "Comet", "Comet", "CometFade" }, root + Vector3.new(i * 0.16, 0, 0), d, Vector3.yAxis:Cross(d).Unit, { n = 5, len = len, w0 = 0.52 - math.abs(i) * 0.05, w1 = 0.14, bend = 4, depth = 0.7 })
		end
		for i = 1, 8 do
			local p = root + Vector3.new(K:rand(-0.6, 0.6), K:rand(0.4, 1.4), K:rand(0.8, 2.6))
			K:block("Tail", "Star", CFrame.new(p) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.09, 0.09, 0.09))
		end

		-- stumpy pillar legs with scaly plates and blunt claws
		local function legSkin(_, ring)
			return ring % 2 == 0 and "Hide" or "HideLight"
		end
		for _, x in { 1, -1 } do
			for _, leg in { { x == 1 and "LegFL" or "LegFR", -0.74 }, { x == 1 and "LegBL" or "LegBR", 0.86 } } do
				local g, z = leg[1], leg[2]
				H.quadLeg(K, g, {
					{ 0.92 * x, 1.06, z, 0.34 },
					{ 1.1 * x, 0.62, z - 0.06, 0.3 },
					{ 1.08 * x, 0.26, z - 0.1, 0.27 },
				}, { step = 0.22, cores = { "Hide", "HideDark" }, tiles = { H.plates(0.24, 6, 0.08), H.plates(0.22, 6, 0.08) }, color = legSkin, foot = { size = Vector3.new(0.6, 0.22, 0.62), key = "HideDark" }, toes = 4, claw = { len = 0.16, w = 0.09, curl = 20 } })
			end
		end
		-- a stubby tail under the comet
		K:chain("Body", { "Hide", "HideDark" }, Vector3.new(0, 1.08, 1.4), Vector3.new(0, -0.3, 1).Unit, Vector3.xAxis, { n = 2, len = 0.4, w0 = 0.22, w1 = 0.12, bend = 0 })

		-- head: a thick scaly neck, a heavy armoured head, a hooked beak, a rocky brow
		local neck = K:tube("Head", {
			{ 0, 1.36, -1.68, rx = 0.3, ru = 0.3, rd = 0.32 },
			{ 0, 1.26, -1.42, rx = 0.36, ru = 0.36, rd = 0.38 },
			{ 0, 1.16, -1.06, rx = 0.44, ru = 0.42, rd = 0.44 },
		}, { step = 0.18, core = "Hide", coreScale = 0.92, tile = H.plates(0.24, nil, 0.08), color = H.skin({ stripe = 30, band = 80, flank = 110, every = 2 }) })
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:scaled(HEAD.Position, 1.3, function()
		K:block("Head", "Hide", hcf(0, 0.06, -0.22), Vector3.new(0.62, 0.5, 0.56))
		K:block("Head", "Hide", hcf(0, 0.04, -0.22, 0, 0, 45), Vector3.new(0.48, 0.48, 0.52))
		K:block("Head", "RockDark", hcf(0, 0.32, -0.26, -8, 0, 0), Vector3.new(0.5, 0.12, 0.5))
		-- armour scutes over the skull
		for i, o in { { 0, 0.34, -0.04, 0.3 }, { 0.16, 0.3, -0.36, 0.22 }, { -0.16, 0.3, -0.36, 0.22 } } do
			K:block("Head", i == 1 and "RockLight" or "Rock", hcf(o[1], o[2], o[3], -8, 0, 0), Vector3.new(o[4], 0.08, o[4]))
		end
		-- the hooked beak
		K:block("Head", "Beak", hcf(0, 0.0, -0.58, -6, 0, 0), Vector3.new(0.44, 0.34, 0.32))
		K:chain("Head", { "Beak", "Beak" }, hp(0, 0.04, -0.72), hv(0, -0.8, -0.6), hv(1, 0, 0), { n = 2, len = 0.3, w0 = 0.28, w1 = 0.12, bend = 30, depth = 1.2 })
		K:block("Head", "Mouth", hcf(0, -0.15, -0.46), Vector3.new(0.4, 0.04, 0.32))
		K:block("Head", "Beak", hcf(0, -0.22, -0.46, 8, 0, 0), Vector3.new(0.36, 0.12, 0.34))
		for _, x in { 1, -1 } do
			K:block("Head", "RockDark", hcf(0.2 * x, 0.28, -0.42, -8, -14 * x, 20 * x), Vector3.new(0.3, 0.12, 0.26))
			H.eye(K, "Head", hcf(0.26 * x, 0.15, -0.44, 0, -44 * x, 10 * x), 0.17, 0.06)
		end
		end)
	end,
}
