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
local rows = {}
local trackedCount = 0
local countdownFont = CreateFont("PleebUI_MovementWarningCountdownFont")
local cooldownAlpha = C_CurveUtil.CreateCurve()
cooldownAlpha:SetType(Enum.LuaCurveType.Step)
cooldownAlpha:AddPoint(0, 0)
cooldownAlpha:AddPoint(3, 1)

local knownSpells = {}
local spellOptions = {}
local specializationID = 0
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
  local previewDuration = db.showDecimals ~= false and "8.0" or "8"
  for index = 1, trackedCount do
    local row = rows[index]
    local text = "No " .. row.spellName .. " for"
    row.label:SetText(text)
    row.icon:SetTexture(row.spellIcon)
    row.previewText:SetText(text)
    row.previewCountdown:SetText(previewDuration)
    row.countdown:SetCountdownMillisecondsThreshold(db.showDecimals ~= false and 86400 or 0)
  end
end

local function ResolveTrackedSpells()
  for index = 1, trackedCount do
    local row = rows[index]
    row.spellID = C_Spell.GetOverrideSpell(row.baseSpellID)
    row.spellName = C_Spell.GetSpellName(row.spellID)
    row.spellIcon = C_Spell.GetSpellTexture(row.spellID)
  end
end

local function RefreshSpellbook()
  if InCombatLockdown() then
    spellbookDirty = true
    return
  end

  wipe(knownSpells)
  wipe(spellOptions)
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
  spellbookDirty = false
end

local function EnsureRow(index)
  local row = rows[index]
  if row then return row end

  row = {}
  row.frame = CreateFrame("Frame", nil, anchor)
  row.runtime = CreateFrame("Frame", nil, row.frame)
  row.runtime:SetAllPoints(row.frame)
  row.runtime:Hide()
  row.label = row.runtime:CreateFontString(nil, "OVERLAY")
  row.icon = row.runtime:CreateTexture(nil, "ARTWORK")
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  row.unavailable = row.runtime:CreateFontString(nil, "OVERLAY")
  row.unavailable:SetShadowColor(0, 0, 0, 1)
  row.unavailable:SetShadowOffset(1, -1)

  local countdown = CreateFrame("Cooldown", nil, row.runtime, "CooldownFrameTemplate")
  row.countdown = countdown
  countdown:SetPoint("CENTER", row.runtime, "CENTER")
  countdown:SetDrawSwipe(false)
  countdown:SetDrawEdge(false)
  countdown:SetDrawBling(false)
  countdown:SetHideCountdownNumbers(false)
  countdown:SetMinimumCountdownDuration(0)
  countdown:SetCountdownAbbrevThreshold(0)
  countdown:SetCountdownMillisecondsThreshold(86400)
  countdown:SetCountdownFont("PleebUI_MovementWarningCountdownFont")
  row.countdownText = countdown:GetCountdownFontString()
  row.countdownText:SetJustifyH("LEFT")
  countdown:SetScript("OnCooldownDone", function()
    if not previewEnabled and not ns.Flags.IsEditing then
      row.runtime:Hide()
    end
  end)

  row.previewText = row.runtime:CreateFontString(nil, "OVERLAY")
  row.previewText:SetPoint("CENTER", row.runtime, "CENTER")
  row.previewText:Hide()

  row.previewCountdown = row.runtime:CreateFontString(nil, "OVERLAY")
  row.previewCountdown:SetJustifyH("LEFT")
  row.previewCountdown:Hide()

  rows[index] = row
  return row
end

local function GetSelectedSpells()
  local spells = Addon.db.profile.movementWarning.spells
  local selected = spells[specializationID]
  if type(selected) == "number" then
    selected = selected ~= 0 and { [selected] = true } or nil
    spells[specializationID] = selected
  end
  return selected
end

local function RefreshSelectedSpells()
  for index = 1, #rows do
    local row = rows[index]
    row.runtime:Hide()
    row.countdown:Clear()
    row.previewText:Hide()
    row.previewCountdown:Hide()
    row.frame:Hide()
  end

  trackedCount = 0
  local selected = GetSelectedSpells()
  for index = 1, #knownSpells do
    local spellID = knownSpells[index]
    if not selected or selected[spellID] == true then
      trackedCount = trackedCount + 1
      local row = EnsureRow(trackedCount)
      row.baseSpellID = spellID
      row.frame:Show()
    end
  end
  ResolveTrackedSpells()
  MovementWarning:RefreshFonts()
end

function MovementWarning:RefreshFonts()
  if not anchor then return end

  local db = Addon.db.profile.movementWarning
  local fontKey, flags = ns.Theme.GetIconTextGlobal()
  local font = ns.LSM:Fetch("font", fontKey)
  local size = ns.Theme.ResolveFontSize(db.fontSize, "qualityOfLife")
  local height = size * 1.6
  local color = db.color
  local countdownColor = db.countdownColor
  countdownFont:SetFont(font, size, flags)
  countdownFont:SetTextColor(countdownColor.r, countdownColor.g, countdownColor.b, countdownColor.a)
  anchor:SetSize(600, height * math.max(1, trackedCount))

  for index = 1, #rows do
    local row = rows[index]
    row.frame:SetSize(600, height)
    row.frame:ClearAllPoints()
    row.frame:SetPoint("TOP", anchor, "TOP", 0, -(index - 1) * height)
    row.label:SetFont(font, size, flags)
    row.label:SetTextColor(color.r, color.g, color.b, color.a)
    row.previewText:SetFont(font, size, flags)
    row.previewText:SetTextColor(color.r, color.g, color.b, color.a)
    row.previewCountdown:SetFont(font, size, flags)
    row.previewCountdown:SetTextColor(countdownColor.r, countdownColor.g, countdownColor.b, countdownColor.a)
    row.unavailable:SetFont(font, math.max(20, size * 0.975), "OUTLINE")
    row.unavailable:SetText("×")
    row.unavailable:SetTextColor(1, 0.2, 0.2, 1)
    row.icon:SetSize(size, size)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("RIGHT", row.runtime, "CENTER", -size * 0.9, 0)
    row.unavailable:ClearAllPoints()
    row.unavailable:SetPoint("TOPRIGHT", row.icon, "TOPRIGHT", size * 0.12, size * 0.12)
    row.countdown:SetSize(size * 3, height)
    row.countdownText:SetFontObject(countdownFont)
    row.countdownText:SetTextColor(countdownColor.r, countdownColor.g, countdownColor.b, countdownColor.a)
    row.label:ClearAllPoints()
    row.label:SetPoint("CENTER", row.runtime, "CENTER", -size * 1.3, 0)
    row.countdownText:ClearAllPoints()
    row.countdownText:SetPoint("LEFT", db.displayMode == "icon" and row.icon or row.label, "RIGHT", size * 0.2, 0)
    row.previewText:ClearAllPoints()
    row.previewText:SetPoint("CENTER", row.runtime, "CENTER", -size * 1.3, 0)
    row.previewCountdown:ClearAllPoints()
    row.previewCountdown:SetPoint("LEFT", db.displayMode == "icon" and row.icon or row.previewText, "RIGHT", size * 0.2, 0)
  end
  RefreshSpellText()
end

local function EnsureDisplay()
  if anchor then return end

  anchor = CreateFrame("Frame", "PleebUI_MovementWarningAnchor", UIParent)
  anchor:SetFrameStrata("HIGH")
  anchor:EnableMouse(false)
  ApplyAnchor()
  countdownFont:SetFont(STANDARD_TEXT_FONT, 24, "OUTLINE")

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

local function RefreshRowCooldown(row)
  local spellID = row.spellID
  local charges = C_Spell.GetSpellCharges(spellID)
  local isChargeSpell = charges and charges.maxCharges > 1
  local duration
  if isChargeSpell then
    if charges.isActive ~= true then
      row.runtime:Hide()
      row.countdown:Clear()
      return
    end
    duration = C_Spell.GetSpellChargeDuration(spellID)
  else
    local cooldown = C_Spell.GetSpellCooldown(spellID)
    if not cooldown or cooldown.isActive ~= true then
      row.runtime:Hide()
      row.countdown:Clear()
      return
    end
    duration = C_Spell.GetSpellCooldownDuration(spellID, true)
  end

  if not duration then
    row.runtime:Hide()
    row.countdown:Clear()
    return
  end

  row.countdown:SetCooldownFromDurationObject(duration)
  row.countdown:Show()
  if isChargeSpell then
    -- A banked charge reports only a brief cooldown. The engine classifies
    -- its secret duration and passes the result directly to the alpha sink.
    local availabilityDuration = C_Spell.GetSpellCooldownDuration(spellID)
    if not availabilityDuration then
      row.runtime:Hide()
      row.countdown:Clear()
      return
    end
    row.runtime:SetAlpha(availabilityDuration:EvaluateTotalDuration(cooldownAlpha))
  else
    row.runtime:SetAlpha(duration:EvaluateTotalDuration(cooldownAlpha))
  end
  row.runtime:Show()
end

function MovementWarning:RefreshWarning()
  if not anchor then return end

  local db = Addon.db.profile.movementWarning
  local enabled = self:IsEnabled() and db.enabled
  local preview = enabled and (previewEnabled or ns.Flags.IsEditing)
  local iconMode = db.displayMode == "icon"
  for index = 1, trackedCount do
    local row = rows[index]
    row.previewText:SetShown(preview and not iconMode)
    row.previewCountdown:SetShown(preview)
    row.label:SetShown(not preview and not iconMode)
    row.icon:SetShown(iconMode)
    row.unavailable:SetShown(iconMode)
    if not enabled or (db.combatOnly and not InCombatLockdown() and not preview) then
      row.runtime:Hide()
      row.countdown:Clear()
    elseif preview then
      row.countdown:Clear()
      row.countdown:Hide()
      row.runtime:SetAlpha(1)
      row.runtime:Show()
    else
      RefreshRowCooldown(row)
    end
  end
end

function MovementWarning:OnMovementEvent(event, unit)
  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end

  if event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED"
    or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED"
  then
    RefreshSpellbook()
    RefreshSelectedSpells()
  elseif event == "UPDATE_SHAPESHIFT_FORM" then
    ResolveTrackedSpells()
    RefreshSpellText()
  elseif event == "PLAYER_REGEN_ENABLED" and spellbookDirty then
    RefreshSpellbook()
    RefreshSelectedSpells()
  end
  self:RefreshWarning()
end

function MovementWarning:ApplySettings()
  self:UnregisterAllEvents()
  local db = Addon.db.profile.movementWarning
  if self:IsEnabled() and db.enabled then
    EnsureDisplay()
    ApplyAnchor()
    RefreshSpellbook()
    RefreshSelectedSpells()
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
          spells = {
            type = "multiselect", name = "Movement spells", order = 1,
            desc = "Select the spells to track for this specialization. Each unavailable spell has its own reminder.",
            values = function() return spellOptions end,
            get = function(_, spellID)
              local selected = GetSelectedSpells()
              return not selected or selected[spellID] == true
            end,
            set = function(_, spellID, value)
              local spells = Addon.db.profile.movementWarning.spells
              local selected = GetSelectedSpells()
              if not selected then
                selected = {}
                for index = 1, #knownSpells do
                  selected[knownSpells[index]] = true
                end
                spells[specializationID] = selected
              end
              selected[spellID] = value
              RefreshSelectedSpells()
              self:RefreshWarning()
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
            values = { text = "Text", icon = "Icon only" },
            get = function() return Addon.db.profile.movementWarning.displayMode end,
            set = function(_, value)
              Addon.db.profile.movementWarning.displayMode = value
              self:RefreshFonts()
              self:RefreshWarning()
            end,
          },
          showDecimals = {
            type = "toggle", name = "Show decimals", order = 2.75,
            get = function() return Addon.db.profile.movementWarning.showDecimals ~= false end,
            set = function(_, value)
              Addon.db.profile.movementWarning.showDecimals = value
              self:RefreshFonts()
              self:RefreshWarning()
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
            type = "color", name = "Label color", order = 4, hasAlpha = true,
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
          countdownColor = {
            type = "color", name = "Countdown color", order = 4.5, hasAlpha = true,
            get = function()
              local color = Addon.db.profile.movementWarning.countdownColor
              return color.r, color.g, color.b, color.a
            end,
            set = function(_, r, g, b, a)
              local color = Addon.db.profile.movementWarning.countdownColor
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
    text = "Do you want to enable the movement reminder?\n\nShows a countdown in the middle of your screen while your selected movement spells are unavailable.",
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
      pageDescription = "Show a countdown for each unavailable movement spell.",
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
    for index = 1, #rows do
      local row = rows[index]
      row.runtime:Hide()
      row.countdown:Clear()
      row.previewText:Hide()
    end
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
