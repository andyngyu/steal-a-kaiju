local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Common / earth: a squat armoured lizard, low and wide on four short splayed legs. Its back is a shell
-- of rounded pebble stones laid like cobbles, a short thick tail capped with stones, a broad blunt head under a stone
-- brow with a crown of stone knobs, amber eyes, a jaw full of teeth.
local HEAD = CFrame.new(0, 1.12, -1.0) * CFrame.Angles(rad(-4), 0, 0)
local SKULL = { 0.86, 0.46, 0.6 }

return {
	Seed = 11,
	Vary = 0.07,
	Gait = "Crawl",
	Emotes = { "Look", "Chomp" },
	Palette = {
		Hide = "4E5D3B",
		HideLight = "7A8260",
		HideDark = "36412A",
		Back = "232B1C",
		Belly = "BBAE8A",
		Belly2 = "9F936F",
		Rock = { "8A8475", Material = "Slate" },
		RockLight = { "B2AB98", Material = "Slate" },
		RockDark = { "5E594F", Material = "Slate" },
		Tooth = "EDE6D2",
		Claw = "3A342D",
		ClawTip = "CFC5AA",
		Mouth = "541C1C",
		Eye = { "FF9A1A", Neon = true },
		Socket = "12170E",
	},
	Joints = {
		Head = { 0, 1.12, -0.8 },
		Jaw = HEAD * Vector3.new(0, 0, -SKULL[3] * 0.25),
		LegFL = { 0.6, 1.04, -0.5 },
		LegFR = { -0.6, 1.04, -0.5 },
		LegBL = { 0.6, 1.04, 0.6 },
		LegBR = { -0.6, 1.04, 0.6 },
		Tail = { 0, 1.02, 0.9 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 40, band = 86, flank = 106, every = 3 })
		local belly = { key = "Belly", key2 = "Belly2", arc = 46, t = 0.11, wide = 1.1 }
		local body = K:tube("Body", {
			{ 0, 1.06, -0.8, rx = 0.66, ru = 0.5, rd = 0.42 },
			{ 0, 1.2, -0.2, rx = 0.92, ru = 0.66, rd = 0.48 },
			{ 0, 1.18, 0.42, rx = 0.9, ru = 0.64, rd = 0.46 },
			{ 0, 1.02, 0.88, rx = 0.64, ru = 0.46, rd = 0.38 },
		}, { step = 0.34, core = "Hide", coreScale = 0.74, tile = H.plates(0.5, nil, 0.12), belly = belly, color = skin })
		local tail = K:tube("Tail", {
			{ 0, 1.02, 0.82, rx = 0.5, ru = 0.42, rd = 0.36 },
			{ 0.02, 0.88, 1.38, rx = 0.34, ru = 0.3, rd = 0.26 },
			{ 0.08, 0.72, 1.8, rx = 0.18, ru = 0.17, rd = 0.15 },
			{ 0.14, 0.64, 2.02, rx = 0.08, ru = 0.08, rd = 0.07 },
		}, { step = 0.3, core = "Hide", coreScale = 0.76, tile = H.plates(0.36, 6, 0.1), belly = belly, color = skin, trim = 0.08 })
		local neck = K:tube("Head", {
			{ 0, 1.14, -1.06, rx = 0.44, ru = 0.4, rd = 0.42 },
			{ 0, 1.1, -0.72, rx = 0.58, ru = 0.5, rd = 0.48 },
		}, { step = 0.3, core = "Hide", coreScale = 0.76, tile = H.plates(0.42, nil, 0.11), belly = belly, color = skin })
		-- the shell: rows of big domed stones like a tortoise's back, pale along the spine, darker toward the flanks
		local SETS = { { "RockDark", "Rock", "RockLight" }, { "Rock", "RockLight", "RockLight" }, { "RockDark", "RockDark", "Rock" }, { "Rock", "Rock", "RockLight" } }
		local BAND = { [0] = { "Rock", "RockLight", "RockLight" }, [1] = { "Rock", "Rock", "RockLight" }, [2] = { "RockDark", "Rock", "Rock" } }
		local row = 0
		for s = 0.2, body.total - 0.12, 0.4 do
			row += 1
			local smp = K:at(body, s)
			local shift = row % 2 == 0 and 16 or 0
			for _, th in { 0, 36, -36, 72, -72 } do
				local band = math.abs(th) < 20 and 0 or (math.abs(th) < 50 and 1 or 2)
				local a = th + (th == 0 and 0 or shift * (th > 0 and 1 or -1))
				local size = ({ [0] = 0.56, 0.48, 0.36 })[band] * math.sqrt(smp.rx / 0.9)
				local pos, nrm = K:surface(smp, rad(a), 0.04)
				H.pebble(K, "Body", BAND[band], pos, nrm, smp.T, size)
			end
		end
		for s = 0.1, tail.total * 0.75, 0.3 do
			local smp = K:at(tail, s)
			for k, th in { 0, 40, -40 } do
				local pos, nrm = K:surface(smp, rad(th), 0.02)
				H.pebble(K, "Tail", SETS[k], pos, nrm, smp.T, (th == 0 and 0.36 or 0.26) * (1 - s / tail.total * 0.6))
			end
		end
		local tip = K:at(tail, tail.total)
		H.pebble(K, "Tail", SETS[2], tip.p - tip.T * 0.05, tip.T, tip.U, 0.3)
		local pos, nrm = K:surface(K:at(neck, 0.15), 0, 0.02)
		H.pebble(K, "Head", SETS[1], pos, nrm, K:at(neck, 0.15).T, 0.34)

		-- four short splayed legs, a stone on each shoulder
		for _, x in { 1, -1 } do
			local front = H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.6 * x, 1.06, -0.5, 0.3 },
				{ 1.0 * x, 0.8, -0.56, 0.26 },
				{ 1.02 * x, 0.26, -0.68, 0.22 },
			}, { step = 0.28, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.46, 0.2, 0.5), key = "HideDark" }, yaw = 18, claw = { len = 0.22, w = 0.075 } })
			local back = H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.6 * x, 1.06, 0.6, 0.36 },
				{ 1.04 * x, 0.84, 0.5, 0.3 },
				{ 1.06 * x, 0.26, 0.7, 0.24 },
			}, { step = 0.28, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.5, 0.2, 0.56), key = "HideDark" }, yaw = 20, claw = { len = 0.24, w = 0.08 } })
			for i, seg in { front[1], back[1] } do
				local smp = K:at(seg, seg.total * 0.5)
				local p, n = K:surface(smp, rad(-20) * x, 0.02)
				H.pebble(K, i == 1 and (x == 1 and "LegFL" or "LegFR") or (x == 1 and "LegBL" or "LegBR"), SETS[i + 1], p, n, smp.T, 0.3)
			end
		end

		-- head: broad and blunt, a stone brow and a crown of stone knobs
		local hd = H.reptileHead(K, {
			frame = HEAD,
			skull = SKULL,
			snout = { 0.66, 0.34, 0.4 },
			tip = { 0.56, 0.3, 0.22 },
			open = 12,
			teeth = { 0.08, 0.05 },
			brow = "RockDark",
			browSize = { 0.38, 0.16, 0.36 },
			eye = { 0.15, 0.045 },
			cheek = 0.3,
		})
		for k, q in { { 0, 0.02 }, { 0.26, 0.08 }, { -0.26, 0.08 } } do
			H.pebble(K, "Head", SETS[k], hd.p(q[1], hd.top - 0.02, q[2] - 0.12), hd.v(q[1] * 0.8, 1, 0.3), hd.v(0, 0, 1), 0.28)
		end
		H.pebble(K, "Head", SETS[2], hd.p(0, 0.38, hd.zEnd + 0.24), hd.v(0, 1, -0.4), hd.v(0, 0, -1), 0.22)
	end,
}
