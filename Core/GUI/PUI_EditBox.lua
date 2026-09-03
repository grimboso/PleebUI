local _, ns = ...

local Theme = ns.Theme
local WidgetSkins = Theme.WidgetSkins
local AceGUI = LibStub("AceGUI-3.0")

local ClearCursor = _G.ClearCursor
local CreateFrame = _G.CreateFrame
local C_Spell = _G.C_Spell
local GetCursorInfo = _G.GetCursorInfo
local GetMacroInfo = _G.GetMacroInfo
local PlaySound = _G.PlaySound
local UIParent = _G.UIParent
local pairs = _G.pairs
local tonumber = _G.tonumber
local tostring = _G.tostring
local math_max = _G.math.max

local WHITE8 = "Interface\\Buttons\\WHITE8x8"

local function HideEditBoxTexture(texture)
  if texture then
    texture:SetTexture(nil)
    texture:SetAlpha(0)
    texture:Hide()
  end
end

function WidgetSkins.UIEditBox(edit)
  HideEditBoxTexture(edit.Left)
  HideEditBoxTexture(edit.Right)
  HideEditBoxTexture(edit.Middle)
  HideEditBoxTexture(edit.LeftDisabled)
  HideEditBoxTexture(edit.RightDisabled)
  HideEditBoxTexture(edit.MiddleDisabled)
  HideEditBoxTexture(edit.left)
  HideEditBoxTexture(edit.right)
  HideEditBoxTexture(edit.middle)

  if edit.NineSlice then
    edit.NineSlice:Hide()
  end

  if edit.SetBackdrop then
    edit:SetBackdrop(nil)
  end

  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(edit, {
    bg = colors.control,
    border = colors.border,
  }, math.max(Theme.GetEdgeSize(), 2))

  Theme.ApplyFont(edit, "body")
  edit:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])

  if edit.Instructions then
    Theme.ApplyFont(edit.Instructions, "body")
    edit.Instructions:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 0.55)
  end
end

function WidgetSkins.EditBox(widget)
  local isMultiLine = widget.type == "MultiLineEditBox"
  local frame = widget.frame
  local button = widget.button
  local label = widget.label
  local colors = Theme.GetColors()
  local geom = Theme.GetWidgetRowGeometry()

  if isMultiLine then
    local edit = widget.editBox
    local background = widget.scrollBG

    background:SetBackdrop(nil)
    Theme.SetSquareBackdrop(background, {
      bg = colors.control,
      border = colors.border,
    }, math.max(Theme.GetEdgeSize(), 2))

    Theme.ApplyFont(edit, "body")
    edit:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])

    WidgetSkins.Button(button, widget)
    WidgetSkins.Scrollbar(widget.scrollBar)
  else
    local edit = widget.editbox
    local controlHeight = geom.controlHeight
    local buttonWidth = geom.buttonWidth

    for _, texture in ipairs({
      edit.Left,
      edit.Right,
      edit.Middle,
      edit.LeftDisabled,
      edit.RightDisabled,
      edit.MiddleDisabled,
    }) do
      if texture then
        texture:Hide()
      end
    end

    edit:ClearAllPoints()
    edit:SetPoint("TOPLEFT", frame, "TOPLEFT", geom.controlLeft, -geom.controlTop)
    edit:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -geom.controlRight, -geom.controlTop)
    edit:SetHeight(controlHeight)

    local bg = Theme.EnsureBackdropFrame(edit)
    local edge = math.max(Theme.GetEdgeSize(), 2)

    bg:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = edge,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bg:SetBackdropColor(colors.control[1], colors.control[2], colors.control[3], colors.control[4])
    bg:SetBackdropBorderColor(colors.border[1], colors.border[2], colors.border[3], colors.border[4])

    bg:ClearAllPoints()
    if edit.NineSlice then
      bg:SetAllPoints(edit)
    else
      bg:SetPoint("TOPLEFT", edit, "TOPLEFT", 0, -2)
      bg:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", -1, 1)
    end

    bg:SetFrameStrata(edit:GetFrameStrata())
    bg:SetFrameLevel(math.max(edit:GetFrameLevel() - 1, 0))
    bg:EnableMouse(false)
    edit._puiBg = bg

    WidgetSkins.Button(button, widget)
    button:SetSize(buttonWidth, controlHeight - 4)
    button:ClearAllPoints()
    button:SetPoint("RIGHT", bg, "RIGHT", -2, 0)
    button:SetParent(bg)

    Theme.ApplyFont(edit, "body")
    edit:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])

    if not edit.__puiTextInsetsHooked then
      edit.__puiTextInsetsHooked = true
      hooksecurefunc(edit, "SetTextInsets", function(self, left, right, top, bottom)
        if self.obj and self.obj.__puiAceGUIOwnedByPleebUI ~= true then
          return
        end

        if (tonumber(left) or 0) == 0 then
          self:SetTextInsets(3, right, top, bottom)
        end
      end)
    end

    edit:SetTextInsets(3, buttonWidth + 6, 0, 0)
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("MIDDLE")

    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", geom.labelLeft, -geom.labelTop)
    label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -geom.labelRight, -geom.labelTop)
    label:SetHeight(geom.labelHeight)
    label:SetJustifyH("CENTER")
  end

  Theme.ApplyFont(label, "body")
  label:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])

  if not widget.__puiEditBoxGeometrySetLabelHooked then
    widget.__puiEditBoxGeometrySetLabelHooked = true
    hooksecurefunc(widget, "SetLabel", function(self)
      if self.__puiAceGUIOwnedByPleebUI == true then
        WidgetSkins.EditBox(self)
      end
    end)
  end
end
local PUI_EDITBOX_TYPE = "PUI_EditBox"
local PUI_EDITBOX_VERSION = 1
local PUI_MULTILINE_EDITBOX_TYPE = "PUI_MultiLineEditBox"
local PUI_MULTILINE_EDITBOX_VERSION = 1

local function PUI_EditBox_SetTextureColor(texture, color, alphaMultiplier)
  texture:SetColorTexture(
    color[1],
    color[2],
    color[3],
    (color[4] or 1) * (alphaMultiplier or 1)
  )
end

local function PUI_EditBox_CreateChrome(parent)
  local background = parent:CreateTexture(nil, "BACKGROUND")
  background:SetTexture(WHITE8)

  local border = {
    top = parent:CreateTexture(nil, "BORDER"),
    bottom = parent:CreateTexture(nil, "BORDER"),
    left = parent:CreateTexture(nil, "BORDER"),
    right = parent:CreateTexture(nil, "BORDER"),
  }

  for _, texture in pairs(border) do
    texture:SetTexture(WHITE8)
  end

  return {
    background = background,
    border = border,
  }
end

local function PUI_EditBox_LayoutChrome(parent, chrome)
  local edge = Theme.GetEdgeSize()
  local border = chrome.border

  chrome.background:ClearAllPoints()
  chrome.background:SetPoint("TOPLEFT", parent, "TOPLEFT", edge, -edge)
  chrome.background:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -edge, edge)

  border.top:ClearAllPoints()
  border.top:SetPoint("TOPLEFT", parent, "TOPLEFT")
  border.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
  border.top:SetHeight(edge)

  border.bottom:ClearAllPoints()
  border.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT")
  border.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
  border.bottom:SetHeight(edge)

  border.left:ClearAllPoints()
  border.left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -edge)
  border.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, edge)
  border.left:SetWidth(edge)

  border.right:ClearAllPoints()
  border.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -edge)
  border.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, edge)
  border.right:SetWidth(edge)
end

local function PUI_EditBox_SetChromeColors(chrome, backgroundColor, borderColor, alphaMultiplier)
  PUI_EditBox_SetTextureColor(chrome.background, backgroundColor, alphaMultiplier)

  for _, texture in pairs(chrome.border) do
    PUI_EditBox_SetTextureColor(texture, borderColor, alphaMultiplier)
  end
end

local function PUI_EditBox_InsertLink(text)
  for index = 1, AceGUI:GetWidgetCount(PUI_EDITBOX_TYPE) do
    local editbox = _G["PUIAceGUIEditBox" .. index]

    if editbox and editbox:IsVisible() and editbox:HasFocus() then
      editbox:Insert(text)
      return
    end
  end

  for index = 1, AceGUI:GetWidgetCount(PUI_MULTILINE_EDITBOX_TYPE) do
    local editbox = _G["PUIAceGUIMultiLineEditBox" .. index .. "Edit"]

    if editbox and editbox:IsVisible() and editbox:HasFocus() then
      editbox:Insert(text)
      return
    end
  end
end

if not _G.__puiAceGUIEditBoxInsertLinkHooked then
  _G.__puiAceGUIEditBoxInsertLinkHooked = true
  hooksecurefunc(_G.ChatFrameUtil, "InsertLink", PUI_EditBox_InsertLink)
end

local function PUI_EditBox_ShowButton(widget)
  if widget.disablebutton or widget.disabled then
    return
  end

  widget.buttonPending = true
  widget.button:Show()
  widget.button:Enable()
  widget.editbox:SetTextInsets(4, Theme.GetWidgetRowGeometry().buttonWidth + 6, 0, 0)
end

local function PUI_EditBox_HideButton(widget)
  widget.buttonPending = nil
  widget.button:Hide()
  widget.editbox:SetTextInsets(4, 4, 0, 0)
end

local function PUI_EditBox_Layout(widget, width)
  local geom = Theme.GetWidgetRowGeometry()
  local frameWidth = tonumber(width) or widget.frame:GetWidth() or 200
  local controlTop = widget.label:IsShown()
    and geom.controlTop
    or math_max(0, ((widget.frame:GetHeight() or geom.rowHeight) - geom.controlHeight) * 0.5)

  widget.label:ClearAllPoints()
  widget.label:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", geom.labelLeft, -geom.labelTop)
  widget.label:SetPoint("TOPRIGHT", widget.frame, "TOPRIGHT", -geom.labelRight, -geom.labelTop)
  widget.label:SetHeight(geom.labelHeight)

  widget.editbox:ClearAllPoints()
  widget.editbox:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", geom.controlLeft, -controlTop)
  widget.editbox:SetPoint("TOPRIGHT", widget.frame, "TOPRIGHT", -geom.controlRight, -controlTop)
  widget.editbox:SetHeight(geom.controlHeight)

  widget.button:ClearAllPoints()
  widget.button:SetPoint("TOPRIGHT", widget.editbox, "TOPRIGHT", -2, -2)
  widget.button:SetPoint("BOTTOMRIGHT", widget.editbox, "BOTTOMRIGHT", -2, 2)
  widget.button:SetWidth(geom.buttonWidth)

  PUI_EditBox_LayoutChrome(widget.editbox, widget.editboxChrome)
  PUI_EditBox_LayoutChrome(widget.button, widget.buttonChrome)
  widget.frame:SetWidth(frameWidth)
end

local function PUI_EditBox_RefreshVisualState(widget)
  local colors = Theme.GetColors()
  local disabled = widget.disabled == true
  local hovered = widget.editbox.__puiHovered == true
  local textColor = disabled and colors.disabledText or colors.text
  local controlColor = disabled and colors.disabledControl or colors.control
  local borderColor = disabled and colors.disabledBorder or colors.border

  if hovered and not disabled then
    borderColor = colors.accent
  end

  PUI_EditBox_SetChromeColors(widget.editboxChrome, controlColor, borderColor, 1)
  PUI_EditBox_SetChromeColors(
    widget.buttonChrome,
    controlColor,
    disabled and colors.disabledBorder or colors.border,
    1
  )

  widget.label:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
  widget.editbox:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
  widget.buttonText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
end

local function PUI_EditBox_OnEnter(editbox)
  local widget = editbox.obj
  editbox.__puiHovered = true
  PUI_EditBox_RefreshVisualState(widget)
  widget:Fire("OnEnter")
end

local function PUI_EditBox_OnLeave(editbox)
  local widget = editbox.obj
  editbox.__puiHovered = nil
  PUI_EditBox_RefreshVisualState(widget)
  widget:Fire("OnLeave")
end

local function PUI_EditBox_OnEscapePressed()
  AceGUI:ClearFocus()
end

local function PUI_EditBox_OnEnterPressed(editbox)
  local widget = editbox.obj
  local value = editbox:GetText()
  local cancel = widget:Fire("OnEnterPressed", value)

  if not cancel then
    PlaySound(856)
    PUI_EditBox_HideButton(widget)
  end
end

local function PUI_EditBox_OnTextChanged(editbox)
  local widget = editbox.obj
  local value = editbox:GetText()

  if tostring(value) ~= tostring(widget.lasttext) then
    widget:Fire("OnTextChanged", value)
    widget.lasttext = value
    PUI_EditBox_ShowButton(widget)
  end
end

local function PUI_EditBox_OnFocusGained(editbox)
  AceGUI:SetFocus(editbox.obj)
end

local function PUI_EditBox_OnReceiveDrag(editbox)
  local widget = editbox.obj
  local cursorType, id, info, extra = GetCursorInfo()
  local value

  if cursorType == "item" then
    value = info
  elseif cursorType == "spell" then
    value = extra and C_Spell.GetSpellName(extra)
  elseif cursorType == "macro" then
    value = GetMacroInfo(id)
  end

  if value == nil then
    return
  end

  widget:SetText(value)
  widget:Fire("OnEnterPressed", value)
  ClearCursor()
  PUI_EditBox_HideButton(widget)
  AceGUI:ClearFocus()
end

local function PUI_EditBox_ButtonOnClick(button)
  local editbox = button.obj.editbox
  editbox:ClearFocus()
  PUI_EditBox_OnEnterPressed(editbox)
end

local function PUI_EditBox_OnShowFocus(frame)
  frame.obj.editbox:SetFocus()
  frame:SetScript("OnShow", nil)
end

local PUI_EditBox_Methods = {
  OnAcquire = function(self)
    self:SetHeight(Theme.GetControlMetrics().widgetBoxHeight)
    self:SetWidth(200)
    self:SetDisabled(false)
    self:SetLabel(nil)
    self:SetText(nil)
    self:DisableButton(false)
    self:SetMaxLetters(0)
    self.editbox.__puiHovered = nil
    self:RefreshTheme()
  end,

  OnRelease = function(self)
    self:ClearFocus()
    self.editbox.__puiHovered = nil
    self.buttonPending = nil
  end,

  OnWidthSet = function(self, width)
    PUI_EditBox_Layout(self, width)
  end,

  OnHeightSet = function(self)
    PUI_EditBox_Layout(self, self.frame:GetWidth())
  end,

  SetDisabled = function(self, disabled)
    disabled = disabled == true
    self.disabled = disabled
    self.editbox:EnableMouse(not disabled)

    if disabled then
      self.editbox.__puiHovered = nil
      self.editbox:ClearFocus()
      self.button:Disable()
    elseif self.buttonPending and not self.disablebutton then
      self.button:Enable()
    end

    PUI_EditBox_RefreshVisualState(self)
  end,

  SetText = function(self, text)
    self.lasttext = text or ""
    self.editbox:SetText(self.lasttext)
    self.editbox:SetCursorPosition(0)
    PUI_EditBox_HideButton(self)
  end,

  GetText = function(self)
    return self.editbox:GetText()
  end,

  SetLabel = function(self, text)
    if text and text ~= "" then
      self.label:SetText(text)
      self.label:Show()
    else
      self.label:SetText("")
      self.label:Hide()
    end

    PUI_EditBox_Layout(self, self.frame:GetWidth())
  end,

  DisableButton = function(self, disabled)
    self.disablebutton = disabled == true

    if self.disablebutton then
      PUI_EditBox_HideButton(self)
    elseif self.buttonPending and not self.disabled then
      PUI_EditBox_ShowButton(self)
    end
  end,

  SetMaxLetters = function(self, count)
    self.editbox:SetMaxLetters(count or 0)
  end,

  ClearFocus = function(self)
    self.editbox:ClearFocus()
    self.frame:SetScript("OnShow", nil)
  end,

  SetFocus = function(self)
    self.editbox:SetFocus()

    if not self.frame:IsShown() then
      self.frame:SetScript("OnShow", PUI_EditBox_OnShowFocus)
    end
  end,

  HighlightText = function(self, from, to)
    self.editbox:HighlightText(from, to)
  end,

  RefreshTheme = function(self)
    Theme.ApplyFont(self.label, "body")
    Theme.ApplyFont(self.editbox, "body")
    Theme.ApplyFont(self.buttonText, "body")
    PUI_EditBox_Layout(self, self.frame:GetWidth())
    PUI_EditBox_RefreshVisualState(self)
  end,
}

local function PUI_EditBox_Constructor()
  local widgetNumber = AceGUI:GetNextWidgetNum(PUI_EDITBOX_TYPE)
  local frame = CreateFrame("Frame", nil, UIParent)

  local label = frame:CreateFontString(nil, "OVERLAY")
  label.__puiOptionsFontOwned = true
  label:SetJustifyH("CENTER")
  label:SetJustifyV("MIDDLE")
  Theme.ApplyFont(label, "body")

  local editbox = CreateFrame("EditBox", "PUIAceGUIEditBox" .. widgetNumber, frame)
  editbox.__puiOptionsFontOwned = true
  editbox:SetAutoFocus(false)
  editbox:SetJustifyH("LEFT")
  editbox:SetJustifyV("MIDDLE")
  editbox:SetTextInsets(4, 4, 0, 0)
  editbox:EnableMouse(true)
  Theme.ApplyFont(editbox, "body")
  editbox:SetScript("OnEnter", PUI_EditBox_OnEnter)
  editbox:SetScript("OnLeave", PUI_EditBox_OnLeave)
  editbox:SetScript("OnEscapePressed", PUI_EditBox_OnEscapePressed)
  editbox:SetScript("OnEnterPressed", PUI_EditBox_OnEnterPressed)
  editbox:SetScript("OnTextChanged", PUI_EditBox_OnTextChanged)
  editbox:SetScript("OnReceiveDrag", PUI_EditBox_OnReceiveDrag)
  editbox:SetScript("OnMouseDown", PUI_EditBox_OnReceiveDrag)
  editbox:SetScript("OnEditFocusGained", PUI_EditBox_OnFocusGained)

  local button = CreateFrame("Button", nil, frame)
  button:RegisterForClicks("LeftButtonUp")
  button:SetScript("OnClick", PUI_EditBox_ButtonOnClick)

  local buttonText = button:CreateFontString(nil, "OVERLAY")
  buttonText.__puiOptionsFontOwned = true
  buttonText:SetAllPoints(button)
  buttonText:SetJustifyH("CENTER")
  buttonText:SetJustifyV("MIDDLE")
  Theme.ApplyFont(buttonText, "body")
  buttonText:SetText(OKAY)

  local widget = {
    type = PUI_EDITBOX_TYPE,
    frame = frame,
    label = label,
    editbox = editbox,
    editboxChrome = PUI_EditBox_CreateChrome(editbox),
    button = button,
    buttonText = buttonText,
    buttonChrome = PUI_EditBox_CreateChrome(button),
    alignoffset = 0,
  }

  for method, func in pairs(PUI_EditBox_Methods) do
    widget[method] = func
  end

  frame.obj = widget
  editbox.obj = widget
  button.obj = widget

  PUI_EditBox_Layout(widget, 200)
  PUI_EditBox_RefreshVisualState(widget)
  PUI_EditBox_HideButton(widget)

  return AceGUI:RegisterAsWidget(widget)
end

local function PUI_MultiLine_Layout(widget)
  local geom = Theme.GetWidgetRowGeometry()
  local labelBottom = widget.label:IsShown() and (geom.labelTop + geom.labelHeight + 4) or 4
  local buttonSpace = widget.disablebutton and 4 or (geom.controlHeight + 8)

  widget.label:ClearAllPoints()
  widget.label:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", geom.labelLeft, -geom.labelTop)
  widget.label:SetPoint("TOPRIGHT", widget.frame, "TOPRIGHT", -geom.labelRight, -geom.labelTop)
  widget.label:SetHeight(geom.labelHeight)

  widget.button:ClearAllPoints()
  widget.button:SetPoint("BOTTOMLEFT", widget.frame, "BOTTOMLEFT", geom.controlLeft, 4)
  widget.button:SetSize(math_max(72, geom.buttonWidth * 2), geom.controlHeight)

  widget.scrollBG:ClearAllPoints()
  widget.scrollBG:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", geom.controlLeft, -labelBottom)
  widget.scrollBG:SetPoint("TOPRIGHT", widget.frame, "TOPRIGHT", -geom.controlRight, -labelBottom)
  widget.scrollBG:SetPoint("BOTTOMLEFT", widget.frame, "BOTTOMLEFT", geom.controlLeft, buttonSpace)
  widget.scrollBG:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", -geom.controlRight, buttonSpace)

  widget.scrollFrame:ClearAllPoints()
  widget.scrollFrame:SetPoint("TOPLEFT", widget.scrollBG, "TOPLEFT", 5, -5)
  widget.scrollFrame:SetPoint("BOTTOMRIGHT", widget.scrollBG, "BOTTOMRIGHT", -20, 5)

  widget.scrollBar:ClearAllPoints()
  widget.scrollBar:SetPoint("TOPRIGHT", widget.scrollBG, "TOPRIGHT", -2, -3)
  widget.scrollBar:SetPoint("BOTTOMRIGHT", widget.scrollBG, "BOTTOMRIGHT", -2, 3)

  PUI_EditBox_LayoutChrome(widget.scrollBG, widget.scrollChrome)
  PUI_EditBox_LayoutChrome(widget.button, widget.buttonChrome)
end

local function PUI_MultiLine_UpdateHeight(widget)
  local geom = Theme.GetWidgetRowGeometry()
  local labelSpace = widget.label:IsShown() and (geom.labelHeight + 8) or 4
  local buttonSpace = widget.disablebutton and 8 or (geom.controlHeight + 12)
  local height = math_max(140, (widget.numlines or 4) * 14 + labelSpace + buttonSpace + 12)

  widget:SetHeight(height)
end

local function PUI_MultiLine_RefreshVisualState(widget)
  local colors = Theme.GetColors()
  local disabled = widget.disabled == true
  local textColor = disabled and colors.disabledText or colors.text
  local controlColor = disabled and colors.disabledControl or colors.control
  local borderColor = disabled and colors.disabledBorder or colors.border

  PUI_EditBox_SetChromeColors(widget.scrollChrome, controlColor, borderColor, 1)
  PUI_EditBox_SetChromeColors(widget.buttonChrome, controlColor, borderColor, 1)

  widget.label:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
  widget.editBox:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
  widget.buttonText:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
end

local function PUI_MultiLine_OnButtonClick(button)
  local widget = button.obj
  widget.editBox:ClearFocus()

  if not widget:Fire("OnEnterPressed", widget.editBox:GetText()) then
    widget.buttonPending = nil
    widget.button:Disable()
  end
end

local function PUI_MultiLine_OnCursorChanged(editbox, _, y, _, cursorHeight)
  local scrollFrame = editbox.obj.scrollFrame
  y = -y

  local offset = scrollFrame:GetVerticalScroll()
  if y < offset then
    scrollFrame:SetVerticalScroll(y)
    return
  end

  local bottom = y + cursorHeight - scrollFrame:GetHeight()
  if bottom > offset then
    scrollFrame:SetVerticalScroll(bottom)
  end
end

local function PUI_MultiLine_OnEditFocusLost(editbox)
  editbox:HighlightText(0, 0)
  editbox.obj:Fire("OnEditFocusLost")
end

local function PUI_MultiLine_OnEditFocusGained(editbox)
  AceGUI:SetFocus(editbox.obj)
  editbox.obj:Fire("OnEditFocusGained")
end

local function PUI_MultiLine_OnEnter(frame)
  local widget = frame.obj

  if not widget.entered then
    widget.entered = true
    widget:Fire("OnEnter")
  end
end

local function PUI_MultiLine_OnLeave(frame)
  local widget = frame.obj

  if widget.entered then
    widget.entered = nil
    widget:Fire("OnLeave")
  end
end

local function PUI_MultiLine_OnMouseUp(scrollFrame)
  local editBox = scrollFrame.obj.editBox
  editBox:SetFocus()
  editBox:SetCursorPosition(editBox:GetNumLetters())
end

local function PUI_MultiLine_OnReceiveDrag(frame)
  local widget = frame.obj
  local cursorType, _, info, extra = GetCursorInfo()

  if cursorType == "spell" then
    info = extra and C_Spell.GetSpellName(extra)
  elseif cursorType ~= "item" then
    return
  end

  if info == nil then
    return
  end

  ClearCursor()

  local editBox = widget.editBox
  if not editBox:HasFocus() then
    editBox:SetFocus()
    editBox:SetCursorPosition(editBox:GetNumLetters())
  end

  editBox:Insert(info)
  widget.buttonPending = true

  if not widget.disablebutton and not widget.disabled then
    widget.button:Enable()
  end
end

local function PUI_MultiLine_OnSizeChanged(scrollFrame, width)
  scrollFrame.obj.editBox:SetWidth(width)
end

local function PUI_MultiLine_OnTextChanged(editbox, userInput)
  if not userInput then
    return
  end

  local widget = editbox.obj
  widget:Fire("OnTextChanged", editbox:GetText())
  widget.buttonPending = true

  if not widget.disablebutton and not widget.disabled then
    widget.button:Enable()
  end
end

local function PUI_MultiLine_OnTextSet(editbox)
  editbox:HighlightText(0, 0)
  editbox:SetCursorPosition(editbox:GetNumLetters())
  editbox:SetCursorPosition(0)
  editbox.obj.buttonPending = nil
  editbox.obj.button:Disable()
end

local function PUI_MultiLine_OnVerticalScroll(scrollFrame, offset)
  local editBox = scrollFrame.obj.editBox
  editBox:SetHitRectInsets(0, 0, offset, editBox:GetHeight() - offset - scrollFrame:GetHeight())
end

local function PUI_MultiLine_OnScrollRangeChanged(scrollFrame, _, verticalRange)
  if verticalRange == 0 then
    scrollFrame.obj.editBox:SetHitRectInsets(0, 0, 0, 0)
  else
    PUI_MultiLine_OnVerticalScroll(scrollFrame, scrollFrame:GetVerticalScroll())
  end
end

local function PUI_MultiLine_OnShowFocus(frame)
  frame.obj.editBox:SetFocus()
  frame:SetScript("OnShow", nil)
end

local PUI_MultiLine_Methods = {
  OnAcquire = function(self)
    self:SetWidth(200)
    self:SetDisabled(false)
    self:SetLabel(nil)
    self:DisableButton(false)
    self:SetNumLines(4)
    self:SetMaxLetters(0)
    self:SetText("")
    self.entered = nil
    self:RefreshTheme()
  end,

  OnRelease = function(self)
    self:ClearFocus()
    self.entered = nil
    self.buttonPending = nil
  end,

  OnWidthSet = function(self)
    PUI_MultiLine_Layout(self)
  end,

  OnHeightSet = function(self)
    PUI_MultiLine_Layout(self)
  end,

  SetDisabled = function(self, disabled)
    disabled = disabled == true
    self.disabled = disabled
    self.editBox:EnableMouse(not disabled)
    self.scrollFrame:EnableMouse(not disabled)

    if disabled then
      self.editBox:ClearFocus()
      self.button:Disable()
    elseif self.buttonPending and not self.disablebutton then
      self.button:Enable()
    end

    PUI_MultiLine_RefreshVisualState(self)
  end,

  SetLabel = function(self, text)
    if text and text ~= "" then
      self.label:SetText(text)
      self.label:Show()
    else
      self.label:SetText("")
      self.label:Hide()
    end

    PUI_MultiLine_UpdateHeight(self)
  end,

  SetNumLines = function(self, count)
    self.numlines = math_max(4, tonumber(count) or 4)
    PUI_MultiLine_UpdateHeight(self)
  end,

  SetText = function(self, text)
    self.editBox:SetText(text or "")
  end,

  GetText = function(self)
    return self.editBox:GetText()
  end,

  SetMaxLetters = function(self, count)
    self.editBox:SetMaxLetters(count or 0)
  end,

  DisableButton = function(self, disabled)
    self.disablebutton = disabled == true

    if self.disablebutton then
      self.button:Hide()
    else
      self.button:Show()

      if self.buttonPending and not self.disabled then
        self.button:Enable()
      else
        self.button:Disable()
      end
    end

    PUI_MultiLine_UpdateHeight(self)
  end,

  ClearFocus = function(self)
    self.editBox:ClearFocus()
    self.frame:SetScript("OnShow", nil)
  end,

  SetFocus = function(self)
    self.editBox:SetFocus()

    if not self.frame:IsShown() then
      self.frame:SetScript("OnShow", PUI_MultiLine_OnShowFocus)
    end
  end,

  HighlightText = function(self, from, to)
    self.editBox:HighlightText(from, to)
  end,

  GetCursorPosition = function(self)
    return self.editBox:GetCursorPosition()
  end,

  SetCursorPosition = function(self, ...)
    return self.editBox:SetCursorPosition(...)
  end,

  RefreshTheme = function(self)
    Theme.ApplyFont(self.label, "body")
    Theme.ApplyFont(self.editBox, "body")
    Theme.ApplyFont(self.buttonText, "body")
    WidgetSkins.Scrollbar(self.scrollBar)
    PUI_MultiLine_Layout(self)
    PUI_MultiLine_RefreshVisualState(self)
  end,
}

local function PUI_MultiLine_Constructor()
  local widgetNumber = AceGUI:GetNextWidgetNum(PUI_MULTILINE_EDITBOX_TYPE)
  local frame = CreateFrame("Frame", nil, UIParent)

  local label = frame:CreateFontString(nil, "OVERLAY")
  label.__puiOptionsFontOwned = true
  label:SetJustifyH("CENTER")
  label:SetJustifyV("MIDDLE")
  Theme.ApplyFont(label, "body")

  local button = CreateFrame("Button", nil, frame)
  button:RegisterForClicks("LeftButtonUp")
  button:SetScript("OnClick", PUI_MultiLine_OnButtonClick)

  local buttonText = button:CreateFontString(nil, "OVERLAY")
  buttonText.__puiOptionsFontOwned = true
  buttonText:SetAllPoints(button)
  buttonText:SetJustifyH("CENTER")
  buttonText:SetJustifyV("MIDDLE")
  Theme.ApplyFont(buttonText, "body")
  buttonText:SetText(ACCEPT)

  local scrollBG = CreateFrame("Frame", nil, frame)
  local scrollFrame = CreateFrame(
    "ScrollFrame",
    "PUIAceGUIMultiLineEditBox" .. widgetNumber .. "ScrollFrame",
    frame,
    "UIPanelScrollFrameTemplate"
  )
  local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
  local editBox = CreateFrame(
    "EditBox",
    "PUIAceGUIMultiLineEditBox" .. widgetNumber .. "Edit",
    scrollFrame
  )

  editBox.__puiOptionsFontOwned = true
  editBox:SetAllPoints(scrollFrame)
  editBox:SetMultiLine(true)
  editBox:EnableMouse(true)
  editBox:SetAutoFocus(false)
  editBox:SetCountInvisibleLetters(false)
  Theme.ApplyFont(editBox, "body")
  editBox:SetScript("OnCursorChanged", PUI_MultiLine_OnCursorChanged)
  editBox:SetScript("OnEditFocusLost", PUI_MultiLine_OnEditFocusLost)
  editBox:SetScript("OnEditFocusGained", PUI_MultiLine_OnEditFocusGained)
  editBox:SetScript("OnEnter", PUI_MultiLine_OnEnter)
  editBox:SetScript("OnLeave", PUI_MultiLine_OnLeave)
  editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
  editBox:SetScript("OnMouseDown", PUI_MultiLine_OnReceiveDrag)
  editBox:SetScript("OnReceiveDrag", PUI_MultiLine_OnReceiveDrag)
  editBox:SetScript("OnTextChanged", PUI_MultiLine_OnTextChanged)
  editBox:SetScript("OnTextSet", PUI_MultiLine_OnTextSet)

  scrollFrame:SetScrollChild(editBox)
  scrollFrame:SetScript("OnEnter", PUI_MultiLine_OnEnter)
  scrollFrame:SetScript("OnLeave", PUI_MultiLine_OnLeave)
  scrollFrame:SetScript("OnMouseUp", PUI_MultiLine_OnMouseUp)
  scrollFrame:SetScript("OnReceiveDrag", PUI_MultiLine_OnReceiveDrag)
  scrollFrame:SetScript("OnSizeChanged", PUI_MultiLine_OnSizeChanged)
  scrollFrame:HookScript("OnVerticalScroll", PUI_MultiLine_OnVerticalScroll)
  scrollFrame:HookScript("OnScrollRangeChanged", PUI_MultiLine_OnScrollRangeChanged)

  local widget = {
    type = PUI_MULTILINE_EDITBOX_TYPE,
    frame = frame,
    label = label,
    button = button,
    buttonText = buttonText,
    buttonChrome = PUI_EditBox_CreateChrome(button),
    scrollBG = scrollBG,
    scrollChrome = PUI_EditBox_CreateChrome(scrollBG),
    scrollFrame = scrollFrame,
    scrollBar = scrollBar,
    editBox = editBox,
    numlines = 4,
    alignoffset = 0,
  }

  for method, func in pairs(PUI_MultiLine_Methods) do
    widget[method] = func
  end

  frame.obj = widget
  button.obj = widget
  editBox.obj = widget
  scrollFrame.obj = widget

  widget = AceGUI:RegisterAsWidget(widget)
  PUI_MultiLine_UpdateHeight(widget)
  PUI_MultiLine_Layout(widget)
  PUI_MultiLine_RefreshVisualState(widget)

  return widget
end

AceGUI:RegisterWidgetType(PUI_EDITBOX_TYPE, PUI_EditBox_Constructor, PUI_EDITBOX_VERSION)
AceGUI:RegisterWidgetType(
  PUI_MULTILINE_EDITBOX_TYPE,
  PUI_MultiLine_Constructor,
  PUI_MULTILINE_EDITBOX_VERSION
)
