-- ModernUI: built into the client (not in the original 3.3.5a).
-- ColorMixin and CreateColor, and colour methods on the colour tables the 3.3.5 interface already has.

local _G = _G
local type, pairs, floor = type, pairs, math.floor

local ColorMixin = _G.ColorMixin or {}
_G.ColorMixin = ColorMixin

local function byte(v)
	v = floor((v or 0) * 255 + 0.5)
	if v < 0 then return 0 elseif v > 255 then return 255 end
	return v
end

function ColorMixin:OnLoad(r, g, b, a)
	self:SetRGBA(r, g, b, a)
end

function ColorMixin:IsRGBEqualTo(other)
	return self.r == other.r and self.g == other.g and self.b == other.b
end

function ColorMixin:IsEqualTo(other)
	return self:IsRGBEqualTo(other) and self.a == other.a
end

function ColorMixin:GetRGB()
	return self.r, self.g, self.b
end

function ColorMixin:GetRGBAsBytes()
	return byte(self.r), byte(self.g), byte(self.b)
end

function ColorMixin:GetRGBA()
	return self.r, self.g, self.b, self.a
end

function ColorMixin:GetRGBAAsBytes()
	return byte(self.r), byte(self.g), byte(self.b), byte(self.a or 1)
end

function ColorMixin:SetRGBA(r, g, b, a)
	self.r, self.g, self.b, self.a = r, g, b, a
end

function ColorMixin:SetRGB(r, g, b)
	self:SetRGBA(r, g, b, nil)
end

function ColorMixin:GenerateHexColor()
	return ("ff%.2x%.2x%.2x"):format(self:GetRGBAsBytes())
end

function ColorMixin:GenerateHexColorNoAlpha()
	return ("%.2x%.2x%.2x"):format(self:GetRGBAsBytes())
end

function ColorMixin:GenerateHexColorMarkup()
	return "|c" .. self:GenerateHexColor()
end

function ColorMixin:WrapTextInColorCode(text)
	return "|c" .. self:GenerateHexColor() .. tostring(text) .. "|r"
end

function ColorMixin:GetHexColor()
	return self:GenerateHexColor()
end

if _G.CreateColor == nil then
	function _G.CreateColor(r, g, b, a)
		local color = CreateFromMixins(ColorMixin)
		color:OnLoad(r, g, b, a)
		return color
	end
end

if _G.CreateColorFromBytes == nil then
	function _G.CreateColorFromBytes(r, g, b, a)
		return CreateColor(r / 255, g / 255, b / 255, (a or 255) / 255)
	end
end

local function parseHex(hex)
	hex = hex:gsub("^#", ""):gsub("^|c", "")
	if #hex == 6 then
		hex = "ff" .. hex
	end
	local a, r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), tonumber(hex:sub(7, 8), 16)
	if not (a and r and g and b) then
		return nil
	end
	return r / 255, g / 255, b / 255, a / 255
end

if _G.CreateColorFromHexString == nil then
	function _G.CreateColorFromHexString(hex)
		local r, g, b, a = parseHex(hex)
		if r then
			return CreateColor(r, g, b, a)
		end
	end
end

if _G.CreateColorFromRGBHexString == nil then
	function _G.CreateColorFromRGBHexString(hex)
		local r, g, b = parseHex(hex)
		if r then
			return CreateColor(r, g, b, 1)
		end
	end
end

if _G.WrapTextInColorCode == nil then
	function _G.WrapTextInColorCode(text, colorHexString)
		return ("|c%s%s|r"):format(colorHexString, text)
	end
end

if _G.WrapTextInColor == nil then
	function _G.WrapTextInColor(text, color)
		return color:WrapTextInColorCode(text)
	end
end

-- Give the colour tables 3.3.5 already defines the ColorMixin methods modern code calls on them.
local function upgrade(color)
	if type(color) == "table" and type(color.r) == "number" and color.GetRGB == nil then
		for k, v in pairs(ColorMixin) do
			if color[k] == nil then
				color[k] = v
			end
		end
	end
	return color
end

for name, value in pairs(_G) do
	if type(name) == "string" and name:find("_COLOR$") then
		upgrade(value)
	end
end

if type(_G.ITEM_QUALITY_COLORS) == "table" then
	for _, color in pairs(ITEM_QUALITY_COLORS) do
		upgrade(color)
		-- Modern entries also carry .color (a ColorMixin) next to r, g, b and hex.
		if color.color == nil then
			color.color = color
		end
	end
end

for _, list in pairs({ _G.RAID_CLASS_COLORS, _G.CUSTOM_CLASS_COLORS }) do
	if type(list) == "table" then
		for _, color in pairs(list) do
			upgrade(color)
			if color.colorStr == nil and color.r then
				color.colorStr = color:GenerateHexColor()
			end
		end
	end
end

local fallbacks = {
	WHITE_FONT_COLOR = { 1, 1, 1 },
	BLACK_FONT_COLOR = { 0, 0, 0 },
	LIGHTGRAY_FONT_COLOR = { 0.6, 0.6, 0.6 },
	DARKGRAY_COLOR = { 0.4, 0.4, 0.4 },
	DISABLED_FONT_COLOR = { 0.498, 0.498, 0.498 },
	LIGHTYELLOW_FONT_COLOR = { 1, 1, 0.6 },
	DARKYELLOW_FONT_COLOR = { 1, 0.82, 0 },
	BRIGHTBLUE_FONT_COLOR = { 0, 0.8, 1 },
	LIGHTBLUE_FONT_COLOR = { 0.53, 0.67, 1 },
	ORANGE_FONT_COLOR = { 1, 0.5, 0.25 },
	EPIC_PURPLE_COLOR = { 0.64, 0.21, 0.93 },
	RARE_BLUE_COLOR = { 0, 0.44, 0.87 },
	UNCOMMON_GREEN_COLOR = { 0.12, 1, 0 },
	LEGENDARY_ORANGE_COLOR = { 1, 0.5, 0 },
	TRANSMOGRIFY_FONT_COLOR = { 1, 0.5, 1 },
	WARNING_FONT_COLOR = { 1, 0.282, 0 },
	BLUE_FONT_COLOR = { 0, 0.749, 0.953 },
	LINK_FONT_COLOR = { 0.4, 0.733, 1 },
	ARTIFACT_GOLD_COLOR = { 0.9, 0.8, 0.5 },
	PASSIVE_SPELL_FONT_COLOR = { 0.776, 0.737, 0.635 },
}
for name, rgb in pairs(fallbacks) do
	if _G[name] == nil then
		_G[name] = CreateColor(rgb[1], rgb[2], rgb[3], 1)
	end
end

if _G.C_ClassColor == nil then
	_G.C_ClassColor = {
		GetClassColor = function(classFilename)
			return RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename]
		end,
	}
end

if _G.GetClassColorObj == nil then
	function _G.GetClassColorObj(classFilename)
		return RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename]
	end
end

if _G.GetClassColoredTextForUnit == nil then
	function _G.GetClassColoredTextForUnit(unit, text)
		local _, class = UnitClass(unit)
		local color = class and RAID_CLASS_COLORS[class]
		return color and color:WrapTextInColorCode(text) or text
	end
end

if _G.C_ColorUtil == nil then
	_G.C_ColorUtil = {
		WrapTextInColor = function(text, color) return color:WrapTextInColorCode(text) end,
		GenerateTextColorCode = function(color) return color:GenerateHexColorMarkup() end,
	}
end
