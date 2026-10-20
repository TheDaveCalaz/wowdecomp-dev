-- ModernUI: built into the client (not in the original 3.3.5a).
-- The modern menu system (MenuUtil, dropdown buttons' SetupMenu) drawn with the 3.3.5 dropdown menus.
-- AddOns describe a menu (CreateButton, CreateCheckbox, CreateRadio, CreateTitle, CreateDivider, nested
-- submenus); here the description becomes a 3.3.5 menu list, built afresh each time it opens.

local _G = _G
if _G.MenuUtil then
	return
end

local type, ipairs, select, tostring = type, ipairs, select, tostring

_G.MenuResponse = _G.MenuResponse or { Open = 1, Refresh = 2, Close = 3, CloseAll = 4 }
_G.MenuInputContext = _G.MenuInputContext or { None = 0, MouseButton = 1, MouseWheel = 2 }

-- Descriptions -----------------------------------------------------------------------------------------

local Description = {}
Description.__index = Description

local function newDescription(kind, text, data)
	return setmetatable({ kind = kind, text = text, data = data, children = {}, enabled = true }, Description)
end

function Description:Add(kind, text, data)
	local child = newDescription(kind, text, data)
	self.children[#self.children + 1] = child
	return child
end
function Description:CreateButton(text, callback, data)
	local child = self:Add("button", text, data)
	child.callback = callback
	return child
end
function Description:CreateCheckbox(text, isSelected, setSelected, data)
	local child = self:Add("checkbox", text, data)
	child.isSelected, child.setSelected = isSelected, setSelected
	return child
end
function Description:CreateRadio(text, isSelected, setSelected, data)
	local child = self:Add("radio", text, data)
	child.isSelected, child.setSelected = isSelected, setSelected
	return child
end
function Description:CreateTitle(text) return self:Add("title", text) end
function Description:CreateDivider() return self:Add("divider", "") end
function Description:CreateSpacer() return self:Add("divider", "") end
function Description:CreateTemplate() return self:Add("template", "") end
function Description:CreateFrame() return self:Add("template", "") end
function Description:CreateColorSwatch(text, callback, color)
	local child = self:Add("button", text)
	child.callback = callback
	return child
end
function Description:SetEnabled(enabled) self.enabled = enabled end
function Description:IsEnabled()
	if type(self.enabled) == "function" then
		return self.enabled(self)
	end
	return self.enabled ~= false
end
function Description:SetTooltip(func) self.tooltip = func end
function Description:SetResponse(response) self.response = response end
function Description:SetTag() end
function Description:SetScrollMode() end
function Description:SetGridMode() end
function Description:SetMinimumWidth() end
function Description:SetData(data) self.data = data end
function Description:GetData() return self.data end
function Description:SetRadio() end
function Description:SetIsSelected(func) self.isSelected = func end
function Description:SetSelectionIgnored() end
function Description:SetOnEnter() end
function Description:SetOnLeave() end
function Description:SetCanSelect() end
function Description:QueueTitle(text) return self:CreateTitle(text) end
function Description:QueueDivider() return self:CreateDivider() end
function Description:QueueSpacer() return self:CreateDivider() end
function Description:ClearQueuedDescriptions() end
function Description:EnumerateElementDescriptions() return ipairs(self.children) end
-- The rest of the modern description interface. Menus here are drawn by this client's dropdowns, so
-- frame initializers and resetters are kept but have no frames to run on.
function Description:AddInitializer(fn) self.initializers = self.initializers or {} table.insert(self.initializers, fn) end
function Description:GetInitializers() return self.initializers or {} end
function Description:AddResetter(fn) self.resetters = self.resetters or {} table.insert(self.resetters, fn) end
function Description:GetResetters() return self.resetters or {} end
function Description:SetFinalInitializer(fn) self.finalInitializer = fn end
function Description:GetFinalInitializer() return self.finalInitializer end
function Description:Insert(description, index)
	if type(description) ~= "table" then
		return description
	end
	if getmetatable(description) ~= Description then
		setmetatable(description, Description)
		description.children = description.children or {}
	end
	table.insert(self.children, index or (#self.children + 1), description)
	return description
end
function Description:CanOpenSubmenu() return #self.children > 0 end
function Description:ForceOpenSubmenu() end
function Description:DeactivateSubmenu() end
function Description:SetMaximumWidth() end
function Description:SetSharedMenuProperties(properties) self.sharedProperties = properties end
function Description:GetSharedMenuProperties() return self.sharedProperties or {} end
function Description:DisableCompositor() end
function Description:IsCompositorEnabled() return false end
function Description:CanReacquireFrames() return false end
function Description:DisableReacquireFrames() end
function Description:SetElementFactory(factory) self.factory = factory end
function Description:CallFactory() end
function Description:SendResponseToMenu() end
function Description:SetFinalizeGridLayout() end
function Description:GetMenuMixin() return nil end
function Description:SetTooltipFrame(frame) self.tooltipFrame = frame end
function Description:GetTooltipFrame() return self.tooltipFrame or GameTooltip end
function Description:SetResponder(fn) self.responder = fn end
function Description:SetShouldPlaySoundOnCheckboxClick() end
function Description:SetShouldRespondIfSubmenu() end
function Description:SetSoundKit() end
function Description:SetTitleAndTextTooltip(title, text)
	self.tooltip = function(tooltip) tooltip:AddLine(title or "", 1, 1, 1) if text then tooltip:AddLine(text, nil, nil, nil, true) end end
end
for _, kind in ipairs({ "Acquired", "Changed", "Released", "Response" }) do
	Description["AddMenu" .. kind .. "Callback"] = function(self, fn)
		self.callbacks = self.callbacks or {}
		self.callbacks[kind] = self.callbacks[kind] or {}
		table.insert(self.callbacks[kind], fn)
	end
	Description["GetMenu" .. kind .. "Callbacks"] = function(self)
		return self.callbacks and self.callbacks[kind] or {}
	end
end
function Description:HasElements() return #self.children > 0 end

local function selected(element)
	if type(element.isSelected) == "function" then
		return element.isSelected(element.data) and true or false
	end
	return element.isSelected and true or false
end

-- 3.3.5 menu lists ------------------------------------------------------------------------------------

local toList
toList = function(description)
	local list = {}
	for _, element in ipairs(description.children) do
		local info = { text = element.text or "", notCheckable = true }
		if element.kind == "title" then
			info.isTitle = true
		elseif element.kind == "divider" or element.kind == "template" then
			info.disabled = true
			info.text = ""
		elseif element.kind == "checkbox" or element.kind == "radio" then
			info.notCheckable = nil
			info.checked = selected(element)
			info.keepShownOnClick = element.kind == "checkbox"
			info.func = function()
				if element.setSelected then
					securecall(element.setSelected, element.data, { buttonName = "LeftButton" }, element)
				end
			end
		else
			info.func = function()
				if element.callback then
					securecall(element.callback, element.data, { buttonName = "LeftButton" }, element)
				end
			end
		end
		if not element:IsEnabled() then
			info.disabled = true
		end
		if #element.children > 0 then
			info.hasArrow = true
			info.menuList = toList(element)
		end
		list[#list + 1] = info
	end
	return list
end

local menuFrame
local function open(owner, generator, anchor, cursor)
	local root = newDescription("root")
	if type(generator) == "function" then
		securecall(generator, owner, root)
	end
	menuFrame = menuFrame or CreateFrame("Frame", "ModernUIMenuDropDown", UIParent, "UIDropDownMenuTemplate")
	local list = toList(root)
	if #list == 0 then
		return
	end
	if cursor then
		EasyMenu(list, menuFrame, "cursor", 0, 0, "MENU")
	else
		EasyMenu(list, menuFrame, anchor or owner, 0, 0, "MENU")
	end
	return root
end

local MenuUtil = {}
function MenuUtil.CreateContextMenu(owner, generator)
	return open(owner, generator, nil, true)
end
function MenuUtil.CreateButtonMenu(owner, ...)
	local entries = { ... }
	return open(owner, function(_, root)
		for _, entry in ipairs(entries) do
			root:CreateButton(entry[1], entry[2])
		end
	end, nil, true)
end
function MenuUtil.CreateCheckboxContextMenu(owner, isSelected, setSelected, ...)
	local entries = { ... }
	return open(owner, function(_, root)
		for _, entry in ipairs(entries) do
			root:CreateCheckbox(entry[1], isSelected, setSelected, entry[2])
		end
	end, nil, true)
end
function MenuUtil.CreateRadioContextMenu(owner, isSelected, setSelected, ...)
	local entries = { ... }
	return open(owner, function(_, root)
		for _, entry in ipairs(entries) do
			root:CreateRadio(entry[1], isSelected, setSelected, entry[2])
		end
	end, nil, true)
end
function MenuUtil.ShowTooltip(owner, func, ...)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	func(GameTooltip, ...)
	GameTooltip:Show()
end
function MenuUtil.HideTooltip() GameTooltip:Hide() end
function MenuUtil.GetElementText(description) return description and description.text end
function MenuUtil.SetElementText(description, text) if description then description.text = text end end
function MenuUtil.CreateRootMenuDescription() return newDescription("root") end
function MenuUtil.TraverseMenu(description, fn, condition)
	for _, element in ipairs(description and description.children or {}) do
		if not condition or condition(element) then
			fn(element)
		end
		MenuUtil.TraverseMenu(element, fn, condition)
	end
end
function MenuUtil.GetSelections(description, condition)
	local list = {}
	MenuUtil.TraverseMenu(description, function(element)
		if (element.kind == "radio" or element.kind == "checkbox") and selected(element) then
			list[#list + 1] = element
		end
	end, condition)
	return list
end
-- Free-standing descriptions, inserted later with description:Insert().
function MenuUtil.CreateButton(text, callback, data)
	local element = newDescription("button", text, data)
	element.callback = callback
	return element
end
function MenuUtil.CreateCheckbox(text, isSelected, setSelected, data)
	local element = newDescription("checkbox", text, data)
	element.isSelected, element.setSelected = isSelected, setSelected
	return element
end
function MenuUtil.CreateRadio(text, isSelected, setSelected, data)
	local element = newDescription("radio", text, data)
	element.isSelected, element.setSelected = isSelected, setSelected
	return element
end
function MenuUtil.CreateHighlightButton(text, data) return MenuUtil.CreateButton(text, nil, data) end
function MenuUtil.CreateHighlightRadio(text, isSelected, setSelected, data) return MenuUtil.CreateRadio(text, isSelected, setSelected, data) end
function MenuUtil.CreateTitle(text) return newDescription("title", text) end
function MenuUtil.CreateDivider() return newDescription("divider", "") end
function MenuUtil.CreateSpacer() return newDescription("divider", "") end
function MenuUtil.CreateTemplate() return newDescription("template", "") end
function MenuUtil.CreateFrame() return newDescription("template", "") end
function MenuUtil.CreateColorSwatch(text, callback) return MenuUtil.CreateButton(text, callback) end
function MenuUtil.ShowTooltipEx(owner, tooltip, func, ...)
	tooltip:SetOwner(owner, "ANCHOR_RIGHT")
	func(tooltip, ...)
	tooltip:Show()
end
function MenuUtil.HideTooltipEx(owner, tooltip)
	if tooltip:GetOwner() == owner then
		tooltip:Hide()
	end
end
function MenuUtil.HookTooltipScripts(owner, func)
	local tooltip = GameTooltip
	owner:HookScript("OnEnter", function()
		tooltip:SetOwner(owner, "ANCHOR_RIGHT")
		func(tooltip)
		tooltip:Show()
	end)
	owner:HookScript("OnLeave", function()
		if tooltip:GetOwner() == owner then
			tooltip:Hide()
		end
	end)
end
local function dropdownMenu(dropdown, build)
	if dropdown and dropdown.SetupMenu then
		dropdown:SetupMenu(function(_, root) build(root) end)
	end
end
function MenuUtil.CreateButtonContextMenu(owner, ...) return MenuUtil.CreateButtonMenu(owner, ...) end
function MenuUtil.CreateCheckboxMenu(dropdown, isSelected, setSelected, ...)
	local entries = { ... }
	dropdownMenu(dropdown, function(root)
		for _, entry in ipairs(entries) do root:CreateCheckbox(entry[1], isSelected, setSelected, entry[2]) end
	end)
end
function MenuUtil.CreateRadioMenu(dropdown, isSelected, setSelected, ...)
	local entries = { ... }
	dropdownMenu(dropdown, function(root)
		for _, entry in ipairs(entries) do root:CreateRadio(entry[1], isSelected, setSelected, entry[2]) end
	end)
end
local function enumEntries(enum, translate, order)
	local list = {}
	if order then
		for _, value in ipairs(order) do list[#list + 1] = { translate(value), value } end
	else
		for _, value in pairs(enum) do list[#list + 1] = { translate(value), value } end
		table.sort(list, function(a, b) return a[2] < b[2] end)
	end
	return list
end
function MenuUtil.CreateEnumRadioMenu(dropdown, enum, translate, isSelected, setSelected, order)
	return MenuUtil.CreateRadioMenu(dropdown, isSelected, setSelected, unpack(enumEntries(enum, translate, order)))
end
function MenuUtil.CreateEnumRadioContextMenu(owner, enum, translate, isSelected, setSelected, order)
	return MenuUtil.CreateRadioContextMenu(owner, isSelected, setSelected, unpack(enumEntries(enum, translate, order)))
end
_G.MenuUtil = MenuUtil

-- Menu templates attach extra buttons to menu entries' frames. Entries here are this client's dropdown
-- buttons, which have no room for them; the attachments are made but kept hidden.
if _G.MenuTemplates == nil then
	local function hiddenButton(parent)
		local button = CreateFrame("Button", nil, parent)
		button:SetWidth(16)
		button:SetHeight(16)
		button:Hide()
		return button
	end
	local MenuTemplates = {}
	MenuTemplates.AttachAutoHideGearButton = hiddenButton
	MenuTemplates.AttachAutoHideCancelButton = hiddenButton
	MenuTemplates.AttachUtilityButton = hiddenButton
	MenuTemplates.AttachBasicButton = hiddenButton
	MenuTemplates.AttachNewFeatureFrame = hiddenButton
	MenuTemplates.AttachTexture = function(parent) return parent:CreateTexture(nil, "ARTWORK") end
	MenuTemplates.SetUtilityButtonAnchor = function() end
	MenuTemplates.SetUtilityButtonClickHandler = function() end
	MenuTemplates.SetUtilityButtonLockedEnabledState = function() end
	MenuTemplates.SetUtilityButtonTooltipText = function() end
	MenuTemplates.SetHierarchyEnabled = function() end
	MenuTemplates.RecurseSetupFontString = function() end
	MenuTemplates.CreateSelectionTextures = function() end
	MenuTemplates.CreateButton = MenuUtil.CreateButton
	MenuTemplates.CreateCheckbox = MenuUtil.CreateCheckbox
	MenuTemplates.CreateRadio = MenuUtil.CreateRadio
	MenuTemplates.CreateHighlightButton = MenuUtil.CreateHighlightButton
	MenuTemplates.CreateHighlightRadio = MenuUtil.CreateHighlightRadio
	MenuTemplates.CreateTitle = MenuUtil.CreateTitle
	MenuTemplates.CreateDivider = MenuUtil.CreateDivider
	MenuTemplates.CreateSpacer = MenuUtil.CreateSpacer
	MenuTemplates.CreateTemplate = MenuUtil.CreateTemplate
	MenuTemplates.CreateFrame = MenuUtil.CreateFrame
	MenuTemplates.CreateColorSwatch = MenuUtil.CreateColorSwatch
	_G.MenuTemplates = MenuTemplates
end

_G.Menu = _G.Menu or {
	ModifyMenu = function() end,
	GetManager = function() return { GetOpenMenu = function() end, CloseMenus = function() CloseDropDownMenus() end } end,
	PopulateDescription = function() end,
}

-- Dropdown buttons ---------------------------------------------------------------------------------------
-- Modern dropdown buttons take their menu with SetupMenu and open it when clicked.

local DropdownButtonMixin = _G.DropdownButtonMixin or {}
function DropdownButtonMixin:SetupMenu(generator)
	self.menuGenerator = generator
	if not self.menuHooked then
		self.menuHooked = true
		self:HookScript("OnClick", function(button)
			if button.menuGenerator then
				open(button, button.menuGenerator, button, false)
			end
		end)
	end
	self:GenerateMenu()
end
function DropdownButtonMixin:GenerateMenu()
	if not self.menuGenerator then
		return
	end
	-- Show the selected radio or checkbox entry as the button's text, as modern dropdowns do.
	local root = newDescription("root")
	securecall(self.menuGenerator, self, root)
	local function find(description)
		for _, element in ipairs(description.children) do
			if element.kind == "radio" and selected(element) then
				return element.text
			end
			local inner = find(element)
			if inner then
				return inner
			end
		end
	end
	local text = self.overrideText or find(root) or self.defaultText
	if text and self.SetText then
		self:SetText(text)
	end
end
function DropdownButtonMixin:OverrideText(text) self.overrideText = text if self.SetText then self:SetText(text) end end
function DropdownButtonMixin:SetDefaultText(text) self.defaultText = text end
function DropdownButtonMixin:SetSelectionText() end
function DropdownButtonMixin:SetSelectionTranslator() end
function DropdownButtonMixin:Update() self:GenerateMenu() end
function DropdownButtonMixin:Signal() end
function DropdownButtonMixin:IsMenuOpen() return DropDownList1 and DropDownList1:IsShown() end
function DropdownButtonMixin:CloseMenu() CloseDropDownMenus() end
function DropdownButtonMixin:OpenMenu() if self.menuGenerator then open(self, self.menuGenerator, self, false) end end
function DropdownButtonMixin:SetMenuAnchor() end
function DropdownButtonMixin:RegisterCallback() end
function DropdownButtonMixin:EnableMouseWheel() end
_G.DropdownButtonMixin = DropdownButtonMixin
_G.WowStyle1DropdownMixin = _G.WowStyle1DropdownMixin or DropdownButtonMixin

-- Every button can take a menu this way.
do
	local probe = CreateFrame("Button")
	probe:Hide()
	local index = getmetatable(probe).__index
	-- Only the menu methods: generic names (Update, RegisterCallback) would shadow AddOns' own checks.
	local menuMethods = { SetupMenu = true, GenerateMenu = true, OverrideText = true, SetDefaultText = true,
		SetSelectionText = true, SetSelectionTranslator = true, OpenMenu = true, CloseMenu = true, IsMenuOpen = true }
	for name, fn in pairs(DropdownButtonMixin) do
		if menuMethods[name] and type(index) == "table" and rawget(index, name) == nil then
			index[name] = fn
		end
	end
end
