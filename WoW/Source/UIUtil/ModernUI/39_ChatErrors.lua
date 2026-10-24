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

-- Errors AddOns catch with pcall and then report without their cause (Questie's database compiler, for one):
-- the first time each such error message is seen it is written to the log too.
do
	local pcall_global = pcall
	local logged, count = {}, 0
	local function note(ok, ...)
		if not ok and count < 200 then
			local message = tostring((...))
			if not logged[message] then
				logged[message] = true
				count = count + 1
				ModernUI_Log("caught: " .. message)
			end
		end
		return ok, ...
	end
	pcall = function(f, ...)
		return note(pcall_global(f, ...))
	end
end

-- What this client says about the player while AddOns load, for checking against what they expect.
do
	local reported
	local reporter = CreateFrame("Frame")
	reporter:RegisterEvent("ADDON_LOADED")
	reporter:SetScript("OnEvent", function(self)
		if reported then
			return
		end
		reported = true
		self:UnregisterAllEvents()
		local name, token, id = UnitClass("player")
		local count = 0
		for _ in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do count = count + 1 end
		ModernUI_Log(("ModernUI player at load: UnitClass=%s/%s/%s UnitClassBase=%s classNames=%d race=%s guid=%s"):format(
			tostring(name), tostring(token), tostring(id), tostring(UnitClassBase and UnitClassBase("player")), count,
			tostring(select(2, UnitRace("player"))), tostring(UnitGUID("player"))))
	end)
end
