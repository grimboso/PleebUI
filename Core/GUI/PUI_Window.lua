local _, ns = ...

local Theme = ns.Theme
local WHITE8 = "Interface\\Buttons\\WHITE8x8"
local WidgetSkins = Theme.WidgetSkins

function Theme.StripACDFrameTextures(frame)
  ns.IconSkin.StripNineSliceAndBackdrop(frame)

  if frame.SetBackdrop then
    frame:SetBackdrop(nil)
  end

  for _, region in ipairs({ frame:GetRegions() }) do
    if region:GetObjectType() == "Texture" then
      region:SetTexture(nil)
      region:SetAlpha(0)
      region:Hide()
    end
  end
end



local function RefreshScrollbarState(scrollbar)
  local owner = scrollbar.__puiScrollbarOwner
  if owner and owner.__puiAceGUIOwnedByPleebUI ~= true then return end

  local hovered = scrollbar.__puiScrollbarHovered == true
  local pressed = scrollbar.__puiScrollbarPressed == true
  local fill, border = Theme.GetControlStateColors(false, hovered, pressed)
  Theme.SetSquareBackdrop(scrollbar, { bg = fill, border = border }, Theme.ControlBorderSize)

  local accent = Theme.GetColors().accent
  local highlight = pressed and 0.16 or hovered and 0.08 or 0
  scrollbar:GetThumbTexture():SetVertexColor(
    accent[1] + (1 - accent[1]) * highlight,
    accent[2] + (1 - accent[2]) * highlight,
    accent[3] + (1 - accent[3]) * highlight,
    (hovered or pressed) and 1 or 0.90
  )
end

function WidgetSkins.Scrollbar(widget)
  local scrollbar = widget.ScrollBar or widget
  local colors = Theme.GetColors()
  local edge = Theme.ControlBorderSize
  local border = colors.border
  local fill = colors.control
  local accent = colors.accent
  local scrollbarWidth = Theme.GetOptionsPointerTargetSize(20)
  local upButton = scrollbar.ScrollUpButton
  local downButton = scrollbar.ScrollDownButton
  local thumb = scrollbar:GetThumbTexture()
  local parent = scrollbar
  local owner
  while parent do
    if parent.obj and parent.obj.AceGUIWidgetVersion then
      owner = parent.obj
      break
    end
    parent = parent:GetParent()
  end
  scrollbar.__puiScrollbarOwner = owner

  scrollbar:SetWidth(scrollbarWidth)
  scrollbar:SetHitRectInsets(0, 0, 0, 0)
  upButton:ClearAllPoints()
  upButton:SetPoint("BOTTOM", scrollbar, "TOP", 0, 0)
  downButton:ClearAllPoints()
  downButton:SetPoint("TOP", scrollbar, "BOTTOM", 0, 0)

  local function StripTextures(frame, keep)
    for _, region in ipairs({ frame:GetRegions() }) do
      if region ~= keep and region:GetObjectType() == "Texture" then
        region:SetTexture(nil)
        region:SetAlpha(0)
        region:Hide()
      end
    end
  end

  local function SkinArrowButton(button, texture)
    StripTextures(button)
    button:SetSize(scrollbarWidth, scrollbarWidth)
    button:SetHitRectInsets(0, 0, 0, 0)

    WidgetSkins.Button(button, owner)

    local arrow = button.__puiArrow
    if not arrow then
      arrow = button:CreateTexture(nil, "ARTWORK")
      Theme.MarkCreatedWidgetChrome(arrow)
      button.__puiArrow = arrow
    end

    arrow:SetTexture(texture)
    arrow:ClearAllPoints()
    arrow:SetPoint("CENTER")
    arrow:SetSize(12, 12)
    arrow:SetVertexColor(accent[1], accent[2], accent[3], 0.95)
    arrow:Show()
  end

  StripTextures(scrollbar, thumb)

  Theme.SetSquareBackdrop(scrollbar, {
    bg = fill,
    border = border,
  }, edge)

  local bg = scrollbar._puiBg
  bg:ClearAllPoints()
  bg:SetAllPoints(scrollbar)

  SkinArrowButton(upButton, "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
  SkinArrowButton(downButton, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

  thumb:SetTexture(WHITE8)
  thumb:SetTexCoord(0, 1, 0, 1)
  thumb:SetVertexColor(accent[1], accent[2], accent[3], 0.90)
  thumb:SetSize(scrollbarWidth - 2, Theme.GetOptionsPointerTargetSize(24))
  thumb:Show()

  if not scrollbar.__puiScrollbarStateHooked then
    scrollbar.__puiScrollbarStateHooked = true
    scrollbar:HookScript("OnEnter", function(self)
      self.__puiScrollbarHovered = true
      RefreshScrollbarState(self)
    end)
    scrollbar:HookScript("OnLeave", function(self)
      self.__puiScrollbarHovered = nil
      RefreshScrollbarState(self)
    end)
    scrollbar:HookScript("OnMouseDown", function(self, mouseButton)
      if mouseButton == "LeftButton" then
        self.__puiScrollbarPressed = true
        RefreshScrollbarState(self)
      end
    end)
    scrollbar:HookScript("OnMouseUp", function(self, mouseButton)
      if mouseButton == "LeftButton" then
        self.__puiScrollbarPressed = nil
        RefreshScrollbarState(self)
      end
    end)
    scrollbar:HookScript("OnHide", function(self)
      self.__puiScrollbarHovered = nil
      self.__puiScrollbarPressed = nil
    end)
    scrollbar:HookScript("OnShow", RefreshScrollbarState)
  end
  RefreshScrollbarState(scrollbar)
end

local function LayoutScrollFrameTargets(widget)
  local width = Theme.GetOptionsPointerTargetSize(20)
  local margin = widget.scrollBarShown and (width + 2) or 0
  local changed = widget.__puiScrollTargetMargin ~= margin
  widget.__puiScrollTargetMargin = margin
  widget.scrollframe:SetPoint("BOTTOMRIGHT", -margin, 0)
  if widget.content.original_width then
    widget.content.width = widget.content.original_width - margin
  end
  local inset = width > 18 and width or 16
  widget.scrollbar:ClearAllPoints()
  widget.scrollbar:SetPoint("TOPLEFT", widget.scrollframe, "TOPRIGHT", 4, -inset)
  widget.scrollbar:SetPoint("BOTTOMLEFT", widget.scrollframe, "BOTTOMRIGHT", 4, inset)
  return changed
end

function WidgetSkins.ScrollFrame(widget)
  WidgetSkins.Scrollbar(widget.scrollbar)
  if not widget.__puiScrollTargetLayoutHooked then
    widget.__puiScrollTargetLayoutHooked = true
    local originalDoLayout = widget.DoLayout
    widget.DoLayout = function(self, ...)
      if self.__puiAceGUIOwnedByPleebUI == true then
        LayoutScrollFrameTargets(self)
      end
      return originalDoLayout(self, ...)
    end
    local originalOnWidthSet = widget.OnWidthSet
    widget.OnWidthSet = function(self, width)
      originalOnWidthSet(self, width)
      if self.__puiAceGUIOwnedByPleebUI == true then
        LayoutScrollFrameTargets(self)
      end
    end
  end
  if LayoutScrollFrameTargets(widget) then
    widget:DoLayout()
  end
end

function WidgetSkins.Frame(frame)
  Theme.StripACDFrameTextures(frame)

  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(frame, {
    bg = colors.background,
    border = colors.border,
  })
end

function WidgetSkins.CloseButton(button)
  ns.KeyboardNavigation.RegisterFrame(button, "button", "close")
  local colors = Theme.GetColors()

  button:SetNormalTexture("")
  button:SetPushedTexture("")
  button:SetHighlightTexture("")
  Theme:ApplyButton(button, "close")

  if not button._puiCloseText then
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    Theme.MarkCreatedWidgetChrome(text)
    button._puiCloseText = text
  end

  local text = button._puiCloseText
  local color = colors.text
  Theme.ApplyFont(text, "button", 15, "NONE")
  text:SetText("×")
  text:SetTextColor(color[1], color[2], color[3], color[4])
  text:Show()

  Theme.StripIcon(button)
end
