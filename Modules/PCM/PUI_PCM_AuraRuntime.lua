local _, ns = ...

local AuraRuntime = {}
ns.PCMAuraRuntime = AuraRuntime

local Catalog = ns.PCMCatalog
local PCMRuntime = ns.PCMRuntime
local AuraLayout = ns.PCMAuraLayout
local AuraSlotDriver = ns.AuraSlotDriver
local AuraWidget = ns.AuraWidget
local IconSettings = ns.PCMIconSettings
local PCMPresentation = ns.PCMPresentation

local CreateFrame = CreateFrame
local UIParent = UIParent
local C_Spell = C_Spell
local GetNumTotemSlots = GetNumTotemSlots
local GetTotemInfo = GetTotemInfo
local GetTotemDuration = GetTotemDuration
local ipairs = ipairs
local pairs = pairs
local type = type
local issecretvalue = issecretvalue

local BUFF_ICON_VIEWER = "BuffIconCooldownViewer"
local BUFF_BAR_VIEWER = "BuffBarCooldownViewer"
local AURA_UNITS = { "player", "target" }
local PLAYER_AURA_UNITS = { "player" }

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
local pendingTotems = false
local totemSpellIDs = {}
local totemDurations = {}
local SetSlotActive

local AURA_RESTRICTION_TYPES = {
  [Enum.AddOnRestrictionType.Combat] = true,
  [Enum.AddOnRestrictionType.Encounter] = true,
  [Enum.AddOnRestrictionType.ChallengeMode] = true,
  [Enum.AddOnRestrictionType.PvPMatch] = true,
  [Enum.AddOnRestrictionType.Map] = true,
}

local function GetViewer(viewerKey)
  return viewers[viewerKey]
end

local function ScheduleFlush()
  if enabled then
    flushFrame:Show()
  end
end

local function BuildCandidates(record)
  local spellIDs = {}
  local entry = record.entry
  for index = 1, #(entry.identitySpellIDs or {}) do
    local spellID = entry.identitySpellIDs[index]
    if not record.runtimeOverrideKnown or spellID ~= entry.overrideSpellID then
      spellIDs[spellID] = true
    end
  end
  if record.runtimeOverrideSpellID then
    spellIDs[record.runtimeOverrideSpellID] = true
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
  local layoutChanged = record.layoutVisible ~= visible
  record.layoutVisible = visible
  local shown = visible and (not groupLayoutEnabled or record.layoutPrepared == true)
  record.presentationShown = shown
  record.parts.frame:SetShown(shown)
  if record.layoutFrame then
    record.layoutFrame:SetShown(shown)
  end
  SetSlotActive(record, shown)
  if layoutChanged then
    if groupLayoutEnabled then
      ns.PCMGroupManager:RequestLayout()
    else
      AuraLayout:RequestLayout(record.viewerKey)
    end
  end
end

local function GetIconStyle(record)
  local viewer = viewers[record.viewerKey]
  return IconSettings:ResolveOwnedStyle(record.entry, record.viewerKey, viewer.style)
end

local function ConfigureIconButton(record, button, unit, initializing)
  if initializing ~= true and not button:CanBeAccessedInContext() then
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
  if initializing ~= true and not button:CanBeAccessedInContext() then
    record.stylePending = true
    return
  end
  PCMPresentation.ConfigureOwnedAuraBar(
    record.parts,
    button,
    viewers[record.viewerKey].style,
    button == record.buttons.totem
  )
  record.stylePending = nil
end

local function InitializeAuraButton(record, button, unit)
  record.buttons[unit] = button
  button:SetCollapsesLayout(true)
  button:SetIgnoringChildrenForBounds(true)

  if record.viewerKey == BUFF_ICON_VIEWER then
    ConfigureIconButton(record, button, unit, true)
    local size, padding = ns.PCMGroupManager:GetRecordIconLayout(record)
    button:SetSize(size, size)
    record.horizontalPadding = padding
  else
    ConfigureBarButton(record, button, true)
  end

  if record.layoutFrame then
    local sizeAssistant = CreateFrame(
      "Frame",
      nil,
      record.layoutFrame,
      "DisableUntrustedLayoutScriptsTemplate"
    )
    sizeAssistant:SetSize(0.001, 0.001)
    sizeAssistant:SetPoint("TOPLEFT", button, "BOTTOMRIGHT", record.horizontalPadding / 2, 0)
    record.boundsAssistants[unit] = sizeAssistant
  end
end

SetSlotActive = function(record, active)
  active = active and (not groupLayoutEnabled or record.layoutPrepared == true)
  for unit, handle in pairs(record.slots) do
    if handle then
      AuraSlotDriver:SetSlotActive(
        handle,
        active and record.totemSlot == nil
          and (record.entry.playerAuraOnly ~= true or unit == "player")
      )
    end
  end
  local button = record.buttons.totem
  if button then
    local shown = active and record.totemSlot ~= nil
    if record.totemShown ~= shown then
      record.totemShown = shown
      button:SetShown(shown)
      if record.boundsAssistants.totem then
        record.boundsAssistants.totem:SetShown(shown)
      end
      PCMPresentation.SetBuffTotemDuration(
        button.__puiAuraApplicationDurationParts,
        shown and record.totemDuration or nil
      )
    end
  end
end

local function SlotConfigurationMatches(left, right)
  if left.playerAuraOnly ~= right.playerAuraOnly or left.includeAnySource ~= right.includeAnySource then
    return false
  end
  local leftIDs = left.identitySpellIDs
  local rightIDs = right.identitySpellIDs
  if #leftIDs ~= #rightIDs then
    return false
  end
  for index = 1, #leftIDs do
    if leftIDs[index] ~= rightIDs[index] then
      return false
    end
  end
  return true
end

local function ConfigureRecordSlots(record)
  record.candidateSpellIDs = BuildCandidates(record)
  if PCMRuntime:IsAuraRestricted() then
    record.slotConfigurationPending = true
    pendingSlotConfiguration = true
    return
  end

  local candidates = record.candidateSpellIDs
  local units = record.entry.playerAuraOnly and PLAYER_AURA_UNITS or AURA_UNITS
  for _, unit in ipairs(units) do
    local handle = record.slots[unit]
    local filter
    if unit == "player" then
      filter = record.entry.includeAnySource == true and "HELPFUL" or "HELPFUL|PLAYER"
    else
      filter = "HARMFUL|PLAYER"
    end
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
    record.collapseWhenInactive = style.hideWhenInactive == true
    PCMPresentation.ApplyOwnedAuraIconStyle(record.parts, style)
    PCMPresentation.SetStaticIcon(
      record.parts,
      record.runtimeTexture or record.entry.texture
    )
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
    record.placeholderLabel:SetText(record.runtimeName or record.entry.name or "")
    record.placeholderLabel:SetShown(style.orientation ~= "VERTICAL")
  end
  record.appearancePending = nil
end

local function SetRecordTotem(record, slot, duration)
  local wasActive = record.totemSlot ~= nil
  record.totemSlot = slot
  record.totemDuration = duration
  if slot and not record.buttons.totem then
    local button = CreateFrame(
      "Frame", nil, viewers[record.viewerKey].frame, "PUI_AuraApplicationDurationTemplate"
    )
    button:Hide()
    InitializeAuraButton(record, button, "totem")
    if record.viewerKey == BUFF_ICON_VIEWER then
      button.PUIDurationCooldown:SetScript("OnCooldownDone", function()
        SetRecordTotem(record, nil, nil)
      end)
    end
    button:SetScript("OnEnter", function()
      GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
      GameTooltip:SetSpellByID(record.totemSpellID)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end
  if slot then
    local auraParts = record.buttons.totem.__puiAuraApplicationDurationParts
    auraParts.icon:SetTexture(record.runtimeTexture or record.entry.texture)
    if auraParts.ownedName then
      auraParts.ownedName:SetText(record.runtimeName or record.entry.name)
    end
  end
  record.totemShown = nil
  SetSlotActive(record, record.presentationShown == true)
  if wasActive ~= (slot ~= nil) then
    if groupLayoutEnabled then
      ns.PCMGroupManager:RequestLayout()
    else
      AuraLayout:RequestLayout(record.viewerKey)
    end
  end
end

local function RefreshTotemBindings(preferredSlot)
  if not presentationActive then
    return
  end
  wipe(totemSpellIDs)
  wipe(totemDurations)
  local slotCount = GetNumTotemSlots()
  for slot = 1, slotCount do
    local spellID = select(7, GetTotemInfo(slot))
    -- Totem identity may be secret; only public identities can select addon-owned records.
    if not issecretvalue(spellID) and type(spellID) == "number" and spellID > 0 then
      totemSpellIDs[slot] = spellID
      totemDurations[slot] = GetTotemDuration(slot)
    end
  end
  for _, viewer in pairs(viewers) do
    for _, record in ipairs(viewer.orderedRecords) do
      local selectedSlot
      local candidates = record.candidateSpellIDs
      for slot = 1, slotCount do
        local spellID = totemSpellIDs[slot]
        if spellID and candidates[spellID] and totemDurations[slot] then
          if not selectedSlot or slot == record.totemSlot or slot == preferredSlot then
            selectedSlot = slot
          end
          if slot == preferredSlot then
            break
          end
        end
      end
      if selectedSlot or record.totemSlot then
        record.totemSpellID = selectedSlot and totemSpellIDs[selectedSlot] or nil
        SetRecordTotem(record, selectedSlot, selectedSlot and totemDurations[selectedSlot] or nil)
      end
    end
  end
end

local function CreateRecord(viewer, entry, preparedOnly)
  local record = retiredRecords[viewer.key][entry.cooldownID]
  if record then
    retiredRecords[viewer.key][entry.cooldownID] = nil
    record.entry = entry
    record.runtimeOverrideKnown = false
    record.runtimeOverrideSpellID = entry.overrideSpellID
    record.runtimeName = nil
    record.runtimeTexture = nil
    record.candidateSpellIDs = BuildCandidates(record)
    viewer.records[entry.cooldownID] = record
    if not preparedOnly then
      ConfigureRecordSlots(record)
    end
    ApplyRecordAppearance(record)
    UpdateRecordVisibility(record)
    return record
  end

  local parts
  record = {
    cooldownID = entry.cooldownID,
    viewerKey = viewer.key,
    entry = entry,
    runtimeOverrideKnown = false,
    runtimeOverrideSpellID = entry.overrideSpellID,
    runtimeName = nil,
    runtimeTexture = nil,
    buttons = {},
    slots = {},
    boundsAssistants = {},
  }

  if viewer.key == BUFF_ICON_VIEWER then
    parts = PCMPresentation.CreateOwnedAuraIcon(viewer.frame)
    local layoutFrame = CreateFrame("Frame", nil, viewer.frame)
    layoutFrame:SetSize(1, 1)
    layoutFrame:SetIgnoringChildrenForBounds(true)
    record.layoutFrame = layoutFrame
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
  if record.layoutFrame then
    parts.frame:ClearAllPoints()
    parts.frame:SetPoint("TOPLEFT", record.layoutFrame, "TOPLEFT")
    record.layoutFrame:Hide()
  end
  parts.frame:Hide()
  viewer.records[entry.cooldownID] = record
  ConfigureRecordSlots(record)
  ApplyRecordAppearance(record)
  UpdateRecordVisibility(record)
  return record
end

local function ReleaseRecord(viewer, record)
  record.totemSlot = nil
  record.totemDuration = nil
  record.totemSpellID = nil
  SetSlotActive(record, false)
  record.parts.frame:Hide()
  if not record.layoutFrame then
    record.parts.frame:ClearAllPoints()
  end
  if record.layoutFrame then
    record.layoutFrame:Hide()
    record.layoutFrame:ClearAllPoints()
  end
  record.layoutVisible = nil
  record.layoutPrepared = nil
  record.presentationShown = nil
  if record.viewerKey == BUFF_ICON_VIEWER then
    PCMPresentation.DeactivateOwnedAuraIcon(record.parts)
  end
  viewer.records[record.cooldownID] = nil
  retiredRecords[viewer.key][record.cooldownID] = record
end

local function ReconcileViewer(viewer, entries, generation, restricted)
  local retained = {}
  local ordered = {}
  local deferred = false
  for index = 1, #entries do
    local entry = entries[index]
    local record = viewer.records[entry.cooldownID]
    if not record then
      local prepared = retiredRecords[viewer.key][entry.cooldownID]
      if not restricted or prepared and SlotConfigurationMatches(prepared.entry, entry) then
        record = CreateRecord(viewer, entry, restricted)
      else
        deferred = true
      end
    elseif not Catalog:EntriesMatch(record.entry, entry, true) then
      local configurationMatches = SlotConfigurationMatches(record.entry, entry)
      if restricted and not configurationMatches then
        deferred = true
      else
        record.entry = entry
        record.runtimeOverrideKnown = false
        record.runtimeOverrideSpellID = entry.overrideSpellID
        record.runtimeName = nil
        record.runtimeTexture = nil
        record.candidateSpellIDs = BuildCandidates(record)
        if not configurationMatches then
          ConfigureRecordSlots(record)
        end
        ApplyRecordAppearance(record)
      end
    else
      record.entry = entry
    end
    if record then
      retained[entry.cooldownID] = true
      ordered[#ordered + 1] = record
      UpdateRecordVisibility(record)
    end
  end

  for cooldownID, record in pairs(viewer.records) do
    if not retained[cooldownID] then
      ReleaseRecord(viewer, record)
    end
  end

  viewer.orderedRecords = ordered
  if not deferred or viewer.generation > 0 then
    viewer.generation = generation
  end
  if groupLayoutEnabled then
    ns.PCMGroupManager:RequestLayout(true)
  else
    AuraLayout:RequestLayout(viewer.key)
  end
  return deferred
end

local function GetLayoutFrames(viewer)
  local frames = {}
  for index = 1, #viewer.orderedRecords do
    local record = viewer.orderedRecords[index]
    if record.layoutVisible == true then
      frames[#frames + 1] = record.layoutFrame or record.parts.frame
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
  end
  RegisterLayout(viewer)
  return viewer.frame
end

function AuraRuntime:GetViewerFrame(viewerKey)
  local viewer = GetViewer(viewerKey)
  return viewer and viewer.frame or nil
end

function AuraRuntime:GetViewerStyle(viewerKey)
  local viewer = GetViewer(viewerKey)
  return viewer and viewer.style or nil
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
    if viewer.frame then
      viewer.frame:SetShown(presentationActive and not groupLayoutEnabled)
    end
    for _, record in ipairs(viewer.orderedRecords) do
      if groupLayoutEnabled then
        record.layoutPrepared = nil
      end
      UpdateRecordVisibility(record)
    end
    if not groupLayoutEnabled and viewer.frame then
      RegisterLayout(viewer)
    end
  end

  if not groupLayoutEnabled then
    for _, viewer in pairs(viewers) do
      AuraLayout:RequestLayout(viewer.key)
    end
  end
end

function AuraRuntime:SetGroupLayoutReady(ready)
  groupLayoutReady = ready == true
  for _, viewer in pairs(viewers) do
    if viewer.frame then
      viewer.frame:SetShown(
        presentationActive and (not groupLayoutEnabled or groupLayoutReady)
      )
    end
  end
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
  if presentationActive then
    restrictionFrame:RegisterEvent("PLAYER_TOTEM_UPDATE")
    restrictionFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  else
    restrictionFrame:UnregisterEvent("PLAYER_TOTEM_UPDATE")
    restrictionFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end
  for _, viewer in pairs(viewers) do
    if viewer.frame then
      viewer.frame:SetShown(
        presentationActive and (not groupLayoutEnabled or groupLayoutReady)
      )
    end
    for _, record in ipairs(viewer.orderedRecords) do
      UpdateRecordVisibility(record)
    end
  end
  RefreshTotemBindings()
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

function AuraRuntime:UsesCollapsedLayout(record)
  return record.viewerKey == BUFF_ICON_VIEWER and record.collapseWhenInactive == true
end

function AuraRuntime:PrepareRecordLayout(record, width, height, horizontalPadding)
  if record.viewerKey ~= BUFF_ICON_VIEWER then
    local frame = record.parts.frame
    frame:SetSize(width, height)
    return frame
  end

  local layoutFrame = record.layoutFrame
  layoutFrame:SetShown(record.layoutVisible == true)
  horizontalPadding = horizontalPadding or 0

  local frame = record.parts.frame
  frame:SetSize(width, height)
  for _, button in pairs(record.buttons) do
    if button:CanBeAccessedInContext() then
      button:SetSize(width, height)
    end
  end

  if record.collapseWhenInactive then
    local appliedPadding = record.horizontalPadding or horizontalPadding
    if appliedPadding ~= horizontalPadding then
      local canUpdatePadding = true
      for _, sizeAssistant in pairs(record.boundsAssistants) do
        if not sizeAssistant:CanBeAccessedInContext() then
          canUpdatePadding = false
          break
        end
      end
      if canUpdatePadding then
        appliedPadding = horizontalPadding
        for unit, sizeAssistant in pairs(record.boundsAssistants) do
          sizeAssistant:ClearAllPoints()
          sizeAssistant:SetPoint("TOPLEFT", record.buttons[unit], "BOTTOMRIGHT", appliedPadding / 2, 0)
        end
      end
    end
    record.horizontalPadding = appliedPadding
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", layoutFrame, "TOPLEFT", appliedPadding / 2, 0)
  else
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", layoutFrame, "CENTER")
    layoutFrame:SetSize(math.max(0.001, width + horizontalPadding), height)
  end
  return layoutFrame
end

function AuraRuntime:FinalizeRecordLayout(record)
  record.layoutPrepared = true
  UpdateRecordVisibility(record)
end

function AuraRuntime:RefreshRecordLayoutBounds(record)
  if record.viewerKey ~= BUFF_ICON_VIEWER or not record.collapseWhenInactive then
    return
  end

  local layoutFrame = record.layoutFrame
  layoutFrame:SetIgnoringChildrenForBounds(false)
  layoutFrame:SetSize(0.001, 0.001)
  layoutFrame:ResizeToBoundsRect()
  layoutFrame:SetIgnoringChildrenForBounds(true)
end

function AuraRuntime:ApplySpellOverride(baseSpellID, overrideSpellID)
  if issecretvalue(baseSpellID) or type(baseSpellID) ~= "number" then
    return
  end
  if overrideSpellID ~= nil
    and (issecretvalue(overrideSpellID) or type(overrideSpellID) ~= "number" or overrideSpellID <= 0)
  then
    return
  end

  local runtimeName
  local runtimeTexture
  if overrideSpellID then
    local name = C_Spell.GetSpellName(overrideSpellID)
    if not issecretvalue(name) and type(name) == "string" and name ~= "" then
      runtimeName = name
    end
    local texture = C_Spell.GetSpellTexture(overrideSpellID)
    if not issecretvalue(texture)
      and (type(texture) == "number" or type(texture) == "string")
    then
      runtimeTexture = texture
    end
  end

  for _, viewer in pairs(viewers) do
    for _, record in ipairs(viewer.orderedRecords) do
      if record.entry.baseSpellID == baseSpellID then
        record.runtimeOverrideKnown = true
        record.runtimeOverrideSpellID = overrideSpellID
        record.runtimeName = runtimeName
        record.runtimeTexture = runtimeTexture
        ConfigureRecordSlots(record)
        if record.viewerKey == BUFF_ICON_VIEWER then
          PCMPresentation.SetStaticIcon(
            record.parts,
            record.runtimeTexture or record.entry.texture
          )
        else
          record.placeholderLabel:SetText(record.runtimeName or record.entry.name or "")
        end
      end
    end
  end
  pendingTotems = true
  ScheduleFlush()
end

function AuraRuntime:OnCatalogChanged(generation)
  pendingCatalog = true
  pendingTotems = true
  ScheduleFlush()

  if PCMRuntime:IsAuraRestricted() then
    for _, viewer in pairs(viewers) do
      local entries = Catalog:GetViewerEntries(viewer.key)
      for index = 1, #entries do
        local entry = entries[index]
        local record = viewer.records[entry.cooldownID] or retiredRecords[viewer.key][entry.cooldownID]
        if not record or not SlotConfigurationMatches(record.entry, entry) then
          ns.Addon:PUI_ConfirmAction({
            title = "Buff tracking",
            text = "Buff tracking saved. Reload the UI to show newly tracked buffs now.",
            yesText = RELOADUI,
            noText = "Later",
            onYes = ReloadUI,
          })
          return
        end
      end
    end
  end
end

function AuraRuntime:Flush()
  if not enabled then
    flushFrame:Hide()
    return
  end

  if pendingCatalog
    and viewers[BUFF_ICON_VIEWER].style ~= nil
    and viewers[BUFF_BAR_VIEWER].style ~= nil
  then
    pendingCatalog = false
    local restricted = PCMRuntime:IsAuraRestricted()
    for _, viewer in pairs(viewers) do
      local entries, generation = Catalog:GetViewerEntries(viewer.key)
      if ReconcileViewer(viewer, entries, generation, restricted) then
        pendingCatalog = true
      end
    end
  end

  if pendingSlotConfiguration and not PCMRuntime:IsAuraRestricted() then
    pendingSlotConfiguration = false
    for _, viewer in pairs(viewers) do
      for _, record in ipairs(viewer.orderedRecords) do
        if record.slotConfigurationPending then
          ConfigureRecordSlots(record)
        end
      end
    end
  end

  if pendingAppearance and not PCMRuntime:IsAuraRestricted() then
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

  if pendingTotems then
    pendingTotems = false
    RefreshTotemBindings()
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
  restrictionFrame:UnregisterAllEvents()
  flushFrame:Hide()
  pendingCatalog = false
  pendingAppearance = false
  pendingVisibility = false
  pendingSlotConfiguration = false
  pendingTotems = false
  wipe(totemSpellIDs)
  wipe(totemDurations)
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
  return enabled
    and viewers[BUFF_ICON_VIEWER].generation > 0
    and viewers[BUFF_ICON_VIEWER].frame ~= nil
    and viewers[BUFF_BAR_VIEWER].frame ~= nil
    and viewers[BUFF_ICON_VIEWER].style ~= nil
    and viewers[BUFF_BAR_VIEWER].style ~= nil
    and viewers[BUFF_ICON_VIEWER].generation == viewers[BUFF_BAR_VIEWER].generation
    and (
      groupLayoutEnabled and groupLayoutReady
      or AuraLayout:GetLastPlan(BUFF_ICON_VIEWER) ~= nil
        and AuraLayout:GetLastPlan(BUFF_BAR_VIEWER) ~= nil
    )
end

restrictionFrame:SetScript("OnEvent", function(_, event, restrictionType, state)
  if event == "PLAYER_TOTEM_UPDATE" then
    RefreshTotemBindings(restrictionType)
    return
  elseif event == "PLAYER_ENTERING_WORLD" then
    RefreshTotemBindings()
    return
  end
  if event == "ADDON_RESTRICTION_STATE_CHANGED"
    and state == Enum.AddOnRestrictionState.Activating
    and AURA_RESTRICTION_TYPES[restrictionType] == true
  then
    for _, viewer in pairs(viewers) do
      for _, record in ipairs(viewer.orderedRecords) do
        for unit, button in pairs(record.buttons) do
          if unit ~= "totem" and button:CanBeAccessedInContext() then
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
    pendingTotems = true
    ScheduleFlush()
  end
end)

flushFrame:SetScript("OnUpdate", function()
  AuraRuntime:Flush()
end)

local P = select(1, ns.Pleebug:DropIn(AuraRuntime, { name = "PCM", bucket = "AuraRuntime" }))
AuraRuntime.InitializeViewer = P:Def("AuraRuntime:InitializeViewer", AuraRuntime.InitializeViewer)
AuraRuntime.GetViewerFrame = P:Def("AuraRuntime:GetViewerFrame", AuraRuntime.GetViewerFrame)
AuraRuntime.GetViewerStyle = P:Def("AuraRuntime:GetViewerStyle", AuraRuntime.GetViewerStyle)
AuraRuntime.GetOrderedRecords = P:Def("AuraRuntime:GetOrderedRecords", AuraRuntime.GetOrderedRecords)
AuraRuntime.SetGroupLayoutEnabled = P:Def("AuraRuntime:SetGroupLayoutEnabled", AuraRuntime.SetGroupLayoutEnabled)
AuraRuntime.SetGroupLayoutReady = P:Def("AuraRuntime:SetGroupLayoutReady", AuraRuntime.SetGroupLayoutReady)
AuraRuntime.SetViewerStyle = P:Def("AuraRuntime:SetViewerStyle", AuraRuntime.SetViewerStyle)
AuraRuntime.SetPresentationActive = P:Def("AuraRuntime:SetPresentationActive", AuraRuntime.SetPresentationActive)
AuraRuntime.SetBuffIconHiddenResolver = P:Def("AuraRuntime:SetBuffIconHiddenResolver", AuraRuntime.SetBuffIconHiddenResolver)
AuraRuntime.RefreshBuffIconVisibility = P:Def("AuraRuntime:RefreshBuffIconVisibility", AuraRuntime.RefreshBuffIconVisibility)
AuraRuntime.RefreshAppearance = P:Def("AuraRuntime:RefreshAppearance", AuraRuntime.RefreshAppearance)
AuraRuntime.RefreshLayout = P:Def("AuraRuntime:RefreshLayout", AuraRuntime.RefreshLayout)
AuraRuntime.UsesCollapsedLayout = P:Def("AuraRuntime:UsesCollapsedLayout", AuraRuntime.UsesCollapsedLayout)
AuraRuntime.PrepareRecordLayout = P:Def("AuraRuntime:PrepareRecordLayout", AuraRuntime.PrepareRecordLayout)
AuraRuntime.FinalizeRecordLayout = P:Def("AuraRuntime:FinalizeRecordLayout", AuraRuntime.FinalizeRecordLayout)
AuraRuntime.RefreshRecordLayoutBounds = P:Def("AuraRuntime:RefreshRecordLayoutBounds", AuraRuntime.RefreshRecordLayoutBounds)
AuraRuntime.ApplySpellOverride = P:Def("AuraRuntime:ApplySpellOverride", AuraRuntime.ApplySpellOverride)
AuraRuntime.OnCatalogChanged = P:Def("AuraRuntime:OnCatalogChanged", AuraRuntime.OnCatalogChanged)
AuraRuntime.Flush = P:Def("AuraRuntime:Flush", AuraRuntime.Flush)
AuraRuntime.Enable = P:Def("AuraRuntime:Enable", AuraRuntime.Enable)
AuraRuntime.Disable = P:Def("AuraRuntime:Disable", AuraRuntime.Disable)
AuraRuntime.IsReady = P:Def("AuraRuntime:IsReady", AuraRuntime.IsReady)
