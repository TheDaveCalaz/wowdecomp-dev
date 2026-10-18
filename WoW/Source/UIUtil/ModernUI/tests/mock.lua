-- Minimal 3.3.5-like environment for testing ModernUI load and behaviour.
local now = 100
function GetTime() return now end
function _advance(dt) now = now + dt end
local frames = {}
local events = {}  -- event -> list of frames
local known = { PLAYER_LOGIN=1, QUEST_QUERY_COMPLETE=1, ADDON_LOADED=1, PARTY_MEMBERS_CHANGED=1, RAID_ROSTER_UPDATE=1,
  UNIT_MANA=1, UNIT_RAGE=1, UNIT_ENERGY=1, UNIT_FOCUS=1, UNIT_RUNIC_POWER=1, UNIT_HAPPINESS=1, UNIT_HEALTH=1,
  UNIT_MAXMANA=1, UNIT_MAXRAGE=1, UNIT_MAXENERGY=1, UNIT_MAXFOCUS=1, UNIT_MAXRUNIC_POWER=1, UNIT_MAXHAPPINESS=1,
  ACTIVE_TALENT_GROUP_CHANGED=1, PLAYER_TALENT_UPDATE=1, BAG_UPDATE=1, PLAYER_LEVEL_UP=1, COMPANION_UPDATE=1,
  PLAYER_ENTERING_WORLD=1, GOSSIP_SHOW=1, GOSSIP_CLOSED=1, QUEST_GREETING=1, QUEST_DETAIL=1, QUEST_PROGRESS=1, QUEST_COMPLETE=1,
  MERCHANT_SHOW=1, MERCHANT_CLOSED=1, TAXIMAP_OPENED=1, TAXIMAP_CLOSED=1, TRAINER_SHOW=1, TRAINER_CLOSED=1,
  BANKFRAME_OPENED=1, BANKFRAME_CLOSED=1, GUILDBANKFRAME_OPENED=1, GUILDBANKFRAME_CLOSED=1, MAIL_SHOW=1, MAIL_CLOSED=1,
  AUCTION_HOUSE_SHOW=1, AUCTION_HOUSE_CLOSED=1, QUEST_FINISHED=1, VARIABLES_LOADED=1 }
function _fire(event, ...)
  for f in pairs(events[event] or {}) do
    local h = f.__scripts.OnEvent
    if h then h(f, event, ...) end
  end
end
function _update(dt)
  _advance(dt)
  for _, f in ipairs(frames) do
    if f.__shown and f.__scripts.OnUpdate then f.__scripts.OnUpdate(f, dt) end
  end
end
local function base()
  local m = {}
  function m:Show() self.__shown = true end
  function m:Hide() self.__shown = false end
  function m:IsShown() return self.__shown end
  function m:SetWidth(w) self.__w = w end
  function m:SetHeight(h) self.__h = h end
  function m:GetWidth() return self.__w or 0 end
  function m:GetHeight() return self.__h or 0 end
  function m:SetPoint(...) table.insert(self.__points, {...}) end
  function m:ClearAllPoints() self.__points = {} end
  function m:GetNumPoints() return #self.__points end
  function m:GetPoint(i) return unpack(self.__points[i]) end
  function m:GetName() return nil end
  function m:SetAlpha() end
  return m
end
local metas = {}
local function meta(kind)
  if not metas[kind] then
    local m = base()
    if kind ~= "Texture" and kind ~= "FontString" and not kind:find("Anim") and kind ~= "Alpha" and kind ~= "Scale" then
      function m:SetScript(s, f) self.__scripts[s] = f end
      function m:GetScript(s) return self.__scripts[s] end
      function m:HookScript(s, f) local o = self.__scripts[s]; self.__scripts[s] = function(...) if o then o(...) end f(...) end end
      function m:RegisterEvent(e) if not known[e] then return false end events[e] = events[e] or {}; events[e][self] = true; return true end
      function m:UnregisterEvent(e) if events[e] then events[e][self] = nil end end
      function m:UnregisterAllEvents() for _, l in pairs(events) do l[self] = nil end end
      function m:IsEventRegistered(e) return events[e] and events[e][self] or false end
      function m:CreateTexture() return _new("Texture") end
      function m:CreateFontString() return _new("FontString") end
      function m:CreateAnimationGroup() return _new("AnimationGroup") end
      function m:EnableMouse(e) self.__mouse = e end
      function m:IsMouseEnabled() return self.__mouse end
      function m:GetFrameLevel() return 1 end
      function m:SetFrameLevel() end
      function m:SetBackdrop(b) self.__backdrop = b end
    end
    if kind == "AnimationGroup" then function m:CreateAnimation(k) if k ~= "Animation" and k ~= "Alpha" and k ~= "Scale" and k ~= "Translation" and k ~= "Rotation" and k ~= "Path" then error("bad anim "..tostring(k)) end return _new(k) end end
    if kind == "Alpha" then function m:SetChange(c) self.__change = c end end
    if kind == "Scale" then function m:SetScale(x, y) self.__scale = {x, y} end end
    if kind == "Texture" then function m:SetTexture(...) self.__tex = {...} end end
    metas[kind] = { __index = m }
  end
  return metas[kind]
end
function _new(kind)
  local o = setmetatable({ __scripts = {}, __points = {}, __shown = true }, meta(kind))
  table.insert(frames, o)
  return o
end
function CreateFrame(kind) if kind == "Bogus" then error("bad type") end return _new(kind) end
function geterrorhandler() return function(e) print("ERRORHANDLER: "..tostring(e)) end end
function securecall(f, ...) return f(...) end
function hooksecurefunc(name, f) local o = _G[name]; _G[name] = function(...) local r = {o(...)}; f(...); return unpack(r) end end
function IsLoggedIn() return false end
function IsAddOnLoaded() return nil end
function strsplit(d, s) local t = {} for p in (s..d):gmatch("(.-)"..d:gsub("%p","%%%0")) do t[#t+1]=p end return unpack(t) end
function GetCVar(n) if n == "gxResolution" then return "1920x1080" end return "EU" end
function GetScreenWidth() return 1024 end
function GetScreenHeight() return 768 end
function GetQuestReward() end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function GetRealmName() return "My Realm" end
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior" }
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
ITEM_QUALITY_COLORS = { [4] = { r = 0.64, g = 0.21, b = 0.93, hex = "|cffa335ee" } }
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
PlaySound = function() return true end
PlaySoundFile = function() return true end
time = os.time
date = os.date
bit = { band = function(a, b) local r, p = 0, 1 while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + p end a = math.floor(a/2) b = math.floor(b/2) p = p * 2 end return r end }
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
GameTooltip = _new("GameTooltip")
WorldFrame = _new("Frame")
