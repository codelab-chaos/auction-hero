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
	-- While the scan runs, gold coins rain down the whole card, behind its text.
	-- Each drop starts at the top edge somewhere along it and falls the
	-- card's height under gravity (slow at first, faster and faster: depth
	-- grows with the square of time, to the power gravity), in a time between
	-- fallSeconds' two values. It sways a little, is bright almost at once and
	-- fades only near the bottom, then starts again somewhere else. A drop is
	-- the coin plus an added copy of it on top (shine), so it gleams.
	coinRain = {
		count = 12,
		fallSeconds = { 1.6, 2.6 },
		gravity = 2, -- 1 falls at a steady speed, 2 like a dropped coin
		size = { 12, 18 },
		alpha = 1, -- at its brightest
		shine = 0.6, -- how strong the added copy on top is, 0 for none
		fadeIn = 0.03, -- share of the fall spent fading in
		fadeOut = 0.15, -- and fading out
		sway = 2, -- how far a drop drifts left and right
		swaySeconds = 2.4, -- one drift there and back
		margin = 10, -- kept clear at the card's edges and its foot
		-- Coins spill out of the progress bar's filled part, mostly near its
		-- leading edge, and fall from there to the card's foot.
		spill = 60, -- how far behind the leading edge a coin can come from
		toss = { -18, 28 }, -- how far sideways a coin travels over its fall
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
	card = { width = 440, height = 480 },
	-- Below the progress: the progress panel (ns.RewardsLook, data\rewards.lua).
	dim = 0.86, -- how dark the cover over the tabs is
}
