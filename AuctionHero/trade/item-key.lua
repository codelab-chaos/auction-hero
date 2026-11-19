-- Item keys: finds the key the auction house knows an item by.
--
-- A single item can only be searched for by its full key: item id, and for
-- gear the level and variant that tell "of the Elder" from "of the Owl". A
-- scan gives the id and the name but not that key, and a key made from the id
-- alone finds nothing (seen on Forever: no auctions back for an item the
-- game's own window listed five of).
--
-- So the key is asked for the way the game's window does it: browse for the
-- name, and take the key of the result with this id and this name. Keys are
-- kept for the session.
--
-- It only reads. Nothing is bought here.
local _, ns = ...

local ItemKey = {}
ns.ItemKey = ItemKey

local PAGES = 5 -- pages of browse results to look through

local known = {} -- "itemID:name" -> item key
local asking = {} -- "itemID:name" -> { itemID, name, waiters, pages }, while being asked

-- Looks through the browse results for the item. Returns its key, or nil and
-- whether some results could not be named yet.
local function Find(wanted)
	local unnamed = false
	local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
	for _, result in ipairs(ok and results or {}) do
		local itemKey = result.itemKey
		if itemKey and itemKey.itemID == wanted.itemID then
			local named, info = pcall(C_AuctionHouse.GetItemKeyInfo, itemKey)
			if not named or not info or not info.itemName then
				unnamed = true -- the game is still loading this one
			elseif info.itemName == wanted.name then
				return itemKey
			end
		end
	end
	return nil, unnamed
end

-- What the browse returned, for the log and the player, when the item was not
-- among it: "not found" can then be told from "looked for it the wrong way".
local function Seen()
	local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
	results = ok and results or {}
	local seen = {}
	for index = 1, math.min(#results, 4) do
		local itemKey = results[index].itemKey or {}
		local named, info = pcall(C_AuctionHouse.GetItemKeyInfo, itemKey)
		seen[#seen + 1] = ("%s \"%s\" level %s variant %s"):format(tostring(itemKey.itemID), tostring(named and info and info.itemName), tostring(itemKey.itemLevel), tostring(itemKey.itemSuffix))
	end
	return ("%d results%s"):format(#results, #seen > 0 and (": " .. table.concat(seen, "; ")) or ""), #results
end

-- Reads the browse results once they are quiet. Returns { itemKey } or
-- { problem, found }, "wait" while names load, or "more" for the next page.
local function Read(wanted, request, last)
	local itemKey, unnamed = Find(wanted)
	if itemKey then
		return { itemKey = itemKey }
	end
	if unnamed and not last then
		return "wait" -- ITEM_KEY_ITEM_INFO_RECEIVED brings us back
	end
	local full = select(2, pcall(C_AuctionHouse.HasFullBrowseResults))
	if full == false and wanted.pages < PAGES and not last then
		wanted.pages = wanted.pages + 1
		return request:More(C_AuctionHouse.RequestMoreBrowseResults)
	end
	local found, count = Seen()
	-- No result at all is the auction house saying it has none by that name.
	return { problem = count == 0 and "none" or "gone", found = found }
end

-- Finds the key for an item of this id and name, then calls done(itemKey),
-- or done(nil, problem, found) where problem is "none" (nothing at all is
-- listed by that name), "gone" (results came back, none with this id and
-- name), "unanswered" or "refused", and found says what the browse did
-- return. Asking again for an item already being asked about waits on the
-- same answer.
function ItemKey:Resolve(itemID, name, done)
	local id = itemID .. ":" .. name
	if known[id] then
		return done(known[id])
	end
	if asking[id] then
		table.insert(asking[id].waiters, done)
		return
	end
	local wanted = { itemID = itemID, name = name, waiters = { done }, pages = 1 }
	asking[id] = wanted
	ns.Requests:Ask({
		kind = "browse",
		label = "item key",
		itemID = itemID,
		send = function()
			return C_AuctionHouse.SendBrowseQuery({
				searchString = name,
				sorts = {
					{ sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false },
					{ sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false },
				},
				filters = {},
			})
		end,
		read = function(request, last)
			return Read(wanted, request, last)
		end,
		done = function(outcome, result)
			asking[id] = nil
			local itemKey, problem, found
			if outcome == "answered" and result then
				itemKey, problem, found = result.itemKey, result.problem, result.found
			else
				problem = outcome == "unanswered" and "unanswered" or "refused"
			end
			if itemKey then
				known[id] = itemKey
				ns.EventLog:Note("item key found", itemID, name, itemKey.itemLevel, itemKey.itemSuffix)
			else
				ns.EventLog:Note("item key not found", itemID, name, problem, found)
			end
			for _, waiter in ipairs(wanted.waiters) do
				waiter(itemKey, problem, found)
			end
		end,
	})
end

-- Forgets a key, when a search by it finds nothing the game's window would.
function ItemKey:Forget(itemID, name)
	known[itemID .. ":" .. name] = nil
end
