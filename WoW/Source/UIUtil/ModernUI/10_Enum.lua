-- ModernUI: built into the client (not in the original 3.3.5a).
-- The Enum tables modern addons read. Values are the modern client's values.
-- Where a 3.3.5 game system uses its own numbers (bag indexes, combat log flags) the 3.3.5 numbers
-- are used, so the values work with this client's functions.

local _G = _G
local Enum = _G.Enum or {}
_G.Enum = Enum

local function enum(name, values)
	local t = Enum[name]
	if not t then
		t = {}
		Enum[name] = t
	end
	for k, v in pairs(values) do
		if t[k] == nil then
			t[k] = v
		end
	end
end

enum("ItemQuality", {
	Poor = 0, Common = 1, Standard = 1, Uncommon = 2, Good = 2, Rare = 3, Superior = 3,
	Epic = 4, Legendary = 5, Artifact = 6, Heirloom = 7, WoWToken = 8,
})

enum("ItemClass", {
	Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4, Reagent = 5, Projectile = 6,
	Tradegoods = 7, ItemEnhancement = 8, Recipe = 9, CurrencyTokenObsolete = 10, Quiver = 11,
	Questitem = 12, Key = 13, PermanentObsolete = 14, Miscellaneous = 15, Glyph = 16, Battlepet = 17,
	WoWToken = 18, Profession = 19,
})

enum("ItemWeaponSubclass", {
	Axe1H = 0, Axe2H = 1, Bows = 2, Guns = 3, Mace1H = 4, Mace2H = 5, Polearm = 6, Sword1H = 7,
	Sword2H = 8, Warglaive = 9, Staff = 10, Bearclaw = 11, Catclaw = 12, Unarmed = 13, Generic = 14,
	Dagger = 15, Thrown = 16, Obsolete3 = 17, Crossbow = 18, Wand = 19, Fishingpole = 20,
})

enum("ItemArmorSubclass", {
	Generic = 0, Cloth = 1, Leather = 2, Mail = 3, Plate = 4, Cosmetic = 5, Shield = 6, Libram = 7,
	Idol = 8, Totem = 9, Sigil = 10, Relic = 11,
})

enum("ItemConsumableSubclass", {
	Generic = 0, Potion = 1, Elixir = 2, Flasksphials = 3, Scroll = 4, Fooddrink = 5,
	Itemenhancement = 6, Bandage = 7, Other = 8, VantusRune = 9,
})

enum("ItemGemSubclass", {
	Intellect = 0, Agility = 1, Strength = 2, Stamina = 3, Spirit = 4, Criticalstrike = 5, Mastery = 6,
	Haste = 7, Versatility = 8, Other = 9, Multiplestats = 10, Artifactrelic = 11,
})

enum("ItemMiscellaneousSubclass", {
	Junk = 0, Reagent = 1, CompanionPet = 2, Holiday = 3, Other = 4, Mount = 5, MountEquipment = 6,
})

enum("ItemRecipeSubclass", {
	Book = 0, Leatherworking = 1, Tailoring = 2, Engineering = 3, Blacksmithing = 4, Cooking = 5,
	Alchemy = 6, FirstAid = 7, Enchanting = 8, Fishing = 9, Jewelcrafting = 10, Inscription = 11,
})

enum("ItemContainerSubclass", {
	Bag = 0, SoulBag = 1, HerbBag = 2, EnchantingBag = 3, EngineeringBag = 4, GemBag = 5,
	MiningBag = 6, LeatherworkingBag = 7, InscriptionBag = 8,
})

enum("ItemBind", {
	None = 0, OnAcquire = 1, OnEquip = 2, OnUse = 3, Quest = 4, Unused1 = 5, Unused2 = 6,
	ToWoWAccount = 7, ToBnetAccount = 8, ToBnetAccountUntilEquipped = 9,
})

enum("InventoryType", {
	IndexNonEquipType = 0, IndexHeadType = 1, IndexNeckType = 2, IndexShoulderType = 3,
	IndexBodyType = 4, IndexChestType = 5, IndexWaistType = 6, IndexLegsType = 7, IndexFeetType = 8,
	IndexWristType = 9, IndexHandType = 10, IndexFingerType = 11, IndexTrinketType = 12,
	IndexWeaponType = 13, IndexShieldType = 14, IndexRangedType = 15, IndexCloakType = 16,
	Index2HweaponType = 17, IndexBagType = 18, IndexTabardType = 19, IndexRobeType = 20,
	IndexWeaponmainhandType = 21, IndexWeaponoffhandType = 22, IndexHoldableType = 23,
	IndexAmmoType = 24, IndexThrownType = 25, IndexRangedrightType = 26, IndexQuiverType = 27,
	IndexRelicType = 28,
})

enum("PowerType", {
	HealthCost = -2, None = -1, Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5,
	RunicPower = 6, SoulShards = 7, LunarPower = 8, HolyPower = 9, Alternate = 10, Maelstrom = 11,
	Chi = 12, Insanity = 13, Obsolete = 14, Obsolete2 = 15, ArcaneCharges = 16, Fury = 17, Pain = 18,
	Essence = 19, RuneBlood = 20, RuneFrost = 21, RuneUnholy = 22, AlternateQuest = 23,
	AlternateEncounter = 24, AlternateMount = 25, NumPowerTypes = 26,
})

enum("UnitSex", { Male = 0, Female = 1, None = 2, Both = 3, Neutral = 4 })

enum("LFGRole", { Tank = 0, Healer = 1, Damage = 2 })

-- 3.3.5 bag numbers.
enum("BagIndex", {
	Keyring = -2, Bank = -1, Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4,
	BankBag_1 = 5, BankBag_2 = 6, BankBag_3 = 7, BankBag_4 = 8, BankBag_5 = 9, BankBag_6 = 10, BankBag_7 = 11,
})

enum("SendAddonMessageResult", {
	Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3, InvalidChatType = 4,
	NotInGroup = 5, TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8, GeneralError = 9,
	NotInGuild = 10, AddOnMessageLockdown = 11, TargetOffline = 12,
})

enum("RegisterAddonMessagePrefixResult", { Success = 0, DuplicatePrefix = 1, InvalidPrefix = 2, MaxPrefixes = 3 })

enum("ChatChannelType", { None = 0, Custom = 1, PrivateParty = 2, PublicParty = 3, Communities = 4 })

enum("UIMapType", { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 })

enum("SpellBookSpellBank", { Player = 0, Pet = 1 })
enum("SpellBookItemType", { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 })

enum("AddOnEnableState", { None = 0, Some = 1, All = 2 })

enum("GossipOptionStatus", { Available = 0, Unavailable = 1, Locked = 2, AlreadyComplete = 3 })

enum("QuestFrequency", { Default = 0, Daily = 1, Weekly = 2, ResetByScheduler = 3 })

enum("QuestTag", {
	Group = 1, PvP = 41, Raid = 62, Dungeon = 81, Legendary = 83, Heroic = 85, Raid10 = 88, Raid25 = 89,
	Scenario = 98, Account = 102, CombatAlly = 266, Delve = 288,
})

enum("QuestClassification", {
	Important = 0, Legendary = 1, Campaign = 2, Calling = 3, Meta = 4, Recurring = 5, Questline = 6,
	Normal = 7, BonusObjective = 8, Threat = 9, WorldQuest = 10,
})

enum("TooltipDataType", {
	Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4, Currency = 5, BattlePet = 6, UnitAura = 7,
	AzeriteEssence = 8, CompanionPet = 9, Mount = 10, PetAction = 11, Achievement = 12,
	EnhancedConduit = 13, EquipmentSet = 14, InstanceLock = 15, PvPBrawl = 16, RecipeRankInfo = 17,
	Totem = 18, Toy = 19, CorruptionCleanser = 20, MinimapMouseover = 21, Flyout = 22, Quest = 23,
	QuestPartyProgress = 24, Macro = 25, Debug = 26,
})

enum("TooltipDataLineType", {
	None = 0, Blank = 1, UnitName = 2, GemSocket = 3, AzeriteEssenceSlot = 4, AzeriteEssencePower = 5,
	LearnableSpell = 6, UnitThreat = 7, QuestObjective = 8, AzeriteItemPowerDescription = 9,
	RuneforgeLegendaryPowerDescription = 10, SellPrice = 11, ProfessionCraftingQuality = 12,
	SpellName = 13, CurrencyTotal = 14, ItemEnchantmentPermanent = 15, UnitOwner = 16, QuestTitle = 17,
	QuestPlayer = 18, NestedBlock = 19, ItemBinding = 20,
})

enum("PlayerInteractionType", {
	None = 0, TradePartner = 1, Item = 2, Gossip = 3, QuestGiver = 4, Merchant = 5, TaxiNode = 6,
	Trainer = 7, Banker = 8, AlliedRaceDetailsGiver = 9, GuildBanker = 10, Registrar = 11, Vendor = 12,
	PetitionVendor = 13, GuildTabardVendor = 14, TalentMaster = 15, SpecializationMaster = 16,
	MailInfo = 17, SpiritHealer = 18, AreaSpiritHealer = 19, Binder = 20, Auctioneer = 21,
	StableMaster = 22, BattleMaster = 23, Transmogrifier = 24, LFGDungeon = 25, ItemUpgrade = 53,
})

enum("TtsVoiceType", { Standard = 0, Alternate = 1 })
enum("VoiceTtsDestination", {
	RemoteTransmission = 0, LocalPlayback = 1, RemoteTransmissionWithLocalPlayback = 2,
	QueuedRemoteTransmission = 3, QueuedLocalPlayback = 4, QueuedRemoteTransmissionWithLocalPlayback = 5,
	ScreenReader = 6,
})

-- Combat log flags: the same bit values the 3.3.5 combat log uses.
enum("CombatLogObject", {
	Empty = 0, AffiliationMine = 0x1, AffiliationParty = 0x2, AffiliationRaid = 0x4,
	AffiliationOutsider = 0x8, AffiliationMask = 0xF, ReactionFriendly = 0x10, ReactionNeutral = 0x20,
	ReactionHostile = 0x40, ReactionMask = 0xF0, ControlPlayer = 0x100, ControlNpc = 0x200,
	ControlMask = 0x300, TypePlayer = 0x400, TypeNpc = 0x800, TypePet = 0x1000, TypeGuardian = 0x2000,
	TypeObject = 0x4000, TypeMask = 0xFC00, Target = 0x10000, Focus = 0x20000, Maintank = 0x40000,
	Mainassist = 0x80000, None = 0x80000000, SpecialMask = 0xFFFF0000,
})

enum("CombatLogObjectTarget", {
	Raidtarget1 = 0x100000, Raidtarget2 = 0x200000, Raidtarget3 = 0x400000, Raidtarget4 = 0x800000,
	Raidtarget5 = 0x1000000, Raidtarget6 = 0x2000000, Raidtarget7 = 0x4000000, Raidtarget8 = 0x8000000,
	RaidNone = 0x80000000, RaidTargetMask = 0x0FF00000,
})

enum("FontStringScaleAnimationMode", { ScaleByHeight = 0, ScaleByWidth = 1, ScaleByBoth = 2 })

enum("SeasonID", { NoSeason = 0, SeasonOfMastery = 1, SeasonOfDiscovery = 2, Hardcore = 3, Fresh = 11, FreshHardcore = 12 })

enum("LuaCurveType", { Linear = 0, Step = 1 })

enum("ClubType", { BattleNet = 0, Character = 1, Guild = 2, Other = 3 })

enum("ItemCreationContext", { None = 0 })

enum("TransmogType", { Appearance = 0, Illusion = 1 })

enum("CurrencySource", { None = 0 })

enum("UIWidgetVisualizationType", {
	IconAndText = 0, CaptureBar = 1, StatusBar = 2, DoubleStatusBar = 3, IconTextAndBackground = 4,
	DoubleIconAndText = 5, StackedResourceTracker = 6, IconTextAndCurrencies = 7, TextWithState = 8,
	HorizontalCurrencies = 9, BulletTextList = 10, ScenarioHeaderCurrenciesAndBackground = 11,
	TextureAndText = 12, SpellDisplay = 13, DoubleStateIconRow = 14, TextureAndTextRow = 15,
	ZoneControl = 16, CaptureZone = 17, TextureWithAnimation = 18, DiscreteProgressSteps = 19,
	ScenarioHeaderTimer = 20, TextColumnRow = 21, Spacer = 22, UnitPowerBar = 23, FillUpFrames = 24,
	TextWithSubtext = 25, MapPinAnimation = 26, ItemDisplay = 27, TugOfWar = 28,
})

enum("QuestCompleteSpellType", {
	LegacyBehavior = 0, Follower = 1, Tradeskill = 2, Ability = 3, Aura = 4, Spell = 5, Unlock = 6,
	Companion = 7, QuestlineUnlock = 8, QuestlineReward = 9, QuestlineUnlockPart = 10, PossibleReward = 11,
})
