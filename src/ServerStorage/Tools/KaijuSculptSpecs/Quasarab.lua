local rad = math.rad
local H = require(script.Parent.Helpers)

-- Cosmic Rift / Epic / void: the quasarab, a cosmic Hercules beetle. A broad armoured beetle on six spiked legs (LegFL /
-- LegML / LegBL and their right twins: KaijuMotion walks them in two tripods). Its wing cases are deep blue, each
-- swirled with a spiral galaxy, pale glowing arms winding out of a white-hot core and white stars scattered over them.
-- A great thoracic shield of deep blue chitin flecked with stars, and a long pale horn curving forward from it, tipped
-- with a star. Head: big glowing compound eyes, two huge crossed sickle mandibles with serrated inner edges, long elbowed
-- antennae ending in glowing clubs. Lavender underside.
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
		LegFL = { 0.66, 1.08, -0.72 },
		LegFR = { -0.66, 1.08, -0.72 },
		LegML = { 0.72, 1.06, -0.3 },
		LegMR = { -0.72, 1.06, -0.3 },
		LegBL = { 0.72, 1.06, 0.12 },
		LegBR = { -0.72, 1.06, 0.12 },
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

		-- the great thoracic shield, flecked with stars, and the long horn curving forward from it
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
		local horn = { Vector3.new(0, 1.92, -0.5), Vector3.new(0, 2.18, -1.08), Vector3.new(0, 2.26, -1.66), Vector3.new(0, 2.5, -2.04) }
		H.curve(K, "Body", { "HornDark", "Horn", "Horn", "Horn" }, horn, 0.36, 0.08, 0.12)
		K:block("Body", "Star", CFrame.new(horn[4] + Vector3.new(0, 0.1, -0.06)) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.18, 0.18, 0.18))
		for _, z in { -1.2, -1.55 } do
			K:spike("Body", "Horn", Vector3.new(0, 2.12 + (z + 1.2) * -0.12, z), Vector3.new(0, -1, -0.3).Unit, Vector3.zAxis, 0.16, 0.08)
		end

		-- six spiked legs: the front pair reaching forward, the middle out to the side, the back pair back
		local function chit(_, ring)
			return ring % 2 == 0 and "Chitin" or "ChitinLight"
		end
		for _, x in { 1, -1 } do
			for _, o in { { "F", -0.72, -0.34, -0.62 }, { "M", -0.3, 0.0, 0.02 }, { "B", 0.12, 0.32, 0.66 } } do
				local g = "Leg" .. o[1] .. (x == 1 and "L" or "R")
				local hip = Vector3.new(0.66 * x + (o[1] == "F" and 0 or 0.06 * x), 1.08, o[2])
				local knee = Vector3.new(1.3 * x, 1.4, o[2] + o[3])
				local foot = Vector3.new(1.6 * x, 0.14, o[2] + o[4])
				local seg = H.limb(K, g, { { hip.X, hip.Y, hip.Z, 0.2 }, { knee.X, knee.Y, knee.Z, 0.15 }, { foot.X, foot.Y + 0.08, foot.Z, 0.08 } }, { step = 0.2, cores = { "Chitin", "ChitinLight" }, color = chit })
				K:block(g, "ChitinLight", CFrame.new(knee) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.24, 0.24, 0.24))
				-- spikes down the back of the shin
				for k = 1, 3 do
					local p = knee:Lerp(foot, k / 4)
					local out = Vector3.new(x * 0.6, 0.2, o[1] == "F" and 0.6 or (o[1] == "B" and -0.2 or 0.4)).Unit
					K:spike(g, "ClawTip", p, out, (foot - knee).Unit, 0.14, 0.05)
				end
				-- the foot: a short segmented tarsus along the ground ending in two hooks
				local fwd = Vector3.new(0.35 * x, 0, o[1] == "B" and 0.6 or (o[1] == "F" and -0.8 or 0)).Unit
				if fwd.Magnitude < 0.1 then
					fwd = Vector3.new(x, 0, 0)
				end
				K:chain(g, { "Chitin", "ChitinLight" }, foot + Vector3.new(0, 0.02, 0), fwd, Vector3.yAxis, { n = 2, len = 0.32, w0 = 0.1, w1 = 0.07, bend = 0, tip = false })
				for _, s in { -1, 1 } do
					K:chain(g, { "Claw", "ClawTip" }, foot + fwd * 0.32 + Vector3.new(0, 0.04, 0), (fwd + Vector3.yAxis:Cross(fwd) * 0.4 * s - Vector3.new(0, 0.3, 0)).Unit, Vector3.yAxis, { n = 2, len = 0.16, w0 = 0.05, w1 = 0.03, bend = 0 })
				end
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
