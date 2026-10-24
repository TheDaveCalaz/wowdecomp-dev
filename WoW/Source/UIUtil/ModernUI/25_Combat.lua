-- ModernUI: built into the client (not in the original 3.3.5a).
-- The combat log in its modern shape, the instance ID from GetInstanceInfo, and the frame mixins
-- the modern window templates (PortraitFrameTemplate and its family) are built from.

local _G = _G
local select, type, unpack = select, type, unpack

local function define(name, value)
	if _G[name] == nil then
		_G[name] = value
	end
end

-- Combat log --------------------------------------------------------------------------------------
-- Modern addons register COMBAT_LOG_EVENT_UNFILTERED and read the event with
-- CombatLogGetCurrentEventInfo(). The 3.3.5 event carries the same news as arguments; this frame
-- registers first (before any AddOn), so it sees each event first and keeps it, reshaped to the modern
-- layout: hideCaster after the sub-event, and raid flags after the source and destination flags.

if _G.CombatLogGetCurrentEventInfo == nil then
	local current = { n = 0 }
	local capture = CreateFrame("Frame")
	capture:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	capture:SetScript("OnEvent", function(_, _, ...)
		local n = select("#", ...)
		local timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = ...
		current[1], current[2], current[3] = timestamp, subevent, false
		current[4], current[5], current[6], current[7] = sourceGUID, sourceName, sourceFlags, 0
		current[8], current[9], current[10], current[11] = destGUID, destName, destFlags, 0
		local count = 11
		for i = 9, n do
			count = count + 1
			current[count] = (select(i, ...))
		end
		for i = count + 1, current.n do
			current[i] = nil
		end
		current.n = count
	end)

	_G.CombatLogGetCurrentEventInfo = function()
		return unpack(current, 1, current.n)
	end
end

define("CombatLog_Object_IsA", function(flags, mask)
	return bit.band(flags or 0, mask or 0) ~= 0
end)

-- Instance info -----------------------------------------------------------------------------------
-- The modern GetInstanceInfo also returns the instance (map) ID eighth; this client's returns seven
-- values. The first seven are left exactly as they are, so code written for this client is unaffected.

do
	local GetInstanceInfo_335 = GetInstanceInfo
	if GetInstanceInfo_335 and select("#", GetInstanceInfo_335()) < 8 then
		_G.GetInstanceInfo = function()
			local name, instanceType, difficulty, difficultyName, maxPlayers, dynamicDifficulty, isDynamic = GetInstanceInfo_335()
			local mapID = UnitPosition and select(4, UnitPosition("player")) or nil
			return name, instanceType, difficulty, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, mapID, maxPlayers, nil
		end
	end
end

-- Texture loading groups (used to wait for textures to load; here they are always loaded) ----------

if _G.TextureLoadingGroupMixin == nil then
	local mixin = {}
	function mixin:AddTexture(texture)
		self.textures = self.textures or {}
		self.textures[texture] = true
	end
	function mixin:RemoveTexture(texture)
		if self.textures then
			self.textures[texture] = nil
		end
	end
	function mixin:ClearTextures()
		self.textures = nil
	end
	function mixin:IsFullyLoaded()
		return true
	end
	function mixin:IsEmpty()
		return not self.textures or next(self.textures) == nil
	end
	_G.TextureLoadingGroupMixin = mixin
end

-- Strings and functions a few AddOns read ------------------------------------------------------------

define("STAT_AVERAGE_ITEM_LEVEL", "Item Level")
define("STAT_AVERAGE_ITEM_LEVEL_TOOLTIP", "The average item level of your equipped gear.")
define("STAT_AVERAGE_ITEM_LEVEL_EQUIPPED", "(Equipped: %d)")
define("EmbeddedItemTooltip_SetItemByQuestReward", function() return false end)
define("EmbeddedItemTooltip_SetItemByID", function() return false end)
define("GameTooltip_AddQuestRewardsToTooltip", function() end)

-- Window mixins -------------------------------------------------------------------------------------
-- Methods of the modern window templates; the templates in 90_Templates.xml mix these in, so frames
-- that override OnLoad still have them.

if _G.TitledPanelMixin == nil then
	local TitledPanelMixin = {}
	local function titleText(self)
		return self.TitleText or (self.TitleContainer and self.TitleContainer.TitleText)
			or (self:GetName() and _G[self:GetName() .. "TitleText"])
	end
	function TitledPanelMixin:GetTitleText()
		return titleText(self)
	end
	function TitledPanelMixin:SetTitleColor(color)
		local text = titleText(self)
		if text and color then
			text:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3])
		end
	end
	function TitledPanelMixin:SetTitle(title)
		local text = titleText(self)
		if text then
			text:SetText(title)
		end
	end
	function TitledPanelMixin:SetTitleFormatted(fmt, ...)
		self:SetTitle(fmt:format(...))
	end
	function TitledPanelMixin:SetTitleMaxLinesAndHeight() end
	function TitledPanelMixin:SetTitleOffsets(x, y)
		local text = titleText(self)
		if text then
			text:ClearAllPoints()
			text:SetPoint("TOP", self, "TOP", x or 0, y or -5)
		end
	end
	_G.TitledPanelMixin = TitledPanelMixin
end

if _G.PortraitFrameMixin == nil then
	local PortraitFrameMixin = CreateFromMixins(TitledPanelMixin)
	local function portrait(self)
		return self.portrait or (self.PortraitContainer and self.PortraitContainer.portrait)
	end
	function PortraitFrameMixin:GetPortrait()
		return portrait(self)
	end
	function PortraitFrameMixin:SetBorder() end
	function PortraitFrameMixin:SetPortraitTextureSizeAndOffset(size, x, y)
		local p = portrait(self)
		if p then
			p:SetWidth(size)
			p:SetHeight(size)
			p:ClearAllPoints()
			p:SetPoint("TOPLEFT", self, "TOPLEFT", x or -6, y or 7)
		end
	end
	function PortraitFrameMixin:SetPortraitToAsset(texture)
		local p = portrait(self)
		if p then
			SetPortraitToTexture(p, texture)
		end
	end
	function PortraitFrameMixin:SetPortraitToUnit(unit)
		local p = portrait(self)
		if p then
			SetPortraitTexture(p, unit)
		end
	end
	function PortraitFrameMixin:SetPortraitToBag() end
	function PortraitFrameMixin:SetPortraitTextureRaw(texture)
		local p = portrait(self)
		if p then
			p:SetTexture(texture)
		end
	end
	function PortraitFrameMixin:SetPortraitAtlasRaw() end
	function PortraitFrameMixin:SetPortraitToClassIcon(classFilename)
		local p = portrait(self)
		if p and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFilename] then
			p:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
			p:SetTexCoord(unpack(CLASS_ICON_TCOORDS[classFilename]))
		end
	end
	function PortraitFrameMixin:SetPortraitTexCoord(...)
		local p = portrait(self)
		if p then
			p:SetTexCoord(...)
		end
	end
	function PortraitFrameMixin:SetPortraitShown(shown)
		local p = portrait(self)
		if p then
			if shown then p:Show() else p:Hide() end
		end
	end
	_G.PortraitFrameMixin = PortraitFrameMixin
	define("ButtonFrameTemplateMixin", PortraitFrameMixin)
	define("DefaultPanelMixin", TitledPanelMixin)
end

-- The modern portrait sits in a container frame that code shows and hides; here the container stands
-- for the portrait texture itself.
_G.ModernUI_PortraitContainer = function(portrait)
	local container = { portrait = portrait }
	function container:Show() if portrait then portrait:Show() end end
	function container:Hide() if portrait then portrait:Hide() end end
	function container:SetShown(shown) if shown then self:Show() else self:Hide() end end
	function container:IsShown() return portrait and portrait:IsShown() end
	function container:SetPoint(...) if portrait then portrait:SetPoint(...) end end
	function container:ClearAllPoints() if portrait then portrait:ClearAllPoints() end end
	function container:SetFrameLevel() end
	function container:GetFrameLevel() return 1 end
	return container
end

-- GetTotemInfo(slot) for a slot this client has no totem slot for (modern clients have more, and code loops over
-- MAX_TOTEMS) answers as an empty slot instead of failing.
do
	local GetTotemInfo_335 = _G.GetTotemInfo
	if GetTotemInfo_335 then
		_G.GetTotemInfo = function(slot)
			slot = tonumber(slot)
			if not slot or slot < 1 or slot > 4 then
				return false, "", 0, 0, ""
			end
			return GetTotemInfo_335(slot)
		end
	end
end
