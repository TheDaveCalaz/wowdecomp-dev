-- Smoke test for the built-in AddOn Control Panel and Advanced Interface Options.
-- Usage: python3 run.py test_panels.lua
-- A permissive widget mock: any method exists; the ones the panels read back keep state.

local function widget(kind, name, parent)
	local w = { __kind = kind, __name = name, __parent = parent, __scripts = {}, __shown = true, __points = {} }
	local mt = {}
	mt.__index = function(t, k)
		return function() end
	end
	setmetatable(w, mt)
	w.GetName = function(self) return self.__name end
	w.GetParent = function(self) return self.__parent end
	w.SetScript = function(self, s, f) self.__scripts[s] = f end
	w.GetScript = function(self, s) return self.__scripts[s] end
	w.HookScript = function(self, s, f) local o = self.__scripts[s] self.__scripts[s] = function(...) if o then o(...) end f(...) end end
	w.Show = function(self) local was = self.__shown self.__shown = true if not was and self.__scripts.OnShow then self.__scripts.OnShow(self) end end
	w.Hide = function(self) local was = self.__shown self.__shown = false if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end end
	w.IsShown = function(self) return self.__shown end
	w.SetChecked = function(self, v) self.__checked = v and 1 or nil end
	w.GetChecked = function(self) return rawget(self, "__checked") end
	w.SetText = function(self, v) self.__text = v end
	w.GetText = function(self) return rawget(self, "__text") end
	w.SetValue = function(self, v) self.__value = v if self.__scripts.OnValueChanged then self.__scripts.OnValueChanged(self, v) end end
	w.GetValue = function(self) return rawget(self, "__value") end
	w.GetHeight = function() return 21 end
	w.SetPoint = function(self, ...) self.__points[#self.__points + 1] = { ... } end
	w.ClearAllPoints = function(self) self.__points = {} end
	w.GetPoint = function(self, i) local p = self.__points[i or 1] if p then return unpack(p) end end
	w.HasFocus = function() return false end
	w.Click = function(self) if self.__scripts.OnClick then self.__scripts.OnClick(self, "LeftButton") end end
	w.CreateTexture = function(self) return widget("Texture", nil, self) end
	w.CreateFontString = function(self) return widget("FontString", nil, self) end
	return w
end

local function expand(name, parent)
	if name and name:find("^%$parent") then
		local p = parent
		while p and not p.__name do p = p.__parent end
		return (p and p.__name or "Top") .. name:sub(8)
	end
	return name
end

function CreateFrame(kind, name, parent, template)
	name = expand(name, parent)
	local w = widget(kind, name, parent)
	if name then
		_G[name] = w
		for _, suffix in ipairs({ "Text", "Low", "High", "ScrollBar", "EditBox", "Button" }) do
			_G[name .. suffix] = widget("Child", name .. suffix, w)
		end
	end
	if kind ~= "Frame" or name ~= "AddonList" then
		-- created shown, like the client
	end
	return w
end

UIParent = widget("Frame", "UIParent")
UISpecialFrames = {}
StaticPopupDialogs = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("CHAT: " .. m) end }
UIErrorsFrame = { AddMessage = function() end }
GameTooltip = widget("GameTooltip", "GameTooltip")
GameFontHighlightSmall, GameFontHighlight = {}, {}
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function UnitName() return "Dave" end
function issecure() return true end
function StaticPopup_Show() end
function ReloadUI() print("RELOAD") end
function CloseDropDownMenus() end
function ToggleDropDownMenu() end
local menuItems
function UIDropDownMenu_Initialize(frame, fn, mode) menuItems = {} fn(frame, 1) end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info) menuItems[#menuItems + 1] = info end
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetText(f, t) f.__text = t end
function FauxScrollFrame_GetOffset() return 0 end
function FauxScrollFrame_Update() end
function FauxScrollFrame_SetOffset() end
function FauxScrollFrame_OnVerticalScroll() end
function HideUIPanel() end
function GetAddOnMemoryUsage() return 2048 end
function UpdateAddOnMemoryUsage() end
local registered = {}
function InterfaceOptions_AddCategory(panel) registered[#registered + 1] = panel.name end
function InterfaceOptionsFrame_OpenToCategory() end

-- AddOns.
local addons = {
	{ name = "DBM-Core", title = "|cffffd200Deadly Boss Mods|r", deps = {}, enabled = true, author = "Tandanu" },
	{ name = "DBM-Party", title = "DBM Party", deps = { "DBM-Core" }, enabled = false, lod = true },
	{ name = "Questie", title = "Questie", deps = {}, enabled = true, category = "Quests" },
	{ name = "WeakAuras", title = "WeakAuras", deps = {}, enabled = true },
	{ name = "WeakAurasOptions", title = "WeakAuras Options", deps = { "WeakAuras", "Missing_Lib" }, enabled = true, lod = true },
}
local byName = {}
for i, a in ipairs(addons) do byName[a.name] = i end
local function idx(x) if type(x) == "number" then return x end return byName[x] end
function GetNumAddOns() return #addons end
function GetAddOnInfo(x)
	local i = idx(x)
	if not i then
		if type(x) == "string" and x:find("^Blizzard_") then return x, x, "", 1, 1, nil end
		return x, nil, nil, nil, nil, "MISSING"
	end
	local a = addons[i]
	return a.name, a.title, "notes", a.enabled and 1 or nil, a.enabled and 1 or nil, a.enabled and nil or "DISABLED", "INSECURE"
end
function GetAddOnMetadata(x, f)
	local a = addons[idx(x) or 0]
	if not a then return nil end
	if f == "Author" then return a.author end
	if f == "X-Category" then return a.category end
end
function GetAddOnDependencies(x) local a = addons[idx(x) or 0] return unpack(a and a.deps or {}) end
function IsAddOnLoaded(x) local i = idx(x) return i and addons[i].enabled and not addons[i].lod end
function IsAddOnLoadOnDemand(x) local i = idx(x) return i and addons[i].lod end
function EnableAddOn(x) local i = idx(x) if i then addons[i].enabled = true end end
function DisableAddOn(x) local i = idx(x) if i then addons[i].enabled = false end end
function EnableAllAddOns() for _, a in ipairs(addons) do a.enabled = true end end
function DisableAllAddOns() for _, a in ipairs(addons) do a.enabled = false end end
function LoadAddOn() return 1 end

-- CVars.
local cvars = { scriptErrors = { "0", "0" }, maxFPS = { "200", "200" }, cameraDistanceMaxFactor = { "1", "1" },
	taintLog = { "0", "0" }, checkAddonVersion = { "1", "1" }, farclip = { "350", "350" } }
function GetCVarInfo(n) local c = cvars[n] if c then return c[1], c[2] end end
function GetCVar(n) local c = cvars[n] return c and c[1] end
function GetCVarDefault(n) local c = cvars[n] return c and c[2] end
function SetCVar(n, v) if not cvars[n] then error("no cvar " .. n) end cvars[n][1] = tostring(v) end
function ConsoleGetAllCommands()
	local t = {}
	for n in pairs(cvars) do t[#t + 1] = { command = n, help = "help for " .. n, category = 5, commandType = 0 } end
	return t
end

local saved
function ModernUI_LoadData() return saved end
function ModernUI_SaveData(k, text) saved = text return true end

GameMenuFrame = CreateFrame("Frame", "GameMenuFrame")
GameMenuButtonMacros = CreateFrame("Button", "GameMenuButtonMacros", GameMenuFrame)
GameMenuButtonLogout = CreateFrame("Button", "GameMenuButtonLogout", GameMenuFrame)
GameMenuButtonLogout:SetPoint("TOP", GameMenuButtonMacros, "BOTTOM", 0, -1)

local function run(file)
	local f = assert(loadstring(assert(io.open("../" .. file)):read("*a"), file))
	f()
end
local ok_, err = pcall(run, "40_AddonList.lua")
assert(ok_, err)
local ok2, err2 = pcall(run, "41_AdvancedOptions.lua")
assert(ok2, err2)

local function check(name, cond) if not cond then error("FAILED: " .. name) end print("ok   " .. name) end

-- Esc menu.
check("AddOns button exists", GameMenuButtonAddOns ~= nil)
local _, rel = GameMenuButtonLogout:GetPoint(1)
check("Logout hangs below AddOns", rel == GameMenuButtonAddOns)
AddonList:Hide()
GameMenuButtonAddOns:Click()
check("button opens the list", AddonList:IsShown())

-- Rows.
check("row 1 shows an AddOn", rawget(AddonListEntry1.title, "__text") ~= nil)
-- Default sort: last rows include the Blizzard header.
local sawBlizzard = false
for i = 1, 20 do
	local row = _G["AddonListEntry" .. i]
	if rawget(row, "line") and row.line.header == "Blizzard AddOns" then sawBlizzard = true end
end
check("Blizzard group listed", sawBlizzard)

-- Recursive enable: enabling DBM-Party enables DBM-Core.
DisableAddOn("DBM-Core")
AddonListEntry2.line = { addon = 2 }
AddonListEntry2.check.__checked = 1
AddonListEntry2.check:Click()
check("recursive enables dependency", addons[1].enabled and addons[2].enabled)

-- Missing dependency message and LoD child (WeakAuras -> WeakAurasOptions).
DisableAddOn("WeakAurasOptions")
DisableAddOn("WeakAuras")
AddonListEntry4.line = { addon = 4 }
AddonListEntry4.check.__checked = 1
AddonListEntry4.check:Click()
check("LoD child enabled", addons[5].enabled)

-- Sort modes.
for _, mode in ipairs({ "Title", "Author", "Group", "Category", "Default" }) do
	UIDropDownMenu_Initialize(AddonListMenu, function() end)
	AddonListSortButton:Click()
	for _, info in ipairs(menuItems) do
		if info.text and info.func and (info.text:find(mode) or (mode == "Default" and info.text == "Load order") or (mode == "Group" and info.text:find("Group"))) then
			info.func()
		end
	end
	check("sort " .. mode, AddonList:IsShown())
end
-- Group mode makes a DBM group.
saved = saved:gsub("sort=[^\n]*", "sort=Group")
UIDropDownMenu_Initialize(AddonListMenu, function() end)
AddonListSortButton:Click()
for _, info in ipairs(menuItems) do if info.text == "Group (by name)" then info.func() end end
local sawDBM = false
for i = 1, 20 do
	local row = _G["AddonListEntry" .. i]
	if rawget(row, "line") and row.line.header == "DBM" then sawDBM = true end
end
check("DBM grouped", sawDBM)

-- Protect and Disable All.
AddonListEntry1.line = { addon = 3 }
AddonListEntry1.lock:Click()
AddonListDisableAllButton:Click()
check("protected stays enabled", addons[3].enabled and not addons[4].enabled)
check("settings saved", saved and saved:find("protected=Questie"))

-- Sets.
EnableAllAddOns()
AddonListSetsButton:Click()
local setMenu = AddonListMenu.initialize
UIDropDownMenu_Initialize(AddonListMenu, function() end)
check("data round trip", saved:find("recursive=1"))

-- Advanced options.
check("AIO pages registered", #registered == 6 and registered[1] == "Advanced Interface Options")
check("sub-pages in reverse for the Game tab", registered[2] == "CVar Browser" and registered[6] == "Camera")
ModernUIAdvancedOptions1:Hide()
ModernUIAdvancedOptions1:Show()
ModernUIAdvancedOptions1Check1:SetChecked(1)
ModernUIAdvancedOptions1Check1:Click()
check("check sets CVar", cvars.scriptErrors[1] == "1")
ModernUIAdvancedOptions1.cancel()
check("cancel restores", cvars.scriptErrors[1] == "0")
ModernUIAdvancedOptions6:Hide()
ModernUIAdvancedOptions6:Show()
check("browser lists CVars", rawget(ModernUIAdvancedOptionsRow1.name, "__text") ~= nil)
SlashCmdList.MODERNUI_AIO()
SlashCmdList.MODERNUI_ADDONS()
print("ALL PASSED")
