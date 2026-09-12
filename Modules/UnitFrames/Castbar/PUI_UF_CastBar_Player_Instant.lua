
-- File: PUI_UF_CastBar_Player_Instant.lua
-- Purpose: Player instant cast pseudo-bar logic.


local ADDON_NAME, ns = ...


local Module = {}
ns.PUICastBarPlayerInstant = Module


local GetTime = GetTime
local C_Spell = C_Spell
local C_DurationUtil = C_DurationUtil
local CreateFrame = CreateFrame

local CB_INSTANT_CLEANUP_DURATION = 1.50

local function CB_OnInstantCleanupFinished(group)
  local bar = group.__puiOwnerBar
  if bar.__puiInstantCast then
    Module:Stop(bar)
  end
end

function Module:OnCreate(bar)
  bar.__puiInstantDuration = C_DurationUtil.CreateDuration()
  bar.__puiInstantSpellNames = {}
  bar.__puiInstantSpellTextures = {}

  local group = bar.instantStatus:CreateAnimationGroup()
  group.__puiOwnerBar = bar
  group:SetScript("OnFinished", CB_OnInstantCleanupFinished)

  local animation = group:CreateAnimation("Alpha")
  animation:SetFromAlpha(1)
  animation:SetToAlpha(1)
  animation:SetDuration(CB_INSTANT_CLEANUP_DURATION)

  bar.__puiInstantCleanupGroup = group
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

  self.sentCastGUID = castGUID
  self.sentSpellID = spellID
  self.pendingCastGUID = nil
  self.pendingSpellID = nil
end

function Module:MarkRealCast(bar, castGUID, spellID)
  if self.enabled ~= true or not castGUID or not spellID then
    return
  end

  local matchesSent = self.sentCastGUID == castGUID and self.sentSpellID == spellID
  local matchesPending = self.pendingCastGUID == castGUID and self.pendingSpellID == spellID
  if not matchesSent and not matchesPending then
    return
  end

  self.realCastGUID = castGUID
  self.realSpellID = spellID

  if matchesSent then
    self.sentCastGUID = nil
    self.sentSpellID = nil
  end

  if matchesPending then
    self.pendingCastGUID = nil
    self.pendingSpellID = nil
    self.pendingBar = nil
    self.pendingFrame:Hide()
  end

  if bar and bar.__puiInstantCast then
    self:Stop(bar, true)
  end
end

function Module:MarkRealCastEnded(castGUID, spellID)
  if self.realCastGUID == castGUID and self.realSpellID == spellID then
    self.realCastGUID = nil
    self.realSpellID = nil
  end
end

function Module:MarkCastFailed(castGUID, spellID)
  if self.realCastGUID == castGUID and self.realSpellID == spellID then
    self.realCastGUID = nil
    self.realSpellID = nil
  end

  if self.sentCastGUID == castGUID and self.sentSpellID == spellID then
    self.sentCastGUID = nil
    self.sentSpellID = nil
  end

  if self.pendingCastGUID == castGUID and self.pendingSpellID == spellID then
    self.pendingCastGUID = nil
    self.pendingSpellID = nil
    self.pendingBar = nil
    self.pendingFrame:Hide()
  end
end

function Module:Stop(bar, preserveLiveCast)
  if bar.__puiInstantCleanupGroup:IsPlaying() then
    bar.__puiInstantCleanupGroup:Stop()
  end

  bar.__puiInstantCast = nil
  bar.instantStatus:Hide()
  bar.instantOverlay:Hide()
  bar.instantSpellName:SetText("")
  bar.instantSpellName:Hide()

  if preserveLiveCast == true then
    return
  end

  bar.timeTextBinding:Disable()
  bar.icon:Hide()
  bar.bg:SetAlpha(0)
  bar.__puiIsIdle = true
  bar:Hide()
end

function Module:StopActive(owner)
  local bar = owner.__puiPlayerCastBar

  self.sentCastGUID = nil
  self.sentSpellID = nil
  self.realCastGUID = nil
  self.realSpellID = nil
  self.pendingCastGUID = nil
  self.pendingSpellID = nil
  self.pendingBar = nil
  self.pendingFrame:Hide()

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

  local duration = bar.__puiInstantDuration
  duration:SetTimeFromStart(GetTime(), CB_INSTANT_CLEANUP_DURATION)

  local element = bar.instantStatus
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

  bar.instantSpellName:SetText(spellName)
  bar.instantSpellName:SetShown(bar.__puiInstantShowSpellName)
  bar.icon:SetTexture(spellTexture)
  bar.icon:SetShown(bar.__puiInstantShowIcon)
  bar.instantOverlay:SetShown(bar.__puiInstantUseOverlay)

  bar.timeTextBinding:Disable()
  bar.timeText:SetText("")
  bar.timeText:Hide()
  bar.safeZone:Hide()
  bar.safeZoneBorder:Hide()
  bar.safeZoneText:Hide()
  bar.spark:Hide()
  bar.uninterrupt:Hide()
  bar.uninterruptLeft:Hide()
  bar.uninterruptRight:Hide()

  element:SetTimerDuration(
    duration,
    Enum.StatusBarInterpolation.Immediate,
    bar.__puiInstantTimerDirection
  )
  element:Show()

  bar.__puiInstantCast = true
  bar.__puiInstantCleanupGroup:Stop()
  bar.__puiInstantCleanupGroup:Play()
end

local function CB_ProcessPendingInstant(frame)
  frame:Hide()

  local bar = Module.pendingBar
  local castGUID = Module.pendingCastGUID
  local spellID = Module.pendingSpellID

  Module.pendingBar = nil
  Module.pendingCastGUID = nil
  Module.pendingSpellID = nil

  if Module.enabled ~= true or not bar or not castGUID or not spellID then
    return
  end

  if Module.realCastGUID == castGUID and Module.realSpellID == spellID then
    return
  end

  CB_PresentInstant(bar, spellID)
end

function Module:SetEnabled(owner, enabled)
  if enabled == true then
    self.enabled = true
    return
  end

  self.enabled = nil
  self:StopActive(owner)
end

function Module:HandleSucceeded(owner, castGUID, spellID)
  if self.enabled ~= true
    or not castGUID
    or not spellID
    or self.sentCastGUID ~= castGUID
    or self.sentSpellID ~= spellID
  then
    return
  end

  self.sentCastGUID = nil
  self.sentSpellID = nil

  if self.realCastGUID == castGUID and self.realSpellID == spellID then
    return
  end

  self.pendingBar = owner.__puiPlayerCastBar
  self.pendingCastGUID = castGUID
  self.pendingSpellID = spellID
  self.pendingFrame:Show()
end


local P = select(1, ns.Pleebug:DropIn(Module, { name = "UnitFrames.CastBar.Instant" }))

CB_PresentInstant = P:Def("Instant.Present", CB_PresentInstant)
CB_ProcessPendingInstant = P:Def("Instant.Pending", CB_ProcessPendingInstant)

Module.pendingFrame = CreateFrame("Frame")
Module.pendingFrame:SetScript("OnUpdate", CB_ProcessPendingInstant)
Module.pendingFrame:Hide()
