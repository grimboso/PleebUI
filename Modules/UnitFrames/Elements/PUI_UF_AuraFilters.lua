local _, ns = ...

local AuraFilters = {}
ns.UFAuraFilters = AuraFilters

local C_CVar = _G.C_CVar
local UnitClassBase = _G.UnitClassBase
local math_floor = _G.math.floor
local math_huge = _G.math.huge
local math_max = _G.math.max
local pairs = _G.pairs
local sort = _G.table.sort
local table_concat = _G.table.concat
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type

local SATED_DEBUFFS = {
  [26013] = true,
  [57723] = true,
  [57724] = true,
  [71041] = true,
  [80354] = true,
  [95809] = true,
  [160455] = true,
  [264689] = true,
  [390435] = true,
}

local RAID_BUFFS_BY_CLASS = {
  DRUID = {
    [1126] = true,
  },
  EVOKER = {
    [364342] = true,
    [381732] = true,
    [381741] = true,
    [381746] = true,
    [381748] = true,
    [381749] = true,
    [381750] = true,
    [381751] = true,
    [381752] = true,
    [381753] = true,
    [381754] = true,
    [381756] = true,
    [381757] = true,
    [381758] = true,
  },
  MAGE = {
    [1459] = true,
  },
  PRIEST = {
    [21562] = true,
  },
  SHAMAN = {
    [462854] = true,
  },
  WARRIOR = {
    [6673] = true,
  },
}

local DISPLAY_TYPES = {
  group = true,
  slot = true,
}

local AURA_TYPES = {
  HELPFUL = true,
  HARMFUL = true,
}

local BUILT_IN_DISPLAY_IDS = {
  DEFAULT_BUFF = 1000001,
  DEFENSIVES_EXTERNALS = 1000002,
  DEFAULT_DEBUFF = 1000003,
  IMPORTANT_BUFFS = 1000004,
}

local USER_DISPLAY_ID_LIMIT = 999999

AuraFilters.BUILT_IN_DISPLAY_IDS = BUILT_IN_DISPLAY_IDS

local SPELL_FILTER_MODES = {
  NONE = true,
  WHITELIST = true,
  BLACKLIST = true,
  BOTH = true,
}

local HELPFUL_FILTER_PRESETS = {
  DEFAULT = true,
  RAID = true,
  RAID_IN_COMBAT = true,
  CROWD_CONTROL = true,
  BIG_DEFENSIVE = true,
  EXTERNAL_DEFENSIVE = true,
  RAID_PLAYER_DISPELLABLE = true,
  DISPELLABLE = true,
  IMPORTANT = true,
  CANCELABLE = true,
}

local HARMFUL_FILTER_PRESETS = {
  DEFAULT = true,
  RAID = true,
  RAID_IN_COMBAT = true,
  CROWD_CONTROL = true,
  RAID_PLAYER_DISPELLABLE = true,
  DISPELLABLE = true,
}

local function CopyTable(source)
  local output = {}

  for key, value in pairs(source or {}) do
    if type(value) == "table" then
      output[key] = CopyTable(value)
    else
      output[key] = value
    end
  end

  return output
end

local function CopyMap(source)
  local output = {}

  for key, value in pairs(source or {}) do
    if value == true then
      output[key] = true
    end
  end

  return output
end

local function MergeMap(target, source)
  target = target or {}

  for key, value in pairs(source or {}) do
    if value == true then
      target[key] = true
    end
  end

  return target
end

function AuraFilters.NormalizeAuraDB(auraDB)
  auraDB = auraDB or {}

  auraDB.enabled = auraDB.enabled ~= false
  auraDB.showBuffs = auraDB.showBuffs ~= false
  auraDB.showDebuffs = auraDB.showDebuffs ~= false
  auraDB.onlyPlayerBuffs = auraDB.onlyPlayerBuffs == true
  auraDB.onlyPlayerDebuffs = auraDB.onlyPlayerDebuffs == true
  auraDB.hidePermanentBuffs = auraDB.hidePermanentBuffs == true
  auraDB.hidePermanentDebuffs = auraDB.hidePermanentDebuffs == true
  auraDB.debuffHideSated = auraDB.debuffHideSated == true
  auraDB.buffFilterMode = auraDB.buffFilterMode or "BLIZZARD"
  auraDB.debuffFilterMode = auraDB.debuffFilterMode or "BLIZZARD"
  auraDB.maxDuration = tonumber(auraDB.maxDuration) or 0

  auraDB.tooltips = auraDB.tooltips ~= false
  auraDB.buffTooltips = auraDB.buffTooltips ~= false
  auraDB.debuffTooltips = auraDB.debuffTooltips ~= false
  auraDB.clickThrough = auraDB.clickThrough == true
  auraDB.disableSwipe = auraDB.disableSwipe == true
  auraDB.disableCountdownText = auraDB.disableCountdownText == true

  auraDB.spacing = tonumber(auraDB.spacing) or 2
  auraDB.iconSize = tonumber(auraDB.iconSize) or 18
  auraDB.buffIconSize = tonumber(auraDB.buffIconSize) or auraDB.iconSize
  auraDB.debuffIconSize = tonumber(auraDB.debuffIconSize) or auraDB.iconSize
  auraDB.durationTextSize = tonumber(auraDB.durationTextSize) or 11
  auraDB.stackTextSize = tonumber(auraDB.stackTextSize) or 11
  auraDB.buffDurationTextSize = tonumber(auraDB.buffDurationTextSize) or auraDB.durationTextSize
  auraDB.buffDurationOutline = auraDB.buffDurationOutline or "OUTLINE"
  auraDB.buffDurationAnchor = auraDB.buffDurationAnchor or "TOPLEFT"
  auraDB.buffDurationXOffset = tonumber(auraDB.buffDurationXOffset) or 1
  auraDB.buffDurationYOffset = tonumber(auraDB.buffDurationYOffset) or -1
  auraDB.buffStackTextSize = tonumber(auraDB.buffStackTextSize) or auraDB.stackTextSize
  auraDB.buffStackOutline = auraDB.buffStackOutline or "OUTLINE"
  auraDB.buffStackAnchor = auraDB.buffStackAnchor or "BOTTOMRIGHT"
  auraDB.buffStackXOffset = tonumber(auraDB.buffStackXOffset) or -1
  auraDB.buffStackYOffset = tonumber(auraDB.buffStackYOffset) or 1
  auraDB.debuffDurationTextSize = tonumber(auraDB.debuffDurationTextSize) or auraDB.durationTextSize
  auraDB.debuffDurationOutline = auraDB.debuffDurationOutline or "OUTLINE"
  auraDB.debuffDurationAnchor = auraDB.debuffDurationAnchor or "TOPLEFT"
  auraDB.debuffDurationXOffset = tonumber(auraDB.debuffDurationXOffset) or 1
  auraDB.debuffDurationYOffset = tonumber(auraDB.debuffDurationYOffset) or -1
  auraDB.debuffStackTextSize = tonumber(auraDB.debuffStackTextSize) or auraDB.stackTextSize
  auraDB.debuffStackOutline = auraDB.debuffStackOutline or "OUTLINE"
  auraDB.debuffStackAnchor = auraDB.debuffStackAnchor or "BOTTOMRIGHT"
  auraDB.debuffStackXOffset = tonumber(auraDB.debuffStackXOffset) or -1
  auraDB.debuffStackYOffset = tonumber(auraDB.debuffStackYOffset) or 1

  auraDB.buffBorderSize = tonumber(auraDB.buffBorderSize) or 0
  auraDB.debuffBorderSize = tonumber(auraDB.debuffBorderSize) or 1
  auraDB.dispelBorderSize = tonumber(auraDB.dispelBorderSize) or 2
  auraDB.buffBorderColor = auraDB.buffBorderColor or { 0, 0, 0, 1 }
  auraDB.debuffBorderColor = auraDB.debuffBorderColor or { 0, 0, 0, 1 }

  auraDB.buffsPerRow = math_max(1, math_floor(tonumber(auraDB.buffsPerRow) or tonumber(auraDB.maxIcons) or 8))
  auraDB.buffsNumRows = math_max(1, math_floor(tonumber(auraDB.buffsNumRows) or 1))
  auraDB.buffsAttachTo = auraDB.buffsAttachTo or "FRAME"
  auraDB.buffsAnchorPoint = auraDB.buffsAnchorPoint or "TOPRIGHT"
  auraDB.buffsGrowthX = auraDB.buffsGrowthX or "LEFT"
  auraDB.buffsGrowthY = auraDB.buffsGrowthY or "DOWN"
  auraDB.buffsSortMethod = auraDB.buffsSortMethod or "INDEX"
  auraDB.buffsSortDirection = auraDB.buffsSortDirection or "ASCENDING"
  auraDB.buffsXOffset = tonumber(auraDB.buffsXOffset) or 0
  auraDB.buffsYOffset = tonumber(auraDB.buffsYOffset) or -6

  auraDB.debuffsPerRow = math_max(1, math_floor(tonumber(auraDB.debuffsPerRow) or tonumber(auraDB.maxIcons) or 8))
  auraDB.debuffsNumRows = math_max(1, math_floor(tonumber(auraDB.debuffsNumRows) or 1))
  auraDB.debuffsAttachTo = auraDB.debuffsAttachTo or "FRAME"
  auraDB.debuffsAnchorPoint = auraDB.debuffsAnchorPoint or "BOTTOMLEFT"
  auraDB.debuffsGrowthX = auraDB.debuffsGrowthX or "RIGHT"
  auraDB.debuffsGrowthY = auraDB.debuffsGrowthY or "UP"
  auraDB.debuffsSortMethod = auraDB.debuffsSortMethod or "INDEX"
  auraDB.debuffsSortDirection = auraDB.debuffsSortDirection or "ASCENDING"
  auraDB.debuffsXOffset = tonumber(auraDB.debuffsXOffset) or 0
  auraDB.debuffsYOffset = tonumber(auraDB.debuffsYOffset) or 6

  AuraFilters.NormalizeDisplays(auraDB)
  return auraDB
end

function AuraFilters.BuildFrameAuraDB(frame, unit)
  local unitFrames = ns.UnitFrames
  local profile = unitFrames.db.profile
  local globalAuras = profile.auras

  if not globalAuras or globalAuras.enabled == false then
    return AuraFilters.NormalizeAuraDB({ enabled = false })
  end

  if frame.__puiAuraDBBuilder then
    return AuraFilters.NormalizeAuraDB(CopyTable(frame.__puiAuraDBBuilder(unit)))
  end

  local output = CopyTable(globalAuras)
  local unitConfig = unitFrames:GetConfigUnit(unit)
  local unitAuras = unitConfig and unitConfig.auras

  for key, value in pairs(unitAuras or {}) do
    if type(value) == "table" then
      output[key] = CopyTable(value)
    else
      output[key] = value
    end
  end

  return AuraFilters.NormalizeAuraDB(output)
end

function AuraFilters.BuildGroupedAuraDB(kind, db, unit)
  if kind == "party" and type(unit) == "string" and unit:find("partypet", 1, true) then
    local petDB = db and db.partyPets
    if not petDB or petDB.trackAuras ~= true then
      return AuraFilters.NormalizeAuraDB({
        enabled = false,
        showBuffs = false,
        showDebuffs = false,
        kind = kind,
        unit = unit,
      })
    end
  end

  local auraDB = db and db.auras or {}
  auraDB.kind = kind
  AuraFilters.NormalizeDisplays(auraDB)

  local output = CopyTable(auraDB)
  local activeLayout

  if db and db.orientation == "HORIZONTAL" then
    activeLayout = auraDB.horizontalLayout
  else
    activeLayout = auraDB.verticalLayout
  end

  for key, value in pairs(activeLayout or {}) do
    if type(value) == "table" then
      output[key] = CopyTable(value)
    else
      output[key] = value
    end
  end

  output.kind = kind
  output.unit = unit
  return AuraFilters.NormalizeAuraDB(output)
end

function AuraFilters.NormalizeSpellIDs(value)
  local output = {}

  if type(value) == "number" then
    local spellID = math_floor(value)
    if spellID > 0 then
      output[spellID] = true
    end
    return output
  end

  if type(value) == "string" then
    for token in value:gmatch("%d+") do
      local spellID = tonumber(token)
      if spellID and spellID > 0 then
        output[math_floor(spellID)] = true
      end
    end
    return output
  end

  if type(value) ~= "table" then
    return output
  end

  for key, entry in pairs(value) do
    local spellID

    if entry == true then
      spellID = tonumber(key)
    elseif type(key) == "number" then
      spellID = tonumber(entry)
    end

    if spellID and spellID > 0 then
      output[math_floor(spellID)] = true
    end
  end

  return output
end

function AuraFilters.SpellIDsToText(value)
  local values = {}

  for spellID in pairs(AuraFilters.NormalizeSpellIDs(value)) do
    values[#values + 1] = spellID
  end

  sort(values)

  for index = 1, #values do
    values[index] = tostring(values[index])
  end

  return table_concat(values, ", ")
end

function AuraFilters.CreateDisplay(id)
  id = math_floor(tonumber(id) or 1)
  if id < 1 then
    id = 1
  end

  return {
    id = id,
    enabled = true,
    name = "Aura Group " .. tostring(id),
    displayType = "group",
    auraType = "HELPFUL",
    filterPreset = "DEFAULT",
    spellFilterMode = "NONE",
    includeSpellIDs = {},
    excludeSpellIDs = {},
    onlyPlayer = false,
    bossAura = false,
    bossOrRoleAura = false,
    priorityAura = false,
    stealable = false,
    hidePermanent = false,
    hideRaidBuff = false,
    hideSated = false,
    maxDuration = 0,
    attachTo = "FRAME",
    anchorPoint = "TOPLEFT",
    relativePoint = "TOPLEFT",
    growthX = "RIGHT",
    growthY = "DOWN",
    xOffset = 0,
    yOffset = 0,
    iconSize = 20,
    autoIconSize = false,
    autoIconSizeMode = nil,
    spacing = 2,
    maxIcons = 4,
    sortMethod = "TIME_REMAINING",
    sortDirection = "ASCENDING",
    appearanceOverrides = {},
  }
end

function AuraFilters.BuildLegacyAppearance(auraDB, auraType)
  auraDB = auraDB or {}

  local harmful = auraType == "HARMFUL"
  local prefix = harmful and "debuff" or "buff"

  return {
    tooltips = auraDB.tooltips ~= false and auraDB[prefix .. "Tooltips"] ~= false,
    clickThrough = auraDB.clickThrough == true,
    disableSwipe = auraDB.disableSwipe == true,
    disableCountdownText = auraDB.disableCountdownText == true,
    borderSize = tonumber(auraDB[prefix .. "BorderSize"]) or (harmful and 1 or 0),
    borderColor = CopyTable(auraDB[prefix .. "BorderColor"] or { 0, 0, 0, 1 }),
    dispelBorderSize = tonumber(auraDB.dispelBorderSize) or 2,
    durationTextSize = tonumber(auraDB[prefix .. "DurationTextSize"] or auraDB.durationTextSize) or 11,
    durationFont = auraDB[prefix .. "DurationFont"],
    durationOutline = auraDB[prefix .. "DurationOutline"] or "OUTLINE",
    durationAnchor = auraDB[prefix .. "DurationAnchor"] or "TOPLEFT",
    durationXOffset = tonumber(auraDB[prefix .. "DurationXOffset"]) or 1,
    durationYOffset = tonumber(auraDB[prefix .. "DurationYOffset"]) or -1,
    stackTextSize = tonumber(auraDB[prefix .. "StackTextSize"] or auraDB.stackTextSize) or 11,
    stackFont = auraDB[prefix .. "StackFont"],
    stackOutline = auraDB[prefix .. "StackOutline"] or "OUTLINE",
    stackAnchor = auraDB[prefix .. "StackAnchor"] or "BOTTOMRIGHT",
    stackXOffset = tonumber(auraDB[prefix .. "StackXOffset"]) or -1,
    stackYOffset = tonumber(auraDB[prefix .. "StackYOffset"]) or 1,
  }
end

local function MergeAppearance(base, overrides)
  local output = CopyTable(base)

  for key, value in pairs(overrides or {}) do
    if type(value) == "table" then
      output[key] = CopyTable(value)
    else
      output[key] = value
    end
  end

  return output
end

local function NormalizeSingleSpellID(value)
  local normalized = AuraFilters.NormalizeSpellIDs(value)
  local selectedSpellID

  for spellID in pairs(normalized) do
    if not selectedSpellID or spellID < selectedSpellID then
      selectedSpellID = spellID
    end
  end

  if selectedSpellID then
    return {
      [selectedSpellID] = true,
    }
  end

  return {}
end

local function CreateDefaultBuffDisplay(auraDB)
  local display = AuraFilters.CreateDisplay(BUILT_IN_DISPLAY_IDS.DEFAULT_BUFF)
  local grouped = auraDB.kind == "party" or auraDB.kind == "raid"
  local perRow = tonumber(auraDB.buffsPerRow or auraDB.maxIcons) or 8
  local rows = tonumber(auraDB.buffsNumRows) or 1

  display.builtInKey = "DEFAULT_BUFF"
  display.protected = true
  display.order = 100
  display.name = "Default Buff Group"
  display.enabled = auraDB.showBuffs ~= false and auraDB.buffFilterMode ~= "NONE"
  display.auraType = "HELPFUL"
  display.filterPreset = grouped and "RAID_IN_COMBAT" or "DEFAULT"
  display.onlyPlayer = grouped or auraDB.onlyPlayerBuffs == true or auraDB.buffFilterMode == "PLAYER"
  display.hidePermanent = grouped or auraDB.hidePermanentBuffs == true
  display.hideRaidBuff = grouped
  display.maxDuration = tonumber(auraDB.maxDuration) or 0
  display.attachTo = "FRAME"
  display.anchorPoint = auraDB.buffsAnchorPoint or "TOPRIGHT"
  display.relativePoint = auraDB.buffsRelativePoint or display.anchorPoint
  display.growthX = auraDB.buffsGrowthX or "LEFT"
  display.growthY = auraDB.buffsGrowthY or "DOWN"
  display.xOffset = tonumber(auraDB.buffsXOffset) or 0
  display.yOffset = tonumber(auraDB.buffsYOffset) or -6
  display.iconSize = tonumber(auraDB.buffIconSize or auraDB.iconSize) or 18
  display.spacing = tonumber(auraDB.spacing) or 2
  display.maxIcons = math_floor(perRow * rows)
  display.sortMethod = auraDB.buffsSortMethod or "INDEX"
  display.sortDirection = auraDB.buffsSortDirection or "ASCENDING"
  display.appearance = AuraFilters.BuildLegacyAppearance(auraDB, "HELPFUL")
  return display
end

local function CreateDefensivesAndExternalsDisplay(auraDB)
  local display = AuraFilters.CreateDisplay(BUILT_IN_DISPLAY_IDS.DEFENSIVES_EXTERNALS)
  local iconSize = auraDB.kind == "raid" and 30 or 20

  display.builtInKey = "DEFENSIVES_EXTERNALS"
  display.specialType = "DEFENSIVES_EXTERNALS"
  display.protected = true
  display.order = 200
  display.name = "Defensives and Externals"
  display.displayType = "slot"
  display.enabled = true
  display.showDefensives = true
  display.showExternals = true
  display.auraType = "HELPFUL"
  display.filterPreset = "BIG_DEFENSIVE"
  display.attachTo = "FRAME"
  display.anchorPoint = "CENTER"
  display.relativePoint = "CENTER"
  display.growthX = "RIGHT"
  display.growthY = "DOWN"
  display.xOffset = 0
  display.yOffset = 0
  display.iconSize = iconSize
  display.spacing = 2
  display.maxIcons = 1
  display.sortMethod = "BIG_DEFENSIVE"
  display.sortDirection = "ASCENDING"
  display.appearanceOverrides = {
    tooltips = true,
  }
  return display
end

local function CreateImportantBuffsDisplay(auraDB)
  local display = AuraFilters.CreateDisplay(BUILT_IN_DISPLAY_IDS.IMPORTANT_BUFFS)
  local iconSize = auraDB.kind == "raid" and 20 or 24

  display.builtInKey = "IMPORTANT_BUFFS"
  display.specialType = "IMPORTANT_BUFFS"
  display.protected = true
  display.order = 300
  display.name = "Offensive Cooldowns"
  display.displayType = "slot"
  display.enabled = true
  display.auraType = "HELPFUL"
  display.filterPreset = "IMPORTANT"
  display.attachTo = "FRAME"
  display.anchorPoint = "TOPRIGHT"
  display.relativePoint = "TOPRIGHT"
  display.growthX = "LEFT"
  display.growthY = "DOWN"
  display.xOffset = -2
  display.yOffset = -2
  display.iconSize = iconSize
  display.spacing = 2
  display.maxIcons = 1
  display.sortMethod = "TIME_REMAINING"
  display.sortDirection = "ASCENDING"
  display.appearanceOverrides = {
    tooltips = true,
  }
  return display
end

local function CreateDefaultDebuffDisplay(auraDB)
  local display = AuraFilters.CreateDisplay(BUILT_IN_DISPLAY_IDS.DEFAULT_DEBUFF)
  local perRow = tonumber(auraDB.debuffsPerRow or auraDB.maxIcons) or 8
  local rows = tonumber(auraDB.debuffsNumRows) or 1

  display.builtInKey = "DEFAULT_DEBUFF"
  display.protected = true
  display.order = 1100
  display.name = "Default Debuff Group"
  display.enabled = auraDB.showDebuffs ~= false and auraDB.debuffFilterMode ~= "NONE"
  display.auraType = "HARMFUL"
  display.filterPreset = "DEFAULT"
  display.onlyPlayer = auraDB.onlyPlayerDebuffs == true or auraDB.debuffFilterMode == "PLAYER"
  display.includeBossAuras = auraDB.defaultDebuffsIncludeBossAuras == true
  display.hidePermanent = auraDB.hidePermanentDebuffs == true
  display.hideSated = auraDB.debuffHideSated == true
  display.maxDuration = tonumber(auraDB.maxDuration) or 0
  display.attachTo = "FRAME"
  display.anchorPoint = auraDB.debuffsAnchorPoint or "BOTTOMLEFT"
  display.relativePoint = auraDB.debuffsRelativePoint or display.anchorPoint
  display.growthX = auraDB.debuffsGrowthX or "RIGHT"
  display.growthY = auraDB.debuffsGrowthY or "UP"
  display.xOffset = tonumber(auraDB.debuffsXOffset) or 0
  display.yOffset = tonumber(auraDB.debuffsYOffset) or 6
  display.iconSize = tonumber(auraDB.debuffIconSize or auraDB.iconSize) or 18
  display.spacing = tonumber(auraDB.spacing) or 2
  display.maxIcons = math_floor(perRow * rows)
  display.sortMethod = auraDB.debuffsSortMethod or "INDEX"
  display.sortDirection = auraDB.debuffsSortDirection or "ASCENDING"
  display.appearance = AuraFilters.BuildLegacyAppearance(auraDB, "HARMFUL")
  return display
end

function AuraFilters.ResetBuiltInDisplay(auraDB, builtInKey, defaultAuraDB)
  if type(auraDB) ~= "table" or type(defaultAuraDB) ~= "table" then
    return false
  end

  local source = CopyTable(defaultAuraDB)
  source.kind = auraDB.kind or source.kind

  local display
  local displayID

  if builtInKey == "DEFAULT_BUFF" then
    displayID = BUILT_IN_DISPLAY_IDS.DEFAULT_BUFF
    display = CreateDefaultBuffDisplay(source)
  elseif builtInKey == "DEFENSIVES_EXTERNALS" then
    displayID = BUILT_IN_DISPLAY_IDS.DEFENSIVES_EXTERNALS
    display = CreateDefensivesAndExternalsDisplay(source)
  elseif builtInKey == "IMPORTANT_BUFFS" then
    displayID = BUILT_IN_DISPLAY_IDS.IMPORTANT_BUFFS
    display = CreateImportantBuffsDisplay(source)
  elseif builtInKey == "DEFAULT_DEBUFF" then
    displayID = BUILT_IN_DISPLAY_IDS.DEFAULT_DEBUFF
    display = CreateDefaultDebuffDisplay(source)
  else
    return false
  end

  auraDB.customDisplays = type(auraDB.customDisplays) == "table" and auraDB.customDisplays or {}
  auraDB.customDisplays[displayID] = AuraFilters.NormalizeDisplay(display, displayID)
  auraDB.selectedCustomDisplayID = displayID
  return true
end

function AuraFilters.NormalizeDisplay(display, id)
  if type(display) ~= "table" then
    display = AuraFilters.CreateDisplay(id)
  end

  display.id = math_floor(tonumber(display.id) or tonumber(id) or 1)
  if display.id < 1 then
    display.id = 1
  end

  display.enabled = display.enabled ~= false
  display.displayType = DISPLAY_TYPES[display.displayType] and display.displayType or "group"
  display.auraType = AURA_TYPES[display.auraType] and display.auraType or "HELPFUL"
  display.spellFilterMode = SPELL_FILTER_MODES[display.spellFilterMode] and display.spellFilterMode or "NONE"
  display.protected = display.builtInKey ~= nil

  local defaultOrder = display.auraType == "HARMFUL"
    and (1200 + display.id)
    or (300 + display.id)
  display.order = tonumber(display.order) or defaultOrder

  if display.builtInKey == "DEFAULT_BUFF" then
    display.name = "Default Buff Group"
    display.displayType = "group"
    display.auraType = "HELPFUL"
    display.order = 100
  elseif display.builtInKey == "DEFENSIVES_EXTERNALS" then
    display.name = "Defensives and Externals"
    display.displayType = "slot"
    display.auraType = "HELPFUL"
    display.specialType = "DEFENSIVES_EXTERNALS"
    display.order = 200
    display.showDefensives = display.showDefensives ~= false
    display.showExternals = display.showExternals ~= false
    display.filterPreset = "BIG_DEFENSIVE"
    display.spellFilterMode = "NONE"
    display.includeSpellIDs = {}
    display.excludeSpellIDs = {}
    display.onlyPlayer = false
    display.bossAura = false
    display.bossOrRoleAura = false
    display.priorityAura = false
    display.stealable = false
    display.hidePermanent = false
    display.hideRaidBuff = false
    display.hideSated = false
    display.maxDuration = 0
    display.anchorPoint = display.anchorPoint or "CENTER"
    display.relativePoint = display.anchorPoint
    display.growthX = "RIGHT"
    display.growthY = "DOWN"
    display.maxIcons = 1
    display.sortMethod = "BIG_DEFENSIVE"
    display.sortDirection = "ASCENDING"
    display.appearanceOverrides = type(display.appearanceOverrides) == "table"
      and display.appearanceOverrides
      or {}

    if display.appearanceOverrides.tooltips == nil then
      display.appearanceOverrides.tooltips = true
    end
  elseif display.builtInKey == "IMPORTANT_BUFFS" then
    display.name = "Offensive Cooldowns"
    display.displayType = "slot"
    display.auraType = "HELPFUL"
    display.specialType = "IMPORTANT_BUFFS"
    display.order = 300
    display.filterPreset = "IMPORTANT"
    display.spellFilterMode = "NONE"
    display.includeSpellIDs = {}
    display.excludeSpellIDs = {}
    display.onlyPlayer = false
    display.bossAura = false
    display.bossOrRoleAura = false
    display.priorityAura = false
    display.stealable = false
    display.hidePermanent = false
    display.hideRaidBuff = false
    display.hideSated = false
    display.maxDuration = 0
    display.maxIcons = 1
    display.appearanceOverrides = type(display.appearanceOverrides) == "table"
      and display.appearanceOverrides
      or {}

    if display.appearanceOverrides.tooltips == nil then
      display.appearanceOverrides.tooltips = true
    end
  elseif display.builtInKey == "DEFAULT_DEBUFF" then
    display.name = "Default Debuff Group"
    display.displayType = "group"
    display.auraType = "HARMFUL"
    display.specialType = nil
    display.order = 1100
    display.filterPreset = "DEFAULT"
    display.spellFilterMode = display.spellFilterMode == "BLACKLIST" and "BLACKLIST" or "NONE"
    display.includeSpellIDs = {}
    display.excludeSpellIDs = AuraFilters.NormalizeSpellIDs(display.excludeSpellIDs)
    display.bossAura = false
    display.bossOrRoleAura = false
    display.priorityAura = false
    display.stealable = false
    display.hideRaidBuff = false
  else
    local prefix = display.displayType == "slot" and "Aura Slot " or "Aura Group "
    display.name = prefix .. tostring(display.id)
  end

  local usesBuiltInSlotFilter = display.builtInKey == "DEFENSIVES_EXTERNALS"
    or display.builtInKey == "IMPORTANT_BUFFS"

  if display.displayType == "slot" and not usesBuiltInSlotFilter then
    display.filterPreset = "DEFAULT"
    display.spellFilterMode = "WHITELIST"
    display.includeSpellIDs = NormalizeSingleSpellID(display.includeSpellIDs)
    display.excludeSpellIDs = {}
    display.maxIcons = 1
  elseif display.displayType == "group" then
    local presets = display.auraType == "HARMFUL" and HARMFUL_FILTER_PRESETS or HELPFUL_FILTER_PRESETS
    display.filterPreset = presets[display.filterPreset] and display.filterPreset or "DEFAULT"
    display.includeSpellIDs = AuraFilters.NormalizeSpellIDs(display.includeSpellIDs)
    display.excludeSpellIDs = AuraFilters.NormalizeSpellIDs(display.excludeSpellIDs)
  end
  display.onlyPlayer = display.onlyPlayer == true
  display.includeBossAuras = display.includeBossAuras == true
  display.bossAura = display.bossAura == true
  display.bossOrRoleAura = display.bossOrRoleAura == true
  display.priorityAura = display.priorityAura == true
  display.stealable = display.stealable == true
  display.hidePermanent = display.hidePermanent == true
  display.hideRaidBuff = display.hideRaidBuff == true
  display.hideSated = display.hideSated == true

  if display.builtInKey == "DEFENSIVES_EXTERNALS" then
    display.autoIconSize = false
    display.autoIconSizeMode = nil
  else
    display.autoIconSize = display.autoIconSize == true

    if display.autoIconSizeMode ~= "HEALTH" then
      display.autoIconSizeMode = "DEFENSIVE"
    end
  end

  display.maxDuration = tonumber(display.maxDuration) or 0
  if display.maxDuration < 0 then
    display.maxDuration = 0
  end

  display.attachTo = "FRAME"
  display.anchorPoint = display.anchorPoint or "TOPLEFT"
  display.relativePoint = display.relativePoint or display.anchorPoint
  display.growthX = display.growthX == "LEFT" and "LEFT" or "RIGHT"
  display.growthY = display.growthY == "UP" and "UP" or "DOWN"
  display.xOffset = tonumber(display.xOffset) or 0
  display.yOffset = tonumber(display.yOffset) or 0

  display.iconSize = math_floor(tonumber(display.iconSize) or 20)
  if display.iconSize < 8 then
    display.iconSize = 8
  elseif display.iconSize > 64 then
    display.iconSize = 64
  end

  display.spacing = math_floor(tonumber(display.spacing) or 2)
  if display.spacing < 0 then
    display.spacing = 0
  elseif display.spacing > 20 then
    display.spacing = 20
  end

  display.maxIcons = math_floor(tonumber(display.maxIcons) or 4)
  if display.maxIcons < 1 then
    display.maxIcons = 1
  elseif display.maxIcons > 40 then
    display.maxIcons = 40
  end

  display.sortMethod = display.sortMethod or "TIME_REMAINING"
  display.sortDirection = display.sortDirection or "ASCENDING"
  display.appearance = type(display.appearance) == "table" and display.appearance or nil
  display.appearanceOverrides = type(display.appearanceOverrides) == "table" and display.appearanceOverrides or {}

  return display
end

function AuraFilters.NormalizeDisplays(auraDB)
  auraDB = auraDB or {}

  local displays = type(auraDB.customDisplays) == "table" and auraDB.customDisplays or {}
  local output = {}
  local highestUserID = 0

  for key, display in pairs(displays) do
    local id = tonumber(type(display) == "table" and display.id or key)
    if id and id > 0 then
      id = math_floor(id)
      output[id] = AuraFilters.NormalizeDisplay(display, id)

      if id <= USER_DISPLAY_ID_LIMIT and id > highestUserID then
        highestUserID = id
      end
    end
  end

  local defaultBuffID = BUILT_IN_DISPLAY_IDS.DEFAULT_BUFF
  local defaultBuff = output[defaultBuffID] or CreateDefaultBuffDisplay(auraDB)
  defaultBuff.builtInKey = "DEFAULT_BUFF"
  defaultBuff.protected = true
  output[defaultBuffID] = defaultBuff

  local defensivesID = BUILT_IN_DISPLAY_IDS.DEFENSIVES_EXTERNALS
  local importantBuffsID = BUILT_IN_DISPLAY_IDS.IMPORTANT_BUFFS
  if auraDB.kind == "party" or auraDB.kind == "raid" then
    local defensives = output[defensivesID] or CreateDefensivesAndExternalsDisplay(auraDB)
    defensives.builtInKey = "DEFENSIVES_EXTERNALS"
    defensives.specialType = "DEFENSIVES_EXTERNALS"
    defensives.protected = true
    output[defensivesID] = defensives

    local importantBuffs = output[importantBuffsID] or CreateImportantBuffsDisplay(auraDB)

    importantBuffs.builtInKey = "IMPORTANT_BUFFS"
    importantBuffs.specialType = "IMPORTANT_BUFFS"
    importantBuffs.protected = true
    output[importantBuffsID] = importantBuffs
  else
    output[defensivesID] = nil
    output[importantBuffsID] = nil
  end

  local defaultDebuffID = BUILT_IN_DISPLAY_IDS.DEFAULT_DEBUFF
  local defaultDebuff = output[defaultDebuffID] or CreateDefaultDebuffDisplay(auraDB)
  if defaultDebuff.includeBossAuras == nil then
    defaultDebuff.includeBossAuras = auraDB.defaultDebuffsIncludeBossAuras == true
  end
  defaultDebuff.builtInKey = "DEFAULT_DEBUFF"
  defaultDebuff.protected = true
  output[defaultDebuffID] = defaultDebuff

  for id, display in pairs(output) do
    output[id] = AuraFilters.NormalizeDisplay(display, id)
  end

  auraDB.customDisplays = output
  auraDB.nextCustomDisplayID = math_floor(
    tonumber(auraDB.nextCustomDisplayID) or (highestUserID + 1)
  )

  if auraDB.nextCustomDisplayID <= highestUserID
    or auraDB.nextCustomDisplayID > USER_DISPLAY_ID_LIMIT
  then
    auraDB.nextCustomDisplayID = highestUserID + 1
  end

  local selectedID = tonumber(auraDB.selectedCustomDisplayID)
  if not selectedID or not output[selectedID] then
    selectedID = BUILT_IN_DISPLAY_IDS.DEFAULT_BUFF
  end
  auraDB.selectedCustomDisplayID = selectedID

  return output
end

function AuraFilters.BuildEffectiveAppearance(auraDB, display)
  local defaultID = display.auraType == "HARMFUL"
    and BUILT_IN_DISPLAY_IDS.DEFAULT_DEBUFF
    or BUILT_IN_DISPLAY_IDS.DEFAULT_BUFF
  local defaultDisplay = auraDB.customDisplays and auraDB.customDisplays[defaultID]
  local fallback = AuraFilters.BuildLegacyAppearance(auraDB, display.auraType)
  local base = defaultDisplay and defaultDisplay.appearance
    and MergeAppearance(fallback, defaultDisplay.appearance)
    or fallback
  local appearance

  if display.id == defaultID then
    display.appearance = MergeAppearance(base, display.appearance)
    appearance = display.appearance
  else
    appearance = MergeAppearance(base, display.appearanceOverrides)
  end

  if auraDB.tooltips == false then
    appearance.tooltips = false
  end

  return appearance
end

function AuraFilters.BuildFilterString(display)
  display = AuraFilters.NormalizeDisplay(display, display and display.id)

  if display.builtInKey == "DEFENSIVES_EXTERNALS" then
    if display.showDefensives == false then
      return "HELPFUL|EXTERNAL_DEFENSIVE"
    elseif display.showExternals == false then
      return "HELPFUL|BIG_DEFENSIVE|!EXTERNAL_DEFENSIVE"
    end

    return "HELPFUL|BIG_DEFENSIVE"
  elseif display.builtInKey == "IMPORTANT_BUFFS" then
    return "HELPFUL|IMPORTANT|!BIG_DEFENSIVE|!EXTERNAL_DEFENSIVE"
  end

  local filters = {
    display.auraType,
  }

  if display.filterPreset ~= "DEFAULT" then
    filters[#filters + 1] = display.filterPreset
  end

  if display.onlyPlayer then
    filters[#filters + 1] = "PLAYER"
  end

  return table_concat(filters, "|")
end

local function AppendMapSignature(parts, prefix, source)
  local keys = {}

  for key, enabled in pairs(source or {}) do
    if enabled == true then
      keys[#keys + 1] = key
    end
  end

  sort(keys, function(left, right)
    return tostring(left) < tostring(right)
  end)

  for index = 1, #keys do
    parts[#parts + 1] = prefix .. tostring(keys[index])
  end
end

function AuraFilters.BuildCandidateFilterSignature(display)
  display = AuraFilters.NormalizeDisplay(display, display and display.id)

  local parts = {
    tostring(display.spellFilterMode),
    tostring(display.maxDuration),
    display.hidePermanent and "permanent:1" or "permanent:0",
    display.hideRaidBuff and "raid:1" or "raid:0",
    display.hideSated and "sated:1" or "sated:0",
    display.bossAura and "boss:1" or "boss:0",
    display.bossOrRoleAura and "bossrole:1" or "bossrole:0",
    display.priorityAura and "priority:1" or "priority:0",
    display.stealable and "stealable:1" or "stealable:0",
    display.includeBossAuras and "bossunion:1" or "bossunion:0",
  }

  if display.hideRaidBuff then
    parts[#parts + 1] = "class:" .. tostring(UnitClassBase("player"))
  end

  AppendMapSignature(parts, "include:", display.includeSpellIDs)
  AppendMapSignature(parts, "exclude:", display.excludeSpellIDs)

  return table_concat(parts, "\31")
end

function AuraFilters.BuildCandidateFilters(display)
  display = AuraFilters.NormalizeDisplay(display, display and display.id)

  local filters = {}
  local mode = display.spellFilterMode

  if mode == "WHITELIST" or mode == "BOTH" then
    filters.includeSpellIDs = CopyMap(display.includeSpellIDs)
  end

  if mode == "BLACKLIST" or mode == "BOTH" then
    filters.excludeSpellIDs = CopyMap(display.excludeSpellIDs)
  end

  if display.maxDuration > 0 then
    filters.maxDuration = display.maxDuration
  elseif display.hidePermanent then
    filters.maxDuration = math_huge
  end

  if display.hideRaidBuff then
    local classBuffs = RAID_BUFFS_BY_CLASS[UnitClassBase("player")]
    if classBuffs then
      filters.excludeSpellIDs = MergeMap(filters.excludeSpellIDs, classBuffs)
    end
  end

  if display.hideSated then
    filters.excludeSpellIDs = MergeMap(filters.excludeSpellIDs, SATED_DEBUFFS)
  end

  if display.bossAura then
    filters.isBossAura = true
  elseif display.bossOrRoleAura then
    filters.isBossOrRoleAura = true
  end

  if display.priorityAura then
    filters.isPriorityAura = true
  end

  if display.stealable then
    filters.isStealable = true
  end

  return filters
end

function AuraFilters.BuildEncounterCandidateFilters(display)
  local filters = AuraFilters.BuildCandidateFilters(display)
  filters.isBossAura = true
  filters.isFromPlayerOrPlayerPet = false
  return filters
end


function AuraFilters.ApplyAuraSpellIDTooltipCVar(enabled)
  C_CVar.SetCVar("tooltipShowAuraSpellIDs", enabled and "1" or "0")
end

function AuraFilters.ApplyAuraSpellIDTooltipPreference(enabled)
  local optionsFrame = ns.Addon._OptionsWindow
  AuraFilters.ApplyAuraSpellIDTooltipCVar(
    optionsFrame and optionsFrame:IsShown() or enabled == true
  )
end

local P = select(1, ns.Pleebug:DropIn(AuraFilters, { name = "UnitFrames.AuraFilters" }))
AuraFilters.NormalizeAuraDB = P:Def("AuraFilters.NormalizeAuraDB", AuraFilters.NormalizeAuraDB)
AuraFilters.BuildFrameAuraDB = P:Def("AuraFilters.BuildFrameAuraDB", AuraFilters.BuildFrameAuraDB)
AuraFilters.BuildGroupedAuraDB = P:Def("AuraFilters.BuildGroupedAuraDB", AuraFilters.BuildGroupedAuraDB)
AuraFilters.NormalizeSpellIDs = P:Def("AuraFilters.NormalizeSpellIDs", AuraFilters.NormalizeSpellIDs)
AuraFilters.SpellIDsToText = P:Def("AuraFilters.SpellIDsToText", AuraFilters.SpellIDsToText)
AuraFilters.CreateDisplay = P:Def("AuraFilters.CreateDisplay", AuraFilters.CreateDisplay)
AuraFilters.BuildLegacyAppearance = P:Def("AuraFilters.BuildLegacyAppearance", AuraFilters.BuildLegacyAppearance)
AuraFilters.ResetBuiltInDisplay = P:Def("AuraFilters.ResetBuiltInDisplay", AuraFilters.ResetBuiltInDisplay)
AuraFilters.NormalizeDisplay = P:Def("AuraFilters.NormalizeDisplay", AuraFilters.NormalizeDisplay)
AuraFilters.NormalizeDisplays = P:Def("AuraFilters.NormalizeDisplays", AuraFilters.NormalizeDisplays)
AuraFilters.BuildEffectiveAppearance = P:Def("AuraFilters.BuildEffectiveAppearance", AuraFilters.BuildEffectiveAppearance)
AuraFilters.BuildFilterString = P:Def("AuraFilters.BuildFilterString", AuraFilters.BuildFilterString)
AuraFilters.BuildCandidateFilterSignature = P:Def("AuraFilters.BuildCandidateFilterSignature", AuraFilters.BuildCandidateFilterSignature)
AuraFilters.BuildCandidateFilters = P:Def("AuraFilters.BuildCandidateFilters", AuraFilters.BuildCandidateFilters)
AuraFilters.BuildEncounterCandidateFilters = P:Def("AuraFilters.BuildEncounterCandidateFilters", AuraFilters.BuildEncounterCandidateFilters)
AuraFilters.ApplyAuraSpellIDTooltipCVar = P:Def("AuraFilters.ApplyAuraSpellIDTooltipCVar", AuraFilters.ApplyAuraSpellIDTooltipCVar)
AuraFilters.ApplyAuraSpellIDTooltipPreference = P:Def("AuraFilters.ApplyAuraSpellIDTooltipPreference", AuraFilters.ApplyAuraSpellIDTooltipPreference)
CopyTable = P:Def("AuraFilters.CopyTable", CopyTable)
CopyMap = P:Def("AuraFilters.CopyMap", CopyMap)
MergeMap = P:Def("AuraFilters.MergeMap", MergeMap)
AppendMapSignature = P:Def("AuraFilters.AppendMapSignature", AppendMapSignature)
MergeAppearance = P:Def("AuraFilters.MergeAppearance", MergeAppearance)
NormalizeSingleSpellID = P:Def("AuraFilters.NormalizeSingleSpellID", NormalizeSingleSpellID)
CreateDefaultBuffDisplay = P:Def("AuraFilters.CreateDefaultBuffDisplay", CreateDefaultBuffDisplay)
CreateDefensivesAndExternalsDisplay = P:Def("AuraFilters.CreateDefensivesAndExternalsDisplay", CreateDefensivesAndExternalsDisplay)
CreateImportantBuffsDisplay = P:Def("AuraFilters.CreateImportantBuffsDisplay", CreateImportantBuffsDisplay)
CreateDefaultDebuffDisplay = P:Def("AuraFilters.CreateDefaultDebuffDisplay", CreateDefaultDebuffDisplay)
