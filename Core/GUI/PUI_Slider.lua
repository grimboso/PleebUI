local _, ns = ...

local Theme = ns.Theme
local Pixel = ns.Pixel
local AceGUI = LibStub("AceGUI-3.0")

local TYPE = "PUI_Slider"
local VERSION = 4
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
  local edge = Theme.GetEdgeSize()
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

local function UpdateText(self)
  local value = self.value or 0

  if self.ispercent then
    self.editbox:SetText(("%s%%"):format(math_floor(value * 1000 + 0.5) / 10))
  else
    self.editbox:SetText(math_floor(value * 100 + 0.5) / 100)
  end
end

local function UpdateLabels(self)
  local minValue = self.min or 0
  local maxValue = self.max or 100

  if self.ispercent then
    self.lowtext:SetFormattedText("%s%%", minValue * 100)
    self.hightext:SetFormattedText("%s%%", maxValue * 100)
  else
    self.lowtext:SetText(minValue)
    self.hightext:SetText(maxValue)
  end
end

local function RefreshVisualState(self)
  local colors = Theme.GetColors()
  local disabled = self.disabled == true
  local textColor = disabled and colors.disabledText or colors.text
  local controlColor = disabled and colors.disabledControl or colors.control
  local borderColor = disabled and colors.disabledBorder or colors.border
  local editBorder = self.editbox.__puiHovered and not disabled and colors.accent or borderColor
  local thumbColor = disabled and colors.disabledText or colors.accent

  self.label:SetTextColor(
    textColor[1],
    textColor[2],
    textColor[3],
    textColor[4]
  )

  SetControlChromeColors(self.sliderChrome, controlColor, borderColor, 1)
  SetControlChromeColors(self.editboxChrome, controlColor, editBorder, 1)

  Pixel.SetVertexColor(self.thumb,
    thumbColor[1],
    thumbColor[2],
    thumbColor[3],
    thumbColor[4]
  )
  self.editbox:SetTextColor(
    textColor[1],
    textColor[2],
    textColor[3],
    textColor[4]
  )
end

local function GetValueGeometry(frameWidth, geom)
  local availableWidth = math_max(0, frameWidth - geom.controlLeft - geom.controlRight)
  local minSliderWidth = 36
  local minValueWidth = 40
  local valueGap
  local valueWidth

  if availableWidth >= minSliderWidth + minValueWidth then
    valueGap = math_min(
      geom.valueGap,
      availableWidth - minSliderWidth - minValueWidth
    )
    valueWidth = math_min(
      geom.valueWidth,
      availableWidth - valueGap - minSliderWidth
    )
  else
    valueGap = math_min(4, math_max(0, availableWidth - 2))
    valueWidth = math_max(1, math_floor((availableWidth - valueGap) * 0.58))
  end

  return valueWidth, valueGap
end

local function LayoutWidget(self, width)
  local geom = Theme.GetWidgetRowGeometry(self)
  local frameWidth = tonumber(width) or self.frame:GetWidth() or 200
  local valueWidth, valueGap = GetValueGeometry(frameWidth, geom)

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
    -(geom.controlRight + valueWidth + valueGap),
    -geom.controlTop
  )
  Pixel.Height(self.slider, geom.controlHeight)

  self.editbox:ClearAllPoints()
  Pixel.Point(self.editbox, "TOPRIGHT", self.frame, "TOPRIGHT", -geom.controlRight, -geom.controlTop)
  Pixel.Size(self.editbox, valueWidth, geom.controlHeight)

  local thumbSize = geom.controlHeight - 4
  Pixel.Size(self.thumb, thumbSize, thumbSize)
  LayoutControlChrome(self.slider, self.sliderChrome)
  LayoutControlChrome(self.editbox, self.editboxChrome)
end

local function ControlOnEnter(frame)
  frame.obj:Fire("OnEnter")
end

local function ControlOnLeave(frame)
  frame.obj:Fire("OnLeave")
end

local function FrameOnMouseDown(frame)
  local self = frame.obj

  if not self.disabled then
    self.slider:EnableMouseWheel(true)
  end

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

  if self.step and self.step > 0 then
    local minValue = self.min or 0
    newValue = math_floor((newValue - minValue) / self.step + 0.5) * self.step + minValue
  end

  if newValue ~= self.value and not self.disabled then
    self.value = newValue

    if ShouldCommitOnRelease(self) then
      self:Fire("OnValueChanging", newValue)
    else
      self:Fire("OnValueChanged", newValue)
    end
  end

  if self.value then
    UpdateText(self)
  end
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

local function SliderOnMouseWheel(frame, delta)
  local self = frame.obj

  if self.disabled then
    return
  end

  local value = self.value
  local step = self.step or 1

  if delta > 0 then
    value = math_min(value + step, self.max)
  else
    value = math_max(value - step, self.min)
  end

  self.slider:SetValue(value)

  if ShouldCommitOnRelease(self) then
    FireSliderCommit(self)
  end
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
    value = tonumber(text:gsub("%%", ""))
    if value then
      value = value / 100
    end
  else
    value = tonumber(text)
  end

  if not value then
    UpdateText(self)
    editbox:ClearFocus()
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
end

local function EditBoxOnLeave(editbox)
  editbox.__puiHovered = nil
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
    self.lowtext:Hide()
    self.hightext:Hide()
    LayoutWidget(self, self.frame:GetWidth())
    RefreshVisualState(self)
  end,

  OnRelease = function(self)
    self.editbox:ClearFocus()
    self.editbox.__puiHovered = nil
    self.slider:EnableMouseWheel(false)
    self.commitOnRelease = nil
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
      self.editbox.__puiHovered = nil
      self.editbox:ClearFocus()
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
    UpdateLabels(self)

    if self.value then
      slider:SetValue(self.value)
      self.value = slider:GetValue()
    end

    slider.setup = nil
  end,

  SetIsPercent = function(self, isPercent)
    self.ispercent = isPercent == true
    UpdateLabels(self)
    UpdateText(self)
  end,

  RefreshTheme = function(self)
    Theme.ApplyFont(self.label, "body")
    Theme.ApplyFont(self.lowtext, "body")
    Theme.ApplyFont(self.hightext, "body")
    Theme.ApplyFont(self.editbox, "body")
    LayoutWidget(self, self.frame:GetWidth())
    RefreshVisualState(self)
  end,
}

local function Constructor()
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:EnableMouse(true)
  frame:SetScript("OnMouseDown", FrameOnMouseDown)

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

  local thumb = slider:GetThumbTexture()
  Pixel.SetTexCoord(thumb, 0, 1, 0, 1)

  local lowtext = slider:CreateFontString(nil, "ARTWORK")
  lowtext.__puiOptionsFontOwned = true
  Theme.ApplyFont(lowtext, "body")
  lowtext:Hide()

  local hightext = slider:CreateFontString(nil, "ARTWORK")
  hightext.__puiOptionsFontOwned = true
  Theme.ApplyFont(hightext, "body")
  hightext:Hide()

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

  local widget = {
    label = label,
    slider = slider,
    thumb = thumb,
    sliderChrome = CreateControlChrome(slider),
    lowtext = lowtext,
    hightext = hightext,
    editbox = editbox,
    editboxChrome = CreateControlChrome(editbox),
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

  LayoutWidget(widget, 200)
  RefreshVisualState(widget)

  return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(TYPE, Constructor, VERSION)
