-- Players pass through each other (still collide with the world).
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local GROUP = "Players"
PhysicsService:RegisterCollisionGroup(GROUP)
PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)

local function setGroup(inst)
	if inst:IsA("BasePart") then
		inst.CollisionGroup = GROUP
	end
end

local function onCharacter(character)
	for _, d in character:GetDescendants() do
		setGroup(d)
	end
	character.DescendantAdded:Connect(setGroup)
end

local function onPlayer(player)
	if player.Character then onCharacter(player.Character) end
	player.CharacterAdded:Connect(onCharacter)
end

for _, p in Players:GetPlayers() do onPlayer(p) end
Players.PlayerAdded:Connect(onPlayer)
