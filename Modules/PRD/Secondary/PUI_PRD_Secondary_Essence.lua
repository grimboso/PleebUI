local ADDON_NAME, ns = ...

local M = ns.Modules.PRD
local Secondary = ns.PRDSecondary
local P = ns.Pleebug:DropIn({}, { name = "PRD_Secondary_Essence" })

local ESSENCE_POWER_TYPE = Enum.PowerType.Essence
local ESSENCE_PARTIAL_SCALE = 1000
local ESSENCE_REGEN_FALLBACK = 0.2
local ESSENCE_HASTE_REFERENCE_SPELL_ID = 361227
local ESSENCE_TIME_FORMATTER = C_StringUtil.CreateNumericRuleFormatter()
ESSENCE_TIME_FORMATTER:AddBreakpoint({ threshold = 0, format = "%.0f" })

local function Clamp01(value)
  if value == nil then
    return 0
  end
  if type(value) ~= "number" then
    value = tonumber(value) or 0
  end
  if value <= 0 then return 0 end
  if value >= 1 then return 1 end
  return value
end

local function GetEssencePartialFraction(unit)
  local partial = UnitPartialPower(unit, ESSENCE_POWER_TYPE)
  if issecretvalue(partial) then
    return nil
  end

  if partial <= 0 then
    return 0
  end
  if partial >= ESSENCE_PARTIAL_SCALE then
    return 1
  end
  return partial / ESSENCE_PARTIAL_SCALE
end

local function ComputeProgress(unit, maxOverride)
  local full = UnitPower(unit, ESSENCE_POWER_TYPE, false)
  local maximum = tonumber(maxOverride)
  if not maximum then
    maximum = UnitPowerMax(unit, ESSENCE_POWER_TYPE, false)
  end
  if maximum <= 0 then maximum = full end
  if maximum < full then maximum = full end

  if full >= maximum then
    return full, maximum, 0
  end

  return full, maximum, GetEssencePartialFraction(unit) or 0
end

function M:RefreshEssenceRechargeRate()
  local spellInfo = C_Spell.GetSpellInfo(ESSENCE_HASTE_REFERENCE_SPELL_ID)
  local castTime = spellInfo and spellInfo.castTime

  -- Return has a 10-second base cast and follows the same spell-haste scaling
  -- as Essence's 5-second base recharge without exposing restricted unit stats.
  if castTime and not issecretvalue(castTime) and castTime > 0 then
    self._puiEssenceRechargeRate = 2000 / castTime
  end
  return self._puiEssenceRechargeRate or ESSENCE_REGEN_FALLBACK
end

function M:StopEssenceDriver()
  if self._puiEssenceAnimationGroup then
    self._puiEssenceAnimationGroup:Stop()
  end

  local segment = self._puiEssenceActiveSegment
  if segment then
    segment:SetScript("OnUpdate", nil)
    segment._puiEssenceTextBinding:Disable()
    segment._timeText:SetText("")
    segment._timeText:Hide()
  end

  self._puiEssenceActiveSegment = nil
  self._puiEssenceDriverStart = nil
  self._puiEssenceDriverDuration = nil
  self._puiEssenceAuthoritativePartial = nil
end

local function UpdateActiveSegment(owner, segment)
  local duration = owner._puiEssenceDriverDuration
  local start = owner._puiEssenceDriverStart
  if not duration or duration <= 0 or not start then
    return
  end

  local now = GetTime()
  local predictedFraction = Clamp01((now - start) / duration)
  local authoritativeFraction = GetEssencePartialFraction("player")

  if authoritativeFraction ~= nil then
    local previousAuthoritative = owner._puiEssenceAuthoritativePartial or 0

    -- Keep the authoritative value monotonic until this segment completes.
    if authoritativeFraction < previousAuthoritative then
      authoritativeFraction = previousAuthoritative
    else
      owner._puiEssenceAuthoritativePartial = authoritativeFraction
    end

    if authoritativeFraction > predictedFraction then
      start = now - authoritativeFraction * duration
      owner._puiEssenceDriverStart = start
      segment._puiEssenceDuration:SetTimeFromStart(start, duration)
      predictedFraction = authoritativeFraction
    end
  end

  local value = authoritativeFraction ~= nil
    and math.max(predictedFraction, authoritativeFraction)
    or predictedFraction
  if segment._puiEssenceVisualValue ~= value then
    segment._puiEssenceVisualValue = value
    segment._puiLastTargetV = value
    segment:SetValue(value)
  end
end

local function StartSegmentDriver(owner, segment, partialFraction)
  if not segment then
    owner:StopEssenceDriver()
    return
  end

  local previous = owner._puiEssenceActiveSegment
  if previous and previous ~= segment then
    previous:SetScript("OnUpdate", nil)
    previous._puiEssenceTextBinding:Disable()
    previous._timeText:SetText("")
    previous._timeText:Hide()
  end

  local normalizedPartial = Clamp01(partialFraction)
  if previous == segment then
    local previousAuthoritative = owner._puiEssenceAuthoritativePartial or 0
    if normalizedPartial < previousAuthoritative then
      normalizedPartial = previousAuthoritative
    end
  end

  owner._puiEssenceAuthoritativePartial = normalizedPartial

  local rate = owner:RefreshEssenceRechargeRate()
  local duration = 1 / rate
  local start = GetTime() - normalizedPartial * duration

  segment._puiEssenceDuration:SetTimeFromStart(start, duration)

  owner._puiEssenceActiveSegment = segment
  owner._puiEssenceDriverStart = start
  owner._puiEssenceDriverDuration = duration
  UpdateActiveSegment(owner, segment)

  if not owner._puiEssenceAnimationGroup then
    local driver = CreateFrame("Frame")
    local group = driver:CreateAnimationGroup()
    local animation = group:CreateAnimation("Animation")
    animation:SetDuration(0.05)
    group:SetLooping("REPEAT")
    group:SetScript("OnLoop", function()
      local activeSegment = owner._puiEssenceActiveSegment
      if activeSegment then
        UpdateActiveSegment(owner, activeSegment)
      end
    end)
    owner._puiEssenceAnimationGroup = group
  end
  owner._puiEssenceAnimationGroup:Play()

  if owner._puiEssShowCooldownCount ~= false then
    segment._puiEssenceTextBinding:SetDuration(segment._puiEssenceDuration)
    segment._puiEssenceTextBinding:Enable()
    segment._timeText:Show()
  else
    segment._puiEssenceTextBinding:Disable()
    segment._timeText:SetText("")
    segment._timeText:Hide()
  end
end

local function PrepareSegment(owner, segment, texturePath)
  segment._puiBg:Hide()

  if not segment.glow then
    local glow = segment:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints(segment)
    glow:SetBlendMode("ADD")
    segment.glow = glow
  end
  segment.glow:SetAllPoints(segment)
  segment.glow:SetTexture(texturePath)
  segment.glow:SetAlpha(0)
  segment.glow:Show()

  segment._puiWasFull = false
  segment._puiGlowPulseDuration = 0.25
  segment._puiGlowBaseAlpha = 0
  Secondary.EnsureSecondaryGlowPulse(segment, "glow")

  if not segment._timeText then
    local text = segment:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", segment, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetTextColor(1, 1, 1, 1)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    Secondary.ApplyResourceFont(owner, text, owner.secondaryResourceConfig)
    segment._timeText = text

    segment._puiEssenceDuration = C_DurationUtil.CreateDuration()
    local binding = C_DurationUtil.CreateDurationTextBinding()
    binding:SetFontString(text)
    binding:SetZeroDurationText("")
    binding:SetExpiredText("")
    binding:SetUpdateInterval(0.10)
    binding:SetFormatter(ESSENCE_TIME_FORMATTER)
    segment._puiEssenceTextBinding = binding
  end
  segment._puiEssenceOwner = owner
  Secondary.ApplyResourceFont(owner, segment._timeText, owner.secondaryResourceConfig)
  segment._puiEssenceTextBinding:Disable()
  segment._timeText:SetText("")
  segment._timeText:Hide()
end

local function Build(owner)
  local segmentCount = owner.secondaryMax
  if segmentCount > 6 then
    segmentCount = 6
  end

  Secondary.BuildSegmented(owner, segmentCount, segmentCount, PrepareSegment)
end

local function ApplyVisuals(owner, full, maximum, partialFraction, r, g, b, a)
  local segments = owner.secondarySegments
  local segmentCount = owner._puiSecondaryActiveSegmentCount or 0
  if not segments or segmentCount == 0 then
    owner:StopEssenceDriver()
    return
  end

  partialFraction = Clamp01(partialFraction)
  local config = owner.secondaryResourceConfig
  local behavior = config.behavior
  local direction = behavior.rechargeDirection or "LTR"
  local showGlow = behavior.showReadyGlow ~= false
  local animationMode = behavior.completionAnimation or "FADE"
  local inactiveAlpha = Secondary.GetInactiveAlpha(owner)
  owner._puiEssShowCooldownCount = behavior.showRechargeTime ~= false

  r = tonumber(r) or 1
  g = tonumber(g) or 1
  b = tonumber(b) or 1
  a = tonumber(a) or 1

  local pr = math.floor(r * 1000 + 0.5)
  local pg = math.floor(g * 1000 + 0.5)
  local pb = math.floor(b * 1000 + 0.5)
  local pa = math.floor(a * 1000 + 0.5)
  if pr < 0 then pr = 0 elseif pr > 1000 then pr = 1000 end
  if pg < 0 then pg = 0 elseif pg > 1000 then pg = 1000 end
  if pb < 0 then pb = 0 elseif pb > 1000 then pb = 1000 end
  if pa < 0 then pa = 0 elseif pa > 1000 then pa = 1000 end
  local colorKey = pr * 1000000000 + pg * 1000000 + pb * 1000 + pa

  local activeIndex = full < maximum and full + 1 or nil

  for i = 1, segmentCount do
    local segment = segments[i]

    if segment._puiFillMode ~= direction then
      segment._puiFillMode = direction

      if direction == "RTL" then
        segment:SetOrientation("HORIZONTAL")
        segment:SetReverseFill(true)
      elseif direction == "TTB" then
        segment:SetOrientation("VERTICAL")
        segment:SetReverseFill(false)
      elseif direction == "BTT" then
        segment:SetOrientation("VERTICAL")
        segment:SetReverseFill(true)
      else
        segment:SetOrientation("HORIZONTAL")
        segment:SetReverseFill(false)
      end
    end

    local isFull = i <= full
    local isPartial = i == activeIndex
    local value = isFull and 1 or isPartial and partialFraction or 0
    local alpha = animationMode == "FADE" and 1 or (isFull or isPartial) and 1 or inactiveAlpha

    if not segment._puiMinMaxSet then
      segment:SetMinMaxValues(0, 1)
      segment._puiMinMaxSet = true
    end

    if segment._puiLastColorP ~= colorKey then
      segment._puiLastColorP = colorKey
      segment:SetStatusBarColor(r, g, b, a)
    end

    if segment._puiLastTargetV ~= value then
      segment._puiLastTargetV = value
      segment:SetValue(value)
    end
    segment._puiEssenceVisualValue = value

    if segment._puiLastTargetA ~= alpha then
      segment._puiLastTargetA = alpha
      segment:SetAlpha(alpha)
    end

    segment.glow:SetVertexColor(r, g, b, 1)

    local baseGlow = showGlow and isFull and 0.25 or 0
    segment._puiGlowBaseAlpha = baseGlow
    segment.glow:SetAlpha(baseGlow)

    if isFull and not segment._puiWasFull then
      segment._puiWasFull = true
      if animationMode == "PULSE" then
        Secondary.PlaySecondaryGlowPulse(segment, "glow", 0.8)
      elseif animationMode == "FADE" then
        Secondary.PlaySecondaryGlowPulse(segment, "glow", 0.45)
      end
    elseif not isFull then
      segment._puiWasFull = false
    end

    if not isPartial then
      segment:SetScript("OnUpdate", nil)
      segment._puiEssenceTextBinding:Disable()
      segment._timeText:SetText("")
      segment._timeText:Hide()
    end
  end

  if activeIndex then
    StartSegmentDriver(owner, segments[activeIndex], partialFraction)
  else
    owner:StopEssenceDriver()
  end
end

function M:UpdateEssenceRegenOnly()
  if self.secondaryUsesCustom ~= true
    or self.secondaryToken ~= "ESSENCE"
    or not self.secondary:IsShown()
  then
    return
  end

  local full = UnitPower("player", ESSENCE_POWER_TYPE, false)
  if self._puiEssLiveFull ~= full then
    self:UpdateSecondary()
    return
  end

  local maximum = self._puiEssLiveMax or 0
  if full >= maximum then
    self:StopEssenceDriver()
    return
  end

  local active = self.secondarySegments[full + 1]
  local start = self._puiEssenceDriverStart
  local duration = self._puiEssenceDriverDuration
  if self._puiEssenceActiveSegment ~= active or not start or not duration then
    self:UpdateSecondary()
    return
  end

  UpdateActiveSegment(self, active)
end

local function ResetRuntime(owner)
  owner:StopEssenceDriver()
  local segments = owner.secondarySegments
  if segments then
    for i = 1, #segments do
      segments[i]:SetScript("OnUpdate", nil)
    end
  end
  owner._puiEssState = nil
  owner._puiEssLiveFull = nil
  owner._puiEssLiveMax = nil
  owner._puiEssLivePartialIndex = nil
end

local function RefreshText(owner)
  local segments = owner.secondarySegments
  if not segments then
    return
  end

  for i = 1, #segments do
    local text = segments[i]._timeText
    if text then
      Secondary.ApplyResourceFont(owner, text, owner.secondaryResourceConfig)
    end
  end
end

local function OnEvent(owner, event, unit, powerToken)
  if event == "PLAYER_REGEN_ENABLED" then
    owner:RefreshEssenceRechargeRate()
    owner:UpdateSecondary()
    return
  end

  if unit ~= "player" then
    return
  end

  if event == "UNIT_POWER_FREQUENT" then
    if powerToken == "ESSENCE" then
      owner:UpdateEssenceRegenOnly()
    end
    return
  end

  if event == "UNIT_MAXPOWER" then
    if powerToken == "ESSENCE" then
      owner:RebuildSecondary()
    end
    return
  end

  owner:RefreshEssenceRechargeRate()
  owner:UpdateSecondary()
end

local function Update(owner, bar, text, unit)
  local segmentMaximum = owner._puiSecondaryActiveSegmentCount or owner.secondaryMax
  local full, maximum, partialFraction = ComputeProgress(unit, segmentMaximum)
  local r, g, b, a = owner._puiSecColorR, owner._puiSecColorG, owner._puiSecColorB, owner._puiSecColorA
  local resourceConfig = owner.secondaryResourceConfig

  r, g, b, a = Secondary.ResolveResourceCueColor(
    resourceConfig,
    full,
    r,
    g,
    b,
    a
  )
  Secondary.UpdateResourceThresholdCue(
    owner.secondary,
    resourceConfig,
    full
  )

  local behavior = resourceConfig.behavior
  local fillMode = behavior.rechargeDirection or "LTR"
  local showGlow = behavior.showReadyGlow ~= false and 1 or 0
  local showCount = behavior.showRechargeTime ~= false and 1 or 0
  local animation = behavior.completionAnimation or "FADE"
  local colorKey = table.concat({
    math.floor((tonumber(r) or 1) * 1000 + 0.5),
    math.floor((tonumber(g) or 1) * 1000 + 0.5),
    math.floor((tonumber(b) or 1) * 1000 + 0.5),
    math.floor((tonumber(a) or 1) * 1000 + 0.5),
  }, ":")
  local segmentCount = owner._puiSecondaryActiveSegmentCount or 0

  local state = owner._puiEssState
  if not state then
    state = {}
    owner._puiEssState = state
  end

  local changed =
    state.full ~= full or
    state.maximum ~= maximum or
    state.fillMode ~= fillMode or
    state.showGlow ~= showGlow or
    state.showCount ~= showCount or
    state.animation ~= animation or
    state.colorKey ~= colorKey or
    state.segmentCount ~= segmentCount or
    state.rechargeRate ~= owner._puiEssenceRechargeRate

  owner._puiEssLiveFull = full
  owner._puiEssLiveMax = maximum
  owner._puiEssLivePartialIndex = full < maximum and full + 1 or nil

  if changed then
    state.full = full
    state.maximum = maximum
    state.fillMode = fillMode
    state.showGlow = showGlow
    state.showCount = showCount
    state.animation = animation
    state.colorKey = colorKey
    state.segmentCount = segmentCount
    state.rechargeRate = owner._puiEssenceRechargeRate

    ApplyVisuals(owner, full, maximum, partialFraction, r, g, b, a)
  elseif full < maximum then
    local active = owner.secondarySegments[full + 1]
    if owner._puiEssenceActiveSegment ~= active then
      StartSegmentDriver(owner, active, partialFraction)
    end
  else
    owner:StopEssenceDriver()
  end

  local value, shouldShow = Secondary.FormatSecondaryText(owner, full, maximum)
  Secondary.SetSecondaryCenterText(text, value, shouldShow)
end

M.RefreshEssenceRechargeRate = P:Def("Essence.RefreshRechargeRate", M.RefreshEssenceRechargeRate)
M.StopEssenceDriver = P:Def("Essence.StopDriver", M.StopEssenceDriver)
M.UpdateEssenceRegenOnly = P:Def("Essence.UpdateRegenOnly", M.UpdateEssenceRegenOnly)

Secondary:RegisterAdapter("ESSENCE", {
  events = {
    UNIT_POWER_FREQUENT = "player",
    UNIT_MAXPOWER = "player",
    UNIT_SPELL_HASTE = "player",
    PLAYER_REGEN_ENABLED = true,
  },
  Deactivate = P:Def("Essence.Deactivate", ResetRuntime),
  Suspend = P:Def("Essence.Suspend", ResetRuntime),
  RefreshText = P:Def("Essence.RefreshText", RefreshText),
  Build = P:Def("Essence.Build", Build),
  OnEvent = P:Def("Essence.OnEvent", OnEvent),
  Update = P:Def("Essence.Update", Update),
})
