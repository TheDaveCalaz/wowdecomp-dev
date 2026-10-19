-- ModernUI: built into the client (not in the original 3.3.5a).
-- Advanced Interface Options: the settings this client has as CVars but no option for, on pages in
-- Interface Options, plus a browser for every CVar. Changes apply at once; Cancel puts back the values
-- the pages had when Interface Options opened, and Defaults restores the page's defaults.
-- /aio opens it, as the AddOn of that name does.

local _G = _G

-- The AddOn itself provides this; leave Interface Options to it when it is enabled.
do
	local name, _, _, enabled = GetAddOnInfo("AdvancedInterfaceOptions")
	if name and enabled then
		return
	end
end

local GetCVar, SetCVar, GetCVarInfo, GetCVarDefault = GetCVar, SetCVar, GetCVarInfo, GetCVarDefault
local format, type, pairs, ipairs, tonumber, tostring = string.format, type, pairs, ipairs, tonumber, tostring
local tinsert, tsort = table.insert, table.sort

local CATEGORY = "Advanced Interface Options"

local function cvarExists(cvar)
	return GetCVarInfo(cvar) ~= nil
end

local function safeSet(cvar, value)
	local ok, err = pcall(SetCVar, cvar, tostring(value))
	if not ok then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Advanced Options|r: could not set " .. cvar .. ": " .. tostring(err))
	end
end

-- The settings ------------------------------------------------------------------------------------
-- check: on/off (invert when the CVar's 1 means the option is off).
-- slider: min, max, step; fmt shows the value.  choice: values = { { value, text }, ... }.

local PAGES = {
	{
		name = CATEGORY,
		title = CATEGORY,
		text = "Settings this client has but the standard options do not show. Changes apply at once.",
		controls = {
			{ "check", "scriptErrors", "Display Lua errors", "Show a message when an interface script fails." },
			{ "check", "alwaysCompareItems", "Always compare items", "Show the comparison tooltip without holding Shift." },
			{ "check", "dontShowEquipmentSetsOnItems", "Hide equipment sets on item tooltips", "Do not list the equipment sets an item belongs to in its tooltip." },
			{ "check", "showQuestTrackingTooltips", "Quest progress in unit tooltips", "Show your quest objectives for a creature in its tooltip." },
			{ "check", "questPOI", "Quest areas on the maps", "Show quest objective areas and markers on the world map and minimap." },
			{ "check", "ShowAllSpellRanks", "Show all spell ranks", "Show every rank of each spell in the spellbook." },
			{ "check", "showKeyring", "Show the keyring", "Show the keyring button next to the bags." },
			{ "check", "predictedHealth", "Smooth health bars", "Update health bars before the server confirms the change." },
			{ "check", "predictedPower", "Smooth power bars", "Update mana, rage and energy bars before the server confirms the change." },
			{ "check", "screenEdgeFlash", "Flash the screen edges at low health", "Flash the edges of the screen red when your health is low." },
			{ "check", "colorChatNamesByClass", "Class-coloured names in chat", "Colour player names in chat by their class." },
			{ "check", "enableWowMouse", "WoW mouse", "Enable the extra buttons of the World of Warcraft gaming mouse." },
			{ "check", "showLootSpam", "Show other players' loot rolls", "Show every loot roll in chat." },
			{ "check", "checkAddonVersion", "Load out of date AddOns", "Load AddOns whose interface version does not match this client's.", invert = true },
			{ "choice", "taintLog", "Taint log", "Write a log of blocked interface actions to Logs\\taint.log.",
				values = { { "0", "Off" }, { "1", "Basic" }, { "2", "Full" } } },
			{ "slider", "maxFPS", "Frame rate limit", "The highest frame rate (0 = no limit).", 0, 300, 5 },
			{ "slider", "maxFPSBk", "Background frame rate limit", "The highest frame rate while the game is in the background (0 = no limit).", 0, 300, 5 },
			{ "choice", "screenshotFormat", "Screenshot format", "The file format of screenshots.",
				values = { { "jpeg", "JPEG" }, { "tga", "TGA" } } },
			{ "slider", "screenshotQuality", "Screenshot quality", "The quality of JPEG screenshots.", 1, 10, 1 },
		},
	},
	{
		name = "Camera",
		title = "Camera",
		text = "Camera settings beyond the standard options.",
		controls = {
			{ "slider", "cameraDistanceMaxFactor", "Maximum zoom distance", "How far the camera can zoom out, as a multiple of the normal maximum.", 1, 4, 0.1, fmt = "%.1fx" },
			{ "slider", "cameraDistanceMoveSpeed", "Zoom speed", "How fast the mouse wheel zooms the camera.", 1, 50, 1 },
			{ "slider", "cameraYawMoveSpeed", "Turn speed", "How fast the camera turns left and right with the mouse.", 30, 360, 5 },
			{ "slider", "cameraPitchMoveSpeed", "Pitch speed", "How fast the camera moves up and down with the mouse.", 30, 360, 5 },
			{ "slider", "cameraDistanceSmoothSpeed", "Zoom smoothing", "How quickly the camera settles at a new zoom distance.", 1, 50, 1 },
			{ "check", "cameraDive", "Camera dives with you", "Tilt the camera to follow you when you dive in water or fly down." },
			{ "check", "cameraHeightIgnoreStandState", "Keep the camera height when sitting", "Do not lower the camera when your character sits or kneels." },
			{ "check", "cameraSmoothPitch", "Smooth pitch", "Smooth the camera's up and down movement when it follows you." },
			{ "check", "cameraSmoothYaw", "Smooth turning", "Smooth the camera's left and right movement when it follows you." },
		},
	},
	{
		name = "Combat",
		title = "Combat",
		text = "Combat behaviour and combat text.",
		controls = {
			{ "check", "secureAbilityToggle", "Protect toggled abilities", "Do not switch off an ability like a stance or aura by pressing it twice in a row." },
			{ "check", "stopAutoAttackOnTargetChange", "Stop attacking on target change", "Stop auto-attack when you change target." },
			{ "check", "autoDismount", "Dismount to cast", "Dismount when you cast a spell on the ground." },
			{ "check", "autoStand", "Stand to cast", "Stand up when you cast a spell while sitting." },
			{ "check", "autoUnshift", "Leave forms to cast", "Leave shapeshift forms when you cast a spell that needs it." },
			{ "check", "PetSpellDamage", "Pet spell damage", "Show your pet's spell damage in the floating combat text on targets." },
			{ "check", "CombatLogPeriodicSpells", "Periodic damage", "Show damage over time in the floating combat text on targets." },
			{ "check", "fctAllSpellMechanics", "All spell mechanics", "Show every spell mechanic (stuns, roots...) in combat text." },
			{ "check", "threatWorldText", "Threat in combat text", "Show threat warnings as combat text." },
		},
	},
	{
		name = "Graphics",
		title = "Graphics",
		text = "Graphics settings beyond the standard video options.",
		controls = {
			{ "slider", "farclip", "View distance", "The far clip distance in yards.", 177, 1277, 10 },
			{ "slider", "horizonFarclipScale", "Horizon distance", "How far the horizon reaches, as a multiple of the view distance.", 3, 6, 0.5, fmt = "%.1fx" },
			{ "slider", "groundEffectDensity", "Ground clutter density", "How thickly grass and small plants are drawn.", 16, 256, 8 },
			{ "slider", "groundEffectDist", "Ground clutter distance", "How far away grass and small plants are drawn.", 0, 140, 5 },
			{ "slider", "weatherDensity", "Weather density", "How much rain and snow is drawn.", 0, 3, 1 },
			{ "check", "ffxGlow", "Full-screen glow", "The soft glow over the whole screen." },
			{ "check", "ffxDeath", "Death effect", "The grey screen effect when you are dead." },
			{ "check", "ffxNetherWorld", "Nether world effect", "The screen effect of spells that move you into the nether (Invisibility, Fade)." },
			{ "check", "useWeatherShaders", "Weather shaders", "Use shaders for weather effects." },
			{ "check", "showfootprints", "Footprints", "Leave footprints on the ground." },
			{ "check", "showfootprintparticles", "Footprint dust", "Kick up dust when walking." },
		},
	},
	{
		name = "Sound",
		title = "Sound",
		text = "Sound settings beyond the standard sound options.",
		controls = {
			{ "check", "Sound_EnableErrorSpeech", "Error speech", "Your character says when something cannot be done." },
			{ "check", "Sound_EnableEmoteSounds", "Emote sounds", "Play the voice sounds of emotes." },
			{ "check", "Sound_EnablePetSounds", "Pet sounds", "Play your pets' sounds." },
			{ "check", "Sound_ZoneMusicNoDelay", "Loop music without gaps", "Play zone music continuously instead of with pauses." },
			{ "check", "Sound_EnableArmorFoleySoundForSelf", "Your armour sounds", "Play the sound of your own armour as you move." },
			{ "check", "Sound_EnableArmorFoleySoundForOthers", "Other players' armour sounds", "Play the sound of other players' armour as they move." },
			{ "check", "FootstepSounds", "Footstep sounds", "Play footstep sounds." },
			{ "slider", "Sound_NumChannels", "Sound channels", "How many sounds can play at once.", 12, 64, 4 },
		},
	},
}

-- Panels ------------------------------------------------------------------------------------------

local snapshot = {}   -- CVar -> value when Interface Options opened (for Cancel)
local panels = {}

local function remember(cvar)
	if snapshot[cvar] == nil then
		snapshot[cvar] = GetCVar(cvar)
	end
end

local function setValue(cvar, value)
	remember(cvar)
	safeSet(cvar, value)
end

local function trim(value, step)
	if step >= 1 then
		return math.floor(value / step + 0.5) * step
	end
	return tonumber(format("%.2f", math.floor(value / step + 0.5) * step))
end

local function tooltip(widget, title, text, cvar)
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		GameTooltip:AddLine(text, nil, nil, nil, true)
		local default = GetCVarDefault(cvar)
		GameTooltip:AddLine(format("CVar: %s   Default: %s", cvar, tostring(default)), 0.5, 0.5, 0.5)
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function makePanel(page, index)
	local panel = CreateFrame("Frame", "ModernUIAdvancedOptions" .. index, UIParent)
	panel:Hide()
	panel.name = page.name
	if index > 1 then
		panel.parent = CATEGORY
	end
	panel.controls = {}

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(page.title)
	local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	sub:SetPoint("RIGHT", -32, 0)
	sub:SetJustifyH("LEFT")
	sub:SetText(page.text)

	-- Checkboxes in two columns, then sliders and choices in two columns.
	local checks, others = {}, {}
	for _, c in ipairs(page.controls) do
		if cvarExists(c[2]) then
			if c[1] == "check" then
				checks[#checks + 1] = c
			else
				others[#others + 1] = c
			end
		end
	end

	local top = -60
	for i, c in ipairs(checks) do
		local _, cvar, label, tip = c[1], c[2], c[3], c[4]
		local column = (i - 1) % 2
		local rowIndex = math.floor((i - 1) / 2)
		local check = CreateFrame("CheckButton", panel:GetName() .. "Check" .. i, panel, "OptionsCheckButtonTemplate")
		check:SetPoint("TOPLEFT", 16 + column * 200, top - rowIndex * 26)
		local text = _G[check:GetName() .. "Text"]
		text:SetText(label)
		text:SetFontObject(GameFontHighlight)
		text:SetWidth(165)
		text:SetJustifyH("LEFT")
		check:SetHitRectInsets(0, -165, 0, 0)
		check.refresh = function()
			local on = GetCVar(cvar) == "1"
			if c.invert then
				on = not on
			end
			check:SetChecked(on)
		end
		check:SetScript("OnClick", function(self)
			local on = self:GetChecked() and true or false
			PlaySound(on and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
			if c.invert then
				on = not on
			end
			setValue(cvar, on and "1" or "0")
		end)
		tooltip(check, label, tip, cvar)
		check.cvar = cvar
		panel.controls[#panel.controls + 1] = check
	end
	top = top - math.ceil(#checks / 2) * 26 - 20

	for i, c in ipairs(others) do
		local kind, cvar, label, tip = c[1], c[2], c[3], c[4]
		local column = (i - 1) % 2
		local rowIndex = math.floor((i - 1) / 2)
		local x, y = 24 + column * 200, top - rowIndex * 56
		if kind == "slider" then
			local minValue, maxValue, step = c[5], c[6], c[7]
			local slider = CreateFrame("Slider", panel:GetName() .. "Slider" .. i, panel, "OptionsSliderTemplate")
			slider:SetWidth(170)
			slider:SetPoint("TOPLEFT", x, y - 14)
			slider:SetMinMaxValues(minValue, maxValue)
			slider:SetValueStep(step)
			local name = slider:GetName()
			_G[name .. "Low"]:SetText(tostring(minValue))
			_G[name .. "High"]:SetText(tostring(maxValue))
			local function label_(value)
				_G[name .. "Text"]:SetText(format("%s: |cffffffff" .. (c.fmt or "%s") .. "|r", label, c.fmt and value or tostring(value)))
			end
			slider.refresh = function()
				local value = tonumber(GetCVar(cvar)) or minValue
				slider.updating = true
				slider:SetValue(math.max(minValue, math.min(maxValue, value)))
				slider.updating = false
				label_(value)
			end
			slider:SetScript("OnValueChanged", function(self, value)
				value = trim(value, step)
				label_(value)
				if not self.updating and tonumber(GetCVar(cvar)) ~= value then
					setValue(cvar, value)
				end
			end)
			tooltip(slider, label, tip, cvar)
			slider.cvar = cvar
			panel.controls[#panel.controls + 1] = slider
		else
			local labelText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			labelText:SetPoint("TOPLEFT", x, y)
			labelText:SetText(label)
			local dropdown = CreateFrame("Frame", panel:GetName() .. "Choice" .. i, panel, "UIDropDownMenuTemplate")
			dropdown:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", -16, -4)
			UIDropDownMenu_SetWidth(dropdown, 140)
			local function textFor(value)
				for _, v in ipairs(c.values) do
					if v[1] == value then
						return v[2]
					end
				end
				return value
			end
			UIDropDownMenu_Initialize(dropdown, function()
				for _, v in ipairs(c.values) do
					local info = UIDropDownMenu_CreateInfo()
					info.text = v[2]
					info.value = v[1]
					info.checked = GetCVar(cvar) == v[1]
					info.func = function()
						setValue(cvar, v[1])
						UIDropDownMenu_SetText(dropdown, v[2])
					end
					UIDropDownMenu_AddButton(info)
				end
			end)
			dropdown.refresh = function()
				UIDropDownMenu_SetText(dropdown, textFor(GetCVar(cvar)))
			end
			tooltip(_G[dropdown:GetName() .. "Button"] or dropdown, label, tip, cvar)
			dropdown.cvar = cvar
			panel.controls[#panel.controls + 1] = dropdown
		end
	end

	panel.refresh = function()
		for _, control in ipairs(panel.controls) do
			control.refresh()
		end
	end
	panel:SetScript("OnShow", panel.refresh)
	panel.okay = function()
		for k in pairs(snapshot) do
			snapshot[k] = nil
		end
	end
	panel.cancel = function()
		for cvar, value in pairs(snapshot) do
			safeSet(cvar, value)
			snapshot[cvar] = nil
		end
	end
	panel.default = function()
		for _, control in ipairs(panel.controls) do
			local default = GetCVarDefault(control.cvar)
			if default then
				setValue(control.cvar, default)
			end
		end
		panel.refresh()
	end
	return panel
end

-- CVar browser --------------------------------------------------------------------------------------

local function makeBrowser(index)
	local ROWS, ROW_HEIGHT = 17, 22
	local panel = CreateFrame("Frame", "ModernUIAdvancedOptions" .. index, UIParent)
	panel:Hide()
	panel.name = "CVar Browser"
	panel.parent = CATEGORY

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("CVar Browser")
	local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	sub:SetPoint("RIGHT", -32, 0)
	sub:SetJustifyH("LEFT")
	sub:SetText("Every setting the client has. Click a value to change it, press Enter to apply. Right-click a row to restore its default.")

	local search = CreateFrame("EditBox", "ModernUIAdvancedOptionsSearch", panel, "InputBoxTemplate")
	search:SetWidth(200)
	search:SetHeight(20)
	search:SetAutoFocus(false)
	search:SetPoint("TOPLEFT", 24, -64)
	local searchLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	searchLabel:SetPoint("LEFT", search, "LEFT", 2, 0)
	searchLabel:SetText(SEARCH or "Search")

	local modified = CreateFrame("CheckButton", "ModernUIAdvancedOptionsModified", panel, "UICheckButtonTemplate")
	modified:SetWidth(24)
	modified:SetHeight(24)
	modified:SetPoint("LEFT", search, "RIGHT", 12, 0)
	_G[modified:GetName() .. "Text"]:SetText("Changed from default only")
	_G[modified:GetName() .. "Text"]:SetFontObject(GameFontHighlightSmall)

	local scroll = CreateFrame("ScrollFrame", "ModernUIAdvancedOptionsScroll", panel, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -92)
	scroll:SetPoint("BOTTOMRIGHT", -34, 12)

	local all, shown, rows = {}, {}, {}

	local function collect()
		for k in pairs(all) do
			all[k] = nil
		end
		local list = ConsoleGetAllCommands and ConsoleGetAllCommands() or {}
		for _, info in ipairs(list) do
			if info.commandType == 0 and info.command ~= "" then
				all[#all + 1] = info
			end
		end
		tsort(all, function(a, b) return a.command:lower() < b.command:lower() end)
	end

	local update
	local function filter()
		for k in pairs(shown) do
			shown[k] = nil
		end
		local text = (search:GetText() or ""):lower()
		local onlyModified = modified:GetChecked()
		for _, info in ipairs(all) do
			local name = info.command
			local matches = text == "" or name:lower():find(text, 1, true) or (info.help or ""):lower():find(text, 1, true)
			if matches and onlyModified then
				local value, default = GetCVarInfo(name)
				matches = value ~= default
			end
			if matches then
				shown[#shown + 1] = info
			end
		end
	end

	update = function()
		local offset = FauxScrollFrame_GetOffset(scroll)
		for i = 1, ROWS do
			local row = rows[i]
			local info = shown[offset + i]
			row.info = info
			if info then
				local value, default = GetCVarInfo(info.command)
				row.name:SetText(info.command)
				if value ~= default then
					row.name:SetTextColor(1, 0.82, 0)
				else
					row.name:SetTextColor(1, 1, 1)
				end
				if not row.value:HasFocus() then
					row.value:SetText(value or "")
				end
				row:Show()
			else
				row:Hide()
			end
		end
		FauxScrollFrame_Update(scroll, #shown, ROWS, ROW_HEIGHT)
	end

	for i = 1, ROWS do
		local row = CreateFrame("Button", "ModernUIAdvancedOptionsRow" .. i, panel)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
		row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row:RegisterForClicks("RightButtonUp")
		row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.name:SetPoint("LEFT", 8, 0)
		row.name:SetWidth(220)
		row.name:SetJustifyH("LEFT")

		local value = CreateFrame("EditBox", "$parentValue", row, "InputBoxTemplate")
		value:SetWidth(150)
		value:SetHeight(18)
		value:SetAutoFocus(false)
		value:SetPoint("RIGHT", -6, 0)
		value:SetScript("OnEnterPressed", function(self)
			if row.info then
				setValue(row.info.command, self:GetText())
			end
			self:ClearFocus()
			update()
		end)
		value:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
			update()
		end)
		value:SetScript("OnEditFocusLost", function() update() end)
		row.value = value

		row:SetScript("OnClick", function()
			if row.info then
				local default = GetCVarDefault(row.info.command)
				if default then
					setValue(row.info.command, default)
					update()
				end
			end
		end)
		row:SetScript("OnEnter", function(self)
			local info = self.info
			if not info then
				return
			end
			local current, default = GetCVarInfo(info.command)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(info.command, 1, 1, 1)
			if info.help and info.help ~= "" then
				GameTooltip:AddLine(info.help, nil, nil, nil, true)
			end
			GameTooltip:AddDoubleLine("Value", tostring(current), 1, 0.82, 0, 1, 1, 1)
			GameTooltip:AddDoubleLine("Default", tostring(default), 1, 0.82, 0, 1, 1, 1)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		rows[i] = row
	end

	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, update)
	end)
	search:SetScript("OnTextChanged", function(self)
		if self:GetText() ~= "" then
			searchLabel:Hide()
		elseif not self:HasFocus() then
			searchLabel:Show()
		end
		filter()
		FauxScrollFrame_SetOffset(scroll, 0)
		_G[scroll:GetName() .. "ScrollBar"]:SetValue(0)
		update()
	end)
	search:SetScript("OnEditFocusGained", function() searchLabel:Hide() end)
	search:SetScript("OnEditFocusLost", function(self)
		if self:GetText() == "" then
			searchLabel:Show()
		end
	end)
	search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	modified:SetScript("OnClick", function()
		filter()
		update()
	end)

	panel.refresh = function()
		collect()
		filter()
		update()
	end
	panel:SetScript("OnShow", panel.refresh)
	panel.okay = function() end
	panel.cancel = function() end
	panel.default = function() end
	return panel
end

-- Registration --------------------------------------------------------------------------------------

for i, page in ipairs(PAGES) do
	panels[#panels + 1] = makePanel(page, i)
end
panels[#panels + 1] = makeBrowser(#PAGES + 1)

-- Pages built into the client go on the Game tab, where each sub-page is placed straight after its
-- parent, so they are added last-first to keep their order. (If this code is not trusted, the AddOns
-- tab takes them, in order.)
InterfaceOptions_AddCategory(panels[1])
if issecure() then
	for i = #panels, 2, -1 do
		InterfaceOptions_AddCategory(panels[i])
	end
else
	for i = 2, #panels do
		InterfaceOptions_AddCategory(panels[i])
	end
end

SLASH_MODERNUI_AIO1 = "/aio"
SlashCmdList.MODERNUI_AIO = function()
	-- The first call can land on the wrong page while the list is still being built; a second puts it right.
	InterfaceOptionsFrame_OpenToCategory(panels[1])
	InterfaceOptionsFrame_OpenToCategory(panels[1])
end
