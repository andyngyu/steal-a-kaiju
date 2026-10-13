local rad = math.rad
local H = require(script.Parent.Helpers)

-- Frostfang Peaks / Uncommon / ice: a glacier crab. A slate-blue carapace armoured in ice, jagged ice crystals erupting
-- from its back, a rim of icicle spikes, crystal-edged pincers, cyan eyes on stalks.
return {
	Seed = 109,
	Vary = 0.05,
	Gait = "Scuttle",
	Emotes = { "ClawSnap", "Look" },
	Palette = {
		Shell = "4E6178",
		ShellDark = "33435A",
		ShellLight = "7C93AC",
		Belly = "B3C3D3",
		Spike = { "A9E1FF", Material = "Ice" },
		SpikeTip = { "E0F3FF", Material = "Ice" },
		Ice = { "A9E1FF", Material = "Ice" },
		IceDeep = { "6CC2EE", Material = "Ice" },
		IceGlow = { "4FD2FF", Neon = true },
		Claw = "4E6178",
		ClawDark = { "8FD3F5", Material = "Ice" },
		Tooth = { "E0F3FF", Material = "Ice" },
		Mouth = "2A1E3A",
		Eye = { "55E0FF", Neon = true },
		Socket = "0C1220",
	},
	Joints = H.CRAB_JOINTS,
	Build = function(K)
		H.crab(K, {
			crest = function(K, shell)
				H.crystalRidge(K, "Body", shell, { from = 0.25, to = shell.total - 0.25, every = 0.4, size = function(u) return 0.8 - 0.25 * math.abs(u - 0.4) end, count = 4, keys = { "Ice", "IceDeep", "IceGlow", "Ice" }, lean = 14, thetas = { 0, rad(40), rad(-40) }, sideScale = 0.55 })
			end,
		})
	end,
}
