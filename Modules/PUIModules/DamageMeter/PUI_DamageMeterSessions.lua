local _, ns = ...

local DamageMeters = ns.Modules.DamageMeters
local Sessions = ns.DamageMeterSessions
local Breakdown = ns.DamageMeterBreakdown
local SegmentPicker = ns.DamageMeterSegmentPicker
local History = ns.DamageMeterHistory
local Constants = ns.DamageMeterConstants
local P = ns.DamageMeterProfiler

local _G = _G
local AbbreviateNumbers = _G.AbbreviateNumbers
local C_DamageMeter = _G.C_DamageMeter
local DAMAGE_METER_COMBAT_NUMBER = _G.DAMAGE_METER_COMBAT_NUMBER
local math_floor = _G.math.floor
local math_max = _G.math.max
local pairs = _G.pairs
local string_format = _G.string.format
local type = _G.type

local MAX_WINDOWS = Constants.MAX_WINDOWS
local METER_TYPES = Constants.METER_TYPES
local SESSION_NAMES = Constants.SESSION_NAMES
local SESSION_TYPES = Constants.SESSION_TYPES
local IsSecret = ns.DamageMeterUtil.IsSecret

local function GetWindowSelection(windowDB)
  if not windowDB or not DamageMeters.windowSelections then
    return nil
  end

  local index = windowDB.index
  if type(index) ~= "number" or index < 1 or index > MAX_WINDOWS then
    local windows = DamageMeters.db.profile.windows
    for windowIndex = 1, MAX_WINDOWS do
      if windows[windowIndex] == windowDB then
        index = windowIndex
        break
      end
    end
  end

  if type(index) ~= "number" or index < 1 or index > MAX_WINDOWS then
    return nil
  end

  return DamageMeters.windowSelections[index]
end

local function SetWindowSelection(index, selection)
  DamageMeters.windowSelections = DamageMeters.windowSelections or {}
  DamageMeters.windowSelections[index] = selection
end

local function IsAvailableSessionSelection(selection)
  return selection and selection.kind == "SESSION_AVAILABLE"
end

local function IsHistorySelection(selection)
  return selection and selection.kind ~= "SESSION_AVAILABLE"
end

local function WindowSelectionsEqual(left, right)
  if IsAvailableSessionSelection(left) or IsAvailableSessionSelection(right) then
    return IsAvailableSessionSelection(left)
      and IsAvailableSessionSelection(right)
      and left.sessionID == right.sessionID
  end

  return History:SelectionsEqual(left, right)
end

function DamageMeters:ClearSelectionsForHistoryRecord(kind, idField, id)
  if not self.windowSelections then
    return
  end

  for index = 1, MAX_WINDOWS do
    local selection = self.windowSelections[index]
    if selection and selection.kind == kind and selection[idField] == id then
      self.windowSelections[index] = nil
      local window = self.windows and self.windows[index]
      if window then
        window.needsSelectionRefresh = true
      end
      if self.breakdownSelection and self.breakdownSelection.ownerIndex == index then
        Breakdown.Close()
      end
    end
  end
end

function DamageMeters:ClearAllWindowSelections()
  self.windowSelections = {}
  Breakdown.Close()
  SegmentPicker.Hide()
end

function DamageMeters:ReconcileAvailableSessionSelections()
  if not self.windowSelections then
    return
  end

  local availableSessionIDs = {}
  local sessions = C_DamageMeter.GetAvailableCombatSessions()
  for index = 1, #sessions do
    local sessionID = sessions[index].sessionID
    if IsSecret(sessionID) or type(sessionID) ~= "number" then
      return
    end
    if sessionID > 0 then
      availableSessionIDs[sessionID] = true
    end
  end

  for index = 1, MAX_WINDOWS do
    local selection = self.windowSelections[index]
    if selection then
      if IsAvailableSessionSelection(selection)
        and not availableSessionIDs[selection.sessionID]
      then
        self.windowSelections[index] = nil
        local window = self.windows and self.windows[index]
        if window then
          window.needsSelectionRefresh = true
        end
      end
    end
  end
end

function DamageMeters:ExpireAvailableSessionSelections()
  if not self.windowSelections then
    return
  end

  for index = 1, MAX_WINDOWS do
    local selection = self.windowSelections[index]
    if IsAvailableSessionSelection(selection) then
      self.windowSelections[index] = nil
    end
  end
end

local function FormatDuration(seconds)
  local wholeSeconds = math_max(0, math_floor(seconds + 0.5))
  local minutes = math_floor(wholeSeconds / 60)
  local remainder = wholeSeconds - minutes * 60
  return string_format("%d:%02d", minutes, remainder)
end

local function GetAvailableSessionInfo(sessionID)
  if type(sessionID) ~= "number" then
    return nil
  end

  local sessions = C_DamageMeter.GetAvailableCombatSessions()
  for index = 1, #sessions do
    local sessionInfo = sessions[index]
    if sessionInfo.sessionID == sessionID then
      return sessionInfo
    end
  end

  return nil
end

local function GetSessionStateKey(windowDB)
  local selection = GetWindowSelection(windowDB)
  if IsAvailableSessionSelection(selection) then
    return "ID:" .. selection.sessionID
  end
  if selection then
    return History:GetSelectionStateKey(selection)
  end

  return "TYPE:" .. windowDB.session
end

local function GetCombatSession(windowDB, meterKey)
  local selection = GetWindowSelection(windowDB)
  if IsHistorySelection(selection) then
    return History:GetSession(selection, meterKey)
  end

  local meterType = METER_TYPES[meterKey]
  if IsAvailableSessionSelection(selection) then
    if GetAvailableSessionInfo(selection.sessionID) then
      return C_DamageMeter.GetCombatSessionFromID(selection.sessionID, meterType)
    end
    return nil
  end

  return C_DamageMeter.GetCombatSessionFromType(SESSION_TYPES[windowDB.session], meterType)
end

local function GetCombatSessionSource(
  windowDB,
  meterKey,
  sourceGUID,
  sourceCreatureID
)
  local selection = GetWindowSelection(windowDB)
  if IsAvailableSessionSelection(selection) then
    if not GetAvailableSessionInfo(selection.sessionID) then
      return nil
    end
    return C_DamageMeter.GetCombatSessionSourceFromID(
      selection.sessionID,
      METER_TYPES[meterKey],
      sourceGUID,
      sourceCreatureID
    )
  end

  if selection then
    return History:GetSessionSource(
      selection,
      meterKey,
      sourceGUID,
      sourceCreatureID
    )
  end

  return C_DamageMeter.GetCombatSessionSourceFromType(
    SESSION_TYPES[windowDB.session],
    METER_TYPES[meterKey],
    sourceGUID,
    sourceCreatureID
  )
end

local NO_COMBAT_SESSION = {}

local function AcquireRefreshSessionCache()
  local cache = DamageMeters.refreshSessionCache
  if not cache then
    cache = {}
    DamageMeters.refreshSessionCache = cache
  end

  return cache
end

local function ReleaseRefreshSessionCache(cache)
  for key in pairs(cache) do
    cache[key] = nil
  end
end

local function GetRefreshSession(cache, windowDB, meterKey)
  local cacheKey = meterKey .. "\31" .. GetSessionStateKey(windowDB)
  local session = cache[cacheKey]
  if session == nil then
    session = GetCombatSession(windowDB, meterKey) or NO_COMBAT_SESSION
    cache[cacheKey] = session
  end

  return session
end

local function GetSessionDisplay(windowDB, session)
  local selection = GetWindowSelection(windowDB)
  if IsAvailableSessionSelection(selection) then
    local sessionInfo = GetAvailableSessionInfo(selection.sessionID)
    if sessionInfo then
      local name = sessionInfo.name
      if IsSecret(name) or type(name) ~= "string" or name == "" then
        name = DAMAGE_METER_COMBAT_NUMBER:format(selection.sessionID)
      end
      return name, sessionInfo.durationSeconds
    end
    return "Expired session", nil
  end

  if selection then
    local name, duration = History:GetSelectionDisplay(selection)
    if name then
      return name, duration
    end

  elseif session then
    return SESSION_NAMES[windowDB.session], session.durationSeconds
  end

  return SESSION_NAMES[windowDB.session], C_DamageMeter.GetSessionDurationSeconds(SESSION_TYPES[windowDB.session])
end

local function SetNumericText(fontString, value)
  if IsSecret(value) then
    fontString:SetText(AbbreviateNumbers(value))
  elseif value == nil then
    fontString:SetText("")
  else
    fontString:SetText(AbbreviateNumbers(value))
  end
end

local function SetDeathTimeText(fontString, value)
  if IsSecret(value) then
    fontString:SetText(value)
  elseif value == nil then
    fontString:SetText("")
  elseif value < 0 then
    fontString:SetText("")
  else
    fontString:SetText(FormatDuration(value))
  end
end

GetWindowSelection = P:Def("GetWindowSelection", GetWindowSelection)
SetWindowSelection = P:Def("SetWindowSelection", SetWindowSelection)
IsAvailableSessionSelection = P:Def("IsAvailableSessionSelection", IsAvailableSessionSelection)
IsHistorySelection = P:Def("IsHistorySelection", IsHistorySelection)
WindowSelectionsEqual = P:Def("WindowSelectionsEqual", WindowSelectionsEqual)
FormatDuration = P:Def("FormatDuration", FormatDuration)
GetAvailableSessionInfo = P:Def("GetAvailableSessionInfo", GetAvailableSessionInfo)
GetSessionStateKey = P:Def("GetSessionStateKey", GetSessionStateKey)
GetCombatSession = P:Def("GetCombatSession", GetCombatSession)
GetCombatSessionSource = P:Def("GetCombatSessionSource", GetCombatSessionSource)
AcquireRefreshSessionCache = P:Def("AcquireRefreshSessionCache", AcquireRefreshSessionCache)
ReleaseRefreshSessionCache = P:Def("ReleaseRefreshSessionCache", ReleaseRefreshSessionCache)
GetRefreshSession = P:Def("GetRefreshSession", GetRefreshSession)
GetSessionDisplay = P:Def("GetSessionDisplay", GetSessionDisplay)
SetNumericText = P:Def("SetNumericText", SetNumericText)
SetDeathTimeText = P:Def("SetDeathTimeText", SetDeathTimeText)

DamageMeters.ClearSelectionsForHistoryRecord = P:Def("DamageMeters.ClearSelectionsForHistoryRecord", DamageMeters.ClearSelectionsForHistoryRecord)
DamageMeters.ClearAllWindowSelections = P:Def("DamageMeters.ClearAllWindowSelections", DamageMeters.ClearAllWindowSelections)
DamageMeters.ReconcileAvailableSessionSelections = P:Def("DamageMeters.ReconcileAvailableSessionSelections", DamageMeters.ReconcileAvailableSessionSelections)
DamageMeters.ExpireAvailableSessionSelections = P:Def("DamageMeters.ExpireAvailableSessionSelections", DamageMeters.ExpireAvailableSessionSelections)

Sessions.GetWindowSelection = GetWindowSelection
Sessions.SetWindowSelection = SetWindowSelection
Sessions.IsAvailableSessionSelection = IsAvailableSessionSelection
Sessions.IsHistorySelection = IsHistorySelection
Sessions.WindowSelectionsEqual = WindowSelectionsEqual
Sessions.FormatDuration = FormatDuration
Sessions.GetAvailableSessionInfo = GetAvailableSessionInfo
Sessions.GetSessionStateKey = GetSessionStateKey
Sessions.GetCombatSession = GetCombatSession
Sessions.GetCombatSessionSource = GetCombatSessionSource
Sessions.AcquireRefreshSessionCache = AcquireRefreshSessionCache
Sessions.ReleaseRefreshSessionCache = ReleaseRefreshSessionCache
Sessions.GetRefreshSession = GetRefreshSession
Sessions.GetSessionDisplay = GetSessionDisplay
Sessions.SetNumericText = SetNumericText
Sessions.SetDeathTimeText = SetDeathTimeText
Sessions.NO_COMBAT_SESSION = NO_COMBAT_SESSION
