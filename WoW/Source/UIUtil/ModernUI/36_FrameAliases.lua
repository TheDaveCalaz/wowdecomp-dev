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
