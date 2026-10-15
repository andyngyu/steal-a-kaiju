local rad = math.rad
local GK = require(script.Parent.GuardianKit)
local H = GK.H

-- Cosmic Rift guardian: the Void Colossus, a titan knuckle-walking out of the rift. Its body is cracked black obsidian
-- plates with magenta void light blazing through every crack between them. In its chest a black hole: a dark orb
-- ringed by a blazing accretion disc of magenta and starlight. Rings of floating rock orbit its shoulders and back on
-- glowing orbits, crystal shards erupt from its back, its fists are clad in violet crystal. Head: a heavy obsidian
-- brow over burning magenta eyes, two great crystal horns curving up and forward, a crystal crest, a jaw glowing with
-- void light.
local HEAD = H.APE_HEAD
local HS = 1.15
local JOINTS = {}
for k, v in H.APE_JOINTS do
	JOINTS[k] = v
end
JOINTS.Jaw = HEAD.Position + (HEAD * H.APE_HINGE - HEAD.Position) * HS

return {
	Seed = 771,
	Vary = 0.04,
	Scale = 5.0,
	RootSize = { 9.0, 8.0, 8.5 },
	HipHeight = 2.4,
	Palette = {
		Fur = { "1C1626", Material = "Slate" },
		FurDark = { "0E0B14", Material = "Slate" },
		FurLight = { "2E2640", Material = "Slate" },
		Skin = { "241C34", Material = "Slate" },
		SkinDark = { "16111F", Material = "Slate" },
		VoidCore = { "C83AF0", Neon = true },
		Void = { "E040FF", Neon = true },
		Star = { "FFF4FF", Neon = true },
		Hole = "030205",
		Disc = { "FF5AD8", Neon = true },
		Orbit = { "A07AFF", Neon = true, Transparency = 0.2 },
		Rock = { "3A3448", Material = "Basalt" },
		RockDark = { "221E2C", Material = "Basalt" },
		Crystal = "B8A4FF",
		CrystalDark = "7A62D0",
		CrystalLight = "DCD0FF",
		Tooth = "E8E2F0",
		Mouth = { "B02AD8", Neon = true },
		Eye = { "FF40E0", Neon = true },
		Socket = "050308",
		Claw = "141018",
		ClawTip = "C8B8E8",
	},
	Joints = JOINTS,
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		local SHARDS = { "Crystal", "CrystalDark", "CrystalLight", "Crystal" }
		H.ape(K, {
			back = "FurDark",
			furLift = 4,
			core = "FurDark",
			limbCore = "FurDark",
			overlap = 1.05,
			crest = { "CrystalDark", "Crystal", "CrystalLight" },
			head = function(K, hcf, hp, hv)
				-- two great crystal horns curving up and forward from the brow
				for _, x in { 1, -1 } do
					H.curve(K, "Head", { "CrystalDark", "Crystal", "Crystal", "CrystalLight" }, { hp(0.32 * x, 0.46, -0.32), hp(0.62 * x, 0.86, -0.24), hp(0.84 * x, 1.3, -0.46), hp(0.8 * x, 1.6, -0.86) }, 0.32, 0.08, 0.1)
					K:block("Head", "Void", hcf(0.32 * x, 0.46, -0.32), Vector3.new(0.2, 0.2, 0.2))
				end
				H.crystal(K, "Head", SHARDS, hp(0, 0.66, -0.06), hv(0, 1, 0.5), 0.5, 4, 26)
				-- void light in the jaw and cracks across the face
				K:block("Head", "Void", hcf(0, -0.2, -0.82), Vector3.new(0.4, 0.06, 0.26))
				for _, x in { 1, -1 } do
					K:block("Head", "Void", hcf(0.36 * x, 0.12, -0.62, 0, 0, 30 * x), Vector3.new(0.05, 0.3, 0.05))
				end
			end,
			extras = function(K, parts)
				-- the black hole in its chest: a dark orb ringed by a blazing accretion disc
				local chestN = Vector3.new(0, -0.35, -1).Unit
				local c = Vector3.new(0, 2.5, -1.36)
				local F = CFrame.fromMatrix(c, Vector3.xAxis, chestN)
				K:block("Body", "Skin", CFrame.lookAt(c - chestN * 0.12, c - chestN), Vector3.new(1.4, 1.2, 0.3))
				for k = 0, 15 do
					local a = k / 16 * math.pi * 2
					local r = 0.48
					K:block("Body", k % 3 == 0 and "Star" or "Disc", F * CFrame.new(math.cos(a) * r, 0.1, math.sin(a) * r * 0.8) * CFrame.Angles(0, -a, 0), Vector3.new(0.14, 0.08, 0.24))
					K:block("Body", "Void", F * CFrame.new(math.cos(a) * r * 0.72, 0.08, math.sin(a) * r * 0.58) * CFrame.Angles(0, -a, 0), Vector3.new(0.1, 0.07, 0.16))
				end
				K:block("Body", "Hole", F * CFrame.new(0, 0.16, 0), Vector3.new(0.5, 0.3, 0.42))
				K:block("Body", "Hole", F * CFrame.new(0, 0.16, 0) * CFrame.Angles(0, rad(45), 0), Vector3.new(0.44, 0.34, 0.44))
				-- magenta void light blazing through cracks in the obsidian
				local torso = parts.torso
				H.cracks(K, "Body", "Void", torso, { rad(60), rad(-60), rad(100), rad(-100) }, 0.2, torso.total - 0.2, 0.34, 0.13, 0.12)
				H.cracks(K, "Body", "Void", parts.mantle, { rad(10), rad(-50) }, 0.2, parts.mantle.total - 0.2, 0.34, 0.12, 0.12)
				for g, arm in parts.arms do
					local x = g == "ArmL" and 1 or -1
					H.cracks(K, g, "Void", arm[1], { rad(100) * x }, 0.1, arm[1].total - 0.1, 0.3, 0.11, 0.12)
					H.cracks(K, g, "Void", arm[2], { rad(110) * x }, 0.1, arm[2].total - 0.1, 0.3, 0.11, 0.12)
				end
				for g, leg in parts.legs do
					local x = g == "LegL" and 1 or -1
					H.cracks(K, g, "Void", leg[1], { rad(100) * x }, 0.1, leg[1].total - 0.1, 0.3, 0.11, 0.12)
				end
				-- crystal shards erupting from the back
				for s = 0.3, torso.total - 0.3, 0.42 do
					local smp = K:at(torso, s)
					for _, th in { rad(30), rad(-30) } do
						local pos, nrm = K:surface(smp, th, 0.06)
						H.crystal(K, "Body", SHARDS, pos, (nrm + smp.T * 0.2).Unit, 0.56, 3, 22)
					end
				end
				-- rings of floating rock orbiting the shoulders and the back
				for ri, o in { { Vector3.new(0, 3.6, 0.0), 1.9, rad(14), rad(0) }, { Vector3.new(0, 3.1, 0.2), 2.4, rad(-10), rad(20) } } do
					local tilt = CFrame.new(o[1]) * CFrame.Angles(o[3], 0, o[4])
					local R = o[2]
					local prev
					for deg = 0, 360, 12 do
						local p = tilt * Vector3.new(math.cos(rad(deg)) * R, 0, math.sin(rad(deg)) * R * 1.1)
						if prev then
							K:block("Body", "Orbit", CFrame.lookAt((prev + p) / 2, p) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.16, 0.16, (p - prev).Magnitude + 0.06))
						end
						prev = p
					end
					for k = 0, 4 do
						local a = rad(k * 72 + ri * 30)
						local p = tilt * Vector3.new(math.cos(a) * R, 0, math.sin(a) * R * 1.1)
						local s = K:rand(0.3, 0.46)
						K:block("Body", k % 2 == 0 and "Rock" or "RockDark", CFrame.new(p) * CFrame.Angles(rad(K:rand(0, 90)), rad(K:rand(0, 90)), 0), Vector3.new(s, s * 0.8, s))
						K:block("Body", "Rock", CFrame.new(p + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(rad(K:rand(0, 90)), rad(K:rand(0, 90)), 0), Vector3.new(s * 0.7, s * 0.6, s * 0.7))
						if k % 2 == 1 then
							K:block("Body", "Void", CFrame.new(p) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(s * 0.4, s * 0.4, s * 0.4))
						end
					end
				end
				-- fists clad in violet crystal
				for _, x in { 1, -1 } do
					local g = x == 1 and "ArmL" or "ArmR"
					local fist = Vector3.new(1.44 * x, 0.5, -0.86)
					H.crystal(K, g, SHARDS, fist + Vector3.new(0, 0.1, -0.2), Vector3.new(0.2 * x, 0.6, -1), 0.56, 4, 30)
					H.crystal(K, g, SHARDS, fist + Vector3.new(0.2 * x, 0.3, 0.1), Vector3.new(0.6 * x, 1, 0), 0.4, 3, 24)
					local arm = parts.arms[g]
					local sh = K:at(arm[1], 0.2)
					local pos, nrm = K:surface(sh, rad(-30) * x, 0.06)
					H.crystal(K, g, SHARDS, pos, (nrm + Vector3.yAxis * 0.5).Unit, 0.5, 3, 22)
				end
			end,
		})
		GK.lids(K, Color3.fromHex("0E0B14"))
	end,
}
