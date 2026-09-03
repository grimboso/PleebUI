
-- File: PUI_UF_Mouseover.lua
-- Purpose: oUF Mouseover element for UnitFrames tooltip and highlight handling.


local ADDON_NAME, ns = ...

ns.UFMouseover = ns.UFMouseover or {}

local UFMouseover = ns.UFMouseover
local P = select(1, ns.Pleebug:DropIn(UFMouseover, { name = "UnitFrames.Mouseover" }))
local _G = _G
local type = _G.type
local GameTooltip = _G.GameTooltip
local GameTooltip_SetDefaultAnchor = _G.GameTooltip_SetDefaultAnchor
local UFFrameGlow = ns.UFFrameGlow
local __PUI_SHARED_MOUSEOVER_FRAME_GLOW_SIZE = 3
local __PUI_MOUSEOVER_FRAME_GLOW_LEVEL = 40
local MouseoverRuntimeConfig = nil


local function BuildMouseoverRuntimeConfig()
  local db = ns.UnitFrames.db.profile or {}
  local mode = db.mouseoverHighlightMode
  local strength = db.mouseoverHighlightStrength
  local borderSize = db.mouseoverHighlightBorderSize

  if mode ~= "FRAME" and mode ~= "BORDER" and mode ~= "BOTH" then
    mode = "BOTH"
  end

  if type(strength) ~= "number" then
    strength = 0.55
  end

  if strength < 0 then
    strength = 0
  elseif strength > 1 then
    strength = 1
  end

  if type(borderSize) ~= "number" then
    borderSize = __PUI_SHARED_MOUSEOVER_FRAME_GLOW_SIZE
  end

  if borderSize < 0 then
    borderSize = 0
  elseif borderSize > 12 then
    borderSize = 12
  end

  return {
    tooltipsEnabled = db.enableMouseoverTooltips ~= false,
    highlightEnabled = db.enableMouseoverHighlight ~= false,
    highlightMode = mode,
    highlightStrength = strength,
    borderSize = borderSize,
  }
end

local function EnsureMouseoverRuntimeConfig()
  if not MouseoverRuntimeConfig then
    MouseoverRuntimeConfig = BuildMouseoverRuntimeConfig()
  end

  return MouseoverRuntimeConfig
end


function UFMouseover.InvalidateRuntimeConfigCache()
  MouseoverRuntimeConfig = nil
end


local function PositionMouseoverTexture(frame, texture)
  if not frame or not texture then
    return
  end

  local health = frame.Health
  if not health then
    return
  end

  local fill = health:GetStatusBarTexture()
  if texture.__puiCachedHealthAnchor == health and texture.__puiCachedFillAnchor == fill then
    return
  end

  texture:ClearAllPoints()
  texture:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
  if fill then
    texture:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
  else
    texture:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
  end

  texture.__puiCachedHealthAnchor = health
  texture.__puiCachedFillAnchor = fill
  texture.__puiPositionReady = true
end

function UFMouseover.HideSharedMouseoverHighlight(frame)
  if not frame then
    return
  end

  if frame.__puiMouseoverActive ~= true
    and frame.__puiMouseoverTextureShown ~= true
    and frame.__puiMouseoverFrameGlowShown ~= true
  then
    return
  end

  local highlight = frame.__puiMouseoverHighlight
  if not highlight then
    frame.__puiIsMouseover = false
    frame.__puiMouseoverActive = false
    frame.__puiMouseoverTextureShown = false
    frame.__puiMouseoverFrameGlowShown = false
    frame.__puiMouseoverMode = nil
    frame.__puiMouseoverStrength = nil
    frame.__puiMouseoverShowTexture = nil
    frame.__puiMouseoverShowFrameGlow = nil
    return
  end

  local texture = highlight.Texture
  if texture and frame.__puiMouseoverTextureShown == true then
    texture:Hide()
  end

  local frameGlow = highlight.FrameGlow
  if frameGlow and frame.__puiMouseoverFrameGlowShown == true then
    frameGlow.__puiBorderShown = false
    if frameGlow:IsShown() then
      frameGlow:Hide()
    end
  end

  frame.__puiIsMouseover = false
  frame.__puiMouseoverActive = false
  frame.__puiMouseoverTextureShown = false
  frame.__puiMouseoverFrameGlowShown = false
  frame.__puiMouseoverMode = nil
  frame.__puiMouseoverStrength = nil
  frame.__puiMouseoverShowTexture = nil
  frame.__puiMouseoverShowFrameGlow = nil
end

function UFMouseover.EnsureSharedMouseoverHighlight(frame)
  if not frame then
    return nil
  end

  if frame.__puiMouseoverHighlight then
    return frame.__puiMouseoverHighlight
  end

  local highlight = {}
  frame.__puiMouseoverHighlight = highlight
  return highlight
end

local function EnsureSharedMouseoverTexture(frame, highlight)
  if not frame or not highlight then
    return nil
  end

  if highlight.Texture then
    return highlight.Texture
  end

  local parent = frame.TextureParent or frame.Health or frame.RaisedElementParent or frame
  if not parent then
    return nil
  end

  local texture = parent:CreateTexture(nil, "ARTWORK", nil, 1)
  texture:SetTexture("Interface\\Buttons\\WHITE8x8")
  texture:Hide()
  highlight.Texture = texture

  return texture
end

local function EnsureSharedMouseoverFrameGlow(frame, highlight)
  if not frame or not highlight then
    return nil
  end

  if highlight.FrameGlow then
    return highlight.FrameGlow
  end

  local frameGlow = UFFrameGlow.EnsureSharedBorderHighlight(frame, "__puiMouseoverFrameGlow", __PUI_SHARED_MOUSEOVER_FRAME_GLOW_SIZE)
  highlight.FrameGlow = frameGlow
  return frameGlow
end

local function WarmMouseoverHighlight(frame)
  if not frame then
    return
  end

  local cfg = MouseoverRuntimeConfig or EnsureMouseoverRuntimeConfig()
  if cfg.highlightEnabled ~= true then
    return
  end

  local mode = cfg.highlightMode
  local highlight = UFMouseover.EnsureSharedMouseoverHighlight(frame)
  if not highlight then
    return
  end

  if mode == "BORDER" or mode == "BOTH" then
    local texture = EnsureSharedMouseoverTexture(frame, highlight)
    if texture then
      PositionMouseoverTexture(frame, texture)
    end
  end

  if mode == "FRAME" or mode == "BOTH" then
    local frameGlow = EnsureSharedMouseoverFrameGlow(frame, highlight)
    if frameGlow then
      UFFrameGlow.PositionBorderHighlight(frame, frameGlow, cfg.borderSize, __PUI_MOUSEOVER_FRAME_GLOW_LEVEL)
    end
  end
end


local function Mouseover_UpdateUnitTooltip(self)
  local unit = self.__unit
  if GameTooltip:IsForbidden() or type(unit) ~= "string" or unit == "" then
    self.UpdateTooltip = nil
    return false
  end

  GameTooltip_SetDefaultAnchor(GameTooltip, self)
  if GameTooltip:SetUnit(unit) then
    self.UpdateTooltip = Mouseover_UpdateUnitTooltip
    return true
  end

  self.UpdateTooltip = nil
  return false
end

local function Mouseover_HideUnitTooltip(self)
  self.UpdateTooltip = nil

  if self.__puiUnitTooltipActive == true and not GameTooltip:IsForbidden() then
    GameTooltip:Hide()
  end

  self.__puiUnitTooltipActive = false
end


local function Mouseover_OnEnter(self)
  if not self then
    return
  end

  self.__puiIsMouseover = true

  local cfg = MouseoverRuntimeConfig or EnsureMouseoverRuntimeConfig()
  if cfg.tooltipsEnabled == true then
    if Mouseover_UpdateUnitTooltip(self) then
      self.__puiUnitTooltipActive = true
    else
      Mouseover_HideUnitTooltip(self)
    end
  else
    Mouseover_HideUnitTooltip(self)
  end

  if cfg.highlightEnabled ~= true then
    return
  end

  local mode = cfg.highlightMode
  local strength = cfg.highlightStrength
  local borderSize = cfg.borderSize or __PUI_SHARED_MOUSEOVER_FRAME_GLOW_SIZE
  local showTexture = mode == "BORDER" or mode == "BOTH"
  local showFrameGlow = mode == "FRAME" or mode == "BOTH"
  local highlight = self.__puiMouseoverHighlight

  if not highlight then
    return
  end

  if self.__puiMouseoverActive == true
    and self.__puiMouseoverMode == mode
    and self.__puiMouseoverStrength == strength
    and self.__puiMouseoverBorderSize == borderSize
    and self.__puiMouseoverShowTexture == showTexture
    and self.__puiMouseoverShowFrameGlow == showFrameGlow
  then
    return
  end

  local texture = highlight.Texture
  if texture then
    if showTexture then
      texture:SetVertexColor(1.0, 0.96, 0.78, strength * 0.30)
      texture:Show()
      self.__puiMouseoverTextureShown = true
    elseif self.__puiMouseoverTextureShown == true then
      texture:Hide()
      self.__puiMouseoverTextureShown = false
    end
  end

  local frameGlow = highlight.FrameGlow
  if frameGlow then
    if showFrameGlow then
      if frameGlow.__puiForcePositionRefresh == true then
        UFFrameGlow.PositionBorderHighlight(self, frameGlow, borderSize, __PUI_MOUSEOVER_FRAME_GLOW_LEVEL)
      end

      UFFrameGlow.ShowPreparedBorderHighlight(frameGlow, 1.0, 0.96, 0.78, strength * 0.85)
      self.__puiMouseoverFrameGlowShown = true
    elseif self.__puiMouseoverFrameGlowShown == true then
      UFFrameGlow.HideBorderHighlight(frameGlow)
      self.__puiMouseoverFrameGlowShown = false
    end
  end

  self.__puiMouseoverActive = true
  self.__puiMouseoverMode = mode
  self.__puiMouseoverStrength = strength
  self.__puiMouseoverBorderSize = borderSize
  self.__puiMouseoverShowTexture = showTexture
  self.__puiMouseoverShowFrameGlow = showFrameGlow
end

local function Mouseover_OnLeave(self)
  if not self then
    return
  end

  self.__puiIsMouseover = false

  Mouseover_HideUnitTooltip(self)

  local highlight = self.__puiMouseoverHighlight
  if highlight then
    local texture = highlight.Texture
    if texture and self.__puiMouseoverTextureShown == true then
      texture:Hide()
    end

    local frameGlow = highlight.FrameGlow
    if frameGlow and self.__puiMouseoverFrameGlowShown == true then
      UFFrameGlow.HideBorderHighlight(frameGlow)
    end
  end

  self.__puiMouseoverActive = false
  self.__puiMouseoverTextureShown = false
  self.__puiMouseoverFrameGlowShown = false
  self.__puiMouseoverMode = nil
  self.__puiMouseoverStrength = nil
  self.__puiMouseoverShowTexture = nil
  self.__puiMouseoverShowFrameGlow = nil
end


function UFMouseover.ApplyScripts(frame)
  if frame.__puiMouseoverScriptsHooked ~= true then
    frame:HookScript("OnEnter", Mouseover_OnEnter)
    frame:HookScript("OnLeave", Mouseover_OnLeave)
    frame.__puiMouseoverScriptsHooked = true
  end

  WarmMouseoverHighlight(frame)
end

function UFMouseover.RefreshFrame(frame)
  if not frame then
    return
  end

  local wasMouseover = frame.__puiIsMouseover == true

  UFMouseover.ApplyScripts(frame)
  UFMouseover.HideSharedMouseoverHighlight(frame)

  if wasMouseover then
    Mouseover_OnEnter(frame)
  end
end




  BuildMouseoverRuntimeConfig = P:Def("BuildMouseoverRuntimeConfig", BuildMouseoverRuntimeConfig)
  EnsureMouseoverRuntimeConfig = P:Def("EnsureMouseoverRuntimeConfig", EnsureMouseoverRuntimeConfig)
  UFMouseover.InvalidateRuntimeConfigCache = P:Def("UFMouseover.InvalidateRuntimeConfigCache", UFMouseover.InvalidateRuntimeConfigCache)
  UFMouseover.ApplyScripts = P:Def("UFMouseover.ApplyScripts", UFMouseover.ApplyScripts)
  UFMouseover.RefreshFrame = P:Def("UFMouseover.RefreshFrame", UFMouseover.RefreshFrame)
  PositionMouseoverTexture = P:Def("PositionMouseoverTexture", PositionMouseoverTexture)
  UFMouseover.HideSharedMouseoverHighlight = P:Def("UFMouseover.HideSharedMouseoverHighlight", UFMouseover.HideSharedMouseoverHighlight)
  UFMouseover.EnsureSharedMouseoverHighlight = P:Def("UFMouseover.EnsureSharedMouseoverHighlight", UFMouseover.EnsureSharedMouseoverHighlight)
  EnsureSharedMouseoverTexture = P:Def("EnsureSharedMouseoverTexture", EnsureSharedMouseoverTexture)
  EnsureSharedMouseoverFrameGlow = P:Def("EnsureSharedMouseoverFrameGlow", EnsureSharedMouseoverFrameGlow)
  Mouseover_UpdateUnitTooltip = P:Def("Mouseover_UpdateUnitTooltip", Mouseover_UpdateUnitTooltip)
  Mouseover_HideUnitTooltip = P:Def("Mouseover_HideUnitTooltip", Mouseover_HideUnitTooltip)
  Mouseover_OnEnter = P:Def("Mouseover_OnEnter", Mouseover_OnEnter)
  Mouseover_OnLeave = P:Def("Mouseover_OnLeave", Mouseover_OnLeave)
  WarmMouseoverHighlight = P:Def("WarmMouseoverHighlight", WarmMouseoverHighlight)
