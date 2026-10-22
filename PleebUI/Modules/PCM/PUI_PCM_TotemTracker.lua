local _, ns = ...

local TotemTracker = {
  bindingsBySpellID = {},
  knownSpellIDs = {},
}
ns.PCMTotemTracker = TotemTracker

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
local monitor = CreateFrame("Frame")
local listeners = {}
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
  PublishBindings()
  for owner, callback in pairs(listeners) do
    callback(owner)
  end
end

local function SeedSlots()
  for slot = 1, GetNumTotemSlots() do
    local spellID = select(7, GetTotemInfo(slot))
    local duration = GetTotemDuration(slot)
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
    if duration ~= nil then
      local spellID = queuedSpellID
      if spellID then
        queuedSpellID = summonSequences[spellID]
      else
        local nativeSpellID = select(7, GetTotemInfo(slot))
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

function TotemTracker:RegisterListener(owner, callback)
  if listeners[owner] then
    return
  end
  if next(listeners) == nil then
    monitor:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    monitor:RegisterEvent("PLAYER_TOTEM_UPDATE")
    monitor:RegisterEvent("PLAYER_ENTERING_WORLD")
    SeedSlots()
    PublishBindings()
  end
  listeners[owner] = callback
  callback(owner)
end

function TotemTracker:UnregisterListener(owner)
  listeners[owner] = nil
  if next(listeners) ~= nil then
    return
  end
  monitor:UnregisterAllEvents()
  monitor:SetScript("OnUpdate", nil)
  queuedSpellID = nil
  sequence = 0
  for _, timer in pairs(petTimers) do
    timer:Cancel()
  end
  wipe(petTimers)
  wipe(petBindings)
  wipe(slotBindings)
  wipe(pendingSlots)
  wipe(pendingSlotSet)
  wipe(self.bindingsBySpellID)
end

local P = select(1, ns.Pleebug:DropIn(TotemTracker, { name = "PCM", bucket = "TotemTracker" }))
FlushSlots = P:Def("TotemTracker.FlushSlots", FlushSlots)
SeedSlots = P:Def("TotemTracker.SeedSlots", SeedSlots)
TotemTracker.RegisterListener = P:Def("TotemTracker:RegisterListener", TotemTracker.RegisterListener)
TotemTracker.UnregisterListener = P:Def("TotemTracker:UnregisterListener", TotemTracker.UnregisterListener)
