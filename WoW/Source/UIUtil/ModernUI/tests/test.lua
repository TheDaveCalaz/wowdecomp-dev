local fails = 0
local function check(name, cond) if not cond then fails = fails + 1 print("FAIL " .. name) else print("ok   " .. name) end end

-- Timers
local order = {}
C_Timer.After(0, function() order[#order+1] = "a0" end)
C_Timer.After(1, function() order[#order+1] = "a1" C_Timer.After(0, function() order[#order+1] = "nested" end) end)
local ticks = 0
local ticker = C_Timer.NewTicker(0.5, function(t) ticks = ticks + 1 end, 3)
local t2 = C_Timer.NewTimer(2, function() order[#order+1] = "cancelled?" end)
t2:Cancel()
for i = 1, 40 do _update(0.1) end
check("timer order", table.concat(order, ",") == "a0,a1,nested")
check("ticker 3 times", ticks == 3 and ticker:IsCancelled())
check("cancelled timer", t2:IsCancelled())

-- Mixins and colours
local M = { Hello = function(self) return "hi " .. self.n end }
local o = CreateFromMixins(M); o.n = 3
check("mixin", o:Hello() == "hi 3")
local c = CreateColor(1, 0.5, 0, 1)
check("color hex", c:GenerateHexColor() == "ffff7f00" or c:GenerateHexColor() == "ffff8000")
check("color wrap", c:WrapTextInColorCode("x"):find("^|cff") ~= nil)
check("upgraded NORMAL_FONT_COLOR", NORMAL_FONT_COLOR.GetRGB ~= nil)
check("class colour string", RAID_CLASS_COLORS.WARRIOR.colorStr ~= nil)
check("hex parse", CreateColorFromHexString("ff00ff00"):GetRGB() == 0)

-- Pools
local pool = CreateFramePool("Frame", nil, nil)
local f1, new1 = pool:Acquire()
local f2 = pool:Acquire()
check("pool new", new1 == true and pool:GetNumActive() == 2)
pool:Release(f1)
local f3, new3 = pool:Acquire()
check("pool reuse", f3 == f1 and new3 == false)
pool:ReleaseAll()
check("pool release all", pool:GetNumActive() == 0)
local coll = CreateFramePoolCollection()
coll:CreatePool("Frame", nil, "T1")
local x = coll:Acquire("T1")
local count = 0 for _ in coll:EnumerateActive() do count = count + 1 end
check("pool collection", x ~= nil and count == 1)

-- Callback registry
local reg = CreateFromMixins(CallbackRegistryMixin)
reg:OnLoad()
reg:GenerateCallbackEvents({ "Ping" })
local got = {}
local owner = {}
reg:RegisterCallback("Ping", function(own, a, b) got[#got+1] = (own == owner) and (a .. b) or "bad" end, owner)
reg:RegisterCallback("Ping", function(own, extra, a) got[#got+1] = extra .. a end, {}, "E")
reg:TriggerEvent("Ping", "x", "y")
table.sort(got)
check("callbacks", got[1] == "Ex" and got[2] == "xy")
reg:UnregisterCallback("Ping", owner)
got = {}
reg:TriggerEvent("Ping", "x", "y")
check("unregister callback", #got == 1)
local okErr = pcall(reg.TriggerEvent, reg, "Nope")
check("undefined event errors", okErr == false)

-- EventRegistry with game events
local seen
EventRegistry:RegisterFrameEventAndCallback("ADDON_LOADED", function(_, name) seen = name end, "me")
_fire("ADDON_LOADED", "Foo")
check("EventRegistry frame event", seen == "Foo")
local done
EventUtil.ContinueOnAddOnLoaded("Bar", function() done = true end)
_fire("ADDON_LOADED", "Baz")
check("ContinueOnAddOnLoaded waits", not done)
_fire("ADDON_LOADED", "Bar")
check("ContinueOnAddOnLoaded fires", done)

-- Event mapping and unit filters
local fr = CreateFrame("Frame")
local log = {}
fr:SetScript("OnEvent", function(self, event, ...) log[#log+1] = event .. ":" .. table.concat({...}, ",") end)
check("unknown event returns false", fr:RegisterEvent("SOME_RETAIL_ONLY_EVENT") == false)
fr:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
fr:RegisterEvent("GROUP_ROSTER_UPDATE")
fr:RegisterUnitEvent("UNIT_HEALTH", "target")
_fire("UNIT_MANA", "player")
_fire("UNIT_MANA", "party1")
_fire("RAID_ROSTER_UPDATE")
_fire("UNIT_HEALTH", "player")
_fire("UNIT_HEALTH", "target")
check("mapped + filtered events", table.concat(log, "|") == "UNIT_POWER_UPDATE:player,MANA|GROUP_ROSTER_UPDATE:|UNIT_HEALTH:target")
-- handler replaced after wrapping still works
log = {}
fr:SetScript("OnEvent", function(self, event, ...) log[#log+1] = "new:" .. event end)
_fire("PARTY_MEMBERS_CHANGED")
check("SetScript after wrap", log[1] == "new:GROUP_ROSTER_UPDATE")
fr:UnregisterEvent("GROUP_ROSTER_UPDATE")
log = {}
_fire("PARTY_MEMBERS_CHANGED")
check("unregister mapped", #log == 0)
check("GetScript returns handler", type(fr:GetScript("OnEvent")) == "function")

-- Widget methods
local w = CreateFrame("Frame")
w:SetShown(false)
check("SetShown", not w:IsShown())
w:SetSize(10, 20)
check("SetSize", w:GetWidth() == 10 and w:GetHeight() == 20)
w:SetFixedFrameStrata(true)
check("fixed strata", w:HasFixedFrameStrata())
local tex = w:CreateTexture()
tex:SetColorTexture(1, 0, 0)
check("SetColorTexture", tex.__tex[1] == 1 and tex.__tex[4] == 1)
local ag = w:CreateAnimationGroup()
local fb = ag:CreateAnimation("FlipBook")
check("unknown animation type", fb ~= nil)
local a = ag:CreateAnimation("Alpha")
a:SetFromAlpha(0.2) a:SetToAlpha(1)
check("alpha from/to", math.abs(a.__change - 0.8) < 1e-9)
local ev = CreateFrame("EventFrame")
check("EventFrame", ev.RegisterCallback ~= nil)

-- Misc
check("WOW_PROJECT_ID", WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC and WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE)
check("region", GetCurrentRegion() == 3)
local w2, h2 = GetPhysicalScreenSize()
check("screen", w2 == 1920 and h2 == 1080)
check("tInvert", tInvert({ "a", "b" }).b == 2)
check("Enum", Enum.ItemClass.Armor == 4 and Enum.PowerType.RunicPower == 6)
check("addon prefix", C_ChatInfo.RegisterAddonMessagePrefix("Foo") == 0 and C_ChatInfo.IsAddonMessagePrefixRegistered("Foo"))
check("spec by id", select(2, GetSpecializationInfoByID(73)) == "Protection")
check("GenerateClosure", GenerateClosure(function(a, b, c) return a .. b .. c end, "x", "y")("z") == "xyz")
check("Ambiguate", Ambiguate("Bob-MyRealm", "none") == "Bob-MyRealm" and Ambiguate("Bob-MyRealm", "short") == "Bob")
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
