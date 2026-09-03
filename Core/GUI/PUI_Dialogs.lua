local _, ns = ...

local Addon = ns.Addon
local Theme = ns.Theme
local WidgetSkins = Theme.WidgetSkins

function Theme:ApplyDialogShell(frame)
  local colors = self:GetColors()

  ns.IconSkin.StripNineSliceAndBackdrop(frame)
  Theme.SetSquareBackdrop(frame, {
    bg = colors.background,
    border = colors.border,
  }, Theme.GetEdgeSize())
end

local function _PUI_HideDialogTextures(root, keepFrame, keepRegion)
  local seen = {}

  local function StripFrame(frame)
    if seen[frame] or frame.__puiIsBackdropFrame then
      return
    end
    seen[frame] = true

    if frame ~= root and keepFrame(frame) then
      return
    end

    if frame.SetBackdrop then
      frame:SetBackdrop(nil)
    end

    local buttonSkin = frame.__puiButtonTextureSkin
    for _, region in ipairs({ frame:GetRegions() }) do
      if region:GetObjectType() == "Texture" then
        local ownedButtonTexture = buttonSkin and (
          region == buttonSkin.bg
          or region == buttonSkin.top
          or region == buttonSkin.bottom
          or region == buttonSkin.left
          or region == buttonSkin.right
        )

        if ownedButtonTexture or keepRegion(region) then
          region:SetAlpha(1)
          region:Show()
        else
          region:SetTexture(nil)
          region:SetAlpha(0)
          region:Hide()
        end
      end
    end

    for _, borderFrame in ipairs({ frame.BorderBox, frame.Border, frame.NineSlice }) do
      if borderFrame and borderFrame ~= frame then
        StripFrame(borderFrame)
        borderFrame:Hide()
      end
    end

    for _, child in ipairs({ frame:GetChildren() }) do
      if child ~= frame._puiBg and not child.__puiIsBackdropFrame then
        StripFrame(child)
      end
    end
  end

  StripFrame(root)
end

local function _PUI_HideStaticPopupTextures(popup)
  local itemFrame = popup:GetItemFrame()
  local item = itemFrame.Item
  local moneyInputFrame = popup.MoneyInputFrame

  _PUI_HideDialogTextures(popup,
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

function Addon:Theme_SkinGameMenu(menu)
  _PUI_HideDialogTextures(menu, function()
    return false
  end, function(region)
    return region == menu.__puiPleebUILogo
  end)

  Theme:ApplyDialogShell(menu)
  Theme.ApplyFont(menu.Header.Text, "title", 18)

  local color = Theme.GetColors().text
  menu.Header.Text:SetTextColor(color[1], color[2], color[3], color[4])

  for button in menu.buttonPool:EnumerateActive() do
    WidgetSkins.UIButton(button)
  end

  if menu.NewOptionsFrame:IsShown() then
    local _, optionsText = menu.NewOptionsFrame:GetPoint(1)
    menu.NewOptionsFrame:ClearAllPoints()
    menu.NewOptionsFrame:SetPoint("RIGHT", optionsText, "LEFT", -8, 0)
  end

  if menu.NewExternalEventFrame:IsShown() then
    local _, externalEventText = menu.NewExternalEventFrame:GetPoint(1)
    menu.NewExternalEventFrame:ClearAllPoints()
    menu.NewExternalEventFrame:SetPoint("RIGHT", externalEventText, "LEFT", -8, 0)
  end
end

local gameMenuBaseHeight

local function _PUI_InstallGameMenuButtons()
  local menu = GameMenuFrame

  local settingsButton = CreateFrame("Button", "PleebUI_GameMenuButton", menu, "MainMenuFrameButtonTemplate")
  settingsButton:SetSize(200, 35)
  settingsButton:SetText("PleebUI")
  WidgetSkins.UIButton(settingsButton)
  settingsButton:SetScript("OnClick", function()
    if InCombatLockdown() then
      Addon:Print("Cannot open PleebUI from the Game Menu during combat.")
      return
    end

    HideUIPanel(menu)
    Addon:OpenOptions(nil, false, true)
  end)
  settingsButton:Hide()

  local logo = settingsButton:CreateTexture(nil, "ARTWORK")
  logo:SetTexture([[Interface\AddOns\PleebUI\Media\logo.tga]])
  logo:SetSize(22, 22)
  logo:SetPoint("LEFT", settingsButton, "LEFT", 12, 0)
  menu.__puiPleebUILogo = logo

  local testModeButton = CreateFrame("Button", "PleebUI_TestModeGameMenuButton", menu, "MainMenuFrameButtonTemplate")
  testModeButton:SetSize(200, 35)
  testModeButton:SetText("PleebUI Test Mode")
  WidgetSkins.UIButton(testModeButton)
  testModeButton:SetScript("OnClick", function()
    if InCombatLockdown() then
      Addon:Print("Cannot toggle PleebUI Test Mode during combat.")
      return
    end

    HideUIPanel(menu)
    Addon:SetEditMode(not Addon:IsEditMode())
  end)
  testModeButton:Hide()

  hooksecurefunc(menu, "Layout", function()
    if InCombatLockdown() then
      settingsButton:Hide()
      testModeButton:Hide()
      return
    end

    local firstButton
    local firstTop

    for button in menu.buttonPool:EnumerateActive() do
      local top = button:GetTop()
      if top and (not firstTop or top > firstTop) then
        firstButton = button
        firstTop = top
      end
    end

    if not firstButton then
      settingsButton:Hide()
      testModeButton:Hide()
      return
    end

    local buttonWidth = firstButton:GetWidth()
    local buttonHeight = firstButton:GetHeight()
    local point, relativeTo, relativePoint, xOffset, yOffset = firstButton:GetPoint(1)

    settingsButton:SetSize(buttonWidth, buttonHeight)
    settingsButton:ClearAllPoints()
    settingsButton:SetPoint(point, relativeTo, relativePoint, xOffset or 0, yOffset or 0)
    settingsButton:Show()

    testModeButton:SetSize(buttonWidth, buttonHeight)
    testModeButton:ClearAllPoints()
    testModeButton:SetPoint("TOP", settingsButton, "BOTTOM", 0, -4)
    testModeButton:Show()

    local extraHeight = (buttonHeight * 2) + 16

    for button in menu.buttonPool:EnumerateActive() do
      local menuPoint, menuRelativeTo, menuRelativePoint, menuX, menuY = button:GetPoint(1)
      if menuPoint then
        button:ClearAllPoints()
        button:SetPoint(menuPoint, menuRelativeTo, menuRelativePoint, menuX or 0, (menuY or 0) - extraHeight)
      end
    end

    if not gameMenuBaseHeight then
      gameMenuBaseHeight = menu:GetHeight()
    end
    menu:SetHeight(gameMenuBaseHeight + extraHeight)
  end)
end

local gameMenuEvents = CreateFrame("Frame")
gameMenuEvents:RegisterEvent("PLAYER_LOGIN")
gameMenuEvents:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  _PUI_InstallGameMenuButtons()
  hooksecurefunc(GameMenuFrame, "InitButtons", function(menu)
    Addon:Theme_SkinGameMenu(menu)
  end)
end)