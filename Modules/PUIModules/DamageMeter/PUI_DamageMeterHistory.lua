local _, ns = ...

local History = ns.DamageMeterHistory

local _G = _G
local C_ChallengeMode = _G.C_ChallengeMode
local C_DamageMeter = _G.C_DamageMeter
local C_DeathRecap = _G.C_DeathRecap
local C_EncodingUtil = _G.C_EncodingUtil
local C_MythicPlus = _G.C_MythicPlus
local C_RestrictedActions = _G.C_RestrictedActions
local Enum = _G.Enum
local GetInstanceInfo = _G.GetInstanceInfo
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local UnitAffectingCombat = _G.UnitAffectingCombat
local issecretvalue = _G.issecretvalue
local math_abs = _G.math.abs
local math_max = _G.math.max
local next = _G.next
local pairs = _G.pairs
local string_format = _G.string.format
local table_insert = _G.table.insert
local table_remove = _G.table.remove
local table_sort = _G.table.sort
local time = _G.time
local type = _G.type

local function IsSecret(value)
  return issecretvalue(value) == true
end

local function IsPlainNumber(value)
  return not IsSecret(value) and type(value) == "number"
end

local function IsPlainString(value)
  return not IsSecret(value) and type(value) == "string"
end

local function GetHistoryOptions(self)
  return self.owner.db.profile.history
end

local function GetHistoryStorage(self)
  local charDB = self.owner.db.char
  charDB.history = charDB.history or {}
  charDB.history.savedSegments = charDB.history.savedSegments or {}
  charDB.history.savedDungeons = charDB.history.savedDungeons or {}
  charDB.history.dungeonStatistics = nil
  charDB.history.raidProgression = nil
  charDB.history.savedRaids = nil
  charDB.history.activeRaid = nil
  return charDB.history
end

local function HasPlainSourceIdentity(source)
  local sourceGUID = source.sourceGUID
  local sourceCreatureID = source.sourceCreatureID
  local name = source.name
  local classFilename = source.classFilename

  if IsSecret(sourceGUID)
    or IsSecret(sourceCreatureID)
    or IsSecret(name)
    or IsSecret(classFilename)
  then
    return false
  end

  return (type(sourceGUID) == "string" and sourceGUID ~= "")
    or type(sourceCreatureID) == "number"
    or (type(name) == "string" and name ~= "")
end

local function CopyCombatSource(source, validateOnly)
  if IsSecret(source) or not source then
    return nil
  end

  if not HasPlainSourceIdentity(source) then
    return nil
  end

  local totalAmount = source.totalAmount
  local amountPerSecond = source.amountPerSecond
  if not IsPlainNumber(totalAmount) or not IsPlainNumber(amountPerSecond) then
    return nil
  end

  local deathRecapID = source.deathRecapID
  if IsSecret(deathRecapID) then
    return nil
  end
  if type(deathRecapID) ~= "number" then
    deathRecapID = 0
  end

  local deathTimeSeconds = source.deathTimeSeconds
  if IsSecret(deathTimeSeconds) then
    return nil
  end
  if type(deathTimeSeconds) ~= "number" then
    deathTimeSeconds = 0
  end

  local name = source.name
  if not IsPlainString(name) then
    return nil
  end

  local classFilename = source.classFilename
  if IsSecret(classFilename) or type(classFilename) ~= "string" then
    classFilename = ""
  end

  local specIconID = source.specIconID
  if IsSecret(specIconID) or type(specIconID) ~= "number" then
    specIconID = 0
  end

  local sourceGUID = source.sourceGUID
  if IsSecret(sourceGUID) then
    return nil
  end

  local sourceCreatureID = source.sourceCreatureID
  if IsSecret(sourceCreatureID) then
    return nil
  end

  local isLocalPlayer = source.isLocalPlayer
  if IsSecret(isLocalPlayer) then
    return nil
  end

  local classification = source.classification
  if IsSecret(classification) then
    return nil
  end

  local sourceDisplayType = source.sourceDisplayType
  if IsSecret(sourceDisplayType) then
    return nil
  end

  local factionGroup = source.factionGroup
  if IsSecret(factionGroup) then
    return nil
  end

  if validateOnly then
    return true
  end

  return {
    sourceGUID = sourceGUID,
    sourceCreatureID = sourceCreatureID,
    name = name,
    classFilename = classFilename,
    specIconID = specIconID,
    totalAmount = totalAmount,
    amountPerSecond = amountPerSecond,
    isLocalPlayer = isLocalPlayer == true,
    deathRecapID = deathRecapID,
    deathTimeSeconds = deathTimeSeconds,
    classification = classification,
    sourceDisplayType = sourceDisplayType,
    factionGroup = factionGroup,
  }
end

local function CopyCombatSpellUnitDetails(details)
  if IsSecret(details) or not details then
    return nil
  end

  local unitName = details.unitName
  local unitClassFilename = details.unitClassFilename
  local classification = details.classification
  local isPet = details.isPet
  local isMob = details.isMob
  local amount = details.amount
  local specIconID = details.specIconID

  if not IsPlainString(unitName)
    or not IsPlainString(unitClassFilename)
    or not IsPlainString(classification)
    or IsSecret(isPet)
    or type(isPet) ~= "boolean"
    or IsSecret(isMob)
    or type(isMob) ~= "boolean"
    or not IsPlainNumber(amount)
    or not IsPlainNumber(specIconID)
  then
    return nil
  end

  return {
    unitName = unitName,
    unitClassFilename = unitClassFilename,
    classification = classification,
    isPet = isPet,
    isMob = isMob,
    amount = amount,
    specIconID = specIconID,
  }
end

local function CopyCombatSpell(spell, requireUnitDetails)
  if IsSecret(spell) or not spell then
    return nil
  end

  local spellID = spell.spellID
  local totalAmount = spell.totalAmount
  local amountPerSecond = spell.amountPerSecond
  local creatureName = spell.creatureName
  local overkillAmount = spell.overkillAmount
  local isAvoidable = spell.isAvoidable
  local isDeadly = spell.isDeadly

  if not IsPlainNumber(spellID)
    or not IsPlainNumber(totalAmount)
    or not IsPlainNumber(amountPerSecond)
    or not IsPlainString(creatureName)
    or not IsPlainNumber(overkillAmount)
    or IsSecret(isAvoidable)
    or type(isAvoidable) ~= "boolean"
    or IsSecret(isDeadly)
    or type(isDeadly) ~= "boolean"
  then
    return nil
  end

  local combatSpellDetails = CopyCombatSpellUnitDetails(spell.combatSpellDetails)
  if requireUnitDetails and not combatSpellDetails then
    return nil
  end

  return {
    spellID = spellID,
    totalAmount = totalAmount,
    amountPerSecond = amountPerSecond,
    creatureName = creatureName,
    overkillAmount = overkillAmount,
    isAvoidable = isAvoidable,
    isDeadly = isDeadly,
    combatSpellDetails = combatSpellDetails,
  }
end

local function CopyCombatSessionSource(source, requireUnitDetails)
  if IsSecret(source) or not source then
    return nil
  end

  local combatSpells = source.combatSpells
  local maxAmount = source.maxAmount
  local totalAmount = source.totalAmount
  if IsSecret(combatSpells)
    or type(combatSpells) ~= "table"
    or not IsPlainNumber(maxAmount)
    or not IsPlainNumber(totalAmount)
  then
    return nil
  end

  local copiedSpells = {}
  for index = 1, #combatSpells do
    local spell = CopyCombatSpell(combatSpells[index], requireUnitDetails)
    if not spell then
      return nil
    end
    copiedSpells[#copiedSpells + 1] = spell
  end

  return {
    combatSpells = copiedSpells,
    maxAmount = maxAmount,
    totalAmount = totalAmount,
  }
end

local DEATH_RECAP_EVENT_FIELDS = {
  "absorbed",
  "amount",
  "avoidable",
  "blocked",
  "critical",
  "currentHP",
  "deadly",
  "environmentalType",
  "event",
  "hideCaster",
  "overkill",
  "resisted",
  "sourceName",
  "spellId",
  "spellName",
  "timestamp",
}

local function CopyDeathRecap(recapID)
  if not IsPlainNumber(recapID)
    or recapID <= 0
    or not C_DeathRecap.HasRecapEvents(recapID)
  then
    return nil
  end

  local events = C_DeathRecap.GetRecapEvents(recapID)
  local maxHealth = C_DeathRecap.GetRecapMaxHealth(recapID)
  if IsSecret(events) or type(events) ~= "table" or not IsPlainNumber(maxHealth) then
    return nil
  end

  local copiedEvents = {}
  local highestDamageIndex = 1
  local highestDamageAmount = 0
  local deathTimestamp = 0
  for index = 1, #events do
    local event = events[index]
    if IsSecret(event) or not event then
      return nil
    end

    local copiedEvent = {}
    for fieldIndex = 1, #DEATH_RECAP_EVENT_FIELDS do
      local field = DEATH_RECAP_EVENT_FIELDS[fieldIndex]
      local value = event[field]
      if IsSecret(value) then
        return nil
      end
      copiedEvent[field] = value
    end
    copiedEvents[index] = copiedEvent

    local amount = copiedEvent.amount
    if type(amount) == "number" and math_abs(amount) > highestDamageAmount then
      highestDamageIndex = index
      highestDamageAmount = math_abs(amount)
    end
    local timestamp = copiedEvent.timestamp
    if type(timestamp) == "number" and timestamp > deathTimestamp then
      deathTimestamp = timestamp
    end
  end

  return {
    events = copiedEvents,
    maxHealth = maxHealth,
    highestDamageIndex = highestDamageIndex,
    deathTimestamp = deathTimestamp,
  }
end

local function CanReadCombatSessionSummary(session)
  if IsSecret(session) or not session then
    return false
  end

  local combatSources = session.combatSources
  if IsSecret(combatSources) or not combatSources then
    return false
  end

  local durationSeconds = session.durationSeconds
  local maxAmount = session.maxAmount
  local totalAmount = session.totalAmount
  if durationSeconds ~= nil and not IsPlainNumber(durationSeconds) then
    return false
  end
  if not IsPlainNumber(maxAmount) or not IsPlainNumber(totalAmount) then
    return false
  end

  for index = 1, #combatSources do
    if not CopyCombatSource(combatSources[index], true) then
      return false
    end
  end

  return true
end

local function ShouldCaptureSourceDetails(meterType)
  return meterType ~= Enum.DamageMeterType.Dps
    and meterType ~= Enum.DamageMeterType.Hps
    and meterType ~= Enum.DamageMeterType.Deaths
end

local function CopyCombatSession(sessionID, sessionType, meterType, session, summaryReady)
  if not summaryReady and not CanReadCombatSessionSummary(session) then
    return nil
  end

  local combatSources = session.combatSources
  local durationSeconds = session.durationSeconds
  local maxAmount = session.maxAmount
  local totalAmount = session.totalAmount
  local captureSourceDetails = ShouldCaptureSourceDetails(meterType)
  local requireUnitDetails = meterType == Enum.DamageMeterType.EnemyDamageTaken
  local copiedSources = {}
  for index = 1, #combatSources do
    local source = CopyCombatSource(combatSources[index])
    if not source then
      return nil
    end

    local hasSourceGUID = type(source.sourceGUID) == "string" and source.sourceGUID ~= ""
    local hasSourceCreatureID = type(source.sourceCreatureID) == "number"
    if captureSourceDetails and (hasSourceGUID or hasSourceCreatureID) then
      local sessionSource
      if sessionID then
        sessionSource = C_DamageMeter.GetCombatSessionSourceFromID(
          sessionID,
          meterType,
          source.sourceGUID,
          source.sourceCreatureID
        )
      else
        sessionSource = C_DamageMeter.GetCombatSessionSourceFromType(
          sessionType,
          meterType,
          source.sourceGUID,
          source.sourceCreatureID
        )
      end
      local copiedSessionSource = CopyCombatSessionSource(sessionSource, requireUnitDetails)
      if not copiedSessionSource then
        return nil
      end
      source.combatSessionSource = copiedSessionSource
    end

    if meterType == Enum.DamageMeterType.Deaths then
      source.deathRecapData = CopyDeathRecap(source.deathRecapID)
    end

    copiedSources[#copiedSources + 1] = source
  end

  return {
    combatSources = copiedSources,
    maxAmount = maxAmount,
    totalAmount = totalAmount,
    durationSeconds = durationSeconds or 0,
  }
end

local function CompressHistoryData(data)
  local serialized = C_EncodingUtil.SerializeCBOR(data)
  return C_EncodingUtil.CompressString(
    serialized,
    Enum.CompressionMethod.Deflate,
    Enum.CompressionLevel.OptimizeForSize
  )
end

local function DecompressHistoryData(compressedData)
  local serialized = C_EncodingUtil.DecompressString(
    compressedData,
    Enum.CompressionMethod.Deflate
  )
  return C_EncodingUtil.DeserializeCBOR(serialized)
end


local function FindDungeonSegment(dungeon, sessionID)
  local segments = dungeon.segments or {}
  for index = 1, #segments do
    if segments[index].sessionID == sessionID then
      return segments[index]
    end
  end
  return nil
end

local function CopyEncounterToDungeonSegment(segment, encounter)
  if not segment or not encounter then
    return
  end

  segment.encounterID = encounter.encounterID
  segment.encounterName = encounter.encounterName
  segment.difficultyID = encounter.difficultyID
  segment.difficultyName = encounter.difficultyName
  segment.groupSize = encounter.groupSize
  segment.instanceType = encounter.instanceType
  segment.instanceID = encounter.instanceID
  segment.instanceName = encounter.instanceName
  segment.instanceDifficultyID = encounter.instanceDifficultyID
  segment.encounterSuccess = encounter.success
  segment.encounterEndedAt = encounter.endedAt
end

local function BuildEncounterFromDungeonSegment(segment)
  if not segment.encounterID then
    return nil
  end

  return {
    sessionID = segment.sessionID,
    encounterID = segment.encounterID,
    encounterName = segment.encounterName,
    difficultyID = segment.difficultyID,
    difficultyName = segment.difficultyName,
    groupSize = segment.groupSize,
    instanceType = segment.instanceType,
    instanceID = segment.instanceID,
    instanceName = segment.instanceName,
    instanceDifficultyID = segment.instanceDifficultyID,
    success = segment.encounterSuccess,
    endedAt = segment.encounterEndedAt,
  }
end

local function BuildRetainedDungeonSegments(segments)
  local retained = {}
  segments = segments or {}

  for index = 1, #segments do
    local segment = segments[index]
    retained[index] = {
      sessionID = segment.sessionID,
      startedAt = segment.startedAt,
      endedAt = segment.endedAt,
      durationSeconds = segment.durationSeconds,
      meters = segment.meters,
      encounterID = segment.encounterID,
      encounterName = segment.encounterName,
      difficultyID = segment.difficultyID,
      difficultyName = segment.difficultyName,
      groupSize = segment.groupSize,
      instanceType = segment.instanceType,
      instanceID = segment.instanceID,
      instanceName = segment.instanceName,
      instanceDifficultyID = segment.instanceDifficultyID,
      encounterSuccess = segment.encounterSuccess,
      encounterEndedAt = segment.encounterEndedAt,
    }
  end

  return retained
end

local function BuildRetainedDungeonBossSessionIDs(segments)
  local sessionIDs = {}
  segments = segments or {}

  for index = 1, #segments do
    local segment = segments[index]
    if segment.meters
      and segment.encounterID
      and segment.encounterSuccess == 1
    then
      sessionIDs[#sessionIDs + 1] = segment.sessionID
    end
  end

  return sessionIDs
end

local function BuildCapturedDungeonSegment(segment, snapshot)
  return {
    sessionID = segment.sessionID,
    startedAt = segment.startedAt,
    endedAt = segment.endedAt,
    durationSeconds = snapshot.durationSeconds,
    meters = snapshot.meters,
    encounterID = segment.encounterID,
    encounterName = segment.encounterName,
    difficultyID = segment.difficultyID,
    difficultyName = segment.difficultyName,
    groupSize = segment.groupSize,
    instanceType = segment.instanceType,
    instanceID = segment.instanceID,
    instanceName = segment.instanceName,
    instanceDifficultyID = segment.instanceDifficultyID,
    encounterSuccess = segment.encounterSuccess,
    encounterEndedAt = segment.encounterEndedAt,
  }
end

local function EnsureDungeonSegment(dungeon, record)
  dungeon.segments = dungeon.segments or {}
  local segment = FindDungeonSegment(dungeon, record.sessionID)
  if not segment then
    segment = {
      sessionID = record.sessionID,
      sessionRecordID = record.id,
      startedAt = record.startedAt,
      endedAt = record.endedAt,
    }
    dungeon.segments[#dungeon.segments + 1] = segment
  end
  record.dungeonSegment = segment
  return segment
end

local function SetRecordEnded(record, endedAt, endedGetTime)
  record.endedAt = endedAt
  record.endedGetTime = endedGetTime
  if record.dungeonSegment then
    record.dungeonSegment.endedAt = endedAt
  end
end

local function GetDungeonName(mapID)
  local instanceName, instanceType = GetInstanceInfo()
  if instanceType == "party" and IsPlainString(instanceName) and instanceName ~= "" then
    return instanceName
  end

  local name = C_ChallengeMode.GetMapUIInfo(mapID)
  if IsPlainString(name) and name ~= "" then
    return name
  end

  return "Mythic+"
end

local function GetActiveChallengeMapID()
  local mapID = C_ChallengeMode.GetActiveChallengeMapID()
  if IsPlainNumber(mapID) and mapID > 0 then
    return mapID
  end

  return nil
end

local function BindEncounterToSession(self, encounter, sessionID)
  if not encounter or not IsPlainNumber(sessionID) or sessionID <= 0 then
    return nil
  end

  local previousSessionID = encounter.sessionID
  if previousSessionID and previousSessionID ~= sessionID then
    local previousRecord = self.sessionRecords[previousSessionID]
    if previousRecord and previousRecord.encounter == encounter then
      previousRecord.encounter = nil
    end
  end

  encounter.sessionID = sessionID
  local record = self.sessionRecords[sessionID]
  if record then
    record.encounter = encounter
    CopyEncounterToDungeonSegment(record.dungeonSegment, encounter)
  end
  return record
end

local function GetCurrentSeasonID()
  local seasonID = C_MythicPlus.GetCurrentSeason()
  if IsPlainNumber(seasonID) then
    return seasonID
  end

  return 0
end

local function GetCurrentOverallDungeonScore()
  local score = C_ChallengeMode.GetOverallDungeonScore()
  if IsPlainNumber(score) then
    return score
  end

  return nil
end

local function BuildDungeonDisplayName(name, level)
  if level and level > 0 then
    return name .. " +" .. level
  end

  return name
end

local function CopyPlainNumberList(values)
  local copied = {}
  if IsSecret(values) or type(values) ~= "table" then
    return copied
  end

  for index = 1, #values do
    local value = values[index]
    if IsPlainNumber(value) then
      copied[#copied + 1] = value
    end
  end

  return copied
end

local function CopyCompletionMembers(members)
  local copied = {}
  if IsSecret(members) or type(members) ~= "table" then
    return copied
  end

  for index = 1, #members do
    local member = members[index]
    if not IsSecret(member) and member then
      local memberGUID = member.memberGUID
      local name = member.name
      if IsPlainString(name) and name ~= "" and not IsSecret(memberGUID) then
        copied[#copied + 1] = {
          memberGUID = memberGUID,
          name = name,
        }
      end
    end
  end

  return copied
end

local function EnrichDungeonMembersFromMeters(run, meters)
  local members = run.members
  if not members or not meters then
    return
  end

  for memberIndex = 1, #members do
    local member = members[memberIndex]
    for _, meter in pairs(meters) do
      local combatSources = meter.combatSources or {}
      for sourceIndex = 1, #combatSources do
        local source = combatSources[sourceIndex]
        if source.sourceGUID == member.memberGUID or source.name == member.name then
          if source.classFilename ~= "" then
            member.classFilename = source.classFilename
          end
          if IsPlainNumber(source.specIconID) and source.specIconID > 0 then
            member.specIconID = source.specIconID
          end
          break
        end
      end
      if member.classFilename and member.specIconID then
        break
      end
    end
  end
end

local function GetNextHistoryRecordID(storage, prefix)
  local nextRecordID = storage.nextRecordID
  if type(nextRecordID) ~= "number" then
    nextRecordID = 0
  end
  nextRecordID = nextRecordID + 1
  storage.nextRecordID = nextRecordID
  return string_format("%s:%d:%d", prefix, time(), nextRecordID)
end

function History:ApplyTrackingOptions()
  self:PruneSavedSegments()
  self:PruneSavedDungeons()
end

function History:Initialize(owner, meterTypes)
  self.owner = owner
  self.meterTypes = meterTypes
  self.sessionRecords = {}
  self.latestSessionID = nil
  self.activeEncounter = nil
  self.savedDungeonDataByID = {}
  self.pendingCaptures = {}
  self.paused = true

  GetHistoryStorage(self)
  self:ApplyTrackingOptions()
end

function History:RestoreDungeonSessionRecords()
  local activeDungeon = self:GetActiveDungeon()
  if not activeDungeon then
    return
  end

  activeDungeon.segments = activeDungeon.segments or {}
  for index = 1, #activeDungeon.segments do
    local dungeonSegment = activeDungeon.segments[index]
    local sessionID = dungeonSegment.sessionID
    if IsPlainNumber(sessionID) and sessionID > 0 then
      local record = self.sessionRecords[sessionID]
      if not record then
        record = {
          id = dungeonSegment.sessionRecordID,
          sessionID = sessionID,
          startedAt = dungeonSegment.startedAt,
          endedAt = dungeonSegment.endedAt,
          runID = activeDungeon.runID,
          encounter = BuildEncounterFromDungeonSegment(dungeonSegment),
          dungeonSegment = dungeonSegment,
        }
        self.sessionRecords[sessionID] = record
      else
        record.runID = activeDungeon.runID
        record.dungeonSegment = dungeonSegment
      end
      if not dungeonSegment.endedAt then
        self.latestSessionID = sessionID
      end
    end
  end
end


function History:Pause()
  self.paused = true
  self.activeEncounter = nil
end

function History:Resume()
  self.paused = false
  self:ReconcileDungeonState()
end

local function SessionHasRestrictedValues(session)
  if IsSecret(session) then
    return true
  end
  if not session then
    return false
  end

  local combatSources = session.combatSources
  if IsSecret(combatSources) then
    return true
  end
  if type(combatSources) ~= "table" then
    return false
  end

  for index = 1, #combatSources do
    local source = combatSources[index]
    if IsSecret(source) then
      return true
    end
    if source then
      if IsSecret(source.name)
        or IsSecret(source.sourceGUID)
        or IsSecret(source.totalAmount)
        or IsSecret(source.classFilename)
      then
        return true
      end
    end
  end

  return false
end

function History:CanReadFinishedSessions()
  if self.paused or InCombatLockdown() then
    return false
  end

  if self.owner.playerInCombat or self.owner.waitingForGroupCombatEnd then
    return false
  end

  local activeDungeon = self:GetActiveDungeon()
  if activeDungeon and activeDungeon.completionPending ~= true then
    return false
  end

  local playerInCombat = UnitAffectingCombat("player")
  if IsSecret(playerInCombat) or playerInCombat == true then
    return false
  end

  if C_RestrictedActions.GetAddOnRestrictionState(Enum.AddOnRestrictionType.Combat) ~= 0 then
    return false
  end

  for _, meterType in pairs(self.meterTypes) do
    if SessionHasRestrictedValues(C_DamageMeter.GetCombatSessionFromType(
      Enum.DamageMeterSessionType.Current,
      meterType
    )) then
      return false
    end
    if SessionHasRestrictedValues(C_DamageMeter.GetCombatSessionFromType(
      Enum.DamageMeterSessionType.Overall,
      meterType
    )) then
      return false
    end
  end

  local availableSessions = C_DamageMeter.GetAvailableCombatSessions()
  if IsSecret(availableSessions) or type(availableSessions) ~= "table" then
    return false
  end

  local firstIndex = math_max(1, #availableSessions - 2)
  for index = firstIndex, #availableSessions do
    local sessionInfo = availableSessions[index]
    if IsSecret(sessionInfo) or not sessionInfo then
      return false
    end

    local sessionID = sessionInfo.sessionID
    if not IsPlainNumber(sessionID) or sessionID <= 0 then
      return false
    end

    for _, meterType in pairs(self.meterTypes) do
      if SessionHasRestrictedValues(C_DamageMeter.GetCombatSessionFromID(
        sessionID,
        meterType
      )) then
        return false
      end
    end
  end

  return true
end

function History:GetAvailableSessionIDs()
  local availableSessions = C_DamageMeter.GetAvailableCombatSessions()
  if IsSecret(availableSessions) or type(availableSessions) ~= "table" then
    return nil
  end

  local sessionIDs = {}
  for index = 1, #availableSessions do
    local sessionInfo = availableSessions[index]
    if IsSecret(sessionInfo) or not sessionInfo then
      return nil
    end

    local sessionID = sessionInfo.sessionID
    if not IsPlainNumber(sessionID) or sessionID <= 0 then
      return nil
    end
    sessionIDs[sessionID] = true
  end

  return sessionIDs
end

function History:IsSessionReady(sessionID)
  if not IsPlainNumber(sessionID) or sessionID <= 0 then
    return false
  end

  for _, meterType in pairs(self.meterTypes) do
    local session = C_DamageMeter.GetCombatSessionFromID(sessionID, meterType)
    if SessionHasRestrictedValues(session)
      or not session
      or not CanReadCombatSessionSummary(session)
    then
      return false
    end
  end

  return true
end

function History:OnBlizzardReset()
  local activeDungeon = self:GetActiveDungeon()
  if activeDungeon then
    activeDungeon.segments = {}
  end

  self.sessionRecords = {}
  self.pendingCaptures = {}
  self.latestSessionID = nil
  if self.activeEncounter then
    self.activeEncounter.sessionID = nil
  end
end

function History:OnCombatSessionUpdated(meterType, sessionID)
  if not IsPlainNumber(sessionID) or sessionID <= 0 then
    return
  end

  if meterType ~= self.meterTypes.DAMAGE_DONE then
    return
  end

  local record = self.sessionRecords[sessionID]
  local activeEncounter = self.activeEncounter

  if record
    and self.latestSessionID == sessionID
    and (self.owner.playerInCombat or self.owner.waitingForGroupCombatEnd)
    and (not activeEncounter or activeEncounter.sessionID == sessionID)
  then
    return
  end

  if not record then
    local now = time()
    local instanceName, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    record = {
      id = GetNextHistoryRecordID(GetHistoryStorage(self), "SESSION"),
      sessionID = sessionID,
      startedAt = now,
      startedGetTime = GetTime(),
      instanceName = instanceName,
      instanceType = instanceType,
      instanceID = instanceID,
      difficultyID = difficultyID,
    }
    local activeDungeon = self:GetActiveDungeon()
    if activeDungeon then
      record.runID = activeDungeon.runID
      EnsureDungeonSegment(activeDungeon, record)
    end
    self.sessionRecords[sessionID] = record
  end

  local previousSessionID = self.latestSessionID
  if previousSessionID and previousSessionID ~= sessionID then
    local previous = self.sessionRecords[previousSessionID]
    if previous and not previous.endedAt then
      SetRecordEnded(previous, time(), GetTime())
    end
  end

  self.latestSessionID = sessionID
  if not self.owner.playerInCombat
    and not self.owner.waitingForGroupCombatEnd
    and not record.endedAt
  then
    SetRecordEnded(record, time(), GetTime())
  end

  local encounterSessionID = activeEncounter and activeEncounter.sessionID
  if activeEncounter
    and (not encounterSessionID or sessionID >= encounterSessionID)
  then
    BindEncounterToSession(self, activeEncounter, sessionID)
  end
end

function History:OnCombatEnded()
  local sessionID = self.latestSessionID
  local record = sessionID and self.sessionRecords[sessionID]
  if record and not record.endedAt then
    SetRecordEnded(record, time(), GetTime())
  end
end

function History:GetSavedSegments()
  return GetHistoryStorage(self).savedSegments
end

function History:GetSavedDungeons()
  return GetHistoryStorage(self).savedDungeons
end

function History:GetActiveDungeon()
  return GetHistoryStorage(self).activeDungeon
end

function History:GetSelectionStateKey(selection)
  if not selection then
    return nil
  end

  if selection.kind == "SEGMENT_SAVED" then
    return "SEGMENT_SAVED:" .. selection.segmentID
  end

  if selection.kind == "DUNGEON_SAVED" then
    return "DUNGEON_SAVED:"
      .. selection.savedID
      .. ":"
      .. (selection.view or "OVERALL")
      .. ":"
      .. (selection.sessionID or 0)
  end

  return nil
end

function History:SelectionsEqual(left, right)
  if not left or not right or left.kind ~= right.kind then
    return false
  end

  if left.kind == "SEGMENT_SAVED" then
    return left.segmentID == right.segmentID
  end

  if left.kind == "DUNGEON_SAVED" then
    return left.savedID == right.savedID
      and (left.view or "OVERALL") == (right.view or "OVERALL")
      and left.sessionID == right.sessionID
  end

  return false
end

function History:FindSavedDungeon(savedID)
  local savedDungeons = self:GetSavedDungeons()
  for index = 1, #savedDungeons do
    local saved = savedDungeons[index]
    if saved.id == savedID then
      return saved
    end
  end

  return nil
end

function History:GetSavedDungeonData(saved)
  local data = self.savedDungeonDataByID[saved.id]
  if data then
    return data
  end

  if not saved.compressedData then
    return nil
  end

  data = DecompressHistoryData(saved.compressedData)
  if data then
    self.savedDungeonDataByID[saved.id] = data
  end
  return data
end

function History:GetSavedDungeonSegment(saved, sessionID)
  local data = self:GetSavedDungeonData(saved)
  local segments = data and data.segments or {}
  for index = 1, #segments do
    if segments[index].sessionID == sessionID then
      return segments[index]
    end
  end
  return nil
end

function History:FindSavedSegment(segmentID)
  local segments = self:GetSavedSegments()
  for index = 1, #segments do
    local segment = segments[index]
    if segment.id == segmentID then
      return segment
    end
  end

  return nil
end

function History:GetSession(selection, meterKey)
  if not selection then
    return nil
  end

  if selection.kind == "SEGMENT_SAVED" then
    local segment = self:FindSavedSegment(selection.segmentID)
    if segment then
      return segment.meters and segment.meters[meterKey] or nil
    end
    return nil
  end

  if selection.kind == "DUNGEON_SAVED" then
    local saved = self:FindSavedDungeon(selection.savedID)
    if saved then
      if selection.view == "BOSS" then
        local segment = self:GetSavedDungeonSegment(saved, selection.sessionID)
        return segment and segment.meters and segment.meters[meterKey] or nil
      end
      local data = self:GetSavedDungeonData(saved)
      return data and data.overallMeters and data.overallMeters[meterKey] or nil
    end
    return nil
  end

  return nil
end

function History:GetSessionSource(selection, meterKey, sourceGUID, sourceCreatureID)
  if not selection then
    return nil
  end

  local sourceMeterKey = meterKey
  if meterKey == "DPS" then
    sourceMeterKey = "DAMAGE_DONE"
  elseif meterKey == "HPS" then
    sourceMeterKey = "HEALING_DONE"
  end

  local session = self:GetSession(selection, sourceMeterKey)
  local combatSources = session and session.combatSources
  if not combatSources then
    return nil
  end

  local matchByGUID = type(sourceGUID) == "string" and sourceGUID ~= ""
  local matchByCreatureID = not matchByGUID and type(sourceCreatureID) == "number"
  if not matchByGUID and not matchByCreatureID then
    return nil
  end

  for index = 1, #combatSources do
    local source = combatSources[index]
    if (matchByGUID and source.sourceGUID == sourceGUID)
      or (matchByCreatureID and source.sourceCreatureID == sourceCreatureID)
    then
      return source.combatSessionSource
    end
  end

  return nil
end

function History:GetSelectionDisplay(selection)
  if not selection then
    return nil, nil
  end

  if selection.kind == "SEGMENT_SAVED" then
    local segment = self:FindSavedSegment(selection.segmentID)
    if segment then
      return segment.displayName, segment.durationSeconds
    end
    return nil, nil
  end

  if selection.kind == "DUNGEON_SAVED" then
    local saved = self:FindSavedDungeon(selection.savedID)
    if saved then
      if selection.view == "BOSS" then
        local segment = self:GetSavedDungeonSegment(saved, selection.sessionID)
        if segment then
          return (segment.encounterName or "Boss") .. " — Kill",
            segment.durationSeconds or 0
        end
        return nil, nil
      end
      return saved.name .. " — M+ Overall", saved.runTime or saved.timeInCombat or 0
    end
    return nil, nil
  end

  return nil, nil
end

function History:CaptureTypedSessionSnapshot(sessionType)
  local snapshot = {
    durationSeconds = 0,
    meters = {},
  }
  local sessions = {}

  for meterKey, meterType in pairs(self.meterTypes) do
    local session = C_DamageMeter.GetCombatSessionFromType(sessionType, meterType)
    if IsSecret(session) or not session or not CanReadCombatSessionSummary(session) then
      return snapshot, false
    end
    sessions[meterKey] = session
  end

  for meterKey, meterType in pairs(self.meterTypes) do
    local copied = CopyCombatSession(nil, sessionType, meterType, sessions[meterKey], true)
    if not copied then
      return snapshot, false
    end
    snapshot.meters[meterKey] = copied
  end

  local durationSeconds = C_DamageMeter.GetSessionDurationSeconds(sessionType)
  if not IsPlainNumber(durationSeconds) then
    return snapshot, false
  end
  snapshot.durationSeconds = durationSeconds
  return snapshot, true
end

function History:CaptureSessionSnapshot(sessionID, durationSeconds)
  local snapshot = {
    durationSeconds = durationSeconds or 0,
    meters = {},
  }
  local sessions = {}

  for meterKey, meterType in pairs(self.meterTypes) do
    local session = C_DamageMeter.GetCombatSessionFromID(sessionID, meterType)
    if IsSecret(session) or not session or not CanReadCombatSessionSummary(session) then
      return snapshot, false
    end
    sessions[meterKey] = session
  end

  for meterKey, meterType in pairs(self.meterTypes) do
    local copied = CopyCombatSession(sessionID, nil, meterType, sessions[meterKey], true)
    if not copied then
      return snapshot, false
    end
    snapshot.meters[meterKey] = copied
    if snapshot.durationSeconds <= 0 and copied.durationSeconds > 0 then
      snapshot.durationSeconds = copied.durationSeconds
    end
  end

  return snapshot, true
end

function History:CreateSavedBossKillSegment(record, encounter, durationSeconds)
  if not IsPlainNumber(durationSeconds) then
    durationSeconds = 0
  end

  local encounterName = encounter.encounterName
  return {
    id = GetNextHistoryRecordID(GetHistoryStorage(self), "SEGMENT"),
    modelVersion = 5,
    sessionID = record.sessionID,
    runID = record.runID,
    kind = "BOSS_KILL",
    displayName = (encounterName or "Boss") .. " — Kill",
    durationSeconds = durationSeconds,
    instanceType = encounter.instanceType,
    instanceID = encounter.instanceID,
    instanceName = encounter.instanceName,
    encounterID = encounter.encounterID,
    encounterName = encounterName,
    difficultyID = encounter.difficultyID,
    difficultyName = encounter.difficultyName,
    startedAt = record.startedAt,
    endedAt = record.endedAt,
  }
end

function History:RemoveSavedSegmentAt(index)
  local segments = self:GetSavedSegments()
  local segment = segments[index]
  if not segment then
    return
  end

  self.owner:ClearSelectionsForHistoryRecord("SEGMENT_SAVED", "segmentID", segment.id)
  table_remove(segments, index)
end

function History:PruneSavedSegments()
  local segments = self:GetSavedSegments()
  local options = GetHistoryOptions(self)

  for index = #segments, 1, -1 do
    local segment = segments[index]
    if type(segment.modelVersion) ~= "number"
      or segment.modelVersion < 2
      or type(segment.meters) ~= "table"
      or segment.kind ~= "BOSS_KILL"
    then
      self:RemoveSavedSegmentAt(index)
    end
  end

  table_sort(segments, function(a, b)
    local leftEndedAt = IsPlainNumber(a.endedAt) and a.endedAt or 0
    local rightEndedAt = IsPlainNumber(b.endedAt) and b.endedAt or 0
    if leftEndedAt == rightEndedAt then
      return (a.sessionID or 0) > (b.sessionID or 0)
    end
    return leftEndedAt > rightEndedAt
  end)

  local bossKillLimit = options.saveBossKills == true and options.bossKillsToKeep or 0
  local bossKillCount = 0

  for index = #segments, 1, -1 do
    local segment = segments[index]
    segment.isRecentSegment = nil
    segment.isExcludedFromRecent = nil
    segment.isRetainedBossKill = nil
  end

  for index = 1, #segments do
    local segment = segments[index]
    if segment.isSaved == true then
      segment.isRetainedBossKill = true
    elseif bossKillCount < bossKillLimit then
      segment.isRetainedBossKill = true
      bossKillCount = bossKillCount + 1
    end
  end

  for index = #segments, 1, -1 do
    local segment = segments[index]
    if not segment.isRetainedBossKill
      and segment.isSaved ~= true
    then
      self:RemoveSavedSegmentAt(index)
    end
  end
end

function History:PrepareForLogout()
  self:PruneSavedSegments()
  self:PruneSavedDungeons()
end

function History:PruneSavedDungeons()
  local savedDungeons = self:GetSavedDungeons()
  local options = GetHistoryOptions(self)
  local limit = options.saveKeystones == true and options.dungeonSummariesToKeep or 0

  table_sort(savedDungeons, function(left, right)
    local leftCompletedAt = IsPlainNumber(left.completedAt) and left.completedAt or 0
    local rightCompletedAt = IsPlainNumber(right.completedAt) and right.completedAt or 0
    if leftCompletedAt == rightCompletedAt then
      return (left.startedAt or 0) > (right.startedAt or 0)
    end
    return leftCompletedAt > rightCompletedAt
  end)

  local retainedUnsaved = 0
  for index = 1, #savedDungeons do
    local saved = savedDungeons[index]
    if saved.isSaved == true then
      saved.__puiRetain = true
    elseif retainedUnsaved < limit then
      saved.__puiRetain = true
      retainedUnsaved = retainedUnsaved + 1
    else
      saved.__puiRetain = nil
    end
  end

  for index = #savedDungeons, 1, -1 do
    local saved = savedDungeons[index]
    if saved.__puiRetain then
      saved.__puiRetain = nil
    else
      self:RemoveSavedDungeonAt(index)
    end
  end
end

function History:AddSavedSegment(segment)
  local segments = self:GetSavedSegments()
  segments[#segments + 1] = segment
  self:PruneSavedSegments()
end

function History:RemoveSavedDungeonAt(index)
  local savedDungeons = self:GetSavedDungeons()
  local saved = savedDungeons[index]
  if not saved then
    return
  end

  self.owner:ClearSelectionsForHistoryRecord("DUNGEON_SAVED", "savedID", saved.id)
  self.savedDungeonDataByID[saved.id] = nil
  table_remove(savedDungeons, index)
end

function History:SetSavedSegment(segmentID, savedState)
  local segment = self:FindSavedSegment(segmentID)
  if not segment or segment.kind ~= "BOSS_KILL" then
    return false
  end

  segment.isSaved = savedState == true and true or nil
  self:PruneSavedSegments()
  return true
end

function History:SetSavedDungeon(savedID, savedState)
  local saved = self:FindSavedDungeon(savedID)
  if not saved then
    return false
  end

  saved.isSaved = savedState == true and true or nil
  self:PruneSavedDungeons()
  return true
end

function History:DeleteSavedSegment(segmentID)
  local segments = self:GetSavedSegments()
  for index = 1, #segments do
    local segment = segments[index]
    if segment.id == segmentID then
      if segment.isSaved == true then
        return false
      end
      self:RemoveSavedSegmentAt(index)
      self:PruneSavedSegments()
      return true
    end
  end

  return false
end

function History:DeleteSavedDungeon(savedID)
  local savedDungeons = self:GetSavedDungeons()
  for index = 1, #savedDungeons do
    local saved = savedDungeons[index]
    if saved.id == savedID then
      if saved.isSaved == true then
        return false
      end
      self:RemoveSavedDungeonAt(index)
      self:PruneSavedDungeons()
      return true
    end
  end

  return false
end

function History:GetSectionEntryCount(sectionKey)
  local count = 0
  if sectionKey == "KEYSTONES" then
    local savedDungeons = self:GetSavedDungeons()
    for index = 1, #savedDungeons do
      if savedDungeons[index].isSaved ~= true then
        count = count + 1
      end
    end
    return count
  end

  local segments = self:GetSavedSegments()
  for index = 1, #segments do
    local segment = segments[index]
    if sectionKey == "BOSS_KILLS"
      and segment.isRetainedBossKill
      and segment.isSaved ~= true
    then
      count = count + 1
    end
  end
  return count
end

function History:DeleteSection(sectionKey)
  if sectionKey == "KEYSTONES" then
    local savedDungeons = self:GetSavedDungeons()
    for index = #savedDungeons, 1, -1 do
      if savedDungeons[index].isSaved ~= true then
        self:RemoveSavedDungeonAt(index)
      end
    end
    self:PruneSavedDungeons()
    return
  end

  local segments = self:GetSavedSegments()
  for index = #segments, 1, -1 do
    local segment = segments[index]
    if sectionKey == "BOSS_KILLS"
      and segment.isRetainedBossKill
      and segment.isSaved ~= true
    then
      self:RemoveSavedSegmentAt(index)
    end
  end
  self:PruneSavedSegments()
end

function History:QueueOwnedCapture(record)
  if not record or not record.endedAt then
    return false
  end

  local encounter = record.encounter
  if not encounter or not encounter.endedAt or encounter.success ~= 1 then
    self.pendingCaptures[record.sessionID] = nil
    return false
  end

  local activeDungeon = self:GetActiveDungeon()
  if activeDungeon and record.runID == activeDungeon.runID then
    self.pendingCaptures[record.sessionID] = nil
    return false
  end

  local options = GetHistoryOptions(self)
  if options.saveBossKills ~= true or options.bossKillsToKeep <= 0 then
    self.pendingCaptures[record.sessionID] = nil
    return false
  end

  self.pendingCaptures[record.sessionID] = record
  return true
end

function History:HasPendingCaptures()
  if next(self.pendingCaptures) then
    return true
  end

  local activeDungeon = self:GetActiveDungeon()
  return activeDungeon and activeDungeon.completionPending == true or false
end

function History:ProcessPendingCaptures()
  if not next(self.pendingCaptures) then
    return false, false
  end

  if not self:CanReadFinishedSessions() then
    return false, true
  end

  local records = {}
  for _, record in pairs(self.pendingCaptures) do
    records[#records + 1] = record
  end
  table_sort(records, function(left, right)
    local leftStartedAt = IsPlainNumber(left.startedAt) and left.startedAt or 0
    local rightStartedAt = IsPlainNumber(right.startedAt) and right.startedAt or 0
    if leftStartedAt == rightStartedAt then
      return left.sessionID < right.sessionID
    end
    return leftStartedAt < rightStartedAt
  end)

  local changed = false
  local retryCapture = false
  local options = GetHistoryOptions(self)
  for index = 1, #records do
    local record = records[index]
    local sessionID = record.sessionID
    local encounter = record.encounter
    local activeDungeon = self:GetActiveDungeon()
    local isDungeonBoss = activeDungeon and record.runID == activeDungeon.runID
    local keepBossKill = encounter
      and encounter.endedAt
      and encounter.success == 1
      and not isDungeonBoss
      and options.saveBossKills == true
      and options.bossKillsToKeep > 0

    if not keepBossKill then
      self.pendingCaptures[sessionID] = nil
    elseif not self:IsSessionReady(sessionID) then
      retryCapture = true
    else
      local snapshot, captureComplete = self:CaptureSessionSnapshot(sessionID, 0)
      if captureComplete then
        local segment = self:CreateSavedBossKillSegment(
          record,
          encounter,
          snapshot.durationSeconds
        )
        segment.meters = snapshot.meters
        self:AddSavedSegment(segment)
        self.pendingCaptures[sessionID] = nil
        changed = true
      else
        retryCapture = true
      end
    end
  end

  return changed, retryCapture
end

function History:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
  local instanceName, instanceType, instanceDifficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
  local encounter = {
    encounterID = encounterID,
    encounterName = encounterName,
    difficultyID = difficultyID,
    difficultyName = difficultyName,
    groupSize = groupSize,
    startedGetTime = GetTime(),
    instanceID = instanceID,
    instanceName = instanceName,
    instanceType = instanceType,
    instanceDifficultyID = instanceDifficultyID,
  }
  self.activeEncounter = encounter
end

function History:OnEncounterEnd(
  encounterID,
  encounterName,
  difficultyID,
  groupSize,
  success
)
  local encounter = self.activeEncounter
  if not encounter then
    return
  end

  local durationSeconds = 0
  if IsPlainNumber(encounter.startedGetTime) then
    durationSeconds = math_max(0, GetTime() - encounter.startedGetTime)
  end

  encounter.encounterID = encounterID
  encounter.encounterName = encounterName
  encounter.difficultyID = difficultyID
  encounter.groupSize = groupSize
  encounter.success = success
  encounter.durationSeconds = durationSeconds
  encounter.endedAt = time()

  local record = encounter.sessionID and self.sessionRecords[encounter.sessionID]
  if record then
    record.encounter = encounter
    SetRecordEnded(record, encounter.endedAt, GetTime())
    CopyEncounterToDungeonSegment(record.dungeonSegment, encounter)
  end

  self.activeEncounter = nil
  if record then
    self:QueueOwnedCapture(record)
  end
end

function History:StartDungeon(mapID, beginNewRun)
  mapID = GetActiveChallengeMapID() or mapID
  if not IsPlainNumber(mapID) or mapID <= 0 then
    return false
  end

  local storage = GetHistoryStorage(self)
  if beginNewRun == true
    and storage.activeDungeon
    and storage.activeDungeon.completionPending == true
  then
    storage.activeDungeon = nil
  end

  local level, affixIDs, wasActiveKeystoneCharged = C_ChallengeMode.GetActiveKeystoneInfo()
  if not IsPlainNumber(level) then
    level = 0
  end
  local dungeonName = GetDungeonName(mapID)
  local startedAt = time()

  storage.activeDungeon = {
    modelVersion = 6,
    runID = GetNextHistoryRecordID(storage, "DUNGEON"),
    challengeMapID = mapID,
    name = dungeonName,
    level = level,
    seasonID = GetCurrentSeasonID(),
    affixIDs = CopyPlainNumberList(affixIDs),
    wasActiveKeystoneCharged = not IsSecret(wasActiveKeystoneCharged)
      and wasActiveKeystoneCharged == true,
    scoreBefore = GetCurrentOverallDungeonScore(),
    startedAt = startedAt,
    startedGetTime = GetTime(),
    segments = {},
    completionPending = false,
  }
  return true
end

function History:MarkDungeonCompleted()
  local activeDungeon = self:GetActiveDungeon()
  if not activeDungeon then
    return false
  end

  local completionInfo = C_ChallengeMode.GetChallengeCompletionInfo()
  activeDungeon.completionPending = true
  activeDungeon.completedAt = activeDungeon.completedAt or time()

  if not IsSecret(completionInfo) and completionInfo then
    local onTime = completionInfo.onTime
    local upgradeLevels = completionInfo.keystoneUpgradeLevels
    local runTime = completionInfo.time
    local mapID = completionInfo.mapChallengeModeID
    local level = completionInfo.level
    local practiceRun = completionInfo.practiceRun
    local oldOverallDungeonScore = completionInfo.oldOverallDungeonScore
    local newOverallDungeonScore = completionInfo.newOverallDungeonScore
    local isMapRecord = completionInfo.isMapRecord
    local isAffixRecord = completionInfo.isAffixRecord
    local isEligibleForScore = completionInfo.isEligibleForScore

    if IsPlainNumber(mapID) and mapID > 0 then
      activeDungeon.challengeMapID = mapID
      activeDungeon.name = GetDungeonName(mapID)
    end
    if IsPlainNumber(level) and level > 0 then
      activeDungeon.level = level
    end

    if not IsSecret(onTime) and type(onTime) == "boolean" then
      activeDungeon.onTime = onTime
    end
    if IsPlainNumber(upgradeLevels) then
      activeDungeon.keystoneUpgradeLevels = upgradeLevels
    end
    if IsPlainNumber(runTime) then
      activeDungeon.runTime = runTime / 1000
    end
    if not IsSecret(practiceRun) and type(practiceRun) == "boolean" then
      activeDungeon.practiceRun = practiceRun
    end
    if IsPlainNumber(oldOverallDungeonScore) then
      activeDungeon.oldOverallDungeonScore = oldOverallDungeonScore
    end
    if IsPlainNumber(newOverallDungeonScore) then
      activeDungeon.newOverallDungeonScore = newOverallDungeonScore
    end
    if not IsSecret(isMapRecord) and type(isMapRecord) == "boolean" then
      activeDungeon.isMapRecord = isMapRecord
    end
    if not IsSecret(isAffixRecord) and type(isAffixRecord) == "boolean" then
      activeDungeon.isAffixRecord = isAffixRecord
    end
    if not IsSecret(isEligibleForScore) and type(isEligibleForScore) == "boolean" then
      activeDungeon.isEligibleForScore = isEligibleForScore
    end
    activeDungeon.members = CopyCompletionMembers(completionInfo.members)
  end

  local numDeaths, timeLost = C_ChallengeMode.GetDeathCount()
  if IsPlainNumber(numDeaths) then
    activeDungeon.numDeaths = numDeaths
  end
  if IsPlainNumber(timeLost) then
    activeDungeon.deathTimeLost = timeLost
  end
  return true
end

function History:FinalizePendingDungeon()
  local storage = GetHistoryStorage(self)
  local activeDungeon = storage.activeDungeon
  if not activeDungeon
    or activeDungeon.modelVersion ~= 6
    or activeDungeon.completionPending ~= true
  then
    return false
  end

  local options = GetHistoryOptions(self)
  local keepBossKills = options.saveBossKills == true and options.bossKillsToKeep > 0
  local keepKeystone = options.saveKeystones == true and options.dungeonSummariesToKeep > 0
  if not keepBossKills and not keepKeystone then
    storage.activeDungeon = nil
    return true
  end

  if not self:CanReadFinishedSessions() then
    return false
  end

  local availableSessionIDs = self:GetAvailableSessionIDs()
  if not availableSessionIDs then
    return false
  end

  local dungeonSegments = activeDungeon.segments or {}
  for index = 1, #dungeonSegments do
    local dungeonSegment = dungeonSegments[index]
    local sessionID = dungeonSegment.sessionID
    if dungeonSegment.encounterSuccess == 1
      and IsPlainNumber(sessionID)
      and sessionID > 0
      and availableSessionIDs[sessionID]
      and not self:IsSessionReady(sessionID)
    then
      return false
    end
  end

  local overallSnapshot
  if keepKeystone then
    local overallComplete
    overallSnapshot, overallComplete = self:CaptureTypedSessionSnapshot(
      Enum.DamageMeterSessionType.Overall
    )
    if not overallComplete then
      return false
    end

    local damageDone = overallSnapshot.meters.DAMAGE_DONE
    if not damageDone or #damageDone.combatSources == 0 then
      return false
    end
  end

  local capturedBossSegments = {}
  for index = 1, #dungeonSegments do
    local dungeonSegment = dungeonSegments[index]
    local sessionID = dungeonSegment.sessionID
    if dungeonSegment.encounterSuccess == 1
      and IsPlainNumber(sessionID)
      and sessionID > 0
      and availableSessionIDs[sessionID]
    then
      local snapshot, captureComplete = self:CaptureSessionSnapshot(sessionID, 0)
      if not captureComplete then
        return false
      end
      capturedBossSegments[#capturedBossSegments + 1] = BuildCapturedDungeonSegment(
        dungeonSegment,
        snapshot
      )
    end
  end

  if keepBossKills then
    for index = 1, #capturedBossSegments do
      local dungeonSegment = capturedBossSegments[index]
      local encounter = BuildEncounterFromDungeonSegment(dungeonSegment)
      if encounter then
        local record = {
          sessionID = dungeonSegment.sessionID,
          runID = activeDungeon.runID,
          startedAt = dungeonSegment.startedAt,
          endedAt = dungeonSegment.endedAt,
        }
        local segment = self:CreateSavedBossKillSegment(
          record,
          encounter,
          dungeonSegment.durationSeconds
        )
        segment.meters = dungeonSegment.meters
        self:AddSavedSegment(segment)
      end
    end
  end

  local savedID
  if keepKeystone then
    EnrichDungeonMembersFromMeters(activeDungeon, overallSnapshot.meters)
    local saved = {
      id = activeDungeon.runID,
      modelVersion = 5,
      bossSessionIDs = BuildRetainedDungeonBossSessionIDs(capturedBossSegments),
      name = BuildDungeonDisplayName(activeDungeon.name, activeDungeon.level),
      challengeMapID = activeDungeon.challengeMapID,
      level = activeDungeon.level,
      seasonID = activeDungeon.seasonID,
      affixIDs = activeDungeon.affixIDs,
      wasActiveKeystoneCharged = activeDungeon.wasActiveKeystoneCharged,
      startedAt = activeDungeon.startedAt,
      completedAt = activeDungeon.completedAt or time(),
      runTime = activeDungeon.runTime,
      timeInCombat = overallSnapshot.durationSeconds or 0,
      onTime = activeDungeon.onTime,
      practiceRun = activeDungeon.practiceRun,
      numDeaths = activeDungeon.numDeaths,
      deathTimeLost = activeDungeon.deathTimeLost,
      keystoneUpgradeLevels = activeDungeon.keystoneUpgradeLevels,
      scoreBefore = activeDungeon.scoreBefore,
      oldOverallDungeonScore = activeDungeon.oldOverallDungeonScore,
      newOverallDungeonScore = activeDungeon.newOverallDungeonScore,
      isMapRecord = activeDungeon.isMapRecord,
      isAffixRecord = activeDungeon.isAffixRecord,
      isEligibleForScore = activeDungeon.isEligibleForScore,
      members = activeDungeon.members or {},
    }
    local savedData = {
      overallMeters = overallSnapshot.meters,
      segments = BuildRetainedDungeonSegments(capturedBossSegments),
    }
    saved.compressedData = CompressHistoryData(savedData)
    self.savedDungeonDataByID[saved.id] = savedData
    table_insert(storage.savedDungeons, 1, saved)
    savedID = saved.id
    self:PruneSavedDungeons()
  end

  storage.activeDungeon = nil
  return true, savedID, false
end

function History:ResetDungeon()
  local storage = GetHistoryStorage(self)
  local activeDungeon = storage.activeDungeon
  if not activeDungeon then
    return
  end

  if activeDungeon.completionPending == true then
    return
  end

  storage.activeDungeon = nil
end

function History:ReconcileDungeonState()
  local storage = GetHistoryStorage(self)
  local storedDungeon = storage.activeDungeon
  if storedDungeon and storedDungeon.modelVersion == 6 then
    storedDungeon.segments = storedDungeon.segments or {}
    self:RestoreDungeonSessionRecords()
  end

  local active = C_ChallengeMode.IsChallengeModeActive()

  if active then
    local mapID = GetActiveChallengeMapID()
    if mapID then
      local activeDungeon = storage.activeDungeon
      if not activeDungeon
        or activeDungeon.modelVersion ~= 6
        or activeDungeon.challengeMapID ~= mapID
      then
        self:StartDungeon(mapID, false)
      else
        activeDungeon.name = GetDungeonName(mapID)
        local level, affixIDs, wasActiveKeystoneCharged = C_ChallengeMode.GetActiveKeystoneInfo()
        if IsPlainNumber(level) and level > 0 then
          activeDungeon.level = level
        end
        activeDungeon.seasonID = activeDungeon.seasonID or GetCurrentSeasonID()
        activeDungeon.affixIDs = activeDungeon.affixIDs or CopyPlainNumberList(affixIDs)
        if activeDungeon.wasActiveKeystoneCharged == nil
          and not IsSecret(wasActiveKeystoneCharged)
        then
          activeDungeon.wasActiveKeystoneCharged = wasActiveKeystoneCharged == true
        end
      end
    end
    return
  end

  if storage.activeDungeon then
    if storage.activeDungeon.modelVersion ~= 6 then
      storage.activeDungeon = nil
    elseif storage.activeDungeon.completionPending ~= true then
      storage.activeDungeon = nil
    end
  end
end


function History:ClearUnsaved()
  self.sessionRecords = {}
  self.latestSessionID = nil
  self.activeEncounter = nil
  self.savedDungeonDataByID = {}
  self.pendingCaptures = {}

  local storage = GetHistoryStorage(self)
  local savedSegments = storage.savedSegments
  for index = #savedSegments, 1, -1 do
    if savedSegments[index].isSaved ~= true then
      self:RemoveSavedSegmentAt(index)
    end
  end

  local savedDungeons = storage.savedDungeons
  for index = #savedDungeons, 1, -1 do
    if savedDungeons[index].isSaved ~= true then
      self:RemoveSavedDungeonAt(index)
    end
  end

  storage.activeDungeon = nil
  self:PruneSavedSegments()
  self:PruneSavedDungeons()
end
