local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Mythic / ice: an aurora sea-dragon. Deep midnight-blue scales banded in black, a pale frost belly,
-- one long glowing ribbon fin flowing down its whole back in waves that shift through green, teal, blue, violet and
-- pink, a sleek eastern-dragon head with branching ice antlers, long flowing whiskers, a fan of ribbon frills behind
-- the jaw, mint-glowing eyes, long fangs.
local HEAD = H.SERPENT_HEAD
local SKULL = { 0.62, 0.44, 0.58 }

return {
	Seed = 127,
	Vary = 0.05,
	Gait = "Slither",
	Emotes = { "RearUp", "Look" },
	Palette = {
		Hide = "2A3B6A",
		HideDark = "1C284C",
		HideLight = "45639C",
		Back = "121A33",
		Belly = "C4D8EC",
		Belly2 = "A2BAD4",
		Aur1 = { "3CF0A8", Material = "Glass" },
		Aur2 = { "3CE0E0", Material = "Glass" },
		Aur3 = { "3CA8FF", Material = "Glass" },
		Aur4 = { "6A6CFF", Material = "Glass" },
		Aur5 = { "A05CFF", Material = "Glass" },
		Aur6 = { "E05CD8", Material = "Glass" },
		Glow1 = { "4DFFC4", Neon = true },
		Glow2 = { "4DC8FF", Neon = true },
		Glow3 = { "B86BFF", Neon = true },
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		Horn = { "8FD3F5", Material = "Ice" },
		HornLight = { "E0F3FF", Material = "Ice" },
		Tooth = "F2F6FA",
		Mouth = "2A1E3A",
		Tongue = "6A2A5A",
		Eye = { "4DFFC4", Neon = true },
		Socket = "0A1020",
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
		local AUR = { "Aur1", "Aur2", "Aur3", "Aur4", "Aur5", "Aur6" }
		local GLOW = { "Glow1", "Glow1", "Glow2", "Glow2", "Glow3", "Glow3" }
		H.serpent(K, {
			crest = function(K, segs)
				-- one continuous ribbon fin: thin panels down the spine, rising and falling in waves, the colour sweeping
				-- from green at the neck to pink at the tail, a glowing edge along the top
				local order = { "Neck", "Seg1", "Seg2", "Seg3", "Seg4", "Tail" }
				local total = 0
				for _, g in order do
					total += segs[g].total
				end
				local run = 0
				for _, g in order do
					local smp0 = segs[g]
					local scale = ({ Neck = 0.85, Seg1 = 1, Seg2 = 1, Seg3 = 0.9, Seg4 = 0.75, Tail = 0.55 })[g]
					local s = 0.06
					while s < smp0.total - 0.04 do
						local smp = K:at(smp0, s)
						local u = (run + s) / total
						local h = (0.5 + 0.24 * math.sin((run + s) * 3.4)) * scale
						local c = math.clamp(math.floor(u * 6) + 1, 1, 6)
						local base = K:surface(smp, 0, 0.05)
						K:block(g, AUR[c], CFrame.fromMatrix(base + smp.U * h * 0.5, smp.R, smp.U) * CFrame.Angles(rad(-12), 0, 0), Vector3.new(0.05, h, 0.24))
						K:block(g, GLOW[c], CFrame.fromMatrix(base + smp.U * h * 0.98, smp.R, smp.U) * CFrame.Angles(rad(-12), 0, 0), Vector3.new(0.07, 0.06, 0.24))
						s += 0.2
					end
					run += smp0.total
				end
			end,
			headBuild = function(K)
				local hd = H.reptileHead(K, {
					frame = HEAD,
					skull = SKULL,
					snout = { 0.44, 0.3, 0.7 },
					tip = { 0.36, 0.26, 0.28 },
					open = 18,
					teeth = { 0.1, 0.05 },
					brow = "IceDeep",
					browSize = { 0.3, 0.13, 0.34 },
					eye = { 0.15, 0.045 },
					cheek = 0.2,
				})
				for _, x in { 1, -1 } do
					-- branching ice antlers
					local tine = {
						hd.p(0.2 * x, hd.top - 0.02, -0.24),
						hd.p(0.34 * x, hd.top + 0.3, 0.0),
						hd.p(0.46 * x, hd.top + 0.62, 0.3),
						hd.p(0.44 * x, hd.top + 0.92, 0.66),
					}
					H.curve(K, "Head", { "Horn", "Horn", "HornLight" }, tine, 0.13, 0.06, 0.16)
					K:chain("Head", { "Horn", "HornLight" }, tine[2], hd.v(0.5 * x, 0.6, -0.4), hd.v(0, 0, 1), { n = 2, len = 0.34, w0 = 0.08, w1 = 0.05, bend = 0 })
					K:chain("Head", { "Horn", "HornLight" }, tine[3], hd.v(0.6 * x, 0.4, 0.1), hd.v(0, 0, 1), { n = 2, len = 0.3, w0 = 0.07, w1 = 0.045, bend = 0 })
					-- long flowing whiskers trailing back from the snout
					H.curve(K, "Head", { "Glow1", "Aur2", "Aur3" }, {
						hd.p(0.2 * x, 0.12, hd.zEnd + 0.12),
						hd.p(0.46 * x, 0.02, hd.zEnd + 0.3),
						hd.p(0.68 * x, -0.2, hd.zEnd + 0.7),
						hd.p(0.74 * x, -0.46, hd.zEnd + 1.2),
					}, 0.05, 0.03, 0.16)
					-- a fan of ribbon frills behind the jaw
					for k = 0, 3 do
						local d = hd.v((0.6 + k * 0.08) * x, 0.5 - k * 0.32, 0.7)
						local root = hd.p(0.3 * x, 0.08 - k * 0.06, -0.12)
						K:block("Head", AUR[k + 2], CFrame.lookAt(root + d * 0.34, root + d * 2) * CFrame.Angles(0, 0, rad(90)), Vector3.new(0.05, 0.24, 0.68 - k * 0.08))
						K:block("Head", GLOW[k + 2], CFrame.lookAt(root + d * 0.34 + hd.v(0, 0.12, 0), root + d * 2) * CFrame.Angles(0, 0, rad(90)), Vector3.new(0.06, 0.04, 0.66 - k * 0.08))
					end
					K:spike("Head", "Tooth", hd.p(0.15 * x, -0.02, hd.zEnd + 0.14), hd.v(0, -1, 0.05), hd.v(0, 0, 1), 0.18, 0.05)
				end
				H.crystal(K, "Head", { "Ice", "IceDeep", "Glow2" }, hd.p(0, hd.top, -0.3), hd.v(0, 1, 0.5), 0.4, 3, 20)
				H.serpentTongue(K, HEAD, "Tongue")
			end,
		})
	end,
}
