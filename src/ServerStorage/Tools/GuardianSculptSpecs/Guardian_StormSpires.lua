local rad = math.rad
local GK = require(script.Parent.GuardianKit)
local H = GK.H

-- Storm Spires guardian: Stormbringer, a storm titan. A towering charcoal tyrant, near-black down the back and slate
-- underneath, split by glowing yellow-white lightning seams that fork down its flanks, neck and tail. A row of iron
-- lightning rods stands up its spine, wound with copper coils and tipped with sparks, electric blue arcing from rod to
-- rod. A churning thundercloud mantle heaps over its shoulders with bolts dropping out of it; iron armour on the
-- shoulders and thighs; broken shackles on its wrists trailing lengths of chain; a lightning-rod spike on the tail.
-- Head: a massive horned bull-dragon skull under an iron brow, small yellow eyes, sparks crackling at the nostrils,
-- two great bone horns sweeping out and forward to glowing tips with lightning arcing between them, a smaller pair
-- swept back, and a jaw full of fangs around a throat glowing with lightning.
local HEAD = H.REX_HEAD
local HS = 1.14
local JOINTS = {}
for k, v in H.REX_JOINTS do
	JOINTS[k] = v
end
JOINTS.Jaw = HEAD.Position + (HEAD * H.REX_HINGE - HEAD.Position) * HS

return {
	Seed = 661,
	Vary = 0.05,
	Scale = 4.4,
	RootSize = { 8.3, 6.6, 10.5 },
	HipHeight = 1.78,
	Palette = {
		Hide = { "2E323C", Material = "Slate" },
		HideDark = { "1A1D24", Material = "Slate" },
		HideLight = { "4A505E", Material = "Slate" },
		Back = { "101216", Material = "Slate" },
		Belly = { "5A6070", Material = "Slate" },
		Belly2 = { "4A505E", Material = "Slate" },
		Armour = { "3A3E48", Material = "Slate" },
		ArmourLight = { "5A606C", Material = "Slate" },
		SeamLip = { "0C0E12", Material = "Slate" },
		Crack = { "FFC830", Neon = true },
		Rod = { "6A707C", Material = "Metal" },
		RodDark = { "3A3E46", Material = "Metal" },
		Copper = "B8743A",
		CopperDark = "7A4A22",
		Chain = { "5A5E66", Material = "Metal" },
		ChainDark = { "2E3138", Material = "Metal" },
		Cloud = "4E5564",
		CloudDark = "2E333E",
		CloudLight = "7A8292",
		Spark = { "FFE680", Neon = true },
		Arc = { "4AC8FF", Neon = true },
		Horn = "D8D0BC",
		HornDark = "8A8270",
		Tooth = "EEEADC",
		Mouth = "1A0A10",
		MouthGlow = { "FFE680", Neon = true },
		Eye = { "FFD84A", Neon = true },
		Socket = "060608",
		Claw = "16181C",
		ClawTip = "C8C4B8",
	},
	Joints = JOINTS,
	Parents = { Jaw = "Head" },
	Build = function(K)
		-- an iron lightning rod: a tapering shaft wound with copper coils, a spark at the tip; returns the tip
		local function rod(g, base, dir, len, w)
			K:chain(g, { "RodDark", "Rod", "Rod" }, base, dir, Vector3.xAxis:Cross(dir).Magnitude > 0.1 and Vector3.xAxis or Vector3.zAxis, { n = 3, len = len, w0 = w, w1 = w * 0.55, bend = 0, tip = false })
			for k = 1, 3 do
				local p = base + dir * len * (0.18 + k * 0.17)
				local ww = w * (1 - (k * 0.17) * 0.5) * 1.5
				K:block(g, k % 2 == 0 and "Copper" or "CopperDark", CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, rad(45)), Vector3.new(ww, ww, w * 0.35))
			end
			local tip = base + dir * (len + w * 0.3)
			K:block(g, "Spark", CFrame.lookAt(tip, tip + dir) * CFrame.Angles(0, 0, rad(45)), Vector3.new(w * 0.9, w * 0.9, w * 0.9))
			return tip
		end

		H.rex(K, {
			color = H.skin({ stripe = 32, band = 68, flank = 104, every = 3, upper = "HideDark" }),
			tiles = { torso = H.plates(0.66), neck = H.plates(0.6), tail = H.plates(0.52, 5) },
			thighArmour = "Armour",
			brow = "Armour",
			tailTip = { "RodDark", "Spark" },
			headScale = HS,
			crest = function(K, torso, neck, tail)
				-- glowing lightning seams sunk into the hide, forking down the flanks, neck and tail
				for _, seg in { { "Body", torso, 0.06, 3 }, { "Head", neck, 0.06, 1 }, { "Tail", tail, 0.5, 2 } } do
					local g, samples, to, forks = seg[1], seg[2], seg[3], seg[4]
					for _, x in { 1, -1 } do
						H.vein(K, g, "Crack", samples, rad(70) * x, 0.08, samples.total - to, { width = 0.12, height = 0.16, lift = 0.15, wander = 26, forks = forks, forkSteps = 3, forkTurn = 40, step = 0.26, lip = "SeamLip", lipW = 0.09 })
						H.cracks(K, g, "Crack", samples, { rad(100) * x }, 0.2, samples.total - to - 0.1, 0.3, 0.09, 0.14)
					end
				end
				-- the lightning rods up the spine, electric blue arcing from tip to tip
				local tips = {}
				for _, seg in { { "Head", neck, 0.3, 0.7, 0.62 }, { "Body", torso, 0.42, 1.25, 0.86 }, { "Tail", tail, 0.46, 0.8, 0.55 } } do
					local g, samples, every, len, to = seg[1], seg[2], seg[3], seg[4], seg[5]
					for s = 0.18, samples.total * to, every do
						local smp = K:at(samples, s)
						local base = smp.p + smp.U * smp.ru * 0.8
						local d = (smp.U + smp.T * 0.3).Unit
						local l = len * (g == "Tail" and (1 - s / samples.total * 0.6) or 1) * K:rand(0.9, 1.1)
						table.insert(tips, { g = g, p = rod(g, base, d, l, 0.16) })
					end
				end
				for i = 1, #tips - 1 do
					if tips[i].g == tips[i + 1].g then
						H.bolt(K, tips[i].g, "Arc", tips[i].p, tips[i + 1].p, Vector3.xAxis, 4, 0.07, 0.12)
					end
				end
			end,
			extras = function(K, parts)
				for _, x in { 1, -1 } do
					-- iron armour over the shoulders
					for i, o in { { 0.12, 62, 0.66 }, { 0.42, 74, 0.58 }, { 0.26, 88, 0.5 } } do
						K:tile("Body", i % 2 == 0 and "ArmourLight" or "Armour", K:at(parts.torso, o[1]), rad(o[2]) * x, o[3], o[3] * 0.9, 0.16, 12, 3, -0.3)
					end
					-- the thundercloud mantle heaped over the shoulders, bolts dropping out of it
					for _, s in { 0.1, 0.5, 0.9 } do
						local smp = K:at(parts.torso, s)
						local pos, nrm = K:surface(smp, rad(48) * x, -0.1)
						H.cloud(K, "Body", { "Cloud", "CloudDark", "CloudLight" }, pos + nrm * 0.2, Vector3.new(0.56, 0.34, 0.5), 11, "Spark", s == 0.5 and 2 or 1)
					end
					-- broken shackles on the wrists, lengths of chain hanging from them
					local g = x == 1 and "ArmL" or "ArmR"
					local wrist = Vector3.new(0.9 * x, 2.56, -1.5)
					K:block(g, "ChainDark", CFrame.lookAt(wrist, wrist + Vector3.new(0, -0.3, -1)), Vector3.new(0.34, 0.34, 0.18))
					K:block(g, "Chain", CFrame.lookAt(wrist, wrist + Vector3.new(0, -0.3, -1)) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.3, 0.3, 0.14))
					local p = wrist + Vector3.new(0, -0.16, 0.02)
					for k = 0, 5 do
						local step = Vector3.new(0.02 * x, -0.17, 0.05 + k * 0.012)
						K:block(g, k % 2 == 0 and "Chain" or "ChainDark", CFrame.lookAt(p + step / 2, p + step) * CFrame.Angles(0, 0, rad(k % 2 == 0 and 0 or 90)), Vector3.new(0.12, 0.05, 0.22))
						p += step
					end
				end
			end,
			headBuild = function(K, HEAD, hcf, hp, hv)
				-- a massive horned bull-dragon skull under an iron brow
				K:block("Head", "Hide", hcf(0, 0.24, -0.4), Vector3.new(1.08, 0.82, 0.9))
				K:block("Head", "Hide", hcf(0, 0.12, -1.1), Vector3.new(0.86, 0.58, 0.82))
				K:block("Head", "HideDark", hcf(0, 0.06, -1.56, -6, 0, 0), Vector3.new(0.76, 0.48, 0.36))
				K:block("Head", "Armour", hcf(0, 0.6, -0.68, -10, 0, 0), Vector3.new(1.0, 0.24, 0.52))
				K:block("Head", "ArmourLight", hcf(0, 0.48, -1.06, -16, 0, 0), Vector3.new(0.54, 0.16, 0.6))
				K:block("Head", "Mouth", hcf(0, -0.16, -1.04), Vector3.new(0.74, 0.06, 1.3))
				K:block("Head", "MouthGlow", hcf(0, -0.15, -0.7), Vector3.new(0.4, 0.05, 0.5))
				local tips = {}
				for _, x in { 1, -1 } do
					K:block("Head", "Hide", hcf(0.52 * x, 0.04, -0.36, 0, -10 * x, 6 * x), Vector3.new(0.32, 0.62, 0.76))
					K:block("Head", "HideDark", hcf(0.3 * x, 0.38, -1.12, -4, 0, -26 * x), Vector3.new(0.28, 0.12, 0.74))
					K:block("Head", "Armour", hcf(0.34 * x, 0.62, -0.74, -8, -12 * x, 16 * x), Vector3.new(0.46, 0.2, 0.52))
					H.eye(K, "Head", hcf(0.48 * x, 0.42, -0.86, 0, -30 * x, 12 * x), 0.2, 0.065)
					-- sparks crackling at the nostrils
					K:block("Head", "Socket", hcf(0.18 * x, 0.14, -1.75, -6, 0, 0), Vector3.new(0.14, 0.12, 0.04))
					H.bolt(K, "Head", "Spark", hp(0.18 * x, 0.12, -1.76), hp(0.38 * x, 0.02, -2.04), hv(0, 1, 0), 3, 0.04, 0.05)
					-- the great horns sweeping out and forward to glowing tips, a smaller pair swept back
					local horn = { hp(0.46 * x, 0.66, -0.36), hp(1.0 * x, 0.92, -0.22), hp(1.42 * x, 1.36, -0.42), hp(1.54 * x, 1.84, -0.9) }
					H.curve(K, "Head", { "HornDark", "Horn", "Horn", "Horn" }, horn, 0.44, 0.12, 0.14)
					local tip = horn[4] + (horn[4] - horn[3]).Unit * 0.12
					K:block("Head", "Spark", CFrame.new(tip), Vector3.new(0.16, 0.16, 0.16))
					tips[x] = tip
					H.curve(K, "Head", { "HornDark", "Horn", "Horn" }, { hp(0.34 * x, 0.72, -0.08), hp(0.58 * x, 1.0, 0.3), hp(0.68 * x, 1.16, 0.78) }, 0.24, 0.08, 0.12)
					K:spike("Head", "Armour", hp(0.6 * x, -0.04, -0.12), hv(0.6 * x, 0.1, 0.8), hv(0, 1, 0), 0.3, 0.1)
					H.teeth(K, "Head", "Tooth", hp(0.38 * x, -0.17, -0.62), hp(0.3 * x, -0.15, -1.74), 8, hv(0, -1, 0.12), hv(1, 0, 0), 0.15, 0.08)
					H.fang(K, "Head", "Tooth", hp(0.3 * x, -0.16, -1.5), hv(0.05 * x, -1, -0.1), 0.34, 0.09)
				end
				H.teeth(K, "Head", "Tooth", hp(-0.18, -0.15, -1.8), hp(0.18, -0.15, -1.8), 3, hv(0, -1, 0.1), hv(0, 0, 1), 0.12, 0.07)
				H.bolt(K, "Head", "Arc", tips[1], tips[-1], hv(0, 1, 0), 7, 0.06, 0.16)
				-- the lower jaw, half open on a throat glowing with lightning
				local JAW = HEAD * CFrame.new(H.REX_HINGE) * CFrame.Angles(rad(-18), 0, 0)
				local function jcf(px, py, pz)
					return JAW * CFrame.new(px, py, pz)
				end
				K:block("Jaw", "Hide", jcf(0, -0.15, -0.8), Vector3.new(0.82, 0.3, 1.5))
				K:block("Jaw", "HideDark", jcf(0, -0.14, -1.56), Vector3.new(0.64, 0.3, 0.32))
				K:block("Jaw", "Belly", jcf(0, -0.31, -0.75), Vector3.new(0.66, 0.06, 1.3))
				K:block("Jaw", "Mouth", jcf(0, 0.01, -0.85), Vector3.new(0.62, 0.05, 1.2))
				K:block("Jaw", "MouthGlow", jcf(0, 0.02, -0.6), Vector3.new(0.3, 0.05, 0.7))
				for _, x in { 1, -1 } do
					H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.34 * x, 0, -0.55), JAW * Vector3.new(0.27 * x, 0, -1.56), 7, JAW:VectorToWorldSpace(Vector3.new(0, 1, -0.1)).Unit, JAW:VectorToWorldSpace(Vector3.xAxis), 0.12, 0.07)
					K:spike("Jaw", "Armour", JAW * Vector3.new(0.4 * x, -0.24, -0.5), JAW:VectorToWorldSpace(Vector3.new(0.5 * x, -0.6, 0.4)).Unit, JAW:VectorToWorldSpace(Vector3.zAxis), 0.24, 0.09)
				end
			end,
		})
		GK.lids(K, Color3.fromHex("101216"))
	end,
}
