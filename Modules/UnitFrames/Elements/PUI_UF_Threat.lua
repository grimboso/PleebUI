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

  if not cfg or cfg.enabled == false then
    if frame:IsElementEnabled("ThreatIndicator") then
      frame:DisableElement("ThreatIndicator")
    end

    UFThreat.HideThreatHighlight(frame)
    return threat
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
    or not self:IsShown()
    or not color
    or not UFThreat.ShouldShowThreatHighlight(frame)
  then
    UFThreat.HideThreatHighlight(frame)
    return
  end

  local style = cfg.style
  local showBorderGlow = style == "BORDER_GLOW" or style == "BOTH"
  local showFrameGlow = style == "FRAME_GLOW" or style == "BOTH"

  local r, g, b = color:GetRGB()
  local a = 0.95
  local threatEdge = cfg.borderSize
  local threatFrameEdge = cfg.borderSize

  if frame.__puiThreatHighlightShown == true
    and frame.__puiThreatStyle == style
    and frame.__puiThreatEdge == threatEdge
    and frame.__puiThreatFrameEdge == threatFrameEdge
    and frame.__puiThreatR == r
    and frame.__puiThreatG == g
    and frame.__puiThreatB == b
  then
    return
  end

  frame.__puiThreatStyle = style
  frame.__puiThreatEdge = threatEdge
  frame.__puiThreatFrameEdge = threatFrameEdge
  frame.__puiThreatR = r
  frame.__puiThreatG = g
  frame.__puiThreatB = b

  local border = self.BorderGlow
  local glow = self.MainGlow

  local threatLevel = UFFrameGlow.GetLayerLevelOffset("threat")
  local threatColor = frame.__puiThreatColor or {}
  frame.__puiThreatColor = threatColor
  threatColor[1], threatColor[2], threatColor[3], threatColor[4] = r, g, b, a

  if showBorderGlow then
    UFFrameGlow.ShowBorderHighlight(frame, border, threatColor, threatColor, threatEdge, threatLevel)
  else
    UFFrameGlow.HideBorderHighlight(border)
  end

  if showFrameGlow then
    UFFrameGlow.ShowBorderHighlight(frame, glow, threatColor, threatColor, threatFrameEdge, threatLevel)
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
