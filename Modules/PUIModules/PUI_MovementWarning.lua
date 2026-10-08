local ADDON_NAME, ns = ...

local Addon = ns.Addon
local MovementWarning = Addon:NewModule("MovementWarning", "NumyAceEvent-3.0")
ns.Modules.MovementWarning = MovementWarning

local P = select(1, ns.Pleebug:DropIn(MovementWarning, { name = "Modules.MovementWarning" }))
local FrameUtil = ns.FrameUtil
local playerClass = select(2, UnitClass("player"))

local MOBILITY_SPELLS = {
  DEATHKNIGHT = { 48265, 444010, 444347, 212552 },
  DEMONHUNTER = { 195072, 189110, 1234796 },
  DRUID = { 102401, 1850, 252216, 106898 },
  EVOKER = { 358267 },
  HUNTER = { 781, 186257 },
  MAGE = { 1953, 212653 },
  MONK = { 109132, 115008, 101545, 119085, 361138 },
  PALADIN = { 190784 },
  PRIEST = { 121536 },
  ROGUE = { 36554, 195457, 2983 },
  SHAMAN = { 192063, 58875, 90328 },
  WARLOCK = { 48020 },
  WARRIOR = { 6544 },
}

local anchor
local runtime
local label
local countdown
local countdownText
local previewText
local countdownFont = CreateFont("PleebUI_MovementWarningCountdownFont")
local cooldownAlpha = C_CurveUtil.CreateCurve()
cooldownAlpha:SetType(Enum.LuaCurveType.Step)
cooldownAlpha:AddPoint(0, 0)
cooldownAlpha:AddPoint(3, 1)

local knownSpells = {}
local spellOptions = { [0] = "Automatic" }
local specializationID = 0
local baseSpellID
local trackedSpellID
local spellName
local spellIcon
local spellbookDirty = true
local previewEnabled = false

local function ApplyAnchor()
  local db = Addon.db.profile.movementWarning
  anchor:ClearAllPoints()
  anchor:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
end

local function RefreshSpellText()
  if not anchor then return end

  local db = Addon.db.profile.movementWarning
  local display = spellName or "movement"
  if db.displayMode == "icon" then
    local size = ns.Theme.ResolveFontSize(db.fontSize, "qualityOfLife")
    display = string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t",
      spellIcon or "Interface\\Icons\\INV_Misc_QuestionMark", size, size)
  end
  local text = "No " .. display .. " for"
  label:SetText(text)
  previewText:SetText(text .. " 8.0")
end

local function ResolveTrackedSpell()
  if not baseSpellID then
    trackedSpellID = nil
    spellName = nil
    spellIcon = nil
    RefreshSpellText()
    return
  end

  trackedSpellID = C_Spell.GetOverrideSpell(baseSpellID)
  spellName = C_Spell.GetSpellName(trackedSpellID)
  spellIcon = C_Spell.GetSpellTexture(trackedSpellID)
  RefreshSpellText()
end

local function RefreshSpellbook()
  if InCombatLockdown() then
    spellbookDirty = true
    return
  end

  wipe(knownSpells)
  wipe(spellOptions)
  spellOptions[0] = "Automatic"
  local specialization = C_SpecializationInfo.GetSpecialization()
  specializationID = specialization and C_SpecializationInfo.GetSpecializationInfo(specialization) or 0
  local candidates = MOBILITY_SPELLS[playerClass]
  local seen = {}
  for index = 1, #candidates do
    local spellID = candidates[index]
    if C_SpellBook.IsSpellKnownOrInSpellBook(spellID, Enum.SpellBookSpellBank.Player, true) then
      local displayID = C_Spell.GetOverrideSpell(spellID)
      local name = C_Spell.GetSpellName(displayID)
      if name and not seen[displayID] then
        seen[displayID] = true
        knownSpells[#knownSpells + 1] = spellID
        spellOptions[spellID] = name
      end
    end
  end

  local selected = Addon.db.profile.movementWarning.spells[specializationID] or 0
  if selected == 0 then
    baseSpellID = knownSpells[1]
  else
    baseSpellID = spellOptions[selected] and selected or nil
  end
  ResolveTrackedSpell()
  spellbookDirty = false
end

function MovementWarning:RefreshFonts()
  if not anchor then return end

  local db = Addon.db.profile.movementWarning
  local fontKey, flags = ns.Theme.GetIconTextGlobal()
  local font = ns.LSM:Fetch("font", fontKey)
  local size = ns.Theme.ResolveFontSize(db.fontSize, "qualityOfLife")
  local color = db.color
  countdownFont:SetFont(font, size, flags)
  countdownFont:SetTextColor(color.r, color.g, color.b, color.a)
  label:SetFont(font, size, flags)
  label:SetTextColor(color.r, color.g, color.b, color.a)
  previewText:SetFont(font, size, flags)
  previewText:SetTextColor(color.r, color.g, color.b, color.a)
  countdownText:SetFontObject(countdownFont)
  countdownText:SetTextColor(color.r, color.g, color.b, color.a)

  anchor:SetSize(600, size * 1.6)
  label:ClearAllPoints()
  label:SetPoint("CENTER", runtime, "CENTER", -size * 1.3, 0)
  countdownText:ClearAllPoints()
  countdownText:SetPoint("LEFT", label, "RIGHT", size * 0.2, 0)
  RefreshSpellText()
end

local function EnsureDisplay()
  if anchor then return end

  anchor = CreateFrame("Frame", "PleebUI_MovementWarningAnchor", UIParent)
  anchor:SetFrameStrata("HIGH")
  anchor:EnableMouse(false)
  ApplyAnchor()

  runtime = CreateFrame("Frame", nil, anchor)
  runtime:SetAllPoints(anchor)
  runtime:Hide()
  label = runtime:CreateFontString(nil, "OVERLAY")

  countdown = CreateFrame("Cooldown", nil, runtime, "CooldownFrameTemplate")
  countdown:SetSize(1, 1)
  countdown:SetPoint("CENTER", runtime, "CENTER")
  countdown:SetDrawSwipe(false)
  countdown:SetDrawEdge(false)
  countdown:SetDrawBling(false)
  countdown:SetHideCountdownNumbers(false)
  countdown:SetMinimumCountdownDuration(0)
  countdown:SetCountdownAbbrevThreshold(0)
  countdown:SetCountdownMillisecondsThreshold(86400)
  countdownFont:SetFont(STANDARD_TEXT_FONT, 24, "OUTLINE")
  countdown:SetCountdownFont("PleebUI_MovementWarningCountdownFont")
  countdownText = countdown:GetCountdownFontString()
  countdownText:SetJustifyH("LEFT")
  countdown:SetScript("OnCooldownDone", function()
    runtime:Hide()
  end)

  previewText = anchor:CreateFontString(nil, "OVERLAY")
  previewText:SetPoint("CENTER", anchor, "CENTER")
  previewText:Hide()
  MovementWarning:RefreshFonts()

  FrameUtil:RegisterMover("movement_warning", anchor, {
    label = "Movement Reminder",
    optionsString = "MovementWarning",
    smartSnap = {
      family = "positionOnly",
      isRuntimeActive = function()
        return MovementWarning:IsEnabled() and Addon.db.profile.movementWarning.enabled
      end,
    },
    savePosition = function()
      local db = Addon.db.profile.movementWarning
      db.x, db.y = FrameUtil.GetMoverOffsets(anchor)
    end,
    resetPosition = function()
      local db = Addon.db.profile.movementWarning
      db.x, db.y = 0, 50
      ApplyAnchor()
    end,
  })
end

function MovementWarning:RefreshWarning()
  if not anchor then return end

  local db = Addon.db.profile.movementWarning
  local enabled = self:IsEnabled() and db.enabled
  local preview = enabled and (previewEnabled or ns.Flags.IsEditing)
  previewText:SetShown(preview)

  if not enabled or preview or not trackedSpellID
    or (db.combatOnly and not InCombatLockdown())
  then
    runtime:Hide()
    countdown:Clear()
    return
  end

  local charges = C_Spell.GetSpellCharges(baseSpellID)
  local duration
  if charges then
    if charges.isActive ~= true then
      runtime:Hide()
      countdown:Clear()
      return
    end
    duration = C_Spell.GetSpellChargeDuration(baseSpellID)
  else
    local cooldown = C_Spell.GetSpellCooldown(baseSpellID)
    if not cooldown or cooldown.isActive ~= true then
      runtime:Hide()
      countdown:Clear()
      return
    end
    duration = C_Spell.GetSpellCooldownDuration(baseSpellID, true)
  end

  if not duration then
    runtime:Hide()
    countdown:Clear()
    return
  end

  countdown:SetCooldownFromDurationObject(duration)
  if charges then
    -- The spell's own duration is GCD-length while a charge is available.
    -- Keep the classification in the engine; currentCharges is secret.
    local availabilityDuration = C_Spell.GetSpellCooldownDuration(baseSpellID)
    if not availabilityDuration then
      runtime:Hide()
      return
    end
    runtime:SetAlpha(availabilityDuration:EvaluateTotalDuration(cooldownAlpha))
  else
    -- Ignore brief shared lockouts without inspecting secret timing fields.
    runtime:SetAlpha(duration:EvaluateTotalDuration(cooldownAlpha))
  end
  runtime:Show()
end

function MovementWarning:OnMovementEvent(event, unit)
  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end

  if event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED"
    or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED"
  then
    RefreshSpellbook()
  elseif event == "UPDATE_SHAPESHIFT_FORM" then
    ResolveTrackedSpell()
  elseif event == "PLAYER_REGEN_ENABLED" and spellbookDirty then
    RefreshSpellbook()
  end
  self:RefreshWarning()
end

function MovementWarning:ApplySettings()
  self:UnregisterAllEvents()
  local db = Addon.db.profile.movementWarning
  if self:IsEnabled() and db.enabled then
    EnsureDisplay()
    ApplyAnchor()
    self:RefreshFonts()
    RefreshSpellbook()
    for _, event in ipairs({
      "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
      "TRAIT_CONFIG_UPDATED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_ENABLED",
      "PLAYER_REGEN_DISABLED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES",
    }) do
      self:RegisterEvent(event, "OnMovementEvent")
    end
  else
    previewEnabled = false
  end
  if anchor then
    FrameUtil.SetMoverSuppressed("movement_warning", not (self:IsEnabled() and db.enabled))
  end
  self:RefreshWarning()
end

function MovementWarning:GetOptions()
  return {
    type = "group",
    name = "Movement Reminder",
    args = {
      enabled = {
        type = "toggle", name = "Show movement reminder", order = 1,
        get = function() return Addon.db.profile.movementWarning.enabled end,
        set = function(_, value)
          Addon.db.profile.movementWarning.enabled = value
          self:ApplySettings()
        end,
      },
      settings = {
        type = "group", name = "Reminder", inline = true, order = 2,
        disabled = function() return not Addon.db.profile.movementWarning.enabled end,
        args = {
          spell = {
            type = "select", name = "Movement spell", order = 1,
            desc = "Choose a movement spell for this specialization. Automatic selects your first known mobility spell.",
            values = function() return spellOptions end,
            get = function() return Addon.db.profile.movementWarning.spells[specializationID] or 0 end,
            set = function(_, value)
              Addon.db.profile.movementWarning.spells[specializationID] = value
              self:ApplySettings()
            end,
          },
          combatOnly = {
            type = "toggle", name = "Only in combat", order = 2,
            get = function() return Addon.db.profile.movementWarning.combatOnly end,
            set = function(_, value)
              Addon.db.profile.movementWarning.combatOnly = value
              self:RefreshWarning()
            end,
          },
          displayMode = {
            type = "select", name = "Spell display", order = 2.5,
            values = { text = "Text", icon = "Icon" },
            get = function() return Addon.db.profile.movementWarning.displayMode end,
            set = function(_, value)
              Addon.db.profile.movementWarning.displayMode = value
              RefreshSpellText()
            end,
          },
          fontSize = {
            type = "range", name = "Text size", order = 3, min = 12, max = 64, step = 1,
            get = function() return Addon.db.profile.movementWarning.fontSize end,
            set = function(_, value)
              Addon.db.profile.movementWarning.fontSize = value
              self:RefreshFonts()
            end,
          },
          color = {
            type = "color", name = "Text color", order = 4, hasAlpha = true,
            get = function()
              local color = Addon.db.profile.movementWarning.color
              return color.r, color.g, color.b, color.a
            end,
            set = function(_, r, g, b, a)
              local color = Addon.db.profile.movementWarning.color
              color.r, color.g, color.b, color.a = r, g, b, a
              self:RefreshFonts()
            end,
          },
          preview = {
            type = "toggle", name = "Show preview", order = 5,
            desc = "Show a sample reminder. Use /pe to move it.",
            get = function() return previewEnabled end,
            set = function(_, value)
              previewEnabled = value
              self:RefreshWarning()
            end,
          },
        },
      },
    },
  }
end

function MovementWarning:ShowEnablePrompt(onClosed)
  local function SaveChoice(enabled)
    Addon.db.global.onboarding.movementReminderPromptPending = false
    Addon.db.profile.movementWarning.enabled = enabled
    self:ApplySettings()
    onClosed()
  end

  Addon:PUI_ConfirmAction({
    title = "Movement Reminder",
    text = "Do you want to enable the movement reminder?\n\nShows a countdown in the middle of your screen while your main movement spell is unavailable.",
    yesText = "Enable",
    noText = "No thanks",
    onYes = function() SaveChoice(true) end,
    onNo = function() SaveChoice(false) end,
  })
end

function MovementWarning:OnInitialize()
  _G.PleebUIAPI:RegisterPlugin("PleebUI_MovementWarning", {
    name = "Movement Reminder",
  }):RegisterEditModeParticipant("runtime", {
    order = 31,
    onChanged = function() self:RefreshWarning() end,
  })
  Addon:RegisterOptionsSection("MovementWarning", function() return self end, 3,
    "Movement Reminder", "Quality", {
      preview = false,
      pageDescription = "Show a countdown while your movement spell is unavailable.",
      pageHelp = "Use /pe to move the reminder.",
    })
end

function MovementWarning:OnEnable()
  self:ApplySettings()
end

function MovementWarning:OnDisable()
  self:UnregisterAllEvents()
  previewEnabled = false
  if anchor then
    runtime:Hide()
    countdown:Clear()
    previewText:Hide()
    FrameUtil.SetMoverSuppressed("movement_warning", true)
  end
end

MovementWarning.RefreshFonts = P:Def("MovementWarning:RefreshFonts", MovementWarning.RefreshFonts)
MovementWarning.RefreshWarning = P:Def("MovementWarning:RefreshWarning", MovementWarning.RefreshWarning)
MovementWarning.OnMovementEvent = P:Def("MovementWarning:OnMovementEvent", MovementWarning.OnMovementEvent)
MovementWarning.ApplySettings = P:Def("MovementWarning:ApplySettings", MovementWarning.ApplySettings)
MovementWarning.ShowEnablePrompt = P:Def("MovementWarning:ShowEnablePrompt", MovementWarning.ShowEnablePrompt)
MovementWarning.OnInitialize = P:Def("MovementWarning:OnInitialize", MovementWarning.OnInitialize)
MovementWarning.OnEnable = P:Def("MovementWarning:OnEnable", MovementWarning.OnEnable)
MovementWarning.OnDisable = P:Def("MovementWarning:OnDisable", MovementWarning.OnDisable)
