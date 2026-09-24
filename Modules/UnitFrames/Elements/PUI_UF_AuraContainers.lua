local _, ns = ...

local _G = _G
local AuraContainers = {}
ns.UFAuraContainers = AuraContainers

local P = select(1, ns.Pleebug:DropIn(AuraContainers, { name = "UnitFrames.AuraContainers" }))

local AnchorUtil = _G.AnchorUtil
local AuraContainerSortDirection = _G.AuraContainerSortDirection
local AuraContainerSortMethod = _G.AuraContainerSortMethod
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local UnitExists = _G.UnitExists
local UnitIsConnected = _G.UnitIsConnected
local UnitIsVisible = _G.UnitIsVisible
local UnitPhaseReason = _G.UnitPhaseReason
local issecretvalue = _G.issecretvalue
local ipairs = _G.ipairs
local next = _G.next
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local table_concat = _G.table.concat
local table_sort = _G.table.sort
local tonumber = _G.tonumber
local tostring = _G.tostring

local AuraButtons = ns.UFAuraButtons
local AuraFilters = ns.UFAuraFilters
local AuraHighlight = ns.UFAuraHighlight
local AuraLayout = ns.UFAuraLayout

local INTERFACE_VERSION = select(4, _G.GetBuildInfo())
local SUPPORTS_NATIVE_AURA_TRACKING_ENABLE = INTERFACE_VERSION >= 120105
local SUPPORTS_NATIVE_AURA_STATE_REFRESH = INTERFACE_VERSION >= 120105

local SORT_METHODS = {
  BIG_DEFENSIVE = AuraContainerSortMethod.BigDefensive,
  INDEX = AuraContainerSortMethod.AuraInstanceIDOnly,
  NAME = AuraContainerSortMethod.NameOnly,
  PLAYER = AuraContainerSortMethod.Default,
  TIME_REMAINING = AuraContainerSortMethod.ExpirationOnly,
}

local SORT_DIRECTIONS = {
  ASCENDING = AuraContainerSortDirection.Normal,
  DESCENDING = AuraContainerSortDirection.Reverse,
}

local PendingFrameRequests = setmetatable({}, { __mode = "k" })
local AvailabilityFrames = setmetatable({}, { __mode = "k" })
local AvailabilityTicker
local RefreshDriver = CreateFrame("Frame")
RefreshDriver:RegisterEvent("PLAYER_ENTERING_WORLD")

local function Round(value)
  return ns.Pixel.Round(tonumber(value) or 0)
end

local function BuildDisplayLayout(frame, display)
  local target = AuraLayout.ResolveAttachTarget(frame, display.attachTo)
  local health = frame.Health or frame
  local metrics = AuraLayout.ResolveDisplayMetrics(
    frame:GetWidth(),
    health:GetHeight(),
    1,
    frame.__puiGroupKind == "party" or frame.__puiGroupKind == "raid",
    display
  )
  local initialAnchor = display.anchorPoint

  if display.specialType == "DEFENSIVES_EXTERNALS" and display.anchorPoint == "CENTER" then
    initialAnchor = metrics.growthX == "LEFT" and "RIGHT" or "LEFT"
  end

  return {
    attachTarget = target,
    anchorPoint = display.anchorPoint,
    relativePoint = display.relativePoint or display.anchorPoint,
    initialAnchor = initialAnchor,
    growthX = metrics.growthX,
    growthY = metrics.growthY,
    xOffset = Round(display.xOffset),
    yOffset = Round(display.yOffset),
    size = metrics.size,
    spacing = metrics.spacing,
    width = metrics.maximumLineSize,
    maxIcons = metrics.maxIcons,
  }
end

local function BuildDisplayLayoutSignature(layout)
  return table_concat({
    tostring(layout.attachTarget),
    tostring(layout.anchorPoint),
    tostring(layout.relativePoint),
    tostring(layout.initialAnchor),
    tostring(layout.growthX),
    tostring(layout.growthY),
    tostring(layout.xOffset),
    tostring(layout.yOffset),
    tostring(layout.size),
    tostring(layout.spacing),
    tostring(layout.width),
    tostring(layout.maxIcons),
  }, "\31")
end

local function BuildAuraGroupLayout(layout, layoutIndex)
  return {
    elementSpacing = layout.spacing,
    lineSpacing = layout.spacing,
    groupSpacing = 0,
    groupLineSpacing = layout.spacing,
    forceNewLine = false,
    elementWidth = layout.size,
    elementHeight = layout.size,
    layoutIndex = layoutIndex,
  }
end

local function BuildAuraGroupLayoutSignature(layout, layoutIndex)
  return table_concat({
    tostring(layout.spacing),
    tostring(layout.size),
    tostring(layoutIndex),
  }, "\31")
end

local function BuildAuraButtonAppearanceSignature(appearance, layout)
  -- Button styling must be part of runtime identity because Blizzard restricts
  -- the button subtree after initializeFrame returns.
  return table_concat({
    AuraButtons.BuildAppearanceSignature(appearance),
    tostring(layout.size),
  }, "\31")
end

local function RefreshNativeAuraContainers(frame, refreshBoundContainers)
  local unit = frame.__unit or frame.__puiConfigUnit
  local containers = frame.__puiAuraContainers
  if unit == nil or containers == nil then
    return
  end

  for index = 1, #containers do
    local container = containers[index]
    if container:IsEnabled() then
      if container:GetUnit() ~= unit then
        container:SetUnit(unit)
      elseif refreshBoundContainers ~= false then
        container:UpdateAllAuras()
      end
    end
  end
end

local function CreateAuraElement(frame, layout, appearance)
  local parent = frame.RaisedElementParent or frame
  local container = frame:CreateAuras({
    initialAnchor = layout.initialAnchor,
    layout = AnchorUtil.FlowLayoutAxis.Horizontal,
    layoutLimit = layout.width,
    growthX = layout.growthX,
    growthY = layout.growthY,
  })

  P:SecDef("BlizzardAuraContainer.UpdateAllAuras", container, "UpdateAllAuras")

  frame.__puiAuraContainers = frame.__puiAuraContainers or {}
  frame.__puiAuraContainers[#frame.__puiAuraContainers + 1] = container

  if not SUPPORTS_NATIVE_AURA_STATE_REFRESH
    and frame.__puiAuraStateRefreshEventsRegistered ~= true
  then
    frame.__puiAuraStateRefreshEventsRegistered = true
    frame:RegisterEvent("UNIT_FLAGS", RefreshNativeAuraContainers)
    frame:RegisterEvent("UNIT_FACTION", RefreshNativeAuraContainers)
  end

  container:SetParent(parent)
  container.__puiAuraAppearance = appearance
  container:SetSize(Round(1), Round(1))
  container:SetFrameStrata(frame:GetFrameStrata())
  container:SetFlowLayoutPadding(0, 0, 0, 0)

  local auraLevel = frame.RaisedElementParent and frame.RaisedElementParent.AuraLevel
  if auraLevel then
    container:SetFrameLevel(auraLevel)
  end

  return container
end

local function ApplyDisplayLayout(container, layout)
  container:ClearAllPoints()
  container:SetPoint(
    layout.anchorPoint,
    layout.attachTarget,
    layout.relativePoint,
    layout.xOffset,
    layout.yOffset
  )
  container:SetFlowLayoutAnchorPoint(layout.initialAnchor)
  container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
  container:SetFlowLayoutMaximumLineSize(layout.width)
  container:SetFlowLayoutGrowthDirection(
    layout.growthX == "LEFT" and AnchorUtil.FlowDirection.Left
      or AnchorUtil.FlowDirection.Right,
    layout.growthY == "DOWN" and AnchorUtil.FlowDirection.Down
      or AnchorUtil.FlowDirection.Up
  )
  container:SetFlowLayoutPadding(0, 0, 0, 0)
end

local RETIRED_SLOT_CANDIDATES = {
  includeSpellIDs = {
    [0] = true,
  },
}

local function InitializeAuraButton(container, options, button)
  local owner = container.__owner
  local auraLevel = owner.RaisedElementParent and owner.RaisedElementParent.AuraLevel

  if auraLevel then
    button:SetFrameLevel(auraLevel)
  end

  AuraButtons.CreateButton(container, options, button)
end

local function ApplySlotButtonLayout(button, layout)
  button:ClearAllPoints()
  button:SetSize(layout.size, layout.size)
  button:SetPoint(
    layout.anchorPoint,
    layout.attachTarget,
    layout.relativePoint,
    layout.xOffset,
    layout.yOffset
  )
end

local function BuildDisplayOptions(container, display, layout, layoutIndex, candidateFilters, appearance)
  local options = {
    __puiAuraKind = display.auraType == "HARMFUL" and "debuffs" or "buffs",
    __puiAuraAppearance = appearance,
    size = layout.size,
    candidateFilters = candidateFilters,
    sortMethod = SORT_METHODS[display.sortMethod] or AuraContainerSortMethod.ExpirationOnly,
    sortDirection = SORT_DIRECTIONS[display.sortDirection] or AuraContainerSortDirection.Normal,
    maxFrameCount = layout.maxIcons,
    layout = BuildAuraGroupLayout(layout, layoutIndex),
  }

  options.initializeFrame = function(button)
    InitializeAuraButton(container, options, button)
  end

  return options
end

local function IsDisplayEnabled(aDB, display)
  if aDB.enabled == false or display.enabled == false then
    return false
  end

  if display.specialType == "DEFENSIVES_EXTERNALS" then
    return display.showDefensives ~= false or display.showExternals ~= false
  end

  return true
end

local function UsesSharedAuraHost(aDB, display)
  if aDB.kind ~= "party" and aDB.kind ~= "raid" then
    return false
  end

  return display.displayType == "slot"
    or display.builtInKey == "DEFAULT_BUFF"
    or display.builtInKey == "DEFAULT_DEBUFF"
end

local function AcquireSharedAuraHost(frame, auraType, layout)
  frame.__puiSharedAuraHosts = frame.__puiSharedAuraHosts or {}
  local host = frame.__puiSharedAuraHosts[auraType]
  if host then
    return host
  end

  host = {
    auraType = auraType,
    container = CreateAuraElement(frame, layout, nil),
    runtimes = setmetatable({}, { __mode = "k" }),
    enabled = nil,
    shown = nil,
  }
  frame.__puiSharedAuraHosts[auraType] = host
  return host
end

local function UpdateSharedAuraHost(host)
  local enabled = false
  local shown = false

  for runtime in pairs(host.runtimes) do
    enabled = enabled or runtime.enabled == true
    shown = shown or runtime.shown == true
  end

  if host.enabled ~= enabled then
    host.enabled = enabled
    host.container:SetEnabled(enabled)
  end

  if host.shown ~= shown then
    host.shown = shown
    host.container:SetShown(shown)
  end
end

local function RegisterSharedRuntime(host, runtime)
  runtime.sharedHost = host
  host.runtimes[runtime] = true
end

local function SetSlotRuntimeTracking(runtime, enabled)
  if runtime.displayType ~= "slot" then
    return
  end

  if SUPPORTS_NATIVE_AURA_TRACKING_ENABLE then
    if runtime.nativeTrackingEnabled ~= enabled then
      runtime.nativeTrackingEnabled = enabled
      runtime.container:SetAuraSlotEnabled(runtime.key, enabled)
    end
    return
  end

  if enabled then
    if runtime.candidatesRetired then
      runtime.container:SetAuraSlotCandidateFilters(
        runtime.key,
        runtime.options.candidateFilters
      )
      runtime.candidatesRetired = nil
    end
  elseif not runtime.candidatesRetired then
    runtime.container:SetAuraSlotCandidateFilters(runtime.key, RETIRED_SLOT_CANDIDATES)
    runtime.candidatesRetired = true
  end
end

local function SetGroupRuntimeTracking(runtime, enabled)
  if runtime.displayType ~= "group" or not runtime.groupKey then
    return
  end

  if SUPPORTS_NATIVE_AURA_TRACKING_ENABLE then
    local trackingEnabled = enabled and runtime.configuredEnabled == true
    if runtime.nativeTrackingEnabled ~= trackingEnabled then
      runtime.nativeTrackingEnabled = trackingEnabled
      runtime.container:SetAuraGroupEnabled(runtime.groupKey, trackingEnabled)

      if runtime.encounterGroupKey then
        runtime.container:SetAuraGroupEnabled(runtime.encounterGroupKey, trackingEnabled)
      end
    end
    return
  end

  if not runtime.sharedHost then
    return
  end

  local maxFrameCount = enabled and runtime.configuredEnabled == true
    and runtime.layoutMaxIcons
    or 0

  if runtime.groupState.maxFrameCount ~= maxFrameCount then
    runtime.groupState.maxFrameCount = maxFrameCount
    runtime.container:SetAuraGroupMaxFrameCount(runtime.groupKey, maxFrameCount)
  end

  if runtime.encounterGroupKey
    and runtime.encounterGroupState.maxFrameCount ~= maxFrameCount
  then
    runtime.encounterGroupState.maxFrameCount = maxFrameCount
    runtime.container:SetAuraGroupMaxFrameCount(runtime.encounterGroupKey, maxFrameCount)
  end
end

local function SetRuntimeEnabled(runtime, enabled)
  enabled = enabled == true

  if runtime.auraHighlight then
    AuraHighlight.SetRuntimeEnabled(
      runtime.auraHighlight,
      enabled and AuraHighlight.IsEnabled(runtime.auraHighlight.frame)
    )
  end

  SetSlotRuntimeTracking(runtime, enabled)
  SetGroupRuntimeTracking(runtime, enabled)

  if runtime.enabled == enabled then
    return
  end

  runtime.enabled = enabled

  if runtime.sharedHost then
    UpdateSharedAuraHost(runtime.sharedHost)
  else
    runtime.container:SetEnabled(enabled)
  end
end

local function SetRuntimeShown(runtime, shown)
  shown = shown == true
  if runtime.shown == shown then
    return
  end

  runtime.shown = shown

  if runtime.sharedHost then
    UpdateSharedAuraHost(runtime.sharedHost)
  else
    runtime.container:SetShown(shown)
  end
end

local function SuspendDisplayRuntime(runtime)
  SetRuntimeEnabled(runtime, false)
end

local function DisableDisplayRuntime(runtime)
  runtime.configuredEnabled = false
  SuspendDisplayRuntime(runtime)
  SetRuntimeShown(runtime, false)
end

local function BuildRuntimeCreationKey(frame, aDB, display)
  local usesEncounterGroup = display.builtInKey == "DEFAULT_DEBUFF"
    and display.includeBossAuras == true
    and display.onlyPlayer == true

  local parts = {
    tostring(display.displayType),
    tostring(display.auraType),
    tostring(display.specialType or "DEFAULT"),
    tostring(display.builtInKey or "CUSTOM"),
    usesEncounterGroup and "ENCOUNTER" or "STANDARD",
  }

  local layout = BuildDisplayLayout(frame, display)
  local appearance = AuraFilters.BuildEffectiveAppearance(aDB, display)
  parts[#parts + 1] = BuildAuraButtonAppearanceSignature(appearance, layout)

  if display.displayType == "slot" then
    parts[#parts + 1] = BuildDisplayLayoutSignature(layout)
  elseif display.builtInKey == "DEFAULT_DEBUFF" then
    local highlightRuntimeKey = AuraHighlight.BuildRuntimeKey(frame)
    if highlightRuntimeKey then
      parts[#parts + 1] = highlightRuntimeKey
    end
  end

  return table_concat(parts, "\30")
end

local function CreateDisplayRuntime(frame, aDB, display)
  local layout = BuildDisplayLayout(frame, display)
  local sharedHost = UsesSharedAuraHost(aDB, display)
    and AcquireSharedAuraHost(frame, display.auraType, layout)
    or nil

  if display.displayType == "slot" then
    return ns.UFAuraTrackers.CreateRuntime(frame, aDB, display, sharedHost)
  end

  local appearance = AuraFilters.BuildEffectiveAppearance(aDB, display)
  local candidateFilters = AuraFilters.BuildCandidateFilters(display)
  local candidateSignature = AuraFilters.BuildCandidateFilterSignature(display)
  local container = sharedHost and sharedHost.container or CreateAuraElement(frame, layout, nil)
  local usesEncounterGroup = display.builtInKey == "DEFAULT_DEBUFF"
    and display.includeBossAuras == true
    and display.onlyPlayer == true
  local primaryLayoutIndex = usesEncounterGroup and 2 or 1
  local options = BuildDisplayOptions(
    container,
    display,
    layout,
    primaryLayoutIndex,
    candidateFilters,
    appearance
  )
  local filterString = AuraFilters.BuildFilterString(display)
  local runtime = {
    container = container,
    displayType = "group",
    enabled = nil,
    shown = nil,
    layoutSignature = BuildDisplayLayoutSignature(layout),
    configuredEnabled = nil,
    options = options,
    groupState = {
      filterString = filterString,
      maxFrameCount = options.maxFrameCount,
      candidateSignature = candidateSignature,
      sortMethod = options.sortMethod,
      sortDirection = options.sortDirection,
      layoutSignature = BuildAuraGroupLayoutSignature(layout, primaryLayoutIndex),
    },
    layoutMaxIcons = layout.maxIcons,
  }

  if sharedHost then
    RegisterSharedRuntime(sharedHost, runtime)
  end

  ApplyDisplayLayout(container, layout)

  if usesEncounterGroup then
    local encounterCandidateFilters = AuraFilters.BuildEncounterCandidateFilters(display)
    local encounterOptions = BuildDisplayOptions(
      container,
      display,
      layout,
      1,
      encounterCandidateFilters,
      appearance
    )

    runtime.encounterOptions = encounterOptions
    runtime.encounterGroupState = {
      filterString = "HARMFUL",
      maxFrameCount = encounterOptions.maxFrameCount,
      candidateSignature = candidateSignature .. "\31encounter:1",
      sortMethod = encounterOptions.sortMethod,
      sortDirection = encounterOptions.sortDirection,
      layoutSignature = BuildAuraGroupLayoutSignature(layout, 1),
    }
    runtime.encounterGroupKey = container:AddGroup("HARMFUL", encounterOptions)
  end

  runtime.groupKey = container:AddGroup(filterString, options)

  runtime.auraHighlight = display.builtInKey == "DEFAULT_DEBUFF"
    and AuraHighlight.AttachContainer(frame, container)
    or nil

  return runtime
end

local function ConfigureAuraGroup(
  runtime,
  groupKey,
  options,
  state,
  display,
  layout,
  filterString,
  candidateFilters,
  candidateSignature,
  layoutIndex
)
  local container = runtime.container
  local sortMethod = SORT_METHODS[display.sortMethod] or AuraContainerSortMethod.ExpirationOnly
  local sortDirection = SORT_DIRECTIONS[display.sortDirection] or AuraContainerSortDirection.Normal
  local layoutSignature = BuildAuraGroupLayoutSignature(layout, layoutIndex)
  local maxFrameCount = layout.maxIcons
  if not SUPPORTS_NATIVE_AURA_TRACKING_ENABLE then
    maxFrameCount = runtime.configuredEnabled == true
      and (not runtime.sharedHost or runtime.enabled ~= false)
      and layout.maxIcons
      or 0
  end

  runtime.layoutMaxIcons = layout.maxIcons
  options.__puiAuraKind = display.auraType == "HARMFUL" and "debuffs" or "buffs"
  options.maxFrameCount = maxFrameCount

  if state.filterString ~= filterString then
    state.filterString = filterString
    container:SetAuraGroupFilterString(groupKey, filterString)
  end

  if state.maxFrameCount ~= maxFrameCount then
    state.maxFrameCount = maxFrameCount
    container:SetAuraGroupMaxFrameCount(groupKey, maxFrameCount)
  end

  if state.candidateSignature ~= candidateSignature then
    state.candidateSignature = candidateSignature
    options.candidateFilters = candidateFilters
    container:SetAuraGroupCandidateFilters(groupKey, candidateFilters)
  end

  if state.sortMethod ~= sortMethod or state.sortDirection ~= sortDirection then
    state.sortMethod = sortMethod
    state.sortDirection = sortDirection
    options.sortMethod = sortMethod
    options.sortDirection = sortDirection
    container:SetAuraGroupSortMethod(groupKey, sortMethod, sortDirection)
  end

  if state.layoutSignature ~= layoutSignature then
    state.layoutSignature = layoutSignature
    local groupLayout = BuildAuraGroupLayout(layout, layoutIndex)
    options.layout = groupLayout
    container:SetAuraGroupLayout(groupKey, groupLayout)
  end
end

local function ConfigureDisplayRuntime(frame, aDB, display, runtime)
  if display.displayType == "slot" then
    ns.UFAuraTrackers.ConfigureRuntime(aDB, display, runtime)
    return
  end

  local layout = BuildDisplayLayout(frame, display)
  local layoutSignature = BuildDisplayLayoutSignature(layout)
  local candidateSignature = AuraFilters.BuildCandidateFilterSignature(display)

  if runtime.layoutSignature ~= layoutSignature then
    runtime.layoutSignature = layoutSignature
    ApplyDisplayLayout(runtime.container, layout)
  end

  runtime.configuredEnabled = IsDisplayEnabled(aDB, display)
  if runtime.encounterGroupKey then
    ConfigureAuraGroup(
      runtime,
      runtime.encounterGroupKey,
      runtime.encounterOptions,
      runtime.encounterGroupState,
      display,
      layout,
      "HARMFUL",
      AuraFilters.BuildEncounterCandidateFilters(display),
      candidateSignature .. "\31encounter:1",
      1
    )
  end

  ConfigureAuraGroup(
    runtime,
    runtime.groupKey,
    runtime.options,
    runtime.groupState,
    display,
    layout,
    AuraFilters.BuildFilterString(display),
    AuraFilters.BuildCandidateFilters(display),
    candidateSignature,
    runtime.encounterGroupKey and 2 or 1
  )

end

local function GetSortedDisplays(aDB)
  local displays = {}

  for _, display in pairs(aDB.customDisplays or {}) do
    displays[#displays + 1] = display
  end

  table_sort(displays, function(left, right)
    if left.order == right.order then
      return left.id < right.id
    end

    return left.order < right.order
  end)

  return displays
end

local function SetAllRuntimeElementState(frame, enabled)
  for _, record in pairs(frame.__puiCustomAuraDisplays or {}) do
    for _, runtime in pairs(record.runtimes) do
      SetRuntimeEnabled(runtime, enabled)
      SetRuntimeShown(runtime, enabled)
    end
  end
end

local function SyncUnknownRuntimeElementState(frame, enabled)
  for _, record in pairs(frame.__puiCustomAuraDisplays or {}) do
    for _, runtime in pairs(record.runtimes) do
      if runtime.enabled == nil then
        SetRuntimeEnabled(runtime, enabled)
      end
      if runtime.shown == nil then
        SetRuntimeShown(runtime, enabled)
      end
    end
  end
end

local function IsGroupAuraUnitAvailable(frame)
  if frame.__puiGroupKind ~= "party" and frame.__puiGroupKind ~= "raid" then
    return true
  end

  if frame.isForced == true then
    return true
  end

  local unit = frame.__unit or frame.__puiConfigUnit
  if unit == nil then
    return false
  end

  local exists = UnitExists(unit)
  if issecretvalue(exists) or exists ~= true then
    return false
  end

  local connected = UnitIsConnected(unit)
  if issecretvalue(connected) or connected ~= true then
    return false
  end

  local phaseReason = UnitPhaseReason(unit)
  if issecretvalue(phaseReason) or phaseReason ~= nil then
    return false
  end

  local visible = UnitIsVisible(unit)
  if issecretvalue(visible) or visible ~= true then
    return false
  end

  return true
end

local function ReconcileDisplayState(frame, unitAvailable)
  local elementActive = frame:IsElementEnabled("Auras") == true
    and not frame:IsElementPaused("Auras")
  if unitAvailable == nil then
    unitAvailable = IsGroupAuraUnitAvailable(frame)
  end
  frame.__puiAuraUnitAvailable = unitAvailable

  for _, record in pairs(frame.__puiCustomAuraDisplays or {}) do
    for _, runtime in pairs(record.runtimes) do
      local highlightActive = runtime.auraHighlight and AuraHighlight.IsEnabled(frame)
      local active = unitAvailable
        and runtime == record.activeRuntime
        and (runtime.configuredEnabled == true or highlightActive)
      SetRuntimeEnabled(runtime, elementActive and active)
      SetRuntimeShown(runtime, elementActive and active)
    end
  end
end

local function AuditAvailabilityFrame(frame, refreshAvailable)
  -- Render visibility can change without a unit event, so active group frames
  -- need a bounded audit that also repairs a stale native container binding.
  local unitAvailable = IsGroupAuraUnitAvailable(frame)
  local availabilityChanged = frame.__puiAuraUnitAvailable ~= unitAvailable

  if availabilityChanged then
    ReconcileDisplayState(frame, unitAvailable)
  end

  if unitAvailable then
    RefreshNativeAuraContainers(frame, availabilityChanged or refreshAvailable == true)
  end
end

local function StopAvailabilityTicker()
  if AvailabilityTicker then
    AvailabilityTicker:Cancel()
    AvailabilityTicker = nil
  end
end

local function AuditAvailabilityFrames()
  for frame in pairs(AvailabilityFrames) do
    if frame:IsVisible() then
      AuditAvailabilityFrame(frame)
    else
      AvailabilityFrames[frame] = nil
    end
  end

  if not next(AvailabilityFrames) then
    StopAvailabilityTicker()
  end
end

local function StartAvailabilityTicker()
  if not AvailabilityTicker then
    AvailabilityTicker = C_Timer.NewTicker(1, AuditAvailabilityFrames)
  end
end

local function AvailabilityFrame_OnShow(frame)
  AvailabilityFrames[frame] = true
  AuditAvailabilityFrame(frame)
  StartAvailabilityTicker()
end

local function AvailabilityFrame_OnHide(frame)
  AvailabilityFrames[frame] = nil

  if not next(AvailabilityFrames) then
    StopAvailabilityTicker()
  end
end

local function RegisterAvailabilityFrame(frame)
  if frame.__puiAuraAvailabilityRegistered == true
    or (frame.__puiGroupKind ~= "party" and frame.__puiGroupKind ~= "raid")
  then
    return
  end

  frame.__puiAuraAvailabilityRegistered = true
  frame:HookScript("OnShow", AvailabilityFrame_OnShow)
  frame:HookScript("OnHide", AvailabilityFrame_OnHide)

  if frame:IsVisible() then
    AvailabilityFrame_OnShow(frame)
  end
end

local function RefreshAurasElementLifecycle(frame, enabled)
  if frame.__puiUF_oUFInitialized ~= true then
    return
  end

  local elementEnabled = frame:IsElementEnabled("Auras") == true
  local elementPaused = frame:IsElementPaused("Auras")

  if elementPaused then
    SetAllRuntimeElementState(frame, false)
    return
  end

  if not enabled then
    if elementEnabled then
      frame:DisableElement("Auras")
      SetAllRuntimeElementState(frame, false)
    end
    return
  end

  if not elementEnabled then
    frame:EnableElement("Auras")
    SetAllRuntimeElementState(frame, true)
  else
    SyncUnknownRuntimeElementState(frame, true)
  end
end

local function ConfigureDisplayRecord(frame, aDB, display, records)
  local id = display.id
  local runtimeKey = BuildRuntimeCreationKey(frame, aDB, display)
  local record = records[id]

  if not record then
    record = { runtimes = {} }
    records[id] = record
  end

  for key, runtime in pairs(record.runtimes) do
    if key ~= runtimeKey then
      DisableDisplayRuntime(runtime)
    end
  end

  local runtime = record.runtimes[runtimeKey]
  local createdRuntime = false
  local needsHighlightHost = display.builtInKey == "DEFAULT_DEBUFF"
    and AuraHighlight.IsEnabled(frame)

  if not runtime and (IsDisplayEnabled(aDB, display) or needsHighlightHost) then
    runtime = CreateDisplayRuntime(frame, aDB, display)
    record.runtimes[runtimeKey] = runtime
    createdRuntime = true
  end

  record.activeRuntime = runtime

  if runtime then
    ConfigureDisplayRuntime(frame, aDB, display, runtime)

    if createdRuntime and frame.__puiUF_oUFInitialized == true then
      local unit = frame.__unit or frame.__puiConfigUnit
      local elementActive = frame:IsElementEnabled("Auras") == true
        and not frame:IsElementPaused("Auras")

      if unit and runtime.container:GetUnit() ~= unit then
        runtime.container:SetUnit(unit)
      end

      SetRuntimeEnabled(runtime, elementActive)
      SetRuntimeShown(runtime, elementActive)
    end

    if display.builtInKey == "DEFAULT_BUFF" then
      frame.AuraBuffs = runtime.container
    elseif display.builtInKey == "DEFAULT_DEBUFF" then
      frame.AuraDebuffs = runtime.container
    end
  end

  return runtime, createdRuntime
end

local function ConfigureDisplays(frame, aDB)
  local records = frame.__puiCustomAuraDisplays
  if not records then
    records = {}
    frame.__puiCustomAuraDisplays = records
  end

  local displays = GetSortedDisplays(aDB)
  local active = {}

  frame.AuraBuffs = nil
  frame.AuraDebuffs = nil

  for _, display in ipairs(displays) do
    local id = display.id
    active[id] = true
    ConfigureDisplayRecord(frame, aDB, display, records)
  end

  for id, record in pairs(records) do
    if not active[id] then
      record.activeRuntime = nil

      for _, runtime in pairs(record.runtimes) do
        DisableDisplayRuntime(runtime)
      end
    end
  end

end

local function QueueFrameConfigure(frame)
  PendingFrameRequests[frame] = true
  RefreshDriver:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function FlushPendingFrameRequests(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    RefreshDriver:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end

  RefreshDriver:UnregisterEvent("PLAYER_REGEN_ENABLED")

  for frame in pairs(PendingFrameRequests) do
    PendingFrameRequests[frame] = nil
    AuraContainers.Configure(frame)
  end
end

RefreshDriver:SetScript("OnEvent", FlushPendingFrameRequests)

AuraContainers.BuildDisplayLayout = BuildDisplayLayout
AuraContainers.CreateAuraElement = CreateAuraElement
AuraContainers.InitializeAuraButton = InitializeAuraButton
AuraContainers.IsDisplayEnabled = IsDisplayEnabled
AuraContainers.SetRuntimeEnabled = SetRuntimeEnabled
AuraContainers.SetRuntimeShown = SetRuntimeShown
AuraContainers.ApplySlotButtonLayout = ApplySlotButtonLayout
AuraContainers.RegisterSharedRuntime = RegisterSharedRuntime

function AuraContainers.GetSortMethod(display)
  return SORT_METHODS[display.sortMethod] or AuraContainerSortMethod.ExpirationOnly
end

function AuraContainers.GetSortDirection(display)
  return SORT_DIRECTIONS[display.sortDirection] or AuraContainerSortDirection.Normal
end

function AuraContainers.Configure(frame)
  if InCombatLockdown() then
    QueueFrameConfigure(frame)
    return
  end

  local aDB = AuraFilters.BuildFrameAuraDB(frame, frame.__unit or frame.__puiConfigUnit)
  frame.__puiAuraContainerDB = aDB

  local highlightEnabled = AuraHighlight.IsEnabled(frame)
  ConfigureDisplays(frame, aDB)
  RefreshAurasElementLifecycle(frame, aDB.enabled ~= false or highlightEnabled)
  ReconcileDisplayState(frame)
  RegisterAvailabilityFrame(frame)
end

local function RefreshFrameDisplay(frame, request)
  if InCombatLockdown() then
    QueueFrameConfigure(frame)
    return
  end

  local aDB = AuraFilters.BuildFrameAuraDB(frame, frame.__unit or frame.__puiConfigUnit)
  local displays = aDB.customDisplays or {}
  local records = frame.__puiCustomAuraDisplays

  if not records then
    AuraContainers.Configure(frame)
    return
  end

  frame.__puiAuraContainerDB = aDB

  local displayID = tonumber(request.displayID)
  local display = displayID and displays[displayID]

  if request.auraChange == "sharedAppearance" then
    local auraType = request.auraType or (display and display.auraType)

    for _, candidate in pairs(displays) do
      if candidate.auraType == auraType then
        ConfigureDisplayRecord(frame, aDB, candidate, records)
      end
    end
  elseif display then
    ConfigureDisplayRecord(frame, aDB, display, records)
  else
    AuraContainers.Configure(frame)
    return
  end

  local highlightEnabled = AuraHighlight.IsEnabled(frame)
  RefreshAurasElementLifecycle(frame, aDB.enabled ~= false or highlightEnabled)
  ReconcileDisplayState(frame)
end

function AuraContainers.RefreshFrame(frame, request)
  if not frame then
    return
  end

  if request
    and request.auraChange ~= "topology"
    and (
      tonumber(request.displayID) ~= nil
      or (request.auraChange == "sharedAppearance" and request.auraType ~= nil)
    )
  then
    RefreshFrameDisplay(frame, request)
    return
  end

  AuraContainers.Configure(frame)
end

function AuraContainers.RefreshHighlight(frame)
  if not frame then
    return
  end

  RefreshFrameDisplay(frame, {
    displayID = AuraFilters.BUILT_IN_DISPLAY_IDS.DEFAULT_DEBUFF,
    auraChange = "state",
  })
end

function AuraContainers.RefreshAvailability(frame, event)
  if not frame then
    return
  end

  AuditAvailabilityFrame(frame, event ~= nil)
end

function AuraContainers.RestoreConfiguredState(frame)
  if not frame or not frame.__puiCustomAuraDisplays then
    return
  end

  SetAllRuntimeElementState(
    frame,
    frame:IsElementEnabled("Auras") == true and not frame:IsElementPaused("Auras")
  )
  ReconcileDisplayState(frame)
end

QueueFrameConfigure = P:Def("QueueFrameConfigure", QueueFrameConfigure)
FlushPendingFrameRequests = P:Def("FlushPendingFrameRequests", FlushPendingFrameRequests)
ConfigureDisplayRecord = P:Def("ConfigureDisplayRecord", ConfigureDisplayRecord)
RefreshFrameDisplay = P:Def("RefreshFrameDisplay", RefreshFrameDisplay)
BuildDisplayOptions = P:Def("BuildDisplayOptions", BuildDisplayOptions)
UsesSharedAuraHost = P:Def("UsesSharedAuraHost", UsesSharedAuraHost)
BuildDisplayLayout = P:Def("BuildDisplayLayout", BuildDisplayLayout)
BuildDisplayLayoutSignature = P:Def("BuildDisplayLayoutSignature", BuildDisplayLayoutSignature)
BuildAuraGroupLayout = P:Def("BuildAuraGroupLayout", BuildAuraGroupLayout)
BuildAuraGroupLayoutSignature = P:Def("BuildAuraGroupLayoutSignature", BuildAuraGroupLayoutSignature)
BuildAuraButtonAppearanceSignature = P:Def(
  "BuildAuraButtonAppearanceSignature",
  BuildAuraButtonAppearanceSignature
)
RefreshNativeAuraContainers = P:Def("RefreshNativeAuraContainers", RefreshNativeAuraContainers)
CreateAuraElement = P:Def("CreateAuraElement", CreateAuraElement)
ApplyDisplayLayout = P:Def("ApplyDisplayLayout", ApplyDisplayLayout)
InitializeAuraButton = P:Def("InitializeAuraButton", InitializeAuraButton)
ApplySlotButtonLayout = P:Def("ApplySlotButtonLayout", ApplySlotButtonLayout)
AcquireSharedAuraHost = P:Def("AcquireSharedAuraHost", AcquireSharedAuraHost)
UpdateSharedAuraHost = P:Def("UpdateSharedAuraHost", UpdateSharedAuraHost)
RegisterSharedRuntime = P:Def("RegisterSharedRuntime", RegisterSharedRuntime)
SetSlotRuntimeTracking = P:Def("SetSlotRuntimeTracking", SetSlotRuntimeTracking)
SetGroupRuntimeTracking = P:Def("SetGroupRuntimeTracking", SetGroupRuntimeTracking)
IsDisplayEnabled = P:Def("IsDisplayEnabled", IsDisplayEnabled)
SetRuntimeEnabled = P:Def("SetRuntimeEnabled", SetRuntimeEnabled)
SetRuntimeShown = P:Def("SetRuntimeShown", SetRuntimeShown)
SuspendDisplayRuntime = P:Def("SuspendDisplayRuntime", SuspendDisplayRuntime)
DisableDisplayRuntime = P:Def("DisableDisplayRuntime", DisableDisplayRuntime)
BuildRuntimeCreationKey = P:Def("BuildRuntimeCreationKey", BuildRuntimeCreationKey)
CreateDisplayRuntime = P:Def("CreateDisplayRuntime", CreateDisplayRuntime)
ConfigureAuraGroup = P:Def("ConfigureAuraGroup", ConfigureAuraGroup)
ConfigureDisplayRuntime = P:Def("ConfigureDisplayRuntime", ConfigureDisplayRuntime)
GetSortedDisplays = P:Def("GetSortedDisplays", GetSortedDisplays)
SetAllRuntimeElementState = P:Def("SetAllRuntimeElementState", SetAllRuntimeElementState)
SyncUnknownRuntimeElementState = P:Def("SyncUnknownRuntimeElementState", SyncUnknownRuntimeElementState)
IsGroupAuraUnitAvailable = P:Def("IsGroupAuraUnitAvailable", IsGroupAuraUnitAvailable)
ReconcileDisplayState = P:Def("ReconcileDisplayState", ReconcileDisplayState)
AuditAvailabilityFrame = P:Def("AuditAvailabilityFrame", AuditAvailabilityFrame)
StopAvailabilityTicker = P:Def("StopAvailabilityTicker", StopAvailabilityTicker)
AuditAvailabilityFrames = P:Def("AuditAvailabilityFrames", AuditAvailabilityFrames)
StartAvailabilityTicker = P:Def("StartAvailabilityTicker", StartAvailabilityTicker)
AvailabilityFrame_OnShow = P:Def("AvailabilityFrame_OnShow", AvailabilityFrame_OnShow)
AvailabilityFrame_OnHide = P:Def("AvailabilityFrame_OnHide", AvailabilityFrame_OnHide)
RegisterAvailabilityFrame = P:Def("RegisterAvailabilityFrame", RegisterAvailabilityFrame)
RefreshAurasElementLifecycle = P:Def("RefreshAurasElementLifecycle", RefreshAurasElementLifecycle)
ConfigureDisplays = P:Def("ConfigureDisplays", ConfigureDisplays)
Round = P:Def("Round", Round)
AuraContainers.GetSortMethod = P:Def("AuraContainers.GetSortMethod", AuraContainers.GetSortMethod)
AuraContainers.GetSortDirection = P:Def("AuraContainers.GetSortDirection", AuraContainers.GetSortDirection)
AuraContainers.Configure = P:Def("AuraContainers.Configure", AuraContainers.Configure)
AuraContainers.RefreshFrame = P:Def("AuraContainers.RefreshFrame", AuraContainers.RefreshFrame)
AuraContainers.RefreshHighlight = P:Def("AuraContainers.RefreshHighlight", AuraContainers.RefreshHighlight)
AuraContainers.RefreshAvailability = P:Def("AuraContainers.RefreshAvailability", AuraContainers.RefreshAvailability)
AuraContainers.RestoreConfiguredState = P:Def("AuraContainers.RestoreConfiguredState", AuraContainers.RestoreConfiguredState)
