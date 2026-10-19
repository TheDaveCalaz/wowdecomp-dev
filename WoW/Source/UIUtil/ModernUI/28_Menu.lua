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
function Description:AddInitializer() end
function Description:SetData(data) self.data = data end
function Description:GetData() return self.data end
function Description:SetRadio() end
function Description:SetIsSelected(func) self.isSelected = func end
function Description:SetSelectionIgnored() end
function Description:SetOnEnter() end
function Description:SetOnLeave() end
function Description:SetCanSelect() end
function Description:SetFinalInitializer() end
function Description:QueueTitle(text) return self:CreateTitle(text) end
function Description:QueueDivider() return self:CreateDivider() end
function Description:QueueSpacer() return self:CreateDivider() end
function Description:ClearQueuedDescriptions() end
function Description:EnumerateElementDescriptions() return ipairs(self.children) end
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
function MenuUtil.TraverseMenu() end
_G.MenuUtil = MenuUtil

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

_G.CreateRadioButtonGroup = _G.CreateRadioButtonGroup or function()
	local group = { buttons = {} }
	function group:AddButton(button) self.buttons[#self.buttons + 1] = button end
	function group:AddButtons(buttons) for _, b in ipairs(buttons) do self:AddButton(b) end end
	function group:SelectAtIndex(index)
		for i, b in ipairs(self.buttons) do
			if b.SetChecked then b:SetChecked(i == index) end
		end
		self.selected = index
		if self.callback then self.callback(self.buttons[index], index) end
	end
	function group:GetSelectedIndex() return self.selected end
	function group:RegisterCallback(_, callback) self.callback = callback end
	return group
end
