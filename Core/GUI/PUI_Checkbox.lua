local _, ns = ...

local Theme = ns.Theme
local Pixel = ns.Pixel
local WidgetSkins = Theme.WidgetSkins
local AceGUI = LibStub("AceGUI-3.0")
local CreateFrame = _G.CreateFrame
local PlaySound = _G.PlaySound
local UIParent = _G.UIParent
local select = _G.select

local WHITE8 = "Interface\\Buttons\\WHITE8x8"
local RADIO_TEXTURE = 130843
local PUI_CHECKBOX_TYPE = "PUI_Checkbox"
local PUI_CHECKBOX_VERSION = 1

local function ClearTexture(texture)
  Pixel.SetTexture(texture, nil)
  texture:SetAlpha(0)
  texture:Hide()
end

local function ResolveCheckbox(widget)
  return widget.frame, widget.check, widget.checkbg, widget.text
end

local function ResolveControlType(widget, anchor)
  local controlType = widget.__puiCheckboxControlType

  if controlType then
    return controlType
  end

  if (anchor:GetWidth() or 24) <= 18 then
    controlType = "radio"
  else
    controlType = "checkbox"
  end

  widget.__puiCheckboxControlType = controlType
  return controlType
end

local function EnsureCheckboxChrome(widget, frame)
  local chrome = widget.__puiCheckboxChrome

  if chrome then
    return chrome
  end

  local background = frame:CreateTexture(nil, "BACKGROUND")
  Theme.MarkCreatedWidgetChrome(background)

  local fill = frame:CreateTexture(nil, "ARTWORK")
  Theme.MarkCreatedWidgetChrome(fill)

  local border = {
    top = frame:CreateTexture(nil, "BORDER"),
    bottom = frame:CreateTexture(nil, "BORDER"),
    left = frame:CreateTexture(nil, "BORDER"),
    right = frame:CreateTexture(nil, "BORDER"),
  }

  for _, texture in pairs(border) do
    Theme.MarkCreatedWidgetChrome(texture)
  end

  chrome = {
    background = background,
    fill = fill,
    border = border,
  }
  widget.__puiCheckboxChrome = chrome
  return chrome
end

local function SetCheckboxChromeShown(chrome, shown)
  if shown then
    chrome.background:Show()
    chrome.fill:Show()

    for _, texture in pairs(chrome.border) do
      texture:Show()
    end
  else
    chrome.background:Hide()
    chrome.fill:Hide()

    for _, texture in pairs(chrome.border) do
      texture:Hide()
    end
  end
end

local function LayoutCheckboxChrome(frame, chrome, left, yOffset, size)
  local edge = Theme.GetEdgeSize()
  local border = chrome.border

  chrome.background:ClearAllPoints()
  Pixel.Point(chrome.background, "LEFT", frame, "LEFT", left + edge, yOffset)
  Pixel.Size(chrome.background, size - edge * 2, size - edge * 2)

  border.top:ClearAllPoints()
  Pixel.Point(border.top, "TOPLEFT", frame, "LEFT", left, yOffset + size * 0.5)
  Pixel.Size(border.top, size, edge)

  border.bottom:ClearAllPoints()
  Pixel.Point(border.bottom, "BOTTOMLEFT", frame, "LEFT", left, yOffset - size * 0.5)
  Pixel.Size(border.bottom, size, edge)

  border.left:ClearAllPoints()
  Pixel.Point(border.left, "LEFT", frame, "LEFT", left, yOffset)
  Pixel.Size(border.left, edge, size - edge * 2)

  border.right:ClearAllPoints()
  Pixel.Point(border.right, "RIGHT", frame, "LEFT", left + size, yOffset)
  Pixel.Size(border.right, edge, size - edge * 2)
end

local function SetCheckboxChromeColors(chrome, backgroundColor, borderColor)
  Pixel.SetColorTexture(chrome.background,
    backgroundColor[1],
    backgroundColor[2],
    backgroundColor[3],
    backgroundColor[4]
  )

  for _, texture in pairs(chrome.border) do
    Pixel.SetColorTexture(texture,
      borderColor[1],
      borderColor[2],
      borderColor[3],
      borderColor[4]
    )
  end
end

local function LayoutCheckboxText(widget, visual, visualSize, text)
  local frame = widget.frame
  local geom = Theme.GetWidgetRowGeometry(widget)
  local controlLeft = geom.controlLeft
  local controlRight = geom.controlRight
  local controlGap = geom.controlGap
  local image = widget.image
  local textLeft = controlLeft + visualSize + controlGap

  if image and image:GetTexture() then
    image:ClearAllPoints()
    Pixel.Point(image, "LEFT", visual, "RIGHT", controlGap, 0)
    Pixel.Size(image, 16, 16)
    image:Show()
    textLeft = textLeft + 16 + controlGap
  elseif image then
    image:Hide()
  end

  text:ClearAllPoints()
  text:SetJustifyH("LEFT")
  text:SetJustifyV("MIDDLE")

  if widget.__puiWrapLabel == true then
    Pixel.Point(text, "TOPLEFT", frame, "TOPLEFT", textLeft, -4)
    Pixel.Point(text, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -controlRight, 4)
    text:SetWordWrap(true)
    text:SetNonSpaceWrap(true)
  else
    Pixel.Point(text, "LEFT", frame, "LEFT", textLeft, geom.controlYOffset)
    Pixel.Point(text, "RIGHT", frame, "RIGHT", -controlRight, geom.controlYOffset)
    Pixel.Height(text, geom.controlHeight)
    text:SetWordWrap(false)
    text:SetNonSpaceWrap(false)
  end
end

local function RefreshCheckbox(widget)
  if widget.__puiAceGUIOwnedByPleebUI ~= true then
    return
  end

  local frame, check, anchor, text = ResolveCheckbox(widget)
  local colors = Theme.GetColors()
  local metrics = Theme.GetControlMetrics(widget)
  local geom = Theme.GetWidgetRowGeometry(widget)
  local checkedColor = colors.accent
  local controlType = ResolveControlType(widget, anchor)
  local isRadio = controlType == "radio"
  local visualSize = isRadio and 16 or metrics.checkboxBoxSize
  local chrome = EnsureCheckboxChrome(widget, frame)
  local value = widget:GetValue()

  anchor:ClearAllPoints()
  Pixel.Point(anchor, "LEFT", frame, "LEFT", geom.controlLeft, geom.controlYOffset)
  Pixel.Size(anchor, visualSize, visualSize)

  if isRadio then
    SetCheckboxChromeShown(chrome, false)

    Pixel.SetTexture(anchor, RADIO_TEXTURE)
    Pixel.SetTexCoord(anchor, 0, 0.25, 0, 1)
    anchor:SetAlpha(1)
    anchor:Show()

    check:ClearAllPoints()
    Pixel.AllPoints(check, anchor)
    Pixel.SetTexture(check, RADIO_TEXTURE)
    Pixel.SetTexCoord(check, 0.25, 0.5, 0, 1)
    check:SetBlendMode("ADD")
    check:SetAlpha(1)

    widget.highlight:ClearAllPoints()
    Pixel.AllPoints(widget.highlight, anchor)
    Pixel.SetTexture(widget.highlight, RADIO_TEXTURE)
    Pixel.SetTexCoord(widget.highlight, 0.5, 0.75, 0, 1)
    widget.highlight:SetBlendMode("ADD")
    widget.highlight:SetAlpha(1)

    if value or (widget.tristate and value == nil) then
      check:Show()
    else
      check:Hide()
    end
  else
    ClearTexture(anchor)
    ClearTexture(check)
    SetCheckboxChromeShown(chrome, true)
    LayoutCheckboxChrome(frame, chrome, geom.controlLeft, geom.controlYOffset, visualSize)

    local backgroundColor = widget.disabled and colors.disabledControl or colors.control
    local borderColor = widget.disabled and colors.disabledBorder or colors.border
    if widget.__puiCheckboxHovered and not widget.disabled then
      borderColor = colors.accent
    end

    SetCheckboxChromeColors(chrome, backgroundColor, borderColor)

    local fillInset = math.max(3, math.floor(visualSize * 0.18 + 0.5))
    chrome.fill:ClearAllPoints()
    Pixel.Point(
      chrome.fill,
      "TOPLEFT",
      frame,
      "LEFT",
      geom.controlLeft + fillInset,
      geom.controlYOffset + visualSize * 0.5 - fillInset
    )
    Pixel.Point(
      chrome.fill,
      "BOTTOMRIGHT",
      frame,
      "LEFT",
      geom.controlLeft + visualSize - fillInset,
      geom.controlYOffset - visualSize * 0.5 + fillInset
    )
    Pixel.SetTexture(chrome.fill, WHITE8)

    if value then
      Pixel.SetVertexColor(chrome.fill, checkedColor[1], checkedColor[2], checkedColor[3], 0.95)
      chrome.fill:Show()
    elseif widget.tristate and value == nil then
      local mutedText = colors.mutedText
      Pixel.SetVertexColor(chrome.fill,
        mutedText[1],
        mutedText[2],
        mutedText[3],
        mutedText[4]
      )
      chrome.fill:Show()
    else
      chrome.fill:Hide()
    end

    ClearTexture(widget.highlight)
  end

  LayoutCheckboxText(widget, anchor, visualSize, text)

  Theme.ApplyFont(text, "body")
  if widget.desc then
    Theme.ApplyFont(widget.desc, "body")
  end

  local textColor = widget.disabled and colors.disabledText or colors.text
  text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
  if widget.desc then
    widget.desc:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
  end
end

function WidgetSkins.Checkbox(widget)
  local _, _, anchor = ResolveCheckbox(widget)
  ResolveControlType(widget, anchor)

  if not widget.__puiCheckboxHooks then
    widget.__puiCheckboxHooks = true

    hooksecurefunc(widget, "SetValue", RefreshCheckbox)
    hooksecurefunc(widget, "SetDisabled", RefreshCheckbox)
    hooksecurefunc(widget, "SetLabel", RefreshCheckbox)
    hooksecurefunc(widget, "SetType", function(self, controlType)
      self.__puiCheckboxControlType = controlType == "radio" and "radio" or "checkbox"
      RefreshCheckbox(self)
    end)
    hooksecurefunc(widget, "SetImage", RefreshCheckbox)
    hooksecurefunc(widget, "SetDescription", RefreshCheckbox)
    widget.frame:HookScript("OnEnter", function()
      widget.__puiCheckboxHovered = true
      RefreshCheckbox(widget)
    end)
    widget.frame:HookScript("OnLeave", function()
      widget.__puiCheckboxHovered = nil
      RefreshCheckbox(widget)
    end)
    widget.frame:HookScript("OnHide", function()
      widget.__puiCheckboxHovered = nil
      RefreshCheckbox(widget)
    end)
  end

  RefreshCheckbox(widget)
end

local function PUI_Checkbox_OnEnter(frame)
  local widget = frame.obj

  if not widget.disabled then
    widget.__puiCheckboxHovered = true
    RefreshCheckbox(widget)
  end

  widget:Fire("OnEnter")
end

local function PUI_Checkbox_OnLeave(frame)
  local widget = frame.obj

  widget.__puiCheckboxHovered = nil
  RefreshCheckbox(widget)
  widget:Fire("OnLeave")
end

local function PUI_Checkbox_OnHide(frame)
  local widget = frame.obj

  widget.__puiCheckboxHovered = nil
  RefreshCheckbox(widget)
end

local function PUI_Checkbox_OnMouseDown()
  AceGUI:ClearFocus()
end

local function PUI_Checkbox_OnMouseUp(frame, button)
  local widget = frame.obj

  if button ~= "LeftButton" or widget.disabled then
    return
  end

  widget:ToggleChecked()

  if widget.checked then
    PlaySound(856)
  else
    PlaySound(857)
  end

  widget:Fire("OnValueChanged", widget.checked)
  RefreshCheckbox(widget)
end

local PUI_Checkbox_Methods = {
  OnAcquire = function(self)
    self.__puiCheckboxHovered = nil
    self:SetType("checkbox")
    self:SetValue(false)
    self:SetTriState(nil)
    self:SetWidth(200)
    self:SetImage(nil)
    self:SetDisabled(false)
    self:SetDescription(nil)
  end,

  OnRelease = function(self)
    self.__puiCheckboxHovered = nil
    self.__puiCheckboxControlType = nil
  end,

  OnWidthSet = function(self, width)
    if self.desc then
      Pixel.Width(self.desc, math.max(1, width - 30))
    end
    RefreshCheckbox(self)
  end,

  SetDisabled = function(self, disabled)
    self.disabled = disabled == true

    if self.disabled then
      self.frame:Disable()
      self.check:SetDesaturated(true)
    else
      self.frame:Enable()
      self.check:SetDesaturated(self.tristate and self.checked == nil)
    end

    RefreshCheckbox(self)
  end,

  SetValue = function(self, value)
    self.checked = value

    if value then
      self.check:SetDesaturated(false)
      self.check:Show()
    elseif self.tristate and value == nil then
      self.check:SetDesaturated(true)
      self.check:Show()
    else
      self.check:SetDesaturated(false)
      self.check:Hide()
    end

    RefreshCheckbox(self)
  end,

  GetValue = function(self)
    return self.checked
  end,

  SetTriState = function(self, enabled)
    self.tristate = enabled == true
    self:SetValue(self.checked)
  end,

  SetType = function(self, controlType)
    local isRadio = controlType == "radio"
    local size = isRadio and 16 or 24

    self.__puiCheckboxControlType = isRadio and "radio" or "checkbox"
    Pixel.Size(self.checkbg, size, size)

    if isRadio then
      Pixel.SetTexture(self.checkbg, RADIO_TEXTURE)
      Pixel.SetTexCoord(self.checkbg, 0, 0.25, 0, 1)
      Pixel.SetTexture(self.check, RADIO_TEXTURE)
      Pixel.SetTexCoord(self.check, 0.25, 0.5, 0, 1)
      self.check:SetBlendMode("ADD")
      Pixel.SetTexture(self.highlight, RADIO_TEXTURE)
      Pixel.SetTexCoord(self.highlight, 0.5, 0.75, 0, 1)
      self.highlight:SetBlendMode("ADD")
    else
      Pixel.SetTexture(self.checkbg, 130755)
      Pixel.SetTexCoord(self.checkbg, 0, 1, 0, 1)
      Pixel.SetTexture(self.check, 130751)
      Pixel.SetTexCoord(self.check, 0, 1, 0, 1)
      self.check:SetBlendMode("BLEND")
      Pixel.SetTexture(self.highlight, 130753)
      Pixel.SetTexCoord(self.highlight, 0, 1, 0, 1)
      self.highlight:SetBlendMode("ADD")
    end

    RefreshCheckbox(self)
  end,

  ToggleChecked = function(self)
    local value = self.checked

    if self.tristate then
      if value then
        self:SetValue(nil)
      elseif value == nil then
        self:SetValue(false)
      else
        self:SetValue(true)
      end
    else
      self:SetValue(not value)
    end
  end,

  SetLabel = function(self, label)
    self.text:SetText(label or "")
    RefreshCheckbox(self)
  end,

  SetDescription = function(self, description)
    if description and description ~= "" then
      if not self.desc then
        local desc = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc.__puiOptionsFontOwned = true
        Pixel.Point(desc, "TOPLEFT", self.checkbg, "TOPRIGHT", 5, -21)
        Pixel.Point(desc, "RIGHT", self.frame, "RIGHT", -30, 0)
        desc:SetJustifyH("LEFT")
        desc:SetJustifyV("TOP")
        self.desc = desc
      end

      self.desc:SetText(description)
      self.desc:Show()
    elseif self.desc then
      self.desc:SetText("")
      self.desc:Hide()
    end

    RefreshCheckbox(self)
  end,

  SetImage = function(self, path, ...)
    Pixel.SetTexture(self.image, path)

    if self.image:GetTexture() then
      local count = select("#", ...)
      if count == 4 or count == 8 then
        Pixel.SetTexCoord(self.image, ...)
      else
        Pixel.SetTexCoord(self.image, 0, 1, 0, 1)
      end
    end

    RefreshCheckbox(self)
  end,

  RefreshTheme = RefreshCheckbox,
}

local function PUI_Checkbox_Constructor()
  local frame = CreateFrame("Button", nil, UIParent)
  frame:Hide()
  frame:EnableMouse(true)
  frame:RegisterForClicks("LeftButtonUp")
  frame:SetScript("OnEnter", PUI_Checkbox_OnEnter)
  frame:SetScript("OnLeave", PUI_Checkbox_OnLeave)
  frame:SetScript("OnMouseDown", PUI_Checkbox_OnMouseDown)
  frame:SetScript("OnMouseUp", PUI_Checkbox_OnMouseUp)
  frame:SetScript("OnHide", PUI_Checkbox_OnHide)

  local checkbg = frame:CreateTexture(nil, "ARTWORK")
  Pixel.Point(checkbg, "TOPLEFT")
  Pixel.Size(checkbg, 24, 24)
  Pixel.SetTexture(checkbg, 130755)

  local check = frame:CreateTexture(nil, "OVERLAY")
  Pixel.AllPoints(check, checkbg)
  Pixel.SetTexture(check, 130751)

  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text.__puiOptionsFontOwned = true
  Pixel.Point(text, "LEFT", checkbg, "RIGHT")
  Pixel.Point(text, "RIGHT")
  Pixel.Height(text, 18)
  text:SetJustifyH("LEFT")

  local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
  Pixel.AllPoints(highlight, checkbg)
  Pixel.SetTexture(highlight, 130753)
  highlight:SetBlendMode("ADD")

  local image = frame:CreateTexture(nil, "OVERLAY")
  Pixel.Point(image, "LEFT", checkbg, "RIGHT", 1, 0)
  Pixel.Size(image, 16, 16)

  local widget = {
    type = PUI_CHECKBOX_TYPE,
    frame = frame,
    checkbg = checkbg,
    check = check,
    text = text,
    highlight = highlight,
    image = image,
    alignoffset = 0,
  }

  for method, func in pairs(PUI_Checkbox_Methods) do
    widget[method] = func
  end

  frame.obj = widget

  return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(PUI_CHECKBOX_TYPE, PUI_Checkbox_Constructor, PUI_CHECKBOX_VERSION)
