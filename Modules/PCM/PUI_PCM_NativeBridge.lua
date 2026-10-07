local _, ns = ...

local NativeBridge = {}
ns.PCMNativeBridge = NativeBridge

local issecretvalue = issecretvalue

local GROUPS = {
  {
    keys = { "EssentialCooldownViewer", "UtilityCooldownViewer" },
    runtime = function() return ns.PCMAbilityRuntime end,
  },
  {
    keys = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" },
    runtime = function() return ns.PCMAuraRuntime end,
  },
}

local originalAlpha = setmetatable({}, { __mode = "k" })

local function GetDevNativeViewerAlpha()
  local alpha = tonumber(ns.Addon.db.char.pcmDevNativeViewerAlpha) or 0
  return math.min(1, math.max(0, alpha))
end

local function HideViewer(viewer)
  if originalAlpha[viewer] == nil then
    local alpha = viewer:GetAlpha()
    originalAlpha[viewer] = issecretvalue(alpha) and 1 or alpha
  end
  viewer:SetAlpha(GetDevNativeViewerAlpha())
end

local function RestoreViewer(viewer)
  local alpha = originalAlpha[viewer]
  if alpha == nil then
    return
  end
  viewer:SetAlpha(alpha)
  originalAlpha[viewer] = nil
end

local function SetGroupNativeVisible(group, visible)
  for index = 1, #group.keys do
    local viewer = _G[group.keys[index]]
    if not viewer then
      return false
    end
  end

  for index = 1, #group.keys do
    local viewer = _G[group.keys[index]]
    if visible then
      RestoreViewer(viewer)
    else
      HideViewer(viewer)
    end
  end
  return true
end

function NativeBridge:Refresh()
  if not ns.PCM_IsModuleEnabledFast() then
    self:Disable()
    if ns.AuraWidget.RequiresNativeCDM() then
      for index = 1, #GROUPS do
        SetGroupNativeVisible(GROUPS[index], false)
      end
    end
    return false
  end

  if not ns.PCM_DBExports.IsRendererMigrationComplete() then
    self:Disable()
    return false
  end

  local nativeEnabled = C_CVar.GetCVar("cooldownViewerEnabled") == "1"
  local allReady = true
  for index = 1, #GROUPS do
    local group = GROUPS[index]
    local runtime = group.runtime()
    local ready = runtime:IsReady()
    runtime:SetPresentationActive(ready)
    if ready then
      if not SetGroupNativeVisible(group, not nativeEnabled) then
        runtime:SetPresentationActive(false)
        allReady = false
      end
    else
      SetGroupNativeVisible(group, true)
      allReady = false
    end
  end
  return allReady
end

function NativeBridge:Disable()
  ns.PCMAbilityRuntime:SetPresentationActive(false)
  ns.PCMAuraRuntime:SetPresentationActive(false)
  for viewer, alpha in pairs(originalAlpha) do
    viewer:SetAlpha(alpha)
  end
  wipe(originalAlpha)
end

function NativeBridge:GetDevNativeViewerAlpha()
  return GetDevNativeViewerAlpha()
end

function NativeBridge:SetDevNativeViewerAlpha(alpha)
  local value = math.min(1, math.max(0, tonumber(alpha) or 0))
  ns.Addon.db.char.pcmDevNativeViewerAlpha = value > 0 and value or nil
  self:Refresh()
end

local P = select(1, ns.Pleebug:DropIn(NativeBridge, { name = "PCM", bucket = "NativeBridge" }))
NativeBridge.Refresh = P:Def("NativeBridge:Refresh", NativeBridge.Refresh)
NativeBridge.Disable = P:Def("NativeBridge:Disable", NativeBridge.Disable)
NativeBridge.GetDevNativeViewerAlpha = P:Def("NativeBridge:GetDevNativeViewerAlpha", NativeBridge.GetDevNativeViewerAlpha)
NativeBridge.SetDevNativeViewerAlpha = P:Def("NativeBridge:SetDevNativeViewerAlpha", NativeBridge.SetDevNativeViewerAlpha)
