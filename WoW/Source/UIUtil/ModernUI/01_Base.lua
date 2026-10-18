-- ModernUI: built into the client (not in the original 3.3.5a).
-- The basic helpers every modern addon expects to find before it loads.
-- Nothing here replaces anything the 3.3.5 interface already defines.

local _G = _G
local type, pairs, ipairs, next, select, error, tostring = type, pairs, ipairs, next, select, error, tostring
local floor, min, max = math.floor, math.min, math.max

local function define(name, value)
	if _G[name] == nil then
		_G[name] = value
	end
end

-- Mixins ----------------------------------------------------------------------------------------

-- A missing mixin is reported (with where it was asked for) but does not stop the file that asked,
-- so one mixin this client lacks costs one feature rather than a whole addon.
local reportedMixins = {}
define("Mixin", function(object, ...)
	for i = 1, select("#", ...) do
		local mixin = select(i, ...)
		if type(mixin) == "table" then
			for k, v in pairs(mixin) do
				object[k] = v
			end
		else
			local where = debugstack and debugstack(2, 1, 0) or "?"
			if not reportedMixins[where] then
				reportedMixins[where] = true
				securecall(error, "Mixin: argument " .. (i + 1) .. " is not a table (a mixin this client lacks), called from " .. where, 0)
			end
		end
	end
	return object
end)

define("CreateFromMixins", function(...)
	return Mixin({}, ...)
end)

define("CreateAndInitFromMixin", function(mixin, ...)
	local object = CreateFromMixins(mixin)
	object:Init(...)
	return object
end)

-- Tables ----------------------------------------------------------------------------------------

define("tInvert", function(tbl)
	local inverted = {}
	for k, v in pairs(tbl) do
		inverted[v] = k
	end
	return inverted
end)

define("tIndexOf", function(tbl, item)
	for i, v in ipairs(tbl) do
		if v == item then
			return i
		end
	end
end)

define("tFilter", function(tbl, pred, isIndexTable)
	local out = {}
	if isIndexTable then
		local n = 0
		for _, v in ipairs(tbl) do
			if pred(v) then
				n = n + 1
				out[n] = v
			end
		end
	else
		for k, v in pairs(tbl) do
			if pred(v) then
				out[k] = v
			end
		end
	end
	return out
end)

define("tAppendAll", function(tbl, addedArray)
	for _, v in ipairs(addedArray) do
		tbl[#tbl + 1] = v
	end
end)

define("tCompare", function(lhs, rhs, depth)
	depth = depth or 1
	for k, v in pairs(lhs) do
		if type(v) == "table" and type(rhs[k]) == "table" and depth > 1 then
			if not tCompare(v, rhs[k], depth - 1) then
				return false
			end
		elseif v ~= rhs[k] then
			return false
		end
	end
	for k in pairs(rhs) do
		if lhs[k] == nil then
			return false
		end
	end
	return true
end)

define("tUnorderedRemove", function(tbl, index)
	local n = #tbl
	if index ~= n then
		tbl[index] = tbl[n]
	end
	tbl[n] = nil
end)

define("TableHasAnyEntries", function(tbl)
	return next(tbl) ~= nil
end)

define("MergeTable", function(destination, source)
	for k, v in pairs(source) do
		destination[k] = v
	end
	return destination
end)

define("ipairs_reverse", function(tbl)
	local i = #tbl + 1
	return function()
		i = i - 1
		if i > 0 then
			return i, tbl[i]
		end
	end
end)

define("SafePack", function(...)
	return { n = select("#", ...), ... }
end)

define("SafeUnpack", function(tbl)
	return unpack(tbl, 1, tbl.n or #tbl)
end)

local TableUtil = _G.TableUtil or {}
_G.TableUtil = TableUtil
TableUtil.ContainsValue = TableUtil.ContainsValue or function(tbl, value)
	for _, v in pairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end
TableUtil.Copy = TableUtil.Copy or function(tbl, shallow)
	local out = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" and not shallow then
			out[k] = TableUtil.Copy(v)
		else
			out[k] = v
		end
	end
	return out
end
TableUtil.CopyUnique = TableUtil.CopyUnique or function(tbl)
	local seen, out = {}, {}
	for _, v in ipairs(tbl) do
		if not seen[v] then
			seen[v] = true
			out[#out + 1] = v
		end
	end
	return out
end
TableUtil.Execute = TableUtil.Execute or function(tbl, fn)
	for _, v in pairs(tbl) do
		fn(v)
	end
end
TableUtil.Transform = TableUtil.Transform or function(tbl, fn)
	local out = {}
	for k, v in pairs(tbl) do
		out[k] = fn(v)
	end
	return out
end
TableUtil.TrySet = TableUtil.TrySet or function(tbl, key)
	if not tbl[key] then
		tbl[key] = true
		return true
	end
	return false
end
TableUtil.CompareValuesAsKeys = TableUtil.CompareValuesAsKeys or function(lhs, rhs)
	return tCompare(tInvert(lhs), tInvert(rhs))
end
TableUtil.GetRandomElement = TableUtil.GetRandomElement or function(tbl)
	return tbl[math.random(#tbl)]
end
TableUtil.FindIndex = TableUtil.FindIndex or function(tbl, pred)
	for i, v in ipairs(tbl) do
		if pred(v) then
			return i
		end
	end
end

-- Maths -----------------------------------------------------------------------------------------

define("Clamp", function(value, minValue, maxValue)
	if value > maxValue then
		return maxValue
	elseif value < minValue then
		return minValue
	end
	return value
end)

define("Saturate", function(value)
	return Clamp(value, 0.0, 1.0)
end)

define("Round", function(value)
	if value < 0.0 then
		return -floor(-value + 0.5)
	end
	return floor(value + 0.5)
end)

define("Lerp", function(startValue, endValue, amount)
	return (1 - amount) * startValue + amount * endValue
end)

define("ClampedPercentageBetween", function(value, startValue, endValue)
	if startValue == endValue then
		return 0.0
	end
	return Saturate((value - startValue) / (endValue - startValue))
end)

define("PercentageBetween", function(value, startValue, endValue)
	if startValue == endValue then
		return 0.0
	end
	return (value - startValue) / (endValue - startValue)
end)

define("FrameDeltaLerp", function(startValue, endValue, amount, elapsed)
	return Lerp(startValue, endValue, Saturate(amount * (elapsed or 0) * 60))
end)

define("ApproximatelyEqual", function(v1, v2, epsilon)
	return math.abs(v1 - v2) < (epsilon or 0.000001)
end)

define("WithinRange", function(value, minValue, maxValue)
	return value >= minValue and value <= maxValue
end)

define("WithinRangeExclusive", function(value, minValue, maxValue)
	return value > minValue and value < maxValue
end)

define("CalculateDistanceSq", function(x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	return dx * dx + dy * dy
end)

define("CalculateDistance", function(x1, y1, x2, y2)
	return math.sqrt(CalculateDistanceSq(x1, y1, x2, y2))
end)

-- Strings ---------------------------------------------------------------------------------------

define("strsplittable", function(delimiter, str, pieces)
	return { strsplit(delimiter, str, pieces) }
end)

define("CreateTextureMarkup", function(file, fileWidth, fileHeight, width, height, left, right, top, bottom, xOffset, yOffset)
	return ("|T%s:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d|t"):format(
		file, height, width, xOffset or 0, yOffset or 0, fileWidth, fileHeight,
		left * fileWidth, right * fileWidth, top * fileHeight, bottom * fileHeight)
end)

define("CreateSimpleTextureMarkup", function(file, width, height)
	return ("|T%s:%d:%d|t"):format(file, height or width or 0, width or 0)
end)

-- No atlas data exists in a 3.3.5 client; markup for an atlas shows nothing rather than failing.
define("CreateAtlasMarkup", function(atlasName, width, height)
	return ""
end)

define("FormatLargeNumber", function(amount)
	local s = tostring(floor(amount))
	local formatted, k = s, nil
	while true do
		formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end)

define("FormatPercentage", function(percentage, roundToNearestInteger)
	if roundToNearestInteger then
		return ("%d%%"):format(Round(percentage * 100))
	end
	return ("%.2f%%"):format(percentage * 100)
end)

-- Functions -------------------------------------------------------------------------------------

define("GenerateClosure", function(f, ...)
	local count = select("#", ...)
	if count == 0 then
		return f
	end
	local args = { ... }
	return function(...)
		local all = { unpack(args, 1, count) }
		local n = count
		for i = 1, select("#", ...) do
			n = n + 1
			all[n] = select(i, ...)
		end
		return f(unpack(all, 1, n))
	end
end)

define("GenerateFlatClosure", GenerateClosure)

define("nop", function() end)

-- Vectors ---------------------------------------------------------------------------------------

local Vector2DMixin = _G.Vector2DMixin or {}
_G.Vector2DMixin = Vector2DMixin
function Vector2DMixin:GetXY() return self.x, self.y end
function Vector2DMixin:SetXY(x, y) self.x, self.y = x, y end
function Vector2DMixin:Clone() return CreateVector2D(self.x, self.y) end
function Vector2DMixin:GetLength() return math.sqrt(self.x * self.x + self.y * self.y) end
function Vector2DMixin:Add(o) self.x, self.y = self.x + o.x, self.y + o.y end
function Vector2DMixin:Subtract(o) self.x, self.y = self.x - o.x, self.y - o.y end
function Vector2DMixin:ScaleBy(s) self.x, self.y = self.x * s, self.y * s end
function Vector2DMixin:IsEqualTo(o) return self.x == o.x and self.y == o.y end
define("CreateVector2D", function(x, y)
	local v = CreateFromMixins(Vector2DMixin)
	v:SetXY(x, y)
	return v
end)

local Vector3DMixin = _G.Vector3DMixin or {}
_G.Vector3DMixin = Vector3DMixin
function Vector3DMixin:GetXYZ() return self.x, self.y, self.z end
function Vector3DMixin:SetXYZ(x, y, z) self.x, self.y, self.z = x, y, z end
function Vector3DMixin:Clone() return CreateVector3D(self.x, self.y, self.z) end
function Vector3DMixin:GetLength() return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z) end
function Vector3DMixin:Add(o) self.x, self.y, self.z = self.x + o.x, self.y + o.y, self.z + o.z end
function Vector3DMixin:Subtract(o) self.x, self.y, self.z = self.x - o.x, self.y - o.y, self.z - o.z end
function Vector3DMixin:ScaleBy(s) self.x, self.y, self.z = self.x * s, self.y * s, self.z * s end
define("CreateVector3D", function(x, y, z)
	local v = CreateFromMixins(Vector3DMixin)
	v:SetXYZ(x, y, z)
	return v
end)

-- Rectangles used by some layout code.
local RectangleMixin = _G.RectangleMixin or {}
_G.RectangleMixin = RectangleMixin
function RectangleMixin:OnLoad(left, right, top, bottom) self:SetSides(left or 0, right or 0, top or 0, bottom or 0) end
function RectangleMixin:SetSides(left, right, top, bottom) self.left, self.right, self.top, self.bottom = left, right, top, bottom end
function RectangleMixin:GetWidth() return self.right - self.left end
function RectangleMixin:GetHeight() return self.bottom - self.top end
function RectangleMixin:GetCenter() return (self.left + self.right) / 2, (self.top + self.bottom) / 2 end
define("CreateRectangle", function(left, right, top, bottom)
	local r = CreateFromMixins(RectangleMixin)
	r:OnLoad(left, right, top, bottom)
	return r
end)
