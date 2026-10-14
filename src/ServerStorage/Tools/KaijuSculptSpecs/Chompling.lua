local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Common / earth: a mire crocodile. Long, low and armoured: rows of keeled bony scutes down a dark
-- olive back that close into a single saw-crest along the tail, a pale scaled belly, a long flat snout with
-- interlocking teeth bared in a half-open jaw, amber eyes raised on brow turrets, sprawled clawed legs.
local HEAD = CFrame.new(0, 1.26, -1.22) * CFrame.Angles(rad(-3), 0, 0)
local HINGE = Vector3.new(0, -0.14, -0.08)
local HS = 1.16

return {
	Seed = 79,
	Vary = 0.07,
	Gait = "Crawl",
	Emotes = { "Look", "Chomp" },
	Palette = {
		Hide = "4E5C37",
		HideDark = "35402A",
		HideLight = "7E8452",
		Back = "2A331F",
		Belly = "BDB38A",
		Belly2 = "A39A73",
		Scute = { "4F563C", Material = "Slate" },
		ScuteLight = { "6B7253", Material = "Slate" },
		Tooth = "EDE5CF",
		Mouth = "5C2020",
		Eye = { "FFA41C", Neon = true },
		Socket = "10130B",
		Claw = "24221C",
		ClawTip = "CFC5AA",
	},
	Joints = {
		Head = { 0, 1.2, -0.92 },
		Jaw = HEAD.Position + (HEAD * HINGE - HEAD.Position) * HS,
		LegFL = { 0.62, 1.02, -0.6 },
		LegFR = { -0.62, 1.02, -0.6 },
		LegBL = { 0.6, 1.0, 0.72 },
		LegBR = { -0.6, 1.0, 0.72 },
		Tail = { 0, 1.1, 1.08 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local skin = H.skin({ stripe = 30, band = 80, flank = 100, every = 3 })
		local belly = { key = "Belly", key2 = "Belly2", arc = 50, t = 0.1, wide = 1.15 }
		local plates = { w = 0.42, n = 8, t = 0.1, lift = 4, jitter = 1.5, sink = 0.5, overlap = 1.1 }
		local body = K:tube("Body", {
			{ 0, 1.2, -0.98, rx = 0.62, ru = 0.42, rd = 0.44 },
			{ 0, 1.22, -0.3, rx = 0.9, ru = 0.52, rd = 0.56 },
			{ 0, 1.18, 0.5, rx = 0.88, ru = 0.5, rd = 0.52 },
			{ 0, 1.1, 1.14, rx = 0.66, ru = 0.42, rd = 0.42 },
		}, { step = 0.36, core = "Hide", coreScale = 0.92, tile = plates, belly = belly, color = skin })
		local tail = K:tube("Tail", {
			{ 0, 1.12, 1.0, rx = 0.62, ru = 0.4, rd = 0.4 },
			{ -0.06, 1.0, 1.8, rx = 0.44, ru = 0.34, rd = 0.32 },
			{ -0.32, 0.86, 2.5, rx = 0.28, ru = 0.26, rd = 0.24 },
			{ -0.78, 0.72, 3.02, rx = 0.16, ru = 0.18, rd = 0.14 },
			{ -1.28, 0.64, 3.22, rx = 0.08, ru = 0.1, rd = 0.07 },
		}, { step = 0.34, core = "Hide", coreScale = 0.92, tile = { w = 0.36, n = 6, t = 0.09, lift = 4, jitter = 1.5, sink = 0.5, overlap = 1.1 }, belly = belly, color = skin, trim = 0.1 })
		-- rows of keeled scutes: four down the back, two down the tail closing into one saw-crest
		local KEYS = { "Scute", "ScuteLight" }
		for _, th in { 14, -14, 34, -34 } do
			local row = math.abs(th) > 20
			for s = 0.25, body.total - 0.15, 0.32 do
				local smp = K:at(body, s)
				local pos, nrm = K:surface(smp, rad(th), 0.02)
				K:plate("Body", KEYS, pos, nrm, smp.T, { h = row and 0.16 or 0.26, w = row and 0.22 or 0.3, t = 0.13, n = 2, lean = 12 })
			end
		end
		for s = 0.15, tail.total - 0.2, 0.3 do
			local smp = K:at(tail, s)
			local u = s / tail.total
			if u < 0.45 then
				for _, th in { 16, -16 } do
					local pos, nrm = K:surface(smp, rad(th), 0.02)
					K:plate("Tail", KEYS, pos, nrm, smp.T, { h = 0.4 - u * 0.2, w = 0.32, t = 0.13, n = 2, lean = 12 })
				end
			else
				local pos, nrm = K:surface(smp, 0, 0.02)
				K:plate("Tail", KEYS, pos, nrm, smp.T, { h = 0.52 * (1.25 - u), w = 0.34, t = 0.13, n = 3, lean = 16 })
			end
		end
		-- sprawled legs: elbows and knees out to the sides, broad clawed feet
		for _, x in { 1, -1 } do
			H.quadLeg(K, x == 1 and "LegFL" or "LegFR", {
				{ 0.62 * x, 1.06, -0.6, 0.34 },
				{ 1.14 * x, 0.86, -0.66, 0.28 },
				{ 1.18 * x, 0.26, -0.78, 0.22 },
			}, { step = 0.3, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.5, 0.2, 0.52), key = "HideDark" }, yaw = 20, claw = { len = 0.24, w = 0.07 } })
			H.quadLeg(K, x == 1 and "LegBL" or "LegBR", {
				{ 0.6 * x, 1.04, 0.72, 0.4 },
				{ 1.18 * x, 0.9, 0.6, 0.32 },
				{ 1.22 * x, 0.26, 0.82, 0.24 },
			}, { step = 0.3, cores = { "Hide", "HideDark" }, foot = { size = Vector3.new(0.56, 0.2, 0.62), key = "HideDark" }, yaw = 24, claw = { len = 0.26, w = 0.075 } })
		end

		-- head (head space: origin at the back of the skull, facing -Z), scaled up about its origin: a broad flat skull
		-- table with bony knobs at the corners, raised eye turrets under heavy bony lids, a long snout tapering then
		-- flaring into a rounded tip with a raised nostril bump, a half-open jaw of separate interlocking teeth with the
		-- big fourth lower tooth showing outside the upper jaw
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		-- snout half-width along its length (z), for placing teeth on its edge
		local function half(z)
			if z > -1.18 then
				return 0.36
			elseif z > -1.7 then
				return 0.27 + (z + 1.7) / 0.52 * 0.06
			end
			return 0.32
		end
		K:scaled(HEAD.Position, HS, function()
			K:block("Head", "Hide", hcf(0, 0.06, -0.3), Vector3.new(0.92, 0.4, 0.7))
			K:block("Head", "HideDark", hcf(0, 0.27, -0.28), Vector3.new(0.8, 0.06, 0.62))
			for _, x in { 1, -1 } do
				K:block("Head", "Scute", hcf(0.2 * x, 0.31, -0.2), Vector3.new(0.24, 0.06, 0.3))
			end
			-- the snout: a broad base, a narrower middle, a rounded flaring tip
			K:block("Head", "Hide", hcf(0, -0.01, -0.9), Vector3.new(0.72, 0.3, 0.62))
			K:block("Head", "Hide", hcf(0, -0.02, -1.44), Vector3.new(0.56, 0.26, 0.6))
			K:block("Head", "Hide", hcf(0, -0.01, -1.88), Vector3.new(0.64, 0.28, 0.38))
			for _, x in { 1, -1 } do
				K:block("Head", "Hide", hcf(0.27 * x, -0.01, -1.9, 0, 0, 45), Vector3.new(0.14, 0.14, 0.34))
				K:block("Head", "HideDark", hcf(0.3 * x, -0.02, -1.18, 0, -8 * x, 0), Vector3.new(0.1, 0.24, 0.6))
			end
			-- bumpy scale rows down the top of the snout, a raised nostril bump on the tip
			for k = 0, 5 do
				K:block("Head", k % 2 == 0 and "Back" or "HideDark", hcf(0, 0.15, -0.66 - k * 0.22, -4, 0, 0), Vector3.new(0.46 - k * 0.03, 0.06, 0.18))
			end
			K:block("Head", "HideDark", hcf(0, 0.16, -1.92), Vector3.new(0.26, 0.08, 0.22))
			for _, x in { 1, -1 } do
				K:block("Head", "Socket", hcf(0.055 * x, 0.2, -1.94), Vector3.new(0.06, 0.02, 0.07))
			end
			K:block("Head", "Mouth", hcf(0, -0.16, -1.2), Vector3.new(0.5, 0.04, 1.6))
			for _, x in { 1, -1 } do
				-- eye turrets with heavy bony lids slanted into a glare
				K:block("Head", "HideDark", hcf(0.26 * x, 0.32, -0.48), Vector3.new(0.28, 0.22, 0.32))
				K:block("Head", "Scute", hcf(0.27 * x, 0.46, -0.52, -12, -10 * x, 16 * x), Vector3.new(0.32, 0.09, 0.38))
				H.eye(K, "Head", hcf(0.28 * x, 0.33, -0.65, 0, -18 * x, 12 * x), 0.15, 0.045)
				-- bony knobs at the back corners of the skull
				K:spike("Head", "ScuteLight", hp(0.38 * x, 0.24, -0.06), hv(0.4 * x, 0.6, 0.7), hv(0, 0, 1), 0.18, 0.1)
				-- separate upper teeth along the edge of the snout, long and short
				for k, o in { { -0.66, 0.1 }, { -0.88, 0.14 }, { -1.1, 0.1 }, { -1.34, 0.13 }, { -1.56, 0.1 }, { -1.78, 0.18 }, { -1.98, 0.12 } } do
					local base = hp((half(o[1]) - 0.03) * x, -0.15, o[1])
					if o[2] >= 0.13 then
						H.fang(K, "Head", "Tooth", base, hv(0.12 * x, -1, 0), o[2], 0.055)
					else
						K:spike("Head", "Tooth", base, hv(0.1 * x, -1, 0), hv(0, 0, 1), o[2], 0.05)
					end
				end
			end
			local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-12), 0, 0)
			local function jcf(px, py, pz)
				return JAW * CFrame.new(px, py, pz)
			end
			K:block("Jaw", "Hide", jcf(0, -0.08, -0.3), Vector3.new(0.86, 0.2, 0.56))
			K:block("Jaw", "Hide", jcf(0, -0.06, -1.04), Vector3.new(0.6, 0.17, 1.0))
			K:block("Jaw", "Hide", jcf(0, -0.06, -1.74), Vector3.new(0.54, 0.16, 0.5))
			K:block("Jaw", "Belly", jcf(0, -0.16, -0.95), Vector3.new(0.52, 0.04, 1.6))
			K:block("Jaw", "Mouth", jcf(0, 0.03, -1.1), Vector3.new(0.5, 0.04, 1.5))
			for _, x in { 1, -1 } do
				K:block("Jaw", "HideDark", jcf(0.29 * x, -0.04, -1.0), Vector3.new(0.06, 0.12, 1.0))
				local up = JAW:VectorToWorldSpace(Vector3.new(0, 1, 0)).Unit
				for k, o in { { -0.62, 0.09 }, { -0.84, 0.12 }, { -1.08, 0.09 }, { -1.3, 0.12 }, { -1.52, 0.09 }, { -1.92, 0.12 } } do
					local w = o[1] < -1.5 and 0.25 or 0.27
					K:spike("Jaw", "Tooth", JAW * Vector3.new((w - 0.02) * x, 0.02, o[1]), up, JAW:VectorToWorldSpace(Vector3.zAxis), o[2], 0.05)
				end
				-- the big fourth lower tooth jutting up outside the upper jaw
				H.fang(K, "Jaw", "Tooth", JAW * Vector3.new(0.29 * x, 0.0, -1.66), (up + JAW:VectorToWorldSpace(Vector3.new(0.18 * x, 0, 0))).Unit, 0.26, 0.07)
			end
		end)
	end,
}
