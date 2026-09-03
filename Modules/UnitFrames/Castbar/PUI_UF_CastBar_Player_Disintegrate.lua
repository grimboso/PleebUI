
-- File: PUI_UF_CastBar_Player_Disintegrate.lua
-- Purpose: Player Disintegrate and Mass Disintegrate castbar logic.


local ADDON_NAME, ns = ...


local CastBar = ns.Modules.CastBar

local Module = {}
ns.PUICastBarPlayerDisintegrate = Module


local GetTime = GetTime
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local UnitChannelInfo = UnitChannelInfo
local C_SpellBook = C_SpellBook
local issecretvalue = issecretvalue

local tonumber = tonumber
local math_max = math.max
local math_fmod = math.fmod
local Round = ns.Pixel.Round

local CB_DEVASTATION_SPEC_ID = 1467
local CB_DISINTEGRATE_SPELL_ID = 356995
local CB_DISINTEGRATE_BASE_TICKS = 4
local CB_DISINTEGRATE_AZURE_CELERITY_SPELL_ID = 1219723
local CB_DISINTEGRATE_NATURAL_CONVERGENCE_SPELL_ID = 369913
local CB_MASS_DISINTEGRATE_SPELL_ID = 436335
local CB_FIRE_BREATH_SPELL_ID = 357208
local CB_FIRE_BREATH_FONT_OF_MAGIC_SPELL_ID = 382266
local CB_ETERNITY_SURGE_SPELL_ID = 359073
local CB_ETERNITY_SURGE_FONT_OF_MAGIC_SPELL_ID = 382411

Module.DISINTEGRATE_SPELL_ID = CB_DISINTEGRATE_SPELL_ID

function Module:IsMassDisintegrateEmpowerSpell(spellID)
  return spellID == CB_FIRE_BREATH_SPELL_ID
    or spellID == CB_FIRE_BREATH_FONT_OF_MAGIC_SPELL_ID
    or spellID == CB_ETERNITY_SURGE_SPELL_ID
    or spellID == CB_ETERNITY_SURGE_FONT_OF_MAGIC_SPELL_ID
end

function Module:PlayerHasSpell(spellID)
  return C_SpellBook.IsSpellKnownOrInSpellBook(spellID) == true
end

function Module:PlayerKnowsMassDisintegrate()
  return self:PlayerHasSpell(CB_MASS_DISINTEGRATE_SPELL_ID)
end

function Module:RefreshEnabled(owner)
  local specializationIndex = GetSpecialization()
  local specializationID = specializationIndex and GetSpecializationInfo(specializationIndex) or nil
  local enabled = specializationID == CB_DEVASTATION_SPEC_ID
    and (self:PlayerHasSpell(CB_DISINTEGRATE_SPELL_ID) or self:PlayerKnowsMassDisintegrate())
  owner.__puiUseDisintegrateLogic = enabled or nil

  if not enabled then
    self:ResetDeadState(owner)
  end

  return enabled
end

function Module:AddMassDisintegrateStack()
  CastBar.__puiMassDisintegrateStacks = tonumber(CastBar.__puiMassDisintegrateStacks or 0) or 0
  CastBar.__puiMassDisintegrateStacks = CastBar.__puiMassDisintegrateStacks + 1
  CastBar.__puiMassDisintegrateLastGained = GetTime()
end

function Module:ResetOwnerState(owner)
  owner.__puiMassDisintegrateStacks = tonumber(owner.__puiMassDisintegrateStacks or 0) or 0
  owner.__puiMassDisintegrateLastGained = tonumber(owner.__puiMassDisintegrateLastGained or 0) or 0
  owner.__puiHasTipTheScalesActive = owner.__puiHasTipTheScalesActive == true
end

function Module:ResetDeadState(owner)
  owner.__puiMassDisintegrateStacks = 0
  owner.__puiMassDisintegrateLastGained = 0
  owner.__puiHasTipTheScalesActive = false
end

function Module:ResetClipWarning(bar)
  bar.clipWarningText:Hide()
end

function Module:IsPlayerCastElement(element)
  return element.__owner.__unit == "player"
end

function Module:UpdateClipWarning(bar, element, spellID)
  local cfg = bar.__puiState.cfg

  if CastBar.__puiUseDisintegrateLogic ~= true or cfg.showDisintegrateClipWarning ~= true or not self:IsPlayerCastElement(element) then
    bar.clipWarningText:Hide()
    return
  end

  if not spellID or issecretvalue(spellID) or spellID ~= CB_DISINTEGRATE_SPELL_ID then
    return nil
  end

  local stacks = tonumber(CastBar.__puiMassDisintegrateStacks or 0) or 0
  local gainedAt = tonumber(CastBar.__puiMassDisintegrateLastGained or 0) or 0
  local expired = gainedAt <= 0 or ((GetTime() - gainedAt) > 15)

  if expired then
    CastBar.__puiMassDisintegrateStacks = 0
    bar.clipWarningText:Hide()
    return
  end

  if stacks > 0 then
    CastBar.__puiMassDisintegrateStacks = stacks - 1
    bar.clipWarningText:SetText(cfg.disintegrateClipWarningText)
    bar.clipWarningText:Show()
    return
  end

  bar.clipWarningText:Hide()
end

function Module:GetDisintegrateBaseTickCount()
  local ticks = CB_DISINTEGRATE_BASE_TICKS

  if self:PlayerHasSpell(CB_DISINTEGRATE_AZURE_CELERITY_SPELL_ID) then
    ticks = ticks + 1
  end

  return ticks
end

function Module:GetDisintegrateHastedTickInterval(duration)
  duration = tonumber(duration)
  if not duration or duration <= 0 then
    return nil
  end

  local baseDuration = 3.0
  local baseInterval = 1

  if self:PlayerHasSpell(CB_DISINTEGRATE_AZURE_CELERITY_SPELL_ID) then
    baseInterval = baseInterval * 0.75
  end

  if self:PlayerHasSpell(CB_DISINTEGRATE_NATURAL_CONVERGENCE_SPELL_ID) then
    baseDuration = baseDuration * 0.8
    baseInterval = baseInterval * 0.8
  end

  local haste = baseDuration / duration
  if haste <= 0 then
    return nil
  end

  return baseInterval / haste
end

function Module:GetTickData(element, spellID)
  if CastBar.__puiUseDisintegrateLogic ~= true or not self:IsPlayerCastElement(element) then
    return nil
  end

  if not spellID or issecretvalue(spellID) or spellID ~= CB_DISINTEGRATE_SPELL_ID then
    return nil
  end

  local _, _, _, startTimeMS, endTimeMS = UnitChannelInfo("player")
  if not startTimeMS or not endTimeMS then
    return nil
  end

  local startTime = startTimeMS / 1000
  local endTime = endTimeMS / 1000
  local duration = endTime - startTime
  if duration <= 0 then
    return nil
  end

  local cached = element.__puiDisintegrateTickData
  if cached and cached.startTime == startTime and cached.endTime == endTime then
    return cached
  end

  local hastedTickInterval = self:GetDisintegrateHastedTickInterval(duration)
  if not hastedTickInterval or hastedTickInterval <= 0 then
    return nil
  end

  if element.__puiDisintegrateStartTime ~= startTime then
    local firstTick = 0
    local chaining = false

    local prevEndTime = tonumber(element.__puiDisintegratePrevEndTime)
    local prevTickInterval = tonumber(element.__puiDisintegratePrevHastedTickInterval)
    if prevEndTime and prevTickInterval and prevTickInterval > 0 and startTime < prevEndTime then
      local remaining = prevEndTime - startTime
      firstTick = math_max(0, math_fmod(remaining, prevTickInterval))
      chaining = true
    end

    element.__puiDisintegrateFirstTick = firstTick
    element.__puiDisintegrateChaining = chaining
    element.__puiDisintegrateStartTime = startTime
  end

  element.__puiDisintegratePrevEndTime = endTime
  element.__puiDisintegratePrevHastedTickInterval = hastedTickInterval
  element.__puiDisintegrateChanneling = true

  local data = element.__puiDisintegrateTickData or {}
  element.__puiDisintegrateTickData = data
  data.startTime = startTime
  data.endTime = endTime
  data.duration = duration
  data.firstTick = tonumber(element.__puiDisintegrateFirstTick) or 0
  data.hastedTickInterval = hastedTickInterval
  data.maxTicks = self:GetDisintegrateBaseTickCount()
  data.chaining = element.__puiDisintegrateChaining == true

  return data
end

function Module:OnCreate(frame, holder, element, unit)
  holder.clipWarningText = holder:CreateFontString(nil, "OVERLAY")
  holder.clipWarningText:SetPoint(
    "BOTTOM",
    element,
    "TOP",
    0,
    Round(14)
  )
  holder.clipWarningText:SetJustifyH("CENTER")

  CastBar.SetFont(holder.clipWarningText, nil, 18, "OUTLINE")

  holder.clipWarningText:Hide()
  frame.clipWarningText = holder.clipWarningText
end

function Module:OnLayout(bar, unit, cfg, statusHost)
  CastBar.SetFont(bar.clipWarningText, nil, 18, "OUTLINE")

  bar.clipWarningText:ClearAllPoints()
  bar.clipWarningText:SetPoint("BOTTOM", statusHost, "TOP", 0, Round(14))
  bar.clipWarningText:SetText(cfg.disintegrateClipWarningText)

  if cfg.showDisintegrateClipWarning ~= true then
    bar.clipWarningText:Hide()
  end
end

function Module:HandleSucceeded(owner, spellID)
  if owner.__puiUseDisintegrateLogic == true and owner.__puiHasTipTheScalesActive and self:IsMassDisintegrateEmpowerSpell(spellID) and self:PlayerKnowsMassDisintegrate() then
    owner.__puiHasTipTheScalesActive = false
    self:AddMassDisintegrateStack()
  end
end

function Module:HandleEmpowerStop(owner, spellID, complete)
  if owner.__puiUseDisintegrateLogic == true and complete and self:IsMassDisintegrateEmpowerSpell(spellID) and self:PlayerKnowsMassDisintegrate() then
    self:AddMassDisintegrateStack()
  end
end

function Module:HandleGlowShow(owner, spellID)
  if owner.__puiUseDisintegrateLogic == true and self:IsMassDisintegrateEmpowerSpell(spellID) then
    owner.__puiHasTipTheScalesActive = true
  end
end

function Module:HandleGlowHide(owner, spellID)
  if owner.__puiUseDisintegrateLogic == true and self:IsMassDisintegrateEmpowerSpell(spellID) then
    owner.__puiHasTipTheScalesActive = false
  end
end


local P = select(1, ns.Pleebug:DropIn(Module, { name = "UnitFrames.CastBar.Disintegrate" }))


  Module.IsMassDisintegrateEmpowerSpell = P:Def("Disintegrate.IsMassDisintegrateEmpowerSpell", Module.IsMassDisintegrateEmpowerSpell)
  Module.PlayerHasSpell = P:Def("Disintegrate.PlayerHasSpell", Module.PlayerHasSpell)
  Module.PlayerKnowsMassDisintegrate = P:Def("Disintegrate.PlayerKnowsMassDisintegrate", Module.PlayerKnowsMassDisintegrate)
  Module.RefreshEnabled = P:Def("Disintegrate.RefreshEnabled", Module.RefreshEnabled)
  Module.AddMassDisintegrateStack = P:Def("Disintegrate.AddMassDisintegrateStack", Module.AddMassDisintegrateStack)
  Module.ResetOwnerState = P:Def("Disintegrate.ResetOwnerState", Module.ResetOwnerState)
  Module.ResetDeadState = P:Def("Disintegrate.ResetDeadState", Module.ResetDeadState)
  Module.ResetClipWarning = P:Def("Disintegrate.ResetClipWarning", Module.ResetClipWarning)
  Module.IsPlayerCastElement = P:Def("Disintegrate.IsPlayerCastElement", Module.IsPlayerCastElement)
  Module.UpdateClipWarning = P:Def("Disintegrate.UpdateClipWarning", Module.UpdateClipWarning)
  Module.GetDisintegrateBaseTickCount = P:Def("Disintegrate.GetDisintegrateBaseTickCount", Module.GetDisintegrateBaseTickCount)
  Module.GetDisintegrateHastedTickInterval = P:Def("Disintegrate.GetDisintegrateHastedTickInterval", Module.GetDisintegrateHastedTickInterval)
  Module.GetTickData = P:Def("Disintegrate.GetTickData", Module.GetTickData)
  Module.OnCreate = P:Def("Disintegrate.OnCreate", Module.OnCreate)
  Module.OnLayout = P:Def("Disintegrate.OnLayout", Module.OnLayout)
  Module.HandleSucceeded = P:Def("Disintegrate.HandleSucceeded", Module.HandleSucceeded)
  Module.HandleEmpowerStop = P:Def("Disintegrate.HandleEmpowerStop", Module.HandleEmpowerStop)
  Module.HandleGlowShow = P:Def("Disintegrate.HandleGlowShow", Module.HandleGlowShow)
  Module.HandleGlowHide = P:Def("Disintegrate.HandleGlowHide", Module.HandleGlowHide)

