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
local worldTransitionActive = false
local subscribers = {}
local subscriberOrder = {}
local eventFrame = CreateFrame("Frame")

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

local function IsDataRestricted()
  return InCombatLockdown()
    or C_Secrets.ShouldAurasBeSecret()
    or C_Secrets.ShouldCooldownsBeSecret()
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

function Runtime:IsPresentationSuspended()
  return worldTransitionActive == true
end

function Runtime:Enable()
  if enabled then return end
  enabled = true
  worldTransitionActive = false
  for index = 1, #LIFECYCLE_EVENTS do
    eventFrame:RegisterEvent(LIFECYCLE_EVENTS[index])
  end
end

function Runtime:Disable()
  if not enabled then return end
  enabled = false
  worldTransitionActive = false
  eventFrame:UnregisterAllEvents()
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  if not enabled then return end

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

  if event == "LOADING_SCREEN_ENABLED" then
    worldTransitionActive = true
  elseif event == "LOADING_SCREEN_DISABLED" then
    worldTransitionActive = IsDataRestricted()
  elseif event == "PLAYER_ENTERING_WORLD"
    or event == "PLAYER_REGEN_ENABLED"
    or (event == "ADDON_RESTRICTION_STATE_CHANGED"
      and arg2 == Enum.AddOnRestrictionState.Inactive)
  then
    if not IsDataRestricted() then
      worldTransitionActive = false
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
Runtime.IsPresentationSuspended = P:Def("Runtime:IsPresentationSuspended", Runtime.IsPresentationSuspended)
Runtime.Enable = P:Def("Runtime:Enable", Runtime.Enable)
Runtime.Disable = P:Def("Runtime:Disable", Runtime.Disable)
