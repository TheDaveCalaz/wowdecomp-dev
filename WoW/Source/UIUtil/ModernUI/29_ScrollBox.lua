-- ModernUI: built into the client (not in the original 3.3.5a).
-- The modern scrolling list (ScrollBox with a linear list view, its scroll bar, ScrollUtil), built on a
-- 3.3.5 ScrollFrame so rows are clipped at the edges. Only the rows in view (and one either side) have
-- frames; frames are reused per template as the list scrolls, as in the modern client.

local _G = _G
if _G.ScrollUtil and _G.CreateScrollBoxListLinearView then
	return
end

local type, pairs, ipairs, select, max, min, floor = type, pairs, ipairs, select, math.max, math.min, math.floor
local CreateFrame_335 = CreateFrame

_G.ScrollBoxConstants = _G.ScrollBoxConstants or {
	UpdateQueued = false, UpdateImmediately = true, RetainScrollPosition = true, DiscardScrollPosition = false,
	AlignBegin = 0, AlignCenter = 0.5, AlignEnd = 1, AlignNearest = -1, NoScrollInterpolation = true, StopIteration = true,
	ContinueIteration = false,
}
_G.SelectionBehaviorFlags = _G.SelectionBehaviorFlags or { Deselectable = 1, Intrusive = 2 }

-- Views ---------------------------------------------------------------------------------------------

local ViewMixin = {}
ViewMixin.__index = ViewMixin

function ViewMixin:SetElementInitializer(template, initializer)
	self.template, self.initializer, self.factory = template, initializer, nil
end
function ViewMixin:SetElementFactory(factory) self.factory = factory end
function ViewMixin:SetElementExtent(extent) self.extent = extent end
function ViewMixin:SetElementExtentCalculator(calculator) self.extentCalculator = calculator end
function ViewMixin:SetElementResetter(resetter) self.resetter = resetter end
function ViewMixin:SetPadding(top, bottom, left, right, spacing)
	self.top, self.bottom, self.left, self.right, self.spacing = top or 0, bottom or 0, left or 0, right or 0, spacing or 0
end
function ViewMixin:SetPanExtent(extent) self.panExtent = extent end
function ViewMixin:GetPanExtent() return self.panExtent or 20 end
function ViewMixin:SetHorizontal(horizontal) self.horizontal = horizontal end
function ViewMixin:IsHorizontal() return false end
function ViewMixin:SetVirtualized() end
function ViewMixin:SetElementIndentCalculator() end
function ViewMixin:SetElementSizeCalculator(calculator)
	self.extentCalculator = function(index, data) local _, h = calculator(index, data) return h end
end
function ViewMixin:GetDataProvider() return self.box and self.box.dataProvider end
function ViewMixin:FindFrame(data) return self.box and self.box:FindFrame(data) end
function ViewMixin:ForEachFrame(fn) if self.box then self.box:ForEachFrame(fn) end end
function ViewMixin:GetFrames() return self.box and self.box:GetFrames() or {} end
function ViewMixin:FindElementDataByPredicate(pred) return self.box and self.box:FindElementDataByPredicate(pred) end
function ViewMixin:Flush() if self.box then self.box:Flush() end end

_G.CreateScrollBoxListLinearView = function(top, bottom, left, right, spacing)
	local view = setmetatable({}, ViewMixin)
	view:SetPadding(top, bottom, left, right, spacing)
	return view
end
_G.CreateScrollBoxListGridView = _G.CreateScrollBoxListLinearView
_G.CreateScrollBoxListTreeView = function(indent, top, bottom, left, right, spacing)
	return _G.CreateScrollBoxListLinearView(top, bottom, left, right, spacing)
end
_G.CreateScrollBoxLinearView = _G.CreateScrollBoxListLinearView

-- Scroll box -------------------------------------------------------------------------------------------

local ScrollBoxMixin = CreateFromMixins(CallbackRegistryMixin)
ScrollBoxMixin.Event = { OnScroll = "OnScroll", OnLayout = "OnLayout", OnAcquiredFrame = "OnAcquiredFrame",
	OnReleasedFrame = "OnReleasedFrame", OnDataRangeChanged = "OnDataRangeChanged", OnAllowScrollChanged = "OnAllowScrollChanged",
	OnSizeChanged = "OnSizeChanged", OnInitializedFrame = "OnInitializedFrame", OnUpdate = "OnUpdate" }

local function setup(box)
	if box.scrollFrame then
		return
	end
	CallbackRegistryMixin.OnLoad(box)
	box:SetUndefinedEventsAllowed(true)
	box.offset = 0
	box.frames = {}      -- data -> frame
	box.pools = {}       -- template -> list of free frames
	box.extents = {}
	local scroll = CreateFrame_335("ScrollFrame", nil, box)
	scroll:SetAllPoints(box)
	local target = CreateFrame_335("Frame", nil, scroll)
	target:SetWidth(1)
	target:SetHeight(1)
	scroll:SetScrollChild(target)
	box.scrollFrame, box.ScrollTarget = scroll, target
	box:EnableMouseWheel(true)
	box:SetScript("OnMouseWheel", function(self, delta)
		self:ScrollInDirection(self:GetPanExtentPercentage(), delta > 0 and -1 or 1)
	end)
	box:HookScript("OnSizeChanged", function(self) self:MarkDirty() end)
	box:HookScript("OnShow", function(self) self:MarkDirty() end)
	box:SetScript("OnUpdate", function(self)
		if self.dirty then
			self.dirty = false
			self:Layout()
		end
	end)
end

function ScrollBoxMixin:Init(view)
	setup(self)
	self.view = view
	view.box = self
	self:MarkDirty()
end
function ScrollBoxMixin:GetView() return self.view end
function ScrollBoxMixin:GetScrollTarget() return self.ScrollTarget end
function ScrollBoxMixin:MarkDirty() self.dirty = true end
function ScrollBoxMixin:FullUpdate() self:Layout() end
function ScrollBoxMixin:Update() self:Layout() end

local function elements(box)
	local provider = box.dataProvider
	if not provider then
		return {}
	end
	if provider.GetCollection then
		return provider:GetCollection()
	end
	return provider.collection or {}
end

function ScrollBoxMixin:SetDataProvider(provider, retainScrollPosition)
	setup(self)
	if self.dataProvider and self.dataProvider.UnregisterCallback then
		self.dataProvider:UnregisterCallback("OnSizeChanged", self)
		self.dataProvider:UnregisterCallback("OnSort", self)
		self.dataProvider:UnregisterCallback("OnFlush", self)
	end
	self.dataProvider = provider
	if provider and provider.RegisterCallback then
		local refresh = function() self:MarkDirty() end
		provider:RegisterCallback("OnSizeChanged", refresh, self)
		provider:RegisterCallback("OnSort", refresh, self)
		provider:RegisterCallback("OnFlush", refresh, self)
	end
	if not retainScrollPosition then
		self.offset = 0
	end
	self:Layout()
end
function ScrollBoxMixin:GetDataProvider() return self.dataProvider end
function ScrollBoxMixin:HasDataProvider() return self.dataProvider ~= nil end
function ScrollBoxMixin:ClearDataProvider() self:SetDataProvider(nil) end
function ScrollBoxMixin:RemoveDataProvider() self:SetDataProvider(nil) end
function ScrollBoxMixin:Flush() self:SetDataProvider(nil) end
function ScrollBoxMixin:GetDataProviderSize() return #elements(self) end

local function extentOf(box, index, data)
	local view = box.view
	if view.extentCalculator then
		return view.extentCalculator(index, data) or 20
	end
	if view.extent then
		return view.extent
	end
	return box.extents[data] or view.measured or 20
end

local function release(box, data, frame)
	box.frames[data] = nil
	frame:Hide()
	frame:ClearAllPoints()
	if box.view.resetter then
		securecall(box.view.resetter, frame, data)
	end
	box:TriggerEvent(ScrollBoxMixin.Event.OnReleasedFrame, frame, data)
	local pool = box.pools[frame.modernTemplate or ""] or {}
	box.pools[frame.modernTemplate or ""] = pool
	pool[#pool + 1] = frame
end

local function acquire(box, template)
	local pool = box.pools[template or ""]
	local frame = pool and table.remove(pool)
	if not frame then
		local ok, made = pcall(CreateFrame, "Button", nil, box.ScrollTarget, template)
		if not ok then
			made = CreateFrame("Button", nil, box.ScrollTarget)
			securecall(error, made and tostring(template) and ("ScrollBox: could not create from template " .. tostring(template)) or "ScrollBox", 0)
		end
		frame = made
		frame.modernTemplate = template
	end
	return frame
end

local function build(box, data, index)
	local view = box.view
	local frame, initializer
	if view.factory then
		view.factory(function(template, init)
			frame = acquire(box, template)
			initializer = init
			return frame
		end, data)
	else
		frame = acquire(box, view.template)
		initializer = view.initializer
	end
	if not frame then
		return nil
	end
	frame:SetParent(box.ScrollTarget)
	frame:Show()
	box.frames[data] = frame
	frame.GetElementData = function() return data end
	frame.GetElementDataIndex = function() return index end
	frame.ElementDataMatches = function(_, other) return other == data end
	frame.GetOrderIndex = function() return index end
	if initializer then
		securecall(initializer, frame, data)
	end
	box:TriggerEvent(ScrollBoxMixin.Event.OnAcquiredFrame, frame, data, true)
	box:TriggerEvent(ScrollBoxMixin.Event.OnInitializedFrame, frame, data)
	if box.alternateRows then
		securecall(box.alternateRows, frame, index % 2 == 0)
	end
	if not view.extent and not view.extentCalculator then
		local h = frame:GetHeight()
		if h and h > 0 then
			box.extents[data] = h
			view.measured = view.measured or h
		end
	end
	return frame
end

function ScrollBoxMixin:Layout()
	setup(self)
	local view = self.view
	if not view then
		return
	end
	local list = elements(self)
	local height = self:GetHeight() or 0
	local width = self:GetWidth() or 0
	local spacing = view.spacing or 0

	-- Positions of every element (cheap: numbers only).
	local positions, y = {}, view.top or 0
	for i, data in ipairs(list) do
		positions[i] = y
		y = y + extentOf(self, i, data) + spacing
	end
	local total = max(0, y - spacing + (view.bottom or 0))
	self.totalExtent = total
	local maxOffset = max(0, total - height)
	if self.offset > maxOffset then
		self.offset = maxOffset
	end
	local top, bottom = self.offset, self.offset + height

	-- Release frames whose element is gone or out of view.
	local wanted = {}
	for i, data in ipairs(list) do
		local y1, y2 = positions[i], positions[i] + extentOf(self, i, data)
		if y2 >= top - 1 and y1 <= bottom + 1 then
			wanted[data] = i
		end
	end
	for data, frame in pairs(self.frames) do
		if not wanted[data] then
			release(self, data, frame)
		end
	end
	-- Place the frames in view.
	self.ScrollTarget:SetWidth(max(1, width))
	self.ScrollTarget:SetHeight(max(1, total))
	for data, i in pairs(wanted) do
		local frame = self.frames[data] or build(self, data, i)
		if frame then
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", self.ScrollTarget, "TOPLEFT", view.left or 0, -positions[i])
			frame:SetPoint("RIGHT", self.ScrollTarget, "RIGHT", -(view.right or 0), 0)
			if view.extent or view.extentCalculator then
				frame:SetHeight(extentOf(self, i, data))
			end
		end
	end
	self.scrollFrame:SetVerticalScroll(self.offset)
	self:TriggerEvent(ScrollBoxMixin.Event.OnLayout)
	self:TriggerEvent(ScrollBoxMixin.Event.OnScroll, self:GetScrollPercentage())
	if self.scrollBar then
		self.scrollBar:SetVisibleExtentPercentage(self:GetVisibleExtentPercentage())
		self.scrollBar:SetScrollPercentage(self:GetScrollPercentage(), true)
	end
end

function ScrollBoxMixin:GetVisibleExtentPercentage()
	local total = self.totalExtent or 0
	if total <= 0 then
		return 1
	end
	return min(1, (self:GetHeight() or 0) / total)
end
function ScrollBoxMixin:HasScrollableExtent() return self:GetVisibleExtentPercentage() < 1 end
function ScrollBoxMixin:GetDerivedScrollRange() return max(0, (self.totalExtent or 0) - (self:GetHeight() or 0)) end
function ScrollBoxMixin:GetScrollPercentage()
	local range = self:GetDerivedScrollRange()
	return range > 0 and self.offset / range or 0
end
function ScrollBoxMixin:SetScrollPercentage(percentage)
	self.offset = max(0, min(1, percentage or 0)) * self:GetDerivedScrollRange()
	self:Layout()
end
function ScrollBoxMixin:GetDerivedScrollOffset() return self.offset end
function ScrollBoxMixin:ScrollToOffset(offset) self.offset = max(0, offset or 0) self:Layout() end
function ScrollBoxMixin:ScrollToBegin() self:SetScrollPercentage(0) end
function ScrollBoxMixin:ScrollToEnd() self:SetScrollPercentage(1) end
function ScrollBoxMixin:GetPanExtentPercentage()
	local range = self:GetDerivedScrollRange()
	return range > 0 and (self.view and self.view:GetPanExtent() or 20) / range or 0
end
function ScrollBoxMixin:ScrollInDirection(percentage, direction)
	self:SetScrollPercentage(self:GetScrollPercentage() + (percentage or 0.1) * direction)
end
function ScrollBoxMixin:ScrollIncrease() self:ScrollInDirection(self:GetPanExtentPercentage(), 1) end
function ScrollBoxMixin:ScrollDecrease() self:ScrollInDirection(self:GetPanExtentPercentage(), -1) end
function ScrollBoxMixin:ScrollToElementData(data, alignment)
	local list = elements(self)
	local y = self.view and self.view.top or 0
	for i, d in ipairs(list) do
		if d == data then
			local extent = extentOf(self, i, d)
			local height = self:GetHeight() or 0
			self:ScrollToOffset(y - (height - extent) * (alignment or 0))
			return self.frames[data]
		end
		y = y + extentOf(self, i, d) + (self.view and self.view.spacing or 0)
	end
end
function ScrollBoxMixin:ScrollToElementDataIndex(index, alignment)
	local data = elements(self)[index]
	if data then
		return self:ScrollToElementData(data, alignment)
	end
end
function ScrollBoxMixin:ScrollToElementDataByPredicate(pred, alignment)
	for _, data in ipairs(elements(self)) do
		if pred(data) then
			return self:ScrollToElementData(data, alignment)
		end
	end
end
function ScrollBoxMixin:FindFrame(data) return self.frames and self.frames[data] end
function ScrollBoxMixin:FindFrameByPredicate(pred)
	for data, frame in pairs(self.frames or {}) do
		if pred(frame, data) then
			return frame
		end
	end
end
function ScrollBoxMixin:FindElementDataByPredicate(pred)
	for _, data in ipairs(elements(self)) do
		if pred(data) then
			return data
		end
	end
end
function ScrollBoxMixin:FindElementDataIndex(data)
	for i, d in ipairs(elements(self)) do
		if d == data then
			return i
		end
	end
end
function ScrollBoxMixin:FindElementData(index) return elements(self)[index] end
function ScrollBoxMixin:ForEachFrame(fn)
	for data, frame in pairs(self.frames or {}) do
		if fn(frame, data) == true then
			return
		end
	end
end
function ScrollBoxMixin:EnumerateFrames()
	local list = {}
	for _, frame in pairs(self.frames or {}) do
		list[#list + 1] = frame
	end
	return ipairs(list)
end
function ScrollBoxMixin:GetFrames()
	local list = {}
	for _, frame in pairs(self.frames or {}) do
		list[#list + 1] = frame
	end
	return list
end
function ScrollBoxMixin:GetFrameCount() return #self:GetFrames() end
function ScrollBoxMixin:ForEachElementData(fn)
	for _, data in ipairs(elements(self)) do
		fn(data)
	end
end
function ScrollBoxMixin:EnumerateDataProvider() return ipairs(elements(self)) end
function ScrollBoxMixin:EnumerateDataProviderEntireRange() return ipairs(elements(self)) end
function ScrollBoxMixin:SetPanExtent(extent) if self.view then self.view:SetPanExtent(extent) end end
function ScrollBoxMixin:SetInterpolateScroll() end
function ScrollBoxMixin:SetAlignmentOverlapIgnored() end
function ScrollBoxMixin:SetEdgeFadeLength() end
function ScrollBoxMixin:EnableEdgeFade() end
function ScrollBoxMixin:IsScrollAllowed() return true end
function ScrollBoxMixin:SetScrollAllowed() end
function ScrollBoxMixin:ScrollToFrame(frame, alignment)
	for data, f in pairs(self.frames or {}) do
		if f == frame then
			return self:ScrollToElementData(data, alignment)
		end
	end
end
function ScrollBoxMixin:Rebuild() self:Layout() end
function ScrollBoxMixin:IsVirtualized() return true end
_G.ScrollBoxListMixin = _G.ScrollBoxListMixin or ScrollBoxMixin
_G.ScrollBoxBaseMixin = _G.ScrollBoxBaseMixin or ScrollBoxMixin
_G.ScrollBoxMixin = _G.ScrollBoxMixin or ScrollBoxMixin

-- Scroll bar -------------------------------------------------------------------------------------------

local ScrollBarMixin = CreateFromMixins(CallbackRegistryMixin)
ScrollBarMixin.Event = { OnScroll = "OnScroll", OnAllowScrollChanged = "OnAllowScrollChanged" }

local function setupBar(bar)
	if bar.slider then
		return
	end
	CallbackRegistryMixin.OnLoad(bar)
	bar:SetUndefinedEventsAllowed(true)
	if (bar:GetWidth() or 0) < 4 then
		bar:SetWidth(16)
	end
	local slider = CreateFrame_335("Slider", nil, bar)
	slider:SetOrientation("VERTICAL")
	slider:SetPoint("TOP", 0, -16)
	slider:SetPoint("BOTTOM", 0, 16)
	slider:SetWidth(16)
	slider:SetMinMaxValues(0, 1)
	slider:SetValueStep(0.001)
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	thumb:SetWidth(18)
	thumb:SetHeight(24)
	thumb:SetTexCoord(0.20, 0.80, 0.125, 0.875)
	slider:SetThumbTexture(thumb)
	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetTexture(0, 0, 0, 0.3)
	slider:SetScript("OnValueChanged", function(_, value)
		if bar.updating then
			return
		end
		bar.percentage = value
		bar:TriggerEvent(ScrollBarMixin.Event.OnScroll, value)
	end)
	local function arrow(point, y, up)
		local b = CreateFrame_335("Button", nil, bar)
		b:SetWidth(16)
		b:SetHeight(16)
		b:SetPoint(point, 0, y)
		local base = up and "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-" or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-"
		b:SetNormalTexture(base .. "Up")
		b:SetPushedTexture(base .. "Down")
		b:SetDisabledTexture(base .. "Disabled")
		b:SetHighlightTexture(base .. "Highlight", "ADD")
		b:SetScript("OnClick", function()
			bar:ScrollStepInDirection(up and -1 or 1)
		end)
		return b
	end
	bar.Back = arrow("TOP", 0, true)
	bar.Forward = arrow("BOTTOM", 0, false)
	bar.slider = slider
	bar.Track = slider
	bar.percentage = 0
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", function(self, delta) self:ScrollStepInDirection(delta > 0 and -1 or 1) end)
end

function ScrollBarMixin:Init() setupBar(self) end
function ScrollBarMixin:SetScrollPercentage(percentage, fromBox)
	setupBar(self)
	self.updating = true
	self.percentage = percentage or 0
	self.slider:SetValue(self.percentage)
	self.updating = false
	if not fromBox then
		self:TriggerEvent(ScrollBarMixin.Event.OnScroll, self.percentage)
	end
end
function ScrollBarMixin:GetScrollPercentage() return self.percentage or 0 end
function ScrollBarMixin:SetVisibleExtentPercentage(percentage)
	setupBar(self)
	self.visible = percentage
	if self.hideIfUnscrollable then
		if percentage >= 1 then self:Hide() else self:Show() end
	end
	if percentage >= 1 then self.slider:Disable() else self.slider:Enable() end
end
function ScrollBarMixin:GetVisibleExtentPercentage() return self.visible or 1 end
function ScrollBarMixin:SetPanExtentPercentage(percentage) self.pan = percentage end
function ScrollBarMixin:GetPanExtentPercentage() return self.pan or 0.1 end
function ScrollBarMixin:ScrollStepInDirection(direction)
	local step = self.box and self.box:GetPanExtentPercentage() or self:GetPanExtentPercentage()
	self:SetScrollPercentage(max(0, min(1, self:GetScrollPercentage() + step * direction)))
end
function ScrollBarMixin:SetHideIfUnscrollable(hide) self.hideIfUnscrollable = hide end
function ScrollBarMixin:SetHideTrackIfThumbExceedsTrack() end
function ScrollBarMixin:HasScrollableExtent() return (self.visible or 1) < 1 end
function ScrollBarMixin:IsScrollAllowed() return true end
function ScrollBarMixin:SetScrollAllowed() end
function ScrollBarMixin:SetInterpolateScroll() end
function ScrollBarMixin:Update() end
_G.ScrollBarMixin = _G.ScrollBarMixin or ScrollBarMixin
_G.MinimalScrollBarMixin = _G.MinimalScrollBarMixin or ScrollBarMixin
_G.WowTrimScrollBarMixin = _G.WowTrimScrollBarMixin or ScrollBarMixin

-- ScrollUtil ------------------------------------------------------------------------------------------

local ScrollUtil = _G.ScrollUtil or {}
_G.ScrollUtil = ScrollUtil

local function asBox(box)
	if not box.Layout or box.Layout ~= ScrollBoxMixin.Layout then
		Mixin(box, ScrollBoxMixin)
	end
	setup(box)
	return box
end
local function asBar(bar)
	if bar.SetVisibleExtentPercentage ~= ScrollBarMixin.SetVisibleExtentPercentage then
		Mixin(bar, ScrollBarMixin)
	end
	setupBar(bar)
	return bar
end

function ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
	asBox(box)
	box:Init(view)
	if bar then
		asBar(bar)
		box.scrollBar, bar.box = bar, box
		bar:RegisterCallback(ScrollBarMixin.Event.OnScroll, function(_, percentage)
			box.offset = max(0, min(1, percentage or 0)) * box:GetDerivedScrollRange()
			box:Layout()
		end, box)
	end
end
ScrollUtil.InitScrollBoxWithScrollBar = ScrollUtil.InitScrollBoxListWithScrollBar
ScrollUtil.InitScrollBoxList = function(box, view) asBox(box) box:Init(view) end
ScrollUtil.RegisterScrollBoxWithScrollBar = function(box, bar)
	asBox(box)
	if bar then
		asBar(bar)
		box.scrollBar, bar.box = bar, box
	end
end
function ScrollUtil.RegisterAlternateRowBehavior(box, callback)
	box.alternateRows = callback
end
function ScrollUtil.AddAcquiredFrameCallback(box, callback, owner)
	asBox(box)
	box:RegisterCallback(ScrollBoxMixin.Event.OnAcquiredFrame, function(_, frame, data, new) callback(owner, frame, data, new) end, owner)
end
function ScrollUtil.AddReleasedFrameCallback(box, callback, owner)
	asBox(box)
	box:RegisterCallback(ScrollBoxMixin.Event.OnReleasedFrame, function(_, frame, data) callback(owner, frame, data) end, owner)
end
function ScrollUtil.AddInitializedFrameCallback(box, callback, owner)
	asBox(box)
	box:RegisterCallback(ScrollBoxMixin.Event.OnInitializedFrame, function(_, frame, data) callback(owner, frame, data) end, owner)
end
function ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar)
	if bar then
		asBar(bar)
		bar:SetHideIfUnscrollable(true)
	end
	return { GetScrollBoxAnchors = function() return {} end }
end
function ScrollUtil.AddResizableChildrenBehavior() end
function ScrollUtil.RegisterTableBuilder() end
function ScrollUtil.AddSelectionBehavior(box, ...)
	local flags = {}
	for i = 1, select("#", ...) do
		flags[select(i, ...)] = true
	end
	local behavior = CreateFromMixins(CallbackRegistryMixin)
	CallbackRegistryMixin.OnLoad(behavior)
	behavior:SetUndefinedEventsAllowed(true)
	behavior.Event = { OnSelectionChanged = "OnSelectionChanged" }
	local selected = {}
	function behavior:IsElementDataSelected(data) return selected[data] == true end
	function behavior:IsSelected(frame) return frame and frame.GetElementData and selected[frame:GetElementData()] == true end
	function behavior:SelectElementData(data)
		if not flags[SelectionBehaviorFlags.Intrusive] then
			for d in pairs(selected) do
				selected[d] = nil
				self:TriggerEvent("OnSelectionChanged", box.FindFrame and box:FindFrame(d), false, d)
			end
		end
		selected[data] = true
		self:TriggerEvent("OnSelectionChanged", box.FindFrame and box:FindFrame(data), true, data)
	end
	function behavior:Select(frame) if frame and frame.GetElementData then self:SelectElementData(frame:GetElementData()) end end
	function behavior:DeselectElementData(data)
		selected[data] = nil
		self:TriggerEvent("OnSelectionChanged", box.FindFrame and box:FindFrame(data), false, data)
	end
	function behavior:ToggleSelect(frame)
		local data = frame and frame.GetElementData and frame:GetElementData()
		if data == nil then return end
		if selected[data] and flags[SelectionBehaviorFlags.Deselectable] then
			self:DeselectElementData(data)
		else
			self:SelectElementData(data)
		end
	end
	function behavior:ToggleSelectElementData(data)
		if selected[data] and flags[SelectionBehaviorFlags.Deselectable] then self:DeselectElementData(data) else self:SelectElementData(data) end
	end
	function behavior:ClearSelections()
		for d in pairs(selected) do
			self:DeselectElementData(d)
		end
	end
	function behavior:GetSelectedElementData()
		for d in pairs(selected) do return d end
	end
	function behavior:GetFirstSelectedElementData() return self:GetSelectedElementData() end
	function behavior:HasSelection() return next(selected) ~= nil end
	function behavior:SelectFirstElementData(pred)
		for _, data in ipairs(elements(box)) do
			if not pred or pred(data) then
				self:SelectElementData(data)
				return data
			end
		end
	end
	function behavior:SelectNextElementData() end
	function behavior:SelectPreviousElementData() end
	function behavior:SetSelectionFlags() end
	return behavior
end
function ScrollUtil.CalculateScrollBoxElementExtent(count, extent, spacing)
	return count * (extent or 0) + max(0, count - 1) * (spacing or 0)
end

-- Frames created from the modern templates become scroll boxes and bars as they are made.
_G.ModernUI_SetupScrollBox = function(frame) asBox(frame) end
_G.ModernUI_SetupScrollBar = function(frame) asBar(frame) end
