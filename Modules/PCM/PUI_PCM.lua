-- File: PUI_PCM.lua

local ADDON_NAME, ns = ...

local Addon = ns.Addon
local FrameUtil = ns.FrameUtil
local FrameScale = ns.FrameScale
local Pixel = ns.Pixel
local Round = Pixel.Round
local LibEditModeOverride = LibStub("LibEditModeOverride-1.0")
local PCMHooks = ns.PCMHooks
local PCMRuntime = ns.PCMRuntime
local PCM_DB = ns.PCM_DBExports
local IconSettings = ns.PCMIconSettings
local COOLDOWN_MANAGER_CVAR = "cooldownViewerEnabled"


local function RoundPixel(v)
  if v == nil then
    return v
  end
  return Round(v)
end

local t_wipe = table.wipe

local _PCM_IsSecret = issecretvalue


local PCMCoreState = {
  ViewerCountCache = {},
  DurationCountCache = {},
  SwipeFlagCache = {},
}

local PCMEnabled
local PCMStartupDataReady = false

local _EnsureViewerDurationCount
local _PCM_GetDurationCountEnabledCached
local _PCM_RunHardViewerTransition
local _PCM_QueueTransitionFlush
local _PCM_RunInitialViewerPass

local PCMTransitionFlushFrame = CreateFrame("Frame")
PCMTransitionFlushFrame:Hide()

local PCMTransitionState = {
  Queued = false,
  FlushQueued = false,
  Owner = nil,
  InvalidateClassSpellCache = false,
}

local function _PCM_IsTransitionPending()
  return PCMTransitionState.Queued == true
end

ns.PCM_IsTransitionPending = _PCM_IsTransitionPending

local PCMAnchorState = {
  moverRegistered = setmetatable({}, { __mode = "k" }),
}

local PCM_CUSTOM_BAR_COOLDOWN_CATEGORIES = {
  Enum.CooldownViewerCategory.Essential,
  Enum.CooldownViewerCategory.Utility,
  Enum.CooldownViewerCategory.EquipSlotEssential,
  Enum.CooldownViewerCategory.SpecAgnosticEssential,
}

local PCM_CUSTOM_BAR_AURA_CATEGORIES = {
  Enum.CooldownViewerCategory.TrackedBuff,
  Enum.CooldownViewerCategory.TrackedBar,
  Enum.CooldownViewerCategory.EquipSlotTracked,
  Enum.CooldownViewerCategory.SpecAgnosticTracked,
}

local Cooldowns = Addon:NewModule("CooldownManager", "NumyAceEvent-3.0")
ns.Modules.CooldownManager          = Cooldowns
ns.Registry.Modules.CooldownManager = Cooldowns



local function _PCM_IsModuleEnabledFast()
  if PCMEnabled ~= nil then
    return PCMEnabled == true
  end

  PCMEnabled = PCM_DB.IsPCMEnabled() == true
  return PCMEnabled
end

ns.PCM_IsModuleEnabledFast = _PCM_IsModuleEnabledFast

local function _PCM_HasSoundAlerts()
  local configuration = ns.PCMCatalog:GetNativeConfiguration()
  local getAlertType = _G.CooldownViewerAlert_GetType
  if not configuration or type(getAlertType) ~= "function" then
    return nil
  end
  local cooldownIDs = configuration.orderedCooldownIDs
  for index = 1, #cooldownIDs do
    local alerts = configuration.alertsByID[cooldownIDs[index]]
    if alerts ~= nil then
      if issecretvalue(alerts) or type(alerts) ~= "table" then
        return nil
      end
      for alertIndex = 1, #alerts do
        if getAlertType(alerts[alertIndex]) == Enum.CooldownViewerAlertType.Sound then
          return true
        end
      end
    end
  end
  return false
end

local PCMNativePolicy = {
  ReconcilePending = false,
}

local function _PCM_GetNativeCDMRequirement()
  return _PCM_HasSoundAlerts()
end

local function _PCM_CanChangeNativeCDMState()
  return not PCMRuntime:IsDataRestricted()
end

local function _PCM_ReconcileNativeCDM()
  if not _PCM_IsModuleEnabledFast() then
    PCMNativePolicy.ReconcilePending = false
    ns.PCMNativeBridge:Disable()
    return false
  end

  local canChangeState = _PCM_CanChangeNativeCDMState()
  if not canChangeState then
    PCMNativePolicy.ReconcilePending = true
    ns.PCMNativeBridge:Refresh()
    return nil
  end

  local requiresNative = _PCM_GetNativeCDMRequirement()
  if requiresNative == nil then
    PCMNativePolicy.ReconcilePending = true
    ns.PCMNativeBridge:Refresh()
    return nil
  end

  PCMNativePolicy.ReconcilePending = false

  local nativeEnabled = C_CVar.GetCVar(COOLDOWN_MANAGER_CVAR) == "1"
  if nativeEnabled ~= requiresNative then
    C_CVar.SetCVar(
      COOLDOWN_MANAGER_CVAR,
      requiresNative and "1" or "0"
    )
    return requiresNative
  end

  ns.PCMNativeBridge:Refresh()
  return requiresNative
end

ns.PCM_ReconcileNativeCDM = _PCM_ReconcileNativeCDM


local P, TrackThis = ns.Pleebug:DropIn(Cooldowns, { name = "PCM", bucket = "Core" })



local PCM_VIEWERS = {
  { key = "EssentialCooldownViewer", title = "Essential Cooldowns", ref = function()
    return ns.PCMAbilityRuntime:GetViewerFrame("EssentialCooldownViewer")
  end },
  { key = "UtilityCooldownViewer", title = "Utility Cooldowns", ref = function()
    return ns.PCMAbilityRuntime:GetViewerFrame("UtilityCooldownViewer")
  end },
  { key = "BuffIconCooldownViewer", title = "Tracked Icons", ref = function()
    return ns.PCMAuraRuntime:GetViewerFrame("BuffIconCooldownViewer")
  end },
  { key = "BuffBarCooldownViewer", title = "Tracked Buff Bars", ref = function()
    return ns.PCMAuraRuntime:GetViewerFrame("BuffBarCooldownViewer")
  end },
}

Cooldowns.__puiDefaultViewerAnchors = {}
Cooldowns.__puiDefaultViewerAnchors.UtilityCooldownViewer = {
  point    = "TOP",
  rel      = "EssentialCooldownViewer",
  relPoint = "BOTTOM",
  x        = 0,
  y        = -10,
}

local function _PCM_IsCoreViewerKey(key)
  return key == "EssentialCooldownViewer"
    or key == "UtilityCooldownViewer"
    or key == "BuffIconCooldownViewer"
    or key == "BuffBarCooldownViewer"
end

local function _PCM_IsAbilityViewerKey(key)
  return key == "EssentialCooldownViewer" or key == "UtilityCooldownViewer"
end

local function _RebuildViewerRegistry(self)

  self._viewerRegistry = {}

  for _, v in ipairs(PCM_VIEWERS) do
    table.insert(self._viewerRegistry, v)
  end

  -- Build quick lookup maps so hot paths do not rescan the registry.
  self.__puiViewerKindMap = {}
  self.__puiViewerInfoByKey = {}

  for i = 1, #self._viewerRegistry do
    local info = self._viewerRegistry[i]
    if info and info.key then
      self.__puiViewerKindMap[info.key] = true
      self.__puiViewerInfoByKey[info.key] = info

    end
  end
end

function Cooldowns:IterateViewers()
  if not self._viewerRegistry then
    _RebuildViewerRegistry(self)
  end

  return ipairs(self._viewerRegistry)
end

function Cooldowns:GetViewerInfo(key)
  if not self._viewerRegistry then
    _RebuildViewerRegistry(self)
  end

  local map = self.__puiViewerInfoByKey
  if map then
    return map[key]
  end
end

function Cooldowns:GetViewerFrame(key)
  if not key then
    return nil
  end

  if not self._viewerRegistry then
    _RebuildViewerRegistry(self)
  end

  local viewerFrame
  if key == "EssentialCooldownViewer" or key == "UtilityCooldownViewer" then
    viewerFrame = ns.PCMAbilityRuntime:GetViewerFrame(key)
  elseif key == "BuffIconCooldownViewer" or key == "BuffBarCooldownViewer" then
    viewerFrame = ns.PCMAuraRuntime:GetViewerFrame(key)
  end

  return viewerFrame
end

function Cooldowns:_ResolveOwnedViewerStyle(viewerKey)
  local root = PCM_DB.GetPCMRoot()
  local style = PCM_DB.GetStyleDB(root)
  local border = self.GetBorderConfig(viewerKey) or {}
  return {
    widthMode = self._GetWidthModeForViewer(viewerKey, style),
    fixedWidth = self._GetFixedWidthForViewer(viewerKey, style),
    iconSize = self._GetIconSizeForViewer(viewerKey, style),
    spacing = self._GetIconSpacingForViewer(viewerKey, style),
    firstRowLimit = style.viewerColumns[viewerKey] or 0,
    rowGrowth = style.viewerRowGrowth[viewerKey] == "UP" and "UP" or "DOWN",
    borderThickness = border.enabled ~= false and border.thickness or 0,
    borderColor = border.color,
    backgroundColor = style.iconBgColor or { 0, 0, 0, 0.35 },
    cooldownFont = self._ResolveFontOpts("cooldown", viewerKey),
    chargeFont = self._ResolveFontOpts("charge", viewerKey),
    keybindFont = self._ResolveFontOpts("keybind", viewerKey),
    swipe = PCM_DB.GetViewerSwipeDB(viewerKey, root),
    counts = PCMCoreState.ViewerCountCache[viewerKey],
    durationCount = self:GetDurationCountEnabled(viewerKey),
    tooltips = self:GetViewerTooltipsEnabled(viewerKey),
    procGlow = root and root.glow or nil,
  }
end

local function _PCM_InitializeOwnedViewers(owner)
  local runtime = ns.PCMAbilityRuntime
  for _, viewerKey in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer" }) do
    local anchor = owner:GetViewerAnchorFrame(viewerKey)
    runtime:InitializeViewer(viewerKey, anchor)
    runtime:ApplyViewerStyle(viewerKey, owner:_ResolveOwnedViewerStyle(viewerKey))
  end
end

local function _PCM_RefreshOwnedViewer(owner, viewerKey, mask)
  if viewerKey == "EssentialCooldownViewer" or viewerKey == "UtilityCooldownViewer" then
    local runtime = ns.PCMAbilityRuntime
    runtime:ApplyViewerStyle(viewerKey, owner:_ResolveOwnedViewerStyle(viewerKey))
    runtime:RefreshLayout(viewerKey)
  elseif viewerKey == "BuffIconCooldownViewer" then
    ns.Modules.PCM_Buffs:RefreshSettings()
  elseif viewerKey == "BuffBarCooldownViewer" then
    ns.Modules.PCM_BuffBars:RefreshSettings()
  end
end

local _PCM_TOOLTIP_VIEWER_KEY_SET = {
  EssentialCooldownViewer = true,
  UtilityCooldownViewer = true,
  BuffIconCooldownViewer = true,
  BuffBarCooldownViewer = true,
}

local _PCM_HIDE_WHEN_INACTIVE_VIEWER_KEY_SET = {
  BuffIconCooldownViewer = true,
  BuffBarCooldownViewer = true,
}

local function _PCM_EnsureEditModeLayout()
  if not LibEditModeOverride:IsReady() then
    return false
  end

  if not LibEditModeOverride:AreLayoutsLoaded() then
    if InCombatLockdown() then
      return false
    end
    LibEditModeOverride:LoadLayouts()
  end

  return true
end

function Cooldowns:GetViewerTooltipsEnabled(viewerKey)
  local enabled = PCM_DB.GetOwnedViewerTooltipEnabled(viewerKey)
  if enabled == nil then
    return true
  end
  return enabled == true
end

function Cooldowns:SetViewerTooltipsEnabled(viewerKey, enabled)
  local changed = PCM_DB.SetOwnedViewerTooltipEnabled(viewerKey, enabled == true)
  if changed and _PCM_IsModuleEnabledFast() then
    if viewerKey == "EssentialCooldownViewer" or viewerKey == "UtilityCooldownViewer" then
      _PCM_RefreshOwnedViewer(self, viewerKey)
    elseif viewerKey == "BuffIconCooldownViewer" then
      ns.Modules.PCM_Buffs:RefreshSettings()
    elseif viewerKey == "BuffBarCooldownViewer" then
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end
  end
  return changed
end

local function _PCM_MigrateOwnedViewerTooltips()
  if PCM_DB.IsRendererMigrationComplete() then
    return true
  end
  if not _PCM_EnsureEditModeLayout() then
    return false
  end

  local settings = {
    tooltips = {},
    hideWhenInactive = {},
  }
  for viewerKey in pairs(_PCM_TOOLTIP_VIEWER_KEY_SET) do
    local viewer = _G[viewerKey]
    if not viewer or not LibEditModeOverride:HasEditModeSettings(viewer) then
      return false
    end
    settings.tooltips[viewerKey] = LibEditModeOverride:GetFrameSetting(
      viewer,
      Enum.EditModeCooldownViewerSetting.ShowTooltips
    )
  end
  for viewerKey in pairs(_PCM_HIDE_WHEN_INACTIVE_VIEWER_KEY_SET) do
    settings.hideWhenInactive[viewerKey] = LibEditModeOverride:GetFrameSetting(
      _G[viewerKey],
      Enum.EditModeCooldownViewerSetting.HideWhenInactive
    )
  end
  return PCM_DB.CommitRendererSettingsMigration(settings)
end

function Cooldowns:GetViewerHideWhenInactive(viewerKey)
  local enabled = PCM_DB.GetOwnedViewerHideWhenInactive(viewerKey)
  if enabled == nil then
    return true
  end
  return enabled == true
end

function Cooldowns:SetViewerHideWhenInactive(viewerKey, enabled)
  local changed = PCM_DB.SetOwnedViewerHideWhenInactive(viewerKey, enabled == true)
  if changed and _PCM_IsModuleEnabledFast() then
    if viewerKey == "BuffIconCooldownViewer" then
      ns.Modules.PCM_Buffs:RefreshSettings()
    elseif viewerKey == "BuffBarCooldownViewer" then
      ns.Modules.PCM_BuffBars:RefreshSettings()
    end
  end
  return changed
end


local _GetOrCreateViewerAnchorFrame
local _ForceAnchor


local function _DeactivatePCMOwnedFrames()
  for _, info in Cooldowns:IterateViewers() do
    local key = info and info.key
    local viewer = key and Cooldowns:GetViewerFrame(key) or nil
    local fd = PCMHooks.GetFrameData(viewer)

    local anchor = (fd and fd.anchorFrame) or (key and _G["PUI_PCM_Anchor_" .. tostring(key)]) or nil
    local inCombat = InCombatLockdown()

    if anchor then
      if not inCombat and anchor.Hide then
        anchor:Hide()
      end
      if not inCombat and anchor.EnableMouse then
        anchor:EnableMouse(false)
      end
    end
  end
end

function Cooldowns:GetCustomBarSpellDropdown(kind)
  local values = {
    ["none"] = "-- Select --",
  }
  local sorting = { "none" }

  local configuration = ns.PCMCatalog:GetNativeConfiguration()
  if not configuration then
    return values, sorting
  end

  local isAura = kind == "aura"
  local entriesBySpellID = {}
  local entries = {}

  local function AddCategory(category)
    local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category, true)
    if _PCM_IsSecret(cooldownIDs) or type(cooldownIDs) ~= "table" then
      return
    end

    for index = 1, #cooldownIDs do
      local cooldownID = cooldownIDs[index]
      if not _PCM_IsSecret(cooldownID)
        and type(cooldownID) == "number"
        and cooldownID > 0
      then
        local nativeInfo = configuration.infoByID[cooldownID]
        if nativeInfo then
          local info = nativeInfo.sourceInfo
          local isKnown = info.isKnown
          local currentCategory = nativeInfo.resolvedCategory

          if not _PCM_IsSecret(isKnown)
            and not _PCM_IsSecret(currentCategory)
          then
            local spellID
            if isAura then
              spellID = info.spellID
            else
              spellID = info.overrideSpellID
              if _PCM_IsSecret(spellID)
                or type(spellID) ~= "number"
                or spellID <= 0
              then
                spellID = info.spellID
              end
            end

            if not _PCM_IsSecret(spellID)
              and type(spellID) == "number"
              and spellID > 0
            then
              local shown = isKnown == true
                and currentCategory ~= Enum.CooldownViewerCategory.HiddenActive
                and currentCategory ~= Enum.CooldownViewerCategory.HiddenPassive

              local existing = entriesBySpellID[spellID]
              if existing then
                if shown then
                  existing.shown = true
                end
              else
                local name = C_Spell.GetSpellName(spellID)
                if _PCM_IsSecret(name) or type(name) ~= "string" or name == "" then
                  name = "Spell " .. tostring(spellID)
                end

                local icon = C_Spell.GetSpellTexture(spellID)
                if _PCM_IsSecret(icon)
                  or (type(icon) ~= "number" and type(icon) ~= "string")
                then
                  icon = nil
                end

                local entry = {
                  spellID = spellID,
                  name = name,
                  icon = icon,
                  shown = shown == true,
                }
                entriesBySpellID[spellID] = entry
                entries[#entries + 1] = entry
              end
            end
          end
        end
      end
    end
  end

  local categories = isAura and PCM_CUSTOM_BAR_AURA_CATEGORIES or PCM_CUSTOM_BAR_COOLDOWN_CATEGORIES
  for index = 1, #categories do
    AddCategory(categories[index])
  end

  table.sort(entries, function(left, right)
    if left.shown ~= right.shown then
      return left.shown == true
    end

    local leftName = left.name:lower()
    local rightName = right.name:lower()
    if leftName == rightName then
      return left.spellID < right.spellID
    end

    return leftName < rightName
  end)

  for index = 1, #entries do
    local entry = entries[index]
    local key = tostring(entry.spellID)
    local label = entry.name .. " (" .. key .. ")"

    if entry.icon then
      label = string.format("|T%s:16:16:0:0|t %s", tostring(entry.icon), label)
    end

    if not entry.shown then
      label = "|cff808080" .. label .. "|r"
    end

    values[key] = label
    sorting[#sorting + 1] = key
  end

  return values, sorting
end



local function _PCM_LoadViewerCountFlags(viewerKey)
  if not viewerKey then
    return nil
  end

  local cfg = ns.PCM_DBExports.GetViewerCountDB(viewerKey)
  local cached = {
    cooldown = not cfg or cfg.cooldown == true,
    buff = not cfg or cfg.buff == true,
    charge = not cfg or cfg.charge == true,
    keybind = not cfg or cfg.keybind == true,
  }
  PCMCoreState.ViewerCountCache[viewerKey] = cached
  return cached
end

local function _PCM_PrimeViewerCountCache()
  t_wipe(PCMCoreState.ViewerCountCache)

  for _, info in Cooldowns:IterateViewers() do
    local viewerKey = info and info.key
    if viewerKey then
      _PCM_LoadViewerCountFlags(viewerKey)
    end
  end
end

local function _PCM_SetViewerCountFlagCached(viewerKey, field, enabled)
  if not viewerKey or not field then
    return
  end

  local cached = PCMCoreState.ViewerCountCache[viewerKey] or _PCM_LoadViewerCountFlags(viewerKey)
  if cached then
    cached[field] = enabled == true
  end
end

local function _PCM_InvalidateViewerRuleSettingCache(viewerKey)
  if viewerKey then
    PCMCoreState.ViewerCountCache[viewerKey] = nil
    PCMCoreState.DurationCountCache[viewerKey] = nil
    PCMCoreState.SwipeFlagCache[viewerKey] = nil
    return
  end

  t_wipe(PCMCoreState.ViewerCountCache)
  t_wipe(PCMCoreState.DurationCountCache)
  t_wipe(PCMCoreState.SwipeFlagCache)
end

local function _PCM_GetViewerCountFlagsCached(viewerKey)
  if not viewerKey then
    return nil
  end

  return PCMCoreState.ViewerCountCache[viewerKey]
end

-- Cooldown count toggle (main Cooldown text, non-aura or overridden aura)
function Cooldowns:GetCooldownCountEnabled(viewerKey)
  if not viewerKey then
    return true
  end

  local flags = _PCM_GetViewerCountFlagsCached(viewerKey)
  return not flags or flags.cooldown == true
end

function Cooldowns:SetCooldownCountEnabled(viewerKey, enabled)
  local cfg = ns.PCM_DBExports.GetViewerCountDB(viewerKey)
  if not cfg then
    return
  end

  cfg.cooldown = not not enabled
  _PCM_SetViewerCountFlagCached(viewerKey, "cooldown", cfg.cooldown)
  self:ApplyCooldownCountRulesNow(viewerKey)
end

-- Buff stack/application count toggle
function Cooldowns:GetBuffCountEnabled(viewerKey)
  local flags = _PCM_GetViewerCountFlagsCached(viewerKey)
  return not flags or flags.buff == true
end

function Cooldowns:SetBuffCountEnabled(viewerKey, enabled)
  local cfg = ns.PCM_DBExports.GetViewerCountDB(viewerKey)
  if not cfg then
    return
  end

  cfg.buff = not not enabled
  _PCM_SetViewerCountFlagCached(viewerKey, "buff", cfg.buff)
  self:ApplyCooldownCountRulesNow(viewerKey)
end

-- Charge count toggle (cooldown viewers only).
function Cooldowns:GetChargeCountEnabled(viewerKey)
  local flags = _PCM_GetViewerCountFlagsCached(viewerKey)
  return not flags or flags.charge == true
end

function Cooldowns:SetChargeCountEnabled(viewerKey, enabled)
  local cfg = ns.PCM_DBExports.GetViewerCountDB(viewerKey)
  if not cfg then
    return
  end

  cfg.charge = not not enabled
  _PCM_SetViewerCountFlagCached(viewerKey, "charge", cfg.charge)
  self:ApplyCooldownCountRulesNow(viewerKey)
end


function Cooldowns:ApplyCooldownCountRulesNow(viewerKey)
  if not self or not _PCM_IsModuleEnabledFast() then
    return
  end

  if viewerKey then
    _PCM_RefreshOwnedViewer(self, viewerKey)
    return
  end

  for _, info in self:IterateViewers() do
    _PCM_RefreshOwnedViewer(self, info.key)
  end
end

_PCM_GetDurationCountEnabledCached = function(viewerKey)
  if not viewerKey then
    return true
  end

  local cached = PCMCoreState.DurationCountCache[viewerKey]
  if cached ~= nil then
    return cached
  end

  local cfg = _EnsureViewerDurationCount(viewerKey)
  local enabled = not cfg or cfg.enabled ~= false
  PCMCoreState.DurationCountCache[viewerKey] = enabled
  return enabled
end

_EnsureViewerDurationCount = function(viewerKey)
  return ns.PCM_DBExports.EnsureViewerSubDB("durationCount", viewerKey, {
    enabled = true,
  })
end




function Cooldowns:SetDurationCountEnabled(viewerKey, enabled)
  local cfg = _EnsureViewerDurationCount(viewerKey)
  if not cfg then
    return
  end

  cfg.enabled = not not enabled
  PCMCoreState.DurationCountCache[viewerKey] = cfg.enabled
  PCMCoreState.SwipeFlagCache[viewerKey] = nil

  self:_RequestViewerRefresh("icons", viewerKey)
end

function Cooldowns:GetDurationCountEnabled(viewerKey)
  return _PCM_GetDurationCountEnabledCached(viewerKey)
end


local function _PCM_InvalidateClassSpellCache()
  IconSettings:InvalidateCatalog()
end

local function _PCM_BeginTransition(owner, invalidateClassSpellCache)
  if not owner then
    return
  end

  PCMTransitionState.Queued = true
  PCMTransitionState.FlushQueued = false
  PCMTransitionState.Token = (PCMTransitionState.Token or 0) + 1
  PCMTransitionState.Owner = owner

  if invalidateClassSpellCache == true then
    PCMTransitionState.InvalidateClassSpellCache = true
  end

  owner:ClearSavedSpellKnownCache()

  PCMTransitionFlushFrame:Hide()
  if not PCMRuntime:IsDataRestricted() then
    _PCM_QueueTransitionFlush()
  end
end

_PCM_RunHardViewerTransition = function(owner, invalidateClassSpellCache)
  if not owner or not _PCM_IsModuleEnabledFast() then
    return
  end

  if PCMRuntime:IsDataRestricted() then
    _PCM_BeginTransition(owner, invalidateClassSpellCache)
    return
  end

  if invalidateClassSpellCache then
    _PCM_InvalidateClassSpellCache()
  end

  ns.PCMAbilityCatalog:Invalidate("hard-transition")
  ns.PCMAbilityCatalog:Refresh()
  ns.PCMAbilityRuntime:Flush()
  ns.PCMAuraRuntime:Flush()
  owner:_RequestViewerRefresh("layout")
end

function Cooldowns:RefreshAbilityCatalog()
  _PCM_RunHardViewerTransition(self, false)
end

local function _PCM_OnNativeSettingsHidden()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  _PCM_BeginTransition(Cooldowns, false)
end

local function _PCM_ReconcileRuntimeViewers(owner)
  if not owner then
    return
  end

  ns.PCMAbilityCatalog:Invalidate("transition-finalize")
  ns.PCMAbilityCatalog:Refresh()
  owner:_RequestViewerRefresh("all")
  ns.PCMAbilityRuntime:Flush()
  ns.PCMAuraRuntime:Flush()

  _ForceAnchor(owner:GetViewerFrame("EssentialCooldownViewer"), "EssentialCooldownViewer")
  _ForceAnchor(owner:GetViewerFrame("UtilityCooldownViewer"), "UtilityCooldownViewer")

  FrameUtil.RelayoutSmartSnapCluster("PCM_EssentialCooldownViewer")
  FrameUtil.RelayoutSmartSnapCluster("PCM_UtilityCooldownViewer")
end


local function _PCM_FinalizeTransition(token)
  if token ~= (PCMTransitionState.Token or 0) or not _PCM_IsTransitionPending() then
    return
  end

  local owner = PCMTransitionState.Owner
  if not owner or not _PCM_IsModuleEnabledFast() then
    PCMTransitionState.Queued = false
    PCMTransitionState.Owner = nil
    PCMTransitionState.InvalidateClassSpellCache = false
    return
  end

  local invalidateClassSpellCache = PCMTransitionState.InvalidateClassSpellCache == true

  if invalidateClassSpellCache then
    _PCM_InvalidateClassSpellCache()
  end

  _PCM_ReconcileRuntimeViewers(owner)
  _PCM_ReconcileNativeCDM()

  PCMTransitionState.Queued = false
  PCMTransitionState.Owner = nil
  PCMTransitionState.InvalidateClassSpellCache = false

  ns.Modules.PCM_BB.RefreshAfterTalentSwap()
  owner:SpellBars_ReconcileAvailability()
  owner:CooldownStackBars_RefreshAfterTalentSwap()
  ns.PCM_RefreshCustomBarsOptionsAfterSpecializationChange()
  owner.RefreshKeybinds(nil)
end

local function _PCM_FlushTransition(token)
  if token ~= (PCMTransitionState.Token or 0) then
    return
  end

  PCMTransitionState.FlushQueued = false

  if not _PCM_IsTransitionPending() then
    return
  end

  local owner = PCMTransitionState.Owner
  if not owner or not _PCM_IsModuleEnabledFast() then
    PCMTransitionState.Queued = false
    PCMTransitionState.Owner = nil
    PCMTransitionState.InvalidateClassSpellCache = false
    return
  end

  if PCMRuntime:IsDataRestricted() then
    return
  end

  local settings = _G.CooldownViewerSettings
  local provider = settings and settings:GetDataProvider() or nil
  if not provider then
    return
  end

  if type(provider.IsLayoutUpdateQueued) == "function"
    and provider:IsLayoutUpdateQueued()
  then
    return
  end

  _PCM_FinalizeTransition(token)
end

_PCM_QueueTransitionFlush = function()
  if not _PCM_IsTransitionPending() or PCMTransitionState.FlushQueued then
    return
  end

  PCMTransitionState.FlushQueued = true
  PCMTransitionFlushFrame:Show()
end

PCMTransitionFlushFrame:SetScript("OnUpdate", function(frame)
  frame:Hide()
  _PCM_FlushTransition(PCMTransitionState.Token or 0)
end)


_GetOrCreateViewerAnchorFrame = function(viewer, key)
  if not key then
    return nil
  end

  local vfd = viewer and PCMHooks.GetFrameData(viewer) or nil
  if vfd and vfd.anchorFrame then
    return vfd.anchorFrame
  end

  local name = "PUI_PCM_Anchor_" .. tostring(key)
  local af = _G[name]
  if not af then
    af = CreateFrame("Frame", name, UIParent)
    af:SetSize(1, 1)
    af:SetFrameStrata("LOW")
    af:SetFrameLevel(1)
  end

  if vfd then
    vfd.anchorFrame = af
  end

  local afd = PCMHooks.GetFrameData(af)
  afd.viewerKey = key

  return af
end

function Cooldowns:GetViewerAnchorFrame(viewerKey)
  if not _PCM_IsAbilityViewerKey(viewerKey) then
    return nil
  end

  if not _PCM_IsModuleEnabledFast() then
    return nil
  end

  local viewer = self:GetViewerFrame(viewerKey)
  return _GetOrCreateViewerAnchorFrame(viewer, viewerKey)
end

_ForceAnchor = function(frame, key)
  if not _PCM_IsAbilityViewerKey(key) then return end
  if frame and frame.IsForbidden and frame:IsForbidden() then return end

  -- Never mutate anchors while Blizzard Edit Mode is active.
  -- Do not fight the user while the Edit Mode UI is open.
  if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then
    return
  end

  local db = Cooldowns._GetViewerDB()
  if not db then return end

  local pos = db[key]
  if not pos or not pos.point then return end

  local anchor = _GetOrCreateViewerAnchorFrame(frame, key)
  if not anchor then
    return
  end

  local relativeKey = pos.rel
  local rel
  if _PCM_IsCoreViewerKey(relativeKey) then
    rel = Cooldowns:GetViewerAnchorFrame(relativeKey)
  else
    rel = _G[relativeKey or "UIParent"] or UIParent
  end
  if rel then
    local rfd = PCMHooks.GetFrameData(rel)
    if rfd.anchorFrame then
      rel = rfd.anchorFrame
    end
  end

  anchor:ClearAllPoints()
  anchor:SetPoint(
    pos.point,
    rel,
    pos.relPoint or pos.point,
    pos.x or 0,
    pos.y or 0
  )
end

function Cooldowns:_OnDataRestrictionsCleared()
  if InCombatLockdown() then
    return
  end

  if self.__puiPCMStartupPending then
    _PCM_RunInitialViewerPass(self)
  end

  if IconSettings:PrimeRuntimeCache() then
    for _, info in self:IterateViewers() do
      _PCM_RefreshOwnedViewer(self, info.key)
    end
  end

  if _PCM_IsTransitionPending() then
    _PCM_QueueTransitionFlush()
  end

  if self.__puiPCMCustomTrackerStartupPending then
    self:_ReconcileCustomTrackerStartupAvailability()
  end

  if PCMNativePolicy.ReconcilePending then
    _PCM_ReconcileNativeCDM()
  end

  if self.__puiPCM_BlizzardEditModeRetakePending
    and not Addon:IsBlizzardEditModeActive()
  then
    self:_OnBlizzardEditModeChanged(false)
  end
end

local function _EnsureDefaultViewerAnchor(key)
  if not key then
    return
  end

  local db = Cooldowns._GetViewerDB()
  if not db then
    return
  end

  if db[key] and db[key].point then
    return
  end

  local point, rel, relPoint, x, y

  local extraAnchors = Cooldowns.__puiDefaultViewerAnchors
  local ex = extraAnchors and extraAnchors[key] or nil
  if type(ex) == "table" then
    db[key] = {
      point    = ex.point,
      rel      = ex.rel,
      relPoint = ex.relPoint,
      x        = Round(ex.x or 0),
      y        = Round(ex.y or 0),
    }
    return
  end

  if key == "EssentialCooldownViewer" then
    point    = "CENTER"
    rel      = "UIParent"
    relPoint = "CENTER"
    x, y     = 0, -300
  else
    return
  end




  db[key] = {
    point    = point,
    rel      = rel,
    relPoint = relPoint,
    x        = Round(x or 0),
    y        = Round(y or 0),
  }
end

local function _RegisterViewerMover(info)
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  if info.key ~= "EssentialCooldownViewer" and info.key ~= "UtilityCooldownViewer" then
    return
  end

  local viewer = Cooldowns:GetViewerFrame(info.key)
  if viewer and viewer.IsForbidden and viewer:IsForbidden() then return end

  local anchor = _GetOrCreateViewerAnchorFrame(viewer, info.key)
  if not anchor then
    return
  end

  local inCombat = InCombatLockdown()

  if not inCombat and anchor.Show then
    anchor:Show()
  end
  if not inCombat and anchor.EnableMouse then
    anchor:EnableMouse(false)
  end

  _EnsureDefaultViewerAnchor(info.key)

  _ForceAnchor(viewer, info.key)

  if PCMAnchorState.moverRegistered[anchor] then
    return
  end
  PCMAnchorState.moverRegistered[anchor] = true

  local isSmartCombatViewer = info.key == "EssentialCooldownViewer"
    or info.key == "UtilityCooldownViewer"
  local function GetBorderPad()
    local border = Cooldowns.GetBorderConfig(info.key)
    local thickness = border and border.enabled ~= false and tonumber(border.thickness) or 0
    return RoundPixel(math.max(0, thickness)) * 2
  end
  local BuildQuickSettings
  BuildQuickSettings = function(moverFrame)
    local style = ns.PCM_DBExports.GetStyleDB()
    local fonts = Cooldowns._GetFontDB()
    fonts.viewers = fonts.viewers or {}
    fonts.viewers[info.key] = fonts.viewers[info.key] or {}
    fonts.viewers[info.key].cooldown = fonts.viewers[info.key].cooldown or {}

    local widthMode = Cooldowns._GetWidthModeForViewer(info.key)
    local controls = {
      {
        type = "select",
        label = "Width mode",
        values = {
          icon = "Icon size",
          fixed = "Fixed width",
        },
        sorting = { "icon", "fixed" },
        get = function()
          return Cooldowns._GetWidthModeForViewer(info.key)
        end,
        set = function(value)
          style.viewerWidthMode[info.key] = value == "fixed" and "fixed" or "icon"
          Cooldowns:_FlushViewerRefreshImmediate("layout", info.key)
          FrameUtil.RefreshSmartSnapState("PCM_" .. info.key)

          C_Timer.After(0, function()
            if Addon:IsEditMode() then
              ns.EditModeQuickSettings:Refresh(
                "PCM_" .. info.key,
                moverFrame,
                BuildQuickSettings
              )
            end
          end)
        end,
      },
    }

    if widthMode ~= "fixed" then
      controls[#controls + 1] = {
        type = "slider",
        label = "Icon size",
        min = 8,
        max = 96,
        step = 1,
        commitOnRelease = true,
        get = function()
          return Cooldowns._GetIconSizeForViewer(info.key)
        end,
        set = function(value)
          style.viewerSizes[info.key] = Round(value)
          Cooldowns:_FlushViewerRefreshImmediate("layout", info.key)
          FrameUtil:RefreshGhostMover("PCM_" .. info.key)
          FrameUtil.RefreshSmartSnapState("PCM_" .. info.key)
        end,
      }
    end

    controls[#controls + 1] = {
      type = "slider",
      label = "Width",
      min = 1,
      max = 1000,
      step = 1,
      commitOnRelease = true,
      get = function()
        if Cooldowns._GetWidthModeForViewer(info.key) == "fixed" then
          return Round(Cooldowns._GetFixedWidthForViewer(info.key) + GetBorderPad())
        end

        local width = anchor:GetWidth()
        if width and width > 1 then
          return Round(width)
        end
        return Round(Cooldowns._GetFixedWidthForViewer(info.key) + GetBorderPad())
      end,
      set = function(value)
        style.viewerWidthMode[info.key] = "fixed"
        style.viewerFixedWidth[info.key] = math.max(
          1,
          Round(value - GetBorderPad())
        )
        Cooldowns:_FlushViewerRefreshImmediate("layout", info.key)
        FrameUtil:RefreshGhostMover("PCM_" .. info.key)
        FrameUtil.RefreshSmartSnapState("PCM_" .. info.key)

        C_Timer.After(0, function()
          if Addon:IsEditMode() then
            ns.EditModeQuickSettings:Refresh(
              "PCM_" .. info.key,
              moverFrame,
              BuildQuickSettings
            )
          end
        end)
      end,
    }

    controls[#controls + 1] = {
      type = "slider",
      label = "Icon spacing",
      min = -20,
      max = 40,
      step = 1,
      get = function()
        return style.viewerSpacing[info.key] or style.iconSpacing or 2
      end,
      set = function(value)
        style.viewerSpacing[info.key] = Round(value)
        Cooldowns:_FlushViewerRefreshImmediate("layout", info.key)
        FrameUtil:RefreshGhostMover("PCM_" .. info.key)
        FrameUtil.RefreshSmartSnapState("PCM_" .. info.key)
      end,
    }
    controls[#controls + 1] = {
      type = "slider",
      label = "Border size",
      min = 0,
      max = 8,
      step = 1,
      get = function()
        local border = Cooldowns.GetBorderConfig(info.key)
        return border and border.thickness or 0
      end,
      set = function(value)
        Cooldowns.SetViewerBorderThickness(info.key, value)
        Cooldowns:_FlushViewerRefreshImmediate("icons", info.key)
        FrameUtil.RefreshSmartSnapState("PCM_" .. info.key)
      end,
    }
    controls[#controls + 1] = {
      type = "slider",
      label = "Cooldown font size",
      min = 6,
      max = 36,
      step = 1,
      get = function()
        return fonts.viewers[info.key].cooldown.size
          or Cooldowns._ResolveFontOpts("cooldown", info.key).size
          or 12
      end,
      set = function(value)
        fonts.viewers[info.key].cooldown.size = Round(value)
        Cooldowns:_FlushViewerRefreshImmediate("fonts", info.key)
      end,
    }
    controls[#controls + 1] = {
      type = "toggle",
      label = "Show tooltips",
      get = function()
        return Cooldowns:GetViewerTooltipsEnabled(info.key)
      end,
      set = function(value)
        Cooldowns:SetViewerTooltipsEnabled(info.key, value)
      end,
    }

    if _PCM_HIDE_WHEN_INACTIVE_VIEWER_KEY_SET[info.key] then
      controls[#controls + 1] = {
        type = "toggle",
        label = "Hide when inactive",
        get = function()
          return Cooldowns:GetViewerHideWhenInactive(info.key)
        end,
        set = function(value)
          Cooldowns:SetViewerHideWhenInactive(info.key, value)
        end,
      }
    end

    return {
      ownerKey = "PCM_" .. info.key,
      title = info.title or "Cooldown Manager",
      description = "Live Cooldown Manager settings.",
      controls = controls,
    }
  end

  local function SavePosition()
    if InCombatLockdown() then
      return
    end

    Cooldowns._SavePosition(anchor, info.key)
  end

  FrameUtil:RegisterMover("PCM_" .. info.key, anchor, {
    label = info.title or info.key,

    useOverlayDrag = true,
    optionsString = (info.key == "EssentialCooldownViewer" and "CooldownManager,essential")
      or (info.key == "UtilityCooldownViewer" and "CooldownManager,utility")
      or "CooldownManager",
    quickSettings = BuildQuickSettings,
    smartSnap = isSmartCombatViewer and {
      family = "combatBars",
      isRuntimeActive = function()
        return _PCM_IsModuleEnabledFast() and ns.PCMAbilityRuntime:IsReady()
      end,
      syncAxis = "WIDTH",
      syncWidthMin = 1,
      syncWidthMax = 1000,
      getSyncWidth = function()
        if Cooldowns._GetWidthModeForViewer(info.key) == "fixed" then
          return Round(Cooldowns._GetFixedWidthForViewer(info.key) + GetBorderPad())
        end
        return anchor:GetWidth()
      end,
      applySyncWidth = function(width)
        local style = ns.PCM_DBExports.GetStyleDB()
        style.viewerWidthMode[info.key] = "fixed"
        style.viewerFixedWidth[info.key] = math.max(
          1,
          Round(width - GetBorderPad())
        )
        Cooldowns:_FlushViewerRefreshImmediate("layout", info.key)
        FrameUtil:RefreshGhostMover("PCM_" .. info.key)
      end,
    } or nil,

    savePosition = SavePosition,
    onDragStop = function()
      _ForceAnchor(Cooldowns:GetViewerFrame(info.key), info.key)
    end,
  })


end

local function _InitAllViewerMovers()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  for _, info in Cooldowns:IterateViewers() do
    if info.key == "EssentialCooldownViewer" or info.key == "UtilityCooldownViewer" then
      _RegisterViewerMover(info)
    end
  end
end

local function _RefreshViewerBordersOnly(viewerKey)
  if viewerKey then
    _PCM_RefreshOwnedViewer(Cooldowns, viewerKey)
    return
  end
  for _, info in Cooldowns:IterateViewers() do
    _PCM_RefreshOwnedViewer(Cooldowns, info.key)
  end
end

local function _RefreshViewerFontsOnly(viewerKey)
  _RefreshViewerBordersOnly(viewerKey)
end

local function _RefreshIconViewers(viewerKey)
  _RefreshViewerBordersOnly(viewerKey)
end

Cooldowns._RefreshViewerBordersOnly = _RefreshViewerBordersOnly
Cooldowns._RefreshViewerFontsOnly = _RefreshViewerFontsOnly

function Cooldowns:RefreshIconFonts()
  _RefreshViewerFontsOnly(nil)
  self:ConsumableTracker_RefreshFonts()
end


local function _RefreshViewerOwnershipAfterBlizzardEditMode(self)
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  if PCMHooks.InBlizzardEditMode() then
    return
  end

  _InitAllViewerMovers()

  do
    local viewersDB = self:_GetViewerDB()

    for _, info in self:IterateViewers() do
      local key = info and info.key
      local frame = key and self:GetViewerFrame(key) or nil

      if _PCM_IsAbilityViewerKey(key)
        and frame
        and not (frame.IsForbidden and frame:IsForbidden())
      then
        if viewersDB and viewersDB[key] then
          _GetOrCreateViewerAnchorFrame(frame, key)
          _ForceAnchor(frame, key)

        end
      end
    end
  end

  FrameUtil.RelayoutSmartSnapCluster("PCM_EssentialCooldownViewer")
  FrameUtil.RelayoutSmartSnapCluster("PCM_UtilityCooldownViewer")

  ns.Modules.PCM_Buffs:RefreshSettings()
  ns.Modules.PCM_BuffBars:RefreshSettings()

  self:_RequestViewerRefresh("layout")
  self:_RequestViewerRefresh("icons")
end

function Cooldowns:_OnEditModeChanged(enable)
  local moduleEnabled = _PCM_IsModuleEnabledFast() == true

  enable = (enable == true)

  if not moduleEnabled then
    Cooldowns.__puiPCM_EditModeOn = false
    return
  end

  Cooldowns.__puiPCM_EditModeOn = enable
  ns.PCMCustomIcons:RefreshAllVisibility()

  if enable then
    _InitAllViewerMovers()
    Cooldowns.RefreshKeybinds(nil)
  else
    Cooldowns:_RequestViewerRefresh("icons")
    Cooldowns.RefreshKeybinds(nil)
  end
end

function Cooldowns:_OnBlizzardEditModeChanged(enable)
  enable = (enable == true)

  if not _PCM_IsModuleEnabledFast() then
    return
  end

  if enable then
    ns.PCMNativeBridge:Refresh()
    return
  end

  if InCombatLockdown() then
    self.__puiPCM_BlizzardEditModeRetakePending = true
    return
  end

  self.__puiPCM_BlizzardEditModeRetakePending = nil
  _RefreshViewerOwnershipAfterBlizzardEditMode(self)
  ns.PCMNativeBridge:Refresh()

end

local function _ApplyPCMProfile(self)
  _InitAllViewerMovers()

  do
    local viewersDB = self:_GetViewerDB()

    for _, info in self:IterateViewers() do
      local key = info and info.key
      local frame = key and self:GetViewerFrame(key) or nil

      if _PCM_IsAbilityViewerKey(key)
        and frame
        and viewersDB
        and viewersDB[key]
      then
        _GetOrCreateViewerAnchorFrame(frame, key)
        _ForceAnchor(frame, key)
      end
    end
  end

  FrameUtil.RelayoutSmartSnapCluster("PCM_EssentialCooldownViewer")
  FrameUtil.RelayoutSmartSnapCluster("PCM_UtilityCooldownViewer")

  ns.Modules.PCM_Buffs:RefreshSettings()
  ns.Modules.PCM_BuffBars:RefreshSettings()
  _RefreshIconViewers()
end

local function _EnsurePCMViewerMoverForKey(key)
  if not key then
    return
  end

  for _, info in Cooldowns:IterateViewers() do
    if info and info.key == key then
      _RegisterViewerMover(info)
      return
    end
  end
end

local function _EnsureViewerMovers()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  for _, info in Cooldowns:IterateViewers() do
    local key = info.key
    if key then
      _EnsurePCMViewerMoverForKey(key)
    end
  end
end

function Cooldowns:_FlushViewerRefreshImmediate(mode, viewerKey)
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  self:_RequestViewerRefresh(mode, viewerKey)
  ns.PCMAbilityRuntime:Flush()
  ns.PCMAuraRuntime:Flush()
end

function Cooldowns:_RequestViewerRefresh(mode, viewerKey)
  if not self or not _PCM_IsModuleEnabledFast() then
    return
  end

  if viewerKey and _PCM_IsCoreViewerKey(viewerKey) then
    _PCM_RefreshOwnedViewer(self, viewerKey)
    return
  end

  if not viewerKey then
    for _, info in self:IterateViewers() do
      _PCM_RefreshOwnedViewer(self, info.key)
    end
  end
end

function Cooldowns:RefreshIndividualIconSettings(viewerKey)
  if viewerKey == "EssentialCooldownViewer" or viewerKey == "UtilityCooldownViewer" then
    local entries = ns.PCMAbilityCatalog:GetViewerEntries(viewerKey)
    for index = 1, #entries do
      ns.PCMAbilityRuntime:ApplyEntrySettings(entries[index].cooldownID)
    end
  elseif viewerKey == "BuffIconCooldownViewer" then
    ns.Modules.PCM_Buffs:RefreshIndividualIconSettings()
  elseif viewerKey == "BuffBarCooldownViewer" then
    ns.PCMAuraRuntime:RefreshAppearance(viewerKey)
  end
end

function Cooldowns:RefreshViewerGlows()
  ns.PCMAbilityRuntime:MarkBucketDirty(
    "proc",
    ns.PCMAbilityRuntime.DIRTY_STATE
  )
end

local function _PCM_RegisterEditModeParticipant(self)
  _G.PleebUIAPI:RegisterPlugin("PleebUI_CooldownManager", {
    name = "Cooldown Manager",
  }):RegisterEditModeParticipant("runtime", {
    order = 40,
    onChanged = function(enable)
      self:_OnEditModeChanged(enable)
    end,
  })
end



function Cooldowns:OnInitialize()
  PCM_DB.Attach(Cooldowns)
  _PCM_RegisterEditModeParticipant(self)

  local cm = Cooldowns._GetModuleDB()
  local enabled = PCM_DB.IsPCMEnabled() == true
  PCMEnabled = enabled
  cm.enabled = enabled

  PCMHooks.SetRuntimeEnabled(enabled)
  self:SetEnabledState(enabled)
  ns.Modules.PCM_Buffs:SetEnabledState(enabled)
  ns.Modules.PCM_BuffBars:SetEnabledState(enabled)
  ns.Modules.PCM_BB:SetEnabledState(enabled)

  if enabled and PCMRuntime:IsInitializing() then
    C_AddOns.LoadAddOn("Blizzard_CooldownViewer")
    -- Register before VARIABLES_LOADED, after Blizzard registers its provider setup.
    EventUtil.ContinueAfterAllEvents(function()
      PCMStartupDataReady = true
      if self:IsEnabled() then
        _PCM_RunInitialViewerPass(self)
      end
    end, "VARIABLES_LOADED", "PLAYER_ENTERING_WORLD", "COOLDOWN_VIEWER_DATA_LOADED", "SPELLS_CHANGED")
  end
end

local function _PCM_SetOneChildModuleEnabled(mod, want)
  if want then
    if not mod:IsEnabled() then
      mod:Enable()
    end
  elseif mod:IsEnabled() then
    mod:Disable()
  end
end

local function _PCM_SetChildModulesEnabled(want)
  _PCM_SetOneChildModuleEnabled(ns.Modules.PCM_Buffs, want)
  _PCM_SetOneChildModuleEnabled(ns.Modules.PCM_BuffBars, want)
  _PCM_SetOneChildModuleEnabled(ns.Modules.PCM_BB, want)

  if want then
    Cooldowns:SpellBars_Enable()
    Cooldowns:CooldownStackBars_Enable()
    Cooldowns:ConsumableTracker_Enable()
  else
    Cooldowns:SpellBars_Disable()
    Cooldowns:CooldownStackBars_Disable()
    Cooldowns:ConsumableTracker_Disable()
  end
end

function Cooldowns:_PCM_RunDisableTeardown()
  PCMHooks.SetRuntimeEnabled(false)
  self.__puiPCM_EditModeOn = false
  self.__puiPCM_BlizzardEditModeRetakePending = nil
  self.__puiPCMCustomTrackerStartupPending = nil

  PCMTransitionFlushFrame:Hide()
  PCMTransitionState.Queued = false
  PCMTransitionState.FlushQueued = false
  PCMTransitionState.Owner = nil
  PCMTransitionState.InvalidateClassSpellCache = false

  _DeactivatePCMOwnedFrames()

  self:_Keybinds_Disable()
  _PCM_SetChildModulesEnabled(false)

  PCMRuntime:Disable()
  PCMRuntime:SetSubscriberEnabled("Coordinator", false)

end

function Cooldowns:SetModuleEnabled(enabled)
  if InCombatLockdown() then
    return false
  end

  local cm = Cooldowns._GetModuleDB()
  local want = enabled == true

  cm.enabled = want
  PCMEnabled = want
  PCMHooks.SetRuntimeEnabled(want)

  if want then
    self:Enable()
  else
    self:Disable()
  end

  Addon:RequestUpdate("CooldownManager", {
    profile = true,
    layout = true,
    movers = true,
  })
  Addon:RequestUpdate("Options", { options = true })
  return true
end

function Cooldowns:IsModuleEnabledByUser()
  return _PCM_IsModuleEnabledFast()
end

local PCMCVarRefreshFrame = CreateFrame("Frame")
PCMCVarRefreshFrame:Hide()
PCMCVarRefreshFrame:SetScript("OnUpdate", function(frame)
  frame:Hide()
  _PCM_ReconcileNativeCDM()
  Addon:InvalidateOptionsRender("CooldownManager")
  LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
end)

local PCMCVarFrame = CreateFrame("Frame")
PCMCVarFrame:SetScript("OnEvent", function(_, _, cvarName)
  if cvarName == COOLDOWN_MANAGER_CVAR then
    PCMCVarRefreshFrame:Show()
  end
end)

local function _RunPCMStartupRefresh(self)
  if not self or not _PCM_IsModuleEnabledFast() then
    return false
  end

  if Addon:IsBlizzardEditModeActive() then
    return false
  end

  if not C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer") then
    if InCombatLockdown() and FrameUtil._smartSnapWorldReady then
      self.__puiPCMStartupPending = true
      return false
    end
    C_AddOns.LoadAddOn("Blizzard_CooldownViewer")
  end

  if PCMRuntime:IsDataRestricted() then
    self.__puiPCMStartupPending = true
    return false
  end

  self.__puiPCMStartupPending = nil
  return true
end

_PCM_RunInitialViewerPass = function(owner)
  if owner.__puiPCMStartupComplete == true then
    return true
  end

  if PCMRuntime:IsInitializing() and not PCMStartupDataReady then
    owner.__puiPCMStartupPending = true
    return false
  end

  if not _RunPCMStartupRefresh(owner) then
    return false
  end

  if not PCMRuntime:IsDataRestricted() then
    IconSettings:PrimeRuntimeCache()
  end

  local settings = _G.CooldownViewerSettings
  local provider = settings and settings:GetDataProvider() or nil
  if not provider
    or type(provider.IsLayoutUpdateQueued) ~= "function"
    or provider:IsLayoutUpdateQueued()
  then
    owner.__puiPCMStartupPending = true
    return false
  end

  if ns.PCMGroupManager:IsStructureLocked() then
    owner.__puiPCMStartupPending = true
    return false
  end

  local migrationComplete = PCM_DB.IsRendererMigrationComplete()
  if not _PCM_MigrateOwnedViewerTooltips() then
    owner.__puiPCMStartupPending = true
    return false
  end
  if not migrationComplete then
    ns.Modules.PCM_Buffs:RefreshSettings()
    ns.Modules.PCM_BuffBars:RefreshSettings()
  end

  _PCM_InitializeOwnedViewers(owner)

  for _, info in owner:IterateViewers() do
    local key = info and info.key
    if key and not owner:GetViewerFrame(key) then
      owner.__puiPCMStartupPending = true
      return false
    end
  end

  ns.PCMAbilityCatalog:Invalidate("initial-viewer-pass")
  ns.PCMAbilityCatalog:Refresh()
  ns.PCMAbilityRuntime:Flush()
  ns.PCMAuraRuntime:Flush()
  ns.PCMGroupManager:Flush()

  if not ns.PCMAbilityRuntime:IsReady() or not ns.PCMAuraRuntime:IsReady() then
    owner.__puiPCMStartupPending = true
    return false
  end

  for _, info in owner:IterateViewers() do
    local key = info and info.key
    local frame = key and owner:GetViewerFrame(key) or nil
    if frame then
      _RegisterViewerMover(info)
    end
  end

  _PCM_ReconcileNativeCDM()
  owner:_ReconcileCustomTrackerStartupAvailability()
  owner.__puiPCMStartupPending = nil
  owner.__puiPCMStartupComplete = true
  PCMRuntime:FinishInitialization()
  return true
end

local function _PCM_PrepareStartupLayout()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  _PCM_RunInitialViewerPass(Cooldowns)
end

local function _PCM_OnFrameScaleChanged(_, scale)
  if Cooldowns.__puiFrameScale == scale then
    return
  end

  Cooldowns.__puiFrameScale = scale
  Cooldowns:SoftRebuild({ layout = true })
end

function Cooldowns:OnEnable()
  if not _PCM_IsModuleEnabledFast() then
    self:_PCM_RunDisableTeardown()
    self:Disable()
    return
  end

  _PCM_PrimeViewerCountCache()
  self.__puiPCMStartupComplete = nil

  PCMHooks.SetRuntimeEnabled(true)
  PCMHooks.HookEditMode(self)

  PCMRuntime:SetSubscriberEnabled("Coordinator", true)
  PCMRuntime:Enable()
  _PCM_InitializeOwnedViewers(self)
  ns.PCMAbilityRuntime:Enable()
  ns.PCMAuraRuntime:Enable()
  ns.PCMGroupManager:Enable()

  _PCM_SetChildModulesEnabled(true)
  self:_Keybinds_Enable()

  self.__puiFrameScale = Pixel.GetOnePixel()
  FrameScale:RegisterScaleListener(_PCM_OnFrameScaleChanged)

  FrameUtil:RegisterStartupLayoutParticipant(
    "PCM",
    _PCM_PrepareStartupLayout
  )
  PCMCVarFrame:RegisterEvent("CVAR_UPDATE")
  _PCM_RunInitialViewerPass(self)
  EventRegistry:RegisterCallback(
    "CooldownViewerSettings.OnHide",
    _PCM_OnNativeSettingsHidden,
    self
  )
end

function Cooldowns:OnDisable()
  EventRegistry:UnregisterCallback("CooldownViewerSettings.OnHide", self)
  PCMCVarFrame:UnregisterEvent("CVAR_UPDATE")
  PCMCVarRefreshFrame:Hide()
  PCMNativePolicy.ReconcilePending = false
  FrameScale:UnregisterScaleListener(_PCM_OnFrameScaleChanged)
  self.__puiFrameScale = nil
  self.__puiPCMStartupComplete = nil
  self.__puiPCMStartupPending = nil
  ns.PCMNativeBridge:Disable()
  ns.PCMGroupManager:Disable()
  ns.PCMAbilityRuntime:Disable()
  ns.PCMAuraRuntime:Disable()
  self:_PCM_RunDisableTeardown()
end

function Cooldowns:_ReconcileCustomTrackerStartupAvailability()
  if self.__puiPCMCustomTrackerStartupReconciled == true then
    return
  end

  if InCombatLockdown() then
    self.__puiPCMCustomTrackerStartupPending = true
    return
  end

  self.__puiPCMCustomTrackerStartupPending = nil

  self:ClearSavedSpellKnownCache()
  self:SpellBars_ReconcileAvailability()
  self:CooldownStackBars_RefreshAfterTalentSwap()
  ns.Modules.PCM_BB.RefreshAfterTalentSwap()
  ns.PCM_RefreshCustomBarsOptionsAfterSpecializationChange()

  self.__puiPCMCustomTrackerStartupReconciled = true
end



function Cooldowns:_OnPlayerEnteringWorld()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  _PCM_RunInitialViewerPass(self)
  self:_ReconcileCustomTrackerStartupAvailability()
end

function Cooldowns:_OnPlayerSpecializationChanged(_, unit)
  if unit ~= "player" then
    return
  end

  if not _PCM_IsModuleEnabledFast() then
    return
  end

  _PCM_BeginTransition(self, true)
end

function Cooldowns:_OnTraitConfigUpdated(_, configID)
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  local activeID = C_ClassTalents.GetActiveConfigID()
  if configID and activeID and configID ~= activeID then
    return
  end

  _PCM_BeginTransition(self, false)
end

function Cooldowns:_OnCooldownViewerDataLoaded()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  if self.__puiPCMStartupComplete == true then
    _PCM_BeginTransition(self, true)
  else
    _PCM_RunInitialViewerPass(self)
  end
end

function Cooldowns:_OnCooldownViewerTableHotfixed()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  _PCM_BeginTransition(self, true)
end

function Cooldowns:_OnSpellsChanged()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  _PCM_BeginTransition(self, true)
end

local function _PCM_RuntimeLifecycleEvent(event, ...)
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  local arg1, arg2 = ...

  if event == "PLAYER_ENTERING_WORLD" then
    Cooldowns:_OnPlayerEnteringWorld()
  elseif event == "PLAYER_REGEN_ENABLED" then
    Cooldowns:_OnDataRestrictionsCleared()
  elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
    if arg2 == Enum.AddOnRestrictionState.Inactive
      and not InCombatLockdown()
    then
      Cooldowns:_OnDataRestrictionsCleared()
    end
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    Cooldowns:_OnPlayerSpecializationChanged(event, arg1)
  elseif event == "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED" then
    ns.PCMAuraRuntime:ApplySpellOverride(arg1, arg2)
  elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
    or event == "ACTIVE_COMBAT_CONFIG_CHANGED"
    or event == "PLAYER_TALENT_UPDATE"
    or event == "PLAYER_PVP_TALENT_UPDATE"
    or event == "ACTIVE_TALENT_GROUP_CHANGED"
    or event == "PLAYER_EQUIPMENT_CHANGED"
  then
    _PCM_BeginTransition(Cooldowns, true)
  elseif event == "TRAIT_CONFIG_UPDATED" then
    Cooldowns:_OnTraitConfigUpdated(event, arg1)
  elseif event == "COOLDOWN_VIEWER_DATA_LOADED" then
    Cooldowns:_OnCooldownViewerDataLoaded()
  elseif event == "COOLDOWN_VIEWER_TABLE_HOTFIXED" then
    Cooldowns:_OnCooldownViewerTableHotfixed()
  elseif event == "SPELLS_CHANGED" then
    Cooldowns:_OnSpellsChanged()
  elseif event == "ADDON_LOADED" then
    _PCM_RunInitialViewerPass(Cooldowns)
  elseif event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "LOADING_SCREEN_DISABLED" then
    if Cooldowns.__puiPCMStartupPending then
      _PCM_RunInitialViewerPass(Cooldowns)
    end
  end
end

PCMRuntime:RegisterSubscriber("Coordinator", {
  OnLifecycleEvent = _PCM_RuntimeLifecycleEvent,
})

function Cooldowns:ApplySettings(flags)
  if not flags then
    return
  end

  if flags.profile == true then
    local profileEnabled = PCM_DB.IsPCMEnabled() == true
    local enabled = profileEnabled
    PCMEnabled = enabled
    PCMHooks.SetRuntimeEnabled(enabled)

    if enabled then
      if not self:IsEnabled() then
        self:Enable()
        return
      end
    else
      if self:IsEnabled() then
        self:Disable()
      end
      return
    end
  end

  if not _PCM_IsModuleEnabledFast() then
    return
  end

  local needsIconRefresh = false
  local needsFontRefresh = false

  if flags.profile == true then
    _PCM_MigrateOwnedViewerTooltips()
    ns.PCMGroupManager:RefreshProfile()
    IconSettings:InvalidateCatalog()
    IconSettings:InvalidateSettings()
    needsIconRefresh = true

    _PCM_InvalidateViewerRuleSettingCache()
    _PCM_PrimeViewerCountCache()
  end

  if flags.theme == true then
    needsIconRefresh = true
  end

  if flags.fonts == true then
    needsFontRefresh = true
  end

  ns.Modules.PCM_Buffs:ApplySettings(flags)
  ns.Modules.PCM_BuffBars:ApplySettings(flags)
  ns.Modules.PCM_BB:ApplySettings(flags)

  self:_SpellBars_ApplySettings(flags)
  self:_CooldownStackBars_ApplySettings(flags)
  self:_ConsumableTracker_ApplySettings(flags)

  if needsIconRefresh then
    _RefreshIconViewers(nil)
  elseif needsFontRefresh then
    _RefreshViewerFontsOnly(nil)
  end

  if flags.profile == true then
    self:RefreshAbilityCatalog()
    self:ApplyKeybindTextRulesNow(nil)
    _PCM_ReconcileNativeCDM()
  end
end

function Cooldowns:SoftRebuild(flags)
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  if not flags then
    return
  end

  if flags.profile ~= true and flags.layout ~= true and flags.movers ~= true then
    return
  end

  _ApplyPCMProfile(self)
  _EnsureViewerMovers()
  self:_RequestViewerRefresh("layout")
  ns.PCMGroupManager:RequestLayout()

  ns.Modules.PCM_Buffs:SoftRebuild(flags)
  ns.Modules.PCM_BuffBars:SoftRebuild(flags)
  ns.Modules.PCM_BB:SoftRebuild(flags)

  self:_SpellBars_SoftRebuild(flags)
  self:_CooldownStackBars_SoftRebuild(flags)
  self:_ConsumableTracker_SoftRebuild(flags)
end

local function _PCM_AddCustomBarSpellID(spellSet, spellID)
  if _PCM_IsSecret(spellID) then
    return
  end

  spellID = tonumber(spellID)
  if spellID and spellID > 0 then
    spellSet[spellID] = true
  end
end

local function _PCM_GetCustomBarInfoSpellSet(info)
  local spellSet = {}
  if type(info) ~= "table" then
    return spellSet
  end

  _PCM_AddCustomBarSpellID(spellSet, info.spellID)
  _PCM_AddCustomBarSpellID(spellSet, info.overrideSpellID)
  _PCM_AddCustomBarSpellID(spellSet, info.overrideTooltipSpellID)

  if type(info.linkedSpellIDs) == "table" then
    for index = 1, #info.linkedSpellIDs do
      _PCM_AddCustomBarSpellID(spellSet, info.linkedSpellIDs[index])
    end
  end

  return spellSet
end

function Cooldowns:ResolveCustomBarAuraEntry(wantedSpellID, cachedCooldownID)
  if wantedSpellID == nil or _PCM_IsSecret(wantedSpellID) then
    return nil, nil
  end

  wantedSpellID = tonumber(wantedSpellID)
  if not wantedSpellID or wantedSpellID <= 0 then
    return nil, nil
  end

  if cachedCooldownID ~= nil and not _PCM_IsSecret(cachedCooldownID) then
    cachedCooldownID = tonumber(cachedCooldownID)
    if cachedCooldownID and cachedCooldownID > 0 then
      local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cachedCooldownID)
      if not _PCM_IsSecret(info) and type(info) == "table" then
        local spellSet = _PCM_GetCustomBarInfoSpellSet(info)
        if spellSet[wantedSpellID] then
          return cachedCooldownID, spellSet
        end
      end
    end
  end

  if InCombatLockdown() then
    return nil, nil
  end

  local function FindInCategory(category)
    local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category, true)
    if _PCM_IsSecret(cooldownIDs) or type(cooldownIDs) ~= "table" then
      return nil, nil
    end

    for index = 1, #cooldownIDs do
      local cooldownID = cooldownIDs[index]
      if not _PCM_IsSecret(cooldownID)
        and type(cooldownID) == "number"
        and cooldownID > 0
      then
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
        if not _PCM_IsSecret(info) and type(info) == "table" then
          local spellSet = _PCM_GetCustomBarInfoSpellSet(info)
          if spellSet[wantedSpellID] then
            return cooldownID, spellSet
          end
        end
      end
    end

    return nil, nil
  end

  for index = 1, #PCM_CUSTOM_BAR_AURA_CATEGORIES do
    local cooldownID, spellSet = FindInCategory(PCM_CUSTOM_BAR_AURA_CATEGORIES[index])
    if cooldownID then
      return cooldownID, spellSet
    end
  end

  return nil, nil
end


function Cooldowns:OnProfileChanged()
  self:ApplySettings({ profile = true })
  self:SoftRebuild({ profile = true, movers = true, layout = true })
end

  Cooldowns.ApplyCustomBarsCDMProfile = P:Def('Cooldowns:ApplyCustomBarsCDMProfile', Cooldowns.ApplyCustomBarsCDMProfile)
  Cooldowns.ExportCustomBars = P:Def('Cooldowns:ExportCustomBars', Cooldowns.ExportCustomBars)
  Cooldowns.ImportCustomBarsString = P:Def('Cooldowns:ImportCustomBarsString', Cooldowns.ImportCustomBarsString)
  RoundPixel = P:Def('RoundPixel', RoundPixel)
  _PCM_IsModuleEnabledFast = P:Def('_PCM_IsModuleEnabledFast', _PCM_IsModuleEnabledFast)
  ns.PCM_IsModuleEnabledFast = _PCM_IsModuleEnabledFast
  _RebuildViewerRegistry = P:Def('_RebuildViewerRegistry', _RebuildViewerRegistry)
  Cooldowns.IterateViewers = P:Def('Cooldowns:IterateViewers', Cooldowns.IterateViewers)
  Cooldowns.GetViewerInfo = P:Def('Cooldowns:GetViewerInfo', Cooldowns.GetViewerInfo)
  Cooldowns.GetViewerFrame = P:Def('Cooldowns:GetViewerFrame', Cooldowns.GetViewerFrame)
  _PCM_EnsureEditModeLayout = P:Def('_PCM_EnsureEditModeLayout', _PCM_EnsureEditModeLayout)
  Cooldowns.GetViewerTooltipsEnabled = P:Def('Cooldowns:GetViewerTooltipsEnabled', Cooldowns.GetViewerTooltipsEnabled)
  Cooldowns.SetViewerTooltipsEnabled = P:Def('Cooldowns:SetViewerTooltipsEnabled', Cooldowns.SetViewerTooltipsEnabled)
  Cooldowns.GetViewerHideWhenInactive = P:Def('Cooldowns:GetViewerHideWhenInactive', Cooldowns.GetViewerHideWhenInactive)
  Cooldowns.SetViewerHideWhenInactive = P:Def('Cooldowns:SetViewerHideWhenInactive', Cooldowns.SetViewerHideWhenInactive)
  _DeactivatePCMOwnedFrames = P:Def('_DeactivatePCMOwnedFrames', _DeactivatePCMOwnedFrames)
  Cooldowns.GetCustomBarSpellDropdown = P:Def('Cooldowns:GetCustomBarSpellDropdown', Cooldowns.GetCustomBarSpellDropdown)

  _PCM_LoadViewerCountFlags = P:Def('_PCM_LoadViewerCountFlags', _PCM_LoadViewerCountFlags)
  _PCM_PrimeViewerCountCache = P:Def('_PCM_PrimeViewerCountCache', _PCM_PrimeViewerCountCache)
  _PCM_SetViewerCountFlagCached = P:Def('_PCM_SetViewerCountFlagCached', _PCM_SetViewerCountFlagCached)
  _PCM_InvalidateViewerRuleSettingCache = P:Def('_PCM_InvalidateViewerRuleSettingCache', _PCM_InvalidateViewerRuleSettingCache)
  _PCM_GetViewerCountFlagsCached = P:Def('_PCM_GetViewerCountFlagsCached', _PCM_GetViewerCountFlagsCached)
  Cooldowns._PrimeViewerCountCache = _PCM_PrimeViewerCountCache
  Cooldowns._SetViewerCountFlagCached = _PCM_SetViewerCountFlagCached
  Cooldowns._InvalidateViewerRuleSettingCache = _PCM_InvalidateViewerRuleSettingCache
  Cooldowns._GetViewerCountFlagsCached = _PCM_GetViewerCountFlagsCached
  Cooldowns.GetCooldownCountEnabled = P:Def('Cooldowns:GetCooldownCountEnabled', Cooldowns.GetCooldownCountEnabled)
  Cooldowns.SetCooldownCountEnabled = P:Def('Cooldowns:SetCooldownCountEnabled', Cooldowns.SetCooldownCountEnabled)
  Cooldowns.GetBuffCountEnabled = P:Def('Cooldowns:GetBuffCountEnabled', Cooldowns.GetBuffCountEnabled)
  Cooldowns.SetBuffCountEnabled = P:Def('Cooldowns:SetBuffCountEnabled', Cooldowns.SetBuffCountEnabled)
  Cooldowns.GetChargeCountEnabled = P:Def('Cooldowns:GetChargeCountEnabled', Cooldowns.GetChargeCountEnabled)
  Cooldowns.SetChargeCountEnabled = P:Def('Cooldowns:SetChargeCountEnabled', Cooldowns.SetChargeCountEnabled)
  Cooldowns.ApplyCooldownCountRulesNow = P:Def('Cooldowns:ApplyCooldownCountRulesNow', Cooldowns.ApplyCooldownCountRulesNow)
  _PCM_GetDurationCountEnabledCached = P:Def('_PCM_GetDurationCountEnabledCached', _PCM_GetDurationCountEnabledCached)
  Cooldowns.SetDurationCountEnabled = P:Def('Cooldowns:SetDurationCountEnabled', Cooldowns.SetDurationCountEnabled)
  Cooldowns.GetDurationCountEnabled = P:Def('Cooldowns:GetDurationCountEnabled', Cooldowns.GetDurationCountEnabled)
  _PCM_InvalidateClassSpellCache = P:Def('_PCM_InvalidateClassSpellCache', _PCM_InvalidateClassSpellCache)
  _PCM_BeginTransition = P:Def('_PCM_BeginTransition', _PCM_BeginTransition)
  _PCM_RunHardViewerTransition = P:Def('_PCM_RunHardViewerTransition', _PCM_RunHardViewerTransition)
  _PCM_ReconcileRuntimeViewers = P:Def('_PCM_ReconcileRuntimeViewers', _PCM_ReconcileRuntimeViewers)
  _PCM_FinalizeTransition = P:Def('_PCM_FinalizeTransition', _PCM_FinalizeTransition)
  _GetOrCreateViewerAnchorFrame = P:Def('_GetOrCreateViewerAnchorFrame', _GetOrCreateViewerAnchorFrame)
  Cooldowns.GetViewerAnchorFrame = P:Def('Cooldowns:GetViewerAnchorFrame', Cooldowns.GetViewerAnchorFrame)
  _ForceAnchor = P:Def('_ForceAnchor', _ForceAnchor)
  Cooldowns._OnDataRestrictionsCleared = P:Def('Cooldowns:_OnDataRestrictionsCleared', Cooldowns._OnDataRestrictionsCleared)
  _EnsureDefaultViewerAnchor = P:Def('_EnsureDefaultViewerAnchor', _EnsureDefaultViewerAnchor)
  _RegisterViewerMover = P:Def('_RegisterViewerMover', _RegisterViewerMover)
  _InitAllViewerMovers = P:Def('_InitAllViewerMovers', _InitAllViewerMovers)
  _RefreshViewerBordersOnly = P:Def('_RefreshViewerBordersOnly', _RefreshViewerBordersOnly)
  _RefreshViewerFontsOnly = P:Def('_RefreshViewerFontsOnly', _RefreshViewerFontsOnly)
  _RefreshIconViewers = P:Def('_RefreshIconViewers', _RefreshIconViewers)
  Cooldowns.RefreshIndividualIconSettings = P:Def('Cooldowns:RefreshIndividualIconSettings', Cooldowns.RefreshIndividualIconSettings)
  Cooldowns.RefreshIconFonts = P:Def('Cooldowns:RefreshIconFonts', Cooldowns.RefreshIconFonts)
  _RefreshViewerOwnershipAfterBlizzardEditMode = P:Def(
    '_RefreshViewerOwnershipAfterBlizzardEditMode',
    _RefreshViewerOwnershipAfterBlizzardEditMode
  )
  Cooldowns._OnEditModeChanged = P:Def('Cooldowns:_OnEditModeChanged', Cooldowns._OnEditModeChanged)
  Cooldowns._OnBlizzardEditModeChanged = P:Def('Cooldowns:_OnBlizzardEditModeChanged', Cooldowns._OnBlizzardEditModeChanged)
  _ApplyPCMProfile = P:Def('_ApplyPCMProfile', _ApplyPCMProfile)
  _EnsurePCMViewerMoverForKey = P:Def('_EnsurePCMViewerMoverForKey', _EnsurePCMViewerMoverForKey)
  _EnsureViewerMovers = P:Def('_EnsureViewerMovers', _EnsureViewerMovers)
  Cooldowns._RequestViewerRefresh = P:Def('Cooldowns:_RequestViewerRefresh', Cooldowns._RequestViewerRefresh)
  Cooldowns.RefreshAbilityCatalog = P:Def('Cooldowns:RefreshAbilityCatalog', Cooldowns.RefreshAbilityCatalog)
  Cooldowns._FlushViewerRefreshImmediate = P:Def('Cooldowns:_FlushViewerRefreshImmediate', Cooldowns._FlushViewerRefreshImmediate)
  Cooldowns.RefreshViewerGlows = P:Def('Cooldowns:RefreshViewerGlows', Cooldowns.RefreshViewerGlows)
  _PCM_RegisterEditModeParticipant = P:Def('_PCM_RegisterEditModeParticipant', _PCM_RegisterEditModeParticipant)
  Cooldowns.OnInitialize = P:Def('Cooldowns:OnInitialize', Cooldowns.OnInitialize)
  _PCM_SetOneChildModuleEnabled = P:Def('_PCM_SetOneChildModuleEnabled', _PCM_SetOneChildModuleEnabled)
  _PCM_SetChildModulesEnabled = P:Def('_PCM_SetChildModulesEnabled', _PCM_SetChildModulesEnabled)
  Cooldowns._PCM_RunDisableTeardown = P:Def('Cooldowns:_PCM_RunDisableTeardown', Cooldowns._PCM_RunDisableTeardown)
  Cooldowns.SetModuleEnabled = P:Def('Cooldowns:SetModuleEnabled', Cooldowns.SetModuleEnabled)
  Cooldowns.IsModuleEnabledByUser = P:Def('Cooldowns:IsModuleEnabledByUser', Cooldowns.IsModuleEnabledByUser)
  _RunPCMStartupRefresh = P:Def('_RunPCMStartupRefresh', _RunPCMStartupRefresh)
  _PCM_RunInitialViewerPass = P:Def('_PCM_RunInitialViewerPass', _PCM_RunInitialViewerPass)
  Cooldowns.OnEnable = P:Def('Cooldowns:OnEnable', Cooldowns.OnEnable)
  Cooldowns.OnDisable = P:Def('Cooldowns:OnDisable', Cooldowns.OnDisable)
  Cooldowns._ReconcileCustomTrackerStartupAvailability = P:Def('Cooldowns:_ReconcileCustomTrackerStartupAvailability', Cooldowns._ReconcileCustomTrackerStartupAvailability)
  Cooldowns._OnPlayerEnteringWorld = P:Def('Cooldowns:_OnPlayerEnteringWorld', Cooldowns._OnPlayerEnteringWorld)
  Cooldowns._OnPlayerSpecializationChanged = P:Def('Cooldowns:_OnPlayerSpecializationChanged', Cooldowns._OnPlayerSpecializationChanged)
  Cooldowns._OnTraitConfigUpdated = P:Def('Cooldowns:_OnTraitConfigUpdated', Cooldowns._OnTraitConfigUpdated)
  Cooldowns._OnCooldownViewerDataLoaded = P:Def('Cooldowns:_OnCooldownViewerDataLoaded', Cooldowns._OnCooldownViewerDataLoaded)
  Cooldowns._OnCooldownViewerTableHotfixed = P:Def('Cooldowns:_OnCooldownViewerTableHotfixed', Cooldowns._OnCooldownViewerTableHotfixed)
  Cooldowns._OnSpellsChanged = P:Def('Cooldowns:_OnSpellsChanged', Cooldowns._OnSpellsChanged)
  Cooldowns.ApplySettings = P:Def('Cooldowns:ApplySettings', Cooldowns.ApplySettings)
  Cooldowns.SoftRebuild = P:Def('Cooldowns:SoftRebuild', Cooldowns.SoftRebuild)
  Cooldowns.OnProfileChanged = P:Def('Cooldowns:OnProfileChanged', Cooldowns.OnProfileChanged)
  _PCM_IsTransitionPending = P:Def('_PCM_IsTransitionPending', _PCM_IsTransitionPending)
  _PCM_FlushTransition = P:Def('_PCM_FlushTransition', _PCM_FlushTransition)
  _PCM_QueueTransitionFlush = P:Def('_PCM_QueueTransitionFlush', _PCM_QueueTransitionFlush)
  _PCM_AddCustomBarSpellID = P:Def('_PCM_AddCustomBarSpellID', _PCM_AddCustomBarSpellID)
  _PCM_GetCustomBarInfoSpellSet = P:Def('_PCM_GetCustomBarInfoSpellSet', _PCM_GetCustomBarInfoSpellSet)
  Cooldowns.ResolveCustomBarAuraEntry = P:Def('Cooldowns:ResolveCustomBarAuraEntry', Cooldowns.ResolveCustomBarAuraEntry)
  _EnsureViewerDurationCount = P:Def('_EnsureViewerDurationCount', _EnsureViewerDurationCount)
  Cooldowns._RefreshViewerBordersOnly = P:Def('Cooldowns._RefreshViewerBordersOnly', Cooldowns._RefreshViewerBordersOnly)
  Cooldowns._RefreshViewerFontsOnly = P:Def('Cooldowns._RefreshViewerFontsOnly', Cooldowns._RefreshViewerFontsOnly)
