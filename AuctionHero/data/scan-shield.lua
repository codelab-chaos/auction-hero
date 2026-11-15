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
	coinIcon = ns.Theme.brandIcon, -- the brand coin, see data\theme.lua
	-- While the scan runs, a light rain of coins sprinkles down the whole card,
	-- behind its text. Each drop starts at the top edge somewhere along it,
	-- falls the card's height in a time between fallSeconds' two values,
	-- sways a little, fades in at the top and out before the bottom, then
	-- starts again somewhere else. Sizes and coins are picked per fall; a coin
	-- listed more often falls more often. Gold only, at full brightness.
	coinRain = {
		count = 12,
		fallSeconds = { 3.2, 5 },
		size = { 8, 13 },
		alpha = 1, -- at its brightest
		glow = true, -- drawn added onto the card, so the gold shines
		fadeIn = 0.12, -- share of the fall spent fading in
		fadeOut = 0.3, -- and fading out
		sway = 5, -- how far a drop drifts left and right
		swaySeconds = 2.4, -- one drift there and back
		margin = 10, -- kept clear at the card's edges
		icons = {
			"Interface\\MoneyFrame\\UI-GoldIcon",
		},
	},
	stageIcons = {
		done = "Interface\\RaidFrame\\ReadyCheck-Ready",
		current = "Interface\\RaidFrame\\ReadyCheck-Waiting",
	},
	-- Reading the last scan after a reload or login: the same card, its first
	-- stages already done, and the bar running the whole width for pricing.
	reading = { stage = "pricing", from = 0, to = 1 },
	card = { width = 400, height = 268 },
	dim = 0.86, -- how dark the cover over the tabs is
}
