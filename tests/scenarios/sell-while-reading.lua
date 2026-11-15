-- Right after logging in or a reload, the last scan is still being read into a
-- market. Until it is, the Sell tab says so, not that nobody is selling, and
-- the window's status line says the scan is being read.
local ns = Boot()
OpenAuctionHouse()
Scan()
ShowTab("sell")

local function has(text)
	return #Frames(function(frame)
		return type(frame.text) == "string" and strip(frame.text) == text
	end) > 0
end

local market, status = ns.Analysis, ns.AnalysisStatus
ns.Analysis, ns.AnalysisStatus = nil, { phase = "loading" }
NS.Bus:Fire("ANALYSIS_STATE", false)
ns.Window:RefreshActive()
checkTrue("the competition says the scan is being read", has(ns.L.WIN_ANALYZING))
checkTrue("not that nobody is selling", not has(ns.L.SELL_NOT_LISTED))

ns.Analysis, ns.AnalysisStatus = market, status
NS.Bus:Fire("ANALYSIS_STATE", false)
NS.Bus:Fire("ANALYSIS_READY")
-- Once read, the competition is the market's again.
checkTrue("the competition is back", #Frames(function(frame)
	local text = type(frame.text) == "string" and strip(frame.text) or ""
	return text == ns.L.SELL_CHEAPEST or text:find("units sell before yours%.$") ~= nil
end) > 0)
