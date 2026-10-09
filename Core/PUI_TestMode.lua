local _, ns = ...

local Addon = ns.Addon
local TestMode = ns.TestMode or {}
ns.TestMode = TestMode

local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local UIParent = _G.UIParent
local ipairs = _G.ipairs
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local pairs = _G.pairs
local next = _G.next
local sort = _G.table.sort
local tostring = _G.tostring
local type = _G.type

local TOOLBAR_WIDTH = 420
local TOOLBAR_PADDING = 12
local TOOLBAR_TITLE_HEIGHT = 160
local TOOLBAR_COLLAPSED_HEIGHT = 38
local SECTION_GAP = 10
local TOGGLE_WIDTH = 72
local TOGGLE_HEIGHT = 23
local TOGGLE_GAP = 6
local RANGE_HEIGHT = 34
local WHITE8 = "Interface\\Buttons\\WHITE8x8"

TestMode.participants = TestMode.participants or ns.Registry.TestModeParticipants
TestMode.controls = TestMode.controls or ns.Registry.TestModeControls
TestMode.values = TestMode.values or {}
TestMode.participantState = TestMode.participantState or {}
TestMode.active = TestMode.active == true
TestMode.pendingStop = TestMode.pendingStop == true
TestMode.toolbar = TestMode.toolbar or nil
if TestMode.toolbarCollapsed == nil then
  TestMode.toolbarCollapsed = false
end

local function SortedRecords(records)
  local output = {}

  for key, record in pairs(records) do
    output[#output + 1] = {
      key = key,
      record = record,
    }
  end

  sort(output, function(left, right)
    local leftOrder = tonumber(left.record.order) or 100
    local rightOrder = tonumber(right.record.order) or 100

    if leftOrder == rightOrder then
      return left.key < right.key
    end

    return leftOrder < rightOrder
  end)

  return output
end

local function BuildContext(participantKey, reason, changedKey)
  return {
    manager = TestMode,
    participantKey = participantKey,
    reason = reason,
    changedKey = changedKey,
    values = TestMode.values,
    GetValue = function(_, key)
      return TestMode:GetValue(key)
    end,
    SetValue = function(_, key, value)
      return TestMode:SetValue(key, value, "participant")
    end,
    IsActive = function()
      return TestMode:IsActive()
    end,
  }
end

local function IsParticipantAvailable(key, participant)
  if type(participant.IsAvailable) ~= "function" then
    return true
  end

  return participant:IsAvailable(BuildContext(key, "availability")) ~= false
end

local function RefreshToolbar()
  if TestMode.toolbar and TestMode.toolbar:IsShown() then
    TestMode:RebuildToolbar()
  end
end

function TestMode:RegisterParticipant(key, spec)
  if type(key) ~= "string" or key == "" or type(spec) ~= "table" then
    return nil
  end

  spec.key = key
  self.participants[key] = spec
  ns.Registry.TestModeParticipants[key] = spec

  local state = self.participantState[key]
  if not state then
    state = {
      enabled = spec.defaultEnabled ~= false,
      started = false,
    }
    self.participantState[key] = state
  end

  if self.active and state.enabled and IsParticipantAvailable(key, spec) then
    self:StartParticipant(key, "late-registration")
  end

  RefreshToolbar()
  return spec
end

function TestMode:UnregisterParticipant(key)
  local participant = self.participants[key]
  if not participant then
    return
  end

  self:StopParticipant(key, "unregister")
  self.participants[key] = nil
  ns.Registry.TestModeParticipants[key] = nil
  self.participantState[key] = nil
  RefreshToolbar()
end

function TestMode:RegisterControl(key, spec)
  if type(key) ~= "string" or key == "" or type(spec) ~= "table" then
    return nil
  end

  spec.key = key
  if spec.type == "range" then
    spec.type = "range"
  elseif spec.type == "choice" then
    spec.type = "choice"
  else
    spec.type = "toggle"
  end

  self.controls[key] = spec
  ns.Registry.TestModeControls[key] = spec

  if self.values[key] == nil then
    if spec.type == "range" then
      self.values[key] = tonumber(spec.default) or tonumber(spec.min) or 0
    elseif spec.type == "choice" then
      local firstChoice = type(spec.values) == "table" and spec.values[1] or nil
      self.values[key] = spec.default or (firstChoice and firstChoice.value)
    else
      self.values[key] = spec.default ~= false
    end
  end

  RefreshToolbar()
  return spec
end

function TestMode:GetValue(key)
  return self.values[key]
end

function TestMode:SetValue(key, value, reason)
  local control = self.controls[key]
  if not control then
    return false
  end

  if control.type == "range" then
    value = tonumber(value)
    if not value then
      return false
    end

    local minimum = tonumber(control.min) or 0
    local maximum = tonumber(control.max) or minimum
    local step = tonumber(control.step) or 1
    value = math_min(maximum, math_max(minimum, value))
    value = minimum + math_floor(((value - minimum) / step) + 0.5) * step
    value = math_min(maximum, math_max(minimum, value))
  elseif control.type == "choice" then
    local valid = false

    for _, choice in ipairs(control.values or {}) do
      if choice.value == value then
        valid = true
        break
      end
    end

    if not valid then
      return false
    end
  else
    value = value == true
  end

  if self.values[key] == value then
    return true
  end

  self.values[key] = value

  local participantKey = control.participant
  local participant = participantKey and self.participants[participantKey] or nil
  local context = BuildContext(participantKey, reason or "control", key)

  if type(control.OnChange) == "function" then
    control:OnChange(value, context)
  end

  if self.active and participant then
    self:Refresh(participantKey, reason or "control", key)
  end

  if reason ~= "toolbar" then
    RefreshToolbar()
  end
  return true
end

function TestMode:IsParticipantEnabled(key)
  local state = self.participantState[key]
  return state and state.enabled == true or false
end

function TestMode:SetParticipantEnabled(key, enabled)
  local participant = self.participants[key]
  local state = self.participantState[key]
  if not participant or not state then
    return false
  end

  enabled = enabled == true
  if state.enabled == enabled then
    return true
  end

  state.enabled = enabled

  local complete = true
  if self.active then
    if enabled then
      complete = self:StartParticipant(key, "participant-enabled")
      if not complete then
        state.enabled = false
      end
    else
      complete = self:StopParticipant(key, "participant-disabled")
    end
  end

  RefreshToolbar()
  return complete
end

function TestMode:StartParticipant(key, reason)
  local participant = self.participants[key]
  local state = self.participantState[key]
  if not participant or not state or state.started or not state.enabled then
    return true
  end

  if not IsParticipantAvailable(key, participant) then
    return false
  end

  local started = true
  if type(participant.Start) == "function" then
    started = participant:Start(BuildContext(key, reason or "start"))
  end

  if started == false then
    state.started = false
    return false
  end

  state.started = true
  return true
end

function TestMode:StopParticipant(key, reason)
  local participant = self.participants[key]
  local state = self.participantState[key]
  if not participant or not state or not state.started then
    return true
  end

  local stopped = true
  if type(participant.Stop) == "function" then
    stopped = participant:Stop(BuildContext(key, reason or "stop"))
  end

  if stopped == false then
    self.pendingStop = true
    return false
  end

  state.started = false
  return true
end

function TestMode:Refresh(key, reason, changedKey)
  if not self.active then
    return false
  end

  if key then
    local participant = self.participants[key]
    local state = self.participantState[key]
    if not participant or not state or not state.started then
      return false
    end

    if type(participant.Refresh) == "function" then
      return participant:Refresh(BuildContext(key, reason or "refresh", changedKey)) ~= false
    end

    return true
  end

  local complete = true

  for _, entry in ipairs(SortedRecords(self.participants)) do
    local state = self.participantState[entry.key]
    if state
      and state.started
      and not self:Refresh(entry.key, reason or "refresh-all", changedKey)
    then
      complete = false
    end
  end

  return complete
end

function TestMode:IsActive()
  return self.active == true
end

local function StopAllParticipants(reason)
  local complete = true
  local records = SortedRecords(TestMode.participants)

  for index = #records, 1, -1 do
    if not TestMode:StopParticipant(records[index].key, reason) then
      complete = false
    end
  end

  TestMode.pendingStop = not complete
  return complete
end

function TestMode:SetActive(enabled, reason)
  enabled = enabled == true

  if enabled and InCombatLockdown() then
    Addon:Print("Cannot enable test mode while in combat.")
    return false
  end

  if self.active == enabled and not (not enabled and self.pendingStop) then
    if enabled then
      self:ShowToolbar()
    end
    return true
  end

  if enabled then
    self.pendingStop = false
    self.active = true
    self:ShowToolbar()

    local started = true

    for _, entry in ipairs(SortedRecords(self.participants)) do
      local state = self.participantState[entry.key]
      if state
        and state.enabled
        and IsParticipantAvailable(entry.key, entry.record)
        and not self:StartParticipant(entry.key, reason or "enable")
      then
        started = false
      end
    end

    if not started then
      self.active = false
      self:HideToolbar()
      StopAllParticipants("startup-failed")
      Addon:Print("Test mode could not start.")
      return false
    end

    self:RebuildToolbar()
    Addon:Print("Test mode enabled.")
    return true
  end

  self.active = false
  self:HideToolbar()
  local complete = StopAllParticipants(reason or "disable")

  if complete then
    Addon:Print("Test mode disabled.")
  elseif reason ~= "combat" then
    Addon:Print("Test mode cleanup will finish after combat.")
  end

  return complete
end

local function StylePanel(panel)
  local Theme = ns.Theme
  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(panel, {
    bg = colors.background,
    border = colors.border,
  }, math_max(2, Theme.GetEdgeSize()))
end

local function StyleText(fontString, role, size)
  local Theme = ns.Theme
  Theme.ApplyFont(fontString, role or "body", size)
  local colors = Theme.GetColors()
  fontString:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4] or 1)
end

local function StyleButton(button, selected)
  local Theme = ns.Theme
  Theme:ApplyButton(button, selected and "primary" or "secondary")

  local colors = Theme.GetColors()
  local bg = colors.control
  local border = selected and colors.accent or colors.border
  Theme.SetSquareBackdrop(button, {
    bg = { bg[1], bg[2], bg[3], selected and 0.82 or 0.66 },
    border = { border[1], border[2], border[3], selected and 0.95 or 0.45 },
  }, math_max(2, Theme.GetEdgeSize()))
end

local function CreateToolbarButton(parent, text, width, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, TOGGLE_HEIGHT)
  button:SetText(text)
  button:SetScript("OnClick", onClick)
  return button
end

local function StyleRangeControl(row)
  local Theme = ns.Theme
  if not row then
    return
  end

  local colors = Theme.GetColors()
  StyleText(row.label, "body", 11)
  StyleText(row.valueText, "body", 11)
  row.track:SetVertexColor(colors.border[1], colors.border[2], colors.border[3], 0.8)
  row.thumb:SetVertexColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
end

local function CreateRangeControl(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(RANGE_HEIGHT)

  local label = row:CreateFontString(nil, "OVERLAY")
  label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  StyleText(label, "body", 11)
  row.label = label

  local valueText = row:CreateFontString(nil, "OVERLAY")
  valueText:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
  StyleText(valueText, "body", 11)
  row.valueText = valueText

  local slider = CreateFrame("Slider", nil, row)
  slider:SetOrientation("HORIZONTAL")
  slider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 1)
  slider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 1)
  slider:SetHeight(16)
  slider:SetObeyStepOnDrag(true)

  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetTexture(WHITE8)
  track:SetPoint("LEFT", slider, "LEFT", 0, 0)
  track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
  track:SetHeight(4)

  local thumb = slider:CreateTexture(nil, "ARTWORK")
  thumb:SetTexture(WHITE8)
  thumb:SetSize(10, 16)
  slider:SetThumbTexture(thumb)

  row.track = track
  row.thumb = thumb
  StyleRangeControl(row)

  slider:SetScript("OnValueChanged", function(self, newValue)
    if self.__puiSettingUp then
      return
    end

    local control = self.__puiControl
    if not control then
      return
    end

    local minimum = tonumber(control.min) or 0
    local step = tonumber(control.step) or 1
    newValue = minimum + math_floor(((newValue - minimum) / step) + 0.5) * step
    row.valueText:SetText(tostring(newValue))
    TestMode:SetValue(control.key, newValue, "toolbar")
  end)

  slider:EnableMouseWheel(true)
  slider:SetScript("OnMouseWheel", function(self, delta)
    local control = self.__puiControl
    if not control then
      return
    end

    local step = tonumber(control.step) or 1
    self:SetValue(self:GetValue() + (delta > 0 and step or -step))
  end)

  row.slider = slider
  row:Hide()
  return row
end

local function ConfigureRangeControl(row, control, value, yOffset)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", TOOLBAR_PADDING, yOffset)
  row:SetPoint("TOPRIGHT", row:GetParent(), "TOPRIGHT", -TOOLBAR_PADDING, yOffset)
  row.label:SetText(control.label or control.key)
  row.valueText:SetText(tostring(value))

  local slider = row.slider
  slider.__puiSettingUp = true
  slider.__puiControl = control
  slider:SetMinMaxValues(tonumber(control.min) or 0, tonumber(control.max) or 100)
  slider:SetValueStep(tonumber(control.step) or 1)
  slider:SetValue(value)
  slider.__puiSettingUp = nil
  StyleRangeControl(row)
  row:Show()
end

local function CreateChoiceControl(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(TOGGLE_HEIGHT)
  row.buttons = {}

  local label = row:CreateFontString(nil, "OVERLAY")
  label:SetPoint("LEFT", row, "LEFT", 0, 0)
  label:SetWidth(74)
  label:SetJustifyH("RIGHT")
  StyleText(label, "body", 11)
  row.label = label

  row:Hide()
  return row
end

local function AcquireChoiceButton(row, index)
  local button = row.buttons[index]
  if button then
    return button
  end

  button = CreateToolbarButton(row, "", TOGGLE_WIDTH, function(self)
    local control = self.__puiControl
    if not control then
      return
    end

    TestMode:SetValue(control.key, self.__puiChoiceValue, "toolbar")
    TestMode:RebuildToolbar()
  end)
  row.buttons[index] = button
  return button
end

local function ConfigureChoiceControl(row, control, value, yOffset)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", TOOLBAR_PADDING, yOffset)
  row:SetPoint("TOPRIGHT", row:GetParent(), "TOPRIGHT", -TOOLBAR_PADDING, yOffset)
  row.label:SetText(control.label or control.key)

  for _, button in ipairs(row.buttons) do
    button:Hide()
    button:ClearAllPoints()
  end

  local choices = control.values or {}
  local rowsUsed = math_max(1, math_floor((#choices + 2) / 3))
  local rowHeight = rowsUsed * (TOGGLE_HEIGHT + TOGGLE_GAP) - TOGGLE_GAP
  row:SetHeight(rowHeight)
  for index, choice in ipairs(choices) do
    local button = AcquireChoiceButton(row, index)
    button.__puiControl = control
    button.__puiChoiceValue = choice.value
    button:SetText(choice.label or tostring(choice.value))
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", row, "TOPLEFT",
      82 + ((index - 1) % 3) * (TOGGLE_WIDTH + TOGGLE_GAP),
      -math_floor((index - 1) / 3) * (TOGGLE_HEIGHT + TOGGLE_GAP))
    StyleButton(button, value == choice.value)
    button:Show()
  end

  row:Show()
  return rowHeight
end

local function CreateToolbarSection(parent)
  local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  section.toggleButtons = {}
  section.choiceRows = {}
  section.rangeRows = {}

  local heading = section:CreateFontString(nil, "OVERLAY")
  heading:SetPoint("TOPLEFT", section, "TOPLEFT", 8, -7)
  StyleText(heading, "header", 12)
  section.heading = heading

  local enabledButton = CreateToolbarButton(section, "Enabled", 78, function(self)
    local participantKey = self.__puiParticipantKey
    if participantKey then
      TestMode:SetParticipantEnabled(participantKey, not TestMode:IsParticipantEnabled(participantKey))
    end
  end)
  enabledButton:SetPoint("TOPRIGHT", section, "TOPRIGHT", -7, -5)
  section.enabledButton = enabledButton

  return section
end

local function AcquireToggleButton(section, index)
  local button = section.toggleButtons[index]
  if button then
    return button
  end

  button = CreateToolbarButton(section, "", TOGGLE_WIDTH, function(self)
    local control = self.__puiControl
    if not control then
      return
    end

    TestMode:SetValue(
      control.key,
      not (TestMode:GetValue(control.key) == true),
      "toolbar"
    )
    TestMode:RebuildToolbar()
  end)
  section.toggleButtons[index] = button
  return button
end

local function AcquireChoiceControl(section, index)
  local row = section.choiceRows[index]
  if not row then
    row = CreateChoiceControl(section)
    section.choiceRows[index] = row
  end
  return row
end

local function AcquireRangeControl(section, index)
  local row = section.rangeRows[index]
  if not row then
    row = CreateRangeControl(section)
    section.rangeRows[index] = row
  end
  return row
end

local function StyleVisibilityCheckbox(check, state)
  local colors = ns.Theme.GetColors()
  ns.Theme.SetSquareBackdrop(check, {
    bg = colors.control,
    border = colors.border,
  }, math_max(1, ns.Theme.GetEdgeSize()))
  check:SetChecked(state == "on")
  ns.Theme.ApplyFont(check.indicator, "body", 13)
  check.indicator:SetText(state == "mixed" and "-" or "X")
  check.indicator:SetShown(state ~= "off")
  check.indicator:SetTextColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
end

local function CreateVisibilityCheckbox(parent, onClick)
  local check = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
  check:SetSize(20, 20)
  check.indicator = check:CreateFontString(nil, "OVERLAY")
  check.indicator:SetPoint("CENTER")
  check:SetScript("OnClick", onClick)
  return check
end

function TestMode:QueueToolbarRefresh()
  if self.toolbarRefreshPending then
    return
  end
  self.toolbarRefreshPending = true
  _G.C_Timer.After(0, function()
    self.toolbarRefreshPending = nil
    if self.toolbar and self.toolbar:IsShown() then
      self:RebuildToolbar()
    end
  end)
end

function TestMode:EnsureToolbar()
  if self.toolbar then
    return self.toolbar
  end

  local panel = CreateFrame("Frame", "PleebUI_TestModeToolbar", UIParent, "BackdropTemplate")
  panel:SetSize(TOOLBAR_WIDTH, 520)
  panel:SetPoint("TOP", UIParent, "TOP", 0, -55)
  panel:SetFrameStrata("DIALOG")
  panel:SetFrameLevel(180)
  panel:SetClampedToScreen(true)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then
      self:StartMoving()
    end
  end)
  panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)

  local title = panel:CreateFontString(nil, "OVERLAY")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", TOOLBAR_PADDING, -10)
  StyleText(title, "header", 14)
  title:SetText("PleebUI Edit Mode")
  panel.title = title

  local exit = CreateToolbarButton(panel, "Exit", 62, function()
    Addon:SetEditMode(false)
  end)
  exit:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -TOOLBAR_PADDING, -7)
  StyleButton(exit, false)
  panel.exitButton = exit

  local minimize = CreateToolbarButton(panel, "", 28, function()
    TestMode.toolbarCollapsed = not TestMode.toolbarCollapsed
    TestMode:RebuildToolbar()
  end)
  minimize:SetPoint("RIGHT", exit, "LEFT", -6, 0)
  StyleButton(minimize, false)
  ns.Theme.ApplyExpandCollapseButton(minimize, not TestMode.toolbarCollapsed)
  panel.minimizeButton = minimize

  local visibility = ns.FrameUtil.GetMoverVisibilityConfig()
  panel.setLabel = panel:CreateFontString(nil, "OVERLAY")
  panel.setLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", TOOLBAR_PADDING, -38)
  StyleText(panel.setLabel, "body", 11)
  panel.setButtons = {}
  local previous
  for _, setName in ipairs(ns.FrameUtil.GetMoverVisibilitySetNames()) do
    local button = CreateToolbarButton(panel, setName, 91, function()
      ns.FrameUtil.SelectMoverVisibilitySet(setName)
      TestMode:RebuildToolbar()
    end)
    button:SetPoint("TOPLEFT", previous or panel, previous and "TOPRIGHT" or "TOPLEFT", previous and 6 or TOOLBAR_PADDING, previous and 0 or -61)
    panel.setButtons[setName] = button
    previous = button
  end

  panel.followCheck = CreateVisibilityCheckbox(panel, function(self)
    ns.FrameUtil.GetMoverVisibilityConfig().followGroup = self:GetChecked() == true
    StyleVisibilityCheckbox(self, self:GetChecked() and "on" or "off")
  end)
  panel.followCheck:SetPoint("TOPLEFT", panel, "TOPLEFT", TOOLBAR_PADDING, -99)
  StyleVisibilityCheckbox(panel.followCheck, visibility.followGroup and "on" or "off")

  panel.followLabel = panel:CreateFontString(nil, "OVERLAY")
  panel.followLabel:SetPoint("LEFT", panel.followCheck, "RIGHT", 3, 0)
  StyleText(panel.followLabel, "body", 11)
  panel.followLabel:SetText("Follow current group on open")
  panel.followLabel:SetWidth(180)
  panel.followLabel:SetJustifyH("LEFT")

  panel.resetButton = CreateToolbarButton(panel, "Reset preset", 112, function()
    ns.FrameUtil.ResetMoverVisibilitySet()
    TestMode:RebuildToolbar()
  end)
  panel.resetButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -TOOLBAR_PADDING, -96)

  panel.search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  panel.search:SetAutoFocus(false)
  panel.search:SetHeight(24)
  panel.search:SetPoint("TOPLEFT", panel, "TOPLEFT", TOOLBAR_PADDING + 6, -132)
  panel.search:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -TOOLBAR_PADDING - 6, -132)
  panel.searchHint = panel.search:CreateFontString(nil, "OVERLAY")
  panel.searchHint:SetPoint("LEFT", panel.search, "LEFT", 5, 0)
  StyleText(panel.searchHint, "body", 11)
  panel.searchHint:SetText("Search movers...")
  panel.search:SetScript("OnTextChanged", function(self)
    panel.searchCollapsed = {}
    panel.searchHint:SetShown(self:GetText() == "")
    TestMode:RebuildToolbar()
  end)
  panel.search:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  panel.scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -TOOLBAR_TITLE_HEIGHT)
  panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -27, 8)
  ns.Theme.WidgetSkins.Scrollbar(panel.scroll.ScrollBar)

  panel.content = CreateFrame("Frame", nil, panel.scroll)
  panel.content:SetWidth(TOOLBAR_WIDTH - 30)
  panel.content:SetHeight(100)
  panel.scroll:SetScrollChild(panel.content)

  panel.moverRows = {}
  panel.searchCollapsed = {}
  panel.__puiSections = {}
  panel:Hide()
  self.toolbar = panel
  StylePanel(panel)
  return panel
end

local function HideToolbarSections(panel)
  for _, section in ipairs(panel.__puiSections or {}) do
    section:Hide()
    section:ClearAllPoints()

    for _, button in ipairs(section.toggleButtons or {}) do
      button:Hide()
      button:ClearAllPoints()
    end

    for _, row in ipairs(section.choiceRows or {}) do
      row:Hide()
      row:ClearAllPoints()

      for _, button in ipairs(row.buttons or {}) do
        button:Hide()
        button:ClearAllPoints()
      end
    end

    for _, row in ipairs(section.rangeRows or {}) do
      row:Hide()
      row:ClearAllPoints()
    end
  end
end

local function ControlVisible(control, participantKey)
  if control.participant ~= participantKey then
    return false
  end

  if type(control.Visible) ~= "function" then
    return true
  end

  return control:Visible(BuildContext(participantKey, "toolbar")) ~= false
end

local function BuildMoverTree()
  local modules = {}
  local keyed = {}

  for _, entry in ipairs(ns.FrameUtil.GetRegisteredMoverEntries()) do
    local opts = entry.opts
    if opts.moduleKey then
      local module = keyed[opts.moduleKey]
      if not module then
        module = {
          key = opts.moduleKey,
          label = opts.moduleLabel or opts.moduleKey,
          groups = {},
          groupMap = {},
          movers = {},
          allMovers = {},
        }
        keyed[opts.moduleKey] = module
        modules[#modules + 1] = module
      end
      module.allMovers[#module.allMovers + 1] = entry

      if opts.groupKey then
        local group = module.groupMap[opts.groupKey]
        if not group then
          group = {
            key = opts.moduleKey .. ":" .. opts.groupKey,
            label = opts.groupLabel or opts.groupKey,
            movers = {},
          }
          module.groupMap[opts.groupKey] = group
          module.groups[#module.groups + 1] = group
        end
        group.movers[#group.movers + 1] = entry
      else
        module.movers[#module.movers + 1] = entry
      end
    end
  end

  local function ByLabel(first, second)
    if first.label == second.label then
      return first.key < second.key
    end
    return first.label < second.label
  end
  local function ByMoverLabel(first, second)
    if first.label == second.label then
      return first.key < second.key
    end
    return tostring(first.label) < tostring(second.label)
  end

  sort(modules, function(first, second)
    if first.key == "external" then return false end
    if second.key == "external" then return true end
    return ByLabel(first, second)
  end)
  for _, module in ipairs(modules) do
    sort(module.groups, ByLabel)
    sort(module.movers, ByMoverLabel)
    for _, group in ipairs(module.groups) do
      sort(group.movers, ByMoverLabel)
    end
  end
  return modules
end

local function AcquireMoverRow(panel, index)
  local row = panel.moverRows[index]
  if row then return row end

  row = CreateFrame("Frame", nil, panel.content)
  row:SetHeight(25)

  local expand = CreateToolbarButton(row, "+", 22, function(self)
    local config = ns.FrameUtil.GetMoverVisibilityConfig()
    local key = self.__puiExpansionKey
    if key == "previews" then
      config.previewsExpanded = not (config.previewsExpanded == true)
    else
      local searching = panel.search:GetText() ~= ""
      if searching then
        panel.searchCollapsed[key] = not panel.searchCollapsed[key]
      else
        config.expanded[key] = not (config.expanded[key] == true)
      end
    end
    TestMode:RebuildToolbar()
  end)
  row.expand = expand

  local check = CreateVisibilityCheckbox(row, function(self)
    ns.FrameUtil.SetMoverVisibilityNode(self.__puiKind, self.__puiKey, self.__puiState == "off")
    TestMode:RebuildToolbar()
  end)
  check:SetPoint("RIGHT", row, "RIGHT", -5, 0)
  row.check = check

  local label = row:CreateFontString(nil, "OVERLAY")
  label:SetJustifyH("LEFT")
  StyleText(label, "body", 12)
  row.label = label
  panel.moverRows[index] = row
  return row
end

local function MoverNodeState(kind, key, entries)
  if not ns.FrameUtil.GetMoverVisibilityNodeChoice(kind, key) then
    return "off"
  end
  local active = 0
  for _, entry in ipairs(entries) do
    if ns.FrameUtil.IsMoverVisibleInPreset(entry) then
      active = active + 1
    end
  end
  return active == #entries and "on" or "mixed"
end

local function ShowMoverRow(panel, index, y, kind, key, label, depth, state, expansionKey, expanded)
  local row = AcquireMoverRow(panel, index)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", TOOLBAR_PADDING + depth * 18, y)
  row:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", -TOOLBAR_PADDING, y)
  row.expand:ClearAllPoints()
  row.expand:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.expand.__puiExpansionKey = expansionKey
  row.expand:SetShown(expansionKey ~= nil)
  if expansionKey then
    row.expand:SetText(expanded and "-" or "+")
    StyleButton(row.expand, false)
  end
  if type(state) == "boolean" then
    state = state and "on" or "off"
  end
  row.check.__puiKind = kind
  row.check.__puiKey = key
  row.check.__puiState = state
  StyleVisibilityCheckbox(row.check, state)
  row.check:SetShown(kind ~= "preview")
  row.label:ClearAllPoints()
  row.label:SetPoint("LEFT", row, "LEFT", expansionKey and 27 or 8, 0)
  row.label:SetPoint("RIGHT", row.check, "LEFT", -5, 0)
  row.label:SetText(label)
  StyleText(row.label, depth == 0 and "header" or "body", 12)
  row:Show()
end

function TestMode:RebuildToolbar()
  local panel = self:EnsureToolbar()
  local content = panel.content
  local config = ns.FrameUtil.GetMoverVisibilityConfig()
  HideToolbarSections(panel)
  for _, row in ipairs(panel.moverRows) do row:Hide() end

  panel.setLabel:SetText("Editing: " .. config.selectedSet)
  panel.setLabel:SetShown(not self.toolbarCollapsed)
  for name, button in pairs(panel.setButtons) do
    StyleButton(button, name == config.selectedSet)
  end
  StyleVisibilityCheckbox(panel.followCheck, config.followGroup and "on" or "off")
  for _, button in pairs(panel.setButtons) do
    button:SetShown(not self.toolbarCollapsed)
  end
  panel.followCheck:SetShown(not self.toolbarCollapsed)
  panel.followLabel:SetShown(not self.toolbarCollapsed)
  panel.resetButton:SetShown(not self.toolbarCollapsed)
  panel.search:SetShown(not self.toolbarCollapsed)

  local search = (panel.search:GetText() or ""):lower()
  local function Matches(value)
    return search == "" or (tostring(value):lower():find(search, 1, true) ~= nil)
  end

  local y = -2
  local rowIndex = 0
  local function AddRow(kind, key, label, depth, state, expansionKey, expanded)
    rowIndex = rowIndex + 1
    ShowMoverRow(panel, rowIndex, y, kind, key, label, depth, state, expansionKey, expanded)
    y = y - 26
  end

  for _, module in ipairs(BuildMoverTree()) do
    local moduleMatch = Matches(module.label)
    local matching = {}
    for _, entry in ipairs(module.allMovers) do
      if moduleMatch or Matches(entry.label) then
        matching[entry] = true
      else
        for _, group in ipairs(module.groups) do
          if Matches(group.label) then
            for _, member in ipairs(group.movers) do matching[member] = true end
          end
        end
      end
    end
    if next(matching) then
      local moduleExpansion = "module:" .. module.key
      local moduleExpanded = (search ~= "" and not panel.searchCollapsed[moduleExpansion])
        or (search == "" and config.expanded[moduleExpansion] == true)
      AddRow("modules", module.key, module.label, 0,
        MoverNodeState("modules", module.key, module.allMovers), moduleExpansion, moduleExpanded)
      if moduleExpanded then
        for _, entry in ipairs(module.movers) do
          if matching[entry] then
            AddRow("movers", entry.key, entry.label, 1,
              ns.FrameUtil.GetMoverVisibilityChoice(entry), nil, false)
          end
        end
        for _, group in ipairs(module.groups) do
          local groupMembers = {}
          for _, entry in ipairs(group.movers) do
            if matching[entry] then groupMembers[#groupMembers + 1] = entry end
          end
          if #groupMembers > 0 then
            local groupExpansion = "group:" .. group.key
            local groupExpanded = (search ~= "" and not panel.searchCollapsed[groupExpansion])
              or (search == "" and config.expanded[groupExpansion] == true)
            AddRow("groups", group.key, group.label, 1,
              MoverNodeState("groups", group.key, group.movers), groupExpansion, groupExpanded)
            if groupExpanded then
              for _, entry in ipairs(groupMembers) do
                AddRow("movers", entry.key, entry.label, 2,
                  ns.FrameUtil.GetMoverVisibilityChoice(entry), nil, false)
              end
            end
          end
        end
      end
    end
  end

  y = y - SECTION_GAP
  local previewExpanded = config.previewsExpanded == true
  AddRow("preview", "previews", "Test previews", 0,
    "off", "previews", previewExpanded)
  y = y - 2

  local sectionIndex = 0
  if previewExpanded then
    for _, participantEntry in ipairs(SortedRecords(self.participants)) do
      local key = participantEntry.key
      local participant = participantEntry.record

      if IsParticipantAvailable(key, participant) then
        sectionIndex = sectionIndex + 1

        local section = panel.__puiSections[sectionIndex]
        if not section then
          section = CreateToolbarSection(content)
          panel.__puiSections[sectionIndex] = section
        end

        section:SetPoint("TOPLEFT", content, "TOPLEFT", TOOLBAR_PADDING, y)
        section:SetPoint("TOPRIGHT", content, "TOPRIGHT", -TOOLBAR_PADDING, y)
        section:SetHeight(70)
        section:Show()

        local Theme = ns.Theme
        local colors = Theme.GetColors()
        Theme.SetSquareBackdrop(section, {
          bg = colors.background,
          border = colors.border,
        }, math_max(1, Theme.GetEdgeSize()))

        section.heading:SetText(participant.label or key)

        local enabled = self:IsParticipantEnabled(key)
        section.enabledButton.__puiParticipantKey = key
        section.enabledButton:SetText(enabled and "Enabled" or "Disabled")
        StyleButton(section.enabledButton, enabled)

        local toggleControls = {}
        local choiceControls = {}
        local rangeControls = {}

        for _, controlEntry in ipairs(SortedRecords(self.controls)) do
          local control = controlEntry.record
          if ControlVisible(control, key) then
            if control.type == "range" then
              rangeControls[#rangeControls + 1] = control
            elseif control.type == "choice" then
              choiceControls[#choiceControls + 1] = control
            else
              toggleControls[#toggleControls + 1] = control
            end
          end
        end

        local toggleY = -32
        local toggleX = 8
        local usableWidth = content:GetWidth() - (TOOLBAR_PADDING * 2) - 16

        for index, control in ipairs(toggleControls) do
          if toggleX + TOGGLE_WIDTH > usableWidth then
            toggleX = 8
            toggleY = toggleY - (TOGGLE_HEIGHT + TOGGLE_GAP)
          end

          local button = AcquireToggleButton(section, index)
          button.__puiControl = control
          button:SetText(control.label or control.key)
          button:SetPoint("TOPLEFT", section, "TOPLEFT", toggleX, toggleY)
          StyleButton(button, self:GetValue(control.key) == true)
          button:Show()
          toggleX = toggleX + TOGGLE_WIDTH + TOGGLE_GAP
        end

        local rowsUsed = #toggleControls > 0
          and (math_floor((#toggleControls - 1) / math_max(1, math_floor((usableWidth - 8) / (TOGGLE_WIDTH + TOGGLE_GAP)))) + 1)
          or 0
        local sectionHeight = 31 + (rowsUsed * (TOGGLE_HEIGHT + TOGGLE_GAP))
        local controlY = -(sectionHeight + 2)

        for index, control in ipairs(choiceControls) do
          local rowHeight = ConfigureChoiceControl(
            AcquireChoiceControl(section, index),
            control,
            self:GetValue(control.key),
            controlY
          )
          controlY = controlY - (rowHeight + TOGGLE_GAP)
          sectionHeight = sectionHeight + rowHeight + TOGGLE_GAP
        end

        for index, control in ipairs(rangeControls) do
          ConfigureRangeControl(
            AcquireRangeControl(section, index),
            control,
            self:GetValue(control.key),
            controlY
          )
          controlY = controlY - RANGE_HEIGHT
          sectionHeight = sectionHeight + RANGE_HEIGHT
        end

        sectionHeight = math_max(58, sectionHeight + 8)
        section:SetHeight(sectionHeight)
        y = y - sectionHeight - SECTION_GAP
      end
    end

  end

  local contentHeight = math_max(60, -y + 2)
  content:SetHeight(contentHeight)
  local availableHeight = math_max(200, UIParent:GetHeight() - 110)
  panel:SetHeight(
    self.toolbarCollapsed
      and TOOLBAR_COLLAPSED_HEIGHT
      or math_min(availableHeight, math_max(350, TOOLBAR_TITLE_HEIGHT + contentHeight + TOOLBAR_PADDING))
  )
  panel.scroll:SetShown(not self.toolbarCollapsed)
  panel.scroll:SetVerticalScroll(math_min(panel.scroll:GetVerticalScroll(),
    math_max(0, contentHeight - (panel:GetHeight() - TOOLBAR_TITLE_HEIGHT - 8))))
  ns.Theme.ApplyExpandCollapseButton(panel.minimizeButton, not self.toolbarCollapsed)
  StylePanel(panel)
end

local function RefreshToolbarTheme()
  local panel = TestMode.toolbar
  if not panel then
    return
  end

  StylePanel(panel)
  StyleText(panel.title, "header", 14)
  StyleText(panel.setLabel, "body", 11)
  StyleText(panel.followLabel, "body", 11)
  StyleVisibilityCheckbox(panel.followCheck, ns.FrameUtil.GetMoverVisibilityConfig().followGroup and "on" or "off")
  ns.Theme.WidgetSkins.Scrollbar(panel.scroll.ScrollBar)
  StyleText(panel.searchHint, "body", 11)
  StyleButton(panel.resetButton, false)
  for name, button in pairs(panel.setButtons) do
    StyleButton(button, name == ns.FrameUtil.GetMoverVisibilityConfig().selectedSet)
  end
  for _, row in ipairs(panel.moverRows) do
    if row:IsShown() then
      StyleText(row.label, "body", 12)
      StyleVisibilityCheckbox(row.check, row.check.__puiState)
      StyleButton(row.expand, false)
    end
  end
  StyleButton(panel.exitButton, false)
  StyleButton(panel.minimizeButton, false)
  ns.Theme.ApplyExpandCollapseButton(panel.minimizeButton, not TestMode.toolbarCollapsed)

  for _, section in ipairs(panel.__puiSections or {}) do
    if section:IsShown() then
      StylePanel(section)
      StyleText(section.heading, "header", 12)

      local participantKey = section.enabledButton.__puiParticipantKey
      StyleButton(section.enabledButton, participantKey and TestMode:IsParticipantEnabled(participantKey))

      for _, button in ipairs(section.toggleButtons or {}) do
        if button:IsShown() then
          local control = button.__puiControl
          StyleButton(button, control and TestMode:GetValue(control.key) == true)
        end
      end

      for _, row in ipairs(section.choiceRows or {}) do
        if row:IsShown() then
          StyleText(row.label, "body", 11)

          for _, button in ipairs(row.buttons or {}) do
            if button:IsShown() then
              local control = button.__puiControl
              StyleButton(
                button,
                control and TestMode:GetValue(control.key) == button.__puiChoiceValue
              )
            end
          end
        end
      end

      for _, row in ipairs(section.rangeRows or {}) do
        if row:IsShown() then
          StyleRangeControl(row)
        end
      end
    end
  end
end

function TestMode:RefreshTheme()
  RefreshToolbarTheme()

  if self.active then
    self:Refresh(nil, "theme")
  end

  ns.FrameUtil.RefreshTheme()
  ns.EditModeQuickSettings:RefreshTheme()
end

function TestMode:ShowToolbar()
  local panel = self:EnsureToolbar()
  panel:Show()
  self:RebuildToolbar()
end

function TestMode:HideToolbar()
  if self.toolbar then
    self.toolbar:Hide()
  end
end

local eventFrame = TestMode.eventFrame or CreateFrame("Frame")
TestMode.eventFrame = eventFrame
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    if TestMode:IsActive() then
      TestMode:SetActive(false, "combat")
      Addon:Print("Test mode stopped for combat.")
    end
    return
  end

  if event == "PLAYER_REGEN_ENABLED" and TestMode.pendingStop then
    StopAllParticipants("post-combat-cleanup")
  end
end)

local P = select(1, ns.Pleebug:DropIn(TestMode, { name = "Core.TestMode" }))
TestMode.RegisterParticipant = P:Def("TestMode:RegisterParticipant", TestMode.RegisterParticipant)
TestMode.UnregisterParticipant = P:Def("TestMode:UnregisterParticipant", TestMode.UnregisterParticipant)
TestMode.RegisterControl = P:Def("TestMode:RegisterControl", TestMode.RegisterControl)
TestMode.GetValue = P:Def("TestMode:GetValue", TestMode.GetValue)
TestMode.SetValue = P:Def("TestMode:SetValue", TestMode.SetValue)
TestMode.IsParticipantEnabled = P:Def("TestMode:IsParticipantEnabled", TestMode.IsParticipantEnabled)
TestMode.SetParticipantEnabled = P:Def("TestMode:SetParticipantEnabled", TestMode.SetParticipantEnabled)
TestMode.StartParticipant = P:Def("TestMode:StartParticipant", TestMode.StartParticipant)
TestMode.StopParticipant = P:Def("TestMode:StopParticipant", TestMode.StopParticipant)
TestMode.Refresh = P:Def("TestMode:Refresh", TestMode.Refresh)
TestMode.IsActive = P:Def("TestMode:IsActive", TestMode.IsActive)
TestMode.SetActive = P:Def("TestMode:SetActive", TestMode.SetActive)
TestMode.EnsureToolbar = P:Def("TestMode:EnsureToolbar", TestMode.EnsureToolbar)
TestMode.RebuildToolbar = P:Def("TestMode:RebuildToolbar", TestMode.RebuildToolbar)
TestMode.QueueToolbarRefresh = P:Def("TestMode:QueueToolbarRefresh", TestMode.QueueToolbarRefresh)
TestMode.RefreshTheme = P:Def("TestMode:RefreshTheme", TestMode.RefreshTheme)
TestMode.ShowToolbar = P:Def("TestMode:ShowToolbar", TestMode.ShowToolbar)
TestMode.HideToolbar = P:Def("TestMode:HideToolbar", TestMode.HideToolbar)
