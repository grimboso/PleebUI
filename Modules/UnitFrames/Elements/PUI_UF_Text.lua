
-- File: PUI_UF_Text.lua
-- Purpose: Shared UnitFrames text sizing, font resolution, and text layout helpers.


local ADDON_NAME, ns = ...


ns.UFText = ns.UFText or {}
local Text = ns.UFText
local Pixel = ns.Pixel

local _G = _G
local CreateFrame = _G.CreateFrame
local math_abs = _G.math.abs
local math_floor = _G.math.floor
local math_max = _G.math.max
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

local function ApplyFontStringFrameWidth(fontString, anchorFrame, offsetX)
  local width = anchorFrame:GetWidth()
  if width <= 0 then
    return
  end

  local inset = math_abs(tonumber(offsetX) or 0)
  Pixel.Width(fontString, math_max(1, width - inset))
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

  local cache = TextConfigKeyCache[text]
  if cache
    and cache.shortenValues == shortenValues
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

  local key = tostring(shortenValues)
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

  local useGlobalFont = fontKey == nil or fontKey == ""
  fontKey = OptionsUtil.ResolveFontKey(fontKey, useGlobalFont)

  fontString:SetFont(
    LSM:Fetch("font", fontKey, true),
    Theme.ResolveFontSize(size, "unitFrames"),
    outline
  )
end

function Text.ApplyUnitTextLayout(frame, unit, cfg, useConfigText)
  local healthBar = frame and frame.Health
  if not frame or not healthBar then
    return
  end

  local powerBar = frame.Power

  if frame.NameText then
    local _, _, _, anchor, dx, dy = Text.ResolveFontForText(unit, "name", nil, cfg, useConfigText)
    frame.__puiNameAnchor = anchor or "LEFT"
    local justifyH = ResolveHorizontalJustification(frame.__puiNameAnchor, "LEFT")

    frame.NameText:ClearAllPoints()
    frame.NameText:SetJustifyH(justifyH)
    Pixel.Point(frame.NameText, frame.__puiNameAnchor, healthBar, frame.__puiNameAnchor, dx or 0, dy or 0)
    ApplyFontStringFrameWidth(frame.NameText, healthBar, dx)

    frame.NameText:SetMaxLines(1)
    frame.NameText:SetWordWrap(false)
  end

  if frame.HealthText then
    local _, _, _, anchor, dx, dy = Text.ResolveFontForText(unit, "health", nil, cfg, useConfigText)
    frame.__puiHealthAnchor = anchor or "RIGHT"
    local justifyH = ResolveHorizontalJustification(frame.__puiHealthAnchor, "RIGHT")

    frame.HealthText:ClearAllPoints()
    frame.HealthText:SetJustifyH(justifyH)
    Pixel.Point(frame.HealthText, frame.__puiHealthAnchor, healthBar, frame.__puiHealthAnchor, dx or 0, dy or 0)
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
  if not unit or not frame.config then
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
    if frame.Untag and fontString.__puiTagString then
      frame:Untag(fontString)
    end

    fontString.__puiTagString = nil
    fontString:SetText("")
    return
  end

  if fontString.__puiTagString == tagString then
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
      Text.ApplyUnitTextLayout(frame, unit, cfg, useConfigText)
    end

    frame.__puiTextConstructedUnit = unit
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
    fontString:SetTextColor(r, g, b, a)
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

  if frame.__puiTextApplyUnit ~= unit
    or frame.__puiTextApplyUseConfigText ~= useConfigText
    or frame.__puiTextApplyFontRev ~= curRev
    or frame.__puiTextApplyHealthMode ~= hpMode
    or frame.__puiTextApplyPowerMode ~= ppMode
    or frame.__puiTextApplyShortenValues ~= shortenValues
    or frame.__puiTextApplyHideNameText ~= hideNameText
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
    frame.__puiTextApplyShowHealth = showHealth
    frame.__puiTextApplyShowPower = showPower
    frame.__puiTextApplyConfigKey = textKey
    frame.__puiTextApplyClassColoredNames = classColoredNames

    if hideNameText then
      Text.TagOrClearFrame(frame, frame.NameText, "")
      frame.NameText:Hide()
    else
      Text.TagOrClearFrame(
        frame,
        frame.NameText,
        classColoredNames and "[raidcolor][pui:name]|r" or "[pui:name]"
      )
      frame.NameText:Show()
    end

    if showHealth then
      Text.TagOrClearFrame(frame, frame.HealthText, healthTags[hpMode] or defaultHealthTag)
      frame.HealthText:Show()
    else
      Text.TagOrClearFrame(frame, frame.HealthText, "")
      frame.HealthText:Hide()
    end

    if showPower then
      Text.TagOrClearFrame(frame, frame.PowerText, powerTags[ppMode] or defaultPowerTag)

      if frame.PowerText then
        frame.PowerText:Show()
      end
    elseif frame.PowerText then
      Text.TagOrClearFrame(frame, frame.PowerText, "")
      frame.PowerText:Hide()
    end
  end

  local healthBar = frame.Health
  local healthWidth = Round(healthBar:GetWidth())
  local healthHeight = Round(healthBar:GetHeight())
  local powerWidth = powerBar and Round(powerBar:GetWidth()) or 0
  local powerHeight = powerBar and Round(powerBar:GetHeight()) or 0

  if frame.__puiTextLayoutUnit ~= unit
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
    frame.__puiTextLayoutUnit = unit
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

    Text.ApplyUnitTextLayout(frame, unit, cfg, useConfigText)
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
end

  Round = P:Def("Text.Round", Round)
  ApplyFontStringFrameWidth = P:Def("Text.ApplyFontStringFrameWidth", ApplyFontStringFrameWidth)
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
