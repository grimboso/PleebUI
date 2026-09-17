
-- File: PUI_UF_Health.lua
-- Purpose: Shared UnitFrames native oUF Health construction, colors, and prediction sub-widgets.


local ADDON_NAME, ns = ...


ns.UFHealth = ns.UFHealth or {}
local UFHealth = ns.UFHealth


local P = select(1, ns.Pleebug:DropIn(UFHealth, { name = "UnitFrames.Health" }))


local _G = _G
local CreateFrame = _G.CreateFrame
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local setmetatable = _G.setmetatable
local oUF = ns.oUF
local UFHealPrediction = ns.UFHealPrediction

local FrameColorsMeta = {
  __index = oUF.colors,
}

function UFHealth.UpdateHealth(frame, event, unit)
  if not unit or frame.__unit ~= unit then
    return
  end

  if frame.config and frame.config.hideHealth == true then
    return
  end

  local element = frame.Health

  if element.PreUpdate then
    element:PreUpdate(unit)
  end

  local max = UnitHealthMax(unit)
  element:SetMinMaxValues(0, max)

  local cur = UnitHealth(unit)
  element:SetValue(cur, element.smoothing)

  if element.PostUpdate then
    element:PostUpdate(unit, cur, max, 0)
  end
end

function UFHealth.PostUpdateHealth(element, unit, cur, max)
  local owner = element.__owner

  if owner.isForced ~= true then
    return
  end

  cur = owner.__puiPreviewHealth or 72
  max = owner.__puiPreviewHealthMax or 100
  element:SetMinMaxValues(0, max)
  element:SetValue(cur)
end

function UFHealth.PostUpdateHealthColor(element, unit, color)
  local frame = element.__owner
  local isGroupFrame = frame.__puiGroupKind == "party" or frame.__puiGroupKind == "raid"
  if not isGroupFrame then
    return
  end

  local isOffline = color == frame.colors.disconnected
  if frame.__puiOfflineState ~= isOffline then
    ns.UFIndicators.UpdateOfflinePresentation(frame, isOffline)
  end
end

local function EnsureFrameColors(frame)
  local frameColors = frame.__puiFrameColors
  if frameColors then
    return frameColors
  end

  frameColors = setmetatable({
    class = RAID_CLASS_COLORS,
  }, FrameColorsMeta)
  frame.__puiFrameColors = frameColors
  frame.colors = frameColors
  return frameColors
end

local function ConfigureHealthColors(frame, cfg, colors, forceUpdate)
  local healthBar = frame and frame.Health
  if not healthBar then
    return
  end

  local useClassColor = frame.__puiUseClassColor
  if useClassColor == nil then
    useClassColor = true
  end

  local useReactionColor = not colors or colors.useReactionForNPC ~= false
  local useCustomHealthColor = useClassColor == false

  if useCustomHealthColor then
    local custom = (cfg and cfg.colors and cfg.colors.healthBar)
      or (colors and colors.healthBar)
      or { 0.35, 0.35, 0.35, 1 }
    local healthColor = frame.__puiCustomHealthColor

    if healthColor then
      healthColor:SetRGBA(
        custom[1] or 0.35,
        custom[2] or 0.35,
        custom[3] or 0.35,
        custom[4] or 1
      )
    else
      healthColor = oUF:CreateColor(
        custom[1] or 0.35,
        custom[2] or 0.35,
        custom[3] or 0.35,
        custom[4] or 1
      )
      frame.__puiCustomHealthColor = healthColor
    end

    EnsureFrameColors(frame).health = healthColor
  elseif frame.__puiFrameColors then
    frame.__puiFrameColors.health = nil
  end

  healthBar.PostUpdateColor = UFHealth.PostUpdateHealthColor
  healthBar.colorClass = not useCustomHealthColor
  local useReactionColors = not useCustomHealthColor and useReactionColor

  if healthBar.SetColorSelection then
    healthBar:SetColorSelection(useReactionColors)
  else
    healthBar.colorSelection = useReactionColors
  end

  if healthBar.SetColorReaction then
    healthBar:SetColorReaction(useReactionColors)
  else
    healthBar.colorReaction = useReactionColors
  end

  healthBar.colorHealth = useCustomHealthColor

  UFHealth.RefreshMissingColor(frame, cfg, colors)

  if forceUpdate and frame:IsElementEnabled("Health") and healthBar.ForceUpdate then
    healthBar:ForceUpdate()
  end
end

function UFHealth.RefreshColors(frame, cfg, colors)
  ConfigureHealthColors(frame, cfg, colors, true)
end


function UFHealth.Construct(frame)
  EnsureFrameColors(frame)

  if not frame.healthBG then
    local healthBG = frame:CreateTexture(nil, "BACKGROUND")
    healthBG:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.healthBG = healthBG
  end

  local healthBar = frame.Health
  if not healthBar then
    healthBar = CreateFrame("StatusBar", nil, frame)
    healthBar:SetMinMaxValues(0, 1)
    healthBar:SetValue(1)
  end

  healthBar:SetClipsChildren(true)

  frame.Health = healthBar

  healthBar.PostUpdate = nil
  healthBar.PostUpdateColor = nil
  healthBar.colorDisconnected = true
  healthBar.colorTapping = true
  healthBar.colorClass = true
  healthBar.colorSelection = true
  healthBar.colorReaction = true
  healthBar.colorHealth = nil
  healthBar.Override = UFHealth.UpdateHealth

  UFHealPrediction.Construct(healthBar)
end

function UFHealth.ConfigureFrame(frame, unit, cfg, layout, colors)
  local healthBar = frame.Health
  local showHealth = not cfg or cfg.hideHealth ~= true

  healthBar.PostUpdate = frame.isForced == true and UFHealth.PostUpdateHealth or nil
  healthBar.colorDisconnected = true
  healthBar.colorTapping = true

  local contentLeft = layout.contentLeft or layout.inset or 0
  local contentRight = layout.contentRight or layout.inset or 0

  local bg = frame.healthBG
  bg:ClearAllPoints()
  bg:SetPoint("TOPLEFT", frame, "TOPLEFT", contentLeft, -(layout.inset or 0))
  bg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -contentRight, -(layout.inset or 0))
  bg:SetHeight(layout.healthHeight or 1)
  bg:SetShown(showHealth)

  healthBar:ClearAllPoints()
  healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", contentLeft, -(layout.inset or 0))
  healthBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -contentRight, -(layout.inset or 0))
  healthBar:SetHeight(layout.healthHeight or 1)
  healthBar:SetClipsChildren(true)
  healthBar:SetShown(showHealth)

  local healthTexture = ns.UFStyle.ResolveStatusbarTexture("health", unit, cfg)
  if frame.__puiUF_healthTexPath ~= healthTexture or not healthBar:GetStatusBarTexture() then
    frame.__puiUF_healthTexPath = healthTexture
    healthBar:SetStatusBarTexture(healthTexture)
  end

  ConfigureHealthColors(frame, cfg, colors, false)

  if showHealth
    and frame.__puiUF_oUFInitialized == true
    and frame:IsElementEnabled("Health")
    and healthBar.ForceUpdate
  then
    healthBar:ForceUpdate()
  end

  return healthBar
end

function UFHealth.RefreshMissingColor(frame, cfg, colors)
  if not frame or not frame.healthBG then
    return
  end

  local missing = (cfg and cfg.colors and cfg.colors.healthMissing)
    or (colors and colors.healthMissing)
    or { 1, 1, 1, 1 }
  frame.healthBG:SetVertexColor(missing[1], missing[2], missing[3], missing[4] or 1)
end






  P:SecDef("UFHealth.UpdateHealth", UFHealth, "UpdateHealth")
  P:SecDef("UFHealth.PostUpdateHealth", UFHealth, "PostUpdateHealth")
  P:SecDef("UFHealth.PostUpdateHealthColor", UFHealth, "PostUpdateHealthColor")
  EnsureFrameColors = P:Def("EnsureFrameColors", EnsureFrameColors)
  ConfigureHealthColors = P:Def("ConfigureHealthColors", ConfigureHealthColors)
  UFHealth.RefreshMissingColor = P:Def("UFHealth.RefreshMissingColor", UFHealth.RefreshMissingColor)
  UFHealth.RefreshColors = P:Def("UFHealth.RefreshColors", UFHealth.RefreshColors)
  UFHealth.Construct = P:Def("UFHealth.Construct", UFHealth.Construct)
  UFHealth.ConfigureFrame = P:Def("UFHealth.ConfigureFrame", UFHealth.ConfigureFrame)
