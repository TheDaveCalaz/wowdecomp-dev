-- ModernUI: built into the client (not in the original 3.3.5a).
-- C_Item, C_Container, ItemLocation and the Item object, answered from this client's item functions.

local _G = _G
local type, select, tonumber, pairs, ipairs = type, select, tonumber, pairs, ipairs

-- ItemLocation ----------------------------------------------------------------------------------

local ItemLocationMixin = _G.ItemLocationMixin or {}
_G.ItemLocationMixin = ItemLocationMixin

function ItemLocationMixin:Clear()
	self.bagID, self.slotIndex, self.equipmentSlotIndex = nil, nil, nil
end
function ItemLocationMixin:SetBagAndSlot(bagID, slotIndex)
	self:Clear()
	self.bagID, self.slotIndex = bagID, slotIndex
end
function ItemLocationMixin:GetBagAndSlot()
	return self.bagID, self.slotIndex
end
function ItemLocationMixin:SetEquipmentSlot(equipmentSlotIndex)
	self:Clear()
	self.equipmentSlotIndex = equipmentSlotIndex
end
function ItemLocationMixin:GetEquipmentSlot()
	return self.equipmentSlotIndex
end
function ItemLocationMixin:IsEquipmentSlot()
	return self.equipmentSlotIndex ~= nil
end
function ItemLocationMixin:IsBagAndSlot()
	return self.bagID ~= nil and self.slotIndex ~= nil
end
function ItemLocationMixin:HasAnyLocation()
	return self:IsEquipmentSlot() or self:IsBagAndSlot()
end
function ItemLocationMixin:IsValid()
	return C_Item.DoesItemExist(self)
end
function ItemLocationMixin:IsEqualToBagAndSlot(bagID, slotIndex)
	return self.bagID == bagID and self.slotIndex == slotIndex
end
function ItemLocationMixin:IsEqualToEquipmentSlot(equipmentSlotIndex)
	return self.equipmentSlotIndex == equipmentSlotIndex
end
function ItemLocationMixin:IsEqualTo(other)
	if not other then
		return false
	end
	if self:IsEquipmentSlot() then
		return self.equipmentSlotIndex == other.equipmentSlotIndex
	end
	return self.bagID == other.bagID and self.slotIndex == other.slotIndex
end

local ItemLocation = _G.ItemLocation or {}
_G.ItemLocation = ItemLocation
function ItemLocation:CreateEmpty()
	return CreateFromMixins(ItemLocationMixin)
end
function ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
	local loc = CreateFromMixins(ItemLocationMixin)
	loc:SetBagAndSlot(bagID, slotIndex)
	return loc
end
function ItemLocation:CreateFromEquipmentSlot(equipmentSlotIndex)
	local loc = CreateFromMixins(ItemLocationMixin)
	loc:SetEquipmentSlot(equipmentSlotIndex)
	return loc
end
function ItemLocation:ApplyLocationToTooltip(location, tooltip)
	if location:IsEquipmentSlot() then
		return tooltip:SetInventoryItem("player", location:GetEquipmentSlot())
	elseif location:IsBagAndSlot() then
		return tooltip:SetBagItem(location:GetBagAndSlot())
	end
end

local function linkAt(location)
	if not location then
		return nil
	end
	if location.IsEquipmentSlot and location:IsEquipmentSlot() then
		return GetInventoryItemLink("player", location:GetEquipmentSlot())
	elseif location.IsBagAndSlot and location:IsBagAndSlot() then
		return GetContainerItemLink(location:GetBagAndSlot())
	end
end

local function idFromLink(link)
	return link and tonumber(link:match("item:(%-?%d+)"))
end

local inventoryTypeIndex = {}
for i, token in ipairs({
	"INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_BODY", "INVTYPE_CHEST", "INVTYPE_WAIST",
	"INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_FINGER", "INVTYPE_TRINKET",
	"INVTYPE_WEAPON", "INVTYPE_SHIELD", "INVTYPE_RANGED", "INVTYPE_CLOAK", "INVTYPE_2HWEAPON", "INVTYPE_BAG",
	"INVTYPE_TABARD", "INVTYPE_ROBE", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE",
	"INVTYPE_AMMO", "INVTYPE_THROWN", "INVTYPE_RANGEDRIGHT", "INVTYPE_QUIVER", "INVTYPE_RELIC",
}) do
	inventoryTypeIndex[token] = i
end

-- C_Item ----------------------------------------------------------------------------------------

local C_Item = _G.C_Item or {}
_G.C_Item = C_Item

local function set(name, fn)
	if C_Item[name] == nil then
		C_Item[name] = fn
	end
end

set("GetItemInfo", GetItemInfo)
set("GetItemInfoInstant", GetItemInfoInstant)
set("GetItemClassInfo", GetItemClassInfo)
set("GetItemSubClassInfo", GetItemSubClassInfo)
set("GetItemIDForItemInfo", function(item) return (GetItemInfoInstant(item)) end)
set("GetItemIconByID", function(item) return select(5, GetItemInfoInstant(item)) end)
set("GetItemInventoryTypeByID", function(item)
	local equipLoc = select(4, GetItemInfoInstant(item))
	return equipLoc and (inventoryTypeIndex[equipLoc] or 0)
end)
set("GetItemNameByID", function(item) return (GetItemInfo(item)) end)
set("GetItemQualityByID", function(item) return (select(3, GetItemInfo(item))) end)
set("GetItemMaxStackSizeByID", function(item) return (select(8, GetItemInfo(item))) end)
set("DoesItemExistByID", function(item) return GetItemInfoInstant(item) ~= nil end)
set("IsItemDataCachedByID", function(item) return GetItemInfo(item) ~= nil end)
set("RequestLoadItemDataByID", function(item) GetItemInfo(item) end)
set("GetItemCount", function(item, includeBank, includeUses) return GetItemCount(item, includeBank, includeUses) end)
set("GetItemSpell", GetItemSpell)
set("GetItemStats", GetItemStats)
set("GetItemGem", GetItemGem)
set("GetItemFamily", GetItemFamily)
set("GetItemQualityColor", function(quality)
	local r, g, b, hex = GetItemQualityColor(quality)
	return r, g, b, hex
end)
set("GetItemCooldown", function(item)
	local start, duration, enable = GetItemCooldown(item)
	return start, duration, enable == 1
end)
set("GetDetailedItemLevelInfo", function(item)
	local level = select(4, GetItemInfo(item))
	return level, false, level
end)
set("IsEquippedItem", IsEquippedItem)
set("IsEquippedItemType", IsEquippedItemType)
set("IsEquippableItem", IsEquippableItem)
set("IsUsableItem", IsUsableItem)
set("IsHelpfulItem", IsHelpfulItem)
set("IsHarmfulItem", IsHarmfulItem)
set("IsConsumableItem", IsConsumableItem)
set("IsCurrentItem", IsCurrentItem)
set("IsItemInRange", function(item, unit) return IsItemInRange(item, unit) == 1 end)
set("ItemHasRange", function(item) return ItemHasRange(item) == 1 end)
set("IsDressableItemByID", function(item) return IsDressableItem and IsDressableItem(item) and true or false end)
set("IsCosmeticItem", function() return false end)
set("IsAnimaItemByID", function() return false end)
set("IsArtifactPowerItem", function() return false end)
set("IsItemKeystoneByID", function() return false end)
set("IsItemConduit", function() return false end)
set("IsCorruptedItem", function() return false end)
set("IsItemCorrupted", function() return false end)
set("IsBoundToAccountUntilEquip", function() return false end)
set("IsItemBindToAccountUntilEquip", function() return false end)
set("IsItemSpecificToPlayerClass", function() return false end)
set("DoesItemContainSpec", function() return true end)
set("GetItemSetInfo", function() return nil end)
set("GetItemUniquenessByID", function() return nil end)
set("GetItemCreationContext", function() return nil end)
set("GetAppliedItemTransmogInfo", function() return nil end)
set("GetBaseItemTransmogInfo", function() return nil end)
set("GetCurrentItemTransmogInfo", function() return nil end)
set("GetItemLearnTransmogSet", function() return nil end)
set("ActionBindsItem", function() return false end)
set("EndBoundTradeable", function() end)
set("EndRefund", function() end)
set("PickupItem", PickupItem)
set("UseItemByName", UseItemByName)
set("EquipItemByName", EquipItemByName)
set("GetItemSpecInfo", function() return nil end)
set("GetFirstTriggeredSpellForItem", function() return nil end)

-- Location-based functions.
set("DoesItemExist", function(location) return linkAt(location) ~= nil end)
set("GetItemLink", function(location) return linkAt(location) end)
set("GetItemID", function(location) return idFromLink(linkAt(location)) end)
set("GetItemName", function(location)
	local link = linkAt(location)
	return link and (GetItemInfo(link))
end)
set("GetItemIcon", function(location)
	local link = linkAt(location)
	return link and select(10, GetItemInfo(link)) or (link and GetItemIcon(idFromLink(link)))
end)
set("GetItemQuality", function(location)
	local link = linkAt(location)
	return link and (select(3, GetItemInfo(link)))
end)
set("GetCurrentItemLevel", function(location)
	local link = linkAt(location)
	return link and (select(4, GetItemInfo(link)))
end)
set("GetItemInventoryType", function(location)
	local link = linkAt(location)
	local equipLoc = link and select(9, GetItemInfo(link))
	return equipLoc and (inventoryTypeIndex[equipLoc] or 0)
end)
set("GetItemMaxStackSize", function(location)
	local link = linkAt(location)
	return link and (select(8, GetItemInfo(link)))
end)
set("GetStackCount", function(location)
	if location:IsBagAndSlot() then
		return (select(2, GetContainerItemInfo(location:GetBagAndSlot())))
	end
	return 1
end)
set("IsLocked", function(location)
	if location:IsBagAndSlot() then
		return (select(3, GetContainerItemInfo(location:GetBagAndSlot()))) and true or false
	end
	return IsInventoryItemLocked(location:GetEquipmentSlot()) and true or false
end)
set("IsBound", function() return false end)
set("IsItemDataCached", function(location)
	local link = linkAt(location)
	return link ~= nil and GetItemInfo(link) ~= nil
end)
set("RequestLoadItemData", function(location)
	local link = linkAt(location)
	if link then GetItemInfo(link) end
end)
set("GetItemGUID", function() return nil end)
set("LockItem", function() end)
set("UnlockItem", function() end)
set("LockItemByGUID", function() end)
set("UnlockItemByGUID", function() end)

-- Item object -----------------------------------------------------------------------------------
-- Item:CreateFromItemID(...):ContinueOnItemLoad(callback) waits until the server has sent the item.

local waiting = {}
local waitFrame = CreateFrame("Frame")
waitFrame:Hide()
local waitElapsed = 0
waitFrame:SetScript("OnUpdate", function(self, elapsed)
	waitElapsed = waitElapsed + elapsed
	if waitElapsed < 0.1 then
		return
	end
	waitElapsed = 0
	local now = GetTime()
	for i = #waiting, 1, -1 do
		local entry = waiting[i]
		if entry.cancelled then
			table.remove(waiting, i)
		elseif GetItemInfo(entry.item) then
			table.remove(waiting, i)
			entry.callback()
		elseif now > entry.giveUpAt then
			table.remove(waiting, i)
		end
	end
	if #waiting == 0 then
		self:Hide()
	end
end)

local function whenItemLoaded(item, callback)
	if GetItemInfo(item) then
		callback()
		return function() end
	end
	local entry = { item = item, callback = callback, giveUpAt = GetTime() + 30 }
	waiting[#waiting + 1] = entry
	waitFrame:Show()
	return function() entry.cancelled = true end
end

local ItemMixin = _G.ItemMixin or {}
_G.ItemMixin = ItemMixin

local Item = _G.Item or {}
_G.Item = Item

function Item:CreateFromItemID(itemID)
	local item = CreateFromMixins(ItemMixin)
	item:SetItemID(itemID)
	return item
end
function Item:CreateFromItemLink(itemLink)
	local item = CreateFromMixins(ItemMixin)
	item:SetItemLink(itemLink)
	return item
end
function Item:CreateFromItemLocation(itemLocation)
	local item = CreateFromMixins(ItemMixin)
	item:SetItemLocation(itemLocation)
	return item
end
function Item:CreateFromBagAndSlot(bagID, slotIndex)
	return Item:CreateFromItemLocation(ItemLocation:CreateFromBagAndSlot(bagID, slotIndex))
end
function Item:CreateFromEquipmentSlot(equipmentSlotIndex)
	return Item:CreateFromItemLocation(ItemLocation:CreateFromEquipmentSlot(equipmentSlotIndex))
end
function Item:CreateFromItemGUID() return Item:CreateFromItemID(nil) end

function ItemMixin:Clear()
	self.itemID, self.itemLink, self.itemLocation = nil, nil, nil
end
function ItemMixin:SetItemID(itemID)
	self:Clear()
	self.itemID = itemID
end
function ItemMixin:SetItemLink(itemLink)
	self:Clear()
	self.itemLink = itemLink
end
function ItemMixin:SetItemLocation(itemLocation)
	self:Clear()
	self.itemLocation = itemLocation
end
function ItemMixin:GetItemLocation() return self.itemLocation end
function ItemMixin:HasItemLocation() return self.itemLocation ~= nil end
function ItemMixin:GetStaticBackingItem()
	return self.itemLink or self.itemID
end
function ItemMixin:GetItemLink()
	if self.itemLink then return self.itemLink end
	if self.itemLocation then return linkAt(self.itemLocation) end
	if self.itemID then return (select(2, GetItemInfo(self.itemID))) end
end
local function backing(self)
	return self.itemLink or (self.itemLocation and linkAt(self.itemLocation)) or self.itemID
end
function ItemMixin:GetItemID()
	if self.itemID then return self.itemID end
	return idFromLink(self:GetItemLink())
end
function ItemMixin:IsItemEmpty()
	return backing(self) == nil
end
function ItemMixin:IsItemDataCached()
	local item = backing(self)
	return item ~= nil and GetItemInfo(item) ~= nil
end
function ItemMixin:GetItemName()
	local item = backing(self)
	return item and (GetItemInfo(item))
end
function ItemMixin:GetItemIcon()
	local item = backing(self)
	return item and select(5, GetItemInfoInstant(item))
end
function ItemMixin:GetItemQuality()
	local item = backing(self)
	return item and (select(3, GetItemInfo(item)))
end
function ItemMixin:GetCurrentItemLevel()
	local item = backing(self)
	return item and (select(4, GetItemInfo(item)))
end
function ItemMixin:GetItemQualityColor()
	local quality = self:GetItemQuality()
	return quality and ITEM_QUALITY_COLORS[quality]
end
function ItemMixin:GetInventoryType()
	local item = backing(self)
	local equipLoc = item and select(4, GetItemInfoInstant(item))
	return equipLoc and inventoryTypeIndex[equipLoc] or 0
end
function ItemMixin:GetInventoryTypeName()
	local item = backing(self)
	return item and select(4, GetItemInfoInstant(item))
end
function ItemMixin:IsItemInPlayersControl()
	return self.itemLocation ~= nil and C_Item.DoesItemExist(self.itemLocation)
end
function ItemMixin:IsItemLocked()
	return self.itemLocation ~= nil and C_Item.IsLocked(self.itemLocation)
end
function ItemMixin:LockItem() end
function ItemMixin:UnlockItem() end
function ItemMixin:IsDataEvictable() return true end
function ItemMixin:GetItemGUID() return nil end
function ItemMixin:ContinueOnItemLoad(callback)
	local item = backing(self)
	if item == nil then
		return
	end
	whenItemLoaded(item, callback)
end
function ItemMixin:ContinueWithCancelOnItemLoad(callback)
	local item = backing(self)
	if item == nil then
		return function() end
	end
	return whenItemLoaded(item, callback)
end

-- Several items at once.
_G.ContinuableContainer = _G.ContinuableContainer or {
	Create = function()
		local container = { items = {} }
		function container:AddContinuable(obj) self.items[#self.items + 1] = obj end
		function container:AddContinuables(list) for _, obj in ipairs(list) do self:AddContinuable(obj) end end
		function container:ContinueOnLoad(callback)
			local remaining = #self.items
			if remaining == 0 then
				callback()
				return function() end
			end
			local cancels = {}
			for _, obj in ipairs(self.items) do
				cancels[#cancels + 1] = obj:ContinueWithCancelOnItemLoad(function()
					remaining = remaining - 1
					if remaining == 0 then
						callback()
					end
				end)
			end
			return function() for _, c in ipairs(cancels) do c() end end
		end
		function container:Cancel() end
		function container:RemoveAllContinuables() self.items = {} end
		return container
	end,
}

-- C_Container ------------------------------------------------------------------------------------

local C_Container = _G.C_Container or {}
_G.C_Container = C_Container

local function cset(name, fn)
	if C_Container[name] == nil then
		C_Container[name] = fn
	end
end

cset("GetContainerNumSlots", GetContainerNumSlots)
cset("GetContainerNumFreeSlots", GetContainerNumFreeSlots)
cset("GetContainerItemLink", GetContainerItemLink)
cset("GetContainerItemID", GetContainerItemID)
cset("GetContainerItemCooldown", GetContainerItemCooldown)
cset("GetContainerItemDurability", GetContainerItemDurability)
cset("GetContainerItemPurchaseInfo", GetContainerItemPurchaseInfo)
cset("GetContainerFreeSlots", GetContainerFreeSlots)
cset("PickupContainerItem", PickupContainerItem)
cset("UseContainerItem", UseContainerItem)
cset("SplitContainerItem", SplitContainerItem)
cset("SocketContainerItem", SocketContainerItem)
cset("ShowContainerSellCursor", ShowContainerSellCursor)
cset("ContainerIDToInventoryID", ContainerIDToInventoryID)
cset("GetBagName", GetBagName)
cset("GetItemCooldown", function(itemID)
	return GetItemCooldown(itemID)
end)
cset("GetContainerItemInfo", function(bag, slot)
	local icon, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
	if not icon then
		return nil
	end
	local sellPrice = link and select(11, GetItemInfo(link))
	return {
		iconFileID = icon,
		stackCount = count,
		isLocked = locked and true or false,
		quality = quality,
		isReadable = readable and true or false,
		hasLoot = lootable and true or false,
		hyperlink = link,
		isFiltered = false,
		hasNoValue = sellPrice == 0,
		itemID = GetContainerItemID(bag, slot),
		isBound = false,
	}
end)
cset("GetContainerItemQuestInfo", function(bag, slot)
	if not GetContainerItemQuestInfo then
		return { isQuestItem = false, isActive = false }
	end
	local isQuestItem, questID, isActive = GetContainerItemQuestInfo(bag, slot)
	return { isQuestItem = isQuestItem and true or false, questID = questID, isActive = isActive and true or false }
end)
cset("IsContainerFiltered", function() return false end)
cset("GetBagSlotFlag", function() return false end)
cset("SetBagSlotFlag", function() end)
cset("GetBankAutosortDisabled", function() return false end)
cset("GetBackpackAutosortDisabled", function() return false end)
cset("SetBackpackAutosortDisabled", function() end)
cset("SetBankAutosortDisabled", function() end)
cset("GetSortBagsRightToLeft", function() return false end)
cset("SetSortBagsRightToLeft", function() end)
cset("GetInsertItemsLeftToRight", function() return false end)
cset("SetInsertItemsLeftToRight", function() end)
cset("PlayerHasHearthstone", function()
	return GetItemCount(6948) > 0 and 6948 or nil
end)
cset("GetMaxArenaCurrency", function() return 5000 end)
cset("UseHearthstone", function() return false end)
