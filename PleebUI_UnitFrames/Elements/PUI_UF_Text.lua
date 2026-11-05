
-- File: PUI_UF_Text.lua
-- Purpose: Shared UnitFrames text sizing, font resolution, and text layout helpers.


local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace


ns.UFText = ns.UFText or {}
local Text = ns.UFText
local Pixel = ns.Pixel

local _G = _G
local CreateFrame = _G.CreateFrame
local math_abs = _G.math.abs
local math_ceil = _G.math.ceil
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local tonumber = _G.tonumber
local type = _G.type
local setmetatable = _G.setmetatable
local tostring = _G.tostring

local LSM = ns.LSM
local Theme = ns.Theme
local OptionsUtil = ns.OptionsUtil


local P = select(1, ns.Pleebug:DropIn(Text, { name = "UnitFrames.Text" }))


local function Round(v)
  return Pixel.Round(tonumber(v) or 0)
end

local function GetAnchorRow(anchor)
  if anchor == "TOP" or anchor == "TOPLEFT" or anchor == "TOPRIGHT" then
    return "TOP"
  elseif anchor == "BOTTOM" or anchor == "BOTTOMLEFT" or anchor == "BOTTOMRIGHT" then
    return "BOTTOM"
  end

  return "MIDDLE"
end

local function GetAnchorEdgePoint(anchor, edge)
  local row = GetAnchorRow(anchor)
  return row == "MIDDLE" and edge or (row .. edge)
end

local function ResolveHorizontalJustification(anchor, defaultHorizontal)
  if anchor == "LEFT" or anchor == "TOPLEFT" or anchor == "BOTTOMLEFT" then
    return "LEFT"
  elseif anchor == "RIGHT" or anchor == "TOPRIGHT" or anchor == "BOTTOMRIGHT" then
    return "RIGHT"
  elseif anchor == "TOP" or anchor == "BOTTOM" or anchor == "CENTER" then
    return "CENTER"
  end

  return defaultHorizontal
end

local HEALTH_TAGS = {
  HIDE = "",
  PERCENT = "[perhp<$%]",
  CUR_PERCENT = "[curhp] - [perhp<$%]",
  CUR = "[curhp]",
}
local DEFAULT_HEALTH_TAG = "[curhp]/[maxhp]"

local SHORT_HEALTH_TAGS = {
  HIDE = "",
  PERCENT = "[perhp<$%]",
  CUR_PERCENT = "[pui:curhp] - [perhp<$%]",
  CUR = "[pui:curhp]",
}
local SHORT_DEFAULT_HEALTH_TAG = "[pui:curhp]/[maxhp]"

local NAME_TAGS = {
  first = "[pui:name(first)]",
  last = "[pui:name(last)]",
  full = "[pui:name(full)]",
}

local POWER_TAGS = {
  HIDE = "",
  PERCENT = "[perpp<$%]",
  CUR_PERCENT = "[curpp] - [perpp<$%]",
  CUR = "[curpp]",
}
local DEFAULT_POWER_TAG = "[curpp]/[maxpp]"

local SHORT_POWER_TAGS = {
  HIDE = "",
  PERCENT = "[perpp<$%]",
  CUR_PERCENT = "[pui:curpp] - [perpp<$%]",
  CUR = "[pui:curpp]",
}
local SHORT_DEFAULT_POWER_TAG = "[pui:curpp]/[pui:maxpp]"

local function ShouldShortenValues(textCfg, ufDB)
  local globalText = ufDB and ufDB.text or nil

  if globalText and globalText.shortenValues == true then
    return true
  end

  return textCfg and textCfg.shortenValues == true or false
end

local TextConfigKeyCache = setmetatable({}, { __mode = "k" })
local EMPTY_TEXT_CONFIG = {}

function Text.GetUnitTextConfig(unit)
  local uf = ns.UnitFrames
  local db = uf.db.profile
  local unitConfig = uf:GetConfigUnit(unit)
  return db.text or EMPTY_TEXT_CONFIG, unitConfig and unitConfig.text or EMPTY_TEXT_CONFIG
end

local function PickTextValue(global, per, useOverride, globalKey, perKey, default)
  if useOverride and per[perKey] ~= nil then
    return per[perKey]
  elseif global[globalKey] ~= nil then
    return global[globalKey]
  else
    return default
  end
end

local function ShouldUseGlobalFont(fontKey, useGlobalFont)
  if useGlobalFont ~= nil then
    return useGlobalFont == true
  end

  local standardKey = ns.FontDropdown.STANDARD_FONT_KEY
  return not (type(fontKey) == "string" and fontKey ~= "" and fontKey ~= standardKey)
end

function Text.ResolveFontForText(unit, kind, baseSize, cfg, useConfigText)
  local groupedText = useConfigText == true and type(cfg) == "table" and type(cfg.text) == "table" and cfg.text or nil
  local global
  local per

  if groupedText then
    global = EMPTY_TEXT_CONFIG
    per = EMPTY_TEXT_CONFIG
  else
    global, per = Text.GetUnitTextConfig(unit)
  end

  local sizeKey
  local fontConfigKey
  local useGlobalFontKey
  local outlineKey
  local anchorKey
  local customTypographyKey
  local customPositionKey
  local defaultAnchor

  if kind == "name" then
    sizeKey = "sizeName"
    fontConfigKey = "nameFont"
    useGlobalFontKey = "nameUseGlobalFont"
    outlineKey = "nameOutline"
    anchorKey = "anchorName"
    customTypographyKey = "nameUseCustomTypography"
    customPositionKey = "nameUseCustomPosition"
    defaultAnchor = "LEFT"
  elseif kind == "health" then
    sizeKey = "sizeHealth"
    fontConfigKey = "healthFont"
    useGlobalFontKey = "healthUseGlobalFont"
    outlineKey = "healthOutline"
    anchorKey = "anchorHealth"
    customTypographyKey = "healthUseCustomTypography"
    customPositionKey = "healthUseCustomPosition"
    defaultAnchor = "RIGHT"
  else
    sizeKey = "sizePower"
    fontConfigKey = "powerFont"
    useGlobalFontKey = "powerUseGlobalFont"
    outlineKey = "powerOutline"
    anchorKey = "anchorPower"
    customTypographyKey = "powerUseCustomTypography"
    customPositionKey = "powerUseCustomPosition"
    defaultAnchor = "RIGHT"
  end

  if groupedText then
    local fontKey = groupedText[fontConfigKey] or groupedText.font
    local outline = groupedText[outlineKey] or groupedText.outline

    if ShouldUseGlobalFont(fontKey, groupedText[useGlobalFontKey]) then
      fontKey = nil
    end

    local size = groupedText[sizeKey] or baseSize or 12
    outline = outline or "OUTLINE"
    local anchor = groupedText[anchorKey] or defaultAnchor

    local offsetXKey, offsetYKey
    if kind == "name" then
      offsetXKey, offsetYKey = "offsetNameX", "offsetNameY"
    elseif kind == "health" then
      offsetXKey, offsetYKey = "offsetHealthX", "offsetHealthY"
    else
      offsetXKey, offsetYKey = "offsetPowerX", "offsetPowerY"
    end

    local dx = groupedText[offsetXKey] or 0
    local dy = groupedText[offsetYKey] or 0

    return fontKey, size, outline, anchor, dx, dy
  end

  local useCustomTypography = per[customTypographyKey] == true
  local useCustomPosition = per[customPositionKey] == true
  local fontKey

  if useCustomTypography then
    fontKey = per[fontConfigKey]
  elseif not ShouldUseGlobalFont(global.font, global.useGlobalFont) then
    fontKey = global.font
  end

  local size = PickTextValue(global, per, useCustomTypography, sizeKey, sizeKey, baseSize or 12)
  local outline = PickTextValue(global, per, useCustomTypography, "outline", outlineKey, "OUTLINE")
  local anchor = PickTextValue(global, per, useCustomPosition, anchorKey, anchorKey, defaultAnchor)

  local offsetXKey
  local offsetYKey

  if kind == "name" then
    offsetXKey, offsetYKey = "offsetNameX", "offsetNameY"
  elseif kind == "health" then
    offsetXKey, offsetYKey = "offsetHealthX", "offsetHealthY"
  else
    offsetXKey, offsetYKey = "offsetPowerX", "offsetPowerY"
  end

  local dx = PickTextValue(global, per, useCustomPosition, offsetXKey, offsetXKey, 0)
  local dy = PickTextValue(global, per, useCustomPosition, offsetYKey, offsetYKey, 0)

  return fontKey, size, outline, anchor, dx, dy
end

function Text.GetConfigTextKey(cfg)
  local text = type(cfg) == "table" and cfg.text or nil
  if type(text) ~= "table" then
    return ""
  end

  local nameUseCustomTypography = text.nameUseCustomTypography
  local healthUseCustomTypography = text.healthUseCustomTypography
  local powerUseCustomTypography = text.powerUseCustomTypography
  local nameUseCustomPosition = text.nameUseCustomPosition
  local healthUseCustomPosition = text.healthUseCustomPosition
  local powerUseCustomPosition = text.powerUseCustomPosition
  local font = text.font or ""
  local useGlobalFont = text.useGlobalFont
  local nameFont = text.nameFont or ""
  local nameUseGlobalFont = text.nameUseGlobalFont
  local healthFont = text.healthFont or ""
  local healthUseGlobalFont = text.healthUseGlobalFont
  local powerFont = text.powerFont or ""
  local powerUseGlobalFont = text.powerUseGlobalFont
  local outline = text.outline or ""
  local nameOutline = text.nameOutline or ""
  local healthOutline = text.healthOutline or ""
  local powerOutline = text.powerOutline or ""
  local nameSize = text.sizeName or ""
  local healthSize = text.sizeHealth or ""
  local powerSize = text.sizePower or ""
  local anchorName = text.anchorName or ""
  local anchorHealth = text.anchorHealth or ""
  local anchorPower = text.anchorPower or ""
  local offsetNameX = text.offsetNameX or ""
  local offsetNameY = text.offsetNameY or ""
  local offsetHealthX = text.offsetHealthX or ""
  local offsetHealthY = text.offsetHealthY or ""
  local offsetPowerX = text.offsetPowerX or ""
  local offsetPowerY = text.offsetPowerY or ""
  local uf = ns.UnitFrames
  local ufDB = uf and uf.db and uf.db.profile or nil
  local shortenValues = ShouldShortenValues(text, ufDB)
  local fontSlug = ns.UnitFrames.db.profile.text.fontSlug == true

  local cache = TextConfigKeyCache[text]
  if cache
    and cache.shortenValues == shortenValues
    and cache.fontSlug == fontSlug
    and cache.nameUseCustomTypography == nameUseCustomTypography
    and cache.healthUseCustomTypography == healthUseCustomTypography
    and cache.powerUseCustomTypography == powerUseCustomTypography
    and cache.nameUseCustomPosition == nameUseCustomPosition
    and cache.healthUseCustomPosition == healthUseCustomPosition
    and cache.powerUseCustomPosition == powerUseCustomPosition
    and cache.font == font
    and cache.useGlobalFont == useGlobalFont
    and cache.nameFont == nameFont
    and cache.nameUseGlobalFont == nameUseGlobalFont
    and cache.healthFont == healthFont
    and cache.healthUseGlobalFont == healthUseGlobalFont
    and cache.powerFont == powerFont
    and cache.powerUseGlobalFont == powerUseGlobalFont
    and cache.outline == outline
    and cache.nameOutline == nameOutline
    and cache.healthOutline == healthOutline
    and cache.powerOutline == powerOutline
    and cache.nameSize == nameSize
    and cache.healthSize == healthSize
    and cache.powerSize == powerSize
    and cache.anchorName == anchorName
    and cache.anchorHealth == anchorHealth
    and cache.anchorPower == anchorPower
    and cache.offsetNameX == offsetNameX
    and cache.offsetNameY == offsetNameY
    and cache.offsetHealthX == offsetHealthX
    and cache.offsetHealthY == offsetHealthY
    and cache.offsetPowerX == offsetPowerX
    and cache.offsetPowerY == offsetPowerY
  then
    return cache.key
  end

  local key = tostring(fontSlug)
    .. "|" .. tostring(shortenValues)
    .. "|" .. tostring(nameUseCustomTypography)
    .. "|" .. tostring(healthUseCustomTypography)
    .. "|" .. tostring(powerUseCustomTypography)
    .. "|" .. tostring(nameUseCustomPosition)
    .. "|" .. tostring(healthUseCustomPosition)
    .. "|" .. tostring(powerUseCustomPosition)
    .. "|" .. tostring(font)
    .. "|" .. tostring(useGlobalFont)
    .. "|" .. tostring(nameFont)
    .. "|" .. tostring(nameUseGlobalFont)
    .. "|" .. tostring(healthFont)
    .. "|" .. tostring(healthUseGlobalFont)
    .. "|" .. tostring(powerFont)
    .. "|" .. tostring(powerUseGlobalFont)
    .. "|" .. tostring(outline)
    .. "|" .. tostring(nameOutline)
    .. "|" .. tostring(healthOutline)
    .. "|" .. tostring(powerOutline)
    .. "|" .. tostring(nameSize)
    .. "|" .. tostring(healthSize)
    .. "|" .. tostring(powerSize)
    .. "|" .. tostring(anchorName)
    .. "|" .. tostring(anchorHealth)
    .. "|" .. tostring(anchorPower)
    .. "|" .. tostring(offsetNameX)
    .. "|" .. tostring(offsetNameY)
    .. "|" .. tostring(offsetHealthX)
    .. "|" .. tostring(offsetHealthY)
    .. "|" .. tostring(offsetPowerX)
    .. "|" .. tostring(offsetPowerY)

  TextConfigKeyCache[text] = {
    shortenValues = shortenValues,
    fontSlug = fontSlug,
    nameUseCustomTypography = nameUseCustomTypography,
    healthUseCustomTypography = healthUseCustomTypography,
    powerUseCustomTypography = powerUseCustomTypography,
    nameUseCustomPosition = nameUseCustomPosition,
    healthUseCustomPosition = healthUseCustomPosition,
    powerUseCustomPosition = powerUseCustomPosition,
    font = font,
    useGlobalFont = useGlobalFont,
    nameFont = nameFont,
    nameUseGlobalFont = nameUseGlobalFont,
    healthFont = healthFont,
    healthUseGlobalFont = healthUseGlobalFont,
    powerFont = powerFont,
    powerUseGlobalFont = powerUseGlobalFont,
    outline = outline,
    nameOutline = nameOutline,
    healthOutline = healthOutline,
    powerOutline = powerOutline,
    nameSize = nameSize,
    healthSize = healthSize,
    powerSize = powerSize,
    anchorName = anchorName,
    anchorHealth = anchorHealth,
    anchorPower = anchorPower,
    offsetNameX = offsetNameX,
    offsetNameY = offsetNameY,
    offsetHealthX = offsetHealthX,
    offsetHealthY = offsetHealthY,
    offsetPowerX = offsetPowerX,
    offsetPowerY = offsetPowerY,
    key = key,
  }

  return key
end

function Text.ApplyUnitTextFont(fontString, unit, kind, baseSize, cfg, useConfigText)
  if not fontString then
    return
  end

  local fontKey, size, outline = Text.ResolveFontForText(unit, kind, baseSize, cfg, useConfigText)

  size = tonumber(size) or tonumber(baseSize) or 12
  size = math_floor(size + 0.5)

  outline = Theme.NormalizeOutlineFlags(outline or "")

  local _, globalFlags = Theme.GetIconTextGlobal()
  globalFlags = Theme.NormalizeOutlineFlags(globalFlags or "")

  if outline == "" then
    outline = (globalFlags ~= "" and globalFlags) or "OUTLINE"
  end

  if ns.UnitFrames.db.profile.text.fontSlug == true and outline == "OUTLINE" then
    outline = "OUTLINE, SLUG"
  end

  local useGlobalFont = fontKey == nil or fontKey == ""
  fontKey = OptionsUtil.ResolveFontKey(fontKey, useGlobalFont)

  ns.Theme.SetRuntimeFont(
    fontString,
    LSM:Fetch("font", fontKey, true),
    Theme.ResolveFontSize(size, "unitFrames"),
    outline
  )
end

function Text.ApplyUnitTextLayout(frame, unit, cfg, useConfigText, groupKind)
  local healthBar = frame and frame.Health
  if not frame or not healthBar then
    return
  end

  local powerBar = frame.Power
  local _, _, _, healthAnchor, healthDX, healthDY = Text.ResolveFontForText(unit, "health", nil, cfg, useConfigText)
  healthAnchor = healthAnchor or "RIGHT"

  if frame.NameText then
    local _, _, _, anchor, dx, dy = Text.ResolveFontForText(unit, "name", nil, cfg, useConfigText)
    frame.__puiNameAnchor = anchor or "LEFT"
    local justifyH = ResolveHorizontalJustification(frame.__puiNameAnchor, "LEFT")
    local nameRow = GetAnchorRow(frame.__puiNameAnchor)

    local nameAnchor = frame.__puiNameAnchor
    if groupKind == "raid" then
      local onePixel = Pixel.GetOnePixel()
      local nameHeight = math_ceil(frame.NameText:GetLineHeight() / onePixel) * onePixel
      frame.NameText:SetHeight(nameHeight)
      frame.NameText:SetJustifyV("TOP")

      -- Round the text box's top edge, not an odd-height health bar's half-pixel centre.
      if nameAnchor == "LEFT" or nameAnchor == "RIGHT" or nameAnchor == "CENTER" then
        dy = (dy or 0) + (nameHeight - Round(healthBar:GetHeight())) * 0.5
        nameAnchor = justifyH == "CENTER" and "TOP" or ("TOP" .. justifyH)
      end
    end

    frame.NameText:ClearAllPoints()
    frame.NameText:SetJustifyH(justifyH)
    frame.NameText:SetWidth(0)

    if groupKind == "raid" and justifyH == "LEFT" then
      Pixel.Point(frame.NameText, nameAnchor, healthBar, nameAnchor, dx or 0, dy or 0)
      local rightAnchor = "TOPRIGHT"
      if nameAnchor == "BOTTOMLEFT" then
        rightAnchor = "BOTTOMRIGHT"
      end

      local offsetX = tonumber(dx) or 0
      local maxInset = math_max(0, healthBar:GetWidth() - Round(1))
      local rightOffset = offsetX - math_min(math_abs(offsetX), maxInset)
      Pixel.Point(frame.NameText, rightAnchor, healthBar, rightAnchor, rightOffset, dy or 0)
    else
      local leftPoint = GetAnchorEdgePoint(nameAnchor, "LEFT")
      local rightPoint = GetAnchorEdgePoint(nameAnchor, "RIGHT")
      local offsetX = tonumber(dx) or 0
      local maxInset = math_max(0, healthBar:GetWidth() - Round(1))
      local leftInset = math_min(math_max(offsetX, 0), maxInset)
      local rightInset = -math_min(math_max(-offsetX, 0), maxInset)
      local textCfg = cfg and cfg.text
      local sameRow = groupKind ~= "raid"
        and frame.HealthText
        and nameRow == GetAnchorRow(healthAnchor)
        and not (textCfg and (textCfg.hideHealthText == true or textCfg.healthMode == "HIDE"))

      if sameRow then
        local healthSide = ResolveHorizontalJustification(healthAnchor, "RIGHT")
        local verticalOffset = (dy or 0) - (healthDY or 0)
        local spacing = Round(3)

        if healthSide == "LEFT" or (healthSide == "CENTER" and justifyH == "RIGHT") then
          Pixel.Point(frame.NameText, leftPoint, frame.HealthText, GetAnchorEdgePoint(healthAnchor, "RIGHT"), spacing, verticalOffset)
          Pixel.Point(frame.NameText, rightPoint, healthBar, rightPoint, rightInset, dy or 0)
        else
          Pixel.Point(frame.NameText, leftPoint, healthBar, leftPoint, leftInset, dy or 0)
          Pixel.Point(frame.NameText, rightPoint, frame.HealthText, GetAnchorEdgePoint(healthAnchor, "LEFT"), -spacing, verticalOffset)
        end
      else
        Pixel.Point(frame.NameText, leftPoint, healthBar, leftPoint, leftInset, dy or 0)
        Pixel.Point(frame.NameText, rightPoint, healthBar, rightPoint, rightInset, dy or 0)
      end
    end

    frame.NameText:SetMaxLines(1)
    frame.NameText:SetWordWrap(false)
  end

  if frame.HealthText then
    frame.__puiHealthAnchor = healthAnchor
    local justifyH = ResolveHorizontalJustification(healthAnchor, "RIGHT")

    frame.HealthText:ClearAllPoints()
    frame.HealthText:SetJustifyH(justifyH)
    Pixel.Point(frame.HealthText, healthAnchor, healthBar, healthAnchor, healthDX or 0, healthDY or 0)
  end

  if frame.PowerText and powerBar then
    local _, _, _, anchor, dx, dy = Text.ResolveFontForText(unit, "power", nil, cfg, useConfigText)
    anchor = anchor or "RIGHT"
    local justifyH = ResolveHorizontalJustification(anchor, "RIGHT")

    frame.PowerText:ClearAllPoints()
    frame.PowerText:SetJustifyH(justifyH)
    Pixel.Point(frame.PowerText, anchor, powerBar, anchor, dx or 0, dy or 0)
  end
end

function Text.RefreshTextForFrame(frame, fontRev)
  local unit = frame and frame.__puiConfigUnit
  if not unit or not frame.config or frame.__puiElementsPaused == true then
    return
  end

  local uf = ns.UnitFrames
  local ufDB = uf and uf.db and uf.db.profile or nil
  local cfg = frame.config

  Text.ApplyFrame(frame, unit, cfg, fontRev, {
    forceNoPower = frame.__puiForceNoPower == true,
    groupKind = frame.__puiGroupKind,
    useConfigText = frame.__puiUseConfigText == true,
    colors = cfg.colors or (ufDB and ufDB.colors),
  })
end

function Text.TagOrClearFrame(frame, fontString, tagString)
  if not frame or not fontString then
    return
  end

  if not tagString or tagString == "" then
    fontString:Hide()

    if frame.Untag and fontString.__puiTagString then
      frame:Untag(fontString)
    end

    fontString.__puiTagString = nil
    fontString:SetText("")
    return
  end

  if fontString.__puiTagString == tagString then
    fontString:Show()
    return
  end

  if frame.Tag then
    if frame.Untag and fontString.__puiTagString then
      frame:Untag(fontString)
    end

    frame:Tag(fontString, tagString)
    fontString.__puiTagString = tagString

    if fontString.UpdateTag then
      fontString:UpdateTag()
    end
  end

  fontString:Show()
end

function Text.Construct(frame, unit, cfg, deferLayout)
  if not frame then
    return
  end

  local parent = frame.textOverlay
  if not parent then
    parent = CreateFrame("Frame", nil, frame.RaisedElementParent or frame)
    frame.textOverlay = parent
  elseif frame.RaisedElementParent and parent:GetParent() ~= frame.RaisedElementParent then
    parent:SetParent(frame.RaisedElementParent)
  end

  Pixel.AllPoints(parent, frame)
  parent:EnableMouse(false)
  parent:Show()
  frame.TextParent = parent

  local created = false

  if not frame.NameText then
    frame.NameText = parent:CreateFontString(nil, "OVERLAY")
    created = true
  end

  if not frame.HealthText then
    frame.HealthText = parent:CreateFontString(nil, "OVERLAY")
    created = true
  end

  if not frame.PowerText then
    frame.PowerText = parent:CreateFontString(nil, "OVERLAY")
    created = true
  end

  if created or frame.__puiTextConstructedUnit ~= unit then
    local useConfigText = frame.__puiUseConfigText == true
    local baseNameSize, baseHPSize, basePowerSize = ns.UnitFrames:GetBaseTextSizesForUnit(unit)

    Text.ApplyUnitTextFont(frame.NameText, unit, "name", baseNameSize, cfg, useConfigText)
    Text.ApplyUnitTextFont(frame.HealthText, unit, "health", baseHPSize, cfg, useConfigText)
    Text.ApplyUnitTextFont(frame.PowerText, unit, "power", basePowerSize, cfg, useConfigText)

    if deferLayout ~= true then
      Text.ApplyUnitTextLayout(frame, unit, cfg, useConfigText, frame.__puiGroupKind)
    end

    frame.__puiTextConstructedUnit = unit
  end
end

local CLASSIFICATION_ATLAS = {
  elite = "nameplates-icon-elite-gold",
  worldboss = "nameplates-icon-elite-gold",
  rareelite = "nameplates-icon-elite-silver",
  rare = "nameplates-icon-rareelite",
}
local FRIENDLY_LEVEL_COLOR = { r = 1, g = 0.82, b = 0 }

local function ApplyHealthDifficultyColor(frame, color)
  frame.__puiHealthDifficultyColor = color
  frame.HealthText:SetTextColor(
    color and color.r or frame.__puiHealthTextColorR or 1,
    color and color.g or frame.__puiHealthTextColorG or 1,
    color and color.b or frame.__puiHealthTextColorB or 1,
    frame.__puiHealthTextColorA or 1
  )
end

local function ApplyClassificationBadge(frame, atlas)
  local badge = frame.ClassificationBadge
  if atlas then
    badge:SetAtlas(atlas)
    badge:Show()
  elseif badge then
    badge:Hide()
  end
end

local function UpdateUnitDifficulty(frame, event, unit)
  if (event == "UNIT_LEVEL" or event == "UNIT_FACTION" or event == "UNIT_CLASSIFICATION_CHANGED")
    and unit ~= frame.__unit then return end
  unit = frame.__unit

  local color, atlas
  local exists = unit and UnitExists(unit)
  if not issecretvalue(exists) and exists then
    if frame.__puiColorHealthByDifficulty then
      local attackable = UnitCanAttack("player", unit)
      if not issecretvalue(attackable) then
        if attackable then
          local difficulty = C_PlayerInfo.GetContentDifficultyCreatureForPlayer(unit)
          if not issecretvalue(difficulty) then
            color = GetDifficultyColor(difficulty)
          end
        else
          color = FRIENDLY_LEVEL_COLOR
        end
      end
    end

    if frame.__puiShowClassification and (frame.__puiClassificationInInstances or not IsInInstance()) then
      local classification = UnitClassification(unit)
      if not issecretvalue(classification) then
        atlas = CLASSIFICATION_ATLAS[classification]
      end
    end
  end

  if frame.__puiColorHealthByDifficulty then
    ApplyHealthDifficultyColor(frame, color)
  end
  ApplyClassificationBadge(frame, atlas)
end

local function EnableUnitDifficulty(frame)
  if not frame.__puiColorHealthByDifficulty and not frame.__puiShowClassification then return end

  frame:RegisterEvent("UNIT_LEVEL", UpdateUnitDifficulty)
  frame:RegisterEvent("UNIT_FACTION", UpdateUnitDifficulty)
  frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", UpdateUnitDifficulty)
  frame:RegisterEvent("PLAYER_LEVEL_UP", UpdateUnitDifficulty, true)
  frame:RegisterEvent("ZONE_CHANGED_NEW_AREA", UpdateUnitDifficulty, true)
  return true
end

local function DisableUnitDifficulty(frame)
  frame:UnregisterEvent("UNIT_LEVEL", UpdateUnitDifficulty)
  frame:UnregisterEvent("UNIT_FACTION", UpdateUnitDifficulty)
  frame:UnregisterEvent("UNIT_CLASSIFICATION_CHANGED", UpdateUnitDifficulty)
  frame:UnregisterEvent("PLAYER_LEVEL_UP", UpdateUnitDifficulty)
  frame:UnregisterEvent("ZONE_CHANGED_NEW_AREA", UpdateUnitDifficulty)
  ApplyHealthDifficultyColor(frame, nil)
  ApplyClassificationBadge(frame, nil)
end

ns.oUF:AddElement("PUIUnitDifficulty", UpdateUnitDifficulty, EnableUnitDifficulty, DisableUnitDifficulty)

local function ConfigureUnitDifficulty(frame, unit, cfg, textCfg, hpMode)
  local target = unit == "target"
  local boss = unit:match("^boss%d+$") ~= nil
  if not target and not boss then return end

  local colorHealth = hpMode ~= "HIDE" and textCfg.colorHealthByDifficulty == true
  local showBadge = target and cfg and cfg.showClassification == true
  if showBadge and not frame.ClassificationBadge then
    local badge = frame.TextParent:CreateTexture(nil, "OVERLAY")
    Pixel.Size(badge, 16, 16)
    Pixel.Point(badge, "LEFT", frame.Health, "RIGHT", 2, 0)
    frame.ClassificationBadge = badge
  end

  if frame.__puiColorHealthByDifficulty and not colorHealth then
    ApplyHealthDifficultyColor(frame, nil)
  end
  frame.__puiColorHealthByDifficulty = colorHealth
  frame.__puiShowClassification = showBadge
  frame.__puiClassificationInInstances = cfg and cfg.classificationInInstances == true

  if frame.__puiPresentationFrame then
    ApplyHealthDifficultyColor(frame, colorHealth and GetDifficultyColor(Enum.RelativeContentDifficulty.Difficult) or nil)
    ApplyClassificationBadge(frame, showBadge and CLASSIFICATION_ATLAS.rareelite or nil)
  elseif colorHealth or showBadge then
    frame:EnableElement("PUIUnitDifficulty")
    UpdateUnitDifficulty(frame)
  else
    frame:DisableElement("PUIUnitDifficulty")
  end
end

function Text.ApplyTextColors(frame, colors)
  if not frame then
    return
  end

  local fallback = colors and colors.nameText or { 1, 1, 1, 1 }

  local function Apply(fontString, cachePrefix, color)
    if not fontString or not fontString.SetTextColor then
      return
    end

    color = type(color) == "table" and color or fallback

    local r = color[1] or fallback[1] or 1
    local g = color[2] or fallback[2] or 1
    local b = color[3] or fallback[3] or 1
    local a = color[4] or fallback[4] or 1

    if frame[cachePrefix .. "R"] == r
      and frame[cachePrefix .. "G"] == g
      and frame[cachePrefix .. "B"] == b
      and frame[cachePrefix .. "A"] == a
    then
      return
    end

    frame[cachePrefix .. "R"] = r
    frame[cachePrefix .. "G"] = g
    frame[cachePrefix .. "B"] = b
    frame[cachePrefix .. "A"] = a
    local difficultyColor = fontString == frame.HealthText and frame.__puiHealthDifficultyColor
    if difficultyColor then
      fontString:SetTextColor(difficultyColor.r, difficultyColor.g, difficultyColor.b, a)
    else
      fontString:SetTextColor(r, g, b, a)
    end
  end

  Apply(frame.NameText, "__puiNameTextColor", colors and colors.nameText)
  Apply(frame.HealthText, "__puiHealthTextColor", colors and colors.healthText)
  Apply(frame.PowerText, "__puiPowerTextColor", colors and colors.powerText)
end

function Text.ApplyFrame(frame, unit, cfg, fontRev, opts)
  if not frame or not unit then
    return
  end

  opts = type(opts) == "table" and opts or {}
  local groupKind = opts.groupKind or frame.__puiGroupKind

  local useConfigText = opts.useConfigText == true or frame.__puiUseConfigText == true
  frame.__puiUseConfigText = useConfigText

  local needsConstruct = not frame.NameText or not frame.HealthText or not frame.PowerText or frame.__puiTextConstructedUnit ~= unit
  if needsConstruct then
    Text.Construct(frame, unit, cfg)
    frame.__puiTextApplyUnit = nil
    frame.__puiTextLayoutUnit = nil
    frame.__puiTextColorApplyReady = nil
  end

  local textCfg = (cfg and cfg.text) or {}
  local hideNameText = textCfg.hideNameText == true
  local hideHealthText = textCfg.hideHealthText == true
  local showHealth = not hideHealthText
  local hpMode = showHealth and (textCfg.healthMode or "CUR_MAX") or "HIDE"
  local uf = ns.UnitFrames
  local ufDB = uf and uf.db and uf.db.profile or nil
  local globalText = ufDB and ufDB.text or nil
  local ppMode = textCfg.powerMode or (not useConfigText and globalText and globalText.powerMode) or "CUR"
  local shortenValues = ShouldShortenValues(textCfg, ufDB)
  local healthTags = shortenValues and SHORT_HEALTH_TAGS or HEALTH_TAGS
  local defaultHealthTag = shortenValues and SHORT_DEFAULT_HEALTH_TAG or DEFAULT_HEALTH_TAG
  local powerTags = shortenValues and SHORT_POWER_TAGS or POWER_TAGS
  local defaultPowerTag = shortenValues and SHORT_DEFAULT_POWER_TAG or DEFAULT_POWER_TAG
  local globalPowerText = ufDB and ufDB.powerText or nil
  local powerBar = frame.Power
  local showPower = powerBar and cfg and cfg.showPower ~= false and opts.forceNoPower ~= true and powerBar:IsShown()

  if not useConfigText and globalPowerText and globalPowerText.enabled == false then
    ppMode = "HIDE"
    showPower = false
  end

  local curRev = tonumber(fontRev) or 0
  local textKey = Text.GetConfigTextKey(cfg)
  local classColoredNames = opts.colors and opts.colors.useClassForNames == true
  local showLevel = textCfg.showLevel == true
  local nameTag = "[pui:name]"
  if ns.Client.IsForever then
    nameTag = NAME_TAGS[textCfg.nameFormat] or NAME_TAGS.full
  end

  if frame.__puiTextApplyUnit ~= unit
    or frame.__puiTextApplyUseConfigText ~= useConfigText
    or frame.__puiTextApplyFontRev ~= curRev
    or frame.__puiTextApplyHealthMode ~= hpMode
    or frame.__puiTextApplyPowerMode ~= ppMode
    or frame.__puiTextApplyShortenValues ~= shortenValues
    or frame.__puiTextApplyHideNameText ~= hideNameText
    or frame.__puiTextApplyShowLevel ~= showLevel
    or frame.__puiTextApplyNameTag ~= nameTag
    or frame.__puiTextApplyShowHealth ~= showHealth
    or frame.__puiTextApplyShowPower ~= showPower
    or frame.__puiTextApplyConfigKey ~= textKey
    or frame.__puiTextApplyClassColoredNames ~= classColoredNames
  then
    if frame.__puiFontRev ~= curRev or frame.__puiTextConfigKey ~= textKey then
      local baseNameSize, baseHPSize, basePowerSize = ns.UnitFrames:GetBaseTextSizesForUnit(unit)

      if frame.NameText then
        Text.ApplyUnitTextFont(frame.NameText, unit, "name", baseNameSize, cfg, useConfigText)
      end

      if frame.HealthText then
        Text.ApplyUnitTextFont(frame.HealthText, unit, "health", baseHPSize, cfg, useConfigText)
      end

      if frame.PowerText then
        Text.ApplyUnitTextFont(frame.PowerText, unit, "power", basePowerSize, cfg, useConfigText)
      end

      frame.__puiFontRev = curRev
      frame.__puiTextConfigKey = textKey
    end

    frame.__puiTextApplyUnit = unit
    frame.__puiTextApplyUseConfigText = useConfigText
    frame.__puiTextApplyFontRev = curRev
    frame.__puiTextApplyHealthMode = hpMode
    frame.__puiTextApplyPowerMode = ppMode
    frame.__puiTextApplyShortenValues = shortenValues
    frame.__puiTextApplyHideNameText = hideNameText
    frame.__puiTextApplyShowLevel = showLevel
    frame.__puiTextApplyNameTag = nameTag
    frame.__puiTextApplyShowHealth = showHealth
    frame.__puiTextApplyShowPower = showPower
    frame.__puiTextApplyConfigKey = textKey
    frame.__puiTextApplyClassColoredNames = classColoredNames

    if hideNameText then
      Text.TagOrClearFrame(frame, frame.NameText, "")
    else
      Text.TagOrClearFrame(
        frame,
        frame.NameText,
        (showLevel and "[pui:level] " or "") .. (classColoredNames and "[raidcolor]" .. nameTag .. "|r" or nameTag)
      )
    end

    if showHealth then
      Text.TagOrClearFrame(frame, frame.HealthText, healthTags[hpMode] or defaultHealthTag)
    else
      Text.TagOrClearFrame(frame, frame.HealthText, "")
    end

    if showPower then
      Text.TagOrClearFrame(frame, frame.PowerText, powerTags[ppMode] or defaultPowerTag)
    elseif frame.PowerText then
      Text.TagOrClearFrame(frame, frame.PowerText, "")
    end
  end

  local healthBar = frame.Health
  local healthWidth = Round(healthBar:GetWidth())
  local healthHeight = Round(healthBar:GetHeight())
  local powerWidth = powerBar and Round(powerBar:GetWidth()) or 0
  local powerHeight = powerBar and Round(powerBar:GetHeight()) or 0

  if frame.__puiTextLayoutFontRev ~= curRev
    or frame.__puiTextLayoutUnit ~= unit
    or frame.__puiTextLayoutGroupKind ~= groupKind
    or frame.__puiTextLayoutUseConfigText ~= useConfigText
    or frame.__puiTextLayoutConfigKey ~= textKey
    or frame.__puiTextLayoutHealthMode ~= hpMode
    or frame.__puiTextLayoutPowerMode ~= ppMode
    or frame.__puiTextLayoutHideNameText ~= hideNameText
    or frame.__puiTextLayoutShowHealth ~= showHealth
    or frame.__puiTextLayoutShowPower ~= showPower
    or frame.__puiTextLayoutHealthWidth ~= healthWidth
    or frame.__puiTextLayoutHealthHeight ~= healthHeight
    or frame.__puiTextLayoutPowerWidth ~= powerWidth
    or frame.__puiTextLayoutPowerHeight ~= powerHeight
  then
    frame.__puiTextLayoutFontRev = curRev
    frame.__puiTextLayoutUnit = unit
    frame.__puiTextLayoutGroupKind = groupKind
    frame.__puiTextLayoutUseConfigText = useConfigText
    frame.__puiTextLayoutConfigKey = textKey
    frame.__puiTextLayoutHealthMode = hpMode
    frame.__puiTextLayoutPowerMode = ppMode
    frame.__puiTextLayoutHideNameText = hideNameText
    frame.__puiTextLayoutShowHealth = showHealth
    frame.__puiTextLayoutShowPower = showPower
    frame.__puiTextLayoutHealthWidth = healthWidth
    frame.__puiTextLayoutHealthHeight = healthHeight
    frame.__puiTextLayoutPowerWidth = powerWidth
    frame.__puiTextLayoutPowerHeight = powerHeight

    Text.ApplyUnitTextLayout(frame, unit, cfg, useConfigText, groupKind)
  end

  local colors = opts.colors
  local nameColor = colors and colors.nameText
  local healthColor = colors and colors.healthText
  local powerColor = colors and colors.powerText

  local fr = nameColor and nameColor[1] or 1
  local fg = nameColor and nameColor[2] or 1
  local fb = nameColor and nameColor[3] or 1
  local fa = nameColor and nameColor[4] or 1

  local nr = fr
  local ng = fg
  local nb = fb
  local na = fa

  local hr = healthColor and healthColor[1] or fr
  local hg = healthColor and healthColor[2] or fg
  local hb = healthColor and healthColor[3] or fb
  local ha = healthColor and healthColor[4] or fa

  local pr = powerColor and powerColor[1] or fr
  local pg = powerColor and powerColor[2] or fg
  local pb = powerColor and powerColor[3] or fb
  local pa = powerColor and powerColor[4] or fa

  if frame.__puiTextColorApplyReady ~= true
    or frame.__puiTextColorNR ~= nr
    or frame.__puiTextColorNG ~= ng
    or frame.__puiTextColorNB ~= nb
    or frame.__puiTextColorNA ~= na
    or frame.__puiTextColorHR ~= hr
    or frame.__puiTextColorHG ~= hg
    or frame.__puiTextColorHB ~= hb
    or frame.__puiTextColorHA ~= ha
    or frame.__puiTextColorPR ~= pr
    or frame.__puiTextColorPG ~= pg
    or frame.__puiTextColorPB ~= pb
    or frame.__puiTextColorPA ~= pa
  then
    frame.__puiTextColorApplyReady = true
    frame.__puiTextColorNR = nr
    frame.__puiTextColorNG = ng
    frame.__puiTextColorNB = nb
    frame.__puiTextColorNA = na
    frame.__puiTextColorHR = hr
    frame.__puiTextColorHG = hg
    frame.__puiTextColorHB = hb
    frame.__puiTextColorHA = ha
    frame.__puiTextColorPR = pr
    frame.__puiTextColorPG = pg
    frame.__puiTextColorPB = pb
    frame.__puiTextColorPA = pa

    Text.ApplyTextColors(frame, colors)
  end

  ConfigureUnitDifficulty(frame, unit, cfg, textCfg, hpMode)
end

  Round = P:Def("Text.Round", Round)
  GetAnchorRow = P:Def("Text.GetAnchorRow", GetAnchorRow)
  GetAnchorEdgePoint = P:Def("Text.GetAnchorEdgePoint", GetAnchorEdgePoint)
  ResolveHorizontalJustification = P:Def("Text.ResolveHorizontalJustification", ResolveHorizontalJustification)
  ShouldShortenValues = P:Def("Text.ShouldShortenValues", ShouldShortenValues)
  Text.GetUnitTextConfig = P:Def("Text.GetUnitTextConfig", Text.GetUnitTextConfig)
  PickTextValue = P:Def("PickTextValue", PickTextValue)
  Text.ResolveFontForText = P:Def("Text.ResolveFontForText", Text.ResolveFontForText)
  Text.ApplyUnitTextFont = P:Def("Text.ApplyUnitTextFont", Text.ApplyUnitTextFont)
  Text.ApplyUnitTextLayout = P:Def("Text.ApplyUnitTextLayout", Text.ApplyUnitTextLayout)
  Text.RefreshTextForFrame = P:Def("Text.RefreshTextForFrame", Text.RefreshTextForFrame)
  Text.TagOrClearFrame = P:Def("Text.TagOrClearFrame", Text.TagOrClearFrame)
  Text.Construct = P:Def("Text.Construct", Text.Construct)
  Text.ApplyTextColors = P:Def("Text.ApplyTextColors", Text.ApplyTextColors)
  Text.ApplyFrame = P:Def("Text.ApplyFrame", Text.ApplyFrame)
  ShouldUseGlobalFont = P:Def("Text.ShouldUseGlobalFont", ShouldUseGlobalFont)
  Text.GetConfigTextKey = P:Def("Text.GetConfigTextKey", Text.GetConfigTextKey)
