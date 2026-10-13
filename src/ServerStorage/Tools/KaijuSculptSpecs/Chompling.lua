local rad = math.rad
local H = require(script.Parent.Helpers)

-- Pebble Plains / Common / earth: a mire crocodile. Long, low and armoured: rows of keeled bony scutes down a dark
-- olive back that close into a single saw-crest along the tail, a pale scaled belly, a long flat snout with
-- interlocking teeth bared in a half-open jaw, amber eyes raised on brow turrets, sprawled clawed legs.
local HEAD = CFrame.new(0, 1.26, -1.22) * CFrame.Angles(rad(-3), 0, 0)
local HINGE = Vector3.new(0, -0.14, -0.08)

return {
	Seed = 79,
	Vary = 0.07,
	Gait = "Crawl",
	Emotes = { "Look", "Chomp" },
	Palette = {
		Hide = "414C30",
		HideDark = "2D3522",
		HideLight = "6C7049",
		Back = "222A19",
		Belly = "BDB38A",
		Belly2 = "A39A73",
		Scute = { "4B5136", Material = "Slate" },
		ScuteLight = { "6D7151", Material = "Slate" },
		Tooth = "EDE5CF",
		Mouth = "5C2020",
		Eye = { "FFA41C", Neon = true },
		Socket = "10130B",
		Claw = "24221C",
		ClawTip = "CFC5AA",
	},
	Joints = {
		Head = { 0, 1.2, -0.92 },
		Jaw = HEAD * HINGE,
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
				K:plate("Body", KEYS, pos, nrm, smp.T, { h = row and 0.16 or 0.22, w = row and 0.22 or 0.28, t = 0.13, n = 2, lean = 10 })
			end
		end
		for s = 0.15, tail.total - 0.2, 0.3 do
			local smp = K:at(tail, s)
			local u = s / tail.total
			if u < 0.45 then
				for _, th in { 16, -16 } do
					local pos, nrm = K:surface(smp, rad(th), 0.02)
					K:plate("Tail", KEYS, pos, nrm, smp.T, { h = 0.3 - u * 0.2, w = 0.3, t = 0.12, n = 2, lean = 12 })
				end
			else
				local pos, nrm = K:surface(smp, 0, 0.02)
				K:plate("Tail", KEYS, pos, nrm, smp.T, { h = 0.36 * (1.2 - u), w = 0.3, t = 0.12, n = 2, lean = 14 })
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

		-- head (head space: origin at the back of the skull, facing -Z)
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Hide", hcf(0, 0.06, -0.3), Vector3.new(0.86, 0.4, 0.66))
		K:block("Head", "Hide", hcf(0, -0.02, -1.18), Vector3.new(0.6, 0.26, 1.24))
		K:block("Head", "Hide", hcf(0, -0.02, -1.88), Vector3.new(0.66, 0.26, 0.28))
		K:block("Head", "HideDark", hcf(0, 0.12, -1.88), Vector3.new(0.26, 0.1, 0.2))
		K:block("Head", "Mouth", hcf(0, -0.13, -1.1), Vector3.new(0.54, 0.04, 1.5))
		for i = 0, 4 do
			K:block("Head", i % 2 == 0 and "Back" or "HideDark", hcf(0, 0.12, -0.7 - i * 0.24, -6, 0, 0), Vector3.new(0.42 - i * 0.02, 0.06, 0.24))
		end
		for _, x in { 1, -1 } do
			-- brow turrets with the eyes set in their fronts, heavy bony lids over them
			K:block("Head", "HideDark", hcf(0.25 * x, 0.3, -0.44), Vector3.new(0.26, 0.2, 0.32))
			K:block("Head", "Scute", hcf(0.25 * x, 0.42, -0.46, -10, -10 * x, 14 * x), Vector3.new(0.3, 0.08, 0.36))
			H.eye(K, "Head", hcf(0.27 * x, 0.32, -0.61, 0, -20 * x, 10 * x), 0.14, 0.045)
			-- bony knobs at the back corners of the skull
			K:spike("Head", "ScuteLight", hp(0.36 * x, 0.24, -0.06), hv(0.4 * x, 0.6, 0.7), hv(0, 0, 1), 0.16, 0.1)
			-- interlocking teeth: upper row down, along the edge of the snout
			H.teeth(K, "Head", "Tooth", hp(0.3 * x, -0.15, -0.62), hp(0.31 * x, -0.15, -1.92), 10, hv(0, -1, 0), hv(1, 0, 0), 0.09, 0.05)
		end
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-9), 0, 0)
		local function jcf(px, py, pz) return JAW * CFrame.new(px, py, pz) end
		K:block("Jaw", "Hide", jcf(0, -0.08, -0.3), Vector3.new(0.82, 0.18, 0.56))
		K:block("Jaw", "Hide", jcf(0, -0.06, -1.14), Vector3.new(0.56, 0.16, 1.6))
		K:block("Jaw", "Belly", jcf(0, -0.15, -0.9), Vector3.new(0.5, 0.04, 1.6))
		K:block("Jaw", "Mouth", jcf(0, 0.02, -1.1), Vector3.new(0.48, 0.04, 1.4))
		for _, x in { 1, -1 } do
			H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.27 * x, 0, -0.56), JAW * Vector3.new(0.26 * x, 0, -1.9), 9, JAW:VectorToWorldSpace(Vector3.new(0, 1, 0)).Unit, JAW:VectorToWorldSpace(Vector3.xAxis), 0.08, 0.05)
		end
	end,
}
