local rad = math.rad
local H = require(script.Parent.Helpers)

-- Sunken Abyss / Uncommon / water: the barnaclaw, a wreck-crawling crab that has been on the seabed so long the reef
-- grew onto it. A heavy deep-teal carapace crusted with barnacle clusters (each one glowing faintly cyan down its
-- mouth), branching coral and anemones growing from the top, kelp trailing off the rim, a pale underside. One giant
-- crusher claw scarred and barnacled, one small slicer claw, cyan eyes on stalks under spiked brows.
return {
	Seed = 509,
	Vary = 0.05,
	Scale = 1.15,
	Gait = "Scuttle",
	Emotes = { "ClawSnap", "Look", "Wiggle" },
	Palette = {
		Shell = { "1E4A58", Material = "Slate" },
		ShellDark = { "10283A", Material = "Slate" },
		ShellLight = { "4E8A90", Material = "Slate" },
		Belly = "D2D8C6",
		Spike = { "2A3E4A", Material = "Slate" },
		SpikeTip = "D8D2BE",
		Claw = { "C8643A", Material = "Slate" },
		ClawDark = { "7A3A22", Material = "Slate" },
		Reef = { "B65A34", Material = "Slate" },
		ReefDark = { "7A3A24", Material = "Slate" },
		ReefLight = { "D88A52", Material = "Slate" },
		CoralOrange = "F07A3A",
		CoralOrangeDark = "B4501E",
		CoralTeal = "2EB0A8",
		CoralTealDark = "1A7A74",
		TipOrange = { "FF9A4A", Neon = true },
		TipTeal = { "3FE0D0", Neon = true },
		Barnacle = { "CFC8B2", Material = "Slate" },
		BarnacleDark = { "8C846E", Material = "Slate" },
		BarnacleMouth = "141A1E",
		Glow = { "1AA6D8", Neon = true },
		Coral = "E8506E",
		CoralDark = "A8344E",
		CoralTip = { "FF5A82", Neon = true },
		Anemone = "F08A4A",
		Kelp = "3E6A3A",
		KelpDark = "284A28",
		Tooth = "E6E8DC",
		Mouth = "2A0E18",
		Eye = { "22C4E8", Neon = true },
		Socket = "060C10",
	},
	Joints = H.CRAB_JOINTS,
	Build = function(K)
		-- a barnacle: a pale cone of stacked rings with a dark mouth and a faint glow down inside it
		local function barnacle(g, pos, nrm, s)
			local F = CFrame.fromMatrix(pos, nrm:Cross(Vector3.zAxis).Magnitude > 1e-3 and nrm:Cross(Vector3.zAxis).Unit or Vector3.xAxis, nrm) * CFrame.Angles(0, K:rand(0, 1.5), 0)
			K:block(g, "BarnacleDark", F * CFrame.new(0, s * 0.12, 0), Vector3.new(s, s * 0.3, s))
			K:block(g, "Barnacle", F * CFrame.new(0, s * 0.32, 0) * CFrame.Angles(0, rad(45), 0), Vector3.new(s * 0.8, s * 0.34, s * 0.8))
			K:block(g, "Barnacle", F * CFrame.new(0, s * 0.5, 0), Vector3.new(s * 0.56, s * 0.24, s * 0.56))
			K:block(g, "BarnacleMouth", F * CFrame.new(0, s * 0.6, 0), Vector3.new(s * 0.3, s * 0.06, s * 0.3))
			K:block(g, "Glow", F * CFrame.new(0, s * 0.58, 0), Vector3.new(s * 0.14, s * 0.06, s * 0.14))
		end
		local shell = H.crab(K, {
			clawScale = { 1.75, 0.85 },
			crest = function(K, shell)
				-- barnacle clusters scattered over the carapace
				for s = 0.15, shell.total - 0.1, 0.3 do
					local smp = K:at(shell, s)
					for _, th in { -50, -18, 20, 52 } do
						if K:rand(0, 1) < 0.7 then
							local pos, nrm = K:surface(smp, rad(th + K:rand(-10, 10)), -0.02)
							barnacle("Body", pos, nrm, K:rand(0.18, 0.3))
						end
					end
				end
				-- a tall domed reef mound grown over the back of the shell: stacked rounded layers of orange reef rock
				local C = Vector3.new(0, 1.66, 0.5)
				local RX, RY, RZ = 1.12, 1.85, 1.02
				-- a point on the mound's surface and its outward normal, by angle round (az) and up (el)
				local function onMound(az, el)
					local ce, se = math.cos(el), math.sin(el)
					local p = C + Vector3.new(RX * ce * math.sin(az), RY * se, RZ * ce * math.cos(az))
					local n = Vector3.new(ce * math.sin(az) / RX, se / RY, ce * math.cos(az) / RZ).Unit
					return p, n
				end
				-- a solid core, then the surface built up from tilted rock lumps so it reads as a rounded reef boulder
				for i, s in { { 0.0, 1.0 }, { 0.45, 0.86 }, { 0.85, 0.58 } } do
					local c = C + Vector3.new(0, RY * s[1] * 0.85, 0)
					K:block("Body", "ReefDark", CFrame.new(c), Vector3.new(RX * 1.7 * s[2], RY * 0.7, RZ * 1.7 * s[2]))
					K:block("Body", "ReefDark", CFrame.new(c) * CFrame.Angles(0, rad(45), 0), Vector3.new(RX * 1.5 * s[2], RY * 0.66, RZ * 1.5 * s[2]))
				end
				local k = 0
				for el = 0.08, 1.45, 0.3 do
					local ring = math.max(1, math.floor(9 * math.cos(el) + 0.5))
					for j = 0, ring - 1 do
						local az = j / ring * math.pi * 2 + el * 1.7
						local p, n = onMound(az, el)
						local sz = K:rand(0.5, 0.72) * (1 - el * 0.22)
						local side = n:Cross(Vector3.yAxis)
						side = side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis
						local key = k % 3 == 0 and "ReefLight" or (k % 3 == 1 and "Reef" or "ReefDark")
						K:block("Body", key, CFrame.fromMatrix(p - n * sz * 0.3, side, n) * CFrame.Angles(rad(K:rand(-15, 15)), rad(K:rand(0, 90)), rad(K:rand(-15, 15))), Vector3.new(sz, sz * 0.7, sz))
						k += 1
					end
				end
				local SETS = {
					{ "CoralOrangeDark", "CoralOrange", "TipOrange" },
					{ "CoralDark", "Coral", "CoralTip" },
					{ "CoralTealDark", "CoralTeal", "TipTeal" },
				}
				local function coral(set, base, d, len, depth)
					K:chain("Body", { set[1], set[2] }, base, d, Vector3.xAxis, { n = 2, len = len, w0 = 0.2 * (len / 0.6), w1 = 0.13 * (len / 0.6), bend = 0, tip = false })
					local tip = base + d * len
					if depth > 0 then
						for _, a in { -32, 32 } do
							local axis = d:Cross(Vector3.zAxis)
							axis = axis.Magnitude > 1e-3 and axis.Unit or Vector3.xAxis
							coral(set, tip, (CFrame.fromAxisAngle(axis, rad(a)) * d + Vector3.new(K:rand(-0.2, 0.2), 0.25, K:rand(-0.2, 0.2))).Unit, len * 0.7, depth - 1)
						end
					else
						H.point(K, "Body", set[3], tip + d * 0.06, d, 0.09)
					end
				end
				-- branching coral in orange, pink and teal growing from the mound
				for i, o in { { 0, 1.3, 0.8, 2 }, { 0.9, 0.85, 0.7, 2 }, { -1.0, 0.9, 0.7, 2 }, { 2.4, 0.75, 0.62, 2 }, { -2.3, 0.8, 0.62, 2 }, { 3.14, 0.95, 0.6, 2 }, { 1.7, 0.4, 0.5, 1 }, { -1.6, 0.45, 0.5, 1 }, { 0.4, 0.5, 0.46, 1 } } do
					local p, n = onMound(o[1], o[2])
					coral(SETS[(i - 1) % 3 + 1], p - n * 0.04, (n + Vector3.new(0, 0.9, 0)).Unit, o[3], o[4])
				end
				-- barnacle clusters and anemones studding the mound
				for k = 0, 15 do
					local az, el = k * 2.4, 0.15 + (k % 4) * 0.22
					local p, n = onMound(az, el)
					barnacle("Body", p - n * 0.05, n, K:rand(0.2, 0.3))
				end
				for k, o in { { 0.5, 0.3 }, { -0.6, 0.45 }, { 2.0, 0.25 }, { -2.2, 0.5 }, { 3.0, 0.3 } } do
					local p, n = onMound(o[1], o[2])
					local key = k % 2 == 0 and "CoralTeal" or "Anemone"
					K:block("Body", key, CFrame.lookAt(p + n * 0.06, p + n), Vector3.new(0.34, 0.34, 0.16))
					for j = 0, 6 do
						local a = j / 7 * math.pi * 2
						local side = n:Cross(Vector3.yAxis)
						side = side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis
						local up2 = side:Cross(n).Unit
						K:chain("Body", { key, k % 2 == 0 and "TipTeal" or "CoralTip" }, p + n * 0.14, (n + (side * math.cos(a) + up2 * math.sin(a)) * 0.7).Unit, n, { n = 2, len = 0.3, w0 = 0.06, w1 = 0.04, bend = -20, tip = false })
					end
				end
				-- kelp trailing off the rim
				for s = 0.3, shell.total - 0.2, 0.45 do
					local smp = K:at(shell, s)
					for _, x in { 1, -1 } do
						local pos, nrm = K:surface(smp, rad(96) * x, 0.02)
						K:chain("Body", { "Kelp", "KelpDark", "Kelp" }, pos, (nrm * 0.3 + Vector3.new(0, -1, 0.3)).Unit, smp.T, { n = 3, len = K:rand(0.4, 0.6), w0 = 0.16, w1 = 0.1, bend = 12, depth = 0.25, tip = false })
					end
				end
			end,
		})
		-- barnacles on the giant crusher claw (ClawL), a heavy spiked brow over each eye stalk
		local palm = CFrame.lookAt(Vector3.new(1.5, 1.34, -1.5), Vector3.new(1.46, 1.48, -2.4))
		K:scaled(Vector3.new(1.0, 1.1, -0.5), 1.75, function()
			for _, o in { { 0.3, 0.2, 0.1, 0.16 }, { 0.32, -0.1, -0.2, 0.13 }, { -0.1, 0.33, 0.2, 0.14 } } do
				local pos = palm * Vector3.new(o[1], o[2], o[3])
				barnacle("ClawL", pos, (pos - palm.Position).Unit, o[4])
			end
		end)
		for _, x in { 1, -1 } do
			K:block("Body", "Spike", CFrame.new(0.36 * x, 1.62, -0.62) * CFrame.Angles(rad(-14), rad(-10 * x), rad(16 * x)), Vector3.new(0.34, 0.1, 0.28))
			K:chain("Body", { "Spike", "SpikeTip" }, Vector3.new(0.48 * x, 1.66, -0.6), Vector3.new(0.6 * x, 0.6, -0.3).Unit, Vector3.zAxis, { n = 2, len = 0.28, w0 = 0.1, w1 = 0.06, bend = 0 })
		end
	end,
}
