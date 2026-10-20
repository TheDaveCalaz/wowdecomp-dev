-- Guards against changes that break AddOn libraries reading frames' method tables directly.
-- Usage: python3 run.py test_guard.lua
for _, kind in ipairs({ "Frame", "Button", "CheckButton", "EditBox", "Slider", "StatusBar" }) do
	local f = CreateFrame(kind)
	local index = getmetatable(f).__index
	assert(type(index) == "table", kind .. ": method table must stay a table (libraries iterate it)")
end
local t = CreateFrame("Frame"):CreateTexture()
assert(type(getmetatable(t).__index) == "table", "Texture: method table must stay a table")
print("ok   method tables are tables")
print("ALL PASSED")
