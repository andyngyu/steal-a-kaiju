-- KaijuAnimation.DebugUI (Studio only): a small panel for reviewing the animation engine in Play mode.
--   Gallery / Back: go to the animation gallery and return. The arrows pick a creature; Look points the camera at it.
--   Actions: every action the creature can do (its own list first). States: force a state (Auto = read from the game).
--   Slow 0.25x, tier labels, Freeze, Night, and "All" (apply actions and states to every creature).
--   The readout shows creatures per tier and the engine's frame time; the numbers box shows the selected creature's
--   motion numbers (periods, degrees, spring frequency and damping) for tuning by name in Config.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DebugUI = {}

local STATES = { "Auto", "PenIdle", "OwnerNearby", "StrangerNearby", "Carried", "Asleep", "Wake" }

local function button(parent, text, w, onClick)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w or 64, 24)
	b.BackgroundColor3 = Color3.fromHex("2E3446")
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = text
	b.AutoButtonColor = true
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = b
	b.Parent = parent
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function row(parent, order, height)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, height or 24)
	f.AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y
	f.LayoutOrder = order
	local l = Instance.new("UIGridLayout")
	l.CellSize = UDim2.fromOffset(70, 24)
	l.CellPadding = UDim2.fromOffset(4, 4)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = f
	f.Parent = parent
	return f, l
end

local function label(parent, order, text, size)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 0)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = Color3.fromHex("DDE6FF")
	t.Font = Enum.Font.Gotham
	t.TextSize = size or 12
	t.Text = text
	t.LayoutOrder = order
	t.Parent = parent
	return t
end

function DebugUI.Start(Controller, Gallery)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "KaijuAnimDebug"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(310, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Position = UDim2.fromOffset(12, 150)
	panel.BackgroundColor3 = Color3.fromHex("151925")
	panel.BackgroundTransparency = 0.12
	panel.Visible = false
	panel.Parent = gui
	local pad = Instance.new("UIPadding")
	for _, k in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		pad[k] = UDim.new(0, 8)
	end
	pad.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel
	Instance.new("UICorner").Parent = panel

	local toggle = button(gui, "Kaiju Anim", 90, function()
		panel.Visible = not panel.Visible
	end)
	toggle.Position = UDim2.fromOffset(12, 118)

	local selected = 1
	local all = false
	local function names()
		return Gallery.Names()
	end
	local function current()
		local n = names()
		if #n == 0 then
			return nil
		end
		selected = (selected - 1) % #n + 1
		return n[selected]
	end
	local function target()
		return all and "all" or current()
	end

	label(panel, 1, "KAIJU ANIMATION (Studio)", 14).Font = Enum.Font.GothamBlack
	local r1 = row(panel, 2, 24)
	button(r1, "Gallery", 70, function()
		task.spawn(Gallery.Open, Controller)
	end)
	button(r1, "Back", 70, function()
		Gallery.Close()
	end)
	button(r1, "Free cam", 70, function()
		Gallery.Unfocus()
	end)

	local r2 = row(panel, 3, 24)
	local nameLabel
	local rebuildActions
	button(r2, "<", 30, function()
		selected -= 1
		rebuildActions()
	end)
	nameLabel = button(r2, "(open the gallery)", 70, function() end)
	button(r2, ">", 30, function()
		selected += 1
		rebuildActions()
	end)
	button(r2, "Look", 50, function()
		local n = current()
		if n then
			Gallery.Focus(n)
		end
	end)

	label(panel, 4, "Actions", 12).Font = Enum.Font.GothamBold
	local actionsRow = row(panel, 5)
	label(panel, 6, "States", 12).Font = Enum.Font.GothamBold
	local statesRow = row(panel, 7)
	for _, s in STATES do
		button(statesRow, s, 70, function()
			Controller.Command("state", target(), s ~= "Auto" and s or nil)
		end)
	end
	local r3 = row(panel, 8)
	local slow, lab, frz, night, allB
	slow = button(r3, "Slow 0.25x", 70, function()
		local on = slow.Text == "Slow 0.25x"
		Controller.Command("slowmo", on and 0.25 or 1)
		slow.Text = on and "Speed 1x" or "Slow 0.25x"
	end)
	lab = button(r3, "Labels", 70, function()
		local on = lab.Text == "Labels"
		Controller.Command("labels", on)
		lab.Text = on and "Labels off" or "Labels"
	end)
	frz = button(r3, "Freeze", 70, function()
		local on = frz.Text == "Freeze"
		Controller.Command("freeze", on)
		frz.Text = on and "Unfreeze" or "Freeze"
	end)
	local nightMode = 0
	night = button(r3, "Night: auto", 70, function()
		nightMode = (nightMode + 1) % 3
		Controller.Command("night", nightMode == 1 and true or nightMode == 2 and false or nil)
		night.Text = nightMode == 1 and "Night: on" or nightMode == 2 and "Night: off" or "Night: auto"
	end)
	allB = button(r3, "One", 70, function()
		all = not all
		allB.Text = all and "All" or "One"
	end)

	local readout = label(panel, 9, "", 12)
	readout.TextColor3 = Color3.fromHex("9CFF8A")
	local numbers = label(panel, 10, "", 11)

	rebuildActions = function()
		for _, c in actionsRow:GetChildren() do
			if c:IsA("GuiButton") then
				c:Destroy()
			end
		end
		local n = current()
		nameLabel.Text = n or "(open the gallery)"
		if not n then
			return
		end
		local text = Controller.Command("actions", n)
		local own, every = text:match("^(.-) | all: (.*)$")
		local seen = {}
		for _, list in { own or "", every or "" } do
			for a in string.gmatch(list, "[^,]+") do
				if not seen[a] then
					seen[a] = true
					local b = button(actionsRow, a, 70, function()
						Controller.Command("action", target(), a)
					end)
					if list == own then
						b.BackgroundColor3 = Color3.fromHex("4A3A8C")
					end
				end
			end
		end
		numbers.Text = Controller.Command("numbers", n)
	end

	local acc, lastCount = 0, -1
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 or not panel.Visible then
			return
		end
		acc = 0
		readout.Text = Controller.Status()
		local count = #names()
		if count ~= lastCount then
			lastCount = count
			rebuildActions()
		end
	end)
end

return DebugUI
