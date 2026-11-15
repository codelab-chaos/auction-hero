-- The scan shield, as data: the stages a full scan goes through, in order,
-- and how much of the progress bar each one fills. The shield itself is
-- ui\scan-shield.lua; its words are in the locale (L.SHIELD_*).
--
-- A stage is { id, label, from, to }. id is the downloader's phase (see
-- feed\downloader.lua), or "pricing" for the analysis that follows it.
-- from and to are the share of the bar the stage starts and ends at.
local _, ns = ...
local L = ns.L

ns.ScanShield = {
	stages = {
		{ id = "waiting", label = L.SHIELD_STAGE_ASK, from = 0, to = 0.1 },
		{ id = "reading", label = L.SHIELD_STAGE_READ, from = 0.1, to = 0.65 },
		{ id = "resolving", label = L.SHIELD_STAGE_DETAILS, from = 0.65, to = 0.9 },
		{ id = "pricing", label = L.SHIELD_STAGE_PRICE, from = 0.9, to = 1 },
	},
	-- A stage with no count to go by (waiting on the server, pricing) creeps
	-- toward its end, getting halfway in about this many seconds.
	creepHalfSeconds = 6,
	quipSeconds = 4, -- how long each quip stays
	doneSeconds = 2.5, -- how long the result shows before the shield lifts
	coinTurnSeconds = 2, -- one turn of the spinning coin
	coinIcon = ns.Theme.brandIcon, -- the brand coin, see data\theme.lua
	stageIcons = {
		done = "Interface\\RaidFrame\\ReadyCheck-Ready",
		current = "Interface\\RaidFrame\\ReadyCheck-Waiting",
	},
	card = { width = 400, height = 268 },
	dim = 0.86, -- how dark the cover over the tabs is
}
