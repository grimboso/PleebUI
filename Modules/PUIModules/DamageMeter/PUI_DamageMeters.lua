local _, ns = ...

local Addon = ns.Addon

local DamageMeters = Addon:NewModule("DamageMeters", "NumyAceEvent-3.0")
ns.Modules.DamageMeters = DamageMeters
ns.Registry.DamageMeters = DamageMeters

local P = select(1, ns.Pleebug:DropIn(DamageMeters, { name = "Modules.DamageMeters" }))

local History = {}
local Sessions = {}
local Config = {}
local Windows = {}
local Breakdown = {}
local SegmentPicker = {}
local Util = {}

ns.DamageMeterHistory = History
ns.DamageMeterSessions = Sessions
ns.DamageMeterConfig = Config
ns.DamageMeterWindows = Windows
ns.DamageMeterBreakdown = Breakdown
ns.DamageMeterSegmentPicker = SegmentPicker
ns.DamageMeterUtil = Util
ns.DamageMeterProfiler = P

local _G = _G
local C_DamageMeter = _G.C_DamageMeter
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local Enum = _G.Enum
local GetNumGroupMembers = _G.GetNumGroupMembers
local IsInGroup = _G.IsInGroup
local IsInRaid = _G.IsInRaid
local LibStub = _G.LibStub
local MenuUtil = _G.MenuUtil
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local UnitAffectingCombat = _G.UnitAffectingCombat
local issecretvalue = _G.issecretvalue
local math_floor = _G.math.floor
local tonumber = _G.tonumber
local type = _G.type

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local Constants = {
  MAX_WINDOWS = 10,
  ROW_POOL_SIZE = 40,
  BREAKDOWN_ROW_POOL_SIZE = 40,
  MOVER_PREFIX = "DamageMeter",
  LAUNCHER_NAME = "PleebUI Damage Meters",
  LAUNCHER_FALLBACK_ICON = [[Interface\AddOns\PleebUI\Media\logo.tga]],
  LIST_TEXTURE = [[Interface\AddOns\PleebUI\Media\Textures\List.png]],
  PAD_LOCKED_TEXTURE = [[Interface\AddOns\PleebUI\Media\Textures\PadLock.png]],
  PAD_UNLOCKED_TEXTURE = [[Interface\AddOns\PleebUI\Media\Textures\PadUnlock.png]],
  TRASH_TEXTURE = [[Interface\AddOns\PleebUI\Media\Textures\Trash.png]],
  MINIMIZE_TEXTURE = [[Interface\AddOns\PleebUI\Media\Textures\Minimize.png]],
  CONFIG_TEXTURE = [[Interface\AddOns\PleebUI\Media\Textures\Config.png]],
  CLOSE_TEXTURE = [[Interface\AddOns\PleebUI\Media\Textures\Close.png]],
}
ns.DamageMeterConstants = Constants

Constants.RUNTIME_EVENTS = {
  "ADDON_RESTRICTION_STATE_CHANGED",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_ENTERING_WORLD",
  "UNIT_FLAGS",
  "ENCOUNTER_START",
  "ENCOUNTER_END",
  "CHALLENGE_MODE_START",
  "CHALLENGE_MODE_COMPLETED",
  "CHALLENGE_MODE_RESET",
  "DAMAGE_METER_COMBAT_SESSION_UPDATED",
  "DAMAGE_METER_CURRENT_SESSION_UPDATED",
  "DAMAGE_METER_RESET",
}

Constants.METER_KEYS = {
  "DAMAGE_DONE",
  "DPS",
  "HEALING_DONE",
  "HPS",
  "ABSORBS",
  "INTERRUPTS",
  "DISPELS",
  "DAMAGE_TAKEN",
  "AVOIDABLE_DAMAGE_TAKEN",
  "DEATHS",
  "ENEMY_DAMAGE_TAKEN",
}

Constants.METER_NAMES = {
  DAMAGE_DONE = "Damage Done",
  DPS = "DPS",
  HEALING_DONE = "Healing Done",
  HPS = "HPS",
  ABSORBS = "Absorbs",
  INTERRUPTS = "Interrupts",
  DISPELS = "Dispels",
  DAMAGE_TAKEN = "Damage Taken",
  AVOIDABLE_DAMAGE_TAKEN = "Avoidable Damage Taken",
  DEATHS = "Deaths",
  ENEMY_DAMAGE_TAKEN = "Enemy Damage Taken",
}

Constants.METER_CATEGORIES = {
  {
    name = "Damage",
    keys = {
      "DAMAGE_DONE",
      "DPS",
      "DAMAGE_TAKEN",
      "AVOIDABLE_DAMAGE_TAKEN",
      "ENEMY_DAMAGE_TAKEN",
    },
  },
  {
    name = "Healing",
    keys = {
      "HEALING_DONE",
      "HPS",
      "ABSORBS",
    },
  },
  {
    name = "Actions",
    keys = {
      "INTERRUPTS",
      "DISPELS",
      "DEATHS",
    },
  },
}

Constants.METER_TYPES = {
  DAMAGE_DONE = Enum.DamageMeterType.DamageDone,
  DPS = Enum.DamageMeterType.Dps,
  HEALING_DONE = Enum.DamageMeterType.HealingDone,
  HPS = Enum.DamageMeterType.Hps,
  ABSORBS = Enum.DamageMeterType.Absorbs,
  INTERRUPTS = Enum.DamageMeterType.Interrupts,
  DISPELS = Enum.DamageMeterType.Dispels,
  DAMAGE_TAKEN = Enum.DamageMeterType.DamageTaken,
  AVOIDABLE_DAMAGE_TAKEN = Enum.DamageMeterType.AvoidableDamageTaken,
  DEATHS = Enum.DamageMeterType.Deaths,
  ENEMY_DAMAGE_TAKEN = Enum.DamageMeterType.EnemyDamageTaken,
}

Constants.SESSION_NAMES = {
  CURRENT = "Current",
  OVERALL = "Overall",
}

Constants.SESSION_TYPES = {
  CURRENT = Enum.DamageMeterSessionType.Current,
  OVERALL = Enum.DamageMeterSessionType.Overall,
}

function Util.Clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  end
  if value > maximum then
    return maximum
  end
  return value
end

function Util.GetViewportRowCount(viewport, rowHeight, rowSpacing, maximum)
  local rowStride = rowHeight + rowSpacing
  local height = viewport:GetHeight()
  local visible = math_floor((height + rowSpacing) / rowStride)
  return Util.Clamp(visible, 1, maximum)
end

function Util.IsSecret(value)
  return issecretvalue(value) == true
end

function Util.IsCountMeter(meterKey)
  return meterKey == "INTERRUPTS" or meterKey == "DISPELS"
end

function Util.IsDeathMeter(meterKey)
  return meterKey == "DEATHS"
end

function Util.IsRatePrimaryMeter(meterKey)
  return meterKey == "DPS" or meterKey == "HPS"
end

Util.Clamp = P:Def("Clamp", Util.Clamp)
Util.GetViewportRowCount = P:Def("GetViewportRowCount", Util.GetViewportRowCount)
Util.IsSecret = P:Def("IsSecret", Util.IsSecret)
Util.IsCountMeter = P:Def("IsCountMeter", Util.IsCountMeter)
Util.IsDeathMeter = P:Def("IsDeathMeter", Util.IsDeathMeter)
Util.IsRatePrimaryMeter = P:Def("IsRatePrimaryMeter", Util.IsRatePrimaryMeter)

local MAX_WINDOWS = Constants.MAX_WINDOWS
local LAUNCHER_NAME = Constants.LAUNCHER_NAME
local LAUNCHER_FALLBACK_ICON = Constants.LAUNCHER_FALLBACK_ICON
local RUNTIME_EVENTS = Constants.RUNTIME_EVENTS
local METER_TYPES = Constants.METER_TYPES
local IsSecret = Util.IsSecret
local HISTORY_CAPTURE_RETRY_DELAYS = { 0.5, 1, 2 }

SegmentPicker.rowCount = 12
SegmentPicker.rowHeight = 26
SegmentPicker.rowGap = 1
SegmentPicker.recentRowCount = 20
SegmentPicker.recentRowHeight = 16
SegmentPicker.recentRowGap = 1
SegmentPicker.panelWidth = 232
SegmentPicker.panelGap = 8
SegmentPicker.horizontalPadding = 8

local function IsPlainUnitInCombat(unit)
  local inCombat = UnitAffectingCombat(unit)
  if IsSecret(inCombat) then
    return false
  end
  return inCombat == true
end

local function IsGroupInCombat()
  if IsPlainUnitInCombat("player") then
    return true
  end

  if IsInRaid() then
    local memberCount = GetNumGroupMembers()
    for index = 1, memberCount do
      if IsPlainUnitInCombat("raid" .. index) then
        return true
      end
    end
    return false
  end

  if IsInGroup() then
    local memberCount = GetNumGroupMembers() - 1
    for index = 1, memberCount do
      if IsPlainUnitInCombat("party" .. index) then
        return true
      end
    end
  end

  return false
end

function DamageMeters:CancelCombatRefresh()
  if self.combatRefreshGroup then
    self.combatRefreshGroup:Stop()
  end
  self.combatRefreshPending = nil
  self.combatRefreshCycleStartIndex = nil
  self.combatRefreshWindowIndex = nil
  self.combatRefreshSlotsRemaining = nil

  self.breakdownNeedsCombatRefresh = nil
  if self.windows then
    for index = 1, MAX_WINDOWS do
      local window = self.windows[index]
      if window then
        window.needsCombatRefresh = nil
      end
    end
  end
end

local function GetFirstDirtyCombatRefreshWindowIndex()
  local windows = DamageMeters.combatRefreshWindows
  if not windows then
    return nil
  end

  local selection = DamageMeters.breakdownSelection
  local breakdownOwner = DamageMeters.breakdownNeedsCombatRefresh
    and selection
    and selection.ownerWindow
    or nil

  for index = 1, #windows do
    local window = windows[index]
    if window.needsCombatRefresh or window == breakdownOwner then
      return index
    end
  end

  return nil
end

local function StartCombatRefreshCycle(startIndex)
  local windows = DamageMeters.combatRefreshWindows
  local windowCount = windows and #windows or 0

  if DamageMeters.breakdownNeedsCombatRefresh
    and not DamageMeters.breakdownSelection
  then
    DamageMeters.breakdownNeedsCombatRefresh = nil
  end

  local dirtyIndex = windowCount > 0 and GetFirstDirtyCombatRefreshWindowIndex() or nil

  if not dirtyIndex then
    DamageMeters.combatRefreshPending = nil
    DamageMeters.combatRefreshCycleStartIndex = nil
    DamageMeters.combatRefreshWindowIndex = nil
    DamageMeters.combatRefreshSlotsRemaining = nil
    return false
  end

  if not startIndex or startIndex < 1 or startIndex > windowCount then
    startIndex = dirtyIndex
  end

  DamageMeters.combatRefreshCycleStartIndex = startIndex
  DamageMeters.combatRefreshWindowIndex = startIndex
  DamageMeters.combatRefreshSlotsRemaining = windowCount
  DamageMeters.combatRefreshAnimation:SetDuration(
    DamageMeters.runtimeRefreshRate / windowCount
  )
  DamageMeters.combatRefreshPending = true
  DamageMeters.combatRefreshGroup:Play()
  return true
end

local function RunScheduledCombatRefresh()
  if not DamageMeters.runtimeEnabled or not DamageMeters.runtimeVisible then
    DamageMeters.combatRefreshPending = nil
    DamageMeters.combatRefreshCycleStartIndex = nil
    DamageMeters.combatRefreshWindowIndex = nil
    DamageMeters.combatRefreshSlotsRemaining = nil
    return
  end

  local windows = DamageMeters.combatRefreshWindows
  local windowCount = windows and #windows or 0
  if windowCount == 0 then
    DamageMeters.combatRefreshPending = nil
    DamageMeters.combatRefreshCycleStartIndex = nil
    DamageMeters.combatRefreshWindowIndex = nil
    DamageMeters.combatRefreshSlotsRemaining = nil
    return
  end

  local index = DamageMeters.combatRefreshWindowIndex or 1
  if index > windowCount then
    index = 1
  end

  DamageMeters:RefreshCombatWindowSlot(windows[index])

  local slotsRemaining = DamageMeters.combatRefreshSlotsRemaining or windowCount
  if slotsRemaining > windowCount then
    slotsRemaining = windowCount
  end
  slotsRemaining = slotsRemaining - 1

  if slotsRemaining <= 0 then
    local cycleStartIndex = DamageMeters.combatRefreshCycleStartIndex
    DamageMeters.combatRefreshWindowIndex = nil
    DamageMeters.combatRefreshSlotsRemaining = nil
    StartCombatRefreshCycle(cycleStartIndex)
    return
  end

  index = index + 1
  if index > windowCount then
    index = 1
  end

  DamageMeters.combatRefreshWindowIndex = index
  DamageMeters.combatRefreshSlotsRemaining = slotsRemaining
  DamageMeters.combatRefreshAnimation:SetDuration(
    DamageMeters.runtimeRefreshRate / windowCount
  )
  DamageMeters.combatRefreshGroup:Play()
end

local function EnsureCombatRefreshDriver()
  if DamageMeters.combatRefreshGroup then
    return
  end

  local driver = CreateFrame("Frame")
  local group = driver:CreateAnimationGroup()
  local animation = group:CreateAnimation("Animation")
  animation:SetDuration(1)
  group:SetScript("OnFinished", RunScheduledCombatRefresh)

  DamageMeters.combatRefreshGroup = group
  DamageMeters.combatRefreshAnimation = animation
end

function DamageMeters:CompileRuntimeConfig()
  local db = self.db.profile
  self.runtimeVisible = db.visible ~= false
  self.runtimeRefreshRate = db.refreshRate
  self.runtimeWindowCount = db.windowCount
  self.runtimeShowSpecIcons = db.showSpecIcons ~= false
end

function DamageMeters:ScheduleCombatRefresh()
  if not self.runtimeEnabled
    or not self.runtimeVisible
    or self.combatRefreshPending
  then
    return
  end

  StartCombatRefreshCycle()
end

function DamageMeters:CancelTargetAnalysisRefresh()
  if self.targetAnalysisRefreshTimer then
    self.targetAnalysisRefreshTimer:Cancel()
    self.targetAnalysisRefreshTimer = nil
  end
end

local function RunScheduledTargetAnalysisRefresh()
  DamageMeters.targetAnalysisRefreshTimer = nil

  local breakdown = DamageMeters.breakdown
  local selection = DamageMeters.breakdownSelection
  if not DamageMeters.runtimeEnabled
    or not DamageMeters.runtimeVisible
    or not breakdown
    or not breakdown.frame:IsShown()
    or not selection
    or selection.mode ~= "SPELLS"
    or (selection.meterKey ~= "DAMAGE_DONE" and selection.meterKey ~= "DPS")
    or Breakdown.IsSourceBlocked()
  then
    return
  end

  Breakdown.Refresh()
end

function DamageMeters:ScheduleTargetAnalysisRefresh()
  if self.targetAnalysisRefreshTimer then
    return
  end

  self.targetAnalysisRefreshTimer = C_Timer.NewTimer(0.1, RunScheduledTargetAnalysisRefresh)
end

function DamageMeters:CancelHistoryCaptureWork()
  if self.historyCaptureWorkTimer then
    self.historyCaptureWorkTimer:Cancel()
    self.historyCaptureWorkTimer = nil
  end
  self.historyCaptureRetryIndex = 0
  History:CancelCaptureWork()
end

local function RunHistoryCaptureWork()
  DamageMeters.historyCaptureWorkTimer = nil
  DamageMeters:ProcessHistoryCaptures()
end

function DamageMeters:ScheduleHistoryCaptureWork(delay, preserveRetryIndex)
  if preserveRetryIndex ~= true then
    self.historyCaptureRetryIndex = 0
  end

  if self.historyCaptureWorkTimer
    or not self.runtimeEnabled
    or self.playerInCombat
    or self.waitingForGroupCombatEnd
    or not History:HasPendingCaptures()
  then
    return
  end

  self.historyCaptureWorkTimer = C_Timer.NewTimer(
    delay or 0.3,
    RunHistoryCaptureWork
  )
end

function DamageMeters:ProcessHistoryCaptures()
  if not self.runtimeEnabled or not History:HasPendingCaptures() then
    return
  end

  local changed, workRemaining, retryNeeded = History:ProcessCaptureWork()

  if changed then
    self:RefreshSelectionWindows()
    local picker = self.segmentPicker
    if picker and picker:IsShown() then
      SegmentPicker.ReloadData(picker)
    end
  end

  if workRemaining then
    self:ScheduleHistoryCaptureWork(0, true)
  elseif retryNeeded then
    local retryIndex = (self.historyCaptureRetryIndex or 0) + 1
    local retryDelay = HISTORY_CAPTURE_RETRY_DELAYS[retryIndex]
    if retryDelay then
      self.historyCaptureRetryIndex = retryIndex
      self:ScheduleHistoryCaptureWork(retryDelay, true)
    end
  else
    self.historyCaptureRetryIndex = 0
  end
end

function DamageMeters:CancelEncounterEndRefresh()
  if self.encounterEndTimer then
    self.encounterEndTimer:Cancel()
    self.encounterEndTimer = nil
  end
  self.pendingEncounterGeneration = nil
  self.pendingEncounterSuccess = nil
end

local function RunScheduledEncounterEndRefresh()
  DamageMeters.encounterEndTimer = nil
  local combatGeneration = DamageMeters.pendingEncounterGeneration
  local success = DamageMeters.pendingEncounterSuccess
  DamageMeters.pendingEncounterGeneration = nil
  DamageMeters.pendingEncounterSuccess = nil

  if not DamageMeters.runtimeEnabled
    or not DamageMeters.runtimeEventsRegistered
    or DamageMeters.combatGeneration ~= combatGeneration
  then
    return
  end

  if success ~= 1 and IsGroupInCombat() then
    DamageMeters.playerInCombat = false
    DamageMeters.waitingForGroupCombatEnd = true
    return
  end

  if DamageMeters.breakdownSelection
    and DamageMeters.breakdownSelection.mode == "LIVE_ENEMY_PLAYERS"
  then
    Breakdown.Close()
  end

  DamageMeters.playerInCombat = false
  DamageMeters.waitingForGroupCombatEnd = false
  DamageMeters.currentDisplaySessionID = History:OnCombatEnded()
  DamageMeters:CancelCombatRefresh()
  DamageMeters:RefreshWindows()
  DamageMeters:ScheduleHistoryCaptureWork(0.3)
end

function DamageMeters:ScheduleEncounterEndRefresh(success)
  self:CancelEncounterEndRefresh()
  self.pendingEncounterGeneration = self.combatGeneration or 0
  self.pendingEncounterSuccess = success
  self.encounterEndTimer = C_Timer.NewTimer(0.5, RunScheduledEncounterEndRefresh)
end

function DamageMeters:RegisterRuntimeEvents()
  if self.runtimeEventsRegistered
    or not self.runtimeEnabled
  then
    return
  end

  self:ReconcileRuntimeState()
  History:Resume()
  if self.playerInCombat or self.waitingForGroupCombatEnd then
    self:SelectCurrentSessionsOnCombat()
  end
  self.runtimeEventsRegistered = true
  for index = 1, #RUNTIME_EVENTS do
    local event = RUNTIME_EVENTS[index]
    if event ~= "UNIT_FLAGS" or not self.playerInCombat then
      self:RegisterEvent(event)
    end
  end
end

function DamageMeters:UnregisterRuntimeEvents()
  if not self.runtimeEventsRegistered then
    return
  end

  for index = 1, #RUNTIME_EVENTS do
    self:UnregisterEvent(RUNTIME_EVENTS[index])
  end
  self.runtimeEventsRegistered = false
  History:Pause()
end

function DamageMeters:ReconcileRuntimeState()
  Breakdown.InvalidateTargetAnalysisCache()
  Breakdown.InvalidateDeathRecapCache()
  self.combatGeneration = (self.combatGeneration or 0) + 1
  self.playerInCombat = IsPlainUnitInCombat("player")
  self.waitingForGroupCombatEnd = not self.playerInCombat and IsGroupInCombat()
end



function DamageMeters:SetRuntimeEnabled(enabled)
  enabled = enabled == true
  if enabled and self.runtimeEnabled then
    return true
  end

  if not enabled then
    self.runtimeEnabled = false
    Breakdown.InvalidateTargetAnalysisCache()
    Breakdown.InvalidateDeathRecapCache()
    self.playerInCombat = false
    self.waitingForGroupCombatEnd = false
    self:CancelCombatRefresh()
    self:CancelHistoryCaptureWork()
    self:CancelTargetAnalysisRefresh()
    self:CancelEncounterEndRefresh()
    self:UnregisterRuntimeEvents()
    self:UnregisterWindowMovers()

    Breakdown.Close()
    SegmentPicker.Hide()

    if self.windows then
      for index = 1, MAX_WINDOWS do
        local window = self.windows[index]
        if window then
          window.dragState = nil
          window.resizeState = nil
          window.dragDriver:Hide()
          window.resizeDriver:Hide()
          window.frame:Hide()
        end
      end
    end

    return false
  end

  local available, failureReason = C_DamageMeter.IsDamageMeterAvailable()
  if not available then
    if failureReason ~= "" and self.lastFailureReason ~= failureReason then
      self.lastFailureReason = failureReason
      Addon:Print("Damage Meters unavailable: " .. failureReason)
    end
    return false
  end

  self.lastFailureReason = nil
  self.runtimeEnabled = true
  return true
end

function DamageMeters:ApplySettings()
  Config.SanitizeProfile()
  self:CompileRuntimeConfig()

  if self.db.profile.enabled == false then
    self:SetRuntimeEnabled(false)
    return
  end

  if not self:SetRuntimeEnabled(true) then
    return
  end

  self:ApplyWindowConfiguration()
  self:CancelCombatRefresh()
  self:CancelHistoryCaptureWork()
  if self.runtimeVisible and self:HasShownWindow() then
    self:RegisterRuntimeEvents()
    self:ScheduleHistoryCaptureWork(0.3)
    self:RefreshWindows()
  else
    self:CancelTargetAnalysisRefresh()
    self:CancelEncounterEndRefresh()
    self:UnregisterRuntimeEvents()
    SegmentPicker.Hide()
  end
end

function DamageMeters:ClearUnsavedCombatHistory()
  self:ClearAllWindowSelections()
  self.currentDisplaySessionID = nil
  History:ClearUnsaved()
  C_DamageMeter.ResetAllCombatSessions()
end

function DamageMeters:PLAYER_REGEN_DISABLED()
  self:CancelEncounterEndRefresh()
  self:UnregisterEvent("UNIT_FLAGS")
  Breakdown.InvalidateTargetAnalysisCache()
  self.combatGeneration = (self.combatGeneration or 0) + 1
  self.playerInCombat = true
  self.waitingForGroupCombatEnd = false
  self:CancelHistoryCaptureWork()
  self:SelectCurrentSessionsOnCombat()
  if self.breakdownSelection
    and (self.breakdownSelection.sessionID ~= nil or self.breakdownSelection.isLocalPlayer ~= true)
  then
    Breakdown.Close()
  end

  if self:MarkCurrentWindowsDirty() then
    self:ScheduleCombatRefresh()
  end
end

function DamageMeters:ADDON_RESTRICTION_STATE_CHANGED(_, restrictionType, state)
  if restrictionType ~= Enum.AddOnRestrictionType.Combat
    or state ~= 0
    or self.playerInCombat
    or self.waitingForGroupCombatEnd
  then
    return
  end

  self:ScheduleHistoryCaptureWork(0.3)
end

function DamageMeters:PLAYER_REGEN_ENABLED()
  self:CancelEncounterEndRefresh()
  self:RegisterEvent("UNIT_FLAGS")
  if IsGroupInCombat() then
    self.playerInCombat = false
    self.waitingForGroupCombatEnd = true
    return
  end

  if self.breakdownSelection and self.breakdownSelection.mode == "LIVE_ENEMY_PLAYERS" then
    Breakdown.Close()
  end

  self.playerInCombat = false
  self.waitingForGroupCombatEnd = false
  self.currentDisplaySessionID = History:OnCombatEnded()
  self:CancelCombatRefresh()
  self:RefreshWindows()
  self:ScheduleHistoryCaptureWork(0.3)
end

function DamageMeters:UNIT_FLAGS(_, unit)
  if self.playerInCombat or not unit then
    return
  end
  if unit ~= "player" and not unit:match("^party%d+$") and not unit:match("^raid%d+$") then
    return
  end

  if self.waitingForGroupCombatEnd then
    if IsPlainUnitInCombat(unit) or IsGroupInCombat() then
      return
    end

    if self.breakdownSelection and self.breakdownSelection.mode == "LIVE_ENEMY_PLAYERS" then
      Breakdown.Close()
    end

    self.waitingForGroupCombatEnd = false
    self.currentDisplaySessionID = History:OnCombatEnded()
    self:CancelCombatRefresh()
    self:RefreshWindows()
    self:ScheduleHistoryCaptureWork(0.3)
    return
  end

  if not IsPlainUnitInCombat(unit) then
    return
  end

  self.combatGeneration = (self.combatGeneration or 0) + 1
  self.waitingForGroupCombatEnd = true
  Breakdown.InvalidateTargetAnalysisCache()
  self:CancelHistoryCaptureWork()
  self:SelectCurrentSessionsOnCombat()
  if self.breakdownSelection
    and (self.breakdownSelection.sessionID ~= nil or self.breakdownSelection.isLocalPlayer ~= true)
  then
    Breakdown.Close()
  end
  if self:MarkCurrentWindowsDirty() then
    self:ScheduleCombatRefresh()
  end
end

function DamageMeters:ENCOUNTER_START(_, encounterID, encounterName, difficultyID, groupSize)
  History:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
  self:CancelEncounterEndRefresh()
  Breakdown.InvalidateTargetAnalysisCache()
  self.combatGeneration = (self.combatGeneration or 0) + 1
  self.playerInCombat = true
  self.waitingForGroupCombatEnd = false
  self:CancelHistoryCaptureWork()
  self:SelectCurrentSessionsOnCombat()
  if self.breakdownSelection
    and (self.breakdownSelection.sessionID ~= nil or self.breakdownSelection.isLocalPlayer ~= true)
  then
    Breakdown.Close()
  end
  if self:MarkCurrentWindowsDirty() then
    self:ScheduleCombatRefresh()
  end
end

function DamageMeters:ENCOUNTER_END(
  _,
  encounterID,
  encounterName,
  difficultyID,
  groupSize,
  success
)
  History:OnEncounterEnd(
    encounterID,
    encounterName,
    difficultyID,
    groupSize,
    success
  )
  self:ScheduleEncounterEndRefresh(success)
end

function DamageMeters:CHALLENGE_MODE_START(_, mapID)
  if History:StartDungeon(mapID, true) then
    Breakdown.InvalidateTargetAnalysisCache()
    Breakdown.InvalidateDeathRecapCache()
  end
end

function DamageMeters:CHALLENGE_MODE_COMPLETED()
  History:MarkDungeonCompleted()
  self:ScheduleHistoryCaptureWork(0.3)
end

function DamageMeters:CHALLENGE_MODE_RESET()
  History:ResetDungeon()
  local picker = self.segmentPicker
  if picker and picker:IsShown() then
    SegmentPicker.ReloadData(picker)
  end
end

function DamageMeters:PLAYER_ENTERING_WORLD()
  self:CancelEncounterEndRefresh()
  Breakdown.InvalidateTargetAnalysisCache()
  Breakdown.InvalidateDeathRecapCache()
  self.combatGeneration = (self.combatGeneration or 0) + 1
  self.playerInCombat = IsPlainUnitInCombat("player")
  self.waitingForGroupCombatEnd = not self.playerInCombat and IsGroupInCombat()
  if self.playerInCombat or self.waitingForGroupCombatEnd then
    self:SelectCurrentSessionsOnCombat()
  end
  History:ReconcileDungeonState()

  if self.breakdownSelection then
    if self.breakdownSelection.mode == "LIVE_ENEMY_PLAYERS" then
      Breakdown.Close()
    elseif (self.playerInCombat or self.waitingForGroupCombatEnd)
      and self.breakdownSelection.isLocalPlayer ~= true
    then
      Breakdown.Close()
    end
  end

  self:CancelCombatRefresh()
  self:ReconcileAvailableSessionSelections()
  self:ScheduleHistoryCaptureWork(0.3)
  self:RefreshWindows()
end

function DamageMeters:DAMAGE_METER_COMBAT_SESSION_UPDATED(_, meterType, sessionID)
  if meterType == METER_TYPES.DAMAGE_DONE then
    History:OnCombatSessionUpdated(meterType, sessionID)
  end

  if self.playerInCombat or self.waitingForGroupCombatEnd then
    if not self.runtimeVisible then
      return
    end

    local meterWindows = self.combatEventWindowsByMeterType
      and self.combatEventWindowsByMeterType[meterType]
    local breakdownSelection = self.breakdownSelection
    local breakdownMatchesMeter = breakdownSelection
      and METER_TYPES[breakdownSelection.meterKey] == meterType

    if not meterWindows and not breakdownMatchesMeter then
      return
    end

    if self.combatRefreshPending then
      local allWindowsDirty = true
      if meterWindows then
        for index = 1, #meterWindows do
          local window = meterWindows[index]
          if window.frame:IsShown()
            and not window.navigationMode
            and not window.needsCombatRefresh
          then
            allWindowsDirty = false
            break
          end
        end
      end

      local breakdownAlreadyDirty = not breakdownMatchesMeter
        or self.breakdownNeedsCombatRefresh
      if allWindowsDirty and breakdownAlreadyDirty then
        return
      end
    end

    if self:MarkWindowsDirtyForMeterEvent(meterType, sessionID)
      and not self.combatRefreshPending
    then
      self:ScheduleCombatRefresh()
    end
    return
  end

  if meterType == METER_TYPES.DAMAGE_DONE
    and not IsSecret(sessionID)
    and type(sessionID) == "number"
    and sessionID > 0
  then
    self:ReconcileAvailableSessionSelections()
    self:RefreshSelectionWindows()
  end

  if meterType == METER_TYPES.DAMAGE_DONE or meterType == METER_TYPES.ENEMY_DAMAGE_TAKEN then
    Breakdown.MarkTargetAnalysisDirty(sessionID)
  end

  self:RefreshWindowsForMeterType(meterType, sessionID)
  self:ScheduleHistoryCaptureWork(0.3)
end

function DamageMeters:DAMAGE_METER_CURRENT_SESSION_UPDATED()
  if self.playerInCombat or self.waitingForGroupCombatEnd then
    if not self.runtimeVisible then
      return
    end

    if self:MarkCurrentWindowsDirty() and not self.combatRefreshPending then
      self:ScheduleCombatRefresh()
    end
    return
  end

  Breakdown.MarkTargetAnalysisDirty(0)
  if self:MarkCurrentWindowsDirty() then
    self:RefreshDirtyWindows()
  end
end

function DamageMeters:DAMAGE_METER_RESET()
  self:CancelCombatRefresh()
  self:CancelHistoryCaptureWork()
  self.currentDisplaySessionID = nil
  History:OnBlizzardReset()
  Breakdown.Close()
  Breakdown.InvalidateTargetAnalysisCache()
  Breakdown.InvalidateDeathRecapCache()

  self:ExpireAvailableSessionSelections()

  if self.windows then
    for index = 1, MAX_WINDOWS do
      local window = self.windows[index]
      if window then
        window.firstSource = 1
      end
    end
  end
  self:RefreshWindows()
end

function DamageMeters:OnDatabaseShutdown()
  History:PrepareForLogout()
end

local function CreateLauncherIcon(button)
  if not button or button.__puiDamageMeterIcon then
    return
  end

  button.icon:SetAlpha(0)

  local icon = CreateFrame("Frame", nil, button)
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -5)
  icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 5)
  icon:SetFrameLevel(button:GetFrameLevel() + 2)

  local classKeys = { "MAGE", "ROGUE", "DRUID" }
  local heights = { 0.45, 0.70, 1.00 }

  for index = 1, 3 do
    local bar = icon:CreateTexture(nil, "ARTWORK")
    bar:SetAtlas("UI-HUD-CoolDownManager-Bar")
    bar:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", (index - 1) * 6, 0)
    bar:SetSize(5, 15 * heights[index])

    local color = RAID_CLASS_COLORS[classKeys[index]]
    bar:SetVertexColor(color.r, color.g, color.b, 1)
  end

  button.__puiDamageMeterIcon = icon
end

local function BuildLauncherMenu(_, rootDescription)
  local db = DamageMeters.db.profile

  rootDescription:CreateTitle("PleebUI Damage Meters")
  rootDescription:CreateButton(db.enabled and db.visible and DamageMeters:HasShownWindow() and "Hide windows" or "Show windows", function()
    DamageMeters:ToggleWindows()
  end)
  for index = 1, db.windowCount do
    local windowIndex = index
    if Config.GetWindowDB(windowIndex).shown == false then
      rootDescription:CreateButton("Reopen window " .. windowIndex, function()
        DamageMeters:ReopenWindow(windowIndex)
      end)
    end
  end
  rootDescription:CreateButton("New window", function()
    DamageMeters:AddWindow()
  end)
  rootDescription:CreateButton("Close last shown window", function()
    DamageMeters:CloseLastWindow()
  end)
  rootDescription:CreateButton("Delete last window", function()
    DamageMeters:DeleteWindow(db.windowCount)
  end)
  rootDescription:CreateButton("Clear unsaved segments", function()
    SegmentPicker.ConfirmClearUnsavedSegments()
  end)
  rootDescription:CreateButton("Open settings", function()
    Addon:OpenOptionsSection("DamageMeters")
  end)
  rootDescription:CreateButton(db.enabled and "Disable damage meters" or "Enable damage meters", function()
    db.enabled = not db.enabled
    if db.enabled then
      db.visible = true
      if db.windowCount == 0 then
        db.windowCount = 1
        Config.GetWindowDB(1).shown = true
      elseif not DamageMeters:HasShownWindow() then
        Config.GetWindowDB(1).shown = true
      end
    end
    DamageMeters:ApplySettings()
  end)
end

function DamageMeters:InitializeLauncher()
  if self.launcher then
    return
  end

  self.launcher = LDB:NewDataObject(LAUNCHER_NAME, {
    type = "launcher",
    text = "Damage Meters",
    icon = LAUNCHER_FALLBACK_ICON,
    OnClick = function(frame, button)
      if button == "LeftButton" then
        DamageMeters:ToggleWindows()
      elseif button == "MiddleButton" then
        DamageMeters:AddWindow()
      elseif button == "RightButton" then
        MenuUtil.CreateContextMenu(frame, BuildLauncherMenu)
      end
    end,
    OnTooltipShow = function(tooltip)
      local db = DamageMeters.db.profile
      tooltip:AddLine("PleebUI Damage Meters", 1, 1, 1)

      if db.enabled == false then
        tooltip:AddLine("Disabled", 0.75, 0.75, 0.75)
      elseif db.visible and DamageMeters:HasShownWindow() then
        tooltip:AddLine("Enabled · windows shown", 0.75, 0.75, 0.75)
      else
        tooltip:AddLine("Enabled · windows hidden", 0.75, 0.75, 0.75)
      end

      tooltip:AddLine("Left-click: Show or hide", 0.65, 0.65, 0.65)
      tooltip:AddLine("Middle-click: New window", 0.65, 0.65, 0.65)
      tooltip:AddLine("Right-click: Menu", 0.65, 0.65, 0.65)
    end,
  })

  LDBIcon:Register(LAUNCHER_NAME, self.launcher, self.db.profile.minimap)
  CreateLauncherIcon(LDBIcon:GetMinimapButton(LAUNCHER_NAME))
end

function DamageMeters:HandleSlashCommand(message)
  local command, argument = message:match("^%s*(%S*)%s*(%S*)")
  command = (command or ""):lower()

  if command == "" or command == "show" or command == "open" then
    self:SetWindowsVisible(true)
  elseif command == "hide" then
    self:SetWindowsVisible(false)
  elseif command == "toggle" then
    self:ToggleWindows()
  elseif command == "enable" then
    self.db.profile.enabled = true
    self.db.profile.visible = true
    if self.db.profile.windowCount == 0 then
      self.db.profile.windowCount = 1
      Config.GetWindowDB(1).shown = true
    elseif not self:HasShownWindow() then
      Config.GetWindowDB(1).shown = true
    end
    self:ApplySettings()
  elseif command == "disable" then
    self.db.profile.enabled = false
    self:ApplySettings()
  elseif command == "new" then
    self:AddWindow()
  elseif command == "reopen" then
    local index = tonumber(argument)
    if not index then
      Addon:Print("Damage Meters: use /dmg reopen 1-" .. MAX_WINDOWS)
      return
    end
    self:ReopenWindow(index)
  elseif command == "close" then
    self:CloseLastWindow()
  elseif command == "delete" then
    self:DeleteWindow(self.db.profile.windowCount)
  elseif command == "reset" then
    SegmentPicker.ConfirmClearUnsavedSegments()
  elseif command == "config" or command == "settings" then
    Addon:OpenOptionsSection("DamageMeters")
  else
    Addon:Print("Damage Meters: /dmg show, hide, toggle, enable, disable, new, reopen, close, delete, reset, or config")
  end
end

SLASH_PUI_DAMAGEMETERS1 = "/dmg"
SLASH_PUI_DAMAGEMETERS2 = "/dps"
function SlashCmdList.PUI_DAMAGEMETERS(message)
  DamageMeters:HandleSlashCommand(message)
end

function DamageMeters:ApplyProfile()
  Breakdown.Close()
  Breakdown.InvalidateTargetAnalysisCache()
  Breakdown.InvalidateDeathRecapCache()
  self.db = Addon.db:GetNamespace("DamageMeters")
  Config.SanitizeProfile()
  self:ClearAllWindowSelections()
  History:ApplyTrackingOptions()
  LDBIcon:Refresh(LAUNCHER_NAME, self.db.profile.minimap)
  self:ApplySettings()
end

function DamageMeters:OnInitialize()
  self.db = Addon.db:RegisterNamespace("DamageMeters", Config.DEFAULTS)
  self.db.RegisterCallback(self, "OnDatabaseShutdown", "OnDatabaseShutdown")
  Config.SanitizeProfile()
  self.windowSelections = {}
  History:Initialize(self, METER_TYPES)
  self.runtimeEnabled = false
  self.runtimeEventsRegistered = false
  self.combatGeneration = 0

  EnsureCombatRefreshDriver()
  self:InitializeLauncher()

  Addon:RegisterOptionsSection("DamageMeters", function()
    return DamageMeters
  end, 55, "Damage Meters", nil, {
    preview = false,
  })
end

function DamageMeters:OnEnable()
  self:ApplySettings()
end

function DamageMeters:OnDisable()
  self:SetRuntimeEnabled(false)
end

IsPlainUnitInCombat = P:Def("IsPlainUnitInCombat", IsPlainUnitInCombat)
IsGroupInCombat = P:Def("IsGroupInCombat", IsGroupInCombat)
GetFirstDirtyCombatRefreshWindowIndex = P:Def("GetFirstDirtyCombatRefreshWindowIndex", GetFirstDirtyCombatRefreshWindowIndex)
StartCombatRefreshCycle = P:Def("StartCombatRefreshCycle", StartCombatRefreshCycle)
RunScheduledCombatRefresh = P:Def("RunScheduledCombatRefresh", RunScheduledCombatRefresh)
EnsureCombatRefreshDriver = P:Def("EnsureCombatRefreshDriver", EnsureCombatRefreshDriver)
RunScheduledTargetAnalysisRefresh = P:Def("RunScheduledTargetAnalysisRefresh", RunScheduledTargetAnalysisRefresh)
RunHistoryCaptureWork = P:Def("RunHistoryCaptureWork", RunHistoryCaptureWork)
RunScheduledEncounterEndRefresh = P:Def("RunScheduledEncounterEndRefresh", RunScheduledEncounterEndRefresh)
CreateLauncherIcon = P:Def("CreateLauncherIcon", CreateLauncherIcon)
BuildLauncherMenu = P:Def("BuildLauncherMenu", BuildLauncherMenu)

DamageMeters.CancelCombatRefresh = P:Def("DamageMeters.CancelCombatRefresh", DamageMeters.CancelCombatRefresh)
DamageMeters.CompileRuntimeConfig = P:Def("DamageMeters.CompileRuntimeConfig", DamageMeters.CompileRuntimeConfig)
DamageMeters.ScheduleCombatRefresh = P:Def("DamageMeters.ScheduleCombatRefresh", DamageMeters.ScheduleCombatRefresh)
DamageMeters.CancelTargetAnalysisRefresh = P:Def("DamageMeters.CancelTargetAnalysisRefresh", DamageMeters.CancelTargetAnalysisRefresh)
DamageMeters.ScheduleTargetAnalysisRefresh = P:Def("DamageMeters.ScheduleTargetAnalysisRefresh", DamageMeters.ScheduleTargetAnalysisRefresh)
DamageMeters.CancelHistoryCaptureWork = P:Def("DamageMeters.CancelHistoryCaptureWork", DamageMeters.CancelHistoryCaptureWork)
DamageMeters.ScheduleHistoryCaptureWork = P:Def("DamageMeters.ScheduleHistoryCaptureWork", DamageMeters.ScheduleHistoryCaptureWork)
DamageMeters.ProcessHistoryCaptures = P:Def("DamageMeters.ProcessHistoryCaptures", DamageMeters.ProcessHistoryCaptures)
DamageMeters.CancelEncounterEndRefresh = P:Def("DamageMeters.CancelEncounterEndRefresh", DamageMeters.CancelEncounterEndRefresh)
DamageMeters.ScheduleEncounterEndRefresh = P:Def("DamageMeters.ScheduleEncounterEndRefresh", DamageMeters.ScheduleEncounterEndRefresh)
DamageMeters.RegisterRuntimeEvents = P:Def("DamageMeters.RegisterRuntimeEvents", DamageMeters.RegisterRuntimeEvents)
DamageMeters.UnregisterRuntimeEvents = P:Def("DamageMeters.UnregisterRuntimeEvents", DamageMeters.UnregisterRuntimeEvents)
DamageMeters.ReconcileRuntimeState = P:Def("DamageMeters.ReconcileRuntimeState", DamageMeters.ReconcileRuntimeState)
DamageMeters.SetRuntimeEnabled = P:Def("DamageMeters.SetRuntimeEnabled", DamageMeters.SetRuntimeEnabled)
DamageMeters.ApplySettings = P:Def("DamageMeters.ApplySettings", DamageMeters.ApplySettings)
DamageMeters.ClearUnsavedCombatHistory = P:Def("DamageMeters.ClearUnsavedCombatHistory", DamageMeters.ClearUnsavedCombatHistory)
DamageMeters.InitializeLauncher = P:Def("DamageMeters.InitializeLauncher", DamageMeters.InitializeLauncher)
DamageMeters.HandleSlashCommand = P:Def("DamageMeters.HandleSlashCommand", DamageMeters.HandleSlashCommand)
DamageMeters.ApplyProfile = P:Def("DamageMeters.ApplyProfile", DamageMeters.ApplyProfile)
DamageMeters.CHALLENGE_MODE_START = P:Def("DamageMeters.CHALLENGE_MODE_START", DamageMeters.CHALLENGE_MODE_START)
DamageMeters.CHALLENGE_MODE_COMPLETED = P:Def("DamageMeters.CHALLENGE_MODE_COMPLETED", DamageMeters.CHALLENGE_MODE_COMPLETED)
DamageMeters.CHALLENGE_MODE_RESET = P:Def("DamageMeters.CHALLENGE_MODE_RESET", DamageMeters.CHALLENGE_MODE_RESET)
DamageMeters.OnInitialize = P:Def("DamageMeters.OnInitialize", DamageMeters.OnInitialize)
DamageMeters.OnEnable = P:Def("DamageMeters.OnEnable", DamageMeters.OnEnable)
DamageMeters.OnDisable = P:Def("DamageMeters.OnDisable", DamageMeters.OnDisable)
