-- File: LibPleebug-1_CPU.lua
-- CPU support for Pleebug.
--
-- Light mode:
--   Uses Blizzard native CPU counters such as GetFunctionCPUUsage/GetEventCPUUsage.
--   Requires scriptProfile=1 and a reload.
--   Does not execute Pleebug wrappers for instrumented functions.
--   Provides CPU call counts/calls per second, but not per-call memory deltas.
--
-- Full debug mode:
--   Executes every P:Def and P:SecDef registration through Pleebug wrappers.
--   Uses C_AddOnProfiler.MeasureCall when available, with a local timing fallback.
--   Can taint and requires a reload to install or remove wrappers.

local LibStub = _G.LibStub
local Pleebug = LibStub and LibStub("LibPleebug-1", true)
if not Pleebug then return end

-- Backwards-compatible alias (rest of file can keep using MemDebug)
local MemDebug = Pleebug


MemDebug.CPU = MemDebug.CPU or {}
local CPU = MemDebug.CPU

-- WoW Lua compatibility: table.pack/unpack may be nil in some clients
local t_pack = table.pack or function(...)
  return { n = select("#", ...), ... }
end
local t_unpack = table.unpack or unpack


---------------------
-- Tick hook: publish native function/event deltas and the retained addon overview.
---------------------
if MemDebug and MemDebug.RegisterTickHook then
  MemDebug:RegisterTickHook("CPU", function(self, now, interval, snap)
    local cpu = self.CPU
    if not cpu then
      return
    end

    -- Native samplers replace wrapper-based TrackFunc counts.
    -- They must run when Pleebug is started, even if the optional CPU chart checkbox is off.
    if cpu.SampleNativeFunctions then
      cpu:SampleNativeFunctions(now, interval, snap)
    end
    if cpu.SampleNativeEvents then
      cpu:SampleNativeEvents(now, interval, snap)
    end
    if cpu.SnapshotOverview then
      cpu:SnapshotOverview(snap, now)
    end
  end)
end



local function _now()
  if GetTimePreciseSec then return GetTimePreciseSec() end
  if GetTime then return GetTime() end
  return 0
end

local METRIC = Enum and Enum.AddOnProfilerMetric or nil
local METRIC_LAST_TIME = METRIC and METRIC.LastTime or nil

local function _ProfilerEnabled()
  if C_AddOnProfiler and C_AddOnProfiler.IsEnabled then
    return C_AddOnProfiler.IsEnabled()
  end
  return false
end

local function _GetAddOnLastMs(addonName)
  if not addonName or addonName == "" then return nil end
  if not METRIC_LAST_TIME then return nil end
  if not (C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric) then return nil end
  return C_AddOnProfiler.GetAddOnMetric(addonName, METRIC_LAST_TIME)
end

local GetFunctionCPUUsage = _G.GetFunctionCPUUsage
local GetEventCPUUsage = _G.GetEventCPUUsage
local GetAddOnMemoryUsage = _G.GetAddOnMemoryUsage
local UpdateAddOnMemoryUsage = _G.UpdateAddOnMemoryUsage
local C_AddOns = _G.C_AddOns

local function _EnsureCDB()
  if not MemDebug.GetDB then return nil end
  local db = MemDebug:GetDB()
  if not db then return nil end

  db.cpu = db.cpu or {}
  local cdb = db.cpu

  if type(cdb.enabled) ~= "boolean" then cdb.enabled = false end

  cdb.keepSeconds = tonumber(cdb.keepSeconds) or 120
  if cdb.keepSeconds < 10 then cdb.keepSeconds = 10 end
  if cdb.keepSeconds > 600 then cdb.keepSeconds = 600 end

  -- Native sampling is the safe default: P:Def registers original functions and returns them.
  if type(cdb.nativeFunctionSampling) ~= "boolean" then cdb.nativeFunctionSampling = true end
  if type(cdb.nativeEventSampling) ~= "boolean" then cdb.nativeEventSampling = true end

  cdb.eventMarks = nil
  cdb.nativeScriptSampling = nil
  cdb.overlay = nil
  cdb.refFps = nil
  cdb.refLine = nil

  cdb.measured = nil

  -- Tracking outputs must NEVER persist to SavedVariables.
  if cdb.funcStats ~= nil then cdb.funcStats = nil end
  if cdb.samples ~= nil then cdb.samples = nil end

  -- Runtime-only buffers (kept after Stop/closing window, cleared on Start/Clear/reload).
  CPU._rtFuncStats = CPU._rtFuncStats or {} -- [path] = { time/tick/alloc/dealloc stats }
  CPU._nativeFuncs = CPU._nativeFuncs or {} -- [path] = original function sample state
  CPU._nativeByFunction = CPU._nativeByFunction or setmetatable({}, { __mode = "k" })
  CPU._nativeEvents = CPU._nativeEvents or {} -- [eventName] = global event sample state
  CPU._nativeLive = CPU._nativeLive or {} -- [treeKey] = { {t=, c=} } native live call-count deltas

  return cdb
end

local OVERVIEW_KEEP_SECONDS = 120
local OVERVIEW_SPIKE_MS = { 1, 5, 10, 50, 100, 500, 1000 }

local function _NewOverviewWindow(nowT, id, name)
  return {
    startedAt = nowT,
    id = id,
    name = name,
    totalMs = 0,
    frames = 0,
    peakMs = 0,
  }
end

local function _FinishOverviewWindow(window, nowT)
  if not window then return nil end
  window.endedAt = nowT
  window.averageMs = window.frames > 0 and (window.totalMs / window.frames) or 0
  return window
end

local function _StoreOverviewWindow(overview, key, window)
  if not window then return end
  local windows = overview[key]
  windows[#windows + 1] = window
  if #windows > 20 then
    for i = 2, #windows do
      windows[i - 1] = windows[i]
    end
    windows[#windows] = nil
  end
end

local function _TrimOverviewHistory(overview, nowT)
  local history = overview.history
  local head = overview.historyHead or 1
  local tail = overview.historyTail or 0
  local cutoff = nowT - OVERVIEW_KEEP_SECONDS
  while head <= tail do
    local entry = history[head]
    if entry and entry.lastT >= cutoff then
      break
    end
    history[head] = nil
    head = head + 1
  end
  overview.historyHead = head

  if head > 2048 then
    local compact = {}
    for i = head, tail do
      compact[#compact + 1] = history[i]
    end
    overview.history = compact
    overview.historyHead = 1
    overview.historyTail = #compact
  end
end

function CPU:SetOverviewAddonName(addonName)
  if type(addonName) == "string" and addonName ~= "" then
    if self._overviewAddonName ~= addonName then
      self._overviewAddonIndex = nil
    end
    self._overviewAddonName = addonName
  end
end

function CPU:ResetOverviewRuntime()
  self._overview = {
    startedAt = _now(),
    totalMs = 0,
    frames = 0,
    peakMs = 0,
    spikes = {},
    history = {},
    historyHead = 1,
    historyTail = 0,
    combatWindows = {},
    encounterWindows = {},
  }
end

function CPU:SampleOverviewFrame()
  local overview = self._overview
  if not (overview and overview.running) then return end

  local ms = _GetAddOnLastMs(self._overviewAddonName)
  ms = tonumber(ms)
  if not ms then return end

  local nowT = _now()
  overview.totalMs = overview.totalMs + ms
  overview.frames = overview.frames + 1
  if ms > overview.peakMs then
    overview.peakMs = ms
  end

  local history = overview.history
  local second = math.floor(nowT)
  local historyTail = overview.historyTail or 0
  local historyBucket = history[historyTail]
  if not historyBucket or historyBucket.second ~= second then
    historyTail = historyTail + 1
    historyBucket = {
      second = second,
      lastT = nowT,
      totalMs = 0,
      frames = 0,
      peakMs = 0,
      spikes = {},
    }
    history[historyTail] = historyBucket
    overview.historyTail = historyTail
  end
  historyBucket.lastT = nowT
  historyBucket.totalMs = historyBucket.totalMs + ms
  historyBucket.frames = historyBucket.frames + 1
  if ms > historyBucket.peakMs then historyBucket.peakMs = ms end
  for i = 1, #OVERVIEW_SPIKE_MS do
    local threshold = OVERVIEW_SPIKE_MS[i]
    if ms >= threshold then
      overview.spikes[threshold] = (overview.spikes[threshold] or 0) + 1
      historyBucket.spikes[threshold] = (historyBucket.spikes[threshold] or 0) + 1
    end
  end
  _TrimOverviewHistory(overview, nowT)

  local combat = overview.currentCombat
  if combat then
    combat.totalMs = combat.totalMs + ms
    combat.frames = combat.frames + 1
    if ms > combat.peakMs then combat.peakMs = ms end
  end

  local encounter = overview.currentEncounter
  if encounter then
    encounter.totalMs = encounter.totalMs + ms
    encounter.frames = encounter.frames + 1
    if ms > encounter.peakMs then encounter.peakMs = ms end
  end
end

function CPU:HandleOverviewEvent(event, ...)
  local overview = self._overview
  if not overview then return end

  local nowT = _now()
  if event == "PLAYER_REGEN_DISABLED" then
    overview.currentCombat = _NewOverviewWindow(nowT)
  elseif event == "PLAYER_REGEN_ENABLED" then
    overview.lastCombat = _FinishOverviewWindow(overview.currentCombat, nowT)
    _StoreOverviewWindow(overview, "combatWindows", overview.lastCombat)
    overview.currentCombat = nil
  elseif event == "ENCOUNTER_START" then
    local encounterID, encounterName = ...
    overview.currentEncounter = _NewOverviewWindow(nowT, encounterID, encounterName)
  elseif event == "ENCOUNTER_END" then
    overview.lastEncounter = _FinishOverviewWindow(overview.currentEncounter, nowT)
    _StoreOverviewWindow(overview, "encounterWindows", overview.lastEncounter)
    overview.currentEncounter = nil
  end
end

function CPU:StartOverview()
  if not self._overview then
    self:ResetOverviewRuntime()
  end

  local overview = self._overview
  overview.running = true

  if not self._overviewFrame then
    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function()
      CPU:SampleOverviewFrame()
    end)
    frame:SetScript("OnEvent", function(_, event, ...)
      CPU:HandleOverviewEvent(event, ...)
    end)
    self._overviewFrame = frame
  end

  local frame = self._overviewFrame
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("ENCOUNTER_START")
  frame:RegisterEvent("ENCOUNTER_END")
  frame:Show()

  if MemDebug.GetDebugMode and MemDebug:GetDebugMode() == "full" then
    self:RefreshAddonMemory()
  end
end

function CPU:StopOverview()
  local overview = self._overview
  if overview then
    overview.running = false
    local nowT = _now()
    local combat = _FinishOverviewWindow(overview.currentCombat, nowT)
    local encounter = _FinishOverviewWindow(overview.currentEncounter, nowT)
    if combat then
      overview.lastCombat = combat
      _StoreOverviewWindow(overview, "combatWindows", combat)
    end
    if encounter then
      overview.lastEncounter = encounter
      _StoreOverviewWindow(overview, "encounterWindows", encounter)
    end
    overview.currentCombat = nil
    overview.currentEncounter = nil
  end

  local frame = self._overviewFrame
  if frame then
    frame:UnregisterAllEvents()
    frame:Hide()
  end
end

function CPU:GetOverview(windowSeconds)
  local overview = self._overview
  if not overview then return nil end

  local nowT = _now()
  local window = tonumber(windowSeconds) or 5
  if window < 0.1 then window = 0.1 end
  if window > OVERVIEW_KEEP_SECONDS then window = OVERVIEW_KEEP_SECONDS end
  local cutoff = nowT - window
  local recentTotal, recentFrames, recentPeak = 0, 0, 0
  local recentSpikes = {}
  local history = overview.history
  for i = overview.historyHead or 1, overview.historyTail or 0 do
    local entry = history[i]
    if entry and entry.lastT >= cutoff then
      recentTotal = recentTotal + entry.totalMs
      recentFrames = recentFrames + entry.frames
      if entry.peakMs > recentPeak then recentPeak = entry.peakMs end
      for thresholdIndex = 1, #OVERVIEW_SPIKE_MS do
        local threshold = OVERVIEW_SPIKE_MS[thresholdIndex]
        local count = entry.spikes[threshold]
        if count then
          recentSpikes[threshold] = (recentSpikes[threshold] or 0) + count
        end
      end
    end
  end

  return {
    addonName = self._overviewAddonName,
    running = overview.running == true,
    startedAt = overview.startedAt,
    totalMs = overview.totalMs,
    frames = overview.frames,
    averageMs = overview.frames > 0 and (overview.totalMs / overview.frames) or 0,
    peakMs = overview.peakMs,
    recentMs = recentTotal,
    recentFrames = recentFrames,
    recentAverageMs = recentFrames > 0 and (recentTotal / recentFrames) or 0,
    recentPeakMs = recentPeak,
    spikes = overview.spikes,
    recentSpikes = recentSpikes,
    currentCombat = overview.currentCombat,
    lastCombat = overview.lastCombat,
    combatWindows = overview.combatWindows,
    currentEncounter = overview.currentEncounter,
    lastEncounter = overview.lastEncounter,
    encounterWindows = overview.encounterWindows,
  }
end

function CPU:GetOverviewWindows()
  return {
    [5] = self:GetOverview(5),
    [15] = self:GetOverview(15),
    [30] = self:GetOverview(30),
    [60] = self:GetOverview(60),
    [120] = self:GetOverview(120),
  }
end

function CPU:SnapshotOverview(snap, nowT)
  local overview = self._overview
  if not overview then return end

  if MemDebug.GetDebugMode and MemDebug:GetDebugMode() == "full" then
    self:RefreshAddonMemory()
  end

  local stats = self:GetOverview(5)
  if type(snap) == "table" and stats then
    snap.__addonTotalMs = stats.totalMs
    snap.__addonAverageMs = stats.averageMs
    snap.__addonPeakMs = stats.peakMs
    snap.__addonRecentAverageMs = stats.recentAverageMs
    snap.__addonRecentPeakMs = stats.recentPeakMs
    snap.__addonMemoryKB = self._addonMemoryKB
  end

end

function CPU:RefreshAddonMemory()
  if type(UpdateAddOnMemoryUsage) ~= "function"
    or type(GetAddOnMemoryUsage) ~= "function"
    or not self._overviewAddonName
  then
    return nil
  end

  local addonIndex = self._overviewAddonIndex
  if not addonIndex and C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo then
    for index = 1, C_AddOns.GetNumAddOns() do
      if C_AddOns.GetAddOnInfo(index) == self._overviewAddonName then
        addonIndex = index
        self._overviewAddonIndex = index
        break
      end
    end
  end
  if not addonIndex then
    return nil
  end

  UpdateAddOnMemoryUsage()
  self._addonMemoryKB = tonumber(GetAddOnMemoryUsage(addonIndex))
  return self._addonMemoryKB
end

function CPU:GetAddonMemoryKB()
  return self._addonMemoryKB
end


local function _WipeTable(t)
  if not t then return end
  for k in pairs(t) do
    t[k] = nil
  end
end

function CPU:ResetRuntime()
  local overviewRunning = self._overview and self._overview.running == true
  _WipeTable(self._rtFuncStats)

  -- Keep registered original function/event references, but reset baselines on Start/Clear.
  if self._nativeByFunction then
    for _, rec in pairs(self._nativeByFunction) do
      if type(rec) == "table" then
        rec.lastTime = nil
        rec.lastCount = nil
        rec.windowCalls = 0
      end
    end
  end
  if self._nativeEvents then
    for _, rec in pairs(self._nativeEvents) do
      if type(rec) == "table" then
        rec.lastTime = nil
        rec.lastCount = nil
      end
    end
  end
  if self._nativeLive then
    _WipeTable(self._nativeLive)
  end
  self:ResetOverviewRuntime()
  self._overview.running = overviewRunning
end


local function _GetFuncStats()
  CPU._rtFuncStats = CPU._rtFuncStats or {}
  return CPU._rtFuncStats
end

local function _ToNumberEarly(v)
  if v == nil then return nil end
  if type(v) == "number" then return v end
  local ok, s = pcall(tostring, v)
  if not ok then return nil end
  return tonumber(s)
end

local function _BuildPathEarly(moduleName, bucket, funcName)
  local name = tostring(funcName or "Unknown"):gsub("%.", ":")
  return tostring(moduleName or "Unknown") .. "." .. name
end

local function _AddSnapshotCount(snap, key, amount)
  if type(snap) ~= "table" or type(key) ~= "string" or key == "" then
    return
  end
  amount = tonumber(amount) or 0
  if amount <= 0 then
    return
  end
  snap[key] = (tonumber(snap[key]) or 0) + amount
end

local function _FuncTreeKey(path)
  return "Funcs." .. tostring(path or "Unknown")
end

local function _PushNativeLive(key, countDelta, nowT)
  key = tostring(key or "")
  countDelta = tonumber(countDelta) or 0
  if key == "" or countDelta <= 0 then
    return
  end

  local cdb = _EnsureCDB()
  CPU._nativeLive = CPU._nativeLive or {}
  local list = CPU._nativeLive[key]
  if not list then
    list = {}
    CPU._nativeLive[key] = list
  end

  nowT = tonumber(nowT) or _now()
  list[#list + 1] = { t = nowT, c = countDelta }

  local keep = tonumber(cdb and cdb.keepSeconds) or 120
  local interval = MemDebug and MemDebug.GetInterval and MemDebug:GetInterval() or 10
  interval = tonumber(interval) or 10
  if keep < (interval + 2) then
    keep = interval + 2
  end

  local cutoff = nowT - keep
  local drop = 0
  for i = 1, #list do
    local e = list[i]
    if e and e.t and e.t < cutoff then
      drop = i
    else
      break
    end
  end
  if drop > 0 then
    for i = drop + 1, #list do
      list[i - drop] = list[i]
    end
    for i = #list - drop + 1, #list do
      list[i] = nil
    end
  end

end

local function _PushNativeFuncStat(path, msDelta, countDelta)
  local stats = _GetFuncStats()
  path = tostring(path or "Unknown")
  countDelta = tonumber(countDelta) or 0
  msDelta = _ToNumberEarly(msDelta) or 0
  if countDelta <= 0 then
    return
  end

  local st = stats[path]
  if not st then
    st = {
      n = 0,
      timeSum = 0,
      timeLast = 0,
      timeMax = 0,
      native = true,
    }
    stats[path] = st
  end

  st.native = true
  local perCall = msDelta / countDelta
  st.n = (st.n or 0) + countDelta
  st.timeSum = (st.timeSum or 0) + msDelta
  st.timeLast = perCall
  if st.timeMin == nil or perCall < st.timeMin then st.timeMin = perCall end
  if st.timeMax == nil or perCall > st.timeMax then st.timeMax = perCall end
end


function CPU:NativeFunctionSamplingEnabled()
  local cdb = _EnsureCDB()
  if MemDebug and MemDebug.GetDebugMode and MemDebug:GetDebugMode() == "full" then
    return false
  end
  return cdb and cdb.nativeFunctionSampling == true and type(GetFunctionCPUUsage) == "function"
end

function CPU:SetNativeFunctionSamplingEnabled(on)
  local cdb = _EnsureCDB()
  if not cdb then return end
  cdb.nativeFunctionSampling = (on == true)
end

function CPU:NativeEventSamplingEnabled()
  local cdb = _EnsureCDB()
  if MemDebug and MemDebug.GetDebugMode and MemDebug:GetDebugMode() == "full" then
    return false
  end
  return cdb and cdb.nativeEventSampling == true and type(GetEventCPUUsage) == "function"
end

function CPU:SetNativeEventSamplingEnabled(on)
  local cdb = _EnsureCDB()
  if not cdb then return end
  cdb.nativeEventSampling = (on == true)
end

function CPU:ApplyDebugModeDefaults(mode)
  local cdb = _EnsureCDB()
  if not cdb then return end

  mode = tostring(mode or "light")
  if mode == "full" then
    cdb.nativeFunctionSampling = false
    cdb.nativeEventSampling = false
    cdb.enabled = true
  else
    cdb.nativeFunctionSampling = true
    cdb.nativeEventSampling = true
    cdb.enabled = true
  end
end

function CPU:IsScriptProfileEnabled()
  local v
  if C_CVar and C_CVar.GetCVar then
    v = C_CVar.GetCVar("scriptProfile")
  elseif GetCVar then
    v = GetCVar("scriptProfile")
  end
  return tostring(v or "0") == "1"
end

function CPU:SetScriptProfile(on)
  local value = (on == true) and "1" or "0"
  if C_CVar and C_CVar.SetCVar then
    C_CVar.SetCVar("scriptProfile", value)
  elseif SetCVar then
    SetCVar("scriptProfile", value)
  end
end

function CPU:SetScriptProfileAndReload(on)
  self:SetScriptProfile(on == true)
  local db = MemDebug and MemDebug.GetDB and MemDebug:GetDB() or nil
  if db then
    db.openAfterReload = true
  end
  if ReloadUI then
    ReloadUI()
  end
end

function CPU:GetScaleMs()
  local cdb = _EnsureCDB()
  return cdb and (tonumber(cdb.scaleMs) or 16.7) or 16.7
end

function CPU:SetScaleMs(ms)
  local cdb = _EnsureCDB()
  if not cdb then return end
  ms = tonumber(ms) or 16.7
  if ms < 1 then ms = 1 end
  if ms > 100 then ms = 100 end
  cdb.scaleMs = ms
end


function CPU:RegisterFunction(moduleName, bucket, funcName, fn, opt)
  if type(fn) ~= "function" then return end
  opt = opt or {}
  moduleName = tostring(moduleName or "Unknown")
  funcName = tostring(funcName or "UnknownFunc"):gsub("%.", ":")
  bucket = nil

  local path = _BuildPathEarly(moduleName, bucket, funcName)
  self._nativeFuncs = self._nativeFuncs or {}
  self._nativeByFunction = self._nativeByFunction or setmetatable({}, { __mode = "k" })
  local registrationChanged = self._nativeFuncs[path] == nil

  local rec = self._nativeByFunction[fn]
  if not rec then
    rec = {
      fn = fn,
      canonicalPath = path,
      moduleName = moduleName,
      bucket = bucket,
      funcName = funcName,
      aliases = {},
      windowCalls = 0,
    }
    self._nativeByFunction[fn] = rec
  end

  local previous = self._nativeFuncs[path]
  if previous and previous ~= rec then
    previous.aliases[path] = nil
    if previous.canonicalPath == path then
      local replacementPath, replacement = next(previous.aliases)
      previous.canonicalPath = replacementPath
      if replacement then
        previous.moduleName = replacement.moduleName
        previous.bucket = replacement.bucket
        previous.funcName = replacement.funcName
      else
        previous.retired = true
      end
    end
  end

  rec.aliases[path] = {
    path = path,
    moduleName = moduleName,
    bucket = bucket,
    funcName = funcName,
    kind = opt.kind or "native",
    owner = opt.owner,
    methodName = opt.methodName,
  }
  if not rec.canonicalPath then
    rec.canonicalPath = path
    rec.moduleName = moduleName
    rec.bucket = bucket
    rec.funcName = funcName
  end
  rec.retired = false
  self._nativeFuncs[path] = rec

  if registrationChanged then
    self._registrationVersion = (self._registrationVersion or 0) + 1
  end

  return path, rec
end

function CPU:SetRegistrationKind(path, kind)
  local rec = self._nativeFuncs and self._nativeFuncs[path]
  local alias = rec and rec.aliases and rec.aliases[path]
  if alias then
    alias.kind = kind
  end
end

function CPU:GetFunctionRegistration(path)
  local rec = self._nativeFuncs and self._nativeFuncs[path]
  if not rec then return nil end
  return rec, rec.aliases and rec.aliases[path]
end

function CPU:GetFullMeasurementBackend()
  if C_AddOnProfiler and C_AddOnProfiler.MeasureCall and _ProfilerEnabled() then
    return "MeasureCall"
  end
  return "timer fallback - allocation unavailable"
end

function CPU:GetMeasurementState(path)
  local rec, alias = self:GetFunctionRegistration(path)
  if not (rec and alias) then return nil end

  if alias.kind ~= "wrapped"
    and alias.owner
    and alias.methodName
    and alias.owner[alias.methodName] ~= rec.fn
  then
    return "Stale owner reference"
  end
  local aliasSuffix = path ~= rec.canonicalPath and (" - alias of " .. tostring(rec.canonicalPath)) or ""
  if alias.kind == "count-only" then
    return "Count only" .. aliasSuffix
  end
  if alias.kind == "restricted" then
    return "Excluded - restricted path" .. aliasSuffix
  end

  local mode = MemDebug and MemDebug.GetDebugMode and MemDebug:GetDebugMode() or "light"
  if mode == "full" then
    local backend = self:GetFullMeasurementBackend()
    if alias.kind == "wrapped" then
      return "Wrapped - " .. backend .. aliasSuffix
    end
    for wrappedPath, registeredAlias in pairs(rec.aliases) do
      if registeredAlias.kind == "wrapped" then
        return "Measured via alias " .. tostring(wrappedPath) .. " - " .. backend .. aliasSuffix
      end
    end
    return "Registered after Full-mode wrapping" .. aliasSuffix
  end

  if type(GetFunctionCPUUsage) ~= "function" or not self:IsScriptProfileEnabled() then
    return "Native unavailable - scriptProfile=1" .. aliasSuffix
  end
  if (rec.windowCalls or 0) > 0 then
    return (alias.kind == "secure-native" and "Secure native" or "Native") .. aliasSuffix
  end
  if (rec.everCount or 0) > 0 then
    return "Called earlier" .. aliasSuffix
  end
  return "Registered - no calls in this window" .. aliasSuffix
end

function CPU:RegisterEvent(eventName)
  if type(eventName) ~= "string" or eventName == "" then return end
  self._nativeEvents = self._nativeEvents or {}
  if not self._nativeEvents[eventName] then
    self._nativeEvents[eventName] = { eventName = eventName }
    self._registrationVersion = (self._registrationVersion or 0) + 1
  end
end

function CPU:PrimeNativeBaselines()
  if self._nativeByFunction and type(GetFunctionCPUUsage) == "function" then
    for _, rec in pairs(self._nativeByFunction) do
      if type(rec) == "table" and not rec.retired and type(rec.fn) == "function" then
        local total, count = GetFunctionCPUUsage(rec.fn, false)
        rec.lastTime = _ToNumberEarly(total)
        rec.lastCount = _ToNumberEarly(count)
        rec.everCount = rec.lastCount or rec.everCount or 0
      end
    end
  end

  if self._nativeEvents and type(GetEventCPUUsage) == "function" then
    for eventName, rec in pairs(self._nativeEvents) do
      if type(rec) == "table" then
        local total, count = GetEventCPUUsage(eventName)
        rec.lastTime = _ToNumberEarly(total)
        rec.lastCount = _ToNumberEarly(count)
      end
    end
  end
end

function CPU:SampleNativeFunctions(nowT, interval, snap)
  if not self:NativeFunctionSamplingEnabled() then return end
  if not self._nativeByFunction then return end

  nowT = nowT or _now()

  for _, rec in pairs(self._nativeByFunction) do
    local path = rec and rec.canonicalPath
    local fn = rec and rec.fn
    local moduleEnabled = not (MemDebug and MemDebug.IsModuleEnabled)
      or MemDebug:IsModuleEnabled(rec and rec.moduleName)

    if not rec.retired and moduleEnabled and type(fn) == "function" then
      local total, count = GetFunctionCPUUsage(fn, false)
      total = _ToNumberEarly(total)
      count = _ToNumberEarly(count)

      if total and count then
        if rec.lastTime ~= nil and rec.lastCount ~= nil then
          local msDelta = total - rec.lastTime
          local countDelta = count - rec.lastCount

          if msDelta < 0 or countDelta < 0 then
            msDelta = 0
            countDelta = 0
          end

          if countDelta > 0 then
            _PushNativeFuncStat(path, msDelta, countDelta)
            _PushNativeLive(_FuncTreeKey(path), countDelta, nowT)
            _AddSnapshotCount(snap, "Funcs.Total", countDelta)
            _AddSnapshotCount(snap, _FuncTreeKey(path), countDelta)
            rec.windowCalls = (rec.windowCalls or 0) + countDelta
          end
        end

        rec.lastTime = total
        rec.lastCount = count
        rec.everCount = count
      end
    elseif rec then
      -- Do not carry disabled-period calls into the first sample after re-enabling.
      rec.lastTime = nil
      rec.lastCount = nil
    end
  end

end

function CPU:SampleNativeEvents(nowT, interval, snap)
  if not self:NativeEventSamplingEnabled() then return end
  if not self._nativeEvents then return end

  nowT = nowT or _now()

  for eventName, rec in pairs(self._nativeEvents) do
    local total, count = GetEventCPUUsage(eventName)
    total = _ToNumberEarly(total)
    count = _ToNumberEarly(count)

    if total and count then
      if rec.lastTime ~= nil and rec.lastCount ~= nil then
        local msDelta = total - rec.lastTime
        local countDelta = count - rec.lastCount

        if msDelta < 0 or countDelta < 0 then
          msDelta = 0
          countDelta = 0
        end

        if countDelta > 0 then
          local path = "Events.Global." .. tostring(eventName)
          _PushNativeFuncStat(path, msDelta, countDelta)
          _PushNativeLive(path, countDelta, nowT)
          _AddSnapshotCount(snap, "Events.Global.Total", countDelta)
          _AddSnapshotCount(snap, path, countDelta)
        end
      end

      rec.lastTime = total
      rec.lastCount = count
    end
  end

end

function CPU:PollNative(nowT)
  nowT = tonumber(nowT) or _now()
  if self.SampleNativeFunctions then
    self:SampleNativeFunctions(nowT, nil, nil)
  end
  if self.SampleNativeEvents then
    self:SampleNativeEvents(nowT, nil, nil)
  end
end

function CPU:BuildNativeLiveSnapshot(windowSec, nowT, out)
  out = out or {}
  for k in pairs(out) do out[k] = nil end

  windowSec = tonumber(windowSec) or (MemDebug and MemDebug.GetInterval and MemDebug:GetInterval()) or 10
  if windowSec < 0.1 then windowSec = 0.1 end
  nowT = tonumber(nowT) or _now()

  out.__interval = windowSec
  out.__time = nowT

  local cutoff = nowT - windowSec
  local fnTotal, eventTotal = 0, 0
  local live = self._nativeLive
  if type(live) == "table" then
    for key, list in pairs(live) do
      local sum = 0
      if type(list) == "table" then
        for i = #list, 1, -1 do
          local e = list[i]
          if not e or not e.t then
            break
          end
          if e.t < cutoff then
            break
          end
          sum = sum + (tonumber(e.c) or 0)
        end
      end

      if sum > 0 then
        out[key] = sum
        if key:sub(1, 6) == "Funcs." then
          fnTotal = fnTotal + sum
        elseif key:sub(1, 7) == "Events." then
          eventTotal = eventTotal + sum
        end
      end
    end
  end

  out["Funcs.Total"] = fnTotal
  out["Events.Total"] = eventTotal
  return out
end

-------------------
-- Per-function measurement: path helpers + stats
-------------------
local function _BuildPath(moduleName, bucket, funcName)
  local name = tostring(funcName or "Unknown"):gsub("%.", ":")
  return tostring(moduleName or "Unknown") .. "." .. name
end

function CPU:GetFuncStat(path)
  if not path or path == "" then return nil end
  local rec = self._nativeFuncs and self._nativeFuncs[path]
  if rec and rec.canonicalPath then
    path = rec.canonicalPath
  end
  local s = _GetFuncStats()
  return s and s[path]
end

-- Generic accessor (Funcs.* or Events.*). Kept separate so Window can show stats for event leaves.
function CPU:GetStat(path)
  return self:GetFuncStat(path)
end


local function _ToNumber(v)
  if v == nil then return nil end
  if type(v) == "number" then return v end
  local ok, s = pcall(tostring, v)
  if not ok then return nil end
  return tonumber(s)
end

local function _PushFuncStat(path, ms, ticks, allocBytes, deallocBytes)
  if not _EnsureCDB() then return end

  local stats = _GetFuncStats()
  local st = stats[path]
  if not st then
    st = {
      n = 0,

      timeSum = 0,
      timeMin = nil,
      timeMax = nil,
      timeLast = nil,

      tickSum = 0,
      tickMax = nil,
      tickLast = nil,

      allocSum = 0,
      allocMax = nil,
      allocLast = nil,

      deallocSum = 0,
      deallocMax = nil,
      deallocLast = nil,
    }
    stats[path] = st
  end

  st.n = (st.n or 0) + 1

  ms = _ToNumber(ms) or 0
  st.timeSum  = (st.timeSum or 0) + ms
  st.timeLast = ms
  if st.timeMin == nil or ms < st.timeMin then st.timeMin = ms end
  if st.timeMax == nil or ms > st.timeMax then st.timeMax = ms end

  ticks = _ToNumber(ticks)
  if ticks then
    st.tickSum  = (st.tickSum or 0) + ticks
    st.tickLast = ticks
    if st.tickMax == nil or ticks > st.tickMax then st.tickMax = ticks end
  end

  allocBytes = _ToNumber(allocBytes)
  if allocBytes then
    st.allocSum  = (st.allocSum or 0) + allocBytes
    st.allocLast = allocBytes
    if st.allocMax == nil or allocBytes > st.allocMax then st.allocMax = allocBytes end
  end

  deallocBytes = _ToNumber(deallocBytes)
  if deallocBytes then
    st.deallocSum  = (st.deallocSum or 0) + deallocBytes
    st.deallocLast = deallocBytes
    if st.deallocMax == nil or deallocBytes > st.deallocMax then st.deallocMax = deallocBytes end
  end
end



local function _CallMeasuredPath(path, fn, ...)
  if C_AddOnProfiler and C_AddOnProfiler.MeasureCall and _ProfilerEnabled() then
    local measured = t_pack(C_AddOnProfiler.MeasureCall(fn, ...))
    local results = measured[1]
    if results and results.elapsedMilliseconds then
      local ms = _ToNumber(results.elapsedMilliseconds) or 0
      local ticks = _ToNumber(results.elapsedTicks)
      local allocB = _ToNumber(results.allocatedBytes)
      local dealloc = _ToNumber(results.deallocatedBytes)
      _PushFuncStat(path, ms, ticks, allocB, dealloc)
    end
    return t_unpack(measured, 2, measured.n)
  end

  local t0 = debugprofilestop and debugprofilestop() or 0
  local returns = t_pack(fn(...))
  local t1 = debugprofilestop and debugprofilestop() or t0
  local ms = t1 - t0
  _PushFuncStat(path, ms)
  return t_unpack(returns, 1, returns.n)
end

function CPU:CallMeasured(moduleName, bucket, funcName, fn, ...)
  local path = _BuildPath(moduleName, bucket, funcName)
  if type(fn) ~= "function" then
    return
  end
  local rec = self._nativeFuncs and self._nativeFuncs[path]
  if rec and rec.canonicalPath then
    path = rec.canonicalPath
  end
  return _CallMeasuredPath(path, fn, ...)
end
