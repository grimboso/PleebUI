-- File: PUI_PRD_Primary.lua


local ADDON_NAME, ns = ...


local Theme             = ns.Theme
local LSM               = ns.LSM
local Presentation      = ns.Presentation
local M                 = ns.Modules.PRD
local Unpack            = unpack
local _PUI_GlobalFontSig, _PUI_GlobalFontPath, _PUI_GlobalFontFlags
local _PUI_PRD_GetNativeBarText
local _PUI_PRD_ApplyNativeTextConfig

-- Keep PleebUI bookkeeping off Blizzard-owned PRD objects; their native power/text paths can receive secret values.
local _PUI_PRD_NativeBarState = setmetatable({}, { __mode = "k" })
local _PUI_PRD_NativeRegionState = setmetatable({}, { __mode = "k" })
local _PUI_PRD_NativeFontState = setmetatable({}, { __mode = "k" })
local _PUI_PRD_NativePresentation = setmetatable({}, { __mode = "k" })
local _PUI_PRD_NativeMouseoverOwner = setmetatable({}, { __mode = "k" })

local function _PUI_PRD_GetBarState(bar)
  local state = _PUI_PRD_NativeBarState[bar]
  if not state then
    state = {}
    _PUI_PRD_NativeBarState[bar] = state
  end
  return state
end

local function _PUI_PRD_GetRegionState(region)
  local state = _PUI_PRD_NativeRegionState[region]
  if not state then
    state = {}
    _PUI_PRD_NativeRegionState[region] = state
  end
  return state
end


local P = ns.Pleebug:DropIn({}, { name = "PRD_Primary" })
local _, PLAYER_CLASS = UnitClass("player")

local function _IsPUI_SecureFrame(f)
  return f and not f:IsForbidden()
end

local GetTime = _G.GetTime

local function _PUI_ShouldApply()
  local prof = M.db and M.db.profile
  if not (prof and prof.enabled) then
    return false
  end

  if not M:IsEnabled() then
    return false
  end

  return true
end

local function _PUI_HealthAvailable()
  local prof = M.db and M.db.profile
  return prof ~= nil
end

local function _PUI_PrimaryEnabled()
  local prof = M.db and M.db.profile
  return prof and prof.hidePrimary ~= true
end

local function _PUI_GetStyleForBackdrop(self, key)
  local prof = self and self.db and self.db.profile
  if not prof then
    return nil
  end

  return self:GetBarAppearance(key == "healthBox" and "health" or "primary").style
end

local function _PUI_ResolveBackdropFillColor(st)
  local c = st and st.bgColor or Theme.GetColors().background
  local r = c[1] or c.r or 0
  local g = c[2] or c.g or 0
  local b = c[3] or c.b or 0
  local a = c[4] or c.a or 0.65
  return r, g, b, a
end


local function _PUI_GetNativeBarOwner(self, role)
  if role == "health" then
    return self.health, "healthBox"
  elseif role == "primary" then
    return self.primary, "primaryBox"
  end

  return nil, nil
end

local function _PUI_ApplyNativeBarGeometry(self, bar, role)
  if not bar then
    return nil
  end

  local owner, key = _PUI_GetNativeBarOwner(self, role)
  if not owner then
    return nil
  end

  local style = _PUI_GetStyleForBackdrop(self, key)
  local inset = self:GetBarBorderThickness(style, owner)

  if bar:GetParent() ~= owner then
    bar:SetParent(owner)
  end

  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", owner, "TOPLEFT", inset, -inset)
  bar:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset, inset)

  return owner
end

local function _PUI_ApplyBackdropStyle(self, target, bg, border, key)
  if not bg or not border or not target then
    return
  end


  local st = _PUI_GetStyleForBackdrop(self, key)
  local r, g, b, a = _PUI_ResolveBackdropFillColor(st)
  local thickness = self:GetBarBorderThickness(st, target)
  local borderColor = self:GetBarBorderColor(st)
  local br = tonumber(borderColor[1] or borderColor.r) or 0.20
  local bgc = tonumber(borderColor[2] or borderColor.g) or 0.20
  local bb = tonumber(borderColor[3] or borderColor.b) or 0.24
  local ba = tonumber(borderColor[4] or borderColor.a) or 1.00

  local prev = bg.__puiStyleVals
  if prev
    and prev.r == r
    and prev.g == g
    and prev.b == b
    and prev.a == a
    and prev.th == thickness
    and prev.br == br
    and prev.bgc == bgc
    and prev.bb == bb
    and prev.ba == ba
  then
    return
  end

  if not prev then
    prev = {}
    bg.__puiStyleVals = prev
  end

  prev.r = r
  prev.g = g
  prev.b = b
  prev.a = a
  prev.th = thickness
  prev.br = br
  prev.bgc = bgc
  prev.bb = bb
  prev.ba = ba

  bg:SetColorTexture(r, g, b, a)
  self:ApplyBarBorder(border, thickness, borderColor)
end

local function _EnsurePUIBackdrop(self, target, key)
  if not target or not target.GetFrameLevel then
    return
  end

  self._puiBackdrops = self._puiBackdrops or {}

  local bg = self._puiBackdrops[key]

  if not bg then
    bg = target:CreateTexture(nil, "BACKGROUND", nil, 0)
    self._puiBackdrops[key] = bg
  end

  bg:ClearAllPoints()
  bg:SetAllPoints(target)

  local lvl = target:GetFrameLevel() or 1

  local border = bg._puiBorderFrame
  if not border then
    border = CreateFrame("Frame", nil, target)
    border:EnableMouse(false)
    bg._puiBorderFrame = border
  elseif border:GetParent() ~= target then
    border:SetParent(target)
  end

  border:ClearAllPoints()
  border:SetAllPoints(target)
  border:SetFrameStrata(target:GetFrameStrata())
  border:SetFrameLevel(lvl + 20)

  _PUI_ApplyBackdropStyle(self, target, bg, border, key)

  bg:Show()
  border:Show()

  return bg
end

local function _PUI_PRD_HidePrimaryTicks(self)
  local overlay = self and self._puiPrimaryTickOverlay
  if overlay then
    overlay:Hide()
  end
end

local function _PUI_PRD_EnsurePrimaryTickOverlay(self)
  local owner = self and self.primary
  if not owner then
    return nil
  end

  local overlay = self._puiPrimaryTickOverlay
  if not overlay then
    overlay = CreateFrame("Frame", nil, owner)
    overlay:EnableMouse(false)
    self._puiPrimaryTickOverlay = overlay
    self._puiPrimaryTickTextures = {}
  elseif overlay:GetParent() ~= owner then
    overlay:SetParent(owner)
  end

  overlay:SetFrameStrata(owner:GetFrameStrata())
  overlay:SetFrameLevel((owner:GetFrameLevel() or 0) + 10)
  return overlay
end

function M:RefreshPrimaryTicks()
  local profile = self.db and self.db.profile
  local owner = self.primary
  local resourceSettings = profile and self:GetPrimaryResourceSettings()
  local tickConfig = resourceSettings and resourceSettings.ticks

  if not profile
    or not owner
    or profile.hidePrimary == true
    or not tickConfig
    or tickConfig.enabled ~= true
    or type(tickConfig.entries) ~= "table"
  then
    _PUI_PRD_HidePrimaryTicks(self)
    return
  end

  local maximum = self:GetPrimaryTickMaximum(tickConfig)
  if not maximum or maximum <= 0 or #tickConfig.entries == 0 then
    _PUI_PRD_HidePrimaryTicks(self)
    return
  end

  local appearance = self:GetBarAppearance("primary")
  local inset = self:GetBarBorderThickness(appearance and appearance.style, owner)
  local width = math.max(0, (owner:GetWidth() or 0) - inset * 2)
  local autoHeight = math.max(1, (owner:GetHeight() or 0) - inset * 2)

  if width <= 0 then
    _PUI_PRD_HidePrimaryTicks(self)
    return
  end

  local overlay = _PUI_PRD_EnsurePrimaryTickOverlay(self)
  if not overlay then
    return
  end

  overlay:ClearAllPoints()
  overlay:SetPoint("TOPLEFT", owner, "TOPLEFT", inset, -inset)
  overlay:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset, inset)

  local textures = self._puiPrimaryTickTextures
  local shown = 0

  for index = 1, #tickConfig.entries do
    local entry = tickConfig.entries[index]
    local value = type(entry) == "table" and tonumber(entry.value) or nil

    if value and value >= 0 and value <= maximum then
      shown = shown + 1

      local tick = textures[shown]
      if not tick then
        tick = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
        textures[shown] = tick
      end

      local tickWidth = ns.Pixel.Round(
        math.max(1, math.min(50, tonumber(entry.width) or 2))
      )
      local configuredHeight = tonumber(entry.height) or 0
      local tickHeight = configuredHeight <= 0
        and autoHeight
        or ns.Pixel.Round(math.max(1, math.min(50, configuredHeight)))
      local color = entry.color or { 1, 1, 1, 1 }

      tick:ClearAllPoints()
      tick:SetSize(tickWidth, tickHeight)
      tick:SetPoint(
        "CENTER",
        overlay,
        "LEFT",
        ns.Pixel.Round(width * (value / maximum)),
        0
      )
      tick:SetColorTexture(
        tonumber(color[1] or color.r) or 1,
        tonumber(color[2] or color.g) or 1,
        tonumber(color[3] or color.b) or 1,
        tonumber(color[4] or color.a) or 1
      )
      tick:Show()
    end
  end

  for index = shown + 1, #textures do
    textures[index]:Hide()
  end

  overlay:SetShown(shown > 0)
end

local function _PUI_PRD_HideTexture(texture)
  if not texture then
    return
  end

  if texture.Hide then
    texture:Hide()
  end
  if texture.SetAlpha then
    texture:SetAlpha(0)
  end
  if texture.SetTexture then
    texture:SetTexture(nil)
  end
end

local function _PUI_PRD_HideKnownNamePlateBorder(border)
  if not border then
    return
  end

  if border.Hide then
    border:Hide()
  end
  if border.SetAlpha then
    border:SetAlpha(0)
  end

  if type(border.Textures) == "table" then
    for i = 1, #border.Textures do
      _PUI_PRD_HideTexture(border.Textures[i])
    end
  end

  _PUI_PRD_HideTexture(border.Top)
  _PUI_PRD_HideTexture(border.Bottom)
  _PUI_PRD_HideTexture(border.Left)
  _PUI_PRD_HideTexture(border.Right)
end

local function _StripPRDOverlayArt(bar)
  if not bar then
    return
  end

  _PUI_PRD_HideKnownNamePlateBorder(bar.Border)
  _PUI_PRD_HideKnownNamePlateBorder(bar.border)
  _PUI_PRD_HideTexture(bar.background)

  local parent = bar.GetParent and bar:GetParent() or nil
  if parent then
    _PUI_PRD_HideKnownNamePlateBorder(parent.Border)
    _PUI_PRD_HideKnownNamePlateBorder(parent.border)
    _PUI_PRD_HideTexture(parent.background)
  end
end

local function _PUI_PRD_HideNativeAnonymousBackground(bar)
  if not bar or not bar.GetRegions then
    return
  end

  local statusTexture = bar.GetStatusBarTexture and bar:GetStatusBarTexture() or nil
  local count = select("#", bar:GetRegions())

  for i = 1, count do
    local region = select(i, bar:GetRegions())

    if region
      and region.SetTexture
      and region ~= statusTexture
      and region ~= bar.myHealPrediction
      and region ~= bar.otherHealPrediction
      and region ~= bar.totalAbsorb
      and region ~= bar.totalAbsorbOverlay
      and region ~= bar.myHealAbsorb
      and region ~= bar.myHealAbsorbLeftShadow
      and region ~= bar.myHealAbsorbRightShadow
      and region ~= bar.overAbsorbGlow
      and region ~= bar.overHealAbsorbGlow
      and region ~= bar.ManaCostPredictionBar
    then
      _PUI_PRD_HideTexture(region)
    end
  end
end

local function _PUI_PRD_GetNativeBarConfig(self, role)
  local profile = self and self.db and self.db.profile
  if not profile then
    return nil
  end

  if role == "health" then
    return profile.health
  elseif role == "primary" then
    if self.__puiEffectivePrimarySkin then
      return self.__puiEffectivePrimarySkin
    end
    return profile.primary
  end

  return nil
end

local function _PUI_PRD_GetClassColor()
  local c = RAID_CLASS_COLORS[PLAYER_CLASS]
  return c.r, c.g, c.b, c.a or 1
end

local function _PUI_PRD_ApplyNativeBarTexture(self, bar, role)
  if not bar then
    return
  end

  local cfg = self:GetBarAppearance(role)

  local key = cfg.texture
  if not key or key == "" then
    key = "Pleebar"
  end

  local tex = LSM:Fetch("statusbar", key, true)
  if tex then
    bar:SetStatusBarTexture(tex)
  end

  local sbtex = bar:GetStatusBarTexture()
  if sbtex then
    sbtex:SetHorizTile(false)
    sbtex:SetVertTile(false)
    if cfg.squareTexture ~= false then
      sbtex:SetTexCoord(0, 1, 0, 1)
    end
    sbtex:SetDrawLayer("ARTWORK", 1)
  end
end

local function _PUI_PRD_ApplyNativeBarColor(bar, cfg)
  if not bar then
    return
  end

  cfg = cfg or {}
  local mode = cfg.colorMode or "DEFAULT"
  local state = _PUI_PRD_GetBarState(bar)

  if not state.defaultStatusBarColor then
    local r, g, b, a = bar:GetStatusBarColor()
    state.defaultStatusBarColor = { r or 1, g or 1, b or 1, a or 1 }
  end

  if mode == "CUSTOM" then
    local c = cfg.customColor or { 1, 1, 1, 1 }
    state.forcedStatusBarColor = true
    bar:SetStatusBarColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
  elseif mode == "CLASS" then
    state.forcedStatusBarColor = true
    bar:SetStatusBarColor(_PUI_PRD_GetClassColor())
  elseif mode == "TEXTURE" then
    state.forcedStatusBarColor = true
    bar:SetStatusBarColor(1, 1, 1, 1)
  elseif state.forcedStatusBarColor and state.defaultStatusBarColor then
    local c = state.defaultStatusBarColor
    state.forcedStatusBarColor = nil
    bar:SetStatusBarColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
  else
    state.forcedStatusBarColor = nil
  end
end

local function _PUI_PRD_SetRegionTexture(region, tex)
  if not region or not tex then
    return
  end

  if region.SetStatusBarTexture then
    region:SetStatusBarTexture(tex)
  elseif region.SetTexture then
    region:SetTexture(tex)
  end

  local sbtex = region.GetStatusBarTexture and region:GetStatusBarTexture() or nil
  if sbtex and sbtex.SetTexCoord then
    sbtex:SetTexCoord(0, 1, 0, 1)
  end
end

local function _PUI_PRD_SetRegionColor(region, r, g, b, a)
  if not region then
    return
  end

  local state = _PUI_PRD_GetRegionState(region)

  if not state.defaultColor then
    if region.GetStatusBarColor then
      local cr, cg, cb, ca = region:GetStatusBarColor()
      state.defaultColor = { cr or 1, cg or 1, cb or 1, ca or 1 }
    elseif region.GetVertexColor then
      local cr, cg, cb, ca = region:GetVertexColor()
      state.defaultColor = { cr or 1, cg or 1, cb or 1, ca or 1 }
    end
  end

  if r then
    state.forcedColor = true
    if region.SetStatusBarColor then
      region:SetStatusBarColor(r, g, b, a)
    elseif region.SetVertexColor then
      region:SetVertexColor(r, g, b, a)
    end
  elseif state.forcedColor and state.defaultColor then
    local c = state.defaultColor
    state.forcedColor = nil
    if region.SetStatusBarColor then
      region:SetStatusBarColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    elseif region.SetVertexColor then
      region:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    end
  else
    state.forcedColor = nil
  end
end

local function _PUI_PRD_GetEffectTint(cfg)
  cfg = cfg or {}
  local mode = cfg.colorMode or "DEFAULT"

  if mode == "CUSTOM" then
    local c = cfg.customColor or { 1, 1, 1, 1 }
    return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
  elseif mode == "CLASS" then
    return _PUI_PRD_GetClassColor()
  elseif mode == "TEXTURE" then
    return 1, 1, 1, 1
  end

  return nil
end

local function _PUI_PRD_ApplyNativeBarEffects(self, bar, role, cfg)
  if not bar then
    return
  end

  cfg = cfg or {}

  local tex = nil
  local key = self:GetBarAppearance(role).texture
  if key and key ~= "" then
    tex = LSM:Fetch("statusbar", key, true)
  end

  local r, g, b, a = _PUI_PRD_GetEffectTint(cfg)
  local regions = nil

  if role == "health" then
    regions = {
      bar.myHealPrediction,
      bar.otherHealPrediction,
      bar.myHealAbsorb,
      bar.totalAbsorb,
    }
  elseif role == "primary" then
    regions = {
      bar.ManaCostPredictionBar,
    }
  end

  if not regions then
    return
  end

  for i = 1, #regions do
    local region = regions[i]
    _PUI_PRD_SetRegionTexture(region, tex)
    _PUI_PRD_SetRegionColor(region, r, g, b, a)
  end
end

local PRDBarPresentation = {}

local function _PUI_PRD_ResolvePresentationFont(config)
  config = config or {}

  local path, flags = M:ResolveIconTextFont()
  local key = config.font

  if config.useGlobalFont ~= true
    and type(key) == "string"
    and key ~= ""
    and key ~= "GLOBAL"
    and key ~= ns.FontDropdown.STANDARD_FONT_KEY
  then
    path = LSM:Fetch(LSM.MediaType.FONT, key, true) or path
  end

  if type(config.flags) == "string" then
    flags = config.flags == "NONE" and "" or config.flags
  end

  local size = tonumber(config.size) or 14
  if size < 6 then size = 6 end
  if size > 72 then size = 72 end

  return path, flags or "", Theme.ResolveFontSize(size, "resourceDisplay")
end

local function _PUI_PRD_CreatePreviewBar(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetFrameLevel(parent:GetFrameLevel() + 2)
  frame:EnableMouse(true)

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)

  local status = CreateFrame("StatusBar", nil, frame)
  status:SetFrameLevel(frame:GetFrameLevel() + 1)
  status:SetMinMaxValues(0, 1)
  status:SetValue(1)

  local iconFrame = CreateFrame("Frame", nil, frame)
  iconFrame:SetFrameLevel(frame:GetFrameLevel() + 2)
  iconFrame:Hide()

  local icon = iconFrame:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(iconFrame)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  local leftText = status:CreateFontString(nil, "OVERLAY")
  leftText:SetJustifyH("LEFT")

  local rightText = status:CreateFontString(nil, "OVERLAY")
  rightText:SetJustifyH("RIGHT")

  local centerText = status:CreateFontString(nil, "OVERLAY")
  centerText:SetJustifyH("CENTER")

  return {
    frame = frame,
    background = background,
    status = status,
    iconFrame = iconFrame,
    icon = icon,
    leftText = leftText,
    rightText = rightText,
    centerText = centerText,
    segments = {},
    dividers = {},
    preview = true,
  }
end

local function _PUI_PRD_GetNativePresentation(bar, role)
  local instance = _PUI_PRD_NativePresentation[bar]
  if instance then
    instance.role = role or instance.role
    return instance
  end

  instance = {
    frame = bar,
    status = bar,
    role = role,
    preview = false,
  }
  _PUI_PRD_NativePresentation[bar] = instance
  return instance
end

function PRDBarPresentation.Create(parent, context)
  context = context or {}

  if context.nativeBar then
    return _PUI_PRD_GetNativePresentation(context.nativeBar, context.role)
  end

  return _PUI_PRD_CreatePreviewBar(parent)
end

function PRDBarPresentation.BindDataProvider(instance, provider)
  instance.provider = provider
end

function PRDBarPresentation.ApplyStyle(instance, state)
  if instance.preview ~= true then
    local bar = instance.status
    local role = state.role or instance.role
    local cfg = state.config or _PUI_PRD_GetNativeBarConfig(M, role)
    local owner = state.owner or _PUI_GetNativeBarOwner(M, role)

    _StripPRDOverlayArt(bar)

    local boxKey = role == "health" and "healthBox" or "primaryBox"
    _EnsurePUIBackdrop(M, owner or bar, boxKey)
    _PUI_PRD_ApplyNativeBarTexture(M, bar, role)
    _PUI_PRD_HideNativeAnonymousBackground(bar)
    _PUI_PRD_ApplyNativeBarColor(bar, cfg)
    _PUI_PRD_ApplyNativeBarEffects(M, bar, role, cfg)
    _PUI_PRD_ApplyNativeTextConfig(M, bar, role)
    _StripPRDOverlayArt(bar)
    return
  end

  local appearance = state.appearance or {}
  local style = appearance.style or {}
  local color = state.color or { 1, 1, 1, 1 }
  local borderSize = M:GetBarBorderThickness(style, instance.frame)
  local borderColor = M:GetBarBorderColor(style)
  local backgroundColor = style.bgColor or { 0, 0, 0, 0.65 }
  local textureKey = appearance.texture or "Pleebar"
  local texture = LSM:Fetch("statusbar", textureKey, true) or textureKey

  instance.background:SetColorTexture(
    backgroundColor[1] or backgroundColor.r or 0,
    backgroundColor[2] or backgroundColor.g or 0,
    backgroundColor[3] or backgroundColor.b or 0,
    backgroundColor[4] or backgroundColor.a or 0.65
  )
  M:ApplyBarBorder(instance.frame, borderSize, borderColor)
  instance.status:SetStatusBarTexture(texture)
  instance.status:SetStatusBarColor(
    color[1] or color.r or 1,
    color[2] or color.g or 1,
    color[3] or color.b or 1,
    color[4] or color.a or 1
  )

  local statusTexture = instance.status:GetStatusBarTexture()
  if statusTexture then
    statusTexture:SetHorizTile(false)
    statusTexture:SetVertTile(false)
    statusTexture:SetTexCoord(0, 1, 0, 1)
  end

  local path, flags, size = _PUI_PRD_ResolvePresentationFont(state.textConfig)
  local texts = { instance.leftText, instance.rightText, instance.centerText }
  for index = 1, #texts do
    local text = texts[index]
    text:SetFont(path, size, flags)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
  end
end

function PRDBarPresentation.ApplyGeometry(instance, state)
  if instance.preview ~= true then
    if not InCombatLockdown() then
      state.owner = _PUI_ApplyNativeBarGeometry(M, instance.status, state.role or instance.role)
    end
    return
  end

  local frame = instance.frame
  local appearance = state.appearance or {}
  local style = appearance.style or {}
  local inset = M:GetBarBorderThickness(style, frame)
  local iconSpellID = state.iconSpellID

  frame:SetSize(state.width or frame:GetWidth(), state.height or frame:GetHeight())
  instance.iconFrame:ClearAllPoints()
  instance.status:ClearAllPoints()

  if iconSpellID then
    local height = math.max(1, frame:GetHeight() - inset * 2)
    instance.iconFrame:SetSize(height, height)
    instance.iconFrame:SetPoint("LEFT", frame, "LEFT", inset, 0)
    instance.icon:SetTexture(C_Spell.GetSpellTexture(iconSpellID) or "Interface\\Icons\\INV_Misc_QuestionMark")
    instance.iconFrame:Show()

    instance.status:SetPoint("TOPLEFT", instance.iconFrame, "TOPRIGHT", state.iconGap or 2, 0)
    instance.status:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
  else
    instance.iconFrame:Hide()
    instance.status:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    instance.status:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
  end

  instance.leftText:ClearAllPoints()
  instance.leftText:SetPoint("LEFT", instance.status, "LEFT", 4, 0)
  instance.leftText:SetPoint("RIGHT", instance.status, "CENTER", -2, 0)
  instance.rightText:ClearAllPoints()
  instance.rightText:SetPoint("LEFT", instance.status, "CENTER", 2, 0)
  instance.rightText:SetPoint("RIGHT", instance.status, "RIGHT", -4, 0)
  instance.centerText:ClearAllPoints()
  instance.centerText:SetPoint("CENTER", instance.status, "CENTER", 0, 0)
end

function PRDBarPresentation.ApplyVisibility(instance, state)
  if state.skipVisibility == true then
    return
  end

  local visible = state.visible ~= false
  instance.frame:SetShown(visible)
  if not visible then
    return
  end

  if instance.preview ~= true then
    return
  end

  local provider = instance.provider
  local minimum = tonumber(Presentation.Read(provider, "minimum", 0, instance, state)) or 0
  local maximum = tonumber(Presentation.Read(provider, "maximum", 100, instance, state)) or 100
  local value = tonumber(Presentation.Read(provider, "value", maximum, instance, state)) or maximum

  instance.status:SetMinMaxValues(minimum, maximum)
  instance.status:SetValue(value)
  instance.leftText:SetText(Presentation.Read(provider, "leftText", "", instance, state) or "")
  instance.rightText:SetText(Presentation.Read(provider, "rightText", "", instance, state) or "")
  instance.centerText:SetText(Presentation.Read(provider, "centerText", "", instance, state) or "")
end

function PRDBarPresentation.Release(instance)
  instance.provider = nil
  instance.frame:Hide()
  instance.frame:ClearAllPoints()
end

Presentation.Register("PRDBar", PRDBarPresentation)

function M:ApplyNativeBarSkin(bar, role)
  if not _IsPUI_SecureFrame(bar) then
    return
  end

  if role ~= "health" and role ~= "primary" then
    return
  end

  local instance = _PUI_PRD_GetNativePresentation(bar, role)
  Presentation.Apply("PRDBar", instance, {
    role = role,
    config = _PUI_PRD_GetNativeBarConfig(self, role),
    skipVisibility = true,
  })

  if bar.GetFrameLevel and bar.SetFrameLevel then
    local level = bar:GetFrameLevel() or 0
    if level < 2 then
      bar:SetFrameLevel(2)
    end
  end

  local state = _PUI_PRD_GetBarState(bar)
  state.skinnedOnce = true
  state.skinnedRole = role
end




local function _OnSetupHealthBar(frame)
  local now = GetTime()
  local nextAt = M.__puiSetupHealthNextAt or 0
  if now < nextAt then
    return
  end
  M.__puiSetupHealthNextAt = now + 0.10

  if not _PUI_ShouldApply() then return end
  if not _PUI_HealthAvailable() then return end

  local bar = frame.HealthBarsContainer.healthBar
  if bar then
    M.blizz = M.blizz or {}
    M.blizz.health = bar
    local changed = (M.healthBar ~= bar)
    M.healthBar = bar

    if not M._puiOriginalHealthColor and bar.GetStatusBarColor then
      local r, g, b, a = bar:GetStatusBarColor()
      M._puiOriginalHealthColor = { r or 1, g or 1, b or 1, a or 1 }
    end

    local state = _PUI_PRD_NativeBarState[bar]
    if (not changed)
      and state
      and state.skinnedOnce == true
      and state.skinnedRole == "health"
      and not M.__puiHealthTextureDirty
    then
      return
    end

    if not InCombatLockdown() then
      M:MountHealthBar()
    else
      M:ApplyNativeBarSkin(bar, "health")
    end

    M.__puiHealthTextureDirty = false
  end
end

local function _OnSetupPowerBar(frame)
  local now = GetTime()
  local nextAt = M.__puiSetupPowerNextAt or 0
  if now < nextAt then
    return
  end
  M.__puiSetupPowerNextAt = now + 0.10

  if not _PUI_ShouldApply() then return end
  if not _PUI_PrimaryEnabled() then return end

  local bar = frame.PowerBar
  if bar then
    M.blizz = M.blizz or {}
    M.blizz.primary = bar

    local changed = (M.primaryBar ~= bar)
    M.primaryBar = bar

    local state = _PUI_PRD_NativeBarState[bar]
    if (not changed)
      and state
      and state.skinnedOnce == true
      and state.skinnedRole == "primary"
      and not M.__puiPrimaryTextureDirty
    then
      return
    end

    if not InCombatLockdown() then
      M:MountPrimaryBar()
    else
      M:ApplyNativeBarSkin(bar, "primary")
    end

    M.__puiPrimaryTextureDirty = false
  end
end

local function _OnSetupClassBar()
  if not _PUI_ShouldApply() then return end
  M:SetBlizzardSecondaryShown(not M.secondaryCustomEnabled)
end

function M:HookBlizzardSetupOnce()
  if self.__puiPRDSetupHooked then
    return
  end
  self.__puiPRDSetupHooked = true

  local frame = PersonalResourceDisplayFrame
  hooksecurefunc(frame, "SetupHealthBar", _OnSetupHealthBar)
  hooksecurefunc(frame, "SetupPowerBar", _OnSetupPowerBar)
  hooksecurefunc(frame, "SetupClassBar", _OnSetupClassBar)
end


local function _StoreOriginalBarLayout(self, key, bar)
  if not self or not bar or not bar.GetNumPoints then return end

  self._puiOriginalLayout = self._puiOriginalLayout or {}
  if self._puiOriginalLayout[key]
    and self._puiOriginalLayout[key].bar == bar
  then
    return
  end

  local rec = { bar = bar }
  rec.parent = bar:GetParent()
  rec.points = {}
  rec.textures = {}
  rec.textureLookup = {}

  local num = bar:GetNumPoints() or 0
  for i = 1, num do
    local p1, p2, p3, p4, p5 = bar:GetPoint(i)
    rec.points[i] = { p1, p2, p3, p4, p5 }
  end

  local function CaptureTexture(texture)
    if not texture or rec.textureLookup[texture] then
      return
    end

    rec.textureLookup[texture] = true

    local state = {
      texture = texture,
      atlas = texture.GetAtlas and texture:GetAtlas() or nil,
      file = texture.GetTexture and texture:GetTexture() or nil,
      alpha = texture.GetAlpha and texture:GetAlpha() or 1,
      shown = texture.IsShown and texture:IsShown() or false,
    }

    if texture.GetVertexColor then
      state.vertexColor = { texture:GetVertexColor() }
    end
    if texture.GetTexCoord then
      state.texCoord = { texture:GetTexCoord() }
    end

    rec.textures[#rec.textures + 1] = state
  end

  local function CaptureRegions(frame)
    if not frame or not frame.GetRegions then
      return
    end

    for i = 1, select("#", frame:GetRegions()) do
      local region = select(i, frame:GetRegions())
      if region and region.SetTexture then
        CaptureTexture(region)
      end
    end
  end

  local function CaptureBorder(border)
    if not border then
      return
    end

    if border.SetTexture then
      CaptureTexture(border)
    end

    if type(border.Textures) == "table" then
      for i = 1, #border.Textures do
        CaptureTexture(border.Textures[i])
      end
    end

    CaptureTexture(border.Top)
    CaptureTexture(border.Bottom)
    CaptureTexture(border.Left)
    CaptureTexture(border.Right)
  end

  CaptureRegions(bar)
  CaptureRegions(rec.parent)
  CaptureBorder(bar.Border)
  CaptureBorder(bar.border)
  CaptureBorder(rec.parent and rec.parent.Border)
  CaptureBorder(rec.parent and rec.parent.border)

  if bar.GetStatusBarTexture then
    local statusTexture = bar:GetStatusBarTexture()
    rec.statusBarTexture = statusTexture and statusTexture:GetTexture() or nil
  end
  if bar.GetStatusBarColor then
    rec.statusBarColor = { bar:GetStatusBarColor() }
  end

  rec.textureLookup = nil
  self._puiOriginalLayout[key] = rec
end

local function _RestoreOriginalBarLayout(self, key, bar)
  local rec = self._puiOriginalLayout and self._puiOriginalLayout[key]
  if not rec or rec.bar ~= bar then
    return
  end

  bar:SetParent(rec.parent)
  bar:ClearAllPoints()
  for i = 1, #rec.points do
    bar:SetPoint(Unpack(rec.points[i]))
  end

  if rec.statusBarTexture and bar.SetStatusBarTexture then
    bar:SetStatusBarTexture(rec.statusBarTexture)
  end
  if rec.statusBarColor and bar.SetStatusBarColor then
    bar:SetStatusBarColor(Unpack(rec.statusBarColor))
  end

  for i = 1, #rec.textures do
    local state = rec.textures[i]
    local texture = state.texture

    if state.atlas and texture.SetAtlas then
      texture:SetAtlas(state.atlas)
    elseif texture.SetTexture then
      texture:SetTexture(state.file)
    end

    if state.vertexColor and texture.SetVertexColor then
      texture:SetVertexColor(Unpack(state.vertexColor))
    end
    if state.texCoord and texture.SetTexCoord then
      texture:SetTexCoord(Unpack(state.texCoord))
    end

    texture:SetAlpha(state.alpha)
    if state.shown then
      texture:Show()
    else
      texture:Hide()
    end

    _PUI_PRD_NativeRegionState[texture] = nil
  end

  local nativeState = _PUI_PRD_NativeBarState[bar]
  if nativeState
    and nativeState.originalPropagateMouseMotion ~= nil
    and bar:CanPropagateMouseMotion() ~= nativeState.originalPropagateMouseMotion
  then
    bar:SetPropagateMouseMotion(nativeState.originalPropagateMouseMotion)
  end

  _PUI_PRD_NativeBarState[bar] = nil
  _PUI_PRD_NativePresentation[bar] = nil

  local centerText, leftText, rightText = _PUI_PRD_GetNativeBarText(bar)
  if centerText then
    _PUI_PRD_NativeFontState[centerText] = nil
  end
  if leftText then
    _PUI_PRD_NativeFontState[leftText] = nil
  end
  if rightText then
    _PUI_PRD_NativeFontState[rightText] = nil
  end

  local owner = key == "health" and self.health or key == "primary" and self.primary or nil
  if owner then
    owner:EnableMouseMotion(false)
    owner:SetScript("OnEnter", nil)
    owner:SetScript("OnLeave", nil)
    _PUI_PRD_NativeMouseoverOwner[owner] = nil
  end

  bar:Show()
end

function M:RestoreBlizzardBars()
  if InCombatLockdown() then
    self._puiNativeRestorePending = true
    return false
  end

  self:AcquireBlizzardFrames()

  local healthBar = self.blizz and self.blizz.health
  local primaryBar = self.blizz and self.blizz.primary

  _RestoreOriginalBarLayout(self, "health", healthBar)
  _RestoreOriginalBarLayout(self, "primary", primaryBar)

  self._puiOriginalLayout = nil
  self._puiOriginalHealthColor = nil
  self._puiNativeRestorePending = nil
  return true
end


function M:MountPrimaryBar()
  if not self.blizz or not self.blizz.primary or not self.primary then
    return
  end

  if not _PUI_PrimaryEnabled() then
    if self.PrimaryText then
      self.PrimaryText:SetText("")
      self.PrimaryText:Hide()
    end
    return
  end

  local bar = self.blizz.primary
  self.primaryBar = bar -- store reference for text overlays

  _StoreOriginalBarLayout(self, "primary", bar)

  if bar.Show then
    bar:Show()
  end

  self:RefreshPrimaryTexture()
end

function M:MountHealthBar()
  if not self.blizz or not self.blizz.health or not self.health then
    return
  end

  local bar = self.blizz.health

  if (not self._puiOriginalHealthColor) and bar.GetStatusBarColor then
    local r, g, b, a = bar:GetStatusBarColor()
    self._puiOriginalHealthColor = { r or 1, g or 1, b or 1, a or 1 }
  end

  self.healthBar = bar

  -- Snapshot original layout once so we can restore on disable
  _StoreOriginalBarLayout(self, "health", bar)

  bar:Show()
  self:RefreshHealthTexture()
end

function M:ResolveIconTextFont()
  local key, flags = Theme.GetIconTextGlobal()

  if not key or key == "" then
    key = Theme.iconTextGlobal.font
  end
  if flags == nil or flags == "" then
    flags = Theme.iconTextGlobal.flags
  end

  if key == ns.FontDropdown.STANDARD_FONT_KEY then
    key = nil
  end

  if flags == "NONE" or flags == nil then
    flags = ""
  end

  local cacheKey = tostring(key or "") .. "|" .. tostring(flags or "")
  if _PUI_GlobalFontSig == cacheKey and type(_PUI_GlobalFontPath) == "string" then
    return _PUI_GlobalFontPath, _PUI_GlobalFontFlags or ""
  end

  local path
  if key then
    path = LSM:Fetch(LSM.MediaType.FONT, key, true)
  end

  if type(path) ~= "string" or path == "" then
    if type(key) == "string" and (key:find("\\") or key:find("/")) and key:lower():find("%.ttf") then
      path = key
    else
      path = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end
  end

  _PUI_GlobalFontSig   = cacheKey
  _PUI_GlobalFontPath  = path
  _PUI_GlobalFontFlags = flags

  return path, flags
end

-- Font helpers
local function _EnsureFontSet(fs, cfg)
  if not fs or not fs.SetFont then
    return
  end

  local fontPath, fontFlags
  local fontSize = 14

  local gPath, gFlags = M:ResolveIconTextFont()
  fontPath = gPath
  fontFlags = gFlags

  local appearanceText = cfg

  if appearanceText then
    if type(appearanceText.size) == "number" and appearanceText.size > 0 then
      fontSize = appearanceText.size
    end

    if appearanceText.useGlobalFont ~= true and type(appearanceText.font) == "string" and appearanceText.font ~= "" and appearanceText.font ~= "GLOBAL" then
      local fetched = LSM:Fetch(LSM.MediaType.FONT, appearanceText.font, true)
      if type(fetched) == "string" and fetched ~= "" then
        fontPath = fetched
      end
    end

    if type(appearanceText.flags) == "string" then
      if appearanceText.flags == "NONE" or appearanceText.flags == "" then
        fontFlags = ""
      else
        fontFlags = appearanceText.flags
      end
    end
  end

  if type(fontPath) ~= "string" or fontPath == "" then
    fontPath = gPath
  end

  fontSize = Theme.ResolveFontSize(fontSize, "resourceDisplay")
  local sig = tostring(fontPath) .. "|" .. tostring(fontSize) .. "|" .. tostring(fontFlags)
  if _PUI_PRD_NativeFontState[fs] ~= sig then
    _PUI_PRD_NativeFontState[fs] = sig
    fs:SetFont(fontPath, fontSize, fontFlags)
  end
end

_PUI_PRD_GetNativeBarText = function(bar)
  if not bar then
    return nil, nil, nil
  end

  return bar.TextString, bar.LeftText, bar.RightText
end

local function _PUI_PRD_TextModeAlpha(bar, mode)
  if mode == "ALWAYS" then
    return 1
  end

  if mode == "MOUSEOVER" then
    local state = bar and _PUI_PRD_NativeBarState[bar]
    return state and state.textMouseover and 1 or 0
  end

  return 0
end

local function _PUI_PRD_UpdateNativeTextAlpha(bar)
  if not bar then
    return
  end

  local state = _PUI_PRD_NativeBarState[bar]
  local cfg = state and state.nativeTextConfig
  if not cfg then
    return
  end

  local _, leftText, rightText = _PUI_PRD_GetNativeBarText(bar)

  if leftText and leftText.SetAlpha then
    leftText:SetAlpha(_PUI_PRD_TextModeAlpha(bar, cfg.leftVisibility))
  end

  if rightText and rightText.SetAlpha then
    rightText:SetAlpha(_PUI_PRD_TextModeAlpha(bar, cfg.rightVisibility))
  end
end

local function _PUI_PRD_InstallNativeTextMouseover(self, bar, role, enabled)
  if not self or not bar then
    return
  end

  local owner = _PUI_GetNativeBarOwner(self, role)
  if not owner then
    return
  end

  local state = _PUI_PRD_GetBarState(bar)
  if state.originalPropagateMouseMotion == nil then
    state.originalPropagateMouseMotion = bar:CanPropagateMouseMotion()
  end

  local propagateMouseMotion = enabled == true or state.originalPropagateMouseMotion == true
  if not InCombatLockdown() and bar:CanPropagateMouseMotion() ~= propagateMouseMotion then
    bar:SetPropagateMouseMotion(propagateMouseMotion)
  end

  local binding = _PUI_PRD_NativeMouseoverOwner[owner]

  if enabled ~= true then
    state.textMouseover = false

    if binding then
      if binding.bar and binding.bar ~= bar then
        local previousState = _PUI_PRD_NativeBarState[binding.bar]
        if previousState then
          previousState.textMouseover = false
        end
      end

      owner:EnableMouseMotion(false)
      owner:SetScript("OnEnter", nil)
      owner:SetScript("OnLeave", nil)
      _PUI_PRD_NativeMouseoverOwner[owner] = nil
    end

    _PUI_PRD_UpdateNativeTextAlpha(bar)
    return
  end

  if not binding then
    binding = {}
    _PUI_PRD_NativeMouseoverOwner[owner] = binding

    owner:SetScript("OnEnter", function(container)
      local active = _PUI_PRD_NativeMouseoverOwner[container]
      local nativeBar = active and active.bar
      if nativeBar then
        local mouseoverState = _PUI_PRD_GetBarState(nativeBar)
        mouseoverState.textMouseover = true
        _PUI_PRD_UpdateNativeTextAlpha(nativeBar)
      end
    end)

    owner:SetScript("OnLeave", function(container)
      local active = _PUI_PRD_NativeMouseoverOwner[container]
      local nativeBar = active and active.bar
      if nativeBar then
        local mouseoverState = _PUI_PRD_GetBarState(nativeBar)
        mouseoverState.textMouseover = false
        _PUI_PRD_UpdateNativeTextAlpha(nativeBar)
      end
    end)
  elseif binding.bar and binding.bar ~= bar then
    local previousState = _PUI_PRD_NativeBarState[binding.bar]
    if previousState then
      previousState.textMouseover = false
    end
  end

  binding.bar = bar
  state.textMouseover = owner:IsMouseOver()
  owner:EnableMouseMotion(true)
end

local function _PUI_PRD_ConfigureNativeTextRegion(fs, cfg, alpha)
  if not fs then
    return
  end

  if cfg then
    _EnsureFontSet(fs, cfg)
  end

  if fs.SetDrawLayer then
    fs:SetDrawLayer("OVERLAY", 7)
  end
  if fs.SetJustifyV then
    fs:SetJustifyV("MIDDLE")
  end
  if fs.SetAlpha then
    fs:SetAlpha(alpha or 0)
  end
end

local function _PUI_PRD_PointNativeText(bar, fs, point, relativePoint, x, y, justify)
  if not bar or not fs then
    return
  end

  fs:ClearAllPoints()
  fs:SetPoint(point, bar, relativePoint, x or 0, y or 0)

  if justify and fs.SetJustifyH then
    fs:SetJustifyH(justify)
  end
end

local function _PUI_PRD_ApplyNativeTextAnchors(bar, cfg)
  local text, leftText, rightText = _PUI_PRD_GetNativeBarText(bar)
  local showLeft = cfg and M:IsNativeTextVisible(cfg.leftVisibility)
  local showRight = cfg and M:IsNativeTextVisible(cfg.rightVisibility)
  local centered = cfg and cfg.centerText == true

  _PUI_PRD_PointNativeText(bar, text, "CENTER", "CENTER", 0, 0, "CENTER")

  if centered then
    if showLeft and showRight then
      _PUI_PRD_PointNativeText(bar, leftText, "RIGHT", "CENTER", -2, 0, "RIGHT")
      _PUI_PRD_PointNativeText(bar, rightText, "LEFT", "CENTER", 2, 0, "LEFT")
    elseif showLeft then
      _PUI_PRD_PointNativeText(bar, leftText, "CENTER", "CENTER", 0, 0, "CENTER")
      _PUI_PRD_PointNativeText(bar, rightText, "RIGHT", "RIGHT", -2, 0, "RIGHT")
    elseif showRight then
      _PUI_PRD_PointNativeText(bar, leftText, "LEFT", "LEFT", 2, 0, "LEFT")
      _PUI_PRD_PointNativeText(bar, rightText, "CENTER", "CENTER", 0, 0, "CENTER")
    else
      _PUI_PRD_PointNativeText(bar, leftText, "LEFT", "LEFT", 2, 0, "LEFT")
      _PUI_PRD_PointNativeText(bar, rightText, "RIGHT", "RIGHT", -2, 0, "RIGHT")
    end
  else
    _PUI_PRD_PointNativeText(bar, leftText, "LEFT", "LEFT", 2, 0, "LEFT")
    _PUI_PRD_PointNativeText(bar, rightText, "RIGHT", "RIGHT", -2, 0, "RIGHT")
  end
end

_PUI_PRD_ApplyNativeTextConfig = function(self, bar, key)
  if not bar then
    return false
  end

  local resourceSettings = key == "primary" and self:GetPrimaryResourceSettings() or nil
  local cfg = resourceSettings and resourceSettings.text or self.db.profile.text[key]
  local text, leftText, rightText = _PUI_PRD_GetNativeBarText(bar)
  local leftMode = cfg and cfg.leftVisibility or "HIDE"
  local rightMode = cfg and cfg.rightVisibility or "HIDE"
  local left = cfg and cfg.left or nil
  local right = cfg and cfg.right or nil
  local appearanceText = resourceSettings and resourceSettings.text or self:GetBarAppearance(key).text
  local usesMouseover = leftMode == "MOUSEOVER" or rightMode == "MOUSEOVER"

  local state = _PUI_PRD_GetBarState(bar)
  state.nativeTextConfig = cfg
  _PUI_PRD_InstallNativeTextMouseover(self, bar, key, usesMouseover)

  local sig = table.concat({
    key or "",
    leftMode or "",
    rightMode or "",
    cfg and cfg.centerText and "1" or "0",
    left and left.font or "",
    left and left.size or "",
    left and left.flags or "",
    left and left.useGlobalFont and "1" or "0",
    right and right.font or "",
    right and right.size or "",
    right and right.flags or "",
    right and right.useGlobalFont and "1" or "0",
    appearanceText.font or "",
    appearanceText.size or "",
    appearanceText.flags or "",
    appearanceText.useGlobalFont and "1" or "0",
  }, "|")

  if state.nativeTextSig == sig then
    _PUI_PRD_UpdateNativeTextAlpha(bar)
    return M:IsNativeTextVisible(leftMode) or M:IsNativeTextVisible(rightMode)
  end

  state.nativeTextSig = sig

  _PUI_PRD_ConfigureNativeTextRegion(text, appearanceText, 0)
  _PUI_PRD_ConfigureNativeTextRegion(leftText, appearanceText, _PUI_PRD_TextModeAlpha(bar, leftMode))
  _PUI_PRD_ConfigureNativeTextRegion(rightText, appearanceText, _PUI_PRD_TextModeAlpha(bar, rightMode))
  _PUI_PRD_ApplyNativeTextAnchors(bar, cfg)

  return M:IsNativeTextVisible(leftMode) or M:IsNativeTextVisible(rightMode)
end

function M:EnsurePrimaryTextFrames()
  local healthOwner  = _PUI_HealthAvailable() and self.healthBar or nil
  local primaryOwner = _PUI_PrimaryEnabled() and self.primaryBar or nil

  if healthOwner then
    self.HealthText, self.HealthLeftText, self.HealthRightText = _PUI_PRD_GetNativeBarText(healthOwner)
  else
    self.HealthText, self.HealthLeftText, self.HealthRightText = nil, nil, nil
  end

  if primaryOwner then
    self.PrimaryText, self.PrimaryLeftText, self.PrimaryRightText = _PUI_PRD_GetNativeBarText(primaryOwner)
  else
    self.PrimaryText, self.PrimaryLeftText, self.PrimaryRightText = nil, nil, nil
  end
end

function M:ApplyTextSettings()
  self:EnsurePrimaryTextFrames()

  if _PUI_PrimaryEnabled() then
    _PUI_PRD_ApplyNativeTextConfig(self, self.primaryBar, "primary")
  end

  if _PUI_HealthAvailable() then
    _PUI_PRD_ApplyNativeTextConfig(self, self.healthBar, "health")
  end
end

function M:InvalidateTextCache()
  if self.healthBar then
    _PUI_PRD_GetBarState(self.healthBar).nativeTextSig = nil
  end
  if self.primaryBar then
    _PUI_PRD_GetBarState(self.primaryBar).nativeTextSig = nil
  end
  self:ApplyTextSettings()
end


  _IsPUI_SecureFrame = P:Def("_IsPUI_SecureFrame", _IsPUI_SecureFrame)
  _PUI_ShouldApply = P:Def("_PUI_ShouldApply", _PUI_ShouldApply)
  _PUI_GetStyleForBackdrop = P:Def("_PUI_GetStyleForBackdrop", _PUI_GetStyleForBackdrop)
  _PUI_ResolveBackdropFillColor = P:Def("_PUI_ResolveBackdropFillColor", _PUI_ResolveBackdropFillColor)
  _PUI_GetNativeBarOwner = P:Def("_PUI_GetNativeBarOwner", _PUI_GetNativeBarOwner)
  _PUI_ApplyNativeBarGeometry = P:Def("_PUI_ApplyNativeBarGeometry", _PUI_ApplyNativeBarGeometry)
  _PUI_ApplyBackdropStyle = P:Def("_PUI_ApplyBackdropStyle", _PUI_ApplyBackdropStyle)
  _EnsurePUIBackdrop = P:Def("_EnsurePUIBackdrop", _EnsurePUIBackdrop)
  _PUI_PRD_HidePrimaryTicks = P:Def("_PUI_PRD_HidePrimaryTicks", _PUI_PRD_HidePrimaryTicks)
  _PUI_PRD_EnsurePrimaryTickOverlay = P:Def("_PUI_PRD_EnsurePrimaryTickOverlay", _PUI_PRD_EnsurePrimaryTickOverlay)
  M.RefreshPrimaryTicks = P:Def("RefreshPrimaryTicks", M.RefreshPrimaryTicks)
  _StripPRDOverlayArt = P:Def("_StripPRDOverlayArt", _StripPRDOverlayArt)
  _PUI_PRD_HideTexture = P:Def("_PUI_PRD_HideTexture", _PUI_PRD_HideTexture)
  _PUI_PRD_HideKnownNamePlateBorder = P:Def("_PUI_PRD_HideKnownNamePlateBorder", _PUI_PRD_HideKnownNamePlateBorder)
  _PUI_PRD_HideNativeAnonymousBackground = P:Def("_PUI_PRD_HideNativeAnonymousBackground", _PUI_PRD_HideNativeAnonymousBackground)
  _PUI_PRD_GetNativeBarConfig = P:Def("_PUI_PRD_GetNativeBarConfig", _PUI_PRD_GetNativeBarConfig)
  _PUI_PRD_GetClassColor = P:Def("_PUI_PRD_GetClassColor", _PUI_PRD_GetClassColor)
  _PUI_PRD_ApplyNativeBarTexture = P:Def("_PUI_PRD_ApplyNativeBarTexture", _PUI_PRD_ApplyNativeBarTexture)
  _PUI_PRD_ApplyNativeBarColor = P:Def("_PUI_PRD_ApplyNativeBarColor", _PUI_PRD_ApplyNativeBarColor)
  _PUI_PRD_SetRegionTexture = P:Def("_PUI_PRD_SetRegionTexture", _PUI_PRD_SetRegionTexture)
  _PUI_PRD_SetRegionColor = P:Def("_PUI_PRD_SetRegionColor", _PUI_PRD_SetRegionColor)
  _PUI_PRD_GetEffectTint = P:Def("_PUI_PRD_GetEffectTint", _PUI_PRD_GetEffectTint)
  _PUI_PRD_ApplyNativeBarEffects = P:Def("_PUI_PRD_ApplyNativeBarEffects", _PUI_PRD_ApplyNativeBarEffects)
  M.ApplyNativeBarSkin = P:Def("ApplyNativeBarSkin", M.ApplyNativeBarSkin)
  _OnSetupHealthBar = P:Def("_OnSetupHealthBar", _OnSetupHealthBar)
  _OnSetupPowerBar = P:Def("_OnSetupPowerBar", _OnSetupPowerBar)
  _OnSetupClassBar = P:Def("_OnSetupClassBar", _OnSetupClassBar)
  M.HookBlizzardSetupOnce = P:Def("HookBlizzardSetupOnce", M.HookBlizzardSetupOnce)
  _StoreOriginalBarLayout = P:Def("_StoreOriginalBarLayout", _StoreOriginalBarLayout)
  _RestoreOriginalBarLayout = P:Def("_RestoreOriginalBarLayout", _RestoreOriginalBarLayout)
  M.RestoreBlizzardBars = P:Def("RestoreBlizzardBars", M.RestoreBlizzardBars)
  M.MountPrimaryBar = P:Def("MountPrimaryBar", M.MountPrimaryBar)
  M.MountHealthBar = P:Def("MountHealthBar", M.MountHealthBar)
  M.ResolveIconTextFont = P:Def("ResolveIconTextFont", M.ResolveIconTextFont)
  _EnsureFontSet = P:Def("_EnsureFontSet", _EnsureFontSet)
  _PUI_PRD_GetNativeBarText = P:Def("_PUI_PRD_GetNativeBarText", _PUI_PRD_GetNativeBarText)
  _PUI_PRD_ConfigureNativeTextRegion = P:Def("_PUI_PRD_ConfigureNativeTextRegion", _PUI_PRD_ConfigureNativeTextRegion)
  _PUI_PRD_PointNativeText = P:Def("_PUI_PRD_PointNativeText", _PUI_PRD_PointNativeText)
  _PUI_PRD_ApplyNativeTextAnchors = P:Def("_PUI_PRD_ApplyNativeTextAnchors", _PUI_PRD_ApplyNativeTextAnchors)
  _PUI_PRD_ApplyNativeTextConfig = P:Def("_PUI_PRD_ApplyNativeTextConfig", _PUI_PRD_ApplyNativeTextConfig)
  M.EnsurePrimaryTextFrames = P:Def("EnsurePrimaryTextFrames", M.EnsurePrimaryTextFrames)
  M.ApplyTextSettings = P:Def("ApplyTextSettings", M.ApplyTextSettings)
  M.InvalidateTextCache = P:Def("InvalidateTextCache", M.InvalidateTextCache)

