local _, ns = ...

local TotemTracker = {
  bindingsBySpellID = {},
  knownSpellIDs = {},
  activeSlots = {},
}
ns.TotemTracker = TotemTracker

local summonSpellIDs = {
  [2484] = 2484,
  [5394] = 5394,
  [8143] = 8143,
  [383013] = 383013,
  [51485] = 51485,
  [192058] = 192058,
  [192077] = 192077,
  [98008] = 98008,
  [108280] = 108280,
  [444995] = 444995,
  [198103] = 198103,
  [188592] = 114050,
  [191717] = 191634,
  [1251781] = 1251781,
  [104316] = 104316,
  [265187] = 265187,
  [205180] = 205180,
  [1122] = 1122,
  [34433] = 34433,
  [26573] = 26573,
  [132578] = 132578,
  [325197] = 325197,
  [322118] = 322118,
}
local summonSequences = { [104316] = 1251781 }
local procSpellIDs = { PALADIN = 26573, PRIEST = 34433 }
local petOverrides = {
  [114050] = { talent = 117013, spellID = 118291, duration = 24 },
}
local castSpellIDs = {}
for displaySpellID, castSpellID in pairs(summonSpellIDs) do
  castSpellIDs[castSpellID] = true
  TotemTracker.knownSpellIDs[displaySpellID] = true
  TotemTracker.knownSpellIDs[castSpellID] = true
end
for _, override in pairs(petOverrides) do
  TotemTracker.knownSpellIDs[override.spellID] = true
end

local class = UnitClassBase("player")
local trackElementalSlots = ns.Client.IsForever and class == "SHAMAN"
local monitor = CreateFrame("Frame")
local listeners = {}
local spellListeners = {}
local slotBindings = {}
local petBindings = {}
local petTimers = {}
local pendingSlots = {}
local pendingSlotSet = {}
local queuedSpellID
local sequence = 0

local function PublishBindings()
  local bindings = TotemTracker.bindingsBySpellID
  wipe(bindings)
  for _, binding in pairs(slotBindings) do
    local previous = bindings[binding.spellID]
    if not previous or binding.sequence > previous.sequence then
      bindings[binding.spellID] = binding
    end
  end
  for spellID, binding in pairs(petBindings) do
    bindings[spellID] = binding
    bindings[binding.spellID] = binding
  end
  for displaySpellID, castSpellID in pairs(summonSpellIDs) do
    local displayBinding = bindings[displaySpellID]
    local castBinding = bindings[castSpellID]
    local binding = displayBinding
    if castBinding and (not binding or castBinding.sequence > binding.sequence) then
      binding = castBinding
    end
    if binding then
      bindings[displaySpellID] = binding
      bindings[castSpellID] = binding
    end
  end
end

local function NotifyListeners()
  if next(spellListeners) ~= nil then
    PublishBindings()
  end
  for owner, callback in pairs(listeners) do
    callback(owner)
  end
end

local function ReadSlot(slot, duration)
  local active, _, _, _, icon, _, spellID = GetTotemInfo(slot)
  if trackElementalSlots then
    if duration == nil
      or (not issecretvalue(active) and not active)
      or (not duration:HasSecretValues() and duration:IsZero())
    then
      TotemTracker.activeSlots[slot] = nil
    else
      local state = TotemTracker.activeSlots[slot] or {}
      state.duration = duration
      state.icon = not issecretvalue(icon) and icon or nil
      TotemTracker.activeSlots[slot] = state
    end
  end
  return spellID
end

local function SeedSlots()
  for slot = 1, GetNumTotemSlots() do
    local duration = GetTotemDuration(slot)
    local spellID = ReadSlot(slot, duration)
    if duration == nil then
      slotBindings[slot] = nil
    elseif not issecretvalue(spellID) then
      if spellID and spellID > 0 then
        sequence = sequence + 1
        slotBindings[slot] = { slot = slot, spellID = spellID, duration = duration, sequence = sequence }
      else
        slotBindings[slot] = nil
      end
    elseif slotBindings[slot] then
      slotBindings[slot].duration = duration
    end
  end
end

local function FlushSlots()
  monitor:SetScript("OnUpdate", nil)
  table.sort(pendingSlots)
  for _, slot in ipairs(pendingSlots) do
    local previous = slotBindings[slot]
    slotBindings[slot] = nil
    local duration = GetTotemDuration(slot)
    local nativeSpellID
    if trackElementalSlots or (duration ~= nil and not queuedSpellID) then
      nativeSpellID = ReadSlot(slot, duration)
    end
    if duration ~= nil then
      local spellID = queuedSpellID
      if spellID then
        queuedSpellID = summonSequences[spellID]
      else
        if not issecretvalue(nativeSpellID) and nativeSpellID and nativeSpellID > 0 then
          spellID = nativeSpellID
        else
          spellID = previous and previous.spellID or procSpellIDs[class]
        end
      end
      if spellID then
        sequence = sequence + 1
        slotBindings[slot] = { slot = slot, spellID = spellID, duration = duration, sequence = sequence }
      end
    end
  end
  wipe(pendingSlots)
  wipe(pendingSlotSet)
  NotifyListeners()
end

monitor:SetScript("OnEvent", function(_, event, arg1, arg2, spellID)
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    -- Cast identities can be secret even though the totem update supplies a public slot.
    if issecretvalue(spellID) then
      queuedSpellID = nil
      return
    end
    local override = petOverrides[spellID]
    if override and C_SpellBook.IsSpellKnown(override.talent) then
      queuedSpellID = nil
      if petTimers[spellID] then
        petTimers[spellID]:Cancel()
      end
      local duration = C_DurationUtil.CreateDuration()
      duration:SetTimeFromStart(GetTime(), override.duration)
      sequence = sequence + 1
      petBindings[spellID] = { spellID = override.spellID, duration = duration, sequence = sequence }
      petTimers[spellID] = C_Timer.NewTimer(override.duration, function()
        petTimers[spellID] = nil
        petBindings[spellID] = nil
        NotifyListeners()
      end)
      NotifyListeners()
    elseif castSpellIDs[spellID] then
      queuedSpellID = spellID
    end
  elseif event == "PLAYER_TOTEM_UPDATE" then
    if not pendingSlotSet[arg1] then
      pendingSlotSet[arg1] = true
      pendingSlots[#pendingSlots + 1] = arg1
    end
    monitor:SetScript("OnUpdate", FlushSlots)
  elseif event == "PLAYER_ENTERING_WORLD" then
    queuedSpellID = nil
    monitor:SetScript("OnUpdate", nil)
    wipe(pendingSlots)
    wipe(pendingSlotSet)
    SeedSlots()
    NotifyListeners()
  end
end)

function TotemTracker:RegisterListener(owner, callback, slotsOnly)
  if listeners[owner] then
    return
  end
  if next(listeners) == nil then
    monitor:RegisterEvent("PLAYER_TOTEM_UPDATE")
    monitor:RegisterEvent("PLAYER_ENTERING_WORLD")
    SeedSlots()
  end
  if not slotsOnly then
    if next(spellListeners) == nil then
      monitor:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
      PublishBindings()
    end
    spellListeners[owner] = true
  end
  listeners[owner] = callback
  callback(owner)
end

function TotemTracker:UnregisterListener(owner)
  listeners[owner] = nil
  if spellListeners[owner] then
    spellListeners[owner] = nil
    if next(spellListeners) == nil then
      monitor:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
      queuedSpellID = nil
      for _, timer in pairs(petTimers) do
        timer:Cancel()
      end
      wipe(petTimers)
      wipe(petBindings)
      wipe(self.bindingsBySpellID)
    end
  end
  if next(listeners) == nil then
    monitor:UnregisterAllEvents()
    monitor:SetScript("OnUpdate", nil)
    sequence = 0
    wipe(slotBindings)
    wipe(pendingSlots)
    wipe(pendingSlotSet)
    wipe(self.activeSlots)
  end
end

local P = select(1, ns.Pleebug:DropIn(TotemTracker, { name = "PUI_TotemTracker" }))
FlushSlots = P:Def("TotemTracker.FlushSlots", FlushSlots)
SeedSlots = P:Def("TotemTracker.SeedSlots", SeedSlots)
TotemTracker.RegisterListener = P:Def("TotemTracker:RegisterListener", TotemTracker.RegisterListener)
TotemTracker.UnregisterListener = P:Def("TotemTracker:UnregisterListener", TotemTracker.UnregisterListener)
