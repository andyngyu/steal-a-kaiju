-- Client entry point of the kaiju animation engine (ReplicatedStorage.KaijuAnimation). Starts the controller. In Studio it
-- also adds the review tools: the animation Gallery, the debug panel ("Kaiju Anim" button) and a BindableFunction
-- "Debug" under this script for scripted control:
--   Debug:Invoke("gallery")                       build the gallery and go there ("gallery", "close" to leave)
--   Debug:Invoke("focus", name, view)             camera on one creature (view: front, side, back, top)
--   Debug:Invoke("action", name or "all", action) play an action
--   Debug:Invoke("state", name or "all", state)   force a state (nil: read it from the game again)
--   Debug:Invoke("status" | "list" | "numbers" | "probe" | "pose" | "slowmo" | "labels" | "freeze" | "night", ...)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local folder = ReplicatedStorage:WaitForChild("KaijuAnimation")
local Controller = require(folder:WaitForChild("Controller"))
Controller.Start()

if RunService:IsStudio() then
	local Gallery = require(folder:WaitForChild("Gallery"))
	local DebugUI = require(folder:WaitForChild("DebugUI"))
	local debug = Instance.new("BindableFunction")
	debug.Name = "Debug"
	debug.OnInvoke = function(cmd, a, b)
		if cmd == "gallery" then
			if a == "close" then
				Gallery.Close()
				return true
			end
			return Gallery.Open(Controller)
		elseif cmd == "focus" then
			return Gallery.Focus(a, b)
		elseif cmd == "unfocus" then
			Gallery.Unfocus()
			return true
		end
		return Controller.Command(cmd, a, b)
	end
	debug.Parent = script
	DebugUI.Start(Controller, Gallery)
end
