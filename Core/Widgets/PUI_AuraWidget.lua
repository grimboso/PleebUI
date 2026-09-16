local _, ns = ...

local AuraWidget = {}
ns.AuraWidget = AuraWidget

local CreateFrame = CreateFrame
local table_sort = table.sort

local MAX_STACK_COLOR_THRESHOLD = 30
local STACK_COLOR_THRESHOLD_DEFAULT_COLOR = { 1, 0.82, 0, 1 }

local applicationThresholdTracks = setmetatable({}, { __mode = "k" })
local applicationThresholdViewerHooks = setmetatable({}, { __mode = "k" })
local applicationThresholdViewerSnapshots = {}
local applicationThresholdSnapshotGeneration = 0
local applicationThresholdTickFrame
local applicationThresholdWakeFrame
local applicationThresholdIdleTicks = 0

local function IsUsableSpellID(spellID)
  if type(spellID) ~= "number" then
    return false
  end
  if issecretvalue(spellID) then
    return false
  end
  return spellID > 0 and spellID == math.floor(spellID)
end

local function BuildApplicationThresholdSpellSet(spellIDs)
  local spellSet = {}
  local orderedSpellIDs = {}

  local function AddSpellID(spellID)
    if not IsUsableSpellID(spellID) or spellSet[spellID] then
      return
    end

    spellSet[spellID] = true
    orderedSpellIDs[#orderedSpellIDs + 1] = spellID

    local baseSpellID = C_Spell.GetBaseSpell(spellID)
    if IsUsableSpellID(baseSpellID) and not spellSet[baseSpellID] then
      spellSet[baseSpellID] = true
      orderedSpellIDs[#orderedSpellIDs + 1] = baseSpellID
    end
  end

  if type(spellIDs) == "table" then
    for key, value in pairs(spellIDs) do
      local spellID = type(key) == "number" and value == true and key or value
      AddSpellID(spellID)
    end
  elseif IsUsableSpellID(spellIDs) then
    AddSpellID(spellIDs)
  end

  return spellSet, orderedSpellIDs
end

local function SourceHasSpell(source, spellID)
  return IsUsableSpellID(spellID) and source.spellSet[spellID] == true
end

local function ApplicationThresholdInfoMatches(info, source)
  if not info then
    return false
  end

  if SourceHasSpell(source, info.overrideSpellID)
    or SourceHasSpell(source, info.overrideTooltipSpellID)
    or SourceHasSpell(source, info.spellID)
  then
    return true
  end

  for _, spellID in ipairs(info.linkedSpellIDs) do
    if SourceHasSpell(source, spellID) then
      return true
    end
  end
  return false
end

local function GetApplicationThresholdFrameSpellID(frame)
  local auraData = frame.auraDataCached
  if not issecretvalue(auraData) and type(auraData) == "table" then
    local spellID = auraData.spellId
    if IsUsableSpellID(spellID) then
      return spellID
    end
  end

  local spellID = frame:GetAuraSpellID()
  if IsUsableSpellID(spellID) then
    return spellID
  end

  spellID = frame:GetSpellID()
  if IsUsableSpellID(spellID) then
    return spellID
  end

  return nil
end

local function ApplicationThresholdFrameHasSourceUnit(frame, source)
  local unit = frame:GetAuraDataUnit()
  if issecretvalue(unit) then
    return false
  end
  return unit ~= nil and unit == source.unit
end

local function ApplicationThresholdFrameCanServeSource(frame, source)
  local unit = frame:GetAuraDataUnit()
  if issecretvalue(unit) then
    return false
  end
  return unit == nil or unit == source.unit
end

local function ApplicationThresholdFrameMatches(frame, source)
  if not ApplicationThresholdFrameCanServeSource(frame, source) then
    return false
  end
  local cooldownID = frame.cooldownID
  if source.childCooldownID and cooldownID == source.childCooldownID then
    return true
  end

  if not cooldownID then
    return false
  end

  local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
  if ApplicationThresholdInfoMatches(info, source) then
    return true
  end

  return SourceHasSpell(
    source,
    GetApplicationThresholdFrameSpellID(frame)
  )
end

local function GetApplicationThresholdViewerSnapshot(viewerKey)
  local viewer = _G[viewerKey]
  if not viewer or not viewer.itemFramePool then
    return nil
  end

  local snapshot = applicationThresholdViewerSnapshots[viewerKey]
  if not snapshot then
    snapshot = {
      frames = {},
      active = {},
      generation = -1,
    }
    applicationThresholdViewerSnapshots[viewerKey] = snapshot
  end

  if snapshot.generation == applicationThresholdSnapshotGeneration then
    return snapshot
  end

  local frames = snapshot.frames
  local active = snapshot.active

  for index = 1, #frames do
    local frame = frames[index]
    frames[index] = nil
    active[frame] = nil
  end

  local count = 0
  for frame in viewer.itemFramePool:EnumerateActive() do
    count = count + 1
    frames[count] = frame
    active[frame] = true
  end

  snapshot.generation = applicationThresholdSnapshotGeneration
  return snapshot
end

local function FindApplicationThresholdChild(source)
  local snapshot = GetApplicationThresholdViewerSnapshot(source.viewerKey)
  if not snapshot then
    return nil
  end

  local frames = snapshot.frames

  -- A clean CDM identity can validate a binding. During the restricted window,
  -- retain the same pooled child only while it still serves the original slot.
  local child = source.child
  if child
    and child.cooldownID == source.childCooldownID
    and ApplicationThresholdFrameHasSourceUnit(child, source)
    and snapshot.active[child] == true
  then
    return child
  end

  source.child = nil
  source.childCooldownID = nil

  for index = 1, #frames do
    local frame = frames[index]
    if ApplicationThresholdFrameHasSourceUnit(frame, source)
      and SourceHasSpell(
        source,
        GetApplicationThresholdFrameSpellID(frame)
      )
    then
      source.child = frame
      source.childCooldownID = frame.cooldownID
      return frame
    end
  end

  local candidate
  for index = 1, #frames do
    local frame = frames[index]
    if ApplicationThresholdFrameMatches(frame, source) then
      if candidate then
        return nil
      end
      candidate = frame
    end
  end

  if candidate then
    source.child = candidate
    source.childCooldownID = candidate.cooldownID
  end

  return candidate
end

local function FeedApplicationThresholds(parts, value)
  local overlays = parts.applicationThresholds
  local count = parts.applicationThresholdCount or 0

  for index = 1, count do
    overlays[index]:SetValue(value)
  end
end

local function FeedCDMStackApplications(parts, blizzardChild)
  -- CDM's cache is authoritative. Restricted application counts pass directly
  -- to native StatusBar setters without Lua comparison, coercion, or caching.
  local auraData = blizzardChild.auraDataCached
  if issecretvalue(auraData) or type(auraData) ~= "table" then
    return false
  end

  if issecretvalue(auraData.applications) then
    if parts.applicationThresholdMirror then
      parts.applicationThresholdMirror:SetValue(
        auraData.applications,
        parts.applicationThresholdInterpolation
      )
    end
    FeedApplicationThresholds(parts, auraData.applications)
    return true
  end

  local applications = auraData.applications
  if type(applications) ~= "number" then
    return false
  end

  if parts.applicationThresholdMirror then
    parts.applicationThresholdMirror:SetValue(
      applications,
      parts.applicationThresholdInterpolation
    )
  end
  FeedApplicationThresholds(parts, applications)
  return true
end

local function UpdateApplicationThresholdTracks()
  local tickLive = false

  applicationThresholdSnapshotGeneration = applicationThresholdSnapshotGeneration + 1

  for parts, source in pairs(applicationThresholdTracks) do
    if parts.applicationThresholdMirrorIsVisible ~= true then
      applicationThresholdTracks[parts] = nil
    else
      local child = FindApplicationThresholdChild(source)
      local active
      if child then
        active = child:IsActive()
      end

      local applicationsUpdated = child
        and FeedCDMStackApplications(parts, child)
        or false
      if applicationsUpdated ~= true
        and child
        and not issecretvalue(active)
        and active ~= true
      then
        if parts.applicationThresholdMirror then
          parts.applicationThresholdMirror:SetValue(0)
        end
        FeedApplicationThresholds(parts, 0)
      end

      if issecretvalue(active) then
        if applicationsUpdated == true then
          tickLive = true
        end
      elseif active == true then
        tickLive = true
      end
    end
  end

  if not next(applicationThresholdTracks) then
    if applicationThresholdTickFrame then
      applicationThresholdTickFrame:Hide()
    end
    if applicationThresholdWakeFrame then
      applicationThresholdWakeFrame:UnregisterAllEvents()
    end
    return
  end

  if tickLive then
    applicationThresholdIdleTicks = 0
  elseif applicationThresholdTickFrame and applicationThresholdTickFrame:IsShown() then
    applicationThresholdIdleTicks = applicationThresholdIdleTicks + 1
    if applicationThresholdIdleTicks >= 10 then
      applicationThresholdTickFrame:Hide()
    end
  end
end

local function EnableApplicationThresholdWakeEvents()
  if applicationThresholdWakeFrame:IsEventRegistered("UNIT_AURA") then
    return
  end

  applicationThresholdWakeFrame:RegisterEvent("ADDON_LOADED")
  applicationThresholdWakeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  applicationThresholdWakeFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
  applicationThresholdWakeFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
  applicationThresholdWakeFrame:RegisterUnitEvent("UNIT_AURA", "player", "target")
end

local function WakeApplicationThresholdTicker()
  applicationThresholdIdleTicks = 0
  EnableApplicationThresholdWakeEvents()

  if not applicationThresholdTickFrame then
    applicationThresholdTickFrame = CreateFrame("Frame")
    local accumulator = 0
    applicationThresholdTickFrame:SetScript("OnUpdate", function(_, elapsed)
      accumulator = accumulator + elapsed
      if accumulator < 0.05 then
        return
      end
      accumulator = 0
      UpdateApplicationThresholdTracks()
    end)
  end

  applicationThresholdTickFrame:Show()
end

local function EnsureApplicationThresholdViewerHook(viewerKey)
  local viewer = _G[viewerKey]
  local pool = viewer and viewer.itemFramePool
  if not pool or applicationThresholdViewerHooks[pool] then
    return
  end

  applicationThresholdViewerHooks[pool] = true
  hooksecurefunc(pool, "Acquire", function()
    WakeApplicationThresholdTicker()
  end)
end

applicationThresholdWakeFrame = CreateFrame("Frame")
applicationThresholdWakeFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 ~= "Blizzard_CooldownViewer" then
    return
  end

  EnsureApplicationThresholdViewerHook("BuffBarCooldownViewer")
  EnsureApplicationThresholdViewerHook("BuffIconCooldownViewer")

  if next(applicationThresholdTracks) then
    WakeApplicationThresholdTicker()
  end
end)

local function NormalizeStackColorThreshold(threshold, index)
  if type(threshold) ~= "table" then
    threshold = {}
  end

  if threshold.enabled == nil then
    threshold.enabled = true
  else
    threshold.enabled = threshold.enabled == true
  end

  local defaultValue = math.min(MAX_STACK_COLOR_THRESHOLD, (index or 1) + 1)
  threshold.value = math.floor((tonumber(threshold.value) or defaultValue) + 0.5)
  threshold.value = math.max(1, math.min(MAX_STACK_COLOR_THRESHOLD, threshold.value))
  threshold.colorMode = threshold.colorMode == "CLASS" and "CLASS" or "CUSTOM"

  local color = type(threshold.color) == "table" and threshold.color or {}
  color[1] = tonumber(color[1] or color.r) or STACK_COLOR_THRESHOLD_DEFAULT_COLOR[1]
  color[2] = tonumber(color[2] or color.g) or STACK_COLOR_THRESHOLD_DEFAULT_COLOR[2]
  color[3] = tonumber(color[3] or color.b) or STACK_COLOR_THRESHOLD_DEFAULT_COLOR[3]
  color[4] = tonumber(color[4] or color.a) or STACK_COLOR_THRESHOLD_DEFAULT_COLOR[4]
  threshold.color = color

  return threshold
end

function AuraWidget.EnsureStackColorThresholds(config)
  if type(config) ~= "table" then
    return nil
  end

  local thresholds = type(config.stackColorThresholds) == "table"
    and config.stackColorThresholds
    or {}

  for index = 1, #thresholds do
    thresholds[index] = NormalizeStackColorThreshold(thresholds[index], index)
  end

  table_sort(thresholds, function(left, right)
    return left.value < right.value
  end)

  config.stackColorThresholds = thresholds
  return thresholds
end

function AuraWidget.AddStackColorThreshold(config, maximum)
  local thresholds = AuraWidget.EnsureStackColorThresholds(config)
  if not thresholds then
    return nil
  end

  maximum = math.floor((tonumber(maximum) or MAX_STACK_COLOR_THRESHOLD) + 0.5)
  maximum = math.max(1, math.min(MAX_STACK_COLOR_THRESHOLD, maximum))
  if #thresholds >= maximum then
    return nil
  end

  local used = {}
  for index = 1, #thresholds do
    used[thresholds[index].value] = true
  end

  local last = thresholds[#thresholds]
  local startValue = last and math.min(maximum, last.value + 1) or math.min(2, maximum)
  local value

  for candidate = startValue, maximum do
    if not used[candidate] then
      value = candidate
      break
    end
  end

  if not value then
    for candidate = 1, startValue - 1 do
      if not used[candidate] then
        value = candidate
        break
      end
    end
  end

  if not value then
    return nil
  end

  local threshold = NormalizeStackColorThreshold({
    enabled = true,
    value = value,
    colorMode = "CUSTOM",
    color = {
      STACK_COLOR_THRESHOLD_DEFAULT_COLOR[1],
      STACK_COLOR_THRESHOLD_DEFAULT_COLOR[2],
      STACK_COLOR_THRESHOLD_DEFAULT_COLOR[3],
      STACK_COLOR_THRESHOLD_DEFAULT_COLOR[4],
    },
  }, #thresholds + 1)

  thresholds[#thresholds + 1] = threshold
  table_sort(thresholds, function(left, right)
    return left.value < right.value
  end)

  return threshold
end

function AuraWidget.RemoveStackColorThreshold(config, index)
  local thresholds = AuraWidget.EnsureStackColorThresholds(config)
  if not thresholds or not thresholds[index] then
    return false
  end

  table.remove(thresholds, index)
  return true
end

local function ResolveStackColorThresholdColor(threshold, classColor)
  if threshold.colorMode == "CLASS" then
    classColor = classColor or {}
    return classColor.r or classColor[1] or 1,
      classColor.g or classColor[2] or 1,
      classColor.b or classColor[3] or 1,
      classColor.a or classColor[4] or 1
  end

  local color = threshold.color or {}
  return color[1] or color.r or 1,
    color[2] or color.g or 1,
    color[3] or color.b or 1,
    color[4] or color.a or 1
end

local function EnsureApplicationThresholdOverlay(parts, index)
  local overlays = parts.applicationThresholds
  local overlay = overlays[index]
  if overlay then
    return overlay
  end

  local mirror = parts.applicationThresholdMirror or parts.applicationBar
  overlay = CreateFrame("StatusBar", nil, overlays[index - 1] or mirror)
  overlay:SetAllPoints(mirror:GetStatusBarTexture())
  overlay:SetFrameLevel(mirror:GetFrameLevel() + 2)
  overlay:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  overlay:SetMinMaxValues(0, 1)
  overlay:SetValue(0)
  overlay:Hide()

  overlays[index] = overlay
  return overlay
end

local function ConfigureApplicationThresholdOverlay(
  parts,
  overlay,
  threshold,
  thresholdIndex,
  texturePath,
  orientation,
  reverseFill,
  classColor
)
  local mirror = parts.applicationThresholdMirror or parts.applicationBar
  local thresholdValue = tonumber(threshold.value) or 1
  local r, g, b, a = ResolveStackColorThresholdColor(threshold, classColor)

  overlay:SetStatusBarTexture(texturePath or "Interface\\Buttons\\WHITE8X8")
  overlay:SetOrientation(orientation or "HORIZONTAL")
  overlay:SetReverseFill(reverseFill == true)

  local texture = overlay:GetStatusBarTexture()
  texture:SetVertexColor(r, g, b, a)
  texture:SetDrawLayer("ARTWORK", thresholdIndex)

  overlay:SetFrameLevel(mirror:GetFrameLevel() + 2)
  overlay:ClearAllPoints()
  overlay:SetAllPoints(mirror:GetStatusBarTexture())
  overlay:SetMinMaxValues(thresholdValue - 1, thresholdValue)
  overlay:Show()
end

AuraWidget.FeedApplicationThresholds = FeedApplicationThresholds

function AuraWidget.SetApplicationThresholdHost(parts, parent)
  parts.applicationThresholdMirrorIsVisible = nil
  local mirror = parts.applicationThresholdMirror
  if not mirror then
    mirror = CreateFrame("StatusBar", nil, parent)
    mirror:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    mirror:SetStatusBarColor(1, 1, 1, 0)
    mirror:SetMinMaxValues(0, 1)
    mirror:SetValue(0)
    parts.applicationThresholdMirror = mirror
  elseif mirror:GetParent() ~= parent then
    mirror:SetParent(parent)
  end

  local overlays = parts.applicationThresholds
  for index = 1, #overlays do
    overlays[index]:SetParent(overlays[index - 1] or mirror)
  end

  mirror:Show()
  return mirror
end

function AuraWidget.SetApplicationThresholdBar(parts, statusBar)
  parts.applicationThresholdMirror = statusBar
  parts.applicationThresholdMirrorIsVisible = true

  local overlays = parts.applicationThresholds
  for index = 1, #overlays do
    overlays[index]:SetParent(overlays[index - 1] or statusBar)
  end

  statusBar:Show()
  return statusBar
end

function AuraWidget.ClearApplicationThresholdBar(parts)
  if parts.applicationThresholdMirrorIsVisible ~= true then
    return
  end

  local mirror = parts.applicationThresholdMirror
  if mirror then
    mirror:SetValue(0)
    mirror:Hide()
  end

  parts.applicationThresholdMirror = nil
  parts.applicationThresholdMirrorIsVisible = nil

  local overlays = parts.applicationThresholds
  for index = 1, #overlays do
    overlays[index]:SetParent(overlays[index - 1] or parts.applicationBar)
  end
end

function AuraWidget.ConfigureApplicationThresholdSource(
  parts,
  spellIDs,
  cooldownID,
  viewerKey,
  unit
)
  local spellSet, orderedSpellIDs = BuildApplicationThresholdSpellSet(spellIDs)
  local source = parts.applicationThresholdSource or {}
  local resolvedCooldownID = IsUsableSpellID(cooldownID) and cooldownID or nil
  local resolvedViewerKey = viewerKey or "BuffBarCooldownViewer"
  local resolvedUnit = unit or "player"
  local sourceChanged = source.cooldownID ~= resolvedCooldownID
    or source.viewerKey ~= resolvedViewerKey
    or source.unit ~= resolvedUnit
    or #(source.orderedSpellIDs or {}) ~= #orderedSpellIDs

  if not sourceChanged then
    for index = 1, #orderedSpellIDs do
      if source.orderedSpellIDs[index] ~= orderedSpellIDs[index] then
        sourceChanged = true
        break
      end
    end
  end

  source.spellSet = spellSet
  source.orderedSpellIDs = orderedSpellIDs
  source.cooldownID = resolvedCooldownID
  source.viewerKey = resolvedViewerKey
  source.unit = resolvedUnit
  if sourceChanged then
    source.child = nil
    source.childCooldownID = nil
  end
  parts.applicationThresholdSource = source

  EnsureApplicationThresholdViewerHook(source.viewerKey)
  if parts.applicationThresholdMirrorIsVisible == true
  then
    applicationThresholdTracks[parts] = source
    WakeApplicationThresholdTicker()
  end
end

function AuraWidget.DisableApplicationThresholdSource(parts)
  applicationThresholdTracks[parts] = nil
  parts.applicationThresholdSource = nil
  if parts.applicationThresholdMirror then
    parts.applicationThresholdMirror:SetValue(0)
  end
  FeedApplicationThresholds(parts, 0)

  if not next(applicationThresholdTracks) then
    if applicationThresholdTickFrame then
      applicationThresholdTickFrame:Hide()
    end
    applicationThresholdWakeFrame:UnregisterAllEvents()
  end
end

function AuraWidget.ConfigureApplicationThresholds(
  parts,
  thresholds,
  texturePath,
  orientation,
  reverseFill,
  classColor,
  maximum
)
  maximum = math.floor((tonumber(maximum) or 1) + 0.5)
  maximum = math.max(1, maximum)

  local active = {}
  if type(thresholds) == "table" then
    for index = 1, #thresholds do
      local threshold = thresholds[index]
      local value = threshold and tonumber(threshold.value)

      if threshold
        and threshold.enabled == true
        and value
        and value >= 1
        and value <= maximum
      then
        active[#active + 1] = threshold
      end
    end
  end

  table_sort(active, function(left, right)
    return left.value < right.value
  end)

  local overlays = parts.applicationThresholds
  local overlayCount = 0
  local mirror = parts.applicationThresholdMirror
  if mirror then
    mirror:SetStatusBarTexture(texturePath or "Interface\\Buttons\\WHITE8X8")
    mirror:SetOrientation(orientation or "HORIZONTAL")
    mirror:SetReverseFill(reverseFill == true)
    if parts.applicationThresholdMirrorIsVisible ~= true then
      mirror:SetStatusBarColor(1, 1, 1, 0)
      mirror:SetFrameLevel(parts.applicationBar:GetFrameLevel())
    end
    mirror:SetMinMaxValues(0, maximum)
    mirror:Show()
  end

  for thresholdIndex = 1, #active do
    overlayCount = thresholdIndex
    ConfigureApplicationThresholdOverlay(
      parts,
      EnsureApplicationThresholdOverlay(parts, thresholdIndex),
      active[thresholdIndex],
      thresholdIndex,
      texturePath,
      orientation,
      reverseFill,
      classColor
    )
  end

  for index = overlayCount + 1, #overlays do
    overlays[index]:Hide()
  end

  parts.applicationThresholdCount = overlayCount
  parts.applicationThresholdLayerCount = overlayCount
  parts.applicationThresholdMaximum = maximum
  parts.applicationThresholdsDirty = true

  local source = parts.applicationThresholdSource
  if source and parts.applicationThresholdMirrorIsVisible == true then
    applicationThresholdTracks[parts] = source
    WakeApplicationThresholdTicker()
  end
end

function AuraWidget.ConfigureApplicationThresholdBarSource(parts)
  parts.applicationThresholdBarSourceEnabled = true

  if parts.applicationThresholdBarSource ~= parts.applicationBar then
    parts.applicationThresholdBarSource = parts.applicationBar
    hooksecurefunc(parts.applicationBar, "SetValue", function(_, value)
      if parts.applicationThresholdBarSourceEnabled == true then
        FeedApplicationThresholds(parts, value)
      end
    end)
  end

  local currentValue = parts.applicationBar:GetValue()
  if not issecretvalue(currentValue) and currentValue ~= nil then
    FeedApplicationThresholds(parts, currentValue)
  end
end

function AuraWidget.DisableApplicationThresholdBarSource(parts)
  parts.applicationThresholdBarSourceEnabled = nil
end

local SLOT_GLOW_PIXEL_TEX = [[Interface\Buttons\WHITE8X8]]
local SLOT_GLOW_SHINE_TEX = [[Interface\Artifacts\Artifacts]]
local SLOT_GLOW_SHINE_COORDS = { 0.8115234375, 0.9169921875, 0.8798828125, 0.9853515625 }
local SLOT_GLOW_PROC_ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook"
local SLOT_GLOW_PIXEL_COUNT = 8
local SLOT_GLOW_PIXEL_LENGTH = 12
local SLOT_GLOW_PIXEL_THICKNESS = 2
local SLOT_GLOW_PIXEL_PERIOD = 4
local SLOT_GLOW_AUTOCAST_COUNT = 8
local SLOT_GLOW_AUTOCAST_SIZES = { 7, 6, 5, 4 }
local SLOT_GLOW_AUTOCAST_PERIOD = 4
local SLOT_GLOW_PROC_DURATION = 1
local SLOT_GLOW_DIRS = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }

local function SetSlotGlowColor(texture, color)
  texture:SetVertexColor(color[1], color[2], color[3], color[4])
end

local function NormalizeSlotGlowSize(value)
  return math.max(1, tonumber(value) or 1)
end

local function NormalizeSlotGlowOptions(options)
  options = type(options) == "table" and options or {}

  local pixelCount = math.floor((tonumber(options.pixelCount) or SLOT_GLOW_PIXEL_COUNT) + 0.5)
  pixelCount = math.max(2, math.min(SLOT_GLOW_PIXEL_COUNT, pixelCount))

  local pixelThickness = tonumber(options.pixelThickness) or SLOT_GLOW_PIXEL_THICKNESS
  pixelThickness = math.max(1, math.min(8, pixelThickness))

  local pixelLength = tonumber(options.pixelLength) or SLOT_GLOW_PIXEL_LENGTH
  pixelLength = math.max(1, pixelLength)

  local pixelPeriod = tonumber(options.pixelPeriod) or SLOT_GLOW_PIXEL_PERIOD
  pixelPeriod = math.max(0.1, pixelPeriod)

  local autocastScale = tonumber(options.autocastScale) or 1
  autocastScale = math.max(0.1, autocastScale)

  local autocastPeriod = tonumber(options.autocastPeriod) or SLOT_GLOW_AUTOCAST_PERIOD
  autocastPeriod = math.max(0.1, autocastPeriod)

  local procDuration = tonumber(options.procDuration) or SLOT_GLOW_PROC_DURATION
  procDuration = math.max(0.05, procDuration)

  return {
    pixelCount = pixelCount,
    pixelThickness = pixelThickness,
    pixelLength = pixelLength,
    pixelPeriod = pixelPeriod,
    autocastScale = autocastScale,
    autocastPeriod = autocastPeriod,
    procDuration = procDuration,
  }
end

local function AnchorSlotGlowTexture(texture, host, pos, width, height)
  local topRight = height + width
  local bottomRight = topRight + height

  texture:ClearAllPoints()
  if pos >= bottomRight then
    texture:SetPoint("CENTER", host, "BOTTOMRIGHT", -(pos - bottomRight), 0)
  elseif pos >= topRight then
    texture:SetPoint("CENTER", host, "TOPRIGHT", 0, -(pos - topRight))
  elseif pos >= height then
    texture:SetPoint("CENTER", host, "TOPLEFT", pos - height, 0)
  else
    texture:SetPoint("CENTER", host, "BOTTOMLEFT", 0, pos)
  end
end

local function ConfigureSlotGlowOrbit(entry, pos, width, height, period)
  local perimeter = 2 * (width + height)
  local lengths = { height, width, height, width }
  local leg = 1
  local into = pos % perimeter

  for index = 1, 4 do
    if into < lengths[index] then
      leg = index
      break
    end
    into = into - lengths[index]
  end

  entry.group:Stop()

  local remaining = perimeter
  local index = leg
  local skip = into
  local animationIndex = 1

  while remaining > 0.0001 and animationIndex <= #entry.moves do
    local distance = lengths[index] - skip
    skip = 0
    if distance > remaining then
      distance = remaining
    end

    local direction = SLOT_GLOW_DIRS[index]
    local move = entry.moves[animationIndex]
    move:SetOffset(direction[1] * distance, direction[2] * distance)
    move:SetDuration(period * distance / perimeter)

    remaining = remaining - distance
    animationIndex = animationIndex + 1
    index = index % 4 + 1
  end

  for moveIndex = animationIndex, #entry.moves do
    local move = entry.moves[moveIndex]
    move:SetOffset(0, 0)
    move:SetDuration(0.001)
  end

  entry.group:Play()
end

local function CreateSlotPixelGlow(parent, color)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local backdrop = {}
  for index = 1, 4 do
    local edge = frame:CreateTexture(nil, "ARTWORK", nil, 6)
    edge:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    backdrop[index] = edge
  end

  backdrop[1]:SetHeight(1)
  backdrop[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  backdrop[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  backdrop[2]:SetHeight(1)
  backdrop[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  backdrop[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  backdrop[3]:SetWidth(1)
  backdrop[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  backdrop[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  backdrop[4]:SetWidth(1)
  backdrop[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  backdrop[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  local edges = {}
  local textures = {}
  for edgeIndex = 1, 4 do
    local clip = CreateFrame("Frame", nil, frame)
    clip:SetClipsChildren(true)

    local mover = CreateFrame("Frame", nil, clip)
    mover:SetAllPoints(clip)

    local edgeTextures = {}
    for textureIndex = 1, SLOT_GLOW_PIXEL_COUNT + 2 do
      local texture = mover:CreateTexture(nil, "ARTWORK", nil, 7)
      texture:SetTexture(SLOT_GLOW_PIXEL_TEX)
      SetSlotGlowColor(texture, color)
      edgeTextures[textureIndex] = texture
      textures[#textures + 1] = texture
    end

    local group = mover:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    local move = group:CreateAnimation("Translation")
    move:SetSmoothing("NONE")

    edges[edgeIndex] = {
      clip = clip,
      mover = mover,
      textures = edgeTextures,
      group = group,
      move = move,
    }
  end

  return {
    frame = frame,
    edges = edges,
    textures = textures,
  }
end

local function ConfigureSlotPixelGlow(pixel, width, height, options)
  local perimeter = 2 * (width + height)
  local spacing = perimeter / options.pixelCount
  local duration = options.pixelPeriod / options.pixelCount
  local thickness = options.pixelThickness
  local length = math.min(options.pixelLength, math.max(width, height))
  local edgeData = {
    { start = 0, len = height, vertical = true, from = "BOTTOM", point = "LEFT", dx = 0, dy = spacing },
    { start = height, len = width, vertical = false, from = "LEFT", point = "TOP", dx = spacing, dy = 0 },
    { start = height + width, len = height, vertical = true, from = "TOP", point = "RIGHT", dx = 0, dy = -spacing },
    { start = height + width + height, len = width, vertical = false, from = "RIGHT", point = "BOTTOM", dx = -spacing, dy = 0 },
  }

  for edgeIndex = 1, 4 do
    local edge = pixel.edges[edgeIndex]
    local data = edgeData[edgeIndex]
    local clip = edge.clip

    edge.group:Stop()
    clip:ClearAllPoints()
    clip:SetSize(data.vertical and thickness or data.len, data.vertical and data.len or thickness)
    clip:SetPoint("CENTER", pixel.frame, data.point, 0, 0)

    local first = ((-data.start) % spacing) - spacing
    local count = math.ceil(data.len / spacing) + 2

    for textureIndex = 1, #edge.textures do
      local texture = edge.textures[textureIndex]
      if textureIndex <= count then
        local at = first + (textureIndex - 1) * spacing
        texture:ClearAllPoints()
        texture:SetSize(data.vertical and thickness or length, data.vertical and length or thickness)
        if data.vertical then
          texture:SetPoint("CENTER", edge.mover, data.from, 0, data.from == "BOTTOM" and at or -at)
        else
          texture:SetPoint("CENTER", edge.mover, data.from, data.from == "LEFT" and at or -at, 0)
        end
        texture:Show()
      else
        texture:Hide()
      end
    end

    edge.move:SetOffset(data.dx, data.dy)
    edge.move:SetDuration(duration)
    edge.group:Play()
  end
end

local function CreateSlotAutocastGlow(parent, color)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local entries = {}
  local textures = {}
  for layer = 1, 4 do
    for index = 1, SLOT_GLOW_AUTOCAST_COUNT do
      local texture = frame:CreateTexture(nil, "ARTWORK", nil, 7)
      texture:SetTexture(SLOT_GLOW_SHINE_TEX)
      texture:SetTexCoord(
        SLOT_GLOW_SHINE_COORDS[1],
        SLOT_GLOW_SHINE_COORDS[2],
        SLOT_GLOW_SHINE_COORDS[3],
        SLOT_GLOW_SHINE_COORDS[4]
      )
      texture:SetDesaturated(true)
      SetSlotGlowColor(texture, color)

      local group = texture:CreateAnimationGroup()
      group:SetLooping("REPEAT")
      local moves = {}
      for moveIndex = 1, 5 do
        local move = group:CreateAnimation("Translation")
        move:SetOrder(moveIndex)
        move:SetSmoothing("NONE")
        moves[moveIndex] = move
      end

      entries[#entries + 1] = {
        texture = texture,
        group = group,
        moves = moves,
        layer = layer,
        index = index,
      }
      textures[#textures + 1] = texture
    end
  end

  return {
    frame = frame,
    entries = entries,
    textures = textures,
  }
end

local function ConfigureSlotAutocastGlow(autocast, width, height, options)
  local perimeter = 2 * (width + height)
  local spacing = perimeter / SLOT_GLOW_AUTOCAST_COUNT

  for entryIndex = 1, #autocast.entries do
    local entry = autocast.entries[entryIndex]
    local size = SLOT_GLOW_AUTOCAST_SIZES[entry.layer] * options.autocastScale
    local period = options.autocastPeriod * entry.layer
    local pos = (spacing * entry.index) % perimeter

    entry.texture:SetSize(size, size)
    AnchorSlotGlowTexture(entry.texture, autocast.frame, pos, width, height)
    ConfigureSlotGlowOrbit(entry, pos, width, height, period)
  end
end

local function CreateSlotProcGlow(parent, color)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local texture = frame:CreateTexture(nil, "ARTWORK", nil, 7)
  texture:SetAtlas(SLOT_GLOW_PROC_ATLAS)
  texture:SetBlendMode("ADD")
  texture:SetDesaturated(true)
  texture:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 8)
  texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 8, -8)
  SetSlotGlowColor(texture, color)

  local group = texture:CreateAnimationGroup()
  group:SetLooping("REPEAT")
  local flipbook = group:CreateAnimation("FlipBook")
  flipbook:SetFlipBookRows(6)
  flipbook:SetFlipBookColumns(5)
  flipbook:SetFlipBookFrames(30)
  flipbook:SetFlipBookFrameWidth(0)
  flipbook:SetFlipBookFrameHeight(0)

  return {
    frame = frame,
    texture = texture,
    textures = { texture },
    group = group,
    flipbook = flipbook,
  }
end

local function ConfigureSlotProcGlow(proc, options)
  proc.group:Stop()
  proc.flipbook:SetDuration(options.procDuration)
  proc.group:Play()
end

function AuraWidget.CreateSlotGlow(button, width, height, style, color, options)
  local root = CreateFrame("Frame", nil, button)
  root:SetAllPoints(button)
  root:SetFrameLevel(button:GetFrameLevel() + 8)
  root:EnableMouse(false)

  local pixel = CreateSlotPixelGlow(root, color)
  local autocast = CreateSlotAutocastGlow(root, color)
  local proc = CreateSlotProcGlow(root, color)
  local glow = {
    root = root,
    pixel = pixel,
    autocast = autocast,
    proc = proc,
    styles = {
      PIXEL = pixel.frame,
      AUTOCAST = autocast.frame,
      PROC = proc.frame,
    },
  }

  AuraWidget.ConfigureSlotGlow(glow, width, height, style, color, options)
  return glow
end

function AuraWidget.ConfigureSlotGlow(glow, width, height, style, color, options)
  width = NormalizeSlotGlowSize(width)
  height = NormalizeSlotGlowSize(height)
  options = NormalizeSlotGlowOptions(options)

  for _, edge in ipairs(glow.pixel.edges) do
    edge.group:Stop()
  end
  for _, entry in ipairs(glow.autocast.entries) do
    entry.group:Stop()
  end
  glow.proc.group:Stop()

  if style == "PIXEL" then
    ConfigureSlotPixelGlow(glow.pixel, width, height, options)
  elseif style == "AUTOCAST" then
    ConfigureSlotAutocastGlow(glow.autocast, width, height, options)
  elseif style == "PROC" then
    ConfigureSlotProcGlow(glow.proc, options)
  end

  for name, frame in pairs(glow.styles) do
    frame:SetAlpha(name == style and 1 or 0)
  end

  for _, texture in ipairs(glow.pixel.textures) do
    SetSlotGlowColor(texture, color)
  end
  for _, texture in ipairs(glow.autocast.textures) do
    SetSlotGlowColor(texture, color)
  end
  for _, texture in ipairs(glow.proc.textures) do
    SetSlotGlowColor(texture, color)
  end
end

function AuraWidget.BindApplicationDurationButton(button, parts)
  parts = parts or button.__puiAuraApplicationDurationParts or {}
  if parts.__puiBoundButton == button then
    return parts
  end

  button.__puiAuraApplicationDurationParts = parts
  parts.__puiBoundButton = button
  parts.button = button
  parts.applicationBase = button.PUIApplicationBase
  parts.applicationBar = button.PUIApplicationBar
  parts.applicationThresholds = parts.applicationThresholds or {}
  parts.applicationHolder = button.PUIApplicationHolder
  parts.applicationText = parts.applicationHolder.PUIApplicationCount
  parts.durationBar = button.PUIDurationBar
  parts.durationTextHolder = button.PUIDurationTextHolder
  parts.durationText = parts.durationTextHolder.PUIDurationText
  parts.durationCooldown = button.PUIDurationCooldown
  parts.icon = button.PUIIcon

  parts.applicationText:SetDrawLayer("OVERLAY", 7)
  parts.durationText:SetDrawLayer("OVERLAY", 7)
  parts.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  parts.icon:SetDrawLayer("ARTWORK", -1)
  parts.durationCooldown:SetDrawEdge(false)
  parts.durationCooldown:SetDrawBling(false)
  parts.durationCooldown:SetUseCircularEdge(false)
  parts.durationCooldown:SetDrawSwipe(true)

  return parts
end

function AuraWidget.BindIconButton(button)
  local parts = button.__puiAuraIconParts
  if parts then
    return parts
  end

  local textHolder = button.PUITextHolder
  parts = {
    button = button,
    icon = button.PUIIcon,
    cooldown = button.PUIDurationCooldown,
    textHolder = textHolder,
    count = textHolder.PUIApplicationCount,
    duration = textHolder.PUIDurationText,
  }
  button.__puiAuraIconParts = parts

  parts.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  parts.cooldown:SetDrawEdge(false)
  parts.cooldown:SetDrawBling(false)
  parts.cooldown:SetHideCountdownNumbers(true)
  parts.cooldown:SetReverse(true)
  parts.cooldown:SetSwipeColor(0, 0, 0, 0.65)
  parts.textHolder:SetFrameLevel(parts.cooldown:GetFrameLevel() + 1)

  button.Icon = parts.icon
  button.Cooldown = parts.cooldown
  button.Count = parts.count
  button.Duration = parts.duration

  button:SetIcon(parts.icon)
  button:SetDurationCooldown(parts.cooldown)
  button:SetApplicationCount(parts.count, {})

  return parts
end

function AuraWidget.ConfigureApplicationBar(parts, maxApplications, interpolation)
  if parts.applicationBarEnabled
    and parts.maxApplications == maxApplications
    and parts.applicationInterpolation == interpolation
    and parts.applicationThresholdsDirty ~= true
  then
    parts.applicationBar:Show()
    local source = parts.applicationThresholdSource
    if source and parts.applicationThresholdMirrorIsVisible == true then
      applicationThresholdTracks[parts] = source
      WakeApplicationThresholdTicker()
    end
    return
  end

  if parts.applicationBarEnabled then
    parts.button:ClearApplicationBar()
  end

  parts.applicationBarEnabled = true
  parts.maxApplications = maxApplications
  parts.applicationInterpolation = interpolation
  parts.applicationThresholdsDirty = nil
  parts.button:SetApplicationBar(parts.applicationBar, {
    maxApplications = maxApplications,
    interpolation = interpolation,
  })
  local source = parts.applicationThresholdSource
  if source and parts.applicationThresholdMirrorIsVisible == true then
    applicationThresholdTracks[parts] = source
    WakeApplicationThresholdTicker()
  end
  parts.applicationBar:Show()
end

function AuraWidget.DisableApplicationBar(parts)
  if parts.applicationBarEnabled then
    parts.button:ClearApplicationBar()
    parts.applicationBarEnabled = false
    parts.maxApplications = nil
    parts.applicationInterpolation = nil
  end

  parts.applicationThresholdsDirty = nil

  parts.applicationBase:Hide()
  parts.applicationBar:Hide()
  parts.applicationThresholdCount = 0
  parts.applicationThresholdLayerCount = 0
  applicationThresholdTracks[parts] = nil
  if parts.applicationThresholdMirror then
    parts.applicationThresholdMirror:SetValue(0)
    parts.applicationThresholdMirror:Hide()
  end

  if not next(applicationThresholdTracks) then
    if applicationThresholdTickFrame then
      applicationThresholdTickFrame:Hide()
    end
    applicationThresholdWakeFrame:UnregisterAllEvents()
  end

  local segments = parts.applicationThresholds
  for index = 1, #segments do
    segments[index]:Hide()
  end
end

function AuraWidget.ConfigureApplicationCount(parts, formatter)
  if not parts.applicationCountEnabled
    or parts.applicationFormatterBinding ~= formatter
  then
    if parts.applicationCountEnabled then
      parts.button:ClearApplicationCount()
    end

    parts.applicationCountEnabled = true
    parts.applicationFormatterBinding = formatter
    parts.button:SetApplicationCount(parts.applicationText, {
      formatter = formatter,
    })
  end

  parts.applicationHolder:Show()
  parts.applicationText:Show()
end

function AuraWidget.DisableApplicationCount(parts)
  if parts.applicationCountEnabled then
    parts.button:ClearApplicationCount()
    parts.applicationCountEnabled = false
    parts.applicationFormatterBinding = nil
  end

  parts.applicationText:Hide()
  parts.applicationHolder:Hide()
end

function AuraWidget.ConfigureDurationBar(parts, interpolation, direction)
  if not parts.durationBarEnabled
    or parts.durationInterpolation ~= interpolation
    or parts.durationDirection ~= direction
  then
    if parts.durationBarEnabled then
      parts.button:ClearDurationBar()
    end

    parts.durationBarEnabled = true
    parts.durationInterpolation = interpolation
    parts.durationDirection = direction
    parts.button:SetDurationBar(parts.durationBar, {
      interpolation = interpolation,
      direction = direction,
    })
  end

  parts.durationBar:Show()
end

function AuraWidget.DisableDurationBar(parts)
  if parts.durationBarEnabled then
    parts.button:ClearDurationBar()
    parts.durationBarEnabled = false
    parts.durationInterpolation = nil
    parts.durationDirection = nil
  end

  parts.durationBar:Hide()
end

function AuraWidget.ConfigureDurationText(parts, formatter)
  if not parts.durationTextEnabled
    or parts.durationFormatterBinding ~= formatter
  then
    if parts.durationTextEnabled then
      parts.button:ClearDurationText()
    end

    parts.durationTextEnabled = true
    parts.durationFormatterBinding = formatter
    parts.button:SetDurationText(parts.durationText, {
      textFormatter = formatter,
    })
  end

  parts.durationTextHolder:Show()
  parts.durationText:Show()
end

function AuraWidget.DisableDurationText(parts)
  if parts.durationTextEnabled then
    parts.button:ClearDurationText()
    parts.durationTextEnabled = false
    parts.durationFormatterBinding = nil
  end

  parts.durationText:Hide()
  parts.durationTextHolder:Hide()
end

function AuraWidget.ConfigureIcon(parts)
  if not parts.iconEnabled then
    parts.iconEnabled = true
    parts.button:SetIcon(parts.icon)
  end

  parts.icon:Show()
end

function AuraWidget.DisableIcon(parts)
  if parts.iconEnabled then
    parts.button:ClearIcon()
    parts.iconEnabled = false
  end

  parts.icon:Hide()
end

function AuraWidget.ConfigureDurationCooldown(parts)
  if not parts.durationCooldownEnabled then
    parts.durationCooldownEnabled = true
    parts.button:SetDurationCooldown(parts.durationCooldown)
  end

  parts.durationCooldown:Show()
end

function AuraWidget.DisableDurationCooldown(parts)
  if parts.durationCooldownEnabled then
    parts.button:ClearDurationCooldown()
    parts.durationCooldownEnabled = false
  end

  parts.durationCooldown:Hide()
end

local P = select(1, ns.Pleebug:DropIn(AuraWidget, { name = "Core.AuraWidget" }))
AuraWidget.BindApplicationDurationButton = P:Def(
  "AuraWidget.BindApplicationDurationButton",
  AuraWidget.BindApplicationDurationButton
)
AuraWidget.BindIconButton = P:Def("AuraWidget.BindIconButton", AuraWidget.BindIconButton)
NormalizeStackColorThreshold = P:Def(
  "AuraWidget.NormalizeStackColorThreshold",
  NormalizeStackColorThreshold
)
AuraWidget.EnsureStackColorThresholds = P:Def(
  "AuraWidget.EnsureStackColorThresholds",
  AuraWidget.EnsureStackColorThresholds
)
AuraWidget.AddStackColorThreshold = P:Def(
  "AuraWidget.AddStackColorThreshold",
  AuraWidget.AddStackColorThreshold
)
AuraWidget.RemoveStackColorThreshold = P:Def(
  "AuraWidget.RemoveStackColorThreshold",
  AuraWidget.RemoveStackColorThreshold
)
ResolveStackColorThresholdColor = P:Def(
  "AuraWidget.ResolveStackColorThresholdColor",
  ResolveStackColorThresholdColor
)
EnsureApplicationThresholdOverlay = P:Def(
  "AuraWidget.EnsureApplicationThresholdOverlay",
  EnsureApplicationThresholdOverlay
)
ConfigureApplicationThresholdOverlay = P:Def(
  "AuraWidget.ConfigureApplicationThresholdOverlay",
  ConfigureApplicationThresholdOverlay
)
FeedApplicationThresholds = P:SecDef(
  "AuraWidget.FeedApplicationThresholds",
  AuraWidget,
  "FeedApplicationThresholds"
)
AuraWidget.ConfigureApplicationThresholds = P:Def(
  "AuraWidget.ConfigureApplicationThresholds",
  AuraWidget.ConfigureApplicationThresholds
)
AuraWidget.ConfigureApplicationThresholdBarSource = P:Def(
  "AuraWidget.ConfigureApplicationThresholdBarSource",
  AuraWidget.ConfigureApplicationThresholdBarSource
)
AuraWidget.DisableApplicationThresholdBarSource = P:Def(
  "AuraWidget.DisableApplicationThresholdBarSource",
  AuraWidget.DisableApplicationThresholdBarSource
)
AuraWidget.CreateSlotGlow = P:Def("AuraWidget.CreateSlotGlow", AuraWidget.CreateSlotGlow)
AuraWidget.ConfigureSlotGlow = P:Def("AuraWidget.ConfigureSlotGlow", AuraWidget.ConfigureSlotGlow)
AuraWidget.SetApplicationThresholdHost = P:Def(
  "AuraWidget.SetApplicationThresholdHost",
  AuraWidget.SetApplicationThresholdHost
)
AuraWidget.SetApplicationThresholdBar = P:Def(
  "AuraWidget.SetApplicationThresholdBar",
  AuraWidget.SetApplicationThresholdBar
)
AuraWidget.ClearApplicationThresholdBar = P:Def(
  "AuraWidget.ClearApplicationThresholdBar",
  AuraWidget.ClearApplicationThresholdBar
)
AuraWidget.ConfigureApplicationThresholdSource = P:Def(
  "AuraWidget.ConfigureApplicationThresholdSource",
  AuraWidget.ConfigureApplicationThresholdSource
)
AuraWidget.DisableApplicationThresholdSource = P:Def(
  "AuraWidget.DisableApplicationThresholdSource",
  AuraWidget.DisableApplicationThresholdSource
)
AuraWidget.ConfigureApplicationBar = P:Def(
  "AuraWidget.ConfigureApplicationBar",
  AuraWidget.ConfigureApplicationBar
)
AuraWidget.DisableApplicationBar = P:Def(
  "AuraWidget.DisableApplicationBar",
  AuraWidget.DisableApplicationBar
)
AuraWidget.ConfigureApplicationCount = P:Def(
  "AuraWidget.ConfigureApplicationCount",
  AuraWidget.ConfigureApplicationCount
)
AuraWidget.DisableApplicationCount = P:Def(
  "AuraWidget.DisableApplicationCount",
  AuraWidget.DisableApplicationCount
)
AuraWidget.ConfigureDurationBar = P:Def(
  "AuraWidget.ConfigureDurationBar",
  AuraWidget.ConfigureDurationBar
)
AuraWidget.DisableDurationBar = P:Def("AuraWidget.DisableDurationBar", AuraWidget.DisableDurationBar)
AuraWidget.ConfigureDurationText = P:Def(
  "AuraWidget.ConfigureDurationText",
  AuraWidget.ConfigureDurationText
)
AuraWidget.DisableDurationText = P:Def(
  "AuraWidget.DisableDurationText",
  AuraWidget.DisableDurationText
)
AuraWidget.ConfigureIcon = P:Def("AuraWidget.ConfigureIcon", AuraWidget.ConfigureIcon)
AuraWidget.DisableIcon = P:Def("AuraWidget.DisableIcon", AuraWidget.DisableIcon)
AuraWidget.ConfigureDurationCooldown = P:Def(
  "AuraWidget.ConfigureDurationCooldown",
  AuraWidget.ConfigureDurationCooldown
)
AuraWidget.DisableDurationCooldown = P:Def(
  "AuraWidget.DisableDurationCooldown",
  AuraWidget.DisableDurationCooldown
)
