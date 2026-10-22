local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace

local Pixel = ns.Pixel
local M = ns.Modules.PRD
local Secondary = ns.PRDSecondary
local P = ns.Pleebug:DropIn({}, { name = "PRD_Secondary_Runes" })

local RUNE_TIME_FORMATTER = C_StringUtil.CreateNumericRuleFormatter()
RUNE_TIME_FORMATTER:AddBreakpoint({ threshold = 0, format = "%.0f" })

local function ReflowRuneBars(owner)
  local content = Secondary.GetSecondaryContentFrame(owner) or owner.secondary
  local config = owner.secondaryResourceConfig
  local inset = Secondary.GetSecondaryBorderThickness(owner)

  local width = content:GetWidth()
  if not width or width <= 0 then
    width = config.width - inset * 2
  end
  if width < 1 then width = 1 end

  local height = content:GetHeight()
  if not height or height <= 0 then
    height = (config.height or 15) - inset * 2
  end
  height = Pixel.Round(height)
  if height < 1 then height = 1 end

  local spacing = Pixel.Round(2)
  local runeWidth = (width - spacing * 5) / 6

  for i = 1, 6 do
    local bar = owner.runeBars[i]
    bar:SetParent(owner.secondaryBar)
    bar:SetFrameLevel(owner.secondaryBar:GetFrameLevel() + 1)
    bar:ClearAllPoints()
    bar:SetSize(runeWidth, height)

    if i == 1 then
      bar:SetPoint("LEFT", content, "LEFT", 0, 0)
    else
      bar:SetPoint("LEFT", owner.runeBars[i - 1], "RIGHT", spacing, 0)
    end
  end
end

local function ApplyRuneCooldown(bar, start, duration, runeReady, recharging)
  local owner = bar._puiRuneOwner
  local behavior = owner.secondaryResourceConfig.behavior
  local showCooldown = behavior.simpleRunes ~= true and behavior.showRechargeTime ~= false
    and (recharging or behavior.showQueuedRuneTime == true)
  local showGlow = behavior.simpleRunes ~= true and behavior.showReadyGlow ~= false
  local animationMode = behavior.completionAnimation
  local inactiveAlpha = Secondary.GetInactiveAlpha(owner)
  local fill = bar._fill
  local wasOnCooldown = bar._wasOnCooldown == true
  if not runeReady or not showGlow then
    bar._puiGlowPulseGroup:Stop()
    bar._puiGlow:SetAlpha(0)
    bar._puiGlow:Hide()
  end
  local direction = behavior.rechargeDirection
  fill:SetOrientation((direction == "TTB" or direction == "BTT") and "VERTICAL" or "HORIZONTAL")
  fill:SetReverseFill(direction == "RTL" or direction == "TTB")
  bar._bg:SetAlpha(inactiveAlpha)

  if not bar:IsShown() then
    bar:Show()
  end

  if runeReady then
    fill:SetValue(400)
    if bar._puiRuneState ~= "READY" then
      if bar._puiRuneTextShown == true then
        bar._puiRuneTextBinding:Disable()
        bar._timeText:SetText("")
        bar._timeText:Hide()
        bar._puiRuneTextShown = false
      end

      if showGlow and wasOnCooldown then
        bar._puiGlow:Show()
        if animationMode == "PULSE" then
          bar._puiGlowPulseDuration = 0.25
          Secondary.PlaySecondaryGlowPulse(bar, "_puiGlow", 0.80)
        else
          bar._puiGlowPulseDuration = 0.45
          Secondary.PlaySecondaryGlowPulse(bar, "_puiGlow", 0.45)
        end
      end
    end

    bar._puiRuneStart = nil
    bar._puiRuneDuration = nil
    bar._puiRuneReady = true
    bar._wasOnCooldown = false
    bar._puiRuneState = "READY"
    return false
  end

  if start == 0 then
    fill:SetValue(0)
    if bar._puiRuneState ~= "PAUSED" then
      if bar._puiRuneTextShown == true then
        bar._puiRuneTextBinding:Disable()
        bar._timeText:SetText("")
        bar._timeText:Hide()
        bar._puiRuneTextShown = false
      end
    end

    bar._puiRuneStart = nil
    bar._puiRuneDuration = nil
    bar._puiRuneReady = false
    bar._wasOnCooldown = true
    bar._puiRuneState = "PAUSED"
    return false
  end

  local runeState = recharging and "CHARGING" or "QUEUED"
  local timerChanged = bar._puiRuneState ~= runeState
    or bar._puiRuneStart ~= start
    or bar._puiRuneDuration ~= duration

  bar._puiRuneStart = start
  bar._puiRuneDuration = duration
  bar._puiRuneTimer:SetTimeFromStart(start, duration)
  if recharging and behavior.simpleRunes ~= true then
    fill:SetTimerDuration(bar._puiRuneTimer)
  else
    fill:SetValue(0)
  end

  if showCooldown then
    if timerChanged or bar._puiRuneTextShown ~= true then
      bar._puiRuneTextBinding:SetDuration(bar._puiRuneTimer)
      bar._puiRuneTextBinding:Enable()
      bar._timeText:Show()
      bar._puiRuneTextShown = true
    end
  elseif bar._puiRuneTextShown == true then
    bar._puiRuneTextBinding:Disable()
    bar._timeText:SetText("")
    bar._timeText:Hide()
    bar._puiRuneTextShown = false
  end

  bar._puiRuneReady = false
  bar._wasOnCooldown = true
  bar._puiRuneState = runeState
  return recharging == true
end

local function ApplyRuneResourceCues(owner, readyCount)
  local config = owner.secondaryResourceConfig
  local r, g, b, a = Secondary.ResolveResourceCueColor(
    config,
    readyCount,
    owner._puiSecColorR,
    owner._puiSecColorG,
    owner._puiSecColorB,
    owner._puiSecColorA
  )

  Secondary.UpdateResourceThresholdCue(
    owner.secondary,
    config,
    readyCount
  )

  local behavior = config.behavior
  for i = 1, 6 do
    local bar = owner.runeBars[i]
    local sr, sg, sb, sa = r, g, b, a
    if bar._puiRuneReady ~= true and behavior.customRechargeColor then
      sr, sg, sb, sa = unpack(behavior.rechargeColor)
    end
    local colorKey = Secondary.PackResourceColor(sr, sg, sb, sa)
    if bar._puiResourceColorKey ~= colorKey then
      bar._puiResourceColorKey = colorKey
      bar._fill:SetStatusBarColor(sr, sg, sb, sa)
      bar._puiGlow:SetVertexColor(r, g, b, 1)
    end
  end
  local text = Secondary.PrepareSecondaryText(owner, owner.secondaryBar)
  if behavior.simpleRunes then
    local value, show = Secondary.FormatSecondaryText(owner, readyCount, 6)
    Secondary.SetSecondaryCenterText(text, value, show)
  else
    Secondary.SetSecondaryCenterText(text, nil, false)
  end
end

local function CompareRuneStart(left, right)
  if left.ready ~= right.ready then
    return left.ready
  end
  if (left.start == 0) ~= (right.start == 0) then
    return right.start == 0
  end
  return left.start < right.start
end

local function RefreshRuneWidget(bar)
  local cooldowns = {}
  local readyCount = 0
  for runeIndex = 1, 6 do
    local start, duration, ready = GetRuneCooldown(runeIndex)
    cooldowns[runeIndex] = { start = start, duration = duration, ready = ready }
    if ready then readyCount = readyCount + 1 end
  end
  table.sort(cooldowns, CompareRuneStart)
  -- Only three runes can recharge at once; later cooldowns are queued.
  local rechargingCount = 0
  for index = 1, 6 do
    local cooldown = cooldowns[index]
    if not cooldown.ready and cooldown.start ~= 0 then
      rechargingCount = rechargingCount + 1
      cooldown.recharging = rechargingCount <= 3
      if cooldown.recharging then
        cooldown.availableAt = cooldown.start + cooldown.duration
      end
    end
  end

  if bar._puiRuneOwner.secondaryResourceConfig.behavior.showQueuedRuneTime == true then
    for index = 1, 6 do
      local cooldown = cooldowns[index]
      if not cooldown.ready and not cooldown.recharging then
        local nextRecharge
        for rechargeIndex = 1, 6 do
          local recharge = cooldowns[rechargeIndex]
          if recharge.recharging
            and (not nextRecharge or recharge.availableAt < nextRecharge.availableAt)
          then
            nextRecharge = recharge
          end
        end
        if nextRecharge then
          cooldown.queuedReadyAt = nextRecharge.availableAt + cooldown.duration
          nextRecharge.availableAt = cooldown.queuedReadyAt
        end
      end
    end
  end

  local cooldown = cooldowns[bar._puiRuneSlot]
  local start, duration = cooldown.start, cooldown.duration
  if cooldown.queuedReadyAt then
    start = GetTime()
    duration = math.max(0, cooldown.queuedReadyAt - start)
  end
  ApplyRuneCooldown(bar, start, duration, cooldown.ready, cooldown.recharging)
  ApplyRuneResourceCues(bar._puiRuneOwner, readyCount)
end

if select(2, UnitClass("player")) == "DEATHKNIGHT" then
  M.runeBars = {}
  for index = 1, 6 do
    local bar = CreateFrame("Frame", nil, UIParent)
    bar:Hide()
    bar._fill = CreateFrame("StatusBar", nil, bar)
    bar._fill:SetAllPoints(bar)
    bar._puiRuneTimer = C_DurationUtil.CreateDuration()
    bar:SetScript("OnEvent", RefreshRuneWidget)
    M.runeBars[index] = bar
  end
end

function M:BuildRuneBars()
  Secondary.EnsureSecondaryContainerBox(self)

  local content = Secondary.GetSecondaryContentFrame(self) or self.secondary
  local runeContainer = Secondary.EnsureSecondaryBuildBar(self, content)
  Secondary.SetSecondaryCenterText(runeContainer._puiText, nil, false)
  local config = self.secondaryResourceConfig
  local texturePath = Secondary.FetchStatusbarTexture(
    config.texture or self.secondaryTexture
  )
  local inactiveAlpha = Secondary.GetInactiveAlpha(self)

  self.runeBars = self.runeBars or {}

  for i = 1, 6 do
    local bar = self.runeBars[i]

    bar:SetParent(runeContainer)
    bar:SetFrameLevel(runeContainer:GetFrameLevel() + 1)
    bar._puiRuneOwner = self
    bar._puiRuneSlot = i
    bar:RegisterEvent("RUNE_POWER_UPDATE")
    bar:SetAlpha(1)
    local fill = bar._fill
    fill:SetFrameLevel(bar:GetFrameLevel() + 1)
    fill:SetMinMaxValues(0, 400)
    fill:SetValue(400)
    fill:SetStatusBarTexture(texturePath)
    fill:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    fill:SetStatusBarColor(1, 1, 1, 1)

    if not bar._bg then
      local background = fill:CreateTexture(nil, "BACKGROUND")
      background:SetAllPoints(bar)
      bar._bg = background
    end
    bar._bg:SetColorTexture(unpack(config.style.bgColor))
    bar._bg:SetAlpha(inactiveAlpha)

    if not bar._timeText then
      local text = fill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      text:SetPoint("CENTER", bar, "CENTER", 0, 0)
      text:SetJustifyH("CENTER")
      text:SetTextColor(1, 1, 1, 1)
      text:SetShadowOffset(1, -1)
      text:SetShadowColor(0, 0, 0, 1)
      Secondary.ApplyResourceFont(self, text, config)
      bar._timeText = text

      local binding = C_DurationUtil.CreateDurationTextBinding()
      binding:SetFontString(text)
      binding:SetZeroDurationText("")
      binding:SetExpiredText("")
      binding:SetUpdateInterval(0.10)
      binding:SetFormatter(RUNE_TIME_FORMATTER)
      bar._puiRuneTextBinding = binding
    end
    Secondary.ApplyResourceFont(self, bar._timeText, config)
    bar._puiRuneTextBinding:Disable()
    bar._timeText:SetText("")
    bar._timeText:Hide()

    if not bar._puiGlow then
      local glow = fill:CreateTexture(nil, "OVERLAY")
      glow:SetAllPoints(bar)
      glow:SetBlendMode("ADD")
      glow:SetTexture(texturePath)
      glow:SetAlpha(0)
      bar._puiGlow = glow
    else
      bar._puiGlow:SetTexture(texturePath)
    end

    bar._puiGlowBaseAlpha = 0
    bar._puiGlow:SetAlpha(0)
    Secondary.EnsureSecondaryGlowPulse(bar, "_puiGlow")
    bar._puiGlowPulseGroup:Stop()
    bar._puiGlow:Hide()
    bar._wasOnCooldown = false
    bar._puiRuneStart = nil
    bar._puiRuneDuration = nil
    bar._puiRuneReady = true
    bar._puiRuneState = nil
    bar._puiRuneTextShown = false
    bar._puiResourceColorKey = nil
    bar:Show()
  end

  self.secondary:Show()
  Secondary.ReflowSecondaryGeometry(self)
  ReflowRuneBars(self)
  self:UpdateSecondary()
end

function M:UpdateRunes()
  if self.secondaryUsesCustom ~= true
    or not self.secondary:IsShown()
    or not self.runeBars
    or self.secondaryToken ~= "RUNIC_POWER"
  then
    return
  end

  if not self._puiSecondaryBox or not self._puiSecondaryContent or self._puiSecondaryNeedsReflow then
    Secondary.EnsureSecondaryContainerBox(self)
    Secondary.ReflowSecondaryGeometry(self)
    ReflowRuneBars(self)
  end

  for i = 1, 6 do
    local bar = self.runeBars[i]
    bar:RegisterEvent("RUNE_POWER_UPDATE")
    RefreshRuneWidget(bar)
  end
end

local function Deactivate(owner)
  if owner.runeBars then
    for i = 1, #owner.runeBars do
      local bar = owner.runeBars[i]
      bar:UnregisterAllEvents()
      bar._fill:SetValue(0)
      bar._puiRuneTextBinding:Disable()
      bar._timeText:SetText("")
      bar._timeText:Hide()

      if bar._puiGlowPulseGroup then
        bar._puiGlowPulseGroup:Stop()
      end
      bar._puiGlow:SetAlpha(0)
      bar._puiGlow:Hide()

      bar._wasOnCooldown = false
      bar._puiRuneStart = nil
      bar._puiRuneDuration = nil
      bar._puiRuneReady = nil
      bar._puiRuneState = nil
      bar._puiRuneTextShown = false
      bar._puiResourceColorKey = nil
      bar:Hide()
    end
  end
end

local function RefreshText(owner)
  if not owner.runeBars then
    return
  end

  for i = 1, #owner.runeBars do
    Secondary.ApplyResourceFont(
      owner,
      owner.runeBars[i]._timeText,
      owner.secondaryResourceConfig
    )
  end
end

local function IsStructureReady(owner)
  return owner.runeBars and #owner.runeBars == 6 or false
end

ApplyRuneResourceCues = P:Def(
  "Runes.ApplyResourceCues",
  ApplyRuneResourceCues
)
M.BuildRuneBars = P:Def("Runes.BuildRuneBars", M.BuildRuneBars)
M.UpdateRunes = P:Def("Runes.UpdateRunes", M.UpdateRunes)

Secondary:RegisterAdapter("RUNES", {
  directUpdate = true,
  events = {},
  Deactivate = P:Def("Runes.Deactivate", Deactivate),
  Suspend = P:Def("Runes.Suspend", Deactivate),
  RefreshText = P:Def("Runes.RefreshText", RefreshText),
  IsStructureReady = P:Def("Runes.IsStructureReady", IsStructureReady),
  Build = M.BuildRuneBars,
  Update = M.UpdateRunes,
})
