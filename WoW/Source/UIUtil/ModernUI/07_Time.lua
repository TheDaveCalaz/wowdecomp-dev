-- ModernUI: built into the client (not in the original 3.3.5a).
-- SecondsFormatter and the number formatting helpers modern addons use.

local _G = _G
local floor, ceil, max, type, ipairs = math.floor, math.ceil, math.max, type, ipairs

local function define(name, value)
	if _G[name] == nil then
		_G[name] = value
	end
end

define("CallErrorHandler", function(...)
	return geterrorhandler()(...)
end)

-- Numbers ----------------------------------------------------------------------------------------

define("BreakUpLargeNumbers", function(value)
	return FormatLargeNumber(value)
end)

define("AbbreviateLargeNumbers", function(value)
	local abs = value < 0 and -value or value
	if abs >= 1e9 then
		return ("%.1fB"):format(value / 1e9)
	elseif abs >= 1e6 then
		return ("%.1fM"):format(value / 1e6)
	elseif abs >= 1e4 then
		return ("%dK"):format(floor(value / 1e3))
	end
	return BreakUpLargeNumbers(value)
end)

define("AbbreviateNumbers", function(value)
	local abs = value < 0 and -value or value
	if abs >= 1e9 then
		return ("%.2fB"):format(value / 1e9):gsub("%.?0+B$", "B")
	elseif abs >= 1e6 then
		return ("%.2fM"):format(value / 1e6):gsub("%.?0+M$", "M")
	elseif abs >= 1e3 then
		return ("%.2fK"):format(value / 1e3):gsub("%.?0+K$", "K")
	end
	return tostring(floor(value))
end)

-- SecondsFormatter -------------------------------------------------------------------------------

local SecondsFormatter = _G.SecondsFormatter or {}
_G.SecondsFormatter = SecondsFormatter
SecondsFormatter.Abbreviation = SecondsFormatter.Abbreviation or { None = 1, Truncate = 2, OneLetter = 3 }
SecondsFormatter.Interval = SecondsFormatter.Interval or { Seconds = 1, Minutes = 2, Hours = 3, Days = 4 }
SecondsFormatter.IntervalDescription = SecondsFormatter.IntervalDescription or {
	{ seconds = 1, formatString = { D_SECONDS or "%d |4Second:Seconds;", SECONDS_ABBR or "%d |4Sec:Sec;", SECOND_ONELETTER_ABBR or "%d s" } },
	{ seconds = 60, formatString = { D_MINUTES or "%d |4Minute:Minutes;", MINUTES_ABBR or "%d |4Min:Min;", MINUTE_ONELETTER_ABBR or "%d m" } },
	{ seconds = 3600, formatString = { D_HOURS or "%d |4Hour:Hours;", HOURS_ABBR or "%d |4Hr:Hr;", HOUR_ONELETTER_ABBR or "%d h" } },
	{ seconds = 86400, formatString = { D_DAYS or "%d |4Day:Days;", DAYS_ABBR or "%d |4Day:Days;", DAY_ONELETTER_ABBR or "%d d" } },
}

local SecondsFormatterMixin = _G.SecondsFormatterMixin or {}
_G.SecondsFormatterMixin = SecondsFormatterMixin

function SecondsFormatterMixin:Init(approximationSeconds, defaultAbbreviation, roundUpLastUnit, convertToLower, roundUpIntervals)
	self.approximationSeconds = approximationSeconds or 0
	self.defaultAbbreviation = defaultAbbreviation or SecondsFormatter.Abbreviation.None
	self.roundUpLastUnit = roundUpLastUnit
	self.convertToLower = convertToLower
	self.roundUpIntervals = roundUpIntervals
	self.stripIntervalWhitespace = false
	self.minInterval = SecondsFormatter.Interval.Seconds
	self.desiredUnitCount = 2
end
function SecondsFormatterMixin:SetDefaultAbbreviation(abbreviation) self.defaultAbbreviation = abbreviation end
function SecondsFormatterMixin:GetDefaultAbbreviation() return self.defaultAbbreviation end
function SecondsFormatterMixin:SetApproximationSeconds(seconds) self.approximationSeconds = seconds end
function SecondsFormatterMixin:GetApproximationSeconds() return self.approximationSeconds end
function SecondsFormatterMixin:SetStripIntervalWhitespace(strip) self.stripIntervalWhitespace = strip end
function SecondsFormatterMixin:GetStripIntervalWhitespace() return self.stripIntervalWhitespace end
function SecondsFormatterMixin:SetMinInterval(interval) self.minInterval = interval end
function SecondsFormatterMixin:GetMinInterval() return self.minInterval or SecondsFormatter.Interval.Seconds end
function SecondsFormatterMixin:SetDesiredUnitCount(count) self.desiredUnitCount = count end
function SecondsFormatterMixin:GetDesiredUnitCount() return self.desiredUnitCount or 2 end
function SecondsFormatterMixin:SetCanRoundUpLastUnit(round) self.roundUpLastUnit = round end
function SecondsFormatterMixin:CanRoundUpLastUnit() return self.roundUpLastUnit end
function SecondsFormatterMixin:SetConvertToLower(lower) self.convertToLower = lower end
function SecondsFormatterMixin:GetMaxInterval() return #SecondsFormatter.IntervalDescription end
function SecondsFormatterMixin:GetIntervalDescription(interval) return SecondsFormatter.IntervalDescription[interval] end
function SecondsFormatterMixin:GetIntervalSeconds(interval)
	local description = self:GetIntervalDescription(interval)
	return description and description.seconds
end
function SecondsFormatterMixin:CanApproximate(seconds)
	return seconds > 0 and seconds < (self.approximationSeconds or 0)
end

function SecondsFormatterMixin:FormatZero(abbreviation)
	local description = self:GetIntervalDescription(self:GetMinInterval())
	local text = description.formatString[abbreviation or self.defaultAbbreviation]:format(0)
	if self.stripIntervalWhitespace then
		text = text:gsub(" ", "")
	end
	return text
end

function SecondsFormatterMixin:Format(seconds, round, abbreviation)
	seconds = max(tonumber(seconds) or 0, 0)
	abbreviation = abbreviation or self.defaultAbbreviation

	if self:CanApproximate(seconds) then
		local description = self:GetIntervalDescription(self:GetMinInterval())
		local text = "< " .. description.formatString[abbreviation]:format(ceil(self.approximationSeconds / description.seconds))
		return self.convertToLower and text:lower() or text
	end

	local parts = {}
	local remaining = seconds
	local desired = self:GetDesiredUnitCount()
	local minInterval = self:GetMinInterval()

	for interval = self:GetMaxInterval(), minInterval, -1 do
		local description = self:GetIntervalDescription(interval)
		local size = description.seconds
		local last = (#parts + 1 == desired) or interval == minInterval
		local count
		if last and (round or self.roundUpLastUnit) then
			count = ceil(remaining / size)
		else
			count = floor(remaining / size)
		end
		if count > 0 or (interval == minInterval and #parts == 0) then
			local text = description.formatString[abbreviation]:format(count)
			if self.stripIntervalWhitespace then
				text = text:gsub(" ", "")
			end
			parts[#parts + 1] = text
			remaining = remaining - count * size
			if #parts >= desired then
				break
			end
		end
	end

	local text = table.concat(parts, " ")
	return self.convertToLower and text:lower() or text
end

define("CreateSecondsFormatter", function(...)
	local formatter = CreateFromMixins(SecondsFormatterMixin)
	formatter:Init(...)
	return formatter
end)
