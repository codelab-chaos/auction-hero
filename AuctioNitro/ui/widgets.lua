-- Native equivalents of the lab's concept controls. No Blizzard button skin:
-- colors and gradients come from the generated, effective concept stylesheet.
local _, ns = ...
local W = {}; ns.Widgets = W
local C = ns.Concept
local white = "Interface\\Buttons\\WHITE8x8"
local font = "Fonts\\ARIALN.TTF"
function W.Color(value, alpha)
	value = C.palette[value] or value or "#f2e8d5"
	local hex = value:match("#(%x%x%x%x%x%x)") or "f2e8d5"
	return tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255,alpha or 1
end
function W.Paint(texture,color,alpha) texture:SetColorTexture(W.Color(color,alpha)) end
function W.Background(parent,color)
	local t=parent:CreateTexture(nil,"BACKGROUND"); t:SetAllPoints(); W.Paint(t,color); return t
end
function W.Skin(frame,bg,border)
	frame:SetBackdrop({bgFile=white,edgeFile=white,edgeSize=1})
	frame:SetBackdropColor(W.Color(bg or "panel")); frame:SetBackdropBorderColor(W.Color(border or "line"))
end
function W.Panel(parent,bg,border)
	local f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); W.Skin(f,bg,border); return f
end
function W.Gradient(frame,selector)
	local value=(C.styles[selector] or {}).background or ""
	local top,bottom=value:match("(#%x%x%x%x%x%x).-(#%x%x%x%x%x%x)")
	if not top then return end
	if not frame.gradient then
		frame.gradient=frame:CreateTexture(nil,"BACKGROUND",nil,1)
		frame.gradient:SetPoint("TOPLEFT",1,-1); frame.gradient:SetPoint("BOTTOMRIGHT",-1,1)
		frame.gradient:SetColorTexture(1,1,1)
	end
	frame.gradient:SetGradient("VERTICAL",CreateColor(W.Color(bottom)),CreateColor(W.Color(top)))
end
function W.Label(parent,text,x,y,width,size,color)
	local label=parent:CreateFontString(nil,"OVERLAY")
	label:SetFont(font,type(size)=="number" and size or 12)
	label:SetTextColor(W.Color(color or "text")); label:SetJustifyH("LEFT"); label:SetJustifyV("TOP")
	label:SetPoint("TOPLEFT",x or 0,y or 0); if width then label:SetWidth(width) end
	label:SetText(text or ""); return label
end
function W.Tip(frame,text,item)
	frame:EnableMouse(true)
	frame:SetScript("OnEnter",function(self)
		GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
		if item then local value=type(item)=="function" and item() or item; if value and value.link then GameTooltip:SetHyperlink(value.link) else GameTooltip:Hide(); return end
		else GameTooltip:AddLine(type(text)=="function" and text() or text,1,1,1,true) end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
function W.Button(parent,text,width,click,kind)
	local b=CreateFrame("Button",nil,parent,"BackdropTemplate"); b:SetSize(width or 80,24)
	b.label=W.Label(b,"",0,0,nil,12); b.label:ClearAllPoints(); b.label:SetPoint("CENTER"); b:SetFontString(b.label); b:SetText(text or "")
	b.label:SetWidth((width or 80)-12); b.label:SetWordWrap(false)
	b.kind=kind or "toggle"
	function b:SetActive(on)
		self.active=on
		local selector=".cw-window .cw-"..self.kind..(on and ".active" or "")
		local style=C.styles[selector] or {}
		W.Skin(self,"panel",style["border-color"] or (self.kind=="action" and "#d9a441" or (on and "#d9a441" or "#5c4526")))
		W.Gradient(self,selector)
		self.label:SetTextColor(W.Color(style.color or (on and "accent" or "text")))
	end
	b:SetActive(false)
	local hover=b:CreateTexture(nil,"HIGHLIGHT"); hover:SetAllPoints(); W.Paint(hover,"accent",0.07)
	b:SetScript("OnClick",click)
	b:SetScript("OnDisable",function(self) self:SetAlpha(0.45) end)
	b:SetScript("OnEnable",function(self) self:SetAlpha(1) end)
	return b
end
function W.Edit(parent,width,value,change,numeric)
	local e=CreateFrame("EditBox",nil,parent,"BackdropTemplate"); e:SetSize(width,24)
	W.Skin(e,"#0d0a07","#5c4526"); e:SetFont(font,12); e:SetTextColor(W.Color("text"))
	e:SetTextInsets(6,6,0,0); e:SetAutoFocus(false); e:SetNumeric(numeric or false); e:SetText(tostring(value or ""))
	e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
	e:SetScript("OnTextChanged",function(self,user) if user and change then change(self:GetText()) end end)
	return e
end
function W.Check(parent,text,checked,change,width,icon)
	local b=CreateFrame("Button",nil,parent); b:SetSize(width or 156,24)
	b.box=W.Panel(b,"#0d0a07","#5c4526"); b.box:SetSize(12,12); b.box:SetPoint("LEFT",0,0)
	b.mark=W.Label(b.box,"",0,0,12,11,"accent"); b.mark:SetJustifyH("CENTER")
	b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetSize(16,16); b.icon:SetPoint("LEFT",18,0)
	b.label=W.Label(b,text,icon and 38 or 18,-6,math.max(1,(width or 156)-(icon and 38 or 18)),13)
	b.label:SetWordWrap(false)
	function b:SetChecked(on,partial) self.checked=on; self.mark:SetText(on and "x" or (partial and "-" or "")) end
	function b:GetChecked() return self.checked end
	function b:SetIcon(value) self.icon:SetTexture(value); self.icon:SetShown(value~=nil); self.label:ClearAllPoints(); self.label:SetPoint("TOPLEFT",value and 38 or 18,-6) end
	b:SetIcon(icon); b:SetChecked(checked)
	b:SetScript("OnClick",function(self) change(not self.checked) end); return b
end
function W.Money(parent,value,change,compact)
	local f=CreateFrame("Frame",nil,parent); local widths=compact and {36,24,24} or {66,40,40}
	f:SetSize(compact and 126 or 188,24); f.boxes={}
	local function Changed()
		change(math.max(0,f.boxes[1]:GetNumber())*10000+math.min(99,math.max(0,f.boxes[2]:GetNumber()))*100+math.min(99,math.max(0,f.boxes[3]:GetNumber())))
	end
	local x=0
	for i,suffix in ipairs({"g","s","c"}) do
		local box=W.Edit(f,widths[i],0,Changed,true); box:SetPoint("TOPLEFT",x,0); box:SetJustifyH("RIGHT")
		box:SetMaxLetters(i==1 and 8 or 2); f.boxes[i]=box
		W.Label(f,suffix,x+widths[i]+2,-5,10,12,({"#ffd100","#c7c7cf","#e0a273"})[i]); x=x+widths[i]+14
	end
	function f:SetAmount(amount)
		amount=math.max(0,math.floor(amount or 0))
		local parts={math.floor(amount/10000),math.floor(amount/100)%100,amount%100}
		for i,box in ipairs(self.boxes) do if not box:HasFocus() and box:GetText()~=tostring(parts[i]) then box:SetText(parts[i]) end end
	end
	f:SetAmount(value); return f
end
function W.Icon(parent,size)
	local f=W.Panel(parent,"#0d0a07","line"); f:SetSize(size,size)
	f.image=f:CreateTexture(nil,"ARTWORK"); f.image:SetPoint("TOPLEFT",1,-1); f.image:SetPoint("BOTTOMRIGHT",-1,1)
	function f:SetItem(item) self.image:SetTexture(item and item.icon); self.item=item end
	W.Tip(f,nil,function() return f.item end); return f
end
function W.ItemText(item,withIcon)
	local color=ITEM_QUALITY_COLORS[item.quality or 1] or ITEM_QUALITY_COLORS[1]
	local hex=color.hex or "|cffffffff"
	return (withIcon and item.icon and ("|T"..item.icon..":18|t ") or "")..hex..item.name.."|r"
end
local tones={bad="#e0503c",warn="#e8a030",ok="#b8cc3c",good="#40c060"}
function W.Signal(parent,count,withLabel,width)
	local f=CreateFrame("Frame",nil,parent); f:SetSize(width or count*9,16); f.pips={}
	for i=1,count do
		local pip=f:CreateTexture(nil,"ARTWORK"); pip:SetSize(7,11); pip:SetPoint("TOPLEFT",(i-1)*9,-2); f.pips[i]=pip
	end
	if withLabel then f.label=W.Label(f,"",count*9+5,0,(width or 150)-count*9-5,12) end
	function f:SetReading(reading)
		self.reading=reading
		for i,pip in ipairs(self.pips) do
			if i<=reading.level.pips then pip:SetColorTexture(W.Color(tones[reading.level.tone])) else pip:SetColorTexture(1,1,1,0.12) end
		end
		if self.label then self.label:SetText(reading.level.label) end
	end
	W.Tip(f,function() return f.reading and table.concat(f.reading.reasons,"\n") or "" end)
	return f
end
function W.Meter(parent,width)
	local f=CreateFrame("Frame",nil,parent); f:SetSize(width or 228,38)
	f.label=W.Label(f,"Price confidence",0,0,100,11,"muted")
	f.signal=W.Signal(f,4,true,110); f.signal:SetPoint("TOPRIGHT")
	f.facts=W.Label(f,"",0,-19,width or 228,11,"muted"); f.facts:SetWordWrap(false)
	function f:SetItem(item)
		local reading=ns.ConceptModel:Confidence(item); self.reading=reading
		local facts=reading.facts
		self.signal:SetReading(reading)
		self.facts:SetText("auctions: "..ns.Comma(facts.auctions).." | "..(facts.nearUsual and (facts.nearUsual.."%") or "-").." usual | scans: "..facts.scans.." | sales: 0")
	end
	W.Tip(f,function() return f.reading and table.concat(f.reading.reasons,"\n") or "Price confidence" end); return f
end
-- Scroll content uses a fixed number of controls; frame count doesn't grow on refresh.
function W.Scroll(parent,width,height,gutter)
	local f=CreateFrame("ScrollFrame",nil,parent); f:SetSize(width,height)
	f.content=CreateFrame("Frame",nil,f); f.content:SetSize(width-(gutter or 10),height); f:SetScrollChild(f.content)
	f.bar=CreateFrame("Slider",nil,parent); f.bar:SetSize(6,height); f.bar:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0)
	f.bar:SetOrientation("VERTICAL"); f.bar:SetMinMaxValues(0,0); f.bar:SetValueStep(12)
	f.bar:SetThumbTexture(white); f.bar:GetThumbTexture():SetSize(4,24); f.bar:GetThumbTexture():SetVertexColor(W.Color("line"))
	f.bar:SetScript("OnValueChanged",function(_,value) f:SetVerticalScroll(value) end)
	f:EnableMouseWheel(true); f:SetScript("OnMouseWheel",function(_,delta) f.bar:SetValue(math.max(0,math.min(f.maximum or 0,(f.bar:GetValue() or 0)-delta*30))) end)
	function f:SetContentHeight(value)
		self.content:SetHeight(math.max(height,value)); self.maximum=math.max(0,value-height)
		self.bar:SetMinMaxValues(0,self.maximum); self.bar:SetShown(self.maximum>0)
		self.bar:SetValue(math.min(self.maximum,self.bar:GetValue() or 0))
	end
	return f
end
-- A small retained layout helper for text and existing controls in detail panes.
function W.Flow(parent,width)
	local flow={parent=parent,width=width,labels={},used=0,y=0}
	function flow:Reset() self.used=0; self.y=0 end
	function flow:Text(text,size,color,height)
		self.used=self.used+1; local label=self.labels[self.used]
		if not label then label=W.Label(self.parent,"",0,0,self.width); self.labels[self.used]=label end
		label:Show(); label:ClearAllPoints(); label:SetPoint("TOPLEFT",0,-self.y); label:SetWidth(self.width)
		label:SetJustifyH("LEFT"); label:SetWordWrap(true)
		label:SetFont(font,size or 12); label:SetTextColor(W.Color(color or "text")); label:SetText(text)
		label:SetHeight(height or 0)
		local measured=height or math.max((size or 12)+2,label:GetStringHeight() or 14)
		label:SetHeight(measured); self.y=self.y+measured+6; return label
	end
	function flow:Row(left,right,size,color)
		local label=self:Text(left,size,color,18)
		local y=self.y-24; local other=self:Text(right,size,color,18)
		local rightWidth=math.min(self.width*0.65,(other:GetStringWidth() or self.width*0.5)+2)
		other:ClearAllPoints(); other:SetPoint("TOPRIGHT",0,-y); other:SetWidth(rightWidth); other:SetJustifyH("RIGHT"); label:SetWidth(self.width-rightWidth-8)
		label:SetWordWrap(false); other:SetWordWrap(false)
		self.y=self.y-24; return label,other
	end
	function flow:Place(widget,height)
		widget:Show(); widget:ClearAllPoints(); widget:SetPoint("TOPLEFT",0,-self.y); self.y=self.y+(height or widget:GetHeight())+8
	end
	function flow:Finish() for i=self.used+1,#self.labels do self.labels[i]:Hide() end end
	return flow
end
function W.Slider(parent,width,change)
	local f=CreateFrame("Slider",nil,parent,"BackdropTemplate"); f:SetSize(width,18); W.Skin(f,"#0d0a07","line")
	f:SetOrientation("HORIZONTAL"); f:SetMinMaxValues(1,1); f:SetValueStep(1); f:SetObeyStepOnDrag(true)
	f:SetThumbTexture(white); f:GetThumbTexture():SetSize(8,18); f:GetThumbTexture():SetVertexColor(W.Color("accent"))
	f:SetScript("OnValueChanged",function(self,value) if not self.updating then change(math.floor(value+0.5)) end end)
	function f:Update(value,maximum) self.updating=true; self:SetMinMaxValues(1,math.max(1,maximum)); self:SetValue(value); self.updating=false end
	return f
end
function W.Quantity(parent,width,change,all)
	local f=CreateFrame("Frame",nil,parent); f:SetSize(width,24)
	W.Label(f,"Quantity",0,-5,52,11,"muted")
	f.minus=W.Button(f,"-",22,function() change((f.value or 1)-1) end); f.minus:SetPoint("TOPLEFT",54,0)
	f.input=W.Edit(f,46,1,function(text) change(tonumber(text) or 1) end,true); f.input:SetPoint("TOPLEFT",80,0)
	f.plus=W.Button(f,"+",22,function() change((f.value or 1)+1) end); f.plus:SetPoint("TOPLEFT",130,0)
	f.all=W.Button(f,"All",32,all); f.all:SetPoint("TOPLEFT",156,0)
	function f:SetQuantity(value) self.value=value; if not self.input:HasFocus() then self.input:SetText(value) end end
	return f
end
-- Virtual table: only visible rows have frames, even with a full realm scan.
function W.List(parent,width,height,columns,choose,sort)
	local f=W.Panel(parent); f:SetSize(width,height); f.data={}; f.offset=0; f.rows={}; f.headers={}
	local rowHeight,headerHeight=C.metrics.listRow,C.metrics.listHeader
	local fullRows=math.floor((height-headerHeight)/rowHeight)
	local visible=math.ceil((height-headerHeight)/rowHeight); f:SetClipsChildren(true)
	local fixed=0; for _,column in ipairs(columns) do fixed=fixed+(column.width or 0) end
	local firstWidth=width-fixed-C.metrics.listGutter
	local header=CreateFrame("Frame",nil,f); header:SetPoint("TOPLEFT",1,-1); header:SetSize(width-C.metrics.listGutter,headerHeight); W.Background(header,"panel-2")
	local x=0
	for i,column in ipairs(columns) do
		local index=i; local size=column.width or firstWidth
		local b=CreateFrame("Button",nil,header); b:SetSize(size,headerHeight); b:SetPoint("TOPLEFT",x,0)
		b.label=W.Label(b,column.label,6,-7,size-12,11,"accent"); b.label:SetJustifyH(column.align or "LEFT")
		b:SetScript("OnClick",function() if sort then sort(index) end end); f.headers[i]=b
		x=x+size
	end
	f.empty=W.Label(f,"Nothing matches.",10,-40,width-20,12,"muted")
	f.bar=CreateFrame("Slider",nil,f); f.bar:SetPoint("TOPRIGHT",-4,-headerHeight); f.bar:SetSize(6,height-headerHeight-2)
	f.bar:SetOrientation("VERTICAL"); f.bar:SetMinMaxValues(0,0); f.bar:SetValueStep(1); f.bar:SetThumbTexture(white)
	f.bar:GetThumbTexture():SetSize(3,24); f.bar:GetThumbTexture():SetVertexColor(W.Color("line"))
	for i=1,visible do
		local row=CreateFrame("Button",nil,f); row:SetPoint("TOPLEFT",1,-headerHeight-(i-1)*rowHeight); row:SetSize(width-C.metrics.listGutter,rowHeight)
		row.bg=row:CreateTexture(nil,"BACKGROUND"); row.bg:SetAllPoints()
		local hover=row:CreateTexture(nil,"HIGHLIGHT"); hover:SetAllPoints(); W.Paint(hover,"accent",0.07)
		row.texts={}; x=0
		row.signals={}
		for j,column in ipairs(columns) do
			local size=column.width or firstWidth; row.texts[j]=W.Label(row,"",x+6,-5,size-12,13)
			row.texts[j]:SetWordWrap(false); row.texts[j]:SetJustifyH(column.align or "LEFT")
			if column.signal then row.signals[j]=W.Signal(row,5); row.signals[j]:SetPoint("TOPLEFT",x+6,-5) end
			x=x+size
		end
		row:SetScript("OnClick",function(self) if self.value and choose then choose(self.value) end end)
		W.Tip(row,nil,function() return row.value and (row.value.item or row.value) end); f.rows[i]=row
	end
	function f:Draw()
		self.empty:SetShown(#self.data==0)
		for i,row in ipairs(self.rows) do
			local value=self.data[self.offset+i]; row.value=value; row:SetShown(value~=nil)
			if value then
				local item=value.item or value; W.Paint(row.bg,"accent",item.key==self.selected and 0.18 or 0)
				for j,column in ipairs(columns) do
					if column.signal then row.signals[j]:SetReading(column.signal(value)) else row.texts[j]:SetText(column.text(value) or "") end
				end
			end
		end
	end
	function f:SetRows(data,selected,limit,empty)
		local total=#data; self.data={}; for i=1,math.min(total,limit or total) do self.data[i]=data[i] end
		self.selected=selected; self.offset=math.min(self.offset,math.max(0,#self.data-fullRows))
		self.bar:SetMinMaxValues(0,math.max(0,#self.data-fullRows)); self.bar:SetValue(self.offset); self.bar:SetShown(#self.data>fullRows)
		self.empty:SetText(empty or "Nothing matches."); self:Draw()
	end
	function f:SetSort(index,descending)
		for i,headerButton in ipairs(self.headers) do headerButton.label:SetText(columns[i].label..(index==i and (descending and " v" or " ^") or "")) end
	end
	f.bar:SetScript("OnValueChanged",function(_,value) f.offset=math.floor(value+0.5); f:Draw() end)
	f:EnableMouseWheel(true); f:SetScript("OnMouseWheel",function(_,delta) f.bar:SetValue(math.max(0,math.min(math.max(0,#f.data-fullRows),f.offset-delta*3))) end)
	return f
end
function W.Sort(rows,field,descending,read)
	table.sort(rows,function(a,b)
		local av,bv
		if read then av,bv=read(a,field),read(b,field) else av,bv=a[field],b[field] end
		if av==bv then return (a.key or a.item.key)<(b.key or b.item.key) end
		if av==nil then return false elseif bv==nil then return true end
		if descending then return av>bv else return av<bv end
	end)
end
