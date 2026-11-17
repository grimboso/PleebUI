local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace
if not ns.Client.IsForever then
  return
end

local DamageMeters = ns.Modules.DamageMeters
local IsSecret = ns.DamageMeterUtil.IsSecret

local sources, pool = {}, {}
local session = { combatSources = sources }
ns.DamageMeterThreat = session

local partyUnits, partyPets, raidUnits, raidPets = {}, {}, {}, {}
local groupTokens = { player = true, pet = true }
for index = 1, 40 do
  local unit, pet = "raid" .. index, "raidpet" .. index
  raidUnits[index], raidPets[index] = unit, pet
  groupTokens[unit], groupTokens[pet] = true, true
end
for index = 1, 4 do
  local unit, pet = "party" .. index, "partypet" .. index
  partyUnits[index], partyPets[index] = unit, pet
  groupTokens[unit], groupTokens[pet] = true, true
end

local events = CreateFrame("Frame")
local active, groupedOnly, watching, pending, followTicker, mob
local Refresh
local TRACKING_EVENTS = {
  "PLAYER_TARGET_CHANGED",
  "UNIT_PET",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
}
local pull = { name = "Pull Aggro", isPullThreat = true, threatPercent = 100, order = 0 }
local count

local function IsAttackable(unit)
  local attackable = UnitCanAttack("player", unit)
  return not IsSecret(attackable) and attackable
end

local function AddSource(unit, owner)
  local exists = UnitExists(unit)
  if IsSecret(exists) or not exists then
    return
  end

  local tanking, _, percent, _, amount = UnitDetailedThreatSituation(unit, mob)
  if IsSecret(amount) or IsSecret(percent) or IsSecret(tanking)
    or not amount or amount <= 0 or not percent
  then
    return
  end

  count = count + 1
  local source = pool[count]
  if not source then
    source = {}
    pool[count] = source
  end

  local name = UnitName(unit)
  local _, class = UnitClass(owner or unit)
  local isPlayer = not owner and UnitIsUnit(unit, "player")
  source.name = not IsSecret(name) and name or ""
  source.classFilename = not IsSecret(class) and class or false
  source.specIconID = owner and 132161 or nil
  source.isLocalPlayer = not IsSecret(isPlayer) and isPlayer == true
  source.totalAmount = amount
  source.threatPercent = percent
  source.tanking = tanking
  source.order = count
  sources[count] = source
  return source
end

local function ByThreat(left, right)
  if left.totalAmount ~= right.totalAmount then
    return left.totalAmount > right.totalAmount
  end
  return left.order < right.order
end

local function Rebuild()
  local followTarget, nextMob
  if watching then
    local friendly = UnitIsFriend("player", "target")
    followTarget = not IsSecret(friendly) and friendly
    if followTarget then
      if IsAttackable("targettarget") then
        nextMob = "targettarget"
      end
    elseif IsAttackable("target") then
      nextMob = "target"
    end
  end
  if nextMob then
    local dead = UnitIsDeadOrGhost(nextMob)
    if not IsSecret(dead) and dead then
      nextMob = nil
    end
  end

  if nextMob ~= mob then
    mob = nextMob
    if mob then
      events:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
      events:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    else
      events:UnregisterEvent("UNIT_THREAT_LIST_UPDATE")
      events:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    end
  end

  local hadRows, oldLabel = #sources > 0, session.label
  wipe(sources)
  count = 0
  local name = mob and UnitName(mob)
  session.label = not IsSecret(name) and name or nil
  if mob then
    local player
    if IsInRaid() then
      for index = 1, GetNumGroupMembers() do
        local unit = raidUnits[index]
        local source = AddSource(unit)
        if source and source.isLocalPlayer then
          player = source
        end
        AddSource(raidPets[index], unit)
      end
    else
      player = AddSource("player")
      AddSource("pet", "player")
      for index = 1, GetNumSubgroupMembers() do
        local unit = partyUnits[index]
        AddSource(unit)
        AddSource(partyPets[index], unit)
      end
    end

    if player and player.tanking == false and player.threatPercent > 0 then
      pull.totalAmount = player.totalAmount * 100 / player.threatPercent
      sources[count + 1] = pull
    end
    table.sort(sources, ByThreat)
    local rank = 0
    for index = 1, #sources do
      local source = sources[index]
      if not source.isPullThreat then
        rank = rank + 1
        source.threatRank = rank
      end
    end
  end
  session.maxAmount = sources[1] and sources[1].totalAmount or 0

  if hadRows or #sources > 0 or oldLabel ~= session.label then
    DamageMeters:RefreshThreatWindows()
  end
  return followTarget and InCombatLockdown()
end

local function QueueRefresh()
  if not pending then
    pending = C_Timer.NewTimer(0.2, Refresh)
  end
end

Refresh = function()
  if pending then
    pending:Cancel()
    pending = nil
  end

  local shouldWatch = not groupedOnly or IsInGroup()
  if shouldWatch ~= watching then
    watching = shouldWatch
    if watching then
      for _, event in ipairs(TRACKING_EVENTS) do
        events:RegisterEvent(event)
      end
      events:RegisterUnitEvent("UNIT_TARGET", "target")
      events:RegisterUnitEvent("UNIT_FLAGS", "target")
    else
      for _, event in ipairs(TRACKING_EVENTS) do
        events:UnregisterEvent(event)
      end
      events:UnregisterEvent("UNIT_TARGET")
      events:UnregisterEvent("UNIT_FLAGS")
    end
  end

  local follow = Rebuild()
  -- Threat events do not report the derived targettarget token directly.
  if follow and not followTicker then
    followTicker = C_Timer.NewTicker(0.5, QueueRefresh)
  elseif not follow and followTicker then
    followTicker:Cancel()
    followTicker = nil
  end
end

events:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_TARGET_CHANGED" then
    Refresh()
    return
  end

  if pending then
    return
  end
  if event == "UNIT_THREAT_LIST_UPDATE" and not IsSecret(unit) and unit ~= mob then
    local same = UnitIsUnit(unit, mob)
    if not IsSecret(same) and not same then
      return
    end
  elseif (event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_PET")
    and not IsSecret(unit) and not groupTokens[unit]
  then
    return
  end

  QueueRefresh()
end)

function session.SetActive(enabled, requireGroup)
  if active == enabled then
    if enabled and groupedOnly ~= requireGroup then
      groupedOnly = requireGroup
      Refresh()
    end
    return
  end
  active = enabled
  groupedOnly = requireGroup
  if enabled then
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    Refresh()
  else
    events:UnregisterAllEvents()
    if pending then
      pending:Cancel()
      pending = nil
    end
    if followTicker then
      followTicker:Cancel()
      followTicker = nil
    end
    watching, mob, session.label, session.maxAmount = nil, nil, nil, 0
    wipe(sources)
  end
end
