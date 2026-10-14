local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Uncommon / ice: a glacier king crab. Not a low shore crab: it stands tall on three pairs of long,
-- spindly, spiked legs with the knees high above its back. A domed deep-blue carapace bristling all over with frost
-- spikes, a rim of long ice thorns, ice crystals breaking through the top, an ice rostrum jutting between its eyes.
-- Face: cyan eyes on short stalks under spiked brows, layered mouthparts round a frost-glowing mouth. Two long spiked
-- arms, the right one ending in a much bigger crusher claw.
local LEGZ = { -0.38, 0.14, 0.62 }

local joints = {
	ClawL = { 0.78, 1.96, -0.6 },
	ClawR = { -0.78, 1.96, -0.6 },
	EyeL = { 0.22, 2.24, -0.78 },
	EyeR = { -0.22, 2.24, -0.78 },
}
for i, z in LEGZ do
	local l = ({ "A", "B", "C" })[i]
	joints["Leg" .. l .. "L"] = { 1.0, 2.0, z }
	joints["Leg" .. l .. "R"] = { -1.0, 2.0, z }
end

return {
	Seed = 109,
	Vary = 0.05,
	Gait = "Scuttle",
	Emotes = { "ClawSnap", "Look" },
	Palette = {
		Shell = "3F5878",
		ShellDark = "293C57",
		ShellLight = "6F8EB2",
		Belly = "B3C3D3",
		Spike = { "A9E1FF", Material = "Ice" },
		SpikeTip = { "E0F3FF", Material = "Ice" },
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		IceGlow = { "4FD2FF", Neon = true },
		Claw = "3F5878",
		ClawDark = { "8FD3F5", Material = "Ice" },
		Tooth = { "E0F3FF", Material = "Ice" },
		Mouth = "1A1430",
		Eye = { "55E0FF", Neon = true },
		Socket = "0C1220",
	},
	Joints = joints,
	Build = function(K)
		local function shellColor(th, ring)
			local a = math.deg(math.abs(th))
			if a < 30 then
				return "ShellDark"
			elseif a < 70 then
				return ring % 2 == 0 and "Shell" or "ShellDark"
			end
			return "ShellLight"
		end
		-- a domed carapace raised high, narrow at the face, broad behind
		local shell = K:tube("Body", {
			{ 0, 2.06, -0.74, rx = 0.66, ru = 0.36, rd = 0.3 },
			{ 0, 2.22, -0.18, rx = 1.14, ru = 0.56, rd = 0.38 },
			{ 0, 2.2, 0.38, rx = 1.24, ru = 0.54, rd = 0.38 },
			{ 0, 2.04, 0.84, rx = 0.84, ru = 0.38, rd = 0.3 },
		}, { step = 0.32, core = "ShellDark", coreScale = 0.76, tile = { w = 0.56, t = 0.13, lift = 6, jitter = 2, sink = 0.5, overlap = 1.1 }, belly = { key = "Belly", key2 = "Belly", arc = 60, t = 0.1, wide = 1.05 }, color = shellColor })
		-- frost spikes bristling all over the carapace
		for s = 0.2, shell.total - 0.15, 0.3 do
			local smp = K:at(shell, s)
			local k = math.floor(s / 0.3)
			for j = -2, 2 do
				local th = rad(j * 30 + (k % 2) * 15 - 7 + K:rand(-4, 4))
				local pos, nrm = K:surface(smp, th, -0.06)
				local d = (nrm + Vector3.new(0, 0.35, 0)).Unit
				K:chain("Body", { "ShellLight", "SpikeTip" }, pos, d, smp.T, { n = 2, len = 0.2 + K:rand(0, 0.08), w0 = 0.14, w1 = 0.08, bend = 0, tipH = 0.1 })
			end
		end
		-- a rim of long ice thorns round the edge
		for s = 0.1, shell.total - 0.05, 0.3 do
			local smp = K:at(shell, s)
			for _, x in { 1, -1 } do
				local pos, nrm = K:surface(smp, rad(84) * x, 0.05)
				K:chain("Body", { "Spike", "SpikeTip" }, pos, (nrm + smp.U * 0.25 + smp.T * 0.1).Unit, smp.T, { n = 2, len = 0.4, w0 = 0.14, w1 = 0.08, bend = 0, tipH = 0.12 })
			end
		end
		-- ice crystals breaking through the top
		local ICE = { "Ice", "IceDeep", "IceGlow", "Ice" }
		local top, nrm = K:surface(K:at(shell, shell.total * 0.55), 0, 0.06)
		H.crystal(K, "Body", ICE, top, (nrm + Vector3.new(0, 0, 0.3)).Unit, 0.95, 5, 26)
		for _, x in { 1, -1 } do
			local p2, n2 = K:surface(K:at(shell, shell.total * 0.3), rad(36) * x, 0.06)
			H.crystal(K, "Body", ICE, p2, (n2 + Vector3.new(0, 0.6, 0)).Unit, 0.55, 3, 24)
		end
		-- the face: an ice rostrum between the eyes, layered mouthparts round a frost-glowing mouth
		H.curve(K, "Body", { "ShellDark", "Ice", "SpikeTip" }, { Vector3.new(0, 2.3, -0.8), Vector3.new(0, 2.4, -1.12), Vector3.new(0, 2.56, -1.36) }, 0.2, 0.08, 0.14)
		K:block("Body", "ShellDark", CFrame.new(0, 2.0, -0.9) * CFrame.Angles(rad(-14), 0, 0), Vector3.new(0.9, 0.42, 0.16))
		K:block("Body", "Mouth", CFrame.new(0, 1.86, -0.98), Vector3.new(0.46, 0.2, 0.08))
		K:block("Body", "IceGlow", CFrame.new(0, 1.86, -1.0), Vector3.new(0.3, 0.05, 0.04))
		for i, o in { { 1.98, 0.6 }, { 1.78, 0.52 }, { 1.66, 0.38 } } do
			for _, x in { 1, -1 } do
				K:block("Body", i % 2 == 0 and "ShellLight" or "Shell", CFrame.new(0.15 * x, o[1], -1.02 - i * 0.02) * CFrame.Angles(rad(8), 0, rad(-10 * x)), Vector3.new(0.22, 0.12, 0.08))
			end
		end
		for _, x in { 1, -1 } do
			K:spike("Body", "Tooth", Vector3.new(0.12 * x, 1.82, -1.04), Vector3.new(-0.3 * x, -1, -0.2).Unit, Vector3.zAxis, 0.12, 0.05)
			-- eyes on short stalks under spiked brows
			local ge = x == 1 and "EyeL" or "EyeR"
			K:tube(ge, {
				{ 0.22 * x, 2.22, -0.76, rx = 0.08 },
				{ 0.3 * x, 2.52, -0.9, rx = 0.07 },
			}, { step = 0.2, ref = Vector3.xAxis, core = "ShellDark", coreScale = 0.98 })
			K:block(ge, "Socket", CFrame.new(0.31 * x, 2.6, -0.92) * CFrame.Angles(0, rad(45), 0), Vector3.new(0.17, 0.15, 0.17))
			K:block(ge, "Eye", CFrame.new(0.31 * x, 2.62, -1.0) * CFrame.Angles(0, 0, rad(14 * x)), Vector3.new(0.14, 0.06, 0.04))
			K:block(ge, "ShellDark", CFrame.new(0.3 * x, 2.7, -0.98) * CFrame.Angles(rad(-12), 0, rad(22 * x)), Vector3.new(0.26, 0.07, 0.14))
			K:spike(ge, "Spike", Vector3.new(0.37 * x, 2.74, -0.94), Vector3.new(0.5 * x, 1, 0.3).Unit, Vector3.zAxis, 0.14, 0.05)
			-- long spiked arms; the right one ends in a much bigger crusher claw
			local gc = x == 1 and "ClawL" or "ClawR"
			local cs = x == 1 and 0.9 or 1.3
			K:scaled(Vector3.new(0.78 * x, 1.96, -0.6), cs, function()
				local arm = H.limb(K, gc, {
					{ 0.78 * x, 1.96, -0.6, 0.15 },
					{ 1.26 * x, 2.2, -1.0, 0.14 },
					{ 1.2 * x, 2.04, -1.42, 0.15 },
				}, { step = 0.22, cores = { "ShellDark", "Shell" } })
				for _, sg in arm do
					local smp = K:at(sg, sg.total * 0.5)
					H.point(K, gc, "Spike", smp.p + Vector3.new(0, 0.24, 0), Vector3.new(0.3 * x, 1, 0).Unit, 0.12)
				end
				local palm = CFrame.lookAt(Vector3.new(1.18 * x, 2.02, -1.62), Vector3.new(1.12 * x, 1.86, -2.4)) * CFrame.Angles(0, 0, rad(-16 * x))
				K:block(gc, "Claw", palm, Vector3.new(0.48, 0.46, 0.6))
				K:block(gc, "ShellLight", palm * CFrame.new(0, 0.18, 0.02) * CFrame.Angles(rad(-8), 0, 0), Vector3.new(0.38, 0.14, 0.52))
				local fwd = palm:VectorToWorldSpace(Vector3.new(0, 0, -1))
				local up = palm:VectorToWorldSpace(Vector3.yAxis)
				local side = palm:VectorToWorldSpace(Vector3.xAxis)
				K:chain(gc, { "Claw", "ClawDark", "SpikeTip" }, palm * Vector3.new(0, -0.12, -0.28), (fwd - up * 0.1).Unit, side, { n = 3, len = 0.62, w0 = 0.26, w1 = 0.1, bend = 14, depth = 0.8 })
				K:chain(gc, { "Claw", "ClawDark", "SpikeTip" }, palm * Vector3.new(0, 0.14, -0.24), (fwd + up * 0.5).Unit, side, { n = 3, len = 0.54, w0 = 0.22, w1 = 0.09, bend = -22, depth = 0.8 })
				H.teeth(K, gc, "Tooth", palm * Vector3.new(0, -0.02, -0.36), palm * Vector3.new(0, 0.0, -0.72), 3, up, side, 0.06, 0.04)
				H.point(K, gc, "Spike", palm * Vector3.new(0.12 * x, 0.32, 0.1), (up + side * 0.3 * x).Unit, 0.13)
			end)
			-- three pairs of long spindly legs, knees high above the back, spikes along the thighs
			for i, z in LEGZ do
				local g = "Leg" .. ({ "A", "B", "C" })[i] .. (x == 1 and "L" or "R")
				local fan = ({ -0.5, 0.0, 0.5 })[i]
				local reach = i == 2 and 0.12 or 0
				local knee = Vector3.new((1.9 + reach) * x, 2.86, z + fan * 0.8)
				local mid = Vector3.new((2.5 + reach) * x, 1.9, z + fan * 1.25)
				local ankle = Vector3.new((2.62 + reach) * x, 0.42, z + fan * 1.5)
				local leg = H.limb(K, g, {
					{ 1.0 * x, 2.0, z, 0.16 },
					{ knee.X, knee.Y, knee.Z, 0.13 },
					{ mid.X, mid.Y, mid.Z, 0.1 },
					{ ankle.X, ankle.Y, ankle.Z, 0.075 },
				}, { step = 0.26, cores = { "Shell", "ShellDark", "Shell" } })
				K:block(g, "ShellLight", CFrame.lookAt(mid, mid + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.15, 0.15, 0.15))
				K:block(g, "ShellLight", CFrame.lookAt(knee, knee + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.2, 0.2, 0.2))
				for _, f in { 0.35, 0.7 } do
					local smp = K:at(leg[1], leg[1].total * f)
					H.point(K, g, "Spike", smp.p + Vector3.new(0, 0.2, 0), Vector3.new(0.2 * x, 1, 0).Unit, 0.11)
				end
				local smp2 = K:at(leg[2], leg[2].total * 0.4)
				H.point(K, g, "Spike", smp2.p + Vector3.new(0.17 * x, 0, 0), Vector3.new(x, 0.3, 0).Unit, 0.1)
				H.point(K, g, "SpikeTip", Vector3.new(ankle.X + 0.04 * x, 0.02, ankle.Z), Vector3.new(0.1 * x, -1, 0), 0.12)
				K:block(g, "ShellDark", CFrame.lookAt(ankle, Vector3.new(ankle.X + 0.04 * x, 0.1, ankle.Z)), Vector3.new(0.12, 0.12, 0.36))
			end
		end
	end,
}
