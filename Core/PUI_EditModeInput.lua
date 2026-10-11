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
        Addon:ShowEditModeGuide(true)
      end)
      choice.buttons[index] = button
    end
    choice:SetScript("OnShow", function(self) self:RegisterEvent("PLAYER_REGEN_DISABLED") end)
    choice:SetScript("OnHide", function(self) self:UnregisterEvent("PLAYER_REGEN_DISABLED") end)
    choice:SetScript("OnEvent", function(self) self:Hide() end)
    table.insert(UISpecialFrames, choice:GetName())
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

local GUIDE_STEPS = {
  {
    title = "Before you start",
    text = "Use /pui to change settings and /pe to arrange frames. /pe uses your saved Mouse or Keyboard preference; /pek opens keyboard Edit Mode for one session.\n\nThis guide explains the controls without changing your layout or input preference. Close it before trying a step in the game, then replay it from /pui > Edit Mode.\n\nEdit Mode is unavailable during combat and while Blizzard Edit Mode is open.",
  },
  {
    mode = "mouse", title = "Mouse: navigating /pui",
    text = "1. Open /pui and click a main category.\n\n2. Click a tab or subcategory, then the setting you want to change. Use the mouse wheel or scrollbar to reach more controls.\n\n3. Click a checkbox to toggle it. Open a dropdown and choose a value. Drag a slider, use its minus or plus buttons, or enter a number.\n\nMouse clicks clear keyboard navigation focus. Clicking a new page should not leave an old control active.",
  },
  {
    mode = "keyboard", title = "Keyboard: navigating /pui",
    text = "1. Enable Keyboard navigation in Accessibility or Edit Mode settings, then open /pui.\n\n2. Press Tab to move forward and Shift+Tab to move backward. Focus alone does not change a setting.\n\n3. In category lists, use Up/Down to browse, Left/Right to expand or collapse, and Enter to open a page. On tabs, use Left/Right to browse and Enter or Space to select.\n\n4. Press Enter or Space to activate a button, checkbox, or dropdown. Use arrow keys on a slider. In text fields, arrows move the caret and Enter commits numeric input.\n\nEscape cancels an edit or closes a dropdown first, then leaves navigation. F1 opens keyboard help.",
  },
  {
    mode = "mouse", title = "Mouse: select and move",
    text = "1. Open /pe. Left-click a mover to select it and open its quick settings.\n\n2. Drag a mover to change its position. Ctrl+click adds or removes movers from the selection. Drag a selected mover to move the selection together.\n\n3. Drag empty space to box-select movers. Use the arrows or X/Y coordinate fields for precise positioning.\n\nRight-click a mover to open its module settings. Shift+right-click hides its editing handle for this session; Show all restores it. Hiding a handle does not disable the live widget.",
  },
  {
    mode = "keyboard", title = "Keyboard: select and move",
    text = "1. Open /pek to try keyboard Edit Mode without changing your saved preference.\n\n2. Press Tab to select the next mover, or Shift+Tab for the previous mover.\n\n3. Press 1 to use a one-pixel step, then use the arrow keys to move the selected mover. Keys 1-9 choose other movement steps.\n\n4. Press F6 to switch to toolbar controls. Tab and Shift+Tab move between controls; Enter or Space activates them. Press F6 again to return to mover selection.\n\nWhen typing in a field, arrow keys edit the text rather than moving a frame. F1 opens keyboard help.",
  },
  {
    title = "Snapping and readability",
    text = "Snap to frames aligns nearby edges while dragging. Smart Snap links supported movers so they move and arrange together. Snap distance controls how close they must be.\n\nSnap to grid and Show grid are separate settings: showing a grid does not enable snapping.\n\nWith the mouse, Shift-drag detaches a mover and moves it freely. Alt+right-click disconnects Smart Snap links.\n\nIf handles are hard to read, turn off Compact movers. Adjust screen dimming in Edit Mode settings. Accessibility also contains text size, larger pointer targets, and color presets.",
  },
  {
    title = "Undo and finish",
    text = "Undo reverses the last edit; Redo reapplies it. Ctrl+Z and Ctrl+Y also work outside text fields.\n\nHistory belongs to the current Edit Mode session and clears when you leave or switch profiles. Close quick settings or help before using Escape to leave Edit Mode. Your layout changes remain saved.\n\nYou can now open Edit Mode using your saved preference, or close this guide. Replay the Mouse, Keyboard, or Both guide from /pui > Edit Mode whenever you need it.",
  },
}

local function RenderEditModeGuide(guide)
  local panel, Theme = guide.panel, ns.Theme
  local colors = Theme.GetColors()
  Theme.SetSquareBackdrop(panel, { bg = colors.background, border = colors.controlBorder }, Theme.ControlBorderSize)
  Theme.ApplyFont(panel.title, "header")
  Theme.ApplyFont(panel.text, "body")
  panel.title:SetTextColor(unpack(colors.text))
  panel.text:SetTextColor(unpack(colors.text))
  local labels
  if guide.stage == "offer" then
    panel.title:SetText("Would you like an Edit Mode guide?")
    panel.text:SetText("Learn how to navigate /pui and arrange frames in /pe. You can choose Mouse, Keyboard, or Both.\n\nThe guide does not change your layout. You can replay it later from /pui > Edit Mode.")
    labels = { "Take the guide", "Skip and open Edit Mode", "Close" }
  elseif guide.stage == "choose" then
    panel.title:SetText("Choose your guide")
    panel.text:SetText("Choose Mouse, Keyboard, or Both. This choice only selects the instructions; it does not change your saved input preference.\n\nUse Tab and Shift+Tab to reach the buttons, then Enter or Space to choose. During the guide, focus the text and use Up/Down or Page Up/Down to scroll. Escape closes the guide.")
    labels = { "Mouse", "Keyboard", "Both" }
  else
    local step = guide.steps[guide.index]
    panel.title:SetText(string.format("%d / %d · %s", guide.index, #guide.steps, step.title))
    panel.text:SetText(step.text)
    labels = { "Back", guide.index == #guide.steps and "Open Edit Mode" or "Next", "Close" }
  end
  local width = math.max(1, math.min(640, UIParent:GetWidth() - 40))
  local height = math.max(1, math.min(540, UIParent:GetHeight() - 60))
  local buttonHeight = math.max(30, Theme.GetOptionsPointerTargetSize(0), Theme.GetOptionsFontHeight("button") + 10)
  local buttonWidth = (width - 56) / 3
  local stacked = false
  panel:SetSize(width, height)
  panel.text:SetWidth(math.max(1, width - 66))
  panel.content:SetSize(math.max(1, width - 66), math.max(1, panel.text:GetStringHeight()))
  for index, button in ipairs(panel.buttons) do
    button:SetText(labels[index])
    button:SetEnabled(guide.stage ~= "steps" or index ~= 1 or guide.index > 1)
    Theme.WidgetSkins.UIButton(button)
    if button:GetFontString():GetUnboundedStringWidth() + 24 > buttonWidth then stacked = true end
  end
  local footerHeight = stacked and buttonHeight * 3 + 16 or buttonHeight
  if stacked then buttonWidth = width - 40 end
  for index, button in ipairs(panel.buttons) do
    local x = stacked and 20 or 20 + (index - 1) * (buttonWidth + 8)
    local y = stacked and 20 + (3 - index) * (buttonHeight + 8) or 20
    button:SetSize(buttonWidth, buttonHeight)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x, y)
  end
  panel.close:SetSize(math.max(80, panel.close:GetFontString():GetUnboundedStringWidth() + 24), buttonHeight)
  panel.close:SetShown(guide.stage == "choose")
  panel.title:ClearAllPoints()
  panel.title:SetPoint("TOPLEFT", 20, -20)
  panel.title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", guide.stage == "choose" and -panel.close:GetWidth() - 32 or -20, -20)
  panel.scroll:ClearAllPoints()
  panel.scroll:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -16)
  panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -42, footerHeight + 36)
  panel.scroll:SetVerticalScroll(0)
  panel.scroll:UpdateScrollChildRect()
  Theme.WidgetSkins.Scrollbar(panel.scroll.ScrollBar)
  ns.KeyboardNavigation.QueueRestore()
end

function Addon:ShowEditModeGuide(offer)
  if InCombatLockdown() then return end
  local guide = self._EditModeGuide
  if not guide then
    guide = CreateFrame("Frame", "PleebUI_EditModeGuide", UIParent)
    self._EditModeGuide = guide
    guide:Hide()
    guide:SetAllPoints(UIParent)
    guide:SetFrameStrata("FULLSCREEN_DIALOG")
    guide:SetFrameLevel(600)
    guide:EnableMouse(true)
    local panel = CreateFrame("Frame", nil, guide, "BackdropTemplate")
    guide.panel = panel
    panel:SetPoint("CENTER")
    panel:EnableMouse(true)
    panel.title = panel:CreateFontString(nil, "OVERLAY")
    panel.title:SetPoint("TOPLEFT", 20, -20)
    panel.title:SetPoint("TOPRIGHT", -20, -20)
    panel.title:SetJustifyH("LEFT")
    panel.close = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.close:SetPoint("TOPRIGHT", -20, -20)
    panel.close:SetText("Close")
    panel.close:SetScript("OnClick", function() guide:Hide() end)
    ns.Theme.WidgetSkins.UIButton(panel.close)
    panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    local function Scroll(direction)
      local scroll = panel.scroll
      scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll() + direction * 32)))
    end
    panel.scroll:EnableMouseWheel(true)
    panel.scroll:SetScript("OnMouseWheel", function(_, delta) Scroll(-delta) end)
    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.scroll:SetScrollChild(panel.content)
    panel.text = panel.content:CreateFontString(nil, "OVERLAY")
    panel.text:SetPoint("TOPLEFT")
    panel.text:SetJustifyH("LEFT")
    panel.text:SetWordWrap(true)
    ns.KeyboardNavigation.RegisterFrame(panel.scroll, "slider", "guideText", nil, nil, nil, {
      adjust = function(direction) Scroll(-direction) end,
    })
    panel.buttons = {}
    for index = 1, 3 do
      local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
      button:SetScript("OnClick", function()
        if guide.stage == "offer" then
          if index == 1 then guide.stage = "choose"
          elseif index == 2 then guide:Hide(); Addon:SetEditMode(true); return
          else guide:Hide(); return end
        elseif guide.stage == "choose" then
          local mode = ({ "mouse", "keyboard", "both" })[index]
          guide.steps = {}
          for _, step in ipairs(GUIDE_STEPS) do
            if not step.mode or step.mode == mode or mode == "both" then
              guide.steps[#guide.steps + 1] = step
            end
          end
          guide.stage, guide.index = "steps", 1
        elseif index == 1 then guide.index = math.max(1, guide.index - 1)
        elseif index == 3 then guide:Hide(); return
        elseif guide.index == #guide.steps then guide:Hide(); Addon:SetEditMode(true); return
        else guide.index = guide.index + 1 end
        RenderEditModeGuide(guide)
      end)
      panel.buttons[index] = button
    end
    guide:SetScript("OnShow", function(self) self:RegisterEvent("PLAYER_REGEN_DISABLED") end)
    guide:SetScript("OnHide", function(self) self:UnregisterEvent("PLAYER_REGEN_DISABLED") end)
    guide:SetScript("OnEvent", function(self) self:Hide() end)
    table.insert(UISpecialFrames, guide:GetName())
    ns.KeyboardNavigation.BindWindow(guide, false, function() guide:Hide() end)
  end
  guide.stage, guide.steps, guide.index = offer and "offer" or "choose", nil, nil
  RenderEditModeGuide(guide)
  guide:Show()
  ns.KeyboardNavigation.HandleKey("TAB", true)
end

local function EditModeOptionsProvider()
  local provider = {}
  function provider:GetOptions()
    local util = ns.FrameUtil
    local function Setting(name, field, default, setter, order, minimum, maximum, step, description)
      return {
        type = minimum and "range" or "toggle", name = name, order = order,
        desc = description, min = minimum, max = maximum, step = step,
        disabled = field == "dimAlpha" and function()
          return util._GetEditModeDB().disableDimming == true
        end or field == "snapTolerance" and function()
          local db = util._GetEditModeDB()
          return db.snapToFrame ~= true and db.smartSnapEnabled == false
        end or nil,
        arg = minimum and { puiRefreshOnRelease = true } or nil,
        get = function()
          local value = util._GetEditModeDB()[field]
          if value == nil then return default end
          return value
        end,
        set = function(_, value)
          util._InitEditModeConfig()
          local history = util.BeginEditHistory("Change " .. name)
          setter(value)
          util.CommitEditHistory(history)
          ns.TestMode:QueueToolbarRefresh()
          Addon:NotifyOptionsTreeChanged(nil, ns._PUIActiveOptionsPath)
        end,
      }
    end
    local gridSize = Setting("Grid size", "gridSize", 16, util.SetGridSize, 6)
    gridSize.type = "select"
    gridSize.values = { [8] = "8 px", [16] = "16 px", [32] = "32 px", [64] = "64 px" }
    return {
      type = "group", name = "Edit Mode", childGroups = "tab", order = 17,
      args = {
        gettingStarted = {
          type = "group", name = "Getting started", order = 1,
          args = {
            description = { type = "description", order = 1,
              name = "Arrange frames with /pe. /pek opens keyboard Edit Mode for one session. These settings use the same saved values as the Edit Mode toolbar. Frame-specific settings remain in their module pages and mover quick settings." },
            guide = { type = "execute", name = "Edit Mode guide", order = 2,
              disabled = InCombatLockdown, func = function() Addon:ShowEditModeGuide() end },
            open = { type = "execute", name = "Open Edit Mode", order = 3,
              disabled = function() return InCombatLockdown() or Addon:IsBlizzardEditModeActive() end,
              func = function() Addon:SetEditMode(true) end },
            keyboardNavigation = { type = "toggle", name = "Keyboard navigation", order = 4,
              desc = "Use Tab, arrow keys, and Enter in options and dialogs. Keyboard mover selection has its own preference.",
              get = ns.KeyboardNavigation.IsEnabled,
              set = function(_, value) ns.KeyboardNavigation.SetEnabled(value) end },
          },
        },
        settings = {
          type = "group", name = "Settings", order = 2, disabled = InCombatLockdown,
          args = {
            movement = {
              type = "group", name = "Movement", order = 1, inline = true, arg = { puiExplicit = true },
              args = {
                keyboard = Setting("Keyboard movement", "keyboardMoveEnabled", false, util.SetKeyboardMovementEnabled, 1, nil, nil, nil,
                  "Prefer keyboard movement when opening /pe. /pek uses keyboard movement for one session."),
                nudge = Setting("Nudge step", "nudgeStep", 1, util._SetNudgeStepFromSlider, 2, 1, 10, 1,
                  "Distance moved by each arrow press, in pixels."),
              },
            },
            snapping = {
              type = "group", name = "Snapping and grid", order = 2, inline = true, arg = { puiExplicit = true },
              args = {
                frames = Setting("Snap to frames", "snapToFrame", false, util.SetEditFrameSnap, 1, nil, nil, nil,
                  "Align nearby frame edges while dragging."),
                smart = Setting("Smart Snap", "smartSnapEnabled", true, util.SetSmartSnapEnabled, 2, nil, nil, nil,
                  "Link supported movers so they move and arrange together."),
                tolerance = Setting("Snap distance", "snapTolerance", 8, util.SetSnapTolerance, 3, 2, 20, 1,
                  "How close movers must be before frame snapping or Smart Snap activates."),
                snapGrid = Setting("Snap to grid", "snapToGrid", false, util.SetEditGridSnap, 4, nil, nil, nil,
                  "Align movers with the grid while dragging."),
                showGrid = Setting("Show grid", "showGrid", false, util.ShowGrid, 5, nil, nil, nil,
                  "Show the grid during Edit Mode. This does not enable snapping."),
                gridSize = gridSize,
              },
            },
            appearance = {
              type = "group", name = "Appearance", order = 3, inline = true, arg = { puiExplicit = true },
              args = {
                compact = Setting("Compact movers", "compactMovers", false, util.SetCompactMovers, 1, nil, nil, nil,
                  "Soften idle mover labels and borders. Hover or select a mover to show it clearly."),
                disableDimming = Setting("Disable screen dimming", "disableDimming", false, util.SetEditDimmingDisabled, 2, nil, nil, nil,
                  "Keep the game background at its normal brightness while editing."),
                dimAlpha = Setting("Screen dimming", "dimAlpha", 0.7, util.SetEditDimAlpha, 3, 0, 1, 0.05,
                  "How much to darken the game background while editing."),
              },
            },
          },
        },
      },
    }
  end
  return provider
end

ns.FrameUtil.RegisterEditModeParticipant("EditModeInput", {
  OnEditModeChanged = function()
    if Addon._EditModeInputChoice then Addon._EditModeInputChoice:Hide() end
    if Addon._EditModeGuide then Addon._EditModeGuide:Hide() end
  end,
}, 90)

Addon:RegisterOptionsSection("EditMode", EditModeOptionsProvider, 17, "Edit Mode", nil, {
  preview = false, navSection = "General",
  navDescription = "Movement, snapping, and step-by-step guides.",
  pageDescription = "Configure Edit Mode and learn mouse or keyboard controls.",
})
