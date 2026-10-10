local _, ns = ...

local Theme = ns.Theme
local Pixel = ns.Pixel
local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local TYPE = "PUI_Slider"
local VERSION = 5
local WHITE8 = "Interface\\Buttons\\WHITE8x8"

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local tonumber = tonumber
local type = type

local function SetTextureColor(texture, color, alphaMultiplier)
  Pixel.SetColorTexture(texture,
    color[1],
    color[2],
    color[3],
    (color[4] or 1) * (alphaMultiplier or 1)
  )
end

local function CreateControlChrome(parent)
  local background = parent:CreateTexture(nil, "BACKGROUND")
  Pixel.SetTexture(background, WHITE8)

  local border = {
    top = parent:CreateTexture(nil, "BORDER"),
    bottom = parent:CreateTexture(nil, "BORDER"),
    left = parent:CreateTexture(nil, "BORDER"),
    right = parent:CreateTexture(nil, "BORDER"),
  }

  for _, texture in pairs(border) do
    Pixel.SetTexture(texture, WHITE8)
  end

  return {
    background = background,
    border = border,
  }
end

local function LayoutControlChrome(parent, chrome)
  local edge = Theme.ControlBorderSize
  local border = chrome.border

  chrome.background:ClearAllPoints()
  Pixel.Point(chrome.background, "TOPLEFT", parent, "TOPLEFT", edge, -edge)
  Pixel.Point(chrome.background, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", -edge, edge)

  border.top:ClearAllPoints()
  Pixel.Point(border.top, "TOPLEFT", parent, "TOPLEFT", 0, 0)
  Pixel.Point(border.top, "TOPRIGHT", parent, "TOPRIGHT", 0, 0)
  Pixel.Height(border.top, edge)

  border.bottom:ClearAllPoints()
  Pixel.Point(border.bottom, "BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
  Pixel.Point(border.bottom, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
  Pixel.Height(border.bottom, edge)

  border.left:ClearAllPoints()
  Pixel.Point(border.left, "TOPLEFT", parent, "TOPLEFT", 0, -edge)
  Pixel.Point(border.left, "BOTTOMLEFT", parent, "BOTTOMLEFT", 0, edge)
  Pixel.Width(border.left, edge)

  border.right:ClearAllPoints()
  Pixel.Point(border.right, "TOPRIGHT", parent, "TOPRIGHT", 0, -edge)
  Pixel.Point(border.right, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, edge)
  Pixel.Width(border.right, edge)
end

local function SetControlChromeColors(chrome, backgroundColor, borderColor, alphaMultiplier)
  SetTextureColor(chrome.background, backgroundColor, alphaMultiplier)

  for _, texture in pairs(chrome.border) do
    SetTextureColor(texture, borderColor, alphaMultiplier)
  end
end

local function FormatValue(self, value)
  local text = ("%.2f"):format(self.ispercent and value * 100 or value)
  text = text:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
  return self.ispercent and text .. "%" or text
end

local function UpdateText(self)
  self.inputError = nil
  self.editbox:SetText(FormatValue(self, self.value or 0))
end

local function GetAdjustmentStep(self)
  local minimumStep = self.ispercent and 0.0001 or 0.01
  if self.step and self.step > 0 then return math_max(self.step, minimumStep) end
  return self.ispercent and 0.01 or 1
end

local function HideSliderTooltip(self)
  local tooltip = self.hintTooltip
  if tooltip and tooltip:GetOwner() == self.frame then tooltip:Hide() end
  self.hintTooltip = nil
end

local function ShowSliderTooltip(self)
  HideSliderTooltip(self)
  self:Fire("OnEnter")
  local tooltip = AceConfigDialog.tooltip
  if not tooltip:IsShown() or tooltip:GetOwner() ~= self.frame then
    tooltip = GameTooltip
    if not tooltip:IsShown() or tooltip:GetOwner() ~= self.frame then
      tooltip:SetOwner(self.frame, "ANCHOR_RIGHT")
      tooltip:SetText(self.label:GetText() or "")
    end
  end
  local colors = Theme.GetColors()
  tooltip:AddLine("Range: " .. FormatValue(self, self.min or 0) .. " - " .. FormatValue(self, self.max or 100),
    colors.text[1], colors.text[2], colors.text[3], true)
  local step = GetAdjustmentStep(self)
  tooltip:AddLine("Step: " .. FormatValue(self, step), colors.mutedText[1], colors.mutedText[2], colors.mutedText[3], true)
  tooltip:AddLine("Shift + mouse wheel to adjust.", colors.mutedText[1], colors.mutedText[2], colors.mutedText[3], true)
  if self.inputError then tooltip:AddLine(self.inputError, colors.accent[1], colors.accent[2], colors.accent[3], true) end
  tooltip:Show()
  self.hintTooltip = tooltip
end

local function RefreshVisualState(self)
  local colors = Theme.GetColors()
  local disabled = self.disabled == true
  local textColor = disabled and colors.disabledText or colors.text
  local controlColor = disabled and colors.disabledControl or colors.control
  local borderColor = disabled and colors.disabledControlBorder or colors.controlBorder
  local editControl, editBorder = Theme.GetControlStateColors(
    disabled, self.editbox.__puiHovered == true, false, self.editbox:HasFocus()
  )
  local thumbColor = disabled and colors.disabledText or colors.accent

  self.label:SetTextColor(
    textColor[1],
    textColor[2],
    textColor[3],
    textColor[4]
  )

  SetControlChromeColors(self.sliderChrome, controlColor, borderColor, 1)
  SetControlChromeColors(self.editboxChrome, editControl, editBorder, 1)

  Pixel.SetVertexColor(self.thumb,
    thumbColor[1],
    thumbColor[2],
    thumbColor[3],
    thumbColor[4]
  )
  for _, button in ipairs({ self.minusButton, self.plusButton }) do
    local atLimit = button == self.minusButton
      and (self.value or 0) <= (self.min or 0)
      or button == self.plusButton and (self.value or 0) >= (self.max or 100)
    local buttonDisabled = disabled or atLimit
    if buttonDisabled then button:Disable() else button:Enable() end
    local background, border, text = Theme.GetControlStateColors(
      buttonDisabled, button.__puiHovered == true, button.__puiPressed == true
    )
    SetControlChromeColors(button.chrome, background, border, 1)
    button.text:SetTextColor(text[1], text[2], text[3], text[4])
  end
  self.editbox:SetTextColor(
    textColor[1],
    textColor[2],
    textColor[3],
    textColor[4]
  )
end

local function GetValueGeometry(frameWidth, geom)
  local availableWidth = math_max(4, frameWidth - geom.controlLeft - geom.controlRight)
  local gap = math_min(geom.valueGap, math_max(0, (availableWidth - 4) / 3))
  local buttonWidth = math_min(geom.controlHeight, math_max(1, math_floor((availableWidth - gap * 3 - 2) / 4)))
  local remainingWidth = math_max(2, availableWidth - buttonWidth * 2 - gap * 3)
  local valueWidth = math_min(geom.valueWidth, math_max(1, remainingWidth - math_min(36, remainingWidth * 0.4)))
  return valueWidth, gap, buttonWidth
end

local function LayoutWidget(self, width)
  local geom = Theme.GetWidgetRowGeometry(self)
  local frameWidth = tonumber(width) or self.frame:GetWidth() or 200
  local valueWidth, valueGap, buttonWidth = GetValueGeometry(frameWidth, geom)

  self.label:ClearAllPoints()
  Pixel.Point(self.label, "TOPLEFT", self.frame, "TOPLEFT", geom.labelLeft, -geom.labelTop)
  Pixel.Point(self.label, "TOPRIGHT", self.frame, "TOPRIGHT", -geom.labelRight, -geom.labelTop)
  Pixel.Height(self.label, geom.labelHeight)

  self.slider:ClearAllPoints()
  Pixel.Point(self.slider, "TOPLEFT", self.frame, "TOPLEFT", geom.controlLeft, -geom.controlTop)
  Pixel.Point(self.slider,
    "TOPRIGHT",
    self.frame,
    "TOPRIGHT",
    -(geom.controlRight + valueWidth + buttonWidth * 2 + valueGap * 3),
    -geom.controlTop
  )
  Pixel.Height(self.slider, geom.controlHeight)

  self.plusButton:ClearAllPoints()
  Pixel.Point(self.plusButton, "TOPRIGHT", self.frame, "TOPRIGHT", -geom.controlRight, -geom.controlTop)
  Pixel.Size(self.plusButton, buttonWidth, geom.controlHeight)
  self.editbox:ClearAllPoints()
  Pixel.Point(self.editbox, "TOPRIGHT", self.plusButton, "TOPLEFT", -valueGap, 0)
  Pixel.Size(self.editbox, valueWidth, geom.controlHeight)

  self.minusButton:ClearAllPoints()
  Pixel.Point(self.minusButton, "TOPRIGHT", self.editbox, "TOPLEFT", -valueGap, 0)
  Pixel.Size(self.minusButton, buttonWidth, geom.controlHeight)
  LayoutControlChrome(self.minusButton, self.minusButton.chrome)
  LayoutControlChrome(self.plusButton, self.plusButton.chrome)

  local thumbSize = geom.controlHeight - 4
  Pixel.Size(self.thumb, thumbSize, thumbSize)
  LayoutControlChrome(self.slider, self.sliderChrome)
  LayoutControlChrome(self.editbox, self.editboxChrome)
end

local function SliderModifierChanged(frame)
  frame:EnableMouseWheel(not frame.obj.disabled and frame.__puiHovered == true and IsShiftKeyDown())
end

local function ControlOnEnter(frame)
  frame.__puiHovered = true
  frame:RegisterEvent("MODIFIER_STATE_CHANGED")
  SliderModifierChanged(frame)
  ShowSliderTooltip(frame.obj)
end

local function ControlOnLeave(frame)
  frame.__puiHovered = nil
  frame:UnregisterEvent("MODIFIER_STATE_CHANGED")
  frame:EnableMouseWheel(false)
  HideSliderTooltip(frame.obj)
  frame.obj:Fire("OnLeave")
end

local function FrameOnMouseDown()
  AceGUI:ClearFocus()
end

local function ShouldCommitOnRelease(self)
  if self.commitOnRelease == true then
    return true
  end

  local option = self:GetUserData("option")
  local optionArg = option and option.arg

  return self:GetUserData("appName") == "PleebUI"
    and type(optionArg) == "table"
    and optionArg.puiRefreshOnRelease == true
end

local function SliderOnValueChanged(frame, newValue)
  local self = frame.obj

  if frame.setup then
    return
  end

  if self.step and self.step > 0 and newValue ~= self.min and newValue ~= self.max then
    local minValue = self.min or 0
    newValue = math_floor((newValue - minValue) / self.step + 0.5) * self.step + minValue
  end
  newValue = math_max(self.min or 0, math_min(self.max or 100, newValue))
  if frame:GetValue() ~= newValue then
    frame.setup = true
    frame:SetValue(newValue)
    frame.setup = nil
  end

  if newValue ~= self.value and not self.disabled then
    self.value = newValue

    if ShouldCommitOnRelease(self) then
      local option = self:GetUserData("option")
      local optionArg = option and option.arg
      local preview = type(optionArg) == "table" and optionArg.puiLivePreview
      if type(preview) == "function" then
        self.livePreview = preview
        preview(newValue)
      end
      self:Fire("OnValueChanging", newValue)
    else
      self:Fire("OnValueChanged", newValue)
    end
  end

  UpdateText(self)
  RefreshVisualState(self)
end

local function FireSliderCommit(self)
  if self:GetUserData("appName") == "PleebUI"
    and not ShouldCommitOnRelease(self)
  then
    return
  end

  self:Fire("OnMouseUp", self.value)
end

local function SliderOnMouseUp(frame)
  FireSliderCommit(frame.obj)
end

local function AdjustValue(self, direction)
  if self.disabled then return end
  AceGUI:ClearFocus()
  local step = GetAdjustmentStep(self)
  local value = math_max(self.min, math_min(self.max, self.value + direction * step))
  if value == self.value then return end
  self.slider:SetValue(value)
  FireSliderCommit(self)
end

local function SliderOnMouseWheel(frame, delta)
  if not IsShiftKeyDown() or frame.__puiHovered ~= true then return end
  AdjustValue(frame.obj, delta > 0 and 1 or -1)
end

local function StepButtonOnClick(button)
  AdjustValue(button.obj, button.direction)
end

local function StepButtonOnEnter(button)
  button.__puiHovered = true
  RefreshVisualState(button.obj)
  ShowSliderTooltip(button.obj)
end

local function StepButtonOnLeave(button)
  button.__puiHovered = nil
  button.__puiPressed = nil
  RefreshVisualState(button.obj)
  HideSliderTooltip(button.obj)
  button.obj:Fire("OnLeave")
end

local function StepButtonOnMouseDown(button, mouseButton)
  if mouseButton ~= "LeftButton" then return end
  button.__puiPressed = true
  RefreshVisualState(button.obj)
end

local function StepButtonOnMouseUp(button, mouseButton)
  if mouseButton ~= "LeftButton" then return end
  button.__puiPressed = nil
  RefreshVisualState(button.obj)
end

local function SliderOnHide(frame)
  local self = frame.obj
  self.slider:UnregisterEvent("MODIFIER_STATE_CHANGED")
  self.slider:EnableMouseWheel(false)
  self.slider.__puiHovered = nil
  self.editbox:ClearFocus()
  self.editbox.__puiHovered = nil
  for _, button in ipairs({ self.minusButton, self.plusButton }) do
    button.__puiHovered = nil
    button.__puiPressed = nil
  end
  HideSliderTooltip(self)
end

local function EditBoxOnEscapePressed(editbox)
  UpdateText(editbox.obj)
  editbox:ClearFocus()
end

local function EditBoxOnEnterPressed(editbox)
  local self = editbox.obj
  local text = editbox:GetText()
  local value

  if self.ispercent then
    value = tonumber((text:gsub("%%", "")))
    if value then
      value = value / 100
    end
  else
    value = tonumber(text)
  end

  if not value or value ~= value or value == math.huge or value == -math.huge then
    self.inputError = "Enter a number."
  elseif value < self.min or value > self.max then
    self.inputError = "Enter a value between " .. FormatValue(self, self.min) .. " and " .. FormatValue(self, self.max) .. "."
  else
    self.inputError = nil
  end
  if self.inputError then
    editbox:HighlightText()
    ShowSliderTooltip(self)
    return
  end

  PlaySound(856)
  self.slider:SetValue(value)
  FireSliderCommit(self)
  editbox:ClearFocus()
end

local function EditBoxOnEnter(editbox)
  editbox.__puiHovered = true
  RefreshVisualState(editbox.obj)
  ShowSliderTooltip(editbox.obj)
end

local function EditBoxOnLeave(editbox)
  editbox.__puiHovered = nil
  RefreshVisualState(editbox.obj)
  HideSliderTooltip(editbox.obj)
  editbox.obj:Fire("OnLeave")
end

local function EditBoxOnFocusGained(editbox)
  AceGUI:SetFocus(editbox.obj)
  RefreshVisualState(editbox.obj)
end

local function EditBoxOnFocusLost(editbox)
  UpdateText(editbox.obj)
  HideSliderTooltip(editbox.obj)
  RefreshVisualState(editbox.obj)
end

local methods = {
  OnAcquire = function(self)
    local metrics = Theme.GetControlMetrics()

    self:SetWidth(200)
    self:SetHeight(metrics.widgetBoxHeight)
    self:SetDisabled(false)
    self:SetCommitOnRelease(false)
    self:SetIsPercent(nil)
    self:SetSliderValues(0, 100, 1)
    self:SetValue(0)
    self.slider:EnableMouseWheel(false)
    self.inputError = nil
    self.slider.__puiHovered = nil
    LayoutWidget(self, self.frame:GetWidth())
    RefreshVisualState(self)
  end,

  OnRelease = function(self)
    if self.livePreview then
      self.livePreview(nil)
      self.livePreview = nil
    end
    SliderOnHide(self.frame)
    self.commitOnRelease = nil
  end,

  ClearFocus = function(self)
    self.editbox:ClearFocus()
  end,

  OnWidthSet = function(self, width)
    LayoutWidget(self, width)
  end,

  OnHeightSet = function(self)
    LayoutWidget(self, self.frame:GetWidth())
  end,

  SetCommitOnRelease = function(self, enabled)
    self.commitOnRelease = enabled == true
  end,

  SetDisabled = function(self, disabled)
    disabled = disabled == true
    self.disabled = disabled
    self.slider:EnableMouse(not disabled)
    self.editbox:EnableMouse(not disabled)

    if disabled then
      SliderOnHide(self.frame)
    elseif self.slider.__puiHovered == true then
      SliderModifierChanged(self.slider)
    end

    RefreshVisualState(self)
  end,

  SetValue = function(self, value)
    value = tonumber(value) or 0
    self.slider.setup = true
    self.slider:SetValue(value)
    self.value = self.slider:GetValue()
    UpdateText(self)
    self.slider.setup = nil
    RefreshVisualState(self)
  end,

  GetValue = function(self)
    return self.value
  end,

  SetLabel = function(self, text)
    self.label:SetText(text)
  end,

  SetSliderValues = function(self, minValue, maxValue, step)
    local slider = self.slider

    minValue = tonumber(minValue) or 0
    maxValue = tonumber(maxValue) or 100
    step = tonumber(step) or 0

    slider.setup = true
    self.min = minValue
    self.max = maxValue
    self.step = step
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)

    if self.value then
      slider:SetValue(self.value)
      self.value = slider:GetValue()
    end

    slider.setup = nil
    RefreshVisualState(self)
  end,

  SetIsPercent = function(self, isPercent)
    self.ispercent = isPercent == true
    UpdateText(self)
  end,

  RefreshTheme = function(self)
    Theme.ApplyFont(self.label, "body")
    Theme.ApplyFont(self.minusButton.text, "body")
    Theme.ApplyFont(self.plusButton.text, "body")
    Theme.ApplyFont(self.editbox, "body")
    LayoutWidget(self, self.frame:GetWidth())
    RefreshVisualState(self)
  end,
}

local function Constructor()
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:EnableMouse(true)
  frame:SetScript("OnMouseDown", FrameOnMouseDown)
  frame:SetScript("OnHide", SliderOnHide)

  local label = frame:CreateFontString(nil, "OVERLAY")
  label.__puiOptionsFontOwned = true
  label:SetJustifyH("CENTER")
  Theme.ApplyFont(label, "body")

  local slider = CreateFrame("Slider", nil, frame)
  slider:SetOrientation("HORIZONTAL")
  slider:SetHitRectInsets(0, 0, -6, -6)
  slider:SetThumbTexture(WHITE8)
  slider:SetValue(0)
  slider:SetScript("OnValueChanged", SliderOnValueChanged)
  slider:SetScript("OnEnter", ControlOnEnter)
  slider:SetScript("OnLeave", ControlOnLeave)
  slider:SetScript("OnMouseUp", SliderOnMouseUp)
  slider:SetScript("OnMouseWheel", SliderOnMouseWheel)
  slider:SetScript("OnEvent", SliderModifierChanged)

  local thumb = slider:GetThumbTexture()
  Pixel.SetTexCoord(thumb, 0, 1, 0, 1)

  local editbox = CreateFrame("EditBox", nil, frame)
  editbox.__puiOptionsFontOwned = true
  editbox:SetAutoFocus(false)
  editbox:SetJustifyH("CENTER")
  editbox:SetTextInsets(4, 4, 0, 0)
  editbox:EnableMouse(true)
  Theme.ApplyFont(editbox, "body")
  editbox:SetScript("OnEnter", EditBoxOnEnter)
  editbox:SetScript("OnLeave", EditBoxOnLeave)
  editbox:SetScript("OnEnterPressed", EditBoxOnEnterPressed)
  editbox:SetScript("OnEscapePressed", EditBoxOnEscapePressed)
  editbox:SetScript("OnEditFocusGained", EditBoxOnFocusGained)
  editbox:SetScript("OnEditFocusLost", EditBoxOnFocusLost)

  local minusButton = CreateFrame("Button", nil, frame)
  local plusButton = CreateFrame("Button", nil, frame)
  for index, button in ipairs({ minusButton, plusButton }) do
    button.direction = index == 1 and -1 or 1
    button:RegisterForClicks("LeftButtonUp")
    button.chrome = CreateControlChrome(button)
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text.__puiOptionsFontOwned = true
    Pixel.AllPoints(button.text, button)
    button.text:SetJustifyH("CENTER")
    button.text:SetJustifyV("MIDDLE")
    button.text:SetText(index == 1 and "-" or "+")
    Theme.ApplyFont(button.text, "body")
    button:SetScript("OnClick", StepButtonOnClick)
    button:SetScript("OnEnter", StepButtonOnEnter)
    button:SetScript("OnLeave", StepButtonOnLeave)
    button:SetScript("OnMouseDown", StepButtonOnMouseDown)
    button:SetScript("OnMouseUp", StepButtonOnMouseUp)
  end

  local widget = {
    label = label,
    slider = slider,
    thumb = thumb,
    sliderChrome = CreateControlChrome(slider),
    editbox = editbox,
    editboxChrome = CreateControlChrome(editbox),
    minusButton = minusButton,
    plusButton = plusButton,
    alignoffset = 0,
    frame = frame,
    type = TYPE,
  }

  for method, func in pairs(methods) do
    widget[method] = func
  end

  frame.obj = widget
  slider.obj = widget
  editbox.obj = widget
  minusButton.obj = widget
  plusButton.obj = widget

  LayoutWidget(widget, 200)
  RefreshVisualState(widget)

  return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(TYPE, Constructor, VERSION)
