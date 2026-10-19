-- ModernUI: built into the client (not in the original 3.3.5a).
-- A built-in AddOn Control Panel: an "AddOns" button on the Esc menu (and /acp, /addons) opens a
-- list of every AddOn with what ACP offers - sorting and grouping, sets, protected AddOns,
-- enabling dependencies with an AddOn, loading load-on-demand AddOns, and a UI reload.
-- Enabling and disabling apply to the current character, as the client's own functions do, and take
-- effect after a UI reload; the client saves them when the UI reloads or the character logs out.
-- The panel's own settings and sets are account-wide, in WTF\ModernUI\AddonControl.txt.

local _G = _G

-- The ACP AddOn itself provides all of this; leave the Esc menu to it when it is enabled.
do
	local name, _, _, enabled = GetAddOnInfo("ACP")
	if name and enabled then
		return
	end
end

local GetNumAddOns, GetAddOnInfo, GetAddOnMetadata = GetNumAddOns, GetAddOnInfo, GetAddOnMetadata
local IsAddOnLoaded, IsAddOnLoadOnDemand, LoadAddOn = IsAddOnLoaded, IsAddOnLoadOnDemand, LoadAddOn
local EnableAddOn, DisableAddOn, GetAddOnDependencies = EnableAddOn, DisableAddOn, GetAddOnDependencies
local format, select, type, pairs, ipairs, tostring = string.format, select, type, pairs, ipairs, tostring
local tinsert, tsort, tconcat = table.insert, table.sort, table.concat

local ROW_HEIGHT = 20
local NUM_ROWS = 20
local NUM_SETS = 10
local DATA_KEY = "AddonControl"

local function say(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AddOns|r: " .. text)
end

-- Saved settings -----------------------------------------------------------------------------------

local data = { sort = "Default", recursive = true, children = true, protected = {}, sets = {} }

local function splitList(text)
	local list = {}
	for item in (text or ""):gmatch("[^,]+") do
		list[#list + 1] = item
	end
	return list
end

local function loadData()
	local text = ModernUI_LoadData and ModernUI_LoadData(DATA_KEY)
	if not text then
		return
	end
	for line in text:gmatch("[^\r\n]+") do
		local key, value = line:match("^([^=]+)=(.*)$")
		if key == "sort" then
			data.sort = value
		elseif key == "recursive" then
			data.recursive = value == "1"
		elseif key == "children" then
			data.children = value == "1"
		elseif key == "protected" then
			for _, name in ipairs(splitList(value)) do
				data.protected[name] = true
			end
		elseif key then
			local set, field = key:match("^set%.([^%.]+)%.(%a+)$")
			if set then
				data.sets[set] = data.sets[set] or {}
				if field == "name" then
					data.sets[set].name = value
				elseif field == "addons" then
					data.sets[set].addons = splitList(value)
				end
			end
		end
	end
end

local function saveData()
	if not ModernUI_SaveData then
		return
	end
	local lines = {
		"sort=" .. data.sort,
		"recursive=" .. (data.recursive and "1" or "0"),
		"children=" .. (data.children and "1" or "0"),
	}
	local protected = {}
	for name in pairs(data.protected) do
		protected[#protected + 1] = name
	end
	tsort(protected)
	lines[#lines + 1] = "protected=" .. tconcat(protected, ",")
	for key, set in pairs(data.sets) do
		if set.name then
			lines[#lines + 1] = "set." .. key .. ".name=" .. set.name:gsub("[\r\n]", " ")
		end
		lines[#lines + 1] = "set." .. key .. ".addons=" .. tconcat(set.addons or {}, ",")
	end
	ModernUI_SaveData(DATA_KEY, tconcat(lines, "\n") .. "\n")
end

loadData()

-- AddOn helpers ----------------------------------------------------------------------------------

local BLIZZARD_ADDONS = {
	"Blizzard_AchievementUI", "Blizzard_ArenaUI", "Blizzard_AuctionUI", "Blizzard_BarbershopUI",
	"Blizzard_BattlefieldMinimap", "Blizzard_BindingUI", "Blizzard_Calendar", "Blizzard_CombatLog",
	"Blizzard_CombatText", "Blizzard_DebugTools", "Blizzard_GlyphUI", "Blizzard_GMChatUI",
	"Blizzard_GMSurveyUI", "Blizzard_GuildBankUI", "Blizzard_InspectUI", "Blizzard_ItemSocketingUI",
	"Blizzard_MacroUI", "Blizzard_RaidUI", "Blizzard_TalentUI", "Blizzard_TimeManager",
	"Blizzard_TokenUI", "Blizzard_TradeSkillUI", "Blizzard_TrainerUI",
}
local BLIZZARD_HEADER = "Blizzard AddOns"

local function plain(text)
	return (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function exists(addon)
	local name, _, _, _, _, reason = GetAddOnInfo(addon)
	return name ~= nil and reason ~= "MISSING"
end

local function reasonText(reason)
	if not reason or reason == "" then
		return nil
	end
	return _G["ADDON_" .. reason] or reason
end

-- Enables an AddOn, and (unless toggled off, or Shift/Ctrl held) the AddOns it needs and the
-- load-on-demand AddOns that need it, as ACP does.
local function enableAddon(addon, recursive, children, seen)
	seen = seen or {}
	local name = GetAddOnInfo(addon)
	if not name or seen[name] then
		return
	end
	seen[name] = true
	EnableAddOn(name)
	if recursive then
		for i = 1, select("#", GetAddOnDependencies(name)) do
			local dep = select(i, GetAddOnDependencies(name))
			if exists(dep) then
				enableAddon(dep, recursive, children, seen)
			else
				say(format("%s needs |cffff7f7f%s|r, which is not installed.", name, dep))
			end
		end
	end
	if children then
		for i = 1, GetNumAddOns() do
			if IsAddOnLoadOnDemand(i) then
				for j = 1, select("#", GetAddOnDependencies(i)) do
					if select(j, GetAddOnDependencies(i)) == name then
						enableAddon(i, recursive, false, seen)
						break
					end
				end
			end
		end
	end
end

local function enableWithModifiers(addon)
	local recursive, children = data.recursive, data.children
	if IsShiftKeyDown() then
		recursive = not recursive
	end
	if IsControlKeyDown() then
		children = not children
	end
	enableAddon(addon, recursive, children)
end

local function isProtected(addon)
	local name = GetAddOnInfo(addon)
	return name and data.protected[name] or false
end

local function disableAll()
	DisableAllAddOns()
	for name in pairs(data.protected) do
		if exists(name) then
			EnableAddOn(name)
		end
	end
end

-- The list --------------------------------------------------------------------------------------

local collapsed = { [BLIZZARD_HEADER] = true }
local lines = {}      -- what the rows show: { header = text, count = n } or { addon = index or name, child = bool }
local groups = {}     -- header text -> addon list
local sorters = { "Default", "Title", "Author", "Group", "Category" }
local sorterNames = {
	Default = "Load order", Title = "Title", Author = "Author", Group = "Group (by name)", Category = "Category",
}

local function titleOf(i)
	local name, title = GetAddOnInfo(i)
	return plain(title or name):lower()
end

local function buildLines()
	for k in pairs(lines) do
		lines[k] = nil
	end
	for k in pairs(groups) do
		groups[k] = nil
	end
	local count = GetNumAddOns()
	local order = {}
	for i = 1, count do
		order[i] = i
	end

	local function addGroup(header, members)
		groups[header] = members
		lines[#lines + 1] = { header = header, count = #members }
		if not collapsed[header] then
			for _, addon in ipairs(members) do
				lines[#lines + 1] = { addon = addon, child = true }
			end
		end
	end

	local function grouped(keyOf, fallback)
		local byKey, keys = {}, {}
		for _, i in ipairs(order) do
			local key = keyOf(i)
			if not key or key == "" then
				key = fallback
			end
			if not byKey[key] then
				byKey[key] = {}
				keys[#keys + 1] = key
			end
			tinsert(byKey[key], i)
		end
		tsort(keys, function(a, b) return a:lower() < b:lower() end)
		for _, key in ipairs(keys) do
			tsort(byKey[key], function(a, b) return titleOf(a) < titleOf(b) end)
			addGroup(key, byKey[key])
		end
	end

	local sort = data.sort
	if sort == "Title" then
		tsort(order, function(a, b) return titleOf(a) < titleOf(b) end)
		for _, i in ipairs(order) do
			lines[#lines + 1] = { addon = i }
		end
	elseif sort == "Author" then
		grouped(function(i) return plain(GetAddOnMetadata(i, "Author")) end, "Unknown")
	elseif sort == "Category" then
		grouped(function(i) return plain(GetAddOnMetadata(i, "X-Category")) end, "Uncategorised")
	elseif sort == "Group" then
		-- AddOns that share a name before "_" or "-" (DBM-Core, DBM-Party...) are grouped, along with
		-- an AddOn named exactly like the prefix; a prefix only one AddOn uses is not a group.
		local prefixOf, uses = {}, {}
		for _, i in ipairs(order) do
			local prefix = (GetAddOnInfo(i)):match("^([^_%-]+)[_%-]")
			prefixOf[i] = prefix
			if prefix then
				uses[prefix:lower()] = (uses[prefix:lower()] or 0) + 1
			end
		end
		for _, i in ipairs(order) do
			local name = GetAddOnInfo(i)
			if not prefixOf[i] and uses[name:lower()] then
				prefixOf[i] = name
				uses[name:lower()] = uses[name:lower()] + 1
			end
		end
		local function groupOf(i)
			local prefix = prefixOf[i]
			if prefix and uses[prefix:lower()] >= 2 then
				return prefix
			end
		end
		local function sortKey(i)
			local group = groupOf(i)
			return group and group:lower() or titleOf(i)
		end
		tsort(order, function(a, b)
			local ka, kb = sortKey(a), sortKey(b)
			if ka ~= kb then
				return ka < kb
			end
			return titleOf(a) < titleOf(b)
		end)
		local current
		for _, i in ipairs(order) do
			local group = groupOf(i)
			if group then
				if not current or current.key ~= group:lower() then
					current = { key = group:lower(), header = group, members = {} }
					groups[group] = current.members
					lines[#lines + 1] = current
				end
				tinsert(current.members, i)
			else
				current = nil
				lines[#lines + 1] = { addon = i }
			end
		end
		-- Fill in the counts and leave out the members of collapsed groups.
		local expanded = {}
		for _, line in ipairs(lines) do
			expanded[#expanded + 1] = line
			if line.header then
				line.count = #line.members
				if not collapsed[line.header] then
					for _, i in ipairs(line.members) do
						expanded[#expanded + 1] = { addon = i, child = true }
					end
				end
			end
		end
		for k in pairs(lines) do
			lines[k] = nil
		end
		for k, v in ipairs(expanded) do
			lines[k] = v
		end
	else
		for _, i in ipairs(order) do
			lines[#lines + 1] = { addon = i }
		end
	end

	local blizzard = {}
	for _, name in ipairs(BLIZZARD_ADDONS) do
		if exists(name) then
			blizzard[#blizzard + 1] = name
		end
	end
	if #blizzard > 0 then
		addGroup(BLIZZARD_HEADER, blizzard)
	end
end

-- Frame ------------------------------------------------------------------------------------------

local frame = CreateFrame("Frame", "AddonList", UIParent)
frame.ModernUI = true
frame:Hide()
frame:SetWidth(620)
frame:SetHeight(ROW_HEIGHT * NUM_ROWS + 150)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
tinsert(UISpecialFrames, "AddonList")

local header = frame:CreateTexture(nil, "ARTWORK")
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
header:SetWidth(360)
header:SetHeight(64)
header:SetPoint("TOP", 0, 12)
local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("TOP", header, "TOP", 0, -14)
title:SetText("AddOn Control Panel")

local close = CreateFrame("Button", "AddonListCloseButton", frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

local function button(name, text, width, onClick)
	local b = CreateFrame("Button", "AddonList" .. name, frame, "UIPanelButtonTemplate")
	b:SetWidth(width)
	b:SetHeight(22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

local function checkbox(name, text, tip, get, set)
	local c = CreateFrame("CheckButton", "AddonList" .. name, frame, "UICheckButtonTemplate")
	c:SetWidth(24)
	c:SetHeight(24)
	_G[c:GetName() .. "Text"]:SetText(text)
	_G[c:GetName() .. "Text"]:SetFontObject(GameFontHighlightSmall)
	c:SetScript("OnShow", function(self) self:SetChecked(get()) end)
	c:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
	end)
	c:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1)
		GameTooltip:AddLine(tip, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	c:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return c
end

local update
local changed = false

-- Top bar: sorting, sets, options.
local menu = CreateFrame("Frame", "AddonListMenu", frame, "UIDropDownMenuTemplate")

local sortButton = button("SortButton", "", 150, function(self)
	UIDropDownMenu_Initialize(menu, function()
		for _, key in ipairs(sorters) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = sorterNames[key]
			info.checked = data.sort == key
			info.func = function()
				data.sort = key
				saveData()
				update()
			end
			UIDropDownMenu_AddButton(info)
		end
	end, "MENU")
	ToggleDropDownMenu(1, nil, menu, self, 0, 0)
end)
sortButton:SetPoint("TOPLEFT", 20, -32)

-- The class set is keyed by class file name, read when needed (not at load, before the player exists).
local function classKey()
	return select(2, UnitClass("player")) or "CLASS"
end

local function setName(key)
	local set = data.sets[key]
	if set and set.name and set.name ~= "" then
		return set.name
	end
	if key == classKey() then
		return (UnitClass("player"))
	end
	return "Set " .. key
end

local function saveSet(key)
	local addons = {}
	for i = 1, GetNumAddOns() do
		local name, _, _, enabled = GetAddOnInfo(i)
		if enabled then
			addons[#addons + 1] = name
		end
	end
	data.sets[key] = data.sets[key] or {}
	data.sets[key].addons = addons
	saveData()
	say(format("Set [%s] saved (%d AddOns).", setName(key), #addons))
end

local function loadSet(key, clearFirst)
	local set = data.sets[key]
	if not set or not set.addons then
		return
	end
	if clearFirst then
		disableAll()
	end
	for _, name in ipairs(set.addons) do
		if exists(name) then
			enableAddon(name, data.recursive, data.children)
		end
	end
	changed = true
	say(format("Set [%s] loaded. Reload the UI to apply it.", setName(key)))
	update()
end

local function unloadSet(key)
	local set = data.sets[key]
	if not set or not set.addons then
		return
	end
	for _, name in ipairs(set.addons) do
		if exists(name) and not data.protected[name] then
			DisableAddOn(name)
		end
	end
	changed = true
	say(format("Set [%s] removed from the selection.", setName(key)))
	update()
end

StaticPopupDialogs["MODERNUI_ADDONS_RELOAD"] = {
	text = "Reload your User Interface?",
	button1 = ACCEPT, button2 = CANCEL,
	OnAccept = function() ReloadUI() end,
	timeout = 0, hideOnEscape = 1, whileDead = 1, exclusive = 1,
}
StaticPopupDialogs["MODERNUI_ADDONS_SAVESET"] = {
	text = "Save the current AddOn list to [%s]?",
	button1 = YES, button2 = CANCEL,
	OnAccept = function(self) saveSet(self.data) end,
	timeout = 0, hideOnEscape = 1, whileDead = 1, exclusive = 1,
}
local function renameAccept(popup)
	local box = _G[popup:GetName() .. "EditBox"]
	local text = box and box:GetText() or ""
	local key = popup.data
	data.sets[key] = data.sets[key] or {}
	data.sets[key].name = text ~= "" and text:gsub(",", " ") or nil
	saveData()
end
StaticPopupDialogs["MODERNUI_ADDONS_RENAMESET"] = {
	text = "Enter the new name for [%s]:",
	button1 = ACCEPT, button2 = CANCEL,
	hasEditBox = 1,
	OnAccept = renameAccept,
	EditBoxOnEnterPressed = function(self)
		local popup = self:GetParent()
		renameAccept(popup)
		popup:Hide()
	end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	timeout = 0, hideOnEscape = 1, whileDead = 1, exclusive = 1,
}

local setsButton = button("SetsButton", "Sets", 80, function(self)
	UIDropDownMenu_Initialize(menu, function(_, level)
		level = level or 1
		if level == 1 then
			local keys = {}
			for i = 1, NUM_SETS do
				keys[#keys + 1] = tostring(i)
			end
			keys[#keys + 1] = classKey() -- one set per class, shared by that class's characters
			for _, key in ipairs(keys) do
				local set = data.sets[key]
				local info = UIDropDownMenu_CreateInfo()
				info.text = format("%s (%d)", setName(key), set and set.addons and #set.addons or 0)
				info.value = key
				info.hasArrow = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)
			end
		else
			local key = UIDROPDOWNMENU_MENU_VALUE
			local function add(text, fn, isTitle)
				local info = UIDropDownMenu_CreateInfo()
				info.text = text
				info.notCheckable = 1
				info.isTitle = isTitle
				info.func = fn
				UIDropDownMenu_AddButton(info, level)
			end
			add(setName(key), nil, 1)
			add("Save", function()
				StaticPopup_Show("MODERNUI_ADDONS_SAVESET", setName(key), nil, key)
				CloseDropDownMenus()
			end)
			add("Load", function() loadSet(key, true) CloseDropDownMenus() end)
			add("Add to current selection", function() loadSet(key, false) CloseDropDownMenus() end)
			add("Remove from current selection", function() unloadSet(key) CloseDropDownMenus() end)
			if key ~= classKey() then
				add("Rename", function()
					StaticPopup_Show("MODERNUI_ADDONS_RENAMESET", setName(key), nil, key)
					CloseDropDownMenus()
				end)
			end
		end
	end, "MENU")
	ToggleDropDownMenu(1, nil, menu, self, 0, 0)
end)
setsButton:SetPoint("LEFT", sortButton, "RIGHT", 6, 0)

local collapseAll = button("CollapseAllButton", "Collapse All", 100, function(self)
	local anyOpen = false
	for headerText in pairs(groups) do
		if not collapsed[headerText] then
			anyOpen = true
		end
	end
	for headerText in pairs(groups) do
		collapsed[headerText] = anyOpen
	end
	update()
end)
collapseAll:SetPoint("LEFT", setsButton, "RIGHT", 6, 0)

local recursiveCheck = checkbox("RecursiveCheck", "Recursive",
	"Enabling an AddOn also enables the AddOns it needs. Hold Shift while clicking to do the opposite.",
	function() return data.recursive end,
	function(v) data.recursive = v saveData() end)
recursiveCheck:SetPoint("LEFT", collapseAll, "RIGHT", 8, 0)

local childrenCheck = checkbox("ChildrenCheck", "LoD children",
	"Enabling an AddOn also enables the load-on-demand AddOns that need it. Hold Ctrl while clicking to do the opposite.",
	function() return data.children end,
	function(v) data.children = v saveData() end)
childrenCheck:SetPoint("LEFT", recursiveCheck, "RIGHT", 70, 0)

local outdatedCheck = checkbox("OutOfDateCheck", "Load out of date AddOns",
	"Load AddOns whose interface version does not match this client's.",
	function() return GetCVar("checkAddonVersion") == "0" end,
	function(v) SetCVar("checkAddonVersion", v and "0" or "1") changed = true update() end)
outdatedCheck:SetPoint("TOPLEFT", sortButton, "BOTTOMLEFT", 0, -2)

local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
hint:SetPoint("LEFT", _G[outdatedCheck:GetName() .. "Text"], "RIGHT", 16, 0)
hint:SetText("Changes apply to this character after a UI reload.")

-- Rows.
local scroll = CreateFrame("ScrollFrame", "AddonListScrollFrame", frame, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 20, -84)
scroll:SetPoint("BOTTOMRIGHT", -40, 50)

local rows = {}

local function addonStatus(addon)
	local name, _, _, enabled, loadable, reason = GetAddOnInfo(addon)
	local loaded = IsAddOnLoaded(addon)
	if loaded then
		if enabled then
			return "Loaded", 0.4, 1, 0.4
		end
		return "Disabled after reload", 1, 0.5, 0.25
	elseif enabled and loadable and IsAddOnLoadOnDemand(addon) then
		return "Load on demand", 1, 0.82, 0
	elseif enabled and loadable then
		return "Loads after reload", 1, 0.82, 0
	elseif enabled then
		return reasonText(reason) or ADDON_UNKNOWN_ERROR or "Not loadable", 1, 0.3, 0.3
	end
	return ADDON_DISABLED or "Disabled", 0.5, 0.5, 0.5
end

local function rowTooltip(row)
	local line = row.line
	if not line or not line.addon then
		return
	end
	local addon = line.addon
	local name, addonTitle, notes = GetAddOnInfo(addon)
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(addonTitle or name, 1, 0.82, 0)
	local version = GetAddOnMetadata(addon, "Version")
	local author = GetAddOnMetadata(addon, "Author")
	if author and author ~= "" then
		GameTooltip:AddDoubleLine("Author", plain(author), 1, 1, 0.5, 1, 1, 1)
	end
	if version and version ~= "" then
		GameTooltip:AddDoubleLine("Version", plain(version), 1, 1, 0.5, 1, 1, 1)
	end
	local status, r, g, b = addonStatus(addon)
	GameTooltip:AddDoubleLine("Status", status, 1, 1, 0.5, r, g, b)
	if plain(addonTitle) ~= name then
		GameTooltip:AddDoubleLine("Folder", name, 1, 1, 0.5, 0.7, 0.7, 0.7)
	end
	local deps = {}
	for i = 1, select("#", GetAddOnDependencies(addon)) do
		local dep = select(i, GetAddOnDependencies(addon))
		if IsAddOnLoaded(dep) then
			deps[#deps + 1] = "|cff80ff80" .. dep .. "|r"
		elseif exists(dep) then
			deps[#deps + 1] = "|cffffd100" .. dep .. "|r"
		else
			deps[#deps + 1] = "|cffff4040" .. dep .. "|r"
		end
	end
	if #deps > 0 then
		GameTooltip:AddLine("Dependencies: " .. tconcat(deps, ", "), 1, 1, 0.5, true)
	end
	if IsAddOnLoaded(addon) and UpdateAddOnMemoryUsage and type(addon) == "number" then
		UpdateAddOnMemoryUsage()
		local kb = GetAddOnMemoryUsage(addon) or 0
		local text = kb > 1024 and format("%.2f MB", kb / 1024) or format("%.0f KB", kb)
		GameTooltip:AddDoubleLine("Memory Usage", text, 1, 1, 0.5, 1, 1, 1)
	end
	if notes and notes ~= "" then
		GameTooltip:AddLine(notes, 1, 1, 1, true)
	end
	if type(addon) == "number" then
		GameTooltip:AddLine("Click the lock to protect this AddOn: protected AddOns stay enabled through Disable All and sets.", 0.6, 0.6, 0.6, true)
	end
	GameTooltip:Show()
end

local function setIcon(texture, index)
	texture:SetTexCoord((index - 1) * 0.25, index * 0.25, 0, 1)
end

update = function()
	buildLines()
	local offset = FauxScrollFrame_GetOffset(scroll)
	for i = 1, NUM_ROWS do
		local row = rows[i]
		local line = lines[offset + i]
		row.line = line
		if not line then
			row:Hide()
		elseif line.header then
			row.collapse:Show()
			row.collapse:SetNormalTexture(collapsed[line.header] and "Interface\\Minimap\\UI-Minimap-ZoomInButton-Up" or "Interface\\Minimap\\UI-Minimap-ZoomOutButton-Up")
			row.check:Hide()
			row.lock:Hide()
			row.load:Hide()
			row.status:SetText("")
			row.title:ClearAllPoints()
			row.title:SetPoint("LEFT", row.collapse, "RIGHT", 4, 0)
			row.title:SetText(format("%s  |cffffffff(%d)|r", line.header, line.count or 0))
			row.title:SetTextColor(1, 1, 1)
			row:Show()
		else
			local addon = line.addon
			local name, addonTitle, _, enabled, loadable = GetAddOnInfo(addon)
			local blizzard = type(addon) == "string"
			local indent = line.child and 18 or 0
			row.collapse:Hide()
			row.lock:ClearAllPoints()
			row.lock:SetPoint("LEFT", indent, 0)
			row.check:ClearAllPoints()
			row.check:SetPoint("LEFT", row.lock, "RIGHT", 0, 0)
			if blizzard then
				row.lock:Hide()
				row.check:Hide()
			else
				row.lock:Show()
				setIcon(row.lockIcon, isProtected(addon) and 4 or 1)
				row.lockIcon:SetAlpha(isProtected(addon) and 1 or 0.25)
				if isProtected(addon) then
					row.check:Hide()
				else
					row.check:Show()
				end
				row.check:SetChecked(enabled)
			end
			row.title:ClearAllPoints()
			row.title:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
			row.title:SetText(plain(addonTitle or name))
			if loadable or IsAddOnLoaded(addon) then
				row.title:SetTextColor(1, 0.82, 0)
			elseif enabled then
				row.title:SetTextColor(1, 0.3, 0.3)
			else
				row.title:SetTextColor(0.5, 0.5, 0.5)
			end
			local status, r, g, b = addonStatus(addon)
			row.status:SetText(status)
			row.status:SetTextColor(r, g, b)
			if enabled and loadable and IsAddOnLoadOnDemand(addon) and not IsAddOnLoaded(addon) then
				row.load:Show()
				row.status:SetPoint("RIGHT", row.load, "LEFT", -6, 0)
			else
				row.load:Hide()
				row.status:SetPoint("RIGHT", row, "RIGHT", -4, 0)
			end
			row:Show()
		end
	end
	FauxScrollFrame_Update(scroll, #lines, NUM_ROWS, ROW_HEIGHT)
	sortButton:SetText("Sort: " .. (sorterNames[data.sort] or data.sort))
	if next(groups) ~= nil then
		collapseAll:Enable()
	else
		collapseAll:Disable()
	end
	_G.AddonListReloadButton:SetText(changed and "Reload UI *" or (RELOADUI or "Reload UI"))
end
frame.Update = function() update() end

for i = 1, NUM_ROWS do
	local row = CreateFrame("Button", "AddonListEntry" .. i, frame)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
	row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	row:RegisterForClicks("LeftButtonUp")

	local collapse = CreateFrame("Button", "$parentCollapse", row)
	collapse:SetWidth(16)
	collapse:SetHeight(16)
	collapse:SetPoint("LEFT", 2, 0)
	collapse:SetScript("OnClick", function()
		local line = row.line
		if line and line.header then
			collapsed[line.header] = not collapsed[line.header]
			update()
		end
	end)
	row.collapse = collapse

	local lock = CreateFrame("Button", "$parentLock", row)
	lock:SetWidth(16)
	lock:SetHeight(16)
	local lockIcon = lock:CreateTexture(nil, "ARTWORK")
	lockIcon:SetAllPoints()
	lockIcon:SetTexture("Interface\\Glues\\CharacterSelect\\Glues-AddOn-Icons")
	lock:SetScript("OnClick", function()
		local line = row.line
		if line and type(line.addon) == "number" then
			local name = GetAddOnInfo(line.addon)
			if data.protected[name] then
				data.protected[name] = nil
			else
				data.protected[name] = true
				enableAddon(name, data.recursive, false)
			end
			saveData()
			update()
		end
	end)
	lock:SetScript("OnEnter", function() rowTooltip(row) end)
	lock:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row.lock, row.lockIcon = lock, lockIcon

	local check = CreateFrame("CheckButton", "$parentEnabled", row, "UICheckButtonTemplate")
	check:SetWidth(22)
	check:SetHeight(22)
	check:SetScript("OnClick", function(self)
		local line = row.line
		if not line or not line.addon then
			return
		end
		if self:GetChecked() then
			PlaySound("igMainMenuOptionCheckBoxOn")
			enableWithModifiers(line.addon)
		else
			PlaySound("igMainMenuOptionCheckBoxOff")
			DisableAddOn(line.addon)
		end
		changed = true
		update()
	end)
	check:SetScript("OnEnter", function() rowTooltip(row) end)
	check:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row.check = check

	local load = CreateFrame("Button", "$parentLoad", row, "UIPanelButtonTemplate")
	load:SetWidth(50)
	load:SetHeight(18)
	load:SetPoint("RIGHT", -2, 0)
	load:SetText("Load")
	load:SetScript("OnClick", function()
		local line = row.line
		if not line or not line.addon then
			return
		end
		local ok, reason = LoadAddOn(line.addon)
		if not ok and reason then
			say(format(ADDON_LOAD_FAILED or "Couldn't load %s: %s", tostring(GetAddOnInfo(line.addon)), reasonText(reason) or reason))
		end
		update()
	end)
	row.load = load

	row.title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	row.title:SetJustifyH("LEFT")
	row.title:SetWidth(300)
	row.title:SetHeight(ROW_HEIGHT)

	row.status = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.status:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.status:SetJustifyH("RIGHT")

	row:SetScript("OnClick", function()
		local line = row.line
		if not line then
			return
		end
		if line.header then
			collapse:Click()
		elseif check:IsShown() then
			check:Click()
		end
	end)
	row:SetScript("OnEnter", rowTooltip)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	rows[i] = row
end

scroll:SetScript("OnVerticalScroll", function(self, offset)
	FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, update)
end)

-- Bottom bar.
local disableButton = button("DisableAllButton", "Disable All", 110, function()
	disableAll()
	changed = true
	update()
end)
disableButton:SetPoint("BOTTOMLEFT", 18, 18)

local enableButton = button("EnableAllButton", "Enable All", 110, function()
	EnableAllAddOns()
	changed = true
	update()
end)
enableButton:SetPoint("LEFT", disableButton, "RIGHT", 6, 0)

local closeButton = button("CloseButton2", CLOSE or "Close", 100, function()
	frame:Hide()
end)
closeButton:SetPoint("BOTTOMRIGHT", -18, 18)

local reloadButton = button("ReloadButton", RELOADUI or "Reload UI", 110, function()
	StaticPopup_Show("MODERNUI_ADDONS_RELOAD")
end)
reloadButton:SetPoint("RIGHT", closeButton, "LEFT", -6, 0)

frame:SetScript("OnShow", function()
	PlaySound("igMainMenuOpen")
	update()
end)
frame:SetScript("OnHide", function()
	PlaySound("igMainMenuClose")
	CloseDropDownMenus()
end)

-- Protected AddOns stay enabled: make sure they are, once the UI has loaded.
do
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("PLAYER_LOGIN")
	watcher:SetScript("OnEvent", function(self)
		self:UnregisterAllEvents()
		local missing = false
		for name in pairs(data.protected) do
			if exists(name) then
				local _, _, _, enabled = GetAddOnInfo(name)
				if not enabled then
					EnableAddOn(name)
				end
				if not IsAddOnLoaded(name) and not IsAddOnLoadOnDemand(name) then
					missing = true
				end
			end
		end
		if missing then
			say("Some protected AddOns are not loaded. Open the AddOn list and reload the UI to load them.")
		end
	end)
end

-- Esc menu button --------------------------------------------------------------------------------

local gameMenu, macros = _G.GameMenuFrame, _G.GameMenuButtonMacros
if gameMenu and macros and not _G.GameMenuButtonAddOns then
	local addons = CreateFrame("Button", "GameMenuButtonAddOns", gameMenu, "GameMenuButtonTemplate")
	addons:SetText(ADDONS or "AddOns")
	addons:SetPoint("TOP", macros, "BOTTOM", 0, -1)
	addons:SetScript("OnClick", function()
		PlaySound("igMainMenuOption")
		HideUIPanel(gameMenu)
		frame:Show()
	end)

	-- Everything that hung below Macros now hangs below AddOns.
	local function reanchor()
		for _, name in ipairs({ "GameMenuButtonRatings", "GameMenuButtonLogout" }) do
			local b = _G[name]
			if b then
				local point, relativeTo, relativePoint, x, y = b:GetPoint(1)
				if relativeTo == macros then
					b:ClearAllPoints()
					b:SetPoint(point, addons, relativePoint, x, y)
				end
			end
		end
	end
	reanchor()
	gameMenu:SetHeight(gameMenu:GetHeight() + (addons:GetHeight() > 0 and addons:GetHeight() or 21) + 1)
	gameMenu:HookScript("OnShow", reanchor)
end

-- Slash commands, as ACP's.
SLASH_MODERNUI_ADDONS1 = "/acp"
SLASH_MODERNUI_ADDONS2 = "/addons"
SlashCmdList.MODERNUI_ADDONS = function()
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
	end
end
