local _, ns = ...

local Addon = ns.Addon
local FrameUtil = ns.FrameUtil
local Theme = ns.Theme
local DamageMeters = ns.Modules.DamageMeters
local Windows = ns.DamageMeterWindows
local Config = ns.DamageMeterConfig
local Sessions = ns.DamageMeterSessions
local History = ns.DamageMeterHistory
local Breakdown = ns.DamageMeterBreakdown
local SegmentPicker = ns.DamageMeterSegmentPicker
local Constants = ns.DamageMeterConstants
local P = ns.DamageMeterProfiler

local _G = _G
local UIParent = _G.UIParent
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local AbbreviateNumbers = _G.AbbreviateNumbers
local Ambiguate = _G.Ambiguate
local GetClassAtlas = _G.GetClassAtlas
local GetCursorPosition = _G.GetCursorPosition
local IsShiftKeyDown = _G.IsShiftKeyDown
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local type = _G.type
local NUMBER_ABBREVIATION_OPTIONS = _G.NUMBER_ABBREVIATION_OPTIONS

local MAX_WINDOWS = Constants.MAX_WINDOWS
local ROW_POOL_SIZE = Constants.ROW_POOL_SIZE
local MOVER_PREFIX = Constants.MOVER_PREFIX
local METER_NAMES = Constants.METER_NAMES
local METER_CATEGORIES = Constants.METER_CATEGORIES
local METER_TYPES = Constants.METER_TYPES
local LIST_TEXTURE = Constants.LIST_TEXTURE
local PAD_LOCKED_TEXTURE = Constants.PAD_LOCKED_TEXTURE
local PAD_UNLOCKED_TEXTURE = Constants.PAD_UNLOCKED_TEXTURE
local TRASH_TEXTURE = Constants.TRASH_TEXTURE
local MINIMIZE_TEXTURE = Constants.MINIMIZE_TEXTURE
local CONFIG_TEXTURE = Constants.CONFIG_TEXTURE
local DEFAULT_WINDOW_POSITIONS = Config.DEFAULT_WINDOW_POSITIONS

local Round = ns.DamageMeterUtil.Round
local Clamp = ns.DamageMeterUtil.Clamp
local GetViewportRowCount = ns.DamageMeterUtil.GetViewportRowCount
local IsSecret = ns.DamageMeterUtil.IsSecret
local GetWindowDB = Config.GetWindowDB
local GetWindowSelection = Sessions.GetWindowSelection
local SetWindowSelection = Sessions.SetWindowSelection
local IsAvailableSessionSelection = Sessions.IsAvailableSessionSelection
local GetCombatSession = Sessions.GetCombatSession
local AcquireRefreshSessionCache = Sessions.AcquireRefreshSessionCache
local ReleaseRefreshSessionCache = Sessions.ReleaseRefreshSessionCache
local GetRefreshSession = Sessions.GetRefreshSession
local GetSessionDisplay = Sessions.GetSessionDisplay
local FormatDuration = Sessions.FormatDuration
local SetDeathTimeText = Sessions.SetDeathTimeText
local NO_COMBAT_SESSION = Sessions.NO_COMBAT_SESSION

local RANK_TEXT = {}
for index = 1, ROW_POOL_SIZE do
  RANK_TEXT[index] = index .. "."
end
local function SetHeaderButtonTooltip(button, title, description)
  button.__puiTooltipTitle = title
  button.__puiTooltipDescription = description
end

local function ShowHeaderButtonTooltip(button)
  GameTooltip:SetOwner(button, "ANCHOR_TOP")
  GameTooltip:SetText(button.__puiTooltipTitle or "")
  if button.__puiTooltipDescription then
    GameTooltip:AddLine(button.__puiTooltipDescription, 0.78, 0.78, 0.78, true)
  end
  GameTooltip:Show()
end

local function RefreshHeaderButtonTooltip(button)
  if GameTooltip:IsOwned(button) then
    ShowHeaderButtonTooltip(button)
  end
end

local function HideHeaderButtonTooltip()
  GameTooltip:Hide()
end

local function CreateHeaderButton(parent)
  local button = CreateFrame("Button", nil, parent)
  button:RegisterForClicks("LeftButtonUp")
  button.__puiIconAlpha = 0.78
  button.__puiIconInsetX = 3
  button.__puiIconInsetY = 1

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", button.__puiIconInsetX, -button.__puiIconInsetY)
  icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -button.__puiIconInsetX, button.__puiIconInsetY)
  icon:SetAlpha(button.__puiIconAlpha)
  button.icon = icon

  local highlight = button:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints(button)
  highlight:SetColorTexture(1, 1, 1, 0.10)

  button:SetScript("OnEnter", function(self)
    self.icon:SetAlpha(1)
    ShowHeaderButtonTooltip(self)
  end)
  button:SetScript("OnLeave", function(self)
    self.icon:SetAlpha(self.__puiIconAlpha)
    HideHeaderButtonTooltip()
  end)

  return button
end

local function CreateAtlasButton(parent, atlas)
  local button = CreateHeaderButton(parent)
  button.icon:SetAtlas(atlas)
  return button
end

local function CreateTextureButton(parent, texture, left, right, top, bottom)
  local button = CreateHeaderButton(parent)
  button.icon:SetTexture(texture)
  button.icon:SetTexCoord(
    left or 0.30,
    right or 0.70,
    top or 0.20,
    bottom or 0.80
  )
  return button
end

-- Keep breakdown helpers on one private owner so this chunk stays below Lua's 200-local limit.
local function ShowMeterRowTooltip(row)
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText("Damage breakdown")

  local restricted = Breakdown.IsSourceBlocked()
  if restricted and row.isLocalPlayer ~= true then
    GameTooltip:AddLine(
      "Detailed information for other sources is secret while in combat.",
      0.78,
      0.78,
      0.78,
      true
    )
  elseif restricted then
    GameTooltip:AddLine(
      "Left-click to open your live breakdown. Restricted spell names and icons remain hidden.",
      0.78,
      0.78,
      0.78,
      true
    )
  else
    GameTooltip:AddLine("Left-click to open this source.", 0.78, 0.78, 0.78, true)
  end

  GameTooltip:Show()
end

local function CreateMeterRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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

  local localPlayerMarker = row:CreateTexture(nil, "OVERLAY")
  localPlayerMarker:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  localPlayerMarker:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
  localPlayerMarker:SetWidth(2)
  localPlayerMarker:Hide()
  row.localPlayerMarker = localPlayerMarker

  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints(row)
  highlight:SetColorTexture(1, 1, 1, 0.08)
  row.highlight = highlight

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
  amountHost:SetWidth(170)
  row.amountHost = amountHost

  local secondarySuffix = amountHost:CreateFontString(nil, "OVERLAY")
  secondarySuffix:SetPoint("RIGHT", amountHost, "RIGHT", 0, 0)
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
    local breakdown = DamageMeters.breakdown
    if breakdown and breakdown.pinned then
      ShowMeterRowTooltip(self)
    else
      Breakdown.OpenForRow(self, false)
    end
  end)
  row:SetScript("OnLeave", function(self)
    if GameTooltip:IsOwned(self) then
      GameTooltip:Hide()
    end
    Breakdown.ScheduleTransientClose(self)
  end)
  row:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
      Breakdown.OpenForRow(self, true)
    elseif button == "RightButton" then
      Breakdown.NavigateBack(self.window)
    end
  end)

  return row
end

local function EnsureWindowRows(window, count)
  local rows = window.rows
  local created = false

  for index = #rows + 1, count do
    rows[index] = CreateMeterRow(window.viewport)
    created = true
  end

  if created then
    window.rowDisplayMeter = nil
  end
end

local function ApplyWindowPosition(window)
  local windowDB = GetWindowDB(window.index)
  window.frame:ClearAllPoints()
  window.frame:SetPoint("CENTER", UIParent, "CENTER", windowDB.x, windowDB.y)
end

local function SaveWindowPosition(window)
  local x, y = FrameUtil.GetMoverOffsets(window.frame)
  local windowDB = GetWindowDB(window.index)

  windowDB.x = Round(x)
  windowDB.y = Round(y)
  ApplyWindowPosition(window)
end

local function ResetWindowPosition(window)
  local position = DEFAULT_WINDOW_POSITIONS[window.index]
  local windowDB = GetWindowDB(window.index)

  windowDB.x = position.x
  windowDB.y = position.y
  ApplyWindowPosition(window)
end

local function GetWindowRect(window)
  local frame = window and window.frame
  if not frame then
    return nil
  end

  local left = frame:GetLeft()
  local right = frame:GetRight()
  local top = frame:GetTop()
  local bottom = frame:GetBottom()
  if not left or not right or not top or not bottom then
    return nil
  end

  return {
    left = left,
    right = right,
    top = top,
    bottom = bottom,
    width = right - left,
    height = top - bottom,
  }
end

local function PlaceWindowFromLeftTop(window, left, top)
  window.frame:ClearAllPoints()
  window.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", Round(left), Round(top))
end

local function GetCursorCoordinates()
  local scale = UIParent:GetEffectiveScale()
  local x, y = GetCursorPosition()
  return x / scale, y / scale
end

local function StopWindowDrag(window)
  local state = window.dragState
  if not state then
    return
  end

  window.dragState = nil
  window.dragDriver:Hide()
  window.snapHint:Hide()

  if state.smartSnap then
    FrameUtil.FinishExternalSmartSnapDrag(state.smartSnap)
  else
    SaveWindowPosition(window)
  end
end

local function UpdateWindowDrag(window)
  local state = window.dragState
  if not state then
    return
  end

  local cursorX, cursorY = GetCursorCoordinates()
  if IsShiftKeyDown() and state.breakSnap ~= true then
    state.breakSnap = true
    state.cursorX = cursorX
    state.cursorY = cursorY
    state.smartSnap = FrameUtil.BeginExternalSmartSnapDrag(
      MOVER_PREFIX .. window.index,
      true
    )
    return
  end

  local deltaX = cursorX - state.cursorX
  local deltaY = cursorY - state.cursorY
  if state.smartSnap then
    FrameUtil.UpdateExternalSmartSnapDrag(state.smartSnap, deltaX, deltaY)
  end
end

local function StartWindowDrag(window)
  local windowDB = GetWindowDB(window.index)
  if windowDB.locked or ns.Flags.IsEditing then
    return
  end

  local cursorX, cursorY = GetCursorCoordinates()
  local breakSnap = IsShiftKeyDown() == true
  local smartSnap = FrameUtil.BeginExternalSmartSnapDrag(
    MOVER_PREFIX .. window.index,
    breakSnap
  )
  if not smartSnap then
    return
  end

  window.dragState = {
    breakSnap = breakSnap,
    cursorX = cursorX,
    cursorY = cursorY,
    smartSnap = smartSnap,
  }
  window.snapHint:Show()
  window.dragDriver:Show()
end

function DamageMeters:CaptureWindowResizeState(window)
  local rect = GetWindowRect(window)
  if not rect then
    return nil
  end

  return {
    left = rect.left,
    right = rect.right,
    top = rect.top,
    width = rect.width,
    height = rect.height,
  }
end

function DamageMeters:ApplySnappedWindowResize(window, state, width, height, preserveRight)
  width = Round(Clamp(width, 220, 700))
  height = Round(Clamp(height, 90, 600))

  window.frame:SetSize(width, height)
  local left = preserveRight and (state.right - width) or state.left
  PlaceWindowFromLeftTop(window, left, state.top)
  FrameUtil.RelayoutSmartSnapCluster(MOVER_PREFIX .. window.index, false)
end

function DamageMeters:CommitWindowResize(window)
  local windowDB = GetWindowDB(window.index)
  windowDB.width = Round(window.frame:GetWidth())
  windowDB.height = Round(window.frame:GetHeight())
  SaveWindowPosition(window)

  FrameUtil.RelayoutSmartSnapCluster(MOVER_PREFIX .. window.index, true)
  self:RefreshWindowAppearance(window.index)
  FrameUtil.RefreshSmartSnapState(MOVER_PREFIX .. window.index)
end

function DamageMeters:ResizeWindow(index, width, height)
  local windowDB = GetWindowDB(index)
  width = Clamp(math_floor(width or windowDB.width), 220, 700)
  height = Clamp(math_floor(height or windowDB.height), 90, 600)

  local window = self.windows and self.windows[index]
  if not window or not window.frame:IsShown() then
    windowDB.width = width
    windowDB.height = height
    return
  end

  local state = self:CaptureWindowResizeState(window)
  if not state then
    return
  end

  self:ApplySnappedWindowResize(window, state, width, height, false)
  self:CommitWindowResize(window)
end

local function StopWindowResize(window)
  if not window.resizeState then
    return
  end

  window.resizeState = nil
  window.resizeDriver:Hide()
  DamageMeters:CommitWindowResize(window)
end

local function UpdateWindowResize(window)
  local state = window.resizeState
  if not state then
    return
  end

  local cursorX, cursorY = GetCursorCoordinates()
  local newWidth = state.width - (cursorX - state.cursorX)
  local newHeight = state.height - (cursorY - state.cursorY)
  DamageMeters:ApplySnappedWindowResize(window, state, newWidth, newHeight, true)
end

local function StartWindowResize(window)
  local windowDB = GetWindowDB(window.index)
  if windowDB.locked or ns.Flags.IsEditing then
    return
  end

  local state = DamageMeters:CaptureWindowResizeState(window)
  if not state then
    return
  end

  state.cursorX, state.cursorY = GetCursorCoordinates()
  window.resizeState = state
  window.resizeDriver:Show()
end

local function UpdateLockButton(window)
  local windowDB = GetWindowDB(window.index)

  window.lockButton.icon:SetTexture(windowDB.locked and PAD_LOCKED_TEXTURE or PAD_UNLOCKED_TEXTURE)
  window.lockButton.__puiIconAlpha = 0.90
  window.lockButton.icon:SetAlpha(window.lockButton.__puiIconAlpha)
  window.resizeGrip:SetShown(windowDB.locked == false)

  if windowDB.locked then
    SetHeaderButtonTooltip(
      window.lockButton,
      "Window locked",
      "Click to unlock dragging, snapping, and resizing outside PleebUI Edit Mode."
    )
  else
    SetHeaderButtonTooltip(
      window.lockButton,
      "Window unlocked",
      "Drag the header to move. The moved window snaps to stationary windows. Shift-drag prevents snapping."
    )
  end

  RefreshHeaderButtonTooltip(window.lockButton)
end

local function CompileWindowRuntime(window, windowDB)
  local runtime = window.runtime
  if not runtime then
    runtime = {}
    window.runtime = runtime
  end

  runtime.index = window.index
  runtime.meter = windowDB.meter
  runtime.session = windowDB.session
  runtime.alwaysShowMe = windowDB.alwaysShowMe == true
  return runtime
end

local function UpdateHeaderText(window, windowDB, session)
  windowDB = windowDB or GetWindowDB(window.index)

  local meterName = METER_NAMES[windowDB.meter]
  local sessionLabel

  if window.navigationMode then
    if window.headerMode ~= "NAVIGATION" then
      window.headerMode = "NAVIGATION"
      window.headerSessionLabel = nil
      window.headerDurationSecond = nil
      window.title:SetText("Damage Meters")
      window.subtitle:SetText("Choose meter")
    end

    sessionLabel = GetSessionDisplay(windowDB, session)
  else
    if window.headerMode ~= windowDB.meter then
      window.headerMode = windowDB.meter
      window.headerSessionLabel = nil
      window.headerDurationSecond = nil
      window.title:SetText(meterName)
    end

    local duration
    sessionLabel, duration = GetSessionDisplay(windowDB, session)

    if IsSecret(duration) then
      if window.headerSessionLabel ~= sessionLabel or window.headerDurationSecond ~= false then
        window.headerSessionLabel = sessionLabel
        window.headerDurationSecond = false
        window.subtitle:SetText(sessionLabel)
      end
    elseif type(duration) == "number" then
      local durationSecond = math_max(0, math_floor(duration + 0.5))
      if window.headerSessionLabel ~= sessionLabel or window.headerDurationSecond ~= durationSecond then
        window.headerSessionLabel = sessionLabel
        window.headerDurationSecond = durationSecond
        window.subtitle:SetText(sessionLabel .. " · " .. FormatDuration(duration))
      end
    elseif window.headerSessionLabel ~= sessionLabel or window.headerDurationSecond ~= nil then
      window.headerSessionLabel = sessionLabel
      window.headerDurationSecond = nil
      window.subtitle:SetText(sessionLabel)
    end
  end

  if window.headerMeterTooltip ~= meterName then
    window.headerMeterTooltip = meterName
    SetHeaderButtonTooltip(window.meterButton, "Change meter", meterName)
    RefreshHeaderButtonTooltip(window.meterButton)
  end

  if window.headerSessionTooltip ~= sessionLabel then
    window.headerSessionTooltip = sessionLabel
    SetHeaderButtonTooltip(window.sessionButton, "Change segment", sessionLabel)
    RefreshHeaderButtonTooltip(window.sessionButton)
  end
end

local function ApplyWindowStyle(window)
  local db = DamageMeters.db.profile
  local windowDB = GetWindowDB(window.index)
  local colors = Theme.GetColors()
  local barTexture = Theme.GetBarTexture()
  local headerHeight = db.headerHeight
  local buttonSize = math_min(22, headerHeight - 6)
  local barHeight = db.barHeight
  local showIcons = db.showSpecIcons
  local fontSize = db.fontSize

  window.frame:SetSize(windowDB.width, windowDB.height)
  Theme.SetSquareBackdrop(window.frame, {
    bg = colors.background,
    border = colors.border,
  }, 2)

  window.header:SetHeight(headerHeight)
  window.headerBackground:SetColorTexture(
    colors.background[1],
    colors.background[2],
    colors.background[3],
    colors.background[4]
  )
  window.headerBorder:SetColorTexture(
    colors.border[1],
    colors.border[2],
    colors.border[3],
    colors.border[4]
  )

  Theme.ApplyFont(window.title, "header", fontSize + 1, "OUTLINE")
  Theme.ApplyFont(window.subtitle, "tiny", math_max(8, fontSize - 2), "OUTLINE")
  Theme.ApplyFont(window.snapHint, "tiny", math_max(9, fontSize - 1), "OUTLINE")
  window.title:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  window.subtitle:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.72)
  window.snapHint:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 1)
  window.snapHint:SetText("Smart Snap highlights compatible meters. Shift-drag detaches the moved meter.")

  local buttons = window.headerButtons
  for index = 1, #buttons do
    local button = buttons[index]
    button:SetSize(buttonSize, buttonSize)
    button:ClearAllPoints()
    button:SetPoint("RIGHT", window.header, "RIGHT", -4 - ((index - 1) * (buttonSize + 2)), 0)
  end

  window.title:ClearAllPoints()
  window.title:SetPoint("TOPLEFT", window.header, "TOPLEFT", 8, -3)
  window.title:SetPoint("RIGHT", buttons[#buttons], "LEFT", -6, 0)

  window.subtitle:ClearAllPoints()
  window.subtitle:SetPoint("BOTTOMLEFT", window.header, "BOTTOMLEFT", 8, 3)
  window.subtitle:SetPoint("RIGHT", buttons[#buttons], "LEFT", -6, 0)

  window.viewport:ClearAllPoints()
  window.viewport:SetPoint("TOPLEFT", window.header, "BOTTOMLEFT", 4, -4)
  window.viewport:SetPoint("BOTTOMRIGHT", window.frame, "BOTTOMRIGHT", -4, 4)

  local visibleRowCount = GetViewportRowCount(
    window.viewport,
    db.barHeight,
    db.barSpacing,
    ROW_POOL_SIZE
  )
  local activeRowCount = math_min(ROW_POOL_SIZE, visibleRowCount + 1)
  EnsureWindowRows(window, activeRowCount)
  window.activeRowCount = activeRowCount

  local navigation = window.meterNavigation
  if navigation then
    navigation:ClearAllPoints()
    navigation:SetAllPoints(window.viewport)

    local padding = 4
    local columnGap = 4
    local navigationWidth = window.viewport:GetWidth()
    local columnWidth = math_floor(
      (navigationWidth - padding * 2 - columnGap * (#METER_CATEGORIES - 1))
        / #METER_CATEGORIES
    )

    for categoryIndex = 1, #METER_CATEGORIES do
      local categoryUI = window.meterNavigationCategories[categoryIndex]
      local columnX = padding + (categoryIndex - 1) * (columnWidth + columnGap)

      categoryUI.title:ClearAllPoints()
      categoryUI.title:SetPoint("TOPLEFT", navigation, "TOPLEFT", columnX, -4)
      categoryUI.title:SetWidth(columnWidth)
      Theme.ApplyFont(categoryUI.title, "header", math_max(8, fontSize - 1), "OUTLINE")
      categoryUI.title:SetText(METER_CATEGORIES[categoryIndex].name)
      categoryUI.title:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 1)

      for meterIndex = 1, #categoryUI.buttons do
        local button = categoryUI.buttons[meterIndex]
        button:ClearAllPoints()
        button:SetPoint(
          "TOPLEFT",
          navigation,
          "TOPLEFT",
          columnX,
          -24 - ((meterIndex - 1) * 20)
        )
        button:SetSize(columnWidth, 18)

        Theme.ApplyFont(button.text, "tiny", math_max(8, fontSize - 2), "OUTLINE")
        button.text:SetText(METER_NAMES[button.meterKey])
        button.text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.90)

        if button.meterKey == windowDB.meter then
          button.background:SetColorTexture(
            colors.accent[1],
            colors.accent[2],
            colors.accent[3],
            0.32
          )
        else
          button.background:SetColorTexture(
            colors.control[1],
            colors.control[2],
            colors.control[3],
            0.72
          )
        end
      end
    end

    navigation:SetShown(window.navigationMode == true)
  end

  window.emptyText:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.62)
  Theme.ApplyFont(window.emptyText, "body", fontSize, "OUTLINE")

  for index = 1, activeRowCount do
    local row = window.rows[index]

    row:SetHeight(barHeight)
    row.fill:SetStatusBarTexture(barTexture)
    row.fill:SetAlpha(db.barAlpha)
    row.background:SetColorTexture(
      colors.control[1],
      colors.control[2],
      colors.control[3],
      0.48
    )
    row.localPlayerMarker:SetColorTexture(
      colors.accent[1],
      colors.accent[2],
      colors.accent[3],
      1
    )

    Theme.ApplyFont(row.rank, "tiny", math_max(8, fontSize - 1), "OUTLINE")
    Theme.ApplyFont(row.name, "body", fontSize, "OUTLINE")
    Theme.ApplyFont(row.primaryAmount, "body", fontSize, "OUTLINE")
    Theme.ApplyFont(row.primarySuffix, "tiny", math_max(8, fontSize - 2), "OUTLINE")
    Theme.ApplyFont(row.amountSeparator, "tiny", math_max(8, fontSize - 2), "OUTLINE")
    Theme.ApplyFont(row.secondaryAmount, "body", fontSize, "OUTLINE")
    Theme.ApplyFont(row.secondarySuffix, "tiny", math_max(8, fontSize - 2), "OUTLINE")

    row.rank:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.82)
    row.name:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 1)
    row.primaryAmount:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 1)
    row.primarySuffix:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.72)
    row.amountSeparator:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.55)
    row.secondaryAmount:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.78)
    row.secondarySuffix:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.62)

    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "LEFT", 29, 0)
    row.icon:SetSize(barHeight - 4, barHeight - 4)

    row.name:ClearAllPoints()
    if showIcons then
      row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    else
      row.name:SetPoint("LEFT", row, "LEFT", 30, 0)
    end
    row.name:SetPoint("RIGHT", row.amountHost, "LEFT", -8, 0)
  end

  UpdateLockButton(window)
  UpdateHeaderText(window, windowDB)
end

local function ApplyWindowLayout(window)
  local db = DamageMeters.db.profile
  local rowStride = db.barHeight + db.barSpacing

  for index = 1, window.activeRowCount do
    local row = window.rows[index]
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", window.viewport, "TOPLEFT", 0, -((index - 1) * rowStride))
    row:SetPoint("TOPRIGHT", window.viewport, "TOPRIGHT", 0, -((index - 1) * rowStride))
  end

  window.visibleRowCount = nil
end

local function GetVisibleRowCount(window)
  local db = DamageMeters.db.profile
  return GetViewportRowCount(window.viewport, db.barHeight, db.barSpacing, ROW_POOL_SIZE)
end

local function ConfigureWindowRowDisplay(window, meterKey)
  if window.rowDisplayMeter == meterKey then
    return
  end

  local countOnly = meterKey == "INTERRUPTS" or meterKey == "DISPELS" or meterKey == "DEATHS"
  local ratePrimary = meterKey == "DPS" or meterKey == "HPS"

  for index = 1, window.activeRowCount do
    local row = window.rows[index]
    row.primarySuffix:SetText("")

    if countOnly then
      row.amountSeparator:SetText("")
      row.secondaryAmount:SetText("")
      row.secondarySuffix:SetText("")
    else
      row.amountSeparator:SetText("·")
      row.secondarySuffix:SetText(ratePrimary and "" or "/s")
    end
  end

  window.rowDisplayMeter = meterKey
end

local function SetAbbreviatedRowValue(row, modeField, valueField, fontString, mode, value)
  if IsSecret(value) then
    row[modeField] = nil
    row[valueField] = nil
    fontString:SetText(AbbreviateNumbers(value, NUMBER_ABBREVIATION_OPTIONS))
    return
  end

  if row[modeField] == mode and row[valueField] == value then
    return
  end

  row[modeField] = mode
  row[valueField] = value
  fontString:SetText(AbbreviateNumbers(value, NUMBER_ABBREVIATION_OPTIONS))
end

local function SetDeathTimeRowValue(row, value)
  if IsSecret(value) then
    row.primaryAmountMode = nil
    row.primaryAmountValue = nil
    SetDeathTimeText(row.primaryAmount, value)
    return
  end

  if row.primaryAmountMode == "DEATH_TIME" and row.primaryAmountValue == value then
    return
  end

  row.primaryAmountMode = "DEATH_TIME"
  row.primaryAmountValue = value
  SetDeathTimeText(row.primaryAmount, value)
end

local function SetRowSource(window, row, source, rank, maxAmount, meterKey)
  local classFilename = source.classFilename

  if row.sourceIndex ~= rank then
    row.sourceIndex = rank
    row.rank:SetText(RANK_TEXT[rank] or (rank .. "."))
  end

  if row.classFilename ~= classFilename then
    row.classFilename = classFilename
    local classColor = RAID_CLASS_COLORS[classFilename]
    if classColor then
      row.fill:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1)
    else
      row.fill:SetStatusBarColor(0.62, 0.62, 0.62, 1)
    end
  end

  local totalAmount = source.totalAmount
  if meterKey == "DEATHS" and source.__puiSummaryDeathCount ~= true then
    if row.fillMode ~= "FULL" then
      row.fillMode = "FULL"
      row.fillMaxAmount = nil
      row.fillAmount = nil
      row.fill:SetMinMaxValues(0, 1)
      row.fill:SetValue(1)
    end
  else
    if row.fillMode ~= "AMOUNT" then
      row.fillMode = "AMOUNT"
      row.fillMaxAmount = nil
      row.fillAmount = nil
    end

    if IsSecret(maxAmount) then
      row.fillMaxAmount = nil
      row.fill:SetMinMaxValues(0, maxAmount)
    elseif row.fillMaxAmount ~= maxAmount then
      row.fillMaxAmount = maxAmount
      row.fill:SetMinMaxValues(0, maxAmount)
    end

    if IsSecret(totalAmount) then
      row.fillAmount = nil
      row.fill:SetValue(totalAmount)
    elseif row.fillAmount ~= totalAmount then
      row.fillAmount = totalAmount
      row.fill:SetValue(totalAmount)
    end
  end

  local sourceName = source.name
  if IsSecret(sourceName) then
    row.name:SetText(sourceName)
    row.plainSourceName = nil
    if meterKey == "DEATHS" then
      row.sourceDisplayName = nil
    end
  else
    local displayName
    if sourceName == "" then
      displayName = "Unknown"
    else
      displayName = Ambiguate(sourceName, "short")
    end

    if row.plainSourceName ~= displayName then
      row.plainSourceName = displayName
      row.name:SetText(displayName)
    end

    if meterKey == "DEATHS" then
      row.sourceDisplayName = displayName
    end
  end

  if meterKey == "DEATHS" then
    if source.__puiSummaryDeathCount == true then
      SetAbbreviatedRowValue(
        row,
        "primaryAmountMode",
        "primaryAmountValue",
        row.primaryAmount,
        "DEATH_COUNT",
        totalAmount
      )
    else
      SetDeathTimeRowValue(row, source.deathTimeSeconds)
    end
  elseif meterKey == "INTERRUPTS" or meterKey == "DISPELS" then
    SetAbbreviatedRowValue(
      row,
      "primaryAmountMode",
      "primaryAmountValue",
      row.primaryAmount,
      "TOTAL",
      totalAmount
    )
  elseif meterKey == "DPS" or meterKey == "HPS" then
    SetAbbreviatedRowValue(
      row,
      "primaryAmountMode",
      "primaryAmountValue",
      row.primaryAmount,
      "RATE",
      source.amountPerSecond
    )
    SetAbbreviatedRowValue(
      row,
      "secondaryAmountMode",
      "secondaryAmountValue",
      row.secondaryAmount,
      "TOTAL",
      totalAmount
    )
  else
    SetAbbreviatedRowValue(
      row,
      "primaryAmountMode",
      "primaryAmountValue",
      row.primaryAmount,
      "TOTAL",
      totalAmount
    )
    SetAbbreviatedRowValue(
      row,
      "secondaryAmountMode",
      "secondaryAmountValue",
      row.secondaryAmount,
      "RATE",
      source.amountPerSecond
    )
  end

  local iconKind
  local iconValue
  local specIconID = source.specIconID
  if DamageMeters.runtimeShowSpecIcons then
    if type(specIconID) == "number" and specIconID > 0 then
      iconKind = "SPEC"
      iconValue = specIconID
    elseif type(classFilename) == "string" and classFilename ~= "" then
      iconKind = "CLASS"
      iconValue = GetClassAtlas(classFilename)
    end
  end

  if row.iconKind ~= iconKind or row.iconValue ~= iconValue then
    row.iconKind = iconKind
    row.iconValue = iconValue
    if iconKind == "SPEC" then
      row.icon:SetTexture(iconValue)
      row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      row.icon:Show()
    elseif iconKind == "CLASS" and iconValue then
      row.icon:SetAtlas(iconValue)
      row.icon:Show()
    else
      row.icon:Hide()
    end
  end

  local isLocalPlayer = source.isLocalPlayer == true
  if row.isLocalPlayer ~= isLocalPlayer then
    row.isLocalPlayer = isLocalPlayer
    row.localPlayerMarker:SetShown(isLocalPlayer)
  end

  row.window = window
  row.deathRecapID = source.deathRecapID
  if not row:IsShown() then
    row:Show()
  end
end

local function HideWindowRowsFrom(window, firstIndex)
  local usedRows = window.usedRows or 0
  for index = firstIndex, usedRows do
    local row = window.rows[index]
    row.window = nil
    row.sourceIndex = nil
    row.isLocalPlayer = nil
    row.classFilename = nil
    row.deathRecapID = nil
    row.sourceDisplayName = nil
    row.fillMode = nil
    row.fillMaxAmount = nil
    row.fillAmount = nil
    row.primaryAmountMode = nil
    row.primaryAmountValue = nil
    row.secondaryAmountMode = nil
    row.secondaryAmountValue = nil
    row.iconKind = nil
    row.iconValue = nil
    row:Hide()
    row.icon:Hide()
    row.localPlayerMarker:Hide()
  end
  window.usedRows = firstIndex - 1
end

local function FindLocalPlayerSourceIndex(sources)
  for index = 1, #sources do
    if sources[index].isLocalPlayer == true then
      return index
    end
  end

  return nil
end

local function RefreshWindow(window, session, windowDB)
  if not DamageMeters.runtimeEnabled or not window.frame:IsShown() then
    return
  end

  if windowDB and windowDB ~= window.runtime then
    windowDB = CompileWindowRuntime(window, windowDB)
  else
    windowDB = window.runtime
  end

  if window.navigationMode then
    UpdateHeaderText(window, windowDB)
    if (window.usedRows or 0) > 0 then
      HideWindowRowsFrom(window, 1)
    end
    window.emptyText:Hide()
    if window.meterNavigation then
      window.meterNavigation:Show()
    end
    return
  end

  if window.rowDisplayMeter ~= windowDB.meter then
    ConfigureWindowRowDisplay(window, windowDB.meter)
  end

  if session == nil then
    session = GetCombatSession(windowDB, windowDB.meter)
  elseif session == NO_COMBAT_SESSION then
    session = nil
  end

  UpdateHeaderText(window, windowDB, session)

  if not session then
    window.firstSource = 1
    window.sourceCount = 0
    if (window.usedRows or 0) > 0 then
      HideWindowRowsFrom(window, 1)
    end
    window.emptyText:Show()
    return
  end

  local sources = session.combatSources
  local sourceCount = #sources
  window.sourceCount = sourceCount

  if sourceCount == 0 then
    window.firstSource = 1
    if (window.usedRows or 0) > 0 then
      HideWindowRowsFrom(window, 1)
    end
    window.emptyText:Show()
    return
  end

  window.emptyText:Hide()

  local visibleCount = window.visibleRowCount
  if not visibleCount then
    visibleCount = GetVisibleRowCount(window)
    window.visibleRowCount = visibleCount
  end

  local maximumFirstSource = math_max(1, sourceCount - visibleCount + 1)
  window.firstSource = Clamp(window.firstSource or 1, 1, maximumFirstSource)

  local lastSource = math_min(sourceCount, window.firstSource + visibleCount - 1)
  local localPlayerIndex
  if windowDB.alwaysShowMe and sourceCount > visibleCount then
    localPlayerIndex = FindLocalPlayerSourceIndex(sources)
  end

  local pinLocalPlayerAbove = localPlayerIndex and localPlayerIndex < window.firstSource
  local pinLocalPlayerBelow = localPlayerIndex and localPlayerIndex > lastSource
  local rowIndex = 0

  if pinLocalPlayerAbove then
    rowIndex = 1
    SetRowSource(
      window,
      window.rows[rowIndex],
      sources[localPlayerIndex],
      localPlayerIndex,
      session.maxAmount,
      windowDB.meter
    )
  end

  local normalRowLimit = visibleCount
  if pinLocalPlayerAbove or pinLocalPlayerBelow then
    normalRowLimit = visibleCount - 1
  end

  local normalLastSource = math_min(lastSource, window.firstSource + normalRowLimit - 1)
  for sourceIndex = window.firstSource, normalLastSource do
    rowIndex = rowIndex + 1
    SetRowSource(
      window,
      window.rows[rowIndex],
      sources[sourceIndex],
      sourceIndex,
      session.maxAmount,
      windowDB.meter
    )
  end

  if pinLocalPlayerBelow then
    rowIndex = rowIndex + 1
    SetRowSource(
      window,
      window.rows[rowIndex],
      sources[localPlayerIndex],
      localPlayerIndex,
      session.maxAmount,
      windowDB.meter
    )
  end

  if (window.usedRows or 0) > rowIndex then
    HideWindowRowsFrom(window, rowIndex + 1)
  end
  window.usedRows = rowIndex
end

local function UpdateBreakdownForWindow(window)
  local selection = DamageMeters.breakdownSelection
  if not selection or selection.ownerWindow ~= window then
    return
  end

  local windowDB = GetWindowDB(window.index)
  if selection.mode == "DEATH_RECAP"
    or selection.mode == "ENEMY_PLAYERS"
    or selection.mode == "LIVE_ENEMY_PLAYERS"
  then
    Breakdown.Close()
    return
  end

  selection.meterKey = windowDB.meter
  selection.sessionKey = windowDB.session
  local windowSelection = GetWindowSelection(windowDB)
  selection.sessionID = IsAvailableSessionSelection(windowSelection)
    and windowSelection.sessionID
    or nil

  local breakdown = DamageMeters.breakdown
  if breakdown then
    breakdown.firstSpell = 1
    breakdown.firstTarget = 1
    Breakdown.ApplyPosition(breakdown)
    Breakdown.Refresh()
  end
end

local function SetWindowNavigationMode(window, enabled)
  if not window then
    return
  end

  window.navigationMode = enabled == true

  if window.navigationMode then
    window.needsCombatRefresh = nil
    HideWindowRowsFrom(window, 1)
    window.emptyText:Hide()
  end

  if window.meterNavigation then
    window.meterNavigation:SetShown(window.navigationMode)
  end

  UpdateHeaderText(window)
end

local function ShowMeterNavigation(window)
  if not window then
    return
  end

  SegmentPicker.Hide()
  local selection = DamageMeters.breakdownSelection
  if selection and selection.ownerWindow == window then
    Breakdown.Close()
  end

  SetWindowNavigationMode(window, true)
end

local function SelectWindowMeter(window, meterKey)
  if not window or not METER_TYPES[meterKey] then
    return
  end

  local windowDB = GetWindowDB(window.index)
  windowDB.meter = meterKey
  window.firstSource = 1
  window.needsCombatRefresh = nil

  ApplyWindowStyle(window)
  ApplyWindowLayout(window)
  SetWindowNavigationMode(window, false)
  RefreshWindow(window, nil, windowDB)
  DamageMeters:CompileCombatEventWindows()
  UpdateBreakdownForWindow(window)
end

local function SelectWindowSession(window, sessionKey)
  local windowDB = GetWindowDB(window.index)
  windowDB.session = sessionKey or "CURRENT"
  SetWindowSelection(window.index, nil)
  window.firstSource = 1
  window.needsCombatRefresh = nil
  RefreshWindow(window, nil, windowDB)
  UpdateBreakdownForWindow(window)
end

local function SelectWindowRecord(window, selection)
  local windowDB = GetWindowDB(window.index)
  SetWindowSelection(window.index, selection)
  window.firstSource = 1
  window.needsCombatRefresh = nil

  if DamageMeters.breakdownSelection and DamageMeters.breakdownSelection.ownerWindow == window then
    Breakdown.Close()
  end

  RefreshWindow(window, nil, windowDB)
end

local function CreateDamageMeterWindow(index)
  local window = {
    index = index,
    rows = {},
    firstSource = 1,
    sourceCount = 0,
    usedRows = 0,
  }

  local frame = CreateFrame("Frame", "PUI_DamageMeter" .. index, UIParent)
  frame:SetFrameStrata("LOW")
  frame:SetFrameLevel(10 + index)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:Hide()
  window.frame = frame

  local snapHint = frame:CreateFontString(nil, "OVERLAY")
  snapHint:SetPoint("BOTTOM", frame, "TOP", 0, 6)
  snapHint:Hide()
  window.snapHint = snapHint

  local header = CreateFrame("Frame", nil, frame)
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
  header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  window.header = header

  local headerBackground = header:CreateTexture(nil, "BACKGROUND")
  headerBackground:SetAllPoints(header)
  window.headerBackground = headerBackground

  local headerBorder = header:CreateTexture(nil, "BORDER")
  headerBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
  headerBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
  headerBorder:SetHeight(1)
  window.headerBorder = headerBorder

  local title = header:CreateFontString(nil, "OVERLAY")
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  window.title = title

  local subtitle = header:CreateFontString(nil, "OVERLAY")
  subtitle:SetJustifyH("LEFT")
  subtitle:SetWordWrap(false)
  window.subtitle = subtitle

  local closeButton = CreateTextureButton(header, MINIMIZE_TEXTURE)
  local configButton = CreateTextureButton(header, CONFIG_TEXTURE)
  local lockButton = CreateTextureButton(header, PAD_LOCKED_TEXTURE)
  local resetButton = CreateTextureButton(header, TRASH_TEXTURE)
  local sessionButton = CreateTextureButton(
    header,
    LIST_TEXTURE,
    0.25,
    0.75,
    0.15,
    0.85
  )
  local meterButton = CreateAtlasButton(header, "Azerite-PointingArrow")
  configButton.HandlesGlobalMouseEvent = SegmentPicker.ContextMenuButtonHandlesGlobalMouseEvent
  window.closeButton = closeButton
  window.configButton = configButton
  window.lockButton = lockButton
  window.resetButton = resetButton
  window.sessionButton = sessionButton
  window.meterButton = meterButton
  window.headerButtons = {
    closeButton,
    configButton,
    lockButton,
    resetButton,
    sessionButton,
    meterButton,
  }

  SetHeaderButtonTooltip(
    closeButton,
    "Minimize window",
    "Hide this window without deleting its settings."
  )
  SetHeaderButtonTooltip(
    configButton,
    "Window menu",
    "Open window actions such as hide, delete, clear unsaved segments, and settings."
  )
  SetHeaderButtonTooltip(
    resetButton,
    "Clear unsaved segments",
    "Reset Blizzard sessions and clear unsaved PleebUI history. Saved bosses and keystones are kept."
  )

  closeButton:SetScript("OnClick", function()
    DamageMeters:CloseWindow(index)
  end)

  configButton:SetScript("OnClick", function()
    SegmentPicker.ShowWindowConfigMenu(window)
  end)

  lockButton:SetScript("OnClick", function()
    local windowDB = GetWindowDB(index)
    windowDB.locked = not windowDB.locked
    UpdateLockButton(window)
  end)

  resetButton:SetScript("OnClick", function()
    SegmentPicker.ConfirmClearUnsavedSegments()
  end)

  sessionButton:SetScript("OnClick", function()
    SegmentPicker.Show(window)
  end)

  meterButton:SetScript("OnClick", function()
    ShowMeterNavigation(window)
  end)

  header:SetScript("OnDragStart", function()
    StartWindowDrag(window)
  end)

  header:SetScript("OnDragStop", function()
    StopWindowDrag(window)
  end)

  local dragDriver = CreateFrame("Frame", nil, UIParent)
  dragDriver:SetScript("OnUpdate", function()
    UpdateWindowDrag(window)
  end)
  dragDriver:Hide()
  window.dragDriver = dragDriver

  local resizeGrip = CreateFrame("Button", nil, frame)
  resizeGrip:SetSize(22, 22)
  resizeGrip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
  resizeGrip:SetFrameLevel(frame:GetFrameLevel() + 10)
  resizeGrip:RegisterForDrag("LeftButton")
  resizeGrip:EnableMouse(true)
  window.resizeGrip = resizeGrip

  local resizeTexture = resizeGrip:CreateTexture(nil, "ARTWORK")
  resizeTexture:SetAllPoints(resizeGrip)
  resizeTexture:SetAtlas("damagemeters-scalehandle")
  resizeTexture:SetTexCoord(1, 0, 0, 1)
  resizeTexture:SetAlpha(0.72)
  resizeGrip.texture = resizeTexture

  local resizeHighlight = resizeGrip:CreateTexture(nil, "HIGHLIGHT")
  resizeHighlight:SetAllPoints(resizeGrip)
  resizeHighlight:SetAtlas("damagemeters-scalehandle-hover")
  resizeHighlight:SetTexCoord(1, 0, 0, 1)

  SetHeaderButtonTooltip(
    resizeGrip,
    "Resize window",
    "Top/bottom snaps share width. Left/right snaps share height."
  )
  resizeGrip:SetScript("OnEnter", function(self)
    ShowHeaderButtonTooltip(self)
  end)
  resizeGrip:SetScript("OnLeave", function()
    HideHeaderButtonTooltip()
  end)
  resizeGrip:SetScript("OnDragStart", function()
    StartWindowResize(window)
  end)
  resizeGrip:SetScript("OnDragStop", function()
    StopWindowResize(window)
  end)

  local resizeDriver = CreateFrame("Frame", nil, UIParent)
  resizeDriver:SetScript("OnUpdate", function()
    UpdateWindowResize(window)
  end)
  resizeDriver:Hide()
  window.resizeDriver = resizeDriver

  local viewport = CreateFrame("Frame", nil, frame)
  viewport:SetClipsChildren(true)
  viewport:EnableMouse(true)
  viewport:EnableMouseWheel(true)
  window.viewport = viewport

  local meterNavigation = CreateFrame("Frame", nil, viewport)
  meterNavigation:SetAllPoints(viewport)
  meterNavigation:EnableMouse(true)
  meterNavigation:Hide()
  window.meterNavigation = meterNavigation
  window.meterNavigationCategories = {}
  window.meterNavigationButtons = {}

  for categoryIndex = 1, #METER_CATEGORIES do
    local category = METER_CATEGORIES[categoryIndex]
    local categoryUI = {
      buttons = {},
    }

    local categoryTitle = meterNavigation:CreateFontString(nil, "OVERLAY")
    categoryTitle:SetJustifyH("LEFT")
    categoryUI.title = categoryTitle

    for meterIndex = 1, #category.keys do
      local meterKey = category.keys[meterIndex]
      local button = CreateFrame("Button", nil, meterNavigation)
      button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      button.meterKey = meterKey

      local background = button:CreateTexture(nil, "BACKGROUND")
      background:SetAllPoints(button)
      button.background = background

      local highlight = button:CreateTexture(nil, "HIGHLIGHT")
      highlight:SetAllPoints(button)
      highlight:SetColorTexture(1, 1, 1, 0.08)

      local text = button:CreateFontString(nil, "OVERLAY")
      text:SetPoint("LEFT", button, "LEFT", 5, 0)
      text:SetPoint("RIGHT", button, "RIGHT", -5, 0)
      text:SetJustifyH("LEFT")
      text:SetWordWrap(false)
      button.text = text

      button:SetScript("OnClick", function(self, buttonName)
        if buttonName == "LeftButton" then
          SelectWindowMeter(window, self.meterKey)
        elseif buttonName == "RightButton" then
          Breakdown.NavigateBack(window)
        end
      end)

      categoryUI.buttons[#categoryUI.buttons + 1] = button
      window.meterNavigationButtons[meterKey] = button
    end

    window.meterNavigationCategories[categoryIndex] = categoryUI
  end

  meterNavigation:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" then
      Breakdown.NavigateBack(window)
    end
  end)

  viewport:SetScript("OnMouseWheel", function(_, delta)
    if window.navigationMode then
      return
    end

    local visibleCount = GetVisibleRowCount(window)
    local maximumFirstSource = math_max(1, window.sourceCount - visibleCount + 1)
    window.firstSource = Clamp((window.firstSource or 1) - delta, 1, maximumFirstSource)
    RefreshWindow(window)
  end)

  viewport:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" then
      Breakdown.NavigateBack(window)
    end
  end)

  frame:SetScript("OnHide", function()
    window.navigationMode = false
    meterNavigation:Hide()
  end)

  local emptyText = viewport:CreateFontString(nil, "OVERLAY")
  emptyText:SetPoint("CENTER", viewport, "CENTER", 0, 0)
  Theme.ApplyFont(emptyText, "body", DamageMeters.db.profile.fontSize, "OUTLINE")
  emptyText:SetText("No combat data")
  window.emptyText = emptyText

  window.moverOptions = {
    label = "Damage Meter " .. index,
    useOverlayDrag = true,
    onDragStop = function()
      SaveWindowPosition(window)
    end,
    resetPosition = function()
      ResetWindowPosition(window)
    end,
    optionsSection = "DamageMeters",
    optionsKey = "window" .. index,
    smartSnap = {
      family = "damageMeters",
      families = {
        positionOnly = true,
        raidUtility = true,
      },
      relationSizeSync = true,
      applyDimensions = function(width, height)
        local windowDB = GetWindowDB(index)
        if width then
          windowDB.width = Round(Clamp(width, 220, 700))
          frame:SetWidth(windowDB.width)
        end
        if height then
          windowDB.height = Round(Clamp(height, 90, 600))
          frame:SetHeight(windowDB.height)
        end
        DamageMeters:RefreshWindowAppearance(index)
      end,
    },
    quickSettings = function()
      local windowDB = GetWindowDB(index)
      return {
        ownerKey = MOVER_PREFIX .. index,
        title = "Damage Meter " .. index,
        description = "Live damage meter settings.",
        controls = {
          {
            type = "slider",
            label = "Width",
            min = 220,
            max = 700,
            step = 5,
            get = function() return windowDB.width end,
            set = function(value)
              DamageMeters:ResizeWindow(index, value, windowDB.height)
            end,
          },
          {
            type = "slider",
            label = "Height",
            min = 90,
            max = 600,
            step = 5,
            get = function() return windowDB.height end,
            set = function(value)
              DamageMeters:ResizeWindow(index, windowDB.width, value)
            end,
          },
          {
            type = "slider",
            label = "Font size",
            min = 8,
            max = 24,
            step = 1,
            get = function() return DamageMeters.db.profile.fontSize end,
            set = function(value)
              DamageMeters.db.profile.fontSize = Clamp(math_floor(value), 8, 24)
              DamageMeters:RefreshAppearance()
            end,
          },
        },
      }
    end,
  }

  ApplyWindowPosition(window)
  return window
end

function DamageMeters:EnsureWindows()
  self.windows = self.windows or {}

  for index = 1, self.db.profile.windowCount do
    if not self.windows[index] then
      self.windows[index] = CreateDamageMeterWindow(index)
    end
  end
end

function DamageMeters:UnregisterWindowMovers()
  for index = 1, MAX_WINDOWS do
    FrameUtil:UnregisterMover(MOVER_PREFIX .. index)
  end
end

function DamageMeters:CompileCombatEventWindows()
  local windowsByMeterType = {}

  if self.runtimeVisible and self.windows then
    for index = 1, self.runtimeWindowCount do
      local window = self.windows[index]
      if window and window.frame:IsShown() and window.runtime then
        local meterType = METER_TYPES[window.runtime.meter]
        local meterWindows = windowsByMeterType[meterType]
        if not meterWindows then
          meterWindows = {}
          windowsByMeterType[meterType] = meterWindows
        end
        meterWindows[#meterWindows + 1] = window
      end
    end
  end

  self.combatEventWindowsByMeterType = windowsByMeterType
end

function DamageMeters:CompileCombatRefreshWindows()
  local windows = {}

  if self.runtimeVisible and self.windows then
    for index = 1, self.runtimeWindowCount do
      local window = self.windows[index]
      if window and window.frame:IsShown() and window.runtime then
        windows[#windows + 1] = window
      end
    end
  end

  self.combatRefreshWindows = windows
end

function DamageMeters:ApplyWindowConfiguration()
  local db = self.db.profile
  self:EnsureWindows()

  for index = 1, MAX_WINDOWS do
    local window = self.windows[index]
    local windowDB = index <= db.windowCount and GetWindowDB(index) or nil
    if windowDB then
      CompileWindowRuntime(window, windowDB)
    elseif window then
      window.runtime = nil
    end

    if db.visible and windowDB and windowDB.shown then
      ApplyWindowPosition(window)
      ApplyWindowStyle(window)
      ApplyWindowLayout(window)
      window.frame:Show()
      FrameUtil:RegisterMover(MOVER_PREFIX .. window.index, window.frame, window.moverOptions)
    elseif window then
      window.dragState = nil
      window.resizeState = nil
      window.dragDriver:Hide()
      window.resizeDriver:Hide()
      window.frame:Hide()
      FrameUtil:UnregisterMover(MOVER_PREFIX .. index)
    end
  end

  self:CompileCombatEventWindows()
  self:CompileCombatRefreshWindows()

  local selection = self.breakdownSelection
  if selection then
    local ownerDB = selection.ownerIndex <= db.windowCount and GetWindowDB(selection.ownerIndex) or nil
    if not db.visible or not ownerDB or ownerDB.shown == false then
      Breakdown.Close()
    elseif self.breakdown and self.breakdown.frame:IsShown() then
      Breakdown.ApplyStyle(self.breakdown)
    end
  end
end

function DamageMeters:RefreshWindowAppearance(index)
  local window = self.windows and self.windows[index]
  if not window or not window.frame:IsShown() then
    return
  end

  ApplyWindowStyle(window)
  ApplyWindowLayout(window)
  RefreshWindow(window, nil, GetWindowDB(index))

  local selection = self.breakdownSelection
  if selection and selection.ownerWindow == window and self.breakdown then
    Breakdown.ApplyPosition(self.breakdown)
  end
end

function DamageMeters:RefreshAppearance()
  if not self.runtimeEnabled then
    return
  end

  local db = self.db.profile
  for index = 1, db.windowCount do
    local window = self.windows[index]
    if window and window.frame:IsShown() then
      ApplyWindowStyle(window)
      ApplyWindowLayout(window)
    end
  end

  local breakdown = self.breakdown
  if breakdown then
    Breakdown.ApplyStyle(breakdown)
  end

  local segmentPicker = self.segmentPicker
  if segmentPicker then
    SegmentPicker.ApplyStyle(segmentPicker)
    if segmentPicker:IsShown() then
      SegmentPicker.Refresh(segmentPicker)
    end
  end

  self:RefreshWindows()
end

function DamageMeters:RefreshBreakdownAppearance()
  local breakdown = self.breakdown
  if not breakdown then
    return
  end

  Breakdown.ApplyStyle(breakdown)
  if breakdown.frame:IsShown() then
    Breakdown.Refresh()
  end
end

function DamageMeters:RefreshBreakdownData()
  if self.breakdown and self.breakdown.frame:IsShown() then
    Breakdown.Refresh()
  end
end

local function DoesWindowSessionMatchEvent(windowRuntime, sessionID)
  local selection = GetWindowSelection(windowRuntime)
  if IsAvailableSessionSelection(selection) then
    return selection.sessionID == sessionID
  end
  if selection then
    return false
  end

  return sessionID == 0
end

function DamageMeters:RefreshWindows()
  if not self.runtimeEnabled or not self.runtimeVisible then
    return
  end

  local sessionCache = AcquireRefreshSessionCache()
  for index = 1, self.runtimeWindowCount do
    local window = self.windows[index]
    if window and window.frame:IsShown() then
      local windowRuntime = window.runtime
      if window.navigationMode then
        RefreshWindow(window, nil, windowRuntime)
      else
        RefreshWindow(
          window,
          GetRefreshSession(sessionCache, windowRuntime, windowRuntime.meter),
          windowRuntime
        )
      end
    end
  end
  ReleaseRefreshSessionCache(sessionCache)

  Breakdown.Refresh()
end

function DamageMeters:RefreshTheme()
  if not self.runtimeEnabled or not self.db or not self.db.profile then
    return
  end

  self:RefreshAppearance()
end

function DamageMeters:RefreshWindowsForMeterType(meterType, sessionID)
  if not self.runtimeEnabled or not self.runtimeVisible then
    return
  end

  local sessionCache = AcquireRefreshSessionCache()
  for index = 1, self.runtimeWindowCount do
    local window = self.windows[index]
    if window and window.frame:IsShown() then
      local windowRuntime = window.runtime
      if METER_TYPES[windowRuntime.meter] == meterType
        and DoesWindowSessionMatchEvent(windowRuntime, sessionID)
      then
        if window.navigationMode then
          RefreshWindow(window, nil, windowRuntime)
        else
          RefreshWindow(
            window,
            GetRefreshSession(sessionCache, windowRuntime, windowRuntime.meter),
            windowRuntime
          )
        end
      end
    end
  end
  ReleaseRefreshSessionCache(sessionCache)

  local selection = self.breakdownSelection
  if selection then
    local ownerRuntime = selection.ownerWindow.runtime
    local selectionMeterType = METER_TYPES[selection.meterKey]
    local targetAnalysisUpdated = meterType == METER_TYPES.ENEMY_DAMAGE_TAKEN
      and (selection.meterKey == "DAMAGE_DONE" or selection.meterKey == "DPS")
    local targetAnalysisSelection = selection.mode == "SPELLS"
      and (selection.meterKey == "DAMAGE_DONE" or selection.meterKey == "DPS")

    if DoesWindowSessionMatchEvent(ownerRuntime, sessionID) then
      if targetAnalysisSelection and (selectionMeterType == meterType or targetAnalysisUpdated) then
        self:ScheduleTargetAnalysisRefresh()
      elseif selectionMeterType == meterType then
        Breakdown.Refresh()
      end
    end
  end
end

function DamageMeters:MarkWindowsDirtyForMeterEvent(meterType, sessionID)
  local marked = false
  local meterWindows = self.combatEventWindowsByMeterType
    and self.combatEventWindowsByMeterType[meterType]

  if meterWindows then
    for index = 1, #meterWindows do
      local window = meterWindows[index]
      if not window.needsCombatRefresh
        and window.frame:IsShown()
        and not window.navigationMode
        and DoesWindowSessionMatchEvent(window.runtime, sessionID)
      then
        window.needsCombatRefresh = true
        marked = true
      end
    end
  end

  local selection = self.breakdownSelection
  if selection and not self.breakdownNeedsCombatRefresh then
    local ownerRuntime = selection.ownerWindow.runtime
    if METER_TYPES[selection.meterKey] == meterType
      and DoesWindowSessionMatchEvent(ownerRuntime, sessionID)
    then
      self.breakdownNeedsCombatRefresh = true
      marked = true
    end
  end

  return marked
end

function DamageMeters:MarkCurrentWindowsDirty()
  local marked = false

  for index = 1, self.runtimeWindowCount do
    local window = self.windows[index]
    if window
      and not window.needsCombatRefresh
      and window.frame:IsShown()
      and not window.navigationMode
    then
      local windowRuntime = window.runtime
      if GetWindowSelection(windowRuntime) == nil and windowRuntime.session == "CURRENT" then
        window.needsCombatRefresh = true
        marked = true
      end
    end
  end

  local selection = self.breakdownSelection
  if selection
    and not self.breakdownNeedsCombatRefresh
    and selection.sessionID == nil
    and selection.sessionKey == "CURRENT"
  then
    self.breakdownNeedsCombatRefresh = true
    marked = true
  end

  return marked
end

function DamageMeters:RefreshCombatWindowSlot(window)
  if not self.runtimeEnabled or not self.runtimeVisible or not window then
    return
  end

  if window.needsCombatRefresh then
    window.needsCombatRefresh = nil
    if window.frame:IsShown() and not window.navigationMode then
      local windowRuntime = window.runtime
      local session = GetCombatSession(windowRuntime, windowRuntime.meter)
        or NO_COMBAT_SESSION
      RefreshWindow(window, session, windowRuntime)
    end
  end

  if self.breakdownNeedsCombatRefresh then
    local selection = self.breakdownSelection
    if not selection then
      self.breakdownNeedsCombatRefresh = nil
    elseif selection.ownerWindow == window then
      self.breakdownNeedsCombatRefresh = nil
      Breakdown.Refresh()
    end
  end
end

function DamageMeters:RefreshDirtyWindows()
  if not self.runtimeEnabled or not self.runtimeVisible then
    return
  end

  local sessionCache = AcquireRefreshSessionCache()
  for index = 1, self.runtimeWindowCount do
    local window = self.windows[index]
    if window and window.needsCombatRefresh then
      window.needsCombatRefresh = nil
      if window.frame:IsShown() then
        local windowRuntime = window.runtime
        RefreshWindow(
          window,
          GetRefreshSession(sessionCache, windowRuntime, windowRuntime.meter),
          windowRuntime
        )
      end
    end
  end
  ReleaseRefreshSessionCache(sessionCache)

  if self.breakdownNeedsCombatRefresh then
    self.breakdownNeedsCombatRefresh = nil
    Breakdown.Refresh()
  end
end

function DamageMeters:RefreshSelectionWindows()
  if not self.runtimeEnabled or not self.runtimeVisible then
    return
  end

  for index = 1, self.runtimeWindowCount do
    local window = self.windows[index]
    if window and window.needsSelectionRefresh then
      window.needsSelectionRefresh = nil
      if window.frame:IsShown() then
        RefreshWindow(window, nil, window.runtime)
      end
    end
  end
end

function DamageMeters:ResetWindowPosition(index)
  if not self.windows or not self.windows[index] then
    return
  end
  ResetWindowPosition(self.windows[index])
end

function DamageMeters:HasShownWindow()
  local db = self.db.profile

  for index = 1, db.windowCount do
    if GetWindowDB(index).shown then
      return true
    end
  end

  return false
end

function DamageMeters:SetWindowsVisible(visible)
  local db = self.db.profile
  visible = visible == true

  if visible then
    if db.enabled == false then
      Addon:Print("Damage Meters are disabled. Use /dmg enable or the launcher menu to enable them.")
      return
    end

    if db.windowCount == 0 then
      db.windowCount = 1
      GetWindowDB(1).shown = true
    elseif not self:HasShownWindow() then
      GetWindowDB(1).shown = true
    end

    db.visible = true
    self:ApplySettings()
    return
  end

  db.visible = false
  self.runtimeVisible = false
  self:CancelCombatRefresh()
  self:CancelTargetAnalysisRefresh()
  self:UnregisterWindowMovers()

  Breakdown.Close()
  SegmentPicker.Hide()

  if self.windows then
    for index = 1, MAX_WINDOWS do
      local window = self.windows[index]
      if window then
        window.dragState = nil
        window.resizeState = nil
        window.dragDriver:Hide()
        window.resizeDriver:Hide()
        window.frame:Hide()
      end
    end
  end
end

function DamageMeters:ToggleWindows()
  local db = self.db.profile
  if db.enabled == false then
    Addon:Print("Damage Meters are disabled. Use /dmg enable or the launcher menu to enable them.")
    return
  end

  self:SetWindowsVisible(db.visible == false or not self:HasShownWindow())
end

function DamageMeters:ReopenWindow(index)
  local db = self.db.profile
  if db.enabled == false then
    Addon:Print("Damage Meters are disabled. Enable them before reopening a window.")
    return
  end
  if index < 1 or index > db.windowCount then
    return
  end

  local windowDB = GetWindowDB(index)
  if windowDB.shown then
    return
  end

  windowDB.shown = true
  db.visible = true
  self:ApplySettings()
end

function DamageMeters:AddWindow()
  local db = self.db.profile
  if db.enabled == false then
    Addon:Print("Damage Meters are disabled. Enable them before creating a window.")
    return
  end

  if db.windowCount >= MAX_WINDOWS then
    Addon:Print("Damage Meters supports up to " .. MAX_WINDOWS .. " windows.")
    return
  end

  db.windowCount = db.windowCount + 1
  GetWindowDB(db.windowCount).shown = true
  db.visible = true
  self:ApplySettings()
  Addon:NotifyOptionsTreeChanged("DamageMeters")
end

function DamageMeters:CloseWindow(index)
  local db = self.db.profile
  if index < 1 or index > db.windowCount then
    return
  end

  GetWindowDB(index).shown = false
  SegmentPicker.Hide()

  if not self:HasShownWindow() then
    self:SetWindowsVisible(false)
    return
  end

  self:ApplyWindowConfiguration()
end

function DamageMeters:DeleteWindow(index)
  local db = self.db.profile
  if index < 1 or index > db.windowCount then
    return
  end

  for moverIndex = 1, MAX_WINDOWS do
    FrameUtil.ClearSmartSnapForKey(MOVER_PREFIX .. moverIndex)
  end

  Breakdown.Close()
  SegmentPicker.Hide()

  for windowIndex = index, db.windowCount - 1 do
    db.windows[windowIndex] = db.windows[windowIndex + 1]
    if self.windowSelections then
      self.windowSelections[windowIndex] = self.windowSelections[windowIndex + 1]
    end
    if self.windows and self.windows[windowIndex] then
      local window = self.windows[windowIndex]
      window.firstSource = 1
      window.navigationMode = false
      if window.meterNavigation then
        window.meterNavigation:Hide()
      end
    end
  end

  db.windows[db.windowCount] = nil
  if self.windowSelections then
    self.windowSelections[db.windowCount] = nil
  end
  db.windowCount = db.windowCount - 1

  if db.windowCount == 0 then
    db.visible = false
  elseif not self:HasShownWindow() then
    db.visible = false
  end

  self:ApplySettings()
  Addon:NotifyOptionsTreeChanged("DamageMeters")
end

function DamageMeters:CloseLastWindow()
  local db = self.db.profile

  for index = db.windowCount, 1, -1 do
    if GetWindowDB(index).shown then
      self:CloseWindow(index)
      return
    end
  end
end

SetHeaderButtonTooltip = P:Def("SetHeaderButtonTooltip", SetHeaderButtonTooltip)
ShowHeaderButtonTooltip = P:Def("ShowHeaderButtonTooltip", ShowHeaderButtonTooltip)
RefreshHeaderButtonTooltip = P:Def("RefreshHeaderButtonTooltip", RefreshHeaderButtonTooltip)
HideHeaderButtonTooltip = P:Def("HideHeaderButtonTooltip", HideHeaderButtonTooltip)
CreateHeaderButton = P:Def("CreateHeaderButton", CreateHeaderButton)
CreateAtlasButton = P:Def("CreateAtlasButton", CreateAtlasButton)
CreateTextureButton = P:Def("CreateTextureButton", CreateTextureButton)
ShowMeterRowTooltip = P:Def("ShowMeterRowTooltip", ShowMeterRowTooltip)
EnsureWindowRows = P:Def("EnsureWindowRows", EnsureWindowRows)
ApplyWindowPosition = P:Def("ApplyWindowPosition", ApplyWindowPosition)
SaveWindowPosition = P:Def("SaveWindowPosition", SaveWindowPosition)
ResetWindowPosition = P:Def("ResetWindowPosition", ResetWindowPosition)
GetWindowRect = P:Def("GetWindowRect", GetWindowRect)
PlaceWindowFromLeftTop = P:Def("PlaceWindowFromLeftTop", PlaceWindowFromLeftTop)
StartWindowDrag = P:Def("StartWindowDrag", StartWindowDrag)
UpdateWindowDrag = P:Def("UpdateWindowDrag", UpdateWindowDrag)
StopWindowDrag = P:Def("StopWindowDrag", StopWindowDrag)
StartWindowResize = P:Def("StartWindowResize", StartWindowResize)
UpdateWindowResize = P:Def("UpdateWindowResize", UpdateWindowResize)
StopWindowResize = P:Def("StopWindowResize", StopWindowResize)
UpdateLockButton = P:Def("UpdateLockButton", UpdateLockButton)
CompileWindowRuntime = P:Def("CompileWindowRuntime", CompileWindowRuntime)
UpdateHeaderText = P:Def("UpdateHeaderText", UpdateHeaderText)
ApplyWindowStyle = P:Def("ApplyWindowStyle", ApplyWindowStyle)
ApplyWindowLayout = P:Def("ApplyWindowLayout", ApplyWindowLayout)
GetVisibleRowCount = P:Def("GetVisibleRowCount", GetVisibleRowCount)
ConfigureWindowRowDisplay = P:Def("ConfigureWindowRowDisplay", ConfigureWindowRowDisplay)
SetAbbreviatedRowValue = P:Def("SetAbbreviatedRowValue", SetAbbreviatedRowValue)
SetDeathTimeRowValue = P:Def("SetDeathTimeRowValue", SetDeathTimeRowValue)
SetRowSource = P:Def("SetRowSource", SetRowSource)
HideWindowRowsFrom = P:Def("HideWindowRowsFrom", HideWindowRowsFrom)
RefreshWindow = P:Def("RefreshWindow", RefreshWindow)
UpdateBreakdownForWindow = P:Def("UpdateBreakdownForWindow", UpdateBreakdownForWindow)
SetWindowNavigationMode = P:Def("SetWindowNavigationMode", SetWindowNavigationMode)
ShowMeterNavigation = P:Def("ShowMeterNavigation", ShowMeterNavigation)
SelectWindowMeter = P:Def("SelectWindowMeter", SelectWindowMeter)
SelectWindowSession = P:Def("SelectWindowSession", SelectWindowSession)
SelectWindowRecord = P:Def("SelectWindowRecord", SelectWindowRecord)
CreateDamageMeterWindow = P:Def("CreateDamageMeterWindow", CreateDamageMeterWindow)
DoesWindowSessionMatchEvent = P:Def("DoesWindowSessionMatchEvent", DoesWindowSessionMatchEvent)

DamageMeters.CaptureWindowResizeState = P:Def("DamageMeters.CaptureWindowResizeState", DamageMeters.CaptureWindowResizeState)
DamageMeters.ApplySnappedWindowResize = P:Def("DamageMeters.ApplySnappedWindowResize", DamageMeters.ApplySnappedWindowResize)
DamageMeters.CommitWindowResize = P:Def("DamageMeters.CommitWindowResize", DamageMeters.CommitWindowResize)
DamageMeters.ResizeWindow = P:Def("DamageMeters.ResizeWindow", DamageMeters.ResizeWindow)
DamageMeters.EnsureWindows = P:Def("DamageMeters.EnsureWindows", DamageMeters.EnsureWindows)
DamageMeters.CompileCombatEventWindows = P:Def("DamageMeters.CompileCombatEventWindows", DamageMeters.CompileCombatEventWindows)
DamageMeters.CompileCombatRefreshWindows = P:Def("DamageMeters.CompileCombatRefreshWindows", DamageMeters.CompileCombatRefreshWindows)
DamageMeters.ApplyWindowConfiguration = P:Def("DamageMeters.ApplyWindowConfiguration", DamageMeters.ApplyWindowConfiguration)
DamageMeters.RefreshWindowAppearance = P:Def("DamageMeters.RefreshWindowAppearance", DamageMeters.RefreshWindowAppearance)
DamageMeters.RefreshAppearance = P:Def("DamageMeters.RefreshAppearance", DamageMeters.RefreshAppearance)
DamageMeters.RefreshBreakdownAppearance = P:Def("DamageMeters.RefreshBreakdownAppearance", DamageMeters.RefreshBreakdownAppearance)
DamageMeters.RefreshBreakdownData = P:Def("DamageMeters.RefreshBreakdownData", DamageMeters.RefreshBreakdownData)
DamageMeters.RefreshWindows = P:Def("DamageMeters.RefreshWindows", DamageMeters.RefreshWindows)
DamageMeters.RefreshTheme = P:Def("DamageMeters.RefreshTheme", DamageMeters.RefreshTheme)
DamageMeters.RefreshWindowsForMeterType = P:Def("DamageMeters.RefreshWindowsForMeterType", DamageMeters.RefreshWindowsForMeterType)
DamageMeters.MarkWindowsDirtyForMeterEvent = P:Def("DamageMeters.MarkWindowsDirtyForMeterEvent", DamageMeters.MarkWindowsDirtyForMeterEvent)
DamageMeters.MarkCurrentWindowsDirty = P:Def("DamageMeters.MarkCurrentWindowsDirty", DamageMeters.MarkCurrentWindowsDirty)
DamageMeters.RefreshCombatWindowSlot = P:Def("DamageMeters.RefreshCombatWindowSlot", DamageMeters.RefreshCombatWindowSlot)
DamageMeters.RefreshDirtyWindows = P:Def("DamageMeters.RefreshDirtyWindows", DamageMeters.RefreshDirtyWindows)
DamageMeters.RefreshSelectionWindows = P:Def("DamageMeters.RefreshSelectionWindows", DamageMeters.RefreshSelectionWindows)
DamageMeters.ResetWindowPosition = P:Def("DamageMeters.ResetWindowPosition", DamageMeters.ResetWindowPosition)
DamageMeters.HasShownWindow = P:Def("DamageMeters.HasShownWindow", DamageMeters.HasShownWindow)
DamageMeters.SetWindowsVisible = P:Def("DamageMeters.SetWindowsVisible", DamageMeters.SetWindowsVisible)
DamageMeters.ToggleWindows = P:Def("DamageMeters.ToggleWindows", DamageMeters.ToggleWindows)
DamageMeters.AddWindow = P:Def("DamageMeters.AddWindow", DamageMeters.AddWindow)
DamageMeters.ReopenWindow = P:Def("DamageMeters.ReopenWindow", DamageMeters.ReopenWindow)
DamageMeters.CloseWindow = P:Def("DamageMeters.CloseWindow", DamageMeters.CloseWindow)
DamageMeters.DeleteWindow = P:Def("DamageMeters.DeleteWindow", DamageMeters.DeleteWindow)
DamageMeters.CloseLastWindow = P:Def("DamageMeters.CloseLastWindow", DamageMeters.CloseLastWindow)

Windows.CreateTextureButton = CreateTextureButton
Windows.SetHeaderButtonTooltip = SetHeaderButtonTooltip
Windows.ResetWindowPosition = ResetWindowPosition
Windows.UpdateHeaderText = UpdateHeaderText
Windows.RefreshWindow = RefreshWindow
Windows.SetWindowNavigationMode = SetWindowNavigationMode
Windows.ShowMeterNavigation = ShowMeterNavigation
Windows.SelectWindowMeter = SelectWindowMeter
Windows.SelectWindowSession = SelectWindowSession
Windows.SelectWindowRecord = SelectWindowRecord
Windows.RANK_TEXT = RANK_TEXT
