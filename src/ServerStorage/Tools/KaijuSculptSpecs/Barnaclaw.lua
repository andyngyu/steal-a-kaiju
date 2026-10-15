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
		Claw = { "28566A", Material = "Slate" },
		ClawDark = { "12303E", Material = "Slate" },
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
				-- branching coral and anemones growing from the back of the shell
				local function coral(base, d, len, depth)
					K:chain("Body", { "CoralDark", "Coral" }, base, d, Vector3.xAxis, { n = 2, len = len, w0 = 0.2 * (len / 0.6), w1 = 0.13 * (len / 0.6), bend = 0, tip = false })
					local tip = base + d * len
					if depth > 0 then
						for _, a in { -32, 32 } do
							local nd = (CFrame.fromAxisAngle(Vector3.new(d.Z, 0, -d.X).Magnitude > 1e-3 and Vector3.new(d.Z, 0, -d.X).Unit or Vector3.xAxis, rad(a)) * d).Unit
							coral(tip, (nd + Vector3.new(K:rand(-0.2, 0.2), 0.2, K:rand(-0.2, 0.2))).Unit, len * 0.7, depth - 1)
						end
					else
						H.point(K, "Body", "CoralTip", tip + d * 0.06, d, 0.08)
					end
				end
				for i, o in { { 0.4, 0.5, 1.24 }, { -0.36, 0.6, 0.72 }, { 0.1, 0.4, 0.2 }, { -0.62, 0.3, 1.4 }, { 0.66, 0.35, 0.6 } } do
					local smp = K:at(shell, o[3])
					local pos = K:surface(smp, rad(o[1] * 60), -0.02)
					coral(pos, Vector3.new(o[1], 1, 0.15).Unit, 0.55 + o[2] * 0.4, i == 3 and 1 or 2)
				end
				for _, o in { { 0.62, 0.56, 0.5 }, { -0.66, 0.5, 0.9 } } do
					local smp = K:at(shell, o[3])
					local pos, nrm = K:surface(smp, rad(o[1] * 70), -0.02)
					K:block("Body", "Anemone", CFrame.new(pos + nrm * 0.08), Vector3.new(0.3, 0.16, 0.3))
					for k = 0, 5 do
						local a = k / 6 * math.pi * 2
						K:chain("Body", { "Anemone", "CoralTip" }, pos + nrm * 0.16, (nrm + Vector3.new(math.cos(a), 0, math.sin(a)) * 0.6).Unit, Vector3.yAxis, { n = 2, len = 0.26, w0 = 0.05, w1 = 0.035, bend = -20, tip = false })
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
