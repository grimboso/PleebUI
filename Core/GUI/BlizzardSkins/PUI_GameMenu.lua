local _, ns = ...

local Addon = ns.Addon
local Theme = ns.Theme
local WidgetSkins = Theme.WidgetSkins

function Addon:Theme_SkinGameMenu(menu)
  ns.BlizzardSkins.StripDialogTextures(menu, function()
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
  ns.BlizzardWindowControls.Install(menu)
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
