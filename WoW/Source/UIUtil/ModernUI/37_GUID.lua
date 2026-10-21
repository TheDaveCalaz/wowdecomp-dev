-- ModernUI: built into the client (not in the original 3.3.5a).
-- Modern GUIDs. This client's GUIDs are 64-bit hex numbers ("0xF130004D3B00A1C2"); modern clients write them as
-- dash-separated text ("Creature-0-1-0-0-19811-0000A1C2", "Player-1-0000002A"), and modern AddOns take them apart
-- with strsplit("-", guid) to get the kind of unit and the NPC ID. Modern AddOns (the environment in
-- 98_AddOnEnvironment.lua) are given GUIDs in the modern form; the client's own interface code keeps the 3.3.5
-- form. Every conversion is exact both ways, and every function here that takes a GUID accepts either form.
--
-- Layout of a 3.3.5 GUID (16 hex digits): 4 for the kind (0000 player, F130 creature, F140 pet, F150 vehicle,
-- F110 game object, 4000 item...), 6 for the entry (NPC or object ID), 6 for the counter.
-- Modern form used here: Player-1-<low 8 hex>, or <Kind>-0-1-0-<kind hex>-<entry>-0000<counter hex>.

local _G = _G
local type, tonumber, format, upper, rep, sub, match = type, tonumber, string.format, string.upper, string.rep, string.sub, string.match

local kinds = { F13 = "Creature", F14 = "Pet", F15 = "Vehicle", F11 = "GameObject", F12 = "Transport",
	F10 = "DynamicObject", F50 = "Corpse", ["400"] = "Item" }

local modernOf, legacyOf = {}, {}

local function toModern(guid)
	if type(guid) ~= "string" then
		return guid
	end
	local known = modernOf[guid]
	if known then
		return known
	end
	local hex = match(guid, "^0[xX](%x+)$")
	if not hex then
		return guid -- already modern, or not a GUID
	end
	hex = upper(hex)
	if #hex < 16 then
		hex = rep("0", 16 - #hex) .. hex
	end
	local result
	local high = sub(hex, 1, 4)
	if high == "0000" then
		if sub(hex, 5, 8) == "0000" then
			result = "Player-1-" .. sub(hex, 9)
		else
			result = "Player-1-" .. sub(hex, 5)
		end
	else
		result = format("%s-0-1-0-%s-%d-0000%s", kinds[sub(high, 1, 3)] or "Creature", high, tonumber(sub(hex, 5, 10), 16), sub(hex, 11))
	end
	modernOf[guid] = result
	legacyOf[result] = guid
	return result
end

local function toLegacy(guid)
	if type(guid) ~= "string" then
		return guid
	end
	local known = legacyOf[guid]
	if known then
		return known
	end
	if match(guid, "^0[xX]%x+$") then
		return guid
	end
	local result
	local low = match(guid, "^Player%-%d+%-(%x+)$")
	if low then
		result = "0x" .. rep("0", 16 - #low) .. upper(low)
	else
		local high, entry, counter = match(guid, "^%a+%-%d+%-%d+%-%d+%-(%x%x%x%x)%-(%d+)%-(%x+)$")
		if not high then
			return guid
		end
		result = format("0x%s%06X%s", upper(high), tonumber(entry) % 0x1000000, upper(sub(counter, -6)))
	end
	legacyOf[guid] = result
	modernOf[result] = guid
	return result
end

_G.ModernUI_ModernGUID = toModern
_G.ModernUI_LegacyGUID = toLegacy

-- Functions that take a GUID accept either form.
local GetPlayerInfoByGUID_335 = _G.GetPlayerInfoByGUID
if GetPlayerInfoByGUID_335 then
	_G.GetPlayerInfoByGUID = function(guid, ...)
		return GetPlayerInfoByGUID_335(toLegacy(guid), ...)
	end
end

local function sameUnit(unit, legacy)
	return UnitExists(unit) and UnitGUID(unit) == legacy
end

local function tokenFromGUID(guid)
	local legacy = toLegacy(guid)
	if not legacy then
		return nil
	end
	for _, unit in ipairs({ "player", "target", "focus", "pet", "mouseover", "targettarget", "vehicle" }) do
		if sameUnit(unit, legacy) then
			return unit
		end
	end
	for i = 1, 4 do
		if sameUnit("party" .. i, legacy) then return "party" .. i end
		if sameUnit("partypet" .. i, legacy) then return "partypet" .. i end
	end
	for i = 1, 40 do
		if sameUnit("raid" .. i, legacy) then return "raid" .. i end
	end
	for i = 1, 5 do
		if sameUnit("boss" .. i, legacy) then return "boss" .. i end
		if sameUnit("arena" .. i, legacy) then return "arena" .. i end
	end
	local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
	for _, plate in ipairs(plates) do
		local token = plate.namePlateUnitToken
		if token and sameUnit(token, legacy) then
			return token
		end
	end
	return nil
end
_G.UnitTokenFromGUID = tokenFromGUID

local function isPlayerGUID(guid)
	local legacy = toLegacy(guid)
	return type(legacy) == "string" and match(legacy, "^0[xX]0000") ~= nil
end

_G.C_PlayerInfo = _G.C_PlayerInfo or {}
C_PlayerInfo.GUIDIsPlayer = isPlayerGUID
_G.UnitClassFromGUID = function(guid)
	local unit = tokenFromGUID(guid)
	if unit then
		return UnitClass(unit)
	end
	if isPlayerGUID(guid) and GetPlayerInfoByGUID_335 then
		local localizedClass, englishClass = GetPlayerInfoByGUID_335(toLegacy(guid))
		return localizedClass, englishClass
	end
end
_G.UnitNameFromGUID = function(guid)
	local unit = tokenFromGUID(guid)
	if unit then
		return UnitName(unit)
	end
	if isPlayerGUID(guid) and GetPlayerInfoByGUID_335 then
		return (select(6, GetPlayerInfoByGUID_335(toLegacy(guid))))
	end
end
_G.UnitPercentHealthFromGUID = function(guid)
	local unit = tokenFromGUID(guid)
	if unit then
		local max = UnitHealthMax(unit) or 0
		return max > 0 and (UnitHealth(unit) or 0) / max or 0
	end
end
_G.IsGUIDInGroup = function(guid)
	local unit = tokenFromGUID(guid)
	return unit ~= nil and (unit == "player" or UnitInParty(unit) or UnitInRaid(unit)) and true or false
end
_G.C_PartyInfo = _G.C_PartyInfo or {}
C_PartyInfo.IsGUIDInGroup = _G.IsGUIDInGroup
