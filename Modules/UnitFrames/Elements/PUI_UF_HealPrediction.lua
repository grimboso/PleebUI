local ADDON_NAME, ns = ...

ns.UFHealPrediction = ns.UFHealPrediction or {}

local UFHealPrediction = ns.UFHealPrediction
local P = select(1, ns.Pleebug:DropIn(UFHealPrediction, { name = "UnitFrames.HealPrediction" }))

local _G = _G
local CreateFrame = _G.CreateFrame
local Enum = _G.Enum
local Round = ns.Pixel.Round
local LSM = ns.LSM

local STRIPES_TEXTURE = LSM:Fetch("statusbar", "PUI Stripes")
local THIN_STRIPES_TEXTURE = LSM:Fetch("statusbar", "PUI Thin Stripes")

local DAMAGE_ABSORB_CLAMP_MODE = Enum.UnitDamageAbsorbClampMode.MaximumHealth
local HEAL_ABSORB_CLAMP_MODE = Enum.UnitHealAbsorbClampMode.CurrentHealth
local INCOMING_HEAL_CLAMP_MODE = Enum.UnitIncomingHealClampMode.MissingHealth
local HEAL_ABSORB_MODE = Enum.UnitHealAbsorbMode.Total
local INCOMING_HEAL_OVERFLOW = 1.05

local function CreatePredictionBar(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar:Hide()
  return bar
end

local function CreatePredictionTexture(parent, texturePath)
  local texture = parent:CreateTexture(nil, "OVERLAY")
  texture:SetTexture(texturePath)
  texture:SetBlendMode("ADD")
  texture:SetAlpha(0)
  texture:Hide()
  return texture
end

function UFHealPrediction.ConfigurePredictionTexture(bar, texture)
  bar:SetStatusBarTexture(texture)

  local statusTexture = bar:GetStatusBarTexture()
  local tiled = texture == STRIPES_TEXTURE or texture == THIN_STRIPES_TEXTURE

  statusTexture:SetHorizTile(tiled)
  statusTexture:SetVertTile(tiled)
end

local function ConfigurePredictionBar(bar, texture, frameLevel, orientation, reverseFill, frameStrata)
  bar:SetFrameStrata(frameStrata)
  bar:SetFrameLevel(frameLevel)
  bar:SetOrientation(orientation)
  bar:SetReverseFill(reverseFill)
  UFHealPrediction.ConfigurePredictionTexture(bar, texture)
end

local function AnchorPredictionBar(bar, healthBar, relativeTexture, orientation, point, relativePoint)
  bar:ClearAllPoints()

  if orientation == "VERTICAL" then
    bar:SetPoint("LEFT", healthBar, "LEFT", 0, 0)
    bar:SetPoint("RIGHT", healthBar, "RIGHT", 0, 0)
  else
    bar:SetPoint("TOP", healthBar, "TOP", 0, 0)
    bar:SetPoint("BOTTOM", healthBar, "BOTTOM", 0, 0)
  end

  bar:SetPoint(point, relativeTexture, relativePoint, 0, 0)
end

local function AnchorOverflowIndicator(indicator, healthBar, orientation, point, relativePoint)
  indicator:ClearAllPoints()

  if orientation == "VERTICAL" then
    indicator:SetPoint("LEFT", healthBar, "LEFT", 0, 0)
    indicator:SetPoint("RIGHT", healthBar, "RIGHT", 0, 0)
    indicator:SetPoint(point, healthBar, relativePoint, 0, 0)
    indicator:SetHeight(Round(8))
  else
    indicator:SetPoint("TOP", healthBar, "TOP", 0, 0)
    indicator:SetPoint("BOTTOM", healthBar, "BOTTOM", 0, 0)
    indicator:SetPoint(point, healthBar, relativePoint, 0, 0)
    indicator:SetWidth(Round(8))
  end
end

local function HidePredictionWidgets(widgets)
  widgets.healingPlayer:Hide()
  widgets.healingOther:Hide()
  widgets.damageAbsorb:Hide()
  widgets.healAbsorb:Hide()
  widgets.overHealIndicator:Hide()
  widgets.overHealAbsorbIndicator:Hide()
end

local function GetPredictionFlags(frame)
  local profile = ns.UnitFrames.db.profile
  local settings = profile.healthPrediction
  if frame.config and frame.config.hideHealth == true then
    return false, false, false
  end
  return settings.incomingHeals ~= false,
    settings.damageAbsorbs ~= false,
    settings.healAbsorbs ~= false
end

local function ApplyNativePredictionWidgets(frame)
  local healthBar = frame.Health
  local widgets = healthBar.__puiPredictionWidgets
  local incomingHeals, damageAbsorbs, healAbsorbs = GetPredictionFlags(frame)
  local usePrediction = incomingHeals or damageAbsorbs or healAbsorbs
  local selectionChanged = (healthBar.HealingPlayer == widgets.healingPlayer) ~= incomingHeals
    or (healthBar.DamageAbsorb == widgets.damageAbsorb) ~= damageAbsorbs
    or (healthBar.HealAbsorb == widgets.healAbsorb) ~= healAbsorbs
    or (healthBar.Override == nil) ~= usePrediction
  local initialized = frame.__puiUF_oUFInitialized == true
  local enabled = initialized and frame:IsElementEnabled("Health") == true
  local paused = enabled and frame:IsElementPaused("Health") == true
  local rebind = selectionChanged and enabled and not paused
  if rebind then
    frame:DisableElement("Health")
  end
  healthBar.HealingPlayer = incomingHeals and widgets.healingPlayer or nil
  healthBar.HealingOther = incomingHeals and widgets.healingOther or nil
  healthBar.OverHealIndicator = incomingHeals and widgets.overHealIndicator or nil
  healthBar.DamageAbsorb = damageAbsorbs and widgets.damageAbsorb or nil
  healthBar.HealAbsorb = healAbsorbs and widgets.healAbsorb or nil
  healthBar.OverHealAbsorbIndicator = healAbsorbs and widgets.overHealAbsorbIndicator or nil
  if usePrediction then
    healthBar.Override = nil
  else
    healthBar.Override = ns.UFHealth.UpdateHealth
  end
  if not incomingHeals then
    widgets.healingPlayer:Hide()
    widgets.healingOther:Hide()
    widgets.overHealIndicator:Hide()
  end
  if not damageAbsorbs then
    widgets.damageAbsorb:Hide()
  end
  if not healAbsorbs then
    widgets.healAbsorb:Hide()
    widgets.overHealAbsorbIndicator:Hide()
  end
  if rebind then
    frame:EnableElement("Health")
  end
  return incomingHeals, damageAbsorbs, healAbsorbs, rebind
end

function UFHealPrediction.Construct(healthBar)
  healthBar.__puiPredictionWidgets = {
    healingPlayer = CreatePredictionBar(healthBar),
    healingOther = CreatePredictionBar(healthBar),
    damageAbsorb = CreatePredictionBar(healthBar),
    healAbsorb = CreatePredictionBar(healthBar),
    overHealIndicator = CreatePredictionTexture(healthBar, [[Interface\RaidFrame\Shield-Overshield]]),
    overHealAbsorbIndicator = CreatePredictionTexture(healthBar, [[Interface\RaidFrame\Absorb-Overabsorb]]),
  }
  healthBar.damageAbsorbClampMode = DAMAGE_ABSORB_CLAMP_MODE
  healthBar.healAbsorbClampMode = HEAL_ABSORB_CLAMP_MODE
  healthBar.healAbsorbMode = HEAL_ABSORB_MODE
  healthBar.incomingHealClampMode = INCOMING_HEAL_CLAMP_MODE
  healthBar.incomingHealOverflow = INCOMING_HEAL_OVERFLOW
  ApplyNativePredictionWidgets(healthBar:GetParent())
end

function UFHealPrediction.Configure(frame, predictionTexture)
  local healthBar = frame.Health
  local widgets = healthBar.__puiPredictionWidgets
  local profile = ns.UnitFrames.db.profile
  local incomingHeals, damageAbsorbs, healAbsorbs, rebound = ApplyNativePredictionWidgets(frame)
  if not incomingHeals and not damageAbsorbs and not healAbsorbs then
    HidePredictionWidgets(widgets)
    if rebound and healthBar.ForceUpdate then
      healthBar:ForceUpdate()
    end
    return
  end
  local playerHealColor = profile.colors.healthIncomingPlayer
  local otherHealColor = profile.colors.healthIncomingOther
  local absorbColor = profile.colors.healthAbsorb
  local healAbsorbColor = profile.colors.healthHealAbsorb
  local orientation = healthBar:GetOrientation()
  local reverseFill = healthBar:GetReverseFill()
  local baseLevel = healthBar:GetFrameLevel()
  local frameStrata = healthBar:GetFrameStrata()
  local healthTexture = healthBar:GetStatusBarTexture()
  local point
  local relativePoint
  local backfillPoint
  if orientation == "VERTICAL" then
    point = reverseFill and "TOP" or "BOTTOM"
    relativePoint = reverseFill and "BOTTOM" or "TOP"
    backfillPoint = reverseFill and "BOTTOM" or "TOP"
  else
    point = reverseFill and "RIGHT" or "LEFT"
    relativePoint = reverseFill and "LEFT" or "RIGHT"
    backfillPoint = reverseFill and "LEFT" or "RIGHT"
  end
  if incomingHeals then
    ConfigurePredictionBar(widgets.healingPlayer, predictionTexture, baseLevel + 1, orientation, reverseFill, frameStrata)
    ConfigurePredictionBar(widgets.healingOther, predictionTexture, baseLevel + 2, orientation, reverseFill, frameStrata)
    widgets.healingPlayer:SetStatusBarColor(playerHealColor[1], playerHealColor[2], playerHealColor[3], playerHealColor[4])
    widgets.healingOther:SetStatusBarColor(otherHealColor[1], otherHealColor[2], otherHealColor[3], otherHealColor[4])
    AnchorPredictionBar(widgets.healingPlayer, healthBar, healthTexture, orientation, point, relativePoint)
    AnchorPredictionBar(widgets.healingOther, healthBar, widgets.healingPlayer:GetStatusBarTexture(), orientation, point, relativePoint)
    AnchorOverflowIndicator(widgets.overHealIndicator, healthBar, orientation, point, relativePoint)
  end
  if damageAbsorbs then
    ConfigurePredictionBar(widgets.damageAbsorb, predictionTexture, baseLevel + 3, orientation, not reverseFill, frameStrata)
    widgets.damageAbsorb:SetStatusBarColor(absorbColor[1], absorbColor[2], absorbColor[3], absorbColor[4])
    AnchorPredictionBar(widgets.damageAbsorb, healthBar, healthTexture, orientation, backfillPoint, backfillPoint)
  end
  if healAbsorbs then
    ConfigurePredictionBar(widgets.healAbsorb, predictionTexture, baseLevel + 4, orientation, not reverseFill, frameStrata)
    widgets.healAbsorb:SetStatusBarColor(healAbsorbColor[1], healAbsorbColor[2], healAbsorbColor[3], healAbsorbColor[4])
    AnchorPredictionBar(widgets.healAbsorb, healthBar, healthTexture, orientation, backfillPoint, backfillPoint)
    AnchorOverflowIndicator(widgets.overHealAbsorbIndicator, healthBar, orientation, relativePoint, point)
  end
  if rebound and healthBar.ForceUpdate then
    healthBar:ForceUpdate()
  end
end

CreatePredictionBar = P:Def("CreatePredictionBar", CreatePredictionBar)
CreatePredictionTexture = P:Def("CreatePredictionTexture", CreatePredictionTexture)
UFHealPrediction.ConfigurePredictionTexture = P:Def(
  "UFHealPrediction.ConfigurePredictionTexture",
  UFHealPrediction.ConfigurePredictionTexture
)
ConfigurePredictionBar = P:Def("ConfigurePredictionBar", ConfigurePredictionBar)
AnchorPredictionBar = P:Def("AnchorPredictionBar", AnchorPredictionBar)
AnchorOverflowIndicator = P:Def("AnchorOverflowIndicator", AnchorOverflowIndicator)
HidePredictionWidgets = P:Def("HidePredictionWidgets", HidePredictionWidgets)
GetPredictionFlags = P:Def("GetPredictionFlags", GetPredictionFlags)
ApplyNativePredictionWidgets = P:Def("ApplyNativePredictionWidgets", ApplyNativePredictionWidgets)
UFHealPrediction.Construct = P:Def("UFHealPrediction.Construct", UFHealPrediction.Construct)
UFHealPrediction.Configure = P:Def("UFHealPrediction.Configure", UFHealPrediction.Configure)
