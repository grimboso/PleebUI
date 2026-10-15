local _, ns = ...

local Addon = ns.Addon
local Theme = ns.Theme
local Content = ns.InstallerContent
local InCombatLockdown = _G.InCombatLockdown
local wizardFrame
local currentPage = 1
local pages = {}
local sections = {}
local RefreshPage
local ShowInstaller
local math_max = math.max
local function SetStatus(message)
  if wizardFrame then wizardFrame.Status:SetText(message or "") end
end

local CombatReadabilityChanges

local function SetCombatReadabilityValue(target, key, value, owner)
  if target[key] == value then
    return
  end

  CombatReadabilityChanges[#CombatReadabilityChanges + 1] = {
    target = target,
    key = key,
    previous = rawget(target, key),
    applied = value,
    owner = owner,
  }

  target[key] = value
end

local function ApplyCombatReadabilityTextConfig(text, nameSize, healthSize, powerSize, owner)
  if type(text) ~= "table" then
    return
  end

  if nameSize then
    SetCombatReadabilityValue(
      text, "sizeName", math_max(tonumber(text.sizeName) or 0, nameSize), owner
    )
  end

  if healthSize then
    SetCombatReadabilityValue(
      text, "sizeHealth", math_max(tonumber(text.sizeHealth) or 0, healthSize), owner
    )
  end

  if powerSize then
    SetCombatReadabilityValue(
      text, "sizePower", math_max(tonumber(text.sizePower) or 0, powerSize), owner
    )
  end

  SetCombatReadabilityValue(text, "outline", "THICKOUTLINE", owner)
  SetCombatReadabilityValue(text, "nameOutline", "THICKOUTLINE", owner)
  SetCombatReadabilityValue(text, "healthOutline", "THICKOUTLINE", owner)
  SetCombatReadabilityValue(text, "powerOutline", "THICKOUTLINE", owner)
end

local function ApplyCombatReadabilityPRDText(text, size)
  if type(text) ~= "table" then
    return
  end

  SetCombatReadabilityValue(
    text, "size", math_max(tonumber(text.size) or 0, size), "prd"
  )
  SetCombatReadabilityValue(text, "flags", "THICKOUTLINE", "prd")
end

local function ApplyCombatReadabilityPRDStyle(style)
  if type(style) ~= "table" then
    return
  end

  SetCombatReadabilityValue(
    style, "borderSize", math_max(tonumber(style.borderSize) or 0, 2), "prd"
  )

  if type(style.bgColor) == "table" then
    SetCombatReadabilityValue(
      style.bgColor,
      4,
      math_max(tonumber(style.bgColor[4]) or 0, 0.85),
      "prd"
    )
  end
end

local function CaptureCombatReadabilityProfiles()
  local profiles = {}
  local modules = {
    unitFrames = ns.Modules.UnitFrames,
    partyFrames = ns.Modules.PartyFrames,
    raidFrames = ns.Modules.RaidFrames,
    resourceDisplay = ns.Modules.PRD,
  }

  for _, module in pairs(modules) do
    profiles[module] = module.db.profile
  end

  return profiles
end

function Addon:CanUndoCombatReadabilityPreset()
  local undo = self.__puiCombatReadabilityUndo
  if not undo then
    return false
  end

  if undo.profile ~= self.db.profile then
    self.__puiCombatReadabilityUndo = nil
    return false
  end

  for module, profile in pairs(undo.moduleProfiles) do
    if module.db.profile ~= profile then
      self.__puiCombatReadabilityUndo = nil
      return false
    end
  end

  return #undo.changes > 0
end

function Addon:UndoCombatReadabilityPreset()
  if InCombatLockdown() or not self:CanUndoCombatReadabilityPreset() then
    return false
  end

  local changes = self.__puiCombatReadabilityUndo.changes
  self.__puiCombatReadabilityUndo = nil

  local affected = {}

  for i = #changes, 1, -1 do
    local change = changes[i]

    if rawget(change.target, change.key) == change.applied then
      change.target[change.key] = change.previous
      affected[change.owner] = true
    end
  end

  if affected.unitFrames then
    ns.Modules.UnitFrames:SafeRefresh("text")
  end

  local groupedModules = {
    {
      module = ns.Modules.PartyFrames,
      textOwner = "partyText",
      auraOwner = "partyAuras",
    },
    {
      module = ns.Modules.RaidFrames,
      textOwner = "raidText",
      auraOwner = "raidAuras",
    },
  }

  for i = 1, #groupedModules do
    local group = groupedModules[i]

    if affected[group.textOwner] then
      group.module:SafeRefresh("text")
    end

    if affected[group.auraOwner] then
      group.module:RefreshAuraDisplay()
    end
  end

  if affected.prd then
    local PRD = ns.Modules.PRD
    PRD:InvalidateRuntimeConfig()
    PRD:RequestRefresh({
      health = true,
      primary = true,
      secondaryAppearance = true,
      text = true,
      secondaryText = true,
      layout = true,
      outerBorder = true,
    })
  end

  local Cooldowns = ns.Modules.CooldownManager

  if affected.spellBars then
    Cooldowns:SpellBars_Rebuild()
  end

  if affected.chargeBars then
    Cooldowns:CooldownStackBars_Rebuild()
  end

  if affected.buffBars then
    ns.Modules.PCM_BB.RebuildCustomBars()
  end

  LibStub("AceConfigRegistry-3.0"):NotifyChange("PleebUI")
  SetStatus("Combat readability settings restored.")
  return true
end

function Addon:ApplyCombatReadabilityPreset()
  if InCombatLockdown() then
    SetStatus("Combat readability cannot be applied during combat.")
    return false
  end

  self.__puiCombatReadabilityUndo = nil
  CombatReadabilityChanges = {}

  local moduleProfiles = CaptureCombatReadabilityProfiles()
  local UF = ns.Modules.UnitFrames
  local ufDB = UF.db.profile

  SetCombatReadabilityValue(ufDB.text, "shortenValues", true, "unitFrames")
  ApplyCombatReadabilityTextConfig(ufDB.text, 16, 16, 14, "unitFrames")

  for _, cfg in pairs(ufDB.units or {}) do
    if type(cfg) == "table" then
      ApplyCombatReadabilityTextConfig(cfg.text, 16, 16, 14, "unitFrames")
    end
  end

  UF:SafeRefresh("text")

  local groupedModules = {
    {
      module = ns.Modules.PartyFrames,
      textOwner = "partyText",
      auraOwner = "partyAuras",
    },
    {
      module = ns.Modules.RaidFrames,
      textOwner = "raidText",
      auraOwner = "raidAuras",
    },
  }

  for i = 1, #groupedModules do
    local group = groupedModules[i]
    local module = group.module

    if module and module.db and module.db.profile then
      local profile = module.db.profile

      ApplyCombatReadabilityTextConfig(
        profile.text, 14, 14, 12, group.textOwner
      )

      if type(profile.auras) == "table" then
        SetCombatReadabilityValue(
          profile.auras,
          "buffIconSize",
          math_max(tonumber(profile.auras.buffIconSize) or 0, 20),
          group.auraOwner
        )
        SetCombatReadabilityValue(
          profile.auras,
          "debuffIconSize",
          math_max(tonumber(profile.auras.debuffIconSize) or 0, 20),
          group.auraOwner
        )
      end

      module:SafeRefresh("text")
      module:RefreshAuraDisplay()
    end
  end

  local PRD = ns.Modules.PRD
  if PRD and PRD.db and PRD.db.profile then
    local db = PRD.db.profile

    ApplyCombatReadabilityPRDText(db.health and db.health.text, 16)
    ApplyCombatReadabilityPRDStyle(db.health and db.health.style)
    ApplyCombatReadabilityPRDText(db.primary and db.primary.text, 16)
    ApplyCombatReadabilityPRDStyle(db.primary and db.primary.style)

    local _, classToken = UnitClass("player")
    local resources = ns.PRDSecondary:GetResourceOptionsForClass(classToken) or {}
    for i = 1, #resources do
      local settings = ns.PRDSecondary:GetResourceSettings(db, resources[i].key)
      if settings then
        ApplyCombatReadabilityPRDText(settings.text, 16)
        ApplyCombatReadabilityPRDStyle(settings.style)
      end
    end

    local text = db.text
    if type(text) == "table" then
      if type(text.health) == "table" then
        ApplyCombatReadabilityPRDText(text.health.left, 16)
        ApplyCombatReadabilityPRDText(text.health.right, 16)
      end
      if type(text.primary) == "table" then
        ApplyCombatReadabilityPRDText(text.primary.left, 16)
        ApplyCombatReadabilityPRDText(text.primary.right, 16)
      end
      ApplyCombatReadabilityPRDText(text.secondary, 16)
    end

    PRD:InvalidateRuntimeConfig()
    PRD:RequestRefresh({
      health = true,
      primary = true,
      secondaryAppearance = true,
      text = true,
      secondaryText = true,
      layout = true,
      outerBorder = true,
    })
  end

  local Cooldowns = ns.Modules.CooldownManager
  local BuffBars = ns.Modules.PCM_BB

  local spellBars = Cooldowns:GetSpellBarsDB() or {}
  for _, cfg in pairs(spellBars) do
    if type(cfg) == "table" then
      SetCombatReadabilityValue(
        cfg, "fontSize", math_max(tonumber(cfg.fontSize) or 0, 16), "spellBars"
      )
      SetCombatReadabilityValue(
        cfg, "fontOutline", "THICKOUTLINE", "spellBars"
      )

      Cooldowns:NormalizeCustomTrackerPresentation(cfg, "cooldown")

      if cfg.presentation == "BUTTON" then
        SetCombatReadabilityValue(
          cfg.icon, "fontSize",
          math_max(tonumber(cfg.icon.fontSize) or 0, 16),
          "spellBars"
        )
        SetCombatReadabilityValue(
          cfg.icon, "countFontSize",
          math_max(tonumber(cfg.icon.countFontSize) or 0, 16),
          "spellBars"
        )
        SetCombatReadabilityValue(
          cfg.icon, "outline", "THICKOUTLINE", "spellBars"
        )
      end
    end
  end
  Cooldowns:SpellBars_Rebuild()

  local chargeBars = Cooldowns:GetCooldownStackBarsDB() or {}
  for _, cfg in pairs(chargeBars) do
    if type(cfg) == "table" then
      SetCombatReadabilityValue(
        cfg, "fontSize", math_max(tonumber(cfg.fontSize) or 0, 16), "chargeBars"
      )
      SetCombatReadabilityValue(
        cfg, "fontOutline", "THICKOUTLINE", "chargeBars"
      )

      Cooldowns:NormalizeCustomTrackerPresentation(cfg, "charge")

      if cfg.presentation == "BUTTON" then
        SetCombatReadabilityValue(
          cfg.icon, "fontSize",
          math_max(tonumber(cfg.icon.fontSize) or 0, 16),
          "chargeBars"
        )
        SetCombatReadabilityValue(
          cfg.icon, "countFontSize",
          math_max(tonumber(cfg.icon.countFontSize) or 0, 16),
          "chargeBars"
        )
        SetCombatReadabilityValue(
          cfg.icon, "outline", "THICKOUTLINE", "chargeBars"
        )
      end
    end
  end
  Cooldowns:CooldownStackBars_Rebuild()

  local buffBars = BuffBars.GetStackBarsDB() or {}
  for _, cfg in pairs(buffBars) do
    if type(cfg) == "table" then
      SetCombatReadabilityValue(
        cfg, "fontSize", math_max(tonumber(cfg.fontSize) or 0, 16), "buffBars"
      )
      SetCombatReadabilityValue(
        cfg, "outline", "THICKOUTLINE", "buffBars"
      )
      SetCombatReadabilityValue(
        cfg, "durationCountFontSize",
        math_max(tonumber(cfg.durationCountFontSize) or 0, 16),
        "buffBars"
      )
      SetCombatReadabilityValue(
        cfg, "durationOutline", "THICKOUTLINE", "buffBars"
      )

      Cooldowns:NormalizeCustomTrackerPresentation(cfg, cfg.kind)

      if cfg.presentation == "BUTTON" then
        SetCombatReadabilityValue(
          cfg.icon, "fontSize",
          math_max(tonumber(cfg.icon.fontSize) or 0, 16),
          "buffBars"
        )
        SetCombatReadabilityValue(
          cfg.icon, "countFontSize",
          math_max(tonumber(cfg.icon.countFontSize) or 0, 16),
          "buffBars"
        )
        SetCombatReadabilityValue(
          cfg.icon, "outline", "THICKOUTLINE", "buffBars"
        )
      end
    end
  end
  BuffBars.RebuildCustomBars()

  local changes = CombatReadabilityChanges
  CombatReadabilityChanges = nil

  if #changes > 0 then
    self.__puiCombatReadabilityUndo = {
      profile = self.db.profile,
      moduleProfiles = moduleProfiles,
      changes = changes,
    }

    SetStatus("Combat readability applied. Undo is available in UI Theme.")
  else
    SetStatus("Combat readability settings are already applied.")
  end

  return true
end

local PAGE_DEFINITIONS = {
  { "welcome", "Welcome and accessibility" },
  { "profiles", "Profile and setup choices" },
  { "appearance", "Appearance and readability" },
  { "navigation", "Finding your way around" },
  { "unitframes", "Player, target and unit frames", "frames" },
  { "group", "Party and raid frames", "frames" },
  { "auras", "Buffs, debuffs and indicators", "frames" },
  { "bars", "Action bars and keybinds", "frames" },
  { "prd", "Personal Resource Display", "combat" },
  { "spec", "Your specialization", "combat" },
  { "cooldowns", "Cooldown Manager", "combat" },
  { "trackerCooldown", "Custom cooldown buttons and bars", "combat" },
  { "trackerStacks", "Custom stacks and durations", "combat" },
  { "trackerCharges", "Custom charge bars", "combat" },
  { "utility", "Items, racials and group utility", "combat" },
  { "meters", "Damage meters", "interface" },
  { "everyday", "Everyday interface", "interface" },
  { "convenience", "Convenience and visual helpers", "convenience" },
  { "arrange", "Arrange your UI", "arrange" },
  { "review", "Review your setup" },
  { "ready", "Ready to play" },
}

local function Onboarding()
  return Addon.db.profile.pui.onboarding
end

local function BuildRoute(target)
  wipe(pages)
  currentPage = 1
  for _, definition in ipairs(PAGE_DEFINITIONS) do
    if not definition[3] or sections[definition[3]] ~= false then
      pages[#pages + 1] = definition
      if definition[1] == target then currentPage = #pages end
    end
  end
end

local function SelectPage(index)
  ns.KeyboardNavigation.ClearKeyboardFocus()
  currentPage = math.max(1, math.min(#pages, index))
  Onboarding().installerPage = pages[currentPage][1]
  RefreshPage()
end

local function Navigate(id)
  for index, definition in ipairs(pages) do
    if definition[1] == id then SelectPage(index) return end
  end
  SetStatus("Include this chapter on Profile and setup choices to visit it.")
end

local function RequireReload()
  Onboarding().installerReload = true
  Content.pendingReload = true
end

local returnFromOptions
local returnFromEditMode
local function OpenEditMode()
  if InCombatLockdown() then SetStatus("Open Edit Mode after combat ends.") return end
  wizardFrame:Hide()
  returnFromEditMode = true
  Addon:SetEditMode(true)
end

ns.FrameUtil.RegisterEditModeParticipant("PleebUIInstallerReturn", {
  OnEditModeChanged = function(_, enabled)
    if not enabled and returnFromEditMode then
      returnFromEditMode = nil
      C_Timer.After(0, function() ShowInstaller() end)
    end
  end,
}, 100)

local function OpenOptions(path)
  if InCombatLockdown() then SetStatus("Open settings after combat ends.") return end
  wizardFrame:Hide()
  Addon:OpenOptions(path, false, true)
  local optionsFrame = Addon._OptionsWindow
  returnFromOptions = true
  if not optionsFrame.__puiInstallerReturnHook then
    optionsFrame.__puiInstallerReturnHook = true
    optionsFrame:HookScript("OnHide", function()
      if not returnFromOptions then return end
      returnFromOptions = nil
      C_Timer.After(0, function()
        if not optionsFrame:IsShown() then ShowInstaller() end
      end)
    end)
  end
end

local function OpenTracker(draft)
  if InCombatLockdown() then SetStatus("Create trackers after combat ends.") return end
  wizardFrame:Hide()
  ns.PCMCustomTrackerInstaller:Open(function()
    ShowInstaller()
  end, draft)
end

local function Finish(reload)
  if InCombatLockdown() then SetStatus("Finish setup after combat ends.") return end
  local db = Onboarding()
  db.installComplete = true
  db.installVersion = ns.InstallFlowVersion
  Addon.db.global.installed = true
  ns.Flags.FirstRunPending = false
  reload = reload or db.installerReload == true
  db.installerReload = nil
  wizardFrame:Hide()
  if reload then ReloadUI() end
end

local function ApplyWindowTheme(frame)
  local colors = Theme.GetColors()
  local background = colors.background
  Theme.SetSquareBackdrop(frame, {
    bg = { background[1], background[2], background[3], 1 },
    border = colors.border,
  }, Theme.GetEdgeSize())
  Theme.SetSquareBackdrop(frame.Sidebar, { bg = colors.control, border = colors.border }, Theme.GetEdgeSize())
  Theme.ApplyFont(frame.Title, "title", 20)
  Theme.ApplyFont(frame.Status, "body", 12)
  Theme.ApplyFont(frame.Progress, "body", 12)
  for _, button in ipairs(frame.Buttons) do
    Theme.WidgetSkins.UIButton(button)
    button:SetHeight(Theme.GetOptionsPointerTargetSize(34))
  end
end

local function RefreshChrome(frame)
  ApplyWindowTheme(frame)
  frame:SetScale(math.min(Theme.GetOptionsUIScale(), (UIParent:GetWidth() - 24) / 850, (UIParent:GetHeight() - 24) / 560))
  Content.Relayout()
  frame.Next:SetText(currentPage == #pages and (Onboarding().installerReload and "Finish and reload" or "Finish setup") or "Continue")
end

local profileCallbacks = {}
function profileCallbacks:Changed()
  if not wizardFrame or not wizardFrame:IsShown() then return end
  Content.Suspend(wizardFrame.Content)
  C_Timer.After(0, function()
    if wizardFrame:IsShown() then Content.Invalidate(); ShowInstaller() end
  end)
end

RefreshPage = function()
  local frame = wizardFrame
  local definition = pages[currentPage]
  Content.pendingReload = Onboarding().installerReload == true
  frame.Title:SetText(definition[2])
  frame.Progress:SetText(string.format("%d / %d", currentPage, #pages))
  frame.Status:SetText("")
  frame.Previous:SetEnabled(currentPage > 1)
  frame.Next:SetText(currentPage == #pages and (Content.pendingReload and "Finish and reload" or "Finish setup") or "Continue")
  frame.Skip:SetShown(currentPage < #pages)
  for index, button in ipairs(frame.PageButtons) do
    local page = pages[index]
    button:SetShown(page ~= nil)
    if page then
      button:SetText(string.format("%02d  %s", index, page[2]))
      button:SetEnabled(index ~= currentPage)
    end
  end
  local rowHeight = Theme.GetOptionsPointerTargetSize(38)
  for index, button in ipairs(frame.PageButtons) do
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", frame.SidebarCanvas, "TOPLEFT", 0, -(index - 1) * (rowHeight + 4))
    button:SetPoint("TOPRIGHT", frame.SidebarCanvas, "TOPRIGHT", 0, -(index - 1) * (rowHeight + 4))
    button:SetHeight(rowHeight)
  end
  frame.SidebarCanvas:SetHeight(#pages * (rowHeight + 4))
  local offset = (currentPage - 1) * (rowHeight + 4)
  frame.SidebarScroll:SetVerticalScroll(math.max(0, math.min(frame.SidebarScroll:GetVerticalScrollRange(), offset - frame.SidebarScroll:GetHeight() / 2)))
  Content.Show(frame.Content, definition[1])
  frame.Scroll:SetVerticalScroll(0)
end

local function BuildFrame()
  local frame = CreateFrame("Frame", "PleebUIOnboardingFrame", UIParent, "BackdropTemplate")
  frame:Hide()
  frame:SetSize(1170, 820)
  frame:SetPoint("CENTER")
  frame:SetClampedToScreen(true)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetResizeBounds(850, 560)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame.Buttons, frame.PageButtons = {}, {}
  local function Text(parent)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text.__puiOptionsFontOwned = true
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    return text
  end
  local function Button(parent, title, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 34)
    button:SetText(title)
    button:SetScript("OnClick", callback)
    ns.KeyboardNavigation.RegisterFrame(button, "button", "installer" .. title)
    frame.Buttons[#frame.Buttons + 1] = button
    return button
  end
  frame.Title = Text(frame)
  frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", 265, -22)
  frame.Title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -240, -22)
  frame.Title:SetHeight(60)
  frame.Sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.Sidebar:SetPoint("TOPLEFT", 12, -18)
  frame.Sidebar:SetPoint("BOTTOMLEFT", 12, 116)
  frame.Sidebar:SetWidth(235)
  local function Scroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    Theme.WidgetSkins.Scrollbar(scroll.ScrollBar)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
      self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 48)))
    end)
    return scroll
  end
  frame.SidebarScroll = Scroll(frame.Sidebar)
  frame.SidebarScroll:SetPoint("TOPLEFT", 6, -6)
  frame.SidebarScroll:SetPoint("BOTTOMRIGHT", -28, 6)
  frame.SidebarCanvas = CreateFrame("Frame", nil, frame.SidebarScroll)
  frame.SidebarCanvas:SetSize(195, 1000)
  frame.SidebarScroll:SetScrollChild(frame.SidebarCanvas)
  for index = 1, #PAGE_DEFINITIONS do
    local button = Button(frame.SidebarCanvas, "", 195, function() SelectPage(index) end)
    button:GetFontString():SetWordWrap(true)
    button:GetFontString():SetJustifyH("LEFT")
    frame.PageButtons[index] = button
  end
  frame.Scroll = Scroll(frame)
  frame.Scroll:SetPoint("TOPLEFT", 265, -92)
  frame.Scroll:SetPoint("BOTTOMRIGHT", -44, 116)
  local canvas = CreateFrame("Frame", nil, frame.Scroll)
  canvas:SetSize(830, 1000)
  frame.Scroll:SetScrollChild(canvas)
  frame.Canvas = canvas
  ns.InstallerSettings.SetCallbacks({
    requireReload = RequireReload,
    changed = function() RefreshChrome(frame) end,
  })
  frame.Content = Content.Create(canvas, {
    status = SetStatus, navigate = Navigate, requireReload = RequireReload,
    openOptions = OpenOptions, openTracker = OpenTracker, openEditMode = OpenEditMode,
    closeForOptions = function() frame:Hide() end,
    resize = function(height) canvas:SetHeight(height + 24) end,
    refreshTheme = function() RefreshChrome(frame) end,
    chooseMode = function(mode)
      Onboarding().installerMode = mode
      for _, chapter in ipairs(Content.Chapters) do sections[chapter.key] = mode == "full" end
      Onboarding().installerSections = sections
      BuildRoute("profiles")
      SelectPage(currentPage)
    end,
    changedRoute = function()
      local target = pages[currentPage][1]
      Onboarding().installerMode = "custom"
      Onboarding().installerSections = sections
      BuildRoute(target)
      RefreshPage()
    end,
  })
  frame.Content:SetPoint("TOPLEFT", canvas, "TOPLEFT")
  frame.Content:SetPoint("TOPRIGHT", canvas, "TOPRIGHT")
  frame.Scroll:SetScript("OnSizeChanged", function(_, width)
    canvas:SetWidth(math.max(480, width - 4))
    Content.Relayout(frame.Content)
  end)
  frame.Status = Text(frame)
  frame.Status:SetPoint("BOTTOMLEFT", 265, 82)
  frame.Status:SetPoint("BOTTOMRIGHT", -30, 82)
  frame.Status:SetHeight(30)
  frame.Progress = Text(frame)
  frame.Progress:SetPoint("BOTTOMLEFT", 24, 84)
  frame.Progress:SetWidth(200)
  frame.Previous = Button(frame, "Back", 110, function() SelectPage(currentPage - 1) end)
  frame.Previous:SetPoint("BOTTOMLEFT", 18, 22)
  frame.Save = Button(frame, "Save and exit", 145, function() frame:Hide() end)
  frame.Save:SetPoint("LEFT", frame.Previous, "RIGHT", 12, 0)
  frame.Skip = Button(frame, "Skip section", 140, function()
    local chapter = pages[currentPage][3]
    local target = currentPage + 1
    if chapter then
      while target < #pages and pages[target][3] == chapter do target = target + 1 end
    end
    SelectPage(target)
  end)
  frame.Skip:SetPoint("LEFT", frame.Save, "RIGHT", 12, 0)
  frame.Next = Button(frame, "Continue", 180, function()
    if currentPage == #pages then Finish(false) else SelectPage(currentPage + 1) end
  end)
  frame.Next:SetPoint("BOTTOMRIGHT", -22, 22)
  frame.Accessibility = Button(frame, "Accessibility", 155, function() Navigate("appearance") end)
  frame.Accessibility:SetPoint("TOPRIGHT", -60, -23)
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() frame:Hide() end)
  Theme.WidgetSkins.CloseButton(close)
  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(18, 18)
  grip:SetPoint("BOTTOMRIGHT", -1, 1)
  local texture = grip:CreateTexture(nil, "OVERLAY")
  texture:SetAllPoints(grip)
  texture:SetAtlas("damagemeters-scalehandle")
  grip:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end end)
  grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)
  frame:SetScript("OnHide", function()
    frame:UnregisterAllEvents()
    for _, event in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do Addon.db.UnregisterCallback(profileCallbacks, event) end
    ns.InstallerPreview.Deactivate()
    Content.Hide(frame.Content)
  end)
  frame:SetScript("OnShow", function()
    for _, event in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do Addon.db.RegisterCallback(profileCallbacks, event, "Changed") end
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("PLAYER_TALENT_UPDATE")
    frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    ns.InstallerPreview.Activate()
  end)
  frame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end
    if event == "PLAYER_REGEN_DISABLED" then
      Content.Suspend(frame.Content)
      SetStatus("Setup is paused during combat. Your place and choices are kept.")
    elseif not InCombatLockdown() then
      Content.Invalidate(frame.Content)
      RefreshPage()
    end
  end)
  ns.KeyboardNavigation.BindWindow(frame, false, function() frame:Hide() end, nil, function(key, keyboardInput)
    return Content.HandleKey(frame.Content, key, keyboardInput)
  end)
  table.insert(UISpecialFrames, frame:GetName())
  return frame
end

ShowInstaller = function()
  local db = Onboarding()
  sections = db.installerSections or {}
  Content.sections = sections
  BuildRoute(db.installerPage)
  returnFromOptions = nil
  returnFromEditMode = nil
  if Addon._OptionsWindow then Addon._OptionsWindow:Hide() end
  wizardFrame = wizardFrame or BuildFrame()
  RefreshChrome(wizardFrame)
  local screenWidth = UIParent:GetWidth() / wizardFrame:GetScale()
  local screenHeight = UIParent:GetHeight() / wizardFrame:GetScale()
  wizardFrame:SetSize(math.min(1170, screenWidth - 24), math.min(820, screenHeight - 24))
  wizardFrame:Show()
  wizardFrame.Canvas:SetWidth(math.max(480, wizardFrame.Scroll:GetWidth() - 4))
  RefreshPage()
  if InCombatLockdown() then Content.Suspend(wizardFrame.Content) end
  wizardFrame:Raise()
end

function Addon:IsInstallWizardPending()
  local db = Onboarding()
  return db.installComplete ~= true or (tonumber(db.installVersion) or 0) < ns.InstallFlowVersion
end

function Addon:ShowInstallWizard(force)
  if force or self:IsInstallWizardPending() then ShowInstaller() end
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if InCombatLockdown() then self:RegisterEvent("PLAYER_REGEN_ENABLED") return end
  if Addon.db.global.onboarding.movementReminderPromptPending then
    ns.Modules.MovementWarning:ShowEnablePrompt(function()
      if Addon:IsInstallWizardPending() then ShowInstaller() end
    end)
  elseif Addon:IsInstallWizardPending() then
    ShowInstaller()
  end
end)
