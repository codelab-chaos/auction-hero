-- Posting from the Sell tab: what is sent to the game, and what is refused.
local ns = Boot()
OpenAuctionHouse()
Scan()
local leather, tunic = "2003:Light Leather", "2006:Tunic of the Bear"
local function phase()
	return ns.Posting.state.phase
end
local function sent()
	local last = POSTS[#POSTS]
	return last and table.concat(last, " ") or "nothing"
end
local function ask(key)
	ns.SellSearch:Request(key)
	Tick(3)
end

-- A post waits for the item's live listings to have been asked for.
ns.Posting:Post({ key = tunic, commodity = false, duration = 3, quantity = 1, unit = 500, buyout = true })
check("no post before the sell search", phase(), "failed")
check("nothing reached the game", #POSTS, 0)
Tick(3)

-- Goods sold by the unit: one listing of a quantity at a unit price.
ask(leather)
check("leather is sold by the unit", ns.Posting:IsCommodity(leather), true)
ns.Posting:Post({ key = leather, commodity = true, duration = 3, quantity = 53, unit = 299, buyout = true })
check("sent as a commodity post", sent(), "commodity 2003 3 53 299")
Tick(5)
check("the game's answer finishes it", phase(), "done")

-- A single item: buyout only, with bids, and bids only.
ask(tunic)
check("a tunic is a single item", ns.Posting:IsCommodity(tunic), false)
ns.Posting:Post({ key = tunic, commodity = false, duration = 3, quantity = 1, unit = 244, buyout = true })
check("buyout only", sent(), "item 2006 3 1 nil 244")
Tick(5)
ns.Posting:Post({ key = tunic, commodity = false, duration = 2, quantity = 1, unit = 244, bid = 195, buyout = true })
check("buyout with a starting bid", sent(), "item 2006 2 1 195 244")
Tick(5)
ns.Posting:Post({ key = tunic, commodity = false, duration = 1, quantity = 1, unit = 244, buyout = false })
check("bids only", sent(), "item 2006 1 1 244 nil")
Tick(5)

-- The server never answers a single item posted under 1 silver, and the
-- auction house hangs. Such a post must never be sent.
local before = #POSTS
check("the floor is 1 silver", ns.MinItemPrice, 100)
ns.Posting:Post({ key = tunic, commodity = false, duration = 3, quantity = 1, unit = 99, buyout = true })
check("a price under the floor is refused", phase(), "failed")
check("and never reaches the game", #POSTS, before)
ask(leather)
ns.Posting:Post({ key = leather, commodity = true, duration = 3, quantity = 5, unit = 3, buyout = true })
check("goods sold by the unit have no floor", #POSTS, before + 1)
Tick(5)

-- Posting the wrong kind is refused: the game's own form never does it.
before = #POSTS
ns.Posting:Post({ key = leather, commodity = false, duration = 3, quantity = 1, unit = 500, buyout = true })
check("a commodity posted as an item is refused", phase(), "failed")
check("the wrong kind never reaches the game", #POSTS, before)

-- The deposit has to be covered.
ask(tunic)
MONEY = 1
ns.Posting:Post({ key = tunic, commodity = false, duration = 3, quantity = 1, unit = 500, buyout = true })
check("no gold for the deposit", phase(), "failed")
check("that never reaches the game either", #POSTS, before)
MONEY = 50000

-- The game asks for a second press when a price looks like a mistake.
ask(leather)
MOCK.needsConfirm = true
ns.Posting:Post({ key = leather, commodity = true, duration = 3, quantity = 53, unit = 121, buyout = true })
check("waits for the second press", phase(), "confirm")
ns.Posting:Cancel()
check("backing out returns to idle", phase(), "idle")
ns.Posting:Post({ key = leather, commodity = true, duration = 3, quantity = 53, unit = 121, buyout = true })
ns.Posting:Confirm()
check("the second press confirms", sent(), "confirm 2003 3 53 121")
Tick(5)
check("and it finishes", phase(), "done")

-- A confirm the game never answers is settled by the bags, as a first press
-- is, instead of waiting for ever.
local realConfirm = C_AuctionHouse.ConfirmPostCommodity
C_AuctionHouse.ConfirmPostCommodity = function() end
ns.Posting:Post({ key = leather, commodity = true, duration = 3, quantity = 53, unit = 121, buyout = true })
ns.Posting:Confirm()
check("a silent confirm waits", phase(), "posting")
Tick(200)
check("then gives up, the item still in the bags", phase(), "failed")
C_AuctionHouse.ConfirmPostCommodity = realConfirm
MOCK.needsConfirm = false

-- The game refuses.
MOCK.postError = true
ns.Posting:Post({ key = leather, commodity = true, duration = 3, quantity = 5, unit = 121, buyout = true })
Tick(5)
check("a refusal is reported", phase(), "failed")
MOCK.postError = false

-- The game stays silent and the item is still in the bags: not posted.
ask(tunic)
local realPost = C_AuctionHouse.PostItem
C_AuctionHouse.PostItem = function()
	return false
end
ns.Posting:Post({ key = tunic, commodity = false, duration = 3, quantity = 1, unit = 500, buyout = true })
check("waiting on a silent game", phase(), "posting")
Tick(200)
check("silence with the item still in the bags is a failure", phase(), "failed")

-- Silent, but the item left the bags: that is a post.
ns.Posting:Post({ key = tunic, commodity = false, duration = 3, quantity = 1, unit = 500, buyout = true })
local realInfo = C_Container.GetContainerItemInfo
C_Container.GetContainerItemInfo = function(bag, slot)
	local info = realInfo(bag, slot)
	if info and info.itemID == 2006 then
		return nil
	end
	return info
end
FireEvent("BAG_UPDATE_DELAYED")
Tick(3)
check("the item leaving the bags settles it", phase(), "done")
C_Container.GetContainerItemInfo = realInfo
FireEvent("BAG_UPDATE_DELAYED")
Tick(3)
C_AuctionHouse.PostItem = realPost

-- Nothing can be posted with the auction house closed.
FireEvent("AUCTION_HOUSE_CLOSED")
ns.Posting:Post({ key = tunic, commodity = false, duration = 3, quantity = 1, unit = 500, buyout = true })
check("closed auction house", phase(), "failed")
