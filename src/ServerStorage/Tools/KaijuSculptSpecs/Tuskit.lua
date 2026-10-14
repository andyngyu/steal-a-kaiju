local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Rare / earth: a war mammoth. A towering shoulder hump with the back sloping steeply down to low
-- hindquarters, a high domed skull, a long shaggy russet coat hanging in a heavy skirt over pillar legs, a beard of
-- hair under the throat, a stone war-helm on the brow and stone slabs over the hump. Face: small amber eyes glaring
-- out from under heavy brow folds, a thick ringed trunk, huge ivory tusks sweeping out and curling up, bound with
-- stone rings.
local HEAD = CFrame.new(0, 2.92, -1.46) * CFrame.Angles(rad(-20), 0, 0)
local HS = 1.2

local function hj(v)
	return HEAD.Position + (HEAD * v - HEAD.Position) * HS
end

return {
	Seed = 101,
	Vary = 0.06,
	Gait = "Amble",
	Emotes = { "Look", "Trumpet" },
	Palette = {
		Fur = "5C3A28",
		FurDark = "3E2619",
		FurLight = "7A5238",
		Skin = "3E3430",
		SkinDark = "2A2320",
		Ivory = "E6DBC0",
		IvoryDark = "C2B494",
		Armour = { "6E685C", Material = "Slate" },
		ArmourLight = { "938B7A", Material = "Slate" },
		ArmourDark = { "4E4A42", Material = "Slate" },
		Tooth = "E6DBC0",
		Mouth = "4E1A1A",
		Eye = { "FF9A1A", Neon = true },
		Socket = "100C0A",
		Claw = "2A2420",
		ClawTip = "BFB49A",
	},
	Joints = {
		Head = { 0, 2.78, -0.98 },
		Trunk = hj(Vector3.new(0, -0.34, -0.74)),
		EarL = hj(Vector3.new(0.47, 0.2, -0.1)),
		EarR = hj(Vector3.new(-0.47, 0.2, -0.1)),
		LegFL = { 0.6, 2.0, -0.62 },
		LegFR = { -0.6, 2.0, -0.62 },
		LegBL = { 0.58, 1.84, 1.0 },
		LegBR = { -0.58, 1.84, 1.0 },
		Tail = { 0, 2.2, 1.46 },
	},
	Parents = { Trunk = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		local function fur(th, ring)
			local a = math.deg(math.abs(th))
			if a < 40 then
				return "FurDark"
			elseif a < 120 then
				return ring % 2 == 0 and "Fur" or "FurDark"
			end
			return "FurLight"
		end
		local function limb(_, ring)
			return ring % 2 == 0 and "Fur" or "FurDark"
		end
		-- a towering shoulder hump, the back sloping steeply down to the hips
		local body = K:tube("Body", {
			{ 0, 2.62, -0.8, rx = 0.9, ru = 1.04, rd = 0.86 },
			{ 0, 2.5, -0.06, rx = 1.0, ru = 0.92, rd = 0.88 },
			{ 0, 2.22, 0.72, rx = 0.94, ru = 0.76, rd = 0.84 },
			{ 0, 1.98, 1.26, rx = 0.74, ru = 0.6, rd = 0.66 },
		}, { step = 0.38, core = "Fur", coreScale = 0.74, tile = H.fur(0.7, nil, 0.72, 18), color = fur })
		-- the heavy shaggy skirt hanging off the flanks, long enough to brush the knees
		for s = 0.12, body.total - 0.1, 0.42 do
			local smp = K:at(body, s)
			for _, th in { 100, 136, -100, -136 } do
				local pos, nrm = K:surface(smp, rad(th), 0.04)
				K:chain("Body", { "Fur", "FurDark" }, pos, (nrm * 0.22 + Vector3.new(0, -1, 0)).Unit, smp.T, { n = 2, len = 0.8 + K:rand(-0.1, 0.1), w0 = 0.26, w1 = 0.15, bend = 0, tip = false, depth = 1.5 })
			end
		end
		-- a beard of hair hanging under the throat
		for k = -2, 2 do
			K:chain("Body", { "FurDark", "Fur" }, Vector3.new(k * 0.2, 2.1, -1.22 + math.abs(k) * 0.06), Vector3.new(k * 0.08, -1, -0.1).Unit, Vector3.xAxis, { n = 2, len = 0.7 - math.abs(k) * 0.08, w0 = 0.24, w1 = 0.14, bend = 0, tip = false, depth = 1.4 })
		end
		-- stone slabs over the hump: a saddle of overlapping plates, pale rims
		for i, s in { 0.15, 0.5, 0.85, 1.2 } do
			local smp = K:at(body, s)
			for _, th in { 0, 36, -36 } do
				local w = (th == 0 and 0.62 or 0.52) - i * 0.04
				K:tile("Body", th == 0 and "Armour" or (i % 2 == 0 and "ArmourDark" or "Armour"), smp, rad(th), w, 0.46, 0.15, 10, 1, -0.8)
			end
			K:tile("Body", "ArmourLight", K:at(body, s + 0.2), 0, 0.5 - i * 0.04, 0.1, 0.17, 10, 1, -0.8)
		end
		K:tube("Tail", {
			{ 0, 2.2, 1.42, rx = 0.13, ru = 0.13 },
			{ 0, 1.82, 1.74, rx = 0.09, ru = 0.09 },
		}, { step = 0.2, core = "FurDark", coreScale = 0.95 })
		K:chain("Tail", { "FurDark", "Fur" }, Vector3.new(0, 1.8, 1.76), Vector3.new(0, -1, 0.25).Unit, Vector3.xAxis, { n = 2, len = 0.36, w0 = 0.16, w1 = 0.1, tip = false, depth = 1.4, bend = 0 })
		-- pillar legs showing under the skirt, broad round feet with ivory toenails
		for _, x in { 1, -1 } do
			for _, f in { { "LegFL", "LegFR", -0.62, 2.0, 0.46 }, { "LegBL", "LegBR", 1.0, 1.84, 0.48 } } do
				local g = x == 1 and f[1] or f[2]
				local z = f[3]
				H.quadLeg(K, g, {
					{ 0.6 * x, f[4], z, f[5] },
					{ 0.62 * x, 1.06, z - 0.04, 0.4 },
					{ 0.6 * x, 0.34, z, 0.36 },
				}, { step = 0.3, cores = { "Fur", "Skin" }, tiles = { H.fur(0.62, 5, 0.7, 16), nil }, color = limb, foot = { size = Vector3.new(0.66, 0.28, 0.64), key = "Skin" }, toes = 3, claw = { len = 0.1, w = 0.14, curl = 6, keys = { "IvoryDark", "Ivory", "Ivory" } } })
			end
		end

		-- head: a high domed skull under a stone war-helm, eyes under brow folds, a ringed trunk, ringed tusks
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
		K:block("Head", "Fur", hcf(0, 0.2, -0.24), Vector3.new(1.0, 0.98, 0.8))
		K:block("Head", "FurDark", hcf(0, 0.7, -0.16, -12, 0, 0), Vector3.new(0.84, 0.4, 0.7))
		K:block("Head", "FurDark", hcf(0, 0.74, -0.16, -12, 0, 45), Vector3.new(0.6, 0.6, 0.68))
		for _, x in { 1, -1 } do
			K:block("Head", "Fur", hcf(0.48 * x, 0.02, -0.38, 0, -10 * x, 0), Vector3.new(0.16, 0.62, 0.5))
			K:block("Head", "FurDark", hcf(0.5 * x, 0.24, -0.3, 0, -10 * x, 45), Vector3.new(0.3, 0.3, 0.46))
		end
		-- the stone war-helm: a brow plate with a raised central ridge and pale rim
		K:block("Head", "Armour", hcf(0, 0.48, -0.64, -24, 0, 0), Vector3.new(0.78, 0.16, 0.52))
		K:block("Head", "ArmourLight", hcf(0, 0.34, -0.86, -24, 0, 0), Vector3.new(0.8, 0.1, 0.12))
		K:block("Head", "ArmourDark", hcf(0, 0.6, -0.64, -24, 0, 45), Vector3.new(0.18, 0.18, 0.5))
		K:block("Head", "Armour", hcf(0, 0.8, -0.46, -40, 0, 0), Vector3.new(0.52, 0.12, 0.34))
		-- the face, brow folds slanted into a glare, small eyes
		K:block("Head", "Skin", hcf(0, -0.02, -0.62), Vector3.new(0.7, 0.58, 0.2))
		for _, x in { 1, -1 } do
			K:block("Head", "SkinDark", hcf(0.24 * x, 0.2, -0.74, -6, -12 * x, 18 * x), Vector3.new(0.32, 0.12, 0.2))
			H.eye(K, "Head", hcf(0.27 * x, 0.1, -0.73, 0, -24 * x, 14 * x), 0.13, 0.045)
			K:block("Head", "SkinDark", hcf(0.2 * x, -0.12, -0.74, 0, -10 * x, 0), Vector3.new(0.18, 0.08, 0.1))
			-- tusk sheaths beside the trunk, the tusks sweeping down, out, forward and curling up, bound with stone rings
			K:block("Head", "Skin", hcf(0.27 * x, -0.34, -0.68, 10, 0, 0), Vector3.new(0.26, 0.26, 0.32))
			local pts = {
				hp(0.27 * x, -0.4, -0.76),
				hp(0.5 * x, -0.96, -0.98),
				hp(0.7 * x, -1.24, -1.56),
				hp(0.64 * x, -1.02, -2.12),
				hp(0.4 * x, -0.56, -2.34),
			}
			H.curve(K, "Head", { "IvoryDark", "Ivory", "Ivory" }, pts, 0.24, 0.1, 0.2)
			for _, f in { 0.18, 0.42 } do
				local i = 1 + f * (#pts - 1)
				local a, b = pts[math.floor(i)], pts[math.floor(i) + 1]
				local c = a:Lerp(b, i - math.floor(i))
				K:block("Head", "Armour", CFrame.lookAt(c, b) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.3, 0.3, 0.12))
			end
			-- small ears flat to the skull
			local g = x == 1 and "EarL" or "EarR"
			K:block(g, "FurDark", hcf(0.56 * x, 0.2, -0.08, 0, -14 * x, 0), Vector3.new(0.1, 0.3, 0.28))
		end
		K:block("Head", "Mouth", hcf(0, -0.56, -0.5, 14, 0, 0), Vector3.new(0.3, 0.08, 0.2))
		K:block("Head", "Skin", hcf(0, -0.62, -0.46, 14, 0, 0), Vector3.new(0.34, 0.08, 0.24))
		-- the trunk: thick at the root, ringed with wrinkles, hanging and curling forward at the tip
		local p0 = HEAD * Vector3.new(0, -0.34, -0.8)
		K:tube("Trunk", {
			{ p0.X, p0.Y, p0.Z, rx = 0.26, ru = 0.26 },
			{ p0.X, p0.Y - 0.5, p0.Z - 0.16, rx = 0.2, ru = 0.2 },
			{ p0.X, p0.Y - 1.0, p0.Z - 0.12, rx = 0.15, ru = 0.15 },
			{ p0.X, p0.Y - 1.32, p0.Z - 0.4, rx = 0.11, ru = 0.11 },
		}, { step = 0.18, ref = Vector3.xAxis, core = "Skin", coreScale = 0.98, tile = { w = 0.32, n = 5, t = 0.06, lift = 6, jitter = 1, sink = 0.5, overlap = 1.1 }, color = function(_, ring) return ring % 2 == 0 and "Skin" or "SkinDark" end })
		end)
	end,
}
