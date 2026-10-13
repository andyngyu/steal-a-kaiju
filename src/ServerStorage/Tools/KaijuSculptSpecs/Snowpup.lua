local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Common / ice: a frost wolf. Lean and long-legged, shaggy frost-grey fur with a dark saddle, a
-- ruff of fur and ice crystals bristling along its neck and spine, tall pointed ears, a snarling muzzle with icicle
-- fangs, cyan eyes, a heavy brush tail held low.
local HEAD = CFrame.new(0, 2.16, -1.26) * CFrame.Angles(rad(-10), 0, 0)
local HINGE = Vector3.new(0, -0.1, -0.12)

return {
	Seed = 89,
	Vary = 0.05,
	Gait = "Trot",
	Emotes = { "Look", "PlayBow", "Paw" },
	Palette = {
		Fur = "AFBBC8",
		FurDark = "7A8A9E",
		FurLight = "D7E0E9",
		Back = "4C5B6E",
		Skin = "263040",
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		IceGlow = { "4FD2FF", Neon = true },
		Tooth = "F2F6FA",
		Mouth = "3A1C2C",
		Eye = { "55E0FF", Neon = true },
		Socket = "0C1220",
		Claw = "22303E",
		ClawTip = "D6EEFF",
	},
	Joints = {
		Head = { 0, 1.96, -0.86 },
		Jaw = HEAD * HINGE,
		EarL = HEAD * Vector3.new(0.2, 0.34, -0.18),
		EarR = HEAD * Vector3.new(-0.2, 0.34, -0.18),
		LegFL = { 0.38, 1.7, -0.72 },
		LegFR = { -0.38, 1.7, -0.72 },
		LegBL = { 0.38, 1.66, 0.74 },
		LegBR = { -0.38, 1.66, 0.74 },
		Tail = { 0, 1.66, 0.98 },
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
		local body = K:tube("Body", {
			{ 0, 1.78, -0.76, rx = 0.5, ru = 0.52, rd = 0.62 },
			{ 0, 1.74, -0.12, rx = 0.52, ru = 0.5, rd = 0.56 },
			{ 0, 1.66, 0.52, rx = 0.44, ru = 0.42, rd = 0.38 },
			{ 0, 1.64, 0.94, rx = 0.4, ru = 0.4, rd = 0.36 },
		}, { step = 0.34, core = "Fur", coreScale = 0.96, tile = H.fur(0.42, 8, 0.5, 16), color = fur })
		local neck = K:tube("Head", {
			{ 0, 2.22, -1.16, rx = 0.32, ru = 0.34, rd = 0.36 },
			{ 0, 2.06, -0.98, rx = 0.42, ru = 0.42, rd = 0.46 },
			{ 0, 1.84, -0.7, rx = 0.52, ru = 0.52, rd = 0.58 },
		}, { step = 0.26, core = "Fur", coreScale = 0.96, tile = H.fur(0.44, 8, 0.52, 26), color = fur })
		local tail = K:tube("Tail", {
			{ 0, 1.68, 0.92, rx = 0.2, ru = 0.2 },
			{ 0.04, 1.52, 1.5, rx = 0.3, ru = 0.3 },
			{ 0.12, 1.24, 1.96, rx = 0.26, ru = 0.26 },
			{ 0.2, 1.0, 2.2, rx = 0.12, ru = 0.12 },
		}, { step = 0.26, core = "FurDark", coreScale = 0.95, tile = H.fur(0.36, 6, 0.44, 20), color = function(th, ring) return math.abs(th) < rad(50) and "Back" or (ring % 2 == 0 and "Fur" or "FurDark") end })
		-- ice crystals bristling through the ruff and down the spine
		local ICE = { "Ice", "IceDeep", "IceGlow", "Ice" }
		H.crystalRidge(K, "Head", neck, { from = 0.1, to = neck.total - 0.05, every = 0.22, size = 0.42, count = 3, keys = ICE, lean = 38 })
		H.crystalRidge(K, "Body", body, { from = 0.15, to = body.total * 0.55, every = 0.34, size = function(u) return 0.5 * (1 - u) + 0.2 end, count = 3, keys = ICE, lean = 34 })
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.38 * x, 1.72, -0.72, 0.28 },
				{ 0.44 * x, 1.04, -0.6, 0.2 },
				{ 0.42 * x, 0.36, -0.74, 0.14 },
			}, { step = 0.26, cores = { "Fur", "FurDark" }, tiles = { H.fur(0.32, 5, 0.4, 14), nil }, color = limb, foot = { size = Vector3.new(0.3, 0.2, 0.36), key = "FurDark" }, toes = 4, claw = { len = 0.16, w = 0.05 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.38 * x, 1.7, 0.74, 0.34 },
				{ 0.44 * x, 1.14, 0.42, 0.26 },
				{ 0.44 * x, 0.62, 0.92, 0.15 },
				{ 0.44 * x, 0.2, 0.84, 0.13 },
			}, { step = 0.26, cores = { "Fur", "FurDark", "FurDark" }, tiles = { H.fur(0.34, 5, 0.42, 14), nil, nil }, color = limb, foot = { size = Vector3.new(0.3, 0.2, 0.38), key = "FurDark" }, toes = 4, claw = { len = 0.16, w = 0.05 } })
		end

		-- head: a long wolf muzzle wrinkled in a snarl, tall ears laid back a little, eyes slanted under the brow
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Fur", hcf(0, 0.1, -0.26), Vector3.new(0.62, 0.48, 0.52))
		K:block("Head", "FurDark", hcf(0, 0.32, -0.28, -10, 0, 0), Vector3.new(0.44, 0.12, 0.5))
		K:block("Head", "Fur", hcf(0, 0.0, -0.76), Vector3.new(0.38, 0.28, 0.58))
		K:block("Head", "FurDark", hcf(0, 0.12, -0.78, -8, 0, 0), Vector3.new(0.26, 0.08, 0.54))
		K:block("Head", "Skin", hcf(0, 0.08, -1.06), Vector3.new(0.18, 0.12, 0.08))
		K:block("Head", "Mouth", hcf(0, -0.13, -0.72), Vector3.new(0.32, 0.04, 0.5))
		for _, x in { 1, -1 } do
			K:block("Head", "FurLight", hcf(0.32 * x, -0.06, -0.24, 0, -16 * x, 10 * x), Vector3.new(0.16, 0.36, 0.42))
			K:block("Head", "Back", hcf(0.17 * x, 0.26, -0.5, -8, -14 * x, 18 * x), Vector3.new(0.22, 0.08, 0.22))
			H.eye(K, "Head", hcf(0.2 * x, 0.18, -0.52, 0, -24 * x, 14 * x), 0.13, 0.04)
			-- snarl: lips drawn back, fangs out
			K:block("Head", "Skin", hcf(0.18 * x, -0.1, -0.74), Vector3.new(0.04, 0.06, 0.5))
			K:spike("Head", "Tooth", hp(0.13 * x, -0.12, -0.92), hv(0, -1, 0), hv(0, 0, 1), 0.12, 0.05)
			H.teeth(K, "Head", "Tooth", hp(0.17 * x, -0.12, -0.5), hp(0.16 * x, -0.12, -0.82), 3, hv(0, -1, 0), hv(1, 0, 0), 0.06, 0.04)
			-- tall pointed ears, a little back
			local g = x == 1 and "EarL" or "EarR"
			K:chain(g, { "FurDark", "Fur" }, hp(0.2 * x, 0.32, -0.18), hv(0.25 * x, 1, 0.35), hv(0, 0, 1), { n = 2, len = 0.4, w0 = 0.2, w1 = 0.1, depth = 0.6, bend = 0 })
		end
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-14), 0, 0)
		K:block("Jaw", "Fur", JAW * CFrame.new(0, -0.07, -0.4), Vector3.new(0.34, 0.14, 0.74))
		K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.01, -0.44), Vector3.new(0.28, 0.03, 0.64))
		for _, x in { 1, -1 } do
			K:spike("Jaw", "Tooth", JAW * Vector3.new(0.12 * x, 0, -0.68), JAW:VectorToWorldSpace(Vector3.new(0, 1, 0)).Unit, JAW:VectorToWorldSpace(Vector3.zAxis), 0.1, 0.045)
			H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.14 * x, 0, -0.22), JAW * Vector3.new(0.13 * x, 0, -0.56), 3, JAW:VectorToWorldSpace(Vector3.yAxis), JAW:VectorToWorldSpace(Vector3.xAxis), 0.05, 0.04)
		end
	end,
}
