-- File: PUI_UF_CastBar.lua

local ADDON_NAME, ns = ...



local Addon = ns.Addon
ns.Addon    = Addon
local _G = _G
local UnitClass = UnitClass
local UnitIsPlayer = UnitIsPlayer
local UnitSpellTargetName = UnitSpellTargetName
local UnitChannelDuration = UnitChannelDuration
local UnitEmpoweredChannelDuration = UnitEmpoweredChannelDuration
local C_DurationUtil = C_DurationUtil
local C_StringUtil = C_StringUtil
local issecretvalue = issecretvalue
local tonumber = tonumber
local type = type
local pairs = pairs
local math_abs = math.abs
local math_floor = math.floor
local string_format = string.format


local CastBar = Addon:NewModule("CastBar", "NumyAceEvent-3.0")
ns.Modules.CastBar = CastBar
ns.Registry.Modules.CastBar = CastBar

local P = select(1, ns.Pleebug:DropIn(CastBar, { name = "UnitFrames.CastBar" }))

local THROTTLE = 0.02
local CB_TIME_TEXT_UPDATE_INTERVAL = 0.10
local CB_SetIdleVisuals

local CB_TIME_TEXT_FORMATTER = C_StringUtil.CreateNumericRuleFormatter()
CB_TIME_TEXT_FORMATTER:AddBreakpoint({ threshold = 0, format = "%.1f" })

local CB_REMAINING_TIME_COMPONENTS = {
  {
    property = Enum.DurationTextBindingProperty.RemainingDuration,
    formatter = CB_TIME_TEXT_FORMATTER,
  },
}

local CB_REMAINING_TOTAL_TIME_COMPONENTS = {
  CB_REMAINING_TIME_COMPONENTS[1],
  {
    property = Enum.DurationTextBindingProperty.TotalDuration,
    formatter = CB_TIME_TEXT_FORMATTER,
  },
}

function CastBar:GetBar(unit)
  return self.bars and self.bars[unit] or nil
end

CastBar.THROTTLE = THROTTLE

CastBar.Units = {
  "player",
  "pet",
  "target",
  "focus",
  "boss1",
  "boss2",
  "boss3",
  "boss4",
  "boss5",
}

CastBar.UnitLookup = {
  player = true,
  pet = true,
  target = true,
  focus = true,
  boss1 = true,
  boss2 = true,
  boss3 = true,
  boss4 = true,
  boss5 = true,
}


function CastBar:RefreshFromProfile()
  self:NormalizeConfigProfile()
  self:UpdateAllLayouts()
end


function CastBar:SetMoversVisible(enable)
  enable = enable and true or false
  self.__puiMoversVisible = enable or nil

  if not self.bars then
    return
  end

  for _, bar in pairs(self.bars) do
    if bar then
      local idle = bar.__puiIsIdle ~= false

      if enable and idle then
        bar.__puiCastbarEditMoverVisible = true
        bar:SetAlpha(0)
        bar:Show()
      elseif not enable and bar.__puiCastbarEditMoverVisible then
        bar.__puiCastbarEditMoverVisible = nil
        bar:SetAlpha(1)
        bar:Hide()
      end
    end
  end
end

-- Test mode lives in PUI_UF_CastBar_Test.lua.

local DEFAULT_PLAYER_COLOR = { 1.0, 0.7, 0.0, 1.0 }
local DEFAULT_PET_COLOR = { 0.7, 0.9, 1.0, 1.0 }
local DEFAULT_TARGET_COLOR = { 0.2, 0.8, 1.0, 1.0 }
local DEFAULT_FOCUS_COLOR = { 0.6, 1.0, 0.4, 1.0 }
local DEFAULT_BOSS_COLOR = { 1.0, 0.6, 0.2, 1.0 }

local function CB_IsEnemyCastUnit(unit)
  return unit == "target"
    or unit == "focus"
    or (type(unit) == "string" and unit:match("^boss%d"))
end

local function CB_Clamp(v, lo, hi)
  v = tonumber(v)
  if v == nil then
    return lo
  end
  if v < lo then
    return lo
  end
  if v > hi then
    return hi
  end
  return v
end

local function CB_HideIndexedWidgets(widgets)
  if not widgets then
    return
  end

  for i = 1, #widgets do
    widgets[i]:Hide()
  end
end

local function CB_UnpackColor(c, fallback)
  c = c or fallback
  return c[1], c[2], c[3], c[4] or 1
end

local function CB_GetBaseCastColor(unit, cfg)
  if cfg.useClassColor and UnitIsPlayer(unit) then
    local _, class = UnitClass(unit)
    local c = RAID_CLASS_COLORS[class]
    return c.r, c.g, c.b, 1
  end

  if cfg.useCustomColor == true and cfg.customColor then
    return cfg.customColor[1], cfg.customColor[2], cfg.customColor[3], cfg.customColor[4] or 1
  end

  if cfg.color then
    return CB_UnpackColor(cfg.color)
  end

  if unit == "player" then
    return CB_UnpackColor(DEFAULT_PLAYER_COLOR)
  elseif unit == "pet" then
    return CB_UnpackColor(DEFAULT_PET_COLOR)
  elseif unit == "target" then
    return CB_UnpackColor(DEFAULT_TARGET_COLOR)
  elseif unit == "focus" then
    return CB_UnpackColor(DEFAULT_FOCUS_COLOR)
  elseif type(unit) == "string" and unit:match("^boss%d") then
    return CB_UnpackColor(DEFAULT_BOSS_COLOR)
  end

  return CB_UnpackColor(DEFAULT_TARGET_COLOR)
end

local function CB_ShouldShowSpellName(cfg)
  return cfg.__puiShowSpellName ~= false
end

local function CB_ShouldShowCastTime(cfg)
  return cfg.__puiShowCastTime ~= false
end

local function CB_GetDisplayName(displayName, bar)
  if issecretvalue(displayName) then
    return displayName
  end

  if type(displayName) == "string" and displayName ~= "" then
    return displayName
  end

  return bar.spellName:GetText() or ""
end

local function CB_SetCastText(bar, cfg, unit, displayName)
  local spellName = bar.__puiTestPresentation
    and bar.__puiTestSpellName
    or CB_GetDisplayName(displayName, bar)

  if cfg.displayTarget == true then
    local targetName

    if bar.__puiTestPresentation then
      targetName = bar.__puiTestTargetName
    else
      targetName = UnitSpellTargetName(unit)
    end

    if issecretvalue(targetName) then
      bar.spellName:SetFormattedText("%s: %s", spellName, targetName)
      return
    end

    if type(targetName) == "string" and targetName ~= "" then
      bar.spellName:SetFormattedText("%s: %s", spellName, targetName)
      return
    end
  end

  bar.spellName:SetText(spellName)
end

local function CB_SetTestCastVisuals(bar, cfg, spellName)
  spellName = spellName or ""
  bar.__puiTestSpellName = spellName

  if bar.__puiTestPresentation
    and cfg.displayTarget == true
    and type(bar.__puiTestTargetName) == "string"
    and bar.__puiTestTargetName ~= ""
  then
    bar.spellName:SetFormattedText("%s: %s", spellName, bar.__puiTestTargetName)
  else
    bar.spellName:SetText(spellName)
  end

  if CB_ShouldShowSpellName(cfg) then
    bar.spellName:Show()
  else
    bar.spellName:Hide()
  end

  if cfg.showIcon == false then
    bar.icon:Hide()
  else
    bar.icon:Show()
  end
end

local function CB_SetTestTimeText(bar, cfg, remaining, total)
  if cfg.__puiShowCastTime ~= false then
    bar.timeText:Show()

    remaining = remaining or 0
    total = total or 0

    local showTotal = cfg.__puiShowTotal ~= false
    local remainingTenths = math_floor((remaining * 10) + 0.5)
    local totalTenths = math_floor((total * 10) + 0.5)

    if bar.__puiTestTimeShowTotal == showTotal
      and bar.__puiTestTimeRemainingTenths == remainingTenths
      and bar.__puiTestTimeTotalTenths == totalTenths
    then
      return
    end

    bar.__puiTestTimeShowTotal = showTotal
    bar.__puiTestTimeRemainingTenths = remainingTenths
    bar.__puiTestTimeTotalTenths = totalTenths

    if showTotal then
      bar.timeText:SetFormattedText("%.1f / %.1f", remainingTenths * 0.1, totalTenths * 0.1)
    else
      bar.timeText:SetFormattedText("%.1f", remainingTenths * 0.1)
    end
  else
    bar.__puiTestTimeShowTotal = nil
    bar.__puiTestTimeRemainingTenths = nil
    bar.__puiTestTimeTotalTenths = nil
    bar.timeText:SetText("")
    bar.timeText:Hide()
  end
end

local function CB_ApplyUninterruptTextureMode(bar, cfg)
  local mode = cfg and cfg.uninterruptTextureMode or "GRAY"
  local r, g, b, a = 0.70, 0.70, 0.70, 1.00

  if mode == "DIM" then
    r, g, b, a = 0.35, 0.35, 0.35, 0.80
  end

  bar.uninterruptLeft:SetVertexColor(r, g, b, a)
  bar.uninterruptRight:SetVertexColor(r, g, b, a)
end


local function CB_UpdateInterruptShield(bar, unit, cfg)
  cfg = cfg or CastBar:GetUnitConfig(unit)

  local testColor = bar.__puiTestPresentation and bar.__puiTestColor or nil
  local r, g, b, a

  if testColor then
    r, g, b, a = CB_UnpackColor(testColor)
  else
    r, g, b, a = CB_GetBaseCastColor(unit, cfg)
  end

  bar.status:SetStatusBarColor(r, g, b, a or 1)

  local shieldMode = cfg.uninterruptShieldMode or "LEFT"
  local showShield = CB_IsEnemyCastUnit(unit) and shieldMode ~= "NONE"

  CB_ApplyUninterruptTextureMode(bar, cfg)

  bar.uninterrupt:SetShown(showShield)
  bar.uninterruptLeft:SetShown(showShield and (shieldMode == "LEFT" or shieldMode == "BOTH"))
  bar.uninterruptRight:SetShown(showShield and (shieldMode == "RIGHT" or shieldMode == "BOTH"))
end

local function CB_HideHolderAfterOUFHide(bar)
  bar.timeTextBinding:Disable()

  bar.__puiIsIdle = true
  bar.__puiCastbarEditMoverVisible = nil

  bar.messageText:Hide()
  bar.stopOverlay:SetAlpha(0)
  bar.stopOverlay:Hide()
  bar.bg:SetAlpha(0)

  bar.icon:Hide()
  bar.spellName:SetText("")
  bar.spellName:Hide()
  bar.__puiTestTimeShowTotal = nil
  bar.__puiTestTimeRemainingTenths = nil
  bar.__puiTestTimeTotalTenths = nil
  bar.timeText:SetText("")
  bar.timeText:Hide()
  bar.spark:Hide()
  bar.uninterrupt:Hide()
  bar.uninterruptLeft:Hide()
  bar.uninterruptRight:Hide()

  bar:SetAlpha(1)
  bar:Hide()
end

function CB_SetIdleVisuals(bar, idle)
  bar.__puiIsIdle = idle and true or false

  bar.messageText:Hide()
  bar.stopOverlay:SetAlpha(0)
  bar.stopOverlay:Hide()
  bar.bg:SetAlpha(idle and 0 or 1)

  if idle then
    bar.status:SetValue(0)
    CB_HideHolderAfterOUFHide(bar)
  else
    bar.__puiCastbarEditMoverVisible = nil
    bar:SetAlpha(1)
    bar:Show()
  end
end

local function CB_GetBarState(element, unit)
  local bar = element.__puiOwnerBar
  local state = bar.__puiState
  unit = unit or element.__owner.__unit or state.unit

  state.unit = unit
  state.cfg = state.cfg or CastBar:GetUnitConfig(unit)

  return bar, state.cfg, unit
end

local function CB_CreateTimeTextBinding(fontString)
  local binding = C_DurationUtil.CreateDurationTextBinding()
  binding:SetFontString(fontString)
  binding:SetUpdateInterval(CB_TIME_TEXT_UPDATE_INTERVAL)
  binding:SetZeroDurationText("")
  binding:SetExpiredText("")
  binding:Disable()
  return binding
end

local function CB_StopTimeText(bar)
  bar.timeTextBinding:Disable()
  bar.__puiTimeTextFormat = nil
  bar.timeText:SetText("")
  bar.timeText:Hide()
end

local function CB_StartTimeText(bar)
  local element = bar.status
  local cfg = bar.__puiState.cfg

  if cfg.__puiShowCastTime == false then
    CB_StopTimeText(bar)
    return
  end

  local durationObject = element:GetTimerDuration()
  if not durationObject then
    CB_StopTimeText(bar)
    return
  end

  local delay = bar.__puiCastDelay or 0
  local format
  local components

  if cfg.__puiShowDelayText ~= false and delay > 0 then
    local sign = bar.__puiChanneling and "-" or "+"
    format = string_format("{} (%s%.1f)", sign, delay)
    components = CB_REMAINING_TIME_COMPONENTS
  elseif cfg.__puiShowTotal ~= false then
    format = "{} / {}"
    components = CB_REMAINING_TOTAL_TIME_COMPONENTS
  else
    format = "{}"
    components = CB_REMAINING_TIME_COMPONENTS
  end

  if bar.__puiTimeTextFormat ~= format then
    bar.__puiTimeTextFormat = format
    bar.timeTextBinding:SetTextFormat(format, components)
  end

  bar.timeTextBinding:SetDuration(durationObject)
  bar.timeTextBinding:Enable()
  bar.timeTextBinding:UpdateFontString()
  bar.timeText:Show()
end

local function CB_OUF_CustomDelayText(element, delay, isChanneling)
  local bar = element.__puiOwnerBar
  local tenths = math_floor(math_abs(tonumber(delay) or 0) * 10 + 0.5)
  if bar.__puiCastDelayTenths == tenths and bar.__puiChanneling == (isChanneling == true) then
    return
  end

  bar.__puiCastDelayTenths = tenths
  bar.__puiCastDelay = tenths / 10
  bar.__puiChanneling = isChanneling == true
  CB_StartTimeText(bar)
end


local function CB_OUF_PostCastStart(element, unit, spellID, notInterruptible, displayName, texture, isTradeSkill)
  local bar, cfg, resolvedUnit = CB_GetBarState(element, unit)

  element.__puiActiveUnit = resolvedUnit
  element.__puiMissingCastSince = nil
  element.__puiNextStaleCastWatchdog = nil
  bar.__puiCastDelay = 0
  bar.__puiCastDelayTenths = 0
  bar.__puiChanneling = element.__puiTestChanneling == true

  CB_SetIdleVisuals(bar, false)

  if bar.icon and cfg.showIcon ~= false then
    bar.icon:Show()
  end

  if CB_ShouldShowSpellName(cfg) then
    CB_SetCastText(bar, cfg, resolvedUnit, displayName)
    bar.spellName:Show()
  else
    bar.spellName:SetText("")
    bar.spellName:Hide()
  end

  if not bar.__puiTestState then
    CB_StartTimeText(bar)
  end

  CB_UpdateInterruptShield(bar, resolvedUnit, cfg)

  if resolvedUnit == "player" and bar.__puiTestPresentation ~= true then
    bar.__puiChanneling = UnitChannelDuration("player") ~= nil
      and UnitEmpoweredChannelDuration("player") == nil
    CastBar:PlayerPostCastStart(element, resolvedUnit, bar, cfg, spellID, bar.__puiChanneling)
  end
end

local function CB_OUF_PostCastUpdate(element, unit, spellID, duration, direction)
  local bar, cfg, resolvedUnit = CB_GetBarState(element, unit)

  element.__puiActiveUnit = resolvedUnit
  element.__puiMissingCastSince = nil
  element.__puiNextStaleCastWatchdog = nil
  bar.__puiChanneling = direction == Enum.StatusBarTimerDirection.RemainingTime

  if not bar.__puiTestState then
    CB_StartTimeText(bar)
  end
end

local function CB_OUF_PostCastStop(element, unit, spellID, empowerComplete)
  local bar, cfg, resolvedUnit = CB_GetBarState(element, unit)

  CB_StopTimeText(bar)

  element.__puiActiveUnit = nil
  element.__puiMissingCastSince = nil
  element.__puiNextStaleCastWatchdog = nil

  if resolvedUnit == "player" and bar.__puiTestPresentation ~= true then
    CastBar:PlayerPostCastStop(element, resolvedUnit, bar, cfg, spellID, empowerComplete)
  end

  bar.__puiChanneling = nil
  bar.__puiCastDelay = nil
  bar.__puiCastDelayTenths = nil
end

local function CB_OUF_PostInterruptible(element, unit, spellID, notInterruptible)
  local bar = element.__puiOwnerBar
  local cfg = bar.__puiState.cfg

  CB_UpdateInterruptShield(bar, unit, cfg)
end

local function CB_OUF_PostCastFail(element, unit, spellID)
  local bar = element.__puiOwnerBar

  CB_StopTimeText(bar)

  element.__puiActiveUnit = nil
  element.__puiMissingCastSince = nil
  element.__puiNextStaleCastWatchdog = nil

  if unit == "player" then
    CastBar:PlayerPostCastFail(element, unit, bar, bar.__puiState.cfg, spellID)
  end


  bar.__puiChanneling = nil
  bar.__puiCastDelay = nil
  bar.__puiCastDelayTenths = nil
end

local function CB_OUF_PostCastInterrupted(element, unit, spellID, interruptedBy)
  CB_OUF_PostCastFail(element, unit, spellID)
end

local function CB_BindCallbacks(self, frame, element, unit)
  if not element.__puiHolderHideHooked then
    element.__puiHolderHideHooked = true
    element:HookScript("OnHide", function(owner)
      CB_HideHolderAfterOUFHide(owner.__puiOwnerBar)
    end)
  end



  element.Icon = frame.icon
  element.Text = frame.spellName
  element.Time = nil
  element.Delay = frame.delayText
  element.Shield = frame.uninterrupt
  element.Spark = frame.spark

  ns.PUICastBarEmpower:OnBindElement(frame, element, unit)

  if unit == "player" then
    self:BindPlayerCastbarElement(frame, element, unit)
  end

  element.PostCastStart = CB_OUF_PostCastStart
  element.PostCastUpdate = CB_OUF_PostCastUpdate
  element.PostCastStop = CB_OUF_PostCastStop
  element.PostCastInterruptible = CB_OUF_PostInterruptible
  element.CustomTimeText = nil
  element.CustomDelayText = CB_OUF_CustomDelayText
  element.PostCastFail = CB_OUF_PostCastFail
  element.PostCastInterrupted = CB_OUF_PostCastInterrupted
  element.smoothing = Enum.StatusBarInterpolation.Immediate
end




function CastBar:OnInitialize()
  self.db = Addon.db:RegisterNamespace("CastBar", self.defaults)
  self:NormalizeConfigProfile()
end

function CastBar:OnEnable()
  self:EnablePlayerCastbarEvents()
  self:RefreshFromProfile()
end

function CastBar:OnDisable()
  self:DisablePlayerCastbarEvents()

  if self.bars then
    for _, bar in pairs(self.bars) do
      local frame = bar.__puiUnitFrame
      if frame:IsElementEnabled("Castbar") then
        frame:DisableElement("Castbar")
      end

      CB_StopTimeText(bar)
      if bar.clipWarningText then
        bar.clipWarningText:Hide()
      end
      bar:Hide()
    end
  end

end


function CastBar:SoftRebuild(flags)
  if not flags then
    return
  end

  if flags.profile == true or flags.layout == true or flags.movers == true then
    self:RefreshFromProfile()

    if flags.profile == true and self:IsEnabled() then
      self:RefreshDisintegrateLogic()
    end
  end
end

  CastBar.RefreshFromProfile = P:Def("CastBar.RefreshFromProfile", CastBar.RefreshFromProfile)
  CastBar.SetMoversVisible = P:Def("CastBar.SetMoversVisible", CastBar.SetMoversVisible)

  CB_OUF_PostCastStart = P:Def("CB_OUF_PostCastStart", CB_OUF_PostCastStart)
  CB_OUF_PostCastUpdate = P:Def("CB_OUF_PostCastUpdate", CB_OUF_PostCastUpdate)
  CB_OUF_PostCastStop = P:Def("CB_OUF_PostCastStop", CB_OUF_PostCastStop)
  CB_OUF_PostInterruptible = P:Def("CB_OUF_PostInterruptible", CB_OUF_PostInterruptible)
  CB_OUF_PostCastFail = P:Def("CB_OUF_PostCastFail", CB_OUF_PostCastFail)
  CB_OUF_PostCastInterrupted = P:Def("CB_OUF_PostCastInterrupted", CB_OUF_PostCastInterrupted)
  CB_OUF_CustomDelayText = P:Def("CB_OUF_CustomDelayText", CB_OUF_CustomDelayText)
  CB_BindCallbacks = P:Def("CB_BindCallbacks", CB_BindCallbacks)

  CastBar.IsEnemyCastUnit = CB_IsEnemyCastUnit
  CastBar.Clamp = CB_Clamp
  CastBar.HideIndexedWidgets = CB_HideIndexedWidgets
  CastBar.UnpackColor = CB_UnpackColor
  CastBar.GetBaseCastColor = CB_GetBaseCastColor
  CastBar.ShouldShowSpellName = CB_ShouldShowSpellName
  CastBar.ShouldShowCastTime = CB_ShouldShowCastTime
  CastBar.SetTestCastVisuals = CB_SetTestCastVisuals
  CastBar.SetTestTimeText = CB_SetTestTimeText
  CastBar.UpdateInterruptShield = CB_UpdateInterruptShield
  CastBar.ApplyUninterruptTextureMode = CB_ApplyUninterruptTextureMode
  CastBar.SetIdleVisuals = CB_SetIdleVisuals
  CastBar.CreateTimeTextBinding = CB_CreateTimeTextBinding
  CastBar.StopTimeText = CB_StopTimeText
  CastBar.StartTimeText = CB_StartTimeText
  CastBar.PostCastStart = CB_OUF_PostCastStart
  CastBar.PostCastUpdate = CB_OUF_PostCastUpdate
  CastBar.PostCastStop = CB_OUF_PostCastStop
  CastBar.BindCallbacks = CB_BindCallbacks

  CastBar.OnInitialize = P:Def("CastBar.OnInitialize", CastBar.OnInitialize)
  CastBar.OnEnable = P:Def("CastBar.OnEnable", CastBar.OnEnable)
  CastBar.OnDisable = P:Def("CastBar.OnDisable", CastBar.OnDisable)
  CastBar.SoftRebuild = P:Def("CastBar.SoftRebuild", CastBar.SoftRebuild)
