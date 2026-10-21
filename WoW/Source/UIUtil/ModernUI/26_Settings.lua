-- ModernUI: built into the client (not in the original 3.3.5a).
-- The modern Settings API (Settings.RegisterCanvasLayoutCategory and friends, SettingsPanel), on the
-- 3.3.5 Interface Options. A modern AddOn's options page appears on the AddOns tab, where 3.3.5 AddOns
-- put theirs; pages AddOns build with the vertical layout (checkboxes, sliders, dropdowns) are drawn
-- with the 3.3.5 option controls.

local _G = _G
if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
	return
end

local type, pairs, ipairs, tostring, tonumber, format = type, pairs, ipairs, tostring, tonumber, string.format

local Settings = _G.Settings or {}
_G.Settings = Settings

Settings.VarType = Settings.VarType or { Boolean = "boolean", Number = "number", String = "string" }
Settings.Default = Settings.Default or { True = true, False = false }
Settings.CategorySet = Settings.CategorySet or { Game = 1, AddOns = 2 }

local categories = {}   -- id -> category
local categoryLayouts = {} -- category -> layout (SettingsPanel.categoryLayouts on modern clients)
local nextID = 1000

local CategoryMixin = {}
function CategoryMixin:GetID() return self.ID end
function CategoryMixin:GetName() return self.name end
function CategoryMixin:SetName(name) self.name = name end
function CategoryMixin:GetParentCategory() return self.parentCategory end
function CategoryMixin:GetSubcategories() return self.subcategories end
function CategoryMixin:HasSubcategories() return #self.subcategories > 0 end
function CategoryMixin:SetOrder(order) self.order = order end
function CategoryMixin:GetOrder() return self.order or 0 end
function CategoryMixin:SetShouldSortAlphabetically() end
function CategoryMixin:SetExpanded(expanded) self.expanded = expanded end

local function newCategory(frame, name, parent)
	local category = CreateFromMixins(CategoryMixin)
	nextID = nextID + 1
	category.ID = name or nextID
	category.name = name
	category.frame = frame
	category.subcategories = {}
	category.parentCategory = parent
	if parent then
		tinsert(parent.subcategories, category)
	end
	categories[category.ID] = category
	categoryLayouts[category] = { frame = frame }
	return category
end

local LayoutMixin = {}
function LayoutMixin:AddAnchorPoint() end
function LayoutMixin:AddInitializer(initializer) tinsert(self.initializers, initializer) end
function LayoutMixin:GetInitializers() return self.initializers end
function LayoutMixin:GetLayoutType() return self.layoutType end
local function newLayout(kind)
	local layout = CreateFromMixins(LayoutMixin)
	layout.layoutType = kind
	layout.initializers = {}
	return layout
end

-- Canvas pages: the AddOn draws the frame itself.
function Settings.RegisterCanvasLayoutCategory(frame, name)
	frame.name = frame.name or name
	local category = newCategory(frame, name)
	local layout = newLayout("canvas")
	layout.frame = frame
	categoryLayouts[category] = layout
	return category, layout
end

function Settings.RegisterCanvasLayoutSubcategory(parentCategory, frame, name)
	frame.name = frame.name or name
	frame.parent = parentCategory and parentCategory.name
	local category = newCategory(frame, name, parentCategory)
	local layout = newLayout("canvas")
	layout.frame = frame
	categoryLayouts[category] = layout
	return category, layout
end

-- Vertical pages: the AddOn lists settings and the client draws them.
local buildVertical

function Settings.RegisterVerticalLayoutCategory(name)
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:Hide()
	frame.name = name
	local category = newCategory(frame, name)
	category.layout = newLayout("vertical")
	category.layout.frame = frame
	categoryLayouts[category] = category.layout
	frame:SetScript("OnShow", function(self) buildVertical(self, category) end)
	return category, category.layout
end

function Settings.RegisterVerticalLayoutSubcategory(parentCategory, name)
	local category, layout = Settings.RegisterVerticalLayoutCategory(name)
	category.parentCategory = parentCategory
	category.frame.parent = parentCategory and parentCategory.name
	if parentCategory then
		tinsert(parentCategory.subcategories, category)
	end
	return category, layout
end

local registered = {}
local function addToOptions(category)
	local frame = category.frame
	if not frame or registered[frame] then
		return
	end
	registered[frame] = true
	frame.name = frame.name or category.name
	frame.okay = frame.okay or frame.OnCommit or function() end
	frame.cancel = frame.cancel or function() end
	frame.default = frame.default or frame.OnDefault or function() end
	frame.refresh = frame.refresh or frame.OnRefresh or function() end
	InterfaceOptions_AddCategory(frame, true)
	for _, sub in ipairs(category.subcategories) do
		addToOptions(sub)
	end
end

function Settings.RegisterAddOnCategory(category)
	if category then
		addToOptions(category)
	end
end

function Settings.GetCategory(id)
	return categories[id]
end

function Settings.OpenToCategory(id)
	local category = categories[id] or (type(id) == "table" and id)
	local target = category and category.frame or id
	if not target then
		return false
	end
	-- 3.3.5 needs two calls the first time, while its list is still being built.
	InterfaceOptionsFrame_OpenToCategory(target)
	InterfaceOptionsFrame_OpenToCategory(target)
	return true
end

-- Settings objects -----------------------------------------------------------------------------------

local SettingMixin = {}
function SettingMixin:GetVariable() return self.variable end
function SettingMixin:GetName() return self.name end
function SettingMixin:GetVariableType() return self.varType end
function SettingMixin:GetDefaultValue() return self.defaultValue end
function SettingMixin:GetValue()
	if self.getter then
		return self.getter()
	end
	local value = self.table and self.table[self.key]
	if value == nil then
		return self.defaultValue
	end
	return value
end
function SettingMixin:SetValue(value)
	if self.setter then
		self.setter(value)
	elseif self.table then
		self.table[self.key] = value
	end
	for _, callback in ipairs(self.callbacks) do
		securecall(callback, self, value)
	end
end
function SettingMixin:SetValueToDefault() self:SetValue(self.defaultValue) end
function SettingMixin:SetValueChangedCallback(callback) tinsert(self.callbacks, callback) end
function SettingMixin:NotifyUpdate() end
function SettingMixin:SetCommitFlags() end
function SettingMixin:HasCommitFlag() return false end

local function newSetting(category, variable, varType, name, defaultValue)
	local setting = CreateFromMixins(SettingMixin)
	setting.variable, setting.varType, setting.name, setting.defaultValue = variable, varType, name, defaultValue
	setting.callbacks = {}
	setting.category = category
	return setting
end

function Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, varType, name, defaultValue)
	local setting = newSetting(category, variable, varType, name, defaultValue)
	setting.table, setting.key = variableTbl, variableKey
	return setting
end

function Settings.RegisterProxySetting(category, variable, varType, name, defaultValue, getter, setter)
	local setting = newSetting(category, variable, varType, name, defaultValue)
	setting.getter, setting.setter = getter, setter
	return setting
end

function Settings.RegisterCVarSetting(category, cvar, varType, name)
	return Settings.RegisterProxySetting(category, cvar, varType, name, GetCVarDefault(cvar),
		function()
			local value = GetCVar(cvar)
			if varType == "boolean" then return value == "1" end
			if varType == "number" then return tonumber(value) end
			return value
		end,
		function(value)
			if type(value) == "boolean" then value = value and "1" or "0" end
			SetCVar(cvar, tostring(value))
		end)
end

function Settings.SetValue(variable, value)
	for _, category in pairs(categories) do
		if category.layout then
			for _, init in ipairs(category.layout.initializers) do
				if init.setting and init.setting.variable == variable then
					init.setting:SetValue(value)
					return
				end
			end
		end
	end
end

-- Controls on vertical pages.
local function initializer(category, kind, setting, tooltip, extra)
	local init = { kind = kind, setting = setting, tooltip = tooltip, extra = extra, data = { setting = setting, tooltip = tooltip } }
	function init:GetSetting() return self.setting end
	function init:SetParentInitializer() end
	function init:AddShownPredicate(predicate) self.shown = predicate end
	function init:AddModifyPredicate(predicate) self.modify = predicate end
	function init:AddSearchTags() end
	function init:GetData() return self.data end
	if category and category.layout then
		category.layout:AddInitializer(init)
	end
	return init
end

function Settings.CreateCheckbox(category, setting, tooltip)
	return initializer(category, "check", setting, tooltip)
end
Settings.CreateCheckBox = Settings.CreateCheckbox

function Settings.CreateSlider(category, setting, options, tooltip)
	return initializer(category, "slider", setting, tooltip, options)
end

function Settings.CreateDropdown(category, setting, options, tooltip)
	return initializer(category, "dropdown", setting, tooltip, options)
end
Settings.CreateDropDown = Settings.CreateDropdown

function Settings.CreateSliderOptions(minValue, maxValue, step)
	local options = { minValue = minValue, maxValue = maxValue, steps = step and maxValue and (maxValue - minValue) / step or 100, step = step or 1 }
	function options:SetLabelFormatter(_, formatter) self.formatter = formatter end
	return options
end

function Settings.CreateControlTextContainer()
	local container = { data = {} }
	function container:Add(value, label, tooltip) tinsert(self.data, { value = value, label = label, tooltip = tooltip }) end
	function container:GetData() return self.data end
	return container
end

function Settings.CreateElementInitializer(template, data)
	return initializer(nil, "element", nil, nil, data)
end

function Settings.CreateSettingInitializer(template, data)
	return initializer(nil, "element", data and data.setting, nil, data)
end

_G.MinimalSliderWithSteppersMixin = _G.MinimalSliderWithSteppersMixin or { Label = { Left = 1, Right = 2, Top = 3, Min = 4, Max = 5 } }
_G.CreateSettingsListSectionHeaderInitializer = _G.CreateSettingsListSectionHeaderInitializer or function(text)
	return initializer(nil, "header", nil, nil, text)
end
_G.CreateSettingsButtonInitializer = _G.CreateSettingsButtonInitializer or function(name, buttonText, onClick, tooltip)
	return initializer(nil, "button", nil, tooltip, { name = name, text = buttonText, onClick = onClick })
end

local controlCount = 0
buildVertical = function(frame, category)
	if frame.built then
		for _, refresh in ipairs(frame.refreshers) do
			refresh()
		end
		return
	end
	frame.built = true
	frame.refreshers = {}
	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(category.name)
	local y = -50
	for _, init in ipairs(category.layout.initializers) do
		local setting = init.setting
		controlCount = controlCount + 1
		local name = "ModernUISettingsControl" .. controlCount
		if init.kind == "check" and setting then
			local check = CreateFrame("CheckButton", name, frame, "InterfaceOptionsCheckButtonTemplate")
			check:SetPoint("TOPLEFT", 16, y)
			_G[name .. "Text"]:SetText(setting.name)
			check.tooltipText = init.tooltip
			check:SetScript("OnClick", function(self) setting:SetValue(self:GetChecked() and true or false) end)
			local refresh = function() check:SetChecked(setting:GetValue() and true or false) end
			refresh()
			tinsert(frame.refreshers, refresh)
			y = y - 30
		elseif init.kind == "slider" and setting then
			local options = init.extra or {}
			local slider = CreateFrame("Slider", name, frame, "OptionsSliderTemplate")
			slider:SetPoint("TOPLEFT", 24, y - 14)
			slider:SetWidth(220)
			slider:SetMinMaxValues(options.minValue or 0, options.maxValue or 1)
			slider:SetValueStep(options.step or 1)
			_G[name .. "Low"]:SetText(tostring(options.minValue or 0))
			_G[name .. "High"]:SetText(tostring(options.maxValue or 1))
			local function label(value)
				_G[name .. "Text"]:SetText(format("%s: %s", setting.name or "", tostring(value)))
			end
			local updating = false
			slider:SetScript("OnValueChanged", function(_, value)
				label(value)
				if not updating then
					setting:SetValue(value)
				end
			end)
			local refresh = function()
				updating = true
				slider:SetValue(tonumber(setting:GetValue()) or options.minValue or 0)
				updating = false
				label(setting:GetValue())
			end
			refresh()
			tinsert(frame.refreshers, refresh)
			y = y - 56
		elseif init.kind == "dropdown" and setting then
			local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			label:SetPoint("TOPLEFT", 24, y)
			label:SetText(setting.name)
			local dropdown = CreateFrame("Frame", name, frame, "UIDropDownMenuTemplate")
			dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -16, -4)
			UIDropDownMenu_SetWidth(dropdown, 180)
			local function options()
				local source = init.extra
				if type(source) == "function" then
					source = source()
				end
				return source and source.GetData and source:GetData() or source or {}
			end
			UIDropDownMenu_Initialize(dropdown, function()
				for _, option in ipairs(options()) do
					local info = UIDropDownMenu_CreateInfo()
					info.text = option.label or option.text or tostring(option.value)
					info.checked = setting:GetValue() == option.value
					info.func = function()
						setting:SetValue(option.value)
						UIDropDownMenu_SetText(dropdown, info.text)
					end
					UIDropDownMenu_AddButton(info)
				end
			end)
			local refresh = function()
				local value = setting:GetValue()
				for _, option in ipairs(options()) do
					if option.value == value then
						UIDropDownMenu_SetText(dropdown, option.label or option.text or tostring(value))
					end
				end
			end
			refresh()
			tinsert(frame.refreshers, refresh)
			y = y - 56
		elseif init.kind == "header" then
			local header = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			header:SetPoint("TOPLEFT", 16, y - 6)
			header:SetText(type(init.extra) == "table" and init.extra.name or tostring(init.extra))
			y = y - 28
		elseif init.kind == "button" and type(init.extra) == "table" then
			local button = CreateFrame("Button", name, frame, "UIPanelButtonTemplate")
			button:SetPoint("TOPLEFT", 16, y)
			button:SetWidth(180)
			button:SetHeight(22)
			button:SetText(init.extra.text or init.extra.name or "")
			button:SetScript("OnClick", function() securecall(init.extra.onClick) end)
			y = y - 30
		end
	end
end

-- SettingsPanel -------------------------------------------------------------------------------------
-- Modern AddOns open, hook and inspect the settings window by this name; it stands for Interface Options.

if _G.SettingsPanel == nil and _G.InterfaceOptionsFrame then
	local panel = CreateFrame("Frame", "SettingsPanel", InterfaceOptionsFrame)
	panel:SetAllPoints()
	panel:EnableMouse(false)
	local list = CreateFrame("Frame", nil, panel)
	list:SetWidth(1)
	list:SetHeight(1)
	list:SetPoint("TOPLEFT")
	panel.CategoryList = list
	panel.categoryLayouts = categoryLayouts
	-- Modern code shows the settings window with SettingsPanel:Show() and redraws its category list.
	list.CreateCategories = function() end
	list.GetCategoryEntry = function() return nil end
	local showPanel = panel.Show
	panel.Show = function(self)
		showPanel(self)
		InterfaceOptionsFrame:Show()
	end
	panel.Container = CreateFrame("Frame", nil, panel)
	panel.Container.SettingsList = CreateFrame("Frame", nil, panel.Container)
	function panel:Open()
		InterfaceOptionsFrame:Show()
	end
	function panel:OpenToCategory(id)
		return Settings.OpenToCategory(id)
	end
	function panel:SelectCategory(category)
		return Settings.OpenToCategory(category)
	end
	function panel:GetCategoryList()
		return self.CategoryList
	end
	function panel:GetCategory(id)
		return categories[id]
	end
	function panel:GetAllCategories()
		local all = {}
		for _, category in pairs(categories) do
			all[#all + 1] = category
		end
		return all
	end
	function panel:GetSettingsList()
		return self.Container.SettingsList
	end
	function panel:ExitWithCommit()
		InterfaceOptionsFrame:Hide()
	end
	function panel:Commit() end
	function panel:DisplayCategory(category) Settings.OpenToCategory(category) end
	_G.SettingsPanel = panel
end
