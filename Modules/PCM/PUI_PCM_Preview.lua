local ADDON_NAME, ns = ...

local PCMPreview = {}
ns.PCMPreview = PCMPreview

local _G = _G
local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local C_Spell = _G.C_Spell
local InCombatLockdown = _G.InCombatLockdown
local issecretvalue = _G.issecretvalue
local UnitClass = _G.UnitClass
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local setmetatable = _G.setmetatable
local ipairs = _G.ipairs
local pairs = _G.pairs
local select = _G.select
local table_sort = _G.table.sort
local string_format = _G.string.format
local string_lower = _G.string.lower
local tostring = _G.tostring
local tonumber = _G.tonumber
local type = _G.type
local math_ceil = _G.math.ceil
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min

local Addon = ns.Addon
local Theme = ns.Theme
local PreviewBox = ns.PreviewBox
local BarWidget = ns.BarWidget
local Presentation = ns.Presentation
local PCMPresentation = ns.PCMPresentation
local IconSkin = ns.IconSkin
local IconSettings = ns.PCMIconSettings
local Round = ns.Pixel.Round
local DB = ns.PCM_DBExports
local Cooldowns = ns.Modules.CooldownManager
local BuffBars = ns.Modules.PCM_BB
local _, PLAYER_CLASS = UnitClass("player")
local PLAYER_CLASS_COLOR = RAID_CLASS_COLORS[PLAYER_CLASS]
local PCMPreviewBoxes = setmetatable({}, { __mode = "k" })

local P = select(1, ns.Pleebug:DropIn(PCMPreview, {
  name = "PCM",
  bucket = "Preview",
}))

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local FALLBACK_BAR_TEXTURE = Theme.GetBarTexture()

local VIEWERS = {
  {
    key = "EssentialCooldownViewer",
    tab = "cooldowns_essential",
    title = "Essential",
    accent = { 0.95, 0.68, 0.20, 1 },
  },
  {
    key = "UtilityCooldownViewer",
    tab = "cooldowns_utility",
    title = "Utility",
    accent = { 0.28, 0.67, 0.95, 1 },
  },
}

local PREVIEW_PANEL_BY_TAB = {
  cooldowns_essential = "essential",
  cooldowns_utility = "utility",
  consumables = "consumables",
  buff_icons = "buffs",
  buff_bars = "buffBars",
  custom_bars = "custom",
}

local function PCMPreview_Clamp(value, minimum, maximum)
  value = tonumber(value) or minimum

  if value < minimum then
    return minimum
  end

  if value > maximum then
    return maximum
  end

  return value
end

local function PCMPreview_GetDisplayScale(panel)
  local zoom = PCMPreview_Clamp(
    panel and panel.__puiPCMPreviewZoom or 1,
    0.25,
    2
  )

  return zoom / Theme.GetOptionsUIScale()
end

local function PCMPreview_ColorComponents(color, fallback)
  fallback = fallback or { 1, 1, 1, 1 }

  if type(color) ~= "table" then
    return fallback[1], fallback[2], fallback[3], fallback[4]
  end

  return color.r or color[1] or fallback[1],
    color.g or color[2] or fallback[2],
    color.b or color[3] or fallback[3],
    color.a or color[4] or fallback[4]
end

local function PCMPreview_GetSafeSpellTexture(spellID)
  local texture = C_Spell.GetSpellTexture(spellID)

  if issecretvalue(texture) then
    return nil
  end

  if type(texture) == "number" or type(texture) == "string" then
    return texture
  end

  return nil
end

local function PCMPreview_GetFontConfig(root, viewerKey, role)
  local fonts = type(root) == "table" and root.fonts or nil
  local global = fonts and fonts.global or nil
  local viewers = fonts and fonts.viewers or nil
  local viewer = viewers and viewers[viewerKey] or nil
  local config = viewer and viewer[role] or nil

  if type(config) ~= "table" then
    config = global and global[role] or nil
  end

  return type(config) == "table" and config or {}
end

local function PCMPreview_ApplyFont(fontString, config, role, fallbackSize, zoom)
  local size = PCMPreview_Clamp(
    (config and config.size or fallbackSize) * (tonumber(zoom) or 1),
    4,
    96
  )
  local font = config and config.font
  local flags = config and config.flags

  if type(font) == "string" and font ~= "" then
    local path = ns.LSM:Fetch("font", font, true)

    if path then
      fontString:SetFont(path, size, flags or "OUTLINE")
    else
      Theme.ApplyFont(fontString, role, size, flags or "OUTLINE")
    end
  else
    Theme.ApplyFont(fontString, role, size, flags or "OUTLINE")
  end

  local r, g, b, a = PCMPreview_ColorComponents(
    config and config.color,
    { 1, 1, 1, 1 }
  )

  fontString:SetTextColor(r, g, b, a)
end

local function PCMPreview_ApplyBackdrop(frame, background, border, thickness)
  Theme.SetSquareBackdrop(frame, {
    bg = background,
    border = border,
  }, PCMPreview_Clamp(thickness or Theme.GetEdgeSize(), 1, 6))
end

local function PCMPreview_Navigate(box, path, sectionKey, optionKey)
  PreviewBox.NavigateToOption(
    box.__puiPCMPreviewAddon or Addon,
    path,
    sectionKey,
    optionKey
  )
end

local function PCMPreview_SetInteraction(
  interaction,
  title,
  description,
  path,
  sectionKey,
  optionKey,
  beforeNavigate
)
  interaction:SetPreviewInteractionOptions({
    title = title,
    description = description,
    onClick = function()
      if beforeNavigate then
        beforeNavigate()
      end
      PCMPreview_Navigate(
        interaction.__puiPCMPreviewBox,
        path,
        sectionKey,
        optionKey
      )
    end,
  })
end

local function PCMPreview_CreateInteraction(box, parent, anchor, frameLevel)
  local interaction = PreviewBox.CreateInteraction(parent, anchor, {
    frameLevel = frameLevel,
  })

  interaction.__puiPCMPreviewBox = box
  return interaction
end



local function PCMPreview_CreatePanel(box, canvas, key, title)
  local colors = Theme.GetColors()
  local panel = CreateFrame("Frame", nil, canvas)
  local titleText = panel:CreateFontString(nil, "OVERLAY")
  local content = CreateFrame("Frame", nil, panel)

  panel:SetFrameLevel(canvas:GetFrameLevel() + 5)
  PCMPreview_ApplyBackdrop(
    panel,
    { colors.background[1], colors.background[2], colors.background[3], 0.96 },
    colors.border,
    Theme.GetEdgeSize()
  )

  local zoomControl = PreviewBox.CreateZoomControl(panel, {
    width = 220,
    height = 14,
    sliderWidth = 128,
    sliderHeight = 14,
    gap = 8,
    fontSize = 9,
    frameLevel = panel:GetFrameLevel() + 40,
    onValueChanged = function(_, zoom)
      panel.__puiPCMPreviewZoom = zoom
      box.__puiPCMPreviewState.pcmZooms[key] = zoom
      PCMPreview.RefreshBox(box)
    end,
  })
  zoomControl:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -6)

  titleText:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -6)
  titleText:SetPoint("TOPRIGHT", zoomControl, "TOPLEFT", -6, 0)
  titleText:SetJustifyH("LEFT")
  Theme.ApplyFont(titleText, "header", 10, "OUTLINE")
  titleText:SetText(title)

  content:SetPoint("TOPLEFT", panel, "TOPLEFT", 7, -22)
  content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -7, 7)
  content:SetFrameLevel(panel:GetFrameLevel() + 2)
  content:SetClipsChildren(true)

  panel.__puiPCMPreviewKey = key
  panel.__puiPCMPreviewZoom = 1
  panel.__puiPCMPreviewZoomControl = zoomControl
  panel.__puiPCMPreviewTitle = titleText
  panel.__puiPCMPreviewContent = content

  return panel
end

local function PCMPreview_CreateIcon(box, parent)
  local icon = Presentation.Create("PCMIcon", parent)
  local frame = icon.frame

  frame:SetFrameLevel(parent:GetFrameLevel() + 4)

  Presentation.Apply("PCMIcon", icon, {
    size = 36,
    inset = 2,
    backgroundColor = { 0.03, 0.03, 0.04, 1 },
    borderColor = { 0.10, 0.10, 0.12, 1 },
    borderSize = 2,
    cooldownFont = { size = 11, flags = "OUTLINE" },
    chargeFont = { size = 10, flags = "OUTLINE" },
    keybindFont = { size = 8, flags = "OUTLINE" },
  }, {
    icon = WHITE_TEXTURE,
  })

  icon.interactions = {
    body = PCMPreview_CreateInteraction(
      box,
      frame,
      frame,
      frame:GetFrameLevel() + 30
    ),
  }

  icon.selection = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  icon.selection:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)
  icon.selection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
  icon.selection:SetFrameLevel(frame:GetFrameLevel() + 25)
  icon.selection:EnableMouse(false)
  PCMPreview_ApplyBackdrop(
    icon.selection,
    { 0, 0, 0, 0 },
    { 0.95, 0.68, 0.20, 1 },
    2
  )
  icon.selection:Hide()

  return icon
end

local function PCMPreview_EnsureIconCount(box, panel, count)
  local icons = panel.__puiPCMPreviewIcons
  count = math_max(0, math_floor(tonumber(count) or 0))

  for index = #icons + 1, count do
    icons[index] = PCMPreview_CreateIcon(
      box,
      panel.__puiPCMPreviewContent
    )
  end

  panel.__puiPCMPreviewVisibleIconCount = count

  for index = count + 1, #icons do
    icons[index].frame:Hide()
    icons[index].selection:Hide()
    if icons[index].customLabel then
      icons[index].customLabel:Hide()
    end
    if icons[index].customStrip then
      icons[index].customStrip:Hide()
    end
  end
end

local function PCMPreview_CreateBar(parent)
  local bar = Presentation.Create("PCMBar", parent, {
    kind = "preview",
  })
  local frame = bar.frame

  frame:SetFrameLevel(parent:GetFrameLevel() + 4)
  bar.valueTextFrame:SetFrameLevel(frame:GetFrameLevel() + 20)

  local chargePresentation = Presentation.Create("PCMBar", frame, {
    template = "charge",
  })
  chargePresentation.frame:ClearAllPoints()
  chargePresentation.frame:SetAllPoints(frame)
  chargePresentation.frame:SetFrameLevel(frame:GetFrameLevel() + 1)
  chargePresentation.frame:Hide()

  local customGlowFrame = CreateFrame("Frame", nil, frame)
  customGlowFrame:SetAllPoints(frame)
  customGlowFrame:SetFrameLevel(frame:GetFrameLevel() + 6)
  customGlowFrame:EnableMouse(false)
  customGlowFrame:Hide()
  local customGlowBorder = PCMPresentation.CreateCustomBarBuffGlowBorder(
    customGlowFrame
  )

  local durationFrame = CreateFrame("Frame", nil, parent)
  local durationStatus = CreateFrame("StatusBar", nil, durationFrame)
  local durationValueTextFrame = CreateFrame("Frame", nil, durationFrame)
  local durationValueText = durationValueTextFrame:CreateFontString(nil, "OVERLAY")
  local durationIconFrame = CreateFrame("Frame", nil, parent)
  local durationIcon = durationIconFrame:CreateTexture(nil, "ARTWORK")
  local durationCooldown = CreateFrame(
    "Cooldown",
    nil,
    durationIconFrame,
    "CooldownFrameTemplate"
  )
  local durationIconText = durationIconFrame:CreateFontString(nil, "OVERLAY")

  durationFrame:SetFrameLevel(parent:GetFrameLevel() + 4)
  durationFrame:Hide()
  durationValueTextFrame:SetAllPoints(durationFrame)
  durationValueTextFrame:SetFrameLevel(durationFrame:GetFrameLevel() + 20)
  durationValueTextFrame:EnableMouse(false)
  PCMPreview_ApplyBackdrop(
    durationFrame,
    { 0.06, 0.06, 0.07, 0.95 },
    { 0.18, 0.18, 0.20, 1 },
    2
  )

  durationStatus:SetPoint("TOPLEFT", durationFrame, "TOPLEFT", 2, -2)
  durationStatus:SetPoint("BOTTOMRIGHT", durationFrame, "BOTTOMRIGHT", -2, 2)
  durationStatus:SetMinMaxValues(0, 1)
  durationStatus:SetValue(1)
  durationStatus:SetStatusBarTexture(FALLBACK_BAR_TEXTURE)
  durationStatus:SetFrameLevel(durationFrame:GetFrameLevel() + 1)

  durationValueText:SetPoint("CENTER", durationStatus, "CENTER", 0, 0)
  durationValueText:SetJustifyH("CENTER")
  Theme.ApplyFont(durationValueText, "tiny", 10, "OUTLINE")

  durationIconFrame:SetFrameLevel(parent:GetFrameLevel() + 4)
  durationIconFrame:Hide()
  PCMPreview_ApplyBackdrop(
    durationIconFrame,
    { 0.03, 0.03, 0.04, 1 },
    { 0.18, 0.18, 0.20, 1 },
    2
  )

  durationIcon:SetPoint("TOPLEFT", durationIconFrame, "TOPLEFT", 2, -2)
  durationIcon:SetPoint("BOTTOMRIGHT", durationIconFrame, "BOTTOMRIGHT", -2, 2)
  durationIcon:SetTexture(WHITE_TEXTURE)
  IconSkin.StripIconMasks(durationIcon)
  IconSkin.MakeIconSquare(durationIcon, { crop = 0.08 })

  durationCooldown:SetAllPoints(durationIcon)
  durationCooldown:SetDrawEdge(false)
  durationCooldown:SetDrawBling(false)
  durationCooldown:SetHideCountdownNumbers(true)
  durationCooldown:SetSwipeTexture(WHITE_TEXTURE)
  IconSkin.SquareCooldown(durationCooldown)

  durationIconText:SetPoint("CENTER", durationIconFrame, "CENTER", 0, 0)
  durationIconText:SetJustifyH("CENTER")
  Theme.ApplyFont(durationIconText, "tiny", 10, "OUTLINE")

  bar.chargePresentation = chargePresentation
  bar.chargeRoot = chargePresentation.slotsContainer
  bar.chargeSlots = chargePresentation.chargeSlots
  bar.customGlowFrame = customGlowFrame
  bar.customGlowBorder = customGlowBorder
  bar.durationFrame = durationFrame
  bar.durationStatus = durationStatus
  bar.durationValueText = durationValueText
  bar.durationIconFrame = durationIconFrame
  bar.durationIcon = durationIcon
  bar.durationCooldown = durationCooldown
  bar.durationIconText = durationIconText

  return bar
end

local function PCMPreview_EnsureBarCount(panel, count)
  local bars = panel.__puiPCMPreviewBars
  count = math_max(0, math_floor(tonumber(count) or 0))

  for index = #bars + 1, count do
    bars[index] = PCMPreview_CreateBar(
      panel.__puiPCMPreviewContent
    )
  end

  panel.__puiPCMPreviewVisibleBarCount = count

  for index = count + 1, #bars do
    local bar = bars[index]
    bar.frame:Hide()
    bar.durationFrame:Hide()
    bar.durationIconFrame:Hide()
  end
end

local function PCMPreview_GetViewerStyle(root, viewerKey, defaultWidth)
  local style = type(root) == "table" and root.style or {}
  local sizes = type(style.viewerSizes) == "table" and style.viewerSizes or {}
  local spacings = type(style.viewerSpacing) == "table" and style.viewerSpacing or {}
  local columns = type(style.viewerColumns) == "table" and style.viewerColumns or {}
  local growth = type(style.viewerGrowth) == "table" and style.viewerGrowth or {}
  local rowGrowth = type(style.viewerRowGrowth) == "table" and style.viewerRowGrowth or {}
  local widthModes = type(style.viewerWidthMode) == "table" and style.viewerWidthMode or {}
  local fixedWidths = type(style.viewerFixedWidth) == "table" and style.viewerFixedWidth or {}
  local columnCount = columns[viewerKey] or 0
  local growthMode = growth[viewerKey]
  local rowGrowthMode = rowGrowth[viewerKey] == "UP" and "UP" or "DOWN"
  local widthMode = widthModes[viewerKey] == "icon" and "icon" or "fixed"

  if viewerKey == "BuffIconCooldownViewer" then
    widthMode = "icon"
  end

  if growthMode ~= "RIGHT" and growthMode ~= "LEFT" then
    growthMode = "CENTER"
  end

  return {
    iconSize = PCMPreview_Clamp(sizes[viewerKey] or style.iconSize or 36, 12, 86),
    spacing = PCMPreview_Clamp(spacings[viewerKey] or style.iconSpacing or 2, 0, 8),
    columns = PCMPreview_Clamp(columnCount, 0, 40),
    growth = growthMode,
    rowGrowth = rowGrowthMode,
    widthMode = widthMode,
    fixedWidth = PCMPreview_Clamp(fixedWidths[viewerKey] or defaultWidth, 120, 1000),
  }
end

local function PCMPreview_GetViewerBorder(root, viewerKey)
  local borders = type(root) == "table" and root.borders or {}
  local viewerRoot = type(borders.viewer) == "table" and borders.viewer or {}
  local viewers = type(viewerRoot.viewers) == "table" and viewerRoot.viewers or {}
  local config = type(viewers[viewerKey]) == "table" and viewers[viewerKey] or {}

  return {
    enabled = config.enabled ~= false,
    thickness = PCMPreview_Clamp(config.thickness or 2, 0, 6),
    color = config.color or { 0.20, 0.20, 0.24, 1 },
  }
end

local function PCMPreview_GetIconBorder(root, viewerKey, buffIcon)
  local borders = type(root) == "table" and root.borders or {}
  local iconRoot = type(borders.icon) == "table" and borders.icon or {}
  local viewers = type(iconRoot.viewers) == "table" and iconRoot.viewers or {}
  local config = type(viewers[viewerKey]) == "table" and viewers[viewerKey] or {}

  if buffIcon then
    return {
      buff = config.buffColor or config.color or { 0, 0, 0, 1 },
      debuff = config.debuffColor or config.buffColor or config.color or { 0.65, 0.18, 0.18, 1 },
      pandemic = config.pandemicColor or config.buffColor or config.color or { 0.95, 0.45, 0.18, 1 },
    }
  end

  return config.color or { 0, 0, 0, 1 }
end

local function PCMPreview_GetViewerCounts(root, viewerKey)
  local counts = type(root) == "table" and root.count or {}
  local config = type(counts[viewerKey]) == "table" and counts[viewerKey] or {}

  return {
    cooldown = config.cooldown ~= false,
    buff = config.buff ~= false,
    charge = config.charge ~= false,
    keybind = config.keybind ~= false,
  }
end

local function PCMPreview_GetViewerSwipe(root, viewerKey)
  local swipes = type(root) == "table" and root.viewerSwipes or {}
  local config = type(swipes[viewerKey]) == "table" and swipes[viewerKey] or {}

  return {
    cooldown = config.cooldown ~= false,
    duration = config.duration ~= false,
    drawEdge = config.drawEdge ~= false,
    color = config.swipeColor or { 0, 0, 0, 0.8 },
  }
end

local function PCMPreview_GetEffectiveIconText(entry, role, viewerConfig)
  local record = IconSettings:GetRecordForEntry(entry, false)
  local override = record and record[role]
  if not override then
    return viewerConfig, nil
  end

  return {
    font = override.font ~= nil and override.font or viewerConfig.font,
    size = override.size ~= nil and override.size or viewerConfig.size,
    flags = override.flags ~= nil and override.flags or viewerConfig.flags,
    color = override.color ~= nil and override.color or viewerConfig.color,
    offsetX = override.offsetX ~= nil and override.offsetX or viewerConfig.offsetX,
    offsetY = override.offsetY ~= nil and override.offsetY or viewerConfig.offsetY,
  }, override.show
end

local function PCMPreview_GetEffectiveIconSwipe(entry, viewerSwipe)
  local record = IconSettings:GetRecordForEntry(entry, false)
  local override = record and record.swipe
  local drawEdge = viewerSwipe.drawEdge
  if override and override.drawEdge ~= nil then
    drawEdge = override.drawEdge
  end

  local show = viewerSwipe.cooldown
  if override and override.show ~= nil then
    show = override.show == true
  end

  return {
    show = show,
    color = override and override.color or viewerSwipe.color,
    drawEdge = drawEdge,
    reverse = override and override.reverse == true,
  }
end

local function PCMPreview_LayoutViewerIcons(panel, icons, config)
  local content = panel.__puiPCMPreviewContent
  local availableWidth = math_max(1, content:GetWidth())
  local availableHeight = math_max(1, content:GetHeight())
  local count = math_min(
    #icons,
    math_max(0, panel.__puiPCMPreviewVisibleIconCount or #icons)
  )

  if count <= 0 then
    return
  end

  local row1Count = math_floor(config.columns)

  if row1Count <= 0 then
    row1Count = count
  end

  row1Count = math_min(count, math_max(1, row1Count))

  local row2Count = math_max(0, count - row1Count)
  local row1ConfiguredSize = config.iconSize

  if config.widthMode == "fixed" then
    row1ConfiguredSize = (
      config.fixedWidth - (row1Count - 1) * config.spacing
    ) / row1Count

    local onePixel = ns.FrameScale:BestOnePixel()
    row1ConfiguredSize = math_floor(row1ConfiguredSize / onePixel) * onePixel
  end

  row1ConfiguredSize = math_max(1, row1ConfiguredSize)

  local row2ConfiguredSize = row1ConfiguredSize
  if row2Count > 0 and config.widthMode == "fixed" then
    local fittedRow2Size = (
      config.fixedWidth - (row2Count - 1) * config.spacing
    ) / row2Count

    row2ConfiguredSize = math_min(row1ConfiguredSize, fittedRow2Size)

    local onePixel = ns.FrameScale:BestOnePixel()
    row2ConfiguredSize = math_floor(row2ConfiguredSize / onePixel) * onePixel
    row2ConfiguredSize = math_max(1, row2ConfiguredSize)
  end

  local displayScale = PCMPreview_GetDisplayScale(panel)
  local row1Size = math_max(4, Round(row1ConfiguredSize * displayScale))
  local row2Size = math_max(4, Round(row2ConfiguredSize * displayScale))
  local spacing = Round(config.spacing * displayScale)

  local function GetRowPlacement(rowCount, iconSize)
    if rowCount <= 0 then
      return 0, 1
    end

    local rowWidth = rowCount * iconSize + (rowCount - 1) * spacing

    if config.growth == "RIGHT" then
      return Round((availableWidth - iconSize) * 0.5), 1
    elseif config.growth == "LEFT" then
      return Round((availableWidth - iconSize) * 0.5), -1
    end

    return Round((availableWidth - rowWidth) * 0.5), 1
  end

  local row1StartX, row1Direction = GetRowPlacement(row1Count, row1Size)
  local row2StartX, row2Direction = GetRowPlacement(row2Count, row2Size)
  local totalHeight = row1Size

  if row2Count > 0 then
    totalHeight = totalHeight + spacing + row2Size
  end

  local topY = -Round(math_max(0, (availableHeight - totalHeight) * 0.5))
  local row1Y = topY
  local row2Y = topY - row1Size - spacing

  if row2Count > 0 and config.rowGrowth == "UP" then
    row2Y = topY
    row1Y = topY - row2Size - spacing
  end

  for index = 1, count do
    local icon = icons[index]
    local size
    local x
    local y

    if index <= row1Count then
      size = row1Size
      x = row1StartX + (index - 1) * (row1Size + spacing) * row1Direction
      y = row1Y
    else
      local row2Index = index - row1Count
      size = row2Size
      x = row2StartX + (row2Index - 1) * (row2Size + spacing) * row2Direction
      y = row2Y
    end

    icon.frame:ClearAllPoints()
    icon.frame:SetPoint("TOPLEFT", content, "TOPLEFT", Round(x), y)
    icon.frame:SetSize(size, size)
    icon.frame:Show()
  end
end

local function PCMPreview_ConfigureViewerPanel(box, panel, definition, root)
  local viewerKey = definition.key
  local tabPath = { "CooldownManager", definition.tab }
  local defaultWidth = viewerKey == "EssentialCooldownViewer" and 400 or 300
  local style = PCMPreview_GetViewerStyle(root, viewerKey, defaultWidth)
  local viewerBorder = PCMPreview_GetViewerBorder(root, viewerKey)
  local iconBorder = PCMPreview_GetIconBorder(root, viewerKey, false)
  local counts = PCMPreview_GetViewerCounts(root, viewerKey)
  local swipe = PCMPreview_GetViewerSwipe(root, viewerKey)
  local cooldownFont = PCMPreview_GetFontConfig(root, viewerKey, "cooldown")
  local chargeFont = PCMPreview_GetFontConfig(root, viewerKey, "charge")
  local keybindFont = PCMPreview_GetFontConfig(root, viewerKey, "keybind")
  local displayScale = PCMPreview_GetDisplayScale(panel)
  local background = type(root.style) == "table" and root.style.iconBgColor
    or { 0, 0, 0, 0.35 }
  local glowConfig = type(root.glow) == "table" and root.glow or {}
  local glowColor = glowConfig.color or { 0.95, 0.95, 0.32, 1 }
  local entries = IconSettings:GetViewerEntries(viewerKey)
  local selectedEntry = IconSettings:GetSelectedEntry(viewerKey)

  PCMPreview_EnsureIconCount(box, panel, #entries)



  local viewerBg = Theme.GetColors().background
  local viewerBorderColor = viewerBorder.enabled
    and viewerBorder.thickness > 0
    and viewerBorder.color
    or { 0, 0, 0, 0 }

  PCMPreview_ApplyBackdrop(
    panel,
    { viewerBg[1], viewerBg[2], viewerBg[3], 0.96 },
    viewerBorderColor,
    math_max(1, viewerBorder.thickness * displayScale)
  )

  PCMPreview_LayoutViewerIcons(panel, panel.__puiPCMPreviewIcons, style)

  for index = 1, #entries do
    local entry = entries[index]
    local icon = panel.__puiPCMPreviewIcons[index]
    local effectiveCooldownFont, cooldownShown = PCMPreview_GetEffectiveIconText(
      entry,
      "cooldown",
      cooldownFont
    )
    local effectiveChargeFont, chargeShown = PCMPreview_GetEffectiveIconText(
      entry,
      "charge",
      chargeFont
    )
    local effectiveKeybindFont, keybindShown = PCMPreview_GetEffectiveIconText(
      entry,
      "keybind",
      keybindFont
    )
    local effectiveSwipe = PCMPreview_GetEffectiveIconSwipe(entry, swipe)
    local record = IconSettings:GetRecordForEntry(entry, false)
    local appearance = record and record.appearance
    local bgR, bgG, bgB, bgA = PCMPreview_ColorComponents(
      background,
      { 0, 0, 0, 0.35 }
    )
    local borderR, borderG, borderB, borderA = PCMPreview_ColorComponents(
      iconBorder,
      { 0, 0, 0, 1 }
    )
    local swipeR, swipeG, swipeB, swipeA = PCMPreview_ColorComponents(
      effectiveSwipe.color,
      { 0, 0, 0, 0.8 }
    )

    local previewState = selectedEntry == entry and IconSettings:GetPreviewState(viewerKey) or nil
    local customTexture = appearance and appearance.texture or nil
    icon.background:SetVertexColor(bgR, bgG, bgB, bgA)
    icon.icon:SetTexture(customTexture or entry.texture)
    icon.icon:SetVertexColor(1, 1, 1, 1)
    icon.__puiPCMPreviewState = previewState
    icon.__puiPCMPreviewStateViewerKey = selectedEntry == entry and viewerKey or nil
    icon.__puiPCMPreviewReadySaturation = appearance and appearance.readySaturation or nil
    icon.__puiPCMPreviewCooldownSaturation = appearance and appearance.cooldownSaturation or nil
    icon.cooldown:SetDrawEdge(effectiveSwipe.drawEdge)
    icon.cooldown:SetReverse(effectiveSwipe.reverse)
    icon.cooldown:SetSwipeColor(swipeR, swipeG, swipeB, swipeA)
    icon.cooldown:SetShown(effectiveSwipe.show)
    icon.__puiPCMPreviewCooldownEnabled = effectiveSwipe.show
    icon.__puiPCMPreviewReadyAlpha = appearance and appearance.readyAlpha or 1
    icon.__puiPCMPreviewCooldownAlpha = appearance and appearance.cooldownAlpha or 1
    icon.__puiPCMPreviewDuration = 7 + index * 2
    icon.__puiPCMPreviewPhaseOffset = index * 0.8
    icon.__puiPCMPreviewCooldownCycle = nil

    PCMPreview_ApplyBackdrop(
      icon.frame,
      { 0.03, 0.03, 0.04, 1 },
      { borderR, borderG, borderB, borderA },
      2 * displayScale
    )
    PCMPreview_ApplyBackdrop(
      icon.selection,
      { 0, 0, 0, 0 },
      definition.accent,
      2 * displayScale
    )

    PCMPreview_ApplyFont(icon.cooldownText, effectiveCooldownFont, "body", 11, displayScale)
    PCMPreview_ApplyFont(icon.chargeText, effectiveChargeFont, "tiny", 10, displayScale)
    PCMPreview_ApplyFont(icon.keybindText, effectiveKeybindFont, "tiny", 8, displayScale)

    icon.cooldownText:ClearAllPoints()
    icon.cooldownText:SetPoint(
      "CENTER",
      icon.frame,
      "CENTER",
      Round((effectiveCooldownFont.offsetX or 0) * displayScale),
      Round((effectiveCooldownFont.offsetY or 0) * displayScale)
    )
    icon.chargeText:ClearAllPoints()
    icon.chargeText:SetPoint(
      "BOTTOMRIGHT",
      icon.frame,
      "BOTTOMRIGHT",
      Round((-2 + (effectiveChargeFont.offsetX or 0)) * displayScale),
      Round((2 + (effectiveChargeFont.offsetY or 0)) * displayScale)
    )
    icon.keybindText:ClearAllPoints()
    icon.keybindText:SetPoint(
      "TOPLEFT",
      icon.frame,
      "TOPLEFT",
      Round((effectiveKeybindFont.offsetX or 0) * displayScale),
      Round((effectiveKeybindFont.offsetY or 0) * displayScale)
    )

    local showCooldownText = cooldownShown == nil and counts.cooldown or cooldownShown
    local showChargeText = chargeShown == nil and counts.charge or chargeShown
    local showKeybindText = keybindShown == nil and counts.keybind or keybindShown
    icon.cooldownText:SetShown(showCooldownText)
    icon.chargeText:SetShown(showChargeText and index % 2 == 0)
    icon.keybindText:SetShown(showKeybindText)
    icon.keybindText:SetText(index <= 4 and tostring(index) or "S" .. tostring(index - 4))

    local optionKey = IconSettings:GetOptionKey(entry)
    local iconOverridePath = optionKey and {
      "CooldownManager",
      definition.tab,
      "iconOverrides",
      optionKey,
    } or tabPath

    local function SelectIcon()
      IconSettings:Select(viewerKey, entry.settingsKey)
      PCMPreview.RefreshBox(box)
    end

    icon.selection:SetShown(selectedEntry == entry)

    PCMPreview_SetInteraction(
      icon.interactions.body,
      entry.name,
      "Click to configure this icon's overrides.",
      iconOverridePath,
      nil,
      nil,
      SelectIcon
    )


    local showGlow = definition.key == "EssentialCooldownViewer"
      and glowConfig.enabled ~= false
      and index == 1

    if showGlow then
      local glowR, glowG, glowB, glowA = PCMPreview_ColorComponents(
        glowColor,
        { 0.95, 0.95, 0.32, 1 }
      )
      icon.glow:SetVertexColor(glowR, glowG, glowB, glowA)
      icon.glow:Show()
    else
      icon.glow:Hide()
    end
  end
end

local function PCMPreview_ConfigureBuffIconPanel(box, panel, root)
  local viewerKey = "BuffIconCooldownViewer"
  local path = { "CooldownManager", "buff_icons" }
  local style = PCMPreview_GetViewerStyle(root, viewerKey, 300)
  local viewerBorder = PCMPreview_GetViewerBorder(root, viewerKey)
  local borders = PCMPreview_GetIconBorder(root, viewerKey, true)
  local countFont = PCMPreview_GetFontConfig(root, viewerKey, "cooldown")
  local stackFont = PCMPreview_GetFontConfig(root, viewerKey, "charge")
  local displayScale = PCMPreview_GetDisplayScale(panel)
  local entries = IconSettings:GetViewerEntries(viewerKey)
  local selectedEntry = IconSettings:GetSelectedEntry(viewerKey)

  PCMPreview_EnsureIconCount(box, panel, #entries)



  local colors = Theme.GetColors()
  local viewerBorderColor = viewerBorder.enabled
    and viewerBorder.thickness > 0
    and viewerBorder.color
    or { 0, 0, 0, 0 }

  PCMPreview_ApplyBackdrop(
    panel,
    { colors.background[1], colors.background[2], colors.background[3], 0.96 },
    viewerBorderColor,
    math_max(1, viewerBorder.thickness * displayScale)
  )

  PCMPreview_LayoutViewerIcons(panel, panel.__puiPCMPreviewIcons, style)

  for index = 1, #entries do
    local entry = entries[index]
    local icon = panel.__puiPCMPreviewIcons[index]
    local effectiveCountFont, countShown = PCMPreview_GetEffectiveIconText(entry, "cooldown", countFont)
    local effectiveStackFont, stackShown = PCMPreview_GetEffectiveIconText(entry, "charge", stackFont)
    local record = IconSettings:GetRecordForEntry(entry, false)
    local appearance = record and record.appearance or nil
    local swipe = PCMPreview_GetEffectiveIconSwipe(entry, {
      cooldown = true,
      drawEdge = true,
      color = { 0, 0, 0, 0.8 },
    })
    local br, bg, bb, ba = PCMPreview_ColorComponents(
      borders.buff,
      { 0, 0, 0, 1 }
    )

    local customTexture = appearance and appearance.texture or nil
    icon.icon:SetTexture(customTexture or entry.texture)
    icon.icon:SetVertexColor(1, 1, 1, 1)
    icon.__puiPCMPreviewState = selectedEntry == entry and IconSettings:GetPreviewState(viewerKey) or "AURA"
    icon.__puiPCMPreviewStateViewerKey = selectedEntry == entry and viewerKey or nil
    icon.__puiPCMPreviewAuraAlpha = appearance and appearance.auraAlpha or 1
    icon.__puiPCMPreviewAuraSaturation = appearance and appearance.auraSaturation or nil
    icon.__puiPCMPreviewReadySaturation = nil
    icon.__puiPCMPreviewCooldownSaturation = nil
    icon.cooldown:SetDrawEdge(swipe.drawEdge)
    icon.cooldown:SetReverse(swipe.reverse)
    local sr, sg, sb, sa = PCMPreview_ColorComponents(swipe.color, { 0, 0, 0, 0.8 })
    icon.cooldown:SetSwipeColor(sr, sg, sb, sa)
    icon.cooldown:SetShown(swipe.show)
    icon.__puiPCMPreviewCooldownEnabled = swipe.show
    icon.__puiPCMPreviewDuration = 9 + index * 2
    icon.__puiPCMPreviewPhaseOffset = index * 0.6
    icon.__puiPCMPreviewCooldownCycle = nil
    icon.__puiPCMPreviewAuraMode = true

    local showCountText = countShown == nil or countShown == true
    local showStackText = (stackShown == nil or stackShown == true) and index % 2 == 0
    icon.cooldownText:SetShown(showCountText)
    icon.chargeText:SetShown(showStackText)
    icon.keybindText:Hide()
    icon.glow:Hide()

    PCMPreview_ApplyFont(icon.cooldownText, effectiveCountFont, "body", 10, displayScale)
    PCMPreview_ApplyFont(icon.chargeText, effectiveStackFont, "tiny", 10, displayScale)
    PCMPreview_ApplyBackdrop(
      icon.frame,
      { 0.03, 0.03, 0.04, 1 },
      { br, bg, bb, ba },
      2 * displayScale
    )
    PCMPreview_ApplyBackdrop(
      icon.selection,
      { 0, 0, 0, 0 },
      { 0.85, 0.55, 0.2, 1 },
      2 * displayScale
    )

    local optionKey = IconSettings:GetOptionKey(entry)
    local iconOverridePath = optionKey and {
      "CooldownManager",
      "buff_icons",
      "iconOverrides",
      optionKey,
    } or path

    local function SelectIcon()
      IconSettings:Select(viewerKey, entry.settingsKey)
      PCMPreview.RefreshBox(box)
    end

    icon.selection:SetShown(selectedEntry == entry)
    PCMPreview_SetInteraction(
      icon.interactions.body,
      entry.name,
      "Click to configure this buff icon's overrides.",
      iconOverridePath,
      nil,
      nil,
      SelectIcon
    )

  end
end

local function PCMPreview_ConfigureBuffBarPanel(panel, style)
  style = type(style) == "table" and style or {}
  local config = type(style.buffBar) == "table" and style.buffBar or {}
  local colors = Theme.GetColors()
  local vertical = config.orientation == "VERTICAL"
  local length = PCMPreview_Clamp(config.width or 250, 120, 400)
  local thickness = PCMPreview_Clamp(config.height or 20, 8, 40)
  local spacing = PCMPreview_Clamp(config.rowSpacing or 1, 0, 40)
  local iconGap = PCMPreview_Clamp(config.iconGap or config.padding or 1, 0, 20)
  local content = panel.__puiPCMPreviewContent
  local previewZoom = PCMPreview_GetDisplayScale(panel)
  local displayLength = math_max(30, Round(length * previewZoom))
  local displayThickness = math_max(6, Round(thickness * previewZoom))
  local displaySpacing = Round(spacing * previewZoom)
  local displayIconGap = Round(iconGap * previewZoom)
  local iconPlacement = config.iconPlacement or (vertical and "TOP" or "LEFT")
  local showIcon = iconPlacement ~= "HIDE"
  local displayIconSize = displayThickness
  local barWidth = vertical and displayThickness or displayLength
  local barHeight = vertical and displayLength or displayThickness
  local rowWidth = barWidth
  local rowHeight = barHeight

  if showIcon then
    if vertical then
      rowWidth = math_max(rowWidth, displayIconSize)
      rowHeight = rowHeight + displayIconSize + displayIconGap
    else
      rowWidth = rowWidth + displayIconSize + displayIconGap
      rowHeight = math_max(rowHeight, displayIconSize)
    end
  end

  local labelWidth = vertical and 0 or math_max(88, Round(132 * previewZoom))
  local labelGap = vertical and 0 or Round(6 * previewZoom)
  local texture = BarWidget.ResolveStatusBarTexture(config.texture or "Pleebar", FALLBACK_BAR_TEXTURE)
  local backgroundColor = style.buffBarBgColor or { 0.12, 0.12, 0.12, 0.95 }
  local fillColor = style.buffBarColor or colors.accent
  local borderColor = config.borderColor or { 0.20, 0.20, 0.24, 1 }
  local borderThickness = PCMPreview_Clamp(config.borderThickness or 2, 0, 6)
  local entries = IconSettings:GetViewerEntries("BuffBarCooldownViewer")
  local totalWidth
  local totalHeight

  if vertical then
    totalWidth = #entries > 0
      and #entries * rowWidth + (#entries - 1) * displaySpacing
      or 0
    totalHeight = rowHeight
  else
    totalWidth = labelWidth + labelGap + rowWidth
    totalHeight = #entries > 0
      and #entries * rowHeight + (#entries - 1) * displaySpacing
      or 0
  end

  local startX = Round((content:GetWidth() - totalWidth) * 0.5)
  local startY = -Round(math_max(0, (content:GetHeight() - totalHeight) * 0.5))
  local growthDirection = config.growthDirection or (vertical and "RIGHT" or "DOWN")
  local reverseFill = vertical
    and config.drainDirection == "TOP_TO_BOTTOM"
    or (not vertical and config.drainDirection == "LEFT_TO_RIGHT")
  local fillR, fillG, fillB, fillA

  if style.buffBarUseClassColor ~= false then
    local class = select(2, UnitClass("player"))
    local classColor = class and RAID_CLASS_COLORS[class] or nil

    if classColor then
      fillR, fillG, fillB, fillA = classColor.r, classColor.g, classColor.b, 1
    end
  end

  if not fillR then
    fillR, fillG, fillB, fillA = PCMPreview_ColorComponents(
      fillColor,
      colors.accent
    )
  end

  PCMPreview_EnsureBarCount(panel, #entries)

  for index = 1, #entries do
    local entry = entries[index]
    local bar = panel.__puiPCMPreviewBars[index]
    local growthIndex
    local x
    local y

    if vertical then
      growthIndex = growthDirection == "LEFT" and (#entries - index) or (index - 1)
      x = startX + growthIndex * (rowWidth + displaySpacing)
      y = startY
    else
      growthIndex = growthDirection == "UP" and (#entries - index) or (index - 1)
      x = startX + labelWidth + labelGap
      y = startY - growthIndex * (rowHeight + displaySpacing)
    end

    local bgR, bgG, bgB, bgA = PCMPreview_ColorComponents(
      backgroundColor,
      { 0.12, 0.12, 0.12, 0.95 }
    )
    local borderR, borderG, borderB, borderA = PCMPreview_ColorComponents(
      borderColor,
      { 0.20, 0.20, 0.24, 1 }
    )

    bar.frame:ClearAllPoints()
    bar.frame:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    bar.frame:SetSize(rowWidth, rowHeight)
    bar.frame:Show()

    bar.label:ClearAllPoints()
    bar.label:SetShown(not vertical)
    if not vertical then
      bar.label:SetPoint("RIGHT", bar.frame, "LEFT", -labelGap, 0)
      bar.label:SetWidth(labelWidth)
      bar.label:SetJustifyH("RIGHT")
    end

    bar.iconFrame:SetShown(showIcon)
    bar.icon:SetShown(showIcon)
    bar.status:ClearAllPoints()

    if showIcon then
      bar.iconFrame:ClearAllPoints()
      bar.iconFrame:SetSize(displayIconSize, displayIconSize)

      if vertical then
        if iconPlacement == "BOTTOM" then
          bar.iconFrame:SetPoint("BOTTOM", bar.frame, "BOTTOM", 0, 0)
          bar.status:SetPoint("BOTTOM", bar.iconFrame, "TOP", 0, displayIconGap)
        else
          bar.iconFrame:SetPoint("TOP", bar.frame, "TOP", 0, 0)
          bar.status:SetPoint("TOP", bar.iconFrame, "BOTTOM", 0, -displayIconGap)
        end
      elseif iconPlacement == "RIGHT" then
        bar.iconFrame:SetPoint("RIGHT", bar.frame, "RIGHT", 0, 0)
        bar.status:SetPoint("RIGHT", bar.iconFrame, "LEFT", -displayIconGap, 0)
      else
        bar.iconFrame:SetPoint("LEFT", bar.frame, "LEFT", 0, 0)
        bar.status:SetPoint("LEFT", bar.iconFrame, "RIGHT", displayIconGap, 0)
      end
    else
      bar.status:SetPoint("CENTER", bar.frame, "CENTER", 0, 0)
    end

    bar.status:SetSize(barWidth, barHeight)
    bar.valueTextFrame:ClearAllPoints()
    bar.valueTextFrame:SetAllPoints(bar.status)
    bar.icon:SetTexture(entry.texture)
    bar.icon:SetVertexColor(1, 1, 1, 1)
    bar.background:SetVertexColor(bgR, bgG, bgB, bgA)
    bar.status:SetStatusBarTexture(texture)
    bar.status:SetStatusBarColor(fillR, fillG, fillB, fillA)
    bar.status:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
    bar.status:SetReverseFill(reverseFill)

    Theme.ApplyFont(bar.label, "tiny", math_max(4, displayThickness * 0.42), "OUTLINE")
    Theme.ApplyFont(bar.valueText, "tiny", math_max(4, displayThickness * 0.42), "OUTLINE")

    bar.label:SetText(entry.name or ("Spell " .. tostring(entry.spellID or index)))
    bar.valueText:SetText("12")
    bar.__puiPCMPreviewMode = "duration"
    bar.__puiPCMPreviewDuration = 15 + index * 4
    bar.__puiPCMPreviewPhaseOffset = index * 1.4
    bar.__puiPCMPreviewDurationStatus = bar.status
    bar.__puiPCMPreviewDurationText = bar.valueText
    bar.__puiPCMPreviewDurationDrain = true

    local visualBorder = borderThickness > 0
      and { borderR, borderG, borderB, borderA }
      or { 0, 0, 0, 0 }

    PCMPreview_ApplyBackdrop(
      bar.frame,
      { bgR, bgG, bgB, bgA },
      visualBorder,
      math_max(1, borderThickness * previewZoom)
    )
  end
end

local function PCMPreview_SortedKeys(root)
  local keys = {}

  for key, value in pairs(root or {}) do
    if (type(key) == "number" or type(key) == "string")
      and type(value) == "table"
    then
      keys[#keys + 1] = key
    end
  end

  table_sort(keys, function(left, right)
    local leftConfig = root[left]
    local rightConfig = root[right]
    local leftLabel = tostring(leftConfig.label or "")
    local rightLabel = tostring(rightConfig.label or "")

    if leftLabel == rightLabel then
      return tostring(left) < tostring(right)
    end

    return leftLabel < rightLabel
  end)

  return keys
end

local function PCMPreview_GetClassBarColor(config, fallback)
  if config.useClassColor ~= false then
    local class = select(2, UnitClass("player"))
    local classColor = class and RAID_CLASS_COLORS[class] or nil

    if classColor then
      return classColor.r, classColor.g, classColor.b, 1
    end
  end

  return PCMPreview_ColorComponents(config.barColor, fallback)
end

local function PCMPreview_GetStackSegmentColor(config, stackIndex, r, g, b, a)
  local thresholds = config and config.stackColorThresholds
  if type(thresholds) ~= "table" then
    return r, g, b, a
  end

  for index = 1, #thresholds do
    local threshold = thresholds[index]
    local value = threshold and tonumber(threshold.value)

    if threshold and threshold.enabled == true and value and stackIndex >= value then
      if threshold.colorMode == "CLASS" then
        if PLAYER_CLASS_COLOR then
          r, g, b, a = PLAYER_CLASS_COLOR.r, PLAYER_CLASS_COLOR.g, PLAYER_CLASS_COLOR.b, 1
        end
      else
        r, g, b, a = PCMPreview_ColorComponents(threshold.color, { r, g, b, a })
      end
    end
  end

  return r, g, b, a
end

local function PCMPreview_GetCustomEntries()
  local entries = {}

  if InCombatLockdown() then
    return entries
  end

  local spellRoot = Cooldowns.GetSpellBarsDB() or {}
  local spellKeys = PCMPreview_SortedKeys(spellRoot)

  for index = 1, #spellKeys do
    local key = spellKeys[index]
    local config = Cooldowns.NormalizeSpellBarEntry(spellRoot[key], key)
    local spellID = config.enabled ~= false
      and Cooldowns:GetTrackedSpellIDForCurrentSpec(config)
      or nil

    if spellID and Cooldowns.IsSpellBarLoaded(config) then
      local texture = PCMPreview_GetSafeSpellTexture(spellID)

      if texture then
        entries[#entries + 1] = {
          targetKey = "spell:" .. tostring(key),
          kind = "cooldown",
          title = Cooldowns:GetCustomBarDisplayName(config),
          spellID = spellID,
          texture = texture,
          config = config,
        }
      end
    end
  end

  local chargeRoot = Cooldowns.GetCooldownStackBarsDB() or {}
  local chargeKeys = PCMPreview_SortedKeys(chargeRoot)

  for index = 1, #chargeKeys do
    local key = chargeKeys[index]
    local config = Cooldowns.NormalizeCooldownStackBarEntry(chargeRoot[key], key)
    local spellID = config.enabled ~= false
      and Cooldowns:GetTrackedSpellIDForCurrentSpec(config)
      or nil

    if spellID and Cooldowns.IsChargeCooldownBarLoaded(config) then
      local texture = PCMPreview_GetSafeSpellTexture(spellID)

      if texture then
        entries[#entries + 1] = {
          targetKey = "chargeSpell:" .. tostring(key),
          kind = "charge",
          title = Cooldowns:GetCustomBarDisplayName(config),
          spellID = spellID,
          texture = texture,
          config = config,
        }
      end
    end
  end

  local buffRoot = BuffBars.GetStackBarsDB() or {}
  local buffKeys = PCMPreview_SortedKeys(buffRoot)

  for index = 1, #buffKeys do
    local key = buffKeys[index]
    local config = BuffBars.EnsureStackBarDefaults(buffRoot[key], key)
    local spellID = config.enabled ~= false
      and Cooldowns:GetTrackedSpellIDForCurrentSpec(config)
      or nil

    if spellID and Cooldowns.IsBuffBarLoaded(config) then
      local texture = PCMPreview_GetSafeSpellTexture(spellID)

      if texture then
        entries[#entries + 1] = {
          targetKey = "bb:" .. tostring(key),
          kind = config.kind == "duration" and "duration" or "stack",
          title = Cooldowns:GetCustomBarDisplayName(config),
          spellID = spellID,
          texture = texture,
          config = config,
        }
      end
    end
  end

  return entries
end

local function PCMPreview_GetCustomPath(entry)
  return {
    "CooldownManager",
    "custom_bars",
    entry.targetKey,
  }
end



local function PCMPreview_EnsureStackSegments(bar, count)
  bar.stackSegments = PCMPresentation.EnsureStackSegments(bar, count)
end

local function PCMPreview_EnsureChargeSlots(bar, count)
  bar.chargeSlots = PCMPresentation.EnsureChargeSlots(
    bar.chargePresentation,
    count
  )
end

local function PCMPreview_ResetCustomBar(bar)
  BarWidget.ApplyBorder(bar.barFrame, 0, { 0, 0, 0, 0 })
  bar.barFrame:ClearAllPoints()
  bar.barFrame:SetAllPoints(bar.frame)
  bar.background:Hide()
  bar.status:SetAlpha(1)
  bar.status:Show()
  bar.iconFrame:Hide()
  bar.icon:Hide()
  bar.chargeRoot:Hide()
  bar.chargePresentation.frame:Hide()
  bar.customGlowFrame:Hide()
  bar.valueText:Show()
  bar.durationFrame:Hide()
  bar.durationStatus:SetValue(1)
  bar.durationValueText:Hide()
  bar.durationIconFrame:Hide()
  bar.durationCooldown:Hide()
  bar.durationIconText:Hide()

  bar.__puiPCMPreviewDurationStatus = nil
  bar.__puiPCMPreviewDurationText = nil
  bar.__puiPCMPreviewDurationIcon = false
  bar.__puiPCMPreviewDurationCycle = nil
  bar.__puiPCMPreviewChargeDuration = nil
  bar.__puiPCMPreviewChargeSpendDuration = nil
  bar.__puiPCMPreviewChargeConfig = nil
  bar.__puiPCMPreviewMaxCharges = nil
  bar.__puiPCMPreviewMaxStacks = nil
  bar.__puiPCMPreviewStackReverse = nil
  bar.__puiPCMPreviewDurationDrain = nil
  bar.__puiPCMPreviewCustomGlowEnabled = nil

  for index = 1, #bar.stackSegments do
    bar.stackSegments[index]:Hide()
  end

  for index = 1, #bar.chargeSlots do
    bar.chargeSlots[index].frame:Hide()
  end
end

local function PCMPreview_LayoutCustomFrame(
  bar,
  config,
  entry,
  content,
  yOffset,
  zoom
)
  local rawWidth = PCMPreview_Clamp(config.width or 250, 50, 600)
  local rawHeight = PCMPreview_Clamp(config.height or 25, 5, 80)
  local isVertical = config.orientation == "vertical"
  local gap = PCMPreview_Clamp(config.durationGap or 2, 0, 20)
  local durationAnchor = tostring(config.durationAnchor or "BOTTOM"):upper()
  local durationEnabled = entry.kind == "duration"
    or entry.kind == "stack"
      and config.showDuration == true
  local durationUsesIcon = entry.kind == "stack"
    and durationEnabled
    and (durationAnchor == "LEFT" or durationAnchor == "RIGHT")
  local showMainIcon = false
  local showDurationIcon = false
  local mainWidth = rawWidth
  local mainHeight = rawHeight
  local topExtent = 0
  local bottomExtent = 0
  local leftExtent = 0
  local mainIconSize = 0
  local durationIconSize = 0
  local auraGeometry = (entry.kind == "stack" or entry.kind == "duration")
    and BuffBars.GetCustomBarLayoutGeometry(config)
    or nil

  if entry.kind == "cooldown" or entry.kind == "charge" then
    showMainIcon = config.showIcon == true
    if showMainIcon then
      mainIconSize = rawHeight
      if mainIconSize >= rawWidth then
        mainIconSize = math_max(1, rawWidth - 1)
      end
    end

    if isVertical then
      mainWidth = math_max(rawHeight, mainIconSize)
      mainHeight = rawWidth
    else
      mainWidth = rawWidth
      mainHeight = math_max(rawHeight, mainIconSize)
    end
  elseif entry.kind == "duration" then
    mainWidth = auraGeometry.frameWidth
    mainHeight = auraGeometry.frameHeight
    showDurationIcon = auraGeometry.inlineKind == "duration"
    durationIconSize = auraGeometry.inlineIconSize

    if showDurationIcon then
      if isVertical then
        bottomExtent = durationIconSize + gap
      else
        leftExtent = durationIconSize + gap
      end
    end
  else
    mainWidth = auraGeometry.frameWidth
    mainHeight = auraGeometry.frameHeight

    if auraGeometry.inlineKind == "duration" then
      showDurationIcon = true
      durationIconSize = auraGeometry.inlineIconSize

      if isVertical then
        bottomExtent = durationIconSize + gap
      elseif auraGeometry.inlineAnchor == "LEFT" then
        leftExtent = durationIconSize + gap
      end
    elseif durationEnabled then
      local durationHeight = PCMPreview_Clamp(
        config.durationHeight or 10,
        2,
        40
      )

      if durationAnchor == "TOP" then
        topExtent = durationHeight + gap
      else
        bottomExtent = durationHeight + gap
      end
    end

    showMainIcon = auraGeometry.inlineKind == "spell"
    mainIconSize = showMainIcon and auraGeometry.inlineIconSize or 0
    if showMainIcon then
      if isVertical then
        bottomExtent = math_max(bottomExtent, mainIconSize + gap)
      else
        leftExtent = math_max(leftExtent, mainIconSize + gap)
      end
    end
  end

  if showDurationIcon and not isVertical and durationIconSize > mainHeight then
    local extraHeight = durationIconSize - mainHeight
    topExtent = math_max(topExtent, extraHeight * 0.5)
    bottomExtent = math_max(bottomExtent, extraHeight * 0.5)
  end

  local displayMainWidth = math_max(1, Round(mainWidth * zoom))
  local displayMainHeight = math_max(1, Round(mainHeight * zoom))
  local displayTopExtent = Round(topExtent * zoom)
  local displayBottomExtent = Round(bottomExtent * zoom)
  local displayLeftExtent = Round(leftExtent * zoom)
  local displayGap = Round(gap * zoom)
  local labelWidth = math_max(88, Round(132 * zoom))

  bar.frame:ClearAllPoints()
  bar.frame:SetPoint(
    "TOP",
    content,
    "TOP",
    0,
    -(yOffset + displayTopExtent)
  )
  bar.__puiPCMPreviewLayoutY = yOffset + displayTopExtent
  bar.frame:SetSize(displayMainWidth, displayMainHeight)
  bar.frame:Show()

  bar.label:ClearAllPoints()
  bar.label:SetPoint(
    "RIGHT",
    bar.frame,
    "LEFT",
    -(displayLeftExtent + Round(6 * zoom)),
    0
  )
  bar.label:SetWidth(labelWidth)
  bar.label:SetJustifyH("RIGHT")

  bar.iconFrame:ClearAllPoints()
  bar.iconFrame:SetShown(showMainIcon)
  bar.icon:SetShown(showMainIcon)

  bar.status:ClearAllPoints()
  bar.chargeRoot:ClearAllPoints()
  bar.durationFrame:ClearAllPoints()
  bar.durationIconFrame:ClearAllPoints()

  if entry.kind == "cooldown" or entry.kind == "charge" then
    local displayThickness = math_max(1, Round(rawHeight * zoom))
    local displayIconSize = math_max(1, Round(mainIconSize * zoom))
    local displayBarLength = math_max(
      1,
      Round((showMainIcon and rawWidth - mainIconSize or rawWidth) * zoom)
    )

    if isVertical then
      if showMainIcon then
        local anchor = entry.kind == "cooldown" and config.iconAnchor or "bottom"

        if anchor == "top" then
          bar.iconFrame:SetPoint("TOP", bar.frame, "TOP", 0, 0)
          bar.status:SetPoint("TOP", bar.iconFrame, "BOTTOM", 0, 0)
          bar.chargeRoot:SetPoint("TOP", bar.iconFrame, "BOTTOM", 0, 0)
        else
          bar.iconFrame:SetPoint("BOTTOM", bar.frame, "BOTTOM", 0, 0)
          bar.status:SetPoint("BOTTOM", bar.iconFrame, "TOP", 0, 0)
          bar.chargeRoot:SetPoint("BOTTOM", bar.iconFrame, "TOP", 0, 0)
        end

        bar.iconFrame:SetSize(displayIconSize, displayIconSize)
      else
        bar.status:SetPoint("BOTTOM", bar.frame, "BOTTOM", 0, 0)
        bar.chargeRoot:SetPoint("BOTTOM", bar.frame, "BOTTOM", 0, 0)
      end

      bar.status:SetSize(displayThickness, displayBarLength)
      bar.chargeRoot:SetSize(displayThickness, displayBarLength)
    else
      if showMainIcon then
        local anchor = entry.kind == "cooldown" and config.iconAnchor or "left"

        if anchor == "right" then
          bar.iconFrame:SetPoint("RIGHT", bar.frame, "RIGHT", 0, 0)
          bar.status:SetPoint("RIGHT", bar.iconFrame, "LEFT", 0, 0)
          bar.chargeRoot:SetPoint("RIGHT", bar.iconFrame, "LEFT", 0, 0)
        else
          bar.iconFrame:SetPoint("LEFT", bar.frame, "LEFT", 0, 0)
          bar.status:SetPoint("LEFT", bar.iconFrame, "RIGHT", 0, 0)
          bar.chargeRoot:SetPoint("LEFT", bar.iconFrame, "RIGHT", 0, 0)
        end

        bar.iconFrame:SetSize(displayIconSize, displayIconSize)
      else
        bar.status:SetPoint("LEFT", bar.frame, "LEFT", 0, 0)
        bar.chargeRoot:SetPoint("LEFT", bar.frame, "LEFT", 0, 0)
      end

      bar.status:SetSize(displayBarLength, displayThickness)
      bar.chargeRoot:SetSize(displayBarLength, displayThickness)
    end
  else
    local borderSize = PCMPreview_Clamp(config.borderSize or 2, 0, 12)
    local inset = math_max(0, Round(borderSize * zoom))

    bar.status:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", inset, -inset)
    bar.status:SetPoint("BOTTOMRIGHT", bar.frame, "BOTTOMRIGHT", -inset, inset)

    if showMainIcon then
      local displayIconSize = math_max(1, Round(mainIconSize * zoom))

      if isVertical then
        bar.iconFrame:SetPoint(
          "TOP",
          bar.frame,
          "BOTTOM",
          0,
          -displayGap
        )
      else
        bar.iconFrame:SetPoint(
          "RIGHT",
          bar.frame,
          "LEFT",
          -displayGap,
          0
        )
      end

      bar.iconFrame:SetSize(displayIconSize, displayIconSize)
    end

    if entry.kind == "stack" and durationEnabled and not durationUsesIcon then
      local displayDurationHeight = math_max(
        1,
        Round(PCMPreview_Clamp(config.durationHeight or 10, 2, 40) * zoom)
      )

      if durationAnchor == "TOP" then
        bar.durationFrame:SetPoint(
          "BOTTOMLEFT",
          bar.frame,
          "TOPLEFT",
          0,
          displayGap
        )
        bar.durationFrame:SetPoint(
          "BOTTOMRIGHT",
          bar.frame,
          "TOPRIGHT",
          0,
          displayGap
        )
      else
        bar.durationFrame:SetPoint(
          "TOPLEFT",
          bar.frame,
          "BOTTOMLEFT",
          0,
          -displayGap
        )
        bar.durationFrame:SetPoint(
          "TOPRIGHT",
          bar.frame,
          "BOTTOMRIGHT",
          0,
          -displayGap
        )
      end

      bar.durationFrame:SetHeight(displayDurationHeight)
      bar.durationFrame:Show()
    end

    if showDurationIcon then
      local displayDurationIconSize = math_max(1, Round(durationIconSize * zoom))

      if isVertical then
        bar.durationIconFrame:SetPoint(
          "TOP",
          bar.frame,
          "BOTTOM",
          0,
          -displayGap
        )
      elseif entry.kind == "duration" or durationAnchor == "LEFT" then
        bar.durationIconFrame:SetPoint(
          "RIGHT",
          bar.frame,
          "LEFT",
          -displayGap,
          0
        )
      else
        bar.durationIconFrame:SetPoint(
          "LEFT",
          bar.frame,
          "RIGHT",
          displayGap,
          0
        )
      end

      bar.durationIconFrame:SetSize(
        displayDurationIconSize,
        displayDurationIconSize
      )
      bar.durationIconFrame:Show()
    end
  end

  bar.__puiPCMPreviewDurationBarEnabled = entry.kind == "stack"
    and durationEnabled
    and not durationUsesIcon
  bar.__puiPCMPreviewDurationIconEnabled = showDurationIcon

  return displayTopExtent + displayMainHeight + displayBottomExtent
end

local function PCMPreview_ConfigureStackSegments(bar, config, zoom)
  local maxStacks = PCMPreview_Clamp(config.maxStacks or 3, 1, 60)
  local r, g, b, a = PCMPreview_GetClassBarColor(
    config,
    { 0.74, 0.48, 0.92, 1 }
  )

  bar.stackSegments = PCMPresentation.LayoutStackSegments(bar, {
    config = config,
    maxStacks = maxStacks,
    gap = math_max(0, Round(zoom)),
    color = { r, g, b, a },
  })

  for index = 1, maxStacks do
    local segment = bar.stackSegments[index]
    if segment then
      local stackIndex = bar.stackReverse
        and (maxStacks - index + 1)
        or index
      local sr, sg, sb, sa = PCMPreview_GetStackSegmentColor(
        config,
        stackIndex,
        r, g, b, a
      )
      segment:SetStatusBarColor(sr, sg, sb, sa)
    end
  end

  bar.__puiPCMPreviewMaxStacks = bar.maxStacks
  bar.__puiPCMPreviewStackReverse = bar.stackReverse
end

local function PCMPreview_ConfigureChargeSlots(bar, config, zoom, texture)
  local maxCharges = PCMPreview_Clamp(config.maxCharges or 2, 1, 60)
  local r, g, b, a = PCMPreview_GetClassBarColor(
    config,
    { 0.28, 0.67, 0.95, 1 }
  )
  local charge = bar.chargePresentation
  local width = (tonumber(config.width) or 250) * zoom
  local height = (tonumber(config.height) or 25) * zoom

  charge.frame:Show()
  Presentation.Apply("PCMBar", charge, {
    config = config,
    width = width,
    height = height,
    showIcon = config.showIcon == true,
    iconSize = height,
    maxCharges = maxCharges,
    scale = zoom,
    color = { r, g, b, a },
    font = {
      font = config.font,
      size = (config.fontSize or 14) * zoom,
      flags = config.fontOutline or config.outline or "OUTLINE",
      color = config.fontColor,
    },
    visible = true,
    showText = config.showText ~= false,
  }, {
    icon = texture,
  })

  bar.chargeRoot = charge.slotsContainer
  bar.chargeSlots = charge.chargeSlots
  bar.chargeRoot:Show()
  bar.background:Hide()
  bar.status:Hide()
  bar.iconFrame:Hide()
  bar.icon:Hide()
  bar.valueText:Hide()
  charge.timerTextContainer:SetShown(config.showText ~= false)

  bar.__puiPCMPreviewChargeDuration = 5
  bar.__puiPCMPreviewChargeSpendDuration = 0.75
  bar.__puiPCMPreviewChargeDrain = config.durationBarFillMode == "drain"
  bar.__puiPCMPreviewChargeConfig = config
  bar.__puiPCMPreviewMaxCharges = maxCharges
end

local function PCMPreview_ConfigureDurationVisuals(bar, config, entry, zoom)
  local texture = BarWidget.ResolveStatusBarTexture(config.durationTexture or "Pleebar", FALLBACK_BAR_TEXTURE)
  local orientation = config.orientation == "vertical" and "VERTICAL" or "HORIZONTAL"
  local direction = tostring(config.fillDirection or ""):upper()
  local reverseFill = orientation == "VERTICAL" and direction == "DOWN"
    or orientation == "HORIZONTAL" and direction == "LEFT"
  local r, g, b, a = PCMPreview_GetClassBarColor(
    config,
    { 0.28, 0.67, 0.95, 1 }
  )
  local backgroundColor = entry.kind == "stack"
    and { 0.12, 0.12, 0.12, 0.95 }
    or config.backgroundColor
  local borderColor = entry.kind == "stack"
    and { 0.20, 0.20, 0.24, 1 }
    or config.borderColor
  local bgR, bgG, bgB, bgA = PCMPreview_ColorComponents(
    backgroundColor,
    { 0.12, 0.12, 0.12, 0.95 }
  )
  local borderR, borderG, borderB, borderA = PCMPreview_ColorComponents(
    borderColor,
    { 0.20, 0.20, 0.24, 1 }
  )
  local borderSize = PCMPreview_Clamp(config.borderSize or 2, 0, 12)

  if type(config.durationBarColor) == "table" then
    r, g, b, a = PCMPreview_ColorComponents(
      config.durationBarColor,
      { r, g, b, a }
    )
  end

  if entry.kind == "duration" then
    bar.status:SetStatusBarTexture(texture)
    bar.status:SetStatusBarColor(r, g, b, a)
    bar.status:SetOrientation(orientation)
    bar.status:SetReverseFill(reverseFill)
    bar.__puiPCMPreviewDurationStatus = bar.status
    bar.__puiPCMPreviewDurationText = bar.valueText
  elseif bar.__puiPCMPreviewDurationBarEnabled then
    local durationInset = math_max(0, Round(borderSize * zoom))

    bar.durationStatus:ClearAllPoints()
    bar.durationStatus:SetPoint(
      "TOPLEFT",
      bar.durationFrame,
      "TOPLEFT",
      durationInset,
      -durationInset
    )
    bar.durationStatus:SetPoint(
      "BOTTOMRIGHT",
      bar.durationFrame,
      "BOTTOMRIGHT",
      -durationInset,
      durationInset
    )
    bar.durationStatus:SetStatusBarTexture(texture)
    bar.durationStatus:SetStatusBarColor(r, g, b, a)
    bar.durationStatus:SetOrientation(orientation)
    bar.durationStatus:SetReverseFill(reverseFill)
    bar.durationValueText:SetShown(
      config.showText ~= false
        and (tonumber(config.durationCountFontSize) or 0) > 0
    )

    PCMPreview_ApplyFont(
      bar.durationValueText,
      {
        font = config.durationFont,
        size = config.durationCountFontSize or 14,
        flags = config.durationOutline or "OUTLINE",
        color = { 1, 1, 1, 1 },
      },
      "tiny",
      14,
      zoom
    )
    PCMPreview_ApplyBackdrop(
      bar.durationFrame,
      { bgR, bgG, bgB, bgA },
      borderSize > 0 and { borderR, borderG, borderB, borderA }
        or { 0, 0, 0, 0 },
      math_max(1, borderSize * zoom)
    )

    bar.__puiPCMPreviewDurationStatus = bar.durationStatus
    bar.__puiPCMPreviewDurationText = bar.durationValueText
  end

  if bar.__puiPCMPreviewDurationIconEnabled then
    local iconBorderR, iconBorderG, iconBorderB, iconBorderA =
      borderR, borderG, borderB, borderA
    local iconBorderSize = PCMPreview_Clamp(
      config.durationIconBorderSize or borderSize,
      0,
      12
    )

    if type(config.durationIconBorderColor) == "table" then
      iconBorderR, iconBorderG, iconBorderB, iconBorderA =
        PCMPreview_ColorComponents(
          config.durationIconBorderColor,
          { borderR, borderG, borderB, borderA }
        )
    end

    bar.durationIcon:SetTexture(entry.texture)
    bar.durationIcon:SetShown(config.durationHideSpellIcon ~= true)
    bar.durationCooldown:Show()
    bar.durationIconText:SetShown(
      config.showText ~= false
        and (tonumber(config.durationCountFontSize) or 0) > 0
    )
    PCMPreview_ApplyFont(
      bar.durationIconText,
      {
        font = config.durationFont,
        size = config.durationCountFontSize or 14,
        flags = config.durationOutline or "OUTLINE",
        color = { 1, 1, 1, 1 },
      },
      "tiny",
      14,
      zoom
    )
    PCMPreview_ApplyBackdrop(
      bar.durationIconFrame,
      { bgR, bgG, bgB, bgA },
      iconBorderSize > 0
        and { iconBorderR, iconBorderG, iconBorderB, iconBorderA }
        or { 0, 0, 0, 0 },
      math_max(1, iconBorderSize * zoom)
    )

    bar.__puiPCMPreviewDurationIcon = true
  end
end

local function PCMPreview_ConfigureCustomBar(
  bar,
  entry,
  index,
  content,
  yOffset,
  zoom
)
  local config = entry.config

  PCMPreview_ResetCustomBar(bar)

  local displayHeight = PCMPreview_LayoutCustomFrame(
    bar,
    config,
    entry,
    content,
    yOffset,
    zoom
  )
  local orientation = config.orientation == "vertical" and "VERTICAL" or "HORIZONTAL"
  local fillDirection = string_lower(tostring(
    config.fillDirection or "RIGHT"
  ))
  local r, g, b, a = PCMPreview_GetClassBarColor(
    config,
    { 0.28, 0.67, 0.95, 1 }
  )
  local backgroundColor = entry.kind == "stack"
    and { 0.12, 0.12, 0.12, 0.95 }
    or config.backgroundColor
  local borderColor = entry.kind == "stack"
    and { 0.20, 0.20, 0.24, 1 }
    or config.borderColor
  local bgR, bgG, bgB, bgA = PCMPreview_ColorComponents(
    backgroundColor,
    { 0.12, 0.12, 0.12, 0.95 }
  )
  local borderR, borderG, borderB, borderA = PCMPreview_ColorComponents(
    borderColor,
    { 0.20, 0.20, 0.24, 1 }
  )
  local borderSize = PCMPreview_Clamp(
    config.borderSize or config.borderThickness or 2,
    0,
    12
  )
  local previewWidth = (tonumber(config.width) or 250) * zoom
  local previewHeight = (tonumber(config.height) or 25) * zoom

  local textureKey = entry.kind == "stack"
      and (config.stackTexture or "Pleebar")
    or entry.kind == "duration"
      and (config.durationTexture or "Pleebar")
    or (config.texture or "Pleebar")

  Presentation.Apply("PCMBar", bar, {
    config = config,
    skipGeometry = entry.kind ~= "cooldown",
    width = previewWidth,
    height = previewHeight,
    showIcon = config.showIcon == true,
    iconSize = previewHeight,
    scale = zoom,
    texture = textureKey,
    color = { r, g, b, a },
    backgroundColor = { bgR, bgG, bgB, bgA },
    borderColor = { borderR, borderG, borderB, borderA },
    borderSize = borderSize * zoom,
    applyBackground = entry.kind ~= "charge",
    applyBorder = entry.kind ~= "charge",
    font = {
      font = config.font,
      size = (config.fontSize or 14) * zoom,
      flags = config.fontOutline or config.outline or "OUTLINE",
      color = config.fontColor,
    },
    labelFont = {
      font = config.font,
      size = (config.fontSize or 14) * zoom,
      flags = config.fontOutline or config.outline or "OUTLINE",
      color = config.fontColor,
    },
    visible = true,
    showText = entry.kind ~= "charge" and config.showText ~= false,
  }, {
    icon = entry.texture,
    label = entry.title,
  })

  bar.__puiPCMPreviewMode = entry.kind
  bar.__puiPCMPreviewOrientation = orientation
  bar.__puiPCMPreviewDrain = config.direction == "drain"
  bar.__puiPCMPreviewDurationDrain = config.durationBarFillMode ~= "fill"
  bar.__puiPCMPreviewDuration = entry.kind == "stack"
      and 5
    or 14 + index * 3
  bar.__puiPCMPreviewPhaseOffset = index * 1.1

  local valueFont = {
    font = config.font,
    size = config.fontSize or 14,
    flags = config.fontOutline or config.outline,
    color = config.fontColor,
  }

  if entry.kind == "stack" then
    valueFont.flags = config.outline
    valueFont.color = { 1, 1, 1, 1 }
  elseif entry.kind == "duration" then
    valueFont.font = config.durationFont
    valueFont.size = config.durationCountFontSize or 14
    valueFont.flags = config.durationOutline
    valueFont.color = { 1, 1, 1, 1 }
  end

  PCMPreview_ApplyFont(
    bar.valueText,
    valueFont,
    "cooldown",
    valueFont.size,
    zoom
  )

  bar.valueText:ClearAllPoints()

  if entry.kind == "stack" then
    bar.valueText:SetPoint(
      "BOTTOM",
      bar.status,
      "TOP",
      Round((config.fontOffsetX or 0) * zoom),
      Round((2 + (config.fontOffsetY or 0)) * zoom)
    )
    bar.valueText:SetShown((tonumber(config.fontSize) or 0) > 0)
    PCMPreview_ConfigureStackSegments(bar, config, zoom)
    PCMPreview_ConfigureDurationVisuals(bar, config, entry, zoom)
  elseif entry.kind == "charge" then
    PCMPreview_ConfigureChargeSlots(bar, config, zoom, entry.texture)
  elseif entry.kind == "duration" then
    bar.valueText:SetPoint("CENTER", bar.status, "CENTER", 0, 0)
    bar.valueText:SetShown((tonumber(config.durationCountFontSize) or 0) > 0)
    PCMPreview_ConfigureDurationVisuals(bar, config, entry, zoom)
  else
    bar.valueText:SetPoint("CENTER", bar.status, "CENTER", 0, 0)
  end

  local buffGlowSpellID = tonumber(config.buffGlowSpellID)
  if config.buffGlowEnabled == true
    and buffGlowSpellID
    and buffGlowSpellID > 0
  then
    PCMPresentation.ConfigureCustomBarBuffGlowBorder(
      bar.customGlowBorder,
      bar.customGlowFrame,
      config,
      zoom
    )
    bar.__puiPCMPreviewCustomGlowEnabled = true
  end

  return displayHeight
end

local function PCMPreview_ConfigureCustomPanel(box, panel)
  local entries = PCMPreview_GetCustomEntries()
  local content = panel.__puiPCMPreviewContent
  local zoom = PCMPreview_GetDisplayScale(panel)
  local yOffset = 0
  local barEntries = {}
  local iconEntries = {}

  for index = 1, #entries do
    local entry = entries[index]
    if entry.config.presentation == "BAR" then
      barEntries[#barEntries + 1] = entry
    end
    if entry.config.presentation == "BUTTON" then
      iconEntries[#iconEntries + 1] = entry
    end
  end

  PCMPreview_EnsureBarCount(panel, #barEntries)
  PCMPreview_EnsureIconCount(box, panel, #iconEntries)

  for index = 1, #barEntries do
    local displayHeight = PCMPreview_ConfigureCustomBar(
      panel.__puiPCMPreviewBars[index],
      barEntries[index],
      index,
      content,
      yOffset,
      zoom
    )

    yOffset = yOffset + displayHeight + math_max(6, Round(8 * zoom))
  end

  for index = 1, #iconEntries do
    local entry = iconEntries[index]
    local config = entry.config
    local iconConfig = config.icon
    local icon = panel.__puiPCMPreviewIcons[index]
    local size = math_max(20, Round(iconConfig.size * zoom))
    local statefulIcon = entry.kind == "cooldown" or entry.kind == "charge"
    local previewActive = statefulIcon and iconConfig.visibility ~= "INACTIVE"
    local countText = entry.kind == "charge" and iconConfig.showCount == true and (previewActive and "1" or "3")
      or entry.kind == "stack" and iconConfig.showCount == true and "3"
      or ""
    local countdownText = previewActive and iconConfig.showDuration == true and tostring(7 + index) or ""

    Presentation.Apply("PCMIcon", icon, {
      size = size,
      inset = 0,
      backgroundColor = iconConfig.backgroundColor,
      borderColor = iconConfig.borderColor,
      borderSize = iconConfig.chromeStyle == "BLIZZARD" and 0
        or iconConfig.chromeStyle == "SQUARE" and math_max(1, zoom)
        or iconConfig.borderSize * zoom,
      cooldownFont = {
        font = iconConfig.font,
        size = iconConfig.fontSize * iconConfig.durationTextScale / 100 * zoom,
        flags = iconConfig.outline,
        color = iconConfig.durationTextColor,
      },
      chargeFont = {
        font = iconConfig.font,
        size = iconConfig.countFontSize * iconConfig.countTextScale / 100 * zoom,
        flags = iconConfig.outline,
        color = iconConfig.countTextColor,
      },
      visible = true,
    }, {
      icon = entry.texture,
      cooldownText = countdownText,
      chargeText = countText,
      glow = config.buffGlowEnabled == true
        or previewActive and iconConfig.cooldownGlowStyle ~= "NONE"
        or statefulIcon and not previewActive and iconConfig.readyGlowStyle ~= "NONE",
    })

    icon.cooldown:SetDrawSwipe(previewActive and iconConfig.showSwipe == true)
    icon.cooldown:SetShown(previewActive and iconConfig.showSwipe == true)
    icon.cooldownText:SetShown(countdownText ~= "")
    icon.chargeText:SetShown(countText ~= "")
    icon.icon:SetTexCoord(
      iconConfig.chromeStyle == "SQUARE" and 0 or 0.08,
      iconConfig.chromeStyle == "SQUARE" and 1 or 0.92,
      iconConfig.chromeStyle == "SQUARE" and 0 or 0.08,
      iconConfig.chromeStyle == "SQUARE" and 1 or 0.92
    )
    icon.cooldownText:ClearAllPoints()
    icon.cooldownText:SetPoint(
      iconConfig.durationTextAnchor,
      icon.frame,
      iconConfig.durationTextAnchor,
      iconConfig.durationTextX * zoom,
      iconConfig.durationTextY * zoom
    )
    icon.chargeText:ClearAllPoints()
    icon.chargeText:SetPoint(
      iconConfig.countTextAnchor,
      icon.frame,
      iconConfig.countTextAnchor,
      iconConfig.countTextX * zoom,
      iconConfig.countTextY * zoom
    )
    local durationColor = iconConfig.durationTextColor
    icon.cooldownText:SetTextColor(
      durationColor[1] or durationColor.r or 1,
      durationColor[2] or durationColor.g or 1,
      durationColor[3] or durationColor.b or 1,
      durationColor[4] or durationColor.a or 1
    )
    local countColor = iconConfig.countTextColor
    icon.chargeText:SetTextColor(
      countColor[1] or countColor.r or 1,
      countColor[2] or countColor.g or 1,
      countColor[3] or countColor.b or 1,
      countColor[4] or countColor.a or 1
    )
    if not icon.customBlizzardBorder then
      icon.customBlizzardBorder = icon.frame:CreateTexture(nil, "OVERLAY", nil, 7)
      icon.customBlizzardBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
      icon.customBlizzardBorder:SetPoint("TOPLEFT", icon.frame, "TOPLEFT", -12, 12)
      icon.customBlizzardBorder:SetPoint("BOTTOMRIGHT", icon.frame, "BOTTOMRIGHT", 12, -12)
    end
    icon.customBlizzardBorder:SetShown(iconConfig.chromeStyle == "BLIZZARD")
    local previewGlowColor = config.buffGlowEnabled == true and config.buffGlowColor
      or previewActive and iconConfig.cooldownGlowColor
      or iconConfig.readyGlowColor
    icon.glow:SetVertexColor(
      previewGlowColor[1] or previewGlowColor.r or 1,
      previewGlowColor[2] or previewGlowColor.g or 1,
      previewGlowColor[3] or previewGlowColor.b or 1,
      previewGlowColor[4] or previewGlowColor.a or 1
    )
    icon.frame:ClearAllPoints()
    icon.frame:SetPoint(
      "TOP",
      content,
      "TOP",
      0,
      -yOffset
    )
    icon.__puiPCMPreviewLayoutY = yOffset
    icon.frame:SetAlpha(statefulIcon and (previewActive and iconConfig.onCooldownAlpha or iconConfig.readyAlpha) / 100 or 1)
    icon.icon:SetDesaturated(statefulIcon and (
      previewActive and iconConfig.desaturateCooldown == true
        or not previewActive and iconConfig.desaturateReady == true
    ))
    icon.__puiPCMPreviewCooldownEnabled = previewActive and iconConfig.showSwipe == true
    icon.__puiPCMPreviewDuration = 8 + index
    icon.__puiPCMPreviewPhaseOffset = index * 0.7
    icon.__puiPCMPreviewCooldownCycle = nil
    icon.frame:Show()

    if not icon.customLabel then
      icon.customLabel = content:CreateFontString(nil, "OVERLAY")
      Theme.ApplyFont(icon.customLabel, "tiny", 10, "OUTLINE")
    end
    icon.customLabel:ClearAllPoints()
    icon.customLabel:SetPoint("RIGHT", icon.frame, "LEFT", -6, 0)
    icon.customLabel:SetWidth(Round(132 * zoom))
    icon.customLabel:SetJustifyH("RIGHT")
    icon.customLabel:SetText(
      entry.title .. " icon" .. (iconConfig.group > 0 and " (Group " .. tostring(iconConfig.group) .. ")" or "")
    )
    icon.customLabel:Show()

    if not icon.customStrip then
      icon.customStrip = CreateFrame("StatusBar", nil, icon.frame)
      icon.customStrip:SetStatusBarTexture(WHITE_TEXTURE)
      icon.customStrip:SetStatusBarColor(0.25, 0.75, 1, 1)
      icon.customStrip:SetMinMaxValues(0, 3)
    end
    icon.customStrip:ClearAllPoints()
    icon.customStrip:SetPoint("BOTTOMLEFT", icon.frame, "BOTTOMLEFT", 1, 1)
    icon.customStrip:SetPoint("BOTTOMRIGHT", icon.frame, "BOTTOMRIGHT", -1, 1)
    icon.customStrip:SetHeight(math_max(2, Round(3 * zoom)))
    icon.customStrip:SetValue(2)
    icon.customStrip:SetShown(
      entry.kind == "stack" and iconConfig.showStackStrip == true
        or entry.kind == "charge" and iconConfig.showPips == true
    )

    local path = PCMPreview_GetCustomPath(entry)
    PCMPreview_SetInteraction(
      icon.interactions.body,
      entry.title .. " icon",
      "Click to configure this custom button.",
      path,
      "icon",
      "showIcon"
    )

    yOffset = yOffset + size + math_max(6, Round(8 * zoom))
  end

  local rowGap = math_max(6, Round(8 * zoom))
  local totalHeight = math_max(0, yOffset - rowGap)
  local centerOffset = Round(math_max(0, (content:GetHeight() - totalHeight) * 0.5))

  for index = 1, #barEntries do
    local bar = panel.__puiPCMPreviewBars[index]
    bar.frame:ClearAllPoints()
    bar.frame:SetPoint(
      "TOP",
      content,
      "TOP",
      0,
      -(centerOffset + (bar.__puiPCMPreviewLayoutY or 0))
    )
  end

  for index = 1, #iconEntries do
    local icon = panel.__puiPCMPreviewIcons[index]
    icon.frame:ClearAllPoints()
    icon.frame:SetPoint(
      "TOP",
      content,
      "TOP",
      0,
      -(centerOffset + (icon.__puiPCMPreviewLayoutY or 0))
    )
  end
end

local function PCMPreview_ConfigureConsumablesPanel(box, panel)
  local cfg = Cooldowns:GetConsumableTrackerDB()
  local definitions = Cooldowns:GetConsumableTrackerDefinitions()
  local entries = {}

  for index = 1, #definitions do
    local definition = definitions[index]
    local slot = cfg.slots[definition.key]
    if slot.enabled ~= false then
      entries[#entries + 1] = {
        definition = definition,
        slot = slot,
      }
    end
  end

  table_sort(entries, function(left, right)
    return (left.slot.order or 99) < (right.slot.order or 99)
  end)

  local visible = {}
  for index = 1, #entries do
    local entry = entries[index]
    local available = entry.definition.spellIDs ~= nil
      or entry.definition.supportsQuality == true
      or entry.definition.previewAvailable == true
    if available or entry.slot.missing ~= "HIDE" then
      entry.available = available
      visible[#visible + 1] = entry
    end
  end

  PCMPreview_EnsureIconCount(box, panel, #visible)

  local content = panel.__puiPCMPreviewContent
  local count = #visible
  local showCounts = cfg.countVisibility ~= "NEVER"

  if count <= 0 then
    return
  end

  local displayScale = PCMPreview_GetDisplayScale(panel)
  local spacing = Round(math_max(0, tonumber(cfg.spacing) or 4) * displayScale)
  local availableWidth = math_max(1, content:GetWidth())
  local availableHeight = math_max(1, content:GetHeight())
  local configuredSize = PCMPreview_Clamp(cfg.iconSize or 36, 16, 86) * displayScale
  local wrap = math_max(1, math_floor(tonumber(cfg.wrap) or count))
  local horizontal = cfg.orientation ~= "VERTICAL"
  local primaryNegative = cfg.growth == "LEFT" or cfg.growth == "DOWN"
  local primaryCount = math_min(wrap, count)
  local secondaryCount = math_max(1, math_ceil(count / wrap))
  local widthCount = horizontal and primaryCount or secondaryCount
  local heightCount = horizontal and secondaryCount or primaryCount
  local size = math_max(8, Round(configuredSize))
  local totalWidth = widthCount * size + math_max(0, widthCount - 1) * spacing
  local totalHeight = heightCount * size + math_max(0, heightCount - 1) * spacing
  local startX = Round((availableWidth - totalWidth) * 0.5)
  local startY = -Round((availableHeight - totalHeight) * 0.5)

  for index = 1, count do
    local entry = visible[index]
    local definition = entry.definition
    local icon = panel.__puiPCMPreviewIcons[index]
    local itemID = definition.itemIDs and definition.itemIDs[1]
      or definition.equipSlot and GetInventoryItemID("player", definition.equipSlot)
    local spellID = nil
    if definition.spellIDs then
      for spellIndex = 1, #definition.spellIDs do
        local candidate = definition.spellIDs[spellIndex]
        local isKnown = C_SpellBook.IsSpellInSpellBook(candidate)
        if not issecretvalue(isKnown) and isKnown == true then
          spellID = candidate
          break
        end
      end
      spellID = spellID or definition.spellIDs[1]
    end
    local texture = nil
    if not issecretvalue(spellID) and spellID then
      texture = C_Spell.GetSpellTexture(spellID)
    elseif not issecretvalue(itemID) and itemID then
      texture = C_Item.GetItemIconByID(itemID)
    end
    local qualityAtlas = cfg.showItemQuality
      and definition.supportsQuality
      and Cooldowns:GetConsumableItemQualityAtlas(itemID)
      or nil

    Presentation.Apply("PCMIcon", icon, {
      size = size,
      inset = displayScale,
      backgroundColor = cfg.backgroundColor,
      borderColor = cfg.borderColor,
      borderSize = cfg.borderSize * displayScale,
      cooldownFont = {
        font = cfg.font,
        size = Theme.ResolveFontSize(cfg.cooldownFontSize, "cooldownManager") * displayScale,
        flags = "OUTLINE",
      },
      chargeFont = { font = cfg.font, size = cfg.countFontSize * displayScale, flags = "OUTLINE" },
      keybindFont = { font = cfg.font, size = cfg.keybindFontSize * displayScale, flags = "OUTLINE" },
    }, {
      icon = not issecretvalue(texture) and texture or WHITE_TEXTURE,
      cooldownText = cfg.showCooldownText and tostring(8 + index) or "",
      chargeText = showCounts and tostring(index + 1) or "",
      keybindText = cfg.showKeybinds and (index % 2 == 0 and "S" .. index or tostring(index)) or "",
      qualityAtlas = qualityAtlas,
    })

    local zero = index - 1
    local primary = zero % wrap
    local secondary = math_floor(zero / wrap)
    local x
    local y

    if horizontal then
      x = primary * (size + spacing)
      y = -secondary * (size + spacing)
      if primaryNegative then
        x = totalWidth - size - x
      end
    else
      x = secondary * (size + spacing)
      y = -primary * (size + spacing)
      if not primaryNegative then
        y = -totalHeight + size + primary * (size + spacing)
      end
    end

    icon.frame:ClearAllPoints()
    icon.frame:SetPoint(
      "TOPLEFT",
      content,
      "TOPLEFT",
      Round(startX + x),
      Round(startY + y)
    )
    icon.frame:SetAlpha(entry.available and 1 or cfg.missingAlpha)
    icon.icon:SetDesaturated(not entry.available)
    icon.__puiPCMPreviewCooldownEnabled = entry.available
    icon.__puiPCMPreviewDuration = 10 + index
    icon.__puiPCMPreviewPhaseOffset = index * 0.6
    icon.__puiPCMPreviewCooldownCycle = nil
    icon.frame:Show()

    PCMPreview_SetInteraction(
      icon.interactions.body,
      definition.label,
      definition.spellIDs and "Click to configure this tracked ability."
        or "Click to configure this tracked item.",
      { "CooldownManager", "consumables" },
      "slots",
      definition.key
    )
  end
end


local function PCMPreview_EnsureContents(box)
  if box.__puiPCMPreviewContentsReady then
    return
  end

  local canvas = box:GetCanvas()
  local panels = {
    essential = PCMPreview_CreatePanel(
      box,
      canvas,
      "essential",
      "Essential cooldowns"
    ),
    utility = PCMPreview_CreatePanel(
      box,
      canvas,
      "utility",
      "Utility cooldowns"
    ),
    buffs = PCMPreview_CreatePanel(
      box,
      canvas,
      "buffs",
      "Buff icons"
    ),
    buffBars = PCMPreview_CreatePanel(
      box,
      canvas,
      "buffBars",
      "Buff bars"
    ),
    consumables = PCMPreview_CreatePanel(
      box,
      canvas,
      "consumables",
      "Consumable Tracker"
    ),
    custom = PCMPreview_CreatePanel(
      box,
      canvas,
      "custom",
      "Custom trackers"
    ),
  }

  panels.essential.__puiPCMPreviewIcons = {}
  panels.utility.__puiPCMPreviewIcons = {}
  panels.buffs.__puiPCMPreviewIcons = {}
  panels.buffBars.__puiPCMPreviewBars = {}
  panels.consumables.__puiPCMPreviewIcons = {}
  panels.custom.__puiPCMPreviewBars = {}
  panels.custom.__puiPCMPreviewIcons = {}

  box.__puiPCMPreviewPanels = panels
  box.__puiPCMPreviewPanelKey = "essential"
  box.__puiPCMPreviewContentsReady = true
end

local function PCMPreview_Layout(box)
  local canvas = box:GetCanvas()
  local panels = box.__puiPCMPreviewPanels
  local width = math_max(1, canvas:GetWidth())
  local height = math_max(1, canvas:GetHeight())
  local activePanel = panels[box.__puiPCMPreviewPanelKey]

  for _, panel in pairs(panels) do
    panel:ClearAllPoints()
    panel:SetShown(panel == activePanel)
  end

  activePanel:SetAllPoints(canvas)

  box.__puiPCMPreviewCanvasWidth = Round(width)
  box.__puiPCMPreviewCanvasHeight = Round(height)
end

local function PCMPreview_Configure(box)
  local canvas = box:GetCanvas()

  if canvas:GetWidth() < 10 or canvas:GetHeight() < 10 then
    return
  end

  PCMPreview_Layout(box)

  local panels = box.__puiPCMPreviewPanels
  local panelKey = box.__puiPCMPreviewPanelKey

  if panelKey == "essential" then
    PCMPreview_ConfigureViewerPanel(box, panels.essential, VIEWERS[1], DB.GetPCMRoot())
  elseif panelKey == "utility" then
    PCMPreview_ConfigureViewerPanel(box, panels.utility, VIEWERS[2], DB.GetPCMRoot())
  elseif panelKey == "buffs" then
    PCMPreview_ConfigureBuffIconPanel(box, panels.buffs, DB.GetProfileBuffsDB())
  elseif panelKey == "buffBars" then
    PCMPreview_ConfigureBuffBarPanel(panels.buffBars, DB.GetStyleDB())
  elseif panelKey == "consumables" then
    PCMPreview_ConfigureConsumablesPanel(box, panels.consumables)
  elseif panelKey == "custom" then
    PCMPreview_ConfigureCustomPanel(box, panels.custom)
  end
end

local function PCMPreview_UpdateIcon(icon, phase)
  local duration = icon.__puiPCMPreviewDuration or 10
  local elapsed = (phase + (icon.__puiPCMPreviewPhaseOffset or 0)) % duration
  local remaining = math_max(0, duration - elapsed)
  local autoCooldownActive = elapsed < duration * 0.8
  local previewState = icon.__puiPCMPreviewState
  if icon.__puiPCMPreviewStateViewerKey then
    previewState = IconSettings:GetPreviewState(icon.__puiPCMPreviewStateViewerKey)
  end
  local cooldownActive = previewState == "COOLDOWN" or (previewState == nil and autoCooldownActive)
  local auraActive = previewState == "AURA" or icon.__puiPCMPreviewAuraMode == true

  local alpha
  local saturation
  if auraActive then
    alpha = icon.__puiPCMPreviewAuraAlpha or 1
    saturation = icon.__puiPCMPreviewAuraSaturation
  elseif cooldownActive then
    alpha = icon.__puiPCMPreviewCooldownAlpha or 1
    saturation = icon.__puiPCMPreviewCooldownSaturation
  else
    alpha = icon.__puiPCMPreviewReadyAlpha or 1
    saturation = icon.__puiPCMPreviewReadySaturation
  end
  icon.frame:SetAlpha(alpha)
  if icon.icon.SetDesaturation then
    icon.icon:SetDesaturation(
      saturation == nil and 0 or 1 - math_max(0, math_min(1, tonumber(saturation) or 1))
    )
  end

  if icon.__puiPCMPreviewCooldownEnabled then
    local cycle = math_floor(
      (phase + (icon.__puiPCMPreviewPhaseOffset or 0)) / duration
    )

    if cycle ~= icon.__puiPCMPreviewCooldownCycle then
      icon.__puiPCMPreviewCooldownCycle = cycle
      icon.cooldown:SetCooldown(GetTime() - elapsed, duration)
    end
  end

  if icon.cooldownText:IsShown() then
    icon.cooldownText:SetText(tostring(math_ceil(remaining)))
  end

  if icon.chargeText:IsShown() then
    local charge = math_floor(elapsed / math_max(1, duration / 3)) + 1
    icon.chargeText:SetText(tostring(math_min(3, charge)))
  end

  if icon.glow:IsShown() then
    icon.glow:SetAlpha(0.35 + 0.45 * (1 - remaining / duration))
  end
end

local function PCMPreview_UpdateDurationVisuals(bar, phase, duration, elapsed)
  local progress = elapsed / duration
  local remaining = math_max(0, duration - elapsed)
  local status = bar.__puiPCMPreviewDurationStatus
  local text = bar.__puiPCMPreviewDurationText

  if status then
    status:SetMinMaxValues(0, 1)
    status:SetValue(
      bar.__puiPCMPreviewDurationDrain and (1 - progress) or progress
    )
  end

  if text and text:IsShown() then
    text:SetText(string_format("%.0f", remaining))
  end

  if bar.__puiPCMPreviewDurationIcon then
    local cycle = math_floor(
      (phase + (bar.__puiPCMPreviewPhaseOffset or 0)) / duration
    )

    if cycle ~= bar.__puiPCMPreviewDurationCycle then
      bar.__puiPCMPreviewDurationCycle = cycle
      bar.durationCooldown:SetCooldown(GetTime() - elapsed, duration)
    end

    if bar.durationIconText:IsShown() then
      bar.durationIconText:SetText(string_format("%.0f", remaining))
    end
  end
end

local function PCMPreview_UpdateBar(bar, phase)
  if not bar.frame:IsShown() then
    return
  end

  local mode = bar.__puiPCMPreviewMode

  if bar.__puiPCMPreviewCustomGlowEnabled then
    local glowElapsed = (
      phase + (bar.__puiPCMPreviewPhaseOffset or 0)
    ) % 8
    bar.customGlowFrame:SetShown(glowElapsed < 3)
  else
    bar.customGlowFrame:Hide()
  end

  if mode == "charge" then
    local maxCharges = bar.__puiPCMPreviewMaxCharges or 2
    local rechargeDuration = bar.__puiPCMPreviewChargeDuration or 5
    local spendDuration = bar.__puiPCMPreviewChargeSpendDuration or 0.75
    local spendPhase = (maxCharges + 1) * spendDuration
    local cycleDuration = spendPhase + maxCharges * rechargeDuration
    local cycleElapsed = (
      phase + (bar.__puiPCMPreviewPhaseOffset or 0)
    ) % cycleDuration
    local currentCharges
    local activeSlot
    local rechargeProgress = 0

    if cycleElapsed < spendPhase then
      local spendStep = math_floor(cycleElapsed / spendDuration)
      currentCharges = math_max(0, maxCharges - spendStep)
    else
      local rechargeElapsed = cycleElapsed - spendPhase
      local completedCharges = math_min(
        maxCharges,
        math_floor(rechargeElapsed / rechargeDuration)
      )

      currentCharges = completedCharges

      if completedCharges < maxCharges then
        activeSlot = completedCharges + 1
        rechargeProgress = (
          rechargeElapsed - completedCharges * rechargeDuration
        ) / rechargeDuration
      end
    end

    PCMPresentation.ApplyChargeCount(
      bar.chargePresentation,
      currentCharges
    )

    for index = 1, maxCharges do
      local slot = bar.chargeSlots[index]

      if slot then
        local isRecharging = index == activeSlot
        slot.rechargeBar:SetShown(isRecharging)

        if isRecharging then
          slot.rechargeBar:SetMinMaxValues(0, 1)
          slot.rechargeBar:SetValue(
            bar.__puiPCMPreviewChargeDrain
              and (1 - rechargeProgress)
              or rechargeProgress
          )
        end
      end
    end

    PCMPresentation.AnchorChargeTimerText(
      bar.chargePresentation,
      bar.__puiPCMPreviewChargeConfig,
      activeSlot ~= nil
    )

    local chargeText = bar.chargePresentation.timerText
    local showText = bar.__puiPCMPreviewChargeConfig
      and bar.__puiPCMPreviewChargeConfig.showText ~= false
    if showText and activeSlot then
      local remaining = rechargeDuration * (1 - rechargeProgress)
      chargeText:SetText(string_format("%.0f", remaining))
      chargeText:Show()
    else
      chargeText:SetText("")
      chargeText:Hide()
    end

    return
  end

  local duration = bar.__puiPCMPreviewDuration or 15
  local elapsed = (phase + (bar.__puiPCMPreviewPhaseOffset or 0)) % duration
  local progress = elapsed / duration
  local remaining = math_max(0, duration - elapsed)

  if mode == "duration" then
    PCMPreview_UpdateDurationVisuals(bar, phase, duration, elapsed)
  elseif mode == "cooldown" then
    bar.status:SetMinMaxValues(0, 1)
    bar.status:SetValue(
      bar.__puiPCMPreviewDrain and (1 - progress) or progress
    )
    bar.valueText:SetText(string_format("%.0f", remaining))
  elseif mode == "stack" then
    local maxStacks = bar.__puiPCMPreviewMaxStacks or 3
    local stepDuration = 0.6
    local step = math_floor(
      (phase + (bar.__puiPCMPreviewPhaseOffset or 0)) / stepDuration
    )
    local cycleLength = math_max(1, maxStacks * 2)
    local cycleStep = step % cycleLength
    local stacks = cycleStep <= maxStacks
      and cycleStep
      or cycleLength - cycleStep

    for index = 1, maxStacks do
      local segment = bar.stackSegments[index]

      if segment then
        local fillIndex = bar.__puiPCMPreviewStackReverse
          and (maxStacks - index + 1)
          or index

        segment:SetValue(fillIndex <= stacks and 1 or 0)
      end
    end

    if bar.valueText:IsShown() then
      bar.valueText:SetText(tostring(stacks))
    end

    PCMPreview_UpdateDurationVisuals(bar, phase, duration, elapsed)
  end
end

local function PCMPreview_UpdateAnimation(box)
  local phase = box.__puiPCMPreviewPhase or 0
  local panels = box.__puiPCMPreviewPanels
  local panelKey = box.__puiPCMPreviewPanelKey

  if panelKey == "essential"
    or panelKey == "utility"
    or panelKey == "buffs"
    or panelKey == "consumables"
  then
    local panel = panels[panelKey]
    local icons = panel.__puiPCMPreviewIcons
    local count = panel.__puiPCMPreviewVisibleIconCount or #icons

    for index = 1, count do
      PCMPreview_UpdateIcon(icons[index], phase)
    end
    return
  end

  if panelKey == "buffBars" then
    local bars = panels.buffBars.__puiPCMPreviewBars
    for index = 1, #bars do
      PCMPreview_UpdateBar(bars[index], phase)
    end
    return
  end

  if panelKey == "custom" then
    local panel = panels.custom
    local barCount = panel.__puiPCMPreviewVisibleBarCount or 0
    local iconCount = panel.__puiPCMPreviewVisibleIconCount or 0

    for index = 1, barCount do
      PCMPreview_UpdateBar(panel.__puiPCMPreviewBars[index], phase)
    end

    for index = 1, iconCount do
      PCMPreview_UpdateIcon(panel.__puiPCMPreviewIcons[index], phase)
    end
  end
end

local function PCMPreview_OnUpdate(box, elapsed)
  box.__puiPCMPreviewPhase = (box.__puiPCMPreviewPhase or 0) + elapsed
  box.__puiPCMPreviewAnimationElapsed =
    (box.__puiPCMPreviewAnimationElapsed or 0) + elapsed

  if box.__puiPCMPreviewAnimationElapsed >= 0.05 then
    box.__puiPCMPreviewAnimationElapsed = 0
    PCMPreview_UpdateAnimation(box)
  end
end

function PCMPreview.RefreshBox(box)
  if not box
    or not box:IsShown()
    or not box.__puiPCMPreviewContentsReady
  then
    return
  end

  PCMPreview_Configure(box)
  PCMPreview_UpdateAnimation(box)
end

function PCMPreview.Refresh()
  for box in pairs(PCMPreviewBoxes) do
    PCMPreview.RefreshBox(box)
  end
end

function PCMPreview.Build(addon, frame, shell, path)
  local previewHost = shell.previewHost
  local box = frame.__puiPCMPreviewBox

  if not box then
    box = PreviewBox.Create(previewHost)
    frame.__puiPCMPreviewBox = box

    box:SetTitle("Cooldown Manager preview")
    box:SetDescription(
      "100% zoom matches the in-game widget size. Click an icon to open its settings."
    )

    PCMPreview_EnsureContents(box)
    box:SetScript("OnUpdate", PCMPreview_OnUpdate)

    local canvas = box:GetCanvas()
    canvas:HookScript("OnSizeChanged", function()
      PCMPreview.RefreshBox(box)
    end)

    PCMPreviewBoxes[box] = true
  end

  local activeTab = type(path) == "table"
    and path[1] == "CooldownManager"
    and path[2]
    or "cooldowns_essential"
  local previewState = shell:GetPreviewState()
  if type(previewState.pcmZooms) ~= "table" then
    previewState.pcmZooms = {}
  end

  box.__puiPCMPreviewPanelKey = PREVIEW_PANEL_BY_TAB[activeTab] or "essential"
  box.__puiPCMPreviewState = previewState

  for key, panel in pairs(box.__puiPCMPreviewPanels) do
    local zoom = PCMPreview_Clamp(previewState.pcmZooms[key] or 1, 0.25, 2)

    panel.__puiPCMPreviewZoom = zoom
    panel.__puiPCMPreviewZoomControl:SetZoom(zoom)
  end

  box:SetParent(previewHost)
  box:ClearAllPoints()
  box:SetPoint("TOPLEFT", previewHost, "TOPLEFT", 0, 0)
  box:SetPoint("TOPRIGHT", previewHost, "TOPRIGHT", 0, 0)
  box:SetPoint("BOTTOMRIGHT", previewHost, "BOTTOMRIGHT", 0, 0)

  local boxLevel = previewHost:GetFrameLevel() + 1
  local canvas = box:GetCanvas()

  box:SetFrameStrata(previewHost:GetFrameStrata())
  box:SetFrameLevel(boxLevel)

  if box._puiBg then
    box._puiBg:SetFrameStrata(box:GetFrameStrata())
    box._puiBg:SetFrameLevel(math_max(0, boxLevel - 1))
  end

  canvas:SetFrameStrata(box:GetFrameStrata())
  canvas:SetFrameLevel(boxLevel + 1)

  if canvas._puiBg then
    canvas._puiBg:SetFrameStrata(canvas:GetFrameStrata())
    canvas._puiBg:SetFrameLevel(boxLevel)
  end

  canvas:SetClipsChildren(true)

  box.__puiPCMPreviewAddon = addon
  box:Show()
  PCMPreview.RefreshBox(box)

  return true
end

PCMPreview_Clamp = P:Def("Clamp", PCMPreview_Clamp)
PCMPreview_GetDisplayScale = P:Def("GetDisplayScale", PCMPreview_GetDisplayScale)
PCMPreview_ColorComponents = P:Def("ColorComponents", PCMPreview_ColorComponents)
PCMPreview_GetSafeSpellTexture = P:Def("GetSafeSpellTexture", PCMPreview_GetSafeSpellTexture)
PCMPreview_GetFontConfig = P:Def("GetFontConfig", PCMPreview_GetFontConfig)
PCMPreview_ApplyFont = P:Def("ApplyFont", PCMPreview_ApplyFont)
PCMPreview_ApplyBackdrop = P:Def("ApplyBackdrop", PCMPreview_ApplyBackdrop)
PCMPreview_Navigate = P:Def("Navigate", PCMPreview_Navigate)
PCMPreview_SetInteraction = P:Def("SetInteraction", PCMPreview_SetInteraction)
PCMPreview_CreateInteraction = P:Def("CreateInteraction", PCMPreview_CreateInteraction)
PCMPreview_CreatePanel = P:Def("CreatePanel", PCMPreview_CreatePanel)
PCMPreview_CreateIcon = P:Def("CreateIcon", PCMPreview_CreateIcon)
PCMPreview_CreateBar = P:Def("CreateBar", PCMPreview_CreateBar)
PCMPreview_EnsureIconCount = P:Def("EnsureIconCount", PCMPreview_EnsureIconCount)
PCMPreview_EnsureBarCount = P:Def("EnsureBarCount", PCMPreview_EnsureBarCount)
PCMPreview_GetViewerStyle = P:Def("GetViewerStyle", PCMPreview_GetViewerStyle)
PCMPreview_GetViewerBorder = P:Def("GetViewerBorder", PCMPreview_GetViewerBorder)
PCMPreview_GetIconBorder = P:Def("GetIconBorder", PCMPreview_GetIconBorder)
PCMPreview_GetViewerCounts = P:Def("GetViewerCounts", PCMPreview_GetViewerCounts)
PCMPreview_GetViewerSwipe = P:Def("GetViewerSwipe", PCMPreview_GetViewerSwipe)
PCMPreview_GetEffectiveIconText = P:Def("GetEffectiveIconText", PCMPreview_GetEffectiveIconText)
PCMPreview_GetEffectiveIconSwipe = P:Def("GetEffectiveIconSwipe", PCMPreview_GetEffectiveIconSwipe)
PCMPreview_LayoutViewerIcons = P:Def("LayoutViewerIcons", PCMPreview_LayoutViewerIcons)
PCMPreview_ConfigureViewerPanel = P:Def("ConfigureViewerPanel", PCMPreview_ConfigureViewerPanel)
PCMPreview_ConfigureBuffIconPanel = P:Def("ConfigureBuffIconPanel", PCMPreview_ConfigureBuffIconPanel)
PCMPreview_ConfigureBuffBarPanel = P:Def("ConfigureBuffBarPanel", PCMPreview_ConfigureBuffBarPanel)
PCMPreview_SortedKeys = P:Def("SortedKeys", PCMPreview_SortedKeys)
PCMPreview_GetCustomEntries = P:Def("GetCustomEntries", PCMPreview_GetCustomEntries)
PCMPreview_GetCustomPath = P:Def("GetCustomPath", PCMPreview_GetCustomPath)
PCMPreview_GetClassBarColor = P:Def("GetClassBarColor", PCMPreview_GetClassBarColor)
PCMPreview_EnsureStackSegments = P:Def("EnsureStackSegments", PCMPreview_EnsureStackSegments)
PCMPreview_EnsureChargeSlots = P:Def("EnsureChargeSlots", PCMPreview_EnsureChargeSlots)
PCMPreview_ResetCustomBar = P:Def("ResetCustomBar", PCMPreview_ResetCustomBar)
PCMPreview_LayoutCustomFrame = P:Def("LayoutCustomFrame", PCMPreview_LayoutCustomFrame)
PCMPreview_ConfigureStackSegments = P:Def("ConfigureStackSegments", PCMPreview_ConfigureStackSegments)
PCMPreview_ConfigureChargeSlots = P:Def("ConfigureChargeSlots", PCMPreview_ConfigureChargeSlots)
PCMPreview_ConfigureCustomBar = P:Def("ConfigureCustomBar", PCMPreview_ConfigureCustomBar)
PCMPreview_ConfigureCustomPanel = P:Def("ConfigureCustomPanel", PCMPreview_ConfigureCustomPanel)
PCMPreview_EnsureContents = P:Def("EnsureContents", PCMPreview_EnsureContents)
PCMPreview_Layout = P:Def("Layout", PCMPreview_Layout)
PCMPreview_Configure = P:Def("Configure", PCMPreview_Configure)
PCMPreview_UpdateIcon = P:Def("UpdateIcon", PCMPreview_UpdateIcon)
PCMPreview_UpdateDurationVisuals = P:Def("UpdateDurationVisuals", PCMPreview_UpdateDurationVisuals)
PCMPreview_UpdateBar = P:Def("UpdateBar", PCMPreview_UpdateBar)
PCMPreview_UpdateAnimation = P:Def("UpdateAnimation", PCMPreview_UpdateAnimation)
PCMPreview_OnUpdate = P:Def("OnUpdate", PCMPreview_OnUpdate)
PCMPreview.Build = P:Def("Build", PCMPreview.Build)
