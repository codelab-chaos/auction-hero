-- Every tab builds, and nothing a player can click or hover raises an error.
local ns = Boot()
SlashCmdList.AUCTIONHERO("")
OpenAuctionHouse()
Scan()
checkTrue("the scan became a market", ns.Analysis and ns.Analysis.market)

local function tabs()
	local ids = {}
	for _, tab in ipairs(ns.Window.tabs) do
		if not tab.debug or ns.IsEnabled("debug") then
			ids[#ids + 1] = tab.id
		end
	end
	return table.concat(ids, ",")
end
check("tabs without debug", tabs(), "buy,sell,resell,auctions,ledger,history")
SlashCmdList.AUCTIONHERO("debug on")
check("tabs with debug", tabs(), "buy,sell,resell,auctions,ledger,history,debug")

local all = { "buy", "sell", "auctions", "resell", "history", "debug" }
for _, id in ipairs(all) do
	ns.charDb.tab = id
	ns.Window:Toggle()
	ns.Window:Toggle()
end
for _, view in ipairs(ns.Views) do
	ns.charDb.tab = "debug"
	ns.charDb.view = view.id
	ns.Window:RefreshActive()
end

-- Press, hover and type into everything on every tab, three times over, so
-- states reached by one click are exercised by the next.
local clicked = 0
for _ = 1, 3 do
	for _, id in ipairs(all) do
		ns.charDb.tab = id
		ns.Window:Toggle()
		ns.Window:Toggle()
		for _, frame in ipairs(ALL_FRAMES()) do
			if frame.shown ~= false then
				if frame.scripts.OnEnter then
					frame.scripts.OnEnter(frame)
				end
				if frame.scripts.OnLeave then
					frame.scripts.OnLeave(frame)
				end
				if frame.scripts.OnClick then
					frame.scripts.OnClick(frame)
					clicked = clicked + 1
				end
				if frame.scripts.OnMouseUp and frame.data then
					frame.scripts.OnMouseUp(frame)
				end
				if frame.scripts.OnTextChanged and frame.__kind == "EditBox" then
					frame.text = "12"
					frame.scripts.OnTextChanged(frame, true)
				end
				if frame.scripts.OnValueChanged then
					frame.scripts.OnValueChanged(frame, 2)
				end
			end
		end
		Tick(3)
	end
end
checkTrue("there was plenty to click", clicked > 500)

-- A player with almost no gold.
MONEY = 3
ns.Window:RefreshActive()
