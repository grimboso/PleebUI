
-- File: PUI_UF_CastBar_Layout.lua
-- Purpose: Shared castbar layout, anchoring, sizing, textures, and fonts.


local ADDON_NAME, ns = ...


local CastBar = ns.Modules.CastBar
local BarWidget = ns.BarWidget

local _G = _G
local UIParent = UIParent
local tonumber = tonumber
local type = type
local math_max = math.max

local Round = ns.Pixel.Round

local function CB_SetCastbarElementEnabled(bar, enabled)
  local frame = bar.__puiUnitFrame

  if enabled and not frame:IsElementEnabled("Castbar") then
    frame:EnableElement("Castbar")
  elseif not enabled and frame:IsElementEnabled("Castbar") then
    frame:DisableElement("Castbar")
  end
end

function CastBar:UpdateUnitLayout(unit, resolvedConfig, overrideBar, presentation)
  local bar = overrideBar or self:GetBar(unit)
  if not bar then
    return
  end

  local cfg = resolvedConfig or self:GetUnitConfig(unit)
  if not cfg then
    return
  end

  bar.__puiState = bar.__puiState or {}
  bar.__puiState.cfg = cfg
  bar.__puiState.unit = unit

  if self.db.profile.enabled == false or cfg.enabled == false then
    if presentation ~= true then
      CB_SetCastbarElementEnabled(bar, false)
    end
    bar:Hide()
    return
  end

  if presentation ~= true then
    CB_SetCastbarElementEnabled(bar, true)
  end

  local isBoss = type(unit) == "string" and unit:match("^boss%d") ~= nil

  local Empower = ns.PUICastBarEmpower
  Empower:ApplyConfig(bar, bar.status, cfg)
  Empower:UpdatePipColors(bar.status)

  local width = math_max(Round(1), Round(cfg.width or 240))
  local height = math_max(Round(1), Round(cfg.height or 20))
  local showIcon = (cfg.showIcon ~= false)
  local iconGap = showIcon and Round(6) or 0
  local iconSize = showIcon and math_max(Round(1), Round(tonumber(cfg.iconSize or height))) or 0
  local statusHost = bar.status

  bar:SetSize(width, height)
  bar.status:ClearAllPoints()

  if showIcon then
    bar.status:SetPoint("TOPLEFT", bar, "TOPLEFT", iconSize + iconGap, 0)
    bar.status:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    bar.icon:Show()
    bar.icon:SetSize(iconSize, iconSize)
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
  else
    bar.status:SetAllPoints(bar)
    bar.icon:Hide()
    bar.icon:SetSize(Round(1), Round(1))
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("LEFT", bar, "LEFT", 0, 0)
  end

  if bar.border and bar.border ~= (statusHost and statusHost.border) then
    bar.border:Hide()
  end

  CastBar.GetBorder(statusHost, cfg)
  bar.border = statusHost.border

  local offsetX = Round(cfg.offsetX or 0)
  local offsetY = Round(cfg.offsetY or -12)
  local moved = cfg.userMoved and true or false

  if isBoss then
    offsetX = Round(cfg.offsetX or 0)
    offsetY = Round(cfg.offsetY or -6)
    moved = false
  end

  bar:ClearAllPoints()

  if moved then
    bar:SetPoint("CENTER", UIParent, "CENTER", offsetX or 0, offsetY or 0)
  else
    local relFrame = type(cfg.relativeTo) == "string" and _G[cfg.relativeTo] or nil

    if relFrame then
      local point = cfg.point or "CENTER"
      local relativePoint = cfg.relativePoint or "CENTER"
      bar:SetPoint(point, relFrame, relativePoint, offsetX or 0, offsetY or -12)
    elseif cfg.attachToUF ~= false then
      local point = cfg.point or "TOP"
      local relativePoint = cfg.relativePoint or "BOTTOM"
      bar:SetPoint(point, bar.__puiUnitFrame, relativePoint, offsetX or 0, offsetY or -10)
    else
      local point = cfg.point or "CENTER"
      local relativePoint = cfg.relativePoint or "CENTER"
      bar:SetPoint(point, UIParent, relativePoint, offsetX or 0, offsetY or -12)
    end
  end

  local texture = BarWidget.ResolveStatusBarTexture(cfg.texture)
  bar.__puiNormalTexture = texture

  if unit == "player" then
    if cfg.instantCastTexture ~= "" then
      bar.__puiInstantTexture = BarWidget.ResolveStatusBarTexture(cfg.instantCastTexture)
    else
      bar.__puiInstantTexture = texture
    end

    bar.instantStatus:SetStatusBarTexture(bar.__puiInstantTexture)
    bar.instantStatus:SetReverseFill(cfg.reverseFill == true)
    bar.instantOverlay:SetTexture(BarWidget.ResolveStatusBarTexture(cfg.instantCastOverlayTexture))
    bar.instantOverlay:SetAlpha(CastBar.Clamp(cfg.instantCastOverlayAlpha, 0, 1))
    bar.__puiInstantAlpha = CastBar.Clamp(cfg.instantCastAlpha, 0.10, 1)
    bar.__puiInstantShowSpellName = cfg.__puiShowSpellName ~= false
    bar.__puiInstantShowIcon = cfg.showIcon ~= false
    bar.__puiInstantUseOverlay = cfg.instantCastUseOverlay ~= false

    if cfg.instantCastFillMode == "FILL" then
      bar.__puiInstantTimerDirection = Enum.StatusBarTimerDirection.ElapsedTime
    else
      bar.__puiInstantTimerDirection = Enum.StatusBarTimerDirection.RemainingTime
    end
  end

  bar.status:SetStatusBarTexture(texture)
  bar.status:SetReverseFill(cfg.reverseFill == true)

  local hold = tonumber(cfg.timeToHold) or 0.20
  if hold < 0 then
    hold = 0
  end
  bar.status.timeToHold = hold

  if cfg.showSpark == false then
    bar.spark:Hide()
  else
    local tex = bar.status:GetStatusBarTexture()
    bar.spark:SetWidth(Round(16))
    bar.spark:SetHeight(Round((bar:GetHeight() or 20) * 2))
    bar.spark:ClearAllPoints()
    bar.spark:SetPoint("CENTER", tex, "RIGHT", 0, 0)
    bar.spark:Show()
  end

  local bgR, bgG, bgB, bgA = CastBar.UnpackColor(cfg.bgColor, { 0, 0, 0, 0.40 })
  bar.bg:SetColorTexture(bgR, bgG, bgB, bgA)

  local testColor = presentation == true and bar.__puiTestColor or nil
  local statusR, statusG, statusB, statusA

  if testColor then
    statusR, statusG, statusB, statusA = CastBar.UnpackColor(testColor)
  else
    statusR, statusG, statusB, statusA = CastBar.GetBaseCastColor(unit, cfg)
  end

  bar.status:SetStatusBarColor(statusR, statusG, statusB, statusA or 1)

  if unit == "player" then
    bar.__puiInstantColorR = statusR
    bar.__puiInstantColorG = statusG
    bar.__puiInstantColorB = statusB
  end

  if bar.spellName and cfg.text then
    CastBar.SetFont(bar.spellName, cfg.text.useGlobalFont == true and nil or cfg.text.fontKey, cfg.text.size, cfg.text.flags)

    local r, g, b, a = CastBar.UnpackColor(cfg.text.color, { 1, 1, 1, 1 })
    bar.spellName:SetTextColor(r, g, b, a)

    bar.spellName:ClearAllPoints()
    local anchor = cfg.text.anchor or "LEFT"
    local textHost = bar.status
    bar.spellName:SetPoint(
      anchor,
      textHost,
      anchor,
      Round(cfg.text.offX or 6),
      Round(cfg.text.offY or 0)
    )

    if unit == "player" then
      CastBar.SetFont(bar.instantSpellName, cfg.text.useGlobalFont == true and nil or cfg.text.fontKey, cfg.text.size, cfg.text.flags)
      bar.instantSpellName:SetTextColor(r, g, b, a)
      bar.instantSpellName:ClearAllPoints()
      bar.instantSpellName:SetPoint(
        anchor,
        bar.instantStatus,
        anchor,
        Round(cfg.text.offX or 6),
        Round(cfg.text.offY or 0)
      )
    end

    if not CastBar.ShouldShowSpellName(cfg) then
      bar.spellName:Hide()
    else
      bar.spellName:Show()
    end

    if anchor:find("RIGHT") then
      bar.spellName:SetJustifyH("RIGHT")
      if unit == "player" then
        bar.instantSpellName:SetJustifyH("RIGHT")
      end
    else
      bar.spellName:SetJustifyH("LEFT")
      if unit == "player" then
        bar.instantSpellName:SetJustifyH("LEFT")
      end
    end
  end

  if bar.timeText and cfg.timeText then
    CastBar.SetFont(bar.timeText, cfg.timeText.useGlobalFont == true and nil or cfg.timeText.fontKey, cfg.timeText.size, cfg.timeText.flags)

    local r, g, b, a = CastBar.UnpackColor(cfg.timeText.color, { 1, 1, 1, 1 })
    bar.timeText:SetTextColor(r, g, b, a)

    bar.timeText:ClearAllPoints()
    local anchor = cfg.timeText.anchor or "RIGHT"
    local textHost = bar.status
    bar.timeText:SetPoint(anchor, textHost, anchor, Round(cfg.timeText.offX or -6), Round(cfg.timeText.offY or 0))

    if not CastBar.ShouldShowCastTime(cfg) then
      CastBar.StopTimeText(bar)
    elseif bar.__puiInstantCast then
      CastBar.StopTimeText(bar)
    elseif bar.status:IsShown() and not bar.__puiTestState then
      CastBar.StartTimeText(bar)
    else
      bar.timeText:Show()
    end

    if anchor:find("LEFT") then
      bar.timeText:SetJustifyH("LEFT")
    else
      bar.timeText:SetJustifyH("RIGHT")
    end
  end

  if unit == "player" then
    self:LayoutPlayerCastbar(bar, unit, cfg, statusHost)
  elseif bar.clipWarningText then
    bar.clipWarningText:Hide()
  end

  bar.uninterruptRight:SetSize(Round(16), Round(16))
  bar.uninterruptRight:ClearAllPoints()
  bar.uninterruptRight:SetPoint("RIGHT", bar.status, "RIGHT", Round(18), 0)
  bar.uninterruptRight:SetAtlas("UI-CastingBar-Shield", true)

  bar.uninterruptLeft:SetSize(Round(16), Round(16))
  bar.uninterruptLeft:ClearAllPoints()
  bar.uninterruptLeft:SetPoint("LEFT", bar.status, "LEFT", -Round(18), 0)
  bar.uninterruptLeft:SetAtlas("UI-CastingBar-Shield", true)

  CastBar.ApplyUninterruptTextureMode(bar, cfg)

end


function CastBar:UpdateAllLayouts()
  if not self.db or not self.db.profile then
    return
  end

  for i = 1, #self.Units do
    local unit = self.Units[i]
    local cfg = self:GetUnitConfig(unit)

    if cfg then
      self:UpdateUnitLayout(unit, cfg)
    elseif self.bars and self.bars[unit] then
      CB_SetCastbarElementEnabled(self.bars[unit], false)
      self.bars[unit]:Hide()
    end
  end
end


local P = select(1, ns.Pleebug:DropIn(CastBar, { name = "UnitFrames.CastBar.Layout" }))

  CB_SetCastbarElementEnabled = P:Def("CB_SetCastbarElementEnabled", CB_SetCastbarElementEnabled)
  CastBar.UpdateUnitLayout = P:Def("CastBar.UpdateUnitLayout", CastBar.UpdateUnitLayout)
  CastBar.UpdateAllLayouts = P:Def("CastBar.UpdateAllLayouts", CastBar.UpdateAllLayouts)

