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
		Hide = { "58348A", Material = "Slate" },
		HideDark = { "382262", Material = "Slate" },
		HideLight = { "8A5CB8", Material = "Slate" },
		Back = { "1A1636", Material = "Slate" },
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
		Jaw = { 0, 1.5, -0.76 },
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

		-- the mantle: a tall bulbous dome, rounded at the front and widest just above the eyes, tapering up and back
		local mantle = K:tube("Head", {
			{ 0, 1.98, -0.66, rx = 0.5, ru = 0.46, rd = 0.42 },
			{ 0, 2.24, -0.36, rx = 1.08, ru = 1.0, rd = 0.94 },
			{ 0, 2.74, 0.1, rx = 1.3, ru = 1.24, rd = 1.16 },
			{ 0, 3.26, 0.66, rx = 1.22, ru = 1.16, rd = 1.1 },
			{ 0, 3.68, 1.26, rx = 0.92, ru = 0.88, rd = 0.84 },
			{ 0, 3.94, 1.82, rx = 0.52, ru = 0.5, rd = 0.48 },
			{ 0, 4.04, 2.2, rx = 0.16, ru = 0.15, rd = 0.15 },
		}, { step = 0.3, ref = Vector3.xAxis, core = "HideDark", coreScale = 0.9, tile = { w = 0.56, t = 0.12, lift = 4, jitter = 2, sink = 0.5, overlap = 1.1 }, color = function(th, ring)
			local a = math.deg(math.abs(th))
			return a < 34 and "Back" or (a < 78 and "HideDark" or (a < 128 and "Hide" or "HideLight"))
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
		-- round off the front of the dome
		K:block("Head", "HideDark", CFrame.new(0, 2.02, -0.74), Vector3.new(0.9, 0.84, 0.3))
		K:block("Head", "HideDark", CFrame.new(0, 2.02, -0.74) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.74, 0.74, 0.28))
		for _, x in { 1, -1 } do
			-- the eyes on the sides of the dome, bulging, under heavy bony brows, glowing with a dark slit
			local pos = Vector3.new(1.06 * x, 2.26, -0.36)
			local E = CFrame.lookAt(pos, pos + Vector3.new(0.85 * x, -0.05, -0.55))
			K:block("Head", "Hide", E * CFrame.new(0, 0, 0.16), Vector3.new(0.66, 0.6, 0.44))
			K:block("Head", "Socket", E * CFrame.new(0, 0, -0.06), Vector3.new(0.5, 0.46, 0.1))
			K:block("Head", "Eye", E * CFrame.new(0, 0, -0.1), Vector3.new(0.4, 0.36, 0.08))
			K:block("Head", "Socket", E * CFrame.new(0, 0, -0.13), Vector3.new(0.34, 0.07, 0.04))
			K:block("Head", "Brow", E * CFrame.new(0, 0.36, -0.02) * CFrame.Angles(rad(-16), 0, 0), Vector3.new(0.76, 0.18, 0.5))
			K:spike("Head", "Brow", E * Vector3.new(0, 0.42, 0.16), (Vector3.new(0.5 * x, 0.8, 0.3)).Unit, Vector3.zAxis, 0.26, 0.1)
		end
		-- the hooked beak underneath the dome, between the front tentacles (upper in the head, lower on the jaw)
		K:block("Head", "Mouth", CFrame.new(0, 1.56, -0.74), Vector3.new(0.5, 0.34, 0.24))
		H.curve(K, "Head", { "BeakLight", "Beak", "Beak" }, { Vector3.new(0, 1.84, -0.8), Vector3.new(0, 1.76, -1.06), Vector3.new(0, 1.52, -1.16), Vector3.new(0, 1.3, -1.06) }, 0.36, 0.08, 0.1)
		H.curve(K, "Jaw", { "BeakLight", "Beak" }, { Vector3.new(0, 1.3, -0.76), Vector3.new(0, 1.24, -0.94), Vector3.new(0, 1.36, -1.04) }, 0.28, 0.07, 0.1)
	end,
}
