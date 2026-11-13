-- lab/src/ui/concept/resell.ts: filters, sortable leads, Buy / Relist / Keep.
local _,ns=...
local W,C,M=ns.Widgets,ns.Concept,ns.ConceptModel
function ns.ConceptTabs.Resell(parent,ctx)
	local page=CreateFrame("Frame",nil,parent); page:SetAllPoints()
	local center=CreateFrame("Frame",nil,page); center:SetSize(582,ctx.height); center:SetPoint("TOPLEFT")
	local panel=W.Panel(page); panel:SetSize(290,ctx.height); panel:SetPoint("TOPRIGHT")
	local scroll=W.Scroll(panel,270,ctx.height-20); scroll:SetPoint("TOPLEFT",10,-10)
	local flow=W.Flow(scroll.content,260)
	local margin,minProfit,withinGold,solidOnly=C.resellMargins[2],5000,false,false
	local selected,wanted=nil,nil
	local sortIndex,descending=5,true
	local leads,Refresh,DrawPlan={},nil,nil
	local function Change(update)
		if ns.Trade:IsBusy() or not ns.Trade:Cancel() then return end
		update(); Refresh()
	end
	local function Budget() return withinGold and GetMoney() or 0 end
	local function SetWanted(value)
		if ns.Trade:IsBusy() or not ns.Trade:Cancel() then return end
		local lead=leads[selected]; if not lead then return end
		wanted=math.max(1,math.min(lead.buyAuctions,math.floor(value))); DrawPlan()
	end
	local quantity=W.Quantity(scroll.content,260,SetWanted,function() local lead=leads[selected]; if lead then SetWanted(lead.buyAuctions) end end)
	local icon=W.Icon(scroll.content,32)
	local meter=W.Meter(scroll.content,260)
	local action=W.Button(scroll.content,"Buy this auction",260,function()
		local lead=leads[selected]; if not lead then return end
		local plan=M:Resell(lead.item,margin,Budget(),wanted)
		if plan then ctx.Buy(plan.item,M:Commodity(plan.item) and plan.buyUnits or plan.lines[1].tier.stack) end
	end,"action"); action:SetHeight(28)
	local refreshPrice=W.Button(scroll.content,"Check again",90,function()
		local lead=leads[selected]; if lead then ns.Trade:Search(lead.item,M:Commodity(lead.item) and lead.buyUnits or lead.lines[1].tier.stack) end
	end)
	DrawPlan=function()
		flow:Reset(); for _,widget in ipairs({quantity,icon,meter,action,refreshPrice}) do widget:Hide() end
		local lead=leads[selected]
		if not lead then
			flow.y=24; local hint=flow:Text("Pick an item to see the plan: what to buy, what to relist it at, and what you keep.",12,"muted"); hint:SetJustifyH("CENTER")
		else
			lead=M:Resell(lead.item,margin,Budget(),wanted) or lead
			local item=lead.item
			icon:Show(); icon:SetPoint("TOPLEFT"); icon:SetItem(item)
			local title=flow:Text(W.ItemText(item),12,nil,16); title:SetWidth(220); title:ClearAllPoints(); title:SetPoint("TOPLEFT",40,0)
			local stock=flow:Text(ns.Comma(item.units).." for sale in "..item.listings.." auctions",11,"muted",14); stock:SetWidth(220); stock:ClearAllPoints(); stock:SetPoint("TOPLEFT",40,-19)
			flow.y=48; flow:Text("1  Buy",14,"accent",18)
			quantity:SetQuantity(lead.buyAuctions); flow:Place(quantity,24)
			local label,message,liveCost=ctx.BuyState(item,lead.buyAuctions>1 and ("Buy auction 1 of "..lead.buyAuctions) or "Buy this auction")
			action:SetText(label); action:SetEnabled(ns.auctionHouseOpen and (liveCost or lead.cost)<=GetMoney() and not ns.Trade:IsBusy()); flow:Place(action,28)
			local nextLine=lead.lines[1]
			flow:Text(message or (M:Commodity(item) and ("Buy "..lead.buyUnits.." units, cheapest sellers first.") or ("stack of "..nextLine.tier.stack.." at "..ns.Money(nextLine.tier.unit).." each")),11,"muted")
			if message then refreshPrice:SetEnabled(not ns.Trade:IsBusy()); flow:Place(refreshPrice,24) end
			meter:SetItem(item); flow:Place(meter,38)
			flow:Row(ns.Comma(lead.buyUnits).." units, average each",ns.Money(lead.averageUnit),11,"muted")
			flow:Row("Cost",ns.Money(lead.cost),12)
			flow.y=flow.y+8; flow:Text("2  Relist",14,"accent",18)
			flow:Row("At the usual price, each",ns.Money(lead.target),11,"muted")
			flow:Row("If all sell, less the "..(C.assumptions.auctionCut*100).."% cut",ns.Money(lead.revenue),11,"muted")
			flow.y=flow.y+8; flow:Text("3  Keep",14,"accent",18)
			flow:Row("Profit",ns.Money(lead.profit),15,"#76d49b")
			flow:Row("Return on what you spend",lead.roi.."%",11,"muted")
			flow:Text(lead.competition==0 and "Nothing else is listed at or under the usual price once you buy." or (ns.Comma(lead.competition).." units stay listed at or under the usual price."),11,lead.competition>lead.buyUnits*3 and "#ff6060" or "muted")
			flow.y=flow.y+6; flow:Text("THE AUCTIONS",11,"muted")
			for i=1,math.min(5,#lead.lines) do local line=lead.lines[i]; flow:Row(line.auctions.." x "..line.tier.stack,ns.Money(line.tier.unit).." each",11,"muted") end
		end
		flow:Finish(); scroll:SetContentHeight(flow.y)
	end
	W.Label(center,"Discount",0,-7,48,11,"muted")
	for i,value in ipairs(C.resellMargins) do
		local button=W.Button(center,value.."%",35,function() Change(function() margin=value; wanted=nil end) end)
		button:SetPoint("TOPLEFT",50+(i-1)*35,0); page["margin"..value]=button
	end
	W.Label(center,"Min profit",162,-7,54,11,"muted")
	local profit=W.Money(center,minProfit,function(value) Change(function() minProfit=value end) end,true); profit:SetPoint("TOPLEFT",217,0)
	local affordable=W.Button(center,"I can afford",94,function(self) Change(function() withinGold=not withinGold; self:SetActive(withinGold) end) end); affordable:SetPoint("TOPLEFT",348,0)
	local top=W.Button(center,"Top deals",80,function(self) Change(function() solidOnly=not solidOnly; self:SetActive(solidOnly) end) end); top:SetPoint("TOPLEFT",447,0)
	local fields={"name","deal","buyUnits","cost","profit"}
	local listTop=C.metrics.resellToolbar+C.metrics.toolbarGap
	local list=W.List(center,582,ctx.height-listTop,{
		{label="Item",text=function(lead) return W.ItemText(lead.item,true) end},
		{label="Deal",width=66,signal=function(lead) return lead.deal end},
		{label="Buy",width=52,align="RIGHT",text=function(lead) return ns.Comma(lead.buyUnits) end},
		{label="Cost",width=96,align="RIGHT",text=function(lead) return ns.Money(lead.cost) end},
		{label="Profit",width=96,align="RIGHT",text=function(lead) return "|cff76d49b"..ns.Money(lead.profit).."|r" end},
	},function(lead)
		if ns.Trade:IsBusy() or not ns.Trade:Cancel() then return end
		selected=lead.item.key; wanted=nil; Refresh()
	end,function(index) if sortIndex==index then descending=not descending else descending=index>=3 end; sortIndex=index; Refresh() end)
	list:SetPoint("TOPLEFT",0,-listTop)
	Refresh=function()
		local market=ctx.Market(); local rows={}; leads={}
		for _,item in ipairs(market and market.items or {}) do
			local lead=M:Resell(item,margin,Budget())
			if lead and lead.profit>=minProfit and (not withinGold or (GetMoney()>0 and lead.cost<=GetMoney())) then
				lead.deal=M:Deal(item,lead.buyUnits,lead.cost)
				if lead.deal.known and lead.deal.level.pips>=(solidOnly and 5 or C.resellMinPips) then rows[#rows+1]=lead; leads[item.key]=lead end
			end
		end
		W.Sort(rows,fields[sortIndex],descending,function(lead,field) if field=="name" then return lead.item.name elseif field=="deal" then return lead.deal.level.pips else return lead[field] end end)
		for _,value in ipairs(C.resellMargins) do page["margin"..value]:SetActive(margin==value) end
		list:SetSort(sortIndex,descending); list:SetRows(rows,selected,C.resellLimit,ctx.Empty("Nothing worth flipping with these settings.")); DrawPlan()
	end
	function page:Refresh() Refresh() end
	page.list=list; return page
end
