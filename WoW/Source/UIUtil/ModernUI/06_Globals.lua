-- ModernUI: built into the client (not in the original 3.3.5a).
-- Global functions and constants modern addons expect, answered from this client's own data.

local _G = _G
local type, select, pairs, tonumber, tostring = type, select, pairs, tonumber, tostring

local function define(name, value)
	if _G[name] == nil then
		_G[name] = value
	end
end

-- Which game this is. Multi-version addons branch on these; without them "WOW_PROJECT_ID ==
-- WOW_PROJECT_MAINLINE" is nil == nil and every addon thinks it is running on retail.
define("WOW_PROJECT_MAINLINE", 1)
define("WOW_PROJECT_CLASSIC", 2)
define("WOW_PROJECT_BURNING_CRUSADE_CLASSIC", 5)
define("WOW_PROJECT_WRATH_CLASSIC", 11)
define("WOW_PROJECT_CATACLYSM_CLASSIC", 14)
define("WOW_PROJECT_MISTS_CLASSIC", 19)
define("WOW_PROJECT_ID", WOW_PROJECT_WRATH_CLASSIC)

define("LE_EXPANSION_CLASSIC", 0)
define("LE_EXPANSION_BURNING_CRUSADE", 1)
define("LE_EXPANSION_WRATH_OF_THE_LICH_KING", 2)
define("LE_EXPANSION_NORTHREND", 2)
define("LE_EXPANSION_CATACLYSM", 3)
define("LE_EXPANSION_MISTS_OF_PANDARIA", 4)
define("LE_EXPANSION_WARLORDS_OF_DRAENOR", 5)
define("LE_EXPANSION_LEGION", 6)
define("LE_EXPANSION_BATTLE_FOR_AZEROTH", 7)
define("LE_EXPANSION_SHADOWLANDS", 8)
define("LE_EXPANSION_DRAGONFLIGHT", 9)
define("LE_EXPANSION_WAR_WITHIN", 10)
define("LE_EXPANSION_LEVEL_CURRENT", 2)
define("GetClassicExpansionLevel", function() return 2 end)
define("GetServerExpansionLevel", function() return GetExpansionLevel() end)
define("GetMaxLevelForPlayerExpansion", function() return MAX_PLAYER_LEVEL_TABLE and MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()] or 80 end)
define("GetMaxLevelForLatestExpansion", function() return 80 end)
define("IsTrialAccount", function() return false end)
define("IsVeteranTrialAccount", function() return false end)
define("IsRestrictedAccount", function() return false end)

-- Region and screen ------------------------------------------------------------------------------

local regionByPortal = { US = 1, KR = 2, EU = 3, TW = 4, CN = 5 }
define("GetCurrentRegion", function()
	local portal = (GetCVar("portal") or ""):upper()
	return regionByPortal[portal] or 1
end)
define("GetCurrentRegionName", function()
	local portal = (GetCVar("portal") or ""):upper()
	return regionByPortal[portal] and portal or "US"
end)

define("GetPhysicalScreenSize", function()
	local w, h = (GetCVar("gxResolution") or ""):match("(%d+)x(%d+)")
	if w then
		return tonumber(w), tonumber(h)
	end
	return GetScreenWidth(), GetScreenHeight()
end)

-- Groups -----------------------------------------------------------------------------------------

define("IsInRaid", function()
	return GetNumRaidMembers() > 0
end)

define("IsInGroup", function()
	return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
end)

define("GetNumGroupMembers", function()
	local raid = GetNumRaidMembers()
	if raid > 0 then
		return raid
	end
	local party = GetNumPartyMembers()
	return party > 0 and party + 1 or 0
end)

define("GetNumSubgroupMembers", function()
	return GetNumPartyMembers()
end)

define("UnitInSubgroup", function(unit)
	return UnitInParty(unit or "player")
end)

local function raidRank(unit)
	for i = 1, GetNumRaidMembers() do
		local name, rank = GetRaidRosterInfo(i)
		if name and UnitIsUnit("raid" .. i, unit) then
			return rank
		end
	end
end

define("UnitIsGroupLeader", function(unit)
	unit = unit or "player"
	if GetNumRaidMembers() > 0 then
		return raidRank(unit) == 2
	end
	if UnitIsUnit(unit, "player") then
		return IsPartyLeader() and true or false
	end
	return UnitIsPartyLeader(unit) and true or false
end)

define("UnitIsGroupAssistant", function(unit)
	return GetNumRaidMembers() > 0 and raidRank(unit or "player") == 1 or false
end)

define("IsEveryoneAssistant", function() return false end)

define("UnitFullName", function(unit)
	local name, realm = UnitName(unit)
	if name and (realm == nil or realm == "") and UnitIsUnit(unit, "player") then
		realm = (GetRealmName() or ""):gsub("[%s%-]", "")
	end
	return name, realm
end)

define("GetNormalizedRealmName", function()
	return (GetRealmName() or ""):gsub("[%s%-]", "")
end)

define("Ambiguate", function(fullName, context)
	if type(fullName) ~= "string" or context == "none" then
		return fullName
	end
	local name, realm = fullName:match("^([^%-]+)%-(.+)$")
	if not name then
		return fullName
	end
	if realm == GetNormalizedRealmName() or context == "short" then
		return name
	end
	return fullName
end)

define("UnitNameUnmodified", UnitName)
define("UnitEffectiveLevel", function(unit) return UnitLevel(unit) end)
define("UnitStagger", function() return 0 end)
define("UnitPartialPower", function() return 0 end)
define("UnitPowerBarID", function() return 0 end)
define("UnitIsBattlePet", function() return false end)
define("UnitIsWildBattlePet", function() return false end)
define("UnitIsBattlePetCompanion", function() return false end)
define("UnitIsOtherPlayersPet", function() return false end)
define("UnitIsQuestBoss", function() return false end)
define("UnitHasIncomingResurrection", function() return false end)
define("UnitInPhase", function() return true end)
define("UnitPhaseReason", function() return nil end)
define("UnitTreatAsPlayerForDisplay", function(unit) return UnitIsPlayer(unit) end)
define("UnitClassBase", function(unit) return select(2, UnitClass(unit)) end)
define("UnitGetIncomingHeals", function() return 0 end)
define("UnitGetTotalAbsorbs", function() return 0 end)
define("UnitGetTotalHealAbsorbs", function() return 0 end)
define("UnitHealthMissing", function(unit) return UnitHealthMax(unit) - UnitHealth(unit) end)
define("UnitIsTapDenied", function(unit) return UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) end)
define("UnitNameplateShowsWidgetsOnly", function() return false end)
define("UnitWidgetSet", function() return nil end)
define("UnitChromieTimeID", function() return 0 end)
define("UnitIsFeignDeath", function(unit) return false end)
define("UnitSelectionType", function(unit)
	if UnitIsUnit(unit, "player") then return 4 end
	if UnitIsFriend("player", unit) then return 3 end
	if UnitIsEnemy("player", unit) then return 0 end
	return 2
end)
define("UnitHPPerStamina", function() return 10 end)

define("GetPowerRegenForPowerType", function() return GetPowerRegen() end)
define("GetHaste", function()
	return GetCombatRatingBonus(CR_HASTE_MELEE or 18) or 0
end)
define("GetHitModifier", function() return 0 end)
define("GetSpellHitModifier", function() return 0 end)
define("GetCritChanceProvidesParryEffect", function() return false end)
define("GetMasteryEffect", function() return 0, 0 end)
define("GetMastery", function() return 0 end)
define("GetVersatilityBonus", function() return 0 end)
define("GetCombatRatingBonusForCombatRatingValue", function() return 0 end)
define("GetAvoidance", function() return 0 end)
define("GetLifesteal", function() return 0 end)
define("GetSpeed", function() return 0 end)
define("GetShapeshiftFormID", function() return nil end)
define("IsArenaSkirmish", function() return false end)
define("GetArenaOpponentSpec", function() return nil end)
define("IsPlayerSpell", function(spellID) return IsSpellKnown(spellID) end)
define("IsSpellKnownOrOverridesKnown", function(spellID, isPet) return IsSpellKnown(spellID, isPet) end)
define("GetDifficultyInfo", function(difficultyID)
	local names = { [1] = "Normal", [2] = "Heroic", [3] = "10 Player", [4] = "25 Player", [5] = "10 Player (Heroic)", [6] = "25 Player (Heroic)" }
	local name = names[difficultyID]
	if not name then
		return nil
	end
	local isHeroic = difficultyID == 2 or difficultyID == 5 or difficultyID == 6
	local instanceType = difficultyID <= 2 and "party" or "raid"
	return name, instanceType, isHeroic, false, false, false, nil
end)

define("IsGuildMember", function(name)
	if not IsInGuild() then
		return false
	end
	for i = 1, GetNumGuildMembers() do
		local member = GetGuildRosterInfo(i)
		if member and Ambiguate(member, "short") == Ambiguate(name, "short") then
			return true
		end
	end
	return false
end)

-- Classes and races ------------------------------------------------------------------------------

local classFiles = {
	[1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE", [5] = "PRIEST",
	[6] = "DEATHKNIGHT", [7] = "SHAMAN", [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID",
}
local classIDs = tInvert(classFiles)

define("GetNumClasses", function() return 11 end)

define("GetClassInfo", function(classID)
	local file = classFiles[classID]
	if not file then
		return nil
	end
	local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file] or file
	return name, file, classID
end)

define("GetClassIDFromFile", function(classFile)
	return classIDs[classFile]
end)

local races = {
	[1] = { "Human", "Human" }, [2] = { "Orc", "Orc" }, [3] = { "Dwarf", "Dwarf" },
	[4] = { "Night Elf", "NightElf" }, [5] = { "Undead", "Scourge" }, [6] = { "Tauren", "Tauren" },
	[7] = { "Gnome", "Gnome" }, [8] = { "Troll", "Troll" }, [10] = { "Blood Elf", "BloodElf" },
	[11] = { "Draenei", "Draenei" },
}

define("GetClassAtlas", function() return nil end)

-- Specialisations: 3.3.5 talent trees, numbered with the modern specialisation IDs.
local specs = {
	WARRIOR = { { 71, "Arms", "DAMAGER" }, { 72, "Fury", "DAMAGER" }, { 73, "Protection", "TANK" } },
	PALADIN = { { 65, "Holy", "HEALER" }, { 66, "Protection", "TANK" }, { 70, "Retribution", "DAMAGER" } },
	HUNTER = { { 253, "Beast Mastery", "DAMAGER" }, { 254, "Marksmanship", "DAMAGER" }, { 255, "Survival", "DAMAGER" } },
	ROGUE = { { 259, "Assassination", "DAMAGER" }, { 260, "Combat", "DAMAGER" }, { 261, "Subtlety", "DAMAGER" } },
	PRIEST = { { 256, "Discipline", "HEALER" }, { 257, "Holy", "HEALER" }, { 258, "Shadow", "DAMAGER" } },
	DEATHKNIGHT = { { 250, "Blood", "TANK" }, { 251, "Frost", "DAMAGER" }, { 252, "Unholy", "DAMAGER" } },
	SHAMAN = { { 262, "Elemental", "DAMAGER" }, { 263, "Enhancement", "DAMAGER" }, { 264, "Restoration", "HEALER" } },
	MAGE = { { 62, "Arcane", "DAMAGER" }, { 63, "Fire", "DAMAGER" }, { 64, "Frost", "DAMAGER" } },
	WARLOCK = { { 265, "Affliction", "DAMAGER" }, { 266, "Demonology", "DAMAGER" }, { 267, "Destruction", "DAMAGER" } },
	DRUID = { { 102, "Balance", "DAMAGER" }, { 103, "Feral Combat", "DAMAGER" }, { 105, "Restoration", "HEALER" } },
}
local specByID = {}
for classFile, list in pairs(specs) do
	for index, spec in ipairs(list) do
		specByID[spec[1]] = { classFile = classFile, index = index, name = spec[2], role = spec[3] }
	end
end
_G.ModernUI_SpecData = { specs = specs, byID = specByID, classIDs = classIDs, classFiles = classFiles, races = races }

local function playerSpecIndex(isInspect, talentGroup)
	local best, bestPoints = nil, 0
	for i = 1, GetNumTalentTabs(isInspect) do
		local _, _, points = GetTalentTabInfo(i, isInspect, nil, talentGroup)
		if points and points > bestPoints then
			best, bestPoints = i, points
		end
	end
	return best
end

define("GetNumSpecializations", function() return 3 end)
define("GetNumSpecializationsForClassID", function(classID) return classFiles[classID] and 3 or 0 end)

define("GetSpecialization", function(isInspect, isPet, specGroup)
	if isPet then
		return nil
	end
	return playerSpecIndex(isInspect, specGroup or GetActiveTalentGroup(isInspect))
end)

define("GetActiveSpecGroup", function(isInspect) return GetActiveTalentGroup(isInspect) end)
define("GetNumSpecGroups", function(isInspect) return GetNumTalentGroups(isInspect) end)

define("GetSpecializationInfo", function(specIndex, isInspect, isPet)
	if isPet then
		return nil
	end
	local _, classFile = UnitClass("player")
	local spec = specs[classFile] and specs[classFile][specIndex]
	if not spec then
		return nil
	end
	local name, icon, _, _, description = GetTalentTabInfo(specIndex, isInspect)
	return spec[1], name or spec[2], description or "", icon, spec[3], nil
end)

define("GetSpecializationRole", function(specIndex)
	local _, classFile = UnitClass("player")
	local spec = specs[classFile] and specs[classFile][specIndex]
	return spec and spec[3]
end)

define("GetSpecializationInfoByID", function(specID)
	local spec = specByID[specID]
	if not spec then
		return nil
	end
	local className = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[spec.classFile] or spec.classFile
	return specID, spec.name, "", nil, spec.role, spec.classFile, className
end)

define("GetSpecializationInfoForClassID", function(classID, specIndex)
	local list = specs[classFiles[classID] or ""]
	local spec = list and list[specIndex]
	if not spec then
		return nil
	end
	return spec[1], spec[2], "", nil, spec[3], false, true
end)

define("GetSpecializationRoleByID", function(specID)
	return specByID[specID] and specByID[specID].role
end)

define("GetSpecializationInfoForSpecID", _G.GetSpecializationInfoByID)
define("GetInspectSpecialization", function() return 0 end)
define("GetTalentGroupRole", function() return "NONE" end)
define("GetPrimaryTalentTree", function(isInspect, isPet, talentGroup) return playerSpecIndex(isInspect, talentGroup) end)

-- Sounds: modern code passes sound kit numbers; this client plays sounds by name.
-- Numbers are accepted (and ignored) rather than raising an error.
do
	local PlaySound_335 = PlaySound
	_G.PlaySound = function(sound, channel, ...)
		if type(sound) == "number" then
			return false
		end
		return PlaySound_335(sound, channel, ...)
	end
	local PlaySoundFile_335 = PlaySoundFile
	_G.PlaySoundFile = function(file, channel, ...)
		if type(file) == "number" then
			return false
		end
		return PlaySoundFile_335(file, channel, ...)
	end
end
define("StopSound", function() end)
define("SOUNDKIT", setmetatable({}, { __index = function() return 0 end }))

-- Text to speech does not exist in this client.
define("TextToSpeech_Speak", function() end)
define("TextToSpeech_Stop", function() end)
define("TextToSpeech_GetSelectedVoice", function() return nil end)
define("TextToSpeech_GetSelectedVoiceID", function() return nil end)

-- File IDs do not exist in this client: files are addressed by path.
define("GetFileIDFromPath", function() return nil end)

define("ButtonFrameTemplate_HidePortrait", function(frame)
	if frame.portrait then frame.portrait:Hide() end
	if frame.PortraitContainer then frame.PortraitContainer:Hide() end
end)
define("ButtonFrameTemplate_ShowPortrait", function(frame)
	if frame.portrait then frame.portrait:Show() end
	if frame.PortraitContainer then frame.PortraitContainer:Show() end
end)

define("IsLevelAtEffectiveMaxLevel", function(level) return level >= 80 end)
define("IsPlayerAtEffectiveMaxLevel", function() return UnitLevel("player") >= 80 end)
define("IsXPUserDisabled", function() return false end)
define("GetCVarNumberOrDefault", function(name) return tonumber(GetCVar(name)) or (GetCVarDefault and tonumber(GetCVarDefault(name))) end)
define("CVarCallbackRegistry", _G.CVarCallbackRegistry or (function()
	local r = CreateCallbackRegistry()
	r.GetCVarValueBool = function(_, name) return GetCVarBool(name) end
	r.GetCVarNumberOrDefault = function(_, name) return GetCVarNumberOrDefault(name) end
	r.SetCVarCachable = function() end
	return r
end)())

define("GetServerTime", function() return time() end)
define("Kiosk", { IsEnabled = function() return false end })
define("IsOnGlueScreen", function() return false end)
define("IsPublicBuild", function() return true end)
define("IsBetaBuild", function() return false end)
define("IsTestBuild", function() return false end)
define("IsPublicTestClient", function() return false end)
define("GetGameAccountInfoByGUID", function() return nil end)
define("BNIsSelf", function() return false end)
define("GetMouseFoci", function() return { GetMouseFocus() } end)
define("issecretvalue", function() return false end)
define("canaccessvalue", function() return true end)
define("canaccessallvalues", function() return true end)
define("issecrettable", function() return false end)
define("canaccesstable", function() return true end)

-- Old names that later clients renamed, so code written for either works.
define("GetAddOnEnableState", function(character, name)
	if name == nil then
		name, character = character, nil
	end
	local _, _, _, enabled = GetAddOnInfo(name)
	return enabled and 2 or 0
end)

-- Constants and strings modern code reads at load time ------------------------------------------

define("NUM_LE_EXPANSION_LEVELS", 2)
define("EXPANSION_NAME0", "Classic")
define("EXPANSION_NAME1", "The Burning Crusade")
define("EXPANSION_NAME2", "Wrath of the Lich King")
define("NUM_BANKBAGSLOTS", 7)
define("NUM_BAG_SLOTS", 4)
define("Constants", {})
Constants.InventoryConstants = Constants.InventoryConstants or {
	NumBagSlots = 4, NumReagentBagSlots = 0, NumCharacterBankSlots = 7, NumAccountBankSlots = 0,
}
define("LE_UNIT_STAT_STRENGTH", 1)
define("LE_UNIT_STAT_AGILITY", 2)
define("LE_UNIT_STAT_STAMINA", 3)
define("LE_UNIT_STAT_INTELLECT", 4)
define("LE_UNIT_STAT_SPIRIT", 5)
define("ON_USE", ITEM_SPELL_TRIGGER_ONUSE or "Use:")
define("ON_EQUIP", ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:")
define("ON_PROC", ITEM_SPELL_TRIGGER_ONPROC or "Chance on hit:")
define("ITEM_BONUS", "Bonus:")
define("ITEM_LEVEL_PLUS", "Item Level %d+")
define("STAT_HASTE", SPELL_STAT_HASTE or "Haste")
define("STAT_CRITICAL_STRIKE", "Critical Strike")
define("STAT_MASTERY", "Mastery")
define("STAT_VERSATILITY", "Versatility")
define("STAT_AVOIDANCE", "Avoidance")
define("STAT_LIFESTEAL", "Leech")
define("STAT_SPEED", "Speed")
define("STAT_MOVEMENT_SPEED", "Movement Speed")

-- Difficulty IDs: modern numbering (3/4 = 10/25 normal, 5/6 = 10/25 heroic) from 3.3.5's own settings.
local raidDifficultyIDs = { [1] = 3, [2] = 4, [3] = 5, [4] = 6 }
local raidDifficultyIndex = tInvert(raidDifficultyIDs)
define("GetRaidDifficultyID", function() return raidDifficultyIDs[GetRaidDifficulty()] or 3 end)
define("GetDungeonDifficultyID", function() return GetDungeonDifficulty() or 1 end)
define("GetLegacyRaidDifficultyID", function() return raidDifficultyIDs[GetRaidDifficulty()] or 3 end)
define("SetRaidDifficultyID", function(id) if raidDifficultyIndex[id] then SetRaidDifficulty(raidDifficultyIndex[id]) end end)
define("SetDungeonDifficultyID", function(id) if id == 1 or id == 2 then SetDungeonDifficulty(id) end end)
define("SetLegacyRaidDifficultyID", function(id) if raidDifficultyIndex[id] then SetRaidDifficulty(raidDifficultyIndex[id]) end end)

-- Battle.net game data messages do not exist in this client; defined so code can hook them.
define("BNSendGameData", function() end)
define("BNGetInfo", function() return nil end)

-- Frame names that changed after 3.3.5.
if _G.QuestLogListScrollFrame == nil and _G.QuestLogScrollFrame then
	_G.QuestLogListScrollFrame = QuestLogScrollFrame
end

-- More modern strings and constants read at load time.
for i, name in ipairs({ "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact", "Heirloom", "WoW Token" }) do
	define("ITEM_QUALITY" .. (i - 1) .. "_DESC", name)
end
define("ITEM_UPGRADE_TOOLTIP_FORMAT", "Upgrade Level: %d/%d")
define("AMMO_DAMAGE_TEMPLATE", "Adds %s damage per second")
define("CR_CRIT_TOOLTIP", "Critical Strike\nChance of extra effectiveness on damage and healing.")
define("STAT_HASTE_BASE_TOOLTIP", "Haste\nIncreases attack speed and spell casting speed.")
define("CR_VERSATILITY_TOOLTIP", "Versatility\nIncreases damage and healing done and reduces damage taken.")
define("ITEM_SET_BONUS_GRAY", ITEM_SET_BONUS or "Set: %s")
