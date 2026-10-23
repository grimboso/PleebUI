local _, ns = ...
local Addon, Theme = ns.Addon, ns.Theme
local AceGUI = LibStub("AceGUI-3.0")
local Content = {}
ns.InstallerContent = Content
local callbacks, host, group, previewHost, settingsHost, settingsPanel, practice
local selected = {}
local drafts = {}
local activeKey
local rebuilding
local pendingRebuild
local paletteChoice
local chooseSections = false
local moverHelp = false
local profileTools = false
local individualBars = false
local combatReadability = false
local chapterOrder = {
  { key = "frames", name = "Frames and auras" },
  { key = "combat", name = "Combat and trackers" },
  { key = "interface", name = "Everyday interface" },
  { key = "convenience", name = "Convenience" },
  { key = "arrange", name = "Arrange and finish" },
}
Content.Chapters = chapterOrder

local specGuides = {
  DEATHKNIGHT = {
    { "Blood", "Runes and Bone Shield", "Bone Shield is a tracked effect, not a power resource." },
    { "Frost", "Runes", "Explore rune recharge direction and ready-state indicators." },
    { "Unholy", "Runes", "Pet warnings are configured separately under Quality of Life." },
  },
  DEMONHUNTER = {
    { "Havoc", "Primary power", "A secondary resource is not required; trackers are optional." },
    { "Vengeance", "Soul Fragments", "Choose PRD, supported cooldown icon counts, or both." },
    { "Devourer", "Soul Fragments (tracked effect)", "Maximum and availability can depend on your current talents." },
  },
  DRUID = {
    { "Balance", "Alternate Mana; Cat Form Combo Points", "Combo Points depend on Cat Form and can appear outside Feral." },
    { "Feral", "Combo Points", "The primary power changes with your form." },
    { "Guardian", "Ironfur; Cat Form Combo Points", "Ironfur is a Bear Form effect. Cat Combo Points are contextual." },
    { "Restoration", "Primary power; contextual Combo Points", "Cat Form can expose Combo Points; group indicators have separate settings." },
  },
  EVOKER = {
    { "Devastation", "Essence", "Choose readable segments and recharge cues." },
    { "Preservation", "Essence", "Also explore healing indicators and empower castbars." },
    { "Augmentation", "Essence", "Effect-duration trackers are available separately." },
  },
  HUNTER = {
    { "Beast Mastery", "Primary power", "Pet warnings and pet bar settings are separate." },
    { "Marksmanship", "Primary power", "Pet controls are only useful when a pet is available." },
    { "Survival", "Tip of the Spear", "This effect tracks stacks rather than the primary resource." },
  },
  MAGE = {
    { "Arcane", "Arcane Charges; Arcane Salvo", "Charges are power. Arcane Salvo is a tracked effect." },
    { "Fire", "Primary power", "Add an optional tracker only for a spell you can use." },
    { "Frost", "Icicles; Freezing; Fingers of Frost", "Freezing is target-related; the others represent different effects." },
  },
  MONK = {
    { "Brewmaster", "Stagger", "Stagger severity and fill thresholds have dedicated options." },
    { "Mistweaver", "Sheilun's Gift", "The supported count display is separate from ordinary power." },
    { "Windwalker", "Chi", "Configure segments, text and visibility for a true resource." },
  },
  PALADIN = {
    { "Holy", "Holy Power", "Group indicators can be customized in Unit Frames." },
    { "Protection", "Holy Power; Shining Light", "Shining Light is a tracked effect, not Holy Power." },
    { "Retribution", "Holy Power", "Choose the supported segments, text and resource cues." },
  },
  PRIEST = {
    { "Discipline", "Primary power", "Healing indicators and optional effect trackers have separate settings." },
    { "Holy", "Lightweaver", "This tracked effect can depend on your current talents." },
    { "Shadow", "Primary power; alternate Mana", "Alternate Mana is not a new class resource." },
  },
  ROGUE = {
    { "Assassination", "Combo Points", "Charged points and ordinary segment fill are separate." },
    { "Outlaw", "Combo Points", "An optional ability tracker is independent of Combo Points." },
    { "Subtlety", "Combo Points", "Charged-point coloring has its own configuration." },
  },
  SHAMAN = {
    { "Elemental", "Primary power; alternate Mana", "Alternate Mana and primary power are different displays." },
    { "Enhancement", "Maelstrom Weapon; Hailstorm; Overflowing Maelstrom", "These are tracked stacks/effects, not new basic power types." },
    { "Restoration", "Primary power", "Group indicators and effect-duration trackers are optional." },
  },
  WARLOCK = {
    { "Affliction", "Soul Shards", "Choose segment visibility and count text." },
    { "Demonology", "Soul Shards", "Pet warnings have a separate control." },
    { "Destruction", "Soul Shards", "Partial-shard fill and darkening are available in detailed options." },
  },
  WARRIOR = {
    { "Arms", "Sweeping Strikes", "Other tracked effects are available without changing spec.", preferredResource = "SWEEPING_STRIKES" },
    { "Fury", "Optional Whirlwind stacks", "Check talent availability; an optional effect can start disabled.", preferredResource = "WHIRLWIND_STACKS" },
    { "Protection", "Optional Ignore Pain", "Percentage and tick presentation are separate from power.", preferredResource = "IGNORE_PAIN" },
  },
}
Content.SpecializationGuides = specGuides


local function Add(widget)
  widget:SetUserData("keyboardKey", activeKey .. "\001" .. tostring(#group.children + 1))
  group:AddChild(widget)
  ns.AceHooks.TakeOwnership(widget)
  return widget
end

local function Text(value)
  local widget = AceGUI:Create("PUI_Label")
  widget:SetText(value)
  widget:SetFullWidth(true)
  return Add(widget)
end

local function Heading(value)
  local widget = AceGUI:Create("PUI_Heading")
  widget:SetText(value)
  widget:SetFullWidth(true)
  return Add(widget)
end

local function PrimaryPowerIntroduction()
  local key = ns.Modules.PRD and ns.Modules.PRD:GetPrimaryResourceKey()
  local name = key and _G[key]
  if name then
    Text("Your primary power: " .. name .. ". Health and class resources are separate.")
  else
    Text("Your primary power is not available yet. Its name will appear when the game provides it.")
  end
end

local function Action(value, callback, disabled)
  local widget = AceGUI:Create("PUI_Button")
  widget:SetText(value)
  widget:SetFullWidth(true)
  widget:SetDisabled(disabled == true)
  widget:SetCallback("OnClick", function()
    if InCombatLockdown() then callbacks.status("Setup is paused during combat.") return end
    callback()
  end)
  return Add(widget)
end

local function Check(value, checked, callback, sample)
  local widget = AceGUI:Create("PUI_Checkbox")
  widget:SetLabel(value)
  widget:SetValue(checked == true)
  widget:SetFullWidth(true)
  widget:SetCallback("OnValueChanged", function(_, _, enabled)
    if InCombatLockdown() then return end
    callback(enabled == true)
    if not sample then ns.InstallerPreview.Refresh() end
  end)
  return Add(widget)
end

local function Dropdown(value, values, order, current, callback)
  local widget = AceGUI:Create("PUI_Dropdown")
  widget:SetLabel(value)
  widget:SetList(values, order)
  widget:SetValue(current)
  widget:SetFullWidth(true)
  widget:SetCallback("OnValueChanged", function(_, _, choice)
    if not InCombatLockdown() then callback(choice) end
  end)
  return Add(widget)
end

local function Slider(label, value, minimum, maximum, step, callback)
  local widget = AceGUI:Create("PUI_Slider")
  widget:SetLabel(label)
  widget:SetSliderValues(minimum, maximum, step)
  widget:SetValue(value)
  widget:SetFullWidth(true)
  widget:SetCallback("OnValueChanged", function(_, _, choice)
    if not InCombatLockdown() then callback(choice) end
  end)
  return Add(widget)
end

local function Panel(height)
  local widget = AceGUI:Create("SimpleGroup")
  widget:SetFullWidth(true)
  widget:SetAutoAdjustHeight(false)
  widget:SetHeight(height)
  widget:SetLayout("Fill")
  Add(widget)
  return widget.content, widget
end

local function Settings(path)
  Heading("Start with these settings")
  local parent
  parent, settingsPanel = Panel(1)
  settingsHost:SetParent(parent)
  settingsHost:ClearAllPoints()
  settingsHost:SetPoint("TOPLEFT", parent, "TOPLEFT")
  settingsHost:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
  settingsHost:Show()
  ns.InstallerSettings.Show(settingsHost, path)
  Action("Open full settings", function() callbacks.openOptions(path) end)
end

local function AnimationToggle()
  local status = Text("Example paused.")
  local play
  play = Check("Animate this example", false, function(value)
    local enabled = ns.InstallerPreview.SetPlaying(value)
    play:SetValue(enabled)
    status:SetText(enabled and "Example playing. Uncheck to pause." or "Example paused.")
  end, true)
  play:SetDisabled(not ns.OptionsMotion.IsEnabled())
  if not ns.OptionsMotion.IsEnabled() then Text("Motion is off in Accessibility.") end
end

local function Preview(kind, path)
  local height = kind == "unitframes" and (path[2] == "party" or path[2] == "raid") and 220
    or kind == "unitframes" and 150 or 335
  if kind == "unitframes" then Heading("Example · sample data") end
  local parent = Panel(height)
  previewHost:SetParent(parent)
  previewHost:ClearAllPoints()
  previewHost:SetAllPoints(parent)
  previewHost:Show()
  ns.InstallerPreview.Show(previewHost, kind, path)
  if ns.InstallerPreview.AnimatedKinds[kind] then AnimationToggle() else Text("Static example · sample data.") end
end

local function Rebuild()
  if pendingRebuild then return end
  pendingRebuild = true
  C_Timer.After(0, function()
    pendingRebuild = nil
    if host and host:IsVisible() and not InCombatLockdown() then
      callbacks.refreshTheme()
      Content.Show(host, activeKey)
    end
  end)
end

local function Accessibility()
  Text("Make setup comfortable. These choices also apply to PleebUI options.")
  Slider("Text size", Theme.GetOptionsFontSize(), Theme.OptionsFontSizeRange.min, Theme.OptionsFontSizeRange.max,
    Theme.OptionsFontSizeRange.step, function(value) Theme.SetOptionsFontSize(value); Rebuild() end)
  Slider("Window scale", Theme.GetOptionsUIScale(), Theme.OptionsUIScaleRange.min, Theme.OptionsUIScaleRange.max,
    Theme.OptionsUIScaleRange.step, function(value) Theme.SetOptionsUIScale(value); Rebuild() end)
  Check("Larger pointer targets", Addon:GetOptionsDB().largerPointerTargets, function(value)
    Addon:GetOptionsDB().largerPointerTargets = value
    Addon:RefreshOptionsTheme()
    Rebuild()
  end)
  Check("Keyboard navigation", ns.KeyboardNavigation.IsEnabled(), ns.KeyboardNavigation.SetEnabled)
  Check("Allow animation", ns.OptionsMotion.IsEnabled(), function(value)
    ns.OptionsMotion.SetEnabled(value)
    if not value then ns.InstallerPreview.SetPlaying(false) end
  end)
  local values = {}
  for _, key in ipairs(Theme.ColorPresetOrder) do values[key] = Theme.GetColorPresetLabel(key) end
  Dropdown("Color and contrast preset", values, Theme.ColorPresetOrder, paletteChoice, function(value)
    paletteChoice = value
    Rebuild()
  end)
  if paletteChoice then
    local colors = Theme.GetColorPresetPreviewColors(paletteChoice)
    local sample = Text("Aa · " .. Theme.GetColorPresetDefinition(paletteChoice).description)
    sample:SetHeight(Theme.GetOptionsFontHeight("body") * 2 + 16)
    Theme.SetSquareBackdrop(sample.frame, { bg = colors.background, border = colors.border }, Theme.GetEdgeSize())
    sample.label:SetTextColor(unpack(colors.text))
    Action("Apply selected colors", function() Theme.ApplyColorPreset(paletteChoice); Rebuild() end)
  end
  Text("• Mouse: click a control; scroll for more.\n• Keyboard: Tab moves, Enter selects, Ctrl+Tab changes areas.")
  Action("Open keyboard help", callbacks.openHelp)
end

local function Choices(label, options, default, callback, cards)
  local values, order = {}, {}
  for index, option in ipairs(options) do values[index] = option[1]; order[index] = index end
  local index = selected[activeKey] or default or 1
  index = math.min(index, #options)
  selected[activeKey] = index
  if cards then
    Heading(label)
    for choice, option in ipairs(options) do
      local button = AceGUI:Create("PUI_Button")
      button:SetText(option[1])
      button:SetRelativeWidth(group.frame:GetWidth() >= Theme.GetOptionsFontHeight("button") * 30 and 0.48 or 1)
      button:SetHeight(math.max(Theme.GetOptionsPointerTargetSize(52), Theme.GetOptionsFontHeight("button") * 3 + 16))
      button:SetDisabled(choice == index)
      button:SetCallback("OnClick", function()
        if InCombatLockdown() then return end
        selected[activeKey] = choice
        Rebuild()
      end)
      Add(button)
    end
  else
    Dropdown(label, values, order, index, function(choice)
      selected[activeKey] = choice
      Rebuild()
    end)
  end
  callback(options[index])
end

local function Details(path, name)
  Text("Find this later: /pui > " .. name .. ". Close settings to return to setup.")
  Action("Open full settings", function() callbacks.openOptions(path) end)
end

local function Practice(kind)
  local parent, panel = Panel(1)
  practice = practice or ns.EditModeGuidePractice.Create(host)
  practice.frame:SetParent(parent)
  practice.frame:ClearAllPoints()
  practice.frame:SetPoint("TOPLEFT", parent, "TOPLEFT")
  practice:Show(kind, math.max(450, group.frame:GetWidth()), not moverHelp)
  panel:SetHeight(practice.frame:GetHeight())
end

local function TrackerPage(key)
  if not ns.Modules.CooldownManager then
    Preview("cooldowns", { "CooldownManager" })
    Settings({ "CooldownManager" })
    return
  end
  local kind = key == "trackerCharges" and "charge" or key == "trackerStacks" and "stack" or "cooldown"
  local draft = drafts[key]
  if not draft then
    draft = ns.PCMCustomTrackerInstaller:CreateDraft(kind)
    draft.presentation = "BAR"
    drafts[key] = draft
  end
  local introduction = kind == "charge" and "Charge trackers show available charges and recharge progress."
    or kind == "stack" and "Effect trackers show stacks or how long an effect lasts."
    or "Custom cooldowns give one spell its own button or bar."
  Text(introduction .. "\n• Try the example; nothing is created.\n• Add a tracker only if you need one.")
  if key == "trackerStacks" then
    Dropdown("Example", { stack = "Stacks", duration = "Effect duration" }, { "stack", "duration" }, draft.kind, function(value)
      draft.kind = value
      draft.spellID = nil
      Rebuild()
    end)
  end
  Dropdown("Display", { BUTTON = "Button", BAR = "Bar" }, { "BUTTON", "BAR" }, draft.presentation, function(value)
    draft.presentation = value
    Rebuild()
  end)
  if draft.presentation == "BAR" then
    Slider("Width", draft.width, 80, 600, 5, function(value) draft.width = value; ns.InstallerPreview.Refresh() end)
    Slider("Height", draft.height, 6, 50, 1, function(value) draft.height = value; ns.InstallerPreview.Refresh() end)
  else
    Slider("Icon size", draft.icon.size, 20, 96, 2, function(value) draft.icon.size = value; ns.InstallerPreview.Refresh() end)
  end
  local parent = Panel(180)
  previewHost:SetParent(parent)
  previewHost:ClearAllPoints()
  previewHost:SetAllPoints(parent)
  previewHost:Show()
  ns.InstallerPreview.ShowDraft(previewHost, draft)
  AnimationToggle()
  Text("Tip: the optional creator handles spell selection, sources, text, and visibility.")
  Action(ns.PCMCustomTrackerInstaller:HasDraft() and "Continue unfinished tracker (optional)" or "Create a tracker (optional)", function()
    if ns.PCMCustomTrackerInstaller:HasDraft() then callbacks.openTracker() else callbacks.openTracker(draft) end
  end)
  Details({ "CooldownManager", "customTrackers" }, "Cooldown Manager / Custom trackers")
end

local function Review()
  Heading("Saved profile: " .. Addon.db:GetCurrentProfile())
  local index = C_SpecializationInfo.GetSpecialization()
  local name
  if index then name = select(2, C_SpecializationInfo.GetSpecializationInfo(index)) end
  Text("Specialization: " .. (name or "Not selected") .. ". Settings are saved as you change them. Examples are separate.")
  local enabledModules = {}
  for _, choice in ipairs(Addon:GetChildAddonChoices()) do
    if choice.installed and choice.enabled then enabledModules[#enabledModules + 1] = choice.label end
  end
  Text("Modules selected for this profile: " .. (#enabledModules > 0 and table.concat(enabledModules, ", ") or "None") .. ".")
  Action("Change module selection", function() callbacks.navigate("modules") end)
  for _, entry in ipairs({
    { "Unit frames", ns.Modules.UnitFrames and ns.UnitFrames:GetQuickSetupValue("enabled"), "unitframes" },
    { "Party frames", ns.Modules.PartyFrames and ns.Modules.PartyFrames.db.profile.enabled ~= false, "group", 1 },
    { "Raid frames", ns.Modules.RaidFrames and ns.Modules.RaidFrames.db.profile.enabled ~= false, "group", 2 },
    { "Personal Resource Display", ns.Modules.PRD and ns.Modules.PRD:IsModuleEnabled(), "prd" },
    { "Cooldown Manager", ns.Modules.CooldownManager and ns.Modules.CooldownManager:IsModuleEnabledByUser(), "cooldowns" },
    { "Items and racials", ns.Modules.CooldownManager and ns.Modules.CooldownManager:GetConsumableTrackerEnabled(), "utility" },
    { "Damage meters", ns.Modules.DamageMeters and ns.Modules.DamageMeters.db.profile.enabled ~= false, "meters" },
  }) do
    Action(entry[1] .. ": " .. (entry[2] and "On" or "Off") .. " — Edit", function()
      if entry[4] then selected.group = entry[4] end
      callbacks.navigate(entry[3])
    end)
  end
  local count = 0
  if ns.Modules.CooldownManager then
    for _, entries in ipairs({ ns.Modules.CooldownManager:GetSpellBarsDB(), ns.Modules.CooldownManager:GetCooldownStackBarsDB(), ns.Modules.PCM_BB.GetStackBarsDB() }) do
      for _, config in pairs(entries) do if type(config) == "table" then count = count + 1 end end
    end
  end
  Text("Custom trackers: " .. count .. ". Optional; you can add or edit them later.")
  Text(Content.pendingReload and "Remaining: finish and reload to apply all choices." or "Your changes are saved. No reload is needed.")
  Action("Check my layout in Edit Mode", callbacks.openEditMode)
end

local function BuildPage(key)
  if key == "welcome" or key == "accessibility" then
    Accessibility()
  elseif key == "profiles" then
    Heading("Current profile: " .. Addon.db:GetCurrentProfile())
    Text("• Settings save to this profile as you change them.\n• Examples stay separate from your real layout.")
    Check("Use another profile (optional)", profileTools, function(value) profileTools = value; Rebuild() end, true)
    if profileTools then
      local values, order = Addon:GetInstallerExistingProfiles()
      Dropdown("Use an existing profile (reload)", values, order, nil, function(name)
        local ok, message = Addon:ActivateExistingProfile(name)
        if ok then Addon:ApplyChildAddonProfile() else callbacks.status(message) end
      end)
      Action("Create a separate setup profile", function()
        Addon:PUI_ConfirmAction({
          title = "Create setup profile", text = "Create a profile with PleebUI defaults and reload? Your current profile will be kept.",
          yesText = "Create and reload", onYes = function()
            if InCombatLockdown() then callbacks.status("Create a profile after combat ends.") return end
            local names, index = {}, 1
            for _, name in ipairs(Addon.db:GetProfiles({})) do names[name] = true end
            local name = "PleebUI Setup"
            while names[name] do index = index + 1; name = "PleebUI Setup " .. index end
            Addon.db:SetProfile(name)
            Addon:ApplyChildAddonProfile()
          end,
        })
      end)
    end
    Check("Choose which sections to visit", chooseSections, function(value) chooseSections = value; Rebuild() end, true)
    if chooseSections then
      for _, chapter in ipairs(Content.Chapters) do
        Check(chapter.name, Content.sections[chapter.key] ~= false, function(value)
          Content.sections[chapter.key] = value
          callbacks.changedRoute()
        end)
      end
      Text("Tip: skipping a section keeps its current settings.")
    end
  elseif key == "modules" then
    Heading("Choose modules for " .. Addon.db:GetCurrentProfile())
    Text("Uncheck modules you do not need or handle with another addon. Their saved settings are kept.")
    Text("These choices belong to this profile and take effect after a reload. Until then, setup pages show the modules currently loaded.")
    for _, choice in ipairs(Addon:GetChildAddonChoices()) do
      local addonName = choice.name
      local checkbox = Check(choice.label .. (choice.installed and "" or " (not installed)"), choice.enabled, function(value)
        Addon.db.profile.childAddons[addonName] = value
        Rebuild()
      end, true)
      checkbox:SetDisabled(not choice.installed)
    end
    Text("Apply now to configure newly enabled modules, or continue and apply all choices when you finish setup.")
    Action("Apply and reload", function() Addon:ApplyChildAddonProfile() end, not Addon:ChildAddonProfileNeedsReload())
  elseif key == "appearance" then
    Text("Choose a readable look.\n• Global font affects PleebUI text.\n• Game UI scale resizes the whole interface.")
    Settings({ "UITheme" })
    Heading("Text sample")
    local sample = Add(AceGUI:Create("PUI_Label"))
    sample:SetFullWidth(true)
    sample:SetText("Combat text sample: Player   73%   Power 62")
    ns.Theme.ApplyFont(sample.label, "body", 16)
    Text("Tip: Accessibility above has text size and contrast. Combat readability is optional.")
    Check("Combat readability (optional)", combatReadability, function(value) combatReadability = value; Rebuild() end, true)
    if combatReadability then
      Text("Enlarge combat text and aura icons. Undo is available until profile change or reload.")
      Action("Apply combat readability", function() Addon:ApplyCombatReadabilityPreset(); Rebuild() end)
      Action("Undo combat readability", function() Addon:UndoCombatReadabilityPreset(); Rebuild() end, not Addon:CanUndoCombatReadabilityPreset())
    end
  elseif key == "navigation" then
    Text("Find a feature now, or come back later.\n• Use the numbered pages, Back, and Continue.\n• Type /pui for full settings; close them to return here.")
    Text("Tip: settings save as you change them. Examples use sample data.")
    Action("Open full options (optional)", function() callbacks.openOptions({ "unitframes", "player" }) end)
  elseif key == "unitframes" then
    if not ns.Modules.UnitFrames then
      Preview("unitframes", { "unitframes" })
      Settings({ "unitframes" })
      return
    end
    Text("Unit frames show health and power.\n• Pick the frame you want to change.\n• Start with a readable size and health text.")
    Check("Enable unit frames", ns.UnitFrames:GetQuickSetupValue("enabled"), function(value) ns.UnitFrames:SetQuickSetupValue("enabled", value) end)
    Choices("Frame", {
      { "Player", { "unitframes", "player" } }, { "Target", { "unitframes", "target" } },
      { "Focus", { "unitframes", "focus" } }, { "Pet", { "unitframes", "player", "pet" } },
      { "Boss", { "unitframes", "boss" } },
    }, 1, function(choice) Preview("unitframes", choice[2]); Settings(choice[2]) end)
    Text("Tip: /pui > Unit Frames has castbars, portraits, and detailed styling.")
  elseif key == "group" then
    if not ns.Modules.UnitFrames then
      Preview("unitframes", { "unitframes" })
      Settings({ "unitframes" })
      return
    end
    Text("Follow your group at a glance.\n• Choose Party or Raid.\n• Give each frame enough size and space.")
    Choices("Group", { { "Party", { "unitframes", "party" } }, { "Raid", { "unitframes", "raid" } } }, 1, function(choice)
      Preview("unitframes", choice[2]); Settings(choice[2])
    end)
    Text("Tip: /pui > Unit Frames > Party or Raid has sorting and indicators.")
  elseif key == "auras" then
    if not ns.Modules.UnitFrames then
      Preview("unitframes", { "unitframes" })
      Settings({ "unitframes" })
      return
    end
    Text("Auras show effects on a unit.\n• Buffs help; debuffs harm.\n• Defensive icons show protection.")
    Choices("Aura example", {
      { "Player buffs", { "unitframes", "player", "auras", "customDisplays", "buffs" } },
      { "Player debuffs", { "unitframes", "player", "auras", "customDisplays", "debuffs" } },
      { "Party buffs", { "unitframes", "party", "auras", "customDisplays", "buffs" } },
      { "Party debuffs", { "unitframes", "party", "auras", "customDisplays", "debuffs" } },
      { "Party defensives", { "unitframes", "party", "auras", "customDisplays", "defensives" } },
      { "Raid buffs", { "unitframes", "raid", "auras", "customDisplays", "buffs" } },
      { "Raid debuffs", { "unitframes", "raid", "auras", "customDisplays", "debuffs" } },
      { "Raid defensives", { "unitframes", "raid", "auras", "customDisplays", "defensives" } },
    }, 1, function(choice)
      Text("Sample auras stay visible when a display is off. The controls below change your real UI.")
      Preview("unitframes", choice[2]); Settings(choice[2])
    end)
    Text("Tip: /pui > Unit Frames > Auras has spell lists, filters, and dispel highlighting.")
  elseif key == "bars" then
    Text("Action bars hold spells and items.\n• Start with shared button size and spacing.\n• Individual bar overrides are optional.")
    local choices = { { "Shared settings", { "ACTIONBARS", "general" } } }
    for index = 1, 12 do choices[#choices + 1] = { "Bar " .. index, { "ACTIONBARS", tostring(index) } } end
    choices[#choices + 1] = { "Pet bar", { "ACTIONBARS", "special", "pet" } }
    choices[#choices + 1] = { "Stance bar", { "ACTIONBARS", "special", "stance" } }
    Check("Customize an individual bar (optional)", individualBars, function(value) individualBars = value; Rebuild() end, true)
    if individualBars then
      Choices("Action bar", choices, 1, function(choice) Preview("actionbars", choice[2]); Settings(choice[2]) end)
    else
      Preview("actionbars", { "ACTIONBARS", "general" })
      Settings({ "ACTIONBARS", "general" })
    end
    Text("Tip: /pui > Action bars has visibility and styling. Keybind mode assigns keys to hovered buttons.")
    Action("Open keybind mode", callbacks.openKeybinds)
  elseif key == "prd" then
    Text("Keep health and power near your character.\n• Choose which bars to show.\n• Make their height and text easy to read.")
    PrimaryPowerIntroduction()
    if not ns.Modules.PRD then
      Preview("prd", { "PRD" })
      Settings({ "PRD" })
      return
    end
    Check("Enable Personal Resource Display", ns.Modules.PRD:IsModuleEnabled(), function(value) ns.Modules.PRD:SetModuleEnabled(value) end)
    Preview("prd")
    Choices("Configure", { { "Health", { "PRD", "health" } }, { "Primary power and alternate Mana", { "PRD", "primary" } } }, 1, function(choice) Settings(choice[2]) end)
    Text("Tip: /pui > Personal Resource Display has stack order and colors. Move bars on Arrange UI later.")
  elseif key == "spec" then
    if not ns.Modules.PRD then
      Preview("prd", { "PRD" })
      Settings({ "PRD" })
      return
    end
    local className, class = UnitClass("player")
    local index = C_SpecializationInfo.GetSpecialization()
    if not index then Text("Choose a specialization in the game to see its resource settings.") return end
    local id, name = C_SpecializationInfo.GetSpecializationInfo(index)
    local guide = Content.SpecializationGuides[class][index]
    Heading(className .. " — " .. name)
    PrimaryPowerIntroduction()
    if guide then Text(guide[2] .. ". " .. guide[3]) end
    local choices = {}
    local default = 1
    for _, resource in ipairs(ns.PRDSecondary:GetResourceOptionsForClass(class, id)) do
      choices[#choices + 1] = { resource.name .. (resource.category == "TRACKED_EFFECT" and " — Tracked effect" or " — Resource"), { "PRD", "resources", resource.key } }
      if guide and guide.preferredResource == resource.key then default = #choices end
    end
    Text("Tip: effects may need a talent or form. The preview uses sample values.")
    Preview("prd")
    if #choices > 0 then Choices("Resource or effect", choices, default, function(choice)
      if class == "DRUID" and choice[2][3] == "COMBO_POINTS" then
        Text("Combo Points appear in Cat Form in any Druid specialization; settings are kept when you leave the form.")
      elseif class == "DRUID" and choice[2][3] == "IRONFUR" then
        Text("Ironfur is a Bear Form effect. Its bar can show duration or stacks; this is only a sample.")
      end
      Settings(choice[2])
    end)
    else Text("This specialization has no dedicated secondary tracker. Configure its primary power or choose an optional custom tracker.") end
  elseif key == "cooldowns" then
    if not ns.Modules.CooldownManager then
      Preview("cooldowns", { "CooldownManager" })
      Settings({ "CooldownManager" })
      return
    end
    Text("See when spells are ready and effects expire.\n• Pick one group to style.\n• Choose tracked spells separately.")
    Check("Enable Cooldown Manager", ns.Modules.CooldownManager:IsModuleEnabledByUser(), function(value) ns.Modules.CooldownManager:SetModuleEnabled(value) end)
    local choices = {}
    local groups = ns.PCMGroupManager:GetGroups()
    for _, id in ipairs(groups.order) do
      local entry = groups.byID[id]
      if entry then choices[#choices + 1] = { entry.name, { "CooldownManager", "groups", id } } end
    end
    if #choices > 0 then Choices("Group", choices, 1, function(choice) Preview("cooldowns", choice[2]); Settings(choice[2]) end) end
    Text("Tip: Choose tracked spells opens Blizzard settings; close them to return. Detailed styling is in /pui > Cooldown Manager.")
    Action("Choose tracked spells", callbacks.openTrackedSpells)
  elseif key == "trackerCooldown" or key == "trackerStacks" or key == "trackerCharges" then
    TrackerPage(key)
  elseif key == "utility" then
    Text("Keep useful items and group tools nearby.\n• Choose items or group tools.\n• Battle resurrection and bloodlust can be enabled separately.")
    Choices("Configure", {
      { "Items and racials", { "CooldownManager", "consumables" }, "cooldowns" },
      { "Battle resurrection, bloodlust, and group tools", { "Quality", "groupTab" }, "quality" },
    }, 1, function(choice) Preview(choice[3], choice[2]); Settings(choice[2]) end)
  elseif key == "meters" then
    Text("Meters summarize combat.\n• Current follows the current session.\n• Overall combines session data; choose a fight on the live meter.")
    Preview("meters")
    Settings({ "DamageMeters", "general" })
    if not ns.Modules.DamageMeters then return end
    local db = ns.Modules.DamageMeters.db.profile
    if db.windowCount > 0 then
      local window = ns.DamageMeterConfig.GetWindowDB(1)
      Slider("Window width", window.width, 220, 700, 5, function(value) ns.Modules.DamageMeters:ResizeWindow(1, value, window.height); ns.InstallerPreview.Refresh() end)
      Slider("Window height", window.height, 90, 600, 5, function(value) ns.Modules.DamageMeters:ResizeWindow(1, window.width, value); ns.InstallerPreview.Refresh() end)
    end
    Text("Tip: select sessions on the live meter. /pui > Damage Meters has history and detailed styling.")
  elseif key == "everyday" then
    Text("Choose a feature to try.\n• Start with visibility and size.\n• Window skins may need a reload.")
    Choices("Feature", {
      { "Chat", { "Chat" }, "chat" }, { "Minimap", { "Minimap" }, "minimap" },
      { "Player buffs", { "PLAYER_BUFFS" }, "buffs" }, { "Bags", { "BlizzardWindows" }, "bags" },
      { "Window skins", { "BlizzardWindows" }, "skins" }, { "Skyriding", { "Dragonriding" }, "skyriding" },
    }, 1, function(choice)
      Preview("everyday", { choice[3] }); Settings(choice[2])
      if choice[3] == "bags" or choice[3] == "skins" then
        Text("Bags use the Blizzard window-skin settings. Apply skin changes with a reload.")
      end
    end, true)
  elseif key == "convenience" then
    Text("Choose the helpers you want.\n• Automation changes game interactions.\n• Visual reminders are separate and optional.")
    Choices("Feature", {
      { "Loot and repair", { "Quality", "automationTab" } },
      { "Cursor ring and crosshair", { "Quality", "cursorTab" }, "quality" },
      { "Combat and pet warnings", { "Quality", "combatTab" }, "quality" },
      { "Movement reminders", { "MovementWarning" }, "movement" },
    }, 1, function(choice)
      if choice[3] then Preview(choice[3], choice[2]) end
      Settings(choice[2])
    end, true)
  elseif key == "arrange" then
    Text("Try moving one sample frame. Your real layout stays unchanged.\n• Mouse: drag a sample frame.\n• Keyboard: F6, then Tab to select a frame and arrows to move it.")
    Practice("movers")
    Check("More practice (optional)", moverHelp, function(value) moverHelp = value; Rebuild() end, true)
    if moverHelp then Text("Ctrl selects more frames. Ctrl+Z undoes; Ctrl+Y redoes. Keys 1–9 change the movement step. F6 returns to controls.") end
    Action("Open real Edit Mode", callbacks.openEditMode)
  elseif key == "review" then
    Review()
  elseif key == "ready" then
    Heading("Your setup is ready")
    Text("Profile: " .. Addon.db:GetCurrentProfile())
    Text(Content.pendingReload and "Choose Finish and reload below to apply the remaining changes." or "Choose Finish setup below to start playing.")
    Text("• /pui — change settings\n• /pe — move frames\n• /pui install — reopen setup")
    Text("Check later: /pui > Cooldown Manager > Custom trackers. Add them only when you need them.")
  end
end

function Content.Create(parent, handlers)
  callbacks = handlers
  host = CreateFrame("Frame", nil, parent)
  group = AceGUI:Create("SimpleGroup")
  group:SetLayout("Flow")
  group.frame:SetParent(host)
  group.frame:SetFrameStrata(host:GetFrameStrata())
  group.frame:SetFrameLevel(host:GetFrameLevel() + 1)
  group.frame:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -8)
  ns.AceHooks.TakeOwnership(group)
  function group:LayoutFinished(_, height)
    self:SetHeight(height)
    host:SetHeight(height + 16)
    callbacks.resize(height + 16)
  end
  settingsHost = ns.InstallerSettings.Create(host, 0, function(height)
    if settingsPanel and settingsPanel.frame:GetHeight() ~= height then
      settingsPanel:SetHeight(height)
      if not rebuilding then group:DoLayout() end
    end
  end)
  host.Settings = settingsHost
  settingsHost:Hide()
  previewHost = CreateFrame("Frame", nil, host)
  previewHost:Hide()
  host:SetScript("OnSizeChanged", function(_, width)
    if width > 0 then
      local contentWidth = math.max(450, width - 16)
      if group.frame:GetWidth() ~= contentWidth then group:SetWidth(contentWidth) end
    end
  end)
  ns.InstallerPreview.SetOpenOptions(callbacks.openOptions)
  return host
end

function Content.Suspend()
  ns.InstallerSettings.Hide(settingsHost)
  if practice then practice:StopDrag(true); practice.frame:Hide() end
  group.frame:Hide()
end

function Content.Hide()
  settingsPanel = nil
  ns.InstallerPreview.Hide()
  ns.InstallerSettings.Hide(settingsHost)
  settingsHost:Hide()
  settingsHost:SetParent(host)
  previewHost:Hide()
  previewHost:SetParent(host)
  if practice then practice.frame:Hide(); practice.frame:SetParent(host) end
  group:ReleaseChildren()
  group.frame:Hide()
end

function Content.Show(_, key)
  if rebuilding then return end
  rebuilding = true
  group:PauseLayout()
  Content.Hide()
  activeKey = key
  if InCombatLockdown() then group:ResumeLayout(); rebuilding = nil return end
  group.frame:SetFrameStrata(host:GetFrameStrata())
  group.frame:SetFrameLevel(host:GetFrameLevel() + 1)
  group:SetWidth(math.max(450, host:GetWidth() - 16))
  BuildPage(key)
  group:ResumeLayout()
  group.frame:Show()
  group:DoLayout()
  ns.InstallerPreview.Refresh()
  rebuilding = nil
end

function Content.Relayout()
  if not host or not group or rebuilding then return end
  group:SetWidth(math.max(450, host:GetWidth() - 16))
  group:DoLayout()
  ns.InstallerPreview.Refresh()
end

function Content.Invalidate()
  selected.spec = nil
end

function Content.HandleKey(_, key, keyboardInput)
  return practice and practice.frame:IsVisible() and practice:HandleKey(key, keyboardInput) or false
end
