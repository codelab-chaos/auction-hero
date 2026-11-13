local ns,frames,Event,Eq=...
local function Visible(frame)
	while frame do if not frame.shown then return false end; frame=frame.parent end
	return true
end
local function Click(label)
	for _,frame in ipairs(frames) do
		if frame.text==label and frame.scripts.OnClick and Visible(frame) then
			assert(frame:IsEnabled(),'disabled control: '..label); frame.scripts.OnClick(frame); return frame
		end
	end
	error('visible control not found: '..label)
end
local function SelectTab(label) return Click(label) end
ns.auctionHouseOpen=true; ns.Trade:Cancel()
local buy=ns.Window.pages.buy
SelectTab('Buy')
Eq(AuctioNitroWindow.width,900); Eq(AuctioNitroWindow.height,600)
Eq(buy.parent.width,880); Eq(buy.parent.height,508.625)
Eq(buy.list.width,396); Eq(buy.list.rows[1].height,25.1875)
local stock=ns.Analysis
local fixtures=assert(loadfile('tests/concept-fixtures.lua'))()
local items,byKey={},{}
for _,fixture in ipairs(fixtures.results) do
	local item=fixture.item; item.itemID=item.id
	if item.name and item.units>0 then items[#items+1]=item; byKey[item.key]=item end
end
ns.Analysis={market={items=items,byKey=byKey,listings=200,time=GetServerTime(),place='Test / Horde'}}
ns.Window:Refresh()
Eq(#buy.list.data,#items)
local armor=Click('Armor'); Click('Weapons')
-- Each header has its own select-all box, separate from its expander.
for _,frame in ipairs(frames) do
	if frame.parent==armor and frame.scripts.OnClick then frame.scripts.OnClick(frame); break end
end
Eq(#buy.list.data,2)
assert(buy.selection.armor['armor:Leather'])
Click('Clear all'); Eq(#buy.list.data,#items)
-- Search and all quick toggles stay in the same center frame.
local search
for _,frame in ipairs(frames) do if frame.kind=='EditBox' and frame.parent==buy.list.parent then search=frame; break end end
assert(search); search:SetText('9001'); search.scripts.OnTextChanged(search,true); Eq(#buy.list.data,1)
search:SetText(''); search.scripts.OnTextChanged(search,true)
local toggled=Click('I can use'); Eq(toggled.active,true); Click('I can use'); Eq(toggled.active,false)
local row=buy.list.rows[1]; row.scripts.OnClick(row); Eq(buy.list.selected,row.value.key)
ns.Analysis=stock; ns.Window:Refresh()
-- Switching tabs keeps selected tabs enabled and gold, rather than disabled.
local selectedTab=SelectTab('Sell'); Eq(selectedTab.active,true); Eq(selectedTab:IsEnabled(),true)
local sell=ns.Window.pages.sell
Eq(#sell.bagButtons,16)
Click('Buy now + bids'); Click('Bids only'); Click('Buy now')
Click('Match'); Click('Undercut'); Click('Quick sale'); Click('Skip lowballs'); Click('Usual price')
Click('Short'); Click('Medium'); Click('Long')
local slots=ns.Inventory.items[1].slots
slots[2]={bag=0,slot=2,count=13}; ns.Inventory.items[1].count=33
ns.Bus:Fire('BAGS_CHANGED')
Eq(sell.bagButtons[1].value.key,sell.bagButtons[2].value.key)
Eq(sell.bagButtons[1].count.text,'20'); Eq(sell.bagButtons[2].count.text,'13')
local lead={key='9500:Lead',itemID=9500,name='Lead',quality=2,classID=7,commodity=false,units=68,listings=20,bidOnly=0,min=4100,median=10000,usual=10000,
	tiers={{unit=4100,stack=7,buyout=29300,copies=2,units=14},{unit=10000,stack=3,buyout=30000,copies=18,units=54}}}
ns.Analysis={market={items={lead},byKey={[lead.key]=lead},time=GetServerTime(),listings=20,place='Test / Horde'}}
SelectTab('Resell'); Click('15%'); Click('50%'); Click('30%')
Click('Top deals'); Click('Top deals'); Click('I can afford'); Click('I can afford')
local resell=ns.Window.pages.resell
Eq(#resell.list.data,1); resell.list.rows[1].scripts.OnClick(resell.list.rows[1]); Eq(resell.list.selected,lead.key)
Click('+'); Click('-'); Click('All')
-- Refreshes reuse the rows, bags, category controls and detail text.
for _,label in ipairs({'Buy','Sell','Resell'}) do
	SelectTab(label); ns.Window:Refresh(); local before=#frames
	for _=1,30 do ns.Window:Refresh() end
	Eq(#frames,before)
end
SelectTab('Buy')
ns.Analysis=nil; ns.AnalysisStatus={phase='loading'}; ns.Window:Refresh()
Eq(buy.list.empty.text,'Preparing market data...')
ns.AnalysisStatus={phase='error'}; ns.Window:Refresh()
Eq(buy.list.empty.text,'Market data could not be prepared. Open Data for details.')
ns.AnalysisStatus={phase='ready'}; ns.Window:Refresh()
Eq(buy.list.empty.text,'No full scan yet. Open the auction house and press Scan.')
ns.Analysis={market={place='Other / Alliance',items=items,byKey=byKey,time=1,listings=1}}; ns.Window:Refresh()
Eq(buy.list.empty.text,'Scan belongs to another realm or faction.'); Eq(#buy.list.data,0)
-- Queue analysis so its loading/error/race behavior is exercised independently.
local queued={}
ns.Jobs={Run=function(_,work,done,fail) local job={work=work,done=done,fail=fail}; queued[#queued+1]=job end}
local snapshot={meta={source='replicate',schema='replicate',time=42,place='Test / Horde'},rows={}}
ns.Store={GetSnapshot=function() return snapshot end,GetSourceSnapshot=function() return snapshot end}
ns.Profile={Run=function() return {} end}; ns.Derive={Run=function() return {} end}; ns.Print=function() end
assert(loadfile('AuctioNitro/analyze/analyzer.lua'))('AuctioNitro',ns)
ns.Analysis=stock
ns.Bus:Fire('SNAPSHOT_CHANGED'); Eq(ns.Analysis,stock); Eq(ns.AnalysisStatus.phase,'loading')
queued[#queued].fail('fixture failure'); Eq(ns.Analysis,stock); Eq(ns.AnalysisStatus.phase,'error')
ns.Bus:Fire('SNAPSHOT_CHANGED'); local obsolete=queued[#queued]
ns.Bus:Fire('SNAPSHOT_CHANGED'); local current=queued[#queued]
obsolete.done({},{},{items={},byKey={}},false); Eq(ns.AnalysisStatus.phase,'loading'); Eq(ns.Analysis,stock)
current.done({},{},{items={},byKey={},time=42,listings=0,place='Test / Horde'},false); Eq(ns.AnalysisStatus.phase,'ready')
snapshot=nil; ns.Bus:Fire('SNAPSHOT_CHANGED'); Eq(ns.Analysis,nil); Eq(ns.AnalysisStatus.phase,'empty')
print('Native UI passed: prototype geometry, independent category expansion/selection, search, tabs, bag grid, sale and rule choices, retained frames, market states and analysis races.')
