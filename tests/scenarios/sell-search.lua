-- Picking an item to sell asks the game for its live listings, with the same
-- query the game's own sell form sends.
local ns = Boot()
OpenAuctionHouse()
Scan()

ns.SellSearch:Request("2006:Tunic of the Bear")
check("equipment is searched by item id, level and suffix cleared", SEARCHES[#SEARCHES], "sellsearch 2006 level=0")
check("asked, not yet answered", ns.SellSearch.state.phase, "sent")
checkTrue("counts as asked", ns.SellSearch:Asked("2006:Tunic of the Bear"))
Tick(3)
check("answered", ns.SellSearch.state.phase, "done")
check("live listings are read", #ns.SellSearch.state.listings, 2)
check("with their unit price", ns.SellSearch.state.listings[1].unit, 100)

ns.SellSearch:Request("2003:Light Leather")
check("goods sold by the unit are searched with no sort orders", SEARCHES[#SEARCHES], "search sorts=0 2003 level=12")
Tick(3)
check("their listings come from the commodity results", ns.SellSearch.state.listings[1].quantity, 40)

local before = #SEARCHES
ns.SellSearch:Request("2003:Light Leather")
check("asking again for the same item sends nothing", #SEARCHES, before)

FireEvent("AUCTION_HOUSE_CLOSED")
check("closing forgets the search", ns.SellSearch.state.phase, "idle")

-- The Sell tab asks by itself when an item is shown.
OpenAuctionHouse()
before = #SEARCHES
ShowTab("sell")
checkTrue("the Sell tab asked for its first item", #SEARCHES > before)
