
-- File: LibPleebug-1.lua
-- Purpose: Dev-only profiling of events and function call frequency.
--
-- Modes:
--   Light mode
--     Uses Blizzard native CPU counters such as GetFunctionCPUUsage.
--     It keeps original function references in the execution path and avoids wrapper calls.
--     It requires scriptProfile=1 and a reload.
--     It shows CPU call counts/calls per second, but not per-call memory deltas.
--
--   Full debug mode
--     Routes every P:Def and P:SecDef function through Pleebug wrappers.
--     It tracks calls, CPU cost, and memory allocation data.
--     It is loaded only after the user explicitly selects Full debug and reloads.
--     It can taint and is meant for short debug sessions with frequent reloads.
--
-- Instrumentation note:
--   DropIn registers the module/table and installs event/script hooks.
--   Local functions still need P:Def(name, fn), because Lua local functions are invisible
--   unless their function reference is passed to Pleebug.
--   In Light mode P:Def returns the original function unchanged.
--   In Full debug mode P:Def and P:SecDef install wrappers for every registration.



local MAJOR, MINOR = "LibPleebug-1", 1
local LibStub = _G.LibStub
if not LibStub then return end

local MemDebug, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not MemDebug then return end

-- SavedVariables root (flat DB, library-owned)
_G.LibPleebugDB = _G.LibPleebugDB or {}

local function _GetSavedDebugMode()
  local db = _G.LibPleebugDB
  if type(db) == "table" and db.debugMode == "full" then
    return "full"
  end
  return "light"
end

MemDebug.__pleebugLoadMode = _GetSavedDebugMode()


MemDebug._enabled = false
MemDebug._ticker = nil
MemDebug._counts = MemDebug._counts or {}
MemDebug._rollingCounts = MemDebug._rollingCounts or {}
MemDebug._lastSnapshot = MemDebug._lastSnapshot or {}

-- Used by AceEvent method wrapping
MemDebug._wrapped = MemDebug._wrapped or setmetatable({}, { __mode = "k" })
MemDebug._origNewModule = MemDebug._origNewModule or nil

-- Runtime-only source grouping. Rebuilt from DropIn caller paths every load.
MemDebug._moduleGroups = {}

local function _now()
  if GetTimePreciseSec then
    return GetTimePreciseSec()
  end
  return (GetTime and GetTime()) or 0
end

local function _wipe(t)
  if not t then return end
  for k in pairs(t) do
    t[k] = nil
  end
end

local function _getModuleName(obj)
  if not obj then return "Unknown" end
  local n = (obj.GetName and obj:GetName()) or obj.moduleName or obj.name or "Unknown"
  if n == ADDON_NAME then
    return "Core"
  end
  return tostring(n)
end

-- Tick hooks (optional modules can register; called from SnapshotAndReset)
function MemDebug:RegisterTickHook(id, fn)
  if not id or id == "" then return end
  if type(fn) ~= "function" then return end
  self._tickHooks = self._tickHooks or {}
  self._tickHooks[id] = fn
end

function MemDebug:UnregisterTickHook(id)
  if not self._tickHooks then return end
  self._tickHooks[id] = nil
end


local function _ensureDB()
  local mdb = _G.LibPleebugDB
  if type(mdb) ~= "table" then return nil end

  -- Runtime-only init guard. Do NOT store this in SavedVariables.
  -- A persisted init flag can survive /reload and make mode/default setup stale.
  if MemDebug.__pleebugDBInit == true then
    return mdb
  end
  MemDebug.__pleebugDBInit = true
  mdb.__pleebugInit = nil

  -- Tracking must never persist across reloads. Only runtime Start() enables tracking.
  mdb.enabled = false
  if type(mdb.interval) ~= "number" then mdb.interval = 10 end
  if mdb.interval < 5 then mdb.interval = 5 end
  if mdb.interval > 60 then mdb.interval = 60 end

  -- Window-only UI readability (dev)
  if type(mdb.fontSize) ~= "number" then mdb.fontSize = 14 end
  if mdb.fontSize < 10 then mdb.fontSize = 10 end
  if mdb.fontSize > 22 then mdb.fontSize = 22 end

  if type(mdb.printToChat) ~= "boolean" then mdb.printToChat = false end
  if type(mdb.trackEvents) ~= "boolean" then mdb.trackEvents = true end
  if type(mdb.trackFuncs) ~= "boolean" then mdb.trackFuncs = true end

  -- Wrapper interception is an explicit persisted choice read before Lua files load.
  -- scriptProfile controls Blizzard's native counters, not whether Pleebug wraps functions.
  mdb.debugMode = mdb.debugMode == "full" and "full" or "light"
  mdb.__pleebugLoadMode = nil
  mdb.__pleebugForceFullDebug = nil
  mdb.fullDebugOnNextLoad = nil
  MemDebug.__pleebugLoadMode = mdb.debugMode

  -- One-shot UI restore after mode/CVar reload buttons.
  if type(mdb.openAfterReload) ~= "boolean" then mdb.openAfterReload = false end

  -- File discovery is rebuilt on every load so removed or renamed files do not remain in the UI.
  mdb.knownModules = {}

  -- Friendly names (custom display names) shown in UI: real module name -> friendly
  mdb.friendly = mdb.friendly or {}

  -- Friendly aliases (aliases) shown in UI: alias -> real module name
  mdb.moduleAliases = mdb.moduleAliases or {}

  -- Preserve the user's module enable state. Newly discovered filenames default to enabled.
  mdb.modules = mdb.modules or {}

  -- Removed profiler systems must not leave stale controls in SavedVariables.
  mdb.autoWrap = nil
  mdb.series = nil
  mdb.traceEnabled = nil
  mdb.traceMax = nil
  mdb.traceStyle = nil
  mdb.traceWindow = nil

  -- Pleebug now has one bucket per source file and no nested bucket metadata.
  mdb.buckets = {}
  mdb.bucketLists = {}

  -- Flush pending known modules (Attach/Ping can run before DB exists)
  if MemDebug._pendingKnownModules then
    for name, v in pairs(MemDebug._pendingKnownModules) do
      if v == true and type(name) == "string" and name ~= "" then
        mdb.knownModules[name] = true
        if mdb.modules[name] == nil then
          mdb.modules[name] = true
        end
      end
    end
    MemDebug._pendingKnownModules = nil
  end

  return mdb
end



function MemDebug:GetDB()
  return _ensureDB()
end

function MemDebug:GetDebugMode()
  return self.__pleebugLoadMode or "light"
end

function MemDebug:GetLoadMode()
  -- Used by P:Def while addon files are loading.
  return self.__pleebugLoadMode or "light"
end

function MemDebug:SetDebugMode(mode)
  mode = tostring(mode or "light")
  if mode ~= "full" then
    mode = "light"
  end

  local db = _ensureDB()
  if db then
    db.openAfterReload = true
    db.debugMode = mode
    db.__pleebugLoadMode = nil
    db.__pleebugForceFullDebug = nil
    db.fullDebugOnNextLoad = nil
    db.__pleebugInit = nil

    db.trackEvents = true
    db.trackFuncs = true
  end

  local wantScriptProfile = (mode == "light")
  if self.CPU and self.CPU.SetScriptProfile then
    self.CPU:SetScriptProfile(wantScriptProfile)
  else
    local value = wantScriptProfile and "1" or "0"
    if C_CVar and C_CVar.SetCVar then
      C_CVar.SetCVar("scriptProfile", value)
    elseif SetCVar then
      SetCVar("scriptProfile", value)
    end
  end
end

function MemDebug:SetDebugModeAndReload(mode)
  mode = tostring(mode or "light")
  if mode ~= "full" then
    mode = "light"
  end

  -- Persist the explicit wrapper mode and set the matching native profiler CVar.
  -- The reload is required because P:Def chooses original functions or wrappers at file load.
  self:SetDebugMode(mode)

  local db = _ensureDB()
  if db then
    db.openAfterReload = true
  end

  if ReloadUI then
    ReloadUI()
  end
end

function MemDebug:OpenAfterReloadIfRequested()
  local db = _ensureDB()
  if not db or db.openAfterReload ~= true then
    return
  end

  db.openAfterReload = false

  if self.Window then
    if self.Window.Open then
      self.Window:Open()
    elseif self.Window.Toggle then
      self.Window:Toggle()
    end
  end
end

local function _moduleAllowed(mdb, moduleName)

  if not mdb or not mdb.modules then return true end
  local v = mdb.modules[moduleName]
  if v == nil then
    mdb.modules[moduleName] = true
    return true
  end
  return v ~= false
end

local function _inc(key, amount)
  if not key then return end
  amount = amount or 1
  local c = MemDebug._counts
  c[key] = (c[key] or 0) + amount
end

local ROLLING_BUCKET_SECONDS = 62

local function _rollingPush(key, amount, nowT)
  if type(key) ~= "string" or key == "" or key:match("^__") then
    return
  end

  amount = tonumber(amount) or 1
  if amount <= 0 then
    return
  end

  nowT = tonumber(nowT) or _now()
  local store = MemDebug._rollingCounts
  if type(store) ~= "table" then
    store = {}
    MemDebug._rollingCounts = store
  end

  local buckets = store[key]
  if not buckets then
    buckets = {}
    store[key] = buckets
  end

  local second = math.floor(nowT)
  local slot = (second % ROLLING_BUCKET_SECONDS) + 1
  local secondSlot = slot + ROLLING_BUCKET_SECONDS
  if buckets[secondSlot] ~= second then
    buckets[secondSlot] = second
    buckets[slot] = amount
  else
    buckets[slot] = (buckets[slot] or 0) + amount
  end
end

function MemDebug:BuildRollingSnapshot(windowSec, nowT, out)
  out = out or {}
  _wipe(out)

  windowSec = tonumber(windowSec) or (self.GetInterval and self:GetInterval()) or 10
  if windowSec < 0.1 then windowSec = 0.1 end

  nowT = tonumber(nowT) or _now()
  out.__interval = windowSec
  out.__time = nowT

  local cutoffSecond = math.floor(nowT - windowSec)
  local store = self._rollingCounts
  if type(store) == "table" then
    for key, buckets in pairs(store) do
      local sum = 0
      if type(buckets) == "table" then
        for slot = 1, ROLLING_BUCKET_SECONDS do
          local second = buckets[slot + ROLLING_BUCKET_SECONDS]
          if second and second >= cutoffSecond then
            sum = sum + (buckets[slot] or 0)
          end
        end
      end
      if sum > 0 then
        out[key] = sum
      end
    end
  end

  return out
end


function MemDebug:IsEnabled()
  return self._enabled == true
end

function MemDebug:SetEnabled(state)
  state = not not state
  self._enabled = state

  if state then
    self:Start()
  else
    self:Stop()
  end
end


function MemDebug:GetInterval()
  local mdb = _ensureDB()
  return (mdb and mdb.interval) or 2
end

function MemDebug:SetInterval(seconds)
  local mdb = _ensureDB()
  seconds = tonumber(seconds) or 10
  seconds = math.floor(seconds + 0.5)
  if seconds < 5 then seconds = 5 end
  if seconds > 60 then seconds = 60 end
  if mdb then
    mdb.interval = seconds
  end


  if self._ticker then
    self:Start()
  end
end

function MemDebug:GetFontSize()
  local mdb = _ensureDB()
  return (mdb and mdb.fontSize) or 14
end

function MemDebug:SetFontSize(size)
  local mdb = _ensureDB()
  size = tonumber(size) or 14
  size = math.floor(size + 0.5)
  if size < 10 then size = 10 end
  if size > 22 then size = 22 end
  if mdb then
    mdb.fontSize = size
  end
end

-- Internal: ensure module exists in DB lists so UI can populate.
function MemDebug:_RegisterKnownModule(moduleName)
  moduleName = tostring(moduleName or "Unknown")
  if moduleName == "" then moduleName = "Unknown" end

  local mdb = _ensureDB()
  if not mdb then
    -- UI can open before DB exists. Buffer modules so the list can populate.
    self._pendingKnownModules = self._pendingKnownModules or {}
    self._pendingKnownModules[moduleName] = true
    return
  end


  mdb.knownModules = mdb.knownModules or {}
  mdb.modules = mdb.modules or {}

  if mdb.knownModules[moduleName] ~= true then
    mdb.knownModules[moduleName] = true
  end

  -- Default: enabled unless explicitly disabled.
  if mdb.modules[moduleName] == nil then
    mdb.modules[moduleName] = true
  end
end


function MemDebug:GetModuleDisplayName(moduleName)
  moduleName = tostring(moduleName or "Unknown")
  local mdb = _ensureDB()
  if not mdb or not mdb.friendly then
    return moduleName
  end
  local v = mdb.friendly[moduleName]
  if type(v) == "string" and v ~= "" then
    return v
  end
  return moduleName
end

function MemDebug:SetModuleFriendlyName(moduleName, friendly)
  moduleName = tostring(moduleName or "Unknown")
  if moduleName == "" then moduleName = "Unknown" end

  -- Ensure module exists in lists so UI can show it
  self:_RegisterKnownModule(moduleName)

  local mdb = _ensureDB()
  if not mdb then return end
  mdb.friendly = mdb.friendly or {}

  if friendly == nil or friendly == "" then
    mdb.friendly[moduleName] = nil
  else
    mdb.friendly[moduleName] = tostring(friendly)
  end
end

function MemDebug:GetKnownModules()
  local mdb = _ensureDB()
  local out = {}

  if not mdb then
    local pending = self._pendingKnownModules
    if pending then
      for name, v in pairs(pending) do
        if v == true and type(name) == "string" and name ~= "" then
          out[#out + 1] = name
        end
      end
      table.sort(out, function(a, b) return a < b end)
    end
    return out
  end

  local km = mdb.knownModules or {}
  for name, v in pairs(km) do
    if v == true and type(name) == "string" and name ~= "" then
      out[#out + 1] = name
    end
  end

  table.sort(out, function(a, b) return a < b end)
  return out
end

function MemDebug:GetModuleGroup(moduleName)
  moduleName = tostring(moduleName or "Unknown")
  local groups = self._moduleGroups
  return groups and groups[moduleName] or nil
end

function MemDebug:GetModuleGroupState(groupName)
  groupName = tostring(groupName or "")
  if groupName == "" then
    return false, 0, 0
  end

  local mdb = _ensureDB()
  if not mdb then
    return false, 0, 0
  end

  local enabledCount = 0
  local totalCount = 0
  local knownModules = mdb.knownModules or {}
  local modules = mdb.modules or {}

  for moduleName, known in pairs(knownModules) do
    if known == true and self:GetModuleGroup(moduleName) == groupName then
      totalCount = totalCount + 1
      if modules[moduleName] ~= false then
        enabledCount = enabledCount + 1
      end
    end
  end

  return totalCount > 0 and enabledCount == totalCount, enabledCount, totalCount
end

function MemDebug:SetModuleGroupEnabled(groupName, enabled)
  groupName = tostring(groupName or "")
  if groupName == "" then return end

  local mdb = _ensureDB()
  if not mdb then return end

  enabled = not not enabled
  mdb.modules = mdb.modules or {}

  local knownModules = mdb.knownModules or {}
  for moduleName, known in pairs(knownModules) do
    if known == true and self:GetModuleGroup(moduleName) == groupName then
      mdb.modules[moduleName] = enabled
      if enabled and self:IsEnabled() then
        self:_InstallUniversalOnAttached(moduleName)
      end
    end
  end
end

function MemDebug:IsModuleEnabled(moduleName)
  local mdb = _ensureDB()
  if not mdb then return true end

  moduleName = tostring(moduleName or "Unknown")
  local v = mdb.modules and mdb.modules[moduleName]
  if v == nil then
    return true
  end
  return v ~= false
end

function MemDebug:EnableAllModules()
  local mdb = _ensureDB()
  if not mdb then return end
  mdb.modules = mdb.modules or {}
  mdb.knownModules = mdb.knownModules or {}

  for name, v in pairs(mdb.knownModules) do
    if v == true then
      mdb.modules[name] = true
    end
  end
end

function MemDebug:DisableAllModules()
  local mdb = _ensureDB()
  if not mdb then return end
  mdb.modules = mdb.modules or {}
  mdb.knownModules = mdb.knownModules or {}

  for name, v in pairs(mdb.knownModules) do
    if v == true then
      mdb.modules[name] = false
    end
  end
end

function MemDebug:GetModuleAlias(moduleName)
  local mdb = _ensureDB()
  if not mdb or not mdb.moduleAliases then return nil end
  moduleName = tostring(moduleName or "Unknown")
  local a = mdb.moduleAliases[moduleName]
  if type(a) ~= "string" or a == "" then
    return nil
  end
  return a
end

function MemDebug:SetModuleAlias(moduleName, alias)
  local mdb = _ensureDB()
  if not mdb then return end
  moduleName = tostring(moduleName or "Unknown")

  self:_RegisterKnownModule(moduleName)

  mdb.moduleAliases = mdb.moduleAliases or {}

  if alias == nil then
    mdb.moduleAliases[moduleName] = nil
    return
  end

  alias = tostring(alias or "")
  alias = alias:gsub("^%s+", ""):gsub("%s+$", "")
  if alias == "" then
    mdb.moduleAliases[moduleName] = nil
  else
    mdb.moduleAliases[moduleName] = alias
  end
end

function MemDebug:GetModuleDisplayName(moduleName)
  moduleName = tostring(moduleName or "Unknown")
  local a = self:GetModuleAlias(moduleName)
  if a and a ~= "" and a ~= moduleName then
    return a .. " (" .. moduleName .. ")"
  end
  return moduleName
end



function MemDebug:SetModuleEnabled(moduleName, enabled)
  local mdb = _ensureDB()
  if not mdb then return end

  moduleName = tostring(moduleName or "Unknown")
  self:_RegisterKnownModule(moduleName)

  enabled = not not enabled
  mdb.modules[moduleName] = enabled

  if enabled and self:IsEnabled() then
    self:_InstallUniversalOnAttached(moduleName)
  end
end
function MemDebug:TrackKey(key, amount)
  if not self:IsEnabled() then return end
  amount = amount or 1
  _inc(key, amount)
  _rollingPush(key, amount)
end

function MemDebug:TrackEvent(moduleName, eventName)
  if not self:IsEnabled() then
    return
  end

  local mdb = _ensureDB()
  if not mdb then
    return
  end

  local fullDebug = self.GetDebugMode and self:GetDebugMode() == "full"

  -- In Full debug mode, the preset owns tracking. Do not let legacy manual
  -- event toggles suppress wrapper/event data.
  if not fullDebug and not mdb.trackEvents then
    return
  end

  local m = tostring(moduleName or "Unknown")
  if not self:IsModuleEnabled(m) then
    return
  end


  local e = tostring(eventName or "UNKNOWN_EVENT")

  local cpu = self.CPU
  if cpu and cpu.RegisterEvent then
    cpu:RegisterEvent(e)
  end

  local eventKey = ("Events.%s.%s"):format(m, e)
  _inc("Events.Total", 1)
  _inc(eventKey, 1)
  local nowT = _now()
  _rollingPush("Events.Total", 1, nowT)
  _rollingPush(eventKey, 1, nowT)

end


function MemDebug:TrackFunc(moduleName, bucketName, funcName)
  if not self:IsEnabled() then
    return
  end

  local mdb = _ensureDB()
  if not mdb then
    return
  end

  local fullDebug = self.GetDebugMode and self:GetDebugMode() == "full"

  -- In Full debug mode, the preset owns tracking. Do not let legacy manual
  -- function toggles suppress wrapper data.
  if not fullDebug and not mdb.trackFuncs then
    return
  end

  local m = tostring(moduleName or "Unknown")
  if not self:IsModuleEnabled(m) then
    return
  end


  local f = tostring(funcName or "UnknownFunc"):gsub("%.", ":")
  local key = ("Funcs.%s.%s"):format(m, f)

  _inc("Funcs.Total", 1)
  _inc(key, 1)
  local nowT = _now()
  _rollingPush("Funcs.Total", 1, nowT)
  _rollingPush(key, 1, nowT)

end


-- Convenience: returns a tiny tracker function you can keep local in a module file
-- Usage: local Track = MemDebug:MakeTracker("UnitFrames", "player"); Track("UnitHealth")
function MemDebug:MakeTracker(moduleName, defaultBucket)
  moduleName = tostring(moduleName or "Unknown")
  defaultBucket = defaultBucket and tostring(defaultBucket) or nil
  return function(funcName, bucketOverride)
    local b = bucketOverride ~= nil and tostring(bucketOverride) or defaultBucket
    MemDebug:TrackFunc(moduleName, b, funcName)
  end
end

local function _NormalizeBucketPath(bucket)
  if bucket == nil then
    return nil
  end

  bucket = tostring(bucket)
  if bucket == "" then
    return nil
  end

  local out = {}
  for part in bucket:gmatch("[^%.]+") do
    if part ~= "" and part ~= "Funcs" then
      out[#out + 1] = part
    end
  end

  if #out == 0 then
    return nil
  end

  return table.concat(out, ".")
end

---------------------------
-- Private local function helper (least invasive)
--
-- Goal:
--   Make "local function Foo()" trackable WITHOUT turning it into a global,
--   and WITHOUT rewriting it into "function T:Foo()".
--
-- Basic module setup:
--
--   local MemDebug = ns and ns.Pleebug
--   local P, TrackThis
--   if MemDebug and MemDebug.DropIn then
--     P, TrackThis = MemDebug:DropIn(MyModuleTable, { name = "PCM" })
--   end
--
-- Register a local function:
--
--   local function Foo(a, b)
--     ...
--   end
--   Foo = P:Def("Foo", Foo)
--
-- Mode behavior:
--   Light mode:
--     P:Def only registers the original function reference for Blizzard native CPU sampling.
--     It returns the same function object, so calls still go directly to Foo.
--     This gives CPU call counts/calls per second without Pleebug wrapper taint.
--
--   Full debug mode:
--     P:Def returns an instrumented wrapper for every registered function.
--     P:SecDef deliberately replaces the registered owner method with the same wrapper path.
--
-- IMPORTANT:
--   DropIn alone is not enough to see local functions, because Lua local function
--   references are invisible unless you pass them to P:Def or P:SecDef.
---------------------------

function MemDebug:NewPrivate(moduleName, opt)
  opt = opt or {}
  moduleName = tostring(moduleName or "Unknown")

  local t = {}
  t.____pleebugPrivate = true
  t.__pleebugModuleName = moduleName

  -- Optional default bucket prefix for locals you Def() (you can ignore this)
  if opt.bucket ~= nil then
    t.__pleebugBucket = tostring(opt.bucket)
  end

  -- Optional per-call bucket resolver (shared with Attach/DropIn semantics)
  if type(opt.bucketFunc) == "function" then
    t.__pleebugBucketFunc = opt.bucketFunc
  end


  function t:Def(name, fn, bucketOverride)
    if type(name) ~= "string" or name == "" or type(fn) ~= "function" then
      return fn
    end

    -- Optional: allow a per-function default bucket
    if bucketOverride ~= nil then
      self.__pleebugFnBuckets = self.__pleebugFnBuckets or {}
      self.__pleebugFnBuckets[name] = tostring(bucketOverride)
    end

    local module = self.__pleebugModuleName or "Unknown"
    local baseBucket = self.__pleebugBucket
    local fnBuckets = rawget(self, "__pleebugFnBuckets")
    local localBucket = (fnBuckets and fnBuckets[name]) or nil

    local bucket = _NormalizeBucketPath(localBucket or baseBucket)

    MemDebug._pdefBuckets = MemDebug._pdefBuckets or {}
    MemDebug._pdefBuckets[module] = MemDebug._pdefBuckets[module] or {}
    MemDebug._pdefBuckets[module][name] = bucket or ""

    local cpu = MemDebug.CPU
    local path
    if cpu and cpu.RegisterFunction then
      path = cpu:RegisterFunction(module, bucket, name, fn, { kind = "native" })
    end

    local mode = (MemDebug.GetLoadMode and MemDebug:GetLoadMode()) or MemDebug.__pleebugLoadMode or "light"
    if mode ~= "full" then
      mode = "light"
    end

    if mode == "full" then
      if cpu and path then
        cpu:SetRegistrationKind(path, "wrapped")
      end
      local wrapped = function(...)
        if not (MemDebug and MemDebug.IsEnabled and MemDebug:IsEnabled()) then
          return fn(...)
        end
        if MemDebug.IsModuleEnabled and not MemDebug:IsModuleEnabled(module) then
          return fn(...)
        end

        MemDebug:TrackFunc(module, bucket, name)

        if MemDebug.CPU and MemDebug.CPU.CallMeasured then
          return MemDebug.CPU:CallMeasured(module, bucket, name, fn, ...)
        end

        return fn(...)
      end

      rawset(self, name, wrapped)
      return wrapped
    end

    rawset(self, name, fn)
    return fn
  end

  -- Light mode keeps the original owner method. Full mode deliberately replaces it.
  function t:SecDef(name, owner, methodName, bucketOverride)
    if type(name) ~= "string" or name == "" then
      return
    end
    if type(owner) ~= "table" or type(methodName) ~= "string" or methodName == "" then
      return
    end

    local module = self.__pleebugModuleName or "Unknown"
    local baseBucket = self.__pleebugBucket
    local bucket = _NormalizeBucketPath(bucketOverride ~= nil and tostring(bucketOverride) or baseBucket)
    local fn = owner[methodName]
    if type(fn) ~= "function" then
      return
    end

    local cpu = MemDebug.CPU
    local path
    if cpu and cpu.RegisterFunction then
      path = cpu:RegisterFunction(module, bucket, name, fn, {
        kind = "secure-native",
        owner = owner,
        methodName = methodName,
      })
    end

    local mode = (MemDebug.GetLoadMode and MemDebug:GetLoadMode()) or MemDebug.__pleebugLoadMode or "light"
    if mode == "full" then
      if cpu and path then
        cpu:SetRegistrationKind(path, "wrapped")
      end

      local wrapped = function(...)
        if not (MemDebug and MemDebug.IsEnabled and MemDebug:IsEnabled()) then
          return fn(...)
        end
        if MemDebug.IsModuleEnabled and not MemDebug:IsModuleEnabled(module) then
          return fn(...)
        end

        MemDebug:TrackFunc(module, bucket, name)

        if MemDebug.CPU and MemDebug.CPU.CallMeasured then
          return MemDebug.CPU:CallMeasured(module, bucket, name, fn, ...)
        end

        return fn(...)
      end

      owner[methodName] = wrapped
      rawset(self, name, wrapped)
      return wrapped
    end

    rawset(self, name, fn)
    return fn
  end


  return t
end

---------------------------
-- DropIn: one source file, one Pleebug bucket.
--
-- The caller filename is the bucket identity. opt.name, opt.bucket, opt.buckets,
-- and opt.bucketFunc are not used for function grouping. Local functions still
-- need P:Def(name, fn) because Lua does not expose local references to DropIn.
---------------------------
function MemDebug:DropIn(primary, opt, ...)
  opt = opt or {}

  local stack = debugstack(2, 1, 0):gsub("\\", "/")
  local inferredAddon = stack:match("Interface/AddOns/([^/]+)/")
  local moduleName = stack:match("([^/]+)%.lua:%d+") or stack:match("([^/]+)%.lua")
  local moduleGroup = stack:match("Modules/([^/]+)/")

  if moduleGroup and moduleName then
    self._moduleGroups[moduleName] = moduleGroup
  end

  local fileOpt = {}
  for key, value in pairs(opt) do
    if key ~= "bucket" and key ~= "buckets" and key ~= "bucketFunc" then
      fileOpt[key] = value
    end
  end
  fileOpt.name = moduleName

  local mdb = _ensureDB()
  mdb.moduleAddon = mdb.moduleAddon or {}
  mdb.moduleAddonName = mdb.moduleAddonName or {}

  local addonName = fileOpt.addonName or fileOpt.addon or inferredAddon or mdb.moduleAddon[moduleName] or mdb.moduleAddonName[moduleName]
  mdb.moduleAddon[moduleName] = addonName
  mdb.moduleAddonName[moduleName] = addonName
  if self.CPU and self.CPU.SetOverviewAddonName then
    self.CPU:SetOverviewAddonName(addonName)
  end

  local P = self:NewPrivate(moduleName)

  local extra = { ... }
  if #extra > 0 then
    self:_AttachInternal(moduleName, primary, P, unpack(extra), fileOpt)
  else
    self:_AttachInternal(moduleName, primary, P, fileOpt)
  end

  local function TrackThis(name)
    self:TrackFunc(moduleName, nil, name)
  end

  return P, TrackThis
end


-- Universal module/file wrapper:
-- Drop this into ANY file once.
--
-- Minimal (true drop-in):
--   local MemDebug = ns and ns.Pleebug
--   if MemDebug then MemDebug:Attach(MyModuleTableOrFrame) end

--
-- Optional explicit name + extra tables:
--   MemDebug:Attach("MyModule", MyModule, Private, Internal)
--
-- Optional opts (last argument, or 2nd arg if using drop-in signature):
--   MemDebug:Attach(MyModule, { deep = true })
--   MemDebug:Attach("MyModule", MyModule, { deep = true, bucketFunc = fn })
--
-- opts:
--   name       : string override for module grouping
--   deep       : true to recurse subtables when wrapping functions
--   bucketFunc : function(self, funcKey, ...) -> bucket string (unit/viewer/etc)

-- Public API: Attach is a thin alias for internal registration.
-- Prefer MemDebug:DropIn(...) in new code.
function MemDebug:Attach(...)
  return self:_AttachInternal(...)
end

function MemDebug:_AttachInternal(moduleName, primary, ...)

  self._attached = self._attached or {}

  local opt = nil
  local extra = { ... }

  -- Drop-in signature:
  --   Attach(primary [, opt])
  if type(moduleName) ~= "string" then
    local droppedOpt = primary -- 2nd argument in drop-in form

    primary = moduleName
    moduleName = _getModuleName(primary)

    -- If they provided an opts table as the 2nd arg, capture it (common case).
    if type(droppedOpt) == "table" and (droppedOpt.deep ~= nil or droppedOpt.name ~= nil or droppedOpt.bucketFunc ~= nil or droppedOpt.bucket ~= nil) then
      opt = droppedOpt
    -- Otherwise allow opts as next vararg.
    elseif type(extra[1]) == "table" then
      opt = extra[1]
      extra[1] = nil
    end
  else

    moduleName = tostring(moduleName or "Unknown")

    -- Named signature:
    --   Attach("Name", primary, ... [, opt])
    local last = extra[#extra]
    if type(last) == "table" then
      opt = last
      extra[#extra] = nil
    end
  end

  moduleName = tostring((opt and opt.name) or moduleName or "Unknown")

  -- DropIn/Attach is the single owner of source-file discovery.
  self:_RegisterKnownModule(moduleName)

  local entry = self._attached[moduleName]


  if not entry or type(entry) ~= "table" or entry.list == nil then
    entry = { list = {}, opt = opt or {} }
    self._attached[moduleName] = entry
  else
    entry.opt = opt or entry.opt or {}
  end

  local function add(obj)
    if not obj then return end
    entry.list[#entry.list + 1] = obj
  end

  add(primary)
  for i = 1, #extra do
    add(extra[i])
  end

  -- If already running, install immediately.
  if self:IsEnabled() then
    self:_InstallUniversalOnAttached(moduleName)
  end

end



local function _defaultBucketFromCall(selfObj, funcKey, ...)
  -- 1) common: first arg is unit token
  local a1 = select(1, ...)
  if type(a1) == "string" then
    local u = a1
    if u == "player" or u == "pet" or u == "target" or u == "focus" or u == "mouseover" or u == "vehicle" then
      return u
    end
    if u:match("^party%d+$") or u:match("^raid%d+$") or u:match("^boss%d+$") or u:match("^arena%d+$") then
      return u
    end
    if u:match("^nameplate%d+$") then
      return u
    end

    -- 2) PCM-style: viewer keys
    if u:match("CooldownViewer") or u:match("^Essential") or u:match("^Utility") or u:match("^Buff") then
      return u
    end
  end

  -- 3) self.unit on frames/objects
  if type(selfObj) == "table" then
    if type(selfObj.unit) == "string" then
      return selfObj.unit
    end
    if type(selfObj.unitToken) == "string" then
      return selfObj.unitToken
    end
    if type(selfObj.viewerKey) == "string" then
      return selfObj.viewerKey
    end
    if type(selfObj._viewerKey) == "string" then
      return selfObj._viewerKey
    end
  end

  -- 4) Frame attribute "unit"
  if selfObj and type(selfObj.GetAttribute) == "function" then
    local unit = selfObj:GetAttribute("unit")
    if type(unit) == "string" and unit ~= "" then
      return unit
    end
  end
  return nil
end

local function _pleebug_IsRiskyObject(obj)
  if not obj then
    return false
  end

  local t = type(obj)
  if t ~= "table" and t ~= "userdata" then
    return false
  end

  if type(obj.IsForbidden) == "function" and obj:IsForbidden() then
    return true
  end
  if type(obj.IsProtected) == "function" and obj:IsProtected() then
    return true
  end

  -- Secure unit frames often carry secure attributes; do not touch.
  if type(obj.GetAttribute) == "function" then
    if obj:GetAttribute("unit") ~= nil or obj:GetAttribute("type") ~= nil then
      return true
    end
  end

  -- Direct unit markers
  if type(obj.unit) == "string" then
    local u = obj.unit
    if u:match("^party%d+$") or u:match("^raid%d+$") or u:match("^boss%d+$") or u:match("^arena%d+$") or u:match("^nameplate%d+$") then
      return true
    end
  end
  if type(obj.unitToken) == "string" then
    local u = obj.unitToken
    if u:match("^party%d+$") or u:match("^raid%d+$") or u:match("^boss%d+$") or u:match("^arena%d+$") or u:match("^nameplate%d+$") then
      return true
    end
  end

  -- Frame name heuristics (nameplates/compact/raid/party are taint-prone)
  local n = (type(obj.GetName) == "function") and obj:GetName() or nil
  if n then
    if n == "GameTooltip" or n:find("Tooltip", 1, true) then
      return true
    end
    if n:find("NamePlate", 1, true) or n:find("Compact", 1, true) or n:find("Party", 1, true) or n:find("Raid", 1, true) then
      return true
    end
  end

  return false
end

-- Internal: install event/callback wrappers + optional function wrapping on all attached objects.
function MemDebug:_InstallUniversalOnAttached(moduleName)


  local mdb = _ensureDB()
  if mdb and not _moduleAllowed(mdb, moduleName) then
    return
  end

  if not self._attached or not self._attached[moduleName] then
    return
  end

  local entry = self._attached[moduleName]
  local list = entry.list or entry
  local opt  = entry.opt or {}
  local function _deepInstall(t, visited)
    if type(t) ~= "table" then return end
    if _pleebug_IsRiskyObject(t) then return end
    visited = visited or {}
    if visited[t] then return end
    visited[t] = true


    -- Install on this object if it looks like a frame/object that registers stuff
    if self.InstallAceEventTracking and (type(t.RegisterEvent) == "function" or type(t.RegisterUnitEvent) == "function") then
      self:InstallAceEventTracking(t, moduleName)
    end
    if self.InstallCallbackTracking and (type(t.RegisterCallback) == "function" or type(t.AddCallback) == "function") then
      self:InstallCallbackTracking(t, moduleName)
    end
    if self.InstallFrameEventTracking and type(t.SetScript) == "function" then
      self:InstallFrameEventTracking(t, moduleName)
    end

    for _, v in pairs(t) do
      if type(v) == "table" then
        if not _pleebug_IsRiskyObject(v) then
          _deepInstall(v, visited)
        end
      end
    end

  end

  for i = 1, #list do
    local obj = list[i]
    if obj and not _pleebug_IsRiskyObject(obj) then
      -- 1) Events (AceEvent-style or any object exposing RegisterEvent/RegisterUnitEvent)
      if self.InstallAceEventTracking then
        self:InstallAceEventTracking(obj, moduleName)
      end

      -- 2) Callbacks (CallbackHandler/AceCallback-style if present)
      if self.InstallCallbackTracking then
        self:InstallCallbackTracking(obj, moduleName)
      end

      -- 3) Frame OnEvent (RegisterEvent without AceEvent mixin)
      if self.InstallFrameEventTracking then
        self:InstallFrameEventTracking(obj, moduleName)
      end

      -- Deep-scan nested tables for frames/objects that register events/scripts/callbacks
      if opt and opt.deep == true and type(obj) == "table" then
        _deepInstall(obj, nil)
      end

    end
  end
end


function MemDebug:Clear()
  _wipe(self._counts)
  _wipe(self._rollingCounts)
  _wipe(self._lastSnapshot)
  self._liveStartedAt = _now()
  self._lastSnapshotTime = self._liveStartedAt

  -- Clear CPU runtime buffers only when explicitly clearing (or on reload).
  if self.CPU and self.CPU.ResetRuntime then
    self.CPU:ResetRuntime()
  end
  if self.Window then
    self.Window._stoppedSnapshot = nil
  end
end



function MemDebug:GetLastSnapshot()
  return self._lastSnapshot or {}
end

local function _sortedPairsByCount(t)
  local tmp = {}
  for k, v in pairs(t) do
    if type(v) == "number" and v > 0 then
      tmp[#tmp + 1] = { k = k, v = v }
    end
  end
  table.sort(tmp, function(a, b)
    if a.v == b.v then
      return a.k < b.k
    end
    return a.v > b.v
  end)
  return tmp
end

function MemDebug:SnapshotAndReset()
  local interval = self:GetInterval()
  local snap = {}
  for k, v in pairs(self._counts) do
    snap[k] = v
  end
  snap.__interval = interval
  snap.__time = _now()
  self._lastSnapshotTime = snap.__time

  self._lastSnapshot = snap

  _wipe(self._counts)

  -- Optional tick hooks (CPU module etc.)
  local hooks = self._tickHooks
  if hooks then
    -- snapshot list so a hook can add/remove hooks safely without breaking iteration
    local list, n = {}, 0
    for _, fn in pairs(hooks) do
      if type(fn) == "function" then
        n = n + 1
        list[n] = fn
      end
    end

    for i = 1, n do
      list[i](self, snap.__time, interval, snap)
    end
  end


  if MemDebug and MemDebug.Window and MemDebug.Window.OnSnapshot then
    MemDebug.Window:OnSnapshot(snap)
  end



  local mdb = _ensureDB()
  if mdb and mdb.printToChat then
    local lines = {}
    lines[#lines + 1] = string.format("|cff00ffff[Pleebug]|r Interval: %.2fs", interval)

    local sorted = _sortedPairsByCount(snap)
    local maxLines = 20
    local n = 0
    for i = 1, #sorted do
      local entry = sorted[i]
      if entry.k and not entry.k:match("^__") then
        n = n + 1
        if n > maxLines then break end
        local rate = entry.v / interval
        lines[#lines + 1] = string.format("%s = %d (%.1f/s)", entry.k, entry.v, rate)
      end
    end

    for i = 1, #lines do
      print(lines[i])
    end
  end
end

function MemDebug:Start()
  if self._ticker then
    self._ticker:Cancel()
    self._ticker = nil
  end

  self._enabled = true
  self._liveStartedAt = _now()
  self._lastSnapshotTime = self._liveStartedAt

  if self.CPU and self.CPU.ApplyDebugModeDefaults and self.GetDebugMode then
    self.CPU:ApplyDebugModeDefaults(self:GetDebugMode())
  end

  if self:IsAutoPollFramesEnabled() then
    self:_StartAutoPollTicker()
  end

  -- Install tracking only for source files that explicitly called DropIn/Attach.
  if self._attached then
    for moduleName in pairs(self._attached) do
      self:_InstallUniversalOnAttached(moduleName)
    end
  end

  -- Reset runtime-only tracking buffers on every start (never SavedVariables).
  _wipe(self._counts)
  _wipe(self._rollingCounts)
  _wipe(self._lastSnapshot)

  -- CPU module keeps its own runtime buffers. Clear them only on Start (and Clear button),
  -- never on Stop and never persist to SavedVariables.
  if self.CPU and self.CPU.ResetRuntime then
    self.CPU:ResetRuntime()
  end
  if self.CPU and self.CPU.PrimeNativeBaselines then
    self.CPU:PrimeNativeBaselines()
  end
  if self.CPU and self.CPU.StartOverview then
    self.CPU:StartOverview()
  end

  -- Self-test: guarantees UI shows something immediately when running.
  self:TrackFunc("MemDebug", nil, "Start")


  local interval = self:GetInterval()
  self._ticker = C_Timer.NewTicker(interval, function()
    if not MemDebug:IsEnabled() then return end
    MemDebug:SnapshotAndReset()
  end)
end


function MemDebug:Stop()
  if self._ticker then
    self._ticker:Cancel()
    self._ticker = nil
  end

  -- Freeze the visible live stats before disabling. Otherwise Refresh() falls back to the
  -- last interval snapshot and looks like Stop cleared or truncated the counters.
  if self.Window and self.Window.FreezeForStop then
    self.Window:FreezeForStop()
  end

  self._enabled = false
  self:_StopAutoPollTicker()
  if self.CPU and self.CPU.StopOverview then
    self.CPU:StopOverview()
  end

  -- Keep runtime buffers for inspection after Stop(), but never persist to SavedVariables.
end


local function _wrapMethodForEvent(obj, methodName, moduleName)
  if not obj or not methodName then return end

  local perObj = MemDebug._wrapped[obj]
  if not perObj then
    perObj = {}
    MemDebug._wrapped[obj] = perObj
  end

  if perObj[methodName] then
    return
  end

  -- hooksecurefunc only works on named table methods (no anonymous function refs).
  if type(obj[methodName]) ~= "function" then return end

  perObj[methodName] = true

  -- Posthook only: never replace methods (avoids taint on secure frames/actions).
  hooksecurefunc(obj, methodName, function(self, event, ...)
    MemDebug:TrackEvent(moduleName, event, select(1, ...))
  end)


end


local function _installOnObject(obj, moduleName)
  if not obj then return end
  obj.__pleebugInstalled = true

  moduleName = tostring(moduleName or _getModuleName(obj) or "Unknown")

  -- Hook registrations (observe only). Then hook named methods with hooksecurefunc.
  -- We do NOT wrap/replace RegisterEvent/RegisterUnitEvent or the callback functions.
  if type(obj.RegisterEvent) == "function" and not obj.__pleebugHookedRegisterEvent then
    obj.__pleebugHookedRegisterEvent = true

    hooksecurefunc(obj, "RegisterEvent", function(self, event, method, ...)
      -- AceEvent convention: method == nil means methodName == event
      if method == nil then
        _wrapMethodForEvent(self, tostring(event), moduleName)
        return
      end

      if type(method) == "string" then
        _wrapMethodForEvent(self, method, moduleName)
        return
      end

      -- NOTE: method == function (anonymous callback) cannot be hooksecurefunc'd.
      -- We intentionally do nothing here to avoid mutation.
    end)
  end

  if type(obj.RegisterUnitEvent) == "function" and not obj.__pleebugHookedRegisterUnitEvent then
    obj.__pleebugHookedRegisterUnitEvent = true

    hooksecurefunc(obj, "RegisterUnitEvent", function(self, event, method, ...)
      if method == nil then
        _wrapMethodForEvent(self, tostring(event), moduleName)
        return
      end

      if type(method) == "string" then
        _wrapMethodForEvent(self, method, moduleName)
        return
      end

      -- method == function cannot be hooksecurefunc'd safely (no named key).
    end)
  end

  -- Retro-hook already registered AceEvent handlers (string methods only).
  if type(obj.events) == "table" then
    for _, method in pairs(obj.events) do
      if type(method) == "string" then
        _wrapMethodForEvent(obj, method, moduleName)
      end
      -- function entries cannot be hooksecurefunc'd.
    end
  end
end



-- Public helper so an explicitly attached source file can install event tracking.
function MemDebug:InstallAceEventTracking(obj, moduleName)
  _installOnObject(obj, moduleName)
end

-- Optional: callback tracking (AceCallback/CallbackHandler style)
-- We count callbacks as Events with an "CB:" prefix so the existing UI stays unchanged.
function MemDebug:InstallCallbackTracking(obj, moduleName)
  if not obj or obj.__pleebugCallbackInstalled then return end
  obj.__pleebugCallbackInstalled = true

  moduleName = tostring(moduleName or _getModuleName(obj) or "Unknown")

  local function hookCallbackRegister(methodKey)
    if type(obj[methodKey]) ~= "function" then return end
    local flag = "__pleebugHooked_" .. methodKey
    if obj[flag] then return end
    obj[flag] = true

    -- Observe registrations only (no mutation of callback functions).
    hooksecurefunc(obj, methodKey, function(self, callbackName, method, ...)
      -- We intentionally record this as an "event" so UI stays consistent.
      -- This does NOT guarantee we can observe callback execution without wrapping.
      MemDebug:TrackEvent(moduleName, "CBREG:" .. tostring(callbackName or "UNKNOWN_CB"))
    end)

    -- If callback uses a string method on this object, we can at least hook that named method.
    -- We cannot attach the callbackName at execution time reliably, but we can still count calls.
    hooksecurefunc(obj, methodKey, function(self, callbackName, method, ...)
      if type(method) == "string" then
        _wrapMethodForEvent(self, method, moduleName)
      end
    end)
  end

  -- Common names across Ace/CallbackHandler style consumers
  hookCallbackRegister("RegisterCallback")
  hookCallbackRegister("AddCallback")
end

function MemDebug:InstallFrameEventTracking(obj, moduleName)
  if not obj then
    return
  end

  -- HARD SAFETY:
  -- Never HookScript secure/protected/forbidden frames. These are common "secret value"
  -- execution paths (tooltips, raid frames/compact frames, nameplates, secure unit buttons).
  if type(obj.IsForbidden) == "function" and obj:IsForbidden() then
    return
  end
  if type(obj.IsProtected) == "function" and obj:IsProtected() then
    return
  end

  -- Secure unit frames often carry secure attributes; do not touch.
  if type(obj.GetAttribute) == "function" then
    if obj:GetAttribute("unit") ~= nil or obj:GetAttribute("type") ~= nil then
      return
    end
  end

  local n = (type(obj.GetName) == "function") and obj:GetName() or nil
  if n then
    -- Tooltips
    if n == "GameTooltip" or n:find("Tooltip", 1, true) then
      return
    end
    -- Raid/compact/nameplates (taint-prone, secret auras/units)
    if n:find("Compact", 1, true) or n:find("NamePlate", 1, true) then
      return
    end
  end

  if obj == _G.GameTooltip or obj == _G.ShoppingTooltip1 or obj == _G.ShoppingTooltip2 then
    return
  end

  -- Never touch unknown frames. Any indexing on a forbidden frame can throw
  -- "attempted to index a forbidden table". So we only hook frames explicitly
  -- allow-listed by our own instrumentation paths.
  self._frameEventInstalled = self._frameEventInstalled or setmetatable({}, { __mode = "k" })
  self._frameEventAllow     = self._frameEventAllow     or setmetatable({}, { __mode = "k" })

  if self._frameEventInstalled[obj] then
    return
  end

  -- If caller is explicitly attaching this frame (InstallUniversalOnAttached),
  -- it is safe to allow-list it here.
  self._frameEventAllow[obj] = true

  -- Hard gate: only hook allow-listed frames (prevents forbidden table indexing).
  if self._frameEventAllow[obj] ~= true then
    return
  end

  -- Only some UI objects support HookScript at all.
  if type(obj.HookScript) ~= "function" then
    return
  end

  -- Only true event-capable frames should be considered here.
  -- Textures/regions can have HookScript but cannot hook "OnEvent".
  if type(obj.RegisterEvent) ~= "function" and type(obj.RegisterUnitEvent) ~= "function" then
    return
  end

  -- Optional: if HasScript exists, require OnEvent support
  if type(obj.HasScript) == "function" then
    local has = obj:HasScript("OnEvent")
    if not has then
      return
    end
  end

  local mName = tostring(moduleName or _getModuleName(obj) or "Unknown")

  -- Mark installed BEFORE HookScript to prevent re-entry / double hooks.
  self._frameEventInstalled[obj] = true

  obj:HookScript("OnEvent", function(frame, event, ...)
    MemDebug:TrackEvent(mName, event, select(1, ...))
  end)
end



local function _BuildKnownFuncSetForModule(self, moduleName)
  local entry = self._attached and self._attached[moduleName]
  if not entry or type(entry) ~= "table" or type(entry.list) ~= "table" then
    return nil
  end

  local set = {}

  for _, obj in ipairs(entry.list) do
    if type(obj) == "table" then
      for _, v in pairs(obj) do
        if type(v) == "function" then
          set[v] = true
        end
      end
    elseif type(obj) == "function" then
      set[obj] = true
    end
  end

  return set
end

function MemDebug:PollFrames(moduleName)
  if type(EnumerateFrames) ~= "function" then
    return 0
  end

  local mdb = _ensureDB()
  local total = 0

  self._polledFrames = self._polledFrames or {}
  local function _seenFor(mName)
    self._polledFrames[mName] = self._polledFrames[mName] or setmetatable({}, { __mode = "k" })
    return self._polledFrames[mName]
  end

  local function _pollOne(mName)
    if mdb and not _moduleAllowed(mdb, mName) then
      return 0
    end

    local known = _BuildKnownFuncSetForModule(self, mName)
    if not known then
      return 0
    end

    local seen = _seenFor(mName)
    local count = 0

    local f = EnumerateFrames()
    while f do
      if not seen[f] then
        seen[f] = true

        if not (f.IsForbidden and f:IsForbidden()) then
          if type(f.GetScript) == "function" then
            local onEvent = f:GetScript("OnEvent")
            if type(onEvent) == "function" and known[onEvent] then
              -- Only hook frames we explicitly allow-listed through Attach/InstallUniversal.
              if self._frameEventAllow and self._frameEventAllow[f] == true then
                self:InstallFrameEventTracking(f, mName)
                count = count + 1
              end
            end

          end
        end

      end
      f = EnumerateFrames(f)
    end

    return count
  end

  if type(moduleName) == "string" and moduleName ~= "" then
    total = total + _pollOne(moduleName)
  else
    if self._attached then
      for mName in pairs(self._attached) do
        total = total + _pollOne(mName)
      end
    end
  end

  return total
end

function MemDebug:SetAutoPollFrames(enabled, interval)
  local mdb = _ensureDB()
  if not mdb then return end

  mdb.autoPollFrames = enabled and true or false
  mdb.autoPollFramesInterval = tonumber(interval) or 1

  if self:IsEnabled() and mdb.autoPollFrames then
    self:_StartAutoPollTicker()
  else
    self:_StopAutoPollTicker()
  end
end

function MemDebug:IsAutoPollFramesEnabled()
  local mdb = _ensureDB()
  return (mdb and mdb.autoPollFrames) == true
end

function MemDebug:_StartAutoPollTicker()
  self:_StopAutoPollTicker()

  local mdb = _ensureDB()
  if not mdb then return end

  local interval = tonumber(mdb.autoPollFramesInterval) or 1
  if interval < 0.2 then interval = 0.2 end

  if C_Timer and C_Timer.NewTicker then
    self._autoPollTicker = C_Timer.NewTicker(interval, function()
      MemDebug:PollFrames(nil)
    end)
  end
end

function MemDebug:_StopAutoPollTicker()
  if self._autoPollTicker then
    self._autoPollTicker:Cancel()
    self._autoPollTicker = nil
  end
end


-- IMPORTANT:
-- Do NOT install at file load. MemDebug is dev-only and must stay idle until Start().
-- Installation happens inside MemDebug:Start().

local function _ToggleMemDebugWindow()
  if MemDebug and MemDebug.Window and MemDebug.Window.Toggle then
    MemDebug.Window:Toggle()
    return
  end
  print("Pleebug window is not loaded yet.")
end


-- Addon-free slash command
if not SLASH_PLEEBBUG1 then
  SLASH_PLEEBBUG1 = "/pleebug"
  SLASH_PLEEBBUG2 = "/pbug"
  SlashCmdList.PLEEBBUG = function()
    _ToggleMemDebugWindow()
  end
end

-- One-shot reopen after the mode/CVar reload buttons.
-- Delayed until PLAYER_LOGIN so LibPleebug-1_Window.lua has registered MemDebug.Window.
if not MemDebug.__pleebugOpenAfterReloadFrame then
  local _openFrame = CreateFrame("Frame")
  MemDebug.__pleebugOpenAfterReloadFrame = _openFrame
  _openFrame:RegisterEvent("PLAYER_LOGIN")
  _openFrame:SetScript("OnEvent", function()
    if C_Timer and C_Timer.After then
      C_Timer.After(0.25, function()
        if MemDebug and MemDebug.OpenAfterReloadIfRequested then
          MemDebug:OpenAfterReloadIfRequested()
        end
      end)
    elseif MemDebug and MemDebug.OpenAfterReloadIfRequested then
      MemDebug:OpenAfterReloadIfRequested()
    end
  end)
end
