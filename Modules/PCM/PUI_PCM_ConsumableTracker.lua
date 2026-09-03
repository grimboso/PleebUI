local _, ns = ...

local Addon = ns.Addon
local Cooldowns = ns.Modules.CooldownManager
local FrameUtil = ns.FrameUtil
local Presentation = ns.Presentation
local IconSkin = ns.IconSkin
local AuraSlotDriver = ns.AuraSlotDriver
local AuraWidget = ns.AuraWidget
local BarWidget = ns.BarWidget
local PCMPresentation = ns.PCMPresentation
local Theme = ns.Theme
local LSM = ns.LSM
local Round = ns.Pixel.Round
local P = select(1, ns.Pleebug:DropIn(Cooldowns, { name = "PCM", bucket = "ConsumableTracker" }))

local TRACKER_MOVER_KEY = "PCM_ConsumableTracker"
local PARTICIPANT_KEY = "pcmConsumables"
local DURATION_GLOW_STYLE = {
  buffGlowThickness = 2,
  activeGlowColor = { 1, 0.55, 0.1, 1 },
}
local COOLDOWN_FONT_STYLE = {
  role = "cooldown",
  scope = "cooldownManager",
  flags = "OUTLINE",
}
local durationFont = CreateFont("PUI_PCMConsumableDurationFont")
local durationFontPath
local durationFontSize
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local HEALTHSTONE_ITEM_ID = 5512
local IsSecret = issecretvalue
local UnitClassBase = UnitClassBase
local GetInventoryItemID = GetInventoryItemID
local PCMRuntime = ns.PCMRuntime

local ACTIVE_TRINKET_CATEGORY = Enum.CooldownViewerCategory.EquipSlotEssential
local TRACKED_TRINKET_CATEGORY = Enum.CooldownViewerCategory.EquipSlotTracked

local RACIAL_SPELL_IDS = {
  Scourge = { 7744 },
  Tauren = { 20549 },
  Orc = { 20572, 33697, 33702 },
  BloodElf = { 202719, 50613, 25046, 69179, 80483, 155145, 129597, 232633, 28730 },
  Dwarf = { 20594 },
  Troll = { 26297 },
  Draenei = { 28880, 59543, 59545, 121093, 59544, 370626, 59547, 59548, 59542, 416250 },
  NightElf = { 58984 },
  Human = { 59752 },
  DarkIronDwarf = { 265221 },
  Gnome = { 20589 },
  HighmountainTauren = { 255654 },
  Worgen = { 68992 },
  Goblin = { 69070 },
  Pandaren = { 107079 },
  MagharOrc = { 274738 },
  LightforgedDraenei = { 255647 },
  VoidElf = { 256948 },
  KulTiran = { 287712 },
  ZandalariTroll = { 291944 },
  Vulpera = { 312411 },
  Mechagnome = { 312924 },
  Nightborne = { 260364 },
  Dracthyr = { 357214 },
  EarthenDwarf = { 436344 },
  Haranir = { 1237885 },
}

local DEFINITIONS = {
  {
    key = "healthPotion",
    label = "Health potion",
    categoryID = 30,
    itemIDs = { 271884, 271883, 241304, 241305 },
    supportsQuality = true,
  },
  {
    key = "lightsPotential",
    label = "Light's Potential",
    categoryID = 4,
    itemIDs = { 245898, 241308, 245897, 241309 },
    tracksDuration = true,
    supportsQuality = true,
  },
  {
    key = "recklessness",
    label = "Potion of Recklessness",
    categoryID = 4,
    itemIDs = { 245902, 241288, 245903, 241289 },
    tracksDuration = true,
    supportsQuality = true,
  },
  {
    key = "liquidLuster",
    label = "Liquid Luster",
    itemIDs = { 274764, 271887, 274763, 271886 },
    tracksDuration = true,
    supportsQuality = true,
  },
  {
    key = "lightfusedMana",
    label = "Lightfused Mana Potion",
    itemIDs = { 241300, 245917, 245916, 241301 },
    supportsQuality = true,
  },
  {
    key = "invisibilityPotion",
    label = "Invisibility Potion",
    itemIDs = { 241302, 241303 },
    tracksDuration = true,
    supportsQuality = true,
  },
  {
    key = "healthstone",
    label = "Healthstone",
    categoryID = 1711,
    itemIDs = { HEALTHSTONE_ITEM_ID },
    includeUses = true,
    combatLockoutSpellID = 6262,
    previewAvailable = true,
  },
  {
    key = "demonicHealthstone",
    label = "Demonic Healthstone",
    categoryID = 2566,
    itemIDs = { 224464 },
    includeUses = true,
    previewAvailable = true,
  },
  {
    key = "combatRes",
    label = "Combat resurrection",
    itemIDs = { 269586, 248486, 198251 },
  },
  {
    key = "trinket1",
    label = "Trinket 1",
    equipSlot = 13,
  },
  {
    key = "trinket2",
    label = "Trinket 2",
    equipSlot = 14,
  },
  {
    key = "racial",
    label = "Racial ability",
    spellIDs = RACIAL_SPELL_IDS[select(2, UnitRace("player"))] or {},
  },
}

local CATEGORY_ITEM_IDS = {}
local TRACKED_ITEM_IDS = {}
local COMBAT_LOCKOUT_SPELLS = {}
for index = 1, #DEFINITIONS do
  local definition = DEFINITIONS[index]
  if definition.itemIDs then
    for itemIndex = 1, #definition.itemIDs do
      TRACKED_ITEM_IDS[definition.itemIDs[itemIndex]] = true
    end
  end
  if definition.combatLockoutSpellID then
    COMBAT_LOCKOUT_SPELLS[definition.combatLockoutSpellID] = definition
  end
  if definition.categoryID then
    local category = CATEGORY_ITEM_IDS[definition.categoryID]
    if not category then
      category = {}
      CATEGORY_ITEM_IDS[definition.categoryID] = category
    end
    for itemIndex = 1, #definition.itemIDs do
      category[#category + 1] = definition.itemIDs[itemIndex]
    end
  end
end

local Tracker = {
  active = false,
  testMode = false,
  container = nil,
  eventFrame = nil,
  icons = {},
  orderedIcons = {},
  visibleIcons = {},
  combatLockouts = {},
  hasWarlock = false,
  warlockRosterDirty = false,
  equippedItems = {},
  trinketCooldownData = {},
  itemDataRequests = {},
}

local QUALITY_ATLAS_CACHE = {}

local function GetDB()
  return ns.PCM_DBExports.GetConsumableTrackerDB()
end

local function GetSlotDB(cfg, key)
  return cfg.slots[key]
end

local function IsWarlockUnit(unit)
  local classFilename = UnitClassBase(unit)
  if IsSecret(classFilename) then
    return nil
  end

  return classFilename == "WARLOCK"
end

local function RefreshWarlockPresence()
  local previous = Tracker.hasWarlock
  local unresolved = false
  local isWarlock = IsWarlockUnit("player")

  if isWarlock == true then
    Tracker.hasWarlock = true
    Tracker.warlockRosterDirty = false
    return Tracker.hasWarlock ~= previous
  elseif isWarlock == nil then
    unresolved = true
  end

  for index = 1, 4 do
    isWarlock = IsWarlockUnit("party" .. index)
    if isWarlock == true then
      Tracker.hasWarlock = true
      Tracker.warlockRosterDirty = false
      return Tracker.hasWarlock ~= previous
    elseif isWarlock == nil then
      unresolved = true
    end
  end

  for index = 1, 40 do
    isWarlock = IsWarlockUnit("raid" .. index)
    if isWarlock == true then
      Tracker.hasWarlock = true
      Tracker.warlockRosterDirty = false
      return Tracker.hasWarlock ~= previous
    elseif isWarlock == nil then
      unresolved = true
    end
  end

  if not unresolved then
    Tracker.hasWarlock = false
  end

  Tracker.warlockRosterDirty = unresolved
  return Tracker.hasWarlock ~= previous
end

local function GetItemCountByID(itemID, includeUses)
  if IsSecret(itemID) then
    return nil
  end

  local count = C_Item.GetItemCount(itemID, false, includeUses == true)
  if IsSecret(count) or type(count) ~= "number" then
    return nil
  end

  return count
end

local function GetItemCount(definition, itemID)
  return GetItemCountByID(itemID, definition.includeUses == true)
end

local function GetItemTexture(itemID)
  if IsSecret(itemID) or (type(itemID) ~= "number" and type(itemID) ~= "string") then
    return nil
  end

  local texture = C_Item.GetItemIconByID(itemID)
  return not IsSecret(texture) and texture or nil
end

local function ShowMissingHealthstoneWarning()
  if Tracker.testMode then
    return
  end

  local cfg = GetDB()
  local slot = GetSlotDB(cfg, "healthstone")
  if slot.enabled == false then
    return
  end

  local count = GetItemCountByID(HEALTHSTONE_ITEM_ID, true)
  if count == nil or count > 0 then
    return
  end

  local message = "Missing Healthstone"
  local texture = GetItemTexture(HEALTHSTONE_ITEM_ID)
  if texture then
    message = message .. " |T" .. texture .. ":20:20:0:0|t"
  end

  UIErrorsFrame:AddMessage(message, 1, 0.2, 0.2, 1)
end

local function GetItemQualityAtlas(itemID)
  if IsSecret(itemID) or type(itemID) ~= "number" then
    return nil
  end

  local cached = QUALITY_ATLAS_CACHE[itemID]
  if cached ~= nil then
    return cached or nil
  end

  local _, itemLink = C_Item.GetItemInfo(itemID)
  if IsSecret(itemLink) then
    return nil
  end
  if not itemLink then
    C_Item.RequestLoadItemDataByID(itemID)
    return nil
  end

  local qualityInfo = C_TradeSkillUI.GetItemReagentQualityInfo(itemLink)
  if IsSecret(qualityInfo) or type(qualityInfo) ~= "table" then
    QUALITY_ATLAS_CACHE[itemID] = false
    return nil
  end

  local atlas = qualityInfo.iconInventory
  if IsSecret(atlas) or type(atlas) ~= "string" then
    QUALITY_ATLAS_CACHE[itemID] = false
    return nil
  end

  QUALITY_ATLAS_CACHE[itemID] = atlas
  return atlas
end

local function GetSpellTexture(spellID)
  if IsSecret(spellID) or type(spellID) ~= "number" then
    return nil
  end

  local texture = C_Spell.GetSpellTexture(spellID)
  return not IsSecret(texture) and texture or nil
end

local function ResolveBagItem(definition)
  for index = 1, #definition.itemIDs do
    local itemID = definition.itemIDs[index]
    local count = GetItemCount(definition, itemID)
    if count and count > 0 then
      return itemID, count, true
    end
  end

  return definition.itemIDs[1], 0, false
end

local function GetEquippedItemData(equipSlot)
  local itemID = GetInventoryItemID("player", equipSlot)
  if IsSecret(itemID) or type(itemID) ~= "number" then
    Tracker.equippedItems[equipSlot] = nil
    Tracker.trinketCooldownData[equipSlot] = nil
    return nil, nil, false
  end

  local cached = Tracker.equippedItems[equipSlot]
  if not cached then
    cached = {}
    Tracker.equippedItems[equipSlot] = cached
  end

  if cached.itemID and cached.itemID ~= itemID then
    Tracker.trinketCooldownData[equipSlot] = nil
    cached.texture = nil
  end
  cached.itemID = itemID

  local texture = C_Item.GetItemIconByID(itemID)
  if not IsSecret(texture) and (type(texture) == "number" or type(texture) == "string") then
    cached.texture = texture
  elseif Tracker.itemDataRequests[itemID] ~= true then
    Tracker.itemDataRequests[itemID] = true
    C_Item.RequestLoadItemDataByID(itemID)
  end

  return itemID, cached.texture, true
end

local function GetEquippedItemID(equipSlot)
  local itemID = GetEquippedItemData(equipSlot)
  return itemID
end

local function GetDefinitionTexture(definition, itemID, spellID)
  if definition.equipSlot then
    local texture = ItemUtil.GetEquipSlotTexture(definition.equipSlot)
    if texture then
      return texture
    end
    local cached = Tracker.equippedItems[definition.equipSlot]
    if cached and cached.texture then
      return cached.texture
    end
  end
  local texture = GetSpellTexture(spellID)
  if texture then
    return texture
  end
  return GetItemTexture(itemID)
end

local function AddDurationSpellID(spellIDs, spellID)
  if IsSecret(spellID) or type(spellID) ~= "number" then
    return
  end
  spellIDs[spellID] = true
end

local function AddCooldownAuraSpellIDs(spellIDs, info)
  local readable = true
  local function Add(spellID)
    if IsSecret(spellID) then
      readable = false
      return
    end
    if type(spellID) == "number" then
      spellIDs[spellID] = true
    end
  end

  Add(info.spellID)
  Add(info.overrideSpellID)
  Add(info.overrideTooltipSpellID)

  local linkedSpellIDs = info.linkedSpellIDs
  if IsSecret(linkedSpellIDs) then
    readable = false
  elseif type(linkedSpellIDs) == "table" then
    for index = 1, #linkedSpellIDs do
      Add(linkedSpellIDs[index])
    end
  end

  return readable
end

local function GetKnownEquipSlotCooldownData(equipSlot, category, collectAuraSpells)
  local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category, false)
  if IsSecret(cooldownIDs) or type(cooldownIDs) ~= "table" then
    return false, nil, false
  end

  local found = false
  local readable = true
  local spellIDs = collectAuraSpells and {} or nil

  for index = 1, #cooldownIDs do
    local cooldownID = cooldownIDs[index]
    if IsSecret(cooldownID) or type(cooldownID) ~= "number" then
      readable = false
    else
      local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
      if IsSecret(info) or type(info) ~= "table" then
        readable = false
      else
        local infoEquipSlot = info.equipSlot
        local isKnown = info.isKnown
        if IsSecret(infoEquipSlot) or IsSecret(isKnown) then
          readable = false
        elseif infoEquipSlot == equipSlot and isKnown == true then
          found = true
          if spellIDs and not AddCooldownAuraSpellIDs(spellIDs, info) then
            readable = false
          end
        end
      end
    end
  end

  if spellIDs and next(spellIDs) == nil then
    spellIDs = nil
  end
  return found, spellIDs, readable
end

local function BuildDurationSpellIDs(definition, itemID, trackedSpellIDs)
  local spellIDs = {}

  if definition.tracksDuration and itemID then
    local _, itemSpellID = C_Item.GetItemSpell(itemID)
    AddDurationSpellID(spellIDs, itemSpellID)
  end

  if trackedSpellIDs then
    for spellID in pairs(trackedSpellIDs) do
      AddDurationSpellID(spellIDs, spellID)
    end
  end

  return next(spellIDs) and spellIDs or nil
end

local function ResolveTrinket(definition, cfg)
  local equipSlot = definition.equipSlot
  local itemID, _, equipped = GetEquippedItemData(equipSlot)
  if not equipped then
    return nil, nil, false, nil, nil, false
  end

  local cached = Tracker.trinketCooldownData[equipSlot]
  if not cached then
    cached = {}
    Tracker.trinketCooldownData[equipSlot] = cached
  end

  local isActive, _, activeReadable = GetKnownEquipSlotCooldownData(
    equipSlot,
    ACTIVE_TRINKET_CATEGORY,
    false
  )
  if activeReadable then
    cached.isActive = isActive
  elseif cached.isActive ~= nil then
    isActive = cached.isActive
  end

  local isTracked, trackedSpellIDs, trackedReadable = GetKnownEquipSlotCooldownData(
    equipSlot,
    TRACKED_TRINKET_CATEGORY,
    true
  )
  if trackedReadable then
    cached.isTracked = isTracked
    cached.trackedSpellIDs = trackedSpellIDs
  else
    if cached.isTracked ~= nil then
      isTracked = cached.isTracked
    end
    if cached.trackedSpellIDs then
      trackedSpellIDs = cached.trackedSpellIDs
    end
  end

  if isActive then
    return itemID, nil, true, "ACTIVE", trackedSpellIDs, false
  end

  local activeKnown = activeReadable or cached.isActive ~= nil
  if not activeKnown then
    return itemID, nil, true, nil, trackedSpellIDs, false
  end

  if isTracked then
    local filtered = cfg.onlyOnUseTrinkets == true
    return itemID, nil, not filtered, "PASSIVE", trackedSpellIDs, filtered
  end

  local trackedKnown = trackedReadable or cached.isTracked ~= nil
  if not trackedKnown then
    return itemID, nil, true, nil, trackedSpellIDs, false
  end

  local filtered = cfg.onlyOnUseTrinkets == true
  return itemID, nil, not filtered, nil, nil, filtered
end

local function ResolveSpell(definition)
  for index = 1, #definition.spellIDs do
    local spellID = definition.spellIDs[index]
    local isKnown = C_SpellBook.IsSpellInSpellBook(spellID)
    if not IsSecret(isKnown) and isKnown == true then
      return spellID, true
    end
  end

  return definition.spellIDs[1], false
end

local function ResolveDefinition(definition, cfg)
  if definition.spellIDs then
    local spellID, available = ResolveSpell(definition)
    return nil, spellID, nil, available, nil, BuildDurationSpellIDs(definition, nil), false
  end
  if definition.equipSlot then
    local itemID, count, available, trinketKind, trackedSpellIDs, filtered = ResolveTrinket(definition, cfg)
    return itemID, nil, count, available, trinketKind, BuildDurationSpellIDs(definition, itemID, trackedSpellIDs), filtered
  end
  local itemID, count, available = ResolveBagItem(definition)
  return itemID, nil, count, available, nil, BuildDurationSpellIDs(definition, itemID), false
end

local function GetCooldown(definition, itemID, spellID)
  local startTime, duration, enabled
  if definition.equipSlot then
    startTime, duration, enabled = GetInventoryItemCooldown("player", definition.equipSlot)
  elseif spellID then
    local info = C_Spell.GetSpellCooldown(spellID)
    if IsSecret(info) or type(info) ~= "table" then
      return nil, nil, nil
    end
    startTime = info.startTime
    duration = info.duration
    enabled = info.isEnabled
  elseif itemID then
    startTime, duration, enabled = C_Item.GetItemCooldown(itemID)
  end

  if IsSecret(startTime) or IsSecret(duration) or IsSecret(enabled) then
    return nil, nil, nil
  end
  if type(startTime) ~= "number" or type(duration) ~= "number" then
    return nil, nil, nil
  end
  return startTime, duration, enabled
end

local function GetKeybind(definition, itemID, spellID)
  local key = spellID and Cooldowns:GetSpellKeybind(spellID)
    or itemID and Cooldowns:GetItemKeybind(itemID)
    or nil
  if not key and definition.equipSlot then
    key = Cooldowns:GetEquipmentSlotKeybind(definition.equipSlot)
  end
  return key or ""
end

local function GetGrowthAnchorPoint(cfg)
  if cfg.orientation == "VERTICAL" then
    if cfg.growth == "UP" then
      return "BOTTOM"
    end
    if cfg.growth == "CENTER" then
      return "CENTER"
    end
    return "TOP"
  end

  if cfg.growth == "LEFT" then
    return "RIGHT"
  end
  if cfg.growth == "CENTER" then
    return "CENTER"
  end
  return "LEFT"
end

local function SaveAnchor(frame, cfg)
  local point = GetGrowthAnchorPoint(cfg)
  local x, y = FrameUtil._GetOffsetsForFrame(frame)
  local width = frame:GetWidth() or 0
  local height = frame:GetHeight() or 0

  if point == "LEFT" then
    x = (x or 0) - width * 0.5
  elseif point == "RIGHT" then
    x = (x or 0) + width * 0.5
  elseif point == "TOP" then
    y = (y or 0) + height * 0.5
  elseif point == "BOTTOM" then
    y = (y or 0) - height * 0.5
  end

  cfg.pos.point = point
  cfg.pos.rel = "UIParent"
  cfg.pos.relPoint = "CENTER"
  cfg.pos.x = Round(x or 0)
  cfg.pos.y = Round(y or 0)
end

local function ApplyAnchor(frame, cfg)
  local pos = cfg.pos
  local point = GetGrowthAnchorPoint(cfg)

  pos.point = point
  pos.rel = "UIParent"
  pos.relPoint = "CENTER"

  frame:ClearAllPoints()
  frame:SetPoint(
    point,
    UIParent,
    "CENTER",
    tonumber(pos.x) or 0,
    tonumber(pos.y) or -120
  )
end

local function EnsureContainer()
  if Tracker.container then
    return Tracker.container
  end

  local container = CreateFrame("Frame", "PleebUI_PCMConsumableTracker", UIParent)
  container:SetSize(1, 1)
  container:SetFrameStrata("MEDIUM")
  container:SetClampedToScreen(true)
  container:Hide()

  Tracker.container = container
  return container
end

local function SetTooltip(icon)
  icon.frame:SetScript("OnEnter", function(frame)
    local definition = icon.definition
    if definition and definition.equipSlot then
      local itemLocation = ItemLocation:CreateFromEquipmentSlot(definition.equipSlot)
      if itemLocation:IsValid() then
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        ItemLocation:ApplyLocationToTooltip(itemLocation, GameTooltip)
        GameTooltip:Show()
      end
      return
    end

    local itemID = icon.itemID
    local spellID = icon.spellID
    if spellID and not IsSecret(spellID) then
      GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
      GameTooltip:SetSpellByID(spellID)
      GameTooltip:Show()
      return
    end
    if not itemID or IsSecret(itemID) then
      return
    end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. tostring(itemID))
    GameTooltip:Show()
  end)
  icon.frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

local function SetTooltipEnabled(icon, enabled)
  icon.frame:EnableMouse(enabled == true)
  if enabled ~= true and GameTooltip:IsOwned(icon.frame) then
    GameTooltip:Hide()
  end
end

local function EnsureIcons()
  local container = EnsureContainer()
  for index = #Tracker.icons + 1, #DEFINITIONS do
    local icon = Presentation.Create("PCMIcon", container)
    icon.definition = DEFINITIONS[index]
    icon.frame:SetFrameLevel(container:GetFrameLevel() + 2)
    icon.frame:Hide()
    SetTooltip(icon)
    Tracker.icons[index] = icon
  end
end

local function RefreshMover()
  local cfg = GetDB()
  local container = EnsureContainer()
  FrameUtil:EnsureGhostMover(TRACKER_MOVER_KEY, {
    label = "Consumable Tracker",
    optionsString = "CooldownManager,consumables",
    useOverlayDrag = true,
    smartSnap = {
      family = "combatBars",
      syncAxis = "NONE",
    },
    liveFrame = function()
      return container
    end,
    shouldShow = function()
      return Tracker.active and (cfg.enabled == true or Tracker.testMode)
    end,
    onDragStop = function(frame)
      SaveAnchor(frame or container, cfg)
      ApplyAnchor(container, cfg)
      FrameUtil:RefreshGhostMover(TRACKER_MOVER_KEY)
    end,
    quickSettings = function()
      local function Rebuild()
        Cooldowns:ConsumableTracker_Rebuild()
        FrameUtil:RefreshGhostMover(TRACKER_MOVER_KEY)
      end

      local controls = {
          {
            type = "toggle",
            label = "Enable tracker",
            get = function() return GetDB().enabled == true end,
            set = function(value) Cooldowns:SetConsumableTrackerEnabled(value) end,
          },
          {
            type = "slider",
            label = "Icon size",
            min = 16,
            max = 86,
            step = 1,
            get = function() return GetDB().iconSize end,
            set = function(value) GetDB().iconSize = Round(value) Rebuild() end,
          },
          {
            type = "slider",
            label = "Spacing",
            min = 0,
            max = 16,
            step = 1,
            get = function() return GetDB().spacing end,
            set = function(value) GetDB().spacing = Round(value) Rebuild() end,
          },
          {
            type = "select",
            label = "Orientation",
            values = {
              HORIZONTAL = "Horizontal",
              VERTICAL = "Vertical",
            },
            sorting = { "HORIZONTAL", "VERTICAL" },
            get = function() return GetDB().orientation end,
            set = function(value)
              local cfg = GetDB()
              cfg.orientation = value
              cfg.growth = value == "VERTICAL" and "DOWN" or "RIGHT"
              Rebuild()
            end,
          },
          {
            type = "select",
            label = "Show counts",
            values = {
              ALWAYS = "Always",
              OOC = "Out of combat",
              NEVER = "Never",
            },
            sorting = { "ALWAYS", "OOC", "NEVER" },
            get = function() return GetDB().countVisibility end,
            set = function(value) GetDB().countVisibility = value Rebuild() end,
          },
          {
            type = "toggle",
            label = "Show item quality",
            get = function() return GetDB().showItemQuality == true end,
            set = function(value) GetDB().showItemQuality = value == true Rebuild() end,
          },
          {
            type = "toggle",
            label = "Show keybinds",
            get = function() return GetDB().showKeybinds == true end,
            set = function(value)
              GetDB().showKeybinds = value == true
              Cooldowns:_Keybinds_Enable()
              Rebuild()
            end,
          },
          {
            type = "toggle",
            label = "Show tooltips",
            get = function() return GetDB().showTooltips == true end,
            set = function(value) GetDB().showTooltips = value == true Rebuild() end,
          },
          {
            type = "toggle",
            label = "Only show on-use trinkets",
            get = function() return GetDB().onlyOnUseTrinkets == true end,
            set = function(value) GetDB().onlyOnUseTrinkets = value == true Rebuild() end,
          },
          {
            type = "toggle",
            label = "Show duration swipe",
            get = function() return GetDB().showDurationSwipe == true end,
            set = function(value) GetDB().showDurationSwipe = value == true Rebuild() end,
          },
          {
            type = "toggle",
            label = "Glow during duration swipe",
            get = function() return GetDB().glowDuringDurationSwipe == true end,
            set = function(value) GetDB().glowDuringDurationSwipe = value == true Rebuild() end,
          },
          {
            type = "toggle",
            label = "Only in combat",
            get = function() return GetDB().combatOnly == true end,
            set = function(value) GetDB().combatOnly = value == true Rebuild() end,
          },
          {
            type = "heading",
            label = "Tracked abilities and items",
          },
      }

      local function AddSlotToggle(definition)
        local slotKey = definition.key
        controls[#controls + 1] = {
          type = "toggle",
          label = definition.label,
          get = function() return GetDB().slots[slotKey].enabled ~= false end,
          set = function(value)
            GetDB().slots[slotKey].enabled = value == true
            Rebuild()
          end,
        }
      end

      for index = 1, #DEFINITIONS do
        AddSlotToggle(DEFINITIONS[index])
      end

      return {
        ownerKey = TRACKER_MOVER_KEY,
        title = "Consumable Tracker",
        description = "Live racial, consumable, and item settings.",
        controls = controls,
      }
    end,
  })
end

local function RefreshCooldownFont(cfg)
  local fontPath = LSM:Fetch("font", cfg.font, true) or STANDARD_TEXT_FONT
  local fontSize = Theme.ResolveFontSize(cfg.cooldownFontSize, "cooldownManager")

  COOLDOWN_FONT_STYLE.font = cfg.font
  COOLDOWN_FONT_STYLE.size = cfg.cooldownFontSize

  if durationFontPath ~= fontPath or durationFontSize ~= fontSize then
    durationFontPath = fontPath
    durationFontSize = fontSize
    durationFont:SetFont(fontPath, fontSize, "OUTLINE")
    durationFont:SetTextColor(1, 1, 1, 1)
    durationFont:SetShadowColor(0, 0, 0, 1)
    durationFont:SetShadowOffset(1, -1)
  end
end

local function ConfigureDurationAuraParts(icon, button, frameLevel, showGlow)
  local parts = AuraWidget.BindApplicationDurationButton(button, {})

  button:ClearAllPoints()
  button:SetAllPoints(icon.frame)
  button:SetFrameStrata(icon.frame:GetFrameStrata())
  button:SetFrameLevel(icon.frame:GetFrameLevel() + frameLevel)
  button:EnableMouse(false)

  AuraWidget.ConfigureIcon(parts)
  AuraWidget.DisableApplicationCount(parts)
  AuraWidget.DisableApplicationBar(parts)
  AuraWidget.DisableDurationBar(parts)
  AuraWidget.ConfigureDurationText(parts, BarWidget.GetDurationFormatter())
  AuraWidget.ConfigureDurationCooldown(parts)
  parts.icon:SetAllPoints(button)
  parts.durationTextHolder:SetAllPoints(button)
  parts.durationTextHolder:SetFrameStrata(button:GetFrameStrata())
  parts.durationTextHolder:SetFrameLevel(button:GetFrameLevel() + 1)
  parts.durationText:SetFontObject(durationFont)
  parts.durationCooldown:SetAllPoints(button)
  parts.durationCooldown:SetReverse(true)
  parts.durationCooldown:SetSwipeColor(0, 0, 0, 0.72)
  parts.durationCooldown:SetDrawSwipe(true)
  parts.durationCooldown:SetDrawEdge(true)
  parts.durationCooldown:SetHideCountdownNumbers(true)

  if showGlow then
    local glowBorder = PCMPresentation.CreateCustomBarBuffGlowBorder(button)
    PCMPresentation.ConfigureCustomBarBuffGlowBorder(
      glowBorder,
      button,
      DURATION_GLOW_STYLE
    )
  end

  button:SetAlpha(1)
end

local function SetDurationAuraEntryActive(entry, active)
  if not entry then
    return
  end

  if entry.plain then
    AuraSlotDriver:SetSlotActive(entry.plain.handle, active and entry.activeVariant == "plain")
  end
  if entry.glow then
    AuraSlotDriver:SetSlotActive(entry.glow.handle, active and entry.activeVariant == "glow")
  end
end

local function EnsureDurationAuraSlot(icon, key, unit, filter, frameLevel, spellIDs, showGlow)
  icon.durationAuraSlots = icon.durationAuraSlots or {}
  local entry = icon.durationAuraSlots[key]
  if not entry then
    entry = {}
    icon.durationAuraSlots[key] = entry
  end

  local variantKey = showGlow and "glow" or "plain"
  local variant = entry[variantKey]
  if not variant then
    variant = {}
    entry[variantKey] = variant
    variant.handle = AuraSlotDriver:CreateSlot(unit, filter, {
      candidateFilters = { includeSpellIDs = spellIDs },
      templateNames = { "PUI_AuraApplicationDurationTemplate" },
      initializeFrame = function(button)
        ConfigureDurationAuraParts(icon, button, frameLevel, showGlow)
      end,
    })
  end

  entry.activeVariant = variantKey
  if variantKey == "plain" and entry.glow then
    AuraSlotDriver:SetSlotActive(entry.glow.handle, false)
  elseif variantKey == "glow" and entry.plain then
    AuraSlotDriver:SetSlotActive(entry.plain.handle, false)
  end

  AuraSlotDriver:SetSlotCandidates(variant.handle, { includeSpellIDs = spellIDs })
  AuraSlotDriver:SetSlotActive(variant.handle, true)
end

local function DeactivateDurationAuraTrack(icon)
  local slots = icon.durationAuraSlots
  if slots then
    for _, entry in pairs(slots) do
      SetDurationAuraEntryActive(entry, false)
    end
  end
end

local function ConfigureDurationAuraTrack(icon, definition, spellIDs, cfg)
  local canRun = Tracker.active
    and (cfg.enabled == true or Tracker.testMode)
    and (Tracker.testMode or cfg.combatOnly ~= true or UnitAffectingCombat("player"))
    and cfg.showDurationSwipe == true
    and type(spellIDs) == "table"
    and next(spellIDs) ~= nil

  if not canRun then
    DeactivateDurationAuraTrack(icon)
    return
  end

  local showGlow = cfg.glowDuringDurationSwipe == true
  EnsureDurationAuraSlot(icon, "player", "player", "HELPFUL|PLAYER", 8, spellIDs, showGlow)

  if definition.equipSlot then
    EnsureDurationAuraSlot(
      icon,
      "targetHelpful",
      "target",
      "HELPFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY",
      7,
      spellIDs,
      showGlow
    )
    EnsureDurationAuraSlot(icon, "targetHarmful", "target", "HARMFUL|PLAYER", 6, spellIDs, showGlow)
  elseif icon.durationAuraSlots then
    SetDurationAuraEntryActive(icon.durationAuraSlots.targetHelpful, false)
    SetDurationAuraEntryActive(icon.durationAuraSlots.targetHarmful, false)
  end
end

local function SetIconCooldown(icon, definition, itemID, spellID)
  if Tracker.combatLockouts[definition.key] then
    icon.cooldown:SetCooldown(0, 0)
    return
  end

  local startTime, duration, enabled = GetCooldown(definition, itemID, spellID)
  if startTime and duration and duration > 0 and enabled ~= false and enabled ~= 0 then
    icon.cooldown:SetCooldown(startTime, duration)
  else
    icon.cooldown:SetCooldown(0, 0)
  end
end

local function ShouldShowCounts(cfg)
  if cfg.countVisibility == "ALWAYS" then
    return true
  end
  return cfg.countVisibility == "OOC" and not UnitAffectingCombat("player")
end

local function SetIconQuality(icon, definition, itemID, cfg)
  local atlas = cfg.showItemQuality and definition.supportsQuality and GetItemQualityAtlas(itemID) or nil
  if atlas then
    icon.qualityTexture:SetAtlas(atlas, true)
    icon.qualityHolder:Show()
  else
    icon.qualityHolder:Hide()
  end
  return atlas
end

local function SetIconRuntime(icon, definition, cfg, available, itemID, spellID, count, trinketKind, durationSpellIDs)
  local keybind = cfg.showKeybinds and GetKeybind(definition, itemID, spellID) or ""
  local countText = ""
  if ShouldShowCounts(cfg) and count and count > 0 then
    countText = tostring(count)
  end

  icon.itemID = itemID
  icon.spellID = spellID
  icon.count = count
  icon.available = available
  icon.trinketKind = trinketKind
  icon.durationSpellIDs = durationSpellIDs
  local texture = GetDefinitionTexture(definition, itemID, spellID)
  if texture then
    icon.icon:SetTexture(texture)
  elseif not definition.equipSlot then
    icon.icon:SetTexture(WHITE_TEXTURE)
  end
  icon.chargeText:SetText(countText)
  icon.keybindText:SetText(keybind)
  SetIconQuality(icon, definition, itemID, cfg)
  SetTooltipEnabled(icon, cfg.showTooltips)
  icon.icon:SetDesaturated(not available or Tracker.combatLockouts[definition.key] == true)
  icon.frame:SetAlpha(available and 1 or cfg.missingAlpha)
  SetIconCooldown(icon, definition, itemID, spellID)
  ConfigureDurationAuraTrack(icon, definition, durationSpellIDs, cfg)
end

local function ConfigureIcon(icon, definition, cfg, available, itemID, spellID, count, trinketKind, durationSpellIDs)
  local keybind = cfg.showKeybinds and GetKeybind(definition, itemID, spellID) or ""
  local countText = ""
  if ShouldShowCounts(cfg) and count and count > 0 then
    countText = tostring(count)
  end
  local qualityAtlas = cfg.showItemQuality and definition.supportsQuality and GetItemQualityAtlas(itemID) or nil
  local texture = GetDefinitionTexture(definition, itemID, spellID)
  if not texture and not definition.equipSlot then
    texture = WHITE_TEXTURE
  end

  Presentation.Apply("PCMIcon", icon, {
    size = cfg.iconSize,
    inset = 1,
    backgroundColor = cfg.backgroundColor,
    borderColor = cfg.borderColor,
    borderSize = cfg.borderSize,
    cooldownFont = { font = cfg.font, size = cfg.cooldownFontSize, flags = "OUTLINE" },
    chargeFont = { font = cfg.font, size = cfg.countFontSize, flags = "OUTLINE" },
    keybindFont = { font = cfg.font, size = cfg.keybindFontSize, flags = "OUTLINE" },
  }, {
    icon = texture,
    cooldownText = "",
    chargeText = countText,
    keybindText = keybind,
    qualityAtlas = qualityAtlas,
  })

  IconSkin.StyleCooldownText(icon.cooldown, COOLDOWN_FONT_STYLE)
  icon.cooldown:SetHideCountdownNumbers(cfg.showCooldownText ~= true)

  icon.itemID = itemID
  icon.spellID = spellID
  icon.count = count
  icon.available = available
  icon.trinketKind = trinketKind
  icon.durationSpellIDs = durationSpellIDs
  SetTooltipEnabled(icon, cfg.showTooltips)
  icon.icon:SetDesaturated(not available or Tracker.combatLockouts[definition.key] == true)
  icon.frame:SetAlpha(available and 1 or cfg.missingAlpha)
  SetIconCooldown(icon, definition, itemID, spellID)
  ConfigureDurationAuraTrack(icon, definition, durationSpellIDs, cfg)
end

local function LayoutIcons(visible, cfg)
  local size = math.max(1, tonumber(cfg.iconSize) or 36)
  local spacing = math.max(0, tonumber(cfg.spacing) or 0)
  local wrap = math.max(1, math.floor(tonumber(cfg.wrap) or #visible))
  local horizontal = cfg.orientation ~= "VERTICAL"
  local primaryNegative = cfg.growth == "LEFT" or cfg.growth == "DOWN"
  local primaryCount = math.min(wrap, math.max(1, #visible))
  local secondaryCount = math.max(1, math.ceil(#visible / wrap))
  local width = horizontal and (primaryCount * size + (primaryCount - 1) * spacing)
    or (secondaryCount * size + (secondaryCount - 1) * spacing)
  local height = horizontal and (secondaryCount * size + (secondaryCount - 1) * spacing)
    or (primaryCount * size + (primaryCount - 1) * spacing)

  Tracker.container:SetSize(math.max(1, width), math.max(1, height))

  for index = 1, #visible do
    local icon = visible[index]
    local zero = index - 1
    local primary = zero % wrap
    local secondary = math.floor(zero / wrap)
    local x, y

    if horizontal then
      x = primary * (size + spacing)
      y = -secondary * (size + spacing)
      if primaryNegative then
        x = width - size - x
      end
    else
      x = secondary * (size + spacing)
      y = -primary * (size + spacing)
      if not primaryNegative then
        y = -height + size + primary * (size + spacing)
      end
    end

    icon.frame:ClearAllPoints()
    icon.frame:SetPoint("TOPLEFT", Tracker.container, "TOPLEFT", x, y)
    icon.frame:Show()
  end
end

local function ShouldShowContainer(cfg)
  if Tracker.testMode then
    return true
  end
  if cfg.enabled ~= true then
    return false
  end
  if cfg.combatOnly and not UnitAffectingCombat("player") then
    return false
  end
  return true
end

local function RefreshEvents()
  local shouldRegister = Tracker.active and (GetDB().enabled == true or Tracker.testMode)
  if shouldRegister == Tracker.eventsRegistered then
    return
  end

  if shouldRegister then
    local events = {
      "PLAYER_ENTERING_WORLD",
      "GROUP_ROSTER_UPDATE",
      "READY_CHECK",
      "BAG_UPDATE_DELAYED",
      "PLAYER_EQUIPMENT_CHANGED",
      "PLAYER_REGEN_DISABLED",
      "PLAYER_REGEN_ENABLED",
      "ITEM_DATA_LOAD_RESULT",
      "SPELL_UPDATE_COOLDOWN",
      "SPELLS_CHANGED",
    }
    for index = 1, #events do
      Tracker.eventFrame:RegisterEvent(events[index])
    end
    Tracker.eventFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    Tracker.eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
  elseif Tracker.eventFrame then
    Tracker.eventFrame:UnregisterAllEvents()
  end

  Tracker.eventsRegistered = shouldRegister
end

function Cooldowns:GetConsumableTrackerDB()
  return GetDB()
end

function Cooldowns:GetConsumableTrackerDefinitions()
  return DEFINITIONS
end

function Cooldowns:GetConsumableItemQualityAtlas(itemID)
  return GetItemQualityAtlas(itemID)
end

function Cooldowns:GetConsumableCategoryItemIDs(categoryID)
  if IsSecret(categoryID) then
    return nil
  end
  return CATEGORY_ITEM_IDS[tonumber(categoryID)]
end

function Cooldowns:GetConsumableTrackerEnabled()
  local cfg = GetDB()
  return cfg and cfg.enabled == true
end

function Cooldowns:SetConsumableTrackerEnabled(enabled)
  local cfg = GetDB()
  cfg.enabled = enabled == true
  self:_Keybinds_Enable()
  self:ConsumableTracker_Rebuild()
  Addon:RequestUpdate("Options", { options = true })
end

local function RefreshContainerVisibility(cfg)
  Tracker.container:SetShown(#Tracker.visibleIcons > 0 and ShouldShowContainer(cfg))
end

local function RelayoutVisibleIcons(cfg)

  local visible = Tracker.visibleIcons
  wipe(visible)
  for index = 1, #Tracker.orderedIcons do
    local icon = Tracker.orderedIcons[index]

    if icon.frame:IsShown() then
      visible[#visible + 1] = icon
    end
  end

  if #visible > 0 then
    LayoutIcons(visible, cfg)
  end
  RefreshContainerVisibility(cfg)
  RefreshMover()
end

local function ShouldShowDefinition(definition, slot, available, filtered)

  if filtered then

    return false

  end

  if Tracker.testMode or available then

    return true

  end

  if definition.key == "healthstone" then

    return Tracker.hasWarlock == true

  end

  return slot.missing == "GRAY"

end

function Cooldowns:ConsumableTracker_Rebuild()
  if not Tracker.active then
    return
  end

  EnsureIcons()
  local cfg = GetDB()
  RefreshCooldownFont(cfg)
  ApplyAnchor(Tracker.container, cfg)

  local ordered = Tracker.orderedIcons
  wipe(ordered)
  for index = 1, #DEFINITIONS do
    ordered[#ordered + 1] = Tracker.icons[index]
  end
  table.sort(ordered, function(left, right)
    local leftSlot = GetSlotDB(cfg, left.definition.key)
    local rightSlot = GetSlotDB(cfg, right.definition.key)
    return (leftSlot.order or 99) < (rightSlot.order or 99)
  end)

  for index = 1, #ordered do
    local icon = ordered[index]
    local definition = icon.definition
    local slot = GetSlotDB(cfg, definition.key)
    DeactivateDurationAuraTrack(icon)
    icon.frame:Hide()

    if slot.enabled ~= false then
      local itemID, spellID, count, available, trinketKind, durationSpellIDs, filtered = ResolveDefinition(definition, cfg)
      local show = ShouldShowDefinition(definition, slot, available, filtered)
      if show then
        ConfigureIcon(icon, definition, cfg, available, itemID, spellID, count, trinketKind, durationSpellIDs)
        icon.frame:Show()
      end
    end
  end

  RelayoutVisibleIcons(cfg)
  RefreshEvents()
end

local function IsBagItemDefinition(definition)
  return definition.itemIDs ~= nil
end

local function IsEquipmentDefinition(definition)
  return definition.equipSlot ~= nil
end

local function IsItemCooldownDefinition(definition)
  return definition.itemIDs ~= nil or definition.equipSlot ~= nil
end

local function IsSpellDefinition(definition)
  return definition.spellIDs ~= nil
end

local function IsHealthstoneDefinition(definition)
  return definition.key == "healthstone"
end

local function HasCombatLockout(definition)
  return definition.combatLockoutSpellID ~= nil
end

local function RefreshDefinitions(predicate)
  if not Tracker.active then
    return
  end

  EnsureIcons()
  local cfg = GetDB()
  local layoutChanged = false
  for index = 1, #Tracker.icons do
    local icon = Tracker.icons[index]
    local definition = icon.definition
    if predicate(definition) then
      local slot = GetSlotDB(cfg, definition.key)
      local wasShown = icon.frame:IsShown()

      if slot.enabled ~= false then
        local itemID, spellID, count, available, trinketKind, durationSpellIDs, filtered = ResolveDefinition(definition, cfg)
        local show = ShouldShowDefinition(definition, slot, available, filtered)
        
        if show then
          if wasShown then
            SetIconRuntime(icon, definition, cfg, available, itemID, spellID, count, trinketKind, durationSpellIDs)
          else
            ConfigureIcon(icon, definition, cfg, available, itemID, spellID, count, trinketKind, durationSpellIDs)
            icon.frame:Show()
            layoutChanged = true
          end
        else
          DeactivateDurationAuraTrack(icon)
          if wasShown then
            icon.frame:Hide()
            layoutChanged = true
          end
        end
      else
        DeactivateDurationAuraTrack(icon)
        if wasShown then
          icon.frame:Hide()
          layoutChanged = true
        end
      end
    end
  end

  if layoutChanged then
    RelayoutVisibleIcons(cfg)
  else
    RefreshContainerVisibility(cfg)
  end
end

local function IsTrackedCooldownItemID(itemID)
  if IsSecret(itemID) or type(itemID) ~= "number" then
    return false
  end

  if TRACKED_ITEM_IDS[itemID] == true then
    return true
  end

  for _, cached in pairs(Tracker.equippedItems) do
    if cached and cached.itemID == itemID then
      return true
    end
  end

  return false
end

local function IconUsesCooldownSpellID(icon, spellID)
  if IsSecret(spellID) or type(spellID) ~= "number" then
    return false
  end

  local definition = icon.definition
  local spellIDs = definition and definition.spellIDs
  if spellIDs then
    for index = 1, #spellIDs do
      if spellIDs[index] == spellID then
        return true
      end
    end
  end

  local durationSpellIDs = icon.durationSpellIDs
  return type(durationSpellIDs) == "table" and durationSpellIDs[spellID] == true
end

local function RefreshCooldownEvent(spellID, baseSpellID, itemID)
  if not Tracker.active then
    return
  end

  local refreshItems = IsTrackedCooldownItemID(itemID)

  for index = 1, #Tracker.icons do
    local icon = Tracker.icons[index]
    if icon.frame:IsShown() then
      local definition = icon.definition
      local refresh = refreshItems and IsItemCooldownDefinition(definition)

      if not refresh then
        refresh = IconUsesCooldownSpellID(icon, spellID)
          or IconUsesCooldownSpellID(icon, baseSpellID)
      end

      if refresh then
        SetIconCooldown(icon, definition, icon.itemID, icon.spellID)
      end
    end
  end
end

local function RefreshCountsAndVisibility()
  if not Tracker.active then
    return
  end

  local cfg = GetDB()
  local showCounts = ShouldShowCounts(cfg)
  for index = 1, #Tracker.icons do
    local icon = Tracker.icons[index]
    if icon.frame:IsShown() then
      local count = icon.count
      icon.chargeText:SetText(showCounts and count and count > 0 and tostring(count) or "")
      ConfigureDurationAuraTrack(icon, icon.definition, icon.durationSpellIDs, cfg)
    end
  end
  RefreshContainerVisibility(cfg)
end

local function GetItemInfoOwners(itemID)
  if IsSecret(itemID) or type(itemID) ~= "number" then
    return false, false
  end

  local ownsBagItem = TRACKED_ITEM_IDS[itemID] == true
  local ownsEquippedItem = false
  for index = 1, #DEFINITIONS do
    local definition = DEFINITIONS[index]
    if definition.equipSlot then
      local equippedItemID = GetEquippedItemID(definition.equipSlot)
      if equippedItemID == itemID then
        ownsEquippedItem = true
        break
      end
    end
  end
  return ownsBagItem, ownsEquippedItem
end

local function SetHealthstoneCombatLockout(spellID)
  if IsSecret(spellID) or type(spellID) ~= "number" or not InCombatLockdown() then
    return
  end

  local definition = COMBAT_LOCKOUT_SPELLS[spellID]
  if not definition then
    return
  end

  Tracker.combatLockouts[definition.key] = true
  RefreshDefinitions(HasCombatLockout)
end

local function ClearHealthstoneCombatLockouts()
  if not next(Tracker.combatLockouts) then
    return
  end

  wipe(Tracker.combatLockouts)
  RefreshDefinitions(HasCombatLockout)
end

PCMRuntime:RegisterSubscriber("ConsumableTracker", {
  OnLifecycleEvent = function(event)
    if event == "LOADING_SCREEN_DISABLED"
      or event == "COOLDOWN_VIEWER_DATA_LOADED"
      or event == "COOLDOWN_VIEWER_TABLE_HOTFIXED"
    then
      RefreshDefinitions(IsEquipmentDefinition)
    end
  end,
})

function Cooldowns:ConsumableTracker_RefreshKeybinds()
  if not (Tracker.active and GetDB().showKeybinds) then
    return
  end

  for index = 1, #Tracker.icons do
    local icon = Tracker.icons[index]
    if icon.frame:IsShown() then
      icon.keybindText:SetText(GetKeybind(icon.definition, icon.itemID, icon.spellID))
    end
  end
end

function Cooldowns:ConsumableTracker_RefreshFonts()
  if not Tracker.active then
    return
  end

  local cfg = GetDB()
  RefreshCooldownFont(cfg)
  for index = 1, #Tracker.icons do
    IconSkin.StyleCooldownText(Tracker.icons[index].cooldown, COOLDOWN_FONT_STYLE)
  end
end

function Cooldowns:ConsumableTracker_SetTestMode(enabled)
  Tracker.testMode = enabled == true
  self:ConsumableTracker_Rebuild()
end

function Cooldowns:ConsumableTracker_Enable()
  if Tracker.active then
    self:ConsumableTracker_Rebuild()
    return
  end

  Tracker.active = true
  PCMRuntime:SetSubscriberEnabled("ConsumableTracker", true)
  Tracker.eventFrame = Tracker.eventFrame or CreateFrame("Frame")
  Tracker.eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
    if event == "PLAYER_ENTERING_WORLD" then
      wipe(Tracker.combatLockouts)
      RefreshWarlockPresence()
      Cooldowns:ConsumableTracker_Rebuild()
    elseif event == "GROUP_ROSTER_UPDATE" then
      if RefreshWarlockPresence() then
        RefreshDefinitions(IsHealthstoneDefinition)
      end

    elseif event == "READY_CHECK" then
      ShowMissingHealthstoneWarning()

    elseif event == "BAG_UPDATE_DELAYED" then
      RefreshDefinitions(IsBagItemDefinition)
    elseif event == "UNIT_INVENTORY_CHANGED" then
      RefreshDefinitions(IsEquipmentDefinition)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
      RefreshDefinitions(IsEquipmentDefinition)
    elseif event == "ITEM_DATA_LOAD_RESULT" then
      local itemID = arg1
      local success = arg2
      if not IsSecret(itemID) and type(itemID) == "number" then
        Tracker.itemDataRequests[itemID] = nil

        if not IsSecret(success) and success == true then
          local ownsBagItem, ownsEquippedItem = GetItemInfoOwners(itemID)
          if ownsBagItem then
            RefreshDefinitions(IsBagItemDefinition)
          end
          if ownsEquippedItem then
            RefreshDefinitions(IsEquipmentDefinition)
          end
        end
      end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
      RefreshCooldownEvent(arg1, arg2, arg5)
    elseif event == "SPELLS_CHANGED" then
      RefreshDefinitions(IsSpellDefinition)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
      SetHealthstoneCombatLockout(arg3)
    elseif event == "PLAYER_REGEN_DISABLED" then
      wipe(Tracker.combatLockouts)
      RefreshCountsAndVisibility()
    elseif event == "PLAYER_REGEN_ENABLED" then
      local warlockChanged = false
      if Tracker.warlockRosterDirty then
        warlockChanged = RefreshWarlockPresence()
      end

      ClearHealthstoneCombatLockouts()

      if warlockChanged then
        RefreshDefinitions(IsHealthstoneDefinition)
      end

      RefreshCountsAndVisibility()
    end
  end)

  RefreshWarlockPresence()
  RefreshEvents()
  EnsureContainer()
  self:ConsumableTracker_Rebuild()
end

function Cooldowns:ConsumableTracker_Disable()
  Tracker.active = false
  Tracker.testMode = false
  PCMRuntime:SetSubscriberEnabled("ConsumableTracker", false)
  Tracker.hasWarlock = false
  Tracker.warlockRosterDirty = false
  wipe(Tracker.combatLockouts)
  wipe(Tracker.itemDataRequests)
  if Tracker.eventFrame then
    Tracker.eventFrame:UnregisterAllEvents()
  end
  Tracker.eventsRegistered = false
  for index = 1, #Tracker.icons do
    DeactivateDurationAuraTrack(Tracker.icons[index])
  end
  if Tracker.container then
    Tracker.container:Hide()
  end
  FrameUtil:RefreshGhostMover(TRACKER_MOVER_KEY)
end

function Cooldowns:_ConsumableTracker_ApplySettings(flags)
  if flags and (flags.profile or flags.theme or flags.fonts or flags.layout or flags.movers) then
    self:ConsumableTracker_Rebuild()
  end
end

function Cooldowns:_ConsumableTracker_SoftRebuild(flags)
  if flags and (flags.profile or flags.layout or flags.movers) then
    self:ConsumableTracker_Rebuild()
  end
end

local TestParticipant = {
  label = "Consumable Tracker",
  order = 30,
  defaultEnabled = true,
}

function TestParticipant:IsAvailable()
  return ns.PCM_IsModuleEnabledFast() == true
end

function TestParticipant:Start()
  if InCombatLockdown() then
    return false
  end
  Cooldowns:ConsumableTracker_SetTestMode(true)
  return true
end

function TestParticipant:Stop()
  Cooldowns:ConsumableTracker_SetTestMode(false)
  return true
end

function TestParticipant:Refresh()
  Cooldowns:ConsumableTracker_Rebuild()
  return true
end

ns.TestMode:RegisterParticipant(PARTICIPANT_KEY, TestParticipant)

Cooldowns.GetConsumableTrackerDB = P:Def("Cooldowns:GetConsumableTrackerDB", Cooldowns.GetConsumableTrackerDB)
Cooldowns.GetConsumableTrackerDefinitions = P:Def("Cooldowns:GetConsumableTrackerDefinitions", Cooldowns.GetConsumableTrackerDefinitions)
Cooldowns.GetConsumableItemQualityAtlas = P:Def("Cooldowns:GetConsumableItemQualityAtlas", Cooldowns.GetConsumableItemQualityAtlas)
Cooldowns.GetConsumableCategoryItemIDs = P:Def("Cooldowns:GetConsumableCategoryItemIDs", Cooldowns.GetConsumableCategoryItemIDs)
Cooldowns.GetConsumableTrackerEnabled = P:Def("Cooldowns:GetConsumableTrackerEnabled", Cooldowns.GetConsumableTrackerEnabled)
Cooldowns.SetConsumableTrackerEnabled = P:Def("Cooldowns:SetConsumableTrackerEnabled", Cooldowns.SetConsumableTrackerEnabled)
Cooldowns.ConsumableTracker_Rebuild = P:Def("Cooldowns:ConsumableTracker_Rebuild", Cooldowns.ConsumableTracker_Rebuild)
Cooldowns.ConsumableTracker_RefreshKeybinds = P:Def("Cooldowns:ConsumableTracker_RefreshKeybinds", Cooldowns.ConsumableTracker_RefreshKeybinds)
Cooldowns.ConsumableTracker_RefreshFonts = P:Def("Cooldowns:ConsumableTracker_RefreshFonts", Cooldowns.ConsumableTracker_RefreshFonts)
Cooldowns.ConsumableTracker_SetTestMode = P:Def("Cooldowns:ConsumableTracker_SetTestMode", Cooldowns.ConsumableTracker_SetTestMode)
Cooldowns.ConsumableTracker_Enable = P:Def("Cooldowns:ConsumableTracker_Enable", Cooldowns.ConsumableTracker_Enable)
Cooldowns.ConsumableTracker_Disable = P:Def("Cooldowns:ConsumableTracker_Disable", Cooldowns.ConsumableTracker_Disable)
Cooldowns._ConsumableTracker_ApplySettings = P:Def("Cooldowns:_ConsumableTracker_ApplySettings", Cooldowns._ConsumableTracker_ApplySettings)
Cooldowns._ConsumableTracker_SoftRebuild = P:Def("Cooldowns:_ConsumableTracker_SoftRebuild", Cooldowns._ConsumableTracker_SoftRebuild)
