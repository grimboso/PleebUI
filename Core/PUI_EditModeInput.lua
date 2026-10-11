local _, ns = ...

local Addon = ns.Addon

function Addon:ShowEditModeInputChoice()
  local choice = self._EditModeInputChoice
  if not choice then
    choice = CreateFrame("Frame", "PleebUI_EditModeInputChoice", UIParent, "BackdropTemplate")
    self._EditModeInputChoice = choice
    choice:Hide()
    choice:SetPoint("CENTER")
    choice:SetFrameStrata("FULLSCREEN_DIALOG")
    choice:SetFrameLevel(500)
    choice:SetClampedToScreen(true)
    choice:EnableMouse(true)
    choice.title = choice:CreateFontString(nil, "OVERLAY")
    choice.title:SetPoint("TOPLEFT", 20, -20)
    choice.title:SetPoint("TOPRIGHT", -20, -20)
    choice.title:SetJustifyH("LEFT")
    choice.body = choice:CreateFontString(nil, "OVERLAY")
    choice.body:SetPoint("TOPLEFT", choice.title, "BOTTOMLEFT", 0, -12)
    choice.body:SetPoint("RIGHT", choice, "RIGHT", -20, 0)
    choice.body:SetJustifyH("LEFT")
    choice.body:SetWordWrap(true)
    choice.buttons = {}
    for index, label in ipairs({ "Mouse", "Keyboard" }) do
      local keyboard = index == 2
      local button = CreateFrame("Button", nil, choice, "UIPanelButtonTemplate")
      button:SetText(label)
      button:SetScript("OnClick", function()
        ns.FrameUtil.SetKeyboardMovementEnabled(keyboard)
        Addon:GetGlobalOptionsDB().editModeInputExplained = true
        choice:Hide()
        Addon:SetEditMode(true)
      end)
      choice.buttons[index] = button
    end
    ns.KeyboardNavigation.BindWindow(choice, false, function() choice:Hide() end)
  end
  local Theme = ns.Theme
  local colors = Theme.GetColors()
  local height = math.max(30, Theme.GetOptionsPointerTargetSize(0), Theme.GetOptionsFontHeight("button") + 10)
  choice:SetWidth(math.max(460, Theme.GetOptionsFontHeight("body") * 30))
  Theme.SetSquareBackdrop(choice, { bg = colors.background, border = colors.controlBorder }, Theme.ControlBorderSize)
  Theme.ApplyFont(choice.title, "title")
  Theme.ApplyFont(choice.body, "body")
  choice.title:SetText("Choose your preferred Edit Mode")
  choice.body:SetText("Mouse: drag movers and click controls.\n\nKeyboard: Tab and Shift+Tab cycle movers. Arrow keys move them; keys 1-9 choose the movement step. F6 switches between movers and toolbar controls.\n\nIn options, Tab moves between controls, arrow keys navigate lists, and Enter or Space activates the focused control. Escape cancels or leaves navigation.\n\n/pe uses your choice. /pek always opens keyboard Edit Mode for that session. You can change your preference with Keyboard movement in the Edit Mode toolbar.")
  choice.title:SetTextColor(unpack(colors.text))
  choice.body:SetTextColor(unpack(colors.text))
  choice:SetHeight(choice.title:GetStringHeight() + choice.body:GetStringHeight() + height + 76)
  for index, button in ipairs(choice.buttons) do
    button:SetSize((choice:GetWidth() - 48) * 0.5, height)
    button:ClearAllPoints()
    button:SetPoint(index == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT", choice,
      index == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT", index == 1 and 20 or -20, 20)
    Theme.WidgetSkins.UIButton(button)
  end
  choice:Show()
  ns.KeyboardNavigation.HandleKey("TAB", true)
end
