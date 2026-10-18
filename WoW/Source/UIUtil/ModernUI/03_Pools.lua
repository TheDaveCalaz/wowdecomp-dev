-- ModernUI: built into the client (not in the original 3.3.5a).
-- Object pools: CreateObjectPool, CreateFramePool, CreateTexturePool, CreateFontStringPool,
-- and pool collections, as modern addons use them.

local _G = _G
local pairs, next, select = pairs, next, select

local ObjectPoolMixin = _G.ObjectPoolMixin or {}
_G.ObjectPoolMixin = ObjectPoolMixin

function ObjectPoolMixin:OnLoad(creationFunc, resetterFunc)
	self.creationFunc = creationFunc
	self.resetterFunc = resetterFunc
	self.activeObjects = {}
	self.inactiveObjects = {}
	self.numActiveObjects = 0
end

function ObjectPoolMixin:Acquire()
	local n = #self.inactiveObjects
	if n > 0 then
		local obj = self.inactiveObjects[n]
		self.inactiveObjects[n] = nil
		self.activeObjects[obj] = true
		self.numActiveObjects = self.numActiveObjects + 1
		return obj, false
	end
	local obj = self.creationFunc(self)
	if self.resetterFunc and not self.disallowResetIfNew then
		self.resetterFunc(self, obj, true)
	end
	self.activeObjects[obj] = true
	self.numActiveObjects = self.numActiveObjects + 1
	return obj, true
end

function ObjectPoolMixin:Release(obj)
	if not self.activeObjects[obj] then
		return false
	end
	if self.resetterFunc then
		self.resetterFunc(self, obj, false)
	end
	self.inactiveObjects[#self.inactiveObjects + 1] = obj
	self.activeObjects[obj] = nil
	self.numActiveObjects = self.numActiveObjects - 1
	return true
end

function ObjectPoolMixin:ReleaseAll()
	for obj in pairs(self.activeObjects) do
		self:Release(obj)
	end
end

function ObjectPoolMixin:SetResetDisallowedIfNew(disallowed)
	self.disallowResetIfNew = disallowed
end

function ObjectPoolMixin:EnumerateActive()
	return pairs(self.activeObjects)
end

function ObjectPoolMixin:GetNextActive(current)
	return (next(self.activeObjects, current))
end

function ObjectPoolMixin:GetNextInactive(current)
	return self.inactiveObjects[(current or 0) + 1]
end

function ObjectPoolMixin:IsActive(obj)
	return self.activeObjects[obj] == true
end

function ObjectPoolMixin:GetNumActive()
	return self.numActiveObjects
end

function ObjectPoolMixin:EnumerateInactive()
	return ipairs(self.inactiveObjects)
end

if _G.CreateObjectPool == nil then
	function _G.CreateObjectPool(creationFunc, resetterFunc)
		local pool = CreateFromMixins(ObjectPoolMixin)
		pool:OnLoad(creationFunc, resetterFunc)
		return pool
	end
end
_G.CreateUnsecuredObjectPool = _G.CreateUnsecuredObjectPool or _G.CreateObjectPool
_G.CreateSecureObjectPool = _G.CreateSecureObjectPool or _G.CreateObjectPool

-- Resetters ------------------------------------------------------------------------------------

local Pool_HideAndClearAnchors = function(pool, region)
	region:Hide()
	region:ClearAllPoints()
end
_G.Pool_HideAndClearAnchors = _G.Pool_HideAndClearAnchors or Pool_HideAndClearAnchors
_G.FramePool_HideAndClearAnchors = _G.FramePool_HideAndClearAnchors or Pool_HideAndClearAnchors
_G.TexturePool_HideAndClearAnchors = _G.TexturePool_HideAndClearAnchors or Pool_HideAndClearAnchors
_G.FontStringPool_HideAndClearAnchors = _G.FontStringPool_HideAndClearAnchors or Pool_HideAndClearAnchors

_G.FramePool_Hide = _G.FramePool_Hide or function(pool, frame) frame:Hide() end
_G.TexturePool_Hide = _G.TexturePool_Hide or function(pool, texture) texture:Hide() end

_G.Pool_HideAndClearAnchorsWithReset = _G.Pool_HideAndClearAnchorsWithReset or function(pool, region)
	Pool_HideAndClearAnchors(pool, region)
	if region.Reset then
		region:Reset()
	end
end

-- Frame pools -----------------------------------------------------------------------------------

local FramePoolMixin = CreateFromMixins(ObjectPoolMixin)
_G.FramePoolMixin = _G.FramePoolMixin or FramePoolMixin

local function FramePoolFactory(pool)
	local frame = CreateFrame(pool.frameType, nil, pool.parent, pool.frameTemplate)
	if pool.frameInitFunc then
		pool.frameInitFunc(frame)
	end
	return frame
end

function FramePoolMixin:OnLoad(frameType, parent, frameTemplate, resetterFunc, forbidden, frameInitFunc)
	ObjectPoolMixin.OnLoad(self, FramePoolFactory, resetterFunc or Pool_HideAndClearAnchors)
	self.frameType = frameType
	self.parent = parent
	self.frameTemplate = frameTemplate
	self.frameInitFunc = frameInitFunc
end

function FramePoolMixin:GetTemplate()
	return self.frameTemplate
end

if _G.CreateFramePool == nil then
	function _G.CreateFramePool(frameType, parent, frameTemplate, resetterFunc, forbidden, frameInitFunc)
		local pool = CreateFromMixins(FramePoolMixin)
		pool:OnLoad(frameType, parent, frameTemplate, resetterFunc, forbidden, frameInitFunc)
		return pool
	end
end

-- Texture, font string and line pools -------------------------------------------------------------

local TexturePoolMixin = CreateFromMixins(ObjectPoolMixin)
_G.TexturePoolMixin = _G.TexturePoolMixin or TexturePoolMixin

local function TexturePoolFactory(pool)
	return pool.parent:CreateTexture(nil, pool.layer, pool.textureTemplate, pool.subLayer)
end

function TexturePoolMixin:OnLoad(parent, layer, subLayer, textureTemplate, resetterFunc)
	ObjectPoolMixin.OnLoad(self, TexturePoolFactory, resetterFunc or Pool_HideAndClearAnchors)
	self.parent = parent
	self.layer = layer
	self.subLayer = subLayer
	self.textureTemplate = textureTemplate
end

function TexturePoolMixin:GetTemplate()
	return self.textureTemplate
end

if _G.CreateTexturePool == nil then
	function _G.CreateTexturePool(parent, layer, subLayer, textureTemplate, resetterFunc)
		local pool = CreateFromMixins(TexturePoolMixin)
		pool:OnLoad(parent, layer, subLayer, textureTemplate, resetterFunc)
		return pool
	end
end

local FontStringPoolMixin = CreateFromMixins(ObjectPoolMixin)
_G.FontStringPoolMixin = _G.FontStringPoolMixin or FontStringPoolMixin

local function FontStringPoolFactory(pool)
	return pool.parent:CreateFontString(nil, pool.layer, pool.fontStringTemplate, pool.subLayer)
end

function FontStringPoolMixin:OnLoad(parent, layer, subLayer, fontStringTemplate, resetterFunc)
	ObjectPoolMixin.OnLoad(self, FontStringPoolFactory, resetterFunc or Pool_HideAndClearAnchors)
	self.parent = parent
	self.layer = layer
	self.subLayer = subLayer
	self.fontStringTemplate = fontStringTemplate
end

function FontStringPoolMixin:GetTemplate()
	return self.fontStringTemplate
end

if _G.CreateFontStringPool == nil then
	function _G.CreateFontStringPool(parent, layer, subLayer, fontStringTemplate, resetterFunc)
		local pool = CreateFromMixins(FontStringPoolMixin)
		pool:OnLoad(parent, layer, subLayer, fontStringTemplate, resetterFunc)
		return pool
	end
end

-- Pool collections ------------------------------------------------------------------------------

local PoolCollectionMixin = _G.FramePoolCollectionMixin or {}
_G.FramePoolCollectionMixin = PoolCollectionMixin
_G.PoolCollectionMixin = _G.PoolCollectionMixin or PoolCollectionMixin

function PoolCollectionMixin:OnLoad()
	self.pools = {}
end

local function poolKey(...)
	local key = ""
	for i = 1, select("#", ...) do
		key = key .. "\001" .. tostring((select(i, ...)))
	end
	return key
end

function PoolCollectionMixin:GetNumActive()
	local n = 0
	for _, pool in pairs(self.pools) do
		n = n + pool:GetNumActive()
	end
	return n
end

function PoolCollectionMixin:GetPool(template, specialization)
	return self.pools[poolKey(template, specialization)]
end

function PoolCollectionMixin:GetOrCreatePool(frameType, parent, template, resetterFunc, forbidden, specialization)
	local key = poolKey(template, specialization)
	local pool = self.pools[key]
	if not pool then
		pool = CreateFramePool(frameType, parent, template, resetterFunc, forbidden)
		self.pools[key] = pool
	end
	return pool
end

function PoolCollectionMixin:CreatePool(frameType, parent, template, resetterFunc, forbidden, specialization)
	return self:GetOrCreatePool(frameType, parent, template, resetterFunc, forbidden, specialization)
end

function PoolCollectionMixin:Acquire(template, specialization)
	local pool = self:GetPool(template, specialization)
	if pool then
		return pool:Acquire()
	end
end

function PoolCollectionMixin:Release(obj)
	for _, pool in pairs(self.pools) do
		if pool:Release(obj) then
			return true
		end
	end
	return false
end

function PoolCollectionMixin:ReleaseAllByTemplate(template)
	local pool = self:GetPool(template)
	if pool then
		pool:ReleaseAll()
	end
end

function PoolCollectionMixin:ReleaseAll()
	for _, pool in pairs(self.pools) do
		pool:ReleaseAll()
	end
end

function PoolCollectionMixin:EnumerateActiveByTemplate(template, specialization)
	local pool = self:GetPool(template, specialization)
	if pool then
		return pool:EnumerateActive()
	end
	return nop
end

function PoolCollectionMixin:EnumerateActive()
	local poolKeyNow, pool = next(self.pools)
	local obj
	return function()
		while pool do
			obj = pool:GetNextActive(obj)
			if obj then
				return obj
			end
			poolKeyNow, pool = next(self.pools, poolKeyNow)
		end
	end
end

if _G.CreateFramePoolCollection == nil then
	function _G.CreateFramePoolCollection()
		local collection = CreateFromMixins(PoolCollectionMixin)
		collection:OnLoad()
		return collection
	end
end
_G.CreatePoolCollection = _G.CreatePoolCollection or _G.CreateFramePoolCollection
