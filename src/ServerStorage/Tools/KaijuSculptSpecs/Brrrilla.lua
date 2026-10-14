local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Epic / ice: the yeti. A round, top-heavy hulk with a slight hunch: a great domed mass of shaggy
-- frost-white fur over the shoulders tapering to small hips and short legs, long arms reaching almost to the ground,
-- knuckles frozen into chunks of ice, icicle-tipped strands hanging off its flanks. Face: light blue-grey skin, a
-- frosty brow hung with icicles over clearly glowing cyan eyes, a wide flat nose, a broad muzzle, icy fangs, icicles
-- hanging from the jaw, frosty breath.
local HEAD = CFrame.new(0, 3.66, -1.5) * CFrame.Angles(rad(-4), 0, 0)
local HS = 1.12

return {
	Seed = 73,
	Vary = 0.04,
	Gait = "Knuckle",
	Emotes = { "Look", "ChestBeat" },
	Palette = {
		Fur = "C3CFDB",
		FurDark = "94A6B9",
		FurLight = "E6EDF4",
		Skin = "8496AE",
		SkinDark = "5E6F88",
		Nose = "44536A",
		Frost = "BCD6EA",
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		IceGlow = { "4FD2FF", Neon = true },
		Breath = { "EAF6FF", Transparency = 0.45 },
		Tooth = { "E0F3FF", Material = "Ice" },
		Mouth = "3A1C2C",
		Eye = { "3FE6FF", Neon = true },
		Socket = "0C1220",
		Claw = "22303E",
		ClawTip = "D6EEFF",
	},
	Joints = {
		Head = { 0, 3.64, -1.06 },
		Jaw = H.apeHeadJoint(HEAD, HS, H.GHEAD_HINGE),
		ArmL = { 1.42, 3.9, -0.56 },
		ArmR = { -1.42, 3.9, -0.56 },
		LegL = { 0.68, 2.16, 0.46 },
		LegR = { -0.68, 2.16, 0.46 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local function fur(th, ring)
			local a = math.deg(math.abs(th))
			if a < 128 then
				return ring % 2 == 0 and "Fur" or (a < 50 and "FurDark" or "FurLight")
			end
			return nil
		end
		local function shaggy(w, n, l)
			return { w = w, n = n, l = l, t = 0.12, lift = 20, jitter = 3, sink = 0.4, overlap = 1.18 }
		end
		-- a round, top-heavy body: a great domed chest and shoulders hunched forward, tapering to small hips
		local torso = K:tube("Body", {
			{ 0, 3.62, -0.62, rx = 1.3, ru = 1.04, rd = 1.12 },
			{ 0, 3.3, -0.04, rx = 1.34, ru = 1.08, rd = 1.1 },
			{ 0, 2.74, 0.36, rx = 1.06, ru = 0.9, rd = 0.9 },
			{ 0, 2.22, 0.52, rx = 0.8, ru = 0.68, rd = 0.64 },
		}, { step = 0.4, core = "Fur", coreScale = 0.86, tile = shaggy(0.66, 8, 0.66), color = fur })
		local mantle = K:tube("Body", {
			{ -1.2, 3.96, -0.52, rx = 0.78, ru = 0.78, rd = 0.66 },
			{ 0, 4.3, -0.42, rx = 0.9, ru = 0.86, rd = 0.7 },
			{ 1.2, 3.96, -0.52, rx = 0.78, ru = 0.78, rd = 0.66 },
		}, { step = 0.4, ref = Vector3.zAxis, core = "Fur", coreScale = 0.9, tile = shaggy(0.64, 7, 0.66), color = function(th, ring)
			return th > rad(-118) and (ring % 2 == 0 and "FurLight" or "Fur") or nil
		end })
		-- a thick neck of fur hunched down into the head
		for _, o in { { 0, 4.06, -0.98, 1.1, 0.74, 0.86, 30, "Fur" }, { 0, 3.84, -1.18, 0.92, 0.6, 0.6, 24, "FurLight" } } do
			K:block("Body", o[8], CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(rad(o[7]), 0, 0), Vector3.new(o[4], o[5], o[6]))
			K:block("Body", o[8], CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(rad(o[7]), 0, rad(45)), Vector3.new(o[5] * 1.15, o[5] * 1.15, o[6] * 0.96))
		end
		-- a bare blue-grey chest
		for _, x in { 1, -1 } do
			K:tile("Body", "Skin", K:at(torso, 0.24), rad(180 - 30) * x, 0.98, 0.92, 0.16, 6, 0.5, 0.4)
		end
		K:tile("Body", "SkinDark", K:at(torso, 0.9), math.pi, 0.86, 0.56, 0.14, 6, 0.5, 0.4)
		-- shaggy strands hanging off the flanks and shoulders, every one tipped with an icicle
		local function strands(group, samples, thetas, from, to, every, len)
			for s = from, to, every do
				local smp = K:at(samples, s)
				for i, th in thetas do
					local pos, nrm = K:surface(smp, th + rad(K:rand(-8, 8)), 0.04)
					local d = (nrm * 0.25 + Vector3.new(0, -1, 0)).Unit
					local l = len * K:rand(0.8, 1.2)
					K:chain(group, { i % 2 == 0 and "FurLight" or "Fur", "FurDark" }, pos, d, smp.T, { n = 2, len = l, w0 = 0.2, w1 = 0.13, bend = 0, tip = false, depth = 1.4 })
					H.point(K, group, i % 3 == 0 and "IceDeep" or "Ice", pos + d * (l + 0.18), d, 0.13)
				end
			end
		end
		strands("Body", torso, { rad(80), rad(-80) }, 0.5, torso.total - 0.3, 0.55, 0.55)
		strands("Body", mantle, { rad(-70) }, 0.3, mantle.total - 0.3, 0.6, 0.45)
		-- frost crystals breaking out of the shoulder hump
		local ICE = { "Ice", "IceDeep", "IceGlow", "Ice" }
		for _, x in { 1, -1 } do
			local cap = K:at(mantle, x == 1 and mantle.total - 0.5 or 0.5)
			local pos, nrm = K:surface(cap, rad(25), 0.06)
			H.crystal(K, "Body", ICE, pos, (nrm + Vector3.new(0.3 * x, 0.6, 0.3)).Unit, 0.7, 4, 28)
		end
		for _, x in { 1, -1 } do
			-- long arms reaching almost to the ground, the knuckles frozen into chunks of ice
			local g = x == 1 and "ArmL" or "ArmR"
			local arm, fc = H.apeArm(K, g, x, {
				pts = { { 1.42, 3.9, -0.56, 0.54 }, { 1.98, 2.5, -0.58, 0.46 }, { 1.86, 0.92, -0.82, 0.46 } },
				fist = Vector3.new(0.76, 0.72, 0.76),
				fistY = 0.44,
				fistKey = "Skin",
				knuckleKey = "SkinDark",
				fur = shaggy(0.56, 6, 0.62),
				foreFur = shaggy(0.54, 6, 0.6),
				color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurLight" end,
			})
			strands(g, arm[1], { rad(100) * x }, 0.3, arm[1].total - 0.2, 0.5, 0.42)
			for i, o in { { -0.24, 0.0, -0.4, 0.36, 20, 30 }, { 0.1, 0.06, -0.44, 0.42, -15, 50 }, { 0.32, -0.04, -0.36, 0.32, 35, 10 }, { -0.02, 0.32, -0.24, 0.34, 40, -20 }, { 0.3, 0.3, -0.16, 0.26, -30, 25 } } do
				K:block(g, i % 2 == 0 and "IceDeep" or "Ice", fc * CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(rad(o[5]), rad(o[6]), rad(o[5] * 0.6)), Vector3.new(o[4], o[4] * 0.9, o[4]))
			end
			H.crystal(K, g, { "Ice", "IceGlow" }, fc * Vector3.new(0.05, 0.36, -0.2), fc:VectorToWorldSpace(Vector3.new(0, 0.6, -1)), 0.34, 2, 18)
			local lg = x == 1 and "LegL" or "LegR"
			H.limb(K, lg, {
				{ 0.68 * x, 2.16, 0.46, 0.56 },
				{ 0.94 * x, 1.24, 0.2, 0.46 },
				{ 0.88 * x, 0.4, 0.5, 0.34 },
			}, { step = 0.44, cores = { "Fur", "FurDark" }, tiles = { shaggy(0.6, 6, 0.64), nil }, color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurLight" end })
			K:block(lg, "SkinDark", CFrame.new(0.9 * x, 0.15, 0.3) * CFrame.Angles(0, rad(-10 * x), 0), Vector3.new(0.62, 0.3, 0.9))
		end
		H.gorillaHead(K, {
			frame = HEAD,
			scale = HS,
			keys = { fur = "Fur", furDark = "FurDark", face = "Skin", faceDark = "SkinDark", brow = "Frost", nose = "Nose" },
			crest = { "Fur", "FurLight", "Fur", "Ice" },
			crestH = 0.85,
			open = 16,
			browTilt = 10,
			eye = { w = 0.17, h = 0.07, y = 0.25 },
			fangs = { upper = 0.18, lower = 0.13 },
			extras = function(K, cf, p, v, JAW)
				-- a shaggy hood of fur round the face
				for _, x in { 1, -1 } do
					K:chain("Head", { "FurLight", "Fur" }, p(0.5 * x, 0.0, -0.42), v(0.5 * x, -1, -0.4), v(0, 0, 1), { n = 2, len = 0.34, w0 = 0.2, w1 = 0.13, bend = 0, tip = false })
				end
				-- a crust of ice along the brow, icicles hanging from it (clear of the eyes) and from the jaw
				for _, x in { 1, -1 } do
					K:block("Head", "Ice", cf(0.22 * x, 0.56, -0.68, -12, -6 * x, 10 * x), Vector3.new(0.5, 0.08, 0.22))
				end
				for _, o in { { 0.4, 0.15 }, { -0.4, 0.15 }, { 0.0, 0.17 }, { 0.47, 0.1 }, { -0.47, 0.1 } } do
					H.fang(K, "Head", "Ice", p(o[1], 0.36, -0.8), v(0, -1, -0.15), o[2], 0.07)
				end
				for _, o in { { 0.0, 0.24 }, { 0.16, 0.17 }, { -0.16, 0.17 }, { 0.28, 0.12 }, { -0.28, 0.12 } } do
					H.fang(K, "Jaw", "Ice", JAW * Vector3.new(o[1], -0.26, -0.5), JAW:VectorToWorldSpace(Vector3.new(0, -1, -0.1)).Unit, o[2], 0.08)
				end
				-- frosty breath hanging in front of the mouth
				for i, o in { { 0.12, -0.62, -1.3, 0.22 }, { -0.06, -0.74, -1.52, 0.16 } } do
					K:block("Head", "Breath", cf(o[1], o[2], o[3], K:rand(0, 40), K:rand(0, 90), K:rand(0, 40)), Vector3.new(o[4], o[4], o[4]))
				end
			end,
		})
	end,
}
