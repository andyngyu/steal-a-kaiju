local rad = math.rad
local GK = require(script.Parent.GuardianKit)
local H = GK.H

-- Sunken Abyss guardian: the Leviathan, an anglerfish titan risen from the trench. Upright and hunched: massive legs,
-- a deep chest, long arms, a heavy finned tail. Navy hide fading to a pale belly, rows of photophores glowing cyan in
-- dark pits down its flanks, a spiny dorsal fin webbed in membrane. Its shoulders are a reef: barnacle clusters and
-- coral growing out of them. Rusted chains wrap its forearms and it drags a ship's anchor in one claw. Face: a huge
-- underbite jaw bristling with needle fangs, small cyan eyes under heavy brows, and a lure on a long stalk arching from
-- its brow, glowing in front of its face.
local HEAD = CFrame.new(0, 5.9, -1.14) * CFrame.Angles(rad(-6), 0, 0)
local HINGE = Vector3.new(0, -0.3, -0.24)

return {
	Seed = 557,
	Vary = 0.04,
	Scale = 3.2,
	RootSize = { 8.8, 7.0, 11.0 },
	HipHeight = 1.86,
	Palette = {
		Hide = { "1E4A5C", Material = "Slate" },
		HideDark = { "10283A", Material = "Slate" },
		HideLight = { "4E8492", Material = "Slate" },
		Back = { "0A1828", Material = "Slate" },
		Belly = "D2D8C8",
		Belly2 = "B8C2B2",
		Barnacle = { "CFC8B2", Material = "Slate" },
		BarnacleDark = { "8C846E", Material = "Slate" },
		BarnacleMouth = "141A1E",
		Coral = "E8506E",
		CoralDark = "A8344E",
		CoralTip = { "FF5A82", Neon = true },
		Fin = { "1A3A4C", Material = "Slate" },
		Membrane = "2E5E6E",
		Spine = "E2DAC6",
		Chain = { "6A3E26", Material = "CorrodedMetal" },
		Anchor = { "4A3A30", Material = "CorrodedMetal" },
		LureStalk = { "23506A", Material = "Slate" },
		Lure = { "3FE0FF", Neon = true },
		Glow = { "1AA6D8", Neon = true },
		SeamLip = { "08141C", Material = "Slate" },
		Tooth = "EEF0E6",
		Gum = "6A2A3A",
		Mouth = "1A0610",
		Eye = { "22C4E8", Neon = true },
		Socket = "060C10",
		Claw = "142030",
		ClawTip = "C8D8D4",
	},
	Joints = {
		Head = { 0, 5.5, -0.42 },
		Jaw = HEAD * HINGE,
		LegL = { 0.95, 3.05, 0.35 },
		LegR = { -0.95, 3.05, 0.35 },
		ArmL = { 1.38, 5.0, -0.35 },
		ArmR = { -1.38, 5.0, -0.35 },
		Tail = { 0, 3.2, 0.72 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local SMOOTH = { w = 1.0, t = 0.14, lift = 3, jitter = 1, sink = 0.5, overlap = 1.08 }
		local function hide(th, ring)
			local a = math.deg(math.abs(th))
			if a > 130 then
				return ring % 2 == 0 and "Back" or "HideDark"
			end
			return a > 80 and "HideDark" or "Hide"
		end
		-- a barnacle: a pale cone of stacked rings with a dark mouth and a faint glow down inside it
		local function barnacle(g, pos, nrm, s)
			local ax = nrm:Cross(Vector3.zAxis)
			ax = ax.Magnitude > 1e-3 and ax.Unit or Vector3.xAxis
			local F = CFrame.fromMatrix(pos, ax, nrm) * CFrame.Angles(0, K:rand(0, 1.5), 0)
			K:block(g, "BarnacleDark", F * CFrame.new(0, s * 0.12, 0), Vector3.new(s, s * 0.3, s))
			K:block(g, "Barnacle", F * CFrame.new(0, s * 0.32, 0) * CFrame.Angles(0, rad(45), 0), Vector3.new(s * 0.8, s * 0.34, s * 0.8))
			K:block(g, "Barnacle", F * CFrame.new(0, s * 0.5, 0), Vector3.new(s * 0.56, s * 0.24, s * 0.56))
			K:block(g, "BarnacleMouth", F * CFrame.new(0, s * 0.6, 0), Vector3.new(s * 0.3, s * 0.06, s * 0.3))
			K:block(g, "Glow", F * CFrame.new(0, s * 0.58, 0), Vector3.new(s * 0.14, s * 0.06, s * 0.14))
		end
		local function coral(g, base, d, len, depth)
			K:chain(g, { "CoralDark", "Coral" }, base, d, Vector3.xAxis, { n = 2, len = len, w0 = 0.2 * (len / 0.6), w1 = 0.13 * (len / 0.6), bend = 0, tip = false })
			local tip = base + d * len
			if depth > 0 then
				for _, a in { -32, 32 } do
					local axis = d:Cross(Vector3.zAxis)
					axis = axis.Magnitude > 1e-3 and axis.Unit or Vector3.xAxis
					coral(g, tip, (CFrame.fromAxisAngle(axis, rad(a)) * d + Vector3.new(0, 0.2, 0)).Unit, len * 0.7, depth - 1)
				end
			else
				H.point(K, g, "CoralTip", tip + d * 0.06, d, 0.1)
			end
		end
		-- photophores: small glowing points in dark pits
		local function photophore(g, smp, th, s)
			local pos, nrm = K:surface(smp, th, -0.05)
			local F = CFrame.fromMatrix(pos, nrm:Cross(smp.T).Unit, nrm)
			K:block(g, "SeamLip", F, Vector3.new(s, 0.06, s))
			K:block(g, "Glow", F * CFrame.new(0, 0.01, 0), Vector3.new(s * 0.45, 0.06, s * 0.45))
		end

		-- an upright torso leaning forward (front = theta 0): a pale belly down the front
		local torso = K:tube("Body", {
			{ 0, 5.35, -0.3, rx = 1.3, ru = 0.88, rd = 0.88 },
			{ 0, 4.7, -0.1, rx = 1.4, ru = 1.02, rd = 0.94 },
			{ 0, 3.9, 0.15, rx = 1.28, ru = 0.98, rd = 0.92 },
			{ 0, 3.15, 0.42, rx = 1.06, ru = 0.82, rd = 0.86 },
		}, { step = 0.4, ref = Vector3.xAxis, core = "HideDark", coreScale = 0.88, tile = SMOOTH, color = function(th, ring)
			if math.abs(th) < rad(38) then
				return nil
			end
			return hide(th, ring)
		end })
		for s = 0.15, torso.total - 0.1, 0.32 do
			local smp = K:at(torso, s)
			K:tile("Body", s % 0.64 < 0.32 and "Belly" or "Belly2", smp, 0, 0.96 - s * 0.08, 0.32, 0.12, 4, 1, 0.3)
		end
		for _, x in { 1, -1 } do
			for s = 0.3, torso.total - 0.2, 0.34 do
				photophore("Body", K:at(torso, s), rad(70) * x, 0.2)
				photophore("Body", K:at(torso, s + 0.17), rad(96) * x, 0.16)
			end
		end
		-- the shoulder reef: a hump crusted with barnacles, coral growing out of it
		local mantle = K:tube("Body", {
			{ -1.42, 5.16, -0.28, rx = 0.7, ru = 0.66, rd = 0.56 },
			{ 0, 5.46, -0.2, rx = 0.82, ru = 0.72, rd = 0.6 },
			{ 1.42, 5.16, -0.28, rx = 0.7, ru = 0.66, rd = 0.56 },
		}, { step = 0.42, ref = Vector3.zAxis, core = "HideDark", coreScale = 0.9, tile = SMOOTH, color = hide })
		for s = 0.2, mantle.total - 0.2, 0.3 do
			local smp = K:at(mantle, s)
			for _, th in { -40, 0, 40 } do
				if K:rand(0, 1) < 0.75 then
					local pos, nrm = K:surface(smp, rad(th + K:rand(-10, 10)), -0.04)
					barnacle("Body", pos, nrm, K:rand(0.26, 0.4))
				end
			end
		end
		for _, o in { { 1.2, 1, 0.7 }, { -1.3, -1, 0.6 }, { 0.6, 0.4, 0.5 } } do
			coral("Body", Vector3.new(o[1], 5.7, -0.2), Vector3.new(o[2] * 0.4, 1, 0.2).Unit, o[3], 2)
		end
		-- the neck (moves with the head)
		K:tube("Head", {
			{ 0, 5.92, -1.0, rx = 0.7, ru = 0.66, rd = 0.68 },
			{ 0, 5.72, -0.7, rx = 0.82, ru = 0.76, rd = 0.8 },
			{ 0, 5.42, -0.36, rx = 0.92, ru = 0.84, rd = 0.88 },
		}, { step = 0.36, core = "HideDark", coreScale = 0.9, tile = H.plates(0.8), color = hide })
		-- the heavy tail, a fin at its end
		local tail = K:tube("Tail", {
			{ 0, 3.2, 0.68, rx = 0.88, ru = 0.84, rd = 0.82 },
			{ 0.08, 2.6, 1.78, rx = 0.72, ru = 0.68, rd = 0.66 },
			{ 0.4, 1.74, 2.86, rx = 0.54, ru = 0.5, rd = 0.48 },
			{ 0.96, 1.04, 3.74, rx = 0.38, ru = 0.36, rd = 0.34 },
			{ 1.66, 0.62, 4.32, rx = 0.24, ru = 0.22, rd = 0.2 },
		}, { step = 0.6, core = "HideDark", coreScale = 0.88, tile = H.plates(1.0, 5), belly = { key = "Belly", key2 = "Belly2", arc = 40, t = 0.11, wide = 1.05 }, color = hide, trim = 0.1 })
		local tt = K:at(tail, tail.total)
		for _, d in { Vector3.new(0.3, 1, 0.5), Vector3.new(0.5, -0.3, 1), Vector3.new(0.7, 0.4, 0.8) } do
			K:chain("Tail", { "Fin", "Membrane", "Spine" }, tt.p, d.Unit, tt.R, { n = 3, len = 1.1, w0 = 0.5, w1 = 0.12, bend = 0, depth = 0.2 })
		end
		for s = 0.4, tail.total - 0.6, 0.6 do
			for _, x in { 1, -1 } do
				photophore("Tail", K:at(tail, s), rad(90) * x, 0.18)
			end
		end
		-- the spiny dorsal fin down the back and tail: tall spines webbed with membrane
		local prev
		local function spineRow(g, samples, from, to, every, size, body)
			for s = from, to, every do
				local u = (s - from) / math.max(to - from, 1e-3)
				local smp = K:at(samples, s)
				local pos, nrm = K:surface(smp, body and math.pi or 0, 0.06)
				local d = body and (nrm + Vector3.new(0, 0.7, 0.2)).Unit or (nrm + smp.T * 0.3).Unit
				local len = size(u)
				K:chain(g, { "Fin", "Spine", "Spine" }, pos, d, Vector3.xAxis, { n = 3, len = len, w0 = 0.16, w1 = 0.07, bend = 8 })
				local cur = { pos = pos, d = d, len = len, g = g }
				if prev and prev.g == g then
					for _, f in { 0.3, 0.62 } do
						local pa, pb = prev.pos + prev.d * prev.len * f, cur.pos + cur.d * cur.len * f
						local across = pb - pa
						K:block(g, "Membrane", CFrame.fromMatrix((pa + pb) / 2, across.Unit, cur.d), Vector3.new(across.Magnitude + 0.06, cur.len * 0.36, 0.05))
					end
				end
				prev = cur
			end
		end
		spineRow("Body", torso, 0.3, torso.total - 0.2, 0.42, function(u) return 2.0 - u * 0.6 end, true)
		spineRow("Tail", tail, 0.3, tail.total - 1.0, 0.6, function(u) return 1.3 * (1 - u) + 0.4 end, false)

		for _, x in { 1, -1 } do
			-- massive legs on webbed feet, barnacles on the knees
			local g = x == 1 and "LegL" or "LegR"
			local dz = x == 1 and -0.12 or 0.16
			local leg = H.limb(K, g, {
				{ 0.95 * x, 3.05, 0.35, 0.82 },
				{ 1.16 * x, 1.78, -0.04 + dz, 0.66 },
				{ 1.12 * x, 0.6, 0.28 + dz, 0.46 },
			}, { step = 0.5, cores = { "HideDark", "HideDark" }, tiles = { SMOOTH, H.plates(0.9) }, color = hide })
			local knee = K:at(leg[2], 0.1)
			for _, th in { -20, 30 } do
				local pos, nrm = K:surface(knee, rad(th), -0.04)
				barnacle(g, pos, nrm, 0.3)
			end
			local foot = CFrame.new(1.12 * x, 0.22, -0.1 + dz) * CFrame.Angles(0, rad(-8 * x), 0)
			K:block(g, "HideDark", foot, Vector3.new(1.0, 0.44, 1.3))
			K:block(g, "Membrane", foot * CFrame.new(0, -0.12, -0.7), Vector3.new(1.1, 0.06, 0.5))
			for t = -1, 1 do
				local dirT = CFrame.Angles(0, rad(t * 22 - 8 * x), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
				local base = (foot * Vector3.new(t * 0.32, -0.04, -0.54)) + dirT * 0.1
				K:chain(g, { "Claw", "Claw", "ClawTip" }, base, (dirT - Vector3.new(0, 0.2, 0)).Unit, dirT:Cross(Vector3.yAxis), { n = 3, len = 0.5, w0 = 0.17, w1 = 0.09, bend = -30 })
			end
			-- long arms reaching forward, webbed claws, rusted chain wound round the forearms
			local ga = x == 1 and "ArmL" or "ArmR"
			local arm = H.limb(K, ga, {
				{ 1.38 * x, 5.0, -0.35, 0.48 },
				{ 1.86 * x, 3.9, -0.6, 0.4 },
				{ 1.7 * x, 3.0, -1.2, 0.34 },
			}, { step = 0.42, cores = { "HideDark", "HideDark" }, tiles = { H.plates(0.86), nil }, color = hide })
			local fore = arm[2]
			for k = 0, 9 do
				local smp = K:at(fore, fore.total * (0.15 + k * 0.06))
				local a = k * rad(70)
				local pos = K:surface(smp, a, -0.08)
				K:block(ga, "Chain", CFrame.fromMatrix(pos, smp.T, (pos - smp.p).Unit) * CFrame.Angles(0, k % 2 == 0 and 0 or rad(90), 0), Vector3.new(0.3, 0.1, 0.18))
			end
			local hand = CFrame.lookAt(Vector3.new(1.68 * x, 2.9, -1.36), Vector3.new(1.62 * x, 2.4, -2.1))
			K:block(ga, "HideDark", hand, Vector3.new(0.6, 0.42, 0.52))
			for t = -1, 1 do
				local d = hand:VectorToWorldSpace(Vector3.new(t * 0.3, 0, -1)).Unit
				K:chain(ga, { "Claw", "Claw", "ClawTip" }, hand * Vector3.new(t * 0.18, 0, -0.2), d, hand.RightVector, { n = 3, len = 0.6, w0 = 0.14, w1 = 0.07, bend = 26 })
			end
			K:block(ga, "Membrane", hand * CFrame.new(0, -0.05, -0.42), Vector3.new(0.5, 0.05, 0.4))
			if x == 1 then
				-- the ship's anchor hanging from the left claw
				local top = Vector3.new(1.74, 2.6, -1.62)
				K:block(ga, "Anchor", CFrame.new(top + Vector3.new(0, -0.95, 0)), Vector3.new(0.18, 1.9, 0.18))
				K:block(ga, "Anchor", CFrame.new(top + Vector3.new(0, -0.3, 0)), Vector3.new(0.9, 0.14, 0.16))
				K:block(ga, "Anchor", CFrame.new(top + Vector3.new(0, 0.16, 0)) * CFrame.Angles(rad(90), 0, 0), Vector3.new(0.42, 0.12, 0.42))
				for _, sd in { 1, -1 } do
					K:block(ga, "Anchor", CFrame.new(top + Vector3.new(sd * 0.42, -1.72, 0)) * CFrame.Angles(0, 0, rad(-sd * 50)), Vector3.new(0.16, 0.9, 0.16))
					H.point(K, ga, "Anchor", top + Vector3.new(sd * 0.82, -1.36, 0), Vector3.new(sd * 0.5, 1, 0).Unit, 0.26)
				end
				K:block(ga, "Anchor", CFrame.new(top + Vector3.new(0, -1.9, 0)) * CFrame.Angles(0, 0, rad(90)), Vector3.new(0.18, 1.0, 0.18))
			end
		end

		-- the anglerfish head: wide and heavy, a huge underbite, a lure on a stalk arching over the face
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.22, -0.4), Vector3.new(1.6, 0.9, 1.0))
		K:block("Head", "Hide", hcf(0, 0.16, -1.0), Vector3.new(1.44, 0.62, 0.7))
		K:block("Head", "Back", hcf(0, 0.7, -0.5, -8, 0, 0), Vector3.new(1.2, 0.1, 1.0))
		K:block("Head", "Mouth", hcf(0, -0.16, -0.9), Vector3.new(1.3, 0.06, 1.1))
		K:block("Head", "Glow", hcf(0, -0.15, -0.4), Vector3.new(0.3, 0.06, 0.2))
		for _, x in { 1, -1 } do
			K:block("Head", "HideDark", hcf(0.72 * x, 0.1, -0.5, 0, -10 * x, 0), Vector3.new(0.26, 0.8, 0.9))
			-- small eyes under heavy brows, set wide
			K:block("Head", "Back", hcf(0.56 * x, 0.74, -0.9, -10, -14 * x, 20 * x), Vector3.new(0.5, 0.16, 0.46))
			H.eye(K, "Head", hcf(0.6 * x, 0.5, -1.02, 0, -24 * x, 12 * x), 0.28, 0.09)
			-- needle fangs down the upper jaw, the longest at the front
			for k, z in { -0.5, -0.74, -0.98, -1.2 } do
				H.fang(K, "Head", "Tooth", hp((0.62 - k * 0.04) * x, -0.16, z), hv(0.15 * x, -1, -0.1), 0.26 + k * 0.05, 0.07)
			end
		end
		H.teeth(K, "Head", "Tooth", hp(-0.44, -0.16, -1.32), hp(0.44, -0.16, -1.32), 5, hv(0, -1, -0.15), hv(0, 0, 1), 0.3, 0.07)
		-- the lure: a stalk arching up from the brow and out over the face, a glowing bulb in a cage of fin rays
		local stalk = { hp(0, 0.74, -0.4), hp(0, 1.4, -0.9), hp(0, 1.4, -1.7), hp(0, 0.86, -2.2), hp(0, 0.5, -2.24) }
		H.curve(K, "Head", { "LureStalk", "LureStalk", "LureStalk", "Fin" }, stalk, 0.14, 0.07, 0.16)
		local bulb = hp(0, 0.3, -2.24)
		K:block("Head", "Lure", CFrame.new(bulb) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.3, 0.3, 0.3))
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2
			local d = (hv(math.cos(a), 0, math.sin(a)) + Vector3.new(0, -0.5, 0)).Unit
			K:chain("Head", { "Membrane", "Spine" }, bulb + Vector3.new(0, 0.18, 0), d, Vector3.yAxis, { n = 2, len = 0.34, w0 = 0.05, w1 = 0.035, bend = 0 })
		end
		-- the huge underbite jaw, jutting past the upper jaw, fangs pointing up and out
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-24), 0, 0)
		local function jcf(px, py, pz)
			return JAW * CFrame.new(px, py, pz)
		end
		K:block("Jaw", "Hide", jcf(0, -0.2, -0.86), Vector3.new(1.7, 0.44, 1.7))
		K:block("Jaw", "Belly", jcf(0, -0.43, -0.82), Vector3.new(1.5, 0.06, 1.5))
		K:block("Jaw", "Gum", jcf(0, 0.03, -0.9), Vector3.new(1.5, 0.05, 1.5))
		K:block("Jaw", "Mouth", jcf(0, 0.05, -0.8), Vector3.new(1.2, 0.05, 1.2))
		local up = JAW:VectorToWorldSpace(Vector3.yAxis)
		for _, x in { 1, -1 } do
			for k, z in { -0.4, -0.7, -1.0, -1.3, -1.56 } do
				local out = JAW:VectorToWorldSpace(Vector3.new(0.25 * x, 1, -0.15)).Unit
				H.fang(K, "Jaw", "Tooth", JAW * Vector3.new((0.76 - k * 0.04) * x, 0.02, z), out, 0.3 + (k % 2) * 0.14, 0.08)
			end
		end
		H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(-0.56, 0.02, -1.66), JAW * Vector3.new(0.56, 0.02, -1.66), 6, JAW:VectorToWorldSpace(Vector3.new(0, 1, -0.3)).Unit, JAW:VectorToWorldSpace(Vector3.zAxis), 0.34, 0.08)
		GK.lids(K, Color3.fromHex("0A1828"))
	end,
}
