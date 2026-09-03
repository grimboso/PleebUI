
-- File: PUI_UF_Power.lua
-- Purpose: Shared UnitFrames native oUF Power widget construction and configuration.


local ADDON_NAME, ns = ...


ns.UFPower = ns.UFPower or {}
local Power = ns.UFPower
local P = select(1, ns.Pleebug:DropIn(Power, { name = "UnitFrames.Power" }))
local _G = _G
local CreateFrame = _G.CreateFrame
local Enum = _G.Enum
local tonumber = _G.tonumber

local StatusBarInterpolation = Enum.StatusBarInterpolation

function Power.PostUpdatePower(element, unit, cur, min, max)
  local owner = element.__owner

  if owner.isForced == true then
    cur = owner.__puiPreviewPower or 62
    min = owner.__puiPreviewPowerMin or 0
    max = owner.__puiPreviewPowerMax or 100
    element:SetMinMaxValues(min, max)
    element:SetValue(cur)

    element.cur = cur
    element.min = min
    element.max = max
  end

end

local function ConstructPowerPrediction(frame, unit)
  local power = frame and frame.Power
  if not power or unit ~= "player" or power.CostPrediction then
    return
  end

  local costPrediction = CreateFrame("StatusBar", nil, power)
  costPrediction:SetReverseFill(true)
  costPrediction:Hide()
  power.CostPrediction = costPrediction
end

local function ConfigurePowerPrediction(frame, unit, cfg)
  local power = frame and frame.Power
  if not power then
    return
  end

  if unit ~= "player" then
    if power.CostPrediction then
      power.CostPrediction:Hide()
    end
    return
  end

  ConstructPowerPrediction(frame, unit)

  local costPrediction = power.CostPrediction
  if not costPrediction then
    return
  end

  costPrediction:SetReverseFill(true)
  costPrediction:ClearAllPoints()
  costPrediction:SetPoint("TOP")
  costPrediction:SetPoint("BOTTOM")
  costPrediction:SetPoint("RIGHT", power:GetStatusBarTexture(), "RIGHT")
  costPrediction:SetStatusBarTexture(ns.UFStyle.ResolveStatusbarTexture("power", unit, cfg))
  costPrediction:SetStatusBarColor(1, 1, 1, 0.35)
end

function Power.Construct(frame, unit)
  local powerBar = frame.Power
  if not powerBar then
    powerBar = CreateFrame("StatusBar", "$parent_PowerBar", frame)
    powerBar:SetMinMaxValues(0, 1)
    powerBar:SetValue(1)
  end

  frame.Power = powerBar

  powerBar.PostUpdate = nil
  powerBar.colorPower = true
  powerBar.colorDisconnected = false
  powerBar.colorTapping = false
  powerBar.colorClass = nil
  powerBar.colorSelection = nil
  powerBar.colorReaction = nil
  powerBar.displayAltPower = false
  powerBar.frequentUpdates = false
  powerBar.smoothing = StatusBarInterpolation.Immediate

  if not powerBar.bg then
    local powerBG = powerBar:CreateTexture(nil, "BORDER")
    powerBG:SetAllPoints(powerBar)
    powerBG:SetTexture("Interface\\Buttons\\WHITE8x8")
    powerBar.bg = powerBG
  end

  ConstructPowerPrediction(frame, unit)
end

function Power.RefreshColors(frame, cfg, colors)
  local powerBar = frame and frame.Power
  if not powerBar or not powerBar.bg then
    return
  end

  local missing = (cfg and cfg.colors and cfg.colors.powerMissing) or (colors and colors.powerMissing) or { 0.1, 0.1, 0.1, 0.9 }
  powerBar.bg:SetVertexColor(missing[1], missing[2], missing[3], missing[4] or 1)
end

function Power.ConfigureFrame(frame, unit, cfg, layout, colors, opts)
  local powerBar = frame.Power

  powerBar.PostUpdate = frame.isForced == true and Power.PostUpdatePower or nil
  powerBar.colorClass = nil
  powerBar.colorReaction = nil
  powerBar.colorSelection = nil
  powerBar.colorPower = true
  powerBar.colorDisconnected = false
  powerBar.colorTapping = false
  powerBar.displayAltPower = cfg and cfg.displayAltPower == true
  powerBar.frequentUpdates = false


  local usePower = cfg and cfg.showPower ~= false and opts.forceNoPower ~= true and (tonumber(layout.powerHeight) or 0) > 0

  if not usePower then
    if frame:IsElementEnabled("Power") then
      frame:DisableElement("Power")
    end

    powerBar.bg:Hide()
    powerBar:Hide()
    return nil
  end

  if not frame:IsElementEnabled("Power") then
    frame:EnableElement("Power")
  end

  if powerBar.CostPrediction then
    powerBar.CostPrediction:ClearAllPoints()
  end

  local contentLeft = layout.contentLeft or layout.inset or 0
  local contentRight = layout.contentRight or layout.inset or 0

  powerBar:ClearAllPoints()
  powerBar:SetPoint("TOPLEFT", frame, "TOPLEFT", contentLeft, -((layout.inset or 0) + (layout.healthHeight or 1) + (layout.gap or 0)))
  powerBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -contentRight, -((layout.inset or 0) + (layout.healthHeight or 1) + (layout.gap or 0)))
  powerBar:SetHeight(layout.powerHeight or 0)

  powerBar:SetStatusBarTexture(ns.UFStyle.ResolveStatusbarTexture("power", unit, cfg))
  ConfigurePowerPrediction(frame, unit, cfg)

  powerBar.bg:ClearAllPoints()
  powerBar.bg:SetAllPoints(powerBar)

  local pm = (cfg and cfg.colors and cfg.colors.powerMissing) or (colors and colors.powerMissing) or { 0.1, 0.1, 0.1, 0.9 }
  powerBar.bg:SetVertexColor(pm[1], pm[2], pm[3], pm[4] or 1)
  powerBar.bg:Show()

  powerBar:Show()

  return powerBar
end



  P:SecDef("Power.PostUpdatePower", Power, "PostUpdatePower")
  ConstructPowerPrediction = P:Def("ConstructPowerPrediction", ConstructPowerPrediction)
  ConfigurePowerPrediction = P:Def("ConfigurePowerPrediction", ConfigurePowerPrediction)
  Power.RefreshColors = P:Def("Power.RefreshColors", Power.RefreshColors)
  Power.Construct = P:Def("Power.Construct", Power.Construct)
  Power.ConfigureFrame = P:Def("Power.ConfigureFrame", Power.ConfigureFrame)
