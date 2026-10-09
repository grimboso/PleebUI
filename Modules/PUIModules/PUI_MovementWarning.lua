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
local cooldownAlpha = C_CurveUtil.CreateCurve()
cooldownAlpha:SetType(Enum.LuaCurveType.Step)
cooldownAlpha:AddPoint(0, 0)
cooldownAlpha:AddPoint(3, 1)

local knownSpells = {}
local spellOptions = {}
local specializationID = 0
local spellbookDirty = true
local previewEnabled = false
local optionsPreview
local previewSpellID

local function NormalizeReminderSettings()
  local db = Addon.db.profile.movementWarning
  db.reminders = db.reminders or {}
  for _, spellID in ipairs(MOBILITY_SPELLS[playerClass]) do
    if not db.reminders[spellID] then
      local color = db.color or { r = 1, g = 1, b = 1, a = 1 }
      local countdownColor = db.countdownColor or { r = 1, g = 0.2, b = 0.2, a = 1 }
      db.reminders[spellID] = {
        combatOnly = db.combatOnly == true,
        displayMode = db.displayMode or "text",
        showCountdown = true,
        showDecimals = db.showDecimals ~= false,
        fontSize = db.fontSize or 24,
        countdownFontSize = db.fontSize or 24,
        color = { r = color.r, g = color.g, b = color.b, a = color.a },
        countdownColor = { r = countdownColor.r, g = countdownColor.g, b = countdownColor.b, a = countdownColor.a },
      }
    end
  end
  db.combatOnly, db.displayMode, db.showDecimals, db.fontSize, db.color, db.countdownColor = nil, nil, nil, nil, nil, nil
end

local function ApplyAnchor()
  local db = Addon.db.profile.movementWarning
  anchor:ClearAllPoints()
  anchor:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
end

local function RefreshSpellText()
  if not anchor then return end

  local db = Addon.db.profile.movementWarning
  for index = 1, trackedCount do
    local row = rows[index]
    local config = db.reminders[row.baseSpellID]
    local text = config.showCountdown and ("No " .. row.spellName .. " for") or (row.spellName .. " unavailable")
    row.label:SetText(text)
    row.icon:SetTexture(row.spellIcon)
    row.previewText:SetText(text)
    row.previewCountdown:SetText(config.showDecimals and "8.0" or "8")
    row.countdown:SetCountdownMillisecondsThreshold(config.showDecimals and 86400 or 0)
    row.countdown:SetHideCountdownNumbers(not config.showCountdown)
  end
end

local function ResolveTrackedSpells()
  local tracksCharges = false
  for index = 1, trackedCount do
    local row = rows[index]
    row.spellID = C_Spell.GetOverrideSpell(row.baseSpellID)
    row.spellName = C_Spell.GetSpellName(row.spellID)
    row.spellIcon = C_Spell.GetSpellTexture(row.spellID)

    local charges = C_Spell.GetSpellCharges(row.spellID)
    if charges and charges.maxCharges > 1 then
      tracksCharges = true
    end
  end

  if tracksCharges then
    MovementWarning:RegisterEvent("SPELL_UPDATE_CHARGES", "OnMovementEvent")
  else
    MovementWarning:UnregisterEvent("SPELL_UPDATE_CHARGES")
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
  row.countdownFont = CreateFont("PleebUI_MovementWarningCountdownFont" .. index)
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
  countdown:SetCountdownFont("PleebUI_MovementWarningCountdownFont" .. index)
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
  self:RefreshOptionsPreview()
  if not anchor then return end

  local db = Addon.db.profile.movementWarning
  local fontKey, flags = ns.Theme.GetIconTextGlobal()
  local font = ns.LSM:Fetch("font", fontKey)
  local offset = 0
  for index = 1, trackedCount do
    local row = rows[index]
    local config = db.reminders[row.baseSpellID]
    local size = ns.Theme.ResolveFontSize(config.fontSize, "qualityOfLife")
    local countdownSize = ns.Theme.ResolveFontSize(config.countdownFontSize, "qualityOfLife")
    local height = math.max(size, config.showCountdown and countdownSize or 0) * 1.6
    local color = config.color
    local countdownColor = config.countdownColor
    row.countdownFont:SetFont(font, countdownSize, flags)
    row.countdownFont:SetTextColor(countdownColor.r, countdownColor.g, countdownColor.b, countdownColor.a)
    row.frame:SetSize(600, height)
    row.frame:ClearAllPoints()
    row.frame:SetPoint("TOP", anchor, "TOP", 0, -offset)
    offset = offset + height
    row.label:SetFont(font, size, flags)
    row.label:SetTextColor(color.r, color.g, color.b, color.a)
    row.previewText:SetFont(font, size, flags)
    row.previewText:SetTextColor(color.r, color.g, color.b, color.a)
    row.previewCountdown:SetFont(font, countdownSize, flags)
    row.previewCountdown:SetTextColor(countdownColor.r, countdownColor.g, countdownColor.b, countdownColor.a)
    row.unavailable:SetFont(font, math.max(20, size * 0.975), "OUTLINE")
    row.unavailable:SetText("×")
    row.unavailable:SetTextColor(1, 0.2, 0.2, 1)
    row.icon:SetSize(size, size)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("RIGHT", row.runtime, "CENTER", -size * 0.9, 0)
    row.unavailable:ClearAllPoints()
    row.unavailable:SetPoint("TOPRIGHT", row.icon, "TOPRIGHT", size * 0.12, size * 0.12)
    row.countdown:SetSize(countdownSize * 3, height)
    row.countdownText:SetFontObject(row.countdownFont)
    row.countdownText:SetTextColor(countdownColor.r, countdownColor.g, countdownColor.b, countdownColor.a)
    row.label:ClearAllPoints()
    row.label:SetPoint("CENTER", row.runtime, "CENTER", -size * 1.3, 0)
    row.countdownText:ClearAllPoints()
    row.countdownText:SetPoint("LEFT", config.displayMode == "icon" and row.icon or row.label, "RIGHT", size * 0.2, 0)
    row.previewText:ClearAllPoints()
    row.previewText:SetPoint("CENTER", row.runtime, "CENTER", -size * 1.3, 0)
    row.previewCountdown:ClearAllPoints()
    row.previewCountdown:SetPoint("LEFT", config.displayMode == "icon" and row.icon or row.previewText, "RIGHT", size * 0.2, 0)
  end
  anchor:SetSize(600, math.max(24, offset))
  RefreshSpellText()
end

local function EnsureDisplay()
  if anchor then return end

  anchor = CreateFrame("Frame", "PleebUI_MovementWarningAnchor", UIParent)
  anchor:SetFrameStrata("HIGH")
  anchor:EnableMouse(false)
  ApplyAnchor()

  FrameUtil:RegisterMover("movement_warning", anchor, {
    label = "Movement Reminder",
    moduleKey = "movementWarning",
    moduleLabel = "Movement Reminder",
    onPreviewVisibilityChanged = function()
      MovementWarning:RefreshWarning()
    end,
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
  local config = Addon.db.profile.movementWarning.reminders[row.baseSpellID]
  if config.combatOnly and not InCombatLockdown() then
    row.runtime:Hide()
    row.countdown:Clear()
    return
  end
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
  local previewVisible = FrameUtil.IsMoverPreviewVisible("movement_warning")
  local preview = enabled and (previewEnabled or ns.Flags.IsEditing)
    and previewVisible
  for index = 1, trackedCount do
    local row = rows[index]
    local config = db.reminders[row.baseSpellID]
    local iconMode = config.displayMode == "icon"
    row.previewText:SetShown(preview and not iconMode)
    row.previewCountdown:SetShown(preview and config.showCountdown)
    row.label:SetShown(not preview and not iconMode)
    row.icon:SetShown(iconMode)
    row.unavailable:SetShown(iconMode)
    if not enabled
      or (ns.Flags.IsEditing and not previewVisible)
      or (config.combatOnly and not InCombatLockdown() and not preview)
    then
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

function MovementWarning:OnMovementEvent(event, eventSpellID, baseSpellID, spellCategory)
  if event == "PLAYER_SPECIALIZATION_CHANGED" and eventSpellID ~= "player" then return end

  if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
    if trackedCount == 0 or previewEnabled or ns.Flags.IsEditing
    then
      return
    end

    if event == "SPELL_UPDATE_COOLDOWN"
      and not issecretvalue(eventSpellID)
      and not issecretvalue(baseSpellID)
      and not issecretvalue(spellCategory)
      and eventSpellID ~= nil and spellCategory == nil
    then
      for index = 1, trackedCount do
        local row = rows[index]
        if eventSpellID == row.spellID
          or eventSpellID == row.baseSpellID
          or baseSpellID == row.baseSpellID
        then
          RefreshRowCooldown(row)
        end
      end
      return
    end

    for index = 1, trackedCount do
      RefreshRowCooldown(rows[index])
    end
    return
  end

  local spellbookChanged = false
  if event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED"
    or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED"
  then
    RefreshSpellbook()
    RefreshSelectedSpells()
    spellbookChanged = true
  elseif event == "UPDATE_SHAPESHIFT_FORM" then
    ResolveTrackedSpells()
    RefreshSpellText()
  elseif event == "PLAYER_REGEN_ENABLED" and spellbookDirty then
    RefreshSpellbook()
    RefreshSelectedSpells()
    spellbookChanged = true
  end
  if spellbookChanged then
    local path = ns._PUIActiveOptionsPath
    Addon:NotifyOptionsTreeChanged("MovementWarning", path and path[1] == "MovementWarning" and path or nil)
  end
  self:RefreshWarning()
  self:RefreshOptionsPreview()
end

function MovementWarning:ApplySettings()
  self:UnregisterAllEvents()
  NormalizeReminderSettings()
  local db = Addon.db.profile.movementWarning
  if self:IsEnabled() and db.enabled then
    EnsureDisplay()
    ApplyAnchor()
    RefreshSpellbook()
    RefreshSelectedSpells()
    for _, event in ipairs({
      "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
      "TRAIT_CONFIG_UPDATED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_ENABLED",
      "PLAYER_REGEN_DISABLED", "SPELL_UPDATE_COOLDOWN",
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
  self:RefreshOptionsPreview()
end

function MovementWarning:RefreshOptionsPreview()
  local root = optionsPreview
  if not root or not root:IsShown() then return end
  if not previewSpellID or not spellOptions[previewSpellID] then previewSpellID = knownSpells[1] end
  if not previewSpellID then
    root.title:SetText("No supported movement spells are currently known")
    root.sample:Hide()
    return
  end

  local config = Addon.db.profile.movementWarning.reminders[previewSpellID]
  local selected = GetSelectedSpells()
  local enabled = not selected or selected[previewSpellID] == true
  local fontKey, flags = ns.Theme.GetIconTextGlobal()
  local font = ns.LSM:Fetch("font", fontKey)
  local size = ns.Theme.ResolveFontSize(config.fontSize, "qualityOfLife")
  local countdownSize = ns.Theme.ResolveFontSize(config.countdownFontSize, "qualityOfLife")
  local iconMode = config.displayMode == "icon"
  local name = spellOptions[previewSpellID]
  root.title:SetText(name .. (enabled and "" or " (disabled)"))
  root.label:SetFont(font, size, flags)
  root.label:SetTextColor(config.color.r, config.color.g, config.color.b, config.color.a)
  root.label:SetText(config.showCountdown and ("No " .. name .. " for") or (name .. " unavailable"))
  root.countdown:SetFont(font, countdownSize, flags)
  root.countdown:SetTextColor(config.countdownColor.r, config.countdownColor.g, config.countdownColor.b, config.countdownColor.a)
  root.countdown:SetText(config.showDecimals and "8.0" or "8")
  root.countdown:SetShown(config.showCountdown)
  root.icon:SetTexture(C_Spell.GetSpellTexture(C_Spell.GetOverrideSpell(previewSpellID)))
  root.icon:SetSize(size, size)
  root.icon:SetShown(iconMode)
  root.label:SetShown(not iconMode)
  local gap = size * 0.2
  local width = (iconMode and size or root.label:GetStringWidth())
    + (config.showCountdown and (gap + root.countdown:GetStringWidth()) or 0)
  root.sample:SetSize(math.max(1, width), math.max(size, countdownSize) * 1.6)
  root.sample:SetScale(math.min(1, math.max(1, root:GetWidth() - 40) / math.max(1, width)))
  root.countdown:ClearAllPoints()
  root.countdown:SetPoint("LEFT", iconMode and root.icon or root.label, "RIGHT", gap, 0)
  root.sample:Show()
end

local function MovementWarning_BuildPreview(_, _, shell)
  local host = shell.previewHost
  if not optionsPreview then
    local root = CreateFrame("Frame", nil, host)
    optionsPreview = root
    root:EnableMouse(false)
    root.title = root:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    root.title:SetPoint("TOP", root, "TOP", 0, -12)
    root.sample = CreateFrame("Frame", nil, root)
    root.sample:SetPoint("CENTER", root, "CENTER", 0, 0)
    root.label = root.sample:CreateFontString(nil, "OVERLAY")
    root.label:SetPoint("LEFT", root.sample, "LEFT")
    root.icon = root.sample:CreateTexture(nil, "ARTWORK")
    root.icon:SetPoint("LEFT", root.sample, "LEFT")
    root.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    root.countdown = root.sample:CreateFontString(nil, "OVERLAY")
    local hint = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOM", root, "BOTTOM", 0, 12)
    hint:SetText("Sample countdown · Change any reminder to preview it")
  end
  optionsPreview:SetParent(host)
  optionsPreview:ClearAllPoints()
  optionsPreview:SetAllPoints(host)
  optionsPreview:Show()
  ns.Theme.ApplyFont(optionsPreview.title, "header")
  MovementWarning:RefreshOptionsPreview()
  return true
end

function MovementWarning:GetOptions()
  NormalizeReminderSettings()
  if not InCombatLockdown() then RefreshSpellbook() end
  if not previewSpellID or not spellOptions[previewSpellID] then previewSpellID = knownSpells[1] end
  local db = Addon.db.profile.movementWarning
  local options = {
    type = "group", name = "Movement Reminder", arg = { puiExplicit = true },
    args = {
      general = {
        type = "group", name = "General", inline = true, order = 10,
        args = {
          enabled = {
            type = "toggle", name = "Show movement reminders", order = 10,
            get = function() return db.enabled end,
            set = function(_, value)
              db.enabled = value
              self:ApplySettings()
              Addon:NotifyOptionsTreeChanged("MovementWarning", ns._PUIActiveOptionsPath)
            end,
          },
          preview = {
            type = "select", name = "Preview reminder", order = 20,
            values = function() return spellOptions end,
            disabled = function() return #knownSpells == 0 end,
            get = function() return previewSpellID end,
            set = function(_, value) previewSpellID = value; self:RefreshOptionsPreview() end,
          },
          onScreenPreview = {
            type = "toggle", name = "Show on-screen preview", order = 30,
            desc = "Show sample reminders at their live position. Use /pe to move them.",
            disabled = function() return not db.enabled end,
            get = function() return previewEnabled end,
            set = function(_, value) previewEnabled = value; self:RefreshWarning() end,
          },
        },
      },
    },
  }
  if #knownSpells == 0 then
    options.args.reminders = {
      type = "group", name = "Reminders", inline = true, order = 20,
      args = { help = { type = "description", name = "No supported movement spells are currently known for this specialization." } },
    }
  end
  for index = 1, #knownSpells do
    local spellID = knownSpells[index]
    local config = db.reminders[spellID]
    local function RefreshReminder()
      previewSpellID = spellID
      self:RefreshFonts()
      self:RefreshWarning()
    end
    local function ColorOption(label, field, order)
      return {
        type = "color", name = label, order = order, hasAlpha = true,
        get = function() local c = config[field]; return c.r, c.g, c.b, c.a end,
        set = function(_, r, g, b, a)
          local c = config[field]; c.r, c.g, c.b, c.a = r, g, b, a
          RefreshReminder()
        end,
      }
    end
    options.args["reminder" .. spellID] = {
      type = "group", name = spellOptions[spellID], inline = true, order = 20 + index,
      args = {
        enabled = {
          type = "toggle", name = "Show reminder", order = 10,
          desc = "Show this spell's reminder while the spell is unavailable.",
          get = function()
            local selected = GetSelectedSpells()
            return not selected or selected[spellID] == true
          end,
          set = function(_, value)
            local selected = GetSelectedSpells()
            if not selected then
              selected = {}
              for spellIndex = 1, #knownSpells do selected[knownSpells[spellIndex]] = true end
              db.spells[specializationID] = selected
            end
            selected[spellID] = value
            previewSpellID = spellID
            if self:IsEnabled() and db.enabled then
              RefreshSelectedSpells()
            else
              self:RefreshOptionsPreview()
            end
            self:RefreshWarning()
          end,
        },
        combatOnly = {
          type = "toggle", name = "Only show in combat", order = 20,
          get = function() return config.combatOnly end,
          set = function(_, value) config.combatOnly = value; RefreshReminder() end,
        },
        displayMode = {
          type = "select", name = "Display type", order = 30,
          values = { text = "Text", icon = "Icon" },
          get = function() return config.displayMode end,
          set = function(_, value) config.displayMode = value; RefreshReminder() end,
        },
        fontSize = {
          type = "range", name = "Font size", order = 40, min = 12, max = 64, step = 1,
          desc = "Size of this reminder's label or icon.",
          get = function() return config.fontSize end,
          set = function(_, value) config.fontSize = value; RefreshReminder() end,
        },
        color = ColorOption("Text color", "color", 50),
        showCountdown = {
          type = "toggle", name = "Show countdown", order = 60,
          get = function() return config.showCountdown end,
          set = function(_, value) config.showCountdown = value; RefreshReminder() end,
        },
        countdownFontSize = {
          type = "range", name = "Countdown font size", order = 70, min = 12, max = 64, step = 1,
          disabled = function() return not config.showCountdown end,
          get = function() return config.countdownFontSize end,
          set = function(_, value) config.countdownFontSize = value; RefreshReminder() end,
        },
        countdownColor = ColorOption("Countdown color", "countdownColor", 80),
        showDecimals = {
          type = "toggle", name = "Show decimals", order = 90,
          disabled = function() return not config.showCountdown end,
          get = function() return config.showDecimals end,
          set = function(_, value) config.showDecimals = value; RefreshReminder() end,
        },
      },
    }
    options.args["reminder" .. spellID].args.countdownColor.disabled = function() return not config.showCountdown end
    options.args["reminder" .. spellID].args.color.disabled = function() return config.displayMode == "icon" end
  end
  return options
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
      allowPreview = true,
      page = {
        previewAlwaysShown = true,
        previewWidth = 340,
        previewHeight = 190,
        tabsBeforeHeader = true,
        previewPathMatches = function() return true end,
        buildPreview = MovementWarning_BuildPreview,
      },
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
