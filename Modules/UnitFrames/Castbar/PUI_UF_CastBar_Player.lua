
-- File: PUI_UF_CastBar_Player.lua
-- Purpose: Player-only castbar extras and event routing.


local ADDON_NAME, ns = ...


local CastBar = ns.Modules.CastBar

local P = select(1, ns.Pleebug:DropIn(CastBar, { name = "UnitFrames.CastBar.Player" }))

local CreateFrame = CreateFrame
local GetNetStats = GetNetStats
local _, PLAYER_CLASS = UnitClass("player")

local string_format = string.format



function CastBar:CreatePlayerCastbarExtras(frame, holder, element, unit)
  holder.safeZone = element:CreateTexture(nil, "OVERLAY")
  holder.safeZone:SetColorTexture(1, 0.15, 0.15, 0.35)
  holder.safeZone:Hide()
  frame.safeZone = holder.safeZone

  holder.safeZoneBorder = CreateFrame("Frame", nil, element, "BackdropTemplate")
  holder.safeZoneBorder:SetFrameLevel((element:GetFrameLevel() or 0) + 5)
  holder.__puiSafeZoneBorderBackdrop = {
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = ns.FrameScale:BestOnePixel(),
  }
  holder.safeZoneBorder:SetBackdrop(holder.__puiSafeZoneBorderBackdrop)
  holder.safeZoneBorder:SetBackdropBorderColor(1, 0.15, 0.15, 0.90)
  holder.safeZoneBorder:Hide()
  frame.safeZoneBorder = holder.safeZoneBorder

  holder.safeZoneText = element:CreateFontString(nil, "OVERLAY")
  holder.safeZoneText:SetJustifyH("RIGHT")
  self.SetFont(holder.safeZoneText, nil, 12, "OUTLINE")
  holder.safeZoneText:Hide()
  frame.safeZoneText = holder.safeZoneText

  element.SafeZone = holder.safeZone

  holder.instantStatus = CreateFrame("StatusBar", nil, holder)
  holder.instantStatus:SetAllPoints(element)
  holder.instantStatus:SetMinMaxValues(0, 1)
  holder.instantStatus:SetValue(0)
  holder.instantStatus:Hide()
  frame.instantStatus = holder.instantStatus

  holder.instantSpellName = holder.instantStatus:CreateFontString(nil, "OVERLAY")
  holder.instantSpellName:SetJustifyH("LEFT")
  self.SetFont(holder.instantSpellName, nil, 14, "OUTLINE")
  holder.instantSpellName:Hide()
  frame.instantSpellName = holder.instantSpellName

  holder.instantOverlay = holder.instantStatus:CreateTexture(nil, "OVERLAY", nil, 2)
  holder.instantOverlay:SetAllPoints(holder.instantStatus)
  holder.instantOverlay:Hide()
  frame.instantOverlay = holder.instantOverlay

  ns.PUICastBarPlayerInstant:OnCreate(holder)
  ns.PUICastBarPlayerChannelTicks:OnCreate(holder, element)

  if PLAYER_CLASS == "EVOKER" then
    ns.PUICastBarPlayerDisintegrate:OnCreate(frame, holder, element, unit)
  end
end

function CastBar:BindPlayerCastbarElement(frame, element, unit)
  element.SafeZone = frame.safeZone
end

function CastBar:LayoutPlayerCastbar(bar, unit, cfg, statusHost)
  local edgeSize = ns.FrameScale:BestOnePixel()
  local backdrop = bar.__puiSafeZoneBorderBackdrop

  if backdrop.edgeSize ~= edgeSize then
    backdrop.edgeSize = edgeSize
    bar.safeZoneBorder:SetBackdrop(backdrop)
  end

  CastBar.GetBorder(bar.instantStatus, cfg)
  ns.PUICastBarPlayerChannelTicks:OnLayout(bar, statusHost, cfg)

  if PLAYER_CLASS == "EVOKER" then
    ns.PUICastBarPlayerDisintegrate:OnLayout(bar, unit, cfg, statusHost)
  end
end

function CastBar:PlayerPostCastStart(element, unit, bar, cfg, spellID, isChanneling)
  if not (element.__puiTestCasting or element.__puiTestChanneling) and bar.__puiInstantCast then
    ns.PUICastBarPlayerInstant:Stop(bar, true)
  end

  element.curStage = 0

  if cfg.showPingOverlay ~= false then
    bar.safeZone:Show()
    bar.safeZoneBorder:ClearAllPoints()
    bar.safeZoneBorder:SetAllPoints(bar.safeZone)
    bar.safeZoneBorder:Show()

    local _, _, home, world = GetNetStats()
    local ms = (home + world) * 0.5

    bar.safeZoneText:Show()
    bar.safeZoneText:ClearAllPoints()
    bar.safeZoneText:SetText(string_format("%.0fms", ms))

    if isChanneling then
      bar.safeZoneText:SetPoint("LEFT", bar.status, "BOTTOMLEFT", 0, 0)
    else
      bar.safeZoneText:SetPoint("RIGHT", bar.status, "BOTTOMRIGHT", 0, 0)
    end
  else
    bar.safeZone:Hide()
    bar.safeZoneBorder:Hide()
    bar.safeZoneText:Hide()
  end

  if isChanneling then
    ns.PUICastBarPlayerChannelTicks:Update(bar, element, cfg, spellID)
  else
    ns.PUICastBarPlayerChannelTicks:Hide(bar)
  end

  if self.__puiUseDisintegrateLogic == true then
    ns.PUICastBarPlayerDisintegrate:UpdateClipWarning(bar, element, spellID)
  end
end

function CastBar:PlayerPostCastStop(element, unit, bar, cfg, spellID, empowerComplete)
  if self.__puiUseDisintegrateLogic == true and empowerComplete ~= nil then
    ns.PUICastBarPlayerDisintegrate:HandleEmpowerStop(self, spellID, empowerComplete)
  end

  element.chainTick = nil
  element.chainTime = nil
  element.curStage = nil
  element.__puiDisintegrateChanneling = false
  element.__puiDisintegrateChaining = false

  bar.safeZone:Hide()
  bar.safeZoneBorder:Hide()
  bar.safeZoneText:Hide()

  if self.__puiUseDisintegrateLogic == true then
    ns.PUICastBarPlayerDisintegrate:ResetClipWarning(bar)
  end

  ns.PUICastBarPlayerChannelTicks:Hide(bar)
end

function CastBar:PlayerPostCastFail(element, unit, bar, cfg)
  bar.safeZone:Hide()
  bar.safeZoneBorder:Hide()
  bar.safeZoneText:Hide()

  element.__puiDisintegrateChanneling = false
  element.__puiDisintegrateChaining = false

  if self.__puiUseDisintegrateLogic == true then
    ns.PUICastBarPlayerDisintegrate:ResetClipWarning(bar)
  end

  ns.PUICastBarPlayerChannelTicks:Hide(bar)
end

local function PlayerSpellcastEvent(_, event, _, arg2, arg3, arg4, arg5, arg6)
  if event == "UNIT_SPELLCAST_SENT" then
    ns.PUICastBarPlayerInstant:MarkSpellSent(arg3, arg4)
    return
  end

  local castGUID = arg2
  local spellID = arg3

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    if CastBar.__puiUseDisintegrateLogic == true then
      ns.PUICastBarPlayerDisintegrate:HandleSucceeded(CastBar, spellID)
    end

    if CastBar.__puiPlayerInstantEventsEnabled == true then
      ns.PUICastBarPlayerInstant:HandleSucceeded(CastBar, castGUID, spellID, arg4)
    end
    return
  end

  if CastBar.__puiPlayerInstantEventsEnabled ~= true then
    return
  end

  if event == "UNIT_SPELLCAST_START"
    or event == "UNIT_SPELLCAST_CHANNEL_START"
    or event == "UNIT_SPELLCAST_EMPOWER_START"
  then
    ns.PUICastBarPlayerInstant:MarkRealCast(CastBar.__puiPlayerCastBar, castGUID, spellID, arg4)
  elseif event == "UNIT_SPELLCAST_STOP" then
    ns.PUICastBarPlayerInstant:MarkRealCastEnded(arg4)
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    ns.PUICastBarPlayerInstant:MarkRealCastEnded(arg5)
  elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
    ns.PUICastBarPlayerInstant:MarkRealCastEnded(arg6)
  elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
    ns.PUICastBarPlayerInstant:MarkCastFailed(castGUID, spellID, arg5)
  else
    ns.PUICastBarPlayerInstant:MarkCastFailed(castGUID, spellID, arg4)
  end
end

function CastBar:RefreshPlayerSpellcastEvents()
  local cfg = self:GetUnitConfig("player")
  local playerBar = self:GetBar("player")
  local playerBarEnabled = playerBar ~= nil and cfg.enabled ~= false
  local instantEnabled = playerBarEnabled and cfg.showInstantCasts ~= false
  local succeededEnabled = playerBarEnabled and (instantEnabled or self.__puiUseDisintegrateLogic == true)

  self.__puiPlayerCastBar = playerBar
  self.__puiPlayerInstantEventsEnabled = instantEnabled or nil
  ns.PUICastBarPlayerInstant:SetEnabled(self, instantEnabled)

  if not succeededEnabled then
    if self.__puiPlayerSpellcastEventFrame then
      self.__puiPlayerSpellcastEventFrame:UnregisterAllEvents()
    end
    return
  end

  if not self.__puiPlayerSpellcastEventFrame then
    self.__puiPlayerSpellcastEventFrame = CreateFrame("Frame")
    self.__puiPlayerSpellcastEventFrame:SetScript("OnEvent", PlayerSpellcastEvent)
  end

  local frame = self.__puiPlayerSpellcastEventFrame
  frame:UnregisterAllEvents()
  frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

  if instantEnabled then
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
  end
end

function CastBar:SPELL_ACTIVATION_OVERLAY_GLOW_SHOW(_, spellID)
  if self.__puiUseDisintegrateLogic == true then
    ns.PUICastBarPlayerDisintegrate:HandleGlowShow(self, spellID)
  end
end

function CastBar:SPELL_ACTIVATION_OVERLAY_GLOW_HIDE(_, spellID)
  if self.__puiUseDisintegrateLogic == true then
    ns.PUICastBarPlayerDisintegrate:HandleGlowHide(self, spellID)
  end
end

function CastBar:PLAYER_DEAD()
  if self.__puiUseDisintegrateLogic == true then
    ns.PUICastBarPlayerDisintegrate:ResetDeadState(self)
  end
end

function CastBar:RefreshDisintegrateLogic()
  if PLAYER_CLASS ~= "EVOKER" then
    self.__puiUseDisintegrateLogic = nil
    self:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    self:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    self:UnregisterEvent("PLAYER_DEAD")
    self:RefreshPlayerSpellcastEvents()
    return false
  end

  local enabled = ns.PUICastBarPlayerDisintegrate:RefreshEnabled(self)

  if enabled then
    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    self:RegisterEvent("PLAYER_DEAD")
  else
    self:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    self:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    self:UnregisterEvent("PLAYER_DEAD")
  end

  self:RefreshPlayerSpellcastEvents()
  return enabled
end

function CastBar:PLAYER_SPECIALIZATION_CHANGED(_, unit)
  if unit and unit ~= "player" then
    return
  end

  self:RefreshDisintegrateLogic()
end

function CastBar:EnablePlayerCastbarEvents()
  if PLAYER_CLASS == "EVOKER" then
    self:RegisterEvent("SPELLS_CHANGED", "RefreshDisintegrateLogic")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RefreshDisintegrateLogic()
  else
    self.__puiUseDisintegrateLogic = nil
    self:RefreshPlayerSpellcastEvents()
  end
end

function CastBar:DisablePlayerCastbarEvents()
  self:UnregisterEvent("SPELLS_CHANGED")
  self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  self:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
  self:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
  self:UnregisterEvent("PLAYER_DEAD")

  self.__puiPlayerInstantEventsEnabled = nil

  if self.__puiPlayerSpellcastEventFrame then
    self.__puiPlayerSpellcastEventFrame:UnregisterAllEvents()
  end

  ns.PUICastBarPlayerInstant:SetEnabled(self, false)
end



  PlayerSpellcastEvent = P:Def("PlayerSpellcastEvent", PlayerSpellcastEvent)
  CastBar.RefreshPlayerSpellcastEvents = P:Def("CastBar.RefreshPlayerSpellcastEvents", CastBar.RefreshPlayerSpellcastEvents)
  CastBar.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = P:Def("CastBar.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", CastBar.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW)
  CastBar.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = P:Def("CastBar.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", CastBar.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE)
  CastBar.PLAYER_DEAD = P:Def("CastBar.PLAYER_DEAD", CastBar.PLAYER_DEAD)
  CastBar.RefreshDisintegrateLogic = P:Def("CastBar.RefreshDisintegrateLogic", CastBar.RefreshDisintegrateLogic)
  CastBar.PLAYER_SPECIALIZATION_CHANGED = P:Def("CastBar.PLAYER_SPECIALIZATION_CHANGED", CastBar.PLAYER_SPECIALIZATION_CHANGED)
  CastBar.EnablePlayerCastbarEvents = P:Def("CastBar.EnablePlayerCastbarEvents", CastBar.EnablePlayerCastbarEvents)
  CastBar.DisablePlayerCastbarEvents = P:Def("CastBar.DisablePlayerCastbarEvents", CastBar.DisablePlayerCastbarEvents)
