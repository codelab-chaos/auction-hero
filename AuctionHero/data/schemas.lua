-- Schemas: the shape of a row from each source, as data.
-- A row is a plain array. Field N of the schema is value N of the row, and a
-- value may be nil, so always use schema.count and never #row.
--
--   id       field name, as the API documentation calls it
--   note     what we believe the field means (shown in the Model view)
--   virtual  not stored. Computed from another field when profiling:
--            { from = <field id>, part = <key of ns.Links.Parse's result> }
--   variant  not stored in the row. The value sits at this place in the
--            snapshot's variants entry the row points to (see "listings")
--
-- Read a field with ns.RowReader, which knows where each kind of field is.
local _, ns = ...

ns.Schemas = {
	-- C_AuctionHouse.GetReplicateItemInfo(index), then two extra lookups.
	replicate = {
		native = 18, -- values GetReplicateItemInfo is documented to return
		fields = {
			{ id = "name", note = "Item name. Nil until the item data has loaded." },
			{ id = "texture", note = "Icon file id." },
			{ id = "count", note = "Units in this auction." },
			{ id = "qualityID", note = "Item quality, 0 poor to 5 legendary." },
			{ id = "usable", note = "Whether this character can use the item." },
			{ id = "level", note = "A level. levelType says which kind." },
			{ id = "levelType", note = "What 'level' means for this row." },
			{ id = "minBid", note = "Starting bid, in copper." },
			{ id = "minIncrement", note = "Smallest raise over the current bid." },
			{ id = "buyoutPrice", note = "Buyout in copper for the whole stack. 0 means bid only, which is rare." },
			{ id = "bidAmount", note = "Current highest bid, 0 when nobody has bid." },
			{ id = "highBidder", note = "Name of the highest bidder." },
			{ id = "bidderFullName", note = "Bidder with realm." },
			{ id = "owner", note = "Seller name. Never filled by a full scan." },
			{ id = "ownerFullName", note = "Seller with realm." },
			{ id = "saleStatus", note = "0 while active. 1 means sold." },
			{ id = "itemID", note = "Item id." },
			{ id = "hasAllInfo", note = "False while the client is still loading the item." },
			{ id = "link", note = "From GetReplicateItemLink. Carries suffix, enchants and bonuses." },
			{ id = "timeLeft", note = "From GetReplicateItemTimeLeft. A time band, not seconds." },
			{ id = "link.type", note = "Link kind, such as item or battlepet.", virtual = { from = "link", part = "type" } },
			{ id = "link.suffix", note = "Random suffix id inside the link. Empty on Forever, variants use bonus ids.", virtual = { from = "link", part = "suffix" } },
			{ id = "link.enchant", note = "Enchant id inside the link.", virtual = { from = "link", part = "enchant" } },
			{ id = "link.parts", note = "How many ':' separated values the link holds.", virtual = { from = "link", part = "parts" } },
		},
	},

	-- How a full scan is kept. The game hands back one "replicate" row per
	-- auction, and most of each row repeats: more than half of all auctions are
	-- exact copies of another, and everything about the item is said again on
	-- every one of its auctions. So a scan is kept as two lists:
	--   snapshot.variants  one entry per distinct item as listed (id, name,
	--                      link and the rest), each a plain array
	--   snapshot.rows      one row per distinct listing of a variant, with how
	--                      many identical auctions it stands for
	-- Left out: the seller and bidder names a full scan never fills, the sale
	-- status that is always the same, and the bid increment nothing reads.
	listings = {
		native = 18, -- what the scan it was made from should have returned
		fields = {
			{ id = "variant", note = "Which entry of the snapshot's variants this is a listing of." },
			{ id = "count", note = "Units in each of these auctions." },
			{ id = "minBid", note = "Starting bid, in copper." },
			{ id = "buyoutPrice", note = "Buyout in copper for the whole stack. 0 means bid only, which is rare." },
			{ id = "bidAmount", note = "Current highest bid, 0 when nobody has bid." },
			{ id = "timeLeft", note = "A time band, not seconds." },
			{ id = "copies", note = "How many identical auctions this row stands for." },
			{ id = "name", variant = 1, note = "Item name. Nil when the item data never loaded." },
			{ id = "texture", variant = 2, note = "Icon file id." },
			{ id = "qualityID", variant = 3, note = "Item quality, 0 poor to 5 legendary." },
			{ id = "usable", variant = 4, note = "Whether this character can use the item." },
			{ id = "level", variant = 5, note = "A level. levelType says which kind." },
			{ id = "levelType", variant = 6, note = "What 'level' means for this row." },
			{ id = "itemID", variant = 7, note = "Item id." },
			{ id = "link", variant = 8, note = "Carries suffix, enchants and bonuses." },
			{ id = "link.type", note = "Link kind, such as item or battlepet.", virtual = { from = "link", part = "type" } },
			{ id = "link.suffix", note = "Random suffix id inside the link. Empty on Forever, variants use bonus ids.", virtual = { from = "link", part = "suffix" } },
			{ id = "link.enchant", note = "Enchant id inside the link.", virtual = { from = "link", part = "enchant" } },
			{ id = "link.parts", note = "How many ':' separated values the link holds.", virtual = { from = "link", part = "parts" } },
		},
	},

	-- C_AuctionHouse.GetBrowseResults(), flattened, plus GetItemKeyInfo.
	browse = {
		fields = {
			{ id = "itemID", note = "itemKey.itemID" },
			{ id = "itemLevel", note = "itemKey.itemLevel. 0 when the level is not part of the key." },
			{ id = "itemSuffix", note = "itemKey.itemSuffix. Random suffix id." },
			{ id = "battlePetSpeciesID", note = "itemKey.battlePetSpeciesID" },
			{ id = "totalQuantity", note = "Units for sale across all auctions of this key." },
			{ id = "minPrice", note = "Lowest price in copper. Believed to be per unit." },
			{ id = "containsOwnerItem", note = "True when one of the auctions is yours." },
			{ id = "appearanceLink", note = "Transmog link, when there is one." },
			{ id = "name", note = "From GetItemKeyInfo. Nil until the item data has loaded." },
			{ id = "quality", note = "From GetItemKeyInfo." },
			{ id = "iconFileID", note = "From GetItemKeyInfo." },
			{ id = "isCommodity", note = "From GetItemKeyInfo. Commodities are bought by quantity." },
			{ id = "isEquipment", note = "From GetItemKeyInfo." },
			{ id = "isPet", note = "From GetItemKeyInfo." },
			{ id = "requiredLevel", note = "From GetItemKeyRequiredLevel. Forever shows this instead of item level." },
		},
	},
}

-- schema.index     field id -> its place in schema.fields
-- schema.count     how many values a row holds
-- schema.variants  how many values a variants entry holds, 0 when none
for id, schema in pairs(ns.Schemas) do
	schema.id = id
	schema.index = {}
	schema.count = 0
	schema.variants = 0
	for position, field in ipairs(schema.fields) do
		schema.index[field.id] = position
		if field.variant then
			schema.variants = math.max(schema.variants, field.variant)
		elseif not field.virtual then
			schema.count = position
		end
	end
end

-- Returns a function that reads one field of one of a snapshot's rows,
-- wherever that field is kept: get(row, fieldId). A field the snapshot's
-- schema does not have reads as nil.
function ns.RowReader(snapshot)
	local schema = ns.Schemas[snapshot.meta.schema]
	local fields, index = schema.fields, schema.index
	local variants, variantAt = snapshot.variants, index.variant
	local function get(row, fieldId)
		local position = index[fieldId]
		local field = position and fields[position]
		if not field then
			return nil
		end
		if field.variant then
			local entry = variants and variants[row[variantAt]]
			return entry and entry[field.variant]
		end
		if field.virtual then
			return ns.Links.Parse(get(row, field.virtual.from))[field.virtual.part]
		end
		return row[position]
	end
	return get
end

-- How many auctions a snapshot's rows stand for. A row is one auction unless
-- its schema counts copies.
function ns.AuctionCount(snapshot)
	local at = ns.Schemas[snapshot.meta.schema].index.copies
	if not at then
		return #snapshot.rows
	end
	local total = 0
	for _, row in ipairs(snapshot.rows) do
		total = total + (row[at] or 1)
	end
	return total
end

-- Each snapshot's variants by what they hold, for finding one again. Built
-- when first needed and never saved.
local variantLookups = setmetatable({}, { __mode = "k" })

local function VariantKey(entry, length)
	local parts = {}
	for place = 1, length do
		parts[place] = tostring(entry[place])
	end
	return table.concat(parts, "\031")
end

-- A new row for a snapshot: a copy of one of its rows with some fields set
-- to other values. It stands for one auction. When the values make it an item
-- the snapshot has no variants entry for, one is added.
function ns.MakeRow(snapshot, template, details)
	local schema = ns.Schemas[snapshot.meta.schema]
	local fields, index = schema.fields, schema.index
	local row = {}
	for position = 1, schema.count do
		row[position] = template[position]
	end
	local changed
	for fieldId, value in pairs(details) do
		local position = index[fieldId]
		local field = position and fields[position]
		if field and field.variant then
			changed = changed or {}
			changed[field.variant] = value
		elseif field and not field.virtual then
			row[position] = value
		end
	end
	if index.copies then
		row[index.copies] = 1
	end
	if changed and snapshot.variants then
		local variants, length = snapshot.variants, schema.variants
		local entry = {}
		local base = variants[row[index.variant]] or {}
		for place = 1, length do
			entry[place] = base[place]
		end
		for place, value in pairs(changed) do
			entry[place] = value
		end
		local lookup = variantLookups[variants]
		if not lookup then
			lookup = {}
			for at, known in ipairs(variants) do
				lookup[VariantKey(known, length)] = at
			end
			variantLookups[variants] = lookup
		end
		local key = VariantKey(entry, length)
		local at = lookup[key]
		if not at then
			at = #variants + 1
			variants[at] = entry
			lookup[key] = at
		end
		row[index.variant] = at
	end
	return row
end
