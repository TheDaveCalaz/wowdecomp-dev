-- ModernUI: built into the client (not in the original 3.3.5a).
-- Temporary diagnostics, written to Logs\LuaErrors.log: where the player's GUID stands while AddOns load
-- (several AddOns read UnitGUID("player") then and find nothing).

if not (ModernUI_Log and ModernUI_DebugPlayerGUID) then
	return
end

local function report(stage)
	local login, active, exists = ModernUI_DebugPlayerGUID()
	ModernUI_Log(("ModernUI diagnostic (%s): UnitGUID(\"player\")=%s login=%s active=%s playerObject=%s"):format(
		stage, tostring(UnitGUID("player")), tostring(login), tostring(active), tostring(exists)))
end

report("ModernUI loaded")
local first = true
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" then
		if first then
			first = false
			report("first ADDON_LOADED: " .. tostring(name))
		end
		return
	end
	report(event)
	self:UnregisterEvent(event)
end)
