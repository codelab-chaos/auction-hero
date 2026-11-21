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
check("tabs without debug", tabs(), "buy,sell,resell,auctions,ledger,history,progress")
SlashCmdList.AUCTIONHERO("debug on")
check("tabs with debug", tabs(), "buy,sell,resell,auctions,ledger,history,progress,debug")

local all = { "buy", "sell", "auctions", "resell", "history", "debug", "progress" }
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

-- Graphs, Progress and Debug sit at the right end of the tab row; Progress is
-- a pouch, and Debug a skull, always last while it is on.
SlashCmdList.AUCTIONHERO("debug")
Tick(2)
local function tabButton(id)
	return Frames(function(frame)
		return frame.tabId == id
	end)[1]
end
check("Buy runs from the left", tabButton("buy").lastPoint[1], "TOPLEFT")
check("Graphs sits at the right", tabButton("history").lastPoint[1], "TOPRIGHT")
check("Debug too", tabButton("debug").lastPoint[1], "TOPRIGHT")
local icon = ns.Theme.tabIconWidth + 2
check("Debug at the very end", tabButton("debug").lastPoint[2], -ns.Theme.pad)
check("Progress before it", tabButton("progress").lastPoint[2], -(ns.Theme.pad + icon))
check("with Graphs before that", tabButton("history").lastPoint[2], -(ns.Theme.pad + icon * 2))
checkTrue("Progress shows its icon", tabButton("progress").icon ~= nil and tabButton("progress").label.text == "")
check("with debug off, Progress is last", (function() SlashCmdList.AUCTIONHERO("debug"); Tick(2); local x = tabButton("progress").lastPoint[2]; SlashCmdList.AUCTIONHERO("debug"); Tick(2); return x end)(), -ns.Theme.pad)
checkTrue("Debug shows a skull, not its name", tabButton("debug").icon ~= nil and tabButton("debug").label.text == "")
SlashCmdList.AUCTIONHERO("debug")
Tick(2)

-- Closing the window can close the auction house too, when the player asks.
local closes = 0
C_AuctionHouse.CloseAuctionHouse = function()
	closes = closes + 1
end
OpenAuctionHouse()
ns.Window:Show()
local frame = _G.AuctionHeroWindow or Frames(function(f) return f.scripts.OnHide ~= nil and f.scripts.OnShow ~= nil end)[1]
check("off by default", ns.SettingById.closeAuctionHouse.default, false)
ns.SetEnabled("closeAuctionHouse", false)
frame:Hide()
check("off: the auction house stays open", closes, 0)
ns.SetEnabled("closeAuctionHouse", true)
ns.Window:Show()
frame:Hide()
check("on: closing the window closes the auction house", closes, 1)
ns.Window:Show()
ns.Downloader.IsRunning = function() return true end
frame:Hide()
check("but never while a scan runs", closes, 1)

-- The title says it is early access, and "feedback welcome" gives the
-- CurseForge page's address to copy.
local function titleText(text)
	return Frames(function(frame)
		local value = type(frame.text) == "table" and frame.text.text or frame.text
		return value == text
	end)[1]
end
ShowTab("buy") -- the window, open
checkTrue("the title says early access", titleText("Early Access  |  ") ~= nil)
local feedback = Frames(function(frame)
	return frame.label and frame.label.text == "feedback welcome" and frame.scripts.OnClick
end)[1]
checkTrue("with a feedback link", feedback ~= nil)
feedback.scripts.OnClick(feedback)
checkTrue("that shows the project page to copy", titleText("https://www.curseforge.com/wow/addons/auction-hero") ~= nil)
