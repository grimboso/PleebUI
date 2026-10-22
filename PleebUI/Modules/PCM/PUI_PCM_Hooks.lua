-- File: PUI_PCM_Hooks.lua
-- Purpose:
--   - Shared helper hooks for the CooldownManager (PCM) family.
--   - Centralizes hooksecurefunc usage so PCM modules can stay lean.

local ADDON_NAME, ns = ...

local Hooks = {}
ns.PCMHooks = Hooks

local P = select(1, ns.Pleebug:DropIn(Hooks))

local hooksecurefunc = hooksecurefunc

local FrameData = setmetatable({}, { __mode = "k" })

local EmptyFD = {}
local function GetFrameData(frame)
  if not frame then
    return EmptyFD
  end

  local data = FrameData[frame]
  if not data then
    data = {}
    FrameData[frame] = data
  end

  return data
end

Hooks.GetFrameData = GetFrameData

local _PCM_HooksEnabled

local _pcmHooksEnabledCache = nil
local _pcmHooksEnabledDirty = true
local _pcmHooksEditModeActive = false
local _pcmHooksRuntimeActive = true

local _methodHooks = setmetatable({}, { __mode = "k" })

function Hooks.HookMethod(obj, method, key, fn)
  if not (obj and method and key and fn) then
    return false
  end
  if type(fn) ~= "function" then
    return false
  end


  local mt = _methodHooks[obj]
  if not mt then
    mt = {}
    _methodHooks[obj] = mt
  end

  local mm = mt[method]
  if not mm then
    mm = {}
    mt[method] = mm
  end

  if mm[key] then
    return false
  end
  mm[key] = true

  if obj[method] then
    hooksecurefunc(obj, method, fn)
    return true
  end

  return false
end

local function _InBlizzardEditMode()
  local active = ns.Addon:IsBlizzardEditModeActive()
  _pcmHooksEditModeActive = active
  _pcmHooksRuntimeActive = (_pcmHooksEnabledCache == true and not active)
  return active
end

Hooks.InBlizzardEditMode = _InBlizzardEditMode



local function _PCM_RefreshHooksRuntimeState()
  if _pcmHooksEnabledDirty or _pcmHooksEnabledCache == nil then
    _pcmHooksEnabledCache = ns.PCM_IsModuleEnabledFast() == true
    _pcmHooksEnabledDirty = false
  end

  _pcmHooksRuntimeActive = (_pcmHooksEnabledCache == true and _pcmHooksEditModeActive ~= true)
  return _pcmHooksRuntimeActive
end

function Hooks.RefreshRuntimeState()
  _pcmHooksEnabledDirty = true
  return _PCM_RefreshHooksRuntimeState()
end

function Hooks.SetRuntimeEnabled(enabled)
  _pcmHooksEnabledCache = enabled == true
  _pcmHooksEnabledDirty = false
  return _PCM_RefreshHooksRuntimeState()
end

function Hooks.SetBlizzardEditModeActive(active)
  _pcmHooksEditModeActive = active == true
  return _PCM_RefreshHooksRuntimeState()
end

_PCM_HooksEnabled = function()
  if _pcmHooksEnabledDirty or _pcmHooksEnabledCache == nil then
    _PCM_RefreshHooksRuntimeState()
  end
  return _pcmHooksEnabledCache == true
end

function Hooks.HookEditMode(module)
  if not module then
    return
  end

  local initialActive = ns.Addon:IsBlizzardEditModeActive()

  if module.__puiPCM_EditHooked then
    Hooks.SetBlizzardEditModeActive(initialActive)
    module.__puiPCM_LastBlizzardEditModeState = initialActive
    return
  end
  module.__puiPCM_EditHooked = true

  local function FireBlizzardEditModeState(enable)
    if not _PCM_HooksEnabled() then
      return
    end

    enable = (enable == true)
    Hooks.SetBlizzardEditModeActive(enable)

    if module.__puiPCM_LastBlizzardEditModeState == enable then
      return
    end
    module.__puiPCM_LastBlizzardEditModeState = enable

    module:_OnBlizzardEditModeChanged(enable)
  end

  local function HookBlizzardEditModeExit()
    local manager = _G.EditModeManagerFrame
    if not manager then
      return
    end

    Hooks.HookMethod(manager, "ExitEditMode", "PCM_EditModeExit", function()
      FireBlizzardEditModeState(false)
    end)
  end

  EventRegistry:RegisterCallback("EditMode.Enter", function()
    HookBlizzardEditModeExit()
    FireBlizzardEditModeState(true)
  end, module)

  HookBlizzardEditModeExit()
  Hooks.SetBlizzardEditModeActive(initialActive)
  module.__puiPCM_LastBlizzardEditModeState = initialActive
end

GetFrameData = P:Def("GetFrameData", GetFrameData)
Hooks.HookMethod = P:Def("Hooks:HookMethod", Hooks.HookMethod)
_InBlizzardEditMode = P:Def("_InBlizzardEditMode", _InBlizzardEditMode)
_PCM_RefreshHooksRuntimeState = P:Def("_PCM_RefreshHooksRuntimeState", _PCM_RefreshHooksRuntimeState)
Hooks.RefreshRuntimeState = P:Def("Hooks:RefreshRuntimeState", Hooks.RefreshRuntimeState)
Hooks.SetRuntimeEnabled = P:Def("Hooks:SetRuntimeEnabled", Hooks.SetRuntimeEnabled)
Hooks.SetBlizzardEditModeActive = P:Def("Hooks:SetBlizzardEditModeActive", Hooks.SetBlizzardEditModeActive)
_PCM_HooksEnabled = P:Def("_PCM_HooksEnabled", _PCM_HooksEnabled)
Hooks.HookEditMode = P:Def("Hooks:HookEditMode", Hooks.HookEditMode)

Hooks.GetFrameData = GetFrameData
Hooks.InBlizzardEditMode = _InBlizzardEditMode
