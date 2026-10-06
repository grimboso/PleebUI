-- File: PUI_UF_Threat.lua
-- Purpose: PleebUI styling for the oUF ThreatIndicator element.


local ADDON_NAME, ns = ...

ns.UFThreat = ns.UFThreat or {}

local UFThreat = ns.UFThreat
local P = select(1, ns.Pleebug:DropIn(UFThreat, { name = "UnitFrames.Threat" }))

local _G = _G
local CreateFrame = _G.CreateFrame
local tonumber = _G.tonumber
local type = _G.type
local USE_SECRET_ROLE_ICONS = select(4, _G.GetBuildInfo()) >= 120105

local UFFrameGlow = ns.UFFrameGlow

local __PUI_SHARED_THREAT_BORDER_SIZE = 3
local __PUI_SHARED_THREAT_FRAME_GLOW_SIZE = 3

function UFThreat.NormalizeThreatConfig(cfg)
  cfg = type(cfg) == "table" and cfg or {}

  if cfg.enabled == nil then
    cfg.enabled = true
  end

  if cfg.style ~= "BORDER_GLOW" and cfg.style ~= "FRAME_GLOW" and cfg.style ~= "BOTH" then
    cfg.style = "FRAME_GLOW"
  end

  cfg.borderSize = tonumber(cfg.borderSize) or __PUI_SHARED_THREAT_FRAME_GLOW_SIZE
  if cfg.borderSize < 0 then
    cfg.borderSize = 0
  elseif cfg.borderSize > 12 then
    cfg.borderSize = 12
  end

  return cfg
end

function UFThreat.GetThreatConfigForFrame(frame)
  local kind = frame and frame.__puiGroupKind or nil

  if kind == "party" then
    return UFThreat.NormalizeThreatConfig(ns.Modules.PartyFrames.db.profile.threatIndicator)
  end

  if kind == "raid" then
    return UFThreat.NormalizeThreatConfig(ns.Modules.RaidFrames.db.profile.threatIndicator)
  end

  return nil
end

function UFThreat.ShouldShowThreatHighlight(frame)
  if USE_SECRET_ROLE_ICONS then
    return true
  end

  local role = frame.__puiGroupRole
  return role ~= nil and role ~= Enum.LFGRole.Tank
end

function UFThreat.HideThreatHighlight(frame)
  if frame.__puiThreatHighlightShown == false then
    return
  end

  local threat = frame.ThreatIndicator
  UFFrameGlow.HideBorderHighlight(threat.BorderGlow)
  UFFrameGlow.HideBorderHighlight(threat.MainGlow)
  frame.__puiThreatHighlightShown = false
end

function UFThreat.Construct(frame)
  local threat = CreateFrame("Frame", nil, frame)
  threat:SetAllPoints(frame)
  threat:EnableMouse(false)
  threat:Hide()
  threat.PostUpdate = UFThreat.PostUpdate
  threat.BorderGlow = UFFrameGlow.EnsureSharedBorderHighlight(frame, "__puiThreatHighlight", __PUI_SHARED_THREAT_BORDER_SIZE)
  threat.MainGlow = UFFrameGlow.EnsureSharedBorderHighlight(frame, "__puiThreatFrameGlow", __PUI_SHARED_THREAT_FRAME_GLOW_SIZE)

  frame.ThreatIndicator = threat
  return threat
end

function UFThreat.Configure(frame)
  local cfg = UFThreat.GetThreatConfigForFrame(frame)
  local threat = frame.ThreatIndicator
  frame.__puiThreatConfig = cfg

  if not cfg or cfg.enabled == false or cfg.borderSize <= 0 then
    frame.__puiThreatShowBorderGlow = false
    frame.__puiThreatShowFrameGlow = false

    if frame:IsElementEnabled("ThreatIndicator") then
      frame:DisableElement("ThreatIndicator")
    end

    UFThreat.HideThreatHighlight(frame)
    return threat
  end

  local style = cfg.style
  local edge = cfg.borderSize
  local level = UFFrameGlow.GetLayerLevelOffset("threat")
  local showBorderGlow = style == "BORDER_GLOW" or style == "BOTH"
  local showFrameGlow = style == "FRAME_GLOW" or style == "BOTH"
  local presentationChanged = frame.__puiThreatShowBorderGlow ~= showBorderGlow
    or frame.__puiThreatShowFrameGlow ~= showFrameGlow
    or frame.__puiThreatBorderSize ~= edge
    or frame.__puiThreatLevelOffset ~= level

  frame.__puiThreatShowBorderGlow = showBorderGlow
  frame.__puiThreatShowFrameGlow = showFrameGlow
  frame.__puiThreatBorderSize = edge
  frame.__puiThreatLevelOffset = level

  if presentationChanged then
    frame.__puiThreatColorObject = nil
  end

  if showBorderGlow and (threat.BorderGlow.__puiPositionReady ~= true
    or threat.BorderGlow.__puiForcePositionRefresh == true
    or threat.BorderGlow.__puiLogicalEdge ~= edge
    or threat.BorderGlow.__puiCachedLevelOffset ~= level)
  then
    UFFrameGlow.PositionBorderHighlight(frame, threat.BorderGlow, edge, level)
  end

  if showFrameGlow and (threat.MainGlow.__puiPositionReady ~= true
    or threat.MainGlow.__puiForcePositionRefresh == true
    or threat.MainGlow.__puiLogicalEdge ~= edge
    or threat.MainGlow.__puiCachedLevelOffset ~= level)
  then
    UFFrameGlow.PositionBorderHighlight(frame, threat.MainGlow, edge, level)
  end

  if not showBorderGlow then
    UFFrameGlow.HideBorderHighlight(threat.BorderGlow)
  end

  if not showFrameGlow then
    UFFrameGlow.HideBorderHighlight(threat.MainGlow)
  end

  threat.feedbackUnit = nil

  if not frame:IsElementEnabled("ThreatIndicator") and not frame:IsElementPaused("ThreatIndicator") then
    frame:EnableElement("ThreatIndicator")
  end

  return threat
end

function UFThreat.PostUpdate(self, unit, status, color)
  local frame = self.__owner
  local cfg = frame.__puiThreatConfig
  if not cfg
    or cfg.enabled == false
    or not color
    or (not USE_SECRET_ROLE_ICONS and not UFThreat.ShouldShowThreatHighlight(frame))
  then
    UFThreat.HideThreatHighlight(frame)
    return
  end

  local border = self.BorderGlow
  local glow = self.MainGlow
  local showBorderGlow = frame.__puiThreatShowBorderGlow == true
  local showFrameGlow = frame.__puiThreatShowFrameGlow == true
  local edge = frame.__puiThreatBorderSize
  local level = frame.__puiThreatLevelOffset

  local borderNeedsPosition = showBorderGlow
    and (border.__puiPositionReady ~= true
      or border.__puiForcePositionRefresh == true
      or border.__puiLogicalEdge ~= edge
      or border.__puiCachedLevelOffset ~= level)
  local glowNeedsPosition = showFrameGlow
    and (glow.__puiPositionReady ~= true
      or glow.__puiForcePositionRefresh == true
      or glow.__puiLogicalEdge ~= edge
      or glow.__puiCachedLevelOffset ~= level)

  if frame.__puiThreatHighlightShown == true
    and frame.__puiThreatColorObject == color
    and not borderNeedsPosition
    and not glowNeedsPosition
  then
    return
  end

  frame.__puiThreatColorObject = color
  local r, g, b = color:GetRGB()

  if showBorderGlow then
    if borderNeedsPosition then
      UFFrameGlow.PositionBorderHighlight(frame, border, edge, level)
    end
    UFFrameGlow.ShowPreparedBorderHighlight(border, r, g, b, 0.95)
  else
    UFFrameGlow.HideBorderHighlight(border)
  end

  if showFrameGlow then
    if glowNeedsPosition then
      UFFrameGlow.PositionBorderHighlight(frame, glow, edge, level)
    end
    UFFrameGlow.ShowPreparedBorderHighlight(glow, r, g, b, 0.95)
  else
    UFFrameGlow.HideBorderHighlight(glow)
  end

  frame.__puiThreatHighlightShown = true
end

function UFThreat.Refresh(frame)
  local threat = UFThreat.Configure(frame)
  if frame:IsElementEnabled("ThreatIndicator") and not frame:IsElementPaused("ThreatIndicator") then
    threat:ForceUpdate()
  end
end

UFThreat.NormalizeThreatConfig = P:Def("UFThreat.NormalizeThreatConfig", UFThreat.NormalizeThreatConfig)
UFThreat.GetThreatConfigForFrame = P:Def("UFThreat.GetThreatConfigForFrame", UFThreat.GetThreatConfigForFrame)
UFThreat.ShouldShowThreatHighlight = P:Def("UFThreat.ShouldShowThreatHighlight", UFThreat.ShouldShowThreatHighlight)
UFThreat.HideThreatHighlight = P:Def("UFThreat.HideThreatHighlight", UFThreat.HideThreatHighlight)
UFThreat.Construct = P:Def("UFThreat.Construct", UFThreat.Construct)
UFThreat.Configure = P:Def("UFThreat.Configure", UFThreat.Configure)
UFThreat.PostUpdate = P:Def("UFThreat.PostUpdate", UFThreat.PostUpdate)
UFThreat.Refresh = P:Def("UFThreat.Refresh", UFThreat.Refresh)
