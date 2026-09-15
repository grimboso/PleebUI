
-- File: PUI_UF_Style.lua
-- Purpose: Shared UnitFrames style, media, texture, and theme helpers.


local ADDON_NAME, ns = ...


ns.UFStyle = ns.UFStyle or {}
local UFStyle = ns.UFStyle

local _G = _G
local CreateFrame = _G.CreateFrame
local math_max = _G.math.max
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local type = _G.type

local LSM = ns.LSM
local Theme = ns.Theme
local UFHealth = ns.UFHealth
local UFHealPrediction = ns.UFHealPrediction
local UFPortrait = ns.UFPortrait
local Pixel = ns.Pixel

local DEFAULT_STATUSBAR_TEXTURE = Theme.GetBarTexture()
local BASE_COLORS = {
  bg = { 0, 0, 0, 0.55 },
  border = { 0.10, 0.10, 0.10, 1 },
  borderColor = { 0.10, 0.10, 0.10, 1 },
  healthBar = { 0.35, 0.35, 0.35, 1 },
  healthMissing = { 0.15, 0.15, 0.15, 0.95 },
  powerMissing = { 0.10, 0.10, 0.10, 0.95 },
  nameText = { 1, 1, 1, 1 },
  healthText = { 1, 1, 1, 1 },
  powerText = { 1, 1, 1, 1 },
  deadText = { 0.7, 0.7, 0.7, 1 },
  healthAbsorb = { 0.50196081399918, 0.75294125080109, 1, 0.8 },
  healthHealAbsorb = { 0.50196078431373, 0.25098039215686, 1, 1 },
}
local BASE_SIZES = {
  edgeSize = 1,
  inset = 1,
  gap = 1,
}
local FrameLayoutCache = setmetatable({}, { __mode = "k" })

local function CopyFlatTable(src)
  local out = {}
  for k, v in pairs(src) do
    if type(v) == "table" then
      out[k] = { v[1], v[2], v[3], v[4] }
    else
      out[k] = v
    end
  end
  return out
end


local P = select(1, ns.Pleebug:DropIn(UFStyle, { name = "UnitFrames.Style" }))


local Round = Pixel.Round

local function GetConfigMediaOverride(config, kind)
  if type(config) ~= "table" then
    return nil
  end

  local key = kind .. "Texture"
  local media = type(config.media) == "table" and config.media or nil
  local value = (media and media[key]) or config[key]

  if kind == "absorb" and (type(value) ~= "string" or value == "") then
    value = (media and media.healthTexture) or config.healthTexture
  end

  if type(value) == "string" and value ~= "" then
    return value
  end

  return nil
end

local function GetUnitMediaOverride(unit, kind)
  local UF = ns.UnitFrames
  local units = UF.db.profile.units
  local cfg = units and units[unit] or nil
  local media = cfg and cfg.media or nil
  if not media or not media.useCustomTexture then
    return nil
  end

  if kind == "health" then
    return media.healthTexture
  elseif kind == "power" then
    return media.powerTexture
  elseif kind == "absorb" then
    return media.absorbTexture or media.healthTexture
  end

  return nil
end

function UFStyle.ResolveStatusbarTexture(kind, unit, config)
  local UF = ns.UnitFrames
  local configName = GetConfigMediaOverride(config, kind)

  if configName then
    local texture = LSM:Fetch("statusbar", configName, true)
    if texture then
      return texture
    end
  end

  if unit then
    local perUnitName = GetUnitMediaOverride(unit, kind)
    if perUnitName and perUnitName ~= "" then
      local tex = LSM:Fetch("statusbar", perUnitName, true)
      if tex then
        return tex
      end
    end
  end

  if kind == "health" and UF.Media.healthTexture then
    return UF.Media.healthTexture
  elseif kind == "power" and UF.Media.powerTexture then
    return UF.Media.powerTexture
  elseif kind == "absorb" and UF.Media.absorbTexture then
    return UF.Media.absorbTexture
  end

  return DEFAULT_STATUSBAR_TEXTURE
end

function UFStyle.ResolveMedia(owner)
  local UF = ns.UnitFrames
  owner = owner or UF

  owner.Media = owner.Media or UF.Media or {}
  UF.Media = owner.Media

  owner._colorsCache = nil
  UF._colorsCache = nil

  local media = owner.Media
  local profileMedia = UF.db.profile.media or {}

  media.healthTexture = LSM:Fetch("statusbar", profileMedia.healthTexture or "Pleebar", true) or DEFAULT_STATUSBAR_TEXTURE
  media.powerTexture = LSM:Fetch("statusbar", profileMedia.powerTexture or "Pleebar", true) or DEFAULT_STATUSBAR_TEXTURE
  media.absorbTexture = LSM:Fetch("statusbar", profileMedia.absorbTexture or profileMedia.healthTexture or "Pleebar", true) or DEFAULT_STATUSBAR_TEXTURE

  owner._fontRev = (owner._fontRev or 0) + 1
  owner._styleRev = (owner._styleRev or 0) + 1
end


function UFStyle.GetUFThemeColors()
  local UF = ns.UnitFrames
  if UF._colorsCache then
    return UF._colorsCache
  end

  local colors = CopyFlatTable(BASE_COLORS)
  local db = UF.db.profile
  local overrides = db and db.colors or nil

  if overrides then
    for k, v in pairs(overrides) do
      if type(v) == "table" then
        colors[k] = { v[1], v[2], v[3], v[4] }
      else
        colors[k] = v
      end
    end
  end

  if overrides and overrides.healthAbsorb then
    local src = overrides.healthAbsorb
    colors.healthAbsorb = {
      src[1] or 0.50196081399918,
      src[2] or 0.75294125080109,
      src[3] or 1,
      src[4] or (colors.healthAbsorb and colors.healthAbsorb[4]) or 0.8,
    }
  end

  if overrides and overrides.healthHealAbsorb then
    local src = overrides.healthHealAbsorb
    colors.healthHealAbsorb = {
      src[1] or 0.50196078431373,
      src[2] or 0.25098039215686,
      src[3] or 1,
      src[4] or (colors.healthHealAbsorb and colors.healthHealAbsorb[4]) or 1,
    }
  end

  UF._colorsCache = colors

  return colors
end


function UFStyle.ApplyStyleIfNeeded(frame, unit)
  local UF = ns.UnitFrames
  if not frame then
    return
  end

  local rev = UF._styleRev or 0
  if frame.__puiUF_styleRev == rev then
    return
  end
  frame.__puiUF_styleRev = rev

  if unit and frame.Health then
    local texH = UFStyle.ResolveStatusbarTexture("health", unit, frame.config)
    frame.__puiUF_healthTexPath = texH
    Pixel.SetStatusBarTexture(frame.Health, texH)
  end

  if unit and frame.Power then
    local texP = UFStyle.ResolveStatusbarTexture("power", unit, frame.config)
    frame.__puiUF_powerTexPath = texP
    Pixel.SetStatusBarTexture(frame.Power, texP)
  end
end

function UFStyle.RefreshFrameTextures(frame)
  if not frame or (frame.IsForbidden and frame:IsForbidden()) then
    return
  end

  local unit = frame.__puiConfigUnit
  if not unit then
    return
  end

  UFStyle.ApplyStyleIfNeeded(frame, unit)

  local absorbTexture = UFStyle.ResolveStatusbarTexture("absorb", unit, frame.config)

  UFHealPrediction.Configure(frame, absorbTexture)
end

function UFStyle.RefreshAllFrameTextures(owner)
  owner = owner or ns.UnitFrames
  if not owner or type(owner.IterateSingleFrames) ~= "function" then
    return
  end

  UFStyle.ResolveMedia(owner)

  owner:IterateSingleFrames(function(frame)
    UFStyle.RefreshFrameTextures(frame)
    UFStyle.UpdateOverlayLevels(frame)
  end)
end


function UFStyle.CreateRaisedElement(frame)
  if not frame then
    return nil
  end

  local baseLevel = frame:GetFrameLevel() or 1
  local frameStrata = frame:GetFrameStrata() or "MEDIUM"
  local raised = frame.RaisedElementParent

  if not raised then
    raised = CreateFrame("Frame", nil, frame)
    frame.RaisedElementParent = raised
  end

  raised:SetAllPoints(frame)
  raised:EnableMouse(false)
  raised:SetFrameStrata(frameStrata)
  raised:SetFrameLevel(baseLevel + 10)
  raised.RaidRoleLevel = baseLevel + 19
  raised.AuraLevel = baseLevel + 20
  raised.AuraWatchLevel = baseLevel + 25
  raised.TrackingRootLevel = baseLevel + 25

  local textureParent = frame.TextureParent
  if not textureParent then
    textureParent = CreateFrame("Frame", nil, raised)
    frame.TextureParent = textureParent
  elseif textureParent:GetParent() ~= raised then
    textureParent:SetParent(raised)
  end

  textureParent:SetAllPoints(frame)
  textureParent:SetFrameStrata(frameStrata)
  textureParent:SetFrameLevel(baseLevel + 11)
  textureParent:EnableMouse(false)

  return raised
end


function UFStyle.BuildUnitFrameVisuals(frame, unit, cfg)
  if not frame then
    return
  end

  UFStyle.CreateRaisedElement(frame)

  UFHealth.Construct(frame)
  ns.UFPower.Construct(frame, unit)

  if cfg and cfg.portrait and cfg.portrait.enabled == true and UFPortrait.IsApplicableUnit(unit, frame.__puiGroupKind) then
    UFPortrait.PrepareFrame(frame, cfg)
  end

  ns.UFIndicators.ConstructNativeStatusElements(frame, unit, cfg)
  ns.UFText.Construct(frame, unit, cfg)

  frame.__puiUF_VisualsBuilt = true
  UFStyle.UpdateOverlayLevels(frame)
end

function UFStyle.ResolveFrameSize(cfg, totalWidthOverride)
  local width = Round(totalWidthOverride or (cfg and cfg.width) or 200)
  local height = Round(cfg and cfg.height or 22)
  local portraitDB = cfg and cfg.portrait

  if totalWidthOverride == nil
    and type(portraitDB) == "table"
    and portraitDB.enabled == true
  then
    width = Round(width + height)
  end

  return width, height
end

function UFStyle.CalculateFrameLayout(cfg, db, opts)
  opts = type(opts) == "table" and opts or {}

  local slider = db and db.borderEdgeSize
  if type(slider) ~= "number" or slider < 0 then
    slider = 0
  end

  local placement = (db and db.borderPlacement) or "inside"
  if placement ~= "outside" and placement ~= "inside" then
    placement = "inside"
  end

  local onePixel = ns.Pixel.GetOnePixel()
  local borderSize = math_max(1, BASE_SIZES.edgeSize + slider)
  local edgeSize = Round(borderSize * onePixel)
  local inset = Round(BASE_SIZES.inset * onePixel)
  if placement == "inside" then
    inset = edgeSize
  end

  local gap = Round(BASE_SIZES.gap * onePixel)
  local width, totalHeight = UFStyle.ResolveFrameSize(cfg, opts.totalWidthOverride)
  local powerHeight = (cfg and cfg.showPower ~= false) and Round((cfg and cfg.powerHeight) or 6) or 0

  if opts.forceNoPower == true then
    powerHeight = 0
  end

  local innerAvail = Round(math_max(1, totalHeight - inset * 2))
  if powerHeight > 0 then
    local maxPowerHeight = Round(math_max(0, innerAvail - gap - 1))
    if powerHeight > maxPowerHeight then
      powerHeight = maxPowerHeight
    end
  end

  local extraPower = (powerHeight > 0) and (gap + powerHeight) or 0
  local healthHeight = Round(math_max(1, innerAvail - extraPower))

  local portraitDB = cfg and cfg.portrait
  local portraitEnabled = type(portraitDB) == "table" and portraitDB.enabled == true
  local portraitSide = portraitEnabled and portraitDB.side == "RIGHT" and "RIGHT" or "LEFT"
  local portraitSize = portraitEnabled and totalHeight or 0

  local contentLeft = inset
  local contentRight = inset
  if portraitSize > 0 then
    if portraitSide == "RIGHT" then
      contentRight = inset + portraitSize
    else
      contentLeft = inset + portraitSize
    end
  end

  local cached = cfg and FrameLayoutCache[cfg]

  if cached
    and cached.width == width
    and cached.totalHeight == totalHeight
    and cached.powerHeight == powerHeight
    and cached.healthHeight == healthHeight
    and cached.inset == inset
    and cached.gap == gap
    and cached.edgeSize == edgeSize
    and cached.borderSize == borderSize
    and cached.placement == placement
    and cached.portraitEnabled == portraitEnabled
    and cached.portraitSide == portraitSide
    and cached.portraitSize == portraitSize
    and cached.contentLeft == contentLeft
    and cached.contentRight == contentRight
  then
    return cached
  end

  local layout = {
    width = width,
    totalHeight = totalHeight,
    powerHeight = powerHeight,
    healthHeight = healthHeight,
    inset = inset,
    gap = gap,
    edgeSize = edgeSize,
    borderSize = borderSize,
    placement = placement,
    portraitEnabled = portraitEnabled,
    portraitSide = portraitSide,
    portraitSize = portraitSize,
    contentLeft = contentLeft,
    contentRight = contentRight,
  }

  if cfg then
    FrameLayoutCache[cfg] = layout
  end

  return layout
end

function UFStyle.ConfigureFrameChrome(frame, layout, colors)
  if not frame or type(layout) ~= "table" then
    return
  end

  colors = colors or UFStyle.GetUFThemeColors() or {}

  local bg = colors.bg or { 0, 0, 0, 0.55 }
  local bd = colors.border or { 0.1, 0.1, 0.1, 1 }

  if not frame.__pui_bg then
    local t = frame:CreateTexture(nil, "BACKGROUND")
    Pixel.AllPoints(t, frame)
    frame.__pui_bg = t
  end

  Pixel.SetColorTexture(frame.__pui_bg, bg[1], bg[2], bg[3], bg[4] or 1)

  ns.IconSkin.ApplyBorder(frame, {
    enabled = true,
    thickness = layout.borderSize or 1,
    color = bd,
    placement = layout.placement or "inside",
  })

  ns.UFFrameGlow.InvalidateAnchorCache(frame)
end

function UFStyle.UpdateOverlayLevels(frame)
  if not frame then
    return
  end

  local healthBar = frame.Health
  local baseLevel = (healthBar and healthBar:GetFrameLevel()) or frame:GetFrameLevel() or 1
  local frameStrata = frame:GetFrameStrata() or "MEDIUM"

  if frame.RaisedElementParent then
    frame.RaisedElementParent:SetFrameStrata(frameStrata)
    frame.RaisedElementParent:SetFrameLevel(baseLevel + 10)
    frame.RaisedElementParent.RaidRoleLevel = baseLevel + 19
    frame.RaisedElementParent.AuraLevel = baseLevel + 20
    frame.RaisedElementParent.AuraWatchLevel = baseLevel + 25
    frame.RaisedElementParent.TrackingRootLevel = baseLevel + 25
  end

  if frame.TextureParent then
    frame.TextureParent:SetFrameStrata(frameStrata)
    frame.TextureParent:SetFrameLevel(baseLevel + 11)
  end

  if frame.textOverlay then
    frame.textOverlay:SetFrameStrata(frameStrata)
    frame.textOverlay:SetFrameLevel(baseLevel + 12)
  end
end

function UFStyle.UpdateFrameStyleElement(frame)
  UFStyle.RefreshFrameTextures(frame)
  UFStyle.UpdateOverlayLevels(frame)
end



  CopyFlatTable = P:Def("CopyFlatTable", CopyFlatTable)
  GetUF = P:Def("GetUF", GetUF)
  GetConfigMediaOverride = P:Def("GetConfigMediaOverride", GetConfigMediaOverride)
  GetUnitMediaOverride = P:Def("GetUnitMediaOverride", GetUnitMediaOverride)
  UFStyle.ResolveStatusbarTexture = P:Def("UFStyle.ResolveStatusbarTexture", UFStyle.ResolveStatusbarTexture)
  UFStyle.ResolveMedia = P:Def("UFStyle.ResolveMedia", UFStyle.ResolveMedia)
  UFStyle.GetUFThemeColors = P:Def("UFStyle.GetUFThemeColors", UFStyle.GetUFThemeColors)
  UFStyle.ApplyStyleIfNeeded = P:Def("UFStyle.ApplyStyleIfNeeded", UFStyle.ApplyStyleIfNeeded)
  UFStyle.RefreshFrameTextures = P:Def("UFStyle.RefreshFrameTextures", UFStyle.RefreshFrameTextures)
  UFStyle.RefreshAllFrameTextures = P:Def("UFStyle.RefreshAllFrameTextures", UFStyle.RefreshAllFrameTextures)
  UFStyle.CreateRaisedElement = P:Def("UFStyle.CreateRaisedElement", UFStyle.CreateRaisedElement)
  UFStyle.BuildUnitFrameVisuals = P:Def("UFStyle.BuildUnitFrameVisuals", UFStyle.BuildUnitFrameVisuals)
  UFStyle.ResolveFrameSize = P:Def("UFStyle.ResolveFrameSize", UFStyle.ResolveFrameSize)
  UFStyle.CalculateFrameLayout = P:Def("UFStyle.CalculateFrameLayout", UFStyle.CalculateFrameLayout)
  UFStyle.ConfigureFrameChrome = P:Def("UFStyle.ConfigureFrameChrome", UFStyle.ConfigureFrameChrome)
  UFStyle.UpdateOverlayLevels = P:Def("UFStyle.UpdateOverlayLevels", UFStyle.UpdateOverlayLevels)
  UFStyle.UpdateFrameStyleElement = P:Def("UFStyle.UpdateFrameStyleElement", UFStyle.UpdateFrameStyleElement)
