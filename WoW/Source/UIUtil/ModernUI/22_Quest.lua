-- ModernUI: built into the client (not in the original 3.3.5a).
-- C_QuestLog, C_GossipInfo, C_QuestInfoSystem and completed-quest tracking, on this client's quest log.

local _G = _G
local type, select, tonumber, pairs, ipairs = type, select, tonumber, pairs, ipairs

-- Completed quests ------------------------------------------------------------------------------
-- 3.3.5 only tells the client which quests are done when asked (QueryQuestsCompleted). Ask at login
-- and after each hand-in, and keep the answer.

local completed = {}
local completedReady = false

local completedFrame = CreateFrame("Frame")
completedFrame:RegisterEvent("PLAYER_LOGIN")
completedFrame:RegisterEvent("QUEST_QUERY_COMPLETE")
completedFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		if QueryQuestsCompleted then
			QueryQuestsCompleted()
		end
	elseif event == "QUEST_QUERY_COMPLETE" then
		local list = {}
		GetQuestsCompleted(list)
		completed = list
		completedReady = true
	end
end)

if GetQuestReward then
	hooksecurefunc("GetQuestReward", function()
		local id = GetQuestID and GetQuestID()
		if id and id > 0 then
			completed[id] = true
		end
		C_Timer.After(1, function()
			if QueryQuestsCompleted then
				QueryQuestsCompleted()
			end
		end)
	end)
end

local function isCompleted(questID)
	return questID ~= nil and completed[questID] == true
end

if _G.IsQuestFlaggedCompleted == nil then
	_G.IsQuestFlaggedCompleted = isCompleted
end

-- Quest log ---------------------------------------------------------------------------------------

local function logEntry(index)
	local title, level, tag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(index)
	return title, level, tag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID
end

local function indexForQuest(questID)
	if not questID then
		return nil
	end
	for i = 1, GetNumQuestLogEntries() do
		local _, _, _, _, isHeader, _, _, _, id = logEntry(i)
		if not isHeader and id == questID then
			return i
		end
	end
end

local tagIDs = { Group = 1, PvP = 41, Raid = 62, Dungeon = 81, Heroic = 85 }
local function tagIDFor(tag)
	if not tag or tag == "" then
		return nil
	end
	for name, id in pairs(tagIDs) do
		if tag == (_G[name:upper()] or name) or tag == name then
			return id
		end
	end
	if tag == (RAID or "Raid") then return 62 end
	if tag == (LFG_TYPE_DUNGEON or "Dungeon") then return 81 end
	if tag == (PVP or "PvP") then return 41 end
	if tag == (GROUP or "Group") then return 1 end
	if tag == (LFG_TYPE_HEROIC_DUNGEON or "Heroic") then return 85 end
	return 0
end

-- Run fn with the quest selected in the log, then put the selection back.
local function withSelected(index, fn)
	local previous = GetQuestLogSelection()
	SelectQuestLogEntry(index)
	local a, b, c = fn()
	SelectQuestLogEntry(previous)
	return a, b, c
end

local C_QuestLog = _G.C_QuestLog or {}
_G.C_QuestLog = C_QuestLog

local function set(name, fn)
	if C_QuestLog[name] == nil then
		C_QuestLog[name] = fn
	end
end

set("GetNumQuestLogEntries", function() return GetNumQuestLogEntries() end)
set("GetMaxNumQuests", function() return MAX_QUESTS or 25 end)
set("GetMaxNumQuestsCanAccept", function() return MAX_QUESTLOG_QUESTS or 25 end)
set("GetInfo", function(index)
	local title, level, tag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID = logEntry(index)
	if not title then
		return nil
	end
	return {
		title = title, questLogIndex = index, questID = questID or 0, campaignID = nil, level = level or 0,
		difficultyLevel = level or 0, suggestedGroup = suggestedGroup or 0, frequency = isDaily and 1 or 0,
		isHeader = isHeader and true or false, useMinimalHeader = false, sortAsHeader = false,
		isCollapsed = isCollapsed and true or false, startEvent = false, isTask = false, isBounty = false,
		isStory = false, isScaling = false, isOnMap = false, hasLocalPOI = false, isHidden = false,
		isAutoComplete = false, overridesSortOrder = false, readyForTranslation = true,
		isInternalOnly = false, isAbandonOnDisable = false, questClassification = Enum.QuestClassification.Normal,
	}
end)
set("GetLogIndexForQuestID", indexForQuest)
set("GetQuestIDForLogIndex", function(index) return (select(9, logEntry(index))) end)
set("IsOnQuest", function(questID) return indexForQuest(questID) ~= nil end)
set("GetTitleForQuestID", function(questID)
	local index = indexForQuest(questID)
	return index and (logEntry(index))
end)
set("GetQuestInfo", function(questID) return C_QuestLog.GetTitleForQuestID(questID) end)
set("IsQuestFlaggedCompleted", isCompleted)
set("IsQuestFlaggedCompletedOnAccount", isCompleted)
set("GetAllCompletedQuestIDs", function()
	local list = {}
	for id in pairs(completed) do
		list[#list + 1] = id
	end
	table.sort(list)
	return list
end)
set("IsComplete", function(questID)
	local index = indexForQuest(questID)
	return index ~= nil and select(7, logEntry(index)) == 1
end)
set("ReadyForTurnIn", function(questID) return C_QuestLog.IsComplete(questID) end)
set("IsFailed", function(questID)
	local index = indexForQuest(questID)
	return index ~= nil and select(7, logEntry(index)) == -1
end)
set("IsRepeatableQuest", function(questID)
	local index = indexForQuest(questID)
	return index ~= nil and select(8, logEntry(index)) and true or false
end)
set("GetQuestDifficultyLevel", function(questID)
	local index = indexForQuest(questID)
	return index and (select(2, logEntry(index)))
end)
set("GetSuggestedGroupSize", function(questID)
	local index = indexForQuest(questID)
	return index and (select(4, logEntry(index))) or 0
end)
set("GetQuestTagInfo", function(questID)
	local index = indexForQuest(questID)
	local tag = index and select(3, logEntry(index))
	if not tag or tag == "" then
		return nil
	end
	return { tagName = tag, tagID = tagIDFor(tag), worldQuestType = nil, quality = 1, isElite = tag == (ELITE or "Elite"), displayExpiration = false }
end)
set("GetQuestType", function(questID)
	local info = C_QuestLog.GetQuestTagInfo(questID)
	return info and info.tagID
end)
set("GetQuestObjectives", function(questID)
	local index = indexForQuest(questID)
	if not index then
		return {}
	end
	local list = {}
	for i = 1, GetNumQuestLeaderBoards(index) do
		local text, objectiveType, finished = GetQuestLogLeaderBoard(i, index)
		local have, need = (text or ""):match("(%d+)%s*/%s*(%d+)")
		list[i] = {
			text = text or "", type = objectiveType, finished = finished and true or false,
			numFulfilled = tonumber(have) or (finished and 1 or 0), numRequired = tonumber(need) or 1,
			objectiveType = objectiveType,
		}
	end
	return list
end)
set("GetNumQuestObjectives", function(questID)
	local index = indexForQuest(questID)
	return index and GetNumQuestLeaderBoards(index) or 0
end)
set("GetSelectedQuest", function()
	local index = GetQuestLogSelection()
	return index and index > 0 and select(9, logEntry(index)) or 0
end)
set("SetSelectedQuest", function(questID)
	local index = indexForQuest(questID)
	if index then
		SelectQuestLogEntry(index)
	end
end)
set("GetRequiredMoney", function(questID)
	local index = indexForQuest(questID)
	return index and withSelected(index, GetQuestLogRequiredMoney) or 0
end)
set("IsPushableQuest", function(questID)
	local index = indexForQuest(questID)
	return index ~= nil and withSelected(index, GetQuestLogPushable) and true or false
end)
set("GetTimeAllowed", function(questID)
	local index = indexForQuest(questID)
	local left = index and withSelected(index, GetQuestLogTimeLeft)
	return left, left
end)
set("SetAbandonQuest", function()
	local index = GetQuestLogSelection()
	if index and index > 0 then
		SetAbandonQuest()
	end
end)
set("AbandonQuest", function() AbandonQuest() end)
set("AddQuestWatch", function(questID)
	local index = indexForQuest(questID)
	if index then
		AddQuestWatch(index)
		return true
	end
	return false
end)
set("RemoveQuestWatch", function(questID)
	local index = indexForQuest(questID)
	if index then
		RemoveQuestWatch(index)
		return true
	end
	return false
end)
set("GetQuestWatchType", function(questID)
	local index = indexForQuest(questID)
	return index and IsQuestWatched(index) and 0 or nil
end)
set("GetNumQuestWatches", function() return GetNumQuestWatches() end)
set("GetNumWorldQuestWatches", function() return 0 end)
set("GetQuestIDForQuestWatchIndex", function(watchIndex)
	local index = GetQuestIndexForWatch(watchIndex)
	return index and (select(9, logEntry(index)))
end)
set("RequestLoadQuestByID", function() end)
set("IsQuestTrivial", function() return false end)
set("IsQuestTask", function() return false end)
set("IsWorldQuest", function() return false end)
set("IsAccountQuest", function() return false end)
set("IsQuestCalling", function() return false end)
set("IsThreatQuest", function() return false end)
set("IsImportantQuest", function() return false end)
set("IsLegendaryQuest", function() return false end)
set("IsMetaQuest", function() return false end)
set("IsQuestBounty", function() return false end)
set("IsQuestInvasion", function() return false end)
set("IsQuestReplayable", function() return false end)
set("IsQuestDisabledForSession", function() return false end)
set("QuestCanHaveWarModeBonus", function() return false end)
set("QuestHasQuestSessionBonus", function() return false end)
set("QuestHasWarModeBonus", function() return false end)
set("ShouldShowQuestRewards", function() return true end)
set("GetZoneStoryInfo", function() return nil end)
set("GetQuestDetailsTheme", function() return nil end)
set("GetQuestRewardCurrencies", function() return {} end)
set("GetQuestsOnMap", function() return {} end)
set("GetDistanceSqToQuest", function() return nil end)
set("GetNextWaypoint", function() return nil end)
set("GetQuestAdditionalHighlights", function() return nil end)
set("GetQuestLogPortraitGiver", function() return nil end)
set("GetHeaderIndexForQuest", function(questID)
	local index = indexForQuest(questID)
	if not index then return nil end
	for i = index, 1, -1 do
		if select(5, logEntry(i)) then
			return i
		end
	end
end)
set("UnitIsRelatedToActiveQuest", function() return false end)
set("GetActivePreyQuest", function() return nil end)

-- C_QuestInfoSystem -----------------------------------------------------------------------------

local C_QuestInfoSystem = _G.C_QuestInfoSystem or {}
_G.C_QuestInfoSystem = C_QuestInfoSystem
C_QuestInfoSystem.GetQuestClassification = C_QuestInfoSystem.GetQuestClassification or function() return Enum.QuestClassification.Normal end
C_QuestInfoSystem.GetQuestRewardCurrencies = C_QuestInfoSystem.GetQuestRewardCurrencies or function() return {} end
C_QuestInfoSystem.HasQuestRewardCurrencies = C_QuestInfoSystem.HasQuestRewardCurrencies or function() return false end
C_QuestInfoSystem.GetQuestRewardSpells = C_QuestInfoSystem.GetQuestRewardSpells or function() return {} end
C_QuestInfoSystem.HasQuestRewardSpells = C_QuestInfoSystem.HasQuestRewardSpells or function() return false end
C_QuestInfoSystem.GetQuestRewardSpellInfo = C_QuestInfoSystem.GetQuestRewardSpellInfo or function() return nil end
C_QuestInfoSystem.GetQuestShouldToastCompletion = C_QuestInfoSystem.GetQuestShouldToastCompletion or function() return false end

-- C_GossipInfo ----------------------------------------------------------------------------------
-- 3.3.5 gossip quests have no quest ID; the list position is used as the ID, and the Select
-- functions accept that same number, so the two stay consistent.

local gossipIcons = {
	gossip = "Interface\\GossipFrame\\GossipGossipIcon",
	vendor = "Interface\\GossipFrame\\VendorGossipIcon",
	taxi = "Interface\\GossipFrame\\TaxiGossipIcon",
	trainer = "Interface\\GossipFrame\\TrainerGossipIcon",
	binder = "Interface\\GossipFrame\\BinderGossipIcon",
	banker = "Interface\\GossipFrame\\BankerGossipIcon",
	petition = "Interface\\GossipFrame\\PetitionGossipIcon",
	tabard = "Interface\\GossipFrame\\TabardGossipIcon",
	battlemaster = "Interface\\GossipFrame\\BattleMasterGossipIcon",
	healer = "Interface\\GossipFrame\\HealerGossipIcon",
}

local function chunk(count, ...)
	local total = select("#", ...)
	local stride = count > 0 and total / count or 0
	return stride, { ... }
end

local C_GossipInfo = _G.C_GossipInfo or {}
_G.C_GossipInfo = C_GossipInfo

local function gset(name, fn)
	if C_GossipInfo[name] == nil then
		C_GossipInfo[name] = fn
	end
end

gset("GetText", function() return GetGossipText() end)
gset("GetNumOptions", function() return GetNumGossipOptions() end)
gset("GetNumAvailableQuests", function() return GetNumGossipAvailableQuests() end)
gset("GetNumActiveQuests", function() return GetNumGossipActiveQuests() end)
gset("GetOptions", function()
	local stride, values = chunk(GetNumGossipOptions(), GetGossipOptions())
	local list = {}
	for i = 1, GetNumGossipOptions() do
		local name, kind = values[(i - 1) * stride + 1], values[(i - 1) * stride + 2]
		list[i] = {
			gossipOptionID = i, name = name, icon = gossipIcons[kind] or gossipIcons.gossip, type = kind,
			status = 0, flags = 0, orderIndex = i, selectOptionWhenOnlyOption = false, rewards = {},
			spellID = nil, overrideIconID = nil,
		}
	end
	return list
end)
gset("GetAvailableQuests", function()
	local count = GetNumGossipAvailableQuests()
	local stride, values = chunk(count, GetGossipAvailableQuests())
	local list = {}
	for i = 1, count do
		local base = (i - 1) * stride
		list[i] = {
			title = values[base + 1], questLevel = values[base + 2], isTrivial = values[base + 3] and true or false,
			frequency = (stride >= 4 and values[base + 4]) and 1 or 0, repeatable = (stride >= 5 and values[base + 5]) and true or false,
			isComplete = false, isLegendary = false, isIgnored = false, isImportant = false, isMeta = false,
			questID = i,
		}
	end
	return list
end)
gset("GetActiveQuests", function()
	local count = GetNumGossipActiveQuests()
	local stride, values = chunk(count, GetGossipActiveQuests())
	local list = {}
	for i = 1, count do
		local base = (i - 1) * stride
		list[i] = {
			title = values[base + 1], questLevel = values[base + 2], isTrivial = values[base + 3] and true or false,
			frequency = 0, repeatable = false, isComplete = (stride >= 4 and values[base + 4]) and true or false,
			isLegendary = false, isIgnored = false, isImportant = false, isMeta = false, questID = i,
		}
	end
	return list
end)
gset("SelectOption", function(optionID) SelectGossipOption(optionID) end)
gset("SelectOptionByIndex", function(index) SelectGossipOption(index) end)
gset("SelectAvailableQuest", function(id) SelectGossipAvailableQuest(id) end)
gset("SelectActiveQuest", function(id) SelectGossipActiveQuest(id) end)
gset("CloseGossip", function() CloseGossip() end)
gset("ForceGossip", function() return false end)
gset("RefreshOptions", function() end)
gset("GetPoiForUiMapID", function() return nil end)
gset("GetPoiInfo", function() return nil end)
gset("GetCompletedOptionDescriptionString", function() return nil end)
gset("GetCustomGossipDescriptionString", function() return nil end)
gset("GetFriendshipReputation", function(factionID)
	return {
		friendshipFactionID = 0, standing = 0, maxRep = 0, name = nil, text = "", texture = 0,
		reaction = "", reactionThreshold = 0, nextThreshold = nil, reversedColor = false, overrideColor = nil,
	}
end)
gset("GetFriendshipReputationRanks", function() return { currentLevel = 0, maxLevel = 0 } end)
