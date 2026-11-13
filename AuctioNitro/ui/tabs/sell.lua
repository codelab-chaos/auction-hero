-- The lab's Sell form, with real bag slots replacing PRETEND_BAG.
local _,ns=...
local W,C,M=ns.Widgets,ns.Concept,ns.ConceptModel
function ns.ConceptTabs.Sell(parent,ctx)
	local page=CreateFrame("Frame",nil,parent); page:SetAllPoints()
	local bags=W.Panel(page); bags:SetSize(200,ctx.height); bags:SetPoint("TOPLEFT")
	W.Label(bags,"Your bags",10,-10,170,12,"accent")
	local bagScroll=W.Scroll(bags,180,ctx.height-42); bagScroll:SetPoint("TOPLEFT",10,-32)
	local bagButtons={}
	local form=W.Panel(page); form:SetSize(434,ctx.height); form:SetPoint("TOPLEFT",208,0)
	local formScroll=W.Scroll(form,416,ctx.height-18,0); formScroll:SetPoint("TOPLEFT",9,-9)
	local flow=W.Flow(formScroll.content,416)
	local competition=W.Panel(page); competition:SetSize(230,ctx.height); competition:SetPoint("TOPRIGHT")
	local competitionScroll=W.Scroll(competition,210,ctx.height-20); competitionScroll:SetPoint("TOPLEFT",10,-10)
	local ladder=W.Flow(competitionScroll.content,200)
	local selected,perAuction,auctions=nil,1,1
	local ruleId,duration,saleType=C.defaultPriceRule,C.defaultDuration,"buyout"
	local customUnit,customBid
	local Refresh,DrawForm,DrawBags
	local function Bag() return ns.Inventory.byKey[selected] end
	local function Item()
		local bag=Bag(); if not bag then return end
		return ctx.Find(selected) or {key=bag.key,name=bag.name,itemID=bag.itemID,quality=bag.quality,icon=bag.icon,link=bag.link,commodity=bag.commodity,tiers={},units=0,listings=0,bidOnly=0}
	end
	local function UnitPrice() local item=Item(); return customUnit or (item and M:Price(item,ruleId)) end
	local function BidPrice() local unit=UnitPrice(); return customBid or (unit and math.max(1,math.floor(unit*C.startingBidShare))) end
	local function Change(fn) if ns.Trade:IsBusy() or not ns.Trade:Cancel() then return end; fn(); Refresh() end
	local icon=W.Icon(formScroll.content,40)
	local saleRow=CreateFrame("Frame",nil,formScroll.content); saleRow:SetSize(404,26); W.Label(saleRow,"Sale",0,-6,54,11,"muted")
	local saleButtons={}
	local x=64
	for i,option in ipairs(C.saleTypes) do
		local id=option.id; local b=W.Button(saleRow,option.label,({87,122,91})[i],function() Change(function() saleType=id end) end)
		b:SetPoint("TOPLEFT",x,0); W.Tip(b,option.note); saleButtons[id]=b; x=x+({87,122,91})[i]+4
	end
	local price=W.Money(formScroll.content,0,function(value) Change(function() customUnit=math.max(1,value) end) end)
	local rules=CreateFrame("Frame",nil,formScroll.content); rules:SetSize(404,24)
	local ruleButtons={}; x=0
	for i,rule in ipairs(C.priceRules) do
		local id=rule.id; local width=({49,65,71,100,99})[i]
		local b=W.Button(rules,rule.label,width,function() Change(function() ruleId=id; customUnit=nil end) end); b:SetPoint("TOPLEFT",x,0)
		b.label:SetFont("Fonts\\ARIALN.TTF",11); W.Tip(b,rule.note); ruleButtons[id]=b; x=x+width+4
	end
	local bidRow=CreateFrame("Frame",nil,formScroll.content); bidRow:SetSize(404,24)
	W.Label(bidRow,"Starting bid",0,-5,80,11,"muted")
	local bid=W.Money(bidRow,0,function(value) Change(function() customBid=math.max(1,value) end) end,true); bid:SetPoint("TOPLEFT",90,0)
	local meter=W.Meter(formScroll.content,404)
	local sizeRow=CreateFrame("Frame",nil,formScroll.content); sizeRow:SetSize(404,24)
	W.Label(sizeRow,"Each auction",0,-4,90,11,"muted")
	local sizeValue=W.Label(sizeRow,"",266,-4,134,12); sizeValue:SetJustifyH("RIGHT")
	local size=W.Slider(sizeRow,162,function(value) Change(function() perAuction=value end) end); size:SetPoint("TOPLEFT",98,-2)
	local countRow=CreateFrame("Frame",nil,formScroll.content); countRow:SetSize(404,24)
	W.Label(countRow,"Auctions",0,-4,90,11,"muted")
	local countValue=W.Label(countRow,"",266,-4,134,12); countValue:SetJustifyH("RIGHT")
	local count=W.Slider(countRow,162,function(value) Change(function() auctions=value end) end); count:SetPoint("TOPLEFT",98,-2)
	local durationRow=CreateFrame("Frame",nil,formScroll.content); durationRow:SetSize(404,24); W.Label(durationRow,"Duration",0,-5,80,11,"muted")
	local durationButtons={}
	for i,option in ipairs(C.durations) do
		local index=option.index; local b=W.Button(durationRow,option.label,76,function() Change(function() duration=index end) end)
		b:SetPoint("TOPLEFT",98+(i-1)*80,0); W.Tip(b,option.note); durationButtons[index]=b
	end
	local action=W.Button(formScroll.content,"Post auction",416,function()
		local bag=Bag(); local unit=UnitPrice(); if not bag or not unit then return end
		ns.Trade:Post(selected,bag.commodity and perAuction*auctions or perAuction,unit,saleType=="bids" and unit or (BidPrice() or unit),duration,saleType)
	end,"action"); action:SetHeight(32)
	DrawForm=function()
		flow:Reset(); ladder:Reset()
		for _,control in ipairs({icon,saleRow,price,rules,bidRow,meter,sizeRow,countRow,durationRow,action}) do control:Hide() end
		local bag,item=Bag(),Item()
		if not bag then
			flow.y=24; local hint=flow:Text("Pick an item from your bags.",12,"muted"); hint:SetJustifyH("CENTER")
			ladder:Text("The competition",12,"accent")
		else
			perAuction=math.max(1,math.min(perAuction,bag.count)); auctions=math.max(1,math.min(auctions,math.floor(bag.count/perAuction)))
			if bag.commodity then saleType="buyout" end
			icon:Show(); icon:SetPoint("TOPLEFT"); icon:SetItem(bag)
			local title=flow:Text(W.ItemText(bag),13,nil,18); title:SetWidth(356); title:ClearAllPoints(); title:SetPoint("TOPLEFT",48,0); title:SetJustifyH("LEFT")
			local owned=flow:Text("You have "..ns.Comma(bag.count)..(#bag.slots>1 and (" in "..#bag.slots.." stacks") or ""),11,"muted",16)
			owned:SetWidth(356); owned:ClearAllPoints(); owned:SetPoint("TOPLEFT",48,-22)
			flow.y=50
			for id,button in pairs(saleButtons) do button:SetActive(saleType==id); button:SetEnabled(not bag.commodity or id=="buyout") end
			flow:Place(saleRow,26)
			local unit=UnitPrice(); local starting=BidPrice()
			flow:Text(saleType=="bids" and "Starting bid each" or "Price each",12,"accent",14)
			price:SetAmount(unit); flow:Place(price,24)
			for id,button in pairs(ruleButtons) do button:SetActive(not customUnit and ruleId==id); button:SetEnabled(M:Price(item,id)~=nil) end
			flow:Place(rules,24)
			if saleType=="both" then bid:SetAmount(starting); flow:Place(bidRow,24) end
			meter:SetItem(item); flow:Place(meter,38)
			if bag.count>1 then
				size:Update(perAuction,bag.count); sizeValue:SetText(ns.Comma(perAuction).." units"); flow:Place(sizeRow,24)
				local maximum=math.floor(bag.count/perAuction); count:Update(auctions,maximum); countValue:SetText(auctions.." of "..maximum); flow:Place(countRow,24)
			end
			for index,button in pairs(durationButtons) do button:SetActive(duration==index) end
			flow:Place(durationRow,24)
			local posting=perAuction*auctions; local all=(unit or 0)*posting
			flow:Text("Posting "..ns.Comma(posting).." of "..ns.Comma(bag.count)..(posting<bag.count and (", keeping "..ns.Comma(bag.count-posting)) or ""),11,"muted")
			flow:Row(saleType=="bids" and "All starting bids" or (auctions>1 and "All buyouts" or "Buyout"),ns.Money(all),15)
			flow:Row("After the "..(C.assumptions.auctionCut*100).."% cut",ns.Money(math.floor(all*(1-C.assumptions.auctionCut))),12,"muted")
			if not unit then flow:Text("Nobody is selling this, so there is no price to go by. Type one.",11,"muted") end
			local invalid=saleType=="both" and starting and unit and starting>=unit
			if invalid then flow:Text("The starting bid has to be under the buy now price.",11,"#ff6060") end
			local state=ns.Trade.state
			action:SetText(state.phase=="post-confirm" and "Confirm post" or (bag.commodity and ("Post "..ns.Comma(posting).." units") or (auctions>1 and ("Post next auction ("..auctions.." remaining)") or "Post auction")))
			action:SetEnabled(ns.auctionHouseOpen and unit~=nil and not invalid and not ns.Trade:IsBusy()); flow:Place(action,28)
			if state.message then flow:Text(state.message,11,state.phase=="error" and "#ff6060" or "muted")
			elseif not ns.auctionHouseOpen then flow:Text("Open the auction house to post.",11,"muted")
			elseif bag.commodity then flow:Text("Commodities post as one combined quantity.",11,"muted")
			elseif auctions>1 then flow:Text("One auction per press.",11,"muted") end
			ladder:Text("The competition",12,"accent")
			ladder:Text("auctions x units each",11,"muted")
			local placed,ahead,shown=not unit,0,0
			local function You() ladder:Row("You: "..auctions.." x "..perAuction,ns.Money(unit),12,"#76d49b") end
			for _,tier in ipairs(item.tiers) do
				if not placed and tier.unit>=unit then You(); placed=true end
				if not placed then ahead=ahead+tier.units end
				if shown<9 then ladder:Row(tier.copies.." x "..tier.stack,ns.Money(tier.unit),12); shown=shown+1 end
			end
			if not placed then You() end
			ladder.y=ladder.y+8
			ladder:Text(unit and (ahead==0 and "You would be the cheapest." or (ns.Comma(ahead).." units sell before yours.")) or ctx.Empty("No competing buyouts."),11,"muted")
			ladder:Text(item.listings.." auctions, usual price "..ns.Money(M:Usual(item)),11,"muted")
		end
		flow:Finish(); ladder:Finish(); formScroll:SetContentHeight(flow.y); competitionScroll:SetContentHeight(ladder.y)
	end
	local function Choose(bag)
		Change(function() selected=bag.key; perAuction=math.min(bag.count,bag.slots[1].count); auctions=math.max(1,math.floor(bag.count/perAuction)); customUnit=nil; customBid=nil end)
	end
	DrawBags=function()
		local slots={}
		for _,bag in ipairs(ns.Inventory.items) do for _,slot in ipairs(bag.slots) do slots[#slots+1]={item=bag,slot=slot} end end
		table.sort(slots,function(a,b) if a.slot.bag~=b.slot.bag then return a.slot.bag<b.slot.bag end; return a.slot.slot<b.slot.slot end)
		for i=1,math.max(16,#slots) do
			local button=bagButtons[i]
			if not button then
				button=W.Button(bagScroll.content,"",40,function(self) if self.value then Choose(self.value) end end)
				button:SetHeight(40); button.image=button:CreateTexture(nil,"ARTWORK"); button.image:SetPoint("TOPLEFT",3,-3); button.image:SetPoint("BOTTOMRIGHT",-3,3)
				button.count=W.Label(button,"",0,0,34,12); button.count:ClearAllPoints(); button.count:SetPoint("BOTTOMRIGHT",-3,3); button.count:SetJustifyH("RIGHT")
				W.Tip(button,nil,function() return button.value end); bagButtons[i]=button
			end
			local entry=slots[i]; button.value=entry and entry.item; button:SetActive(entry and entry.item.key==selected)
			button.image:SetTexture(entry and entry.item.icon); button.count:SetText(entry and entry.slot.count>1 and entry.slot.count or "")
			button:ClearAllPoints(); button:SetPoint("TOPLEFT",((i-1)%4)*44,-math.floor((i-1)/4)*44); button:Show()
		end
		for i=math.max(16,#slots)+1,#bagButtons do bagButtons[i]:Hide() end
		bagScroll:SetContentHeight(math.ceil(math.max(16,#slots)/4)*44)
	end
	Refresh=function() DrawBags(); DrawForm() end
	function page:Refresh()
		if selected and not Bag() then selected=nil end
		if not selected and ns.Inventory.items[1] then
			local bag=ns.Inventory.items[1]; selected=bag.key; perAuction=bag.slots[1].count; auctions=math.max(1,math.floor(bag.count/perAuction)); customUnit=nil; customBid=nil
		end
		Refresh()
	end
	function page:Posted(post) if post.key==selected then auctions=math.max(1,auctions-1) end end
	page.bagButtons=bagButtons; return page
end
