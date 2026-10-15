local rad = math.rad
local H = require(script.Parent.Helpers)

-- Cosmic Rift / Epic / void: the gorillaxy, a gorilla with a galaxy inside it. A hulking black-furred ape
-- knuckle-walking on fists of violet crystal, a glowing spiral galaxy swirling across its bare violet chest and another
-- across its back, flecks of stars in the fur, two small moons circling its shoulders on glowing orbit rings. Face: a
-- heavy brow over glowing magenta eyes, a crest of crystal shards on the skull, bared fangs.
local function galaxy(K, group, F, scale, lift)
	-- a bright core and three spiral arms of violet, pink and starlight, laid flat in the frame F (Y = out of the body)
	K:block(group, "Core", F * CFrame.new(0, lift + 0.03, 0) * CFrame.Angles(0, rad(45), 0), Vector3.new(0.3, 0.08, 0.3) * scale)
	K:block(group, "Void", F * CFrame.new(0, lift, 0), Vector3.new(0.46, 0.06, 0.46) * scale)
	for arm = 0, 2 do
		for k = 1, 8 do
			local t = k / 8
			local a = rad(arm * 120 + t * 210)
			local r = (0.16 + t * 0.62) * scale
			local s = (0.24 - t * 0.12) * scale
			local key = k % 3 == 0 and "Star" or (k % 3 == 1 and "GalaxyPink" or "GalaxyViolet")
			K:block(group, key, F * CFrame.new(math.cos(a) * r, lift - t * 0.03, math.sin(a) * r) * CFrame.Angles(0, -a, 0), Vector3.new(s, 0.06, s * 1.5))
		end
	end
end

return {
	Seed = 731,
	Vary = 0.04,
	Scale = 0.92,
	Gait = "Knuckle",
	Emotes = { "Look", "ChestBeat" },
	Palette = {
		Fur = "1E1A2C",
		FurDark = "100D18",
		FurLight = "30284A",
		Skin = "3A2C5E",
		SkinDark = "281E44",
		Crystal = "B8A4FF",
		CrystalDark = "7A62D0",
		CrystalLight = "DCD0FF",
		Core = { "FFF4FF", Neon = true },
		Void = { "C83AF0", Neon = true },
		GalaxyPink = { "FF5AC8", Neon = true },
		GalaxyViolet = { "8A5CFF", Neon = true },
		Star = { "FFF4FF", Neon = true },
		Orbit = { "A07AFF", Neon = true, Transparency = 0.2 },
		Moon = { "8C8698", Material = "Basalt" },
		MoonDark = { "4E4A58", Material = "Basalt" },
		Tooth = "EEE8F4",
		Mouth = "3A1238",
		Eye = { "FF40E0", Neon = true },
		Socket = "07050C",
		Claw = "141018",
		ClawTip = "C8B8E8",
	},
	Joints = H.APE_JOINTS,
	Parents = { Jaw = "Head", EarL = "Head", EarR = "Head" },
	Build = function(K)
		local SHARDS = { "Crystal", "CrystalDark", "CrystalLight", "Crystal" }
		H.ape(K, {
			back = "FurDark",
			crest = { "CrystalDark", "Crystal", "CrystalLight" },
			head = function(K, hcf, hp, hv)
				-- a crest of crystal shards breaking out of the skull
				H.crystal(K, "Head", SHARDS, hp(0, 0.66, -0.1), hv(0, 1, 0.5), 0.5, 4, 26)
				for _, x in { 1, -1 } do
					K:block("Head", "Star", hcf(0.36 * x, 0.36, -0.36), Vector3.new(0.06, 0.06, 0.06))
				end
			end,
			extras = function(K, parts)
				local torso = parts.torso
				-- the galaxy on the chest, facing forward under the head
				local chestN = Vector3.new(0, -0.35, -1).Unit
				local chest = Vector3.new(0, 2.5, -1.36)
				K:block("Body", "Skin", CFrame.lookAt(chest - chestN * 0.12, chest - chestN), Vector3.new(1.5, 1.2, 0.3))
				galaxy(K, "Body", CFrame.fromMatrix(chest, Vector3.xAxis, chestN), 1.1, 0.06)
				-- and one across the back, over the fur
				local smp2 = K:at(torso, 0.62)
				local pos2, nrm2 = K:surface(smp2, 0, 0.0)
				galaxy(K, "Body", CFrame.fromMatrix(pos2, smp2.R, nrm2), 1.0, 0.34)
				-- stars flecked through the fur
				for i = 1, 22 do
					local s2 = K:at(torso, K:rand(0.1, torso.total - 0.1))
					local p = K:surface(s2, rad(K:rand(20, 120)) * (i % 2 == 0 and 1 or -1), -0.16)
					K:block("Body", "Star", CFrame.new(p) * CFrame.Angles(rad(45), rad(45), 0), Vector3.new(0.08, 0.08, 0.08))
				end
				-- two small moons circling the shoulders on glowing orbit rings
				for _, x in { 1, -1 } do
					local c = Vector3.new(1.2 * x, 3.2, -0.5)
					local tilt = CFrame.new(c) * CFrame.Angles(rad(18), 0, rad(28 * x))
					local R = 1.0
					local prev
					for deg = 0, 360, 15 do
						local p = tilt * Vector3.new(math.cos(rad(deg)) * R, 0, math.sin(rad(deg)) * R)
						if prev then
							K:block("Body", "Orbit", CFrame.lookAt((prev + p) / 2, p) * CFrame.Angles(0, 0, rad(45)), Vector3.new(0.15, 0.15, (p - prev).Magnitude + 0.06))
						end
						prev = p
					end
					local m = tilt * Vector3.new(math.cos(rad(x == 1 and 200 or -20)) * R, 0, math.sin(rad(x == 1 and 200 or -20)) * R)
					K:block("Body", "Moon", CFrame.new(m) * CFrame.Angles(rad(20), rad(30), 0), Vector3.new(0.52, 0.52, 0.52))
					K:block("Body", "Moon", CFrame.new(m) * CFrame.Angles(rad(65), rad(75), rad(20)), Vector3.new(0.46, 0.46, 0.46))
					K:block("Body", "MoonDark", CFrame.new(m + Vector3.new(0.1, 0.14, -0.2)), Vector3.new(0.16, 0.08, 0.16))
					K:block("Body", "MoonDark", CFrame.new(m + Vector3.new(-0.14, -0.06, -0.22)), Vector3.new(0.12, 0.08, 0.12))
					-- crystal knuckles: violet shards breaking out of the fists
					local g = x == 1 and "ArmL" or "ArmR"
					local fist = Vector3.new(1.44 * x, 0.5, -0.86)
					H.crystal(K, g, SHARDS, fist + Vector3.new(0, 0.1, -0.2), Vector3.new(0.2 * x, 0.6, -1), 0.62, 4, 30)
					H.crystal(K, g, SHARDS, fist + Vector3.new(0.2 * x, 0.3, 0.1), Vector3.new(0.6 * x, 1, 0), 0.4, 3, 24)
					K:block(g, "Crystal", CFrame.new(1.44 * x, 0.14, -1.08) * CFrame.Angles(0, rad(-8 * x), 0), Vector3.new(0.66, 0.16, 0.12))
				end
			end,
		})
	end,
}
