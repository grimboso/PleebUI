local _, ns = ...

local Runtime = {}
ns.PCMRuntime = Runtime

local C_Secrets = C_Secrets
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local bit_band = bit.band

Runtime.Dirty = {
  LAYOUT = 1,
  FONT = 2,
  SKIN = 4,
}

local enabled = false
local initializing = true
local subscribers = {}
local subscriberOrder = {}
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local LIFECYCLE_EVENTS = {
  "ADDON_LOADED",
  "PLAYER_ENTERING_WORLD",
  "LOADING_SCREEN_DISABLED",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_TARGET_CHANGED",
  "ADDON_RESTRICTION_STATE_CHANGED",
  "PLAYER_SPECIALIZATION_CHANGED",
  "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
  "ACTIVE_COMBAT_CONFIG_CHANGED",
  "PLAYER_TALENT_UPDATE",
  "PLAYER_PVP_TALENT_UPDATE",
  "ACTIVE_TALENT_GROUP_CHANGED",
  "TRAIT_CONFIG_UPDATED",
  "SPELLS_CHANGED",
  "PLAYER_EQUIPMENT_CHANGED",
  "EDIT_MODE_LAYOUTS_UPDATED",
  "COOLDOWN_VIEWER_DATA_LOADED",
  "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED",
  "COOLDOWN_VIEWER_TABLE_HOTFIXED",
}

local function IsDataRestricted()
  return InCombatLockdown()
    or (not initializing and (
      C_Secrets.ShouldAurasBeSecret()
      or C_Secrets.ShouldCooldownsBeSecret()
    ))
end

local function DispatchLifecycleEvent(event, ...)
  for index = 1, #subscriberOrder do
    local subscriber = subscribers[subscriberOrder[index]]
    if subscriber and subscriber.enabled == true then
      local callback = subscriber.callbacks.OnLifecycleEvent
      if callback then
        callback(event, ...)
      end
    end
  end
end

function Runtime:RegisterSubscriber(name, callbacks)
  local subscriber = subscribers[name]
  if not subscriber then
    subscriber = { enabled = false }
    subscribers[name] = subscriber
    subscriberOrder[#subscriberOrder + 1] = name
  end
  subscriber.callbacks = callbacks
end

function Runtime:SetSubscriberEnabled(name, active)
  local subscriber = subscribers[name]
  if subscriber then
    subscriber.enabled = active == true
  end
end

function Runtime:MaskHas(mask, flag)
  return bit_band(mask or 0, flag or 0) ~= 0
end

function Runtime:IsDataRestricted()
  return IsDataRestricted()
end

function Runtime:IsAuraRestricted()
  return InCombatLockdown()
    or (not initializing and C_Secrets.ShouldAurasBeSecret() == true)
end

function Runtime:IsInitializing()
  return initializing
end

function Runtime:FinishInitialization()
  initializing = false
end

function Runtime:Enable()
  if enabled then return end
  enabled = true
  for index = 1, #LIFECYCLE_EVENTS do
    eventFrame:RegisterEvent(LIFECYCLE_EVENTS[index])
  end
end

function Runtime:Disable()
  if not enabled then return end
  enabled = false
  eventFrame:UnregisterAllEvents()
  if initializing then
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  if not enabled then
    if event == "PLAYER_ENTERING_WORLD" then
      initializing = false
      eventFrame:UnregisterAllEvents()
    end
    return
  end

  local arg1 = ...
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

  DispatchLifecycleEvent(event, ...)
end)

local P = select(1, ns.Pleebug:DropIn(Runtime, { name = "PCM", bucket = "Runtime" }))
DispatchLifecycleEvent = P:Def("Runtime.DispatchLifecycleEvent", DispatchLifecycleEvent)
Runtime.RegisterSubscriber = P:Def("Runtime:RegisterSubscriber", Runtime.RegisterSubscriber)
Runtime.SetSubscriberEnabled = P:Def("Runtime:SetSubscriberEnabled", Runtime.SetSubscriberEnabled)
Runtime.MaskHas = P:Def("Runtime:MaskHas", Runtime.MaskHas)
Runtime.IsDataRestricted = P:Def("Runtime:IsDataRestricted", Runtime.IsDataRestricted)
Runtime.IsAuraRestricted = P:Def("Runtime:IsAuraRestricted", Runtime.IsAuraRestricted)
Runtime.IsInitializing = P:Def("Runtime:IsInitializing", Runtime.IsInitializing)
Runtime.FinishInitialization = P:Def("Runtime:FinishInitialization", Runtime.FinishInitialization)
Runtime.Enable = P:Def("Runtime:Enable", Runtime.Enable)
Runtime.Disable = P:Def("Runtime:Disable", Runtime.Disable)
