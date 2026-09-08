-- Individual-frame integration adapted from Unhalted Unit Frames, with permission.
--[[
  Range spell data derived from LibRangeCheck-3.0.

  Copyright (c) 2023 The WoWUIDev Community
  Licensed under the MIT License

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.
]]

local ADDON_NAME, ns = ...

ns.Range = ns.Range or {}
local Range = ns.Range

local _G = _G
local C_Spell = _G.C_Spell
local C_SpellBook = _G.C_SpellBook
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local UnitCanAssist = _G.UnitCanAssist
local UnitCanAttack = _G.UnitCanAttack
local UnitClass = _G.UnitClass
local UnitExists = _G.UnitExists
local UnitIsConnected = _G.UnitIsConnected
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local issecretvalue = _G.issecretvalue
local next = _G.next
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local tonumber = _G.tonumber
local type = _G.type
local wipe = _G.wipe

local DEFAULT_OUT_OF_RANGE_ALPHA = 0.45
local DEFAULT_UPDATE_INTERVAL = 0.25

local P = select(1, ns.Pleebug:DropIn(Range, { name = "UnitFrames.Range" }))

local _, playerClass = UnitClass("player")

local RANGE_SPELLS = {
  enemy = {
    DEATHKNIGHT = { 47541, 49576 },
    DEMONHUNTER = { 185123, 204021, 183752 },
    DRUID = { 8921, 5176, 339, 6795, 33786, 22568 },
    EVOKER = { 362969 },
    HUNTER = { 75, 466930 },
    MAGE = { 116, 133, 44425, 44614, 118, 5019 },
    MONK = { 117952, 115546, 115078, 100780 },
    PALADIN = { 20473, 20271, 62124, 183218, 853, 35395 },
    PRIEST = { 585, 8092, 589, 5019 },
    ROGUE = { 185565, 36554, 185763, 2094, 921 },
    SHAMAN = { 188196, 8042, 117014, 370, 73899 },
    WARLOCK = { 686, 232670, 234153, 198590, 5782, 5019 },
    WARRIOR = { 355, 100, 5246 },
  },
  friendly = {
    DEATHKNIGHT = { 47541 },
    DEMONHUNTER = {},
    DRUID = { 8936, 774, 88423, 2782 },
    EVOKER = { 360823, 361469, 355913 },
    HUNTER = {},
    MAGE = { 1459, 475 },
    MONK = { 116670, 115450 },
    PALADIN = { 19750, 85673, 4987, 213644 },
    PRIEST = { 2061, 17, 21562, 527 },
    ROGUE = { 57934, 36554, 921 },
    SHAMAN = { 8004, 188070, 546 },
    WARLOCK = { 20707, 5697 },
    WARRIOR = { 3411 },
  },
  resurrect = {
    DEATHKNIGHT = { 61999 },
    DEMONHUNTER = {},
    DRUID = { 50769, 20484 },
    EVOKER = { 361227 },
    HUNTER = {},
    MAGE = {},
    MONK = { 115178 },
    PALADIN = { 7328, 391054 },
    PRIEST = { 2006, 212036 },
    ROGUE = {},
    SHAMAN = { 2008 },
    WARLOCK = { 20707 },
    WARRIOR = {},
  },
}

local activeRangeSpells = {
  enemy = {},
  friendly = {},
  resurrect = {},
}

local individualRangeFrames = setmetatable({}, { __mode = "k" })
local individualRangeTicker
local individualRangeTickerInterval
local individualRangeDriver = CreateFrame("Frame")

local function BuildActiveRangeSpellList(active, spells)
  wipe(active)

  for index = 1, #spells do
    local spellID = spells[index]
    if C_SpellBook.IsSpellInSpellBook(spellID, nil, true) then
      active[#active + 1] = spellID
    end
  end
end

local function RefreshActiveRangeSpells()
  BuildActiveRangeSpellList(activeRangeSpells.enemy, RANGE_SPELLS.enemy[playerClass])
  BuildActiveRangeSpellList(activeRangeSpells.friendly, RANGE_SPELLS.friendly[playerClass])
  BuildActiveRangeSpellList(activeRangeSpells.resurrect, RANGE_SPELLS.resurrect[playerClass])
end

local function ClampAlpha(value)
  value = tonumber(value) or DEFAULT_OUT_OF_RANGE_ALPHA

  if value < 0 then
    return 0
  elseif value > 1 then
    return 1
  end

  return value
end

local function GetSpellRange(unit, spells)
  local outOfRange = false

  for index = 1, #spells do
    local inRange = C_Spell.IsSpellInRange(spells[index], unit)

    if issecretvalue(inRange) then
      return inRange
    elseif inRange == true then
      return true
    elseif inRange == false then
      outOfRange = true
    end
  end

  if outOfRange then
    return false
  end
end

local function UpdateIndividualRangeFrame(frame)
  local cfg = frame.__puiRangeConfig
  local unit = frame.__unit

  if not cfg or cfg.enabled == false or not unit or not UnitExists(unit) or not UnitIsConnected(unit) then
    frame:SetAlpha(1)
    return
  end

  local spells

  if UnitIsDeadOrGhost(unit) then
    spells = activeRangeSpells.resurrect
  elseif UnitCanAttack("player", unit) then
    spells = activeRangeSpells.enemy
  elseif UnitCanAssist("player", unit) then
    spells = activeRangeSpells.friendly
  end

  if not spells or #spells == 0 then
    frame:SetAlpha(1)
    return
  end

  local inRange = GetSpellRange(unit, spells)

  if issecretvalue(inRange) then
    frame:SetAlphaFromBoolean(inRange, 1, cfg.outOfRangeAlpha)
  elseif inRange == nil then
    frame:SetAlpha(1)
  else
    frame:SetAlphaFromBoolean(inRange, 1, cfg.outOfRangeAlpha)
  end
end

local function UpdateIndividualRangeFrames()
  for frame in pairs(individualRangeFrames) do
    UpdateIndividualRangeFrame(frame)
  end
end

local function StopIndividualRangeTicker()
  if individualRangeTicker then
    individualRangeTicker:Cancel()
    individualRangeTicker = nil
    individualRangeTickerInterval = nil
  end
end

local function GetIndividualRangeTickerInterval()
  local interval

  for frame in pairs(individualRangeFrames) do
    local cfg = frame.__puiRangeConfig
    local candidate = cfg and tonumber(cfg.updateInterval) or DEFAULT_UPDATE_INTERVAL
    if candidate < 0.25 then
      candidate = 0.25
    end

    if not interval or candidate < interval then
      interval = candidate
    end
  end

  return interval
end

local function RefreshIndividualRangeTicker()
  if not next(individualRangeFrames) then
    StopIndividualRangeTicker()
    return
  end

  local updateInterval = GetIndividualRangeTickerInterval() or DEFAULT_UPDATE_INTERVAL
  if individualRangeTicker and individualRangeTickerInterval == updateInterval then
    return
  end

  StopIndividualRangeTicker()
  individualRangeTickerInterval = updateInterval
  individualRangeTicker = C_Timer.NewTicker(updateInterval, UpdateIndividualRangeFrames)
end

local function UpdateIndividualRangeDriverRegistration()
  local hasFrames = false
  local hasTarget = false
  local hasFocus = false
  local hasBoss = false

  for frame in pairs(individualRangeFrames) do
    hasFrames = true

    local unit = frame.__unit
    if unit == "target" then
      hasTarget = true
    elseif unit == "focus" then
      hasFocus = true
    elseif unit and unit:find("boss", 1, true) == 1 then
      hasBoss = true
    end
  end

  individualRangeDriver:UnregisterAllEvents()

  if not hasFrames then
    return
  end

  if hasTarget then
    individualRangeDriver:RegisterEvent("PLAYER_TARGET_CHANGED")
  end
  if hasFocus then
    individualRangeDriver:RegisterEvent("PLAYER_FOCUS_CHANGED")
  end
  if hasBoss then
    individualRangeDriver:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
  end

  individualRangeDriver:RegisterEvent("SPELLS_CHANGED")
  individualRangeDriver:RegisterEvent("UNIT_CONNECTION")
  individualRangeDriver:RegisterEvent("UNIT_PHASE")
  individualRangeDriver:RegisterEvent("UNIT_TARGETABLE_CHANGED")
end

local function RegisterIndividualRangeFrame(frame)
  local firstFrame = not next(individualRangeFrames)

  individualRangeFrames[frame] = true

  if firstFrame then
    RefreshActiveRangeSpells()
  end

  UpdateIndividualRangeDriverRegistration()
  RefreshIndividualRangeTicker()
  UpdateIndividualRangeFrame(frame)
end

local function UnregisterIndividualRangeFrame(frame)
  individualRangeFrames[frame] = nil
  UpdateIndividualRangeDriverRegistration()
  RefreshIndividualRangeTicker()
end

local function IsIndividualFrameAffected(frame, event, eventUnit)
  local unit = frame.__unit

  if event == "PLAYER_TARGET_CHANGED" then
    return unit == "target"
  elseif event == "PLAYER_FOCUS_CHANGED" then
    return unit == "focus"
  elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
    return unit and unit:find("boss", 1, true) == 1
  end

  return unit == eventUnit
end

individualRangeDriver:SetScript("OnEvent", function(_, event, unit)
  if event == "SPELLS_CHANGED" then
    RefreshActiveRangeSpells()
    UpdateIndividualRangeFrames()
    return
  end

  for frame in pairs(individualRangeFrames) do
    if frame:IsVisible() and IsIndividualFrameAffected(frame, event, unit) then
      UpdateIndividualRangeFrame(frame)
    end
  end
end)

function Range.GetNormalizedRangeConfig(db)
  if type(db) ~= "table" then
    return {
      enabled = true,
      outOfRangeAlpha = DEFAULT_OUT_OF_RANGE_ALPHA,
      updateInterval = DEFAULT_UPDATE_INTERVAL,
    }
  end

  return {
    enabled = db.enabled ~= false,
    outOfRangeAlpha = ClampAlpha(db.outOfRangeAlpha),
    updateInterval = tonumber(db.updateInterval) or DEFAULT_UPDATE_INTERVAL,
  }
end

local function NormalizeConfigObject(config)
  if type(config) == "table" and config.__puiRangeConfigNormalized == true then
    return config
  end

  config = Range.GetNormalizedRangeConfig(config)
  config.__puiRangeConfigNormalized = true
  return config
end

local function ResolveConfig(frame, config)
  return NormalizeConfigObject(config or (frame and frame.__puiRangeConfig))
end

local function EnsureOwnerRegistry(owner)
  if not owner then
    return nil
  end

  owner._rangeFrames = owner._rangeFrames or setmetatable({}, { __mode = "k" })
  return owner._rangeFrames
end

local function DisableRangeElement(frame)
  if frame:IsElementEnabled("Range") then
    frame:DisableElement("Range")
  end

  frame:SetAlpha(1)
end

local function EnableOUFRangeElement(frame)
  if not frame.Range then
    frame.Range = {}
  end

  if not frame:IsElementEnabled("Range") then
    frame:EnableElement("Range")
  end
end

local function RangeFrame_OnShow(frame)
  if frame.__puiUseIndividualRange == true and frame.__puiRangeRegistered == true then
    RegisterIndividualRangeFrame(frame)
  end
end

local function RangeFrame_OnHide(frame)
  if frame.__puiUseIndividualRange == true then
    UnregisterIndividualRangeFrame(frame)
    frame:SetAlpha(1)
  end
end

local function ApplyRangeElementConfig(frame, cfg)
  local previousInterval = frame.__puiRangeConfig and frame.__puiRangeConfig.updateInterval
  frame.__puiRangeConfig = cfg

  if cfg.enabled == false then
    UnregisterIndividualRangeFrame(frame)
    DisableRangeElement(frame)
    frame.Range = nil
    return
  end

  frame.Range = frame.Range or {}
  frame.Range.insideAlpha = 1
  frame.Range.outsideAlpha = cfg.outOfRangeAlpha
  frame.Range.Override = nil

  if frame.__puiUseIndividualRange == true then
    DisableRangeElement(frame)

    if frame:IsVisible() then
      RegisterIndividualRangeFrame(frame)
    end

    if previousInterval ~= cfg.updateInterval then
      RefreshIndividualRangeTicker()
    end
  else
    UnregisterIndividualRangeFrame(frame)
    EnableOUFRangeElement(frame)
  end
end

function Range.Configure(frame, config)
  ApplyRangeElementConfig(frame, ResolveConfig(frame, config))
end

function Range.Detach(frame)
  if not frame then
    return
  end

  local owner = frame.__puiRangeOwner
  if owner and owner._rangeFrames then
    owner._rangeFrames[frame] = nil
  end

  frame.__puiRangeOwner = nil
  frame.__puiRangeRegistered = nil
  frame.__puiRangeConfig = nil

  UnregisterIndividualRangeFrame(frame)
  DisableRangeElement(frame)
  frame.Range = nil
end

function Range.RegisterFrame(owner, frame, configOrProvider)
  if not frame then
    return
  end

  local oldOwner = frame.__puiRangeOwner
  if oldOwner and oldOwner ~= owner and oldOwner._rangeFrames then
    oldOwner._rangeFrames[frame] = nil
  end

  local registry = EnsureOwnerRegistry(owner)
  if registry then
    registry[frame] = true
  end

  frame.__puiRangeOwner = owner
  frame.__puiRangeRegistered = true

  if frame.__puiRangeLifecycleHooked ~= true then
    frame.__puiRangeLifecycleHooked = true
    frame:HookScript("OnShow", RangeFrame_OnShow)
    frame:HookScript("OnHide", RangeFrame_OnHide)
  end

  Range.Configure(frame, configOrProvider)
end

function Range.RefreshRangeOwnerConfig(owner, configOrProvider)
  if not owner or not owner._rangeFrames then
    return
  end

  local cfg = ResolveConfig(nil, configOrProvider)

  for frame in pairs(owner._rangeFrames) do
    Range.Configure(frame, cfg)
  end
end

RefreshActiveRangeSpells = P:Def("RefreshActiveRangeSpells", RefreshActiveRangeSpells)
ClampAlpha = P:Def("ClampAlpha", ClampAlpha)
UpdateIndividualRangeFrames = P:Def("UpdateIndividualRangeFrames", UpdateIndividualRangeFrames)
StopIndividualRangeTicker = P:Def("StopIndividualRangeTicker", StopIndividualRangeTicker)
GetIndividualRangeTickerInterval = P:Def("GetIndividualRangeTickerInterval", GetIndividualRangeTickerInterval)
RefreshIndividualRangeTicker = P:Def("RefreshIndividualRangeTicker", RefreshIndividualRangeTicker)
UpdateIndividualRangeDriverRegistration = P:Def("UpdateIndividualRangeDriverRegistration", UpdateIndividualRangeDriverRegistration)
RegisterIndividualRangeFrame = P:Def("RegisterIndividualRangeFrame", RegisterIndividualRangeFrame)
UnregisterIndividualRangeFrame = P:Def("UnregisterIndividualRangeFrame", UnregisterIndividualRangeFrame)
IsIndividualFrameAffected = P:Def("IsIndividualFrameAffected", IsIndividualFrameAffected)
Range.GetNormalizedRangeConfig = P:Def("Range.GetNormalizedRangeConfig", Range.GetNormalizedRangeConfig)
NormalizeConfigObject = P:Def("NormalizeConfigObject", NormalizeConfigObject)
ResolveConfig = P:Def("ResolveConfig", ResolveConfig)
EnsureOwnerRegistry = P:Def("EnsureOwnerRegistry", EnsureOwnerRegistry)
DisableRangeElement = P:Def("DisableRangeElement", DisableRangeElement)
EnableOUFRangeElement = P:Def("EnableOUFRangeElement", EnableOUFRangeElement)
ApplyRangeElementConfig = P:Def("ApplyRangeElementConfig", ApplyRangeElementConfig)
Range.Configure = P:Def("Range.Configure", Range.Configure)
Range.Detach = P:Def("Range.Detach", Range.Detach)
Range.RegisterFrame = P:Def("Range.RegisterFrame", Range.RegisterFrame)
Range.RefreshRangeOwnerConfig = P:Def("Range.RefreshRangeOwnerConfig", Range.RefreshRangeOwnerConfig)
RangeFrame_OnShow = P:Def("RangeFrame_OnShow", RangeFrame_OnShow)
RangeFrame_OnHide = P:Def("RangeFrame_OnHide", RangeFrame_OnHide)
