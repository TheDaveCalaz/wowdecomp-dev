-- ModernUI: built into the client (not in the original 3.3.5a).
-- AddOns that catch their own errors often report them only in the chat window, where long lines are cut
-- off. Chat lines that report an error are also written to Logs\LuaErrors.log, in full.

if not ModernUI_Log then
	return
end

local lower, find = string.lower, string.find
local seen = {}
local function watch(frame)
	if not frame or not frame.AddMessage or seen[frame] then
		return
	end
	seen[frame] = true
	hooksecurefunc(frame, "AddMessage", function(_, text)
		if type(text) == "string" then
			local l = lower(text)
			if find(l, "error", 1, true) or find(l, "failed", 1, true) then
				ModernUI_Log("chat: " .. text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
			end
		end
	end)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_LOGIN")
local function watchAll()
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		watch(_G["ChatFrame" .. i])
	end
	watch(DEFAULT_CHAT_FRAME)
end
watcher:SetScript("OnEvent", watchAll)
watchAll()
