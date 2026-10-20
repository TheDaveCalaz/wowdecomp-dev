-- Smoke test for the built-in AddOn Control Panel and Advanced Interface Options.
-- Usage: python3 run.py test_panels.lua
-- A permissive widget mock: any method exists; the ones the panels read back keep state.

local function widget(kind, name, parent)
	local w = { __kind = kind, __name = name, __parent = parent, __scripts = {}, __shown = true, __points = {} }
	local mt = {}
	mt.__index = function(t, k)
		if type(k) == "string" and k:byte(1) >= 65 and k:byte(1) <= 90 then
			return function() end
		end
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


ScrollUtil, CreateScrollBoxListLinearView, CallbackRegistryMixin, Mixin, CreateFromMixins, CreateDataProvider, DataProviderMixin = nil
for _, f in ipairs({"01_Base.lua","04_Callbacks.lua","27_Gaps.lua","29_ScrollBox.lua"}) do
	local fn = assert(loadstring(assert(io.open("../" .. f)):read("*a"), f))
	local ok, err = pcall(fn)
	if not ok then print("load " .. f .. ": " .. tostring(err)) end
end
local box = CreateFrame("Frame", "TestBox", UIParent)
box.GetHeight = function() return 100 end
box.GetWidth = function() return 200 end
local bar = CreateFrame("Frame", "TestBar", UIParent)
local view = CreateScrollBoxListLinearView()
view:SetElementExtent(20)
local inits = 0
view:SetElementInitializer("Template", function(frame, data) inits = inits + 1 frame.data = data end)
ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
local list = {}
for i = 1, 50 do list[i] = { i = i } end
box:SetDataProvider(CreateDataProvider(list))
local n = #box:GetFrames()
assert(n >= 5 and n <= 7, "frames in view: " .. n)
print("ok   frames in view " .. n)
box:ScrollToEnd()
assert(box:FindFrame(list[50]), "last row after scrolling to end")
assert(not box:FindFrame(list[1]), "first row released")
print("ok   scroll to end reuses frames")
bar:SetScrollPercentage(0)
assert(box:FindFrame(list[1]), "bar scrolls box")
print("ok   scroll bar drives box")
print("ALL PASSED")
