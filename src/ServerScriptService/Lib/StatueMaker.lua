-- Turns models into the Kaiju Citadel's golden statues: used at edit time by Tools.CitadelBuilder (the placeholders)
-- and at run time by Services.ChampionService (the richest player's avatar and their best kaiju).
--   StatueMaker.Gild(model, rich)        anchors every part, gilds it and strips everything that isn't shape: scripts,
--                                        joints, constraints, the humanoid, clothing, textures, sounds, effects, attributes;
--                                        rich = deeper golds (for avatars). Assembles a freshly made avatar first.
--   StatueMaker.RaiseFist(model)         an avatar's right arm (and whatever is attached to it) raised straight up; call
--                                        before Gild. Skipped for avatars in layered clothing (a jacket can't follow the arm)
--   StatueMaker.Place(model, base, facing, maxH, maxW)   scales the figure to fit maxH tall / maxW across, stands it on
--                                        base (the top centre of its plinth) and turns it to face the point facing
local StatueMaker = {}

local DEEP = Color3.fromRGB(168, 104, 22)
local MID = Color3.fromRGB(236, 166, 32)
local PALE = Color3.fromRGB(255, 226, 112)

-- a brick's brightness picks a shade of gold, so the model's pattern still reads; the darkest bricks become bronze
-- rather than black (black read as holes at statue scale)
local function gold(c, rich)
	local t = math.clamp((0.299 * c.R + 0.587 * c.G + 0.114 * c.B - 0.05) / 0.75, 0, 1)
	if rich then
		t *= 0.72 -- avatars are mostly bright skin and clothes: keep them in the deep and mid golds, not lemon
	end
	return t < 0.5 and DEEP:Lerp(MID, t * 2) or MID:Lerp(PALE, (t - 0.5) * 2)
end

local STRIP = {
	"LuaSourceContainer", "JointInstance", "Constraint", "NoCollisionConstraint", "WeldConstraint", "Sound",
	"ParticleEmitter", "Fire", "Smoke", "Sparkles", "Trail", "Beam", "Light", "BillboardGui", "SurfaceAppearance",
	"Clothing", "ShirtGraphic", "BodyColors", "Animator", "AnimationController", "HumanoidDescription", "ValueBase",
	"BindableFunction", "BindableEvent", "Animation", "FaceControls", "ProximityPrompt", "ClickDetector",
}

-- A freshly made avatar (Players:CreateHumanoidModelFromUserId) isn't put together yet: on a live server its body parts
-- and accessories sit wherever they were loaded until physics solves the joints. Walk the joints out from the root and
-- place every part where its joint says it belongs (Motor6Ds and welds by C0 / C1; the new avatar joints -
-- AnimationConstraint, BallSocketConstraint - and RigidConstraints by their two attachments, in the rest pose).
local function solveJoints(model)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root then
		return
	end
	local edges = {}
	local function add(a, b, place)
		table.insert(edges, { a, b, place })
	end
	-- two attachments that sit together in the rest pose. An attachment may hang off a skin Bone inside its part
	-- (skinned avatars keep the neck and shoulders on Chest / Clavicle bones), so each is measured against the part that
	-- owns it, before anything moves.
	local function link(a0, a1)
		local p0, p1 = a0:FindFirstAncestorWhichIsA("BasePart"), a1:FindFirstAncestorWhichIsA("BasePart")
		if not (p0 and p1) or p0 == p1 then
			return
		end
		local r0, r1 = p0.CFrame:ToObjectSpace(a0.WorldCFrame), p1.CFrame:ToObjectSpace(a1.WorldCFrame)
		add(p0, p1, function(cf)
			return cf * r0 * r1:Inverse()
		end)
		add(p1, p0, function(cf)
			return cf * r1 * r0:Inverse()
		end)
	end
	-- R15 bodies always carry a matching pair of "...RigAttachment"s at every joint (even when an avatar made at server
	-- start has no joints hooked up yet): these come first
	local rigs = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d.Name:sub(-13) == "RigAttachment" and not d:FindFirstAncestorWhichIsA("Accessory") then
			rigs[d.Name] = rigs[d.Name] or {}
			table.insert(rigs[d.Name], d)
		end
	end
	for _, pair in rigs do
		if #pair == 2 then
			link(pair[1], pair[2])
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") and d.Part0 and d.Part1 then
			local c0, c1 = d.C0, d.C1
			add(d.Part0, d.Part1, function(cf)
				return cf * c0 * c1:Inverse()
			end)
			add(d.Part1, d.Part0, function(cf)
				return cf * c1 * c0:Inverse()
			end)
		elseif (d:IsA("AnimationConstraint") or d:IsA("BallSocketConstraint") or d:IsA("RigidConstraint")) and d.Attachment0 and d.Attachment1 then
			link(d.Attachment0, d.Attachment1)
		end
	end
	local placed = { [root] = true }
	local progress = true
	while progress do
		progress = false
		for _, e in edges do
			if placed[e[1]] and not placed[e[2]] then
				e[2].CFrame = e[3](e[1].CFrame)
				placed[e[2]] = true
				progress = true
			end
		end
	end
	return placed
end

local function settleAccessories(model)
	local placed = solveJoints(model) or {}
	for _, acc in model:GetDescendants() do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			if handle and not placed[handle] then
				-- no weld: match the handle's attachment to the body attachment of the same name
				for _, a in handle:GetChildren() do
					if a:IsA("Attachment") then
						local target
						for _, p in model:GetChildren() do
							local t = p:IsA("BasePart") and p:FindFirstChild(a.Name, true)
							if t and t:IsA("Attachment") then
								target = t
								break
							end
						end
						if target then
							handle.CFrame = target.WorldCFrame * a.CFrame:Inverse()
							break
						end
					end
				end
			end
		end
	end
end

local function anchorAll(model)
	if not model:GetAttribute("StatueSettled") then
		settleAccessories(model)
		model:SetAttribute("StatueSettled", true)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

function StatueMaker.Gild(model, rich)
	anchorAll(model)
	for k in model:GetAttributes() do
		model:SetAttribute(k, nil)
	end
	-- the hidden core: an avatar's HumanoidRootPart (an R6 avatar's PrimaryPart is its head) or a kaiju's Root
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") or (not hum and model.PrimaryPart) or nil
	-- strip first: body colours and clothing would otherwise paint over the gold
	for _, d in model:GetDescendants() do
		for _, class in STRIP do
			if d:IsA(class) then
				d:Destroy()
				break
			end
		end
	end
	if hum then
		hum:Destroy()
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if d == root or d.Name == "HumanoidRootPart" or d.Transparency >= 1 then
				d.Transparency = 1
			elseif d.Material == Enum.Material.Neon and d.Name:find("Eye") then
				d.Color = Color3.fromRGB(255, 120, 24) -- eyes keep glowing, like embers
			elseif d.Material == Enum.Material.Neon then
				-- other glows (lava cracks, bellies, mouths) bloomed too much at statue size: bright solid gold instead
				d.Color = PALE
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
			else
				d.Color = gold(d.Color, rich)
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
			end
			if d:IsA("MeshPart") then
				pcall(function()
					d.TextureID = ""
				end)
			end
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
			d.VertexColor = Vector3.one
		elseif d:IsA("Decal") then
			-- the face stays, cast in dark bronze
			d.Color3 = Color3.fromRGB(96, 52, 8)
		elseif d:IsA("Texture") then
			d.Color3 = Color3.fromRGB(255, 214, 110)
		end
	end
	return model
end

local ARM = { RightUpperArm = true, RightLowerArm = true, RightHand = true, ["Right Arm"] = true }

function StatueMaker.RaiseFist(model, degrees)
	anchorAll(model) -- puts the avatar together first, so the shoulder is where it should be
	for _, d in model:GetDescendants() do
		if d:IsA("WrapLayer") then
			return false
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local upper = model:FindFirstChild("RightUpperArm") or model:FindFirstChild("Right Arm")
	if not (root and upper) then
		return false
	end
	local att = upper:FindFirstChild("RightShoulderRigAttachment") or upper:FindFirstChild("RightShoulderAttachment")
	local pivot = att and att.WorldPosition or (upper.CFrame * Vector3.new(-upper.Size.X / 2, upper.Size.Y / 2 - 0.5, 0))
	-- the arm, plus accessories welded to it
	local moving = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and ARM[d.Name] then
			moving[d] = true
		elseif d:IsA("JointInstance") and d.Part0 and d.Part1 then
			if ARM[d.Part0.Name] and d.Part1.Parent and d.Part1.Parent:IsA("Accessory") then
				moving[d.Part1] = true
			elseif ARM[d.Part1.Name] and d.Part0.Parent and d.Part0.Parent:IsA("Accessory") then
				moving[d.Part0] = true
			end
		end
	end
	-- (everything is anchored, so each part moves on its own)
	-- turning about the body's back axis swings a hanging right arm out to the side and up
	local turn = CFrame.new(pivot) * CFrame.fromAxisAngle(-root.CFrame.LookVector, math.rad(degrees or 168)) * CFrame.new(-pivot)
	for p in moving do
		p.CFrame = turn * p.CFrame
	end
	return true
end

function StatueMaker.Place(model, base, facing, maxH, maxW)
	local flat = Vector3.new(facing.X - base.X, 0, facing.Z - base.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	local at = CFrame.lookAt(base, base + flat)
	model:PivotTo(at)
	local _, size = model:GetBoundingBox()
	local s = math.min(maxH / size.Y, maxW / math.max(size.X, size.Z))
	model:ScaleTo(model:GetScale() * s)
	model:PivotTo(at)
	-- centre the figure over the plinth and stand it on top
	local cf, size2 = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(base.X - cf.X, base.Y - (cf.Y - size2.Y / 2), base.Z - cf.Z))
	return model
end

return StatueMaker
