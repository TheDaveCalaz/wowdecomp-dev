-- ModernUI: built into the client (not in the original 3.3.5a).
-- C_UnitAuras, AuraUtil and C_TooltipInfo, built on UnitAura and a hidden tooltip.

local _G = _G
local type, select, tostring, pairs, ipairs = type, select, tostring, pairs, ipairs

-- Aura instance IDs: modern code identifies an aura by a number that stays the same while the aura
-- lasts. Here the number is given out per (unit, spell, caster, expiry) the first time it is seen.
local instanceIDs = {}
local nextInstanceID = 0
local instanceLookup = {}

local function instanceID(unit, spellId, caster, expirationTime, filterKind)
	local guid = UnitGUID(unit) or unit
	local key = ("%s:%s:%s:%s:%s"):format(guid, tostring(spellId), tostring(caster and UnitGUID(caster) or ""), tostring(expirationTime), filterKind)
	local id = instanceIDs[key]
	if not id then
		nextInstanceID = nextInstanceID + 1
		id = nextInstanceID
		instanceIDs[key] = id
	end
	return id
end

local function isHarmfulFilter(filter)
	return type(filter) == "string" and filter:upper():find("HARMFUL") ~= nil
end

local function auraData(unit, index, filter)
	local name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable, shouldConsolidate, spellId = UnitAura(unit, index, filter)
	if not name then
		return nil
	end
	local harmful = isHarmfulFilter(filter)
	local id = instanceID(unit, spellId, caster, expirationTime, harmful and "H" or "B")
	local data = {
		name = name, icon = icon, applications = count or 0, dispelName = debuffType, duration = duration or 0,
		expirationTime = expirationTime or 0, sourceUnit = caster, isStealable = isStealable and true or false,
		nameplateShowPersonal = false, spellId = spellId, canApplyAura = false, isBossAura = false,
		isFromPlayerOrPlayerPet = caster == "player" or caster == "pet" or caster == "vehicle",
		nameplateShowAll = false, timeMod = 1, points = {}, isHelpful = not harmful, isHarmful = harmful,
		isRaid = type(filter) == "string" and filter:upper():find("RAID") ~= nil, isNameplateOnly = false,
		charges = nil, maxCharges = nil, auraInstanceID = id, shouldConsolidate = shouldConsolidate,
	}
	instanceLookup[id] = { unit = unit, index = index, filter = filter }
	return data
end

local C_UnitAuras = _G.C_UnitAuras or {}
_G.C_UnitAuras = C_UnitAuras

local function set(name, fn)
	if C_UnitAuras[name] == nil then
		C_UnitAuras[name] = fn
	end
end

set("GetAuraDataByIndex", function(unit, index, filter) return auraData(unit, index, filter or "HELPFUL") end)
-- Every aura of a unit that matches the filter, in order (C_UnitAuras.GetUnitAuras(unit, filter, maxCount)).
set("GetUnitAuras", function(unit, filter, maxCount)
	local out = {}
	filter = filter or "HELPFUL"
	for i = 1, 255 do
		if maxCount and #out >= maxCount then
			break
		end
		local data = auraData(unit, i, filter)
		if not data then
			break
		end
		out[#out + 1] = data
	end
	return out
end)
set("GetBuffDataByIndex", function(unit, index, filter) return auraData(unit, index, "HELPFUL" .. (filter and ("|" .. filter) or "")) end)
set("GetDebuffDataByIndex", function(unit, index, filter) return auraData(unit, index, "HARMFUL" .. (filter and ("|" .. filter) or "")) end)
set("GetAuraDataBySpellName", function(unit, spellName, filter)
	filter = filter or "HELPFUL"
	for i = 1, 40 do
		local name = UnitAura(unit, i, filter)
		if not name then
			return nil
		end
		if name == spellName then
			return auraData(unit, i, filter)
		end
	end
end)
set("GetPlayerAuraBySpellID", function(spellID)
	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		for i = 1, 40 do
			local name, _, _, _, _, _, _, _, _, _, id = UnitAura("player", i, filter)
			if not name then
				break
			end
			if id == spellID then
				return auraData("player", i, filter)
			end
		end
	end
end)
set("GetUnitAuraBySpellID", function(unit, spellID, filter)
	for i = 1, 40 do
		local name, _, _, _, _, _, _, _, _, _, id = UnitAura(unit, i, filter or "HELPFUL")
		if not name then
			return nil
		end
		if id == spellID then
			return auraData(unit, i, filter or "HELPFUL")
		end
	end
end)
set("GetAuraDataByAuraInstanceID", function(unit, auraInstanceID)
	local where = instanceLookup[auraInstanceID]
	if where and where.unit == unit then
		local data = auraData(unit, where.index, where.filter)
		if data and data.auraInstanceID == auraInstanceID then
			return data
		end
	end
	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		for i = 1, 40 do
			local data = auraData(unit, i, filter)
			if not data then
				break
			end
			if data.auraInstanceID == auraInstanceID then
				return data
			end
		end
	end
end)
-- Slots: helpful auras are 1..40, harmful ones 1001..1040.
set("GetAuraSlots", function(unit, filter, maxSlots, continuationToken)
	local base = isHarmfulFilter(filter) and 1000 or 0
	local slots = {}
	for i = 1, maxSlots or 40 do
		if not UnitAura(unit, i, filter) then
			break
		end
		slots[#slots + 1] = base + i
	end
	return nil, unpack(slots)
end)
set("GetAuraDataBySlot", function(unit, slot)
	if slot > 1000 then
		return auraData(unit, slot - 1000, "HARMFUL")
	end
	return auraData(unit, slot, "HELPFUL")
end)
set("IsAuraFilteredOutByInstanceID", function() return false end)
set("WantsAlteredForm", function() return false end)
set("AddPrivateAuraAnchor", function() return nil end)
set("RemovePrivateAuraAnchor", function() end)
set("AddPrivateAuraAppliedSound", function() return nil end)
set("RemovePrivateAuraAppliedSound", function() end)
set("SetPrivateWarningTextAnchor", function() end)
set("GetCooldownAuraBySpellID", function() return nil end)

-- AuraUtil --------------------------------------------------------------------------------------

local AuraUtil = _G.AuraUtil or {}
_G.AuraUtil = AuraUtil

AuraUtil.ForEachAura = AuraUtil.ForEachAura or function(unit, filter, maxCount, func, usePackedAura)
	for i = 1, maxCount or 40 do
		if usePackedAura then
			local data = auraData(unit, i, filter)
			if not data then
				return
			end
			if func(data) then
				return
			end
		else
			local results = { UnitAura(unit, i, filter) }
			if not results[1] then
				return
			end
			if func(unpack(results, 1, 11)) then
				return
			end
		end
	end
end

AuraUtil.FindAuraByName = AuraUtil.FindAuraByName or function(auraName, unit, filter)
	for i = 1, 40 do
		local results = { UnitAura(unit, i, filter) }
		if not results[1] then
			return nil
		end
		if results[1] == auraName then
			return unpack(results, 1, 11)
		end
	end
end

AuraUtil.FindAura = AuraUtil.FindAura or function(predicate, unit, filter, ...)
	for i = 1, 40 do
		local results = { UnitAura(unit, i, filter) }
		if not results[1] then
			return nil
		end
		if predicate(..., unpack(results, 1, 11)) then
			return unpack(results, 1, 11)
		end
	end
end

AuraUtil.UnpackAuraData = AuraUtil.UnpackAuraData or function(data)
	if not data then
		return nil
	end
	return data.name, data.icon, data.applications, data.dispelName, data.duration, data.expirationTime,
		data.sourceUnit, data.isStealable, data.nameplateShowPersonal, data.spellId, data.canApplyAura,
		data.isBossAura, data.isFromPlayerOrPlayerPet, data.nameplateShowAll, data.timeMod
end

AuraUtil.AuraUpdateChangedType = AuraUtil.AuraUpdateChangedType or { None = 1, Debuff = 2, Buff = 3, Dispel = 4 }
AuraUtil.UnitFrameDebuffType = AuraUtil.UnitFrameDebuffType or { BossDebuff = 1, BossBuff = 2, PriorityDebuff = 3, NonBossRaidDebuff = 4, NonBossDebuff = 5 }
AuraUtil.DispellableDebuffTypes = AuraUtil.DispellableDebuffTypes or { Magic = true, Curse = true, Disease = true, Poison = true }
AuraUtil.ShouldSkipAuraUpdate = AuraUtil.ShouldSkipAuraUpdate or function() return false end
AuraUtil.ProcessAura = AuraUtil.ProcessAura or function() return AuraUtil.AuraUpdateChangedType.None end
AuraUtil.IsPriorityDebuff = AuraUtil.IsPriorityDebuff or function() return false end
AuraUtil.ShouldDisplayBuff = AuraUtil.ShouldDisplayBuff or function() return true end
AuraUtil.ShouldDisplayDebuff = AuraUtil.ShouldDisplayDebuff or function() return true end

-- C_TooltipInfo ---------------------------------------------------------------------------------
-- Fills the hidden tooltip and reads its lines back as modern tooltip data.

local C_TooltipInfo = _G.C_TooltipInfo or {}
_G.C_TooltipInfo = C_TooltipInfo

local function readTooltip(kind, id, hyperlink)
	local tip = ModernUI_GetScanTooltip()
	return tip
end

local function collect(tip, kind, id)
	local n = tip:NumLines()
	if n == 0 then
		return nil
	end
	local lines = {}
	for i = 1, n do
		local left = _G["ModernUIScanTooltipTextLeft" .. i]
		local right = _G["ModernUIScanTooltipTextRight" .. i]
		local leftText = left and left:GetText()
		local rightText = right and right:IsShown() and right:GetText() or nil
		local lr, lg, lb = 1, 1, 1
		if left then lr, lg, lb = left:GetTextColor() end
		local line = {
			leftText = leftText or "", type = Enum.TooltipDataLineType.None,
			leftColor = CreateColor(lr, lg, lb, 1),
		}
		if rightText then
			local rr, rg, rb = right:GetTextColor()
			line.rightText = rightText
			line.rightColor = CreateColor(rr, rg, rb, 1)
		end
		if i == 1 then
			line.type = kind == Enum.TooltipDataType.Unit and Enum.TooltipDataLineType.UnitName or Enum.TooltipDataLineType.None
		end
		lines[i] = line
	end
	local _, link = tip:GetItem()
	if not link then
		local _, _, spell = tip:GetSpell()
		id = id or spell
	end
	return { type = kind, id = id, lines = lines, hyperlink = link, args = {} }
end

local function with(kind, id, fill)
	local tip = ModernUI_GetScanTooltip()
	fill(tip)
	return collect(tip, kind, id)
end

local tset = function(name, fn)
	if C_TooltipInfo[name] == nil then
		C_TooltipInfo[name] = fn
	end
end

local T = Enum.TooltipDataType
tset("GetHyperlink", function(link)
	local kind = link:find("spell:") and T.Spell or (link:find("item:") and T.Item or (link:find("quest:") and T.Quest or nil))
	return with(kind, nil, function(tip) tip:SetHyperlink(link) end)
end)
tset("GetItemByID", function(itemID) return with(T.Item, itemID, function(tip) tip:SetHyperlink("item:" .. itemID) end) end)
tset("GetSpellByID", function(spellID) return with(T.Spell, spellID, function(tip) tip:SetHyperlink("spell:" .. spellID) end) end)
tset("GetBagItem", function(bag, slot)
	local id = GetContainerItemID(bag, slot)
	return with(T.Item, id, function(tip) tip:SetBagItem(bag, slot) end)
end)
tset("GetInventoryItem", function(unit, slot)
	local id = GetInventoryItemID(unit, slot)
	return with(T.Item, id, function(tip) tip:SetInventoryItem(unit, slot) end)
end)
tset("GetUnit", function(unit) return with(T.Unit, nil, function(tip) tip:SetUnit(unit) end) end)
tset("GetUnitAura", function(unit, index, filter) return with(T.UnitAura, nil, function(tip) tip:SetUnitAura(unit, index, filter) end) end)
tset("GetUnitBuff", function(unit, index, filter) return with(T.UnitAura, nil, function(tip) tip:SetUnitBuff(unit, index, filter) end) end)
tset("GetUnitDebuff", function(unit, index, filter) return with(T.UnitAura, nil, function(tip) tip:SetUnitDebuff(unit, index, filter) end) end)
local function byInstance(unit, auraInstanceID, setter)
	local where = instanceLookup[auraInstanceID]
	if not where or where.unit ~= unit then
		return nil
	end
	return with(T.UnitAura, nil, function(tip) tip[setter](tip, unit, where.index, where.filter) end)
end
tset("GetUnitBuffByAuraInstanceID", function(unit, id) return byInstance(unit, id, "SetUnitAura") end)
tset("GetUnitDebuffByAuraInstanceID", function(unit, id) return byInstance(unit, id, "SetUnitAura") end)
tset("GetUnitAuraByAuraInstanceID", function(unit, id) return byInstance(unit, id, "SetUnitAura") end)
tset("GetAction", function(slot) return with(nil, nil, function(tip) tip:SetAction(slot) end) end)
tset("GetMerchantItem", function(index) return with(T.Item, nil, function(tip) tip:SetMerchantItem(index) end) end)
tset("GetLootItem", function(index) return with(T.Item, nil, function(tip) tip:SetLootItem(index) end) end)
tset("GetQuestItem", function(kind, index) return with(T.Item, nil, function(tip) tip:SetQuestItem(kind, index) end) end)
tset("GetQuestLogItem", function(kind, index) return with(T.Item, nil, function(tip) tip:SetQuestLogItem(kind, index) end) end)
tset("GetSpellBookItem", function(index, bank)
	local book = bank == 1 and "pet" or "spell"
	return with(T.Spell, nil, function(tip) tip:SetSpell(index, book) end)
end)

local TooltipUtil = _G.TooltipUtil or {}
_G.TooltipUtil = TooltipUtil
TooltipUtil.SurfaceArgs = TooltipUtil.SurfaceArgs or function(data) return data end
TooltipUtil.GetDisplayedItem = TooltipUtil.GetDisplayedItem or function(tooltip) return tooltip:GetItem() end
TooltipUtil.GetDisplayedSpell = TooltipUtil.GetDisplayedSpell or function(tooltip) return tooltip:GetSpell() end
TooltipUtil.GetDisplayedUnit = TooltipUtil.GetDisplayedUnit or function(tooltip) return tooltip:GetUnit() end

-- TooltipDataProcessor: modern code adds callbacks that run when a tooltip shows something.
-- Here they are driven by the 3.3.5 tooltip script hooks.
if _G.TooltipDataProcessor == nil then
	local callbacks = { all = {} }
	local TooltipDataProcessor = { AllTypes = "ALL" }
	_G.TooltipDataProcessor = TooltipDataProcessor

	function TooltipDataProcessor.AddTooltipPostCall(kind, func)
		local key = kind == "ALL" and "all" or kind
		callbacks[key] = callbacks[key] or {}
		table.insert(callbacks[key], func)
	end
	function TooltipDataProcessor.AddTooltipPreCall(kind, func) end
	function TooltipDataProcessor.AddLinePostCall(kind, func) end
	function TooltipDataProcessor.AddLinePreCall(kind, func) end

	local function run(tooltip, kind, id)
		local data = { type = kind, id = id, lines = {} }
		for _, func in ipairs(callbacks[kind] or {}) do
			pcall(func, tooltip, data)
		end
		for _, func in ipairs(callbacks.all) do
			pcall(func, tooltip, data)
		end
	end

	local function hook(tooltip)
		tooltip:HookScript("OnTooltipSetItem", function(self)
			local _, link = self:GetItem()
			run(self, T.Item, link and tonumber(link:match("item:(%d+)")))
		end)
		tooltip:HookScript("OnTooltipSetSpell", function(self)
			local _, _, id = self:GetSpell()
			run(self, T.Spell, id)
		end)
		tooltip:HookScript("OnTooltipSetUnit", function(self)
			run(self, T.Unit, nil)
		end)
	end
	for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3" }) do
		if _G[name] then
			hook(_G[name])
		end
	end
end
