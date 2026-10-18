-- ModernUI: built into the client (not in the original 3.3.5a).
-- C_Timer: After, NewTimer, NewTicker.

local _G = _G
if _G.C_Timer and _G.C_Timer.After then
	return
end

local GetTime, geterrorhandler, xpcall, type, error = GetTime, geterrorhandler, xpcall, type, error

local C_Timer = _G.C_Timer or {}
_G.C_Timer = C_Timer

local pending = {}  -- timers waiting to fire
local adding = {}   -- timers created while pending is being walked
local walking = false
local frame = CreateFrame("Frame")
frame:Hide()

local function errorHandler(err)
	return geterrorhandler()(err)
end

local function schedule(timer)
	if walking then
		adding[#adding + 1] = timer
	else
		pending[#pending + 1] = timer
	end
	frame:Show()
end

frame:SetScript("OnUpdate", function(self)
	local now = GetTime()
	walking = true
	local n = #pending
	local i = 1
	while i <= n do
		local timer = pending[i]
		if timer._cancelled then
			pending[i] = pending[n]
			pending[n] = nil
			n = n - 1
		elseif now >= timer._fireAt then
			if timer._ticker then
				timer._remaining = timer._remaining and (timer._remaining - 1)
				if timer._remaining and timer._remaining <= 0 then
					timer._cancelled = true
				else
					timer._fireAt = now + timer._interval
				end
				xpcall(function() timer._callback(timer) end, errorHandler)
			else
				timer._cancelled = true
				local callback = timer._callback
				if timer._handle then
					xpcall(function() callback(timer) end, errorHandler)
				else
					xpcall(callback, errorHandler)
				end
			end
			if timer._cancelled then
				pending[i] = pending[n]
				pending[n] = nil
				n = n - 1
			else
				i = i + 1
			end
		else
			i = i + 1
		end
	end
	walking = false
	for j = 1, #adding do
		pending[#pending + 1] = adding[j]
		adding[j] = nil
	end
	if #pending == 0 then
		self:Hide()
	end
end)

local TimerHandle = {}
TimerHandle.__index = TimerHandle

function TimerHandle:Cancel()
	self._cancelled = true
end

function TimerHandle:IsCancelled()
	return self._cancelled == true
end

-- Modern addons sometimes read the remaining time from a handle.
function TimerHandle:GetRemainingTime()
	return math.max(0, self._fireAt - GetTime())
end

local function checkArgs(name, seconds, callback)
	if type(seconds) ~= "number" then
		error(("Usage: C_Timer.%s(seconds, callback)"):format(name), 3)
	end
	if type(callback) ~= "function" and not (type(callback) == "table" and getmetatable(callback) and getmetatable(callback).__call) then
		error(("Usage: C_Timer.%s(seconds, callback)"):format(name), 3)
	end
end

function C_Timer.After(seconds, callback)
	checkArgs("After", seconds, callback)
	schedule({ _fireAt = GetTime() + seconds, _callback = callback })
end

function C_Timer.NewTimer(seconds, callback)
	checkArgs("NewTimer", seconds, callback)
	local timer = setmetatable({ _fireAt = GetTime() + seconds, _callback = callback, _handle = true }, TimerHandle)
	schedule(timer)
	return timer
end

function C_Timer.NewTicker(seconds, callback, iterations)
	checkArgs("NewTicker", seconds, callback)
	local interval = seconds > 0 and seconds or 0.001
	local timer = setmetatable({
		_fireAt = GetTime() + interval,
		_interval = interval,
		_callback = callback,
		_ticker = true,
		_handle = true,
		_remaining = iterations,
	}, TimerHandle)
	schedule(timer)
	return timer
end
