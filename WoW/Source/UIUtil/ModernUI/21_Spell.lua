-- ModernUI: built into the client (not in the original 3.3.5a).
-- C_Spell, C_SpellBook and the Spell object, answered from this client's spell functions.

local _G = _G
local type, select, tonumber, pairs, ipairs = type, select, tonumber, pairs, ipairs

local function spellID(spell)
	if type(spell) == "number" then
		return spell
	end
	if type(spell) == "string" then
		local id = tonumber(spell) or tonumber(spell:match("spell:(%d+)"))
		if id then
			return id
		end
		local link = GetSpellLink(spell)
		return link and tonumber(link:match("spell:(%d+)"))
	end
end

local function spellName(spell)
	if type(spell) == "string" and not spell:find("spell:") and not tonumber(spell) then
		return spell
	end
	local id = spellID(spell)
	return id and (GetSpellInfo(id))
end

local function makeLink(id, name)
	return ("|cff71d5ff|Hspell:%d|h[%s]|h|r"):format(id, name)
end

-- A hidden tooltip for the few things only a tooltip shows (descriptions).
local scanner
local function scanTooltip()
	if not scanner then
		scanner = CreateFrame("GameTooltip", "ModernUIScanTooltip", nil, "GameTooltipTemplate")
		scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
	end
	scanner:ClearLines()
	scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
	return scanner
end
_G.ModernUI_GetScanTooltip = scanTooltip

local C_Spell = _G.C_Spell or {}
_G.C_Spell = C_Spell

local function set(name, fn)
	if C_Spell[name] == nil then
		C_Spell[name] = fn
	end
end

set("GetSpellInfo", function(spell)
	local id = spellID(spell)
	local name, _, icon, _, _, _, castTime, minRange, maxRange = GetSpellInfo(id or spell)
	if not name then
		return nil
	end
	return {
		name = name, iconID = icon, originalIconID = icon, castTime = castTime or 0,
		minRange = minRange or 0, maxRange = maxRange or 0, spellID = id,
	}
end)
set("GetSpellName", function(spell) return (GetSpellInfo(spellID(spell) or spell)) end)
set("GetSpellSubtext", function(spell) return (select(2, GetSpellInfo(spellID(spell) or spell))) end)
set("GetSpellTexture", function(spell)
	local icon = select(3, GetSpellInfo(spellID(spell) or spell))
	return icon, icon
end)
set("GetSpellLink", function(spell)
	local id = spellID(spell)
	local name = id and GetSpellInfo(id)
	return name and makeLink(id, name)
end)
set("GetSpellIDForSpellIdentifier", function(spell) return spellID(spell) end)
set("DoesSpellExist", function(spell) return GetSpellInfo(spellID(spell) or spell) ~= nil end)
set("IsSpellDataCached", function() return true end)
set("RequestLoadSpellData", function() end)
set("GetSpellCooldown", function(spell)
	local name = spellName(spell)
	if not name then
		return nil
	end
	local start, duration, enabled = GetSpellCooldown(name)
	if not start then
		return nil
	end
	return { startTime = start, duration = duration, isEnabled = enabled == 1, modRate = 1, isActive = duration > 0 }
end)
set("GetSpellCharges", function() return nil end)
set("GetSpellCastCount", function(spell)
	local name = spellName(spell)
	return name and GetSpellCount and GetSpellCount(name) or 0
end)
set("GetSpellLossOfControlCooldown", function() return 0, 0 end)
set("GetSpellLossOfControlCooldownInfo", function() return nil end)
set("GetOverrideSpell", function(spell) return spellID(spell) end)
set("GetBaseSpell", function(spell) return spellID(spell) end)
set("GetSpellPowerCost", function(spell)
	local _, _, _, cost, _, powerType = GetSpellInfo(spellID(spell) or spell)
	if not cost or cost == 0 then
		return {}
	end
	return { { type = powerType, cost = cost, minCost = cost, costPercent = 0, costPerSec = 0, requiredAuraID = 0, hasRequiredAura = false } }
end)
set("IsSpellUsable", function(spell)
	local name = spellName(spell)
	if not name then
		return false, false
	end
	local usable, noMana = IsUsableSpell(name)
	return usable and true or false, noMana and true or false
end)
set("IsCurrentSpell", function(spell)
	local name = spellName(spell)
	return name and IsCurrentSpell(name) and true or false
end)
set("IsAutoRepeatSpell", function(spell)
	local name = spellName(spell)
	return name and IsAutoRepeatSpell(name) and true or false
end)
set("IsSpellHarmful", function(spell)
	local name = spellName(spell)
	return name and IsHarmfulSpell(name) and true or false
end)
set("IsSpellHelpful", function(spell)
	local name = spellName(spell)
	return name and IsHelpfulSpell(name) and true or false
end)
set("IsSpellInRange", function(spell, unit)
	local name = spellName(spell)
	local result = name and IsSpellInRange(name, unit)
	if result == nil then
		return nil
	end
	return result == 1
end)
set("SpellHasRange", function(spell)
	local name = spellName(spell)
	return name and SpellHasRange(name) and true or false
end)
set("IsSpellPassive", function() return false end)
set("IsPressHoldReleaseSpell", function() return false end)
set("IsExternalDefensive", function() return false end)
set("IsSelfBuff", function() return false end)
set("PickupSpell", function(spell) PickupSpell(spellName(spell)) end)
set("GetSpellDescription", function(spell)
	local id = spellID(spell)
	if not id then
		return ""
	end
	local tip = scanTooltip()
	tip:SetHyperlink("spell:" .. id)
	local n = tip:NumLines()
	local line = n > 0 and _G["ModernUIScanTooltipTextLeft" .. n]
	return line and line:GetText() or ""
end)
set("GetSchoolString", function(mask)
	local names = {
		{ 1, STRING_SCHOOL_PHYSICAL or "Physical" }, { 2, STRING_SCHOOL_HOLY or "Holy" },
		{ 4, STRING_SCHOOL_FIRE or "Fire" }, { 8, STRING_SCHOOL_NATURE or "Nature" },
		{ 16, STRING_SCHOOL_FROST or "Frost" }, { 32, STRING_SCHOOL_SHADOW or "Shadow" },
		{ 64, STRING_SCHOOL_ARCANE or "Arcane" },
	}
	local parts = {}
	for _, pair in ipairs(names) do
		if bit.band(mask or 0, pair[1]) ~= 0 then
			parts[#parts + 1] = pair[2]
		end
	end
	return table.concat(parts, ", ")
end)
set("GetSpellTradeSkillLink", function() return nil end)
set("GetSpellAutoCast", function(spell)
	local name = spellName(spell)
	if not name then
		return false, false
	end
	local autoCastAllowed, autoCastEnabled = GetSpellAutocast(name, "pet")
	return autoCastAllowed and true or false, autoCastEnabled and true or false
end)
set("TargetSpellIsEnemy", function() return false end)
set("GetVisibilityInfo", function() return false end)

-- Spell object.
local SpellMixin = _G.SpellMixin or {}
_G.SpellMixin = SpellMixin
local Spell = _G.Spell or {}
_G.Spell = Spell
function Spell:CreateFromSpellID(id)
	local spell = CreateFromMixins(SpellMixin)
	spell:SetSpellID(id)
	return spell
end
function SpellMixin:SetSpellID(id) self.spellID = id end
function SpellMixin:GetSpellID() return self.spellID end
function SpellMixin:Clear() self.spellID = nil end
function SpellMixin:IsSpellEmpty() return self.spellID == nil end
function SpellMixin:IsSpellDataCached() return true end
function SpellMixin:IsDataEvictable() return false end
function SpellMixin:GetSpellName() return (GetSpellInfo(self.spellID)) end
function SpellMixin:GetSpellSubtext() return (select(2, GetSpellInfo(self.spellID))) end
function SpellMixin:GetSpellTexture() return (select(3, GetSpellInfo(self.spellID))) end
function SpellMixin:GetSpellDescription() return C_Spell.GetSpellDescription(self.spellID) end
function SpellMixin:ContinueOnSpellLoad(callback) callback() end
function SpellMixin:ContinueWithCancelOnSpellLoad(callback) callback() return function() end end

-- C_SpellBook --------------------------------------------------------------------------------------

local C_SpellBook = _G.C_SpellBook or {}
_G.C_SpellBook = C_SpellBook

local function bset(name, fn)
	if C_SpellBook[name] == nil then
		C_SpellBook[name] = fn
	end
end

local function bookType(bank)
	return bank == 1 and (BOOKTYPE_PET or "pet") or (BOOKTYPE_SPELL or "spell")
end

local function bookSpellID(index, bank)
	local link = GetSpellLink(index, bookType(bank))
	return link and tonumber(link:match("spell:(%d+)"))
end

bset("IsSpellKnown", function(id, isPet) return IsSpellKnown(id, isPet) and true or false end)
bset("IsSpellKnownOrInSpellBook", function(id, bank) return IsSpellKnown(id, bank == 1) and true or false end)
bset("IsSpellInSpellBook", function(id, bank) return IsSpellKnown(id, bank == 1) and true or false end)
bset("FindSpellOverrideByID", function(id) return id end)
bset("FindBaseSpellByID", function(id) return id end)
bset("GetOverrideSpell", function(id) return id end)
bset("HasPetSpells", function() return HasPetSpells() end)
bset("GetNumSpellBookSkillLines", function() return GetNumSpellTabs() end)
bset("GetSpellBookSkillLineInfo", function(index)
	local name, icon, offset, numSpells = GetSpellTabInfo(index)
	if not name then
		return nil
	end
	return {
		name = name, iconID = icon, itemIndexOffset = offset, numSpellBookItems = numSpells,
		isGuild = false, shouldHide = false, offSpecID = nil, specID = nil,
	}
end)
bset("GetSpellBookItemName", function(index, bank)
	return GetSpellName(index, bookType(bank))
end)
bset("GetSpellBookItemTexture", function(index, bank)
	return GetSpellTexture(index, bookType(bank))
end)
bset("GetSpellBookItemLink", function(index, bank)
	return GetSpellLink(index, bookType(bank))
end)
bset("GetSpellBookItemType", function(index, bank)
	local name = GetSpellName(index, bookType(bank))
	if not name then
		return Enum.SpellBookItemType.None
	end
	local id = bookSpellID(index, bank)
	return Enum.SpellBookItemType.Spell, id, id
end)
bset("GetSpellBookItemInfo", function(index, bank)
	local book = bookType(bank)
	local name, subName = GetSpellName(index, book)
	if not name then
		return nil
	end
	local id = bookSpellID(index, bank)
	return {
		actionID = id, spellID = id, itemType = Enum.SpellBookItemType.Spell, name = name, subName = subName or "",
		iconID = GetSpellTexture(index, book), isPassive = IsPassiveSpell(index, book) and true or false,
		isOffSpec = false, skillLineIndex = nil,
	}
end)
bset("GetSpellBookItemCooldown", function(index, bank)
	local start, duration, enabled = GetSpellCooldown(index, bookType(bank))
	if not start then
		return nil
	end
	return { startTime = start, duration = duration, isEnabled = enabled == 1, modRate = 1 }
end)
bset("IsSpellBookItemPassive", function(index, bank) return IsPassiveSpell(index, bookType(bank)) and true or false end)
bset("PickupSpellBookItem", function(index, bank) PickupSpell(index, bookType(bank)) end)
bset("CastSpellBookItem", function(index, bank) CastSpell(index, bookType(bank)) end)
bset("GetSpellBookItemLevelLearned", function() return 0 end)
bset("GetSkillLineIndexByID", function() return nil end)
bset("ContainsAnyDisenchantSpell", function() return IsSpellKnown(13262) end)
bset("GetCurrentLevelSpells", function() return {} end)

-- GetSpellBookItemInfo(index, bookType) as on Wrath Classic: the entry's type and spell ID (two values; the
-- retail table form is C_SpellBook.GetSpellBookItemInfo).
if _G.GetSpellBookItemInfo == nil then
	_G.GetSpellBookItemInfo = function(index, book)
		book = (book == 1 or book == "pet" or book == BOOKTYPE_PET) and (BOOKTYPE_PET or "pet") or (BOOKTYPE_SPELL or "spell")
		local name = GetSpellName(index, book)
		if not name then
			return nil
		end
		local link = GetSpellLink(index, book)
		local id = link and tonumber(link:match("spell:(%d+)"))
		if book == (BOOKTYPE_PET or "pet") then
			return "PETACTION", id
		end
		return IsSpellKnown and id and not IsSpellKnown(id) and "FUTURESPELL" or "SPELL", id
	end
end
