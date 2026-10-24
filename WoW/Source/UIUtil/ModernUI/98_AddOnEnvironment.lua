-- ModernUI: built into the client (not in the original 3.3.5a).
-- The environment the Lua files of AddOns written for modern clients run in (set natively when such an
-- AddOn loads, from its .toc's Interface line). A handful of functions kept their names on modern clients
-- but return their values in a different order (UnitAura lost the spell rank, GetQuestLogTitle lost the
-- quest tag, UnitGroupRolesAssigned returns a role name...). This client's own interface code needs the
-- 3.3.5 shapes, so the global functions keep them; modern AddOns see the modern shapes here instead.
-- Everything else is the ordinary global table: reads fall through to it and writes go straight into it.

local _G = _G
local select, type, tonumber, match = select, type, tonumber, string.match

local modern = setmetatable({}, { __index = _G })
_G.ModernUI_AddOnEnvironment = setmetatable({}, { __index = modern, __newindex = _G })

-- AddOns written for Classic clients as well (their .toc lists Wrath, Cata... Classic) run here instead: the same,
-- except that the systems only retail clients have (13_RetailOnlyNamespaces.lua) are absent, as on a Classic
-- client. Such code checks for them ("if C_Garrison then") and takes its Classic path.
local retailOnly = _G.ModernUI_RetailOnlyNamespaces or {}
_G.ModernUI_ClassicAddOnEnvironment = setmetatable({}, {
	__index = function(_, key)
		if retailOnly[key] then
			return nil
		end
		return modern[key]
	end,
	__newindex = _G,
})
_G.ModernUI_ModernAPI = modern -- the modern-shape functions, for code that wants them explicitly

-- The spell ID of a spell known by name, where the client can tell (spells in the player's spellbook).
local function spellIDByName(name)
	local link = name and GetSpellLink and GetSpellLink(name)
	return link and tonumber(match(link, "spell:(%d+)")) or nil
end
local function isPlayerSide(unit)
	return unit == "player" or unit == "pet" or unit == "vehicle"
end

-- Auras: name, icon, count, dispelType, duration, expirationTime, source, isStealable,
-- nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, nameplateShowAll, timeMod.
local UnitAura_335, UnitBuff_335, UnitDebuff_335 = _G.UnitAura, _G.UnitBuff, _G.UnitDebuff
local function reshapeAura(name, _, icon, count, debuffType, duration, expirationTime, caster, isStealable, _, spellId)
	if not name then
		return nil
	end
	return name, icon, count or 0, debuffType, duration or 0, expirationTime or 0, caster, isStealable and true or false,
		false, spellId, false, false, isPlayerSide(caster), false, 1
end
modern.UnitAura = function(unit, index, filter) return reshapeAura(UnitAura_335(unit, index, filter)) end
modern.UnitBuff = function(unit, index, filter) return reshapeAura(UnitBuff_335(unit, index, filter)) end
modern.UnitDebuff = function(unit, index, filter) return reshapeAura(UnitDebuff_335(unit, index, filter)) end

-- Quest log: title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID,
-- startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling.
local GetQuestLogTitle_335 = _G.GetQuestLogTitle
modern.GetQuestLogTitle = function(index)
	local title, level, _, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle_335(index)
	if not title then
		return nil
	end
	return title, level, suggestedGroup or 0, isHeader and true or false, isCollapsed and true or false, isComplete,
		isDaily and 2 or 1, questID or 0, false, false, false, false, false, false, false, false, false
end

-- Casts: name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellId.
local UnitCastingInfo_335, UnitChannelInfo_335 = _G.UnitCastingInfo, _G.UnitChannelInfo
modern.UnitCastingInfo = function(unit)
	local name, _, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo_335(unit)
	if not name then
		return nil
	end
	return name, text, texture, startTime, endTime, isTradeSkill and true or false, castID, notInterruptible and true or false,
		isPlayerSide(unit) and spellIDByName(name) or nil
end
modern.UnitChannelInfo = function(unit)
	local name, _, text, texture, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo_335(unit)
	if not name then
		return nil
	end
	return name, text, texture, startTime, endTime, isTradeSkill and true or false, notInterruptible and true or false,
		isPlayerSide(unit) and spellIDByName(name) or nil
end

-- Spells: name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon.
local GetSpellInfo_335 = _G.GetSpellInfo
modern.GetSpellInfo = function(spell, rank)
	-- A second argument (even nil) makes this client read the first as a spellbook slot.
	local name, spellRank, icon, _, _, _, castTime, minRange, maxRange
	if rank ~= nil then
		name, spellRank, icon, _, _, _, castTime, minRange, maxRange = GetSpellInfo_335(spell, rank)
	else
		name, spellRank, icon, _, _, _, castTime, minRange, maxRange = GetSpellInfo_335(spell)
	end
	if not name then
		return nil
	end
	local id = type(spell) == "number" and spell or tonumber(spell) or spellIDByName(name)
	return name, spellRank, icon, castTime, minRange, maxRange, id, icon
end

-- Loot: texture, item, quantity, currencyID, quality, locked, isQuestItem, questID, isActive.
local GetLootSlotInfo_335 = _G.GetLootSlotInfo
modern.GetLootSlotInfo = function(slot)
	local texture, item, quantity, quality, locked = GetLootSlotInfo_335(slot)
	if not texture then
		return nil
	end
	return texture, item, quantity, nil, quality, locked, false, nil, false
end

-- Roles: one role name instead of three flags.
local UnitGroupRolesAssigned_335 = _G.UnitGroupRolesAssigned
modern.UnitGroupRolesAssigned = function(unit)
	local tank, healer, damage = UnitGroupRolesAssigned_335(unit)
	return tank and "TANK" or healer and "HEALER" or damage and "DAMAGER" or "NONE"
end

-- Shapeshift forms: icon, active, castable, spellID.
local GetShapeshiftFormInfo_335 = _G.GetShapeshiftFormInfo
modern.GetShapeshiftFormInfo = function(index)
	local texture, name, isActive, isCastable = GetShapeshiftFormInfo_335(index)
	if not texture then
		return nil
	end
	return texture, isActive and true or false, isCastable and true or false, spellIDByName(name)
end

-- Pet actions: name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID, hasRange, inRange.
local GetPetActionInfo_335 = _G.GetPetActionInfo
modern.GetPetActionInfo = function(index)
	local name, _, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo_335(index)
	if not name then
		return nil
	end
	return name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, not isToken and spellIDByName(name) or nil, false, false
end

-- GUIDs in the modern form ("Creature-0-1-0-F130-19811-0000A1C2"); see 37_GUID.lua.
local toModern = _G.ModernUI_ModernGUID
if toModern then
	local UnitGUID_335 = _G.UnitGUID
	modern.UnitGUID = function(unit)
		return toModern(UnitGUID_335(unit))
	end
	local CombatLogGetCurrentEventInfo_global = _G.CombatLogGetCurrentEventInfo
	if CombatLogGetCurrentEventInfo_global then
		local event = {}
		local function keep(...)
			local n = select("#", ...)
			for i = 1, n do
				event[i] = (select(i, ...))
			end
			event[4] = toModern(event[4])
			event[8] = toModern(event[8])
			return n
		end
		modern.CombatLogGetCurrentEventInfo = function()
			local n = keep(CombatLogGetCurrentEventInfo_global())
			return unpack(event, 1, n)
		end
	end
end

-- UnitClassBase: this client answers the class's name and file name; modern clients the file name and class ID.
do
	local UnitClass_global = _G.UnitClass
	modern.UnitClassBase = function(unit)
		local _, file, id = UnitClass_global(unit)
		return file, id
	end
end

-- SetUIVisibility: modern clients hide or show the whole interface (as Alt-Z does); this client's only turns the
-- world's unit names and highlights off, and its interface code hides UIParent itself.
do
	local SetUIVisibility_335 = _G.SetUIVisibility
	modern.SetUIVisibility = function(visible)
		if SetUIVisibility_335 then
			SetUIVisibility_335(visible)
		end
		if visible then
			UIParent:Show()
		else
			UIParent:Hide()
		end
	end
end
