-- Native frames shared by the trading tabs. Lists reuse visible rows so a
-- 200,000-auction scan does not create one frame per auction.
local _, ns = ...
local W = {}
ns.Widgets = W

function W.Label(parent, text, x, y, width, font)
	local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	label:SetPoint("TOPLEFT", x, y)
	if width then label:SetWidth(width) end
	label:SetJustifyH("LEFT")
	label:SetText(text or "")
	return label
end
function W.Panel(parent)
	local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	f:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=8,
		insets={left=2,right=2,top=2,bottom=2} })
	f:SetBackdropColor(0.07,0.06,0.08,0.98)
	f:SetBackdropBorderColor(0.45,0.36,0.17,1)
	return f
end
function W.Button(parent, text, width, click)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width or 90, 24)
	b:SetText(text)
	b:SetScript("OnClick", click)
	return b
end
function W.Edit(parent, width, value, change, numeric)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetSize(width, 22)
	e:SetAutoFocus(false)
	e:SetNumeric(numeric or false)
	e:SetText(tostring(value or ""))
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	e:SetScript("OnTextChanged", function(self, user) if user and change then change(self:GetText()) end end)
	return e
end
function W.Check(parent, text, checked, change)
	local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	b:SetSize(22,22)
	b:SetChecked(checked)
	local label = W.Label(b, text, 24,-5)
	b:SetScript("OnClick", function(self) change(self:GetChecked()) end)
	b.label = label
	return b
end
function W.Dropdown(parent, width, choices, selected, change)
	local b = W.Button(parent, "", width)
	function b:SetChoice(id)
		self.selected = id
		for _, option in ipairs(choices) do if option.id == id then self:SetText(option.label .. "  |TInterface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up:12|t"); return end end
	end
	function b:SetChoices(nextChoices, id) choices=nextChoices; self:SetChoice(id) end
	b:SetScript("OnClick", function(self)
		if MenuUtil and MenuUtil.CreateContextMenu then
			MenuUtil.CreateContextMenu(self, function(_, root)
				for _, option in ipairs(choices) do
					root:CreateRadio(option.label, function() return self.selected == option.id end,
						function() self:SetChoice(option.id); change(option.id) end)
				end
			end)
		else
			for i, option in ipairs(choices) do
				if option.id == self.selected then local next = choices[i % #choices + 1]; self:SetChoice(next.id); change(next.id); return end
			end
		end
	end)
	b:SetChoice(selected)
	return b
end
function W.Money(parent, value, change)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(225,24)
	f.boxes = {}
	local function Changed()
		change(math.max(0, f.boxes[1]:GetNumber()) * 10000 + math.min(99, math.max(0, f.boxes[2]:GetNumber())) * 100
			+ math.min(99, math.max(0, f.boxes[3]:GetNumber())))
	end
	for i, suffix in ipairs({"g","s","c"}) do
		local width = i == 1 and 72 or 44
		local x = i == 1 and 4 or (i == 2 and 100 or 168)
		local e = W.Edit(f, width, 0, Changed, true)
		e:SetPoint("LEFT", x,0)
		e:SetMaxLetters(i == 1 and 8 or 2)
		W.Label(f,suffix,x+width+3,-5,12)
		f.boxes[i] = e
	end
	function f:SetAmount(amount)
		amount = math.max(0, math.floor(amount or 0))
		self.boxes[1]:SetText(tostring(math.floor(amount/10000)))
		self.boxes[2]:SetText(tostring(math.floor(amount/100)%100))
		self.boxes[3]:SetText(tostring(amount%100))
	end
	f:SetAmount(value)
	return f
end
function W.Meter(parent)
	local f = CreateFrame("Frame",nil,parent)
	f:SetSize(250,45)
	f.label = W.Label(f,"",0,0,250)
	f.facts = W.Label(f,"",0,-20,250,"GameFontDisableSmall")
	local tones = { bad={0.8,0.25,0.2}, warn={0.9,0.65,0.2}, ok={0.6,0.8,0.3}, good={0.2,0.85,0.35} }
	f.pips = {}
	for i=1,4 do
		local pip = f:CreateTexture(nil,"ARTWORK")
		pip:SetSize(9,9); pip:SetPoint("TOPRIGHT",-((4-i)*12),0)
		f.pips[i] = pip
	end
	f:EnableMouse(true)
	f:SetScript("OnEnter",function(self)
		if not self.reading then return end
		GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
		GameTooltip:AddLine(ns.L.CONFIDENCE)
		for _, line in ipairs(self.reading.reasons) do GameTooltip:AddLine(line,1,1,1,true) end
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave",function() GameTooltip:Hide() end)
	function f:SetItem(item)
		local reading = ns.Signals:Confidence(item)
		self.reading = reading
		self.label:SetText(ns.L.CONFIDENCE .. ": " .. reading.level.label)
		self.facts:SetText(ns.Signals:ConfidenceLine(reading))
		for i,pip in ipairs(self.pips) do
			local color = i <= reading.level.pips and tones[reading.level.tone] or {0.2,0.2,0.2}
			pip:SetColorTexture(unpack(color))
		end
	end
	return f
end

-- columns = { { label, width, text=function(row) ... end } }; first column
-- may show the item's icon. Wheel and scrollbar share a single row offset.
function W.List(parent, width, height, columns, choose, sort)
	local f = W.Panel(parent)
	f:SetSize(width,height)
	f.rows, f.data, f.offset, f.selected = {}, {}, 0, nil
	local visible = math.floor((height-29)/25)
	local x = 8
	for i,column in ipairs(columns) do
		local index = i
		local b = CreateFrame("Button",nil,f)
		b:SetSize(column.width,24); b:SetPoint("TOPLEFT",x,-2)
		W.Label(b,column.label,0,-5,column.width,"GameFontNormalSmall")
		if sort then b:SetScript("OnClick",function() sort(index) end) end
		x = x + column.width
	end
	f.empty = W.Label(f,"Nothing matches.",12,-40,width-32,"GameFontDisable")
	f.bar = CreateFrame("Slider",nil,f,"BackdropTemplate")
	f.bar:SetPoint("TOPRIGHT",-3,-28); f.bar:SetPoint("BOTTOMRIGHT",-3,5); f.bar:SetWidth(9)
	f.bar:SetOrientation("VERTICAL"); f.bar:SetMinMaxValues(0,0); f.bar:SetValueStep(1)
	f.bar:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
	f.bar:GetThumbTexture():SetSize(8,26); f.bar:GetThumbTexture():SetVertexColor(0.55,0.45,0.25)
	for i=1,visible do
		local row = CreateFrame("Button",nil,f)
		row:SetPoint("TOPLEFT",6,-27-(i-1)*25); row:SetSize(width-22,24)
		row.bg = row:CreateTexture(nil,"BACKGROUND"); row.bg:SetAllPoints()
		row.texts = {}
		local colX = 2
		for j,column in ipairs(columns) do
			row.texts[j] = W.Label(row,"",colX,-5,column.width-4)
			row.texts[j]:SetWordWrap(false)
			colX = colX + column.width
		end
		row:SetScript("OnClick",function(self) if self.value and choose then choose(self.value) end end)
		row:SetScript("OnEnter",function(self)
			local item = self.value and (self.value.item or self.value)
			if item and item.link then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink(item.link); GameTooltip:Show() end
		end)
		row:SetScript("OnLeave",function() GameTooltip:Hide() end)
		f.rows[i] = row
	end
	function f:Draw()
		self.empty:SetShown(#self.data == 0)
		for i,row in ipairs(self.rows) do
			local value = self.data[self.offset+i]
			row.value = value
			row:SetShown(value ~= nil)
			if value then
				local key = value.key or (value.item and value.item.key)
				row.bg:SetColorTexture(1,0.75,0.25,key == self.selected and 0.2 or (i%2)*0.035)
				for j,column in ipairs(columns) do row.texts[j]:SetText(column.text(value)) end
			end
		end
	end
	function f:SetRows(data, selected)
		self.data, self.selected = data, selected
		local maximum = math.max(0,#data-visible)
		self.offset = math.min(self.offset,maximum)
		self.bar:SetMinMaxValues(0,maximum); self.bar:SetValue(self.offset); self.bar:SetShown(maximum>0)
		self:Draw()
	end
	f.bar:SetScript("OnValueChanged",function(_,value) f.offset=math.floor(value+0.5); f:Draw() end)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel",function(_,delta) f.bar:SetValue(math.max(0,math.min(math.max(0,#f.data-visible),f.offset-delta*3))) end)
	return f
end
