local rad = math.rad
local H = require(script.Parent.Helpers)

-- Cosmic Rift / Epic / void: the quasarab, a cosmic Hercules beetle. A broad armoured beetle on six thick spiked legs
-- tucked in under its shell (LegFL / LegML / LegBL and their right twins: KaijuMotion walks them in two tripods). Its
-- wing cases are deep blue, each swirled with a spiral galaxy, pale glowing arms winding out of a white-hot core and
-- white stars scattered over them. A great thoracic shield of deep blue chitin flecked with stars, and rising from it
-- the huge pale Hercules horn: thick at the root, arching high over the head and reaching far past it before hooking
-- down, toothed underneath with two side knobs, tipped with a star; a shorter horn curves up from the head to meet it.
-- Head: big glowing compound eyes, two crossed sickle mandibles with serrated inner edges, long elbowed antennae ending
-- in glowing clubs. Lavender underside.
local HEAD = CFrame.new(0, 1.18, -1.08) * CFrame.Angles(rad(-6), 0, 0)

return {
	Seed = 735,
	Vary = 0.03,
	Scale = 1.15,
	Gait = "Trot",
	Emotes = { "Look", "Wiggle" },
	Palette = {
		Shell = "263C96",
		ShellDark = "141E52",
		ShellLight = "3E58B8",
		Galaxy = { "5A8CFF", Neon = true },
		GalaxyLight = { "B8D4FF", Neon = true },
		GalaxyCore = { "F0F6FF", Neon = true },
		Star = { "FFFFFF", Neon = true },
		Chitin = { "2C2A6E", Material = "Slate" },
		ChitinLight = { "4A48A0", Material = "Slate" },
		Under = { "8A86C8", Material = "Slate" },
		Under2 = { "7A76B8", Material = "Slate" },
		Horn = "C8D4FF",
		HornShade = "A8B6EC",
		HornDark = "7A88C8",
		Mandible = "3A3880",
		MandibleTip = "D8DEFF",
		Tooth = "E8ECFF",
		Eye = { "6EB8FF", Neon = true },
		Socket = "07050C",
		Claw = "141018",
		ClawTip = "C8D0F0",
	},
	Joints = {
		Head = { 0, 1.2, -0.96 },
		LegFL = { 0.5, 1.0, -0.66 },
		LegFR = { -0.5, 1.0, -0.66 },
		LegML = { 0.56, 0.98, -0.3 },
		LegMR = { -0.56, 0.98, -0.3 },
		LegBL = { 0.56, 0.98, 0.06 },
		LegBR = { -0.56, 0.98, 0.06 },
		WingL = { 0.08, 1.92, -0.1 },
		WingR = { -0.08, 1.92, -0.1 },
	},
	Build = function(K)
		-- the abdomen under the wing cases: dark on top, lavender underneath
		local ABD = {
			{ 0, 1.36, -0.12, rx = 0.82, ru = 0.56, rd = 0.46 },
			{ 0, 1.44, 0.6, rx = 1.0, ru = 0.68, rd = 0.5 },
			{ 0, 1.38, 1.3, rx = 0.88, ru = 0.6, rd = 0.44 },
			{ 0, 1.22, 1.86, rx = 0.5, ru = 0.36, rd = 0.3 },
		}
		K:tube("Body", ABD, { step = 0.24, core = "ShellDark", coreScale = 0.9, tile = { w = 0.3, t = 0.08, lift = 3, jitter = 1, sink = 0.5, overlap = 1.1 }, color = function(th, ring)
			if math.abs(th) < rad(96) then
				return nil
			end
			return ring % 2 == 0 and "Under" or "Under2"
		end })
		-- the wing cases: a domed half-shell each side, a spiral galaxy swirling across it
		for _, x in { 1, -1 } do
			local nodes = {}
			for i, n in ABD do
				nodes[i] = { n[1], n[2] + 0.03, n[3], rx = n.rx + 0.09, ru = n.ru + 0.09, rd = n.rd }
			end
			local function galaxy(th, ring, smp)
				local a = th * x
				if a < 0 or a > rad(112) then
					return nil
				end
				if a < rad(7) or a > rad(104) then
					return "ShellDark"
				end
				local v = (a - rad(55)) * smp.rx
				local u = smp.p.Z - 0.78
				local r = math.sqrt(u * u + v * v)
				if r < 0.17 then
					return "GalaxyCore"
				end
				local s = math.sin(2 * math.atan2(v, u) * x - r * 5.2)
				if r < 0.95 and s > 0.5 then
					return r < 0.45 and "GalaxyLight" or "Galaxy"
				elseif r < 0.95 and s > -0.05 then
					return "ShellLight"
				end
				return "Shell"
			end
			local g = x == 1 and "WingL" or "WingR"
			local ely = K:tube(g, nodes, { step = 0.2, tile = { w = 0.26, t = 0.1, lift = 2, jitter = 0.5, sink = 0.5, overlap = 1.12 }, color = galaxy })
			-- white stars scattered over the case
			for i = 1, 14 do
				local smp = K:at(ely, K:rand(0.2, ely.total - 0.2))
				local pos = K:surface(smp, rad(K:rand(14, 98)) * x, -0.08)
				local s = i % 4 == 0 and 0.13 or 0.08
				K:block(g, "Star", CFrame.new(pos) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(s, s, s))
			end
		end

		-- the great thoracic shield, flecked with stars, and the huge horn rising from it
		local pron = K:tube("Body", {
			{ 0, 1.34, -1.0, rx = 0.6, ru = 0.46, rd = 0.38 },
			{ 0, 1.46, -0.56, rx = 0.86, ru = 0.64, rd = 0.46 },
			{ 0, 1.42, -0.1, rx = 0.84, ru = 0.6, rd = 0.44 },
		}, { step = 0.2, core = "ShellDark", coreScale = 0.9, tile = { w = 0.28, t = 0.1, lift = 3, jitter = 1, sink = 0.5, overlap = 1.12 }, color = function(th, ring)
			local a = math.abs(th)
			if a > rad(100) then
				return ring % 2 == 0 and "Under" or "Under2"
			end
			return a < rad(30) and "ShellLight" or (ring % 3 == 0 and "ShellDark" or "Shell")
		end })
		for i = 1, 8 do
			local smp = K:at(pron, K:rand(0.15, pron.total - 0.1))
			local pos = K:surface(smp, rad(K:rand(-90, 90)), -0.08)
			K:block("Body", "Star", CFrame.new(pos) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.08, 0.08, 0.08))
		end
		-- the Hercules horn: thick at the root, arching high over the head and far past it, hooking down at the tip
		local hornTube = K:tube("Body", {
			{ 0, 1.9, -0.36, rx = 0.34, ru = 0.36, rd = 0.32 },
			{ 0, 2.6, -1.0, rx = 0.28, ru = 0.3, rd = 0.27 },
			{ 0, 2.98, -1.76, rx = 0.22, ru = 0.24, rd = 0.21 },
			{ 0, 3.02, -2.5, rx = 0.16, ru = 0.17, rd = 0.15 },
			{ 0, 2.74, -3.08, rx = 0.1, ru = 0.1, rd = 0.1 },
		}, { step = 0.16, core = "HornDark", coreScale = 0.9, tile = { w = 0.2, t = 0.07, lift = 1, jitter = 0.3, sink = 0.5, overlap = 1.15 }, color = function(th, ring)
			if math.abs(th) > rad(125) then
				return "HornDark"
			end
			return ring % 4 == 0 and "HornShade" or "Horn"
		end })
		local tipS = K:at(hornTube, hornTube.total)
		local tipDir = (tipS.T + Vector3.new(0, -0.5, 0)).Unit
		H.point(K, "Body", "Horn", tipS.p + tipS.T * 0.06, tipDir, 0.18)
		K:block("Body", "Star", CFrame.new(tipS.p + tipDir * 0.1) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.17, 0.17, 0.17))
		-- teeth down its underside and a knob each side, so it reads from the front too
		for k, u in { 0.42, 0.56, 0.7, 0.82 } do
			local s = K:at(hornTube, hornTube.total * u)
			K:spike("Body", "Horn", K:surface(s, rad(180), 0.04), Vector3.new(0, -1, -0.25).Unit, Vector3.zAxis, 0.22 - k * 0.025, 0.1)
		end
		for _, x in { 1, -1 } do
			local s = K:at(hornTube, hornTube.total * 0.36)
			K:spike("Body", "Horn", K:surface(s, rad(95) * x, 0.04), Vector3.new(x, 0.15, -0.5).Unit, Vector3.yAxis, 0.24, 0.12)
		end
		-- stars flecked up the horn's back
		for i = 1, 5 do
			local s = K:at(hornTube, hornTube.total * (0.15 + i * 0.13))
			K:block("Body", "Star", CFrame.new(K:surface(s, rad(K:rand(-30, 30)), -0.05)) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.07, 0.07, 0.07))
		end

		-- six thick legs tucked in under the shell like a real beetle's: a short femur out to a knee just under the shell's
		-- rim, a stout spiked shin down to the ground; the front pair reaching forward, the middle out, the back pair back
		local function chit(_, ring)
			return ring % 2 == 0 and "Chitin" or "ChitinLight"
		end
		local LEGS = {
			{ "F", { 0.5, 1.0, -0.66 }, { 0.9, 1.0, -0.86 }, { 1.18, 0.12, -1.24 } },
			{ "M", { 0.56, 0.98, -0.3 }, { 1.0, 1.0, -0.28 }, { 1.34, 0.12, -0.16 } },
			{ "B", { 0.56, 0.98, 0.06 }, { 0.98, 0.98, 0.4 }, { 1.26, 0.12, 0.96 } },
		}
		for _, x in { 1, -1 } do
			for _, o in LEGS do
				local g = "Leg" .. o[1] .. (x == 1 and "L" or "R")
				local hip = Vector3.new(o[2][1] * x, o[2][2], o[2][3])
				local knee = Vector3.new(o[3][1] * x, o[3][2], o[3][3])
				local foot = Vector3.new(o[4][1] * x, o[4][2], o[4][3])
				H.limb(K, g, { { hip.X, hip.Y, hip.Z, 0.3 }, { knee.X, knee.Y, knee.Z, 0.26 }, { foot.X, foot.Y + 0.1, foot.Z, 0.15 } }, { step = 0.18, cores = { "Chitin", "ChitinLight" }, color = chit })
				K:block(g, "ChitinLight", CFrame.new(knee) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.38, 0.38, 0.38))
				-- two spikes on the outside of the shin
				local out = Vector3.new(x * 0.7, 0.25, o[1] == "F" and 0.5 or (o[1] == "B" and -0.1 or 0.3)).Unit
				for k = 1, 2 do
					local p = knee:Lerp(foot, k / 3)
					K:spike(g, "ClawTip", p + out * 0.16, out, (foot - knee).Unit, 0.16, 0.07)
				end
				-- the foot: a short stout tarsus tapering to a pale hooked tip
				local fwd = Vector3.new(0.35 * x, 0, o[1] == "B" and 0.6 or (o[1] == "F" and -0.8 or 0)).Unit
				K:chain(g, { "Chitin", "ChitinLight", "ClawTip" }, foot + Vector3.new(0, 0.05, 0), fwd, Vector3.yAxis, { n = 3, len = 0.17, w0 = 0.16, w1 = 0.08, bend = 8 })
			end
		end

		-- head: compound eyes, crossed sickle mandibles, elbowed antennae
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Shell", hcf(0, 0.04, -0.16), Vector3.new(0.72, 0.46, 0.5))
		K:block("Head", "ShellDark", hcf(0, 0.22, -0.2, -10, 0, 0), Vector3.new(0.54, 0.12, 0.46))
		K:block("Head", "Under", hcf(0, -0.16, -0.18), Vector3.new(0.56, 0.12, 0.44))
		K:block("Head", "Chitin", hcf(0, -0.04, -0.44), Vector3.new(0.4, 0.22, 0.12))
		for _, x in { 1, -1 } do
			-- big compound eyes bulging from the sides
			K:block("Head", "Socket", hcf(0.34 * x, 0.08, -0.22, 0, -20 * x, 0), Vector3.new(0.14, 0.3, 0.32))
			K:block("Head", "Eye", hcf(0.38 * x, 0.08, -0.24, 0, -20 * x, 0), Vector3.new(0.1, 0.24, 0.26))
			K:block("Head", "Eye", hcf(0.38 * x, 0.08, -0.24, 45, -20 * x, 0), Vector3.new(0.08, 0.2, 0.2))
			-- the sickle mandibles sweeping out and curving in to cross in front
			local pts = { hp(0.2 * x, -0.1, -0.38), hp(0.52 * x, -0.1, -0.78), hp(0.46 * x, -0.12, -1.14), hp(0.18 * x, -0.14, -1.38) }
			H.curve(K, "Head", { "Mandible", "Mandible", "Mandible", "MandibleTip" }, pts, 0.3, 0.08, 0.1)
			for k = 1, 4 do
				local f = 0.25 + k * 0.15
				local p = (k <= 2) and pts[2]:Lerp(pts[3], f) or pts[3]:Lerp(pts[4], f - 0.4)
				K:spike("Head", "Tooth", p, hv(-x, 0, -0.2), hv(0, 1, 0), 0.12, 0.05)
			end
			-- the shorter head horn curving up to meet the great horn (once, on the centre line)
			if x == 1 then
				H.curve(K, "Head", { "HornDark", "Horn", "Horn" }, { hp(0, 0.2, -0.36), hp(0, 0.26, -0.82), hp(0, 0.5, -1.22), hp(0, 0.86, -1.44) }, 0.3, 0.1, 0.14)
			end
			-- elbowed antennae with glowing clubs
			local a0 = hp(0.16 * x, 0.22, -0.42)
			local d1 = hv(0.45 * x, 0.65, -0.6)
			K:chain("Head", { "Chitin", "Chitin" }, a0, d1, hv(0, 0, 1), { n = 2, len = 0.6, w0 = 0.07, w1 = 0.06, bend = 0, tip = false })
			local a1 = a0 + d1 * 0.6
			local d2 = hv(0.5 * x, 0.35, -0.8)
			K:chain("Head", { "ChitinLight", "ChitinLight", "Chitin" }, a1, d2, hv(0, 1, 0), { n = 3, len = 0.7, w0 = 0.06, w1 = 0.05, bend = -10 * x, tip = false })
			local club = a1 + d2 * 0.72
			K:block("Head", "GalaxyLight", CFrame.new(club) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.16, 0.16, 0.16))
		end
	end,
}
