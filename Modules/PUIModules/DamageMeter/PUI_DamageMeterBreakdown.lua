local _, ns = ...

local Theme = ns.Theme
local DamageMeters = ns.Modules.DamageMeters
local Breakdown = ns.DamageMeterBreakdown
local Config = ns.DamageMeterConfig
local Sessions = ns.DamageMeterSessions
local Windows = ns.DamageMeterWindows
local Constants = ns.DamageMeterConstants
local P = ns.DamageMeterProfiler

local _G = _G
local UIParent = _G.UIParent
local CreateFrame = _G.CreateFrame
local C_DeathRecap = _G.C_DeathRecap
local C_Spell = _G.C_Spell
local C_Timer = _G.C_Timer
local Enum = _G.Enum
local GameTooltip = _G.GameTooltip
local InCombatLockdown = _G.InCombatLockdown
local ScrollBoxConstants = _G.ScrollBoxConstants
local Ambiguate = _G.Ambiguate
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local AbbreviateNumbers = _G.AbbreviateNumbers
local UnitGUID = _G.UnitGUID
local UnitName = _G.UnitName
local math_abs = _G.math.abs
local math_max = _G.math.max
local math_min = _G.math.min
local pairs = _G.pairs
local string_format = _G.string.format
local table_concat = _G.table.concat
local table_sort = _G.table.sort
local type = _G.type

local BREAKDOWN_ROW_POOL_SIZE = Constants.BREAKDOWN_ROW_POOL_SIZE
local CLOSE_TEXTURE = Constants.CLOSE_TEXTURE
local METER_TYPES = Constants.METER_TYPES
local METER_NAMES = Constants.METER_NAMES
local SESSION_TYPES = Constants.SESSION_TYPES
local IsSecret = ns.DamageMeterUtil.IsSecret
local IsCountMeter = ns.DamageMeterUtil.IsCountMeter
local IsDeathMeter = ns.DamageMeterUtil.IsDeathMeter
local IsRatePrimaryMeter = ns.DamageMeterUtil.IsRatePrimaryMeter
local Round = ns.Pixel.Round
local Clamp = ns.DamageMeterUtil.Clamp
local GetViewportRowCount = ns.DamageMeterUtil.GetViewportRowCount
local GetWindowDB = Config.GetWindowDB
local GetWindowSelection = Sessions.GetWindowSelection
local IsHistorySelection = Sessions.IsHistorySelection
local IsAvailableSessionSelection = Sessions.IsAvailableSessionSelection
local GetSessionStateKey = Sessions.GetSessionStateKey
local GetCombatSession = Sessions.GetCombatSession
local GetCombatSessionSource = Sessions.GetCombatSessionSource
local GetBlizzardSessionID = Sessions.GetBlizzardSessionID
local GetSessionDisplay = Sessions.GetSessionDisplay
local SetNumericText = Sessions.SetNumericText
local CreateTextureButton = Windows.CreateTextureButton
local SetHeaderButtonTooltip = Windows.SetHeaderButtonTooltip
local ShowMeterNavigation = Windows.ShowMeterNavigation
local RANK_TEXT = Windows.RANK_TEXT

function Breakdown.GetDB()
  return DamageMeters.db.profile.breakdown
end

function Breakdown.IsSourceBlocked()
  return InCombatLockdown()
    or DamageMeters.playerInCombat
    or DamageMeters.waitingForGroupCombatEnd
end

function Breakdown.ShowSourceUnavailableTooltip(row)
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText("Damage breakdown")
  GameTooltip:AddLine(
    "Detailed information for other sources is secret while in combat.",
    0.78,
    0.78,
    0.78,
    true
  )
  GameTooltip:Show()
end

function Breakdown.SavePosition(breakdown)
  local frameX, frameY = breakdown.frame:GetCenter()
  local parentX, parentY = UIParent:GetCenter()
  if not frameX or not frameY or not parentX or not parentY then
    return
  end

  local db = Breakdown.GetDB()
  db.x = Round(frameX - parentX)
  db.y = Round(frameY - parentY)
end

function Breakdown.CancelTransientClose()
  local breakdown = DamageMeters.breakdown
  if breakdown then
    breakdown.hoverSerial = (breakdown.hoverSerial or 0) + 1
  end
end

function Breakdown.ScheduleTransientClose(row)
  local breakdown = DamageMeters.breakdown
  if not breakdown or breakdown.pinned then
    return
  end

  breakdown.hoverSerial = (breakdown.hoverSerial or 0) + 1
  local serial = breakdown.hoverSerial

  C_Timer.After(0.10, function()
    if not DamageMeters.breakdown or DamageMeters.breakdown ~= breakdown then
      return
    end
    if breakdown.hoverSerial ~= serial or breakdown.pinned then
      return
    end
    if breakdown.frame:IsMouseOver() then
      return
    end
    if breakdown.targetFrame and breakdown.targetFrame:IsMouseOver() then
      return
    end
    if row and row:IsMouseOver() then
      return
    end

    Breakdown.Close()
  end)
end

function Breakdown.CreateRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row:RegisterForClicks("RightButtonUp")
  row:EnableMouse(true)
  row:Hide()

  local background = row:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(row)
  row.background = background

  local fill = CreateFrame("StatusBar", nil, row)
  fill:SetAllPoints(row)
  fill:SetMinMaxValues(0, 1)
  fill:SetValue(0)
  row.fill = fill

  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints(row)
  highlight:SetColorTexture(1, 1, 1, 0.08)

  local textLayer = CreateFrame("Frame", nil, row)
  textLayer:SetAllPoints(row)
  textLayer:SetFrameLevel(fill:GetFrameLevel() + 2)

  local rank = textLayer:CreateFontString(nil, "OVERLAY")
  rank:SetPoint("LEFT", textLayer, "LEFT", 5, 0)
  rank:SetWidth(24)
  rank:SetJustifyH("LEFT")
  row.rank = rank

  local icon = textLayer:CreateTexture(nil, "ARTWORK")
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  icon:Hide()
  row.icon = icon

  local name = textLayer:CreateFontString(nil, "OVERLAY")
  name:SetJustifyH("LEFT")
  name:SetWordWrap(false)
  row.name = name

  local amountHost = CreateFrame("Frame", nil, textLayer)
  amountHost:SetPoint("TOPRIGHT", textLayer, "TOPRIGHT", -5, 0)
  amountHost:SetPoint("BOTTOMRIGHT", textLayer, "BOTTOMRIGHT", -5, 0)
  amountHost:SetWidth(190)
  row.amountHost = amountHost

  local percent = amountHost:CreateFontString(nil, "OVERLAY")
  percent:SetPoint("RIGHT", amountHost, "RIGHT", 0, 0)
  percent:SetJustifyH("RIGHT")
  row.percent = percent

  local secondarySuffix = amountHost:CreateFontString(nil, "OVERLAY")
  secondarySuffix:SetPoint("RIGHT", percent, "LEFT", -6, 0)
  secondarySuffix:SetJustifyH("RIGHT")
  row.secondarySuffix = secondarySuffix

  local secondaryAmount = amountHost:CreateFontString(nil, "OVERLAY")
  secondaryAmount:SetPoint("RIGHT", secondarySuffix, "LEFT", 0, 0)
  secondaryAmount:SetJustifyH("RIGHT")
  row.secondaryAmount = secondaryAmount

  local amountSeparator = amountHost:CreateFontString(nil, "OVERLAY")
  amountSeparator:SetPoint("RIGHT", secondaryAmount, "LEFT", -3, 0)
  amountSeparator:SetJustifyH("RIGHT")
  row.amountSeparator = amountSeparator

  local primarySuffix = amountHost:CreateFontString(nil, "OVERLAY")
  primarySuffix:SetPoint("RIGHT", amountSeparator, "LEFT", -3, 0)
  primarySuffix:SetJustifyH("RIGHT")
  row.primarySuffix = primarySuffix

  local primaryAmount = amountHost:CreateFontString(nil, "OVERLAY")
  primaryAmount:SetPoint("RIGHT", primarySuffix, "LEFT", 0, 0)
  primaryAmount:SetJustifyH("RIGHT")
  row.primaryAmount = primaryAmount

  row:SetScript("OnEnter", function(self)
    local db = Breakdown.GetDB()
    local spellID = self.spellID
    if self.deathEvent then
      Breakdown.ShowDeathRecapTooltip(self)
    elseif db.showSpellTooltips and spellID then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetSpellByID(spellID)
      GameTooltip:Show()
    elseif self.targetRow then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Damage to target")
      GameTooltip:AddLine(
        "Target totals are available after combat.",
        0.78,
        0.78,
        0.78,
        true
      )
      GameTooltip:Show()
    elseif self.enemyPlayerRow then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Damage from player")
      GameTooltip:AddLine(
        "Damage this player dealt to the selected enemy.",
        0.78,
        0.78,
        0.78,
        true
      )
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", function(self)
    if GameTooltip:IsOwned(self) then
      GameTooltip:Hide()
    end
  end)
  row:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      local selection = DamageMeters.breakdownSelection
      Breakdown.NavigateBack(selection and selection.ownerWindow or nil)
    end
  end)

  return row
end

function Breakdown.EnsureRow(breakdown, index)
  local row = breakdown.rows[index]
  if row then
    return row, false
  end

  row = Breakdown.CreateRow(breakdown.viewport)
  breakdown.rows[index] = row
  return row, true
end

function Breakdown.EnsureTargetRow(breakdown, index)
  local row = breakdown.targetRows[index]
  if row then
    return row, false
  end

  row = Breakdown.CreateRow(breakdown.targetViewport)
  breakdown.targetRows[index] = row
  return row, true
end

function Breakdown.Ensure()
  if DamageMeters.breakdown then
    return DamageMeters.breakdown
  end

  local breakdown = {
    rows = {},
    targetRows = {},
    firstSpell = 1,
    firstTarget = 1,
    sourceCount = 0,
    targetCount = 0,
    usedRows = 0,
    usedTargetRows = 0,
    pinned = false,
    hoverSerial = 0,
  }

  local frame = CreateFrame("Frame", "PUI_DamageMeterBreakdown", UIParent)
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(50)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:Hide()
  breakdown.frame = frame

  local header = CreateFrame("Frame", nil, frame)
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
  header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  breakdown.header = header

  local headerBackground = header:CreateTexture(nil, "BACKGROUND")
  headerBackground:SetAllPoints(header)
  breakdown.headerBackground = headerBackground

  local headerBorder = header:CreateTexture(nil, "BORDER")
  headerBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
  headerBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
  headerBorder:SetHeight(1)
  breakdown.headerBorder = headerBorder

  local title = header:CreateFontString(nil, "OVERLAY")
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  breakdown.title = title

  local subtitle = header:CreateFontString(nil, "OVERLAY")
  subtitle:SetJustifyH("LEFT")
  subtitle:SetWordWrap(false)
  breakdown.subtitle = subtitle

  local closeButton = CreateTextureButton(header, CLOSE_TEXTURE)
  SetHeaderButtonTooltip(closeButton, "Close breakdown", "Close the selected source breakdown.")
  closeButton:SetScript("OnClick", function()
    Breakdown.Close()
  end)
  breakdown.closeButton = closeButton


  header:SetScript("OnDragStart", function()
    if ns.Flags.IsEditing then
      return
    end

    local db = Breakdown.GetDB()
    if db.position ~= "FLOATING" then
      Breakdown.SavePosition(breakdown)
      db.position = "FLOATING"
      Breakdown.ApplyPosition(breakdown)
    end

    breakdown.pinned = true
    Breakdown.CancelTransientClose()
    frame:StartMoving()
  end)
  header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    Breakdown.SavePosition(breakdown)
    Breakdown.ApplyPosition(breakdown)
  end)

  frame:SetScript("OnEnter", function()
    Breakdown.CancelTransientClose()
  end)
  frame:SetScript("OnLeave", function()
    Breakdown.ScheduleTransientClose(DamageMeters.breakdownSelection and DamageMeters.breakdownSelection.ownerRow)
  end)

  local viewport = CreateFrame("Frame", nil, frame)
  viewport:SetClipsChildren(true)
  viewport:EnableMouse(true)
  viewport:EnableMouseWheel(true)
  breakdown.viewport = viewport

  viewport:SetScript("OnMouseWheel", function(_, delta)
    local visibleCount = breakdown.visibleRowCount or 1
    local maximumFirstSpell = math_max(1, breakdown.sourceCount - visibleCount + 1)
    breakdown.firstSpell = Clamp((breakdown.firstSpell or 1) - delta, 1, maximumFirstSpell)
    Breakdown.Refresh()
  end)

  local emptyText = viewport:CreateFontString(nil, "OVERLAY")
  emptyText:SetPoint("CENTER", viewport, "CENTER", 0, 0)
  Theme.ApplyFont(emptyText, "body", DamageMeters.db.profile.fontSize, "OUTLINE")
  emptyText:SetText("No breakdown data")
  breakdown.emptyText = emptyText

  local liveSourceWindow = CreateFrame(
    "Frame",
    "PUI_DamageMeterLiveEnemyPlayers",
    frame,
    "DamageMeterSourceWindowTemplate"
  )
  liveSourceWindow:SetFrameStrata("DIALOG")
  liveSourceWindow:SetFrameLevel(frame:GetFrameLevel() + 2)
  liveSourceWindow:SetClampedToScreen(true)
  liveSourceWindow:SetSticky(true)
  liveSourceWindow.Background:Hide()
  liveSourceWindow.CloseButton:Hide()
  liveSourceWindow.CloseButton:EnableMouse(false)
  liveSourceWindow.ResizeButton:Hide()
  liveSourceWindow.ResizeButton:EnableMouse(false)
  liveSourceWindow:Hide()
  breakdown.liveSourceWindow = liveSourceWindow

  local targetFrame = CreateFrame("Frame", "PUI_DamageMeterTargets", UIParent)
  targetFrame:SetFrameStrata("DIALOG")
  targetFrame:SetFrameLevel(50)
  targetFrame:SetClampedToScreen(true)
  targetFrame:EnableMouse(true)
  targetFrame:Hide()
  breakdown.targetFrame = targetFrame

  targetFrame:SetScript("OnEnter", function()
    Breakdown.CancelTransientClose()
  end)
  targetFrame:SetScript("OnLeave", function()
    Breakdown.ScheduleTransientClose(DamageMeters.breakdownSelection and DamageMeters.breakdownSelection.ownerRow)
  end)

  local targetHeader = CreateFrame("Frame", nil, targetFrame)
  targetHeader:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", 2, -2)
  targetHeader:SetPoint("TOPRIGHT", targetFrame, "TOPRIGHT", -2, -2)
  breakdown.targetHeader = targetHeader

  local targetHeaderBackground = targetHeader:CreateTexture(nil, "BACKGROUND")
  targetHeaderBackground:SetAllPoints(targetHeader)
  breakdown.targetHeaderBackground = targetHeaderBackground

  local targetHeaderBorder = targetHeader:CreateTexture(nil, "BORDER")
  targetHeaderBorder:SetPoint("BOTTOMLEFT", targetHeader, "BOTTOMLEFT", 0, 0)
  targetHeaderBorder:SetPoint("BOTTOMRIGHT", targetHeader, "BOTTOMRIGHT", 0, 0)
  targetHeaderBorder:SetHeight(1)
  breakdown.targetHeaderBorder = targetHeaderBorder

  local targetTitle = targetHeader:CreateFontString(nil, "OVERLAY")
  targetTitle:SetJustifyH("LEFT")
  targetTitle:SetWordWrap(false)
  breakdown.targetTitle = targetTitle

  local targetViewport = CreateFrame("Frame", nil, targetFrame)
  targetViewport:SetClipsChildren(true)
  targetViewport:EnableMouse(true)
  targetViewport:EnableMouseWheel(true)
  breakdown.targetViewport = targetViewport

  targetViewport:SetScript("OnMouseWheel", function(_, delta)
    local visibleCount = breakdown.targetVisibleRowCount or 1
    local maximumFirstTarget = math_max(1, breakdown.targetCount - visibleCount + 1)
    breakdown.firstTarget = Clamp((breakdown.firstTarget or 1) - delta, 1, maximumFirstTarget)
    Breakdown.Refresh()
  end)

  DamageMeters.breakdown = breakdown
  return breakdown
end

function Breakdown.ApplyPosition(breakdown)
  local selection = DamageMeters.breakdownSelection
  local db = Breakdown.GetDB()
  local frame = breakdown.frame

  frame:ClearAllPoints()

  if db.position == "FLOATING" or not selection or not selection.ownerWindow then
    frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
  else
    local ownerFrame = selection.ownerWindow.frame
    local ownerCenterX = ownerFrame:GetCenter()
    local screenCenterX = UIParent:GetCenter()
    if ownerCenterX and screenCenterX and ownerCenterX >= screenCenterX then
      frame:SetPoint("TOPRIGHT", ownerFrame, "TOPLEFT", -4, 0)
    else
      frame:SetPoint("TOPLEFT", ownerFrame, "TOPRIGHT", 4, 0)
    end
  end

  breakdown.targetFrame:ClearAllPoints()
  breakdown.targetFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
end

function Breakdown.ApplyRowStyle(row, viewport, index, db, breakdownDB, colors, barTexture)
  local barHeight = db.barHeight
  local fontSize = db.fontSize
  local rowStride = barHeight + db.barSpacing

  row:SetHeight(barHeight)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, -((index - 1) * rowStride))
  row:SetPoint("TOPRIGHT", viewport, "TOPRIGHT", 0, -((index - 1) * rowStride))

  row.fill:SetStatusBarTexture(barTexture)
  row.fill:SetAlpha(db.barAlpha)
  row.background:SetColorTexture(
    colors.control[1],
    colors.control[2],
    colors.control[3],
    0.48
  )

  Theme.ApplyFont(row.rank, "tiny", math_max(8, fontSize - 1), "OUTLINE")
  Theme.ApplyFont(row.name, "body", fontSize, "OUTLINE")
  Theme.ApplyFont(row.primaryAmount, "body", fontSize, "OUTLINE")
  Theme.ApplyFont(row.primarySuffix, "tiny", math_max(8, fontSize - 2), "OUTLINE")
  Theme.ApplyFont(row.amountSeparator, "tiny", math_max(8, fontSize - 2), "OUTLINE")
  Theme.ApplyFont(row.secondaryAmount, "body", fontSize, "OUTLINE")
  Theme.ApplyFont(row.secondarySuffix, "tiny", math_max(8, fontSize - 2), "OUTLINE")
  Theme.ApplyFont(row.percent, "tiny", math_max(8, fontSize - 2), "OUTLINE")

  row.rank:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.82)
  row.name:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 1)
  row.primaryAmount:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 1)
  row.primarySuffix:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.72)
  row.amountSeparator:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.55)
  row.secondaryAmount:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.78)
  row.secondarySuffix:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.62)
  row.percent:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.62)

  row.icon:ClearAllPoints()
  row.icon:SetPoint("LEFT", row, "LEFT", 29, 0)
  row.icon:SetSize(barHeight - 4, barHeight - 4)

  row.name:ClearAllPoints()
  if breakdownDB.showIcons then
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
  else
    row.name:SetPoint("LEFT", row, "LEFT", 30, 0)
  end
  row.name:SetPoint("RIGHT", row.amountHost, "LEFT", -8, 0)
end

function Breakdown.ApplyStyle(breakdown)
  local db = DamageMeters.db.profile
  local breakdownDB = db.breakdown
  local colors = Theme.GetColors()
  local barTexture = Theme.GetBarTexture()
  local headerHeight = db.headerHeight
  local buttonSize = math_min(22, headerHeight - 6)
  local fontSize = db.fontSize

  breakdown.frame:SetSize(breakdownDB.width, breakdownDB.height)
  Theme.SetSquareBackdrop(breakdown.frame, {
    bg = colors.background,
    border = colors.border,
  }, 2)

  breakdown.header:SetHeight(headerHeight)
  breakdown.headerBackground:SetColorTexture(
    colors.background[1],
    colors.background[2],
    colors.background[3],
    colors.background[4]
  )
  breakdown.headerBorder:SetColorTexture(
    colors.border[1],
    colors.border[2],
    colors.border[3],
    colors.border[4]
  )

  breakdown.closeButton:SetSize(buttonSize, buttonSize)
  breakdown.closeButton:ClearAllPoints()
  breakdown.closeButton:SetPoint("RIGHT", breakdown.header, "RIGHT", -4, 0)

  Theme.ApplyFont(breakdown.title, "header", fontSize + 1, "OUTLINE")
  Theme.ApplyFont(breakdown.subtitle, "tiny", math_max(8, fontSize - 2), "OUTLINE")
  breakdown.title:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  breakdown.subtitle:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.72)

  breakdown.title:ClearAllPoints()
  breakdown.title:SetPoint("TOPLEFT", breakdown.header, "TOPLEFT", 8, -3)
  breakdown.title:SetPoint("RIGHT", breakdown.closeButton, "LEFT", -6, 0)

  breakdown.subtitle:ClearAllPoints()
  breakdown.subtitle:SetPoint("BOTTOMLEFT", breakdown.header, "BOTTOMLEFT", 8, 3)
  breakdown.subtitle:SetPoint("RIGHT", breakdown.closeButton, "LEFT", -6, 0)

  breakdown.viewport:ClearAllPoints()
  breakdown.viewport:SetPoint("TOPLEFT", breakdown.header, "BOTTOMLEFT", 4, -4)
  breakdown.viewport:SetPoint("BOTTOMRIGHT", breakdown.frame, "BOTTOMRIGHT", -4, 4)

  Theme.ApplyFont(breakdown.emptyText, "body", fontSize, "OUTLINE")
  breakdown.emptyText:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.62)

  local liveSourceWindow = breakdown.liveSourceWindow
  liveSourceWindow:ClearAllPoints()
  liveSourceWindow:SetPoint("TOPLEFT", breakdown.header, "BOTTOMLEFT", 4, -4)
  liveSourceWindow:SetPoint("BOTTOMRIGHT", breakdown.frame, "BOTTOMRIGHT", -4, 4)
  liveSourceWindow:SetUseClassColor(true)
  liveSourceWindow:SetBarHeight(db.barHeight)
  liveSourceWindow:SetTextScale(fontSize / 12)
  liveSourceWindow:SetShowBarIcons(db.showSpecIcons)
  liveSourceWindow:SetBarSpacing(db.barSpacing)
  liveSourceWindow:SetStyle(Enum.DamageMeterStyle.Default)
  liveSourceWindow:SetBackgroundAlpha(db.barAlpha)
  liveSourceWindow.Background:Hide()
  liveSourceWindow.CloseButton:Hide()
  liveSourceWindow.ResizeButton:Hide()

  breakdown.targetFrame:SetSize(breakdownDB.width, breakdownDB.targetHeight)
  Theme.SetSquareBackdrop(breakdown.targetFrame, {
    bg = colors.background,
    border = colors.border,
  }, 2)

  breakdown.targetHeader:SetHeight(headerHeight)
  breakdown.targetHeaderBackground:SetColorTexture(
    colors.background[1],
    colors.background[2],
    colors.background[3],
    colors.background[4]
  )
  breakdown.targetHeaderBorder:SetColorTexture(
    colors.border[1],
    colors.border[2],
    colors.border[3],
    colors.border[4]
  )

  Theme.ApplyFont(breakdown.targetTitle, "header", fontSize + 1, "OUTLINE")
  breakdown.targetTitle:SetText("Targets")
  breakdown.targetTitle:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  breakdown.targetTitle:ClearAllPoints()
  breakdown.targetTitle:SetPoint("LEFT", breakdown.targetHeader, "LEFT", 8, 0)
  breakdown.targetTitle:SetPoint("RIGHT", breakdown.targetHeader, "RIGHT", -8, 0)

  breakdown.targetViewport:ClearAllPoints()
  breakdown.targetViewport:SetPoint("TOPLEFT", breakdown.targetHeader, "BOTTOMLEFT", 4, -4)
  breakdown.targetViewport:SetPoint("BOTTOMRIGHT", breakdown.targetFrame, "BOTTOMRIGHT", -4, 4)

  local visibleRowCount = GetViewportRowCount(
    breakdown.viewport,
    db.barHeight,
    db.barSpacing,
    breakdownDB.maxSpells
  )
  local activeRowCount = math_min(breakdownDB.maxSpells, visibleRowCount + 1)
  local visibleTargetRowCount = GetViewportRowCount(
    breakdown.targetViewport,
    db.barHeight,
    db.barSpacing,
    BREAKDOWN_ROW_POOL_SIZE
  )
  local activeTargetRowCount = math_min(BREAKDOWN_ROW_POOL_SIZE, visibleTargetRowCount + 1)

  for index = 1, activeRowCount do
    Breakdown.EnsureRow(breakdown, index)
  end
  for index = 1, activeTargetRowCount do
    Breakdown.EnsureTargetRow(breakdown, index)
  end

  breakdown.activeRowCount = activeRowCount
  breakdown.activeTargetRowCount = activeTargetRowCount

  for index = 1, activeRowCount do
    Breakdown.ApplyRowStyle(
      breakdown.rows[index],
      breakdown.viewport,
      index,
      db,
      breakdownDB,
      colors,
      barTexture
    )
  end
  for index = 1, activeTargetRowCount do
    Breakdown.ApplyRowStyle(
      breakdown.targetRows[index],
      breakdown.targetViewport,
      index,
      db,
      breakdownDB,
      colors,
      barTexture
    )
  end

  breakdown.styledProfile = db
  Breakdown.ApplyPosition(breakdown)
end

local function ApplyBreakdownOpeningStyle(breakdown)
  if breakdown.styledProfile ~= DamageMeters.db.profile then
    Breakdown.ApplyStyle(breakdown)
  else
    Breakdown.ApplyPosition(breakdown)
  end
end

function Breakdown.GetVisibleRowCount(breakdown)
  local db = DamageMeters.db.profile
  return GetViewportRowCount(
    breakdown.viewport,
    db.barHeight,
    db.barSpacing,
    Breakdown.GetDB().maxSpells
  )
end

function Breakdown.GetTargetVisibleRowCount(breakdown)
  local db = DamageMeters.db.profile
  return GetViewportRowCount(
    breakdown.targetViewport,
    db.barHeight,
    db.barSpacing,
    BREAKDOWN_ROW_POOL_SIZE
  )
end

function Breakdown.GetPlainShortName(name)
  if IsSecret(name) or type(name) ~= "string" or name == "" then
    return nil
  end

  return Ambiguate(name, "short")
end

function Breakdown.InvalidateTargetAnalysisCache()
  DamageMeters.targetAnalysisCache = nil
  DamageMeters.targetAnalysisDirty = nil
end

function Breakdown.MarkTargetAnalysisDirty(sessionID)
  local caches = DamageMeters.targetAnalysisCache
  if not caches then
    return
  end

  if type(sessionID) == "number" and sessionID > 0 then
    local cacheKey = "ID:" .. sessionID
    if caches[cacheKey] then
      local dirty = DamageMeters.targetAnalysisDirty or {}
      DamageMeters.targetAnalysisDirty = dirty
      dirty[cacheKey] = true
    end
    return
  end

  if caches["TYPE:CURRENT"] or caches["TYPE:OVERALL"] then
    local dirty = DamageMeters.targetAnalysisDirty or {}
    DamageMeters.targetAnalysisDirty = dirty
    if caches["TYPE:CURRENT"] then
      dirty["TYPE:CURRENT"] = true
    end
    if caches["TYPE:OVERALL"] then
      dirty["TYPE:OVERALL"] = true
    end
  end

end

function Breakdown.InvalidateDeathRecapCache()
  DamageMeters.deathRecapCache = nil
end

function Breakdown.GetTargetPlayerKey(playerName, classFilename)
  local shortPlayerName = Breakdown.GetPlainShortName(playerName)
  if not shortPlayerName then
    return nil
  end

  return shortPlayerName .. "\31" .. (classFilename or "")
end

function Breakdown.BuildTargetAnalysisCache(windowDB)
  if not IsHistorySelection(GetWindowSelection(windowDB)) and Breakdown.IsSourceBlocked() then
    return nil
  end

  local cacheKey = GetSessionStateKey(windowDB)
  local caches = DamageMeters.targetAnalysisCache
  if not caches then
    caches = {}
    DamageMeters.targetAnalysisCache = caches
  end

  local cached = caches[cacheKey]
  local dirty = DamageMeters.targetAnalysisDirty
  if cached and not (dirty and dirty[cacheKey]) then
    return cached
  end

  cached = {
    players = {},
  }
  caches[cacheKey] = cached
  if dirty then
    dirty[cacheKey] = nil
  end

  local session = GetCombatSession(windowDB, "ENEMY_DAMAGE_TAKEN")
  if not session then
    return cached
  end

  local enemySources = session.combatSources
  for sourceIndex = 1, #enemySources do
    local enemySource = enemySources[sourceIndex]
    local targetName = Breakdown.GetPlainShortName(enemySource.name)
    local sourceGUID = enemySource.sourceGUID
    local sourceCreatureID = enemySource.sourceCreatureID

    if IsSecret(sourceGUID) then
      sourceGUID = nil
    end
    if IsSecret(sourceCreatureID) then
      sourceCreatureID = nil
    end

    if targetName and (sourceGUID or sourceCreatureID) then
      local sourceData = GetCombatSessionSource(
        windowDB,
        "ENEMY_DAMAGE_TAKEN",
        sourceGUID,
        sourceCreatureID
      )
      local playerEntries = sourceData and sourceData.combatSpells

      if playerEntries then
        for playerIndex = 1, #playerEntries do
          local playerEntry = playerEntries[playerIndex]
          local details = playerEntry.combatSpellDetails
          local playerName = Breakdown.GetPlainShortName(details.unitName)
          local classFilename = details.unitClassFilename
          local playerKey = Breakdown.GetTargetPlayerKey(playerName, classFilename)
          local totalAmount = playerEntry.totalAmount
          local amountPerSecond = playerEntry.amountPerSecond

          if playerKey
            and type(totalAmount) == "number"
            and not IsSecret(totalAmount)
            and type(amountPerSecond) == "number"
            and not IsSecret(amountPerSecond)
          then
            local player = cached.players[playerKey]
            if not player then
              player = {
                name = playerName,
                classFilename = classFilename,
                entries = {},
                byTarget = {},
                totalAmount = 0,
                maxAmount = 0,
              }
              cached.players[playerKey] = player
            end

            local targetKey = sourceGUID or sourceCreatureID
            local target = player.byTarget[targetKey]
            if not target then
              target = {
                targetName = targetName,
                totalAmount = 0,
                amountPerSecond = 0,
              }
              player.byTarget[targetKey] = target
              player.entries[#player.entries + 1] = target
            end

            target.totalAmount = target.totalAmount + totalAmount
            target.amountPerSecond = target.amountPerSecond + amountPerSecond
            player.totalAmount = player.totalAmount + totalAmount
          end
        end
      end
    end
  end

  for _, player in pairs(cached.players) do
    table_sort(player.entries, function(first, second)
      return first.totalAmount > second.totalAmount
    end)
    if player.entries[1] then
      player.maxAmount = player.entries[1].totalAmount
    end
  end

  return cached
end

function Breakdown.GetTargetAnalysisPlayer(windowDB, playerName, classFilename)
  local cache = Breakdown.BuildTargetAnalysisCache(windowDB)
  if not cache then
    return nil
  end

  local playerKey = Breakdown.GetTargetPlayerKey(playerName, classFilename)
  if playerKey and cache.players[playerKey] then
    return cache.players[playerKey]
  end

  local shortPlayerName = Breakdown.GetPlainShortName(playerName)
  if not shortPlayerName then
    return nil
  end

  for _, player in pairs(cache.players) do
    if player.name == shortPlayerName then
      return player
    end
  end

  return nil
end


function Breakdown.GetDeathRecapData(recapID, storedData)
  if storedData then
    return storedData
  end

  if Breakdown.IsSourceBlocked()
    or type(recapID) ~= "number"
    or recapID <= 0
    or not C_DeathRecap.HasRecapEvents(recapID)
  then
    return nil
  end

  local cache = DamageMeters.deathRecapCache
  if not cache then
    cache = {}
    DamageMeters.deathRecapCache = cache
  end

  if cache[recapID] then
    return cache[recapID]
  end

  local events = C_DeathRecap.GetRecapEvents(recapID)
  local maxHealth = C_DeathRecap.GetRecapMaxHealth(recapID)
  local highestDamageIndex = 1
  local highestDamageAmount = 0
  local deathTimestamp = 0

  for index = 1, #events do
    local event = events[index]
    local amount = event.amount
    local timestamp = event.timestamp

    if type(amount) == "number" and math_abs(amount) > highestDamageAmount then
      highestDamageIndex = index
      highestDamageAmount = math_abs(amount)
    end
    if type(timestamp) == "number" and timestamp > deathTimestamp then
      deathTimestamp = timestamp
    end
  end

  local data = {
    events = events,
    maxHealth = maxHealth,
    highestDamageIndex = highestDamageIndex,
    deathTimestamp = deathTimestamp,
  }
  cache[recapID] = data
  return data
end

function Breakdown.GetDeathEventDisplay(event, index)
  local spellID = event.spellId
  local spellName = event.spellName
  local eventType = event.event

  if type(spellName) ~= "string" or spellName == "" then
    if eventType == "SWING_DAMAGE" then
      spellName = "Melee"
      spellID = 88163
    elseif eventType == "ENVIRONMENTAL_DAMAGE" then
      spellName = event.environmentalType or "Environmental damage"
    elseif type(eventType) == "string" and eventType ~= "" then
      spellName = eventType
    else
      spellName = "Event " .. index
    end
  end

  local texture
  if type(spellID) == "number" then
    texture = C_Spell.GetSpellTexture(spellID)
  end

  return spellID, spellName, texture
end

function Breakdown.BuildDeathEventFlags(event, index, data)
  local flags = {}
  if index == 1 then
    flags[#flags + 1] = "Killing blow"
  end
  if index == data.highestDamageIndex then
    flags[#flags + 1] = "Highest hit"
  end
  if event.critical == true then
    flags[#flags + 1] = "Critical"
  end
  if event.avoidable == true then
    flags[#flags + 1] = "Avoidable"
  end
  if event.deadly == true then
    flags[#flags + 1] = "Deadly"
  end

  local overkill = event.overkill
  if type(overkill) == "number" and overkill > 0 then
    flags[#flags + 1] = AbbreviateNumbers(overkill) .. " overkill"
  end

  local absorbed = event.absorbed
  if type(absorbed) == "number" and absorbed > 0 then
    flags[#flags + 1] = AbbreviateNumbers(absorbed) .. " absorbed"
  end

  local resisted = event.resisted
  if type(resisted) == "number" and resisted > 0 then
    flags[#flags + 1] = AbbreviateNumbers(resisted) .. " resisted"
  end

  local blocked = event.blocked
  if type(blocked) == "number" and blocked > 0 then
    flags[#flags + 1] = AbbreviateNumbers(blocked) .. " blocked"
  end

  return flags
end

function Breakdown.ShowDeathRecapTooltip(row)
  local event = row.deathEvent
  local data = row.deathData
  if not event or not data then
    return
  end

  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText(row.deathSpellName or "Death event")

  if type(event.sourceName) == "string" and event.sourceName ~= "" and event.hideCaster ~= true then
    GameTooltip:AddLine(event.sourceName, 0.78, 0.78, 0.78)
  end

  local timestamp = event.timestamp
  if type(timestamp) == "number" then
    GameTooltip:AddLine(
      string_format("%.1f seconds before death", math_max(0, data.deathTimestamp - timestamp)),
      0.78,
      0.78,
      0.78
    )
  end

  local currentHP = event.currentHP
  local maxHealth = data.maxHealth
  if type(currentHP) == "number" and type(maxHealth) == "number" and maxHealth > 0 then
    GameTooltip:AddLine(
      string_format("Health: %s / %s (%.1f%%)",
        AbbreviateNumbers(currentHP),
        AbbreviateNumbers(maxHealth),
        currentHP / maxHealth * 100
      ),
      1,
      0.82,
      0
    )
  end

  local flags = Breakdown.BuildDeathEventFlags(event, row.deathIndex, data)
  for index = 1, #flags do
    GameTooltip:AddLine(flags[index], 1, 0.35, 0.25)
  end

  GameTooltip:Show()
end

local function SetBreakdownNumericValue(
  row,
  modeField,
  valueField,
  fontString,
  mode,
  value
)
  if IsSecret(value) then
    row[modeField] = nil
    row[valueField] = nil
    SetNumericText(fontString, value)
    return
  end

  if row[modeField] == mode and row[valueField] == value then
    return
  end

  row[modeField] = mode
  row[valueField] = value
  SetNumericText(fontString, value)
end

function Breakdown.SetAmountText(row, spell, sourceTotalAmount, meterKey)
  local db = Breakdown.GetDB()
  local totalAmount = spell.totalAmount
  local amountPerSecond = spell.amountPerSecond
  local ratePrimary = IsRatePrimaryMeter(meterKey)
  local amountLayout

  if db.amounts == "TOTAL" or IsCountMeter(meterKey) or IsDeathMeter(meterKey) then
    amountLayout = "TOTAL"
  elseif db.amounts == "RATE" then
    amountLayout = ratePrimary and "RATE" or "RATE_SUFFIX"
  elseif ratePrimary then
    amountLayout = "RATE_TOTAL"
  else
    amountLayout = "TOTAL_RATE"
  end

  if row.amountLayout ~= amountLayout then
    row.amountLayout = amountLayout

    if amountLayout == "RATE_SUFFIX" then
      row.primarySuffix:SetText("/s")
      row.amountSeparator:SetText("")
      row.secondarySuffix:SetText("")
    elseif amountLayout == "RATE_TOTAL" then
      row.primarySuffix:SetText("")
      row.amountSeparator:SetText("·")
      row.secondarySuffix:SetText("")
    elseif amountLayout == "TOTAL_RATE" then
      row.primarySuffix:SetText("")
      row.amountSeparator:SetText("·")
      row.secondarySuffix:SetText("/s")
    else
      row.primarySuffix:SetText("")
      row.amountSeparator:SetText("")
      row.secondarySuffix:SetText("")
    end
  end

  if amountLayout == "TOTAL" then
    SetBreakdownNumericValue(
      row,
      "primaryAmountMode",
      "primaryAmountValue",
      row.primaryAmount,
      "TOTAL",
      totalAmount
    )
    SetBreakdownNumericValue(
      row,
      "secondaryAmountMode",
      "secondaryAmountValue",
      row.secondaryAmount,
      "EMPTY",
      nil
    )
  elseif amountLayout == "RATE" or amountLayout == "RATE_SUFFIX" then
    SetBreakdownNumericValue(
      row,
      "primaryAmountMode",
      "primaryAmountValue",
      row.primaryAmount,
      "RATE",
      amountPerSecond
    )
    SetBreakdownNumericValue(
      row,
      "secondaryAmountMode",
      "secondaryAmountValue",
      row.secondaryAmount,
      "EMPTY",
      nil
    )
  elseif amountLayout == "RATE_TOTAL" then
    SetBreakdownNumericValue(
      row,
      "primaryAmountMode",
      "primaryAmountValue",
      row.primaryAmount,
      "RATE",
      amountPerSecond
    )
    SetBreakdownNumericValue(
      row,
      "secondaryAmountMode",
      "secondaryAmountValue",
      row.secondaryAmount,
      "TOTAL",
      totalAmount
    )
  else
    SetBreakdownNumericValue(
      row,
      "primaryAmountMode",
      "primaryAmountValue",
      row.primaryAmount,
      "TOTAL",
      totalAmount
    )
    SetBreakdownNumericValue(
      row,
      "secondaryAmountMode",
      "secondaryAmountValue",
      row.secondaryAmount,
      "RATE",
      amountPerSecond
    )
  end

  row.percent:SetText("")
  if db.showPercent
    and not Breakdown.IsSourceBlocked()
    and not IsSecret(totalAmount)
    and not IsSecret(sourceTotalAmount)
    and type(totalAmount) == "number"
    and type(sourceTotalAmount) == "number"
    and sourceTotalAmount > 0
  then
    row.percent:SetText(string_format("%.1f%%", (totalAmount / sourceTotalAmount) * 100))
  end
end

function Breakdown.SetSpellMetadataText(row, spell)
  if Breakdown.IsSourceBlocked() then
    return
  end

  local parts = {}
  local current = row.percent:GetText()
  if current and current ~= "" then
    parts[#parts + 1] = current
  end

  if spell.isDeadly == true then
    parts[#parts + 1] = "Deadly"
  end
  if spell.isAvoidable == true then
    parts[#parts + 1] = "Avoidable"
  end

  local overkillAmount = spell.overkillAmount
  if type(overkillAmount) == "number" and overkillAmount > 0 then
    parts[#parts + 1] = AbbreviateNumbers(overkillAmount) .. " overkill"
  end

  row.percent:SetText(table_concat(parts, " · "))
end


function Breakdown.SetTargetRow(row, target, index, maxAmount, sourceTotalAmount, selection)
  local classColor = selection.classFilename and RAID_CLASS_COLORS[selection.classFilename]
  local colors = Theme.GetColors()

  row.rank:SetText(RANK_TEXT[index] or (index .. "."))
  row.fill:SetMinMaxValues(0, maxAmount)
  row.fill:SetValue(target.totalAmount)
  if classColor then
    row.fill:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1)
  else
    row.fill:SetStatusBarColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
  end

  row.name:SetText(target.targetName)
  row.icon:Hide()
  row.spellID = nil
  row.enemyPlayerRow = nil
  row.targetRow = true
  row.deathEvent = nil
  row.deathData = nil
  row.deathIndex = nil
  row.deathSpellID = nil
  row.deathSpellName = nil
  Breakdown.SetAmountText(row, target, sourceTotalAmount, selection.meterKey)
  row:Show()
end

function Breakdown.HideTargetRowsFrom(breakdown, firstIndex)
  local usedRows = breakdown.usedTargetRows or 0
  for index = firstIndex, usedRows do
    local row = breakdown.targetRows[index]
    if row then
      row.spellID = nil
      row.enemyPlayerRow = nil
      row.targetRow = nil
      row.deathEvent = nil
      row.deathData = nil
      row.deathIndex = nil
      row.deathSpellID = nil
      row.deathSpellName = nil
      row:Hide()
      row.icon:Hide()
    end
  end
  breakdown.usedTargetRows = firstIndex - 1
end

function Breakdown.HideTarget(breakdown)
  breakdown.firstTarget = 1
  breakdown.targetCount = 0
  Breakdown.HideTargetRowsFrom(breakdown, 1)
  breakdown.targetFrame:Hide()
end

function Breakdown.RefreshTarget(breakdown, targetPlayer, selection)
  if selection.mode ~= "SPELLS" or not targetPlayer then
    Breakdown.HideTarget(breakdown)
    return
  end

  local entries = targetPlayer.entries
  local targetCount = #entries
  breakdown.targetCount = targetCount

  if targetCount == 0 then
    Breakdown.HideTarget(breakdown)
    return
  end

  local visibleCount = Breakdown.GetTargetVisibleRowCount(breakdown)
  breakdown.targetVisibleRowCount = visibleCount
  local maximumFirstTarget = math_max(1, targetCount - visibleCount + 1)
  breakdown.firstTarget = Clamp(breakdown.firstTarget or 1, 1, maximumFirstTarget)

  local lastTarget = math_min(targetCount, breakdown.firstTarget + visibleCount - 1)
  local rowIndex = 0

  for targetIndex = breakdown.firstTarget, lastTarget do
    rowIndex = rowIndex + 1
    local row, created = Breakdown.EnsureTargetRow(breakdown, rowIndex)
    if created then
      local db = DamageMeters.db.profile
      Breakdown.ApplyRowStyle(
        row,
        breakdown.targetViewport,
        rowIndex,
        db,
        db.breakdown,
        Theme.GetColors(),
        Theme.GetBarTexture()
      )
    end

    Breakdown.SetTargetRow(
      row,
      entries[targetIndex],
      targetIndex,
      targetPlayer.maxAmount,
      targetPlayer.totalAmount,
      selection
    )
  end

  Breakdown.HideTargetRowsFrom(breakdown, rowIndex + 1)
  breakdown.usedTargetRows = rowIndex
  breakdown.targetFrame:Show()
end

function Breakdown.SetDeathRecapRow(breakdown, row, event, index, data)
  local colors = Theme.GetColors()
  row.amountLayout = nil
  row.primaryAmountMode = nil
  row.primaryAmountValue = nil
  row.secondaryAmountMode = nil
  row.secondaryAmountValue = nil
  local spellID, spellName, texture = Breakdown.GetDeathEventDisplay(event, index)
  local sourceName = event.hideCaster ~= true and event.sourceName or nil
  local displayName = spellName
  if type(sourceName) == "string" and sourceName ~= "" then
    displayName = spellName .. " — " .. sourceName
  end

  row.rank:SetText(RANK_TEXT[index] or (index .. "."))
  local currentHP = event.currentHP
  local maxHealth = data.maxHealth
  if type(currentHP) == "number" and type(maxHealth) == "number" and maxHealth > 0 then
    local healthRatio = currentHP / maxHealth
    row.fill:SetMinMaxValues(0, maxHealth)
    row.fill:SetValue(currentHP)
    if healthRatio <= 0.30 then
      row.fill:SetStatusBarColor(0.78, 0.16, 0.12, 1)
    elseif healthRatio <= 0.60 then
      row.fill:SetStatusBarColor(0.92, 0.66, 0.12, 1)
    else
      row.fill:SetStatusBarColor(0.24, 0.72, 0.30, 1)
    end
  else
    row.fill:SetMinMaxValues(0, 1)
    row.fill:SetValue(1)
    row.fill:SetStatusBarColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
  end

  row.name:SetText(displayName)
  row.icon:Hide()
  if texture then
    row.icon:SetTexture(texture)
    row.icon:Show()
  end

  row.primaryAmount:SetText("")
  row.primarySuffix:SetText("")
  row.amountSeparator:SetText("")
  row.secondaryAmount:SetText("")
  row.secondarySuffix:SetText("")
  row.percent:SetText("")

  local amount = event.amount
  if type(amount) == "number" then
    SetNumericText(row.primaryAmount, math_abs(amount))
  end

  local timestamp = event.timestamp
  if type(timestamp) == "number" then
    row.amountSeparator:SetText("·")
    row.secondaryAmount:SetText(string_format("-%.1fs", math_max(0, data.deathTimestamp - timestamp)))
  end

  local metadata = {}
  if type(currentHP) == "number" and type(maxHealth) == "number" and maxHealth > 0 then
    metadata[#metadata + 1] = string_format("%.1f%% HP", currentHP / maxHealth * 100)
  end
  local flags = Breakdown.BuildDeathEventFlags(event, index, data)
  for flagIndex = 1, #flags do
    metadata[#metadata + 1] = flags[flagIndex]
  end
  row.percent:SetText(table_concat(metadata, " · "))

  row.spellID = nil
  row.enemyPlayerRow = nil
  row.targetRow = nil
  row.deathEvent = event
  row.deathData = data
  row.deathIndex = index
  row.deathSpellID = spellID
  row.deathSpellName = spellName
  row:Show()
end

function Breakdown.SetEnemyDamagePlayerRow(breakdown, row, spell, index, maxAmount, sourceTotalAmount, selection)
  local details = spell.combatSpellDetails
  local classFilename = details.unitClassFilename
  local classColor = RAID_CLASS_COLORS[classFilename]
  local specIconID = details.specIconID
  local playerName = details.unitName

  row.rank:SetText(RANK_TEXT[index] or (index .. "."))
  row.fill:SetMinMaxValues(0, maxAmount)
  row.fill:SetValue(spell.totalAmount)

  if classColor then
    row.fill:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1)
  else
    local colors = Theme.GetColors()
    row.fill:SetStatusBarColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
  end

  row.spellID = nil
  row.enemyPlayerRow = true
  row.targetRow = nil
  row.deathEvent = nil
  row.deathData = nil
  row.deathIndex = nil
  row.deathSpellID = nil
  row.deathSpellName = nil
  row.icon:Hide()

  row.name:SetText(playerName)

  if Breakdown.GetDB().showIcons and type(specIconID) == "number" and specIconID > 0 then
    row.icon:SetTexture(specIconID)
    row.icon:Show()
  end

  Breakdown.SetAmountText(row, spell, sourceTotalAmount, selection.meterKey)
  row:Show()
end

function Breakdown.SetRow(breakdown, row, spell, index, maxAmount, sourceTotalAmount, selection)
  local colors = Theme.GetColors()
  local classColor = selection.classFilename and RAID_CLASS_COLORS[selection.classFilename]

  row.rank:SetText(RANK_TEXT[index] or (index .. "."))
  row.fill:SetMinMaxValues(0, maxAmount)
  row.fill:SetValue(spell.totalAmount)

  if classColor then
    row.fill:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1)
  else
    row.fill:SetStatusBarColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
  end

  row.enemyPlayerRow = nil
  row.targetRow = nil
  row.deathEvent = nil
  row.deathData = nil
  row.deathIndex = nil
  row.deathSpellID = nil
  row.deathSpellName = nil

  local spellID = spell.spellID
  row.spellID = nil
  row.icon:Hide()

  if IsSecret(spellID) then
    row.name:SetText(C_Spell.GetSpellName(spellID))
    if Breakdown.GetDB().showIcons then
      row.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
      row.icon:Show()
    end
  elseif type(spellID) == "number" then
    local displayName = C_Spell.GetSpellName(spellID)
    if type(displayName) ~= "string" or displayName == "" then
      displayName = "Ability " .. index
    end

    local creatureName = spell.creatureName
    if not IsSecret(creatureName)
      and type(creatureName) == "string"
      and creatureName ~= ""
    then
      displayName = displayName .. " (" .. creatureName .. ")"
    end

    row.name:SetText(displayName)
    if Breakdown.GetDB().showIcons then
      row.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
      row.icon:Show()
    end
    row.spellID = spellID
  else
    row.name:SetText("Ability " .. index)
  end
  Breakdown.SetAmountText(row, spell, sourceTotalAmount, selection.meterKey)
  Breakdown.SetSpellMetadataText(row, spell)
  row:Show()
end

function Breakdown.HideRowsFrom(breakdown, firstIndex)
  local usedRows = breakdown.usedRows or 0
  for index = firstIndex, usedRows do
    local row = breakdown.rows[index]
    if row then
      row.spellID = nil
      row.enemyPlayerRow = nil
      row.targetRow = nil
      row.deathEvent = nil
      row.deathData = nil
      row.deathIndex = nil
      row.deathSpellID = nil
      row.deathSpellName = nil
      row:Hide()
      row.icon:Hide()
    end
  end
  breakdown.usedRows = firstIndex - 1
end

function Breakdown.Refresh()
  local breakdown = DamageMeters.breakdown
  local selection = DamageMeters.breakdownSelection
  if not breakdown or not breakdown.frame:IsShown() or not selection then
    return
  end

  if not selection.ownerWindow or not selection.ownerWindow.frame:IsShown() then
    Breakdown.Close()
    return
  end

  if selection.mode == "LIVE_ENEMY_PLAYERS" then
    local liveSourceWindow = breakdown.liveSourceWindow
    if not liveSourceWindow:IsShown() then
      Breakdown.Close()
      return
    end

    liveSourceWindow:Refresh(ScrollBoxConstants.RetainScrollPosition)
    return
  end

  breakdown.liveSourceWindow:Hide()
  breakdown.viewport:Show()

  local ownerDB = GetWindowDB(selection.ownerIndex)
  local historySelection = GetWindowSelection(ownerDB)
  local storedBreakdown = IsHistorySelection(historySelection)
  local sourceBlocked = not storedBreakdown and Breakdown.IsSourceBlocked()

  if selection.mode == "DEATH_RECAP" and sourceBlocked then
    Breakdown.Close()
    return
  end

  if sourceBlocked and selection.isLocalPlayer ~= true then
    Breakdown.Close()
    return
  end

  selection.sessionKey = ownerDB.session
  selection.sessionID = GetBlizzardSessionID(ownerDB)

  local sessionLabel = GetSessionDisplay(ownerDB)
  local entries
  local sourceCount = 0
  local maxAmount = 0
  local totalAmount = 0
  local rowSetter = Breakdown.SetRow
  local deathData
  local targetPlayer

  if selection.mode == "DEATH_RECAP" then
    deathData = Breakdown.GetDeathRecapData(
      selection.deathRecapID,
      selection.storedDeathRecapData
    )
    if deathData then
      entries = deathData.events
      sourceCount = #entries
    end
    breakdown.title:SetText(selection.name)
    breakdown.subtitle:SetText("Death recap · " .. sessionLabel)
  else
    local sourceData = GetCombatSessionSource(
      ownerDB,
      selection.meterKey,
      selection.sourceGUID,
      selection.sourceCreatureID
    )

    if sourceData then
      entries = sourceData.combatSpells
      sourceCount = #entries
      maxAmount = sourceData.maxAmount
      totalAmount = sourceData.totalAmount
    end

    if selection.mode == "ENEMY_PLAYERS" then
      rowSetter = Breakdown.SetEnemyDamagePlayerRow
      breakdown.title:SetText(selection.name)
      breakdown.subtitle:SetText("Damage from players · " .. sessionLabel)
    else
      breakdown.title:SetText(selection.name)
      breakdown.subtitle:SetText(METER_NAMES[selection.meterKey] .. " · " .. sessionLabel)

      if not sourceBlocked
        and (selection.meterKey == "DAMAGE_DONE" or selection.meterKey == "DPS")
      then
        targetPlayer = Breakdown.GetTargetAnalysisPlayer(ownerDB, selection.name, selection.classFilename)
      end
    end
  end

  Breakdown.RefreshTarget(breakdown, targetPlayer, selection)
  breakdown.sourceCount = sourceCount

  if sourceCount == 0 then
    breakdown.firstSpell = 1
    Breakdown.HideRowsFrom(breakdown, 1)
    if selection.mode == "DEATH_RECAP" then
      breakdown.emptyText:SetText("No death recap data")
    else
      breakdown.emptyText:SetText("No breakdown data")
    end
    breakdown.emptyText:Show()
    return
  end

  breakdown.emptyText:Hide()
  local visibleCount = Breakdown.GetVisibleRowCount(breakdown)
  breakdown.visibleRowCount = visibleCount
  local maximumFirstSpell = math_max(1, sourceCount - visibleCount + 1)
  breakdown.firstSpell = Clamp(breakdown.firstSpell or 1, 1, maximumFirstSpell)

  local lastSpell = math_min(sourceCount, breakdown.firstSpell + visibleCount - 1)
  local rowIndex = 0

  for displayIndex = breakdown.firstSpell, lastSpell do
    rowIndex = rowIndex + 1
    local row, created = Breakdown.EnsureRow(breakdown, rowIndex)
    if created then
      local db = DamageMeters.db.profile
      Breakdown.ApplyRowStyle(
        row,
        breakdown.viewport,
        rowIndex,
        db,
        db.breakdown,
        Theme.GetColors(),
        Theme.GetBarTexture()
      )
    end

    if selection.mode == "DEATH_RECAP" then
      Breakdown.SetDeathRecapRow(breakdown, row, entries[displayIndex], displayIndex, deathData)
    else
      rowSetter(
        breakdown,
        row,
        entries[displayIndex],
        displayIndex,
        maxAmount,
        totalAmount,
        selection
      )
    end
  end

  Breakdown.HideRowsFrom(breakdown, rowIndex + 1)
  breakdown.usedRows = rowIndex
end

function Breakdown.Close()
  DamageMeters:CancelTargetAnalysisRefresh()
  DamageMeters.breakdownSelection = nil
  local breakdown = DamageMeters.breakdown
  if not breakdown then
    return
  end

  breakdown.hoverSerial = (breakdown.hoverSerial or 0) + 1
  breakdown.pinned = false
  breakdown.firstSpell = 1
  breakdown.firstTarget = 1
  breakdown.sourceCount = 0
  breakdown.targetCount = 0
  Breakdown.HideRowsFrom(breakdown, 1)
  Breakdown.HideTargetRowsFrom(breakdown, 1)
  breakdown.liveSourceWindow:Hide()
  breakdown.viewport:Show()
  breakdown.targetFrame:Hide()
  breakdown.frame:Hide()
end

function Breakdown.OpenLiveEnemyPlayers(ownerWindow, row, source, pinned)
  local windowDB = GetWindowDB(ownerWindow.index)
  local breakdown = Breakdown.Ensure()

  Breakdown.CancelTransientClose()
  breakdown.pinned = pinned == true
  DamageMeters.breakdownSelection = {
    ownerWindow = ownerWindow,
    ownerRow = row,
    ownerIndex = ownerWindow.index,
    mode = "LIVE_ENEMY_PLAYERS",
    meterKey = windowDB.meter,
    sessionKey = windowDB.session,
    sessionID = GetBlizzardSessionID(windowDB),
    isLocalPlayer = false,
  }

  breakdown.firstSpell = 1
  breakdown.firstTarget = 1
  Breakdown.HideRowsFrom(breakdown, 1)
  Breakdown.HideTarget(breakdown)
  breakdown.viewport:Hide()
  breakdown.emptyText:Hide()

  ApplyBreakdownOpeningStyle(breakdown)
  breakdown.title:SetText("Damage from players")

  local sessionLabel = GetSessionDisplay(windowDB)
  breakdown.subtitle:SetText("Selected enemy · " .. sessionLabel)

  local sessionID = GetBlizzardSessionID(windowDB)
  local sessionType = sessionID and nil or SESSION_TYPES[windowDB.session]
  local liveSourceWindow = breakdown.liveSourceWindow
  liveSourceWindow:Hide()
  liveSourceWindow:SetDamageMeterType(METER_TYPES.ENEMY_DAMAGE_TAKEN)
  liveSourceWindow:SetSource(source)
  liveSourceWindow:SetSession(sessionType, sessionID)
  liveSourceWindow.CloseButton:Hide()
  liveSourceWindow.ResizeButton:Hide()
  liveSourceWindow:Show()
  breakdown.frame:Show()
end

function Breakdown.OpenForRow(row, pinned)
  local ownerWindow = row.window
  if not ownerWindow or not row.sourceIndex then
    return
  end

  if GameTooltip:IsOwned(row) then
    GameTooltip:Hide()
  end

  local existingBreakdown = DamageMeters.breakdown
  if pinned ~= true and existingBreakdown and existingBreakdown.pinned then
    return
  end

  local windowDB = GetWindowDB(ownerWindow.index)
  local historySelection = GetWindowSelection(windowDB)
  local storedBreakdown = IsHistorySelection(historySelection)
  local restricted = not storedBreakdown and Breakdown.IsSourceBlocked()

  if IsDeathMeter(windowDB.meter) then
    if restricted then
      Breakdown.ShowSourceUnavailableTooltip(row)
      return
    end

    local recapID = row.deathRecapID
    local storedDeathRecapData
    if storedBreakdown then
      local session = GetCombatSession(windowDB, windowDB.meter)
      local source = session and session.combatSources[row.sourceIndex]
      storedDeathRecapData = source and source.deathRecapData
    end

    local hasLiveRecap = false
    if not storedDeathRecapData and type(recapID) == "number" and recapID > 0 then
      hasLiveRecap = C_DeathRecap.HasRecapEvents(recapID)
    end
    if not storedDeathRecapData and not hasLiveRecap then
      GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
      GameTooltip:SetText("Death recap")
      GameTooltip:AddLine("Blizzard did not retain recap events for this death.", 0.78, 0.78, 0.78, true)
      GameTooltip:Show()
      return
    end

    local breakdown = Breakdown.Ensure()
    Breakdown.CancelTransientClose()
    breakdown.pinned = pinned == true
    DamageMeters.breakdownSelection = {
      ownerWindow = ownerWindow,
      ownerRow = row,
      ownerIndex = ownerWindow.index,
      mode = "DEATH_RECAP",
      meterKey = windowDB.meter,
      sessionKey = windowDB.session,
      sessionID = GetBlizzardSessionID(windowDB),
      deathRecapID = recapID,
      storedDeathRecapData = storedDeathRecapData,
      isLocalPlayer = false,
      name = row.sourceDisplayName or "Death",
    }

    breakdown.firstSpell = 1
    breakdown.firstTarget = 1
    breakdown.liveSourceWindow:Hide()
    breakdown.viewport:Show()
    ApplyBreakdownOpeningStyle(breakdown)
    breakdown.frame:Show()
    Breakdown.Refresh()
    return
  end

  if restricted and windowDB.meter == "ENEMY_DAMAGE_TAKEN" then
    local session = GetCombatSession(windowDB, windowDB.meter)
    if not session then
      return
    end

    local source = session.combatSources[row.sourceIndex]
    if not source then
      return
    end

    Breakdown.OpenLiveEnemyPlayers(ownerWindow, row, source, pinned)
    return
  end

  if restricted and row.isLocalPlayer ~= true then
    Breakdown.ShowSourceUnavailableTooltip(row)
    return
  end

  local sourceGUID
  local sourceCreatureID
  local sourceName
  local classFilename = row.classFilename

  if restricted then
    sourceGUID = UnitGUID("player")
    if not sourceGUID or IsSecret(sourceGUID) then
      return
    end

    sourceName = UnitName("player")
    if IsSecret(sourceName) or type(sourceName) ~= "string" or sourceName == "" then
      sourceName = "Player"
    else
      sourceName = Ambiguate(sourceName, "short")
    end
  else
    local session = GetCombatSession(windowDB, windowDB.meter)
    if not session then
      return
    end

    local source = session.combatSources[row.sourceIndex]
    if not source then
      return
    end

    sourceGUID = source.sourceGUID
    if IsSecret(sourceGUID) then
      sourceGUID = nil
    end

    sourceCreatureID = source.sourceCreatureID
    if IsSecret(sourceCreatureID) then
      sourceCreatureID = nil
    end

    if not sourceGUID and not sourceCreatureID then
      return
    end

    sourceName = source.name
    if IsSecret(sourceName) or type(sourceName) ~= "string" or sourceName == "" then
      sourceName = "Source"
    else
      sourceName = Ambiguate(sourceName, "short")
    end

    classFilename = source.classFilename
  end

  local breakdown = Breakdown.Ensure()
  Breakdown.CancelTransientClose()
  breakdown.pinned = pinned == true
  DamageMeters.breakdownSelection = {
    ownerWindow = ownerWindow,
    ownerRow = row,
    ownerIndex = ownerWindow.index,
    mode = windowDB.meter == "ENEMY_DAMAGE_TAKEN" and "ENEMY_PLAYERS" or "SPELLS",
    meterKey = windowDB.meter,
    sessionKey = windowDB.session,
    sessionID = GetBlizzardSessionID(windowDB),
    sourceGUID = sourceGUID,
    sourceCreatureID = sourceCreatureID,
    isLocalPlayer = row.isLocalPlayer == true,
    name = sourceName,
    classFilename = classFilename,
  }

  breakdown.firstSpell = 1
  breakdown.firstTarget = 1
  breakdown.liveSourceWindow:Hide()
  breakdown.viewport:Show()
  ApplyBreakdownOpeningStyle(breakdown)
  breakdown.frame:Show()
  Breakdown.Refresh()
end
function Breakdown.NavigateBack(window)
  if not window then
    return
  end

  local selection = DamageMeters.breakdownSelection
  if selection and selection.ownerWindow == window then
    local breakdown = DamageMeters.breakdown
    if breakdown and breakdown.pinned then
      Breakdown.Close()
      return
    end

    Breakdown.Close()
  end

  if window.navigationMode then
    return
  end

  ShowMeterNavigation(window)
end

Breakdown.GetDB = P:Def("GetBreakdownDB", Breakdown.GetDB)
Breakdown.IsSourceBlocked = P:Def("SourceBreakdownBlocked", Breakdown.IsSourceBlocked)
Breakdown.ShowSourceUnavailableTooltip = P:Def("ShowSourceUnavailableTooltip", Breakdown.ShowSourceUnavailableTooltip)
Breakdown.SavePosition = P:Def("SaveBreakdownPosition", Breakdown.SavePosition)
Breakdown.CancelTransientClose = P:Def("CancelTransientBreakdownClose", Breakdown.CancelTransientClose)
Breakdown.ScheduleTransientClose = P:Def("ScheduleTransientBreakdownClose", Breakdown.ScheduleTransientClose)
Breakdown.CreateRow = P:Def("CreateBreakdownRow", Breakdown.CreateRow)
Breakdown.EnsureRow = P:Def("EnsureBreakdownRow", Breakdown.EnsureRow)
Breakdown.EnsureTargetRow = P:Def("EnsureTargetBreakdownRow", Breakdown.EnsureTargetRow)
Breakdown.Ensure = P:Def("EnsureBreakdown", Breakdown.Ensure)
Breakdown.ApplyPosition = P:Def("ApplyBreakdownPosition", Breakdown.ApplyPosition)
Breakdown.ApplyRowStyle = P:Def("ApplyBreakdownRowStyle", Breakdown.ApplyRowStyle)
Breakdown.ApplyStyle = P:Def("ApplyBreakdownStyle", Breakdown.ApplyStyle)
Breakdown.GetVisibleRowCount = P:Def("GetBreakdownVisibleRowCount", Breakdown.GetVisibleRowCount)
Breakdown.GetTargetVisibleRowCount = P:Def("GetTargetBreakdownVisibleRowCount", Breakdown.GetTargetVisibleRowCount)
Breakdown.GetPlainShortName = P:Def("GetPlainShortName", Breakdown.GetPlainShortName)
Breakdown.InvalidateTargetAnalysisCache = P:Def("InvalidateTargetAnalysisCache", Breakdown.InvalidateTargetAnalysisCache)
Breakdown.MarkTargetAnalysisDirty = P:Def("MarkTargetAnalysisDirty", Breakdown.MarkTargetAnalysisDirty)
Breakdown.InvalidateDeathRecapCache = P:Def("InvalidateDeathRecapCache", Breakdown.InvalidateDeathRecapCache)
Breakdown.GetTargetPlayerKey = P:Def("GetTargetPlayerKey", Breakdown.GetTargetPlayerKey)
Breakdown.BuildTargetAnalysisCache = P:Def("BuildTargetAnalysisCache", Breakdown.BuildTargetAnalysisCache)
Breakdown.GetTargetAnalysisPlayer = P:Def("GetTargetAnalysisPlayer", Breakdown.GetTargetAnalysisPlayer)
Breakdown.GetDeathRecapData = P:Def("GetDeathRecapData", Breakdown.GetDeathRecapData)
Breakdown.GetDeathEventDisplay = P:Def("GetDeathEventDisplay", Breakdown.GetDeathEventDisplay)
Breakdown.BuildDeathEventFlags = P:Def("BuildDeathEventFlags", Breakdown.BuildDeathEventFlags)
Breakdown.ShowDeathRecapTooltip = P:Def("ShowDeathRecapTooltip", Breakdown.ShowDeathRecapTooltip)
Breakdown.SetAmountText = P:Def("SetBreakdownAmountText", Breakdown.SetAmountText)
Breakdown.SetSpellMetadataText = P:Def("SetSpellMetadataText", Breakdown.SetSpellMetadataText)
Breakdown.SetTargetRow = P:Def("SetTargetBreakdownRow", Breakdown.SetTargetRow)
Breakdown.HideTargetRowsFrom = P:Def("HideTargetBreakdownRowsFrom", Breakdown.HideTargetRowsFrom)
Breakdown.HideTarget = P:Def("HideTargetBreakdown", Breakdown.HideTarget)
Breakdown.RefreshTarget = P:Def("RefreshTargetBreakdown", Breakdown.RefreshTarget)
Breakdown.SetDeathRecapRow = P:Def("SetDeathRecapRow", Breakdown.SetDeathRecapRow)
Breakdown.SetEnemyDamagePlayerRow = P:Def("SetEnemyDamagePlayerRow", Breakdown.SetEnemyDamagePlayerRow)
Breakdown.SetRow = P:Def("SetBreakdownRow", Breakdown.SetRow)
Breakdown.HideRowsFrom = P:Def("HideBreakdownRowsFrom", Breakdown.HideRowsFrom)
Breakdown.Refresh = P:Def("RefreshBreakdown", Breakdown.Refresh)
Breakdown.Close = P:Def("CloseBreakdown", Breakdown.Close)
Breakdown.OpenLiveEnemyPlayers = P:Def("OpenLiveEnemyPlayers", Breakdown.OpenLiveEnemyPlayers)
Breakdown.OpenForRow = P:Def("OpenBreakdownForRow", Breakdown.OpenForRow)
Breakdown.NavigateBack = P:Def("NavigateBack", Breakdown.NavigateBack)
