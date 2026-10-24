-- ModernUI: built into the client (not in the original 3.3.5a).
-- The modern nameplate system on this client's nameplates. The client gives each nameplate showing a unit
-- the token "nameplateN" (UnitGUID("nameplate3"), UnitHealth... work with it) and fires NAME_PLATE_UNIT_ADDED
-- and NAME_PLATE_UNIT_REMOVED; nameplate frames are named NamePlate1, NamePlate2... Here the rest of the
-- modern shape is added: NAME_PLATE_CREATED the first time a plate is used, plate.namePlateUnitToken,
-- plate.UnitFrame (standing for Blizzard's own drawing of the plate, so AddOns that draw their own can hide
-- it), C_NamePlate.GetNamePlateForUnit / GetNamePlates, and NamePlateDriverFrame.

if not ModernUI_GetNamePlateFrame then
	return
end

local _G = _G
local plates = {}        -- index -> plate frame, for every plate that has been used
local seen = {}          -- plate frame -> true once NAME_PLATE_CREATED has gone out

-- Blizzard's drawing of a plate: the regions and child frames the client made for it. Hiding UnitFrame
-- makes them invisible; the plate itself stays, so AddOns can parent their own drawing to it.
local function makeUnitFrame(plate)
	local native = { plate:GetRegions() }
	local nativeChildren = { plate:GetChildren() }
	local healthBar, castBar
	for _, child in ipairs(nativeChildren) do
		if child:GetObjectType() == "StatusBar" then
			if not healthBar then
				healthBar = child
			else
				castBar = castBar or child
			end
		end
	end
	local unitFrame = CreateFrame("Frame", nil, plate)
	unitFrame:SetAllPoints(plate)
	unitFrame:EnableMouse(false)
	local function setVisible(visible)
		local alpha = visible and 1 or 0
		for _, region in ipairs(native) do
			region:SetAlpha(alpha)
		end
		for _, child in ipairs(nativeChildren) do
			child:SetAlpha(alpha)
		end
	end
	local show, hide = unitFrame.Show, unitFrame.Hide
	local hidden = false
	unitFrame.Show = function(self)
		hidden = false
		setVisible(true)
		show(self)
	end
	unitFrame.Hide = function(self)
		hidden = true
		setVisible(false)
		hide(self)
	end
	unitFrame.IsShown = function() return not hidden end
	unitFrame.IsVisible = function() return not hidden and plate:IsVisible() end
	-- The client redraws its own plate parts (name colour, health, highlight) as the unit changes; while
	-- Blizzard's plate is hidden they are kept invisible.
	plate:HookScript("OnUpdate", function()
		if hidden then
			for _, region in ipairs(native) do
				if region:GetAlpha() > 0 then
					region:SetAlpha(0)
				end
			end
			for _, child in ipairs(nativeChildren) do
				if child:GetAlpha() > 0 then
					child:SetAlpha(0)
				end
			end
		end
	end)
	unitFrame.SetShown = function(self, shown)
		if shown then self:Show() else self:Hide() end
	end
	unitFrame.healthBar = healthBar
	unitFrame.HealthBarsContainer = { healthBar = healthBar }
	unitFrame.CastBar = castBar or CreateFrame("StatusBar", nil, unitFrame)
	unitFrame.castBar = unitFrame.CastBar
	for _, region in ipairs(native) do
		if region:GetObjectType() == "FontString" and not unitFrame.name then
			unitFrame.name = region
		end
	end
	return unitFrame
end

local function prepare(plate, token)
	if not seen[plate] then
		seen[plate] = true
		plate.UnitFrame = plate.UnitFrame or makeUnitFrame(plate)
		plate.namePlateUnitToken = token
		plate.UnitFrame.unit = token
		ModernUI_SignalEvent("NAME_PLATE_CREATED", plate)
	end
	plate.namePlateUnitToken = token
	plate.UnitFrame.unit = token
	plate.UnitFrame.displayedUnit = token
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
watcher:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
watcher:SetScript("OnEvent", function(_, event, token)
	local plate, index = ModernUI_GetNamePlateFrame(token)
	if not plate then
		return
	end
	plates[index] = plate
	if event == "NAME_PLATE_UNIT_ADDED" then
		prepare(plate, token)
	end
end)

local C_NamePlate = _G.C_NamePlate or {}
_G.C_NamePlate = C_NamePlate

C_NamePlate.GetNamePlateForUnit = function(unit)
	if type(unit) ~= "string" then
		return nil
	end
	local plate = ModernUI_GetNamePlateFrame(unit)
	if plate then
		return plate
	end
	-- Any other token: the plate showing the same unit.
	local guid = UnitGUID(unit)
	if not guid then
		return nil
	end
	for index, frame in pairs(plates) do
		local current = ModernUI_GetNamePlateFrame(index)
		if current and UnitGUID("nameplate" .. index) == guid then
			return current
		end
	end
	return nil
end

C_NamePlate.GetNamePlates = function()
	local list = {}
	for index in pairs(plates) do
		local plate = ModernUI_GetNamePlateFrame(index)
		if plate then
			list[#list + 1] = plate
		end
	end
	return list
end

-- The frame modern AddOns adjust nameplate behaviour through.
if _G.NamePlateDriverFrame == nil then
	local driver = CreateFrame("Frame", "NamePlateDriverFrame", UIParent)
	driver:Hide()
	driver.namePlateSetInsetFunctions = { friendly = function() end, enemy = function() end, player = function() end }
	driver.namePlateSetupFunctions = { friendly = function() end, enemy = function() end, player = function() end }
	function driver:SetClassNameplateBar(bar) self.classNamePlateMechanicFrame = bar end
	function driver:GetClassNameplateBar() return self.classNamePlateMechanicFrame end
	function driver:SetClassNameplateManaBar(bar) self.classNamePlatePowerBar = bar end
	function driver:GetClassNameplateManaBar() return self.classNamePlatePowerBar end
	function driver:SetClassNameplateAlternatePowerBar(bar) self.classNamePlateAlternatePowerBar = bar end
	function driver:GetClassNameplateAlternatePowerBar() return self.classNamePlateAlternatePowerBar end
	function driver:UpdateNamePlateOptions() end
	function driver:SetBaseNamePlateSize() end
	function driver:GetBaseNamePlateWidth() return 110 end
	function driver:GetBaseNamePlateHeight() return 45 end
	function driver:OnNamePlateAdded() end
	function driver:OnNamePlateRemoved() end
	function driver:OnNamePlateCreated() end
	function driver:IsUsingLargerNamePlateStyle() return false end
	function driver:GetNamePlateTypeFromUnit(unit)
		if UnitIsUnit(unit, "player") then
			return "player"
		end
		return UnitIsFriend("player", unit) and "friendly" or "enemy"
	end
end
