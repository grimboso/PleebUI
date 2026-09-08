local _, ns = ...

local OptionsUtil = {
  _cache = {
    statusbars = {},
    fonts = {},
    outlines = {},
  },
}
ns.OptionsUtil = OptionsUtil

local LSM = ns.LSM
local STANDARD_FONT_KEY = ns.FontDropdown.STANDARD_FONT_KEY
local STANDARD_OUTLINE_KEY = ns.Theme.STANDARD_OUTLINE_KEY

local function CacheKey(includeDefault, defaultLabel, defaultKey)
  return table.concat({
    includeDefault == true and "1" or "0",
    tostring(defaultLabel or ""),
    tostring(defaultKey or ""),
  }, "\031")
end


function OptionsUtil.BuildStatusbarValues(includeDefault, defaultLabel, defaultKey)
  local key = CacheKey(includeDefault, defaultLabel, defaultKey)
  local cached = OptionsUtil._cache.statusbars[key]
  if cached then
    return cached
  end

  local list = {}
  if includeDefault then
    list[defaultKey or ""] = defaultLabel or "Use default"
  end

  for name in pairs(LSM:HashTable("statusbar")) do
    list[name] = name
  end

  OptionsUtil._cache.statusbars[key] = list
  return list
end

local function HasLSMFontKey(fontKey)
  return type(fontKey) == "string"
    and fontKey ~= ""
    and fontKey ~= STANDARD_FONT_KEY
    and LSM:HashTable("font")[fontKey] ~= nil
end

function OptionsUtil.BuildFontValues(includeDefault, defaultLabel, defaultKey)
  local key = CacheKey(includeDefault, defaultLabel, defaultKey)
  local cached = OptionsUtil._cache.fonts[key]
  if cached then
    return cached
  end

  local list = {}
  if includeDefault then
    list[defaultKey or STANDARD_FONT_KEY] = defaultLabel or "Use global font"
  end

  for fontKey, value in pairs(ns.Theme.BuildGlobalFontList()) do
    list[fontKey] = value
  end

  OptionsUtil._cache.fonts[key] = list
  return list
end

function OptionsUtil.ResolveFontKey(value, useGlobalFont)
  if useGlobalFont ~= true and HasLSMFontKey(value) then
    return value
  end

  local fontKey = ns.Theme.GetIconTextGlobal()
  return HasLSMFontKey(fontKey) and fontKey or "FiraSans Heavy"
end


function OptionsUtil.FetchFontPath(value, useGlobalFont)
  return LSM:Fetch("font", OptionsUtil.ResolveFontKey(value, useGlobalFont), true)
end

function OptionsUtil.BuildOutlineValues(includeDefault, defaultLabel, defaultKey)
  local key = CacheKey(includeDefault, defaultLabel, defaultKey)
  local cached = OptionsUtil._cache.outlines[key]
  if cached then
    return cached
  end

  local list = {}
  if includeDefault then
    list[defaultKey or STANDARD_OUTLINE_KEY] = defaultLabel or "Use global outline"
  end

  for outlineKey, value in pairs(ns.Theme.GetOutlineList()) do
    list[outlineKey] = value
  end

  OptionsUtil._cache.outlines[key] = list
  return list
end

function OptionsUtil.GetStoredOutlineValue(value, defaultKey)
  return value == nil and (defaultKey or STANDARD_OUTLINE_KEY) or value
end

function OptionsUtil.SetStoredOutlineValue(value, defaultKey)
  if value == nil or value == (defaultKey or STANDARD_OUTLINE_KEY) then
    return nil
  end

  return value == "NONE" and "" or value
end
