-- Headless checks for trading invariants and native frame construction.
unpack=table.unpack; tinsert=table.insert
local frames, timers, calls = {}, {}, {}
local Methods={}
local function Object(name)
	local o=setmetatable({ shown=true, scripts={}, events={}, text="", value=0 },{__index=function(_,key)
		if Methods[key] then return Methods[key] end
		if key:match("^Set") or key:match("^Get") or key:match("^Register") or key:match("^Enable") or key:match("^Clear") or key:match("^Start") or key:match("^Stop") then return function() end end
	end})
	if name then _G[name]=o end
	return o
end
function CreateFrame(kind,name,parent,template) local f=Object(name); f.kind,f.parent,f.template=kind,parent,template; frames[#frames+1]=f; return f end
function Methods:SetScript(key,fn) self.scripts[key]=fn end
function Methods:SetFontString(label) self.fontString=label end
function Methods:SetSize(width,height) self.width,self.height=width,height end
function Methods:SetWidth(width) self.width=width end
function Methods:SetHeight(height) self.height=height end
function Methods:GetWidth() return self.width or 100 end
function Methods:GetHeight() return self.height or 24 end
function Methods:GetValue() return self.value end
function Methods:GetStringHeight() return math.max(14,math.ceil(#self.text*6/(self.width or 200))*14) end
function Methods:GetStringWidth() return #self.text*6 end
function Methods:IsEnabled() return self.enabled~=false end
function Methods:HasFocus() return false end
function CreateColor(...) return {...} end
function Methods:RegisterEvent(event) self.events[event]=true end
function Methods:Show() if not self.shown then self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
function Methods:Hide() if self.shown then self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
function Methods:SetShown(value) if value then self:Show() else self:Hide() end end
function Methods:IsShown() return self.shown end
function Methods:SetText(text) self.text=tostring(text or ""); if self.fontString then self.fontString:SetText(text) end end
function Methods:GetText() return self.text end
function Methods:GetNumber() return tonumber(self.text) or 0 end
function Methods:SetChecked(value) self.checked=value end
function Methods:GetChecked() return self.checked end
function Methods:CreateTexture() return Object() end
function Methods:CreateFontString() return Object() end
function Methods:GetThumbTexture() self.thumb=self.thumb or Object(); return self.thumb end
function Methods:SetMinMaxValues(low,high) self.low,self.high=low,high end
function Methods:SetValue(value)
	value=math.min(self.high or value,math.max(self.low or value,value))
	if self.value~=value then self.value=value; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,value) end end
end
function Methods:GetPoint() return "CENTER",nil,"CENTER",0,0 end
function Methods:SetEnabled(value) self.enabled=value end
function Methods:Raise() end
UIParent=Object(); UISpecialFrames={}; SlashCmdList={}; NUM_BAG_SLOTS=0
ITEM_QUALITY_COLORS={}
for i=0,5 do ITEM_QUALITY_COLORS[i]={hex="|cffffffff"} end
GameTooltip=Object()
C_Timer={After=function(seconds,fn) timers[#timers+1]={seconds,fn} end}
local money=1000000
function GetMoney() return money end
function GetTime() return 100 end
function GetServerTime() return 1794528276 end
function GetRealmName() return "Test" end
function UnitFactionGroup() return "Horde" end
function InCombatLockdown() return false end
Enum={AuctionHouseSortOrder={Price=0},AuctionHouseTimeLeftBand={Short=0,Medium=1,Long=2,VeryLong=3}}
local link="|Hitem:100|h[Ore]|h"
C_Container={GetContainerNumSlots=function() return 1 end, GetContainerItemInfo=function() return {hyperlink=link,stackCount=20,quality=1} end}
ItemLocation={CreateFromBagAndSlot=function(_,bag,slot) return {bag=bag,slot=slot} end}
C_Item={GetItemInfoInstant=function() return 100,"Trade Goods","Metal","",1,7,7 end,GetItemLink=function() return link end}
local commodity=false
local liveItems,liveCommodities={},{}
local quoteRemaining=10
local postConfirm=false
local function Record(name) return function(...) calls[#calls+1]={name,...}; return name=="PostItem" and postConfirm end end
C_AuctionHouse={
	MakeItemKey=function(id) return {itemID=id} end,
	GetItemKeyInfo=function() return {isCommodity=commodity} end,
	GetItemCommodityStatus=function() return commodity and 2 or 1 end,
	IsThrottledMessageSystemReady=function() return true end,
	IsSellItemValid=function() return true end,
	GetAvailablePostCount=function() return 20 end,
	SupportsCopperValues=function() return true end,
	CalculateItemDeposit=function() return 100 end,
	CalculateCommodityDeposit=function() return 100 end,
	GetNumItemSearchResults=function() return #liveItems end,
	GetItemSearchResultInfo=function(_,i) return liveItems[i] end,
	HasFullItemSearchResults=function() return true end,
	GetNumCommoditySearchResults=function() return #liveCommodities end,
	GetCommoditySearchResultInfo=function(_,i) return liveCommodities[i] end,
	HasFullCommoditySearchResults=function() return true end,
	GetQuoteDurationRemaining=function() return quoteRemaining end,
}
for _,name in ipairs({"SendSearchQuery","PlaceBid","StartCommoditiesPurchase","ConfirmCommoditiesPurchase","CancelCommoditiesPurchase",
	"PostItem","PostCommodity","ConfirmPostItem","ConfirmPostCommodity","CancelSell"}) do C_AuctionHouse[name]=Record(name) end
local ns={L={},db={history={items={},folded={},scans=0}},charDb={},auctionHouseOpen=true}
ns.Bus={handlers={}}
function ns.Bus:On(event,handler) self.handlers[event]=self.handlers[event] or {}; table.insert(self.handlers[event],handler) end
function ns.Bus:Fire(event,...) for _,fn in ipairs(self.handlers[event] or {}) do fn(...) end end
ns.Comma=function(n) return tostring(math.floor(n)) end
ns.Money=function(n) return n and tostring(n) or "" end
ns.Duration=function(n) return tostring(n) end
ns.Breathe=function() end
ns.IsEnabled=function() return true end
ns.Downloader={IsRunning=function() return false end}
ns.Panel={Toggle=function() end}
ns.L.TITLE="AuctioNitro"; ns.L.WIN_SCAN="Scan"; ns.L.WIN_DEBUG="Data"; ns.L.WIN_NO_SCAN="No scan"
ns.L.WIN_SCAN_TIP="Scan"; ns.L.WIN_SCAN_AGE="%s %s %s"; ns.L.CONFIDENCE="Confidence"
ns.L.CONFIDENCE_FACTS="%s %s %s %s"; ns.L.REASON_AUCTIONS="%s auctions"; ns.L.REASON_NEAR_USUAL="%s agree"
ns.L.REASON_SCATTERED="%s scattered"; ns.L.REASON_SCANS="%s scans %s days"; ns.L.CONFIDENCE_NO_SHARE="-"
local function Load(path) assert(loadfile("AuctioNitro/"..path))("AuctioNitro",ns) end
local function Event(event,...)
	for _,f in ipairs(frames) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
end
local function Count(name) local n=0; for _,c in ipairs(calls) do if c[1]==name then n=n+1 end end; return n end
local function Eq(actual,expected) assert(actual==expected,tostring(actual).." ~= "..tostring(expected)) end
Load("locales/en-us.lua"); Load("data/trading.lua"); Load("data/catalog.lua"); Load("data/concept.lua")
Load("market/history.lua"); Load("market/signals.lua"); Load("market/trading.lua"); Load("inventory.lua"); Load("trade.lua")
Load("market/concept.lua")
ns.Bus:Fire("INIT")
ns.Inventory:Refresh()
local item={key="100:Ore",itemID=100,name="Ore",link=link,quality=1,units=20,listings=2,bidOnly=0,min=50,median=100,
	tiers={{unit=50,stack=10,buyout=500,copies=1,units=10},{unit=100,stack=10,buyout=1000,copies=1,units=10}}}
local itemResult={auctionID=7,itemLink=link,quantity=10,buyoutAmount=500}
liveItems={itemResult}
ns.Trade:Search(item,1)
Event("ITEM_SEARCH_RESULTS_UPDATED",{itemID=100})
Eq(ns.Trade.state.phase,"item"); Eq(Count("PlaceBid"),0)
ns.Trade:Buy(); Eq(Count("PlaceBid"),1)
ns.Trade:Buy(); Eq(Count("PlaceBid"),1)
Event("AUCTION_HOUSE_PURCHASE_COMPLETED",7); Eq(ns.Trade.state.phase,"done")
ns.Trade:Search(item,1); Event("ITEM_SEARCH_RESULTS_UPDATED",{itemID=100}); itemResult.buyoutAmount=600
ns.Trade:Buy(); Eq(Count("PlaceBid"),1); Eq(ns.Trade.state.phase,"error")
itemResult.buyoutAmount=500
liveItems={{auctionID=8,itemLink="|Hitem:100|h[Different variant]|h",quantity=1,buyoutAmount=1}}
ns.Trade:Search(item,1); Event("ITEM_SEARCH_RESULTS_UPDATED",{itemID=100}); Eq(ns.Trade.state.phase,"error")
commodity=true; liveCommodities={{unitPrice=100,quantity=40,numOwnerItems=0}}
ns.Trade:Search(item,12); Event("COMMODITY_SEARCH_RESULTS_UPDATED",100); Eq(ns.Trade.state.phase,"commodity")
ns.Trade:Buy(); Eq(Count("StartCommoditiesPurchase"),1); Eq(Count("ConfirmCommoditiesPurchase"),0)
Event("COMMODITY_PRICE_UPDATED",101,1212); Eq(ns.Trade.state.phase,"quote"); Eq(Count("ConfirmCommoditiesPurchase"),0)
ns.Trade:Buy(); Eq(Count("ConfirmCommoditiesPurchase"),1)
Event("COMMODITY_PURCHASE_SUCCEEDED"); Eq(ns.Trade.state.phase,"done")
ns.Trade:Search(item,12); Event("COMMODITY_SEARCH_RESULTS_UPDATED",100); ns.Trade:Buy(); Event("COMMODITY_PRICE_UPDATED",100,1200)
quoteRemaining=0; ns.Trade:Buy(); Eq(Count("ConfirmCommoditiesPurchase"),1); Eq(ns.Trade.state.phase,"error")
commodity=false; postConfirm=true
ns.Trade:Post(item.key,10,100,80,3,"both"); Eq(ns.Trade.state.phase,"post-confirm"); Eq(Count("ConfirmPostItem"),0)
ns.Trade:Post(item.key,10,100,80,3,"both"); Eq(Count("ConfirmPostItem"),1)
Event("AUCTION_HOUSE_AUCTION_CREATED",99); Eq(ns.Trade.state.phase,"done")
ns.Trade:Post(item.key,10,100,80,3,"both"); ns.Trade:Post(item.key,10,200,80,3,"both")
Eq(Count("ConfirmPostItem"),1); Eq(ns.Trade.state.phase,"error")
local posts=Count("PostItem")
ns.Trade:Post(item.key,21,100,80,3,"buyout"); Eq(Count("PostItem"),posts)
ns.Trade:Post(item.key,10,100,100,3,"both"); Eq(Count("PostItem"),posts)
ns.auctionHouseOpen=false; ns.Trade:Post(item.key,10,100,80,3,"buyout"); Eq(Count("PostItem"),posts)
ns.auctionHouseOpen=true; money=0; ns.Trade:Post(item.key,10,100,80,3,"buyout"); Eq(Count("PostItem"),posts); money=1000000
local order=ns.Trading:Order(item,12,false); Eq(order.units,20); Eq(order.cost,1500)
order=ns.Trading:Order(item,12,true); Eq(order.units,12); Eq(order.cost,700)
Eq(ns.History:Fold({time=10,place="Test / Horde",items={item}}),true)
Eq(ns.History:Fold({time=10,place="Test / Horde",items={item}}),false)
Eq(ns.History:ScanCount(),1)
Eq(ns.History:Fold({time=11,place="Other / Alliance",items={item}}),true)
Eq(ns.History:ScanCount(),1)
Eq(ns.History:Fold({time=12,place="Test / Horde",items={item},stale=true}),false)
Load("data/schemas.lua"); Load("data/sources.lua"); Load("market/market.lua")
local at=ns.Schemas.replicate.index
local raw={}
for key,value in pairs({name="Ore",itemID=100,count=10,buyoutPrice=500,qualityID=1,usable=true,texture=1}) do raw[at[key]]=value end
local built=ns.Market:Build({meta={source="replicate",schema="replicate",time=20,place="Test / Horde"},rows={raw,raw},items={[100]={type="Trade Goods",subType="Metal",classID=7}}})
Eq(#built.items,1); Eq(built.items[1].tiers[1].copies,2); Eq(built.items[1].units,20)
Eq(built.items[1].min,50); Eq(built.items[1].usable,true); Eq(built.items[1].subType,"Metal")
ns.Analysis={market={items={item},byKey={[item.key]=item},time=GetServerTime(),listings=2}}
Load("ui/widgets.lua"); Load("ui/tabs/buy.lua"); Load("ui/tabs/sell.lua"); Load("ui/tabs/resell.lua"); Load("ui/trading-window.lua")
ns.Bus:Fire("READY"); ns.Window:Show()
assert(AuctioNitroWindow:IsShown())
for _,tab in ipairs({"Sell","Resell","Buy"}) do
	local found=false
	for _,f in ipairs(frames) do if f.text==tab and f.scripts.OnClick then f.scripts.OnClick(f); found=true; break end end
	assert(found,"missing tab "..tab)
end
for _,f in ipairs(frames) do if f.text=="Sell" and f.scripts.OnClick then f.scripts.OnClick(f); break end end
local picked=false
for _,f in ipairs(frames) do
	if type(f.value)=="table" and f.value.key==item.key and f.value.count and f.scripts.OnClick then
		f.scripts.OnClick(f); picked=true; break
	end
end
assert(picked,"bag item selection was not constructed")
ns.Bus:Fire("AH_CLOSED"); Eq(ns.Trade.state.phase,"idle")
print("Addon checks passed: live searches, variant/price guards, commodity quotes, post confirmations, validation, order math, and native window/tabs.")
assert(loadfile('tests/concept.lua'))(ns)
assert(loadfile('tests/native-ui.lua'))(ns,frames,Event,Eq)
