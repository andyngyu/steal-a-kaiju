local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Common / ice: a frost dire wolf, stalking. Shoulders high and the head held low and forward, a
-- deep chest over a tucked waist, long legs, a thick ruff of frosted fur and ice crystals round the neck, hackles
-- raised down the spine in spikes of fur and ice, a heavy brush tail. Face: a long wedge muzzle wrinkled in a snarl,
-- lips drawn back off long icy fangs, a black nose, slanted cyan eyes under a hard brow, tall ears pinned back.
local HEAD = CFrame.new(0, 1.86, -1.46) * CFrame.Angles(rad(-4), 0, 0)
local HINGE = Vector3.new(0, -0.1, -0.14)
local HS = 1.12

local function hj(v)
	return HEAD.Position + (HEAD * v - HEAD.Position) * HS
end

return {
	Seed = 89,
	Vary = 0.05,
	Gait = "Trot",
	Emotes = { "Look", "PlayBow", "Paw" },
	Palette = {
		Fur = "AAB8C7",
		FurDark = "6E7F95",
		FurLight = "D7E0E9",
		Back = "3E4C60",
		Skin = "1C2430",
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		IceGlow = { "4FD2FF", Neon = true },
		Tooth = { "E8F6FF", Material = "Ice" },
		Mouth = "3A1C2C",
		Eye = { "55E0FF", Neon = true },
		Socket = "0C1220",
		Claw = "22303E",
		ClawTip = "D6EEFF",
	},
	Joints = {
		Head = { 0, 1.9, -0.82 },
		Jaw = hj(HINGE),
		EarL = hj(Vector3.new(0.2, 0.3, -0.26)),
		EarR = hj(Vector3.new(-0.2, 0.3, -0.26)),
		LegFL = { 0.38, 1.72, -0.72 },
		LegFR = { -0.38, 1.72, -0.72 },
		LegBL = { 0.38, 1.66, 0.74 },
		LegBR = { -0.38, 1.66, 0.74 },
		Tail = { 0, 1.68, 0.98 },
	},
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		local function fur(th, ring)
			local a = math.deg(math.abs(th))
			if a < 40 then
				return "Back"
			elseif a < 70 then
				return ring % 2 == 0 and "FurDark" or "Fur"
			elseif a < 130 then
				return "Fur"
			end
			return "FurLight"
		end
		local function limb(_, ring)
			return ring % 2 == 0 and "Fur" or "FurDark"
		end
		local ICE = { "Ice", "IceDeep", "IceGlow", "Ice" }
		-- a deep chest under high shoulders, a tucked waist
		local body = K:tube("Body", {
			{ 0, 1.86, -0.8, rx = 0.52, ru = 0.56, rd = 0.68 },
			{ 0, 1.78, -0.14, rx = 0.52, ru = 0.5, rd = 0.56 },
			{ 0, 1.66, 0.5, rx = 0.42, ru = 0.4, rd = 0.34 },
			{ 0, 1.66, 0.94, rx = 0.42, ru = 0.42, rd = 0.36 },
		}, { step = 0.34, core = "Fur", coreScale = 0.96, tile = H.fur(0.44, 8, 0.52, 18), color = fur })
		-- the neck reaching forward and down from the shoulders, wrapped in a thick frosted ruff
		local neck = K:tube("Head", {
			{ 0, 1.96, -1.36, rx = 0.36, ru = 0.36, rd = 0.38 },
			{ 0, 2.02, -1.08, rx = 0.5, ru = 0.5, rd = 0.52 },
			{ 0, 1.92, -0.74, rx = 0.58, ru = 0.6, rd = 0.62 },
		}, { step = 0.22, core = "Fur", coreScale = 0.96, tile = H.fur(0.46, 9, 0.56, 26), color = function(th, ring)
			return math.abs(th) < rad(60) and (ring % 2 == 0 and "FurDark" or "Back") or (ring % 2 == 0 and "FurLight" or "Fur")
		end })
		H.crystalRidge(K, "Head", neck, { from = 0.05, to = neck.total - 0.05, every = 0.2, size = 0.44, count = 3, keys = ICE, lean = 40 })
		-- hackles raised down the spine: spikes of dark fur tipped with ice, crystals between them
		for s = 0.1, body.total * 0.62, 0.22 do
			local smp = K:at(body, s)
			local u = s / body.total
			for _, th in { -14, 14 } do
				local pos, nrm = K:surface(smp, rad(th), 0.02)
				local d = (nrm + smp.T * 0.7).Unit
				local l = 0.42 * (1 - u) + 0.14
				K:chain("Body", { "Back", "FurDark" }, pos, d, smp.R, { n = 2, len = l, w0 = 0.14, w1 = 0.09, bend = 0, tip = false, depth = 1.3 })
				H.point(K, "Body", "Ice", pos + d * (l + 0.12), d, 0.1)
			end
		end
		H.crystalRidge(K, "Body", body, { from = 0.2, to = body.total * 0.5, every = 0.4, size = function(u) return 0.46 * (1 - u) + 0.2 end, count = 2, keys = ICE, lean = 30 })
		local tail = K:tube("Tail", {
			{ 0, 1.7, 0.92, rx = 0.22, ru = 0.22 },
			{ -0.04, 1.56, 1.5, rx = 0.34, ru = 0.34 },
			{ -0.14, 1.28, 1.98, rx = 0.3, ru = 0.3 },
			{ -0.24, 1.0, 2.24, rx = 0.13, ru = 0.13 },
		}, { step = 0.26, core = "FurDark", coreScale = 0.95, tile = H.fur(0.38, 6, 0.48, 24), color = function(th, ring) return math.abs(th) < rad(50) and "Back" or (ring % 2 == 0 and "Fur" or "FurLight") end })
		H.point(K, "Tail", "Ice", Vector3.new(-0.3, 0.86, 2.36), Vector3.new(-0.2, -0.7, 0.6), 0.14)
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.38 * x, 1.74, -0.72, 0.3 },
				{ 0.44 * x, 1.04, -0.6, 0.21 },
				{ 0.42 * x, 0.36, -0.76, 0.15 },
			}, { step = 0.26, cores = { "Fur", "FurDark" }, tiles = { H.fur(0.34, 5, 0.42, 16), nil }, color = limb, foot = { size = Vector3.new(0.32, 0.2, 0.38), key = "FurDark" }, toes = 4, claw = { len = 0.18, w = 0.05 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.38 * x, 1.7, 0.74, 0.36 },
				{ 0.44 * x, 1.14, 0.42, 0.27 },
				{ 0.44 * x, 0.62, 0.92, 0.16 },
				{ 0.44 * x, 0.2, 0.84, 0.13 },
			}, { step = 0.26, cores = { "Fur", "FurDark", "FurDark" }, tiles = { H.fur(0.36, 5, 0.44, 16), nil, nil }, color = limb, foot = { size = Vector3.new(0.32, 0.2, 0.4), key = "FurDark" }, toes = 4, claw = { len = 0.18, w = 0.05 } })
		end

		-- head: a long wedge muzzle wrinkled in a snarl, slanted eyes under a hard brow, ears pinned back
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:scaled(HEAD.Position, HS, function()
			K:block("Head", "Fur", hcf(0, 0.1, -0.22), Vector3.new(0.64, 0.5, 0.56))
			K:block("Head", "FurDark", hcf(0, 0.3, -0.2, -6, 0, 0), Vector3.new(0.48, 0.12, 0.5))
			K:block("Head", "FurDark", hcf(0, 0.25, -0.5, -16, 0, 0), Vector3.new(0.24, 0.14, 0.3))
			-- the muzzle: a tapering wedge, a dark bridge wrinkled in a snarl, a black nose
			K:block("Head", "Fur", hcf(0, 0.02, -0.8), Vector3.new(0.4, 0.26, 0.56))
			K:block("Head", "Fur", hcf(0, -0.01, -1.0), Vector3.new(0.3, 0.2, 0.24))
			K:block("Head", "Fur", hcf(0, 0.04, -0.84, 0, 0, 45), Vector3.new(0.26, 0.26, 0.52))
			K:block("Head", "FurDark", hcf(0, 0.16, -0.84, -8, 0, 0), Vector3.new(0.28, 0.08, 0.54))
			for k = 0, 2 do
				K:block("Head", "Back", hcf(0, 0.205 - k * 0.012, -0.66 - k * 0.1, -8, 0, 0), Vector3.new(0.26 - k * 0.02, 0.03, 0.035))
			end
			K:block("Head", "Skin", hcf(0, 0.1, -1.1, -14, 0, 0), Vector3.new(0.17, 0.09, 0.12))
			K:block("Head", "Mouth", hcf(0, -0.13, -0.74), Vector3.new(0.32, 0.04, 0.56))
			for _, x in { 1, -1 } do
				K:block("Head", "FurLight", hcf(0.33 * x, -0.06, -0.24, 0, -16 * x, 10 * x), Vector3.new(0.16, 0.38, 0.44))
				-- a hard brow slanting down over narrow eyes
				K:block("Head", "Back", hcf(0.2 * x, 0.25, -0.56, -6, -14 * x, 20 * x), Vector3.new(0.24, 0.08, 0.2))
				H.eye(K, "Head", hcf(0.22 * x, 0.16, -0.6, 0, -22 * x, 16 * x), 0.16, 0.05)
				-- lips drawn back off the teeth, long icy fangs
				K:block("Head", "Skin", hcf(0.19 * x, -0.1, -0.76, 0, 3 * x, 0), Vector3.new(0.04, 0.07, 0.54))
				H.fang(K, "Head", "Tooth", hp(0.14 * x, -0.12, -0.98), hv(0, -1, -0.1), 0.2, 0.06)
				for k = 0, 2 do
					K:spike("Head", "Tooth", hp(0.17 * x, -0.12, -0.5 - k * 0.12), hv(0, -1, 0), hv(1, 0, 0), 0.06, 0.04)
				end
				-- tall ears pinned back
				local g = x == 1 and "EarL" or "EarR"
				K:chain(g, { "FurDark", "Back" }, hp(0.2 * x, 0.3, -0.26), hv(0.32 * x, 1, 0.42), hv(0, 0, 1), { n = 2, len = 0.54, w0 = 0.24, w1 = 0.12, depth = 0.6, bend = 0 })
			end
			local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-20), 0, 0)
			K:block("Jaw", "Fur", JAW * CFrame.new(0, -0.07, -0.42), Vector3.new(0.34, 0.14, 0.76))
			K:block("Jaw", "FurLight", JAW * CFrame.new(0, -0.15, -0.36), Vector3.new(0.3, 0.04, 0.6))
			K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.46), Vector3.new(0.28, 0.03, 0.64))
			for _, x in { 1, -1 } do
				H.fang(K, "Jaw", "Tooth", JAW * Vector3.new(0.11 * x, 0, -0.72), JAW:VectorToWorldSpace(Vector3.new(0, 1, -0.05)).Unit, 0.15, 0.055)
				for k = 0, 2 do
					K:spike("Jaw", "Tooth", JAW * Vector3.new(0.14 * x, 0, -0.24 - k * 0.12), JAW:VectorToWorldSpace(Vector3.yAxis), JAW:VectorToWorldSpace(Vector3.xAxis), 0.05, 0.04)
				end
			end
		end)
	end,
}
