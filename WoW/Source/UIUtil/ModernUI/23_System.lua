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
	local function addonArgs(a, b)
		if b ~= nil and type(a) == "string" and GetAddOnInfo(b) and (select(6, GetAddOnInfo(b))) ~= "MISSING" then
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
-- Map IDs here are this client's own map area IDs (the ones GetCurrentMapAreaID returns).

do
	local set = namespace("C_Map")

	-- Run fn with the world map switched to mapID, then put the map back the way the player had it.
	local function onMap(mapID, fn)
		local previous = GetCurrentMapAreaID()
		local previousLevel = GetCurrentMapDungeonLevel()
		if mapID then
			SetMapByID(mapID)
		else
			SetMapToCurrentZone()
		end
		local a, b, c, d = fn()
		if WorldMapFrame and WorldMapFrame:IsShown() then
			SetMapByID(previous)
			if previousLevel and previousLevel > 0 then
				SetDungeonMapLevel(previousLevel)
			end
		end
		return a, b, c, d
	end

	local function currentMapInfo()
		local mapID = GetCurrentMapAreaID()
		local continent = GetCurrentMapContinent()
		local zone = GetCurrentMapZone()
		local name, mapType, parent
		if continent and continent > 0 and zone and zone > 0 then
			name = select(zone, GetMapZones(continent))
			mapType = Enum.UIMapType.Zone
		elseif continent and continent > 0 then
			name = select(continent, GetMapContinents())
			mapType = Enum.UIMapType.Continent
		elseif continent == 0 then
			name = WORLD_MAP or "World"
			mapType = Enum.UIMapType.World
		else
			name = GetRealZoneText()
			mapType = GetNumDungeonMapLevels() > 0 and Enum.UIMapType.Dungeon or Enum.UIMapType.Zone
		end
		return mapID, name, mapType, continent
	end

	set("GetBestMapForUnit", function(unit)
		if unit ~= "player" and not UnitIsUnit(unit or "", "player") then
			return nil
		end
		return (onMap(nil, function() return GetCurrentMapAreaID() end))
	end)
	set("GetMapInfo", function(mapID)
		if not mapID then
			return nil
		end
		return onMap(mapID, function()
			local id, name, mapType, continent = currentMapInfo()
			local parentMapID = 0
			if mapType == Enum.UIMapType.Zone and continent and continent > 0 then
				SetMapZoom(continent)
				parentMapID = GetCurrentMapAreaID()
			end
			return { mapID = id, name = name or "", mapType = mapType, parentMapID = parentMapID, flags = 0 }
		end)
	end)
	set("GetPlayerMapPosition", function(mapID, unit)
		return onMap(mapID, function()
			local x, y = GetPlayerMapPosition(unit or "player")
			if not x or (x == 0 and y == 0) then
				return nil
			end
			return CreateVector2D(x, y)
		end)
	end)
	set("GetMapChildrenInfo", function(mapID)
		return onMap(mapID, function()
			local list = {}
			local _, _, mapType, continent = currentMapInfo()
			if mapType == Enum.UIMapType.Continent and continent and continent > 0 then
				local zones = { GetMapZones(continent) }
				for i, name in ipairs(zones) do
					SetMapZoom(continent, i)
					list[#list + 1] = { mapID = GetCurrentMapAreaID(), name = name, mapType = Enum.UIMapType.Zone, parentMapID = mapID, flags = 0 }
				end
			end
			return list
		end)
	end)
	set("GetMapGroupID", nilFn)
	set("GetMapGroupMembersInfo", nilFn)
	set("GetWorldPosFromMapPos", nilFn)
	set("GetMapPosFromWorldPos", nilFn)
	set("GetAreaInfo", nilFn)
	set("GetMapWorldSize", nilFn)
	set("GetMapArtID", nilFn)
	set("GetMapLevels", function() return 0, 0, 0, 0 end)
	set("GetMapRectOnMap", nilFn)
	set("GetFallbackWorldMapID", function() return 0 end)
	set("MapHasArt", function() return true end)
	set("IsMapValidForNavBarDropDown", function() return true end)
	set("GetMapDisplayInfo", function() return false end)
	set("GetMapHighlightInfoAtPosition", nilFn)
	set("GetMapLinksForMap", emptyFn)
	set("GetMapInfoAtPosition", nilFn)
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
	set("GetAtlasInfo", nilFn)
	set("GetAtlasElements", emptyFn)
	set("GetFilenameFromFileDataID", nilFn)
end
do
	-- 3.3.5 nameplates have no unit tokens, so nothing can be returned for a unit.
	local set = namespace("C_NamePlate")
	set("GetNamePlateForUnit", nilFn)
	set("GetNamePlates", emptyFn)
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
	set("GetAllCommands", emptyFn)
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
