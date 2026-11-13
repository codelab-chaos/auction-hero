-- A button on Blizzard's auction house window that opens the AuctioNitro
-- window. It sits on the game's own frame, so it uses the game's own button.
-- The auction house UI loads on demand, so the button is made the first time
-- it opens.
local _, ns = ...
local Bus = ns.Bus

local button

Bus:On("AH_OPENED", function()
	if button or not AuctionHouseFrame then
		return
	end
	button = CreateFrame("Button", nil, AuctionHouseFrame, "UIPanelButtonTemplate")
	button:SetSize(100, 22)
	button:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "TOPRIGHT", -4, 2)
	button:SetText(ns.L.TITLE)
	button:SetScript("OnClick", function()
		ns.Window:Toggle()
	end)
end)
