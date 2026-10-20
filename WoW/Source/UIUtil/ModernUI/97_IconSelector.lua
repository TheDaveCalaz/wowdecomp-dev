-- ModernUI: built into the client (not in the original 3.3.5a).
-- The icon grid inside IconSelectorPopupFrameTemplate (template in 90_Templates.xml; the popup's own code is
-- Blizzard's, imported by 96_BlizzardShared.lua). Modern clients build the grid on a scrolling grid list;
-- here it is a fixed grid of buttons that scrolls by rows, with the same interface.

if _G.ModernUIIconSelectorMixin then
	return
end

local BUTTON_SIZE, PADDING = 36, 9

local Selector = {}

function Selector:OnLoad()
	self.buttons = {}
	self.offset = 0
	self.stride = nil
	self:EnableMouseWheel(true)
	self:SetScript("OnMouseWheel", function(frame, delta) frame:ScrollRows(-delta) end)

	local bar = CreateFrame("Slider", nil, self)
	bar:SetWidth(16)
	bar:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -2)
	bar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 2)
	bar:SetOrientation("VERTICAL")
	bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	bar:SetMinMaxValues(0, 0)
	bar:SetValueStep(1)
	bar:SetValue(0)
	bar:SetScript("OnValueChanged", function(_, value)
		value = math.floor(value + 0.5)
		if value ~= self.offset then
			self.offset = value
			self:UpdateSelections()
		end
	end)
	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetTexture(0, 0, 0, 0.4)
	self.ScrollBar = bar
end

function Selector:Layout()
	local width = (self:GetWidth() or 0) - 20
	local height = self:GetHeight() or 0
	local columns = self.stride or math.max(1, math.floor((width + PADDING) / (BUTTON_SIZE + PADDING)))
	local rows = math.max(1, math.floor((height + PADDING) / (BUTTON_SIZE + PADDING)))
	if columns == self.columns and rows == self.rows then
		return
	end
	self.columns, self.rows = columns, rows
	for i = 1, columns * rows do
		local button = self.buttons[i]
		if not button then
			button = CreateFrame("CheckButton", nil, self)
			button:SetWidth(BUTTON_SIZE)
			button:SetHeight(BUTTON_SIZE)
			button.Icon = button:CreateTexture(nil, "ARTWORK")
			button.Icon:SetAllPoints()
			button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
			button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
			button.SetIconTexture = function(b, texture) b.Icon:SetTexture(texture) end
			button.GetIconTexture = function(b) return b.Icon:GetTexture() end
			button:SetScript("OnClick", function(b)
				self:SetSelectedIndex(b.selectionIndex)
				if self.selectedCallback then
					self.selectedCallback(b.selectionIndex, self:GetSelection(b.selectionIndex))
				end
			end)
			self.buttons[i] = button
		end
		local column, row = (i - 1) % columns, math.floor((i - 1) / columns)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", self, "TOPLEFT", column * (BUTTON_SIZE + PADDING), -row * (BUTTON_SIZE + PADDING))
	end
	for i = columns * rows + 1, #self.buttons do
		self.buttons[i]:Hide()
	end
end

function Selector:SetSetupCallback(callback) self.setupCallback = callback end
function Selector:SetSelectedCallback(callback) self.selectedCallback = callback end
function Selector:SetSelectionsDataProvider(getSelection, getNumSelections)
	self.getSelection, self.getNumSelections = getSelection, getNumSelections
	self:UpdateSelections()
end
function Selector:GetSelection(index) return self.getSelection and self.getSelection(index) end
function Selector:GetNumSelections() return self.getNumSelections and self.getNumSelections() or 0 end
function Selector:SetSelectedIndex(index)
	self.selectedIndex = index
	self:UpdateSelections()
end
function Selector:GetSelectedIndex() return self.selectedIndex end
function Selector:AdjustScrollBarOffsets() end
function Selector:SetCustomStride(stride) self.stride = stride self.columns = nil end
function Selector:SetCustomPadding() end
function Selector:ScrollRows(delta)
	local _, maxValue = self.ScrollBar:GetMinMaxValues()
	self.ScrollBar:SetValue(math.max(0, math.min(maxValue, self.offset + delta)))
end
function Selector:ScrollToSelectedIndex()
	if not self.selectedIndex or not self.columns then
		return
	end
	local row = math.floor((self.selectedIndex - 1) / self.columns)
	if row < self.offset or row >= self.offset + self.rows then
		local _, maxValue = self.ScrollBar:GetMinMaxValues()
		self.ScrollBar:SetValue(math.max(0, math.min(maxValue, row)))
	end
end
function Selector:UpdateSelections()
	self:Layout()
	local total = self:GetNumSelections()
	local totalRows = math.ceil(total / self.columns)
	local maxOffset = math.max(0, totalRows - self.rows)
	self.ScrollBar:SetMinMaxValues(0, maxOffset)
	if self.offset > maxOffset then
		self.offset = maxOffset
	end
	for i = 1, self.columns * self.rows do
		local button = self.buttons[i]
		local index = self.offset * self.columns + i
		if index <= total then
			button.selectionIndex = index
			local selection = self:GetSelection(index)
			if self.setupCallback then
				self.setupCallback(button, index, selection)
			else
				button:SetIconTexture(selection)
			end
			button:SetChecked(index == self.selectedIndex)
			button:Show()
		else
			button:Hide()
		end
	end
end
function Selector:OnShow() self:UpdateSelections() end

_G.ModernUIIconSelectorMixin = Selector
_G.ScrollBoxSelectorMixin = _G.ScrollBoxSelectorMixin or Selector

-- Blizzard's icon list joins names to "Interface\Icons\"; this client's macro icon functions give whole
-- paths, so the list gets the names alone.
for _, name in ipairs({ "GetMacroIcons", "GetMacroItemIcons" }) do
	local original = _G[name]
	if original then
		_G[name] = function(list)
			list = list or {}
			local first = #list + 1
			original(list)
			for i = first, #list do
				if type(list[i]) == "string" then
					list[i] = list[i]:gsub("^[Ii][Nn][Tt][Ee][Rr][Ff][Aa][Cc][Ee]\\[Ii][Cc][Oo][Nn][Ss]\\", "")
				end
			end
			return list
		end
	end
end
