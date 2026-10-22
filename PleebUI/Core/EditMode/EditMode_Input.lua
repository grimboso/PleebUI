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
    sections = {
      { "Two places to work", "Use /pui to change settings. Use /pe to arrange frames on your screen." },
      { "Choose how you interact", "/pe uses your saved Mouse or Keyboard preference. /pek opens keyboard Edit Mode for one session." },
      { "A safe place to learn", "The next pages include sample menus and movers. Try them here: they do not change your real layout or saved settings.\n\nYou can close and replay this guide from /pui > Edit Mode. Edit Mode is unavailable during combat or while Blizzard Edit Mode is open." },
    },
  },
  {
    mode = "mouse", title = "Mouse: navigating /pui", practice = "navigation",
    sections = {
      { "Choose a page", "Click a sample category on the left, then General or Text on the right." },
      { "Try a control", "Click Show sample text to turn it on and off. Your choice only affects the practice area below." },
      { "In your real options", "Use the mouse wheel or scrollbar to reach more settings. Mouse clicks clear keyboard navigation focus." },
    },
  },
  {
    mode = "keyboard", title = "Keyboard: navigating /pui", practice = "navigation",
    sections = {
      { "Reach the practice menu", "Press Tab until a sample category has a focus outline. Shift+Tab moves backward." },
      { "Browse, then select", "Use Up/Down to browse sample categories, then Enter to open one. On General and Text, use Left/Right to browse tabs and Enter or Space to select." },
      { "Try a control", "Tab to Show sample text and press Enter or Space. Focus alone does not change a setting.\n\nIn /pui, enable Keyboard navigation to use these controls. Escape cancels an edit or leaves navigation; F1 opens keyboard help." },
    },
  },
  {
    mode = "mouse", title = "Mouse: select and move", practice = "movers",
    sections = {
      { "Move a sample frame", "Click Player, Target, or Resources below. Drag it to another position inside the practice area." },
      { "Move frames together", "Ctrl+click to add or remove a sample frame from the selection. Drag a selected frame to move the selected group together." },
      { "In your real Edit Mode", "Left-click a mover opens quick settings. Right-click opens its module settings. Use arrows or X/Y fields for precise positioning. Practice here does not move live frames." },
    },
  },
  {
    mode = "keyboard", title = "Keyboard: select and move", practice = "movers",
    sections = {
      { "Enter mover practice", "Press F6 to switch from guide controls to the sample movers. The practice status shows which mode is active." },
      { "Select and move", "Tab selects the next mover; Shift+Tab selects the previous one. Press 1 for a one-pixel step, then move it with the arrow keys. Try keys 2-9 for a larger step." },
      { "Return to the guide", "Press F6 again to return to guide controls, then Tab to Next.\n\nIn the game, /pek opens keyboard Edit Mode for one session. F6 switches between real movers and toolbar controls." },
    },
  },
  {
    title = "Snapping and readability",
    sections = {
      { "Align frames", "Snap to frames aligns nearby edges. Smart Snap links supported movers. Snap distance controls how close frames must be." },
      { "Grid and free movement", "Show grid and Snap to grid are separate settings. With the mouse, Shift-drag detaches a real mover and moves it freely; Alt+right-click disconnects Smart Snap links." },
      { "Make editing easier to see", "Turn off Compact movers for clearer labels and borders. Adjust screen dimming in Edit Mode settings. Accessibility contains text size, larger pointer targets, and color presets." },
    },
  },
  {
    title = "Undo and finish", practice = "history",
    sections = {
      { "Make a change", "Drag a sample mover below, or press F6 and move it with the arrow keys." },
      { "Undo, then redo", "Press Ctrl+Z to restore its previous position. Press Ctrl+Y to apply the move again. The Undo and Redo buttons do the same thing.\n\nMake another move after undoing: it starts a new history and clears Redo." },
      { "Finish when you are ready", "This practice history belongs only to the guide. In real Edit Mode, history clears when you leave or switch profiles, while your saved layout remains.\n\nPress F6 to leave mover practice before using Tab to reach Open Edit Mode or Close." },
    },
  },
}

local function RenderEditModeGuide(guide)
  local panel, Theme = guide.panel, ns.Theme
  local colors = Theme.GetColors()
  panel.practice:StopDrag(true)
  panel.practice.frame:Hide()
  Theme.SetSquareBackdrop(panel, { bg = colors.background, border = colors.controlBorder }, Theme.ControlBorderSize)
  ns.EditModeGuidePractice.ApplyReadingFont(panel.title, "title", 26)
  local labels, sections, exercise
  if guide.stage == "offer" then
    panel.title:SetText("Would you like an Edit Mode guide?")
    sections = {
      { "Learn at your own pace", "Choose Mouse, Keyboard, or Both. Short instructions and sample controls let you practice /pui navigation and /pe movement." },
      { "Your settings stay safe", "The practice area does not change your real layout. You can replay this guide from /pui > Edit Mode." },
    }
    labels = { "Take the guide", "Skip and open Edit Mode", "Close" }
  elseif guide.stage == "choose" then
    panel.title:SetText("Choose your guide")
    sections = {
      { "Mouse, Keyboard, or Both", "Choose the instructions you want to try. This choice does not change your saved input preference." },
      { "Moving through the guide", "Use Tab and Shift+Tab to reach controls, then Enter or Space to activate them. Focus the reading area and use Up/Down or Page Up/Down to scroll. Escape closes the guide." },
    }
    labels = { "Mouse", "Keyboard", "Both" }
  else
    local step = guide.steps[guide.index]
    panel.title:SetText(string.format("%d / %d  ·  %s", guide.index, #guide.steps, step.title))
    sections, exercise = step.sections, step.practice
    labels = { "Back", guide.index == #guide.steps and "Open Edit Mode" or "Next", "Close" }
  end
  local width = math.max(1, math.min(820, UIParent:GetWidth() - 40))
  local buttonHeight = math.max(36, Theme.GetOptionsPointerTargetSize(0), Theme.GetOptionsFontHeight("button") + 12)
  local buttonWidth, stacked = (width - 56) / 3, false
  for index, button in ipairs(panel.buttons) do
    button:SetText(labels[index])
    button:SetEnabled(guide.stage ~= "steps" or index ~= 1 or guide.index > 1)
    Theme.WidgetSkins.UIButton(button)
    if button:GetFontString():GetUnboundedStringWidth() + 24 > buttonWidth then stacked = true end
  end
  local footerHeight = stacked and buttonHeight * 3 + 16 or buttonHeight
  if stacked then buttonWidth = width - 40 end
  for index, button in ipairs(panel.buttons) do
    button:SetSize(buttonWidth, buttonHeight)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT",
      stacked and 20 or 20 + (index - 1) * (buttonWidth + 8),
      stacked and 20 + (3 - index) * (buttonHeight + 8) or 20)
  end
  Theme.WidgetSkins.UIButton(panel.close)
  panel.close:SetSize(math.max(80, panel.close:GetFontString():GetUnboundedStringWidth() + 24), buttonHeight)
  panel.close:SetShown(guide.stage == "choose")
  panel.title:ClearAllPoints()
  panel.title:SetPoint("TOPLEFT", 24, -24)
  panel.title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", guide.stage == "choose" and -panel.close:GetWidth() - 36 or -24, -24)
  local contentWidth = width - 72
  local y = 0
  for index, section in ipairs(sections) do
    local row = panel.sections[index]
    if not row then
      row = { heading = panel.content:CreateFontString(nil, "OVERLAY"), body = panel.content:CreateFontString(nil, "OVERLAY") }
      panel.sections[index] = row
      for _, text in pairs(row) do text:SetJustifyH("LEFT"); text:SetWordWrap(true) end
    end
    for _, text in pairs(row) do text:Show(); text:SetWidth(contentWidth); text:ClearAllPoints() end
    ns.EditModeGuidePractice.ApplyReadingFont(row.heading, "header", 22)
    ns.EditModeGuidePractice.ApplyReadingFont(row.body, "body", 18)
    row.heading:SetText(section[1])
    row.heading:SetPoint("TOPLEFT", 0, -y)
    y = y + row.heading:GetStringHeight() + 10
    row.body:SetText(section[2])
    row.body:SetPoint("TOPLEFT", 0, -y)
    y = y + row.body:GetStringHeight() + 28
  end
  for index = #sections + 1, #panel.sections do
    panel.sections[index].heading:Hide(); panel.sections[index].body:Hide()
  end
  if exercise then
    panel.practice.frame:ClearAllPoints()
    panel.practice.frame:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -y)
    panel.practice:Show(exercise, contentWidth)
    y = y + panel.practice.frame:GetHeight() + 16
  end
  panel.content:SetSize(contentWidth, math.max(1, y))
  local desiredHeight = y + panel.title:GetStringHeight() + footerHeight + 100
  panel:SetSize(width, math.min(UIParent:GetHeight() - 60, desiredHeight))
  panel.scroll:ClearAllPoints()
  panel.scroll:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -24)
  panel.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -44, footerHeight + 36)
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
    panel.sections = {}
    panel.practice = ns.EditModeGuidePractice.Create(panel.content)
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
    guide:SetScript("OnHide", function(self)
      self:UnregisterEvent("PLAYER_REGEN_DISABLED")
      panel.practice:StopDrag(true)
      panel.practice.keyboardMode = false
    end)
    guide:SetScript("OnEvent", function(self) self:Hide() end)
    table.insert(UISpecialFrames, guide:GetName())
    ns.KeyboardNavigation.BindWindow(guide, false, function() guide:Hide() end, nil,
      function(key, keyboardInput) return panel.practice:HandleKey(key, keyboardInput) end)
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
          ns.OptionsLifecycle.RefreshModel({ "EditMode" })
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
