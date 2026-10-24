-- ModernUI: built into the client (not in the original 3.3.5a).
-- Blizzard frames that modern clients (retail and Wrath Classic alike) know by a newer name. AddOns reach for
-- them by that name (PetActionBar, StanceBar, ScriptErrorsFrame, ...); each newer name refers to this client's
-- frame that does the same job. Frames are never replaced: a name is only set where nothing has it.

local _G = _G
local rawget, type = rawget, type

local ALIASES = {
	PetActionBar = "PetActionBarFrame",
	StanceBar = "ShapeshiftBarFrame",
	StanceBarFrame = "ShapeshiftBarFrame",
	PossessActionBar = "PossessBarFrame",
	MainActionBar = "MainMenuBar",
	PlayerCastingBarFrame = "CastingBarFrame",
	ObjectiveTrackerFrame = "WatchFrame",
	QuestWatchFrame = "WatchFrame",
	ScriptErrorsFrame = "ScriptErrors",
}

for modern, own in pairs(ALIASES) do
	local frame = rawget(_G, own)
	if rawget(_G, modern) == nil and type(frame) == "table" then
		_G[modern] = frame
	end
end

-- Methods modern code calls on those frames that this client's frames do not have.
local function nothing() end
local METHODS = {
	PetActionBar = { "ClearPetActionHighlightMarks", "Update", "UpdateCooldowns" },
	StanceBar = { "Update", "UpdateState" },
	ScriptErrorsFrame = { "DisplayMessageInternal", "OnError", "Update" },
	ObjectiveTrackerFrame = { "Update", "SetCollapsed" },
}
for name, methods in pairs(METHODS) do
	local frame = rawget(_G, name)
	if type(frame) == "table" then
		for _, method in ipairs(methods) do
			if frame[method] == nil then
				frame[method] = nothing
			end
		end
	end
end

-- A Blizzard frame of the modern interfaces that this client does not have at all (StatusTrackingBarManager,
-- BagsBar, EmbeddedItemTooltip, ...; the list is 35_ModernFrameNames.lua) is made the first time code looks
-- it up: a hidden frame of the same type, so AddOns that hide, reparent, unregister or skin it carry on. Parts
-- of it that code reaches for by name (StatusTrackingBarManager.MainStatusTrackingBarContainer) are hidden
-- frames too, and calling one does nothing. Each is noted once in Logs\LuaErrors.log.
local log = _G.ModernUI_Log or function() end
local CreateFrame = CreateFrame
local standIns = setmetatable({}, { __mode = "k" })

local function standIn(kind, name, parent)
	local ok, frame = pcall(CreateFrame, kind, name, parent or UIParent, kind == "GameTooltip" and "GameTooltipTemplate" or nil)
	if not ok or not frame then
		ok, frame = pcall(CreateFrame, "Frame", name, parent or UIParent)
		if not ok or not frame then
			return nil
		end
	end
	frame:Hide()
	local methods = getmetatable(frame).__index
	standIns[frame] = true
	setmetatable(frame, {
		__index = function(t, key)
			local method = type(methods) == "table" and methods[key]
			if method ~= nil then
				return method
			end
			if type(key) == "string" and key:find("^%u") then
				local part = standIn("Frame", nil, t)
				rawset(t, key, part)
				return part
			end
			return nil
		end,
		__call = function() end,
	})
	return frame
end
_G.ModernUI_MakeStandInFrame = standIn

if rawget(_G, "ScriptErrorsFrame") == nil then
	rawset(_G, "ScriptErrorsFrame", standIn("Frame", "ScriptErrorsFrame"))
end

local names = rawget(_G, "ModernUI_ModernFrameNames") or {}
local meta = getmetatable(_G)
if meta == nil then
	meta = {}
	setmetatable(_G, meta)
end
local previous = meta.__index
meta.__index = function(t, key)
	local kind = names[key]
	if kind then
		names[key] = nil
		local frame = standIn(kind, key)
		if frame then
			rawset(t, key, frame)
			log("ModernUI: the modern Blizzard frame " .. key .. " is not in this client; a hidden stand-in is used")
			return frame
		end
	end
	if type(previous) == "function" then
		return previous(t, key)
	elseif type(previous) == "table" then
		return previous[key]
	end
end
