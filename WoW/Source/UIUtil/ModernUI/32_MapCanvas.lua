-- ModernUI: built into the client (not in the original 3.3.5a).
-- The modern world-map canvas on this client's world map. Blizzard's map canvas code (data providers, pins,
-- pin frame levels, the canvas itself) is used as it is; WorldMapFrame becomes a map canvas whose canvas is
-- WorldMapButton, with this client's map drawing underneath. Map IDs are the modern ones C_Map uses.

if _G.MapCanvasMixin then
	return
end

-- MapCanvas_DataProviderBase.lua ---------------------------------------------------------------------

-- Provides a basic interface for something that manages the adding, updating, and removing of data like icons, blobs or text to the map canvas
MapCanvasDataProviderMixin = {};

function MapCanvasDataProviderMixin:OnAdded(owningMap)
	-- Optionally override in your mixin, called when this provider is added to a map canvas
	self.owningMap = owningMap;
end

function MapCanvasDataProviderMixin:OnRemoved(owningMap)
	-- Optionally override in your mixin, called when this provider is removed from a map canvas
	assert(owningMap == self.owningMap);
	self.owningMap = nil;

	if self.registeredEvents then
		for event in pairs(self.registeredEvents) do
			owningMap:UnregisterEvent(event);
		end
		self.registeredEvents = nil;
	end
end

function MapCanvasDataProviderMixin:RemoveAllData()
	-- Override in your mixin, this method should remove everything that has been added to the map
end

function MapCanvasDataProviderMixin:RefreshAllData(fromOnShow)
	-- Override in your mixin, this method should assume the map is completely blank, and refresh any data necessary on the map
end

function MapCanvasDataProviderMixin:OnShow()
	-- Override in your mixin, called when the map canvas is shown
end

function MapCanvasDataProviderMixin:OnHide()
	-- Override in your mixin, called when the map canvas is closed
end

function MapCanvasDataProviderMixin:OnMapInsetSizeChanged(mapInsetIndex, expanded)
	-- Optionally override in your mixin, called when a map inset changes sizes
end

function MapCanvasDataProviderMixin:OnMapInsetMouseEnter(mapInsetIndex)
	-- Optionally override in your mixin, called when a map inset gains mouse focus
end

function MapCanvasDataProviderMixin:OnMapInsetMouseLeave(mapInsetIndex)
	-- Optionally override in your mixin, called when a map inset loses mouse focus
end

function MapCanvasDataProviderMixin:OnCanvasScaleChanged()
	-- Optionally override in your mixin, called when the canvas scale changes
end

function MapCanvasDataProviderMixin:OnCanvasPanChanged()
	-- Optionally override in your mixin, called when the pan location changes
end

function MapCanvasDataProviderMixin:OnCanvasSizeChanged()
	-- Optionally override in your mixin, called when the canvas size changes
end

function MapCanvasDataProviderMixin:OnEvent(event, ...)
	-- Override in your mixin to accept events register via RegisterEvent
end

function MapCanvasDataProviderMixin:OnGlobalAlphaChanged()
	-- Optionally override in your mixin if your data provider obeys global alpha, called when the global alpha changes
end

function MapCanvasDataProviderMixin:GetMap()
	return self.owningMap;
end

function MapCanvasDataProviderMixin:OnMapChanged()
	--  Optionally override in your mixin, called when map ID changes
	self:RefreshAllData();
end

function MapCanvasDataProviderMixin:RegisterEvent(event)
	-- Since data providers aren't frames this provides a similar method of event registration, but always calls self:OnEvent(event, ...)
	if not self.registeredEvents then
		self.registeredEvents = {}
	end
	if not self.registeredEvents[event] then
		self.registeredEvents[event] = true;
		self:GetMap():AddDataProviderEvent(event);
	end
end

function MapCanvasDataProviderMixin:UnregisterEvent(event)
	if self.registeredEvents and self.registeredEvents[event] then
		self.registeredEvents[event] = nil;
		self:GetMap():RemoveDataProviderEvent(event);
	end
end

function MapCanvasDataProviderMixin:SignalEvent(event, ...)
	if self.registeredEvents and self.registeredEvents[event] then
		self:OnEvent(event, ...);
	end
end

-- A base template for data providers that are enabled or disabled with a CVar, e.g. archaeology digsites.
CVarMapCanvasDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin);

function CVarMapCanvasDataProviderMixin:Init(cvar)
	self.cvar = cvar;
end

function CVarMapCanvasDataProviderMixin:IsCVarSet()
	return GetCVarBool(self.cvar);
end

function CVarMapCanvasDataProviderMixin:OnShow()
	self:RegisterEvent("CVAR_UPDATE");
	self:RefreshAllData();
end

function CVarMapCanvasDataProviderMixin:OnHide()
	self:UnregisterEvent("CVAR_UPDATE");
end

function CVarMapCanvasDataProviderMixin:OnEvent(event, ...)
	if event == "CVAR_UPDATE" then
		local eventName, value = ...;
		if eventName == self.cvar then
			self:RefreshAllData();
		end
	end
end

-- Provides a basic interface for something that is visible on the map canvas, like icons, blobs or text
MapCanvasPinMixin = {};

function MapCanvasPinMixin:OnLoad()
	-- Override in your mixin, called when this pin is created
end

function MapCanvasPinMixin:OnAcquired(...) -- the arguments here are anything that are passed into AcquirePin after the pinTemplate
	-- Override in your mixin, called when this pin is being acquired by a data provider but before its added to the map
end

function MapCanvasPinMixin:OnReleased()
	-- Override in your mixin, called when this pin is being released by a data provider and is no longer on the map
end

function MapCanvasPinMixin:OnClick(button)
	-- Override in your mixin, called when this pin is clicked
end

function MapCanvasPinMixin:OnMouseEnter()
	-- Override in your mixin, called when the mouse enters this pin
end

function MapCanvasPinMixin:OnMouseLeave()
	-- Override in your mixin, called when the mouse leaves this pin
end

function MapCanvasPinMixin:OnMouseDown()
	-- Override in your mixin, called when the mouse is pressed on this pin
end

function MapCanvasPinMixin:OnMouseUp()
	-- Override in your mixin, called when the mouse is released
end

function MapCanvasPinMixin:OnMapInsetSizeChanged(mapInsetIndex, expanded)
	-- Optionally override in your mixin, called when a map inset changes sizes
end

function MapCanvasPinMixin:OnMapInsetMouseEnter(mapInsetIndex)
	-- Optionally override in your mixin, called when a map inset gains mouse focus
end

function MapCanvasPinMixin:OnMapInsetMouseLeave(mapInsetIndex)
	-- Optionally override in your mixin, called when a map inset loses mouse focus
end

function MapCanvasPinMixin:SetNudgeTargetFactor(newFactor)
	self.nudgeTargetFactor = newFactor;
end

function MapCanvasPinMixin:GetNudgeTargetFactor()
	return self.nudgeTargetFactor or 0;
end

function MapCanvasPinMixin:SetNudgeSourceRadius(newRadius)
	self.nudgeSourceRadius = newRadius;
end

function MapCanvasPinMixin:GetNudgeSourceRadius()
	return self.nudgeSourceRadius or 0;
end

function MapCanvasPinMixin:SetNudgeSourceMagnitude(nudgeSourceZoomedOutMagnitude, nudgeSourceZoomedInMagnitude)
	self.nudgeSourceZoomedOutMagnitude = nudgeSourceZoomedOutMagnitude;
	self.nudgeSourceZoomedInMagnitude = nudgeSourceZoomedInMagnitude;
end

function MapCanvasPinMixin:GetNudgeSourceZoomedOutMagnitude()
	return self.nudgeSourceZoomedOutMagnitude;
end

function MapCanvasPinMixin:GetNudgeSourceZoomedInMagnitude()
	return self.nudgeSourceZoomedInMagnitude;
end

function MapCanvasPinMixin:SetNudgeZoomedInFactor(newFactor)
	self.zoomedInNudge = newFactor;
end

function MapCanvasPinMixin:GetZoomedInNudgeFactor()
	return self.zoomedInNudge or 0;
end

function MapCanvasPinMixin:SetNudgeZoomedOutFactor(newFactor)
	self.zoomedOutNudge = newFactor;
end

function MapCanvasPinMixin:GetZoomedOutNudgeFactor()
	return self.zoomedOutNudge or 0;
end

function MapCanvasPinMixin:IgnoresNudging()
	return self.insetIndex or (self:GetNudgeSourceRadius() == 0 and self:GetNudgeTargetFactor() == 0);
end

function MapCanvasPinMixin:GetMap()
	return self.owningMap;
end

function MapCanvasPinMixin:GetNudgeVector()
	return self.nudgeVectorX, self.nudgeVectorY;
end

function MapCanvasPinMixin:GetNudgeSourcePinZoomedOutNudgeFactor()
	return self.nudgeSourcePinZoomedOutNudgeFactor or 0;
end

function MapCanvasPinMixin:GetNudgeSourcePinZoomedInNudgeFactor()
	return self.nudgeSourcePinZoomedInNudgeFactor or 0;
end

-- x and y should be a normalized vector.
function MapCanvasPinMixin:SetNudgeVector(sourcePinZoomedOutNudgeFactor, sourcePinZoomedInNudgeFactor, x, y)
	self.nudgeSourcePinZoomedOutNudgeFactor = sourcePinZoomedOutNudgeFactor;
	self.nudgeSourcePinZoomedInNudgeFactor = sourcePinZoomedInNudgeFactor;
	self.nudgeVectorX = x;
	self.nudgeVectorY = y;
	self:ApplyCurrentPosition();
end

function MapCanvasPinMixin:GetNudgeFactor()
	return self.nudgeFactor or 0;
end

function MapCanvasPinMixin:SetNudgeFactor(nudgeFactor)
	self.nudgeFactor = nudgeFactor;
	self:ApplyCurrentPosition();
end

function MapCanvasPinMixin:GetNudgeZoomFactor()
	local zoomPercent = self:GetMap():GetCanvasZoomPercent();
	local targetFactor = Lerp(self:GetZoomedOutNudgeFactor(), self:GetZoomedInNudgeFactor(), zoomPercent);
	local sourceFactor = Lerp(self:GetNudgeSourcePinZoomedOutNudgeFactor(), self:GetNudgeSourcePinZoomedInNudgeFactor(), zoomPercent);
	return targetFactor * sourceFactor;
end

function MapCanvasPinMixin:SetPosition(normalizedX, normalizedY, insetIndex)
	self.normalizedX = normalizedX;
	self.normalizedY = normalizedY;
	self.insetIndex = insetIndex;
	self:GetMap():SetPinPosition(self, normalizedX, normalizedY, insetIndex);
end

-- Returns the global position if not part of an inset, otherwise returns local coordinates of that inset
function MapCanvasPinMixin:GetPosition()
	return self.normalizedX, self.normalizedY, self.insetIndex;
end

-- Returns the global position, even if part of an inset
function MapCanvasPinMixin:GetGlobalPosition()
	if self.insetIndex then
		return self:GetMap():GetGlobalPosition(self.normalizedX, self.normalizedY, self.insetIndex);
	end
	return self.normalizedX, self.normalizedY;
end

function MapCanvasPinMixin:PanTo(normalizedXOffset, normalizedYOffset)
	local normalizedX, normalizedY = self:GetGlobalPosition();
	self:GetMap():PanTo(normalizedX + (normalizedXOffset or 0), (normalizedY or 0));
end

function MapCanvasPinMixin:PanAndZoomTo(normalizedXOffset, normalizedYOffset)
	local normalizedX, normalizedY = self:GetGlobalPosition();
	self:GetMap():PanAndZoomTo(normalizedX + (normalizedXOffset or 0), (normalizedY or 0));
end

function MapCanvasPinMixin:OnCanvasScaleChanged()
	self:ApplyCurrentScale();
	self:ApplyCurrentAlpha();
end

function MapCanvasPinMixin:OnCanvasPanChanged()
	-- Optionally override in your mixin, called when the pan location changes
end

function MapCanvasPinMixin:OnCanvasSizeChanged()
	-- Optionally override in your mixin, called when the canvas size changes
end

function MapCanvasPinMixin:SetIgnoreGlobalPinScale(ignore)
	self.ignoreGlobalPinScale = ignore;
end

function MapCanvasPinMixin:IsIgnoringGlobalPinScale()
	return not not self.ignoreGlobalPinScale;
end

function MapCanvasPinMixin:SetScalingLimits(scaleFactor, startScale, endScale)
	self.scaleFactor = scaleFactor;
	self.startScale = startScale and math.max(startScale, .01) or nil;
	self.endScale = endScale and math.max(endScale, .01) or nil;
end

AM_PIN_SCALE_STYLE_VISIBLE_WHEN_ZOOMED_IN = 1;
AM_PIN_SCALE_STYLE_VISIBLE_WHEN_ZOOMED_OUT = 2;
AM_PIN_SCALE_STYLE_WITH_TERRAIN = 3;

function MapCanvasPinMixin:SetScaleStyle(scaleStyle)
	if scaleStyle == AM_PIN_SCALE_STYLE_VISIBLE_WHEN_ZOOMED_IN then
		self:SetScalingLimits(1.5, 0.0, 2.55);
	elseif scaleStyle == AM_PIN_SCALE_STYLE_VISIBLE_WHEN_ZOOMED_OUT then
		self:SetScalingLimits(1.5, 0.825, 0.0);
	elseif scaleStyle == AM_PIN_SCALE_STYLE_WITH_TERRAIN then
		self:SetScalingLimits(nil, nil, nil);
		if self:IsIgnoringGlobalPinScale() then
			self:SetScale(1.0);
		else
			self:SetScale(self:GetGlobalPinScale());
		end
	end
end

function MapCanvasPinMixin:SetAlphaLimits(alphaFactor, startAlpha, endAlpha)
	self.alphaFactor = alphaFactor;
	self.startAlpha = startAlpha;
	self.endAlpha = endAlpha;
end

AM_PIN_ALPHA_STYLE_VISIBLE_WHEN_ZOOMED_IN = 1;
AM_PIN_ALPHA_STYLE_VISIBLE_WHEN_ZOOMED_OUT = 2;
AM_PIN_ALPHA_STYLE_ALWAYS_VISIBLE = 3;

function MapCanvasPinMixin:SetAlphaStyle(alphaStyle)
	if alphaStyle == AM_PIN_ALPHA_STYLE_VISIBLE_WHEN_ZOOMED_IN then
		self:SetAlphaLimits(2.0, 0.0, 1.0);
	elseif alphaStyle == AM_PIN_ALPHA_STYLE_VISIBLE_WHEN_ZOOMED_OUT then
		self:SetAlphaLimits(2.0, 1.0, 0.0);
	elseif alphaStyle == AM_PIN_ALPHA_STYLE_ALWAYS_VISIBLE then
		self:SetAlphaLimits(nil, nil, nil);
	end
end

function MapCanvasPinMixin:ApplyCurrentPosition()
	self:GetMap():ApplyPinPosition(self, self.normalizedX, self.normalizedY, self.insetIndex);
end

function MapCanvasPinMixin:ApplyCurrentScale()
	local scale;
	if self.startScale and self.startScale and self.endScale then
		local parentScaleFactor = 1.0 / self:GetMap():GetCanvasScale();
		scale = parentScaleFactor * Lerp(self.startScale, self.endScale, Saturate(self.scaleFactor * self:GetMap():GetCanvasZoomPercent()));
	elseif not self:IsIgnoringGlobalPinScale() then
		scale = 1;
	end
	if scale then
		if not self:IsIgnoringGlobalPinScale() then
			scale = scale * self:GetMap():GetGlobalPinScale();
		end
		self:SetScale(math.max(scale, 0.01));
		self:ApplyCurrentPosition();
	end
end

function MapCanvasPinMixin:ApplyCurrentAlpha()
	if self.alphaFactor and self.startAlpha and self.endAlpha then
		local alpha = Lerp(self.startAlpha, self.endAlpha, Saturate(self.alphaFactor * self:GetMap():GetCanvasZoomPercent()));
		self:SetAlpha(alpha);
		self:SetShown(alpha > 0.05);
	end
end

function MapCanvasPinMixin:UseFrameLevelType(pinFrameLevelType, index)
	self.pinFrameLevelType = pinFrameLevelType;
	self.pinFrameLevelIndex = index;
end

function MapCanvasPinMixin:GetFrameLevelType(pinFrameLevelType)
	return self.pinFrameLevelType or "PIN_FRAME_LEVEL_DEFAULT";
end

function MapCanvasPinMixin:ApplyFrameLevel()
	local frameLevel = self:GetMap():GetPinFrameLevelsManager():GetValidFrameLevel(self.pinFrameLevelType, self.pinFrameLevelIndex);
	self:SetFrameLevel(frameLevel);
end

function MapCanvasPinMixin:GetDataProvider()
	return self.dataProvider;
end

function MapCanvasPinMixin:SetDataProvider(dataProvider)
	self.dataProvider = dataProvider;
end

-- MapCanvas_PinFrameLevelsManager.lua ---------------------------------------------------------------

MapCanvasPinFrameLevelsManagerMixin = {};

local MAP_CANVAS_PIN_FRAME_LEVEL_DEFAULT = 2000;
local MAX_FRAME_LEVEL = 9000;
local MIN_FRAME_LEVEL = 0;

function MapCanvasPinFrameLevelsManagerMixin:Initialize()
	if not self.definitions then
		self.definitions = { ["PIN_FRAME_LEVEL_DEFAULT"] = { startLevel = MAP_CANVAS_PIN_FRAME_LEVEL_DEFAULT, range = 1 } };
		self.topMostDefinition = self.definitions["PIN_FRAME_LEVEL_DEFAULT"];
		self.minLevel = MAP_CANVAS_PIN_FRAME_LEVEL_DEFAULT;
		self.maxLevel = MAP_CANVAS_PIN_FRAME_LEVEL_DEFAULT;
	end
end

function MapCanvasPinFrameLevelsManagerMixin:ValidateContiguous()
	local start = self.minLevel;
	while start < self.maxLevel do
		local found = false;
		for frameLevelType, definition in pairs(self.definitions) do
			if definition.startLevel == start then
				found = true;
				start = definition.startLevel + definition.range;
				break;
			end
		end
		if not found then
			return false;
		end
	end
	return true;
end

function MapCanvasPinFrameLevelsManagerMixin:AddDefinition(frameLevelType, range, targetLevel, comparisonMod)
	if targetLevel > self:GetFrameLevelStart("PIN_FRAME_LEVEL_DEFAULT") then
		if self.maxLevel + range > MAX_FRAME_LEVEL then
			return false;
		end

		for _, definition in pairs(self.definitions) do
			if definition.startLevel > targetLevel + comparisonMod then
				definition.startLevel = definition.startLevel + range;
			end
		end
		self.maxLevel = self.maxLevel + range;
	else
		if self.minLevel - range < MIN_FRAME_LEVEL then
			return false;
		end

		for _, definition in pairs(self.definitions) do
			if definition.startLevel < targetLevel + comparisonMod then
				definition.startLevel = definition.startLevel - range;
			end
		end
		self.minLevel = self.minLevel - range;
	end
	self.definitions[frameLevelType] = { startLevel = targetLevel, range = range };
	if self.topMostDefinition.startLevel < targetLevel then
		self.topMostDefinition = self.definitions[frameLevelType];
	end
	return true;
end

function MapCanvasPinFrameLevelsManagerMixin:AddFrameLevel(frameLevelType, optionalRange)
	if self.definitions[frameLevelType] or frameLevelType == "PIN_FRAME_LEVEL_TOPMOST" then
		return false;
	end

	local range = optionalRange or 1;
	local targetLevel = self.maxLevel + 1;
	local comparisonMod = 0;
	return self:AddDefinition(frameLevelType, range, targetLevel, comparisonMod);
end

function MapCanvasPinFrameLevelsManagerMixin:InsertFrameLevelAbove(frameLevelType, relativeFrameLevelType, optionalRange)
	local relativeDefinition = self.definitions[relativeFrameLevelType];
	if not relativeDefinition or self.definitions[frameLevelType] or frameLevelType == "PIN_FRAME_LEVEL_TOPMOST" then
		return false;
	end

	local range = optionalRange or 1;
	local targetLevel, comparisonMod;
	if relativeDefinition.startLevel < self:GetFrameLevelStart("PIN_FRAME_LEVEL_DEFAULT") then
		targetLevel = relativeDefinition.startLevel + relativeDefinition.range - range;
		comparisonMod = range - relativeDefinition.range + 1;
	else
		targetLevel = relativeDefinition.startLevel + relativeDefinition.range;
		comparisonMod = -1;
	end
	return self:AddDefinition(frameLevelType, range, targetLevel, comparisonMod);
end

function MapCanvasPinFrameLevelsManagerMixin:InsertFrameLevelBelow(frameLevelType, relativeFrameLevelType, optionalRange)
	local relativeDefinition = self.definitions[relativeFrameLevelType];
	if not relativeDefinition or self.definitions[frameLevelType] or frameLevelType == "PIN_FRAME_LEVEL_TOPMOST" then
		return false;
	end

	local range = optionalRange or 1;
	local targetLevel, comparisonMod;
	if relativeDefinition.startLevel <= self:GetFrameLevelStart("PIN_FRAME_LEVEL_DEFAULT") then
		targetLevel = relativeDefinition.startLevel - range;
		comparisonMod = range;
	else
		targetLevel = relativeDefinition.startLevel;
		comparisonMod = -1;
	end
	return self:AddDefinition(frameLevelType, range, targetLevel, comparisonMod);
end

function MapCanvasPinFrameLevelsManagerMixin:SetOverride(frameLevelType, overrideFrameLevelType)
	local definition = self.definitions[frameLevelType];
	if not definition or not self.definitions[overrideFrameLevelType] or definition.overrideType == overrideFrameLevelType then
		return false;
	end
	definition.overrideType = overrideFrameLevelType;
	return true;
end

function MapCanvasPinFrameLevelsManagerMixin:ClearOverride(frameLevelType)
	local definition = self.definitions[frameLevelType];
	if not definition or not definition.overrideType then
		return false;
	end
	definition.overrideType = nil;
	return true;
end

function MapCanvasPinFrameLevelsManagerMixin:GetFrameLevelStart(frameLevelType)
	local definition = self.definitions[frameLevelType] or self.definitions["PIN_FRAME_LEVEL_DEFAULT"];
	if definition.overrideType then
		definition = self.definitions[definition.overrideType];
	end
	return definition.startLevel;
end

function MapCanvasPinFrameLevelsManagerMixin:GetValidFrameLevel(frameLevelType, optionalIndex)
	local definition;
	if frameLevelType == "PIN_FRAME_LEVEL_TOPMOST" then
		definition = self.topMostDefinition;
	else
		definition = self.definitions[frameLevelType] or self.definitions["PIN_FRAME_LEVEL_DEFAULT"];
		if definition.overrideType then
			definition = self.definitions[definition.overrideType];
		end
	end
	local offset = Clamp(optionalIndex or 1, 1, definition.range) - 1;
	return definition.startLevel + offset;
end

-- Blizzard_MapCanvas.lua -------------------------------------------------------------------------------

MapCanvasMixin = CreateFromMixins(CallbackRegistryMixin);

function MapCanvasMixin:OnLoad()
	CallbackRegistryMixin.OnLoad(self);
	self:SetUndefinedEventsAllowed(true);

	self.detailLayerPool = CreateFramePool("FRAME", self:GetCanvas(), "MapCanvasDetailLayerTemplate");
	self.dataProviders = {};
	self.dataProviderEventsCount = {};
	self.pinPools = {};
	self.pinTemplateTypes = {};
	self.activeAreaTriggers = {};
	self.lockReasons = {};
	self.pinsToNudge = {};
	self.pinFrameLevelsManager = CreateFromMixins(MapCanvasPinFrameLevelsManagerMixin);
	self.pinFrameLevelsManager:Initialize();
	self.mouseClickHandlers = {};

	self:EvaluateLockReasons();

	self.debugAreaTriggers = false;
end

function MapCanvasMixin:OnUpdate()
	self:UpdatePinNudging();
end

function MapCanvasMixin:SetMapID(mapID)
	local mapArtID = C_Map.GetMapArtID(mapID) -- phased map art may be different for the same mapID
	if self.mapID ~= mapID or self.mapArtID ~= mapArtID then
		self.areDetailLayersDirty = true;
		self.mapID = mapID;
		self.mapArtID = mapArtID;
		self.expandedMapInsetsByMapID = {};
		self.ScrollContainer:SetMapID(mapID);
		if self:IsShown() then
			self:RefreshDetailLayers();
		end
		self:OnMapChanged();
	end
end

function MapCanvasMixin:OnFrameSizeChanged()
	self.ScrollContainer:OnCanvasSizeChanged();
end

function MapCanvasMixin:GetMapID()
	-- normally the mapID is set in OnShow, however if the player has never opened the quest log or the map, and then
	-- hides the UI, and while the UI is hidden opens the quest log, mapID will be nil and we get a lua error.
	-- under these very rare circumstances, dig out the diplayable mapID.
	return self.mapID or MapUtil.GetDisplayableMapForPlayer();
end

function MapCanvasMixin:SetMapInsetPool(mapInsetPool)
	self.mapInsetPool = mapInsetPool;
end

function MapCanvasMixin:GetMapInsetPool()
	return self.mapInsetPool;
end

function MapCanvasMixin:OnShow()
	local FROM_ON_SHOW = true;
	self:RefreshAll(FROM_ON_SHOW);

	for dataProvider in pairs(self.dataProviders) do
		dataProvider:OnShow();
	end
end

function MapCanvasMixin:OnHide()
	for dataProvider in pairs(self.dataProviders) do
		dataProvider:OnHide();
	end
end

function MapCanvasMixin:OnEvent(event, ...)
	-- Data provider event
	for dataProvider in pairs(self.dataProviders) do
		dataProvider:SignalEvent(event, ...);
	end
end

function MapCanvasMixin:AddDataProvider(dataProvider)
	self.dataProviders[dataProvider] = true;
	dataProvider:OnAdded(self);
end

function MapCanvasMixin:RemoveDataProvider(dataProvider)
	dataProvider:RemoveAllData();
	self.dataProviders[dataProvider] = nil;
	dataProvider:OnRemoved(self);
end

function MapCanvasMixin:AddDataProviderEvent(event)
	self.dataProviderEventsCount[event] = (self.dataProviderEventsCount[event] or 0) + 1;
	self:RegisterEvent(event);
end

function MapCanvasMixin:RemoveDataProviderEvent(event)
	if self.dataProviderEventsCount[event] then
		self.dataProviderEventsCount[event] = self.dataProviderEventsCount[event] - 1;
		if self.dataProviderEventsCount[event] == 0 then
			self.dataProviderEventsCount[event] = nil;
			self:UnregisterEvent(event);
		end
	end
end

function MapCanvasMixin:SetPinNudgingDirty()
	self.pinNudgingDirty = true;
end

function MapCanvasMixin:AddPinToNudge(pin)
	table.insert(self.pinsToNudge, pin);
end

function MapCanvasMixin:IsPinNudgingDirty()
	return self.pinNudgingDirty or (self.pinsToNudge and #self.pinsToNudge > 0);
end

function MapCanvasMixin:EnumeratePinsToNudge()
	if self.pinNudgingDirty then
		return self:EnumerateAllPins();
	elseif #self.pinsToNudge then
		return ipairs(self.pinsToNudge);
	end
end

function MapCanvasMixin:MarkPinNudgingClean()
	self.pinNudgingDirty = false;
	self.pinsToNudge = {};
end

function MapCanvasMixin:SetPinPostProcessDirty()
	self:SetPinNudgingDirty();
end

do
	local function OnPinReleased(pinPool, pin)
		Pool_HideAndClearAnchors(pinPool, pin);
		pin:OnReleased();

		pin.pinTemplate = nil;
		pin.owningMap = nil;
	end

	local function OnPinMouseUp(pin, button, upInside)
		pin:OnMouseUp(button);
		if upInside then
			pin:OnClick(button);
		end
	end

	function MapCanvasMixin:AcquirePin(pinTemplate, ...)
		if not self.pinPools[pinTemplate] then
			local pinTemplateType = self:GetPinTemplateType(pinTemplate);
			self.pinPools[pinTemplate] = CreateFramePool(pinTemplateType, self:GetCanvas(), pinTemplate, OnPinReleased);
		end

		local pin, newPin = self.pinPools[pinTemplate]:Acquire();

		if newPin then
			local isMouseClickEnabled = pin:IsMouseClickEnabled();
			local isMouseMotionEnabled = pin:IsMouseMotionEnabled();

			if isMouseClickEnabled then
				pin:SetScript("OnMouseUp", OnPinMouseUp);
				pin:SetScript("OnMouseDown", pin.OnMouseDown);
			end

			if isMouseMotionEnabled then
				if newPin then
					-- These will never be called, just define a OnMouseEnter and OnMouseLeave on the pin mixin and it'll be called when appropriate
					assert(pin:GetScript("OnEnter") == nil);
					assert(pin:GetScript("OnLeave") == nil);
				end
				pin:SetScript("OnEnter", pin.OnMouseEnter);
				pin:SetScript("OnLeave", pin.OnMouseLeave);
			end

			pin:SetMouseClickEnabled(isMouseClickEnabled);
			pin:SetMouseMotionEnabled(isMouseMotionEnabled);
		end

		pin.pinTemplate = pinTemplate;
		pin.owningMap = self;

		if newPin then
			pin:OnLoad();
		end

		self.ScrollContainer:MarkCanvasDirty();
		pin:Show();
		pin:OnAcquired(...);

		return pin;
	end
end

function MapCanvasMixin:SetPinTemplateType(pinTemplate, pinTemplateType)
	self.pinTemplateTypes[pinTemplate] = pinTemplateType;
end

function MapCanvasMixin:GetPinTemplateType(pinTemplate)
	-- Can always be overridden by manually calling SetPinTemplateType, but by default this will use the template
	-- to look up type information and discover the most likely type so that pins can avoid needing to call
	-- SetPinTemplateType.
	local pinTemplateType = self.pinTemplateTypes[pinTemplate];
	if not pinTemplateType then
		local templateInfo = C_XMLUtil.GetTemplateInfo(pinTemplate);
		pinTemplateType = templateInfo and templateInfo.type or "FRAME";
		self.pinTemplateTypes[pinTemplate] = pinTemplateType;
	end

	return pinTemplateType;
end

function MapCanvasMixin:RemoveAllPinsByTemplate(pinTemplate)
	if self.pinPools[pinTemplate] then
		self.pinPools[pinTemplate]:ReleaseAll();
		self.ScrollContainer:MarkCanvasDirty();
	end
end

function MapCanvasMixin:RemovePin(pin)
	if pin:GetNudgeSourceRadius() > 0 then
		self:SetPinNudgingDirty();
	end

	self.pinPools[pin.pinTemplate]:Release(pin);
	self.ScrollContainer:MarkCanvasDirty();
end

function MapCanvasMixin:EnumeratePinsByTemplate(pinTemplate)
	if self.pinPools[pinTemplate] then
		return self.pinPools[pinTemplate]:EnumerateActive();
	end
	return nop;
end

function MapCanvasMixin:GetNumActivePinsByTemplate(pinTemplate)
	if self.pinPools[pinTemplate] then
		return self.pinPools[pinTemplate]:GetNumActive();
	end
	return 0;
end

function MapCanvasMixin:EnumerateAllPins()
	local currentPoolKey, currentPool = next(self.pinPools, nil);
	local currentPin = nil;
	return function()
		if currentPool then
			currentPin = currentPool:GetNextActive(currentPin);
			while not currentPin do
				currentPoolKey, currentPool = next(self.pinPools, currentPoolKey);
				if currentPool then
					currentPin = currentPool:GetNextActive();
				else
					break;
				end
			end
		end

		return currentPin;
	end, nil;
end

function MapCanvasMixin:AcquireAreaTrigger(namespace)
	if not self.activeAreaTriggers[namespace] then
		self.activeAreaTriggers[namespace] = {};
	end
	local areaTrigger = CreateRectangle();
	areaTrigger.enclosed = false;
	areaTrigger.intersects = false;

	areaTrigger.intersectCallback = nil;
	areaTrigger.enclosedCallback = nil;
	areaTrigger.triggerPredicate = nil;

	self.activeAreaTriggers[namespace][areaTrigger] = true;
	self.ScrollContainer:MarkAreaTriggersDirty();
	return areaTrigger;
end

function MapCanvasMixin:SetAreaTriggerEnclosedCallback(areaTrigger, enclosedCallback)
	areaTrigger.enclosedCallback = enclosedCallback;
	self.ScrollContainer:MarkAreaTriggersDirty();
end

function MapCanvasMixin:SetAreaTriggerIntersectsCallback(areaTrigger, intersectCallback)
	areaTrigger.intersectCallback = intersectCallback;
	self.ScrollContainer:MarkAreaTriggersDirty();
end

function MapCanvasMixin:SetAreaTriggerPredicate(areaTrigger, triggerPredicate)
	areaTrigger.triggerPredicate = triggerPredicate;
	self.ScrollContainer:MarkAreaTriggersDirty();
end

function MapCanvasMixin:ReleaseAreaTriggers(namespace)
	self.activeAreaTriggers[namespace] = nil;
	self:TryRefreshingDebugAreaTriggers();
end

function MapCanvasMixin:ReleaseAreaTrigger(namespace, areaTrigger)
	if self.activeAreaTriggers[namespace] then
		self.activeAreaTriggers[namespace][areaTrigger] = nil;
		self:TryRefreshingDebugAreaTriggers();
	end
end

function MapCanvasMixin:UpdateAreaTriggers(scrollRect)
	for namespace, areaTriggers in pairs(self.activeAreaTriggers) do
		for areaTrigger in pairs(areaTriggers) do
			if areaTrigger.intersectCallback then
				local intersects = (not areaTrigger.triggerPredicate or areaTrigger.triggerPredicate(areaTrigger)) and scrollRect:IntersectsRect(areaTrigger);
				if areaTrigger.intersects ~= intersects then
					areaTrigger.intersects = intersects;
					areaTrigger.intersectCallback(areaTrigger, intersects);
				end
			end

			if areaTrigger.enclosedCallback then
				local enclosed = (not areaTrigger.triggerPredicate or areaTrigger.triggerPredicate(areaTrigger)) and scrollRect:EnclosesRect(areaTrigger);

				if areaTrigger.enclosed ~= enclosed then
					areaTrigger.enclosed = enclosed;
					areaTrigger.enclosedCallback(areaTrigger, enclosed);
				end
			end
		end
	end

	self:TryRefreshingDebugAreaTriggers();
end

function SquaredDistanceBetweenPoints(firstX, firstY, secondX, secondY)
	local xDiff = firstX - secondX;
	local yDiff = firstY - secondY;

	return xDiff * xDiff + yDiff * yDiff;
end

function MapCanvasMixin:CalculatePinNudging(targetPin)
	targetPin:SetNudgeVector(nil, nil, nil, nil);
	if not targetPin:IgnoresNudging() and targetPin:GetNudgeTargetFactor() > 0 then
		local normalizedX, normalizedY = targetPin:GetPosition();
		for sourcePin in self:EnumerateAllPins() do
			if targetPin ~= sourcePin and not sourcePin:IgnoresNudging() and sourcePin:GetNudgeSourceRadius() > 0 then
				local otherNormalizedX, otherNormalizedY = sourcePin:GetPosition();
				local distanceSquared = SquaredDistanceBetweenPoints(normalizedX, normalizedY, otherNormalizedX, otherNormalizedY);

				local nudgeFactor = targetPin:GetNudgeTargetFactor() * sourcePin:GetNudgeSourceRadius();
				if distanceSquared < nudgeFactor * nudgeFactor then
					local distance = math.sqrt(distanceSquared);

					-- Avoid divide by zero: just push it right.
					if distanceSquared == 0 then
						targetPin:SetNudgeVector(sourcePin:GetNudgeSourceZoomedOutMagnitude(), sourcePin:GetNudgeSourceZoomedInMagnitude(), 1, 0);
					else
						targetPin:SetNudgeVector(sourcePin:GetNudgeSourceZoomedOutMagnitude(), sourcePin:GetNudgeSourceZoomedInMagnitude(), (normalizedX - otherNormalizedX) / distance, (normalizedY - otherNormalizedY) / distance);
					end

					targetPin:SetNudgeFactor(1 - (distance / nudgeFactor));
					break; -- This is non-exact: each target pin only gets pushed by one source pin.
				end
			end
		end
	end
end

function MapCanvasMixin:UpdatePinNudging()
	if self:IsPinNudgingDirty() then
		for targetPin in self:EnumeratePinsToNudge() do
			self:CalculatePinNudging(targetPin);
		end

		self:MarkPinNudgingClean();
	end
end

function MapCanvasMixin:TryRefreshingDebugAreaTriggers()
	if self.debugAreaTriggers then
		self:RefreshDebugAreaTriggers();
	elseif self.debugAreaTriggerPool then
		self.debugAreaTriggerPool:ReleaseAll();
	end
end

function MapCanvasMixin:RefreshDebugAreaTriggers()
	if not self.debugAreaTriggerPool then
		self.debugAreaTriggerPool = CreateTexturePool(self:GetCanvas(), "OVERLAY", 7, "MapCanvasDebugTriggerAreaTemplate");
		self.debugAreaTriggerColors = {};
	end

	self.debugAreaTriggerPool:ReleaseAll();

	local canvas = self:GetCanvas();

	for namespace, areaTriggers in pairs(self.activeAreaTriggers) do
		if not self.debugAreaTriggerColors[namespace] then
			self.debugAreaTriggerColors[namespace] = { math.random(), math.random(), math.random(), 0.45 };
		end
		for areaTrigger in pairs(areaTriggers) do
			local debugAreaTexture = self.debugAreaTriggerPool:Acquire();
			debugAreaTexture:SetPoint("TOPLEFT", canvas, "TOPLEFT", canvas:GetWidth() * areaTrigger:GetLeft(), -canvas:GetHeight() * areaTrigger:GetTop());
			debugAreaTexture:SetPoint("BOTTOMRIGHT", canvas, "TOPLEFT", canvas:GetWidth() * areaTrigger:GetRight(), -canvas:GetHeight() * areaTrigger:GetBottom());
			debugAreaTexture:SetColorTexture(unpack(self.debugAreaTriggerColors[namespace]));
			debugAreaTexture:Show();
		end
	end
end

function MapCanvasMixin:SetDebugAreaTriggersEnabled(enabled)
	self.debugAreaTriggers = enabled;
	self.ScrollContainer:MarkAreaTriggersDirty();
end

function MapCanvasMixin:RefreshDetailLayers()
	if not self.areDetailLayersDirty then return end;
	self.detailLayerPool:ReleaseAll();

	local layers = C_Map.GetMapArtLayers(self.mapID);
	for layerIndex, layerInfo in ipairs(layers) do
		local detailLayer = self.detailLayerPool:Acquire();
		detailLayer:SetAllPoints(self:GetCanvas());
		detailLayer:SetMapAndLayer(self.mapID, layerIndex);
		detailLayer:SetGlobalAlpha(self:GetGlobalAlpha());
		detailLayer:Show();
	end

	self:AdjustDetailLayerAlpha();

	self.areDetailLayersDirty = false;
end

function MapCanvasMixin:AreDetailLayersLoaded()
	for detailLayer in self.detailLayerPool:EnumerateActive() do
		if not detailLayer:IsFullyLoaded() then
			return false;
		end
	end
	return true;
end

function MapCanvasMixin:AdjustDetailLayerAlpha()
	self.ScrollContainer:AdjustDetailLayerAlpha(self.detailLayerPool);
end

function MapCanvasMixin:RefreshAllDataProviders(fromOnShow)
	for dataProvider in pairs(self.dataProviders) do
		dataProvider:RefreshAllData(fromOnShow);
	end
end

function MapCanvasMixin:ResetInsets()
	if self.mapInsetPool then
		self.mapInsetPool:ReleaseAll();
		self.mapInsetsByIndex = {};
	end
end

function MapCanvasMixin:RefreshInsets()
	self:ResetInsets();
end

function MapCanvasMixin:AddInset(insetIndex, mapID, title, description, collapsedIcon, numDetailTiles, normalizedX, normalizedY)
	if self.mapInsetPool then
		local mapInset = self.mapInsetPool:Acquire();
		local expanded = self.expandedMapInsetsByMapID[mapID];
		mapInset:Initialize(self, not expanded, insetIndex, mapID, title, description, collapsedIcon, numDetailTiles, normalizedX, normalizedY);

		self.mapInsetsByIndex[insetIndex] = mapInset;
	end
end

function MapCanvasMixin:RefreshAll(fromOnShow)
	self:RefreshDetailLayers();
	self:RefreshInsets();
	self:RefreshAllDataProviders(fromOnShow);
end

function MapCanvasMixin:SetPinPosition(pin, normalizedX, normalizedY, insetIndex)
	self:ApplyPinPosition(pin, normalizedX, normalizedY, insetIndex);
	if not pin:IgnoresNudging() then
		if pin:GetNudgeSourceRadius() > 0 then
			-- If we nudge other things we need to recalculate all nudging.
			self:SetPinNudgingDirty();
		else
			self:AddPinToNudge(pin);
		end
	end
end

function MapCanvasMixin:ApplyPinPosition(pin, normalizedX, normalizedY, insetIndex)
	if insetIndex then
		if self.mapInsetsByIndex and self.mapInsetsByIndex[insetIndex] then
			self.mapInsetsByIndex[insetIndex]:SetLocalPinPosition(pin, normalizedX, normalizedY);
			pin:ApplyFrameLevel();
		end
	else
		pin:ClearAllPoints();
		if normalizedX and normalizedY then
			local x = normalizedX;
			local y = normalizedY;

			local nudgeVectorX, nudgeVectorY = pin:GetNudgeVector();
			if nudgeVectorX and nudgeVectorY then
				local finalNudgeFactor = pin:GetNudgeFactor() * pin:GetNudgeTargetFactor() * pin:GetNudgeZoomFactor();
				x = normalizedX + nudgeVectorX * finalNudgeFactor;
				y = normalizedY + nudgeVectorY * finalNudgeFactor;
			end

			local canvas = self:GetCanvas();
			local scale = pin:GetScale();
			pin:SetParent(canvas);
			pin:ApplyFrameLevel();
			pin:SetPoint("CENTER", canvas, "TOPLEFT", (canvas:GetWidth() * x) / scale, -(canvas:GetHeight() * y) / scale);
		end
	end
end

function MapCanvasMixin:GetGlobalPosition(normalizedX, normalizedY, insetIndex)
	if self.mapInsetsByIndex and self.mapInsetsByIndex[insetIndex] then
		return self.mapInsetsByIndex[insetIndex]:GetGlobalPosition(normalizedX, normalizedY);
	end
	return normalizedX, normalizedY;
end

function MapCanvasMixin:GetCanvas()
	return self.ScrollContainer.Child;
end

function MapCanvasMixin:GetCanvasContainer()
	return self.ScrollContainer;
end

function MapCanvasMixin:CallMethodOnPinsAndDataProviders(methodName, ...)
	for dataProvider in pairs(self.dataProviders) do
		dataProvider[methodName](dataProvider, ...);
	end

	for pin in self:EnumerateAllPins() do
		pin[methodName](pin, ...);
	end
end

function MapCanvasMixin:OnMapInsetSizeChanged(mapID, mapInsetIndex, expanded)
	self.expandedMapInsetsByMapID[mapID] = expanded;
	self:CallMethodOnPinsAndDataProviders("OnMapInsetSizeChanged", mapInsetIndex, expanded);
end

function MapCanvasMixin:OnMapInsetMouseEnter(mapInsetIndex)
	self:CallMethodOnPinsAndDataProviders("OnMapInsetMouseEnter", mapInsetIndex);
end

function MapCanvasMixin:OnMapInsetMouseLeave(mapInsetIndex)
	self:CallMethodOnPinsAndDataProviders("OnMapInsetMouseLeave", mapInsetIndex);
end

function MapCanvasMixin:OnMapChanged()
	for dataProvider in pairs(self.dataProviders) do
		dataProvider:OnMapChanged();
	end
end

function MapCanvasMixin:OnCanvasScaleChanged()
	self:AdjustDetailLayerAlpha();

	if self.mapInsetsByIndex then
		for insetIndex, mapInset in pairs(self.mapInsetsByIndex) do
			mapInset:OnCanvasScaleChanged();
		end
	end

	self:CallMethodOnPinsAndDataProviders("OnCanvasScaleChanged");
end

function MapCanvasMixin:OnCanvasPanChanged()
	self:CallMethodOnPinsAndDataProviders("OnCanvasPanChanged");
end

function MapCanvasMixin:OnCanvasSizeChanged()
	self:CallMethodOnPinsAndDataProviders("OnCanvasSizeChanged");
end

function MapCanvasMixin:GetCanvasScale()
	return self.ScrollContainer:GetCanvasScale();
end

function MapCanvasMixin:GetCanvasZoomPercent()
	return self.ScrollContainer:GetCanvasZoomPercent();
end

function MapCanvasMixin:IsZoomingIn()
	return self.ScrollContainer:IsZoomingIn();
end

function MapCanvasMixin:IsZoomingOut()
	return self.ScrollContainer:IsZoomingOut();
end

function MapCanvasMixin:ZoomIn()
	self.ScrollContainer:ZoomIn();
end

function MapCanvasMixin:ZoomOut()
	self.ScrollContainer:ZoomOut();
end

function MapCanvasMixin:ResetZoom()
	self.ScrollContainer:ResetZoom();
end

function MapCanvasMixin:IsAtMaxZoom()
	return self.ScrollContainer:IsAtMaxZoom();
end

function MapCanvasMixin:IsAtMinZoom()
	return self.ScrollContainer:IsAtMinZoom();
end

function MapCanvasMixin:PanTo(normalizedX, normalizedY)
	self.ScrollContainer:SetPanTarget(normalizedX, normalizedY);
end

function MapCanvasMixin:PanAndZoomTo(normalizedX, normalizedY)
	self.ScrollContainer:SetPanTarget(normalizedX, normalizedY);
	self.ScrollContainer:ZoomIn();
end

function MapCanvasMixin:SetMouseWheelZoomMode(zoomMode)
	self.ScrollContainer:SetMouseWheelZoomMode(zoomMode);
end

function MapCanvasMixin:SetShouldZoomInOnClick(shouldZoomInOnClick)
	self.ScrollContainer:SetShouldZoomInOnClick(shouldZoomInOnClick);
end

function MapCanvasMixin:ShouldZoomInOnClick()
	return self.ScrollContainer:ShouldZoomInOnClick();
end

function MapCanvasMixin:SetShouldNavigateOnClick(shouldNavigateOnClick)
	self.ScrollContainer:SetShouldNavigateOnClick(shouldNavigateOnClick);
end

function MapCanvasMixin:ShouldNavigateOnClick()
	return self.ScrollContainer:ShouldNavigateOnClick();
end

function MapCanvasMixin:SetShouldPanOnClick(shouldPanOnClick)
	self.ScrollContainer:SetShouldPanOnClick(shouldPanOnClick);
end

function MapCanvasMixin:ShouldPanOnClick()
	return self.ScrollContainer:ShouldPanOnClick();
end

function MapCanvasMixin:SetShouldZoomInstantly(shouldZoomInstantly)
	self.ScrollContainer:SetShouldZoomInstantly(shouldZoomInstantly);
end

function MapCanvasMixin:ShouldZoomInstantly()
	return self.ScrollContainer:ShouldZoomInstantly();
end

function MapCanvasMixin:GetViewRect()
	return self.ScrollContainer:GetViewRect();
end

function MapCanvasMixin:GetMaxZoomViewRect()
	return self.ScrollContainer:GetMaxZoomViewRect();
end

function MapCanvasMixin:GetMinZoomViewRect()
	return self.ScrollContainer:GetMinZoomViewRect();
end

function MapCanvasMixin:GetScaleForMaxZoom()
	return self.ScrollContainer:GetScaleForMaxZoom();
end

function MapCanvasMixin:GetScaleForMinZoom()
	return self.ScrollContainer:GetScaleForMinZoom();
end

function MapCanvasMixin:CalculateZoomScaleAndPositionForAreaInViewRect(...)
	return self.ScrollContainer:CalculateZoomScaleAndPositionForAreaInViewRect(...);
end

function MapCanvasMixin:NormalizeHorizontalSize(size)
	return self.ScrollContainer:NormalizeHorizontalSize(size);
end

function MapCanvasMixin:DenormalizeHorizontalSize(size)
	return self.ScrollContainer:DenormalizeHorizontalSize(size);
end

function MapCanvasMixin:NormalizeVerticalSize(size)
	return self.ScrollContainer:NormalizeVerticalSize(size);
end

function MapCanvasMixin:DenormalizeVerticalSize(size)
	return self.ScrollContainer:DenormalizeVerticalSize(size);
end

function MapCanvasMixin:GetNormalizedCursorPosition()
	return self.ScrollContainer:GetNormalizedCursorPosition()
end

function MapCanvasMixin:IsCanvasMouseFocus()
	return self.ScrollContainer:IsMouseMotionFocus();
end

function MapCanvasMixin:AddLockReason(reason)
	self.lockReasons[reason] = true;
	self:EvaluateLockReasons();
end

function MapCanvasMixin:RemoveLockReason(reason)
	self.lockReasons[reason] = nil;
	self:EvaluateLockReasons();
end

function MapCanvasMixin:EvaluateLockReasons()
	if next(self.lockReasons) then
		self.BorderFrame:EnableMouse(true);
		self.BorderFrame:EnableMouseWheel(true);
		if self.BorderFrame.Underlay then
			self.BorderFrame.Underlay:Show();
		end
	else
		self.BorderFrame:EnableMouse(false);
		self.BorderFrame:EnableMouseWheel(false);
		if self.BorderFrame.Underlay then
			self.BorderFrame.Underlay:Hide();
		end
	end
end

function MapCanvasMixin:GetPinFrameLevelsManager()
	return self.pinFrameLevelsManager;
end

function MapCanvasMixin:ReapplyPinFrameLevels(pinFrameLevelType)
	for pin in self:EnumerateAllPins() do
		if pin:GetFrameLevelType() == pinFrameLevelType then
			pin:ApplyFrameLevel();
		end
	end
end

function MapCanvasMixin:NavigateToParentMap()
	local mapInfo = C_Map.GetMapInfo(self:GetMapID());
	if mapInfo.parentMapID > 0 then
		self:SetMapID(mapInfo.parentMapID);
	end
end

function MapCanvasMixin:NavigateToCursor()
	local normalizedCursorX, normalizedCursorY = self:GetNormalizedCursorPosition();
	local mapInfo = C_Map.GetMapInfoAtPosition(self:GetMapID(), normalizedCursorX, normalizedCursorY);
	if mapInfo then
		self:SetMapID(mapInfo.mapID);
	end
end

-- Add a function that will be checked when the canvas is clicked
-- If the function returns true then handling will stop
-- A priority can optionally be specified, higher priority values will be called first
do
	local function PrioritySorter(left, right)
		return left.priority > right.priority;
	end
	function MapCanvasMixin:AddCanvasClickHandler(handler, priority)
		table.insert(self.mouseClickHandlers, { handler = handler, priority = priority or 0 });
		table.sort(self.mouseClickHandlers, PrioritySorter);
	end
end

function MapCanvasMixin:RemoveCanvasClickHandler(handler, priority)
	for i, handlerInfo in ipairs(self.mouseClickHandlers) do
		if handlerInfo.handler == handler and (not priority or handlerInfo.priority == priority) then
			table.remove(i);
			break;
		end
	end
end

function MapCanvasMixin:ProcessCanvasClickHandlers(button, cursorX, cursorY)
	for i, handlerInfo in ipairs(self.mouseClickHandlers) do
		local success, stopChecking = xpcall(handlerInfo.handler, CallErrorHandler, self, button, cursorX, cursorY);
		if success and stopChecking then
			return true;
		end
	end
	return false;
end

function MapCanvasMixin:GetGlobalPinScale()
	return self.globalPinScale or 1;
end

function MapCanvasMixin:SetGlobalPinScale(scale)
	if self.globalPinScale ~= scale then
		self.globalPinScale = scale;
		for pin in self:EnumerateAllPins() do
			pin:ApplyCurrentScale();
		end
	end
end

function MapCanvasMixin:GetGlobalAlpha()
	return self.globalAlpha or 1;
end

function MapCanvasMixin:SetGlobalAlpha(globalAlpha)
	if self.globalAlpha ~= globalAlpha then
		self.globalAlpha = globalAlpha;
		for detailLayer in self.detailLayerPool:EnumerateActive() do
			detailLayer:SetGlobalAlpha(globalAlpha);
		end
		for dataProvider in pairs(self.dataProviders) do
			dataProvider:OnGlobalAlphaChanged();
		end
	end
end

-- WorldMapFrame as a map canvas ------------------------------------------------------------------------

local map = _G.WorldMapFrame
local canvas = _G.WorldMapButton
local container = _G.WorldMapDetailFrame
if not (map and canvas and container) then
	return
end

-- The scroll container: this client's map does not pan or zoom, so the view is always the whole map.
local Scroll = {}
function Scroll:SetMapID() end
function Scroll:MarkCanvasDirty() end
function Scroll:MarkAreaTriggersDirty() end
function Scroll:OnCanvasSizeChanged() end
function Scroll:AdjustDetailLayerAlpha() end
function Scroll:GetCanvasScale() return 1 end
function Scroll:GetCanvasZoomPercent() return 0 end
function Scroll:IsZoomingIn() return false end
function Scroll:IsZoomingOut() return false end
function Scroll:ZoomIn() end
function Scroll:ZoomOut() end
function Scroll:ResetZoom() end
function Scroll:IsAtMaxZoom() return true end
function Scroll:IsAtMinZoom() return true end
function Scroll:SetPanTarget() end
function Scroll:SetMouseWheelZoomMode() end
function Scroll:SetShouldZoomInOnClick() end
function Scroll:ShouldZoomInOnClick() return false end
function Scroll:SetShouldNavigateOnClick() end
function Scroll:ShouldNavigateOnClick() return false end
function Scroll:SetShouldPanOnClick() end
function Scroll:ShouldPanOnClick() return false end
function Scroll:SetShouldZoomInstantly() end
function Scroll:ShouldZoomInstantly() return true end
function Scroll:GetViewRect() return CreateRectangle(0, 1, 0, 1) end
function Scroll:GetMaxZoomViewRect() return CreateRectangle(0, 1, 0, 1) end
function Scroll:GetMinZoomViewRect() return CreateRectangle(0, 1, 0, 1) end
function Scroll:GetScaleForMaxZoom() return 1 end
function Scroll:GetScaleForMinZoom() return 1 end
function Scroll:CalculateZoomScaleAndPositionForAreaInViewRect() return 1, 0.5, 0.5 end
function Scroll:NormalizeHorizontalSize(size) return size / canvas:GetWidth() end
function Scroll:DenormalizeHorizontalSize(size) return size * canvas:GetWidth() end
function Scroll:NormalizeVerticalSize(size) return size / canvas:GetHeight() end
function Scroll:DenormalizeVerticalSize(size) return size * canvas:GetHeight() end
function Scroll:GetNormalizedCursorPosition()
	local x, y = GetCursorPosition()
	local scale = canvas:GetEffectiveScale()
	local left, top = canvas:GetLeft(), canvas:GetTop()
	if not left then
		return 0.5, 0.5
	end
	return (x / scale - left) / canvas:GetWidth(), (top - y / scale) / canvas:GetHeight()
end
function Scroll:IsMouseMotionFocus() return canvas:IsMouseOver() end
function Scroll:GetCursorPosition()
	local x, y = GetCursorPosition()
	local scale = canvas:GetEffectiveScale()
	return x / scale, y / scale
end
for name, fn in pairs(Scroll) do
	if container[name] == nil then
		container[name] = fn
	end
end
container.Child = canvas
map.ScrollContainer = container

-- The title area: AddOns look for the title among the border frame's regions.
local function borderProxy()
	local frame = CreateFrame("Frame", nil, map)
	frame:SetAllPoints(map)
	frame:EnableMouse(false)
	frame.GetRegions = function() return map:GetRegions() end
	frame.CloseButton = _G.WorldMapFrameCloseButton
	frame.TitleText = _G.WorldMapFrameTitle
	return frame
end
map.BorderFrame = map.BorderFrame or borderProxy()
map.MiniBorderFrame = map.MiniBorderFrame or map.BorderFrame
map.overlayFrames = map.overlayFrames or {}

for name, fn in pairs(MapCanvasMixin) do
	if rawget(map, name) == nil then
		map[name] = fn
	end
end
map.ScrollContainer = container
MapCanvasMixin.OnLoad(map)
map.VisibilityTracker = { state = false }

-- This client draws the map itself; there are no detail layers or locks to manage.
function map:RefreshDetailLayers() end
function map:AreDetailLayersLoaded() return true end
function map:EvaluateLockReasons() end
function map:RefreshOverlayFrames()
	for _, frame in ipairs(self.overlayFrames) do
		if frame.Refresh then
			frame:Refresh()
		end
	end
end

-- Pin frame levels sit above the map's own drawing.
local applyFrameLevel = MapCanvasPinMixin.ApplyFrameLevel
function MapCanvasPinMixin:ApplyFrameLevel()
	local frameLevel = self:GetMap():GetPinFrameLevelsManager():GetValidFrameLevel(self.pinFrameLevelType, self.pinFrameLevelIndex)
	self:SetFrameLevel(canvas:GetFrameLevel() + frameLevel)
end

-- Data provider events arrive through a frame of their own (the map's own handler keeps the client's).
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
	MapCanvasMixin.OnEvent(map, event, ...)
end)
function map:AddDataProviderEvent(event)
	self.dataProviderEventsCount[event] = (self.dataProviderEventsCount[event] or 0) + 1
	events:RegisterEvent(event)
end
function map:RemoveDataProviderEvent(event)
	local count = self.dataProviderEventsCount[event]
	if count then
		count = count - 1
		self.dataProviderEventsCount[event] = count > 0 and count or nil
		if count <= 0 then
			events:UnregisterEvent(event)
		end
	end
end

-- The displayed map, in modern IDs, follows the client's map.
local function currentMapID()
	local legacy = GetCurrentMapAreaID and GetCurrentMapAreaID()
	return legacy and ModernUI_GetUIMapIDFromAreaID and ModernUI_GetUIMapIDFromAreaID(legacy) or nil
end
local function syncMap()
	local mapID = currentMapID()
	if mapID and mapID ~= map.mapID then
		map.mapID = mapID
		map:OnMapChanged()
	end
end
function map:SetMapID(mapID)
	local legacy = ModernUI_GetAreaIDFromUIMapID and ModernUI_GetAreaIDFromUIMapID(mapID)
	if legacy then
		SetMapByID(legacy - 1)
	end
	syncMap()
end
function map:GetMapID()
	return self.mapID or currentMapID() or (C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
end
map.SetCurrentMap = map.SetCurrentMap or map.SetMapID

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("WORLD_MAP_UPDATE")
watcher:SetScript("OnEvent", function()
	if map:IsShown() then
		syncMap()
	end
end)

map:HookScript("OnShow", function(self)
	self.VisibilityTracker.state = true
	syncMap()
	MapCanvasMixin.OnShow(self)
	self:TriggerEvent("WorldMapOnShow")
end)
map:HookScript("OnHide", function(self)
	self.VisibilityTracker.state = false
	MapCanvasMixin.OnHide(self)
	self:TriggerEvent("WorldMapOnHide")
end)
map:HookScript("OnUpdate", function(self)
	self:UpdatePinNudging()
end)

-- The map changes size (full and small modes): pins keep their place on it.
canvas:HookScript("OnSizeChanged", function()
	for pin in map:EnumerateAllPins() do
		if pin.normalizedX and pin.normalizedY then
			map:ApplyPinPosition(pin, pin.normalizedX, pin.normalizedY, pin.insetIndex)
		end
	end
	map:CallMethodOnPinsAndDataProviders("OnCanvasSizeChanged")
end)
