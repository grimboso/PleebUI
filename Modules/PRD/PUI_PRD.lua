
local ADDON_NAME, ns = ...



-- Core addon
local Addon = ns.Addon

-- Shared helpers from PleebUI core
local FrameUtil = ns.FrameUtil
local Pixel = ns.Pixel
local Round = Pixel.Round

local Theme     = ns.Theme
local LSM       = ns.LSM
local EditModeOverride = LibStub("LibEditModeOverride-1.0")
local SHOW_BAR_TEXT_SETTING = Enum.EditModePersonalResourceDisplaySetting.ShowBarText
local PLAYER_CLASS = select(2, UnitClass("player"))

local M = Addon:NewModule("PRD", "NumyAceEvent-3.0")
M._puiResourceConfigCache = {}

-- Central registry references (match PleebUI pattern)
ns.Registry.PRD         = M
ns.Modules.PRD          = M
ns.Registry.Modules.PRD = M

local P, TrackThis = ns.Pleebug:DropIn({}, {
  name = "PRD",
  bucket = "Core",
})


local defaults = {
  profile = {
    enabled = true,
    locked  = false,

    anchor = {
      point    = "CENTER",
      rel      = "UIParent",
      relPoint = "CENTER",
      x        = 0,
      y        = -250,
    },


    size = {
      width = 250,
      gap   = 0,
    },

    appearance = {
      unified       = true,
      height        = 15,
      texture       = "Pleebar",
      squareTexture = true,
      style = {
        borderColor = { 0.20, 0.20, 0.24, 1.00 },
        borderSize  = 1,
        bgColor     = { 0, 0, 0, 0.65 },
      },
      text = {
        size = 14,
        flags = "",
        useGlobalFont = true,
      },
    },

    outerBorder = {
      enabled = false,
      size = 1,
      color = { 0.20, 0.20, 0.24, 1.00 },
    },

    health = {
      height                 = 15,
      texture                = "Pleebar",
      squareTexture          = true,
      style = {
        borderColor = { 0.20, 0.20, 0.24, 1.00 },
        borderSize  = 1,
        bgColor     = { 0, 0, 0, 0.65 },
      },
      text = {
        size = 14,
        flags = "",
        useGlobalFont = true,
      },
      colorMode              = "DEFAULT",
      useCustomColor         = false,
      useBlizzardHealthColor = true,
      customColor            = { 1, 1, 1, 1 },
    },

    hideHealth  = false,
    hidePrimary = false,
    usePlayerHealth = false,
    stackOrder = { "health", "primary" },

    primary = {
      height                 = 15,
      texture                = "Pleebar",
      squareTexture          = true,
      style = {
        borderColor = { 0.20, 0.20, 0.24, 1.00 },
        borderSize  = 1,
        bgColor     = { 0, 0, 0, 0.65 },
      },
      text = {
        size = 14,
        flags = "",
        useGlobalFont = true,
      },
      detached              = false,
      hideAlternateMana     = false,
      colorMode             = "DEFAULT",
      useCustomColor        = false,
      useBlizzardPowerColor = true,
      customColor           = { 1, 1, 1, 1 },
      ticks = {
        enabled  = false,
        maxValue = 0,
        entries  = {},
      },

      anchor = {

        point = "CENTER",
        x     = 0,
        y     = -250,
      },
      width = nil,
    },

    secondary = {
      enabled               = true,
      detached              = false,
      height                = 15,
      perSegment            = false,
      texture               = "Pleebar",
      style = {
        borderColor = { 0.20, 0.20, 0.24, 1.00 },
        borderSize  = 1,
        bgColor     = { 0, 0, 0, 0.65 },
      },
      useCustomColor        = false,
      useBlizzardPowerColor = true,
      customColor           = { 1, 1, 1, 1 },
      visibilityMode        = "ALWAYS",
      resourceEnabled       = {},
      resourceSettings      = {},
      inactiveAlpha         = 0.15,
      showDividers          = true,
      dividerSize           = 1,
      dividerColor          = { 0.20, 0.20, 0.24, 1.00 },
      gap       = 2,

      anchor = {
        point = "CENTER",
        x     = 0,
        y     = -230,
      },
      width = nil,
    },

    text = {
      health = {
        leftVisibility = "ALWAYS",
        rightVisibility = "HIDE",
        centerText = true,
        left = {
          size = 14,
          flags = "",
          useGlobalFont = true,
        },
        right = {
          size = 14,
          flags = "",
          useGlobalFont = true,
        },
      },
      primary = {
        leftVisibility = "HIDE",
        rightVisibility = "ALWAYS",
        centerText = true,
        left = {
          size = 14,
          flags = "",
          useGlobalFont = true,
        },
        right = {
          size = 14,
          flags = "",
          useGlobalFont = true,
        },
      },
      secondary = {
        mode = "CUR",
        showNumber = true,
        size = 14,
        flags = "",
        useGlobalFont = true,
      },
    },
    class = {
      DRUID = {
        forms = {
          CAT     = { primary = {} },
          BEAR    = { primary = {} },
          MOONKIN = { primary = {} },
          CASTER  = { primary = {} },
        },
      },
    },
  },
  char = {
    __puiSeededHidePrimaryBySpec = false,
  },
}

local function PRD_CopySmartSnapValue(value)
  if type(value) ~= "table" then
    return value
  end

  local copy = {}
  for key, child in pairs(value) do
    copy[key] = PRD_CopySmartSnapValue(child)
  end
  return copy
end

local function PRD_GetSmartSnapDesign(appearance)
  if not appearance then
    return nil
  end

  local style = appearance.style or {}
  return {
    texture = appearance.texture,
    borderSize = style.borderSize,
    borderColor = PRD_CopySmartSnapValue(style.borderColor),
    backgroundColor = PRD_CopySmartSnapValue(style.bgColor),
  }
end

local function PRD_ApplySmartSnapDesign(appearance, design)
  if not appearance or type(design) ~= "table" then
    return
  end

  appearance.style = appearance.style or {}
  local style = appearance.style

  if design.texture ~= nil then
    appearance.texture = design.texture
  end
  if design.borderSize ~= nil then
    style.borderSize = Round(design.borderSize)
  end
  if type(design.borderColor) == "table" then
    style.borderColor = PRD_CopySmartSnapValue(design.borderColor)
  end
  if type(design.backgroundColor) == "table" then
    style.bgColor = PRD_CopySmartSnapValue(design.backgroundColor)
  end
end

local function PRD_GetSecondaryAppearanceOwner(profile, resourceKey)
  local secondary = profile.secondary
  local settings = secondary.resourceSettings[resourceKey]
  return settings
end

local function PRD_BuildCombatBarSmartSnap(owner, getState)
  return {
    family = "combatBars",
    syncAxis = "WIDTH",
    syncWidthMin = 120,
    syncWidthMax = 600,
    getSyncWidth = function()
      local state = getState()
      return state and state.widthOwner and state.widthOwner.width or nil
    end,
    applySyncWidth = function(width)
      local state = getState()
      if not state or not state.widthOwner then
        return
      end

      state.widthOwner.width = Round(width)
      owner:InvalidateRuntimeConfig()
      owner:RequestRefresh(state.sizeFlags)
    end,
    getDesign = function()
      local state = getState()
      return state and PRD_GetSmartSnapDesign(state.appearance) or nil
    end,
    applyDesign = function(design)
      local state = getState()
      if not state then
        return
      end

      PRD_ApplySmartSnapDesign(state.appearance, design)
      owner:InvalidateRuntimeConfig()
      owner:RequestRefresh(state.designFlags)
    end,
  }
end

local function _PUI_PRD_SeedCVarOnFirstLogin()
  local cur = GetCVar("nameplateShowSelf")
  if cur ~= "1" then
    SetCVar("nameplateShowSelf", "1")
  end
end

function M:NormalizeDruidFormPrimary(config)
  if type(config) ~= "table" then
    return nil
  end

  if config.colorMode == nil then
    if config.useCustomColor == true then
      config.colorMode = "CUSTOM"
    elseif config.useClassColor == true then
      config.colorMode = "CLASS"
    elseif config.useBlizzardPowerColor == true then
      config.colorMode = "DEFAULT"
    elseif config.useBlizzardPowerColor == false then
      config.colorMode = "TEXTURE"
    end
  end

  if config.colorMode ~= "DEFAULT"
    and config.colorMode ~= "CLASS"
    and config.colorMode ~= "CUSTOM"
    and config.colorMode ~= "TEXTURE"
  then
    config.colorMode = nil
  end

  config.texture = nil
  config.useCustomColor = nil
  config.useClassColor = nil
  config.useBlizzardPowerColor = nil

  return config
end

function M:NormalizeDruidFormSettings()
  local profile = self.db and self.db.profile
  local forms = profile
    and profile.class
    and profile.class.DRUID
    and profile.class.DRUID.forms

  if not forms then
    return
  end

  for _, form in pairs(forms) do
    if type(form) == "table" then
      form.secondary = nil
      if type(form.primary) == "table" then
        self:NormalizeDruidFormPrimary(form.primary)
      end
    end
  end
end

function M:InvalidateRuntimeConfig()
  self._puiRuntimeConfigRevision = (self._puiRuntimeConfigRevision or 0) + 1
  wipe(self._puiResourceConfigCache)
  self._puiSecColorDirty = true
  self._puiSecInactiveAlpha = nil
  self._puiSecFontsDirty = true
end

function M:SeedHidePrimaryBySpec()
  local db = self and self.db and self.db.profile
  if not db then
    return
  end

  if db.__puiHidePrimaryUserSet == true then
    return
  end

  local cdb = self and self.db and self.db.char
  if cdb and cdb.__puiSeededHidePrimaryBySpec == true then
    return
  end

  local _, classToken = UnitClass("player")
  if not classToken then
    db.__puiSeedHidePrimaryPending = true
    return
  end

  local shouldHide = false

  -- Warlock (all 3 specs) - hide mana by default
  if classToken == "WARLOCK" then
    shouldHide = true
  end

  -- Mage: Fire=63, Frost=64 (use specID, not specName, to avoid localization issues)
  if classToken == "MAGE" then
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or nil

    if not specID then
      db.__puiSeedHidePrimaryPending = true
      return
    end

    if specID == 63 or specID == 64 then
      shouldHide = true
    end
  end

  -- Evoker: Devastation=1467 (Augmentation=1473 should SHOW primary by default)
  if classToken == "EVOKER" then
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or nil

    if not specID then
      db.__puiSeedHidePrimaryPending = true
      return
    end

    if specID == 1467 then
      shouldHide = true
    end
  end

  if shouldHide then
    db.hidePrimary = true
  end

  db.__puiSeedHidePrimaryPending = nil

  cdb.__puiSeededHidePrimaryBySpec = true
end


function M:OnInitialize()


  self.db = Addon.db:RegisterNamespace("PRD", defaults)
  self:NormalizeProfile()
  self:SetEnabledState(self.db.profile.enabled and true or false)

  if not self._dbCallbacksRegistered then
    self._dbCallbacksRegistered = true
    -- Core update bus owns normal profile refresh.
    -- Keep only reset/new hooks for one-time PRD seeding.
    self.db.RegisterCallback(self, "OnProfileReset",   "OnProfileReset")
    self.db.RegisterCallback(self, "OnNewProfile",     "OnNewProfile")
  end

  EventRegistry:RegisterCallback("EditMode.Exit", function()
    self:ReassertBlizzardPRDRoot()
  end, self)

  -- Only seed the Blizzard PRD CVar on the very first login (fresh install).
  local g = Addon.db and Addon.db.global
  local rc = g and tonumber(g.reloadCount) or nil
  if rc and rc <= 1 then
    _PUI_PRD_SeedCVarOnFirstLogin()
  end
end



-- CVar that controls Blizzard Personal Resource Display.
local PRD_CVAR_NAME = "nameplateShowSelf"

-- Keep Blizzard CVar aligned with our enabled state when profile.syncCVar is on.
function M:SyncCVarFromSettings()
  if not self.db or not self.db.profile then
    return
  end

  local profile = self.db.profile
  if profile.syncCVar == false then
    return
  end

  local desired = (profile.enabled and "1" or "0")
  local current = GetCVar(PRD_CVAR_NAME)
  if current ~= desired then
    SetCVar(PRD_CVAR_NAME, desired)
  end
end

function M:GetBlizzardShowBarText()
  if not _G.EditModeManagerFrame or not EditModeOverride:IsReady() then
    return false
  end

  local frame = _G.PersonalResourceDisplayFrame
  if not frame then
    return false
  end

  EditModeOverride:LoadLayouts()

  if not EditModeOverride:HasEditModeSettings(frame) then
    return false
  end

  return EditModeOverride:GetFrameSetting(frame, SHOW_BAR_TEXT_SETTING) == 1
end

function M:SetBlizzardShowBarText(enabled)
  if InCombatLockdown() or not _G.EditModeManagerFrame or not EditModeOverride:IsReady() then
    return false
  end

  local frame = _G.PersonalResourceDisplayFrame
  if not frame then
    return false
  end

  EditModeOverride:LoadLayouts()

  if not EditModeOverride:CanEditActiveLayout() then
    local characterDB = Addon.db.char
    local layoutName = characterDB.prdEditModeLayoutName

    if type(layoutName) == "string"
      and layoutName ~= ""
      and EditModeOverride:DoesLayoutExist(layoutName)
    then
      EditModeOverride:SetActiveLayout(layoutName)
    else
      local layoutNumber = 2
      layoutName = "PleebUI"

      while EditModeOverride:DoesLayoutExist(layoutName) do
        layoutName = "PleebUI " .. layoutNumber
        layoutNumber = layoutNumber + 1
      end

      EditModeOverride:AddLayout(Enum.EditModeLayoutType.Character, layoutName)
      characterDB.prdEditModeLayoutName = layoutName
    end
  end

  if not EditModeOverride:HasEditModeSettings(frame) then
    return false
  end

  local value = enabled == true and 1 or 0
  if EditModeOverride:GetFrameSetting(frame, SHOW_BAR_TEXT_SETTING) ~= value then
    EditModeOverride:SetFrameSetting(frame, SHOW_BAR_TEXT_SETTING, value)
    EditModeOverride:ApplyChanges()
  end

  return true
end

-- Simple accessor for options UI.
function M:IsModuleEnabled()
  return self.db
     and self.db.profile
     and self.db.profile.enabled == true
end

-- Main toggle API.
-- enabled : boolean
-- opts    : optional table
--          { syncCVar = true } -> also SetCVar when called (used by options)
function M:SetModuleEnabled(enabled, opts)
  if not self.db or not self.db.profile then
    return false
  end

  local want = not not enabled
  local profile = self.db.profile

  profile.enabled = want

  if want then
    if self:IsEnabled() then
      self:StartRuntime()
    else
      self:Enable()
    end
  elseif self:IsEnabled() then
    self:Disable()
  else
    self:StopRuntime()
  end

  if opts and opts.syncCVar then
    local desired = want and "1" or "0"
    local current = GetCVar(PRD_CVAR_NAME)
    if current ~= desired then
      SetCVar(PRD_CVAR_NAME, desired)
    end
  end

  return true
end

local function _PUI_PRD_CopyFlags(dst, src)
  dst = dst or {}

  if type(src) ~= "table" then
    dst.all = true
    return dst
  end

  for key, value in pairs(src) do
    if value then
      dst[key] = true
    end
  end

  return dst
end

local function _PUI_PRD_ShouldDoFullRefresh(flags)
  return (not flags)
    or flags.all == true
    or flags.full == true
    or flags.profile == true
    or flags.runtime == true
end

function M:RunInitialPEWRefresh()
  if self._puiDidPEWRefresh then
    return
  end

  self._puiDidPEWRefresh = true
  self:RequestRefresh({ all = true })
  self:RequestInitialSettleRefresh()
end

function M:RunInitialSettleRefresh()
  self._puiPRDSettleTimer = nil

  if self._puiRuntimeStarted ~= true
    or not self.db
    or not self.db.profile
    or self.db.profile.enabled ~= true
  then
    return
  end

  self._puiInitialSettleCompleted = true
  self:RequestRefresh({ visibility = true, layout = true })
end

function M:RequestInitialSettleRefresh()
  if self._puiInitialSettleCompleted == true or self._puiPRDSettleTimer then
    return
  end

  self._puiPRDSettleTimer = C_Timer.NewTimer(1, function()
    self:RunInitialSettleRefresh()
  end)
end

function M:EnsurePEWFrame()
  local f = self._puiPEWFrame
  if f then
    f._puiOwner = self
    return f
  end

  f = CreateFrame("Frame")
  f._puiOwner = self
  f:SetScript("OnEvent", function(frame, event)
    if event ~= "PLAYER_ENTERING_WORLD" then
      return
    end

    frame:UnregisterEvent("PLAYER_ENTERING_WORLD")

    frame._puiOwner:RunInitialPEWRefresh()
  end)

  self._puiPEWFrame = f
  return f
end

function M:RunDeferredShutdownCleanup()
  if self._puiRuntimeStarted == true or InCombatLockdown() then
    return
  end

  local secondaryStopped = self:CompleteSecondaryShutdown()
  local displayRestored = self:RestoreBlizzardDisplayState()
  local nativeRestored = self:RestoreBlizzardBars()

  if secondaryStopped and displayRestored and nativeRestored then
    self._puiShutdownCleanupPending = nil
    if self._puiShutdownFrame then
      self._puiShutdownFrame:UnregisterAllEvents()
    end
  end
end

function M:EnsureShutdownFrame()
  local frame = self._puiShutdownFrame
  if frame then
    frame._puiOwner = self
    return frame
  end

  frame = CreateFrame("Frame")
  frame._puiOwner = self
  frame:SetScript("OnEvent", function(shutdownFrame)
    shutdownFrame._puiOwner:RunDeferredShutdownCleanup()
  end)

  self._puiShutdownFrame = frame
  return frame
end

function M:RequestDeferredShutdownCleanup()
  self._puiShutdownCleanupPending = true
  self:RunDeferredShutdownCleanup()

  if self._puiShutdownCleanupPending
    or self._puiNativeRestorePending
  then
    local frame = self:EnsureShutdownFrame()
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  end
end

function M:UnregisterAllMovers()
  FrameUtil:UnregisterMover("PRD")
  FrameUtil:UnregisterMover("PRD_HEALTH")
  FrameUtil:UnregisterMover("PRD_PRIMARY")
  FrameUtil:UnregisterMover("PRD_SECONDARY")

  local moverKeys = self._puiSecondaryMoverKeys
  if moverKeys then
    for moverKey in pairs(moverKeys) do
      FrameUtil:UnregisterMover(moverKey)
    end
  end

  self._puiSecondaryMoverKeys = nil
end

function M:IsPlayerHealthReplacementActive()
  local profile = self.db and self.db.profile
  if not profile
    or profile.enabled ~= true
    or profile.usePlayerHealth ~= true
    or self._puiRuntimeStarted ~= true
    or not self.health
  then
    return false
  end

  local unitFrames = ns.UnitFrames
  if not unitFrames
    or unitFrames.__puiRuntimeAvailable ~= true
    or not unitFrames.db
    or unitFrames.db.profile.enabled == false
    or not unitFrames.frames
    or not unitFrames.frames.player
  then
    return false
  end

  local cfg = unitFrames:ResolveUnitConfig("player")
  return cfg and cfg.enabled ~= false
end

function M:GetResourceDisplayWidth()
  local profile = self.db and self.db.profile
  local size = profile and profile.size
  return Pixel.Round(size and size.width or 250)
end

function M:SetResourceDisplayWidth(width)
  local profile = self.db and self.db.profile
  local size = profile and profile.size
  if not size then
    return false
  end

  local resolvedWidth = Round(tonumber(width) or size.width or 250)
  if resolvedWidth < 120 then
    resolvedWidth = 120
  elseif resolvedWidth > 600 then
    resolvedWidth = 600
  end

  size.width = resolvedWidth
  self:InvalidateRuntimeConfig()
  self:RequestRefresh({ layout = true, mover = true })
  FrameUtil.RefreshSmartSnapState("PRD")
  return true
end

function M:SetUsePlayerHealth(enabled)
  if InCombatLockdown() or not self.db or not self.db.profile then
    return false
  end

  local profile = self.db.profile
  local nextValue = enabled == true
  if profile.usePlayerHealth == nextValue then
    return true
  end

  profile.usePlayerHealth = nextValue

  local unitFrames = ns.UnitFrames
  if unitFrames and unitFrames.db then
    unitFrames:RefreshPlayerPRDReplacement()
  end

  self:RequestRefresh({
    layout = true,
    visibility = true,
    mover = true,
  })

  if ns.TestMode:IsActive() then
    ns.TestMode:Refresh("unitframes", "player-health-replacement", "uf.singleSettings")
  end

  Addon:NotifyOptionsTreeChanged("PRD", { "PRD", "general" })
  return true
end

function M:RefreshPlayerHealthReplacement()
  if self._puiRuntimeStarted == true then
    self:RequestRefresh({
      layout = true,
      visibility = true,
      mover = true,
    })
  end
end

function M:ReassertBlizzardPRDRoot()
  if self._puiRuntimeStarted ~= true or self._puiBlizzardRootGhosted ~= true then
    return
  end

  self:SetBlizzardRootGhosted(true)
end

function M:PLAYER_ALIVE()
  self:ReassertBlizzardPRDRoot()
end

function M:PLAYER_UNGHOST()
  self:ReassertBlizzardPRDRoot()
end

function M:SyncEnabledState()
  if not self.db or not self.db.profile then
    return false
  end

  local wantEnabled = self.db.profile.enabled == true
  local isEnabled = self:IsEnabled()

  if wantEnabled and not isEnabled then
    self:Enable()
  elseif (not wantEnabled) and isEnabled then
    self:Disable()
  end

  return wantEnabled
end

function M:EnsureInitialized()
  if self._puiPRDInitDone then
    return
  end

  self:CreateFrames()
  self:AttachMover()
  self:HookBlizzardSetupOnce()
  self._puiPRDInitDone = true
end

function M:ApplyRequestedFlags(flags)
  ns.PRDPreview.MarkDirty()

  if flags and flags.cvar then
    self:SyncCVarFromSettings()
  end

  if not self:IsEnabled() then
    return
  end

  local secondaryStructure = flags and flags.secondaryRebuild == true
  local secondaryChanged = flags and (
    flags.secondary == true
    or secondaryStructure
    or flags.secondaryAppearance == true
    or flags.secondaryLayout == true
    or flags.secondaryUpdate == true
    or flags.secondaryCues == true
    or flags.secondaryVisibility == true
    or flags.secondaryText == true
  )
  local secondaryAppliesLayout = secondaryStructure
    or flags and (
      flags.secondary == true
      or flags.secondaryAppearance == true
      or flags.secondaryLayout == true
    )

  if secondaryChanged
    or flags and (flags.all or flags.full or flags.profile or flags.runtime)
  then
    self:InvalidateRuntimeConfig()
  end

  if _PUI_PRD_ShouldDoFullRefresh(flags) then
    self:RefreshActive()
    return
  end

  if flags.visibility then
    self:RefreshVisibility()
  end

  if flags.layout and not secondaryAppliesLayout then
    self:ApplyLayout()
  end

  if flags.health then
    self:RefreshHealthTexture()
  end

  if flags.primary then
    self:RefreshPrimaryTexture()
  end

  if flags.primaryTicks then
    self:RefreshPrimaryTicks()
  end

  if flags.text or flags.healthText or flags.primaryText then
    self:ApplyTextSettings()
  end

  if flags.secondaryText then
    self._puiSecFontsDirty = true
  end
  if flags.secondary == true
    or flags.secondaryAppearance == true
    or flags.secondaryUpdate == true
    or flags.secondaryText == true
  then
    self._puiSecColorDirty = true
    self._puiSecInactiveAlpha = nil
  end

  if secondaryStructure then
    self:RebuildSecondary(true)
  elseif secondaryChanged then
    self:RebuildSecondary()

    if flags.secondary == true or flags.secondaryAppearance == true then
      self:RefreshSecondaryAppearance()
    elseif flags.secondaryLayout == true then
      self:ApplyLayout()
      self:AttachMover()
    elseif flags.secondaryText == true then
      self:RefreshSecondaryText()
    end
  end

  if (flags.mover or flags.movers) and not secondaryStructure then
    self:AttachMover()
  end

  if flags.outerBorder and not flags.layout and not secondaryStructure then
    self:ApplyOuterBorder()
  end
end

function M:RunPendingRefresh()
  self._puiPRDRefreshTimer = nil

  local flags = self._puiPendingRefreshFlags
  self._puiPendingRefreshFlags = nil

  if not flags then
    return
  end

  self:ApplyRequestedFlags(flags)
end

function M:RequestRefresh(flags, delay)
  if not self.db or not self.db.profile then
    return
  end

  self._puiPendingRefreshFlags = _PUI_PRD_CopyFlags(self._puiPendingRefreshFlags, flags)

  local wait = tonumber(delay) or 0
  if wait <= 0 then
    if self._puiPRDRefreshTimer and self._puiPRDRefreshTimer.Cancel then
      self._puiPRDRefreshTimer:Cancel()
    end

    self._puiPRDRefreshTimer = nil
    self:RunPendingRefresh()
    return
  end

  if self._puiPRDRefreshTimer then
    return
  end

  self._puiPRDRefreshTimer = C_Timer.NewTimer(wait, function()
    if self then
      self:RunPendingRefresh()
    end
  end)
end

function M:StartRuntime()
  if not self.db or not self.db.profile or self.db.profile.enabled ~= true then
    return
  end

  self:EnsureInitialized()
  self._puiRuntimeStarted = true

  local unitFrames = ns.UnitFrames
  if unitFrames and unitFrames.db then
    unitFrames:RefreshPlayerPRDReplacement()
  end
  if self._puiShutdownFrame then
    self._puiShutdownFrame:UnregisterAllEvents()
  end
  self._puiShutdownCleanupPending = nil
  self._puiNativeRestorePending = nil
  self:SyncCVarFromSettings()
  self:RegisterEvent("PLAYER_ALIVE")
  self:RegisterEvent("PLAYER_UNGHOST")

  if not self._puiDidPEWRefresh then
    local f = self:EnsurePEWFrame()
    f:UnregisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
  end

  if _G.PersonalResourceDisplayFrame then
    self:RequestRefresh({ all = true })
    self:RequestInitialSettleRefresh()
  end

  if self.db.profile.syncCVar == false then
    local v = GetCVar("nameplateShowSelf")
    if v and v ~= "1" and not self._puiWarnedCVar then
      self._puiWarnedCVar = true
      print("|cff33ff99PleebUI|r PRD module is enabled, but Blizzard Personal Resource Display is disabled (CVar nameplateShowSelf = " .. tostring(v) .. ").")
      print("Enable 'Sync Blizzard Personal Resource Display CVar' in PleebUI PRD settings to auto-fix this.")
    end
  end
end

function M:StopRuntime()
  self._puiRuntimeStarted = false

  local unitFrames = ns.UnitFrames
  if unitFrames and unitFrames.db then
    unitFrames:RefreshPlayerPRDReplacement()
  end
  self:UnregisterAllEvents()
  self:UnregisterSecondaryEvents()

  if self._puiPEWFrame then
    self._puiPEWFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end

  if self._puiPRDRefreshTimer and self._puiPRDRefreshTimer.Cancel then
    self._puiPRDRefreshTimer:Cancel()
  end
  self._puiPRDRefreshTimer = nil
  self._puiPendingRefreshFlags = nil

  if self._puiPRDSettleTimer and self._puiPRDSettleTimer.Cancel then
    self._puiPRDSettleTimer:Cancel()
  end
  self._puiPRDSettleTimer = nil

  if self._puiMoverRefreshFrame then
    self._puiMoverRefreshFrame:UnregisterAllEvents()
  end
  self._puiMoverRefreshPending = nil

  if self.frame then
    self.frame:Hide()
  end
  if self.health then self.health:Hide() end
  if self.primary then self.primary:Hide() end
  if self.secondary then self.secondary:Hide() end
  if self._puiSecondaryExtraFrames then
    for _, frame in pairs(self._puiSecondaryExtraFrames) do
      frame:Hide()
    end
  end

  self:UnregisterAllMovers()
  self:RequestDeferredShutdownCleanup()
end


function M:GetBarBorderThickness(style, owner)
  local raw = tonumber(style and style.borderSize) or 0
  if raw < 0 then
    raw = 0
  elseif raw > 12 then
    raw = 12
  end

  local thickness = Round(raw)
  if thickness <= 0 then
    return 0
  end

  if owner and owner.GetWidth and owner.GetHeight then
    local width = tonumber(owner:GetWidth()) or 0
    local height = tonumber(owner:GetHeight()) or 0
    local minimum = math.min(width, height)

    if minimum > 0 then
      local onePixel = ns.FrameScale:BestOnePixel()
      local maximum = (minimum - onePixel) * 0.5
      if maximum < 0 then
        maximum = 0
      end
      maximum = Round(maximum)

      if thickness > maximum then
        thickness = maximum
      end
    end
  end

  return thickness
end

function M:GetBarBorderColor(style)
  local color = style and style.borderColor
  if type(color) == "table" then
    return color
  end

  return Theme.GetColors().border
end

function M:GetAppearance()
  return self.db.profile.appearance
end

function M:GetBarAppearance(role)
  local profile = self.db.profile
  return profile[role]
end

function M:ApplyOuterBorder()
  if not self.frame then
    return
  end

  local config = self.db.profile.outerBorder
  local border = self._puiOuterBorder

  if not border then
    border = CreateFrame("Frame", nil, self.frame)
    border:EnableMouse(false)
    self._puiOuterBorder = border
  end

  border:ClearAllPoints()
  border:SetAllPoints(self.frame)
  border:SetFrameStrata(self.frame:GetFrameStrata())
  border:SetFrameLevel((self.frame:GetFrameLevel() or 0) + 100)
  border:SetAlpha(1)

  if config.enabled ~= true or (self._puiAttachedCount or 0) == 0 then
    self:ApplyBarBorder(border, 0)
    border:Hide()
    return
  end

  local thickness = self:GetBarBorderThickness(
    { borderSize = config.size },
    self.frame
  )
  self:ApplyBarBorder(border, thickness, config.color)
  border:Show()
end

function M:ApplyBarBorder(frame, thickness, color)
  if not frame or not frame.CreateTexture then
    return
  end

  thickness = tonumber(thickness) or 0

  local border = frame.__puiPRDBorder
  if not border then
    local function CreateEdge()
      return frame:CreateTexture(nil, "OVERLAY", nil, 7)
    end

    border = {
      top = CreateEdge(),
      bottom = CreateEdge(),
      left = CreateEdge(),
      right = CreateEdge(),
    }
    frame.__puiPRDBorder = border
  end

  if thickness <= 0 then
    border.top:Hide()
    border.bottom:Hide()
    border.left:Hide()
    border.right:Hide()
    return
  end

  local r = tonumber(color and (color[1] or color.r)) or 0.20
  local g = tonumber(color and (color[2] or color.g)) or 0.20
  local b = tonumber(color and (color[3] or color.b)) or 0.24
  local a = tonumber(color and (color[4] or color.a)) or 1.00

  border.top:ClearAllPoints()
  border.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  border.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  border.top:SetHeight(thickness)
  border.top:SetColorTexture(r, g, b, a)
  border.top:Show()

  border.bottom:ClearAllPoints()
  border.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  border.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  border.bottom:SetHeight(thickness)
  border.bottom:SetColorTexture(r, g, b, a)
  border.bottom:Show()

  border.left:ClearAllPoints()
  border.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  border.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  border.left:SetWidth(thickness)
  border.left:SetColorTexture(r, g, b, a)
  border.left:Show()

  border.right:ClearAllPoints()
  border.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  border.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  border.right:SetWidth(thickness)
  border.right:SetColorTexture(r, g, b, a)
  border.right:Show()
end



function M:CreateFrames()
  if self.frame then
    return self.frame
  end

  -- Root container (addon-owned, safe to move/skin)
  local f = CreateFrame("Frame", "PUI_PRD_Frame", UIParent, "BackdropTemplate")
  self.frame = f

  -- Health bar container (own box)
  local health = CreateFrame("Frame", nil, f, "BackdropTemplate")
  self.health = health

  -- Primary bar container (own box)
  local primary = CreateFrame("Frame", nil, f, "BackdropTemplate")
  self.primary = primary

  -- The first active secondary resource uses this base host. Additional
  -- resources get resource-keyed hosts through AssignSecondaryResourceFrames().
  local secondary = CreateFrame("Frame", nil, f, "BackdropTemplate")
  self.secondary = secondary
  self._puiSecondaryExtraFrames = {}

  -- Give each container a themed box (Theme owns visuals)
  return f
end

function M:AssignSecondaryResourceFrames()
  local resources = self.secondaryResources or {}
  local extraFrames = self._puiSecondaryExtraFrames or {}
  local activeExtraFrames = {}

  self._puiSecondaryExtraFrames = extraFrames

  for index = 1, #resources do
    local resource = resources[index]
    local resourceKey = resource.definition.resourceKey
    local frame

    if index == 1 then
      frame = self.secondary
    else
      frame = extraFrames[resourceKey]
      if not frame then
        frame = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
        extraFrames[resourceKey] = frame
      end
      activeExtraFrames[resourceKey] = true
    end

    resource.index = index
    resource.frame = frame
  end

  for resourceKey, frame in pairs(extraFrames) do
    if activeExtraFrames[resourceKey] ~= true then
      frame:Hide()
    end
  end
end


local function _PRD_AppendStackKey(order, seen, key)
  if type(key) ~= "string" or key == "" or seen[key] then
    return
  end

  order[#order + 1] = key
  seen[key] = true
end

function M:GetSecondaryResourceOptions(includeAllSpecs)
  return ns.PRDSecondary:GetResourceOptionsForClass(PLAYER_CLASS, includeAllSpecs)
end

function M:IsSecondaryResourceEnabled(resourceKey)
  local db = self.db and self.db.profile
  if not db or not db.secondary then
    return false
  end

  local resourceEnabled = db.secondary.resourceEnabled
  return not resourceEnabled or resourceEnabled[resourceKey] ~= false
end

function M:SetSecondaryResourceEnabled(resourceKey, enabled)
  local db = self.db and self.db.profile
  if not db or not db.secondary or type(resourceKey) ~= "string" then
    return false
  end

  db.secondary.resourceEnabled = db.secondary.resourceEnabled or {}
  db.secondary.resourceEnabled[resourceKey] = enabled and true or false
  self:InvalidateRuntimeConfig()
  self:NormalizeStackOrder()
  self:RequestRefresh({ secondaryRebuild = true, secondaryText = true, layout = true })
  return true
end

function M:NormalizeStackOrder()
  local db = self.db and self.db.profile
  if not db then
    return nil
  end

  local normalized = {}
  local seen = {}
  local resourceOptions = self:GetSecondaryResourceOptions(true)
  self:GetSecondaryDefinition()
  local resources = self.secondaryResources or {}
  local existing = db.stackOrder

  if type(existing) == "table" and #existing > 0 then
    for i = 1, #existing do
      _PRD_AppendStackKey(normalized, seen, existing[i])
    end
  end

  _PRD_AppendStackKey(normalized, seen, "health")
  _PRD_AppendStackKey(normalized, seen, "primary")

  for i = 1, #resourceOptions do
    _PRD_AppendStackKey(normalized, seen, resourceOptions[i].key)
  end

  for index = 1, #resources do
    _PRD_AppendStackKey(
      normalized,
      seen,
      resources[index].definition.resourceKey
    )
  end

  db.stackOrder = normalized
  return normalized
end

function M:GetStackOrder()
  local db = self.db and self.db.profile
  if not db then
    return nil
  end

  if type(db.stackOrder) ~= "table" or #db.stackOrder == 0 then
    return self:NormalizeStackOrder()
  end

  return db.stackOrder
end

function M:SwapStackItems(firstKey, secondKey)
  if firstKey == secondKey then
    return false
  end

  local order = self:GetStackOrder()
  if not order then
    return false
  end

  local firstIndex
  local secondIndex

  for i = 1, #order do
    local key = order[i]
    if key == firstKey then
      firstIndex = i
    elseif key == secondKey then
      secondIndex = i
    end

    if firstIndex and secondIndex then
      break
    end
  end

  if not firstIndex or not secondIndex then
    return false
  end

  order[firstIndex], order[secondIndex] = order[secondIndex], order[firstIndex]
  self:RequestRefresh({ layout = true, mover = true })
  return true
end

local _PRD_LAYOUT_BARS = {
  health = {},
  primary = {},
}

local _PRD_LAYOUT_ACTIVE = {}

local function _AddPRDLayoutSlot(activeStack, count, key, record, gapBefore)
  count = count + 1
  local slot = activeStack[count]
  if not slot then
    slot = {}
    activeStack[count] = slot
  end

  slot.key = key
  slot.frame = record.frame
  slot.height = record.height
  slot.gapBefore = count > 1 and gapBefore or 0
  return count
end

function M:ApplyLayout()
  if not self.frame or not self.db or not self.db.profile then
    return
  end

  local db = self.db.profile
  local size = db.size
  local healthAppearance = self:GetBarAppearance("health")
  local primaryAppearance = self:GetBarAppearance("primary")
  local healthCfg = db.health
  local primaryCfg = db.primary
  local secondaryCfg = db.secondary
  local resources = self.secondaryResources or {}
  local resourceByKey = self.secondaryResourceByKey or {}
  local usePlayerHealth = self:IsPlayerHealthReplacementActive()
  local healthDetached = db.detachHealth == true and not usePlayerHealth
  local primaryDetached = primaryCfg.detached == true
  local savedStackWidth = Pixel.Round(size.width or 240)
  local gap = Pixel.Round(size.gap or 0)
  local healthHeightPx = Pixel.Round(healthAppearance.height or 15)
  local primaryHeightPx = Pixel.Round(primaryAppearance.height or 15)
  local secondaryResourceGap = Pixel.Round(secondaryCfg.gap or 2)
  local hideHealth = db.hideHealth == true
  local hidePrimary = db.hidePrimary == true
  local secondaryOn = self.secondaryUsesCustom == true
  local ordered = self:GetStackOrder()
  local bars = _PRD_LAYOUT_BARS

  local hb = bars.health
  hb.frame = self.health
  hb.height = healthHeightPx
  hb.hidden = usePlayerHealth or hideHealth
  hb.detached = healthDetached

  local pb = bars.primary
  pb.frame = self.primary
  pb.height = primaryHeightPx
  pb.hidden = hidePrimary
  pb.detached = primaryDetached

  self._puiSecondaryLayoutRecords = self._puiSecondaryLayoutRecords or {}
  local resourceRecords = self._puiSecondaryLayoutRecords

  for index = 1, #resources do
    local resource = resources[index]
    local resourceKey = resource.definition.resourceKey
    local config = resource.config
    local record = resourceRecords[resourceKey]
    if not record then
      record = {}
      resourceRecords[resourceKey] = record
    end

    record.frame = resource.frame
    record.height = Pixel.Round(config and config.height or 15)
    record.hidden = not secondaryOn
    record.detached = config and config.detached == true or false
  end

  local activeStack = _PRD_LAYOUT_ACTIVE
  local n = 0
  local lastAttachedWasResource = false

  for _, key in ipairs(ordered) do
    if key == "health" then
      if hb.frame and not hb.hidden and not hb.detached then
        n = _AddPRDLayoutSlot(activeStack, n, key, hb, gap)
        lastAttachedWasResource = false
      end
    elseif key == "primary" then
      if pb.frame and not pb.hidden and not pb.detached then
        n = _AddPRDLayoutSlot(activeStack, n, key, pb, gap)
        lastAttachedWasResource = false
      end
    else
      local resource = resourceByKey[key]
      local record = resource and resourceRecords[key]
      if record and record.frame and not record.hidden and not record.detached then
        n = _AddPRDLayoutSlot(
          activeStack,
          n,
          key,
          record,
          lastAttachedWasResource and secondaryResourceGap or gap
        )
        lastAttachedWasResource = true
      end
    end
  end

  for i = #activeStack, n + 1, -1 do
    activeStack[i] = nil
  end
  self._puiAttachedCount = n

  local stackWidth = savedStackWidth
  local anchor = db.anchor
  local point = anchor.point or "CENTER"
  local ax = anchor.x or 0
  local ay = anchor.y or -250

  if #activeStack > 0 then
    local totalHeight = 0
    for _, rec in ipairs(activeStack) do
      totalHeight = totalHeight + (rec.height or 0) + (rec.gapBefore or 0)
    end

    self.frame:ClearAllPoints()
    local relPoint = anchor.relPoint or point
    self.frame:SetPoint(point, UIParent, relPoint, ax, ay)
    self.frame:SetSize(stackWidth, totalHeight)
    self.frame:Show()

    local currentTop = 0
    for _, rec in ipairs(activeStack) do
      local barFrame = rec.frame
      local height = rec.height

      currentTop = currentTop + (rec.gapBefore or 0)
      barFrame:ClearAllPoints()
      barFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -currentTop)
      barFrame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, -currentTop)
      barFrame:SetHeight(height)
      currentTop = currentTop + height
    end
  else
    self.frame:ClearAllPoints()
    local relPoint = anchor.relPoint or point
    self.frame:SetPoint(point, UIParent, relPoint, ax, ay)
    self.frame:SetSize(stackWidth, 1)
    self.frame:Show()
  end

  if healthDetached and self.health then
    if hideHealth then
      self.health:Hide()
    else
      local hcfg = db.health
      local healthAnchor = hcfg.anchor
      local healthPoint = healthAnchor.point or point or "CENTER"
      local healthX = healthAnchor.x or ax or 0
      local healthY = healthAnchor.y or (ay + 20)
      local healthWidth = Pixel.Round(hcfg.width or savedStackWidth)

      self.health:ClearAllPoints()
      self.health:SetPoint(healthPoint, UIParent, healthPoint, healthX, healthY)
      self.health:SetSize(healthWidth, healthHeightPx)
      self.health:Show()
    end
  end

  if primaryDetached and self.primary then
    if hidePrimary then
      self.primary:Hide()
    else
      local primaryAnchor = primaryCfg.anchor
      local primaryPoint = primaryAnchor.point or point or "CENTER"
      local primaryX = primaryAnchor.x or ax or 0
      local primaryY = primaryAnchor.y or ay or -250
      local primaryWidth = Pixel.Round(primaryCfg.width or savedStackWidth)

      self.primary:ClearAllPoints()
      self.primary:SetPoint(primaryPoint, UIParent, primaryPoint, primaryX, primaryY)
      self.primary:SetSize(primaryWidth, primaryHeightPx)
      self.primary:Show()
    end
  end

  for index = 1, #resources do
    local resource = resources[index]
    local frame = resource.frame
    local config = resource.config
    local record = resourceRecords[resource.definition.resourceKey]

    if frame and config and config.detached == true then
      if not secondaryOn then
        frame:Hide()
      else
        local resourceAnchor = config.anchor
        local resourcePoint = resourceAnchor.point or "CENTER"
        local resourceX = resourceAnchor.x or 0
        local resourceY = resourceAnchor.y or -230
        local resourceWidth = Pixel.Round(config.width or savedStackWidth)

        frame:ClearAllPoints()
        frame:SetPoint(
          resourcePoint,
          UIParent,
          resourcePoint,
          resourceX,
          resourceY
        )
        frame:SetSize(resourceWidth, record.height)
        frame:Show()
      end
    end
  end

  if self.health then
    self.health:SetShown(not (usePlayerHealth or bars.health.hidden))
  end

  if self.primary then
    self.primary:SetShown(not bars.primary.hidden)
  end

  for index = 1, #resources do
    local resource = resources[index]
    if resource.frame then
      resource.frame:SetShown(secondaryOn)
    end
  end

  if self.secondaryUsesCustom == true then
    ns.PRDSecondary.ApplySecondaryAppearance(self)
  else
    ns.PRDSecondary.UpdateTrackedSpellIcons(self)
  end
  self:ApplyOuterBorder()
  self:RefreshPrimaryTicks()

  FrameUtil.RefreshSmartSnapState("PRD")
end

function M:RefreshVisibility()
  if not self.db or not self.db.profile then
    return
  end

  local db = self.db.profile
  local usePlayerHealth = self:IsPlayerHealthReplacementActive()
  local hideHealth  = db.hideHealth  == true
  local hidePrimary = db.hidePrimary == true

  -- Our containers
  if self.health then
    if usePlayerHealth or hideHealth then
      self.health:Hide()
    else
      self.health:Show()
    end
  end

  if self.primary then
    if hidePrimary then
      self.primary:Hide()
    else
      self.primary:Show()
    end
  end

  if self.blizz and self.blizz.primary then
    if hidePrimary then
      self.blizz.primary:Hide()
    elseif InCombatLockdown() then
      self.blizz.primary:Show()
    elseif self.blizz.primary:GetParent() == self.primary then
      self.blizz.primary:Show()
    else
      self:MountPrimaryBar()
    end
  end
end



function M:EnsureMoverRefreshFrame()
  local frame = self._puiMoverRefreshFrame
  if frame then
    frame._puiOwner = self
    return frame
  end

  frame = CreateFrame("Frame")
  frame._puiOwner = self
  frame:SetScript("OnEvent", function(moverFrame)
    local owner = moverFrame._puiOwner
    if owner._puiRuntimeStarted == true then
      owner:AttachMover()
    else
      moverFrame:UnregisterAllEvents()
    end
  end)

  self._puiMoverRefreshFrame = frame
  return frame
end

function M:AttachMover()
  if InCombatLockdown() then
    self._puiMoverRefreshPending = true
    self:EnsureMoverRefreshFrame():RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  self._puiMoverRefreshPending = nil
  if self._puiMoverRefreshFrame then
    self._puiMoverRefreshFrame:UnregisterAllEvents()
  end

  if not (self.db and self.db.profile) then
    return
  end

  local db = self.db.profile


  -- Always create frames before wiring movers
  self:CreateFrames()

  -- Helper to always fetch the *current* profile table
  local function GetProfile()
    return self.db and self.db.profile or nil
  end

  local function BuildQuickSettings(anchor)
    local controls = {}

    controls[#controls + 1] = {
      type = "slider",
      label = "Width",
      min = 120,
      max = 600,
      step = 1,
      commitOnRelease = true,
      get = function()
        return self:GetResourceDisplayWidth()
      end,
      set = function(value)
        self:SetResourceDisplayWidth(value)
      end,
    }
    controls[#controls + 1] = {
      type = "toggle",
      label = "Use Player Unit Frame in the Resource Display",
      disabled = function()
        return InCombatLockdown()
      end,
      get = function()
        return GetProfile().usePlayerHealth == true
      end,
      set = function(value)
        self:SetUsePlayerHealth(value)
      end,
    }
    controls[#controls + 1] = {
      type = "description",
      text = "Player Unit Frame can display more information, such as shields or absorbs. ",
    }
    controls[#controls + 1] = {
      type = "slider",
      label = "Bar height",
      min = 4,
      max = 60,
      step = 1,
      get = function()
        return GetProfile().appearance.height
      end,
      set = function(value)
        GetProfile().appearance.height = Round(value)
        self:RequestRefresh({ layout = true, secondaryLayout = true })
      end,
    }
    controls[#controls + 1] = {
      type = "statusbar",
      label = "Texture",
      values = ns.OptionsUtil.BuildStatusbarValues(false),
      get = function()
        return GetProfile().appearance.texture
      end,
      set = function(value)
        GetProfile().appearance.texture = value
        self:RequestRefresh({ health = true, primary = true, secondaryAppearance = true })
      end,
    }
    controls[#controls + 1] = {
      type = "slider",
      label = "Border size",
      min = 0,
      max = 10,
      step = 1,
      get = function()
        return GetProfile().appearance.style.borderSize
      end,
      set = function(value)
        GetProfile().appearance.style.borderSize = Round(value)
        self:RequestRefresh({
          health = true,
          primary = true,
          secondaryAppearance = true,
          layout = true,
        })
      end,
    }
    controls[#controls + 1] = {
      type = "slider",
      label = "Font size",
      min = 6,
      max = 32,
      step = 1,
      get = function()
        return GetProfile().appearance.text.size
      end,
      set = function(value)
        GetProfile().appearance.text.size = Round(value)
        self:RequestRefresh({
          text = true,
          secondaryText = true,
        })
      end,
    }
    controls[#controls + 1] = {
      type = "toggle",
      label = "Show bar text",
      get = function()
        return self:GetBlizzardShowBarText()
      end,
      set = function(value)
        self:SetBlizzardShowBarText(value)
      end,
    }

    local attachedKeys = {}
    local attachedValues = {}
    local resources = self.secondaryResourceByKey or {}

    for index = 1, #_PRD_LAYOUT_ACTIVE do
      local key = _PRD_LAYOUT_ACTIVE[index].key
      local label

      if key == "health" then
        label = "Health"
      elseif key == "primary" then
        label = "Primary resource"
      else
        local resource = resources[key]
        label = resource and resource.config and resource.config.resourceName or key
      end

      attachedKeys[index] = key
      attachedValues[key] = label
    end

    if #attachedKeys > 1 then
      controls[#controls + 1] = {
        type = "heading",
        label = "Resource bar order",
      }

      for index = 1, #attachedKeys do
        local position = index
        local positionLabel

        if position == 1 then
          positionLabel = "Top bar"
        elseif position == #attachedKeys then
          positionLabel = "Bottom bar"
        else
          positionLabel = "Position " .. position
        end

        controls[#controls + 1] = {
          type = "select",
          label = positionLabel,
          values = attachedValues,
          sorting = attachedKeys,
          get = function()
            return attachedKeys[position]
          end,
          set = function(value)
            local currentKey = attachedKeys[position]
            if not self:SwapStackItems(value, currentKey) then
              return
            end

            C_Timer.After(0, function()
              if ns.Flags.IsEditing then
                ns.EditModeQuickSettings:Open(
                  anchor or self.frame,
                  BuildQuickSettings(anchor)
                )
              end
            end)
          end,
        }
      end
    end

    return {
      ownerKey = "PRD",
      title = "Personal Resource Display",
      description = "Live Resource Display settings.",
      controls = controls,
    }
  end

 ----
  -- Root PRD stack mover
 ----
  FrameUtil:RegisterMover("PRD", self.frame, {
      label = "Personal Resource Display",

      onDragStop = function(frame)
        local profile = GetProfile()
        if not profile then
          return
        end

        local x, y = FrameUtil._GetOffsetsForFrame(frame)
        profile.anchor = profile.anchor or {}
        local a = profile.anchor
        a.point    = "CENTER"
        a.rel      = "UIParent"
        a.relPoint = "CENTER"
        a.x, a.y   = x, y
      end,

      resetPosition = function(frame)
        local profile = GetProfile()
        if not profile then
          return
        end

        profile.anchor = profile.anchor or {}
        local a = profile.anchor
        a.point    = "CENTER"
        a.rel      = "UIParent"
        a.relPoint = "CENTER"
        a.x        = 0
        a.y        = -250

        frame:ClearAllPoints()
        frame:SetPoint(a.point, UIParent, a.relPoint, a.x, a.y)
      end,

      optionsString = "PRD,general",
      quickSettings = BuildQuickSettings,
      smartSnap = PRD_BuildCombatBarSmartSnap(self, function()
        local p = GetProfile()
        if not p then return nil end
        return {
          widthOwner = p.size,
          appearance = p.appearance,
          sizeFlags = { layout = true, mover = true },
          designFlags = {
            health = true,
            primary = true,
            secondaryAppearance = true,
            layout = true,
          },
        }
      end),
    })

 ----
  -- Per-bar movers (only when detached)
 ----
  local profile = GetProfile()
  if not profile then
    return
  end

  local healthDetached = profile.detachHealth == true
    and not self:IsPlayerHealthReplacementActive()
  local primaryDetached = profile.primary.detached == true
  local secondaryResources = self.secondaryResources or {}


 ----
  -- Health mover: only when detached
 ----
  if self.health and healthDetached then
    FrameUtil:RegisterMover("PRD_HEALTH", self.health, {
      label = "PRD: Health bar",

      onDragStop = function(frame)
        local p = GetProfile()
        if not p then
          return
        end

        local cfg = p.health
        local a = cfg.anchor

        local x, y = FrameUtil._GetOffsetsForFrame(frame)
        a.point = a.point or "CENTER"
        a.x, a.y = x, y
      end,

      resetPosition = function(frame)
        local p = GetProfile()
        if not p then
          return
        end

        local cfg = p.health
        local a = cfg.anchor

        a.point, a.x, a.y = "CENTER", 0, -180

        frame:ClearAllPoints()
        frame:SetPoint(a.point, UIParent, a.point, a.x, a.y)
      end,

      optionsString = "PRD,health",
      quickSettings = BuildQuickSettings,
      smartSnap = PRD_BuildCombatBarSmartSnap(self, function()
        local p = GetProfile()
        if not p then return nil end
        return {
          widthOwner = p.health,
          appearance = self:GetBarAppearance("health"),
          sizeFlags = { layout = true, health = true, mover = true },
          designFlags = { health = true, layout = true },
        }
      end),
    })
  else
    if not healthDetached then
      FrameUtil.ClearSmartSnapForKey("PRD_HEALTH")
    end
    FrameUtil:UnregisterMover("PRD_HEALTH")
  end

 ----
  -- Primary mover: only when detached
 ----
  if self.primary and primaryDetached then
    FrameUtil:RegisterMover("PRD_PRIMARY", self.primary, {
      label = "PRD: Primary bar",

      onDragStop = function(frame)
        local p = GetProfile()
        if not p then
          return
        end

        local cfg = p.primary
        local a = cfg.anchor

        local x, y = FrameUtil._GetOffsetsForFrame(frame)
        a.point = a.point or "CENTER"
        a.x, a.y = x, y
      end,

      resetPosition = function(frame)
        local p = GetProfile()
        if not p then
          return
        end

        local cfg = p.primary
        local a = cfg.anchor

        a.point, a.x, a.y = "CENTER", 0, -250

        frame:ClearAllPoints()
        frame:SetPoint(a.point, UIParent, a.point, a.x, a.y)
      end,

      optionsString = "PRD,primary",
      quickSettings = BuildQuickSettings,
      smartSnap = PRD_BuildCombatBarSmartSnap(self, function()
        local p = GetProfile()
        if not p then return nil end
        return {
          widthOwner = p.primary,
          appearance = self:GetBarAppearance("primary"),
          sizeFlags = { layout = true, primary = true, mover = true },
          designFlags = { primary = true, layout = true },
        }
      end),
    })
  else
    if not primaryDetached then
      FrameUtil.ClearSmartSnapForKey("PRD_PRIMARY")
    end
    FrameUtil:UnregisterMover("PRD_PRIMARY")
  end

  -- Secondary-resource movers: each detached resource owns its mover.
  FrameUtil:UnregisterMover("PRD_SECONDARY")

  local previousMoverKeys = self._puiSecondaryMoverKeys or {}
  local activeMoverKeys = {}

  local function RegisterSecondaryResourceMover(frame, config, resourceIndex)
    if not frame or not config then
      return
    end

    local resourceKey = config.resourceKey
    local moverKey = "PRD_SECONDARY_" .. resourceKey
    if config.detached ~= true then
      FrameUtil.ClearSmartSnapForKey(moverKey)
      FrameUtil:UnregisterMover(moverKey)
      return
    end
    activeMoverKeys[moverKey] = true

    FrameUtil:RegisterMover(moverKey, frame, {
      label = "PRD: " .. config.resourceName,

      onDragStop = function(movedFrame)
        local p = GetProfile()
        if not p then
          return
        end

        local settings = p.secondary.resourceSettings[resourceKey]
        local anchor = settings.anchor
        local x, y = FrameUtil._GetOffsetsForFrame(movedFrame)

        anchor.point = anchor.point or "CENTER"
        anchor.x = x
        anchor.y = y
        self:InvalidateRuntimeConfig()
      end,

      resetPosition = function(movedFrame)
        local p = GetProfile()
        if not p then
          return
        end

        local settings = p.secondary.resourceSettings[resourceKey]
        local anchor = settings.anchor

        anchor.point = "CENTER"
        anchor.x = 0
        anchor.y = -230 - ((resourceIndex - 1) * ((settings.height or 15) + (p.secondary.gap or 2)))
        self:InvalidateRuntimeConfig()

        movedFrame:ClearAllPoints()
        movedFrame:SetPoint(anchor.point, UIParent, anchor.point, anchor.x, anchor.y)
      end,

      optionsString = "PRD,secondary",
      quickSettings = BuildQuickSettings,
      smartSnap = PRD_BuildCombatBarSmartSnap(self, function()
        local p = GetProfile()
        if not p then return nil end
        local settings = p.secondary.resourceSettings[resourceKey]
        return {
          widthOwner = settings,
          appearance = PRD_GetSecondaryAppearanceOwner(p, resourceKey),
          sizeFlags = { layout = true, secondaryLayout = true, mover = true },
          designFlags = { secondaryAppearance = true, secondaryLayout = true },
        }
      end),
    })
  end

  if self.secondaryUsesCustom == true then
    for index = 1, #secondaryResources do
      local resource = secondaryResources[index]
      RegisterSecondaryResourceMover(resource.frame, resource.config, index)
    end
  end

  for moverKey in pairs(previousMoverKeys) do
    if not activeMoverKeys[moverKey] then
      FrameUtil:UnregisterMover(moverKey)
    end
  end

  self._puiSecondaryMoverKeys = activeMoverKeys
end

function M:AcquireBlizzardFrames()
  local prd = _G.PersonalResourceDisplayFrame
  if not prd then
    return nil
  end

  self.blizz = self.blizz or {}
  self.blizz.root = prd

  self.blizz.primary = prd.PowerBar
  self.blizz.health = prd.HealthBarsContainer.healthBar
  self.blizz.classContainer = prd.ClassFrameContainer
  self.blizz.altBar = prd.AlternatePowerBar

  return prd
end





function M:GetDruidFormKey()
  if PLAYER_CLASS ~= "DRUID" then
    return nil
  end

  local form = GetShapeshiftFormID()
  if form == DRUID_CAT_FORM then
    return "CAT"
  elseif form == DRUID_BEAR_FORM then
    return "BEAR"
  elseif form == DRUID_MOONKIN_FORM_1 or form == DRUID_MOONKIN_FORM_2 then
    return "MOONKIN"
  end
  return "CASTER"
end


local function _ResolvePrimaryCfgEffective(self)
  local profile = self.db.profile
  local base = profile.primary

  local colorMode = base.colorMode or "DEFAULT"
  local customColor = base.customColor

  local formKey = self:GetDruidFormKey()
  local classDB = profile.class
  if formKey
     and classDB
     and classDB.DRUID
     and classDB.DRUID.forms
     and classDB.DRUID.forms[formKey] then
    local f = classDB.DRUID.forms[formKey]
    local fp = f and f.primary

    if fp then
      if fp.colorMode ~= nil then
        colorMode = fp.colorMode
        if type(fp.customColor) == "table" then
          customColor = fp.customColor
        end
      end
    end
  end

  local cfg = {
    colorMode = colorMode,
    customColor = customColor,
  }

  return cfg
end

function M:RefreshHealthTexture()
  if not (self.db and self.db.profile) then
    return
  end

  local cfg = self.db.profile.health

  local bar = self.healthBar
  if not bar and self.blizz and self.blizz.health then
    bar = self.blizz.health
    self.healthBar = bar
  end

  if not bar then
    return
  end

  self:ApplyNativeBarSkin(bar, "health")
end


function M:RefreshPrimaryTexture()
  if not (self.db and self.db.profile) then
    return
  end

  if self.db.profile.hidePrimary == true then
    return
  end

  local cfg = _ResolvePrimaryCfgEffective(self)
  if not cfg then
    return
  end

  local bar = self.primaryBar
  if not bar and self.blizz and self.blizz.primary then
    bar = self.blizz.primary
    self.primaryBar = bar
  end

  if not bar then
    return
  end

  self.__puiEffectivePrimarySkin = cfg
  self:ApplyNativeBarSkin(bar, "primary")
end

function M:RefreshActive()
  if not (self.db and self.db.profile and self.db.profile.enabled) then
    return
  end
  if not self:IsEnabled() then
    return
  end

  self:SeedHidePrimaryBySpec()
  self:EnsureInitialized()
  self._puiRuntimeStarted = true

  self:AcquireBlizzardFrames()
  self:RefreshHealthTexture()
  self:RefreshPrimaryTexture()
  self:ApplyTextSettings()
  self:RefreshVisibility()
  self:RebuildSecondary(true)

  if not self._puiSecondaryEventsRegistered then
    self:RegisterSecondaryEvents()
  end
end

function M:RefreshIconFonts()
  if not self:IsEnabled() then
    return
  end

  self:InvalidateTextCache()
  self:ApplyTextSettings()
  self._puiSecFontsDirty = true
  self:UpdateSecondary()
  ns.PRDPreview.MarkDirty()
end

function M:ApplySettings(flags)
  if not self.db or not self.db.profile then
    return
  end

  ns.PRDPreview.MarkDirty()

  if not flags or flags.profile or flags.profileChanged then
    self:NormalizeProfile()
  end

  local wantEnabled = self:SyncEnabledState()
  if not wantEnabled then
    return
  end

  self:SyncCVarFromSettings()

  if flags and flags.theme == true then
    self:RequestRefresh({
      health = true,
      primary = true,
      secondary = true,
      outerBorder = true,
    })
  end
end

function M:SoftRebuild(flags)
  if not self:IsEnabled() then
    return
  end

  self:RequestRefresh(flags or { all = true })
end

function M:OnProfileReset()
  ns.PRDPreview.MarkDirty()
  if self.db and self.db.char then
    self.db.char.__puiSeededHidePrimaryBySpec = false
  end
  self:NormalizeProfile()
  self:SeedHidePrimaryBySpec()
end

function M:OnNewProfile()
  ns.PRDPreview.MarkDirty()
  if self.db and self.db.char then
    self.db.char.__puiSeededHidePrimaryBySpec = false
  end
  _PUI_PRD_SeedCVarOnFirstLogin()
  self:NormalizeProfile()
  self:SeedHidePrimaryBySpec()
end

M.OnEnable = M.StartRuntime

function M:OnDisable()
  self:StopRuntime()
  self:SyncCVarFromSettings()
end

  _PUI_PRD_SeedCVarOnFirstLogin = P:Def("_PUI_PRD_SeedCVarOnFirstLogin", _PUI_PRD_SeedCVarOnFirstLogin)
  M.NormalizeDruidFormPrimary = P:Def("NormalizeDruidFormPrimary", M.NormalizeDruidFormPrimary)
  M.NormalizeDruidFormSettings = P:Def("NormalizeDruidFormSettings", M.NormalizeDruidFormSettings)
  M.InvalidateRuntimeConfig = P:Def("InvalidateRuntimeConfig", M.InvalidateRuntimeConfig)
  M.SeedHidePrimaryBySpec = P:Def("SeedHidePrimaryBySpec", M.SeedHidePrimaryBySpec)
  M.OnInitialize = P:Def("OnInitialize", M.OnInitialize)
  M.SyncCVarFromSettings = P:Def("SyncCVarFromSettings", M.SyncCVarFromSettings)
  M.GetBlizzardShowBarText = P:Def("GetBlizzardShowBarText", M.GetBlizzardShowBarText)
  M.SetBlizzardShowBarText = P:Def("SetBlizzardShowBarText", M.SetBlizzardShowBarText)
  M.IsModuleEnabled = P:Def("IsModuleEnabled", M.IsModuleEnabled)
  M.SetModuleEnabled = P:Def("SetModuleEnabled", M.SetModuleEnabled)
  _PUI_PRD_CopyFlags = P:Def("_PUI_PRD_CopyFlags", _PUI_PRD_CopyFlags)
  _PUI_PRD_ShouldDoFullRefresh = P:Def("_PUI_PRD_ShouldDoFullRefresh", _PUI_PRD_ShouldDoFullRefresh)
  M.RunInitialPEWRefresh = P:Def("RunInitialPEWRefresh", M.RunInitialPEWRefresh)
  M.RunInitialSettleRefresh = P:Def("RunInitialSettleRefresh", M.RunInitialSettleRefresh)
  M.RequestInitialSettleRefresh = P:Def("RequestInitialSettleRefresh", M.RequestInitialSettleRefresh)
  M.EnsurePEWFrame = P:Def("EnsurePEWFrame", M.EnsurePEWFrame)
  M.RunDeferredShutdownCleanup = P:Def("RunDeferredShutdownCleanup", M.RunDeferredShutdownCleanup)
  M.EnsureShutdownFrame = P:Def("EnsureShutdownFrame", M.EnsureShutdownFrame)
  M.RequestDeferredShutdownCleanup = P:Def("RequestDeferredShutdownCleanup", M.RequestDeferredShutdownCleanup)
  M.UnregisterAllMovers = P:Def("UnregisterAllMovers", M.UnregisterAllMovers)
  M.IsPlayerHealthReplacementActive = P:Def("IsPlayerHealthReplacementActive", M.IsPlayerHealthReplacementActive)
  M.GetResourceDisplayWidth = P:Def("GetResourceDisplayWidth", M.GetResourceDisplayWidth)
  M.SetResourceDisplayWidth = P:Def("SetResourceDisplayWidth", M.SetResourceDisplayWidth)
  M.SetUsePlayerHealth = P:Def("SetUsePlayerHealth", M.SetUsePlayerHealth)
  M.RefreshPlayerHealthReplacement = P:Def("RefreshPlayerHealthReplacement", M.RefreshPlayerHealthReplacement)
  M.ReassertBlizzardPRDRoot = P:Def("ReassertBlizzardPRDRoot", M.ReassertBlizzardPRDRoot)
  M.PLAYER_ALIVE = P:Def("PLAYER_ALIVE", M.PLAYER_ALIVE)
  M.PLAYER_UNGHOST = P:Def("PLAYER_UNGHOST", M.PLAYER_UNGHOST)
  M.SyncEnabledState = P:Def("SyncEnabledState", M.SyncEnabledState)
  M.EnsureInitialized = P:Def("EnsureInitialized", M.EnsureInitialized)
  M.ApplyRequestedFlags = P:Def("ApplyRequestedFlags", M.ApplyRequestedFlags)
  M.RunPendingRefresh = P:Def("RunPendingRefresh", M.RunPendingRefresh)
  M.RequestRefresh = P:Def("RequestRefresh", M.RequestRefresh)
  M.StartRuntime = P:Def("StartRuntime", M.StartRuntime)
  M.StopRuntime = P:Def("StopRuntime", M.StopRuntime)
  M.GetBarBorderThickness = P:Def("GetBarBorderThickness", M.GetBarBorderThickness)
  M.GetBarBorderColor = P:Def("GetBarBorderColor", M.GetBarBorderColor)
  M.GetAppearance = P:Def("GetAppearance", M.GetAppearance)
  M.ApplyBarBorder = P:Def("ApplyBarBorder", M.ApplyBarBorder)
  M.ApplyOuterBorder = P:Def("ApplyOuterBorder", M.ApplyOuterBorder)
  M.CreateFrames = P:Def("CreateFrames", M.CreateFrames)
  _PRD_AppendStackKey = P:Def("_PRD_AppendStackKey", _PRD_AppendStackKey)
  M.GetSecondaryResourceOptions = P:Def("GetSecondaryResourceOptions", M.GetSecondaryResourceOptions)
  M.IsSecondaryResourceEnabled = P:Def("IsSecondaryResourceEnabled", M.IsSecondaryResourceEnabled)
  M.SetSecondaryResourceEnabled = P:Def("SetSecondaryResourceEnabled", M.SetSecondaryResourceEnabled)
  M.NormalizeStackOrder = P:Def("NormalizeStackOrder", M.NormalizeStackOrder)
  M.GetStackOrder = P:Def("GetStackOrder", M.GetStackOrder)
  M.SwapStackItems = P:Def("SwapStackItems", M.SwapStackItems)
  M.ApplyLayout = P:Def("ApplyLayout", M.ApplyLayout)
  M.RefreshVisibility = P:Def("RefreshVisibility", M.RefreshVisibility)
  M.EnsureMoverRefreshFrame = P:Def("EnsureMoverRefreshFrame", M.EnsureMoverRefreshFrame)
  M.AttachMover = P:Def("AttachMover", M.AttachMover)
  M.AcquireBlizzardFrames = P:Def("AcquireBlizzardFrames", M.AcquireBlizzardFrames)
  M.GetDruidFormKey = P:Def("GetDruidFormKey", M.GetDruidFormKey)
  _ResolvePrimaryCfgEffective = P:Def("_ResolvePrimaryCfgEffective", _ResolvePrimaryCfgEffective)
  M.RefreshHealthTexture = P:Def("RefreshHealthTexture", M.RefreshHealthTexture)
  M.RefreshPrimaryTexture = P:Def("RefreshPrimaryTexture", M.RefreshPrimaryTexture)
  M.RefreshActive = P:Def("RefreshActive", M.RefreshActive)
  M.RefreshIconFonts = P:Def("RefreshIconFonts", M.RefreshIconFonts)
  M.ApplySettings = P:Def("ApplySettings", M.ApplySettings)
  M.SoftRebuild = P:Def("SoftRebuild", M.SoftRebuild)
  M.OnProfileReset = P:Def("OnProfileReset", M.OnProfileReset)
  M.OnNewProfile = P:Def("OnNewProfile", M.OnNewProfile)
  M.OnEnable = P:Def("OnEnable", M.OnEnable)
  M.OnDisable = P:Def("OnDisable", M.OnDisable)
