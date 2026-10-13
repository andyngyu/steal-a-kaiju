local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Rare / earth: a war mammoth. High shouldered and shaggy, dark russet fur hanging in a heavy skirt,
-- slabs of stone grown over its brow and back, huge curling ivory tusks, a long trunk, small amber eyes under a
-- domed skull.
local HEAD = CFrame.new(0, 2.42, -1.28) * CFrame.Angles(rad(-18), 0, 0)

return {
	Seed = 101,
	Vary = 0.06,
	Gait = "Amble",
	Emotes = { "Look", "Trumpet" },
	Palette = {
		Fur = "4A3024",
		FurDark = "2F1D16",
		FurLight = "6A4733",
		Skin = "3A2F2A",
		Ivory = "E6DBC0",
		IvoryDark = "C2B494",
		Armour = { "6A6458", Material = "Slate" },
		ArmourLight = { "8E8676", Material = "Slate" },
		Tooth = "E6DBC0",
		Mouth = "4E1A1A",
		Eye = { "FF9A1A", Neon = true },
		Socket = "100C0A",
		Claw = "2A2420",
		ClawTip = "BFB49A",
	},
	Joints = {
		Head = { 0, 2.3, -0.92 },
		Trunk = HEAD * Vector3.new(0, -0.3, -0.62),
		EarL = HEAD * Vector3.new(0.46, 0.12, -0.12),
		EarR = HEAD * Vector3.new(-0.46, 0.12, -0.12),
		LegFL = { 0.58, 1.7, -0.5 },
		LegFR = { -0.58, 1.7, -0.5 },
		LegBL = { 0.58, 1.6, 1.06 },
		LegBR = { -0.58, 1.6, 1.06 },
		Tail = { 0, 2.0, 1.42 },
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
		local body = K:tube("Body", {
			{ 0, 2.24, -0.82, rx = 0.86, ru = 0.94, rd = 0.84 },
			{ 0, 2.28, -0.1, rx = 1.0, ru = 0.98, rd = 0.9 },
			{ 0, 2.06, 0.7, rx = 0.94, ru = 0.84, rd = 0.84 },
			{ 0, 1.94, 1.22, rx = 0.74, ru = 0.7, rd = 0.66 },
		}, { step = 0.38, core = "Fur", coreScale = 0.74, tile = H.fur(0.56, nil, 0.66, 18), color = fur })
		-- the shaggy skirt hanging off the flanks and belly
		for s = 0.1, body.total - 0.1, 0.32 do
			local smp = K:at(body, s)
			for _, th in { 104, 140, -104, -140 } do
				local pos, nrm = K:surface(smp, rad(th), 0.04)
				K:chain("Body", { "Fur", "FurDark" }, pos, (nrm * 0.25 + Vector3.new(0, -1, 0)).Unit, smp.T, { n = 2, len = 0.62 + K:rand(-0.08, 0.1), w0 = 0.24, w1 = 0.14, bend = 0, tip = false, depth = 1.5 })
			end
		end
		-- stone slabs over the back
		H.studs(K, "Body", body, { 0, rad(34), rad(-34) }, 0.5, 0.34, 0.3, body.total - 0.3, { "Armour", "ArmourLight" })
		K:tube("Tail", {
			{ 0, 2.02, 1.36, rx = 0.14, ru = 0.14 },
			{ 0, 1.62, 1.66, rx = 0.09, ru = 0.09 },
		}, { step = 0.2, core = "FurDark", coreScale = 0.95 })
		K:chain("Tail", { "FurDark", "Fur" }, Vector3.new(0, 1.6, 1.68), Vector3.new(0, -1, 0.25).Unit, Vector3.xAxis, { n = 2, len = 0.32, w0 = 0.16, w1 = 0.1, tip = false, depth = 1.4, bend = 0 })
		for _, x in { 1, -1 } do
			for _, f in { { "LegFL", "LegFR", -0.5, 0.46 }, { "LegBL", "LegBR", 1.06, 0.48 } } do
				local g = x == 1 and f[1] or f[2]
				local z = f[3]
				H.quadLeg(K, g, {
					{ 0.58 * x, 1.86, z, f[4] },
					{ 0.62 * x, 1.0, z - 0.06, 0.38 },
					{ 0.6 * x, 0.32, z, 0.34 },
				}, { step = 0.3, cores = { "Fur", "FurDark" }, tiles = { H.fur(0.56, 5, 0.66, 16), nil }, color = limb, foot = { size = Vector3.new(0.6, 0.26, 0.58), key = "Skin" }, toes = 3, claw = { len = 0.1, w = 0.13, curl = 6, keys = { "IvoryDark", "Ivory", "Ivory" } } })
			end
		end

		-- head: a high domed skull capped with stone, small eyes, ears flat to the skull, tusks and trunk
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Fur", hcf(0, 0.1, -0.3), Vector3.new(0.86, 0.86, 0.7))
		K:block("Head", "FurDark", hcf(0, 0.56, -0.24, -14, 0, 0), Vector3.new(0.62, 0.36, 0.56))
		K:block("Head", "Skin", hcf(0, -0.12, -0.66), Vector3.new(0.6, 0.56, 0.2))
		K:block("Head", "Armour", hcf(0, 0.38, -0.62, -24, 0, 0), Vector3.new(0.6, 0.12, 0.44))
		K:block("Head", "ArmourLight", hcf(0, 0.64, -0.36, -40, 0, 0), Vector3.new(0.44, 0.1, 0.34))
		for _, x in { 1, -1 } do
			K:block("Head", "Armour", hcf(0.23 * x, 0.2, -0.72, -8, -12 * x, 16 * x), Vector3.new(0.28, 0.12, 0.2))
			H.eye(K, "Head", hcf(0.3 * x, 0.08, -0.72, 0, -28 * x, 12 * x), 0.12, 0.04)
			local g = x == 1 and "EarL" or "EarR"
			K:block(g, "FurDark", hcf(0.47 * x, 0.08, -0.12, 0, -14 * x, 0), Vector3.new(0.1, 0.5, 0.44))
			-- tusks: down and out, then sweeping forward and curling up and in
			H.curve(K, "Head", { "IvoryDark", "Ivory", "Ivory" }, {
				hp(0.24 * x, -0.3, -0.7),
				hp(0.44 * x, -0.86, -0.92),
				hp(0.62 * x, -1.16, -1.5),
				hp(0.58 * x, -0.96, -2.04),
				hp(0.36 * x, -0.5, -2.26),
			}, 0.22, 0.1, 0.2)
		end
		-- the trunk: hanging and curling forward at the tip
		local p0 = HEAD * Vector3.new(0, -0.3, -0.72)
		K:tube("Trunk", {
			{ p0.X, p0.Y, p0.Z, rx = 0.22, ru = 0.22 },
			{ p0.X, p0.Y - 0.5, p0.Z - 0.2, rx = 0.18, ru = 0.18 },
			{ p0.X, p0.Y - 1.0, p0.Z - 0.18, rx = 0.14, ru = 0.14 },
			{ p0.X, p0.Y - 1.3, p0.Z - 0.42, rx = 0.1, ru = 0.1 },
		}, { step = 0.2, ref = Vector3.xAxis, core = "Skin", coreScale = 0.98, tile = { w = 0.3, n = 5, t = 0.06, lift = 6, jitter = 1, sink = 0.5, overlap = 1.1 }, color = function(_, ring) return ring % 2 == 0 and "Skin" or "FurDark" end })
	end,
}
