local _, ns = ...

local Presentation = ns.Presentation
local UFStyle = ns.UFStyle
local UFHealth = ns.UFHealth
local UFPower = ns.UFPower
local UFPortrait = ns.UFPortrait
local UFText = ns.UFText

local UnitFramePresentation = {}
ns.UFPresentation = UnitFramePresentation

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local tonumber = tonumber
local type = type

local PreviewFrameIndex = 0

local function SetElementEnabled(frame, element, enabled)
  frame.__puiPresentationElements[element] = enabled == true
end

local function PreparePreviewFrame(frame)
  frame.__puiPresentationElements = {}

  frame.IsElementEnabled = function(self, element)
    return self.__puiPresentationElements[element] == true
  end

  frame.EnableElement = function(self, element)
    SetElementEnabled(self, element, true)
  end

  frame.DisableElement = function(self, element)
    SetElementEnabled(self, element, false)
  end

  frame.UpdateAllElements = function() end
  frame.RegisterForClicks = function() end
end

local function ApplyProvider(frame, state)
  local provider = frame.__puiPresentationProvider
  if not provider then
    return
  end

  local healthMax = tonumber(Presentation.Read(provider, "healthMax", 100, frame, state)) or 100
  local health = tonumber(Presentation.Read(provider, "health", healthMax, frame, state)) or healthMax
  local powerMin = tonumber(Presentation.Read(provider, "powerMin", 0, frame, state)) or 0
  local powerMax = tonumber(Presentation.Read(provider, "powerMax", 100, frame, state)) or 100
  local power = tonumber(Presentation.Read(provider, "power", powerMax, frame, state)) or powerMax

  frame.Health:SetMinMaxValues(0, healthMax)
  frame.Health:SetValue(health)

  frame.Power:SetMinMaxValues(powerMin, powerMax)
  frame.Power:SetValue(power)

  local name = Presentation.Read(provider, "name", nil, frame, state)
  if name ~= nil then
    frame.NameText:SetText(name)
  end

  local healthText = Presentation.Read(provider, "healthText", nil, frame, state)
  if healthText ~= nil then
    frame.HealthText:SetText(healthText)
  end

  local powerText = Presentation.Read(provider, "powerText", nil, frame, state)
  if powerText ~= nil then
    frame.PowerText:SetText(powerText)
  end

  local healthColor = Presentation.Read(provider, "healthColor", nil, frame, state)
  if type(healthColor) == "table" then
    frame.Health:SetStatusBarColor(
      healthColor[1] or healthColor.r or 1,
      healthColor[2] or healthColor.g or 1,
      healthColor[3] or healthColor.b or 1,
      healthColor[4] or healthColor.a or 1
    )
  end

  local powerColor = Presentation.Read(provider, "powerColor", nil, frame, state)
  if type(powerColor) == "table" then
    frame.Power:SetStatusBarColor(
      powerColor[1] or powerColor.r or 1,
      powerColor[2] or powerColor.g or 1,
      powerColor[3] or powerColor.b or 1,
      powerColor[4] or powerColor.a or 1
    )
  end

  local healthMissingColor = Presentation.Read(provider, "healthMissingColor", nil, frame, state)
  if type(healthMissingColor) == "table" and frame.healthBG then
    frame.healthBG:SetVertexColor(
      healthMissingColor[1] or healthMissingColor.r or 1,
      healthMissingColor[2] or healthMissingColor.g or 1,
      healthMissingColor[3] or healthMissingColor.b or 1,
      healthMissingColor[4] or healthMissingColor.a or 1
    )
  end
end

function UnitFramePresentation.Create(parent, context)
  PreviewFrameIndex = PreviewFrameIndex + 1

  local frame = CreateFrame(
    "Frame",
    "PleebUI_UnitFramePresentation" .. PreviewFrameIndex,
    parent
  )

  PreparePreviewFrame(frame)
  frame.__puiPresentationFrame = true

  local unit = context.unit or "player"
  local cfg = context.config

  frame.unit = unit
  frame.config = cfg
  frame.__puiUseConfigText = context.useConfigText == true
  frame.__puiUseClassColor = context.useClassColor

  UFStyle.CreateRaisedElement(frame)
  UFHealth.Construct(frame)
  UFPower.Construct(frame, unit)
  UFText.Construct(frame, unit, cfg, true)

  frame.__puiAuraPreviewBackground = frame.__pui_bg
  frame.__puiAuraPreviewHealth = frame.Health
  frame.__puiAuraPreviewPower = frame.Power
  frame.__puiAuraPreviewName = frame.NameText
  frame.__puiAuraPreviewHealthText = frame.HealthText
  frame.__puiAuraPreviewPowerText = frame.PowerText

  return frame
end

function UnitFramePresentation.BindDataProvider(frame, provider)
  frame.__puiPresentationProvider = provider
end

function UnitFramePresentation.ApplyStyle(frame, state)
  local cfg = state.config
  local colors = state.colors or UFStyle.GetUFThemeColors()
  local layout = state.layout

  if state.useClassColor ~= nil then
    frame.__puiUseClassColor = state.useClassColor
  end

  UFStyle.ConfigureFrameChrome(frame, layout, colors)

  if state.refreshOnly == true then
    UFHealth.RefreshColors(frame, cfg, colors)
    UFPower.RefreshColors(frame, cfg, colors)
    UFText.ApplyTextColors(frame, state.textColors or colors)
  end

  frame.__puiAuraPreviewBackground = frame.__pui_bg
end

function UnitFramePresentation.ApplyGeometry(frame, state)
  if state.refreshOnly == true then
    return
  end

  local unit = state.unit or frame.__unit or frame.unit or "player"
  local cfg = state.config
  local layout = state.layout
  local colors = state.colors or UFStyle.GetUFThemeColors()
  local opts = state.options or {}

  if frame.__puiPresentationFrame == true then
    frame.unit = unit
  end
  frame.config = cfg
  frame.__puiUseConfigText = opts.useConfigText == true or frame.__puiUseConfigText == true

  if frame.__puiPresentationKey == "UnitFrame" or not InCombatLockdown() then
    frame:SetSize(layout.width or 200, layout.totalHeight or 22)
  end

  UFHealth.ConfigureFrame(frame, unit, cfg, layout, colors)
  UFPower.ConfigureFrame(frame, unit, cfg, layout, colors, {
    forceNoPower = opts.forceNoPower == true,
  })

  local portraitDB = cfg and cfg.portrait
  if portraitDB and portraitDB.enabled == true and UFPortrait.IsApplicableUnit(unit, opts.groupKind) then
    if frame.__puiPresentationFrame == true then
      UFPortrait.ConfigurePreview(frame, cfg, layout)
    else
      UFPortrait.ConfigureFrame(frame, unit, cfg, layout)
    end
  elseif frame.__puiPresentationFrame == true then
    if frame.__puiPortraitPreviewEnabled == true then
      UFPortrait.DisablePreview(frame)
    end
  elseif frame.__puiPortraitEnabled == true then
    UFPortrait.Disable(frame)
  end

  UFText.ApplyFrame(frame, unit, cfg, state.fontRevision or 0, {
    forceNoPower = opts.forceNoPower == true,
    colors = state.textColors or colors,
    groupKind = opts.groupKind,
    useConfigText = opts.useConfigText == true,
  })
  UFStyle.UpdateOverlayLevels(frame)
end

function UnitFramePresentation.ApplyVisibility(frame, state)
  if state.skipVisibility == true then
    return
  end

  local cfg = state.config

  if cfg and cfg.enabled == false and state.forceShown ~= true then
    frame:Hide()
    return
  end

  ApplyProvider(frame, state)
  frame:Show()
end

function UnitFramePresentation.Release(frame)
  frame.__puiPresentationProvider = nil
  if frame.__puiPortraitPreviewEnabled == true then
    UFPortrait.DisablePreview(frame)
  end
  frame:Hide()
  frame:ClearAllPoints()
end

Presentation.Register("UnitFrame", UnitFramePresentation)

local P = select(1, ns.Pleebug:DropIn(UnitFramePresentation, { name = "UnitFrames.Presentation" }))
UnitFramePresentation.Create = P:Def("UnitFramePresentation.Create", UnitFramePresentation.Create)
UnitFramePresentation.BindDataProvider = P:Def("UnitFramePresentation.BindDataProvider", UnitFramePresentation.BindDataProvider)
UnitFramePresentation.ApplyStyle = P:Def("UnitFramePresentation.ApplyStyle", UnitFramePresentation.ApplyStyle)
UnitFramePresentation.ApplyGeometry = P:Def("UnitFramePresentation.ApplyGeometry", UnitFramePresentation.ApplyGeometry)
UnitFramePresentation.ApplyVisibility = P:Def("UnitFramePresentation.ApplyVisibility", UnitFramePresentation.ApplyVisibility)
UnitFramePresentation.Release = P:Def("UnitFramePresentation.Release", UnitFramePresentation.Release)
