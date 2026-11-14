-- Schemas: the shape of a raw row from each source, as data.
-- A row is a plain array. Field N of the schema is value N of the row, and a
-- value may be nil, so always use schema.count and never #row.
--
--   id       field name, as the API documentation calls it
--   note     what we believe the field means (shown in the Model view)
--   virtual  not stored. Computed from another field when profiling:
--            { from = <field id>, part = <key of ns.Links.Parse's result> }
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

for id, schema in pairs(ns.Schemas) do
	schema.id = id
	schema.index = {}
	schema.count = 0
	for position, field in ipairs(schema.fields) do
		schema.index[field.id] = position
		if not field.virtual then
			schema.count = position
		end
	end
end
