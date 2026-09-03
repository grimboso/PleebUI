local _, ns = ...

local Theme = ns.Theme
local WidgetSkins = Theme.WidgetSkins
local AceGUI = LibStub("AceGUI-3.0")
local CreateFrame = _G.CreateFrame
local PlaySound = _G.PlaySound
local UIParent = _G.UIParent
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min
local tonumber = tonumber

local PUI_BUTTON_TYPE = "PUI_Button"
local PUI_BUTTON_VERSION = 1
local PUI_BUTTON_TEXT_PADDING = 30

local function ClearTexture(texture)
  if texture then
    texture:SetTexture(nil)
    texture:SetAlpha(0)
    texture:Hide()
  end
end

local function StripButtonTextures(button)
  button:SetNormalTexture("")
  button:SetPushedTexture("")
  button:SetHighlightTexture("")
  button:SetDisabledTexture("")

  ClearTexture(button:GetNormalTexture())
  ClearTexture(button:GetPushedTexture())
  ClearTexture(button:GetHighlightTexture())
  ClearTexture(button:GetDisabledTexture())

  for _, region in ipairs({ button:GetRegions() }) do
    if region:GetObjectType() == "Texture" then
      ClearTexture(region)
    end
  end

  for _, key in ipairs({ "Left", "Right", "Middle", "Top", "Bottom", "Center" }) do
    ClearTexture(button[key])
  end

  if button.SetBackdrop then
    button:SetBackdrop(nil)
  end
end

local function ApplyButtonText(button, fallbackText, alpha)
  local text = button:GetFontString() or fallbackText
  if not text then
    return
  end

  local textColor = Theme.GetColors().text

  Theme.ApplyFont(text, "button")
  text:SetAlpha(1)
  text:SetDrawLayer("OVERLAY", 7)
  text:SetTextColor(textColor[1], textColor[2], textColor[3], alpha)
  text:Show()
end

local function ApplyButtonVisual(button, fallbackText)
  local colors = Theme.GetColors()
  local bg = colors.control
  local border = colors.border
  local enabled = button:IsEnabled()

  Theme.SetSquareBackdrop(button, {
    bg = { bg[1], bg[2], bg[3], enabled and 0.66 or 0.42 },
    border = { border[1], border[2], border[3], enabled and 0.22 or 0.14 },
  }, math.max(Theme.GetEdgeSize(), 2))

  local backdrop = button._puiBg
  backdrop:ClearAllPoints()
  backdrop:SetAllPoints(button)
  backdrop:SetFrameLevel(math.max(button:GetFrameLevel() - 1, 0))
  backdrop:Show()

  ApplyButtonText(button, fallbackText, enabled and 1 or 0.68)
end

local function HookButtonState(button, fallbackText, owner)
  if button.__puiButtonStateHooked then
    return
  end

  button.__puiButtonStateHooked = true

  local function Refresh(self)
    if owner and owner.__puiAceGUIOwnedByPleebUI ~= true then
      return
    end

    ApplyButtonVisual(self, fallbackText)
  end

  button:HookScript("OnShow", Refresh)
  button:HookScript("OnEnable", Refresh)
  button:HookScript("OnDisable", Refresh)
end

function WidgetSkins.UIButton(button)
  StripButtonTextures(button)
  button:SetAlpha(1)
  ApplyButtonVisual(button)
  HookButtonState(button)
end

function WidgetSkins.Button(widget, owner)
  local button = widget.button or widget.frame or widget
  local outer = widget.frame or button

  if outer ~= button then
    if outer._puiBg then
      outer._puiBg:Hide()
    end
    if outer.SetBackdrop then
      outer:SetBackdrop(nil)
    end
  end

  StripButtonTextures(button)

  if outer ~= button then
    local geom = Theme.GetWidgetRowGeometry()

    button:ClearAllPoints()
    button:SetPoint("LEFT", outer, "LEFT", geom.controlLeft, geom.controlYOffset)
    button:SetPoint("RIGHT", outer, "RIGHT", -geom.controlRight, geom.controlYOffset)
    button:SetHeight(geom.controlHeight)
  end

  button:SetAlpha(1)

  local fallbackText = widget.text or widget.label
  local hookOwner = owner or (widget.AceGUIWidgetVersion and widget or nil)
  ApplyButtonVisual(button, fallbackText)
  HookButtonState(button, fallbackText, hookOwner)
end

function WidgetSkins.Keybinding(widget)
  WidgetSkins.Button(widget)

  local msgframe = widget.msgframe
  for _, region in ipairs({ msgframe:GetRegions() }) do
    if region:GetObjectType() == "Texture" then
      ClearTexture(region)
    end
  end

  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(msgframe, {
    bg = colors.control,
    border = colors.border,
  }, math.max(Theme.GetEdgeSize(), 2))

  msgframe.msg:ClearAllPoints()
  msgframe.msg:SetPoint("CENTER", msgframe, "CENTER", 0, 0)
  Theme.ApplyFont(msgframe.msg, "body")
end

local function PUI_Button_Layout(widget, width)
  local geom = Theme.GetWidgetRowGeometry()
  local frameWidth = tonumber(width) or widget.frame:GetWidth() or 200
  local availableWidth = math_max(1, frameWidth - geom.controlLeft - geom.controlRight)
  local textWidth = tonumber(widget.text:GetUnboundedStringWidth()) or 0
  local buttonWidth = math_min(
    availableWidth,
    math_max(geom.buttonWidth * 2, math_ceil(textWidth + PUI_BUTTON_TEXT_PADDING))
  )

  widget.button:ClearAllPoints()
  widget.button:SetPoint("CENTER", widget.frame, "CENTER", 0, geom.controlYOffset)
  widget.button:SetSize(buttonWidth, geom.controlHeight)
end

local function PUI_Button_RefreshVisualState(widget)
  local colors = Theme.GetColors()
  local disabled = widget.disabled == true
  local hovered = widget.button.__puiHovered == true and not disabled
  local pressed = widget.button.__puiPressed == true and not disabled
  local background = disabled and colors.disabledControl or colors.control
  local backgroundAlpha = background[4]
  local border = disabled and colors.disabledBorder or colors.border

  if pressed then
    background = colors.accent
    backgroundAlpha = background[4] * 0.32
    border = colors.accent
  elseif hovered then
    background = colors.accent
    backgroundAlpha = background[4] * 0.20
    border = colors.accent
  end

  Theme.SetSquareBackdrop(widget.button, {
    bg = { background[1], background[2], background[3], backgroundAlpha },
    border = border,
  }, Theme.GetEdgeSize())

  widget.button._puiBg:SetAlpha(1)

  local textColor = disabled and colors.disabledText or colors.text
  widget.text:SetTextColor(
    textColor[1],
    textColor[2],
    textColor[3],
    textColor[4]
  )
end

local function PUI_Button_OnClick(button, ...)
  AceGUI:ClearFocus()
  PlaySound(852)
  button.obj:Fire("OnClick", ...)
end

local function PUI_Button_OnEnter(button)
  local widget = button.obj

  if not widget.disabled then
    button.__puiHovered = true
    PUI_Button_RefreshVisualState(widget)
  end

  widget:Fire("OnEnter")
end

local function PUI_Button_OnLeave(button)
  local widget = button.obj

  button.__puiHovered = nil
  button.__puiPressed = nil
  PUI_Button_RefreshVisualState(widget)
  widget:Fire("OnLeave")
end

local function PUI_Button_OnMouseDown(button, mouseButton)
  local widget = button.obj

  if mouseButton ~= "LeftButton" or widget.disabled then
    return
  end

  button.__puiPressed = true
  PUI_Button_RefreshVisualState(widget)
end

local function PUI_Button_OnMouseUp(button, mouseButton)
  if mouseButton ~= "LeftButton" then
    return
  end

  button.__puiPressed = nil
  PUI_Button_RefreshVisualState(button.obj)
end

local function PUI_Button_OnHide(button)
  button.__puiHovered = nil
  button.__puiPressed = nil
  PUI_Button_RefreshVisualState(button.obj)
end

local PUI_Button_Methods = {
  OnAcquire = function(self)
    self:SetHeight(Theme.GetControlMetrics().widgetBoxHeight)
    self:SetWidth(200)
    self.button.__puiHovered = nil
    self.button.__puiPressed = nil
    self:SetText("")
    self:SetDisabled(false)
    self:RefreshTheme()
  end,

  OnRelease = function(self)
    self.button.__puiHovered = nil
    self.button.__puiPressed = nil
  end,

  OnWidthSet = function(self, width)
    PUI_Button_Layout(self, width)
  end,

  OnHeightSet = function(self)
    PUI_Button_Layout(self, self.frame:GetWidth())
  end,

  SetText = function(self, text)
    self.text:SetText(text or "")
    PUI_Button_Layout(self, self.frame:GetWidth())
  end,

  SetDisabled = function(self, disabled)
    disabled = disabled == true
    self.disabled = disabled
    self.button.__puiHovered = nil
    self.button.__puiPressed = nil

    if disabled then
      self.button:Disable()
    else
      self.button:Enable()
    end

    PUI_Button_RefreshVisualState(self)
  end,

  RefreshTheme = function(self)
    Theme.ApplyFont(self.text, "button")
    PUI_Button_Layout(self, self.frame:GetWidth())
    PUI_Button_RefreshVisualState(self)
  end,
}

local function PUI_Button_Constructor()
  local frame = CreateFrame("Frame", nil, UIParent)

  local button = CreateFrame("Button", nil, frame)
  button:RegisterForClicks("LeftButtonUp")
  button:SetScript("OnClick", PUI_Button_OnClick)
  button:SetScript("OnEnter", PUI_Button_OnEnter)
  button:SetScript("OnLeave", PUI_Button_OnLeave)
  button:SetScript("OnMouseDown", PUI_Button_OnMouseDown)
  button:SetScript("OnMouseUp", PUI_Button_OnMouseUp)
  button:SetScript("OnHide", PUI_Button_OnHide)

  local text = button:CreateFontString(nil, "OVERLAY")
  text.__puiOptionsFontOwned = true
  text:SetPoint("LEFT", button, "LEFT", 8, 0)
  text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
  text:SetJustifyH("CENTER")
  text:SetJustifyV("MIDDLE")
  text:SetWordWrap(false)
  Theme.ApplyFont(text, "button")
  button:SetFontString(text)

  local widget = {
    type = PUI_BUTTON_TYPE,
    frame = frame,
    button = button,
    text = text,
    alignoffset = 0,
  }

  for method, func in pairs(PUI_Button_Methods) do
    widget[method] = func
  end

  frame.obj = widget
  button.obj = widget

  PUI_Button_Layout(widget, 200)
  PUI_Button_RefreshVisualState(widget)

  return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(PUI_BUTTON_TYPE, PUI_Button_Constructor, PUI_BUTTON_VERSION)