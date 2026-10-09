local _, ns = ...

local Addon = ns.Addon
local TestMode = ns.TestMode or {}
ns.TestMode = TestMode

local AceGUI = _G.LibStub("AceGUI-3.0")
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

local TOOLBAR_WIDTH = 390
local TOOLBAR_DEFAULT_HEIGHT = 650
local TOOLBAR_MIN_WIDTH = 360
local TOOLBAR_MIN_HEIGHT = 320
local TOOLBAR_PADDING = 12
local TOOLBAR_TITLE_HEIGHT = 40
local TOOLBAR_COLLAPSED_HEIGHT = 38
local SECTION_GAP = 10
local TOGGLE_WIDTH = 136
local TOGGLE_HEIGHT = 30
local TOGGLE_GAP = 6
local RANGE_HEIGHT = 66
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
  if participant.moverKey and not ns.FrameUtil.IsMoverPreviewVisible(participant.moverKey) then
    return true
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

local function CreateRangeControl(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(RANGE_HEIGHT)
  local widget = AceGUI:Create("PUI_Slider")
  ns.AceHooks.TakeOwnership(widget)
  widget.frame:SetParent(row)
  widget.frame:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  widget.frame:Show()
  widget:SetCallback("OnValueChanged", function(_, _, value)
    local control = row.control
    if control then
      TestMode:SetValue(control.key, value, "toolbar")
    end
  end)
  row.widget = widget
  row:Hide()
  return row
end

local function ConfigureRangeControl(row, control, value, yOffset)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", TOOLBAR_PADDING, yOffset)
  row:SetPoint("TOPRIGHT", row:GetParent(), "TOPRIGHT", -TOOLBAR_PADDING, yOffset)
  row.control = control
  row.widget:SetLabel(control.label or control.key)
  row.widget:SetSliderValues(tonumber(control.min) or 0, tonumber(control.max) or 100, tonumber(control.step) or 1)
  row.widget:SetValue(value)
  row.widget:SetWidth(math_max(160, row:GetParent():GetWidth() - TOOLBAR_PADDING * 2))
  row:Show()
end

local function CreateChoiceControl(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(58)
  local widget = AceGUI:Create("PUI_Dropdown")
  ns.AceHooks.TakeOwnership(widget)
  widget.frame:SetParent(row)
  widget.frame:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  widget.frame:Show()
  widget:SetCallback("OnValueChanged", function(_, _, value)
    local control = row.control
    if control then
      TestMode:SetValue(control.key, value, "toolbar")
      TestMode:QueueToolbarRefresh()
    end
  end)
  row.widget = widget
  row:Hide()
  return row
end

local function ConfigureChoiceControl(row, control, value, yOffset)
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", TOOLBAR_PADDING, yOffset)
  row:SetPoint("TOPRIGHT", row:GetParent(), "TOPRIGHT", -TOOLBAR_PADDING, yOffset)
  row.control = control
  local choices = {}
  for _, choice in ipairs(control.values or {}) do
    choices[choice.value] = choice.label or tostring(choice.value)
  end
  row.widget:SetLabel(control.label or control.key)
  row.widget:SetList(choices)
  row.widget:SetValue(value)
  row.widget:SetWidth(math_max(160, row:GetParent():GetWidth() - TOOLBAR_PADDING * 2))
  row:Show()
  return 58
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
  local widget = section.toggleButtons[index]
  if widget then
    return widget
  end
  widget = AceGUI:Create("PUI_Checkbox")
  ns.AceHooks.TakeOwnership(widget)
  widget.frame:SetParent(section)
  widget.frame:Show()
  widget:SetCallback("OnValueChanged", function(self, _, checked)
    local control = self.__puiControl
    if control then
      TestMode:SetValue(control.key, checked == true, "toolbar")
      TestMode:QueueToolbarRefresh()
    end
  end)
  section.toggleButtons[index] = widget
  return widget
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
  if state == "mixed" then
    check.widget:SetValue(nil)
  else
    check.widget:SetValue(state == "on")
  end
end

local function CreateVisibilityCheckbox(parent, onClick)
  local check = CreateFrame("Frame", nil, parent)
  check:SetSize(24, 24)
  local widget = AceGUI:Create("PUI_Checkbox")
  widget:SetLabel("")
  widget:SetWidth(28)
  widget:SetTriState(true)
  widget.frame:SetParent(check)
  widget.frame:ClearAllPoints()
  widget.frame:Show()
  ns.AceHooks.TakeOwnership(widget)
  widget:SetHeight(24)
  local geometry = ns.Theme.GetWidgetRowGeometry(widget)
  local metrics = ns.Theme.GetControlMetrics(widget)
  widget.frame:SetPoint("LEFT", check, "LEFT", (24 - metrics.checkboxBoxSize) / 2 - geometry.controlLeft, 0)
  check.widget = widget
  check.GetChecked = function() return widget:GetValue() == true end
  widget:SetCallback("OnValueChanged", function()
    onClick(check)
  end)
  return check
end

function TestMode:QueuePreviewRefresh()
  if not self.active or self.previewRefreshPending then
    return
  end
  self.previewRefreshPending = true
  _G.C_Timer.After(0, function()
    self.previewRefreshPending = nil
    if not self.active or InCombatLockdown() then
      return
    end
    for _, entry in ipairs(SortedRecords(self.participants)) do
      local key, participant = entry.key, entry.record
      local state = self.participantState[key]
      local visible = not participant.moverKey or ns.FrameUtil.IsMoverPreviewVisible(participant.moverKey)
      if state.enabled and visible and IsParticipantAvailable(key, participant) then
        if state.started then
          self:Refresh(key, "mover-visibility")
        else
          self:StartParticipant(key, "mover-visibility")
        end
      else
        self:StopParticipant(key, "mover-visibility")
      end
    end
  end)
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

local function BuildEditControls(panel)
  local host = CreateFrame("Frame", nil, panel.content)
  panel.editControls = host
  panel.editWidgets = {}
  local widgets = panel.editWidgets
  panel.editHeadings = {}
  for _, entry in ipairs({
    { "movement", "Movement" },
    { "snapping", "Snapping & grid" },
    { "appearance", "Appearance" },
    { "session", "Temporary visibility" },
  }) do
    local heading = host:CreateFontString(nil, "OVERLAY")
    heading:SetJustifyH("LEFT")
    StyleText(heading, "header", 12)
    heading:SetText(entry[2])
    panel.editHeadings[entry[1]] = heading
  end

  local function Checkbox(key, label, value, setter)
    local widget = AceGUI:Create("PUI_Checkbox")
    widget:SetLabel(label)
    widget:SetCallback("OnValueChanged", function(_, _, checked)
      local history = ns.FrameUtil.BeginEditHistory(label)
      setter(checked == true)
      ns.FrameUtil.CommitEditHistory(history)
      TestMode:QueueToolbarRefresh()
    end)
    widget.frame:SetParent(host)
    widget.frame:Show()
    ns.AceHooks.TakeOwnership(widget)
    widgets[key] = { widget = widget, label = label, value = value, setter = setter, height = 30 }
  end

  local function Slider(key, label, minimum, maximum, step, value, setter)
    local widget = AceGUI:Create("PUI_Slider")
    widget:SetLabel(label)
    widget:SetSliderValues(minimum, maximum, step)
    widget:SetCommitOnRelease(true)
    local history
    widget:SetCallback("OnValueChanging", function(_, _, newValue)
      history = history or ns.FrameUtil.BeginEditHistory(label)
      setter(newValue)
    end)
    widget:SetCallback("OnMouseUp", function(_, _, newValue)
      local transaction = history or ns.FrameUtil.BeginEditHistory(label)
      history = nil
      setter(newValue)
      ns.FrameUtil.CommitEditHistory(transaction)
    end)
    widget.frame:HookScript("OnHide", function()
      local transaction = history
      history = nil
      ns.FrameUtil.CommitEditHistory(transaction)
    end)
    widget.frame:SetParent(host)
    widget.frame:Show()
    ns.AceHooks.TakeOwnership(widget)
    widgets[key] = { widget = widget, label = label, value = value, setter = setter, height = 66 }
  end

  local function Dropdown(key, label, choices, value, setter)
    local widget = AceGUI:Create("PUI_Dropdown")
    widget:SetLabel(label)
    widget:SetList(choices)
    widget:SetCallback("OnValueChanged", function(_, _, choice)
      local navigation = key == "positionUnit"
      local history = not navigation and ns.FrameUtil.BeginEditHistory(label)
      setter(choice)
      ns.FrameUtil.CommitEditHistory(history)
      TestMode:QueueToolbarRefresh()
    end)
    widget.frame:SetParent(host)
    widget.frame:Show()
    ns.AceHooks.TakeOwnership(widget)
    widgets[key] = { widget = widget, label = label, value = value, setter = setter, height = 58 }
  end

  local util = ns.FrameUtil
  Checkbox("keyboard", "Keyboard movement", function() return util._keyboardMoveEnabled end,
    function(v) util.SetKeyboardMovementEnabled(v) end)
  Checkbox("compact", "Compact movers", function() return util._compactMovers end, util.SetCompactMovers)
  Checkbox("dim", "Disable screen dimming", function() return util._disableDimming end,
    util.SetEditDimmingDisabled)
  Checkbox("snap", "Snap to frames", function() return util._snapToFrame end,
    util.SetEditFrameSnap)
  Checkbox("smart", "Smart Snap", function() return util._smartSnapEnabled end,
    util.SetSmartSnapEnabled)
  Checkbox("snapGrid", "Snap to grid", function() return util._snapToGrid end,
    util.SetEditGridSnap)
  Dropdown("grid", "Show grid", { off = "Off", [8] = "8 px", [16] = "16 px", [32] = "32 px", [64] = "64 px" },
    function() return util._showGrid and util._gridSize or "off" end,
    function(value)
      if value == "off" then
        util.ShowGrid(false)
      else
        util.SetGridSize(value)
        util.ShowGrid(true)
      end
    end)
  Slider("nudge", "Nudge step", 1, 10, 1,
    function() return util._nudgeStep end, util._SetNudgeStepFromSlider)
  Slider("tolerance", "Snap distance", 2, 20, 1,
    function() return util._snapTolerance end, util.SetSnapTolerance)
  Slider("fade", "Screen dimming", 0, 1, 0.05,
    function() return util._dimAlpha end, util.SetEditDimAlpha)

  local help = {
    keyboard = "Use Tab to cycle movers, arrow keys to move them, and keys 1–9 to change the step.",
    nudge = "Distance moved by each arrow press, in pixels.",
    snap = "Align a mover with nearby frame edges while dragging.",
    smart = "Link supported movers so they move and arrange together.",
    tolerance = "How close movers must be before frame snapping or Smart Snap activates.",
    snapGrid = "Align movers with the grid while dragging.",
    grid = "Show a positioning grid. Grid visibility and snapping are separate settings.",
    compact = "Soften idle mover labels and borders. Hover or select a mover to show it clearly.",
    dim = "Keep the game background at its normal brightness while editing.",
    fade = "How much to darken the game background while editing.",
  }
  for key, text in pairs(help) do
    local spec = widgets[key]
    local control = { label = spec.label, tooltip = text }
    if key == "fade" then
      control.disabled = function() return util._disableDimming end
      control.disabledReason = function() return "Turn off Disable screen dimming to adjust the strength." end
    elseif key == "tolerance" then
      control.disabled = function() return not util._snapToFrame and not util._smartSnapEnabled end
      control.disabledReason = function() return "Enable Snap to frames or Smart Snap to adjust the snap distance." end
    end
    ns.EditModeQuickSettings:BindControlTooltip(spec.widget, control, panel)
  end

  panel.positionUnit = "target"
  host = CreateFrame("Frame", nil, panel.content)
  panel.positionControls = host
  Dropdown("positionUnit", "Frame positions", { target = "Target", focus = "Focus", boss1 = "Boss" },
    function() return panel.positionUnit end,
    function(value) panel.positionUnit = value end)
  Dropdown("switchMode", "On group change", {
    Never = "Never switch", Prompt = "Ask before switching", Auto = "Switch automatically",
  }, function()
    return ns.Modules.UnitFrames:GetPositionSettings().switchMode
  end, function(value)
    ns.Modules.UnitFrames:SetPositionSwitchMode(value)
  end)
  Dropdown("activeContext", "Active position layout", {
    Shared = "Shared", Solo = "Solo", Party = "Party", Raid = "Raid",
  }, function()
    return ns.Modules.UnitFrames:GetPositionSettings().active
  end, function(value)
    ns.Modules.UnitFrames:ActivatePositionContext(value)
  end)
  Checkbox("separate", "Use different positions by group", function()
    local config = ns.Modules.UnitFrames.db.profile.units[panel.positionUnit]
    return config.contextPositions and config.contextPositions.enabled == true
  end, function(value)
    ns.Modules.UnitFrames:SetSeparatePosition(panel.positionUnit, value)
  end)
  Dropdown("positionEdit", "Position to edit", {
    Shared = "Shared", Solo = "Solo", Party = "Party", Raid = "Raid",
  }, function()
    return ns.Modules.UnitFrames:GetPositionEditContext(panel.positionUnit)
  end, function(value)
    ns.Modules.UnitFrames:SetPositionEditContext(panel.positionUnit, value)
  end)
  Checkbox("positionOverride", "Use a separate position", function()
    local unit = panel.positionUnit
    local selected = ns.Modules.UnitFrames:GetPositionEditContext(unit)
    local context = ns.Modules.UnitFrames.db.profile.units[unit].contextPositions
    return context and context[selected] and context[selected].enabled == true
  end, function(value)
    local uf = ns.Modules.UnitFrames
    uf:SetContextPositionEnabled(panel.positionUnit, uf:GetPositionEditContext(panel.positionUnit), value)
  end)
  panel.removePositionButton = CreateToolbarButton(host, "Remove separate position", 230, function()
    local uf = ns.Modules.UnitFrames
    local history = ns.FrameUtil.BeginEditHistory("Remove separate position")
    uf:RemoveContextPosition(panel.positionUnit, uf:GetPositionEditContext(panel.positionUnit))
    ns.FrameUtil.CommitEditHistory(history)
    TestMode:RebuildToolbar()
  end)
  StyleButton(panel.removePositionButton, false)

  host = panel.editControls
  panel.blizzardSettingsButton = CreateToolbarButton(host, "Blizzard Cooldown Settings", 230, function()
    _G.CooldownViewerSettings:ShowUIPanel(false)
  end)
  StyleButton(panel.blizzardSettingsButton, false)

  panel.sessionButtons = {}
  for _, spec in ipairs({
    { "Hide selected", util.HideSelectedMoversForEditSession },
    { "Hide others", util.HideUnselectedMoversForEditSession },
    { "Show all", util.ShowAllMoversForEditSession },
  }) do
    local action = spec[2]
    local button = CreateToolbarButton(host, spec[1], 108, function()
      action()
      TestMode:RefreshEditControlButtons()
    end)
    StyleButton(button, false)
    panel.sessionButtons[#panel.sessionButtons + 1] = button
  end
end

function TestMode:GetEditHistoryControls()
  local controls = {}
  local panel = self.toolbar
  if not panel or not panel.editWidgets then return controls end
  for _, key in ipairs({ "keyboard", "compact", "dim", "snap", "smart", "snapGrid",
    "grid", "nudge", "tolerance", "fade" }) do
    local spec = panel.editWidgets[key]
    controls[#controls + 1] = { get = spec.value, set = spec.setter }
  end
  return controls
end

function TestMode:RefreshEditControlButtons()
  local panel = self.toolbar
  if not panel or not panel.sessionButtons then return end
  local history = ns.FrameUtil._editHistory
  panel.undoButton:SetEnabled(#history.undo > 0 and not history.pending)
  panel.redoButton:SetEnabled(#history.redo > 0 and not history.pending)
  local selected = ns.FrameUtil._GetSelectedMoverCount() > 0
  local widgets = panel.editWidgets
  widgets.fade.widget:SetDisabled(ns.FrameUtil._disableDimming)
  widgets.tolerance.widget:SetDisabled(not ns.FrameUtil._snapToFrame and not ns.FrameUtil._smartSnapEnabled)
  panel.sessionButtons[1]:SetEnabled(selected)
  panel.sessionButtons[2]:SetEnabled(selected)
  panel.sessionButtons[3]:SetEnabled(ns.FrameUtil.GetEditSessionHiddenMoverCount() > 0)
end

local EDIT_HELP = {
  "Select a mover with left-click. Ctrl+click selects multiple movers.",
  "Drag empty space to box-select. Drag a selected mover to move the selection.",
  "Right-click opens module settings; Ctrl+right-click resets a mover.",
  "Shift+right-click temporarily hides a mover; Show all restores it.",
  "Alt+right-click disconnects Smart Snap. Shift+left-drag detaches and moves freely.",
  "Use the arrows or the movable X/Y popup for precise positioning.",
  "Enable keyboard movement for Tab, Shift+Tab, arrow keys and steps 1–9.",
  "Undo reverses the last edit; Redo reapplies it. Ctrl+Z / Ctrl+Y also work outside text fields.",
  "History belongs to this session and clears when you exit or switch profiles.",
  "Esc closes Edit Mode. Presets only control editing handles, not live layouts.",
}

function TestMode:EnsureToolbar()
  if self.toolbar then
    return self.toolbar
  end

  local panel = CreateFrame("Frame", "PleebUI_TestModeToolbar", UIParent, "BackdropTemplate")
  panel:Hide()
  local window = ns.FrameUtil._GetEditModeDB().window or {}
  local maxWidth = math_max(TOOLBAR_MIN_WIDTH, UIParent:GetWidth() - 30)
  local maxHeight = math_max(TOOLBAR_MIN_HEIGHT, UIParent:GetHeight() - 60)
  local width = math_min(maxWidth, math_max(TOOLBAR_MIN_WIDTH, window.width or TOOLBAR_WIDTH))
  local height = math_min(maxHeight, math_max(TOOLBAR_MIN_HEIGHT, window.height or TOOLBAR_DEFAULT_HEIGHT))
  panel:SetSize(width, height)
  panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", window.x or 16, window.y or -32)
  panel:SetFrameStrata("DIALOG")
  panel:SetFrameLevel(180)
  panel:SetClampedToScreen(true)
  panel:SetMovable(true)
  panel:SetResizable(true)
  panel:SetResizeBounds(TOOLBAR_MIN_WIDTH, TOOLBAR_MIN_HEIGHT, maxWidth, maxHeight)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")

  local function SaveWindow(self)
    local db = ns.FrameUtil._GetEditModeDB()
    db.window = db.window or {}
    local left, top = self:GetLeft(), self:GetTop()
    if left and top then
      db.window.x = left - UIParent:GetLeft()
      db.window.y = top - UIParent:GetTop()
    end
    db.window.width = self:GetWidth()
    if not TestMode.toolbarCollapsed then
      db.window.height = self:GetHeight()
    end
  end

  panel:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then
      self:StartMoving()
    end
  end)
  panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveWindow(self)
  end)
  panel.SaveWindow = SaveWindow

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

  panel.undoButton = CreateToolbarButton(panel, "Undo", 90, function()
    ns.FrameUtil.ReplayEditHistory(false)
  end)
  panel.redoButton = CreateToolbarButton(panel, "Redo", 90, function()
    ns.FrameUtil.ReplayEditHistory(true)
  end)
  panel.undoButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", TOOLBAR_PADDING, 7)
  panel.redoButton:SetPoint("LEFT", panel.undoButton, "RIGHT", 6, 0)
  StyleButton(panel.undoButton, false)
  StyleButton(panel.redoButton, false)

  local visibility = ns.FrameUtil.GetMoverVisibilityConfig()
  panel.setLabel = panel:CreateFontString(nil, "OVERLAY")
  panel.setLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", TOOLBAR_PADDING, -38)
  StyleText(panel.setLabel, "body", 11)
  panel.setButtons = {}
  local previous
  for _, setName in ipairs(ns.FrameUtil.GetMoverVisibilitySetNames()) do
    local button = CreateToolbarButton(panel, setName, 84, function()
      ns.FrameUtil.SelectMoverVisibilitySet(setName)
      TestMode:RebuildToolbar()
    end)
    button:SetPoint("TOPLEFT", previous or panel, previous and "TOPRIGHT" or "TOPLEFT", previous and 6 or TOOLBAR_PADDING, previous and 0 or -61)
    panel.setButtons[setName] = button
    previous = button
  end

  panel.followCheck = CreateVisibilityCheckbox(panel, function(self)
    local history = ns.FrameUtil.BeginEditHistory("Follow current group")
    ns.FrameUtil.GetMoverVisibilityConfig().followGroup = self:GetChecked() == true
    ns.FrameUtil.CommitEditHistory(history)
    StyleVisibilityCheckbox(self, self:GetChecked() and "on" or "off")
  end)
  panel.followCheck.widget:SetTriState(false)
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
  StyleButton(panel.resetButton, false)

  panel.search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  ns.Theme.WidgetSkins.UIEditBox(panel.search)
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
  panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -27, 42)
  panel.scroll.ScrollBar.scrollStep = 26
  ns.Theme.WidgetSkins.Scrollbar(panel.scroll.ScrollBar)

  panel.content = CreateFrame("Frame", nil, panel.scroll)
  panel.content:SetWidth(width - 30)
  panel.content:SetHeight(100)
  panel.scroll:SetScrollChild(panel.content)

  for _, button in pairs(panel.setButtons) do
    button:SetParent(panel.content)
    button:ClearAllPoints()
  end
  for _, region in ipairs({ panel.setLabel, panel.followCheck, panel.followLabel,
    panel.resetButton, panel.search }) do
    region:SetParent(panel.content)
    region:ClearAllPoints()
  end

  panel.sectionButtons = {}
  for _, definition in ipairs({
    { key = "positions", label = "Group positions" },
    { key = "movers", label = "Movers" },
    { key = "controls", label = "Edit controls" },
    { key = "help", label = "Help & shortcuts" },
  }) do
    local key = definition.key
    panel.sectionButtons[key] = CreateToolbarButton(panel.content, definition.label, 190, function()
      local db = ns.FrameUtil._GetEditModeDB()
      db.editSections = db.editSections or { movers = true }
      db.editSections[key] = db.editSections[key] ~= true
      TestMode:RebuildToolbar()
    end)
  end

  panel.resizeGrip = CreateFrame("Button", nil, panel)
  panel.resizeGrip:SetSize(18, 18)
  panel.resizeGrip:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
  local gripTexture = panel.resizeGrip:CreateTexture(nil, "ARTWORK")
  gripTexture:SetAllPoints()
  gripTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  panel.resizeGrip:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and not InCombatLockdown() then
      panel:StartSizing("BOTTOMRIGHT")
    end
  end)
  panel.resizeGrip:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
      panel:StopMovingOrSizing()
      panel.SaveWindow(panel)
      TestMode:RebuildToolbar()
    end
  end)
  panel:SetScript("OnSizeChanged", function(self, newWidth)
    panel.content:SetWidth(math_max(1, newWidth - 30))
  end)
  panel:SetPropagateKeyboardInput(true)
  panel:SetScript("OnKeyDown", function(self, key)
    self:SetPropagateKeyboardInput(not ns.FrameUtil.HandleEditModeKeyDown(key))
  end)
  panel:SetScript("OnHide", function()
    if ns.Flags.IsEditing and TestMode.active then
      Addon:SetEditMode(false)
    end
  end)
  _G.table.insert(_G.UISpecialFrames, panel:GetName())

  panel.moverRows = {}
  panel.searchCollapsed = {}
  panel.__puiSections = {}
  panel.profileEditMode = ns.FrameUtil._GetEditModeDB()
  self.toolbar = panel
  BuildEditControls(panel)
  StylePanel(panel)
  return panel
end

local function HideToolbarSections(panel)
  for _, section in ipairs(panel.__puiSections or {}) do
    section:Hide()
    section:ClearAllPoints()

    for _, widget in ipairs(section.toggleButtons or {}) do
      widget.frame:Hide()
      widget.frame:ClearAllPoints()
    end

    for _, row in ipairs(section.choiceRows or {}) do
      row:Hide()
      row:ClearAllPoints()
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
    if opts.moduleKey and ns.FrameUtil.IsMoverAvailable(entry) then
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

local function ToggleMoverVisibility(check)
  ns.FrameUtil.SetMoverVisibilityNode(check.__puiKind, check.__puiKey, check.__puiState == "off")
  TestMode:RebuildToolbar()
end

local function ToggleMoverRowExpansion(panel, row)
  local config = ns.FrameUtil.GetMoverVisibilityConfig()
  local key = row.__puiExpansionKey
  if key == "previews" then
    config.previewsExpanded = not (config.previewsExpanded == true)
  elseif panel.search:GetText() ~= "" then
    panel.searchCollapsed[key] = not panel.searchCollapsed[key]
  else
    config.expanded[key] = not (config.expanded[key] == true)
  end
  TestMode:RebuildToolbar()
end

local function AcquireMoverRow(panel, index)
  local row = panel.moverRows[index]
  if row then return row end

  row = CreateFrame("Button", nil, panel.content)
  row:SetHeight(25)
  row:EnableMouse(true)
  row:RegisterForClicks("LeftButtonUp")
  row:SetScript("OnClick", function(self)
    if self.__puiExpansionKey then
      ToggleMoverRowExpansion(panel, self)
    else
      ToggleMoverVisibility(self.check)
    end
  end)

  local highlight = row:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  row.hoverHighlight = highlight

  local expand = CreateToolbarButton(row, "+", 22, function()
    ToggleMoverRowExpansion(panel, row)
  end)
  expand:SetHeight(22)
  row.expand = expand

  local check = CreateVisibilityCheckbox(row, ToggleMoverVisibility)
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
  row.__puiExpansionKey = expansionKey
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
  local accent = ns.Theme.GetColors().accent
  row.hoverHighlight:SetColorTexture(accent[1], accent[2], accent[3], 0.10)
  StyleText(row.label, depth == 0 and "header" or "body", 12)
  row:Show()
end

function TestMode:RebuildToolbar()
  local panel = self:EnsureToolbar()
  local profile = ns.FrameUtil._GetEditModeDB()
  if panel.profileEditMode ~= profile then
    panel.profileEditMode = profile
    panel.expandedHeight = nil
    local window = profile.window or {}
    local maxWidth = math_max(TOOLBAR_MIN_WIDTH, UIParent:GetWidth() - 30)
    local maxHeight = math_max(TOOLBAR_MIN_HEIGHT, UIParent:GetHeight() - 60)
    panel:SetSize(
      math_min(maxWidth, math_max(TOOLBAR_MIN_WIDTH, window.width or TOOLBAR_WIDTH)),
      math_min(maxHeight, math_max(TOOLBAR_MIN_HEIGHT, window.height or TOOLBAR_DEFAULT_HEIGHT))
    )
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", window.x or 16, window.y or -32)
    panel.content:SetWidth(panel:GetWidth() - 30)
  end
  local content = panel.content
  local config = ns.FrameUtil.GetMoverVisibilityConfig()
  HideToolbarSections(panel)
  for _, row in ipairs(panel.moverRows) do row:Hide() end

  local windowSections = profile.editSections
  if not windowSections then
    windowSections = { movers = true }
    profile.editSections = windowSections
  end
  local y = -2
  local function AddSectionHeader(key, title)
    local open = windowSections[key] == true
    local button = panel.sectionButtons[key]
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", content, "TOPLEFT", TOOLBAR_PADDING, y)
    button:SetPoint("TOPRIGHT", content, "TOPRIGHT", -TOOLBAR_PADDING, y)
    button:SetText((open and "-  " or "+  ") .. title)
    StyleButton(button, false)
    button:Show()
    y = y - 34
    return open
  end
  local uf = ns.Modules.UnitFrames
  local groupAvailable = uf ~= nil and uf.db ~= nil
  local positionsOpen = groupAvailable and AddSectionHeader("positions", "Group positions")
  panel.sectionButtons.positions:SetShown(groupAvailable)
  panel.positionControls:SetShown(positionsOpen)
  if positionsOpen then
    local host = panel.positionControls
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", content, "TOPLEFT", TOOLBAR_PADDING, y)
    host:SetPoint("TOPRIGHT", content, "TOPRIGHT", -TOOLBAR_PADDING, y)
    local controlY = -4
    local available = math_max(220, content:GetWidth() - TOOLBAR_PADDING * 2 - 12)
    local positions = uf.db.profile.units[panel.positionUnit].contextPositions
    local editContext = uf:GetPositionEditContext(panel.positionUnit)
    for _, key in ipairs({ "positionUnit", "switchMode", "activeContext", "separate",
      "positionEdit", "positionOverride" }) do
      local spec = panel.editWidgets[key]
      local frame = spec.widget.frame
      local show = true
      if key == "positionEdit" or key == "positionOverride" then
        show = positions ~= nil and positions.enabled == true
        if key == "positionOverride" then
          show = show and editContext ~= "Shared"
        end
      end
      frame:SetShown(show)
      if show then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", host, "TOPLEFT", 4, controlY)
        spec.widget:SetWidth(available)
        frame:SetHeight(spec.height)
        if key == "positionOverride" then
          spec.widget:SetLabel("Use a separate " .. editContext .. " position")
        end
        spec.widget:SetValue(spec.value())
        if key == "separate" then
          spec.widget:SetDisabled(ns.FrameUtil.HasSmartSnapLinks("UF_" .. panel.positionUnit)
            and not spec.value())
        end
        controlY = controlY - spec.height - 4
      end
    end
    local existing = positions and positions[editContext]
    panel.removePositionButton:ClearAllPoints()
    panel.removePositionButton:SetPoint("TOPLEFT", host, "TOPLEFT", 4, controlY)
    panel.removePositionButton:SetWidth(available)
    panel.removePositionButton:SetShown(editContext ~= "Shared" and existing ~= nil)
    if panel.removePositionButton:IsShown() then
      controlY = controlY - 34
    end
    host:SetHeight(-controlY)
    y = y + controlY - SECTION_GAP
  end

  local moversOpen = AddSectionHeader("movers", "Movers")
  panel.setLabel:SetShown(moversOpen)
  panel.followCheck:SetShown(moversOpen)
  panel.followLabel:SetShown(moversOpen)
  panel.resetButton:SetShown(moversOpen)
  panel.search:SetShown(moversOpen)
  for _, button in pairs(panel.setButtons) do
    button:SetShown(moversOpen)
  end
  if moversOpen then
    panel.setLabel:SetText("Editing: " .. config.selectedSet)
    panel.setLabel:SetPoint("TOPLEFT", content, "TOPLEFT", TOOLBAR_PADDING, y)
    panel.resetButton:SetPoint("TOPRIGHT", content, "TOPRIGHT", -TOOLBAR_PADDING, y + 4)
    y = y - 36
    local previous
    local tabWidth = math_floor((content:GetWidth() - TOOLBAR_PADDING * 2 - 18) / 4)
    for _, name in ipairs(ns.FrameUtil.GetMoverVisibilitySetNames()) do
      local button = panel.setButtons[name]
      button:SetWidth(tabWidth)
      button:SetPoint("TOPLEFT", previous or content, previous and "TOPRIGHT" or "TOPLEFT",
        previous and 6 or TOOLBAR_PADDING, previous and 0 or y)
      StyleButton(button, name == config.selectedSet)
      previous = button
    end
    y = y - 35
    StyleVisibilityCheckbox(panel.followCheck, config.followGroup and "on" or "off")
    panel.followCheck:SetPoint("TOPLEFT", content, "TOPLEFT", TOOLBAR_PADDING, y)
    panel.followLabel:ClearAllPoints()
    panel.followLabel:SetPoint("LEFT", panel.followCheck, "RIGHT", 3, 0)
    panel.followLabel:SetPoint("RIGHT", content, "RIGHT", -TOOLBAR_PADDING, 0)
    y = y - 34
    panel.search:SetPoint("TOPLEFT", content, "TOPLEFT", TOOLBAR_PADDING + 6, y)
    panel.search:SetPoint("TOPRIGHT", content, "TOPRIGHT", -TOOLBAR_PADDING - 6, y)
    y = y - 38
  end

  local search = (panel.search:GetText() or ""):lower()
  local function Matches(value)
    return search == "" or (tostring(value):lower():find(search, 1, true) ~= nil)
  end

  local rowIndex = 0
  local function AddRow(kind, key, label, depth, state, expansionKey, expanded)
    rowIndex = rowIndex + 1
    ShowMoverRow(panel, rowIndex, y, kind, key, label, depth, state, expansionKey, expanded)
    y = y - 26
  end

  if moversOpen then
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

          local widget = AcquireToggleButton(section, index)
          widget.__puiControl = control
          widget:SetLabel(control.label or control.key)
          widget:SetWidth(TOGGLE_WIDTH)
          widget.frame:ClearAllPoints()
          widget.frame:SetPoint("TOPLEFT", section, "TOPLEFT", toggleX, toggleY)
          widget:SetValue(self:GetValue(control.key) == true)
          widget.frame:Show()
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
  end

  local controlsOpen = AddSectionHeader("controls", "Edit controls")
  panel.editControls:SetShown(controlsOpen)
  if controlsOpen then
    local host = panel.editControls
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", content, "TOPLEFT", TOOLBAR_PADDING, y)
    host:SetPoint("TOPRIGHT", content, "TOPRIGHT", -TOOLBAR_PADDING, y)
    local controlY = -4
    local available = math_max(220, content:GetWidth() - TOOLBAR_PADDING * 2 - 12)
    for _, key in ipairs({ "keyboard", "nudge", "snap", "smart", "tolerance", "snapGrid", "grid",
      "compact", "dim", "fade" }) do
      local headingKey = key == "keyboard" and "movement"
        or key == "snap" and "snapping"
        or key == "compact" and "appearance"
      if headingKey then
        local heading = panel.editHeadings[headingKey]
        StyleText(heading, "header", 12)
        heading:ClearAllPoints()
        heading:SetPoint("TOPLEFT", host, "TOPLEFT", 4, controlY)
        heading:Show()
        controlY = controlY - 26
      end
      local spec = panel.editWidgets[key]
      local frame = spec.widget.frame
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", host, "TOPLEFT", 4, controlY)
      spec.widget:SetWidth(available)
      frame:SetHeight(spec.height)
      spec.widget:SetValue(spec.value())
      frame:Show()
      controlY = controlY - spec.height - 4
    end
    local sessionHeading = panel.editHeadings.session
    StyleText(sessionHeading, "header", 12)
    sessionHeading:ClearAllPoints()
    sessionHeading:SetPoint("TOPLEFT", host, "TOPLEFT", 4, controlY)
    sessionHeading:Show()
    controlY = controlY - 26
    for index, button in ipairs(panel.sessionButtons) do
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", host, "TOPLEFT", 4 + (index - 1) * (available - 8) / 3, controlY)
      button:SetWidth((available - 14) / 3)
      button:Show()
    end
    TestMode:RefreshEditControlButtons()
    controlY = controlY - 38
    panel.blizzardSettingsButton:ClearAllPoints()
    panel.blizzardSettingsButton:SetPoint("TOPLEFT", host, "TOPLEFT", 4, controlY)
    panel.blizzardSettingsButton:SetWidth(available)
    panel.blizzardSettingsButton:Show()
    controlY = controlY - 32
    host:SetHeight(-controlY)
    y = y + controlY - 6
  end

  local helpOpen = AddSectionHeader("help", "Help & shortcuts")
  panel.helpRows = panel.helpRows or {}
  for _, label in ipairs(panel.helpRows) do label:Hide() end
  if helpOpen then
    for index, line in ipairs(EDIT_HELP) do
      local label = panel.helpRows[index]
      if not label then
        label = content:CreateFontString(nil, "OVERLAY")
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
        label:SetWordWrap(true)
        panel.helpRows[index] = label
      end
      StyleText(label, "body", 12)
      label:SetWidth(math_max(230, content:GetWidth() - TOOLBAR_PADDING * 2 - 15))
      label:ClearAllPoints()
      label:SetPoint("TOPLEFT", content, "TOPLEFT", TOOLBAR_PADDING + 5, y)
      label:SetText(line)
      label:Show()
      y = y - math_max(36, label:GetStringHeight() + 12)
    end
  end

  local contentHeight = math_max(60, -y + 2)
  content:SetHeight(contentHeight)
  if self.toolbarCollapsed then
    if panel:GetHeight() ~= TOOLBAR_COLLAPSED_HEIGHT then
      panel.expandedHeight = panel:GetHeight()
      panel:SetHeight(TOOLBAR_COLLAPSED_HEIGHT)
    end
  elseif panel.expandedHeight then
    panel:SetHeight(panel.expandedHeight)
    panel.expandedHeight = nil
  end
  panel.resizeGrip:SetShown(not self.toolbarCollapsed)
  panel.scroll:SetShown(not self.toolbarCollapsed)
  panel.undoButton:SetShown(not self.toolbarCollapsed)
  panel.redoButton:SetShown(not self.toolbarCollapsed)
  panel.scroll:SetVerticalScroll(math_min(panel.scroll:GetVerticalScroll(),
    math_max(0, contentHeight - (panel:GetHeight() - TOOLBAR_TITLE_HEIGHT - 42))))
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
      local accent = ns.Theme.GetColors().accent
      row.hoverHighlight:SetColorTexture(accent[1], accent[2], accent[3], 0.10)
      StyleText(row.label, "body", 12)
      StyleVisibilityCheckbox(row.check, row.check.__puiState)
      StyleButton(row.expand, false)
    end
  end
  for _, button in pairs(panel.sectionButtons) do
    StyleButton(button, false)
  end
  for _, button in ipairs(panel.sessionButtons) do
    StyleButton(button, false)
  end
  StyleButton(panel.blizzardSettingsButton, false)
  StyleButton(panel.removePositionButton, false)
  for _, heading in pairs(panel.editHeadings) do
    StyleText(heading, "header", 12)
  end
  for _, label in ipairs(panel.helpRows or {}) do
    if label:IsShown() then
      StyleText(label, "body", 12)
    end
  end
  StyleButton(panel.exitButton, false)
  StyleButton(panel.undoButton, false)
  StyleButton(panel.redoButton, false)
  StyleButton(panel.minimizeButton, false)
  ns.Theme.ApplyExpandCollapseButton(panel.minimizeButton, not TestMode.toolbarCollapsed)

  for _, section in ipairs(panel.__puiSections or {}) do
    if section:IsShown() then
      StylePanel(section)
      StyleText(section.heading, "header", 12)

      local participantKey = section.enabledButton.__puiParticipantKey
      StyleButton(section.enabledButton, participantKey and TestMode:IsParticipantEnabled(participantKey))

      for _, widget in ipairs(section.toggleButtons or {}) do
        if widget.frame:IsShown() then
          widget:SetValue(TestMode:GetValue(widget.__puiControl.key) == true)
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
  ns.FrameUtil._UpdateEditDialogKeyboardState()
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
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "SPELLS_CHANGED" then
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then
      return
    end
    if ns.Flags.IsEditing and not InCombatLockdown() then
      ns.FrameUtil.ApplyMoverVisibilityPreset()
    end
    return
  end
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
