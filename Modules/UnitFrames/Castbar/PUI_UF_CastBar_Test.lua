
-- File: PUI_UF_CastBar_Test.lua
-- Purpose: Castbar test mode only.


local ADDON_NAME, ns = ...


local CastBar = ns.Modules.CastBar
local UF = ns.Modules.UnitFrames


local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local UIParent = _G.UIParent
local tonumber = _G.tonumber

local TEST_CLASS_TOKENS = {
  "WARRIOR",
  "PALADIN",
  "HUNTER",
  "ROGUE",
  "PRIEST",
  "DEATHKNIGHT",
  "SHAMAN",
  "MAGE",
  "WARLOCK",
}

local TEST_CLASS_COLORS = {}
for index = 1, #TEST_CLASS_TOKENS do
  local color = RAID_CLASS_COLORS[TEST_CLASS_TOKENS[index]]
  TEST_CLASS_COLORS[index] = { color.r, color.g, color.b, 1 }
end

local TEST_CAST_ICONS = {
  "Interface\\Icons\\Spell_Fire_Fireball02",
  "Interface\\Icons\\Spell_Holy_HolyBolt",
  "Interface\\Icons\\Spell_Nature_Lightning",
  "Interface\\Icons\\Spell_Shadow_ShadowBolt",
}

local TEST_TARGET_NAMES = {
  player = "Training Target",
  pet = "Training Target",
  target = "Player",
  focus = "Player",
  boss1 = "Raid",
  boss2 = "Tank",
  boss3 = "Healer",
  boss4 = "Raid",
  boss5 = "Tank",
}

local TEST_DEFAULT_COLORS = {
  player = { 1.0, 0.7, 0.0, 1.0 },
  pet = { 0.7, 0.9, 1.0, 1.0 },
  target = { 0.2, 0.8, 1.0, 1.0 },
  focus = { 0.6, 1.0, 0.4, 1.0 },
  boss1 = { 1.0, 0.6, 0.2, 1.0 },
  boss2 = { 1.0, 0.6, 0.2, 1.0 },
  boss3 = { 1.0, 0.6, 0.2, 1.0 },
  boss4 = { 1.0, 0.6, 0.2, 1.0 },
  boss5 = { 1.0, 0.6, 0.2, 1.0 },
}

local function CB_Test_ResolveColor(unit, cfg, sampleIndex)
  if cfg.useClassColor == true then
    return TEST_CLASS_COLORS[((sampleIndex - 1) % #TEST_CLASS_COLORS) + 1]
  elseif cfg.useCustomColor == true and cfg.customColor then
    return cfg.customColor
  elseif cfg.color then
    return cfg.color
  end

  return TEST_DEFAULT_COLORS[unit] or TEST_DEFAULT_COLORS.target
end

local TEST_UNITS = {
  "player",
  "pet",
  "target",
  "focus",
  "boss1",
  "boss2",
  "boss3",
  "boss4",
  "boss5",
}
local TestBars = {}
local TestOwners = {}

local function CB_Test_AcquireUnit(index, unit)
  local owner = TestOwners[index]
  local bar = TestBars[index]

  if not owner then
    owner = CreateFrame("Frame", nil, UIParent)
    owner:EnableMouse(false)
    owner:Hide()
    TestOwners[index] = owner
  end

  if not bar then
    bar = CastBar.CreateCastBarFrame(owner, unit, {
      skipMover = true,
    })
    bar.__puiTestPresentation = true
    TestBars[index] = bar
  end

  return bar, owner
end

local function CB_Test_StopUnit(bar)
  if not bar then
    return
  end

  bar.__puiTestState = nil

  local element = bar.status
  if element then
    element.__puiTestCasting = nil
    element.__puiTestChanneling = nil
    element.casting = nil
    element.channeling = nil
  end

  CastBar.SetIdleVisuals(bar, true)

  if bar.empowerPips then
    for i = 1, #bar.empowerPips do
      local p = bar.empowerPips[i]
      if p then
        p:Hide()
      end
    end
  end

  if bar.empowerCharges then
    for i = 1, #bar.empowerCharges do
      local s = bar.empowerCharges[i]
      if s then
        s:Hide()
      end
    end
  end

  if bar.empowerHold then
    bar.empowerHold:Hide()
  end
end

local function CB_Test_BeginPhase(bar, state, isChannel)
  local cfg = bar.__puiState and bar.__puiState.cfg or nil
  if not cfg or cfg.enabled == false then
    CB_Test_StopUnit(bar)
    return false
  end

  local element = bar.status
  local duration = isChannel and state.chanDur or state.castDur

  state.t = 0
  state.phaseStarted = true
  element.__puiOwnerBar = bar
  element.__puiTestCasting = isChannel and nil or true
  element.__puiTestChanneling = isChannel and true or nil
  element.casting = isChannel and nil or true
  element.channeling = isChannel and true or nil

  local spellName = isChannel and "Test Channel" or "Test Cast"
  local iconIndex = ((state.sampleIndex - 1) % #TEST_CAST_ICONS) + 1

  bar.icon:SetTexture(TEST_CAST_ICONS[iconIndex])
  CastBar.SetTestCastVisuals(bar, cfg, spellName)
  element:SetMinMaxValues(0, duration)
  element:SetValue(isChannel and duration or 0)
  CastBar.PostCastStart(element, state.unit)
  CastBar.SetTestTimeText(bar, cfg, duration, duration)
  return true
end

local function CB_Test_StartUnit(bar, unit, mode, sampleIndex)
  if not bar or not bar.status then
    return false
  end

  local cfg = bar.__puiState and bar.__puiState.cfg or nil
  if not cfg or cfg.enabled == false then
    CB_Test_StopUnit(bar)
    return false
  end

  local state = bar.__puiTestState
  if state and state.mode == mode and state.unit == unit then
    state.sampleIndex = sampleIndex or state.sampleIndex or 1
    return true
  end

  state = {
    mode = mode,
    unit = unit,
    sampleIndex = sampleIndex or 1,
    phase = 1,
    phaseStarted = false,
    t = 0,
    castDur = 2.4,
    holdDur = 0.30,
    chanDur = 3.0,
  }
  bar.__puiTestState = state

  CastBar.SetIdleVisuals(bar, false)
  return CB_Test_BeginPhase(bar, state, false)
end

local function CB_Test_UpdateProgress(bar, state, isChannel, duration)
  local cfg = bar.__puiState and bar.__puiState.cfg or nil
  if not cfg or cfg.enabled == false then
    CB_Test_StopUnit(bar)
    return false
  end

  local value = isChannel and (duration - state.t) or state.t
  if value < 0 then
    value = 0
  elseif value > duration then
    value = duration
  end

  bar:Show()
  bar.status:Show()
  bar.status:SetValue(value)

  local remaining = duration - state.t
  if remaining < 0 then
    remaining = 0
  end

  CastBar.SetTestTimeText(bar, cfg, remaining, duration)
  return true
end

local function CB_Test_UpdateUnit(bar, elapsed)
  local state = bar and bar.__puiTestState
  if not state then
    return
  end

  if state.phase == 1 then
    if not state.phaseStarted and not CB_Test_BeginPhase(bar, state, false) then
      return
    end

    state.t = state.t + elapsed

    if not CB_Test_UpdateProgress(bar, state, false, state.castDur) then
      return
    end

    if state.t >= state.castDur then
      CastBar.PostCastStop(bar.status, state.unit)
      state.phase = 2
      state.phaseStarted = false
      state.t = 0
    end
  elseif state.phase == 2 then
    state.t = state.t + elapsed

    if state.t >= state.holdDur then
      state.phase = 3
      state.phaseStarted = false
      state.t = 0
    end
  else
    if not state.phaseStarted and not CB_Test_BeginPhase(bar, state, true) then
      return
    end

    state.t = state.t + elapsed

    if not CB_Test_UpdateProgress(bar, state, true, state.chanDur) then
      return
    end

    if state.t >= state.chanDur then
      CastBar.PostCastStop(bar.status, state.unit)
      state.phase = 1
      state.phaseStarted = false
      state.t = 0
    end
  end
end

local testDriver = CreateFrame("Frame")
testDriver:Hide()
testDriver:SetScript("OnUpdate", function(_, elapsed)
  if InCombatLockdown() then
    testDriver:Hide()
    return
  end

  elapsed = tonumber(elapsed) or 0

  for index = 1, #TEST_UNITS do
    CB_Test_UpdateUnit(TestBars[index], elapsed)
  end
end)

function CastBar:IsTestMode()
  return self.__puiTestMode == "castchannel"
end

function CastBar:SuspendTestMode()
  testDriver:Hide()
  self.__puiTestMode = nil

  for index = 1, #TEST_UNITS do
    local bar = TestBars[index]
    if bar then
      bar:Hide()
    end
  end
end

function CastBar:SetTestMode(enabled, visibleUnits)
  enabled = enabled == true

  if enabled and InCombatLockdown() then
    return false
  end

  self.__puiTestMode = enabled and "castchannel" or nil

  if enabled then
    local activeBars = 0

    for index = 1, #TEST_UNITS do
      local unit = TEST_UNITS[index]
      local cfg = self:GetUnitConfig(unit)
      local bar, owner = CB_Test_AcquireUnit(index, unit)
      local unitShown = visibleUnits == nil or visibleUnits[unit] == true

      bar.__puiTestTargetName = TEST_TARGET_NAMES[unit]
      bar.__puiTestColor = cfg and CB_Test_ResolveColor(unit, cfg, index) or nil

      if unitShown
        and self.db.profile.enabled ~= false
        and cfg
        and cfg.enabled ~= false
        and UF:LayoutTestFrame(owner, unit) ~= false
      then
        self:UpdateUnitLayout(unit, cfg, bar, true)

        if CB_Test_StartUnit(bar, unit, "castchannel", index) then
          activeBars = activeBars + 1
        end
      else
        CB_Test_StopUnit(bar)
        bar:Hide()
      end
    end

    testDriver:SetShown(activeBars > 0)
    return true
  end

  testDriver:Hide()

  if InCombatLockdown() then
    return false
  end

  for index = 1, #TEST_UNITS do
    local bar = TestBars[index]
    CB_Test_StopUnit(bar)
  end

  return true
end

local P = select(1, ns.Pleebug:DropIn(CastBar, { name = "UnitFrames.CastBar.Test" }))


  CB_Test_ResolveColor = P:Def("CB_Test_ResolveColor", CB_Test_ResolveColor)
  CB_Test_AcquireUnit = P:Def("CB_Test_AcquireUnit", CB_Test_AcquireUnit)
  CB_Test_StopUnit = P:Def("CB_Test_StopUnit", CB_Test_StopUnit)
  CB_Test_BeginPhase = P:Def("CB_Test_BeginPhase", CB_Test_BeginPhase)
  CB_Test_StartUnit = P:Def("CB_Test_StartUnit", CB_Test_StartUnit)
  CB_Test_UpdateProgress = P:Def("CB_Test_UpdateProgress", CB_Test_UpdateProgress)
  CB_Test_UpdateUnit = P:Def("CB_Test_UpdateUnit", CB_Test_UpdateUnit)
  CastBar.IsTestMode = P:Def("CastBar.IsTestMode", CastBar.IsTestMode)
  CastBar.SuspendTestMode = P:Def("CastBar.SuspendTestMode", CastBar.SuspendTestMode)
  CastBar.SetTestMode = P:Def("CastBar.SetTestMode", CastBar.SetTestMode)

