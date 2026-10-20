local _G = _G
local env = setmetatable({}, { __index = _G })
local log = ModernUI_Log or function() end

-- Enum and Constants groups of newer clients that this one lacks read as tables of placeholder numbers
-- inside the shared code, so a lookup table keyed by one does not stop a whole file from loading.
local sentinel = -100000
local function placeholders()
	return setmetatable({}, { __index = function(t, key)
		sentinel = sentinel - 1
		rawset(t, key, sentinel)
		return sentinel
	end })
end
local function softGroups(real)
	return setmetatable({}, { __index = function(t, key)
		local value = real and real[key]
		if value == nil then
			value = placeholders()
		end
		rawset(t, key, value)
		return value
	end })
end
local private = { Enum = true, Constants = true }
rawset(env, "Enum", softGroups(_G.Enum))
rawset(env, "Constants", softGroups(_G.Constants))

for _, source in ipairs(sources) do
	local name, text = source[1], source[2]
	local chunk, err = loadstring(text, "@Interface\\ModernUI\\Blizzard\\" .. name)
	if chunk then
		setfenv(chunk, env)
		local ok, runErr = pcall(chunk, "Blizzard", {})
		if not ok then
			log("ModernUI: Blizzard shared code " .. name .. " stopped part-way: " .. tostring(runErr))
		end
	else
		log("ModernUI: Blizzard shared code " .. name .. " did not compile: " .. tostring(err))
	end
end

local added = 0
for key, value in pairs(env) do
	if not private[key] and rawget(_G, key) == nil then
		_G[key] = value
		added = added + 1
	end
end
_G.ModernUI_BlizzardSharedEnvironment = env
sources = nil
