
-- File: PUI_UF_Config.lua
-- Purpose: UnitFrames options, AceConfig builders, and grouped config mutation helpers.


local ADDON_NAME, ns = ...



local LibStub  = _G.LibStub
local Addon    = ns.Addon
local LSM      = ns.LSM
local OptionsUtil = ns.OptionsUtil
local UF       = ns.UnitFrames
local CastBar  = ns.Modules.CastBar
local FrameUtil = ns.FrameUtil
local UFConfigDebug = ns.UFConfigDebug or {}
ns.UFConfigDebug = UFConfigDebug

local P, TrackThis = ns.Pleebug:DropIn(UFConfigDebug, { name = "UnitFrames.Config" })


local function GetCBUnitCfg(unit)
  if unit == "boss" then
    return CastBar.db.profile.boss
  end

  return CastBar:GetUnitConfig(unit)
end

local function UFCB_CopyTable(source)
  local output = {}

  for key, value in pairs(source or {}) do
    if type(value) == "table" then
      output[key] = UFCB_CopyTable(value)
    else
      output[key] = value
    end
  end

  return output
end

local lastCombatWarnTime = 0

local function WarnCombatLocked()
  local now = GetTime()
  if now > 0 and (now - lastCombatWarnTime) < 1.5 then
    -- A warning was shown very recently; skip to avoid chat spam.
    return
  end

  lastCombatWarnTime = now
  local msg = "Unit Frame and Cast Bar settings cannot be changed while in combat."
  Addon:Print(msg)
end

local TEXT_MODE_VALUES = {
  CUR         = "Show current value",
  CUR_MAX     = "Show current / max",
  PERCENT     = "Show percent",
  CUR_PERCENT = "Show current + percent",
  HIDE        = "Hide",
}
ns.UnitFrameHealthTextModeValues = TEXT_MODE_VALUES

local FONT_OUTLINE_VALUES = ns.Theme.GetOutlineList()

local TEXT_ANCHOR_VALUES = {
  LEFT         = "Left",
  RIGHT        = "Right",
  CENTER       = "Center",
  TOP          = "Top",
  BOTTOM       = "Bottom",
  TOPLEFT      = "Top left",
  TOPRIGHT     = "Top right",
  BOTTOMLEFT   = "Bottom left",
  BOTTOMRIGHT  = "Bottom right",
}

local PARTY_ANCHOR_VALUES = TEXT_ANCHOR_VALUES

local UNIT_AURA_VISIBILITY_VALUES = {
  ALL = "Show all",
  PLAYER = "Only player applied",
  NONE = "Show none",
}

local PORTRAIT_STYLE_VALUES = {
  ["2D"] = "2D",
  ["3D"] = "3D",
}

local PORTRAIT_SIDE_VALUES = {
  LEFT = "Left",
  RIGHT = "Right",
}

local PORTRAIT_UNIT_KEYS = {
  "player",
  "target",
  "focus",
  "boss",
}

ns.UnitFrameAuraAnchorValues = PARTY_ANCHOR_VALUES
ns.UnitFrameAuraVisibilityValues = UNIT_AURA_VISIBILITY_VALUES


local MOUSEOVER_HIGHLIGHT_MODE_VALUES = {
  FRAME = "Frame glow",
  BORDER = "Health overlay",
  BOTH = "Both",
}

local THREAT_INDICATOR_STYLE_VALUES = {
  FRAME_GLOW = "Frame glow",
  BORDER_GLOW = "Border glow",
  BOTH = "Both",
}

local UFCB_RequestGroupedRefresh

local function UFCB_RefreshUFTextures()
  Addon:ApplyOptionsChange("UnitFrames", { textures = true })
  UFCB_RequestGroupedRefresh("party", false, { textures = true })
  UFCB_RequestGroupedRefresh("raid", false, { textures = true })
end

local function UFCB_RefreshUFMouseover()
  Addon:ApplyOptionsChange("UnitFrames", { mouseover = true })
  UFCB_RequestGroupedRefresh("party", false, { mouseover = true })
  UFCB_RequestGroupedRefresh("raid", false, { mouseover = true })
end

local function UFCB_RefreshUFHealthPrediction()
  Addon:ApplyOptionsChange("UnitFrames", { mode = "healthPrediction" })
  UFCB_RequestGroupedRefresh("party", false, { healthPrediction = true })
  UFCB_RequestGroupedRefresh("raid", false, { healthPrediction = true })
end

local function UFCB_RefreshUFTargetHighlight()
  UFCB_RequestGroupedRefresh("party", false, { targetHighlight = true })
  UFCB_RequestGroupedRefresh("raid", false, { targetHighlight = true })
end

local function UFCB_RefreshUFAuras(flags)
  if type(flags) == "table" then
    flags.auras = true
  else
    flags = { auras = true }
  end

  Addon:ApplyOptionsChange("UnitFrames", flags)
end

local function UFCB_RefreshUFText()
  Addon:ApplyOptionsChange("UnitFrames", { mode = "text" })
  UFCB_RequestGroupedRefresh("party", false, { text = true })
  UFCB_RequestGroupedRefresh("raid", false, { text = true })
end

local function CB_RefreshUnit(unit, extraFlags)
  local flags = type(extraFlags) == "table" and extraFlags or {}

  if unit then
    flags.unit = unit
  end

  Addon:ApplyOptionsChange("CastBar", flags)
end

local function UFCB_BlockCombat()
  if InCombatLockdown() then
    WarnCombatLocked()
    return true
  end
  return false
end

local function UFCB_BuildInlineArgsGroup(name, order, args)
  return {
    type = "group",
    name = name,
    order = order,
    inline = true,
    args = args,
  }
end

local UFCB_INLINE_GROUP_NAMES = {
  core = "Module and behavior",
  frameLayout = "Frame size and layout",
  indicators = "Indicators",
  textures = "Textures",
  sorting = "Sorting",
  groupLayout = "Raid groups",
  layout = "Layout and sorting",
  visibility = "Visibility",
  dispelIndicator = "Dispel indicator",
  roleSetup = "Role order",
}

local UFCB_INLINE_SECTION_ORDER = {
  behavior = 1,
  size = 2,
  appearance = 3,
  textures = 4,
  colors = 5,
  typography = 6,
  position = 7,
  layout = 8,
  sorting = 9,
  other = 10,
  info = 99,
}

local UFCB_INLINE_SECTION_NAMES = {
  behavior = "Behavior",
  size = "Size",
  appearance = "Appearance",
  textures = "Textures",
  colors = "Colors",
  typography = "Typography",
  position = "Position",
  layout = "Layout",
  sorting = "Sorting",
  other = "Settings",
  info = "Information",
}

local function UFCB_GetInlineSectionKey(key, option)
  local lowerKey = tostring(key or ""):lower()

  if option.type == "description"
    or lowerKey:find("note", 1, true)
    or lowerKey:find("help", 1, true)
    or lowerKey:find("info", 1, true)
  then
    return "info"
  end

  if lowerKey:find("sort", 1, true) then
    return "sorting"
  end

  if lowerKey:find("anchor", 1, true)
    or lowerKey:find("offset", 1, true)
    or lowerKey:find("position", 1, true)
    or lowerKey:find("point", 1, true)
    or lowerKey == "side"
  then
    return "position"
  end

  if lowerKey:find("font", 1, true)
    or lowerKey:find("outline", 1, true)
    or lowerKey:find("textsize", 1, true)
  then
    return "typography"
  end

  if lowerKey:find("growth", 1, true)
    or lowerKey:find("orientation", 1, true)
    or lowerKey:find("spacing", 1, true)
    or lowerKey:find("row", 1, true)
    or lowerKey:find("column", 1, true)
    or lowerKey:find("group", 1, true)
  then
    return "layout"
  end

  if lowerKey:find("texture", 1, true) then
    return "textures"
  end

  if lowerKey:find("color", 1, true) then
    return "colors"
  end

  if lowerKey:find("alpha", 1, true)
    or lowerKey:find("opacity", 1, true)
    or lowerKey:find("style", 1, true)
    or lowerKey:find("zoom", 1, true)
    or lowerKey:find("border", 1, true)
  then
    return "appearance"
  end

  if lowerKey:find("width", 1, true)
    or lowerKey:find("height", 1, true)
    or lowerKey:find("size", 1, true)
  then
    return "size"
  end

  if option.type == "toggle"
    or lowerKey:find("enable", 1, true)
    or lowerKey:find("disable", 1, true)
    or lowerKey:find("show", 1, true)
    or lowerKey:find("hide", 1, true)
    or lowerKey:find("use", 1, true)
    or lowerKey:find("mode", 1, true)
    or lowerKey:find("visibility", 1, true)
  then
    return "behavior"
  end

  return "other"
end

local function UFCB_BuildCategorizedInlineArgs(args)
  local output = {}
  local sections = {}

  for key, option in pairs(args or {}) do
    if type(option) == "table" and option.type == "group" then
      if option.name == nil or option.name == "" or option.name == " " then
        option.name = UFCB_INLINE_GROUP_NAMES[key] or "Settings"
      end
      output[key] = option
    elseif type(option) == "table" then
      local sectionKey = UFCB_GetInlineSectionKey(key, option)
      local section = sections[sectionKey]
      if not section then
        section = {}
        sections[sectionKey] = section
      end
      section[key] = option
    end
  end

  for sectionKey, sectionArgs in pairs(sections) do
    output["__puiInline_" .. sectionKey] = UFCB_BuildInlineArgsGroup(
      UFCB_INLINE_SECTION_NAMES[sectionKey],
      UFCB_INLINE_SECTION_ORDER[sectionKey],
      sectionArgs
    )
  end

  return output
end


local function UFCB_IsUsingGlobalFont(fontKey, useGlobalFont)
  if useGlobalFont ~= nil then
    return useGlobalFont == true
  end

  local standardKey = ns.FontDropdown.STANDARD_FONT_KEY
  return not (type(fontKey) == "string" and fontKey ~= "" and fontKey ~= standardKey)
end



local function UFCB_GetValidChoice(values, current, fallback)
  if type(values) == "table" and values[current] ~= nil then
    return current
  end

  return fallback
end

local function UFCB_GetTextModeChoice(current, fallback)
  if current == "CUR_PCT" then
    current = "CUR_PERCENT"
  end

  return UFCB_GetValidChoice(TEXT_MODE_VALUES, current, fallback or "CUR")
end

local function UFCB_GetNumberOrDefault(value, default)
  value = tonumber(value)
  if type(value) ~= "number" then
    return default
  end

  return value
end

local function UFCB_GetClampedNumber(value, default, minValue, maxValue)
  value = UFCB_GetNumberOrDefault(value, default)

  if type(minValue) == "number" and value < minValue then
    value = minValue
  end

  if type(maxValue) == "number" and value > maxValue then
    value = maxValue
  end

  return value
end

local function UFCB_GetPlayerQuickSetupState()
  local ufDB = UF.db.profile
  local cfg = UF:GetConfigUnit("player")

  if not ufDB or not cfg then
    return nil, nil
  end

  ufDB.media = ufDB.media or {}
  ufDB.text = ufDB.text or {}
  ufDB.colors = ufDB.colors or {}
  ufDB.auras = ufDB.auras or {}
  cfg.text = cfg.text or {}
  cfg.auras = cfg.auras or {}

  return ufDB, cfg
end

local function UFCB_AreAllPortraitsEnabled()
  for index = 1, #PORTRAIT_UNIT_KEYS do
    local cfg = UF:GetConfigUnit(PORTRAIT_UNIT_KEYS[index])
    if not cfg or not cfg.portrait or cfg.portrait.enabled ~= true then
      return false
    end
  end

  local partyDB = ns.Modules.PartyFrames.db.profile
  return partyDB.portrait and partyDB.portrait.enabled == true
end

local function UFCB_SetAllPortraitsEnabled(enabled)
  enabled = enabled == true

  for index = 1, #PORTRAIT_UNIT_KEYS do
    local cfg = UF:GetConfigUnit(PORTRAIT_UNIT_KEYS[index])
    cfg.portrait.enabled = enabled
  end

  ns.Modules.PartyFrames.db.profile.portrait.enabled = enabled

  Addon:ApplyOptionsChange("UnitFrames", { mode = "resize" })
  UFCB_RequestGroupedRefresh("party", false, { resize = true })
end

local function UFCB_GetQuickAuraDisplay(auras, builtInKey)
  local displayID = ns.UFAuraFilters.BUILT_IN_DISPLAY_IDS[builtInKey]
  local displays = type(auras.customDisplays) == "table" and auras.customDisplays or nil

  if not displays or not displays[displayID] then
    displays = ns.UFAuraFilters.NormalizeDisplays(auras)
  end

  return displays[displayID]
end

local function UFCB_GetQuickAuraVisibility(auras, showKey, onlyPlayerKey)
  if auras[showKey] == false then
    return "NONE"
  end

  if auras[onlyPlayerKey] == true then
    return "PLAYER"
  end

  return "ALL"
end

local function UFCB_SetQuickAuraVisibility(auras, showKey, onlyPlayerKey, value)
  if value == "NONE" then
    auras[showKey] = false
    auras[onlyPlayerKey] = false
  elseif value == "PLAYER" then
    auras[showKey] = true
    auras[onlyPlayerKey] = true
  else
    auras[showKey] = true
    auras[onlyPlayerKey] = false
  end
end

local function UFCB_GetQuickAuraGrowth(anchor)
  local growthX = anchor and anchor:find("RIGHT", 1, true) and "LEFT" or "RIGHT"
  local growthY = anchor and anchor:find("BOTTOM", 1, true) and "DOWN" or "UP"

  if anchor == "LEFT" then
    growthX = "LEFT"
  elseif anchor == "RIGHT" then
    growthX = "RIGHT"
  elseif anchor == "BOTTOM" then
    growthY = "DOWN"
  end

  return growthX, growthY
end

function UF:GetQuickSetupValue(key)
  local ufDB, cfg = UFCB_GetPlayerQuickSetupState()
  if not ufDB or not cfg then
    return nil
  end

  if key == "enabled" then
    return ufDB.enabled ~= false
  elseif key == "texture" or key == "globalHealthTexture" then
    return ufDB.media.healthTexture or "Pleebar"
  elseif key == "globalPowerTexture" then
    return ufDB.media.powerTexture or ufDB.media.healthTexture or "Pleebar"
  elseif key == "healthMode" then
    local defaults = UF:GetDefaultUnitConfig("player")
    local defaultText = type(defaults.text) == "table" and defaults.text or {}
    return UFCB_GetTextModeChoice(cfg.text.healthMode or defaultText.healthMode, defaultText.healthMode or "CUR")
  elseif key == "shortenValues" then
    return ufDB.text.shortenValues == true
  elseif key == "showPower" then
    return cfg.showPower ~= false and (tonumber(cfg.powerHeight) or 0) > 0
  elseif key == "playerPowerHeight" then
    local defaults = UF:GetDefaultUnitConfig("player")
    return tonumber(cfg.powerHeight or defaults.powerHeight) or 0
  elseif key == "classColor" then
    return cfg.useClassColor ~= false
  elseif key == "portraitsEnabled" then
    return UFCB_AreAllPortraitsEnabled()
  elseif key == "borderThickness" then
    return UFCB_GetClampedNumber(ufDB.borderEdgeSize, 1, 0, 6)
  elseif key == "borderPlacement" then
    return ufDB.borderPlacement == "inside" and "inside" or "outside"
  elseif key == "aurasEnabled" then
    return ufDB.auras.enabled ~= false
  elseif key == "showBuffs" then
    local display = UFCB_GetQuickAuraDisplay(cfg.auras, "DEFAULT_BUFF")
    if display then
      return display.enabled ~= false
    end

    return cfg.auras.showBuffs ~= false
  elseif key == "showDebuffs" then
    local display = UFCB_GetQuickAuraDisplay(cfg.auras, "DEFAULT_DEBUFF")
    if display then
      return display.enabled ~= false
    end

    return cfg.auras.showDebuffs ~= false
  elseif key == "auraAnchor" then
    return cfg.auras.debuffsAnchorPoint or ufDB.auras.debuffsAnchorPoint or "TOPLEFT"
  elseif key == "auraSize" then
    return UFCB_GetClampedNumber(cfg.auras.buffIconSize or cfg.auras.iconSize or ufDB.auras.iconSize, 18, 10, 64)
  elseif key == "buffVisibility" then
    local display = UFCB_GetQuickAuraDisplay(cfg.auras, "DEFAULT_BUFF")
    if display then
      return UFCB_GetQuickAuraVisibility(display, "enabled", "onlyPlayer")
    end

    return UFCB_GetQuickAuraVisibility(cfg.auras, "showBuffs", "onlyPlayerBuffs")
  elseif key == "debuffVisibility" then
    local display = UFCB_GetQuickAuraDisplay(cfg.auras, "DEFAULT_DEBUFF")
    if display then
      return UFCB_GetQuickAuraVisibility(display, "enabled", "onlyPlayer")
    end

    return UFCB_GetQuickAuraVisibility(cfg.auras, "showDebuffs", "onlyPlayerDebuffs")
  end

  return nil
end

function UF:SetQuickSetupValue(key, value)
  if UFCB_BlockCombat() then
    return false
  end

  local ufDB, cfg = UFCB_GetPlayerQuickSetupState()
  if not ufDB or not cfg then
    return false
  end

  if key == "enabled" then
    ufDB.enabled = value and true or false
  elseif key == "texture" then
    ufDB.media.healthTexture = value
    ufDB.media.powerTexture = value
    UFCB_RefreshUFTextures()
  elseif key == "globalHealthTexture" then
    ufDB.media.healthTexture = value
    UFCB_RefreshUFTextures()
  elseif key == "globalPowerTexture" then
    ufDB.media.powerTexture = value
    UFCB_RefreshUFTextures()
  elseif key == "healthMode" then
    local defaults = UF:GetDefaultUnitConfig("player")
    local defaultText = type(defaults.text) == "table" and defaults.text or {}
    cfg.text.healthMode = UFCB_GetTextModeChoice(value, defaultText.healthMode or "CUR")
    Addon:ApplyOptionsChange("UnitFrames", { mode = "text", unit = "player" })
  elseif key == "shortenValues" then
    ufDB.text.shortenValues = value and true or false
    UFCB_RefreshUFText()
  elseif key == "showPower" then
    cfg.showPower = value and true or false
    Addon:ApplyOptionsChange("UnitFrames", { mode = "resize", unit = "player" })
  elseif key == "playerPowerHeight" then
    cfg.powerHeight = UFCB_GetClampedNumber(value, 0, 0, 20)
    Addon:ApplyOptionsChange("UnitFrames", { mode = "resize", unit = "player" })
  elseif key == "classColor" then
    cfg.useClassColor = value and true or false
    Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance", unit = "player" })
  elseif key == "portraitsEnabled" then
    UFCB_SetAllPortraitsEnabled(value)
  elseif key == "borderThickness" then
    ufDB.borderEdgeSize = UFCB_GetClampedNumber(value, 1, 0, 6)
    Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance" })
  elseif key == "borderPlacement" then
    ufDB.borderPlacement = value == "inside" and "inside" or "outside"
    Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance" })
  elseif key == "aurasEnabled" then
    ufDB.auras.enabled = value and true or false
    UFCB_RefreshUFAuras()
  elseif key == "showBuffs" then
    local display = UFCB_GetQuickAuraDisplay(cfg.auras, "DEFAULT_BUFF")
    if display then
      display.enabled = value and true or false
    else
      cfg.auras.showBuffs = value and true or false
    end

    UFCB_RefreshUFAuras({ unit = "player" })
  elseif key == "showDebuffs" then
    local display = UFCB_GetQuickAuraDisplay(cfg.auras, "DEFAULT_DEBUFF")
    if display then
      display.enabled = value and true or false
    else
      cfg.auras.showDebuffs = value and true or false
    end

    UFCB_RefreshUFAuras({ unit = "player" })
  elseif key == "auraAnchor" then
    local anchor = PARTY_ANCHOR_VALUES[value] and value or "TOPLEFT"
    local growthX, growthY = UFCB_GetQuickAuraGrowth(anchor)

    cfg.auras.debuffsAttachTo = "FRAME"
    cfg.auras.debuffsAnchorPoint = anchor
    cfg.auras.debuffsGrowthX = growthX
    cfg.auras.debuffsGrowthY = growthY
    cfg.auras.debuffsXOffset = 0
    cfg.auras.debuffsYOffset = 0

    cfg.auras.buffsAttachTo = "DEBUFFS"
    cfg.auras.buffsAnchorPoint = anchor
    cfg.auras.buffsGrowthX = growthX
    cfg.auras.buffsGrowthY = growthY
    cfg.auras.buffsXOffset = 0
    cfg.auras.buffsYOffset = 0

    UFCB_RefreshUFAuras({ unit = "player" })
  elseif key == "auraSize" then
    local size = UFCB_GetClampedNumber(value, 18, 10, 64)
    cfg.auras.iconSize = size
    cfg.auras.buffIconSize = size
    cfg.auras.debuffIconSize = size
    UFCB_RefreshUFAuras({ unit = "player" })
  elseif key == "buffVisibility" then
    local display = UFCB_GetQuickAuraDisplay(cfg.auras, "DEFAULT_BUFF")
    if display then
      UFCB_SetQuickAuraVisibility(display, "enabled", "onlyPlayer", value)
    else
      UFCB_SetQuickAuraVisibility(cfg.auras, "showBuffs", "onlyPlayerBuffs", value)
    end

    UFCB_RefreshUFAuras({ unit = "player" })
  elseif key == "debuffVisibility" then
    local display = UFCB_GetQuickAuraDisplay(cfg.auras, "DEFAULT_DEBUFF")
    if display then
      UFCB_SetQuickAuraVisibility(display, "enabled", "onlyPlayer", value)
    else
      UFCB_SetQuickAuraVisibility(cfg.auras, "showDebuffs", "onlyPlayerDebuffs", value)
    end

    UFCB_RefreshUFAuras({ unit = "player" })
  else
    return false
  end

  return true
end


local function UFCB_GetCastbarRefreshUnit(unitKey)
  if unitKey == "boss" then
    return "boss1"
  end

  return unitKey
end

local function UFCB_GetOutlineValues()
  local STANDARD_OUTLINE_KEY = ns.Theme.STANDARD_OUTLINE_KEY
  return OptionsUtil.BuildOutlineValues(true, "Use global outline", STANDARD_OUTLINE_KEY), STANDARD_OUTLINE_KEY
end

local function UFCB_GetGlobalOutlineValue(v)
  local _, STANDARD_OUTLINE_KEY = UFCB_GetOutlineValues()
  v = ns.Theme.NormalizeOutlineFlags(v)

  if v == nil then
    return STANDARD_OUTLINE_KEY
  end

  return v
end

local function UFCB_SetStoredOutline(v)
  local _, STANDARD_OUTLINE_KEY = UFCB_GetOutlineValues()
  if v == STANDARD_OUTLINE_KEY then
    return nil
  end
  return ns.Theme.NormalizeOutlineFlags(v)
end


local function UFCB_BuildUnavailableArgs(msg)
  return {
    unavailable = {
      type = "description",
      name = msg or "This section is not available.",
      order = 1,
      fontSize = "medium",
    },
  }
end

local function UFCB_BuildGeneralAppearanceArgs()
  local ufDB = UF.db.profile
  if not ufDB then
    return UFCB_BuildUnavailableArgs("UnitFrames module is not loaded.")
  end

  local colors = ufDB.colors

  return {
    borderThickness = {
      type = "range",
      name = "Border thickness",
      order = 1,
      min = 0,
      max = 6,
      step = 1,
      get = function()
        return UF:GetQuickSetupValue("borderThickness")
      end,
      set = function(_, v)
        UF:SetQuickSetupValue("borderThickness", v)
      end,
    },
    borderPlacement = {
      type = "select",
      name = "Border placement",
      order = 2,
      values = {
        inside = "Inside frame (shrinks bars)",
        outside = "Outside frame (does not cover bars)",
      },
      get = function()
        return UF:GetQuickSetupValue("borderPlacement")
      end,
      set = function(_, v)
        UF:SetQuickSetupValue("borderPlacement", v)
      end,
    },

    useReactionForNPC = {
      type = "toggle",
      name = "Use reaction color for NPCs",
      order = 4,
      
      get = function()
        return colors.useReactionForNPC ~= false
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        colors.useReactionForNPC = v and true or false
        Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance" })
      end,
    },
    classColoredNames = {
      type = "toggle",
      name = "Class colored names",
      order = 4.5,
      get = function()
        return colors.useClassForNames == true
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        colors.useClassForNames = v and true or false
        Addon:ApplyOptionsChange("UnitFrames", { mode = "text" })
      end,
    },
    nameTextColor = {
      type = "color",
      name = "Name text",
      order = 5,
      get = function()
        local c = colors.nameText or { 1, 1, 1 }
        return c[1] or 1, c[2] or 1, c[3] or 1
      end,
      set = function(_, r, g, b)
        if UFCB_BlockCombat() then return end
        colors.nameText = { r, g, b }
        Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance" })
      end,
    },
    deadTextColor = {
      type = "color",
      name = "Dead / ghost text",
      order = 6,
      get = function()
        local c = colors.deadText or { 0.7, 0.7, 0.7 }
        return c[1] or 0.7, c[2] or 0.7, c[3] or 0.7
      end,
      set = function(_, r, g, b)
        if UFCB_BlockCombat() then return end
        colors.deadText = { r, g, b }
        Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance" })
      end,
    },
    healthMissingColor = {
      type = "color",
      name = "Missing Health",
      order = 7,
      hasAlpha = true,
      get = function()
        local c = colors.healthMissing or { 0.2, 0.2, 0.2, 1 }
        return c[1] or 0.2, c[2] or 0.2, c[3] or 0.2, c[4] or 1
      end,
      set = function(_, r, g, b, a)
        if UFCB_BlockCombat() then return end
        colors.healthMissing = { r, g, b, a or 1 }
        Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance" })
      end,
    },
    incomingHeals = UFCB_BuildInlineArgsGroup("Incoming heals", 7.5, {
      enabled = {
        type = "toggle",
        name = "Show incoming heals",
        order = 1,
        get = function()
          return ufDB.healthPrediction.incomingHeals ~= false
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          ufDB.healthPrediction.incomingHeals = v and true or false
          UFCB_RefreshUFHealthPrediction()
        end,
      },
      playerColor = {
        type = "color",
        name = "My incoming heals",
        order = 2,
        hasAlpha = true,
        disabled = function()
          return ufDB.healthPrediction.incomingHeals == false
        end,
        get = function()
          local c = colors.healthIncomingPlayer or { 0.20, 0.85, 0.35, 0.55 }
          return c[1] or 0.20, c[2] or 0.85, c[3] or 0.35, c[4] or 0.55
        end,
        set = function(_, r, g, b, a)
          if UFCB_BlockCombat() then return end
          colors.healthIncomingPlayer = { r, g, b, a or 0.55 }
          UFCB_RefreshUFHealthPrediction()
        end,
      },
      otherColor = {
        type = "color",
        name = "Other incoming heals",
        order = 3,
        hasAlpha = true,
        disabled = function()
          return ufDB.healthPrediction.incomingHeals == false
        end,
        get = function()
          local c = colors.healthIncomingOther or { 0.35, 0.65, 1.00, 0.35 }
          return c[1] or 0.35, c[2] or 0.65, c[3] or 1.00, c[4] or 0.35
        end,
        set = function(_, r, g, b, a)
          if UFCB_BlockCombat() then return end
          colors.healthIncomingOther = { r, g, b, a or 0.35 }
          UFCB_RefreshUFHealthPrediction()
        end,
      },
    }),
    damageAbsorbs = UFCB_BuildInlineArgsGroup("Shields and absorbs", 8, {
      enabled = {
        type = "toggle",
        name = "Show shields and absorbs",
        order = 1,
        get = function()
          return ufDB.healthPrediction.damageAbsorbs ~= false
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          ufDB.healthPrediction.damageAbsorbs = v and true or false
          UFCB_RefreshUFHealthPrediction()
        end,
      },
      color = {
        type = "color",
        name = "Shield absorb",
        order = 2,
        hasAlpha = true,
        disabled = function()
          return ufDB.healthPrediction.damageAbsorbs == false
        end,
        get = function()
          local c = colors.healthAbsorb or { 0.50196081399918, 0.75294125080109, 1, 0.8 }
          return c[1] or 0.50196081399918, c[2] or 0.75294125080109, c[3] or 1, c[4] or 0.8
        end,
        set = function(_, r, g, b, a)
          if UFCB_BlockCombat() then return end
          colors.healthAbsorb = { r, g, b, a or 0.8 }
          UFCB_RefreshUFHealthPrediction()
        end,
      },
    }),
    healAbsorbs = UFCB_BuildInlineArgsGroup("Heal absorbs", 9, {
      enabled = {
        type = "toggle",
        name = "Show heal absorbs",
        order = 1,
        get = function()
          return ufDB.healthPrediction.healAbsorbs ~= false
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          ufDB.healthPrediction.healAbsorbs = v and true or false
          UFCB_RefreshUFHealthPrediction()
        end,
      },
      color = {
        type = "color",
        name = "Heal absorb",
        order = 2,
        hasAlpha = true,
        disabled = function()
          return ufDB.healthPrediction.healAbsorbs == false
        end,
        get = function()
          local c = colors.healthHealAbsorb or { 0.50196078431373, 0.25098039215686, 1, 1 }
          return c[1] or 0.50196078431373, c[2] or 0.25098039215686, c[3] or 1, c[4] or 1
        end,
        set = function(_, r, g, b, a)
          if UFCB_BlockCombat() then return end
          colors.healthHealAbsorb = { r, g, b, a or 1 }
          UFCB_RefreshUFHealthPrediction()
        end,
      },
    }),
    portraitsEnabled = {
      type = "toggle",
      name = "Show portraits on supported frames",
      desc = "Show portraits on Player, Target, Focus, Boss, and Party frames. Each frame can still be changed individually in its Portrait settings.",
      order = 10,
      get = function()
        return UF:GetQuickSetupValue("portraitsEnabled")
      end,
      set = function(_, v)
        UF:SetQuickSetupValue("portraitsEnabled", v)
      end,
    },

    enableUnitMouseoverTooltips = {
      type = "toggle",
      name = "Enable unit mouseover tooltips",
      desc = "Shows the regular Blizzard unit tooltip when your mouse is over a PleebUI frame. This is the frame tooltip, not the aura icon tooltip.",
      order = 11,
      
      get = function()
        return ufDB.enableMouseoverTooltips ~= false
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        ufDB.enableMouseoverTooltips = v and true or false
        UFCB_RefreshUFMouseover()
      end,
    },
    enableUnitMouseoverHighlight = {
      type = "toggle",
      name = "Enable unit mouseover highlight",
      desc = "Adds a visual highlight to the full unit frame while your mouse is over it. This does not control aura icon tooltips.",
      order = 12,
      
      get = function()
        return ufDB.enableMouseoverHighlight ~= false
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        ufDB.enableMouseoverHighlight = v and true or false
        UFCB_RefreshUFMouseover()
      end,
    },
    unitMouseoverHighlightMode = {
      type = "select",
      name = "Mouseover highlight style",
      desc = "Choose how the frame highlight looks while the mouse is over a unit frame.",
      order = 13,
      values = MOUSEOVER_HIGHLIGHT_MODE_VALUES,
      disabled = function()
        return ufDB.enableMouseoverHighlight == false
      end,
      get = function()
        return UFCB_GetValidChoice(MOUSEOVER_HIGHLIGHT_MODE_VALUES, ufDB.mouseoverHighlightMode, "BOTH")
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        ufDB.mouseoverHighlightMode = v
        UFCB_RefreshUFMouseover()
      end,
    },
    unitMouseoverHighlightStrength = {
      type = "range",
      name = "Mouseover highlight strength",
      desc = "Controls the opacity of the mouseover frame highlight.",
      order = 14,
      min = 0,
      max = 1,
      step = 0.01,
      disabled = function()
        return ufDB.enableMouseoverHighlight == false
      end,
      get = function()
        return UFCB_GetClampedNumber(ufDB.mouseoverHighlightStrength, 0.55, 0, 1)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        ufDB.mouseoverHighlightStrength = UFCB_GetClampedNumber(v, 0.55, 0, 1)
        UFCB_RefreshUFMouseover()
      end,
    },
    unitMouseoverHighlightBorderSize = {
      type = "range",
      name = "Mouseover border size",
      desc = "Controls the border thickness of the unit mouseover frame highlight.",
      order = 15,
      min = 0,
      max = 12,
      step = 1,
      disabled = function()
        return ufDB.enableMouseoverHighlight == false
      end,
      get = function()
        return UFCB_GetClampedNumber(ufDB.mouseoverHighlightBorderSize, 3, 0, 12)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        ufDB.mouseoverHighlightBorderSize = UFCB_GetClampedNumber(v, 3, 0, 12)
        UFCB_RefreshUFMouseover()
      end,
    },
    unitTargetHighlightBorderSize = {
      type = "range",
      name = "Target border size",
      desc = "Controls the border thickness of the party and raid target highlight.",
      order = 16,
      min = 0,
      max = 12,
      step = 1,
      get = function()
        return UFCB_GetClampedNumber(ufDB.targetHighlightBorderSize, 3, 0, 12)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        ufDB.targetHighlightBorderSize = UFCB_GetClampedNumber(v, 3, 0, 12)
        UFCB_RefreshUFTargetHighlight()
      end,
    },
  }
end

local function UFCB_BuildGeneralAurasArgs()
  local ufDB = UF.db.profile
  if not ufDB then
    return UFCB_BuildUnavailableArgs("UnitFrames module is not loaded.")
  end

  local auras = ufDB.auras
  local powerText = ufDB.powerText
  local cbDB = CastBar.db.profile

  local args = {
    enableAuras = {
      type = "toggle",
      name = "Enable auras (buffs/debuffs)",
      order = 1,
      
      get = function()
        return UF:GetQuickSetupValue("aurasEnabled")
      end,
      set = function(_, v)
        UF:SetQuickSetupValue("aurasEnabled", v)
      end,
    },
    enableAllUF = {
      type = "toggle",
      name = "Enable all unit frames",
      order = 3,
      
      get = function()
        return UF:GetQuickSetupValue("enabled")
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then
          LibStub("AceConfigRegistry-3.0"):NotifyChange("PleebUI")
          return
        end

        v = v == true

        if UF:GetQuickSetupValue("enabled") == v then
          return
        end

        Addon:PUI_ConfirmAction({
          title = "Reload required",
          text = "Changing PleebUI unit frames requires reloading the UI.",
          yesText = "Apply + Reload",
          onYes = function()
            UF:SetQuickSetupValue("enabled", v)
            ReloadUI()
          end,
          onNo = function()
            LibStub("AceConfigRegistry-3.0"):NotifyChange("PleebUI")
          end,
        })
      end,
    },
    enableNumericPowerText = {
      type = "toggle",
      name = "Enable numeric power text (where used)",
      order = 5,
      
      get = function()
        return powerText.enabled ~= false
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        powerText.enabled = v and true or false
        UFCB_RefreshUFText()
      end,
    },
  }

  if cbDB then
    args.enableAllCastBars = {
      type = "toggle",
      name = "Enable all cast bars",
      order = 4,
      
      get = function()
        return cbDB.enabled ~= false
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        cbDB.enabled = v and true or false
        CastBar:RefreshPlayerSpellcastEvents()
        CB_RefreshUnit()
      end,
    }
  end

  return args
end

local function UFCB_BuildGeneralTextFontsArgs()
  local ufDB = UF.db.profile
  if not ufDB then
    return UFCB_BuildUnavailableArgs("UnitFrames module is not loaded.")
  end

  local textGlobal = ufDB.text
  local outlineValues = UFCB_GetOutlineValues()

  return {
    useGlobalFont = {
      type = "toggle",
      name = "Use global font",
      order = 1,
      get = function()
        return UFCB_IsUsingGlobalFont(textGlobal.font, textGlobal.useGlobalFont)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        textGlobal.useGlobalFont = v and true or false
        UFCB_RefreshUFText()
      end,
    },
    defaultFont = {
      type = "select",
      dialogControl = "LSM30_Font",
      name = "Default unit frame font",
      order = 2,
      values = OptionsUtil.BuildFontValues,
      disabled = function()
        return UFCB_IsUsingGlobalFont(textGlobal.font, textGlobal.useGlobalFont)
      end,
      get = function()
        return OptionsUtil.ResolveFontKey(textGlobal.font, textGlobal.useGlobalFont)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        textGlobal.font = v
        textGlobal.useGlobalFont = false
        UFCB_RefreshUFText()
      end,
    },
    outline = {
      type = "select",
      name = "Outline",
      order = 2,
      values = outlineValues,
      get = function()
        return UFCB_GetGlobalOutlineValue(textGlobal.outline)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        textGlobal.outline = UFCB_SetStoredOutline(v)
        UFCB_RefreshUFText()
      end,
    },
    useNSRTNicknames = {
      type = "toggle",
      name = "Enable nicknames",
      order = 3,
      
      desc = "Uses NorthernSky nicknames for PleebUI unit frame, party frame, and raid frame names when available.",
      get = function()
        return textGlobal.useNSRTNicknames == true
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        textGlobal.useNSRTNicknames = v and true or false
        ns.UFTags.RefreshNicknames()
      end,
    },
    shortenValues = {
      type = "toggle",
      name = "Shorten values",
      order = 4,
      desc = "Shortens health and resource numbers with Blizzard-style abbreviations. Example: 12345 becomes 12.3k, and 1234567 becomes 1.2m. Percent-only modes are unchanged.",
      get = function()
        return UF:GetQuickSetupValue("shortenValues")
      end,
      set = function(_, v)
        UF:SetQuickSetupValue("shortenValues", v)
      end,
    },
    nameTextSize = {
      type = "range",
      name = "Name text size",
      order = 5,
      min = 8,
      max = 32,
      step = 1,
      get = function()
        return tonumber(textGlobal.sizeName)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        textGlobal.sizeName = v
        UFCB_RefreshUFText()
      end,
    },
    healthTextSize = {
      type = "range",
      name = "Health text size",
      order = 6,
      min = 8,
      max = 32,
      step = 1,
      get = function()
        return tonumber(textGlobal.sizeHealth)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        textGlobal.sizeHealth = v
        UFCB_RefreshUFText()
      end,
    },
    powerTextSize = {
      type = "range",
      name = "Power text size",
      order = 7,
      min = 8,
      max = 32,
      step = 1,
      get = function()
        return tonumber(textGlobal.sizePower)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        textGlobal.sizePower = v
        UFCB_RefreshUFText()
      end,
    },
  }
end

local function UFCB_BuildGeneralAnchorsArgs()
  local ufDB = UF.db.profile
  if not ufDB then
    return UFCB_BuildUnavailableArgs("UnitFrames module is not loaded.")
  end

  local textGlobal = ufDB.text

  local function BuildAnchorArgs(title, orderBase, anchorKey, xKey, yKey, defaultAnchor)
    return {
      type = "group",
      name = title,
      inline = true,
      order = orderBase,
      args = {
        anchor = {
          type = "select",
          name = "Anchor point",
          order = 1,
          values = TEXT_ANCHOR_VALUES,
          get = function()
            local cur = textGlobal[anchorKey] or defaultAnchor
            if not TEXT_ANCHOR_VALUES[cur] then
              cur = defaultAnchor
            end
            return cur
          end,
          set = function(_, v)
            if UFCB_BlockCombat() then return end
            textGlobal[anchorKey] = v
            UFCB_RefreshUFText()
          end,
        },
        offsetX = {
          type = "range",
          name = "X offset",
          order = 2,
          min = -40,
          max = 40,
          step = 1,
          get = function()
            return tonumber(textGlobal[xKey] or 0)
          end,
          set = function(_, v)
            if UFCB_BlockCombat() then return end
            textGlobal[xKey] = v
            UFCB_RefreshUFText()
          end,
        },
        offsetY = {
          type = "range",
          name = "Y offset",
          order = 3,
          min = -40,
          max = 40,
          step = 1,
          get = function()
            return tonumber(textGlobal[yKey] or 0)
          end,
          set = function(_, v)
            if UFCB_BlockCombat() then return end
            textGlobal[yKey] = v
            UFCB_RefreshUFText()
          end,
        },
      },
    }
  end

  local args = {
    name = BuildAnchorArgs("Name Settings", 1, "anchorName", "offsetNameX", "offsetNameY", "LEFT"),
    health = BuildAnchorArgs("Health Settings", 2, "anchorHealth", "offsetHealthX", "offsetHealthY", "RIGHT"),
    power = BuildAnchorArgs("Power Settings", 3, "anchorPower", "offsetPowerX", "offsetPowerY", "RIGHT"),
  }

  args.power.args.mode = {
    type = "select",
    name = "Power text mode",
    order = 4,
    values = TEXT_MODE_VALUES,
    get = function()
      return UFCB_GetTextModeChoice(textGlobal.powerMode or "CUR", "CUR")
    end,
    set = function(_, v)
      if UFCB_BlockCombat() then return end
      textGlobal.powerMode = v
      UFCB_RefreshUFText()
    end,
  }

  return args
end

local function UFCB_BuildGeneralTexturesArgs()
  local ufDB = UF.db.profile
  if not ufDB then
    return UFCB_BuildUnavailableArgs("UnitFrames module is not loaded.")
  end

  local media = ufDB.media
  local range = ufDB.range
  local mediaDefaults = {}
  local rangeDefaults = {}

  return {
    textures = UFCB_BuildInlineArgsGroup("Textures", 1, {
      healthTexture = {
        type = "select",
        dialogControl = "LSM30_Statusbar",
        name = "Health bar texture",
        order = 1,
        values = function()
          return OptionsUtil.BuildStatusbarValues(false)
        end,
        get = function()
          return UF:GetQuickSetupValue("globalHealthTexture")
        end,
        set = function(_, v)
          UF:SetQuickSetupValue("globalHealthTexture", v)
        end,
      },
      powerTexture = {
        type = "select",
        dialogControl = "LSM30_Statusbar",
        name = "Power bar texture",
        order = 2,
        values = function()
          return OptionsUtil.BuildStatusbarValues(false)
        end,
        get = function()
          return UF:GetQuickSetupValue("globalPowerTexture")
        end,
        set = function(_, v)
          UF:SetQuickSetupValue("globalPowerTexture", v)
        end,
      },
      absorbTexture = {
        type = "select",
        dialogControl = "LSM30_Statusbar",
        name = "Absorb texture",
        order = 3,
        values = function()
          return OptionsUtil.BuildStatusbarValues(false)
        end,
        get = function()
          return media.absorbTexture or media.healthTexture or mediaDefaults.absorbTexture or mediaDefaults.healthTexture
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          media.absorbTexture = v
          UFCB_RefreshUFTextures()
        end,
      },
    }),
    range = UFCB_BuildInlineArgsGroup("Range", 2, {
      outOfRangeAlpha = {
        type = "range",
        name = "Out of range alpha",
        order = 1,
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
          return UFCB_GetClampedNumber(range.outOfRangeAlpha, tonumber(rangeDefaults.outOfRangeAlpha) or 0.5, 0, 1)
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          range.outOfRangeAlpha = UFCB_GetClampedNumber(v, 0.5, 0, 1)
          Addon:ApplyOptionsChange("UnitFrames", { mode = "range" })
        end,
      },
    }),
  }
end

local UFCB_MergeOptionArgs

local function UFCB_BuildSharedFrameGeneralArgs(opts)
  opts = opts or {}

  local function BuildOption(key, defaults)
    local src = opts[key]
    if not src then
      return nil
    end

    local out = {}
    for k, v in pairs(defaults or {}) do
      out[k] = v
    end
    for k, v in pairs(src) do
      out[k] = v
    end
    return out
  end

  local args = {}
  local specs = {
    { "width", { type = "range", name = "Frame width", order = 1, min = 80, max = 400, step = 1 } },
    { "height", { type = "range", name = "Total frame height", order = 2, min = 12, max = 80, step = 1 } },
    { "powerHeight", { type = "range", name = "Power height", order = 3, min = 0, max = 20, step = 1 } },
    { "showPower", { type = "toggle", name = "Show power", order = 4 } },
    { "useClassColor", { type = "toggle", name = "Use class color", order = 5 } },
    { "showRoleIcon", { type = "toggle", name = "Show role icons", order = 6 } },
    { "roleIconPosition", { type = "select", name = "Role icon position", order = 6.1, values = TEXT_ANCHOR_VALUES } },
    { "borderSize", { type = "range", name = "Border size", order = 7, min = 0, max = 8, step = 1 } },
    { "spacing", { type = "range", name = "Spacing", order = 8, min = 0, max = 40, step = 1 } },
    { "orientation", { type = "select", name = "Orientation", order = 9 } },
    { "sortOrder", { type = "select", name = "Sort order", order = 10 } },
    { "growthY", { type = "select", name = "Vertical growth", order = 11 } },
    { "useCustomTexture", { type = "toggle", name = "Use custom textures for this frame", order = 12 } },
    { "healthTexture", { type = "select", dialogControl = "LSM30_Statusbar", name = "Health bar texture", order = 13, values = function() return OptionsUtil.BuildStatusbarValues(false) end } },
    { "powerTexture", { type = "select", dialogControl = "LSM30_Statusbar", name = "Power bar texture", order = 14, values = function() return OptionsUtil.BuildStatusbarValues(false) end } },
    { "absorbTexture", { type = "select", dialogControl = "LSM30_Statusbar", name = "Absorb texture", order = 15, values = function() return OptionsUtil.BuildStatusbarValues(false) end } },
  }

  for _, spec in ipairs(specs) do
    local key, defaults = spec[1], spec[2]
    local option = BuildOption(key, defaults)
    if option then
      args[key] = option
    end
  end

  if opts.note and opts.note.name and opts.note.name ~= "" then
    args.note = {
      type = "description",
      name = opts.note.name,
      order = opts.note.order or 100,
      fontSize = opts.note.fontSize or "medium",
    }
  end

  return UFCB_MergeOptionArgs(opts.prefixArgs, args, opts.suffixArgs)
end


local function UFCB_BuildUnitGeneralArgs(unitKey, extraNote)
  local cfg = UF:GetConfigUnit(unitKey)
  local ufDB = UF.db.profile

  if not cfg or not ufDB then
    return UFCB_BuildUnavailableArgs("No configuration found for unit '" .. tostring(unitKey) .. "'.")
  end

  cfg.media = cfg.media or {}
  cfg.text = cfg.text or {}

  local media = cfg.media
  local globalM = ufDB.media
  local unitDefaults = UF:GetDefaultUnitConfig(unitKey)
  local unitMediaDefaults = type(unitDefaults.media) == "table" and unitDefaults.media or {}
  local globalMediaDefaults = {}

  return UFCB_BuildSharedFrameGeneralArgs({
    prefixArgs = {
      core = UFCB_BuildInlineArgsGroup(" ", 0.5, {
        reset = {
          type = "execute",
          name = "Reset to default",
          desc = "Restore this unit frame's General settings to the current PleebUI defaults.",
          order = 0.5,
          width = 0.8,
          func = function()
            if UFCB_BlockCombat() then return end

            cfg.width = unitDefaults.width
            cfg.height = unitDefaults.height
            cfg.powerHeight = unitDefaults.powerHeight

            if unitKey == "player" then
              cfg.showRestingIndicator = unitDefaults.showRestingIndicator ~= false
            end

            for key in pairs(media) do
              media[key] = nil
            end

            for key, value in pairs(unitMediaDefaults) do
              media[key] = type(value) == "table" and UFCB_CopyTable(value) or value
            end

            if unitKey == "boss" then
              cfg.growthDirection = unitDefaults.growthDirection
              cfg.spacing = unitDefaults.spacing
            end

            Addon:ApplyOptionsChange("UnitFrames", { mode = "resize", unit = unitKey })
            Addon:NotifyOptionsTreeChanged("unitframes", ns._PUIActiveOptionsPath)
          end,
        },
      }),
    },
    width = {
      order = 1,
      min = 120,
      max = unitKey == "player" and 600 or 400,
      get = function()
        return tonumber(cfg.width or unitDefaults.width)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        cfg.width = v
        Addon:ApplyOptionsChange("UnitFrames", { mode = "resize", unit = unitKey })
      end,
    },
    height = {
      order = 2,
      min = 12,
      max = 60,
      get = function()
        return tonumber(cfg.height or unitDefaults.height)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        cfg.height = v
        Addon:ApplyOptionsChange("UnitFrames", { mode = "resize", unit = unitKey })
      end,
    },
    powerHeight = {
      order = 3,
      min = 0,
      max = 20,
      get = function()
        if unitKey == "player" then
          return UF:GetQuickSetupValue("playerPowerHeight")
        end

        return tonumber(cfg.powerHeight or unitDefaults.powerHeight)
      end,
      set = function(_, v)
        if unitKey == "player" then
          UF:SetQuickSetupValue("playerPowerHeight", v)
          return
        end

        if UFCB_BlockCombat() then return end
        cfg.powerHeight = v
        Addon:ApplyOptionsChange("UnitFrames", { mode = "resize", unit = unitKey })
      end,
    },
    useCustomTexture = {
      order = 4,
      name = "Use custom textures for this frame",
      desc = "If disabled, this frame uses the global textures from the General tab.",
      get = function()
        return media.useCustomTexture == true
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        media.useCustomTexture = v and true or false
        UFCB_RefreshUFTextures()
      end,
    },
    healthTexture = {
      order = 5,
      disabled = function()
        return media.useCustomTexture ~= true
      end,
      get = function()
        return media.healthTexture or unitMediaDefaults.healthTexture or globalM.healthTexture or globalMediaDefaults.healthTexture
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        media.healthTexture = v
        UFCB_RefreshUFTextures()
      end,
    },
    powerTexture = {
      order = 6,
      disabled = function()
        return media.useCustomTexture ~= true
      end,
      get = function()
        return media.powerTexture or unitMediaDefaults.powerTexture or globalM.powerTexture or globalMediaDefaults.powerTexture
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        media.powerTexture = v
        UFCB_RefreshUFTextures()
      end,
    },
    absorbTexture = {
      order = 7,
      disabled = function()
        return media.useCustomTexture ~= true
      end,
      get = function()
        return media.absorbTexture
          or media.healthTexture
          or unitMediaDefaults.absorbTexture
          or unitMediaDefaults.healthTexture
          or globalM.absorbTexture
          or globalM.healthTexture
          or globalMediaDefaults.absorbTexture
          or globalMediaDefaults.healthTexture
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        media.absorbTexture = v
        UFCB_RefreshUFTextures()
      end,
    },
    suffixArgs = unitKey == "player" and {
      showRestingIndicator = {
        type = "toggle",
        name = "Show rested indicator",
        order = 8,
        get = function()
          return cfg.showRestingIndicator ~= false
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          cfg.showRestingIndicator = v and true or false
          Addon:ApplyOptionsChange("UnitFrames", { mode = "indicators", unit = "player" })
        end,
      },
    } or unitKey == "boss" and {
      growthDirection = {
        type = "select",
        name = "Growth direction",
        order = 8,
        values = {
          UP = "Up",
          DOWN = "Down",
          LEFT = "Left",
          RIGHT = "Right",
        },
        get = function()
          return cfg.growthDirection or unitDefaults.growthDirection or "DOWN"
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          cfg.growthDirection = v
          Addon:ApplyOptionsChange("UnitFrames", { mode = "resize", unit = "boss" })
        end,
      },
      spacing = {
        type = "range",
        name = "Spacing",
        order = 9,
        min = 0,
        max = 80,
        step = 1,
        get = function()
          return tonumber(cfg.spacing or unitDefaults.spacing or 30)
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          cfg.spacing = v
          Addon:ApplyOptionsChange("UnitFrames", { mode = "resize", unit = "boss" })
        end,
      },
    } or nil,
    note = (extraNote and extraNote ~= "") and {
      name = extraNote,
      order = 100,
      fontSize = "medium",
    } or nil,
  })
end

local function UFCB_BuildSharedTextLeafArgs(opts)
  opts = opts or {}
  local outlineValues = UFCB_GetOutlineValues()
  local typographyDisabled = opts.typographyDisabled or opts.disabled
  local positionDisabled = opts.positionDisabled or opts.disabled

  local args = {
    fontSize = {
      type = "range",
      name = opts.sizeName or "Font size",
      order = opts.sizeOrder or 2,
      min = opts.sizeMin or 8,
      max = opts.sizeMax or 32,
      step = opts.sizeStep or 1,
      disabled = typographyDisabled,
      get = opts.getSize,
      set = opts.setSize,
    },
    useGlobalFont = opts.getUseGlobalFont and {
      type = "toggle",
      name = "Use global font",
      order = (opts.fontOrder or 3) - 0.5,
      disabled = typographyDisabled,
      get = opts.getUseGlobalFont,
      set = opts.setUseGlobalFont,
    } or nil,
    font = {
      type = "select",
      dialogControl = "LSM30_Font",
      name = opts.fontName or "Font",
      order = opts.fontOrder or 3,
      values = OptionsUtil.BuildFontValues,
      disabled = function()
        if type(typographyDisabled) == "function" and typographyDisabled() then
          return true
        elseif typographyDisabled == true then
          return true
        end

        if opts.getUseGlobalFont then
          return opts.getUseGlobalFont() == true
        end

        return false
      end,
      get = opts.getFont,
      set = opts.setFont,
    },
    outline = {
      type = "select",
      name = opts.outlineName or "Outline",
      order = opts.outlineOrder or 4,
      values = outlineValues,
      disabled = typographyDisabled,
      get = opts.getOutline,
      set = opts.setOutline,
    },
    anchor = {
      type = "select",
      name = opts.anchorName or "Anchor point",
      order = opts.anchorOrder or 5,
      values = opts.anchorValues or TEXT_ANCHOR_VALUES,
      disabled = positionDisabled,
      get = opts.getAnchor,
      set = opts.setAnchor,
    },
    offsetX = {
      type = "range",
      name = opts.offsetXName or "X offset",
      order = opts.offsetXOrder or 6,
      min = opts.offsetXMin or -40,
      max = opts.offsetXMax or 40,
      step = opts.offsetXStep or 1,
      disabled = positionDisabled,
      get = opts.getOffsetX,
      set = opts.setOffsetX,
    },
    offsetY = {
      type = "range",
      name = opts.offsetYName or "Y offset",
      order = opts.offsetYOrder or 7,
      min = opts.offsetYMin or -40,
      max = opts.offsetYMax or 40,
      step = opts.offsetYStep or 1,
      disabled = positionDisabled,
      get = opts.getOffsetY,
      set = opts.setOffsetY,
    },
  }

  return UFCB_MergeOptionArgs(opts.prefixArgs, args, opts.suffixArgs)
end

local function UFCB_BuildUnitTextArgs(unitKey, kind)
  local cfg = UF:GetConfigUnit(unitKey)
  local ufDB = UF.db.profile

  if not cfg or not ufDB then
    return UFCB_BuildUnavailableArgs("No configuration found for unit '" .. tostring(unitKey) .. "'.")
  end

  cfg.text = cfg.text or {}

  local text = cfg.text
  local globalT = ufDB.text
  local unitDefaults = UF:GetDefaultUnitConfig(unitKey)
  local defaultText = type(unitDefaults.text) == "table" and unitDefaults.text or {}
  local globalTextDefaults = {}

  local baseName, baseHP, basePower = UF:GetBaseTextSizesForUnit(unitKey)
  local baseSize = (kind == "name") and baseName or ((kind == "health") and baseHP or basePower)

  local fontKey, useGlobalFontKey, outlineKey, customTypographyKey
  local anchorKey, offXKey, offYKey, customPositionKey, defaultAnchor
  if kind == "name" then
    fontKey = "nameFont"
    useGlobalFontKey = "nameUseGlobalFont"
    outlineKey = "nameOutline"
    customTypographyKey = "nameUseCustomTypography"
    anchorKey = "anchorName"
    offXKey = "offsetNameX"
    offYKey = "offsetNameY"
    customPositionKey = "nameUseCustomPosition"
    defaultAnchor = "LEFT"
  elseif kind == "health" then
    fontKey = "healthFont"
    useGlobalFontKey = "healthUseGlobalFont"
    outlineKey = "healthOutline"
    customTypographyKey = "healthUseCustomTypography"
    anchorKey = "anchorHealth"
    offXKey = "offsetHealthX"
    offYKey = "offsetHealthY"
    customPositionKey = "healthUseCustomPosition"
    defaultAnchor = "RIGHT"
  else
    fontKey = "powerFont"
    useGlobalFontKey = "powerUseGlobalFont"
    outlineKey = "powerOutline"
    customTypographyKey = "powerUseCustomTypography"
    anchorKey = "anchorPower"
    offXKey = "offsetPowerX"
    offYKey = "offsetPowerY"
    customPositionKey = "powerUseCustomPosition"
    defaultAnchor = "RIGHT"
  end

  local function UsesCustomTypography()
    return text[customTypographyKey] == true
  end

  local function UsesCustomPosition()
    return text[customPositionKey] == true
  end

  local function GetSizeKey()
    if kind == "name" then
      return "sizeName"
    elseif kind == "health" then
      return "sizeHealth"
    end
    return "sizePower"
  end

  local function GetMode()
    if kind == "health" then
      return UFCB_GetTextModeChoice(text.healthMode or defaultText.healthMode or "CUR", defaultText.healthMode or "CUR")
    elseif kind == "power" then
      local cur = text.powerMode or globalT.powerMode
      return UFCB_GetTextModeChoice(cur or defaultText.powerMode or globalTextDefaults.powerMode or "CUR", defaultText.powerMode or globalTextDefaults.powerMode or "CUR")
    end
    return nil
  end

  local prefixArgs = {
    useCustomTypography = {
      type = "toggle",
      name = "Use custom typography",
      order = 1,
      desc = "Use a custom font, size, and outline for this text.",
      get = function()
        return UsesCustomTypography()
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        text[customTypographyKey] = v and true or false
        UFCB_RefreshUFText()
      end,
    },
    useCustomPosition = {
      type = "toggle",
      name = "Use custom position",
      order = 4.5,
      desc = "Use a custom anchor and offsets for this text.",
      get = function()
        return UsesCustomPosition()
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        text[customPositionKey] = v and true or false
        UFCB_RefreshUFText()
      end,
    },
  }

  if kind == "name" then
    prefixArgs.hideNameText = {
      type = "toggle",
      name = "Hide name",
      order = 0.5,
      get = function()
        return text.hideNameText == true
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        text.hideNameText = v == true
        Addon:ApplyOptionsChange("UnitFrames", { mode = "text", unit = unitKey })
      end,
    }
  elseif kind == "health" then
    prefixArgs.hideHealthText = {
      type = "toggle",
      name = "Hide health numbers",
      order = 0.5,
      get = function()
        return text.hideHealthText == true
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        text.hideHealthText = v == true
        Addon:ApplyOptionsChange("UnitFrames", { mode = "text", unit = unitKey })
      end,
    }
    prefixArgs.frameHeight = {
      type = "range",
      name = "Unit frame height",
      order = 0.6,
      min = 12,
      max = 60,
      step = 1,
      get = function()
        return tonumber(cfg.height or unitDefaults.height)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        cfg.height = v
        Addon:ApplyOptionsChange("UnitFrames", { mode = "resize", unit = unitKey })
      end,
    }

    if unitKey == "player" then
      prefixArgs.useClassColor = {
        type = "toggle",
        name = "Use class color",
        order = 0.7,
        get = function()
          return cfg.useClassColor ~= false
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          cfg.useClassColor = v and true or false
          Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance", unit = "player" })
        end,
      }

      prefixArgs.healthColor = {
        type = "color",
        name = "Health color",
        order = 0.8,
        hidden = function()
          return cfg.useClassColor ~= false
        end,
        get = function()
          local themeColors = ns.UFStyle.GetUFThemeColors()
          local c = (cfg.colors and cfg.colors.healthBar)
            or themeColors.healthBar
            or { 0.35, 0.35, 0.35, 1 }
          return c[1] or 0.35, c[2] or 0.35, c[3] or 0.35
        end,
        set = function(_, r, g, b)
          if UFCB_BlockCombat() then return end
          cfg.colors = cfg.colors or {}
          cfg.colors.healthBar = { r, g, b, 1 }
          Addon:ApplyOptionsChange("UnitFrames", { mode = "appearance", unit = "player" })
        end,
      }
    end
  elseif kind == "power" then
    prefixArgs.hidePower = {
      type = "toggle",
      name = "Hide power",
      desc = "Hide the power bar and its text.",
      order = 0.5,
      get = function()
        return cfg.showPower == false
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        cfg.showPower = v ~= true
        Addon:ApplyOptionsChange("UnitFrames", { mode = "resize", unit = unitKey })
      end,
    }
    prefixArgs.powerHeight = {
      type = "range",
      name = "Power height",
      order = 0.6,
      min = 0,
      max = 20,
      step = 1,
      get = function()
        return tonumber(cfg.powerHeight or unitDefaults.powerHeight)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        cfg.powerHeight = v
        Addon:ApplyOptionsChange("UnitFrames", { mode = "resize", unit = unitKey })
      end,
    }
  end

  if kind == "health" or kind == "power" then
    prefixArgs.mode = {
      type = "select",
      name = (kind == "health") and "Health text mode" or "Power text mode",
      order = 8,
      values = TEXT_MODE_VALUES,
      get = function()
        if unitKey == "player" and kind == "health" then
          return UF:GetQuickSetupValue("healthMode")
        end

        return GetMode()
      end,
      set = function(_, v)
        if unitKey == "player" and kind == "health" then
          UF:SetQuickSetupValue("healthMode", v)
          return
        end

        if UFCB_BlockCombat() then return end

        if kind == "health" then
          text.healthMode = v
        else
          text.powerMode = v
        end

        UFCB_RefreshUFText()
      end,
    }
  end

  local function TypographyDisabled()
    return not UsesCustomTypography()
  end

  local function PositionDisabled()
    return not UsesCustomPosition()
  end

  return UFCB_BuildSharedTextLeafArgs({
    prefixArgs = prefixArgs,
    typographyDisabled = TypographyDisabled,
    positionDisabled = PositionDisabled,
    sizeName = "Font size",
    sizeOrder = 2,
    getSize = function()
      local key = GetSizeKey()
      local v = UsesCustomTypography() and text[key] or globalT[key]
      if type(v) ~= "number" then
        v = baseSize
      end
      return v
    end,
    setSize = function(_, v)
      if UFCB_BlockCombat() then return end
      if not UsesCustomTypography() then return end
      text[GetSizeKey()] = v
      UFCB_RefreshUFText()
    end,
    getUseGlobalFont = function()
      local cur = UsesCustomTypography() and text[fontKey] or globalT.font
      local flag = UsesCustomTypography() and text[useGlobalFontKey] or globalT.useGlobalFont
      return UFCB_IsUsingGlobalFont(cur, flag)
    end,
    setUseGlobalFont = function(_, v)
      if UFCB_BlockCombat() then return end

      if not UsesCustomTypography() then return end
      text[useGlobalFontKey] = v and true or false
      UFCB_RefreshUFText()
    end,
    getFont = function()
      local cur = UsesCustomTypography() and text[fontKey] or globalT.font
      local flag = UsesCustomTypography() and text[useGlobalFontKey] or globalT.useGlobalFont
      return OptionsUtil.ResolveFontKey(cur, flag)
    end,
    setFont = function(_, v)
      if UFCB_BlockCombat() then return end
      if not UsesCustomTypography() then return end
      text[fontKey] = v
      text[useGlobalFontKey] = false
      UFCB_RefreshUFText()
    end,
    getOutline = function()
      local cur = UsesCustomTypography() and text[outlineKey] or globalT.outline
      return UFCB_GetGlobalOutlineValue(cur)
    end,
    setOutline = function(_, v)
      if UFCB_BlockCombat() then return end
      if not UsesCustomTypography() then return end
      text[outlineKey] = UFCB_SetStoredOutline(v)
      UFCB_RefreshUFText()
    end,
    anchorValues = TEXT_ANCHOR_VALUES,
    getAnchor = function()
      local cur = UsesCustomPosition() and text[anchorKey] or globalT[anchorKey]
      if not cur or not TEXT_ANCHOR_VALUES[cur] then
        cur = defaultAnchor
      end
      return cur
    end,
    setAnchor = function(_, v)
      if UFCB_BlockCombat() then return end
      if not UsesCustomPosition() then return end
      text[anchorKey] = v
      UFCB_RefreshUFText()
    end,
    getOffsetX = function()
      local v = UsesCustomPosition() and text[offXKey] or globalT[offXKey]
      if type(v) ~= "number" then v = 0 end
      return v
    end,
    setOffsetX = function(_, v)
      if UFCB_BlockCombat() then return end
      if not UsesCustomPosition() then return end
      text[offXKey] = v
      UFCB_RefreshUFText()
    end,
    getOffsetY = function()
      local v = UsesCustomPosition() and text[offYKey] or globalT[offYKey]
      if type(v) ~= "number" then v = 0 end
      return v
    end,
    setOffsetY = function(_, v)
      if UFCB_BlockCombat() then return end
      if not UsesCustomPosition() then return end
      text[offYKey] = v
      UFCB_RefreshUFText()
    end,
  })
end

local UFCB_AURA_GROWTH_X_VALUES = {
  LEFT = "Left",
  RIGHT = "Right",
}

local UFCB_AURA_GROWTH_Y_VALUES = {
  UP = "Up",
  DOWN = "Down",
}

local UFCB_AURA_SORT_DIRECTION_VALUES = {
  ASCENDING = "Ascending",
  DESCENDING = "Descending",
}

local UFCB_AURA_SORT_METHOD_VALUES = {
  TIME_REMAINING = "Time Remaining",
  DURATION = "Duration",
  NAME = "Name",
  INDEX = "Index",
  PLAYER = "Player",
}

local UFCB_CUSTOM_AURA_DISPLAY_TYPE_VALUES = {
  group = "Aura group",
  slot = "Aura slot",
}

local UFCB_CUSTOM_AURA_TYPE_VALUES = {
  HELPFUL = "Helpful",
  HARMFUL = "Harmful",
}

local UFCB_CUSTOM_AURA_FILTER_MODE_VALUES = {
  NONE = "Disabled",
  WHITELIST = "Whitelist",
  BLACKLIST = "Blacklist",
  BOTH = "Whitelist and blacklist",
}

local UFCB_CUSTOM_AURA_HELPFUL_FILTER_VALUES = {
  DEFAULT = "All helpful auras",
  RAID = "Raid",
  RAID_IN_COMBAT = "Raid in combat",
  CROWD_CONTROL = "Crowd control",
  BIG_DEFENSIVE = "Big defensive",
  EXTERNAL_DEFENSIVE = "External defensive",
  RAID_PLAYER_DISPELLABLE = "Player-dispellable raid auras",
  DISPELLABLE = "Dispellable",
  IMPORTANT = "Important",
  CANCELABLE = "Cancelable",
}

local UFCB_CUSTOM_AURA_HARMFUL_FILTER_VALUES = {
  DEFAULT = "All harmful auras",
  RAID = "Raid",
  RAID_IN_COMBAT = "Raid in combat",
  CROWD_CONTROL = "Crowd control",
  RAID_PLAYER_DISPELLABLE = "Player-dispellable raid auras",
  DISPELLABLE = "Dispellable",
}

local UFCB_CUSTOM_AURA_FILTER_DESCRIPTIONS = {
  HELPFUL = {
    DEFAULT = "All helpful auras.",
    RAID = "Helpful auras Blizzard considers applicable by you.",
    RAID_IN_COMBAT = "Auras Blizzard flags for raid frames during combat. Enable Cast by me to show the self-cast HoTs described by Blizzard's raid-frame filter.",
    CROWD_CONTROL = "Auras Blizzard classifies as crowd control, such as stuns, fears, silences, and slows.",
    BIG_DEFENSIVE = "Auras Blizzard classifies as major defensive cooldowns.",
    EXTERNAL_DEFENSIVE = "Auras Blizzard classifies as defensive cooldowns applied to another unit.",
    RAID_PLAYER_DISPELLABLE = "Helpful auras that someone in your raid can purge or steal.",
    DISPELLABLE = "Helpful auras that can be dispelled, purged, or stolen, regardless of whether you or your group can currently remove them.",
    IMPORTANT = "Helpful auras Blizzard flags as important, including buffs intended to remain visible on enemy nameplates.",
    CANCELABLE = "Helpful auras the player can cancel.",
  },
  HARMFUL = {
    DEFAULT = "All harmful auras.",
    RAID = "Harmful auras Blizzard considers dispellable by you.",
    RAID_IN_COMBAT = "Auras Blizzard flags for raid frames during combat.",
    CROWD_CONTROL = "Auras Blizzard classifies as crowd control, such as stuns, fears, silences, and slows.",
    RAID_PLAYER_DISPELLABLE = "Harmful auras that someone in your raid can dispel.",
    DISPELLABLE = "Harmful auras that can be dispelled, regardless of whether you or your group can currently remove them.",
  },
}

local UFCB_CUSTOM_AURA_SORT_METHOD_VALUES = UFCB_AURA_SORT_METHOD_VALUES
local UFCB_CUSTOM_AURA_SORT_DIRECTION_VALUES = UFCB_AURA_SORT_DIRECTION_VALUES


UFCB_MergeOptionArgs = function(...)
  local out = {}

  for i = 1, select("#", ...) do
    local src = select(i, ...)
    if type(src) == "table" then
      for key, value in pairs(src) do
        out[key] = value
      end
    end
  end

  return out
end

local function UFCB_BuildAuraGeneralCommonArgs(getAuras, refresh, defaults)
  defaults = defaults or {}

  return {
    tooltips = {
      type = "toggle",
      name = "Enable aura mouseover tooltips",
      desc = "Master toggle for PleebUI aura icon tooltips. The global unit mouseover tooltip setting also hard-disables these.",
      order = 2,
      
      get = function()
        local auras = getAuras()
        if auras.tooltips == nil then
          return defaults.tooltips ~= false
        end
        return auras.tooltips ~= false
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        local auras = getAuras()
        auras.tooltips = v and true or false
        refresh()
      end,
    },
    tooltipKinds = {
      type = "group",
      name = "Tooltip categories",
      inline = true,
      order = 3,
      disabled = function()
        local auras = getAuras()
        return not auras or auras.tooltips == false
      end,
      args = {
        buffTooltips = {
          type = "toggle",
          name = "Buffs",
          get = function()
            local auras = getAuras()
            if auras.buffTooltips == nil then
              return defaults.buffTooltips ~= false
            end
            return auras.buffTooltips ~= false
          end,
          set = function(_, v)
            if UFCB_BlockCombat() then return end
            local auras = getAuras()
            auras.buffTooltips = v and true or false
            refresh()
          end,
        },
        debuffTooltips = {
          type = "toggle",
          name = "Debuffs",
          get = function()
            local auras = getAuras()
            if auras.debuffTooltips == nil then
              return defaults.debuffTooltips ~= false
            end
            return auras.debuffTooltips ~= false
          end,
          set = function(_, v)
            if UFCB_BlockCombat() then return end
            local auras = getAuras()
            auras.debuffTooltips = v and true or false
            refresh()
          end,
        },

      },
    },
    clickThrough = {
      type = "toggle",
      name = "Click Through",
      desc = "Prevents the aura icons from taking mouse clicks. Use this when you want the unit frame underneath to handle your mouse instead of the icons.",
      order = 4,
      
      get = function()
        local auras = getAuras()
        return auras.clickThrough == true
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        local auras = getAuras()
        auras.clickThrough = v and true or false
        refresh()
      end,
    },
    spacing = {
      type = "range",
      name = "Spacing",
      order = 5,
      min = 0,
      max = 20,
      step = 1,
      get = function()
        local auras = getAuras()
        return tonumber(auras.spacing or defaults.spacing or 2)
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        local auras = getAuras()
        auras.spacing = v
        refresh()
      end,
    },
  }
end

local function UFCB_BuildAuraSpellIDTooltipArg(order)
  return {
    type = "toggle",
    name = "Show aura SpellIDs outside /pui",
    desc = "PleebUI always shows aura SpellIDs while /pui is open. Enable this to keep showing them after the window closes. The non-persistent CVar is reapplied on PLAYER_ENTERING_WORLD.",
    order = order,
    get = function()
      local profile = Addon.db and Addon.db.profile
      local quality = profile and profile.quality
      return quality and quality.showAuraSpellIDs == true or false
    end,
    set = function(_, value)
      local profile = Addon.db.profile
      profile.quality = profile.quality or {}
      profile.quality.showAuraSpellIDs = value and true or false
      ns.UFAuraFilters.ApplyAuraSpellIDTooltipPreference(value == true)
    end,
  }
end

local function UFCB_FocusAuraSlotSpellID(displayID)
  local AceGUI = LibStub("AceGUI-3.0")

  for index = 1, AceGUI:GetWidgetCount("EditBox") do
    local editBox = _G["AceGUI-3.0EditBox" .. index]
    local widget = editBox and editBox.obj
    local user = widget and widget:GetUserDataTable()
    local option = user and user.option

    if editBox and editBox:IsShown()
      and option
      and option.__puiAuraSlotSpellID == displayID
    then
      widget:SetFocus()
      widget:HighlightText()
      return
    end
  end
end

local function UFCB_CreateCustomAuraEditor(getAuras, refresh, fixedDisplayID, unitKey, defaultAuras)
  local editor = {
    fixedDisplayID = tonumber(fixedDisplayID),
    unitKey = unitKey,
    defaultAuras = defaultAuras,
  }

  function editor:GetDisplays()
    local auras = getAuras()
    if not auras then
      return nil
    end

    auras.customDisplays = type(auras.customDisplays) == "table" and auras.customDisplays or {}
    ns.UFAuraFilters.NormalizeDisplays(auras)
    return auras.customDisplays
  end

  function editor:GetSelectedID()
    local auras = getAuras()
    local displays = self:GetDisplays()
    if not auras or not displays then
      return nil
    end

    if self.fixedDisplayID then
      return displays[self.fixedDisplayID] and self.fixedDisplayID or nil
    end

    local selectedID = tonumber(auras.selectedCustomDisplayID)
    if selectedID and displays[selectedID] then
      return selectedID
    end

    selectedID = ns.UFAuraFilters.BUILT_IN_DISPLAY_IDS.DEFAULT_BUFF

    if not displays[selectedID] then
      selectedID = nil

      for id in pairs(displays) do
        id = tonumber(id)
        if id and (not selectedID or id < selectedID) then
          selectedID = id
        end
      end
    end

    auras.selectedCustomDisplayID = selectedID
    return selectedID
  end

  function editor:GetSelectedDisplay()
    local displays = self:GetDisplays()
    local selectedID = self:GetSelectedID()
    return displays and selectedID and displays[selectedID] or nil
  end

  function editor:SyncSelection()
    local auras = getAuras()
    local display = self:GetSelectedDisplay()
    if not auras or not display then
      return
    end

    auras.selectedCustomDisplayID = display.id
  end

  function editor:GetManagerRootPath()
    local activePath = ns._PUIActiveOptionsPath
    local resolvedUnitKey = self.unitKey

    if not resolvedUnitKey
      and type(activePath) == "table"
      and activePath[1] == "unitframes"
    then
      resolvedUnitKey = activePath[2]
    end

    if not resolvedUnitKey then
      return nil
    end

    return {
      "unitframes",
      resolvedUnitKey,
      "auras",
      "customDisplays",
    }
  end

  function editor:GetDisplayPath(displayID, auraType)
    local path = self:GetManagerRootPath()
    if type(path) ~= "table" then
      return nil
    end

    local displays = self:GetDisplays()
    local display = displays and displays[tonumber(displayID)]

    if display and display.builtInKey == "DEFAULT_BUFF" then
      path[#path + 1] = "buffs"
    elseif display and display.builtInKey == "DEFENSIVES_EXTERNALS" then
      path[#path + 1] = "defensives"
    elseif display and display.builtInKey == "IMPORTANT_BUFFS" then
      path[#path + 1] = "important"
    elseif display and display.builtInKey == "DEFAULT_DEBUFF" then
      path[#path + 1] = "debuffs"
    else
      path[#path + 1] = "display_" .. tostring(displayID)
    end

    return path
  end

  function editor:NotifyOptionsChanged(targetPath, afterSelect)
    targetPath = targetPath or ns._PUIActiveOptionsPath
    ns._PUIActiveOptionsPath = targetPath

    C_Timer.After(0, function()
      Addon:NotifyOptionsTreeChanged("unitframes", targetPath)

      local dialog = LibStub("AceConfigDialog-3.0")
      dialog:SelectGroup("PleebUI", unpack(targetPath))

      if afterSelect then
        afterSelect()
      end
    end)
  end

  function editor:Refresh(rebuildOptions, targetPath, afterSelect, changeType, displayID)
    ns.UFPreview.RefreshAuraManagerPreview()

    if self.runtimeRefreshTimer then
      self.runtimeRefreshTimer:Cancel()
      self.runtimeRefreshTimer = nil
    end

    local request = {
      rebuildDB = true,
      auras = true,
      displayID = tonumber(displayID) or self:GetSelectedID(),
      auraChange = changeType or "display",
    }

    if rebuildOptions then
      refresh(request)
      self:NotifyOptionsChanged(targetPath, afterSelect)
      return
    end

    self.runtimeRefreshTimer = C_Timer.NewTimer(0.15, function()
      self.runtimeRefreshTimer = nil
      refresh(request)
    end)
  end

  function editor:GetOrderedDisplays(auraType, includeProtected)
    local output = {}

    for _, display in pairs(self:GetDisplays() or {}) do
      if display.auraType == auraType and (includeProtected or not display.protected) then
        output[#output + 1] = display
      end
    end

    table.sort(output, function(left, right)
      local leftOrder = tonumber(left.order) or 0
      local rightOrder = tonumber(right.order) or 0

      if leftOrder == rightOrder then
        return left.id < right.id
      end

      return leftOrder < rightOrder
    end)

    return output
  end

  function editor:ReindexCategory(auraType)
    local baseOrder = auraType == "HARMFUL" and 1200 or 300

    for index, display in ipairs(self:GetOrderedDisplays(auraType, false)) do
      display.order = baseOrder + (index * 10)
    end
  end

  function editor:MutateSelected(callback, rebuildOptions, changeType)
    if UFCB_BlockCombat() then
      return
    end

    local display = self:GetSelectedDisplay()
    if not display then
      return
    end

    callback(display)
    ns.UFAuraFilters.NormalizeDisplay(display, display.id)
    self:SyncSelection()

    local targetPath = rebuildOptions and self:GetDisplayPath(display.id, display.auraType) or nil
    self:Refresh(rebuildOptions, targetPath, nil, changeType, display.id)
  end

  function editor:MutateSelectedBlacklist(callback)
    local display = self:GetSelectedDisplay()
    if not display or display.builtInKey ~= "DEFAULT_DEBUFF" then
      return
    end

    callback(display)
    ns.UFAuraFilters.NormalizeDisplay(display, display.id)
    self:SyncSelection()
    self:Refresh(
      true,
      self:GetDisplayPath(display.id, display.auraType),
      nil,
      "filter",
      display.id
    )
  end

  function editor:CreateDisplay(displayType, auraType)
    if UFCB_BlockCombat() then
      return
    end

    local auras = getAuras()
    if not auras then
      return
    end

    auraType = auraType == "HARMFUL" and "HARMFUL" or "HELPFUL"
    displayType = displayType == "slot" and "slot" or "group"

    local ordered = self:GetOrderedDisplays(auraType, false)
    local displays = self:GetDisplays()
    local id = math.floor(tonumber(auras.nextCustomDisplayID) or 1)

    while displays[id] do
      id = id + 1
    end

    local baseOrder = auraType == "HARMFUL" and 1200 or 300
    local display = ns.UFAuraFilters.CreateDisplay(id)

    display.displayType = displayType
    display.auraType = auraType
    display.order = ordered[#ordered] and ((tonumber(ordered[#ordered].order) or baseOrder) + 10) or (baseOrder + 10)

    display.name = (displayType == "slot" and "Aura Slot " or "Aura Group ") .. tostring(id)

    if displayType == "slot" then
      display.spellFilterMode = "WHITELIST"
      display.includeSpellIDs = {}
      display.excludeSpellIDs = {}
      display.maxIcons = 1
    end

    displays[id] = ns.UFAuraFilters.NormalizeDisplay(display, id)
    auras.nextCustomDisplayID = id + 1
    auras.selectedCustomDisplayID = id

    self:ReindexCategory(auraType)

    local afterSelect
    if displayType == "slot" then
      afterSelect = function()
        UFCB_FocusAuraSlotSpellID(id)
      end
    end

    self:Refresh(true, self:GetDisplayPath(id, auraType), afterSelect, "topology", id)
  end

  function editor:DeleteSelectedDisplay()
    if UFCB_BlockCombat() then
      return
    end

    local auras = getAuras()
    local displays = self:GetDisplays()
    local selectedID = self:GetSelectedID()
    if not auras or not displays or not selectedID then
      return
    end

    local display = displays[selectedID]
    if not display or display.protected then
      return
    end

    local auraType = display.auraType
    local remainingDisplays = {}

    for id, candidate in pairs(displays) do
      id = math.floor(tonumber(id) or 0)

      if id > 0 and id ~= selectedID then
        remainingDisplays[id] = candidate
      end
    end

    auras.customDisplays = remainingDisplays
    auras.selectedCustomDisplayID = nil
    self:ReindexCategory(auraType)

    local builtInIDs = ns.UFAuraFilters.BUILT_IN_DISPLAY_IDS
    local replacementID = auraType == "HARMFUL"
      and builtInIDs.DEFAULT_DEBUFF
      or builtInIDs.DEFAULT_BUFF

    auras.selectedCustomDisplayID = replacementID
    self:Refresh(true, self:GetDisplayPath(replacementID, auraType), nil, "topology", selectedID)
  end

  function editor:ResetSelectedDisplay()
    if UFCB_BlockCombat() then
      return
    end

    local auras = getAuras()
    local display = self:GetSelectedDisplay()

    if not auras or not display or type(self.defaultAuras) ~= "table" then
      return
    end

    local builtInKey = display.builtInKey
    if builtInKey ~= "DEFAULT_BUFF"
      and builtInKey ~= "DEFENSIVES_EXTERNALS"
      and builtInKey ~= "IMPORTANT_BUFFS"
      and builtInKey ~= "DEFAULT_DEBUFF"
    then
      return
    end

    local displayID = display.id
    local auraType = display.auraType

    if ns.UFAuraFilters.ResetBuiltInDisplay(auras, builtInKey, self.defaultAuras) then
      self:Refresh(true, self:GetDisplayPath(displayID, auraType), nil, "topology", displayID)
    end
  end

  function editor:FieldsDisabled()
    return self:GetSelectedDisplay() == nil
  end

  function editor:IsGroupDisplay()
    local display = self:GetSelectedDisplay()
    return display and display.displayType == "group" or false
  end

  function editor:IsSlotDisplay()
    local display = self:GetSelectedDisplay()
    return display and display.displayType == "slot" or false
  end

  function editor:IsSelectedProtected()
    local display = self:GetSelectedDisplay()
    return display and display.protected == true or false
  end

  function editor:GetSelectedAuraType()
    local display = self:GetSelectedDisplay()
    return display and display.auraType or "HELPFUL"
  end

  return editor
end

local function UFCB_BuildCustomAuraDisplaysArgs(getAuras, refresh, displayID, defaultAuras, unitKey)
  local editor = UFCB_CreateCustomAuraEditor(getAuras, refresh, displayID, unitKey, defaultAuras)
  local changeTypesByField = {
    enabled = "state",
    showDefensives = "state",
    showExternals = "state",
    spellFilterMode = "filter",
    includeSpellIDs = "filter",
    excludeSpellIDs = "filter",
    filterPreset = "filter",
    onlyPlayer = "filter",
    bossAura = "filter",
    bossOrRoleAura = "filter",
    maxDuration = "filter",
    hidePermanent = "filter",
    hideRaidBuff = "filter",
    hideSated = "filter",
    iconSize = "layout",
    anchorPoint = "layout",
    relativePoint = "layout",
    xOffset = "layout",
    yOffset = "layout",
    maxIcons = "layout",
    spacing = "layout",
    growthX = "layout",
    growthY = "layout",
    sortMethod = "sort",
    sortDirection = "sort",
  }

  local function GetDisplay()
    local display = editor:GetSelectedDisplay()

    if display then
      editor:SyncSelection()
    end

    return display
  end

  local function GetValue(key, fallback)
    local display = GetDisplay()
    local value = display and display[key]

    if value == nil then
      return fallback
    end

    return value
  end

  local function SetValue(key, value, rebuildOptions)
    editor:MutateSelected(function(display)
      display[key] = value
    end, rebuildOptions, changeTypesByField[key] or "display")
  end

  local function FieldsDisabled()
    return editor:FieldsDisabled()
  end

  local function GroupOnlyDisabled()
    return FieldsDisabled() or not editor:IsGroupDisplay()
  end

  local function IsDefensivesDisplay()
    local display = GetDisplay()
    return display and display.specialType == "DEFENSIVES_EXTERNALS" or false
  end

  local function IsImportantBuffsDisplay()
    local display = GetDisplay()
    return display and display.specialType == "IMPORTANT_BUFFS" or false
  end

  local function IsFixedHelpfulDisplay()
    return IsDefensivesDisplay() or IsImportantBuffsDisplay()
  end

  local function IsDefaultDebuffDisplay()
    local display = GetDisplay()
    return display and display.builtInKey == "DEFAULT_DEBUFF" or false
  end

  local function IsDefaultDebuffBlacklistAvailable()
    return IsDefaultDebuffDisplay()
      and (unitKey == "target" or unitKey == "focus" or unitKey == "boss")
  end

  local function UsesDefaultDebuffEncounterUnion()
    return IsDefaultDebuffDisplay()
      and GetValue("includeBossAuras", false) == true
      and GetValue("onlyPlayer", false) == true
  end

  local function GetBlacklistUnitLabel()
    if unitKey == "boss" then
      return "boss frames"
    end

    return unitKey or "unit frame"
  end

  local function GetBlacklistedSpellValues()
    local values = {}

    for spellID in pairs(GetValue("excludeSpellIDs", {})) do
      spellID = tonumber(spellID)
      if spellID then
        local spellName = C_Spell.GetSpellName(spellID)
        values[spellID] = spellName
          and (spellName .. " (" .. tostring(spellID) .. ")")
          or tostring(spellID)
      end
    end

    return values
  end

  local function HasBlacklistedSpells()
    return next(GetValue("excludeSpellIDs", {})) ~= nil
  end

  local function IsAppearanceOwner(display)
    display = display or GetDisplay()

    return display
      and (display.builtInKey == "DEFAULT_BUFF" or display.builtInKey == "DEFAULT_DEBUFF")
      or false
  end

  local function GetAppearanceStore(display)
    if not display then
      return nil
    end

    if IsAppearanceOwner(display) then
      display.appearance = type(display.appearance) == "table" and display.appearance or {}
      return display.appearance
    end

    display.appearanceOverrides = type(display.appearanceOverrides) == "table"
      and display.appearanceOverrides
      or {}
    return display.appearanceOverrides
  end

  local function GetEffectiveAppearanceValue(key, fallback)
    local display = GetDisplay()
    if not display then
      return fallback
    end

    local store = GetAppearanceStore(display)
    if store[key] ~= nil then
      return store[key]
    end

    local auras = getAuras()
    local appearance = ns.UFAuraFilters.BuildEffectiveAppearance(auras, display)
    local value = appearance and appearance[key]

    if value == nil then
      return fallback
    end

    return value
  end

  local function HasAppearanceOverride(key)
    local display = GetDisplay()
    if not display then
      return false
    end

    if IsAppearanceOwner(display) then
      return true
    end

    return GetAppearanceStore(display)[key] ~= nil
  end

  local function SetAppearanceOverride(key, enabled, fallback)
    local inherited = GetEffectiveAppearanceValue(key, fallback)
    local display = GetDisplay()
    local changeType = IsAppearanceOwner(display) and "sharedAppearance" or "appearance"

    editor:MutateSelected(function(display)
      local store = GetAppearanceStore(display)
      store[key] = enabled and inherited or nil
    end, false, changeType)
  end

  local function SetAppearanceValue(key, value)
    local display = GetDisplay()
    local changeType = IsAppearanceOwner(display) and "sharedAppearance" or "appearance"

    editor:MutateSelected(function(display)
      GetAppearanceStore(display)[key] = value
    end, false, changeType)
  end

  local function AppearanceFieldDisabled(key)
    return FieldsDisabled() or not HasAppearanceOverride(key)
  end

  local function IncludeDisabled()
    if editor:IsSlotDisplay() then
      return FieldsDisabled()
    end

    local mode = GetValue("spellFilterMode", "NONE")
    return FieldsDisabled() or (mode ~= "WHITELIST" and mode ~= "BOTH")
  end

  local function ExcludeDisabled()
    if editor:IsSlotDisplay() then
      return true
    end

    local mode = GetValue("spellFilterMode", "NONE")
    return FieldsDisabled() or (mode ~= "BLACKLIST" and mode ~= "BOTH")
  end

  return {
    display = {
      type = "group",
      name = "General",
      order = function()
        return editor:IsSlotDisplay() and 20 or 10
      end,
      inline = true,
      disabled = FieldsDisabled,
      args = {
        enabled = {
          type = "toggle",
          name = "Enabled",
          order = 1,
          get = function()
            return GetValue("enabled", true) ~= false
          end,
          set = function(_, value)
            SetValue("enabled", value and true or false)
          end,
        },
        showDefensives = {
          type = "toggle",
          name = "Show defensives",
          order = 1.1,
          hidden = function()
            return not IsDefensivesDisplay()
          end,
          get = function()
            return GetValue("showDefensives", true) ~= false
          end,
          set = function(_, value)
            SetValue("showDefensives", value and true or false)
          end,
        },
        showExternals = {
          type = "toggle",
          name = "Show externals",
          order = 1.2,
          hidden = function()
            return not IsDefensivesDisplay()
          end,
          get = function()
            return GetValue("showExternals", true) ~= false
          end,
          set = function(_, value)
            SetValue("showExternals", value and true or false)
          end,
        },
        importantBuffsDescription = {
          type = "description",
          name = "Shows major offensive cooldown buffs. Big defensives and external defensives stay in their separate tracker.",
          order = 1.3,
          width = "full",
          hidden = function()
            return not IsImportantBuffsDisplay()
          end,
        },

        displayType = {
          type = "select",
          name = "Type",
          desc = "The display type is fixed when the display is created.",
          order = 3,
          values = UFCB_CUSTOM_AURA_DISPLAY_TYPE_VALUES,
          hidden = IsFixedHelpfulDisplay,
          disabled = true,
          get = function()
            return GetValue("displayType", "group")
          end,
        },
        auraType = {
          type = "select",
          name = "Aura type",
          desc = "Helpful and Harmful displays cannot be converted after creation.",
          order = 4,
          values = UFCB_CUSTOM_AURA_TYPE_VALUES,
          hidden = IsDefensivesDisplay,
          disabled = true,
          get = function()
            return GetValue("auraType", "HELPFUL")
          end,
        },
        reset = {
          type = "execute",
          name = "Reset to default",
          desc = "Restore this built-in aura display to the current PleebUI defaults for this frame type.",
          order = 2,
          width = 0.8,
          hidden = function()
            local display = GetDisplay()
            return not display
              or (
                display.builtInKey ~= "DEFAULT_BUFF"
                and display.builtInKey ~= "DEFENSIVES_EXTERNALS"
                and display.builtInKey ~= "IMPORTANT_BUFFS"
                and display.builtInKey ~= "DEFAULT_DEBUFF"
              )
          end,
          func = function()
            editor:ResetSelectedDisplay()
          end,
        },
        delete = {
          type = "execute",
          name = function()
            return editor:IsSlotDisplay() and "Delete Aura Slot" or "Delete Aura Group"
          end,
          desc = "Permanently delete this custom aura display.",
          order = 2,
          width = 0.8,
          hidden = function()
            return editor:IsSelectedProtected()
          end,
          func = function()
            editor:DeleteSelectedDisplay()
          end,
        },
      },
    },
    spellIDs = {
      type = "group",
      name = function()
        return editor:IsSlotDisplay() and "Tracked aura" or "SpellID filtering"
      end,
      order = function()
        return editor:IsSlotDisplay() and 10 or 20
      end,
      inline = true,
      hidden = function()
        return IsFixedHelpfulDisplay() or IsDefaultDebuffDisplay()
      end,
      disabled = FieldsDisabled,
      args = {
        mode = {
          type = "select",
          name = "SpellID filter mode",
          order = 1,
          values = UFCB_CUSTOM_AURA_FILTER_MODE_VALUES,
          hidden = function()
            return editor:IsSlotDisplay()
          end,
          get = function()
            return GetValue("spellFilterMode", "NONE")
          end,
          set = function(_, value)
            SetValue("spellFilterMode", value, true)
          end,
        },
        midnightWarning = {
          type = "description",
          name = "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:16:16:0:0|t |cffffc107Midnight limitation:|r Harmful exact-SpellID filters are evaluated by Blizzard's secure aura system. The editor can configure them, but cannot verify secret live aura identity in combat.",
          order = 1.5,
          width = "full",
          hidden = function()
            return editor:GetSelectedAuraType() ~= "HARMFUL"
          end,
        },
        includeSpellIDs = {
          __puiAuraSlotSpellID = editor:IsSlotDisplay() and displayID or nil,
          type = "input",
          name = function()
            return editor:IsSlotDisplay() and "SpellID" or "Whitelist SpellIDs"
          end,
          desc = function()
            if editor:IsSlotDisplay() then
              return "Enter the single SpellID tracked by this Aura Slot."
            end

            return "Enter SpellIDs separated by commas, spaces or line breaks."
          end,
          order = 2,
          width = "full",
          disabled = IncludeDisabled,
          get = function()
            return ns.UFAuraFilters.SpellIDsToText(GetValue("includeSpellIDs", {}))
          end,
          set = function(_, value)
            editor:MutateSelected(function(display)
              display.includeSpellIDs = ns.UFAuraFilters.NormalizeSpellIDs(value)
            end, false, "filter")
          end,
        },
        excludeSpellIDs = {
          type = "input",
          name = "Blacklist SpellIDs",
          desc = "Enter SpellIDs separated by commas, spaces or line breaks. A SpellID present in both lists is excluded.",
          order = 3,
          width = "full",
          hidden = function()
            return editor:IsSlotDisplay()
          end,
          disabled = ExcludeDisabled,
          get = function()
            return ns.UFAuraFilters.SpellIDsToText(GetValue("excludeSpellIDs", {}))
          end,
          set = function(_, value)
            editor:MutateSelected(function(display)
              display.excludeSpellIDs = ns.UFAuraFilters.NormalizeSpellIDs(value)
            end, false, "filter")
          end,
        },
      },
    },
    regularFilters = {
      type = "group",
      name = "Filtering",
      order = 25,
      inline = true,
      hidden = IsFixedHelpfulDisplay,
      disabled = FieldsDisabled,
      args = {
        filterPreset = {
          type = "select",
          name = "Base filter",
          desc = function()
            local auraType = GetValue("auraType", "HELPFUL")
            local preset = GetValue("filterPreset", "DEFAULT")
            local descriptions = UFCB_CUSTOM_AURA_FILTER_DESCRIPTIONS[auraType]

            return descriptions and descriptions[preset]
              or "Choose the base aura set. SpellID filters and the options below narrow it further."
          end,
          order = 1,
          hidden = function()
            return editor:IsSlotDisplay() or IsDefaultDebuffDisplay()
          end,
          values = function()
            if GetValue("auraType", "HELPFUL") == "HARMFUL" then
              return UFCB_CUSTOM_AURA_HARMFUL_FILTER_VALUES
            end

            return UFCB_CUSTOM_AURA_HELPFUL_FILTER_VALUES
          end,
          get = function()
            return GetValue("filterPreset", "DEFAULT")
          end,
          set = function(_, value)
            SetValue("filterPreset", value)
          end,
        },
        filterGuide = {
          type = "description",
          name = function()
            local auraType = GetValue("auraType", "HELPFUL")
            local preset = GetValue("filterPreset", "DEFAULT")
            local descriptions = UFCB_CUSTOM_AURA_FILTER_DESCRIPTIONS[auraType]
            local description = descriptions and descriptions[preset] or ""

            if auraType == "HARMFUL" then
              return description
                .. "\n\nThe Base filter selects one Blizzard aura category. Applied by me and the other filters below narrow that result further. Use another Aura Group to show an additional category."
            end

            return description
              .. "\n\nThe Base filter selects one Blizzard aura category. Cast by me and the other filters below narrow that result further. Use another Aura Group to show an additional category."
          end,
          order = 1.5,
          width = "full",
          hidden = function()
            return editor:IsSlotDisplay() or IsDefaultDebuffDisplay()
          end,
        },
        onlyPlayer = {
          type = "toggle",
          name = function()
            return editor:GetSelectedAuraType() == "HARMFUL"
              and "Applied by me"
              or "Cast by me"
          end,
          desc = function()
            if editor:GetSelectedAuraType() == "HARMFUL" then
              return "Show only debuffs applied by you, your pet, or your vehicle."
            end

            return "Show only buffs cast by you, your pet, or your vehicle."
          end,
          order = 2,
          get = function()
            return GetValue("onlyPlayer", false) == true
          end,
          set = function(_, value)
            SetValue("onlyPlayer", value and true or false)
          end,
        },
        bossAura = {
          type = "toggle",
          name = "Only boss auras",
          order = 3,
          hidden = function()
            return editor:IsSlotDisplay() or IsDefaultDebuffDisplay()
          end,
          get = function()
            return GetValue("bossAura", false) == true
          end,
          set = function(_, value)
            editor:MutateSelected(function(display)
              display.bossAura = value and true or false

              if value then
                display.bossOrRoleAura = false
              end
            end, false, "filter")
          end,
        },
        bossOrRoleAura = {
          type = "toggle",
          name = "Boss or role auras",
          order = 4,
          hidden = function()
            return editor:IsSlotDisplay() or IsDefaultDebuffDisplay()
          end,
          get = function()
            return GetValue("bossOrRoleAura", false) == true
          end,
          set = function(_, value)
            editor:MutateSelected(function(display)
              display.bossOrRoleAura = value and true or false

              if value then
                display.bossAura = false
              end
            end, false, "filter")
          end,
        },
        maxDuration = {
          type = "range",
          name = "Maximum duration",
          desc = "Set to 0 to disable the maximum-duration candidate filter.",
          order = 5,
          min = 0,
          max = 10800,
          step = 1,
          get = function()
            return tonumber(GetValue("maxDuration", 0)) or 0
          end,
          set = function(_, value)
            SetValue("maxDuration", tonumber(value) or 0)
          end,
        },
        hidePermanent = {
          type = "toggle",
          name = "Hide permanent auras",
          order = 6,
          hidden = function()
            return editor:IsSlotDisplay()
          end,
          get = function()
            return GetValue("hidePermanent", false) == true
          end,
          set = function(_, value)
            SetValue("hidePermanent", value and true or false)
          end,
        },
        hideRaidBuff = {
          type = "toggle",
          name = "Hide raid buff",
          desc = "Hides the core raid buff provided by your current class.",
          order = 7,
          hidden = function()
            return editor:IsSlotDisplay() or editor:GetSelectedAuraType() ~= "HELPFUL"
          end,
          get = function()
            return GetValue("hideRaidBuff", false) == true
          end,
          set = function(_, value)
            SetValue("hideRaidBuff", value and true or false)
          end,
        },
        hideSated = {
          type = "toggle",
          name = "Hide Sated",
          desc = "Hides Bloodlust-style lockout debuffs.",
          order = 8,
          hidden = function()
            return editor:IsSlotDisplay() or editor:GetSelectedAuraType() ~= "HARMFUL"
          end,
          get = function()
            return GetValue("hideSated", false) == true
          end,
          set = function(_, value)
            SetValue("hideSated", value and true or false)
          end,
        },
      },
    },
    blacklist = {
      type = "group",
      name = "Blacklist",
      desc = "Add Spell IDs to this frame's Default Debuffs blacklist.",
      order = 27,
      inline = true,
      hidden = function()
        return not IsDefaultDebuffBlacklistAvailable()
      end,
      disabled = FieldsDisabled,
      args = {
        enabled = {
          type = "toggle",
          name = "Enable blacklist",
          desc = function()
            return "Enable blacklisting debuffs on the " .. GetBlacklistUnitLabel() .. "."
          end,
          order = 1,
          get = function()
            return GetValue("spellFilterMode", "NONE") == "BLACKLIST"
          end,
          set = function(_, value)
            editor:MutateSelectedBlacklist(function(display)
              display.spellFilterMode = value and "BLACKLIST" or "NONE"
            end)
          end,
        },
        addSpellID = {
          type = "input",
          name = "Add Spell ID",
          desc = "Add a Spell ID to this frame's blacklist.",
          order = 2,
          width = "full",
          disabled = function()
            return GetValue("spellFilterMode", "NONE") ~= "BLACKLIST"
          end,
          validate = function(_, value)
            local spellID = tonumber(value)
            if spellID and spellID > 0 and spellID == math.floor(spellID) then
              return true
            end

            return "Enter a whole Spell ID."
          end,
          get = function()
            return ""
          end,
          set = function(_, value)
            local spellID = math.floor(tonumber(value))

            editor:MutateSelectedBlacklist(function(display)
              display.excludeSpellIDs[spellID] = true
            end)
          end,
        },
        spellIDHelp = {
          type = "description",
          name = function()
            return "While this window is open, mouse over a debuff on the "
              .. GetBlacklistUnitLabel()
              .. " to see its SpellID."
          end,
          order = 3,
          width = "full",
        },
        removeSpellID = {
          type = "select",
          name = "Remove blacklisted spell",
          desc = "View the spells blacklisted for this frame and select one to remove it.",
          order = 4,
          width = "full",
          values = GetBlacklistedSpellValues,
          disabled = function()
            return not HasBlacklistedSpells()
          end,
          confirm = function(_, spellID)
            local label = GetBlacklistedSpellValues()[tonumber(spellID)] or tostring(spellID)
            return "Remove " .. label .. " from this frame's blacklist?"
          end,
          get = function()
            return nil
          end,
          set = function(_, value)
            local spellID = tonumber(value)

            editor:MutateSelectedBlacklist(function(display)
              display.excludeSpellIDs[spellID] = nil
            end)
          end,
        },
      },
    },
    defensiveAppearance = {
      type = "group",
      name = "Appearance",
      order = 5,
      inline = true,
      hidden = function()
        return not IsDefensivesDisplay()
      end,
      disabled = FieldsDisabled,
      args = {
        iconSize = {
          type = "range",
          name = "Icon size",
          order = 1,
          min = 8,
          max = 64,
          step = 1,
          get = function()
            return tonumber(GetValue("iconSize", 20)) or 20
          end,
          set = function(_, value)
            SetValue("iconSize", value)
          end,
        },
        tooltips = {
          type = "toggle",
          name = "Show tooltips",
          order = 2,
          disabled = function()
            local auras = getAuras()
            return AppearanceFieldDisabled("tooltips")
              or not auras
              or auras.tooltips == false
          end,
          get = function()
            return GetEffectiveAppearanceValue("tooltips", true) ~= false
          end,
          set = function(_, value)
            SetAppearanceValue("tooltips", value == true)
          end,
        },
      },
    },
    defensiveLayout = {
      type = "group",
      name = "Position and layout",
      order = 30,
      inline = true,
      hidden = function()
        return not IsDefensivesDisplay()
      end,
      disabled = FieldsDisabled,
      args = {
        spacing = {
          type = "range",
          name = "Spacing",
          order = 1,
          min = 0,
          max = 20,
          step = 1,
          get = function()
            return tonumber(GetValue("spacing", 2)) or 2
          end,
          set = function(_, value)
            SetValue("spacing", value)
          end,
        },
        anchorPoint = {
          type = "select",
          name = "Anchor",
          order = 2,
          values = PARTY_ANCHOR_VALUES,
          get = function()
            return GetValue("anchorPoint", "CENTER")
          end,
          set = function(_, value)
            editor:MutateSelected(function(display)
              display.anchorPoint = value
              display.relativePoint = value
            end, false, "layout")
          end,
        },
        xOffset = {
          type = "range",
          name = "X offset",
          order = 3,
          min = -300,
          max = 300,
          step = 1,
          get = function()
            return tonumber(GetValue("xOffset", 0)) or 0
          end,
          set = function(_, value)
            SetValue("xOffset", value)
          end,
        },
        yOffset = {
          type = "range",
          name = "Y offset",
          order = 4,
          min = -300,
          max = 300,
          step = 1,
          get = function()
            return tonumber(GetValue("yOffset", 0)) or 0
          end,
          set = function(_, value)
            SetValue("yOffset", value)
          end,
        },
      },
    },
    appearance = {
      type = "group",
      name = "Icon and text appearance",
      order = 5,
      inline = true,
      hidden = IsDefensivesDisplay,
      disabled = FieldsDisabled,
      args = {
        iconSize = {
          type = "range",
          name = "Icon size",
          order = 0.5,
          min = 8,
          max = 64,
          step = 1,
          get = function()
            return tonumber(GetValue("iconSize", 20)) or 20
          end,
          set = function(_, value)
            SetValue("iconSize", value)
          end,
        },
        durationOverride = {
          type = "toggle",
          name = "Override duration font size",
          order = 1,
          hidden = function()
            return IsAppearanceOwner()
          end,
          get = function()
            return HasAppearanceOverride("durationTextSize")
          end,
          set = function(_, value)
            SetAppearanceOverride("durationTextSize", value == true, 11)
          end,
        },
        durationTextSize = {
          type = "range",
          name = "Duration font size",
          order = 2,
          min = 6,
          max = 32,
          step = 1,
          disabled = function()
            return AppearanceFieldDisabled("durationTextSize")
          end,
          get = function()
            return tonumber(GetEffectiveAppearanceValue("durationTextSize", 11)) or 11
          end,
          set = function(_, value)
            SetAppearanceValue("durationTextSize", value)
          end,
        },
        stackOverride = {
          type = "toggle",
          name = "Override stack font size",
          order = 3,
          hidden = function()
            return IsAppearanceOwner()
          end,
          get = function()
            return HasAppearanceOverride("stackTextSize")
          end,
          set = function(_, value)
            SetAppearanceOverride("stackTextSize", value == true, 11)
          end,
        },
        stackTextSize = {
          type = "range",
          name = "Stack font size",
          order = 4,
          min = 6,
          max = 32,
          step = 1,
          disabled = function()
            return AppearanceFieldDisabled("stackTextSize")
          end,
          get = function()
            return tonumber(GetEffectiveAppearanceValue("stackTextSize", 11)) or 11
          end,
          set = function(_, value)
            SetAppearanceValue("stackTextSize", value)
          end,
        },
        borderOverride = {
          type = "toggle",
          name = "Override border size",
          order = 5,
          hidden = function()
            return IsAppearanceOwner()
          end,
          get = function()
            return HasAppearanceOverride("borderSize")
          end,
          set = function(_, value)
            SetAppearanceOverride("borderSize", value == true, 1)
          end,
        },
        borderSize = {
          type = "range",
          name = "Border size",
          order = 6,
          min = 0,
          max = 8,
          step = 1,
          disabled = function()
            return AppearanceFieldDisabled("borderSize")
          end,
          get = function()
            return tonumber(GetEffectiveAppearanceValue("borderSize", 1)) or 1
          end,
          set = function(_, value)
            SetAppearanceValue("borderSize", value)
          end,
        },
        tooltipsOverride = {
          type = "toggle",
          name = "Override tooltips",
          order = 7,
          hidden = function()
            return IsAppearanceOwner()
          end,
          get = function()
            return HasAppearanceOverride("tooltips")
          end,
          set = function(_, value)
            SetAppearanceOverride("tooltips", value == true, true)
          end,
        },
        tooltips = {
          type = "toggle",
          name = "Show tooltips",
          order = 8,
          disabled = function()
            return AppearanceFieldDisabled("tooltips")
          end,
          get = function()
            return GetEffectiveAppearanceValue("tooltips", true) ~= false
          end,
          set = function(_, value)
            SetAppearanceValue("tooltips", value == true)
          end,
        },
        swipeOverride = {
          type = "toggle",
          name = "Override cooldown swipe",
          order = 9,
          hidden = function()
            return IsAppearanceOwner()
          end,
          get = function()
            return HasAppearanceOverride("disableSwipe")
          end,
          set = function(_, value)
            SetAppearanceOverride("disableSwipe", value == true, false)
          end,
        },
        disableSwipe = {
          type = "toggle",
          name = "Disable cooldown swipe",
          order = 10,
          disabled = function()
            return AppearanceFieldDisabled("disableSwipe")
          end,
          get = function()
            return GetEffectiveAppearanceValue("disableSwipe", false) == true
          end,
          set = function(_, value)
            SetAppearanceValue("disableSwipe", value == true)
          end,
        },
        countdownOverride = {
          type = "toggle",
          name = "Override countdown text",
          order = 11,
          hidden = function()
            return IsAppearanceOwner()
          end,
          get = function()
            return HasAppearanceOverride("disableCountdownText")
          end,
          set = function(_, value)
            SetAppearanceOverride("disableCountdownText", value == true, false)
          end,
        },
        disableCountdownText = {
          type = "toggle",
          name = "Disable countdown text",
          order = 12,
          disabled = function()
            return AppearanceFieldDisabled("disableCountdownText")
          end,
          get = function()
            return GetEffectiveAppearanceValue("disableCountdownText", false) == true
          end,
          set = function(_, value)
            SetAppearanceValue("disableCountdownText", value == true)
          end,
        },
      },
    },
    layout = {
      type = "group",
      name = "Position and layout",
      order = 30,
      inline = true,
      hidden = IsDefensivesDisplay,
      disabled = FieldsDisabled,
      args = {
        anchorPoint = {
          type = "select",
          name = "Aura group point",
          desc = "The point on the aura group that is attached to the unit frame point below.",
          order = 2,
          values = PARTY_ANCHOR_VALUES,
          get = function()
            return GetValue("anchorPoint", "TOPLEFT")
          end,
          set = function(_, value)
            SetValue("anchorPoint", value)
          end,
        },
        relativePoint = {
          type = "select",
          name = "Unit frame point",
          desc = "The point on the unit frame that the aura group is attached to.",
          order = 2.1,
          values = PARTY_ANCHOR_VALUES,
          get = function()
            return GetValue("relativePoint", GetValue("anchorPoint", "TOPLEFT"))
          end,
          set = function(_, value)
            SetValue("relativePoint", value)
          end,
        },
        xOffset = {
          type = "range",
          name = "X offset",
          order = 3,
          min = -300,
          max = 300,
          step = 1,
          get = function()
            return tonumber(GetValue("xOffset", 0)) or 0
          end,
          set = function(_, value)
            SetValue("xOffset", value)
          end,
        },
        yOffset = {
          type = "range",
          name = "Y offset",
          order = 4,
          min = -300,
          max = 300,
          step = 1,
          get = function()
            return tonumber(GetValue("yOffset", 0)) or 0
          end,
          set = function(_, value)
            SetValue("yOffset", value)
          end,
        },

        maxIcons = {
          type = "range",
          name = function()
            return UsesDefaultDebuffEncounterUnion()
              and "Maximum auras per category"
              or "Maximum auras"
          end,
          desc = function()
            if UsesDefaultDebuffEncounterUnion() then
              return "Sets the separate limits for player-applied debuffs and boss or encounter debuffs."
            end

            return "Party and Raid use Icon size × Maximum auras for maximumLineSize. Player, Target, Focus and Boss use the unit-frame width."
          end,
          order = 6,
          min = 1,
          max = 40,
          step = 1,
          hidden = function()
            return editor:IsSlotDisplay()
          end,
          disabled = GroupOnlyDisabled,
          get = function()
            return tonumber(GetValue("maxIcons", 4)) or 4
          end,
          set = function(_, value)
            SetValue("maxIcons", value)
          end,
        },
        spacing = {
          type = "range",
          name = "Icon spacing",
          order = 7,
          min = 0,
          max = 20,
          step = 1,
          hidden = function()
            return editor:IsSlotDisplay()
          end,
          disabled = GroupOnlyDisabled,
          get = function()
            return tonumber(GetValue("spacing", 2)) or 2
          end,
          set = function(_, value)
            SetValue("spacing", value)
          end,
        },
        growthX = {
          type = "select",
          name = "Horizontal growth",
          order = 8,
          values = UFCB_AURA_GROWTH_X_VALUES,
          hidden = function()
            return editor:IsSlotDisplay()
          end,
          get = function()
            return GetValue("growthX", "RIGHT")
          end,
          set = function(_, value)
            SetValue("growthX", value)
          end,
        },
        growthY = {
          type = "select",
          name = "Vertical growth",
          order = 9,
          values = UFCB_AURA_GROWTH_Y_VALUES,
          hidden = function()
            return editor:IsSlotDisplay()
          end,
          get = function()
            return GetValue("growthY", "DOWN")
          end,
          set = function(_, value)
            SetValue("growthY", value)
          end,
        },
        sortMethod = {
          type = "select",
          name = "Sort method",
          order = 10,
          hidden = function()
            return editor:IsSlotDisplay()
          end,
          values = UFCB_CUSTOM_AURA_SORT_METHOD_VALUES,
          get = function()
            return GetValue("sortMethod", "TIME_REMAINING")
          end,
          set = function(_, value)
            SetValue("sortMethod", value)
          end,
        },
        sortDirection = {
          type = "select",
          name = "Sort direction",
          order = 11,
          hidden = function()
            return editor:IsSlotDisplay()
          end,
          values = UFCB_CUSTOM_AURA_SORT_DIRECTION_VALUES,
          get = function()
            return GetValue("sortDirection", "ASCENDING")
          end,
          set = function(_, value)
            SetValue("sortDirection", value)
          end,
        },
      },
    },
  }
end

local function UFCB_GetAuraManagerTreeLabel(display)
  local name = tostring(display.name or ("Aura display " .. tostring(display.id)))
  local anchor = PARTY_ANCHOR_VALUES[display.anchorPoint] or tostring(display.anchorPoint)
  local amount = display.displayType == "slot"
    and "1 aura"
    or tostring(display.maxIcons) .. " auras"

  return name .. " - " .. anchor .. " / " .. amount
end

local function UFCB_BuildAuraManagerTreeArgs(getAuras, refresh, defaultAuras, unitKey)
  local editor = UFCB_CreateCustomAuraEditor(getAuras, refresh, nil, nil, defaultAuras)
  local displays = editor:GetDisplays()
  local builtInIDs = ns.UFAuraFilters.BUILT_IN_DISPLAY_IDS
  local defaultBuffID = builtInIDs.DEFAULT_BUFF
  local defensivesID = builtInIDs.DEFENSIVES_EXTERNALS
  local importantBuffsID = builtInIDs.IMPORTANT_BUFFS
  local defaultDebuffID = builtInIDs.DEFAULT_DEBUFF
  local tree = {}

  tree.buffs = {
    type = "group",
    name = "Default Buffs",
    order = 1,
    args = UFCB_BuildCustomAuraDisplaysArgs(getAuras, refresh, defaultBuffID, defaultAuras, unitKey),
  }

  if displays[defensivesID] then
    tree.defensives = {
      type = "group",
      name = "Defensives and Externals",
      order = 2,
      args = UFCB_BuildCustomAuraDisplaysArgs(getAuras, refresh, defensivesID, defaultAuras, unitKey),
    }
  end

  if displays[importantBuffsID] then
    tree.important = {
      type = "group",
      name = "Offensive Cooldowns",
      order = 3,
      args = UFCB_BuildCustomAuraDisplaysArgs(getAuras, refresh, importantBuffsID, defaultAuras, unitKey),
    }
  end

  tree.debuffs = {
    type = "group",
    name = "Default Debuffs",
    order = 1000,
    args = UFCB_BuildCustomAuraDisplaysArgs(getAuras, refresh, defaultDebuffID, defaultAuras, unitKey),
  }

  for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
    for _, display in ipairs(editor:GetOrderedDisplays(auraType, false)) do
      local displayID = display.id

      tree["display_" .. tostring(displayID)] = {
        type = "group",
        name = function()
          local current = editor:GetDisplays()[displayID]
          return current and UFCB_GetAuraManagerTreeLabel(current) or "Aura display"
        end,
        order = tonumber(display.order) or displayID,
        args = UFCB_BuildCustomAuraDisplaysArgs(getAuras, refresh, displayID, defaultAuras, unitKey),
      }
    end
  end

  return tree
end

local function UFCB_BuildSharedAuraTabs(opts)
  opts = opts or {}

  local getAuras = opts.getAuras
  local refresh = opts.refresh
  local defaults = opts.defaults or {}
  local inline = opts.inline == true

  local auras = getAuras and getAuras() or nil
  if not auras then
    return UFCB_BuildUnavailableArgs("No aura configuration found.")
  end

  local generalArgs = UFCB_MergeOptionArgs(
    opts.generalPrefixArgs,
    UFCB_BuildAuraGeneralCommonArgs(getAuras, refresh, defaults),
    opts.generalSuffixArgs
  )
  local output = {
    general = {
      type = "group",
      name = "General",
      inline = inline,
      order = 1,
      args = generalArgs,
    },
  }

  generalArgs.showAuraSpellIDs = UFCB_BuildAuraSpellIDTooltipArg(6)
  output.customDisplays = {
    type = "group",
    name = "Aura Manager",
    order = 2,
    childGroups = "tree",
    args = UFCB_BuildAuraManagerTreeArgs(getAuras, refresh, defaults, opts.unitKey),
  }

  return output
end

local function UFCB_BuildUnitAurasArgs(unitKey)
  local cfg = UF:GetConfigUnit(unitKey)
  if not cfg then
    return UFCB_BuildUnavailableArgs("No configuration found for unit '" .. tostring(unitKey) .. "'.")
  end

  local unitDefaults = UF:GetDefaultUnitConfig(unitKey)
  local defaults = unitDefaults and unitDefaults.auras or {}

  local function GetAuras()
    local liveCfg = UF:GetConfigUnit(unitKey)
    if not liveCfg then
      return nil
    end

    liveCfg.auras = liveCfg.auras or {}
    return liveCfg.auras
  end

  local function RefreshAuras(flags)
    flags = type(flags) == "table" and flags or {}
    flags.unit = unitKey
    UFCB_RefreshUFAuras(flags)
  end

  local args = UFCB_BuildSharedAuraTabs({
    getAuras = GetAuras,
    refresh = RefreshAuras,
    defaults = defaults,
    unitKey = unitKey,
    inline = false,
  })

  return args
end

local function UFCB_GetGroupedKind(kind)
  if kind ~= "raid" then
    return "party"
  end

  return "raid"
end

local function UFCB_GetGroupedModule(kind)
  kind = UFCB_GetGroupedKind(kind)
  return ns.Modules[(kind == "raid") and "RaidFrames" or "PartyFrames"]
end

local function UFCB_GetGroupedDB(kind)
  return UFCB_GetGroupedModule(kind).db.profile
end

local function UFCB_SetGroupedModuleEnabled(kind, enabled)
  kind = UFCB_GetGroupedKind(kind)

  if UFCB_BlockCombat() then
    LibStub("AceConfigRegistry-3.0"):NotifyChange("PleebUI")
    return
  end

  local db = UFCB_GetGroupedDB(kind)

  enabled = enabled == true

  if (db.enabled ~= false) == enabled then
    return
  end

  Addon:PUI_ConfirmAction({
    title = "Reload required",
    text = "Changing PleebUI " .. kind .. " frames requires reloading the UI.",
    yesText = "Apply + Reload",
    onYes = function()
      db.enabled = enabled
      ReloadUI()
    end,
    onNo = function()
      LibStub("AceConfigRegistry-3.0"):NotifyChange("PleebUI")
    end,
  })
end

local function UFCB_RefreshGroupedTestPreview(kind)
  kind = UFCB_GetGroupedKind(kind)

  local testMode = ns.TestMode
  local controlKey = "uf." .. kind
  if not testMode:IsActive() or testMode:GetValue(controlKey) ~= true then
    return
  end

  testMode:Refresh("unitframes", "unit-frame-options", controlKey)
end

local function UFCB_RunGroupedRefreshNow(kind, fullRefresh, flags)
  kind = UFCB_GetGroupedKind(kind)

  local m = UFCB_GetGroupedModule(kind)
  if not m:IsEnabled() then
    return
  end

  flags = flags or {}

  if fullRefresh or flags.layout then
    m:SafeRefresh("layout")
    return
  end

  if flags.visibility then
    m:SafeRefresh("visibility")
    return
  end

  if flags.appearance then
    m:SafeRefresh("appearance")
    return
  end

  if flags.resize then
    m:SafeRefresh("resize")
    return
  end

  if flags.data then
    m:SafeRefresh("data")
    return
  end

  local handled = false

  if flags.textures then
    m:RefreshTextures()
    handled = true
  end

  if flags.mouseover then
    m:RefreshMouseoverSettings()
    handled = true
  end

  if flags.targetHighlight then
    m:RefreshTargetHighlight()
    handled = true
  end

  if flags.healthPrediction then
    m:RefreshFrames("healthPrediction")
    handled = true
  end

  if flags.auras then
    m:RefreshAuraDisplay(flags)
    handled = true
  end

  if flags.roleIcons or flags.indicators then
    m:RefreshRoleIcons(flags)
    handled = true
  end

  if flags.threat then
    m:RefreshThreat()
    handled = true
  end

  if flags.colors or flags.healthColor or flags.healthMissingColor or flags.powerMissingColor then
    m:RefreshColors(flags)
    handled = true
  end

  if flags.power then
    m:RefreshPowerLayout()
    handled = true
  end

  if flags.text then
    m:SafeRefresh("text")
    handled = true
  end

  if flags.range then
    m:SafeRefresh("range")
    handled = true
  end

  if not handled then
    m:SafeRefresh()
  end
end

local GroupedRefreshQueue = {}

local function MergeGroupedRefreshFlags(target, source)
  if not source then
    return target
  end

  target = target or {}

  for key, value in pairs(source) do
    if value == true or target[key] == nil then
      target[key] = value
    end
  end

  return target
end

UFCB_RequestGroupedRefresh = function(kind, fullRefresh, flags)
  kind = UFCB_GetGroupedKind(kind)

  ns.UFPreview.RefreshAuraManagerPreview()

  local request = GroupedRefreshQueue[kind]
  if request then
    request.fullRefresh = request.fullRefresh or fullRefresh
    request.flags = MergeGroupedRefreshFlags(request.flags, flags)
    return
  end

  GroupedRefreshQueue[kind] = {
    kind = kind,
    fullRefresh = fullRefresh,
    flags = MergeGroupedRefreshFlags(nil, flags),
  }

  C_Timer.After(0, function()
    local pending = GroupedRefreshQueue[kind]
    GroupedRefreshQueue[kind] = nil

    if pending then
      UFCB_RunGroupedRefreshNow(pending.kind, pending.fullRefresh, pending.flags)
      UFCB_RefreshGroupedTestPreview(pending.kind)
    end
  end)
end

local function UFCB_MutateGrouped(kind, fullRefresh, flags, mutator)
  kind = UFCB_GetGroupedKind(kind)

  if UFCB_BlockCombat() then
    return
  end

  local m = UFCB_GetGroupedModule(kind)
  local db = UFCB_GetGroupedDB(kind)
  if not db or not m then
    return
  end

  mutator(db, m)
  UFCB_RequestGroupedRefresh(kind, fullRefresh, flags)
end

local GROUPED_GENERAL_COMMON_RESET_KEYS = {
  enabled = true,
  width = true,
  height = true,
  powerHeight = true,
  borderSize = true,
  useClassColor = true,
  healthTexture = true,
  powerTexture = true,
  absorbTexture = true,
  threatIndicator = true,
}

local PARTY_GENERAL_RESET_KEYS = {
  hideInRaid = true,
  showPlayer = true,
  showSolo = true,
  orientation = true,
  growthY = true,
  spacing = true,
  groupBy = true,
  sortOrder = true,
  sortDir = true,
  ROLE1 = true,
  ROLE2 = true,
  ROLE3 = true,
  showRaidRoleStrip = true,
  raidRoleStripPosition = true,
  raidRoleStripXOffset = true,
  raidRoleStripYOffset = true,
  raidRoleStripSize = true,
  showLeader = true,
  showRoleIcon = true,
  roleIconPosition = true,
  roleIconXOffset = true,
  roleIconYOffset = true,
  roleIconSize = true,
  showRaidTarget = true,
  raidTargetAnchorPoint = true,
  raidTargetXOffset = true,
  raidTargetYOffset = true,
  raidTargetSize = true,
  showReadyCheck = true,
  showSummon = true,
  showInCombat = true,
  showCombatRes = true,
  showPhase = true,
  statusIconSize = true,
}

local RAID_GENERAL_RESET_KEYS = {
  hideBlizzard = true,
  enableMainTankFrames = true,
  growthDirection = true,
  rowSpacing = true,
  columnSpacing = true,
  lockMembersToGroup = true,
  groupSortOrientation = true,
  showGroupNumbers = true,
  enabledGroups = true,
  sortOrder = true,
  sortDir = true,
  numGroups = true,
  unitsPerColumn = true,
}

local GROUPED_GENERAL_COLOR_RESET_KEYS = {
  healthBar = true,
  healthMissing = true,
}



local function UFCB_BuildPartyGeneralArgs(groupKind, opts)
  opts = opts or {}

  local groupedKind = UFCB_GetGroupedKind(groupKind)
  local isRaid = groupedKind == "raid"
  local groupedDefaults = (
    isRaid and ns.UFDefaults.GetRaidDefaults() or ns.UFDefaults.GetPartyDefaults()
  ).profile
  local groupedResetKeys = isRaid and RAID_GENERAL_RESET_KEYS or PARTY_GENERAL_RESET_KEYS

  local function GetDB()
    return UFCB_GetGroupedDB(groupedKind)
  end

  if not GetDB() then
    return UFCB_BuildUnavailableArgs("No configuration found for grouped frame '" .. tostring(groupedKind) .. "'.")
  end

  local function SetGroupedValue(key, value, flags)
    UFCB_MutateGrouped(groupedKind, true, flags, function(db)
      db[key] = value
    end)
  end

  local function SetGroupedValueWithRefresh(key, value, fullRefresh, flags)
    if fullRefresh == true then
      SetGroupedValue(key, value, flags)
      return
    end

    UFCB_MutateGrouped(groupedKind, false, flags or { appearance = true }, function(db)
      db[key] = value
    end)
  end

  local indicatorRefreshFlagByKey = {
    showRaidRoleStrip = "indicatorRaidRoleStrip",
    raidRoleStripPosition = "indicatorRaidRoleStrip",
    raidRoleStripXOffset = "indicatorRaidRoleStrip",
    raidRoleStripYOffset = "indicatorRaidRoleStrip",
    raidRoleStripSize = "indicatorRaidRoleStrip",
    showLeader = "indicatorRaidRoleStrip",
    showRaidAssistant = "indicatorRaidRoleStrip",
    showMainTank = "indicatorRaidRoleStrip",
    showMainAssist = "indicatorRaidRoleStrip",
    showRoleIcon = "indicatorGroupRole",
    roleIconPosition = "indicatorGroupRole",
    roleIconXOffset = "indicatorGroupRole",
    roleIconYOffset = "indicatorGroupRole",
    roleIconSize = "indicatorGroupRole",
    showRaidTarget = "indicatorRaidTarget",
    raidTargetAnchorPoint = "indicatorRaidTarget",
    raidTargetXOffset = "indicatorRaidTarget",
    raidTargetYOffset = "indicatorRaidTarget",
    raidTargetSize = "indicatorRaidTarget",
    showReadyCheck = "indicatorStatus",
    showSummon = "indicatorStatus",
    showInCombat = "indicatorStatus",
    showCombatRes = "indicatorStatus",
    showPhase = "indicatorStatus",
    statusIconSize = "indicatorStatus",
  }

  local function GetGroupedRefreshFlags(key, flags)
    local indicatorFlag = flags and flags.indicators and indicatorRefreshFlagByKey[key]
    if indicatorFlag then
      flags[indicatorFlag] = true
    end

    return flags
  end

  local function BuildGroupedToggle(key, name, order, opts)
    opts = opts or {}

    return {
      type = "toggle",
      name = name,
      desc = opts.desc,
      order = order,
      
      hidden = opts.hidden,
      disabled = opts.disabled,
      get = opts.get or function()
        local db = GetDB()
        if not db then
          if opts.nilValue ~= nil then
            return opts.nilValue
          end

          return opts.defaultTrue == true
        end

        if opts.defaultTrue then
          return db[key] ~= false
        end

        return db[key] == true
      end,
      set = opts.set or function(_, v)
        SetGroupedValueWithRefresh(
          key,
          v and true or false,
          opts.fullRefresh,
          GetGroupedRefreshFlags(key, opts.flags)
        )
      end,
    }
  end

  local function SetBlizzardRaidFramesHidden(_, value)
    if UFCB_BlockCombat() then
      LibStub("AceConfigRegistry-3.0"):NotifyChange("PleebUI")
      return
    end

    value = value == true

    local db = GetDB()
    if db.hideBlizzard == value then
      return
    end

    Addon:PUI_ConfirmAction({
      title = "Reload required",
      text = "Changing Blizzard raid frames requires reloading the UI.",
      yesText = "Apply + Reload",
      onYes = function()
        GetDB().hideBlizzard = value
        ReloadUI()
      end,
      onNo = function()
        LibStub("AceConfigRegistry-3.0"):NotifyChange("PleebUI")
      end,
    })
  end

  local function SetPartyPlayerShown(_, value)
    if UFCB_BlockCombat() then
      LibStub("AceConfigRegistry-3.0"):NotifyChange("PleebUI")
      return
    end

    value = value == true

    local db = GetDB()
    if db.showPlayer == value then
      return
    end

    Addon:PUI_ConfirmAction({
      title = "Reload required",
      text = "Changing Show self in party requires reloading the UI.",
      yesText = "Apply + Reload",
      onYes = function()
        GetDB().showPlayer = value
        ReloadUI()
      end,
      onNo = function()
        LibStub("AceConfigRegistry-3.0"):NotifyChange("PleebUI")
      end,
    })
  end

  local function BuildGroupedRange(key, name, order, minValue, maxValue, opts)
    opts = opts or {}

    return {
      type = "range",
      name = name,
      desc = opts.desc,
      order = order,
      min = minValue,
      max = maxValue,
      step = opts.step or 1,
      
      hidden = opts.hidden,
      disabled = opts.disabled,
      get = opts.get or function()
        local db = GetDB()
        local value = db and tonumber(db[key]) or nil
        if value == nil then
          return opts.default
        end
        return value
      end,
      set = opts.set or function(_, v)
        SetGroupedValueWithRefresh(key, v, opts.fullRefresh, GetGroupedRefreshFlags(key, opts.flags))
      end,
    }
  end

  local function BuildGroupedSelect(key, name, order, values, opts)
    opts = opts or {}

    return {
      type = "select",
      name = name,
      desc = opts.desc,
      order = order,
      values = values,
      dialogControl = opts.dialogControl,
      
      hidden = opts.hidden,
      disabled = opts.disabled,
      get = opts.get or function()
        local db = GetDB()
        local value = db and db[key] or nil
        return value or opts.default
      end,
      set = opts.set or function(_, v)
        SetGroupedValueWithRefresh(key, v, opts.fullRefresh, GetGroupedRefreshFlags(key, opts.flags))
      end,
    }
  end

  local function BuildGroupedTextureSelect(key, name, order, getValue)
    return BuildGroupedSelect(key, name, order, function()
      return OptionsUtil.BuildStatusbarValues(false)
    end, {
      dialogControl = "LSM30_Statusbar",
      get = getValue,
      set = function(_, v)
        SetGroupedValueWithRefresh(key, v, false, { textures = true })
      end,
    })
  end

  local function BuildGroupedColor(colorKey, name, order, fallback, opts)
    opts = opts or {}

    return {
      type = "color",
      name = name,
      order = order,
      hasAlpha = opts.hasAlpha,
      hidden = opts.hidden,
      disabled = opts.disabled,
      get = function()
        local db = GetDB()
        local c = db and db.colors and db.colors[colorKey] or fallback
        if opts.hasAlpha then
          return c[1] or fallback[1], c[2] or fallback[2], c[3] or fallback[3], c[4] or fallback[4]
        end
        return c[1] or fallback[1], c[2] or fallback[2], c[3] or fallback[3]
      end,
      set = function(_, r, g, b, a)
        UFCB_MutateGrouped(groupedKind, false, opts.flags or { colors = true }, function(db)
          db.colors = db.colors or {}
          db.colors[colorKey] = { r, g, b, a or fallback[4] or 1 }
        end)
      end,
    }
  end

  local function GetThreatIndicatorDB()
    local db = GetDB()
    if not db then
      return nil, nil
    end

    db.threatIndicator = type(db.threatIndicator) == "table" and db.threatIndicator or {}
    local t = db.threatIndicator

    if t.enabled == nil then
      t.enabled = true
    end

    if t.style ~= "BORDER_GLOW" and t.style ~= "FRAME_GLOW" and t.style ~= "BOTH" then
      t.style = "FRAME_GLOW"
    end

    return db, t
  end

  local function MutateThreatIndicator(mutator)
    UFCB_MutateGrouped(groupedKind, false, { threat = true }, function(db)
      db.threatIndicator = type(db.threatIndicator) == "table" and db.threatIndicator or {}

      if db.threatIndicator.enabled == nil then
        db.threatIndicator.enabled = true
      end

      if db.threatIndicator.style ~= "BORDER_GLOW" and db.threatIndicator.style ~= "FRAME_GLOW" and db.threatIndicator.style ~= "BOTH" then
        db.threatIndicator.style = "FRAME_GLOW"
      end

      mutator(db.threatIndicator)
    end)
  end

  local frameOrientationValues = {
    VERTICAL = "Vertical",
    HORIZONTAL = "Horizontal",
  }

  local verticalGrowthValues = {
    DOWN = "Down",
    UP = "Up",
  }

  local sortOrderValues = {
    INDEX = "Group order",
    NAME = "Name",
  }

  local partyGroupByValues = {
    INDEX = "Index",
    NAME = "Name",
    ROLE = "Role",
  }

  local roleOrderValues = {
    TANK = "Tank",
    HEALER = "Healer",
    DAMAGER = "DPS",
  }

  local sortDirectionValues = {
    ASC = "Ascending",
    DESC = "Descending",
  }

  local function NormalizeRoleOrder(db)
    if not db then
      return
    end

    if db.ROLE1 ~= "TANK" and db.ROLE1 ~= "HEALER" and db.ROLE1 ~= "DAMAGER" then
      db.ROLE1 = "TANK"
    end
    if db.ROLE2 ~= "TANK" and db.ROLE2 ~= "HEALER" and db.ROLE2 ~= "DAMAGER" then
      db.ROLE2 = "HEALER"
    end
    if db.ROLE3 ~= "TANK" and db.ROLE3 ~= "HEALER" and db.ROLE3 ~= "DAMAGER" then
      db.ROLE3 = "DAMAGER"
    end
  end

  local function ApplyGeneralDefaults(reloadAfterReset)
    local db = GetDB()

    for key in pairs(GROUPED_GENERAL_COMMON_RESET_KEYS) do
      local value = groupedDefaults[key]
      db[key] = type(value) == "table" and UFCB_CopyTable(value) or value
    end

    for key in pairs(groupedResetKeys) do
      local value = groupedDefaults[key]
      db[key] = type(value) == "table" and UFCB_CopyTable(value) or value
    end

    db.colors = db.colors or {}
    for key in pairs(GROUPED_GENERAL_COLOR_RESET_KEYS) do
      local value = groupedDefaults.colors[key]
      db.colors[key] = type(value) == "table" and UFCB_CopyTable(value) or value
    end

    if reloadAfterReset then
      ReloadUI()
      return
    end

    UFCB_GetGroupedModule(groupedKind):SafeRefresh()
    UFCB_RefreshGroupedTestPreview(groupedKind)
    Addon:NotifyOptionsTreeChanged("unitframes", ns._PUIActiveOptionsPath)
  end

  local function ResetGeneralDefaults()
    if UFCB_BlockCombat() then return end

    local db = GetDB()
    local requiresReload = db.enabled ~= groupedDefaults.enabled
      or (isRaid and db.hideBlizzard ~= groupedDefaults.hideBlizzard)
      or (not isRaid and db.showPlayer ~= groupedDefaults.showPlayer)

    if not requiresReload then
      ApplyGeneralDefaults()
      return
    end

    Addon:PUI_ConfirmAction({
      title = "Reset " .. groupedKind .. " frames",
      text = "Reset these General settings to defaults?\n\nThis will reload the UI.",
      yesText = "Reset + Reload",
      onYes = function()
        ApplyGeneralDefaults(true)
      end,
    })
  end

  local args = {
    core = UFCB_BuildInlineArgsGroup(" ", 1, {
      reset = {
        type = "execute",
        name = "Reset to default",
        desc = "Restore these General settings to the current PleebUI defaults.",
        order = 0.5,
        width = 0.8,
        func = ResetGeneralDefaults,
      },
      enabled = BuildGroupedToggle("enabled", isRaid and "Enable raid frames" or "Enable party frames", 1, {
        get = function()
          local db = GetDB()
          return db and db.enabled or false
        end,
        set = function(_, v)
          UFCB_SetGroupedModuleEnabled(groupedKind, v and true or false)
        end,
      }),
      hideBlizzard = isRaid and BuildGroupedToggle("hideBlizzard", "Hide Blizzard raid frames", 2, {
        desc = "Fully disables Blizzard raid frames. Requires a UI reload.",
        set = SetBlizzardRaidFramesHidden,
      }) or nil,
      enableMainTankFrames = BuildGroupedToggle("enableMainTankFrames", "Enable Main Tank Frames", 2.5, {
        flags = { visibility = true },
        hidden = function()
          return not isRaid
        end,
      }),
    }),
    frameLayout = UFCB_BuildInlineArgsGroup(" ", 2, {
      width = BuildGroupedRange("width", "Frame width", 1, isRaid and 40 or 80, 400, { flags = { resize = true } }),
      height = BuildGroupedRange("height", "Total frame height", 2, 12, 80, { flags = { resize = true } }),
      powerHeight = BuildGroupedRange("powerHeight", "Power height", 3, 0, 20, { flags = { power = true } }),
      borderSize = BuildGroupedRange("borderSize", "Border size", 4, 0, 8, { flags = { resize = true } }),
    }),
    indicators = UFCB_BuildInlineArgsGroup(" ", 4, {
      enableThreatIndicator = {
        type = "toggle",
        name = "Enable aggro indicator",
        order = 0.1,
        get = function()
          local _, t = GetThreatIndicatorDB()
          return t and t.enabled ~= false or false
        end,
        set = function(_, v)
          MutateThreatIndicator(function(t)
            t.enabled = v and true or false
          end)
        end,
      },
      threatIndicatorStyle = {
        type = "select",
        name = "Aggro indicator style",
        order = 0.2,
        values = THREAT_INDICATOR_STYLE_VALUES,
        disabled = function()
          local _, t = GetThreatIndicatorDB()
          return not t or t.enabled == false
        end,
        get = function()
          local _, t = GetThreatIndicatorDB()
          return t and t.style or "FRAME_GLOW"
        end,
        set = function(_, v)
          MutateThreatIndicator(function(t)
            t.style = THREAT_INDICATOR_STYLE_VALUES[v] and v or "FRAME_GLOW"
          end)
        end,
      },
      threatIndicatorBorderSize = {
        type = "range",
        name = "Aggro border size",
        order = 0.3,
        min = 0,
        max = 12,
        step = 1,
        disabled = function()
          local _, t = GetThreatIndicatorDB()
          return not t or t.enabled == false
        end,
        get = function()
          local _, t = GetThreatIndicatorDB()
          return UFCB_GetClampedNumber(t and t.borderSize, 3, 0, 12)
        end,
        set = function(_, v)
          MutateThreatIndicator(function(t)
            t.borderSize = UFCB_GetClampedNumber(v, 3, 0, 12)
          end)
        end,
      },
      raidRoleStrip = {
        type = "group",
        name = "Raid role strip",
        order = 1,
        inline = true,
        args = {
          showRaidRoleStrip = BuildGroupedToggle("showRaidRoleStrip", "Toggle", 1, {
            defaultTrue = true,
            fullRefresh = false,
            flags = { indicators = true },
          }),
          raidRoleStripPosition = BuildGroupedSelect("raidRoleStripPosition", "Anchor Point", 2, TEXT_ANCHOR_VALUES, {
            default = "TOPLEFT",
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRaidRoleStrip ~= false)
            end,
            get = function()
              local db = GetDB()
              local value = db and db.raidRoleStripPosition or nil
              if not TEXT_ANCHOR_VALUES[value] then
                value = "TOPLEFT"
              end
              return value
            end,
          }),
          raidRoleStripXOffset = BuildGroupedRange("raidRoleStripXOffset", "X offset", 3, -64, 64, {
            default = 0,
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRaidRoleStrip ~= false)
            end,
          }),
          raidRoleStripYOffset = BuildGroupedRange("raidRoleStripYOffset", "Y offset", 4, -64, 64, {
            default = 0,
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRaidRoleStrip ~= false)
            end,
          }),
          raidRoleStripSize = BuildGroupedRange("raidRoleStripSize", "Size", 5, 8, 32, {
            default = 12,
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRaidRoleStrip ~= false)
            end,
          }),
          showLeader = BuildGroupedToggle("showLeader", "Show leader", 6, {
            defaultTrue = true,
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRaidRoleStrip ~= false)
            end,
          }),
          showRaidAssistant = BuildGroupedToggle("showRaidAssistant", "Show raid assistant", 7, {
            defaultTrue = true,
            fullRefresh = false,
            flags = { indicators = true },
            hidden = function()
              return not isRaid
            end,
            disabled = function()
              local db = GetDB()
              return not (db and db.showRaidRoleStrip ~= false)
            end,
          }),
          showMainTank = BuildGroupedToggle("showMainTank", "Show main tank", 8, {
            defaultTrue = true,
            fullRefresh = false,
            flags = { indicators = true },
            hidden = function()
              return not isRaid
            end,
            disabled = function()
              local db = GetDB()
              return not (db and db.showRaidRoleStrip ~= false)
            end,
          }),
          showMainAssist = BuildGroupedToggle("showMainAssist", "Show main assist", 9, {
            defaultTrue = true,
            fullRefresh = false,
            flags = { indicators = true },
            hidden = function()
              return not isRaid
            end,
            disabled = function()
              local db = GetDB()
              return not (db and db.showRaidRoleStrip ~= false)
            end,
          }),
        },
      },
      roleIcon = {
        type = "group",
        name = "Group role icon",
        order = 2,
        inline = true,
        args = {
          showRoleIcon = BuildGroupedToggle("showRoleIcon", "Toggle", 1, {
            defaultTrue = true,
            fullRefresh = false,
            flags = { indicators = true },
          }),
          roleIconPosition = BuildGroupedSelect("roleIconPosition", "Anchor Point", 2, TEXT_ANCHOR_VALUES, {
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRoleIcon ~= false)
            end,
            get = function()
              local db = GetDB()
              local value = db and db.roleIconPosition or nil
              if not TEXT_ANCHOR_VALUES[value] then
                value = isRaid and "TOPLEFT" or "BOTTOM"
              end
              return value
            end,
          }),
          roleIconXOffset = BuildGroupedRange("roleIconXOffset", "X offset", 3, -64, 64, {
            default = 0,
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRoleIcon ~= false)
            end,
          }),
          roleIconYOffset = BuildGroupedRange("roleIconYOffset", "Y offset", 4, -64, 64, {
            default = 0,
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRoleIcon ~= false)
            end,
          }),
          roleIconSize = BuildGroupedRange("roleIconSize", "Size", 5, 8, 32, {
            default = 17,
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRoleIcon ~= false)
            end,
          }),
        },
      },
      raidMarker = {
        type = "group",
        name = "Raid marker",
        order = 3,
        inline = true,
        args = {
          showRaidTarget = BuildGroupedToggle("showRaidTarget", "Toggle", 1, {
            defaultTrue = true,
            fullRefresh = false,
            flags = { indicators = true },
          }),
          raidTargetAnchorPoint = BuildGroupedSelect("raidTargetAnchorPoint", "Anchor Point", 2, TEXT_ANCHOR_VALUES, {
            default = "TOP",
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRaidTarget ~= false)
            end,
            get = function()
              local db = GetDB()
              local value = db and db.raidTargetAnchorPoint or nil
              if not TEXT_ANCHOR_VALUES[value] then
                value = "TOP"
              end
              return value
            end,
          }),
          raidTargetXOffset = BuildGroupedRange("raidTargetXOffset", "X offset", 3, -64, 64, {
            default = 0,
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRaidTarget ~= false)
            end,
          }),
          raidTargetYOffset = BuildGroupedRange("raidTargetYOffset", "Y offset", 4, -64, 64, {
            default = 0,
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRaidTarget ~= false)
            end,
          }),
          raidTargetSize = BuildGroupedRange("raidTargetSize", "Size", 5, 8, 60, {
            default = 18,
            fullRefresh = false,
            flags = { indicators = true },
            disabled = function()
              local db = GetDB()
              return not (db and db.showRaidTarget ~= false)
            end,
          }),
        },
      },
      remainingIndicators = {
        type = "group",
        name = "Remaining indicators",
        order = 4,
        inline = true,
        args = {
          showReadyCheck = BuildGroupedToggle("showReadyCheck", "Show ready check", 1, {
            defaultTrue = true,
            fullRefresh = false,
            flags = { indicators = true },
          }),
          showSummon = BuildGroupedToggle("showSummon", "Show summon", 2, {
            defaultTrue = true,
            fullRefresh = false,
            flags = { indicators = true },
          }),
          showInCombat = BuildGroupedToggle("showInCombat", "Show in combat", 3, {
            defaultTrue = true,
            fullRefresh = false,
            flags = { indicators = true },
          }),
          showCombatRes = BuildGroupedToggle("showCombatRes", "Show combat res", 4, {
            defaultTrue = true,
            fullRefresh = false,
            flags = { indicators = true },
          }),
          showPhase = BuildGroupedToggle("showPhase", "Show phase", 5, {
            defaultTrue = true,
            fullRefresh = false,
            flags = { indicators = true },
          }),
          statusIconSize = BuildGroupedRange("statusIconSize", "Size", 6, 8, 48, {
            default = 18,
            fullRefresh = false,
            flags = { indicators = true },
          }),
        },
      },
    }),
    colors = UFCB_BuildInlineArgsGroup("Colors", 5, {
      useClassColor = BuildGroupedToggle("useClassColor", "Use class color", 1, { defaultTrue = true, fullRefresh = false, flags = { healthColor = true } }),
      unitFrameColor = BuildGroupedColor("healthBar", "Unit frame color", 2, { 0.35, 0.35, 0.35, 1 }, {
        flags = { healthColor = true },
        hidden = function()
          local db = GetDB()
          return db and db.useClassColor ~= false or false
        end,
      }),
      missingHealthColor = BuildGroupedColor("healthMissing", "Missing health color", 3, { 0.15, 0.15, 0.15, 0.95 }, {
        hasAlpha = true,
        flags = { healthMissingColor = true },
      }),
    }),
    textures = UFCB_BuildInlineArgsGroup("Textures", 5.5, {
      healthTexture = BuildGroupedTextureSelect("healthTexture", "Health bar texture", 1, function()
        local db = GetDB()
        return db and (db.healthTexture or "Pleebar") or "Pleebar"
      end),
      powerTexture = BuildGroupedTextureSelect("powerTexture", "Power bar texture", 2, function()
        local db = GetDB()
        return db and (db.powerTexture or db.healthTexture or "Pleebar") or "Pleebar"
      end),
      absorbTexture = BuildGroupedTextureSelect("absorbTexture", "Absorb texture", 3, function()
        local db = GetDB()
        return db and (db.absorbTexture or db.healthTexture or "Pleebar") or "Pleebar"
      end),
    }),
  }

  if not isRaid then
    args.core.args.showSelfInParty = BuildGroupedToggle("showPlayer", "Show self in party", 5, {
      desc = "Requires a UI reload.",
      set = SetPartyPlayerShown,
    })
    args.core.args.showSolo = BuildGroupedToggle("showSolo", "Show party while solo", 5.5, {
      
      desc = "Show party frames while you are not in a group.",
      flags = { visibility = true },
    })
    args.core.args.hideInRaid = BuildGroupedToggle("hideInRaid", "Hide in raid", 6, {
      
      defaultTrue = true,
      flags = { visibility = true },
    })

    args.frameLayout.args.orientation = BuildGroupedSelect("orientation", "Orientation", 4, frameOrientationValues)
    args.frameLayout.args.growthY = BuildGroupedSelect("growthY", "Vertical growth", 5, verticalGrowthValues, {
      disabled = function()
        local db = GetDB()
        return db and db.orientation == "HORIZONTAL" or false
      end,
    })
    args.frameLayout.args.spacing = BuildGroupedRange("spacing", "Spacing", 6, 0, 40)

    args.sorting = UFCB_BuildInlineArgsGroup(" ", 6, {
      groupBy = BuildGroupedSelect("groupBy", "Group by", 1, partyGroupByValues, {
        flags = { layout = true },
        get = function()
          local db = GetDB()
          local value = db and db.groupBy or nil
          if value ~= "NAME" and value ~= "ROLE" then
            value = "INDEX"
          end
          return value
        end,
        set = function(_, v)
          UFCB_MutateGrouped(groupedKind, true, { layout = true }, function(db)
            if v ~= "NAME" and v ~= "ROLE" then
              v = "INDEX"
            end

            db.groupBy = v
            if v == "ROLE" then
              NormalizeRoleOrder(db)
            end
          end)
        end,
      }),
      sortOrder = BuildGroupedSelect("sortOrder", "Sort method", 2, sortOrderValues, {
        flags = { layout = true },
        disabled = function()
          local db = GetDB()
          return not db or db.groupBy ~= "ROLE"
        end,
        get = function()
          local db = GetDB()
          local value = db and db.sortOrder or nil
          if value ~= "NAME" then
            value = "INDEX"
          end
          return value
        end,
      }),
      sortDir = BuildGroupedSelect("sortDir", "Sort direction", 3, sortDirectionValues, {
        flags = { layout = true },
        get = function()
          local db = GetDB()
          local value = db and db.sortDir or nil
          if value ~= "DESC" then
            value = "ASC"
          end
          return value
        end,
      }),
      roleSetup = {
        type = "group",
        name = "Role order",
        order = 4,
        inline = true,
        disabled = function()
          local db = GetDB()
          return not db or db.groupBy ~= "ROLE"
        end,
        args = {
          ROLE1 = BuildGroupedSelect("ROLE1", "First", 1, roleOrderValues, {
            flags = { layout = true },
            get = function()
              local db = GetDB()
              return db and db.ROLE1 or "TANK"
            end,
          }),
          ROLE2 = BuildGroupedSelect("ROLE2", "Second", 2, roleOrderValues, {
            flags = { layout = true },
            get = function()
              local db = GetDB()
              return db and db.ROLE2 or "HEALER"
            end,
          }),
          ROLE3 = BuildGroupedSelect("ROLE3", "Third", 3, roleOrderValues, {
            flags = { layout = true },
            get = function()
              local db = GetDB()
              return db and db.ROLE3 or "DAMAGER"
            end,
          }),
        },
      },
    })
  else
    args.frameLayout.args.growthDirection = BuildGroupedSelect("growthDirection", "Growth direction", 4, {
      RIGHT_DOWN = "Right then down",
      LEFT_DOWN = "Left then down",
      RIGHT_UP = "Right then up",
      LEFT_UP = "Left then up",
    })
    args.frameLayout.args.rowSpacing = BuildGroupedRange("rowSpacing", "Row spacing", 5, 0, 20)
    args.frameLayout.args.columnSpacing = BuildGroupedRange("columnSpacing", "Column spacing", 6, 0, 20)

    local displayGroupArgs = {}
    for groupIndex = 1, 8 do
      local index = groupIndex
      displayGroupArgs["group" .. tostring(index)] = {
        type = "toggle",
        name = tostring(index),
        order = index,
        width = "normal",
        get = function()
          local db = GetDB()
          local enabledGroups = type(db and db.enabledGroups) == "table" and db.enabledGroups or nil

          if enabledGroups then
            local shown = enabledGroups[index]
            if shown == nil then
              shown = enabledGroups[tostring(index)]
            end

            if shown ~= nil then
              return shown == true
            end
          end

          return true
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end

          UFCB_MutateGrouped(groupedKind, true, { visibility = true }, function(db)
            db.enabledGroups = type(db.enabledGroups) == "table" and db.enabledGroups or {}
            db.enabledGroups[index] = v and true or false
          end)
        end,
      }
    end

    args.groupLayout = UFCB_BuildInlineArgsGroup(" ", 6, {
      sortPerGroup = BuildGroupedToggle("lockMembersToGroup", "Sort per Group", 1, {
        desc = "Keep raid members in their own raid groups instead of filling one flat grid.",
        
        defaultTrue = true,
      }),
      groupSortOrientation = BuildGroupedSelect("groupSortOrientation", "Group Orientation", 2, frameOrientationValues, {
        disabled = function()
          local db = GetDB()
          return not db or db.lockMembersToGroup == false
        end,
        get = function()
          local db = GetDB()
          if db and db.groupSortOrientation == "VERTICAL" then
            return "VERTICAL"
          end

          return "HORIZONTAL"
        end,
      }),
      showGroupNumbers = BuildGroupedToggle("showGroupNumbers", "Show group numbers", 3, {
        desc = "Show a group label above each raid group when Sort per Group is enabled.",
        
        defaultTrue = true,
        disabled = function()
          local db = GetDB()
          return not db or db.lockMembersToGroup == false
        end,
      }),
      displayGroups = {
        type = "group",
        name = "Display groups",
        order = 4,
        inline = true,
        disabled = function()
          local db = GetDB()
          return not db or db.lockMembersToGroup == false
        end,
        args = displayGroupArgs,
      },
    })

    args.layout = UFCB_BuildInlineArgsGroup(" ", 7, {
      sortOrder = BuildGroupedSelect("sortOrder", "Sort method", 1, sortOrderValues, {
        get = function()
          local db = GetDB()
          local value = db and db.sortOrder or nil
          if value ~= "NAME" then
            value = "INDEX"
          end
          return value
        end,
      }),
      sortDirection = BuildGroupedSelect("sortDir", "Sort direction", 2, sortDirectionValues),
      numGroups = BuildGroupedRange("numGroups", "Groups", 3, 1, 8),
      unitsPerColumn = BuildGroupedRange("unitsPerColumn", "Units per column", 4, 1, 5, {
        disabled = function()
          local db = GetDB()
          if not db then
            return true
          end

          return db.lockMembersToGroup ~= false
        end,
      }),
    })
  end

  if isRaid and opts.keepIndicators ~= true then
    args.indicators = nil
  end

  return args
end


local function UFCB_BuildRaidIndicatorArgs()
  local general = UFCB_BuildPartyGeneralArgs("raid", { keepIndicators = true })
  local indicators = general and general.indicators and general.indicators.args or {}

  return UFCB_MergeOptionArgs({
    helper = {
      type = "description",
      name = "Raid frame indicators such as ready check, role, tank, in combat etc",
      order = 0,
      fontSize = "medium",
    },
  }, indicators)
end


local function UFCB_BuildPartyTextArgs(kind, groupKind)
  local groupedKind = UFCB_GetGroupedKind(groupKind)

  local config = {
    name = {
      sizeName = "Name text size",
      sizeKey = "sizeName",
      fontKey = "nameFont",
      outlineKey = "nameOutline",
      anchorKey = "anchorName",
      offsetXKey = "offsetNameX",
      offsetYKey = "offsetNameY",
      sizeOrder = 2,
      fontOrder = 3,
      outlineOrder = 4,
      anchorOrder = 5,
      offsetXOrder = 6,
      offsetYOrder = 7,
      colors = {
        {
          key = "nameTextColor",
          name = "Name text color",
          order = 1,
          colorKey = "nameText",
        },
      },
    },
    health = {
      modeKey = "healthMode",
      modeName = "Health text mode",
      sizeName = "Health text size",
      sizeKey = "sizeHealth",
      fontKey = "healthFont",
      outlineKey = "healthOutline",
      anchorKey = "anchorHealth",
      offsetXKey = "offsetHealthX",
      offsetYKey = "offsetHealthY",
      sizeOrder = 4,
      fontOrder = 5,
      outlineOrder = 6,
      anchorOrder = 7,
      offsetXOrder = 8,
      offsetYOrder = 9,
      colors = {
        {
          key = "missingHPColor",
          name = "Missing HP color",
          order = 2,
          colorKey = "healthMissing",
        },
        {
          key = "healthTextColor",
          name = "Health text color",
          order = 3,
          colorKey = "healthText",
        },
      },
    },
    power = {
      modeKey = "powerMode",
      modeName = "Power text mode",
      sizeName = "Power text size",
      sizeKey = "sizePower",
      fontKey = "powerFont",
      outlineKey = "powerOutline",
      anchorKey = "anchorPower",
      offsetXKey = "offsetPowerX",
      offsetYKey = "offsetPowerY",
      sizeOrder = 4,
      fontOrder = 5,
      outlineOrder = 6,
      anchorOrder = 7,
      offsetXOrder = 8,
      offsetYOrder = 9,
      colors = {
        {
          key = "powerMissingColor",
          name = "Missing power color",
          order = 2,
          colorKey = "powerMissing",
        },
        {
          key = "powerTextColor",
          name = "Power text color",
          order = 3,
          colorKey = "powerText",
        },
      },
    },
  }

  local cfg = config[kind]
  if not cfg then
    return UFCB_BuildUnavailableArgs("Invalid grouped text config.")
  end

  local function GetDB()
    return UFCB_GetGroupedDB(groupedKind)
  end

  if not GetDB() then
    return UFCB_BuildUnavailableArgs("No configuration found for grouped frame '" .. tostring(groupedKind) .. "'.")
  end

  local function SetGroupedValue(key, value, flags)
    local refreshFlags = flags

    if type(refreshFlags) ~= "table" then
      if key == "healthTexture" or key == "powerTexture" or key == "absorbTexture" then
        refreshFlags = { textures = true }
      elseif key == "orientation"
        or key == "growthY"
        or key == "spacing"
        or key == "sortOrder"
        or key == "sortDir"
        or key == "roleSortOrder"
        or key == "growthDirection"
        or key == "rowSpacing"
        or key == "columnSpacing"
        or key == "lockMembersToGroup"
        or key == "groupSortOrientation"
        or key == "moveGroupsSeparately"
      then
        refreshFlags = { layout = true }
      end
    end

    UFCB_MutateGrouped(groupedKind, false, refreshFlags, function(db)
      db[key] = value
    end)
  end

  local function SetTextValue(key, value)
    UFCB_MutateGrouped(groupedKind, false, { text = true }, function(db)
      db.text = db.text or {}
      db.text[key] = value
    end)
  end

  local function SetColorValue(key, value)
    local flags

    if key == "healthMissing" then
      flags = { healthMissingColor = true }
    elseif key == "powerMissing" then
      flags = { powerMissingColor = true }
    else
      flags = { text = true }
    end

    UFCB_MutateGrouped(groupedKind, false, flags, function(db)
      db.colors = db.colors or {}
      db.colors[key] = value
    end)
  end

  local function BuildGroupedTextModeArg()
    return {
      type = "select",
      name = cfg.modeName,
      order = 1,
      values = TEXT_MODE_VALUES,
      get = function()
        local db = GetDB()
        local t = db and db.text or nil
        local cur = t and t[cfg.modeKey] or nil
        if cur == "CUR_PCT" then
          cur = "CUR_PERCENT"
        end
        return cur
      end,
      set = function(_, v)
        SetTextValue(cfg.modeKey, v)
      end,
    }
  end

  local function BuildGroupedTextColorArg(colorDef)
    return {
      type = "color",
      name = colorDef.name,
      order = colorDef.order,
      hasAlpha = true,
      get = function()
        local db = GetDB()
        local c = db and db.colors and db.colors[colorDef.colorKey] or nil
        if type(c) ~= "table" then
          if colorDef.colorKey == "healthMissing" or colorDef.colorKey == "powerMissing" then
            c = { 0.15, 0.15, 0.15, 0.95 }
          else
            c = { 1, 1, 1, 1 }
          end
        end
        return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
      end,
      set = function(_, r, g, b, a)
        SetColorValue(colorDef.colorKey, { r, g, b, a or 1 })
      end,
    }
  end

  local function BuildGroupedTextTextureArg(key, name, order, getValue)
    return {
      type = "select",
      dialogControl = "LSM30_Statusbar",
      name = name,
      order = order,
      
      values = function()
        return OptionsUtil.BuildStatusbarValues(false)
      end,
      get = getValue,
      set = function(_, v)
        SetGroupedValue(key, v, { textures = true })
      end,
    }
  end

  local function BuildGroupedFrameHeightArg()
    return {
      type = "range",
      name = "Unit frame height",
      order = 0.5,
      min = 12,
      max = 80,
      step = 1,
      get = function()
        local db = GetDB()
        return db and tonumber(db.height) or nil
      end,
      set = function(_, v)
        UFCB_MutateGrouped(groupedKind, false, { resize = true }, function(db)
          db.height = v
        end)
      end,
    }
  end

  local function BuildGroupedHidePowerArg()
    return {
      type = "toggle",
      name = "Hide power",
      desc = "Hide the power bar and its text.",
      order = 0.5,
      get = function()
        local db = GetDB()
        return db and db.showPower == false or false
      end,
      set = function(_, v)
        UFCB_MutateGrouped(groupedKind, false, { power = true }, function(db)
          db.showPower = v ~= true
        end)
      end,
    }
  end

  local function BuildGroupedPowerHeightArg()
    return {
      type = "range",
      name = "Power height",
      order = 0.6,
      min = 0,
      max = 20,
      step = 1,
      get = function()
        local db = GetDB()
        return db and tonumber(db.powerHeight) or nil
      end,
      set = function(_, v)
        UFCB_MutateGrouped(groupedKind, false, { power = true }, function(db)
          db.powerHeight = v
        end)
      end,
    }
  end

  local prefixArgs = {}
  local suffixArgs = {}

  if cfg.modeKey then
    prefixArgs.mode = BuildGroupedTextModeArg()
  end

  for _, colorDef in ipairs(cfg.colors or {}) do
    prefixArgs[colorDef.key] = BuildGroupedTextColorArg(colorDef)
  end

  if kind == "health" then
    suffixArgs.healthTexture = BuildGroupedTextTextureArg("healthTexture", "Health bar texture", 20, function()
      local db = GetDB()
      return db and (db.healthTexture or "Pleebar") or "Pleebar"
    end)

    suffixArgs.absorbTexture = BuildGroupedTextTextureArg("absorbTexture", "Absorb texture", 21, function()
      local db = GetDB()
      return db and (db.absorbTexture or db.healthTexture or "Pleebar") or "Pleebar"
    end)
  elseif kind == "power" then
    suffixArgs.powerTexture = BuildGroupedTextTextureArg("powerTexture", "Power bar texture", 20, function()
      local db = GetDB()
      return db and (db.powerTexture or db.healthTexture or "Pleebar") or "Pleebar"
    end)
  end

  local flatArgs = UFCB_BuildSharedTextLeafArgs({
    prefixArgs = prefixArgs,
    suffixArgs = suffixArgs,
    sizeName = cfg.sizeName,
    sizeOrder = cfg.sizeOrder,
    fontOrder = cfg.fontOrder,
    outlineOrder = cfg.outlineOrder,
    anchorOrder = cfg.anchorOrder,
    offsetXOrder = cfg.offsetXOrder,
    offsetYOrder = cfg.offsetYOrder,
    anchorValues = PARTY_ANCHOR_VALUES,
    getSize = function()
      local db = GetDB()
      local t = db and db.text or nil
      return t and tonumber(t[cfg.sizeKey]) or nil
    end,
    setSize = function(_, v)
      SetTextValue(cfg.sizeKey, v)
    end,
    getUseGlobalFont = function()
      local db = GetDB()
      local t = db and db.text or nil
      local useGlobalKey = cfg.fontKey and cfg.fontKey:gsub("Font$", "UseGlobalFont") or "useGlobalFont"
      local cur = t and (t[cfg.fontKey] or t.font)
      local flag = t and t[useGlobalKey]
      return UFCB_IsUsingGlobalFont(cur, flag)
    end,
    setUseGlobalFont = function(_, v)
      local useGlobalKey = cfg.fontKey and cfg.fontKey:gsub("Font$", "UseGlobalFont") or "useGlobalFont"
      SetTextValue(useGlobalKey, v and true or false)
    end,
    getFont = function()
      local db = GetDB()
      local t = db and db.text or nil
      local useGlobalKey = cfg.fontKey and cfg.fontKey:gsub("Font$", "UseGlobalFont") or "useGlobalFont"
      local cur = t and (t[cfg.fontKey] or t.font)
      local flag = t and t[useGlobalKey]
      return OptionsUtil.ResolveFontKey(cur, flag)
    end,
    setFont = function(_, v)
      local useGlobalKey = cfg.fontKey and cfg.fontKey:gsub("Font$", "UseGlobalFont") or "useGlobalFont"
      SetTextValue(cfg.fontKey, v)
      SetTextValue(useGlobalKey, false)
    end,
    getOutline = function()
      local db = GetDB()
      local t = db and db.text or nil
      return UFCB_GetGlobalOutlineValue(t and (t[cfg.outlineKey] or t.outline) or nil)
    end,
    setOutline = function(_, v)
      SetTextValue(cfg.outlineKey, UFCB_SetStoredOutline(v))
    end,
    getAnchor = function()
      local db = GetDB()
      local t = db and db.text or nil
      return t and t[cfg.anchorKey] or nil
    end,
    setAnchor = function(_, v)
      SetTextValue(cfg.anchorKey, v)
    end,
    getOffsetX = function()
      local db = GetDB()
      local t = db and db.text or nil
      return t and tonumber(t[cfg.offsetXKey]) or nil
    end,
    setOffsetX = function(_, v)
      SetTextValue(cfg.offsetXKey, v)
    end,
    getOffsetY = function()
      local db = GetDB()
      local t = db and db.text or nil
      return t and tonumber(t[cfg.offsetYKey]) or nil
    end,
    setOffsetY = function(_, v)
      SetTextValue(cfg.offsetYKey, v)
    end,
  })

  local BuildInlineArgsGroup = UFCB_BuildInlineArgsGroup

  if flatArgs.fontSize then
    flatArgs.fontSize.name = (kind == "name") and "Text size" or cfg.sizeName
  end
  if flatArgs.mode then
    flatArgs.mode.name = "Display mode"
  end
  if flatArgs.anchor then
    flatArgs.anchor.name = "Text anchor"
  end
  if flatArgs.offsetX then
    flatArgs.offsetX.name = "Text X offset"
  end
  if flatArgs.offsetY then
    flatArgs.offsetY.name = "Text Y offset"
  end

  if kind == "name" then
    return {
      appearance = BuildInlineArgsGroup("Text", 1, {
        classColoredNames = {
          type = "toggle",
          name = "Class colored names",
          order = 0.5,
          get = function()
            local db = GetDB()
            return db and db.colors and db.colors.useClassForNames == true or false
          end,
          set = function(_, v)
            SetColorValue("useClassForNames", v and true or false)
          end,
        },
        nameTextColor = flatArgs.nameTextColor,
        fontSize = flatArgs.fontSize,
        useGlobalFont = flatArgs.useGlobalFont,
        font = flatArgs.font,
        outline = flatArgs.outline,
      }),
      position = BuildInlineArgsGroup("Position", 2, {
        anchor = flatArgs.anchor,
        offsetX = flatArgs.offsetX,
        offsetY = flatArgs.offsetY,
      }),
    }
  end

  if kind == "health" then
    return {
      display = BuildInlineArgsGroup("Health and text", 1, {
        frameHeight = BuildGroupedFrameHeightArg(),
        mode = flatArgs.mode,
        fontSize = flatArgs.fontSize,
        useGlobalFont = flatArgs.useGlobalFont,
        font = flatArgs.font,
        outline = flatArgs.outline,
      }),
      colors = BuildInlineArgsGroup("Colors", 2, {
        missingHPColor = flatArgs.missingHPColor,
        healthTextColor = flatArgs.healthTextColor,
      }),
      position = BuildInlineArgsGroup("Position", 3, {
        anchor = flatArgs.anchor,
        offsetX = flatArgs.offsetX,
        offsetY = flatArgs.offsetY,
      }),
      textures = BuildInlineArgsGroup("Textures", 4, {
        healthTexture = flatArgs.healthTexture,
        absorbTexture = flatArgs.absorbTexture,
      }),
    }
  end

  return {
    display = BuildInlineArgsGroup("Power and text", 1, {
      hidePower = BuildGroupedHidePowerArg(),
      powerHeight = BuildGroupedPowerHeightArg(),
      mode = flatArgs.mode,
      fontSize = flatArgs.fontSize,
      useGlobalFont = flatArgs.useGlobalFont,
      font = flatArgs.font,
      outline = flatArgs.outline,
    }),
    colors = BuildInlineArgsGroup("Colors", 2, {
      powerMissingColor = flatArgs.powerMissingColor,
      powerTextColor = flatArgs.powerTextColor,
    }),
    position = BuildInlineArgsGroup("Position", 3, {
      anchor = flatArgs.anchor,
      offsetX = flatArgs.offsetX,
      offsetY = flatArgs.offsetY,
    }),
    textures = BuildInlineArgsGroup("Textures", 4, {
      powerTexture = flatArgs.powerTexture,
    }),
  }
end

local function UFCB_BuildPartyDispelArgs(groupKind)
  local groupedKind = UFCB_GetGroupedKind(groupKind)

  local function GetDB()
    return UFCB_GetGroupedDB(groupedKind)
  end

  return {
    healthColor = {
      type = "toggle",
      name = "Health bar color",
      order = 1,
      get = function()
        local db = GetDB()
        local mode = db and db.debuffHighlighting or "NONE"
        return mode == "FILL" or mode == "BOTH"
      end,
      set = function(_, v)
        UFCB_MutateGrouped(groupedKind, false, { auras = true, highlightState = true }, function(db)
          local mode = db.debuffHighlighting or "NONE"
          if v == true then
            if mode == "NONE" then
              mode = "FILL"
            elseif mode == "GLOW" then
              mode = "BOTH"
            end
          elseif mode == "FILL" then
            mode = "NONE"
          elseif mode == "BOTH" then
            mode = "GLOW"
          end
          db.debuffHighlighting = mode
        end)
      end,
    },
    border = {
      type = "toggle",
      name = "Border",
      order = 2,
      get = function()
        local db = GetDB()
        local mode = db and db.debuffHighlighting or "NONE"
        return mode == "GLOW" or mode == "BOTH"
      end,
      set = function(_, v)
        UFCB_MutateGrouped(groupedKind, false, { auras = true, highlightState = true }, function(db)
          local mode = db.debuffHighlighting or "NONE"
          if v == true then
            if mode == "NONE" then
              mode = "GLOW"
            elseif mode == "FILL" then
              mode = "BOTH"
            end
          elseif mode == "GLOW" then
            mode = "NONE"
          elseif mode == "BOTH" then
            mode = "FILL"
          end
          db.debuffHighlighting = mode
        end)
      end,
    },
    borderSize = {
      type = "range",
      name = "Border thickness",
      order = 3,
      min = 0,
      max = 12,
      step = 1,
      disabled = function()
        local db = GetDB()
        local mode = db and db.debuffHighlighting or "NONE"
        return mode ~= "GLOW" and mode ~= "BOTH"
      end,
      get = function()
        local db = GetDB()
        local highlight = db and db.debuffHighlight
        return UFCB_GetClampedNumber(highlight and highlight.borderSize, 3, 0, 12)
      end,
      set = function(_, v)
        UFCB_MutateGrouped(groupedKind, false, { auras = true, highlightPresentation = true }, function(db)
          db.debuffHighlight.borderSize = UFCB_GetClampedNumber(v, 3, 0, 12)
        end)
      end,
    },
    blizzardIndicatorSettings = UFCB_BuildInlineArgsGroup("Blizzard dispel icon", 4, {
      enabled = {
        type = "toggle",
        name = "Blizzard dispel icon",
        order = 1,
        get = function()
          local db = GetDB()
          return db and db.debuffHighlight and db.debuffHighlight.blizzardIndicator == true or false
        end,
        set = function(_, v)
          UFCB_MutateGrouped(groupedKind, false, { auras = true, highlightState = true }, function(db)
            db.debuffHighlight.blizzardIndicator = v == true
          end)
        end,
      },
      size = {
        type = "range",
        name = "Size",
        order = 2,
        min = 8,
        max = 48,
        step = 1,
        disabled = function()
          local db = GetDB()
          return not (db and db.debuffHighlight and db.debuffHighlight.blizzardIndicator == true)
        end,
        get = function()
          local db = GetDB()
          local highlight = db and db.debuffHighlight
          return UFCB_GetClampedNumber(highlight and highlight.blizzardIndicatorSize, 18, 8, 48)
        end,
        set = function(_, v)
          UFCB_MutateGrouped(groupedKind, false, { auras = true, highlightPresentation = true }, function(db)
            db.debuffHighlight.blizzardIndicatorSize = UFCB_GetClampedNumber(v, 18, 8, 48)
          end)
        end,
      },
      position = {
        type = "select",
        name = "Anchor",
        order = 3,
        values = TEXT_ANCHOR_VALUES,
        disabled = function()
          local db = GetDB()
          return not (db and db.debuffHighlight and db.debuffHighlight.blizzardIndicator == true)
        end,
        get = function()
          local db = GetDB()
          local highlight = db and db.debuffHighlight
          return highlight and highlight.blizzardIndicatorPosition or "TOPRIGHT"
        end,
        set = function(_, v)
          UFCB_MutateGrouped(groupedKind, false, { auras = true, highlightPresentation = true }, function(db)
            db.debuffHighlight.blizzardIndicatorPosition = v
          end)
        end,
      },
      xOffset = {
        type = "range",
        name = "X offset",
        order = 4,
        min = -50,
        max = 50,
        step = 1,
        disabled = function()
          local db = GetDB()
          return not (db and db.debuffHighlight and db.debuffHighlight.blizzardIndicator == true)
        end,
        get = function()
          local db = GetDB()
          local highlight = db and db.debuffHighlight
          return UFCB_GetClampedNumber(highlight and highlight.blizzardIndicatorXOffset, 0, -50, 50)
        end,
        set = function(_, v)
          UFCB_MutateGrouped(groupedKind, false, { auras = true, highlightPresentation = true }, function(db)
            db.debuffHighlight.blizzardIndicatorXOffset = UFCB_GetClampedNumber(v, 0, -50, 50)
          end)
        end,
      },
      yOffset = {
        type = "range",
        name = "Y offset",
        order = 5,
        min = -50,
        max = 50,
        step = 1,
        disabled = function()
          local db = GetDB()
          return not (db and db.debuffHighlight and db.debuffHighlight.blizzardIndicator == true)
        end,
        get = function()
          local db = GetDB()
          local highlight = db and db.debuffHighlight
          return UFCB_GetClampedNumber(highlight and highlight.blizzardIndicatorYOffset, 0, -50, 50)
        end,
        set = function(_, v)
          UFCB_MutateGrouped(groupedKind, false, { auras = true, highlightPresentation = true }, function(db)
            db.debuffHighlight.blizzardIndicatorYOffset = UFCB_GetClampedNumber(v, 0, -50, 50)
          end)
        end,
      },
    }),
  }
end

local function UFCB_BuildPartyAuraArgs(groupKind)
  local groupedKind = UFCB_GetGroupedKind(groupKind)

  local function GetDB()
    return UFCB_GetGroupedDB(groupedKind)
  end


  local function GetAuraDB()
    local db = GetDB()
    if not db or not db.auras then
      return nil, nil
    end

    return db, db.auras
  end

  local function Refresh(flags)
    local auraFlags = MergeGroupedRefreshFlags({ auras = true }, type(flags) == "table" and flags or nil)
    UFCB_RequestGroupedRefresh(groupedKind, false, auraFlags)
  end

  local function GetAuras()
    local _, auras = GetAuraDB()
    if not auras then
      return nil
    end

    auras.kind = groupedKind
    return auras
  end

  local function GetDefaultAuras()
    local defaults = groupedKind == "raid"
      and ns.UFDefaults.GetRaidDefaults()
      or ns.UFDefaults.GetPartyDefaults()
    local auras = defaults and defaults.profile and defaults.profile.auras or {}
    auras.kind = groupedKind
    return auras
  end


  if not GetAuras() then
    return UFCB_BuildUnavailableArgs("No aura configuration found for grouped frame '" .. tostring(groupedKind) .. "'.")
  end

  local function BuildGroupedAuraToggle(key, name, order, opts)
    opts = opts or {}

    return {
      type = "toggle",
      name = name,
      desc = opts.desc,
      order = order,
      
      disabled = opts.disabled,
      get = opts.get or function()
        local _, a = GetAuraDB()
        if not a then
          return opts.nilValue == true
        end

        if opts.defaultTrue then
          return a[key] ~= false
        end

        return a[key] == true
      end,
      set = opts.set or function(_, v)
        if UFCB_BlockCombat() then return end
        local _, a = GetAuraDB()
        if not a then return end
        a[key] = v and true or false
        Refresh(opts.refreshFlags)
      end,
    }
  end

  local shared = UFCB_BuildSharedAuraTabs({
    getAuras = GetAuras,
    refresh = Refresh,
    defaults = GetDefaultAuras(),
    inline = false,
    generalPrefixArgs = {
      enabled = BuildGroupedAuraToggle(
        "enabled",
        "Enable auras",
        1,
        {
          desc = "Master toggle for all Aura Groups and Aura Slots on these unit frames.",
        }
      ),
    },
    generalSuffixArgs = {
      disableSwipe = BuildGroupedAuraToggle("disableSwipe", "Disable swipe", 6.1),
      disableCountdownText = BuildGroupedAuraToggle("disableCountdownText", "Disable countdown text", 6.2),
    },
  })





  shared.general.args.testModePreview = {
    type = "group",
    name = "Frame test mode",
    order = 10.5,
    inline = true,
    args = {
      testMode = {
        type = "toggle",
        name = "Show test frames",
        order = 0.5,
        get = function()
          return ns.TestMode:IsActive() and ns.TestMode:GetValue("uf." .. groupedKind) == true
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end

          ns.TestMode:SetParticipantEnabled("unitframes", true)
          ns.TestMode:SetValue("uf." .. groupedKind, v == true, "unit-frame-options")
          if v == true and not ns.TestMode:IsActive() then
            Addon:SetEditMode(true)
          end
        end,
      },
      info = {
        type = "description",
        name = "Shows the configured party or raid layout with synthetic activity. Use the Test Mode toolbar to change frame count, activity, castbars, and Movers.",
        order = 1,
        fontSize = "medium",
      },
    },
  }



  return shared
end

local UFCB_DEFAULT_EMPOWER_COLORS = {
  { 1.00, 0.26, 0.20, 0.5 },
  { 1.00, 0.80, 0.26, 0.5 },
  { 1.00, 1.00, 0.26, 0.5 },
  { 0.66, 1.00, 0.40, 0.5 },
  { 0.36, 0.90, 0.80, 0.5 },
}

local function UFCB_GetEmpowerColorSet(cfg)
  return cfg and cfg.empowerSegmentColors
end

local function UFCB_GetEmpowerStageColor(unitKey, stage)
  local cfg = GetCBUnitCfg(unitKey)
  local colors = UFCB_GetEmpowerColorSet(cfg)
  local color = colors and colors[stage] or nil
  if color then
    return color
  end

  local playerCfg = GetCBUnitCfg("player")
  local playerColors = UFCB_GetEmpowerColorSet(playerCfg)
  return (playerColors and playerColors[stage]) or UFCB_DEFAULT_EMPOWER_COLORS[stage] or { 1, 1, 1, 0.5 }
end

local function UFCB_EnsureEmpowerColorTable(cfg)
  cfg.empowerSegmentColors = cfg.empowerSegmentColors or {}

  for i = 1, 5 do
    if type(cfg.empowerSegmentColors[i]) ~= "table" then
      local c = UFCB_GetEmpowerStageColor("player", i)
      cfg.empowerSegmentColors[i] = { c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1, c[4] or c.a or 0.5 }
    end
  end

  return cfg.empowerSegmentColors
end

local function UFCB_BuildEmpowerStageColorArgs(unitKey, cfg, refresh)
  local args = {}

  for i = 1, 5 do
    args["stage" .. tostring(i)] = {
      type = "color",
      name = "Stage " .. tostring(i),
      order = i,
      hasAlpha = true,
      get = function()
        local c = UFCB_GetEmpowerStageColor(unitKey, i)
        return c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1, c[4] or c.a or 0.5
      end,
      set = function(_, r, g, b, a)
        if UFCB_BlockCombat() then return end
        local colors = UFCB_EnsureEmpowerColorTable(cfg)
        colors[i] = { r, g, b, a or 0.5 }
        refresh()
      end,
    }
  end

  return {
    type = "group",
    name = "Empower stage colors",
    inline = true,
    order = 11,
    args = args,
  }
end

local function UFCB_BuildCastbarArgs(unitKey)
  local cfg = GetCBUnitCfg(unitKey)
  if not cfg then
    return UFCB_BuildUnavailableArgs("No cast bar configuration found for '" .. tostring(unitKey) .. "'.")
  end

  cfg.text = cfg.text or {}
  cfg.timeText = cfg.timeText or {}

  local text = cfg.text
  local time = cfg.timeText
  local castbarUnit = UFCB_GetCastbarRefreshUnit(unitKey)

  local function refresh(extraFlags)
    CB_RefreshUnit(castbarUnit, extraFlags)
  end

  local outlineValues = UFCB_GetOutlineValues()

  local anchorValues = {
    LEFT = "LEFT",
    RIGHT = "RIGHT",
    CENTER = "CENTER",
    TOP = "TOP",
    BOTTOM = "BOTTOM",
  }

  local function BuildCastbarToggle(store, key, name, order, opts)
    opts = opts or {}

    return {
      type = "toggle",
      name = name,
      order = order,
      
      disabled = opts.disabled,
      get = opts.get or function()
        if opts.defaultTrue then
          return store[key] ~= false
        end

        return store[key] == true
      end,
      set = opts.set or function(_, v)
        if UFCB_BlockCombat() then return end
        store[key] = v and true or false
        refresh()
      end,
    }
  end

  local function BuildCastbarRange(store, key, name, order, minValue, maxValue, opts)
    opts = opts or {}

    return {
      type = "range",
      name = name,
      order = order,
      min = minValue,
      max = maxValue,
      step = opts.step or 1,
      
      disabled = opts.disabled,
      get = opts.get or function()
        return tonumber(store[key] or opts.default)
      end,
      set = opts.set or function(_, v)
        if UFCB_BlockCombat() then return end
        if opts.numberDefault ~= nil then
          store[key] = tonumber(v) or opts.numberDefault
        else
          store[key] = v
        end
        refresh()
      end,
    }
  end

  local function BuildCastbarSelect(store, key, name, order, values, opts)
    opts = opts or {}

    return {
      type = "select",
      dialogControl = opts.dialogControl,
      name = name,
      order = order,
      
      values = values,
      disabled = opts.disabled,
      get = opts.get or function()
        return store[key] or opts.default
      end,
      set = opts.set or function(_, v)
        if UFCB_BlockCombat() then return end
        store[key] = opts.fallback and (v or opts.fallback) or v
        refresh()
      end,
    }
  end

  local function BuildCastbarInput(store, key, name, order, opts)
    opts = opts or {}

    return {
      type = "input",
      name = name,
      order = order,
      
      disabled = opts.disabled,
      get = opts.get or function()
        return tostring(store[key] or opts.default or "")
      end,
      set = opts.set or function(_, v)
        if UFCB_BlockCombat() then return end
        v = tostring(v or "")
        if v == "" and opts.default then
          v = opts.default
        end
        store[key] = v
        refresh()
      end,
    }
  end

  local function BuildCastbarColor(store, key, name, order, opts)
    opts = opts or {}

    return {
      type = "color",
      name = name,
      order = order,
      hasAlpha = opts.hasAlpha,
      get = function()
        local c = store[key]
        if opts.hasAlpha then
          return c[1], c[2], c[3], c[4]
        end

        return c[1], c[2], c[3]
      end,
      set = function(_, r, g, b, a)
        if UFCB_BlockCombat() then return end
        if opts.hasAlpha then
          store[key] = { r, g, b, a or opts.alphaDefault }
        else
          store[key] = { r, g, b }
        end
        refresh()
      end,
    }
  end

  local args = {
    enabled = BuildCastbarToggle(cfg, "enabled", "Enable cast bar", 1, {
      defaultTrue = true,
      set = function(_, v)
        if UFCB_BlockCombat() then return end
        cfg.enabled = v and true or false
        if castbarUnit == "player" then
          CastBar:RefreshPlayerSpellcastEvents()
        end
        refresh()
      end,
    }),
    width = BuildCastbarRange(cfg, "width", "Width (bar + icon)", 2, 120, 400, {
      set = function(_, value)
        if UFCB_BlockCombat() then return end
        cfg.width = value
        refresh()
        FrameUtil.RefreshSmartSnapState("CastBar_" .. tostring(castbarUnit))
      end,
    }),
    height = BuildCastbarRange(cfg, "height", "Height", 3, 8, 40, {
      set = function(_, value)
        if UFCB_BlockCombat() then return end
        cfg.height = value
        refresh()
        FrameUtil.RefreshSmartSnapState("CastBar_" .. tostring(castbarUnit))
      end,
    }),
    borderSize = BuildCastbarRange(cfg, "borderSize", "Border size", 4, 0, 8),
    texture = BuildCastbarSelect(cfg, "texture", "Cast bar texture", 5, function()
      return OptionsUtil.BuildStatusbarValues(false)
    end, { dialogControl = "LSM30_Statusbar" }),
    uninterruptShieldMode = BuildCastbarSelect(cfg, "uninterruptShieldMode", "Uninterruptible shield", 6, {
      NONE = "None",
      LEFT = "Left",
      RIGHT = "Right",
      BOTH = "Both",
    }),
    uninterruptTextureMode = BuildCastbarSelect(cfg, "uninterruptTextureMode", "Uninterruptible style", 7, {
      GRAY = "Gray (default)",
      DIM = "Dim (darker)",
    }),
    useCustomColor = BuildCastbarToggle(cfg, "useCustomColor", "Use custom color", 8),
    barColor = BuildCastbarColor(cfg, "customColor", "Bar color", 9),
    backgroundColor = BuildCastbarColor(cfg, "bgColor", "Background color", 10, { hasAlpha = true, alphaDefault = 0.40 }),
    empowerStageColors = UFCB_BuildEmpowerStageColorArgs(unitKey, cfg, refresh),
    fonts = {
      type = "group",
      name = "Fonts",
      inline = true,
      order = 20,
      args = {
        useGlobalFont = {
          type = "toggle",
          name = "Use global font",
          order = 1,
          get = function()
            return UFCB_IsUsingGlobalFont(text.fontKey, text.useGlobalFont)
          end,
          set = function(_, v)
            if UFCB_BlockCombat() then return end
            text.useGlobalFont = v and true or false
            refresh()
          end,
        },
        font = BuildCastbarSelect(text, "fontKey", "Font type", 2, OptionsUtil.BuildFontValues, {
          dialogControl = "LSM30_Font",
          disabled = function()
            return UFCB_IsUsingGlobalFont(text.fontKey, text.useGlobalFont)
          end,
          get = function()
            return OptionsUtil.ResolveFontKey(text.fontKey, text.useGlobalFont)
          end,
          set = function(_, v)
            if UFCB_BlockCombat() then return end
            text.fontKey = v
            text.useGlobalFont = false
            refresh()
          end,
        }),
        outline = BuildCastbarSelect(text, "flags", "Font outline", 2, outlineValues, {
          get = function()
            return UFCB_GetGlobalOutlineValue(text.flags)
          end,
          set = function(_, v)
            if UFCB_BlockCombat() then return end
            text.flags = UFCB_SetStoredOutline(v)
            refresh()
          end,
        }),
        fontColor = BuildCastbarColor(text, "color", "Font color", 3),
        nameFontSize = BuildCastbarRange(text, "size", "Name Font Size", 4, 6, 30),
        nameYOffset = BuildCastbarRange(text, "offY", "Name Y offset", 5, -40, 40, { default = 0 }),
        nameXOffset = BuildCastbarRange(text, "offX", "Name X offset", 6, -80, 80),
        timeFontSize = BuildCastbarRange(time, "size", "Time font size", 7, 6, 30),
        timeYOffset = BuildCastbarRange(time, "offY", "Time Y offset", 8, -40, 40),
        timeXOffset = BuildCastbarRange(time, "offX", "Time X offset", 9, -80, 80),
        nameAnchor = BuildCastbarSelect(text, "anchor", "Spell Name Anchor", 10, anchorValues),
        timeAnchor = BuildCastbarSelect(time, "anchor", "Cast Time anchor", 11, anchorValues),
      },
    },
    toggles = {
      type = "group",
      name = "Toggles",
      inline = true,
      order = 21,
      args = {
        showIcon = BuildCastbarToggle(cfg, "showIcon", "Show Spell Icon", 1, {  defaultTrue = true }),
        showPingOverlay = BuildCastbarToggle(cfg, "showPingOverlay", "Show Latency (Ping) overlay", 2, {  defaultTrue = true }),
        showName = BuildCastbarToggle(text, "showName", "Enable Spell Name", 3, {
          defaultTrue = true,
          set = function(_, v)
            if UFCB_BlockCombat() then return end
            text.showName = v and true or false
            cfg.__puiShowSpellName = v and true or false
            refresh()
          end,
        }),
        showCast = BuildCastbarToggle(time, "showCast", "Enable Cast Time", 4, {
          
          defaultTrue = true,
          set = function(_, v)
            if UFCB_BlockCombat() then return end
            time.showCast = v and true or false
            cfg.showTimeText = v and true or false
            cfg.__puiShowCastTime = v and true or false
            refresh()
          end,
        }),
        displayTarget = BuildCastbarToggle(cfg, "displayTarget", "Show cast target in name text", 5),
      },
    },
  }

  if unitKey == "player" then
    args.toggles.args.showEmpowerPips = BuildCastbarToggle(cfg, "showEmpowerPips", "Show empower pips", 6, {  defaultTrue = true })

    args.toggles.args.showEmpowerHold = BuildCastbarToggle(cfg, "showEmpowerHold", "Show empower hold area", 7, {  defaultTrue = true })

    args.toggles.args.empowerHoldColor = BuildCastbarColor(cfg, "empowerHoldColor", "Empower hold color", 8, {
      hasAlpha = true,
      alphaDefault = 1,
      disabled = function()
        return cfg.showEmpowerHold == false
      end,
    })

    args.toggles.args.showChannelTicks = BuildCastbarToggle(cfg, "showChannelTicks", "Show channel tick markers", 9, {  defaultTrue = true })

    args.toggles.args.channelTickThickness = BuildCastbarRange(cfg, "channelTickThickness", "Channel tick thickness", 10, 1, 10, {
      default = 2,
      numberDefault = 2,
      disabled = function()
        return cfg.showChannelTicks == false
      end,
    })

    args.toggles.args.showDisintegrateClipWarning = BuildCastbarToggle(cfg, "showDisintegrateClipWarning", "Enable Disintegrate clip warning", 11)

    args.toggles.args.disintegrateClipWarningText = BuildCastbarInput(cfg, "disintegrateClipWarningText", "Disintegrate clip warning text", 12, {
      
      default = "DON'T CLIP",
      disabled = function()
        return cfg.showDisintegrateClipWarning ~= true
      end,
    })

    args.instantCast = {
      type = "group",
      name = "Instant Cast Bar",
      inline = true,
      order = 22,
      args = {
        showInstantCasts = BuildCastbarToggle(cfg, "showInstantCasts", "Enable instant cast bar", 1, {
          defaultTrue = true,
          set = function(_, v)
            if UFCB_BlockCombat() then return end
            cfg.showInstantCasts = v and true or false
            CastBar:RefreshPlayerSpellcastEvents()
            refresh()
          end,
        }),

        instantCastHelp = {
          type = "description",
          name = "Shows a short GCD bar when your player unit successfully fires an instant spell.",
          order = 2,
        },

        instantCastFillMode = BuildCastbarSelect(cfg, "instantCastFillMode", "Instant cast bar mode", 3, {
          DRAIN = "Drain",
          FILL = "Fill",
        }, {
          
          default = "DRAIN",
          fallback = "DRAIN",
          disabled = function()
            return cfg.showInstantCasts == false
          end,
        }),

        instantCastAlpha = BuildCastbarRange(cfg, "instantCastAlpha", "Instant cast bar alpha", 4, 0.10, 1, {
          
          step = 0.05,
          default = 0.65,
          numberDefault = 0.65,
          disabled = function()
            return cfg.showInstantCasts == false
          end,
        }),

        instantCastTexture = BuildCastbarSelect(cfg, "instantCastTexture", "Instant cast texture", 5, function()
          return OptionsUtil.BuildStatusbarValues(false)
        end, {
          dialogControl = "LSM30_Statusbar",
          
          fallback = "Pleebar",
          get = function()
            return cfg.instantCastTexture or cfg.texture or "Pleebar"
          end,
          disabled = function()
            return cfg.showInstantCasts == false
          end,
        }),

        instantCastUseOverlay = BuildCastbarToggle(cfg, "instantCastUseOverlay", "Use instant cast overlay", 6, {
          
          defaultTrue = true,
          disabled = function()
            return cfg.showInstantCasts == false
          end,
        }),

        instantCastOverlayTexture = BuildCastbarSelect(cfg, "instantCastOverlayTexture", "Instant cast overlay texture", 7, function()
          return OptionsUtil.BuildStatusbarValues(false)
        end, {
          dialogControl = "LSM30_Statusbar",
          
          default = "PUI Stripes",
          fallback = "PUI Stripes",
          disabled = function()
            return cfg.showInstantCasts == false or cfg.instantCastUseOverlay == false
          end,
        }),

        instantCastOverlayAlpha = BuildCastbarRange(cfg, "instantCastOverlayAlpha", "Instant cast overlay alpha", 8, 0, 1, {
          
          step = 0.05,
          default = 0.35,
          numberDefault = 0.35,
          disabled = function()
            return cfg.showInstantCasts == false or cfg.instantCastUseOverlay == false
          end,
        }),
      },
    }

    args.testMode = {
      type = "toggle",
      name = "Test bar (cast + channel)",
      order = 30,
      
      get = function()
        return ns.TestMode:IsActive() and ns.TestMode:GetValue("uf.castbars") == true
      end,
      set = function(_, v)
        if UFCB_BlockCombat() then return end

        ns.TestMode:SetParticipantEnabled("unitframes", true)
        ns.TestMode:SetValue("uf.castbars", v == true, "unit-frame-options")
        if v == true and not ns.TestMode:IsActive() then
          Addon:SetEditMode(true)
        end
      end,
    }
  end

  return args
end

local function UFCB_BuildTreeGroupLeaf(name, order, args, childGroups)
  if childGroups == "tab" then
    for _, tab in pairs(args or {}) do
      if type(tab) == "table" and type(tab.args) == "table" then
        tab.args = UFCB_BuildCategorizedInlineArgs(tab.args)
      end
    end
  else
    args = UFCB_BuildCategorizedInlineArgs(args)
  end

  local leaf = {
    type = "group",
    name = name,
    order = order,
    args = args,
  }

  if childGroups then
    leaf.childGroups = childGroups
  end

  return leaf
end

local function UFCB_BuildTreeArgsFromSpecs(specs)
  local args = {}

  for _, spec in ipairs(specs or {}) do
    args[spec.key] = UFCB_BuildTreeGroupLeaf(spec.name, spec.order, spec.args, spec.childGroups)
  end

  return args
end

local function UFCB_BuildExtraLeaf(key, name, order, args, childGroups)
  return {
    key = key,
    def = UFCB_BuildTreeGroupLeaf(name, order, args, childGroups),
  }
end

local function UFCB_BuildPortraitArgs(getPortrait, refresh)
  local function IsDisabled()
    local portrait = getPortrait()
    return not portrait or portrait.enabled ~= true
  end

  return {
    enabled = {
      type = "toggle",
      name = "Show portrait",
      order = 1,
      get = function()
        local portrait = getPortrait()
        return portrait and portrait.enabled == true
      end,
      set = function(_, value)
        if UFCB_BlockCombat() then return end
        local portrait = getPortrait()
        if not portrait then return end
        portrait.enabled = value == true
        refresh()
      end,
    },
    style = {
      type = "select",
      name = "Portrait style",
      order = 2,
      values = PORTRAIT_STYLE_VALUES,
      disabled = IsDisabled,
      get = function()
        local portrait = getPortrait()
        return portrait and portrait.style or "2D"
      end,
      set = function(_, value)
        if UFCB_BlockCombat() then return end
        local portrait = getPortrait()
        if not portrait then return end
        portrait.style = value == "3D" and "3D" or "2D"
        refresh()
      end,
    },
    side = {
      type = "select",
      name = "Portrait side",
      order = 3,
      values = PORTRAIT_SIDE_VALUES,
      disabled = IsDisabled,
      get = function()
        local portrait = getPortrait()
        return portrait and portrait.side or "LEFT"
      end,
      set = function(_, value)
        if UFCB_BlockCombat() then return end
        local portrait = getPortrait()
        if not portrait then return end
        portrait.side = value == "RIGHT" and "RIGHT" or "LEFT"
        refresh()
      end,
    },
    zoom = {
      type = "range",
      name = "Portrait zoom",
      order = 4,
      min = 0,
      max = 100,
      step = 1,
      disabled = IsDisabled,
      get = function()
        local portrait = getPortrait()
        return (portrait and tonumber(portrait.zoom) or 0) * 100
      end,
      set = function(_, value)
        if UFCB_BlockCombat() then return end
        local portrait = getPortrait()
        if not portrait then return end
        portrait.zoom = value / 100
        refresh()
      end,
    },
  }
end

local function UFCB_BuildUnitPortraitArgs(unitKey)
  return UFCB_BuildPortraitArgs(
    function()
      local cfg = UF:GetConfigUnit(unitKey)
      return cfg and cfg.portrait
    end,
    function()
      Addon:ApplyOptionsChange("UnitFrames", { mode = "resize", unit = unitKey })
    end
  )
end

local function UFCB_BuildPartyPortraitArgs()
  return UFCB_BuildPortraitArgs(
    function()
      local db = UFCB_GetGroupedDB("party")
      return db and db.portrait
    end,
    function()
      UFCB_RequestGroupedRefresh("party", false, { resize = true })
    end
  )
end



local function UFCB_BuildUnitBaseLeafSpecs(unitKey, opts)
  opts = opts or {}

  local specs = {
    {
      key = "general",
      name = "General",
      order = 1,
      args = UFCB_BuildUnitGeneralArgs(unitKey),
    },
    {
      key = "name",
      name = "Name",
      order = 2,
      args = UFCB_BuildUnitTextArgs(unitKey, "name"),
    },
    {
      key = "health",
      name = "Health",
      order = 3,
      args = UFCB_BuildUnitTextArgs(unitKey, "health"),
    },
    {
      key = "power",
      name = "Power",
      order = 4,
      args = UFCB_BuildUnitTextArgs(unitKey, "power"),
    },
    {
      key = "auras",
      name = "Auras",
      order = 5,
      childGroups = "tab",
      args = UFCB_BuildUnitAurasArgs(unitKey),
    },
  }

  if unitKey == "player" or unitKey == "target" or unitKey == "focus" or unitKey == "boss" then
    specs[#specs + 1] = {
      key = "portrait",
      name = "Portrait",
      order = 6,
      args = UFCB_BuildUnitPortraitArgs(unitKey),
    }
  end

  if opts.includeCastbar ~= false then
    specs[#specs + 1] = {
      key = "castbar",
      name = "Castbar",
      order = 7,
      args = UFCB_BuildCastbarArgs(opts.castbarUnit or unitKey),
    }
  end

  return specs
end

local function UFCB_BuildUnitTree(unitKey, opts)
  opts = opts or {}

  local tree = UFCB_BuildTreeArgsFromSpecs(UFCB_BuildUnitBaseLeafSpecs(unitKey, opts))

  if opts.extraLeaves then
    for _, leaf in ipairs(opts.extraLeaves) do
      tree[leaf.key] = leaf.def
    end
  end

  return {
    type = "group",
    name = opts.rootName or "Unit",
    childGroups = "tree",
    args = tree,
  }
end

local function UFCB_BuildPartyPetsArgs()
  local function GetPetDB()
    local db = UFCB_GetGroupedDB("party")
    if not db or not db.partyPets then
      return nil, nil
    end

    return db, db.partyPets
  end

  if not select(2, GetPetDB()) then
    return UFCB_BuildUnavailableArgs("No party pet configuration found.")
  end

  local function Refresh(flags, registerAuraEvents)
    local m = UFCB_GetGroupedModule("party")
    if registerAuraEvents then
      m:RegisterAuraUnitEvents()
    end
    UFCB_RequestGroupedRefresh("party", false, flags or { resize = true })
  end

  local BuildInlineArgsGroup = UFCB_BuildInlineArgsGroup

  return {
    behavior = BuildInlineArgsGroup("Behavior", 1, {
      enabled = {
        type = "toggle",
        name = "Enable party pets",
        desc = "Show or hide the party pet frames.",
        order = 1,
        
        get = function()
          local _, petDB = GetPetDB()
          return petDB and petDB.enabled or false
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          local _, petDB = GetPetDB()
          if not petDB or not UFCB_GetGroupedModule("party") then return end
          petDB.enabled = v and true or false
          Refresh({ visibility = true, resize = true }, false)
        end,
      },
      trackAuras = {
        type = "toggle",
        name = "Track auras on party pets",
        desc = "Disabled by default. When off, party pet auras and party pet aura event listeners stay off.",
        order = 2,
        
        get = function()
          local _, petDB = GetPetDB()
          return petDB and petDB.trackAuras or false
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          local _, petDB = GetPetDB()
          if not petDB or not UFCB_GetGroupedModule("party") then return end
          petDB.trackAuras = v and true or false
          Refresh({ auras = true }, true)
        end,
      },
    }),
    anchor = BuildInlineArgsGroup("Anchoring", 2, {
      anchorPoint = {
        type = "select",
        name = "Anchor point",
        order = 1,
        values = PARTY_ANCHOR_VALUES,
        get = function()
          local _, petDB = GetPetDB()
          return petDB and petDB.anchorPoint or nil
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          local _, petDB = GetPetDB()
          if not petDB then return end
          petDB.anchorPoint = v
          Refresh({ layout = true }, false)
        end,
      },
      relativePoint = {
        type = "select",
        name = "Attach to point",
        order = 2,
        values = PARTY_ANCHOR_VALUES,
        get = function()
          local _, petDB = GetPetDB()
          return petDB and petDB.relativePoint or nil
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          local _, petDB = GetPetDB()
          if not petDB then return end
          petDB.relativePoint = v
          Refresh({ layout = true }, false)
        end,
      },
    }),
    size = BuildInlineArgsGroup("Size", 3, {
      width = {
        type = "range",
        name = "Width",
        order = 1,
        min = 40,
        max = 240,
        step = 1,
        get = function()
          local _, petDB = GetPetDB()
          return petDB and tonumber(petDB.width) or nil
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          local _, petDB = GetPetDB()
          if not petDB then return end
          petDB.width = v
          Refresh({ resize = true }, false)
        end,
      },
      height = {
        type = "range",
        name = "Height",
        order = 2,
        min = 8,
        max = 40,
        step = 1,
        get = function()
          local _, petDB = GetPetDB()
          return petDB and tonumber(petDB.height) or nil
        end,
        set = function(_, v)
          if UFCB_BlockCombat() then return end
          local _, petDB = GetPetDB()
          if not petDB then return end
          petDB.height = v
          Refresh({ resize = true }, false)
        end,
      },
    }),
  }
end




local function UFCB_BuildGroupedRootLeafSpecs(groupKind)
  local kind = UFCB_GetGroupedKind(groupKind)

  local specs = {
    {
      key = "general",
      name = "General",
      order = 1,
      args = UFCB_BuildPartyGeneralArgs(kind),
    },
    {
      key = "name",
      name = "Name",
      order = 2,
      args = UFCB_BuildPartyTextArgs("name", kind),
    },
    {
      key = "health",
      name = "Health",
      order = 3,
      args = UFCB_BuildPartyTextArgs("health", kind),
    },
    {
      key = "power",
      name = "Power",
      order = 4,
      args = UFCB_BuildPartyTextArgs("power", kind),
    },
    {
      key = "dispels",
      name = "Dispels",
      order = 5,
      args = UFCB_BuildPartyDispelArgs(kind),
    },
    {
      key = "auras",
      name = "Auras",
      order = 6,
      childGroups = "tab",
      args = UFCB_BuildPartyAuraArgs(kind),
    },
  }

  if kind == "party" then
    specs[#specs + 1] = {
      key = "portrait",
      name = "Portrait",
      order = 7,
      args = UFCB_BuildPartyPortraitArgs(),
    }
    specs[#specs + 1] = {
      key = "partypets",
      name = "Party Pets",
      order = 8,
      args = UFCB_BuildPartyPetsArgs(),
    }
  else
    specs[#specs + 1] = {
      key = "indicators",
      name = "Indicators",
      order = 7,
      args = UFCB_BuildRaidIndicatorArgs(),
    }
  end

  return specs
end

local function UFCB_BuildGroupedRootArgs(groupKind)
  return UFCB_BuildTreeArgsFromSpecs(UFCB_BuildGroupedRootLeafSpecs(groupKind))
end

local function UFCB_BuildGeneralRootLeafSpecs()
  return {
    {
      key = "auras",
      name = "Features",
      order = 1,
      args = UFCB_BuildGeneralAurasArgs(),
    },
    {
      key = "appearance",
      name = "Appearance",
      order = 2,
      args = UFCB_BuildGeneralAppearanceArgs(),
    },
    {
      key = "textures",
      name = "Textures and range",
      order = 3,
      args = UFCB_BuildGeneralTexturesArgs(),
    },
    {
      key = "textfonts",
      name = "Text and fonts",
      order = 4,
      args = UFCB_BuildGeneralTextFontsArgs(),
    },
    {
      key = "anchors",
      name = "Anchors",
      order = 5,
      args = UFCB_BuildGeneralAnchorsArgs(),
    },
  }
end

local function UFCB_BuildGeneralRootArgs()
  return UFCB_BuildTreeArgsFromSpecs(UFCB_BuildGeneralRootLeafSpecs())
end

local function UFCB_BuildUnitEntryArgs(spec)
  return {
    order = spec.order,
    name = spec.name,
    type = "group",
    childGroups = "tree",
    args = UFCB_BuildUnitTree(spec.unitKey, {
      rootName = spec.rootName,
      castbarUnit = spec.castbarUnit,
      extraLeaves = spec.extraLeaves,
    }).args,
  }
end

local function UFCB_BuildTopLevelUnitArgs(activeKey)
  local bossInfoNote = "Boss 1-5 share the same size, power, text and aura settings. Boss 1 anchors to the Boss Frames mover. Boss 2-5 follow the shared growth direction and spacing."

  local specs = {
    {
      key = "player",
      order = 2,
      name = "Player",
      unitKey = "player",
      rootName = "Player",
      castbarUnit = "player",
      extraLeavesBuilder = function()
        return {
          UFCB_BuildExtraLeaf("pet", "Pet", 8, UFCB_BuildUnitGeneralArgs("pet")),
        }
      end,
    },
    {
      key = "target",
      order = 3,
      name = "Target",
      unitKey = "target",
      rootName = "Target",
      castbarUnit = "target",
      extraLeavesBuilder = function()
        return {
          UFCB_BuildExtraLeaf("targettarget", "Target of Target", 8, UFCB_BuildUnitGeneralArgs("targettarget")),
        }
      end,
    },
    {
      key = "focus",
      order = 4,
      name = "Focus",
      unitKey = "focus",
      rootName = "Focus",
      castbarUnit = "focus",
      extraLeavesBuilder = function()
        return {
          UFCB_BuildExtraLeaf("focustarget", "Focus Target", 8, UFCB_BuildUnitGeneralArgs("focustarget")),
        }
      end,
    },
    {
      key = "boss",
      order = 5,
      name = "Boss Frames",
      unitKey = "boss",
      rootName = "Boss Frames",
      castbarUnit = "boss",
      extraLeavesBuilder = function()
        return {
          UFCB_BuildExtraLeaf("bossinfo", "Boss Stack Info", 8, {
            note = {
              type = "description",
              name = bossInfoNote,
              order = 1,
              fontSize = "medium",
            },
          }),
        }
      end,
    },
  }

  local args = {}

  for _, spec in ipairs(specs) do
    if not activeKey or activeKey == spec.key then
      local buildSpec = {
        key = spec.key,
        order = spec.order,
        name = spec.name,
        unitKey = spec.unitKey,
        rootName = spec.rootName,
        castbarUnit = spec.castbarUnit,
        extraLeaves = spec.extraLeavesBuilder and spec.extraLeavesBuilder() or nil,
      }
      args[spec.key] = UFCB_BuildUnitEntryArgs(buildSpec)
    else
      args[spec.key] = {
        order = spec.order,
        name = spec.name,
        type = "group",
        childGroups = "tree",
        args = {},
      }
    end
  end

  return args
end



Addon:RegisterOptionsSection("unitframes", function()
  local provider = {}

  function provider:GetOptions()
    local activePath = ns and ns._PUIActiveOptionsPath or nil
    local activeTab = type(activePath) == "table" and activePath[1] == "unitframes" and activePath[2] or nil
    local lazyBuild = activeTab ~= nil

    local options = {
      type = "group",
      name = "Unit Frames",
      childGroups = "tab",
      args = UFCB_MergeOptionArgs(
        {
          general = {
            type = "group",
            name = "General settings",
            order = 1,
            childGroups = "tree",
            args = (not lazyBuild or activeTab == "general") and UFCB_BuildGeneralRootArgs() or {},
          },
        },
        UFCB_BuildTopLevelUnitArgs(lazyBuild and activeTab or nil),
        {
          party = {
            order = 6,
            name = "Party",
            type = "group",
            childGroups = "tree",
            args = (not lazyBuild or activeTab == "party") and UFCB_BuildGroupedRootArgs("party") or {},
          },
          raid = {
            order = 7,
            name = "Raid",
            type = "group",
            childGroups = "tree",
            args = (not lazyBuild or activeTab == "raid") and UFCB_BuildGroupedRootArgs("raid") or {},
          },
        }
      ),
    }

    return options
  end

  return provider
end, 20, "Unit Frames", nil, {
  navDescription = "Frames, auras, text, and layout.",
  pageTitle = "Unit Frames",
  pageDescription = "Configure frame families, shared visuals, aura behavior, text, and previews.",
  pageHelp = "Set the global frame language first, then tune each family.",
  page = {
    previewWidth = 360,
    previewHeight = 248,
    previewAlwaysShown = true,
    previewPathMatches = ns.UFPreview.IsUnitFramesOptionsPath,
    onOptionsPathChanged = ns.UFPreview.HandleUnitFrameOptionsPathChanged,
    buildPreview = ns.UFPreview.BuildUnitFramePreview,
  },

})

ns.Registry.Options.unitframes.dynamicOptions = true

local function UFCB_CreateAuraManagerPreviewDisplay(unitKey, displayType, auraType)
  local grouped = unitKey == "party" or unitKey == "raid"
  local getAuras
  local refresh

  if grouped then
    getAuras = function()
      local db = UFCB_GetGroupedDB(unitKey)
      db.auras = db.auras or {}
      db.auras.kind = unitKey
      return db.auras
    end

    refresh = function(flags)
      local module = UFCB_GetGroupedModule(unitKey)
      module:RefreshAuraDisplay({
        rebuildDB = type(flags) == "table" and flags.rebuildDB == true or false,
        auras = true,
        displayID = type(flags) == "table" and flags.displayID or nil,
        auraChange = type(flags) == "table" and flags.auraChange or nil,
      })
      UFCB_RefreshGroupedTestPreview(unitKey)
    end
  else
    getAuras = function()
      local frameDB = ns.UnitFrames:GetConfigUnit(unitKey)
      frameDB.auras = frameDB.auras or {}
      return frameDB.auras
    end

    refresh = function(flags)
      UFCB_RefreshUFAuras({
        unit = unitKey,
        rebuildDB = type(flags) == "table" and flags.rebuildDB == true or false,
        displayID = type(flags) == "table" and flags.displayID or nil,
        auraChange = type(flags) == "table" and flags.auraChange or nil,
      })
    end
  end

  UFCB_CreateCustomAuraEditor(getAuras, refresh, nil, unitKey):CreateDisplay(displayType, auraType)
end

local function UFCB_CommitAuraManagerPreviewVisibility(unitKey, displayID, enabled)
  if UFCB_BlockCombat() then
    return
  end

  local grouped = unitKey == "party" or unitKey == "raid"
  local auraDB

  if grouped then
    local db = UFCB_GetGroupedDB(unitKey)
    db.auras = db.auras or {}
    auraDB = db.auras
  else
    local frameDB = ns.UnitFrames:GetConfigUnit(unitKey)
    frameDB.auras = frameDB.auras or {}
    auraDB = frameDB.auras
  end

  local displays = ns.UFAuraFilters.NormalizeDisplays(auraDB)
  local display = displays[displayID]
  if not display then
    return
  end

  display.enabled = enabled == true
  ns.UFAuraFilters.NormalizeDisplay(display, displayID)
  auraDB.selectedCustomDisplayID = displayID

  ns.UFPreview.RefreshAuraManagerPreview()

  if grouped then
    UFCB_GetGroupedModule(unitKey):RefreshAuraDisplay({
      rebuildDB = true,
      auras = true,
      displayID = displayID,
      auraChange = "state",
    })
    UFCB_RefreshGroupedTestPreview(unitKey)
  else
    UFCB_RefreshUFAuras({
      unit = unitKey,
      rebuildDB = true,
      displayID = displayID,
      auraChange = "state",
    })
  end

  Addon:NotifyOptionsTreeChanged("unitframes", ns._PUIActiveOptionsPath)
end

local function UFCB_CommitAuraManagerPreviewPosition(
  unitKey,
  displayID,
  anchorPoint,
  relativePoint,
  xOffset,
  yOffset
)
  if UFCB_BlockCombat() then
    return
  end

  local grouped = unitKey == "party" or unitKey == "raid"
  local auraDB

  if grouped then
    local db = UFCB_GetGroupedDB(unitKey)
    db.auras = db.auras or {}
    auraDB = db.auras
  else
    local frameDB = ns.UnitFrames:GetConfigUnit(unitKey)
    frameDB.auras = frameDB.auras or {}
    auraDB = frameDB.auras
  end

  local displays = ns.UFAuraFilters.NormalizeDisplays(auraDB)
  local display = displays[displayID]
  if not display then
    return
  end

  display.anchorPoint = anchorPoint
  display.relativePoint = relativePoint
  display.xOffset = xOffset
  display.yOffset = yOffset
  ns.UFAuraFilters.NormalizeDisplay(display, displayID)
  auraDB.selectedCustomDisplayID = displayID

  ns.UFPreview.RefreshAuraManagerPreview()

  if grouped then
    UFCB_GetGroupedModule(unitKey):RefreshAuraDisplay({
      rebuildDB = true,
      auras = true,
      displayID = displayID,
      auraChange = "layout",
    })
    UFCB_RefreshGroupedTestPreview(unitKey)
  else
    UFCB_RefreshUFAuras({
      unit = unitKey,
      rebuildDB = true,
      displayID = displayID,
      auraChange = "layout",
    })
  end

  Addon:NotifyOptionsTreeChanged("unitframes", ns._PUIActiveOptionsPath)
end

UFCB_CreateAuraManagerPreviewDisplay = P:Def(
  "UFCB_CreateAuraManagerPreviewDisplay",
  UFCB_CreateAuraManagerPreviewDisplay
)
UFCB_CommitAuraManagerPreviewVisibility = P:Def(
  "UFCB_CommitAuraManagerPreviewVisibility",
  UFCB_CommitAuraManagerPreviewVisibility
)
UFCB_CommitAuraManagerPreviewPosition = P:Def(
  "UFCB_CommitAuraManagerPreviewPosition",
  UFCB_CommitAuraManagerPreviewPosition
)
ns.UFPreview.RegisterAuraManagerDisplayCreator(UFCB_CreateAuraManagerPreviewDisplay)
ns.UFPreview.RegisterAuraManagerVisibilityCommitter(UFCB_CommitAuraManagerPreviewVisibility)
ns.UFPreview.RegisterAuraManagerPositionCommitter(UFCB_CommitAuraManagerPreviewPosition)


  GetCBUnitCfg = P:Def("GetCBUnitCfg", GetCBUnitCfg)
  UFCB_CopyTable = P:Def("UFCB_CopyTable", UFCB_CopyTable)
  WarnCombatLocked = P:Def("WarnCombatLocked", WarnCombatLocked)
  UFCB_RefreshUFTextures = P:Def("UFCB_RefreshUFTextures", UFCB_RefreshUFTextures)
  UFCB_RefreshUFMouseover = P:Def("UFCB_RefreshUFMouseover", UFCB_RefreshUFMouseover)
  UFCB_RefreshUFHealthPrediction = P:Def("UFCB_RefreshUFHealthPrediction", UFCB_RefreshUFHealthPrediction)
  UFCB_RefreshUFTargetHighlight = P:Def("UFCB_RefreshUFTargetHighlight", UFCB_RefreshUFTargetHighlight)
  UFCB_RefreshUFAuras = P:Def("UFCB_RefreshUFAuras", UFCB_RefreshUFAuras)
  UFCB_RefreshUFText = P:Def("UFCB_RefreshUFText", UFCB_RefreshUFText)
  CB_RefreshUnit = P:Def("CB_RefreshUnit", CB_RefreshUnit)
  UFCB_BlockCombat = P:Def("UFCB_BlockCombat", UFCB_BlockCombat)
  UFCB_BuildInlineArgsGroup = P:Def("UFCB_BuildInlineArgsGroup", UFCB_BuildInlineArgsGroup)
  UFCB_GetInlineSectionKey = P:Def("UFCB_GetInlineSectionKey", UFCB_GetInlineSectionKey)
  UFCB_BuildCategorizedInlineArgs = P:Def("UFCB_BuildCategorizedInlineArgs", UFCB_BuildCategorizedInlineArgs)
  UFCB_GetValidChoice = P:Def("UFCB_GetValidChoice", UFCB_GetValidChoice)
  UFCB_GetTextModeChoice = P:Def("UFCB_GetTextModeChoice", UFCB_GetTextModeChoice)
  UFCB_GetNumberOrDefault = P:Def("UFCB_GetNumberOrDefault", UFCB_GetNumberOrDefault)
  UFCB_GetClampedNumber = P:Def("UFCB_GetClampedNumber", UFCB_GetClampedNumber)
  UFCB_GetCastbarRefreshUnit = P:Def("UFCB_GetCastbarRefreshUnit", UFCB_GetCastbarRefreshUnit)
  UFCB_GetOutlineValues = P:Def("UFCB_GetOutlineValues", UFCB_GetOutlineValues)
  UFCB_GetGlobalOutlineValue = P:Def("UFCB_GetGlobalOutlineValue", UFCB_GetGlobalOutlineValue)
  UFCB_SetStoredOutline = P:Def("UFCB_SetStoredOutline", UFCB_SetStoredOutline)
  UFCB_BuildUnavailableArgs = P:Def("UFCB_BuildUnavailableArgs", UFCB_BuildUnavailableArgs)
  UFCB_BuildGeneralAppearanceArgs = P:Def("UFCB_BuildGeneralAppearanceArgs", UFCB_BuildGeneralAppearanceArgs)
  UFCB_BuildGeneralAurasArgs = P:Def("UFCB_BuildGeneralAurasArgs", UFCB_BuildGeneralAurasArgs)
  UFCB_BuildGeneralTextFontsArgs = P:Def("UFCB_BuildGeneralTextFontsArgs", UFCB_BuildGeneralTextFontsArgs)
  UFCB_BuildGeneralAnchorsArgs = P:Def("UFCB_BuildGeneralAnchorsArgs", UFCB_BuildGeneralAnchorsArgs)
  UFCB_BuildGeneralTexturesArgs = P:Def("UFCB_BuildGeneralTexturesArgs", UFCB_BuildGeneralTexturesArgs)
  UFCB_BuildSharedFrameGeneralArgs = P:Def("UFCB_BuildSharedFrameGeneralArgs", UFCB_BuildSharedFrameGeneralArgs)
  UFCB_BuildUnitGeneralArgs = P:Def("UFCB_BuildUnitGeneralArgs", UFCB_BuildUnitGeneralArgs)
  UFCB_BuildSharedTextLeafArgs = P:Def("UFCB_BuildSharedTextLeafArgs", UFCB_BuildSharedTextLeafArgs)
  UFCB_BuildUnitTextArgs = P:Def("UFCB_BuildUnitTextArgs", UFCB_BuildUnitTextArgs)
  UFCB_BuildAuraGeneralCommonArgs = P:Def("UFCB_BuildAuraGeneralCommonArgs", UFCB_BuildAuraGeneralCommonArgs)
  UFCB_BuildAuraSpellIDTooltipArg = P:Def("UFCB_BuildAuraSpellIDTooltipArg", UFCB_BuildAuraSpellIDTooltipArg)
  UFCB_CreateCustomAuraEditor = P:Def("UFCB_CreateCustomAuraEditor", UFCB_CreateCustomAuraEditor)
  UFCB_BuildCustomAuraDisplaysArgs = P:Def("UFCB_BuildCustomAuraDisplaysArgs", UFCB_BuildCustomAuraDisplaysArgs)
  UFCB_GetAuraManagerTreeLabel = P:Def("UFCB_GetAuraManagerTreeLabel", UFCB_GetAuraManagerTreeLabel)
  UFCB_BuildAuraManagerTreeArgs = P:Def("UFCB_BuildAuraManagerTreeArgs", UFCB_BuildAuraManagerTreeArgs)
  UFCB_BuildSharedAuraTabs = P:Def("UFCB_BuildSharedAuraTabs", UFCB_BuildSharedAuraTabs)
  UFCB_BuildUnitAurasArgs = P:Def("UFCB_BuildUnitAurasArgs", UFCB_BuildUnitAurasArgs)
  UFCB_GetGroupedKind = P:Def("UFCB_GetGroupedKind", UFCB_GetGroupedKind)
  UFCB_GetGroupedModule = P:Def("UFCB_GetGroupedModule", UFCB_GetGroupedModule)
  UFCB_GetGroupedDB = P:Def("UFCB_GetGroupedDB", UFCB_GetGroupedDB)
  UFCB_SetGroupedModuleEnabled = P:Def("UFCB_SetGroupedModuleEnabled", UFCB_SetGroupedModuleEnabled)
  UFCB_RefreshGroupedTestPreview = P:Def("UFCB_RefreshGroupedTestPreview", UFCB_RefreshGroupedTestPreview)
  UFCB_MutateGrouped = P:Def("UFCB_MutateGrouped", UFCB_MutateGrouped)
  UFCB_BuildPartyGeneralArgs = P:Def("UFCB_BuildPartyGeneralArgs", UFCB_BuildPartyGeneralArgs)
  UFCB_BuildPartyTextArgs = P:Def("UFCB_BuildPartyTextArgs", UFCB_BuildPartyTextArgs)
  UFCB_BuildPartyAuraArgs = P:Def("UFCB_BuildPartyAuraArgs", UFCB_BuildPartyAuraArgs)
  UFCB_BuildCastbarArgs = P:Def("UFCB_BuildCastbarArgs", UFCB_BuildCastbarArgs)
  UFCB_BuildTreeGroupLeaf = P:Def("UFCB_BuildTreeGroupLeaf", UFCB_BuildTreeGroupLeaf)
  UFCB_BuildTreeArgsFromSpecs = P:Def("UFCB_BuildTreeArgsFromSpecs", UFCB_BuildTreeArgsFromSpecs)
  UFCB_BuildExtraLeaf = P:Def("UFCB_BuildExtraLeaf", UFCB_BuildExtraLeaf)
  UFCB_BuildUnitBaseLeafSpecs = P:Def("UFCB_BuildUnitBaseLeafSpecs", UFCB_BuildUnitBaseLeafSpecs)
  UFCB_BuildUnitTree = P:Def("UFCB_BuildUnitTree", UFCB_BuildUnitTree)
  UFCB_BuildPartyPetsArgs = P:Def("UFCB_BuildPartyPetsArgs", UFCB_BuildPartyPetsArgs)
  UFCB_BuildGroupedRootLeafSpecs = P:Def("UFCB_BuildGroupedRootLeafSpecs", UFCB_BuildGroupedRootLeafSpecs)
  UFCB_BuildGroupedRootArgs = P:Def("UFCB_BuildGroupedRootArgs", UFCB_BuildGroupedRootArgs)
  UFCB_BuildGeneralRootLeafSpecs = P:Def("UFCB_BuildGeneralRootLeafSpecs", UFCB_BuildGeneralRootLeafSpecs)
  UFCB_BuildGeneralRootArgs = P:Def("UFCB_BuildGeneralRootArgs", UFCB_BuildGeneralRootArgs)
  UFCB_BuildUnitEntryArgs = P:Def("UFCB_BuildUnitEntryArgs", UFCB_BuildUnitEntryArgs)
  UFCB_BuildTopLevelUnitArgs = P:Def("UFCB_BuildTopLevelUnitArgs", UFCB_BuildTopLevelUnitArgs)
  UFCB_IsUsingGlobalFont = P:Def("UFCB_IsUsingGlobalFont", UFCB_IsUsingGlobalFont)
  UFCB_GetPlayerQuickSetupState = P:Def("UFCB_GetPlayerQuickSetupState", UFCB_GetPlayerQuickSetupState)
  UFCB_GetQuickAuraDisplay = P:Def("UFCB_GetQuickAuraDisplay", UFCB_GetQuickAuraDisplay)
  UFCB_GetQuickAuraVisibility = P:Def("UFCB_GetQuickAuraVisibility", UFCB_GetQuickAuraVisibility)
  UFCB_SetQuickAuraVisibility = P:Def("UFCB_SetQuickAuraVisibility", UFCB_SetQuickAuraVisibility)
  UFCB_GetQuickAuraGrowth = P:Def("UFCB_GetQuickAuraGrowth", UFCB_GetQuickAuraGrowth)
  UF.GetQuickSetupValue = P:Def("UF.GetQuickSetupValue", UF.GetQuickSetupValue)
  UF.SetQuickSetupValue = P:Def("UF.SetQuickSetupValue", UF.SetQuickSetupValue)
  UFCB_MergeOptionArgs = P:Def("UFCB_MergeOptionArgs", UFCB_MergeOptionArgs)
  UFCB_FocusAuraSlotSpellID = P:Def("UFCB_FocusAuraSlotSpellID", UFCB_FocusAuraSlotSpellID)
  UFCB_RunGroupedRefreshNow = P:Def("UFCB_RunGroupedRefreshNow", UFCB_RunGroupedRefreshNow)
  MergeGroupedRefreshFlags = P:Def("MergeGroupedRefreshFlags", MergeGroupedRefreshFlags)
  UFCB_RequestGroupedRefresh = P:Def("UFCB_RequestGroupedRefresh", UFCB_RequestGroupedRefresh)
  UFCB_BuildRaidIndicatorArgs = P:Def("UFCB_BuildRaidIndicatorArgs", UFCB_BuildRaidIndicatorArgs)
  UFCB_GetEmpowerColorSet = P:Def("UFCB_GetEmpowerColorSet", UFCB_GetEmpowerColorSet)
  UFCB_GetEmpowerStageColor = P:Def("UFCB_GetEmpowerStageColor", UFCB_GetEmpowerStageColor)
  UFCB_EnsureEmpowerColorTable = P:Def("UFCB_EnsureEmpowerColorTable", UFCB_EnsureEmpowerColorTable)
  UFCB_BuildEmpowerStageColorArgs = P:Def("UFCB_BuildEmpowerStageColorArgs", UFCB_BuildEmpowerStageColorArgs)
