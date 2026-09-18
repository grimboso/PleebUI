-- File: PUI_PCM_Hooks.lua
-- Purpose:
--   - Shared helper hooks for the CooldownManager (PCM) family.
--   - Centralizes hooksecurefunc usage so PCM modules can stay lean.

local ADDON_NAME, ns = ...

local Hooks = {}
ns.PCMHooks = Hooks

local P = select(1, ns.Pleebug:DropIn(Hooks))

local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local IsSecret = issecretvalue

local rawFrame = CreateFrame("Frame")
local RawClearAllPoints = rawFrame.ClearAllPoints
local RawSetPoint = rawFrame.SetPoint
local RawSetSize = rawFrame.SetSize
local RawSetScale = rawFrame.SetScale
local RawSetAlpha = rawFrame.SetAlpha

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

local function PeekFrameData(frame)
  return frame and FrameData[frame] or nil
end

Hooks.GetFrameData = GetFrameData
Hooks.PeekFrameData = PeekFrameData

function Hooks.GetItemViewerKey(itemFrame, fallback)
  local data = itemFrame and FrameData[itemFrame]
  local viewerKey = data and data.viewerKey
  if viewerKey ~= nil then
    return viewerKey
  end
  return fallback
end

function Hooks.SetItemViewerKey(itemFrame, viewerKey)
  local data = GetFrameData(itemFrame)
  data.viewerKey = viewerKey
  data.isViewerIconButton = viewerKey == "EssentialCooldownViewer" or viewerKey == "UtilityCooldownViewer"
end

local _PCM_HooksEnabled
local _PCM_HooksShouldRun

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

local _scriptHooks = setmetatable({}, { __mode = "k" })

function Hooks.HookScript(obj, script, key, fn)
  if not (obj and script and key and fn) then
    return false
  end
  if type(fn) ~= "function" then
    return false
  end
  if type(obj.HookScript) ~= "function" then
    return false
  end

  local mt = _scriptHooks[obj]
  if not mt then
    mt = {}
    _scriptHooks[obj] = mt
  end

  local mm = mt[script]
  if not mm then
    mm = {}
    mt[script] = mm
  end

  if mm[key] then
    return false
  end
  mm[key] = true

  obj:HookScript(script, fn)
  return true
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

_PCM_HooksShouldRun = function()
  if _pcmHooksEnabledDirty or _pcmHooksEnabledCache == nil then
    _PCM_RefreshHooksRuntimeState()
  end

  return _pcmHooksRuntimeActive == true
end

local _bbIconState = Hooks._bbIconState
if not _bbIconState then
  _bbIconState = setmetatable({}, { __mode = "k" })
  Hooks._bbIconState = _bbIconState
end

function Hooks.SetBBIconHidden(icon, hidden, wasShown)
  if not icon then
    return
  end

  local st = _bbIconState[icon]
  if not st then
    st = {}
    _bbIconState[icon] = st
  end

  st.hidden = hidden and true or nil
  if wasShown ~= nil then
    st.wasShown = wasShown and true or false
  end

  local fd = GetFrameData(icon)
  if fd ~= EmptyFD then
    fd.__puiBBHidden = st.hidden
    if wasShown ~= nil then
      fd.__puiBBWasShown = st.wasShown
    end
  end
end

function Hooks.GetBBIconHidden(icon)
  if not icon then
    return nil, nil
  end

  local st = _bbIconState[icon]
  if not st then
    return nil, nil
  end
  return st.hidden, st.wasShown
end

local abs = math.abs

local function OnIconSetPoint(self)
  local fd = FrameData[self]
  if not fd or fd.locking or fd.hidden or not fd.anchor then
    return
  end

  if not _PCM_HooksShouldRun() then
    return
  end

  fd.locking = true
  RawClearAllPoints(self)
  RawSetPoint(self, "CENTER", fd.anchor, "CENTER", fd.posX or 0, fd.posY or 0)
  fd.locking = false
end

local function OnIconSetSize(self)
  local fd = FrameData[self]
  if not fd or fd.locking or fd.hidden then
    return
  end

  local tw = fd.sizeW
  local th = fd.sizeH
  if not tw or not th then
    return
  end

  local cw, ch = self:GetSize()
  if IsSecret(cw) or IsSecret(ch) then
    return
  end
  if cw and ch and abs(cw - tw) <= 1 and abs(ch - th) <= 1 then
    return
  end

  if not _PCM_HooksShouldRun() then
    return
  end

  fd.locking = true
  RawSetSize(self, tw, th)
  fd.locking = false
end

local function OnIconSetScale(self, scale)
  local fd = FrameData[self]
  if not fd or fd.locking or fd.hidden then
    return
  end

  if IsSecret(scale) or abs((scale or 1) - 1) <= 0.01 then
    return
  end

  if not _PCM_HooksShouldRun() then
    return
  end

  fd.locking = true
  RawSetScale(self, 1)
  fd.locking = false
end

local function OnIconSetAlpha(self, alpha)
  local fd = FrameData[self]
  if not fd or fd.locking then
    return
  end

  if not _PCM_HooksShouldRun() then
    return
  end

  if IsSecret(alpha) then
    return
  end

  if (fd.parked or fd.hidden) and alpha and alpha > 0 then
    fd.locking = true
    RawSetAlpha(self, 0)
    fd.locking = false
  end
end



function Hooks.HookIconFrame(icon, key)
  if not icon then
    return
  end


  local fd = Hooks.GetFrameData(icon)
  if fd.posHooked then
    return
  end

  fd.posHooked = true
  fd.viewerKey = key

  hooksecurefunc(icon, "SetPoint", OnIconSetPoint)
  hooksecurefunc(icon, "SetScale", OnIconSetScale)
  hooksecurefunc(icon, "SetSize", OnIconSetSize)
  hooksecurefunc(icon, "SetWidth", OnIconSetSize)
  hooksecurefunc(icon, "SetHeight", OnIconSetSize)
  hooksecurefunc(icon, "SetAlpha", OnIconSetAlpha)
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

-- Proc glow hooks (ActionButtonSpellAlertManager)

local glowHooked = false

function Hooks.HookGlowManager(isEnabled, startProcGlow, stopProcGlow)
  if glowHooked then
    return
  end

  local mgr = ActionButtonSpellAlertManager
  if not mgr then
    return
  end

  glowHooked = true

  local pendingIcons = {}
  local queuedIcons = setmetatable({}, { __mode = "k" })
  local desiredState = setmetatable({}, { __mode = "k" })
  local pendingCount = 0
  local flushFrame = CreateFrame("Frame")
  flushFrame:Hide()

  local function FlushPendingGlows(frame)
    frame:Hide()

    local enabled = isEnabled() == true

    for i = 1, pendingCount do
      local btn = pendingIcons[i]
      pendingIcons[i] = nil

      if btn then
        local wanted = desiredState[btn]
        desiredState[btn] = nil
        queuedIcons[btn] = nil

        local st = FrameData[btn]
        if st then
          st.procGlowPending = nil
        end

        if st and st.isViewerIconButton == true then
          if wanted == true then
            if enabled and btn:IsShown() then
              startProcGlow(btn)
            end
          elseif wanted == false and (st.procGlowActive or st.procGlowWanted) then
            stopProcGlow(btn)
          end
        end
      end
    end

    pendingCount = 0
  end

  flushFrame:SetScript("OnUpdate", FlushPendingGlows)

  local function QueueGlowState(btn, wanted)
    local st = btn and FrameData[btn]
    if not st or st.isViewerIconButton ~= true then
      return
    end

    if wanted == true then
      if isEnabled() ~= true then
        return
      end
      st.procGlowPending = true
    elseif not (st.procGlowActive or st.procGlowPending or st.procGlowWanted) then
      return
    else
      st.procGlowPending = nil
    end

    desiredState[btn] = wanted == true
    if queuedIcons[btn] ~= true then
      queuedIcons[btn] = true
      pendingCount = pendingCount + 1
      pendingIcons[pendingCount] = btn
    end

    flushFrame:Show()
  end

  if mgr.ShowAlert then
    hooksecurefunc(mgr, "ShowAlert", function(_, btn)
      QueueGlowState(btn, true)
    end)
  end

  if mgr.HideAlert then
    hooksecurefunc(mgr, "HideAlert", function(_, btn)
      QueueGlowState(btn, false)
    end)
  end
end

local viewerLayoutHooked = setmetatable({}, { __mode = "k" })
local viewerLayoutCallbacks = setmetatable({}, { __mode = "k" })

function Hooks.HookViewerLayout(viewer, cb)
  local callbacks = viewerLayoutCallbacks[viewer]
  if not callbacks then
    callbacks = {}
    viewerLayoutCallbacks[viewer] = callbacks
  end
  callbacks[#callbacks + 1] = cb

  if viewerLayoutHooked[viewer] then
    return
  end
  viewerLayoutHooked[viewer] = true

  hooksecurefunc(viewer, "RefreshLayout", function()
    if _InBlizzardEditMode() then
      return
    end

    local list = viewerLayoutCallbacks[viewer]
    for i = 1, #list do
      list[i](viewer, "RefreshLayout")
    end
  end)
end

GetFrameData = P:Def("GetFrameData", GetFrameData)
Hooks.PeekFrameData = P:Def("Hooks:PeekFrameData", Hooks.PeekFrameData)
Hooks.GetItemViewerKey = P:Def("Hooks:GetItemViewerKey", Hooks.GetItemViewerKey)
Hooks.SetItemViewerKey = P:Def("Hooks:SetItemViewerKey", Hooks.SetItemViewerKey)
Hooks.HookMethod = P:Def("Hooks:HookMethod", Hooks.HookMethod)
Hooks.HookScript = P:Def("Hooks:HookScript", Hooks.HookScript)
_InBlizzardEditMode = P:Def("_InBlizzardEditMode", _InBlizzardEditMode)
_PCM_RefreshHooksRuntimeState = P:Def("_PCM_RefreshHooksRuntimeState", _PCM_RefreshHooksRuntimeState)
Hooks.RefreshRuntimeState = P:Def("Hooks:RefreshRuntimeState", Hooks.RefreshRuntimeState)
Hooks.SetRuntimeEnabled = P:Def("Hooks:SetRuntimeEnabled", Hooks.SetRuntimeEnabled)
Hooks.SetBlizzardEditModeActive = P:Def("Hooks:SetBlizzardEditModeActive", Hooks.SetBlizzardEditModeActive)
_PCM_HooksEnabled = P:Def("_PCM_HooksEnabled", _PCM_HooksEnabled)
_PCM_HooksShouldRun = P:Def("_PCM_HooksShouldRun", _PCM_HooksShouldRun)
  Hooks.SetBBIconHidden = P:Def("Hooks:SetBBIconHidden", Hooks.SetBBIconHidden)
Hooks.GetBBIconHidden = P:Def("Hooks:GetBBIconHidden", Hooks.GetBBIconHidden)
OnIconSetPoint = P:Def("OnIconSetPoint", OnIconSetPoint)
OnIconSetSize = P:Def("OnIconSetSize", OnIconSetSize)
OnIconSetScale = P:Def("OnIconSetScale", OnIconSetScale)
OnIconSetAlpha = P:Def("OnIconSetAlpha", OnIconSetAlpha)
Hooks.HookIconFrame = P:Def("Hooks:HookIconFrame", Hooks.HookIconFrame)
Hooks.HookEditMode = P:Def("Hooks:HookEditMode", Hooks.HookEditMode)
Hooks.HookGlowManager = P:Def("Hooks:HookGlowManager", Hooks.HookGlowManager)
Hooks.HookViewerLayout = P:Def("Hooks:HookViewerLayout", Hooks.HookViewerLayout)

Hooks.GetFrameData = GetFrameData
Hooks.InBlizzardEditMode = _InBlizzardEditMode
