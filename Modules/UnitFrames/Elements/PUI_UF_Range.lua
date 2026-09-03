-- Individual-frame integration adapted from Unhalted Unit Frames, with permission.
-- Range estimation is provided by LibRangeCheck-3.0 under its MIT license.

local ADDON_NAME, ns = ...

ns.Range = ns.Range or {}
local Range = ns.Range

local _G = _G
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local UnitCanAssist = _G.UnitCanAssist
local UnitCanAttack = _G.UnitCanAttack
local UnitExists = _G.UnitExists
local UnitIsConnected = _G.UnitIsConnected
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local next = _G.next
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local tonumber = _G.tonumber
local type = _G.type

local LibRangeCheck = LibStub("LibRangeCheck-3.0")

local DEFAULT_OUT_OF_RANGE_ALPHA = 0.45
local DEFAULT_UPDATE_INTERVAL = 0.25

local P = select(1, ns.Pleebug:DropIn(Range, { name = "UnitFrames.Range" }))

local individualRangeFrames = setmetatable({}, { __mode = "k" })
local individualRangeTicker
local individualRangeTickerInterval
local individualRangeDriver = CreateFrame("Frame")
local maximumHarmRangeChecker
local maximumFriendRangeChecker
local maximumFriendCombatRangeChecker

local function GetMaximumRangeChecker(iterator)
  local checker

  for _, candidate in iterator do
    checker = candidate
  end

  return checker
end

local function RefreshMaximumRangeCheckers()
  maximumHarmRangeChecker = GetMaximumRangeChecker(LibRangeCheck:GetHarmCheckersNoItems(false))
  maximumFriendRangeChecker = GetMaximumRangeChecker(LibRangeCheck:GetFriendCheckersNoItems(false))
  maximumFriendCombatRangeChecker = GetMaximumRangeChecker(LibRangeCheck:GetFriendCheckersNoItems(true))
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

local function SetFrameAlpha(frame, alpha)
  if frame:GetAlpha() ~= alpha then
    frame:SetAlpha(alpha)
  end
end

local function UpdateIndividualRangeFrame(frame)
  local cfg = frame.__puiRangeConfig
  local unit = frame.__unit

  if not cfg or cfg.enabled == false or not unit or not UnitExists(unit) or not UnitIsConnected(unit) then
    SetFrameAlpha(frame, 1)
    return
  end

  if not UnitIsDeadOrGhost(unit) then
    local checker

    if UnitCanAttack("player", unit) then
      checker = maximumHarmRangeChecker
    elseif UnitCanAssist("player", unit) then
      checker = InCombatLockdown() and maximumFriendCombatRangeChecker or maximumFriendRangeChecker
    end

    if checker then
      if checker(unit) == true then
        SetFrameAlpha(frame, 1)
      else
        SetFrameAlpha(frame, cfg.outOfRangeAlpha)
      end
      return
    end
  end

  local minRange, maxRange = LibRangeCheck:GetRange(unit, false, true, cfg.updateInterval)
  if minRange ~= nil and maxRange == nil then
    SetFrameAlpha(frame, cfg.outOfRangeAlpha)
  else
    SetFrameAlpha(frame, 1)
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

  individualRangeDriver:RegisterEvent("UNIT_CONNECTION")
  individualRangeDriver:RegisterEvent("UNIT_TARGETABLE_CHANGED")
end

local function RegisterIndividualRangeFrame(frame)
  individualRangeFrames[frame] = true
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

  SetFrameAlpha(frame, 1)
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
    SetFrameAlpha(frame, 1)
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

GetMaximumRangeChecker = P:Def("GetMaximumRangeChecker", GetMaximumRangeChecker)
RefreshMaximumRangeCheckers = P:Def("RefreshMaximumRangeCheckers", RefreshMaximumRangeCheckers)
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

LibRangeCheck.RegisterCallback(Range, LibRangeCheck.CHECKERS_CHANGED, RefreshMaximumRangeCheckers)
RefreshMaximumRangeCheckers()
