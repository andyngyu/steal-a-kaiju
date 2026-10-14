-- Restyles the in-world signs that CitadelBuilder doesn't build itself into the citadel's carved style: Antique lettering
-- in gold (titles) or cream (smaller text) with a dark stroke, on dark timber (wooden boards) or slate (stone plaques).
-- Only fonts, text colours, strokes and board colours change; nothing is moved, renamed or rebuilt, and each gui gets
-- NoAutoGradient so WorldTextController leaves the lettering alone. Returns the list of signs it changed.
-- Deliberately left alone (Andy's do-not-touch list, or scripts write to them): the PLOT boards, Treadmill and Upgrade
-- signs, the food stall's restock board (MarketFX), the safe-zone line (GameVFX / GameAudio), the biome speed signs
-- (SpeedFX), food price tags and the leaderboards (LeaderboardController).
-- MarketBuilder and BiomeArtBuilder still build the old style: re-run this after either of them.
return function(map, K)
	local P = K.P
	local changed = {}

	local function restyle(gui, color)
		gui:SetAttribute("NoAutoGradient", true)
		for _, l in gui:GetDescendants() do
			if l:IsA("TextLabel") then
				l.Font = Enum.Font.Antique
				l.TextColor3 = color
				for _, c in l:GetChildren() do
					if c:IsA("UIGradient") then
						c:Destroy()
					end
				end
				local s = l:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
				s.Color = P.Ink
				s.Thickness = math.max(s.Thickness, 3)
				s.Parent = l
			end
		end
	end
	local function guis(part, color)
		for _, g in part:GetChildren() do
			if g:IsA("SurfaceGui") or g:IsA("BillboardGui") then
				restyle(g, color)
			end
		end
	end
	local function board(part, color)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
	end

	local market = map:FindFirstChild("Market")
	local decor = market and market:FindFirstChild("Decor")
	-- the KAIJU MARKET arch: dark timber board, gold trim
	local arch = decor and decor:FindFirstChild("MarketArch")
	local archBoard = arch and arch:FindFirstChild("Board")
	if archBoard then
		board(archBoard, P.TimberDark)
		guis(archBoard, P.SignGold)
		for _, t in arch:GetChildren() do
			if t.Name == "Trim" and t:IsA("BasePart") then
				t.Color = P.Gold
			end
		end
		table.insert(changed, "KAIJU MARKET - market arch board, both faces (Map.Market.Decor.MarketArch.Board)")
	end
	-- the stalls' title boards
	for _, s in { { "FoodStall", "KAIJU FOOD" }, { "SellStall", "SELL" }, { "TrailStall", "TRAILS" } } do
		local stall = market and market:FindFirstChild(s[1])
		local sb = stall and stall:FindFirstChild("SignBoard")
		if sb then
			board(sb, P.TimberDark)
			guis(sb, P.SignGold)
			table.insert(changed, s[2] .. " - " .. s[1] .. " title board, both faces (Map.Market." .. s[1] .. ".SignBoard)")
		end
	end
	-- the sell stall's money bag
	local bag = market and market:FindFirstChild("SellStall") and market.SellStall:FindFirstChild("MoneyBag")
	if bag then
		guis(bag, P.SignGold)
		table.insert(changed, "$ - the sell stall's money bag (Map.Market.SellStall.MoneyBag)")
	end
	-- the golden Rumblerex's plaque: slate
	local statue = decor and decor:FindFirstChild("KaijuStatue")
	local plaque = statue and statue:FindFirstChild("Plaque")
	if plaque then
		board(plaque, P.Slate)
		guis(plaque, P.SignGold)
		table.insert(changed, "RUMBLEREX - the group-reward statue's plaque (Map.Market.Decor.KaijuStatue.Plaque)")
	end
	-- the group reward's floating sign: gold title, cream line under it
	local anchor = market and market:FindFirstChild("GroupReward") and market.GroupReward:FindFirstChild("SignAnchor")
	local reward = anchor and anchor:FindFirstChild("RewardSign")
	if reward then
		restyle(reward, P.SignCream)
		local title = reward:FindFirstChild("Title")
		if title then
			title.TextColor3 = P.SignGold
		end
		table.insert(changed, "FREE REWARDS! / Join the group to claim - floating group-reward sign (Map.Market.GroupReward.SignAnchor.RewardSign)")
	end
	-- the NEST signs in the lanes: dark timber board, cream lettering
	local lane = map:FindFirstChild("Lane")
	if lane then
		for _, biome in lane:GetChildren() do
			local dec = biome:FindFirstChild("Decor")
			for _, d in dec and dec:GetChildren() or {} do
				local sign = d.Name:sub(1, 8) == "NestSign" and d:FindFirstChild("Sign")
				local b = sign and sign:FindFirstChild("Board")
				if b then
					board(b, P.Timber)
					guis(b, P.SignCream)
					table.insert(changed, "NEST > - " .. biome.Name .. " nest sign (Map.Lane." .. biome.Name .. ".Decor." .. d.Name .. ")")
				end
			end
		end
	end
	return changed
end
