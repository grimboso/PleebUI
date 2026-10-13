local ADDON_NAME, ns = ...

local M = ns.Modules.PRD
local Secondary = ns.PRDSecondary
local P = ns.Pleebug:DropIn({}, { name = "PRD_Secondary_Core" })
local function BuildStateKey(owner, hasSecondary)
  local parts = {
    tostring(hasSecondary and 1 or 0),
  }
  local resources = owner.secondaryResources or {}

  for index = 1, #resources do
    local resource = resources[index]
    local definition = resource.definition
    local config = resource.config

    parts[#parts + 1] = definition.resourceKey
    parts[#parts + 1] = resource.visible and 1 or 0
    parts[#parts + 1] = definition.adapter or ""
    parts[#parts + 1] = tostring(resource.maximum or 0)
    parts[#parts + 1] = config and config.structureKey or ""
  end

  return table.concat(parts, "|")
end

local function ResourceHasBuffCue(config)
  return config ~= nil
    and (tonumber(config.cues.buffGlowSpellID) or 0) > 0
end

local function ForEachResourceAdapter(resources, callback)
  local seen = {}

  for index = 1, #(resources or {}) do
    local adapter = resources[index].adapter
    if adapter and seen[adapter] ~= true then
      seen[adapter] = true
      callback(adapter)
    end
  end
end

local function ForEachSecondaryAdapter(owner, callback)
  local adapters = owner.secondaryAdapters
  if not adapters then
    return
  end

  for index = 1, #adapters do
    callback(adapters[index])
  end
end

local function HideSecondaryResourceFrames(owner)
  if owner.secondary then
    owner.secondary:Hide()
  end

  local extraFrames = owner._puiSecondaryExtraFrames
  if extraFrames then
    for _, frame in pairs(extraFrames) do
      frame:Hide()
    end
  end
end

local function StopSecondaryCues(owner, resources)
  for index = 1, #(resources or {}) do
    local resource = resources[index]
    if resource.frame and resource.config then
      Secondary.StopResourceCues(owner, resource.frame, resource.config)
    end
  end
end

local function ConfigureSecondaryCues(owner)
  local resources = owner.secondaryResources or {}

  for index = 1, #resources do
    local resource = resources[index]
    local frame = resource.frame
    local config = resource.config

    if owner.secondaryUsesCustom == true and resource.visible and frame and config then
      Secondary.ConfigureResourceBuffCue(owner, frame, config)
    elseif frame and config then
      Secondary.StopResourceCues(owner, frame, config)
    end
  end
end

local function AreSecondaryStructuresReady(owner)
  local ready = true
  local hasAdapter = false

  ForEachSecondaryAdapter(owner, function(adapter)
    hasAdapter = true
    if not adapter.IsStructureReady(owner) then
      ready = false
    end
  end)

  return hasAdapter and ready
end

local function SuspendSecondaryAdapters(owner)
  ForEachSecondaryAdapter(owner, function(adapter)
    adapter.Suspend(owner)
  end)
end

local function DeactivateSecondaryAdapters(owner, resources)
  ForEachResourceAdapter(resources, function(adapter)
    adapter.Deactivate(owner)
  end)
end

local function BuildSecondaryStructures(owner)
  owner._puiSecondaryBuildPending = nil

  ForEachSecondaryAdapter(owner, function(adapter)
    adapter.Build(owner)
  end)

  if not AreSecondaryStructuresReady(owner) then
    owner._puiSecondaryBuildPending = true
    return false
  end

  owner._puiSecondaryAppearancePending = nil
  owner._puiSecondaryTextPending = nil
  Secondary.ApplySecondaryAppearance(owner)
  return true
end

local function GetAdapterEvents(adapter, owner)
  if adapter.GetEvents then
    return adapter.GetEvents(owner)
  end

  return adapter.events
end

local function RegisterAdapterEvents(frame, adapter, owner)
  local events = GetAdapterEvents(adapter, owner)
  local registered = frame._puiAdapterEvents

  if not registered then
    registered = {}
    frame._puiAdapterEvents = registered
  end

  for event, unit in pairs(events) do
    local adapters = registered[event]

    if not adapters then
      adapters = {}
      registered[event] = adapters

      if unit == true then
        frame:RegisterEvent(event)
      else
        frame:RegisterUnitEvent(event, unit)
      end
    end

    if adapters[adapter] ~= true then
      adapters[adapter] = true
      adapters[#adapters + 1] = adapter
    end
  end
end

local function RegisterVisibilityEvents(frame, mode)
  if mode == "COMBAT" or mode == "COMBAT_OR_TARGET" then
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  end

  if mode == "TARGET" or mode == "COMBAT_OR_TARGET" then
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
  end
end

function M:RebuildSecondary(forceBuild)
  local oldResources = self._puiSecondaryRuntimeResources or {}
  local wasUsingCustom = self.secondaryUsesCustom == true
  local powerType, token, maximum = self:ResolveSecondaryType()
  local definition = self.secondaryDef
  local adapter = self.secondaryAdapter
  local resources = self.secondaryResources or {}
  local profile = self.db.profile
  local hasSecondary = #resources > 0
    and definition ~= nil
    and adapter ~= nil
    and token ~= nil
    and maximum > 0
  local useCustom = hasSecondary and self._puiSecondaryHasVisibleResources

  self.secondaryType = powerType
  self.secondaryToken = token
  self.secondaryMax = maximum
  self.secondaryCustomEnabled = hasSecondary

  local stateKey = BuildStateKey(self, hasSecondary)
  local stateChanged = forceBuild == true or self._puiSecondaryStateKey ~= stateKey
  local visibilityChanged = wasUsingCustom ~= useCustom

  self.secondaryUsesCustom = useCustom
  self._puiSecondaryStateKey = stateKey

  local eventParts = {
    tostring(profile.primary.hideAlternateMana ~= true and 1 or 0),
    tostring(hasSecondary and 1 or 0),
    tostring(useCustom and 1 or 0),
  }

  for index = 1, #resources do
    local resource = resources[index]
    eventParts[#eventParts + 1] = resource.definition.resourceKey
    eventParts[#eventParts + 1] = resource.definition.adapter or ""
    eventParts[#eventParts + 1] = resource.config.visibilityMode
    eventParts[#eventParts + 1] = tostring(
      resource.config and resource.config.cues.buffGlowSpellID or 0
    )
  end

  local eventKey = table.concat(eventParts, "|")
  if self._puiSecondaryEventKey ~= eventKey then
    self._puiSecondaryEventKey = eventKey
    self:RegisterSecondaryEvents()
  end

  if stateChanged then
    DeactivateSecondaryAdapters(self, oldResources)
    StopSecondaryCues(self, oldResources)
    self._puiSecColorDirty = true
    self._puiSecInactiveAlpha = nil
    self._puiSecondaryBuildKey = nil
    self._puiSecondaryBuildPending = true
  elseif visibilityChanged and not useCustom then
    SuspendSecondaryAdapters(self)
  end

  self._puiSecondaryRuntimeResources = useCustom and resources or {}

  if useCustom and not wasUsingCustom and self._puiSecondaryContent then
    self._puiSecondaryContent:SetAlpha(1)
  end

  local blizzardState = tostring(profile.primary.hideAlternateMana == true and 1 or 0)

  if self._puiBlizzardSecondaryState ~= blizzardState then
    self._puiBlizzardSecondaryState = blizzardState
    self:SetBlizzardSecondaryShown(false)
  end

  if self._puiBlizzardRootGhosted ~= true then
    self._puiBlizzardRootGhosted = true
    self:SetBlizzardRootGhosted(true)
  end

  local structureReady = not useCustom or AreSecondaryStructuresReady(self)

  if (stateChanged or visibilityChanged)
    and (
      not useCustom
      or structureReady and self._puiSecondaryBuildPending ~= true
      or not InCombatLockdown()
    )
  then
    self:ApplyLayout()
  end

  if stateChanged then
    self:AttachMover()
  end

  if useCustom
    and (self._puiSecondaryBuildPending == true or not structureReady)
  then
    structureReady = BuildSecondaryStructures(self)
    self:RegisterSecondaryEvents()
  end

  if not structureReady then
    SuspendSecondaryAdapters(self)
    HideSecondaryResourceFrames(self)
    return
  end

  if useCustom then
    ConfigureSecondaryCues(self)
  else
    StopSecondaryCues(self, resources)
  end

  if not useCustom then
    SuspendSecondaryAdapters(self)
    HideSecondaryResourceFrames(self)
    self._puiSecondaryBuildPending = nil
    self._puiSecondaryAppearancePending = nil
    self._puiSecondaryTextPending = nil
    self:RegisterSecondaryEvents()
    return
  end

  self:UpdateSecondary()
end

function M:RefreshSecondaryVisibility()
  self._puiSecondaryVisibilityDirty = true
  self:RebuildSecondary()
  ns.PRDPreview.MarkDirty()
end

function M:RefreshSecondaryAppearance()
  if self.secondaryUsesCustom ~= true or #((self.secondaryResources) or {}) == 0 then
    return
  end

  self._puiSecondaryAppearancePending = nil
  self._puiSecondaryBuildKey = nil

  ForEachSecondaryAdapter(self, function(adapter)
    adapter.Build(self)
  end)

  if not AreSecondaryStructuresReady(self) then
    self._puiSecondaryAppearancePending = true
    self._puiSecondaryBuildPending = true
    self:RegisterSecondaryEvents()
    SuspendSecondaryAdapters(self)
    HideSecondaryResourceFrames(self)
    return
  end

  self._puiSecondaryBuildPending = nil
  self._puiSecondaryTextPending = nil
  self._puiSecColorDirty = true
  self._puiSecInactiveAlpha = nil
  self._puiSecFontsDirty = true
  ConfigureSecondaryCues(self)
  Secondary.ApplySecondaryAppearance(self)
  self:ApplyLayout()

  if self.secondaryUsesCustom == true then
    self:UpdateSecondary()
  else
    SuspendSecondaryAdapters(self)
    HideSecondaryResourceFrames(self)
  end

  self:RegisterSecondaryEvents()
end

function M:RefreshSecondaryText()
  if self.secondaryUsesCustom ~= true or #((self.secondaryResources) or {}) == 0 then
    return
  end

  self._puiSecondaryTextPending = nil
  self._puiSecFontsDirty = true
  if self.secondaryBar then
    Secondary.PrepareSecondaryText(self, self.secondaryBar)
  end

  ForEachSecondaryAdapter(self, function(adapter)
    adapter.RefreshText(self)
  end)

  self:UpdateSecondary()
  self:RegisterSecondaryEvents()
end

function M:UpdateSecondary()
  if self.secondaryUsesCustom ~= true then
    return
  end

  local adapter = self.secondaryAdapter

  if self._puiSecColorDirty == true or self._puiSecColorR == nil then
    Secondary.ResolveSecondaryColorConfig(self)
  end

  if self._puiSecInactiveAlpha == nil then
    Secondary.GetInactiveAlpha(self)
  end

  local activeAdapters = self.secondaryAdapters
  if activeAdapters then
    for index = 1, #activeAdapters do
      local activeAdapter = activeAdapters[index]
      if activeAdapter.directUpdate == true then
        activeAdapter.Update(self)
      end
    end
  end

  if not adapter or adapter.directUpdate == true or self.secondaryResources[1].visible ~= true then
    return
  end

  local bar = self.secondaryBar
  if not bar then
    return
  end

  local text = Secondary.PrepareSecondaryText(self, bar)
  adapter.Update(self, bar, text, "player")
end

local function EnsureEventFrame(owner)
  local frame = owner._puiSecondaryEventFrame
  if frame then
    frame._puiOwner = owner
    return frame
  end

  frame = CreateFrame("Frame")
  frame._puiOwner = owner
  frame:SetScript("OnEvent", function(eventFrame, event, ...)
    local currentOwner = eventFrame._puiOwner
    if currentOwner._puiRuntimeStarted ~= true then
      return
    end

    local visibilityEvent = event == "PLAYER_REGEN_DISABLED"
      or event == "PLAYER_REGEN_ENABLED"
      or event == "PLAYER_TARGET_CHANGED"

    if visibilityEvent then
      currentOwner:RefreshSecondaryVisibility()
    end

    if event == "PLAYER_REGEN_ENABLED" then
      if currentOwner._puiSecondaryBuildPending then
        currentOwner:RebuildSecondary()
      elseif currentOwner._puiSecondaryAppearancePending then
        currentOwner:RefreshSecondaryAppearance()
      elseif currentOwner._puiSecondaryTextPending then
        currentOwner:RefreshSecondaryText()
      end
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED"
      and currentOwner._puiSecondaryCueStylePending
    then
      currentOwner._puiSecondaryCueStylePending = nil
      ConfigureSecondaryCues(currentOwner)
      currentOwner:RegisterSecondaryEvents()
    end

    local handler = currentOwner[event]
    if handler then
      handler(currentOwner, event, ...)
      return
    end

    local adapters = eventFrame._puiAdapterEvents
      and eventFrame._puiAdapterEvents[event]
    if not adapters then
      return
    end

    for index = 1, #adapters do
      local adapter = adapters[index]
      if adapter.OnEvent then
        adapter.OnEvent(currentOwner, event, ...)
      end
    end
  end)

  owner._puiSecondaryEventFrame = frame
  return frame
end

function M:RegisterSecondaryEvents()
  local frame = EnsureEventFrame(self)
  frame:UnregisterAllEvents()
  frame._puiAdapterEvents = nil

  for _, resource in ipairs(self.secondaryResources or {}) do
    if resource.definition.isAlternatePower ~= true then
      RegisterVisibilityEvents(frame, resource.config.visibilityMode)
    end
  end

  if self._puiSecondaryBuildPending
    or self._puiSecondaryAppearancePending
    or self._puiSecondaryTextPending
  then
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  end

  local hasBuffCue = false
  for index = 1, #(self.secondaryResources or {}) do
    if self.secondaryResources[index].visible and ResourceHasBuffCue(self.secondaryResources[index].config) then
      hasBuffCue = true
      break
    end
  end

  if self._puiSecondaryCueStylePending or hasBuffCue then
    frame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
  end

  if self.secondaryUsesCustom == true then
    ForEachSecondaryAdapter(self, function(adapter)
      RegisterAdapterEvents(frame, adapter, self)
    end)
  end

  self._puiSecondaryEventsRegistered = true
end

function M:UnregisterSecondaryEvents()
  local frame = self._puiSecondaryEventFrame
  if frame then
    frame:UnregisterAllEvents()
    frame._puiAdapterEvents = nil
  end

  self.secondaryUsesCustom = false
  self._puiSecondaryEventKey = nil
  self._puiBlizzardSecondaryState = nil
  self._puiBlizzardRootGhosted = nil
  self._puiSecondaryEventsRegistered = false
end

function M:CompleteSecondaryShutdown()
  if self._puiRuntimeStarted == true then
    return true
  end

  self._puiSecondaryCueStylePending = nil
  self._puiSecondaryAppearancePending = nil
  self._puiSecondaryTextPending = nil

  local resources = self._puiSecondaryRuntimeResources or {}
  DeactivateSecondaryAdapters(self, resources)
  StopSecondaryCues(self, resources)
  HideSecondaryResourceFrames(self)
  self._puiSecondaryRuntimeResources = nil

  return true
end

BuildStateKey = P:Def("BuildStateKey", BuildStateKey)
ResourceHasBuffCue = P:Def("ResourceHasBuffCue", ResourceHasBuffCue)
ForEachResourceAdapter = P:Def("ForEachResourceAdapter", ForEachResourceAdapter)
ForEachSecondaryAdapter = P:Def("ForEachSecondaryAdapter", ForEachSecondaryAdapter)
HideSecondaryResourceFrames = P:Def("HideSecondaryResourceFrames", HideSecondaryResourceFrames)
StopSecondaryCues = P:Def("StopSecondaryCues", StopSecondaryCues)
ConfigureSecondaryCues = P:Def(
  "ConfigureSecondaryCues",
  ConfigureSecondaryCues
)
AreSecondaryStructuresReady = P:Def(
  "AreSecondaryStructuresReady",
  AreSecondaryStructuresReady
)
SuspendSecondaryAdapters = P:Def(
  "SuspendSecondaryAdapters",
  SuspendSecondaryAdapters
)
DeactivateSecondaryAdapters = P:Def(
  "DeactivateSecondaryAdapters",
  DeactivateSecondaryAdapters
)
BuildSecondaryStructures = P:Def(
  "BuildSecondaryStructures",
  BuildSecondaryStructures
)
GetAdapterEvents = P:Def("GetAdapterEvents", GetAdapterEvents)
RegisterAdapterEvents = P:Def("RegisterAdapterEvents", RegisterAdapterEvents)
RegisterVisibilityEvents = P:Def("RegisterVisibilityEvents", RegisterVisibilityEvents)
M.RebuildSecondary = P:Def("RebuildSecondary", M.RebuildSecondary)
M.RefreshSecondaryVisibility = P:Def("RefreshSecondaryVisibility", M.RefreshSecondaryVisibility)
M.RefreshSecondaryAppearance = P:Def(
  "RefreshSecondaryAppearance",
  M.RefreshSecondaryAppearance
)
M.RefreshSecondaryText = P:Def(
  "RefreshSecondaryText",
  M.RefreshSecondaryText
)
M.UpdateSecondary = P:Def("UpdateSecondary", M.UpdateSecondary)
EnsureEventFrame = P:Def("EnsureEventFrame", EnsureEventFrame)
M.RegisterSecondaryEvents = P:Def("RegisterSecondaryEvents", M.RegisterSecondaryEvents)
M.UnregisterSecondaryEvents = P:Def("UnregisterSecondaryEvents", M.UnregisterSecondaryEvents)
M.CompleteSecondaryShutdown = P:Def("CompleteSecondaryShutdown", M.CompleteSecondaryShutdown)
