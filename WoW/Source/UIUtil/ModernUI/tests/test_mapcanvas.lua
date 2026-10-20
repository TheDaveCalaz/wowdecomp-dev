-- The world map works as a modern map canvas: data providers, pins placed on WorldMapButton, map IDs in
-- the modern numbering, and the open map is only changed when code asks for it.
local function check(cond, msg) if not cond then error("FAIL " .. msg, 2) end print("ok   " .. msg) end
for _, kind in ipairs({ "Frame", "Button" }) do
	local m = getmetatable(CreateFrame(kind)).__index
	m.SetParent = function(self, p) self.__parent = p end
	m.GetParent = function(self) return self.__parent end
	m.GetScale = function() return 1 end
	m.SetScale = function(self, s) self.__scale = s end
	m.SetSize = function(self, w, h) self:SetWidth(w) self:SetHeight(h) end
	m.GetRegions = function(self) return unpack(self.__regions or {}) end
	m.IsMouseOver = function() return false end
	m.GetEffectiveScale = function() return 1 end
	m.GetLeft = function() return 0 end
	m.GetTop = function() return 668 end
	m.SetMouseClickEnabled = function() end
	m.SetMouseMotionEnabled = function() end
	m.SetAllPoints = function() end
	m.EnableMouseWheel = function() end
end
WorldMapFrame = CreateFrame("Frame")
WorldMapFrame.__regions = { { SetText = function() end } }
WorldMapDetailFrame = CreateFrame("Frame")
WorldMapButton = CreateFrame("Button")
WorldMapButton:SetWidth(1000) WorldMapButton:SetHeight(600)
WorldMapFrame:Hide()
local legacy = 5
GetCurrentMapAreaID = function() return legacy end
local setTo
SetMapByID = function(id) setTo = id legacy = id + 1 end
ModernUI_GetUIMapIDFromAreaID = function(l) return ({ [5] = 1411, [14] = 1414 })[l] end
ModernUI_GetAreaIDFromUIMapID = function(u) return ({ [1411] = 5, [1414] = 14 })[u] end
C_XMLUtil = C_XMLUtil or {} C_XMLUtil.GetTemplateInfo = function() return nil end

_G.MapCanvasMixin = nil
local ok, err = pcall(dofile, "../32_MapCanvas.lua")
check(ok, "map canvas file loads: " .. tostring(err))
check(WorldMapFrame:GetCanvas() == WorldMapButton, "canvas is WorldMapButton")
check(WorldMapFrame.BorderFrame:GetRegions().SetText ~= nil, "border frame exposes the title")

local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local refreshed = 0
function provider:RefreshAllData() refreshed = refreshed + 1 end
WorldMapFrame:AddDataProvider(provider)
check(provider:GetMap() == WorldMapFrame, "provider attached")
WorldMapFrame:Show()
WorldMapFrame.__scripts.OnShow(WorldMapFrame)
check(refreshed >= 1 and WorldMapFrame:GetMapID() == 1411, "shown: refreshed, map is Durotar's modern ID")

local pool = CreateFramePool("FRAME")
local pinMixin = CreateFromMixins(MapCanvasPinMixin)
pool.createFunc = function() local f = CreateFrame("Frame") return Mixin(f, pinMixin) end
pool.creationFunc = pool.createFunc
WorldMapFrame.pinPools["TestPin"] = pool
function pinMixin:OnAcquired(x, y) self:SetPosition(x, y) end
local pin = WorldMapFrame:AcquirePin("TestPin", 0.25, 0.5)
local point, rel, relPoint, x, y = pin:GetPoint(1)
check(rel == WorldMapButton and math.abs(x - 250) < 1e-6 and math.abs(y + 300) < 1e-6, "pin placed at 25%/50% of the canvas")
local n = 0 for _ in WorldMapFrame:EnumeratePinsByTemplate("TestPin") do n = n + 1 end
check(n == 1, "pin enumerated")
WorldMapFrame:RemoveAllPinsByTemplate("TestPin")
n = 0 for _ in WorldMapFrame:EnumeratePinsByTemplate("TestPin") do n = n + 1 end
check(n == 0, "pins removed")

WorldMapFrame:SetMapID(1414)
check(setTo == 13 and WorldMapFrame:GetMapID() == 1414, "SetMapID shows Kalimdor (record ID 13)")
print("ALL PASSED")
