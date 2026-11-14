-- Activity: a short list of what the addon last did, for the window's footer.
-- Newest first, kept for the session only.
--
-- An entry: { clock = "21:57", text = "...", tone = "good" | "bad" | nil }
-- Which messages become entries, and how they read, is ns.ActivityRules in
-- data\activity.lua. This file only keeps the list.
local _, ns = ...
local Bus = ns.Bus

local Activity = { entries = {} }
ns.Activity = Activity

function Activity:Add(text, tone)
	table.insert(self.entries, 1, { clock = date("%H:%M"), text = text, tone = tone })
	while #self.entries > ns.ActivityLimit do
		table.remove(self.entries)
	end
	Bus:Fire("ACTIVITY_ADDED")
end

function Activity:Latest()
	return self.entries[1]
end

-- A rule returns the text (and a tone) for a message, or nil to say nothing.
for message, rule in pairs(ns.ActivityRules) do
	Bus:On(message, function(...)
		local text, tone = rule(...)
		if text then
			Activity:Add(text, tone)
		end
	end)
end
