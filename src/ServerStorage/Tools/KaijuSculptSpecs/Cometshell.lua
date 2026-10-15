local rad = math.rad
local H = require(script.Parent.Helpers)

-- Cosmic Rift / Rare / void: the cometshell, a snapping turtle carrying a comet. A heavy, low turtle on four stumpy
-- pillar legs, its high domed shell a cratered meteor of violet-grey rock split by glowing icy-blue cracks, the front
-- rim blazing with icy comet fire that streams back over the dome, a long glowing comet tail fanning up and away
-- behind it. Head: a snapping turtle's, big and triangular on a thick knobbly neck, a sharp hooked beak, a heavy
-- brow ridge over glowing eyes, rough knobs over the skull and down the neck.
local HEAD = CFrame.new(0, 1.34, -1.72) * CFrame.Angles(rad(-6), 0, 0)

return {
	Seed = 721,
	Vary = 0.05,
	Scale = 1.0,
	Gait = "Amble",
	Emotes = { "Look", "Wiggle" },
	Palette = {
		Hide = { "5A5084", Material = "Slate" },
		HideDark = { "40386A", Material = "Slate" },
		HideLight = { "7A70A4", Material = "Slate" },
		Back = { "2A2448", Material = "Slate" },
		Belly = { "ACA0D4", Material = "Slate" },
		Belly2 = { "9A8EC4", Material = "Slate" },
		Rock = { "6A6088", Material = "Basalt" },
		RockDark = { "4E4670", Material = "Basalt" },
		RockLight = { "8C82AA", Material = "Basalt" },
		Crater = { "16121C", Material = "Basalt" },
		Ice = { "6CCBFF", Neon = true },
		SeamLip = { "1E1A30", Material = "Basalt" },
		Blaze = { "6CCBFF", Neon = true },
		BlazeHot = { "E8F8FF", Neon = true },
		Comet = { "5AB4FF", Neon = true, Transparency = 0.15 },
		CometFade = { "C4ECFF", Neon = true, Transparency = 0.4 },
		Star = { "FFF4FF", Neon = true },
		Beak = "2A2438",
		BeakEdge = "C8C0DC",
		Knob = { "7A70A4", Material = "Slate" },
		Tooth = "D8D0E0",
		Mouth = "3A1438",
		Eye = { "8ADCFF", Neon = true },
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
		-- glowing icy-blue cracks splitting the meteor, branching across the dome
		for _, th in { 30, -30, 70, -70, 100, -100 } do
			H.vein(K, "Body", "Ice", shell, rad(th), 0.7, shell.total - 0.2, { width = 0.14, height = 0.1, lift = 0.1, wander = 30, step = 0.24, forks = 2, forkSteps = 3, forkTurn = 50 })
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

		-- head: a snapping turtle's, on a thick knobbly neck
		local neck = K:tube("Head", {
			{ 0, 1.36, -1.68, rx = 0.34, ru = 0.32, rd = 0.34 },
			{ 0, 1.26, -1.42, rx = 0.4, ru = 0.38, rd = 0.4 },
			{ 0, 1.16, -1.06, rx = 0.46, ru = 0.44, rd = 0.46 },
		}, { step = 0.18, core = "Hide", coreScale = 0.92, tile = H.plates(0.24, nil, 0.08), belly = { key = "Belly", key2 = "Belly2", arc = 40, t = 0.08, wide = 1.05 }, color = H.skin({ stripe = 30, band = 80, flank = 110, every = 2 }) })
		for s = 0.08, neck.total - 0.06, 0.14 do
			local smp = K:at(neck, s)
			for _, th in { 0, rad(48), rad(-48) } do
				K:spike("Head", "Knob", K:surface(smp, th + rad(K:rand(-10, 10)), 0.02), (select(2, K:surface(smp, th, 0)) + smp.T * 0.3).Unit, smp.T, 0.12, 0.1)
			end
		end
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:scaled(HEAD.Position, 1.35, function()
			-- a big triangular skull, wide at the jaw hinge and narrowing to the beak
			K:block("Head", "Hide", hcf(0, 0.06, -0.16), Vector3.new(0.8, 0.5, 0.5))
			K:block("Head", "Hide", hcf(0, 0.06, -0.48), Vector3.new(0.6, 0.44, 0.34))
			K:block("Head", "HideLight", hcf(0, 0.28, -0.3, -10, 0, 0), Vector3.new(0.5, 0.1, 0.6))
			for _, x in { 1, -1 } do
				K:block("Head", "Hide", hcf(0.3 * x, 0.0, -0.26, 0, -24 * x, 0), Vector3.new(0.18, 0.42, 0.44))
			end
			-- the heavy brow ridge jutting over the eyes
			K:block("Head", "HideDark", hcf(0, 0.3, -0.56, -14, 0, 0), Vector3.new(0.56, 0.14, 0.2))
			for _, x in { 1, -1 } do
				K:block("Head", "HideDark", hcf(0.2 * x, 0.3, -0.46, -10, -18 * x, 22 * x), Vector3.new(0.32, 0.16, 0.34))
				H.eye(K, "Head", hcf(0.27 * x, 0.17, -0.66, 0, -30 * x, 10 * x), 0.2, 0.075)
			end
			-- the sharp hooked beak: the upper bill curving down past the lower into a point
			K:block("Head", "Beak", hcf(0, 0.02, -0.74, -10, 0, 0), Vector3.new(0.38, 0.32, 0.3))
			K:block("Head", "BeakEdge", hcf(0, -0.12, -0.74, -10, 0, 0), Vector3.new(0.36, 0.04, 0.28))
			K:chain("Head", { "Beak", "Beak", "BeakEdge" }, hp(0, 0.08, -0.86), hv(0, -0.75, -0.65), hv(1, 0, 0), { n = 3, len = 0.42, w0 = 0.26, w1 = 0.08, bend = 34, depth = 1.2 })
			K:block("Head", "Mouth", hcf(0, -0.16, -0.5), Vector3.new(0.5, 0.05, 0.42))
			K:block("Head", "Beak", hcf(0, -0.24, -0.56, 10, 0, 0), Vector3.new(0.4, 0.14, 0.44))
			K:block("Head", "BeakEdge", hcf(0, -0.18, -0.74, 10, 0, 0), Vector3.new(0.3, 0.04, 0.12))
			-- rough knobs over the skull
			for i, o in { { 0.0, 0.34, -0.06 }, { 0.2, 0.32, -0.12 }, { -0.2, 0.32, -0.12 }, { 0.12, 0.34, 0.08 }, { -0.12, 0.34, 0.08 }, { 0.36, 0.18, -0.1 }, { -0.36, 0.18, -0.1 } } do
				K:spike("Head", "Knob", hp(o[1], o[2], o[3]), hv(o[1] * 1.6, 1, 0.3), hv(0, 0, 1), 0.1, 0.08)
			end
		end)
	end,
}
