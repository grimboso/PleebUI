local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace

local Secondary = ns.PRDSecondary
local P = ns.Pleebug:DropIn({}, { name = "PRD_Secondary_Power" })

local function ReadPowerValues(owner, unit)
  if ns.Client.IsForever and owner.secondaryType == Enum.PowerType.ComboPoints then
    local points = GetComboPoints(unit, "target")
    if issecretvalue(points) then
      return nil, owner.secondaryMax
    end
    return points, owner.secondaryMax, points
  end

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

  local chargedMask = 0
  if owner.secondaryResourceConfig.behavior.colorChargedPoints
    and owner.secondaryResourceConfig.perSegment
  then
    local points = GetUnitChargedPowerPoints(unit)
    if not issecretvalue(points) and points then
      for index = 1, #points do
        local point = points[index]
        if not issecretvalue(point) then
          chargedMask = chargedMask + 2 ^ (point - 1)
        end
      end
    end
  end
  Secondary.ApplyDiscreteSecondaryBars(owner, current, maximum, r, g, b, a, chargedMask)

  if current == nil then
    Secondary.SetSecondaryCenterText(text, nil, false)
    return
  end

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
  if event == "UNIT_POWER_POINT_CHARGE" or event == "PLAYER_TARGET_CHANGED" or event == "COMBO_TARGET_CHANGED" then
    owner:UpdateSecondary()
    return
  end
  if event ~= "ADDON_RESTRICTION_STATE_CHANGED" and powerToken ~= owner.secondaryToken then
    return
  end

  if event == "UNIT_MAXPOWER" or event == "ADDON_RESTRICTION_STATE_CHANGED" then
    if owner.secondaryAdapter.key == "POWER_SECRET" then
      owner:UpdateSecondary()
      return
    end

    local maximum = UnitPowerMax("player", owner.secondaryType)
    if issecretvalue(maximum) or maximum == owner.secondaryMax then
      owner:UpdateSecondary()
      return
    end

    owner._puiSecondaryDefinitionDirty = true
    owner:RebuildSecondary()
    return
  end

  owner:UpdateSecondary()
end

local POWER_EVENTS = {
  UNIT_POWER_UPDATE = "player",
  UNIT_MAXPOWER = "player",
}
local CHARGED_POWER_EVENTS = {
  UNIT_POWER_UPDATE = "player",
  UNIT_MAXPOWER = "player",
  UNIT_POWER_POINT_CHARGE = "player",
}

local FOREVER_COMBO_EVENTS = {
  UNIT_POWER_UPDATE = "player",
  UNIT_MAXPOWER = "player",
  PLAYER_TARGET_CHANGED = true,
  COMBO_TARGET_CHANGED = true,
  ADDON_RESTRICTION_STATE_CHANGED = true,
}

Secondary:RegisterAdapter("POWER", {
  GetEvents = function(owner)
    if ns.Client.IsForever and owner.secondaryType == Enum.PowerType.ComboPoints then
      return FOREVER_COMBO_EVENTS
    end
    return owner.secondaryResourceConfig.behavior.colorChargedPoints and CHARGED_POWER_EVENTS or POWER_EVENTS
  end,
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
