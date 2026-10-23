local _, ns = ...
local PUI_OptionsProfiler = select(1, ns.Pleebug:DropIn({}))

local Navigation = {}
ns.KeyboardNavigation = Navigation
local widgets = setmetatable({}, { __mode = "k" })
local controls = setmetatable({}, { __mode = "k" })
local windows = setmetatable({}, { __mode = "k" })
local current, activeWindow, popup, serial = nil, nil, nil, 0
local restorePending
local restoreGeneration = 0
local keyboardInput = false
local events = CreateFrame("Frame")
local pendingWindows = setmetatable({}, { __mode = "k" })
local MoveFocus, FocusControl, AdoptPopup

function Navigation.IsEnabled()
  return ns.Addon:GetOptionsDB().keyboardNavigation ~= false
end
Navigation.IsEnabled = PUI_OptionsProfiler:Def("Navigation.IsEnabled", Navigation.IsEnabled)


local function WindowNavigationEnabled(state)
  return (state.movers or Navigation.IsEnabled()) and (not state.enabled or state.enabled())
end
WindowNavigationEnabled = PUI_OptionsProfiler:Def("WindowNavigationEnabled", WindowNavigationEnabled)


local function BelongsTo(frame, root)
  while frame do
    if frame == root then return true end
    frame = frame:GetParent()
  end
  return false
end
BelongsTo = PUI_OptionsProfiler:Def("BelongsTo", BelongsTo)


local function ControlKey(control)
  local widget = control.widget
  if widget then
    local user = widget:GetUserDataTable()
    local path = user.path or {}
    local parts = {}
    for index, value in ipairs(path) do parts[index] = tostring(value) end
    local key = user.keyboardKey or (widget.__puiControl and widget.__puiControl.key)
      or (user.puiControlTooltip and user.puiControlTooltip.label)
      or (#parts > 0 and widget.type or control.serial)
    return table.concat(parts, "\001") .. "\002" .. tostring(key) .. "\002" .. control.part
  end
  local frame = control.frame
  return control.part .. "\002" .. tostring(frame.uniquevalue or frame.__puiValue or frame.__puiSectionKey or frame:GetName() or control.serial)
end
ControlKey = PUI_OptionsProfiler:Def("ControlKey", ControlKey)


local function IsDisabled(control)
  local frame, widget = control.frame, control.widget
  local kind = frame:GetObjectType()
  return (widget and widget.disabled == true) or frame.__puiDisabled == true
    or ((kind == "Button" or kind == "CheckButton" or kind == "Slider") and not frame:IsEnabled())
    or (frame.treeline and frame.treeline.disabled == true)
end
IsDisabled = PUI_OptionsProfiler:Def("IsDisabled", IsDisabled)


local function RunControlScript(frame, script, ...)
  local callback = frame:GetScript(script)
  if callback then callback(frame, ...) end
end
RunControlScript = PUI_OptionsProfiler:Def("RunControlScript", RunControlScript)


local function Activate(control)
  if IsDisabled(control) then return end
  local frame = control.frame
  if control.actions and control.actions.activate then
    control.actions.activate(frame)
  elseif control.mouseUp then
    RunControlScript(frame, "OnMouseUp", "LeftButton")
  else
    frame:Click("LeftButton")
  end
  Navigation.RefreshWindows()
end
Activate = PUI_OptionsProfiler:Def("Activate", Activate)


local function ScrollIntoView(frame)
  local parent = frame:GetParent()
  while parent do
    if parent:GetObjectType() == "ScrollFrame" then
      if parent.__puiKeyboardAutoScroll == false then return end
      local top, bottom = frame:GetTop(), frame:GetBottom()
      local viewportTop, viewportBottom = parent:GetTop(), parent:GetBottom()
      if top and bottom and viewportTop and viewportBottom then
        local offset = parent:GetVerticalScroll()
        if top > viewportTop then offset = offset - (top - viewportTop)
        elseif bottom < viewportBottom then offset = offset + viewportBottom - bottom end
        offset = math.max(0, math.min(parent:GetVerticalScrollRange(), offset))
        if offset ~= parent:GetVerticalScroll() then parent:SetVerticalScroll(offset) end
      end
    end
    parent = parent:GetParent()
  end
end
ScrollIntoView = PUI_OptionsProfiler:Def("ScrollIntoView", ScrollIntoView)


local function HideFocus()
  if not current then return end
  local frame = current.frame
  if current.actions and current.actions.blur then current.actions.blur(frame) end
  if frame.__puiKeyboardOutline then frame.__puiKeyboardOutline:Hide() end
  if current.widget then ns.AceHooks.HideDisabledTooltip(current.widget) end
end
HideFocus = PUI_OptionsProfiler:Def("HideFocus", HideFocus)


function Navigation.ClearKeyboardFocus()
  HideFocus()
  current, popup = nil, nil
  keyboardInput = false
  restoreGeneration = restoreGeneration + 1
  for _, state in pairs(windows) do
    state.active, state.restoreKey = false, nil
  end
  local state = activeWindow and windows[activeWindow]
  if state and state.keyHandler then state.keyHandler("GLOBAL_MOUSE_DOWN", false) end
  Navigation.RefreshWindows()
end
Navigation.ClearKeyboardFocus = PUI_OptionsProfiler:Def("Navigation.ClearKeyboardFocus", Navigation.ClearKeyboardFocus)


function Navigation.SetEnabled(enabled)
  ns.Addon:GetOptionsDB().keyboardNavigation = enabled == true
  if not enabled then
    for _, state in pairs(windows) do
      if not state.movers then state.helpShown = false end
    end
  end
  Navigation.ClearKeyboardFocus()
end
Navigation.SetEnabled = PUI_OptionsProfiler:Def("Navigation.SetEnabled", Navigation.SetEnabled)


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
  local palette = control.widget and control.widget.type == "PUI_PalettePreview" and control.widget.palette or nil
  local _, border = ns.Theme.GetControlStateColors(false, false, false, true, palette)
  outline:SetBackdropBorderColor(unpack(border))
  outline:SetFrameStrata(frame:GetFrameStrata())
  outline:SetFrameLevel(frame:GetFrameLevel() + 30)
  outline:Show()
end
DrawFocus = PUI_OptionsProfiler:Def("DrawFocus", DrawFocus)


local GUIDE_TEXT = {
  movers = "Tab Select mover · Arrows Move · 1-9 Step · F6 Controls",
  options = "Tab Next · Shift+Tab Previous · Enter/Space Activate",
  dropdown = "Up/Down Browse · Enter Select · Esc Cancel",
}
local HELP_TEXT = [[Moving between controls
Tab moves forward; Shift+Tab moves backward. Focus does not change a setting.
In options and setup, Ctrl+Tab jumps between navigation, tabs, previews, settings, and window controls. Hidden or empty areas are skipped. Ctrl+Shift+Tab jumps back. Up/Down browses lists; Enter opens a page. Opening a page with the keyboard moves focus into its content.

Trees and tabs
Up/Down browses tree entries. Left/Right expands or collapses tree branches, or browses tabs. Enter opens the focused page; Space also selects a tab.

Preview regions
Tab reaches clickable preview regions. Focus shows the region label and explanation; Enter or Space opens its settings.

Buttons and checkboxes
Enter or Space activates the focused control. Disabled controls stay read-only and show their dependency explanation.

Dropdowns
Enter or Space opens the list. Type in its search field to filter choices. Up/Down browses; Enter selects; Escape closes without selecting. Tab moves through the list and back to controls.

Sliders and text
Arrow keys adjust a focused slider. Tab reaches its minus button, numeric field and plus button. Enter commits numeric input; Escape restores it. In text fields, arrow keys move the caret.

Scrolling
Focus scrolls settings controls into view. The installer page list stays where you scroll it. Page Up/Down scrolls the focused control's containing area.

Leaving navigation
Escape closes a dropdown or cancels an edit first, then leaves keyboard navigation. Use the window's Close button or Escape afterward to close it. Clicking with the mouse clears navigation focus; Tab resumes it.

Keyboard Edit Mode
Tab and Shift+Tab cycle movers. Arrow keys move the selection; keys 1-9 choose the movement step. F6 switches between movers and toolbar controls. Ctrl+Z undoes; Ctrl+Y redoes outside text fields.

/pe uses your saved Mouse or Keyboard preference. /pek opens keyboard Edit Mode for this session. Change your preference with Keyboard movement in the toolbar.

Help
F1 or the Keyboard help button toggles this guide. While it is open, Tab switches between the guide and Close; Up/Down and Page Up/Down scroll the guide. Escape closes help first and returns to your control. Keyboard navigation pauses during combat.]]

local function GuideContext(state)
  if popup then return "dropdown" end
  if state.movers and not state.active then return "movers" end
  return "options"
end
GuideContext = PUI_OptionsProfiler:Def("GuideContext", GuideContext)


local function RefreshGuide(root, state)
  local guide = state.guide
  if not guide then return end
  local visible = root == activeWindow and root:IsVisible() and not InCombatLockdown()
    and (state.active or state.helpShown or (state.movers and ns.FrameUtil._keyboardMoveEnabled == true))
    and not (current and current.widget and current.widget.waitingForKey == true)
    and (not guide.settings.visible or guide.settings.visible())
  local height = 0
  if visible then
    local Theme = ns.Theme
    local colors = Theme.GetColors()
    local width = math.max(1, root:GetWidth() - 24)
    Theme.WidgetSkins.UIButton(guide.button)
    Navigation.RegisterFrame(guide.button, "help", "keyboardHelp")
    Theme.ApplyFont(guide.label, "body")
    guide.label:SetJustifyH("LEFT")
    guide.label:SetWordWrap(true)
    guide.label:SetWidth(math.max(1, width - 16))
    for _, text in pairs(GUIDE_TEXT) do
      guide.label:SetText("Keyboard help · F1  |  " .. text)
      height = math.max(height, guide.label:GetStringHeight() + 12)
    end
    height = math.max(height, Theme.GetOptionsPointerTargetSize(24))
    guide.label:SetText("Keyboard help · F1  |  " .. (guide.settings.text or GUIDE_TEXT[GuideContext(state)]))
    height = math.max(height, guide.label:GetStringHeight() + 12)
    guide.label:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.9)
    guide.button:SetSize(width, height)
  end
  guide.button:SetShown(visible)
  if guide.height ~= height or guide.bottom ~= guide.settings.bottom then
    guide.bottom = guide.settings.bottom
    guide.button:ClearAllPoints()
    guide.button:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 12, guide.bottom)
    guide.height = height
    guide.settings.layout(height)
  end
  for _, control in ipairs(guide.helpControls) do
    if control.frame.__puiKeyboardOutline then control.frame.__puiKeyboardOutline:Hide() end
  end
  if not state.helpShown then guide.overlay:Hide(); return end
  local Theme = ns.Theme
  local colors = Theme.GetColors()
  local help = guide.help
  guide.overlay:SetFrameLevel(math.max(root:GetFrameLevel() + 100, popup and popup.frame:GetFrameLevel() + 200 or 0))
  Theme.SetSquareBackdrop(help, { bg = colors.background, border = colors.controlBorder }, Theme.ControlBorderSize)
  Theme.ApplyFont(help.title, "header")
  Theme.ApplyFont(help.text, "body")
  help.title:SetTextColor(unpack(colors.text))
  help.text:SetTextColor(unpack(colors.text))
  Theme.WidgetSkins.UIButton(help.close)
  local width = math.max(1, root:GetWidth() - 24)
  help:SetWidth(width)
  help.text:SetWidth(math.max(1, width - 56))
  local titleHeight = help.title:GetStringHeight()
  local buttonHeight = math.max(24, Theme.GetOptionsPointerTargetSize(0), Theme.GetOptionsFontHeight("button") + 8)
  local available = math.max(1, root:GetHeight() - guide.settings.bottom - height - 20)
  help:SetHeight(math.min(available, titleHeight + help.text:GetStringHeight() + buttonHeight + 48))
  help.title:SetHeight(titleHeight)
  help.close:SetSize(width - 24, buttonHeight)
  help.scroll:ClearAllPoints()
  help.scroll:SetPoint("TOPLEFT", help, "TOPLEFT", 12, -titleHeight - 22)
  help.scroll:SetPoint("BOTTOMRIGHT", help.close, "TOPRIGHT", -22, 8)
  help.content:SetSize(width - 56, math.max(1, help.text:GetStringHeight()))
  help.scroll:UpdateScrollChildRect()
  Theme.WidgetSkins.Scrollbar(help.scroll.ScrollBar)
  help:ClearAllPoints()
  help:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 12, guide.settings.bottom + height + 8)
  guide.overlay:Show()
  if keyboardInput then DrawFocus(guide.helpControls[state.helpIndex]) end
end
RefreshGuide = PUI_OptionsProfiler:Def("RefreshGuide", RefreshGuide)


function Navigation.GetGuideHeight(root)
  local state = windows[root]
  return state and state.guide and state.guide.height or 0
end
Navigation.GetGuideHeight = PUI_OptionsProfiler:Def("Navigation.GetGuideHeight", Navigation.GetGuideHeight)


function Navigation.AttachGuide(root, settings)
  local state = windows[root] or pendingWindows[root]
  if state.guide then return end
  local button = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
  button:Hide()
  button.__puiOptionsFontRole = "body"
  button:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 12, settings.bottom)
  button:SetFrameLevel(root:GetFrameLevel() + 90)
  local label = button:GetFontString()
  label:ClearAllPoints()
  label:SetPoint("LEFT", button, "LEFT", 8, 0)
  label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
  button:SetScript("OnClick", PUI_OptionsProfiler:DefCallback("Navigation.AttachGuide > button.SetScript OnClick", function() Navigation.ToggleHelp(root) end))
  local overlay = CreateFrame("Frame", nil, root)
  overlay:Hide()
  overlay:SetAllPoints(UIParent)
  overlay:EnableMouse(true)
  overlay:SetFrameStrata("TOOLTIP")
  overlay:SetFrameLevel(root:GetFrameLevel() + 100)
  local help = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
  help:EnableMouse(true)
  help.title = help:CreateFontString(nil, "OVERLAY")
  ns.Theme.ApplyFont(help.title, "header")
  help.title:SetPoint("TOPLEFT", 12, -12)
  help.title:SetPoint("TOPRIGHT", -12, -12)
  help.title:SetJustifyH("LEFT")
  help.title:SetText("Keyboard help")
  help.close = CreateFrame("Button", nil, help, "UIPanelButtonTemplate")
  help.close.__puiKeyboardHelpAccessory = true
  help.close:SetText("Close help · F1 / Escape")
  help.close:SetPoint("BOTTOMLEFT", 12, 12)
  help.close:SetScript("OnClick", PUI_OptionsProfiler:DefCallback("Navigation.AttachGuide > help.close.SetScript OnClick", function() Navigation.ToggleHelp(root) end))
  help.scroll = CreateFrame("ScrollFrame", nil, help, "UIPanelScrollFrameTemplate")
  help.scroll:EnableMouseWheel(true)
  help.scroll:SetScript("OnMouseWheel", PUI_OptionsProfiler:DefCallback("Navigation.AttachGuide > help.scroll.SetScript OnMouseWheel", function(self, delta)
    self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 32)))
  end))
  help.content = CreateFrame("Frame", nil, help.scroll)
  help.scroll:SetScrollChild(help.content)
  help.text = help.content:CreateFontString(nil, "OVERLAY")
  ns.Theme.ApplyFont(help.text, "body")
  help.text:SetPoint("TOPLEFT")
  help.text:SetJustifyH("LEFT")
  help.text:SetWordWrap(true)
  help.text:SetText(HELP_TEXT)
  state.guide = { button = button, label = label, overlay = overlay, help = help,
    helpControls = { { frame = help.scroll }, { frame = help.close } }, height = 0, settings = settings }
  root:HookScript("OnSizeChanged", PUI_OptionsProfiler:DefCallback("Navigation.AttachGuide > root.HookScript OnSizeChanged", function() Navigation.RefreshWindows() end))
  Navigation.RefreshWindows()
end
Navigation.AttachGuide = PUI_OptionsProfiler:Def("Navigation.AttachGuide", Navigation.AttachGuide)


function Navigation.ToggleHelp(root)
  if InCombatLockdown() or root ~= activeWindow then return end
  local state = windows[root]
  if not state or not state.guide or (current and current.widget and current.widget.waitingForKey == true) then return end
  if not state.helpShown and state.guide.settings.prepare then state.guide.settings.prepare() end
  state.helpShown = not state.helpShown
  if state.helpShown then
    HideFocus()
    state.helpIndex = 1
    state.guide.help.scroll:SetVerticalScroll(0)
  elseif current and current.frame:IsVisible() then
    DrawFocus(current)
  end
  Navigation.RefreshWindows()
  if not state.helpShown then Navigation.QueueRestore() end
end
Navigation.ToggleHelp = PUI_OptionsProfiler:Def("Navigation.ToggleHelp", Navigation.ToggleHelp)


local function HookTextInput(frame)
  if frame.__puiKeyboardTextHooked then return end
  frame.__puiKeyboardTextHooked = true
  local tab = frame:GetScript("OnTabPressed")
  frame:SetScript("OnTabPressed", PUI_OptionsProfiler:DefCallback("HookTextInput > frame.SetScript OnTabPressed", function(self)
    local control = controls[self]
    local state = activeWindow and windows[activeWindow]
    if control and state and (BelongsTo(self, activeWindow) or (popup and BelongsTo(self, popup.frame)))
      and not InCombatLockdown()
      and WindowNavigationEnabled(state) then
      Navigation.HandleKey("TAB")
    elseif tab then
      tab(self)
    end
  end))
  frame:HookScript("OnEditFocusGained", PUI_OptionsProfiler:DefCallback("HookTextInput > frame.HookScript OnEditFocusGained", function(self)
    local control = controls[self]
    local state = activeWindow and windows[activeWindow]
    if not control or not state or not (BelongsTo(self, activeWindow) or (popup and BelongsTo(self, popup.frame)))
      or InCombatLockdown() or not WindowNavigationEnabled(state) then return end
    if not state.active then Navigation.RefreshWindows(); return end
    HideFocus()
    current = control
    windows[activeWindow].active = true
    DrawFocus(control)
    Navigation.RefreshWindows()
  end))
  frame:HookScript("OnEscapePressed", PUI_OptionsProfiler:DefCallback("HookTextInput > frame.HookScript OnEscapePressed", function(self)
    if controls[self] and self:HasFocus() then self:ClearFocus() end
  end))
  frame:HookScript("OnKeyDown", PUI_OptionsProfiler:DefCallback("HookTextInput > frame.HookScript OnKeyDown", function(self, key)
    local popupSearch = popup and current and current.frame == self and BelongsTo(self, popup.frame)
    if (key == "F6" or key == "F1" or (popupSearch and (key == "UP" or key == "DOWN" or key == "PAGEUP" or key == "PAGEDOWN")))
      and controls[self] and activeWindow
      and (BelongsTo(self, activeWindow) or popupSearch) then
      Navigation.HandleKey(key)
    end
  end))
  frame:HookScript("OnEditFocusLost", PUI_OptionsProfiler:DefCallback("HookTextInput > frame.HookScript OnEditFocusLost", function() Navigation.RefreshWindows() end))
end
HookTextInput = PUI_OptionsProfiler:Def("HookTextInput", HookTextInput)


function Navigation.RegisterFrame(frame, kind, part, group, widget, mouseUp, actions)
  local control = controls[frame]
  if not control then
    serial = serial + 1
    control = { frame = frame, serial = serial }
    controls[frame] = control
  end
  if control.widget and control.widget ~= widget then
    control.widget.__puiKeyboardControls[frame] = nil
  end
  if widget then
    local ownedControls = widget.__puiKeyboardControls
    if not ownedControls then
      ownedControls = {}
      widget.__puiKeyboardControls = ownedControls
    end
    ownedControls[frame] = true
  end
  if not frame.__puiKeyboardHideHooked then
    frame.__puiKeyboardHideHooked = true
    frame:HookScript("OnHide", PUI_OptionsProfiler:DefCallback("Navigation.RegisterFrame > frame.HookScript OnHide", function(self)
      if current and current.frame == self then
        local state = activeWindow and windows[activeWindow]
        if state and state.active then state.restoreKey = ControlKey(current) end
        HideFocus()
        current = nil
      end
    end))
  end
  control.kind, control.part, control.group, control.widget, control.mouseUp, control.actions = kind, part, group, widget, mouseUp, actions
  if kind == "text" then HookTextInput(frame) end
  if kind == "dropdown" and not frame.__puiKeyboardDropdownHooked then
    frame.__puiKeyboardDropdownHooked = true
    frame:HookScript("OnClick", PUI_OptionsProfiler:DefCallback("Navigation.RegisterFrame > frame.HookScript OnClick", function(self)
      local entry = controls[self]
      local state = activeWindow and windows[activeWindow]
      if entry and entry.kind == "dropdown" and state and state.active and not state.helpShown
        and BelongsTo(self, activeWindow) and not InCombatLockdown()
        and entry.widget.__puiAceGUIOwnedByPleebUI == true
        and WindowNavigationEnabled(state) then
        AdoptPopup(entry)
      end
    end))
  end
  return control
end
Navigation.RegisterFrame = PUI_OptionsProfiler:Def("Navigation.RegisterFrame", Navigation.RegisterFrame)


function Navigation.UnregisterFrame(frame)
  local control = controls[frame]
  if not control then return end
  if current == control then
    local state = activeWindow and windows[activeWindow]
    if state and state.active then state.restoreKey = ControlKey(control) end
    HideFocus()
    current = nil
  end
  if control.kind == "text" and frame:HasFocus() then frame:ClearFocus() end
  if control.widget then control.widget.__puiKeyboardControls[frame] = nil end
  controls[frame] = nil
  Navigation.QueueRestore()
end
Navigation.UnregisterFrame = PUI_OptionsProfiler:Def("Navigation.UnregisterFrame", Navigation.UnregisterFrame)


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
  elseif kind == "PUI_Dropdown" or kind == "PUI_FontDropdown" or kind == "Dropdown" then
    Navigation.RegisterFrame(widget.button_cover or widget.button, "dropdown", "dropdown", nil, widget)
  elseif kind:sub(1, 6) == "LSM30_" then
    Navigation.RegisterFrame(widget.frame.dropButton, "dropdown", "dropdown", nil, widget)
  elseif kind == "PUI_PalettePreview" then
    Navigation.RegisterFrame(widget.checked, "button", "sampleChecked", nil, widget)
    Navigation.RegisterFrame(widget.unchecked, "button", "sampleUnchecked", nil, widget)
    Navigation.RegisterFrame(widget.dropdown, "dropdown", "sampleDropdown", nil, widget, nil, {
      popup = { frame = widget.menu, rows = widget.menuItems },
    })
    Navigation.RegisterFrame(widget.focusInput, "text", "sampleInput", nil, widget)
    Navigation.RegisterFrame(widget.number, "text", "sampleNumber", nil, widget)
    Navigation.RegisterFrame(widget.slider, "slider", "sampleSlider", nil, widget, nil, {
      adjust = PUI_OptionsProfiler:DefCallback("Navigation.RegisterWidget > adjust", function(direction)
        widget.slider:SetValue(math.max(0, math.min(100, widget.slider:GetValue() + direction)))
      end),
    })
    Navigation.RegisterFrame(widget.enabled, "button", "sampleReset", nil, widget)
    Navigation.RegisterFrame(widget.disabled, "button", "sampleDisabled", nil, widget)
  elseif kind == "ColorPicker" then
    Navigation.RegisterFrame(widget.frame, "button", "color", nil, widget)
  end
  if kind == "Keybinding" and not widget.button.__puiKeyboardBindingHooked then
    local button = widget.button
    button.__puiKeyboardBindingHooked = true
    for _, script in ipairs({ "OnKeyDown", "OnClick", "OnMouseDown", "OnMouseWheel", "OnGamePadButtonDown" }) do
      button:HookScript(script, PUI_OptionsProfiler:DefCallback("Navigation.RegisterWidget > button.HookScript", function() Navigation.RefreshWindows() end))
    end
    button:HookScript("OnHide", PUI_OptionsProfiler:DefCallback("Navigation.RegisterWidget > button.HookScript OnHide", function()
      if widget.waitingForKey then
        RunControlScript(button, "OnClick", "LeftButton")
        Navigation.RefreshWindows()
      end
    end))
  end
end
Navigation.RegisterWidget = PUI_OptionsProfiler:Def("Navigation.RegisterWidget", Navigation.RegisterWidget)


function Navigation.ReleaseWidget(widget)
  widgets[widget] = nil
  local ownedControls = widget.__puiKeyboardControls
  if ownedControls then
    for frame in pairs(ownedControls) do
      Navigation.UnregisterFrame(frame)
    end
    widget.__puiKeyboardControls = nil
  end
  if popup and popup.widget == widget then popup = nil end
  Navigation.QueueRestore()
end
Navigation.ReleaseWidget = PUI_OptionsProfiler:Def("Navigation.ReleaseWidget", Navigation.ReleaseWidget)


local function ControlRegion(control, regions)
  local frame = control.frame
  while frame do
    for index, region in ipairs(regions) do
      if frame == region then return index end
    end
    frame = frame:GetParent()
  end
  return #regions + 1
end
ControlRegion = PUI_OptionsProfiler:Def("ControlRegion", ControlRegion)


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
  local regions = windows[root].regions
  for frame, control in pairs(controls) do
    if frame:IsVisible() and BelongsTo(frame, root)
      and control.kind ~= "popup"
      and not frame.__puiKeyboardHelpAccessory
      and not (frame.__puiNode and frame.__puiNode.meta.navHeader == true)
      and (not control.widget or control.widget.__puiAceGUIOwnedByPleebUI == true)
    then
      local row = control.widget and control.widget.type ~= "PUI_PalettePreview"
        and control.kind ~= "tree" and control.kind ~= "tabs" and control.widget.frame or frame
      local top, left = row:GetTop(), frame:GetLeft()
      if top and left then
        control.top, control.left = math.floor(top + 0.5), left
        control.region = regions and ControlRegion(control, regions) or 1
        result[#result + 1] = control
      end
    end
  end
  table.sort(result, PUI_OptionsProfiler:DefCallback("Collect > table.sort", function(a, b)
    if a.region ~= b.region then return a.region < b.region end
    if a.top ~= b.top then return a.top > b.top end
    if a.left ~= b.left then return a.left < b.left end
    return a.serial < b.serial
  end))
  return result
end
Collect = PUI_OptionsProfiler:Def("Collect", Collect)


function Navigation.FocusWidget(widget)
  local state = activeWindow and windows[activeWindow]
  if not state or not state.active or state.helpShown or InCombatLockdown()
    or not WindowNavigationEnabled(state) then return end
  for _, control in ipairs(Collect(activeWindow)) do
    if control.widget == widget then
      state.restoreKey = nil
      FocusControl(control)
      return
    end
  end
end
Navigation.FocusWidget = PUI_OptionsProfiler:Def("Navigation.FocusWidget", Navigation.FocusWidget)


FocusControl = PUI_OptionsProfiler:Def("FocusControl", function(control)
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
  DrawFocus(control)
  if IsDisabled(control) then
    if control.widget then ns.AceHooks.ShowDisabledTooltip(control.widget) end
  elseif control.kind == "text" and not control.frame:HasFocus() then
    control.frame:SetFocus()
  end
  if not IsDisabled(control) and control.actions and control.actions.focus then control.actions.focus(control.frame) end
  Navigation.RefreshWindows()
  if current == control and windows[activeWindow].active and not windows[activeWindow].helpShown then
    ScrollIntoView(control.frame)
  end
end)

function Navigation.SetRegions(root, regions)
  (windows[root] or pendingWindows[root]).regions = regions
end
Navigation.SetRegions = PUI_OptionsProfiler:Def("Navigation.SetRegions", Navigation.SetRegions)


function Navigation.FocusRegion(root, index)
  local state = windows[root]
  if root ~= activeWindow or not state or not state.active or state.helpShown
    or InCombatLockdown() or not WindowNavigationEnabled(state) then return false end
  for _, control in ipairs(Collect(root)) do
    if control.region == index then
      state.restoreKey = nil
      restoreGeneration = restoreGeneration + 1
      FocusControl(control)
      return true
    end
  end
  return false
end
Navigation.FocusRegion = PUI_OptionsProfiler:Def("Navigation.FocusRegion", Navigation.FocusRegion)


function Navigation.QueueFocusRegion(root, index)
  local state = windows[root]
  if root ~= activeWindow or not state or not state.active or state.helpShown
    or InCombatLockdown() or not WindowNavigationEnabled(state) then return end
  local request = {}
  local generation = restoreGeneration
  state.pendingRegionFocus = request
  C_Timer.After(0, PUI_OptionsProfiler:DefCallback("Navigation.QueueFocusRegion > C_Timer.After", function()
    if state.pendingRegionFocus ~= request then return end
    state.pendingRegionFocus = nil
    if generation ~= restoreGeneration then return end
    Navigation.FocusRegion(root, index)
  end))
end
Navigation.QueueFocusRegion = PUI_OptionsProfiler:Def("Navigation.QueueFocusRegion", Navigation.QueueFocusRegion)


MoveFocus = PUI_OptionsProfiler:Def("MoveFocus", function(direction)
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
end)

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
  if widget.__puiBlizzardTree and widget.__puiTreeViewport then
    local step = widget.__puiTreeSmoothStep
    if step then
      local top = (index - 1) * step
      local bottom = top + step - ns.Theme.GetControlMetrics().treeButtonGap
      local scroll = (widget.__puiTreeSmoothScroll or 0) * step
      if top < scroll then
        widget.scrollbar:SetValue(top / step)
      elseif bottom > scroll + widget.__puiTreeViewport:GetHeight() then
        widget.scrollbar:SetValue((bottom - widget.__puiTreeViewport:GetHeight()) / step)
      end
    end
  elseif not visible then
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
FocusTreeLine = PUI_OptionsProfiler:Def("FocusTreeLine", FocusTreeLine)


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
MoveInGroup = PUI_OptionsProfiler:Def("MoveInGroup", MoveInGroup)


local function ClosePopup()
  if not popup then return false end
  local owner, widget = popup.owner, popup.widget
  popup = nil
  widget:ClearFocus()
  FocusControl(owner)
  return true
end
ClosePopup = PUI_OptionsProfiler:Def("ClosePopup", ClosePopup)


local function PopupRows()
  local rows = {}
  local widget = popup.widget
  if popup.rows then
    for _, row in ipairs(popup.rows) do
      if row:IsVisible() and row:IsEnabled() then rows[#rows + 1] = row end
    end
  elseif widget.pullout then
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
PopupRows = PUI_OptionsProfiler:Def("PopupRows", PopupRows)


local function MoveInPopup(direction)
  local rows = PopupRows()
  if #rows == 0 then return end
  local index = direction > 0 and 0 or 1
  for i, row in ipairs(rows) do if current and current.frame == row then index = i; break end end
  local row = rows[(index - 1 + direction) % #rows + 1]
  local control = Navigation.RegisterFrame(row, "popup", "popup", nil, popup.widget)
  FocusControl(control)
end
MoveInPopup = PUI_OptionsProfiler:Def("MoveInPopup", MoveInPopup)


AdoptPopup = PUI_OptionsProfiler:Def("AdoptPopup", function(control)
  local widget = control.widget
  local custom = control.actions and control.actions.popup
  local frame = custom and custom.frame or (widget.pullout and widget.pullout.frame or widget.dropdown)
  if not frame or not frame:IsShown() then return end
  popup = { widget = widget, owner = control, frame = frame, rows = custom and custom.rows }
  if not frame.__puiKeyboardPopupHooked then
    frame.__puiKeyboardPopupHooked = true
    frame:HookScript("OnHide", PUI_OptionsProfiler:DefCallback("AdoptPopup > frame.HookScript OnHide", function(self)
      if popup and popup.frame == self then
        local owner = popup.owner
        popup = nil
        FocusControl(owner)
      end
    end))
  end
  local search = widget.pullout and widget.pullout.__puiDropdownSearchBox or frame.__puiLSMFontSearchBox
  if search and search:IsShown() then
    local entry = Navigation.RegisterFrame(search, "text", "popupSearch", nil, widget)
    FocusControl(entry)
  else
    MoveInPopup(1)
  end
end)

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
ScrollPage = PUI_OptionsProfiler:Def("ScrollPage", ScrollPage)


function Navigation.HandleKey(key, autoFocus)
  if not activeWindow or InCombatLockdown() then return false end
  if autoFocus and not keyboardInput then return false end
  local state = windows[activeWindow]
  if not WindowNavigationEnabled(state) and not state.helpShown then return false end
  local text = GetCurrentKeyBoardFocus()
  if text and not BelongsTo(text, activeWindow) and not (popup and current and current.frame == text) then return false end
  if key == "TAB" or key == "F1" or (key == "F6" and (state.movers or state.keyHandler)) then keyboardInput = true end
  if key == "F1" and state.guide then Navigation.ToggleHelp(activeWindow); return true end
  if state.helpShown then
    if key == "ESCAPE" or ((key == "ENTER" or key == "SPACE") and state.helpIndex == 2) then Navigation.ToggleHelp(activeWindow)
    elseif key == "TAB" then
      state.helpIndex = (state.helpIndex - 1 + (IsShiftKeyDown() and -1 or 1)) % #state.guide.helpControls + 1
      Navigation.RefreshWindows()
    elseif key == "UP" or key == "DOWN" or key == "PAGEUP" or key == "PAGEDOWN" then
      local scroll = state.guide.help.scroll
      local step = (key == "PAGEUP" or key == "PAGEDOWN") and scroll:GetHeight() * 0.8 or 32
      local direction = (key == "UP" or key == "PAGEUP") and -1 or 1
      scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll() + direction * step)))
    end
    return true
  end
  if state.keyHandler and not text and not popup and state.keyHandler(key, keyboardInput) then
    if key == "F6" then
      HideFocus()
      current, state.active, state.restoreKey = nil, false, nil
      Navigation.RefreshWindows()
    end
    return true
  end
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
  if key == "TAB" and IsControlKeyDown() and state.regions and not popup then
    state.active = true
    local direction = IsShiftKeyDown() and -1 or 1
    local index = current and ControlRegion(current, state.regions) or (direction > 0 and 0 or 1)
    for step = 1, #state.regions do
      if Navigation.FocusRegion(activeWindow, (index - 1 + direction * step) % #state.regions + 1) then return true end
    end
    return true
  end
  if key == "TAB" then
    if not state.active and text and controls[text] then current = controls[text] end
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
        local owner, frame = popup.owner, popup.frame
        Activate(current)
        if not frame or not frame:IsShown() then popup = nil; FocusControl(owner) end
      end
      return true
    end
    return false
  end
  if current.kind == "list" then
    if key == "UP" or key == "DOWN" then MoveInGroup(key == "UP" and -1 or 1); return true end
  elseif current.kind == "tree" then
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
        local direction = (key == "LEFT" or key == "DOWN") and -1 or 1
        if current.actions and current.actions.adjust then
          current.actions.adjust(direction)
        else
          local widget = current.widget
          local button = direction == -1 and widget.minusButton or widget.plusButton
          button:Click("LeftButton")
        end
      end
      return true
    end
  end
  if key == "ENTER" or key == "SPACE" then
    if current.kind == "dropdown" then Activate(current)
    elseif current.kind ~= "text" and current.kind ~= "slider" then Activate(current); Navigation.QueueRestore() end
    return true
  end
  return false
end
Navigation.HandleKey = PUI_OptionsProfiler:Def("Navigation.HandleKey", Navigation.HandleKey)


function Navigation.RefreshWindows()
  local activeState = activeWindow and windows[activeWindow]
  if activeState and not WindowNavigationEnabled(activeState) and (current or activeState.active) then
    HideFocus()
    current, popup = nil, nil
    activeState.active, activeState.restoreKey = false, nil
    restoreGeneration = restoreGeneration + 1
    if not Navigation.IsEnabled() then keyboardInput = false end
  end
  if activeState and WindowNavigationEnabled(activeState) and activeWindow:IsVisible() and not InCombatLockdown() then
    events:RegisterEvent("GLOBAL_MOUSE_DOWN")
  else
    events:UnregisterEvent("GLOBAL_MOUSE_DOWN")
  end
  for root, state in pairs(windows) do
    local shown = root:IsVisible() and (root == activeWindow) and not InCombatLockdown()
    local text = GetCurrentKeyBoardFocus()
    RefreshGuide(root, state)
    state.receiver:SetFrameStrata(state.helpShown and "TOOLTIP" or "FULLSCREEN_DIALOG")
    state.receiver:SetFrameLevel(state.helpShown and state.guide.overlay:GetFrameLevel() + 200 or 2000)
    state.receiver:SetShown(shown and (state.helpShown or not (text and (BelongsTo(text, root)
      or (popup and BelongsTo(text, popup.frame)))))
      and not (current and current.widget and current.widget.waitingForKey == true)
      and (state.helpShown or WindowNavigationEnabled(state)))
  end
end
Navigation.RefreshWindows = PUI_OptionsProfiler:Def("Navigation.RefreshWindows", Navigation.RefreshWindows)


function Navigation.ActivateWindow(root)
  local state = windows[root]
  if not state or not root:IsVisible() then return end
  if activeWindow and activeWindow ~= root then
    state.previousWindow = activeWindow
    if current then windows[activeWindow].restoreKey = ControlKey(current) end
    HideFocus()
    windows[activeWindow].helpShown = false
    current = nil
  end
  activeWindow = root
  Navigation.RefreshWindows()
end
Navigation.ActivateWindow = PUI_OptionsProfiler:Def("Navigation.ActivateWindow", Navigation.ActivateWindow)


function Navigation.BindWindow(root, movers, cancel, enabled, keyHandler)
  if windows[root] then return end
  if InCombatLockdown() then
    pendingWindows[root] = { movers = movers, cancel = cancel, enabled = enabled, keyHandler = keyHandler }
    return
  end
  local pending = pendingWindows[root]
  pendingWindows[root] = nil
  local receiver = CreateFrame("Frame", nil, UIParent)
  receiver:SetAllPoints(root)
  receiver:SetFrameStrata("FULLSCREEN_DIALOG")
  receiver:SetFrameLevel(2000)
  receiver:EnableMouse(false)
  receiver:EnableKeyboard(true)
  receiver:SetPropagateKeyboardInput(true)
  receiver:Hide()
  local state = { receiver = receiver, movers = movers, cancel = cancel, enabled = enabled,
    keyHandler = keyHandler, guide = pending and pending.guide, regions = pending and pending.regions }
  windows[root] = state
  receiver:SetScript("OnKeyDown", PUI_OptionsProfiler:DefCallback("Navigation.BindWindow > receiver.SetScript OnKeyDown", function(self, key)
    if InCombatLockdown() then self:Hide(); return end
    if state.helpShown then self:SetPropagateKeyboardInput(false) end
    self:SetPropagateKeyboardInput(not Navigation.HandleKey(key))
  end))
  receiver:SetScript("OnKeyUp", PUI_OptionsProfiler:DefCallback("Navigation.BindWindow > receiver.SetScript OnKeyUp", function(self)
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
  end))
  root:HookScript("OnShow", PUI_OptionsProfiler:DefCallback("Navigation.BindWindow > root.HookScript OnShow", function() Navigation.ActivateWindow(root) end))
  root:HookScript("OnHide", PUI_OptionsProfiler:DefCallback("Navigation.BindWindow > root.HookScript OnHide", function()
    state.pendingRegionFocus = nil
    if activeWindow == root then
      HideFocus()
      current, popup, state.active, state.restoreKey = nil, nil, false, nil
      local previous = state.previousWindow
      activeWindow = previous and previous:IsVisible() and previous or nil
      state.previousWindow = nil
      Navigation.QueueRestore()
    end
    state.helpShown = false
    state.receiver:Hide()
    Navigation.RefreshWindows()
  end))
  Navigation.ActivateWindow(root)
end
Navigation.BindWindow = PUI_OptionsProfiler:Def("Navigation.BindWindow", Navigation.BindWindow)


function Navigation.QueueRestore()
  local state = activeWindow and windows[activeWindow]
  if not state or not state.active or not WindowNavigationEnabled(state) then return end
  if restorePending then return end
  restorePending = true
  local generation = restoreGeneration
  C_Timer.After(0, PUI_OptionsProfiler:DefCallback("Navigation.QueueRestore > C_Timer.After", function()
    restorePending = nil
    if generation ~= restoreGeneration then return end
    local state = activeWindow and windows[activeWindow]
    if not state or not state.active or state.helpShown or not activeWindow:IsVisible() or InCombatLockdown()
      or not WindowNavigationEnabled(state) then return end
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
  end))
end
Navigation.QueueRestore = PUI_OptionsProfiler:Def("Navigation.QueueRestore", Navigation.QueueRestore)


events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", PUI_OptionsProfiler:Def("events.SetScript OnEvent", function(_, event)
  if event == "GLOBAL_MOUSE_DOWN" then
    Navigation.ClearKeyboardFocus()
  elseif event == "PLAYER_REGEN_DISABLED" then
    events:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    keyboardInput = false
    restoreGeneration = restoreGeneration + 1
    HideFocus()
    current, popup = nil, nil
    for root, state in pairs(windows) do
      state.receiver:Hide()
      state.active, state.helpShown, state.restoreKey = false, false, nil
      RefreshGuide(root, state)
    end
  else
    for root, state in pairs(pendingWindows) do Navigation.BindWindow(root, state.movers, state.cancel, state.enabled, state.keyHandler) end
    Navigation.RefreshWindows()
  end
end))
