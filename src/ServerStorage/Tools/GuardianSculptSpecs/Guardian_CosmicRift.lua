local rad = math.rad
local GK = require(script.Parent.GuardianKit)
local H = GK.H

-- Cosmic Rift guardian: the Void Colossus, a titan knuckle-walking out of the rift. Its body is deep violet obsidian
-- plates split by black-lipped cracks blazing with magenta void light. In its chest a black hole: a black sphere ringed
-- by a thick, blazing magenta accretion disk. Chunks of rock orbit it on two tilted paths, some glowing inside, crystal
-- shards erupt from its back and fists. Its head is a horned skull of pale bone: a heavy jutting brow over deep sockets
-- with burning magenta eyes, bony cheeks, slit nostrils, a fanged jaw glowing with void light, two great crystal horns
-- curving up and forward and a crystal crest. (The ape body plan builds a gorilla face; it is cleared and replaced.)
local HEAD = H.APE_HEAD
local HS = 1.2
local HINGE = Vector3.new(0, -0.24, -0.24)
local JOINTS = {}
for k, v in H.APE_JOINTS do
	JOINTS[k] = v
end
JOINTS.Jaw = HEAD.Position + (HEAD * HINGE - HEAD.Position) * HS

return {
	Seed = 771,
	Vary = 0.04,
	Scale = 5.0,
	RootSize = { 9.0, 8.0, 8.5 },
	HipHeight = 2.4,
	Palette = {
		Fur = { "3A2C62", Material = "Slate" },
		FurDark = { "2A1E4C", Material = "Slate" },
		FurLight = { "4E3E80", Material = "Slate" },
		Skin = { "34285A", Material = "Slate" },
		SkinDark = { "241A44", Material = "Slate" },
		Bone = { "C8C0DE", Material = "Slate" },
		BoneShade = { "8C82AE", Material = "Slate" },
		BoneDark = { "4A4068", Material = "Slate" },
		Void = { "E040FF", Neon = true },
		SeamLip = { "08060C", Material = "Slate" },
		Star = { "FFF4FF", Neon = true },
		Hole = "020104",
		Disc = { "FF3ACC", Neon = true },
		DiscHot = { "FFB8F2", Neon = true },
		Rock = { "5A5078", Material = "Basalt" },
		RockDark = { "3A3254", Material = "Basalt" },
		Crystal = "B8A4FF",
		CrystalDark = "7A62D0",
		CrystalLight = "DCD0FF",
		Tooth = "ECE6F4",
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
		local parts = H.ape(K, { back = "FurDark", furLift = 4, core = "FurDark", limbCore = "FurDark", overlap = 1.05 })
		-- clear the gorilla face the body plan built; the skull goes in its place
		for _, g in { "Head", "Jaw" } do
			for _, d in K.groups[g]:GetChildren() do
				if d:IsA("BasePart") then
					d:Destroy()
				end
			end
		end

		-- black-lipped cracks blazing with void light across the obsidian
		local VEIN = { width = 0.14, height = 0.14, lift = 0.14, wander = 30, step = 0.3, forks = 2, forkSteps = 3, forkTurn = 50, lip = "SeamLip", lipW = 0.05 }
		local torso = parts.torso
		for _, th in { 60, -60, 104, -104 } do
			H.vein(K, "Body", "Void", torso, rad(th), 0.2, torso.total - 0.2, VEIN)
		end
		H.vein(K, "Body", "Void", parts.mantle, rad(-40), 0.2, parts.mantle.total - 0.2, VEIN)
		for g, arm in parts.arms do
			local x = g == "ArmL" and 1 or -1
			H.vein(K, g, "Void", arm[1], rad(100) * x, 0.1, arm[1].total - 0.1, VEIN)
			H.vein(K, g, "Void", arm[2], rad(110) * x, 0.1, arm[2].total - 0.1, VEIN)
		end
		for g, leg in parts.legs do
			H.vein(K, g, "Void", leg[1], rad(100) * (g == "LegL" and 1 or -1), 0.1, leg[1].total - 0.1, VEIN)
		end

		-- the black hole in its chest: a black sphere ringed by a thick, tilted, blazing accretion disk
		local chestN = Vector3.new(0, -0.3, -1).Unit
		local c = Vector3.new(0, 2.28, -1.46)
		K:block("Body", "Skin", CFrame.lookAt(c - chestN * 0.18, c - chestN), Vector3.new(1.5, 1.3, 0.3))
		for i, ang in { { 0, 0, 0 }, { 45, 0, 0 }, { 0, 45, 0 }, { 0, 0, 45 }, { 35, 35, 0 } } do
			K:block("Body", "Hole", CFrame.new(c + chestN * 0.12) * CFrame.Angles(rad(ang[1]), rad(ang[2]), rad(ang[3])), Vector3.new(0.6, 0.6, 0.6))
		end
		local D = CFrame.fromMatrix(c + chestN * 0.12, Vector3.xAxis, chestN) * CFrame.Angles(rad(22), 0, rad(-14))
		local N = 20
		for k = 0, N - 1 do
			local a0, a1 = k / N * math.pi * 2, (k + 1) / N * math.pi * 2
			for band, o in { { 0.54, 0.18, "DiscHot" }, { 0.72, 0.2, "Disc" }, { 0.88, 0.12, "Disc" } } do
				local p0 = D * Vector3.new(math.cos(a0) * o[1], 0, math.sin(a0) * o[1])
				local p1 = D * Vector3.new(math.cos(a1) * o[1], 0, math.sin(a1) * o[1])
				K:block("Body", (band == 3 and k % 3 == 0) and "Star" or o[3], CFrame.lookAt((p0 + p1) / 2, p1, D.UpVector), Vector3.new(o[2], 0.1, (p1 - p0).Magnitude + 0.05))
			end
		end

		-- crystal shards erupting from the back and the shoulders
		for s = 0.3, torso.total - 0.3, 0.42 do
			local smp = K:at(torso, s)
			for _, th in { rad(30), rad(-30) } do
				local pos, nrm = K:surface(smp, th, 0.06)
				H.crystal(K, "Body", SHARDS, pos, (nrm + smp.T * 0.2).Unit, 0.56, 3, 22)
			end
		end
		-- chunks of rock orbiting it on two tilted paths (no ring lines), a few glowing inside
		for ri, o in { { Vector3.new(0, 3.3, 0.1), 2.3, rad(18), rad(10), 7 }, { Vector3.new(0, 2.5, 0.3), 2.8, rad(-14), rad(-22), 6 } } do
			local tilt = CFrame.new(o[1]) * CFrame.Angles(o[3], 0, o[4])
			for k = 0, o[5] - 1 do
				local a = rad(k * 360 / o[5] + ri * 25 + K:rand(-10, 10))
				local p = tilt * Vector3.new(math.cos(a) * o[2], K:rand(-0.12, 0.12), math.sin(a) * o[2] * 1.1)
				local s = K:rand(0.38, 0.62)
				K:block("Body", k % 2 == 0 and "Rock" or "RockDark", CFrame.new(p) * CFrame.Angles(rad(K:rand(0, 90)), rad(K:rand(0, 90)), rad(K:rand(0, 60))), Vector3.new(s, s * 0.8, s))
				K:block("Body", "Rock", CFrame.new(p + Vector3.new(K:rand(-0.12, 0.12), s * 0.3, K:rand(-0.12, 0.12))) * CFrame.Angles(rad(K:rand(0, 90)), rad(K:rand(0, 90)), 0), Vector3.new(s * 0.7, s * 0.6, s * 0.7))
				K:block("Body", "RockDark", CFrame.new(p + Vector3.new(s * 0.3, -s * 0.15, 0)) * CFrame.Angles(0, rad(K:rand(0, 90)), rad(K:rand(0, 90))), Vector3.new(s * 0.5, s * 0.45, s * 0.5))
				if k % 2 == 1 then
					K:block("Body", "Void", CFrame.new(p) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(s * 0.42, s * 0.42, s * 0.42))
				end
			end
		end
		-- fists clad in violet crystal
		for _, x in { 1, -1 } do
			local g = x == 1 and "ArmL" or "ArmR"
			local fist = Vector3.new(1.44 * x, 0.5, -0.86)
			H.crystal(K, g, SHARDS, fist + Vector3.new(0, 0.1, -0.2), Vector3.new(0.2 * x, 0.6, -1), 0.56, 4, 30)
			H.crystal(K, g, SHARDS, fist + Vector3.new(0.2 * x, 0.3, 0.1), Vector3.new(0.6 * x, 1, 0), 0.4, 3, 24)
			local sh = K:at(parts.arms[g][1], 0.2)
			local pos, nrm = K:surface(sh, rad(-30) * x, 0.06)
			H.crystal(K, g, SHARDS, pos, (nrm + Vector3.yAxis * 0.5).Unit, 0.5, 3, 22)
		end

		-- the horned skull
		local function hcf(px, py, pz, ax, ay, az)
			return HEAD * CFrame.new(px, py, pz) * CFrame.Angles(rad(ax or 0), rad(ay or 0), rad(az or 0))
		end
		local function hp(px, py, pz)
			return HEAD * Vector3.new(px, py, pz)
		end
		local function hv(px, py, pz)
			return HEAD:VectorToWorldSpace(Vector3.new(px, py, pz)).Unit
		end
		K:scaled(HEAD.Position, HS, function()
			-- cranium, sloping back into the neck
			K:block("Head", "Bone", hcf(0, 0.22, -0.28), Vector3.new(0.86, 0.66, 0.74))
			K:block("Head", "Bone", hcf(0, 0.24, -0.26, 0, 0, 45), Vector3.new(0.64, 0.64, 0.7))
			K:block("Head", "BoneShade", hcf(0, 0.56, -0.2, -12, 0, 0), Vector3.new(0.5, 0.12, 0.6))
			-- the heavy jutting brow ridge, sharp at the outer corners
			K:block("Head", "BoneShade", hcf(0, 0.44, -0.68, -12, 0, 0), Vector3.new(0.96, 0.18, 0.26))
			for _, x in { 1, -1 } do
				K:block("Head", "Bone", hcf(0.28 * x, 0.46, -0.66, -10, -16 * x, 22 * x), Vector3.new(0.42, 0.18, 0.34))
				K:spike("Head", "BoneShade", hp(0.5 * x, 0.46, -0.6), hv(x, 0.3, 0.2), hv(0, 0, 1), 0.22, 0.12)
				-- deep sockets with burning eyes
				K:block("Head", "Socket", hcf(0.22 * x, 0.25, -0.72, 0, -12 * x, 0), Vector3.new(0.32, 0.22, 0.1))
				K:block("Head", "Eye", hcf(0.22 * x, 0.25, -0.78, 0, -12 * x, 12 * x), Vector3.new(0.26, 0.13, 0.05), "Eye")
				-- bony cheekbones
				K:block("Head", "Bone", hcf(0.38 * x, 0.06, -0.52, 0, -20 * x, -8 * x), Vector3.new(0.18, 0.24, 0.5))
				-- great crystal horns curving up and forward
				H.curve(K, "Head", { "CrystalDark", "Crystal", "Crystal", "CrystalLight" }, { hp(0.34 * x, 0.52, -0.36), hp(0.66 * x, 0.92, -0.26), hp(0.88 * x, 1.36, -0.5), hp(0.82 * x, 1.66, -0.92) }, 0.34, 0.08, 0.1)
				K:block("Head", "Void", hcf(0.34 * x, 0.52, -0.36), Vector3.new(0.2, 0.2, 0.2))
			end
			-- a short snout of bone with slit nostrils, fangs over the lip
			K:block("Head", "Bone", hcf(0, 0.04, -0.86, -6, 0, 0), Vector3.new(0.56, 0.34, 0.4))
			K:block("Head", "BoneShade", hcf(0, 0.22, -0.9, -14, 0, 0), Vector3.new(0.2, 0.08, 0.36))
			for _, x in { 1, -1 } do
				K:block("Head", "Socket", hcf(0.07 * x, 0.14, -1.07, -10, 0, 0), Vector3.new(0.04, 0.07, 0.04))
				H.fang(K, "Head", "Tooth", hp(0.2 * x, -0.12, -0.98), hv(0, -1, -0.1), 0.3, 0.08)
			end
			H.teeth(K, "Head", "Tooth", hp(-0.14, -0.12, -1.04), hp(0.14, -0.12, -1.04), 4, hv(0, -1, 0), hv(0, 0, 1), 0.12, 0.05)
			K:block("Head", "Mouth", hcf(0, -0.16, -0.72), Vector3.new(0.5, 0.06, 0.5))
			-- a crest of crystal shards on the crown
			H.crystal(K, "Head", SHARDS, hp(0, 0.66, -0.1), hv(0, 1, 0.5), 0.52, 4, 26)
			-- the jaw: a heavy bony jaw hanging open, glowing inside, fangs
			local JAW = HEAD * CFrame.new(HINGE) * CFrame.Angles(rad(-18), 0, 0)
			K:block("Jaw", "Bone", JAW * CFrame.new(0, -0.12, -0.5), Vector3.new(0.6, 0.22, 0.72))
			K:block("Jaw", "BoneDark", JAW * CFrame.new(0, -0.2, -0.2), Vector3.new(0.72, 0.24, 0.4))
			K:block("Jaw", "Mouth", JAW * CFrame.new(0, 0.0, -0.5), Vector3.new(0.48, 0.05, 0.62))
			for _, x in { 1, -1 } do
				H.fang(K, "Jaw", "Tooth", JAW * Vector3.new(0.22 * x, 0, -0.78), JAW:VectorToWorldSpace(Vector3.new(0, 1, 0.05)).Unit, 0.26, 0.07)
				H.teeth(K, "Jaw", "Tooth", JAW * Vector3.new(0.24 * x, 0, -0.3), JAW * Vector3.new(0.22 * x, 0, -0.66), 3, JAW:VectorToWorldSpace(Vector3.yAxis), JAW:VectorToWorldSpace(Vector3.xAxis), 0.1, 0.05)
			end
		end)
		GK.lids(K, Color3.fromHex("241A44"))
	end,
}
