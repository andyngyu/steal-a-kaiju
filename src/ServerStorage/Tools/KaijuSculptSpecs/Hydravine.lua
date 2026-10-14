local rad = math.rad
local H = require(script.Parent.Helpers)

-- Venom Jungle / Mythic / poison: a three-headed vine hydra. A great serpent coiled low, its body wound with thorned
-- vines and leaves, bark-brown scales down the back over jungle-green flanks, a pale belly. Three necks rear up from the
-- front of the coil: the main head in the middle, two smaller heads either side swaying out. Every head has a crown of
-- leaf frills with purple poison blooms behind the skull, swept-back thorn horns, lime eyes and a mouth glowing toxic
-- lime inside long fangs.
local function sideHeadFrame(x)
	return CFrame.lookAt(Vector3.new(1.08 * x, 2.02, -0.62), Vector3.new(1.78 * x, 1.86, -1.86))
end

return {
	Seed = 449,
	Vary = 0.05,
	Gait = "Slither",
	Emotes = { "RearUp", "Look" },
	Palette = {
		Hide = "3E6A2C",
		HideDark = "2A4A1E",
		HideLight = "5E8A3A",
		Back = "4A3422",
		Belly = "C2BC80",
		Belly2 = "A8A26A",
		Horn = "3A2A1C",
		HornLight = "8A7A54",
		Vine = "2E4E1E",
		Leaf = "5A9A34",
		LeafDark = "3A7024",
		Bloom = { "B04CFF", Neon = true },
		BloomCore = { "C6FF3A", Neon = true },
		Thorn = "C9B98A",
		Tooth = "EEE8D0",
		Mouth = { "7CF03A", Neon = true },
		Tongue = "6A1E4A",
		Eye = { "C6FF3A", Neon = true },
		Socket = "0C1208",
	},
	Joints = H.SERPENT_JOINTS,
	Parents = H.SERPENT_PARENTS,
	Build = function(K)
		local function vines(group, samples, turns, from, to)
			local n = math.floor((to - from) / 0.12)
			for i = 0, n do
				local s = from + (to - from) * i / n
				local smp = K:at(samples, s)
				local th = i / n * math.pi * 2 * turns
				local pos, nrm = K:surface(smp, th, -0.05)
				local dir = (smp.T * 0.7 + (smp.U * math.cos(th + math.pi / 2) + smp.R * math.sin(th + math.pi / 2)) * 0.7).Unit
				K:block(group, "Vine", CFrame.lookAt(pos, pos + dir), Vector3.new(0.1, 0.1, 0.18))
				if i % 4 == 0 then
					K:block(group, i % 8 == 0 and "Leaf" or "LeafDark", CFrame.fromMatrix(pos + nrm * 0.07, dir, nrm) * CFrame.Angles(0, rad(35), 0), Vector3.new(0.26, 0.03, 0.14))
				elseif i % 4 == 2 then
					K:spike(group, "Thorn", pos, nrm, dir, 0.12, 0.045)
				end
			end
		end
		-- a crown of leaf frills behind a skull, poison blooms in it
		local function leafCrown(group, F, s)
			for k = -3, 3 do
				local a = rad(k * 26)
				local base = F * Vector3.new(math.sin(a) * 0.28 * s, (0.3 - math.abs(k) * 0.03) * s, 0.02)
				local dir = F:VectorToWorldSpace(Vector3.new(math.sin(a) * 1.1, math.cos(a) * 0.7 + 0.2, 0.75)).Unit
				K:chain(group, { "LeafDark", "Leaf" }, base, dir, F:VectorToWorldSpace(Vector3.zAxis), { n = 2, len = (0.62 - math.abs(k) * 0.06) * s, w0 = 0.22 * s, w1 = 0.12 * s, bend = 0, depth = 0.3 })
				if k % 2 == 0 then
					local c = base + dir * 0.44 * s
					K:block(group, "Bloom", CFrame.new(c) * CFrame.Angles(0, rad(45), 0), Vector3.new(0.16, 0.1, 0.16) * s)
					K:block(group, "BloomCore", CFrame.new(c + Vector3.new(0, 0.06 * s, 0)), Vector3.new(0.07, 0.06, 0.07) * s)
				end
			end
		end
		-- a smaller head on a side neck (group Neck): skull, snout, horns, eyes, fangs, a glowing open mouth
		local function sideHead(F, s)
			local function cf(px, py, pz, ax, ay, az)
				return F * CFrame.new(px * s, py * s, pz * s) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
			end
			local function v(px, py, pz)
				return F:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
			end
			K:block("Neck", "Hide", cf(0, 0.12, -0.26), Vector3.new(0.62, 0.44, 0.56) * s)
			K:block("Neck", "Hide", cf(0, 0.04, -0.78), Vector3.new(0.44, 0.3, 0.6) * s)
			K:block("Neck", "Back", cf(0, 0.34, -0.3, -10, 0, 0), Vector3.new(0.44, 0.08, 0.5) * s)
			K:block("Neck", "Mouth", cf(0, -0.12, -0.72), Vector3.new(0.4, 0.05, 0.8) * s)
			K:block("Neck", "Hide", cf(0, -0.3, -0.62, 22, 0, 0), Vector3.new(0.4, 0.14, 0.8) * s)
			for _, x in { 1, -1 } do
				K:block("Neck", "HideDark", cf(0.24 * x, 0.3, -0.5, -8, -14 * x, 18 * x), Vector3.new(0.24, 0.1, 0.28) * s)
				H.eye(K, "Neck", cf(0.27 * x, 0.2, -0.56, 0, -30 * x, 12 * x), 0.14 * s, 0.04 * s)
				K:chain("Neck", { "Horn", "Horn", "HornLight" }, F * Vector3.new(0.2 * x * s, 0.34 * s, -0.16 * s), v(0.3 * x, 0.5, 0.8), v(1, 0, 0), { n = 3, len = 0.7 * s, w0 = 0.12 * s, w1 = 0.06 * s, bend = 10 })
				K:spike("Neck", "Tooth", F * Vector3.new(0.15 * x * s, -0.12 * s, -1.0 * s), v(0, -1, 0.05), v(0, 0, 1), 0.18 * s, 0.05 * s)
				K:spike("Neck", "Tooth", F * Vector3.new(0.13 * x * s, -0.28 * s, -0.94 * s), v(0, 1, 0.1), v(0, 0, 1), 0.12 * s, 0.04 * s)
			end
			leafCrown("Neck", F, s * 0.9)
		end

		H.serpent(K, {
			color = H.skin({ stripe = 36, band = 80, flank = 108, every = 2 }),
			crest = function(K, segs)
				-- vines wound round the coil and the neck, thorns along the back
				for _, g in { "Seg1", "Seg2", "Seg3", "Seg4" } do
					vines(g, segs[g], 1.5, 0.05, segs[g].total - 0.05)
					K:ridge(g, segs[g], { every = 0.3, height = 0.18, thick = 0.07, key = "Horn", tip = "Thorn", lean = 40, sink = 0.85 })
				end
				vines("Tail", segs.Tail, 1.2, 0.05, segs.Tail.total - 0.2)
				vines("Neck", segs.Neck, 1.4, 0.2, segs.Neck.total - 0.05)
				-- the two side necks rearing out of the front of the coil
				for _, x in { 1, -1 } do
					local F = sideHeadFrame(x)
					local neck = K:tube("Neck", {
						{ F.Position.X, F.Position.Y, F.Position.Z, rx = 0.26, ru = 0.25, rd = 0.27 },
						{ 0.8 * x, 1.46, -0.5, rx = 0.32, ru = 0.3, rd = 0.32 },
						{ 0.36 * x, 0.92, -0.3, rx = 0.38, ru = 0.36, rd = 0.38 },
						{ 0.14 * x, 0.66, 0.1, rx = 0.42, ru = 0.4, rd = 0.4 },
					}, { step = 0.26, core = "Hide", coreScale = 0.8, tile = { w = 0.36, t = 0.1, lift = 7, jitter = 1.5, sink = 0.5, overlap = 1.1 }, belly = { key = "Belly", key2 = "Belly2", arc = 46, t = 0.1, wide = 1.1 }, color = H.skin({ stripe = 36, band = 80, flank = 108, every = 2 }) })
					vines("Neck", neck, 1.2, 0.15, neck.total - 0.1)
					sideHead(F, 0.82)
				end
			end,
			head = function(K, hcf, hp, hv)
				leafCrown("Head", hcf(0, 0.06, 0.04), 1.0)
			end,
		})
	end,
}
