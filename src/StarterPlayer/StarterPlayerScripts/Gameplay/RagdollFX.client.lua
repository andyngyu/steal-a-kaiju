-- The local player's side of a ragdoll (ServerScriptService.Lib.Ragdoll does the joints on the server): while the
-- character attribute RagdollUntil is set, the Humanoid sits in the Physics state so the body flops instead of standing
-- up; when it clears, the character gets up.
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function watch(char)
	local hum = char:WaitForChild("Humanoid")
	local limp = false
	local function update()
		local on = char:GetAttribute("RagdollUntil") ~= nil
		if on and not limp then
			limp = true
			hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		elseif not on and limp then
			limp = false
			hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
	char:GetAttributeChangedSignal("RagdollUntil"):Connect(update)
	update()
end

player.CharacterAdded:Connect(watch)
if player.Character then
	task.spawn(watch, player.Character)
end
