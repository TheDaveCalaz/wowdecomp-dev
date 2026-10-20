-- Loads the generated API surface on top of the other files and checks it fills gaps without replacing.
-- Usage: python3 run.py test_surface.lua
local before = C_Container.GetContainerItemInfo
local f = assert(loadstring(assert(io.open("../95_ApiSurface.lua")):read("*a"), "95_ApiSurface.lua"))
local ok, err = pcall(f)
assert(ok, err)
assert(C_Container.GetContainerItemInfo == before, "hand-written functions are kept")
assert(type(C_Housing) == "table" and next(C_Housing) ~= nil, "missing systems are filled in")
assert(Enum.AccountData and Enum.AccountData.Config == 0, "enums from the documentation")
assert(type(getmetatable(CreateFrame("Frame")).__index) == "table", "method tables stay tables")
local n, missing = 0, 0
print("ok   generated surface loads and fills gaps")
print("ALL PASSED")
