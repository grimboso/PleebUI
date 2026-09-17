local ADDON_NAME, ns = ...

local Addon = ns.Addon

local OptionsUtil = ns.OptionsUtil
local Presentation = ns.Presentation
local Theme = ns.Theme
local FrameUtil = ns.FrameUtil
local AuraWidget = ns.AuraWidget
local LSM = ns.LSM

local P = ns.Pleebug:DropIn({}, { name = "PRD_Config" })
local _, PLAYER_CLASS = UnitClass("player")

local PRDPreview = {}
ns.PRDPreview = PRDPreview

function PRDPreview.MarkDirty()
  local box = PRDPreview.box
  if box then
    box.__puiPRDPreviewDirty = true
  end
end

local CreateFrame = CreateFrame
local UnitPowerType = UnitPowerType
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local PowerBarColor = PowerBarColor
local AbbreviateLargeNumbers = AbbreviateLargeNumbers
local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_sin = math.sin
local tonumber = tonumber
local tostring = tostring
local type = type
local ipairs = ipairs
local pairs = pairs
local unpack = unpack

local PRD_PREVIEW_STATUSBAR_FALLBACK = Theme.GetBarTexture()
local PRD_PREVIEW_DETACHED_GAP = 12
local PRD_PREVIEW_SEGMENT_GAP = 0

local function PRDPreview_Clamp(value, minimum, maximum)
  value = tonumber(value) or minimum
  if value < minimum then
    return minimum
  elseif value > maximum then
    return maximum
  end
  return value
end

local function PRDPreview_CopyColor(color, r, g, b, a)
  color = color or {}
  return {
    tonumber(color[1] or color.r) or r,
    tonumber(color[2] or color.g) or g,
    tonumber(color[3] or color.b) or b,
    tonumber(color[4] or color.a) or a,
  }
end

local function PRDPreview_FetchStatusbar(key)
  return LSM:Fetch("statusbar", key or "Pleebar", true) or PRD_PREVIEW_STATUSBAR_FALLBACK
end

local function PRDPreview_SetTexture(statusBar, textureKey)
  statusBar:SetStatusBarTexture(PRDPreview_FetchStatusbar(textureKey))

  local texture = statusBar:GetStatusBarTexture()
  if texture then
    texture:SetHorizTile(false)
    texture:SetVertTile(false)
    texture:SetTexCoord(0, 1, 0, 1)
  end
end

local function PRDPreview_ResolveClassColor()
  local color = RAID_CLASS_COLORS[PLAYER_CLASS]
  return color.r, color.g, color.b, color.a or 1
end

local function PRDPreview_ResolveNativeColor(role, config)
  config = config or {}

  local mode = config.colorMode or "DEFAULT"

  if mode == "CUSTOM" then
    local color = config.customColor or { 1, 1, 1, 1 }
    return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
  elseif mode == "CLASS" then
    return PRDPreview_ResolveClassColor()
  elseif mode == "TEXTURE" then
    return 1, 1, 1, 1
  end

  local PRD = ns.Modules.PRD
  local liveBar = role == "health" and PRD.healthBar or PRD.primaryBar

  if liveBar then
    local r, g, b, a = liveBar:GetStatusBarColor()
    if r ~= nil then
      return r, g or 1, b or 1, a or 1
    end
  end

  if role == "health" then
    return 0.15, 0.85, 0.22, 1
  end

  local _, token = UnitPowerType("player")
  local color = token and PowerBarColor[token]

  if color then
    return color.r or 0.15, color.g or 0.45, color.b or 1, color.a or 1
  end

  return 0.15, 0.45, 1, 1
end

local function PRDPreview_ResolveResourceColor(config, definition)
  config = config or {}
  definition = definition or {}

  if config.useCustomColor == true then
    return unpack(PRDPreview_CopyColor(config.customColor, 1, 1, 1, 1))
  elseif config.useClassColor == true then
    return PRDPreview_ResolveClassColor()
  elseif config.useBlizzardPowerColor == true then
    local token = definition.colorToken or definition.token
    local color = token and PowerBarColor[token]

    if color then
      return color.r or 1, color.g or 1, color.b or 1, color.a or 1
    end

    return unpack(PRDPreview_CopyColor(
      config.defaultColor or definition.defaultColor,
      1,
      1,
      1,
      1
    ))
  end

  return 1, 1, 1, 1
end

local function PRDPreview_ConfigureStackColorSegments(bar, maximum, config)
  local parts = bar.__puiStackColorParts
  if not parts then
    parts = {
      applicationBar = bar.status,
      applicationThresholds = {},
    }
    bar.__puiStackColorParts = parts
  end

  AuraWidget.ConfigureApplicationThresholds(
    parts,
    config and config.stackColorThresholds,
    PRDPreview_FetchStatusbar(config and config.texture),
    "HORIZONTAL",
    false,
    RAID_CLASS_COLORS[PLAYER_CLASS],
    maximum
  )
end

local function PRD_UsesSecondaryResourceTabs(resourceOptions)
  resourceOptions = resourceOptions or ns.PRDSecondary:GetResourceOptionsForClass(PLAYER_CLASS)
  return #resourceOptions > 1
end

local function PRDPreview_GetResourceOptionCategory(resourceKey)
  local resources = ns.PRDSecondary:GetResourceOptionsForClass(PLAYER_CLASS)

  for index = 1, #resources do
    local resource = resources[index]

    if resource.key == resourceKey then
      return resource.category == "TRACKED_EFFECT"
        and "trackedEffectsGroup"
        or "classResourcesGroup"
    end
  end

  return "classResourcesGroup"
end

local function PRDPreview_Navigate(box, path, sectionKey, optionKey)
  ns.PreviewBox.NavigateToOption(
    box.__puiPRDPreviewAddon or Addon,
    path,
    sectionKey,
    optionKey
  )
end

local function PRDPreview_SetBarHovered(bar, hovered)
  bar.frame.__puiPRDPreviewHovered = hovered == true or nil
end

local function PRDPreview_CreateInteraction(parent, anchor, frameLevel)
  return ns.PreviewBox.CreateInteraction(parent, anchor, {
    frameLevel = frameLevel,
  })
end

local function PRDPreview_CreateEdgeInteractions(bar)
  local frame = bar.frame
  local frameLevel = frame:GetFrameLevel() + 60
  local top = PRDPreview_CreateInteraction(frame, frame, frameLevel)
  local bottom = PRDPreview_CreateInteraction(frame, frame, frameLevel + 1)
  local left = PRDPreview_CreateInteraction(frame, frame, frameLevel + 2)
  local right = PRDPreview_CreateInteraction(frame, frame, frameLevel + 3)

  top:ClearAllPoints()
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  top:SetHeight(5)

  bottom:ClearAllPoints()
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(5)

  left:ClearAllPoints()
  left:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT", 0, 0)
  left:SetWidth(5)

  right:ClearAllPoints()
  right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0)
  right:SetWidth(5)

  return {
    top,
    bottom,
    left,
    right,
  }
end

local function PRDPreview_CreateBarInteractions(bar)
  local frame = bar.frame
  local body = PRDPreview_CreateInteraction(
    frame,
    frame,
    frame:GetFrameLevel() + 40
  )

  local leftText = PRDPreview_CreateInteraction(
    frame,
    frame,
    frame:GetFrameLevel() + 50
  )
  leftText:ClearAllPoints()
  leftText:SetPoint("TOPLEFT", bar.leftText, "TOPLEFT", -3, 3)
  leftText:SetPoint("BOTTOMRIGHT", bar.leftText, "BOTTOMRIGHT", 3, -3)

  local rightText = PRDPreview_CreateInteraction(
    frame,
    frame,
    frame:GetFrameLevel() + 51
  )
  rightText:ClearAllPoints()
  rightText:SetPoint("TOPLEFT", bar.rightText, "TOPLEFT", -3, 3)
  rightText:SetPoint("BOTTOMRIGHT", bar.rightText, "BOTTOMRIGHT", 3, -3)

  local centerText = PRDPreview_CreateInteraction(
    frame,
    frame,
    frame:GetFrameLevel() + 52
  )
  centerText:ClearAllPoints()
  centerText:SetPoint("TOPLEFT", bar.centerText, "TOPLEFT", -3, 3)
  centerText:SetPoint("BOTTOMRIGHT", bar.centerText, "BOTTOMRIGHT", 3, -3)

  return {
    body = body,
    leftText = leftText,
    rightText = rightText,
    centerText = centerText,
    borders = PRDPreview_CreateEdgeInteractions(bar),
  }
end

local function PRDPreview_OrderButtonOnClick(button)
  local targetKey = button.__puiPRDOrderTargetKey
  local box = button.__puiPRDOrderBox
  if not targetKey or not box then
    return
  end

  local PRD = ns.Modules.PRD
  PRD:SwapStackItems(button.__puiPRDOrderKey, targetKey)
end

local function PRDPreview_CreateOrderButton(bar, text, point, relativePoint, xOffset)
  local button = CreateFrame("Button", nil, bar.frame, "UIPanelButtonTemplate")
  button:SetSize(22, 22)
  button:SetPoint(point, bar.frame, relativePoint, xOffset, 0)
  button:SetFrameLevel(bar.frame:GetFrameLevel() + 80)
  button:SetText(text)
  Theme.WidgetSkins.UIButton(button)
  Theme.ApplyFont(button:GetFontString(), "button", 10, "OUTLINE")
  button:SetScript("OnClick", PRDPreview_OrderButtonOnClick)
  button:Hide()
  return button
end

local function PRDPreview_ConfigureOrderButtons(box, entries)
  local bars = box.__puiPRDPreviewBars

  for _, bar in pairs(bars) do
    bar.orderDown:Hide()
    bar.orderUp:Hide()
  end

  for index = 1, #entries do
    local entry = entries[index]
    local bar = entry.bar
    local previousEntry = entries[index - 1]
    local nextEntry = entries[index + 1]

    bar.orderDown.__puiPRDOrderBox = box
    bar.orderDown.__puiPRDOrderKey = entry.key
    bar.orderDown.__puiPRDOrderTargetKey = nextEntry and nextEntry.key or nil
    bar.orderDown:SetEnabled(nextEntry ~= nil)
    bar.orderDown:Show()

    bar.orderUp.__puiPRDOrderBox = box
    bar.orderUp.__puiPRDOrderKey = entry.key
    bar.orderUp.__puiPRDOrderTargetKey = previousEntry and previousEntry.key or nil
    bar.orderUp:SetEnabled(previousEntry ~= nil)
    bar.orderUp:Show()
  end
end

local function PRDPreview_SetTextInteractionVisibility(bar)
  local interactions = bar.interactions

  interactions.leftText:SetShown(
    bar.leftText:IsShown() and (bar.leftText:GetText() or "") ~= ""
  )
  interactions.rightText:SetShown(
    bar.rightText:IsShown() and (bar.rightText:GetText() or "") ~= ""
  )
  interactions.centerText:SetShown(
    bar.centerText:IsShown() and (bar.centerText:GetText() or "") ~= ""
  )
end

local function PRDPreview_GetResourceAppearanceTarget(profile, definition)
  if profile.appearance.unified ~= false then
    return { "PRD", "general" }, "appearanceGroup", "borderSize"
  end

  local resourceKey = definition and definition.resourceKey
  local settings = resourceKey
    and profile.secondary.resourceSettings
    and profile.secondary.resourceSettings[resourceKey]
  local usesResourceTabs = resourceKey ~= nil and PRD_UsesSecondaryResourceTabs()
  local resourcePath = usesResourceTabs
    and { "PRD", "secondary", resourceKey }
    or { "PRD", "secondary" }

  if settings and settings.useSharedAppearance == false then
    if usesResourceTabs then
      return resourcePath, "styleGroup", "borderSize"
    end

    return resourcePath, resourceKey, "styleGroup"
  end

  if usesResourceTabs then
    return resourcePath, "sharedSecondaryStyleGroup", "borderSize"
  end

  return resourcePath, "styleGroup", "borderSize"
end

local function PRDPreview_GetResourceTextTarget(profile, definition)
  if profile.appearance.unified ~= false then
    return { "PRD", "general" }, "appearanceGroup", "fontSize"
  end

  local resourceKey = definition and definition.resourceKey
  local settings = resourceKey
    and profile.secondary.resourceSettings
    and profile.secondary.resourceSettings[resourceKey]
  local usesResourceTabs = resourceKey ~= nil and PRD_UsesSecondaryResourceTabs()
  local resourcePath = usesResourceTabs
    and { "PRD", "secondary", resourceKey }
    or { "PRD", "secondary" }

  if settings and settings.useSharedAppearance == false then
    if usesResourceTabs then
      return resourcePath, "textGroup", "textMode"
    end

    return resourcePath, resourceKey, "textGroup"
  end

  if usesResourceTabs then
    return resourcePath, "sharedSecondaryTextGroup", "textMode"
  end

  return resourcePath, "textGroup", "textMode"
end

local function PRDPreview_ConfigureBarInteractions(
  box,
  bar,
  role,
  profile,
  definition,
  config
)
  local interactions = bar.interactions
  local title
  local bodyPath
  local bodySection
  local bodyOption
  local textPath
  local textSection
  local textOption
  local borderPath
  local borderSection
  local borderOption

  if role == "health" then
    title = "Health"
    bodyPath = { "PRD", "health" }
    bodySection = "layoutGroup"
    bodyOption = "texture"
    textPath = bodyPath
    textSection = "textGroup"
    textOption = "leftVisibility"

    if profile.appearance.unified ~= false then
      borderPath = { "PRD", "general" }
      borderSection = "appearanceGroup"
      borderOption = "borderSize"
    else
      borderPath = bodyPath
      borderSection = "styleGroup"
      borderOption = "borderSize"
    end
  elseif role == "primary" then
    title = "Primary power"
    bodyPath = { "PRD", "primary" }
    bodySection = "layoutGroup"
    bodyOption = "texture"
    textPath = bodyPath
    textSection = "textGroup"
    textOption = "leftVisibility"

    if profile.appearance.unified ~= false then
      borderPath = { "PRD", "general" }
      borderSection = "appearanceGroup"
      borderOption = "borderSize"
    else
      borderPath = bodyPath
      borderSection = "styleGroup"
      borderOption = "borderSize"
    end
  else
    title = config and config.resourceName
      or definition and definition.resourceKey
      or "Secondary resource"

    if definition and definition.isAlternatePower == true then
      bodyPath = { "PRD", "primary" }
      bodySection = "visibilityGroup"
      bodyOption = "hideAlternateMana"
    elseif definition and definition.resourceKey and PRD_UsesSecondaryResourceTabs() then
      bodyPath = { "PRD", "secondary", definition.resourceKey }
      bodySection = "layout"
      bodyOption = "detached"
    else
      bodyPath = { "PRD", "secondary" }
      bodySection = PRDPreview_GetResourceOptionCategory(
        definition and definition.resourceKey
      )
      bodyOption = definition and definition.resourceKey
    end

    textPath, textSection, textOption = PRDPreview_GetResourceTextTarget(
      profile,
      definition
    )
    borderPath, borderSection, borderOption = PRDPreview_GetResourceAppearanceTarget(
      profile,
      definition
    )
  end

  interactions.body:SetPreviewInteractionOptions({
    title = title,
    description = "Click to configure " .. title .. ".",
    onEnter = function()
      PRDPreview_SetBarHovered(bar, true)
    end,
    onLeave = function()
      PRDPreview_SetBarHovered(bar, false)
    end,
    onClick = function()
      PRDPreview_Navigate(
        box,
        bodyPath,
        bodySection,
        bodyOption
      )
    end,
  })

  local textOptions = {
    title = title .. " text",
    description = "Click to configure the text shown on " .. title .. ".",
    onEnter = function()
      PRDPreview_SetBarHovered(bar, true)
    end,
    onLeave = function()
      PRDPreview_SetBarHovered(bar, false)
    end,
    onClick = function()
      PRDPreview_Navigate(
        box,
        textPath,
        textSection,
        textOption
      )
    end,
  }

  interactions.leftText:SetPreviewInteractionOptions(textOptions)
  interactions.rightText:SetPreviewInteractionOptions(textOptions)
  interactions.centerText:SetPreviewInteractionOptions(textOptions)

  local borderOptions = {
    title = title .. " appearance",
    description = "Click to configure this element's border and background.",
    onClick = function()
      PRDPreview_Navigate(
        box,
        borderPath,
        borderSection,
        borderOption
      )
    end,
  }

  for index = 1, #interactions.borders do
    interactions.borders[index]:SetPreviewInteractionOptions(borderOptions)
  end
end

local function PRDPreview_CreateBorderTarget(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)
  frame:SetFrameLevel(parent:GetFrameLevel() + 30)
  frame:EnableMouse(false)

  return frame
end

local function PRDPreview_CreateBar(parent)
  local bar = Presentation.Create("PRDBar", parent)
  bar.cue = PRDPreview_CreateBorderTarget(bar.frame)
  bar.cue:Hide()
  bar.interactions = PRDPreview_CreateBarInteractions(bar)
  bar.orderDown = PRDPreview_CreateOrderButton(bar, "▼", "RIGHT", "LEFT", -6)
  bar.orderUp = PRDPreview_CreateOrderButton(bar, "▲", "LEFT", "RIGHT", 6)
  return bar
end

local function PRDPreview_EnsurePrimaryTick(bar, index)
  bar.__puiPrimaryTickTextures = bar.__puiPrimaryTickTextures or {}

  local tick = bar.__puiPrimaryTickTextures[index]
  if not tick then
    tick = bar.status:CreateTexture(nil, "ARTWORK", nil, 7)
    bar.__puiPrimaryTickTextures[index] = tick
  end

  return tick
end

local function PRDPreview_HidePrimaryTicks(bar, keepCount)
  local ticks = bar.__puiPrimaryTickTextures
  if not ticks then
    return
  end

  for index = keepCount + 1, #ticks do
    ticks[index]:Hide()
  end
end

local function PRDPreview_LayoutPrimaryTicks(bar, config, maximum)
  if not bar
    or not config
    or config.enabled ~= true
    or type(config.entries) ~= "table"
  then
    if bar then
      PRDPreview_HidePrimaryTicks(bar, 0)
    end
    return
  end

  if not maximum or maximum <= 0 or #config.entries == 0 then
    PRDPreview_HidePrimaryTicks(bar, 0)
    return
  end

  local width = bar.status:GetWidth()
  local autoHeight = math_max(1, bar.status:GetHeight())
  if width <= 0 then
    PRDPreview_HidePrimaryTicks(bar, 0)
    return
  end

  local shown = 0
  for index = 1, #config.entries do
    local entry = config.entries[index]
    local value = type(entry) == "table" and tonumber(entry.value) or nil

    if value and value >= 0 and value <= maximum then
      shown = shown + 1

      local tick = PRDPreview_EnsurePrimaryTick(bar, shown)
      local tickWidth = PRDPreview_Clamp(entry.width or 2, 1, 50)
      local configuredHeight = tonumber(entry.height) or 0
      local tickHeight = configuredHeight <= 0
        and autoHeight
        or PRDPreview_Clamp(configuredHeight, 1, 50)
      local color = entry.color or { 1, 1, 1, 1 }

      tick:ClearAllPoints()
      tick:SetSize(tickWidth, tickHeight)
      tick:SetPoint(
        "CENTER",
        bar.status,
        "LEFT",
        width * (value / maximum),
        0
      )
      tick:SetColorTexture(
        tonumber(color[1] or color.r) or 1,
        tonumber(color[2] or color.g) or 1,
        tonumber(color[3] or color.b) or 1,
        tonumber(color[4] or color.a) or 1
      )
      tick:Show()
    end
  end

  PRDPreview_HidePrimaryTicks(bar, shown)
end

local function PRDPreview_EnsureSegment(bar, index)
  local segment = bar.segments[index]
  if segment then
    return segment
  end

  local frame = CreateFrame("Frame", nil, bar.frame)
  frame:SetFrameLevel(bar.frame:GetFrameLevel() + 3)

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)

  local fill = CreateFrame("StatusBar", nil, frame)
  fill:SetAllPoints(frame)
  fill:SetMinMaxValues(0, 1)
  fill:SetValue(0)
  fill:SetFrameLevel(frame:GetFrameLevel() + 1)

  local text = frame:CreateFontString(nil, "OVERLAY")
  text:SetPoint("CENTER")
  text:SetJustifyH("CENTER")
  text:Hide()

  segment = {
    frame = frame,
    background = background,
    fill = fill,
    text = text,
  }

  bar.segments[index] = segment

  return segment
end

local function PRDPreview_HideSegments(bar, keepCount)
  for index = keepCount + 1, #bar.segments do
    bar.segments[index].frame:Hide()
  end
end

local function PRDPreview_EnsureDivider(bar, index)
  local divider = bar.dividers[index]
  if divider then
    return divider
  end

  divider = bar.frame:CreateTexture(nil, "OVERLAY", nil, 7)
  bar.dividers[index] = divider

  return divider
end

local function PRDPreview_HideDividers(bar, keepCount)
  for index = keepCount + 1, #bar.dividers do
    bar.dividers[index]:Hide()
  end
end

local function PRDPreview_ApplyBarStyle(
  bar,
  appearance,
  color,
  textConfig,
  iconSpellID,
  iconGap
)
  Presentation.Apply("PRDBar", bar, {
    appearance = appearance,
    color = color,
    textConfig = textConfig,
    iconSpellID = iconSpellID,
    iconGap = iconGap,
    width = bar.frame:GetWidth(),
    height = bar.frame:GetHeight(),
    visible = true,
  }, bar.__puiPRDPreviewProvider)
end

local function PRDPreview_LayoutDividers(bar, maximum, config)
  maximum = math_floor(tonumber(maximum) or 0)

  local show = config
    and config.showDividers ~= false
    and maximum > 1

  if not show then
    PRDPreview_HideDividers(bar, 0)
    return
  end

  local dividerSize = PRDPreview_Clamp(
    config.dividerSize or 1,
    1,
    6
  )
  local color = config.dividerColor or {
    0.20,
    0.20,
    0.24,
    1,
  }
  local width = bar.status:GetWidth()

  if width <= 0 then
    return
  end

  local count = maximum - 1

  for index = 1, count do
    local divider = PRDPreview_EnsureDivider(bar, index)
    local x = width * index / maximum - dividerSize * 0.5

    divider:ClearAllPoints()
    divider:SetPoint(
      "TOPLEFT",
      bar.status,
      "TOPLEFT",
      x,
      0
    )
    divider:SetPoint(
      "BOTTOMLEFT",
      bar.status,
      "BOTTOMLEFT",
      x,
      0
    )
    divider:SetWidth(dividerSize)
    divider:SetColorTexture(
      color[1] or 0.20,
      color[2] or 0.20,
      color[3] or 0.24,
      color[4] or 1
    )
    divider:Show()
  end

  PRDPreview_HideDividers(bar, count)
end

local function PRDPreview_LayoutSegments(
  bar,
  maximum,
  config,
  textureKey,
  color
)
  maximum = math_floor(tonumber(maximum) or 0)

  if maximum <= 0 then
    PRDPreview_HideSegments(bar, 0)
    return
  end

  local gap = maximum > 1 and PRD_PREVIEW_SEGMENT_GAP or 0
  local width = bar.status:GetWidth()
  local height = bar.status:GetHeight()

  if width <= 0 or height <= 0 then
    return
  end

  local segmentWidth = (
    width - gap * (maximum - 1)
  ) / maximum

  local inactiveAlpha = PRDPreview_Clamp(
    config.inactiveAlpha or 0.15,
    0,
    1
  )

  for index = 1, maximum do
    local segment = PRDPreview_EnsureSegment(bar, index)

    segment.frame:ClearAllPoints()
    segment.frame:SetPoint(
      "TOPLEFT",
      bar.status,
      "TOPLEFT",
      (index - 1) * (segmentWidth + gap),
      0
    )
    segment.frame:SetSize(segmentWidth, height)

    segment.background:SetTexture(
      PRDPreview_FetchStatusbar(textureKey)
    )
    segment.background:SetVertexColor(
      color[1],
      color[2],
      color[3],
      color[4]
    )
    segment.background:SetAlpha(inactiveAlpha)

    PRDPreview_SetTexture(segment.fill, textureKey)
    segment.fill:SetStatusBarColor(
      color[1],
      color[2],
      color[3],
      color[4]
    )

    segment.text:SetFont(
      STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
      math_max(7, math_min(11, height - 3)),
      "OUTLINE"
    )

    segment.frame:Show()
  end

  PRDPreview_HideSegments(bar, maximum)
  bar.status:SetAlpha(0)
end

local function PRDPreview_SetContinuousMode(bar)
  bar.status:SetAlpha(1)
  PRDPreview_HideSegments(bar, 0)
end

local function PRDPreview_FormatPercent(fraction)
  return tostring(
    math_floor(
      PRDPreview_Clamp(fraction, 0, 1) * 100 + 0.5
    )
  ) .. "%"
end

local function PRDPreview_FormatWhole(value)
  return tostring(
    math_floor((tonumber(value) or 0) + 0.5)
  )
end

local function PRDPreview_ShouldShowText(mode, hovered)
  if mode == "ALWAYS" then
    return true
  elseif mode == "MOUSEOVER" then
    return hovered == true
  end

  return false
end

local function PRDPreview_UpdateNativeText(
  bar,
  role,
  fraction,
  config
)
  config = config or {}

  local hovered = bar.frame.__puiPRDPreviewHovered == true
  local leftShown = PRDPreview_ShouldShowText(
    config.leftVisibility,
    hovered
  )
  local rightShown = PRDPreview_ShouldShowText(
    config.rightVisibility,
    hovered
  )

  local current = role == "health"
    and math_floor(785000 * fraction + 0.5)
    or math_floor(100 * fraction + 0.5)

  local leftValue = PRDPreview_FormatPercent(fraction)
  local rightValue

  if role == "health" then
    rightValue = AbbreviateLargeNumbers(current)
  else
    rightValue = PRDPreview_FormatWhole(current)
  end

  bar.leftText:SetText(leftValue)
  bar.rightText:SetText(rightValue)
  bar.centerText:SetText("")

  if config.centerText ~= false
    and leftShown ~= rightShown
  then
    bar.centerText:SetText(
      leftShown and leftValue or rightValue
    )
    bar.centerText:Show()
    bar.leftText:Hide()
    bar.rightText:Hide()
  else
    bar.centerText:Hide()
    bar.leftText:SetShown(leftShown)
    bar.rightText:SetShown(rightShown)
  end

  PRDPreview_SetTextInteractionVisibility(bar)
end

local function PRDPreview_UpdateSecondaryText(
  bar,
  current,
  maximum,
  config
)
  local text = config and config.text or {}
  local mode = text.mode or "CUR"
  local show = text.showNumber ~= false and mode ~= "HIDE"
  local value = ""
  local percentage = maximum > 0
    and current / maximum
    or 0

  if ns.PRDSecondary.ShouldShowApplicationCountdown(config) then
    local applications = math_floor((tonumber(current) or 0) + 0.5)
    local remaining

    if bar.__puiApplicationCountdownReady == true then
      remaining = 0
    else
      remaining = math_max(
        0,
        (tonumber(config.applicationCountdownMax) or 0) - applications
      )
    end

    value = ns.PRDSecondary.FormatApplicationCountdown(config, remaining)
  elseif mode == "BOTH" then
    value =
      PRDPreview_FormatWhole(current)
      .. " / "
      .. PRDPreview_FormatWhole(maximum)
  elseif mode == "CURP" then
    value =
      PRDPreview_FormatWhole(current)
      .. " / "
      .. PRDPreview_FormatPercent(percentage)
  elseif mode == "PCT" then
    value = PRDPreview_FormatPercent(percentage)
  else
    value = PRDPreview_FormatWhole(current)
  end

  bar.leftText:Hide()
  bar.rightText:Hide()
  bar.centerText:SetText(value)
  bar.centerText:SetShown(show)
  PRDPreview_SetTextInteractionVisibility(bar)
end

local function PRDPreview_ThresholdMatches(
  mode,
  value,
  threshold
)
  threshold = tonumber(threshold) or 0

  if mode == "BELOW" then
    return value < threshold
  elseif mode == "AT_OR_ABOVE" then
    return value >= threshold
  end

  return false
end

local function PRDPreview_UpdateCue(
  bar,
  current,
  config,
  now
)
  local cues = config and config.cues

  if not cues or config.supportsNumericCues ~= true then
    bar.cue:Hide()
    return false
  end

  local desaturate = PRDPreview_ThresholdMatches(
    cues.desaturateMode,
    current,
    cues.desaturateThreshold
  )

  local glow = PRDPreview_ThresholdMatches(
    cues.glowMode,
    current,
    cues.glowThreshold
  )

  if glow then
    local PRD = ns.Modules.PRD
    local color = cues.glowColor or {
      1,
      0.82,
      0,
      1,
    }

    PRD:ApplyBarBorder(bar.cue, 2, color)

    bar.cue:SetAlpha(
      0.55 + 0.45 * math_abs(math_sin(now * 4))
    )
    bar.cue:Show()
  else
    bar.cue:Hide()
  end

  return desaturate
end

local function PRDPreview_ApplySegmentValues(
  bar,
  values,
  maximum,
  config,
  color,
  now
)
  local current = 0

  for index = 1, maximum do
    local segment = bar.segments[index]
    local value = PRDPreview_Clamp(
      values[index] or 0,
      0,
      1
    )

    current = current + value

    segment.fill:SetMinMaxValues(0, 1)
    segment.fill:SetValue(value)
    segment.fill:SetAlpha(1)
    segment.frame:SetAlpha(
      value > 0
        and 1
        or PRDPreview_Clamp(
          config.inactiveAlpha or 0.15,
          0,
          1
        )
    )

    if config.behavior
      and config.behavior.showRechargeTime ~= false
      and value > 0
      and value < 1
    then
      segment.text:SetText(
        tostring(
          math_max(
            1,
            math_floor((1 - value) * 4 + 0.5)
          )
        )
      )
      segment.text:Show()
    else
      segment.text:SetText("")
      segment.text:Hide()
    end
  end

  local desaturate = PRDPreview_UpdateCue(
    bar,
    current,
    config,
    now
  )

  if desaturate then
    for index = 1, maximum do
      bar.segments[index].fill:SetStatusBarColor(
        color[1] * 0.35,
        color[2] * 0.35,
        color[3] * 0.35,
        color[4]
      )
    end
  else
    for index = 1, maximum do
      bar.segments[index].fill:SetStatusBarColor(
        color[1],
        color[2],
        color[3],
        color[4]
      )
    end
  end

  return current
end

local function PRDPreview_BuildRuneValues(
  now,
  maximum,
  values
)
  local cycle = now % 10

  for index = 1, maximum do
    local spendAt = 1 + (index - 1) * 0.45
    local rechargeStart = spendAt + 0.35
    local value

    if index > 4 then
      value = 1
    elseif cycle < spendAt then
      value = 1
    elseif cycle < rechargeStart then
      value = 0
    else
      value = PRDPreview_Clamp(
        (cycle - rechargeStart) / 3.2,
        0,
        1
      )
    end

    values[index] = value
  end
end

local function PRDPreview_BuildEssenceValues(
  now,
  maximum,
  values
)
  local cycle = now % 9
  local spent = cycle < 1.2
    and 0
    or cycle < 2.0
      and 1
      or 2

  local rechargeElapsed = math_max(0, cycle - 2.0)

  for index = 1, maximum do
    values[index] = 1
  end

  for index = maximum - spent + 1, maximum do
    if index >= 1 then
      values[index] = 0
    end
  end

  if spent > 0 then
    local firstSpent = maximum - spent + 1
    local rechargeUnits = rechargeElapsed / 2.8

    for offset = 0, spent - 1 do
      local index = firstSpent + offset

      values[index] = PRDPreview_Clamp(
        rechargeUnits - offset,
        0,
        1
      )
    end
  end
end

local function PRDPreview_Triangle(now, period)
  local phase = (now % period) / period

  if phase < 0.5 then
    return phase * 2
  end

  return (1 - phase) * 2
end

local function PRDPreview_UpdateSecondaryBar(
  bar,
  definition,
  maximum,
  config,
  now
)
  if not definition or not config or maximum <= 0 then
    return
  end

  local adapter = definition.adapter
  local color = {
    PRDPreview_ResolveResourceColor(
      config,
      definition
    ),
  }
  local values = bar.__puiPreviewValues or {}

  bar.__puiPreviewValues = values
  bar.__puiApplicationCountdownReady = nil

  local current

  if adapter == "RUNES" then
    PRDPreview_BuildRuneValues(
      now,
      maximum,
      values
    )

    current = PRDPreview_ApplySegmentValues(
      bar,
      values,
      maximum,
      config,
      color,
      now
    )
  elseif adapter == "ESSENCE" then
    PRDPreview_BuildEssenceValues(
      now,
      maximum,
      values
    )

    current = PRDPreview_ApplySegmentValues(
      bar,
      values,
      maximum,
      config,
      color,
      now
    )
  elseif config.perSegment == true
    and definition.forceContinuous ~= true
    and adapter ~= "AURA_STACKS"
  then
    local fraction = PRDPreview_Triangle(now, 7)
    local exact = fraction * maximum

    for index = 1, maximum do
      values[index] = PRDPreview_Clamp(
        exact - (index - 1),
        0,
        1
      )
    end

    current = PRDPreview_ApplySegmentValues(
      bar,
      values,
      maximum,
      config,
      color,
      now
    )
  else
    if adapter == "AURA_STACKS" then
      local cycle = now % 9
      local countdownReady = ns.PRDSecondary.ShouldShowApplicationCountdown(config)
        and cycle < 1

      bar.__puiApplicationCountdownReady = countdownReady

      if cycle < 1 then
        current = countdownReady and 0 or maximum
      else
        local fraction = 1 - PRDPreview_Clamp(
          (cycle - 1) / 7,
          0,
          1
        )

        current = math_floor(fraction * maximum + 0.5)
      end
    else
      local fraction

      if adapter == "STAGGER" then
        fraction =
          0.15
          + PRDPreview_Triangle(now, 8) * 0.75
      else
        fraction = PRDPreview_Triangle(now, 7)
      end

      current = fraction * maximum
    end

    local desaturate = PRDPreview_UpdateCue(
      bar,
      current,
      config,
      now
    )
    local r, g, b, a =
      color[1],
      color[2],
      color[3],
      color[4]

    if desaturate then
      r = r * 0.35
      g = g * 0.35
      b = b * 0.35
    end

    bar.status:SetStatusBarColor(r, g, b, a)
    bar.status:SetMinMaxValues(0, maximum)
    bar.status:SetValue(current)

    if adapter == "AURA_STACKS" and bar.__puiStackColorParts then
      AuraWidget.FeedApplicationThresholds(
        bar.__puiStackColorParts,
        current
      )
    end
  end

  PRDPreview_UpdateSecondaryText(
    bar,
    current,
    maximum,
    config
  )
end

local function PRDPreview_ConfigureSecondaryMode(
  bar,
  definition,
  maximum,
  config
)
  local adapter = definition and definition.adapter
  local color = {
    PRDPreview_ResolveResourceColor(
      config,
      definition
    ),
  }

  local segmented =
    adapter == "RUNES"
    or adapter == "ESSENCE"
    or (
      config.perSegment == true
      and definition.forceContinuous ~= true
      and adapter ~= "AURA_STACKS"
    )

  if segmented then
    PRDPreview_LayoutSegments(
      bar,
      maximum,
      config,
      config.texture,
      color
    )
    PRDPreview_HideDividers(bar, 0)

    if bar.__puiStackColorParts then
      PRDPreview_ConfigureStackColorSegments(bar, maximum, nil)
    end
  else
    PRDPreview_SetContinuousMode(bar)
    PRDPreview_LayoutDividers(
      bar,
      maximum,
      config
    )

    if adapter == "AURA_STACKS" then
      PRDPreview_ConfigureStackColorSegments(bar, maximum, config)
    elseif bar.__puiStackColorParts then
      PRDPreview_ConfigureStackColorSegments(bar, maximum, nil)
    end
  end
end

local function PRDPreview_GetEffectivePrimaryColorConfig(
  profile
)
  local primary = profile.primary
  local config = {
    colorMode = primary.colorMode or "DEFAULT",
    customColor = primary.customColor,
  }

  local PRD = ns.Modules.PRD
  local formKey = PRD:GetDruidFormKey()
  local forms = profile.class
    and profile.class.DRUID
    and profile.class.DRUID.forms

  local formPrimary = formKey
    and forms
    and forms[formKey]
    and forms[formKey].primary

  if formPrimary
    and formPrimary.colorMode ~= nil
  then
    config.colorMode = formPrimary.colorMode

    if type(formPrimary.customColor) == "table" then
      config.customColor = formPrimary.customColor
    end
  end

  return config
end

local function PRDPreview_GetNativeAppearance(
  profile,
  role
)
  if profile.appearance.unified ~= false then
    return profile.appearance
  end

  return profile[role]
end

local function PRDPreview_GetNativeText(
  profile,
  role,
  appearance
)
  if role == "primary" then
    local settings = ns.Modules.PRD:GetPrimaryResourceSettings()
    local text = settings and settings.text or {}
    return text, text
  end

  local text = profile.text
    and profile.text[role]
    or {}

  local fallback = appearance
    and appearance.text
    or profile.appearance.text

  return text, fallback or {}
end

local function PRDPreview_ConfigureBar(
  box,
  key,
  width,
  height,
  appearance,
  color,
  textConfig,
  iconSpellID,
  iconGap
)
  local bar = box.__puiPRDPreviewBars[key]
  if not bar then
    bar = PRDPreview_CreateBar(box.__puiPRDPreviewAttachedRoot)
    box.__puiPRDPreviewBars[key] = bar
  end

  bar.frame:SetSize(width, height)

  PRDPreview_ApplyBarStyle(
    bar,
    appearance,
    color,
    textConfig,
    iconSpellID,
    iconGap
  )

  bar.frame:Show()

  return bar
end

local function PRDPreview_HideAllBars(box)
  for _, bar in pairs(box.__puiPRDPreviewBars) do
    bar.frame:Hide()
    bar.cue:Hide()
  end
end

local function PRDPreview_RefreshLayout(box)
  box.__puiPRDPreviewDirty = nil
  local PRD = ns.Modules.PRD

  if not PRD or not PRD.db or not PRD.db.profile then
    return
  end

  local profile = PRD.db.profile
  PRD:GetSecondaryDefinition()
  local resources = PRD.secondaryResources or {}
  local resourceByKey = PRD.secondaryResourceByKey or {}
  local stackWidth = PRDPreview_Clamp(profile.size.width or 240, 120, 600)
  local stackGap = PRDPreview_Clamp(profile.size.gap or 0, 0, 20)
  local secondaryGap = PRDPreview_Clamp(profile.secondary.gap or 2, 0, 20)

  local healthAppearance = PRDPreview_GetNativeAppearance(profile, "health")
  local primaryAppearance = PRDPreview_GetNativeAppearance(profile, "primary")
  local healthText, healthFont = PRDPreview_GetNativeText(profile, "health", healthAppearance)
  local primaryText, primaryFont = PRDPreview_GetNativeText(profile, "primary", primaryAppearance)
  local healthHeight = PRDPreview_Clamp(healthAppearance.height or 15, 6, 40)
  local primaryHeight = PRDPreview_Clamp(primaryAppearance.height or 15, 6, 40)
  local healthWidth = profile.detachHealth == true
    and PRDPreview_Clamp(profile.health.width or stackWidth, 120, 600)
    or stackWidth
  local primaryWidth = profile.primary.detached == true
    and PRDPreview_Clamp(profile.primary.width or stackWidth, 120, 600)
    or stackWidth
  local healthColor = {
    PRDPreview_ResolveNativeColor("health", profile.health),
  }
  local primaryColorConfig = PRDPreview_GetEffectivePrimaryColorConfig(profile)
  local primaryColor = {
    PRDPreview_ResolveNativeColor("primary", primaryColorConfig),
  }

  PRDPreview_HideAllBars(box)
  box.__puiPRDPreviewActiveResources = {}

  local healthBar
  if profile.hideHealth ~= true then
    healthBar = PRDPreview_ConfigureBar(
      box,
      "health",
      healthWidth,
      healthHeight,
      healthAppearance,
      healthColor,
      healthFont
    )
    healthBar.__puiPreviewTextConfig = healthText
    PRDPreview_ConfigureBarInteractions(box, healthBar, "health", profile)
  end

  local primaryBar
  if profile.hidePrimary ~= true then
    primaryBar = PRDPreview_ConfigureBar(
      box,
      "primary",
      primaryWidth,
      primaryHeight,
      primaryAppearance,
      primaryColor,
      primaryFont
    )
    primaryBar.__puiPreviewTextConfig = primaryText
    PRDPreview_ConfigureBarInteractions(box, primaryBar, "primary", profile)
    local primarySettings = PRD:GetPrimaryResourceSettings()
    local primaryTicks = primarySettings and primarySettings.ticks
    PRDPreview_LayoutPrimaryTicks(
      primaryBar,
      primaryTicks,
      PRD:GetPrimaryTickMaximum(primaryTicks)
    )
  end

  for index = 1, #resources do
    local resource = resources[index]
    local definition = resource.definition
    local config = resource.config
    local maximum = math_floor(tonumber(resource.maximum) or 0)
    local visible = config ~= nil
      and maximum > 0
      and (
        definition.isAlternatePower == true
        or profile.secondary.enabled ~= false
      )

    if visible then
      local width = config.detached == true
        and PRDPreview_Clamp(config.width or stackWidth, 120, 600)
        or stackWidth
      local height = PRDPreview_Clamp(config.height or 15, 6, 40)
      local color = {
        PRDPreview_ResolveResourceColor(config, definition),
      }
      local iconSpellID = config.showSpellIcon and config.iconSpellID or nil
      local resourceKey = definition.resourceKey
      local bar = PRDPreview_ConfigureBar(
        box,
        resourceKey,
        width,
        height,
        config,
        color,
        config.font,
        iconSpellID,
        config.iconGap
      )

      bar.__puiPreviewDefinition = definition
      bar.__puiPreviewMaximum = maximum
      bar.__puiPreviewConfig = config
      PRDPreview_ConfigureBarInteractions(
        box,
        bar,
        "secondary",
        profile,
        definition,
        config
      )

      box.__puiPRDPreviewActiveResources[#box.__puiPRDPreviewActiveResources + 1] = {
        key = resourceKey,
        bar = bar,
        resource = resource,
      }
    end
  end

  local attached = {}
  local detached = {}
  local order = PRD:GetStackOrder()

  local function AddBar(list, bar, key, gapBefore)
    if not bar then
      return
    end

    list[#list + 1] = {
      bar = bar,
      key = key,
      gapBefore = gapBefore or 0,
    }
  end

  local lastAttachedWasResource = false

  for _, key in ipairs(order) do
    if key == "health" and healthBar then
      local list = profile.detachHealth == true and detached or attached
      AddBar(list, healthBar, key, stackGap)
      if list == attached then
        lastAttachedWasResource = false
      end
    elseif key == "primary" and primaryBar then
      local list = profile.primary.detached == true and detached or attached
      AddBar(list, primaryBar, key, stackGap)
      if list == attached then
        lastAttachedWasResource = false
      end
    else
      local resource = resourceByKey[key]
      local bar = resource and box.__puiPRDPreviewBars[key]
      if resource and bar and bar.frame:IsShown() then
        local list = resource.config.detached == true and detached or attached
        AddBar(
          list,
          bar,
          key,
          list == attached and lastAttachedWasResource and secondaryGap or stackGap
        )
        if list == attached then
          lastAttachedWasResource = true
        end
      end
    end
  end

  PRDPreview_ConfigureOrderButtons(box, attached)

  local attachedHeight = 0
  for index, entry in ipairs(attached) do
    if index > 1 then
      attachedHeight = attachedHeight + entry.gapBefore
    end
    attachedHeight = attachedHeight + entry.bar.frame:GetHeight()
  end

  local maxWidth = stackWidth
  local totalHeight = attachedHeight
  local cursorY = 0
  local attachedRoot = box.__puiPRDPreviewAttachedRoot

  if #attached > 0 then
    attachedRoot:SetSize(stackWidth, math_max(1, attachedHeight))
    attachedRoot:Show()

    for index, entry in ipairs(attached) do
      if index > 1 then
        cursorY = cursorY + entry.gapBefore
      end

      local frame = entry.bar.frame
      frame:SetParent(attachedRoot)
      frame:ClearAllPoints()
      frame:SetPoint("TOP", attachedRoot, "TOP", 0, -cursorY)
      frame:SetWidth(stackWidth)
      cursorY = cursorY + frame:GetHeight()
    end
  else
    attachedRoot:Hide()
  end

  local outerBorder = profile.outerBorder or {}
  local showOuterBorderInteraction = #attached > 0 and outerBorder.enabled == true

  if showOuterBorderInteraction then
    PRD:ApplyBarBorder(
      attachedRoot,
      PRD:GetBarBorderThickness({ borderSize = outerBorder.size }, attachedRoot),
      outerBorder.color
    )
  else
    PRD:ApplyBarBorder(attachedRoot, 0)
  end

  for index = 1, #(box.__puiPRDPreviewOuterBorderInteractions or {}) do
    box.__puiPRDPreviewOuterBorderInteractions[index]:SetShown(showOuterBorderInteraction)
  end

  local layout = box.__puiPRDPreviewLayout
  attachedRoot:ClearAllPoints()
  attachedRoot:SetPoint("TOP", layout, "TOP", 0, 0)
  cursorY = attachedHeight

  for _, entry in ipairs(detached) do
    local frame = entry.bar.frame
    cursorY = cursorY + PRD_PREVIEW_DETACHED_GAP
    frame:SetParent(layout)
    frame:ClearAllPoints()
    frame:SetPoint("TOP", layout, "TOP", 0, -cursorY)
    cursorY = cursorY + frame:GetHeight()
    maxWidth = math_max(maxWidth, frame:GetWidth())
  end

  totalHeight = cursorY
  if totalHeight <= 0 then
    totalHeight = 1
  end

  layout:SetSize(maxWidth, totalHeight)
  layout:ClearAllPoints()
  layout:SetPoint("CENTER", box:GetCanvas(), "CENTER", 0, 12)

  local previewZoom = PRDPreview_Clamp(box.__puiPRDPreviewZoom or 1, 0.25, 2)
  layout:SetScale(previewZoom)

  local resourceLabels = {}
  for index = 1, #(box.__puiPRDPreviewActiveResources or {}) do
    local entry = box.__puiPRDPreviewActiveResources[index]
    local resource = entry.resource
    PRDPreview_ConfigureSecondaryMode(
      entry.bar,
      resource.definition,
      resource.maximum,
      resource.config
    )
    resourceLabels[#resourceLabels + 1] = resource.config.resourceName
      or resource.definition.resourceKey
  end

  box.__puiPRDPreviewResourceLabel:SetText(
    #resourceLabels > 0
      and table.concat(resourceLabels, " + ")
      or "No secondary resource for the current specialization"
  )
  box.__puiPRDPreviewResourceLabel:SetShown(#resourceLabels > 0)
  box.__puiPRDPreviewConfigured = true
end

local function PRDPreview_UpdateAnimation(
  box,
  elapsed
)
  if not box.__puiPRDPreviewConfigured then
    return
  end

  local now =
    (box.__puiPRDPreviewTime or 0)
    + elapsed

  box.__puiPRDPreviewTime = now

  local healthBar =
    box.__puiPRDPreviewBars.health

  if healthBar.frame:IsShown() then
    local healthFraction =
      0.35
      + PRDPreview_Triangle(now, 8) * 0.60

    healthBar.status:SetMinMaxValues(0, 1)
    healthBar.status:SetValue(healthFraction)

    PRDPreview_UpdateNativeText(
      healthBar,
      "health",
      healthFraction,
      healthBar.__puiPreviewTextConfig
    )
  end

  local primaryBar =
    box.__puiPRDPreviewBars.primary

  if primaryBar.frame:IsShown() then
    local primaryFraction =
      PRDPreview_Triangle(now + 1.5, 6)

    primaryBar.status:SetMinMaxValues(0, 1)
    primaryBar.status:SetValue(primaryFraction)

    PRDPreview_UpdateNativeText(
      primaryBar,
      "primary",
      primaryFraction,
      primaryBar.__puiPreviewTextConfig
    )
  end

  local activeResources = box.__puiPRDPreviewActiveResources or {}
  for index = 1, #activeResources do
    local entry = activeResources[index]
    local resourceBar = entry.bar

    if resourceBar.frame:IsShown() then
      PRDPreview_UpdateSecondaryBar(
        resourceBar,
        resourceBar.__puiPreviewDefinition,
        resourceBar.__puiPreviewMaximum,
        resourceBar.__puiPreviewConfig,
        now + ((index - 1) * 2.25)
      )
    end
  end
end

local function PRDPreview_EnsureContents(box)
  if box.__puiPRDPreviewLayout then
    return
  end

  local canvas = box:GetCanvas()

  local layout = CreateFrame(
    "Frame",
    nil,
    canvas
  )
  layout:SetFrameLevel(
    canvas:GetFrameLevel() + 2
  )
  box.__puiPRDPreviewLayout = layout

  local attachedRoot = CreateFrame(
    "Frame",
    nil,
    layout
  )
  attachedRoot:SetFrameLevel(
    layout:GetFrameLevel() + 1
  )
  box.__puiPRDPreviewAttachedRoot =
    attachedRoot

  local outerBorderInteractions = PRDPreview_CreateEdgeInteractions({
    frame = attachedRoot,
  })
  local outerBorderOptions = {
    title = "PRD box border",
    description = "Click to configure the border around the attached PRD stack.",
    onClick = function()
      PRDPreview_Navigate(
        box,
        { "PRD", "general" },
        "outerBorderGroup",
        "size"
      )
    end,
  }

  for index = 1, #outerBorderInteractions do
    outerBorderInteractions[index]:SetFrameLevel(
      attachedRoot:GetFrameLevel() + 90 + index
    )
    outerBorderInteractions[index]:SetPreviewInteractionOptions(
      outerBorderOptions
    )
    outerBorderInteractions[index]:Hide()
  end

  box.__puiPRDPreviewOuterBorderInteractions =
    outerBorderInteractions

  box.__puiPRDPreviewBars = {
    health = PRDPreview_CreateBar(attachedRoot),
    primary = PRDPreview_CreateBar(attachedRoot),
  }
  box.__puiPRDPreviewActiveResources = {}

  local resourceLabel =
    canvas:CreateFontString(nil, "OVERLAY")

  resourceLabel:SetPoint(
    "BOTTOMLEFT",
    canvas,
    "BOTTOMLEFT",
    8,
    30
  )
  resourceLabel:SetPoint(
    "BOTTOMRIGHT",
    canvas,
    "BOTTOMRIGHT",
    -8,
    30
  )
  resourceLabel:SetJustifyH("CENTER")
  resourceLabel:SetWordWrap(false)

  ns.Theme.ApplyFont(
    resourceLabel,
    "tiny",
    9
  )

  box.__puiPRDPreviewResourceLabel =
    resourceLabel

  local zoomControl = ns.PreviewBox.CreateZoomControl(canvas, {
    sliderWidth = 110,
    sliderHeight = 14,
    frameLevel = canvas:GetFrameLevel() + 100,
    onValueChanged = function(_, zoom)
      box.__puiPRDPreviewZoom = zoom
      box.__puiPRDPreviewState.zoom = zoom
      PRDPreview_RefreshLayout(box)
    end,
  })
  zoomControl:SetPoint("BOTTOM", canvas, "BOTTOM", 0, 8)
  box.__puiPRDPreviewZoomControl = zoomControl

  local driver = CreateFrame(
    "Frame",
    nil,
    box
  )

  driver:SetScript("OnUpdate", function(_, elapsed)
    if box.__puiPRDPreviewDirty == true then
      PRDPreview_RefreshLayout(box)
    end

    PRDPreview_UpdateAnimation(box, elapsed)
  end)

  driver:SetScript("OnEvent", function(_, event, unit)
    if unit == nil or unit == "player" then
      ns.Modules.PRD:RefreshPrimaryResourceMaximum()
      box.__puiPRDPreviewDirty = true
    end
  end)

  local function RegisterPreviewEvents()
    driver:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    driver:RegisterEvent("PLAYER_TALENT_UPDATE")
    driver:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    driver:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    driver:RegisterUnitEvent("UNIT_MAXPOWER", "player")
  end

  box:HookScript("OnShow", RegisterPreviewEvents)
  box:HookScript("OnHide", function()
    driver:UnregisterAllEvents()
  end)

  if box:IsShown() then
    RegisterPreviewEvents()
  end

  box.__puiPRDPreviewDriver = driver

  canvas:HookScript("OnSizeChanged", function()
    box.__puiPRDPreviewDirty = true
  end)
end

function PRDPreview.Build(
  addon,
  optionsFrame,
  shell
)
  local previewHost = shell.previewHost
  local box = shell.__puiPRDPreviewBox

  if box then
    if box:GetParent() ~= previewHost then
      box:SetParent(previewHost)
    end
  else
    box = ns.PreviewBox.Create(previewHost)
    shell.__puiPRDPreviewBox = box
  end

  PRDPreview.box = box

  local boxLevel = previewHost:GetFrameLevel() + 1
  local canvas = box:GetCanvas()

  box:SetFrameStrata(previewHost:GetFrameStrata())
  box:SetFrameLevel(boxLevel)

  if box._puiBg then
    box._puiBg:SetFrameStrata(box:GetFrameStrata())
    box._puiBg:SetFrameLevel(math_max(0, boxLevel - 1))
  end

  box:ClearAllPoints()
  box:SetAllPoints(previewHost)
  box:SetTitle(
    "Personal Resource Display preview"
  )
  box:SetDescription(
    "Mirrors the current PRD settings. Use the arrows beside stacked bars to change their order, or click a bar, text value, or border to open its settings."
  )

  canvas:SetFrameStrata(box:GetFrameStrata())
  canvas:SetFrameLevel(boxLevel + 1)

  if canvas._puiBg then
    canvas._puiBg:SetFrameStrata(canvas:GetFrameStrata())
    canvas._puiBg:SetFrameLevel(boxLevel)
  end

  canvas:SetClipsChildren(true)
  box:Show()

  PRDPreview_EnsureContents(box)

  local previewState = shell:GetPreviewState()
  local previewZoom = PRDPreview_Clamp(previewState.zoom or 1, 0.25, 2)

  box.__puiPRDPreviewAddon = addon
  box.__puiPRDPreviewState = previewState
  box.__puiPRDPreviewZoom = previewZoom
  box.__puiPRDPreviewZoomControl:SetZoom(previewZoom)
  box.__puiPRDPreviewTime = 0
  box.__puiPRDPreviewDirty = true

  PRDPreview_RefreshLayout(box)
  PRDPreview_UpdateAnimation(box, 0)

  return true
end

local function Clamp(v, min, max)
  if v == nil then
    return min
  end
  v = tonumber(v)
  if not v then
    return min
  end
  if v < min then
    v = min
  end
  if v > max then
    v = max
  end
  return v
end



local function PRD_UseGlobalFont(text)
  text = text or {}
  if text.useGlobalFont ~= nil then
    return text.useGlobalFont == true
  end

  local standardKey = ns.FontDropdown.STANDARD_FONT_KEY
  return not (type(text.font) == "string" and text.font ~= "" and text.font ~= standardKey)
end



do
  local RESOURCE_COLOR_VALUES = {
    DEFAULT = "Resource color (Default)",
    CLASS = "Class color",
    CUSTOM = "Custom color",
    TEXTURE = "Texture color",
  }

  local STACK_THRESHOLD_COLOR_VALUES = {
    CLASS = "Class color",
    CUSTOM = "Custom color",
  }

  local function PRD_GetResourceColorMode(config)
    if config.useCustomColor == true then
      return "CUSTOM"
    elseif config.useClassColor == true then
      return "CLASS"
    elseif config.useBlizzardPowerColor ~= false then
      return "DEFAULT"
    end
    return "TEXTURE"
  end

  local function PRD_SetResourceColorMode(config, mode)
    config.useCustomColor = mode == "CUSTOM"
    config.useClassColor = mode == "CLASS"
    config.useBlizzardPowerColor = mode == "DEFAULT"
  end



  local function PRD_NormalizeBarColorConfig(cfg, role)
    if type(cfg) ~= "table" then
      return
    end

    if cfg.colorMode == nil then
      if cfg.useCustomColor == true then
        cfg.colorMode = "CUSTOM"
      elseif cfg.useClassColor == true then
        cfg.colorMode = "CLASS"
      elseif cfg.useBlizzardHealthColor == false or cfg.useBlizzardPowerColor == false then
        cfg.colorMode = "TEXTURE"
      else
        cfg.colorMode = "DEFAULT"
      end
    end

    if cfg.colorMode ~= "DEFAULT" and cfg.colorMode ~= "CLASS" and cfg.colorMode ~= "CUSTOM" and cfg.colorMode ~= "TEXTURE" then
      cfg.colorMode = "DEFAULT"
    end

    cfg.useCustomColor = cfg.colorMode == "CUSTOM"
    cfg.useClassColor = cfg.colorMode == "CLASS"

    if role == "health" then
      cfg.useBlizzardHealthColor = cfg.colorMode == "DEFAULT"
    elseif role == "primary" then
      cfg.useBlizzardPowerColor = cfg.colorMode == "DEFAULT"
    end
  end

  local function PRD_BuildNativeBarColorGroup(cfg, role)
    PRD_NormalizeBarColorConfig(cfg, role)

    local flags = role == "health" and { health = true } or { primary = true }
    local defaultLabel = role == "health" and "Health (Default)" or "Primary resource (Default)"

    return {
      type = "group",
      name = "Bar color",
      order = 30,
      inline = true,
      args = {
        colorMode = {
          type = "select",
          name = "Status bar color",
          order = 1,
          values = {
            DEFAULT = defaultLabel,
            CLASS = "Class color",
            CUSTOM = "Custom color",
            TEXTURE = "Texture color",
          },
          get = function()
            PRD_NormalizeBarColorConfig(cfg, role)
            return cfg.colorMode or "DEFAULT"
          end,
          set = function(_, value)
            cfg.colorMode = value or "DEFAULT"
            PRD_NormalizeBarColorConfig(cfg, role)
            Addon:ApplyOptionsChange("PRD", flags)
          end,
        },
        customColor = {
          type = "color",
          name = "Custom color",
          order = 2,
          hasAlpha = true,
          disabled = function()
            PRD_NormalizeBarColorConfig(cfg, role)
            return cfg.colorMode ~= "CUSTOM"
          end,
          get = function()
            local c = cfg.customColor or { 1, 1, 1, 1 }
            return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
          end,
          set = function(_, r, g, b, a)
            cfg.customColor = { r, g, b, a }
            cfg.colorMode = "CUSTOM"
            PRD_NormalizeBarColorConfig(cfg, role)
            Addon:ApplyOptionsChange("PRD", flags)
          end,
        },
      },
    }
  end

  local function PRD_NormalizeNativeTextConfig(text, defaultMode)
    if type(text) ~= "table" then
      return
    end

    text.left = text.left or {}
    text.right = text.right or {}

    if text.leftVisibility == nil then
      if text.showLeft ~= nil then
        text.leftVisibility = text.showLeft and "ALWAYS" or "HIDE"
      elseif defaultMode == "PCT" then
        text.leftVisibility = "ALWAYS"
      elseif defaultMode == "BOTH" or defaultMode == "CURP" then
        text.leftVisibility = "ALWAYS"
      else
        text.leftVisibility = "HIDE"
      end
    end

    if text.rightVisibility == nil then
      if text.showRight ~= nil then
        text.rightVisibility = text.showRight and "ALWAYS" or "HIDE"
      elseif defaultMode == "PCT" then
        text.rightVisibility = "HIDE"
      else
        text.rightVisibility = "ALWAYS"
      end
    end

    if text.leftVisibility ~= "ALWAYS" and text.leftVisibility ~= "MOUSEOVER" and text.leftVisibility ~= "HIDE" then
      text.leftVisibility = defaultMode == "PCT" and "ALWAYS" or "HIDE"
    end

    if text.rightVisibility ~= "ALWAYS" and text.rightVisibility ~= "MOUSEOVER" and text.rightVisibility ~= "HIDE" then
      text.rightVisibility = defaultMode == "PCT" and "HIDE" or "ALWAYS"
    end

    text.showLeft = nil
    text.showRight = nil

    if text.centerText == nil then
      text.centerText = true
    end

    if text.left.size == nil then text.left.size = text.size or 14 end
    if text.right.size == nil then text.right.size = text.size or 14 end

    if text.left.flags == nil then text.left.flags = text.flags or "" end
    if text.right.flags == nil then text.right.flags = text.flags or "" end

    if text.left.font == nil then text.left.font = text.font end
    if text.right.font == nil then text.right.font = text.font end

    if text.left.useGlobalFont == nil then text.left.useGlobalFont = PRD_UseGlobalFont(text) end
    if text.right.useGlobalFont == nil then text.right.useGlobalFont = PRD_UseGlobalFont(text) end
  end

  local PRIMARY_RESOURCE_KEYS = {
    "MANA",
    "RAGE",
    "FOCUS",
    "ENERGY",
    "RUNIC_POWER",
    "LUNAR_POWER",
    "MAELSTROM",
    "INSANITY",
    "FURY",
    "PAIN",
  }

  local function PRD_CopyResourceSetting(value)
    if type(value) ~= "table" then
      return value
    end

    local copy = {}
    for key, child in pairs(value) do
      copy[key] = PRD_CopyResourceSetting(child)
    end
    return copy
  end

  local function PRD_NormalizePrimaryResourceSettings(
    settings,
    legacyText,
    legacyAppearanceText,
    legacyTicks
  )
    settings.text = settings.text or PRD_CopyResourceSetting(legacyText) or {}

    if type(legacyAppearanceText) == "table" then
      if settings.text.size == nil then settings.text.size = legacyAppearanceText.size end
      if settings.text.font == nil then settings.text.font = legacyAppearanceText.font end
      if settings.text.flags == nil then settings.text.flags = legacyAppearanceText.flags end
      if settings.text.useGlobalFont == nil then
        settings.text.useGlobalFont = legacyAppearanceText.useGlobalFont
      end
    end

    if settings.text.size == nil then settings.text.size = 14 end
    if settings.text.flags == nil then settings.text.flags = "" end
    if settings.text.useGlobalFont == nil then settings.text.useGlobalFont = true end
    PRD_NormalizeNativeTextConfig(settings.text, "CUR")

    settings.ticks = settings.ticks or PRD_CopyResourceSetting(legacyTicks) or {}
    if settings.ticks.enabled == nil then settings.ticks.enabled = false end
    if settings.ticks.maxValue == nil then settings.ticks.maxValue = 0 end
    if settings.ticks.automaticMax == nil then
      settings.ticks.automaticMax = not (
        type(legacyTicks) == "table"
        and (tonumber(legacyTicks.maxValue) or 0) > 0
      )
    end
    if type(settings.ticks.entries) ~= "table" then settings.ticks.entries = {} end

    return settings
  end

  local function PRD_BuildNativeTextGroup(text, role, appearanceText)
    PRD_NormalizeNativeTextConfig(text, role == "health" and "PCT" or "CUR")

    local flags = role == "health" and { healthText = true } or { primaryText = true }
    local rightName = role == "health" and "Right text (HP #)" or "Right text (Power #)"
    local visibilityValues = {
      ALWAYS = "Always",
      MOUSEOVER = "On mouseover",
      HIDE = "Hide",
    }

    return {
      type = "group",
      name = "Text",
      order = 20,
      inline = true,
      args = {
        leftVisibility = {
          type = "select",
          name = "Left text (Percent)",
          order = 1,
          values = visibilityValues,
          get = function()
            return text.leftVisibility or "HIDE"
          end,
          set = function(_, value)
            text.leftVisibility = value or "HIDE"
            Addon:ApplyOptionsChange("PRD", flags)
          end,
        },
        rightVisibility = {
          type = "select",
          name = rightName,
          order = 2,
          values = visibilityValues,
          get = function()
            return text.rightVisibility or "HIDE"
          end,
          set = function(_, value)
            text.rightVisibility = value or "HIDE"
            Addon:ApplyOptionsChange("PRD", flags)
          end,
        },
        centerText = {
          type = "toggle",
          name = "Show centered",
          desc = "Reanchors the visible native Blizzard text regions toward the center of the bar.",
          order = 3,
          get = function()
            return text.centerText == true
          end,
          set = function(_, value)
            text.centerText = value and true or false
            Addon:ApplyOptionsChange("PRD", flags)
          end,
        },
        leftFont = {
          type = "group",
          name = "Bar font",
          order = 10,
          inline = true,
          hidden = function()
            return ns.Modules.PRD.db.profile.appearance.unified ~= false
          end,
          args = {
            useGlobalFont = {
              type = "toggle",
              name = "Use global font",
              order = 1,
              get = function()
                return PRD_UseGlobalFont(appearanceText)
              end,
              set = function(_, value)
                appearanceText.useGlobalFont = value and true or false
                Addon:ApplyOptionsChange("PRD", flags)
              end,
            },
            font = {
              type = "select",
              dialogControl = "LSM30_Font",
              name = "Font",
              order = 2,
              values = OptionsUtil.BuildFontValues,
              disabled = function()
                return PRD_UseGlobalFont(appearanceText)
              end,
              get = function()
                return OptionsUtil.ResolveFontKey(appearanceText.font, appearanceText.useGlobalFont)
              end,
              set = function(_, key)
                appearanceText.font = key
                appearanceText.useGlobalFont = false
                Addon:ApplyOptionsChange("PRD", flags)
              end,
            },
            fontSize = {
              type = "range",
              name = "Font size",
              order = 3,
              min = 8,
              max = 32,
              step = 1,
              get = function()
                return Clamp(appearanceText.size or 14, 8, 32)
              end,
              set = function(_, value)
                appearanceText.size = Clamp(value, 8, 32)
                Addon:ApplyOptionsChange("PRD", flags)
              end,
            },
            fontFlags = {
              type = "select",
              name = "Font outline",
              order = 4,
              values = function()
                return OptionsUtil.BuildOutlineValues(true, "Use global outline", ns.Theme.STANDARD_OUTLINE_KEY)
              end,
              get = function()
                return OptionsUtil.GetStoredOutlineValue(appearanceText.flags, ns.Theme.STANDARD_OUTLINE_KEY)
              end,
              set = function(_, key)
                appearanceText.flags = OptionsUtil.SetStoredOutlineValue(key, ns.Theme.STANDARD_OUTLINE_KEY)
                Addon:ApplyOptionsChange("PRD", flags)
              end,
            },
          },
        },
      },
    }
  end

  local function PRD_ValidateDB(db)
    db.appearance.style.borderSize = Clamp(db.appearance.style.borderSize, 0, 12)
    db.health.style.borderSize = Clamp(db.health.style.borderSize, 0, 12)
    db.primary.style.borderSize = Clamp(db.primary.style.borderSize, 0, 12)
    db.secondary.style.borderSize = Clamp(db.secondary.style.borderSize, 0, 12)
    db.outerBorder.size = Clamp(db.outerBorder.size, 0, 12)
  end

  local function PRD_EnsureDefaults(db)
    db.size              = db.size      or {}
    db.health            = db.health    or {}
    db.primary           = db.primary   or {}
    db.secondary         = db.secondary or {}
    db.appearance        = db.appearance or {}
    db.appearance.style  = db.appearance.style or {}
    db.appearance.text   = db.appearance.text or {}
    db.health.style      = db.health.style or {}
    db.health.text       = db.health.text or {}
    db.primary.style     = db.primary.style or {}
    db.primary.resourceSettings = db.primary.resourceSettings or {}
    db.secondary.style   = db.secondary.style or {}
    db.outerBorder       = db.outerBorder or {}
    db.anchor            = db.anchor or {}
    db.health.anchor     = db.health.anchor or { point = "CENTER", x = 0, y = -180 }
    db.primary.anchor    = db.primary.anchor or { point = "CENTER", x = 0, y = -250 }
    db.text              = db.text      or {}
    db.text.health       = db.text.health       or {}
    db.text.secondary    = db.text.secondary    or {}

    PRD_NormalizeNativeTextConfig(db.text.health, "PCT")

    if db.primary.__puiResourceSettingsMigrated ~= true then
      local legacyText = db.text.primary
      local legacyAppearanceText = db.primary.text
      local legacyTicks = db.primary.ticks

      for index = 1, #PRIMARY_RESOURCE_KEYS do
        local resourceKey = PRIMARY_RESOURCE_KEYS[index]
        local settings = db.primary.resourceSettings[resourceKey]
        if type(settings) ~= "table" then
          settings = {}
          db.primary.resourceSettings[resourceKey] = settings
        end

        PRD_NormalizePrimaryResourceSettings(
          settings,
          legacyText,
          legacyAppearanceText,
          legacyTicks
        )
      end

      db.primary.__puiResourceSettingsMigrated = true
      db.text.primary = nil
      db.primary.text = nil
      db.primary.ticks = nil
    end

    for _, settings in pairs(db.primary.resourceSettings) do
      if type(settings) == "table" then
        PRD_NormalizePrimaryResourceSettings(settings)
      end
    end

    db.class             = db.class or {}
    db.class.DRUID       = db.class.DRUID or {}
    db.class.DRUID.forms = db.class.DRUID.forms or {}
    db.class.DRUID.forms.CAT     = db.class.DRUID.forms.CAT     or { primary = {} }
    db.class.DRUID.forms.BEAR    = db.class.DRUID.forms.BEAR    or { primary = {} }
    db.class.DRUID.forms.MOONKIN = db.class.DRUID.forms.MOONKIN or { primary = {} }
    db.class.DRUID.forms.CASTER  = db.class.DRUID.forms.CASTER  or { primary = {} }

    if db.primary.hideAlternateMana == nil then db.primary.hideAlternateMana = false end
    db.secondary.resourceEnabled = db.secondary.resourceEnabled or {}
    db.secondary.resourceSettings = db.secondary.resourceSettings or {}

    if db.secondary.visibilityMode == nil then db.secondary.visibilityMode = "ALWAYS" end
    if db.secondary.inactiveAlpha == nil then db.secondary.inactiveAlpha = 0.15 end
    if db.secondary.showDividers == nil then db.secondary.showDividers = true end
    if db.secondary.dividerSize == nil then db.secondary.dividerSize = 1 end
    if db.secondary.dividerColor == nil then db.secondary.dividerColor = { 0.20, 0.20, 0.24, 1.00 } end
    if db.text.secondary.mode == nil then db.text.secondary.mode = "CUR" end
    if db.text.secondary.showNumber == nil then db.text.secondary.showNumber = true end
    if db.appearance.height == nil then db.appearance.height = 15 end
    db.appearance.unified = false
    if db.appearance.texture == nil then db.appearance.texture = "Pleebar" end
    if db.appearance.squareTexture == nil then db.appearance.squareTexture = true end
    if db.appearance.style.borderSize == nil then db.appearance.style.borderSize = 1 end
    if db.appearance.style.borderColor == nil then db.appearance.style.borderColor = { 0.20, 0.20, 0.24, 1.00 } end
    if db.appearance.style.bgColor == nil then db.appearance.style.bgColor = { 0, 0, 0, 0.65 } end
    if db.appearance.text.size == nil then db.appearance.text.size = 14 end
    if db.appearance.text.flags == nil then db.appearance.text.flags = "" end
    if db.appearance.text.useGlobalFont == nil then db.appearance.text.useGlobalFont = true end

    local function EnsureElementAppearance(config, textConfig)
      if config.height == nil then config.height = db.appearance.height end
      if config.texture == nil then config.texture = db.appearance.texture end
      if config.squareTexture == nil then config.squareTexture = db.appearance.squareTexture end
      if config.style.borderSize == nil then config.style.borderSize = db.appearance.style.borderSize end
      if config.style.borderColor == nil then
        local color = db.appearance.style.borderColor
        config.style.borderColor = { color[1], color[2], color[3], color[4] }
      end
      if config.style.bgColor == nil then
        local color = db.appearance.style.bgColor
        config.style.bgColor = { color[1], color[2], color[3], color[4] }
      end
      if textConfig.size == nil then textConfig.size = db.appearance.text.size end
      if textConfig.flags == nil then textConfig.flags = db.appearance.text.flags end
      if textConfig.font == nil then textConfig.font = db.appearance.text.font end
      if textConfig.useGlobalFont == nil then textConfig.useGlobalFont = db.appearance.text.useGlobalFont end
    end

    EnsureElementAppearance(db.health, db.health.text)
    EnsureElementAppearance(db.secondary, db.text.secondary)

    if db.outerBorder.enabled == nil then db.outerBorder.enabled = false end
    if db.outerBorder.size == nil then db.outerBorder.size = 1 end
    if db.outerBorder.color == nil then db.outerBorder.color = { 0.20, 0.20, 0.24, 1.00 } end

  end

  local function PRD_PrepareProfileDB(db)
    if type(db) ~= "table" then
      return nil
    end

    PRD_EnsureDefaults(db)
    db.syncCVar = nil
    PRD_NormalizeBarColorConfig(db.health, "health")
    PRD_NormalizeBarColorConfig(db.primary, "primary")
    PRD_ValidateDB(db)

    return db
  end

  local function GetPRDState()
    local M = ns.Modules.PRD
    if not (M.db and M.db.profile) then
      return nil
    end

    local db = PRD_PrepareProfileDB(M.db.profile)
    if not db then
      return nil
    end

    local primaryResourceCfg = M:GetPrimaryResourceSettings()

    return {
      M = M,
      db = db,
      size = db.size,
      appearance = db.appearance,
      outerBorder = db.outerBorder,
      healthCfg = db.health,
      primaryCfg = db.primary,
      primaryResourceCfg = primaryResourceCfg,
      secondaryCfg = db.secondary,
      healthTextCfg = db.text.health,
      secondaryTextCfg = db.text.secondary,
    }
  end


  local function PRD_CopyAppearance(source, destination, textDestination)
    destination.height = source.height
    destination.texture = source.texture
    destination.squareTexture = source.squareTexture
    destination.style.borderSize = source.style.borderSize
    destination.style.borderColor = {
      source.style.borderColor[1],
      source.style.borderColor[2],
      source.style.borderColor[3],
      source.style.borderColor[4],
    }
    destination.style.bgColor = {
      source.style.bgColor[1],
      source.style.bgColor[2],
      source.style.bgColor[3],
      source.style.bgColor[4],
    }
    textDestination.size = source.text.size
    textDestination.font = source.text.font
    textDestination.flags = source.text.flags
    textDestination.useGlobalFont = source.text.useGlobalFont
  end


  local PRD = ns.Modules.PRD

  function PRD:EnsurePrimaryResourceSettings(resourceKey)
    local db = self.db.profile
    local settings = db.primary.resourceSettings[resourceKey]
    if type(settings) ~= "table" then
      settings = {}
      db.primary.resourceSettings[resourceKey] = settings
    end

    return PRD_NormalizePrimaryResourceSettings(settings)
  end

  function PRD:NormalizeProfile()
    local db = self.db and self.db.profile
    if not db then
      return
    end

    PRD_EnsureDefaults(db)
    PRD_NormalizeBarColorConfig(db.health, "health")
    PRD_NormalizeBarColorConfig(db.primary, "primary")
    PRD_ValidateDB(db)
    self:NormalizeDruidFormSettings()
    ns.PRDSecondary:NormalizeProfile(db)
    self:NormalizeStackOrder()
    self:InvalidateRuntimeConfig()
  end

  local function PRD_GetMainStackAppearanceTargets(s)
    local targets = {}
    local db = s.db

    if db.detachHealth ~= true then
      targets[#targets + 1] = s.healthCfg
    end

    if s.primaryCfg.detached ~= true then
      targets[#targets + 1] = s.primaryCfg
    end

    local resourceOptions = ns.PRDSecondary:GetResourceOptionsForClass(PLAYER_CLASS) or {}
    for i = 1, #resourceOptions do
      local settings = ns.PRDSecondary:GetResourceSettings(db, resourceOptions[i].key)
      if settings and settings.detached ~= true then
        targets[#targets + 1] = settings
      end
    end

    if #targets == 0 then
      targets[1] = s.healthCfg
    end

    return targets
  end

  function PRD:GetQuickSetupValue(key)
    local s = GetPRDState()
    if not s then
      return nil
    end

    local db = s.db

    if key == "showHealth" then
      return db.hideHealth ~= true
    elseif key == "showPrimary" then
      return db.hidePrimary ~= true
    elseif key == "showSecondary" then
      return s.secondaryCfg.enabled ~= false
    elseif key == "texture" then
      local targets = PRD_GetMainStackAppearanceTargets(s)
      return targets[1].texture or "Pleebar"
    elseif key == "width" then
      return Clamp(s.size.width or 240, 120, 600)
    elseif key == "borderSize" then
      local targets = PRD_GetMainStackAppearanceTargets(s)
      return Clamp(targets[1].style.borderSize or 1, 0, 12)
    end

    return nil
  end

  function PRD:SetQuickSetupValue(key, value)
    local s = GetPRDState()
    if not s then
      return false
    end

    local db = s.db

    if key == "showHealth" then
      db.hideHealth = not value
      Addon:ApplyOptionsChange("PRD", { layout = true })
    elseif key == "showPrimary" then
      db.hidePrimary = not value
      db.__puiHidePrimaryUserSet = true
      Addon:ApplyOptionsChange("PRD", { visibility = true })
      Addon:ApplyOptionsChange("PRD", { layout = true })
    elseif key == "showSecondary" then
      s.secondaryCfg.enabled = value and true or false
      Addon:ApplyOptionsChange("PRD", { secondaryRebuild = true, secondaryText = true, layout = true })
    elseif key == "texture" then
      local targets = PRD_GetMainStackAppearanceTargets(s)
      for i = 1, #targets do
        targets[i].texture = value
      end
      Addon:ApplyOptionsChange("PRD", { health = true, primary = true, secondaryAppearance = true, layout = true })
    elseif key == "width" then
      s.size.width = Clamp(value, 120, 600)
      Addon:ApplyOptionsChange("PRD", { layout = true, mover = true })
      FrameUtil.RefreshSmartSnapState("PRD")
    elseif key == "borderSize" then
      local borderSize = Clamp(value, 0, 12)
      local targets = PRD_GetMainStackAppearanceTargets(s)
      for i = 1, #targets do
        targets[i].style.borderSize = borderSize
      end
      Addon:ApplyOptionsChange("PRD", {
        health = true,
        primary = true,
        secondaryAppearance = true,
        layout = true,
      })
    else
      return false
    end

    return true
  end

  local function PRD_BuildGeneralArgs()
    local s = GetPRDState()
    if not s then
      return {
        unavailable = {
          type = "description",
          name = "Personal Resource Display module is not loaded or has no profile data yet.",
          order = 1,
          fontSize = "medium",
        },
      }
    end

    local db = s.db
    local size = s.size
    local appearance = s.appearance
    local appearanceStyle = appearance.style
    local appearanceText = appearance.text
    local outerBorder = s.outerBorder
    local primaryCfg = s.primaryCfg
    local secondaryCfg = s.secondaryCfg

    return {
      generalHeader = {
        type = "header",
        name = "Personal Resource Display",
        order = 1,
      },
      generalIntro = {
        type = "description",
        name = "Control which PRD bars are shown, how the shared stack is arranged, and whether individual bars should break out into their own movers.",
        order = 2,
        fontSize = "medium",
      },
      visibilityGroup = {
        type = "group",
        name = "What is shown",
        order = 10,
        inline = true,
        args = {
          visibilityIntro = {
            type = "description",
            name = "These toggles decide which bars participate in the main PRD setup.",
            order = 0,
            fontSize = "medium",
          },
          hideHealth = {
            type = "toggle",
            name = "Hide health bar",
            desc = "Hides the health bar from the stacked PRD layout.",
            order = 1,
            get = function()
              return not PRD:GetQuickSetupValue("showHealth")
            end,
            set = function(_, val)
              PRD:SetQuickSetupValue("showHealth", not val)
            end,
          },
          hidePrimary = {
            type = "toggle",
            name = "Hide primary bar",
            desc = "Hides the primary resource bar from the stacked PRD layout.",
            order = 2,
            get = function()
              return not PRD:GetQuickSetupValue("showPrimary")
            end,
            set = function(_, val)
              PRD:SetQuickSetupValue("showPrimary", not val)
            end,
          },
          hideSecondary = {
            type = "toggle",
            name = "Hide secondary bar",
            desc = "Hides the custom class-resource bar. Alternate Mana is controlled separately.",
            order = 3,
            get = function()
              return not PRD:GetQuickSetupValue("showSecondary")
            end,
            set = function(_, val)
              PRD:SetQuickSetupValue("showSecondary", not val)
            end,
          },
          hideAlternateMana = {
            type = "toggle",
            name = "Hide alternate Mana bar",
            desc = "Hides Mana when your active specialization or form uses another primary power.",
            order = 4,
            hidden = PLAYER_CLASS ~= "PRIEST" and PLAYER_CLASS ~= "DRUID" and PLAYER_CLASS ~= "SHAMAN",
            get = function()
              return primaryCfg.hideAlternateMana == true
            end,
            set = function(_, val)
              primaryCfg.hideAlternateMana = val and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryRebuild = true, secondaryText = true, layout = true })
            end,
          },
        },
      },
      layoutGroup = {
        type = "group",
        name = "Stack layout",
        order = 20,
        inline = true,
        args = {
          layoutIntro = {
            type = "description",
            name = "Use the arrows in the preview to change stack order. These settings control the shared layout when bars are not detached.",
            order = 0,
            fontSize = "medium",
          },
          width = {
            type = "range",
            name = "Shared width",
            desc = "Controls the shared width used when the bars are stacked together.",
            order = 1,
            min = 120,
            max = 600,
            step = 1,
            get = function()
              return PRD:GetQuickSetupValue("width")
            end,
            set = function(_, val)
              PRD:SetQuickSetupValue("width", val)
            end,
          },
          stackGap = {
            type = "range",
            name = "Gap between stacked bars",
            desc = "Controls the vertical gap between the stacked PRD bars when they are not detached.",
            order = 2,
            min = 0,
            max = 20,
            step = 1,
            get = function()
              return Clamp(size.gap or 0, 0, 20)
            end,
            set = function(_, val)
              size.gap = Clamp(val, 0, 20)
              Addon:ApplyOptionsChange("PRD", { layout = true })
            end,
          },

        },
      },
      playerHealthGroup = {
        type = "group",
        name = "Player health",
        order = 22,
        inline = true,
        args = {
          usePlayerHealth = {
            type = "toggle",
            name = "Use Player health",
            desc = "Uses the actual Player unit frame in the PRD health position and hides the native PRD health bar.",
            order = 1,
            disabled = function()
              return InCombatLockdown()
            end,
            get = function()
              return ns.Modules.PRD.db.profile.usePlayerHealth == true
            end,
            set = function(_, value)
              ns.Modules.PRD:SetUsePlayerHealth(value)
            end,
          },
        },
      },
      appearanceGroup = {
        type = "group",
        name = "Unified appearance",
        order = 25,
        inline = true,
        hidden = true,
        args = {
          unified = {
            type = "toggle",
            name = "Use unified appearance",
            desc = "Applies the settings below to every PRD bar. Turn this off to configure Health, Primary, and Secondary elements separately on their own pages.",
            order = 0,
            get = function()
              return appearance.unified ~= false
            end,
            set = function(_, value)
              local unified = value and true or false
              if appearance.unified ~= false and not unified then
                local primaryResourceSettings = s.M:GetPrimaryResourceSettings()
                PRD_CopyAppearance(appearance, db.health, db.health.text)
                PRD_CopyAppearance(appearance, db.primary, primaryResourceSettings.text)
                PRD_CopyAppearance(appearance, db.secondary, db.text.secondary)
              end
              appearance.unified = unified
              Addon:ApplyOptionsChange("PRD", { health = true, primary = true, secondaryAppearance = true, text = true, layout = true })
              Addon:NotifyOptionsTreeChanged("PRD", { "PRD", "general" })
            end,
          },
          height = {
            type = "range",
            name = "Bar height",
            desc = "Sets the same height for Health, Primary, Alternate Mana, and every secondary resource row.",
            order = 1,
            disabled = function()
              return appearance.unified == false
            end,
            min = 6,
            max = 40,
            step = 1,
            get = function()
              return Clamp(appearance.height or 15, 6, 40)
            end,
            set = function(_, value)
              appearance.height = Clamp(value, 6, 40)
              Addon:ApplyOptionsChange("PRD", { health = true, primary = true, secondaryLayout = true, text = true, layout = true })
            end,
          },
          texture = {
            type = "select",
            dialogControl = "LSM30_Statusbar",
            name = "Bar texture",
            order = 2,
            disabled = function()
              return appearance.unified == false
            end,
            values = function()
              return OptionsUtil.BuildStatusbarValues(false)
            end,
            get = function()
              return appearance.texture or "Pleebar"
            end,
            set = function(_, value)
              appearance.texture = value
              Addon:ApplyOptionsChange("PRD", { health = true, primary = true, secondaryAppearance = true })
            end,
          },
          fontSize = {
            type = "range",
            name = "Font size",
            order = 3,
            disabled = function()
              return appearance.unified == false
            end,
            min = 8,
            max = 32,
            step = 1,
            get = function()
              return Clamp(appearanceText.size or 14, 8, 32)
            end,
            set = function(_, value)
              appearanceText.size = Clamp(value, 8, 32)
              Addon:ApplyOptionsChange("PRD", { text = true, secondaryText = true })
            end,
          },
          useGlobalFont = {
            type = "toggle",
            name = "Use global font",
            order = 4,
            disabled = function()
              return appearance.unified == false
            end,
            get = function()
              return PRD_UseGlobalFont(appearanceText)
            end,
            set = function(_, value)
              appearanceText.useGlobalFont = value and true or false
              Addon:ApplyOptionsChange("PRD", { text = true, secondaryText = true })
            end,
          },
          font = {
            type = "select",
            dialogControl = "LSM30_Font",
            name = "Font",
            order = 5,
            values = OptionsUtil.BuildFontValues,
            disabled = function()
              return appearance.unified == false or PRD_UseGlobalFont(appearanceText)
            end,
            get = function()
              return OptionsUtil.ResolveFontKey(appearanceText.font, appearanceText.useGlobalFont)
            end,
            set = function(_, value)
              appearanceText.font = value
              appearanceText.useGlobalFont = false
              Addon:ApplyOptionsChange("PRD", { text = true, secondaryText = true })
            end,
          },
          fontFlags = {
            type = "select",
            name = "Font outline",
            order = 6,
            disabled = function()
              return appearance.unified == false
            end,
            values = function()
              return OptionsUtil.BuildOutlineValues(true, "Use global outline", ns.Theme.STANDARD_OUTLINE_KEY)
            end,
            get = function()
              return OptionsUtil.GetStoredOutlineValue(appearanceText.flags, ns.Theme.STANDARD_OUTLINE_KEY)
            end,
            set = function(_, value)
              appearanceText.flags = OptionsUtil.SetStoredOutlineValue(value, ns.Theme.STANDARD_OUTLINE_KEY)
              Addon:ApplyOptionsChange("PRD", { text = true, secondaryText = true })
            end,
          },
          borderSize = {
            type = "range",
            name = "PRD element border",
            desc = "Applies the same border thickness to every PRD element and tracked spell icon.",
            order = 10,
            disabled = function()
              return appearance.unified == false
            end,
            min = 0,
            max = 12,
            step = 1,
            get = function()
              return Clamp(appearanceStyle.borderSize or 1, 0, 12)
            end,
            set = function(_, value)
              appearanceStyle.borderSize = Clamp(value, 0, 12)
              Addon:ApplyOptionsChange("PRD", { health = true, primary = true, secondaryAppearance = true, layout = true })
            end,
          },
          borderColor = {
            type = "color",
            name = "PRD element border color",
            order = 11,
            disabled = function()
              return appearance.unified == false
            end,
            hasAlpha = true,
            get = function()
              local color = appearanceStyle.borderColor
              return color[1], color[2], color[3], color[4]
            end,
            set = function(_, r, g, b, a)
              appearanceStyle.borderColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { health = true, primary = true, secondaryAppearance = true })
            end,
          },
          backgroundColor = {
            type = "color",
            name = "Element background",
            order = 12,
            disabled = function()
              return appearance.unified == false
            end,
            hasAlpha = true,
            get = function()
              local color = appearanceStyle.bgColor
              return color[1], color[2], color[3], color[4]
            end,
            set = function(_, r, g, b, a)
              appearanceStyle.bgColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { health = true, primary = true, secondaryAppearance = true })
            end,
          },
        },
      },
      outerBorderGroup = {
        type = "group",
        name = "Box border",
        order = 27,
        inline = true,
        args = {
          enabled = {
            type = "toggle",
            name = "Show outer border",
            desc = "Draws one box around all visible bars attached to the main PRD stack.",
            order = 1,
            get = function()
              return outerBorder.enabled == true
            end,
            set = function(_, value)
              outerBorder.enabled = value and true or false
              Addon:ApplyOptionsChange("PRD", { outerBorder = true })
            end,
          },
          size = {
            type = "range",
            name = "Outer border size",
            order = 2,
            min = 0,
            max = 12,
            step = 1,
            disabled = function()
              return outerBorder.enabled ~= true
            end,
            get = function()
              return Clamp(outerBorder.size or 1, 0, 12)
            end,
            set = function(_, value)
              outerBorder.size = Clamp(value, 0, 12)
              Addon:ApplyOptionsChange("PRD", { outerBorder = true })
            end,
          },
          color = {
            type = "color",
            name = "Outer border color",
            order = 3,
            hasAlpha = true,
            disabled = function()
              return outerBorder.enabled ~= true
            end,
            get = function()
              local color = outerBorder.color
              return color[1], color[2], color[3], color[4]
            end,
            set = function(_, r, g, b, a)
              outerBorder.color = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { outerBorder = true })
            end,
          },
        },
      },
      detachGroup = {
        type = "group",
        name = "Separate bars",
        order = 30,
        inline = true,
        args = {
          detachIntro = {
            type = "description",
            name = "Detach a bar when you want it to leave the shared stack and use its own mover.",
            order = 0,
            fontSize = "medium",
          },
          detachHealth = {
            type = "toggle",
            name = "Detach health bar",
            desc = "Lets the health bar be positioned separately from the main PRD stack.",
            order = 1,
            get = function()
              return db.detachHealth == true
            end,
            set = function(_, val)
              db.detachHealth = not not val
              Addon:ApplyOptionsChange("PRD", { layout = true, mover = true })
            end,
          },
          detachPrimary = {
            type = "toggle",
            name = "Detach primary bar",
            desc = "Lets the primary resource bar be positioned separately from the main PRD stack.",
            order = 2,
            get = function()
              return primaryCfg.detached == true
            end,
            set = function(_, val)
              primaryCfg.detached = not not val
              Addon:ApplyOptionsChange("PRD", { layout = true, mover = true })
            end,
          },
          secondaryResourceDetach = {
            type = "description",
            name = "Secondary resources are detached separately on the Secondary page, under Resources.",
            order = 3,
          },
        },
      },
    }
  end

  local function PRD_BuildHealthArgs()
    local s = GetPRDState()
    if not s then
      return {
        unavailable = {
          type = "description",
          name = "Personal Resource Display module is not loaded or has no profile data yet.",
          order = 1,
          fontSize = "medium",
        },
      }
    end

    local size = s.size
    local cfg = s.healthCfg
    local text = s.healthTextCfg
    local appearance = s.appearance.unified ~= false and s.appearance or cfg
    local style = appearance.style

    return {
      header = {
        type = "header",
        name = "Health bar",
        order = 1,
      },
      layoutGroup = {
        type = "group",
        name = "Layout",
        order = 10,
        inline = true,
        args = {
          height = {
            type = "range",
            name = "Bar height",
            order = 1,
            min = 6,
            max = 40,
            step = 1,
            get = function()
              return Clamp(appearance.height or 15, 6, 40)
            end,
            set = function(_, val)
              appearance.height = Clamp(val, 6, 40)
              Addon:ApplyOptionsChange("PRD", { health = true, layout = true })
            end,
          },
          width = {
            type = "range",
            name = "Detached width",
            desc = "Used when the health bar is detached from the shared PRD stack.",
            order = 2,
            min = 120,
            max = 600,
            step = 1,
            get = function()
              return Clamp(cfg.width or size.width or 240, 120, 600)
            end,
            set = function(_, val)
              cfg.width = Clamp(val, 120, 600)
              Addon:ApplyOptionsChange("PRD", { layout = true })
              FrameUtil.RefreshSmartSnapState("PRD_HEALTH")
            end,
          },
          texture = {
            type = "select",
            dialogControl = "LSM30_Statusbar",
            name = "Texture",
            order = 3,
            values = function()
              return OptionsUtil.BuildStatusbarValues(false)
            end,
            get = function()
              return appearance.texture
            end,
            set = function(_, key)
              appearance.texture = key
              Addon:ApplyOptionsChange("PRD", { health = true })
            end,
          },
          squareTexture = {
            type = "toggle",
            name = "Square texture",
            order = 4,
            get = function()
              return appearance.squareTexture ~= false
            end,
            set = function(_, value)
              appearance.squareTexture = value and true or false
              Addon:ApplyOptionsChange("PRD", { health = true })
            end,
          },
        },
      },
      textGroup = PRD_BuildNativeTextGroup(text, "health", appearance.text),
      colorGroup = PRD_BuildNativeBarColorGroup(cfg, "health"),
      styleGroup = {
        type = "group",
        name = "Frame style",
        order = 40,
        inline = true,
        args = {
          borderSize = {
            type = "range",
            name = "Border size",
            order = 1,
            min = 0,
            max = 12,
            step = 1,
            get = function()
              return Clamp(style.borderSize or 1, 0, 12)
            end,
            set = function(_, val)
              style.borderSize = Clamp(val, 0, 12)
              Addon:ApplyOptionsChange("PRD", { health = true, layout = true })
            end,
          },
          borderColor = {
            type = "color",
            name = "Border color",
            order = 2,
            hasAlpha = true,
            get = function()
              local c = style.borderColor
              return c[1] or 0.20, c[2] or 0.20, c[3] or 0.24, c[4] or 1
            end,
            set = function(_, r, g, b, a)
              style.borderColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { health = true })
            end,
          },
          bgColor = {
            type = "color",
            name = "Background color",
            order = 3,
            hasAlpha = true,
            get = function()
              local c = style.bgColor
              return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.65
            end,
            set = function(_, r, g, b, a)
              style.bgColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { health = true })
            end,
          },
        },
      },
    }
  end

  local DRUID_FORM_COLOR_VALUES = {
    INHERIT = "Use Primary setting",
    DEFAULT = "Primary resource (Default)",
    CLASS = "Class color",
    CUSTOM = "Custom color",
    TEXTURE = "Texture color",
  }

  local DRUID_FORM_OPTIONS = {
    { key = "CASTER", name = "Caster" },
    { key = "MOONKIN", name = "Moonkin" },
    { key = "CAT", name = "Cat" },
    { key = "BEAR", name = "Bear" },
  }

  local function PRD_BuildDruidPrimaryFormArgs(state)
    if PLAYER_CLASS ~= "DRUID" then
      return nil
    end

    local forms = state.db.class.DRUID.forms
    local formArgs = {}

    for index = 1, #DRUID_FORM_OPTIONS do
      local option = DRUID_FORM_OPTIONS[index]
      local form = forms[option.key]
      form.primary = form.primary or {}
      local config = state.M:NormalizeDruidFormPrimary(form.primary)

      formArgs[option.key] = {
        type = "group",
        name = option.name,
        order = index + 1,
        args = {
          description = {
            type = "description",
            name = "Overrides only this form's color. All other settings remain shared with Primary.",
            order = 1,
          },
          colorMode = {
            type = "select",
            name = "Status bar color",
            order = 2,
            values = DRUID_FORM_COLOR_VALUES,
            get = function()
              return config.colorMode or "INHERIT"
            end,
            set = function(_, value)
              config.colorMode = value ~= "INHERIT" and value or nil
              Addon:ApplyOptionsChange("PRD", { primary = true })
            end,
          },
          customColor = {
            type = "color",
            name = "Custom color",
            order = 3,
            hasAlpha = true,
            disabled = function()
              return config.colorMode ~= "CUSTOM"
            end,
            get = function()
              local color = config.customColor or { 1, 1, 1, 1 }
              return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
            end,
            set = function(_, r, g, b, a)
              config.customColor = { r, g, b, a }
              config.colorMode = "CUSTOM"
              Addon:ApplyOptionsChange("PRD", { primary = true })
            end,
          },
          reset = {
            type = "execute",
            name = "Reset form override",
            order = 10,
            func = function()
              config.colorMode = nil
              config.customColor = nil
              Addon:ApplyOptionsChange("PRD", { primary = true })
            end,
          },
        },
      }
    end

    return {
      type = "group",
      name = "Form overrides",
      order = 50,
      childGroups = "tab",
      args = formArgs,
    }
  end

  local function PRD_BuildPrimaryTicksGroup(owner, tickConfig)
    local entries = tickConfig.entries

    local function GetMaximum()
      return owner:GetPrimaryTickMaximum(tickConfig)
    end

    local function RefreshTickOptions()
      Addon:NotifyOptionsTreeChanged("PRD", { "PRD", "primary" })
    end

    local args = {
      enabled = {
        type = "toggle",
        name = "Enable ticks",
        order = 1,
        get = function()
          return tickConfig.enabled == true
        end,
        set = function(_, value)
          tickConfig.enabled = value and true or false
          Addon:ApplyOptionsChange("PRD", { primaryTicks = true })
          RefreshTickOptions()
        end,
      },
      automaticMax = {
        type = "toggle",
        name = "Use detected maximum",
        desc = "Uses the current maximum reported by the game. If it is restricted, ticks wait for a non-secret value outside combat.",
        order = 2,
        hidden = function()
          return tickConfig.enabled ~= true
        end,
        get = function()
          return tickConfig.automaticMax ~= false
        end,
        set = function(_, value)
          tickConfig.automaticMax = value and true or false
          if tickConfig.automaticMax then
            owner:RefreshPrimaryResourceMaximum()
          end
          Addon:ApplyOptionsChange("PRD", { primaryTicks = true })
          RefreshTickOptions()
        end,
      },
      detectedMax = {
        type = "description",
        name = function()
          local maximum = owner:GetPrimaryResourceMaximum()
          if maximum then
            return "Detected maximum: " .. tostring(maximum)
          end
          return "Detected maximum is unavailable until the game exposes a non-secret value outside combat."
        end,
        order = 3,
        hidden = function()
          return tickConfig.enabled ~= true or tickConfig.automaticMax == false
        end,
      },
      maxValue = {
        type = "input",
        name = "Manual maximum",
        desc = "Sets the scale used for tick positions.",
        order = 4,
        hidden = function()
          return tickConfig.enabled ~= true or tickConfig.automaticMax ~= false
        end,
        validate = function(_, value)
          local maximum = tonumber(value)
          if maximum and maximum > 0 then
            return true
          end
          return "Enter a number greater than 0."
        end,
        get = function()
          return tostring(tickConfig.maxValue or 0)
        end,
        set = function(_, value)
          tickConfig.maxValue = tonumber(value) or 0
          Addon:ApplyOptionsChange("PRD", { primaryTicks = true })
          RefreshTickOptions()
        end,
      },
      add = {
        type = "execute",
        name = "Add tick",
        order = 5,
        hidden = function()
          return tickConfig.enabled ~= true
        end,
        disabled = function()
          return GetMaximum() == nil
        end,
        func = function()
          entries[#entries + 1] = {
            value = 0,
            width = 2,
            height = 0,
            color = { 1, 1, 1, 1 },
          }
          Addon:ApplyOptionsChange("PRD", { primaryTicks = true })
          RefreshTickOptions()
        end,
      },
    }

    for index = 1, #entries do
      local tickIndex = index
      local tick = entries[tickIndex]

      args["tick" .. tickIndex] = {
        type = "group",
        name = "Tick " .. tickIndex,
        order = 10 + tickIndex,
        inline = true,
        hidden = function()
          return tickConfig.enabled ~= true
        end,
        args = {
          value = {
            type = "input",
            name = "Value",
            order = 1,
            validate = function(_, value)
              local number = tonumber(value)
              local maximum = GetMaximum() or 0
              if number and number >= 0 and number <= maximum then
                return true
              end
              return "Enter a value from 0 to " .. tostring(maximum) .. "."
            end,
            get = function()
              return tostring(tick.value or 0)
            end,
            set = function(_, value)
              tick.value = tonumber(value) or 0
              Addon:ApplyOptionsChange("PRD", { primaryTicks = true })
            end,
          },
          width = {
            type = "range",
            name = "Tick width",
            order = 2,
            min = 1,
            max = 50,
            step = 1,
            get = function()
              return Clamp(tick.width or 2, 1, 50)
            end,
            set = function(_, value)
              tick.width = Clamp(value, 1, 50)
              Addon:ApplyOptionsChange("PRD", { primaryTicks = true })
            end,
          },
          height = {
            type = "range",
            name = "Tick height",
            desc = "0 matches the bar height.",
            order = 3,
            min = 0,
            max = 50,
            step = 1,
            get = function()
              return Clamp(tick.height or 0, 0, 50)
            end,
            set = function(_, value)
              tick.height = Clamp(value, 0, 50)
              Addon:ApplyOptionsChange("PRD", { primaryTicks = true })
            end,
          },
          color = {
            type = "color",
            name = "Tick color",
            order = 4,
            hasAlpha = true,
            get = function()
              local color = tick.color or { 1, 1, 1, 1 }
              return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
            end,
            set = function(_, r, g, b, a)
              tick.color = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { primaryTicks = true })
            end,
          },
          delete = {
            type = "execute",
            name = "Delete tick",
            order = 5,
            func = function()
              table.remove(entries, tickIndex)
              Addon:ApplyOptionsChange("PRD", { primaryTicks = true })
              RefreshTickOptions()
            end,
          },
        },
      }
    end

    return {
      type = "group",
      name = "Tick markers",
      order = 15,
      inline = true,
      args = args,
    }
  end

  local function PRD_BuildPrimaryArgs()
    local s = GetPRDState()
    if not s then
      return {
        unavailable = {
          type = "description",
          name = "Personal Resource Display module is not loaded or has no profile data yet.",
          order = 1,
          fontSize = "medium",
        },
      }
    end

    local size = s.size
    local cfg = s.primaryCfg
    local resourceSettings = s.primaryResourceCfg
    local text = resourceSettings.text
    local appearance = s.appearance.unified ~= false and s.appearance or cfg
    local style = appearance.style

    return {
      header = {
        type = "header",
        name = function()
          local resourceKey = s.M:GetPrimaryResourceKey()
          if not resourceKey then
            return "Primary bar"
          end

          local resourceName = resourceKey:gsub("_", " "):lower()
          resourceName = resourceName:gsub("^%l", string.upper)
          return "Primary bar - " .. resourceName
        end,
        order = 1,
      },
      visibilityGroup = {
        type = "group",
        name = "Visibility",
        order = 5,
        inline = true,
        hidden = PLAYER_CLASS ~= "PRIEST" and PLAYER_CLASS ~= "DRUID" and PLAYER_CLASS ~= "SHAMAN",
        args = {
          hideAlternateMana = {
            type = "toggle",
            name = "Hide alternate Mana bar",
            desc = "Hides Mana when your active specialization or form uses another primary power.",
            order = 1,
            get = function()
              return cfg.hideAlternateMana == true
            end,
            set = function(_, value)
              cfg.hideAlternateMana = value and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryRebuild = true, secondaryText = true, layout = true })
            end,
          },
        },
      },
      layoutGroup = {
        type = "group",
        name = "Layout",
        order = 10,
        inline = true,
        args = {
          height = {
            type = "range",
            name = "Bar height",
            order = 1,
            min = 6,
            max = 40,
            step = 1,
            get = function()
              return Clamp(appearance.height or 15, 6, 40)
            end,
            set = function(_, val)
              appearance.height = Clamp(val, 6, 40)
              Addon:ApplyOptionsChange("PRD", { primary = true, layout = true })
            end,
          },
          width = {
            type = "range",
            name = "Detached width",
            desc = "Used when the primary bar is detached from the shared PRD stack.",
            order = 2,
            min = 120,
            max = 600,
            step = 1,
            get = function()
              return Clamp(cfg.width or size.width or 240, 120, 600)
            end,
            set = function(_, val)
              cfg.width = Clamp(val, 120, 600)
              Addon:ApplyOptionsChange("PRD", { layout = true })
              FrameUtil.RefreshSmartSnapState("PRD_PRIMARY")
            end,
          },
          texture = {
            type = "select",
            dialogControl = "LSM30_Statusbar",
            name = "Texture",
            order = 3,
            values = function()
              return OptionsUtil.BuildStatusbarValues(false)
            end,
            get = function()
              return appearance.texture
            end,
            set = function(_, key)
              appearance.texture = key
              Addon:ApplyOptionsChange("PRD", { primary = true })
            end,
          },
          squareTexture = {
            type = "toggle",
            name = "Square texture",
            order = 4,
            get = function()
              return appearance.squareTexture ~= false
            end,
            set = function(_, value)
              appearance.squareTexture = value and true or false
              Addon:ApplyOptionsChange("PRD", { primary = true })
            end,
          },
        },
      },
      ticksGroup = PRD_BuildPrimaryTicksGroup(s.M, resourceSettings.ticks),
      textGroup = PRD_BuildNativeTextGroup(text, "primary", text),
      colorGroup = PRD_BuildNativeBarColorGroup(cfg, "primary"),
      styleGroup = {
        type = "group",
        name = "Frame style",
        order = 40,
        inline = true,
        args = {
          borderSize = {
            type = "range",
            name = "Border size",
            order = 1,
            min = 0,
            max = 12,
            step = 1,
            get = function()
              return Clamp(style.borderSize or 1, 0, 12)
            end,
            set = function(_, val)
              style.borderSize = Clamp(val, 0, 12)
              Addon:ApplyOptionsChange("PRD", { primary = true, layout = true })
            end,
          },
          borderColor = {
            type = "color",
            name = "Border color",
            order = 2,
            hasAlpha = true,
            get = function()
              local c = style.borderColor
              return c[1] or 0.20, c[2] or 0.20, c[3] or 0.24, c[4] or 1
            end,
            set = function(_, r, g, b, a)
              style.borderColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { primary = true })
            end,
          },
          bgColor = {
            type = "color",
            name = "Background color",
            order = 3,
            hasAlpha = true,
            get = function()
              local c = style.bgColor
              return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.65
            end,
            set = function(_, r, g, b, a)
              style.bgColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { primary = true })
            end,
          },
        },
      },
    }
  end

  local RESOURCE_ANCHOR_VALUES = {
    TOPLEFT = "Top left",
    TOP = "Top",
    TOPRIGHT = "Top right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom right",
  }

  local RESOURCE_THRESHOLD_VALUES = {
    NONE = "Disabled",
    BELOW = "Below threshold",
    AT_OR_ABOVE = "At or above threshold",
  }

  local RESOURCE_GLOW_VALUES = {
    PIXEL = "Pixel glow",
    AUTOCAST = "Autocast shine",
    PROC = "Proc glow",
  }

  local RESOURCE_COMPLETION_ANIMATION_VALUES = {
    FADE = "Fade",
    PULSE = "Pulse",
  }

  local RESOURCE_RECHARGE_DIRECTION_VALUES = {
    LTR = "Left to right",
    RTL = "Right to left",
    TTB = "Top down",
    BTT = "Bottom up",
  }

  local function PRD_BuildResourceBehaviorGroup(settings, resourceKey)
    local behavior = settings.behavior

    if resourceKey == "RUNES" or resourceKey == "ESSENCE" then
      local args = {
        showRechargeTime = {
          type = "toggle",
          name = "Show recharge time",
          order = 1,
          get = function()
            return behavior.showRechargeTime ~= false
          end,
          set = function(_, value)
            behavior.showRechargeTime = value and true or false
            Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
          end,
        },
        showReadyGlow = {
          type = "toggle",
          name = "Show ready glow",
          order = 2,
          get = function()
            return behavior.showReadyGlow ~= false
          end,
          set = function(_, value)
            behavior.showReadyGlow = value and true or false
            Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
          end,
        },
        completionAnimation = {
          type = "select",
          name = "Completion animation",
          order = 3,
          values = RESOURCE_COMPLETION_ANIMATION_VALUES,
          get = function()
            return behavior.completionAnimation or "FADE"
          end,
          set = function(_, value)
            behavior.completionAnimation = value or "FADE"
            Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
          end,
        },
      }

      if resourceKey == "ESSENCE" then
        args.rechargeDirection = {
          type = "select",
          name = "Recharge direction",
          order = 4,
          values = RESOURCE_RECHARGE_DIRECTION_VALUES,
          get = function()
            return behavior.rechargeDirection or "LTR"
          end,
          set = function(_, value)
            behavior.rechargeDirection = value or "LTR"
            Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
          end,
        }
      end

      return {
        type = "group",
        name = "Resource behavior",
        order = 5,
        inline = true,
        args = args,
      }
    elseif resourceKey == "STAGGER" then
      return {
        type = "group",
        name = "Resource behavior",
        order = 5,
        inline = true,
        args = {
          useSeverityColors = {
            type = "toggle",
            name = "Use severity colors",
            desc = "Colors Stagger green, yellow, or red based on the thresholds below.",
            order = 1,
            get = function()
              return behavior.useSeverityColors ~= false
            end,
            set = function(_, value)
              behavior.useSeverityColors = value and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
          showSeverityLabel = {
            type = "toggle",
            name = "Show severity label",
            desc = "Adds LOW, MED, or HIGH to the Stagger text.",
            order = 2,
            get = function()
              return behavior.showSeverityLabel == true
            end,
            set = function(_, value)
              behavior.showSeverityLabel = value and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
          yellowThreshold = {
            type = "range",
            name = "Yellow threshold",
            order = 3,
            min = 0,
            max = 99,
            step = 1,
            isPercent = true,
            get = function()
              return Clamp(behavior.yellowThreshold or 30, 0, 99)
            end,
            set = function(_, value)
              value = Clamp(value, 0, 99)
              behavior.yellowThreshold = value
              if behavior.redThreshold ~= nil and behavior.redThreshold < value then
                behavior.redThreshold = value
              end
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
          redThreshold = {
            type = "range",
            name = "Red threshold",
            order = 4,
            min = 1,
            max = 100,
            step = 1,
            isPercent = true,
            get = function()
              return Clamp(behavior.redThreshold or 60, 1, 100)
            end,
            set = function(_, value)
              value = Clamp(value, 1, 100)
              behavior.redThreshold = value
              if behavior.yellowThreshold ~= nil and behavior.yellowThreshold > value then
                behavior.yellowThreshold = value
              end
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
        },
      }
    end

    return nil
  end

  local function PRD_BuildResourceLayoutArgs(state, resource)
    local settings = ns.PRDSecondary:GetResourceSettings(
      state.db,
      resource.key
    )
    local anchor = settings.anchor
    local style = settings.style
    local text = settings.text
    local cues = settings.cues
    local supportsNumericCues = ns.PRDSecondary:ResourceSupportsNumericCues(resource.key)
    local applicationCountdownMax = ns.PRDSecondary:GetApplicationCountdownMax(resource.key)
    local stackColorThresholds = resource.category == "TRACKED_EFFECT"
      and ns.PRDSecondary:ResourceSupportsStackColorShifts(resource.key)
      and AuraWidget.EnsureStackColorThresholds(settings)
      or nil
    local freezingRecoloringEnabled = false
    if resource.key == "FREEZING" and stackColorThresholds then
      for index = 1, #stackColorThresholds do
        if stackColorThresholds[index].enabled == true then
          freezingRecoloringEnabled = true
          break
        end
      end
    end

    local function AppearanceDisabled()
      return settings.useSharedAppearance ~= false
    end

    local function RefreshStackColorOptions()
      Addon:NotifyOptionsTreeChanged("PRD", { "PRD", "secondary" })
    end

    local function BuildStackColorThresholdGroup(index)
      local threshold = stackColorThresholds[index]

      return {
        type = "group",
        name = "Stack color shift " .. index,
        order = index,
        inline = true,
        args = {
          enabled = {
            type = "toggle",
            name = "Enable",
            order = 1,
            get = function()
              return threshold.enabled == true
            end,
            set = function(_, value)
              threshold.enabled = value and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          value = {
            type = "input",
            name = "Start at stack",
            order = 2,
            disabled = function()
              return threshold.enabled ~= true
            end,
            validate = function(_, value)
              local stack = tonumber(value)
              if stack and stack >= 1 and stack <= 30 and stack == math.floor(stack) then
                return true
              end
              return "Enter a whole stack value from 1 to 30."
            end,
            get = function()
              return tostring(threshold.value or 1)
            end,
            set = function(_, value)
              threshold.value = tonumber(value)
              AuraWidget.EnsureStackColorThresholds(settings)
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
              RefreshStackColorOptions()
            end,
          },
          colorMode = {
            type = "select",
            name = "Color",
            order = 3,
            values = STACK_THRESHOLD_COLOR_VALUES,
            disabled = function()
              return threshold.enabled ~= true
            end,
            get = function()
              return threshold.colorMode
            end,
            set = function(_, value)
              threshold.colorMode = value == "CLASS" and "CLASS" or "CUSTOM"
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          customColor = {
            type = "color",
            name = "Custom color",
            order = 4,
            hasAlpha = true,
            disabled = function()
              return threshold.enabled ~= true or threshold.colorMode ~= "CUSTOM"
            end,
            get = function()
              local color = threshold.color or { 1, 1, 1, 1 }
              return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
            end,
            set = function(_, r, g, b, a)
              threshold.color = { r, g, b, a }
              threshold.colorMode = "CUSTOM"
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          delete = {
            type = "execute",
            name = "Delete shift",
            order = 5,
            func = function()
              if AuraWidget.RemoveStackColorThreshold(settings, index) then
                Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
                RefreshStackColorOptions()
              end
            end,
          },
        },
      }
    end

    local function BuildStackColorThresholdArgs()
      local args = {}
      if not stackColorThresholds then
        return args
      end

      for index = 1, #stackColorThresholds do
        args["shift" .. index] = BuildStackColorThresholdGroup(index)
      end

      args.add = {
        type = "execute",
        name = "Add stack color shift",
        order = #stackColorThresholds + 1,
        disabled = #stackColorThresholds >= 30,
        func = function()
          if AuraWidget.AddStackColorThreshold(settings, 30) then
            Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            RefreshStackColorOptions()
          end
        end,
      }

      return args
    end

    local function DesaturateThresholdDisabled()
      return cues.desaturateMode == "NONE"
    end

    local function GlowThresholdDisabled()
      return cues.glowMode == "NONE"
    end

    local function BuffGlowDisabled()
      return (tonumber(cues.buffGlowSpellID) or 0) <= 0
    end

    return {
      enabled = {
        type = "toggle",
        name = "Enable " .. resource.name,
        order = 1,
        get = function()
          return PRD:IsSecondaryResourceEnabled(resource.key)
        end,
        set = function(_, value)
          PRD:SetSecondaryResourceEnabled(resource.key, value)
        end,
      },
      useSharedAppearance = {
        type = "toggle",
        name = "Use shared secondary appearance",
        desc = resource.category == "TRACKED_EFFECT"
          and "Uses the shared Secondary height, texture, text, and frame style. Bar color stays specific to this tracked effect."
          or "Uses the shared Secondary height, texture, colors, text, and frame style. Layout, tick separators, and spend cues stay specific to this resource.",
        order = 2,
        hidden = true,
        get = function()
          return settings.useSharedAppearance ~= false
        end,
          set = function(_, value)
            settings.useSharedAppearance = value and true or false
            Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
        end,
      },
      behaviorGroup = PRD_BuildResourceBehaviorGroup(settings, resource.key),
      layout = {
        type = "group",
        name = "Layout",
        order = 10,
        inline = true,
        args = {
          detached = {
            type = "toggle",
            name = "Detach this resource",
            desc = "Gives this resource its own position and width.",
            order = 1,
            get = function()
              return settings.detached == true
            end,
            set = function(_, value)
              settings.detached = value and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryLayout = true })
            end,
          },
          height = {
            type = "range",
            name = "Height",
            order = 2,
            hidden = function()
              return state.appearance.unified ~= false or AppearanceDisabled()
            end,
            min = 6,
            max = 40,
            step = 1,
            get = function()
              return Clamp(settings.height or 15, 6, 40)
            end,
            set = function(_, value)
              settings.height = Clamp(value, 6, 40)
              Addon:ApplyOptionsChange("PRD", { secondaryLayout = true })
            end,
          },
          width = {
            type = "range",
            name = "Detached width",
            desc = "Used only while this resource is detached.",
            order = 3,
            min = 120,
            max = 600,
            step = 1,
            disabled = function()
              return settings.detached ~= true
            end,
            get = function()
              return Clamp(settings.width or 240, 120, 600)
            end,
            set = function(_, value)
              settings.width = Clamp(value, 120, 600)
              Addon:ApplyOptionsChange("PRD", { secondaryLayout = true })
              FrameUtil.RefreshSmartSnapState("PRD_SECONDARY_" .. resource.key)
            end,
          },
          point = {
            type = "select",
            name = "Anchor point",
            order = 4,
            values = RESOURCE_ANCHOR_VALUES,
            disabled = function()
              return settings.detached ~= true
            end,
            get = function()
              return anchor.point or "CENTER"
            end,
            set = function(_, value)
              anchor.point = value or "CENTER"
              Addon:ApplyOptionsChange("PRD", { secondaryLayout = true })
            end,
          },
          x = {
            type = "range",
            name = "X position",
            order = 5,
            min = -2000,
            max = 2000,
            step = 1,
            disabled = function()
              return settings.detached ~= true
            end,
            get = function()
              return Clamp(anchor.x or 0, -2000, 2000)
            end,
            set = function(_, value)
              anchor.x = Clamp(value, -2000, 2000)
              Addon:ApplyOptionsChange("PRD", { secondaryLayout = true })
            end,
          },
          y = {
            type = "range",
            name = "Y position",
            order = 6,
            min = -2000,
            max = 2000,
            step = 1,
            disabled = function()
              return settings.detached ~= true
            end,
            get = function()
              return Clamp(anchor.y or 0, -2000, 2000)
            end,
            set = function(_, value)
              anchor.y = Clamp(value, -2000, 2000)
              Addon:ApplyOptionsChange("PRD", { secondaryLayout = true })
            end,
          },
        },
      },
      display = {
        type = "group",
        name = "Display",
        order = 15,
        inline = true,
        args = {
          segmentedMode = {
            type = "toggle",
            name = "Use segmented mode",
            order = 1,
            get = function()
              return settings.perSegment == true
            end,
            set = function(_, value)
              settings.perSegment = value and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryRebuild = true, secondaryText = true, layout = true })
            end,
          },
          showApplicationsRemaining = {
            type = "toggle",
            name = "Show casts remaining",
            desc = "Shows 3, 2, 1, then 0 while Shining Light is ready.",
            order = 1.5,
            hidden = applicationCountdownMax == nil,
            get = function()
              return settings.showApplicationsRemaining == true
            end,
            set = function(_, value)
              settings.showApplicationsRemaining = value and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          showDividers = {
            type = "toggle",
            name = "Show tick separators",
            desc = "Draws separators for each possible stack or resource point.",
            order = 2,
            get = function()
              return settings.showDividers ~= false
            end,
            set = function(_, value)
              settings.showDividers = value and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          stackTickValues = {
            type = "input",
            name = "Stack ticks",
            desc = "Use All for every stack, or enter specific stack values separated by commas.",
            order = 2.5,
            hidden = resource.category ~= "TRACKED_EFFECT",
            disabled = function()
              return settings.showDividers == false
            end,
            get = function()
              return settings.stackTickValues or "ALL"
            end,
            set = function(_, value)
              settings.stackTickValues = value ~= "" and value or "ALL"
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          dividerSize = {
            type = "range",
            name = "Tick thickness",
            order = 3,
            min = 1,
            max = 6,
            step = 1,
            disabled = function()
              return settings.showDividers == false
            end,
            get = function()
              return Clamp(settings.dividerSize or 1, 1, 6)
            end,
            set = function(_, value)
              settings.dividerSize = Clamp(value, 1, 6)
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          dividerColor = {
            type = "color",
            name = "Tick color",
            order = 4,
            hasAlpha = true,
            disabled = function()
              return settings.showDividers == false
            end,
            get = function()
              local color = settings.dividerColor
              return color[1], color[2], color[3], color[4]
            end,
            set = function(_, r, g, b, a)
              settings.dividerColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          inactiveAlpha = {
            type = "range",
            name = "Inactive segment opacity",
            order = 5,
            min = 0,
            max = 1,
            step = 0.05,
            isPercent = true,
            get = function()
              return Clamp(settings.inactiveAlpha or 0.15, 0, 1)
            end,
            set = function(_, value)
              settings.inactiveAlpha = Clamp(value, 0, 1)
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          showSpellIcon = {
            type = "toggle",
            name = "Show spell icon",
            order = 6,
            hidden = resource.category ~= "TRACKED_EFFECT",
            get = function()
              return settings.showSpellIcon == true
            end,
            set = function(_, value)
              settings.showSpellIcon = value and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryLayout = true })
            end,
          },
          iconGap = {
            type = "range",
            name = "Icon gap",
            order = 7,
            min = 0,
            max = 20,
            step = 1,
            hidden = resource.category ~= "TRACKED_EFFECT",
            disabled = function()
              return settings.showSpellIcon ~= true
            end,
            get = function()
              return Clamp(settings.iconGap or 2, 0, 20)
            end,
            set = function(_, value)
              settings.iconGap = Clamp(value, 0, 20)
              Addon:ApplyOptionsChange("PRD", { secondaryLayout = true })
            end,
          },
        },
      },
      resourceColor = {
        type = "group",
        name = "Bar color",
        order = 18,
        inline = true,
        hidden = resource.category ~= "TRACKED_EFFECT",
        args = {
          colorMode = {
            type = "select",
            name = "Status bar color",
            order = 1,
            values = RESOURCE_COLOR_VALUES,
            get = function()
              return PRD_GetResourceColorMode(settings)
            end,
            set = function(_, value)
              PRD_SetResourceColorMode(settings, value or "DEFAULT")
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          customColor = {
            type = "color",
            name = "Custom color",
            order = 2,
            hasAlpha = true,
            disabled = function()
              return PRD_GetResourceColorMode(settings) ~= "CUSTOM"
            end,
            get = function()
              local color = settings.customColor or { 1, 1, 1, 1 }
              return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
            end,
            set = function(_, r, g, b, a)
              settings.customColor = { r, g, b, a }
              PRD_SetResourceColorMode(settings, "CUSTOM")
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          stackColorShifts = {
            type = "group",
            name = "Stack color shifts",
            order = 3,
            inline = true,
            hidden = stackColorThresholds == nil,
            args = BuildStackColorThresholdArgs(),
          },
        },
      },
      freezingCdmNotice = {
        type = "description",
        name = "Stack recoloring requires Freezing to be tracked in Blizzard's Buff Icon Cooldown Manager.",
        order = 19,
        hidden = resource.key ~= "FREEZING" or not freezingRecoloringEnabled,
      },
      appearance = {
        type = "group",
        name = "Appearance",
        order = 20,
        inline = true,
        hidden = function()
          return state.appearance.unified ~= false or AppearanceDisabled()
        end,
        disabled = AppearanceDisabled,
        args = {
          texture = {
            type = "select",
            dialogControl = "LSM30_Statusbar",
            name = "Texture",
            order = 1,
            values = function()
              return OptionsUtil.BuildStatusbarValues(false)
            end,
            get = function()
              return settings.texture
            end,
            set = function(_, value)
              settings.texture = value
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          colorMode = {
            type = "select",
            name = "Status bar color",
            order = 2,
            values = RESOURCE_COLOR_VALUES,
            hidden = resource.category == "TRACKED_EFFECT",
            get = function()
              return PRD_GetResourceColorMode(settings)
            end,
            set = function(_, value)
              PRD_SetResourceColorMode(settings, value or "DEFAULT")
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
          customColor = {
            type = "color",
            name = "Custom color",
            order = 3,
            hasAlpha = true,
            hidden = resource.category == "TRACKED_EFFECT",
            disabled = function()
              return PRD_GetResourceColorMode(settings) ~= "CUSTOM"
            end,
            get = function()
              local color = settings.customColor or { 1, 1, 1, 1 }
              return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
            end,
            set = function(_, r, g, b, a)
              settings.customColor = { r, g, b, a }
              PRD_SetResourceColorMode(settings, "CUSTOM")
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
        },
      },
      textGroup = {
        type = "group",
        name = "Text",
        order = 30,
        inline = true,
        hidden = function()
          return state.appearance.unified ~= false or AppearanceDisabled()
        end,
        disabled = AppearanceDisabled,
        args = {
          textMode = {
            type = "select",
            name = "Text format",
            order = 1,
            values = {
              CUR = "Show current #",
              BOTH = "Show current # / max #",
              CURP = "Show current # / %",
              PCT = "Show %",
              HIDE = "Hide",
            },
            get = function()
              return text.mode or "CUR"
            end,
            set = function(_, value)
              text.mode = value or "CUR"
              text.showNumber = value ~= "HIDE"
              Addon:ApplyOptionsChange("PRD", { secondaryText = true })
            end,
          },
          useGlobalFont = {
            type = "toggle",
            name = "Use global font",
            order = 2,
            get = function()
              return PRD_UseGlobalFont(text)
            end,
            set = function(_, value)
              text.useGlobalFont = value and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryText = true })
            end,
          },
          font = {
            type = "select",
            dialogControl = "LSM30_Font",
            name = "Font",
            order = 3,
            values = OptionsUtil.BuildFontValues,
            disabled = function()
              return AppearanceDisabled() or PRD_UseGlobalFont(text)
            end,
            get = function()
              return OptionsUtil.ResolveFontKey(text.font, text.useGlobalFont)
            end,
            set = function(_, value)
              text.font = value
              text.useGlobalFont = false
              Addon:ApplyOptionsChange("PRD", { secondaryText = true })
            end,
          },
          fontSize = {
            type = "range",
            name = "Font size",
            order = 4,
            min = 8,
            max = 32,
            step = 1,
            get = function()
              return Clamp(text.size or 14, 8, 32)
            end,
            set = function(_, value)
              text.size = Clamp(value, 8, 32)
              Addon:ApplyOptionsChange("PRD", { secondaryText = true })
            end,
          },
          fontFlags = {
            type = "select",
            name = "Font outline",
            order = 5,
            values = function()
              return OptionsUtil.BuildOutlineValues(true, "Use global outline", ns.Theme.STANDARD_OUTLINE_KEY)
            end,
            get = function()
              return OptionsUtil.GetStoredOutlineValue(text.flags, ns.Theme.STANDARD_OUTLINE_KEY)
            end,
            set = function(_, value)
              text.flags = OptionsUtil.SetStoredOutlineValue(value, ns.Theme.STANDARD_OUTLINE_KEY)
              Addon:ApplyOptionsChange("PRD", { secondaryText = true })
            end,
          },
        },
      },
      styleGroup = {
        type = "group",
        name = "Frame style",
        order = 50,
        inline = true,
        hidden = function()
          return state.appearance.unified ~= false or AppearanceDisabled()
        end,
        disabled = AppearanceDisabled,
        args = {
          borderSize = {
            type = "range",
            name = "Border size",
            order = 1,
            min = 0,
            max = 12,
            step = 1,
            get = function()
              return Clamp(style.borderSize or 1, 0, 12)
            end,
            set = function(_, value)
              style.borderSize = Clamp(value, 0, 12)
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          borderColor = {
            type = "color",
            name = "Border color",
            order = 2,
            hasAlpha = true,
            get = function()
              local color = style.borderColor or { 0.20, 0.20, 0.24, 1 }
              return color[1] or 0.20, color[2] or 0.20, color[3] or 0.24, color[4] or 1
            end,
            set = function(_, r, g, b, a)
              style.borderColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          bgColor = {
            type = "color",
            name = "Background color",
            order = 3,
            hasAlpha = true,
            get = function()
              local color = style.bgColor or { 0, 0, 0, 0.65 }
              return color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 0.65
            end,
            set = function(_, r, g, b, a)
              style.bgColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
        },
      },
      cueGroup = {
        type = "group",
        name = "Spend cues",
        order = 60,
        inline = true,
        args = {
          desaturateMode = {
            type = "select",
            name = "Desaturate",
            order = 2,
            values = RESOURCE_THRESHOLD_VALUES,
            hidden = function()
              return not supportsNumericCues
            end,
            get = function()
              return cues.desaturateMode or "NONE"
            end,
            set = function(_, value)
              cues.desaturateMode = value or "NONE"
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
          desaturateThreshold = {
            type = "range",
            name = "Desaturate threshold",
            order = 3,
            min = 0,
            max = 50,
            step = 1,
            hidden = function()
              return not supportsNumericCues
            end,
            disabled = DesaturateThresholdDisabled,
            get = function()
              return Clamp(cues.desaturateThreshold or 0, 0, 50)
            end,
            set = function(_, value)
              cues.desaturateThreshold = Clamp(value, 0, 50)
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
          glowMode = {
            type = "select",
            name = "Threshold glow",
            order = 4,
            values = RESOURCE_THRESHOLD_VALUES,
            hidden = function()
              return not supportsNumericCues
            end,
            get = function()
              return cues.glowMode or "NONE"
            end,
            set = function(_, value)
              cues.glowMode = value or "NONE"
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
          glowThreshold = {
            type = "range",
            name = "Glow threshold",
            order = 5,
            min = 0,
            max = 50,
            step = 1,
            hidden = function()
              return not supportsNumericCues
            end,
            disabled = GlowThresholdDisabled,
            get = function()
              return Clamp(cues.glowThreshold or 0, 0, 50)
            end,
            set = function(_, value)
              cues.glowThreshold = Clamp(value, 0, 50)
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
          glowType = {
            type = "select",
            name = "Threshold glow style",
            order = 6,
            values = RESOURCE_GLOW_VALUES,
            hidden = function()
              return not supportsNumericCues
            end,
            disabled = GlowThresholdDisabled,
            get = function()
              return cues.glowType or "PIXEL"
            end,
            set = function(_, value)
              cues.glowType = value or "PIXEL"
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
          glowColor = {
            type = "color",
            name = "Threshold glow color",
            order = 7,
            hasAlpha = true,
            hidden = function()
              return not supportsNumericCues
            end,
            disabled = GlowThresholdDisabled,
            get = function()
              local color = cues.glowColor or { 1, 0.82, 0, 1 }
              return color[1] or 1, color[2] or 0.82, color[3] or 0, color[4] or 1
            end,
            set = function(_, r, g, b, a)
              cues.glowColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
          buffGlowSpellID = {
            type = "input",
            name = "Glow while buff is active",
            desc = "Enter a player buff spell ID. Use 0 to disable this cue.",
            order = 10,
            validate = function(_, value)
              local spellID = tonumber(value)
              if spellID and spellID >= 0 and spellID == math.floor(spellID) then
                return true
              end
              return "Enter a whole spell ID or 0."
            end,
            get = function()
              return tostring(cues.buffGlowSpellID or 0)
            end,
            set = function(_, value)
              cues.buffGlowSpellID = math.floor(Clamp(value, 0, 99999999))
              Addon:ApplyOptionsChange("PRD", { secondaryCues = true })
            end,
          },
          buffGlowColor = {
            type = "color",
            name = "Buff glow color",
            order = 11,
            hasAlpha = true,
            disabled = BuffGlowDisabled,
            get = function()
              local color = cues.buffGlowColor or { 0.25, 0.75, 1, 1 }
              return color[1] or 0.25, color[2] or 0.75, color[3] or 1, color[4] or 1
            end,
            set = function(_, r, g, b, a)
              cues.buffGlowColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { secondaryCues = true })
            end,
          },
        },
      },
      formOverridesGroup = PRD_BuildDruidPrimaryFormArgs(s),
    }
  end

  local function PRD_BuildSecondaryArgs()
    local s = GetPRDState()
    if not s then
      return {
        unavailable = {
          type = "description",
          name = "Personal Resource Display module is not loaded or has no profile data yet.",
          order = 1,
          fontSize = "medium",
        },
      }
    end

    local cfg = s.secondaryCfg
    local text = s.secondaryTextCfg
    cfg.resourceEnabled = cfg.resourceEnabled or {}

    local classResourceArgs = {}
    local trackedEffectArgs = {}
    local classResourceCount = 0
    local trackedEffectCount = 0
    local resourceOptions = ns.PRDSecondary:GetResourceOptionsForClass(PLAYER_CLASS) or {}
    local useResourceTabs = PRD_UsesSecondaryResourceTabs(resourceOptions)

    for i = 1, #resourceOptions do
      local resource = resourceOptions[i]
      local targetArgs
      local order

      if resource.category == "TRACKED_EFFECT" then
        trackedEffectCount = trackedEffectCount + 1
        targetArgs = trackedEffectArgs
        order = trackedEffectCount
      else
        classResourceCount = classResourceCount + 1
        targetArgs = classResourceArgs
        order = classResourceCount
      end

      targetArgs[resource.key] = {
        type = "group",
        name = resource.name,
        order = order,
        inline = true,
        args = PRD_BuildResourceLayoutArgs(s, resource),
      }
    end

    local args = {
      visibilityGroup = {
        type = "group",
        name = "Overview",
        order = 10,
        inline = true,
        args = {
          summary = {
            type = "description",
            name = "Controls class resources and tracked effects shown below the Personal Resource Display.",
            order = 1,
          },
          enabled = {
            type = "toggle",
            name = "Enable secondary displays",
            desc = "Enables the secondary displays available to your current specialization.",
            order = 2,
            get = function()
              return cfg.enabled ~= false
            end,
            set = function(_, value)
              cfg.enabled = value and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryRebuild = true, secondaryText = true, layout = true })
            end,
          },
          visibilityMode = {
            type = "select",
            name = "Show secondary displays",
            order = 3,
            values = {
              ALWAYS = "Always",
              COMBAT = "In combat",
              TARGET = "When you have a target",
              COMBAT_OR_TARGET = "In combat or with a target",
            },
            get = function()
              return cfg.visibilityMode or "ALWAYS"
            end,
            set = function(_, value)
              cfg.visibilityMode = value or "ALWAYS"
              Addon:ApplyOptionsChange("PRD", { secondaryVisibility = true })
            end,
          },
        },
      },
      classResourcesGroup = {
        type = "group",
        name = "Class resources",
        order = 20,
        inline = true,
        hidden = classResourceCount == 0,
        args = classResourceArgs,
      },
      trackedEffectsGroup = {
        type = "group",
        name = "Tracked effects",
        order = 30,
        inline = true,
        hidden = trackedEffectCount == 0,
        args = trackedEffectArgs,
      },
      layoutGroup = {
        type = "group",
        name = "Shared appearance",
        order = 40,
        inline = true,
        args = {
          sharedInfo = {
            type = "description",
            name = "Resources that use the shared secondary appearance inherit these settings. Width, detach state, and position remain specific to each resource.",
            order = 1,
          },
          height = {
            type = "range",
            name = "Height",
            order = 2,
            min = 6,
            max = 40,
            step = 1,
            hidden = function()
              return s.appearance.unified ~= false
            end,
            get = function()
              return Clamp(cfg.height or 15, 6, 40)
            end,
            set = function(_, value)
              cfg.height = Clamp(value, 6, 40)
              Addon:ApplyOptionsChange("PRD", { secondaryLayout = true })
            end,
          },
          resourceGap = {
            type = "range",
            name = "Multiple resource gap",
            desc = "Spacing between simultaneous secondary-resource rows, such as Icicles and Freezing.",
            order = 3,
            min = 0,
            max = 20,
            step = 1,
            get = function()
              return Clamp(cfg.gap or 2, 0, 20)
            end,
            set = function(_, value)
              cfg.gap = Clamp(value, 0, 20)
              Addon:ApplyOptionsChange("PRD", { secondaryLayout = true })
            end,
          },
          texture = {
            type = "select",
            dialogControl = "LSM30_Statusbar",
            name = "Texture",
            order = 5,
            hidden = function()
              return s.appearance.unified ~= false
            end,
            values = function()
              return OptionsUtil.BuildStatusbarValues(false)
            end,
            get = function()
              return cfg.texture
            end,
            set = function(_, key)
              cfg.texture = key
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
        },
      },
      textGroup = {
        type = "group",
        name = "Secondary resource text",
        order = 15,
        inline = true,
        args = {
          textMode = {
            type = "select",
            name = "Resource number",
            desc = "Controls the current resource number shown on class-resource bars, including Essence. Choose Hide to disable it.",
            order = 1,
            values = {
              CUR = "Show current #",
              BOTH = "Show current # / max #",
              CURP = "Show current # / %",
              PCT = "Show %",
              HIDE = "Hide",
            },
            get = function()
              return text.mode or "CUR"
            end,
            set = function(_, key)
              text.mode = key or "CUR"
              text.showNumber = key ~= "HIDE"
              Addon:ApplyOptionsChange("PRD", { secondaryText = true })
            end,
          },
          useGlobalFont = {
            type = "toggle",
            name = "Use global font",
            order = 2,
            hidden = function()
              return s.appearance.unified ~= false
            end,
            get = function()
              return PRD_UseGlobalFont(text)
            end,
            set = function(_, value)
              text.useGlobalFont = value and true or false
              Addon:ApplyOptionsChange("PRD", { secondaryText = true })
            end,
          },
          font = {
            type = "select",
            dialogControl = "LSM30_Font",
            name = "Font",
            order = 3,
            hidden = function()
              return s.appearance.unified ~= false
            end,
            values = OptionsUtil.BuildFontValues,
            disabled = function()
              return PRD_UseGlobalFont(text)
            end,
            get = function()
              return OptionsUtil.ResolveFontKey(text.font, text.useGlobalFont)
            end,
            set = function(_, key)
              text.font = key
              text.useGlobalFont = false
              Addon:ApplyOptionsChange("PRD", { secondaryText = true })
            end,
          },
          fontSize = {
            type = "range",
            name = "Font size",
            order = 4,
            hidden = function()
              return s.appearance.unified ~= false
            end,
            min = 8,
            max = 32,
            step = 1,
            get = function()
              return Clamp(text.size or 14, 8, 32)
            end,
            set = function(_, value)
              text.size = Clamp(value, 8, 32)
              Addon:ApplyOptionsChange("PRD", { secondaryText = true })
            end,
          },
          fontFlags = {
            type = "select",
            name = "Font outline",
            order = 5,
            hidden = function()
              return s.appearance.unified ~= false
            end,
            values = function()
              return OptionsUtil.BuildOutlineValues(true, "Use global outline", ns.Theme.STANDARD_OUTLINE_KEY)
            end,
            get = function()
              return OptionsUtil.GetStoredOutlineValue(text.flags, ns.Theme.STANDARD_OUTLINE_KEY)
            end,
            set = function(_, key)
              text.flags = OptionsUtil.SetStoredOutlineValue(key, ns.Theme.STANDARD_OUTLINE_KEY)
              Addon:ApplyOptionsChange("PRD", { secondaryText = true })
            end,
          },
        },
      },
      colorGroup = {
        type = "group",
        name = "Bar color",
        order = 60,
        inline = true,
        args = {
          colorMode = {
            type = "select",
            name = "Status bar color",
            order = 1,
            values = RESOURCE_COLOR_VALUES,
            get = function()
              return PRD_GetResourceColorMode(cfg)
            end,
            set = function(_, value)
              PRD_SetResourceColorMode(cfg, value or "DEFAULT")
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
          customColor = {
            type = "color",
            name = "Custom color",
            order = 2,
            hasAlpha = true,
            disabled = function()
              return PRD_GetResourceColorMode(cfg) ~= "CUSTOM"
            end,
            get = function()
              local color = cfg.customColor or { 1, 1, 1, 1 }
              return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
            end,
            set = function(_, r, g, b, a)
              cfg.customColor = { r, g, b, a }
              PRD_SetResourceColorMode(cfg, "CUSTOM")
              Addon:ApplyOptionsChange("PRD", { secondaryUpdate = true })
            end,
          },
        },
      },
      styleGroup = {
        type = "group",
        name = "Frame style",
        order = 70,
        inline = true,
        hidden = function()
          return s.appearance.unified ~= false
        end,
        args = {
          borderSize = {
            type = "range",
            name = "Border size",
            order = 1,
            min = 0,
            max = 12,
            step = 1,
            get = function()
              return Clamp(cfg.style.borderSize or 1, 0, 12)
            end,
            set = function(_, value)
              cfg.style.borderSize = Clamp(value, 0, 12)
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          borderColor = {
            type = "color",
            name = "Border color",
            order = 2,
            hasAlpha = true,
            get = function()
              local color = cfg.style.borderColor or { 0.20, 0.20, 0.24, 1.00 }
              return color[1] or 0.20, color[2] or 0.20, color[3] or 0.24, color[4] or 1
            end,
            set = function(_, r, g, b, a)
              cfg.style.borderColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
          bgColor = {
            type = "color",
            name = "Background color",
            order = 3,
            hasAlpha = true,
            get = function()
              local color = cfg.style.bgColor or { 0, 0, 0, 0.65 }
              return color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 0.65
            end,
            set = function(_, r, g, b, a)
              cfg.style.bgColor = { r, g, b, a }
              Addon:ApplyOptionsChange("PRD", { secondaryAppearance = true })
            end,
          },
        },
      },
    }

    if not useResourceTabs then
      return args
    end

    args.visibilityGroup.order = 0
    args.layoutGroup.order = 70
    args.textGroup.order = 80
    args.textGroup.name = "Shared secondary text"
    args.colorGroup.order = 90
    args.colorGroup.name = "Shared bar color"
    args.styleGroup.order = 100
    args.styleGroup.name = "Shared frame style"

    local tabArgs = {}

    for i = 1, #resourceOptions do
      local resource = resourceOptions[i]
      local sourceGroup = resource.category == "TRACKED_EFFECT"
        and trackedEffectArgs[resource.key]
        or classResourceArgs[resource.key]
      local resourceArgs = sourceGroup.args

      resourceArgs.secondaryOverviewGroup = args.visibilityGroup
      resourceArgs.sharedSecondaryLayoutGroup = args.layoutGroup
      resourceArgs.sharedSecondaryTextGroup = args.textGroup
      resourceArgs.sharedSecondaryStyleGroup = args.styleGroup

      if resource.category ~= "TRACKED_EFFECT" then
        resourceArgs.sharedSecondaryColorGroup = args.colorGroup
      end

      tabArgs[resource.key] = {
        type = "group",
        name = resource.name,
        order = i,
        args = resourceArgs,
      }
    end

    return tabArgs
  end

  local function PRDRootProvider()
    local provider = {}

    function provider:GetOptions()
      local options = {
        type = "group",
        name = "Personal Resource Display",
        childGroups = "tab",
        args = {
          general = {
            type = "group",
            name = "General",
            order = 1,
            args = PRD_BuildGeneralArgs(),
          },
          health = {
            type = "group",
            name = "Health",
            order = 2,
            args = PRD_BuildHealthArgs(),
          },
          primary = {
            type = "group",
            name = "Primary",
            order = 3,
            args = PRD_BuildPrimaryArgs(),
          },
          secondary = {
            type = "group",
            name = "Secondary",
            order = 4,
            childGroups = PRD_UsesSecondaryResourceTabs() and "tab" or nil,
            hidden = function()
              return not ns.PRDSecondary:HasResourceForCurrentSpec()
            end,
            args = PRD_BuildSecondaryArgs(),
          },
        },
      }

      return options
    end

    return provider
  end

  ns.PRDPreview.Build = P:Def("Preview.Build", ns.PRDPreview.Build)
  Addon:RegisterOptionsSection("PRD", function()
    return PRDRootProvider()
  end, 40, "Personal Resource Display", nil, {
    navDescription = "Health, power, class resources, and text.",
    pageTitle = "Personal Resource Display",
    pageDescription = "Configure your personal resource display, including health, primary power, and class-specific resources.",
    pageHelp = "Tune the layout first, then refine resource behavior and text.",
    page = {
      previewWidth = 360,
      previewHeight = 280,
      previewAlwaysShown = true,
      buildPreview = ns.PRDPreview.Build,
    },
  })
end

  Clamp = P:Def("Clamp", Clamp)
  ns.Modules.PRD.EnsurePrimaryResourceSettings = P:Def(
    "EnsurePrimaryResourceSettings",
    ns.Modules.PRD.EnsurePrimaryResourceSettings
  )
  ns.Modules.PRD.NormalizeProfile = P:Def(
    "NormalizeProfile",
    ns.Modules.PRD.NormalizeProfile
  )
  ns.PRDPreview.MarkDirty = P:Def("Preview.MarkDirty", ns.PRDPreview.MarkDirty)
