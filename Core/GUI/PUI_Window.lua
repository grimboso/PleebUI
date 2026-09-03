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



function WidgetSkins.Scrollbar(widget)
  local scrollbar = widget.ScrollBar or widget
  local colors = Theme.GetColors()
  local edge = math.max(Theme.GetEdgeSize(), 2)
  local border = colors.border
  local fill = colors.control
  local accent = colors.accent
  local upButton = scrollbar.ScrollUpButton
  local downButton = scrollbar.ScrollDownButton
  local thumb = scrollbar:GetThumbTexture()

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

    Theme.SetSquareBackdrop(button, {
      bg = fill,
      border = border,
    }, edge)

    local arrow = button.__puiArrow
    if not arrow then
      arrow = button:CreateTexture(nil, "ARTWORK")
      Theme.MarkCreatedWidgetChrome(arrow)
      button.__puiArrow = arrow
    end

    arrow:SetTexture(texture)
    arrow:ClearAllPoints()
    arrow:SetPoint("CENTER")
    arrow:SetSize(16, 16)
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
  bg:SetPoint("TOPLEFT", upButton, "BOTTOMLEFT", 0, 1)
  bg:SetPoint("BOTTOMRIGHT", downButton, "TOPRIGHT", 0, -1)

  SkinArrowButton(upButton, "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
  SkinArrowButton(downButton, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

  thumb:SetTexture(WHITE8)
  thumb:SetTexCoord(0, 1, 0, 1)
  thumb:SetVertexColor(accent[1], accent[2], accent[3], 0.90)
  thumb:SetSize(math.max(scrollbar:GetWidth() - 4, 6), 24)
  thumb:Show()
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
  text:SetText("x")
  text:SetTextColor(color[1], color[2], color[3], color[4])
  text:Show()

  Theme.StripIcon(button)
end
