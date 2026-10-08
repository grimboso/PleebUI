local _, ns = ...

local AuraWidget = {}
ns.AuraWidget = AuraWidget

local CreateFrame = CreateFrame
local table_sort = table.sort

local USE_NATIVE_APPLICATION_THRESHOLDS = select(4, GetBuildInfo()) >= 120105
local applicationThresholdSources = {}
local applicationThresholdSourceIndex = {}
local applicationThresholdPolicyDirty = false
local applicationThresholdFrames = setmetatable({}, { __mode = "k" })
local applicationThresholdViewers = setmetatable({}, { __mode = "k" })
local applicationThresholdPending = {}
local applicationThresholdParents = setmetatable({}, { __mode = "k" })
local applicationThresholdWork = CreateFrame("Frame")
applicationThresholdWork:Hide()
local RefreshApplicationThresholdSource
local QueueApplicationThresholdRefresh

local MAX_STACK_COLOR_THRESHOLD = 30
local STACK_COLOR_THRESHOLD_DEFAULT_COLOR = { 1, 0.82, 0, 1 }

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

local function FeedApplicationThresholds(parts, value)
  local overlays = parts.applicationThresholds
  local count = math.min(parts.applicationThresholdCount or 0, #overlays)

  for index = 1, count do
    local overlay = overlays[index]
    if overlay.applicationThresholdValue ~= 1 then
      overlay:SetValue(value)
    end
  end
end

local function EnableApplicationThresholdFeed(parts)
  if parts.applicationThresholdFeedEnabled == true then
    return
  end

  local feed = parts.applicationThresholdFeed
  if not feed then
    feed = function(_, value)
      FeedApplicationThresholds(parts, value)
    end
    parts.applicationThresholdFeed = feed
  end

  parts.applicationBar:SetScript("OnValueChanged", feed)
  parts.applicationThresholdFeedEnabled = true
end

local function DisableApplicationThresholdFeed(parts)
  if parts.applicationThresholdFeedEnabled ~= true then
    return
  end

  parts.applicationBar:SetScript("OnValueChanged", nil)
  parts.applicationThresholdFeedEnabled = nil
end

local function EnsureApplicationThresholdOverlay(parts, index)
  local overlays = parts.applicationThresholds
  local overlay = overlays[index]
  if overlay then
    return overlay
  end

  local applicationBar = parts.applicationBar
  local parent = parts.applicationThresholdParent or applicationBar
  overlay = CreateFrame(
    "StatusBar",
    nil,
    parent,
    "DisableUntrustedLayoutScriptsTemplate"
  )
  local config = parts.applicationThresholdConfiguration
  overlay:SetAllPoints(parts.button and parent or applicationBar:GetStatusBarTexture())
  overlay:SetFrameLevel((config and config.frameLevel or applicationBar:GetFrameLevel()) + index)
  overlay:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  overlay:SetMinMaxValues(0, 1)
  overlay:SetValue(0)
  overlay:Hide()

  if parts.button then
    -- Keep the value gate independent of the restricted native fill geometry.
    overlay:SetStatusBarColor(1, 1, 1, 0)
    overlay.applicationThresholdTexture = overlay:CreateTexture(nil, "ARTWORK")
    overlay.applicationThresholdMask = overlay:CreateMaskTexture()
    overlay.applicationThresholdMask:SetTexture(
      "Interface\\Buttons\\WHITE8X8",
      "CLAMPTOBLACKADDITIVE",
      "CLAMPTOBLACKADDITIVE",
      "NEAREST"
    )
    overlay.applicationThresholdTexture:AddMaskTexture(overlay.applicationThresholdMask)
  end

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
  local applicationBar = parts.applicationBar
  local thresholdValue = tonumber(threshold.value) or 1
  local r, g, b, a = ResolveStackColorThresholdColor(threshold, classColor)

  overlay:SetOrientation(orientation or "HORIZONTAL")
  overlay:SetReverseFill(reverseFill == true)

  local config = parts.applicationThresholdConfiguration
  local texture
  if parts.button then
    texture = overlay.applicationThresholdTexture
    texture:SetTexture(texturePath or "Interface\\Buttons\\WHITE8X8")
    texture:ClearAllPoints()
    texture:SetAllPoints(config.anchor)

    local mask = overlay.applicationThresholdMask
    mask:SetSize(parts.applicationThresholdParent:GetSize())
    mask:ClearAllPoints()
    local edge = orientation == "VERTICAL"
      and (reverseFill == true and "BOTTOM" or "TOP")
      or (reverseFill == true and "LEFT" or "RIGHT")
    mask:SetPoint(edge, overlay:GetStatusBarTexture(), edge)
  else
    overlay:SetStatusBarTexture(texturePath or "Interface\\Buttons\\WHITE8X8")
    texture = overlay:GetStatusBarTexture()
  end
  texture:SetVertexColor(r, g, b, a)
  texture:SetDrawLayer("ARTWORK", 0)

  overlay:SetAlpha(config and config.alpha or 1)
  overlay:SetFrameLevel((config and config.frameLevel or applicationBar:GetFrameLevel()) + thresholdIndex)
  overlay:ClearAllPoints()
  overlay:SetAllPoints(parts.button and parts.applicationThresholdParent or applicationBar:GetStatusBarTexture())
  overlay:SetMinMaxValues(thresholdValue - 1, thresholdValue)
  -- CDM suppresses zero/one-stack text; the native fill anchors this constant layer.
  overlay.applicationThresholdValue = thresholdValue
  overlay:SetValue(thresholdValue == 1 and 1 or 0)
  overlay:Show()
end

function AuraWidget.ClearApplicationThresholdBar(parts)
  parts.applicationThresholdConfiguration = nil
  applicationThresholdPending[parts] = nil
  if parts.applicationThresholdSource then
    AuraWidget.SetApplicationThresholdActive(parts, false)
  end
  local overlays = parts.applicationThresholds
  for index = 1, #overlays do
    overlays[index]:Hide()
  end

  parts.applicationThresholdCount = 0
  parts.applicationThresholdLayerCount = 0
  parts.applicationThresholdMaximum = nil
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

  local config = parts.applicationThresholdConfiguration
  local anchor = parts.button and parts.applicationBar:GetStatusBarTexture()
  local frameLevel = parts.button and parts.applicationBar:GetFrameLevel()
  local alpha = parts.applicationThresholdAlpha or 1
  local inputCount = type(thresholds) == "table" and #thresholds or 0
  if parts.button and config
    and config.texturePath == texturePath
    and config.orientation == orientation
    and config.reverseFill == reverseFill
    and config.maximum == maximum
    and config.anchor == anchor
    and config.frameLevel == frameLevel
    and config.alpha == alpha
    and #config.inputs == inputCount
  then
    local matches = true
    for index = 1, inputCount do
      local threshold = thresholds[index]
      local input = config.inputs[index]
      local r, g, b, a = ResolveStackColorThresholdColor(threshold, classColor)
      if input.enabled ~= threshold.enabled
        or input.value ~= tonumber(threshold.value)
        or input.r ~= r or input.g ~= g or input.b ~= b or input.a ~= a
      then
        matches = false
        break
      end
    end
    if matches then
      return
    end
  end

  local active = {}
  local inputs = parts.button and {}
  if type(thresholds) == "table" then
    for index = 1, #thresholds do
      local threshold = thresholds[index]
      local value = threshold and tonumber(threshold.value)
      if inputs then
        local r, g, b, a = ResolveStackColorThresholdColor(threshold, classColor)
        inputs[index] = {
          enabled = threshold.enabled, value = value,
          r = r, g = g, b = b, a = a,
        }
      end

      if threshold
        and threshold.enabled == true
        and value
        and value >= 1
        and value <= maximum
      then
        if inputs then
          local input = inputs[index]
          active[#active + 1] = {
            value = value,
            color = { input.r, input.g, input.b, input.a },
          }
        else
          active[#active + 1] = threshold
        end
      end
    end
  end

  table_sort(active, function(left, right)
    return left.value < right.value
  end)

  if parts.button then
    parts.applicationThresholdConfiguration = {
      thresholds = active,
      inputs = inputs,
      texturePath = texturePath,
      orientation = orientation,
      reverseFill = reverseFill,
      classColor = classColor,
      maximum = maximum,
      anchor = anchor,
      frameLevel = frameLevel,
      alpha = alpha,
    }
    parts.applicationThresholdCount = #active
    parts.applicationThresholdLayerCount = #active
    parts.applicationThresholdMaximum = maximum
    if parts.applicationThresholdSource then
      RefreshApplicationThresholdSource(parts)
    end
    return
  end

  local overlays = parts.applicationThresholds
  local overlayCount = 0

  for thresholdIndex = 1, #active do
    local overlay = EnsureApplicationThresholdOverlay(parts, thresholdIndex)
    if overlay then
      overlayCount = thresholdIndex
      ConfigureApplicationThresholdOverlay(
        parts,
        overlay,
        active[thresholdIndex],
        thresholdIndex,
        texturePath,
        orientation,
        reverseFill,
        classColor
      )
    end
  end

  for index = overlayCount + 1, #overlays do
    overlays[index]:Hide()
  end

  parts.applicationThresholdCount = overlayCount
  parts.applicationThresholdLayerCount = overlayCount
  parts.applicationThresholdMaximum = maximum

  if overlayCount > 0 then
    EnableApplicationThresholdFeed(parts)
    parts.applicationThresholdsDirty = true
  else
    DisableApplicationThresholdFeed(parts)
    parts.applicationThresholdsDirty = nil
  end
end

local function ApplicationThresholdDataRestricted()
  return InCombatLockdown()
    or C_Secrets.ShouldAurasBeSecret()
    or C_Secrets.ShouldCooldownsBeSecret()
end

local function RemoveApplicationThresholdIndex(parts, source)
  local cooldownID = source.indexedCooldownID
  if cooldownID == nil then
    return
  end
  local units = applicationThresholdSourceIndex[cooldownID]
  local sources = units[source.slot.unit]
  sources[parts] = nil
  if not next(sources) then
    units[source.slot.unit] = nil
  end
  if not next(units) then
    applicationThresholdSourceIndex[cooldownID] = nil
  end
  source.indexedCooldownID = nil
end

local function ClearApplicationThresholdFrame(frame)
  local state = applicationThresholdFrames[frame]
  if not state then
    return
  end
  for parts in pairs(state.sources) do
    local source = parts.applicationThresholdSource
    if source.frame == frame then
      source.frame = nil
      FeedApplicationThresholds(parts, 0)
    end
    state.sources[parts] = nil
  end
end

local function FeedApplicationThresholdFrame(frame, value)
  if not next(applicationThresholdSources) then
    return
  end

  if not issecretvalue(value) then
    if type(value) == "string" then
      value = value == "" and 0 or tonumber(value)
      if value == nil then
        return
      end
    elseif type(value) ~= "number" then
      return
    end
  end

  local cooldownID = frame:GetCooldownID()
  local unit = frame:GetAuraDataUnit()
  local state = applicationThresholdFrames[frame]

  if issecretvalue(cooldownID) or issecretvalue(unit) then
    -- A previously verified CDM binding remains valid until Blizzard changes it.
    for parts in pairs(state.sources) do
      local source = parts.applicationThresholdSource
      if source
        and applicationThresholdSources[parts] == source
        and source.frame == frame
        and source.active == true
      then
        FeedApplicationThresholds(parts, value)
      else
        state.sources[parts] = nil
      end
    end
    return
  end
  for parts in pairs(state.sources) do
    local source = parts.applicationThresholdSource
    if applicationThresholdSources[parts] ~= source
      or source.cooldownID ~= cooldownID
      or source.slot.unit ~= unit
    then
      if source.frame == frame then
        source.frame = nil
        FeedApplicationThresholds(parts, 0)
      end
      state.sources[parts] = nil
    end
  end

  local units = applicationThresholdSourceIndex[cooldownID]
  local sources = units and units[unit]
  if not sources then
    return
  end
  for parts, source in pairs(sources) do
    if source.cooldownID ~= nil
      and source.cooldownID == cooldownID
      and source.slot.unit == unit
      and (source.frame == nil or source.frame == frame)
    then
      source.frame = frame
      state.sources[parts] = true
      FeedApplicationThresholds(parts, value)
    end
  end
end

local function HookApplicationThresholdFrame(frame)
  if applicationThresholdFrames[frame] then
    return
  end
  applicationThresholdFrames[frame] = { sources = {} }

  local countText = frame:GetApplicationsFontString()
  hooksecurefunc(countText, "SetText", function(_, value)
    FeedApplicationThresholdFrame(frame, value)
  end)
  hooksecurefunc(frame, "OnCooldownIDSet", function()
    ClearApplicationThresholdFrame(frame)
  end)
  hooksecurefunc(frame, "ResetCooldownData", function()
    ClearApplicationThresholdFrame(frame)
  end)
end

local function RefreshApplicationThresholdViewer(viewer)
  for frame in viewer.itemFramePool:EnumerateActive() do
    HookApplicationThresholdFrame(frame)
    local text = frame:GetApplicationsFontString():GetText()
    -- GetText returns a secret string, unlike Blizzard's numeric SetText input.
    if not issecretvalue(text) then
      FeedApplicationThresholdFrame(frame, text)
    end
  end
end

local function RefreshApplicationThresholdFrames()
  for _, viewerKey in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
    local viewer = _G[viewerKey]
    if viewer and viewer.itemFramePool then
      if not applicationThresholdViewers[viewer] then
        applicationThresholdViewers[viewer] = true
        hooksecurefunc(viewer, "RefreshLayout", function()
          if next(applicationThresholdSources) then
            RefreshApplicationThresholdViewer(viewer)
          end
        end)
      end
      RefreshApplicationThresholdViewer(viewer)
    end
  end
end

local function ConfigureNativeApplicationThreshold(parts, source, index)
  local config = parts.applicationThresholdConfiguration
  local threshold = config.thresholds[index]
  local gates = source.gates
  local gate = gates[index]
  if not gate then
    gate = {}
    gates[index] = gate
    gate.slot = ns.AuraSlotDriver:CreateSlot(source.slot.unit, source.slot.filter, {
      candidateFilters = { includeSpellIDs = source.spellIDs },
      initializeFrame = function(button)
        gate.button = button
        button:SetAllPoints(parts.applicationThresholdParent)
        button:EnableMouse(false)
        gate.bar = CreateFrame("StatusBar", nil, button, "DisableUntrustedLayoutScriptsTemplate")
        gate.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        gate.bar:SetStatusBarColor(1, 1, 1, 0)
        gate.texture = gate.bar:CreateTexture(nil, "ARTWORK")
      end,
    })
  end

  ns.AuraSlotDriver:SetSlotFilter(gate.slot, source.slot.filter)
  ns.AuraSlotDriver:SetSlotCandidates(gate.slot, { includeSpellIDs = source.spellIDs })
  gate.button:SetFrameStrata(parts.applicationThresholdParent:GetFrameStrata())
  gate.bar:SetFrameLevel(config.frameLevel + index)
  gate.bar:ClearAllPoints()
  gate.bar:SetAllPoints(config.anchor)
  gate.button:SetAlpha(parts.applicationThresholdParent:GetEffectiveAlpha() * config.alpha)
  gate.texture:SetTexture(config.texturePath or "Interface\\Buttons\\WHITE8X8")
  gate.texture:ClearAllPoints()
  gate.texture:SetAllPoints(config.anchor)
  gate.texture:SetVertexColor(ResolveStackColorThresholdColor(threshold, config.classColor))

  if gate.minimum ~= threshold.value or gate.maximum ~= config.maximum then
    gate.minimum = threshold.value
    gate.maximum = config.maximum
    -- Only visibility is used; the colored texture follows the original fill.
    gate.button:SetApplicationBar(gate.bar, {
      minApplications = threshold.value,
      maxApplications = math.max(config.maximum, threshold.value + 1),
      interpolation = Enum.StatusBarInterpolation.Immediate,
    })
  end
end

function AuraWidget.SetApplicationThresholdActive(parts, active, presentationChanged)
  local source = parts.applicationThresholdSource
  local config = parts.applicationThresholdConfiguration
  active = active == true
    and config ~= nil
    and #config.thresholds > 0
    and parts.applicationThresholdParent:IsShown()

  if source.active == active and not presentationChanged then
    return
  end

  if USE_NATIVE_APPLICATION_THRESHOLDS then
    for index = 1, #source.gates do
      ns.AuraSlotDriver:SetSlotActive(source.gates[index].slot, active and index <= (parts.applicationThresholdCount or 0))
    end
  else
    local width, height
    if active then
      width, height = parts.applicationThresholdParent:GetSize()
    end
    for index = 1, #parts.applicationThresholds do
      local overlay = parts.applicationThresholds[index]
      overlay:SetShown(active and index <= (parts.applicationThresholdCount or 0))
      if active then
        overlay.applicationThresholdMask:SetSize(width, height)
      end
    end
    if not active then
      source.frame = nil
      FeedApplicationThresholds(parts, 0)
    end
  end

  if source.active == active then
    return
  end
  source.active = active
  local hadSources = next(applicationThresholdSources) ~= nil
  applicationThresholdSources[parts] = active and source or nil
  if active then
    source.identityDirty = true
  else
    RemoveApplicationThresholdIndex(parts, source)
  end
  if hadSources ~= (next(applicationThresholdSources) ~= nil) then
    applicationThresholdPolicyDirty = true
  end
  QueueApplicationThresholdRefresh()
end

RefreshApplicationThresholdSource = function(parts)
  local source = parts.applicationThresholdSource
  local config = parts.applicationThresholdConfiguration
  if not config then
    AuraWidget.SetApplicationThresholdActive(parts, false)
    return
  end

  if source.appliedConfiguration == config and not source.presentationDirty then
    AuraWidget.SetApplicationThresholdActive(parts, source.slot.active)
    return
  end

  if ApplicationThresholdDataRestricted() then
    applicationThresholdPending[parts] = true
    AuraWidget.SetApplicationThresholdActive(parts, source.slot.active, true)
    QueueApplicationThresholdRefresh()
    return
  end
  applicationThresholdPending[parts] = nil

  if USE_NATIVE_APPLICATION_THRESHOLDS then
    for index = 1, #config.thresholds do
      ConfigureNativeApplicationThreshold(parts, source, index)
    end
  else
    for index = 1, #config.thresholds do
      ConfigureApplicationThresholdOverlay(
        parts,
        EnsureApplicationThresholdOverlay(parts, index),
        config.thresholds[index],
        index,
        config.texturePath,
        config.orientation,
        config.reverseFill,
        config.classColor
      )
    end
    for index = #config.thresholds + 1, #parts.applicationThresholds do
      parts.applicationThresholds[index]:Hide()
    end
  end
  source.appliedConfiguration = config
  source.presentationDirty = nil
  AuraWidget.SetApplicationThresholdActive(parts, source.slot.active, true)
  QueueApplicationThresholdRefresh()
end

function AuraWidget.ConfigureApplicationThresholdSource(parts, slot, spellIDs, cooldownID)
  local source = parts.applicationThresholdSource
  if not source then
    source = { slot = slot, gates = {}, active = false }
    parts.applicationThresholdSource = source
    slot.applicationThresholdParts = parts
    local parent = parts.applicationThresholdParent
    local sources = applicationThresholdParents[parent]
    if not sources then
      sources = {}
      applicationThresholdParents[parent] = sources
      parent:HookScript("OnShow", function()
        for ownedParts in pairs(sources) do
          AuraWidget.SetApplicationThresholdActive(ownedParts, ownedParts.applicationThresholdSource.slot.active)
        end
      end)
      parent:HookScript("OnHide", function()
        for ownedParts in pairs(sources) do
          AuraWidget.SetApplicationThresholdActive(ownedParts, false)
        end
      end)
      if not USE_NATIVE_APPLICATION_THRESHOLDS then
        parent:HookScript("OnSizeChanged", function(_, width, height)
          for ownedParts in pairs(sources) do
            if ownedParts.applicationThresholdSource.active then
              for _, overlay in ipairs(ownedParts.applicationThresholds) do
                overlay.applicationThresholdMask:SetSize(width, height)
              end
            end
          end
        end)
      end
      if USE_NATIVE_APPLICATION_THRESHOLDS then
        hooksecurefunc(parent, "SetAlpha", function()
          for ownedParts in pairs(sources) do
            local ownedSource = ownedParts.applicationThresholdSource
            local ownedConfig = ownedParts.applicationThresholdConfiguration
            if ownedConfig then
              for _, gate in ipairs(ownedSource.gates) do
                gate.button:SetAlpha(parent:GetEffectiveAlpha() * ownedConfig.alpha)
              end
            end
          end
        end)
      end
    end
    sources[parts] = true
  end
  if source.spellIDs ~= spellIDs
    or source.requestedCooldownID ~= cooldownID
    or source.filter ~= slot.filter
  then
    RemoveApplicationThresholdIndex(parts, source)
    if source.frame then
      applicationThresholdFrames[source.frame].sources[parts] = nil
      source.frame = nil
      FeedApplicationThresholds(parts, 0)
    end
    source.spellIDs = spellIDs
    source.requestedCooldownID = cooldownID
    source.filter = slot.filter
    source.identityDirty = true
    source.presentationDirty = true
    QueueApplicationThresholdRefresh()
  end
  RefreshApplicationThresholdSource(parts)
end

function AuraWidget.RequiresNativeCDM()
  return not USE_NATIVE_APPLICATION_THRESHOLDS
    and next(applicationThresholdSources) ~= nil
end

QueueApplicationThresholdRefresh = function()
  applicationThresholdWork:RegisterEvent("ADDON_LOADED")
  applicationThresholdWork:RegisterEvent("PLAYER_ENTERING_WORLD")
  applicationThresholdWork:RegisterEvent("PLAYER_REGEN_ENABLED")
  applicationThresholdWork:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
  applicationThresholdWork:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")
  applicationThresholdWork:RegisterEvent("COOLDOWN_VIEWER_TABLE_HOTFIXED")
  applicationThresholdWork:RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED")
  applicationThresholdWork:RegisterEvent("CVAR_UPDATE")
  applicationThresholdWork:Show()
end

applicationThresholdWork:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 ~= "Blizzard_CooldownViewer"
    or event == "CVAR_UPDATE" and arg1 ~= "cooldownViewerEnabled"
  then
    return
  end
  if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" or event == "CVAR_UPDATE" then
    applicationThresholdPolicyDirty = true
  end
  if event ~= "PLAYER_REGEN_ENABLED" and event ~= "ADDON_RESTRICTION_STATE_CHANGED" then
    for _, source in pairs(applicationThresholdSources) do
      source.identityDirty = true
    end
  end
  applicationThresholdWork:Show()
end)

applicationThresholdWork:SetScript("OnUpdate", function(frame)
  frame:Hide()
  if ApplicationThresholdDataRestricted() then
    return
  end

  for parts in pairs(applicationThresholdPending) do
    RefreshApplicationThresholdSource(parts)
  end
  frame:Hide()

  if not USE_NATIVE_APPLICATION_THRESHOLDS then
    for parts, source in pairs(applicationThresholdSources) do
      if source.identityDirty then
        local cooldownID
        for spellID in pairs(source.spellIDs) do
          cooldownID = ns.Modules.CooldownManager:ResolveCustomBarAuraEntry(
            spellID, source.requestedCooldownID or source.cooldownID, false
          )
          if cooldownID then
            break
          end
        end
        if source.cooldownID ~= cooldownID then
          source.frame = nil
          FeedApplicationThresholds(parts, 0)
        end
        source.cooldownID = cooldownID
        source.identityDirty = nil
        if source.indexedCooldownID ~= cooldownID then
          RemoveApplicationThresholdIndex(parts, source)
          if cooldownID ~= nil then
            local units = applicationThresholdSourceIndex[cooldownID]
            if not units then
              units = {}
              applicationThresholdSourceIndex[cooldownID] = units
            end
            local sources = units[source.slot.unit]
            if not sources then
              sources = {}
              units[source.slot.unit] = sources
            end
            sources[parts] = source
            source.indexedCooldownID = cooldownID
          end
        end
      end
    end
  end

  if applicationThresholdPolicyDirty then
    applicationThresholdPolicyDirty = false
    if ns.PCM_ReconcileNativeCDM() == nil then
      applicationThresholdPolicyDirty = true
    end
  end
  if not USE_NATIVE_APPLICATION_THRESHOLDS and next(applicationThresholdSources) then
    RefreshApplicationThresholdFrames()
  end
  if not next(applicationThresholdSources) then
    frame:UnregisterAllEvents()
  end
end)

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
  DisableApplicationThresholdFeed(parts)
  parts.applicationBase:Hide()
  parts.applicationBar:Hide()
  AuraWidget.ClearApplicationThresholdBar(parts)
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
RemoveApplicationThresholdIndex = P:Def(
  "AuraWidget.RemoveApplicationThresholdIndex", RemoveApplicationThresholdIndex
)
FeedApplicationThresholds = P:Def(
  "AuraWidget.FeedApplicationThresholds",
  FeedApplicationThresholds
)
EnableApplicationThresholdFeed = P:Def(
  "AuraWidget.EnableApplicationThresholdFeed",
  EnableApplicationThresholdFeed
)
DisableApplicationThresholdFeed = P:Def(
  "AuraWidget.DisableApplicationThresholdFeed",
  DisableApplicationThresholdFeed
)
EnsureApplicationThresholdOverlay = P:Def(
  "AuraWidget.EnsureApplicationThresholdOverlay",
  EnsureApplicationThresholdOverlay
)
ConfigureApplicationThresholdOverlay = P:Def(
  "AuraWidget.ConfigureApplicationThresholdOverlay",
  ConfigureApplicationThresholdOverlay
)
AuraWidget.ConfigureApplicationThresholds = P:Def(
  "AuraWidget.ConfigureApplicationThresholds",
  AuraWidget.ConfigureApplicationThresholds
)
AuraWidget.ConfigureApplicationThresholdSource = P:Def(
  "AuraWidget.ConfigureApplicationThresholdSource", AuraWidget.ConfigureApplicationThresholdSource
)
AuraWidget.SetApplicationThresholdActive = P:Def(
  "AuraWidget.SetApplicationThresholdActive", AuraWidget.SetApplicationThresholdActive
)
AuraWidget.CreateSlotGlow = P:Def("AuraWidget.CreateSlotGlow", AuraWidget.CreateSlotGlow)
AuraWidget.ConfigureSlotGlow = P:Def("AuraWidget.ConfigureSlotGlow", AuraWidget.ConfigureSlotGlow)
AuraWidget.ClearApplicationThresholdBar = P:Def(
  "AuraWidget.ClearApplicationThresholdBar",
  AuraWidget.ClearApplicationThresholdBar
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
