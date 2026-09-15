-- File: PUI_PCM.lua

local ADDON_NAME, ns = ...

local Addon = ns.Addon
local FrameUtil = ns.FrameUtil
local FrameScale = ns.FrameScale
local Pixel = ns.Pixel
local Round = Pixel.Round
local IconSkin = ns.IconSkin
local LSM = ns.LSM
local LCG = LibStub("LibCustomGlow-1.0")
local LibEditModeOverride = LibStub("LibEditModeOverride-1.0")
local Theme = ns.Theme
local PCMHooks = ns.PCMHooks
local PCMRuntime = ns.PCMRuntime
local PCM_DB = ns.PCM_DBExports
local IconSettings = ns.PCMIconSettings
local Presentation = ns.Presentation
local PCMPresentation = ns.PCMPresentation

local _PCM_ApplyIconAppearance
local _PCM_ClearNativeIconPresentation
local _PCM_UpdateIconCooldownState

local function RoundPixel(v)
  if v == nil then
    return v
  end
  return Round(v)
end

local function _PUI_SetPointStamped(obj, point, rel, relPoint, xOfs, yOfs)
  if not obj then
    return
  end
  if not (obj.ClearAllPoints and obj.SetPoint) then
    return
  end

  local fd = PCMHooks.GetFrameData(obj)
  if fd.apPoint == point and fd.apRel == rel and fd.apRelPoint == relPoint and fd.apX == xOfs and fd.apY == yOfs then
    return
  end

  fd.apPoint = point
  fd.apRel = rel
  fd.apRelPoint = relPoint
  fd.apX = xOfs
  fd.apY = yOfs

  obj:ClearAllPoints()
  obj:SetPoint(point, rel, relPoint, xOfs, yOfs)
end

local function _PUI_SetAllPointsStamped(obj, parent)
  if not obj or not parent then
    return
  end
  if not (obj.ClearAllPoints and obj.SetAllPoints) then
    return
  end

  local fd = PCMHooks.GetFrameData(obj)
  if fd.apAllPointsParent == parent then
    return
  end

  fd.apAllPointsParent = parent

  obj:ClearAllPoints()
  obj:SetAllPoints(parent)
end

local t_wipe = table.wipe

local _PCM_IsSecret = issecretvalue

local function _PCM_GetEquipSlot(itemFrame)
  local info = itemFrame and itemFrame.cooldownInfo
  local equipSlot = info and info.equipSlot or nil

  if equipSlot == nil then
    return nil
  end

  if _PCM_IsSecret(equipSlot) then
    return nil
  end

  if type(equipSlot) == "string" then
    equipSlot = tonumber(equipSlot)
  end

  if type(equipSlot) ~= "number" or equipSlot <= 0 then
    return nil
  end

  return equipSlot
end

local function _PCM_IsEquipSlotCooldownItem(itemFrame)
  return _PCM_GetEquipSlot(itemFrame) ~= nil
end


local PCMViewerState = {
  ItemGen = 0,
}

local PCMCoreState = {
  CountRulesDirty = true,
  CacheGen = 0,
  StaticPresentationGeneration = 1,
  ViewerCountCache = {},
  DurationCountCache = {},
  SwipeFlagCache = {},
  Empty = {},
  ConfiguredEntryCountCache = {},
  ConfiguredEntryCountGen = -1,
}

local PCMEnabled

local PCMGlowState = {
  db = nil,
  enabled = nil,
  settings = nil,
}

local _PCM_MarkCountRulesDirty
local _EnsureViewerDurationCount
local _PCM_GetDurationCountEnabledCached
local _ShouldUseAuraCooldownOverride
local _ApplySimpleViewerLayout
local _ApplyIconSizeToItemFrame
local _PCM_ItemHasLayoutIndex
local _PCM_FlushBlockedViewerRefresh
local _PCM_RunHardViewerTransition
local _PCM_QueueTransitionFlush
local _PCM_ParkViewerItem
local _PCM_EnsureDataProviderHook

local PCMTransitionFlushFrame = CreateFrame("Frame")
PCMTransitionFlushFrame:Hide()

local PCMTransitionProviderHooks = setmetatable({}, { __mode = "k" })

local PCMTransitionState = {
  Gen = 0,
  Queued = false,
  FlushQueued = false,
  Owner = nil,
  InvalidateClassSpellCache = false,
}

local function _PCM_IsTransitionPending()
  return PCMTransitionState.Queued == true
end

ns.PCM_IsTransitionPending = _PCM_IsTransitionPending

local __PUI_PCM_ItemRulePassStamp = setmetatable({}, { __mode = "k" })

local PCMFrameState = {
  ViewerFrameKey = setmetatable({}, { __mode = "k" }),
}
local PCMAnchorState = {
  anchorsOwned = setmetatable({}, { __mode = "k" }),
  moverRegistered = setmetatable({}, { __mode = "k" }),
  applyingAnchor = setmetatable({}, { __mode = "k" }),
}

local function _PCM_AddCategory(list, seen, name)
  local value = Enum.CooldownViewerCategory[name]
  if value == nil or seen[value] then
    return
  end

  seen[value] = true
  list[#list + 1] = value
end

local function _PCM_GetViewerCategoryList(viewerKey)
  local list = {}
  local seen = {}

  if viewerKey == "EssentialCooldownViewer" then
    _PCM_AddCategory(list, seen, "Essential")
    _PCM_AddCategory(list, seen, "SpecAgnosticEssential")
    _PCM_AddCategory(list, seen, "EquipSlotEssential")
  elseif viewerKey == "UtilityCooldownViewer" then
    _PCM_AddCategory(list, seen, "Utility")
  elseif viewerKey == "BuffIconCooldownViewer" or viewerKey == "BuffBarCooldownViewer" then
    _PCM_AddCategory(list, seen, "TrackedBuff")
    _PCM_AddCategory(list, seen, "TrackedBar")
    _PCM_AddCategory(list, seen, "GroupBuff")
    _PCM_AddCategory(list, seen, "SpecAgnosticTracked")
    _PCM_AddCategory(list, seen, "EquipSlotTracked")
  end

  return list
end

local function _PCM_GetViewerCategoryEnum(viewerKey)
  local list = _PCM_GetViewerCategoryList(viewerKey)
  return list and list[1] or nil
end

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

local function _PCM_GetViewerKeyFromFrame(viewer)
  if not viewer then
    return nil
  end

  local key = PCMFrameState.ViewerFrameKey[viewer]
  if key then
    return key
  end

  if viewer.GetName then
    local name = viewer:GetName()
    if name == "EssentialCooldownViewer" or name == "UtilityCooldownViewer" then
      PCMFrameState.ViewerFrameKey[viewer] = name
      return name
    end
  end

  return nil
end

local function _PCM_GetConfiguredViewerEntryCount(viewerKey)
  if PCMHooks.IsAddonRestricted() then
    return nil
  end

  local category = _PCM_GetViewerCategoryEnum(viewerKey)
  if category == nil then
    return nil
  end

  if PCMCoreState.ConfiguredEntryCountGen ~= PCMViewerState.ItemGen then
    PCMCoreState.ConfiguredEntryCountGen = PCMViewerState.ItemGen
    wipe(PCMCoreState.ConfiguredEntryCountCache)
  end

  local cached = PCMCoreState.ConfiguredEntryCountCache[viewerKey]
  if cached ~= nil then
    return cached
  end

  local categories = _PCM_GetViewerCategoryList(viewerKey)
  if #categories == 0 then
    return nil
  end

  cached = 0
  for i = 1, #categories do
    local categorySet = C_CooldownViewer.GetCooldownViewerCategorySet(categories[i], false)
    if _PCM_IsSecret(categorySet) or type(categorySet) ~= "table" then
      return nil
    end

    cached = cached + #categorySet
  end

  PCMCoreState.ConfiguredEntryCountCache[viewerKey] = cached
  return cached
end



local function _PCM_ItemHasRenderableContent(itemFrame)
  if not itemFrame then
    return false
  end

  if _PCM_IsEquipSlotCooldownItem(itemFrame) then
    return true
  end

  if itemFrame.GetCooldownID then
    local cooldownID = itemFrame:GetCooldownID()
    if cooldownID ~= nil and not _PCM_IsSecret(cooldownID) then
      return true
    end
  end

  local cooldownID = itemFrame.cooldownID
  if cooldownID ~= nil and not _PCM_IsSecret(cooldownID) then
    return true
  end

  if itemFrame.HasEditModeData and itemFrame:HasEditModeData() then
    return true
  end

  if itemFrame.editModeIndex ~= nil then
    return true
  end

  return false
end

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


local P, TrackThis = ns.Pleebug:DropIn(Cooldowns, { name = "PCM", bucket = "Core" })



local _baseViewers = {

  { key = "EssentialCooldownViewer", title = "Essential Cooldowns",   ref = function() return _G.EssentialCooldownViewer  end },
}

Cooldowns.__puiPendingExtraViewers = {}
Cooldowns.__puiPendingExtraViewers[#Cooldowns.__puiPendingExtraViewers + 1] = {
  key   = "UtilityCooldownViewer",
  title = "Utility Cooldowns",
  ref   = function() return _G.UtilityCooldownViewer end,
}

Cooldowns.__puiDefaultViewerAnchors = {}
Cooldowns.__puiDefaultViewerAnchors.UtilityCooldownViewer = {
  point    = "TOP",
  rel      = "EssentialCooldownViewer",
  relPoint = "BOTTOM",
  x        = 0,
  y        = -10,
}

function Cooldowns:RegisterExtraViewer(info)
  if type(info) ~= "table" then return end
  if type(info.key) ~= "string" or info.key == "" then return end
  if type(info.ref) ~= "function" then return end

  self.__puiExtraViewers = self.__puiExtraViewers or {}
  local list = self.__puiExtraViewers
  for i = 1, #list do
    local v = list[i]
    if v and v.key == info.key then
      list[i] = info
      self._viewerRegistry = nil
      PCMRuntime:RegisterViewer(info.key, info.ref)
      return
    end
  end

  list[#list + 1] = info
  self._viewerRegistry = nil
  PCMRuntime:RegisterViewer(info.key, info.ref)
end

local function _ConsumePendingExtraViewers()
  local pending = Cooldowns.__puiPendingExtraViewers
  if not pending then
    return
  end

  for i = 1, #pending do
    Cooldowns:RegisterExtraViewer(pending[i])
  end

  Cooldowns.__puiPendingExtraViewers = nil
end


local function _IsEssentialViewerKey(key)
  return key == "EssentialCooldownViewer"
end

local function _PCM_IsCoreViewerKey(key)
  return key == "EssentialCooldownViewer" or key == "UtilityCooldownViewer"
end

local function _RebuildViewerRegistry(self)

  self._viewerRegistry = {}

  for _, v in ipairs(_baseViewers) do
    table.insert(self._viewerRegistry, v)
  end

  -- Extra viewers registered by other files (ex: Utility)
  local extra = self.__puiExtraViewers or {}
  for i = 1, #extra do
    local v = extra[i]
    if v then
      table.insert(self._viewerRegistry, v)
    end
  end

  -- Build quick lookup maps so hot paths do not rescan the registry.
  self.__puiViewerKindMap = {}
  self.__puiViewerInfoByKey = {}

  for i = 1, #self._viewerRegistry do
    local info = self._viewerRegistry[i]
    if info and info.key then
      self.__puiViewerKindMap[info.key] = true
      self.__puiViewerInfoByKey[info.key] = info

      PCMRuntime:RegisterViewer(info.key, info.ref)

      local f = PCMRuntime:GetViewer(info.key)
      if f then
        PCMFrameState.ViewerFrameKey[f] = info.key
      end
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

  local viewerFrame = PCMRuntime:GetViewer(key)

  if viewerFrame then
    PCMFrameState.ViewerFrameKey[viewerFrame] = key
  end

  return viewerFrame
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

local PCMEditModeChangesPending = false

local function _PCM_IsEditModeLayoutMutationBlocked()
  return PCMHooks.IsAddonRestricted()
end

local function _PCM_EnsureEditModeLayout()
  if not LibEditModeOverride:IsReady() then
    return false
  end

  if not LibEditModeOverride:AreLayoutsLoaded() then
    if _PCM_IsEditModeLayoutMutationBlocked() then
      return false
    end
    LibEditModeOverride:LoadLayouts()
  end

  return true
end

local function _PCM_EnsureEditableEditModeLayout()
  if not _PCM_EnsureEditModeLayout() then
    return false, false
  end

  if LibEditModeOverride:CanEditActiveLayout() then
    return true, false
  end

  local characterDB = Addon.db.char
  local layoutName = characterDB.pcmEditModeLayoutName

  if type(layoutName) == "string"
    and layoutName ~= ""
    and LibEditModeOverride:DoesLayoutExist(layoutName)
  then
    LibEditModeOverride:SetActiveLayout(layoutName)
    return true, true
  end

  local layoutNumber = 2
  layoutName = "PleebUI"

  while LibEditModeOverride:DoesLayoutExist(layoutName) do
    layoutName = "PleebUI " .. layoutNumber
    layoutNumber = layoutNumber + 1
  end

  LibEditModeOverride:AddLayout(Enum.EditModeLayoutType.Character, layoutName)
  characterDB.pcmEditModeLayoutName = layoutName
  return true, true
end

local function _PCM_GetViewerEditModeCheckbox(viewerKey, setting, allowedViewers)
  if not allowedViewers[viewerKey] then
    return false
  end

  local viewer = PCMRuntime:GetViewer(viewerKey)
  if not viewer or (viewer.IsForbidden and viewer:IsForbidden()) then
    return false
  end

  if not _PCM_EnsureEditModeLayout() then
    return false
  end

  if not LibEditModeOverride:HasEditModeSettings(viewer) then
    return false
  end

  return LibEditModeOverride:GetFrameSetting(viewer, setting) == 1
end

local function _PCM_SetViewerEditModeCheckbox(viewerKey, setting, enabled, allowedViewers)
  if not allowedViewers[viewerKey] or _PCM_IsEditModeLayoutMutationBlocked() then
    return false
  end

  local viewer = PCMRuntime:GetViewer(viewerKey)
  if not viewer or (viewer.IsForbidden and viewer:IsForbidden()) then
    return false
  end

  local editable, layoutChanged = _PCM_EnsureEditableEditModeLayout()
  if not editable then
    return false
  end

  if not LibEditModeOverride:HasEditModeSettings(viewer) then
    return false
  end

  local editModeValue = enabled == true and 1 or 0
  local currentValue = LibEditModeOverride:GetFrameSetting(viewer, setting)

  if currentValue ~= editModeValue then
    LibEditModeOverride:SetFrameSetting(viewer, setting, editModeValue)
  end

  if layoutChanged or currentValue ~= editModeValue then
    LibEditModeOverride:SaveOnly()
    PCMEditModeChangesPending = true
  end

  return true
end

function Cooldowns:FlushPendingEditModeChanges()
  if not PCMEditModeChangesPending then
    return false
  end

  local optionsWindow = Addon._OptionsWindow
  if (optionsWindow and optionsWindow:IsShown())
    or Addon:IsEditMode()
    or Addon:IsBlizzardEditModeActive()
  then
    return false
  end

  if _PCM_IsEditModeLayoutMutationBlocked() then
    return false
  end

  PCMEditModeChangesPending = false
  ns.Flags.__puiLEMApplyInProgress = true
  LibEditModeOverride:ApplyChanges()
  ns.Flags.__puiLEMApplyInProgress = nil
  return true
end

function Cooldowns:CanChangeViewerEditModeSettings()
  return not _PCM_IsEditModeLayoutMutationBlocked()
end

function Cooldowns:GetViewerTooltipsEnabled(viewerKey)
  return _PCM_GetViewerEditModeCheckbox(
    viewerKey,
    Enum.EditModeCooldownViewerSetting.ShowTooltips,
    _PCM_TOOLTIP_VIEWER_KEY_SET
  )
end

function Cooldowns:SetViewerTooltipsEnabled(viewerKey, enabled)
  return _PCM_SetViewerEditModeCheckbox(
    viewerKey,
    Enum.EditModeCooldownViewerSetting.ShowTooltips,
    enabled,
    _PCM_TOOLTIP_VIEWER_KEY_SET
  )
end

function Cooldowns:GetViewerHideWhenInactive(viewerKey)
  return _PCM_GetViewerEditModeCheckbox(
    viewerKey,
    Enum.EditModeCooldownViewerSetting.HideWhenInactive,
    _PCM_HIDE_WHEN_INACTIVE_VIEWER_KEY_SET
  )
end

function Cooldowns:SetViewerHideWhenInactive(viewerKey, enabled)
  return _PCM_SetViewerEditModeCheckbox(
    viewerKey,
    Enum.EditModeCooldownViewerSetting.HideWhenInactive,
    enabled,
    _PCM_HIDE_WHEN_INACTIVE_VIEWER_KEY_SET
  )
end


local _GetOrCreateViewerAnchorFrame
local _ForceAnchor


local function _DeactivatePCMOwnedFrames()
  for _, info in Cooldowns:IterateViewers() do
    local key = info and info.key
    local viewer = key and PCMRuntime:GetViewer(key) or nil
    local fd = PCMHooks.GetFrameData(viewer)

    local anchor = (fd and fd.anchorFrame) or (key and _G["PUI_PCM_Anchor_" .. tostring(key)]) or nil
    local proxy = (fd and fd.proxyFrame) or (key and _G["PUI_PCM_Proxy_" .. tostring(key)]) or nil
    local inCombat = InCombatLockdown()

    if proxy then
      if not inCombat and proxy.Hide then
        proxy:Hide()
      end
      if not inCombat and proxy.EnableMouse then
        proxy:EnableMouse(false)
      end
    end

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

local function _PCM_IsRefreshBlocked()
  if not _PCM_IsModuleEnabledFast() then
    return true
  end

  if _PCM_IsTransitionPending() then
    return true
  end

  if PCMHooks.IsAddonRestricted() then
    return true
  end

  return PCMHooks.InBlizzardEditMode()
end

local function _GetViewerItemFrames(viewer)
  if not viewer or (viewer.IsForbidden and viewer:IsForbidden()) then
    return PCMCoreState.Empty
  end

  local viewerKey = PCMRuntime:GetViewerKey(viewer) or _PCM_GetViewerKeyFromFrame(viewer)
  local configuredCount = viewerKey and _PCM_GetConfiguredViewerEntryCount(viewerKey) or nil
  local items = PCMRuntime:GetViewerItems(viewer)

  if viewerKey and configuredCount ~= nil and configuredCount <= 0 then
    for index = 1, #items do
      local itemFrame = items[index]
      if itemFrame and itemFrame.Hide then
        itemFrame:Hide()
      end
    end
    return PCMCoreState.Empty
  end

  return items
end


function Cooldowns:GetCustomBarSpellDropdown(kind)
  local values = {
    ["none"] = "-- Select --",
  }
  local sorting = { "none" }

  local settings = _G.CooldownViewerSettings
  local provider = settings and settings:GetDataProvider() or nil
  if not provider then
    return values, sorting
  end

  local isAura = kind == "aura"
  local entriesBySpellID = {}
  local entries = {}

  local function AddCategory(category)
    if PCMHooks.IsAddonRestricted() then
      return
    end

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
        local info = provider:GetCooldownInfoForID(cooldownID)
        if not _PCM_IsSecret(info) and type(info) == "table" then
          local isKnown = info.isKnown
          local currentCategory = info.category

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
  _PCM_MarkCountRulesDirty()
  self._RefreshViewerFontsOnly(viewerKey)

  -- Ensure it takes effect immediately.
  self:ApplyCooldownCountRulesNow()
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
  _PCM_MarkCountRulesDirty()
  self._RefreshViewerFontsOnly(viewerKey)

  -- The unified pass applies cooldown, application, charge, keybind, and duration rules.
  self:ApplyCooldownCountRulesNow()
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
  _PCM_MarkCountRulesDirty()
  self._RefreshViewerFontsOnly(viewerKey)

  -- Ensure it takes effect immediately.
  self:ApplyCooldownCountRulesNow()
end


function Cooldowns:_ApplyCooldownCountRule(itemFrame, viewerKey)
  if not itemFrame or not viewerKey then
    return
  end

  local cd = itemFrame.Cooldown
  if not (cd and cd.SetHideCountdownNumbers) then
    return
  end

  local treatAsAuraDuration = itemFrame.cooldownUseAuraDisplayTime == true
  if treatAsAuraDuration then
    if _PCM_GetDurationCountEnabledCached(viewerKey) == false then
      -- Duration numbers are disabled, so the cooldown rule owns this frame.
    elseif _ShouldUseAuraCooldownOverride(itemFrame, viewerKey) then
      -- Forced cooldown presentation also uses the cooldown rule.
    else
      return
    end
  end

  local viewerDefault = self:GetCooldownCountEnabled(viewerKey)
  local frameData = PCMHooks.PeekFrameData(itemFrame)
  local record = frameData and frameData.iconSettingsRecord or nil
  local entry = frameData and frameData.iconIdentity or nil
  local cooldownText = record and record.cooldown or nil
  local enabled = viewerDefault
  if cooldownText and cooldownText.show ~= nil then
    enabled = cooldownText.show == true
  end

  local rechargeShow = cooldownText and cooldownText.rechargeShow
  if entry and entry.hasCharges
    and frameData.iconCooldownState == "COOLDOWN"
    and rechargeShow ~= nil
  then
    enabled = rechargeShow == true
  end

  cd:SetHideCountdownNumbers(enabled ~= true)
end

function Cooldowns:_ApplyBuffCountRule(itemFrame, viewerKey)
  viewerKey = PCMHooks.GetItemViewerKey(itemFrame, viewerKey)

  local fs
  if viewerKey == "BuffIconCooldownViewer" then
    fs = itemFrame.Applications.Applications
  elseif viewerKey == "BuffBarCooldownViewer" then
    fs = itemFrame.Icon.Applications
  else
    return
  end

  fs:SetShown(self:GetBuffCountEnabled(viewerKey))
end

local function _GetChargeFontString(itemFrame)
  if not itemFrame then
    return nil
  end

  local frame = itemFrame.ChargeCount
  if not frame then
    return nil
  end

  local fs = frame.Current or frame.Count or frame.count
  if fs and fs.SetAlpha then
    return fs
  end

  return nil
end

function Cooldowns:_ApplyChargeCountRule(itemFrame, viewerKey)
  if not itemFrame or not viewerKey then
    return
  end
  -- Charge counts: Essential group viewers + Utility viewer.
  if not ((viewerKey == "UtilityCooldownViewer") or _IsEssentialViewerKey(viewerKey)) then
    return
  end

  local fs = _GetChargeFontString(itemFrame)
  if not fs then
    return
  end

  local viewerDefault = self:GetChargeCountEnabled(viewerKey)
  local frameData = PCMHooks.PeekFrameData(itemFrame)
  local record = frameData and frameData.iconSettingsRecord or nil
  local chargeText = record and record.charge or nil
  local enabled = viewerDefault
  if chargeText and chargeText.show ~= nil then
    enabled = chargeText.show == true
  end
  if enabled then
    if fs.Show then
      fs:Show()
    end
  else
    if fs.Hide then
      fs:Hide()
    end
  end

end

local function _PCM_FetchFontPath(fontKey)
  if not fontKey or fontKey == "" then
    return nil
  end

  local path = LSM:Fetch("font", fontKey)
  if path and path ~= "" then
    return path
  end

  return fontKey
end

local function _PCM_ApplyFontOptsToFontString(fs, opts)
  if not (fs and opts and fs.SetFont) then
    return
  end

  local curFont, _, curFlags = fs:GetFont()
  local face = curFont

  if opts.font then
    face = _PCM_FetchFontPath(opts.font) or curFont
  end

  local roleDefaults = Theme.ResolveIconTextRole(opts.role) or {}
  local baseSize = tonumber(opts.size or roleDefaults.size) or 12
  fs:SetFont(face, Theme.ResolveFontSize(baseSize, "cooldownManager"), opts.flags or curFlags)

  if opts.color and fs.SetTextColor then
    fs:SetTextColor(
      opts.color[1] or 1,
      opts.color[2] or 1,
      opts.color[3] or 1,
      opts.color[4] or 1
    )
  end
end

function Cooldowns._ApplyFontsToItem(itemFrame, viewerKey)
  if not itemFrame or not viewerKey then
    return
  end
  if itemFrame.IsForbidden and itemFrame:IsForbidden() then
    return
  end
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  local isEssential = type(viewerKey) == "string"
    and string.find(viewerKey, "EssentialCooldownViewer", 1, true) == 1

  if not isEssential and viewerKey ~= "UtilityCooldownViewer" then
    return
  end

  local cd = itemFrame.Cooldown
  local cooldownOpts = IconSettings:ResolveFontOptions(
    itemFrame,
    viewerKey,
    "cooldown",
    Cooldowns._ResolveFontOpts("cooldown", viewerKey)
  )

  if cd and cooldownOpts then
    IconSkin.StyleCooldownText(cd, cooldownOpts)

    local cdFS = cd.GetCountdownFontString and cd:GetCountdownFontString() or cd.text
    _PCM_ApplyFontOptsToFontString(cdFS, cooldownOpts)

    if cdFS and cdFS.ClearAllPoints and cdFS.SetPoint then
      cdFS:ClearAllPoints()
      cdFS:SetPoint("CENTER", itemFrame, "CENTER", cooldownOpts.offsetX or 0, cooldownOpts.offsetY or 0)
    end
  end

  local chargeOpts = IconSettings:ResolveFontOptions(
    itemFrame,
    viewerKey,
    "charge",
    Cooldowns._ResolveFontOpts("charge", viewerKey)
  )

  IconSkin.StyleChargeText(itemFrame, chargeOpts or { role = "charge" })

  if chargeOpts then
    local chargeFS = _GetChargeFontString(itemFrame)
    _PCM_ApplyFontOptsToFontString(chargeFS, chargeOpts)

    if chargeFS and chargeFS.ClearAllPoints and chargeFS.SetPoint then
      chargeFS:ClearAllPoints()
      chargeFS:SetPoint(
        "BOTTOMRIGHT",
        itemFrame,
        "BOTTOMRIGHT",
        -2 + (chargeOpts.offsetX or 0),
        2 + (chargeOpts.offsetY or 0)
      )
    end
  end

  Cooldowns._ApplyKeybindFontStyle(itemFrame, viewerKey)
end

function ns._PCM_ShouldSkipUnifiedItemPass(itemFrame, viewerKey, useGenGuard)
  if not useGenGuard then
    return false
  end

  local stamp = __PUI_PCM_ItemRulePassStamp[itemFrame]
  if stamp and stamp.gen == PCMCoreState.CacheGen and stamp.key == viewerKey then
    return true
  end

  if not stamp then
    stamp = {}
    __PUI_PCM_ItemRulePassStamp[itemFrame] = stamp
  end

  stamp.gen = PCMCoreState.CacheGen
  stamp.key = viewerKey
  return false
end

function ns._PCM_ApplyUnifiedItemPass(itemFrame, viewerKey, applyFonts, useGenGuard)
  if not itemFrame or not viewerKey or _PCM_IsRefreshBlocked() then
    return
  end

  if itemFrame.IsForbidden and itemFrame:IsForbidden() then
    return
  end

  if ns._PCM_ShouldSkipUnifiedItemPass(itemFrame, viewerKey, useGenGuard) then
    return
  end

  if applyFonts ~= false then
    Cooldowns._ApplyFontsToItem(itemFrame, viewerKey)
  end

  Cooldowns:_ApplyCooldownCountRule(itemFrame, viewerKey)
  Cooldowns:_ApplyBuffCountRule(itemFrame, viewerKey)
  Cooldowns:_ApplyChargeCountRule(itemFrame, viewerKey)
  Cooldowns:_ApplyKeybindTextRule(itemFrame, viewerKey)
  Cooldowns:_ApplyDurationCountRule(itemFrame, viewerKey)
end

function ns._PCM_RunUnifiedViewerItemPass(viewerKey, applyFonts, useGenGuard)
  if _PCM_IsRefreshBlocked() then
    return
  end

  if viewerKey then
    local frame = Cooldowns:GetViewerFrame(viewerKey)
    if frame and not (frame.IsForbidden and frame:IsForbidden()) then
      local items = _GetViewerItemFrames(frame) or PCMCoreState.Empty
      for _, itemFrame in ipairs(items) do
        if itemFrame then
          ns._PCM_ApplyUnifiedItemPass(itemFrame, viewerKey, applyFonts, useGenGuard)
        end
      end
    end
  else
    for _, info in Cooldowns:IterateViewers() do
      local key = info and info.key
      local frame = key and PCMRuntime:GetViewer(key) or nil
      if key and frame and not (frame.IsForbidden and frame:IsForbidden()) then
        local items = _GetViewerItemFrames(frame) or PCMCoreState.Empty
        for _, itemFrame in ipairs(items) do
          if itemFrame then
            ns._PCM_ApplyUnifiedItemPass(itemFrame, key, applyFonts, useGenGuard)
          end
        end
      end
    end
  end

end

function Cooldowns:ApplyCooldownCountRulesNow()
  if not self or not _PCM_IsModuleEnabledFast() then
    return
  end

  ns._PCM_RunUnifiedViewerItemPass(nil, false, false)
end

_PCM_MarkCountRulesDirty = function()
  PCMCoreState.CountRulesDirty = true
  PCMCoreState.CacheGen = PCMCoreState.CacheGen + 1
end

function Cooldowns:_OnViewersRefreshedForCountRules()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  if not PCMCoreState.CountRulesDirty then
    return
  end

  PCMCoreState.CountRulesDirty = false
  ns._PCM_RunUnifiedViewerItemPass(nil, true, true)
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

local function _PCM_GetSwipeFlagsCached(viewerKey)
  if not viewerKey then
    return nil
  end

  -- Per-viewerKey cache. These values only change when the user edits settings,
  -- at which point _PCM_MarkCountRulesDirty() clears PCMCoreState.SwipeFlagCache.
  local cached = PCMCoreState.SwipeFlagCache[viewerKey]
  if cached then
    return cached
  end

  local entry = ns.PCM_DBExports.GetViewerSwipeDB(viewerKey)
  if not entry then
    return nil
  end

  local flags = {
    gcdOn              = (entry.gcd      ~= false),
    cooldownOn         = (entry.cooldown ~= false),
    durationOn         = (entry.duration ~= false),
    durationCountOn    = _PCM_GetDurationCountEnabledCached(viewerKey),
    forceCooldownSwipe = (entry.forceCooldownSwipe == true),
    drawEdge           = (entry.drawEdge ~= false),
  }

  PCMCoreState.SwipeFlagCache[viewerKey] = flags
  return flags
end

_ShouldUseAuraCooldownOverride = function(itemFrame, viewerKey)
  if not itemFrame or not viewerKey then
    return false
  end

  if _PCM_IsEquipSlotCooldownItem(itemFrame) then
    return false
  end

  local frameData = PCMHooks.PeekFrameData(itemFrame)
  local record = frameData and frameData.iconSettingsRecord or nil
  local swipe = record and record.swipe
  if swipe and swipe.source == "COOLDOWN" then
    return true
  elseif swipe and swipe.source == "AUTOMATIC" then
    return false
  end

  local flags = _PCM_GetSwipeFlagsCached(viewerKey)
  if not flags then
    return false
  end

  if not (flags.gcdOn or flags.cooldownOn) then
    return false
  end

  if flags.forceCooldownSwipe == true then
    return true
  end

  if flags.durationOn or flags.durationCountOn then
    return false
  end

  return itemFrame.cooldownUseAuraDisplayTime == true
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
  _PCM_MarkCountRulesDirty()

  self:_RequestViewerRefresh("icons")

  ns._PCM_RunUnifiedViewerItemPass(nil, false, false)
end

function Cooldowns:GetDurationCountEnabled(viewerKey)
  return _PCM_GetDurationCountEnabledCached(viewerKey)
end


-- Runtime: apply duration-count visibility
function Cooldowns:_ApplyDurationCountRule(itemFrame, viewerKey)
  if not itemFrame or not viewerKey or itemFrame.cooldownUseAuraDisplayTime ~= true then
    return false
  end

  local cd = itemFrame.Cooldown
  if not (cd and cd.SetHideCountdownNumbers) then
    return false
  end

  if _ShouldUseAuraCooldownOverride(itemFrame, viewerKey) then
    return false
  end

  local frameData = PCMHooks.PeekFrameData(itemFrame)
  local record = frameData and frameData.iconSettingsRecord or nil
  local cooldownText = record and record.cooldown or nil
  local enabled = _PCM_GetDurationCountEnabledCached(viewerKey)
  if cooldownText and cooldownText.show ~= nil then
    enabled = cooldownText.show == true
  end

  cd:SetHideCountdownNumbers(enabled ~= true)

  if enabled then
    local fs
    if cd.GetCountdownFontString then
      fs = cd:GetCountdownFontString()
    elseif cd.Timer then
      fs = cd.Timer
    end

    if fs and fs.SetTextColor and not (cooldownText and cooldownText.color) then
      fs:SetTextColor(0, 1, 0, 1)
    end
  end

  return true
end

local function _PCM_ApplyActiveCountRule(itemFrame, viewerKey)
  if Cooldowns:_ApplyDurationCountRule(itemFrame, viewerKey) then
    return
  end
  Cooldowns:_ApplyCooldownCountRule(itemFrame, viewerKey)
end
local function _ResolveViewerKeyFromItem(itemFrame)
  if not itemFrame then
    return nil
  end

  local vk = PCMHooks.GetItemViewerKey(itemFrame, nil)
  if vk then
    return vk
  end

  local vf = itemFrame.viewerFrame
  if not vf and itemFrame.GetParent then
    vf = itemFrame:GetParent()
  end
  if not vf then
    return nil
  end

  local cachedVK = PCMFrameState.ViewerFrameKey[vf]
  if cachedVK ~= nil then
    if cachedVK ~= false then
      PCMHooks.SetItemViewerKey(itemFrame, cachedVK)
      return cachedVK
    end
    -- Explicitly marked as "not a viewer" parent, do not rescan.
    return nil
  end

  for _, info in Cooldowns:IterateViewers() do
    local f = PCMRuntime:GetViewer(info.key)
    if f then
      PCMFrameState.ViewerFrameKey[f] = info.key
    end
    if f == vf then
      PCMFrameState.ViewerFrameKey[vf] = info.key
      PCMHooks.SetItemViewerKey(itemFrame, info.key)
      return info.key
    end
  end

  -- Parent did not match any known viewer; remember this so we do not
  -- pay the IterateViewers cost again for the same frame.
  PCMFrameState.ViewerFrameKey[vf] = false

  return nil
end


local function _ApplyBorderToFrame(borderFrame, borderCfg, viewerKey, itemFrame)
  if not borderFrame or not viewerKey then
    return
  end

  if not _PCM_IsModuleEnabledFast() then
    return
  end

  local cfg = Cooldowns.GetBorderConfig(viewerKey)
  if not cfg then
    return
  end

  local thickness = Cooldowns._ClampBorderThickness(cfg.thickness == nil and 1 or cfg.thickness)

  IconSkin.ApplyBorder(borderFrame, {
    enabled = cfg.enabled ~= false and thickness > 0,
    thickness = thickness,
    color = cfg.color,
  })
end

local function _ApplyBorderInsets(itemFrame, viewerKey, iconContainer, icon, cooldownFrame)
  if not itemFrame then
    return
  end

  if not _PCM_IsModuleEnabledFast() then
    return
  end

  local parent = iconContainer or itemFrame

  if icon and icon.ClearAllPoints and icon.SetAllPoints and parent then
    icon:ClearAllPoints()
    icon:SetAllPoints(parent)
  end

  if cooldownFrame and cooldownFrame.ClearAllPoints and cooldownFrame.SetAllPoints and parent then
    cooldownFrame:ClearAllPoints()
    cooldownFrame:SetAllPoints(parent)
  end
end

local PCMIconRuntimeState = {
  viewerSwipeOptions = {},
}

local PCM_ICON_SETTINGS_VIEWERS = {
  "EssentialCooldownViewer",
  "UtilityCooldownViewer",
  "BuffIconCooldownViewer",
}

function Cooldowns:InvalidateNativeIconViewerCache(viewerKey)
  if viewerKey then
    PCMIconRuntimeState.viewerSwipeOptions[viewerKey] = nil
  else
    wipe(PCMIconRuntimeState.viewerSwipeOptions)
  end
end

local function _PCM_GetViewerSwipeOptions(viewerKey)
  local options = PCMIconRuntimeState.viewerSwipeOptions[viewerKey]
  if options then
    return options
  end

  local cfg = PCM_DB.GetViewerSwipeDB(viewerKey)
  options = {
    show = true,
    source = cfg.forceCooldownSwipe == true and "COOLDOWN" or "AUTOMATIC",
    color = cfg.swipeColor,
    drawEdge = cfg.drawEdge ~= false,
    reverse = false,
    showGCD = cfg.gcd ~= false,
    showCooldown = cfg.cooldown ~= false,
    showDuration = cfg.duration ~= false,
  }
  PCMIconRuntimeState.viewerSwipeOptions[viewerKey] = options
  return options
end

local function _PCM_ApplyForcedCooldownSource(itemFrame, frameData)
  if not itemFrame or not frameData or frameData.iconSettingsApplyingForcedCooldown == true then
    return
  end

  local entry = frameData.iconIdentity
  local cooldownFrame = itemFrame.Cooldown
  if not entry or not cooldownFrame then
    return
  end

  local duration
  if entry.hasCharges then
    duration = C_Spell.GetSpellChargeDuration(entry.chargeSpellID)
  else
    duration = C_Spell.GetSpellCooldownDuration(entry.cooldownSpellID, true)
  end

  frameData.iconSettingsApplyingForcedCooldown = true
  cooldownFrame:SetUseAuraDisplayTime(false)
  cooldownFrame:SetCooldownFromDurationObject(duration, true)
  frameData.iconSettingsApplyingForcedCooldown = nil
end

local function _PCM_ApplyNativeIconSettings(itemFrame, viewerKey, frameData)
  if not itemFrame or not viewerKey then
    return
  end

  frameData = frameData or PCMHooks.PeekFrameData(itemFrame)
  local entry = frameData and frameData.iconIdentity or nil
  local cooldownFrame = itemFrame.Cooldown
  if not entry or not cooldownFrame then
    return
  end

  local record = frameData.iconSettingsRecord
  local swipe = record and record.swipe or nil
  local viewerOptions = _PCM_GetViewerSwipeOptions(viewerKey)
  local source = swipe and swipe.source or viewerOptions.source or "AUTOMATIC"

  if source == "COOLDOWN" then
    _PCM_ApplyForcedCooldownSource(itemFrame, frameData)
  end

  local viewerShow
  if source == "COOLDOWN" then
    viewerShow = viewerOptions.showCooldown
  elseif frameData.iconIsOnGCD == true then
    viewerShow = viewerOptions.showGCD
  elseif itemFrame.cooldownUseAuraDisplayTime == true then
    viewerShow = viewerOptions.showDuration
  else
    viewerShow = viewerOptions.showCooldown
  end

  local showOverride
  local showGCDOverride
  if swipe then
    showOverride = swipe.show
    showGCDOverride = swipe.showGCD
  end
  if frameData.iconIsOnGCD == true and showGCDOverride ~= nil then
    showOverride = showGCDOverride
  end
  local showSwipe = showOverride == nil and viewerShow or showOverride == true

  local drawEdge = swipe and swipe.drawEdge
  if drawEdge == nil then
    drawEdge = viewerOptions.drawEdge
  end
  local rechargeEdgeOverride = swipe and swipe.rechargeEdge
  if entry.hasCharges
    and frameData.iconCooldownState == "COOLDOWN"
    and rechargeEdgeOverride ~= nil
  then
    drawEdge = rechargeEdgeOverride == true
  end

  local reverse = swipe and swipe.reverse
  if reverse == nil then
    reverse = viewerOptions.reverse
  end

  cooldownFrame:SetDrawSwipe(showSwipe)
  cooldownFrame:SetDrawEdge(showSwipe and drawEdge ~= false)
  cooldownFrame:SetReverse(reverse == true)

  local color = swipe and swipe.color or viewerOptions.color
  if color then
    cooldownFrame:SetSwipeColor(
      color[1] or 0,
      color[2] or 0,
      color[3] or 0,
      color[4] == nil and 0.8 or color[4]
    )
  end
end

local function _PCM_UpdateBoundIconRuntimeFlags(frameData, record, entry, viewerOptions)
  local swipe = record and record.swipe or nil
  local cooldown = record and record.cooldown or nil
  local appearance = record and record.appearance or nil
  local cooldownFamily = entry and entry.settingsFamily == "cooldown"
  local viewerKey = frameData and frameData.viewerKey or nil

  local stateAppearance = cooldownFamily and appearance and (
    appearance.readyAlpha ~= nil
    or appearance.cooldownAlpha ~= nil
    or appearance.readySaturation ~= nil
    or appearance.cooldownSaturation ~= nil
    or appearance.readyGlowStyle ~= nil
    or appearance.cooldownGlowStyle ~= nil
    or appearance.maxChargeGlowStyle ~= nil
  )

  local overrideNeedsState = record ~= nil and (
    stateAppearance == true
    or (swipe and (swipe.showGCD ~= nil or swipe.rechargeEdge ~= nil))
    or (cooldown and cooldown.rechargeShow ~= nil)
  )
  local viewerNeedsState = cooldownFamily
    and viewerOptions
    and viewerOptions.showGCD ~= viewerOptions.showCooldown

  local source = swipe and swipe.source or viewerOptions and viewerOptions.source or "AUTOMATIC"
  frameData.iconSettingsForcesCooldownSource = cooldownFamily and source == "COOLDOWN" or nil
  local needsSwipeRefresh = cooldownFamily and (
    viewerOptions and (
      viewerOptions.showGCD ~= true
      or viewerOptions.showCooldown ~= true
      or viewerOptions.showDuration ~= true
    )
    or swipe and (
      swipe.show ~= nil
      or swipe.showGCD ~= nil
      or swipe.rechargeEdge ~= nil
    )
  )

  local cooldownCountEnabled = viewerKey and Cooldowns:GetCooldownCountEnabled(viewerKey) or true
  local durationCountEnabled = viewerKey and _PCM_GetDurationCountEnabledCached(viewerKey) or true
  if cooldown and cooldown.show ~= nil then
    cooldownCountEnabled = cooldown.show == true
    durationCountEnabled = cooldown.show == true
  end

  local charge = record and record.charge or nil
  local chargeCountEnabled = viewerKey and Cooldowns:GetChargeCountEnabled(viewerKey) or true
  if charge and charge.show ~= nil then
    chargeCountEnabled = charge.show == true
  end

  local needsCountModeRefresh = cooldownFamily and (
    cooldownCountEnabled ~= durationCountEnabled
    or cooldown and cooldown.rechargeShow ~= nil
  )
  local needsChargeCountRefresh = cooldownFamily
    and entry and entry.hasCharges == true
    and chargeCountEnabled ~= true

  frameData.iconSettingsNeedsCooldownState = overrideNeedsState or viewerNeedsState or nil
  frameData.iconSettingsNeedsChargeState = entry and entry.hasCharges == true
    and overrideNeedsState
    or nil
  frameData.iconSettingsNeedsTextureRefresh = appearance and appearance.texture ~= nil or nil
  frameData.iconSettingsNeedsSwipeRefresh = needsSwipeRefresh or nil
  frameData.iconSettingsNeedsCountModeRefresh = needsCountModeRefresh or nil
  frameData.iconSettingsNeedsChargeCountRefresh = needsChargeCountRefresh or nil
  frameData.iconSettingsNeedsCooldownRefreshHook = cooldownFamily and (
    frameData.iconSettingsNeedsCooldownState == true
    or needsSwipeRefresh == true
    or needsCountModeRefresh == true
  ) or nil
  frameData.iconSettingsNeedsChargeRefreshHook = cooldownFamily
    and entry and entry.hasCharges == true
    and (
      frameData.iconSettingsNeedsChargeState == true
      or needsChargeCountRefresh == true
    )
    or nil
end

local function _PCM_HookNativeIconRefresh(itemFrame, frameData)
  if not frameData then
    return
  end

  local entry = frameData.iconIdentity
  if entry and entry.settingsFamily == "cooldown" then
    if frameData.iconSettingsForcesCooldownSource == true
      and frameData.iconForcedCooldownSourceHooksInstalled ~= true
    then
      local cooldownFrame = itemFrame.Cooldown
      local function ReapplyForcedCooldownSource()
        local viewerKey = frameData.viewerKey
        local currentEntry = frameData.iconIdentity
        if frameData.iconSettingsApplyingForcedCooldown == true
          or frameData.iconSettingsForcesCooldownSource ~= true
          or not viewerKey
          or not currentEntry
          or currentEntry.settingsFamily ~= "cooldown"
          or _PCM_IsRefreshBlocked()
        then
          return
        end

        _PCM_ApplyForcedCooldownSource(itemFrame, frameData)
        _PCM_ApplyActiveCountRule(itemFrame, viewerKey)
      end

      PCMHooks.HookMethod(
        cooldownFrame,
        "SetCooldown",
        "PCM_ForcedCooldownSource",
        ReapplyForcedCooldownSource
      )
      PCMHooks.HookMethod(
        cooldownFrame,
        "SetCooldownFromDurationObject",
        "PCM_ForcedCooldownSource",
        ReapplyForcedCooldownSource
      )
      PCMHooks.HookMethod(
        cooldownFrame,
        "SetUseAuraDisplayTime",
        "PCM_ForcedCooldownSource",
        ReapplyForcedCooldownSource
      )
      PCMHooks.HookMethod(
        cooldownFrame,
        "Clear",
        "PCM_ForcedCooldownSource",
        ReapplyForcedCooldownSource
      )
      frameData.iconForcedCooldownSourceHooksInstalled = true
    end

    if frameData.iconSettingsNeedsCooldownRefreshHook == true
      and frameData.iconCooldownRefreshHookInstalled ~= true
    then
      PCMHooks.HookMethod(
        itemFrame,
        "RefreshSpellCooldownInfo",
        "PCM_NativeIconCooldown",
        function(frame)
          local viewerKey = frameData.viewerKey
          local currentEntry = frameData.iconIdentity
          if not viewerKey or not currentEntry or currentEntry.settingsFamily ~= "cooldown"
            or frameData.iconSettingsNeedsCooldownRefreshHook ~= true
          then
            return
          end

          if frameData.iconSettingsNeedsCooldownState == true then
            _PCM_UpdateIconCooldownState(frame, viewerKey, "SPELL_UPDATE_COOLDOWN", frameData)
          elseif frameData.iconSettingsNeedsSwipeRefresh == true then
            _PCM_ApplyNativeIconSettings(frame, viewerKey, frameData)
          end

          if frameData.iconSettingsNeedsCountModeRefresh == true then
            _PCM_ApplyActiveCountRule(frame, viewerKey)
          end
        end
      )
      frameData.iconCooldownRefreshHookInstalled = true
    end

    if entry.hasCharges == true
      and frameData.iconSettingsNeedsChargeRefreshHook == true
      and frameData.iconChargeRefreshHookInstalled ~= true
    then
      PCMHooks.HookMethod(
        itemFrame,
        "RefreshSpellChargeInfo",
        "PCM_NativeIconCharge",
        function(frame)
          local viewerKey = frameData.viewerKey
          local currentEntry = frameData.iconIdentity
          if not viewerKey or not currentEntry or currentEntry.settingsFamily ~= "cooldown"
            or currentEntry.hasCharges ~= true
            or frameData.iconSettingsNeedsChargeRefreshHook ~= true
          then
            return
          end

          if frameData.iconSettingsNeedsChargeState == true then
            _PCM_UpdateIconCooldownState(frame, viewerKey, "SPELL_UPDATE_CHARGES", frameData)
          end
          if frameData.iconSettingsNeedsChargeCountRefresh == true then
            Cooldowns:_ApplyChargeCountRule(frame, viewerKey)
          end
        end
      )
      frameData.iconChargeRefreshHookInstalled = true
    end
  end

  if frameData.iconSettingsNeedsTextureRefresh == true
    and frameData.iconTextureRefreshHookInstalled ~= true
  then
    PCMHooks.HookMethod(
      itemFrame,
      "RefreshSpellTexture",
      "PCM_IconOverrideTexture",
      function(frame)
        if frameData.iconSettingsNeedsTextureRefresh ~= true or not frameData.iconSettingsRecord then
          return
        end
        _PCM_ApplyIconAppearance(frame, frameData.viewerKey, frameData)
      end
    )
    frameData.iconTextureRefreshHookInstalled = true
  end
end

local function _PCM_BindNativeIconSettings(itemFrame, viewerKey)
  local record, entry, frameData = IconSettings:GetRecordForItem(itemFrame, viewerKey)
  local viewerOptions = _PCM_GetViewerSwipeOptions(viewerKey)
  local settingsGeneration = IconSettings:GetSettingsGeneration()

  if frameData.iconRuntimeFlagsGeneration ~= settingsGeneration
    or frameData.iconRuntimeFlagsViewerKey ~= viewerKey
    or frameData.iconRuntimeFlagsRecord ~= record
    or frameData.iconRuntimeFlagsEntry ~= entry
    or frameData.iconRuntimeFlagsViewerOptions ~= viewerOptions
  then
    _PCM_UpdateBoundIconRuntimeFlags(frameData, record, entry, viewerOptions)
    frameData.iconRuntimeFlagsGeneration = settingsGeneration
    frameData.iconRuntimeFlagsViewerKey = viewerKey
    frameData.iconRuntimeFlagsRecord = record
    frameData.iconRuntimeFlagsEntry = entry
    frameData.iconRuntimeFlagsViewerOptions = viewerOptions
  end

  _PCM_HookNativeIconRefresh(itemFrame, frameData)
  return frameData, record, entry
end

local function _PCM_GetItemIconSize(itemFrame, viewerKey)
  local iconSize
  if Cooldowns._GetWidthModeForViewer(viewerKey) == "fixed" then
    iconSize = itemFrame:GetWidth()
    if (tonumber(iconSize) or 0) <= 0 then
      iconSize = itemFrame:GetHeight()
    end
  end

  if (tonumber(iconSize) or 0) <= 0 then
    iconSize = Cooldowns._GetIconSizeForViewer(viewerKey)
  end

  if (tonumber(iconSize) or 0) <= 0 then
    iconSize = IconSkin:GetGlobalIconSize()
  end

  if (tonumber(iconSize) or 0) <= 0 then
    iconSize = 24
  end

  return RoundPixel(iconSize)
end

local function _PCM_ApplyStaticItemPresentation(itemFrame, viewerKey, frameData, regions)
  if frameData.iconStaticPresentationGeneration == PCMCoreState.StaticPresentationGeneration
    and frameData.iconStaticPresentationViewerKey == viewerKey
  then
    frameData.sizeW = frameData.iconStaticSizeW
    frameData.sizeH = frameData.iconStaticSizeH
    return
  end

  local icon = regions.icon
  local iconContainer = regions.iconContainer
  local borderFrame = iconContainer or itemFrame
  local cooldownFrame = regions.cd
  local iconSize = _PCM_GetItemIconSize(itemFrame, viewerKey)

  if iconSize and iconSize > 0 then
    _ApplyIconSizeToItemFrame(itemFrame, viewerKey, iconSize)

    if icon and icon.SetSize then
      icon:SetSize(iconSize, iconSize)
    end
  end

  if iconContainer and iconContainer ~= itemFrame and iconContainer.ClearAllPoints and iconContainer.SetPoint then
    iconContainer:ClearAllPoints()
    iconContainer:SetPoint("TOPLEFT", itemFrame, "TOPLEFT", 0, 0)
    iconContainer:SetPoint("BOTTOMRIGHT", itemFrame, "BOTTOMRIGHT", 0, 0)
  end

  IconSkin.StripCooldownManagerOverlay(itemFrame)

  if cooldownFrame then
    IconSkin.SquareCooldown(cooldownFrame)
    if cooldownFrame.SetSwipeTexture then
      cooldownFrame:SetSwipeTexture("Interface/Buttons/WHITE8X8")
    end
  end

  if icon then
    local borderConfig = Cooldowns.GetBorderConfig(viewerKey) or {}
    local borderThickness = Cooldowns._ClampBorderThickness(
      borderConfig.thickness == nil and 1 or borderConfig.thickness
    )
    local presentation = PCMPresentation.BindViewerIcon(
      itemFrame,
      regions,
      borderFrame
    )

    Presentation.Apply("PCMIcon", presentation, {
      size = iconSize,
      inset = 0,
      manageFrameSize = false,
      borderSize = borderConfig.enabled ~= false and borderThickness or 0,
      borderColor = borderConfig.color,
      skipVisibility = true,
    })
  end

  frameData.iconStaticPresentationGeneration = PCMCoreState.StaticPresentationGeneration
  frameData.iconStaticPresentationViewerKey = viewerKey
end

local function _PCM_RefreshItemBinding(itemFrame, viewerKey, regions)
  local icon = regions.icon
  local iconContainer = regions.iconContainer
  local borderFrame = iconContainer or itemFrame
  local cooldownFrame = regions.cd
  local parent = iconContainer or itemFrame
  local hasLayoutIndex = _PCM_ItemHasLayoutIndex(itemFrame)
  local hasRenderableContent = _PCM_ItemHasRenderableContent(itemFrame)

  if not hasLayoutIndex or not hasRenderableContent then
    if cooldownFrame and cooldownFrame.Hide then
      cooldownFrame:Hide()
    end

    if icon and icon.Hide then
      icon:Hide()
    end

    if itemFrame and itemFrame.SetShown then
      itemFrame:SetShown(false)
    elseif itemFrame and itemFrame.Hide then
      itemFrame:Hide()
    end
    return
  end

  if borderFrame and borderFrame ~= itemFrame then
    if borderFrame.Show and not (borderFrame.IsShown and borderFrame:IsShown()) then
      borderFrame:Show()
    end
  end

  if icon then
    if icon.SetVertexColor then
      icon:SetVertexColor(1, 1, 1, 1)
    end
    if icon.Show and not (icon.IsShown and icon:IsShown()) then
      icon:Show()
    end
    _PUI_SetAllPointsStamped(icon, parent)
  end

  if cooldownFrame then
    if cooldownFrame.Show and not (cooldownFrame.IsShown and cooldownFrame:IsShown()) then
      cooldownFrame:Show()
    end
    _PUI_SetAllPointsStamped(cooldownFrame, parent)
  end

  Cooldowns:_ApplyEffectsToButton(itemFrame, viewerKey)

  if cooldownFrame then
    _PCM_ApplyNativeIconSettings(itemFrame, viewerKey)
  end

  _PCM_ApplyIconAppearance(itemFrame, viewerKey)
  ns._PCM_ApplyUnifiedItemPass(itemFrame, viewerKey, true, false)
end

local function _ReskinItemFrame(itemFrame, viewerKey)
  if _PCM_IsRefreshBlocked() then
    return
  end

  if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then
    return
  end

  viewerKey = viewerKey or _ResolveViewerKeyFromItem(itemFrame)
  if not viewerKey then
    return
  end

  PCMHooks.SetItemViewerKey(itemFrame, viewerKey)
  PCMHooks.HookIconFrame(itemFrame, viewerKey)

  local frameData, record = _PCM_BindNativeIconSettings(itemFrame, viewerKey)
  if not record and (
    frameData.iconStateHidden == true
    or frameData.iconAppliedAlpha ~= nil
    or frameData.iconAppliedSaturation ~= nil
    or frameData.iconSettingsGlowStyle ~= nil
    or frameData.iconCustomTextureApplied ~= nil
  ) then
    _PCM_ClearNativeIconPresentation(itemFrame, viewerKey)
  end

  local regions = IconSkin.ResolveCooldownViewerRegions(itemFrame)
  _PCM_ApplyStaticItemPresentation(itemFrame, viewerKey, frameData, regions)
  _PCM_RefreshItemBinding(itemFrame, viewerKey, regions)
end




_ApplyIconSizeToItemFrame = function(itemFrame, viewerKey, iconSize)
  if not itemFrame or not iconSize or iconSize <= 0 then
    return
  end
  if itemFrame.IsForbidden and itemFrame:IsForbidden() then
    return
  end
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  if itemFrame.SetScale then
    itemFrame:SetScale(1)
  end

  if itemFrame.SetSize then
    itemFrame:SetSize(iconSize, iconSize)
  end

  local fd = PCMHooks.GetFrameData(itemFrame)
  fd.sizeW = iconSize
  fd.sizeH = iconSize
  fd.iconStaticSizeW = iconSize
  fd.iconStaticSizeH = iconSize


  local iconContainer = itemFrame
  local icon          = (itemFrame.Icon and itemFrame.Icon.SetTexture) and itemFrame.Icon or nil

  if iconContainer and iconContainer.SetSize then
    if iconContainer.SetScale then
      iconContainer:SetScale(1)
    end
    iconContainer:SetSize(iconSize, iconSize)
  elseif icon and icon.SetSize then
    icon:SetSize(iconSize, iconSize)
  end


  -- Keep container tightly bound to the button so borders/swipes stay aligned.
  if iconContainer and iconContainer ~= itemFrame and iconContainer.ClearAllPoints and iconContainer.SetPoint then
    iconContainer:ClearAllPoints()
    iconContainer:SetPoint("TOPLEFT", itemFrame, "TOPLEFT", 0, 0)
    iconContainer:SetPoint("BOTTOMRIGHT", itemFrame, "BOTTOMRIGHT", 0, 0)
  end
end

-- Per-icon point enforcement (only snap when Blizzard tries to move icons)
local _puiIconPointHooked  = setmetatable({}, { __mode = "k" })
local _puiIconApplyingPt   = setmetatable({}, { __mode = "k" })


local function _PUI_SetIconDesired(icon, parent, x, y, storeOnly)
  if not icon then return end

  local fd = PCMHooks.GetFrameData(icon)
  fd.anchor = parent
  fd.posX = x
  fd.posY = y

  -- In store-only mode, never touch points here.
  if storeOnly then
    return
  end

  -- Initial/explicit apply path (guarded so our own SetPoint doesn't recurse)
  if icon.ClearAllPoints and icon.SetPoint and not _puiIconApplyingPt[icon] then
    _puiIconApplyingPt[icon] = true
    _PUI_SetPointStamped(icon, "CENTER", parent, "CENTER", x, y)
    _puiIconApplyingPt[icon] = nil
  end
end

local function _PUI_SetIconInProxy(icon, layoutFrame, key, x, y, storeOnly)
  if not icon or not layoutFrame then
    return
  end



  local parent = layoutFrame

  local layoutData = PCMHooks.GetFrameData(layoutFrame)
  if layoutData.proxyFrame then
    parent = layoutData.proxyFrame
  end

  if storeOnly then
    _PUI_SetIconDesired(icon, parent, x, y, true)
    return
  end

  if icon.Show and not (icon.IsShown and icon:IsShown()) then
    icon:Show()
  end

  local fd = PCMHooks.GetFrameData(icon)
  local wasParked = fd.parked == true
  if icon.SetAlpha and wasParked then
    local targetAlpha = fd.iconAppliedAlpha
    if targetAlpha == nil then
      targetAlpha = 1
    end

    fd.locking = true
    icon:SetAlpha(targetAlpha)
    fd.locking = false
  end
  fd.parked = nil

  _PUI_SetIconDesired(icon, parent, x, y, false)
end

local function _LayoutTwoRowWrap(frame, icons, key, count, firstRowLimit, iconSize, spacing, wMode, fixedW, borderPad, rowGrowth, storeOnly_)
  local row1Count = tonumber(firstRowLimit) or 0
  if row1Count < 1 then
    row1Count = math.max(count, 0)
  end

  if row1Count > 40 then row1Count = 40 end
  if count > 0 and row1Count > count then
    row1Count = count
  end

  local row1PlaceCount = math.min(row1Count, math.max(count, 0))
  local row2Count = math.max(count - row1PlaceCount, 0)

  local row1IconSize = iconSize
  if wMode == "fixed" and fixedW > 0 then
    local fittedColumns = math.max(row1Count, 1)
    row1IconSize = (
      fixedW - ((fittedColumns - 1) * spacing)
    ) / fittedColumns

    local onePixel = ns.Pixel.GetOnePixel()
    row1IconSize = math.floor(row1IconSize / onePixel) * onePixel
  else
    row1IconSize = RoundPixel(row1IconSize)
  end

  if row1IconSize < 1 then row1IconSize = 1 end
  if wMode ~= "fixed" and row1IconSize > 96 then
    row1IconSize = 96
  end

  local row2IconSize = row1IconSize
  if row2Count > 0 and wMode == "fixed" and fixedW > 0 then
    local fittedRow2Size = (
      fixedW - ((row2Count - 1) * spacing)
    ) / row2Count

    row2IconSize = math.min(row1IconSize, fittedRow2Size)

    local onePixel = ns.Pixel.GetOnePixel()
    row2IconSize = math.floor(row2IconSize / onePixel) * onePixel
    if row2IconSize < 1 then row2IconSize = 1 end
  end

  for index, icon in ipairs(icons) do
    local fittedSize = index <= row1PlaceCount and row1IconSize or row2IconSize
    _ApplyIconSizeToItemFrame(icon, key, fittedSize)
  end

  borderPad = tonumber(borderPad) or 0
  if borderPad < 0 then borderPad = 0 end
  borderPad = RoundPixel(borderPad)

  local row1W = (row1PlaceCount * row1IconSize)
    + ((math.max(row1PlaceCount, 1) - 1) * spacing)
  local row2W = row2Count > 0
    and ((row2Count * row2IconSize) + ((row2Count - 1) * spacing))
    or 0

  local containerW
  if wMode == "fixed" and fixedW > 0 then
    containerW = RoundPixel(fixedW)
  else
    containerW = RoundPixel(math.max(row1W, row2W, row1IconSize))
  end

  local containerH = row1IconSize
  if row2Count > 0 then
    containerH = containerH + spacing + row2IconSize
  end

  if borderPad ~= 0 then
    containerW = containerW + borderPad
    containerH = containerH + borderPad
  end

  local row1Y = (containerH / 2) - (row1IconSize / 2)
  local row2Y = row1Y - (row1IconSize / 2) - spacing - (row2IconSize / 2)

  if row2Count > 0 and rowGrowth == "UP" then
    row1Y = -(containerH / 2) + (row1IconSize / 2)
    row2Y = row1Y + (row1IconSize / 2) + spacing + (row2IconSize / 2)
  end

  local row1StartX = -row1W / 2 + (row1IconSize / 2)
  for column = 1, row1PlaceCount do
    local icon = icons[column]
    if icon and icon.ClearAllPoints and icon.SetPoint then
      local x = row1StartX + (column - 1) * (row1IconSize + spacing)
      _PUI_SetIconInProxy(
        icon,
        frame,
        key,
        RoundPixel(x),
        RoundPixel(row1Y),
        storeOnly_
      )
    end
  end

  if row2Count > 0 then
    local row2StartX = -row2W / 2 + (row2IconSize / 2)
    local firstRow2Index = row1PlaceCount + 1

    for column = 1, row2Count do
      local icon = icons[firstRow2Index + column - 1]
      if icon and icon.ClearAllPoints and icon.SetPoint then
        local x = row2StartX + (column - 1) * (row2IconSize + spacing)
        _PUI_SetIconInProxy(
          icon,
          frame,
          key,
          RoundPixel(x),
          RoundPixel(row2Y),
          storeOnly_
        )
      end
    end
  end

  if not storeOnly_ then
    local fd = PCMHooks.GetFrameData(frame)
    local proxyFrame = fd.proxyFrame
    if proxyFrame and proxyFrame.SetSize and not InCombatLockdown() then
      proxyFrame:SetSize(containerW, containerH)
    end

    local anchorFrame = fd.anchorFrame or frame
    if anchorFrame and anchorFrame.SetSize and not InCombatLockdown() then
      anchorFrame:SetSize(containerW, containerH)
    end
  end

  return containerW, containerH
end

local __PUI_PCM_ViewerIconCache = setmetatable({}, { __mode = "k" })
local __PUI_PCM_ViewerSig = setmetatable({}, { __mode = "k" })
local __PUI_PCM_ItemObjectID = setmetatable({}, { __mode = "k" })
local __PUI_PCM_ItemObjectIDSeed = 0

local function _PCM_GetStableItemObjectID(itemFrame)
  local id = __PUI_PCM_ItemObjectID[itemFrame]
  if id then
    return id
  end

  __PUI_PCM_ItemObjectIDSeed = __PUI_PCM_ItemObjectIDSeed + 1
  id = __PUI_PCM_ItemObjectIDSeed
  __PUI_PCM_ItemObjectID[itemFrame] = id
  return id
end

local function _PCM_GetLayoutIndex(btn)
  if not btn then
    return 0
  end

  local idx = btn.layoutIndex
  if idx ~= nil and not _PCM_IsSecret(idx) then
    if type(idx) == "number" and idx > 0 then
      return idx
    end

    if type(idx) == "string" then
      local numericIndex = tonumber(idx)
      if numericIndex and numericIndex > 0 then
        return numericIndex
      end
    end
  end

  local frameID = btn.GetID and btn:GetID() or nil
  if frameID ~= nil and not _PCM_IsSecret(frameID) then
    if type(frameID) == "number" and frameID > 0 then
      return frameID
    end

    if type(frameID) == "string" then
      local numericID = tonumber(frameID)
      if numericID and numericID > 0 then
        return numericID
      end
    end
  end

  return 0
end

local function _PCM_CompareIconLayoutOrder(a, b)
  local aIndex = _PCM_GetLayoutIndex(a)
  local bIndex = _PCM_GetLayoutIndex(b)

  if aIndex ~= bIndex then
    return aIndex < bIndex
  end

  return _PCM_GetStableItemObjectID(a) < _PCM_GetStableItemObjectID(b)
end

local function _PCM_SortIconsByLayoutOrder(icons)
  if not icons or #icons < 2 then
    return
  end

  table.sort(icons, _PCM_CompareIconLayoutOrder)
end

local function _PCM_HasViewerLayoutChanged(frame, count, cols, iconSize, spacing, borderPad, mode, fixedW, rowGrowth)
  local sig = __PUI_PCM_ViewerSig[frame]
  if not sig then
    sig = {}
    __PUI_PCM_ViewerSig[frame] = sig
  end

  local itemGeneration, layoutGeneration = PCMRuntime:GetViewerGenerations(frame)
  local modeSig = (mode == "fixed") and 2 or 1
  local transitionGen = PCMTransitionState.Gen or 0

  if sig.count == count
    and sig.cols == cols
    and sig.iconSize == iconSize
    and sig.spacing == spacing
    and sig.borderPad == borderPad
    and sig.mode == modeSig
    and sig.fixedW == fixedW
    and sig.rowGrowth == rowGrowth
    and sig.itemGeneration == itemGeneration
    and sig.layoutGeneration == layoutGeneration
    and sig.transitionGen == transitionGen
  then
    return false
  end

  sig.count = count
  sig.cols = cols
  sig.iconSize = iconSize
  sig.spacing = spacing
  sig.borderPad = borderPad
  sig.mode = modeSig
  sig.fixedW = fixedW
  sig.rowGrowth = rowGrowth
  sig.itemGeneration = itemGeneration
  sig.layoutGeneration = layoutGeneration
  sig.transitionGen = transitionGen
  return true
end

_PCM_ItemHasLayoutIndex = function(itemFrame)
  if not itemFrame then
    return false
  end

  local idx = itemFrame.layoutIndex
  if idx == nil then
    return false
  end

  if _PCM_IsSecret(idx) then
    return true
  end

  if type(idx) == "number" then
    return idx > 0
  end

  if type(idx) == "string" then
    idx = tonumber(idx)
    return idx ~= nil and idx > 0
  end

  return true
end

local function _PCM_CollectVisibleIcons(viewer, items)
  local itemGeneration, layoutGeneration = PCMRuntime:GetViewerGenerations(viewer)
  local cache = __PUI_PCM_ViewerIconCache[viewer]

  if cache
    and cache.itemGeneration == itemGeneration
    and cache.layoutGeneration == layoutGeneration
  then
    return cache.icons
  end

  if not cache then
    cache = { icons = {} }
    __PUI_PCM_ViewerIconCache[viewer] = cache
  end

  local icons = cache.icons
  t_wipe(icons)

  for i = 1, #items do
    local child = items[i]
    if child and not (child.IsForbidden and child:IsForbidden()) then
      if _PCM_ItemHasLayoutIndex(child) and _PCM_ItemHasRenderableContent(child) then
        icons[#icons + 1] = child
      end
    end
  end

  _PCM_SortIconsByLayoutOrder(icons)
  cache.itemGeneration = itemGeneration
  cache.layoutGeneration = layoutGeneration
  return icons
end

local function _PCM_GetSpacingForViewer(key)
  local rawSpacing = Cooldowns._GetIconSpacingForViewer(key)
  rawSpacing = tonumber(rawSpacing) or 0
  if rawSpacing < 0  then rawSpacing = 0  end
  if rawSpacing > 40 then rawSpacing = 40 end
  return RoundPixel(rawSpacing)
end

local function _PCM_GetBorderPadForViewer(key)
  local cfg = Cooldowns.GetBorderConfig(key)
  local t = cfg.thickness
  t = tonumber(t) or 0
  if t < 0 then t = 0 end
  return RoundPixel(t) * 2
end

local function _PCM_GetViewerCols(style, key)
  if not _PCM_IsCoreViewerKey(key) then
    return 0
  end

  local cols = style
    and style.viewerColumns
    and tonumber(style.viewerColumns[key])
    or 0

  if cols < 0 then cols = 0 end
  if cols > 40 then cols = 40 end
  return cols
end

local function _PCM_GetViewerRowGrowth(style, key)
  if not _PCM_IsCoreViewerKey(key) then
    return "DOWN"
  end

  if style and style.viewerRowGrowth and style.viewerRowGrowth[key] == "UP" then
    return "UP"
  end

  return "DOWN"
end

local function _PCM_GetIconSizeForViewer(key)
  local iconSize = Cooldowns._GetIconSizeForViewer(key)
  iconSize = RoundPixel(iconSize)
  if iconSize < 12 then iconSize = 12 end
  if iconSize > 96 then iconSize = 96 end
  return iconSize
end

local function _PCM_PreSizeIconsIfNeeded(icons, key, iconSize, mode)
  if mode == "fixed" then
    return
  end

  for _, icon in ipairs(icons) do
    _ApplyIconSizeToItemFrame(icon, key, iconSize)
  end
end

local function _PCM_ApplyWrappedOnly(layoutFrame, icons, key, count, firstRowLimit, iconSize, spacing, borderPad, mode, rowGrowth, storeOnly_)
  firstRowLimit = tonumber(firstRowLimit) or 0
  if firstRowLimit > 0 then
    if firstRowLimit > 40 then firstRowLimit = 40 end
    if count > 0 and firstRowLimit > count then
      firstRowLimit = count
    end
  end

  local fixedW = 0
  if mode == "fixed" then
    fixedW = tonumber(Cooldowns._GetFixedWidthForViewer(key)) or 0
  end
  if fixedW < 0 then fixedW = 0 end

  return _LayoutTwoRowWrap(
    layoutFrame,
    icons,
    key,
    count,
    firstRowLimit,
    iconSize,
    spacing,
    mode,
    fixedW,
    borderPad,
    rowGrowth,
    storeOnly_
  )
end

_ApplySimpleViewerLayout = function(frame, key, storeOnly)
  if not frame then
    return
  end
  if frame.IsForbidden and frame:IsForbidden() then
    return
  end
  if _PCM_IsRefreshBlocked() then
    return
  end

  -- Never run geometry/layout while Blizzard Edit Mode is active.
  -- Do not fight the user while the Edit Mode UI is open.
  if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then
    return
  end

  local storeOnly_  = (storeOnly == true)
  local fd = PCMHooks.GetFrameData(frame)
  local layoutFrame = fd.anchorFrame or frame

  local icons = _PCM_CollectVisibleIcons(frame, _GetViewerItemFrames(frame) or PCMCoreState.Empty)
  local count = #icons

  local spacing   = _PCM_GetSpacingForViewer(key)
  local borderPad = _PCM_GetBorderPadForViewer(key)

  local style = ns.PCM_DBExports.GetStyleDB()
  if style then
    style.viewerColumns = style.viewerColumns or {}
  end

  -- Essential and Utility may continue on a centered second row.
  local isEssential = _IsEssentialViewerKey(key)
  local isUtility = key == "UtilityCooldownViewer"
  if not isEssential and not isUtility then
    return
  end

  local cols = _PCM_GetViewerCols(style, key)
  local rowGrowth = _PCM_GetViewerRowGrowth(style, key)
  local iconSize = _PCM_GetIconSizeForViewer(key)
  local mode = Cooldowns._GetWidthModeForViewer(key)
  local fixedW = 0

  if mode == "fixed" then
    fixedW = tonumber(Cooldowns._GetFixedWidthForViewer(key)) or 0
    if fixedW < 0 then fixedW = 0 end
  end

  if not storeOnly_ and not _PCM_HasViewerLayoutChanged(frame, count, cols, iconSize, spacing, borderPad, mode, fixedW, rowGrowth) then
    return
  end

  if not storeOnly_ and count <= 0 then
    local afd = fd and fd.anchorFrame or nil
    if afd and afd.SetSize then
      afd:SetSize(1, 1)
    end

    local pf = fd and fd.proxyFrame or nil
    if pf and pf.SetSize then
      pf:SetSize(1, 1)
    end

    FrameUtil.RefreshSmartSnapRuntimeLayout("PCM_" .. key)
    return
  end

  _PCM_PreSizeIconsIfNeeded(icons, key, iconSize, mode)

  local w, h = _PCM_ApplyWrappedOnly(
    layoutFrame,
    icons,
    key,
    count,
    cols,
    iconSize,
    spacing,
    borderPad,
    mode,
    rowGrowth,
    storeOnly_
  )

  -- IMPORTANT:
  -- The mover is registered on the anchor frame. If the anchor frame stays 1x1,
  -- the mover becomes a 1px handle. Keep anchor (and proxy) sized to the laid-out icon footprint.
  if not storeOnly_ then
    local afd = fd and fd.anchorFrame or nil
    if afd and afd.SetSize then
      afd:SetSize(w or 1, h or 1)
    end

    local pf = fd and fd.proxyFrame or nil
    if pf and pf.SetSize then
      pf:SetSize(w or 1, h or 1)
    end

    FrameUtil.RefreshSmartSnapRuntimeLayout("PCM_" .. key)
  end
end

local function _PCM_ResetAcquiredItemState(itemFrame)
  IconSettings:ClearItemIdentity(itemFrame)

  local fd = PCMHooks.GetFrameData(itemFrame)
  fd.anchor = nil
  fd.posX = nil
  fd.posY = nil
  fd.sizeW = nil
  fd.sizeH = nil
  fd.apPoint = nil
  fd.apRel = nil
  fd.apRelPoint = nil
  fd.apX = nil
  fd.apY = nil
  fd.parked = nil

  __PUI_PCM_ItemRulePassStamp[itemFrame] = nil
end

local function _PCM_HandleViewerAcquire(frame, key, itemFrame, isRebind, expectInitialRebind)
  if not frame or not key or not itemFrame then
    return
  end

  if isRebind ~= true then
    _PCM_ResetAcquiredItemState(itemFrame)
  end

  _PCM_GetStableItemObjectID(itemFrame)

  local fd = PCMHooks.GetFrameData(itemFrame)
  fd.viewerFrame = frame
  fd.viewerKey = key
  PCMHooks.HookIconFrame(itemFrame, key)

  if isRebind ~= true then
    _PCM_ParkViewerItem(frame, itemFrame)
  end

  -- Blizzard assigns the cooldown identity after OnAcquireItemFrame. Let the
  -- hooked SetCooldownID apply identity presentation once that data exists.
  if expectInitialRebind == true then
    return
  end

  if _PCM_IsRefreshBlocked() then
    return
  end

  _ReskinItemFrame(itemFrame, key)
  local frameData = PCMHooks.PeekFrameData(itemFrame)
  if frameData and frameData.iconSettingsNeedsCooldownState == true then
    _PCM_UpdateIconCooldownState(itemFrame, key, "SPELL_UPDATE_COOLDOWN", frameData)
  end
end

local function _PCM_HandleViewerRelease(frame, itemFrame)
  if not frame or not itemFrame then
    return
  end

  __PUI_PCM_ItemRulePassStamp[itemFrame] = nil
  local fd = PCMHooks.GetFrameData(itemFrame)
  _PCM_ClearNativeIconPresentation(itemFrame, fd.viewerKey)
  IconSettings:ClearItemIdentity(itemFrame)

  fd.viewerFrame = nil
  fd.viewerKey = nil
  fd.anchor = nil
  fd.posX = nil
  fd.posY = nil
  fd.sizeW = nil
  fd.sizeH = nil
  fd.apPoint = nil
  fd.apRel = nil
  fd.apRelPoint = nil
  fd.apX = nil
  fd.apY = nil
  fd.parked = nil
end

local function _PCM_InvalidateBuildKey()
  PCMTransitionState.Gen = (PCMTransitionState.Gen or 0) + 1
end

local function _PCM_InvalidateStaticPresentation()
  PCMCoreState.StaticPresentationGeneration = PCMCoreState.StaticPresentationGeneration + 1
end

local function _PCM_InvalidateSkinCache()
  _PCM_MarkCountRulesDirty()
  _PCM_InvalidateStaticPresentation()

  for itemFrame in pairs(__PUI_PCM_ItemRulePassStamp) do
    __PUI_PCM_ItemRulePassStamp[itemFrame] = nil
  end
end

local function _PCM_InvalidateClassSpellCache()
  IconSettings:InvalidateCatalog()
  PCMViewerState.ItemGen = (PCMViewerState.ItemGen or 0) + 1
  PCMCoreState.ConfiguredEntryCountGen = -1
  wipe(PCMCoreState.ConfiguredEntryCountCache)

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
  _PCM_QueueTransitionFlush()
end

_PCM_ParkViewerItem = function(viewerFrame, itemFrame)
  if not viewerFrame or not itemFrame or (itemFrame.IsForbidden and itemFrame:IsForbidden()) then
    return
  end

  local key = _PCM_GetViewerKeyFromFrame(viewerFrame)
  local anchor = key and _GetOrCreateViewerAnchorFrame(viewerFrame, key) or nil
  local viewerData = PCMHooks.GetFrameData(viewerFrame)
  local parent = viewerData.proxyFrame or anchor
  local fd = PCMHooks.GetFrameData(itemFrame)

  fd.parked = true
  fd.locking = true

  if parent then
    fd.anchor = parent
    fd.posX = 0
    fd.posY = 0
  end

  itemFrame:SetAlpha(0)

  if parent then
    _PUI_SetPointStamped(itemFrame, "CENTER", parent, "CENTER", 0, 0)
  end

  fd.locking = false
end

local function _PCM_ParkRuntimeViewerItems(viewerFrame)
  if not viewerFrame or (viewerFrame.IsForbidden and viewerFrame:IsForbidden()) then
    return
  end

  local items = PCMRuntime:GetViewerItems(viewerFrame)
  for index = 1, #items do
    _PCM_ParkViewerItem(viewerFrame, items[index])
  end
end

local function _PCM_MarkAllViewersDirty(owner)
  if not owner then
    return
  end

  owner:_RequestViewerRefresh("layout")
end

_PCM_RunHardViewerTransition = function(owner, invalidateClassSpellCache)
  if not owner or not _PCM_IsModuleEnabledFast() then
    return
  end

  if PCMHooks.IsAddonRestricted() then
    PCMRuntime:QueueAllViewerScans("hard-transition-blocked")
    _PCM_MarkAllViewersDirty(owner)
    return
  end

  _PCM_InvalidateBuildKey()
  _PCM_InvalidateSkinCache()

  if invalidateClassSpellCache then
    _PCM_InvalidateClassSpellCache()
  end

  PCMRuntime:RefreshAllViewers("hard-transition")

  for _, info in owner:IterateViewers() do
    local key = info and info.key
    local frame = key and PCMRuntime:GetViewer(key) or nil
    if frame then
      _PCM_ParkRuntimeViewerItems(frame)
    end
  end

  _PCM_MarkAllViewersDirty(owner)
end

local function _PCM_ReconcileRuntimeViewers(owner)
  if not owner then
    return
  end

  PCMRuntime:RefreshAllViewers("transition-finalize")

  for _, info in owner:IterateViewers() do
    local key = info and info.key
    local frame = key and PCMRuntime:GetViewer(key) or nil
    if frame then
      __PUI_PCM_ViewerSig[frame] = nil
      _ForceAnchor(frame, key)
    end
  end

  FrameUtil.RelayoutSmartSnapCluster("PCM_EssentialCooldownViewer")
  FrameUtil.RelayoutSmartSnapCluster("PCM_UtilityCooldownViewer")
end


_PCM_EnsureDataProviderHook = function(provider)
  if not provider or PCMTransitionProviderHooks[provider] then
    return
  end

  local hooked = PCMHooks.HookMethod(
    provider,
    "SwitchToBestLayoutForSpec",
    "PleebUI_PCM_DataProviderReady",
    function()
      if not _PCM_IsModuleEnabledFast() then
        return
      end

      if _PCM_IsTransitionPending() then
        _PCM_QueueTransitionFlush()
      end
    end
  )

  if hooked then
    PCMTransitionProviderHooks[provider] = true
  end
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

  _PCM_InvalidateBuildKey()
  _PCM_InvalidateSkinCache()

  if invalidateClassSpellCache then
    _PCM_InvalidateClassSpellCache()
  end

  _PCM_ReconcileRuntimeViewers(owner)

  PCMTransitionState.Queued = false
  PCMTransitionState.Owner = nil
  PCMTransitionState.InvalidateClassSpellCache = false

  owner:_FlushViewerRefreshImmediate("all")
  ns.Modules.PCM_Buffs:RefreshAfterTalentSwap()
  ns.Modules.PCM_BuffBars:RefreshAfterTalentSwap()
  ns.Modules.PCM_BB.RefreshAfterTalentSwap()
  owner:SpellBars_RefreshAfterTalentSwap()
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

  if InCombatLockdown() then
    return
  end

  local settings = _G.CooldownViewerSettings
  local provider = settings and settings:GetDataProvider() or nil
  if not provider then
    return
  end

  _PCM_EnsureDataProviderHook(provider)

  if provider:IsLayoutUpdateQueued() then
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
  if not viewer or not key then
    return nil
  end

  local vfd = PCMHooks.GetFrameData(viewer)
  if vfd.anchorFrame then
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

  vfd.anchorFrame = af

  local afd = PCMHooks.GetFrameData(af)
  afd.viewerKey = key

  local proxyName = "PUI_PCM_Proxy_" .. tostring(key)
  local pf = _G[proxyName]
  if not pf then
    pf = CreateFrame("Frame", proxyName, UIParent)
    pf:SetSize(1, 1)
    pf:SetFrameStrata("LOW")
    pf:SetFrameLevel(2)
  end
  pf:ClearAllPoints()
  pf:SetPoint("CENTER", af, "CENTER", 0, 0)

  vfd.proxyFrame = pf

  afd.proxyFrame = pf

  local pfd = PCMHooks.GetFrameData(pf)
  pfd.viewerKey = key
  pfd.anchorFrame = af

  return af
end

function Cooldowns:GetViewerAnchorFrame(viewerKey)
  if not viewerKey then
    return nil
  end

  if not _PCM_IsModuleEnabledFast() then
    return nil
  end

  local viewer = self:GetViewerFrame(viewerKey)
  if viewer and not (viewer.IsForbidden and viewer:IsForbidden()) then
    return _GetOrCreateViewerAnchorFrame(viewer, viewerKey)
  end

  -- If the viewer is not created yet, still return stable frames so other modules
  -- can safely anchor without depending on Blizzard's viewer existence.
  local name = "PUI_PCM_Anchor_" .. tostring(viewerKey)
  local af = _G[name]
  if not af then
    af = CreateFrame("Frame", name, UIParent)
    af:SetSize(1, 1)
    af:SetFrameStrata("LOW")
    af:SetFrameLevel(1)
  end

  local proxyName = "PUI_PCM_Proxy_" .. tostring(viewerKey)
  local pf = _G[proxyName]
  if not pf then
    pf = CreateFrame("Frame", proxyName, UIParent)
    pf:SetSize(1, 1)
    pf:SetFrameStrata("LOW")
    pf:SetFrameLevel(2)
  end
  pf:ClearAllPoints()
  pf:SetPoint("CENTER", af, "CENTER", 0, 0)

  local afd = PCMHooks.GetFrameData(af)
  afd.viewerKey = viewerKey
  afd.proxyFrame = pf

  local pfd = PCMHooks.GetFrameData(pf)
  pfd.viewerKey = viewerKey
  pfd.anchorFrame = af

  return af
end

_ForceAnchor = function(frame, key)
  if not frame or not key then return end
  if frame.IsForbidden and frame:IsForbidden() then return end

  -- Never mutate anchors while Blizzard Edit Mode is active.
  -- Do not fight the user while the Edit Mode UI is open.
  if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then
    return
  end

  local db = Cooldowns._GetViewerDB()
  if not db then return end

  local pos = db[key]
  if not pos or not pos.point then return end

  -- Anchor to our proxy frame, never to the Blizzard viewer frame.
  local anchor = _GetOrCreateViewerAnchorFrame(frame, key)
  if not anchor then
    return
  end

  local rel = _G[pos.rel or "UIParent"] or UIParent
  if rel then
    local rfd = PCMHooks.GetFrameData(rel)
    if rfd.anchorFrame then
      rel = rfd.anchorFrame
    end
  end

  PCMAnchorState.applyingAnchor[anchor] = true
  anchor:ClearAllPoints()
  anchor:SetPoint(
    pos.point,
    rel,
    pos.relPoint or pos.point,
    pos.x or 0,
    pos.y or 0
  )
  PCMAnchorState.applyingAnchor[anchor] = nil

  -- Keep the Blizzard viewer's own anchors alone.
  -- We only move our anchor/proxy chain and the pooled icon frames.
end

local function _ProtectViewerAnchors_Icons(frame, key)
  if not frame or PCMAnchorState.anchorsOwned[frame] then return end
  if frame.IsForbidden and frame:IsForbidden() then return end

  PCMAnchorState.anchorsOwned[frame] = true

  -- Never touch viewer anchors (EditMode-managed -> can call protected ClearAllPointsBase()).
  -- We position icons relative to our own proxy anchor frame instead.
  _GetOrCreateViewerAnchorFrame(frame, key)
end

function Cooldowns:_OnRegenEnabled()
  if _PCM_IsTransitionPending() then
    _PCM_QueueTransitionFlush()
  end

  if self.__puiPCMCustomTrackerStartupPending then
    self:_ReconcileCustomTrackerStartupAvailability()
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

  local viewer = PCMRuntime:GetViewer(info.key)
  if not viewer then return end
  if viewer.IsForbidden and viewer:IsForbidden() then return end

  local anchor = _GetOrCreateViewerAnchorFrame(viewer, info.key)
  if not anchor then
    return
  end

  local vfd = PCMHooks.GetFrameData(viewer)
  local proxy = vfd.proxyFrame

  local inCombat = InCombatLockdown()

  if not inCombat and anchor.Show then
    anchor:Show()
  end
  if not inCombat and anchor.EnableMouse then
    anchor:EnableMouse(true)
  end

  if proxy and not inCombat and proxy.Show then
    proxy:Show()
  end
  if proxy and not inCombat and proxy.EnableMouse then
    proxy:EnableMouse(true)
  end

  if PCMAnchorState.moverRegistered[anchor] then
    return
  end
  PCMAnchorState.moverRegistered[anchor] = true

  _EnsureDefaultViewerAnchor(info.key)

  _ForceAnchor(viewer, info.key)
  _ProtectViewerAnchors_Icons(viewer, info.key)

  local isSmartCombatViewer = info.key == "EssentialCooldownViewer"
    or info.key == "UtilityCooldownViewer"
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
        min = 12,
        max = 86,
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
      min = 120,
      max = 1000,
      step = 1,
      commitOnRelease = true,
      get = function()
        if Cooldowns._GetWidthModeForViewer(info.key) == "fixed" then
          return Round(Cooldowns._GetFixedWidthForViewer(info.key) + _PCM_GetBorderPadForViewer(info.key))
        end

        local width = anchor:GetWidth()
        if width and width > 1 then
          return Round(width)
        end
        return Round(Cooldowns._GetFixedWidthForViewer(info.key) + _PCM_GetBorderPadForViewer(info.key))
      end,
      set = function(value)
        style.viewerWidthMode[info.key] = "fixed"
        style.viewerFixedWidth[info.key] = math.max(
          1,
          Round(value - _PCM_GetBorderPadForViewer(info.key))
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
      min = 0,
      max = 12,
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
      max = 10,
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
        Cooldowns:FlushPendingEditModeChanges()
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
          Cooldowns:FlushPendingEditModeChanges()
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
    optionsString = (info.key == "EssentialCooldownViewer" and "CooldownManager,cooldowns_essential")
      or (info.key == "UtilityCooldownViewer" and "CooldownManager,cooldowns_utility")
      or "CooldownManager",
    quickSettings = BuildQuickSettings,
    smartSnap = isSmartCombatViewer and {
      family = "combatBars",
      isRuntimeActive = function()
        return _PCM_IsModuleEnabledFast()
      end,
      syncAxis = "WIDTH",
      syncWidthMin = 120,
      syncWidthMax = 1000,
      getSyncWidth = function()
        if Cooldowns._GetWidthModeForViewer(info.key) == "fixed" then
          return Round(Cooldowns._GetFixedWidthForViewer(info.key) + _PCM_GetBorderPadForViewer(info.key))
        end
        return anchor:GetWidth()
      end,
      applySyncWidth = function(width)
        local style = ns.PCM_DBExports.GetStyleDB()
        style.viewerWidthMode[info.key] = "fixed"
        style.viewerFixedWidth[info.key] = math.max(
          1,
          Round(width - _PCM_GetBorderPadForViewer(info.key))
        )
        Cooldowns:_FlushViewerRefreshImmediate("layout", info.key)
        FrameUtil:RefreshGhostMover("PCM_" .. info.key)
      end,
    } or nil,

    savePosition = SavePosition,
    onDragStop = function()
      _ForceAnchor(viewer, info.key)
    end,
  })


end

local function _InitAllViewerMovers()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  for _, info in Cooldowns:IterateViewers() do
    _RegisterViewerMover(info)
  end
end

local function _ForEachRefreshViewer(viewerKey, fn)
  if viewerKey then
    local frame = Cooldowns:GetViewerFrame(viewerKey)
    if frame and not frame:IsForbidden() then
      fn(frame, viewerKey)
    end
    return
  end

  for _, info in Cooldowns:IterateViewers() do
    local key = info and info.key
    local frame = key and PCMRuntime:GetViewer(key) or nil
    if key and frame and not frame:IsForbidden() then
      fn(frame, key)
    end
  end
end

local function _RefreshViewerBordersOnly(viewerKey)
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  if _PCM_IsRefreshBlocked() then
    _PCM_QueueBlockedViewerRefresh(PCM_REFRESH_SKIN, viewerKey)
    return
  end

  -- Do not fight the user while the Edit Mode UI is open.
  if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then
    return
  end

  _PCM_InvalidateStaticPresentation()

  _ForEachRefreshViewer(viewerKey, function(frame, key)
    local items = _GetViewerItemFrames(frame) or PCMCoreState.Empty
    for _, itemFrame in ipairs(items) do
      if _PCM_ItemHasRenderableContent(itemFrame) then
        local regions = IconSkin.ResolveCooldownViewerRegions(itemFrame)
        local iconContainer = regions.iconContainer or itemFrame
        local icon          = regions.icon or ((itemFrame.Icon and itemFrame.Icon.SetTexture) and itemFrame.Icon or nil)
        local cooldownFrame = regions.cd or itemFrame.Cooldown

        IconSkin.StripCooldownManagerOverlay(itemFrame)

        local borderFrame = iconContainer or itemFrame
        _ApplyBorderToFrame(borderFrame, true, key, itemFrame)
        _ApplyBorderInsets(itemFrame, key, iconContainer, icon, cooldownFrame)

        local frameData = PCMHooks.GetFrameData(itemFrame)
        frameData.iconStaticPresentationGeneration = PCMCoreState.StaticPresentationGeneration
        frameData.iconStaticPresentationViewerKey = key
      else
        if itemFrame and itemFrame.SetShown then
          itemFrame:SetShown(false)
        elseif itemFrame and itemFrame.Hide then
          itemFrame:Hide()
        end
      end
    end
  end)
end

local function _RefreshSingleViewerIcons(viewerKey)
  if not viewerKey then
    return false
  end

  local frame = Cooldowns:GetViewerFrame(viewerKey)
  if not frame or (frame.IsForbidden and frame:IsForbidden()) then
    return false
  end

  local items = _GetViewerItemFrames(frame) or PCMCoreState.Empty
  for _, itemFrame in ipairs(items) do
    if itemFrame then
      _ReskinItemFrame(itemFrame, viewerKey)
    end
  end

  return true
end

local function _PCM_RunCountRulePassIfNeeded(viewerKey)
  if viewerKey ~= nil then
    return
  end

  Cooldowns:_OnViewersRefreshedForCountRules()
end

local function _RefreshViewerFontsOnly(viewerKey)
  if _PCM_IsRefreshBlocked() then
    return
  end

  ns._PCM_RunUnifiedViewerItemPass(viewerKey, true, false)
end

local function _RefreshIconViewers(viewerKey)
  if _PCM_IsRefreshBlocked() then
    return
  end

  if viewerKey then
    if _RefreshSingleViewerIcons(viewerKey) then
      _PCM_RunCountRulePassIfNeeded(viewerKey)
    end
    return
  end

  _ForEachRefreshViewer(nil, function(frame, key)
    local items = _GetViewerItemFrames(frame) or PCMCoreState.Empty
    for _, itemFrame in ipairs(items) do
      if itemFrame then
        _ReskinItemFrame(itemFrame, key)
      end
    end
  end)

  _PCM_RunCountRulePassIfNeeded(nil)
end

Cooldowns._RefreshViewerBordersOnly = _RefreshViewerBordersOnly
Cooldowns._RefreshViewerFontsOnly = _RefreshViewerFontsOnly

function Cooldowns:RefreshIconFonts()
  if _PCM_IsRefreshBlocked() then
    return
  end

  ns._PCM_RunUnifiedViewerItemPass(nil, true, false)
  self:ConsumableTracker_RefreshFonts()
end


local function _RetakeBlizzardEditModeOwnership(self)
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  if PCMHooks.IsAddonRestricted() or PCMHooks.InBlizzardEditMode() then
    return
  end

  PCMViewerState.ItemGen = (PCMViewerState.ItemGen or 0) + 1

  _InitAllViewerMovers()

  do
    local viewersDB = self:_GetViewerDB()

    for _, info in self:IterateViewers() do
      local key = info and info.key
      local frame = key and PCMRuntime:GetViewer(key) or nil

      if key and frame and not (frame.IsForbidden and frame:IsForbidden()) then
        if viewersDB and viewersDB[key] then
          _GetOrCreateViewerAnchorFrame(frame, key)
          _ForceAnchor(frame, key)

          __PUI_PCM_ViewerSig[frame] = nil
        end

        if __PUI_CDM_ViewerInitApplied then
          __PUI_CDM_ViewerInitApplied[frame] = nil
        end
      end
    end
  end

  FrameUtil.RelayoutSmartSnapCluster("PCM_EssentialCooldownViewer")
  FrameUtil.RelayoutSmartSnapCluster("PCM_UtilityCooldownViewer")

  ns.Modules.PCM_Buffs:RetakeBlizzardEditModeOwnership()
  ns.Modules.PCM_BuffBars:RetakeBlizzardEditModeOwnership()

  self:_RequestViewerRefresh("layout")
  self:_RequestViewerRefresh("icons")
  _PCM_FlushBlockedViewerRefresh(self)
  PCMRuntime:Flush()
end

function Cooldowns:_OnEditModeChanged(enable)
  local moduleEnabled = _PCM_IsModuleEnabledFast() == true

  enable = (enable == true)

  if not enable then
    C_Timer.After(0, function()
      Cooldowns:FlushPendingEditModeChanges()
    end)
  end

  if not moduleEnabled then
    Cooldowns.__puiPCM_EditModeOn = false
    Cooldowns._essentialDragEnabled = false
    return
  end

  Cooldowns.__puiPCM_EditModeOn = enable
  ns.PCMCustomIcons:RefreshAllVisibility()

  -- Allow drag/drop of Essential icons only during /pe.
  Cooldowns._essentialDragEnabled = enable

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
    return
  end

  if InCombatLockdown() then
    self.__puiPCM_BlizzardEditModeRetakePending = true
    return
  end

  self.__puiPCM_BlizzardEditModeRetakePending = nil
  _RetakeBlizzardEditModeOwnership(self)

  if LibEditModeOverride:IsReady() and not _PCM_IsEditModeLayoutMutationBlocked() then
    LibEditModeOverride:LoadLayouts()
  end

  PCMEditModeChangesPending = false
end

local function _ApplyPCMProfile(self)
  _InitAllViewerMovers()

  do
    local viewersDB = self:_GetViewerDB()

    for _, info in self:IterateViewers() do
      local key = info and info.key
      local frame = key and PCMRuntime:GetViewer(key) or nil

      if key and frame and viewersDB and viewersDB[key] then
        _GetOrCreateViewerAnchorFrame(frame, key)
        _ForceAnchor(frame, key)
        __PUI_PCM_ViewerSig[frame] = nil
      end
    end
  end

  FrameUtil.RelayoutSmartSnapCluster("PCM_EssentialCooldownViewer")
  FrameUtil.RelayoutSmartSnapCluster("PCM_UtilityCooldownViewer")

  _PCM_InvalidateStaticPresentation()
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

-- PUI: hook existing Blizzard CDM viewers and apply our mover+skin pipeline.
local function _TryHookExistingViewers()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  PCMRuntime:RefreshAllViewers("try-hook")

  for _, info in Cooldowns:IterateViewers() do
    local key = info.key
    if key then
      _EnsurePCMViewerMoverForKey(key)
    end
  end
end

local PCM_REFRESH_LAYOUT = PCMRuntime.Dirty.LAYOUT
local PCM_REFRESH_FONT = PCMRuntime.Dirty.FONT
local PCM_REFRESH_SKIN = PCMRuntime.Dirty.SKIN
local PCM_REFRESH_FULL = PCM_REFRESH_LAYOUT + PCM_REFRESH_FONT + PCM_REFRESH_SKIN

local __PUI_PCM_BlockedRefresh = {
  mask = 0,
  dirty = {},
}

local function _PCM_RefreshMaskAdd(mask, flag)
  if PCMRuntime:MaskHas(mask, flag) then
    return mask or 0
  end
  return (mask or 0) + flag
end

local function _PCM_MergeRefreshMask(left, right)
  local merged = left or 0
  right = right or 0

  if PCMRuntime:MaskHas(right, PCM_REFRESH_LAYOUT) then
    merged = _PCM_RefreshMaskAdd(merged, PCM_REFRESH_LAYOUT)
  end
  if PCMRuntime:MaskHas(right, PCM_REFRESH_FONT) then
    merged = _PCM_RefreshMaskAdd(merged, PCM_REFRESH_FONT)
  end
  if PCMRuntime:MaskHas(right, PCM_REFRESH_SKIN) then
    merged = _PCM_RefreshMaskAdd(merged, PCM_REFRESH_SKIN)
  end

  return merged
end

local function _PCM_GetViewerRefreshMask(mode)
  if mode == "layout" then
    return PCM_REFRESH_LAYOUT
  elseif mode == "fonts" then
    return PCM_REFRESH_FONT
  elseif mode == "icons" then
    return PCM_REFRESH_SKIN
  end
  return PCM_REFRESH_FULL
end

local function _PCM_SetDirtyViewerMask(target, viewerKey, mask)
  if type(viewerKey) ~= "string" or viewerKey == "" then
    return
  end

  target[viewerKey] = _PCM_MergeRefreshMask(target[viewerKey], mask)
end

local function _PCM_ClearBlockedViewerRefreshQueue()
  __PUI_PCM_BlockedRefresh.mask = 0
  t_wipe(__PUI_PCM_BlockedRefresh.dirty)
end

local function _PCM_QueueBlockedViewerRefresh(mask, viewerKey)
  if viewerKey then
    _PCM_SetDirtyViewerMask(__PUI_PCM_BlockedRefresh.dirty, viewerKey, mask)
  else
    __PUI_PCM_BlockedRefresh.mask = _PCM_MergeRefreshMask(__PUI_PCM_BlockedRefresh.mask, mask)
  end
end

local function _PCM_ExecuteViewerRefresh(self, mask, viewerKey)
  if not self or not _PCM_IsModuleEnabledFast() or not mask or mask == 0 then
    return
  end

  if PCMRuntime:MaskHas(mask, PCM_REFRESH_SKIN) then
    _RefreshIconViewers(viewerKey)
  elseif PCMRuntime:MaskHas(mask, PCM_REFRESH_FONT) then
    _RefreshViewerFontsOnly(viewerKey)
  end

  if PCMRuntime:MaskHas(mask, PCM_REFRESH_LAYOUT) then
    _ForEachRefreshViewer(viewerKey, _ApplySimpleViewerLayout)
  end
end

_PCM_FlushBlockedViewerRefresh = function(self)
  if not self or not _PCM_IsModuleEnabledFast() then
    _PCM_ClearBlockedViewerRefreshQueue()
    return
  end

  if PCMHooks.InBlizzardEditMode() then
    return
  end

  local globalMask = __PUI_PCM_BlockedRefresh.mask or 0
  __PUI_PCM_BlockedRefresh.mask = 0

  if globalMask > 0 then
    PCMRuntime:MarkAllViewersDirty(globalMask, "blocked-global")
  end

  for viewerKey, mask in pairs(__PUI_PCM_BlockedRefresh.dirty) do
    __PUI_PCM_BlockedRefresh.dirty[viewerKey] = nil
    PCMRuntime:MarkViewerDirty(viewerKey, mask, "blocked-viewer")
  end
end

function Cooldowns:_FlushViewerRefreshImmediate(mode, viewerKey)
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  self:_RequestViewerRefresh(mode, viewerKey)
  PCMRuntime:Flush()
end

function Cooldowns:_RequestViewerRefresh(mode, viewerKey)
  if not self or not _PCM_IsModuleEnabledFast() then
    return
  end

  local mask = _PCM_GetViewerRefreshMask(mode)

  if PCMRuntime:MaskHas(mask, PCM_REFRESH_SKIN) then
    _PCM_MarkCountRulesDirty()
    _PCM_InvalidateStaticPresentation()
  end

  if PCMHooks.InBlizzardEditMode() then
    _PCM_QueueBlockedViewerRefresh(mask, viewerKey)
    return
  end

  if viewerKey then
    PCMRuntime:MarkViewerDirty(viewerKey, mask, "core-request")
  else
    PCMRuntime:MarkAllViewersDirty(mask, "core-request-all")
  end
end

local PCM_GLOW_KEY = "_PUIGlow"
local PCMProcGlowOptions = {
  key = PCM_GLOW_KEY,
  color = nil,
  startAnim = true,
  xOffset = 0,
  yOffset = 0,
  duration = 1,
  frameLevel = 8,
}

local PCM_GLOW_TYPES = {
  pixel      = { lcgType = "pixel",      defaultFrequency = 0.25, defaultLines = 8, defaultThickness = 2, defaultScale = 1.0 },
  autocast   = { lcgType = "autocast",   defaultFrequency = 0.6,  defaultLines = 4, defaultThickness = 2, defaultScale = 1.0 },
  proc       = { lcgType = "proc",       defaultFrequency = 1.0,  defaultLines = 4, defaultThickness = 2, defaultScale = 1.0 },
  actionbutton = { lcgType = "button",   defaultFrequency = 1.0,  defaultLines = 4, defaultThickness = 2, defaultScale = 1.0 },
}

local _PCM_StopLibGlow

local function _PCM_GetGlowDB()
  local E = ns.PCM_DBExports
  local root = (E and E.GetPCMRoot and E.GetPCMRoot()) or nil
  if not root then
    PCMGlowState.db = nil
    PCMGlowState.enabled = false
    PCMGlowState.settings = nil
    return nil
  end

  root.glow = root.glow or {}

  if PCMGlowState.db ~= root.glow then
    PCMGlowState.settings = nil
  end
  PCMGlowState.db = root.glow
  PCMGlowState.enabled = root.glow.enabled ~= false

  return root.glow
end

Cooldowns._GetGlowDB = _PCM_GetGlowDB

local function _PCM_IsGlowEnabled()
  local g = _PCM_GetGlowDB()
  return g and g.enabled ~= false
end

local function _PCM_IsGlowEnabledFast()
  if PCMGlowState.enabled ~= nil then
    return PCMGlowState.enabled == true
  end

  return _PCM_IsGlowEnabled() == true
end

function ns._PCM_SetBlizzardGlowShown(icon, shown)
  if not icon then
    return
  end

  local saa = icon.SpellActivationAlert
  if saa then
    if shown then
      saa:Show()
      saa:SetAlpha(1)

      local loop = saa.ProcLoopFlipbook
      if loop then
        loop:Show()
      end

      local start = saa.ProcStartFlipbook
      if start then
        start:Show()
      end
    else
      saa:Hide()

      local loop = saa.ProcLoopFlipbook
      if loop then
        loop:Hide()
      end

      local start = saa.ProcStartFlipbook
      if start then
        start:Hide()
      end
    end
  end

  if shown then
    if icon.overlay then
      icon.overlay:Show()
      icon.overlay:SetAlpha(1)
    end
    if icon.Overlay then
      icon.Overlay:Show()
      icon.Overlay:SetAlpha(1)
    end
    if icon.Glow then
      icon.Glow:Show()
    end
  else
    if icon.overlay then
      icon.overlay:Hide()
    end
    if icon.Overlay then
      icon.Overlay:Hide()
    end
    if icon.Glow then
      icon.Glow:Hide()
    end

    if LCG and LCG.ButtonGlow_Stop then
      LCG.ButtonGlow_Stop(icon)
    end
  end
end

local function _PCM_GetGlowSettings()
  local cached = PCMGlowState.settings
  if cached then
    return cached.glowType, cached.color, cached.frequency, cached.scale, cached.lines, cached.thickness, cached.duration
  end

  local db = _PCM_GetGlowDB() or {}
  local glowType = tostring(db.type or "pixel")
  local typeInfo = PCM_GLOW_TYPES[glowType] or PCM_GLOW_TYPES.pixel

  local color = db.color
  if type(color) ~= "table" then
    color = { 0.95, 0.95, 0.32, 1 }
  end

  local speed = tonumber(db.speed) or 100
  if speed < 20 then speed = 20 end
  if speed > 200 then speed = 200 end
  local speedMul = speed / 100

  local scale = tonumber(db.scale)
  if scale == nil then
    scale = typeInfo.defaultScale or 1.0
  end
  if scale < 0.5 then scale = 0.5 end
  if scale > 2.0 then scale = 2.0 end

  local lines = tonumber(db.lines)
  if lines == nil then
    lines = typeInfo.defaultLines or 8
  end
  if lines < 2 then lines = 2 end
  if lines > 16 then lines = 16 end

  local thickness = tonumber(db.thickness)
  if thickness == nil then
    thickness = typeInfo.defaultThickness or 2
  end
  if thickness < 1 then thickness = 1 end
  if thickness > 6 then thickness = 6 end

  local frequency = (typeInfo.defaultFrequency or 1.0) * speedMul
  local duration = 1.0 / speedMul
  if duration < 0.05 then
    duration = 0.05
  end

  cached = {
    glowType = glowType,
    color = color,
    frequency = frequency,
    scale = scale,
    lines = lines,
    thickness = thickness,
    duration = duration,
  }
  PCMGlowState.settings = cached

  return glowType, color, frequency, scale, lines, thickness, duration
end

local function _PCM_StartProcGlow(icon)
  if not icon then
    return
  end

  local st = PCMHooks.PeekFrameData(icon)
  if not st then
    return
  end

  st.procGlowWanted = true
  st.procGlowPending = nil

  if st.iconStateHidden == true then
    _PCM_StopLibGlow(icon, st.procGlowType)
    st.procGlowActive = nil
    st.procGlowType = nil
    return
  end

  if st.isViewerIconButton ~= true then
    return
  end

  if not (_PCM_IsGlowEnabledFast() and LCG) then
    _PCM_StopLibGlow(icon)
    st.procGlowActive = nil
    st.procGlowType = nil
    return
  end

  local glowType, color, frequency, scale, lines, thickness, duration = _PCM_GetGlowSettings()

  ns._PCM_SetBlizzardGlowShown(icon, false)

  if st.procGlowActive and st.procGlowType == glowType then
    return
  end

  if st.procGlowActive then
    _PCM_StopLibGlow(icon, st.procGlowType)
    st.procGlowActive = nil
    st.procGlowType = nil
  end

  if glowType == "pixel" and LCG.PixelGlow_Start then
    LCG.PixelGlow_Start(icon, color, lines, frequency, nil, thickness, 0, 0, true, PCM_GLOW_KEY, 8)
  elseif glowType == "autocast" and LCG.AutoCastGlow_Start then
    LCG.AutoCastGlow_Start(icon, color, lines, frequency, scale, 0, 0, PCM_GLOW_KEY, 8)
  elseif glowType == "actionbutton" and LCG.ButtonGlow_Start then
    LCG.ButtonGlow_Start(icon, color, frequency, 8)
  elseif glowType == "proc" and LCG.ProcGlow_Start then
    PCMProcGlowOptions.color = color
    PCMProcGlowOptions.duration = duration
    LCG.ProcGlow_Start(icon, PCMProcGlowOptions)
  else
    st.procGlowActive = nil
    st.procGlowType = nil
    return
  end

  st.procGlowActive = true
  st.procGlowType = glowType
end


_PCM_StopLibGlow = function(icon, glowType)
  if not icon or not LCG then
    return
  end

  if (glowType == nil or glowType == "pixel") and LCG.PixelGlow_Stop then
    LCG.PixelGlow_Stop(icon, PCM_GLOW_KEY)
  end
  if (glowType == nil or glowType == "autocast") and LCG.AutoCastGlow_Stop then
    LCG.AutoCastGlow_Stop(icon, PCM_GLOW_KEY)
  end
  if (glowType == nil or glowType == "actionbutton") and LCG.ButtonGlow_Stop then
    LCG.ButtonGlow_Stop(icon)
  end
  if (glowType == nil or glowType == "proc") and LCG.ProcGlow_Stop then
    LCG.ProcGlow_Stop(icon, PCM_GLOW_KEY)
  end
end

local function _PCM_StopProcGlow(icon, keepWanted)
  if not icon then
    return
  end

  local st = PCMHooks.PeekFrameData(icon)
  if not st then
    return
  end

  if not (st.procGlowActive or st.procGlowPending or st.procGlowWanted) then
    return
  end

  st.procGlowPending = nil

  if st.procGlowActive then
    _PCM_StopLibGlow(icon, st.procGlowType)
  end

  st.procGlowActive = nil
  st.procGlowType = nil

  if not keepWanted then
    st.procGlowWanted = nil
  end
end

local PCM_ICON_SETTINGS_GLOW_KEY = "PUI_PCM_IconSettingsState"

local function _PCM_StopIconSettingsGlow(itemFrame, frameData)
  if not itemFrame then
    return
  end

  frameData = frameData or PCMHooks.PeekFrameData(itemFrame)
  if not frameData then
    return
  end

  local style = frameData.iconSettingsGlowStyle
  if style == "PIXEL" then
    LCG.PixelGlow_Stop(itemFrame, PCM_ICON_SETTINGS_GLOW_KEY)
  elseif style == "AUTOCAST" then
    LCG.AutoCastGlow_Stop(itemFrame, PCM_ICON_SETTINGS_GLOW_KEY)
  elseif style == "PROC" then
    LCG.ProcGlow_Stop(itemFrame, PCM_ICON_SETTINGS_GLOW_KEY)
  end

  frameData.iconSettingsGlowStyle = nil
  frameData.iconSettingsGlowState = nil
  frameData.iconSettingsGlowGeneration = nil
end

local function _PCM_ApplyIconSettingsGlow(itemFrame, frameData, entry, stateName, appearance)
  if not appearance or stateName == "UNKNOWN" then
    _PCM_StopIconSettingsGlow(itemFrame, frameData)
    return
  end

  local style
  local color
  if stateName == "AURA" then
    style = appearance.auraGlowStyle
    color = appearance.auraGlowColor
  elseif stateName == "COOLDOWN" then
    style = appearance.cooldownGlowStyle
    color = appearance.cooldownGlowColor
  elseif entry and entry.hasCharges and appearance.maxChargeGlowStyle ~= nil then
    style = appearance.maxChargeGlowStyle
    color = appearance.maxChargeGlowColor
  else
    style = appearance.readyGlowStyle
    color = appearance.readyGlowColor
  end

  if style == nil or style == "NONE" then
    _PCM_StopIconSettingsGlow(itemFrame, frameData)
    return
  end

  local generation = frameData.iconSettingsGeneration
  if frameData.iconSettingsGlowStyle == style
    and frameData.iconSettingsGlowState == stateName
    and frameData.iconSettingsGlowGeneration == generation
  then
    return
  end

  _PCM_StopIconSettingsGlow(itemFrame, frameData)
  color = color or { 1, 1, 1, 1 }

  if style == "PIXEL" then
    LCG.PixelGlow_Start(itemFrame, color, 8, 0.25, nil, 2, 0, 0, true, PCM_ICON_SETTINGS_GLOW_KEY, 8)
  elseif style == "AUTOCAST" then
    LCG.AutoCastGlow_Start(itemFrame, color, 8, 0.25, 1, 0, 0, PCM_ICON_SETTINGS_GLOW_KEY, 8)
  elseif style == "PROC" then
    LCG.ProcGlow_Start(itemFrame, {
      key = PCM_ICON_SETTINGS_GLOW_KEY,
      color = color,
      startAnim = true,
      xOffset = 0,
      yOffset = 0,
      duration = 1,
      frameLevel = 8,
    })
  else
    return
  end

  frameData.iconSettingsGlowStyle = style
  frameData.iconSettingsGlowState = stateName
  frameData.iconSettingsGlowGeneration = generation
end

_PCM_ClearNativeIconPresentation = function(itemFrame, viewerKey)
  if not itemFrame then
    return
  end

  local frameData = PCMHooks.GetFrameData(itemFrame)
  _PCM_StopIconSettingsGlow(itemFrame, frameData)

  if frameData.iconStateHidden == true then
    itemFrame:SetTooltipsShown(Cooldowns:GetViewerTooltipsEnabled(viewerKey))
  end

  local regions = IconSkin.ResolveCooldownViewerRegions(itemFrame)
  local icon = regions and regions.icon or nil
  if icon and frameData.iconAppliedSaturation ~= nil and icon.SetDesaturation then
    icon:SetDesaturation(0)
  end

  if frameData.iconCustomTextureApplied ~= nil then
    itemFrame:RefreshSpellTexture()
  end

  itemFrame:SetAlpha(1)

  frameData.iconStateHidden = nil
  frameData.iconAppliedAlpha = nil
  frameData.iconAppliedSaturation = nil
  frameData.iconCustomTextureApplied = nil
end

function Cooldowns:RefreshIndividualIconSettings(viewerKey)
  if not viewerKey or not _PCM_IsModuleEnabledFast() then
    return
  end

  if _PCM_IsRefreshBlocked() then
    _PCM_QueueBlockedViewerRefresh(PCM_REFRESH_FULL, viewerKey)
    return
  end

  if viewerKey == "BuffIconCooldownViewer" then
    ns.Modules.PCM_Buffs:RefreshIndividualIconSettings()
    return
  end

  self:_Keybinds_RefreshIconSettings(viewerKey)

  local items = PCMRuntime:GetViewerItems(viewerKey)
  for index = 1, #items do
    local itemFrame = items[index]
    local oldFrameData = PCMHooks.PeekFrameData(itemFrame)
    if oldFrameData and oldFrameData.iconSettingsRecord then
      _PCM_ClearNativeIconPresentation(itemFrame, viewerKey)
    end

    local frameData, record = _PCM_BindNativeIconSettings(itemFrame, viewerKey)
    if record then
      _PCM_ApplyNativeIconSettings(itemFrame, viewerKey, frameData)
      if frameData.iconSettingsNeedsCooldownState == true then
        _PCM_UpdateIconCooldownState(itemFrame, viewerKey, "SPELL_UPDATE_COOLDOWN", frameData)
      else
        _PCM_ApplyIconAppearance(itemFrame, viewerKey, frameData)
      end
    end

    self:_ApplyCooldownCountRule(itemFrame, viewerKey)
    self:_ApplyChargeCountRule(itemFrame, viewerKey)
    self:_ApplyDurationCountRule(itemFrame, viewerKey)
  end

  self:_RequestViewerRefresh("all", viewerKey)
end

_PCM_ApplyIconAppearance = function(itemFrame, viewerKey, frameData)
  if not itemFrame or not viewerKey then
    return
  end

  frameData = frameData or PCMHooks.PeekFrameData(itemFrame)
  if not frameData then
    return
  end

  local record = frameData.iconSettingsRecord
  local entry = frameData.iconIdentity
  if not record or not entry then
    return
  end

  local stateName = frameData.iconCooldownState or "UNKNOWN"
  local appearance = record.appearance
  local regions = IconSkin.ResolveCooldownViewerRegions(itemFrame)
  local icon = regions and regions.icon or nil

  local customTexture = appearance and appearance.texture or nil
  local reconcileTexture = frameData.iconCustomTextureNeedsReconcile == true
  if icon and customTexture ~= nil then
    if reconcileTexture or frameData.iconCustomTextureApplied ~= customTexture then
      icon:SetTexture(customTexture)
      frameData.iconCustomTextureApplied = customTexture
    end
    frameData.iconCustomTextureNeedsReconcile = nil
  elseif frameData.iconCustomTextureApplied ~= nil then
    frameData.iconCustomTextureApplied = nil
    frameData.iconCustomTextureNeedsReconcile = nil
    itemFrame:RefreshSpellTexture()
  else
    frameData.iconCustomTextureNeedsReconcile = nil
  end

  if stateName == "UNKNOWN" then
    _PCM_StopIconSettingsGlow(itemFrame, frameData)
    return
  end

  local alpha
  local saturation
  if stateName == "AURA" then
    alpha = appearance and appearance.auraAlpha or 1
    saturation = appearance and appearance.auraSaturation or nil
  elseif stateName == "COOLDOWN" then
    alpha = appearance and appearance.cooldownAlpha or 1
    saturation = appearance and appearance.cooldownSaturation or nil
  else
    alpha = appearance and appearance.readyAlpha or 1
    saturation = appearance and appearance.readySaturation or nil
  end

  if frameData.iconAppliedAlpha ~= alpha then
    frameData.iconAppliedAlpha = alpha
    if frameData.parked ~= true then
      itemFrame:SetAlpha(alpha)
    end
  end

  if icon and icon.SetDesaturation then
    if saturation ~= nil then
      local desaturation = 1 - math.max(0, math.min(1, tonumber(saturation) or 1))
      if frameData.iconAppliedSaturation ~= desaturation then
        icon:SetDesaturation(desaturation)
        frameData.iconAppliedSaturation = desaturation
      end
    elseif frameData.iconAppliedSaturation ~= nil then
      icon:SetDesaturation(0)
      frameData.iconAppliedSaturation = nil
    end
  end

  if alpha <= 0 then
    _PCM_StopIconSettingsGlow(itemFrame, frameData)
    if frameData.iconStateHidden ~= true then
      frameData.iconStateHidden = true
      itemFrame:SetTooltipsShown(false)
      _PCM_StopProcGlow(itemFrame, true)
    end
  else
    if frameData.iconStateHidden == true then
      frameData.iconStateHidden = nil
      itemFrame:SetTooltipsShown(Cooldowns:GetViewerTooltipsEnabled(viewerKey))
      if frameData.procGlowWanted == true then
        _PCM_StartProcGlow(itemFrame)
      end
    end
    _PCM_ApplyIconSettingsGlow(itemFrame, frameData, entry, stateName, appearance)
  end
end

function Cooldowns:ApplyNativeIndividualIconSettings(itemFrame, viewerKey, stateName)
  if not itemFrame or not viewerKey or _PCM_IsRefreshBlocked() then
    return
  end

  local frameData, record = _PCM_BindNativeIconSettings(itemFrame, viewerKey)
  if stateName then
    frameData.iconCooldownState = stateName
    if stateName == "AURA" then
      frameData.iconIsOnGCD = nil
    end
  end

  if record then
    _PCM_ApplyNativeIconSettings(itemFrame, viewerKey, frameData)
    _PCM_ApplyIconAppearance(itemFrame, viewerKey, frameData)
  end
  ns._PCM_ApplyUnifiedItemPass(itemFrame, viewerKey, true, false)
end

function Cooldowns:ClearNativeIndividualIconSettings(itemFrame, viewerKey)
  if not itemFrame or _PCM_IsRefreshBlocked() then
    return
  end
  _PCM_ClearNativeIconPresentation(itemFrame, viewerKey)
  IconSettings:ClearItemIdentity(itemFrame)
end

_PCM_UpdateIconCooldownState = function(itemFrame, viewerKey, event, frameData)
  frameData = frameData or PCMHooks.PeekFrameData(itemFrame)
  local entry = frameData and frameData.iconIdentity or nil
  local record = frameData and frameData.iconSettingsRecord or nil
  if not entry or entry.settingsFamily ~= "cooldown" then
    return
  end

  local stateName

  if entry.hasCharges then
    local chargeInfo = C_Spell.GetSpellCharges(entry.chargeSpellID)
    if _PCM_IsSecret(chargeInfo) then
      return
    end

    local chargeActive = chargeInfo and chargeInfo.isActive
    if _PCM_IsSecret(chargeActive) then
      return
    end

    stateName = chargeActive == true and "COOLDOWN" or "READY"

    if event == "SPELL_UPDATE_COOLDOWN" then
      local cooldownInfo = C_Spell.GetSpellCooldown(entry.cooldownSpellID)
      if not _PCM_IsSecret(cooldownInfo) then
        local isOnGCD = cooldownInfo and cooldownInfo.isOnGCD
        if not _PCM_IsSecret(isOnGCD) then
          frameData.iconIsOnGCD = isOnGCD == true
        else
          frameData.iconIsOnGCD = nil
        end
      else
        frameData.iconIsOnGCD = nil
      end
    else
      frameData.iconIsOnGCD = nil
    end
  else
    if event ~= "SPELL_UPDATE_COOLDOWN" then
      return
    end

    local cooldownInfo = C_Spell.GetSpellCooldown(entry.cooldownSpellID)
    if _PCM_IsSecret(cooldownInfo) then
      return
    end

    local cooldownActive = cooldownInfo and cooldownInfo.isActive
    local isOnGCD = cooldownInfo and cooldownInfo.isOnGCD
    if _PCM_IsSecret(cooldownActive) or _PCM_IsSecret(isOnGCD) then
      return
    end

    frameData.iconIsOnGCD = isOnGCD == true
    stateName = cooldownActive == true and isOnGCD ~= true and "COOLDOWN" or "READY"
  end

  local stateChanged = frameData.iconCooldownState ~= stateName
  frameData.iconCooldownState = stateName

  if frameData.iconSettingsNeedsSwipeRefresh == true then
    _PCM_ApplyNativeIconSettings(itemFrame, viewerKey, frameData)
  end
  if record and stateChanged then
    _PCM_ApplyIconAppearance(itemFrame, viewerKey, frameData)
  end
  if frameData.iconSettingsNeedsCountModeRefresh == true then
    _PCM_ApplyActiveCountRule(itemFrame, viewerKey)
  end
end

function Cooldowns:_ApplyEffectsToButton(itemFrame, viewerKey)
  if not itemFrame or not viewerKey then
    return
  end

  if not _PCM_IsModuleEnabledFast() then
    return
  end

  local st = PCMHooks.GetFrameData(itemFrame)
  if not st then
    return
  end

  if _PCM_IsEquipSlotCooldownItem(itemFrame) then
    st.isViewerIconButton = false
    if st.procGlowActive or st.procGlowPending or st.procGlowWanted then
      _PCM_StopProcGlow(itemFrame)
    end
    return
  end

  local isGlowViewer = _IsEssentialViewerKey(viewerKey) or viewerKey == "UtilityCooldownViewer"
  st.isViewerIconButton = isGlowViewer

  if not isGlowViewer then
    if st.procGlowActive or st.procGlowPending or st.procGlowWanted then
      _PCM_StopProcGlow(itemFrame)
    end
    return
  end

  if _PCM_IsGlowEnabledFast() ~= true then
    if st.procGlowActive or st.procGlowPending or st.procGlowWanted then
      _PCM_StopProcGlow(itemFrame)
    end
    return
  end

  if st.procGlowWanted == true then
    _PCM_StartProcGlow(itemFrame)
  end
end

function Cooldowns:RefreshViewerGlows()
  PCMGlowState.settings = nil
  local glowEnabled = (_PCM_IsGlowEnabled() == true)

  for _, info in Cooldowns:IterateViewers() do
    local key = info.key
    local viewer = PCMRuntime:GetViewer(key)
    if viewer then
      local items = _GetViewerItemFrames(viewer)
      for _, child in ipairs(items) do
        if child then
          local st = PCMHooks.GetFrameData(child)
          local keepWanted = st and st.procGlowWanted == true

          _PCM_StopProcGlow(child, keepWanted)

          if (not glowEnabled) and keepWanted then
            ns._PCM_SetBlizzardGlowShown(child, true)
          end

          self:_ApplyEffectsToButton(child, key)
        end
      end
    end
  end
end

function Cooldowns:_SetupGlowHooks()
  _PCM_GetGlowSettings()

  PCMHooks.HookGlowManager(
    _PCM_IsGlowEnabledFast,
    _PCM_StartProcGlow,
    _PCM_StopProcGlow
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
  _ConsumePendingExtraViewers()
  _PCM_RegisterEditModeParticipant(self)

  local enabled = _PCM_IsModuleEnabledFast()

  PCMHooks.SetRuntimeEnabled(enabled)
  self:SetEnabledState(enabled)
  ns.Modules.PCM_Buffs:SetEnabledState(enabled)
  ns.Modules.PCM_BuffBars:SetEnabledState(enabled)
  ns.Modules.PCM_BB:SetEnabledState(enabled)
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
  wipe(PCMIconRuntimeState.viewerSwipeOptions)
  PCMGlowState.db = nil
  PCMGlowState.enabled = nil
  PCMGlowState.settings = nil
  self._essentialDragEnabled = false
  self.__puiPCM_EditModeOn = false
  self.__puiPCM_BlizzardEditModeRetakePending = nil
  self.__puiPCMCustomTrackerStartupPending = nil

  PCMTransitionFlushFrame:Hide()
  PCMTransitionState.Queued = false
  PCMTransitionState.FlushQueued = false
  PCMTransitionState.Owner = nil
  PCMTransitionState.InvalidateClassSpellCache = false

  _DeactivatePCMOwnedFrames()
  PCMRuntime:ClearDirty()
  _PCM_ClearBlockedViewerRefreshQueue()

  self:_Keybinds_Disable()
  _PCM_SetChildModulesEnabled(false)

  PCMRuntime:Disable()
  PCMRuntime:SetSubscriberEnabled("Core", false)

end

function Cooldowns:SetModuleEnabled(enabled)
  if InCombatLockdown() then
    return false
  end

  local cm = Cooldowns._GetModuleDB()
  local want = enabled == true

  cm.enabled = want
  cm.__puiCVarChecked = true
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

local function _RunPCMStartupRefresh(self)
  if not self or not _PCM_IsModuleEnabledFast() then
    return false
  end

  if InCombatLockdown() then
    return false
  end

  if PCMHooks.IsAddonRestricted() then
    return false
  end

  if Addon:IsBlizzardEditModeActive() then
    return false
  end

  if not C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer") then
    C_AddOns.LoadAddOn("Blizzard_CooldownViewer")
  end

  return true
end

local function _PCM_RunInitialViewerPass(owner)
  if not _RunPCMStartupRefresh(owner) then
    return
  end

  for index = 1, #PCM_ICON_SETTINGS_VIEWERS do
    IconSettings:GetViewerEntries(PCM_ICON_SETTINGS_VIEWERS[index])
  end

  for _, info in owner:IterateViewers() do
    local key = info and info.key
    local frame = key and PCMRuntime:GetViewer(key) or nil
    if frame then
      _RegisterViewerMover(info)

    end
  end

  PCMRuntime:QueueAllViewerScans("initial-viewer-pass")
  PCMRuntime:MarkAllViewersDirty(PCM_REFRESH_FULL, "initial-viewer-pass")
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

  self._essentialDragEnabled = false
  PCMHooks.SetRuntimeEnabled(true)
  PCMHooks.HookEditMode(self)
  self:_SetupGlowHooks()

  PCMRuntime:SetSubscriberEnabled("Core", true)
  PCMRuntime:Enable()

  _PCM_SetChildModulesEnabled(true)
  self:_Keybinds_Enable()

  self.__puiFrameScale = Pixel.GetOnePixel()
  FrameScale:RegisterScaleListener(_PCM_OnFrameScaleChanged)

  _PCM_RunInitialViewerPass(self)
end

function Cooldowns:OnDisable()
  FrameScale:UnregisterScaleListener(_PCM_OnFrameScaleChanged)
  self.__puiFrameScale = nil
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
  self:SpellBars_RefreshAfterTalentSwap()
  self:CooldownStackBars_RefreshAfterTalentSwap()
  ns.Modules.PCM_BB.RefreshAfterTalentSwap()
  ns.PCM_RefreshCustomBarsOptionsAfterSpecializationChange()

  self.__puiPCMCustomTrackerStartupReconciled = true
end



function Cooldowns:_OnPlayerEnteringWorld()
  local cm = Cooldowns._GetModuleDB()
  local enabled = true

  if cm then
    local isFirstLogin = (cm.__puiFirstLoginDone ~= true)

    if isFirstLogin then
      -- First login: default ON (do NOT force Blizzard CVars).
      cm.enabled = true

      cm.__puiFirstLoginDone = true
      cm.__puiCVarChecked = true
      enabled = true
    else
      -- Not first login: honor the profile flag (no more auto CVar driving).
      cm.__puiCVarChecked = true
      enabled = (cm.enabled ~= false)
    end
  end

  if cm then
    PCMEnabled = enabled
  end

  if not enabled then
    return
  end

  _PCM_RunInitialViewerPass(self)
  self:_ReconcileCustomTrackerStartupAvailability()
end

function Cooldowns:_OnLoadingScreenDisabled()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  _PCM_RunInitialViewerPass(self)
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

  if _PCM_IsTransitionPending() then
    _PCM_QueueTransitionFlush()
    return
  end

  IconSettings:InvalidateCatalog()
  _PCM_InvalidateSkinCache()
  _PCM_RunInitialViewerPass(self)
end

function Cooldowns:_OnCooldownViewerTableHotfixed()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  if _PCM_IsTransitionPending() then
    _PCM_QueueTransitionFlush()
    return
  end

  IconSettings:InvalidateCatalog()
  PCMViewerState.ItemGen = (PCMViewerState.ItemGen or 0) + 1

  _PCM_MarkCountRulesDirty()

  _PCM_RunHardViewerTransition(self)
end

function Cooldowns:_OnSpellsChanged()
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  if _PCM_IsTransitionPending() then
    _PCM_QueueTransitionFlush()
    return
  end

  if not InCombatLockdown() then
    IconSettings:InvalidateCatalog()
  end
end

local function _PCM_RuntimeLifecycleEvent(event, ...)
  if not _PCM_IsModuleEnabledFast() then
    return
  end

  local arg1, arg2 = ...

  if event == "PLAYER_ENTERING_WORLD" then
    Cooldowns:_OnPlayerEnteringWorld()
  elseif event == "LOADING_SCREEN_DISABLED" then
    Cooldowns:_OnLoadingScreenDisabled()
  elseif event == "PLAYER_REGEN_ENABLED" then
    Cooldowns:_OnRegenEnabled()
  elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
    if arg2 == Enum.AddOnRestrictionState.Inactive then
      Cooldowns:FlushPendingEditModeChanges()
      _PCM_FlushBlockedViewerRefresh(Cooldowns)
    end
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    Cooldowns:_OnPlayerSpecializationChanged(event, arg1)
  elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
    or event == "PLAYER_TALENT_UPDATE"
    or event == "ACTIVE_TALENT_GROUP_CHANGED"
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
  end
end

PCMRuntime:RegisterSubscriber("Core", {
  OnViewerChanged = function(key, viewer, previousViewer)
    if not _PCM_IsCoreViewerKey(key) then
      return
    end

    if previousViewer then
      PCMFrameState.ViewerFrameKey[previousViewer] = nil
    end

    if viewer then
      PCMFrameState.ViewerFrameKey[viewer] = key
      _EnsurePCMViewerMoverForKey(key)
    end
  end,

  OnItemAcquired = function(key, viewer, itemFrame, _, expectInitialRebind)
    if _PCM_IsCoreViewerKey(key) then
      _PCM_HandleViewerAcquire(viewer, key, itemFrame, false, expectInitialRebind)
    end
  end,

  OnItemReleased = function(key, viewer, itemFrame)
    if _PCM_IsCoreViewerKey(key) then
      _PCM_HandleViewerRelease(viewer, itemFrame)
    end
  end,

  OnItemRebound = function(key, viewer, itemFrame, initialBind)
    if _PCM_IsCoreViewerKey(key) then
      if initialBind ~= true then
        IconSettings:ClearItemBinding(itemFrame)
      end
      _PCM_HandleViewerAcquire(viewer, key, itemFrame, true)
    end
  end,



  OnViewerDirty = function(key, viewer, mask)
    if not _PCM_IsCoreViewerKey(key) then
      return
    end

    local coreMask = mask or 0
    if PCMRuntime:MaskHas(coreMask, PCMRuntime.Dirty.VISIBILITY)
      and viewer
      and viewer:IsShown()
    then
      coreMask = _PCM_RefreshMaskAdd(coreMask, PCM_REFRESH_LAYOUT)
    end

    if _PCM_IsRefreshBlocked() then
      _PCM_QueueBlockedViewerRefresh(coreMask, key)
      return
    end

    _PCM_ExecuteViewerRefresh(Cooldowns, coreMask, key)
  end,

  OnLifecycleEvent = _PCM_RuntimeLifecycleEvent,
})

function Cooldowns:ApplySettings(flags)
  if not flags then
    return
  end

  if flags.profile == true then
    local enabled = PCM_DB.IsPCMEnabled() == true
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
    IconSettings:InvalidateCatalog()
    IconSettings:InvalidateSettings()
    self:InvalidateNativeIconViewerCache()
    PCMGlowState.db = nil
    PCMGlowState.enabled = nil
    PCMGlowState.settings = nil
    _PCM_GetGlowSettings()
    PCMViewerState.ItemGen = (PCMViewerState.ItemGen or 0) + 1
    needsIconRefresh = true

    _PCM_InvalidateViewerRuleSettingCache()
    _PCM_PrimeViewerCountCache()
    _PCM_MarkCountRulesDirty()
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
    _PCM_InvalidateStaticPresentation()
    _RefreshIconViewers(nil)
  elseif needsFontRefresh then
    _RefreshViewerFontsOnly(nil)
  end

  if flags.profile == true then
    self:ApplyKeybindTextRulesNow(nil)
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
  _TryHookExistingViewers()
  self:_RequestViewerRefresh("layout")

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

  if PCMHooks.IsAddonRestricted() then
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

  _PCM_RunHardViewerTransition(self)
end

  Cooldowns.ApplyCustomBarsCDMProfile = P:Def('Cooldowns:ApplyCustomBarsCDMProfile', Cooldowns.ApplyCustomBarsCDMProfile)
  Cooldowns.ExportCustomBars = P:Def('Cooldowns:ExportCustomBars', Cooldowns.ExportCustomBars)
  Cooldowns.ImportCustomBarsString = P:Def('Cooldowns:ImportCustomBarsString', Cooldowns.ImportCustomBarsString)
  RoundPixel = P:Def('RoundPixel', RoundPixel)
  _PUI_SetPointStamped = P:Def('_PUI_SetPointStamped', _PUI_SetPointStamped)
  _PUI_SetAllPointsStamped = P:Def('_PUI_SetAllPointsStamped', _PUI_SetAllPointsStamped)
  _PCM_GetViewerCategoryEnum = P:Def('_PCM_GetViewerCategoryEnum', _PCM_GetViewerCategoryEnum)
  _PCM_GetViewerKeyFromFrame = P:Def('_PCM_GetViewerKeyFromFrame', _PCM_GetViewerKeyFromFrame)
  _PCM_GetConfiguredViewerEntryCount = P:Def('_PCM_GetConfiguredViewerEntryCount', _PCM_GetConfiguredViewerEntryCount)
  _PCM_ItemHasRenderableContent = P:Def('_PCM_ItemHasRenderableContent', _PCM_ItemHasRenderableContent)
  _PCM_IsModuleEnabledFast = P:Def('_PCM_IsModuleEnabledFast', _PCM_IsModuleEnabledFast)
  ns.PCM_IsModuleEnabledFast = _PCM_IsModuleEnabledFast
  Cooldowns.RegisterExtraViewer = P:Def('Cooldowns:RegisterExtraViewer', Cooldowns.RegisterExtraViewer)
  _ConsumePendingExtraViewers = P:Def('_ConsumePendingExtraViewers', _ConsumePendingExtraViewers)
  _IsEssentialViewerKey = P:Def('_IsEssentialViewerKey', _IsEssentialViewerKey)
  _RebuildViewerRegistry = P:Def('_RebuildViewerRegistry', _RebuildViewerRegistry)
  Cooldowns.IterateViewers = P:Def('Cooldowns:IterateViewers', Cooldowns.IterateViewers)
  Cooldowns.GetViewerInfo = P:Def('Cooldowns:GetViewerInfo', Cooldowns.GetViewerInfo)
  Cooldowns.GetViewerFrame = P:Def('Cooldowns:GetViewerFrame', Cooldowns.GetViewerFrame)
  _PCM_IsEditModeLayoutMutationBlocked = P:Def('_PCM_IsEditModeLayoutMutationBlocked', _PCM_IsEditModeLayoutMutationBlocked)
  _PCM_EnsureEditModeLayout = P:Def('_PCM_EnsureEditModeLayout', _PCM_EnsureEditModeLayout)
  _PCM_EnsureEditableEditModeLayout = P:Def('_PCM_EnsureEditableEditModeLayout', _PCM_EnsureEditableEditModeLayout)
  _PCM_GetViewerEditModeCheckbox = P:Def('_PCM_GetViewerEditModeCheckbox', _PCM_GetViewerEditModeCheckbox)
  _PCM_SetViewerEditModeCheckbox = P:Def('_PCM_SetViewerEditModeCheckbox', _PCM_SetViewerEditModeCheckbox)
  Cooldowns.FlushPendingEditModeChanges = P:Def('Cooldowns:FlushPendingEditModeChanges', Cooldowns.FlushPendingEditModeChanges)
  Cooldowns.CanChangeViewerEditModeSettings = P:Def('Cooldowns:CanChangeViewerEditModeSettings', Cooldowns.CanChangeViewerEditModeSettings)
  Cooldowns.GetViewerTooltipsEnabled = P:Def('Cooldowns:GetViewerTooltipsEnabled', Cooldowns.GetViewerTooltipsEnabled)
  Cooldowns.SetViewerTooltipsEnabled = P:Def('Cooldowns:SetViewerTooltipsEnabled', Cooldowns.SetViewerTooltipsEnabled)
  Cooldowns.GetViewerHideWhenInactive = P:Def('Cooldowns:GetViewerHideWhenInactive', Cooldowns.GetViewerHideWhenInactive)
  Cooldowns.SetViewerHideWhenInactive = P:Def('Cooldowns:SetViewerHideWhenInactive', Cooldowns.SetViewerHideWhenInactive)
  _DeactivatePCMOwnedFrames = P:Def('_DeactivatePCMOwnedFrames', _DeactivatePCMOwnedFrames)
  _PCM_IsRefreshBlocked = P:Def('_PCM_IsRefreshBlocked', _PCM_IsRefreshBlocked)
  _GetViewerItemFrames = P:Def('_GetViewerItemFrames', _GetViewerItemFrames)
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
  _GetChargeFontString = P:Def('_GetChargeFontString', _GetChargeFontString)
  _PCM_FetchFontPath = P:Def('_PCM_FetchFontPath', _PCM_FetchFontPath)
  _PCM_ApplyFontOptsToFontString = P:Def('_PCM_ApplyFontOptsToFontString', _PCM_ApplyFontOptsToFontString)
  Cooldowns._ApplyFontsToItem = P:Def('Cooldowns._ApplyFontsToItem', Cooldowns._ApplyFontsToItem)
  ns._PCM_ShouldSkipUnifiedItemPass = P:Def('ns._PCM_ShouldSkipUnifiedItemPass', ns._PCM_ShouldSkipUnifiedItemPass)
  ns._PCM_ApplyUnifiedItemPass = P:Def('ns._PCM_ApplyUnifiedItemPass', ns._PCM_ApplyUnifiedItemPass)
  ns._PCM_RunUnifiedViewerItemPass = P:Def('ns._PCM_RunUnifiedViewerItemPass', ns._PCM_RunUnifiedViewerItemPass)
  Cooldowns.ApplyCooldownCountRulesNow = P:Def('Cooldowns:ApplyCooldownCountRulesNow', Cooldowns.ApplyCooldownCountRulesNow)
  _PCM_GetDurationCountEnabledCached = P:Def('_PCM_GetDurationCountEnabledCached', _PCM_GetDurationCountEnabledCached)
  _PCM_GetSwipeFlagsCached = P:Def('_PCM_GetSwipeFlagsCached', _PCM_GetSwipeFlagsCached)
  _ShouldUseAuraCooldownOverride = P:Def('_ShouldUseAuraCooldownOverride', _ShouldUseAuraCooldownOverride)
  Cooldowns.SetDurationCountEnabled = P:Def('Cooldowns:SetDurationCountEnabled', Cooldowns.SetDurationCountEnabled)
  Cooldowns.GetDurationCountEnabled = P:Def('Cooldowns:GetDurationCountEnabled', Cooldowns.GetDurationCountEnabled)
  Cooldowns._ApplyDurationCountRule = P:Def('Cooldowns:_ApplyDurationCountRule', Cooldowns._ApplyDurationCountRule)
  _ResolveViewerKeyFromItem = P:Def('_ResolveViewerKeyFromItem', _ResolveViewerKeyFromItem)
  _ApplyBorderToFrame = P:Def('_ApplyBorderToFrame', _ApplyBorderToFrame)
  _ApplyBorderInsets = P:Def('_ApplyBorderInsets', _ApplyBorderInsets)
  Cooldowns.InvalidateNativeIconViewerCache = P:Def('Cooldowns:InvalidateNativeIconViewerCache', Cooldowns.InvalidateNativeIconViewerCache)
  _PCM_GetViewerSwipeOptions = P:Def('_PCM_GetViewerSwipeOptions', _PCM_GetViewerSwipeOptions)
  _PCM_ApplyForcedCooldownSource = P:Def('_PCM_ApplyForcedCooldownSource', _PCM_ApplyForcedCooldownSource)
  _PCM_ApplyNativeIconSettings = P:Def('_PCM_ApplyNativeIconSettings', _PCM_ApplyNativeIconSettings)
  _PCM_UpdateBoundIconRuntimeFlags = P:Def('_PCM_UpdateBoundIconRuntimeFlags', _PCM_UpdateBoundIconRuntimeFlags)
  _PCM_HookNativeIconRefresh = P:Def('_PCM_HookNativeIconRefresh', _PCM_HookNativeIconRefresh)
  _PCM_BindNativeIconSettings = P:Def('_PCM_BindNativeIconSettings', _PCM_BindNativeIconSettings)
  _PCM_GetItemIconSize = P:Def('_PCM_GetItemIconSize', _PCM_GetItemIconSize)
  _PCM_ApplyStaticItemPresentation = P:Def('_PCM_ApplyStaticItemPresentation', _PCM_ApplyStaticItemPresentation)
  _PCM_RefreshItemBinding = P:Def('_PCM_RefreshItemBinding', _PCM_RefreshItemBinding)
  _ReskinItemFrame = P:Def('_ReskinItemFrame', _ReskinItemFrame)
  _PUI_SetIconDesired = P:Def('_PUI_SetIconDesired', _PUI_SetIconDesired)
  _PUI_SetIconInProxy = P:Def('_PUI_SetIconInProxy', _PUI_SetIconInProxy)
  _LayoutTwoRowWrap = P:Def('_LayoutTwoRowWrap', _LayoutTwoRowWrap)
  _PCM_GetLayoutIndex = P:Def('_PCM_GetLayoutIndex', _PCM_GetLayoutIndex)
  _PCM_CompareIconLayoutOrder = P:Def('_PCM_CompareIconLayoutOrder', _PCM_CompareIconLayoutOrder)
  _PCM_SortIconsByLayoutOrder = P:Def('_PCM_SortIconsByLayoutOrder', _PCM_SortIconsByLayoutOrder)
  _PCM_GetStableItemObjectID = P:Def('_PCM_GetStableItemObjectID', _PCM_GetStableItemObjectID)
  _PCM_HasViewerLayoutChanged = P:Def('_PCM_HasViewerLayoutChanged', _PCM_HasViewerLayoutChanged)
  _PCM_CollectVisibleIcons = P:Def('_PCM_CollectVisibleIcons', _PCM_CollectVisibleIcons)
  _PCM_GetSpacingForViewer = P:Def('_PCM_GetSpacingForViewer', _PCM_GetSpacingForViewer)
  _PCM_GetBorderPadForViewer = P:Def('_PCM_GetBorderPadForViewer', _PCM_GetBorderPadForViewer)
  _PCM_GetViewerCols = P:Def('_PCM_GetViewerCols', _PCM_GetViewerCols)
  _PCM_GetViewerRowGrowth = P:Def('_PCM_GetViewerRowGrowth', _PCM_GetViewerRowGrowth)
  _PCM_GetIconSizeForViewer = P:Def('_PCM_GetIconSizeForViewer', _PCM_GetIconSizeForViewer)
  _PCM_PreSizeIconsIfNeeded = P:Def('_PCM_PreSizeIconsIfNeeded', _PCM_PreSizeIconsIfNeeded)
  _PCM_ApplyWrappedOnly = P:Def('_PCM_ApplyWrappedOnly', _PCM_ApplyWrappedOnly)
  _PCM_ResetAcquiredItemState = P:Def('_PCM_ResetAcquiredItemState', _PCM_ResetAcquiredItemState)
  _PCM_HandleViewerAcquire = P:Def('_PCM_HandleViewerAcquire', _PCM_HandleViewerAcquire)
  _PCM_HandleViewerRelease = P:Def('_PCM_HandleViewerRelease', _PCM_HandleViewerRelease)
  _PCM_InvalidateBuildKey = P:Def('_PCM_InvalidateBuildKey', _PCM_InvalidateBuildKey)
  _PCM_InvalidateStaticPresentation = P:Def('_PCM_InvalidateStaticPresentation', _PCM_InvalidateStaticPresentation)
  _PCM_InvalidateSkinCache = P:Def('_PCM_InvalidateSkinCache', _PCM_InvalidateSkinCache)
  _PCM_InvalidateClassSpellCache = P:Def('_PCM_InvalidateClassSpellCache', _PCM_InvalidateClassSpellCache)
  _PCM_BeginTransition = P:Def('_PCM_BeginTransition', _PCM_BeginTransition)
  _PCM_ParkViewerItem = P:Def('_PCM_ParkViewerItem', _PCM_ParkViewerItem)
  _PCM_ParkRuntimeViewerItems = P:Def('_PCM_ParkRuntimeViewerItems', _PCM_ParkRuntimeViewerItems)
  _PCM_MarkAllViewersDirty = P:Def('_PCM_MarkAllViewersDirty', _PCM_MarkAllViewersDirty)
  _PCM_RunHardViewerTransition = P:Def('_PCM_RunHardViewerTransition', _PCM_RunHardViewerTransition)
  _PCM_ReconcileRuntimeViewers = P:Def('_PCM_ReconcileRuntimeViewers', _PCM_ReconcileRuntimeViewers)
  _PCM_EnsureDataProviderHook = P:Def('_PCM_EnsureDataProviderHook', _PCM_EnsureDataProviderHook)
  _PCM_FinalizeTransition = P:Def('_PCM_FinalizeTransition', _PCM_FinalizeTransition)
  _GetOrCreateViewerAnchorFrame = P:Def('_GetOrCreateViewerAnchorFrame', _GetOrCreateViewerAnchorFrame)
  Cooldowns.GetViewerAnchorFrame = P:Def('Cooldowns:GetViewerAnchorFrame', Cooldowns.GetViewerAnchorFrame)
  _ForceAnchor = P:Def('_ForceAnchor', _ForceAnchor)
  _ProtectViewerAnchors_Icons = P:Def('_ProtectViewerAnchors_Icons', _ProtectViewerAnchors_Icons)
  Cooldowns._OnRegenEnabled = P:Def('Cooldowns:_OnRegenEnabled', Cooldowns._OnRegenEnabled)
  _EnsureDefaultViewerAnchor = P:Def('_EnsureDefaultViewerAnchor', _EnsureDefaultViewerAnchor)
  _RegisterViewerMover = P:Def('_RegisterViewerMover', _RegisterViewerMover)
  _InitAllViewerMovers = P:Def('_InitAllViewerMovers', _InitAllViewerMovers)
  _ForEachRefreshViewer = P:Def('_ForEachRefreshViewer', _ForEachRefreshViewer)
  _RefreshViewerBordersOnly = P:Def('_RefreshViewerBordersOnly', _RefreshViewerBordersOnly)
  _RefreshSingleViewerIcons = P:Def('_RefreshSingleViewerIcons', _RefreshSingleViewerIcons)
  _RefreshViewerFontsOnly = P:Def('_RefreshViewerFontsOnly', _RefreshViewerFontsOnly)
  _RefreshIconViewers = P:Def('_RefreshIconViewers', _RefreshIconViewers)
  Cooldowns.RefreshIndividualIconSettings = P:Def('Cooldowns:RefreshIndividualIconSettings', Cooldowns.RefreshIndividualIconSettings)
  Cooldowns.ApplyNativeIndividualIconSettings = P:Def('Cooldowns:ApplyNativeIndividualIconSettings', Cooldowns.ApplyNativeIndividualIconSettings)
  Cooldowns.ClearNativeIndividualIconSettings = P:Def('Cooldowns:ClearNativeIndividualIconSettings', Cooldowns.ClearNativeIndividualIconSettings)
  Cooldowns.RefreshIconFonts = P:Def('Cooldowns:RefreshIconFonts', Cooldowns.RefreshIconFonts)
  _RetakeBlizzardEditModeOwnership = P:Def('_RetakeBlizzardEditModeOwnership', _RetakeBlizzardEditModeOwnership)
  Cooldowns._OnEditModeChanged = P:Def('Cooldowns:_OnEditModeChanged', Cooldowns._OnEditModeChanged)
  Cooldowns._OnBlizzardEditModeChanged = P:Def('Cooldowns:_OnBlizzardEditModeChanged', Cooldowns._OnBlizzardEditModeChanged)
  _ApplyPCMProfile = P:Def('_ApplyPCMProfile', _ApplyPCMProfile)
  _EnsurePCMViewerMoverForKey = P:Def('_EnsurePCMViewerMoverForKey', _EnsurePCMViewerMoverForKey)
  _TryHookExistingViewers = P:Def('_TryHookExistingViewers', _TryHookExistingViewers)
  _PCM_GetViewerRefreshMask = P:Def('_PCM_GetViewerRefreshMask', _PCM_GetViewerRefreshMask)
  Cooldowns._RequestViewerRefresh = P:Def('Cooldowns:_RequestViewerRefresh', Cooldowns._RequestViewerRefresh)
  Cooldowns._FlushViewerRefreshImmediate = P:Def('Cooldowns:_FlushViewerRefreshImmediate', Cooldowns._FlushViewerRefreshImmediate)
  _PCM_GetGlowDB = P:Def('_PCM_GetGlowDB', _PCM_GetGlowDB)
  _PCM_IsGlowEnabled = P:Def('_PCM_IsGlowEnabled', _PCM_IsGlowEnabled)
  _PCM_IsGlowEnabledFast = P:Def('_PCM_IsGlowEnabledFast', _PCM_IsGlowEnabledFast)
  ns._PCM_SetBlizzardGlowShown = P:Def('ns._PCM_SetBlizzardGlowShown', ns._PCM_SetBlizzardGlowShown)
  _PCM_GetGlowSettings = P:Def('_PCM_GetGlowSettings', _PCM_GetGlowSettings)
  Cooldowns._ApplyEffectsToButton = P:Def('Cooldowns:_ApplyEffectsToButton', Cooldowns._ApplyEffectsToButton)
  Cooldowns.RefreshViewerGlows = P:Def('Cooldowns:RefreshViewerGlows', Cooldowns.RefreshViewerGlows)
  Cooldowns._SetupGlowHooks = P:Def('Cooldowns:_SetupGlowHooks', Cooldowns._SetupGlowHooks)
  _PCM_RegisterEditModeParticipant = P:Def('_PCM_RegisterEditModeParticipant', _PCM_RegisterEditModeParticipant)
  Cooldowns.OnInitialize = P:Def('Cooldowns:OnInitialize', Cooldowns.OnInitialize)
  _PCM_SetOneChildModuleEnabled = P:Def('_PCM_SetOneChildModuleEnabled', _PCM_SetOneChildModuleEnabled)
  _PCM_SetChildModulesEnabled = P:Def('_PCM_SetChildModulesEnabled', _PCM_SetChildModulesEnabled)
  Cooldowns._PCM_RunDisableTeardown = P:Def('Cooldowns:_PCM_RunDisableTeardown', Cooldowns._PCM_RunDisableTeardown)
  Cooldowns.SetModuleEnabled = P:Def('Cooldowns:SetModuleEnabled', Cooldowns.SetModuleEnabled)
  _RunPCMStartupRefresh = P:Def('_RunPCMStartupRefresh', _RunPCMStartupRefresh)
  _PCM_RunInitialViewerPass = P:Def('_PCM_RunInitialViewerPass', _PCM_RunInitialViewerPass)
  Cooldowns.OnEnable = P:Def('Cooldowns:OnEnable', Cooldowns.OnEnable)
  Cooldowns.OnDisable = P:Def('Cooldowns:OnDisable', Cooldowns.OnDisable)
  Cooldowns._ReconcileCustomTrackerStartupAvailability = P:Def('Cooldowns:_ReconcileCustomTrackerStartupAvailability', Cooldowns._ReconcileCustomTrackerStartupAvailability)
  Cooldowns._OnPlayerEnteringWorld = P:Def('Cooldowns:_OnPlayerEnteringWorld', Cooldowns._OnPlayerEnteringWorld)
  Cooldowns._OnLoadingScreenDisabled = P:Def('Cooldowns:_OnLoadingScreenDisabled', Cooldowns._OnLoadingScreenDisabled)
  Cooldowns._OnPlayerSpecializationChanged = P:Def('Cooldowns:_OnPlayerSpecializationChanged', Cooldowns._OnPlayerSpecializationChanged)
  Cooldowns._OnTraitConfigUpdated = P:Def('Cooldowns:_OnTraitConfigUpdated', Cooldowns._OnTraitConfigUpdated)
  Cooldowns._OnCooldownViewerDataLoaded = P:Def('Cooldowns:_OnCooldownViewerDataLoaded', Cooldowns._OnCooldownViewerDataLoaded)
  Cooldowns._OnCooldownViewerTableHotfixed = P:Def('Cooldowns:_OnCooldownViewerTableHotfixed', Cooldowns._OnCooldownViewerTableHotfixed)
  Cooldowns._OnSpellsChanged = P:Def('Cooldowns:_OnSpellsChanged', Cooldowns._OnSpellsChanged)
  Cooldowns.ApplySettings = P:Def('Cooldowns:ApplySettings', Cooldowns.ApplySettings)
  Cooldowns.SoftRebuild = P:Def('Cooldowns:SoftRebuild', Cooldowns.SoftRebuild)
  Cooldowns.OnProfileChanged = P:Def('Cooldowns:OnProfileChanged', Cooldowns.OnProfileChanged)
  _PCM_GetEquipSlot = P:Def('_PCM_GetEquipSlot', _PCM_GetEquipSlot)
  _PCM_IsEquipSlotCooldownItem = P:Def('_PCM_IsEquipSlotCooldownItem', _PCM_IsEquipSlotCooldownItem)
  _PCM_IsTransitionPending = P:Def('_PCM_IsTransitionPending', _PCM_IsTransitionPending)
  _PCM_AddCategory = P:Def('_PCM_AddCategory', _PCM_AddCategory)
  _PCM_GetViewerCategoryList = P:Def('_PCM_GetViewerCategoryList', _PCM_GetViewerCategoryList)
  _PCM_FlushTransition = P:Def('_PCM_FlushTransition', _PCM_FlushTransition)
  _PCM_QueueTransitionFlush = P:Def('_PCM_QueueTransitionFlush', _PCM_QueueTransitionFlush)
  _PCM_RefreshMaskAdd = P:Def('_PCM_RefreshMaskAdd', _PCM_RefreshMaskAdd)
  _PCM_MergeRefreshMask = P:Def('_PCM_MergeRefreshMask', _PCM_MergeRefreshMask)
  _PCM_SetDirtyViewerMask = P:Def('_PCM_SetDirtyViewerMask', _PCM_SetDirtyViewerMask)
  _PCM_ExecuteViewerRefresh = P:Def('_PCM_ExecuteViewerRefresh', _PCM_ExecuteViewerRefresh)
  _PCM_StartProcGlow = P:Def('_PCM_StartProcGlow', _PCM_StartProcGlow)
  _PCM_StopProcGlow = P:Def('_PCM_StopProcGlow', _PCM_StopProcGlow)
  Cooldowns._ApplyCooldownCountRule = P:Def('Cooldowns:_ApplyCooldownCountRule', Cooldowns._ApplyCooldownCountRule)
  _PCM_ApplyActiveCountRule = P:Def('_PCM_ApplyActiveCountRule', _PCM_ApplyActiveCountRule)
  Cooldowns._ApplyBuffCountRule = P:Def('Cooldowns:_ApplyBuffCountRule', Cooldowns._ApplyBuffCountRule)
  Cooldowns._ApplyChargeCountRule = P:Def('Cooldowns:_ApplyChargeCountRule', Cooldowns._ApplyChargeCountRule)
  _PCM_AddCustomBarSpellID = P:Def('_PCM_AddCustomBarSpellID', _PCM_AddCustomBarSpellID)
  _PCM_GetCustomBarInfoSpellSet = P:Def('_PCM_GetCustomBarInfoSpellSet', _PCM_GetCustomBarInfoSpellSet)
  Cooldowns.ResolveCustomBarAuraEntry = P:Def('Cooldowns:ResolveCustomBarAuraEntry', Cooldowns.ResolveCustomBarAuraEntry)
  _PCM_MarkCountRulesDirty = P:Def('_PCM_MarkCountRulesDirty', _PCM_MarkCountRulesDirty)
  _EnsureViewerDurationCount = P:Def('_EnsureViewerDurationCount', _EnsureViewerDurationCount)
  _ApplyIconSizeToItemFrame = P:Def('_ApplyIconSizeToItemFrame', _ApplyIconSizeToItemFrame)
  Cooldowns._ApplyIconSizeToItemFrame = _ApplyIconSizeToItemFrame
  _PCM_ItemHasLayoutIndex = P:Def('_PCM_ItemHasLayoutIndex', _PCM_ItemHasLayoutIndex)
  _ApplySimpleViewerLayout = P:Def('_ApplySimpleViewerLayout', _ApplySimpleViewerLayout)
  Cooldowns._RefreshViewerBordersOnly = P:Def('Cooldowns._RefreshViewerBordersOnly', Cooldowns._RefreshViewerBordersOnly)
  Cooldowns._RefreshViewerFontsOnly = P:Def('Cooldowns._RefreshViewerFontsOnly', Cooldowns._RefreshViewerFontsOnly)
  _PCM_StopLibGlow = P:Def('_PCM_StopLibGlow', _PCM_StopLibGlow)
  _PCM_StopIconSettingsGlow = P:Def('_PCM_StopIconSettingsGlow', _PCM_StopIconSettingsGlow)
  _PCM_ApplyIconSettingsGlow = P:Def('_PCM_ApplyIconSettingsGlow', _PCM_ApplyIconSettingsGlow)
  _PCM_ClearNativeIconPresentation = P:Def('_PCM_ClearNativeIconPresentation', _PCM_ClearNativeIconPresentation)
  _PCM_ApplyIconAppearance = P:Def('_PCM_ApplyIconAppearance', _PCM_ApplyIconAppearance)
  _PCM_UpdateIconCooldownState = P:Def('_PCM_UpdateIconCooldownState', _PCM_UpdateIconCooldownState)
  _PCM_ClearBlockedViewerRefreshQueue = P:Def('_PCM_ClearBlockedViewerRefreshQueue', _PCM_ClearBlockedViewerRefreshQueue)
  _PCM_QueueBlockedViewerRefresh = P:Def('_PCM_QueueBlockedViewerRefresh', _PCM_QueueBlockedViewerRefresh)
  _PCM_FlushBlockedViewerRefresh = P:Def('_PCM_FlushBlockedViewerRefresh', _PCM_FlushBlockedViewerRefresh)
  Cooldowns._GetGlowDB = _PCM_GetGlowDB
  Cooldowns._OnViewersRefreshedForCountRules = P:Def('Cooldowns:_OnViewersRefreshedForCountRules', Cooldowns._OnViewersRefreshedForCountRules)
  _PCM_RunCountRulePassIfNeeded = P:Def('_PCM_RunCountRulePassIfNeeded', _PCM_RunCountRulePassIfNeeded)
