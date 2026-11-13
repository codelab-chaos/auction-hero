-- Direct translation of lab/src/model/{facets,filters,orders,resell,signals}.ts.
-- Configuration is exported from the lab, rather than maintained separately.
local _, ns = ...
local C = ns.Concept
local M = {}
ns.ConceptModel = M
local function Has(list,value) for _,v in ipairs(list or {}) do if v==value then return true end end; return false end
local function Any(set) return set and next(set)~=nil end
M.Has = Has
function M:Usual(item) return item.usual or ns.History:Usual(item) end
function M:Commodity(item)
	if item.commodity~=nil then return item.commodity end
	return Has(C.commodityClasses,item.classId or item.classID)
end
function M:Box(category,item)
	local class,sub=item.classId or item.classID,item.subClassId or item.subClassID or 0
	if not Has(category.classIds,class) or (category.slots and not Has(category.slots,item.equipLoc))
		or (category.notSlots and Has(category.notSlots,item.equipLoc)) then return end
	for index,box in ipairs(category.boxes or {}) do
		if (not box.subClassIds or Has(box.subClassIds,sub)) and (not box.slots or Has(box.slots,item.equipLoc)) then
			return {value=category.id..":"..box.label,label=box.label,order=index-1,inRail=box.inRail}
		end
	end
	return {value=class..":"..sub,label=item.subType or "Other",order=#(category.boxes or {})}
end
function M:Options(category,items)
	local groups,order={},{}
	for _,item in ipairs(items) do
		if item.name and item.units>0 then
			local box=self:Box(category,item)
			if box then
				local preferred=Has(category.iconSlots,item.equipLoc)
				local group=groups[box.value]
				if not group then
					group={value=box.value,label=box.label,order=box.order,inRail=box.inRail,count=1,best=item,preferred=preferred,index=#order+1}
					groups[box.value]=group; order[#order+1]=group
				else
					group.count=group.count+1
					local better=preferred==group.preferred and item.listings>group.best.listings or preferred and not group.preferred
					if better and item.icon then group.best,group.preferred=item,preferred end
				end
			end
		end
	end
	table.sort(order,function(a,b)
		if category.keepOrder and a.order~=b.order then return a.order<b.order end
		if a.count~=b.count then return a.count>b.count end
		return a.index<b.index -- JavaScript's Array.sort preserves insertion order on ties.
	end)
	for _,group in ipairs(order) do group.icon=group.best.icon end
	return order
end
function M:Matches(item,selection)
	local quality=selection.quality
	if Any(quality) and not quality[tostring(item.quality)] then return false end
	local active,matched=false,false
	for _,category in ipairs(C.categories) do
		local boxes,refined=selection[category.id] or {},selection[category.id.."/refine"] or {}
		if Any(boxes) or Any(refined) then
			active=true
			local box=self:Box(category,item)
			if box and (not Any(boxes) or boxes[box.value]) then
				local value=category.refine and category.refine.slotValues[item.equipLoc]
				if not Any(refined) or (value and refined[value]) or (not value and Any(boxes)) then matched=true end
			end
		end
	end
	return not active or matched
end
function M:Filter(item,filter,budget)
	if not item.name or item.units<=0 then return false end
	local text=(filter.text or ""):match("^%s*(.-)%s*$"):lower()
	if text~="" and not item.name:lower():find(text,1,true) then return false end
	if filter.usableOnly and not item.usable then return false end
	if filter.affordableOnly then
		local cheapest=math.huge
		for _,tier in ipairs(item.tiers) do cheapest=math.min(cheapest,tier.buyout) end
		if cheapest>budget then return false end
	end
	if filter.dealsOnly and (item.deal or -1)<30 then return false end
	return true
end
function M:Order(item,wanted)
	local byUnit=self:Commodity(item)
	local order={byUnit=byUnit,units=0,cost=0,auctions=0,lines={}}
	for _,tier in ipairs(item.tiers) do
		local left=wanted-order.units
		if left<=0 then break end
		local auctions=byUnit and 0 or math.min(tier.copies,math.ceil(left/tier.stack))
		local units=byUnit and math.min(tier.units,left) or auctions*tier.stack
		order.units=order.units+units; order.cost=order.cost+(byUnit and units*tier.unit or auctions*tier.buyout)
		order.auctions=order.auctions+auctions
		order.lines[#order.lines+1]={tier=tier,units=units,auctions=auctions}
	end
	order.averageUnit=order.units>0 and math.floor(order.cost/order.units) or nil
	order.short=math.max(0,wanted-order.units)
	order.purchases=order.units==0 and 0 or (byUnit and 1 or order.auctions)
	return order
end
function M:Confidence(item)
	local auctions=item and item.listings-item.bidOnly or 0
	local usual=item and self:Usual(item)
	local score,agreement=0,0
	local scans=item and (item.scansSeen or (ns.History:Get(item.key) or {}).n or 1) or 0
	if auctions>0 and usual and item.median then
		local depth=0
		for _,step in ipairs(C.confidenceRule.depth) do if auctions>=step.auctions then depth=step.score end end
		local agreeing=0
		for _,tier in ipairs(item.tiers) do
			if tier.unit>=usual*(1-C.confidenceRule.agreementBand) and tier.unit<=usual*(1+C.confidenceRule.agreementBand) then agreeing=agreeing+tier.units end
		end
		agreement=item.units>0 and agreeing/item.units or 0
		score=math.max(1,math.floor(depth*(C.confidenceRule.agreementFloor+(1-C.confidenceRule.agreementFloor)*agreement)+0.5))
	end
	local level=C.confidenceLevels[1]
	for _,candidate in ipairs(C.confidenceLevels) do if score>=candidate.min then level=candidate end end
	local share=math.floor(agreement*100+0.5)
	local reasons=score==0 and {"None for sale, so no price to go by"} or {
		auctions==1 and "Only 1 auction" or (ns.Comma(auctions).." auctions"),
		agreement<C.confidenceRule.agreementWarning and ("Prices scattered: "..share.."% near usual") or (share.."% priced near usual"),
		scans<=1 and "One scan: listings, not sales" or ("Seen in "..ns.Comma(scans).." scans")}
	return {score=score,level=level,pips=C.confidencePips,
		facts={auctions=score==0 and 0 or auctions,nearUsual=score>0 and share or nil,scans=scans},reasons=reasons}
end
local function Money(copper)
	local gold,silver,rest=math.floor(copper/10000),math.floor(copper/100)%100,math.floor(copper)%100
	return (gold>0 and (gold.."g ") or "")..((gold>0 or silver>0) and (silver.."s ") or "")..rest.."c"
end
function M:Deal(item,units,cost)
	local usual=self:Usual(item)
	local confidence=self:Confidence(item)
	local thresholds={}
	for _,level in ipairs(C.confidenceLevels) do thresholds[level.id]=level.min end
	if units<=0 or not usual or confidence.score<thresholds[C.dealRule.needsConfidence] then
		return {known=false,score=0,level=C.dealUnknown,pips=C.dealPips,reasons={"Too few auctions to know what this usually goes for.",confidence.reasons[1]}}
	end
	local under=(usual-cost/units)/usual*100
	local level=C.dealLevels.fair
	if under < -C.dealRule.fairBand then level=C.dealLevels.over
	elseif under>=C.dealRule.resellFrom and confidence.score>=thresholds[C.dealRule.resellNeeds] then level=C.dealLevels.resell
	elseif under>=C.dealRule.greatFrom then level=confidence.score>=thresholds[C.dealRule.confidentNeeds] and C.dealLevels.confident or C.dealLevels.great end
	local percent=math.floor(math.abs(under)+0.5)
	local reasons={percent==0 and ("Right at the usual price of "..Money(usual)..".") or (percent.."% "..(under>0 and "under" or "over").." the usual price of "..Money(usual)..".")}
	if level==C.dealLevels.great then reasons[#reasons+1]="Not many auctions behind that usual price, so check it." end
	return {known=true,score=math.max(0,math.min(100,math.floor(under+0.5))),saving=math.floor(usual*units-cost+0.5),
		level=level,pips=C.dealPips,reasons=reasons}
end
function M:Price(item,id)
	if id=="match" then return item.min end
	if id=="undercut-copper" then return item.min and math.max(1,item.min-1) end
	if id=="undercut-percent" then return item.min and math.max(1,math.floor(item.min*0.95)) end
	local usual=self:Usual(item)
	if id=="median" then return usual end
	if id=="skip-outliers" and usual then
		for _,tier in ipairs(item.tiers) do if tier.unit>=usual*0.5 then return math.max(1,tier.unit-1) end end
	end
end
function M:Resell(item,margin,budget,limit)
	local target=self:Usual(item)
	if not target or item.listings-item.bidOnly<5 then return end
	local plan={item=item,target=target,lines={},available=0,buyAuctions=0,buyUnits=0,cost=0,competition=0}
	for _,tier in ipairs(item.tiers) do
		if tier.unit>target then break end
		local worth=tier.unit<=target*(1-margin/100) and tier.copies or 0
		plan.available=plan.available+worth
		local take=math.min(worth,(limit or math.huge)-plan.buyAuctions)
		if budget>0 then take=math.min(take,math.floor((budget-plan.cost)/tier.buyout)) end
		take=math.max(0,take)
		if take>0 then plan.lines[#plan.lines+1]={tier=tier,auctions=take} end
		plan.buyAuctions=plan.buyAuctions+take; plan.buyUnits=plan.buyUnits+take*tier.stack
		plan.cost=plan.cost+take*tier.buyout; plan.competition=plan.competition+(tier.copies-take)*tier.stack
	end
	if plan.buyUnits==0 then return end
	plan.averageUnit=math.floor(plan.cost/plan.buyUnits)
	plan.revenue=math.floor(plan.buyUnits*target*(1-C.assumptions.auctionCut))
	plan.profit=plan.revenue-plan.cost; plan.roi=math.floor(plan.profit/plan.cost*100)
	return plan
end
