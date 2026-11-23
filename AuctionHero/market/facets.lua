-- Facets: turns the category data (data\facets.lua) into checkbox groups for
-- a market, and applies whatever is ticked. The lab's lab/src/model/facets.ts
-- carried over.
--
-- A selection is a table: key -> { [value] = true }. A facet's boxes are kept
-- under its id, and its refine toggles under its id .. "/refine".
local _, ns = ...
local L = ns.L

local Facets = {}
ns.Facets = Facets

local function Contains(list, value)
	if not list then
		return false
	end
	for _, entry in ipairs(list) do
		if entry == value then
			return true
		end
	end
	return false
end

local function FitsBox(box, item)
	if box.subClassIDs and not Contains(box.subClassIDs, item.subClassID) then
		return false
	end
	if box.slots and not Contains(box.slots, item.equipLoc) then
		return false
	end
	return true
end

-- Which box of a category an item belongs in: value, label, order, inRail.
-- Nil when the item is not in the category at all.
local function BoxOf(category, item)
	if not item.classID or not Contains(category.classIDs, item.classID) then
		return nil
	end
	if category.slots and not Contains(category.slots, item.equipLoc) then
		return nil
	end
	if category.notSlots and Contains(category.notSlots, item.equipLoc) then
		return nil
	end
	local boxes = category.boxes or {}
	for position, box in ipairs(boxes) do
		if FitsBox(box, item) then
			return category.id .. ":" .. box.label, box.label, position, box.inRail
		end
	end
	local subType = item.subType and item.subType ~= "" and item.subType or L.CAT_OTHER
	return item.classID .. ":" .. (item.subClassID or 0), subType, #boxes + 1, nil
end

local function RefineValue(refine, item)
	for _, option in ipairs(refine.options) do
		if Contains(option.slots, item.equipLoc) then
			return option.label
		end
	end
end

function Facets.RefineKey(facetId)
	return facetId .. "/refine"
end

-- Builds the facets for a market's items. Each facet:
--   id, label, dimension, flat, refine
--   read(item)         the item's box value in this facet, or nil
--   options            { value, label, icon, inRail }, pictured by each box's
--                      most-listed item
--   refineRead(item)   the item's refine value, or nil
--   refineOptions      { value, label, icon }
-- Runs as fast as it can outside a job; inside one it shares frames.
function Facets:Build(items)
	local facets = {}
	for _, category in ipairs(ns.ItemCategories) do
		local groups, order = {}, {}
		local pictures = {} -- refine value -> { item, preferred }
		for count, item in ipairs(items) do
			if count % 200 == 0 then
				ns.Breathe() -- inside a job, a few frames' work instead of one
			end
			local value, label, position, inRail = BoxOf(category, item)
			if value then
				local preferred = Contains(category.iconSlots, item.equipLoc)
				local group = groups[value]
				if not group then
					group = { value = value, label = label, order = position, inRail = inRail, count = 0, best = item, preferred = preferred }
					groups[value] = group
					order[#order + 1] = group
				end
				group.count = group.count + 1
				local better
				if preferred == group.preferred then
					better = item.listings > group.best.listings
				else
					better = preferred
				end
				if better and item.icon then
					group.best, group.preferred = item, preferred
				end

				if category.refine then
					local refined = RefineValue(category.refine, item)
					if refined and item.icon then
						local wanted
						for _, option in ipairs(category.refine.options) do
							if option.label == refined then
								wanted = option.pictureSubClass == nil or option.pictureSubClass == item.subClassID
							end
						end
						local picture = pictures[refined]
						if not picture or (wanted and not picture.preferred) or (wanted == picture.preferred and item.listings > picture.item.listings) then
							pictures[refined] = { item = item, preferred = wanted }
						end
					end
				end
			end
		end

		table.sort(order, function(a, b)
			if category.keepOrder and a.order ~= b.order then
				return a.order < b.order
			end
			return a.label < b.label -- alphabetical
		end)

		local options = {}
		for _, group in ipairs(order) do
			options[#options + 1] = { value = group.value, label = group.label, icon = group.best.icon, inRail = group.inRail }
		end

		local facet = {
			id = category.id,
			label = category.label,
			dimension = "type",
			flat = category.flat,
			options = options,
			read = function(item)
				return (BoxOf(category, item))
			end,
		}
		if category.refine then
			local refine = category.refine
			facet.refine = refine
			facet.refineRead = function(item)
				return RefineValue(refine, item)
			end
			facet.refineOptions = {}
			for _, option in ipairs(refine.options) do
				local picture = pictures[option.label]
				facet.refineOptions[#facet.refineOptions + 1] = { value = option.label, label = option.label, icon = picture and picture.item.icon }
			end
		end
		facets[#facets + 1] = facet
	end

	-- Quality: one box per quality, drawn as color swatches (see ns.BuySidebarTop and ns.BuyRail).
	local quality = {
		id = ns.QualityFacet.id,
		label = ns.QualityFacet.label,
		dimension = ns.QualityFacet.id,
		rail = true,
		options = {},
		read = function(item)
			return item.quality
		end,
	}
	for _, id in ipairs(ns.QualityFacet.qualities) do
		quality.options[#quality.options + 1] = { value = id, label = _G["ITEM_QUALITY" .. id .. "_DESC"] or tostring(id), quality = id }
	end
	facets[#facets + 1] = quality
	return facets
end

local function Any(set)
	return set ~= nil and next(set) ~= nil
end

function Facets.Toggle(selection, key, value, on)
	local set = selection[key]
	if not set then
		set = {}
		selection[key] = set
	end
	set[value] = on and true or nil
end

function Facets.AnySelected(selection)
	for _, set in pairs(selection) do
		if next(set) ~= nil then
			return true
		end
	end
	return false
end

-- True when the item passes everything ticked.
-- An item must satisfy every dimension in play, and satisfies one by matching
-- any facet in it. A facet whose refine toggles are on is in play even with no
-- boxes ticked: it then means the whole group.
function Facets:Filter(facets)
	return function(selection)
		local dimensions, order = {}, {}
		for _, facet in ipairs(facets) do
			local refining = facet.refine and Any(selection[Facets.RefineKey(facet.id)])
			if Any(selection[facet.id]) or refining then
				local list = dimensions[facet.dimension]
				if not list then
					list = {}
					dimensions[facet.dimension] = list
					order[#order + 1] = list
				end
				list[#list + 1] = facet
			end
		end
		if #order == 0 then
			return nil -- nothing ticked: everything passes
		end

		local function Matches(facet, item)
			local value = facet.read(item)
			if value == nil then
				return false
			end
			local boxes = selection[facet.id]
			local anyBoxes = Any(boxes)
			if anyBoxes and not boxes[value] then
				return false
			end
			local toggles = facet.refine and selection[Facets.RefineKey(facet.id)]
			if Any(toggles) then
				local refined = facet.refineRead(item)
				-- The toggles have nothing to say about this item (a bow is not
				-- held in one hand or two). Keep it only when its box was ticked.
				if refined == nil then
					return anyBoxes
				end
				return toggles[refined] == true
			end
			return true
		end

		return function(item)
			for _, group in ipairs(order) do
				local passed = false
				for _, facet in ipairs(group) do
					if Matches(facet, item) then
						passed = true
						break
					end
				end
				if not passed then
					return false
				end
			end
			return true
		end
	end
end
