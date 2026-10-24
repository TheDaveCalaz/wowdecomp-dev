-- ModernUI: built into the client (not in the original 3.3.5a).
-- The last line of defence for the modern API: a function of a C_ namespace, or an Enum group, that nothing
-- here knows (not documented, not in Blizzard's own interface code) is made on first use instead of failing.
-- A function answers as a client with nothing to report would (GetNum... 0, Is/Has/Can... false, anything else
-- nothing); an Enum group numbers its values in the order they are read. Each one is noted once in
-- Logs\LuaErrors.log, so what AddOns reach for can be filled in properly.

local _G = _G
local type, rawget, rawset, setmetatable, getmetatable, pairs = type, rawget, rawset, setmetatable, getmetatable, pairs
local log = _G.ModernUI_Log or function() end

local function zero() return 0 end
local function no() return false end
local function nothing() end
local function answer(name)
	if name:find("^GetNum") then
		return zero
	elseif name:find("^Is") or name:find("^Has") or name:find("^Can") or name:find("^Should") then
		return no
	end
	return nothing
end

local function namespaceMeta(namespace)
	return {
		__index = function(t, key)
			if type(key) ~= "string" or not key:find("^[A-Z]") then
				return nil
			end
			local fn = answer(key)
			rawset(t, key, fn)
			log("ModernUI: " .. namespace .. "." .. key .. " is not known to this client; it answers with nothing")
			return fn
		end,
	}
end

for name, value in pairs(_G) do
	if type(name) == "string" and name:find("^C_%u") and type(value) == "table" and getmetatable(value) == nil then
		setmetatable(value, namespaceMeta(name))
	end
end

-- Enum groups nobody defined: values numbered as they are read.
local Enum = rawget(_G, "Enum")
if type(Enum) == "table" and getmetatable(Enum) == nil then
	setmetatable(Enum, {
		__index = function(t, group)
			if type(group) ~= "string" or not group:find("^%u") then
				return nil
			end
			local count = 0
			local values = setmetatable({}, {
				__index = function(values, key)
					if type(key) ~= "string" then
						return nil
					end
					local value = count
					count = count + 1
					rawset(values, key, value)
					return value
				end,
			})
			rawset(t, group, values)
			log("ModernUI: Enum." .. group .. " is not known to this client; its values are numbered as read")
			return values
		end,
	})
end
