-- The saved data goes out packed when the game is about to write it, and a
-- market kept under no name moves under its name once the game says it.
local realm = "TestRealm"
function GetRealmName() return realm end

-- This character first plays while the game gives no realm name.
realm = ""
local ns = Boot()
OpenAuctionHouse()
Scan()
check("with no name, the market is the faction's alone", ns.Store:GetSourceSnapshot("replicate").meta.place, " / Alliance")
checkTrue("its history is kept there", ns.History:ScanCount() == 1 and AuctionHeroDB.historyByMarket[" / Alliance"] ~= nil)
check("the character has traded under no name", AuctionHeroCharDB.blankRealm, true)

-- The name is known the next time in.
realm = "TestRealm"
FireEvent("PLAYER_LOGIN")
Tick(5)
check("the scan is this market's", ns.Store:GetSourceSnapshot("replicate").meta.place, "TestRealm / Alliance")
check("the history moved under the name", AuctionHeroDB.historyByMarket[" / Alliance"], nil)
check("with its scans", ns.History:ScanCount(), 1)
check("and is not moved twice", AuctionHeroCharDB.blankRealm, nil)

-- Later the game stops saying the name: the one seen before is used.
realm = ""
check("a name once seen is kept", ns.Place:Current(), "TestRealm / Alliance")
SkipTime(3600)
Scan()
check("so a scan does not start a second market", ns.Store:GetSourceSnapshot("replicate").meta.place, "TestRealm / Alliance")
check("nor a second history", AuctionHeroDB.historyByMarket[" / Alliance"], nil)
check("two scans in the one", ns.History:ScanCount(), 2)

-- Logging out: the large tables are packed, and what is written fits.
local rows = #ns.Store:GetSourceSnapshot("replicate").rows
local plain = ns.Saved.Count(AuctionHeroDB)
checkTrue("there are rows to save", rows > 0)
FireEvent("PLAYER_LOGOUT")
local saved = AuctionHeroDB.snapshots.replicate
checkTrue("rows are saved packed", ns.Pack.IsPacked(saved.rows))
check("the save is marked on the account", AuctionHeroDB.savedStamp, 1)
check("and on the character", AuctionHeroCharDB.savedStamp, 1)
checkTrue("so are the variants", ns.Pack.IsPacked(saved.variants))
checkTrue("and the price history", ns.Pack.IsPacked(AuctionHeroDB.historyByMarket["TestRealm / Alliance"].items))
check("the scan's details are saved as they are", saved.meta.place, "TestRealm / Alliance")
checkTrue("what is written is counted", AuctionHeroDB.savedCount ~= nil and AuctionHeroDB.savedCount < plain)
checkTrue("and fits", AuctionHeroDB.savedCount < ns.SavedRule.limit * ns.SavedRule.share)
check("nothing had to be dropped", AuctionHeroDB.savedDropped, nil)
check("nothing went wrong packing", AuctionHeroDB.savedProblem, nil)

-- Back in: everything is as it was.
check("it all unpacks", #ns.Saved.Open(AuctionHeroDB, ns.SavedRule.packed), 0)
check("every row is back", #AuctionHeroDB.snapshots.replicate.rows, rows)
