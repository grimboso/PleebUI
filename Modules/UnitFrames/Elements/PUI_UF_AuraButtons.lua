local _, ns = ...

local _G = _G
local AuraButtons = {}
ns.UFAuraButtons = AuraButtons

local C_StringUtil = _G.C_StringUtil
local CreateFrame = _G.CreateFrame
local Enum = _G.Enum
local math_max = _G.math.max
local table_concat = _G.table.concat
local tonumber = _G.tonumber
local tostring = _G.tostring

local Theme = ns.Theme
local OptionsUtil = ns.OptionsUtil
local AuraWidget = ns.AuraWidget
local Round = ns.Pixel.Round

local DurationFormatter = C_StringUtil.CreateNumericRuleFormatter()
DurationFormatter:SetBreakpoints({
  {
    threshold = 0,
    step = 1,
    rounding = Enum.NumericRuleFormatRounding.Up,
    format = "%d",
  },
  {
    threshold = 60,
    step = 1,
    rounding = Enum.NumericRuleFormatRounding.Up,
    format = "%d:%02d",
    components = {
      {
        div = 60,
        step = 1,
        rounding = Enum.NumericRuleFormatRounding.Down,
      },
      {
        mod = 60,
        step = 1,
        rounding = Enum.NumericRuleFormatRounding.Down,
      },
    },
  },
  {
    threshold = 120,
    step = 60,
    rounding = Enum.NumericRuleFormatRounding.Up,
    format = "%dm",
    components = {
      {
        div = 60,
      },
    },
  },
})
AuraButtons.DurationFormatter = DurationFormatter

local function GetAppearance(element, kind, options)
  if options and options.__puiAuraAppearance then
    return options.__puiAuraAppearance
  end

  if element.__puiAuraAppearance then
    return element.__puiAuraAppearance
  end

  local auraType = kind == "debuffs" and "HARMFUL" or "HELPFUL"
  return ns.UFAuraFilters.BuildLegacyAppearance(element.__owner.__puiAuraContainerDB, auraType)
end

local function IsTooltipEnabled(appearance)
  return appearance.tooltips ~= false
end

local function GetColorChannels(color)
  if color.GetRGBA then
    return color:GetRGBA()
  end

  return color.r or color[1] or 0,
    color.g or color[2] or 0,
    color.b or color[3] or 0,
    color.a or color[4] or 1
end

local function GetColorSignature(color)
  local r, g, b, a = GetColorChannels(color or {})
  return table_concat({ tostring(r), tostring(g), tostring(b), tostring(a) }, ",")
end

function AuraButtons.BuildAppearanceSignature(appearance)
  appearance = appearance or {}

  return table_concat({
    appearance.tooltips ~= false and "1" or "0",
    appearance.clickThrough == true and "1" or "0",
    appearance.disableSwipe == true and "1" or "0",
    appearance.disableCountdownText == true and "1" or "0",
    tostring(appearance.borderSize or 0),
    GetColorSignature(appearance.borderColor),
    tostring(appearance.dispelBorderSize or 0),
    tostring(Theme.ResolveFontSize(tonumber(appearance.durationTextSize) or 11, "unitFrames")),
    tostring(OptionsUtil.FetchFontPath(appearance.durationFont, false)),
    tostring(Theme.NormalizeOutlineFlags(appearance.durationOutline or Theme.GetGlobalUIOutline()) or "OUTLINE"),
    tostring(appearance.durationAnchor or "TOPLEFT"),
    tostring(appearance.durationXOffset or 1),
    tostring(appearance.durationYOffset or -1),
    tostring(Theme.ResolveFontSize(tonumber(appearance.stackTextSize) or 11, "unitFrames")),
    tostring(OptionsUtil.FetchFontPath(appearance.stackFont, false)),
    tostring(Theme.NormalizeOutlineFlags(appearance.stackOutline or Theme.GetGlobalUIOutline()) or "OUTLINE"),
    tostring(appearance.stackAnchor or "BOTTOMRIGHT"),
    tostring(appearance.stackXOffset or -1),
    tostring(appearance.stackYOffset or 1),
  }, "\31")
end

local function CreateBorderTexture(button, subLevel)
  local texture = button:CreateTexture(nil, "OVERLAY", nil, subLevel)
  texture:SetColorTexture(1, 1, 1, 1)
  return texture
end

local function EnsureSquareBorder(button, key, subLevel)
  local border = button[key]
  if border then
    return border
  end

  border = {
    CreateBorderTexture(button, subLevel),
    CreateBorderTexture(button, subLevel),
    CreateBorderTexture(button, subLevel),
    CreateBorderTexture(button, subLevel),
  }
  border.Top = border[1]
  border.Bottom = border[2]
  border.Left = border[3]
  border.Right = border[4]
  button[key] = border

  return border
end

local function ApplySquareBorderLayout(border, button, size, manageVisibility)
  size = math_max(0, Round((tonumber(size) or 0) * ns.FrameScale:BestOnePixel()))

  border.Top:ClearAllPoints()
  border.Top:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  border.Top:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
  border.Top:SetHeight(size)

  border.Bottom:ClearAllPoints()
  border.Bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  border.Bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
  border.Bottom:SetHeight(size)

  border.Left:ClearAllPoints()
  border.Left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  border.Left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  border.Left:SetWidth(size)

  border.Right:ClearAllPoints()
  border.Right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
  border.Right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
  border.Right:SetWidth(size)

  if manageVisibility then
    local shown = size > 0
    border.Top:SetShown(shown)
    border.Bottom:SetShown(shown)
    border.Left:SetShown(shown)
    border.Right:SetShown(shown)
  end
end

local function ApplyStaticBorder(button, size, color)
  local border = EnsureSquareBorder(button, "StaticBorder", 6)
  ApplySquareBorderLayout(border, button, size, true)

  local r, g, b, a = GetColorChannels(color)
  border.Top:SetVertexColor(r, g, b, a)
  border.Bottom:SetVertexColor(r, g, b, a)
  border.Left:SetVertexColor(r, g, b, a)
  border.Right:SetVertexColor(r, g, b, a)
end

local function ApplyAuraTextFont(fontString, fontKey, size, outline)
  local flags = Theme.NormalizeOutlineFlags(outline or Theme.GetGlobalUIOutline()) or "OUTLINE"
  local shadow = flags:find("^SHADOW") ~= nil

  if shadow then
    flags = flags:gsub("^SHADOW", "")
  end

  fontString:SetFont(
    OptionsUtil.FetchFontPath(fontKey, false),
    Theme.ResolveFontSize(tonumber(size) or 11, "unitFrames"),
    flags
  )

  if shadow then
    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetShadowOffset(1, -1)
  else
    fontString:SetShadowColor(0, 0, 0, 0)
    fontString:SetShadowOffset(0, 0)
  end
end

local function ApplyAuraTextPoint(fontString, button, anchor, xOffset, yOffset)
  fontString:ClearAllPoints()
  fontString:SetPoint(anchor, button, anchor, Round(xOffset), Round(yOffset))
end

local function GetTextSettings(appearance)
  return {
    stackSize = tonumber(appearance.stackTextSize) or 11,
    stackFont = appearance.stackFont,
    stackOutline = appearance.stackOutline,
    stackAnchor = appearance.stackAnchor or "BOTTOMRIGHT",
    stackXOffset = tonumber(appearance.stackXOffset) or -1,
    stackYOffset = tonumber(appearance.stackYOffset) or 1,
    durationSize = tonumber(appearance.durationTextSize) or 11,
    durationFont = appearance.durationFont,
    durationOutline = appearance.durationOutline,
    durationAnchor = appearance.durationAnchor or "TOPLEFT",
    durationXOffset = tonumber(appearance.durationXOffset) or 1,
    durationYOffset = tonumber(appearance.durationYOffset) or -1,
  }
end

local function ApplyMouseSettings(button, appearance)
  local tooltipEnabled = IsTooltipEnabled(appearance)
  local clickEnabled = tooltipEnabled and appearance.clickThrough ~= true

  button:EnableMouse(tooltipEnabled)
  button:SetMouseMotionEnabled(tooltipEnabled)
  button:SetMouseClickEnabled(clickEnabled)
  button:SetTooltipAnchorPoint("ANCHOR_CURSOR", 0, 0)
  button:SetHideTooltipInCombat(false)
end

local function CreateIconButtonParts(button)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(button)
  button.PUIIcon = icon

  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  cooldown:SetAllPoints(button)
  button.PUIDurationCooldown = cooldown

  local textHolder = CreateFrame("Frame", nil, button)
  textHolder:SetAllPoints(button)
  button.PUITextHolder = textHolder

  local count = textHolder:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  textHolder.PUIApplicationCount = count

  local duration = textHolder:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  textHolder.PUIDurationText = duration
end

function AuraButtons.ApplyButtonAppearance(button, appearance, size, renderScale)
  local textSettings = GetTextSettings(appearance)
  renderScale = tonumber(renderScale) or 1
  size = math_max(Round(1), Round(tonumber(size) or 18))

  button:SetSize(size, size)
  button.Cooldown:SetDrawSwipe(appearance.disableSwipe ~= true)
  ApplyAuraTextFont(
    button.Count,
    textSettings.stackFont,
    textSettings.stackSize * renderScale,
    textSettings.stackOutline
  )
  ApplyAuraTextPoint(
    button.Count,
    button,
    textSettings.stackAnchor,
    textSettings.stackXOffset * renderScale,
    textSettings.stackYOffset * renderScale
  )
  ApplyAuraTextFont(
    button.Duration,
    textSettings.durationFont,
    textSettings.durationSize * renderScale,
    textSettings.durationOutline
  )
  ApplyAuraTextPoint(
    button.Duration,
    button,
    textSettings.durationAnchor,
    textSettings.durationXOffset * renderScale,
    textSettings.durationYOffset * renderScale
  )
  button.Duration:SetShown(appearance.disableCountdownText ~= true)
  ApplyStaticBorder(
    button,
    (tonumber(appearance.borderSize) or 0) * renderScale,
    appearance.borderColor
  )
end

function AuraButtons.ApplyPreviewDispelBorder(button, size, color)
  local border = EnsureSquareBorder(button, "DispelBorder", 7)
  ApplySquareBorderLayout(border, button, size, true)

  local r, g, b, a = GetColorChannels(color)
  border.Top:SetVertexColor(r, g, b, a)
  border.Bottom:SetVertexColor(r, g, b, a)
  border.Left:SetVertexColor(r, g, b, a)
  border.Right:SetVertexColor(r, g, b, a)
end

function AuraButtons.CreateButton(element, options, button)
  local kind = options.__puiAuraKind
  local size = math_max(Round(1), Round(tonumber(options.size) or 18))
  CreateIconButtonParts(button)
  local parts = AuraWidget.BindIconButton(button)

  local appearance = GetAppearance(element, kind, options)
  button:SetDurationText(parts.duration, {
    textFormatter = DurationFormatter,
  })

  if kind == "debuffs" then
    local dispelBorder = EnsureSquareBorder(button, "DispelBorder", 7)
    ApplySquareBorderLayout(
      dispelBorder,
      button,
      appearance.dispelBorderSize,
      false
    )

    for index = 1, #dispelBorder do
      button:AddDispelTypeTexture(dispelBorder[index], {
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        showWhenHarmful = true,
        showWhenHelpful = false,
        showWithoutDispelType = false,
        customDispelColorMap = element.__owner.colors.dispel,
      })
    end
  end

  ApplyMouseSettings(button, appearance)
  AuraButtons.ApplyButtonAppearance(button, appearance, size)
end

local P = select(1, ns.Pleebug:DropIn(AuraButtons, { name = "UnitFrames.AuraButtons" }))
ApplyAuraTextFont = P:Def("AuraButtons.ApplyAuraTextFont", ApplyAuraTextFont)
ApplyAuraTextPoint = P:Def("AuraButtons.ApplyAuraTextPoint", ApplyAuraTextPoint)
GetAppearance = P:Def("AuraButtons.GetAppearance", GetAppearance)
GetColorSignature = P:Def("AuraButtons.GetColorSignature", GetColorSignature)
AuraButtons.BuildAppearanceSignature = P:Def("AuraButtons.BuildAppearanceSignature", AuraButtons.BuildAppearanceSignature)
GetTextSettings = P:Def("AuraButtons.GetTextSettings", GetTextSettings)
CreateIconButtonParts = P:Def("AuraButtons.CreateIconButtonParts", CreateIconButtonParts)
AuraButtons.ApplyButtonAppearance = P:Def("AuraButtons.ApplyButtonAppearance", AuraButtons.ApplyButtonAppearance)
AuraButtons.ApplyPreviewDispelBorder = P:Def("AuraButtons.ApplyPreviewDispelBorder", AuraButtons.ApplyPreviewDispelBorder)
AuraButtons.CreateButton = P:Def("AuraButtons.CreateButton", AuraButtons.CreateButton)
IsTooltipEnabled = P:Def("AuraButtons.IsTooltipEnabled", IsTooltipEnabled)
GetColorChannels = P:Def("AuraButtons.GetColorChannels", GetColorChannels)
CreateBorderTexture = P:Def("AuraButtons.CreateBorderTexture", CreateBorderTexture)
EnsureSquareBorder = P:Def("AuraButtons.EnsureSquareBorder", EnsureSquareBorder)
ApplySquareBorderLayout = P:Def("AuraButtons.ApplySquareBorderLayout", ApplySquareBorderLayout)
ApplyStaticBorder = P:Def("AuraButtons.ApplyStaticBorder", ApplyStaticBorder)
ApplyMouseSettings = P:Def("AuraButtons.ApplyMouseSettings", ApplyMouseSettings)
