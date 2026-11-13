-- The lab's 900x600 concept as a native WoW window. The title bar stays small;
-- trading tabs own the space, and the old inspector is behind Data.
local _, ns = ...
local W, Bus = ns.Widgets, ns.Bus
local Window = {}
ns.Window = Window
local frame, body, footer, gold, tabs
local pages = {}
local active = "buy"

local function Market()
	local market=ns.Analysis and ns.Analysis.market
	local place=(GetRealmName() or "?").." / "..(UnitFactionGroup("player") or "?")
	if market and market.place and market.place~=place then return end
	return market
end
local function Find(key) local market=Market(); return market and market.byKey[key] end
local function ItemText(item)
	local color = ITEM_QUALITY_COLORS[item.quality or 1] or ITEM_QUALITY_COLORS[1]
	return (item.icon and ("|T" .. item.icon .. ":18|t ") or "") .. color.hex .. item.name .. "|r"
end
local function Tip(button, text)
	button:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(text,1,1,1,true); GameTooltip:Show() end)
	button:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
local function EmptyItem(bag)
	return { key=bag.key, itemID=bag.itemID, name=bag.name, icon=bag.icon, link=bag.link, quality=bag.quality,
		commodity=bag.commodity, tiers={}, units=0, listings=0, bidOnly=0 }
end
local function ChoiceValues(options, field)
	local result = {}
	for _, option in ipairs(options) do result[#result+1] = { id=option[field or "id"], label=option.label } end
	return result
end
local function BuyDetail(parent, itemProvider, quantityProvider)
	local panel = W.Panel(parent)
	panel:SetSize(272,499); panel:SetPoint("TOPRIGHT")
	local title = W.Label(panel,"Pick an item.",12,-12,245,"GameFontNormal")
	local facts = W.Label(panel,"",12,-43,245)
	facts:SetHeight(78); facts:SetJustifyV("TOP")
	local confidence = W.Meter(panel); confidence:SetPoint("TOPLEFT",12,-126)
	local ladder = W.Label(panel,"",12,-185,245); ladder:SetHeight(160); ladder:SetJustifyV("TOP")
	local stateText = W.Label(panel,"",12,-356,245); stateText:SetHeight(60); stateText:SetJustifyV("TOP")
	local action = W.Button(panel,"Check current price",244,function()
		local item = itemProvider()
		if not item then return end
		local state = ns.Trade.state
		if state.item and state.item.key == item.key and (state.phase == "item" or state.phase == "commodity" or state.phase == "quote") then ns.Trade:Buy()
		else ns.Trade:Search(item, quantityProvider()) end
	end)
	action:SetPoint("BOTTOMLEFT",12,43)
	local reset = W.Button(panel,"Refresh price",244,function()
		local item=itemProvider(); if item then ns.Trade:Search(item,quantityProvider()) end
	end)
	reset:SetPoint("BOTTOMLEFT",12,12)
	function panel:Refresh()
		local item=itemProvider()
		action:SetEnabled(item ~= nil and ns.auctionHouseOpen and not ns.Trade:IsBusy())
		reset:SetEnabled(item ~= nil and ns.auctionHouseOpen and not ns.Trade:IsBusy())
		if not item then title:SetText("Pick an item."); facts:SetText(""); ladder:SetText(""); stateText:SetText(""); confidence:Hide(); return end
		confidence:Show(); confidence:SetItem(item)
		title:SetText(ItemText(item))
		local order=ns.Trading:Order(item,quantityProvider(),item.commodity)
		local usual=ns.History:Usual(item)
		facts:SetText(ns.Comma(item.units) .. " listed\nUsual each: " .. ns.Money(usual) .. "\nOrder: " .. ns.Comma(order.units) .. " units, " .. ns.Money(order.cost)
			.. "\n" .. (item.commodity and "Bought by the unit" or "One whole auction per purchase"))
		local lines = { "|cffffd100Price ladder|r" }
		for i=1,math.min(7,#item.tiers) do
			local tier=item.tiers[i]
			lines[#lines+1]=ns.Comma(tier.units) .. " units at " .. ns.Money(tier.unit) .. " each"
		end
		ladder:SetText(table.concat(lines,"\n"))
		local state=ns.Trade.state
		local relevant=state.item and state.item.key == item.key
		local label="Check current price"
		if relevant and state.phase == "item" then label="Buy " .. state.units .. " for " .. ns.Money(state.cost)
		elseif relevant and state.phase == "commodity" then label="Get quote for " .. state.quantity
		elseif relevant and state.phase == "quote" then label="Buy " .. state.quantity .. " for " .. ns.Money(state.cost)
		elseif ns.Trade:IsBusy() then label="Please wait..." end
		action:SetText(label)
		stateText:SetText((relevant or state.phase == "error" or state.phase == "done") and state.message or "")
	end
	return panel
end

local function BuildBuy(parent)
	local page=CreateFrame("Frame",nil,parent); page:SetAllPoints()
	local selected, category, quality, subtype, slot = nil, ns.Categories[1], -1, "", ""
	local search, usable, affordable, deals, minLevel, maxLevel = "", false, false, false, 0, 0
	local sortField, descending = "units", true
	local wanted=1
	local sidebar=W.Panel(page); sidebar:SetSize(158,499); sidebar:SetPoint("TOPLEFT")
	local detail=BuyDetail(page,function() return Find(selected) end,function() return wanted end)
	local list,quantity
	local sortFields={"name","level","units","min"}
	local function RefreshList()
		local rows={}
		for _,item in ipairs(Market() and Market().items or {}) do
			local match=item.units>0 and category.match(item)
			if match and search ~= "" then match=item.name:lower():find(search,1,true) ~= nil end
			if match and quality >= 0 then match=item.quality == quality end
			if match and subtype ~= "" then match=item.subType == subtype end
			if match and slot ~= "" then match=item.equipLoc == slot end
			if match and usable then match=item.usable == true end
			if match and affordable then
				local order=ns.Trading:Order(item,1,item.commodity); match=order.cost>0 and order.cost<=GetMoney()
			end
			if match and deals then match=ns.Trading:Deal(item)>=30 end
			if match and (minLevel>0 or maxLevel>0) then
				match=item.levelType == "REQ_LEVEL_ABBR" and item.level and item.level>=minLevel and (maxLevel==0 or item.level<=maxLevel)
			end
			if match then rows[#rows+1]=item end
		end
		table.sort(rows,function(a,b)
			local av,bv=a[sortField],b[sortField]
			if av == bv then return a.key<b.key end
			if av == nil then return false elseif bv == nil then return true end
			if descending then return av>bv else return av<bv end
		end)
		list:SetRows(rows,selected)
	end
	local subtypeDrop,slotDrop
	local function RefreshChoices()
		local subs,slots={},{}
		for _,item in ipairs(Market() and Market().items or {}) do
			if category.match(item) then
				if item.subType then subs[item.subType]=true end
				if item.equipLoc and item.equipLoc ~= "" then slots[item.equipLoc]=true end
			end
		end
		local function Options(values,names,label)
			local result={ {id="",label=label} }
			for value in pairs(values) do result[#result+1]={id=value,label=names and names[value] or value} end
			table.sort(result,function(a,b) if a.id=="" then return true elseif b.id=="" then return false else return a.label<b.label end end)
			return result
		end
		subtypeDrop:SetChoices(Options(subs,nil,"All types"),subtype)
		slotDrop:SetChoices(Options(slots,ns.SlotNames,"All slots"),slot)
	end
	for i,definition in ipairs(ns.Categories) do
		local option=definition
		local button=W.Button(sidebar,option.label,140,function() category=option; subtype=""; slot=""; RefreshChoices(); RefreshList() end)
		button:SetPoint("TOPLEFT",9,-10-(i-1)*27)
	end
	local qualities={{id=-1,label="All qualities"}}
	for i=0,4 do qualities[#qualities+1]={id=i,label=_G["ITEM_QUALITY"..i.."_DESC"] or tostring(i)} end
	local qualityDrop=W.Dropdown(sidebar,140,qualities,-1,function(value) quality=value; RefreshList() end)
	qualityDrop:SetPoint("TOPLEFT",9,-318)
	subtypeDrop=W.Dropdown(sidebar,140,{{id="",label="All types"}},"",function(value) subtype=value; RefreshList() end)
	subtypeDrop:SetPoint("TOPLEFT",9,-350)
	slotDrop=W.Dropdown(sidebar,140,{{id="",label="All slots"}},"",function(value) slot=value; RefreshList() end)
	slotDrop:SetPoint("TOPLEFT",9,-382)
	W.Label(sidebar,"Required level",12,-425)
	local low=W.Edit(sidebar,51,"",function(text) minLevel=tonumber(text) or 0; RefreshList() end,true); low:SetPoint("TOPLEFT",13,-446)
	local high=W.Edit(sidebar,51,"",function(text) maxLevel=tonumber(text) or 0; RefreshList() end,true); high:SetPoint("TOPLEFT",88,-446)
	W.Label(sidebar,"to",68,-451)
	local name=W.Edit(page,392,"",function(text) search=text:lower(); RefreshList() end); name:SetPoint("TOPLEFT",174,-2)
	Tip(name,"Search items by name")
	local u=W.Check(page,"I can use",false,function(v) usable=v; RefreshList() end); u:SetPoint("TOPLEFT",168,-29)
	local a=W.Check(page,"I can afford",false,function(v) affordable=v; RefreshList() end); a:SetPoint("TOPLEFT",278,-29)
	local d=W.Check(page,"Deals",false,function(v) deals=v; RefreshList() end); d:SetPoint("TOPLEFT",414,-29)
	list=W.List(page,430,400,{
		{label="Item",width=196,text=ItemText},
		{label="Lvl",width=34,text=function(i) return i.levelType=="REQ_LEVEL_ABBR" and tostring(i.level or "") or "" end},
		{label="Avail",width=65,text=function(i) return ns.Comma(i.units) end},
		{label="Each",width=110,text=function(i) return ns.Money(i.min) end},
	},function(item) if not ns.Trade:Cancel() then return end; selected=item.key; wanted=1; quantity:SetText("1"); list:SetRows(list.data,selected); detail:Refresh() end,
	function(index)
		local field=sortFields[index]
		if sortField==field then descending=not descending else descending=field~="name" end
		sortField=field; RefreshList()
	end)
	list:SetPoint("TOPLEFT",168,-59)
	W.Label(page,"Quantity",174,-478)
	quantity=W.Edit(page,65,1,function(text) ns.Trade:Cancel(); wanted=math.max(1,math.floor(tonumber(text) or 1)); detail:Refresh() end,true)
	quantity:SetPoint("TOPLEFT",241,-472)
	function page:Refresh() RefreshChoices(); RefreshList(); detail:Refresh() end
	return page
end

local function BuildSell(parent)
	local page=CreateFrame("Frame",nil,parent); page:SetAllPoints()
	local selected,quantity,auctions,unit,bid= nil,1,1,0,0
	local ruleId,duration,saleType=ns.DefaultPriceRule,ns.DefaultDuration,"buyout"
	local custom=false
	local bagList,priceInput,bidInput,quantityInput,auctionInput,ruleDrop,saleDrop,durationDrop
	local form=W.Panel(page); form:SetSize(354,499); form:SetPoint("TOPLEFT",216,0)
	local competition=W.Panel(page); competition:SetSize(300,499); competition:SetPoint("TOPRIGHT")
	local title=W.Label(form,"Pick an item from your bags.",12,-12,328,"GameFontNormal")
	local totals=W.Label(form,"",12,-346,328); totals:SetHeight(70); totals:SetJustifyV("TOP")
	local status=W.Label(form,"",12,-422,328); status:SetHeight(33)
	local meter=W.Meter(competition); meter:SetPoint("TOPLEFT",12,-15)
	local ladder=W.Label(competition,"",12,-83,276); ladder:SetHeight(390); ladder:SetJustifyV("TOP")
	local function Bag() return selected and ns.Inventory.byKey[selected] end
	local function Item() local bag=Bag(); return bag and (Find(selected) or EmptyItem(bag)) end
	local Refresh
	local function Edit() ns.Trade:Cancel(); Refresh() end
	local function Suggest()
		local item=Item()
		if not item then return end
		for _,rule in ipairs(ns.PriceRules) do
			if rule.id==ruleId then unit=rule.price(item,ns.History:Usual(item)) or 0; break end
		end
		if C_AuctionHouse.SupportsCopperValues and not C_AuctionHouse.SupportsCopperValues() then unit=math.ceil(unit/100)*100 end
		bid=math.max(1,math.floor(unit*ns.StartingBidShare))
		priceInput:SetAmount(unit); bidInput:SetAmount(bid)
	end
	W.Label(form,"Price rule",12,-42)
	ruleDrop=W.Dropdown(form,326,ChoiceValues(ns.PriceRules),ruleId,function(id) ruleId=id; custom=false; ns.Trade:Cancel(); Suggest(); Refresh() end)
	ruleDrop:SetPoint("TOPLEFT",12,-60)
	W.Label(form,"Buyout each",12,-94)
	priceInput=W.Money(form,0,function(value) custom=true; unit=value; Edit() end); priceInput:SetPoint("TOPLEFT",12,-112)
	saleDrop=W.Dropdown(form,326,ChoiceValues(ns.SaleTypes),saleType,function(id) saleType=id; Edit() end); saleDrop:SetPoint("TOPLEFT",12,-150)
	W.Label(form,"Starting bid each",12,-188)
	bidInput=W.Money(form,0,function(value) bid=value; Edit() end); bidInput:SetPoint("TOPLEFT",12,-206)
	W.Label(form,"Units per auction",12,-244)
	quantityInput=W.Edit(form,72,1,function(text) quantity=math.max(1,math.floor(tonumber(text) or 1)); Edit() end,true); quantityInput:SetPoint("TOPLEFT",17,-262)
	W.Label(form,"Auctions",180,-244)
	auctionInput=W.Edit(form,62,1,function(text) auctions=math.max(1,math.floor(tonumber(text) or 1)); Edit() end,true); auctionInput:SetPoint("TOPLEFT",185,-262)
	W.Label(form,"Duration",12,-296)
	durationDrop=W.Dropdown(form,326,ChoiceValues(ns.Durations,"index"),duration,function(id) duration=id; Edit() end); durationDrop:SetPoint("TOPLEFT",12,-314)
	local post=W.Button(form,"Post auction",326,function()
		if Bag() then ns.Trade:Post(selected,quantity,unit,math.max(1,bid),duration,saleType) end
	end); post:SetPoint("BOTTOMLEFT",12,12)
	bagList=W.List(page,206,499,{
		{label="Your bags",width=145,text=ItemText},
		{label="Qty",width=36,text=function(i) return ns.Comma(i.count) end},
	},function(bag)
		if not ns.Trade:Cancel() then return end
		selected,custom=bag.key,false
		quantity=bag.commodity and bag.count or math.min(bag.count,bag.slots[1].count)
		auctions=bag.commodity and 1 or math.max(1,math.floor(bag.count/quantity))
		if bag.commodity then saleType="buyout"; saleDrop:SetChoice(saleType) end
		quantityInput:SetText(tostring(quantity)); auctionInput:SetText(tostring(auctions)); Suggest(); Refresh()
	end); bagList:SetPoint("TOPLEFT")
	Refresh=function()
		bagList:SetRows(ns.Inventory.items,selected)
		local bag,item=Bag(),Item()
		post:SetEnabled(bag ~= nil and ns.auctionHouseOpen and not ns.Trade:IsBusy() and unit>0)
		local phase=ns.Trade.state.phase
		post:SetText(phase=="post-confirm" and "Confirm post" or (auctions>1 and ("Post next ("..auctions.." left)") or "Post auction"))
		status:SetText(ns.Trade.state.message or "")
		if not bag then title:SetText("Pick an item from your bags."); totals:SetText(""); ladder:SetText(""); meter:Hide(); return end
		title:SetText(ItemText(bag)); meter:Show(); meter:SetItem(item)
		if bag.commodity then auctions=1; auctionInput:SetText("1") end
		auctionInput:SetEnabled(not bag.commodity); saleDrop:SetEnabled(not bag.commodity)
		local deposit
		if ns.auctionHouseOpen and bag.slots[1] then
			local location=ItemLocation:CreateFromBagAndSlot(bag.slots[1].bag,bag.slots[1].slot)
			if quantity<=C_AuctionHouse.GetAvailablePostCount(location) then
				deposit=bag.commodity and C_AuctionHouse.CalculateCommodityDeposit(bag.itemID,duration,quantity) or C_AuctionHouse.CalculateItemDeposit(location,duration,quantity)
			end
		end
		local total=(saleType=="bids" and bid or unit)*quantity
		totals:SetText("In bags: "..ns.Comma(bag.count).."\nThis auction: "..ns.Comma(quantity).." units for "..ns.Money(total)
			.."\nDeposit: "..(deposit and ns.Money(deposit) or "unavailable")
			.."\nAfter assumed 5% cut: "..ns.Money(math.floor(total*(1-ns.Assumptions.auctionCut))))
		local lines={"|cffffd100The competition|r", "Usual each: "..ns.Money(ns.History:Usual(item)), ""}
		local ahead=0
		for _,tier in ipairs(item.tiers) do if tier.unit<unit then ahead=ahead+tier.units end end
		lines[#lines+1]=ns.Comma(ahead).." units priced below yours"
		lines[#lines+1]="|cff1eff00You: "..quantity.." at "..ns.Money(saleType=="bids" and bid or unit).." each|r"
		for i=1,math.min(12,#item.tiers) do
			local tier=item.tiers[i]; lines[#lines+1]=tier.copies.." x "..tier.stack.." at "..ns.Money(tier.unit).." each"
		end
		ladder:SetText(table.concat(lines,"\n"))
	end
	function page:Refresh() if Bag() and not custom then Suggest() end; Refresh() end
	function page:Posted(p)
		if p and p.key==selected then auctions=math.max(1,auctions-1); auctionInput:SetText(tostring(auctions)) end
	end
	return page
end

local function BuildResell(parent)
	local page=CreateFrame("Frame",nil,parent); page:SetAllPoints()
	local selected,margin,solid,budget,minimum,limit=nil,30,false,true,5000,1
	local plans={}
	local detail=BuyDetail(page,function() local p=plans[selected]; return p and p.item end,function()
		local p=plans[selected]; return p and p.first and p.first.stack or 1
	end)
	local list
	local function RefreshList()
		plans={}
		local rows={}
		for _,item in ipairs(Market() and Market().items or {}) do
			local plan=ns.Trading:Resell(item,margin,budget and GetMoney() or 0,limit)
			if plan and plan.profit>=minimum and (not solid or ns.Signals:Confidence(item).score>=55) then
				plans[item.key]=plan; rows[#rows+1]=plan
			end
		end
		table.sort(rows,function(a,b) return a.profit>b.profit end)
		list:SetRows(rows,selected)
		detail:Refresh()
	end
	local margins={{id=15,label="15% below usual"},{id=30,label="30% below usual"},{id=50,label="50% below usual"}}
	local drop=W.Dropdown(page,174,margins,margin,function(value) margin=value; RefreshList() end); drop:SetPoint("TOPLEFT",0,0)
	local known=W.Check(page,"Solid prices",false,function(value) solid=value; RefreshList() end); known:SetPoint("TOPLEFT",184,0)
	local goldLimit=W.Check(page,"My gold",true,function(value) budget=value; RefreshList() end); goldLimit:SetPoint("TOPLEFT",323,0)
	W.Label(page,"Minimum profit",6,-43)
	local profit=W.Money(page,minimum,function(value) minimum=value; RefreshList() end); profit:SetPoint("TOPLEFT",101,-37)
	W.Label(page,"Buy up to",347,-43)
	local count=W.Edit(page,65,limit,function(text) limit=math.max(1,math.floor(tonumber(text) or 1)); RefreshList() end,true); count:SetPoint("TOPLEFT",420,-38)
	W.Label(page,"auctions",493,-43)
	list=W.List(page,598,356,{
		{label="Item",width=254,text=function(p) return ItemText(p.item) end},
		{label="Units",width=55,text=function(p) return ns.Comma(p.units) end},
		{label="Cost",width=125,text=function(p) return ns.Money(p.cost) end},
		{label="Profit",width=136,text=function(p) return ns.Money(p.profit) end},
	},function(plan) if not ns.Trade:Cancel() then return end; selected=plan.item.key; RefreshList() end)
	list:SetPoint("TOPLEFT",0,-73)
	local summary=W.Label(page,"",8,-440,575); summary:SetHeight(55); summary:SetJustifyV("TOP")
	function page:Refresh()
		RefreshList()
		local p=plans[selected]
		summary:SetText(p and ("Relist each at "..ns.Money(p.target).."; projected profit "..ns.Money(p.profit).." ("..p.roi.."%).\n"
			..ns.Comma(p.competition).." competing units remain at or below your target. Assumes all units sell, less a 5% cut; excludes deposits.")
			or "Pick a lead to check its current price. Profits are estimates from listed prices.")
	end
	return page
end

function Window:Refresh()
	if not frame or not frame:IsShown() then return end
	gold:SetText(ns.Money(GetMoney()))
	local market=Market()
	if ns.Downloader:IsRunning() then footer:SetText("Scanning...")
	elseif market then footer:SetText(ns.L.WIN_SCAN_AGE:format(ns.Duration(math.max(0,GetServerTime()-market.time)),ns.Comma(market.listings or 0),ns.Comma(ns.History:ScanCount())))
	else footer:SetText(ns.L.WIN_NO_SCAN) end
	if pages[active] then pages[active]:Refresh() end
end

local function Select(id)
	if not pages[id] then id="buy" end
	if active~=id and not ns.Trade:Cancel() then return end
	active=id
	ns.charDb.tradingTab=id
	for key,page in pairs(pages) do page:SetShown(key==id) end
	for key,button in pairs(tabs) do button:SetEnabled(key~=id) end
	Window:Refresh()
end

local function Build()
	frame=W.Panel(UIParent)
	_G.AuctioNitroWindow=frame
	frame:SetSize(900,600); frame:SetPoint("CENTER"); frame:SetFrameStrata("HIGH")
	frame:SetMovable(true); frame:SetClampedToScreen(true); frame:EnableMouse(true)
	local title=W.Label(frame,ns.L.TITLE,14,-13,300,"GameFontNormalLarge")
	local drag=CreateFrame("Frame",nil,frame); drag:SetPoint("TOPLEFT",0,0); drag:SetSize(640,32); drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart",function() frame:StartMoving() end)
	drag:SetScript("OnDragStop",function()
		frame:StopMovingOrSizing()
		local point,_,relative,x,y=frame:GetPoint(); ns.charDb.tradingPosition={point=point,relative=relative,x=x,y=y}
	end)
	local pos=ns.charDb.tradingPosition
	if pos then frame:ClearAllPoints(); frame:SetPoint(pos.point,UIParent,pos.relative,pos.x,pos.y) end
	gold=W.Label(frame,"",400,-15,236); gold:SetJustifyH("RIGHT")
	local scan=W.Button(frame,ns.L.WIN_SCAN,95,function()
		if ns.Downloader:IsRunning() then ns.Downloader:Cancel()
		elseif not ns.Trade:IsBusy() then ns.Trade:Cancel(); ns.Downloader:Start("replicate") end
	end); scan:SetPoint("TOPRIGHT",-151,-8); Tip(scan,ns.L.WIN_SCAN_TIP)
	local data=W.Button(frame,ns.L.WIN_DEBUG,80,function() ns.Panel:Toggle() end); data:SetPoint("TOPRIGHT",-65,-8)
	local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-3)
	body=CreateFrame("Frame",nil,frame); body:SetSize(880,499); body:SetPoint("TOPLEFT",10,-70)
	pages.buy, pages.sell, pages.resell=BuildBuy(body),BuildSell(body),BuildResell(body)
	tabs={}
	for i,entry in ipairs({{id="buy",label="Buy"},{id="sell",label="Sell"},{id="resell",label="Resell"}}) do
		local id=entry.id
		local button=W.Button(frame,entry.label,90,function() Select(id) end)
		button:SetPoint("TOPLEFT",12+(i-1)*94,-38); tabs[id]=button
	end
	footer=W.Label(frame,"",14,-580,860,"GameFontDisableSmall")
	tinsert(UISpecialFrames,"AuctioNitroWindow")
	frame:SetScript("OnShow",function() ns.charDb.tradingShown=true; Window:Refresh() end)
	frame:SetScript("OnHide",function() ns.charDb.tradingShown=false; ns.Trade:Cancel() end)
	local shown=ns.charDb.tradingShown
	frame:Hide()
	Select(ns.charDb.tradingTab or "buy")
	if shown then frame:Show() end
	Bus:On("DOWNLOAD_STATE",function(state)
		scan:SetText(ns.Downloader:IsRunning() and "Cancel scan" or ns.L.WIN_SCAN)
		if frame:IsShown() then footer:SetText(state.phase=="failed" and (ns.L[state.reason] or state.reason or "Scan failed") or "Scanning...") end
		if state.phase=="done" or state.phase=="failed" then Window:Refresh() end
	end)
end
function Window:Show() if frame then frame:Show(); frame:Raise() end end
function Window:Toggle() if frame then frame:SetShown(not frame:IsShown()); if frame:IsShown() then frame:Raise() end end end
Bus:On("READY",Build)
Bus:On("ANALYSIS_READY",function() Window:Refresh() end)
Bus:On("BAGS_CHANGED",function() if frame and frame:IsShown() and active=="sell" then pages.sell:Refresh() end end)
Bus:On("TRADE_CHANGED",function() Window:Refresh() end)
Bus:On("POST_SUCCEEDED",function(post) if pages.sell then pages.sell:Posted(post) end end)
Bus:On("AH_OPENED",function() if ns.IsEnabled("openWithAuctionHouse") then Window:Show() end; Window:Refresh() end)
Bus:On("AH_CLOSED",function() Window:Refresh() end)
local watcher=CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_MONEY")
watcher:SetScript("OnEvent",function() Window:Refresh() end)
