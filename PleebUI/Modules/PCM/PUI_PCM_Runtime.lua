local _, ns = ...

local Runtime = {}
ns.PCMRuntime = Runtime

local C_Secrets = C_Secrets
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local enabled = false
local initializing = true
local trackedSpells = {}
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
  "SPELL_UPDATE_ICON",
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

local SPELL_IDENTITY_EVENTS = {
  SPELLS_CHANGED = true,
  COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED = true,
  PLAYER_SPECIALIZATION_CHANGED = true,
  ACTIVE_PLAYER_SPECIALIZATION_CHANGED = true,
  PLAYER_TALENT_UPDATE = true,
  PLAYER_PVP_TALENT_UPDATE = true,
  ACTIVE_TALENT_GROUP_CHANGED = true,
  ACTIVE_COMBAT_CONFIG_CHANGED = true,
  TRAIT_CONFIG_UPDATED = true,
  PLAYER_ENTERING_WORLD = true,
  COOLDOWN_VIEWER_DATA_LOADED = true,
  COOLDOWN_VIEWER_TABLE_HOTFIXED = true,
}

local function IsTrackedSpellKnown(spellID)
  local known = C_SpellBook.IsSpellKnownOrInSpellBook(spellID, Enum.SpellBookSpellBank.Player)
  if not issecretvalue(known) and known == true then return true end
  known = C_SpellBook.IsSpellKnownOrInSpellBook(spellID, Enum.SpellBookSpellBank.Pet)
  return not issecretvalue(known) and known == true
end

function Runtime:ResolveTrackedSpell(spellID)
  if issecretvalue(spellID) or type(spellID) ~= "number" or spellID <= 0 then
    return nil, false
  end
  local cached = trackedSpells[spellID]
  if cached then return cached.spellID, cached.known end

  local baseSpellID = C_Spell.GetBaseSpell(spellID)
  if issecretvalue(baseSpellID) or type(baseSpellID) ~= "number" or baseSpellID <= 0 then
    return nil, false
  end
  local overrideSpellID = C_Spell.GetOverrideSpell(baseSpellID)
  if issecretvalue(overrideSpellID) or type(overrideSpellID) ~= "number" or overrideSpellID <= 0 then
    return nil, false
  end
  local exists = C_Spell.DoesSpellExist(overrideSpellID)
  if issecretvalue(exists) or exists ~= true then return nil, false end

  local known = IsTrackedSpellKnown(spellID)
    or IsTrackedSpellKnown(baseSpellID)
    or IsTrackedSpellKnown(overrideSpellID)
  if not known then
    for _, entry in ipairs(ns.PCMAbilityCatalog:GetEntries()) do
      local equivalentSpellID
      if entry.baseSpellID == spellID or entry.baseSpellID == baseSpellID then
        equivalentSpellID = entry.overrideSpellID
      elseif entry.overrideSpellID == spellID or entry.overrideSpellID == baseSpellID then
        equivalentSpellID = entry.baseSpellID
      end
      if equivalentSpellID and IsTrackedSpellKnown(equivalentSpellID) then
        local equivalentBaseSpellID = C_Spell.GetBaseSpell(equivalentSpellID)
        if issecretvalue(equivalentBaseSpellID)
          or type(equivalentBaseSpellID) ~= "number"
          or equivalentBaseSpellID <= 0
        then
          return nil, false
        end
        local resolvedSpellID = C_Spell.GetOverrideSpell(equivalentBaseSpellID)
        if not issecretvalue(resolvedSpellID) and type(resolvedSpellID) == "number" and resolvedSpellID > 0 then
          overrideSpellID = resolvedSpellID
          known = true
          break
        end
      end
    end
  end

  trackedSpells[spellID] = { spellID = overrideSpellID, known = known }
  return overrideSpellID, known
end

ns.PCMAbilityCatalog:RegisterListener(Runtime, function()
  wipe(trackedSpells)
end)

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
  wipe(trackedSpells)
  for index = 1, #LIFECYCLE_EVENTS do
    eventFrame:RegisterEvent(LIFECYCLE_EVENTS[index])
  end
end

function Runtime:Disable()
  if not enabled then return end
  enabled = false
  wipe(trackedSpells)
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

  if SPELL_IDENTITY_EVENTS[event] then wipe(trackedSpells) end
  DispatchLifecycleEvent(event, ...)
end)

local P = select(1, ns.Pleebug:DropIn(Runtime, { name = "PCM", bucket = "Runtime" }))
DispatchLifecycleEvent = P:Def("Runtime.DispatchLifecycleEvent", DispatchLifecycleEvent)
Runtime.ResolveTrackedSpell = P:Def("Runtime:ResolveTrackedSpell", Runtime.ResolveTrackedSpell)
Runtime.RegisterSubscriber = P:Def("Runtime:RegisterSubscriber", Runtime.RegisterSubscriber)
Runtime.SetSubscriberEnabled = P:Def("Runtime:SetSubscriberEnabled", Runtime.SetSubscriberEnabled)
Runtime.IsDataRestricted = P:Def("Runtime:IsDataRestricted", Runtime.IsDataRestricted)
Runtime.IsAuraRestricted = P:Def("Runtime:IsAuraRestricted", Runtime.IsAuraRestricted)
Runtime.IsInitializing = P:Def("Runtime:IsInitializing", Runtime.IsInitializing)
Runtime.FinishInitialization = P:Def("Runtime:FinishInitialization", Runtime.FinishInitialization)
Runtime.Enable = P:Def("Runtime:Enable", Runtime.Enable)
Runtime.Disable = P:Def("Runtime:Disable", Runtime.Disable)
