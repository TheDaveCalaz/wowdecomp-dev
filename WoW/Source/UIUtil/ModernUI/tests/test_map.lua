-- C_Map reads map data directly and speaks modern map IDs; it must never change the open map.
local switched = 0
SetMapByID = function() switched = switched + 1 end
SetMapToCurrentZone = function() switched = switched + 1 end
UnitIsUnit = function(a, b) return a == b end
UnitInParty = function() return false end
UnitInRaid = function() return nil end
local data = {
	[14] = { "Kalimdor", "continent", 0, 1, 12000, -12000, 12000, -12000, 0 },
	[5] = { "Durotar", "zone", 14, 1, -3000, -6000, 1000, -2000, 14 },
	[322] = { "Orgrimmar", "zone", 5, 1, -3800, -5300, 2400, 1000, 1637 },
	[900] = { "Custom", "dungeon", 0, 999, 0, 0, 0, 0, 0 },
}
ModernUI_GetAllMapAreaIDs = function() return 14, 5, 322, 900 end
ModernUI_GetMapAreaInfo = function(id) local d = data[id] if d then return unpack(d) end end
ModernUI_GetPlayerMapAreaID = function() return 5, 0 end
ModernUI_GetUnitMapPosition = function(unit, id) if id == 5 then return 0.25, 0.5 end end
ModernUI_GetAreaName = function(id) return id == 14 and "Durotar" or nil end

local function check(cond, msg) if not cond then error("FAIL " .. msg, 2) end print("ok   " .. msg) end
check(C_Map.GetBestMapForUnit("player") == 1411, "player map is Durotar's modern ID")
check(C_Map.GetMapInfo(1411).parentMapID == 1414, "Durotar's parent is Kalimdor")
check(C_Map.GetMapInfo(1414).mapType == Enum.UIMapType.Continent and C_Map.GetMapInfo(1414).parentMapID == 947, "Kalimdor is a continent under Azeroth")
check(C_Map.GetMapInfo(1454) and C_Map.GetMapInfo(1454).parentMapID == 1411, "Orgrimmar under Durotar")
check(C_Map.GetMapInfo(100900).name == "Custom", "custom map keeps its own number plus 100000")
local children = C_Map.GetMapChildrenInfo(947, nil, true)
check(#children == 3, "Azeroth's descendants: " .. #children)
local pos = C_Map.GetPlayerMapPosition(1411, "player")
check(pos and pos.x == 0.25 and pos.y == 0.5, "player position")
local instance, world = C_Map.GetWorldPosFromMapPos(1411, CreateVector2D(0, 0))
check(instance == 1 and world.x == 1000 and world.y == -3000, "world position of the top-left corner")
local id, back = C_Map.GetMapPosFromWorldPos(1, CreateVector2D(-500, -4500), 1411)
check(id == 1411 and math.abs(back.x - 0.5) < 1e-9 and math.abs(back.y - 0.5) < 1e-9, "world to map")
local w, h = C_Map.GetMapWorldSize(1411)
check(w == 3000 and h == 3000, "world size")
check(C_Map.GetMapParentInfo(1454, Enum.UIMapType.Continent).mapID == 1414, "parent info")
check(C_Map.GetAreaInfo(14) == "Durotar", "area name")
check(switched == 0, "the open map was never changed")
