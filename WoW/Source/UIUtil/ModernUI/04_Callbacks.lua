-- ModernUI: built into the client (not in the original 3.3.5a).
-- CallbackRegistryMixin, EventRegistry, EventUtil and FrameUtil, as modern addons use them.

local _G = _G
local pairs, next, select, type, error, securecall = pairs, next, select, type, error, securecall

local CallbackType = { Closure = 1, Function = 2 }

local CallbackRegistryMixin = _G.CallbackRegistryMixin or {}
_G.CallbackRegistryMixin = CallbackRegistryMixin

function CallbackRegistryMixin:OnLoad()
	self.callbackTables = { [CallbackType.Closure] = {}, [CallbackType.Function] = {} }
	self.anonymousOwnerID = 0
	if self.isUndefinedEventAllowed == nil then
		self.isUndefinedEventAllowed = false
	end
end

function CallbackRegistryMixin:SetUndefinedEventsAllowed(allowed)
	self.isUndefinedEventAllowed = allowed
end

function CallbackRegistryMixin:GenerateCallbackEvents(events)
	self.Event = self.Event or {}
	for _, event in ipairs(events) do
		self.Event[event] = event
	end
end

local function getOrCreate(tbl, key)
	local value = tbl[key]
	if not value then
		value = {}
		tbl[key] = value
	end
	return value
end

local function checkEvent(self, event)
	if not self.callbackTables then
		CallbackRegistryMixin.OnLoad(self)
	end
	if type(event) ~= "string" and type(event) ~= "number" then
		error("CallbackRegistryMixin: event must be a string or number")
	end
	if not self.isUndefinedEventAllowed and self.Event and not self.Event[event] then
		error(("CallbackRegistryMixin: event '%s' doesn't exist."):format(tostring(event)))
	end
end

function CallbackRegistryMixin:RegisterCallback(event, func, owner, ...)
	checkEvent(self, event)
	if type(func) ~= "function" then
		error("CallbackRegistryMixin:RegisterCallback 'func' requires a function")
	end
	if owner == nil then
		self.anonymousOwnerID = self.anonymousOwnerID + 1
		owner = self.anonymousOwnerID
	elseif type(owner) == "number" then
		error("CallbackRegistryMixin:RegisterCallback 'owner' cannot be a number")
	end

	local count = select("#", ...)
	if count > 0 then
		local closure = GenerateClosure(func, owner, ...)
		getOrCreate(self.callbackTables[CallbackType.Closure], event)[owner] = closure
	else
		getOrCreate(self.callbackTables[CallbackType.Function], event)[owner] = func
	end
	return owner
end

function CallbackRegistryMixin:RegisterCallbackWithHandle(event, func, owner, ...)
	owner = self:RegisterCallback(event, func, owner, ...)
	local registry = self
	return {
		Unregister = function()
			registry:UnregisterCallback(event, owner)
		end,
	}
end

function CallbackRegistryMixin:UnregisterCallback(event, owner)
	if owner == nil then
		error("CallbackRegistryMixin:UnregisterCallback 'owner' is required")
	end
	if not self.callbackTables then
		return
	end
	for _, callbacks in pairs(self.callbackTables) do
		local tbl = callbacks[event]
		if tbl then
			tbl[owner] = nil
		end
	end
end

function CallbackRegistryMixin:UnregisterEvents(eventTable)
	if not self.callbackTables then
		return
	end
	if eventTable then
		for event in pairs(eventTable) do
			for _, callbacks in pairs(self.callbackTables) do
				callbacks[event] = nil
			end
		end
	else
		self.callbackTables = { [CallbackType.Closure] = {}, [CallbackType.Function] = {} }
	end
end

function CallbackRegistryMixin:DoesFrameHaveEvent(event)
	return self.Event and self.Event[event] ~= nil
end

function CallbackRegistryMixin:HasRegistrantsForEvent(event)
	if not self.callbackTables then
		return false
	end
	for _, callbacks in pairs(self.callbackTables) do
		if callbacks[event] and next(callbacks[event]) then
			return true
		end
	end
	return false
end

function CallbackRegistryMixin:GetCallbackTables()
	return self.callbackTables
end

function CallbackRegistryMixin:TriggerEvent(event, ...)
	if not self.callbackTables then
		return
	end
	if not self.isUndefinedEventAllowed and self.Event and not self.Event[event] then
		error(("CallbackRegistryMixin:TriggerEvent event '%s' doesn't exist."):format(tostring(event)))
	end

	-- Copy first so callbacks can unregister themselves (or others) while the event runs.
	local closures = self.callbackTables[CallbackType.Closure][event]
	if closures and next(closures) then
		local list = {}
		for owner, closure in pairs(closures) do
			list[owner] = closure
		end
		for _, closure in pairs(list) do
			securecall(closure, ...)
		end
	end

	local funcs = self.callbackTables[CallbackType.Function][event]
	if funcs and next(funcs) then
		local list = {}
		for owner, func in pairs(funcs) do
			list[owner] = func
		end
		for owner, func in pairs(list) do
			securecall(func, owner, ...)
		end
	end
end

-- The "WithCount" variant some code uses behaves the same here.
CallbackRegistryMixin.RegisterCallbackWithCount = CallbackRegistryMixin.RegisterCallback

if _G.CreateCallbackRegistry == nil then
	function _G.CreateCallbackRegistry()
		local registry = CreateFromMixins(CallbackRegistryMixin)
		registry:OnLoad()
		registry:SetUndefinedEventsAllowed(true)
		return registry
	end
end

-- Lightweight callback handle list some modern code expects.
_G.CallbackRegistrantMixin = _G.CallbackRegistrantMixin or {
	AddDynamicEventMethod = function(self, registry, event, method)
		self.dynamicEvents = self.dynamicEvents or {}
		self.dynamicEvents[#self.dynamicEvents + 1] = { registry, event, method }
	end,
	SetEventsDynamic = function(self, enabled)
		for _, entry in ipairs(self.dynamicEvents or {}) do
			if enabled then
				entry[1]:RegisterCallback(entry[2], entry[3], self)
			else
				entry[1]:UnregisterCallback(entry[2], self)
			end
		end
	end,
}

-- EventRegistry: one shared registry; also lets code subscribe to game events without a frame.
if _G.EventRegistry == nil then
	local registry = CreateFromMixins(CallbackRegistryMixin)
	registry:OnLoad()
	registry:SetUndefinedEventsAllowed(true)

	local frame = CreateFrame("Frame")
	local frameEventCounts = {}

	frame:SetScript("OnEvent", function(_, event, ...)
		registry:TriggerEvent(event, ...)
	end)

	function registry:RegisterFrameEvent(event)
		frameEventCounts[event] = (frameEventCounts[event] or 0) + 1
		if frameEventCounts[event] == 1 then
			frame:RegisterEvent(event)
		end
	end

	function registry:UnregisterFrameEvent(event)
		local count = frameEventCounts[event]
		if count then
			count = count - 1
			if count <= 0 then
				frameEventCounts[event] = nil
				frame:UnregisterEvent(event)
			else
				frameEventCounts[event] = count
			end
		end
	end

	function registry:RegisterFrameEventAndCallback(event, func, owner, ...)
		self:RegisterFrameEvent(event)
		return self:RegisterCallback(event, func, owner, ...)
	end

	function registry:RegisterFrameEventAndCallbackWithHandle(event, func, owner, ...)
		self:RegisterFrameEvent(event)
		owner = self:RegisterCallback(event, func, owner, ...)
		local this = self
		return {
			Unregister = function()
				this:UnregisterFrameEventAndCallback(event, owner)
			end,
		}
	end

	function registry:UnregisterFrameEventAndCallback(event, owner)
		self:UnregisterFrameEvent(event)
		self:UnregisterCallback(event, owner)
	end

	_G.EventRegistry = registry
end

-- EventUtil ------------------------------------------------------------------------------------

local EventUtil = _G.EventUtil or {}
_G.EventUtil = EventUtil

function EventUtil.RegisterOnceFrameEventAndCallback(event, callback, ...)
	local owner = {}
	local args = SafePack(...)
	local function handler(o, ...)
		EventRegistry:UnregisterFrameEventAndCallback(event, owner)
		callback(...)
	end
	EventRegistry:RegisterFrameEventAndCallback(event, handler, owner)
end

function EventUtil.ContinueOnAddOnLoaded(addOnName, callback)
	if IsAddOnLoaded(addOnName) then
		callback()
		return
	end
	local owner = {}
	EventRegistry:RegisterFrameEventAndCallback("ADDON_LOADED", function(o, loaded)
		if loaded == addOnName then
			EventRegistry:UnregisterFrameEventAndCallback("ADDON_LOADED", owner)
			callback()
		end
	end, owner)
end

function EventUtil.ContinueOnPlayerLogin(callback)
	if IsLoggedIn() then
		callback()
		return
	end
	EventUtil.RegisterOnceFrameEventAndCallback("PLAYER_LOGIN", callback)
end

function EventUtil.ContinueAfterAllEvents(callback, ...)
	local remaining = select("#", ...)
	if remaining == 0 then
		callback()
		return
	end
	for i = 1, remaining do
		EventUtil.RegisterOnceFrameEventAndCallback((select(i, ...)), function()
			remaining = remaining - 1
			if remaining == 0 then
				callback()
			end
		end)
	end
end

function EventUtil.CreateCallbackHandleContainer()
	local container = { handles = {} }
	function container:AddHandle(handle) self.handles[#self.handles + 1] = handle end
	function container:RegisterCallback(registry, event, func, owner, ...)
		self:AddHandle(registry:RegisterCallbackWithHandle(event, func, owner, ...))
	end
	function container:Unregister()
		for _, handle in ipairs(self.handles) do
			handle:Unregister()
		end
		self.handles = {}
	end
	function container:IsEmpty() return #self.handles == 0 end
	return container
end

function EventUtil.TriggerOnVariablesLoaded(callback)
	EventUtil.RegisterOnceFrameEventAndCallback("VARIABLES_LOADED", callback)
end

-- FrameUtil ------------------------------------------------------------------------------------

local FrameUtil = _G.FrameUtil or {}
_G.FrameUtil = FrameUtil

function FrameUtil.RegisterFrameForEvents(frame, events)
	for _, event in ipairs(events) do
		frame:RegisterEvent(event)
	end
end

function FrameUtil.UnregisterFrameForEvents(frame, events)
	for _, event in ipairs(events) do
		frame:UnregisterEvent(event)
	end
end

function FrameUtil.RegisterFrameForUnitEvents(frame, events, ...)
	for _, event in ipairs(events) do
		frame:RegisterUnitEvent(event, ...)
	end
end

function FrameUtil.RegisterUpdateFunction(frame, frequencySeconds, func)
	local elapsed = 0
	frame:SetScript("OnUpdate", function(self, delta)
		elapsed = elapsed + delta
		if elapsed >= frequencySeconds then
			elapsed = 0
			func(self)
		end
	end)
end

function FrameUtil.UnregisterUpdateFunction(frame)
	frame:SetScript("OnUpdate", nil)
end

function FrameUtil.SpecializeFrameWithMixins(frame, ...)
	Mixin(frame, ...)
	if frame.OnLoad then
		frame:OnLoad()
	end
end

function FrameUtil.DialogStyleGlobalMouseDown() end

function FrameUtil.GetRootParent(frame)
	local parent = frame
	while parent:GetParent() do
		parent = parent:GetParent()
	end
	return parent
end

-- ScriptRegion helpers that old code paths call on mixed-in frames.
if _G.RunNextFrame == nil then
	function _G.RunNextFrame(callback)
		C_Timer.After(0, callback)
	end
end
