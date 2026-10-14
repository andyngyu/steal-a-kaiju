local rad = math.rad
local H = require(script.Parent.Helpers)

-- Lava Lagoon / Mythic / fire (accent: crimson): a fire dragon-serpent. Dark-red and rust scales cracked over a molten
-- core, a glowing belly, living flame burning along its whole spine, a dragon head crowned with two pairs of swept
-- black horns and a crimson mane of fire, a molten maw full of fangs, a tongue of flame, gold eyes.
local HEAD = H.SERPENT_HEAD
local SKULL = { 0.74, 0.5, 0.64 }

return {
	Seed = 113,
	Vary = 0.05,
	Gait = "Slither",
	Emotes = { "RearUp", "Look" },
	Palette = {
		Hide = { "7A2A1E", Material = "Basalt" },
		HideDark = { "551A10", Material = "Basalt" },
		HideLight = { "A34428", Material = "Basalt" },
		Back = { "30140E", Material = "Basalt" },
		Belly = { "FF3A2A", Neon = true },
		Belly2 = { "8A2416", Material = "Basalt" },
		Magma = { "FF2A3A", Neon = true },
		MagmaHot = { "FF6A1A", Neon = true },
		Flame = { "FFC23A", Neon = true },
		Horn = { "241712", Material = "Basalt" },
		HornLight = { "4A3028", Material = "Basalt" },
		Tooth = "F2E2C6",
		Mouth = { "FF4A1A", Neon = true },
		Tongue = { "FF6A1A", Neon = true },
		Eye = { "FFD04A", Neon = true },
		Socket = "120A08",
	},
	Joints = {
		Neck = H.SERPENT_JOINTS.Neck,
		Seg1 = H.SERPENT_JOINTS.Seg1,
		Seg2 = H.SERPENT_JOINTS.Seg2,
		Seg3 = H.SERPENT_JOINTS.Seg3,
		Seg4 = H.SERPENT_JOINTS.Seg4,
		Tail = H.SERPENT_JOINTS.Tail,
		Head = H.SERPENT_JOINTS.Head,
		Jaw = HEAD * Vector3.new(0, 0, -SKULL[3] * 0.25),
		Tongue = H.SERPENT_JOINTS.Tongue,
	},
	Parents = H.SERPENT_PARENTS,
	Build = function(K)
		local FLAME = { "Magma", "MagmaHot", "Flame" }
		H.serpent(K, {
			core = "Magma",
			coreCap = "HideDark",
			coreScale = 0.62,
			overlap = 0.92,
			crest = function(K, segs)
				for _, g in { "Neck", "Seg1", "Seg2", "Seg3", "Seg4", "Tail" } do
					local smp0 = segs[g]
					local size = ({ Neck = 0.62, Seg1 = 0.72, Seg2 = 0.66, Seg3 = 0.56, Seg4 = 0.44, Tail = 0.32 })[g]
					for s = 0.12, smp0.total - 0.12, 0.32 do
						local smp = K:at(smp0, s)
						H.flame(K, g, FLAME, K:surface(smp, 0, 0.08), (smp.U + smp.T * 0.45).Unit, smp.R, size * K:rand(0.8, 1.15), 0.2, 22)
					end
					H.cracks(K, g, "Magma", smp0, { rad(62), rad(-62) }, 0.08, smp0.total - 0.08, 0.26, 0.06, 0.08)
				end
			end,
			headBuild = function(K)
				local hd = H.reptileHead(K, {
					frame = HEAD,
					skull = SKULL,
					snout = { 0.52, 0.34, 0.66 },
					tip = { 0.42, 0.28, 0.26 },
					open = 24,
					teeth = { 0.12, 0.06 },
					brow = "Horn",
					browSize = { 0.34, 0.15, 0.36 },
					eye = { 0.16, 0.05 },
					cheek = 0.26,
				})
				for _, x in { 1, -1 } do
					-- two pairs of swept black horns
					H.curve(K, "Head", { "Horn", "Horn", "HornLight", "MagmaHot" }, {
						hd.p(0.26 * x, hd.top - 0.04, -0.3),
						hd.p(0.42 * x, hd.top + 0.24, 0.1),
						hd.p(0.52 * x, hd.top + 0.42, 0.6),
						hd.p(0.48 * x, hd.top + 0.66, 1.0),
					}, 0.18, 0.07, 0.16)
					H.curve(K, "Head", { "Horn", "HornLight", "Magma" }, {
						hd.p(0.36 * x, hd.top - 0.24, -0.1),
						hd.p(0.66 * x, hd.top - 0.18, 0.2),
						hd.p(0.82 * x, hd.top - 0.06, 0.56),
					}, 0.13, 0.06, 0.16)
					K:spike("Head", "Tooth", hd.p(0.17 * x, -0.02, hd.zEnd + 0.14), hd.v(0, -1, 0.05), hd.v(0, 0, 1), 0.22, 0.06)
					K:block("Head", "Magma", hd.cf(0.38 * x, 0.16, -0.36, 0, -10 * x, 0), Vector3.new(0.04, 0.05, 0.46))
				end
				-- a crimson mane of fire framing the head
				for k = 0, 10 do
					local a = rad(-150 + k * 30)
					local d = Vector3.new(math.sin(a), math.cos(a), 0)
					local base = hd.p(d.X * 0.42, 0.3 + d.Y * 0.36, -0.08)
					H.flame(K, "Head", { "Magma", "MagmaHot", "Flame" }, base, hd.v(d.X * 0.9, d.Y * 0.9 + 0.2, 0.75), hd.v(0, 0, 1), 0.78 - math.abs(k - 5) * 0.04, 0.22, 24)
				end
				H.serpentTongue(K, HEAD, "Tongue")
			end,
		})
	end,
}
