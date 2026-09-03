
-- File: PUI_UF_CastBar_Player_Instant.lua
-- Purpose: Player instant cast pseudo-bar logic.


local ADDON_NAME, ns = ...


local CastBar = ns.Modules.CastBar

local Module = {}
ns.PUICastBarPlayerInstant = Module


local GetTime = GetTime
local C_Spell = C_Spell
local C_DurationUtil = C_DurationUtil
local CreateFrame = CreateFrame

local CB_GCD_DUMMY_SPELL_ID = 61304
local CB_INSTANT_SENT_WINDOW = 1.50

local function CB_OnInstantAnimationFinished(group)
  local bar = group.__puiOwnerBar
  if bar.__puiInstantCast then
    Module:Stop(bar)
  end
end

function Module:OnCreate(bar)
  bar.__puiInstantFallbackDuration = C_DurationUtil.CreateDuration()
  bar.__puiInstantSpellNames = {}
  bar.__puiInstantSpellTextures = {}

  local group = bar.status:CreateAnimationGroup()
  group.__puiOwnerBar = bar
  group:SetScript("OnFinished", CB_OnInstantAnimationFinished)

  local animation = group:CreateAnimation("Alpha")
  animation:SetFromAlpha(1)
  animation:SetToAlpha(1)

  bar.__puiInstantExpirationGroup = group
  bar.__puiInstantExpirationAnimation = animation
end

function Module:MarkSpellSent(castGUID, spellID)
  if self.enabled ~= true or not castGUID or not spellID then
    return
  end

  if C_Spell.IsAutoAttackSpell(spellID)
    or C_Spell.IsRangedAutoAttackSpell(spellID)
    or C_Spell.IsAutoRepeatSpell(spellID)
  then
    return
  end

  self.lastInstantSentCastGUID = castGUID
  self.lastInstantSentUntil = GetTime() + CB_INSTANT_SENT_WINDOW
end

function Module:MarkRealCast(bar)
  CastBar.__puiRealCastToken = (CastBar.__puiRealCastToken or 0) + 1

  self.lastInstantSentCastGUID = nil
  self.lastInstantSentUntil = nil

  if bar.__puiInstantCast then
    self:Stop(bar, true)
  end
end

function Module:Stop(bar, preserveLiveCast)
  local preserve = preserveLiveCast == true
  if bar.__puiInstantExpirationGroup:IsPlaying() then
    bar.__puiInstantExpirationGroup:Stop()
  end

  bar.__puiInstantCast = nil
  bar.instantOverlay:Hide()

  local element = bar.status
  element:SetStatusBarTexture(bar.__puiNormalTexture)

  if preserve then
    return
  end

  bar.timeTextBinding:Disable()

  element:Hide()
end

function Module:StopActive(owner)
  local bar = owner.__puiPlayerCastBar

  self.lastInstantSentCastGUID = nil
  self.lastInstantSentUntil = nil

  local pending = self.pendingFrame
  pending.bar = nil
  pending.spellID = nil
  pending.instantToken = nil
  pending:Hide()

  if bar and bar.__puiInstantCast then
    self:Stop(bar, false)
  end
end

local function CB_PresentInstant(bar, spellID)
  local spellName = bar.__puiInstantSpellNames[spellID]
  local spellTexture = bar.__puiInstantSpellTextures[spellID]

  if not spellName then
    spellName = C_Spell.GetSpellName(spellID)
    if not spellName then
      return
    end

    spellTexture = C_Spell.GetSpellTexture(spellID)
    bar.__puiInstantSpellNames[spellID] = spellName
    bar.__puiInstantSpellTextures[spellID] = spellTexture
  end

  local duration = C_Spell.GetSpellCooldownDuration(CB_GCD_DUMMY_SPELL_ID)
  if not duration or duration:IsZero() then
    local fallbackDuration = bar.__puiInstantFallbackDurationSeconds
    if fallbackDuration <= 0 then
      return
    end

    duration = bar.__puiInstantFallbackDuration
    duration:Reset()
    local now = GetTime()
    duration:SetTimeSpan(now, now + fallbackDuration)
  end

  local element = bar.status
  element:SetStatusBarTexture(bar.__puiInstantTexture)
  element:SetStatusBarColor(
    bar.__puiInstantColorR,
    bar.__puiInstantColorG,
    bar.__puiInstantColorB,
    bar.__puiInstantAlpha
  )

  bar.__puiIsIdle = false
  bar.__puiCastbarEditMoverVisible = nil
  bar.bg:SetAlpha(1)
  bar:SetAlpha(1)
  bar:Show()

  bar.spellName:SetText(spellName)
  bar.spellName:SetShown(bar.__puiInstantShowSpellName)
  bar.icon:SetTexture(spellTexture)
  bar.icon:SetShown(bar.__puiInstantShowIcon)
  bar.instantOverlay:SetShown(bar.__puiInstantUseOverlay)

  bar.timeTextBinding:Disable()
  bar.timeText:SetText("")
  bar.timeText:Hide()
  bar.spark:Hide()
  bar.uninterrupt:Hide()
  bar.uninterruptLeft:Hide()
  bar.uninterruptRight:Hide()

  element:Show()
  element:SetTimerDuration(
    duration,
    Enum.StatusBarInterpolation.Immediate,
    bar.__puiInstantTimerDirection
  )

  bar.__puiInstantCast = true
  bar.__puiInstantExpirationGroup:Stop()
  bar.__puiInstantExpirationGroup:Play()
end

local function CB_ProcessPendingInstant(frame)
  if Module.enabled ~= true then
    frame.bar = nil
    frame.spellID = nil
    frame.instantToken = nil
    frame:Hide()
    return
  end

  local bar = frame.bar
  local spellID = frame.spellID
  local instantToken = frame.instantToken

  frame.bar = nil
  frame.spellID = nil
  frame.instantToken = nil
  frame:Hide()

  if instantToken ~= (CastBar.__puiRealCastToken or 0) then
    return
  end

  if bar.status.__puiActiveUnit == "player" then
    return
  end

  CB_PresentInstant(bar, spellID)
end

function Module:SetEnabled(owner, enabled)
  if enabled == true then
    self.enabled = true
    self.pendingFrame:SetScript("OnUpdate", CB_ProcessPendingInstant)
    return
  end

  self.enabled = nil
  self.pendingFrame:SetScript("OnUpdate", nil)
  self:StopActive(owner)
end

function Module:HandleSucceeded(castGUID, spellID)
  if self.enabled ~= true
    or not castGUID
    or not spellID
    or self.lastInstantSentCastGUID ~= castGUID
  then
    return
  end

  local sentUntil = self.lastInstantSentUntil
  self.lastInstantSentCastGUID = nil
  self.lastInstantSentUntil = nil

  if sentUntil and GetTime() > sentUntil then
    return
  end

  local frame = self.pendingFrame
  frame.bar = CastBar.__puiPlayerCastBar
  frame.spellID = spellID
  frame.instantToken = CastBar.__puiRealCastToken or 0
  frame:Show()
end


local P = select(1, ns.Pleebug:DropIn(Module, { name = "UnitFrames.CastBar.Instant" }))

CB_PresentInstant = P:Def("Instant.Present", CB_PresentInstant)
CB_ProcessPendingInstant = P:Def("Instant.Pending", CB_ProcessPendingInstant)

Module.pendingFrame = CreateFrame("Frame")
Module.pendingFrame:Hide()
