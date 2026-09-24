local ADDON_NAME, ns = ...

local Runtime = {}
ns.PCMRuntime = Runtime

local Hooks = ns.PCMHooks
local P = select(1, ns.Pleebug:DropIn(Runtime, { name = "PCM", bucket = "Runtime" }))
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local C_Secrets = C_Secrets
local bit_bor = bit.bor
local bit_band = bit.band
local wipe = wipe

local EMPTY = {}

Runtime.Dirty = {
  LAYOUT = 1,
  FONT = 2,
  SKIN = 4,
  ITEMS = 8,
  VISIBILITY = 16,
  CONTENT = 32,
  ALL = 63,
}

local state = {
  enabled = false,
  eventFrame = CreateFrame("Frame"),
  flushFrame = CreateFrame("Frame"),
  viewers = {},
  viewerOrder = {},
  viewerByFrame = setmetatable({}, { __mode = "k" }),
  itemEntry = setmetatable({}, { __mode = "k" }),
  subscribers = {},
  subscriberOrder = {},
  callbackRoutes = {},
  workHead = nil,
  workTail = nil,
  worldTransitionActive = false,
}
state.flushFrame:Hide()

local function IsDataRestricted()
  return InCombatLockdown()
    or C_Secrets.ShouldAurasBeSecret()
    or C_Secrets.ShouldCooldownsBeSecret()
end

local function IsPresentationSuspended()
  return state.worldTransitionActive == true
end

local LIFECYCLE_EVENTS = {
  "ADDON_LOADED",
  "PLAYER_ENTERING_WORLD",
  "LOADING_SCREEN_ENABLED",
  "LOADING_SCREEN_DISABLED",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_TARGET_CHANGED",
  "ADDON_RESTRICTION_STATE_CHANGED",
  "PLAYER_SPECIALIZATION_CHANGED",
  "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
  "PLAYER_TALENT_UPDATE",
  "ACTIVE_TALENT_GROUP_CHANGED",
  "TRAIT_CONFIG_UPDATED",
  "SPELLS_CHANGED",
  "EDIT_MODE_LAYOUTS_UPDATED",
  "COOLDOWN_VIEWER_DATA_LOADED",
  "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED",
  "COOLDOWN_VIEWER_TABLE_HOTFIXED",
}

local function RebuildSubscriberRoutes()
  wipe(state.callbackRoutes)

  for index = 1, #state.subscriberOrder do
    local subscriber = state.subscribers[state.subscriberOrder[index]]
    if subscriber then
      for callbackName, callback in pairs(subscriber.callbacks or EMPTY) do
        if type(callback) == "function" then
          local routes = state.callbackRoutes[callbackName]
          if not routes then
            routes = {}
            state.callbackRoutes[callbackName] = routes
          end

          routes[#routes + 1] = {
            subscriber = subscriber,
            callback = callback,
          }
        end
      end
    end
  end
end

local function Dispatch(callbackName, ...)
  local routes = state.callbackRoutes[callbackName]
  if not routes then
    return
  end

  for index = 1, #routes do
    local route = routes[index]
    if route.subscriber.enabled == true then
      route.callback(...)
    end
  end
end

local function GetEntry(viewerOrKey)
  if type(viewerOrKey) == "string" then
    return state.viewers[viewerOrKey]
  end

  if viewerOrKey then
    return state.viewerByFrame[viewerOrKey]
  end
end

local function QueueEntry(entry, deferFlush)
  if not state.enabled or not entry or entry.processing == true then
    return
  end

  if entry.workQueued == true then
    if deferFlush ~= true and not IsPresentationSuspended() then
      state.flushFrame:Show()
    end
    return
  end

  entry.workQueued = true
  entry.nextWork = nil

  local tail = state.workTail
  if tail then
    tail.nextWork = entry
  else
    state.workHead = entry
  end
  state.workTail = entry
  if deferFlush ~= true and not IsPresentationSuspended() then
    state.flushFrame:Show()
  end
end

local function ClearWorkQueue()
  local entry = state.workHead
  while entry do
    local nextEntry = entry.nextWork
    entry.workQueued = false
    entry.nextWork = nil
    entry = nextEntry
  end

  state.workHead = nil
  state.workTail = nil
end

local function MarkViewerDirty(entry, mask, reason)
  if not state.enabled or not entry then
    return
  end

  entry.dirtyMask = bit_bor(entry.dirtyMask or 0, mask or Runtime.Dirty.LAYOUT)
  entry.dirtyReason = reason or entry.dirtyReason
  QueueEntry(entry)
end

local function MarkItemMembershipChanged(entry, reason)
  entry.itemGeneration = (entry.itemGeneration or 0) + 1
  MarkViewerDirty(entry, bit_bor(Runtime.Dirty.ITEMS, Runtime.Dirty.LAYOUT), reason)
end

local function FlushRuntime(frame)
  frame:Hide()

  if not state.enabled then
    return
  end

  if IsPresentationSuspended() then
    return
  end

  local stopEntry = state.workTail
  local entry = state.workHead

  while entry do
    local nextEntry = entry.nextWork
    state.workHead = nextEntry
    if not nextEntry then
      state.workTail = nil
    end

    entry.nextWork = nil
    entry.workQueued = false
    entry.processing = true
    if entry.scanQueued == true then
      local scanReason = entry.scanReason or "queued-scan"
      entry.scanQueued = false
      entry.scanReason = nil
      Runtime:RefreshViewer(entry.key, scanReason)
    end

    if entry.acquireQueued == true and not IsDataRestricted() then
      entry.acquireQueued = false

      for index = 1, #entry.items do
        local itemFrame = entry.items[index]
        local itemState = itemFrame and state.itemEntry[itemFrame] or nil
        if itemFrame
          and entry.itemSet[itemFrame] == true
          and itemState
          and itemState.entry == entry
          and itemState.acquirePending == true
        then
          itemState.acquirePending = nil
          Dispatch("OnItemAcquired", entry.key, entry.frame, itemFrame, "deferred-acquire")
        end
      end
    end

    if entry.rebindQueued == true and not IsDataRestricted() then
      entry.rebindQueued = false

      for index = 1, #entry.items do
        local itemFrame = entry.items[index]
        if itemFrame and entry.itemSet[itemFrame] == true then
          Dispatch("OnItemRebound", entry.key, entry.frame, itemFrame)
        end
      end
    end

    local mask = entry.dirtyMask or 0
    if mask ~= 0 then
      local reason = entry.dirtyReason
      entry.dirtyMask = 0
      entry.dirtyReason = nil
      Dispatch(
        "OnViewerDirty",
        entry.key,
        entry.frame,
        mask,
        reason,
        entry.itemGeneration or 0,
        entry.layoutGeneration or 0
      )
    end

    entry.processing = false
    if entry.scanQueued == true
      or (entry.dirtyMask or 0) ~= 0
    then
      QueueEntry(entry, IsPresentationSuspended())
    elseif not IsDataRestricted()
      and (entry.acquireQueued == true or entry.rebindQueued == true)
    then
      QueueEntry(entry)
    end

    if entry == stopEntry then
      break
    end
    entry = nextEntry
  end

  if state.workHead and not IsPresentationSuspended() then
    frame:Show()
  end
end

local function RemoveItemFromList(entry, itemFrame)
  local index = entry.itemIndex[itemFrame]
  if not index then
    return
  end

  local items = entry.items
  local lastIndex = #items
  local lastItem = items[lastIndex]

  items[lastIndex] = nil
  entry.itemIndex[itemFrame] = nil

  if index ~= lastIndex and lastItem then
    items[index] = lastItem
    entry.itemIndex[lastItem] = index
  end
end

local function BindItemState(entry, itemFrame)
  local itemState = state.itemEntry[itemFrame]
  if not itemState then
    itemState = {}
    state.itemEntry[itemFrame] = itemState
  end

  itemState.entry = entry
end

local function AcquireItem(entry, itemFrame, reason, suppressGeneration)
  if not itemFrame or itemFrame:IsForbidden() then
    return false
  end

  local previousEntry = state.itemEntry[itemFrame] and state.itemEntry[itemFrame].entry or nil
  if previousEntry and previousEntry ~= entry and previousEntry.itemSet[itemFrame] == true then
    previousEntry.itemSet[itemFrame] = nil
    RemoveItemFromList(previousEntry, itemFrame)
    Dispatch("OnItemReleased", previousEntry.key, previousEntry.frame, itemFrame, "viewer-changed")
    MarkItemMembershipChanged(previousEntry, "viewer-changed")
  end

  if entry.itemSet[itemFrame] == true then
    BindItemState(entry, itemFrame)
    return false
  end

  entry.itemSet[itemFrame] = true
  local itemIndex = #entry.items + 1
  entry.items[itemIndex] = itemFrame
  entry.itemIndex[itemFrame] = itemIndex
  BindItemState(entry, itemFrame)

  Dispatch("OnItemTracked", entry.key, entry.frame, itemFrame, reason or "acquire")
  if IsDataRestricted() then
    local itemState = state.itemEntry[itemFrame]
    if itemState then
      itemState.acquirePending = true
    end
    entry.acquireQueued = true
  else
    Dispatch("OnItemAcquired", entry.key, entry.frame, itemFrame, reason or "acquire")
  end
  if suppressGeneration ~= true then
    MarkItemMembershipChanged(entry, reason or "acquire")
  end
  return true
end

local function ReleaseItem(entry, itemFrame, reason, suppressGeneration)
  if not entry or not itemFrame or entry.itemSet[itemFrame] ~= true then
    return false
  end

  entry.itemSet[itemFrame] = nil
  RemoveItemFromList(entry, itemFrame)

  local itemState = state.itemEntry[itemFrame]
  if itemState and itemState.entry == entry then
    itemState.entry = nil
    itemState.acquirePending = nil
  end

  Dispatch("OnItemReleased", entry.key, entry.frame, itemFrame, reason or "release")
  if suppressGeneration ~= true then
    MarkItemMembershipChanged(entry, reason or "release")
  end
  return true
end

local function ScanViewer(entry, reason)
  local viewer = entry and entry.frame or nil
  if not viewer or viewer:IsForbidden() then
    return false
  end

  if IsPresentationSuspended() then
    entry.scanQueued = true
    entry.scanReason = reason or entry.scanReason or "transition-scan"
    QueueEntry(entry, true)
    return false
  end

  local pool = viewer.itemFramePool
  local active = entry.activeSet
  local activeItems = entry.activeItems
  wipe(active)
  wipe(activeItems)

  for itemFrame in pool:EnumerateActive() do
    if itemFrame and not itemFrame:IsForbidden() then
      active[itemFrame] = true
      activeItems[#activeItems + 1] = itemFrame
    end
  end

  if #activeItems == #entry.items then
    local membershipChanged = false
    for itemFrame in pairs(entry.itemSet) do
      if active[itemFrame] ~= true then
        membershipChanged = true
        break
      end
    end

    if not membershipChanged then
      return false
    end
  end

  local previous = entry.previousSet
  wipe(previous)
  for itemFrame in pairs(entry.itemSet) do
    previous[itemFrame] = true
  end

  local changed = false

  for itemFrame in pairs(previous) do
    if active[itemFrame] ~= true and ReleaseItem(entry, itemFrame, reason or "scan-release", true) then
      changed = true
    end
  end

  for index = 1, #activeItems do
    local itemFrame = activeItems[index]
    if entry.itemSet[itemFrame] ~= true then
      if AcquireItem(entry, itemFrame, reason or "scan-acquire", true) then
        changed = true
      end
    else
      BindItemState(entry, itemFrame)
    end
  end

  if changed then
    MarkItemMembershipChanged(entry, reason or "scan")
  end

  return changed
end

local function ReleaseViewer(entry, reason)
  local viewer = entry and entry.frame or nil
  if not viewer then
    return
  end

  for index = #entry.items, 1, -1 do
    ReleaseItem(entry, entry.items[index], reason or "viewer-release", true)
  end

  wipe(entry.items)
  wipe(entry.itemSet)
  wipe(entry.itemIndex)
  wipe(entry.previousSet)
  wipe(entry.activeSet)
  wipe(entry.activeItems)
  state.viewerByFrame[viewer] = nil
end

local function HookViewer(entry)
  local viewer = entry.frame
  if not viewer or entry.hookedViewers[viewer] == true then
    return
  end
  entry.hookedViewers[viewer] = true

  Hooks.HookMethod(viewer, "OnAcquireItemFrame", "PCMRuntime_ViewerAcquireItem", function(owner, itemFrame)
    if not state.enabled or entry.frame ~= owner then
      return
    end

    entry.layoutGeneration = (entry.layoutGeneration or 0) + 1
    entry.scanQueued = true
    entry.scanReason = "viewer-acquire"
    entry.rebindQueued = true
    if entry.dynamicMembership == true then
      MarkViewerDirty(entry, bit_bor(Runtime.Dirty.ITEMS, Runtime.Dirty.LAYOUT), "viewer-acquire")
    else
      MarkViewerDirty(entry, Runtime.Dirty.LAYOUT, "viewer-acquire")
    end

    if IsPresentationSuspended() then
      return
    end

    AcquireItem(entry, itemFrame, "viewer-acquire")
  end)

  Hooks.HookScript(viewer, "OnShow", "PCMRuntime_ViewerShow", function(owner)
    if not state.enabled or entry.frame ~= owner then
      return
    end

    MarkViewerDirty(entry, Runtime.Dirty.VISIBILITY, "viewer-show")
  end)

  Hooks.HookScript(viewer, "OnHide", "PCMRuntime_ViewerHide", function(owner)
    if not state.enabled or entry.frame ~= owner then
      return
    end

    MarkViewerDirty(entry, Runtime.Dirty.VISIBILITY, "viewer-hide")
  end)

end

function Runtime:RegisterViewer(key, resolver, dynamicMembership)
  if type(key) ~= "string" or key == "" or type(resolver) ~= "function" then
    return
  end

  local entry = state.viewers[key]
  if not entry then
    entry = {
      key = key,
      resolver = resolver,
      dynamicMembership = dynamicMembership == true,
      frame = nil,
      hookedViewers = setmetatable({}, { __mode = "k" }),
      items = {},
      itemSet = setmetatable({}, { __mode = "k" }),
      itemIndex = setmetatable({}, { __mode = "k" }),
      previousSet = setmetatable({}, { __mode = "k" }),
      activeSet = setmetatable({}, { __mode = "k" }),
      activeItems = {},
      itemGeneration = 0,
      layoutGeneration = 0,
      dirtyMask = 0,
      dirtyReason = nil,
      scanQueued = false,
      scanReason = nil,
      acquireQueued = false,
      rebindQueued = false,
      workQueued = false,
      processing = false,
      nextWork = nil,
    }
    state.viewers[key] = entry
    state.viewerOrder[#state.viewerOrder + 1] = key
  else
    entry.resolver = resolver
    entry.dynamicMembership = dynamicMembership == true
  end

  if state.enabled then
    self:BindViewer(key, "register")
  end
end

function Runtime:RegisterSubscriber(name, callbacks)
  if type(name) ~= "string" or name == "" or type(callbacks) ~= "table" then
    return
  end

  local subscriber = state.subscribers[name]
  if not subscriber then
    subscriber = {
      enabled = false,
      callbacks = callbacks,
    }
    state.subscribers[name] = subscriber
    state.subscriberOrder[#state.subscriberOrder + 1] = name
  else
    subscriber.callbacks = callbacks
  end

  RebuildSubscriberRoutes()
end

function Runtime:SetSubscriberEnabled(name, enabled)
  local subscriber = state.subscribers[name]
  if subscriber then
    subscriber.enabled = enabled == true
  end
end

function Runtime:GetViewer(key)
  local entry = state.viewers[key]
  if not entry then
    return nil
  end

  if state.enabled then
    self:BindViewer(key, "get")
    return entry.frame
  end

  return entry.resolver()
end

function Runtime:GetViewerKey(viewer)
  local entry = GetEntry(viewer)
  return entry and entry.key or nil
end

function Runtime:GetViewerItems(viewerOrKey)
  local entry = GetEntry(viewerOrKey)
  return entry and entry.items or EMPTY
end

function Runtime:GetViewerGenerations(viewerOrKey)
  local entry = GetEntry(viewerOrKey)
  if not entry then
    return 0, 0
  end

  return entry.itemGeneration or 0, entry.layoutGeneration or 0
end

function Runtime:MaskHas(mask, flag)
  return bit_band(mask or 0, flag or 0) ~= 0
end

function Runtime:MarkViewerDirty(viewerOrKey, mask, reason)
  MarkViewerDirty(GetEntry(viewerOrKey), mask, reason)
end

function Runtime:MarkAllViewersDirty(mask, reason)
  if not state.enabled then
    return
  end

  for index = 1, #state.viewerOrder do
    MarkViewerDirty(state.viewers[state.viewerOrder[index]], mask, reason)
  end
end

function Runtime:Flush()
  FlushRuntime(state.flushFrame)
end

function Runtime:ClearDirty()
  state.flushFrame:Hide()
  ClearWorkQueue()

  for index = 1, #state.viewerOrder do
    local entry = state.viewers[state.viewerOrder[index]]
    if entry then
      entry.dirtyMask = 0
      entry.dirtyReason = nil
      entry.scanQueued = false
      entry.scanReason = nil
      entry.acquireQueued = false
      entry.rebindQueued = false
    end
  end
end

function Runtime:BindViewer(key, reason)
  local entry = state.viewers[key]
  if not entry then
    return nil, false
  end

  if IsPresentationSuspended() then
    return entry.frame, false
  end

  local viewer = entry.resolver()
  if viewer and viewer:IsForbidden() then
    viewer = nil
  end

  if entry.frame == viewer then
    return viewer, false
  end

  local previousViewer = entry.frame
  if previousViewer then
    ReleaseViewer(entry, "viewer-replaced")
  end

  entry.frame = viewer

  if viewer then
    state.viewerByFrame[viewer] = entry
    HookViewer(entry)
  end

  Dispatch("OnViewerChanged", key, viewer, previousViewer, reason or "bind")

  if viewer then
    ScanViewer(entry, reason or "bind")
    MarkViewerDirty(entry, Runtime.Dirty.ALL, reason or "bind")
  end

  return viewer, true
end

function Runtime:RefreshViewer(key, reason)
  local viewer, changed = self:BindViewer(key, reason or "refresh")
  local entry = state.viewers[key]
  if viewer and entry and not changed then
    ScanViewer(entry, reason or "refresh")
  end
end

function Runtime:RefreshAllViewers(reason)
  for index = 1, #state.viewerOrder do
    self:RefreshViewer(state.viewerOrder[index], reason or "refresh-all")
  end
end

function Runtime:QueueAllViewerScans(reason)
  if not state.enabled then
    return
  end

  for index = 1, #state.viewerOrder do
    local entry = state.viewers[state.viewerOrder[index]]
    entry.scanQueued = true
    entry.scanReason = reason or entry.scanReason or "queued-all"
    QueueEntry(entry)
  end
end

local function OnRuntimeEvent(_, event, ...)
  if not state.enabled then
    return
  end

  local arg1, arg2 = ...

  if event == "ADDON_LOADED" and arg1 ~= "Blizzard_CooldownViewer" then
    return
  end

  if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 ~= "player" then
    return
  end

  if event == "TRAIT_CONFIG_UPDATED" then
    local activeConfigID = C_ClassTalents.GetActiveConfigID()
    if arg1 and activeConfigID and arg1 ~= activeConfigID then
      return
    end
  end

  local dataRestrictionsCleared = event == "PLAYER_ENTERING_WORLD"
    or event == "PLAYER_REGEN_ENABLED"
    or (event == "ADDON_RESTRICTION_STATE_CHANGED"
      and arg2 == Enum.AddOnRestrictionState.Inactive)

  if event == "LOADING_SCREEN_ENABLED" then
    state.worldTransitionActive = true
  elseif event == "LOADING_SCREEN_DISABLED" then
    state.worldTransitionActive = false
  elseif dataRestrictionsCleared and not IsDataRestricted() then
    state.worldTransitionActive = false
  end

  Dispatch("OnLifecycleEvent", event, ...)

  if event == "PLAYER_TARGET_CHANGED" then
    for index = 1, #state.viewerOrder do
      local entry = state.viewers[state.viewerOrder[index]]
      if entry and entry.frame then
        Dispatch("OnViewerTargetChanged", entry.key, entry.frame)
      end
    end
  end

  if dataRestrictionsCleared and not IsDataRestricted() then
    for index = 1, #state.viewerOrder do
      local entry = state.viewers[state.viewerOrder[index]]
      if entry and (entry.acquireQueued == true or entry.rebindQueued == true) then
        QueueEntry(entry)
      end
    end
  end

  if (event == "LOADING_SCREEN_DISABLED"
      or (dataRestrictionsCleared and not IsDataRestricted()))
    and not IsPresentationSuspended()
    and state.workHead
  then
    state.flushFrame:Show()
  end
end

function Runtime:Enable()
  if state.enabled then
    return
  end

  state.enabled = true
  state.worldTransitionActive = false

  for index = 1, #LIFECYCLE_EVENTS do
    state.eventFrame:RegisterEvent(LIFECYCLE_EVENTS[index])
  end
end

function Runtime:Disable()
  if not state.enabled then
    return
  end

  state.enabled = false
  state.worldTransitionActive = false
  state.eventFrame:UnregisterAllEvents()
  state.flushFrame:Hide()
  ClearWorkQueue()

  for index = 1, #state.viewerOrder do
    local entry = state.viewers[state.viewerOrder[index]]
    if entry then
      ReleaseViewer(entry, "runtime-disable")
      entry.dirtyMask = 0
      entry.dirtyReason = nil
      entry.scanQueued = false
      entry.scanReason = nil
      entry.acquireQueued = false
      entry.rebindQueued = false
      entry.frame = nil
    end
  end
end

OnRuntimeEvent = P:Def("Runtime.OnRuntimeEvent", OnRuntimeEvent)
state.eventFrame:SetScript("OnEvent", OnRuntimeEvent)

Runtime:RegisterViewer("EssentialCooldownViewer", function()
  return _G.EssentialCooldownViewer
end)

Runtime:RegisterViewer("UtilityCooldownViewer", function()
  return _G.UtilityCooldownViewer
end)

Runtime:RegisterViewer("BuffIconCooldownViewer", function()
  return _G.BuffIconCooldownViewer
end, true)

Runtime:RegisterViewer("BuffBarCooldownViewer", function()
  return _G.BuffBarCooldownViewer
end, true)

function Runtime:IsDataRestricted()
  return IsDataRestricted()
end

function Runtime:IsPresentationSuspended()
  return IsPresentationSuspended()
end

Dispatch = P:Def("Runtime.Dispatch", Dispatch)
MarkViewerDirty = P:Def("Runtime.MarkViewerDirty", MarkViewerDirty)
MarkItemMembershipChanged = P:Def("Runtime.MarkItemMembershipChanged", MarkItemMembershipChanged)
FlushRuntime = P:Def("Runtime.FlushRuntime", FlushRuntime)
AcquireItem = P:Def("Runtime.AcquireItem", AcquireItem)
ReleaseItem = P:Def("Runtime.ReleaseItem", ReleaseItem)
ScanViewer = P:Def("Runtime.ScanViewer", ScanViewer)
ReleaseViewer = P:Def("Runtime.ReleaseViewer", ReleaseViewer)
HookViewer = P:Def("Runtime.HookViewer", HookViewer)
Runtime.RegisterViewer = P:Def("Runtime:RegisterViewer", Runtime.RegisterViewer)
Runtime.RegisterSubscriber = P:Def("Runtime:RegisterSubscriber", Runtime.RegisterSubscriber)
Runtime.SetSubscriberEnabled = P:Def("Runtime:SetSubscriberEnabled", Runtime.SetSubscriberEnabled)
Runtime.GetViewer = P:Def("Runtime:GetViewer", Runtime.GetViewer)
Runtime.GetViewerKey = P:Def("Runtime:GetViewerKey", Runtime.GetViewerKey)
Runtime.GetViewerItems = P:Def("Runtime:GetViewerItems", Runtime.GetViewerItems)
Runtime.GetViewerGenerations = P:Def("Runtime:GetViewerGenerations", Runtime.GetViewerGenerations)
Runtime.MaskHas = P:Def("Runtime:MaskHas", Runtime.MaskHas)
Runtime.MarkViewerDirty = P:Def("Runtime:MarkViewerDirty", Runtime.MarkViewerDirty)
Runtime.MarkAllViewersDirty = P:Def("Runtime:MarkAllViewersDirty", Runtime.MarkAllViewersDirty)
Runtime.Flush = P:Def("Runtime:Flush", Runtime.Flush)
Runtime.ClearDirty = P:Def("Runtime:ClearDirty", Runtime.ClearDirty)
Runtime.BindViewer = P:Def("Runtime:BindViewer", Runtime.BindViewer)
Runtime.RefreshViewer = P:Def("Runtime:RefreshViewer", Runtime.RefreshViewer)
Runtime.RefreshAllViewers = P:Def("Runtime:RefreshAllViewers", Runtime.RefreshAllViewers)
Runtime.QueueAllViewerScans = P:Def("Runtime:QueueAllViewerScans", Runtime.QueueAllViewerScans)
Runtime.IsDataRestricted = P:Def("Runtime:IsDataRestricted", Runtime.IsDataRestricted)
Runtime.IsPresentationSuspended = P:Def("Runtime:IsPresentationSuspended", Runtime.IsPresentationSuspended)
Runtime.Enable = P:Def("Runtime:Enable", Runtime.Enable)
Runtime.Disable = P:Def("Runtime:Disable", Runtime.Disable)

state.flushFrame:SetScript("OnUpdate", FlushRuntime)
