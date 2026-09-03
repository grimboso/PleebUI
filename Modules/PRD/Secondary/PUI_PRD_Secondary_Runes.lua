local ADDON_NAME, ns = ...

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
    bar:SetParent(content)
    bar:ClearAllPoints()
    bar:SetSize(runeWidth, height)

    if i == 1 then
      bar:SetPoint("LEFT", content, "LEFT", 0, 0)
    else
      bar:SetPoint("LEFT", owner.runeBars[i - 1], "RIGHT", spacing, 0)
    end
  end
end

function M:BuildRuneBars()
  Secondary.EnsureSecondaryContainerBox(self)

  local content = Secondary.GetSecondaryContentFrame(self) or self.secondary
  local config = self.secondaryResourceConfig
  local texturePath = Secondary.FetchStatusbarTexture(
    config.texture or self.secondaryTexture
  )
  local inactiveAlpha = Secondary.GetInactiveAlpha(self)

  self.runeBars = self.runeBars or {}

  for i = 1, 6 do
    local bar = self.runeBars[i]
    if not bar then
      bar = CreateFrame("StatusBar", nil, content, "BackdropTemplate")
      self.runeBars[i] = bar
    end

    bar:SetParent(content)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar._puiRuneTimer = bar._puiRuneTimer or C_DurationUtil.CreateDuration()
    bar:SetStatusBarTexture(texturePath)
    bar:SetStatusBarColor(1, 1, 1, 1)

    if not bar._bg then
      local background = bar:CreateTexture(nil, "BACKGROUND")
      background:SetAllPoints(bar)
      bar._bg = background
    end
    bar._bg:SetTexture(texturePath)
    bar._bg:SetAlpha(inactiveAlpha)

    if not bar._timeText then
      local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

    if not bar._puiGlow then
      local glow = bar:CreateTexture(nil, "OVERLAY")
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
end

local function UpdateRuneBar(owner, index, showCooldown, showGlow, animationMode)
  local bar = owner.runeBars[index]
  local start, duration, runeReady = GetRuneCooldown(index)
  local wasOnCooldown = bar._wasOnCooldown == true

  if not bar:IsShown() then
    bar:Show()
  end

  if runeReady or not duration or duration == 0 then
    if bar._puiRuneState ~= "READY" then
      bar:SetValue(1)

      if bar._puiRuneTextShown == true then
        bar._puiRuneTextBinding:Disable()
        bar._timeText:SetText("")
        bar._timeText:Hide()
        bar._puiRuneTextShown = false
      end

      if showGlow and wasOnCooldown then
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

  if not start or start == 0 then
    if bar._puiRuneState ~= "PAUSED" then
      bar:SetValue(0)

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

  local timerChanged = bar._puiRuneStart ~= start
    or bar._puiRuneDuration ~= duration

  if timerChanged then
    bar._puiRuneStart = start
    bar._puiRuneDuration = duration
    bar._puiRuneTimer:SetTimeFromStart(start, duration)
    bar:SetTimerDuration(bar._puiRuneTimer)
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
  bar._puiRuneState = "CHARGING"
  return true
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

  local colorKey = Secondary.PackResourceColor(r, g, b, a)

  for i = 1, 6 do
    local bar = owner.runeBars[i]
    if bar._puiResourceColorKey ~= colorKey then
      bar._puiResourceColorKey = colorKey
      bar:SetStatusBarColor(r, g, b, a)
      bar._bg:SetVertexColor(r, g, b, a)
      bar._puiGlow:SetVertexColor(r, g, b, 1)
    end
  end
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

  local config = self.secondaryResourceConfig
  local behavior = config.behavior
  local showCooldown = behavior.showRechargeTime ~= false
  local showGlow = behavior.showReadyGlow ~= false
  local animationMode = behavior.completionAnimation or "FADE"

  local readyCount = 0

  for i = 1, 6 do
    UpdateRuneBar(self, i, showCooldown, showGlow, animationMode)
    if self.runeBars[i]._puiRuneReady == true then
      readyCount = readyCount + 1
    end
  end

  ApplyRuneResourceCues(self, readyCount)

  local text = Secondary.PrepareSecondaryText(self, self.secondaryBar)
  local value, shouldShow = Secondary.FormatSecondaryText(
    self,
    readyCount,
    6
  )
  Secondary.SetSecondaryCenterText(text, value, shouldShow)
end

local function Deactivate(owner)
  if owner.runeBars then
    for i = 1, #owner.runeBars do
      local bar = owner.runeBars[i]
      bar._puiRuneTextBinding:Disable()
      bar._timeText:SetText("")
      bar._timeText:Hide()

      if bar._puiGlowPulseGroup then
        bar._puiGlowPulseGroup:Stop()
      end
      bar._puiGlow:SetAlpha(0)

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
  events = {
    RUNE_POWER_UPDATE = true,
  },
  Deactivate = P:Def("Runes.Deactivate", Deactivate),
  Suspend = P:Def("Runes.Suspend", Deactivate),
  RefreshText = P:Def("Runes.RefreshText", RefreshText),
  IsStructureReady = P:Def("Runes.IsStructureReady", IsStructureReady),
  OnEvent = M.UpdateRunes,
  Build = M.BuildRuneBars,
  Update = M.UpdateRunes,
})
