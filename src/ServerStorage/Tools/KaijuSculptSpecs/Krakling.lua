local rad = math.rad
local H = require(script.Parent.Helpers)

-- Sunken Abyss / Epic / water: the krakling, a young kraken. A great domed mantle swept up and back, deep navy
-- mottled with sunk glowing spots and fading to teal at the sides, over a skirt of eight thick tentacles: four walk on
-- curled tips, two rear up in S-curves ready to strike, two trail behind. Their undersides are pale coral with rows of
-- suckers glowing cyan at the centre. Face: big eyes under heavy bony brows, glowing cyan with a dark slit, and a
-- hooked black beak between the front tentacles.
return {
	Seed = 523,
	Vary = 0.04,
	Scale = 1.15,
	Gait = "Amble",
	Emotes = { "Look", "Wiggle" },
	Palette = {
		Hide = { "23506A", Material = "Slate" },
		HideDark = { "15324A", Material = "Slate" },
		HideLight = { "4E8496", Material = "Slate" },
		Back = { "0E2034", Material = "Slate" },
		Under = "E8A0A8",
		Under2 = "D08890",
		Sucker = "F2C8C8",
		Brow = { "0E2034", Material = "Slate" },
		Beak = "1E1614",
		BeakLight = "4A3A34",
		Glow = { "1AA6D8", Neon = true },
		SeamLip = { "08141C", Material = "Slate" },
		Mouth = "2A0E18",
		Eye = { "22C4E8", Neon = true },
		Socket = "060C10",
	},
	Joints = {
		Head = { 0, 1.9, -0.1 },
		Jaw = { 0, 1.5, -1.0 },
		LegFL = { 0.5, 1.5, -0.5 },
		LegFR = { -0.5, 1.5, -0.5 },
		LegBL = { 0.55, 1.45, 0.4 },
		LegBR = { -0.55, 1.45, 0.4 },
		ArmL = { 0.6, 1.8, -0.56 },
		ArmR = { -0.6, 1.8, -0.56 },
		Tail = { 0, 1.4, 0.7 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		-- a tentacle: thick at the root tapering to a curled tip, dark on top and pale coral underneath, rows of suckers
		-- down the underside each with a glowing centre
		local function tentacle(group, pts, r0, suckers)
			local nodes = {}
			for i, p in pts do
				local f = (i - 1) / (#pts - 1)
				local r = r0 + (0.07 - r0) * f ^ 0.9
				nodes[i] = { p[1], p[2], p[3], rx = r, ru = r * 0.92, rd = r * 0.9 }
			end
			local smps = K:tube(group, nodes, { step = 0.3, core = "Hide", coreScale = 0.92, tile = { w = 0.34, n = 4, l = 0.38, t = 0.08, lift = 3, jitter = 1, sink = 0.5, overlap = 1.12 }, belly = { key = "Under", key2 = "Under2", arc = 64, t = 0.08, wide = 1.1 }, color = function(th)
				return math.abs(th) < rad(50) and "HideDark" or "Hide"
			end, trim = 0.05 })
			if suckers then
				local k = 0
				for s = 0.2, smps.total - 0.3, 0.3 do
					local smp = K:at(smps, s)
					local sz = math.max(0.07, smp.rx * 0.5)
					do
						local side = k % 2 == 0 and 1 or -1
						local pos, nrm = K:surface(smp, math.pi + side * rad(20), -0.02)
						local F = CFrame.fromMatrix(pos, nrm:Cross(smp.T).Unit, nrm)
						K:block(group, "Sucker", F, Vector3.new(sz, 0.05, sz))
						K:block(group, "SeamLip", F * CFrame.new(0, 0.012, 0), Vector3.new(sz * 0.5, 0.05, sz * 0.5))
						K:block(group, "Glow", F * CFrame.new(0, 0.016, 0), Vector3.new(sz * 0.24, 0.05, sz * 0.24))
					end
					k += 1
				end
			end
			return smps
		end
		for _, x in { 1, -1 } do
			-- walking tentacles, out and down to curled tips on the ground
			tentacle(x == 1 and "LegFL" or "LegFR", { { 0.5 * x, 1.5, -0.5 }, { 1.3 * x, 1.2, -1.1 }, { 1.9 * x, 0.5, -1.5 }, { 2.3 * x, 0.14, -1.9 }, { 2.56 * x, 0.3, -2.22 }, { 2.46 * x, 0.5, -2.36 } }, 0.38, true)
			tentacle(x == 1 and "LegBL" or "LegBR", { { 0.55 * x, 1.45, 0.4 }, { 1.4 * x, 1.1, 0.9 }, { 2.0 * x, 0.4, 1.3 }, { 2.4 * x, 0.14, 1.75 }, { 2.66 * x, 0.3, 2.06 }, { 2.56 * x, 0.5, 2.2 } }, 0.38, true)
			-- tentacles rearing up in S-curves, curling in at the top
			tentacle(x == 1 and "ArmL" or "ArmR", { { 0.6 * x, 1.8, -0.56 }, { 1.5 * x, 2.36, -0.96 }, { 1.92 * x, 3.3, -0.96 }, { 1.84 * x, 4.2, -0.66 }, { 1.44 * x, 4.52, -0.36 }, { 1.16 * x, 4.32, -0.24 } }, 0.34, true)
			-- trailing tentacles behind
			tentacle("Tail", { { 0.3 * x, 1.4, 0.7 }, { 0.62 * x, 0.9, 1.6 }, { 0.86 * x, 0.32, 2.5 }, { 1.24 * x, 0.14, 3.2 }, { 1.56 * x, 0.34, 3.56 } }, 0.3, false)
		end
		-- the skirt webbing the tentacle roots together
		K:block("Body", "Hide", CFrame.new(0, 1.42, 0), Vector3.new(1.5, 0.6, 1.7))
		K:block("Body", "Hide", CFrame.new(0, 1.42, 0) * CFrame.Angles(0, rad(45), 0), Vector3.new(1.5, 0.56, 1.5))
		K:block("Body", "Under", CFrame.new(0, 1.1, 0) * CFrame.Angles(0, rad(22), 0), Vector3.new(1.3, 0.1, 1.3))

		-- the mantle, swept up and back from the eyes
		local mantle = K:tube("Head", {
			{ 0, 1.8, -0.1, rx = 0.94, ru = 0.84, rd = 0.8 },
			{ 0, 2.5, 0.42, rx = 1.16, ru = 1.06, rd = 1.0 },
			{ 0, 3.1, 1.08, rx = 1.0, ru = 0.94, rd = 0.9 },
			{ 0, 3.42, 1.66, rx = 0.62, ru = 0.58, rd = 0.56 },
			{ 0, 3.5, 2.02, rx = 0.24, ru = 0.22, rd = 0.22 },
		}, { step = 0.32, ref = Vector3.xAxis, core = "HideDark", coreScale = 0.9, tile = { w = 0.56, t = 0.12, lift = 4, jitter = 2, sink = 0.5, overlap = 1.1 }, color = function(th, ring)
			local a = math.deg(math.abs(th))
			if ring % 3 == 0 then
				return "Back"
			end
			return a < 60 and "HideDark" or (a < 130 and "Hide" or "HideLight")
		end })
		-- sunk glowing spots mottling the mantle
		for s = 0.5, mantle.total - 0.4, 0.34 do
			local smp = K:at(mantle, s)
			for _, th in { -100, -60, -24, 24, 60, 100 } do
				if K:rand(0, 1) < 0.6 then
					local pos, nrm = K:surface(smp, rad(th + K:rand(-12, 12)), -0.05)
					local F = CFrame.fromMatrix(pos, nrm:Cross(smp.T).Unit, nrm) * CFrame.Angles(0, K:rand(0, 1.5), 0)
					local sz = K:rand(0.14, 0.22)
					K:block("Head", "SeamLip", F, Vector3.new(sz, 0.06, sz))
					K:block("Head", "Glow", F * CFrame.new(0, 0.005, 0), Vector3.new(sz * 0.45, 0.06, sz * 0.45))
				end
			end
		end
		-- a ridge of knobs down the top of the mantle
		K:ridge("Head", mantle, { from = 0.5, to = mantle.total - 0.2, every = 0.28, height = 0.18, thick = 0.14, key = "Back", tip = "HideDark", lean = 20, sink = 0.85 })
		for _, x in { 1, -1 } do
			-- the eyes: bulging, under heavy bony brows, glowing with a dark slit
			local E = CFrame.lookAt(Vector3.new(0.72 * x, 2.12, -0.82), Vector3.new(1.5 * x, 2.06, -1.7))
			K:block("Head", "Hide", E * CFrame.new(0, 0, 0.12), Vector3.new(0.6, 0.56, 0.4))
			K:block("Head", "Socket", E * CFrame.new(0, 0, -0.06), Vector3.new(0.46, 0.42, 0.1))
			K:block("Head", "Eye", E * CFrame.new(0, 0, -0.1), Vector3.new(0.36, 0.32, 0.08))
			K:block("Head", "Socket", E * CFrame.new(0, 0, -0.13), Vector3.new(0.3, 0.06, 0.04))
			K:block("Head", "Brow", E * CFrame.new(0.04 * x, 0.32, -0.04) * CFrame.Angles(rad(-14), 0, rad(-14 * x)), Vector3.new(0.66, 0.16, 0.42))
			K:spike("Head", "Brow", E * Vector3.new(0.26 * x, 0.38, 0.1), (Vector3.new(0.4 * x, 0.8, 0.3)).Unit, Vector3.zAxis, 0.24, 0.1)
		end
		-- the hooked beak between the front tentacles (upper in the head, lower on the jaw)
		-- a dark face between the eyes, the beak under it
		K:block("Head", "HideDark", CFrame.new(0, 1.9, -0.9) * CFrame.Angles(rad(-10), 0, 0), Vector3.new(0.9, 0.7, 0.3))
		K:block("Head", "Mouth", CFrame.new(0, 1.48, -1.0), Vector3.new(0.5, 0.36, 0.2))
		H.curve(K, "Head", { "BeakLight", "Beak", "Beak" }, { Vector3.new(0, 1.8, -1.0), Vector3.new(0, 1.74, -1.28), Vector3.new(0, 1.5, -1.4), Vector3.new(0, 1.26, -1.3) }, 0.36, 0.08, 0.1)
		H.curve(K, "Jaw", { "BeakLight", "Beak" }, { Vector3.new(0, 1.28, -1.0), Vector3.new(0, 1.22, -1.18), Vector3.new(0, 1.34, -1.28) }, 0.28, 0.07, 0.1)
	end,
}
