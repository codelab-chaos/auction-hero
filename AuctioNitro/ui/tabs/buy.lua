-- lab/src/ui/concept/buy.ts rendered with retained native frames.
local _,ns=...
local W,C,M=ns.Widgets,ns.Concept,ns.ConceptModel
ns.ConceptTabs=ns.ConceptTabs or {}
function ns.ConceptTabs.Buy(parent,ctx)
	local page=CreateFrame("Frame",nil,parent); page:SetAllPoints()
	local height=ctx.height
	local rail=W.Panel(page); rail:SetSize(34,height); rail:SetPoint("TOPLEFT")
	local sidebar=W.Panel(page); sidebar:SetSize(176,height); sidebar:SetPoint("TOPLEFT",42,0)
	local sideScroll=W.Scroll(sidebar,168,height-18); sideScroll:SetPoint("TOPLEFT",9,-9)
	local center=CreateFrame("Frame",nil,page); center:SetSize(396,height); center:SetPoint("TOPLEFT",226,0)
	local detail=W.Panel(page); detail:SetSize(250,height); detail:SetPoint("TOPRIGHT")
	local detailScroll=W.Scroll(detail,230,height-20); detailScroll:SetPoint("TOPLEFT",10,-10)
	local flow=W.Flow(detailScroll.content,220)
	local selected,wanted=nil,1
	local selection,opened,options,groups,tiles,dividers={},{},{},{},{},{}
	local filter={text="",usableOnly=false,affordableOnly=false,dealsOnly=false}
	local sortField,descending,sortIndex="units",true,3
	local list,quantity,Refresh,DrawDetail,DrawFacets
	local function Items() local market=ctx.Market(); return market and market.items or {} end
	local function Toggle(key,value,on)
		selection[key]=selection[key] or {}; selection[key][value]=on and true or nil
		DrawFacets(); Refresh()
	end
	local function SetWanted(value)
		if ns.Trade:IsBusy() or not ns.Trade:Cancel() then return end
		wanted=math.max(1,math.floor(value)); DrawDetail()
	end
	quantity=W.Quantity(detailScroll.content,220,SetWanted,function() local item=ctx.Find(selected); if item then SetWanted(item.units) end end)
	local itemIcon=W.Icon(detailScroll.content,32)
	local dealMeter=W.Signal(detailScroll.content,5,true,150)
	local action=W.Button(detailScroll.content,"Buy",220,function()
		local item=ctx.Find(selected); if item then ctx.Buy(item,wanted) end
	end,"action"); action:SetHeight(28)
	local refreshPrice=W.Button(detailScroll.content,"Check again",90,function()
		local item=ctx.Find(selected); if item then ns.Trade:Search(item,wanted) end
	end)
	DrawDetail=function()
		flow:Reset(); quantity:Hide(); itemIcon:Hide(); dealMeter:Hide(); action:Hide(); refreshPrice:Hide()
		local item=ctx.Find(selected)
		if not item then
			flow.y=24; local hint=flow:Text("Pick an item to see what buying it takes.",12,"muted"); hint:SetJustifyH("CENTER")
		else
			itemIcon:Show(); itemIcon:SetPoint("TOPLEFT"); itemIcon:SetItem(item)
			local title=flow:Text(W.ItemText(item),12,nil,16); title:SetWidth(180); title:ClearAllPoints(); title:SetPoint("TOPLEFT",40,0); title:SetJustifyH("LEFT")
			local available=flow:Text(ns.Comma(item.units).." available",11,"muted",14); available:SetWidth(180); available:ClearAllPoints(); available:SetPoint("TOPLEFT",40,-19)
			flow.y=44; quantity:SetQuantity(wanted); flow:Place(quantity,24)
			local order=M:Order(item,wanted); local reading=M:Deal(item,order.units,order.cost)
			flow:Row("Total",ns.Money(order.cost),15)
			flow:Row("Average each",ns.Money(order.averageUnit),12,"muted")
			if reading.known then
				local meterY=flow.y; flow:Row("Deal","",12)
				dealMeter:Show(); dealMeter:SetReading(reading); dealMeter:ClearAllPoints(); dealMeter:SetPoint("TOPRIGHT",0,-meterY)
				flow:Row(reading.saving>=0 and "You save" or "You pay extra",ns.Money(math.abs(reading.saving)),12,reading.saving>=0 and "#76d49b" or "#ff6060")
			end
			flow:Text(reading.reasons[1],11,"muted")
			if order.units~=wanted and order.short==0 then flow:Text("You get "..ns.Comma(order.units)..": stacks cannot be split.",11,"muted") end
			if order.short>0 then flow:Text("Only "..ns.Comma(order.units).." are for sale.",11,"#ff6060") end
			if order.cost>GetMoney() then flow:Text("More than your gold.",11,"#ff6060") end
			flow.y=flow.y+4
			for i=1,math.min(8,#order.lines) do
				local line=order.lines[i]
				flow:Row(order.byUnit and (ns.Comma(line.units).." units") or (line.auctions.." x stack of "..line.tier.stack),ns.Money(line.tier.unit).." each",11,"muted")
			end
			if #order.lines>8 then flow:Text("and "..(#order.lines-8).." more price points",11,"muted") end
			local label,message,liveCost=ctx.BuyState(item,"Buy "..ns.Comma(order.units))
			action:SetText(label); action:SetEnabled(ns.auctionHouseOpen and order.units>0 and not ns.Trade:IsBusy() and (liveCost or order.cost)<=GetMoney())
			flow:Place(action,28)
			flow:Text(message or (order.byUnit and "Bought by the unit: one purchase, cheapest sellers first." or (order.purchases==1 and "One auction, one purchase." or (order.purchases.." auctions. One purchase per press."))),11,"muted")
			if message then refreshPrice:SetEnabled(not ns.Trade:IsBusy()); flow:Place(refreshPrice,24) end
		end
		flow:Finish(); detailScroll:SetContentHeight(flow.y)
	end
	local function AddTile(key,value,label,color,icon,y,small)
		local id=key..":"..value; local tile=tiles[id]
		if not tile then
			tile=W.Button(rail,"",26,function() Toggle(key,value,not (selection[key] or {})[value]) end)
			tile.image=tile:CreateTexture(nil,"ARTWORK"); tile.image:SetPoint("TOPLEFT",2,-2); tile.image:SetPoint("BOTTOMRIGHT",-2,2)
			tile.check=W.Label(tile,"x",1,-1,10,10,"accent"); W.Tip(tile,label); tiles[id]=tile
		end
		tile:Show(); tile:SetHeight(small and 12 or 26); tile:ClearAllPoints(); tile:SetPoint("TOPLEFT",4,-y)
		local on=(selection[key] or {})[value]; tile:SetActive(on); tile.check:SetShown(on)
		if color then tile.image:SetColorTexture(W.Color(color)); tile.image:SetAlpha(on and 0.75 or 0.28)
		else tile.image:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark"); tile.image:SetAlpha(on and 1 or 0.65) end
		return y+(small and 16 or 30)
	end
	DrawFacets=function()
		for _,tile in pairs(tiles) do tile:Hide() end
		for _,divider in ipairs(dividers) do divider:Hide() end
		local y=7
		local function Refinements(id)
			local category; for _,candidate in ipairs(C.categories) do if candidate.id==id then category=candidate; break end end
			for _,option in ipairs(category.refine.options) do
				local best,preferred
				for _,item in ipairs(Items()) do
					if item.name and item.icon and M:Box(category,item) and category.refine.slotValues[item.equipLoc]==option.value then
						local isPreferred=category.refine.preferredSubClasses and M.Has(category.refine.preferredSubClasses[option.value],item.subClassID or item.subClassId) or false
						if not best or (isPreferred and not preferred) or (isPreferred==preferred and item.listings>best.listings) then best,preferred=item,isPreferred end
					end
				end
				y=AddTile(id.."/refine",option.value,category.refine.label..": "..option.label,nil,best and best.icon,y)
			end
		end
		for index,section in ipairs(C.rail) do
			if index>1 then
				local divider=dividers[index-1]
				if not divider then divider=rail:CreateTexture(nil,"ARTWORK"); divider:SetSize(20,1); W.Paint(divider,"line"); dividers[index-1]=divider end
				divider:ClearAllPoints(); divider:SetPoint("TOPLEFT",7,-y-2); divider:Show(); y=y+11
			end
			for _,entry in ipairs(section) do
				if entry.refine then Refinements(entry.refine)
				elseif entry.facet=="quality" then
					for _,quality in ipairs(C.qualities) do if quality.id<=4 then y=AddTile("quality",tostring(quality.id),"Quality: "..quality.label,quality.color,nil,y,true) end end
				elseif entry.box then
					for _,option in ipairs(options[entry.of] or {}) do if option.label==entry.box then y=AddTile(entry.of,option.value,option.label,nil,option.icon,y) end end
				end
			end
		end
		y=0
		for _,category in ipairs(C.categories) do
			local id=category.id; local group=groups[id]; local choices=options[id] or {}
			if not group then
				group={options={}}; groups[id]=group
				group.head=W.Button(sideScroll.content,"",158,function() opened[id]=not opened[id]; DrawFacets() end)
				group.head:SetHeight(C.metrics.sidebarHeader)
				group.head.label:ClearAllPoints(); group.head.label:SetPoint("LEFT",26,0); group.head.label:SetJustifyH("LEFT"); group.head.label:SetWidth(119)
				group.head.label:SetFont("Fonts\\ARIALN.TTF",13)
				group.arrow=W.Label(group.head,"",0,0,10,11,"muted"); group.arrow:ClearAllPoints(); group.arrow:SetPoint("RIGHT",-5,0)
				group.badge=W.Panel(group.head,"accent","accent"); group.badge:SetSize(18,16); group.badge:SetPoint("RIGHT",-18,0)
				group.count=W.Label(group.badge,"",0,-2,18,11,"panel"); group.count:SetJustifyH("CENTER")
				group.all=W.Check(group.head,"",false,function(on)
					selection[id]={}; if on then for _,option in ipairs(options[id] or {}) do selection[id][option.value]=true end end
					DrawFacets(); Refresh()
				end,14); group.all:SetSize(14,22); group.all:SetPoint("LEFT",6,0)
			end
			group.head:Hide(); for _,control in pairs(group.options) do control:Hide() end
			if #choices>0 then
				local ticked=selection[id] or {}; local count=0; for _ in pairs(ticked) do count=count+1 end
				local refined=0; for _ in pairs(selection[id.."/refine"] or {}) do refined=refined+1 end
				if not category.flat then
					group.head:Show(); group.head:ClearAllPoints(); group.head:SetPoint("TOPLEFT",0,-y)
					group.head:SetText(category.label); group.head.label:SetWidth(count+refined>0 and 92 or 117)
					group.badge:SetShown(count+refined>0); group.count:SetText(count+refined); group.arrow:SetText(opened[id] and "v" or ">")
					group.all:SetChecked(count==#choices,count>0); y=y+C.metrics.sidebarHeader
				end
				if category.flat or opened[id] then
					for i,option in ipairs(choices) do
						if not option.inRail then
							local control=group.options[i]
							if not control then
								control=W.Check(sideScroll.content,"",false,function(on) local current=control.option; Toggle(id,current.value,on) end,150,true); group.options[i]=control
							end
							control.option=option; control.label:SetText(category.flat and #choices==1 and category.label or option.label)
							control:SetIcon(option.icon); control:SetChecked(ticked[option.value]); control:ClearAllPoints(); control:SetPoint("TOPLEFT",4,-y); control:Show(); y=y+24
						end
					end
				end
				y=y+4
			end
		end
		local any=false; for _,set in pairs(selection) do if next(set) then any=true; break end end
		if not page.clear then page.clear=W.Button(sideScroll.content,"Clear all",158,function() for key in pairs(selection) do selection[key]=nil end; DrawFacets(); Refresh() end) end
		page.clear:SetShown(any); page.clear:ClearAllPoints(); page.clear:SetPoint("TOPLEFT",0,-y); if any then y=y+30 end
		sideScroll:SetContentHeight(y)
	end
	local search=W.Edit(center,C.metrics.searchWidth,"",function(text) filter.text=text; Refresh() end); search:SetHeight(26); search:SetPoint("TOPLEFT")
	search.placeholder=W.Label(search,"Search",6,-6,120,12,"muted")
	search:SetScript("OnEditFocusGained",function() search.placeholder:Hide() end)
	search:SetScript("OnEditFocusLost",function() search.placeholder:SetShown(search:GetText()=="") end)
	local x=C.metrics.searchWidth+5
	for i,toggle in ipairs(C.toggles) do
		local id=toggle.id; local button=W.Button(center,toggle.label,C.metrics.buyToggleWidths[i],function(self) filter[id]=not filter[id]; self:SetActive(filter[id]); Refresh() end)
		button:SetPoint("TOPLEFT",x,0); button:SetHeight(26); x=x+C.metrics.buyToggleWidths[i]+5
	end
	local fields={"name","level","units","min","deal"}
	list=W.List(center,396,height-32,{
		{label="Item",text=function(item) return W.ItemText(item,true) end},
		{label="Lvl",width=44,align="RIGHT",text=function(item) return item.levelType=="REQ_LEVEL_ABBR" and item.level or "" end},
		{label="Avail",width=64,align="RIGHT",text=function(item) return ns.Comma(item.units) end},
		{label="Price",width=100,align="RIGHT",text=function(item) return ns.Money(item.min) end},
		{label="",width=54,align="RIGHT",text=function(item) local value=item.deal; return value and value>=30 and ("|cff76d49b-"..value.."%|r") or "" end},
	},function(item)
		if ns.Trade:IsBusy() or not ns.Trade:Cancel() then return end
		selected=item.key; wanted=1; Refresh()
	end,function(index)
		if not fields[index] then return end
		if sortIndex==index then descending=not descending else descending=index~=1 end
		sortField,sortIndex=fields[index],index; Refresh()
	end); list:SetPoint("TOPLEFT",0,-32)
	Refresh=function()
		local rows={}
		for _,item in ipairs(Items()) do if M:Filter(item,filter,GetMoney()) and M:Matches(item,selection) then rows[#rows+1]=item end end
		W.Sort(rows,sortField,descending,function(item,field) if field=="level" and item.levelType~="REQ_LEVEL_ABBR" then return nil end; return item[field] end); list:SetSort(sortIndex,descending)
		list:SetRows(rows,selected,C.buyLimit,ctx.Empty("Nothing matches.")); DrawDetail()
	end
	local lastMarket
	function page:Refresh()
		local market=ctx.Market()
		if market~=lastMarket then
			lastMarket=market; for _,category in ipairs(C.categories) do options[category.id]=M:Options(category,Items()) end
			DrawFacets()
		end
		Refresh()
	end
	page.list=list; page.selection=selection
	DrawFacets(); return page
end
