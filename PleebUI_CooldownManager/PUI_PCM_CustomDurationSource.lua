local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace

local DurationSource = {}
ns.PCMCustomDurationSource = DurationSource

DurationSource.sourceValues = {
  automatic = "Automatic",
  ground = "Ground effect / Totem / Summons",
  aura = "Buff/debuff",
}
DurationSource.sourceHelp = "Automatic\nUses an available ground effect, totem or summon duration first, then the buff/debuff."
  .. "\n\n" .. DurationSource.sourceValues.ground
  .. "\nTracks the effect's remaining lifetime, even when you leave its area."
  .. "\nPossible uses, when the game provides a matching duration:"
  .. "\n- Ground effects, such as Consecration."
  .. "\n- Totems, such as Shaman totems."
  .. "\n- Temporary summons, such as elementals and guardians."
  .. "\n- Duplicates, such as Augmentation Evoker duplicates."
  .. "\nStays inactive when no matching duration is available."
  .. "\n\nBuff/debuff\nTracks the player buff or target debuff, including the buff from standing in a ground effect."
  .. "\n\nCreate separate bars or icons for the effect's lifetime and its buff/debuff."

local TotemTracker = ns.PCMTotemTracker
local records = {}
local listening = false

function DurationSource:Normalize(cfg)
  if cfg.kind ~= "duration" then
    return "aura"
  end
  if cfg.durationSource ~= "automatic" and cfg.durationSource ~= "ground" then
    cfg.durationSource = "aura"
  end
  return cfg.durationSource
end

function DurationSource:GetAuraUnitAndFilter(cfg)
  local mode = cfg.auraTrackMode
  if mode == "automatic" then
    local spellID = tonumber(cfg.trackedSpellID)
    local best
    for _, entry in ipairs(ns.PCMCatalog:GetEntries()) do
      if entry.hasAura then
        for _, identity in ipairs(entry.identitySpellIDs) do
          if identity == spellID then
            if not best or (cfg.__puiCooldownID ~= nil and entry.cooldownID == cfg.__puiCooldownID) then
              best = entry
            end
            break
          end
        end
      end
    end
    mode = best and not best.selfAura and "target_debuff" or "player_buff"
  end
  if mode == "target_debuff" then
    return "target", "HARMFUL|PLAYER", mode
  end
  return "player", "HELPFUL|PLAYER", "player_buff"
end

local function RefreshRecord(owner, record, force)
  local mode = DurationSource:Normalize(record.cfg)
  local selected
  if mode ~= "aura" then
    for spellID in pairs(record.spellIDs) do
      local binding = TotemTracker.bindingsBySpellID[spellID]
      if binding and binding.sequence ~= record.expiredSequence
        and (not selected or binding.sequence > selected.sequence)
      then
        selected = binding
      end
    end
  end
  local duration = selected and selected.duration or nil
  if selected and selected.slot then
    duration = GetTotemDuration(selected.slot)
  end
  local useAura = mode == "aura" or (mode == "automatic" and duration == nil)
  local sequence = duration ~= nil and selected.sequence or nil
  if force or record.sequence ~= sequence or record.useAura ~= useAura then
    record.sequence = sequence
    record.useAura = useAura
    record.callback(owner, duration, useAura)
  end
end

local function RefreshBindings()
  for owner, record in pairs(records) do
    RefreshRecord(owner, record, false)
  end
end

local function RefreshSubscription()
  local needed = next(records) ~= nil
  if needed == listening then return end
  listening = needed
  if needed then
    TotemTracker:RegisterListener(DurationSource, RefreshBindings)
    return true
  else
    TotemTracker:UnregisterListener(DurationSource)
  end
end

function DurationSource:Attach(owner, cfg, spellIDs, callback)
  local mode = self:Normalize(cfg)
  if mode == "aura" then
    self:Detach(owner)
    callback(owner, nil, true)
    return
  end
  local record = records[owner]
  if not record or record.cfg ~= cfg or record.spellID ~= cfg.trackedSpellID or record.mode ~= mode then
    record = { cfg = cfg, spellID = cfg.trackedSpellID, mode = mode }
    records[owner] = record
  end
  record.spellIDs = spellIDs
  record.callback = callback
  if not RefreshSubscription() then
    RefreshRecord(owner, record, true)
  end
end

function DurationSource:Expire(owner)
  local record = records[owner]
  if not record or record.sequence == nil then return end
  record.expiredSequence = record.sequence
  RefreshRecord(owner, record, true)
end

function DurationSource:Detach(owner)
  records[owner] = nil
  RefreshSubscription()
end

local P = select(1, ns.Pleebug:DropIn(DurationSource, { name = "PCM", bucket = "CustomDurationSource" }))
RefreshRecord = P:Def("CustomDurationSource.RefreshRecord", RefreshRecord)
RefreshBindings = P:Def("CustomDurationSource.RefreshBindings", RefreshBindings)
DurationSource.Normalize = P:Def("CustomDurationSource:Normalize", DurationSource.Normalize)
DurationSource.GetAuraUnitAndFilter = P:Def("CustomDurationSource:GetAuraUnitAndFilter", DurationSource.GetAuraUnitAndFilter)
DurationSource.Attach = P:Def("CustomDurationSource:Attach", DurationSource.Attach)
DurationSource.Expire = P:Def("CustomDurationSource:Expire", DurationSource.Expire)
DurationSource.Detach = P:Def("CustomDurationSource:Detach", DurationSource.Detach)
