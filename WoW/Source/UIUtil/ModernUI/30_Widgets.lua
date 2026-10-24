-- ModernUI: built into the client (not in the original 3.3.5a).
-- Widget methods modern addons call, added to this client's widget types, plus modern frame types,
-- animation types and game events mapped onto their 3.3.5 equivalents.
-- Methods the client already has are never replaced.

local _G = _G
local type, select, pairs, ipairs, pcall, getmetatable, setmetatable, rawget = type, select, pairs, ipairs, pcall, getmetatable, setmetatable, rawget

local CreateFrame_335 = CreateFrame

-- Collect the method table of every widget type ------------------------------------------------

local methodTables = {}   -- kind -> method table
local seen = {}

local function remember(kind, object)
	local mt = object and getmetatable(object)
	local index = mt and mt.__index
	if type(index) == "table" and not seen[index] then
		seen[index] = kind
		methodTables[kind] = index
	end
end

local host = CreateFrame_335("Frame")
host:Hide()

local frameKinds = {
	"Frame", "Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar", "Cooldown",
	"ColorSelect", "GameTooltip", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "Model",
	"PlayerModel", "DressUpModel", "TabardModel", "MovieFrame", "QuestPOIFrame",
}
for _, kind in ipairs(frameKinds) do
	local ok, object = pcall(CreateFrame_335, kind, nil, host)
	if ok and object then
		if object.Hide then object:Hide() end
		remember(kind, object)
	end
end
if _G.Minimap then remember("Minimap", Minimap) end
if _G.WorldFrame then remember("WorldFrame", WorldFrame) end

remember("Texture", host:CreateTexture())
-- Font objects (CreateFont, GameFontNormal) have a method table of their own.
if _G.CreateFont then remember("Font", CreateFont("ModernUIProbeFont")) end
remember("FontString", host:CreateFontString())

local group = host:CreateAnimationGroup()
remember("AnimationGroup", group)
local animationKinds = { "Animation", "Alpha", "Scale", "Translation", "Rotation", "Path" }
for _, kind in ipairs(animationKinds) do
	local ok, anim = pcall(group.CreateAnimation, group, kind)
	if ok and anim then
		remember(kind, anim)
	end
end

local frameTypes, regionTypes, animTypes = {}, {}, {}
for kind, index in pairs(methodTables) do
	if kind == "Font" then
		-- not a region or a frame: only Font methods
	elseif kind == "Texture" or kind == "FontString" then
		regionTypes[#regionTypes + 1] = index
	elseif kind == "AnimationGroup" or kind == "Animation" or kind == "Alpha" or kind == "Scale" or kind == "Translation" or kind == "Rotation" or kind == "Path" then
		animTypes[#animTypes + 1] = index
	else
		frameTypes[#frameTypes + 1] = index
	end
end

local function add(list, name, fn)
	for _, index in ipairs(list) do
		if rawget(index, name) == nil then
			index[name] = fn
		end
	end
end

local function addTo(kind, name, fn)
	local index = methodTables[kind]
	if index and rawget(index, name) == nil then
		index[name] = fn
	end
end

local function noop() end
local function falseFn() return false end
local function nilFn() return nil end

local allRegions = {}
for _, t in ipairs(frameTypes) do allRegions[#allRegions + 1] = t end
for _, t in ipairs(regionTypes) do allRegions[#allRegions + 1] = t end

-- Per-object state kept outside the object.
local state = setmetatable({}, { __mode = "k" })
local function stateOf(object)
	local s = state[object]
	if not s then
		s = {}
		state[object] = s
	end
	return s
end

-- Every region and frame -----------------------------------------------------------------------

add(allRegions, "SetShown", function(self, shown)
	if shown then self:Show() else self:Hide() end
end)
add(allRegions, "SetSize", function(self, width, height)
	self:SetWidth(width)
	self:SetHeight(height or width)
end)
add(allRegions, "GetSize", function(self) return self:GetWidth(), self:GetHeight() end)
add(allRegions, "SetIgnoreParentAlpha", function(self, ignore) stateOf(self).ignoreParentAlpha = ignore and true or false end)
add(allRegions, "IsIgnoringParentAlpha", function(self) return stateOf(self).ignoreParentAlpha == true end)
add(allRegions, "SetIgnoreParentScale", function(self, ignore) stateOf(self).ignoreParentScale = ignore and true or false end)
add(allRegions, "IsIgnoringParentScale", function(self) return stateOf(self).ignoreParentScale == true end)
add(allRegions, "SetSnapToPixelGrid", noop)
add(allRegions, "IsSnappingToPixelGrid", falseFn)
add(allRegions, "SetTexelSnappingBias", noop)
add(allRegions, "GetTexelSnappingBias", function() return 0 end)
add(allRegions, "IsAnchoringRestricted", falseFn)
add(allRegions, "IsForbidden", falseFn)
add(allRegions, "SetForbidden", noop)
add(allRegions, "IsRectValid", function(self) return self:GetLeft() ~= nil end)
add(allRegions, "GetScaledRect", function(self)
	local left, bottom, width, height = self:GetRect()
	if not left then
		return nil
	end
	local scale = self:GetEffectiveScale()
	return left * scale, bottom * scale, width * scale, height * scale
end)
add(allRegions, "GetDebugName", function(self) return self:GetName() or tostring(self) end)
add(allRegions, "GetPointByName", function(self, name)
	for i = 1, self:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = self:GetPoint(i)
		if point == name then
			return point, relativeTo, relativePoint, x, y
		end
	end
end)
add(allRegions, "ClearPoint", function(self, name)
	local keep = {}
	for i = 1, self:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = self:GetPoint(i)
		if point ~= name then
			keep[#keep + 1] = { point, relativeTo, relativePoint, x, y }
		end
	end
	self:ClearAllPoints()
	for _, p in ipairs(keep) do
		self:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
end)
add(allRegions, "AdjustPointsOffset", function(self, dx, dy)
	local points = {}
	for i = 1, self:GetNumPoints() do
		points[i] = { self:GetPoint(i) }
	end
	self:ClearAllPoints()
	for _, p in ipairs(points) do
		self:SetPoint(p[1], p[2], p[3], (p[4] or 0) + dx, (p[5] or 0) + dy)
	end
end)
add(allRegions, "ClearPointsOffset", function(self)
	local points = {}
	for i = 1, self:GetNumPoints() do
		points[i] = { self:GetPoint(i) }
	end
	self:ClearAllPoints()
	for _, p in ipairs(points) do
		self:SetPoint(p[1], p[2], p[3], 0, 0)
	end
end)
add(allRegions, "SetPassThroughButtons", noop)
add(allRegions, "SetMouseClickEnabled", function(self, enabled)
	if self.EnableMouse and enabled then self:EnableMouse(true) end
end)
add(allRegions, "SetMouseMotionEnabled", function(self, enabled)
	if self.EnableMouse and enabled then self:EnableMouse(true) end
end)
add(allRegions, "IsMouseClickEnabled", function(self) return self.IsMouseEnabled and self:IsMouseEnabled() and true or false end)
add(allRegions, "IsMouseMotionEnabled", function(self) return self.IsMouseEnabled and self:IsMouseEnabled() and true or false end)
add(allRegions, "IsMouseMotionFocus", function(self) return GetMouseFocus() == self end)
add(allRegions, "SetCollapsesLayout", noop)
-- Regions (textures, font strings) take their scale from their frame.
for _, index in ipairs(regionTypes) do
	if rawget(index, "GetEffectiveScale") == nil then
		index.GetEffectiveScale = function(self)
			local parent = self:GetParent()
			return parent and parent:GetEffectiveScale() or UIParent:GetEffectiveScale()
		end
	end
	if rawget(index, "GetScale") == nil then
		index.GetScale = function() return 1 end
	end
end
add(allRegions, "SetDrawLayerEnabled", noop)

-- Frames ------------------------------------------------------------------------------------------

add(frameTypes, "SetFixedFrameStrata", function(self, fixed) stateOf(self).fixedStrata = fixed and true or false end)
add(frameTypes, "HasFixedFrameStrata", function(self) return stateOf(self).fixedStrata == true end)
add(frameTypes, "SetFixedFrameLevel", function(self, fixed) stateOf(self).fixedLevel = fixed and true or false end)
add(frameTypes, "HasFixedFrameLevel", function(self) return stateOf(self).fixedLevel == true end)
add(frameTypes, "SetClipsChildren", function(self, clips) stateOf(self).clipsChildren = clips and true or false end)
add(frameTypes, "DoesClipChildren", function(self) return stateOf(self).clipsChildren == true end)
add(frameTypes, "SetFlattensRenderLayers", noop)
add(frameTypes, "GetFlattensRenderLayers", falseFn)
add(frameTypes, "SetIsFrameBuffer", noop)
add(frameTypes, "SetUsingParentLevel", noop)
add(frameTypes, "IsUsingParentLevel", falseFn)
add(frameTypes, "SetPropagateKeyboardInput", function(self, propagate) stateOf(self).propagateKeyboard = propagate end)
add(frameTypes, "GetPropagateKeyboardInput", function(self) return stateOf(self).propagateKeyboard and true or false end)
add(frameTypes, "SetPropagateMouseClicks", noop)
add(frameTypes, "SetPropagateMouseMotion", noop)
add(frameTypes, "EnableMouseMotion", function(self, enabled)
	if enabled then self:EnableMouse(true) end
end)
add(frameTypes, "SetResizeBounds", function(self, minWidth, minHeight, maxWidth, maxHeight)
	if self.SetMinResize then self:SetMinResize(minWidth or 0, minHeight or 0) end
	if self.SetMaxResize and maxWidth and maxHeight then self:SetMaxResize(maxWidth, maxHeight) end
end)
add(frameTypes, "GetResizeBounds", function(self)
	local minW, minH = 0, 0
	local maxW, maxH = 0, 0
	if self.GetMinResize then minW, minH = self:GetMinResize() end
	if self.GetMaxResize then maxW, maxH = self:GetMaxResize() end
	return minW, minH, maxW, maxH
end)
add(frameTypes, "SetEnabled", function(self, enabled)
	if self.Enable then
		if enabled then self:Enable() else self:Disable() end
	end
end)
add(frameTypes, "CanChangeAttribute", function() return not InCombatLockdown() end)
add(frameTypes, "SetAttributeNoHandler", function(self, name, value) self:SetAttribute(name, value) end)
add(frameTypes, "SetHighlightLocked", function(self, locked)
	if locked then
		if self.LockHighlight then self:LockHighlight() end
	elseif self.UnlockHighlight then
		self:UnlockHighlight()
	end
end)
add(frameTypes, "GetWindow", nilFn)
add(frameTypes, "SetWindow", noop)
add(frameTypes, "CreateMaskTexture", function(self, name, layer)
	local texture = self:CreateTexture(name, layer)
	texture:Hide()
	return texture
end)
add(frameTypes, "CreateLine", function(self, name, layer, template, subLevel)
	return self:CreateTexture(name, layer, template)
end)
add(frameTypes, "SetForbidden", noop)
add(frameTypes, "IsForbidden", falseFn)
add(frameTypes, "GetRaisedFrameLevel", function(self) return self:GetFrameLevel() end)
add(frameTypes, "Raise", function(self) self:SetFrameLevel(self:GetFrameLevel() + 1) end)
add(frameTypes, "Lower", function(self) self:SetFrameLevel(math.max(0, self:GetFrameLevel() - 1)) end)

-- Textures ----------------------------------------------------------------------------------------

addTo("Texture", "SetColorTexture", function(self, r, g, b, a)
	self:SetTexture(r, g, b, a or 1)
end)
-- This client has no atlas data. Atlases with a counterpart among this client's own textures are drawn
-- with it (ModernUI_AtlasFallback: file, width, height, left, right, top, bottom); others leave the
-- texture empty instead of raising an error.
local atlasFallback = {
	Options_Tab_Left = { "Interface\\ChatFrame\\ChatFrameTab-BGLeft", 16, 32 },
	Options_Tab_Middle = { "Interface\\ChatFrame\\ChatFrameTab-BGMid", 44, 32 },
	Options_Tab_Right = { "Interface\\ChatFrame\\ChatFrameTab-BGRight", 16, 32 },
	Options_Tab_Active_Left = { "Interface\\ChatFrame\\ChatFrameTab-SelectedLeft", 16, 32 },
	Options_Tab_Active_Middle = { "Interface\\ChatFrame\\ChatFrameTab-SelectedMid", 44, 32 },
	Options_Tab_Active_Right = { "Interface\\ChatFrame\\ChatFrameTab-SelectedRight", 16, 32 },
	NPE_LeftClick = { "Interface\\TutorialFrame\\UI-TUTORIAL-FRAME", 76, 101, 0.0019531, 0.1484375, 0.4257813, 0.6210938 },
	NPE_RightClick = { "Interface\\TutorialFrame\\UI-TUTORIAL-FRAME", 76, 101, 0.0019531, 0.1484375, 0.6269531, 0.8222656 },
	["newplayertutorial-icon-mouse-leftbutton"] = { "Interface\\TutorialFrame\\UI-TUTORIAL-FRAME", 76, 101, 0.0019531, 0.1484375, 0.4257813, 0.6210938 },
	["newplayertutorial-icon-mouse-rightbutton"] = { "Interface\\TutorialFrame\\UI-TUTORIAL-FRAME", 76, 101, 0.0019531, 0.1484375, 0.6269531, 0.8222656 },
	["newplayertutorial-icon-mouse-middlebutton"] = { "Interface\\TutorialFrame\\UI-TUTORIAL-FRAME", 76, 101, 0.0019531, 0.1484375, 0.2246094, 0.4199219 },
	["editmode-new-layout-plus"] = { "Interface\\Buttons\\UI-PlusButton-Up", 16, 16 },
	["communities-icon-addchannelplus"] = { "Interface\\Buttons\\UI-PlusButton-Up", 16, 16 },
}
_G.ModernUI_AtlasFallback = _G.ModernUI_AtlasFallback or atlasFallback
-- Text markup (|A:name|a) draws the same textures; the client's text renderer learns them here.
if ModernUI_RegisterAtlas then
	for name, entry in pairs(_G.ModernUI_AtlasFallback) do
		ModernUI_RegisterAtlas(name, entry[1], entry[2], entry[3], entry[4] or 0, entry[5] or 1, entry[6] or 0, entry[7] or 1)
	end
end
addTo("Texture", "SetAtlas", function(self, atlas, useAtlasSize)
	stateOf(self).atlas = atlas
	local entry = atlas and _G.ModernUI_AtlasFallback[atlas]
	if not entry and atlas and ModernUI_GetAtlasInfo then
		local file, width, height, left, right, top, bottom = ModernUI_GetAtlasInfo(atlas)
		if file then
			entry = { file, width, height, left, right, top, bottom }
		end
	end
	if not entry then
		return false
	end
	self:SetTexture(entry[1])
	self:SetTexCoord(entry[4] or 0, entry[5] or 1, entry[6] or 0, entry[7] or 1)
	if useAtlasSize and entry[2] then
		self:SetWidth(entry[2])
		self:SetHeight(entry[3])
	end
	return true
end)
addTo("Texture", "GetAtlas", function(self) return stateOf(self).atlas end)
-- Masks: the client composes a masked texture's image with its masks' alpha (Frame/ModernUIMask.cpp).
local function masksOf(self)
	local state = stateOf(self)
	state.masks = state.masks or {}
	return state.masks
end
addTo("Texture", "AddMaskTexture", function(self, mask)
	if type(mask) ~= "table" or mask == self then return end
	local masks = masksOf(self)
	for _, existing in ipairs(masks) do
		if existing == mask then return end
	end
	masks[#masks + 1] = mask
	if ModernUI_AddMaskTexture then ModernUI_AddMaskTexture(self, mask) end
end)
addTo("Texture", "RemoveMaskTexture", function(self, mask)
	local masks = masksOf(self)
	for i, existing in ipairs(masks) do
		if existing == mask then
			table.remove(masks, i)
			break
		end
	end
	if ModernUI_RemoveMaskTexture then ModernUI_RemoveMaskTexture(self, mask) end
end)
addTo("Texture", "GetNumMaskTextures", function(self) return #masksOf(self) end)
addTo("Texture", "GetMaskTexture", function(self, index) return masksOf(self)[index] end)
-- SetMask(file): one mask of that image covering the texture; nil or "" removes it.
addTo("Texture", "SetMask", function(self, file)
	local state = stateOf(self)
	if state.fileMask then
		self:RemoveMaskTexture(state.fileMask)
	end
	if not file or file == "" then return end
	local parent = self:GetParent()
	if not parent or not parent.CreateMaskTexture then return end
	local mask = state.fileMask or parent:CreateMaskTexture()
	state.fileMask = mask
	mask:SetTexture(file)
	mask:ClearAllPoints()
	mask:SetAllPoints(self)
	self:AddMaskTexture(mask)
end)
addTo("Texture", "SetVertexOffset", noop)
addTo("Texture", "SetTextureSliceMargins", noop)
addTo("Texture", "SetTextureSliceMode", noop)
addTo("Texture", "ClearTextureSlice", noop)
addTo("Texture", "SetDesaturation", function(self, amount) self:SetDesaturated(amount and amount > 0) end)
addTo("Texture", "GetDesaturation", function(self) return self:IsDesaturated() and 1 or 0 end)
addTo("Texture", "SetBlockingLoadsRequested", noop)
addTo("Texture", "IsBlockingLoadRequested", falseFn)
addTo("Texture", "SetStartPoint", noop)
addTo("Texture", "SetEndPoint", noop)
addTo("Texture", "SetThickness", noop)

-- Font strings ------------------------------------------------------------------------------------

addTo("FontString", "SetMaxLines", noop)
addTo("FontString", "GetMaxLines", function() return 0 end)
addTo("FontString", "SetTextScale", noop)
addTo("FontString", "GetTextScale", function() return 1 end)
addTo("FontString", "SetRotation", noop)
addTo("FontString", "GetRotation", function() return 0 end)
addTo("FontString", "GetUnboundedStringWidth", function(self) return self:GetStringWidth() end)
addTo("FontString", "GetWrappedWidth", function(self)
	local width, limit = self:GetStringWidth() or 0, self:GetWidth() or 0
	if limit > 0 and width > limit then
		return limit
	end
	return width
end)
addTo("FontString", "GetLineHeight", function(self)
	local _, height = self:GetFont()
	return height or 12
end)
addTo("FontString", "IsTruncated", function(self) return self:GetStringWidth() > self:GetWidth() + 0.5 end)
addTo("FontString", "GetNumLines", function(self)
	local _, height = self:GetFont()
	return math.max(1, math.floor(self:GetStringHeight() / (height or 12) + 0.5))
end)
addTo("FontString", "SetWordWrap", noop)
addTo("FontString", "CanWordWrap", function() return true end)
addTo("FontString", "CanNonSpaceWrap", falseFn)
-- Modern fonts hold a font per alphabet; this client has one font for all, so every alphabet answers with the
-- font object itself.
addTo("Font", "GetFontObjectForAlphabet", function(self) return self end)
addTo("Font", "SetFontObjectsToTry", function(self, font) if font and font.GetFont then self:SetFontObject(font) end end)
addTo("FontString", "SetFontObjectsToTry", function(self, font) if font then self:SetFontObject(font) end end)
addTo("FontString", "SetResizeToFitBounds", noop)
addTo("FontString", "SetAutoFit", noop)

-- Status bars, cooldowns, sliders, buttons, edit boxes, models ------------------------------------

addTo("StatusBar", "SetFillStyle", noop)
addTo("StatusBar", "SetReverseFill", noop)
addTo("StatusBar", "GetReverseFill", falseFn)
addTo("StatusBar", "SetColorFill", function(self, r, g, b, a) self:SetStatusBarColor(r, g, b, a) end)
addTo("StatusBar", "SetStatusBarDesaturated", noop)
addTo("StatusBar", "SetStatusBarAtlas", noop)
addTo("StatusBar", "SetTimerDuration", noop)

for _, name in ipairs({
	"SetSwipeColor", "SetDrawSwipe", "SetDrawBling", "SetHideCountdownNumbers", "SetCountdownFont",
	"SetSwipeTexture", "SetEdgeTexture", "SetBlingTexture", "SetUseCircularEdge", "SetEdgeScale",
	"SetUseAuraDisplayTime", "SetMinimumCountdownDuration", "SetCountdownAbbrevThreshold", "SetTexCoordRange",
	"SetRotation", "SetCountdownColor",
}) do
	addTo("Cooldown", name, noop)
end
addTo("Cooldown", "Clear", function(self) self:SetCooldown(0, 0) end)
addTo("Cooldown", "SetCooldownDuration", function(self, duration) self:SetCooldown(GetTime(), duration) end)
addTo("Cooldown", "SetCooldownUNIX", function(self, start, duration) self:SetCooldown(GetTime() - (time() - start), duration) end)
addTo("Cooldown", "GetCooldownTimes", function(self)
	local s = stateOf(self)
	return (s.start or 0) * 1000, (s.duration or 0) * 1000
end)
addTo("Cooldown", "GetCooldownDuration", function(self) return (stateOf(self).duration or 0) * 1000 end)
addTo("Cooldown", "IsPaused", falseFn)
addTo("Cooldown", "Pause", noop)
addTo("Cooldown", "Resume", noop)
addTo("Cooldown", "GetDrawSwipe", function() return true end)
addTo("Cooldown", "GetDrawEdge", falseFn)
addTo("Cooldown", "GetDrawBling", falseFn)
addTo("Cooldown", "GetReverse", falseFn)
do
	local index = methodTables.Cooldown
	local SetCooldown = index and index.SetCooldown
	if SetCooldown then
		index.SetCooldown = function(self, start, duration, modRate)
			local s = stateOf(self)
			s.start, s.duration = start, duration
			return SetCooldown(self, start, duration)
		end
	end
end

addTo("Slider", "SetObeyStepOnDrag", noop)
addTo("Slider", "GetObeyStepOnDrag", falseFn)
addTo("Slider", "SetStepsPerPage", noop)
addTo("Slider", "GetStepsPerPage", function() return 1 end)

for _, kind in ipairs({ "Button", "CheckButton" }) do
	addTo(kind, "SetNormalAtlas", noop)
	addTo(kind, "SetPushedAtlas", noop)
	addTo(kind, "SetDisabledAtlas", noop)
	addTo(kind, "SetHighlightAtlas", noop)
	addTo(kind, "SetCheckedAtlas", noop)
	addTo(kind, "ClearNormalTexture", function(self) local t = self:GetNormalTexture() if t then t:SetTexture(nil) end end)
	addTo(kind, "ClearPushedTexture", function(self) local t = self:GetPushedTexture() if t then t:SetTexture(nil) end end)
	addTo(kind, "ClearDisabledTexture", function(self) local t = self:GetDisabledTexture() if t then t:SetTexture(nil) end end)
	addTo(kind, "ClearHighlightTexture", function(self) local t = self:GetHighlightTexture() if t then t:SetTexture(nil) end end)
	addTo(kind, "RegisterForMouse", noop)
end

addTo("EditBox", "SetCountInvisibleLetters", noop)
addTo("EditBox", "SetVisibleTextByteLimit", noop)
addTo("EditBox", "GetDisplayText", function(self) return self:GetText() end)
addTo("EditBox", "SetEnabled", function(self, enabled) self:EnableMouse(enabled) self:EnableKeyboard(enabled) end)
addTo("EditBox", "IsEnabled", function(self) return self:IsMouseEnabled() and true or false end)
addTo("EditBox", "SetSecureText", function(self, text) self:SetText(text) end)

for _, kind in ipairs({ "Model", "PlayerModel", "DressUpModel", "TabardModel" }) do
	addTo(kind, "SetKeepModelOnHide", noop)
	addTo(kind, "MakeCurrentCameraCustom", noop)
	addTo(kind, "SetModelAlpha", function(self, alpha) self:SetAlpha(alpha) end)
	addTo(kind, "ClearTransform", noop)
	addTo(kind, "SetTransform", noop)
	addTo(kind, "SetAnimation", function(self, animation) if self.SetSequence then self:SetSequence(animation) end end)
	addTo(kind, "SetPortraitZoom", noop)
	addTo(kind, "SetCamDistanceScale", noop)
	addTo(kind, "SetViewTranslation", noop)
	addTo(kind, "SetDesaturation", noop)
	addTo(kind, "SetPaused", noop)
	addTo(kind, "FreezeAnimation", noop)
	addTo(kind, "SetItemAppearance", noop)
	addTo(kind, "SetDisplayInfo", function(self, displayID) if self.SetCreature then self:SetCreature(displayID) end end)
	addTo(kind, "SetUseTransmogSkin", noop)
	addTo(kind, "SetUseTransmogChoices", noop)
	addTo(kind, "SetObeyHideInTransmogFlag", noop)
	addTo(kind, "SetSheathed", noop)
	addTo(kind, "SetDoBlend", noop)
	addTo(kind, "SetAutoDress", noop)
	addTo(kind, "SetBarberShopAlternateForm", noop)
	addTo(kind, "SetAnimationBlendOperation", noop)
	addTo(kind, "SetParticlesEnabled", noop)
	addTo(kind, "GetDisplayInfo", function() return 0 end)
	addTo(kind, "HasAnimation", function() return true end)
	addTo(kind, "IsUsingModelCenterToTransform", falseFn)
	addTo(kind, "UseModelCenterToTransform", noop)
end

addTo("GameTooltip", "SetPadding", noop)
addTo("GameTooltip", "SetAllowShowWithNoLines", noop)
addTo("GameTooltip", "IsTooltipType", falseFn)
addTo("GameTooltip", "GetPrimaryTooltipData", nilFn)
addTo("GameTooltip", "GetTooltipData", nilFn)
addTo("GameTooltip", "ProcessInfo", falseFn)
addTo("GameTooltip", "SetItemByID", function(self, itemID) self:SetHyperlink("item:" .. itemID) end)
addTo("GameTooltip", "SetSpellByID", function(self, spellID) self:SetHyperlink("spell:" .. spellID) end)
addTo("GameTooltip", "SetUnitBuffByAuraInstanceID", noop)
addTo("GameTooltip", "SetUnitDebuffByAuraInstanceID", noop)
addTo("GameTooltip", "SetUnitAuraByAuraInstanceID", noop)
addTo("GameTooltip", "SetCurrencyByID", noop)

-- Animations -----------------------------------------------------------------------------------

addTo("AnimationGroup", "SetToFinalAlpha", noop)
addTo("AnimationGroup", "IsSetToFinalAlpha", falseFn)
addTo("AnimationGroup", "SetPlaying", function(self, playing) if playing then self:Play() else self:Stop() end end)
addTo("AnimationGroup", "Restart", function(self) self:Stop() self:Play() end)
addTo("AnimationGroup", "PlaySynced", function(self) self:Play() end)
addTo("AnimationGroup", "RemoveAnimations", noop)
addTo("AnimationGroup", "GetAnimationSpeedMultiplier", function() return 1 end)
addTo("AnimationGroup", "SetAnimationSpeedMultiplier", noop)

-- Animation types added after 3.3.5 are created as plain animations that do nothing visible.
do
	local index = methodTables.AnimationGroup
	local CreateAnimation = index and index.CreateAnimation
	-- Type names are matched without regard to case, as the client does ("TRANSLATION" is Translation).
	local known = { animation = "Animation", alpha = "Alpha", scale = "Scale", translation = "Translation",
		rotation = "Rotation", path = "Path" }
	if CreateAnimation then
		index.CreateAnimation = function(self, kind, name, inherits)
			if type(kind) == "string" then
				kind = known[kind:lower()] or "Animation"
			end
			return CreateAnimation(self, kind, name, inherits)
		end
	end
end

-- Alpha animations: modern code gives start and end alpha; 3.3.5 takes the change between them.
do
	local function applyAlpha(self)
		local s = stateOf(self)
		self:SetChange((s.toAlpha or 1) - (s.fromAlpha or 0))
	end
	addTo("Alpha", "SetFromAlpha", function(self, alpha) stateOf(self).fromAlpha = alpha applyAlpha(self) end)
	addTo("Alpha", "SetToAlpha", function(self, alpha) stateOf(self).toAlpha = alpha applyAlpha(self) end)
	addTo("Alpha", "GetFromAlpha", function(self) return stateOf(self).fromAlpha or 0 end)
	addTo("Alpha", "GetToAlpha", function(self) return stateOf(self).toAlpha or 1 end)

	local function applyScale(self)
		local s = stateOf(self)
		local fx, fy = s.fromX or 1, s.fromY or 1
		local tx, ty = s.toX or 1, s.toY or 1
		self:SetScale(fx ~= 0 and tx / fx or tx, fy ~= 0 and ty / fy or ty)
	end
	local function fromScale(self, x, y) local s = stateOf(self) s.fromX, s.fromY = x, y or x applyScale(self) end
	local function toScale(self, x, y) local s = stateOf(self) s.toX, s.toY = x, y or x applyScale(self) end
	addTo("Scale", "SetScaleFrom", fromScale)
	addTo("Scale", "SetScaleTo", toScale)
	addTo("Scale", "SetFromScale", fromScale)
	addTo("Scale", "SetToScale", toScale)
end

add(animTypes, "SetTarget", noop)
add(animTypes, "SetTargetKey", noop)
add(animTypes, "SetChildKey", noop)
add(animTypes, "SetTargetName", noop)
add(animTypes, "SetTargetParent", noop)
add(animTypes, "GetTarget", function(self) return self:GetRegionParent() end)
add(animTypes, "SetFlipBookRows", noop)
add(animTypes, "SetFlipBookColumns", noop)
add(animTypes, "SetFlipBookFrames", noop)
add(animTypes, "SetFlipBookFrameWidth", noop)
add(animTypes, "SetFlipBookFrameHeight", noop)
add(animTypes, "SetStartColor", noop)
add(animTypes, "SetEndColor", noop)
add(animTypes, "SetScaleFrom", noop)
add(animTypes, "SetScaleTo", noop)
add(animTypes, "SetFromScale", noop)
add(animTypes, "SetToScale", noop)
add(animTypes, "SetFromAlpha", noop)
add(animTypes, "SetToAlpha", noop)

-- Modern frame types created as their nearest 3.3.5 type ------------------------------------------

local frameTypeAliases = {
	EventFrame = "Frame", DropdownButton = "Button", DropDownToggleButton = "Button",
	ModelScene = "Frame", CinematicModel = "PlayerModel", ContainedAlertFrame = "Button",
	ItemButton = "Button", UnitPositionFrame = "Frame", OffScreenFrame = "Frame", FogOfWarFrame = "Frame",
	ScenarioPOIFrame = "Frame", Checkout = "Frame", Browser = "Frame", ArchaeologyDigSiteFrame = "Frame",
	ScrollBox = "Frame", ScrollBar = "Frame", MinimalScrollBar = "Frame",
}

-- Templates this client provides natively (backdrops are built into every 3.3.5 frame) are taken out of
-- the template list, so CreateFrame does not warn that it cannot find them.
local nativeTemplates = { BackdropTemplate = "BackdropTemplateMixin" }
local function stripTemplates(template)
	if type(template) ~= "string" then
		return template, nil
	end
	local keep, mixins = {}, nil
	for name in template:gmatch("[^,%s]+") do
		if nativeTemplates[name] then
			mixins = mixins or {}
			mixins[#mixins + 1] = nativeTemplates[name]
		else
			keep[#keep + 1] = name
		end
	end
	return #keep > 0 and table.concat(keep, ",") or nil, mixins
end

_G.CreateFrame = function(frameType, name, parent, template, id)
	local alias = type(frameType) == "string" and frameTypeAliases[frameType]
	local mixins
	template, mixins = stripTemplates(template)
	local frame = CreateFrame_335(alias or frameType, name, parent, template, id)
	if alias == "Frame" and frameType == "EventFrame" and frame then
		Mixin(frame, CallbackRegistryMixin)
		frame:OnLoad()
		frame:SetUndefinedEventsAllowed(true)
		frame:HookScript("OnShow", function(self) self:TriggerEvent("OnShow") end)
		frame:HookScript("OnHide", function(self) self:TriggerEvent("OnHide") end)
	end
	if mixins and frame then
		for _, mixinName in ipairs(mixins) do
			local mixin = _G[mixinName]
			if mixin then
				for k, v in pairs(mixin) do
					if frame[k] == nil then
						frame[k] = v
					end
				end
				if frame.OnBackdropLoaded then
					frame:OnBackdropLoaded()
				end
			end
		end
	end
	return frame
end

-- Blizzard frames some libraries read widget types from, missing in 3.3.5. Hidden and unused otherwise.
if _G.ChatFrameChannelButton == nil then
	CreateFrame_335("Button", "ChatFrameChannelButton", nil):Hide()
end
if _G.AddonListForceLoad == nil and _G.AddonList == nil then
	CreateFrame_335("CheckButton", "AddonListForceLoad", nil):Hide()
end

-- Game events ---------------------------------------------------------------------------------------
-- Modern event names are mapped onto the 3.3.5 events that carry the same news, and the handler
-- sees the modern name and arguments. Events this client never sends are accepted quietly.

local powerTokens = {
	UNIT_MANA = "MANA", UNIT_RAGE = "RAGE", UNIT_ENERGY = "ENERGY", UNIT_FOCUS = "FOCUS",
	UNIT_RUNIC_POWER = "RUNIC_POWER", UNIT_HAPPINESS = "HAPPINESS",
}
local maxPowerTokens = {
	UNIT_MAXMANA = "MANA", UNIT_MAXRAGE = "RAGE", UNIT_MAXENERGY = "ENERGY", UNIT_MAXFOCUS = "FOCUS",
	UNIT_MAXRUNIC_POWER = "RUNIC_POWER", UNIT_MAXHAPPINESS = "HAPPINESS",
}
local interactionShow = {
	GOSSIP_SHOW = 3, QUEST_GREETING = 4, QUEST_DETAIL = 4, QUEST_PROGRESS = 4, QUEST_COMPLETE = 4,
	MERCHANT_SHOW = 5, TAXIMAP_OPENED = 6, TRAINER_SHOW = 7, BANKFRAME_OPENED = 8, GUILDBANKFRAME_OPENED = 10,
	MAIL_SHOW = 17, AUCTION_HOUSE_SHOW = 21,
}
local interactionHide = {
	GOSSIP_CLOSED = 3, QUEST_FINISHED = 4, MERCHANT_CLOSED = 5, TAXIMAP_CLOSED = 6, TRAINER_CLOSED = 7,
	BANKFRAME_CLOSED = 8, GUILDBANKFRAME_CLOSED = 10, MAIL_CLOSED = 17, AUCTION_HOUSE_CLOSED = 21,
}

-- modern event -> list of { 3.3.5 event, translate(args...) -> modern args }
local eventMap = {}
local function map(modern, old, translate)
	eventMap[modern] = eventMap[modern] or {}
	table.insert(eventMap[modern], { old, translate })
end

for old, token in pairs(powerTokens) do
	map("UNIT_POWER_UPDATE", old, function(unit) return unit, token end)
	map("UNIT_POWER_FREQUENT", old, function(unit) return unit, token end)
end
for old, token in pairs(maxPowerTokens) do
	map("UNIT_MAXPOWER", old, function(unit) return unit, token end)
end
map("GROUP_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED")
map("GROUP_ROSTER_UPDATE", "RAID_ROSTER_UPDATE")
map("GROUP_JOINED", "PARTY_MEMBERS_CHANGED")
map("PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", function() return "player" end)
map("PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE", function() return "player" end)
map("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", function() return end)
map("TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", function() return 0 end)
map("BAG_UPDATE_DELAYED", "BAG_UPDATE", function() return end)
map("PLAYER_LEVEL_CHANGED", "PLAYER_LEVEL_UP", function(level) return level - 1, level end)
map("PLAYER_MOUNT_DISPLAY_CHANGED", "COMPANION_UPDATE", function() return end)
map("LOADING_SCREEN_DISABLED", "PLAYER_ENTERING_WORLD", function() return end)
for old, kind in pairs(interactionShow) do
	map("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", old, function() return kind end)
end
for old, kind in pairs(interactionHide) do
	map("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", old, function() return kind end)
end

-- Frames that use mapped or unit-filtered events get their OnEvent handler wrapped.
local wrapped = setmetatable({}, { __mode = "k" })

local function deliver(frame, info, event, ...)
	local handler = info.handler
	if not handler then
		return
	end
	local translations = info.byOldEvent[event]
	if translations then
		for modern, translate in pairs(translations) do
			local filter = info.unitFilter[modern]
			if translate then
				if not filter or filter[(translate(...))] then
					handler(frame, modern, translate(...))
				end
			elseif not filter or filter[(...)] then
				handler(frame, modern, ...)
			end
		end
		if not info.direct[event] then
			return
		end
	end
	local filter = info.unitFilter[event]
	if filter and not filter[(...)] then
		return
	end
	return handler(frame, event, ...)
end

local function wrap(frame)
	local info = wrapped[frame]
	if info then
		return info
	end
	local index = getmetatable(frame).__index
	local SetScript, GetScript = index.SetScript, index.GetScript
	info = { byOldEvent = {}, unitFilter = {}, direct = {}, handler = GetScript(frame, "OnEvent") }
	wrapped[frame] = info
	local function onEvent(self, event, ...)
		return deliver(self, info, event, ...)
	end
	SetScript(frame, "OnEvent", onEvent)
	frame.SetScript = function(self, script, func)
		if script == "OnEvent" then
			info.handler = func
			return SetScript(self, script, func and onEvent or nil)
		end
		return SetScript(self, script, func)
	end
	frame.GetScript = function(self, script)
		if script == "OnEvent" then
			return info.handler
		end
		return GetScript(self, script)
	end
	return info
end

for _, index in ipairs(frameTypes) do
	local RegisterEvent, UnregisterEvent, UnregisterAllEvents = rawget(index, "RegisterEvent"), rawget(index, "UnregisterEvent"), rawget(index, "UnregisterAllEvents")
	if RegisterEvent then
		local function register(self, event)
			local ok, known = pcall(RegisterEvent, self, event)
			known = ok and known ~= false
			if known then
				local info = wrapped[self]
				if info then
					info.direct[event] = true
				end
				return true
			end
			local mapped = eventMap[event]
			if mapped then
				local info = wrap(self)
				for _, entry in ipairs(mapped) do
					local old, translate = entry[1], entry[2]
					info.byOldEvent[old] = info.byOldEvent[old] or {}
					info.byOldEvent[old][event] = translate or false
					pcall(RegisterEvent, self, old)
				end
				return true
			end
			return false
		end

		index.RegisterEvent = function(self, event)
			local info = wrapped[self]
			if info then
				info.unitFilter[event] = nil
			end
			return register(self, event)
		end

		index.RegisterUnitEvent = function(self, event, ...)
			local info = wrap(self)
			local count = select("#", ...)
			if count > 0 then
				local filter = {}
				for i = 1, count do
					local unit = select(i, ...)
					if unit then
						filter[unit] = true
					end
				end
				info.unitFilter[event] = filter
			else
				info.unitFilter[event] = nil
			end
			return register(self, event)
		end

		index.UnregisterEvent = function(self, event)
			local info = wrapped[self]
			if info then
				info.unitFilter[event] = nil
				info.direct[event] = nil
				local mapped = eventMap[event]
				if mapped then
					for _, entry in ipairs(mapped) do
						local list = info.byOldEvent[entry[1]]
						if list then
							list[event] = nil
							if not next(list) and not info.direct[entry[1]] then
								info.byOldEvent[entry[1]] = nil
								pcall(UnregisterEvent, self, entry[1])
							end
						end
					end
				end
			end
			return (pcall(UnregisterEvent, self, event))
		end

		if UnregisterAllEvents then
			index.UnregisterAllEvents = function(self)
				local info = wrapped[self]
				if info then
					info.byOldEvent, info.unitFilter, info.direct = {}, {}, {}
				end
				return UnregisterAllEvents(self)
			end
		end

		if rawget(index, "IsEventRegistered") == nil then
			index.IsEventRegistered = function(self, event)
				local info = wrapped[self]
				if info and (info.direct[event] or info.unitFilter[event]) then
					return true
				end
				return false
			end
		end
	end
end

-- Backdrops: 3.3.5 frames draw backdrops natively, so the modern backdrop mixin only needs the
-- helper methods; SetBackdrop itself stays the client's own.
if _G.BackdropTemplateMixin == nil then
	_G.BackdropTemplateMixin = {
		OnBackdropLoaded = function(self)
			if self.backdropInfo then
				self:SetBackdrop(self.backdropInfo)
			end
		end,
		OnBackdropSizeChanged = noop,
		ApplyBackdrop = function(self)
			if self.backdropInfo then
				self:SetBackdrop(self.backdropInfo)
			end
		end,
		ClearBackdrop = function(self) self:SetBackdrop(nil) end,
		HasBackdropInfo = function(self, info) return self.backdropInfo == info end,
		GetEdgeSize = function(self) return self.backdropInfo and self.backdropInfo.edgeSize or 0 end,
		SetupTextureCoordinates = noop,
		SetBorderBlendMode = noop,
	}
end

if _G.TooltipBackdropTemplateMixin == nil then
	_G.TooltipBackdropTemplateMixin = CreateFromMixins(BackdropTemplateMixin)
end

local function backdrop(bg, edge, tile, tileSize, edgeSize, inset)
	return {
		bgFile = bg, edgeFile = edge, tile = tile, tileEdge = true, tileSize = tileSize, edgeSize = edgeSize,
		insets = { left = inset, right = inset, top = inset, bottom = inset },
	}
end
_G.BACKDROP_TOOLTIP_16_16_5555 = _G.BACKDROP_TOOLTIP_16_16_5555 or backdrop("Interface\\Tooltips\\UI-Tooltip-Background", "Interface\\Tooltips\\UI-Tooltip-Border", true, 16, 16, 5)
_G.BACKDROP_TOOLTIP_0_16_5555 = _G.BACKDROP_TOOLTIP_0_16_5555 or backdrop("Interface\\Tooltips\\UI-Tooltip-Background", "Interface\\Tooltips\\UI-Tooltip-Border", true, 0, 16, 5)
_G.BACKDROP_DIALOG_32_32 = _G.BACKDROP_DIALOG_32_32 or backdrop("Interface\\DialogFrame\\UI-DialogBox-Background", "Interface\\DialogFrame\\UI-DialogBox-Border", true, 32, 32, 11)
_G.BACKDROP_DARK_DIALOG_32_32 = _G.BACKDROP_DARK_DIALOG_32_32 or backdrop("Interface\\DialogFrame\\UI-DialogBox-Background-Dark", "Interface\\DialogFrame\\UI-DialogBox-Border", true, 32, 32, 11)
_G.BACKDROP_DIALOG_EDGE_32 = _G.BACKDROP_DIALOG_EDGE_32 or backdrop(nil, "Interface\\DialogFrame\\UI-DialogBox-Border", true, 32, 32, 11)
_G.BACKDROP_TEXT_PANEL_0_16 = _G.BACKDROP_TEXT_PANEL_0_16 or backdrop(nil, "Interface\\Tooltips\\UI-Tooltip-Border", true, 0, 16, 5)
_G.BACKDROP_TUTORIAL_16_16 = _G.BACKDROP_TUTORIAL_16_16 or backdrop("Interface\\TutorialFrame\\TutorialFrameBackground", "Interface\\Tooltips\\UI-Tooltip-Border", true, 16, 16, 3)
_G.BACKDROP_SLIDER_8_8 = _G.BACKDROP_SLIDER_8_8 or backdrop("Interface\\Buttons\\UI-SliderBar-Background", "Interface\\Buttons\\UI-SliderBar-Border", true, 8, 8, 3)
_G.BACKDROP_GOLD_DIALOG_32_32 = _G.BACKDROP_GOLD_DIALOG_32_32 or backdrop("Interface\\DialogFrame\\UI-DialogBox-Background", "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", true, 32, 32, 11)
_G.BACKDROP_WATERMARK_DIALOG_0_16 = _G.BACKDROP_WATERMARK_DIALOG_0_16 or backdrop(nil, "Interface\\DialogFrame\\UI-DialogBox-Border", true, 0, 16, 4)

-- Nine-slice borders: drawn with the matching 3.3.5 backdrop.
if _G.NineSliceUtil == nil then
	local layouts = setmetatable({}, { __index = function() return BACKDROP_TOOLTIP_16_16_5555 end })
	layouts.Dialog = BACKDROP_DIALOG_32_32
	layouts.DialogFrame = BACKDROP_DIALOG_32_32
	layouts.TooltipDefaultLayout = BACKDROP_TOOLTIP_16_16_5555
	layouts.ButtonFrameTemplateNoPortrait = BACKDROP_DIALOG_32_32
	layouts.PortraitFrameTemplate = BACKDROP_DIALOG_32_32
	layouts.UniqueCornersLayout = BACKDROP_DIALOG_32_32
	_G.NineSliceLayouts = _G.NineSliceLayouts or layouts
	_G.NineSliceUtil = {
		ApplyLayout = function(frame, layout)
			if frame.SetBackdrop and type(layout) == "table" and (layout.bgFile or layout.edgeFile) then
				frame:SetBackdrop(layout)
			elseif frame.SetBackdrop then
				frame:SetBackdrop(BACKDROP_TOOLTIP_16_16_5555)
			end
		end,
		ApplyLayoutByName = function(frame, name)
			if frame.SetBackdrop then
				frame:SetBackdrop(layouts[name])
			end
		end,
		GetLayout = function(name) return layouts[name] end,
		AddLayout = function(name, layout) layouts[name] = layout end,
		DisableSharpening = noop,
		ApplyUniqueCornersLayout = function(frame) if frame.SetBackdrop then frame:SetBackdrop(BACKDROP_DIALOG_32_32) end end,
	}
end

if _G.NineSlicePanelMixin == nil then
	_G.NineSlicePanelMixin = {
		OnLoad = function(self)
			if self.layoutType then
				NineSliceUtil.ApplyLayoutByName(self, self.layoutType)
			end
		end,
		GetFrameLayoutType = function(self) return self.layoutType end,
		GetFrameLayoutTextureKit = function(self) return self.layoutTextureKit end,
		SetBorderColor = function(self, r, g, b, a) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(r, g, b, a) end end,
		SetCenterColor = function(self, r, g, b, a) if self.SetBackdropColor then self:SetBackdropColor(r, g, b, a) end end,
		SetVertexColor = function(self, r, g, b, a) if self.SetBackdropBorderColor then self:SetBackdropBorderColor(r, g, b, a) end end,
		GetBorderColor = function(self) if self.GetBackdropBorderColor then return self:GetBackdropBorderColor() end return 1, 1, 1, 1 end,
	}
end

-- Script handlers this client does not have -------------------------------------------------------
-- Setting a handler the client does not know (OnModelLoaded, OnEnable, OnSizeChanged on a region...)
-- raised an error. The handler is kept instead, so GetScript returns it, and the ones that can be
-- driven from Lua are: OnModelLoaded runs after a model is set.

local extraScripts = setmetatable({}, { __mode = "k" })
local mouseScripts = { OnMouseDown = true, OnMouseUp = true, OnEnter = true, OnLeave = true, OnDragStart = true }

for _, index in ipairs(frameTypes) do
	local SetScript, GetScript, HookScript, HasScript = rawget(index, "SetScript"), rawget(index, "GetScript"), rawget(index, "HookScript"), rawget(index, "HasScript")
	if SetScript and HasScript then
		local function known(self, script)
			local ok, has = pcall(HasScript, self, script)
			return ok and has
		end
		index.SetScript = function(self, script, func)
			if script == "OnEvent" or known(self, script) then
				-- Modern clients take mouse input on a frame once it has a mouse handler.
				if func and mouseScripts[script] and self.EnableMouse and not self:IsMouseEnabled() then
					self:EnableMouse(true)
				elseif func and script == "OnMouseWheel" and self.EnableMouseWheel then
					self:EnableMouseWheel(true)
				end
				return SetScript(self, script, func)
			end
			local scripts = extraScripts[self] or {}
			extraScripts[self] = scripts
			scripts[script] = func
		end
		index.GetScript = function(self, script)
			if script == "OnEvent" or known(self, script) then
				return GetScript(self, script)
			end
			local scripts = extraScripts[self]
			return scripts and scripts[script]
		end
		if HookScript then
			index.HookScript = function(self, script, func)
				if script == "OnEvent" or known(self, script) then
					return HookScript(self, script, func)
				end
				local scripts = extraScripts[self] or {}
				extraScripts[self] = scripts
				local old = scripts[script]
				scripts[script] = old and function(...) old(...) return func(...) end or func
			end
		end
	end
end

local function runExtraScript(self, script, ...)
	local scripts = extraScripts[self]
	local func = scripts and scripts[script]
	if func then
		securecall(func, self, ...)
	end
end
_G.ModernUI_RunExtraScript = runExtraScript

for _, kind in ipairs({ "Model", "PlayerModel", "DressUpModel", "TabardModel" }) do
	local index = methodTables[kind]
	if index then
		for _, setter in ipairs({ "SetModel", "SetUnit", "SetCreature", "SetDisplayInfo", "SetItem", "RefreshUnit" }) do
			local original = index[setter]
			if original then
				index[setter] = function(self, ...)
					local a, b, c, d = original(self, ...)
					if extraScripts[self] and extraScripts[self].OnModelLoaded then
						RunNextFrame(function() runExtraScript(self, "OnModelLoaded") end)
					end
					return a, b, c, d
				end
			end
		end

		-- Modern SetLight takes (enabled, lightValues): a table instead of the 3.3.5 argument list.
		local SetLight = index.SetLight
		if SetLight then
			index.SetLight = function(self, enabled, light, ...)
				if type(light) ~= "table" then
					return SetLight(self, enabled, light, ...)
				end
				local point = light.point or {}
				local ambient = light.ambientColor or {}
				local diffuse = light.diffuseColor or {}
				return SetLight(self, enabled and 1 or 0, light.omnidirectional and 1 or 0,
					point.x or point[1] or 0, point.y or point[2] or 0, point.z or point[3] or -1,
					light.ambientIntensity or 0, ambient.r or ambient[1] or 1, ambient.g or ambient[2] or 1, ambient.b or ambient[3] or 1,
					light.diffuseIntensity or 0, diffuse.r or diffuse[1] or 1, diffuse.g or diffuse[2] or 1, diffuse.b or diffuse[3] or 1)
			end
		end
		addTo(kind, "GetLight", function() return true, { omnidirectional = false, point = CreateVector3D(0, 0, -1), ambientIntensity = 1, ambientColor = CreateColor(1, 1, 1), diffuseIntensity = 1, diffuseColor = CreateColor(1, 1, 1) } end)
	end
end

-- Regions take a scale of their own in the modern clients; here it is kept and reported.
for _, index in ipairs(regionTypes) do
	if rawget(index, "SetScale") == nil then
		index.SetScale = function(self, scale) stateOf(self).scale = scale end
		index.GetScale = function(self) return stateOf(self).scale or 1 end
	end
end

add(frameTypes, "SetHyperlinksEnabled", noop)
add(frameTypes, "GetHyperlinksEnabled", function() return true end)
addTo("FontString", "SetHyperlinksEnabled", noop)
addTo("EditBox", "ClearHighlightText", function(self) self:HighlightText(0, 0) end)
addTo("EditBox", "SetHighlightColor", noop)
addTo("EditBox", "GetHighlightColor", function() return 1, 1, 1, 0.3 end)
addTo("EditBox", "SetSecurityDisablePaste", noop)
addTo("EditBox", "SetSecurityDisableSetText", noop)
addTo("EditBox", "SetForceUpperCase", noop)

-- Tooltips: modern code colours a tooltip's border through tooltip.NineSlice.
local function giveNineSlice(tooltip)
	if type(tooltip) == "table" and tooltip.SetBackdropBorderColor and rawget(tooltip, "NineSlice") == nil then
		tooltip.NineSlice = {
			SetBorderColor = function(_, r, g, b, a) tooltip:SetBackdropBorderColor(r, g, b, a) end,
			SetCenterColor = function(_, r, g, b, a) tooltip:SetBackdropColor(r, g, b, a) end,
			GetBorderColor = function() return tooltip:GetBackdropBorderColor() end,
			GetCenterColor = function() return tooltip:GetBackdropColor() end,
			SetVertexColor = function(_, r, g, b, a) tooltip:SetBackdropBorderColor(r, g, b, a) end,
			Show = noop, Hide = noop, SetShown = noop, SetAlpha = noop,
			SetFrameLevel = noop, GetFrameLevel = function() return tooltip:GetFrameLevel() end,
			SetPoint = noop, ClearAllPoints = noop, SetAllPoints = noop,
		}
		tooltip.layoutType = tooltip.layoutType or "TooltipDefaultLayout"
	end
end
for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
	"ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "ItemRefShoppingTooltip3", "WorldMapTooltip", "WorldMapCompareTooltip1",
	"WorldMapCompareTooltip2", "WorldMapCompareTooltip3", "FriendsTooltip" }) do
	giveNineSlice(_G[name])
end
do
	local wrappedCreateFrame = _G.CreateFrame
	_G.CreateFrame = function(frameType, ...)
		local frame = wrappedCreateFrame(frameType, ...)
		if frame and frameType == "GameTooltip" then
			giveNineSlice(frame)
		end
		return frame
	end
end

-- Enable/Disable and highlight locking on frame types that lack them here (modern sliders, models...).
add(frameTypes, "Enable", function(self) stateOf(self).disabled = nil if self.EnableMouse then self:EnableMouse(true) end end)
add(frameTypes, "Disable", function(self) stateOf(self).disabled = true end)
add(frameTypes, "IsEnabled", function(self) return not stateOf(self).disabled end)
add(frameTypes, "LockHighlight", noop)
add(frameTypes, "UnlockHighlight", noop)
for _, kind in ipairs({ "Model", "PlayerModel", "DressUpModel", "TabardModel" }) do
	addTo(kind, "SetModelDrawLayer", noop)
	addTo(kind, "GetModelDrawLayer", function() return "ARTWORK", 0 end)
end

-- Animations aimed at a child --------------------------------------------------------------------
-- Modern animations can animate a child of the group's region (SetChildKey, SetTargetKey, SetTarget,
-- childKey= in XML); 3.3.5 animations always move the region that owns the group. An alpha animation
-- with a target is played here by setting the target's alpha as it runs, and leaves the owner alone.

do
	local function targetOf(anim)
		local s = stateOf(anim)
		if s.target then
			return s.target
		end
		local key = s.childKey or s.targetKey
		if key then
			local group = anim:GetParent()
			local owner = group and group:GetParent()
			local target = owner
			for part in key:gmatch("[^%.]+") do
				if part == "$parent" then
					target = target and target:GetParent()
				else
					target = target and target[part]
				end
			end
			return target
		end
	end

	local function aim(anim)
		local s = stateOf(anim)
		if s.aimed then
			return
		end
		s.aimed = true
		if anim.SetChange then
			anim:SetChange(0)
		end
		local function update(self)
			local target = targetOf(self)
			if target and target.SetAlpha then
				local st = stateOf(self)
				local from, to = st.fromAlpha or 0, st.toAlpha or 1
				local progress = self.GetSmoothProgress and self:GetSmoothProgress() or self:GetProgress() or 0
				target:SetAlpha(from + (to - from) * progress)
			end
		end
		local function play(self)
			local target = targetOf(self)
			if target and target.SetAlpha then
				local st = stateOf(self)
				st.restoreAlpha = target:GetAlpha()
				target:SetAlpha(st.fromAlpha or 0)
			end
		end
		local function finish(self)
			local target = targetOf(self)
			if target and target.SetAlpha then
				local st = stateOf(self)
				local group = self:GetParent()
				if group and stateOf(group).toFinalAlpha then
					target:SetAlpha(st.toAlpha or 1)
				elseif st.restoreAlpha then
					target:SetAlpha(st.restoreAlpha)
				end
			end
		end
		for script, func in pairs({ OnUpdate = update, OnPlay = play, OnFinished = finish, OnStop = finish }) do
			if anim.HookScript then
				anim:HookScript(script, func)
			else
				anim:SetScript(script, func)
			end
		end
	end

	local alpha = methodTables.Alpha
	if alpha then
		local SetChange = alpha.SetChange
		alpha.SetChildKey = function(self, key) stateOf(self).childKey = key aim(self) end
		alpha.SetTargetKey = function(self, key) stateOf(self).targetKey = key aim(self) end
		alpha.SetTarget = function(self, target) stateOf(self).target = target aim(self) end
		alpha.SetTargetName = function(self, name) stateOf(self).target = _G[name] aim(self) end
		alpha.GetTarget = function(self) return targetOf(self) or self:GetRegionParent() end
		-- Keep the owner still once the animation is aimed at a child.
		alpha.SetFromAlpha = function(self, value)
			local s = stateOf(self)
			s.fromAlpha = value
			if not s.aimed then
				SetChange(self, (s.toAlpha or 1) - (s.fromAlpha or 0))
			end
		end
		alpha.SetToAlpha = function(self, value)
			local s = stateOf(self)
			s.toAlpha = value
			if not s.aimed then
				SetChange(self, (s.toAlpha or 1) - (s.fromAlpha or 0))
			end
		end
	end
	local group = methodTables.AnimationGroup
	if group then
		group.SetToFinalAlpha = function(self, final) stateOf(self).toFinalAlpha = final and true or false end
		group.IsSetToFinalAlpha = function(self) return stateOf(self).toFinalAlpha == true end
	end
	_G.ModernUI_AimAnimation = function(anim, childKey)
		stateOf(anim).childKey = childKey
		aim(anim)
	end
end

-- Item buttons -----------------------------------------------------------------------------------
-- Modern bag and item buttons carry parts by key (IconBorder, NewItemTexture, BattlepayItemTexture,
-- JunkIcon, UpgradeIcon...) that the 3.3.5 templates lack; they are added, hidden, when such a
-- button is created.

local function texture(button, layer, sublevel, file, blend)
	local t = button:CreateTexture(nil, layer, nil, sublevel)
	if file then
		t:SetTexture(file)
	end
	if blend then
		t:SetBlendMode(blend)
	end
	t:Hide()
	return t
end

local function modernItemButton(button)
	if rawget(button, "IconBorder") then
		return
	end
	local name = button:GetName()
	if name then
		button.icon = button.icon or _G[name .. "IconTexture"]
		button.Count = button.Count or _G[name .. "Count"]
		button.Cooldown = button.Cooldown or _G[name .. "Cooldown"]
		button.IconQuestTexture = button.IconQuestTexture or _G[name .. "IconQuestTexture"]
		button.searchOverlay = button.searchOverlay or _G[name .. "SearchOverlay"]
		button.Stock = button.Stock or _G[name .. "Stock"]
	end
	if not button.IconQuestTexture then
		button.IconQuestTexture = texture(button, "OVERLAY", 2)
		button.IconQuestTexture:SetAllPoints()
	end
	button.IconBorder = texture(button, "OVERLAY", 0, "Interface\\Buttons\\UI-ActionButton-Border", "ADD")
	button.IconBorder:SetPoint("CENTER")
	button.IconBorder:SetWidth(button:GetWidth() * 1.8)
	button.IconBorder:SetHeight(button:GetHeight() * 1.8)
	button.IconOverlay = texture(button, "OVERLAY", 1)
	button.IconOverlay:SetAllPoints()
	button.IconOverlay2 = texture(button, "OVERLAY", 2)
	button.IconOverlay2:SetAllPoints()
	button.NewItemTexture = texture(button, "OVERLAY", 1, "Interface\\Buttons\\UI-ActionButton-Border", "ADD")
	button.NewItemTexture:SetPoint("CENTER")
	button.NewItemTexture:SetWidth(button:GetWidth() * 1.8)
	button.NewItemTexture:SetHeight(button:GetHeight() * 1.8)
	button.BattlepayItemTexture = texture(button, "OVERLAY", 1)
	button.BattlepayItemTexture:SetAllPoints()
	button.JunkIcon = texture(button, "OVERLAY", 3, "Interface\\Buttons\\UI-GroupLoot-Coin-Up")
	button.JunkIcon:SetPoint("TOPLEFT", 1, -1)
	button.JunkIcon:SetWidth(12)
	button.JunkIcon:SetHeight(12)
	button.UpgradeIcon = texture(button, "OVERLAY", 3, "Interface\\Buttons\\UI-MicroStream-Green")
	button.UpgradeIcon:SetPoint("TOPLEFT", 0, 0)
	button.UpgradeIcon:SetWidth(14)
	button.UpgradeIcon:SetHeight(14)
	button.ItemContextOverlay = texture(button, "OVERLAY", 4)
	button.ItemContextOverlay:SetAllPoints()
	button.flash = texture(button, "OVERLAY", 2, "Interface\\Buttons\\UI-ActionButton-Border", "ADD")
	button.flash:SetPoint("CENTER")
	button.flash:SetWidth(button:GetWidth() * 1.8)
	button.flash:SetHeight(button:GetHeight() * 1.8)
	button.flashAnim = button:CreateAnimationGroup()
	button.newitemglowAnim = button:CreateAnimationGroup()
end
_G.ModernUI_ModernItemButton = modernItemButton

do
	local itemTemplates = { "ContainerFrameItemButtonTemplate", "ItemButtonTemplate", "BankItemButtonGenericTemplate", "MerchantItemButtonTemplate" }
	local wrappedCreateFrame = _G.CreateFrame
	_G.CreateFrame = function(frameType, name, parent, template, ...)
		local frame = wrappedCreateFrame(frameType, name, parent, template, ...)
		if frame and (frameType == "ItemButton" or (type(template) == "string" and (function()
			for _, t in ipairs(itemTemplates) do
				if template:find(t, 1, true) then
					return true
				end
			end
		end)())) then
			modernItemButton(frame)
		end
		return frame
	end
end

-- This client's own bag and bank buttons are made by FrameXML, not CreateFrame; they get the parts too.
do
	local function upgradeBlizzardButtons()
		for bag = 1, NUM_CONTAINER_FRAMES or 13 do
			for slot = 1, MAX_CONTAINER_ITEMS or 36 do
				local button = _G["ContainerFrame" .. bag .. "Item" .. slot]
				if button then
					modernItemButton(button)
				end
			end
		end
		for slot = 1, NUM_BANKGENERIC_SLOTS or 28 do
			local button = _G["BankFrameItem" .. slot]
			if button then
				modernItemButton(button)
			end
		end
	end
	upgradeBlizzardButtons()
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:SetScript("OnEvent", upgradeBlizzardButtons)
end

-- The generated API surface (95_ApiSurface.lua) adds documented methods to these tables.
_G.ModernUI_WidgetMethodTables = methodTables

-- GetFont: modern clients answer with the font the text is drawn in, including one that comes from its font
-- object; this client answers nothing then. SetFont also accepts a missing flags argument.
do
	for _, kind in ipairs({ "FontString", "EditBox", "SimpleHTML", "MessageFrame", "ScrollingMessageFrame" }) do
		local index = methodTables[kind]
		local GetFont = index and rawget(index, "GetFont")
		local SetFont = index and rawget(index, "SetFont")
		if GetFont then
			index.GetFont = function(self, ...)
				local font, height, flags = GetFont(self, ...)
				if not font and self.GetFontObject then
					local object = self:GetFontObject()
					if object and object.GetFont then
						font, height, flags = object:GetFont()
					end
				end
				if not font and _G.GameFontNormal then
					font, height, flags = GameFontNormal:GetFont()
				end
				return font, height, flags or ""
			end
		end
		if SetFont then
			index.SetFont = function(self, font, height, flags, ...)
				if not font then
					font = (index.GetFont(self))
				end
				return SetFont(self, font, height or 12, flags or "", ...)
			end
		end
	end
end

-- SimpleHTML:GetContentHeight: the height its text needs at its current width, measured with a hidden font
-- string (modern code sizes the frame to it; this client has no such query, so the frame ended up 0 high).
do
	local index = methodTables.SimpleHTML
	if index then
		local measure
		local texts = setmetatable({}, { __mode = "k" })
		local SetText = index.SetText
		index.SetText = function(self, text, ...)
			texts[self] = text
			return SetText(self, text, ...)
		end
		index.GetContentHeight = function(self)
			local text = texts[self]
			if not text or text == "" then
				return 0
			end
			if not measure then
				measure = UIParent:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
				measure:Hide()
			end
			local plain = tostring(text):gsub("<[Bb][Rr]%s*/?>", "\n"):gsub("</[Pp]>", "\n"):gsub("<[^>]+>", "")
			plain = plain:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"):gsub("\n+$", "")
			local font, size, flags = self:GetFont()
			if font then
				measure:SetFont(font, size or 12, flags or "")
			end
			local width = self:GetWidth() or 0
			measure:SetWidth(width > 0 and width or 300)
			measure:SetText(plain)
			return measure:GetStringHeight() or 0
		end
		index.GetContentWidth = function(self)
			if not measure then
				return self:GetWidth() or 0
			end
			return math.min(measure:GetStringWidth() or 0, self:GetWidth() or 0)
		end
	end
end
