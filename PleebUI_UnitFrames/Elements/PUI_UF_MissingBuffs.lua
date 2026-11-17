local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace
if not ns.Client.IsForever then return end

local familiesByClass = {
  PRIEST = {
    { names = { 1243, 21562 }, ranks = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 } },
    { names = { 14752, 27681 }, ranks = { 14752, 14818, 14819, 27841, 27681 } },
    { names = { 976, 27683 }, ranks = { 976, 10957, 10958, 16874, 27683 }, matchAuraID = true },
  },
  MAGE = {
    { names = { 1459, 23028 }, ranks = { 1459, 1460, 1461, 10156, 10157, 23028 } },
  },
  DRUID = {
    { names = { 1126, 21849 }, ranks = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 } },
    { names = { 467 }, ranks = { 467, 782, 1075, 8914, 9756, 9910 }, thorns = true },
  },
  PALADIN = {
    { names = { 20217, 25898 }, ranks = { 20217, 25898 } },
    { names = { 19740, 25782 }, ranks = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916 } },
    { names = { 19742, 25894 }, ranks = { 19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918 } },
    { names = { 1038, 25895 }, ranks = { 1038, 25895 } },
    { names = { 19977, 25890 }, ranks = { 19977, 19978, 19979, 25890 } },
  },
}

local class = select(2, UnitClass("player"))
local families = familiesByClass[class]
if not families then return end

local oUF = ns.oUF
local Round = ns.Pixel.Round
local elementName = "PUIMissingBuffs"
local controller = CreateFrame("Frame")
local active = {}
local trackedNames = {}
local known = {}
local textures = {}
local roleBlessing = { TANK = 2, HEALER = 3, DAMAGER = 4 }
local isPaladin = class == "PALADIN"
local readingAuras = false

local function RefreshSpellbook()
  local changed = false
  wipe(trackedNames)
  for index, family in ipairs(families) do
    local readable = true
    local learned
    for _, spellID in ipairs(family.ranks) do
      if C_Secrets.ShouldSpellAuraBeSecret(spellID) then
        readable = false
      end
      if C_SpellBook.IsSpellKnown(spellID) then
        learned = spellID
      end
    end

    local wasReadable = family.auraNames ~= nil
    family.auraNames = nil
    if readable and (learned or isPaladin) then
      local names = {}
      for _, spellID in ipairs(family.names) do
        local name = C_Spell.GetSpellName(spellID)
        if name then
          names[#names + 1] = name
        end
      end
      if #names == #family.names then
        family.auraNames = names
        for _, name in ipairs(names) do
          trackedNames[name] = true
        end
      end
    end

    if family.auraNames and learned and not textures[learned] then
      textures[learned] = C_Spell.GetSpellTexture(learned)
    end
    local castable = family.auraNames and learned and textures[learned] and learned or nil
    if known[index] ~= castable or wasReadable ~= (family.auraNames ~= nil) then
      changed = true
    end
    known[index] = castable
  end
  return changed
end

local function BuffPresent(unit, family, instances)
  if not family.auraNames then return nil end
  if family.matchAuraID then
    -- Absorption potions can share the resistance buff's name.
    for _, spellID in ipairs(family.ranks) do
      local aura = C_UnitAuras.GetUnitAuraBySpellID(unit, spellID)
      if issecretvalue(aura) then return nil end
      if aura then
        local instanceID = aura.auraInstanceID
        if not issecretvalue(instanceID) and instanceID then
          instances[instanceID] = true
        end
        return true
      end
    end
    return false
  end
  for _, name in ipairs(family.auraNames) do
    local aura = C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL")
    if issecretvalue(aura) then return nil end
    if aura then
      local instanceID = aura.auraInstanceID
      if not issecretvalue(instanceID) and instanceID then
        instances[instanceID] = true
      end
      return true
    end
  end
  return false
end

local function MissingBlessing(unit, role, instances)
  local index = roleBlessing[role]
  if index then
    if known[index] and BuffPresent(unit, families[index], instances) == false then
      return known[index]
    end
    return
  end

  for _, family in ipairs(families) do
    if BuffPresent(unit, family, instances) ~= false then return end
  end
  for i = 1, #families do
    if known[i] then return known[i] end
  end
end

local function ShowIcon(frame, state, slot, spellID)
  local icon = state.icons[slot]
  if not icon then
    icon = frame.TextureParent:CreateTexture(nil, "OVERLAY", nil, 5)
    icon:SetPoint("BOTTOMLEFT", frame.Health, "BOTTOMLEFT", Round(2 + (slot - 1) * 13), Round(2))
    icon:SetSize(Round(12), Round(12))
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    state.icons[slot] = icon
  end
  icon:SetTexture(textures[spellID])
  icon:Show()
end

local function CanReadMember(unit)
  if issecretvalue(unit) or not unit or not IsInGroup() then return false end
  local exists = UnitExists(unit)
  if issecretvalue(exists) or not exists then return false end
  local connected = UnitIsConnected(unit)
  local visible = UnitIsVisible(unit)
  return not issecretvalue(connected) and connected and not issecretvalue(visible) and visible
end

local function Paint(frame, state, unit)
  local count = 0
  wipe(state.instances)
  if readingAuras and not InCombatLockdown() and not C_Secrets.ShouldAurasBeSecret()
    and CanReadMember(unit)
  then
    local role
    if isPaladin or state.thornsOnTanks then
      role = UnitGroupRolesAssigned(unit)
    end
    if isPaladin then
      local spellID
      if next(known) and not issecretvalue(role) then
        spellID = MissingBlessing(unit, role, state.instances)
      end
      if spellID then
        count = 1
        ShowIcon(frame, state, count, spellID)
      end
    else
      for index, family in ipairs(families) do
        local needsThorns = not family.thorns or not state.thornsOnTanks
          or (not issecretvalue(role) and role == "TANK")
        if known[index] and needsThorns and BuffPresent(unit, family, state.instances) == false then
          count = count + 1
          ShowIcon(frame, state, count, known[index])
        end
      end
    end
  end
  for i = count + 1, #state.icons do
    state.icons[i]:Hide()
  end
end

local function RelevantAuraChange(info, instances)
  if issecretvalue(info) or not info then return true end
  if issecretvalue(info.isFullUpdate) or info.isFullUpdate then return true end
  local added, removed = info.addedAuras, info.removedAuraInstanceIDs
  if issecretvalue(added) or issecretvalue(removed) then return true end
  if added then
    for _, aura in ipairs(added) do
      if issecretvalue(aura) then return true end
      local name = aura.name
      if issecretvalue(name) or (name and trackedNames[name]) then return true end
    end
  end
  if removed then
    for _, instanceID in ipairs(removed) do
      if issecretvalue(instanceID) or instances[instanceID] then return true end
    end
  end
  return false
end

local dirty = {}
local pendingUpdate

local function FlushUpdates()
  pendingUpdate = nil
  for frame in pairs(dirty) do
    local state = active[frame]
    if state then Paint(frame, state, frame.__unit) end
  end
  wipe(dirty)
end

local function QueueUpdate(frame)
  dirty[frame] = true
  if not pendingUpdate then
    pendingUpdate = C_Timer.NewTimer(0, FlushUpdates)
  end
end

local function CancelUpdates()
  if pendingUpdate then
    pendingUpdate:Cancel()
    pendingUpdate = nil
  end
  wipe(dirty)
end

local function UpdateUnit(frame, event, unit, info)
  local state = active[frame]
  if state and readingAuras and not InCombatLockdown() and not issecretvalue(unit) and unit == frame.__unit
    and (event ~= "UNIT_AURA" or RelevantAuraChange(info, state.instances))
  then
    QueueUpdate(frame)
  end
end

local function SetUnitEvents(frame, state, enabled)
  if state.listening == enabled then return end
  state.listening = enabled
  if enabled then
    frame:RegisterEvent("UNIT_AURA", UpdateUnit)
    frame:RegisterEvent("UNIT_CONNECTION", UpdateUnit)
  else
    frame:UnregisterEvent("UNIT_AURA", UpdateUnit)
    frame:UnregisterEvent("UNIT_CONNECTION", UpdateUnit)
  end
end

local function RefreshTrackedFrames()
  for frame, state in pairs(active) do
    SetUnitEvents(frame, state, readingAuras and next(known) ~= nil)
    Paint(frame, state, frame.__unit)
  end
end

local function SyncTracking(enteringCombat)
  CancelUpdates()
  controller:UnregisterAllEvents()
  readingAuras = false
  if not next(active) then return end

  controller:RegisterEvent("PLAYER_REGEN_ENABLED")
  if not enteringCombat and not InCombatLockdown() then
    controller:RegisterEvent("PLAYER_REGEN_DISABLED")
    controller:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    if not C_Secrets.ShouldAurasBeSecret() then
      controller:RegisterEvent("PLAYER_ENTERING_WORLD")
      controller:RegisterEvent("SPELLS_CHANGED")
      controller:RegisterEvent("PLAYER_ROLES_ASSIGNED")
      controller:RegisterEvent("GROUP_ROSTER_UPDATE")
      readingAuras = true
      RefreshSpellbook()
    end
  end

  RefreshTrackedFrames()
end

controller:SetScript("OnEvent", function(_, event)
  if event == "SPELLS_CHANGED" then
    if readingAuras and not InCombatLockdown() and not C_Secrets.ShouldAurasBeSecret()
      and RefreshSpellbook()
    then
      CancelUpdates()
      RefreshTrackedFrames()
    end
  elseif event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE" then
    for frame in pairs(active) do QueueUpdate(frame) end
  else
    SyncTracking(event == "PLAYER_REGEN_DISABLED")
  end
end)

local function Deactivate(frame)
  local state = active[frame]
  if not state then return end
  active[frame] = nil
  dirty[frame] = nil
  SetUnitEvents(frame, state, false)
  for _, icon in ipairs(state.icons) do
    icon:Hide()
  end
  if not next(active) then
    CancelUpdates()
    controller:UnregisterAllEvents()
    readingAuras = false
  end
end

local function Refresh(frame)
  if not frame:IsVisible() then return end
  local state = frame.PUIMissingBuffs
  local first = not next(active)
  active[frame] = state
  if first then
    SyncTracking()
  elseif readingAuras and not InCombatLockdown() then
    SetUnitEvents(frame, state, next(known) ~= nil)
    QueueUpdate(frame)
  end
end

local function Enable(frame)
  if not frame.PUIMissingBuffs then return false end
  Refresh(frame)
  return true
end

oUF:AddElement(elementName, Refresh, Enable, Deactivate)

function ns.UFIndicators.ConfigureMissingBuffs(frame, config, isPet)
  if config.showMissingBuffs ~= true or isPet or frame.isChild then
    frame:DisableElement(elementName)
    return
  end

  local state = frame.PUIMissingBuffs
  if not state then
    state = { icons = {}, instances = {}, listening = false }
    frame.PUIMissingBuffs = state
    frame:HookScript("OnHide", Deactivate)
  end
  state.thornsOnTanks = config.missingBuffsThornsOnTanks == true
  if frame:IsElementEnabled(elementName) then
    Refresh(frame)
  else
    frame:EnableElement(elementName)
  end
end
