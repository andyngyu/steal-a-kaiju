local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Epic / ice: a towering yeti. Tall and upright, wide and shaggy, with long frost-white fur hanging in
-- icicle-tipped strands, long arms swinging down to its knees, a dark slate-blue face and chest, ice crystals
-- bursting from its shoulders, cyan eyes, icy fangs, and frosty breath hanging in front of its mouth.
local HEAD = CFrame.new(0, 4.34, -0.84) * CFrame.Angles(rad(-2), 0, 0)
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
		Skin = "36435A",
		SkinDark = "252F42",
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		IceGlow = { "4FD2FF", Neon = true },
		Breath = { "EAF6FF", Transparency = 0.45 },
		Tooth = { "E0F3FF", Material = "Ice" },
		Mouth = "3A1C2C",
		Eye = { "55E0FF", Neon = true },
		Socket = "0C1220",
		Claw = "22303E",
		ClawTip = "D6EEFF",
	},
	Joints = {
		Head = { 0, 4.06, -0.5 },
		Jaw = H.apeHeadJoint(HEAD, HS, H.APEHEAD_HINGE),
		ArmL = { 1.34, 3.96, -0.3 },
		ArmR = { -1.34, 3.96, -0.3 },
		LegL = { 0.7, 2.3, 0.34 },
		LegR = { -0.7, 2.3, 0.34 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local function fur(th, ring)
			local a = math.deg(math.abs(th))
			if a < 120 then
				return ring % 2 == 0 and "Fur" or (a < 50 and "FurDark" or "FurLight")
			end
			return nil
		end
		local shag = { t = 0.12, lift = 22, jitter = 4, sink = 0.4, overlap = 1.2 }
		local function shaggy(w, n, l)
			local t = table.clone(shag)
			t.w, t.n, t.l = w, n, l
			return t
		end
		-- an upright torso, shoulders high over the hips
		local torso = K:tube("Body", {
			{ 0, 3.9, -0.36, rx = 1.2, ru = 1.0, rd = 1.06 },
			{ 0, 3.32, -0.08, rx = 1.24, ru = 1.02, rd = 1.1 },
			{ 0, 2.68, 0.14, rx = 1.1, ru = 0.94, rd = 0.96 },
			{ 0, 2.2, 0.28, rx = 0.92, ru = 0.82, rd = 0.8 },
		}, { step = 0.46, core = "Fur", coreScale = 0.86, tile = shaggy(0.7, 7, 0.76), color = fur })
		local mantle = K:tube("Body", {
			{ -1.26, 4.06, -0.3, rx = 0.62, ru = 0.7, rd = 0.56 },
			{ 0, 4.26, -0.26, rx = 0.76, ru = 0.76, rd = 0.62 },
			{ 1.26, 4.06, -0.3, rx = 0.62, ru = 0.7, rd = 0.56 },
		}, { step = 0.42, ref = Vector3.zAxis, core = "Fur", coreScale = 0.9, tile = shaggy(0.66, 7, 0.7), color = function(th, ring)
			return math.abs(th) < rad(135) and (ring % 2 == 0 and "FurLight" or "Fur") or nil
		end })
		-- dark slate chest
		for _, x in { 1, -1 } do
			K:tile("Body", "Skin", K:at(torso, 0.2), rad(180 - 32) * x, 1.0, 0.94, 0.16, 6, 0.5, 0.4)
		end
		K:tile("Body", "SkinDark", K:at(torso, 0.85), math.pi, 0.9, 0.6, 0.14, 6, 0.5, 0.4)
		-- shaggy strands hanging off the shoulders, flanks and back, every one tipped with an icicle
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
		strands("Body", torso, { rad(72), rad(-72), rad(110), rad(-110) }, 0.4, torso.total - 0.2, 0.56, 0.62)
		strands("Body", mantle, { rad(70), rad(-70) }, 0.2, mantle.total - 0.2, 0.42, 0.5)
		-- ice crystals bursting from the shoulders
		local ICE = { "Ice", "IceDeep", "IceGlow", "Ice" }
		for _, x in { 1, -1 } do
			local cap = K:at(mantle, x == 1 and mantle.total - 0.2 or 0.2)
			local pos, nrm = K:surface(cap, rad(-15), 0.06)
			H.crystal(K, "Body", ICE, pos, (nrm + Vector3.new(0.3 * x, 0.4, 0.2)).Unit, 0.95, 5, 30)
		end
		for _, x in { 1, -1 } do
			-- long arms hanging to the knees, shaggy fringes with icicles, fists armoured in ice
			local g = x == 1 and "ArmL" or "ArmR"
			local arm, fc = H.apeArm(K, g, x, {
				pts = { { 1.34, 3.96, -0.3, 0.5 }, { 1.8, 2.76, -0.3, 0.44 }, { 1.7, 1.5, -0.54, 0.44 } },
				fist = Vector3.new(0.74, 0.7, 0.74),
				fistY = 1.08,
				fistKey = "Skin",
				knuckleKey = "SkinDark",
				fur = shaggy(0.56, 6, 0.62),
				foreFur = shaggy(0.52, 6, 0.6),
				color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurLight" end,
			})
			strands(g, arm[1], { rad(150) * x }, 0.3, arm[1].total - 0.1, 0.42, 0.5)
			strands(g, arm[2], { rad(150) * x }, 0.2, arm[2].total - 0.2, 0.44, 0.44)
			for f = -1, 1 do
				H.crystal(K, g, { "Ice", "IceDeep" }, fc * Vector3.new(f * 0.24, 0.2, -0.34), fc:VectorToWorldSpace(Vector3.new(0, 0.4, -1)), 0.32, 2, 14)
			end
			local lg = x == 1 and "LegL" or "LegR"
			local leg = H.limb(K, lg, {
				{ 0.7 * x, 2.32, 0.34, 0.56 },
				{ 0.96 * x, 1.32, 0.16, 0.46 },
				{ 0.9 * x, 0.4, 0.5, 0.34 },
			}, { step = 0.46, cores = { "Fur", "FurDark" }, tiles = { shaggy(0.64, 6, 0.66), shaggy(0.54, 5, 0.54) }, color = function(_, ring) return ring % 2 == 0 and "Fur" or "FurLight" end })
			K:block(lg, "SkinDark", CFrame.new(0.92 * x, 0.15, 0.3) * CFrame.Angles(0, rad(-10 * x), 0), Vector3.new(0.62, 0.3, 0.9))
		end
		H.apeHead(K, {
			frame = HEAD,
			scale = HS,
			face = "Skin",
			faceDark = "SkinDark",
			brow = "FurDark",
			crest = { "Fur", "FurLight", "Fur" },
			open = 16,
			extras = function(K, cf, p, v)
				-- a shaggy frosted hood of fur, and frosty breath hanging in front of the mouth
				for k = -2, 2 do
					K:chain("Head", { "FurLight", "Fur" }, p(k * 0.2, 0.62, -0.5), v(k * 0.2, 0.3, -1), v(1, 0, 0), { n = 2, len = 0.3, w0 = 0.18, w1 = 0.12, bend = 30, tip = false })
				end
				for i, o in { { 0, -0.36, -1.32, 0.26 }, { 0.14, -0.5, -1.56, 0.2 }, { -0.1, -0.6, -1.76, 0.16 }, { 0.06, -0.72, -1.94, 0.12 } } do
					K:block("Head", "Breath", cf(o[1], o[2], o[3], K:rand(0, 40), K:rand(0, 90), K:rand(0, 40)), Vector3.new(o[4], o[4], o[4]))
				end
				K:block("Head", "IceGlow", cf(0, -0.3, -1.12), Vector3.new(0.3, 0.04, 0.04))
			end,
		})
	end,
}
