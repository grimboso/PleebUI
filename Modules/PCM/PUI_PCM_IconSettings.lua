local ADDON_NAME, ns = ...

local Addon = ns.Addon

local IconSettings = {}
ns.PCMIconSettings = IconSettings

local P = select(1, ns.Pleebug:DropIn(IconSettings, { name = "PCM", bucket = "IconSettings" }))
local InCombatLockdown = InCombatLockdown
local wipe = wipe

local FONT_FIELDS = {
  "font",
  "size",
  "flags",
  "color",
  "point",
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

local CATALOG_VIEWERS = {
  "EssentialCooldownViewer",
  "UtilityCooldownViewer",
  "BuffIconCooldownViewer",
  "BuffBarCooldownViewer",
}

local state = {
  catalogGeneration = 1,
  settingsGeneration = 1,
  catalogSpecID = nil,
  catalogs = {},
  selected = {},
  previewState = {},
}

local ownedStyleCache = setmetatable({}, { __mode = "k" })

local function GetSettingsFamily(viewerKey)
  return VIEWER_FAMILIES[viewerKey]
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

local function ResetCatalogForSpecialization()
  local specID = GetCurrentSpecializationID()
  if state.catalogSpecID == specID then
    return
  end

  state.catalogSpecID = specID
  state.catalogGeneration = state.catalogGeneration + 1
  state.settingsGeneration = state.settingsGeneration + 1
  wipe(state.catalogs)
  wipe(state.selected)
  wipe(state.previewState)
end

function IconSettings:InvalidateCatalog()
  if InCombatLockdown() then
    state.catalogInvalidationPending = true
    return
  end

  state.catalogInvalidationPending = nil
  local specID = GetCurrentSpecializationID()
  if state.catalogSpecID ~= specID then
    state.settingsGeneration = state.settingsGeneration + 1
    wipe(state.selected)
  end
  state.catalogGeneration = state.catalogGeneration + 1
  state.catalogSpecID = specID
  wipe(state.catalogs)
end

function IconSettings:InvalidateSettings()
  state.settingsGeneration = state.settingsGeneration + 1
  for viewerKey, catalog in pairs(state.catalogs) do
    local store = GetSpecializationStore(GetSettingsFamily(viewerKey), false)
    for index = 1, #catalog.entries do
      local entry = catalog.entries[index]
      entry.settingsRecord = store and store[entry.settingsKey] or nil
    end
  end
end

function IconSettings:GetViewerEntries(viewerKey)
  ResetCatalogForSpecialization()

  local cached = state.catalogs[viewerKey]
  local catalogEntries, catalogGeneration = ns.PCMCatalog:GetViewerEntries(viewerKey)
  if cached
    and cached.generation == state.catalogGeneration
    and cached.sourceGeneration == catalogGeneration
  then
    return cached.entries
  end

  local entries = catalogEntries
  local settingsFamily = GetSettingsFamily(viewerKey)
  if not settingsFamily then
    return entries
  end

  local store = GetSpecializationStore(settingsFamily, false)
  for index = 1, #entries do
    local entry = entries[index]
    entry.settingsRecord = store and store[entry.settingsKey] or nil
  end

  state.catalogs[viewerKey] = {
    generation = state.catalogGeneration,
    sourceGeneration = catalogGeneration,
    entries = entries,
  }
  return entries
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

local function ResolveOwnedFont(record, role, viewerOptions, destination)
  local override = record and record[role]
  if not override then
    return viewerOptions
  end

  destination = destination or { role = role }
  destination.role = role
  destination.scope = viewerOptions and viewerOptions.scope
  for index = 1, #FONT_FIELDS do
    local field = FONT_FIELDS[index]
    local value = override[field]
    if value == nil and viewerOptions then
      value = viewerOptions[field]
    end
    destination[field] = value
  end
  return destination
end

local function ResolveOverride(value, inherited)
  if value == nil then
    return inherited
  end
  return value
end

function IconSettings:ResolveSwipeSettings(override, viewer, isBuff, destination)
  override = override or {}
  viewer = viewer or {}
  local swipe = destination or {}
  swipe.showCooldown = ResolveOverride(override.show, viewer.cooldown ~= false)
  swipe.showGCD = ResolveOverride(override.showGCD, viewer.gcd ~= false)
  swipe.showDuration = ResolveOverride(
    override[isBuff and "show" or "showDuration"],
    viewer.duration ~= false
  )
  local edge = ResolveOverride(override.drawEdge, viewer.drawEdge ~= false)
  swipe.cooldownEdge = ResolveOverride(override.drawEdge, ResolveOverride(viewer.cooldownEdge, edge))
  swipe.durationEdge = ResolveOverride(override.drawEdge, ResolveOverride(viewer.durationEdge, edge))
  swipe.gcdEdge = ResolveOverride(override.drawEdge, ResolveOverride(viewer.gcdEdge, edge))
  swipe.rechargeEdge = ResolveOverride(override.rechargeEdge, swipe.cooldownEdge)
  local color = override.color or viewer.swipeColor or { 0, 0, 0, 0.8 }
  swipe.cooldownColor = override.color or viewer.cooldownColor or color
  swipe.durationColor = override.color or viewer.durationColor or color
  swipe.gcdColor = override.color or viewer.gcdColor or color
  swipe.reverse = override.reverse == true
  swipe.durationReverse = ResolveOverride(override.reverse, true)
  swipe.source = override.source
  if swipe.source == nil then
    swipe.source = viewer.forceCooldownSwipe == true and "COOLDOWN" or "AUTOMATIC"
  end
  swipe.desaturateCooldown = viewer.desaturateCooldown ~= false
  return swipe
end

function IconSettings:ResolveOwnedStyle(entry, viewerKey, viewerStyle)
  local record = self:GetRecordForEntry(entry, false)
  local cached = ownedStyleCache[entry]
  if cached
    and cached.generation == state.settingsGeneration
    and cached.record == record
    and cached.viewerStyle == viewerStyle
  then
    return cached.style
  end

  cached = cached or {}
  local style = cached.style or {}
  style.size = viewerStyle.iconSize
  style.manageFrameSize = false
  style.inset = 0
  style.backgroundColor = viewerStyle.backgroundColor
  style.borderColor = viewerStyle.borderColor
  style.borderSize = viewerStyle.borderThickness
  style.cooldownFont = ResolveOwnedFont(
    record,
    "cooldown",
    viewerStyle.cooldownFont,
    style.cooldownFont
  )
  style.chargeFont = ResolveOwnedFont(
    record,
    "charge",
    viewerStyle.chargeFont,
    style.chargeFont
  )
  style.keybindFont = ResolveOwnedFont(
    record,
    "keybind",
    viewerStyle.keybindFont,
    style.keybindFont
  )
  style.appearance = record and record.appearance or nil
  style.cooldown = record and record.cooldown or nil
  style.charge = record and record.charge or nil
  style.viewerCounts = viewerStyle.counts
  local isBuff = viewerKey == "BuffIconCooldownViewer"
  style.resolvedSwipe = self:ResolveSwipeSettings(record and record.swipe, viewerStyle.swipe, isBuff, style.resolvedSwipe)
  style.showDurationText = ResolveOverride(
    style.cooldown and style.cooldown[isBuff and "show" or "durationShow"],
    viewerStyle.durationCount ~= false
  )
  style.useDurationDisplay = style.resolvedSwipe.source ~= "COOLDOWN"
  style.tooltips = viewerStyle.tooltips
  style.hideWhenInactive = viewerStyle.hideWhenInactive == true
  style.procGlow = viewerStyle.procGlow
  style.hasCharges = entry.charges == true
  style.visible = true

  cached.generation = state.settingsGeneration
  cached.record = record
  cached.viewerStyle = viewerStyle
  cached.style = style
  ownedStyleCache[entry] = cached
  return style
end

function IconSettings:PrimeRuntimeCache()
  if InCombatLockdown() then
    return false
  end

  if state.catalogInvalidationPending then
    self:InvalidateCatalog()
    return true
  end

  for index = 1, #CATALOG_VIEWERS do
    self:GetViewerEntries(CATALOG_VIEWERS[index])
  end
  return false
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
IconSettings.InvalidateCatalog = P:Def("IconSettings:InvalidateCatalog", IconSettings.InvalidateCatalog)
IconSettings.InvalidateSettings = P:Def("IconSettings:InvalidateSettings", IconSettings.InvalidateSettings)
IconSettings.GetViewerEntries = P:Def("IconSettings:GetViewerEntries", IconSettings.GetViewerEntries)
IconSettings.GetRecordForEntry = P:Def("IconSettings:GetRecordForEntry", IconSettings.GetRecordForEntry)
IconSettings.ResolveSwipeSettings = P:Def("IconSettings:ResolveSwipeSettings", IconSettings.ResolveSwipeSettings)
IconSettings.ResolveOwnedStyle = P:Def("IconSettings:ResolveOwnedStyle", IconSettings.ResolveOwnedStyle)
IconSettings.PrimeRuntimeCache = P:Def("IconSettings:PrimeRuntimeCache", IconSettings.PrimeRuntimeCache)
IconSettings.HasShownTextOverride = P:Def("IconSettings:HasShownTextOverride", IconSettings.HasShownTextOverride)
IconSettings.SetPreviewState = P:Def("IconSettings:SetPreviewState", IconSettings.SetPreviewState)
IconSettings.GetPreviewState = P:Def("IconSettings:GetPreviewState", IconSettings.GetPreviewState)
IconSettings.Select = P:Def("IconSettings:Select", IconSettings.Select)
IconSettings.GetSelectedEntry = P:Def("IconSettings:GetSelectedEntry", IconSettings.GetSelectedEntry)
IconSettings.GetOptionKey = P:Def("IconSettings:GetOptionKey", IconSettings.GetOptionKey)
IconSettings.SetField = P:Def("IconSettings:SetField", IconSettings.SetField)
IconSettings.GetField = P:Def("IconSettings:GetField", IconSettings.GetField)
IconSettings.ResetEntry = P:Def("IconSettings:ResetEntry", IconSettings.ResetEntry)
