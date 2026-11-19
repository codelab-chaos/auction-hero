-- Theme: the window's sizes, colors and fonts, as data. These are the values
-- of the ahero-lab concept (lab/src/styles.css), so the in-game window matches
-- the design it was worked out in.
local _, ns = ...

-- "#rrggbb" -> { r, g, b, a }
local function Hex(hex, alpha)
	return {
		tonumber(hex:sub(2, 3), 16) / 255,
		tonumber(hex:sub(4, 5), 16) / 255,
		tonumber(hex:sub(6, 7), 16) / 255,
		alpha or 1,
	}
end

ns.Theme = {
	Hex = Hex,

	-- The size of the game's own auction house window.
	window = { width = 900, height = 600 },
	-- The window opens at the size above and can be dragged between these from
	-- its corner. Width stays at the designed size (the tabs' columns are laid
	-- out for it); height can shrink, since the lists and rails scroll.
	windowMin = { width = 900, height = 420 },
	windowMax = { width = 1500, height = 1000 },
	-- Sizers: the draggable separators between list columns and between panels.
	sizerWidth = 8, -- the drag area
	sizerIdleAlpha = 0.15, -- how visible its line is at rest, and under the mouse
	sizerHoverAlpha = 0.8,
	columnMin = 28, -- how narrow and how wide a list column can be dragged
	columnMax = 420,
	panelGrow = 260, -- how much wider than designed a side panel can be dragged
	footerHeight = 22, -- the status bar under the tabs' body, added to the height
	titleHeight = 30,
	brandIcon = "Interface\\Icons\\INV_Misc_Coin_01", -- before the title, and with coins raining onto it on the scan shield
	brandIconSize = 20,
	titleBadge = 132351, -- after the name: ability_warrior_rallyingcry, the hero's shout (a file ID)
	tabHeight = 27,
	tabWidth = 84,
	tabIconWidth = 40, -- a tab that shows an icon instead of its name
	debugTabIcon = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", -- the Debug tab's skull
	pad = 8, -- padding around a tab's body, and the gap between its columns

	-- Column widths. The middle column of each tab takes what is left.
	buy = { rail = 34, sidebar = 176, order = 250 },
	sell = { bags = 200, competition = 230 },
	resell = { plan = 290 },
	history = { list = 280 },

	rowHeight = 25, -- list rows
	headerHeight = 22, -- list headers
	controlHeight = 24, -- buttons and inputs
	tile = 26, -- rail tiles
	tileLargeScale = 1.25, -- how much bigger they get when the rail is widened
	railFade = 14, -- the fade at an end of the rail with more tiles past it
	railWheelTiles = 2, -- tiles the rail moves per turn of the mouse wheel
	sideTileGap = 4, -- between the square tiles at the top of the category column
	ledgerTile = { width = 118, headline = 150, height = 48, gap = 16 }, -- the totals across the Ledger tab
	swatch = 12, -- rail quality swatches (their height)
	swatchIconOff = 0.45, -- how faded a quality icon is when it is not ticked
	tileIconOffGray = true, -- an item icon tile is in gray until ticked, then in color
	tileIconOff = 0.75, -- and this faded while gray
	bagSlot = 40,

	-- A narrow sans-serif, the closest the client ships to the concept's font.
	-- If it cannot be loaded the game's standard font is used.
	font = "Fonts\\ARIALN.TTF",
	fontSize = { small = 11, normal = 12, large = 14, title = 14, total = 15 },

	color = {
		window = Hex("#120e0a"),
		settings = Hex("#0d1626"), -- the Options panel, set apart from the tabs
		settingsBorder = Hex("#3d6496"),
		settingsRow = Hex("#16243a"), -- a row under the pointer on the Options panel
		panel = Hex("#1c1611"),
		panel2 = Hex("#2a2018"),
		line = Hex("#4a3a26"),
		text = Hex("#f2e8d5"),
		muted = Hex("#a8977a"),
		accent = Hex("#ffd100"),
		border = Hex("#8a6a2f"),
		input = Hex("#0d0a07"),
		inputBorder = Hex("#5c4526"),
		white = Hex("#ffffff"),
		black = Hex("#000000"),
		good = Hex("#40d040"),
		bad = Hex("#ff6060"),
		gold = Hex("#ffd100"),
		rowHover = Hex("#ffd100", 0.07),
		rowSelected = Hex("#ffd100", 0.18),
		you = Hex("#40d040", 0.2),
		dealBadge = Hex("#40d040", 0.18),
		block = Hex("#ffffff", 0.04),
		-- Gradients run top to bottom.
		titleTop = Hex("#3a2a16"),
		titleBottom = Hex("#1f160c"),
		controlTop = Hex("#3a2c1c"),
		controlBottom = Hex("#241a10"),
		controlText = Hex("#e6d5ae"),
		activeTop = Hex("#6b5120"),
		activeBottom = Hex("#3d2e12"),
		activeBorder = Hex("#d9a441"),
		tabTop = Hex("#2e2318"),
		tabBottom = Hex("#1c1510"),
		tabText = Hex("#c9b48a"),
		tabActiveTop = Hex("#5a431c"),
		tabActiveBottom = Hex("#33260f"),
		tabActiveBorder = Hex("#c79a3a"),
		actionTop = Hex("#a32020"),
		actionBottom = Hex("#5c0f0f"),
		actionHoverTop = Hex("#c22a2a"),
		actionHoverBottom = Hex("#751414"),
		actionBorder = Hex("#d9a441"),
		pipOff = Hex("#ffffff", 0.12),
	},

	-- Meter pip colors, by tone.
	tone = {
		bad = Hex("#e0503c"),
		warn = Hex("#e8a030"),
		ok = Hex("#b8cc3c"),
		good = Hex("#40c060"),
	},
}
