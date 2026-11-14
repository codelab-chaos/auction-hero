-- Buying a single item: a live search for the cheapest auction of this exact
-- item, then a second press that buys that one auction.
local ns = Boot()
OpenAuctionHouse()
Scan()
MONEY = 100000
local tunic = { key = "2006:Tunic of the Bear", itemID = 2006, name = "Tunic of the Bear", single = true }
local function phase()
	return ns.Buying.state.phase
end

-- The live auctions hold two variants. Only the named one may be bought.
MOCK.liveNames = { "Tunic of the Owl", "Tunic of the Bear" }
ns.Buying:Start(tunic)
check("the first press starts looking", phase(), "quoting")
check("first for the item's key, by its name, as the game's own window does", BROWSED[#BROWSED], "Tunic of the Bear")
check("nothing is bought by looking", #BUYS, 0)
Tick(8)
check("then for its auctions, by that full key", SEARCHES[#SEARCHES], "search sorts=2 2006 level=12")
check("the cheapest auction of this exact item is offered", phase(), "confirm")
check("the Bear, not the cheaper Owl", ns.Buying.state.auctionID, 702)
check("at its live price", ns.Buying.state.total, 200)
ns.Buying:Confirm()
check("the second press buys that one auction at that price", BUYS[#BUYS], "bid 702 200")
Tick(10)
check("bought", phase(), "done")
local entries = ns.Ledger:Entries()
check("and written in the ledger once", #entries, 1)
check("under the item's own name", entries[1].name, "Tunic of the Bear")
check("for what was paid", entries[1].amount, 200)

-- Nothing is spent without the second press.
ns.Buying:Start(tunic)
Tick(10)
ns.Buying:Cancel()
check("backing out returns to idle", phase(), "idle")
ns.Buying:Confirm()
check("and nothing more was bought", #BUYS, 1)

-- The item is not among the live auctions any more.
MOCK.liveNames = { "Tunic of the Owl", "Tunic of the Whale" }
ns.Buying:Start(tunic)
Tick(10)
check("an item that is gone fails without spending", phase(), "failed")
checkMatch("and says what it found instead", ns.Buying.state.message, "listed 2 auctions for this item, but none is named \"Tunic of the Bear\"%. The first is \"Tunic of the Owl\"")

-- Auctions whose names cannot be read are never guessed at.
MOCK.liveNames = nil
ns.Buying:Start(tunic)
Tick(10)
check("unreadable auctions are not bought blind", phase(), "failed")
checkMatch("with the reason", ns.Buying.state.message, "Could not tell which auction")

-- The player's own auction is skipped.
MOCK.liveNames = { "Tunic of the Bear", "Tunic of the Bear" }
MOCK.liveMine = true
ns.Buying:Start(tunic)
Tick(10)
check("your own auction is passed over", ns.Buying.state.auctionID, 702)
ns.Buying:Cancel()
MOCK.liveMine = false

-- A price above the player's gold is never sent.
MOCK.livePrice = 999999
ns.Buying:Start(tunic)
Tick(10)
ns.Buying:Confirm()
check("price over gold", phase(), "failed")
check("no bid was sent", #BUYS, 1)
MOCK.livePrice = nil

-- The game never says the purchase went through, but the gold left.
MOCK.bidFails, MOCK.bidTakesGold = true, true
ns.Buying:Start(tunic)
Tick(10)
ns.Buying:Confirm()
Tick(320)
check("gold gone means bought, whatever was said", phase(), "done")
check("and it is in the ledger", #ns.Ledger:Entries(), 2)

-- No word and no gold gone: it does not claim either way.
MOCK.bidTakesGold = false
ns.Buying:Start(tunic)
Tick(10)
ns.Buying:Confirm()
Tick(320)
check("no answer and no gold gone is a failure", phase(), "failed")
checkMatch("that tells the player to check", ns.Buying.state.message, "Check your gold and your mail")
check("and writes nothing in the ledger", #ns.Ledger:Entries(), 2)
MOCK.bidFails = false

-- The auction house lists none under that name at all.
MOCK.liveNames = { "Tunic of the Bear", "Tunic of the Bear" }
MOCK.browseGone = true
ns.Buying:Start({ key = "2006:Tunic of the Whale", itemID = 2006, name = "Tunic of the Whale", single = true })
Tick(10)
check("an item the auction house does not list fails without spending", phase(), "failed")
checkMatch("and says what the lookup found", ns.Buying.state.message, "Could not find this item at the auction house%. Looked up by name: 0 results")
MOCK.browseGone = false

-- The game reports a problem while buying. It is not called a failure until
-- the gold has had a moment to move, and the message states the gold, not a guess.
MOCK.bidFails = true
MOCK.liveNames = { "Tunic of the Bear", "Tunic of the Bear" }
ns.Buying:Start(tunic)
Tick(10)
ns.Buying:Confirm()
FireEvent("AUCTION_HOUSE_SHOW_ERROR", 7)
check("an error is not an answer yet", phase(), "buying")
Tick(80)
check("with the gold unchanged, it did not go through", phase(), "failed")
checkMatch("and says so with the gold before and now", ns.Buying.state.message, "problem %(code 7%)%. Your gold was .* before and is .* now")

-- The same error, but the gold did leave: it was bought.
MOCK.bidTakesGold = true
ns.Buying:Start(tunic)
Tick(10)
ns.Buying:Confirm()
FireEvent("AUCTION_HOUSE_SHOW_ERROR", 7)
Tick(80)
check("an error with the gold gone is still a purchase", phase(), "done")
MOCK.bidFails, MOCK.bidTakesGold = false, false
