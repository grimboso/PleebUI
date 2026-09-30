local _, ns = ...

local AuraRuntime = {}
ns.PCMAuraRuntime = AuraRuntime

local Catalog = ns.PCMCatalog
local AuraLayout = ns.PCMAuraLayout
local AuraSlotDriver = ns.AuraSlotDriver
local AuraWidget = ns.AuraWidget
local IconSettings = ns.PCMIconSettings
local PCMPresentation = ns.PCMPresentation

local C_Secrets = C_Secrets
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UIParent = UIParent
local ipairs = ipairs
local pairs = pairs
local type = type

local BUFF_ICON_VIEWER = "BuffIconCooldownViewer"
local BUFF_BAR_VIEWER = "BuffBarCooldownViewer"

local enabled = false
local presentationActive = false
local readyNotified = false
local groupLayoutEnabled = false
local groupLayoutReady = false
local hiddenResolver
local retiredRecords = {
  [BUFF_ICON_VIEWER] = {},
  [BUFF_BAR_VIEWER] = {},
}

local viewers = {
  [BUFF_ICON_VIEWER] = {
    key = BUFF_ICON_VIEWER,
    frame = nil,
    style = nil,
    records = {},
    orderedRecords = {},
    generation = 0,
  },
  [BUFF_BAR_VIEWER] = {
    key = BUFF_BAR_VIEWER,
    frame = nil,
    style = nil,
    records = {},
    orderedRecords = {},
    generation = 0,
  },
}

local restrictionFrame = CreateFrame("Frame")
local flushFrame = CreateFrame("Frame")
flushFrame:Hide()

local pendingCatalog = false
local pendingAppearance = false
local pendingVisibility = false
local pendingSlotConfiguration = false
local SetSlotActive

local AURA_RESTRICTION_TYPES = {
  [Enum.AddOnRestrictionType.Combat] = true,
  [Enum.AddOnRestrictionType.Encounter] = true,
  [Enum.AddOnRestrictionType.ChallengeMode] = true,
  [Enum.AddOnRestrictionType.PvPMatch] = true,
  [Enum.AddOnRestrictionType.Map] = true,
}

local function IsRestyleLocked()
  return InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() == true
end

local function GetViewer(viewerKey)
  return viewers[viewerKey]
end

local function ScheduleFlush()
  if enabled then
    flushFrame:Show()
  end
end

local function BuildCandidates(entry)
  local spellIDs = {}
  for index = 1, #(entry.identitySpellIDs or {}) do
    spellIDs[entry.identitySpellIDs[index]] = true
  end
  return spellIDs
end

local function ShouldHideIconRecord(record)
  if record.viewerKey ~= BUFF_ICON_VIEWER then
    return false
  end
  return hiddenResolver and hiddenResolver(record.entry) == true or false
end

local function RecordOccupiesLayout(record)
  if ShouldHideIconRecord(record) then
    return false
  end
  local style = viewers[record.viewerKey].style
  return style ~= nil
end

local function UpdateRecordVisibility(record)
  local visible = presentationActive and RecordOccupiesLayout(record)
  if record.layoutVisible == visible then
    return
  end
  record.layoutVisible = visible
  record.parts.frame:SetShown(visible)
  SetSlotActive(record, visible)
  if groupLayoutEnabled then
    ns.PCMGroupManager:RequestLayout()
  else
    AuraLayout:RequestLayout(record.viewerKey)
  end
end

local function GetIconStyle(record)
  local viewer = viewers[record.viewerKey]
  return IconSettings:ResolveOwnedStyle(record.entry, record.viewerKey, viewer.style)
end

local function ConfigureIconButton(record, button, unit, initializing)
  if initializing ~= true and IsRestyleLocked() then
    record.stylePending = true
    return
  end
  PCMPresentation.ConfigureOwnedAuraLayer(
    record.parts,
    button,
    unit,
    GetIconStyle(record)
  )
  record.stylePending = nil
end

local function ConfigureBarButton(record, button, initializing)
  if initializing ~= true and IsRestyleLocked() then
    record.stylePending = true
    return
  end
  PCMPresentation.ConfigureOwnedAuraBar(
    record.parts,
    button,
    viewers[record.viewerKey].style
  )
  record.stylePending = nil
end

local function InitializeAuraButton(record, button, unit)
  record.buttons[unit] = button
  button:SetCollapsesLayout(true)
  button:SetIgnoringChildrenForBounds(true)

  if record.viewerKey == BUFF_ICON_VIEWER then
    ConfigureIconButton(record, button, unit, true)
  else
    ConfigureBarButton(record, button, true)
  end
end

SetSlotActive = function(record, active)
  for _, handle in pairs(record.slots) do
    if handle then
      AuraSlotDriver:SetSlotActive(handle, active)
    end
  end
end

local function ConfigureRecordSlots(record)
  if IsRestyleLocked() then
    record.slotConfigurationPending = true
    pendingSlotConfiguration = true
    return
  end

  local candidates = BuildCandidates(record.entry)
  for _, unit in ipairs({ "player", "target" }) do
    local handle = record.slots[unit]
    local filter = unit == "player" and "HELPFUL|PLAYER" or "HARMFUL|PLAYER"
    if not handle then
      handle = AuraSlotDriver:CreateSlot(unit, filter, {
        candidateFilters = { includeSpellIDs = candidates },
        templateNames = { "PUI_AuraApplicationDurationTemplate" },
        initializeFrame = function(button)
          InitializeAuraButton(record, button, unit)
        end,
      })
      record.slots[unit] = handle
    else
      AuraSlotDriver:SetSlotFilter(handle, filter)
      AuraSlotDriver:SetSlotCandidates(handle, {
        includeSpellIDs = candidates,
      })
    end
  end

  record.slotConfigurationPending = nil
  SetSlotActive(record, enabled and presentationActive and RecordOccupiesLayout(record))
end

local function ApplyRecordAppearance(record)
  if record.viewerKey == BUFF_ICON_VIEWER then
    local style = GetIconStyle(record)
    PCMPresentation.ApplyOwnedIconStyle(record.parts, style)
    PCMPresentation.SetStaticIcon(record.parts, record.entry.texture)
    record.parts.frame:SetAlpha(style.hideWhenInactive and 0 or 1)
    for unit, button in pairs(record.buttons) do
      ConfigureIconButton(record, button, unit, false)
    end
  else
    for _, button in pairs(record.buttons) do
      ConfigureBarButton(record, button, false)
    end
    local placeholder = record.placeholder
    local style = viewers[BUFF_BAR_VIEWER].style
    placeholder:SetColorTexture(
      style.backgroundColor[1] or style.backgroundColor.r or 0.12,
      style.backgroundColor[2] or style.backgroundColor.g or 0.12,
      style.backgroundColor[3] or style.backgroundColor.b or 0.12,
      style.backgroundColor[4] or style.backgroundColor.a or 0.95
    )
    record.parts.frame:SetAlpha(style.hideWhenInactive and 0 or 1)
    record.placeholderLabel:SetText(record.entry.name or "")
    record.placeholderLabel:SetShown(style.orientation ~= "VERTICAL")
  end
  record.appearancePending = nil
end

local function CreateRecord(viewer, entry)
  local record = retiredRecords[viewer.key][entry.cooldownID]
  if record then
    retiredRecords[viewer.key][entry.cooldownID] = nil
    record.entry = entry
    record.parts.frame:SetParent(viewer.frame)
    viewer.records[entry.cooldownID] = record
    ConfigureRecordSlots(record)
    ApplyRecordAppearance(record)
    UpdateRecordVisibility(record)
    return record
  end

  local parts
  record = {
    cooldownID = entry.cooldownID,
    viewerKey = viewer.key,
    entry = entry,
    buttons = {},
    slots = {},
  }

  if viewer.key == BUFF_ICON_VIEWER then
    parts = PCMPresentation.CreateOwnedIcon(viewer.frame)
  else
    parts = PCMPresentation.CreateOwnedAuraBar(viewer.frame)
    local placeholder = parts.frame:CreateTexture(nil, "BACKGROUND")
    placeholder:SetAllPoints(parts.frame)
    local label = parts.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", parts.frame, "LEFT", 5, 0)
    label:SetPoint("RIGHT", parts.frame, "RIGHT", -30, 0)
    label:SetJustifyH("LEFT")
    record.placeholder = placeholder
    record.placeholderLabel = label
  end
  record.parts = parts
  viewer.records[entry.cooldownID] = record
  ConfigureRecordSlots(record)
  ApplyRecordAppearance(record)
  UpdateRecordVisibility(record)
  return record
end

local function ReleaseRecord(viewer, record)
  SetSlotActive(record, false)
  record.parts.frame:Hide()
  record.parts.frame:ClearAllPoints()
  record.layoutVisible = nil
  if record.viewerKey == BUFF_ICON_VIEWER then
    PCMPresentation.DeactivateOwnedIcon(record.parts)
  end
  viewer.records[record.cooldownID] = nil
  retiredRecords[viewer.key][record.cooldownID] = record
end

local function ReconcileViewer(viewer, entries, generation)
  local retained = {}
  local ordered = {}
  for index = 1, #entries do
    local entry = entries[index]
    local record = viewer.records[entry.cooldownID]
    if not record then
      record = CreateRecord(viewer, entry)
    else
      record.entry = entry
      ConfigureRecordSlots(record)
      ApplyRecordAppearance(record)
      UpdateRecordVisibility(record)
    end
    retained[entry.cooldownID] = true
    ordered[index] = record
  end

  for cooldownID, record in pairs(viewer.records) do
    if not retained[cooldownID] then
      ReleaseRecord(viewer, record)
    end
  end

  viewer.orderedRecords = ordered
  viewer.generation = generation
  if groupLayoutEnabled then
    ns.PCMGroupManager:RequestLayout(true)
  else
    AuraLayout:RequestLayout(viewer.key)
  end
end

local function GetLayoutFrames(viewer)
  local frames = {}
  for index = 1, #viewer.orderedRecords do
    local record = viewer.orderedRecords[index]
    if record.layoutVisible == true then
      frames[#frames + 1] = record.parts.frame
    end
  end
  return frames
end

local function RegisterLayout(viewer)
  if groupLayoutEnabled then
    return
  end

  AuraLayout:RegisterViewer(
    viewer.key,
    viewer.frame,
    function()
      return GetLayoutFrames(viewer)
    end,
    function()
      return viewer.style
    end,
    function()
      ns.FrameUtil.RefreshSmartSnapRuntimeLayout(viewer.key)
    end
  )
end

function AuraRuntime:InitializeViewer(viewerKey, parent)
  local viewer = GetViewer(viewerKey)
  if not viewer then
    return nil
  end
  if not viewer.frame then
    viewer.frame = CreateFrame("Frame", nil, parent or UIParent)
    viewer.frame:SetSize(1, 1)
    viewer.frame:SetPoint("CENTER", parent or UIParent, "CENTER", 0, 0)
    viewer.frame:Hide()
  elseif parent and viewer.frame:GetParent() ~= parent then
    viewer.frame:SetParent(parent)
  end
  RegisterLayout(viewer)
  return viewer.frame
end

function AuraRuntime:GetViewerFrame(viewerKey)
  local viewer = GetViewer(viewerKey)
  return viewer and viewer.frame or nil
end

function AuraRuntime:GetOrderedRecords(viewerKey)
  local viewer = GetViewer(viewerKey)
  return viewer and viewer.orderedRecords or nil
end

function AuraRuntime:SetGroupLayoutEnabled(active)
  groupLayoutEnabled = active == true
  groupLayoutReady = false

  for _, viewer in pairs(viewers) do
    AuraLayout:UnregisterViewer(viewer.key)
    if not groupLayoutEnabled and viewer.frame then
      RegisterLayout(viewer)
    end
  end

  if groupLayoutEnabled then
    ns.PCMGroupManager:RequestLayout()
  else
    for _, viewer in pairs(viewers) do
      AuraLayout:RequestLayout(viewer.key)
    end
  end
end

function AuraRuntime:SetGroupLayoutReady(ready)
  groupLayoutReady = ready == true
  if groupLayoutReady and not readyNotified and self:IsReady() then
    readyNotified = true
    ns.PCMNativeBridge:Refresh()
  end
end

function AuraRuntime:SetViewerStyle(viewerKey, style)
  local viewer = GetViewer(viewerKey)
  if not viewer then
    return
  end
  viewer.style = style
  for _, record in ipairs(viewer.orderedRecords) do
    ApplyRecordAppearance(record)
    UpdateRecordVisibility(record)
  end
  if groupLayoutEnabled then
    ns.PCMGroupManager:RequestLayout()
  else
    AuraLayout:RequestLayout(viewerKey)
  end
  ScheduleFlush()
end

function AuraRuntime:SetPresentationActive(active)
  presentationActive = active == true and enabled
  for _, viewer in pairs(viewers) do
    if viewer.frame then
      viewer.frame:SetShown(presentationActive)
    end
    for _, record in ipairs(viewer.orderedRecords) do
      UpdateRecordVisibility(record)
    end
  end
end

function AuraRuntime:SetBuffIconHiddenResolver(resolver)
  hiddenResolver = type(resolver) == "function" and resolver or nil
  self:RefreshBuffIconVisibility()
end

function AuraRuntime:RefreshBuffIconVisibility()
  local viewer = viewers[BUFF_ICON_VIEWER]
  for _, record in ipairs(viewer.orderedRecords) do
    UpdateRecordVisibility(record)
  end
  if groupLayoutEnabled then
    ns.PCMGroupManager:RequestLayout()
  else
    AuraLayout:RequestLayout(BUFF_ICON_VIEWER)
  end
end

function AuraRuntime:RefreshAppearance(viewerKey)
  local viewer = GetViewer(viewerKey)
  if not viewer then
    return
  end
  for _, record in ipairs(viewer.orderedRecords) do
    ApplyRecordAppearance(record)
  end
end

function AuraRuntime:RefreshLayout(viewerKey)
  if groupLayoutEnabled then
    ns.PCMGroupManager:RequestLayout()
  else
    AuraLayout:RequestLayout(viewerKey)
  end
end

function AuraRuntime:OnCatalogChanged(generation)
  pendingCatalog = true
  ScheduleFlush()
end

function AuraRuntime:Flush()
  if not enabled then
    flushFrame:Hide()
    return
  end

  if pendingCatalog
    and viewers[BUFF_ICON_VIEWER].style ~= nil
    and viewers[BUFF_BAR_VIEWER].style ~= nil
    and not IsRestyleLocked()
  then
    pendingCatalog = false
    for _, viewer in pairs(viewers) do
      local entries, generation = Catalog:GetViewerEntries(viewer.key)
      ReconcileViewer(viewer, entries, generation)
    end
  end

  if pendingSlotConfiguration and not IsRestyleLocked() then
    pendingSlotConfiguration = false
    for _, viewer in pairs(viewers) do
      for _, record in ipairs(viewer.orderedRecords) do
        if record.slotConfigurationPending then
          ConfigureRecordSlots(record)
        end
      end
    end
  end

  if pendingAppearance and not IsRestyleLocked() then
    pendingAppearance = false
    for _, viewer in pairs(viewers) do
      for _, record in ipairs(viewer.orderedRecords) do
        if record.stylePending then
          ApplyRecordAppearance(record)
        end
      end
    end
  end

  if pendingVisibility then
    pendingVisibility = false
    for _, viewer in pairs(viewers) do
      for _, record in ipairs(viewer.orderedRecords) do
        UpdateRecordVisibility(record)
      end
    end
  end

  if not groupLayoutEnabled then
    AuraLayout:Flush()
  end
  if not readyNotified and self:IsReady() then
    readyNotified = true
    ns.PCMNativeBridge:Refresh()
  end
  flushFrame:Hide()
end

function AuraRuntime:Enable()
  if enabled then
    return
  end
  enabled = true
  readyNotified = false
  presentationActive = false
  groupLayoutReady = false
  Catalog:Enable(self)
  Catalog:RegisterListener(self, self.OnCatalogChanged)
  restrictionFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
  restrictionFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  pendingCatalog = true
  ScheduleFlush()
end

function AuraRuntime:Disable()
  if not enabled then
    return
  end
  enabled = false
  readyNotified = false
  presentationActive = false
  Catalog:UnregisterListener(self)
  Catalog:Disable(self)
  restrictionFrame:UnregisterAllEvents()
  flushFrame:Hide()
  pendingCatalog = false
  pendingAppearance = false
  pendingVisibility = false
  pendingSlotConfiguration = false
  for _, viewer in pairs(viewers) do
    AuraLayout:UnregisterViewer(viewer.key)
    for _, record in ipairs(viewer.orderedRecords) do
      ReleaseRecord(viewer, record)
    end
    viewer.records = {}
    viewer.orderedRecords = {}
    viewer.generation = 0
    if viewer.frame then
      viewer.frame:SetSize(1, 1)
      viewer.frame:Hide()
    end
  end
end

function AuraRuntime:IsReady()
  local generation = Catalog:GetGeneration()
  return enabled
    and pendingCatalog ~= true
    and generation > 0
    and viewers[BUFF_ICON_VIEWER].frame ~= nil
    and viewers[BUFF_BAR_VIEWER].frame ~= nil
    and viewers[BUFF_ICON_VIEWER].style ~= nil
    and viewers[BUFF_BAR_VIEWER].style ~= nil
    and viewers[BUFF_ICON_VIEWER].generation == generation
    and viewers[BUFF_BAR_VIEWER].generation == generation
    and (
      groupLayoutEnabled and groupLayoutReady
      or AuraLayout:GetLastPlan(BUFF_ICON_VIEWER) ~= nil
        and AuraLayout:GetLastPlan(BUFF_BAR_VIEWER) ~= nil
    )
end

restrictionFrame:SetScript("OnEvent", function(_, event, restrictionType, state)
  if event == "ADDON_RESTRICTION_STATE_CHANGED"
    and state == Enum.AddOnRestrictionState.Activating
    and AURA_RESTRICTION_TYPES[restrictionType] == true
  then
    for _, viewer in pairs(viewers) do
      for _, record in ipairs(viewer.orderedRecords) do
        for _, button in pairs(record.buttons) do
          if button:CanBeAccessedInContext() then
            button:SetAlpha(1)
            record.stylePending = true
          end
        end
      end
    end
  end

  if event == "PLAYER_REGEN_ENABLED"
    or state == Enum.AddOnRestrictionState.Inactive
  then
    pendingAppearance = true
    pendingSlotConfiguration = true
    pendingVisibility = true
    ScheduleFlush()
  end
end)

flushFrame:SetScript("OnUpdate", function()
  AuraRuntime:Flush()
end)

local P = select(1, ns.Pleebug:DropIn(AuraRuntime, { name = "PCM", bucket = "AuraRuntime" }))
AuraRuntime.InitializeViewer = P:Def("AuraRuntime:InitializeViewer", AuraRuntime.InitializeViewer)
AuraRuntime.GetViewerFrame = P:Def("AuraRuntime:GetViewerFrame", AuraRuntime.GetViewerFrame)
AuraRuntime.GetOrderedRecords = P:Def("AuraRuntime:GetOrderedRecords", AuraRuntime.GetOrderedRecords)
AuraRuntime.SetGroupLayoutEnabled = P:Def("AuraRuntime:SetGroupLayoutEnabled", AuraRuntime.SetGroupLayoutEnabled)
AuraRuntime.SetGroupLayoutReady = P:Def("AuraRuntime:SetGroupLayoutReady", AuraRuntime.SetGroupLayoutReady)
AuraRuntime.SetViewerStyle = P:Def("AuraRuntime:SetViewerStyle", AuraRuntime.SetViewerStyle)
AuraRuntime.SetPresentationActive = P:Def("AuraRuntime:SetPresentationActive", AuraRuntime.SetPresentationActive)
AuraRuntime.SetBuffIconHiddenResolver = P:Def("AuraRuntime:SetBuffIconHiddenResolver", AuraRuntime.SetBuffIconHiddenResolver)
AuraRuntime.RefreshBuffIconVisibility = P:Def("AuraRuntime:RefreshBuffIconVisibility", AuraRuntime.RefreshBuffIconVisibility)
AuraRuntime.RefreshAppearance = P:Def("AuraRuntime:RefreshAppearance", AuraRuntime.RefreshAppearance)
AuraRuntime.RefreshLayout = P:Def("AuraRuntime:RefreshLayout", AuraRuntime.RefreshLayout)
AuraRuntime.OnCatalogChanged = P:Def("AuraRuntime:OnCatalogChanged", AuraRuntime.OnCatalogChanged)
AuraRuntime.Flush = P:Def("AuraRuntime:Flush", AuraRuntime.Flush)
AuraRuntime.Enable = P:Def("AuraRuntime:Enable", AuraRuntime.Enable)
AuraRuntime.Disable = P:Def("AuraRuntime:Disable", AuraRuntime.Disable)
AuraRuntime.IsReady = P:Def("AuraRuntime:IsReady", AuraRuntime.IsReady)
