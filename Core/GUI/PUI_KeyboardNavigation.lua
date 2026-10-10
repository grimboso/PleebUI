local _, ns = ...

local Navigation = {}
ns.KeyboardNavigation = Navigation
local widgets = setmetatable({}, { __mode = "k" })
local controls = setmetatable({}, { __mode = "k" })
local windows = setmetatable({}, { __mode = "k" })
local current, activeWindow, popup, serial = nil, nil, nil, 0
local restorePending
local pendingWindows = setmetatable({}, { __mode = "k" })
local MoveFocus, FocusControl

local function BelongsTo(frame, root)
  while frame do
    if frame == root then return true end
    frame = frame:GetParent()
  end
  return false
end

local function ControlKey(control)
  local widget = control.widget
  if widget then
    local user = widget:GetUserDataTable()
    local path = user.path or {}
    local parts = {}
    for index, value in ipairs(path) do parts[index] = tostring(value) end
    local key = widget.__puiControl and widget.__puiControl.key
      or (user.puiControlTooltip and user.puiControlTooltip.label)
      or (#parts > 0 and widget.type or control.serial)
    return table.concat(parts, "\001") .. "\002" .. tostring(key) .. "\002" .. control.part
  end
  local frame = control.frame
  return control.part .. "\002" .. tostring(frame.uniquevalue or frame.__puiValue or frame.__puiSectionKey or frame:GetName() or frame:GetText() or control.serial)
end

local function IsDisabled(control)
  local frame, widget = control.frame, control.widget
  return (widget and widget.disabled == true) or frame.__puiDisabled == true
    or (frame:GetObjectType() == "Button" and not frame:IsEnabled())
    or (frame.treeline and frame.treeline.disabled == true)
end

local function RunControlScript(frame, script, ...)
  local callback = frame:GetScript(script)
  if callback then callback(frame, ...) end
end

local function Activate(control)
  if IsDisabled(control) then return end
  local frame = control.frame
  if control.mouseUp then
    RunControlScript(frame, "OnMouseUp", "LeftButton")
  else
    frame:Click("LeftButton")
  end
  Navigation.RefreshWindows()
end

local function ScrollIntoView(frame)
  local parent = frame:GetParent()
  while parent do
    if parent:GetObjectType() == "ScrollFrame" then
      local top, bottom = frame:GetTop(), frame:GetBottom()
      local viewportTop, viewportBottom = parent:GetTop(), parent:GetBottom()
      if top and bottom and viewportTop and viewportBottom then
        local offset = parent:GetVerticalScroll()
        if top > viewportTop then offset = offset - (top - viewportTop)
        elseif bottom < viewportBottom then offset = offset + viewportBottom - bottom end
        offset = math.max(0, math.min(parent:GetVerticalScrollRange(), offset))
        parent:SetVerticalScroll(offset)
      end
    end
    parent = parent:GetParent()
  end
end

local function HideFocus()
  if not current then return end
  local frame = current.frame
  if frame.__puiKeyboardOutline then frame.__puiKeyboardOutline:Hide() end
  if current.widget then ns.AceHooks.HideDisabledTooltip(current.widget) end
end

local function DrawFocus(control)
  local frame = control.frame
  local outline = frame.__puiKeyboardOutline
  if not outline then
    outline = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    outline:EnableMouse(false)
    outline:SetAllPoints(frame)
    outline:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = ns.Theme.ControlBorderSize })
    frame.__puiKeyboardOutline = outline
  end
  local _, border = ns.Theme.GetControlStateColors(false, false, false, true)
  outline:SetBackdropBorderColor(unpack(border))
  outline:SetFrameStrata(frame:GetFrameStrata())
  outline:SetFrameLevel(frame:GetFrameLevel() + 30)
  outline:Show()
end

local function HookTextInput(frame)
  if frame.__puiKeyboardTextHooked then return end
  frame.__puiKeyboardTextHooked = true
  local tab = frame:GetScript("OnTabPressed")
  frame:SetScript("OnTabPressed", function(self)
    local control = controls[self]
    local state = activeWindow and windows[activeWindow]
    if control and state and BelongsTo(self, activeWindow) and not InCombatLockdown()
      and (not state.enabled or state.enabled()) then
      Navigation.HandleKey("TAB")
    elseif tab then
      tab(self)
    end
  end)
  frame:HookScript("OnEditFocusGained", function(self)
    local control = controls[self]
    local state = activeWindow and windows[activeWindow]
    if not control or not state or not BelongsTo(self, activeWindow)
      or (state.enabled and not state.enabled()) then return end
    HideFocus()
    current = control
    windows[activeWindow].active = true
    DrawFocus(control)
    Navigation.RefreshWindows()
  end)
  frame:HookScript("OnEscapePressed", function(self)
    if controls[self] and self:HasFocus() then self:ClearFocus() end
  end)
  frame:HookScript("OnKeyDown", function(self, key)
    if key == "F6" and controls[self] and activeWindow and BelongsTo(self, activeWindow) then
      Navigation.HandleKey(key)
    end
  end)
  frame:HookScript("OnEditFocusLost", function() Navigation.RefreshWindows() end)
end

function Navigation.RegisterFrame(frame, kind, part, group, widget, mouseUp)
  local control = controls[frame]
  if not control then
    serial = serial + 1
    control = { frame = frame, serial = serial }
    controls[frame] = control
    frame:HookScript("OnHide", function(self)
      if current and current.frame == self then
        local state = activeWindow and windows[activeWindow]
        if state and state.active then state.restoreKey = ControlKey(current) end
        HideFocus()
        current = nil
      end
    end)
  end
  control.kind, control.part, control.group, control.widget, control.mouseUp = kind, part, group, widget, mouseUp
  if kind == "text" then HookTextInput(frame) end
  return control
end

function Navigation.RegisterWidget(widget)
  widgets[widget] = true
  local kind = widget.type
  if kind == "PUI_Slider" then
    Navigation.RegisterFrame(widget.slider, "slider", "slider", nil, widget)
    Navigation.RegisterFrame(widget.minusButton, "button", "minus", nil, widget)
    Navigation.RegisterFrame(widget.editbox, "text", "value", nil, widget)
    Navigation.RegisterFrame(widget.plusButton, "button", "plus", nil, widget)
  elseif kind == "PUI_Button" or kind == "Button" or kind == "Keybinding" then
    Navigation.RegisterFrame(widget.button or widget.frame, "button", "button", nil, widget)
  elseif kind == "PUI_Checkbox" or kind == "CheckBox" then
    Navigation.RegisterFrame(widget.frame, "button", "checkbox", nil, widget, true)
  elseif kind == "PUI_EditBox" or kind == "PUI_MultiLineEditBox" or kind == "EditBox" or kind == "MultiLineEditBox" then
    Navigation.RegisterFrame(widget.editbox or widget.editBox, "text", "input", nil, widget)
    Navigation.RegisterFrame(widget.button, "button", "accept", nil, widget)
  elseif kind == "PUI_Dropdown" or kind == "Dropdown" then
    Navigation.RegisterFrame(widget.button_cover or widget.button, "dropdown", "dropdown", nil, widget)
  elseif kind:sub(1, 6) == "LSM30_" then
    Navigation.RegisterFrame(widget.frame.dropButton, "dropdown", "dropdown", nil, widget)
  elseif kind == "ColorPicker" then
    Navigation.RegisterFrame(widget.frame, "button", "color", nil, widget)
  end
  if kind == "Keybinding" and not widget.button.__puiKeyboardBindingHooked then
    local button = widget.button
    button.__puiKeyboardBindingHooked = true
    for _, script in ipairs({ "OnKeyDown", "OnClick", "OnMouseDown", "OnMouseWheel", "OnGamePadButtonDown" }) do
      button:HookScript(script, function() Navigation.RefreshWindows() end)
    end
    button:HookScript("OnHide", function()
      if widget.waitingForKey then
        RunControlScript(button, "OnClick", "LeftButton")
        Navigation.RefreshWindows()
      end
    end)
  end
end

function Navigation.ReleaseWidget(widget)
  widgets[widget] = nil
  for frame, control in pairs(controls) do
    if control.widget == widget then
      if current == control then
        local state = activeWindow and windows[activeWindow]
        if state and state.active then
          state.restoreKey = ControlKey(control)
        end
        HideFocus()
        current = nil
      end
      controls[frame] = nil
    end
  end
  if popup and popup.widget == widget then popup = nil end
  Navigation.QueueRestore()
end

local function Collect(root)
  for widget in pairs(widgets) do
    if widget.__puiAceGUIOwnedByPleebUI == true and BelongsTo(widget.frame, root) then
      if widget.type == "TreeGroup" then
        for _, button in ipairs(widget.buttons) do
          Navigation.RegisterFrame(button, "tree", "tree:" .. tostring(button.uniquevalue), widget, widget)
        end
      elseif widget.type == "TabGroup" and widget.__puiCustomTabHost then
        for _, button in ipairs(widget.__puiCustomTabHost.__puiButtons) do
          Navigation.RegisterFrame(button, "tabs", "tab:" .. tostring(button.__puiValue), widget, widget)
        end
      end
    end
  end
  local result = {}
  for frame, control in pairs(controls) do
    if frame:IsVisible() and BelongsTo(frame, root)
      and not (frame.__puiNode and frame.__puiNode.meta.navHeader == true)
      and (not control.widget or control.widget.__puiAceGUIOwnedByPleebUI == true)
    then
      local row = control.widget and control.kind ~= "tree" and control.kind ~= "tabs" and control.widget.frame or frame
      local top, left = row:GetTop(), frame:GetLeft()
      if top and left then
        control.top, control.left = math.floor(top + 0.5), left
        result[#result + 1] = control
      end
    end
  end
  table.sort(result, function(a, b)
    if a.top ~= b.top then return a.top > b.top end
    if a.left ~= b.left then return a.left < b.left end
    return a.serial < b.serial
  end)
  return result
end

FocusControl = function(control)
  local old = current
  HideFocus()
  current = nil
  if old and old.kind == "text" and old.frame:HasFocus() and (old ~= control or IsDisabled(old)) then
    old.frame:ClearFocus()
  end
  if control and (not control.frame:IsVisible()
    or (control.widget and control.widget.__puiAceGUIOwnedByPleebUI ~= true)) then
    Navigation.QueueRestore()
    Navigation.RefreshWindows()
    return
  end
  current = control
  if not control then Navigation.RefreshWindows(); return end
  windows[activeWindow].active = true
  ScrollIntoView(control.frame)
  DrawFocus(control)
  if IsDisabled(control) then
    if control.widget then ns.AceHooks.ShowDisabledTooltip(control.widget) end
  elseif control.kind == "text" and not control.frame:HasFocus() then
    control.frame:SetFocus()
  end
  Navigation.RefreshWindows()
end

MoveFocus = function(direction)
  local list = Collect(activeWindow)
  local groups, stops = {}, {}
  for _, control in ipairs(list) do
    local group = control.group
    if not group then stops[#stops + 1] = control
    elseif not groups[group] then
      groups[group] = true
      local choice = control
      for _, member in ipairs(list) do
        if member.group == group and (member == current or member.frame.selected == true
          or (member.kind == "tabs" and member.frame.__puiValue == (group.status or group.localstatus).selected)) then
          choice = member
          if member == current then break end
        end
      end
      stops[#stops + 1] = choice
    end
  end
  if #stops == 0 then FocusControl(nil); return end
  local index = direction > 0 and 0 or 1
  for i, control in ipairs(stops) do if control == current then index = i; break end end
  FocusControl(stops[(index - 1 + direction) % #stops + 1])
end

local function FocusTreeLine(widget, index)
  local line = widget.lines[index]
  if not line then return end
  local count, visible = 0, false
  for _, button in ipairs(widget.buttons) do
    if button:IsShown() then
      count = count + 1
      if button.uniquevalue == line.uniquevalue then visible = true end
    end
  end
  if not visible then
    local status = widget.status or widget.localstatus
    widget.scrollbar:SetValue(index <= status.scrollvalue and index - 1 or math.max(0, index - count))
  end
  for _, button in ipairs(widget.buttons) do
    if button:IsShown() and button.uniquevalue == line.uniquevalue then
      FocusControl(Navigation.RegisterFrame(button, "tree", "tree:" .. tostring(button.uniquevalue), widget, widget))
      return
    end
  end
end

local function MoveInGroup(direction)
  if current.kind == "tree" and current.widget then
    local widget = current.widget
    for index, line in ipairs(widget.lines) do
      if line.uniquevalue == current.frame.uniquevalue then
        FocusTreeLine(widget, math.max(1, math.min(#widget.lines, index + direction)))
        return
      end
    end
    return
  end
  local members = {}
  for _, control in ipairs(Collect(activeWindow)) do
    if control.group == current.group then members[#members + 1] = control end
  end
  for index, control in ipairs(members) do
    if control == current then
      FocusControl(members[(index - 1 + direction) % #members + 1])
      return
    end
  end
end

local function ClosePopup()
  if not popup then return false end
  local owner, widget = popup.owner, popup.widget
  popup = nil
  widget:ClearFocus()
  FocusControl(owner)
  return true
end

local function PopupRows()
  local rows = {}
  local widget = popup.widget
  if widget.pullout then
    for _, item in ipairs(widget.pullout.items) do
      if item.frame:IsVisible() and item.type ~= "Dropdown-Item-Separator" and not item.disabled then rows[#rows + 1] = item.frame end
    end
  elseif widget.dropdown then
    for _, row in ipairs(widget.dropdown.contentRepo) do
      if row:IsVisible() then rows[#rows + 1] = row end
    end
  end
  return rows
end

local function MoveInPopup(direction)
  local rows = PopupRows()
  if #rows == 0 then return end
  local index = direction > 0 and 0 or 1
  for i, row in ipairs(rows) do if current and current.frame == row then index = i; break end end
  local row = rows[(index - 1 + direction) % #rows + 1]
  local control = Navigation.RegisterFrame(row, "popup", "popup", nil, popup.widget)
  FocusControl(control)
end

local function OpenPopup(control)
  Activate(control)
  local widget = control.widget
  local frame = widget.pullout and widget.pullout.frame or widget.dropdown
  if not frame or not frame:IsShown() then return end
  popup = { widget = widget, owner = control, frame = frame }
  if not frame.__puiKeyboardPopupHooked then
    frame.__puiKeyboardPopupHooked = true
    frame:HookScript("OnHide", function(self)
      if popup and popup.frame == self then
        local owner = popup.owner
        popup = nil
        FocusControl(owner)
      end
    end)
  end
  local search = widget.pullout and widget.pullout.__puiDropdownSearchBox or frame.__puiLSMFontSearchBox
  if search and search:IsShown() then
    local entry = Navigation.RegisterFrame(search, "text", "popupSearch", nil, widget)
    FocusControl(entry)
  else
    MoveInPopup(1)
  end
end

local function ScrollPage(direction)
  local frame = current and current.frame
  while frame do
    if frame:GetObjectType() == "ScrollFrame" then
      frame:SetVerticalScroll(math.max(0, math.min(frame:GetVerticalScrollRange(), frame:GetVerticalScroll() + direction * frame:GetHeight() * 0.8)))
      return true
    end
    frame = frame:GetParent()
  end
  return false
end

function Navigation.HandleKey(key)
  if not activeWindow or InCombatLockdown() then return false end
  local state = windows[activeWindow]
  if state.enabled and not state.enabled() then return false end
  local text = GetCurrentKeyBoardFocus()
  if text and not BelongsTo(text, activeWindow) and not (popup and current and current.frame == text) then return false end
  if key == "F6" and state.movers then
    if state.active then
      HideFocus()
      if current and current.kind == "text" then current.frame:ClearFocus() end
      ClosePopup()
      HideFocus()
      current, state.active = nil, false
    else
      MoveFocus(1)
    end
    Navigation.RefreshWindows()
    return true
  end
  if not state.active and state.movers then return ns.FrameUtil.HandleEditModeKeyDown(key) == true end
  if key == "TAB" then
    if popup then
      if current and current.kind == "text" then MoveInPopup(IsShiftKeyDown() and -1 or 1)
      else ClosePopup(); MoveFocus(IsShiftKeyDown() and -1 or 1) end
    else MoveFocus(IsShiftKeyDown() and -1 or 1) end
    return true
  end
  if not state.active then return false end
  if key == "ESCAPE" then
    if ClosePopup() then return true end
    if state.cancel then state.cancel(); return true end
    HideFocus()
    current, state.active = nil, false
    Navigation.RefreshWindows()
    return true
  end
  if not current then return false end
  if key == "PAGEUP" or key == "PAGEDOWN" then return ScrollPage(key == "PAGEUP" and -1 or 1) end
  if popup then
    if key == "UP" or key == "DOWN" then MoveInPopup(key == "UP" and -1 or 1); return true end
    if key == "ENTER" or key == "SPACE" then
      if current.kind == "popup" then
        local owner, widget = popup.owner, popup.widget
        Activate(current)
        local frame = widget.pullout and widget.pullout.frame or widget.dropdown
        if not frame or not frame:IsShown() then popup = nil; FocusControl(owner) end
      end
      return true
    end
    return false
  end
  if current.kind == "tree" then
    if key == "UP" or key == "DOWN" then MoveInGroup(key == "UP" and -1 or 1); return true end
    if key == "LEFT" or key == "RIGHT" then
      if current.widget and current.frame.toggle:IsShown() and not IsDisabled(current) then
        local groups = (current.widget.status or current.widget.localstatus).groups
        if (groups[current.frame.uniquevalue] == true) ~= (key == "RIGHT") then
          current.frame.toggle:Click("LeftButton")
          Navigation.QueueRestore()
        end
      end
      return true
    end
  elseif current.kind == "tabs" then
    if key == "LEFT" or key == "RIGHT" then MoveInGroup(key == "LEFT" and -1 or 1); return true end
  elseif current.kind == "slider" then
    if key == "LEFT" or key == "RIGHT" or key == "UP" or key == "DOWN" then
      if not IsDisabled(current) then
        local widget = current.widget
        local button = (key == "LEFT" or key == "DOWN") and widget.minusButton or widget.plusButton
        button:Click("LeftButton")
      end
      return true
    end
  end
  if key == "ENTER" or key == "SPACE" then
    if current.kind == "dropdown" then OpenPopup(current)
    elseif current.kind ~= "text" and current.kind ~= "slider" then Activate(current); Navigation.QueueRestore() end
    return true
  end
  return false
end

function Navigation.RefreshWindows()
  for root, state in pairs(windows) do
    local shown = root:IsVisible() and (root == activeWindow) and not InCombatLockdown()
    local text = GetCurrentKeyBoardFocus()
    state.receiver:SetShown(shown and not (text and BelongsTo(text, root))
      and not (current and current.widget and current.widget.waitingForKey == true)
      and (not state.enabled or state.enabled()))
  end
end

function Navigation.ActivateWindow(root)
  local state = windows[root]
  if not state or not root:IsVisible() or (state.enabled and not state.enabled()) then return end
  if activeWindow and activeWindow ~= root then
    state.previousWindow = activeWindow
    if current then windows[activeWindow].restoreKey = ControlKey(current) end
    HideFocus()
    current = nil
  end
  activeWindow = root
  Navigation.RefreshWindows()
end

function Navigation.BindWindow(root, movers, cancel, enabled)
  if windows[root] then return end
  if InCombatLockdown() then
    pendingWindows[root] = { movers = movers, cancel = cancel, enabled = enabled }
    return
  end
  pendingWindows[root] = nil
  local receiver = CreateFrame("Frame", nil, UIParent)
  receiver:SetAllPoints(root)
  receiver:SetFrameStrata("FULLSCREEN_DIALOG")
  receiver:SetFrameLevel(2000)
  receiver:EnableMouse(false)
  receiver:EnableKeyboard(true)
  receiver:SetPropagateKeyboardInput(true)
  receiver:Hide()
  local state = { receiver = receiver, movers = movers, cancel = cancel, enabled = enabled }
  windows[root] = state
  receiver:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then self:Hide(); return end
    self:SetPropagateKeyboardInput(not Navigation.HandleKey(key))
  end)
  receiver:SetScript("OnKeyUp", function(self)
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
  end)
  root:HookScript("OnShow", function() Navigation.ActivateWindow(root) end)
  root:HookScript("OnHide", function()
    if activeWindow == root then
      HideFocus()
      current, popup, state.active = nil, nil, false
      local previous = state.previousWindow
      activeWindow = previous and previous:IsVisible() and previous or nil
      state.previousWindow = nil
      Navigation.QueueRestore()
    end
    state.receiver:Hide()
    Navigation.RefreshWindows()
  end)
  Navigation.ActivateWindow(root)
end

function Navigation.QueueRestore()
  if restorePending then return end
  restorePending = true
  C_Timer.After(0, function()
    restorePending = nil
    local state = activeWindow and windows[activeWindow]
    if not state or not state.active or not activeWindow:IsVisible() or InCombatLockdown()
      or (state.enabled and not state.enabled()) then return end
    local key = state.restoreKey or (current and ControlKey(current))
    local list = Collect(activeWindow)
    for _, control in ipairs(list) do
      if key and ControlKey(control) == key then
        state.restoreKey = nil
        FocusControl(control)
        return
      end
    end
    if not current or not current.frame:IsVisible() then
      state.restoreKey = nil
      FocusControl(list[1])
    elseif current then DrawFocus(current) end
  end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    HideFocus()
    current, popup = nil, nil
    for _, state in pairs(windows) do state.receiver:Hide(); state.active = false end
  else
    for root, state in pairs(pendingWindows) do Navigation.BindWindow(root, state.movers, state.cancel, state.enabled) end
    Navigation.RefreshWindows()
  end
end)
