local rad = math.rad
local H = require(script.Parent.Helpers)

-- Storm Spires / Mythic / storm: the raijin wyrm, an eastern storm dragon riding its own thundercloud. A long storm-grey
-- serpent body with a gold-scaled belly: the front reared straight up out of a heaped storm cloud, the back rising
-- behind it and the long tail winding round and round Raijin's ring, a gold hoop of red thunder drums floating behind
-- its shoulders with thick yellow lightning jumping from drum to drum. Four short legs with gold claws. A thundercloud
-- mane heaps along its spine with lightning in it, white locks stream off the neck, a storm-cloud tuft at the tail's
-- end. The cloud it rides: dark rounded billows of different sizes, lighter on top, lightning glowing inside and bolts
-- dropping out of its belly, wisps trailing off its edges. Head: a horned dragon's held high, gold horns with tines, a
-- bushy white brow, long whiskers glowing yellow at the tips, a cloud beard and lightning glowing in its throat.
local SCALE = 1.65
local LIFT = Vector3.new(0, 0.9, 0)
local C0 = Vector3.new(0, 3.05, 2.4) -- the halo's centre (before the lift)
local RING_R = 1.4
local function vec(v)
	return typeof(v) == "Vector3" and v or Vector3.new(v[1], v[2], v[3])
end
local function about(p, ax, ay)
	return CFrame.new(p) * CFrame.Angles(ax or 0, ay or 0, 0) * CFrame.new(-p)
end
-- a point round the halo: angle from the top (toward -X first), distance from its centre, offset out of its plane
local function rim(a, r, dz)
	return Vector3.new(math.sin(a) * r, C0.Y + math.cos(a) * r, C0.Z + (dz or 0))
end
-- moves a segment (joint J, lying along +Z with its back up +Y) so its joint sits at P, pointing along D, its back
-- turned toward `out`
local function aim(J, P, D, out)
	local up = (out - D * out:Dot(D)).Unit
	return CFrame.fromMatrix(P, up:Cross(D), up, D) * CFrame.new(-J)
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
-- second's; the neck brought back upright and the head levelled; the third and fourth coils rising behind toward the
-- halo's lower edge; the tail is rebuilt winding round the halo
local R2 = about(J0.Seg3, rad(40))
local R1 = about(R2 * J0.Seg2, rad(32)) * R2
local N = about(R1 * J0.Neck, rad(-43)) * R1
local U = about(N * J0.Head, rad(-29)) * N
local P3 = J0.Seg3
local D3 = (rim(rad(-150), 2.0) - P3).Unit
local T3 = aim(J0.Seg3, P3, D3, P3 + D3 * 0.47 - C0)
local P4 = P3 + D3 * (J0.Seg4.Z - J0.Seg3.Z)
local D4 = (rim(rad(-118), 2.0) - P4).Unit
local T4 = aim(J0.Seg4, P4, D4, P4 + D4 * 0.42 - C0)
local PT = P4 + D4 * (J0.Tail.Z - J0.Seg4.Z)
local POSE = {
	Seg2 = R2,
	Seg1 = R1,
	LegFL = R1,
	LegFR = R1,
	Neck = N,
	Head = U,
	Jaw = U,
	Tongue = U,
	Seg3 = T3,
	LegBL = T3,
	LegBR = T3,
	Seg4 = T4,
}
local JOINTS = {}
for k, v in J0 do
	JOINTS[k] = (POSE[k] or CFrame.identity) * v + LIFT
end
JOINTS.Tail = PT + LIFT
JOINTS.Cloud = Vector3.new(-0.3, 0.55, 2.1)
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
		Thunder = "545B68",
		ThunderLight = "7C8492",
		ThunderDark = "30343D",
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
		local skin = H.skin({ stripe = 30, band = 70, flank = 104, every = 3, upper = "HideDark" })
		-- a thundercloud mane puff on a tube's top
		local function manePuff(g, smp, t0, sz, k)
			local pos, nrm = K:surface(smp, rad(t0 + K:rand(-8, 8)), -0.06)
			local key = t0 == 0 and (k % 2 == 0 and "CloudLight" or "Cloud") or (k % 3 == 0 and "CloudDark" or "Cloud")
			K:block(g, key, CFrame.new(pos + nrm * sz * 0.25) * CFrame.Angles(rad(K:rand(-15, 15)), rad(K:rand(0, 90)), rad(K:rand(-15, 15))), Vector3.new(sz, sz * 0.72, sz))
		end
		H.serpent(K, {
			color = skin,
			crest = function(K, segs)
				-- the thundercloud mane heaped along the spine, white on top, grey underneath, lightning inside
				local k = 0
				for _, g in { "Neck", "Seg1", "Seg2", "Seg3", "Seg4" } do
					local smps = segs[g]
					local fade = g == "Seg4" and 0.8 or (g == "Seg3" and 0.9 or 1)
					for s = 0.1, smps.total - 0.1, 0.24 do
						local smp = K:at(smps, s)
						for _, t0 in { 0, 30, -30 } do
							manePuff(g, smp, t0, (t0 == 0 and 0.48 or 0.36) * K:rand(0.85, 1.15) * fade, k)
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
				-- four short legs with gold claws, cloud wisps at the elbows
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
		-- the stock tail is replaced by the one winding round the halo
		for _, d in K.groups.Tail:GetChildren() do
			if d:IsA("BasePart") then
				d:Destroy()
			end
		end

		-- pose it: move each group's own blocks (already scaled by the builder), then lift everything onto the cloud
		for name, cf in POSE do
			local g = K.groups[name]
			if g then
				local m = CFrame.new(cf.Position * SCALE) * cf.Rotation
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
		-- from here on, build in the final place (the lift included)
		local C = C0 + LIFT
		local function ringAt(a, r, dz)
			return rim(a, r or RING_R, dz) + LIFT
		end

		-- Raijin's ring, a halo of thunder drums floating behind the raised shoulders (in the tail's group, so the coils
		-- wound round it always stay on it)
		local prev
		for deg = -180, 180, 8 do
			local p = ringAt(rad(deg))
			if prev then
				K:block("Tail", "DrumRim", CFrame.lookAt((prev + p) / 2, p) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.12, 0.12, (p - prev).Magnitude + 0.06))
			end
			prev = p
		end
		local drums = {}
		for i, deg in { -132, -88, -44, 0, 44, 88, 132 } do
			local a = rad(deg)
			local out = Vector3.new(math.sin(a), math.cos(a), 0)
			local c = ringAt(a) + out * 0.08
			local F = CFrame.lookAt(c, c + out)
			K:block("Tail", "Drum", F, Vector3.new(0.52, 0.52, 0.36))
			K:block("Tail", "DrumDark", F * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.52, 0.52, 0.32))
			for _, z in { -0.18, 0.18 } do
				K:block("Tail", "DrumRim", F * CFrame.new(0, 0, z), Vector3.new(0.58, 0.58, 0.05))
				K:block("Tail", "DrumRim", F * CFrame.new(0, 0, z) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.58, 0.58, 0.05))
			end
			K:block("Tail", "DrumHead", F * CFrame.new(0, 0, -0.2), Vector3.new(0.44, 0.44, 0.03))
			K:block("Tail", "DrumHead", F * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.44, 0.44, 0.03))
			K:block("Tail", "Tomoe", F * CFrame.new(0, 0, -0.215) * CFrame.Angles(0, 0, rad(i * 20)), Vector3.new(0.18, 0.18, 0.02))
			drums[i] = c + out * 0.22
		end
		for i = 1, #drums - 1 do
			H.zap(K, "Tail", i % 2 == 0 and { "BoltHot", "Bolt" } or { "Bolt", "BoltHot" }, drums[i], drums[i + 1], Vector3.new(0, 0, 1), 3, 0.1, 0.12)
		end

		-- the tail: on from the fourth coil, winding one and a half turns round the hoop as it climbs over the top of the
		-- halo and down the far side, thinning to a storm-cloud tuft
		local start = PT + LIFT
		local rel = start - C
		local a0 = math.atan2(rel.X, rel.Y)
		local a1 = rad(160)
		local nodes = { { start.X, start.Y, start.Z, rx = 0.32, ru = 0.3, rd = 0.28 } }
		local N = 40
		for i = 1, N do
			local f = i / N
			local a = a0 + (a1 - a0) * f
			local psi = f * math.pi * 3
			local p = ringAt(a, RING_R + 0.62 * math.cos(psi), 0.62 * math.sin(psi))
			local r = 0.3 - 0.22 * f
			table.insert(nodes, { p.X, p.Y, p.Z, rx = r, ru = r * 0.94, rd = r * 0.86 })
		end
		local tail = K:tube("Tail", nodes, { step = 0.26, ref = Vector3.zAxis, core = "Hide", coreScale = 0.76, tile = { w = 0.4, t = 0.1, lift = 7, jitter = 1.5, sink = 0.5, overlap = 1.1 }, belly = { key = "Belly", key2 = "Belly2", arc = 46, t = 0.1, wide = 1.1 }, color = skin, trim = 0.1 })
		local k = 0
		for s = 0.2, tail.total - 0.4, 0.36 do
			local smp = K:at(tail, s)
			local f = s / tail.total
			manePuff("Tail", smp, 0, 0.42 * (1 - f * 0.55) * K:rand(0.85, 1.15), k)
			k += 1
		end
		local tip = K:at(tail, tail.total)
		H.cloud(K, "Tail", { "Cloud", "CloudLight", "CloudDark" }, tip.p + tip.T * 0.16, Vector3.new(0.26, 0.2, 0.26), 9)
		H.zap(K, "Tail", { "Bolt", "BoltHot" }, tip.p + tip.T * 0.2, tip.p + tip.T * 0.3 + Vector3.new(0.1, -0.7, 0), Vector3.zAxis, 3, 0.09, 0.08)

		-- the thundercloud it rides: rounded billows of different sizes in dark storm grey, lighter on top, lightning
		-- glowing inside it and bolts dropping out of its belly, wisps trailing off its edges
		local CC = JOINTS.Cloud
		local function billow(p, s, top)
			K:block("Cloud", top and "ThunderLight" or "Thunder", CFrame.new(p), Vector3.new(s, s * 0.72, s))
			K:block("Cloud", "Thunder", CFrame.new(p) * CFrame.Angles(0, rad(45), 0), Vector3.new(s * 0.94, s * 0.7, s * 0.94))
			K:block("Cloud", top and "CloudDark" or "ThunderLight", CFrame.new(p + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(0, rad(22), 0), Vector3.new(s * 0.66, s * 0.4, s * 0.66))
			K:block("Cloud", "ThunderDark", CFrame.new(p - Vector3.new(0, s * 0.26, 0)) * CFrame.Angles(0, rad(22), 0), Vector3.new(s * 0.8, s * 0.3, s * 0.8))
		end
		local puffs = {}
		for i = 0, 8 do
			local a = i / 9 * math.pi * 2 + K:rand(-0.2, 0.2)
			local r = K:rand(1.2, 1.6)
			table.insert(puffs, { CC + Vector3.new(math.cos(a) * r, K:rand(-0.08, 0.1), math.sin(a) * r * 1.1), K:rand(0.7, 1.05), false })
		end
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + 0.4
			table.insert(puffs, { CC + Vector3.new(math.cos(a) * 0.6, 0.18, math.sin(a) * 0.66), K:rand(1.0, 1.25), true })
		end
		table.insert(puffs, { CC + Vector3.new(0, 0.3, 0), 1.2, true })
		for _, p in puffs do
			billow(p[1], p[2], p[3])
		end
		-- lightning glowing in the gaps between the billows
		for i = 1, 8 do
			local a, b = puffs[i][1], puffs[i + 1][1]
			local m = a:Lerp(b, 0.5) + Vector3.new(0, K:rand(-0.05, 0.15), 0)
			if i % 2 == 0 then
				H.zap(K, "Cloud", { "Bolt", "BoltHot" }, m - (b - a).Unit * 0.3, m + (b - a).Unit * 0.3, Vector3.yAxis, 3, 0.1, 0.08)
			else
				K:block("Cloud", "Bolt", CFrame.new(m) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.22, 0.22, 0.22))
			end
		end
		-- bolts dropping out of its belly
		for _, i in { 1, 4, 7 } do
			local p = puffs[i][1] - Vector3.new(0, puffs[i][2] * 0.3, 0)
			H.zap(K, "Cloud", { "Bolt", "BoltHot" }, p, Vector3.new(p.X * 1.1, 0.02, p.Z), Vector3.xAxis, 3, 0.1, 0.08)
		end
		-- wisps trailing off the edges
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2 + 0.3
			local outw = Vector3.new(math.cos(a), 0, math.sin(a))
			local base = CC + outw * 1.7 + Vector3.new(0, K:rand(0, 0.2), 0)
			local d = (outw + Vector3.new(0, 0.12, 0.35)).Unit
			K:chain("Cloud", { "Thunder", "ThunderLight", "CloudDark" }, base, d, d:Cross(Vector3.yAxis).Unit, { n = 3, len = K:rand(0.8, 1.2), w0 = 0.34, w1 = 0.14, bend = 14, depth = 0.45, tip = false })
		end
	end,
}
