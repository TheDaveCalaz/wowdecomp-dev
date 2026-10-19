-- ModernUI: built into the client (not in the original 3.3.5a).
-- Functions found missing by scanning the AddOns in use (Bagnon, WeakAuras, DBM, Plater, Pawn,
-- Narcissus, Plumber, DialogueUI, Questie), on this client's own functions where it has them.

local _G = _G
local type, select, pairs, ipairs, tostring, tonumber, format = type, select, pairs, ipairs, tostring, tonumber, string.format

local function define(name, value)
	if _G[name] == nil then
		_G[name] = value
	end
end
local function noop() end

-- hooksecurefunc -------------------------------------------------------------------------------------
-- Hooking a function this client does not have raised an error, which stopped the rest of the AddOn's
-- start-up (Bagnon hooks ToggleAllBags, Plater a nameplate driver). A missing target is created as an
-- empty function first, so the hook is set and the AddOn carries on; a missing table is skipped.

do
	local hooksecurefunc_335 = hooksecurefunc
	_G.hooksecurefunc = function(a, b, c)
		if type(a) == "string" then
			if _G[a] == nil then
				_G[a] = noop
			end
			return hooksecurefunc_335(a, b)
		end
		if c == nil and type(a) ~= "table" then
			return
		end
		if type(a) ~= "table" then
			return
		end
		if a[b] == nil then
			a[b] = noop
		end
		return hooksecurefunc_335(a, b, c)
	end
end

-- Tables -------------------------------------------------------------------------------------------

define("FindInTable", function(tbl, value)
	for k, v in pairs(tbl) do
		if v == value then
			return k
		end
	end
end)

define("FindInTableIf", function(tbl, pred)
	for k, v in pairs(tbl) do
		if pred(v) then
			return k, v
		end
	end
end)

define("AccumulateOp", function(tbl, op)
	local total = 0
	for _, v in pairs(tbl) do
		total = total + (op(v) or 0)
	end
	return total
end)

define("DoesAncestryInclude", function(ancestry, frame)
	while frame do
		if frame == ancestry then
			return true
		end
		frame = frame.GetParent and frame:GetParent()
	end
	return false
end)

define("ExecuteFrameScript", function(frame, script, ...)
	local handler = frame and frame.GetScript and frame:GetScript(script)
	if handler then
		return handler(frame, ...)
	end
end)

-- Data providers (a list that tells listeners when it changes) ----------------------------------

if _G.DataProviderMixin == nil then
	local DataProviderMixin = {}
	function DataProviderMixin:Init(tbl)
		self.collection = {}
		self.callbacks = {}
		if tbl then
			for _, v in ipairs(tbl) do
				self.collection[#self.collection + 1] = v
			end
		end
	end
	function DataProviderMixin:RegisterCallback(event, func, owner)
		self.callbacks[#self.callbacks + 1] = { event = event, func = func, owner = owner }
	end
	function DataProviderMixin:UnregisterCallback(event, owner)
		for i = #self.callbacks, 1, -1 do
			if self.callbacks[i].event == event and self.callbacks[i].owner == owner then
				table.remove(self.callbacks, i)
			end
		end
	end
	function DataProviderMixin:TriggerEvent(event, ...)
		for _, cb in ipairs(self.callbacks) do
			if cb.event == event then
				securecall(cb.func, cb.owner, ...)
			end
		end
	end
	function DataProviderMixin:Insert(...)
		for i = 1, select("#", ...) do
			self.collection[#self.collection + 1] = (select(i, ...))
		end
		self:TriggerEvent("OnSizeChanged")
	end
	function DataProviderMixin:InsertTable(tbl)
		for _, v in ipairs(tbl) do
			self.collection[#self.collection + 1] = v
		end
		self:TriggerEvent("OnSizeChanged")
	end
	function DataProviderMixin:Remove(value)
		for i = #self.collection, 1, -1 do
			if self.collection[i] == value then
				table.remove(self.collection, i)
			end
		end
		self:TriggerEvent("OnSizeChanged")
	end
	function DataProviderMixin:Flush()
		self.collection = {}
		self:TriggerEvent("OnFlush")
	end
	function DataProviderMixin:GetSize() return #self.collection end
	function DataProviderMixin:IsEmpty() return #self.collection == 0 end
	function DataProviderMixin:Find(index) return self.collection[index] end
	function DataProviderMixin:FindIndex(value)
		for i, v in ipairs(self.collection) do
			if v == value then
				return i, v
			end
		end
	end
	function DataProviderMixin:FindElementDataByPredicate(pred)
		for _, v in ipairs(self.collection) do
			if pred(v) then
				return v
			end
		end
	end
	function DataProviderMixin:Enumerate() return ipairs(self.collection) end
	function DataProviderMixin:ForEach(func)
		for _, v in ipairs(self.collection) do
			func(v)
		end
	end
	function DataProviderMixin:GetCollection() return self.collection end
	function DataProviderMixin:SetSortComparator(comparator) self.sortComparator = comparator self:Sort() end
	function DataProviderMixin:Sort()
		if self.sortComparator then
			table.sort(self.collection, self.sortComparator)
			self:TriggerEvent("OnSort")
		end
	end
	_G.DataProviderMixin = DataProviderMixin
end
define("CreateDataProvider", function(tbl)
	local provider = CreateFromMixins(DataProviderMixin)
	provider:Init(tbl)
	return provider
end)

-- Bags ------------------------------------------------------------------------------------------------

define("ToggleAllBags", function()
	local open = false
	for i = 1, NUM_CONTAINER_FRAMES or 13 do
		local frame = _G["ContainerFrame" .. i]
		if frame and frame:IsShown() then
			open = true
			break
		end
	end
	if open then
		CloseAllBags()
	else
		OpenAllBags()
	end
end)
define("IsReagentBankUnlocked", function() return false end)
define("CanUseVoidStorage", function() return false end)
define("GetNumVoidTransferDeposit", function() return 0 end)
define("GetNumVoidTransferWithdrawal", function() return 0 end)
define("GetVoidItemInfo", function() return nil end)
define("BattlePetToolTip_Show", noop)
define("IsBagOpen", function(bag)
	for i = 1, NUM_CONTAINER_FRAMES or 13 do
		local frame = _G["ContainerFrame" .. i]
		if frame and frame:IsShown() and frame:GetID() == bag then
			return i
		end
	end
end)

-- Tooltip helpers ---------------------------------------------------------------------------------

local function colourOf(color, r, g, b)
	if type(color) == "table" then
		return color.r or color[1] or r, color.g or color[2] or g, color.b or color[3] or b
	end
	return r, g, b
end
define("GameTooltip_SetTitle", function(tooltip, text, color, wrap)
	local r, g, b = colourOf(color, 1, 1, 1)
	tooltip:SetText(text, r, g, b, 1, wrap ~= false)
end)
define("GameTooltip_AddColoredLine", function(tooltip, text, color, wrap)
	local r, g, b = colourOf(color, 1, 1, 1)
	tooltip:AddLine(text, r, g, b, wrap ~= false)
end)
define("GameTooltip_AddNormalLine", function(tooltip, text, wrap)
	tooltip:AddLine(text, 1, 0.82, 0, wrap ~= false)
end)
define("GameTooltip_AddHighlightLine", function(tooltip, text, wrap)
	tooltip:AddLine(text, 1, 1, 1, wrap ~= false)
end)
define("GameTooltip_AddInstructionLine", function(tooltip, text, wrap)
	tooltip:AddLine(text, 0, 1, 0, wrap ~= false)
end)
define("GameTooltip_AddErrorLine", function(tooltip, text, wrap)
	tooltip:AddLine(text, 1, 0.1, 0.1, wrap ~= false)
end)
define("GameTooltip_AddDisabledLine", function(tooltip, text, wrap)
	tooltip:AddLine(text, 0.5, 0.5, 0.5, wrap ~= false)
end)
define("GameTooltip_AddBlankLineToTooltip", function(tooltip)
	tooltip:AddLine(" ")
end)
define("GameTooltip_AddBlankLinesToTooltip", function(tooltip, count)
	for _ = 1, count or 1 do
		tooltip:AddLine(" ")
	end
end)
define("GameTooltip_Hide", function() GameTooltip:Hide() end)
define("SharedTooltip_SetBackdropStyle", noop)
define("SharedTooltip_ClearInsertedFrames", noop)
define("GameTooltip_ClearInsertedFrames", noop)
define("GameTooltip_ClearMoney", noop)
define("GameTooltip_ClearStatusBars", noop)
define("GameTooltip_ClearProgressBars", noop)
define("GameTooltip_ClearWidgetSet", noop)

-- Game state ----------------------------------------------------------------------------------------

define("GetMinimapShape", function() return "ROUND" end)
define("GetMaxPlayerLevel", function() return MAX_PLAYER_LEVEL or 80 end)
define("GetTimePreciseSec", function() return debugprofilestop() / 1000 end)
define("FlashClientIcon", noop)
define("PlayerGetTimerunningSeasonID", function() return nil end)
define("GetUnitEmpowerHoldAtMaxTime", function() return 0 end)
define("HaveQuestData", function() return true end)
define("HaveQuestRewardData", function() return true end)
define("strcmputf8i", function(a, b)
	a, b = tostring(a):lower(), tostring(b):lower()
	if a < b then return -1 elseif a > b then return 1 end
	return 0
end)

define("GetQuestLogIndexByID", function(questID)
	for i = 1, GetNumQuestLogEntries() do
		local _, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(i)
		if not isHeader and id == questID then
			return i
		end
	end
	return nil
end)

define("UnitTokenFromGUID", function(guid)
	if not guid then
		return nil
	end
	for _, unit in ipairs({ "player", "target", "focus", "pet", "mouseover", "targettarget" }) do
		if UnitGUID(unit) == guid then
			return unit
		end
	end
	for i = 1, 4 do
		if UnitGUID("party" .. i) == guid then return "party" .. i end
	end
	for i = 1, 40 do
		if UnitGUID("raid" .. i) == guid then return "raid" .. i end
	end
	return nil
end)

define("GetAverageItemLevel", function()
	local total, count = 0, 0
	for slot = 1, 18 do
		if slot ~= 4 then
			local link = GetInventoryItemLink("player", slot)
			if link then
				local _, _, _, level = GetItemInfo(link)
				if level then
					total = total + level
					count = count + 1
				end
			end
		end
	end
	local average = count > 0 and total / count or 0
	return average, average, average
end)

define("FormatShortDate", function(day, month, year)
	if year then
		return format("%02d/%02d/%02d", day, month, year % 100)
	end
	return format("%02d/%02d", day, month)
end)

-- Macro icons, from this client's macro icon list.
local function macroIcons(items)
	local icons = {}
	local count = items and (GetNumMacroItemIcons and GetNumMacroItemIcons() or 0) or (GetNumMacroIcons and GetNumMacroIcons() or 0)
	local get = items and GetMacroItemIconInfo or GetMacroIconInfo
	if get then
		for i = 1, count do
			icons[#icons + 1] = get(i)
		end
	end
	return icons
end
define("GetMacroIcons", function(tbl)
	tbl = tbl or {}
	for _, icon in ipairs(macroIcons(false)) do tbl[#tbl + 1] = icon end
	return tbl
end)
define("GetMacroItemIcons", function(tbl)
	tbl = tbl or {}
	for _, icon in ipairs(macroIcons(true)) do tbl[#tbl + 1] = icon end
	return tbl
end)
define("GetLooseMacroIcons", function(tbl) return tbl or {} end)
define("GetLooseMacroItemIcons", function(tbl) return tbl or {} end)

-- Pixel-exact sizing (no UI scale rounding here) ----------------------------------------------------

if _G.PixelUtil == nil then
	_G.PixelUtil = {
		GetPixelToUIUnitFactor = function() return 768 / (select(2, GetPhysicalScreenSize and GetPhysicalScreenSize() or 768)) end,
		GetNearestPixelSize = function(size) return size end,
		SetWidth = function(region, width) region:SetWidth(width) end,
		SetHeight = function(region, height) region:SetHeight(height) end,
		SetSize = function(region, width, height) region:SetWidth(width) region:SetHeight(height) end,
		SetPoint = function(region, point, relativeTo, relativePoint, x, y) region:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0) end,
		SetStatusBarValue = function(bar, value) bar:SetValue(value) end,
	}
end

-- Colour picker: the modern way to open it -------------------------------------------------------

if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow == nil then
	function ColorPickerFrame:SetupColorPickerAndShow(info)
		self.func = info.swatchFunc
		self.hasOpacity = info.hasOpacity
		self.opacityFunc = info.opacityFunc
		self.opacity = info.opacity and (1 - info.opacity) or 0
		self.previousValues = { r = info.r, g = info.g, b = info.b, a = info.opacity, opacity = info.opacity }
		self.cancelFunc = info.cancelFunc and function() info.cancelFunc(self.previousValues) end or nil
		self:SetColorRGB(info.r or 1, info.g or 1, info.b or 1)
		ShowUIPanel(self)
	end
	function ColorPickerFrame:GetColorAlpha()
		if OpacitySliderFrame then
			return 1 - OpacitySliderFrame:GetValue()
		end
		return 1
	end
	function ColorPickerFrame:GetPreviousValues()
		local p = self.previousValues or {}
		return p.r, p.g, p.b, p.a
	end
	ColorPickerFrame.Content = ColorPickerFrame.Content or { ColorPicker = ColorPickerFrame }
end

-- Vector normalising ----------------------------------------------------------------------------------

if Vector2DMixin and Vector2DMixin.Normalize == nil then
	function Vector2DMixin:Normalize()
		local length = self:GetLength()
		if length > 0 then
			self:ScaleBy(1 / length)
		end
	end
end
if Vector3DMixin and Vector3DMixin.Normalize == nil then
	function Vector3DMixin:Normalize()
		local length = self:GetLength()
		if length > 0 then
			self:ScaleBy(1 / length)
		end
	end
end

-- Namespaces for systems this client lacks, answered as "nothing there" ------------------------------

local function namespace(name)
	local ns = _G[name]
	if not ns then
		ns = {}
		_G[name] = ns
	end
	return function(key, fn)
		if ns[key] == nil then
			ns[key] = fn
		end
	end
end
local nilFn = function() return nil end
local falseFn = function() return false end
local emptyFn = function() return {} end

do
	local set = namespace("C_Transmog")
	set("GetSlotVisualInfo", nilFn)
	set("GetSlotInfo", nilFn)
	set("SetPending", noop)
	set("GetItemIDForSource", nilFn)
	set("CanTransmogItem", falseFn)
	set("IsAtTransmogNPC", falseFn)
	set("GetPending", nilFn)
end
do
	local set = namespace("C_TransmogCollection")
	set("GetAppearanceCameraIDBySource", function() return 0 end)
	set("GetItemInfo", nilFn)
	set("GetSourceInfo", nilFn)
	set("PlayerHasTransmog", falseFn)
	set("PlayerHasTransmogByItemInfo", falseFn)
	set("GetAppearanceSourceInfo", nilFn)
end
do
	local set = namespace("C_CVar")
	set("GetCVarBitfield", function(name, index)
		local value = tonumber(GetCVar(name)) or 0
		return bit.band(value, 2 ^ (index - 1)) ~= 0
	end)
	set("SetCVarBitfield", function(name, index, on)
		local value = tonumber(GetCVar(name))
		if not value then
			return false
		end
		local flag = 2 ^ (index - 1)
		if on then
			value = bit.bor(value, flag)
		else
			value = bit.band(value, bit.bnot(flag))
		end
		SetCVar(name, value)
		return true
	end)
end
do
	local set = namespace("C_DateAndTime")
	set("GetWeeklyResetStartTime", function()
		local now = time()
		return now - (now % 604800)
	end)
	set("GetSecondsUntilWeeklyReset", function()
		local now = time()
		return 604800 - (now % 604800)
	end)
	set("GetSecondsUntilDailyReset", function() return GetQuestResetTime and GetQuestResetTime() or 0 end)
end
do
	local set = namespace("C_MountJournal")
	set("GetMountFromItem", nilFn)
	set("GetMountFromSpell", nilFn)
end
do
	local set = namespace("C_PetJournal")
	set("GetPetInfoByItemID", nilFn)
end
do
	local set = namespace("C_QuestLine")
	set("GetQuestLineInfo", nilFn)
	set("GetQuestLineQuests", emptyFn)
	set("GetAvailableQuestLines", emptyFn)
end
do
	local set = namespace("C_TaskQuest")
	set("GetQuestInfoByQuestID", nilFn)
	set("GetQuestsForPlayerByMapID", emptyFn)
	set("GetQuestsOnMap", emptyFn)
	set("IsActive", falseFn)
	set("GetQuestProgressBarInfo", nilFn)
end
do
	local set = namespace("C_ContentTracking")
	set("GetTrackedIDs", emptyFn)
	set("IsTracking", falseFn)
end
do
	local set = namespace("C_TradeSkillUI")
	set("GetProfessionInfoBySkillLineID", nilFn)
	set("GetTradeSkillLine", nilFn)
end
do
	local set = namespace("C_UIWidgetManager")
	set("GetScenarioHeaderDelvesWidgetVisualizationInfo", nilFn)
	set("GetStatusBarWidgetVisualizationInfo", nilFn)
	set("GetIconAndTextWidgetVisualizationInfo", nilFn)
	set("GetTextWithStateWidgetVisualizationInfo", nilFn)
	set("GetAllWidgetsBySetID", emptyFn)
	set("GetTopCenterWidgetSetID", function() return 0 end)
	set("GetBelowMinimapWidgetSetID", function() return 0 end)
	set("GetPowerBarWidgetSetID", function() return 0 end)
end
do
	local set = namespace("C_EncounterJournal")
	set("GetSectionInfo", nilFn)
	set("GetEncounterJournalLink", nilFn)
end

-- Bags and item buttons ---------------------------------------------------------------------------------

do
	local set = namespace("C_NewItems")
	set("IsNewItem", falseFn)
	set("RemoveNewItem", noop)
	set("ClearAll", noop)
end
do
	local set = namespace("C_Container")
	set("IsBattlePayItem", falseFn)
end

define("SetItemButtonQuality", function(button, quality, itemIDOrLink)
	local border = button and button.IconBorder
	if not border then
		return
	end
	if quality and quality >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
		local c = ITEM_QUALITY_COLORS[quality]
		border:SetVertexColor(c.r, c.g, c.b)
		border:Show()
	else
		border:Hide()
	end
end)
define("ClearItemButtonOverlay", function(button)
	if button.IconOverlay then button.IconOverlay:Hide() end
	if button.IconOverlay2 then button.IconOverlay2:Hide() end
end)
define("SetItemButtonOverlay", noop)
define("ContainerFrameUtil_ConvertFilterFlagsToList", function() return {} end)
define("GetValueOrCallFunction", function(tbl, key, ...)
	local value = tbl[key]
	if type(value) == "function" then
		return value(...)
	end
	return value
end)

-- Minimise / maximise button pair ------------------------------------------------------------------

if _G.MaximizeMinimizeButtonFrameMixin == nil then
	local mixin = {}
	function mixin:OnShow()
		if self.isMinimized then self:SetMinimizedLook() else self:SetMaximizedLook() end
	end
	function mixin:SetOnMaximizedCallback(callback) self.maximizedCallback = callback end
	function mixin:SetOnMinimizedCallback(callback) self.minimizedCallback = callback end
	function mixin:IsMinimized() return self.isMinimized == true end
	function mixin:Maximize(skipCallback)
		self.isMinimized = false
		if self.maximizedCallback and not skipCallback then self.maximizedCallback(self) end
		self:SetMaximizedLook()
	end
	function mixin:Minimize(skipCallback)
		self.isMinimized = true
		if self.minimizedCallback and not skipCallback then self.minimizedCallback(self) end
		self:SetMinimizedLook()
	end
	function mixin:SetMinimizedLook()
		if self.MaximizeButton then self.MaximizeButton:Show() end
		if self.MinimizeButton then self.MinimizeButton:Hide() end
	end
	function mixin:SetMaximizedLook()
		if self.MaximizeButton then self.MaximizeButton:Hide() end
		if self.MinimizeButton then self.MinimizeButton:Show() end
	end
	_G.MaximizeMinimizeButtonFrameMixin = mixin
end

-- Scrolling edit boxes: an edit box whose cursor has not moved yet has no cursor offset, and the
-- 3.3.5 update then fails every frame. Start it at the top.
if ScrollingEdit_OnUpdate then
	local ScrollingEdit_OnUpdate_335 = ScrollingEdit_OnUpdate
	_G.ScrollingEdit_OnUpdate = function(self, elapsed, scrollFrame)
		if self.cursorOffset == nil then
			self.cursorOffset = 0
		end
		if self.cursorHeight == nil then
			self.cursorHeight = 0
		end
		return ScrollingEdit_OnUpdate_335(self, elapsed, scrollFrame)
	end
end

-- Cooldowns -----------------------------------------------------------------------------------------

define("CooldownFrame_Set", function(cooldown, start, duration, enable, forceShowDrawEdge, modRate)
	if not cooldown then
		return
	end
	if enable and enable ~= 0 and start and start > 0 and duration and duration > 0 then
		cooldown:SetCooldown(start, duration)
		cooldown:Show()
	else
		cooldown:SetCooldown(0, 0)
		cooldown:Hide()
	end
end)
define("CooldownFrame_Clear", function(cooldown)
	if cooldown then
		cooldown:SetCooldown(0, 0)
		cooldown:Hide()
	end
end)

-- Item button helpers that also work on unnamed buttons ----------------------------------------------
-- The 3.3.5 versions find a button's parts by its name; modern buttons are often unnamed and keep
-- their parts by key (icon, Count, Stock, NormalTexture...).

do
	local function part(button, key, suffix)
		local value = rawget(button, key)
		if value then
			return value
		end
		local name = button:GetName()
		return name and _G[name .. suffix]
	end
	_G.SetItemButtonCount = function(button, count)
		if not button then
			return
		end
		count = count or 0
		button.count = count
		local text = part(button, "Count", "Count")
		if not text then
			return
		end
		if count > 1 or (button.isBag and count > 0) then
			if count > (button.maxDisplayCount or 9999) then
				count = "*"
			end
			text:SetText(count)
			text:Show()
		else
			text:Hide()
		end
	end
	_G.SetItemButtonStock = function(button, numInStock)
		if not button then
			return
		end
		numInStock = numInStock or 0
		button.numInStock = numInStock
		local text = part(button, "Stock", "Stock")
		if not text then
			return
		end
		if numInStock > 0 then
			text:SetFormattedText(MERCHANT_STOCK, numInStock)
			text:Show()
		else
			text:Hide()
		end
	end
	_G.SetItemButtonTexture = function(button, texture)
		if not button then
			return
		end
		local icon = part(button, "icon", "IconTexture") or rawget(button, "Icon")
		if not icon then
			return
		end
		if texture then
			icon:Show()
		else
			icon:Hide()
		end
		icon:SetTexture(texture)
	end
	_G.SetItemButtonTextureVertexColor = function(button, r, g, b)
		local icon = button and (part(button, "icon", "IconTexture") or rawget(button, "Icon"))
		if icon then
			icon:SetVertexColor(r, g, b)
		end
	end
	_G.SetItemButtonDesaturated = function(button, desaturated, r, g, b)
		local icon = button and (part(button, "icon", "IconTexture") or rawget(button, "Icon"))
		if not icon then
			return
		end
		local shaderSupported = icon:SetDesaturated(desaturated)
		if not desaturated then
			r, g, b = 1, 1, 1
		elseif not r or not shaderSupported then
			r, g, b = 0.5, 0.5, 0.5
		end
		icon:SetVertexColor(r, g, b)
	end
	_G.SetItemButtonNormalTextureVertexColor = function(button, r, g, b)
		local normal = button and (button.GetNormalTexture and button:GetNormalTexture() or part(button, "NormalTexture", "NormalTexture"))
		if normal then
			normal:SetVertexColor(r, g, b)
		end
	end
	_G.SetItemButtonNameFrameVertexColor = function(button, r, g, b)
		local frame = button and part(button, "NameFrame", "NameFrame")
		if frame then
			frame:SetVertexColor(r, g, b)
		end
	end
	_G.SetItemButtonSlotVertexColor = function(button, r, g, b)
		local slot = button and part(button, "SlotTexture", "SlotTexture")
		if slot then
			slot:SetVertexColor(r, g, b)
		end
	end
end

-- Frames, tables, money, misc -------------------------------------------------------------------------

define("GetUnscaledFrameRect", function(frame, scale)
	local left, bottom, width, height = frame:GetScaledRect()
	if not left then
		return 0, 0, 0, 0
	end
	scale = scale or 1
	return left / scale, bottom / scale, width / scale, height / scale
end)
define("SetClampedTextureRotation", function(texture, rotation)
	if rotation == 90 or rotation == 270 then
		texture:SetTexCoord(rotation == 90 and 0 or 1, rotation == 90 and 1 or 0, 0, 1)
	end
end)
define("FindValueInTableIf", function(tbl, pred)
	for _, v in pairs(tbl) do
		if pred(v) then
			return v
		end
	end
end)
define("GetPairsArray", function(tbl)
	local out = {}
	for k, v in pairs(tbl) do
		out[#out + 1] = { key = k, value = v }
	end
	return out
end)
define("GetMoneyTypeInfoField", function(moneyType, field)
	local info = MoneyTypeInfo and MoneyTypeInfo[moneyType]
	return info and info[field]
end)
define("GameTooltip_HideBattlePetTooltip", noop)
define("InputScrollFrame_OnLoad", noop)
define("StripHyperlinks", function(text)
	text = tostring(text or "")
	text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
	return text
end)
define("CanEditGuildBankTabInfo", function(tab) return CanEditGuildTabInfo and CanEditGuildTabInfo(tab) end)
define("SetLargeGuildTabardTextures", noop)
define("SetSmallGuildTabardTextures", noop)
define("GetBagSlotFlag", falseFn)
define("GetBankBagSlotFlag", falseFn)
define("GetReagentBankCost", function() return 0 end)
define("DepositReagentBank", noop)
define("IsVoidStorageReady", falseFn)
define("UnlockVoidStorage", noop)
define("ExecuteVoidTransfer", noop)
define("GetVoidTransferCost", function() return 0 end)
define("GetVoidTransferWithdrawalInfo", nilFn)
define("ClickVoidTransferWithdrawalSlot", noop)
define("ClickVoidStorageSlot", noop)
define("GetCraftReagentItemLink", nilFn)
define("IsKeyDown", function(key)
	if key == "LSHIFT" or key == "RSHIFT" or key == "SHIFT" then return IsShiftKeyDown() end
	if key == "LCTRL" or key == "RCTRL" or key == "CTRL" then return IsControlKeyDown() end
	if key == "LALT" or key == "RALT" or key == "ALT" then return IsAltKeyDown() end
	return false
end)
define("MuteSoundFile", noop)
define("UnmuteSoundFile", noop)
define("UnitDistanceSquared", function(unit)
	local x1, y1, _, map1 = UnitPosition("player")
	local x2, y2, _, map2 = UnitPosition(unit)
	if not x1 or not x2 or map1 ~= map2 then
		return 0, false
	end
	local dx, dy = x2 - x1, y2 - y1
	return dx * dx + dy * dy, true
end)
define("IsInScenarioGroup", falseFn)
define("InGuildParty", falseFn)
define("UnitSpellTargetName", nilFn)
define("UnitSpellTargetClass", nilFn)
define("GetLootSpecialization", function() return 0 end)
define("UnitPowerDisplayMod", function() return 1 end)
define("GetUnitChargedPowerPoints", nilFn)
define("GetUnitEmpowerStageDuration", function() return 0 end)
define("FindSpellOverrideByID", function(spellID) return spellID end)
define("FindBaseSpellByID", function(spellID) return spellID end)
define("GetPvpTalentInfoByID", nilFn)
define("GetPlayerFactionGroup", function() return UnitFactionGroup("player") end)
define("UnitRealmRelationship", function() return 1 end)
define("ClassicExpansionAtLeast", function(level) return (LE_EXPANSION_LEVEL_CURRENT or 2) >= level end)
define("GetMaxLevelForExpansionLevel", function(level) return ({ [0] = 60, 70, 80 })[level] or 80 end)
define("GetRelativeDifficultyColor", function(unitLevel, challengeLevel) return GetQuestDifficultyColor(challengeLevel) end)
define("UnitIsGameObject", falseFn)
define("UnitShouldDisplayName", function() return true end)
define("GetSpellDescription", function(spellID)
	local tip = ModernUI_GetScanTooltip and ModernUI_GetScanTooltip()
	if not tip then
		return ""
	end
	tip:SetHyperlink("spell:" .. spellID)
	local lines = tip:NumLines()
	local last = lines > 0 and _G[tip:GetName() .. "TextLeft" .. lines]
	return last and last:GetText() or ""
end)
define("GetSpellBaseCooldown", function() return 0, 0 end)
define("GetSpellCharges", nilFn)
define("GetSpellPowerCost", function() return {} end)
define("IsArtifactRelicItem", falseFn)
define("GetFlyoutInfo", nilFn)
define("GetFlyoutSlotInfo", nilFn)
define("IsSubmerged", function() return IsSwimming() end)
define("GetQuestID", function() return GetQuestLogSelection and select(9, GetQuestLogTitle(GetQuestLogSelection())) or 0 end)
define("GetQuestObjectiveInfo", function(questID, index)
	local logIndex = GetQuestLogIndexByID(questID)
	if not logIndex then
		return nil
	end
	local text, objectiveType, finished = GetQuestLogLeaderBoard(index, logIndex)
	return text, objectiveType, finished
end)
define("GetQuestProgressBarPercent", function() return 0 end)
define("IsQuestComplete", function(questID)
	local logIndex = GetQuestLogIndexByID(questID)
	return logIndex and select(7, GetQuestLogTitle(logIndex)) == 1 or false
end)
define("GameTooltip_SetTooltipWaitingForData", noop)
define("GameTooltip_SetBottomText", noop)
define("QuestUtils_GetQuestName", function(questID)
	local logIndex = GetQuestLogIndexByID(questID)
	return logIndex and GetQuestLogTitle(logIndex) or ""
end)
define("GetAppropriateTooltip", function() return GameTooltip end)
define("DressUpVisual", function(link) if link then DressUpItemLink(link) end end)
define("DressUpLink", function(link) if link then DressUpItemLink(link) end end)
define("DressUpFrame_Show", function() ShowUIPanel(DressUpFrame) end)
define("UpdateContainerFrameAnchors", function() if updateContainerFrameAnchors then updateContainerFrameAnchors() end end)
define("SetPortraitTextureFromCreatureDisplayID", noop)
define("SetBasicMessageDialogText", function(text) message(text) end)
define("IsKeyPressIgnoredForBinding", falseFn)
define("GetBindingName", function(binding) return _G["BINDING_NAME_" .. tostring(binding)] or binding end)
define("SearchBoxTemplate_OnTextChanged", function(self)
	local instructions = self.Instructions
	if instructions then
		if self:GetText() == "" then instructions:Show() else instructions:Hide() end
	end
	if self.clearButton then
		if self:GetText() == "" then self.clearButton:Hide() else self.clearButton:Show() end
	end
end)
define("SearchBoxTemplate_OnLoad", noop)
define("SearchBoxTemplateClearButton_OnClick", function(self)
	local box = self:GetParent()
	box:SetText("")
	box:ClearFocus()
end)

-- Strings -------------------------------------------------------------------------------------------------

for name, value in pairs({
	TOTAL = "Total", BANK = "Bank", EDIT = "Edit", VOID_STORAGE = "Void Storage", TRANSMOGRIFICATION = "Transmogrification",
	PLAYER_TITLE_NONE = "No Title", CRITERIA_COMPLETED = "Completed", LOCK_FRAME = "Lock Frame", ITEM_UPGRADE_CURRENT = "Current",
	ITEM_LEVEL_ABBR = "iLvl", STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF", UNIT_NAME_FONT = UNIT_NAME_FONT or "Fonts\\FRIZQT__.TTF",
	DAMAGE_TEXT_FONT = DAMAGE_TEXT_FONT or "Fonts\\FRIZQT__.TTF", NAMEPLATE_FONT = NAMEPLATE_FONT or "Fonts\\FRIZQT__.TTF",
	POWER_TYPE_MANA = MANA or "Mana", POWER_TYPE_FOCUS = FOCUS or "Focus", POWER_TYPE_ENERGY = ENERGY or "Energy",
	POWER_TYPE_RED_POWER = RAGE or "Rage", POWER_TYPE_RUNIC_POWER = RUNIC_POWER or "Runic Power", COMBO_POINTS = COMBO_POINTS or "Combo Points",
	CHI_POWER = "Chi", HOLY_POWER = "Holy Power", SOUL_SHARDS_POWER = "Soul Shards", POWER_TYPE_LUNAR_POWER = "Astral Power",
	POWER_TYPE_MAELSTROM = "Maelstrom", POWER_TYPE_INSANITY = "Insanity", POWER_TYPE_ARCANE_CHARGES = "Arcane Charges",
	POWER_TYPE_FURY_DEMONHUNTER = "Fury", POWER_TYPE_PAIN = "Pain", POWER_TYPE_ESSENCE = "Essence", STAGGER = "Stagger",
	BONUS_OBJECTIVE_TIME_LEFT = "Time Left: %s", REPUTATION_TOOLTIP_ACCOUNT_WIDE_LABEL = "Account-wide",
	CLUB_FINDER_APPLICANT_LIST_NO_MATCHING_SPECS = "None", PLAYER_DIFFICULTY_STORY_RAID = "Story",
}) do
	define(name, value)
end
define("LE_MODEL_BLEND_OPERATION_NONE", 0)
define("CAMERA_TRANSITION_TYPE_IMMEDIATE", 1)
define("CAMERA_TRANSITION_TYPE_INTERPOLATION", 2)
define("ACCOUNT_WIDE_FONT_COLOR", CreateColor(0, 0.8, 1))
