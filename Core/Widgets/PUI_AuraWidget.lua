local _, ns = ...

local AuraWidget = {}
ns.AuraWidget = AuraWidget

local CreateFrame = CreateFrame
local table_sort = table.sort

local MAX_STACK_COLOR_THRESHOLD = 30
local STACK_COLOR_THRESHOLD_DEFAULT_COLOR = { 1, 0.82, 0, 1 }

local applicationThresholdTracks = setmetatable({}, { __mode = "k" })
local applicationThresholdViewerHooks = setmetatable({}, { __mode = "k" })
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

local function ApplicationThresholdSourceWantsSpellID(source, spellID)
  return IsUsableSpellID(spellID) and source.spellSet[spellID] == true
end

local function ApplicationThresholdInfoMatches(info, source)
  if not info then
    return false
  end

  if ApplicationThresholdSourceWantsSpellID(source, info.overrideSpellID)
    or ApplicationThresholdSourceWantsSpellID(source, info.overrideTooltipSpellID)
    or ApplicationThresholdSourceWantsSpellID(source, info.spellID)
  then
    return true
  end

  local linkedSpellIDs = info.linkedSpellIDs
  if linkedSpellIDs then
    for _, spellID in ipairs(linkedSpellIDs) do
      if ApplicationThresholdSourceWantsSpellID(source, spellID) then
        return true
      end
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

  local getAuraSpellID = frame.GetAuraSpellID
  if type(getAuraSpellID) == "function" then
    local spellID = getAuraSpellID(frame)
    if IsUsableSpellID(spellID) then
      return spellID
    end
  end

  local getSpellID = frame.GetSpellID
  if type(getSpellID) == "function" then
    local spellID = getSpellID(frame)
    if IsUsableSpellID(spellID) then
      return spellID
    end
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

  local getCooldownInfo = C_CooldownViewer
    and C_CooldownViewer.GetCooldownViewerCooldownInfo
  if not getCooldownInfo then
    return false
  end

  local info = getCooldownInfo(cooldownID)
  if ApplicationThresholdInfoMatches(info, source) then
    return true
  end

  return ApplicationThresholdSourceWantsSpellID(
    source,
    GetApplicationThresholdFrameSpellID(frame)
  )
end

local function FindApplicationThresholdChild(source)
  local viewer = _G[source.viewerKey]
  if not viewer or not viewer.itemFramePool then
    return nil
  end

  -- A clean CDM identity can validate a binding. During the restricted window,
  -- retain the same pooled child only while it still serves the original slot.
  local child = source.child
  if child
    and child.cooldownID == source.childCooldownID
    and ApplicationThresholdFrameHasSourceUnit(child, source)
  then
    for frame in viewer.itemFramePool:EnumerateActive() do
      if frame == child then
        return child
      end
    end
  end

  source.child = nil
  source.childCooldownID = nil

  for frame in viewer.itemFramePool:EnumerateActive() do
    if ApplicationThresholdFrameHasSourceUnit(frame, source)
      and ApplicationThresholdSourceWantsSpellID(
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
  for frame in viewer.itemFramePool:EnumerateActive() do
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

  for parts, source in pairs(applicationThresholdTracks) do
    if parts.applicationThresholdMirrorIsVisible ~= true then
      applicationThresholdTracks[parts] = nil
    else
      local child = FindApplicationThresholdChild(source)
      local active
      if child then
        if child.IsActive then
          active = child:IsActive()
        elseif child.IsShown then
          active = child:IsShown()
        end
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

      if applicationsUpdated == true
        or (not issecretvalue(active) and active == true)
      then
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
