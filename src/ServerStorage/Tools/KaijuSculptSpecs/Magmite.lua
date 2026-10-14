local rad = math.rad
local H = require(script.Parent.Helpers)

-- Lava Lagoon / Common / lava: a volcano crab. A rust-red basalt carapace cracked with yellow-orange magma, a smoking
-- volcano cone rising from its back with a glowing crater and lava running down its sides, one huge crushing claw and
-- one small one, a glowing underside and mouth, molten-tipped spikes round the rim, ember eyes on stalks.
return {
	Seed = 107,
	Vary = 0.04,
	Gait = "Scuttle",
	Emotes = { "ClawSnap", "Look" },
	Palette = {
		Shell = { "94502E", Material = "Basalt" },
		ShellDark = { "62341E", Material = "Basalt" },
		ShellLight = { "BE6E40", Material = "Basalt" },
		Belly = { "FFA51F", Neon = true },
		Magma = { "FF9A1A", Neon = true },
		MagmaHot = { "FFC43A", Neon = true },
		Spike = { "5A3A2C", Material = "Basalt" },
		SpikeTip = { "FFB01F", Neon = true },
		Cone = { "6E4834", Material = "Basalt" },
		ConeLight = { "946448", Material = "Basalt" },
		Claw = { "9A522E", Material = "Basalt" },
		ClawDark = { "62341E", Material = "Basalt" },
		Tooth = { "FFC43A", Neon = true },
		Mouth = { "FF9A1A", Neon = true },
		Eye = { "FFD54A", Neon = true },
		Socket = "120A08",
	},
	Joints = H.CRAB_JOINTS,
	Build = function(K)
		H.crab(K, {
			core = "Magma",
			coreScale = 0.6,
			overlap = 0.88,
			clawScale = { 1.45, 0.82 },
			crest = function(K, shell)
				H.cracks(K, "Body", "Magma", shell, { rad(12), rad(-30), rad(48), rad(-62), rad(76) }, 0.12, shell.total - 0.12, 0.22, 0.09, 0.1)
				-- the volcano: a stepped rock cone with a glowing crater, lava running down its sides
				local smp = K:at(shell, shell.total * 0.56)
				local base = smp.p + smp.U * smp.ru * 0.7
				local y = 0
				for i, l in { { 1.34, 0.3 }, { 1.06, 0.3 }, { 0.82, 0.28 }, { 0.62, 0.24 } } do
					K:block("Body", i % 2 == 0 and "ConeLight" or "Cone", CFrame.new(base + Vector3.new(0, y + l[2] / 2, 0)) * CFrame.Angles(0, rad(i * 22), 0), Vector3.new(l[1], l[2], l[1]))
					y += l[2] * 0.92
				end
				K:block("Body", "MagmaHot", CFrame.new(base + Vector3.new(0, y + 0.02, 0)), Vector3.new(0.4, 0.06, 0.4))
				for k = 0, 3 do
					local a = rad(k * 90 + 45)
					K:block("Body", "Cone", CFrame.new(base + Vector3.new(math.cos(a) * 0.28, y + 0.08, math.sin(a) * 0.28)) * CFrame.Angles(0, -a, 0), Vector3.new(0.18, 0.2, 0.3))
				end
				for k = 0, 3 do
					local a = rad(k * 90 + 10)
					local top = base + Vector3.new(math.cos(a) * 0.26, y - 0.02, math.sin(a) * 0.26)
					local bottom = base + Vector3.new(math.cos(a) * 0.66, 0.08, math.sin(a) * 0.66)
					K:block("Body", k % 2 == 0 and "Magma" or "MagmaHot", CFrame.lookAt((top + bottom) / 2, bottom), Vector3.new(0.09, 0.06, (bottom - top).Magnitude))
				end
			end,
		})
	end,
}
