local rad = math.rad
local H = require(script.Parent.Helpers)

-- Sunken Abyss / Mythic / water: the tidewyrm, a sea dragon. A long armoured serpent in deep teal, navy along the back
-- and pale underneath, glowing cyan seams and photophores down its flanks. A mane of long lionfish spines runs down its
-- back, webbed with red-and-white striped membrane; two great manta wings spread from its shoulders; the tail ends in a
-- tall fan fin. Head: a horned dragon skull crowned with branching coral glowing at the tips, long whisker barbels
-- trailing from the snout, heavy brows over cyan eyes, a fanged mouth glowing deep inside.
return {
	Seed = 541,
	Vary = 0.04,
	Scale = 1.55,
	Gait = "Slither",
	Emotes = { "RearUp", "Look" },
	Palette = {
		Hide = { "1E5A6A", Material = "Slate" },
		HideDark = { "123A4E", Material = "Slate" },
		HideLight = { "4E9AA4", Material = "Slate" },
		Back = { "0B1E32", Material = "Slate" },
		Belly = "E2E6D6",
		Belly2 = "C8D0C0",
		Horn = "E8E2CC",
		HornLight = "F6F2E4",
		Spine = "F2EADA",
		SpineTip = "C8405A",
		Membrane = "C8405A",
		MembraneLight = "F0D8D0",
		Wing = { "163E52", Material = "Slate" },
		WingEdge = { "4E9AA4", Material = "Slate" },
		Coral = "E8506E",
		CoralDark = "A8344E",
		CoralTip = { "FF5A82", Neon = true },
		Barbel = "2E6E7E",
		Glow = { "1AA6D8", Neon = true },
		SeamLip = { "08141C", Material = "Slate" },
		Tooth = "F2F2EA",
		Mouth = "2A0A16",
		Tongue = "8A2A44",
		Eye = { "22C4E8", Neon = true },
		Socket = "060C10",
	},
	Joints = H.SERPENT_JOINTS,
	Parents = H.SERPENT_PARENTS,
	Build = function(K)
		-- a raked fin or wing: stacked boards from the base out along `up`, the leading edge sweeping back
		local function fin(g, keys, base, up, along, height, length, thick, n)
			local side = along:Cross(up).Unit
			for i = 0, n - 1 do
				local f = i / n
				local front = -length * 0.5 + f * length * 0.9
				local back = length * 0.5 + f * length * 0.25
				local c = base + up * height * (f + 0.5 / n) + along * (front + back) / 2
				K:block(g, keys[1], CFrame.fromMatrix(c, along, up, side), Vector3.new(math.max(back - front, 0.12), height / n * 1.15, thick * (1 - f * 0.5)))
				K:block(g, keys[2], CFrame.fromMatrix(c + along * (front - (front + back) / 2 + 0.07), along, up, side), Vector3.new(0.14, height / n * 1.15, thick * (1 - f * 0.5) + 0.02))
			end
		end
		H.serpent(K, {
			color = H.skin({ stripe = 32, band = 66, flank = 104, every = 2, upper = "HideDark" }),
			crest = function(K, segs)
				-- glowing seams sunk down the flanks and a row of photophores below them
				for _, g in { "Seg1", "Seg2", "Seg3", "Seg4", "Neck" } do
					local smps = segs[g]
					for _, x in { 1, -1 } do
						H.vein(K, g, "Glow", smps, rad(80) * x, 0.06, smps.total - 0.06, { width = 0.05, height = 0.1, lift = 0.04, wander = 10, step = 0.22, lip = "SeamLip", lipW = 0.05 })
						for s = 0.2, smps.total - 0.1, 0.34 do
							local smp = K:at(smps, s)
							local pos, nrm = K:surface(smp, rad(116) * x, -0.03)
							local F = CFrame.fromMatrix(pos, nrm:Cross(smp.T).Unit, nrm)
							K:block(g, "SeamLip", F, Vector3.new(0.1, 0.05, 0.1))
							K:block(g, "Glow", F * CFrame.new(0, 0.01, 0), Vector3.new(0.05, 0.05, 0.05))
						end
					end
				end
				-- the lionfish mane: long spines down the neck and back, webbed with striped membrane
				for _, g in { "Neck", "Seg1", "Seg2", "Seg3" } do
					local smps = segs[g]
					local prev
					local k = 0
					for s = 0.12, smps.total - 0.08, 0.3 do
						local smp = K:at(smps, s)
						local pos = K:surface(smp, 0, 0.04)
						local len = (g == "Neck" and 0.8 or 0.95) * (g == "Seg3" and (1 - s / smps.total * 0.5) or 1)
						local d = (smp.U + smp.T * 0.55).Unit
						K:chain(g, { "Spine", "Spine", "SpineTip" }, pos, d, smp.R, { n = 3, len = len, w0 = 0.07, w1 = 0.045, bend = 0 })
						local cur = { pos = pos, d = d, len = len }
						if prev then
							for j, f in { 0.3, 0.62 } do
								local pa, pb = prev.pos + prev.d * prev.len * f, cur.pos + cur.d * cur.len * f
								local across = pb - pa
								if across.Magnitude > 0.05 then
									K:block(g, (k + j) % 2 == 0 and "Membrane" or "MembraneLight", CFrame.fromMatrix((pa + pb) / 2, across.Unit, cur.d), Vector3.new(across.Magnitude + 0.04, cur.len * 0.34, 0.03))
								end
							end
						end
						prev = cur
						k += 1
					end
				end
				-- the manta wings spreading from the shoulders, rows of glowing spots along them
				local sh = K:at(segs.Seg1, 0.55)
				for _, x in { 1, -1 } do
					local base = K:surface(sh, rad(84) * x, 0.08)
					local out = (sh.R * x * (sh.R.X * x > 0 and 1 or -1) + Vector3.new(0, 0.7, 0)).Unit
					local back = Vector3.new(sh.T.X, 0, sh.T.Z).Unit
					fin("Seg1", { "Wing", "WingEdge" }, base, out, back, 2.7, 2.2, 0.1, 10)
					for k = 1, 4 do
						local p = base + out * 2.7 * (k / 5) + back * (0.1 + k * 0.1) + out:Cross(back).Unit * 0.06 * x
						K:block("Seg1", "SeamLip", CFrame.lookAt(p, p + back), Vector3.new(0.14, 0.05, 0.14))
						K:block("Seg1", "Glow", CFrame.lookAt(p + Vector3.new(0, 0.01, 0), p + back), Vector3.new(0.07, 0.05, 0.07))
					end
				end
				-- the tall fan fin at the end of the tail
				local tip = K:at(segs.Tail, segs.Tail.total)
				local flat = Vector3.new(tip.T.X, 0, tip.T.Z).Unit
				fin("Tail", { "Membrane", "Spine" }, tip.p, (Vector3.yAxis + flat * 0.35).Unit, flat, 1.5, 1.1, 0.06, 7)
				fin("Tail", { "MembraneLight", "Spine" }, tip.p, (-Vector3.yAxis + flat * 0.6).Unit, flat, 0.6, 0.8, 0.06, 4)
			end,
			head = function(K, hcf, hp, hv)
				-- heavy brows over the eyes
				for _, x in { 1, -1 } do
					K:block("Head", "Back", hcf(0.28 * x, 0.46, -0.6, -10, -12 * x, 18 * x), Vector3.new(0.36, 0.13, 0.4))
					-- whisker barbels trailing from the snout
					K:chain("Head", { "Barbel", "Barbel", "Barbel", "Glow" }, hp(0.2 * x, -0.06, -1.24), hv(0.5 * x, -0.4, 0.8), hv(0, 1, 0), { n = 4, len = 1.3, w0 = 0.07, w1 = 0.04, bend = -14 * x, tip = false })
				end
				-- the coral crown: branching coral rising off the skull, glowing at the tips
				local function coral(base, d, len, depth)
					K:chain("Head", { "CoralDark", "Coral" }, base, d, hv(1, 0, 0), { n = 2, len = len, w0 = 0.12 * (len / 0.5), w1 = 0.08 * (len / 0.5), bend = 0, tip = false })
					local tip = base + d * len
					if depth > 0 then
						for _, a in { -30, 30 } do
							local axis = d:Cross(Vector3.zAxis)
							axis = axis.Magnitude > 1e-3 and axis.Unit or Vector3.xAxis
							coral(tip, (CFrame.fromAxisAngle(axis, rad(a)) * d + Vector3.new(0, 0.15, 0)).Unit, len * 0.7, depth - 1)
						end
					else
						H.point(K, "Head", "CoralTip", tip + d * 0.05, d, 0.08)
					end
				end
				for _, o in { { 0, 0.5, 0.0, 0, 0.6 }, { 0.18, 0.46, -0.24, 0.5, 0.48 }, { -0.18, 0.46, -0.24, -0.5, 0.48 }, { 0.12, 0.42, 0.12, 0.6, 0.4 }, { -0.12, 0.42, 0.12, -0.6, 0.4 } } do
					coral(hp(o[1], o[2], o[3]), hv(o[4], 1, 0.35), o[5], 2)
				end
				-- a glow deep in the throat
				K:block("Head", "Glow", hcf(0, -0.15, -0.4), Vector3.new(0.18, 0.04, 0.2))
			end,
		})
	end,
}
