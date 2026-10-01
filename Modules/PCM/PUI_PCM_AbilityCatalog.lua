local ADDON_NAME, ns = ...

local Catalog = {}
ns.PCMAbilityCatalog = Catalog
ns.PCMCatalog = Catalog

local DB = ns.PCM_DBExports
local C_CooldownViewer = C_CooldownViewer
local C_Spell = C_Spell
local Enum = Enum
local EventRegistry = EventRegistry
local FlagsUtil = FlagsUtil
local CreateFromMixins = CreateFromMixins
local DirtiableMixin = DirtiableMixin
local issecretvalue = issecretvalue
local type = type
local tostring = tostring

local SETTINGS_FAMILY_COOLDOWN = "cooldown"
local SETTINGS_FAMILY_BUFF = "buff"
local SETTINGS_FAMILY_BAR = "bar"
local ESSENTIAL_VIEWER_KEY = "EssentialCooldownViewer"
local UTILITY_VIEWER_KEY = "UtilityCooldownViewer"
local BUFF_ICON_VIEWER_KEY = "BuffIconCooldownViewer"
local BUFF_BAR_VIEWER_KEY = "BuffBarCooldownViewer"
local POWER_INFUSION_SPELL_IDS = { 10060 }
local BLOODLUST_SPELL_IDS = { 2825, 32182, 80353, 264667, 390386, 466904 }

local EMPTY = {}
local ACTIVE_SOURCE_CATEGORIES = {
  [Enum.CooldownViewerCategory.Essential] = true,
  [Enum.CooldownViewerCategory.Utility] = true,
  [Enum.CooldownViewerCategory.SpecAgnosticEssential] = true,
  [Enum.CooldownViewerCategory.EquipSlotEssential] = true,
  [Enum.CooldownViewerCategory.TrackedBuff] = true,
  [Enum.CooldownViewerCategory.TrackedBar] = true,
  [Enum.CooldownViewerCategory.SpecAgnosticTracked] = true,
  [Enum.CooldownViewerCategory.EquipSlotTracked] = true,
}

local ENTRY_SCALAR_FIELDS = {
  "cooldownID",
  "catalogKey",
  "settingsFamily",
  "settingsKey",
  "globalOrder",
  "viewerKey",
  "viewerOrder",
  "sourceCategory",
  "defaultCategory",
  "resolvedCategory",
  "flags",
  "isKnown",
  "isInvisible",
  "hasAura",
  "selfAura",
  "charges",
  "hideAura",
  "hideByDefault",
  "entryKind",
  "baseSpellID",
  "overrideSpellID",
  "overrideTooltipSpellID",
  "staticDisplaySpellID",
  "chargeSpellID",
  "canonicalSpellID",
  "equipSlot",
  "buffSlot",
  "spellCategoryID",
  "staticName",
  "staticIcon",
  "name",
  "texture",
  "hasCharges",
  "cooldownSpellID",
  "spellID",
  "playerAuraOnly",
  "includeAnySource",
}

local STRUCTURAL_EVENTS = {
  "COOLDOWN_VIEWER_DATA_LOADED",
  "COOLDOWN_VIEWER_TABLE_HOTFIXED",
  "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED",
  "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
  "PLAYER_SPECIALIZATION_CHANGED",
  "ACTIVE_COMBAT_CONFIG_CHANGED",
  "ACTIVE_TALENT_GROUP_CHANGED",
  "TRAIT_CONFIG_UPDATED",
  "PLAYER_TALENT_UPDATE",
  "PLAYER_PVP_TALENT_UPDATE",
  "SPELLS_CHANGED",
  "PLAYER_EQUIPMENT_CHANGED",
  "PLAYER_ENTERING_WORLD",
}

local state = {
  generation = 0,
  dirty = true,
  invalidationSerial = 1,
  entries = EMPTY,
  viewerEntries = {
    [ESSENTIAL_VIEWER_KEY] = EMPTY,
    [UTILITY_VIEWER_KEY] = EMPTY,
    [BUFF_ICON_VIEWER_KEY] = EMPTY,
    [BUFF_BAR_VIEWER_KEY] = EMPTY,
  },
}

local listeners = {}
local eventFrame = CreateFrame("Frame")
local enabled = false
local enableOwners = setmetatable({}, { __mode = "k" })

local refreshUpdater = CreateFromMixins(DirtiableMixin)

local function IsSecretValue(value)
  return issecretvalue(value) == true
end

local function ReadRequiredNumber(value)
  if IsSecretValue(value) or type(value) ~= "number" then
    return nil, false
  end
  return value, true
end

local function ReadRequiredPositiveNumber(value)
  local numberValue, valid = ReadRequiredNumber(value)
  if not valid or numberValue <= 0 then
    return nil, false
  end
  return numberValue, true
end

local function ReadOptionalPositiveNumber(value)
  if IsSecretValue(value) then
    return nil, false
  end
  if value == nil then
    return nil, true
  end
  if type(value) ~= "number" then
    return nil, false
  end
  if value <= 0 then
    return nil, true
  end
  return value, true
end

local function ReadRequiredBoolean(value)
  if IsSecretValue(value) or type(value) ~= "boolean" then
    return nil, false
  end
  return value, true
end

local function ReadTable(value)
  if IsSecretValue(value) or type(value) ~= "table" then
    return nil, false
  end
  return value, true
end

local function CopyLinkedSpellIDs(source)
  local sourceTable, valid = ReadTable(source)
  if not valid then
    return nil, false
  end

  local linkedSpellIDs = {}
  for index = 1, #sourceTable do
    local spellID, spellValid = ReadRequiredPositiveNumber(sourceTable[index])
    if not spellValid then
      return nil, false
    end
    linkedSpellIDs[#linkedSpellIDs + 1] = spellID
  end
  return linkedSpellIDs, true
end

local function ResolveBaseSpellID(spellID)
  if not spellID then
    return nil, true
  end

  local baseSpellID = C_Spell.GetBaseSpell(spellID)
  if IsSecretValue(baseSpellID) then
    return nil, false
  end
  if baseSpellID == nil then
    return spellID, true
  end
  if type(baseSpellID) ~= "number" or baseSpellID <= 0 then
    return nil, false
  end
  return baseSpellID, true
end

local function AddIdentitySpellID(identitySpellIDs, seen, spellID)
  if not spellID or seen[spellID] then
    return true
  end

  seen[spellID] = true
  identitySpellIDs[#identitySpellIDs + 1] = spellID

  local baseSpellID, valid = ResolveBaseSpellID(spellID)
  if not valid then
    return false
  end
  if baseSpellID and not seen[baseSpellID] then
    seen[baseSpellID] = true
    identitySpellIDs[#identitySpellIDs + 1] = baseSpellID
  end
  return true
end

local function ReadStaticPresentation(spellID)
  if not spellID then
    return nil, nil
  end

  local name = C_Spell.GetSpellName(spellID)
  if IsSecretValue(name) or type(name) ~= "string" or name == "" then
    name = nil
  end

  local icon = C_Spell.GetSpellTexture(spellID)
  if IsSecretValue(icon) or (type(icon) ~= "number" and type(icon) ~= "string") then
    icon = nil
  end

  return name, icon
end

local function GetEntryKind(equipSlot, spellCategoryID, baseSpellID, overrideSpellID, overrideTooltipSpellID, linkedSpellIDs)
  if equipSlot then
    return "equipmentSlot"
  end
  if spellCategoryID then
    return "spellCategory"
  end
  if baseSpellID or overrideSpellID or overrideTooltipSpellID or linkedSpellIDs[1] then
    return "spell"
  end
  return "unsupported"
end

local function BuildEntry(cooldownID, globalOrder, sourceInfo, defaultCategory, resolvedCategory, viewerKey, viewerOrder)
  local sourceTable, sourceValid = ReadTable(sourceInfo)
  if not sourceValid then
    return nil
  end

  local sourceCooldownID, valid = ReadRequiredPositiveNumber(sourceTable.cooldownID)
  if not valid or sourceCooldownID ~= cooldownID then
    return nil
  end

  local sourceCategory
  sourceCategory, valid = ReadRequiredNumber(sourceTable.category)
  if not valid then
    return nil
  end

  local flags
  flags, valid = ReadRequiredNumber(sourceTable.flags)
  if not valid then
    return nil
  end

  local isKnown
  isKnown, valid = ReadRequiredBoolean(sourceTable.isKnown)
  if not valid then
    return nil
  end

  local isInvisible
  isInvisible, valid = ReadRequiredBoolean(sourceTable.isInvisible)
  if not valid then
    return nil
  end

  local hasAura
  hasAura, valid = ReadRequiredBoolean(sourceTable.hasAura)
  if not valid then
    return nil
  end

  local selfAura
  selfAura, valid = ReadRequiredBoolean(sourceTable.selfAura)
  if not valid then
    return nil
  end

  local charges
  charges, valid = ReadRequiredBoolean(sourceTable.charges)
  if not valid then
    return nil
  end

  local baseSpellID
  baseSpellID, valid = ReadOptionalPositiveNumber(sourceTable.spellID)
  if not valid then
    return nil
  end

  local overrideSpellID
  overrideSpellID, valid = ReadOptionalPositiveNumber(sourceTable.overrideSpellID)
  if not valid then
    return nil
  end

  local overrideTooltipSpellID
  overrideTooltipSpellID, valid = ReadOptionalPositiveNumber(sourceTable.overrideTooltipSpellID)
  if not valid then
    return nil
  end

  local equipSlot
  equipSlot, valid = ReadOptionalPositiveNumber(sourceTable.equipSlot)
  if not valid then
    return nil
  end

  local buffSlot
  buffSlot, valid = ReadOptionalPositiveNumber(sourceTable.buffSlot)
  if not valid then
    return nil
  end

  local spellCategoryID
  spellCategoryID, valid = ReadOptionalPositiveNumber(sourceTable.spellCategoryID)
  if not valid then
    return nil
  end

  local linkedSpellIDs
  linkedSpellIDs, valid = CopyLinkedSpellIDs(sourceTable.linkedSpellIDs)
  if not valid then
    return nil
  end

  local familySpellID = overrideTooltipSpellID or overrideSpellID or baseSpellID
  local canonicalSpellID
  if familySpellID then
    canonicalSpellID, valid = ResolveBaseSpellID(familySpellID)
    if not valid then
      return nil
    end
  end

  local identitySpellIDs = {}
  local seenIdentitySpellIDs = {}
  if not AddIdentitySpellID(identitySpellIDs, seenIdentitySpellIDs, baseSpellID)
    or not AddIdentitySpellID(identitySpellIDs, seenIdentitySpellIDs, overrideSpellID)
    or not AddIdentitySpellID(identitySpellIDs, seenIdentitySpellIDs, overrideTooltipSpellID)
  then
    return nil
  end

  for index = 1, #linkedSpellIDs do
    if not AddIdentitySpellID(identitySpellIDs, seenIdentitySpellIDs, linkedSpellIDs[index]) then
      return nil
    end
  end

  local staticDisplaySpellID = overrideTooltipSpellID or overrideSpellID or baseSpellID
  local staticName, staticIcon = ReadStaticPresentation(staticDisplaySpellID)
  local displayName = staticName
    or (equipSlot and ("Equipment slot " .. tostring(equipSlot)))
    or (spellCategoryID and ("Cooldown category " .. tostring(spellCategoryID)))
    or UNKNOWN

  local settingsFamily = SETTINGS_FAMILY_COOLDOWN
  if viewerKey == BUFF_ICON_VIEWER_KEY then
    settingsFamily = SETTINGS_FAMILY_BUFF
  elseif viewerKey == BUFF_BAR_VIEWER_KEY then
    settingsFamily = SETTINGS_FAMILY_BAR
  end

  return {
    cooldownID = cooldownID,
    catalogKey = "cooldown:" .. tostring(cooldownID),
    settingsFamily = settingsFamily,
    settingsKey = nil,

    globalOrder = globalOrder,
    viewerKey = viewerKey,
    viewerOrder = viewerOrder,

    sourceCategory = sourceCategory,
    defaultCategory = defaultCategory,
    resolvedCategory = resolvedCategory,

    flags = flags,
    isKnown = isKnown,
    isInvisible = isInvisible,
    hasAura = hasAura,
    selfAura = selfAura,
    charges = charges,
    hideAura = FlagsUtil.IsSet(flags, Enum.CooldownSetSpellFlags.HideAura) == true,
    hideByDefault = FlagsUtil.IsSet(flags, Enum.CooldownSetSpellFlags.HideByDefault) == true,

    entryKind = GetEntryKind(
      equipSlot,
      spellCategoryID,
      baseSpellID,
      overrideSpellID,
      overrideTooltipSpellID,
      linkedSpellIDs
    ),

    baseSpellID = baseSpellID,
    overrideSpellID = overrideSpellID,
    overrideTooltipSpellID = overrideTooltipSpellID,
    linkedSpellIDs = linkedSpellIDs,

    staticDisplaySpellID = staticDisplaySpellID,
    chargeSpellID = overrideSpellID or baseSpellID,
    canonicalSpellID = canonicalSpellID,
    identitySpellIDs = identitySpellIDs,

    equipSlot = equipSlot,
    buffSlot = buffSlot,
    spellCategoryID = spellCategoryID,

    staticName = staticName,
    staticIcon = staticIcon,
    name = displayName,
    texture = staticIcon or 134400,
    hasCharges = charges,
    cooldownSpellID = staticDisplaySpellID,
    spellID = staticDisplaySpellID,
  }
end

local function BuildOrderMap(source)
  local sourceTable, valid = ReadTable(source)
  if not valid then
    return nil
  end

  local orderByCooldownID = {}
  for index = 1, #sourceTable do
    local cooldownID, idValid = ReadRequiredPositiveNumber(sourceTable[index])
    if not idValid or orderByCooldownID[cooldownID] ~= nil then
      return nil
    end
    orderByCooldownID[cooldownID] = index
  end
  return orderByCooldownID
end

local function ReadProviderCategory(provider, cooldownID)
  local defaults = provider:GetCooldownDefaults(cooldownID)
  local defaultTable, defaultsValid = ReadTable(defaults)
  if not defaultsValid then
    return nil, nil, false
  end

  local defaultCategory, categoryValid = ReadRequiredNumber(defaultTable.category)
  if not categoryValid then
    return nil, nil, false
  end

  local resolvedInfo = provider:GetCooldownInfoForID(cooldownID)
  local resolvedTable, resolvedValid = ReadTable(resolvedInfo)
  if not resolvedValid then
    return nil, nil, false
  end

  local resolvedCategory
  resolvedCategory, categoryValid = ReadRequiredNumber(resolvedTable.category)
  if not categoryValid then
    return nil, nil, false
  end

  return defaultCategory, resolvedCategory, true
end

local function AssignSettingsKeys(entries)
  local canonicalCounts = {
    [SETTINGS_FAMILY_COOLDOWN] = {},
    [SETTINGS_FAMILY_BUFF] = {},
    [SETTINGS_FAMILY_BAR] = {},
  }

  for index = 1, #entries do
    local entry = entries[index]
    if entry.entryKind == "spell"
      and entry.canonicalSpellID
      and entry.isKnown == true
      and entry.viewerKey ~= nil
    then
      local counts = canonicalCounts[entry.settingsFamily]
      counts[entry.canonicalSpellID] = (counts[entry.canonicalSpellID] or 0) + 1
    end
  end

  for index = 1, #entries do
    local entry = entries[index]
    if entry.entryKind == "spell"
      and entry.canonicalSpellID
      and canonicalCounts[entry.settingsFamily][entry.canonicalSpellID] == 1
    then
      entry.settingsKey = tostring(entry.canonicalSpellID)
    else
      entry.settingsKey = "c" .. tostring(entry.cooldownID)
    end
  end
end

local function BuildCustomAuraEntry(catalogKey, spellIDs, viewerOrder, globalOrder, displayName)
  local identitySpellIDs = {}
  local seenIdentitySpellIDs = {}
  for index = 1, #spellIDs do
    if not AddIdentitySpellID(identitySpellIDs, seenIdentitySpellIDs, spellIDs[index]) then
      return nil
    end
  end

  local displaySpellID = spellIDs[1]
  local canonicalSpellID, valid = ResolveBaseSpellID(displaySpellID)
  if not valid then
    return nil
  end
  local staticName, staticIcon = ReadStaticPresentation(displaySpellID)

  return {
    cooldownID = catalogKey,
    catalogKey = catalogKey,
    settingsFamily = SETTINGS_FAMILY_BUFF,
    settingsKey = nil,
    globalOrder = globalOrder,
    viewerKey = BUFF_ICON_VIEWER_KEY,
    viewerOrder = viewerOrder,
    sourceCategory = Enum.CooldownViewerCategory.TrackedBuff,
    defaultCategory = Enum.CooldownViewerCategory.TrackedBuff,
    resolvedCategory = Enum.CooldownViewerCategory.TrackedBuff,
    flags = 0,
    isKnown = true,
    isInvisible = false,
    hasAura = true,
    selfAura = true,
    charges = false,
    hideAura = false,
    hideByDefault = false,
    entryKind = "spell",
    baseSpellID = displaySpellID,
    overrideSpellID = nil,
    overrideTooltipSpellID = nil,
    linkedSpellIDs = {},
    staticDisplaySpellID = displaySpellID,
    chargeSpellID = displaySpellID,
    canonicalSpellID = canonicalSpellID,
    identitySpellIDs = identitySpellIDs,
    equipSlot = nil,
    buffSlot = nil,
    spellCategoryID = nil,
    staticName = staticName,
    staticIcon = staticIcon,
    name = displayName or staticName or ("Spell " .. tostring(displaySpellID)),
    texture = staticIcon or 134400,
    hasCharges = false,
    cooldownSpellID = displaySpellID,
    spellID = displaySpellID,
    playerAuraOnly = true,
    includeAnySource = true,
  }
end

local function AddCustomBuffEntries(entries, viewerEntries)
  local tracking = DB.GetBuffIconTrackingDB()
  if not tracking then
    return
  end

  local buffEntries = viewerEntries[BUFF_ICON_VIEWER_KEY]
  local trackedSpellIDs = {}
  for index = 1, #buffEntries do
    local entry = buffEntries[index]
    local identitySpellIDs = entry.identitySpellIDs
    for identityIndex = 1, #identitySpellIDs do
      trackedSpellIDs[identitySpellIDs[identityIndex]] = entry
    end
  end

  local function AddEntry(catalogKey, spellIDs, displayName)
    local existingEntry
    for index = 1, #spellIDs do
      if trackedSpellIDs[spellIDs[index]] then
        existingEntry = trackedSpellIDs[spellIDs[index]]
        break
      end
    end

    if existingEntry then
      local seenIdentitySpellIDs = {}
      for index = 1, #existingEntry.identitySpellIDs do
        seenIdentitySpellIDs[existingEntry.identitySpellIDs[index]] = true
      end
      for index = 1, #spellIDs do
        if not AddIdentitySpellID(
          existingEntry.identitySpellIDs,
          seenIdentitySpellIDs,
          spellIDs[index]
        ) then
          return
        end
      end
      existingEntry.playerAuraOnly = true
      existingEntry.includeAnySource = true
      for index = 1, #existingEntry.identitySpellIDs do
        trackedSpellIDs[existingEntry.identitySpellIDs[index]] = existingEntry
      end
      return
    end

    local entry = BuildCustomAuraEntry(
      catalogKey,
      spellIDs,
      #buffEntries + 1,
      #entries + 1,
      displayName
    )
    if not entry then
      return
    end

    entries[#entries + 1] = entry
    buffEntries[#buffEntries + 1] = entry
    for index = 1, #entry.identitySpellIDs do
      trackedSpellIDs[entry.identitySpellIDs[index]] = entry
    end
  end

  if tracking.powerInfusion == true then
    AddEntry("custom-aura:power-infusion", POWER_INFUSION_SPELL_IDS, "Power Infusion")
  end
  if tracking.bloodlust == true then
    AddEntry("custom-aura:bloodlust", BLOODLUST_SPELL_IDS, "Bloodlust")
  end

  for index = 1, #tracking.customSpellIDs do
    local spellID = tonumber(tracking.customSpellIDs[index])
    if spellID and spellID > 0 and spellID == math.floor(spellID) then
      AddEntry("custom-aura:" .. tostring(spellID), { spellID })
    end
  end
end

local function BuildGeneration()
  local settings = _G.CooldownViewerSettings
  if not settings then
    return nil
  end

  local provider = settings:GetDataProvider()
  if not provider or not provider:GetLayoutManager() then
    return nil
  end
  if provider:IsLayoutUpdateQueued() then
    return nil
  end

  local allIDs = provider:GetOrderedCooldownIDs()
  local allIDTable, allIDsValid = ReadTable(allIDs)
  if not allIDsValid then
    return nil
  end

  local essentialIDs = provider:GetOrderedCooldownIDsForCategory(Enum.CooldownViewerCategory.Essential)
  local utilityIDs = provider:GetOrderedCooldownIDsForCategory(Enum.CooldownViewerCategory.Utility)
  local buffIconIDs = provider:GetOrderedCooldownIDsForCategory(Enum.CooldownViewerCategory.TrackedBuff)
  local buffBarIDs = provider:GetOrderedCooldownIDsForCategory(Enum.CooldownViewerCategory.TrackedBar)
  local essentialOrder = BuildOrderMap(essentialIDs)
  local utilityOrder = BuildOrderMap(utilityIDs)
  local buffIconOrder = BuildOrderMap(buffIconIDs)
  local buffBarOrder = BuildOrderMap(buffBarIDs)
  if not essentialOrder or not utilityOrder or not buffIconOrder or not buffBarOrder then
    return nil
  end

  local viewerOrders = {
    [ESSENTIAL_VIEWER_KEY] = essentialOrder,
    [UTILITY_VIEWER_KEY] = utilityOrder,
    [BUFF_ICON_VIEWER_KEY] = buffIconOrder,
    [BUFF_BAR_VIEWER_KEY] = buffBarOrder,
  }
  local seenViewerCooldownIDs = {}
  for viewerKey, orderMap in pairs(viewerOrders) do
    for cooldownID in pairs(orderMap) do
      if seenViewerCooldownIDs[cooldownID] then
        return nil
      end
      seenViewerCooldownIDs[cooldownID] = viewerKey
    end
  end

  for cooldownID in pairs(essentialOrder) do
    if utilityOrder[cooldownID] ~= nil then
      return nil
    end
  end

  local entries = {}
  local seenAllCooldownIDs = {}
  local seenEssentialCount = 0
  local seenUtilityCount = 0
  local seenBuffIconCount = 0
  local seenBuffBarCount = 0

  for globalOrder = 1, #allIDTable do
    local cooldownID, cooldownIDValid = ReadRequiredPositiveNumber(allIDTable[globalOrder])
    if not cooldownIDValid or seenAllCooldownIDs[cooldownID] then
      return nil
    end
    seenAllCooldownIDs[cooldownID] = true

    local essentialViewerOrder = essentialOrder[cooldownID]
    local utilityViewerOrder = utilityOrder[cooldownID]
    local buffIconViewerOrder = buffIconOrder[cooldownID]
    local buffBarViewerOrder = buffBarOrder[cooldownID]
    local viewerKey
    local viewerOrder

    if essentialViewerOrder then
      viewerKey = ESSENTIAL_VIEWER_KEY
      viewerOrder = essentialViewerOrder
      seenEssentialCount = seenEssentialCount + 1
    elseif utilityViewerOrder then
      viewerKey = UTILITY_VIEWER_KEY
      viewerOrder = utilityViewerOrder
      seenUtilityCount = seenUtilityCount + 1
    elseif buffIconViewerOrder then
      viewerKey = BUFF_ICON_VIEWER_KEY
      viewerOrder = buffIconViewerOrder
      seenBuffIconCount = seenBuffIconCount + 1
    elseif buffBarViewerOrder then
      viewerKey = BUFF_BAR_VIEWER_KEY
      viewerOrder = buffBarViewerOrder
      seenBuffBarCount = seenBuffBarCount + 1
    end

    local sourceInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
    local sourceTable, sourceValid = ReadTable(sourceInfo)
    if not sourceValid then
      return nil
    end

    local sourceCategory, sourceCategoryValid = ReadRequiredNumber(sourceTable.category)
    if not sourceCategoryValid then
      return nil
    end

    if viewerKey or ACTIVE_SOURCE_CATEGORIES[sourceCategory] == true then
      local defaultCategory, resolvedCategory, categoriesValid = ReadProviderCategory(provider, cooldownID)
      if not categoriesValid then
        return nil
      end

      local entry = BuildEntry(
        cooldownID,
        globalOrder,
        sourceTable,
        defaultCategory,
        resolvedCategory,
        viewerKey,
        viewerOrder
      )
      if not entry then
        return nil
      end

      entries[#entries + 1] = entry
    end
  end

  if seenEssentialCount ~= #essentialIDs
    or seenUtilityCount ~= #utilityIDs
    or seenBuffIconCount ~= #buffIconIDs
    or seenBuffBarCount ~= #buffBarIDs
  then
    return nil
  end

  local viewerEntries = {
    [ESSENTIAL_VIEWER_KEY] = {},
    [UTILITY_VIEWER_KEY] = {},
    [BUFF_ICON_VIEWER_KEY] = {},
    [BUFF_BAR_VIEWER_KEY] = {},
  }
  for index = 1, #entries do
    local entry = entries[index]
    if entry.viewerKey then
      local list = viewerEntries[entry.viewerKey]
      if not list or entry.viewerOrder ~= (#list + 1) then
        return nil
      end
      list[#list + 1] = entry
    end
  end

  if #viewerEntries[ESSENTIAL_VIEWER_KEY] ~= #essentialIDs
    or #viewerEntries[UTILITY_VIEWER_KEY] ~= #utilityIDs
    or #viewerEntries[BUFF_ICON_VIEWER_KEY] ~= #buffIconIDs
    or #viewerEntries[BUFF_BAR_VIEWER_KEY] ~= #buffBarIDs
  then
    return nil
  end

  AddCustomBuffEntries(entries, viewerEntries)
  AssignSettingsKeys(entries)

  return {
    entries = entries,
    viewerEntries = viewerEntries,
  }
end

local function ArrayEquals(left, right)
  if #left ~= #right then
    return false
  end

  for index = 1, #left do
    if left[index] ~= right[index] then
      return false
    end
  end
  return true
end

function Catalog:EntriesMatch(left, right, ignorePlacement)
  for index = 1, #ENTRY_SCALAR_FIELDS do
    local field = ENTRY_SCALAR_FIELDS[index]
    local placement = field == "globalOrder" or field == "viewerOrder" or field == "viewerKey"
      or field == "resolvedCategory"
    if not (ignorePlacement and placement) and left[field] ~= right[field] then
      return false
    end
  end

  return ArrayEquals(left.linkedSpellIDs, right.linkedSpellIDs)
    and ArrayEquals(left.identitySpellIDs, right.identitySpellIDs)
end

local function GenerationEquals(candidate)
  local currentEntries = state.entries
  local candidateEntries = candidate.entries
  if #currentEntries ~= #candidateEntries then
    return false
  end

  for index = 1, #currentEntries do
    if not Catalog:EntriesMatch(currentEntries[index], candidateEntries[index]) then
      return false
    end
  end
  return true
end

function Catalog:GetGeneration()
  return state.generation
end

function Catalog:GetViewerEntries(viewerKey)
  if IsSecretValue(viewerKey) or type(viewerKey) ~= "string" then
    return EMPTY, state.generation
  end
  return state.viewerEntries[viewerKey] or EMPTY, state.generation
end

function Catalog:RegisterListener(owner, callback)
  if owner == nil or type(callback) ~= "function" then
    return
  end
  listeners[owner] = callback
end

function Catalog:UnregisterListener(owner)
  listeners[owner] = nil
end

function Catalog:Invalidate(reason)
  state.dirty = true
  state.invalidationSerial = state.invalidationSerial + 1
  if enabled then
    refreshUpdater:MarkDirty()
  end
end

function Catalog:Refresh()
  if not state.dirty then
    return false, state.generation
  end

  local invalidationSerial = state.invalidationSerial
  local candidate = BuildGeneration()
  if not candidate or invalidationSerial ~= state.invalidationSerial then
    return false, state.generation
  end

  local changed = state.generation == 0 or not GenerationEquals(candidate)
  if changed then
    state.generation = state.generation + 1
    state.entries = candidate.entries
    state.viewerEntries = candidate.viewerEntries
    for owner, callback in pairs(listeners) do
      callback(owner, state.generation)
    end
  end

  state.dirty = false
  return changed, state.generation
end

refreshUpdater:SetDirtyMethod(function()
  if enabled then
    Catalog:Refresh()
  end
end)

local function InvalidateFromStructuralEvent()
  Catalog:Invalidate("structural")
end

local function InvalidateFromSettingsChange()
  Catalog:Invalidate("provider")
end

eventFrame:SetScript("OnEvent", InvalidateFromStructuralEvent)

function Catalog:Enable(owner)
  enableOwners[owner or self] = true
  if enabled then return end
  enabled = true
  for index = 1, #STRUCTURAL_EVENTS do
    eventFrame:RegisterEvent(STRUCTURAL_EVENTS[index])
  end
  EventRegistry:RegisterCallback(
    "CooldownViewerSettings.OnDataChanged",
    InvalidateFromSettingsChange,
    Catalog
  )
  self:Invalidate("initial")
end

function Catalog:Disable(owner)
  enableOwners[owner or self] = nil
  for _ in pairs(enableOwners) do return end
  if not enabled then return end
  enabled = false
  eventFrame:UnregisterAllEvents()
  EventRegistry:UnregisterCallback("CooldownViewerSettings.OnDataChanged", Catalog)
end

local P = select(1, ns.Pleebug:DropIn(Catalog, { name = "PCM", bucket = "AbilityCatalog" }))
Catalog.EntriesMatch = P:Def("Catalog:EntriesMatch", Catalog.EntriesMatch)
Catalog.GetGeneration = P:Def("Catalog:GetGeneration", Catalog.GetGeneration)
Catalog.GetViewerEntries = P:Def("Catalog:GetViewerEntries", Catalog.GetViewerEntries)
Catalog.RegisterListener = P:Def("Catalog:RegisterListener", Catalog.RegisterListener)
Catalog.UnregisterListener = P:Def("Catalog:UnregisterListener", Catalog.UnregisterListener)
Catalog.Invalidate = P:Def("Catalog:Invalidate", Catalog.Invalidate)
Catalog.Refresh = P:Def("Catalog:Refresh", Catalog.Refresh)
Catalog.Enable = P:Def("Catalog:Enable", Catalog.Enable)
Catalog.Disable = P:Def("Catalog:Disable", Catalog.Disable)
