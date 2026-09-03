local ADDON_NAME, ns = ...

local Secondary = ns.PRDSecondary
local P = ns.Pleebug:DropIn({}, { name = "PRD_Secondary_Power" })

local function ReadPowerValues(owner, unit)
  local current = UnitPower(unit, owner.secondaryType, owner.secondaryPowerPrecise)
  local divisor = owner.secondaryCurrentDivisor
  if divisor ~= 1 then
    current = current / divisor
  end

  local displayValue = owner.secondaryDisplayFloor and math.floor(current + 0.0001) or current
  return current, owner.secondaryMax, displayValue
end

local function BuildPower(owner)
  local cfg = owner.secondaryResourceConfig

  if cfg.perSegment == true then
    Secondary.BuildSegmented(owner, owner.secondaryMax)
  else
    Secondary.BuildContinuous(owner, owner.secondaryMax, owner.secondaryMax)
  end
end

local function BuildSecretPower(owner)
  Secondary.BuildContinuous(owner, 1, nil)
end

local function UpdatePower(owner, bar, text, unit)
  local current, maximum, displayValue = ReadPowerValues(owner, unit)
  local r, g, b, a = owner._puiSecColorR, owner._puiSecColorG, owner._puiSecColorB, owner._puiSecColorA

  Secondary.ApplyDiscreteSecondaryBars(owner, current, maximum, r, g, b, a)

  local displayMaximum = maximum
  if maximum == math.floor(maximum) then
    displayMaximum = math.floor(maximum)
  end

  local value, shouldShow = Secondary.FormatSecondaryText(
    owner,
    current,
    maximum,
    nil,
    displayValue,
    displayMaximum
  )
  Secondary.SetSecondaryCenterText(text, value, shouldShow)
end

local function UpdateSecretPower(owner, bar, text, unit)
  local def = owner.secondaryDef
  local statusBar = owner.secondaryStatusBar

  statusBar:SetMinMaxValues(0, UnitPowerMax(unit, def.powerType))
  statusBar:SetValue(UnitPower(unit, def.powerType))

  local r, g, b, a = owner._puiSecColorR, owner._puiSecColorG, owner._puiSecColorB, owner._puiSecColorA
  statusBar:SetStatusBarColor(r, g, b, a)
  statusBar:Show()

  Secondary.SetSecondaryCenterText(text, nil, false)
end

local function OnEvent(owner, event, _, powerToken)
  if powerToken ~= owner.secondaryToken then
    return
  end

  if event == "UNIT_MAXPOWER" then
    owner:RebuildSecondary()
    return
  end

  owner:UpdateSecondary()
end

Secondary:RegisterAdapter("POWER", {
  events = {
    UNIT_POWER_UPDATE = "player",
    UNIT_MAXPOWER = "player",
  },
  Build = P:Def("Power.Build", BuildPower),
  OnEvent = P:Def("Power.OnEvent", OnEvent),
  Update = P:Def("Power.Update", UpdatePower),
})

Secondary:RegisterAdapter("POWER_SECRET", {
  events = {
    UNIT_POWER_UPDATE = "player",
    UNIT_MAXPOWER = "player",
  },
  Build = P:Def("PowerSecret.Build", BuildSecretPower),
  OnEvent = P:Def("PowerSecret.OnEvent", OnEvent),
  Update = P:Def("PowerSecret.Update", UpdateSecretPower),
})
