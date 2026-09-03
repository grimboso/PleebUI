
-- File: PUI_UF_CastBar_Player_Empower.lua
-- Purpose: Shared oUF empower pip handling for unit frame castbars.


local ADDON_NAME, ns = ...


local CastBar = ns.Modules.CastBar

local Module = {}
ns.PUICastBarEmpower = Module
ns.PUICastBarPlayerEmpower = Module

local CreateFrame = CreateFrame
local type = type
local next = next
local tonumber = tonumber
local Round = ns.Pixel.Round

local function CB_ReadColor(color)
  if type(color) ~= "table" then
    return nil
  end

  if color.r ~= nil and color.g ~= nil and color.b ~= nil then
    return color.r, color.g, color.b, color.a or 1
  end

  if color[1] ~= nil and color[2] ~= nil and color[3] ~= nil then
    return color[1], color[2], color[3], color[4] or 1
  end

  return nil
end

local DEFAULT_EMPOWER_COLORS = {
  { 1.00, 0.26, 0.20, 0.5 },
  { 1.00, 0.80, 0.26, 0.5 },
  { 1.00, 1.00, 0.26, 0.5 },
  { 0.66, 1.00, 0.40, 0.5 },
  { 0.36, 0.90, 0.80, 0.5 },
}

local function CB_GetColorSet(cfg)
  return cfg and cfg.empowerSegmentColors
end

local function CB_GetPlayerStageColor(stage)
  local playerCfg = CastBar:GetUnitConfig("player")
  local playerColors = CB_GetColorSet(playerCfg)
  if playerColors and playerColors[stage] then
    return playerColors[stage]
  end

  return DEFAULT_EMPOWER_COLORS[stage]
end

local function CB_GetStageColor(element, stage)
  local bar = element and element.__puiOwnerBar or nil
  local cfg = (bar and bar.__puiState and bar.__puiState.cfg) or nil
  local colors = CB_GetColorSet(cfg)

  return (colors and colors[stage]) or CB_GetPlayerStageColor(stage)
end

local function CB_GetElementConfig(element)
  local bar = element and element.__puiOwnerBar or nil
  return (bar and bar.__puiState and bar.__puiState.cfg) or CastBar:GetUnitConfig("player")
end

local function CB_HideHold(element)
  local bar = element and element.__puiOwnerBar or nil
  if bar and bar.empowerHold then
    bar.empowerHold:Hide()
  end
end

local function CB_ApplyHold(element, stages)
  local bar = element and element.__puiOwnerBar or nil
  local hold = bar and bar.empowerHold or nil
  local cfg = CB_GetElementConfig(element)

  if not hold then
    return
  end

  if not stages or cfg.showEmpowerHold == false then
    hold:Hide()
    return
  end

  local holdStart = 0
  for _, stageSection in next, stages do
    holdStart = holdStart + (tonumber(stageSection) or 0)
  end

  local holdFraction = 1 - holdStart
  if holdFraction <= 0 then
    hold:Hide()
    return
  end

  local isHorizontal = element:GetOrientation() == "HORIZONTAL"
  local elementSize = isHorizontal and element:GetWidth() or element:GetHeight()
  local holdSize = Round(elementSize * holdFraction)

  if holdSize <= 0 then
    hold:Hide()
    return
  end

  local r, g, b, a = CB_ReadColor(cfg.empowerHoldColor)
  hold:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
  hold:ClearAllPoints()

  if isHorizontal then
    hold:SetWidth(holdSize)
    hold:SetPoint("TOP", element, "TOP", 0, 0)
    hold:SetPoint("BOTTOM", element, "BOTTOM", 0, 0)

    if element:GetReverseFill() then
      hold:SetPoint("LEFT", element, "LEFT", 0, 0)
    else
      hold:SetPoint("RIGHT", element, "RIGHT", 0, 0)
    end
  else
    hold:SetHeight(holdSize)
    hold:SetPoint("LEFT", element, "LEFT", 0, 0)
    hold:SetPoint("RIGHT", element, "RIGHT", 0, 0)

    if element:GetReverseFill() then
      hold:SetPoint("TOP", element, "TOP", 0, 0)
    else
      hold:SetPoint("BOTTOM", element, "BOTTOM", 0, 0)
    end
  end

  hold:Show()
end

local function CB_OUF_UpdatePips(element, stages)
  local bar = element and element.__puiOwnerBar or nil
  if bar then
    CastBar.HideIndexedWidgets(bar.empowerPips)
  end

  CB_ApplyHold(element, stages)
end

local function CB_OUF_CastBarUpdatePip(element, pip, stage)
  local r, g, b, a = CB_ReadColor(CB_GetStageColor(element, stage))
  pip.texture:SetColorTexture(1, 1, 1, 1)
  pip.texture:SetVertexColor(r or 1, g or 1, b or 1, a or 1)

  pip.separator:SetColorTexture(1, 1, 1, 0.95)
  pip.separator:Show()
end


local function CB_PipFadeOut(pip)
  local texture = pip.texture

  texture:SetAlpha(pip.pipStart or 1)

  if not texture.__puiFadeAnim then
    local ag = texture:CreateAnimationGroup()
    ag:SetToFinalAlpha(true)

    local fade = ag:CreateAnimation("Alpha")
    fade:SetOrder(1)
    fade:SetFromAlpha(pip.pipStart or 1)
    fade:SetToAlpha(pip.pipFaded or 0.6)
    fade:SetDuration(pip.pipTimer or 0.4)

    texture.__puiFadeAnim = ag
  end

  local ag = texture.__puiFadeAnim
  if ag then
    ag:Stop()
    ag:Play()
  end
end

local function CB_OUF_UpdatePipStep(element, stage)
  if not element or not element.Pips then
    return
  end

  local pipIndex
  if stage == 4 or (stage == 3 and element.numStages == 3) then
    pipIndex = 1
  elseif stage < 4 then
    pipIndex = stage + 1
  else
    pipIndex = stage
  end

  local pip = element.Pips[pipIndex]
  if pip then
    CB_PipFadeOut(pip)
  end
end

local function CB_OUF_PostUpdatePip(element, pip, stage)
  CB_OUF_CastBarUpdatePip(element, pip, stage)

  local followingBoundary = element.Pips and element.Pips[stage + 1] or element
  local leftBoundary = pip
  local rightBoundary = followingBoundary

  if element:GetReverseFill() then
    leftBoundary, rightBoundary = rightBoundary, leftBoundary
  end

  pip.texture:ClearAllPoints()
  pip.texture:SetPoint("TOP", pip, "TOP", 0, 0)
  pip.texture:SetPoint("BOTTOM", pip, "BOTTOM", 0, 0)
  pip.texture:SetPoint("LEFT", leftBoundary, "LEFT", Round(4), 0)
  pip.texture:SetPoint("RIGHT", rightBoundary, "RIGHT", -Round(4), 0)
end

local function CB_OUF_EnsurePip(element, stage)
  local pip = CreateFrame("Frame", nil, element, "CastingBarFrameStagePipTemplate")

  pip.BasePip:SetAlpha(0)
  pip:SetFrameLevel(element:GetFrameLevel() + 10)

  pip.texture = pip:CreateTexture(nil, "ARTWORK", nil, 1)
  pip.texture:SetPoint("BOTTOM", pip, "BOTTOM", 0, 0)
  pip.texture:SetPoint("TOP", pip, "TOP", 0, 0)

  pip.separator = pip:CreateTexture(nil, "OVERLAY", nil, 7)
  pip.separator:SetPoint("TOP", pip, "TOP", 0, 0)
  pip.separator:SetPoint("BOTTOM", pip, "BOTTOM", 0, 0)
  pip.separator:SetWidth(Round(2))
  pip.separator:SetColorTexture(1, 1, 1, 0.95)

  pip.pipStart = 1.0
  pip.pipAlpha = 0.3
  pip.pipFaded = 0.6
  pip.pipTimer = 0.4

  CB_OUF_CastBarUpdatePip(element, pip, stage)

  local bar = element.__puiOwnerBar
  bar.empowerPips[stage] = pip

  return pip
end

local function CB_OUF_PostUpdatePips(element, stages)
  if not (element and element.Pips and stages) then
    return
  end

  local numStages = 0
  for stage in next, stages do
    numStages = numStages + 1

    local pip = element.Pips[stage]
    if pip then
      CB_OUF_PostUpdatePip(element, pip, stage)
      pip:Show()
    end
  end

  element.numStages = numStages
  CB_ApplyHold(element, stages)
end

function Module:OnCreate(frame, holder, element, unit)
  holder.empowerPips = {}
  frame.empowerPips = holder.empowerPips
  element.Pips = holder.empowerPips

  holder.empowerHold = element:CreateTexture(nil, "ARTWORK", nil, 2)
  holder.empowerHold:Hide()
  frame.empowerHold = holder.empowerHold

  element.setupPips = true
end

function Module:OnBindElement(frame, element, unit)
  frame.empowerPips = frame.empowerPips or {}
  element.Pips = frame.empowerPips
  element.CreatePip = CB_OUF_EnsurePip
  element.UpdatePips = nil
  element.UpdatePipStep = CB_OUF_UpdatePipStep
  element.PostUpdatePip = CB_OUF_PostUpdatePip
  element.PostUpdatePips = CB_OUF_PostUpdatePips
  element.setupPips = true

  Module:ApplyConfig(frame, element, frame.__puiState and frame.__puiState.cfg)
end

function Module:ApplyConfig(bar, element, cfg)
  element = element or (bar and bar.status) or nil
  if not element then
    return
  end

  if cfg and cfg.showEmpowerPips == false then
    element.UpdatePips = CB_OUF_UpdatePips
    if bar then
      CastBar.HideIndexedWidgets(bar.empowerPips)
    end
  else
    element.UpdatePips = nil
  end

  if cfg and cfg.showEmpowerHold == false then
    CB_HideHold(element)
  end
end

function Module:UpdatePipColors(element)
  for stage, pip in next, element.Pips do
    CB_OUF_CastBarUpdatePip(element, pip, stage)
  end
end

function Module:Hide(bar)
  CastBar.HideIndexedWidgets(bar.empowerPips)
  if bar and bar.empowerHold then
    bar.empowerHold:Hide()
  end
end


local P = select(1, ns.Pleebug:DropIn(Module, { name = "UnitFrames.CastBar.Empower" }))


  CB_ReadColor = P:Def("CB_ReadColor", CB_ReadColor)
  CB_GetColorSet = P:Def("CB_GetColorSet", CB_GetColorSet)
  CB_GetPlayerStageColor = P:Def("CB_GetPlayerStageColor", CB_GetPlayerStageColor)
  CB_GetStageColor = P:Def("CB_GetStageColor", CB_GetStageColor)
  CB_GetElementConfig = P:Def("CB_GetElementConfig", CB_GetElementConfig)
  CB_HideHold = P:Def("CB_HideHold", CB_HideHold)
  CB_ApplyHold = P:Def("CB_ApplyHold", CB_ApplyHold)
  CB_OUF_UpdatePips = P:Def("CB_OUF_UpdatePips", CB_OUF_UpdatePips)
  CB_OUF_CastBarUpdatePip = P:Def("CB_OUF_CastBarUpdatePip", CB_OUF_CastBarUpdatePip)
  CB_PipFadeOut = P:Def("CB_PipFadeOut", CB_PipFadeOut)
  CB_OUF_UpdatePipStep = P:Def("CB_OUF_UpdatePipStep", CB_OUF_UpdatePipStep)
  CB_OUF_PostUpdatePip = P:Def("CB_OUF_PostUpdatePip", CB_OUF_PostUpdatePip)
  CB_OUF_EnsurePip = P:Def("CB_OUF_EnsurePip", CB_OUF_EnsurePip)
  CB_OUF_PostUpdatePips = P:Def("CB_OUF_PostUpdatePips", CB_OUF_PostUpdatePips)
  Module.OnCreate = P:Def("Empower.OnCreate", Module.OnCreate)
  Module.OnBindElement = P:Def("Empower.OnBindElement", Module.OnBindElement)
  Module.ApplyConfig = P:Def("Empower.ApplyConfig", Module.ApplyConfig)
  Module.UpdatePipColors = P:Def("Empower.UpdatePipColors", Module.UpdatePipColors)
  Module.Hide = P:Def("Empower.Hide", Module.Hide)
