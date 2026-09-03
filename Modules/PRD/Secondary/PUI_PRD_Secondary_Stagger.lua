local ADDON_NAME, ns = ...

local Secondary = ns.PRDSecondary
local P = ns.Pleebug:DropIn({}, { name = "PRD_Secondary_Stagger" })

local function IsRestricted(value)
  return issecretvalue(value) == true
end

local function OnEvent(owner, event, unit)
  if unit == "player" then
    owner:UpdateSecondary()
  end
end

local function Build(owner)
  Secondary.BuildContinuous(owner, 1, nil)
end

local function Update(owner, bar, text, unit)
  local statusBar = owner.secondaryStatusBar
  local stagger = UnitStagger(unit)
  local maxHealth = UnitHealthMax(unit)

  if IsRestricted(stagger) or IsRestricted(maxHealth) then
    statusBar._puiStaggerLastMax = nil
    statusBar._puiStaggerLastValue = nil
    statusBar._puiStaggerColorMode = nil
    statusBar._puiStaggerColorKey = nil
    statusBar:SetMinMaxValues(0, maxHealth)
    statusBar:SetValue(stagger)

    local r, g, b, a = owner._puiSecColorR, owner._puiSecColorG, owner._puiSecColorB, owner._puiSecColorA
    statusBar:SetStatusBarColor(r, g, b, a)
    statusBar:Show()

    Secondary.SetSecondaryCenterText(text, nil, false)
    return
  end

  stagger = tonumber(stagger) or 0
  maxHealth = tonumber(maxHealth) or 0

  if maxHealth <= 0 then
    maxHealth = 1
  end

  if statusBar._puiStaggerLastMax ~= maxHealth then
    statusBar._puiStaggerLastMax = maxHealth
    statusBar:SetMinMaxValues(0, maxHealth)
  end

  if statusBar._puiStaggerLastValue ~= stagger then
    statusBar._puiStaggerLastValue = stagger
    statusBar:SetValue(stagger)
  end

  local behavior = owner.secondaryResourceConfig.behavior
  local percentage = stagger / maxHealth * 100
  local low = tonumber(behavior.yellowThreshold) or 30
  local high = tonumber(behavior.redThreshold) or 60
  local bucket = 1

  if percentage >= high then
    bucket = 3
  elseif percentage >= low then
    bucket = 2
  end

  if behavior.useSeverityColors ~= false then
    if statusBar._puiStaggerColorMode ~= "SEVERITY"
      or statusBar._puiStaggerColorKey ~= bucket
    then
      statusBar._puiStaggerColorMode = "SEVERITY"
      statusBar._puiStaggerColorKey = bucket

      if bucket == 3 then
        statusBar:SetStatusBarColor(1, 0, 0, 1)
      elseif bucket == 2 then
        statusBar:SetStatusBarColor(1, 1, 0, 1)
      else
        statusBar:SetStatusBarColor(0, 1, 0, 1)
      end
    end
  else
    local r, g, b, a = owner._puiSecColorR, owner._puiSecColorG, owner._puiSecColorB, owner._puiSecColorA
    local colorKey = Secondary.PackResourceColor(r, g, b, a)

    if statusBar._puiStaggerColorMode ~= "RESOURCE"
      or statusBar._puiStaggerColorKey ~= colorKey
    then
      statusBar._puiStaggerColorMode = "RESOURCE"
      statusBar._puiStaggerColorKey = colorKey
      statusBar:SetStatusBarColor(r, g, b, a)
    end
  end

  local currentDisplay = math.floor(stagger + 0.5)
  local maximumDisplay = math.floor(maxHealth + 0.5)
  local value, shouldShow = Secondary.FormatSecondaryText(
    owner,
    stagger,
    maxHealth,
    percentage,
    currentDisplay,
    maximumDisplay
  )

  if shouldShow and behavior.showSeverityLabel == true then
    if owner._puiStaggerTextBucket ~= bucket
      or owner._puiStaggerTextBaseValue ~= value
    then
      owner._puiStaggerTextBucket = bucket
      owner._puiStaggerTextBaseValue = value
      local label = bucket == 3 and "HIGH" or bucket == 2 and "MED" or "LOW"
      owner._puiStaggerTextValue = label .. "  " .. value
    end
    value = owner._puiStaggerTextValue
  else
    owner._puiStaggerTextBucket = nil
    owner._puiStaggerTextBaseValue = nil
    owner._puiStaggerTextValue = nil
  end

  Secondary.SetSecondaryCenterText(text, value, shouldShow)
end


Secondary:RegisterAdapter("STAGGER", {
  events = {
    UNIT_HEALTH = "player",
    UNIT_MAXHEALTH = "player",
  },
  Build = P:Def("Stagger.Build", Build),
  OnEvent = P:Def("Stagger.OnEvent", OnEvent),
  Update = P:Def("Stagger.Update", Update),
})
