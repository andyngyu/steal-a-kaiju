local rad = math.rad
local H = require(script.Parent.Helpers)

-- Storm Spires / Mythic / storm: the raijin wyrm, an eastern storm dragon riding its own thundercloud. A long storm-grey
-- serpent body with a gold-scaled belly: the back half curled round on top of a heaped dark cloud, the front reared
-- straight up from it so it stands tall instead of lying low. Four short legs with gold claws, the front pair reaching
-- out. A thundercloud mane heaps along its whole spine with lightning in it, white locks stream off the neck, a
-- storm-cloud tuft at the tail's end. Behind its raised shoulders floats Raijin's ring: a gold hoop of red thunder
-- drums, thick yellow lightning jumping from drum to drum. Head: a horned dragon's held high, gold horns with tines, a
-- bushy white brow, long whiskers glowing yellow at the tips, a cloud beard and lightning glowing in its throat.
local SCALE = 1.65
local LIFT = Vector3.new(0, 0.9, 0)
local function vec(v)
	return typeof(v) == "Vector3" and v or Vector3.new(v[1], v[2], v[3])
end
local function about(p, ax, ay)
	return CFrame.new(p) * CFrame.Angles(ax or 0, ay or 0, 0) * CFrame.new(-p)
end
local J0 = {}
for k, v in H.SERPENT_JOINTS do
	J0[k] = vec(v)
end
J0.LegFL = Vector3.new(0.46, 0.62, 0.42)
J0.LegFR = Vector3.new(-0.46, 0.62, 0.42)
J0.LegBL = Vector3.new(0.4, 0.54, 2.62)
J0.LegBR = Vector3.new(-0.4, 0.54, 2.62)
-- the pose (build space, before the lift): the front reared up in two bends, about the third coil's joint and then the
-- second's; the neck brought back upright; the head levelled; the fourth coil and the tail curled round on the cloud
local R2 = about(J0.Seg3, rad(40))
local R1 = about(R2 * J0.Seg2, rad(32)) * R2
local N = about(R1 * J0.Neck, rad(-43)) * R1
local U = about(N * J0.Head, rad(-29)) * N
local Y4 = about(J0.Seg4, 0, rad(70))
local YT = about(Y4 * J0.Tail, 0, rad(70)) * Y4
local POSE = {
	Seg2 = R2,
	Seg1 = R1,
	LegFL = R1,
	LegFR = R1,
	Neck = N,
	Head = U,
	Jaw = U,
	Tongue = U,
	Seg4 = Y4,
	Tail = YT,
}
local JOINTS = {}
for k, v in J0 do
	JOINTS[k] = (POSE[k] or CFrame.identity) * v + LIFT
end
JOINTS.Cloud = Vector3.new(0.4, 0.55, 2.5)
local PARENTS = {}
for k, v in H.SERPENT_PARENTS do
	PARENTS[k] = v
end
PARENTS.LegFL = "Seg1"
PARENTS.LegFR = "Seg1"
PARENTS.LegBL = "Seg3"
PARENTS.LegBR = "Seg3"
local RING_C = Vector3.new(0, 3.05, 1.8) + LIFT
local RING_R = 1.4

return {
	Seed = 651,
	Vary = 0.04,
	Scale = SCALE,
	Gait = "Slither",
	Emotes = { "RearUp", "Look" },
	Palette = {
		Hide = { "5A606C", Material = "Slate" },
		HideDark = { "3A3E48", Material = "Slate" },
		HideLight = { "7E8492", Material = "Slate" },
		Back = { "24272E", Material = "Slate" },
		Belly = "E0BC5C",
		Belly2 = "C8A040",
		Horn = "D8A830",
		HornLight = "F2D070",
		Cloud = "C8CED8",
		CloudLight = "EEF1F5",
		CloudDark = "8A92A0",
		Storm = "5A606C",
		StormDark = "363A44",
		Thunder = "7A8290",
		ThunderLight = "A4ACB8",
		Drum = "8A3A24",
		DrumDark = "5A2414",
		DrumHead = "EADFC4",
		DrumRim = "D8A830",
		Tomoe = "B02A2A",
		Bolt = { "FFC93A", Neon = true },
		BoltHot = { "FFEFA8", Neon = true },
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
							local p = K:surface(smp, rad(24), -0.34)
							H.zap(K, g, { "Bolt", "BoltHot" }, p - smp.T * 0.22, p + smp.T * 0.22, smp.R, 3, 0.09, 0.07)
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
				-- a storm-cloud tuft at the end of the tail
				local tip = K:at(segs.Tail, segs.Tail.total)
				H.cloud(K, "Tail", { "Cloud", "CloudLight", "CloudDark" }, tip.p + Vector3.new(0, 0.2, 0.1), Vector3.new(0.3, 0.2, 0.3), 9)
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
					-- a bushy white brow and long whiskers glowing yellow at the tips
					K:chain("Head", { "CloudLight", "Cloud" }, hp(0.24 * x, 0.42, -0.62), hv(0.45 * x, 0.35, 0.8), hv(0, 1, 0), { n = 2, len = 0.46, w0 = 0.16, w1 = 0.1, bend = 0, depth = 0.6 })
					K:chain("Head", { "HornLight", "Horn", "Horn", "Bolt" }, hp(0.2 * x, -0.04, -1.22), hv(0.55 * x, -0.25, 0.8), hv(0, 1, 0), { n = 4, len = 1.5, w0 = 0.09, w1 = 0.06, bend = -12 * x, tip = false })
					-- antler tines off the gold horns
					K:chain("Head", { "Horn", "HornLight" }, hp(0.34 * x, 0.66, 0.02), hv(0.3 * x, 1, -0.2), hv(1, 0, 0), { n = 2, len = 0.36, w0 = 0.1, w1 = 0.06, bend = 0 })
					K:chain("Head", { "Horn", "HornLight" }, hp(0.42 * x, 0.8, 0.32), hv(0.4 * x, 1, 0.1), hv(1, 0, 0), { n = 2, len = 0.3, w0 = 0.09, w1 = 0.05, bend = 0 })
					-- cloud tufts at the cheeks
					H.cloud(K, "Head", { "Cloud", "CloudLight", "CloudDark" }, hp(0.36 * x, 0.0, -0.1), Vector3.new(0.14, 0.12, 0.18), 4)
				end
				H.cloud(K, "Head", { "CloudLight", "Cloud" }, hp(0, 0.44, 0.04), Vector3.new(0.2, 0.12, 0.2), 5)
				K:block("Head", "Bolt", hcf(0, -0.12, -0.5), Vector3.new(0.18, 0.04, 0.24))
			end,
		})

		-- pose it: move each group's own blocks (already scaled by the builder), then lift everything onto the cloud
		local function scaled(cf)
			return CFrame.new(cf.Position * SCALE) * cf.Rotation
		end
		for name, cf in POSE do
			local g = K.groups[name]
			if g then
				local m = scaled(cf)
				for _, d in g:GetChildren() do
					if d:IsA("BasePart") then
						d.CFrame = m * d.CFrame
					end
				end
			end
		end
		local lift = CFrame.new(LIFT * SCALE)
		for _, g in K.groups do
			for _, d in g:GetChildren() do
				if d:IsA("BasePart") then
					d.CFrame = lift * d.CFrame
				end
			end
		end

		-- Raijin's ring, a halo of thunder drums floating behind the raised shoulders
		local function ringAt(a)
			return RING_C + Vector3.new(math.sin(a) * RING_R, math.cos(a) * RING_R, 0)
		end
		local prev
		for deg = -148, 148, 8 do
			local p = ringAt(rad(deg))
			if prev then
				K:block("Seg1", "DrumRim", CFrame.lookAt((prev + p) / 2, p) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.12, 0.12, (p - prev).Magnitude + 0.06))
			end
			prev = p
		end
		local drums = {}
		for i, deg in { -132, -88, -44, 0, 44, 88, 132 } do
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
			H.zap(K, "Seg1", i % 2 == 0 and { "BoltHot", "Bolt" } or { "Bolt", "BoltHot" }, drums[i], drums[i + 1], Vector3.new(0, 0, 1), 3, 0.1, 0.12)
		end

		-- the thundercloud it rides: heaped puffs, dark and heavy underneath, bolts dropping out of its belly
		local C = JOINTS.Cloud
		H.cloud(K, "Cloud", { "Thunder", "Storm", "ThunderLight", "CloudDark" }, C + Vector3.new(0, 0.12, 0), Vector3.new(1.9, 0.36, 2.1), 34)
		H.cloud(K, "Cloud", { "StormDark", "Storm" }, C + Vector3.new(0, -0.18, 0), Vector3.new(1.6, 0.16, 1.8), 16)
		for _, o in { Vector3.new(-1.2, 0, -0.6), Vector3.new(1.4, 0, 0.4), Vector3.new(0.2, 0, 1.6), Vector3.new(-0.6, 0, 1.2) } do
			local p = C + o + Vector3.new(0, -0.1, 0)
			H.zap(K, "Cloud", { "Bolt", "BoltHot" }, p, p + Vector3.new(o.X * 0.2, -0.5, o.Z * 0.2), Vector3.xAxis, 3, 0.1, 0.08)
		end
	end,
}
