local _, ns = ...

local Addon = ns.Addon
local Theme = ns.Theme
local WidgetSkins = Theme.WidgetSkins

local function _PUI_HideStaticPopupTextures(popup)
  local itemFrame = popup:GetItemFrame()
  local item = itemFrame.Item
  local moneyInputFrame = popup.MoneyInputFrame

  ns.BlizzardSkins.StripDialogTextures(popup,
    function(frame)
      return frame == itemFrame
        or frame == item
        or frame == popup:GetExtraFrame()
        or frame == popup.insertedFrame
    end,
    function(region)
      return region == item.icon
        or region == popup.AlertIcon
        or region == moneyInputFrame.gold.texture
        or region == moneyInputFrame.silver.texture
        or region == moneyInputFrame.copper.texture
    end
  )
end

local function _PUI_SkinStaticPopupItemFrame(itemFrame)
  local item = itemFrame.Item
  local icon = item.icon
  local count = item.Count
  local itemText = itemFrame.Text
  local colors = Theme.GetColors()
  local texture = icon:GetTexture()

  itemFrame.NameFrame:SetTexture(nil)
  itemFrame.NameFrame:SetAlpha(0)
  itemFrame.NameFrame:Hide()

  Theme.StripIcon(item)
  Theme.SetSquareBackdrop(item, {
    bg = colors.background,
    border = colors.border,
  }, Theme.GetEdgeSize())

  icon:SetTexture(texture)
  icon:ClearAllPoints()
  icon:SetPoint("TOPLEFT", item, "TOPLEFT", 2, -2)
  icon:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -2, 2)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetAlpha(1)
  icon:SetVertexColor(1, 1, 1, 1)
  icon:Show()

  Theme.ApplyFont(count, "body", 11, "OUTLINE")
  count:SetTextColor(1, 1, 1, 1)
  count:Show()

  Theme.ApplyFont(itemText, "body", 12)
  itemText:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])
  itemText:Show()
end

function Addon:Theme_SkinStaticPopup(popup)
  local text = popup:GetTextFontString()
  local editBox = popup:GetEditBox()
  local moneyInputFrame = popup.MoneyInputFrame
  local alertIcon = popup.AlertIcon

  popup:SetFrameStrata("FULLSCREEN_DIALOG")
  popup:Raise()

  _PUI_HideStaticPopupTextures(popup)
  Theme:ApplyDialogShell(popup)

  local colors = Theme.GetColors()
  Theme.ApplyFont(text, "body", 12)
  text:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4])

  alertIcon:SetAlpha(1)
  alertIcon:SetVertexColor(1, 1, 1, 1)
  alertIcon:Show()

  _PUI_SkinStaticPopupItemFrame(popup:GetItemFrame())

  for _, button in ipairs(popup:GetButtons()) do
    WidgetSkins.UIButton(button)
  end

  WidgetSkins.UIButton(popup.ExtraButton)
  WidgetSkins.CloseButton(popup.CloseButton)
  WidgetSkins.UIEditBox(editBox)
  WidgetSkins.UIEditBox(moneyInputFrame.gold)
  WidgetSkins.UIEditBox(moneyInputFrame.silver)
  WidgetSkins.UIEditBox(moneyInputFrame.copper)
end

