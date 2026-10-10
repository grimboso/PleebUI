local _, ns = ...

local Theme = ns.Theme
local AceGUI = LibStub("AceGUI-3.0")
local TYPE = "PUI_PalettePreview"
local WHITE8 = "Interface\\Buttons\\WHITE8x8"

local function SampleText(parent, text, role)
  local label = parent:CreateFontString(nil, "OVERLAY")
  label.__puiOptionsFontOwned = true
  label:SetText(text)
  label:SetJustifyH("LEFT")
  Theme.ApplyFont(label, role)
  return label
end

local function StyleSampleControl(control)
  local widget = control.preview
  local disabled = control.sampleDisabled == true
  local fill, border, text = Theme.GetControlStateColors(
    disabled, control.hovered == true, control.pressed == true,
    control.focusExample == true or control.focused == true or control.open == true, widget.palette
  )
  Theme.SetSquareBackdrop(control.box or control, { bg = fill, border = border }, Theme.ControlBorderSize)
  if control.label then control.label:SetTextColor(unpack(text)) end
  if control:GetObjectType() == "EditBox" then control:SetTextColor(unpack(text)) end
  if control.mark then
    control.mark:SetVertexColor(unpack(widget.palette.accent))
    control.mark:SetShown(control:GetChecked())
  end
  if control.arrow then control.arrow:SetVertexColor(unpack(widget.palette.accent)) end
end

local function SampleControl(widget, kind)
  local control = CreateFrame(kind, nil, widget.panel)
  control.__puiUseTextureBackdrop = true
  control.preview = widget
  widget.controls[#widget.controls + 1] = control
  control:SetScript("OnEnter", function(self)
    self.hovered = true
    StyleSampleControl(self)
  end)
  control:SetScript("OnLeave", function(self)
    self.hovered, self.pressed = nil, nil
    StyleSampleControl(self)
  end)
  control:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then self.pressed = true; StyleSampleControl(self) end
  end)
  control:SetScript("OnMouseUp", function(self)
    self.pressed = nil
    StyleSampleControl(self)
  end)
  return control
end

local function LayoutSample(widget)
  local width = math.max(1, widget.frame:GetWidth() - 24)
  local height = math.max(Theme.GetControlMetrics().controlHeight, Theme.GetOptionsFontHeight("button") + 4, Theme.GetOptionsFontHeight("checkbox") + 4)
  local gap = 12
  local columns = width >= math.max(420, Theme.GetOptionsFontHeight("body") * 22) and 2 or 1
  local cellWidth = (width - (columns - 1) * gap) / columns
  local y = 12
  local function TextRow(label, role)
    Theme.ApplyFont(label, role)
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", widget.panel, "TOPLEFT", 12, -y)
    label:SetWidth(width)
    label:SetWordWrap(true)
    local textHeight = math.max(Theme.GetOptionsFontHeight(role), label:GetStringHeight())
    label:SetHeight(textHeight)
    y = y + textHeight + gap
  end
  TextRow(widget.title, "header")
  TextRow(widget.secondary, "tiny")
  local function Row(controls)
    for index, control in ipairs(controls) do
      local column = (index - 1) % columns
      local row = math.floor((index - 1) / columns)
      control:ClearAllPoints()
      control:SetPoint("TOPLEFT", widget.panel, "TOPLEFT", 12 + column * (cellWidth + gap), -y - row * (height + gap))
      control:SetSize(cellWidth, height)
      if control.box then control.box:SetSize(height, height) end
    end
    y = y + math.ceil(#controls / columns) * (height + gap)
  end
  Row({ widget.checked, widget.unchecked })
  Row({ widget.dropdown, widget.focusInput })
  widget.slider:ClearAllPoints()
  widget.slider:SetPoint("TOPLEFT", widget.panel, "TOPLEFT", 12, -y)
  local numberWidth = math.min(width * 0.4, math.max(74, Theme.GetOptionsFontHeight("body") * 4 + 10))
  widget.slider:SetSize(math.max(1, width - numberWidth - gap), height)
  widget.slider:GetThumbTexture():SetSize(12, height - 2)
  widget.number:ClearAllPoints()
  widget.number:SetPoint("TOPRIGHT", widget.panel, "TOPRIGHT", -12, -y)
  widget.number:SetSize(numberWidth, height)
  y = y + height + gap
  Row({ widget.enabled, widget.disabled })
  widget.menu:ClearAllPoints()
  widget.menu:SetPoint("TOPLEFT", widget.dropdown, "BOTTOMLEFT", 0, -4)
  widget.menu:SetWidth(cellWidth)
  widget.menu:SetHeight(height * 2 + 8)
  for index, item in ipairs(widget.menuItems) do
    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", widget.menu, "TOPLEFT", 4, -4 - (index - 1) * height)
    item:SetSize(math.max(1, cellWidth - 8), height)
  end
  widget:SetHeight(y)
end

local methods = {
  OnAcquire = function(self)
    self.preset = "default"
    self.palette = Theme.GetColorPresetPreviewColors(self.preset)
    self.checked:SetChecked(true)
    self.unchecked:SetChecked(false)
    self.dropdown.label:SetText("Sample option 1")
    self.focusInput:SetText("Focused input example")
    self.slider:SetValue(50)
    self.number:SetText("50")
    self:SetFullWidth(true)
    self.panel:Show()
    self:RefreshTheme()
  end,
  OnRelease = function(self)
    self.number:ClearFocus()
    self.focusInput:ClearFocus()
    self.menu:Hide()
    self.dropdown.open = nil
    for _, control in ipairs(self.controls) do
      control.hovered, control.pressed, control.focused = nil, nil, nil
    end
  end,
  OnWidthSet = LayoutSample,
  SetText = function(self, key)
    self.preset = key
    self.palette = Theme.GetColorPresetPreviewColors(key)
    self:RefreshTheme()
  end,
  SetFontObject = function(self, fontObject)
    self.title:SetFontObject(fontObject)
    self:RefreshTheme()
  end,
  RefreshTheme = function(self)
    local colors = self.palette
    -- An opaque matte keeps the unapplied palette independent of the current window colors.
    Theme.SetSquareBackdrop(self.panel, {
      bg = { colors.background[1], colors.background[2], colors.background[3], 1 }, border = colors.border,
    }, Theme.ControlBorderSize)
    Theme.SetSquareBackdrop(self.menu, { bg = colors.background, border = colors.controlBorder }, Theme.ControlBorderSize)
    self.title:SetText(Theme.GetColorPresetLabel(self.preset) .. " preview")
    self.title:SetTextColor(unpack(colors.text))
    self.secondary:SetTextColor(unpack(colors.mutedText))
    for _, control in ipairs(self.controls) do
      if control.label then Theme.ApplyFont(control.label, control.fontRole or "body") end
      if control:GetObjectType() == "EditBox" then Theme.ApplyFont(control, "body") end
      StyleSampleControl(control)
    end
    self.slider:GetThumbTexture():SetVertexColor(unpack(colors.accent))
    LayoutSample(self)
  end,
}

local function Constructor()
  local frame = CreateFrame("Frame", nil, UIParent)
  local panel = CreateFrame("Frame", nil, frame)
  panel.__puiUseTextureBackdrop = true
  panel:SetAllPoints(frame)
  Theme.MarkCreatedWidgetChrome(panel)
  local widget = { type = TYPE, frame = frame, panel = panel, controls = {}, menuItems = {}, palette = Theme.GetColorPresetPreviewColors("default"), preset = "default" }
  for key, method in pairs(methods) do widget[key] = method end
  frame.obj = widget
  widget.title = SampleText(panel, "", "header")
  widget.secondary = SampleText(panel, "Try the controls. Only Apply changes your settings.", "tiny")

  local function Checkbox(label, checked)
    local control = SampleControl(widget, "CheckButton")
    control:SetChecked(checked)
    control.box = CreateFrame("Frame", nil, control)
    control.box.__puiUseTextureBackdrop = true
    control.box:SetPoint("LEFT")
    control.mark = control.box:CreateTexture(nil, "ARTWORK")
    control.mark:SetTexture(WHITE8)
    control.mark:SetPoint("TOPLEFT", 4, -4)
    control.mark:SetPoint("BOTTOMRIGHT", -4, 4)
    control.fontRole = "checkbox"
    control.label = SampleText(control, label, control.fontRole)
    control.label:SetPoint("LEFT", control.box, "RIGHT", 6, 0)
    control.label:SetPoint("RIGHT", -4, 0)
    control:SetScript("OnClick", StyleSampleControl)
    return control
  end
  widget.checked = Checkbox("Checked", true)
  widget.unchecked = Checkbox("Unchecked", false)

  local function Button(text, role)
    local control = SampleControl(widget, "Button")
    control.fontRole = role or "button"
    control.label = SampleText(control, text, control.fontRole)
    control.label:SetPoint("LEFT", 8, 0)
    control.label:SetPoint("RIGHT", -8, 0)
    control.label:SetJustifyH("CENTER")
    return control
  end
  widget.dropdown = Button("Sample option 1", "body")
  widget.dropdown.label:SetJustifyH("LEFT")
  widget.dropdown.label:ClearAllPoints()
  widget.dropdown.label:SetPoint("LEFT", 8, 0)
  widget.dropdown.label:SetPoint("RIGHT", -24, 0)
  widget.dropdown.arrow = widget.dropdown:CreateTexture(nil, "ARTWORK")
  widget.dropdown.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
  widget.dropdown.arrow:SetPoint("RIGHT", -4, 0)
  widget.dropdown.arrow:SetSize(12, 12)
  widget.menu = CreateFrame("Frame", nil, panel)
  widget.menu.__puiUseTextureBackdrop = true
  widget.menu:SetFrameLevel(widget.dropdown:GetFrameLevel() + 10)
  widget.menu:Hide()
  for index = 1, 2 do
    local item = Button("Sample option " .. index, "body")
    item:SetParent(widget.menu)
    item:SetFrameLevel(widget.menu:GetFrameLevel() + 1)
    item:SetScript("OnClick", function(self)
      widget.dropdown.label:SetText(self.label:GetText())
      widget.menu:Hide()
      widget.dropdown.open = nil
      StyleSampleControl(widget.dropdown)
    end)
    widget.menuItems[index] = item
  end
  widget.dropdown:SetScript("OnClick", function(self)
    self.open = not self.open
    widget.menu:SetShown(self.open)
    StyleSampleControl(self)
  end)
  panel:SetScript("OnHide", function()
    widget.menu:Hide()
    widget.dropdown.open = nil
  end)

  local function Input()
    local control = SampleControl(widget, "EditBox")
    control:SetAutoFocus(false)
    control:SetTextInsets(8, 8, 0, 0)
    control:SetScript("OnEditFocusGained", function(self) self.focused = true; StyleSampleControl(self) end)
    control:SetScript("OnEditFocusLost", function(self) self.focused = nil; StyleSampleControl(self) end)
    control:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return control
  end
  widget.focusInput = Input()
  widget.focusInput.focusExample = true
  widget.focusInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  widget.number = Input()
  widget.number:SetJustifyH("CENTER")
  widget.number:SetMaxLetters(6)
  widget.slider = SampleControl(widget, "Slider")
  widget.slider:SetOrientation("HORIZONTAL")
  widget.slider:SetMinMaxValues(0, 100)
  widget.slider:SetValueStep(1)
  widget.slider:SetThumbTexture(WHITE8)
  widget.slider:SetScript("OnValueChanged", function(_, value)
    widget.number:SetText(string.format("%.0f", value))
  end)
  widget.number:SetScript("OnEnterPressed", function(self)
    local value = tonumber(self:GetText())
    if value and value >= 0 and value <= 100 then widget.slider:SetValue(value) end
    self:SetText(string.format("%.0f", widget.slider:GetValue()))
    self:ClearFocus()
  end)
  widget.number:SetScript("OnEscapePressed", function(self)
    self:SetText(string.format("%.0f", widget.slider:GetValue()))
    self:ClearFocus()
  end)
  widget.enabled = Button("Reset sample")
  widget.enabled:SetScript("OnClick", function() widget.slider:SetValue(50) end)
  widget.disabled = Button("Disabled button")
  widget.disabled.sampleDisabled = true
  widget.disabled:Disable()
  return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(TYPE, Constructor, 1)
