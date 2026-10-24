-- ModernUI: built into the client (not in the original 3.3.5a).
-- The script objects modern clients hand to Lua that are not widgets: curves, colour curves, durations, clocks
-- and number formatters. Modern code builds these and calls their methods (C_CurveUtil.CreateCurve():AddPoint),
-- so they must be real objects, not nil.
--
-- ModernUI_CreateObject(typeName) makes one. The types below work as they do in the modern client; any other
-- documented object type (95_ApiSurface.lua lists their methods) gets an object with every documented method,
-- each answering with an empty result of its documented type.

local _G = _G
local type, pairs, ipairs, select, tostring, setmetatable, rawget = type, pairs, ipairs, select, tostring, setmetatable, rawget
local floor, min, max = math.floor, math.min, math.max
local tinsert, tremove, sort = table.insert, table.remove, table.sort

local implementations = {}

local function newObject(methods, state)
	return setmetatable(state or {}, { __index = methods })
end

local function clamp01(v)
	return v < 0 and 0 or (v > 1 and 1 or v)
end

-- Curves -------------------------------------------------------------------------------------------------------
-- Points (x, y) kept in x order; Evaluate interpolates (Linear) or holds the previous point's value (Step), and
-- holds the end values outside the points.

local CURVE_LINEAR, CURVE_STEP = 0, 1

local function sortPoints(points)
	sort(points, function(a, b) return a.x < b.x end)
end

local function findSegment(points, x)
	local n = #points
	if n == 0 then
		return nil
	end
	if x <= points[1].x then
		return points[1], points[1], 0
	end
	if x >= points[n].x then
		return points[n], points[n], 0
	end
	for i = 2, n do
		local b = points[i]
		if x <= b.x then
			local a = points[i - 1]
			local span = b.x - a.x
			return a, b, span > 0 and (x - a.x) / span or 0
		end
	end
	return points[n], points[n], 0
end

local CurveBase = {}
function CurveBase:GetType() return self.curveType end
function CurveBase:SetType(curveType) self.curveType = curveType or CURVE_LINEAR end
function CurveBase:HasSecretValues() return false end
function CurveBase:ClearPoints() self.points = {} end
function CurveBase:GetPointCount() return #self.points end
function CurveBase:RemovePoint(index)
	if self.points[index] then
		tremove(self.points, index)
	end
end
function CurveBase:SetToDefaults()
	self.points = {}
	self.curveType = CURVE_LINEAR
end

local Curve = setmetatable({}, { __index = CurveBase })
function Curve:AddPoint(x, y)
	if type(x) == "table" then
		x, y = x.x, x.y
	end
	tinsert(self.points, { x = x or 0, y = y or 0 })
	sortPoints(self.points)
end
function Curve:SetPoints(points)
	self.points = {}
	for _, p in ipairs(points or {}) do
		tinsert(self.points, { x = p.x or p[1] or 0, y = p.y or p[2] or 0 })
	end
	sortPoints(self.points)
end
function Curve:GetPoint(index)
	local p = self.points[index]
	return p and CreateVector2D(p.x, p.y) or nil
end
function Curve:GetPoints()
	local out = {}
	for i, p in ipairs(self.points) do
		out[i] = CreateVector2D(p.x, p.y)
	end
	return out
end
function Curve:Evaluate(x)
	local a, b, t = findSegment(self.points, x or 0)
	if not a then
		return 0
	end
	if self.curveType == CURVE_STEP then
		return a.y
	end
	return a.y + (b.y - a.y) * t
end
function Curve:Copy()
	local copy = implementations.LuaCurveObject()
	copy.curveType = self.curveType
	for i, p in ipairs(self.points) do
		copy.points[i] = { x = p.x, y = p.y }
	end
	return copy
end

implementations.LuaCurveObject = function()
	return newObject(Curve, { points = {}, curveType = CURVE_LINEAR })
end

local ColorCurve = setmetatable({}, { __index = CurveBase })
local function colorParts(c)
	if type(c) ~= "table" then
		return 1, 1, 1, 1
	end
	if c.GetRGBA then
		return c:GetRGBA()
	end
	return c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1, c.a or c[4] or 1
end
function ColorCurve:AddPoint(x, color)
	local r, g, b, a = colorParts(color)
	tinsert(self.points, { x = x or 0, r = r, g = g, b = b, a = a })
	sortPoints(self.points)
end
function ColorCurve:SetPoints(points)
	self.points = {}
	for _, p in ipairs(points or {}) do
		local r, g, b, a = colorParts(p.y or p.color or p[2])
		tinsert(self.points, { x = p.x or p[1] or 0, r = r, g = g, b = b, a = a })
	end
	sortPoints(self.points)
end
function ColorCurve:EvaluateUnpacked(x)
	local p, q, t = findSegment(self.points, x or 0)
	if not p then
		return 1, 1, 1, 1
	end
	if self.curveType == CURVE_STEP then
		t = 0
	end
	return p.r + (q.r - p.r) * t, p.g + (q.g - p.g) * t, p.b + (q.b - p.b) * t, p.a + (q.a - p.a) * t
end
function ColorCurve:Evaluate(x)
	return CreateColor(self:EvaluateUnpacked(x))
end
function ColorCurve:GetPoint(index)
	local p = self.points[index]
	return p and { x = p.x, y = CreateColor(p.r, p.g, p.b, p.a) } or nil
end
function ColorCurve:GetPoints()
	local out = {}
	for i = 1, #self.points do
		out[i] = self:GetPoint(i)
	end
	return out
end
function ColorCurve:Copy()
	local copy = implementations.LuaColorCurveObject()
	copy.curveType = self.curveType
	for i, p in ipairs(self.points) do
		copy.points[i] = { x = p.x, r = p.r, g = p.g, b = p.b, a = p.a }
	end
	return copy
end

implementations.LuaColorCurveObject = function()
	return newObject(ColorCurve, { points = {}, curveType = CURVE_LINEAR })
end

-- Clocks and durations -----------------------------------------------------------------------------------------
-- A duration is a start time, a length and a rate, read against a clock (GetTime unless a manual clock is set).

local ManualClock = {}
function ManualClock:GetTime() return self.time end
function ManualClock:SetTime(time) self.time = time or 0 end
function ManualClock:AdvanceTime(delta) self.time = self.time + (delta or 0) end
function ManualClock:RewindTime(delta) self.time = self.time - (delta or 0) end
function ManualClock:ResetTime() self.time = 0 end

implementations.LuaDurationManualClock = function()
	return newObject(ManualClock, { time = 0 })
end

local function evaluate(curve, value)
	if type(curve) == "table" then
		if curve.EvaluateUnpacked then
			return curve:Evaluate(value)
		elseif curve.Evaluate then
			return curve:Evaluate(value)
		end
	end
	return value
end

local Duration = {}
function Duration:GetClock() return self.clock end
function Duration:SetClock(clock) self.clock = clock end
function Duration:GetClockTime()
	local clock = self.clock
	return clock and clock.GetTime and clock:GetTime() or GetTime()
end
function Duration:GetModRate() return self.modRate end
function Duration:HasSecretValues() return false end
function Duration:SetTimeFromStart(startTime, duration, modRate)
	self.startTime, self.duration, self.modRate = startTime or 0, duration or 0, modRate or 1
end
function Duration:SetTimeFromEnd(endTime, duration, modRate)
	modRate = modRate or 1
	duration = duration or 0
	self.startTime, self.duration, self.modRate = (endTime or 0) - duration / modRate, duration, modRate
end
function Duration:SetTimeSpan(startTime, endTime)
	self.startTime, self.duration, self.modRate = startTime or 0, max((endTime or 0) - (startTime or 0), 0), 1
end
function Duration:Reset()
	self.startTime, self.duration, self.modRate = 0, 0, 1
end
Duration.SetToDefaults = Duration.Reset
function Duration:Assign(other)
	if type(other) == "table" then
		self.startTime, self.duration, self.modRate, self.clock = other.startTime, other.duration, other.modRate, other.clock
	end
end
function Duration:Copy()
	local copy = implementations.LuaDurationObject()
	copy:Assign(self)
	return copy
end
function Duration:IsZero() return (self.duration or 0) <= 0 end
function Duration:GetStartTime() return self.startTime end
function Duration:GetTotalDuration() return self.duration end
function Duration:GetEndTime() return self.startTime + self.duration / self.modRate end
function Duration:GetElapsedDuration()
	if self.duration <= 0 then
		return 0
	end
	return min(max((self:GetClockTime() - self.startTime) * self.modRate, 0), self.duration)
end
function Duration:GetRemainingDuration()
	return self.duration - self:GetElapsedDuration()
end
function Duration:GetElapsedPercent()
	return self.duration > 0 and clamp01(self:GetElapsedDuration() / self.duration) or 0
end
function Duration:GetRemainingPercent()
	return self.duration > 0 and 1 - self:GetElapsedPercent() or 0
end
function Duration:HasStarted() return self.duration > 0 and self:GetClockTime() >= self.startTime end
function Duration:HasExpired() return self.duration <= 0 or self:GetClockTime() >= self:GetEndTime() end
function Duration:IsActive() return self:HasStarted() and not self:HasExpired() end
function Duration:EvaluateElapsedDuration(curve) return evaluate(curve, self:GetElapsedDuration()) end
function Duration:EvaluateRemainingDuration(curve) return evaluate(curve, self:GetRemainingDuration()) end
function Duration:EvaluateElapsedPercent(curve) return evaluate(curve, self:GetElapsedPercent()) end
function Duration:EvaluateRemainingPercent(curve) return evaluate(curve, self:GetRemainingPercent()) end
function Duration:EvaluateTotalDuration(curve) return evaluate(curve, self.duration) end
local function format(formatter, seconds)
	if type(formatter) == "table" then
		if formatter.FormatNumber then
			return formatter:FormatNumber(seconds)
		elseif formatter.Format then
			return formatter:Format(seconds)
		end
	end
	return tostring(floor(seconds + 0.5))
end
function Duration:FormatElapsedDuration(formatter) return format(formatter, self:GetElapsedDuration()) end
function Duration:FormatRemainingDuration(formatter) return format(formatter, self:GetRemainingDuration()) end
function Duration:FormatTotalDuration(formatter) return format(formatter, self.duration) end

implementations.LuaDurationObject = function()
	return newObject(Duration, { startTime = 0, duration = 0, modRate = 1 })
end

-- Number abbreviation ----------------------------------------------------------------------------------------
-- Breakpoints, largest first: { breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e5,
-- fractionDivisor = 10, abbreviationIsGlobal = false }, as AbbreviateNumbers and the formatters take them.

local DEFAULT_BREAKPOINTS = {
	{ breakpoint = 1e10, abbreviation = "SECOND_NUMBER_CAP_NO_SPACE", significandDivisor = 1e9, fractionDivisor = 1, abbreviationIsGlobal = true },
	{ breakpoint = 1e9, abbreviation = "SECOND_NUMBER_CAP_NO_SPACE", significandDivisor = 1e8, fractionDivisor = 10, abbreviationIsGlobal = true },
	{ breakpoint = 1e7, abbreviation = "FIRST_NUMBER_CAP_NO_SPACE", significandDivisor = 1e6, fractionDivisor = 1, abbreviationIsGlobal = true },
	{ breakpoint = 1e6, abbreviation = "FIRST_NUMBER_CAP_NO_SPACE", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = true },
	{ breakpoint = 1e4, abbreviation = "K", significandDivisor = 1e3, fractionDivisor = 1, abbreviationIsGlobal = false },
	{ breakpoint = 1e3, abbreviation = "K", significandDivisor = 1e2, fractionDivisor = 10, abbreviationIsGlobal = false },
}
local GLOBAL_FALLBACK = { SECOND_NUMBER_CAP_NO_SPACE = "B", FIRST_NUMBER_CAP_NO_SPACE = "M" }

local function sortedBreakpoints(list)
	local out = {}
	for i, b in ipairs(list or {}) do
		out[i] = b
	end
	sort(out, function(a, b) return (a.breakpoint or 0) > (b.breakpoint or 0) end)
	return out
end

local function abbreviate(value, breakpoints)
	value = tonumber(value)
	if not value then
		return ""
	end
	local negative = value < 0
	local magnitude = negative and -value or value
	for _, data in ipairs(breakpoints) do
		if magnitude >= (data.breakpoint or 0) then
			local significand = data.significandDivisor or 1
			local fraction = data.fractionDivisor or 1
			local abbreviation = data.abbreviation or ""
			if data.abbreviationIsGlobal then
				abbreviation = rawget(_G, abbreviation) or GLOBAL_FALLBACK[abbreviation] or abbreviation
			end
			local final = floor(magnitude / significand) / fraction
			return (negative and "-" or "") .. tostring(final) .. abbreviation
		end
	end
	return tostring(floor(value) == value and value or floor(value * 10 + 0.5) / 10)
end

local AbbreviateConfig = {}
function AbbreviateConfig:GetAbbreviateNumberData() return self.data end
function AbbreviateConfig:SetAbbreviateNumberData(data) self.data = sortedBreakpoints(data) end

implementations.AbbreviateConfig = function(data)
	return newObject(AbbreviateConfig, { data = sortedBreakpoints(data or DEFAULT_BREAKPOINTS) })
end

local function breakpointsOf(options)
	if type(options) == "table" then
		local config = options.config
		if type(config) == "table" and config.data then
			return config.data
		end
		local data = options.breakpointData or options.breakpoints
		if type(data) == "table" and #data > 0 then
			return sortedBreakpoints(data)
		end
	end
	return DEFAULT_BREAKPOINTS
end

local function define(name, fn)
	if rawget(_G, name) == nil then
		_G[name] = fn
	end
end

define("AbbreviateNumbers", function(value, options)
	return abbreviate(value, breakpointsOf(options))
end)


define("CreateAbbreviateConfig", function(data)
	return implementations.AbbreviateConfig(data)
end)

local NumberFormatter = {}
function NumberFormatter:AddBreakpoint(breakpoint)
	if type(breakpoint) == "table" then
		tinsert(self.breakpoints, breakpoint)
		self.breakpoints = sortedBreakpoints(self.breakpoints)
	end
end
function NumberFormatter:ClearBreakpoints() self.breakpoints = {} end
function NumberFormatter:ResetBreakpoints() self.breakpoints = sortedBreakpoints(DEFAULT_BREAKPOINTS) end
function NumberFormatter:GetBreakpoints() return self.breakpoints end
function NumberFormatter:SetBreakpoints(list) self.breakpoints = sortedBreakpoints(list) end
function NumberFormatter:FormatNumber(value)
	if #self.breakpoints == 0 then
		value = tonumber(value) or 0
		return tostring(floor(value) == value and value or floor(value * 10 + 0.5) / 10)
	end
	return abbreviate(value, self.breakpoints)
end
function NumberFormatter:Copy()
	local copy = newObject(NumberFormatter, { breakpoints = {} })
	copy:SetBreakpoints(self.breakpoints)
	return copy
end

implementations.AbbreviatedNumberFormatter = function()
	return newObject(NumberFormatter, { breakpoints = sortedBreakpoints(DEFAULT_BREAKPOINTS) })
end
implementations.NumericRuleFormatter = function()
	return newObject(NumberFormatter, { breakpoints = {} })
end

-- Seconds: "1h 5m", "45s" (or "1 Hour 5 Min" unabbreviated), up to the desired number of units.
local SecondsFormatter = {}
local UNITS = {
	{ 86400, "d", " Day", " Days" }, { 3600, "h", " Hr", " Hr" }, { 60, "m", " Min", " Min" }, { 1, "s", " Sec", " Sec" },
}
function SecondsFormatter:Format(seconds, abbreviation)
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then
		return self:FormatZero(abbreviation)
	end
	local short = (abbreviation or self.abbreviation or 1) ~= 0
	local wanted = self.unitCount or 2
	local parts = {}
	local remaining = floor(seconds + 0.5)
	for _, unit in ipairs(UNITS) do
		if #parts < wanted and remaining >= unit[1] then
			local count = floor(remaining / unit[1])
			remaining = remaining - count * unit[1]
			parts[#parts + 1] = count .. (short and unit[2] or (count == 1 and unit[3] or unit[4]))
		end
	end
	local text = table.concat(parts, " ")
	return self.lower and text:lower() or text
end
function SecondsFormatter:FormatNumber(seconds) return self:Format(seconds) end
function SecondsFormatter:FormatZero(abbreviation)
	local short = (abbreviation or self.abbreviation or 1) ~= 0
	return short and "0s" or "0 Sec"
end
function SecondsFormatter:SetDesiredUnitCount(count) self.unitCount = count end
function SecondsFormatter:GetDesiredUnitCount() return self.unitCount end
function SecondsFormatter:SetDefaultAbbreviation(abbreviation) self.abbreviation = abbreviation end
function SecondsFormatter:GetDefaultAbbreviation() return self.abbreviation end
function SecondsFormatter:SetConvertToLower(lower) self.lower = lower and true or false end
function SecondsFormatter:GetConvertToLower() return self.lower end
function SecondsFormatter:Reset()
	self.unitCount, self.abbreviation, self.lower = 2, 1, false
end

local function genericObject(typeName)
	local docs = rawget(_G, "ModernUI_ObjectMethodDocs")
	local answerFor = rawget(_G, "ModernUI_SurfaceAnswerFor")
	local methods = {}
	if type(docs) == "table" and answerFor then
		for _, group in ipairs({ typeName .. "API", typeName .. "ObjectAPI" }) do
			for name, rets in pairs(docs[group] or {}) do
				if methods[name] == nil then
					methods[name] = answerFor(rets)
				end
			end
		end
	end
	return methods
end

implementations.SecondsFormatter = function()
	local methods = genericObject("SecondsFormatter")
	for k, v in pairs(SecondsFormatter) do
		methods[k] = v
	end
	return newObject(methods, { unitCount = 2, abbreviation = 1, lower = false })
end

-- Anything else documented: its methods, answering empty.
local genericMethods = {}
function ModernUI_CreateObject(typeName, ...)
	local make = implementations[typeName]
	if make then
		return make(...)
	end
	local methods = genericMethods[typeName]
	if not methods then
		methods = genericObject(typeName)
		genericMethods[typeName] = methods
	end
	return newObject(methods, {})
end

-- The documented constructors (the generated surface also routes them here; these win where they exist).
local function namespace(name)
	local t = rawget(_G, name)
	if t == nil then
		t = {}
		_G[name] = t
	end
	return t
end
local function set(space, name, fn)
	if rawget(space, name) == nil then
		space[name] = fn
	end
end
local CurveUtil = namespace("C_CurveUtil")
set(CurveUtil, "CreateCurve", function() return ModernUI_CreateObject("LuaCurveObject") end)
set(CurveUtil, "CreateColorCurve", function() return ModernUI_CreateObject("LuaColorCurveObject") end)
set(CurveUtil, "EvaluateColorFromBoolean", function(value, trueColor, falseColor)
	return value and trueColor or falseColor
end)
set(CurveUtil, "EvaluateColorValueFromBoolean", function(value, trueValue, falseValue)
	if value then
		return trueValue or 1
	end
	return falseValue or 0
end)
local DurationUtil = namespace("C_DurationUtil")
set(DurationUtil, "CreateDuration", function() return ModernUI_CreateObject("LuaDurationObject") end)
set(DurationUtil, "CreateManualClock", function() return ModernUI_CreateObject("LuaDurationManualClock") end)
local StringUtil = namespace("C_StringUtil")
set(StringUtil, "CreateAbbreviatedNumberFormatter", function() return ModernUI_CreateObject("AbbreviatedNumberFormatter") end)
set(StringUtil, "CreateNumericRuleFormatter", function() return ModernUI_CreateObject("NumericRuleFormatter") end)
set(StringUtil, "CreateSecondsFormatter", function() return ModernUI_CreateObject("SecondsFormatter") end)
