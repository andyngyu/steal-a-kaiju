local rad = math.rad
local H = require(script.Parent.Helpers)

-- Storm Spires / Mythic / storm: the raijin wyrm, an eastern storm dragon. A long violet serpent body, darker along the
-- back and pale cream underneath, on four short legs with gold claws. A thundercloud mane heaps along its whole spine,
-- white on top and grey underneath, lightning flickering in it, white locks streaming off the neck, a storm-cloud tuft
-- at the tail's end. Over its shoulders floats Raijin's ring: a gold hoop of thunder drums, red-brown with pale heads,
-- lightning jumping from drum to drum. Head: a horned dragon's with gold horns and tines, a bushy white brow, long
-- whiskers flickering blue at the tips, a cloud beard and a glow of lightning deep in its throat.
local SCALE = 1.65
local RING_C = Vector3.new(0, 0.62, 0.82)
local RING_R = 1.4
local JOINTS = {}
for k, v in H.SERPENT_JOINTS do
	JOINTS[k] = v
end
JOINTS.LegFL = { 0.46, 0.62, 0.42 }
JOINTS.LegFR = { -0.46, 0.62, 0.42 }
JOINTS.LegBL = { 0.4, 0.54, 2.62 }
JOINTS.LegBR = { -0.4, 0.54, 2.62 }
local PARENTS = {}
for k, v in H.SERPENT_PARENTS do
	PARENTS[k] = v
end
PARENTS.LegFL = "Seg1"
PARENTS.LegFR = "Seg1"
PARENTS.LegBL = "Seg3"
PARENTS.LegBR = "Seg3"

return {
	Seed = 651,
	Vary = 0.04,
	Scale = SCALE,
	Gait = "Slither",
	Emotes = { "RearUp", "Look" },
	Palette = {
		Hide = { "52308E", Material = "Slate" },
		HideDark = { "301C5C", Material = "Slate" },
		HideLight = { "7E5CC4", Material = "Slate" },
		Back = { "1C1038", Material = "Slate" },
		Belly = "ECE4D2",
		Belly2 = "D8CEB6",
		Horn = "D8A830",
		HornLight = "F2D070",
		Cloud = "DCE2EC",
		CloudLight = "F6F8FC",
		CloudDark = "9AA4B6",
		Drum = "8A3A24",
		DrumDark = "5A2414",
		DrumHead = "EADFC4",
		DrumRim = "D8A830",
		Tomoe = "B02A2A",
		Spark = { "FFE680", Neon = true },
		Arc = { "4AC8FF", Neon = true },
		Tooth = "F2EEE0",
		Mouth = "3A1238",
		Tongue = "8A2A5A",
		Eye = { "FFD84A", Neon = true },
		Socket = "0A0810",
		Claw = "D8A830",
		ClawTip = "F2D070",
	},
	Joints = JOINTS,
	Parents = PARENTS,
	Build = function(K)
		H.serpent(K, {
			color = H.skin({ stripe = 30, band = 70, flank = 104, every = 3, upper = "HideDark" }),
			crest = function(K, segs)
				-- the thundercloud mane heaped along the spine, white on top, grey underneath, lightning inside
				local k = 0
				for _, g in { "Neck", "Seg1", "Seg2", "Seg3", "Seg4" } do
					local smps = segs[g]
					local fade = g == "Seg4" and 0.7 or (g == "Seg3" and 0.85 or 1)
					for s = 0.1, smps.total - 0.1, 0.24 do
						local smp = K:at(smps, s)
						for _, t0 in { 0, 30, -30 } do
							local pos, nrm = K:surface(smp, rad(t0 + K:rand(-8, 8)), -0.06)
							local sz = (t0 == 0 and 0.48 or 0.36) * K:rand(0.85, 1.15) * fade
							local key = t0 == 0 and (k % 2 == 0 and "CloudLight" or "Cloud") or (k % 3 == 0 and "CloudDark" or "Cloud")
							K:block(g, key, CFrame.new(pos + nrm * sz * 0.25) * CFrame.Angles(rad(K:rand(-15, 15)), rad(K:rand(0, 90)), rad(K:rand(-15, 15))), Vector3.new(sz, sz * 0.72, sz))
							k += 1
						end
						if k % 4 == 0 then
							local p = K:surface(smp, rad(20), -0.3)
							H.bolt(K, g, "Spark", p - smp.T * 0.2, p + smp.T * 0.2, smp.R, 3, 0.05, 0.06)
						end
					end
				end
				-- white locks streaming back off the neck
				for s = 0.1, segs.Neck.total - 0.2, 0.2 do
					local smp = K:at(segs.Neck, s)
					for _, x in { 1, -1 } do
						local pos, nrm = K:surface(smp, rad(56) * x, 0.02)
						K:chain("Neck", { "CloudDark", "Cloud", "CloudLight" }, pos, (nrm + smp.T * 0.9).Unit, smp.R, { n = 3, len = 0.5, w0 = 0.15, w1 = 0.08, bend = -10, depth = 0.5 })
					end
				end
				-- a storm-cloud tuft at the end of the tail, a bolt dropping from it
				local tip = K:at(segs.Tail, segs.Tail.total)
				H.cloud(K, "Tail", { "Cloud", "CloudLight", "CloudDark" }, tip.p + Vector3.new(0, 0.2, 0.1), Vector3.new(0.3, 0.2, 0.3), 9, "Spark", 2)

				-- Raijin's ring: a gold hoop of thunder drums floating over the shoulders
				local function ringAt(a)
					return RING_C + Vector3.new(math.sin(a) * RING_R, math.cos(a) * RING_R, 0)
				end
				local prev
				for deg = -104, 104, 8 do
					local p = ringAt(rad(deg))
					if prev then
						K:block("Seg1", "DrumRim", CFrame.lookAt((prev + p) / 2, p) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.11, 0.11, (p - prev).Magnitude + 0.06))
					end
					prev = p
				end
				local drums = {}
				for i, deg in { -90, -60, -30, 0, 30, 60, 90 } do
					local a = rad(deg)
					local out = Vector3.new(math.sin(a), math.cos(a), 0)
					local c = ringAt(a) + out * 0.08
					local F = CFrame.lookAt(c, c + out)
					K:block("Seg1", "Drum", F, Vector3.new(0.52, 0.52, 0.36))
					K:block("Seg1", "DrumDark", F * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.52, 0.52, 0.32))
					for _, z in { -0.18, 0.18 } do
						K:block("Seg1", "DrumRim", F * CFrame.new(0, 0, z), Vector3.new(0.58, 0.58, 0.05))
						K:block("Seg1", "DrumRim", F * CFrame.new(0, 0, z) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.58, 0.58, 0.05))
					end
					K:block("Seg1", "DrumHead", F * CFrame.new(0, 0, -0.2), Vector3.new(0.44, 0.44, 0.03))
					K:block("Seg1", "DrumHead", F * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.44, 0.44, 0.03))
					K:block("Seg1", "Tomoe", F * CFrame.new(0, 0, -0.215) * CFrame.Angles(0, 0, rad(i * 20)), Vector3.new(0.18, 0.18, 0.02))
					drums[i] = c + out * 0.22
				end
				for i = 1, #drums - 1 do
					H.bolt(K, "Seg1", i % 2 == 0 and "Spark" or "Arc", drums[i], drums[i + 1], Vector3.new(0, 0, 1), 4, 0.05, 0.1)
				end
				for _, i in { 2, 4, 6 } do
					local a = rad(({ -60, -30, 0, 30, 60 })[i - 1])
					local out = Vector3.new(math.sin(a), math.cos(a), 0)
					H.bolt(K, "Seg1", "Spark", drums[i], drums[i] + out * 0.6 + Vector3.new(0, 0, 0.1), Vector3.new(0, 0, 1), 3, 0.05, 0.08)
				end

				-- four short legs with gold claws, cloud wisps at the elbows
				local skin = H.skin({ stripe = 30, band = 70, flank = 104, every = 3, upper = "HideDark" })
				for _, x in { 1, -1 } do
					for _, leg in { { x == 1 and "LegFL" or "LegFR", 0.42, 0.62, 1 }, { x == 1 and "LegBL" or "LegBR", 2.62, 0.54, 0.86 } } do
						local g, z, y, s = leg[1], leg[2], leg[3], leg[4]
						H.quadLeg(K, g, {
							{ 0.46 * x * s + (1 - s) * 0.06 * x, y, z, 0.2 * s },
							{ 0.9 * x * s + (1 - s) * 0.1 * x, y - 0.06, z - 0.12, 0.15 * s },
							{ 0.98 * x * s + (1 - s) * 0.1 * x, 0.18, z - 0.26, 0.11 * s },
						}, { step = 0.18, cores = { "Hide", "HideDark" }, tiles = { H.plates(0.22, 5, 0.08), nil }, color = skin, foot = { size = Vector3.new(0.3, 0.14, 0.34) * s, key = "HideDark" }, toes = 4, claw = { len = 0.26, w = 0.06, curl = 44 }, yaw = 20 })
						H.cloud(K, g, { "Cloud", "CloudLight", "CloudDark" }, Vector3.new(0.9 * x * s, y + 0.02, z - 0.02), Vector3.new(0.16, 0.12, 0.18) * s, 5)
					end
				end
			end,
			head = function(K, hcf, hp, hv)
				for _, x in { 1, -1 } do
					-- a bushy white brow and long whiskers flickering blue at the tips
					K:chain("Head", { "CloudLight", "Cloud" }, hp(0.24 * x, 0.42, -0.62), hv(0.45 * x, 0.35, 0.8), hv(0, 1, 0), { n = 2, len = 0.46, w0 = 0.16, w1 = 0.1, bend = 0, depth = 0.6 })
					K:chain("Head", { "HornLight", "Cloud", "Cloud", "Arc" }, hp(0.2 * x, -0.04, -1.22), hv(0.55 * x, -0.25, 0.8), hv(0, 1, 0), { n = 4, len = 1.5, w0 = 0.08, w1 = 0.05, bend = -12 * x, tip = false })
					-- antler tines off the gold horns
					K:chain("Head", { "Horn", "HornLight" }, hp(0.34 * x, 0.66, 0.02), hv(0.3 * x, 1, -0.2), hv(1, 0, 0), { n = 2, len = 0.36, w0 = 0.1, w1 = 0.06, bend = 0 })
					K:chain("Head", { "Horn", "HornLight" }, hp(0.42 * x, 0.8, 0.32), hv(0.4 * x, 1, 0.1), hv(1, 0, 0), { n = 2, len = 0.3, w0 = 0.09, w1 = 0.05, bend = 0 })
					-- cloud tufts at the cheeks
					H.cloud(K, "Head", { "Cloud", "CloudLight", "CloudDark" }, hp(0.36 * x, 0.0, -0.1), Vector3.new(0.14, 0.12, 0.18), 4)
				end
				H.cloud(K, "Head", { "CloudLight", "Cloud" }, hp(0, 0.44, 0.04), Vector3.new(0.2, 0.12, 0.2), 5)
				K:block("Head", "Spark", hcf(0, -0.12, -0.5), Vector3.new(0.18, 0.04, 0.24))
			end,
		})
	end,
}
