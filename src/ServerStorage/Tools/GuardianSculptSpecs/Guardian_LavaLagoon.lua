local rad = math.rad
local GK = require(script.Parent.GuardianKit)
local H = GK.H

-- Lava Lagoon guardian: the Magma Colossus. An upright volcanic titan in the classic kaiju stance: massive legs, a deep
-- chest leaning forward, clawed arms held out, a long heavy tail dragging behind. Its hide is cracked red-brown rock
-- split by glowing magma veins, its belly a column of glowing plates, and three rows of jagged dorsal fins blaze from
-- rock to molten orange to white-hot down its back and tail. Face: a heavy rock brow over burning eyes, flame horns
-- sweeping back, magma cracks, a jaw of fangs open on a furnace-bright mouth.
local HEAD = CFrame.new(0, 5.95, -1.12) * CFrame.Angles(rad(-6), 0, 0)
local HINGE = Vector3.new(0, -0.14, -0.26)

return {
	Seed = 233,
	Vary = 0.05,
	Scale = 3.0,
	RootSize = { 8.2, 6.6, 10.4 },
	HipHeight = 1.75,
	Palette = {
		Rock = { "82503A", Material = "Basalt" },
		RockDark = { "5A3428", Material = "Basalt" },
		RockLight = { "A46E52", Material = "Basalt" },
		Magma = { "FF5A14", Neon = true },
		MagmaHot = { "FF8C1A", Neon = true },
		Flame = { "FFD23A", Neon = true },
		BellyGlow = { "FF7A22", Neon = true },
		Tooth = "F0DCC0",
		Mouth = { "FF6A1A", Neon = true },
		Eye = { "FFD23A", Neon = true },
		Socket = "120A08",
		Claw = "201612",
		ClawTip = { "FFB43A", Neon = true },
	},
	Joints = {
		Head = { 0, 5.5, -0.42 },
		Jaw = HEAD * HINGE,
		LegL = { 0.95, 3.05, 0.35 },
		LegR = { -0.95, 3.05, 0.35 },
		ArmL = { 1.35, 5.05, -0.35 },
		ArmR = { -1.35, 5.05, -0.35 },
		Tail = { 0, 3.2, 0.72 },
	},
	Parents = { Jaw = "Head" },
	Build = function(K)
		local ROCK = H.plates(1.05)
		local function rock(_, ring)
			return ring % 2 == 0 and "Rock" or "RockDark"
		end
		local VEIN = { lift = 0.1, wander = 18, width = 0.1, height = 0.12, step = 0.4, forks = 1, forkSteps = 2 }
		local FIN = { "RockDark", "Rock", "Magma", "MagmaHot" }
		-- an upright torso leaning forward (front = theta 0): the belly left bare for a column of glowing plates
		local torso = K:tube("Body", {
			{ 0, 5.35, -0.3, rx = 1.25, ru = 0.85, rd = 0.85 },
			{ 0, 4.7, -0.1, rx = 1.35, ru = 1.0, rd = 0.9 },
			{ 0, 3.9, 0.15, rx = 1.25, ru = 0.95, rd = 0.9 },
			{ 0, 3.15, 0.42, rx = 1.05, ru = 0.8, rd = 0.85 },
		}, { step = 0.4, ref = Vector3.xAxis, core = "RockDark", coreScale = 0.86, tile = ROCK, color = function(th, ring)
			if math.abs(th) < rad(40) then
				return nil
			end
			return rock(th, ring)
		end })
		for s = 0.15, torso.total - 0.1, 0.34 do
			local smp = K:at(torso, s)
			K:tile("Body", "BellyGlow", smp, 0, 0.92 - s * 0.08, 0.3, 0.12, 4, 1, 0.3)
		end
		local mantle = K:tube("Body", {
			{ -1.38, 5.18, -0.28, rx = 0.66, ru = 0.62, rd = 0.55 },
			{ 0, 5.46, -0.2, rx = 0.78, ru = 0.7, rd = 0.6 },
			{ 1.38, 5.18, -0.28, rx = 0.66, ru = 0.62, rd = 0.55 },
		}, { step = 0.42, ref = Vector3.zAxis, core = "RockDark", coreScale = 0.9, tile = ROCK, color = rock })
		for _, x in { 1, -1 } do
			H.vein(K, "Body", "MagmaHot", torso, rad(72) * x, 0.1, torso.total - 0.1, VEIN)
		end
		H.vein(K, "Body", "MagmaHot", mantle, rad(-45), 0.3, mantle.total - 0.3, VEIN)
		-- the neck (moves with the head)
		local neck = K:tube("Head", {
			{ 0, 5.92, -1.0, rx = 0.62, ru = 0.6, rd = 0.62 },
			{ 0, 5.72, -0.7, rx = 0.74, ru = 0.7, rd = 0.74 },
			{ 0, 5.42, -0.36, rx = 0.86, ru = 0.8, rd = 0.84 },
		}, { step = 0.36, core = "RockDark", coreScale = 0.9, tile = H.plates(0.8), color = rock })
		-- the long heavy tail, dragging and curling away to its right
		local tail = K:tube("Tail", {
			{ 0, 3.2, 0.68, rx = 0.86, ru = 0.82, rd = 0.8 },
			{ -0.08, 2.6, 1.78, rx = 0.72, ru = 0.68, rd = 0.66 },
			{ -0.4, 1.74, 2.86, rx = 0.54, ru = 0.5, rd = 0.48 },
			{ -0.96, 1.04, 3.74, rx = 0.38, ru = 0.36, rd = 0.34 },
			{ -1.66, 0.62, 4.32, rx = 0.24, ru = 0.22, rd = 0.2 },
			{ -2.36, 0.44, 4.62, rx = 0.11, ru = 0.1, rd = 0.1 },
		}, { step = 0.62, core = "RockDark", coreScale = 0.88, tile = H.plates(1.0, 5), belly = { key = "BellyGlow", key2 = "RockDark", arc = 40, t = 0.11, wide = 1.05 }, color = rock, trim = 0.16 })
		H.vein(K, "Tail", "MagmaHot", tail, rad(-75), 0.2, tail.total - 1.2, VEIN)
		-- three rows of jagged dorsal fins, rock at the root burning up to white-hot tips
		-- (the torso runs top to bottom with its back at theta pi: its fins rise up and back)
		local function fins(g, samples, from, to, every, size, sides)
			for s = from, to, every do
				local u = (s - from) / math.max(to - from, 1e-3)
				local smp = K:at(samples, s)
				local h = size(u)
				local body = g == "Body"
				local pos, nrm = K:surface(smp, body and math.pi or 0, 0.06)
				local up = body and (nrm + Vector3.new(0, 0.75, 0)).Unit or (nrm + smp.T * 0.15).Unit
				local along = body and Vector3.new(0, 0, 1) or smp.T
				K:plate(g, FIN, pos, up, along, { h = h, w = h * 0.58, t = 0.2, n = 4, lean = 14 })
				if sides then
					for _, x in { 1, -1 } do
						local p2, n2 = K:surface(smp, (body and math.pi or 0) + rad(36) * x, 0.06)
						K:plate(g, FIN, p2, (n2 + Vector3.new(0, body and 0.75 or 0.4, 0)).Unit, along, { h = h * 0.6, w = h * 0.4, t = 0.15, n = 3, lean = 14 })
					end
				end
			end
		end
		fins("Body", torso, 0.2, torso.total - 0.2, 0.6, function(u) return 2.0 - u * 0.5 end, true)
		fins("Tail", tail, 0.3, tail.total - 0.9, 0.62, function(u) return 1.45 * (1 - u) + 0.4 end, false)
		for _, x in { 1, -1 } do
			-- massive legs: huge thighs, rock greaves, three-toed feet with burning claws
			local g = x == 1 and "LegL" or "LegR"
			local dz = x == 1 and -0.12 or 0.16
			local leg = H.limb(K, g, {
				{ 0.95 * x, 3.05, 0.35, 0.8 },
				{ 1.16 * x, 1.78, -0.04 + dz, 0.64 },
				{ 1.12 * x, 0.6, 0.28 + dz, 0.44 },
			}, { step = 0.5, cores = { "RockDark", "RockDark" }, tiles = { ROCK, H.plates(0.9) }, color = rock })
			H.vein(K, g, "MagmaHot", leg[1], rad(60) * x, 0.1, leg[1].total - 0.1, VEIN)
			K:tile(g, "RockLight", K:at(leg[2], leg[2].total * 0.4), 0, 0.72, 0.8, 0.16, 6, 2, -0.3)
			local foot = CFrame.new(1.12 * x, 0.24, -0.08 + dz) * CFrame.Angles(0, rad(-8 * x), 0)
			K:block(g, "RockDark", foot, Vector3.new(0.96, 0.48, 1.24))
			K:block(g, "Rock", foot * CFrame.new(0, 0.18, 0.16), Vector3.new(0.86, 0.3, 0.9))
			for t = -1, 1 do
				local dirT = CFrame.Angles(0, rad(t * 22 - 8 * x), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
				local base = (foot * Vector3.new(t * 0.3, -0.04, -0.5)) + dirT * 0.1
				K:chain(g, { "Claw", "Claw", "ClawTip" }, base, (dirT - Vector3.new(0, 0.2, 0)).Unit, dirT:Cross(Vector3.yAxis), { n = 3, len = 0.5, w0 = 0.17, w1 = 0.09, bend = -30 })
			end
			-- arms held out, burning claws
			local ga = x == 1 and "ArmL" or "ArmR"
			local arm = H.limb(K, ga, {
				{ 1.35 * x, 5.05, -0.35, 0.44 },
				{ 1.78 * x, 4.24, -0.66, 0.36 },
				{ 1.58 * x, 3.72, -1.26, 0.32 },
			}, { step = 0.42, cores = { "RockDark", "RockDark" }, tiles = { H.plates(0.86), nil }, color = rock })
			H.vein(K, ga, "MagmaHot", arm[1], rad(80) * x, 0.05, arm[1].total - 0.05, VEIN)
			local hand = CFrame.lookAt(Vector3.new(1.56 * x, 3.64, -1.4), Vector3.new(1.5 * x, 3.2, -2.2))
			K:block(ga, "RockDark", hand, Vector3.new(0.56, 0.4, 0.5))
			for t = -1, 1 do
				local d = hand:VectorToWorldSpace(Vector3.new(t * 0.3, 0, -1)).Unit
				K:chain(ga, { "Claw", "Claw", "ClawTip" }, hand * Vector3.new(t * 0.17, 0, -0.2), d, hand.RightVector, { n = 3, len = 0.56, w0 = 0.13, w1 = 0.07, bend = 26 })
			end
			-- spikes of rock jutting from the elbows
			H.point(K, ga, "RockLight", Vector3.new(1.98 * x, 4.38, -0.44), Vector3.new(0.6 * x, 0.2, 0.8).Unit, 0.3)
		end

		-- head: a heavy rock brow over burning eyes, flame horns, magma cracks, fangs round a furnace mouth
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:block("Head", "Rock", hcf(0, 0.2, -0.36), Vector3.new(1.02, 0.76, 0.82))
		K:block("Head", "Rock", hcf(0, 0.08, -1.0), Vector3.new(0.84, 0.52, 0.72))
		K:block("Head", "Rock", hcf(0, 0.04, -1.46, -4, 0, 0), Vector3.new(0.72, 0.44, 0.36))
		K:block("Head", "RockDark", hcf(0, 0.08, -1.0, 0, 0, 45), Vector3.new(0.56, 0.56, 0.7))
		for k = 0, 3 do
			K:block("Head", "RockDark", hcf(0, 0.6 - k * 0.07, -0.2 - k * 0.32, -10, 0, 0), Vector3.new(0.62 - k * 0.08, 0.1, 0.3))
		end
		K:block("Head", "Mouth", hcf(0, -0.18, -0.98), Vector3.new(0.76, 0.06, 1.2))
		for _, x in { 1, -1 } do
			K:block("Head", "Rock", hcf(0.5 * x, 0.02, -0.36, 0, -10 * x, 6 * x), Vector3.new(0.32, 0.62, 0.74))
			K:block("Head", "RockDark", hcf(0.31 * x, 0.58, -0.74, -8, -12 * x, 16 * x), Vector3.new(0.5, 0.22, 0.56))
			H.eye(K, "Head", hcf(0.46 * x, 0.37, -0.82, 0, -30 * x, 14 * x), 0.22, 0.065)
			H.bolt(K, "Head", "MagmaHot", hp(0.5 * x, 0.14, -0.6), hp(0.43 * x, 0.12, -1.3), hv(0, 1, 0), 4, 0.06, 0.06)
			-- flame horns sweeping back over the neck
			H.curve(K, "Head", { "RockDark", "Rock", "Magma", "Flame" }, { hp(0.36 * x, 0.6, -0.3), hp(0.58 * x, 0.98, 0.1), hp(0.66 * x, 1.18, 0.6), hp(0.6 * x, 1.24, 1.0) }, 0.26, 0.07, 0.16)
			-- separate fangs along the upper jaw
			for k, z in { -0.66, -0.88, -1.1, -1.32, -1.52 } do
				H.fang(K, "Head", "Tooth", hp((0.36 - k * 0.012) * x, -0.18, z), hv(0, -1, 0.06), k % 2 == 0 and 0.2 or 0.15, 0.08)
			end
		end
		local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-22), 0, 0)
		local function jcf(px, py, pz)
			return JAW * CFrame.new(px, py, pz)
		end
		K:block("Jaw", "Rock", jcf(0, -0.15, -0.76), Vector3.new(0.82, 0.3, 1.3))
		K:block("Jaw", "Rock", jcf(0, -0.13, -1.46), Vector3.new(0.64, 0.28, 0.3))
		K:block("Jaw", "RockDark", jcf(0, -0.32, -0.72), Vector3.new(0.66, 0.08, 1.2))
		K:block("Jaw", "Mouth", jcf(0, 0.01, -0.84), Vector3.new(0.62, 0.05, 1.16))
		for _, x in { 1, -1 } do
			for k, z in { -0.6, -0.84, -1.08, -1.32 } do
				H.fang(K, "Jaw", "Tooth", JAW * Vector3.new((0.32 - k * 0.012) * x, 0.0, z), JAW:VectorToWorldSpace(Vector3.new(0, 1, -0.05)).Unit, k % 2 == 1 and 0.18 or 0.13, 0.075)
			end
			K:spike("Jaw", "RockLight", JAW * Vector3.new(0.42 * x, -0.22, -0.4), JAW:VectorToWorldSpace(Vector3.new(0.6 * x, -0.4, 0.6)).Unit, JAW:VectorToWorldSpace(Vector3.yAxis), 0.24, 0.1)
		end
		GK.lids(K, Color3.fromHex("2A1812"))
	end,
}
