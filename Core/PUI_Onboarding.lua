local _, ns = ...

local Addon = ns.Addon
local Theme = ns.Theme
local LSM = ns.LSM
local OptionsUtil = ns.OptionsUtil
local AceGUI = LibStub("AceGUI-3.0")
local InCombatLockdown = _G.InCombatLockdown
local ReloadUI = _G.ReloadUI
local UIParent = _G.UIParent
local C_CVar = _G.C_CVar
local UnitClass = _G.UnitClass
local UnitLevel = _G.UnitLevel
local UnitName = _G.UnitName
local UnitPowerType = _G.UnitPowerType
local AbbreviateLargeNumbers = _G.AbbreviateLargeNumbers
local C_Spell = _G.C_Spell
local PowerBarColor = _G.PowerBarColor
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min

local INSTALL_FLOW_VERSION = ns.InstallFlowVersion
local WIZARD_WIDTH = 920
local WIZARD_HEIGHT = 820
local WIZARD_MIN_WIDTH = 760
local WIZARD_MIN_HEIGHT = 700
local PROGRESS_WIDTH = 300
local PROGRESS_INNER_WIDTH = PROGRESS_WIDTH - 4
local PREVIEW_UPDATE_INTERVAL = 1 / 30
local ACTION_BUTTON_SPACING = 8
local COOLDOWN_MANAGER_CVAR = "cooldownViewerEnabled"

local activeFlow
local currentPage = 1
local wizardFrame
local wizardScaleSnapshot
local RefreshWizardTheme
local RefreshWizardPage
local LayoutProfileChoiceControls
local RefreshProfileChoiceControls
local LayoutUnitFrameControls
local RefreshUnitFrameControls
local LayoutPRDControls
local RefreshPRDControls
local LayoutQualityControls
local RefreshQualityControls
local OpenCustomTrackerInstallerFromWizard

local function GetInstallOnboardingDB()
  return Addon.db.profile.pui.onboarding
end

local function SetStatus(text)
  if wizardFrame then
    wizardFrame.StatusMessage:SetText(text or "")
  end
end

local function ApplyWizardFont(fontString, role, size, outline)
  fontString.__puiOptionsFontOwned = true
  Theme.ApplyFont(fontString, role, size, outline)
end

local function ApplyWizardButtonBorder(button)
  local colors = Theme.GetColors()
  local bg = colors.control or { 0.07, 0.07, 0.09, 1 }
  local border = colors.border or { 1, 1, 1, 1 }
  local enabled = button:IsEnabled()

  Theme.SetSquareBackdrop(button, {
    bg = { bg[1], bg[2], bg[3], enabled and 0.92 or 0.52 },
    border = { border[1], border[2], border[3], enabled and 1 or 0.45 },
  }, math_max(Theme.GetEdgeSize(), 2))
end

local function SkinWizardButton(button)
  local fontString = button:GetFontString()
  if fontString then
    fontString.__puiOptionsFontOwned = true
  end

  Theme.WidgetSkins.UIButton(button)
  ApplyWizardButtonBorder(button)

  if button.__puiWizardBorderHooked ~= true then
    button.__puiWizardBorderHooked = true
    button:HookScript("OnShow", ApplyWizardButtonBorder)
    button:HookScript("OnEnable", ApplyWizardButtonBorder)
    button:HookScript("OnDisable", ApplyWizardButtonBorder)
  end
end

local function SetWizardUIFont(value)
  Theme.SetGlobalUIFont(value)
  SetStatus("UI font applied: " .. tostring(value))
end

local function SetWizardUIFontSize(value)
  Theme.SetOptionsFontSize(value)
  SetStatus(string.format("UI font size applied: %d", Theme.GetOptionsFontSize()))
end

local function SetWizardUIOutline(value)
  Theme.SetGlobalUIOutline(value)
  SetStatus("UI font outline applied: " .. (Theme.GetOutlineList()[value] or "None"))
end

local function ApplyThemeColorPreset(key)
  if not Theme.ApplyColorPreset(key) then
    return
  end

  RefreshWizardTheme()

  SetStatus("Theme preset applied: " .. (Theme.GetColorPresetLabel(key) or key))
end

local function ApplyCombatReadabilityTextConfig(text, nameSize, healthSize, powerSize)
  if type(text) ~= "table" then
    return
  end

  if nameSize then
    text.sizeName = math_max(tonumber(text.sizeName) or 0, nameSize)
  end
  if healthSize then
    text.sizeHealth = math_max(tonumber(text.sizeHealth) or 0, healthSize)
  end
  if powerSize then
    text.sizePower = math_max(tonumber(text.sizePower) or 0, powerSize)
  end

  text.outline = "THICKOUTLINE"
  text.nameOutline = "THICKOUTLINE"
  text.healthOutline = "THICKOUTLINE"
  text.powerOutline = "THICKOUTLINE"
end

local function ApplyCombatReadabilityPRDText(text, size)
  if type(text) ~= "table" then
    return
  end

  text.size = math_max(tonumber(text.size) or 0, size)
  text.flags = "THICKOUTLINE"
end

local function ApplyCombatReadabilityPRDStyle(style)
  if type(style) ~= "table" then
    return
  end

  style.borderSize = math_max(tonumber(style.borderSize) or 0, 2)

  if type(style.bgColor) == "table" then
    style.bgColor[4] = math_max(tonumber(style.bgColor[4]) or 0, 0.85)
  end
end

function Addon:ApplyCombatReadabilityPreset()
  if InCombatLockdown() then
    SetStatus("Combat readability cannot be applied during combat.")
    return false
  end

  local UF = ns.Modules.UnitFrames
  local ufDB = UF.db.profile

  ufDB.text.shortenValues = true
  ApplyCombatReadabilityTextConfig(ufDB.text, 16, 16, 14)

  for _, cfg in pairs(ufDB.units or {}) do
    if type(cfg) == "table" then
      ApplyCombatReadabilityTextConfig(cfg.text, 16, 16, 14)
    end
  end

  UF:SafeRefresh("text")

  local groupedModules = {
    ns.Modules.PartyFrames,
    ns.Modules.RaidFrames,
  }

  for i = 1, #groupedModules do
    local module = groupedModules[i]
    if module and module.db and module.db.profile then
      local profile = module.db.profile
      ApplyCombatReadabilityTextConfig(profile.text, 14, 14, 12)

      if type(profile.auras) == "table" then
        profile.auras.buffIconSize = math_max(tonumber(profile.auras.buffIconSize) or 0, 20)
        profile.auras.debuffIconSize = math_max(tonumber(profile.auras.debuffIconSize) or 0, 20)
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
      cfg.fontSize = math_max(tonumber(cfg.fontSize) or 0, 16)
      cfg.fontOutline = "THICKOUTLINE"
      Cooldowns:NormalizeCustomTrackerPresentation(cfg, "cooldown")
      cfg.icon.fontSize = math_max(tonumber(cfg.icon.fontSize) or 0, 16)
      cfg.icon.countFontSize = math_max(tonumber(cfg.icon.countFontSize) or 0, 16)
      cfg.icon.outline = "THICKOUTLINE"
    end
  end
  Cooldowns:SpellBars_Rebuild()

  local chargeBars = Cooldowns:GetCooldownStackBarsDB() or {}
  for _, cfg in pairs(chargeBars) do
    if type(cfg) == "table" then
      cfg.fontSize = math_max(tonumber(cfg.fontSize) or 0, 16)
      cfg.fontOutline = "THICKOUTLINE"
      Cooldowns:NormalizeCustomTrackerPresentation(cfg, "charge")
      cfg.icon.fontSize = math_max(tonumber(cfg.icon.fontSize) or 0, 16)
      cfg.icon.countFontSize = math_max(tonumber(cfg.icon.countFontSize) or 0, 16)
      cfg.icon.outline = "THICKOUTLINE"
    end
  end
  Cooldowns:CooldownStackBars_Rebuild()

  local buffBars = BuffBars.GetStackBarsDB() or {}
  for _, cfg in pairs(buffBars) do
    if type(cfg) == "table" then
      cfg.fontSize = math_max(tonumber(cfg.fontSize) or 0, 16)
      cfg.outline = "THICKOUTLINE"
      cfg.durationCountFontSize = math_max(tonumber(cfg.durationCountFontSize) or 0, 16)
      cfg.durationOutline = "THICKOUTLINE"
      Cooldowns:NormalizeCustomTrackerPresentation(cfg, cfg.kind)
      cfg.icon.fontSize = math_max(tonumber(cfg.icon.fontSize) or 0, 16)
      cfg.icon.countFontSize = math_max(tonumber(cfg.icon.countFontSize) or 0, 16)
      cfg.icon.outline = "THICKOUTLINE"
    end
  end
  BuffBars.RebuildCustomBars()

  SetStatus("Combat readability applied. You can adjust every changed setting normally.")
  return true
end

local function CaptureWizardScaleSnapshot()
  local options = Addon:GetGlobalOptionsDB()

  wizardScaleSnapshot = {
    scale = UIParent:GetScale(),
    useCustomUIScale = options.useCustomUIScale ~= false,
  }
end

local function ApplyScale(scale, label)
  if InCombatLockdown() then
    SetStatus("UI scale cannot be changed during combat.")
    return
  end

  Addon.FrameScale:SetUIScale(scale, false)
  SetStatus(string.format("%s applied: %.3f", label, scale))
end

local function ApplyRecommendedScale()
  ApplyScale(Addon.FrameScale:PixelBestSize(), "Recommended UI scale")
end

local function ApplyResolutionScalePreset(key)
  ApplyScale(Addon.FrameScale:GetResolutionScalePreset(key), key .. " UI scale")
end

local function RestoreOpeningScale()
  if InCombatLockdown() then
    SetStatus("UI scale cannot be changed during combat.")
    return
  end

  if not wizardScaleSnapshot then
    CaptureWizardScaleSnapshot()
  end

  Addon.FrameScale:SetUIScale(wizardScaleSnapshot.scale, false)

  if not wizardScaleSnapshot.useCustomUIScale then
    Addon.FrameScale:SetUseCustomUIScale(false)
  end

  SetStatus(string.format("Opening UI scale restored: %.3f", wizardScaleSnapshot.scale))
end

local function MarkInstallComplete()
  local db = GetInstallOnboardingDB()

  db.installComplete = true
  db.installVersion = INSTALL_FLOW_VERSION
  Addon.db.global.installed = true
  ns.Flags.FirstRunPending = false
end

local function ActivateExistingProfileAndExit(profileName)
  local ok, message = Addon:ActivateExistingProfile(profileName)
  if not ok then
    SetStatus(message)

    if wizardFrame and wizardFrame.ProfileChoiceHost then
      RefreshProfileChoiceControls(wizardFrame.ProfileChoiceHost)
    end

    return
  end

  MarkInstallComplete()
  ReloadUI()
end

LayoutProfileChoiceControls = function(host)
  local width = math_min(520, math_max(320, host:GetWidth() - 48))
  host.ProfileWidget:SetWidth(width)
  host.ProfileWidget:SetHeight(64)
  host.ProfileWidget.frame:ClearAllPoints()
  host.ProfileWidget.frame:SetPoint("TOP", host.CurrentProfile, "BOTTOM", 0, -28)
  host.ProfileWidget.frame:Show()
end

RefreshProfileChoiceControls = function(host)
  local values, order = Addon:GetInstallerExistingProfiles()
  local hasProfiles = #order > 0
  host.CurrentProfile:SetText("Current profile: " .. tostring(Addon.db:GetCurrentProfile()))
  host.ProfileWidget:SetList(values, order)
  host.ProfileWidget:SetValue(nil)
  host.ProfileWidget:SetDisabled(not hasProfiles)
  host.ProfileWidget:SetLabel(hasProfiles and "Replace with an existing profile" or "No other profiles available")
  host.ProfileWidget.frame:Show()

  LayoutProfileChoiceControls(host)
end

local function RefreshCooldownManagerButton(button)
  local enabled = C_CVar.GetCVar(COOLDOWN_MANAGER_CVAR) == "1"
  button:SetText(enabled and "Disable Cooldown Manager" or "Enable Cooldown Manager")
  button:SetEnabled(true)
end

local function ToggleCooldownManager(button)
  local enabled = C_CVar.GetCVar(COOLDOWN_MANAGER_CVAR) == "1"
  C_CVar.SetCVar(COOLDOWN_MANAGER_CVAR, enabled and "0" or "1")
  RefreshCooldownManagerButton(button)

  if enabled then
    SetStatus("Cooldown Manager disabled. It will unload after the next UI reload.")
  else
    SetStatus("Cooldown Manager enabled. It will load after the next UI reload.")
  end
end

local function BuildProfileChoiceControls(frame, colors)
  local host = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  host:SetHeight(230)

  Theme.SetSquareBackdrop(host, {
    bg = colors.background,
    border = colors.border,
  }, math_max(Theme.GetEdgeSize(), 2))

  local continueTitle = host:CreateFontString(nil, "OVERLAY")
  continueTitle:SetPoint("TOPLEFT", host, "TOPLEFT", 24, -24)
  continueTitle:SetPoint("TOPRIGHT", host, "TOPRIGHT", -24, -24)
  continueTitle:SetJustifyH("CENTER")
  ApplyWizardFont(continueTitle, "title", 28)
  continueTitle:SetText("Use this character profile")
  host.ContinueTitle = continueTitle

  local currentProfile = host:CreateFontString(nil, "OVERLAY")
  currentProfile:SetPoint("TOPLEFT", continueTitle, "BOTTOMLEFT", 0, -14)
  currentProfile:SetPoint("TOPRIGHT", continueTitle, "BOTTOMRIGHT", 0, -14)
  currentProfile:SetJustifyH("CENTER")
  ApplyWizardFont(currentProfile, "body", 13)
  host.CurrentProfile = currentProfile

  local profileWidget = AceGUI:Create("Dropdown")
  profileWidget:SetLabel("Replace with an existing profile")
  profileWidget:SetCallback("OnValueChanged", function(_, _, value)
    ActivateExistingProfileAndExit(value)
  end)
  profileWidget.frame:SetParent(host)
  ns.AceHooks.TakeOwnership(profileWidget)
  host.ProfileWidget = profileWidget

  local explanation = host:CreateFontString(nil, "OVERLAY")
  explanation:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 24, 20)
  explanation:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -24, 20)
  explanation:SetJustifyH("CENTER")
  explanation:SetWordWrap(true)
  ApplyWizardFont(explanation, "body", 12)
  explanation:SetText("PleebUI has prepared a profile for this character. Continue with it, or choose another profile above to replace it.")
  host.Explanation = explanation

  host:SetScript("OnSizeChanged", LayoutProfileChoiceControls)
  host:SetScript("OnShow", RefreshProfileChoiceControls)
  host:Hide()

  return host
end

OpenCustomTrackerInstallerFromWizard = function()
  local opener = wizardFrame
  if not opener then
    return
  end

  opener:Hide()
  ns.PCMCustomTrackerInstaller:Open(function(createdTrackerKey)
    if createdTrackerKey then
      return
    end

    if wizardFrame and activeFlow then
      wizardFrame:Show()
      RefreshWizardPage()
      wizardFrame:Raise()
    end
  end)
end

local INSTALL_FLOW = {
  title = "PleebUI Setup",
  skipText = "Skip setup",
  pages = {
    {
      title = "Choose a profile",
      body = "PleebUI has already prepared a profile for this character. Continue with it, or replace it with another existing profile.",
      note = "Choosing another profile reloads the UI and only changes this character's active profile.",
      profileChoice = true,
    },
    {
      title = "Text, colors, and UI scale",
      body = "Choose a font, text style, color preset, and UI scale. The combat readability preset increases text, aura, border, and tracker readability across PleebUI.",
      note = "These settings are shared across PleebUI.",
      accessibility = true,
    },
    {
      title = "Unit Frames",
      body = "Use the preview to set the Player frame. Texture, number abbreviations, and borders also apply to other unit frames.\n\n• Health display chooses the text shown on the health bar.\n• Abbreviate numbers changes 12345 to 12.3k.\n• Aura anchor moves the buff and debuff rows around the frame.\n• Aura visibility shows all auras, only yours, or none.",
      note = "Use Unit Frames for frame sizes, grouped frames, cast bars, colors, text positions, and advanced aura filters.",
      unitFrames = true,
    },
    {
      title = "Personal Resource Display",
      body = "Choose which bars are shown and how they are stacked.\n\n• Use the arrows beside each preview bar to change its top-to-bottom order.\n• Class resources and tracked effects are grouped separately for your current specialization.\n• Main stack width, texture, and border apply only to bars that are not detached.",
      note = "Use Personal Resource Display settings to detach bars or change heights, text, colors, and class-specific options.",
      prd = true,
    },
    {
      title = "Everyday shortcuts",
      body = "Choose automation, interface shortcuts, and warnings you want to use.",
      note = "Allowed invite sources and more detailed behavior are under Quality of Life.",
      quality = true,
    },
    {
      title = "Cooldowns and trackers",
      body = "Choose whether Blizzard's Cooldown Manager is enabled, turn on PleebUI's Consumable Tracker, and preview the custom tracker types. Use /cd to choose Blizzard Cooldown Manager spells.",
      note = "The Consumable Tracker covers potions, Healthstones, combat resurrection items, and equipped on-use trinkets. Custom trackers can be created here or later under Cooldown Manager > Custom Trackers.",
      preview = "customBars",
      actions = {
        {
          text = "Create custom tracker",
          func = OpenCustomTrackerInstallerFromWizard,
        },
      },
    },
    {
      title = "Finish setup",
      body = "Click Finish + Reload to save your setup.",
      note = "After reloading, type /pe to move PleebUI frames and bars.",
    },
  },
}

local ACCESSIBILITY_PRESET_COLUMNS = 3
local ACCESSIBILITY_PRESET_CARD_HEIGHT = 100
local ACCESSIBILITY_PRESET_CARD_SPACING = 10

local function SetPresetPreviewTexture(texture, color, alpha)
  texture:SetColorTexture(
    color[1],
    color[2],
    color[3],
    alpha or color[4] or 1
  )
end

local function LayoutAccessibilityControls(host)
  local innerWidth = math_max(300, host:GetWidth() - 24)
  local spacing = 12
  local columnWidth = (innerWidth - (spacing * 2)) / 3
  local widgets = {
    host.FontWidget,
    host.SizeWidget,
    host.OutlineWidget,
  }

  for i = 1, #widgets do
    local widget = widgets[i]
    widget:SetWidth(columnWidth)
    widget:SetHeight(64)
    widget.frame:ClearAllPoints()
    widget.frame:SetPoint("TOPLEFT", host, "TOPLEFT", 12 + ((i - 1) * (columnWidth + spacing)), -12)
    widget.frame:Show()
  end

  host.ScaleLabel:ClearAllPoints()
  host.ScaleLabel:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -82)
  host.ScaleLabel:SetPoint("RIGHT", host, "RIGHT", -12, 0)

  local scaleButtons = host.ScaleButtons
  local buttonSpacing = 8
  local buttonWidth = (innerWidth - (buttonSpacing * (#scaleButtons - 1))) / #scaleButtons

  for i = 1, #scaleButtons do
    local button = scaleButtons[i]
    button:ClearAllPoints()
    button:SetSize(buttonWidth, 30)
    button:SetPoint("TOPLEFT", host, "TOPLEFT", 12 + ((i - 1) * (buttonWidth + buttonSpacing)), -102)
    button:Show()
  end

  host.PresetLabel:ClearAllPoints()
  host.PresetLabel:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -146)
  host.PresetLabel:SetPoint("RIGHT", host.ReadabilityButton, "LEFT", -10, 0)

  host.ReadabilityButton:ClearAllPoints()
  host.ReadabilityButton:SetSize(170, 26)
  host.ReadabilityButton:SetPoint("TOPRIGHT", host, "TOPRIGHT", -12, -140)
  host.ReadabilityButton:Show()

  local cardWidth = (
    innerWidth
    - (ACCESSIBILITY_PRESET_CARD_SPACING * (ACCESSIBILITY_PRESET_COLUMNS - 1))
  ) / ACCESSIBILITY_PRESET_COLUMNS

  for i = 1, #host.PresetCards do
    local card = host.PresetCards[i]
    local column = (i - 1) % ACCESSIBILITY_PRESET_COLUMNS
    local row = math_floor((i - 1) / ACCESSIBILITY_PRESET_COLUMNS)

    card:ClearAllPoints()
    card:SetSize(cardWidth, ACCESSIBILITY_PRESET_CARD_HEIGHT)
    card:SetPoint(
      "TOPLEFT",
      host,
      "TOPLEFT",
      12 + column * (cardWidth + ACCESSIBILITY_PRESET_CARD_SPACING),
      -168 - row * (ACCESSIBILITY_PRESET_CARD_HEIGHT + ACCESSIBILITY_PRESET_CARD_SPACING)
    )
    card:Show()
  end
end

local function RefreshAccessibilityControls(host)
  host.FontWidget:SetList(Theme.BuildGlobalFontList())
  host.FontWidget:SetValue(Theme.GetGlobalUIFont())
  host.SizeWidget:SetValue(Theme.GetOptionsFontSize())
  host.OutlineWidget:SetList(Theme.GetOutlineList())
  host.OutlineWidget:SetValue(Theme.GetGlobalUIOutline())

  host.FontWidget.frame:Show()
  host.SizeWidget.frame:Show()
  host.OutlineWidget.frame:Show()
  host.ScaleLabel:Show()
  host.PresetLabel:Show()
  host.ReadabilityButton:Show()

  for i = 1, #host.ScaleButtons do
    host.ScaleButtons[i]:Show()
  end

  for i = 1, #host.PresetCards do
    host.PresetCards[i]:Show()
  end

  LayoutAccessibilityControls(host)
end

local function BuildAccessibilityPresetCard(host, presetKey)
  local definition = Theme.GetColorPresetDefinition(presetKey)
  local preview = Theme.GetColorPresetPreviewColors(presetKey)
  local card = CreateFrame("Frame", nil, host, "BackdropTemplate")

  Theme.SetSquareBackdrop(card, {
    bg = preview.background,
    border = preview.border,
  }, 2)

  local title = card:CreateFontString(nil, "OVERLAY")
  title:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -7)
  title:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -7)
  title:SetJustifyH("LEFT")
  ApplyWizardFont(title, "body", 11)
  title:SetTextColor(preview.text[1], preview.text[2], preview.text[3], 1)
  title:SetText(definition.label)
  card.Title = title

  local description = card:CreateFontString(nil, "OVERLAY")
  description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  description:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -2)
  description:SetJustifyH("LEFT")
  ApplyWizardFont(description, "tiny", 9)
  description:SetTextColor(preview.text[1], preview.text[2], preview.text[3], 0.82)
  description:SetText(definition.description or "")
  card.Description = description

  local slider = CreateFrame("Frame", nil, card, "BackdropTemplate")
  slider:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -47)
  slider:SetPoint("TOPRIGHT", card, "TOPRIGHT", -72, -47)
  slider:SetHeight(12)
  Theme.SetSquareBackdrop(slider, {
    bg = preview.control,
    border = preview.border,
  }, 1)

  local sliderFill = slider:CreateTexture(nil, "ARTWORK")
  sliderFill:SetPoint("TOPLEFT", slider, "TOPLEFT", 2, -2)
  sliderFill:SetPoint("BOTTOMLEFT", slider, "BOTTOMLEFT", 2, 2)
  sliderFill:SetWidth(54)
  SetPresetPreviewTexture(sliderFill, preview.accent)
  card.SliderFill = sliderFill

  local checkbox = CreateFrame("Frame", nil, card, "BackdropTemplate")
  checkbox:SetSize(16, 16)
  checkbox:SetPoint("LEFT", slider, "RIGHT", 8, 0)
  Theme.SetSquareBackdrop(checkbox, {
    bg = preview.control,
    border = preview.border,
  }, 1)

  local check = checkbox:CreateTexture(nil, "ARTWORK")
  check:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 4, -4)
  check:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -4, 4)
  SetPresetPreviewTexture(check, preview.accent)
  card.Check = check

  local applyButton = CreateFrame("Button", nil, card, "BackdropTemplate")
  applyButton:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 8, 8)
  applyButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 8)
  applyButton:SetHeight(24)

  local applyText = applyButton:CreateFontString(nil, "OVERLAY")
  applyText:SetPoint("CENTER", applyButton, "CENTER", 0, 0)
  ApplyWizardFont(applyText, "button", 10)
  applyText:SetTextColor(preview.text[1], preview.text[2], preview.text[3], 1)
  applyText:SetText("Apply preset")
  applyButton.Text = applyText

  local function SetApplyButtonState(hovered)
    Theme.SetSquareBackdrop(applyButton, {
      bg = preview.control,
      border = hovered and preview.accent or preview.border,
    }, 2)
  end

  SetApplyButtonState(false)

  applyButton:SetScript("OnEnter", function()
    SetApplyButtonState(true)
  end)
  applyButton:SetScript("OnLeave", function()
    SetApplyButtonState(false)
  end)
  applyButton:SetScript("OnClick", function()
    ApplyThemeColorPreset(presetKey)
  end)

  card.ApplyButton = applyButton
  card.PresetKey = presetKey
  return card
end

local function BuildAccessibilityControls(frame, colors)
  local host = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  host:SetHeight(390)
  Theme.SetSquareBackdrop(host, {
    bg = colors.background,
    border = colors.border,
  }, math_max(Theme.GetEdgeSize(), 2))

  local fontWidget = AceGUI:Create("LSM30_Font")
  fontWidget:SetLabel("UI Font Style")
  fontWidget:SetList(Theme.BuildGlobalFontList())
  fontWidget:SetValue(Theme.GetGlobalUIFont())
  fontWidget:SetCallback("OnValueChanged", function(_, _, value)
    SetWizardUIFont(value)
    RefreshAccessibilityControls(host)
  end)
  fontWidget.frame:SetParent(host)
  ns.AceHooks.TakeOwnership(fontWidget)
  host.FontWidget = fontWidget

  local range = Theme.OptionsFontSizeRange
  local sizeWidget = AceGUI:Create("PUI_Slider")
  sizeWidget:SetLabel("UI Font Size")
  sizeWidget:SetSliderValues(range.min, range.max, range.step)
  sizeWidget:SetValue(Theme.GetOptionsFontSize())
  sizeWidget:SetCallback("OnValueChanged", function(_, _, value)
    SetWizardUIFontSize(value)
    RefreshAccessibilityControls(host)
  end)
  sizeWidget.frame:SetParent(host)
  ns.AceHooks.TakeOwnership(sizeWidget)
  host.SizeWidget = sizeWidget

  local outlineWidget = AceGUI:Create("Dropdown")
  outlineWidget:SetLabel("UI Font Outline")
  outlineWidget:SetList(Theme.GetOutlineList())
  outlineWidget:SetValue(Theme.GetGlobalUIOutline())
  outlineWidget:SetCallback("OnValueChanged", function(_, _, value)
    SetWizardUIOutline(value)
    RefreshAccessibilityControls(host)
  end)
  outlineWidget.frame:SetParent(host)
  ns.AceHooks.TakeOwnership(outlineWidget)
  host.OutlineWidget = outlineWidget

  local scaleLabel = host:CreateFontString(nil, "OVERLAY")
  scaleLabel:SetJustifyH("LEFT")
  ApplyWizardFont(scaleLabel, "tiny", 11)
  scaleLabel:SetText("UI Scale")
  host.ScaleLabel = scaleLabel

  local scaleButtons = {}
  local scaleActions = {
    {
      text = "Recommended",
      func = ApplyRecommendedScale,
    },
    {
      text = "1080p",
      func = function()
        ApplyResolutionScalePreset("1080p")
      end,
    },
    {
      text = "1440p",
      func = function()
        ApplyResolutionScalePreset("1440p")
      end,
    },
    {
      text = "4K",
      func = function()
        ApplyResolutionScalePreset("4K")
      end,
    },
    {
      text = "Restore previous scale",
      func = RestoreOpeningScale,
    },
  }

  for i = 1, #scaleActions do
    local action = scaleActions[i]
    local button = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
    button:SetText(action.text)
    button:SetScript("OnClick", action.func)
    SkinWizardButton(button)
    scaleButtons[i] = button
  end

  host.ScaleButtons = scaleButtons

  local presetLabel = host:CreateFontString(nil, "OVERLAY")
  presetLabel:SetJustifyH("LEFT")
  ApplyWizardFont(presetLabel, "tiny", 11)
  presetLabel:SetText("Accessibility color presets")
  host.PresetLabel = presetLabel

  local readabilityButton = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
  readabilityButton:SetText("Improve combat readability")
  readabilityButton:SetScript("OnClick", function()
    Addon:ApplyCombatReadabilityPreset()
  end)
  SkinWizardButton(readabilityButton)
  host.ReadabilityButton = readabilityButton

  host.PresetCards = {}

  for i = 1, #Theme.ColorPresetOrder do
    host.PresetCards[i] = BuildAccessibilityPresetCard(host, Theme.ColorPresetOrder[i])
  end

  host:SetScript("OnSizeChanged", LayoutAccessibilityControls)
  host:SetScript("OnShow", RefreshAccessibilityControls)

  host:Hide()
  return host
end

local function GetSolidColor(color)
  return { color[1], color[2], color[3], 1 }
end

RefreshWizardTheme = function()
  local frame = wizardFrame
  local colors = Theme.GetColors()
  local backgroundColor = GetSolidColor(colors.background)
  local borderColor = GetSolidColor(colors.border)
  local controlColor = GetSolidColor(colors.control)
  local accentColor = colors.accent
  local edge = math_max(Theme.GetEdgeSize(), 2)

  Theme.SetSquareBackdrop(frame, {
    bg = backgroundColor,
    border = borderColor,
  }, Theme.GetEdgeSize())

  Theme.SetSquareBackdrop(frame.ProfileChoiceHost, {
    bg = backgroundColor,
    border = borderColor,
  }, edge)

  Theme.SetSquareBackdrop(frame.AccessibilityHost, {
    bg = backgroundColor,
    border = borderColor,
  }, edge)

  Theme.SetSquareBackdrop(frame.UnitFrameHost, {
    bg = backgroundColor,
    border = borderColor,
  }, edge)

  Theme.SetSquareBackdrop(frame.PRDHost, {
    bg = backgroundColor,
    border = borderColor,
  }, edge)

  Theme.SetSquareBackdrop(frame.QualityHost, {
    bg = backgroundColor,
    border = borderColor,
  }, edge)

  Theme.SetSquareBackdrop(frame.PreviewHost, {
    bg = backgroundColor,
    border = borderColor,
  }, edge)

  Theme.SetSquareBackdrop(frame.Progress, {
    bg = controlColor,
    border = borderColor,
  }, edge)

  frame.Accent:SetColorTexture(accentColor[1], accentColor[2], accentColor[3], 1)
  frame.ProgressFill:SetColorTexture(accentColor[1], accentColor[2], accentColor[3], 1)
  frame.ResizeTexture:SetVertexColor(accentColor[1], accentColor[2], accentColor[3], 0.35)

  Theme.WidgetSkins.Dropdown(frame.ProfileChoiceHost.ProfileWidget)
  Theme.WidgetSkins.Dropdown(frame.AccessibilityHost.FontWidget)
  Theme.ApplyAce3Skin(frame.AccessibilityHost.SizeWidget)
  Theme.WidgetSkins.Dropdown(frame.AccessibilityHost.OutlineWidget)

  if frame.PreviewHost.ConsumableTrackerWidget then
    Theme.ApplyAce3Skin(frame.PreviewHost.ConsumableTrackerWidget)
  end
  if frame.PreviewHost.CooldownManagerButton then
    SkinWizardButton(frame.PreviewHost.CooldownManagerButton)
  end

  for i = 1, #frame.AccessibilityHost.ScaleButtons do
    SkinWizardButton(frame.AccessibilityHost.ScaleButtons[i])
  end
  SkinWizardButton(frame.AccessibilityHost.ReadabilityButton)

  if frame.UnitFrameHost.ControlWidgets then
    for i = 1, #frame.UnitFrameHost.ControlWidgets do
      Theme.ApplyAce3Skin(frame.UnitFrameHost.ControlWidgets[i])
    end
  end

  if frame.PRDHost.ControlWidgets then
    for i = 1, #frame.PRDHost.ControlWidgets do
      Theme.ApplyAce3Skin(frame.PRDHost.ControlWidgets[i])
    end
  end

  for i = 1, #frame.QualityHost.ControlWidgets do
    Theme.ApplyAce3Skin(frame.QualityHost.ControlWidgets[i])
  end

  for i = 1, #frame.ActionButtons do
    SkinWizardButton(frame.ActionButtons[i])
  end

  SkinWizardButton(frame.Previous)
  SkinWizardButton(frame.Skip)
  SkinWizardButton(frame.Next)
end

local function GetPreviewColor(value, fallback)
  value = type(value) == "table" and value or fallback
  return {
    tonumber(value[1]) or tonumber(value.r) or fallback[1],
    tonumber(value[2]) or tonumber(value.g) or fallback[2],
    tonumber(value[3]) or tonumber(value.b) or fallback[3],
    tonumber(value[4]) or tonumber(value.a) or fallback[4],
  }
end

local function GetPreviewClassColor()
  local class = select(2, UnitClass("player"))
  local color = RAID_CLASS_COLORS[class]
  return { color.r, color.g, color.b, 1 }
end

local function GetPreviewFillColor(cfg)
  if cfg.useClassColor ~= false then
    return GetPreviewClassColor()
  end

  return GetPreviewColor(cfg.barColor, { 1, 1, 1, 1 })
end

local function GetPreviewDefaults()
  local cooldowns = ns.Modules.CooldownManager
  local buffBars = ns.Modules.PCM_BB

  return {
    cooldown = cooldowns.NormalizeSpellBarEntry({
      showIcon = false,
    }),
    charge = cooldowns.NormalizeCooldownStackBarEntry({
      showIcon = false,
      maxCharges = 2,
    }),
    stack = buffBars.EnsureStackBarDefaults({
      kind = "stack",
      maxStacks = 20,
      showSpellIconNextToBar = false,
    }),
    duration = buffBars.EnsureStackBarDefaults({
      kind = "duration",
      showSpellIconNextToBar = false,
    }),
  }
end

local function CreatePreviewRow(parent, labelText, yOffset, height)
  local row = CreateFrame("Frame", nil, parent)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
  row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
  row:SetHeight(height or 36)

  local label = row:CreateFontString(nil, "OVERLAY")
  label:SetPoint("LEFT", row, "LEFT", 4, 0)
  label:SetWidth(154)
  label:SetJustifyH("LEFT")
  ApplyWizardFont(label, "body", 11)
  label:SetText(labelText)

  return row
end

local function CreatePreviewBar(row, cfg, textureKey, backgroundColor, borderColor)
  local presentation = ns.Presentation.Create("PCMBar", row, { kind = "duration" })
  ns.Presentation.Apply("PCMBar", presentation, {
    config = cfg,
    width = tonumber(cfg.width) or 250,
    height = tonumber(cfg.height) or 25,
    showIcon = false,
    texture = textureKey,
    color = GetPreviewFillColor(cfg),
    backgroundColor = backgroundColor,
    borderColor = borderColor,
    borderSize = cfg.borderSize or 2,
    font = cfg,
  }, {
    minimum = 0,
    maximum = 1,
    value = 1,
    text = "",
  })

  presentation.frame:ClearAllPoints()
  presentation.frame:SetPoint("LEFT", row, "LEFT", 164, 0)
  return presentation.status, presentation.valueText
end

local function CreateChargePreview(row, cfg)
  local presentation = ns.Presentation.Create("PCMBar", row, { template = "charge" })
  ns.Presentation.Apply("PCMBar", presentation, {
    config = cfg,
    width = tonumber(cfg.width) or 250,
    height = tonumber(cfg.height) or 25,
    showIcon = false,
    maxCharges = 2,
    color = GetPreviewFillColor(cfg),
    font = cfg,
  })

  presentation.frame:ClearAllPoints()
  presentation.frame:SetPoint("LEFT", row, "LEFT", 164, 0)

  local bars = {}
  local texts = {}
  local slots = ns.PCMPresentation.EnsureChargeSlots(presentation, 2)

  for index = 1, 2 do
    local slot = slots[index]
    slot.fullBar:SetMinMaxValues(0, 1)
    slot.fullBar:SetValue(1)

    local text = slot.frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", slot.frame, "CENTER", 0, 0)
    Theme.ApplyFont(text, "cooldown", tonumber(cfg.fontSize) or 14, cfg.fontOutline or cfg.outline or "OUTLINE")

    bars[index] = slot.fullBar
    texts[index] = text
  end

  return bars, texts
end

local function CreateStackPreview(row, cfg)
  local presentation = ns.Presentation.Create("PCMBar", row, { kind = "stack" })
  ns.Presentation.Apply("PCMBar", presentation, {
    config = cfg,
    width = tonumber(cfg.width) or 250,
    height = tonumber(cfg.height) or 25,
    showIcon = false,
    texture = cfg.stackTexture,
    color = GetPreviewFillColor(cfg),
    backgroundColor = GetPreviewColor(cfg.backgroundColor, { 0.12, 0.12, 0.12, 0.95 }),
    borderColor = GetPreviewColor(cfg.borderColor, { 0.20, 0.20, 0.24, 1.00 }),
    borderSize = cfg.borderSize or 2,
    font = cfg,
  })

  presentation.frame:ClearAllPoints()
  presentation.frame:SetPoint("LEFT", row, "LEFT", 164, 0)

  local segments = ns.PCMPresentation.LayoutStackSegments(presentation, {
    config = cfg,
    maxStacks = 20,
    gap = cfg.borderSize or 2,
    color = GetPreviewFillColor(cfg),
  })

  presentation.valueText:ClearAllPoints()
  presentation.valueText:SetPoint("BOTTOM", presentation.frame, "TOP", 0, 1)
  return segments, presentation.valueText
end

local function UpdateCustomBarsPreview(self, elapsed)
  self.animationTime = (self.animationTime or 0) + elapsed
  self.updateElapsed = (self.updateElapsed or 0) + elapsed

  if self.updateElapsed < PREVIEW_UPDATE_INTERVAL then
    return
  end

  self.updateElapsed = 0

  local time = self.animationTime
  local chargePhase = time % 10.8
  local chargeOne
  local chargeTwo
  local chargeOneText = ""
  local chargeTwoText = ""

  if chargePhase < 0.6 then
    chargeOne = 1
    chargeTwo = 1
  elseif chargePhase < 3.6 then
    local elapsedCharge = chargePhase - 0.6
    chargeOne = 1
    chargeTwo = elapsedCharge / 3
    chargeTwoText = string.format("%.1f", 3 - elapsedCharge)
  elseif chargePhase < 4.2 then
    chargeOne = 1
    chargeTwo = 1
  elseif chargePhase < 7.2 then
    local elapsedCharge = chargePhase - 4.2
    chargeOne = elapsedCharge / 3
    chargeTwo = 0
    chargeOneText = string.format("%.1f", 3 - elapsedCharge)
  elseif chargePhase < 10.2 then
    local elapsedCharge = chargePhase - 7.2
    chargeOne = 1
    chargeTwo = elapsedCharge / 3
    chargeTwoText = string.format("%.1f", 3 - elapsedCharge)
  else
    chargeOne = 1
    chargeTwo = 1
  end

  self.ChargeBars[1]:SetValue(chargeOne)
  self.ChargeBars[2]:SetValue(chargeTwo)
  self.ChargeTexts[1]:SetText(chargeOneText)
  self.ChargeTexts[2]:SetText(chargeTwoText)

  local stackPhase = time % 10
  local stackCount

  if stackPhase < 5 then
    stackCount = 5 + math_floor((stackPhase / 5) * 10 + 0.5)
  else
    stackCount = 15 - math_floor(((stackPhase - 5) / 5) * 10 + 0.5)
  end

  local stackDuration = 5 - (time % 5)

  for i = 1, 20 do
    self.StackSegments[i]:SetValue(i <= stackCount and 1 or 0)
  end

  self.StackText:SetFormattedText("%d   %.1fs", stackCount, stackDuration)

  local cooldownElapsed = time % 10
  local cooldownRemaining = 10 - cooldownElapsed
  self.CooldownBar:SetValue(cooldownElapsed)
  self.CooldownText:SetFormattedText("%.1fs", cooldownRemaining)

  local durationRemaining = 8 - (time % 8)
  self.DurationBar:SetValue(durationRemaining)
  self.DurationText:SetFormattedText("%.1fs", durationRemaining)
end

local function BuildCustomBarsPreview(frame, colors)
  local host = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  host:SetHeight(282)
  Theme.SetSquareBackdrop(host, {
    bg = colors.background,
    border = colors.border,
  }, math_max(Theme.GetEdgeSize(), 2))

  local defaults = GetPreviewDefaults()
  local baseBackground = { 0.12, 0.12, 0.12, 0.95 }
  local baseBorder = { 0.20, 0.20, 0.24, 1.00 }

  local cooldownManagerLabel = host:CreateFontString(nil, "OVERLAY")
  cooldownManagerLabel:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -14)
  ApplyWizardFont(cooldownManagerLabel, "body", 12)
  cooldownManagerLabel:SetText("Blizzard Cooldown Manager")

  local cooldownManagerButton = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
  cooldownManagerButton:SetSize(220, 28)
  cooldownManagerButton:SetPoint("TOPRIGHT", host, "TOPRIGHT", -12, -8)
  cooldownManagerButton:SetScript("OnClick", function(self)
    ToggleCooldownManager(self)
  end)
  SkinWizardButton(cooldownManagerButton)
  host.CooldownManagerButton = cooldownManagerButton

  local consumableLabel = host:CreateFontString(nil, "OVERLAY")
  consumableLabel:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -52)
  ApplyWizardFont(consumableLabel, "body", 12)
  consumableLabel:SetText("PleebUI Consumable Tracker")

  local consumableWidget = AceGUI:Create("CheckBox")
  consumableWidget:SetLabel("Show consumables and equipped on-use trinkets")
  consumableWidget:SetCallback("OnValueChanged", function(_, _, value)
    local cooldowns = ns.Modules.CooldownManager
    cooldowns:SetConsumableTrackerEnabled(value == true)
    SetStatus(value and "Consumable Tracker enabled." or "Consumable Tracker disabled.")
  end)
  consumableWidget:SetWidth(420)
  consumableWidget.frame:SetParent(host)
  consumableWidget.frame:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -64)
  ns.AceHooks.TakeOwnership(consumableWidget)
  host.ConsumableTrackerWidget = consumableWidget

  local customTrackerLabel = host:CreateFontString(nil, "OVERLAY")
  customTrackerLabel:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -100)
  ApplyWizardFont(customTrackerLabel, "body", 12)
  customTrackerLabel:SetText("Custom tracker examples")

  local chargeRow = CreatePreviewRow(host, "Charge cooldown", -114, 32)
  host.ChargeBars, host.ChargeTexts = CreateChargePreview(chargeRow, defaults.charge)

  local stackRow = CreatePreviewRow(host, "Stack duration", -152, 34)
  host.StackSegments, host.StackText = CreateStackPreview(stackRow, defaults.stack)

  local cooldownRow = CreatePreviewRow(host, "Cooldown", -194, 32)
  host.CooldownBar, host.CooldownText = CreatePreviewBar(
    cooldownRow,
    defaults.cooldown,
    defaults.cooldown.texture,
    GetPreviewColor(defaults.cooldown.backgroundColor, baseBackground),
    GetPreviewColor(defaults.cooldown.borderColor, baseBorder)
  )
  host.CooldownBar:SetMinMaxValues(0, 10)

  local durationRow = CreatePreviewRow(host, "Duration", -232, 32)
  host.DurationBar, host.DurationText = CreatePreviewBar(
    durationRow,
    defaults.duration,
    defaults.duration.durationTexture,
    GetPreviewColor(defaults.duration.backgroundColor, baseBackground),
    GetPreviewColor(defaults.duration.borderColor, baseBorder)
  )
  host.DurationBar:SetMinMaxValues(0, 8)

  host:SetScript("OnShow", function(self)
    RefreshCooldownManagerButton(self.CooldownManagerButton)
    self.ConsumableTrackerWidget:SetValue(
      ns.Modules.CooldownManager:GetConsumableTrackerEnabled()
    )
    self.animationTime = 0
    self.updateElapsed = PREVIEW_UPDATE_INTERVAL
    UpdateCustomBarsPreview(self, 0)
    self:SetScript("OnUpdate", UpdateCustomBarsPreview)
  end)

  host:SetScript("OnHide", function(self)
    self:SetScript("OnUpdate", nil)
  end)

  host:Hide()
  return host
end

local function BlockUnitFrameInstallerChange()
  if not InCombatLockdown() then
    return false
  end

  SetStatus("Unit Frame settings cannot be changed during combat.")
  return true
end

local function CreateInstallerWidget(host, widgetType, label, callback)
  local widget = AceGUI:Create(widgetType)
  widget:SetLabel(label)
  widget:SetCallback("OnValueChanged", callback)
  widget.frame:SetParent(host)

  if widgetType == "CheckBox" then
    widget.__puiWrapLabel = true
  end

  ns.AceHooks.TakeOwnership(widget)
  return widget
end

local function LayoutInstallerWidgetGrid(host, widgets, columns, topOffset, rowHeight)
  local spacing = 10
  local innerWidth = math_max(360, host:GetWidth() - 24)
  local columnWidth = (innerWidth - ((columns - 1) * spacing)) / columns

  for i = 1, #widgets do
    local widget = widgets[i]
    local column = (i - 1) % columns
    local row = math_floor((i - 1) / columns)

    widget:SetWidth(columnWidth)
    widget:SetHeight(rowHeight)
    widget.frame:ClearAllPoints()
    widget.frame:SetPoint(
      "TOPLEFT",
      host,
      "TOPLEFT",
      12 + column * (columnWidth + spacing),
      -(topOffset + row * rowHeight)
    )
    widget.frame:Show()
  end
end

local function SetPreviewBorder(preview, color, thickness)
  thickness = math_max(0, math_floor((tonumber(thickness) or 0) + 0.5))

  preview.BorderTop:SetHeight(thickness)
  preview.BorderBottom:SetHeight(thickness)
  preview.BorderLeft:SetWidth(thickness)
  preview.BorderRight:SetWidth(thickness)

  preview.BorderTop:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
  preview.BorderBottom:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
  preview.BorderLeft:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
  preview.BorderRight:SetColorTexture(color[1], color[2], color[3], color[4] or 1)

  local shown = thickness > 0
  preview.BorderTop:SetShown(shown)
  preview.BorderBottom:SetShown(shown)
  preview.BorderLeft:SetShown(shown)
  preview.BorderRight:SetShown(shown)
end

local function BuildPreviewBorder(frame)
  local top = frame:CreateTexture(nil, "OVERLAY", nil, 7)
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

  local bottom = frame:CreateTexture(nil, "OVERLAY", nil, 7)
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  local left = frame:CreateTexture(nil, "OVERLAY", nil, 7)
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)

  local right = frame:CreateTexture(nil, "OVERLAY", nil, 7)
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  frame.BorderTop = top
  frame.BorderBottom = bottom
  frame.BorderLeft = left
  frame.BorderRight = right
end

local function ResolvePowerColor(token, fallback)
  local color = PowerBarColor[token] or fallback
  return {
    tonumber(color.r) or tonumber(color[1]) or 0.20,
    tonumber(color.g) or tonumber(color[2]) or 0.55,
    tonumber(color.b) or tonumber(color[3]) or 1.00,
    1,
  }
end

local function FormatPreviewNumber(value, shorten)
  if shorten then
    return AbbreviateLargeNumbers(value)
  end

  return tostring(value)
end

local function FormatUnitFrameHealthText(mode, shorten)
  local current = 1234567
  local maximum = 1690000
  local percent = math_floor((current / maximum) * 100 + 0.5)
  local currentText = FormatPreviewNumber(current, shorten)
  local maximumText = FormatPreviewNumber(maximum, shorten)

  if mode == "CUR" then
    return currentText
  elseif mode == "CUR_MAX" then
    return currentText .. " / " .. maximumText
  elseif mode == "PERCENT" then
    return percent .. "%"
  elseif mode == "CUR_PERCENT" then
    return currentText .. " - " .. percent .. "%"
  end

  return ""
end

local PREVIEW_BUFF_SPELL_IDS = {
  17,
  139,
  21562,
}

local PREVIEW_DEBUFF_SPELL_IDS = {
  589,
  6789,
  51514,
}

local function BuildPreviewAuraGroup(parent)
  local group = CreateFrame("Frame", nil, parent)
  group.Icons = {}

  for i = 1, 3 do
    local button = CreateFrame("Frame", nil, group)
    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetAllPoints(button)
    button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    BuildPreviewBorder(button)

    button.Duration = button:CreateFontString(nil, "OVERLAY")
    button.Duration:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    Theme.ApplyFont(button.Duration, "tiny", 9, "OUTLINE")

    button.Count = button:CreateFontString(nil, "OVERLAY")
    button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    Theme.ApplyFont(button.Count, "tiny", 9, "OUTLINE")

    group.Icons[i] = button
  end

  return group
end

local function LayoutPreviewAuraIcons(group, layout)
  local growLeft = layout.growthX == "LEFT"
  local anchor = growLeft and "TOPRIGHT" or "TOPLEFT"
  local direction = growLeft and -1 or 1
  local step = layout.size + layout.spacing

  for i = 1, #group.Icons do
    local button = group.Icons[i]
    button:ClearAllPoints()
    button:SetPoint(anchor, group, anchor, direction * ((i - 1) * step), 0)
    button:SetSize(layout.size, layout.size)
  end
end

local function RefreshPreviewAuraGroup(preview, group, display, auraDB, spellIDs, shown, visibility)
  if not display then
    group:Hide()
    return
  end

  local layout = ns.UFAuraContainers.BuildDisplayLayout(preview, display)
  local appearance = ns.UFAuraFilters.BuildEffectiveAppearance(auraDB, display)
  local visibleIconCount = visibility == "PLAYER" and math_min(2, #group.Icons) or #group.Icons

  group:ClearAllPoints()
  group:SetPoint(
    layout.initialAnchor,
    layout.attachTarget,
    layout.relativePoint,
    layout.xOffset,
    layout.yOffset
  )
  group:SetSize(layout.width, layout.size)
  LayoutPreviewAuraIcons(group, layout)

  local borderColor = GetPreviewColor(appearance.borderColor, { 0, 0, 0, 1 })
  local borderSize = math_max(1, math_floor((tonumber(appearance.borderSize) or 1) + 0.5))

  for i = 1, #group.Icons do
    local button = group.Icons[i]
    button.Icon:SetTexture(C_Spell.GetSpellTexture(spellIDs[i]) or "Interface\\Icons\\INV_Misc_QuestionMark")
    button.Duration:SetText(i == 1 and "8" or "")
    button.Count:SetText(i == 3 and "2" or "")
    SetPreviewBorder(button, borderColor, borderSize)
    button:SetShown(i <= visibleIconCount)
  end

  group:SetShown(shown)
end

local function RefreshUnitFramePreview(host)
  local UF = ns.UnitFrames
  local db = UF.db.profile
  local cfg = UF:GetConfigUnit("player")
  local layout = ns.UFStyle.CalculateFrameLayout(cfg, db)
  local preview = host.Preview
  local previewArea = host.PreviewArea
  local availableWidth = math_max(280, previewArea:GetWidth() - 40)
  local previewWidth = math_min(360, availableWidth)
  local scale = previewWidth / layout.width
  local colors = ns.UFStyle.GetUFThemeColors()
  local borderColor = GetPreviewColor(colors.border, { 0.10, 0.10, 0.10, 1 })
  local _, classToken = UnitClass("player")
  local classColor = RAID_CLASS_COLORS[classToken]
  local healthColor

  if cfg.useClassColor ~= false then
    healthColor = { classColor.r, classColor.g, classColor.b, 1 }
  else
    local configuredHealthColor = cfg.colors and cfg.colors.healthBar or colors.healthBar
    healthColor = GetPreviewColor(configuredHealthColor, { 0.35, 0.35, 0.35, 1 })
  end

  local _, powerToken = UnitPowerType("player")
  local powerColor = ResolvePowerColor(powerToken, PowerBarColor.MANA)
  local presentationColors = {
    bg = colors.bg,
    border = borderColor,
    healthBar = colors.healthBar,
    healthMissing = colors.healthMissing,
    powerMissing = colors.powerMissing,
    nameText = colors.nameText,
    healthText = colors.healthText,
    powerText = colors.powerText,
  }

  preview:SetScale(scale)
  preview:SetAlpha(db.enabled ~= false and 1 or 0.45)

  ns.Presentation.Apply("UnitFrame", preview, {
    unit = "player",
    config = cfg,
    layout = layout,
    colors = presentationColors,
    textColors = presentationColors,
    fontRevision = UF._fontRev or 0,
    useClassColor = cfg.useClassColor ~= false,
    options = {
      forceNoPower = layout.powerHeight <= 0,
      useConfigText = true,
    },
  }, {
    health = 73,
    healthMax = 100,
    power = 62,
    powerMin = 0,
    powerMax = 100,
    name = (UnitName("player") or "Player") .. "  " .. tostring(UnitLevel("player") or ""),
    healthText = FormatUnitFrameHealthText(cfg.text.healthMode or "CUR_PERCENT", db.text.shortenValues == true),
    powerText = "62",
    healthColor = healthColor,
    powerColor = powerColor,
    healthMissingColor = colors.healthMissing,
  })

  local auraDB = ns.UFAuraFilters.BuildFrameAuraDB(preview, "player")
  local displayIDs = ns.UFAuraFilters.BUILT_IN_DISPLAY_IDS
  local buffDisplay = auraDB.customDisplays and auraDB.customDisplays[displayIDs.DEFAULT_BUFF]
  local debuffDisplay = auraDB.customDisplays and auraDB.customDisplays[displayIDs.DEFAULT_DEBUFF]
  local aurasEnabled = auraDB.enabled ~= false
  local showDebuffs = UF:GetQuickSetupValue("showDebuffs")
  local showBuffs = UF:GetQuickSetupValue("showBuffs")
  local debuffVisibility = UF:GetQuickSetupValue("debuffVisibility")
  local buffVisibility = UF:GetQuickSetupValue("buffVisibility")

  RefreshPreviewAuraGroup(
    preview,
    preview.Debuffs,
    debuffDisplay,
    auraDB,
    PREVIEW_DEBUFF_SPELL_IDS,
    aurasEnabled and showDebuffs,
    debuffVisibility
  )

  RefreshPreviewAuraGroup(
    preview,
    preview.Buffs,
    buffDisplay,
    auraDB,
    PREVIEW_BUFF_SPELL_IDS,
    aurasEnabled and showBuffs,
    buffVisibility
  )
end

LayoutUnitFrameControls = function(host)
  LayoutInstallerWidgetGrid(host, host.GeneralWidgets, 4, 142, 72)

  host.AuraSectionLabel:ClearAllPoints()
  host.AuraSectionLabel:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -364)
  host.AuraSectionLabel:SetPoint("RIGHT", host, "RIGHT", -12, 0)

  LayoutInstallerWidgetGrid(host, host.AuraWidgets, 4, 388, 76)
  RefreshUnitFramePreview(host)
end

RefreshUnitFrameControls = function(host)
  local UF = ns.UnitFrames

  host.EnabledWidget:SetValue(UF:GetQuickSetupValue("enabled"))
  host.TextureWidget:SetList(OptionsUtil.BuildStatusbarValues(false))
  host.TextureWidget:SetValue(UF:GetQuickSetupValue("texture"))
  host.HealthModeWidget:SetList(ns.UnitFrameHealthTextModeValues)
  host.HealthModeWidget:SetValue(UF:GetQuickSetupValue("healthMode"))
  host.ShortenWidget:SetValue(UF:GetQuickSetupValue("shortenValues"))
  host.PowerWidget:SetValue(UF:GetQuickSetupValue("showPower"))
  host.ClassColorWidget:SetValue(UF:GetQuickSetupValue("classColor"))
  host.PortraitWidget:SetValue(UF:GetQuickSetupValue("portraitsEnabled"))
  host.BorderSizeWidget:SetValue(UF:GetQuickSetupValue("borderThickness"))
  host.BorderPlacementWidget:SetList({
    inside = "Inside frame - shrinks bars",
    outside = "Outside frame - preserves bars",
  })
  host.BorderPlacementWidget:SetValue(UF:GetQuickSetupValue("borderPlacement"))

  local aurasEnabled = UF:GetQuickSetupValue("aurasEnabled")
  local showBuffs = UF:GetQuickSetupValue("showBuffs")
  local showDebuffs = UF:GetQuickSetupValue("showDebuffs")
  local showAnyAuras = showBuffs or showDebuffs

  host.AurasEnabledWidget:SetValue(aurasEnabled)
  host.BuffsEnabledWidget:SetValue(showBuffs)
  host.DebuffsEnabledWidget:SetValue(showDebuffs)
  host.AuraAnchorWidget:SetList(ns.UnitFrameAuraAnchorValues)
  host.AuraAnchorWidget:SetValue(UF:GetQuickSetupValue("auraAnchor"))
  host.AuraSizeWidget:SetValue(UF:GetQuickSetupValue("auraSize"))
  host.BuffVisibilityWidget:SetList(ns.UnitFrameAuraVisibilityValues)
  host.BuffVisibilityWidget:SetValue(UF:GetQuickSetupValue("buffVisibility"))
  host.DebuffVisibilityWidget:SetList(ns.UnitFrameAuraVisibilityValues)
  host.DebuffVisibilityWidget:SetValue(UF:GetQuickSetupValue("debuffVisibility"))

  host.BuffsEnabledWidget:SetDisabled(not aurasEnabled)
  host.DebuffsEnabledWidget:SetDisabled(not aurasEnabled)
  host.AuraAnchorWidget:SetDisabled(not aurasEnabled or not showAnyAuras)
  host.AuraSizeWidget:SetDisabled(not aurasEnabled or not showAnyAuras)
  host.BuffVisibilityWidget:SetDisabled(not aurasEnabled or not showBuffs)
  host.DebuffVisibilityWidget:SetDisabled(not aurasEnabled or not showDebuffs)

  for i = 1, #host.ControlWidgets do
    host.ControlWidgets[i].frame:Show()
  end

  LayoutUnitFrameControls(host)
end

local function BuildUnitFrameControls(frame, colors)
  local host = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  host:SetHeight(558)
  Theme.SetSquareBackdrop(host, {
    bg = colors.background,
    border = colors.border,
  }, math.max(Theme.GetEdgeSize(), 2))

  local previewArea = CreateFrame("Frame", nil, host)
  previewArea:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -8)
  previewArea:SetPoint("TOPRIGHT", host, "TOPRIGHT", -12, -8)
  previewArea:SetHeight(124)
  host.PreviewArea = previewArea

  local preview = ns.Presentation.Create("UnitFrame", previewArea, {
    unit = "player",
    useConfigText = true,
  })
  preview:SetPoint("CENTER", previewArea, "CENTER", 0, -2)
  preview.Buffs = BuildPreviewAuraGroup(preview)
  preview.Debuffs = BuildPreviewAuraGroup(preview)
  host.Preview = preview

  host.EnabledWidget = CreateInstallerWidget(host, "CheckBox", "Enable PleebUI unit frames", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("enabled", value)
    RefreshUnitFrameControls(host)
    SetStatus(value and "PleebUI unit frames will be enabled when setup finishes." or "PleebUI unit frames will be disabled when setup finishes.")
  end)

  host.TextureWidget = CreateInstallerWidget(host, "LSM30_Statusbar", "Unit frame texture", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("texture", value)
    RefreshUnitFrameControls(host)
    SetStatus("Unit frame texture applied: " .. tostring(value))
  end)

  host.HealthModeWidget = CreateInstallerWidget(host, "Dropdown", "Player health display", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("healthMode", value)
    RefreshUnitFrameControls(host)
    SetStatus("Player health display updated.")
  end)

  host.ShortenWidget = CreateInstallerWidget(host, "CheckBox", "Abbreviate numbers", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("shortenValues", value)
    RefreshUnitFrameControls(host)
    SetStatus(value and "Health and power values will be abbreviated." or "Health and power values will use full numbers.")
  end)

  host.PowerWidget = CreateInstallerWidget(host, "CheckBox", "Show player power", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("showPower", value)
    RefreshUnitFrameControls(host)
    SetStatus(value and "Player power bar enabled." or "Player power bar hidden.")
  end)

  host.ClassColorWidget = CreateInstallerWidget(host, "CheckBox", "Class-color player health", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("classColor", value)
    RefreshUnitFrameControls(host)
    SetStatus(value and "Player health uses the class color." or "Player health uses the configured health color.")
  end)

  host.PortraitWidget = CreateInstallerWidget(host, "CheckBox", "Show portraits on supported frames", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("portraitsEnabled", value)
    RefreshUnitFrameControls(host)
    SetStatus(value and "Portraits enabled for supported unit frames." or "Portraits disabled for supported unit frames.")
  end)

  host.BorderSizeWidget = CreateInstallerWidget(host, "PUI_Slider", "Border thickness", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("borderThickness", value)
    RefreshUnitFrameControls(host)
    SetStatus(string.format("Unit frame border thickness: %d", value))
  end)
  host.BorderSizeWidget:SetSliderValues(0, 6, 1)

  host.BorderPlacementWidget = CreateInstallerWidget(host, "Dropdown", "Border placement", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("borderPlacement", value)
    RefreshUnitFrameControls(host)
    SetStatus(value == "inside" and "Borders shrink the bars inside the frame." or "Borders sit outside without covering the bars.")
  end)

  local auraSectionLabel = host:CreateFontString(nil, "OVERLAY")
  auraSectionLabel:SetJustifyH("LEFT")
  ApplyWizardFont(auraSectionLabel, "body", 12)
  auraSectionLabel:SetText("Player Buffs and Debuffs")
  host.AuraSectionLabel = auraSectionLabel

  host.AurasEnabledWidget = CreateInstallerWidget(host, "CheckBox", "Show unit frame auras", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("aurasEnabled", value)
    RefreshUnitFrameControls(host)
    SetStatus(value and "Unit frame buffs and debuffs enabled." or "Unit frame buffs and debuffs disabled.")
  end)

  host.BuffsEnabledWidget = CreateInstallerWidget(host, "CheckBox", "Show player buffs", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("showBuffs", value)
    RefreshUnitFrameControls(host)
    SetStatus(value and "Player buffs shown." or "Player buffs hidden.")
  end)

  host.DebuffsEnabledWidget = CreateInstallerWidget(host, "CheckBox", "Show player debuffs", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("showDebuffs", value)
    RefreshUnitFrameControls(host)
    SetStatus(value and "Player debuffs shown." or "Player debuffs hidden.")
  end)

  host.AuraAnchorWidget = CreateInstallerWidget(host, "Dropdown", "Aura block anchor point", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("auraAnchor", value)
    RefreshUnitFrameControls(host)
    SetStatus("Player aura anchor updated.")
  end)

  host.AuraSizeWidget = CreateInstallerWidget(host, "PUI_Slider", "Aura icon size", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("auraSize", value)
    RefreshUnitFrameControls(host)
    SetStatus(string.format("Player aura icon size: %d", value))
  end)
  host.AuraSizeWidget:SetSliderValues(10, 64, 1)

  host.BuffVisibilityWidget = CreateInstallerWidget(host, "Dropdown", "Buff visibility", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("buffVisibility", value)
    RefreshUnitFrameControls(host)
    SetStatus("Player buff visibility updated.")
  end)

  host.DebuffVisibilityWidget = CreateInstallerWidget(host, "Dropdown", "Debuff visibility", function(_, _, value)
    if BlockUnitFrameInstallerChange() then return end
    local UF = ns.UnitFrames
    UF:SetQuickSetupValue("debuffVisibility", value)
    RefreshUnitFrameControls(host)
    SetStatus("Player debuff visibility updated.")
  end)

  host.GeneralWidgets = {
    host.EnabledWidget,
    host.TextureWidget,
    host.HealthModeWidget,
    host.ShortenWidget,
    host.PowerWidget,
    host.ClassColorWidget,
    host.PortraitWidget,
    host.BorderSizeWidget,
    host.BorderPlacementWidget,
  }

  host.AuraWidgets = {
    host.AurasEnabledWidget,
    host.BuffsEnabledWidget,
    host.DebuffsEnabledWidget,
    host.AuraAnchorWidget,
    host.AuraSizeWidget,
    host.BuffVisibilityWidget,
    host.DebuffVisibilityWidget,
  }

  host.ControlWidgets = {
    host.EnabledWidget,
    host.TextureWidget,
    host.HealthModeWidget,
    host.ShortenWidget,
    host.PowerWidget,
    host.ClassColorWidget,
    host.PortraitWidget,
    host.BorderSizeWidget,
    host.BorderPlacementWidget,
    host.AurasEnabledWidget,
    host.BuffsEnabledWidget,
    host.DebuffsEnabledWidget,
    host.AuraAnchorWidget,
    host.AuraSizeWidget,
    host.BuffVisibilityWidget,
    host.DebuffVisibilityWidget,
  }

  host:SetScript("OnSizeChanged", LayoutUnitFrameControls)
  host:Hide()
  return host
end

local POWER_LABELS = {
  MANA = "Mana",
  RAGE = "Rage",
  FOCUS = "Focus",
  ENERGY = "Energy",
  COMBO_POINTS = "Combo Points",
  RUNES = "Runes",
  RUNIC_POWER = "Runic Power",
  SOUL_SHARDS = "Soul Shards",
  LUNAR_POWER = "Astral Power",
  HOLY_POWER = "Holy Power",
  MAELSTROM = "Maelstrom",
  CHI = "Chi",
  INSANITY = "Insanity",
  ARCANE_CHARGES = "Arcane Charges",
  FURY = "Fury",
  PAIN = "Pain",
  ESSENCE = "Essence",
  STAGGER = "Stagger",
}

local function GetPRDResourceInfo()
  local PRD = ns.Modules.PRD
  local className, classToken = UnitClass("player")
  local _, primaryToken = UnitPowerType("player")
  PRD:GetSecondaryDefinition()
  local resourceOptions = ns.PRDSecondary:GetResourceOptionsForClass(classToken)
  local resourceNames = {}
  local resources = {}
  local primaryLabel = POWER_LABELS[primaryToken] or primaryToken or "Primary Resource"

  for i = 1, #resourceOptions do
    local resource = resourceOptions[i]
    resourceNames[resource.key] = resource.name
  end

  local function GetResourceLabel(definition)
    if not definition then
      return nil
    end

    if definition.displayMode == "RUNES" then
      return "Runes"
    end

    return resourceNames[definition.resourceKey]
      or POWER_LABELS[definition.token]
      or definition.token
      or "Secondary Resource"
  end

  for index = 1, #(PRD.secondaryResources or {}) do
    local resource = PRD.secondaryResources[index]
    resources[index] = {
      definition = resource.definition,
      label = GetResourceLabel(resource.definition),
      config = resource.config,
    }
  end

  return {
    className = className,
    classToken = classToken,
    primaryToken = primaryToken,
    primaryLabel = primaryLabel,
    primaryColor = ResolvePowerColor(primaryToken, PowerBarColor.MANA),
    resources = resources,
    resourceOptions = resourceOptions,
  }
end

local function PRDInstallerOrderButtonOnClick(button)
  local host = button.__puiPRDInstallerHost
  local targetKey = button.__puiPRDOrderTargetKey
  if not host or not targetKey then
    return
  end

  local PRD = ns.Modules.PRD
  if PRD:SwapStackItems(button.__puiPRDOrderKey, targetKey) then
    RefreshPRDControls(host)
    SetStatus("PRD stack order updated.")
  end
end

local function CreatePRDPreviewOrderButton(bar, text, point, relativePoint, xOffset)
  local button = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
  button:SetSize(22, 22)
  button:SetPoint(point, bar, relativePoint, xOffset, 0)
  button:SetFrameLevel(bar:GetFrameLevel() + 20)
  button:SetText(text)
  button:SetScript("OnClick", PRDInstallerOrderButtonOnClick)
  SkinWizardButton(button)
  button:Hide()
  return button
end

local function CreatePRDPreviewBar(parent)
  local presentation = ns.Presentation.Create("PRDBar", parent)
  local frame = presentation.frame

  frame.__puiPRDPresentation = presentation
  frame.Background = presentation.background
  frame.Fill = presentation.status
  frame.Label = presentation.centerText
  frame.Segments = presentation.segments
  frame.OrderDown = CreatePRDPreviewOrderButton(frame, "▼", "RIGHT", "LEFT", -6)
  frame.OrderUp = CreatePRDPreviewOrderButton(frame, "▲", "LEFT", "RIGHT", 6)

  return frame
end

local function RefreshPRDPreviewBar(bar, texture, fillColor, backgroundColor, borderColor, borderSize, value, label)
  ns.Presentation.Apply("PRDBar", bar.__puiPRDPresentation, {
    appearance = {
      texture = texture,
      style = {
        bgColor = backgroundColor,
        borderColor = borderColor,
        borderSize = borderSize,
      },
    },
    color = fillColor,
    textConfig = { size = 11, flags = "OUTLINE" },
    width = bar:GetWidth(),
    height = bar:GetHeight(),
    visible = true,
  }, {
    minimum = 0,
    maximum = 100,
    value = value,
    centerText = label,
  })

  bar.Fill:Show()

  for i = 1, #bar.Segments do
    bar.Segments[i]:Hide()
  end
end

local function RefreshPRDSecondaryBar(bar, texture, fillColor, backgroundColor, borderColor, borderSize, def, label)
  if def.displayMode == "STAGGER" then
    RefreshPRDPreviewBar(bar, texture, fillColor, backgroundColor, borderColor, borderSize, 48, label)
    return
  end

  ns.Presentation.Apply("PRDBar", bar.__puiPRDPresentation, {
    appearance = {
      texture = texture,
      style = {
        bgColor = backgroundColor,
        borderColor = borderColor,
        borderSize = borderSize,
      },
    },
    color = fillColor,
    textConfig = { size = 11, flags = "OUTLINE" },
    width = bar:GetWidth(),
    height = bar:GetHeight(),
    visible = true,
  }, {
    minimum = 0,
    maximum = 1,
    value = 0,
    centerText = label,
  })

  bar.Fill:Hide()

  local maximum = math_max(1, math_min(10, tonumber(def.max) or 5))
  local gap = math_max(1, tonumber(borderSize) or 1)
  local active = math_max(1, math_floor(maximum * 0.65 + 0.5))

  for i = 1, maximum do
    local segment = bar.Segments[i]
    if not segment then
      segment = CreateFrame("StatusBar", nil, bar)
      bar.Segments[i] = segment
    end

    segment:ClearAllPoints()
    segment:SetPoint("TOP", bar, "TOP", 0, -borderSize)
    segment:SetPoint("BOTTOM", bar, "BOTTOM", 0, borderSize)
    segment:SetStatusBarTexture(texture)
    segment:SetStatusBarColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 1)
    segment:SetMinMaxValues(0, 1)
    segment:SetValue(i <= active and 1 or 0)
    segment:Show()
  end

  local innerWidth = math_max(1, bar:GetWidth() - borderSize * 2)
  local segmentWidth = (innerWidth - gap * (maximum - 1)) / maximum
  for i = 1, maximum do
    local segment = bar.Segments[i]
    segment:SetPoint("LEFT", bar, "LEFT", borderSize + (i - 1) * (segmentWidth + gap), 0)
    segment:SetWidth(segmentWidth)
  end

  for i = maximum + 1, #bar.Segments do
    bar.Segments[i]:Hide()
  end
end

local function RefreshPRDPreview(host)
  local PRD = ns.Modules.PRD
  local db = PRD.db.profile
  local info = GetPRDResourceInfo()
  local preview = host.Preview
  local size = db.size
  local healthCfg = db.health
  local primaryCfg = db.primary
  local secondaryCfg = db.secondary
  local width = math_min(480, math_max(220, tonumber(size.width) or 250))
  local scale = math_min(1.4, width / 250)
  local gap = math_max(0, math_floor((tonumber(size.gap) or 0) * scale + 0.5))
  local resourceGap = math_max(0, math_floor((tonumber(secondaryCfg.gap) or 2) * scale + 0.5))
  local heights = {
    health = math_max(18, math_floor((tonumber(healthCfg.height) or 15) * scale + 0.5)),
    primary = math_max(18, math_floor((tonumber(primaryCfg.height) or 15) * scale + 0.5)),
  }
  local healthTexture = LSM:Fetch("statusbar", healthCfg.texture or "Pleebar", true)
  local primaryTexture = LSM:Fetch("statusbar", primaryCfg.texture or healthCfg.texture or "Pleebar", true)
  local healthColor = { 0.20, 0.78, 0.28, 1 }
  local entries = {
    health = {
      bar = preview.Bars.health,
      height = heights.health,
      visible = db.hideHealth ~= true,
      resource = false,
    },
    primary = {
      bar = preview.Bars.primary,
      height = heights.primary,
      visible = db.hidePrimary ~= true,
      resource = false,
    },
  }

  local labels = { "Health", info.primaryLabel }
  for index = 1, #info.resources do
    local resource = info.resources[index]
    local definition = resource.definition
    local config = resource.config or secondaryCfg
    local resourceKey = definition.resourceKey
    local bar = preview.Bars[resourceKey]
    if not bar then
      bar = CreatePRDPreviewBar(preview)
      preview.Bars[resourceKey] = bar
    end

    entries[resourceKey] = {
      bar = bar,
      height = math_max(18, math_floor((tonumber(config.height) or 15) * scale + 0.5)),
      visible = secondaryCfg.enabled ~= false and config.enabled ~= false,
      resource = true,
      definition = definition,
      config = config,
      label = resource.label,
      texture = LSM:Fetch("statusbar", config.texture or secondaryCfg.texture or primaryCfg.texture or "Pleebar", true),
      color = ResolvePowerColor(definition.colorToken or definition.token, GetPreviewClassColor()),
    }

    if resource.label then
      labels[#labels + 1] = resource.label
    end
  end

  for _, bar in pairs(preview.Bars) do
    bar:Hide()
    bar.OrderDown:Hide()
    bar.OrderUp:Hide()
  end

  local sequence = PRD:GetStackOrder()
  local displayed = {}
  local previous
  local lastWasResource = false
  local totalHeight = 0

  preview:SetWidth(width)
  preview.ResourceSummary:SetText((info.className or "Player") .. ": " .. table.concat(labels, " • "))
  preview:SetAlpha(PRD:IsModuleEnabled() and 1 or 0.45)

  for _, key in ipairs(sequence) do
    local entry = entries[key]
    if entry and entry.visible then
      local bar = entry.bar
      local barGap = previous and (entry.resource and lastWasResource and resourceGap or gap) or 0

      bar:ClearAllPoints()
      bar:SetWidth(width)
      bar:SetHeight(entry.height)
      if previous then
        bar:SetPoint("TOP", previous, "BOTTOM", 0, -barGap)
      else
        bar:SetPoint("TOP", preview.ResourceSummary, "BOTTOM", 0, -8)
      end
      bar:Show()

      displayed[#displayed + 1] = { key = key, bar = bar }
      totalHeight = totalHeight + entry.height + barGap
      previous = bar
      lastWasResource = entry.resource
    end
  end

  for index = 1, #displayed do
    local entry = displayed[index]
    local previousEntry = displayed[index - 1]
    local nextEntry = displayed[index + 1]
    local bar = entry.bar

    bar.OrderDown.__puiPRDInstallerHost = host
    bar.OrderDown.__puiPRDOrderKey = entry.key
    bar.OrderDown.__puiPRDOrderTargetKey = nextEntry and nextEntry.key or nil
    bar.OrderDown:SetEnabled(nextEntry ~= nil)
    bar.OrderDown:Show()

    bar.OrderUp.__puiPRDInstallerHost = host
    bar.OrderUp.__puiPRDOrderKey = entry.key
    bar.OrderUp.__puiPRDOrderTargetKey = previousEntry and previousEntry.key or nil
    bar.OrderUp:SetEnabled(previousEntry ~= nil)
    bar.OrderUp:Show()
  end

  local previewHeight = 28 + totalHeight
  preview:SetHeight(previewHeight)

  if entries.health.visible then
    RefreshPRDPreviewBar(
      preview.Bars.health,
      healthTexture,
      healthColor,
      GetPreviewColor(healthCfg.style.bgColor, { 0, 0, 0, 0.65 }),
      GetPreviewColor(healthCfg.style.borderColor, { 0.20, 0.20, 0.24, 1 }),
      healthCfg.style.borderSize or 1,
      76,
      "Health  76%"
    )
  end

  if entries.primary.visible then
    RefreshPRDPreviewBar(
      preview.Bars.primary,
      primaryTexture,
      info.primaryColor,
      GetPreviewColor(primaryCfg.style.bgColor, { 0, 0, 0, 0.65 }),
      GetPreviewColor(primaryCfg.style.borderColor, { 0.20, 0.20, 0.24, 1 }),
      primaryCfg.style.borderSize or 1,
      64,
      info.primaryLabel .. "  64%"
    )
  end

  for index = 1, #info.resources do
    local resource = info.resources[index]
    local entry = entries[resource.definition.resourceKey]
    if entry and entry.visible then
      local config = entry.config
      RefreshPRDSecondaryBar(
        entry.bar,
        entry.texture,
        entry.color,
        GetPreviewColor(config.style.bgColor, { 0, 0, 0, 0.65 }),
        GetPreviewColor(config.style.borderColor, { 0.20, 0.20, 0.24, 1 }),
        config.style.borderSize or 1,
        entry.definition,
        entry.label
      )
    end
  end

  return previewHeight
end

local function RefreshPRDResourceWidgets(host, info)
  local PRD = ns.Modules.PRD
  local classWidgets = {}
  local trackedWidgets = {}

  for _, widget in pairs(host.ResourceWidgets) do
    widget.frame:Hide()
  end

  for i = 1, #info.resourceOptions do
    local resource = info.resourceOptions[i]
    local resourceKey = resource.key
    local resourceName = resource.name
    local widget = host.ResourceWidgets[resourceKey]

    if not widget then
      widget = CreateInstallerWidget(host, "CheckBox", "Show " .. resourceName, function(_, _, value)
        PRD:SetSecondaryResourceEnabled(resourceKey, value)
        RefreshPRDControls(host)
        SetStatus(value and (resourceName .. " enabled.") or (resourceName .. " disabled."))
      end)
      host.ResourceWidgets[resourceKey] = widget
    end

    widget:SetLabel("Show " .. resourceName)
    widget:SetValue(PRD:IsSecondaryResourceEnabled(resourceKey))
    widget:SetDisabled(PRD:GetQuickSetupValue("showSecondary") ~= true)
    widget.frame:Show()

    local target = resource.category == "TRACKED_EFFECT" and trackedWidgets or classWidgets
    target[#target + 1] = widget
  end

  return classWidgets, trackedWidgets
end

local function LayoutPRDSection(host, label, widgets, topOffset)
  if #widgets == 0 then
    label:Hide()
    return topOffset
  end

  label:ClearAllPoints()
  label:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -topOffset)
  label:SetPoint("RIGHT", host, "RIGHT", -12, 0)
  label:Show()

  local widgetOffset = topOffset + 22
  local rowCount = math_floor((#widgets + 3) / 4)
  LayoutInstallerWidgetGrid(host, widgets, 4, widgetOffset, 66)

  return widgetOffset + rowCount * 66 + 8
end

LayoutPRDControls = function(host)
  local previewHeight = RefreshPRDPreview(host)
  local topOffset = math_max(132, previewHeight + 28)

  host.PreviewArea:SetHeight(math_max(112, previewHeight + 8))
  topOffset = LayoutPRDSection(host, host.DisplaySectionLabel, host.DisplayWidgets, topOffset)
  topOffset = LayoutPRDSection(host, host.ClassResourceSectionLabel, host.ClassResourceWidgets, topOffset)
  topOffset = LayoutPRDSection(host, host.TrackedEffectSectionLabel, host.TrackedEffectWidgets, topOffset)
  topOffset = LayoutPRDSection(host, host.AppearanceSectionLabel, host.AppearanceWidgets, topOffset)

  local requiredHeight = math_max(278, topOffset + 4)
  if host:GetHeight() ~= requiredHeight then
    host:SetHeight(requiredHeight)
  end
end

RefreshPRDControls = function(host)
  local PRD = ns.Modules.PRD
  local info = GetPRDResourceInfo()
  local classWidgets, trackedWidgets = RefreshPRDResourceWidgets(host, info)
  local hasSecondary = #info.resources > 0 or #info.resourceOptions > 0

  host.EnabledWidget:SetValue(PRD:IsModuleEnabled())
  host.HealthWidget:SetValue(PRD:GetQuickSetupValue("showHealth"))
  host.PrimaryWidget:SetValue(PRD:GetQuickSetupValue("showPrimary"))
  host.SecondaryWidget:SetLabel("Enable class resources and tracked effects")
  host.SecondaryWidget:SetValue(PRD:GetQuickSetupValue("showSecondary"))
  host.SecondaryWidget:SetDisabled(not hasSecondary)
  host.TextureWidget:SetList(OptionsUtil.BuildStatusbarValues(false))
  host.TextureWidget:SetValue(PRD:GetQuickSetupValue("texture"))
  host.WidthWidget:SetValue(PRD:GetQuickSetupValue("width"))
  host.BorderWidget:SetValue(PRD:GetQuickSetupValue("borderSize"))

  host.DisplayWidgets = {
    host.EnabledWidget,
    host.HealthWidget,
    host.PrimaryWidget,
    host.SecondaryWidget,
  }
  host.ClassResourceWidgets = classWidgets
  host.TrackedEffectWidgets = trackedWidgets
  host.AppearanceWidgets = {
    host.TextureWidget,
    host.WidthWidget,
    host.BorderWidget,
  }

  host.ControlWidgets = {}
  local groups = {
    host.DisplayWidgets,
    host.ClassResourceWidgets,
    host.TrackedEffectWidgets,
    host.AppearanceWidgets,
  }

  for groupIndex = 1, #groups do
    local widgets = groups[groupIndex]
    for i = 1, #widgets do
      host.ControlWidgets[#host.ControlWidgets + 1] = widgets[i]
      widgets[i].frame:Show()
    end
  end

  LayoutPRDControls(host)
end

local function BuildPRDControls(frame, colors)
  local host = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  host:SetHeight(278)
  Theme.SetSquareBackdrop(host, {
    bg = colors.background,
    border = colors.border,
  }, math.max(Theme.GetEdgeSize(), 2))

  local previewArea = CreateFrame("Frame", nil, host)
  previewArea:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -8)
  previewArea:SetPoint("TOPRIGHT", host, "TOPRIGHT", -12, -8)
  previewArea:SetHeight(112)
  host.PreviewArea = previewArea

  local preview = CreateFrame("Frame", nil, previewArea)
  preview:SetPoint("TOP", previewArea, "TOP", 0, -2)
  preview.ResourceSummary = preview:CreateFontString(nil, "OVERLAY")
  preview.ResourceSummary:SetPoint("TOP", preview, "TOP", 0, 0)
  Theme.ApplyFont(preview.ResourceSummary, "body", 11, "OUTLINE")
  preview.Bars = {
    health = CreatePRDPreviewBar(preview),
    primary = CreatePRDPreviewBar(preview),
  }
  host.Preview = preview

  host.EnabledWidget = CreateInstallerWidget(host, "CheckBox", "Enable PleebUI PRD", function(_, _, value)
    local PRD = ns.Modules.PRD
    PRD:SetModuleEnabled(value)
    RefreshPRDControls(host)
    SetStatus(value and "PleebUI Personal Resource Display enabled." or "PleebUI Personal Resource Display disabled.")
  end)

  host.HealthWidget = CreateInstallerWidget(host, "CheckBox", "Show health", function(_, _, value)
    local PRD = ns.Modules.PRD
    PRD:SetQuickSetupValue("showHealth", value)
    RefreshPRDControls(host)
    SetStatus(value and "PRD health bar shown." or "PRD health bar hidden.")
  end)

  host.PrimaryWidget = CreateInstallerWidget(host, "CheckBox", "Show primary resource", function(_, _, value)
    local PRD = ns.Modules.PRD
    PRD:SetQuickSetupValue("showPrimary", value)
    RefreshPRDControls(host)
    SetStatus(value and "PRD primary resource shown." or "PRD primary resource hidden.")
  end)

  host.SecondaryWidget = CreateInstallerWidget(host, "CheckBox", "Enable class resources and tracked effects", function(_, _, value)
    local PRD = ns.Modules.PRD
    PRD:SetQuickSetupValue("showSecondary", value)
    RefreshPRDControls(host)
    SetStatus(value and "PRD class resources and tracked effects enabled." or "PRD class resources and tracked effects disabled.")
  end)

  host.ResourceWidgets = {}
  host.DisplayWidgets = {}
  host.ClassResourceWidgets = {}
  host.TrackedEffectWidgets = {}
  host.AppearanceWidgets = {}

  local function CreateSectionLabel(text)
    local label = host:CreateFontString(nil, "OVERLAY")
    label:SetJustifyH("LEFT")
    ApplyWizardFont(label, "body", 12)
    label:SetText(text)
    return label
  end

  host.DisplaySectionLabel = CreateSectionLabel("Display")
  host.ClassResourceSectionLabel = CreateSectionLabel("Class resources")
  host.TrackedEffectSectionLabel = CreateSectionLabel("Tracked effects")
  host.AppearanceSectionLabel = CreateSectionLabel("Main stack appearance")

  host.TextureWidget = CreateInstallerWidget(host, "LSM30_Statusbar", "Main stack texture", function(_, _, value)
    local PRD = ns.Modules.PRD
    PRD:SetQuickSetupValue("texture", value)
    RefreshPRDControls(host)
    SetStatus("PRD texture applied: " .. tostring(value))
  end)

  host.WidthWidget = CreateInstallerWidget(host, "PUI_Slider", "Main stack width", function(_, _, value)
    local PRD = ns.Modules.PRD
    PRD:SetQuickSetupValue("width", value)
    RefreshPRDControls(host)
    SetStatus(string.format("PRD width: %d", value))
  end)
  host.WidthWidget:SetSliderValues(120, 600, 1)

  host.BorderWidget = CreateInstallerWidget(host, "PUI_Slider", "Main stack border size", function(_, _, value)
    local PRD = ns.Modules.PRD
    PRD:SetQuickSetupValue("borderSize", value)
    RefreshPRDControls(host)
    SetStatus(string.format("PRD border size: %d", value))
  end)
  host.BorderWidget:SetSliderValues(0, 12, 1)

  host.DisplayWidgets = {
    host.EnabledWidget,
    host.HealthWidget,
    host.PrimaryWidget,
    host.SecondaryWidget,
  }
  host.ClassResourceWidgets = {}
  host.TrackedEffectWidgets = {}
  host.AppearanceWidgets = {
    host.TextureWidget,
    host.WidthWidget,
    host.BorderWidget,
  }

  host.ControlWidgets = {
    host.EnabledWidget,
    host.HealthWidget,
    host.PrimaryWidget,
    host.SecondaryWidget,
    host.TextureWidget,
    host.WidthWidget,
    host.BorderWidget,
  }

  host:SetScript("OnSizeChanged", LayoutPRDControls)
  host:Hide()
  return host
end

local function LayoutQualitySection(host, label, widgets, topOffset)
  label:ClearAllPoints()
  label:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -topOffset)
  label:SetPoint("RIGHT", host, "RIGHT", -12, 0)

  local widgetOffset = topOffset + 22
  local rowCount = math_floor((#widgets + 2) / 3)
  LayoutInstallerWidgetGrid(host, widgets, 3, widgetOffset, 68)

  return widgetOffset + rowCount * 68 + 8
end

LayoutQualityControls = function(host)
  local topOffset = 16
  topOffset = LayoutQualitySection(host, host.AutomationSectionLabel, host.AutomationWidgets, topOffset)
  topOffset = LayoutQualitySection(host, host.InterfaceSectionLabel, host.InterfaceWidgets, topOffset)
  topOffset = LayoutQualitySection(host, host.WarningSectionLabel, host.WarningWidgets, topOffset)
  local requiredHeight = topOffset + 4
  if host:GetHeight() ~= requiredHeight then
    host:SetHeight(requiredHeight)
  end
end

RefreshQualityControls = function(host)
  local Quality = ns.Modules.Quality
  local petWarningsAvailable = Quality:IsPetWarningAvailable()

  host.FasterLootingWidget:SetValue(Quality:GetQuickSetupValue("fasterLooting"))
  host.FasterMovieSkipWidget:SetValue(Quality:GetQuickSetupValue("fasterMovieSkip"))
  host.AutoRepairWidget:SetValue(Quality:GetQuickSetupValue("autoRepair"))
  host.AutoSellJunkWidget:SetValue(Quality:GetQuickSetupValue("autoSellJunk"))
  host.AutoKeystoneWidget:SetValue(Quality:GetQuickSetupValue("autoKeystone"))
  host.AutoInvitesWidget:SetValue(Quality:GetQuickSetupValue("autoAcceptInvites"))
  host.MaxCameraZoomWidget:SetValue(Quality:GetQuickSetupValue("maxCameraZoom"))
  host.HideTalkingHeadWidget:SetValue(Quality:GetQuickSetupValue("hideTalkingHead"))

  host.PetWarningsWidget:SetLabel(
    petWarningsAvailable
      and "Pet warnings"
      or "Pet warnings - not used by this class/spec"
  )
  host.PetWarningsWidget:SetValue(
    petWarningsAvailable
      and Quality:GetQuickSetupValue("petWarningsEnabled")
  )
  host.PetWarningsWidget:SetDisabled(not petWarningsAvailable)

  for i = 1, #host.ControlWidgets do
    host.ControlWidgets[i].frame:Show()
  end

  LayoutQualityControls(host)
end

local function BuildQualityControls(frame, colors)
  local host = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  host:SetHeight(356)

  Theme.SetSquareBackdrop(host, {
    bg = colors.background,
    border = colors.border,
  }, math_max(Theme.GetEdgeSize(), 2))

  local function AddToggle(label, key, statusOn, statusOff)
    return CreateInstallerWidget(host, "CheckBox", label, function(_, _, value)
      local Quality = ns.Modules.Quality
      Quality:SetQuickSetupValue(key, value)
      RefreshQualityControls(host)
      SetStatus(value and statusOn or statusOff)
    end)
  end

  host.FasterLootingWidget = AddToggle(
    "Faster looting",
    "fasterLooting",
    "Faster looting enabled.",
    "Faster looting disabled."
  )

  host.FasterMovieSkipWidget = AddToggle(
    "Skip movies faster",
    "fasterMovieSkip",
    "Faster movie skip enabled.",
    "Faster movie skip disabled."
  )

  host.AutoRepairWidget = AddToggle(
    "Auto repair at vendors",
    "autoRepair",
    "Auto repair enabled.",
    "Auto repair disabled."
  )

  host.AutoSellJunkWidget = AddToggle(
    "Auto sell junk",
    "autoSellJunk",
    "Auto sell junk enabled.",
    "Auto sell junk disabled."
  )

  host.AutoKeystoneWidget = AddToggle(
    "Auto insert keystone",
    "autoKeystone",
    "Auto keystone insertion enabled.",
    "Auto keystone insertion disabled."
  )

  host.AutoInvitesWidget = AddToggle(
    "Auto accept allowed invites",
    "autoAcceptInvites",
    "Invites from allowed sources will be accepted automatically.",
    "Automatic invite acceptance disabled."
  )

  host.MaxCameraZoomWidget = AddToggle(
    "Maximum camera zoom",
    "maxCameraZoom",
    "Maximum camera zoom enabled.",
    "Maximum camera zoom disabled."
  )

  host.HideTalkingHeadWidget = AddToggle(
    "Hide Talking Head",
    "hideTalkingHead",
    "Talking Head hidden.",
    "Talking Head shown."
  )

  host.PetWarningsWidget = AddToggle(
    "Pet warnings",
    "petWarningsEnabled",
    "Pet warnings enabled.",
    "Pet warnings disabled."
  )

  local function CreateSectionLabel(text)
    local label = host:CreateFontString(nil, "OVERLAY")
    label:SetJustifyH("LEFT")
    ApplyWizardFont(label, "body", 12)
    label:SetText(text)
    return label
  end

  host.AutomationSectionLabel = CreateSectionLabel("Automation")
  host.InterfaceSectionLabel = CreateSectionLabel("Interface")
  host.WarningSectionLabel = CreateSectionLabel("Warnings")

  host.AutomationWidgets = {
    host.FasterLootingWidget,
    host.AutoRepairWidget,
    host.AutoSellJunkWidget,
    host.AutoKeystoneWidget,
    host.AutoInvitesWidget,
  }
  host.InterfaceWidgets = {
    host.FasterMovieSkipWidget,
    host.MaxCameraZoomWidget,
    host.HideTalkingHeadWidget,
  }
  host.WarningWidgets = {
    host.PetWarningsWidget,
  }
  host.ControlWidgets = {
    host.FasterLootingWidget,
    host.AutoRepairWidget,
    host.AutoSellJunkWidget,
    host.AutoKeystoneWidget,
    host.AutoInvitesWidget,
    host.FasterMovieSkipWidget,
    host.MaxCameraZoomWidget,
    host.HideTalkingHeadWidget,
    host.PetWarningsWidget,
  }

  host:SetScript("OnSizeChanged", LayoutQualityControls)
  host:SetScript("OnShow", RefreshQualityControls)
  host:Hide()
  return host
end

local function LayoutActionButtons(frame, count)
  if count <= 0 then
    return
  end

  local availableWidth = math_max(1, frame:GetWidth() - 48)
  local width = (availableWidth - ((count - 1) * ACTION_BUTTON_SPACING)) / count

  if count >= 4 then
    width = math_max(108, math_min(180, width))
  else
    width = math_max(180, math_min(230, width))
  end

  local totalWidth = count * width + (count - 1) * ACTION_BUTTON_SPACING
  local firstOffset = -totalWidth / 2

  for i = 1, count do
    local button = frame.ActionButtons[i]
    button:ClearAllPoints()
    button:SetSize(width, 32)
    button:SetPoint("BOTTOMLEFT", frame, "BOTTOM", firstOffset + (i - 1) * (width + ACTION_BUTTON_SPACING), 92)
  end
end

local function HideActionButtons(frame)
  for i = 1, #frame.ActionButtons do
    local button = frame.ActionButtons[i]
    button:SetScript("OnClick", nil)
    button:Hide()
  end
end

RefreshWizardPage = function()
  local frame = wizardFrame
  local flow = activeFlow
  local page = flow.pages[currentPage]
  local pageCount = #flow.pages

  frame.Title:SetText(flow.title)
  frame.PageTitle:SetText(page.title)
  frame.Body:SetText(page.body)
  frame.Note:SetText(page.note or "")
  frame.StatusMessage:SetText("")
  frame.PageNumber:SetText(string.format("%d / %d", currentPage, pageCount))
  frame.ProgressFill:SetWidth(PROGRESS_INNER_WIDTH * currentPage / pageCount)

  frame.Previous:SetEnabled(currentPage > 1)

  if page.profileChoice == true then
    frame.Next:SetText("Continue")
  elseif currentPage == pageCount then
    frame.Next:SetText("Finish and reload")
  else
    frame.Next:SetText(currentPage == pageCount and "Finish" or "Continue")
  end

  frame.Skip:SetText(flow.skipText)

  local showProfileChoice = page.profileChoice == true
  local showAccessibility = page.accessibility == true
  local showUnitFrames = page.unitFrames == true
  local showPRD = page.prd == true
  local showQuality = page.quality == true
  local showPreview = page.preview == "customBars"

  frame.ProfileChoiceHost:SetShown(showProfileChoice)
  frame.AccessibilityHost:SetShown(showAccessibility)
  frame.UnitFrameHost:SetShown(showUnitFrames)
  frame.PRDHost:SetShown(showPRD)
  frame.QualityHost:SetShown(showQuality)
  frame.PreviewHost:SetShown(showPreview)

  if showPreview then
    RefreshCooldownManagerButton(frame.PreviewHost.CooldownManagerButton)
    frame.PreviewHost.ConsumableTrackerWidget:SetValue(
      ns.Modules.CooldownManager:GetConsumableTrackerEnabled()
    )
  end

  local contentHosts = {
    frame.ProfileChoiceHost,
    frame.AccessibilityHost,
    frame.UnitFrameHost,
    frame.PRDHost,
    frame.QualityHost,
    frame.PreviewHost,
  }

  for i = 1, #contentHosts do
    local host = contentHosts[i]
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", frame.Body, "BOTTOMLEFT", 0, -18)
    host:SetPoint("TOPRIGHT", frame.Body, "BOTTOMRIGHT", 0, -18)
  end

  frame.Note:ClearAllPoints()

  if showProfileChoice then
    RefreshProfileChoiceControls(frame.ProfileChoiceHost)
    frame.Note:SetPoint("TOPLEFT", frame.ProfileChoiceHost, "BOTTOMLEFT", 0, -10)
    frame.Note:SetPoint("TOPRIGHT", frame.ProfileChoiceHost, "BOTTOMRIGHT", 0, -10)
  elseif showAccessibility then
    RefreshAccessibilityControls(frame.AccessibilityHost)
    frame.Note:SetPoint("TOPLEFT", frame.AccessibilityHost, "BOTTOMLEFT", 0, -10)
    frame.Note:SetPoint("TOPRIGHT", frame.AccessibilityHost, "BOTTOMRIGHT", 0, -10)
  elseif showUnitFrames then
    RefreshUnitFrameControls(frame.UnitFrameHost)
    frame.Note:SetPoint("TOPLEFT", frame.UnitFrameHost, "BOTTOMLEFT", 0, -10)
    frame.Note:SetPoint("TOPRIGHT", frame.UnitFrameHost, "BOTTOMRIGHT", 0, -10)
  elseif showPRD then
    RefreshPRDControls(frame.PRDHost)
    frame.Note:SetPoint("TOPLEFT", frame.PRDHost, "BOTTOMLEFT", 0, -10)
    frame.Note:SetPoint("TOPRIGHT", frame.PRDHost, "BOTTOMRIGHT", 0, -10)
  elseif showQuality then
    RefreshQualityControls(frame.QualityHost)
    frame.Note:SetPoint("TOPLEFT", frame.QualityHost, "BOTTOMLEFT", 0, -10)
    frame.Note:SetPoint("TOPRIGHT", frame.QualityHost, "BOTTOMRIGHT", 0, -10)
  elseif showPreview then
    frame.Note:SetPoint("TOPLEFT", frame.PreviewHost, "BOTTOMLEFT", 0, -8)
    frame.Note:SetPoint("TOPRIGHT", frame.PreviewHost, "BOTTOMRIGHT", 0, -8)
  else
    frame.Note:SetPoint("TOPLEFT", frame.Body, "BOTTOMLEFT", 0, -22)
    frame.Note:SetPoint("TOPRIGHT", frame.Body, "BOTTOMRIGHT", 0, -22)
  end

  HideActionButtons(frame)

  local actions = page.actions
  if actions then
    local actionCount = math.min(#actions, #frame.ActionButtons)
    LayoutActionButtons(frame, actionCount)

    for i = 1, actionCount do
      local action = actions[i]
      local button = frame.ActionButtons[i]
      button:SetText(action.text)
      button:SetScript("OnClick", action.func)
      button:Show()
    end
  end
end

local function FinishActiveFlow()
  MarkInstallComplete()
  ReloadUI()
end

local function SkipActiveFlow()
  MarkInstallComplete()
  wizardFrame:Hide()
end

local function BuildWizardFrame()
  local frame = CreateFrame("Frame", "PleebUIOnboardingFrame", UIParent, "BackdropTemplate")
  frame:SetSize(WIZARD_WIDTH, WIZARD_HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetResizeBounds(WIZARD_MIN_WIDTH, WIZARD_MIN_HEIGHT)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  Theme.WidgetSkins.Frame(frame)

  local accent = frame:CreateTexture(nil, "ARTWORK")
  accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  accent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  accent:SetHeight(3)
  local colors = Theme.GetColors()
  local accentColor = colors.accent
  accent:SetColorTexture(accentColor[1], accentColor[2], accentColor[3], 1)
  frame.Accent = accent

  local logo = frame:CreateTexture(nil, "ARTWORK")
  logo:SetSize(42, 42)
  logo:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -14)
  logo:SetTexture("Interface\\AddOns\\PleebUI\\Media\\logo.tga")

  local title = frame:CreateFontString(nil, "OVERLAY")
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -2)
  title:SetPoint("RIGHT", frame, "RIGHT", -52, 0)
  title:SetJustifyH("LEFT")
  ApplyWizardFont(title, "title", 20)
  frame.Title = title

  local pageTitle = frame:CreateFontString(nil, "OVERLAY")
  pageTitle:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -22)
  pageTitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -78)
  pageTitle:SetJustifyH("LEFT")
  ApplyWizardFont(pageTitle, "title", 18)
  frame.PageTitle = pageTitle

  local body = frame:CreateFontString(nil, "OVERLAY")
  body:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -16)
  body:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -118)
  body:SetJustifyH("LEFT")
  body:SetJustifyV("TOP")
  body:SetWordWrap(true)
  body:SetSpacing(6)
  ApplyWizardFont(body, "body", 13)
  frame.Body = body

  frame.ProfileChoiceHost = BuildProfileChoiceControls(frame, colors)
  frame.AccessibilityHost = BuildAccessibilityControls(frame, colors)
  frame.UnitFrameHost = BuildUnitFrameControls(frame, colors)
  frame.PRDHost = BuildPRDControls(frame, colors)
  frame.QualityHost = BuildQualityControls(frame, colors)
  frame.PreviewHost = BuildCustomBarsPreview(frame, colors)

  local note = frame:CreateFontString(nil, "OVERLAY")
  note:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -250)
  note:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -250)
  note:SetJustifyH("LEFT")
  note:SetJustifyV("TOP")
  note:SetWordWrap(true)
  ApplyWizardFont(note, "tiny", 11)
  frame.Note = note

  frame.ActionButtons = {}

  for i = 1, 5 do
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    SkinWizardButton(button)
    frame.ActionButtons[i] = button
  end

  local statusMessage = frame:CreateFontString(nil, "OVERLAY")
  statusMessage:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 68)
  statusMessage:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 68)
  statusMessage:SetJustifyH("CENTER")
  ApplyWizardFont(statusMessage, "tiny", 10)
  frame.StatusMessage = statusMessage

  local progress = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  progress:SetSize(PROGRESS_WIDTH, 10)
  progress:SetPoint("BOTTOM", frame, "BOTTOM", 0, 49)
  Theme.SetSquareBackdrop(progress, {
    bg = colors.control,
    border = colors.border,
  }, math.max(Theme.GetEdgeSize(), 2))

  frame.Progress = progress

  local progressFill = progress:CreateTexture(nil, "ARTWORK")
  progressFill:SetPoint("TOPLEFT", progress, "TOPLEFT", 2, -2)
  progressFill:SetPoint("BOTTOMLEFT", progress, "BOTTOMLEFT", 2, 2)
  progressFill:SetColorTexture(accentColor[1], accentColor[2], accentColor[3], 0.95)
  frame.ProgressFill = progressFill

  local pageNumber = frame:CreateFontString(nil, "OVERLAY")
  pageNumber:SetPoint("CENTER", progress, "CENTER", 0, 0)
  Theme.ApplyFont(pageNumber, "tiny", 9, "OUTLINE")
  frame.PageNumber = pageNumber

  local previous = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  previous:SetSize(140, 32)
  previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 14)
  previous:SetText("Previous")
  previous:SetScript("OnClick", function()
    currentPage = currentPage - 1
    RefreshWizardPage()
  end)
  SkinWizardButton(previous)
  frame.Previous = previous

  local skip = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  skip:SetSize(160, 32)
  skip:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
  skip:SetScript("OnClick", SkipActiveFlow)
  SkinWizardButton(skip)
  frame.Skip = skip

  local nextButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  nextButton:SetSize(180, 32)
  nextButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 14)
  nextButton:SetScript("OnClick", function()
    if currentPage == #activeFlow.pages then
      FinishActiveFlow()
    else
      currentPage = currentPage + 1
      RefreshWizardPage()
    end
  end)
  SkinWizardButton(nextButton)
  frame.Next = nextButton

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1)
  close:SetScript("OnClick", function()
    frame:Hide()
  end)
  Theme.WidgetSkins.CloseButton(close)

  local resizeGrip = CreateFrame("Button", nil, frame)
  resizeGrip:SetSize(18, 18)
  resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

  local resizeTexture = resizeGrip:CreateTexture(nil, "OVERLAY")
  resizeTexture:SetAllPoints(resizeGrip)
  resizeTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
  resizeTexture:SetVertexColor(accentColor[1], accentColor[2], accentColor[3], 0.35)
  frame.ResizeTexture = resizeTexture

  resizeGrip:SetScript("OnEnter", function()
    local color = Theme.GetColors().accent or { 0.20, 0.65, 1.00, 1 }
    resizeTexture:SetVertexColor(color[1], color[2], color[3], 0.75)
  end)
  resizeGrip:SetScript("OnLeave", function()
    local color = Theme.GetColors().accent or { 0.20, 0.65, 1.00, 1 }
    resizeTexture:SetVertexColor(color[1], color[2], color[3], 0.35)
  end)
  resizeGrip:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      frame:StartSizing("BOTTOMRIGHT")
    end
  end)
  resizeGrip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
  end)

  frame:SetScript("OnSizeChanged", function(self)
    LayoutProfileChoiceControls(self.ProfileChoiceHost)
    LayoutAccessibilityControls(self.AccessibilityHost)

    if self.UnitFrameHost.ControlWidgets then
      LayoutUnitFrameControls(self.UnitFrameHost)
    end

    if self.PRDHost.ControlWidgets then
      LayoutPRDControls(self.PRDHost)
    end

    LayoutQualityControls(self.QualityHost)

    local page = activeFlow and activeFlow.pages[currentPage]
    local actions = page and page.actions
    if actions then
      LayoutActionButtons(self, math_min(#actions, #self.ActionButtons))
    end
  end)

  table.insert(UISpecialFrames, frame:GetName())

  frame:Hide()

  wizardFrame = frame
  RefreshWizardTheme()
  return frame
end

local function ShowInstallFlow()
  local flow = INSTALL_FLOW

  activeFlow = flow
  currentPage = 1

  CaptureWizardScaleSnapshot()

  local optionsFrame = Addon._OptionsWindow
  if optionsFrame and optionsFrame:IsShown() then
    optionsFrame:Hide()
  end

  local frame = wizardFrame or BuildWizardFrame()
  frame:Show()
  RefreshWizardPage()
  RefreshWizardTheme()
  frame:Raise()
end

function Addon:IsInstallWizardPending()
  local db = GetInstallOnboardingDB()
  return db.installComplete ~= true
    or (tonumber(db.installVersion) or 0) < INSTALL_FLOW_VERSION
end

function Addon:ShowInstallWizard(force)
  if force or self:IsInstallWizardPending() then
    ShowInstallFlow()
  end
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")

  C_Timer.After(1, function()
    if Addon:IsInstallWizardPending() then
      Addon:ShowInstallWizard(false)
    end
  end)
end)
