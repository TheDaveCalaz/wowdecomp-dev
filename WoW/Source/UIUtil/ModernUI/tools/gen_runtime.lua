
local _G = _G
local type, rawget, unpack, select, ipairs, pairs = type, rawget, unpack, select, ipairs, pairs

-- One shared answer per return signature ("b0t" = false, 0, a new table; c = a white colour, v and w = zero
-- 2D and 3D vectors; {Type} = a new object of a documented object type, such as a curve or a duration, made
-- by ModernUI_CreateObject in 35_Objects.lua).
local answers = {}
local function answerFor(rets)
	if rets == "" then
		return function() end
	end
	local cached = answers[rets]
	if cached then
		return cached
	end
	local tokens = {}
	local i = 1
	while i <= #rets do
		local c = rets:sub(i, i)
		if c == "{" then
			local close = rets:find("}", i, true)
			tokens[#tokens + 1] = rets:sub(i, close)
			i = close + 1
		else
			tokens[#tokens + 1] = c
			i = i + 1
		end
	end
	local n = #tokens
	local f
	if not rets:find("[tcvw{]") then
		local values = {}
		for k = 1, n do
			local c = tokens[k]
			values[k] = (c == "b" and false) or (c == "0" and 0) or (c == "s" and "") or nil
		end
		f = function() return unpack(values, 1, n) end
	else
		f = function()
			local values = {}
			for k = 1, n do
				local c = tokens[k]
				if c:sub(1, 1) == "{" then
					local create = rawget(_G, "ModernUI_CreateObject")
					values[k] = create and create(c:sub(2, -2)) or nil
				else
					values[k] = (c == "b" and false) or (c == "0" and 0) or (c == "s" and "") or (c == "t" and {})
						or (c == "c" and CreateColor(1, 1, 1, 1)) or (c == "v" and CreateVector2D(0, 0))
						or (c == "w" and CreateVector3D(0, 0, 0)) or nil
				end
			end
			return unpack(values, 1, n)
		end
	end
	answers[rets] = f
	return f
end
_G.ModernUI_SurfaceAnswerFor = answerFor

-- Functions.
for i = 1, #F, 3 do
	local ns, name, rets = F[i], F[i + 1], F[i + 2]
	if ns == "" then
		if rawget(_G, name) == nil then
			_G[name] = answerFor(rets)
		end
	else
		local space = rawget(_G, ns)
		if space == nil then
			space = {}
			_G[ns] = space
		end
		if type(space) == "table" and rawget(space, name) == nil then
			space[name] = answerFor(rets)
		end
	end
end

-- Enums and constants: Blizzard's values, filling only what is not already there.
local Enum = rawget(_G, "Enum") or {}
_G.Enum = Enum
for name, fields in pairs(E) do
	local t = rawget(Enum, name)
	if t == nil then
		t = {}
		Enum[name] = t
	end
	for k, v in pairs(fields) do
		if rawget(t, k) == nil then
			t[k] = v
		end
	end
end
local Constants = rawget(_G, "Constants") or {}
_G.Constants = Constants
for name, values in pairs(C) do
	local t = rawget(Constants, name)
	if t == nil then
		t = {}
		Constants[name] = t
	end
	for k, v in pairs(values) do
		if rawget(t, k) == nil then
			t[k] = v
		end
	end
end

-- Widget methods, onto this client's widget types (only where the type has no such method).
local tables = rawget(_G, "ModernUI_WidgetMethodTables")
if type(tables) == "table" then
	local frames = { "Frame", "Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar", "Cooldown",
		"ColorSelect", "GameTooltip", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "Model", "PlayerModel",
		"DressUpModel", "TabardModel", "MovieFrame", "QuestPOIFrame", "Minimap" }
	local regions = { "Texture", "FontString" }
	local anims = { "Animation", "Alpha", "Scale", "Translation", "Rotation", "Path" }
	local models = { "Model", "PlayerModel", "DressUpModel", "TabardModel" }
	local function all(...)
		local out = {}
		for i = 1, select("#", ...) do
			for _, k in ipairs((select(i, ...))) do out[#out + 1] = k end
		end
		return out
	end
	local targets = {
		SimpleObjectAPI = all(frames, regions, anims, { "AnimationGroup" }),
		SimpleFrameScriptObjectAPI = all(frames, regions, anims, { "AnimationGroup" }),
		SimpleRegionAPI = all(frames, regions),
		SimpleScriptRegionAPI = all(frames, regions),
		SimpleScriptRegionResizingAPI = all(frames, regions),
		SimpleFrameAPI = frames,
		SimpleButtonAPI = { "Button", "CheckButton" },
		SimpleCheckboxAPI = { "CheckButton" },
		SimpleEditBoxAPI = { "EditBox" },
		SimpleFontStringAPI = { "FontString" },
		SimpleTextureBaseAPI = { "Texture" },
		SimpleStatusBarAPI = { "StatusBar" },
		SimpleSliderAPI = { "Slider" },
		SimpleScrollFrameAPI = { "ScrollFrame" },
		SimpleMessageFrameAPI = { "MessageFrame", "ScrollingMessageFrame" },
		SimpleHTMLAPI = { "SimpleHTML" },
		SimpleColorSelectAPI = { "ColorSelect" },
		SimpleModelAPI = models,
		FrameAPICharacterModelBase = { "PlayerModel", "DressUpModel", "TabardModel" },
		FrameAPIDressUpModel = { "DressUpModel" },
		FrameAPITabardModelBase = { "TabardModel" },
		FrameAPITabardModel = { "TabardModel" },
		FrameAPICooldown = { "Cooldown" },
		FrameAPITooltip = { "GameTooltip" },
		MinimapFrameAPI = { "Minimap" },
		SimpleAnimAPI = anims,
		SimpleAnimGroupAPI = { "AnimationGroup" },
		SimpleAnimAlphaAPI = { "Alpha" },
		SimpleAnimScaleAPI = { "Scale" },
		SimpleAnimRotationAPI = { "Rotation" },
		SimpleAnimPathAPI = { "Path" },
		SimpleAnimTranslationAPI = { "Translation" },
	}
	for i = 1, #M, 3 do
		local group, name, rets = M[i], M[i + 1], M[i + 2]
		local kinds = targets[group]
		if kinds then
			for _, kind in ipairs(kinds) do
				local index = tables[kind]
				if type(index) == "table" and rawget(index, name) == nil then
					index[name] = answerFor(rets)
				end
			end
		end
	end
end

-- The documented methods of each object type (LuaCurveObjectAPI = { AddPoint = "", ... }), for objects of
-- types that have no hand-written implementation (35_Objects.lua).
do
	local docs = {}
	for i = 1, #M, 3 do
		local group = M[i]
		docs[group] = docs[group] or {}
		docs[group][M[i + 1]] = M[i + 2]
	end
	_G.ModernUI_ObjectMethodDocs = docs
end
