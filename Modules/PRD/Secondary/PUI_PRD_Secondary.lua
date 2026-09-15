
local ADDON_NAME, ns = ...


local Theme = ns.Theme
local Pixel = ns.Pixel
local LSM   = ns.LSM
local LCG   = LibStub("LibCustomGlow-1.0")

local PLAYER_CLASS = select(2, UnitClass("player"))

local M     = ns.Modules.PRD
local Secondary = ns.PRDSecondary
local AuraSlotDriver = ns.AuraSlotDriver
local AuraWidget = ns.AuraWidget


local _GetSecondaryInactiveAlpha

local P = ns.Pleebug:DropIn({}, { name = "PRD_Secondary" })

local function _CaptureBlizzardDisplayState(self, root)
  if self._puiOriginalRootDisplay then
    return
  end

  self._puiOriginalRootDisplay = {
    alpha = root:GetAlpha(),
    mouseEnabled = root:IsMouseEnabled(),
    shown = root:IsShown(),
    hideClassInfo = root.hideClassInfo,
    hideAltPower = root.hideAltPower,
  }
end

function M:SetBlizzardRootGhosted(ghost)
  self:AcquireBlizzardFrames()
  local root = self.blizz and self.blizz.root
  if not root or (root.IsForbidden and root:IsForbidden()) then return end

  _CaptureBlizzardDisplayState(self, root)

  if ghost then
    root:SetAlpha(0)
    root:EnableMouse(false)
    root:Show() -- keep scripts running
  else
    root:SetAlpha(1)
    root:EnableMouse(true)
  end
end


function M:SetBlizzardSecondaryShown(show)
  local root = self:AcquireBlizzardFrames()
  _CaptureBlizzardDisplayState(self, root)

  local hideAlternateMana = self.db.profile.primary.hideAlternateMana == true

  root:SetHideClassInfo(not show)
  root:SetHideAltPower(not show or hideAlternateMana)
end

function M:RestoreBlizzardDisplayState()
  if InCombatLockdown() then
    return false
  end

  local root = self:AcquireBlizzardFrames()
  local original = self._puiOriginalRootDisplay
  if not root or not original then
    return true
  end

  root:SetAlpha(original.alpha)
  root:EnableMouse(original.mouseEnabled)
  root:SetShown(original.shown and GetCVar("nameplateShowSelf") == "1")
  root:SetHideClassInfo(original.hideClassInfo)
  root:SetHideAltPower(original.hideAltPower)
  self._puiOriginalRootDisplay = nil
  return true
end


local function _FetchStatusbarTexture(key)
  if type(key) == "string" and key ~= "" then
    local path = LSM:Fetch("statusbar", key, true)
    if type(path) == "string" and path ~= "" then
      return path
    end

    if key:find("\\", 1, true) or key:find("/", 1, true) then
      return key
    end
  end

  local fallback = LSM:Fetch("statusbar", "Pleebar", true)
  if type(fallback) == "string" and fallback ~= "" then
    return fallback
  end

  return "Interface\\Buttons\\WHITE8X8"
end

local function _ResolveSecondaryTextureKey(self, secCfg)
  if secCfg.texture and secCfg.texture ~= "" then
    return secCfg.texture
  end

  if self.secondaryTexture and self.secondaryTexture ~= "" then
    return self.secondaryTexture
  end

  return nil
end

local function _GetSecondaryStructureSignature(self, buildMode, segmentCount, dividerCount, secCfg, profile)
  local textureKey = _ResolveSecondaryTextureKey(self, secCfg)
  local width = self.secondary:GetWidth()
  local height = self.secondary:GetHeight()

  if not width or width <= 0 then
    width = secCfg.width or profile.size.width or 250
  end
  if not height or height <= 0 then
    height = secCfg.height or 15
  end

  return (
    tostring(buildMode) .. "|" ..
    tostring(segmentCount or 0) .. "|" ..
    tostring(dividerCount or 0) .. "|" ..
    tostring(textureKey or "") .. "|" ..
    tostring(Pixel.Round(width)) .. "|" ..
    tostring(Pixel.Round(height)) .. "|" ..
    tostring(secCfg.stateKey or "")
  )
end

local function _CanReuseSecondaryStructure(self, buildMode, segmentCount)
  if not self.secondaryBar or not self.secondaryBar:IsShown() then
    return false
  end

  if buildMode == "SEGMENTED" then
    if not self.secondarySegments
      or self._puiSecondaryActiveSegmentCount ~= segmentCount
    then
      return false
    end

    for i = 1, segmentCount do
      local segment = self.secondarySegments[i]
      if not segment or not segment:IsShown() then
        return false
      end
    end

    return true
  end

  return self.secondaryStatusBar ~= nil
    and self.secondaryStatusBar:IsShown()
end

local function _ClearSecondaryStructure(self)
  if self.secondaryBar then
    self.secondaryBar:Hide()
  end
  if self.secondaryStatusBar then
    self.secondaryStatusBar:Hide()
  end

  if self.secondaryDividers then
    for _, d in ipairs(self.secondaryDividers) do
      if d then
        d:Hide()
      end
    end
  end

  if self.secondaryDividerFrame then
    self.secondaryDividerFrame:Hide()
  end
  self._puiSecondaryActiveDividerCount = 0

  if self.secondarySegments then
    for _, seg in ipairs(self.secondarySegments) do
      if seg then
        if seg._puiGlowPulseGroup then
          seg._puiGlowPulseGroup:Stop()
        end
        seg:Hide()
      end
    end
  end
  self._puiSecondaryActiveSegmentCount = 0

end


local function _GetSecondaryBorderThickness(self)
  local config = self.secondaryResourceConfig
  return self:GetBarBorderThickness(config.style, self.secondary)
end

local function _TrackedSpellIconIsShown(config, visible)
  return visible == true
    and config
    and config.showSpellIcon == true
    and config.iconSpellID ~= nil
end

local function _GetTrackedResourceBarFrame(parent, config, visible)
  if not parent then
    return nil
  end

  local barFrame = parent._puiTrackedResourceBarFrame
  if not barFrame then
    barFrame = CreateFrame("Frame", nil, parent)
    barFrame:EnableMouse(false)
    parent._puiTrackedResourceBarFrame = barFrame
  end

  local leftOffset = 0
  if _TrackedSpellIconIsShown(config, visible) then
    local iconSize = Pixel.Round(parent:GetHeight())
    if iconSize < 1 then
      iconSize = Pixel.Round(config.height or 15)
    end

    leftOffset = iconSize + Pixel.Round(config.iconGap or 0)
  end

  if barFrame._puiLeftOffset ~= leftOffset then
    barFrame._puiLeftOffset = leftOffset
    barFrame:ClearAllPoints()
    barFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", leftOffset, 0)
    barFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
  end

  local strata = parent:GetFrameStrata()
  if barFrame._puiLastStrata ~= strata then
    barFrame._puiLastStrata = strata
    barFrame:SetFrameStrata(strata)
  end

  local level = (parent:GetFrameLevel() or 0) + 1
  if barFrame._puiLastLevel ~= level then
    barFrame._puiLastLevel = level
    barFrame:SetFrameLevel(level)
  end

  barFrame:Show()

  return barFrame
end

local function _GetSecondaryContentFrame(self)
  if not self or not self.secondary then
    return nil
  end

  local barFrame = _GetTrackedResourceBarFrame(
    self.secondary,
    self.secondaryResourceConfig,
    self.secondaryUsesCustom
  )
  local content = self._puiSecondaryContent
  if not content then
    content = CreateFrame("Frame", nil, barFrame)
    content:EnableMouse(false)
    self._puiSecondaryContent = content
  end

  if content:GetParent() ~= barFrame then
    content:SetParent(barFrame)
    content:ClearAllPoints()
  end

  local inset = _GetSecondaryBorderThickness(self)
  if content._puiInset ~= inset or content._puiAnchorParent ~= barFrame then
    content._puiInset = inset
    content._puiAnchorParent = barFrame
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", barFrame, "TOPLEFT", inset, -inset)
    content:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -inset, inset)
    self._puiSecondaryNeedsReflow = true
  end

  local lvl = (barFrame:GetFrameLevel() or 1) + 1
  if content._puiLastLevel ~= lvl then
    content._puiLastLevel = lvl
    content:SetFrameLevel(lvl)
  end

  content:Show()
  return content
end

local function _EnsureSecondaryBuildBar(self, content)
  local bar = self.secondaryBar
  if not bar then
    bar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    self.secondaryBar = bar
  elseif bar:GetParent() ~= content then
    bar:SetParent(content)
  end

  bar:ClearAllPoints()
  bar:SetAllPoints(content)
  bar:SetClipsChildren(true)
  bar:Show()

  return bar
end

local function _EnsureSecondaryTextOverlay(bar)
  local overlay = bar._puiTextOverlay
  if not overlay then
    overlay = CreateFrame("Frame", nil, bar)
    bar._puiTextOverlay = overlay
  elseif overlay:GetParent() ~= bar then
    overlay:SetParent(bar)
  end

  overlay:ClearAllPoints()
  overlay:SetAllPoints(bar)
  overlay:EnableMouse(false)
  overlay:SetFrameLevel((bar:GetFrameLevel() or 0) + 50)
  overlay:Show()

  return overlay
end

local function _EnsureSecondaryTexts(bar, overlay)
  local text = bar._puiText
  if not text then
    text = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar._puiText = text
  end

  text:SetWidth(0)
  text:ClearAllPoints()
  text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  text:SetJustifyH("CENTER")
  text:SetTextColor(1, 1, 1, 1)
  text:SetShadowOffset(1, -1)
  text:SetShadowColor(0, 0, 0, 1)
  if text.SetFont then
    text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
  end
  Theme.ApplyFont(text, "header", 16, "OUTLINE")
end

_GetSecondaryInactiveAlpha = function(self)
  local alpha = self._puiSecInactiveAlpha
  if alpha ~= nil then
    return alpha
  end

  local cfg = self.secondaryResourceConfig
  alpha = tonumber(cfg.inactiveAlpha) or 0.15

  if alpha < 0 then alpha = 0 end
  if alpha > 1 then alpha = 1 end

  self._puiSecInactiveAlpha = alpha
  return alpha
end

function Secondary.GetSecondaryDividerSize(secCfg)
  local size = Pixel.Round(tonumber(secCfg.dividerSize) or 1)
  if size < 1 then
    size = ns.Pixel.GetOnePixel() or Pixel.Round(1)
  end
  return size
end

local function _ResolveSecondaryDividerColor(secCfg)
  local divCol = { r = 0.20, g = 0.20, b = 0.24, a = 1.00 }
  local configured = secCfg.dividerColor

  if type(configured) == "table" then
    divCol.r = tonumber(configured[1] or configured.r) or divCol.r
    divCol.g = tonumber(configured[2] or configured.g) or divCol.g
    divCol.b = tonumber(configured[3] or configured.b) or divCol.b
    divCol.a = tonumber(configured[4] or configured.a) or divCol.a
    return divCol
  end

  local borderColor = secCfg.style and secCfg.style.borderColor
  if type(borderColor) == "table" then
    divCol.r = tonumber(borderColor[1] or borderColor.r) or divCol.r
    divCol.g = tonumber(borderColor[2] or borderColor.g) or divCol.g
    divCol.b = tonumber(borderColor[3] or borderColor.b) or divCol.b
    divCol.a = tonumber(borderColor[4] or borderColor.a) or divCol.a
  end

  return divCol
end

local function _HideSecondaryDividerSet(self)
  if self.secondaryDividers then
    for i = 1, #self.secondaryDividers do
      local d = self.secondaryDividers[i]
      if d then
        d:Hide()
      end
    end
  end

  self._puiSecondaryActiveDividerCount = 0

  if self.secondaryDividerFrame then
    self.secondaryDividerFrame:Hide()
  end
end

local function _EnsureSecondaryDividerFrame(self, bar, levelOffset)
  local dividerFrame = self.secondaryDividerFrame
  if not dividerFrame then
    dividerFrame = CreateFrame("Frame", nil, bar)
    self.secondaryDividerFrame = dividerFrame
  elseif dividerFrame:GetParent() ~= bar then
    dividerFrame:SetParent(bar)
  end

  dividerFrame:ClearAllPoints()
  dividerFrame:SetAllPoints(bar)
  dividerFrame:SetFrameStrata(bar:GetFrameStrata())
  dividerFrame:SetFrameLevel(bar:GetFrameLevel() + (levelOffset or 30))
  dividerFrame:Show()

  return dividerFrame
end


local function _ApplySecondaryDividers(self, bar, secCfg, segmentCount, width, useSegmentAnchors, levelOffset)
  if secCfg.showDividers == false or not segmentCount or segmentCount <= 1 then
    _HideSecondaryDividerSet(self)
    return
  end

  local dividerFrame = _EnsureSecondaryDividerFrame(self, bar, levelOffset)
  local dividerW = Secondary.GetSecondaryDividerSize(secCfg)
  local divCol = _ResolveSecondaryDividerColor(secCfg)

  self.secondaryDividers = self.secondaryDividers or {}
  local numDividers = segmentCount - 1
  self._puiSecondaryActiveDividerCount = numDividers

  for i = 1, numDividers do
    local d = self.secondaryDividers[i]
    if not d then
      d = dividerFrame:CreateTexture(nil, "OVERLAY", nil, 7)
      self.secondaryDividers[i] = d
    end

    d:SetColorTexture(divCol.r, divCol.g, divCol.b, divCol.a)
    d:SetWidth(dividerW)
    d:ClearAllPoints()
    d:SetPoint("TOP", dividerFrame, "TOP", 0, 0)
    d:SetPoint("BOTTOM", dividerFrame, "BOTTOM", 0, 0)

    if useSegmentAnchors and self.secondarySegments and self.secondarySegments[i] then
      d:SetPoint("LEFT", self.secondarySegments[i], "RIGHT", -(dividerW / 2), 0)
    else
      local xPos = (width * i / segmentCount) - dividerW / 2
      d:SetPoint("LEFT", dividerFrame, "LEFT", xPos, 0)
    end

    d:Show()
  end

  for i = numDividers + 1, #self.secondaryDividers do
    local d = self.secondaryDividers[i]
    if d then
      d:Hide()
    end
  end

end

local function _UpdateTrackedSpellIcon(self, parent, config, visible)
  if not parent then
    return
  end

  local iconFrame = parent._puiTrackedSpellIcon
  local prepareIcon = _TrackedSpellIconIsShown(
    config,
    visible == true or self.secondaryCustomEnabled == true
  )

  if not prepareIcon then
    if parent._puiTrackedResourceBarFrame then
      _GetTrackedResourceBarFrame(parent, config, false)
    end
    if iconFrame then
      iconFrame:Hide()
    end
    return
  end

  _GetTrackedResourceBarFrame(parent, config, true)

  if not iconFrame then
    iconFrame = CreateFrame("Frame", nil, parent)
    iconFrame:EnableMouse(false)

    iconFrame.background = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconFrame.background:SetAllPoints(iconFrame)

    iconFrame.texture = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    parent._puiTrackedSpellIcon = iconFrame
  end

  local style = config.style
  local size = Pixel.Round(parent:GetHeight())
  if size < 1 then
    size = Pixel.Round(config.height or 15)
  end

  local stateKey = config.stateKey or ""
  local parentStrata = parent:GetFrameStrata()
  local parentLevel = parent:GetFrameLevel() or 0

  if iconFrame._puiStateKey == stateKey
    and iconFrame._puiSize == size
    and iconFrame._puiParentStrata == parentStrata
    and iconFrame._puiParentLevel == parentLevel
  then
    iconFrame:SetShown(visible == true)
    return
  end

  iconFrame._puiStateKey = stateKey
  iconFrame._puiSize = size
  iconFrame._puiParentStrata = parentStrata
  iconFrame._puiParentLevel = parentLevel

  local backgroundColor = style.bgColor
  local borderColor = self:GetBarBorderColor(style)

  iconFrame:ClearAllPoints()
  iconFrame:SetPoint("LEFT", parent, "LEFT", 0, 0)
  iconFrame:SetSize(size, size)
  local borderSize = self:GetBarBorderThickness(style, iconFrame)
  iconFrame:SetFrameStrata(parentStrata)
  iconFrame:SetFrameLevel(parentLevel + 30)

  iconFrame.background:SetColorTexture(
    backgroundColor[1] or 0,
    backgroundColor[2] or 0,
    backgroundColor[3] or 0,
    backgroundColor[4] or 0.65
  )

  iconFrame.texture:ClearAllPoints()
  iconFrame.texture:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", borderSize, -borderSize)
  iconFrame.texture:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -borderSize, borderSize)
  iconFrame.texture:SetTexture(C_Spell.GetSpellTexture(config.iconSpellID))

  self:ApplyBarBorder(iconFrame, borderSize, borderColor)
  iconFrame:SetShown(visible == true)
end

local function _UpdateTrackedSpellIcons(self)
  local resources = self.secondaryResources
  if type(resources) == "table" then
    for index = 1, #resources do
      local resource = resources[index]
      local view = resource.view or (index == 1 and self or nil)
      if view then
        _UpdateTrackedSpellIcon(
          view,
          resource.frame,
          resource.config,
          self.secondaryUsesCustom
        )
      end
    end
    return
  end

  _UpdateTrackedSpellIcon(
    self,
    self.secondary,
    self.secondaryResourceConfig,
    self.secondaryUsesCustom
  )
end

local function _TrimSecondarySegments(self, keepCount)
  if not self.secondarySegments then
    return
  end

  self._puiSecondaryActiveSegmentCount = keepCount

  for i = keepCount + 1, #self.secondarySegments do
    local seg = self.secondarySegments[i]
    if seg then
      seg:Hide()
      if seg.bg then
        seg.bg:Hide()
      end
      if seg._puiBg then
        seg._puiBg:Hide()
      end
      if seg.glow then
        seg.glow:SetAlpha(0)
        seg.glow:Hide()
      end
      if seg._timeText then
        if seg._puiEssenceTextBinding then
          seg._puiEssenceTextBinding:Disable()
        end
        seg._timeText:SetText("")
        seg._timeText:Hide()
      end
    end
  end
end

local function _GetSecondaryBuildMetrics(self, bar, profile, segmentCount)
  local w = bar:GetWidth()
  if not w or w <= 0 then
    w = ((profile.size and profile.size.width) or 250) - (_GetSecondaryBorderThickness(self) * 2)
  end
  if w < 1 then
    w = 1
  end

  local inset = _GetSecondaryBorderThickness(self)
  local h = bar:GetHeight()
  if not h or h <= 0 then
    h = ((self.secondaryResourceConfig.height or 15) - (inset * 2))
  end
  h = Pixel.Round(h)
  if h < 1 then
    h = 1
  end

  local spacing = 0
  local totalSpacing = spacing * (segmentCount - 1)
  local usableWidth = w - totalSpacing
  if usableWidth < 0 then
    usableWidth = 0
  end

  local segW = usableWidth / segmentCount
  return w, h, spacing, segW
end



local function _EnsureGenericSecondarySegment(self, bar, index, texPath)
  self.secondarySegments = self.secondarySegments or {}
  local inactiveAlpha = _GetSecondaryInactiveAlpha(self)

  local seg = self.secondarySegments[index]
  if not seg then
    seg = CreateFrame("StatusBar", nil, bar, "BackdropTemplate")
    self.secondarySegments[index] = seg
  elseif seg:GetParent() ~= bar then
    seg:SetParent(bar)
  end

  if texPath and seg.SetStatusBarTexture then
    seg:SetStatusBarTexture(texPath)
  else
    seg:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  end

  if not seg._puiBg then
    local bg = seg:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(seg)
    seg._puiBg = bg
  end
  seg._puiBg:SetAllPoints(seg)
  if texPath then
    seg._puiBg:SetTexture(texPath)
  else
    seg._puiBg:SetColorTexture(1, 1, 1, 1)
  end
  seg._puiBg:SetAlpha(inactiveAlpha)
  seg._puiBg:Show()

  if seg.bg then
    seg.bg:Hide()
  end

  if seg.glow then
    seg.glow:SetAlpha(0)
    seg.glow:Hide()
  end

  if seg._timeText then
    seg._timeText:SetText("")
    seg._timeText:Hide()
  end

  seg:SetStatusBarColor(1, 1, 1, 1)
  seg:Show()
  return seg
end

local function _EnsureSecondaryStatusBar(self, bar, points, texPath)
  local statusBar = self.secondaryStatusBar
  if not statusBar then
    statusBar = CreateFrame("StatusBar", nil, bar, "BackdropTemplate")
    self.secondaryStatusBar = statusBar
  elseif statusBar:GetParent() ~= bar then
    statusBar:SetParent(bar)
  end

  statusBar:ClearAllPoints()
  statusBar:SetAllPoints(bar)
  statusBar:SetMinMaxValues(0, points)
  statusBar:SetValue(0)
  statusBar._puiLastMaxV = nil
  statusBar._puiLastCurV = nil
  statusBar._puiLastColorP = nil

  if texPath then
    statusBar:SetStatusBarTexture(texPath)
  else
    Theme.SkinStatusBar(statusBar, { role = "secondary" })
  end

  if not statusBar._puiBg then
    local bg = statusBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(statusBar)
    statusBar._puiBg = bg
  end
  statusBar._puiBg:SetAllPoints(statusBar)
  if texPath then
    statusBar._puiBg:SetTexture(texPath)
    statusBar._puiBg:SetAlpha(_GetSecondaryInactiveAlpha(self))
  else
    statusBar._puiBg:SetColorTexture(0, 0, 0, 0.45)
  end

  statusBar:SetStatusBarColor(1, 1, 1, 1)
  statusBar:Show()

  return statusBar
end

local function _PrepareSecondaryBuild(self, buildMode, segmentCount, dividerCount)
  local profile = self.db.profile
  local secCfg = self.secondaryResourceConfig
  local buildKey = _GetSecondaryStructureSignature(
    self,
    buildMode,
    segmentCount,
    dividerCount,
    secCfg,
    profile
  )

  self._puiSecondaryBuildMode = buildMode

  if self._puiSecondaryBuildKey == buildKey
    and _CanReuseSecondaryStructure(self, buildMode, segmentCount)
  then
    self.secondary:Show()
    return nil, nil, nil, nil, true
  end

  self._puiSecondaryBuildKey = buildKey
  _ClearSecondaryStructure(self)

  local textureKey = _ResolveSecondaryTextureKey(self, secCfg)
  local texturePath = _FetchStatusbarTexture(textureKey)
  local content = _GetSecondaryContentFrame(self) or self.secondary
  content:SetAlpha(1)
  local bar = _EnsureSecondaryBuildBar(self, content)
  local overlay = _EnsureSecondaryTextOverlay(bar)

  _EnsureSecondaryTexts(bar, overlay)
  self._puiSecFontsDirty = true

  return profile, secCfg, bar, texturePath, false
end

local function _BuildSegmented(self, segmentCount, dividerCount, decorateSegment)
  if segmentCount < 1 then
    _ClearSecondaryStructure(self)
    self.secondary:Hide()
    return
  end

  local profile, secCfg, bar, texturePath, reused = _PrepareSecondaryBuild(
    self,
    "SEGMENTED",
    segmentCount,
    dividerCount or segmentCount
  )
  if reused then
    return
  end

  local width, height, spacing, segmentWidth = _GetSecondaryBuildMetrics(
    self,
    bar,
    profile,
    segmentCount
  )

  self.secondarySegments = self.secondarySegments or {}

  local interpolation = Enum.StatusBarInterpolation.ExponentialEaseOut

  self._puiDiscreteLastCount = nil
  self._puiDiscreteLastFull = nil
  self._puiDiscreteLastFrac = nil
  self._puiDiscreteLastColorP = nil
  self._puiDiscreteLastInactiveAlpha = nil

  for i = 1, segmentCount do
    local segment = _EnsureGenericSecondarySegment(self, bar, i, texturePath)
    segment:SetSize(segmentWidth, height)
    segment:ClearAllPoints()

    if i == 1 then
      segment:SetPoint("LEFT", bar, "LEFT", 0, 0)
    else
      segment:SetPoint("LEFT", self.secondarySegments[i - 1], "RIGHT", spacing, 0)
    end

    segment:SetMinMaxValues(0, 1, interpolation)
    segment:SetValue(0, interpolation)
    segment._puiMinMaxSet = true
    segment._puiLastColorP = nil
    segment._puiLastTargetV = nil
    segment._puiLastTargetA = nil

    if decorateSegment then
      decorateSegment(self, segment, texturePath)
    end

    segment:Show()
  end

  self._puiSecondaryActiveSegmentCount = segmentCount
  _TrimSecondarySegments(self, segmentCount)
  _ApplySecondaryDividers(self, bar, secCfg, dividerCount or segmentCount, width, true, 30)
  self.secondary:Show()
end

local function _BuildContinuous(self, maximum, dividerCount)
  if maximum <= 0 then
    _ClearSecondaryStructure(self)
    self.secondary:Hide()
    return
  end

  local profile, secCfg, bar, texturePath, reused = _PrepareSecondaryBuild(
    self,
    "CONTINUOUS",
    0,
    dividerCount or 0
  )
  if reused then
    return
  end

  local statusBar = _EnsureSecondaryStatusBar(self, bar, maximum, texturePath)
  self.secondaryStatusBar = statusBar

  if dividerCount and dividerCount > 1 then
    local width = statusBar:GetWidth()
    if not width or width <= 0 then
      width = profile.size.width - (_GetSecondaryBorderThickness(self) * 2)
    end
    if width < 1 then width = 1 end

    _ApplySecondaryDividers(self, bar, secCfg, dividerCount, width, false, 30)
  else
    _HideSecondaryDividerSet(self)
  end

  self.secondary:Show()
end


local function _EnsureSecondaryContainerBox(self)
  if not self or not self.secondary or not self.secondary.GetFrameLevel then return end

  local barFrame = _GetTrackedResourceBarFrame(
    self.secondary,
    self.secondaryResourceConfig,
    self.secondaryUsesCustom
  )
  local box = self._puiSecondaryBox
  if not box then
    box = barFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
    box:SetAllPoints(barFrame)
    self._puiSecondaryBox = box
  end

  local border = self._puiSecondaryBorder
  if not border then
    border = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    border:EnableMouse(false)
    self._puiSecondaryBorder = border
  end

  if box._puiAnchorParent ~= barFrame then
    box._puiAnchorParent = barFrame
    box:ClearAllPoints()
    box:SetAllPoints(barFrame)
  end

  if border._puiAnchorParent ~= barFrame then
    border._puiAnchorParent = barFrame
    border:SetParent(barFrame)
    border:ClearAllPoints()
    border:SetAllPoints(barFrame)
  end

  local lvl = barFrame:GetFrameLevel() or 1

  local borderLevel = lvl + 20
  if border._puiLastLevel ~= borderLevel then
    border._puiLastLevel = borderLevel
    border:SetFrameLevel(borderLevel)
  end

  local config = self.secondaryResourceConfig
  local st = config.style

  do
    local c = st and st.bgColor or Theme.GetColors().background
    local r = c[1] or c.r or 0
    local g = c[2] or c.g or 0
    local b = c[3] or c.b or 0
    local a = c[4] or c.a or 0.65

    local resolvedBorderColor = self:GetBarBorderColor(st)

    local bcr = tonumber(resolvedBorderColor[1] or resolvedBorderColor.r) or 0.20
    local bcg = tonumber(resolvedBorderColor[2] or resolvedBorderColor.g) or 0.20
    local bcb = tonumber(resolvedBorderColor[3] or resolvedBorderColor.b) or 0.24
    local bca = tonumber(resolvedBorderColor[4] or resolvedBorderColor.a) or 1.00

    local pr = math.floor(r * 1000 + 0.5)
    local pg = math.floor(g * 1000 + 0.5)
    local pb = math.floor(b * 1000 + 0.5)
    local pa = math.floor(a * 1000 + 0.5)
    if pr < 0 then pr = 0 elseif pr > 1000 then pr = 1000 end
    if pg < 0 then pg = 0 elseif pg > 1000 then pg = 1000 end
    if pb < 0 then pb = 0 elseif pb > 1000 then pb = 1000 end
    if pa < 0 then pa = 0 elseif pa > 1000 then pa = 1000 end
    local bgP = pr * 1000000000 + pg * 1000000 + pb * 1000 + pa

    local br = math.floor(bcr * 1000 + 0.5)
    local bg = math.floor(bcg * 1000 + 0.5)
    local bb = math.floor(bcb * 1000 + 0.5)
    local ba = math.floor(bca * 1000 + 0.5)
    if br < 0 then br = 0 elseif br > 1000 then br = 1000 end
    if bg < 0 then bg = 0 elseif bg > 1000 then bg = 1000 end
    if bb < 0 then bb = 0 elseif bb > 1000 then bb = 1000 end
    if ba < 0 then ba = 0 elseif ba > 1000 then ba = 1000 end
    local borderP = br * 1000000000 + bg * 1000000 + bb * 1000 + ba

    local thickN = _GetSecondaryBorderThickness(self)

    if box._puiBgP ~= bgP
      or box._puiBorderP ~= borderP
      or box._puiBorderSize ~= thickN
    then
      local oldThickness = box._puiBorderSize

      box._puiBgP = bgP
      box._puiBorderP = borderP
      box._puiBorderSize = thickN

      box:SetColorTexture(r, g, b, a)

      if thickN > 0 then
        self:ApplyBarBorder(border, thickN, resolvedBorderColor)
        border:Show()
      else
        self:ApplyBarBorder(border, 0, nil)
        border:Hide()
      end

      if oldThickness ~= thickN then
        self._puiSecondaryNeedsReflow = true
      end
    end

  end

  box:Show()
  _GetSecondaryContentFrame(self)
end

local function _ReflowSecondaryGeometry(self)
  if not self or not self.secondary then
    return
  end

  local content = _GetSecondaryContentFrame(self)
  if not content then
    return
  end

  local profile = self.db and self.db.profile or {}
  local config = self.secondaryResourceConfig
  local inset = _GetSecondaryBorderThickness(self)

  local w = content:GetWidth()
  if not w or w <= 0 then
    w = (config.width or profile.size.width or 250) - (inset * 2)
  end
  if w < 1 then w = 1 end

  local h = content:GetHeight()
  if not h or h <= 0 then
    h = (config.height or 15) - (inset * 2)
  end
  h = Pixel.Round(h)
  if h < 1 then
    h = 1
  end

  local pw = math.floor(w * 100 + 0.5)
  local ph = math.floor(h * 100 + 0.5)

  if not self._puiSecondaryNeedsReflow
    and self._puiSecondaryLayoutW == pw
    and self._puiSecondaryLayoutH == ph
    and self._puiSecondaryLayoutInset == inset
  then
    return
  end

  self._puiSecondaryLayoutW = pw
  self._puiSecondaryLayoutH = ph
  self._puiSecondaryLayoutInset = inset
  self._puiSecondaryNeedsReflow = false

  if self.secondaryBar then
    if self.secondaryBar:GetParent() ~= content then
      self.secondaryBar:SetParent(content)
    end
    self.secondaryBar:ClearAllPoints()
    self.secondaryBar:SetAllPoints(content)
  end

  if self.secondaryStatusBar then
    local parent = self.secondaryBar or content
    if self.secondaryStatusBar:GetParent() ~= parent then
      self.secondaryStatusBar:SetParent(parent)
    end
    self.secondaryStatusBar:ClearAllPoints()
    self.secondaryStatusBar:SetAllPoints(parent)
  end

  local activeSegmentCount = self._puiSecondaryActiveSegmentCount or 0
  if self.secondarySegments and activeSegmentCount > 0 then
    local parent = self.secondaryBar or content
    local ww = Pixel.Round(w)
    if ww < 1 then ww = 1 end

    local count = activeSegmentCount
    local spacing = 0

    local totalSpacing = spacing * (count - 1)
    local usableWidth = ww - totalSpacing
    if usableWidth < 0 then usableWidth = 0 end

    local baseW = math.floor(usableWidth / count)
    local remainder = usableWidth - (baseW * count)

    for i = 1, count do
      local seg = self.secondarySegments[i]
      if seg:GetParent() ~= parent then
        seg:SetParent(parent)
      end
      seg:ClearAllPoints()

      local thisW = baseW
      if remainder > 0 and i <= remainder then
        thisW = thisW + 1
      end

      seg:SetSize(thisW, h)

      if i == 1 then
        seg:SetPoint("LEFT", parent, "LEFT", 0, 0)
      else
        seg:SetPoint("LEFT", self.secondarySegments[i - 1], "RIGHT", spacing, 0)
      end
    end
  end



  if self.secondaryDividerFrame and self.secondaryDividers then
    local secCfg = self.secondaryResourceConfig
    if secCfg.showDividers == false then
      _HideSecondaryDividerSet(self)
    else
      local parent = self.secondaryBar or content
      if self.secondaryDividerFrame:GetParent() ~= parent then
        self.secondaryDividerFrame:SetParent(parent)
      end

      self.secondaryDividerFrame:ClearAllPoints()
      self.secondaryDividerFrame:SetAllPoints(parent)
      self.secondaryDividerFrame:SetFrameStrata(parent:GetFrameStrata())
      self.secondaryDividerFrame:SetFrameLevel(parent:GetFrameLevel() + 30)

      local dividerCount = self._puiSecondaryActiveDividerCount or 0
      local segments = dividerCount + 1
      if segments > 1 then
        local dividerW = Secondary.GetSecondaryDividerSize(secCfg)
        local dividerColor = _ResolveSecondaryDividerColor(secCfg)
        local ww = Pixel.Round(parent:GetWidth() or 0)
        if ww < 1 then
          ww = Pixel.Round(w)
        end
        if ww < 1 then ww = 1 end

        local useSegAnchors = self.secondarySegments
          and #self.secondarySegments >= segments

        for i = 1, dividerCount do
          local divider = self.secondaryDividers[i]
          divider:SetColorTexture(dividerColor.r, dividerColor.g, dividerColor.b, dividerColor.a)
          divider:SetDrawLayer("OVERLAY", 7)
          divider:ClearAllPoints()
          divider:SetWidth(dividerW)
          divider:SetPoint("TOP", self.secondaryDividerFrame, "TOP", 0, 0)
          divider:SetPoint("BOTTOM", self.secondaryDividerFrame, "BOTTOM", 0, 0)

          if useSegAnchors and self.secondarySegments[i] then
            divider:SetPoint("LEFT", self.secondarySegments[i], "RIGHT", -(dividerW / 2), 0)
          else
            local xPos = (ww * i / segments) - dividerW / 2
            divider:SetPoint("LEFT", self.secondaryDividerFrame, "LEFT", xPos, 0)
          end
        end

      end
    end
  end
end

local function _ApplySecondaryAppearance(self)
  _UpdateTrackedSpellIcons(self)
  _EnsureSecondaryContainerBox(self)
  _ReflowSecondaryGeometry(self)
end


function Secondary.ApplyResourceFont(self, fs, config)
  local cfg = config.font
  local fontPath, fontFlags = self:ResolveIconTextFont()
  local fontSize = tonumber(cfg.size) or 14

  if cfg.useGlobalFont ~= true and type(cfg.font) == "string" and cfg.font ~= "" and cfg.font ~= "GLOBAL" then
    local customPath = LSM:Fetch(LSM.MediaType.FONT, cfg.font, true)
    if type(customPath) == "string" and customPath ~= "" then
      fontPath = customPath
    end
  end

  if type(cfg.flags) == "string" then
    if cfg.flags == "NONE" or cfg.flags == "" then
      fontFlags = ""
    else
      fontFlags = cfg.flags
    end
  end

  local appliedKey = tostring(fontPath) .. "|" .. tostring(fontFlags) .. "|" .. tostring(fontSize)
  if fs._puiFontAppliedKey ~= appliedKey then
    fs._puiFontAppliedKey = appliedKey
    fs:SetFont(fontPath, fontSize, fontFlags)
  end
end

local function _ShouldShowApplicationCountdown(config)
  local text = config and config.text
  return config ~= nil
    and config.showApplicationsRemaining == true
    and (tonumber(config.applicationCountdownMax) or 0) > 0
    and text ~= nil
    and text.showNumber ~= false
    and text.mode ~= "HIDE"
end

local function _FormatApplicationCountdown(config, remaining)
  local maximum = tonumber(config and config.applicationCountdownMax) or 0
  local mode = config and config.text and config.text.mode or "CUR"

  if mode == "BOTH" then
    return tostring(remaining) .. " / " .. tostring(maximum)
  end

  return tostring(remaining)
end

local function _FormatSecondaryText(self, current, maximum, percentage, displayCurrent, displayMaximum)
  local cfg = self.secondaryResourceConfig.text
  local mode = cfg.mode or "CUR"
  local showNumber = cfg.showNumber ~= false
  local cache = self._puiSecondaryTextFormatCache

  if not cache then
    cache = {}
    self._puiSecondaryTextFormatCache = cache
  end

  if cache.mode == mode
    and cache.showNumber == showNumber
    and cache.current == current
    and cache.maximum == maximum
    and cache.percentage == percentage
    and cache.displayCurrent == displayCurrent
    and cache.displayMaximum == displayMaximum
  then
    return cache.value, cache.shouldShow
  end

  cache.mode = mode
  cache.showNumber = showNumber
  cache.current = current
  cache.maximum = maximum
  cache.percentage = percentage
  cache.displayCurrent = displayCurrent
  cache.displayMaximum = displayMaximum

  if not showNumber or mode == "HIDE" then
    cache.value = nil
    cache.shouldShow = false
    return nil, false
  end

  local currentValue = displayCurrent
  if currentValue == nil then
    currentValue = current
  end

  local maximumValue = displayMaximum
  if maximumValue == nil then
    maximumValue = maximum
  end

  local value
  if mode == "BOTH" then
    value = tostring(currentValue or 0) .. " / " .. tostring(maximumValue or 0)
  elseif mode == "CURP" or mode == "PCT" then
    local percentageValue = percentage
    if percentageValue == nil and maximum and maximum > 0 then
      percentageValue = current / maximum * 100
    end

    local percentageText = tostring(math.floor((tonumber(percentageValue) or 0) + 0.5)) .. "%"
    if mode == "CURP" then
      value = tostring(currentValue or 0) .. " / " .. percentageText
    else
      value = percentageText
    end
  else
    value = tostring(currentValue or 0)
  end

  cache.value = value
  cache.shouldShow = true
  return value, true
end


function Secondary.ResolveResourceColor(config, definition)
  local useCustom = config.useCustomColor == true
  local useBlizz = config.useBlizzardPowerColor == true
  local useClass = config.useClassColor == true
  local colorTbl = config.customColor
  local r, g, b, a = 1, 1, 1, 1
  local token = definition.colorToken or definition.token

  if useCustom and type(colorTbl) == "table" then
    r = tonumber(colorTbl[1]) or 1
    g = tonumber(colorTbl[2]) or 1
    b = tonumber(colorTbl[3]) or 1
    a = tonumber(colorTbl[4]) or 1
  elseif useClass then
    local color = RAID_CLASS_COLORS[PLAYER_CLASS]
    r, g, b = color.r, color.g, color.b
  elseif useBlizz then
    local color = PowerBarColor[token]
    if color then
      r, g, b, a = color.r, color.g, color.b, color.a or a
    else
      local fallback = config.defaultColor or definition.defaultColor or { 1, 1, 1, 1 }
      r = tonumber(fallback[1] or fallback.r) or 1
      g = tonumber(fallback[2] or fallback.g) or 1
      b = tonumber(fallback[3] or fallback.b) or 1
      a = tonumber(fallback[4] or fallback.a) or 1
    end
  end

  return r, g, b, a, useCustom, useBlizz, useClass
end

local function _PackResourceColor(r, g, b, a)
  local pr = math.floor((tonumber(r) or 1) * 1000 + 0.5)
  local pg = math.floor((tonumber(g) or 1) * 1000 + 0.5)
  local pb = math.floor((tonumber(b) or 1) * 1000 + 0.5)
  local pa = math.floor((tonumber(a) or 1) * 1000 + 0.5)

  if pr < 0 then pr = 0 elseif pr > 1000 then pr = 1000 end
  if pg < 0 then pg = 0 elseif pg > 1000 then pg = 1000 end
  if pb < 0 then pb = 0 elseif pb > 1000 then pb = 1000 end
  if pa < 0 then pa = 0 elseif pa > 1000 then pa = 1000 end

  return pr * 1000000000 + pg * 1000000 + pb * 1000 + pa
end

local function _ResolveSecondaryColorConfig(self)
  if self._puiSecColorDirty ~= true and self._puiSecColorR ~= nil then
    return self._puiSecColorR, self._puiSecColorG, self._puiSecColorB, self._puiSecColorA
  end

  local config = self.secondaryResourceConfig
  local definition = self.secondaryDef
  local r, g, b, a, useCustom, useBlizz, useClass =
    Secondary.ResolveResourceColor(config, definition)

  self._puiSecColorDirty = false
  self._puiSecColorR = r
  self._puiSecColorG = g
  self._puiSecColorB = b
  self._puiSecColorA = a

  local packedResolved = _PackResourceColor(r, g, b, a)

  if useCustom then packedResolved = packedResolved + 2000000000000 end
  if useBlizz then packedResolved = packedResolved + 4000000000000 end
  if useClass then packedResolved = packedResolved + 8000000000000 end

  self._puiSecColorKey = packedResolved
  return r, g, b, a
end




local function _ThresholdMatches(mode, value, threshold)
  if mode == "BELOW" then
    return value < threshold
  elseif mode == "AT_OR_ABOVE" then
    return value >= threshold
  end

  return false
end

local function _ResolveResourceCueColor(config, current, r, g, b, a)
  if config.supportsNumericCues ~= true
    or current == nil
    or issecretvalue(current)
  then
    return r, g, b, a
  end

  local cues = config.cues
  local threshold = tonumber(cues.desaturateThreshold) or 0
  if not _ThresholdMatches(cues.desaturateMode, current, threshold) then
    return r, g, b, a
  end

  local gray = r * 0.2126 + g * 0.7152 + b * 0.0722
  return gray, gray, gray, a
end

local function _StopResourceGlow(frame, key, style)
  if style == "AUTOCAST" then
    LCG.AutoCastGlow_Stop(frame, key)
  elseif style == "PROC" then
    LCG.ProcGlow_Stop(frame, key)
  else
    LCG.PixelGlow_Stop(frame, key)
  end
end

local function _SetResourceGlow(frame, key, enabled, glowType, color)
  frame._puiResourceGlowState = frame._puiResourceGlowState or {}
  local states = frame._puiResourceGlowState
  local state = states[key]

  if not enabled then
    if state and state.active then
      _StopResourceGlow(frame, key, state.style)
      state.active = false
    end
    return
  end

  local style = glowType or "PIXEL"
  local glowColor = color
  local r = glowColor and glowColor[1] or 1
  local g = glowColor and glowColor[2] or 1
  local b = glowColor and glowColor[3] or 1
  local a = glowColor and glowColor[4] or 1

  if state
    and state.active
    and state.style == style
    and state.r == r
    and state.g == g
    and state.b == b
    and state.a == a
  then
    return
  end

  if not state then
    state = {}
    states[key] = state
  elseif state.active then
    _StopResourceGlow(frame, key, state.style)
    state.active = false
  end

  if not glowColor then
    glowColor = { r, g, b, a }
  end

  if style == "AUTOCAST" then
    LCG.AutoCastGlow_Start(frame, glowColor, 8, 0.25, 1, 0, 0, key, 8)
  elseif style == "PROC" then
    LCG.ProcGlow_Start(frame, {
      key = key,
      color = glowColor,
      startAnim = true,
      xOffset = 0,
      yOffset = 0,
      duration = 0.7,
      frameLevel = 8,
    })
  else
    LCG.PixelGlow_Start(frame, glowColor, 8, 0.25, nil, 2, 0, 0, true, key, 8)
  end

  state.active = true
  state.style = style
  state.r = r
  state.g = g
  state.b = b
  state.a = a
end

local function _UpdateResourceThresholdCue(frame, config, current)
  local cues = config.cues
  local active = false

  if config.supportsNumericCues
    and current ~= nil
    and not issecretvalue(current)
  then
    active = _ThresholdMatches(
      cues.glowMode,
      current,
      tonumber(cues.glowThreshold) or 0
    )
  end

  _SetResourceGlow(
    frame,
    config.thresholdGlowKey,
    active,
    cues.glowType,
    cues.glowColor
  )
end


local function _ConfigureResourceBuffCountdown(track)
  local owner = track.owner
  local button = track.button
  local config = track.config
  local shown = _ShouldShowApplicationCountdown(config)
  local barFrame = track.anchorFrame
  local inset = owner:GetBarBorderThickness(config.style, barFrame)

  if not track.countdownCover then
    track.countdownCover = button:CreateTexture(nil, "BACKGROUND", nil, 7)
  end

  local background = config.style.bgColor or { 0, 0, 0, 0.65 }
  local cover = track.countdownCover
  if track.countdownInset ~= inset then
    track.countdownInset = inset
    cover:ClearAllPoints()
    cover:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    cover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
  end
  cover:SetColorTexture(
    background[1] or 0,
    background[2] or 0,
    background[3] or 0,
    1
  )
  cover:SetShown(shown)

  if not track.countdownText then
    track.countdownText = button:CreateFontString(nil, "OVERLAY")
    track.countdownText:SetPoint("CENTER", button, "CENTER", 0, 0)
  end

  local text = track.countdownText
  local sourceText = Secondary.PrepareSecondaryText(owner, owner.secondaryBar)
  text:SetTextColor(sourceText:GetTextColor())
  text:SetShadowColor(sourceText:GetShadowColor())
  text:SetShadowOffset(sourceText:GetShadowOffset())
  Secondary.ApplyResourceFont(owner, text, config)
  text:SetText(_FormatApplicationCountdown(config, 0))
  text:SetShown(shown)
end

local function _ConfigureResourceBuffCueButton(track, initializing)
  if initializing ~= true and C_Secrets.ShouldAurasBeSecret() == true then
    return false
  end

  _ConfigureResourceBuffCountdown(track)

  local color = track.config.cues.buffGlowColor or { 0.25, 0.75, 1, 1 }
  local width = math.max(1, track.anchorFrame:GetWidth())
  local height = math.max(1, track.anchorFrame:GetHeight())
  if initializing == true then
    track.cueGlow = AuraWidget.CreateSlotGlow(
      track.button,
      width,
      height,
      "PIXEL",
      color,
      { pixelThickness = 2 }
    )
  elseif track.cueGlow then
    AuraWidget.ConfigureSlotGlow(
      track.cueGlow,
      width,
      height,
      "PIXEL",
      color,
      { pixelThickness = 2 }
    )
  end
  return true
end

local function _DisableResourceBuffCueTrack(track)
  if track and track.auraSlot then
    AuraSlotDriver:SetSlotActive(track.auraSlot, false)
  end
end

local function _ConfigureResourceBuffCue(self, frame, config)
  local spellID = tonumber(config.cues.buffGlowSpellID) or 0

  self._puiSecondaryBuffCueTracks = self._puiSecondaryBuffCueTracks or {}
  local tracks = self._puiSecondaryBuffCueTracks
  local track = tracks[config.resourceKey]

  if spellID <= 0 then
    _DisableResourceBuffCueTrack(track)
    return
  end

  if not track then
    track = {
      key = "pui_prd_buff_cue_" .. config.resourceKey,
    }
    tracks[config.resourceKey] = track
  end

  track.owner = self
  track.frame = frame
  track.config = config
  track.spellID = spellID
  track.anchorFrame = _GetTrackedResourceBarFrame(frame, config, true)

  local styleApplied = true
  if not track.auraSlot then
    track.auraSlot = AuraSlotDriver:CreateSlot("player", "HELPFUL|PLAYER", {
      candidateFilters = {
        includeSpellIDs = {
          [spellID] = true,
        },
      },
      initializeFrame = function(button)
        track.button = button
        button:ClearAllPoints()
        button:SetAllPoints(track.anchorFrame)
        button:SetFrameStrata(track.anchorFrame:GetFrameStrata())
        button:SetFrameLevel(track.anchorFrame:GetFrameLevel() + 6)
        button:SetAlpha(1)
        button:SetMouseMotionEnabled(false)

        _ConfigureResourceBuffCueButton(track, true)
      end,
    })
    track.candidateSpellID = spellID
  else
    if track.candidateSpellID ~= spellID or track.auraSlot.active ~= true then
      AuraSlotDriver:SetSlotCandidates(track.auraSlot, {
        includeSpellIDs = {
          [spellID] = true,
        },
      })
      track.candidateSpellID = spellID
    end

    styleApplied = _ConfigureResourceBuffCueButton(track, false)
  end

  AuraSlotDriver:SetSlotActive(track.auraSlot, true)
  self._puiSecondaryCueStylePending = styleApplied and nil or true
end

local function _StopResourceCues(self, frame, config)
  if not frame or not config then
    return
  end

  _SetResourceGlow(frame, config.thresholdGlowKey, false)

  local tracks = self._puiSecondaryBuffCueTracks
  if tracks then
    _DisableResourceBuffCueTrack(tracks[config.resourceKey])
  end
end

local function _EnsureSecondaryGlowPulse(obj, glowKey)
  local glow = obj and obj[glowKey]
  if not glow then
    return nil, nil
  end

  local group = obj._puiGlowPulseGroup
  local animation = obj._puiGlowPulseAnimation
  if not group then
    group = glow:CreateAnimationGroup()
    animation = group:CreateAnimation("Alpha")
    animation:SetOrder(1)
    animation:SetSmoothing("OUT")

    group:SetScript("OnFinished", function()
      glow:SetAlpha(obj._puiGlowBaseAlpha or 0)
    end)

    obj._puiGlowPulseGroup = group
    obj._puiGlowPulseAnimation = animation
  end

  return group, animation
end

local function _PlaySecondaryGlowPulse(obj, glowKey, strength)
  local glow = obj and obj[glowKey]
  local group, animation = _EnsureSecondaryGlowPulse(obj, glowKey)
  if not glow or not group or not animation then
    return
  end

  local baseAlpha = obj._puiGlowBaseAlpha or 0
  local peakAlpha = baseAlpha + (tonumber(strength) or 0.6)
  if peakAlpha > 1 then
    peakAlpha = 1
  end

  group:Stop()
  animation:SetDuration(obj._puiGlowPulseDuration or 0.25)
  animation:SetFromAlpha(peakAlpha)
  animation:SetToAlpha(baseAlpha)
  glow:SetAlpha(peakAlpha)
  group:Play()
end


local function _PrepareSecondaryText(self, bar)
  local text = bar._puiText

  if self._puiSecFontsDirty then
    self._puiSecFontsDirty = false
    Secondary.ApplyResourceFont(self, text, self.secondaryResourceConfig)
  end

  return text
end

local function _SetSecondaryCenterText(text, value, shouldShow)
  if shouldShow and value ~= nil and value ~= "" then
    if text._puiLastValue ~= value then
      text._puiLastValue = value
      text:SetText(value)
    end
    if text._puiShown ~= true then
      text._puiShown = true
      text:Show()
    end
  else
    if text._puiLastValue ~= "" then
      text._puiLastValue = ""
      text:SetText("")
    end
    if text._puiShown ~= false then
      text._puiShown = false
      text:Hide()
    end
  end
end



local function _ApplyDiscreteSecondaryBars(self, cur, maxV, r, g, b, a)
  local config = self.secondaryResourceConfig
  r, g, b, a = _ResolveResourceCueColor(config, cur, r, g, b, a)
  _UpdateResourceThresholdCue(self.secondary, config, cur)

  local colorKey = _PackResourceColor(r, g, b, a)

  if self._puiSecondaryBuildMode == "SEGMENTED" then
    local segments = self.secondarySegments
    local count = self._puiSecondaryActiveSegmentCount or 0
    local fullPoints = math.floor(cur + 0.0001)
    local frac = cur - fullPoints

    if frac < 0 then frac = 0 end
    if frac > 1 then frac = 1 end

    local packedFrac = math.floor(frac * 1000 + 0.5)
    local inactiveAlpha = self._puiSecInactiveAlpha

    if self._puiDiscreteLastCount == count
      and self._puiDiscreteLastFull == fullPoints
      and self._puiDiscreteLastFrac == packedFrac
      and self._puiDiscreteLastColorP == colorKey
      and self._puiDiscreteLastInactiveAlpha == inactiveAlpha
    then
      return
    end

    self._puiDiscreteLastCount = count
    self._puiDiscreteLastFull = fullPoints
    self._puiDiscreteLastFrac = packedFrac
    self._puiDiscreteLastColorP = colorKey
    self._puiDiscreteLastInactiveAlpha = inactiveAlpha

    for i = 1, count do
      local segment = segments[i]
      local value = 0

      if i <= fullPoints then
        value = 1
      elseif i == fullPoints + 1 then
        value = frac
      end

      if segment._puiLastColorP ~= colorKey then
        segment._puiLastColorP = colorKey
        segment:SetStatusBarColor(r, g, b, a)
      end

      if segment._puiLastTargetV ~= value then
        segment._puiLastTargetV = value
        segment:SetValue(value)
      end

      local alpha = value > 0 and 1 or inactiveAlpha
      if segment._puiLastTargetA ~= alpha then
        segment._puiLastTargetA = alpha
        segment:SetAlpha(alpha)
      end
    end

    return
  end

  local statusBar = self.secondaryStatusBar
  if statusBar._puiLastMaxV ~= maxV then
    statusBar._puiLastMaxV = maxV
    statusBar:SetMinMaxValues(0, maxV)
  end
  if statusBar._puiLastCurV ~= cur then
    statusBar._puiLastCurV = cur
    statusBar:SetValue(cur)
  end
  if statusBar._puiLastColorP ~= colorKey then
    statusBar._puiLastColorP = colorKey
    statusBar:SetStatusBarColor(r, g, b, a)
  end
end


  _CaptureBlizzardDisplayState = P:Def("_CaptureBlizzardDisplayState", _CaptureBlizzardDisplayState)
  M.SetBlizzardRootGhosted = P:Def("SetBlizzardRootGhosted", M.SetBlizzardRootGhosted)
  M.SetBlizzardSecondaryShown = P:Def("SetBlizzardSecondaryShown", M.SetBlizzardSecondaryShown)
  M.RestoreBlizzardDisplayState = P:Def("RestoreBlizzardDisplayState", M.RestoreBlizzardDisplayState)
  _FetchStatusbarTexture = P:Def("_FetchStatusbarTexture", _FetchStatusbarTexture)
  _ResolveSecondaryTextureKey = P:Def("_ResolveSecondaryTextureKey", _ResolveSecondaryTextureKey)
  _GetSecondaryStructureSignature = P:Def("_GetSecondaryStructureSignature", _GetSecondaryStructureSignature)
  _CanReuseSecondaryStructure = P:Def("_CanReuseSecondaryStructure", _CanReuseSecondaryStructure)
  _ClearSecondaryStructure = P:Def("_ClearSecondaryStructure", _ClearSecondaryStructure)
  _TrackedSpellIconIsShown = P:Def("_TrackedSpellIconIsShown", _TrackedSpellIconIsShown)
  _GetTrackedResourceBarFrame = P:Def("_GetTrackedResourceBarFrame", _GetTrackedResourceBarFrame)
  _UpdateTrackedSpellIcon = P:Def("_UpdateTrackedSpellIcon", _UpdateTrackedSpellIcon)
  _UpdateTrackedSpellIcons = P:Def("_UpdateTrackedSpellIcons", _UpdateTrackedSpellIcons)
  _GetSecondaryBorderThickness = P:Def("_GetSecondaryBorderThickness", _GetSecondaryBorderThickness)
  _GetSecondaryContentFrame = P:Def("_GetSecondaryContentFrame", _GetSecondaryContentFrame)
  _EnsureSecondaryBuildBar = P:Def("_EnsureSecondaryBuildBar", _EnsureSecondaryBuildBar)
  _EnsureSecondaryTextOverlay = P:Def("_EnsureSecondaryTextOverlay", _EnsureSecondaryTextOverlay)
  _EnsureSecondaryTexts = P:Def("_EnsureSecondaryTexts", _EnsureSecondaryTexts)
  _GetSecondaryInactiveAlpha = P:Def("_GetSecondaryInactiveAlpha", _GetSecondaryInactiveAlpha)
  Secondary.GetSecondaryDividerSize = P:Def("_GetSecondaryDividerSize", Secondary.GetSecondaryDividerSize)
  _ResolveSecondaryDividerColor = P:Def("_ResolveSecondaryDividerColor", _ResolveSecondaryDividerColor)
  _HideSecondaryDividerSet = P:Def("_HideSecondaryDividerSet", _HideSecondaryDividerSet)
  _EnsureSecondaryDividerFrame = P:Def("_EnsureSecondaryDividerFrame", _EnsureSecondaryDividerFrame)
  _ApplySecondaryDividers = P:Def("_ApplySecondaryDividers", _ApplySecondaryDividers)
  _TrimSecondarySegments = P:Def("_TrimSecondarySegments", _TrimSecondarySegments)
  _GetSecondaryBuildMetrics = P:Def("_GetSecondaryBuildMetrics", _GetSecondaryBuildMetrics)
  _EnsureGenericSecondarySegment = P:Def("_EnsureGenericSecondarySegment", _EnsureGenericSecondarySegment)
  _EnsureSecondaryStatusBar = P:Def("_EnsureSecondaryStatusBar", _EnsureSecondaryStatusBar)
  _PrepareSecondaryBuild = P:Def("_PrepareSecondaryBuild", _PrepareSecondaryBuild)
  _BuildSegmented = P:Def("_BuildSegmented", _BuildSegmented)
  _BuildContinuous = P:Def("_BuildContinuous", _BuildContinuous)
  _EnsureSecondaryContainerBox = P:Def("_EnsureSecondaryContainerBox", _EnsureSecondaryContainerBox)
  _ReflowSecondaryGeometry = P:Def("_ReflowSecondaryGeometry", _ReflowSecondaryGeometry)
  _ApplySecondaryAppearance = P:Def("_ApplySecondaryAppearance", _ApplySecondaryAppearance)
  Secondary.ApplyResourceFont = P:Def("_ApplyResourceFont", Secondary.ApplyResourceFont)
  _ShouldShowApplicationCountdown = P:Def("_ShouldShowApplicationCountdown", _ShouldShowApplicationCountdown)
  _FormatApplicationCountdown = P:Def("_FormatApplicationCountdown", _FormatApplicationCountdown)
  _FormatSecondaryText = P:Def("_FormatSecondaryText", _FormatSecondaryText)
  Secondary.ResolveResourceColor = P:Def("_ResolveResourceColor", Secondary.ResolveResourceColor)
  _PackResourceColor = P:Def("_PackResourceColor", _PackResourceColor)
  _ResolveSecondaryColorConfig = P:Def("_ResolveSecondaryColorConfig", _ResolveSecondaryColorConfig)
  _ThresholdMatches = P:Def("_ThresholdMatches", _ThresholdMatches)
  _ResolveResourceCueColor = P:Def("_ResolveResourceCueColor", _ResolveResourceCueColor)
  _StopResourceGlow = P:Def("_StopResourceGlow", _StopResourceGlow)
  _SetResourceGlow = P:Def("_SetResourceGlow", _SetResourceGlow)
  _UpdateResourceThresholdCue = P:Def("_UpdateResourceThresholdCue", _UpdateResourceThresholdCue)
  _ConfigureResourceBuffCountdown = P:Def("_ConfigureResourceBuffCountdown", _ConfigureResourceBuffCountdown)
  _ConfigureResourceBuffCueButton = P:Def("_ConfigureResourceBuffCueButton", _ConfigureResourceBuffCueButton)
  _DisableResourceBuffCueTrack = P:Def("_DisableResourceBuffCueTrack", _DisableResourceBuffCueTrack)
  _ConfigureResourceBuffCue = P:Def("_ConfigureResourceBuffCue", _ConfigureResourceBuffCue)
  _StopResourceCues = P:Def("_StopResourceCues", _StopResourceCues)
  _EnsureSecondaryGlowPulse = P:Def("_EnsureSecondaryGlowPulse", _EnsureSecondaryGlowPulse)
  _PlaySecondaryGlowPulse = P:Def("_PlaySecondaryGlowPulse", _PlaySecondaryGlowPulse)
  _PrepareSecondaryText = P:Def("_PrepareSecondaryText", _PrepareSecondaryText)
  _SetSecondaryCenterText = P:Def("_SetSecondaryCenterText", _SetSecondaryCenterText)
  _ApplyDiscreteSecondaryBars = P:Def("_ApplyDiscreteSecondaryBars", _ApplyDiscreteSecondaryBars)


Secondary.FetchStatusbarTexture = _FetchStatusbarTexture
Secondary.UpdateTrackedSpellIcons = _UpdateTrackedSpellIcons
Secondary.ApplySecondaryAppearance = _ApplySecondaryAppearance
Secondary.GetSecondaryBorderThickness = _GetSecondaryBorderThickness
Secondary.GetSecondaryContentFrame = _GetSecondaryContentFrame
Secondary.ResolveSecondaryDividerColor = _ResolveSecondaryDividerColor
Secondary.EnsureSecondaryContainerBox = _EnsureSecondaryContainerBox
Secondary.ReflowSecondaryGeometry = _ReflowSecondaryGeometry
Secondary.ShouldShowApplicationCountdown = _ShouldShowApplicationCountdown
Secondary.FormatApplicationCountdown = _FormatApplicationCountdown
Secondary.PackResourceColor = _PackResourceColor
Secondary.ResolveSecondaryColorConfig = _ResolveSecondaryColorConfig
Secondary.ResolveResourceCueColor = _ResolveResourceCueColor
Secondary.UpdateResourceThresholdCue = _UpdateResourceThresholdCue
Secondary.ConfigureResourceBuffCue = _ConfigureResourceBuffCue
Secondary.StopResourceCues = _StopResourceCues
Secondary.GetInactiveAlpha = _GetSecondaryInactiveAlpha
Secondary.FormatSecondaryText = _FormatSecondaryText
Secondary.BuildSegmented = _BuildSegmented
Secondary.BuildContinuous = _BuildContinuous
Secondary.ApplyDiscreteSecondaryBars = _ApplyDiscreteSecondaryBars
Secondary.EnsureSecondaryGlowPulse = _EnsureSecondaryGlowPulse
Secondary.PlaySecondaryGlowPulse = _PlaySecondaryGlowPulse
Secondary.PrepareSecondaryText = _PrepareSecondaryText
Secondary.SetSecondaryCenterText = _SetSecondaryCenterText


