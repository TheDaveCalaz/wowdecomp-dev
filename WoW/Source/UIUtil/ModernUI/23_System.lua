-- ModernUI: built into the client (not in the original 3.3.5a).
-- C_AddOns, C_ChatInfo, C_CVar, C_Map and the smaller C_ namespaces, on this client's own functions.
-- Namespaces for game systems this client does not have at all (talents trees of later
-- expansions, Mythic+, garrisons...) are left undefined, so addons that check for them skip them.

local _G = _G
local type, select, tonumber, tostring, pairs, ipairs, pcall = type, select, tonumber, tostring, pairs, ipairs, pcall

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
	end, ns
end

local function falseFn() return false end
local function nilFn() return nil end
local function emptyFn() return {} end
local function noop() end

-- C_AddOns ---------------------------------------------------------------------------------------

do
	local set = namespace("C_AddOns")

	-- Retail swapped the argument order of the enable-state call; accept both.
	local function exists(addon)
		local ok, name, _, _, _, _, reason = pcall(GetAddOnInfo, addon)
		return ok and name ~= nil and reason ~= "MISSING"
	end
	local function addonArgs(a, b)
		if b ~= nil and type(a) == "string" and exists(b) and not exists(a) then
			return b, a
		end
		return a, b
	end

	set("GetNumAddOns", function() return GetNumAddOns() end)
	set("GetAddOnInfo", function(addon)
		local name, title, notes, enabled, loadable, reason, security = GetAddOnInfo(addon)
		return name, title, notes, loadable and true or false, reason, security, false
	end)
	set("GetAddOnName", function(addon) return (GetAddOnInfo(addon)) end)
	set("GetAddOnTitle", function(addon) return (select(2, GetAddOnInfo(addon))) end)
	set("GetAddOnNotes", function(addon) return (select(3, GetAddOnInfo(addon))) end)
	set("GetAddOnSecurity", function(addon) return (select(7, GetAddOnInfo(addon))) end)
	set("GetAddOnMetadata", function(addon, field) return GetAddOnMetadata(addon, field) end)
	set("DoesAddOnExist", function(addon)
		local name, _, _, _, _, reason = GetAddOnInfo(addon)
		return name ~= nil and reason ~= "MISSING"
	end)
	set("IsAddOnLoaded", function(addon)
		local loaded = IsAddOnLoaded(addon) and true or false
		return loaded, loaded
	end)
	set("IsAddOnLoadOnDemand", function(addon) return IsAddOnLoadOnDemand(addon) and true or false end)
	set("IsAddOnLoadable", function(addon)
		local _, _, _, _, loadable, reason = GetAddOnInfo(addon)
		return loadable and true or false, reason
	end)
	set("LoadAddOn", function(addon) return LoadAddOn(addon) end)
	set("EnableAddOn", function(addon, character) EnableAddOn(addon, character) end)
	set("DisableAddOn", function(addon, character) DisableAddOn(addon, character) end)
	set("EnableAllAddOns", function(character) EnableAllAddOns(character) end)
	set("DisableAllAddOns", function(character) DisableAllAddOns(character) end)
	set("GetAddOnEnableState", function(a, b)
		local addon = addonArgs(a, b)
		if not exists(addon) then
			return Enum.AddOnEnableState.None
		end
		local _, _, _, enabled = GetAddOnInfo(addon)
		return enabled and Enum.AddOnEnableState.All or Enum.AddOnEnableState.None
	end)
	set("GetAddOnDependencies", function(addon) return GetAddOnDependencies(addon) end)
	set("GetAddOnOptionalDependencies", function(addon)
		if GetAddOnOptionalDependencies then
			return GetAddOnOptionalDependencies(addon)
		end
	end)
	set("SaveAddOns", function() if SaveAddOns then SaveAddOns() end end)
	set("ResetAddOns", function() if ResetAddOns then ResetAddOns() end end)
	set("IsAddonVersionCheckEnabled", falseFn)
	set("SetAddonVersionCheck", noop)
	set("GetScriptsDisallowedForBeta", falseFn)
	set("GetAddOnLocalTable", nilFn)
	set("IsAddOnDefaultEnabled", function() return true end)
end

-- C_ChatInfo -------------------------------------------------------------------------------------
-- 3.3.5 delivers every addon message; prefixes need no registering, but the list is kept so the
-- "is it registered" questions get the answer modern code expects.

do
	local set = namespace("C_ChatInfo")
	local prefixes = {}

	local function chatType(kind)
		if kind == "INSTANCE_CHAT" then
			local _, instanceType = IsInInstance()
			return instanceType == "pvp" and "BATTLEGROUND" or (GetNumRaidMembers() > 0 and "RAID" or "PARTY")
		end
		return kind
	end

	set("RegisterAddonMessagePrefix", function(prefix)
		if type(prefix) ~= "string" or #prefix == 0 or #prefix > 16 then
			return Enum.RegisterAddonMessagePrefixResult.InvalidPrefix
		end
		prefixes[prefix] = true
		return Enum.RegisterAddonMessagePrefixResult.Success
	end)
	set("IsAddonMessagePrefixRegistered", function(prefix) return prefixes[prefix] == true end)
	set("GetRegisteredAddonMessagePrefixes", function()
		local list = {}
		for prefix in pairs(prefixes) do
			list[#list + 1] = prefix
		end
		return list
	end)
	set("SendAddonMessage", function(prefix, message, kind, target)
		local ok = pcall(SendAddonMessage, prefix, message, chatType(kind), target)
		return ok and Enum.SendAddonMessageResult.Success or Enum.SendAddonMessageResult.GeneralError
	end)
	set("SendAddonMessageLogged", function(...) return C_ChatInfo.SendAddonMessage(...) end)
	set("SendChatMessage", function(message, kind, language, target) SendChatMessage(message, chatType(kind), language, target) end)
	set("InChatMessagingLockdown", falseFn)
	set("IsChatLineCensored", falseFn)
	set("GetChannelInfoFromIdentifier", nilFn)
	set("GetChannelRosterInfo", nilFn)
	set("GetNumActiveChannels", function() return (select("#", GetChannelList())) / 2 end)
	set("GetChannelShortcut", function(index) return tostring(index) end)
	set("IsTimerunningPlayer", falseFn)
	set("IsValidChatLine", function() return true end)
	set("ReplaceIconAndGroupExpressions", function(text) return text end)
	set("GetChatTypeName", function(kind) return kind end)
	set("CanPlayerSpeakLanguage", function() return true end)
	set("GetLanguageName", function(id) return nil end)
	set("IsPartyChannelType", falseFn)
	set("IsRegionalServiceAvailable", falseFn)

	if _G.RegisterAddonMessagePrefix == nil then
		_G.RegisterAddonMessagePrefix = C_ChatInfo.RegisterAddonMessagePrefix
	end
	if _G.IsAddonMessagePrefixRegistered == nil then
		_G.IsAddonMessagePrefixRegistered = C_ChatInfo.IsAddonMessagePrefixRegistered
	end
end

-- C_CVar -----------------------------------------------------------------------------------------

do
	local set = namespace("C_CVar")
	set("GetCVar", function(name)
		local ok, value = pcall(GetCVar, name)
		return ok and value or nil
	end)
	set("SetCVar", function(name, value)
		if type(value) == "boolean" then
			value = value and "1" or "0"
		end
		return (pcall(SetCVar, name, value))
	end)
	set("GetCVarBool", function(name)
		local ok, value = pcall(GetCVarBool, name)
		return ok and value and true or false
	end)
	set("GetCVarDefault", function(name)
		if GetCVarDefault then
			local ok, value = pcall(GetCVarDefault, name)
			return ok and value or nil
		end
	end)
	set("RegisterCVar", function(name, default)
		if RegisterCVar then
			pcall(RegisterCVar, name, default)
		end
	end)
	set("GetCVarInfo", function(name)
		local value = C_CVar.GetCVar(name)
		if value == nil then
			return nil
		end
		return value, C_CVar.GetCVarDefault(name), false, false, false, false, false
	end)
	set("ResetTestCVars", noop)
end

-- C_Map -------------------------------------------------------------------------------------------

do
	local set = namespace("C_Map")

	-- Map IDs. Modern addons use the Wrath Classic map IDs (uiMapID: Elwynn Forest 1429, Borean Tundra 114);
	-- this client numbers its maps differently (GetCurrentMapAreaID). Each of this client's maps is given
	-- its modern ID through its AreaTable area; maps with no modern counterpart keep their own number
	-- plus 100000. Every lookup reads the map data directly: the open world map is never changed.
	local COSMIC, AZEROTH = 946, 947
	local CONTINENT_UIMAP = { [1] = 1414, [0] = 1415, [530] = 1945, [571] = 113 }
	local AREA_UIMAP = {
		[1]=1426,[3]=1418,[4]=1419,[8]=1435,[10]=1431,[11]=1437,[12]=1429,[14]=1411,[15]=1445,[16]=1447,[17]=1413,
		[28]=1422,[33]=1434,[36]=1416,[38]=1432,[40]=1436,[41]=1430,[44]=1433,[45]=1417,[46]=1428,[47]=1425,[51]=1427,
		[65]=115,[66]=121,[67]=120,[85]=1420,[130]=1421,[139]=1423,[141]=1438,[148]=1439,[206]=133,[209]=310,
		[210]=118,[215]=1412,[267]=1424,[331]=1440,[357]=1444,[361]=1448,[394]=116,[400]=1441,[405]=1443,[406]=1442,
		[440]=1446,[490]=1449,[491]=301,[493]=1450,[495]=117,[616]=198,[618]=1452,[717]=225,[718]=279,[719]=221,
		[721]=226,[722]=300,[796]=302,[1037]=293,[1176]=219,[1196]=137,[1337]=230,[1377]=1451,[1477]=220,[1497]=1458,
		[1519]=1453,[1537]=1455,[1581]=291,[1583]=253,[1584]=242,[1637]=1454,[1638]=1456,[1657]=1457,[2017]=317,
		[2057]=306,[2100]=280,[2159]=248,[2366]=273,[2367]=274,[2437]=213,[2557]=234,[2597]=1459,[2677]=287,
		[2717]=232,[2817]=127,[3277]=1460,[3358]=1461,[3428]=320,[3429]=247,[3430]=1941,[3433]=1942,[3456]=166,
		[3457]=350,[3483]=1944,[3487]=1954,[3518]=1951,[3519]=1952,[3520]=1948,[3521]=1946,[3522]=1949,[3523]=1953,
		[3524]=1943,[3525]=1950,[3537]=114,[3557]=1947,[3562]=347,[3606]=329,[3607]=332,[3703]=1955,[3711]=119,
		[3713]=261,[3714]=246,[3715]=263,[3716]=262,[3717]=265,[3789]=260,[3790]=256,[3791]=258,[3792]=272,[3805]=333,
		[3820]=1956,[3836]=331,[3845]=334,[3847]=266,[3848]=269,[3849]=267,[3923]=330,[3959]=339,[3979]=113,
		[4075]=335,[4080]=1957,[4095]=349,[4100]=130,[4120]=370,[4131]=349,[4196]=160,[4197]=123,[4228]=143,
		[4264]=140,[4265]=129,[4272]=138,[4273]=147,[4277]=159,[4298]=124,[4384]=128,[4395]=125,[4415]=168,[4416]=154,
		[4493]=155,[4494]=132,[4500]=141,[4560]=126,[4603]=156,[4657]=148,[4706]=217,[4707]=174,[4709]=199,[4710]=169,
		[4714]=179,[4720]=174,[4722]=172,[4723]=171,[4737]=194,[4742]=170,[4755]=202,[4809]=183,[4812]=186,[4813]=184,
		[4815]=201,[4820]=185,[4922]=241,[4926]=283,[4945]=297,[4950]=293,[4987]=200,[5004]=322,[5031]=206,[5034]=249,
		[5035]=325,[5042]=207,[5088]=324,[5094]=286,[5095]=244,[5144]=205,[5145]=204,[5146]=203,[5287]=210,[5334]=294,
		[5339]=224,[5351]=218,[5389]=245,[5396]=277,[5399]=282,[5416]=276,[5449]=275,[5638]=328,[5695]=327,[5723]=367,
		[5733]=338,[5786]=370,[5788]=398,[5789]=401,[5790]=403,[5792]=404,[5793]=402,[5794]=405,[5795]=406,[5844]=399,
		[5861]=407,[5892]=409,[6170]=425,[6176]=427,[6450]=460,[6451]=461,[6452]=462,[6453]=463,[6454]=465,[6455]=467,
		[6456]=468,[6457]=469,
	}
	local CUSTOM_BASE = 100000

	local maps -- uiMapID -> { legacy, name, mapType, parent, instance, left, right, top, bottom, area }
	local byLegacy -- legacy ID -> uiMapID

	local function load()
		if maps then
			return
		end
		maps, byLegacy = {}, {}
		maps[COSMIC] = { name = "Cosmic", mapType = Enum.UIMapType.Cosmic, parent = 0, instance = -1 }
		maps[AZEROTH] = { name = "Azeroth", mapType = Enum.UIMapType.World, parent = COSMIC, instance = 0 }
		maps[COSMIC].name = WORLD_MAP or "World"
		local legacyIDs = {}
		if ModernUI_GetAllMapAreaIDs then
			legacyIDs = { ModernUI_GetAllMapAreaIDs() }
		end
		local info = {}
		for _, legacy in ipairs(legacyIDs) do
			local name, kind, parent, instance, left, right, top, bottom, area = ModernUI_GetMapAreaInfo(legacy)
			if name then
				local uiMapID
				if kind == "continent" then
					uiMapID = CONTINENT_UIMAP[instance]
				else
					uiMapID = AREA_UIMAP[area]
				end
				if not uiMapID or maps[uiMapID] then
					uiMapID = CUSTOM_BASE + legacy
				end
				byLegacy[legacy] = uiMapID
				local mapType = kind == "continent" and Enum.UIMapType.Continent
					or kind == "zone" and Enum.UIMapType.Zone or Enum.UIMapType.Dungeon
				maps[uiMapID] = { legacy = legacy, name = name, mapType = mapType, instance = instance,
					left = left, right = right, top = top, bottom = bottom, area = area }
				info[uiMapID] = parent
			end
		end
		for uiMapID, parent in pairs(info) do
			local map = maps[uiMapID]
			if map.mapType == Enum.UIMapType.Continent then
				map.parent = map.instance == 530 and COSMIC or AZEROTH
			else
				map.parent = parent and parent > 0 and byLegacy[parent] or 0
			end
		end
	end

	local function mapInfo(uiMapID, map)
		return { mapID = uiMapID, name = map.name or "", mapType = map.mapType, parentMapID = map.parent or 0, flags = 0 }
	end

	local function hasBounds(map)
		return map.left and (map.left ~= 0 or map.right ~= 0) and map.left ~= map.right and map.top ~= map.bottom
	end

	-- Translation for code that mixes the two numberings.
	_G.ModernUI_GetUIMapIDFromAreaID = function(legacy)
		load()
		return byLegacy[legacy]
	end
	_G.ModernUI_GetAreaIDFromUIMapID = function(uiMapID)
		load()
		local map = maps[uiMapID]
		return map and map.legacy
	end

	set("GetBestMapForUnit", function(unit)
		if not unit or not (UnitIsUnit(unit, "player") or UnitInParty(unit) or UnitInRaid(unit)) then
			return nil
		end
		load()
		local legacy = ModernUI_GetPlayerMapAreaID()
		if not legacy then
			return nil
		end
		if not UnitIsUnit(unit, "player") then
			-- A group member: their own zone when the client knows it, else the player's.
			local x = ModernUI_GetUnitMapPosition(unit, legacy)
			if not x then
				return nil
			end
		end
		return byLegacy[legacy]
	end)
	set("GetMapInfo", function(uiMapID)
		load()
		local map = uiMapID and maps[uiMapID]
		return map and mapInfo(uiMapID, map) or nil
	end)
	set("GetMapChildrenInfo", function(uiMapID, mapType, allDescendants)
		load()
		local list = {}
		local function collect(parent)
			for id, map in pairs(maps) do
				if map.parent == parent and id ~= parent then
					if not mapType or map.mapType == mapType then
						list[#list + 1] = mapInfo(id, map)
					end
					if allDescendants then
						collect(id)
					end
				end
			end
		end
		if uiMapID then
			collect(uiMapID)
		end
		table.sort(list, function(a, b) return a.mapID < b.mapID end)
		return list
	end)
	set("GetMapParentInfo", function(uiMapID, mapType, topMost)
		load()
		local found
		local map = maps[uiMapID]
		while map and map.parent and map.parent ~= 0 do
			local parent = maps[map.parent]
			if not parent then
				break
			end
			if parent.mapType == mapType then
				found = mapInfo(map.parent, parent)
				if not topMost then
					break
				end
			end
			map = parent
		end
		return found
	end)
	set("GetPlayerMapPosition", function(uiMapID, unit)
		load()
		local map = uiMapID and maps[uiMapID]
		if not map or not map.legacy then
			return nil
		end
		local x, y = ModernUI_GetUnitMapPosition(unit or "player", map.legacy)
		return x and CreateVector2D(x, y) or nil
	end)
	set("GetWorldPosFromMapPos", function(uiMapID, mapPosition)
		load()
		local map = uiMapID and maps[uiMapID]
		if not map or not hasBounds(map) or not mapPosition then
			return nil
		end
		local x, y = mapPosition.x or 0, mapPosition.y or 0
		local worldX = map.top - y * (map.top - map.bottom)
		local worldY = map.left - x * (map.left - map.right)
		return map.instance, CreateVector2D(worldX, worldY)
	end)
	set("GetMapPosFromWorldPos", function(instance, worldPosition, uiMapID)
		load()
		if not worldPosition then
			return nil
		end
		local function try(id, map)
			if map and hasBounds(map) and map.instance == instance then
				local x = (map.left - worldPosition.y) / (map.left - map.right)
				local y = (map.top - worldPosition.x) / (map.top - map.bottom)
				if uiMapID or (x >= 0 and x <= 1 and y >= 0 and y <= 1) then
					return id, CreateVector2D(x, y)
				end
			end
		end
		if uiMapID then
			return try(uiMapID, maps[uiMapID])
		end
		for _, kind in ipairs({ Enum.UIMapType.Zone, Enum.UIMapType.Continent }) do
			for id, map in pairs(maps) do
				if map.mapType == kind then
					local found, position = try(id, map)
					if found then
						return found, position
					end
				end
			end
		end
		return nil
	end)
	set("GetMapWorldSize", function(uiMapID)
		load()
		local map = uiMapID and maps[uiMapID]
		if not map or not hasBounds(map) then
			return 0, 0
		end
		return map.left - map.right, map.top - map.bottom
	end)
	set("GetMapRectOnMap", function(uiMapID, topUiMapID)
		load()
		local map, top = maps[uiMapID], maps[topUiMapID]
		if not map or not top or not hasBounds(map) or not hasBounds(top) or map.instance ~= top.instance then
			return 0, 0, 0, 0
		end
		local width, height = top.left - top.right, top.top - top.bottom
		local minX = (top.left - map.left) / width
		local maxX = (top.left - map.right) / width
		local minY = (top.top - map.top) / height
		local maxY = (top.top - map.bottom) / height
		return minX, maxX, minY, maxY
	end)
	set("GetAreaInfo", function(areaID)
		return areaID and ModernUI_GetAreaName(areaID) or nil
	end)
	set("GetMapGroupID", nilFn)
	set("GetMapGroupMembersInfo", nilFn)
	set("GetMapArtID", nilFn)
	set("GetMapLevels", function() return 0, 0, 0, 0 end)
	set("GetFallbackWorldMapID", function() return AZEROTH end)
	set("MapHasArt", function(uiMapID) load() return maps[uiMapID] ~= nil end)
	set("IsMapValidForNavBarDropDown", function() return true end)
	set("GetMapDisplayInfo", function() return false end)
	set("GetMapHighlightInfoAtPosition", nilFn)
	set("GetMapLinksForMap", emptyFn)
	set("GetMapInfoAtPosition", function(uiMapID, x, y)
		load()
		local instance, world = C_Map.GetWorldPosFromMapPos(uiMapID, CreateVector2D(x, y))
		if not world then
			return nil
		end
		local found = C_Map.GetMapPosFromWorldPos(instance, world)
		return found and C_Map.GetMapInfo(found) or nil
	end)
	set("GetMapBannersForMap", emptyFn)

	local waypoint
	set("CanSetUserWaypointOnMap", falseFn)
	set("SetUserWaypoint", function(point) waypoint = point end)
	set("ClearUserWaypoint", function() waypoint = nil end)
	set("GetUserWaypoint", function() return waypoint end)
	set("HasUserWaypoint", function() return waypoint ~= nil end)
	set("GetUserWaypointPositionForMap", nilFn)
	set("GetUserWaypointHyperlink", nilFn)
	set("GetUserWaypointFromHyperlink", nilFn)

	if _G.UiMapPoint == nil then
		_G.UiMapPoint = {
			CreateFromCoordinates = function(_, mapID, x, y, z)
				return { uiMapID = mapID, position = CreateVector2D(x, y), z = z }
			end,
			CreateFromVector2D = function(_, mapID, position, z)
				return { uiMapID = mapID, position = position, z = z }
			end,
		}
	end
end

-- C_FriendList -----------------------------------------------------------------------------------

do
	local set = namespace("C_FriendList")
	local function friendInfo(index)
		local name, level, className, area, connected, status, notes = GetFriendInfo(index)
		if not name then
			return nil
		end
		return {
			name = name, level = level or 0, className = className, area = area, connected = connected and true or false,
			notes = notes, guid = nil, afk = status == CHAT_FLAG_AFK, dnd = status == CHAT_FLAG_DND,
			isReferAFriend = false, mobile = false,
		}
	end
	set("GetNumFriends", function() return (GetNumFriends()) end)
	set("GetNumOnlineFriends", function() return (select(2, GetNumFriends())) end)
	set("GetFriendInfoByIndex", friendInfo)
	set("GetFriendInfo", function(name)
		for i = 1, GetNumFriends() do
			if GetFriendInfo(i) == name then
				return friendInfo(i)
			end
		end
	end)
	set("IsFriend", function(guidOrName)
		for i = 1, GetNumFriends() do
			if GetFriendInfo(i) == guidOrName then
				return true
			end
		end
		return false
	end)
	set("AddFriend", function(name, notes) AddFriend(name) end)
	set("RemoveFriend", function(name) RemoveFriend(name) end)
	set("ShowFriends", function() ShowFriends() end)
	set("SetFriendNotes", function(name, notes) SetFriendNotes(name, notes) end)
	set("GetNumIgnores", function() return GetNumIgnores() end)
	set("GetIgnoreName", function(index) return GetIgnoreName(index) end)
	set("AddIgnore", function(name) AddIgnore(name) end)
	set("DelIgnore", function(name) DelIgnore(name) end)
	set("IsIgnored", function(name)
		for i = 1, GetNumIgnores() do
			if GetIgnoreName(i) == name then
				return true
			end
		end
		return false
	end)
	set("IsIgnoredByGuid", falseFn)
	set("IsOnIgnoredList", function(name) return C_FriendList.IsIgnored(name) end)
	set("SendWho", function(filter) SendWho(filter) end)
	set("GetNumWhoResults", function() return GetNumWhoResults() end)
	set("GetWhoInfo", function(index)
		local name, guild, level, race, class, zone, classFile = GetWhoInfo(index)
		if not name then
			return nil
		end
		return { fullName = name, fullGuildName = guild, level = level, raceStr = race, classStr = class, area = zone, filename = classFile, gender = nil }
	end)
	set("SetWhoToUi", function(toUi) SetWhoToUI(toUi and 1 or 0) end)
end

-- C_CurrencyInfo ---------------------------------------------------------------------------------
-- 3.3.5 currencies are items; the item ID stands in for the currency ID.

do
	local set = namespace("C_CurrencyInfo")
	local function listInfo(index)
		local name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon, itemID = GetCurrencyListInfo(index)
		if not name then
			return nil
		end
		return {
			name = name, isHeader = isHeader and true or false, isHeaderExpanded = isExpanded and true or false,
			isTypeUnused = isUnused and true or false, isShowInBackpack = isWatched and true or false,
			quantity = count or 0, trackedQuantity = 0, iconFileID = icon, maxQuantity = 0, canEarnPerWeek = false,
			quantityEarnedThisWeek = 0, isTradeable = false, quality = 1, maxWeeklyQuantity = 0, totalEarned = 0,
			discovered = true, useTotalEarnedForMaxQty = false, currencyID = itemID,
		}
	end
	set("GetCurrencyListSize", function() return GetCurrencyListSize() end)
	set("GetCurrencyListInfo", listInfo)
	set("GetCurrencyListLink", function(index)
		local itemID = select(9, GetCurrencyListInfo(index))
		return itemID and (select(2, GetItemInfo(itemID)))
	end)
	set("ExpandCurrencyList", function(index, expand) ExpandCurrencyList(index, expand and 1 or 0) end)
	set("GetCurrencyInfo", function(currencyID)
		for i = 1, GetCurrencyListSize() do
			local info = listInfo(i)
			if info and not info.isHeader and info.currencyID == currencyID then
				return info
			end
		end
	end)
	set("GetCurrencyLink", function(currencyID) return (select(2, GetItemInfo(currencyID))) end)
	set("GetCurrencyIDFromLink", function(link) return link and tonumber(link:match("item:(%d+)")) end)
	set("GetCurrencyInfoFromLink", function(link)
		local id = C_CurrencyInfo.GetCurrencyIDFromLink(link)
		return id and C_CurrencyInfo.GetCurrencyInfo(id)
	end)
	set("GetBackpackCurrencyInfo", function(index)
		local name, count, extraCurrencyType, icon, itemID = GetBackpackCurrencyInfo(index)
		if not name then
			return nil
		end
		return { name = name, quantity = count, iconFileID = icon, currencyTypesID = itemID }
	end)
	set("GetCoinIcon", function(amount)
		if amount >= 10000 then
			return "Interface\\MoneyFrame\\UI-GoldIcon"
		elseif amount >= 100 then
			return "Interface\\MoneyFrame\\UI-SilverIcon"
		end
		return "Interface\\MoneyFrame\\UI-CopperIcon"
	end)
	set("GetCoinText", function(amount) return GetCoinText(amount, " ") end)
	set("GetCoinTextureString", function(amount) return GetCoinTextureString(amount) end)
	set("GetFactionGrantedByCurrency", nilFn)
	set("GetCurrencyContainerInfo", nilFn)
	set("IsAccountCharacterCurrencyDataReady", falseFn)
	set("RequestCurrencyDataForAccountCharacters", noop)
	set("FetchCurrencyDataFromAccountCharacters", emptyFn)
	set("IsAccountTransferableCurrency", falseFn)
	set("GetWarResourcesCurrencyID", nilFn)
	set("GetAzeriteCurrencyID", nilFn)
end

-- C_Reputation -----------------------------------------------------------------------------------

do
	local set = namespace("C_Reputation")
	local function factionData(index)
		local name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(index)
		if not name then
			return nil
		end
		return {
			factionID = 0, name = name, description = description, reaction = standingID,
			currentReactionThreshold = barMin, nextReactionThreshold = barMax, currentStanding = barValue,
			atWarWith = atWarWith and true or false, canToggleAtWar = canToggleAtWar and true or false,
			isChild = isChild and true or false, isHeader = isHeader and true or false,
			isHeaderWithRep = hasRep and true or false, isCollapsed = isCollapsed and true or false,
			isWatched = isWatched and true or false, hasBonusRepGain = false, canSetInactive = true, isAccountWide = false,
		}
	end
	set("GetNumFactions", function() return GetNumFactions() end)
	set("GetFactionDataByIndex", factionData)
	set("GetFactionDataByID", nilFn)
	set("GetWatchedFactionData", function()
		local name, standingID, barMin, barMax, barValue = GetWatchedFactionInfo()
		if not name then
			return nil
		end
		return {
			factionID = 0, name = name, reaction = standingID, currentReactionThreshold = barMin,
			nextReactionThreshold = barMax, currentStanding = barValue, isWatched = true,
		}
	end)
	set("ExpandFactionHeader", function(index) ExpandFactionHeader(index) end)
	set("CollapseFactionHeader", function(index) CollapseFactionHeader(index) end)
	set("ExpandAllFactionHeaders", function() ExpandFactionHeader(0) end)
	set("CollapseAllFactionHeaders", function() CollapseFactionHeader(0) end)
	set("SetWatchedFactionByIndex", function(index) SetWatchedFactionIndex(index) end)
	set("IsFactionActive", function(index) return not IsFactionInactive(index) end)
	set("SetFactionActive", function(index, active) if active then SetFactionActive(index) else SetFactionInactive(index) end end)
	set("IsFactionParagon", falseFn)
	set("IsMajorFaction", falseFn)
	set("IsAccountWideReputation", falseFn)
	set("GetFactionParagonInfo", nilFn)
	set("AreLegacyReputationsShown", function() return true end)
	set("SetLegacyReputationsShown", noop)
	set("GetReputationSortType", function() return 0 end)
	set("SetReputationSortType", noop)
	set("GetGuildFactionData", nilFn)
end

-- C_SpecializationInfo, C_CreatureInfo --------------------------------------------------------------

do
	local set = namespace("C_SpecializationInfo")
	set("GetSpecialization", function(...) return GetSpecialization(...) end)
	set("GetSpecializationInfo", function(...) return GetSpecializationInfo(...) end)
	set("GetActiveSpecGroup", function(...) return GetActiveSpecGroup(...) end)
	set("GetNumSpecializationsForClassID", function(classID) return GetNumSpecializationsForClassID(classID) end)
	set("GetTalentInfo", nilFn)
	set("GetPvpTalentSlotInfo", nilFn)
	set("CanPlayerUsePVPTalentUI", falseFn)
	set("CanPlayerUseTalentSpecUI", function() return true end)
	set("CanPlayerUseTalentUI", function() return true end)
	set("IsInitialized", function() return true end)
end

do
	local set = namespace("C_CreatureInfo")
	set("GetClassInfo", function(classID)
		local name, file, id = GetClassInfo(classID)
		return name and { className = name, classFile = file, classID = id }
	end)
	set("GetRaceInfo", function(raceID)
		local race = ModernUI_SpecData.races[raceID]
		return race and { raceName = race[1], clientFileString = race[2], raceID = raceID }
	end)
	set("GetFactionInfo", function(raceID)
		local alliance = { [1] = true, [3] = true, [4] = true, [7] = true, [11] = true }
		if not ModernUI_SpecData.races[raceID] then
			return nil
		end
		local group = alliance[raceID] and "Alliance" or "Horde"
		return { name = _G["FACTION_" .. group:upper()] or group, groupTag = group }
	end)
	set("GetCreatureTypeIDs", emptyFn)
	set("GetCreatureTypeInfo", nilFn)
	set("GetCreatureFamilyIDs", emptyFn)
	set("GetCreatureFamilyInfo", nilFn)
end

-- C_DateAndTime, C_Calendar -------------------------------------------------------------------------

do
	local set = namespace("C_DateAndTime")
	local function now()
		local weekday, month, day, year = CalendarGetDate()
		local hour, minute = GetGameTime()
		return { year = year, month = month, monthDay = day, weekday = weekday, hour = hour, minute = minute }
	end
	set("GetCurrentCalendarTime", now)
	set("GetTodaysDate", now)
	set("GetServerTimeLocal", function() return time() end)
	set("GetSecondsUntilDailyReset", function() return GetQuestResetTime() end)
	set("GetSecondsUntilWeeklyReset", nilFn)
	set("AdjustTimeByDays", function(when, days)
		local t = time({ year = when.year, month = when.month, day = when.monthDay + days, hour = when.hour, min = when.minute })
		local d = date("*t", t)
		return { year = d.year, month = d.month, monthDay = d.day, weekday = d.wday, hour = d.hour, minute = d.min }
	end)
	set("CompareCalendarTime", function(lhs, rhs)
		local function key(d) return ((((d.year * 100 + d.month) * 100 + d.monthDay) * 100 + d.hour) * 100 + d.minute) end
		local a, b = key(lhs), key(rhs)
		return a < b and 1 or (a > b and -1 or 0)
	end)
end

do
	local set = namespace("C_Calendar")
	set("GetNumDayEvents", function(monthOffset, day) return CalendarGetNumDayEvents(monthOffset, day) end)
	set("GetHolidayInfo", function(monthOffset, day, index)
		local name, description, texture = CalendarGetHolidayInfo(monthOffset, day, index)
		return name and { name = name, description = description, texture = texture }
	end)
	set("GetDate", function()
		local weekday, month, day, year = CalendarGetDate()
		return { weekday = weekday, month = month, monthDay = day, year = year }
	end)
	set("OpenCalendar", function() OpenCalendar() end)
end

-- C_PvP, C_EquipmentSet, C_MountJournal, C_PetJournal -------------------------------------------------

do
	local set = namespace("C_PvP")
	set("GetZonePVPInfo", function() return GetZonePVPInfo() end)
	set("IsPVPMap", function() local _, t = IsInInstance() return t == "pvp" or t == "arena" end)
	set("IsBattleground", function() local _, t = IsInInstance() return t == "pvp" end)
	set("IsArena", function() local _, t = IsInInstance() return t == "arena" end)
	set("IsRatedArena", falseFn)
	set("IsRatedBattleground", falseFn)
	set("IsRatedMap", falseFn)
	set("IsWarModeDesired", falseFn)
	set("IsWarModeActive", falseFn)
	set("IsWarModeFeatureEnabled", falseFn)
	set("IsInBrawl", falseFn)
	set("IsSoloShuffle", falseFn)
	set("IsInRatedMatchWithDeserterPenalty", falseFn)
	set("GetScoreInfo", nilFn)
	set("GetActiveMatchState", function() return 0 end)
end

do
	local set = namespace("C_EquipmentSet")
	set("GetNumEquipmentSets", function() return GetNumEquipmentSets() end)
	set("GetEquipmentSetIDs", function()
		local list = {}
		for i = 1, GetNumEquipmentSets() do
			list[i] = i
		end
		return list
	end)
	set("GetEquipmentSetID", function(name)
		for i = 1, GetNumEquipmentSets() do
			if GetEquipmentSetInfo(i) == name then
				return i
			end
		end
	end)
	set("GetEquipmentSetInfo", function(setID)
		local name, icon = GetEquipmentSetInfo(setID)
		if not name then
			return nil
		end
		local ids = GetEquipmentSetItemIDs(name) or {}
		local numItems, numEquipped = 0, 0
		for slot, itemID in pairs(ids) do
			if itemID and itemID > 1 then
				numItems = numItems + 1
				if GetInventoryItemID("player", slot) == itemID then
					numEquipped = numEquipped + 1
				end
			end
		end
		return name, icon, setID, numItems > 0 and numItems == numEquipped, numItems, numEquipped, 0, 0, 0
	end)
	set("GetItemIDs", function(setID)
		local name = GetEquipmentSetInfo(setID)
		return name and GetEquipmentSetItemIDs(name) or {}
	end)
	set("GetItemLocations", function(setID)
		local name = GetEquipmentSetInfo(setID)
		return name and GetEquipmentSetLocations(name) or {}
	end)
	set("UseEquipmentSet", function(setID)
		local name = GetEquipmentSetInfo(setID)
		if name then
			UseEquipmentSet(name)
			return true
		end
		return false
	end)
	set("CanUseEquipmentSets", function() return CanUseEquipmentSets and CanUseEquipmentSets() or true end)
	set("EquipmentSetContainsLockedItems", falseFn)
	set("GetIgnoredSlots", emptyFn)
	set("IsSlotIgnoredForSave", falseFn)
end

do
	local set = namespace("C_MountJournal")
	local function info(index)
		local creatureID, name, spellID, icon, active = GetCompanionInfo("MOUNT", index)
		if not name then
			return nil
		end
		return name, spellID, icon, active and true or false, true, 0, false, false, nil, false, true, index, false
	end
	set("GetNumMounts", function() return GetNumCompanions("MOUNT") end)
	set("GetNumDisplayedMounts", function() return GetNumCompanions("MOUNT") end)
	set("GetMountIDs", function()
		local list = {}
		for i = 1, GetNumCompanions("MOUNT") do
			list[i] = i
		end
		return list
	end)
	set("GetMountInfoByID", info)
	set("GetDisplayedMountInfo", info)
	set("GetMountInfoExtraByID", function(index)
		local creatureID = GetCompanionInfo("MOUNT", index)
		return creatureID, "", "", false, 0, 0, nil, false
	end)
	set("GetMountFromSpell", function(spellID)
		for i = 1, GetNumCompanions("MOUNT") do
			if select(3, GetCompanionInfo("MOUNT", i)) == spellID then
				return i
			end
		end
	end)
	set("SummonByID", function(index) CallCompanion("MOUNT", index) end)
	set("Dismiss", function() Dismount() end)
	set("GetIsFavorite", falseFn)
	set("SetIsFavorite", noop)
	set("NeedsFanfare", falseFn)
end

do
	local set = namespace("C_PetJournal")
	set("GetNumPets", function()
		local n = GetNumCompanions("CRITTER")
		return n, n
	end)
	set("GetPetInfoByPetID", nilFn)
	set("GetPetInfoBySpeciesID", nilFn)
	set("FindPetIDByName", nilFn)
	set("GetSummonedPetGUID", nilFn)
	set("PetIsSummonable", falseFn)
end

-- Small namespaces: systems this client has no part of, answered "not active". -------------------

do
	local set = namespace("C_Scenario")
	set("IsInScenario", falseFn)
	set("GetInfo", nilFn)
	set("GetStepInfo", nilFn)
	set("GetCriteriaInfo", nilFn)
end
do
	local set = namespace("C_ChallengeMode")
	set("IsChallengeModeActive", falseFn)
	set("GetActiveKeystoneInfo", function() return 0, {}, false end)
	set("GetMapTable", emptyFn)
	set("GetAffixInfo", nilFn)
	set("GetActiveChallengeMapID", nilFn)
end
do
	local set = namespace("C_PetBattles")
	set("IsInBattle", falseFn)
	set("IsWildBattle", falseFn)
	set("IsPlayerNPC", falseFn)
end
do
	local set = namespace("C_ActionBar")
	set("HasOverrideActionBar", falseFn)
	set("HasVehicleActionBar", function() return UnitHasVehicleUI("player") and true or false end)
	set("HasBonusActionBar", function() return GetBonusBarOffset() > 0 end)
	set("HasPossessActionBar", function() return IsPossessBarVisible() and true or false end)
	set("IsOnBarOrSpecialBar", falseFn)
	set("FindSpellActionButtons", emptyFn)
	set("GetBonusBarIndex", function() return GetBonusBarOffset() end)
end
do
	local set = namespace("C_PartyInfo")
	set("DoCountdown", noop)
	set("IsPartyFull", function() return GetNumPartyMembers() >= 4 end)
	set("InviteUnit", function(name) InviteUnit(name) end)
	set("LeaveParty", function() LeaveParty() end)
	set("ConvertToRaid", function() ConvertToRaid() end)
	set("IsPartyWalkIn", falseFn)
	set("GetMinLevel", function() return 1 end)
end
do
	local set = namespace("C_InstanceEncounter")
	set("IsEncounterInProgress", falseFn)
end
do
	local set = namespace("C_GameRules")
	set("IsHardcoreActive", falseFn)
	set("IsSelfFoundAllowed", falseFn)
	set("IsGameRuleActive", falseFn)
	set("GetGameRuleAsFloat", function() return 0 end)
end
do
	local set = namespace("C_Seasons")
	set("HasActiveSeason", falseFn)
	set("GetActiveSeason", nilFn)
end
do
	local set = namespace("C_Engraving")
	set("IsEngravingEnabled", falseFn)
end
do
	local set = namespace("C_Secrets")
	set("ShouldAurasBeSecret", falseFn)
	set("ShouldCooldownsBeSecret", falseFn)
	set("ShouldUnitIdentityBeSecret", falseFn)
	set("ShouldUnitHealthMaxBeSecret", falseFn)
	set("ShouldSpellCooldownBeSecret", falseFn)
	set("HasSecretRestrictions", falseFn)
end
do
	-- File IDs do not exist here: paths are always "known", numbers never are.
	local set = namespace("C_UIFileAsset")
	set("IsKnownFile", function(file) return type(file) == "string" end)
end
do
	local set = namespace("C_PlayerInfo")
	set("GetAlternateFormInfo", falseFn)
	set("IsPlayerNPERestricted", falseFn)
	set("CanUseItem", function() return true end)
	set("GetGlidingInfo", function() return false, false, 0 end)
	set("IsPlayerInChromieTime", falseFn)
	set("GetPlayerMythicPlusRatingSummary", nilFn)
	set("GetClass", function() local name, file, id = UnitClass("player") return name, file, id end)
	set("GetRace", function() return (select(2, UnitRace("player"))) end)
	set("GetName", function() return UnitName("player") end)
	set("IsExpansionLandingPageUnlockedForPlayer", falseFn)
	set("HasVisibleInvSlot", function() return true end)
end
do
	local set = namespace("C_Texture")
	-- Atlases this client can draw (registered with ModernUI_RegisterAtlas), in the modern shape.
	set("GetAtlasInfo", function(atlas)
		local file, width, height, left, right, top, bottom
		local fallback = _G.ModernUI_AtlasFallback and _G.ModernUI_AtlasFallback[atlas]
		if fallback then
			file, width, height, left, right, top, bottom = fallback[1], fallback[2], fallback[3], fallback[4] or 0, fallback[5] or 1, fallback[6] or 0, fallback[7] or 1
		elseif ModernUI_GetAtlasInfo then
			file, width, height, left, right, top, bottom = ModernUI_GetAtlasInfo(atlas)
		end
		if not file then
			return nil
		end
		return { file = file, filename = file, width = width, height = height, leftTexCoord = left, rightTexCoord = right,
			topTexCoord = top, bottomTexCoord = bottom, tilesHorizontally = false, tilesVertically = false }
	end)
	set("GetAtlasElements", emptyFn)
	set("GetFilenameFromFileDataID", function(id) return ModernUI_GetFilenameFromFileID and ModernUI_GetFilenameFromFileID(id) or nil end)
end
do
	-- Nameplates (36_NamePlates.lua gives them unit tokens and the modern events).
	local set = namespace("C_NamePlate")
	for _, name in ipairs({
		"SetNamePlateFriendlySize", "SetNamePlateEnemySize", "SetNamePlateSelfSize",
		"SetNamePlateFriendlyClickThrough", "SetNamePlateEnemyClickThrough", "SetNamePlateSelfClickThrough",
		"SetNamePlateFriendlyPreferredClickInsets", "SetNamePlateEnemyPreferredClickInsets",
		"SetNamePlateSelfPreferredClickInsets", "SetTargetClampingInsets",
	}) do
		set(name, noop)
	end
	set("GetNamePlateFriendlySize", function() return 110, 45 end)
	set("GetNamePlateEnemySize", function() return 110, 45 end)
	set("GetNamePlateSelfSize", function() return 110, 45 end)
	set("GetNamePlateFriendlyClickThrough", falseFn)
	set("GetNamePlateEnemyClickThrough", falseFn)
	set("GetNamePlateSelfClickThrough", falseFn)
end
do
	local set = namespace("C_LossOfControl")
	set("GetActiveLossOfControlDataCount", function() return 0 end)
	set("GetActiveLossOfControlData", nilFn)
	set("GetActiveLossOfControlDataByUnit", nilFn)
	set("GetActiveLossOfControlDataCountByUnit", function() return 0 end)
end
do
	local set = namespace("C_PaperDollInfo")
	set("GetStaggerPercentage", function() return 0 end)
	set("OffhandHasWeapon", function() return OffhandHasWeapon() and true or false end)
	set("OffhandHasShield", function()
		local link = GetInventoryItemLink("player", 17)
		return link and select(9, GetItemInfo(link)) == "INVTYPE_SHIELD" or false
	end)
	set("GetInspectItemLevel", function() return 0 end)
	set("GetMinItemLevel", nilFn)
	set("IsRangedSlotShown", function() return true end)
	set("CanCursorCanGoInSlot", falseFn)
end
do
	local set = namespace("C_BattleNet")
	set("GetFriendAccountInfo", nilFn)
	set("GetFriendNumGameAccounts", function() return 0 end)
	set("GetFriendGameAccountInfo", nilFn)
	set("GetGameAccountInfoByID", nilFn)
	set("GetGameAccountInfoByGUID", nilFn)
	set("GetAccountInfoByID", nilFn)
	set("GetAccountInfoByGUID", nilFn)
	set("SendWhisper", noop)
end
do
	local set = namespace("C_StorePublic")
	set("IsEnabled", falseFn)
	set("IsDisabledByParentalControls", falseFn)
end
do
	local set = namespace("C_SocialRestrictions")
	set("IsMuted", falseFn)
	set("IsSilenced", falseFn)
	set("IsSquelched", falseFn)
	set("CanReceiveChat", function() return true end)
end
do
	local set = namespace("C_Covenants")
	set("GetActiveCovenantID", function() return 0 end)
	set("GetCovenantData", nilFn)
end
do
	local set = namespace("C_IncomingSummon")
	set("HasIncomingSummon", function(unit) return false end)
	set("IncomingSummonStatus", function() return 0 end)
end
do
	local set = namespace("C_LFGInfo")
	set("GetDungeonInfo", nilFn)
	set("IsInLFGFollowerDungeon", falseFn)
	set("IsLFGFollowerDungeon", falseFn)
	set("GetAllEntriesForCategory", emptyFn)
	set("CanPlayerUseLFD", function() return true end)
end
do
	local set = namespace("C_SuperTrack")
	set("IsSuperTrackingUserWaypoint", falseFn)
	set("SetSuperTrackedUserWaypoint", noop)
	set("IsSuperTrackingAnything", falseFn)
	set("IsSuperTrackingQuest", falseFn)
	set("GetSuperTrackedQuestID", nilFn)
	set("SetSuperTrackedQuestID", noop)
end
do
	local set = namespace("C_Console")
	-- The client lists its CVars natively (commandType 0 = CVar).
	set("GetAllCommands", function() return ConsoleGetAllCommands and ConsoleGetAllCommands() or {} end)
	set("GetColorFromType", function() return CreateColor(1, 1, 1, 1) end)
end
do
	local set = namespace("C_Minimap")
	set("GetViewRadius", function() return 0 end)
	set("IsRotateMinimapIgnored", falseFn)
	set("ShouldUseHybridMinimap", falseFn)
end
do
	local set = namespace("C_EventUtils")
	set("IsEventValid", function() return true end)
	set("NotifySettingsLoaded", noop)
end
do
	local set = namespace("C_XMLUtil")
	set("GetTemplateInfo", nilFn)
	set("GetTemplates", emptyFn)
end
do
	local set = namespace("C_ToyBox")
	set("GetToyInfo", nilFn)
	set("GetNumToys", function() return 0 end)
end
do
	local set = namespace("C_TransmogCollection")
	set("GetSourceInfo", nilFn)
	set("GetItemInfo", nilFn)
	set("GetSourceIcon", nilFn)
	set("PlayerHasTransmogItemModifiedAppearance", falseFn)
	set("PlayerHasTransmog", falseFn)
	set("PlayerCanCollectSource", falseFn)
	set("GetAppearanceSourceInfo", nilFn)
end
do
	local set = namespace("C_ModelInfo")
	set("GetModelSceneActorInfoByID", nilFn)
	set("GetModelSceneCameraInfoByID", nilFn)
	set("GetModelSceneInfoByID", nilFn)
end
do
	local set = namespace("C_PlayerInteractionManager")
	set("IsInteractingWithNpcOfType", falseFn)
	set("ClearInteraction", noop)
	set("IsValidNPCInteraction", falseFn)
end
do
	local set = namespace("C_GamePad")
	set("IsEnabled", falseFn)
	set("SetVibration", noop)
	set("StopVibration", noop)
	set("GetActiveDeviceID", nilFn)
end
do
	local set = namespace("C_Social")
	set("IsSocialEnabled", falseFn)
end
do
	local set = namespace("C_Club")
	set("GetSubscribedClubs", emptyFn)
	set("IsEnabled", falseFn)
end
do
	local set = namespace("C_RaidLocks")
	set("IsEncounterComplete", falseFn)
end
do
	local set = namespace("C_Housing")
	set("IsHousingServiceEnabled", falseFn)
end
do
	local set = namespace("C_GuildInfo")
	set("GuildRoster", function() GuildRoster() end)
	set("CanEditOfficerNote", function() return CanEditOfficerNote() and true or false end)
	set("CanViewOfficerNote", function() return CanViewOfficerNote() and true or false end)
	set("CanSpeakInGuildChat", function() return IsInGuild() and true or false end)
	set("RemoveFromGuild", function(name) GuildUninvite(name) end)
	set("IsGuildOfficer", function() return IsGuildLeader() or CanGuildRemove() end)
	set("MemberExistsByName", function(name) return IsGuildMember(name) end)
	set("QueryGuildMembersForRecipe", noop)
	set("GetGuildTabardInfo", nilFn)
	set("GetGuildNewsInfo", nilFn)
	set("IsEncounterGuildNewsEnabled", falseFn)
end
do
	-- Text to speech does not exist in this client.
	local set = namespace("C_VoiceChat")
	set("GetTtsVoices", emptyFn)
	set("GetRemoteTtsVoices", emptyFn)
	set("SpeakText", noop)
	set("StopSpeakingText", noop)
	set("IsSpeakForMeActive", falseFn)
	set("IsSpeakForMeAllowed", falseFn)
	set("GetTtsVoiceOptions", emptyFn)
	set("IsTranscriptionAllowed", falseFn)
	set("IsLoggedIn", falseFn)
	set("IsEnabled", falseFn)
end

-- CVars of modern clients that AddOns read or set. Registered with their modern defaults so GetCVar answers
-- (and SetCVar keeps a value) as on a modern client; this client's own CVars are left as they are.
if RegisterCVar then
	local modernCVars = {
		test_cameraOverShoulder = "0", test_cameraDynamicPitch = "0", test_cameraDynamicPitchBaseFovPad = "0.4",
		test_cameraDynamicPitchBaseFovPadFlying = "0.75", test_cameraDynamicPitchBaseFovPadDownScale = "0.25",
		test_cameraDynamicPitchSmartPivotCutoffDist = "10", test_cameraHeadMovementStrength = "0",
		test_cameraTargetFocusEnemyEnable = "0", test_cameraTargetFocusInteractEnable = "0",
		test_cameraTargetFocusEnemyStrengthPitch = "0.4", test_cameraTargetFocusEnemyStrengthYaw = "0.5",
		test_cameraTargetFocusInteractStrengthPitch = "0.75", test_cameraTargetFocusInteractStrengthYaw = "1",
		cameraFov = "90", cameraKeepCharacterCentered = "1", cameraReduceUnexpectedMovement = "0",
		CameraKeepCharacterCentered = "1",
		nameplateMaxDistance = "41", nameplateHorizontalScale = "1", nameplateVerticalScale = "1",
		nameplateOverlapH = "0.8", nameplateOverlapV = "1.1", nameplatePlayerMaxDistance = "60",
		nameplateShowOnlyNames = "0", nameplateShowAll = "1", nameplateShowFriendlyNPCs = "0",
		nameplateShowSelf = "0", nameplateMotion = "0", nameplateMotionSpeed = "0.025",
		nameplateMinScale = "0.8", nameplateMaxScale = "1", nameplateMinAlpha = "0.6", nameplateMaxAlpha = "1",
		nameplateSelectedScale = "1.2", nameplateSelectedAlpha = "1", nameplateLargerScale = "1.2",
		nameplateGlobalScale = "1", nameplateSelfScale = "1", nameplateSelfAlpha = "0.75",
		nameplateOtherTopInset = "0.08", nameplateOtherBottomInset = "0.1", nameplateLargeTopInset = "0.1",
		nameplateLargeBottomInset = "0.15", nameplateTargetBehindMaxDistance = "15", nameplateOccludedAlphaMult = "0.4",
		nameplateShowFriendlyGuardians = "0", nameplateShowFriendlyMinions = "0", nameplateShowFriendlyPets = "0",
		nameplateShowFriendlyTotems = "0", nameplateShowEnemyGuardians = "1", nameplateShowEnemyMinions = "1",
		nameplateShowEnemyMinus = "1", nameplateShowEnemyPets = "1", nameplateShowEnemyTotems = "1",
		nameplateResourceOnTarget = "0", nameplateShowDebuffsOnFriendly = "0",
		ActionButtonUseKeyDown = "0", combinedBags = "0", countdownForCooldowns = "0", cursorSizePreferred = "-1",
		encounterTimelineEnabled = "0", encounterTimelineHighlightDuration = "0", encounterTimelineShowSequenceCount = "0",
		encounterWarningsEnabled = "0", GamePadEnable = "0", graphicsOutlineMode = "0", instantQuestText = "0",
		MSAAQuality = "0", outline = "0", shadowRt = "0", showOutfitDetails = "1", SoftTargetInteract = "0",
		Sound_DialogVolume = "1", Sound_EnableDialog = "1", colorblindMode = "0", colorblindSimulator = "0",
		threatWarning = "3", showTargetOfTarget = "1", lockActionBars = "1", showQuestTrackingTooltips = "1",
		autoLootDefault = "0", interactOnLeftClick = "0", ResampleAlwaysSharpen = "0", ResampleQuality = "0",
		renderScale = "1", useUiScale = "0", uiScale = "1", scriptErrors = "0", taintLog = "0",
	}
	local getCVar = GetCVar
	for name, value in pairs(modernCVars) do
		if getCVar(name) == nil then
			pcall(RegisterCVar, name, value)
		end
	end
end
