local rad = math.rad
local H = require(script.Parent.Helpers)

-- Sunken Abyss / Legendary / water: the megajaw, a megalodon that crawled out of the deep on four fin-legs. A massive
-- shark body low to the ground, slate-blue skin going navy along the back and white underneath, a towering dorsal fin,
-- a crescent tail, pectoral fins flaring off the front legs. Five gill slits a side glow cyan from inside. Old harpoons
-- still stuck in its back trail rope; a rusted anchor chain is wrapped round one leg; scars rake its flanks. Face: a
-- great conical snout, small cyan eyes under heavy brows, the jaws hanging open on rows of serrated teeth.
local HEAD = CFrame.new(0, 1.96, -1.86) * CFrame.Angles(rad(-4), 0, 0)
local HINGE = Vector3.new(0, -0.3, -0.24)

return {
	Seed = 531,
	Vary = 0.04,
	Scale = 1.15,
	Gait = "Crawl",
	Emotes = { "Look", "Chomp" },
	Palette = {
		Hide = { "3E5E70", Material = "Slate" },
		HideDark = { "243C4C", Material = "Slate" },
		HideLight = { "7A98A6", Material = "Slate" },
		Back = { "132536", Material = "Slate" },
		Belly = "E6ECE6",
		Belly2 = "CED8D2",
		Fin = { "26404E", Material = "Slate" },
		FinDark = { "132536", Material = "Slate" },
		Scar = "9AB0BA",
		Gum = "B04A5E",
		Mouth = "300A16",
		Tooth = "F2F2EA",
		Wood = { "6B4E30", Material = "Wood" },
		Metal = { "7E888E", Material = "Metal" },
		Rope = "B8A27A",
		Chain = { "5A3A2A", Material = "CorrodedMetal" },
		Glow = { "1AA6D8", Neon = true },
		SeamLip = { "08141C", Material = "Slate" },
		Eye = { "22C4E8", Neon = true },
		Socket = "060C10",
		Claw = "1A2A30",
		ClawTip = "C8D8D4",
	},
	Joints = {
		Head = { 0, 1.9, -1.4 },
		Jaw = HEAD * HINGE,
		LegFL = { 0.9, 1.5, -0.8 },
		LegFR = { -0.9, 1.5, -0.8 },
		LegBL = { 0.84, 1.46, 1.0 },
		LegBR = { -0.84, 1.46, 1.0 },
		Tail = { 0, 1.64, 1.7 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		-- a raked shark fin: stacked boards from the base up, the leading edge sweeping back, thin across
		local function fin(g, base, up, along, height, length, thick, n)
			n = n or 7
			local side = along:Cross(up).Unit
			for i = 0, n - 1 do
				local f = i / n
				local front = -length * 0.5 + f * length * 0.95
				local back = length * 0.5 + f * length * 0.18
				local c = base + up * height * (f + 0.5 / n) + along * (front + back) / 2
				K:block(g, "Fin", CFrame.fromMatrix(c, along, up, side), Vector3.new(math.max(back - front, 0.12), height / n * 1.15, thick * (1 - f * 0.5)))
				-- a darker leading edge
				K:block(g, "FinDark", CFrame.fromMatrix(c + along * (front - (front + back) / 2 + 0.08), along, up, side), Vector3.new(0.18, height / n * 1.15, thick * (1 - f * 0.5) + 0.02))
			end
		end
		local skin = H.skin({ stripe = 34, band = 70, flank = 106, every = 3, upper = "HideDark" })
		local smooth = { w = 0.64, t = 0.11, lift = 2, jitter = 0.6, sink = 0.55, overlap = 1.06 }
		local belly = { key = "Belly", key2 = "Belly2", arc = 62, t = 0.11, wide = 1.12 }
		local body = K:tube("Body", {
			{ 0, 1.86, -1.3, rx = 0.98, ru = 0.88, rd = 0.92 },
			{ 0, 1.98, -0.3, rx = 1.26, ru = 1.14, rd = 1.1 },
			{ 0, 1.88, 0.8, rx = 1.12, ru = 1.0, rd = 0.96 },
			{ 0, 1.66, 1.8, rx = 0.8, ru = 0.74, rd = 0.7 },
		}, { step = 0.38, core = "Hide", coreScale = 0.92, tile = smooth, belly = belly, color = skin })
		local tail = K:tube("Tail", {
			{ 0, 1.66, 1.64, rx = 0.78, ru = 0.72, rd = 0.68 },
			{ 0, 1.72, 2.6, rx = 0.54, ru = 0.52, rd = 0.48 },
			{ 0.06, 1.86, 3.46, rx = 0.32, ru = 0.32, rd = 0.3 },
			{ 0.14, 2.02, 4.14, rx = 0.18, ru = 0.2, rd = 0.18 },
		}, { step = 0.36, core = "Hide", coreScale = 0.92, tile = { w = 0.5, n = 6, t = 0.1, lift = 2, jitter = 0.6, sink = 0.55, overlap = 1.06 }, belly = belly, color = skin, trim = 0.06 })
		-- the crescent tail fin
		local tip = K:at(tail, tail.total)
		local flat = Vector3.new(tip.T.X, 0, tip.T.Z).Unit
		-- the crescent tail fin: a tall upper lobe and a shorter lower one, both raked back
		fin("Tail", tip.p - Vector3.new(0, 0.1, 0), (Vector3.yAxis + flat * 0.55).Unit, (flat - Vector3.yAxis * 0.55).Unit, 2.1, 1.0, 0.16, 7)
		fin("Tail", tip.p + Vector3.new(0, 0.1, 0), (-Vector3.yAxis + flat * 0.5).Unit, (flat + Vector3.yAxis * 0.5).Unit, 1.3, 0.8, 0.14, 5)
		-- the towering dorsal fin, a smaller one behind it
		for _, o in { { body, 0.9, 2.4, 2.0 }, { tail, 1.4, 0.8, 0.8 } } do
			local smp = K:at(o[1], o[2])
			local pos = K:surface(smp, 0, 0.12)
			local fl = Vector3.new(smp.T.X, 0, smp.T.Z).Unit
			fin(o[1] == body and "Body" or "Tail", pos, Vector3.yAxis, fl, o[3], o[4], 0.2, o[1] == body and 11 or 5)
		end
		-- gill slits glowing from inside, scars down the flanks
		for _, x in { 1, -1 } do
			for k = 0, 4 do
				local smp = K:at(body, 0.2 + k * 0.22)
				local p, n = K:surface(smp, rad(74) * x, -0.04)
				local F = CFrame.fromMatrix(p, smp.T, n) * CFrame.Angles(0, rad(90), 0)
				K:block("Body", "SeamLip", F, Vector3.new(0.14, 0.08, 1.0 - k * 0.08))
				K:block("Body", "Glow", F * CFrame.new(0, -0.01, 0), Vector3.new(0.06, 0.08, 0.86 - k * 0.08))
			end
			for k = 0, 3 do
				local smp = K:at(body, 1.6 + k * 0.3)
				local p, n = K:surface(smp, rad(84 + k * 6) * x, -0.07)
				K:block("Body", "Scar", CFrame.fromMatrix(p, smp.T, n) * CFrame.Angles(0, rad(30 + k * 8), 0), Vector3.new(0.06, 0.06, 0.7))
			end
		end
		-- old harpoons stuck in the back, trailing rope
		for i, o in { { 1.2, 22, 0.9 }, { 2.2, -30, 1.1 }, { 0.6, -14, 0.8 } } do
			local smp = K:at(body, o[1])
			local pos, nrm = K:surface(smp, rad(o[2]), 0.1)
			local d = (nrm + smp.T * 0.5 + smp.R * 0.2).Unit
			K:block("Body", "Wood", CFrame.lookAt(pos + d * o[3] * 0.5, pos + d * 2), Vector3.new(0.09, 0.09, o[3]))
			K:block("Body", "Metal", CFrame.lookAt(pos + d * 0.05, pos + d * 2) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.2, 0.2, 0.16))
			K:block("Body", "Metal", CFrame.lookAt(pos + d * (o[3] - 0.04), pos + d * 2), Vector3.new(0.12, 0.12, 0.1))
			local rope = { pos + d * o[3] * 0.8, pos + d * o[3] * 0.9 + smp.T * 0.4 + Vector3.new(0, -0.2, 0), pos + d * o[3] * 0.6 + smp.T * 0.9 + Vector3.new(0, -0.6, 0) }
			H.curve(K, "Body", { "Rope" }, rope, 0.05, 0.04, 0.12)
		end
		-- four stocky fin-legs on broad flat flipper feet, pectoral fins flaring off the front pair
		for _, x in { 1, -1 } do
			for _, L in { { "LegF", -0.8, 0.46, 0.38 }, { "LegB", 1.0, 0.5, 0.4 } } do
				local g = L[1] .. (x == 1 and "L" or "R")
				H.quadLeg(K, g, {
					{ 0.9 * x, 1.5, L[2], L[3] },
					{ 1.42 * x, 1.0, L[2] - 0.1, L[4] },
					{ 1.5 * x, 0.3, L[2] - 0.24, L[4] * 0.8 },
				}, { step = 0.34, cores = { "Hide", "HideDark" }, tiles = { smooth, nil }, color = skin, foot = { size = Vector3.new(0.86, 0.2, 1.0), key = "HideDark" }, yaw = 18, toes = 3, claw = { len = 0.22, w = 0.08, curl = 20 } })
				if L[1] == "LegF" then
					K:chain(g, { "FinDark", "Fin", "FinDark" }, Vector3.new(1.3 * x, 1.2, -0.7), Vector3.new(0.6 * x, -0.3, 1).Unit, Vector3.yAxis, { n = 3, len = 1.3, w0 = 0.7, w1 = 0.14, bend = -10 * x, depth = 0.14 })
				end
			end
		end
		-- a rusted anchor chain wrapped round the front left leg, the end dragging
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local c = Vector3.new(1.38 + math.cos(a) * 0.42, 0.9 + k * 0.04, -0.9 + math.sin(a) * 0.42)
			K:block("LegFL", "Chain", CFrame.new(c) * CFrame.Angles(0, -a, k % 2 == 0 and 0 or rad(90)), Vector3.new(0.1, 0.22, 0.32))
		end
		for k = 0, 3 do
			K:block("LegFL", "Chain", CFrame.new(1.8 + k * 0.06, 0.7 - k * 0.18, -0.6 + k * 0.2) * CFrame.Angles(rad(30), 0, k % 2 == 0 and 0 or rad(90)), Vector3.new(0.1, 0.22, 0.32))
		end

		-- the head (origin at the back of the skull, facing -Z): a great conical snout
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		-- each section square plus a turned copy, so the cone reads rounded, tapering to a blunt point
		for _, s in { { 0.2, -0.3, 1.6, 0.96, 1.0 }, { 0.24, -0.96, 1.34, 0.8, 0.8 }, { 0.2, -1.5, 1.0, 0.62, 0.56 }, { 0.14, -1.9, 0.6, 0.42, 0.34 } } do
			K:block("Head", "Hide", hcf(0, s[1], s[2]), Vector3.new(s[3], s[4], s[5]))
			K:block("Head", "Hide", hcf(0, s[1] + 0.04, s[2], 0, 0, 45), Vector3.new(s[4] * 0.95, s[4] * 0.95, s[5] * 0.96))
		end
		K:block("Head", "Back", hcf(0, 0.66, -0.6, -6, 0, 0), Vector3.new(1.1, 0.08, 1.2))
		K:block("Head", "HideDark", hcf(0, 0.56, -1.4, -14, 0, 0), Vector3.new(0.7, 0.08, 0.8))
		K:block("Head", "HideLight", hcf(0, -0.08, -1.2), Vector3.new(1.1, 0.06, 1.2))
		for _, x in { 1, -1 } do
			K:block("Head", "Hide", hcf(0.56 * x, 0.2, -1.36, 0, 22 * x, 0), Vector3.new(0.3, 0.6, 0.9))
			-- small eyes under heavy brows
			K:block("Head", "Back", hcf(0.6 * x, 0.6, -1.0, -10, -14 * x, 20 * x), Vector3.new(0.4, 0.14, 0.42))
			H.eye(K, "Head", hcf(0.68 * x, 0.42, -1.04, 0, -40 * x, 10 * x), 0.14, 0.05)
			K:block("Head", "Socket", hcf(0.2 * x, 0.2, -2.0), Vector3.new(0.1, 0.06, 0.04))
		end
		-- the upper jaw: gums and two rows of serrated teeth round a U
		K:block("Head", "Mouth", hcf(0, -0.1, -1.0), Vector3.new(1.2, 0.06, 1.6))
		local function arc(z0, row, len)
			for k = -6, 6 do
				local f = k / 6
				local x = math.sin(f * 1.25) * (0.62 - row * 0.12)
				local z = z0 + (1 - math.cos(f * 1.25)) * 0.9 + row * 0.16
				K:block("Head", "Gum", hcf(x, -0.1, z), Vector3.new(0.14, 0.05, 0.14))
				K:spike("Head", "Tooth", hp(x, -0.12, z), hv(0, -1, 0.05), hv(math.cos(f), 0, -math.sin(f)), len * (k % 2 == 0 and 1 or 0.8), 0.07)
			end
		end
		arc(-1.78, 0, 0.26)
		arc(-1.78, 1, 0.16)
		-- the lower jaw hanging open, teeth up in rows, a faint glow deep in the throat
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-30), 0, 0)
		local function jcf(px, py, pz)
			return JAW * CFrame.new(px, py, pz)
		end
		K:block("Jaw", "Hide", jcf(0, -0.16, -0.8), Vector3.new(1.3, 0.34, 1.56))
		K:block("Jaw", "Belly", jcf(0, -0.34, -0.74), Vector3.new(1.1, 0.04, 1.36))
		K:block("Jaw", "Mouth", jcf(0, 0.02, -0.82), Vector3.new(1.1, 0.04, 1.4))
		K:block("Jaw", "Glow", jcf(0, 0.03, -0.24), Vector3.new(0.3, 0.04, 0.2))
		local up = JAW:VectorToWorldSpace(Vector3.yAxis)
		for row = 0, 1 do
			for k = -6, 6 do
				local f = k / 6
				local x = math.sin(f * 1.25) * (0.56 - row * 0.12)
				local z = -1.5 + (1 - math.cos(f * 1.25)) * 0.8 + row * 0.16
				K:block("Jaw", "Gum", jcf(x, 0.02, z), Vector3.new(0.13, 0.05, 0.13))
				K:spike("Jaw", "Tooth", JAW * Vector3.new(x, 0.03, z), up, JAW:VectorToWorldSpace(Vector3.new(math.cos(f), 0, -math.sin(f))), (row == 0 and 0.24 or 0.15) * (k % 2 == 0 and 1 or 0.8), 0.07)
			end
		end
	end,
}
