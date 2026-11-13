-- Thin native shell for the lab's 900x600 concept. Each tab owns its layout.
local _,ns=...
local W,C,M,Bus=ns.Widgets,ns.Concept,ns.ConceptModel,ns.Bus
local Window={}; ns.Window=Window
local frame,gold,footer,scan
local pages,tabs={},{}
local active="buy"
local lastDownload
local refreshing=false
local function Market()
	local market=ns.Analysis and ns.Analysis.market
	local place=(GetRealmName() or "?").." / "..(UnitFactionGroup("player") or "?")
	if market and market.place and market.place~=place then return end
	return market
end
local function Empty(fallback)
	local status=ns.AnalysisStatus
	if status and status.phase=="loading" then return "Preparing market data..." end
	if status and status.phase=="error" then return "Market data could not be prepared. Open Data for details." end
	local market=ns.Analysis and ns.Analysis.market
	if market and not Market() then return "Scan belongs to another realm or faction." end
	if not Market() then return "No full scan yet. Open the auction house and press Scan." end
	return fallback
end
local function BuyState(item,label)
	local state=ns.Trade.state
	if state.item and state.item.key==item.key then
		if state.phase=="item" then return "Buy "..state.units.." for "..ns.Money(state.cost),state.message,state.cost end
		if state.phase=="commodity" then return "Get quote for "..state.quantity,state.message,state.cost end
		if state.phase=="quote" then return "Buy "..state.quantity.." for "..ns.Money(state.cost),state.message,state.cost end
	end
	if ns.Trade:IsBusy() then return "Please wait...",state.message end
	if state.phase=="error" or state.phase=="done" then return "Check current price",state.message end
	if not ns.auctionHouseOpen then return "Check current price","Open the auction house to buy." end
	return "Check current price"
end
local function Buy(item,quantity)
	local state=ns.Trade.state
	if state.item and state.item.key==item.key and (state.phase=="item" or state.phase=="commodity" or state.phase=="quote") then ns.Trade:Buy()
	else ns.Trade:Search(item,quantity) end
end
function Window:Refresh()
	if not frame or not frame:IsShown() or refreshing then return end
	refreshing=true
	local market=Market()
	if market and market~=self.prepared then
		self.prepared=market
		for _,item in ipairs(market.items) do
			local median=item.median
			item.deal=(item.listings-item.bidOnly>=3 and median and item.min) and math.floor((median-item.min)/median*100) or nil
		end
	end
	gold:SetText(ns.Money(GetMoney()))
	if pages[active] then pages[active]:Refresh() end
	local status=ns.AnalysisStatus
	local download=lastDownload
	local message
	if ns.Downloader:IsRunning() then message="Scanning..."
	elseif status and status.phase=="loading" then message="Preparing market data..."
	elseif status and status.phase=="error" then message="Market data failed. Open Data for details."
	elseif download and download.phase=="failed" then message=ns.L[download.reason] or download.reason or "Scan failed."
		else message="" end
	footer:SetText(message); scan:SetText(ns.Downloader:IsRunning() and "Cancel scan" or "Scan")
	scan:SetEnabled(not ns.Trade:IsBusy() and (ns.auctionHouseOpen or ns.Downloader:IsRunning()))
	refreshing=false
end
local function Select(id)
	if not pages[id] then id="buy" end
	if active~=id and not ns.Trade:Cancel() then return end
	active=id; ns.charDb.tradingTab=id
	for key,page in pairs(pages) do page:SetShown(key==id) end
	for key,button in pairs(tabs) do button:SetActive(key==id) end
	Window:Refresh()
end
local function Build()
	frame=W.Panel(UIParent,"#120e0a","#8a6a2f"); _G.AuctioNitroWindow=frame
	frame:SetSize(C.window.width,C.window.height); frame:SetPoint("CENTER"); frame:SetFrameStrata("HIGH")
	frame:SetMovable(true); frame:SetClampedToScreen(true); frame:EnableMouse(true)
	local title=CreateFrame("Frame",nil,frame); title:SetPoint("TOPLEFT",2,-2); title:SetSize(896,C.metrics.titleHeight)
	W.Gradient(title,".cw-window .cw-title"); W.Label(title,"AuctioNitro",12,-8,250,13,"accent")
	local drag=CreateFrame("Frame",nil,title); drag:SetPoint("TOPLEFT"); drag:SetSize(590,33); drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart",function() frame:StartMoving() end)
	drag:SetScript("OnDragStop",function()
		frame:StopMovingOrSizing(); local point,_,relative,x,y=frame:GetPoint(); ns.charDb.tradingPosition={point=point,relative=relative,x=x,y=y}
	end)
	local position=ns.charDb.tradingPosition
	if position then frame:ClearAllPoints(); frame:SetPoint(position.point,UIParent,position.relative,position.x,position.y) end
	gold=W.Label(title,"",554,-8,160,12,"muted"); gold:SetJustifyH("RIGHT")
	scan=W.Button(title,"Scan",60,function()
		if ns.Downloader:IsRunning() then ns.Downloader:Cancel()
		elseif not ns.Trade:IsBusy() then ns.Trade:Cancel(); ns.Downloader:Start("replicate") end
	end); scan:SetPoint("TOPRIGHT",-108,-5); scan:SetHeight(23); W.Tip(scan,"Read all current auctions into the market view.")
	local data=W.Button(title,"Data",54,function() ns.Panel:Toggle() end); data:SetPoint("TOPRIGHT",-48,-5); data:SetHeight(23)
	local close=W.Button(title,"x",24,function() frame:Hide() end); close:SetPoint("TOPRIGHT",-10,-5); close:SetHeight(23)
	local tabBar=CreateFrame("Frame",nil,frame); tabBar:SetPoint("TOPLEFT",2,-2-C.metrics.titleHeight); tabBar:SetSize(896,C.metrics.tabsHeight)
	local line=tabBar:CreateTexture(nil,"BACKGROUND"); line:SetPoint("BOTTOMLEFT"); line:SetSize(896,1); W.Paint(line,"line")
	local tabX=8
	for i,entry in ipairs(C.tabs) do
		local id=entry.id; local button=W.Button(tabBar,entry.label,C.metrics.tabWidths[i],function() Select(id) end,"tab")
		button:SetHeight(C.metrics.tabsHeight-7); button:SetPoint("TOPLEFT",tabX,-6); tabs[id]=button; tabX=tabX+C.metrics.tabWidths[i]+2
	end
	local body=CreateFrame("Frame",nil,frame); body:SetSize(880,C.metrics.bodyHeight); body:SetPoint("TOPLEFT",10,-C.metrics.bodyTop)
	local ctx={height=C.metrics.bodyHeight,Market=Market,Find=function(key) local market=Market(); return market and market.byKey[key] end,Empty=Empty,Buy=Buy,BuyState=BuyState}
	pages.buy=ns.ConceptTabs.Buy(body,ctx); pages.sell=ns.ConceptTabs.Sell(body,ctx); pages.resell=ns.ConceptTabs.Resell(body,ctx)
	Window.pages=pages
	-- Only transient progress/errors occupy the unused end of the tab strip.
	footer=W.Label(tabBar,"",300,-17,580,11,"muted"); footer:SetJustifyH("RIGHT")
	tinsert(UISpecialFrames,"AuctioNitroWindow")
	frame:SetScript("OnShow",function() ns.charDb.tradingShown=true; Window:Refresh() end)
	frame:SetScript("OnHide",function() ns.charDb.tradingShown=false; ns.Trade:Cancel() end)
	local shown=ns.charDb.tradingShown; frame:Hide(); Select(ns.charDb.tradingTab or "buy"); if shown then frame:Show() end
end
function Window:Show() if frame then frame:Show(); frame:Raise() end end
function Window:Toggle() if frame then frame:SetShown(not frame:IsShown()); if frame:IsShown() then frame:Raise() end end end
Bus:On("READY",Build)
for _,event in ipairs({"ANALYSIS_READY","ANALYSIS_STATE","TRADE_CHANGED","BAGS_CHANGED"}) do Bus:On(event,function() Window:Refresh() end) end
Bus:On("DOWNLOAD_STATE",function(state) lastDownload=state; Window:Refresh() end)
Bus:On("POST_SUCCEEDED",function(post) if pages.sell then pages.sell:Posted(post); Window:Refresh() end end)
Bus:On("AH_OPENED",function() if ns.IsEnabled("openWithAuctionHouse") then Window:Show() end; Window:Refresh() end)
Bus:On("AH_CLOSED",function() Window:Refresh() end)
local watcher=CreateFrame("Frame"); watcher:RegisterEvent("PLAYER_MONEY"); watcher:SetScript("OnEvent",function() Window:Refresh() end)
