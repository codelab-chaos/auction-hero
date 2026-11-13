-- Analyzer: whenever the snapshot changes, runs the profile, derive and market
-- steps as a job and publishes the result as ns.Analysis.
--   ns.Analysis = { profile = <Profile:Run>, derived = <Derive:Run>, market = <Market:Build> }
-- A new scan's market is also folded into the price history.
local _, ns = ...
local Bus = ns.Bus

local generation = 0 -- bumps on every snapshot change, so late results are dropped

Bus:On("SNAPSHOT_CHANGED", function()
	generation = generation + 1
	local mine = generation
	local snapshot = ns.Store:GetSnapshot()
	ns.Analysis = nil
	if not snapshot then
		Bus:Fire("ANALYSIS_READY")
		return
	end

	Bus:Fire("ANALYSIS_STATE", true)
	ns.Jobs:Run(function()
		local full = ns.Store:GetSourceSnapshot("replicate")
		local market = full and ns.Market:Build(full)
		local folded = ns.History:Fold(market)
		return ns.Profile:Run(snapshot), ns.Derive:Run(snapshot), market, folded
	end, function(profile, derived, market, folded)
		if folded then
			Bus:Fire("HISTORY_CHANGED")
		end
		if mine ~= generation then
			return
		end
		ns.Analysis = { profile = profile, derived = derived, market = market }
		Bus:Fire("ANALYSIS_STATE", false)
		Bus:Fire("ANALYSIS_READY")
	end, function(message)
		if mine ~= generation then
			return
		end
		ns.Print("analysis failed: " .. message)
		Bus:Fire("ANALYSIS_STATE", false)
		Bus:Fire("ANALYSIS_READY")
	end)
end)
