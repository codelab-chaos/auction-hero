-- The Auctions tab lists what the player has up.
local ns = Boot()
ShowTab("auctions")
check("nothing known with the auction house closed", #ns.Owned.auctions, 0)
OpenAuctionHouse()
check("the list is read when it opens", #ns.Owned.auctions, 2)
check("an active auction", ns.Owned.auctions[1].sold, false)
check("a sold one", ns.Owned.auctions[2].sold, true)
checkTrue("the tab shows a summary", #Frames(function(frame)
	return tostring(frame.text):find("for sale,") ~= nil
end) > 0)
