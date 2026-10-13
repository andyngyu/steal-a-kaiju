local rad = math.rad
local H = require(script.Parent.Helpers)

-- Lava Lagoon / Common / fire: a lava crab. A basalt carapace cracked over a molten core, a rim of spikes with molten
-- tips, smouldering vents on its back, heavy basalt pincers glowing along their bite, ember eyes on stalks.
return {
	Seed = 107,
	Vary = 0.04,
	Gait = "Scuttle",
	Emotes = { "ClawSnap", "Look" },
	Palette = {
		Shell = { "3A2E2A", Material = "Basalt" },
		ShellDark = { "241C1A", Material = "Basalt" },
		ShellLight = { "57463D", Material = "Basalt" },
		Belly = { "5E2E1A", Material = "Basalt" },
		Magma = { "E2470F", Neon = true },
		Spike = { "4A3E38", Material = "Basalt" },
		SpikeTip = { "FF7A1A", Neon = true },
		Claw = { "3A2E2A", Material = "Basalt" },
		ClawDark = { "1E1716", Material = "Basalt" },
		Tooth = { "FF9A2A", Neon = true },
		Mouth = { "C8380C", Neon = true },
		Eye = { "FFB233", Neon = true },
		Socket = "0C0909",
	},
	Joints = H.CRAB_JOINTS,
	Build = function(K)
		H.crab(K, {
			core = "Magma",
			coreScale = 0.6,
			overlap = 0.88,
			crest = function(K, shell)
				H.cracks(K, "Body", "Magma", shell, { rad(18), rad(-18), rad(52), rad(-52) }, 0.15, shell.total - 0.15, 0.24, 0.07, 0.1)
				-- smouldering vents: basalt chimneys with glowing mouths
				for i, p in { { 0.3, 0.5 }, { -0.35, 0.62 }, { 0.05, 0.98 } } do
					local smp = K:at(shell, p[2])
					local pos = smp.p + smp.U * smp.ru * 0.9 + Vector3.new(p[1], 0, 0)
					K:block("Body", "Spike", CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, rad(45 * i), 0), Vector3.new(0.3, 0.3, 0.3))
					K:block("Body", "Magma", CFrame.new(pos + Vector3.new(0, 0.28, 0)) * CFrame.Angles(0, rad(45 * i), 0), Vector3.new(0.18, 0.06, 0.18))
				end
			end,
		})
	end,
}
