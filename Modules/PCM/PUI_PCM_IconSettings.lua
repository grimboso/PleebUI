local ADDON_NAME, ns = ...

local Addon = ns.Addon
local Hooks = ns.PCMHooks

local IconSettings = {}
ns.PCMIconSettings = IconSettings

local P = select(1, ns.Pleebug:DropIn(IconSettings, { name = "PCM", bucket = "IconSettings" }))
local IsSecret = issecretvalue
local InCombatLockdown = InCombatLockdown
local wipe = wipe
local sort = table.sort

local FONT_FIELDS = {
  "font",
  "size",
  "flags",
  "color",
  "offsetX",
  "offsetY",
}

local SETTINGS_FAMILY_COOLDOWN = "cooldown"
local SETTINGS_FAMILY_BUFF = "buff"

local VIEWER_FAMILIES = {
  EssentialCooldownViewer = SETTINGS_FAMILY_COOLDOWN,
  UtilityCooldownViewer = SETTINGS_FAMILY_COOLDOWN,
  BuffIconCooldownViewer = SETTINGS_FAMILY_BUFF,
  BuffBarCooldownViewer = "bar",
}

local function CreateIdentityState()
  return {
    byCooldownID = {},
    byCooldownInfo = setmetatable({}, { __mode = "k" }),
    byCanonicalSpellID = {},
    bySpellID = {},
  }
end

local state = {
  catalogGeneration = 1,
  settingsGeneration = 1,
  catalogSpecID = nil,
  catalogs = {},
  identities = {
    [SETTINGS_FAMILY_COOLDOWN] = CreateIdentityState(),
    [SETTINGS_FAMILY_BUFF] = CreateIdentityState(),
    bar = CreateIdentityState(),
  },
  selected = {},
  previewState = {},
}

local function GetSettingsFamily(viewerKey)
  return VIEWER_FAMILIES[viewerKey]
end

local function GetIdentityState(settingsFamily)
  return settingsFamily and state.identities[settingsFamily] or nil
end

local function ClearIdentityState(identity)
  wipe(identity.byCooldownID)
  wipe(identity.byCooldownInfo)
  wipe(identity.byCanonicalSpellID)
  wipe(identity.bySpellID)
end

local function ReadPositiveNumber(value)
  if IsSecret(value) or type(value) ~= "number" or value <= 0 then
    return nil
  end
  return value
end

local function GetCurrentSpecializationID()
  local specializationIndex = GetSpecialization()
  if not specializationIndex then
    return nil
  end
  return GetSpecializationInfo(specializationIndex)
end

local function GetProfileRoot(create)
  local db = Addon.db
  local profile = db and db.profile
  if not profile then
    return nil
  end

  local root = profile.cooldownManager
  if not root and create then
    root = {}
    profile.cooldownManager = root
  end
  return root
end

local function GetSpecializationStore(settingsFamily, create)
  if settingsFamily ~= SETTINGS_FAMILY_COOLDOWN and settingsFamily ~= SETTINGS_FAMILY_BUFF then
    return nil
  end

  local root = GetProfileRoot(create)
  local specID = GetCurrentSpecializationID()
  if not root or not specID then
    return nil
  end

  local stores = root.iconSettings
  if not stores and create then
    stores = {}
    root.iconSettings = stores
  end

  local store = stores and stores[specID]
  if store and store[SETTINGS_FAMILY_COOLDOWN] == nil and store[SETTINGS_FAMILY_BUFF] == nil then
    store = {
      [SETTINGS_FAMILY_COOLDOWN] = store,
      [SETTINGS_FAMILY_BUFF] = {},
    }
    stores[specID] = store
  elseif not store and create then
    store = {
      [SETTINGS_FAMILY_COOLDOWN] = {},
      [SETTINGS_FAMILY_BUFF] = {},
    }
    stores[specID] = store
  end

  if not store then
    return nil
  end

  local familyStore = store[settingsFamily]
  if not familyStore and create then
    familyStore = {}
    store[settingsFamily] = familyStore
  end
  return familyStore
end

local function GetCooldownID(itemFrame)
  local cooldownID
  if type(itemFrame.GetCooldownID) == "function" then
    cooldownID = itemFrame:GetCooldownID()
  end
  if cooldownID == nil then
    cooldownID = itemFrame.cooldownID
  end
  return ReadPositiveNumber(cooldownID)
end

local function CopyLinkedSpellIDs(source)
  local linked = {}
  if IsSecret(source) or type(source) ~= "table" then
    return linked
  end

  for index = 1, #source do
    local spellID = ReadPositiveNumber(source[index])
    if spellID then
      linked[#linked + 1] = spellID
    end
  end
  return linked
end

local function AddIdentityID(entry, seen, spellID)
  spellID = ReadPositiveNumber(spellID)
  if not spellID or seen[spellID] then
    return
  end

  seen[spellID] = true
  entry.identitySpellIDs[#entry.identitySpellIDs + 1] = spellID

  local baseSpellID = C_Spell.GetBaseSpell(spellID)
  baseSpellID = ReadPositiveNumber(baseSpellID)
  if baseSpellID and not seen[baseSpellID] then
    seen[baseSpellID] = true
    entry.identitySpellIDs[#entry.identitySpellIDs + 1] = baseSpellID
  end
end

local function BuildEntry(cooldownID, info, settingsFamily)
  local baseSpellID = ReadPositiveNumber(info.spellID)
  local overrideSpellID = ReadPositiveNumber(info.overrideSpellID)
  local overrideTooltipSpellID = ReadPositiveNumber(info.overrideTooltipSpellID)
  local displaySpellID = overrideSpellID or baseSpellID
  local familySpellID = overrideTooltipSpellID or overrideSpellID or baseSpellID
  local chargeSpellID = overrideSpellID or baseSpellID

  if not displaySpellID or not familySpellID then
    return nil
  end

  local canonicalSpellID = ReadPositiveNumber(C_Spell.GetBaseSpell(familySpellID)) or familySpellID
  local texture = C_Spell.GetSpellTexture(displaySpellID)
  if IsSecret(texture) or (type(texture) ~= "number" and type(texture) ~= "string") then
    return nil
  end

  local name = C_Spell.GetSpellName(displaySpellID)
  if IsSecret(name) or type(name) ~= "string" or name == "" then
    name = tostring(displaySpellID)
  end

  local chargeInfo = C_Spell.GetSpellCharges(chargeSpellID)
  local maxCharges = not IsSecret(chargeInfo) and chargeInfo and chargeInfo.maxCharges or nil
  local hasCharges = not IsSecret(maxCharges)
    and type(maxCharges) == "number"
    and maxCharges > 1

  local entry = {
    cooldownID = cooldownID,
    settingsFamily = settingsFamily,
    cooldownInfo = info,
    spellID = displaySpellID,
    baseSpellID = baseSpellID,
    overrideSpellID = overrideSpellID,
    overrideTooltipSpellID = overrideTooltipSpellID,
    canonicalSpellID = canonicalSpellID,
    cooldownSpellID = baseSpellID or canonicalSpellID,
    chargeSpellID = chargeSpellID,
    settingsKey = tostring(canonicalSpellID),
    texture = texture,
    name = name,
    hasCharges = hasCharges,
    identitySpellIDs = {},
  }

  local seen = {}
  AddIdentityID(entry, seen, baseSpellID)
  AddIdentityID(entry, seen, overrideSpellID)
  AddIdentityID(entry, seen, overrideTooltipSpellID)

  local linkedSpellIDs = CopyLinkedSpellIDs(info.linkedSpellIDs)
  for index = 1, #linkedSpellIDs do
    AddIdentityID(entry, seen, linkedSpellIDs[index])
  end

  return entry
end

local function GetCanonicalSpellIDFromInfo(info)
  if IsSecret(info) or type(info) ~= "table" then
    return nil
  end

  local familySpellID = ReadPositiveNumber(info.overrideTooltipSpellID)
    or ReadPositiveNumber(info.overrideSpellID)
    or ReadPositiveNumber(info.spellID)
  if not familySpellID then
    return nil
  end

  return ReadPositiveNumber(C_Spell.GetBaseSpell(familySpellID)) or familySpellID
end

local function GetEntryForSpellID(settingsFamily, spellID)
  local identity = GetIdentityState(settingsFamily)
  spellID = ReadPositiveNumber(spellID)
  if not identity or not spellID then
    return nil
  end

  local entry = identity.bySpellID[spellID]
  if entry == false then
    return nil
  end
  if entry then
    return entry
  end

  local baseSpellID = ReadPositiveNumber(C_Spell.GetBaseSpell(spellID))
  entry = baseSpellID and identity.bySpellID[baseSpellID] or nil
  return entry ~= false and entry or nil
end

local function GetEntryFromInfoAliases(settingsFamily, info)
  if IsSecret(info) or type(info) ~= "table" then
    return nil
  end

  local entry = GetEntryForSpellID(settingsFamily, info.overrideTooltipSpellID)
    or GetEntryForSpellID(settingsFamily, info.overrideSpellID)
    or GetEntryForSpellID(settingsFamily, info.spellID)
    or GetEntryForSpellID(settingsFamily, info.linkedSpellID)
  if entry then
    return entry
  end

  local linkedSpellIDs = info.linkedSpellIDs
  if IsSecret(linkedSpellIDs) or type(linkedSpellIDs) ~= "table" then
    return nil
  end

  for index = 1, #linkedSpellIDs do
    entry = GetEntryForSpellID(settingsFamily, linkedSpellIDs[index])
    if entry then
      return entry
    end
  end
  return nil
end

local function ClearCatalogIdentity()
  for _, identity in pairs(state.identities) do
    ClearIdentityState(identity)
  end
end

local function ResetCatalogForSpecialization()
  local specID = GetCurrentSpecializationID()
  if state.catalogSpecID == specID then
    return
  end

  state.catalogSpecID = specID
  state.catalogGeneration = state.catalogGeneration + 1
  state.settingsGeneration = state.settingsGeneration + 1
  wipe(state.catalogs)
  ClearCatalogIdentity()
  wipe(state.selected)
  wipe(state.previewState)
end

function IconSettings:InvalidateCatalog()
  local specID = GetCurrentSpecializationID()
  if state.catalogSpecID ~= specID then
    state.settingsGeneration = state.settingsGeneration + 1
    wipe(state.selected)
  end
  state.catalogGeneration = state.catalogGeneration + 1
  state.catalogSpecID = specID
  wipe(state.catalogs)
  ClearCatalogIdentity()
end

function IconSettings:InvalidateSettings()
  state.settingsGeneration = state.settingsGeneration + 1
end

function IconSettings:GetViewerEntries(viewerKey)
  ResetCatalogForSpecialization()

  local cached = state.catalogs[viewerKey]
  if cached and cached.generation == state.catalogGeneration then
    return cached.entries
  end

  local entries = {}
  local settingsFamily = GetSettingsFamily(viewerKey)
  local identity = GetIdentityState(settingsFamily)
  if not settingsFamily or not identity or InCombatLockdown() then
    return entries
  end

  local viewer = _G[viewerKey]
  local settings = _G.CooldownViewerSettings
  local provider = settings and settings:GetDataProvider() or nil
  if not viewer or not provider then
    return entries
  end

  local category = viewer:GetCategory()
  if category == nil or IsSecret(category) then
    return entries
  end

  local familyCategories = {}
  for familyViewerKey, family in pairs(VIEWER_FAMILIES) do
    if family == settingsFamily then
      local familyViewer = _G[familyViewerKey]
      local familyCategory = familyViewer and familyViewer:GetCategory() or nil
      if familyCategory ~= nil and not IsSecret(familyCategory) then
        familyCategories[familyCategory] = true
      end
    end
  end

  local cooldownIDs = provider:GetOrderedCooldownIDs()
  if IsSecret(cooldownIDs) or type(cooldownIDs) ~= "table" then
    return entries
  end

  local familyCounts = {}
  for index = 1, #cooldownIDs do
    local cooldownID = ReadPositiveNumber(cooldownIDs[index])
    if cooldownID then
      local info = provider:GetCooldownInfoForID(cooldownID)
      if not IsSecret(info) and type(info) == "table" then
        local infoCategory = info.category
        local isKnown = info.isKnown
        if not IsSecret(infoCategory)
          and familyCategories[infoCategory] == true
          and not IsSecret(isKnown)
          and isKnown == true
        then
          local entry = BuildEntry(cooldownID, info, settingsFamily)
          if entry then
            familyCounts[entry.settingsKey] = (familyCounts[entry.settingsKey] or 0) + 1
            if infoCategory == category then
              entries[#entries + 1] = entry
            end
          end
        end
      end
    end
  end

  for index = 1, #entries do
    local entry = entries[index]
    if familyCounts[entry.settingsKey] > 1 then
      entry.settingsKey = "c" .. tostring(entry.cooldownID)
    end
    identity.byCooldownID[entry.cooldownID] = entry
    identity.byCooldownInfo[entry.cooldownInfo] = entry
    local canonicalEntry = identity.byCanonicalSpellID[entry.canonicalSpellID]
    if canonicalEntry and canonicalEntry ~= entry then
      identity.byCanonicalSpellID[entry.canonicalSpellID] = false
    elseif canonicalEntry == nil then
      identity.byCanonicalSpellID[entry.canonicalSpellID] = entry
    end

    for spellIndex = 1, #entry.identitySpellIDs do
      local spellID = entry.identitySpellIDs[spellIndex]
      local spellEntry = identity.bySpellID[spellID]
      if spellEntry and spellEntry ~= entry then
        identity.bySpellID[spellID] = false
      elseif spellEntry == nil then
        identity.bySpellID[spellID] = entry
      end
    end
  end

  state.catalogs[viewerKey] = {
    generation = state.catalogGeneration,
    entries = entries,
  }
  return entries
end

function IconSettings:ClearItemBinding(itemFrame)
  local frameData = Hooks.GetFrameData(itemFrame)
  frameData.iconIdentity = nil
  frameData.iconIdentityGeneration = nil
  frameData.iconIdentityViewerKey = nil
  frameData.iconSettingsRecord = nil
  frameData.iconSettingsGeneration = nil
  frameData.iconSettingsViewerKey = nil
  frameData.iconFontOptions = nil
  frameData.iconSwipeOptions = nil
  frameData.iconRuntimeFlagsGeneration = nil
  frameData.iconRuntimeFlagsViewerKey = nil
  frameData.iconRuntimeFlagsRecord = nil
  frameData.iconRuntimeFlagsEntry = nil
  frameData.iconRuntimeFlagsViewerOptions = nil
  frameData.iconCooldownState = "UNKNOWN"
  frameData.iconIsOnGCD = nil
  frameData.iconSettingsNeedsCooldownState = nil
  frameData.iconSettingsNeedsChargeState = nil
  frameData.iconSettingsNeedsTextureRefresh = nil
  frameData.iconSettingsNeedsSwipeRefresh = nil
  frameData.iconSettingsNeedsCountModeRefresh = nil
  frameData.iconSettingsNeedsChargeCountRefresh = nil
  frameData.iconSettingsNeedsCooldownRefreshHook = nil
  frameData.iconSettingsNeedsChargeRefreshHook = nil
  frameData.iconSettingsForcesCooldownSource = nil
  frameData.iconSettingsApplyingForcedCooldown = nil
  if frameData.iconCustomTextureApplied ~= nil then
    frameData.iconCustomTextureNeedsReconcile = true
  end
end

function IconSettings:ClearItemIdentity(itemFrame)
  local frameData = Hooks.GetFrameData(itemFrame)
  self:ClearItemBinding(itemFrame)
  frameData.iconStateHidden = nil
  frameData.iconAppliedAlpha = nil
  frameData.iconAppliedSaturation = nil
  frameData.iconSettingsGlowStyle = nil
  frameData.iconSettingsGlowState = nil
  frameData.iconSettingsGlowGeneration = nil
  frameData.iconCustomTextureApplied = nil
  frameData.iconCustomTextureNeedsReconcile = nil
end

function IconSettings:ResolveItem(itemFrame, viewerKey)
  local settingsFamily = GetSettingsFamily(viewerKey)
  local identity = GetIdentityState(settingsFamily)
  if not itemFrame
    or (settingsFamily ~= SETTINGS_FAMILY_COOLDOWN and settingsFamily ~= SETTINGS_FAMILY_BUFF)
    or not identity
  then
    return nil
  end

  ResetCatalogForSpecialization()

  local frameData = Hooks.GetFrameData(itemFrame)
  if frameData.iconIdentityGeneration == state.catalogGeneration
    and frameData.iconIdentityViewerKey == viewerKey
  then
    return frameData.iconIdentity
  end

  local cooldownInfo
  if type(itemFrame.GetCooldownInfo) == "function" then
    cooldownInfo = itemFrame:GetCooldownInfo()
  end
  if cooldownInfo == nil then
    cooldownInfo = itemFrame.cooldownInfo
  end

  local entry
  if not IsSecret(cooldownInfo) and type(cooldownInfo) == "table" then
    entry = identity.byCooldownInfo[cooldownInfo]
    if not entry then
      local canonicalSpellID = GetCanonicalSpellIDFromInfo(cooldownInfo)
      entry = canonicalSpellID and identity.byCanonicalSpellID[canonicalSpellID] or nil
      if entry == false then
        entry = nil
      end
      entry = entry or GetEntryFromInfoAliases(settingsFamily, cooldownInfo)
    end
  end

  local cooldownID
  if not entry then
    cooldownID = GetCooldownID(itemFrame)
    entry = cooldownID and identity.byCooldownID[cooldownID] or nil
  end

  if not entry and not InCombatLockdown() then
    self:GetViewerEntries(viewerKey)
    if not IsSecret(cooldownInfo) and type(cooldownInfo) == "table" then
      entry = identity.byCooldownInfo[cooldownInfo]
      if not entry then
        local canonicalSpellID = GetCanonicalSpellIDFromInfo(cooldownInfo)
        entry = canonicalSpellID and identity.byCanonicalSpellID[canonicalSpellID] or nil
        if entry == false then
          entry = nil
        end
        entry = entry or GetEntryFromInfoAliases(settingsFamily, cooldownInfo)
      end
    end
    if not entry and cooldownID then
      entry = identity.byCooldownID[cooldownID]
    end
  end

  if entry then
    frameData.iconIdentity = entry
    frameData.iconIdentityGeneration = state.catalogGeneration
    frameData.iconIdentityViewerKey = viewerKey
  end
  return entry
end


function IconSettings:GetRecordForEntry(entry, create)
  if not entry then
    return nil
  end

  local store = GetSpecializationStore(entry.settingsFamily, create)
  if not store then
    return nil
  end

  local record = store[entry.settingsKey]
  if not record and create then
    record = {}
    store[entry.settingsKey] = record
  end
  return record
end

function IconSettings:BindItem(itemFrame, viewerKey)
  if not itemFrame or not viewerKey then
    return nil, nil
  end

  local frameData = Hooks.GetFrameData(itemFrame)
  local entry = self:ResolveItem(itemFrame, viewerKey)
  local record = self:GetRecordForEntry(entry, false)
  frameData.iconSettingsRecord = record
  frameData.iconSettingsGeneration = state.settingsGeneration
  frameData.iconSettingsViewerKey = viewerKey
  return record, entry, frameData
end

function IconSettings:GetRecordForItem(itemFrame, viewerKey)
  local frameData = Hooks.GetFrameData(itemFrame)
  if frameData.iconSettingsGeneration == state.settingsGeneration
    and frameData.iconSettingsViewerKey == viewerKey
    and frameData.iconIdentityGeneration == state.catalogGeneration
    and frameData.iconIdentityViewerKey == viewerKey
  then
    return frameData.iconSettingsRecord, frameData.iconIdentity, frameData
  end
  return self:BindItem(itemFrame, viewerKey)
end


function IconSettings:HasShownTextOverride(role)
  local store = GetSpecializationStore(SETTINGS_FAMILY_COOLDOWN, false)
  if not store then
    return false
  end

  for _, record in pairs(store) do
    local text = type(record) == "table" and record[role]
    if text and text.show == true then
      return true
    end
  end
  return false
end

function IconSettings:ResolveFontOptions(itemFrame, viewerKey, role, viewerOptions)
  local record = self:GetRecordForItem(itemFrame, viewerKey)
  local text = record and record[role]
  if not text then
    return viewerOptions
  end

  local frameData = Hooks.GetFrameData(itemFrame)
  local cache = frameData.iconFontOptions
  if not cache or cache.generation ~= state.settingsGeneration then
    cache = { generation = state.settingsGeneration }
    frameData.iconFontOptions = cache
  end

  local cached = cache[role]
  if cached and cached.source == text and cached.viewerSource == viewerOptions then
    return cached.options
  end

  cached = cached or {}
  local options = cached.options or { role = role }
  for index = 1, #FONT_FIELDS do
    local field = FONT_FIELDS[index]
    local value = text[field]
    if value == nil and viewerOptions then
      value = viewerOptions[field]
    end
    options[field] = value
  end

  cached.source = text
  cached.viewerSource = viewerOptions
  cached.options = options
  cache[role] = cached
  return options
end

function IconSettings:ResolveSwipeOptions(itemFrame, viewerKey, viewerOptions)
  local record = self:GetRecordForItem(itemFrame, viewerKey)
  local swipe = record and record.swipe
  if not swipe then
    return viewerOptions
  end

  local frameData = Hooks.GetFrameData(itemFrame)
  local cached = frameData.iconSwipeOptions
  if cached
    and cached.generation == state.settingsGeneration
    and cached.source == swipe
    and cached.viewerSource == viewerOptions
  then
    return cached.options
  end

  cached = cached or {}
  local options = cached.options or {}
  options.show = swipe.show
  options.showGCD = swipe.showGCD
  options.source = swipe.source
  options.color = swipe.color
  options.drawEdge = swipe.drawEdge
  options.rechargeEdge = swipe.rechargeEdge
  options.reverse = swipe.reverse

  if viewerOptions then
    if options.source == nil then options.source = viewerOptions.source end
    if options.color == nil then options.color = viewerOptions.color end
    if options.drawEdge == nil then options.drawEdge = viewerOptions.drawEdge end
    if options.reverse == nil then options.reverse = viewerOptions.reverse end
  end

  cached.generation = state.settingsGeneration
  cached.source = swipe
  cached.viewerSource = viewerOptions
  cached.options = options
  frameData.iconSwipeOptions = cached
  return options
end

function IconSettings:GetAppearance(itemFrame, viewerKey)
  local record = self:GetRecordForItem(itemFrame, viewerKey)
  return record and record.appearance or nil
end

function IconSettings:GetSettingsGeneration()
  return state.settingsGeneration
end

function IconSettings:SetPreviewState(viewerKey, previewState, duration)
  if not viewerKey then
    return
  end

  local preview = state.previewState[viewerKey]
  if not preview then
    preview = {}
    state.previewState[viewerKey] = preview
  end

  if duration ~= nil then
    preview.transient = previewState
    preview.expiresAt = previewState and (GetTime() + (tonumber(duration) or 3)) or nil
  else
    preview.manual = previewState
  end

  if preview.manual == nil and preview.transient == nil then
    state.previewState[viewerKey] = nil
  end
end

function IconSettings:GetPreviewState(viewerKey)
  local preview = viewerKey and state.previewState[viewerKey] or nil
  if not preview then
    return nil
  end

  if preview.transient ~= nil then
    if preview.expiresAt and preview.expiresAt > GetTime() then
      return preview.transient
    end
    preview.transient = nil
    preview.expiresAt = nil
  end

  if preview.manual == nil and preview.transient == nil then
    state.previewState[viewerKey] = nil
    return nil
  end
  return preview.manual
end

function IconSettings:Select(viewerKey, settingsKey)
  if not viewerKey or not settingsKey then
    return
  end
  state.selected[viewerKey] = settingsKey
end

function IconSettings:GetSelectedEntry(viewerKey)
  local entries = self:GetViewerEntries(viewerKey)
  local selectedKey = state.selected[viewerKey]

  if not selectedKey and entries[1] then
    selectedKey = entries[1].settingsKey
    state.selected[viewerKey] = selectedKey
  end

  for index = 1, #entries do
    if entries[index].settingsKey == selectedKey then
      return entries[index]
    end
  end

  if entries[1] then
    state.selected[viewerKey] = entries[1].settingsKey
    return entries[1]
  end

  if #entries == 0 then
    local store = GetSpecializationStore(GetSettingsFamily(viewerKey), false)
    if store then
      if not selectedKey or not store[selectedKey] then
        for settingsKey in pairs(store) do
          selectedKey = settingsKey
          state.selected[viewerKey] = settingsKey
          break
        end
      end

      if selectedKey and store[selectedKey] then
        return {
          settingsFamily = GetSettingsFamily(viewerKey),
          settingsKey = selectedKey,
          texture = 134400,
          name = "Saved icon " .. selectedKey,
        }
      end
    end
  end
  return nil
end

function IconSettings:GetOptionKey(entry)
  if not entry or not entry.settingsKey then
    return nil
  end
  return "icon_" .. tostring(entry.settingsKey):gsub("[^%w_]", "_")
end

local function TableIsEmpty(value)
  return type(value) ~= "table" or next(value) == nil
end

local function PruneRecord(store, entry, record)
  if type(record) ~= "table" then
    return
  end

  for key, value in pairs(record) do
    if TableIsEmpty(value) then
      record[key] = nil
    end
  end

  if next(record) == nil then
    store[entry.settingsKey] = nil
  end
end

function IconSettings:SetField(entry, section, field, value)
  if not entry then
    return
  end

  local store = GetSpecializationStore(entry.settingsFamily, true)
  if not store then
    return
  end

  local record = store[entry.settingsKey]
  if not record then
    record = {}
    store[entry.settingsKey] = record
  end

  local sectionTable = record[section]
  if not sectionTable then
    sectionTable = {}
    record[section] = sectionTable
  end
  sectionTable[field] = value

  PruneRecord(store, entry, record)
  self:InvalidateSettings()
end

function IconSettings:GetField(entry, section, field)
  local record = self:GetRecordForEntry(entry, false)
  local sectionTable = record and record[section]
  if sectionTable then
    return sectionTable[field]
  end
  return nil
end

function IconSettings:ResetEntry(entry)
  if not entry then
    return
  end

  local store = GetSpecializationStore(entry.settingsFamily, false)
  if not store then
    return
  end
  store[entry.settingsKey] = nil
  self:InvalidateSettings()
end

IconSettings.GetCurrentSpecializationID = P:Def("GetCurrentSpecializationID", GetCurrentSpecializationID)
GetSettingsFamily = P:Def("GetSettingsFamily", GetSettingsFamily)
GetIdentityState = P:Def("GetIdentityState", GetIdentityState)
ClearIdentityState = P:Def("ClearIdentityState", ClearIdentityState)
GetCanonicalSpellIDFromInfo = P:Def("GetCanonicalSpellIDFromInfo", GetCanonicalSpellIDFromInfo)
GetEntryForSpellID = P:Def("GetEntryForSpellID", GetEntryForSpellID)
GetEntryFromInfoAliases = P:Def("GetEntryFromInfoAliases", GetEntryFromInfoAliases)
ClearCatalogIdentity = P:Def("ClearCatalogIdentity", ClearCatalogIdentity)
IconSettings.InvalidateCatalog = P:Def("IconSettings:InvalidateCatalog", IconSettings.InvalidateCatalog)
IconSettings.InvalidateSettings = P:Def("IconSettings:InvalidateSettings", IconSettings.InvalidateSettings)
IconSettings.GetViewerEntries = P:Def("IconSettings:GetViewerEntries", IconSettings.GetViewerEntries)
IconSettings.ClearItemBinding = P:Def("IconSettings:ClearItemBinding", IconSettings.ClearItemBinding)
IconSettings.ClearItemIdentity = P:Def("IconSettings:ClearItemIdentity", IconSettings.ClearItemIdentity)
IconSettings.ResolveItem = P:Def("IconSettings:ResolveItem", IconSettings.ResolveItem)
IconSettings.GetRecordForEntry = P:Def("IconSettings:GetRecordForEntry", IconSettings.GetRecordForEntry)
IconSettings.BindItem = P:Def("IconSettings:BindItem", IconSettings.BindItem)
IconSettings.GetRecordForItem = P:Def("IconSettings:GetRecordForItem", IconSettings.GetRecordForItem)
IconSettings.HasShownTextOverride = P:Def("IconSettings:HasShownTextOverride", IconSettings.HasShownTextOverride)
IconSettings.ResolveFontOptions = P:Def("IconSettings:ResolveFontOptions", IconSettings.ResolveFontOptions)
IconSettings.ResolveSwipeOptions = P:Def("IconSettings:ResolveSwipeOptions", IconSettings.ResolveSwipeOptions)
IconSettings.GetAppearance = P:Def("IconSettings:GetAppearance", IconSettings.GetAppearance)
IconSettings.GetSettingsGeneration = P:Def("IconSettings:GetSettingsGeneration", IconSettings.GetSettingsGeneration)
IconSettings.SetPreviewState = P:Def("IconSettings:SetPreviewState", IconSettings.SetPreviewState)
IconSettings.GetPreviewState = P:Def("IconSettings:GetPreviewState", IconSettings.GetPreviewState)
IconSettings.Select = P:Def("IconSettings:Select", IconSettings.Select)
IconSettings.GetSelectedEntry = P:Def("IconSettings:GetSelectedEntry", IconSettings.GetSelectedEntry)
IconSettings.GetOptionKey = P:Def("IconSettings:GetOptionKey", IconSettings.GetOptionKey)
IconSettings.SetField = P:Def("IconSettings:SetField", IconSettings.SetField)
IconSettings.GetField = P:Def("IconSettings:GetField", IconSettings.GetField)
IconSettings.ResetEntry = P:Def("IconSettings:ResetEntry", IconSettings.ResetEntry)
