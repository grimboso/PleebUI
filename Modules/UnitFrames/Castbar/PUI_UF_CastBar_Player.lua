
-- File: PUI_UF_CastBar_Player.lua
-- Purpose: Player-only castbar extras and event routing.


local ADDON_NAME, ns = ...


local CastBar = ns.Modules.CastBar

local LibStub = _G.LibStub
local P = select(1, ns.Pleebug:DropIn(CastBar, { name = "UnitFrames.CastBar.Player" }))

local CreateFrame = CreateFrame
local GetNetStats = GetNetStats
local _, PLAYER_CLASS = UnitClass("player")

local tonumber = tonumber
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

  holder.instantOverlay = element:CreateTexture(nil, "OVERLAY", nil, 2)
  holder.instantOverlay:SetAllPoints(element)
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
  if bar.safeZoneBorder and bar.__puiSafeZoneBorderBackdrop then
    local edgeSize = ns.FrameScale:BestOnePixel()
    local backdrop = bar.__puiSafeZoneBorderBackdrop

    if backdrop.edgeSize ~= edgeSize then
      backdrop.edgeSize = edgeSize
      bar.safeZoneBorder:SetBackdrop(backdrop)
    end
  end

  ns.PUICastBarPlayerChannelTicks:OnLayout(bar, statusHost, cfg)

  if PLAYER_CLASS == "EVOKER" then
    ns.PUICastBarPlayerDisintegrate:OnLayout(bar, unit, cfg, statusHost)
  end
end

function CastBar:PlayerPostCastStart(element, unit, bar, cfg, spellID, isChanneling)
  if not (element and (element.__puiTestCasting or element.__puiTestChanneling)) then
    ns.PUICastBarPlayerInstant:MarkRealCast(bar)
  end

  if element then
    element.curStage = 0
  end

  if bar.safeZone then
    if cfg and cfg.showPingOverlay ~= false then
      bar.safeZone:Show()

      if bar.safeZoneBorder then
        bar.safeZoneBorder:ClearAllPoints()
        bar.safeZoneBorder:SetAllPoints(bar.safeZone)
        bar.safeZoneBorder:Show()
      end

      if bar.safeZoneText then
        local _, _, msHome, msWorld = GetNetStats()
        msHome = tonumber(msHome) or 0
        msWorld = tonumber(msWorld) or 0
        local ms = (msHome + msWorld) * 0.5

        bar.safeZoneText:Show()
        bar.safeZoneText:ClearAllPoints()
        bar.safeZoneText:SetText(string_format("%.0fms", ms))

        if isChanneling then
          bar.safeZoneText:SetPoint("LEFT", bar.status, "BOTTOMLEFT", 0, 0)
        else
          bar.safeZoneText:SetPoint("RIGHT", bar.status, "BOTTOMRIGHT", 0, 0)
        end
      elseif bar.safeZoneText then
        bar.safeZoneText:Hide()
      end
    else
      bar.safeZone:Hide()
      if bar.safeZoneBorder then
        bar.safeZoneBorder:Hide()
      end
      if bar.safeZoneText then
        bar.safeZoneText:Hide()
      end
    end
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

  if element then
    element.chainTick = nil
    element.chainTime = nil
    element.curStage = nil
    element.__puiDisintegrateChanneling = false
    element.__puiDisintegrateChaining = false
  end

  bar.safeZone:Hide()
  bar.safeZoneBorder:Hide()
  bar.safeZoneText:Hide()

  if self.__puiUseDisintegrateLogic == true then
    ns.PUICastBarPlayerDisintegrate:ResetClipWarning(bar)
  end

  ns.PUICastBarPlayerChannelTicks:Hide(bar)
end

function CastBar:PlayerPostCastFail(element, unit, bar, cfg)
  if element and element.SafeZone then
    element.SafeZone:Hide()
  end

  if bar.safeZoneBorder then
    bar.safeZoneBorder:Hide()
  end

  if bar.safeZoneText then
    bar.safeZoneText:Hide()
  end

  if element then
    element.__puiDisintegrateChanneling = false
    element.__puiDisintegrateChaining = false
  end

  if self.__puiUseDisintegrateLogic == true then
    ns.PUICastBarPlayerDisintegrate:ResetClipWarning(bar)
  end

  ns.PUICastBarPlayerChannelTicks:Hide(bar)
end

local function PlayerSpellcastSent(_, _, _, _, castGUID, spellID)
  ns.PUICastBarPlayerInstant:MarkSpellSent(castGUID, spellID)
end

local function PlayerSpellcastSucceeded(_, _, _, castGUID, spellID)
  if CastBar.__puiUseDisintegrateLogic == true then
    ns.PUICastBarPlayerDisintegrate:HandleSucceeded(CastBar, spellID)
  end

  if CastBar.__puiPlayerInstantEventsEnabled == true then
    ns.PUICastBarPlayerInstant:HandleSucceeded(castGUID, spellID)
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

  if instantEnabled then
    if not self.__puiPlayerSentEventFrame then
      self.__puiPlayerSentEventFrame = CreateFrame("Frame")
      self.__puiPlayerSentEventFrame:SetScript("OnEvent", PlayerSpellcastSent)
    end

    self.__puiPlayerSentEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
  elseif self.__puiPlayerSentEventFrame then
    self.__puiPlayerSentEventFrame:UnregisterAllEvents()
  end

  if succeededEnabled then
    if not self.__puiPlayerSucceededEventFrame then
      self.__puiPlayerSucceededEventFrame = CreateFrame("Frame")
      self.__puiPlayerSucceededEventFrame:SetScript("OnEvent", PlayerSpellcastSucceeded)
    end

    self.__puiPlayerSucceededEventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
  elseif self.__puiPlayerSucceededEventFrame then
    self.__puiPlayerSucceededEventFrame:UnregisterAllEvents()
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

function CastBar:SPELLS_CHANGED()
  self:RefreshDisintegrateLogic()
end

function CastBar:PLAYER_SPECIALIZATION_CHANGED(_, unit)
  if unit and unit ~= "player" then
    return
  end

  self:RefreshDisintegrateLogic()
end

function CastBar:EnablePlayerCastbarEvents()
  if PLAYER_CLASS == "EVOKER" then
    self:RegisterEvent("SPELLS_CHANGED")
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

  if self.__puiPlayerSentEventFrame then
    self.__puiPlayerSentEventFrame:UnregisterAllEvents()
  end

  if self.__puiPlayerSucceededEventFrame then
    self.__puiPlayerSucceededEventFrame:UnregisterAllEvents()
  end

  ns.PUICastBarPlayerInstant:SetEnabled(self, false)
end



  PlayerSpellcastSent = P:Def("PlayerSpellcastSent", PlayerSpellcastSent)
  PlayerSpellcastSucceeded = P:Def("PlayerSpellcastSucceeded", PlayerSpellcastSucceeded)
  CastBar.RefreshPlayerSpellcastEvents = P:Def("CastBar.RefreshPlayerSpellcastEvents", CastBar.RefreshPlayerSpellcastEvents)
  CastBar.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = P:Def("CastBar.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", CastBar.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW)
  CastBar.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = P:Def("CastBar.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", CastBar.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE)
  CastBar.PLAYER_DEAD = P:Def("CastBar.PLAYER_DEAD", CastBar.PLAYER_DEAD)
  CastBar.RefreshDisintegrateLogic = P:Def("CastBar.RefreshDisintegrateLogic", CastBar.RefreshDisintegrateLogic)
  CastBar.SPELLS_CHANGED = P:Def("CastBar.SPELLS_CHANGED", CastBar.SPELLS_CHANGED)
  CastBar.PLAYER_SPECIALIZATION_CHANGED = P:Def("CastBar.PLAYER_SPECIALIZATION_CHANGED", CastBar.PLAYER_SPECIALIZATION_CHANGED)
  CastBar.EnablePlayerCastbarEvents = P:Def("CastBar.EnablePlayerCastbarEvents", CastBar.EnablePlayerCastbarEvents)
  CastBar.DisablePlayerCastbarEvents = P:Def("CastBar.DisablePlayerCastbarEvents", CastBar.DisablePlayerCastbarEvents)
