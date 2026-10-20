-- ModernUI: built into the client (not in the original 3.3.5a).
-- /fstack (as on modern clients): a tooltip listing every shown frame under the mouse, top first, with its
-- name or, for unnamed frames, the path from the nearest named parent. /fstack again turns it off.

if SlashCmdList.FRAMESTACK then
	return
end

local function describe(frame)
	local name = frame:GetName()
	if name and not name:find("^ModernUIFrame") then
		return name
	end
	local parent = frame:GetParent()
	if parent then
		for key, value in pairs(parent) do
			if value == frame and type(key) == "string" then
				return describe(parent) .. "." .. key
			end
		end
		return describe(parent) .. ".<unnamed " .. frame:GetObjectType() .. ">"
	end
	return "<unnamed " .. frame:GetObjectType() .. ">"
end

local tooltip = CreateFrame("GameTooltip", "ModernUIFrameStackTooltip", UIParent, "GameTooltipTemplate")
local watcher = CreateFrame("Frame")
local elapsedSince = 0
watcher:Hide()
watcher:SetScript("OnUpdate", function(_, elapsed)
	elapsedSince = elapsedSince + elapsed
	if elapsedSince < 0.2 then
		return
	end
	elapsedSince = 0
	local list = {}
	local frame = EnumerateFrames()
	while frame do
		if frame ~= tooltip and frame:IsVisible() and frame:IsMouseOver() then
			list[#list + 1] = frame
		end
		frame = EnumerateFrames(frame)
	end
	local strata = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
	table.sort(list, function(a, b)
		local sa, sb = strata[a:GetFrameStrata()] or 0, strata[b:GetFrameStrata()] or 0
		if sa ~= sb then
			return sa > sb
		end
		return a:GetFrameLevel() > b:GetFrameLevel()
	end)
	tooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
	tooltip:AddLine("Frames under the mouse", 1, 0.82, 0)
	for i = 1, math.min(#list, 30) do
		local f = list[i]
		tooltip:AddDoubleLine(describe(f), ("%s %d"):format(f:GetFrameStrata(), f:GetFrameLevel()), 1, 1, 1, 0.6, 0.6, 0.6)
	end
	local focus = GetMouseFocus()
	if focus then
		tooltip:AddLine("Mouse focus: " .. describe(focus), 0.5, 1, 0.5)
	end
	tooltip:Show()
end)

SLASH_FRAMESTACK1 = "/fstack"
SLASH_FRAMESTACK2 = "/framestack"
SlashCmdList.FRAMESTACK = function()
	if watcher:IsShown() then
		watcher:Hide()
		tooltip:Hide()
	else
		watcher:Show()
	end
end
