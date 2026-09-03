
-- File: PUI_UF_CastBar_Config.lua
-- Purpose: Castbar profile normalization and unit config cache.


local ADDON_NAME, ns = ...


local CastBar = ns.Modules.CastBar

local tonumber = tonumber
local type = type
local pairs = pairs


local function CB_MergeMissing(dst, src)
  if type(dst) ~= "table" or type(src) ~= "table" then
    return dst
  end

  for key, value in pairs(src) do
    if type(value) == "table" then
      if type(dst[key]) ~= "table" then
        dst[key] = {}
      end
      CB_MergeMissing(dst[key], value)
    elseif dst[key] == nil then
      dst[key] = value
    end
  end

  return dst
end

function CastBar:NormalizeConfigProfile()
  local db = self.db.profile
  CB_MergeMissing(db, self.defaults.profile)

  local units = {
    "player",
    "pet",
    "target",
    "focus",
    "boss",
  }

  for i = 1, #units do
    local cfg = db[units[i]]
    cfg.text = cfg.text or {}
    cfg.timeText = cfg.timeText or {}

    if cfg.useCustomColor == nil then
      cfg.useCustomColor = false
    end

    if cfg.text.showName == nil then
      cfg.text.showName = true
    end

    if cfg.timeText.showCast == nil then
      cfg.timeText.showCast = true
    end

    cfg.__puiShowSpellName = cfg.text.showName ~= false
    cfg.__puiShowCastTime = cfg.timeText.showCast ~= false
    cfg.__puiShowTotal = cfg.showTotal ~= false
    cfg.__puiShowDelayText = cfg.showDelayText ~= false
  end

  self.__puiUnitConfigCache = nil
end

function CastBar:GetUnitConfig(unit)
  local cache = self.__puiUnitConfigCache
  if cache and cache[unit] ~= nil then
    local cached = cache[unit]
    if cached ~= false then
      return cached
    end
    return nil
  end

  local db = self.db.profile
  local cfg = nil

  if unit == "player" then
    cfg = db.player
  elseif unit == "pet" then
    cfg = db.pet
  elseif unit == "target" then
    cfg = db.target
  elseif unit == "focus" then
    cfg = db.focus
  elseif type(unit) == "string" and unit:match("^boss%d") then
    cfg = db.boss
  end

  self.__puiUnitConfigCache = cache or {}
  self.__puiUnitConfigCache[unit] = cfg or false

  return cfg
end


local P = select(1, ns.Pleebug:DropIn(CastBar, { name = "UnitFrames.CastBar.Construct" }))


  CB_MergeMissing = P:Def("CB_MergeMissing", CB_MergeMissing)
  CastBar.NormalizeConfigProfile = P:Def("CastBar.NormalizeConfigProfile", CastBar.NormalizeConfigProfile)
  CastBar.GetUnitConfig = P:Def("CastBar.GetUnitConfig", CastBar.GetUnitConfig)

