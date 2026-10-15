local _, ns = ...
local Addon, Theme = ns.Addon, ns.Theme
local AceGUI = LibStub("AceGUI-3.0")
local Content = {}
ns.InstallerContent = Content
local callbacks, host, group, previewHost, settingsHost, practice
local selected = {}
local drafts = {}
local activeKey
local rebuilding
local pendingRebuild
local function Onboarding() return Addon.db.profile.pui.onboarding end
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
    { "Restoration", "Primary power; contextual Combo Points", "Cat Form can expose Combo Points; group indicators have separate settings.", healer = true },
  },
  EVOKER = {
    { "Devastation", "Essence", "Recharge and ready effects use the existing resource renderer." },
    { "Preservation", "Essence", "Also explore healing indicators and empower castbars.", healer = true },
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
    { "Mistweaver", "Sheilun's Gift", "The supported count display is separate from ordinary power.", healer = true },
    { "Windwalker", "Chi", "Configure segments, text and visibility for a true resource." },
  },
  PALADIN = {
    { "Holy", "Holy Power", "Group indicators can be customized in Unit Frames.", healer = true },
    { "Protection", "Holy Power; Shining Light", "Shining Light is a tracked effect, not Holy Power." },
    { "Retribution", "Holy Power", "Choose the supported segments, text and resource cues." },
  },
  PRIEST = {
    { "Discipline", "Primary power", "Healing indicators and optional effect trackers have separate settings.", healer = true },
    { "Holy", "Lightweaver", "This tracked effect can depend on your current talents.", healer = true },
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
    { "Restoration", "Primary power", "Group indicators and effect-duration trackers are optional.", healer = true },
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
  local key = ns.Modules.PRD:GetPrimaryResourceKey()
  local name = key and _G[key]
  if name then
    Heading("Your primary power: " .. name)
    Text("Primary power settings control this bar's text and tick markers. Health and secondary resources have separate settings.")
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
  return widget.content
end

local function Settings(path)
  local parent = Panel(500)
  settingsHost:SetParent(parent)
  settingsHost:ClearAllPoints()
  settingsHost:SetAllPoints(parent)
  settingsHost:Show()
  ns.InstallerSettings.Show(settingsHost, path)
end

local function Preview(kind, path)
  local parent = Panel(335)
  previewHost:SetParent(parent)
  previewHost:ClearAllPoints()
  previewHost:SetAllPoints(parent)
  previewHost:Show()
  ns.InstallerPreview.Show(previewHost, kind, path)
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
      button:SetRelativeWidth(0.48)
      button:SetHeight(Theme.GetOptionsPointerTargetSize(52))
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
  Action("Open " .. name, function() callbacks.openOptions(path) end)
end

local function Practice(kind)
  local parent = Panel(460)
  practice = practice or ns.EditModeGuidePractice.Create(host)
  practice.frame:SetParent(parent)
  practice.frame:ClearAllPoints()
  practice.frame:SetPoint("TOPLEFT", parent, "TOPLEFT")
  practice:Show(kind, math.max(450, group.frame:GetWidth()))
end

local function TrackerPage(key)
  local kind = key == "trackerCharges" and "charge" or key == "trackerStacks" and "stack" or "cooldown"
  local draft = drafts[key]
  if not draft then
    draft = ns.PCMCustomTrackerInstaller:CreateDraft(kind)
    draft.presentation = "BAR"
    drafts[key] = draft
  end
  Text("This example works even on a new profile. Nothing is saved until you choose Create tracker, review the creator, and finish it.")
  if key == "trackerStacks" then
    Dropdown("Track", { stack = "Aura stacks", duration = "Effect duration" }, { "stack", "duration" }, draft.kind, function(value)
      draft.kind = value
      draft.spellID = nil
      Rebuild()
    end)
  end
  Dropdown("Display", { BUTTON = "Button", BAR = "Bar" }, { "BUTTON", "BAR" }, draft.presentation, function(value)
    draft.presentation = value
    Rebuild()
  end)
  local values, order, canCreate, reason = ns.PCMCustomTrackerInstaller:GetDraftChoices(draft)
  if reason then Text(reason) end
  Dropdown("Tracked spell", values, order, draft.spellID and tostring(draft.spellID) or "none", function(value)
    draft.spellID = value ~= "none" and tonumber(value) or nil
    Rebuild()
  end)
  if draft.kind == "duration" then
    Dropdown("Duration source", ns.PCMCustomDurationSource.sourceValues, { "automatic", "ground", "aura" }, draft.durationSource, function(value)
      draft.durationSource = value
      Rebuild()
    end)
    Text(ns.PCMCustomDurationSource.sourceHelp)
  end
  if draft.kind == "stack" or draft.kind == "duration" and draft.durationSource ~= "ground" then
    Dropdown("Track aura on", { automatic = "Automatic", player_buff = "Player buff", target_debuff = "Target debuff" },
      { "automatic", "player_buff", "target_debuff" }, draft.auraTrackMode, function(value) draft.auraTrackMode = value end)
  end
  if draft.kind == "stack" then Slider("Maximum stacks", draft.maximum, 2, 60, 1, function(value) draft.maximum = value; ns.InstallerPreview.Refresh() end) end
  if draft.presentation == "BAR" then
    Slider("Width", draft.width, 80, 600, 5, function(value) draft.width = value; ns.InstallerPreview.Refresh() end)
    Slider("Height", draft.height, 6, 50, 1, function(value) draft.height = value; ns.InstallerPreview.Refresh() end)
    Check("Show text", draft.showText, function(value) draft.showText = value; ns.InstallerPreview.Refresh() end, true)
  else
    Slider("Icon size", draft.icon.size, 20, 96, 2, function(value) draft.icon.size = value; ns.InstallerPreview.Refresh() end)
    Check("Show countdown", draft.icon.showDuration, function(value) draft.icon.showDuration = value; ns.InstallerPreview.Refresh() end, true)
    if draft.kind == "charge" or draft.kind == "stack" then
      Check("Show count", draft.icon.showCount, function(value) draft.icon.showCount = value; ns.InstallerPreview.Refresh() end, true)
    end
  end
  if draft.kind == "charge" then
    Check("Show at full charges", draft.showReady, function(value) draft.showReady = value; ns.InstallerPreview.Refresh() end, true)
  elseif draft.kind == "stack" or draft.kind == "duration" then
    Check("Show only while active", draft.showOnlyWhenActive, function(value) draft.showOnlyWhenActive = value; ns.InstallerPreview.Refresh() end, true)
  end
  local parent = Panel(250)
  previewHost:SetParent(parent)
  previewHost:ClearAllPoints()
  previewHost:SetAllPoints(parent)
  previewHost:Show()
  ns.InstallerPreview.ShowDraft(previewHost, draft)
  local states = draft.kind == "charge" and { { "Full charges", "READY" }, { "One spent", "RECHARGING" }, { "Empty", "EMPTY" } }
    or (draft.kind == "stack" or draft.kind == "duration") and { { "Active", "ACTIVE" }, { "Inactive", "INACTIVE" } }
    or { { "Ready", "READY" }, { "On cooldown", "COOLDOWN" }, { "Aura active", "ACTIVE" } }
  for _, state in ipairs(states) do
    Action(state[1], function() ns.InstallerPreview.SetDraftState(state[2]) end)
  end
  Action("Play / pause example", ns.InstallerPreview.ToggleDraftAnimation)
  if ns.PCMCustomTrackerInstaller:HasDraft() then
    Text("You have an unfinished tracker in the creator. Continue it first; this sample does not replace it.")
    Action("Continue unfinished tracker", function() callbacks.openTracker() end)
  else
    Action("Create this tracker", function()
      local _, _, available, message = ns.PCMCustomTrackerInstaller:GetDraftChoices(draft)
      if not available then callbacks.status(message); Rebuild(); return end
      callbacks.openTracker(draft)
    end, not canCreate)
  end
  Details({ "CooldownManager", "customTrackers" }, "Cooldown Manager / Custom trackers")
end

local function Review()
  Heading("Saved profile: " .. Addon.db:GetCurrentProfile())
  local index = C_SpecializationInfo.GetSpecialization()
  local name
  if index then name = select(2, C_SpecializationInfo.GetSpecializationInfo(index)) end
  Text("Specialization: " .. (name or "Not selected") .. ". Settings are saved as you change them. Examples are separate.")
  for _, entry in ipairs({
    { "Unit frames", ns.UnitFrames:GetQuickSetupValue("enabled"), "unitframes" },
    { "Party frames", ns.Modules.PartyFrames.db.profile.enabled ~= false, "group" },
    { "Raid frames", ns.Modules.RaidFrames.db.profile.enabled ~= false, "group" },
    { "Personal Resource Display", ns.Modules.PRD:IsModuleEnabled(), "prd" },
    { "Cooldown Manager", ns.Modules.CooldownManager:IsModuleEnabledByUser(), "cooldowns" },
    { "Items and racials", ns.Modules.CooldownManager:GetConsumableTrackerEnabled(), "utility" },
    { "Damage meters", ns.Modules.DamageMeters.db.profile.enabled ~= false, "meters" },
  }) do
    Action(entry[1] .. ": " .. (entry[2] and "On" or "Off") .. " — Edit", function() callbacks.navigate(entry[3]) end)
  end
  Heading("Custom tracker inventory")
  local spellNames = ns.Modules.CooldownManager:GetCustomBarSpellDropdown("cooldown")
  local count = 0
  for _, family in ipairs({
    { "Cooldown", "spell:", ns.Modules.CooldownManager:GetSpellBarsDB() },
    { "Charge", "chargeSpell:", ns.Modules.CooldownManager:GetCooldownStackBarsDB() },
    { "Effect", "bb:", ns.Modules.PCM_BB.GetStackBarsDB() },
  }) do
    local ids = {}
    for id in pairs(family[3]) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
    for _, id in ipairs(ids) do
      local config = family[3][id]
      if type(config) == "table" then
        count = count + 1
        local name = spellNames[tostring(config.spellID or id)] or config.label or tostring(id)
        Action(family[1] .. " — " .. name .. " (" .. (config.presentation == "BUTTON" and "Button" or "Bar") .. ") — Edit",
          function() callbacks.openOptions({ "CooldownManager", "customTrackers", family[2] .. tostring(id) }) end)
      end
    end
  end
  if count == 0 then Text("No custom trackers have been created. They are optional.") end
  Heading("Other setup choices")
  Text("Options text size: " .. Theme.GetOptionsFontSize() .. ". Keyboard navigation: " .. (ns.KeyboardNavigation.IsEnabled() and "On" or "Off") .. ".")
  for _, entry in ipairs({ { "Accessibility and appearance", "appearance" }, { "Auras and indicators", "auras" },
    { "Action bars and keybinds", "bars" }, { "Specialization resources", "spec" },
    { "Chat, minimap, bags, buffs, skins, and skyriding", "everyday" }, { "Automation and warnings", "convenience" } }) do
    Action(entry[1] .. " — Review", function() callbacks.navigate(entry[2]) end)
  end
  Text(Content.pendingReload and "A reload is needed to finish applying your choices." or "No installer changes are waiting for a reload.")
  Action("Inspect my actual layout in Edit Mode", function()
    callbacks.openEditMode()
  end)
end

local function BuildPage(key)
  if key == "welcome" then
    Text("Welcome to PleebUI. Set up readable frames, action buttons, resources, and trackers at your own pace. Every section can be revisited later.")
    Heading("Make setup comfortable")
    Slider("Options text size", Theme.GetOptionsFontSize(), Theme.OptionsFontSizeRange.min, Theme.OptionsFontSizeRange.max,
      Theme.OptionsFontSizeRange.step, function(value) Theme.SetOptionsFontSize(value); Rebuild() end)
    Check("Larger pointer targets", Addon:GetOptionsDB().largerPointerTargets, function(value)
      Addon:GetOptionsDB().largerPointerTargets = value
      Addon:RefreshOptionsTheme()
      Rebuild()
    end)
    Check("Keyboard navigation", ns.KeyboardNavigation.IsEnabled(), ns.KeyboardNavigation.SetEnabled)
    Check("Animate options", ns.OptionsMotion.IsEnabled(), ns.OptionsMotion.SetEnabled)
    Text("Try Tab, arrow keys, and Enter on these controls. Mouse clicks clear keyboard focus. Accessibility is available at the top of every page.")
    Action("Full walkthrough", function() callbacks.chooseMode("full") end)
    Action("Choose my sections", function() callbacks.chooseMode("custom") end)
  elseif key == "profiles" then
    Heading("Current profile: " .. Addon.db:GetCurrentProfile())
    Text("Controls change the active profile as you use them. Examples stay separate. Create a setup profile first if you want to explore without changing your current profile.")
    local values, order = Addon:GetInstallerExistingProfiles()
    Dropdown("Use an existing profile (reload)", values, order, nil, function(name)
      local ok, message = Addon:ActivateExistingProfile(name)
      if ok then ReloadUI() else callbacks.status(message) end
    end)
    Action("Create a separate setup profile", function()
      Addon:PUI_ConfirmAction({
        title = "Create setup profile", text = "Create a profile with PleebUI defaults and reload? Your current profile will be kept.",
        yesText = "Create and reload", onYes = function()
          local names, index = {}, 1
          for _, name in ipairs(Addon.db:GetProfiles({})) do names[name] = true end
          local name = "PleebUI Setup"
          while names[name] do index = index + 1; name = "PleebUI Setup " .. index end
          Addon.db:SetProfile(name)
          ReloadUI()
        end,
      })
    end)
    Heading("Include these chapters")
    for _, chapter in ipairs(Content.Chapters) do
      Check(chapter.name, Content.sections[chapter.key] ~= false, function(value)
        Content.sections[chapter.key] = value
        callbacks.changedRoute()
      end)
    end
    Text("Excluding a chapter only skips its setup pages. It does not disable that feature.")
  elseif key == "appearance" then
    Text("Options text size and options window scale affect setup and settings. Global font choices affect PleebUI text. Game UI scale resizes the whole interface.")
    Choices("Configure", { { "Accessibility", { "Accessibility" } }, { "UI settings and game scale", { "UITheme" } } }, 1, function(choice) Settings(choice[2]) end)
    Heading("Text examples")
    Text("Options text: Choose a category, then adjust its controls.")
    local sample = Add(AceGUI:Create("PUI_Label"))
    sample:SetFullWidth(true)
    sample:SetText("Combat text sample: Player   73%   Power 62")
    ns.Theme.ApplyFont(sample.label, "body", 16)
    Text("Combat readability enlarges unit and resource text, aura icons, and borders in this profile. Undo remains available until profile change or reload.")
    Action("Apply combat readability", function() Addon:ApplyCombatReadabilityPreset(); Rebuild() end)
    Action("Undo combat readability", function() Addon:UndoCombatReadabilityPreset(); Rebuild() end, not Addon:CanUndoCombatReadabilityPreset())
  elseif key == "navigation" then
    Text("Choose a sample category and tab, then try a toggle and dropdown. These controls change only this practice area.")
    Practice("navigation")
    local sampleChoice = "icons"
    local values = { icons = "Icons", bars = "Bars", both = "Both" }
    local picker = Dropdown("Sample display", values, { "icons", "bars", "both" }, sampleChoice, function(value)
      sampleChoice = value
      practice.navResult:SetText("Sample display: " .. values[value] .. ". Your profile has not changed.")
    end)
    Action("Reset all practice controls", function()
      sampleChoice = "icons"
      picker:SetValue(sampleChoice)
      practice:Show("navigation", math.max(450, group.frame:GetWidth()))
    end)
    Details({ "Accessibility" }, "Accessibility")
  elseif key == "unitframes" then
    Text("Choose a frame to preview and configure. Each frame has its own size, text, power, and castbar settings; shared appearance is available separately.")
    Choices("Frame", {
      { "Player", { "unitframes", "player" } }, { "Target", { "unitframes", "target" } },
      { "Focus", { "unitframes", "focus" } }, { "Pet", { "unitframes", "player", "pet" } },
      { "Boss", { "unitframes", "boss" } }, { "Shared appearance", { "unitframes", "general" } },
    }, 1, function(choice) Preview("unitframes", choice[2]); Settings(choice[2]) end)
    Details({ "unitframes", "player" }, "Unit Frames")
  elseif key == "group" then
    Text("Party and raid layouts are independent. Role icons identify a member's role; defensive icons show supported protection effects; dispel indicators call attention to removable debuffs. Private aura information is controlled by Blizzard.")
    Choices("Group", { { "Party", { "unitframes", "party" } }, { "Raid", { "unitframes", "raid" } } }, 1, function(choice)
      Preview("unitframes", choice[2]); Settings(choice[2])
    end)
    Details({ "unitframes", "party" }, "Unit Frames / Party and raid")
  elseif key == "auras" then
    Text("Buffs help a unit; debuffs affect it negatively. Tracked groups select specific effects. Defensive indicators and dispels have separate settings. Only mine and spell filters apply to the selected aura display.")
    Choices("Aura display", {
      { "Player buffs and tracked effects", { "unitframes", "player", "auras", "customDisplays" } },
      { "Party buffs and debuffs", { "unitframes", "party", "auras", "customDisplays" } },
      { "Raid buffs and debuffs", { "unitframes", "raid", "auras", "customDisplays" } },
      { "Party dispels", { "unitframes", "party", "dispels" } },
      { "Raid dispels", { "unitframes", "raid", "dispels" } },
    }, 1, function(choice) Preview("unitframes", choice[2]); Settings(choice[2]) end)
    Text("The preview cannot be dragged during setup. Use the selected display's settings to change filters or placement. More-specific display settings take precedence over shared settings.")
  elseif key == "bars" then
    Text("Shared settings establish the button layout. Turn on a bar's custom settings to override it, then choose its visibility and mouseover behavior. Special bars retain their own controls.")
    local choices = { { "Shared settings", { "ACTIONBARS", "general" } } }
    for index = 1, 12 do choices[#choices + 1] = { "Bar " .. index, { "ACTIONBARS", tostring(index) } } end
    choices[#choices + 1] = { "Pet bar", { "ACTIONBARS", "special", "pet" } }
    choices[#choices + 1] = { "Stance bar", { "ACTIONBARS", "special", "stance" } }
    Choices("Action bar", choices, 1, function(choice) Preview("actionbars", choice[2]); Settings(choice[2]) end)
    Text("Vehicle, override, possess, extra-action, and zone-ability behavior follows its existing secure owner. Keep the required special controls visible and check them in the appropriate game situation.")
    Action("Open keybind mode", callbacks.openKeybinds)
  elseif key == "prd" then
    Text("Health and primary power are independent bars. Set height and text below; detached bars have their own width and position. Sample playback does not change your saved layout. Open PRD settings to reorder the real stack.")
    PrimaryPowerIntroduction()
    Check("Enable Personal Resource Display", ns.Modules.PRD:IsModuleEnabled(), function(value) ns.Modules.PRD:SetModuleEnabled(value) end)
    Preview("prd")
    Choices("Configure", { { "Health", { "PRD", "health" } }, { "Primary power and alternate Mana", { "PRD", "primary" } } }, 1, function(choice) Settings(choice[2]) end)
    Details({ "PRD", "health" }, "Personal Resource Display")
    Action("Arrange my real UI in Edit Mode", callbacks.openEditMode)
  elseif key == "spec" then
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
    Text("These are settings for the selected specialization. A configured effect still needs its talent, spell, or form to be available. The preview shows sample values, not proof that an effect is currently active.")
    Preview("prd")
    if #choices > 0 then Choices("Resource or effect", choices, default, function(choice)
      if class == "DRUID" and choice[2][3] == "COMBO_POINTS" then
        Text("Combo Points appear in Cat Form in any Druid specialization. Leaving Cat Form removes this contextual display; your saved settings are kept.")
      elseif class == "DRUID" and choice[2][3] == "IRONFUR" then
        Text("Ironfur is a Guardian Bear Form effect. Choose remaining duration or stack count. The example uses sample values and does not activate Ironfur on your character.")
      end
      Settings(choice[2])
    end)
    else Text("This specialization has no dedicated secondary tracker. Configure its primary power or choose an optional custom tracker.") end
    Details({ "PRD", "primary" }, "Personal Resource Display / Primary power")
    Heading("More to explore")
    if guide and guide.healer then
      Text("Party and raid aura indicators have separate settings for each group layout.")
      Action("Open party aura indicators", function() callbacks.openOptions({ "unitframes", "party", "auras", "customDisplays" }) end)
      Action("Open raid aura indicators", function() callbacks.openOptions({ "unitframes", "raid", "auras", "customDisplays" }) end)
    end
    if class == "EVOKER" then
      Action("Open empower castbar settings", function() callbacks.openOptions({ "unitframes", "player", "empower" }) end)
    end
    if ns.Modules.Quality:IsPetWarningAvailable() then
      Action("Open pet warnings", function() callbacks.openOptions({ "Quality", "combatTab" }) end)
      Action("Open pet action bar", function() callbacks.openOptions({ "ACTIONBARS", "special", "pet" }) end)
    end
    Text("Custom trackers are optional. These lessons show examples before you choose whether to create one.")
    Action("Explore custom cooldowns", function() callbacks.navigate("trackerCooldown") end)
    Action("Explore stacks and effect durations", function() callbacks.navigate("trackerStacks") end)
  elseif key == "cooldowns" then
    Text("Cooldowns show when spells become available. Buff icons and bars show active effects. Choose a group to set its size, countdown, visibility, and icon overrides.")
    Check("Enable Cooldown Manager", ns.Modules.CooldownManager:IsModuleEnabledByUser(), function(value) ns.Modules.CooldownManager:SetModuleEnabled(value) end)
    local choices = {}
    local groups = ns.PCMGroupManager:GetGroups()
    for _, id in ipairs(groups.order) do
      local entry = groups.byID[id]
      if entry then choices[#choices + 1] = { entry.name, { "CooldownManager", "groups", id } } end
    end
    if #choices > 0 then Choices("Group", choices, 1, function(choice) Preview("cooldowns", choice[2]); Settings(choice[2]) end) end
    Text("Tracked spell selection belongs to Blizzard. Add the spells you want there, then style their displays here.")
    Action("Choose tracked spells", callbacks.openTrackedSpells)
    Details({ "CooldownManager", "groups" }, "Cooldown Manager / Groups")
  elseif key == "trackerCooldown" or key == "trackerStacks" or key == "trackerCharges" then
    TrackerPage(key)
  elseif key == "utility" then
    Text("Items and racials include supported potions, health items, trinkets, and abilities. Choose categories and individual slots below. Battle resurrection and bloodlust are independent group displays.")
    Choices("Configure", {
      { "Items and racials", { "CooldownManager", "consumables" }, "cooldowns" },
      { "Battle resurrection, bloodlust, and group tools", { "Quality", "groupTab" }, "quality" },
    }, 1, function(choice) Preview(choice[3], choice[2]); Settings(choice[2]) end)
  elseif key == "meters" then
    Text("Current follows the current session. Fight selects a fight view; Overall combines the applicable session data. Changing the example below never changes combat history.")
    Preview("meters")
    Choices("Configure", { { "General", { "DamageMeters", "general" } }, { "Window 1", { "DamageMeters", "window1" } } }, 1, function(choice) Settings(choice[2]) end)
    local db = ns.Modules.DamageMeters.db.profile
    if db.windowCount > 0 then
      local window = ns.DamageMeterConfig.GetWindowDB(1)
      Slider("Window width", window.width, 220, 700, 5, function(value) ns.Modules.DamageMeters:ResizeWindow(1, value, window.height); ns.InstallerPreview.Refresh() end)
      Slider("Window height", window.height, 90, 600, 5, function(value) ns.Modules.DamageMeters:ResizeWindow(1, window.width, value); ns.InstallerPreview.Refresh() end)
      Dropdown("Window session", { CURRENT = "Current", OVERALL = "Overall" }, { "CURRENT", "OVERALL" }, window.session, function(value)
        window.session = value
        ns.DamageMeterSessions.SetWindowSelection(1, nil)
        ns.Modules.DamageMeters:ApplySettings()
        ns.InstallerPreview.Refresh()
      end)
      Text("Select a particular fight from the segment menu on the live meter. Current and Overall above remain explicit choices.")
    end
    Details({ "DamageMeters", "general" }, "Damage Meters")
  elseif key == "everyday" then
    Text("Choose a feature to see its example and existing controls. Changes apply to this profile; window skin changes take effect after reload.")
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
    Text("Choose automation deliberately. Visual helpers are separate from automatic interactions. Pet and combat warnings appear only where the owning module supports them.")
    Choices("Feature", {
      { "Loot, repair, selling, keystones, and invites", { "Quality", "automationTab" } },
      { "Cursor ring and crosshair", { "Quality", "cursorTab" }, "quality" },
      { "Combat and pet warnings", { "Quality", "combatTab" }, "quality" },
      { "Movement reminders", { "MovementWarning" } },
    }, 1, function(choice)
      if choice[3] then Preview(choice[3], choice[2]) end
      Settings(choice[2])
    end, true)
  elseif key == "arrange" then
    Text("Practice: select a mover, move it, select multiple movers with Ctrl, then undo and redo. These sample positions and history never touch your real layout.")
    Practice("movers")
    Text("Keyboard: F6 switches to mover keys; Tab selects a mover; arrows move it; 1–9 choose the step. Ctrl+Z undoes and Ctrl+Y redoes. F6 returns to controls.")
    Action("Check practice progress", function()
      callbacks.status(#practice.undo > 0 and "Movement recorded. Try Undo, Redo, then Reset practice." or #practice.redo > 0 and "Undo completed. Try Redo." or "Select and move a sample frame to start.")
    end)
    Action("Open real Edit Mode", callbacks.openEditMode)
  elseif key == "review" then
    Review()
  elseif key == "ready" then
    Review()
    Heading("Keep these shortcuts")
    Text("/pui — options\n/pe — arrange your UI\n/pek — keyboard Edit Mode\n/cd — tracked spells\n/pui install — reopen setup")
    Text("Continue with Finish setup below. If a reload is required, the button will say Finish and reload. Your saved profile and specialization settings are retained.")
    Details({ "Accessibility" }, "Accessibility and keyboard help")
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
  group.frame:HookScript("OnSizeChanged", function(_, _, height)
    if height > 0 then host:SetHeight(height + 16); callbacks.resize(height + 16) end
  end)
  settingsHost = ns.InstallerSettings.Create(host, 0)
  settingsHost:Hide()
  previewHost = CreateFrame("Frame", nil, host)
  previewHost:Hide()
  host:SetScript("OnSizeChanged", function(_, width)
    if width > 0 then group:SetWidth(math.max(450, width - 16)) end
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
  Content.Hide()
  activeKey = key
  if InCombatLockdown() then rebuilding = nil return end
  group.frame:SetFrameStrata(host:GetFrameStrata())
  group.frame:SetFrameLevel(host:GetFrameLevel() + 1)
  group:SetWidth(math.max(450, host:GetWidth() - 16))
  group:PauseLayout()
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
