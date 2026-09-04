local ADDON_NAME, ns = ...

local Addon = ns.Addon
local BB = Addon:NewModule("PCM_BB")
ns.Modules.PCM_BB = BB

local P = ns.Pleebug:DropIn(BB, { name = "PCM", bucket = "CustomBuffBars" })

local function _PCM_BB_Enabled()
  if ns.PCM_IsTransitionPending() then
    return false
  end

  return ns.PCM_IsModuleEnabledFast() == true
end

local API = BB

local _G = _G
local Theme = ns.Theme
local Pixel = ns.Pixel
local Round = Pixel.Round
local FrameScale = ns.FrameScale
local IconSkin = ns.IconSkin
local AuraWidget = ns.AuraWidget
local AuraSlotDriver = ns.AuraSlotDriver
local BarWidget = ns.BarWidget
local FrameUtil = ns.FrameUtil
local LSM = ns.LSM
local Hooks = ns.PCMHooks
local PCMRuntime = ns.PCMRuntime
local Presentation = ns.Presentation
local PCMPresentation = ns.PCMPresentation
local CustomIcons = ns.PCMCustomIcons
local IsSecret = issecretvalue

local UnitClass           = _G.UnitClass
local UnitExists          = _G.UnitExists
local UnitIsUnit          = _G.UnitIsUnit
local C_CooldownViewer    = _G.C_CooldownViewer
local C_ClassTalents      = _G.C_ClassTalents
local wipe                = _G.wipe
local GetSpecialization   = _G.GetSpecialization
local GetSpecializationInfo = _G.GetSpecializationInfo
local InCombatLockdown    = _G.InCombatLockdown
local UnitAffectingCombat = _G.UnitAffectingCombat
local C_Spell             = _G.C_Spell
local C_Secrets = _G.C_Secrets
local C_StringUtil = _G.C_StringUtil
local _, PLAYER_CLASS = UnitClass("player")
local PLAYER_CLASS_COLOR = RAID_CLASS_COLORS[PLAYER_CLASS]


local VIEWER_KEY = "BuffIconCooldownViewer"

local _cache = {
  cm = nil,
  viewer = nil,
}

-- BB must not write custom fields onto Blizzard frames (Midnight "secret" taint risk).
-- Store all per-frame state in weak-key tables instead.
local _bbState = setmetatable({}, { __mode = "k" })

local function _BB_State(obj)
  if not obj then
    return nil
  end

  local st = _bbState[obj]
  if not st then
    st = {}
    _bbState[obj] = st
  end
  return st
end

local function _GetBuffsDB()
  if not _cache.cm then
    _cache.cm = ns.PCM_DBExports.GetProfileBuffsDB()
  end

  return _cache.cm
end

local function _GetViewer()
  local viewer = PCMRuntime:GetViewer(VIEWER_KEY)
  _cache.viewer = viewer
  return viewer
end

local AceGUI = LibStub("AceGUI-3.0")

-- Custom stack bars DB (per-profile, under the same CooldownManager root)
local function _GetStackBarsDB()
  local cm = _GetBuffsDB()
  cm.stackBars = cm.stackBars or {}
  ns.Modules.CooldownManager:MigrateLegacyCustomTrackerStore(cm.stackBars, "aura")
  return cm.stackBars
end

local _CustomBars = {
  frames = {},
  retiredFrames = {},
  barsByCooldownID = {},
  barsBySpellID = {},
  barsByIcon = setmetatable({}, { __mode = "k" }),
}

_CustomBars._lastCombatState = nil

-- Find the Blizzard cooldown "numbers" FontString on a CooldownFrame.
-- Works even if the region name differs across versions.
local function PUI_GetCooldownNumbersFontString(cooldownFrame)
  if not cooldownFrame or not cooldownFrame.GetRegions then
    return nil
  end

  local st = _BB_State(cooldownFrame)
  if st and st.numbersFS and st.numbersFS.GetObjectType then
    return st.numbersFS
  end

  local best
  local numRegions = select("#", cooldownFrame:GetRegions())
  for i = 1, numRegions do
    local r = select(i, cooldownFrame:GetRegions())
    if r and r.GetObjectType and r:GetObjectType() == "FontString" then
      local name = r.GetName and r:GetName() or nil
      if name and (name:find("Cooldown", 1, true) or name:find("Count", 1, true) or name:find("Text", 1, true)) then
        best = r
        break
      end
      best = best or r
    end
  end

  if st then
    st.numbersFS = best
  end
  return best
end

local _customBarsDefaultsGen = 2

local function _CustomBars_EnsureDefaults(cfg, id)
  cfg = cfg or {}
  ns.Modules.CooldownManager:NormalizeSpecAssignments(cfg)
  ns.Modules.CooldownManager:NormalizeCustomBarBuffGlow(cfg)
  cfg.kind = (type(cfg.kind) == "string" and cfg.kind ~= "") and cfg.kind or "stack"
  ns.Modules.CooldownManager:NormalizeCustomTrackerPresentation(cfg, cfg.kind)
  if cfg.kind ~= "duration" then
    AuraWidget.EnsureStackColorThresholds(cfg)
  end

  local gen = _customBarsDefaultsGen
  if cfg.__puiDefaultsGen == gen then
    return cfg
  end
  cfg.__puiDefaultsGen = gen

  cfg.id = cfg.id or id
  if cfg.enabled == nil then cfg.enabled = true end
  if cfg.hideOutOfCombat == nil then cfg.hideOutOfCombat = false end
  if cfg.outOfCombatAlpha == nil then cfg.outOfCombatAlpha = 0 end
  if cfg.showOnlyWhenActive == nil then cfg.showOnlyWhenActive = false end

  cfg.viewerName = (type(cfg.viewerName) == "string" and cfg.viewerName ~= "") and cfg.viewerName or VIEWER_KEY

  if cfg.auraTrackMode ~= "target_debuff" then
    cfg.auraTrackMode = "player_buff"
  end

  if type(cfg.label) ~= "string" or cfg.label == "" then
    if cfg.kind == "duration" then
      cfg.label = "Duration Bar " .. tostring(id or "")
    else
      cfg.label = "Stack Duration Bar " .. tostring(id or "")
    end
  end

  -- Hide this buff from the visible buff icon list (viewer), while still tracking stacks/duration.
  if cfg.hideViewerIcon == nil then cfg.hideViewerIcon = false end

  -- Optional: show the tracked spell icon next to the stack/duration bar.
  if cfg.showSpellIconNextToBar == nil then cfg.showSpellIconNextToBar = true end

  cfg.maxStacks = tonumber(cfg.maxStacks) or 3
  if cfg.kind == "duration" then
    cfg.maxStacks = 1
  end
  if cfg.maxStacks < 1 then cfg.maxStacks = 1 end
  if cfg.maxStacks > 30 then cfg.maxStacks = 30 end

  cfg.width  = tonumber(cfg.width) or 250
  cfg.height = tonumber(cfg.height) or 25

  if cfg.width < 50 then cfg.width = 50 end
  if cfg.width > 600 then cfg.width = 600 end
  if cfg.height < 5 then cfg.height = 5 end
  if cfg.height > 50 then cfg.height = 50 end

  -- Optional duration element (bar for TOP/BOTTOM, icon+swipe for LEFT/RIGHT).
  -- Duration-only bars are the duration element, so they must always drive duration.
  if cfg.kind == "duration" then
    cfg.showDuration = true
  else
    cfg.showDuration = cfg.showDuration == true
  end
  if cfg.hideDurationWhenMissing == nil then cfg.hideDurationWhenMissing = true end


  cfg.durationAnchor = (type(cfg.durationAnchor) == "string" and cfg.durationAnchor ~= "") and cfg.durationAnchor or "BOTTOM"

  cfg.durationHeight = tonumber(cfg.durationHeight) or 10
  if cfg.durationHeight < 2 then cfg.durationHeight = 2 end
  if cfg.durationHeight > 40 then cfg.durationHeight = 40 end

  cfg.durationIconSize = tonumber(cfg.durationIconSize) or nil
  if cfg.durationIconSize ~= nil then
    if cfg.durationIconSize < 8 then cfg.durationIconSize = 8 end
    if cfg.durationIconSize > 86 then cfg.durationIconSize = 86 end
  end

  -- Duration icon: allow hiding the spell texture while still showing swipe/numbers.
  if cfg.durationHideSpellIcon == nil then cfg.durationHideSpellIcon = false end

  -- Duration icon frame: allow hiding the entire icon (still keep the duration bar).
  if cfg.durationHideIconFrame == nil then cfg.durationHideIconFrame = false end

  cfg.durationCountFontSize = tonumber(cfg.durationCountFontSize) or 14
  if cfg.durationCountFontSize < 0 then cfg.durationCountFontSize = 0 end
  if cfg.durationCountFontSize > 32 then cfg.durationCountFontSize = 32 end

  cfg.durationGap = tonumber(cfg.durationGap) or 2
  if cfg.durationGap < 0 then cfg.durationGap = 0 end
  if cfg.durationGap > 20 then cfg.durationGap = 20 end

  if cfg.durationBarFillMode ~= "fill" and cfg.durationBarFillMode ~= "drain" then
    cfg.durationBarFillMode = "drain"
  end

  cfg.stackTexture = (cfg.stackTexture ~= "") and cfg.stackTexture or nil
  cfg.durationTexture = (cfg.durationTexture ~= "") and cfg.durationTexture or nil

  if not cfg.stackTexture then
    cfg.stackTexture = "Pleebar"
  end
  if not cfg.durationTexture then
    cfg.durationTexture = "Pleebar"
  end

  -- Duration bar fill color override (TOP/BOTTOM only). Nil = use stacks/class color behavior.
  cfg.durationBarColor = (type(cfg.durationBarColor) == "table") and cfg.durationBarColor or nil

  -- Duration icon border (LEFT/RIGHT only).
  cfg.durationIconBorderSize = tonumber(cfg.durationIconBorderSize) or 0
  if cfg.durationIconBorderSize < 0 then cfg.durationIconBorderSize = 0 end
  if cfg.durationIconBorderSize > 12 then cfg.durationIconBorderSize = 12 end
  cfg.durationIconBorderColor = (type(cfg.durationIconBorderColor) == "table") and cfg.durationIconBorderColor or nil

  -- Duration font settings (separate from charge text font).
  -- Nil means "use theme default".
  cfg.durationFont = (cfg.durationFont ~= "") and cfg.durationFont or nil
  cfg.durationOutline = (cfg.durationOutline ~= "") and cfg.durationOutline or nil

  -- Color behavior:
  if cfg.useClassColor == nil then
    cfg.useClassColor = true
  end

  cfg.barColor = (type(cfg.barColor) == "table") and cfg.barColor or nil

  local stdFontKey = Theme.STANDARD_FONT_KEY
  -- Nil means "use theme default". Never persist the standard key into the DB.
  if cfg.font == stdFontKey then
    cfg.font = nil
  end
  cfg.font = (cfg.font ~= "") and cfg.font or nil
  cfg.fontSize = tonumber(cfg.fontSize) or 14
  if cfg.fontSize < 0 then cfg.fontSize = 0 end
  if cfg.fontSize > 30 then cfg.fontSize = 30 end

  cfg.fontOffsetX = tonumber(cfg.fontOffsetX) or 0
  cfg.fontOffsetY = tonumber(cfg.fontOffsetY) or 0
  if cfg.fontOffsetX < -200 then cfg.fontOffsetX = -200 end
  if cfg.fontOffsetX >  200 then cfg.fontOffsetX =  200 end
  if cfg.fontOffsetY < -200 then cfg.fontOffsetY = -200 end
  if cfg.fontOffsetY >  200 then cfg.fontOffsetY =  200 end

  cfg.outline = (cfg.outline ~= "") and cfg.outline or nil

  cfg.pos = cfg.pos or {
    point = "CENTER",
    rel = "UIParent",
    relPoint = "CENTER",
    x = 0,
    y = 0,
  }

  return cfg
end

local function _CustomBars_GetAccentRGBA()
  local color = Theme.GetColors().accent
  return color[1], color[2], color[3], color[4]
end

local function _CustomBars_GetLayoutGeometry(cfg)
  local totalLength = Round(tonumber(cfg and cfg.width) or 250)
  local thickness = Round(tonumber(cfg and cfg.height) or 25)
  if totalLength < 1 then totalLength = 1 end
  if thickness < 1 then thickness = 1 end

  local isVertical = cfg and cfg.orientation == "vertical"
  local gap = Round(tonumber(cfg and cfg.durationGap) or 2)
  if gap < 0 then gap = 0 end

  local inlineKind
  local inlineAnchor
  local requestedIconSize

  if cfg and cfg.kind == "duration" then
    if cfg.durationHideIconFrame ~= true then
      inlineKind = "duration"
      inlineAnchor = isVertical and "BOTTOM" or "LEFT"
      requestedIconSize = tonumber(cfg.durationIconSize) or thickness
    end
  elseif cfg then
    local durationAnchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
    local durationUsesIcon = cfg.showDuration == true
      and (durationAnchor == "LEFT" or durationAnchor == "RIGHT")

    if durationUsesIcon then
      inlineKind = "duration"
      inlineAnchor = isVertical and "BOTTOM" or durationAnchor
      requestedIconSize = tonumber(cfg.durationIconSize) or thickness
    elseif cfg.showSpellIconNextToBar == true then
      inlineKind = "spell"
      inlineAnchor = isVertical and "BOTTOM" or "LEFT"
      requestedIconSize = thickness
    end
  end

  local inlineIconSize = 0
  if requestedIconSize then
    inlineIconSize = Round(requestedIconSize)
    if inlineIconSize < 1 then inlineIconSize = 1 end

    local maxInlineIconSize = math.max(1, totalLength - gap - 1)
    if inlineIconSize > maxInlineIconSize then
      inlineIconSize = maxInlineIconSize
    end
  end

  local mainLength = totalLength
  if inlineIconSize > 0 then
    mainLength = math.max(1, totalLength - inlineIconSize - gap)
  end

  local frameWidth = isVertical and thickness or mainLength
  local frameHeight = isVertical and mainLength or thickness
  local visualWidth = isVertical
    and math.max(thickness, inlineIconSize)
    or totalLength
  local visualHeight = isVertical
    and totalLength
    or math.max(thickness, inlineIconSize)

  return {
    totalLength = totalLength,
    thickness = thickness,
    isVertical = isVertical,
    gap = gap,
    inlineKind = inlineKind,
    inlineAnchor = inlineAnchor,
    inlineIconSize = inlineIconSize,
    mainLength = mainLength,
    frameWidth = frameWidth,
    frameHeight = frameHeight,
    visualWidth = visualWidth,
    visualHeight = visualHeight,
  }
end

API.GetCustomBarLayoutGeometry = _CustomBars_GetLayoutGeometry

local function _CustomBars_GetAnchorVisualOffset(cfg)
  local geometry = _CustomBars_GetLayoutGeometry(cfg)
  if geometry.inlineIconSize <= 0 then
    return 0, 0
  end

  local half = Round((geometry.inlineIconSize + geometry.gap) * 0.5)
  if geometry.inlineAnchor == "RIGHT" then
    return -half, 0
  elseif geometry.inlineAnchor == "BOTTOM" then
    return 0, half
  end

  return half, 0
end

local function _CustomBars_ApplyAnchor(f, cfg)
  if not (f and f.ClearAllPoints and f.SetPoint and UIParent) then
    return
  end

  local pos = cfg and cfg.pos or nil
  local point    = (pos and pos.point) or "CENTER"
  local relPoint = (pos and pos.relPoint) or "CENTER"
  local x = pos and tonumber(pos.x) or 0
  local y = pos and tonumber(pos.y) or 0
  local ox, oy = _CustomBars_GetAnchorVisualOffset(cfg)

  -- Pixel-snap anchors for crisp borders.
  x = Round((x or 0) + (ox or 0))
  y = Round((y or 0) + (oy or 0))

  f:ClearAllPoints()
  f:SetPoint(point, UIParent, relPoint, x, y)
end

local function _CustomBars_SaveAnchor(f, cfg)
  if not (f and cfg) then
    return
  end

  local x, y = FrameUtil._GetOffsetsForFrame(f)

  cfg.pos = cfg.pos or {}
  cfg.pos.point = "CENTER"
  cfg.pos.rel = "UIParent"
  cfg.pos.relPoint = "CENTER"
  cfg.pos.x = Round(x or 0)
  cfg.pos.y = Round(y or 0)
end

local function _CustomBars_ApplyExternalChrome(
  background,
  top,
  bottom,
  left,
  right,
  backgroundColor,
  borderColor,
  borderSize
)
  background:SetColorTexture(
    backgroundColor[1] or backgroundColor.r or 0.12,
    backgroundColor[2] or backgroundColor.g or 0.12,
    backgroundColor[3] or backgroundColor.b or 0.12,
    backgroundColor[4] or backgroundColor.a or 0.95
  )

  local r = borderColor[1] or borderColor.r or 0.20
  local g = borderColor[2] or borderColor.g or 0.20
  local b = borderColor[3] or borderColor.b or 0.24
  local a = borderColor[4] or borderColor.a or 1.00

  top:SetHeight(borderSize)
  top:SetColorTexture(r, g, b, a)
  bottom:SetHeight(borderSize)
  bottom:SetColorTexture(r, g, b, a)
  left:SetWidth(borderSize)
  left:SetColorTexture(r, g, b, a)
  right:SetWidth(borderSize)
  right:SetColorTexture(r, g, b, a)
end

local function _CustomBars_ApplyAppearance(f, cfg)
  if not (f and cfg) then
    return
  end

  local backgroundColor = { 0.12, 0.12, 0.12, 0.95 }
  local borderColor = { 0.20, 0.20, 0.24, 1.00 }

  if cfg.kind == "duration" then
    if type(cfg.backgroundColor) == "table" then
      backgroundColor = cfg.backgroundColor
    end
    if type(cfg.borderColor) == "table" then
      borderColor = cfg.borderColor
    end
  end

  local r, g, b, a = _CustomBars_GetAccentRGBA()
  if cfg.useClassColor ~= false then
    local classColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
    r, g, b = classColor.r, classColor.g, classColor.b
  elseif type(cfg.barColor) == "table" then
    r = cfg.barColor[1] or cfg.barColor.r or r
    g = cfg.barColor[2] or cfg.barColor.g or g
    b = cfg.barColor[3] or cfg.barColor.b or b
    a = cfg.barColor[4] or cfg.barColor.a or a
  end

  local presentation = PCMPresentation.BindCustomBar(f)
  Presentation.Apply("PCMBar", presentation, {
    skipGeometry = true,
    skipVisibility = true,
    applyBorder = false,
    config = cfg,
    texture = cfg.kind == "duration" and cfg.durationTexture or cfg.stackTexture,
    color = { r, g, b, a },
    backgroundColor = backgroundColor,
    font = cfg,
  })

  local borderSize = f.__puiBorderThickness or 2
  _CustomBars_ApplyExternalChrome(
    f.bg,
    f.__puiBorderTop,
    f.__puiBorderBottom,
    f.__puiBorderLeft,
    f.__puiBorderRight,
    backgroundColor,
    borderColor,
    borderSize
  )
  _CustomBars_ApplyExternalChrome(
    f.durBG,
    f.__puiDurBorderTop,
    f.__puiDurBorderBottom,
    f.__puiDurBorderLeft,
    f.__puiDurBorderRight,
    backgroundColor,
    borderColor,
    borderSize
  )

  local iconBorderSize = tonumber(cfg.durationIconBorderSize) or 0
  if iconBorderSize < 0 then iconBorderSize = 0 end
  if iconBorderSize > 12 then iconBorderSize = 12 end
  if iconBorderSize <= 0 then iconBorderSize = borderSize end

  local iconBorderColor = type(cfg.durationIconBorderColor) == "table"
    and cfg.durationIconBorderColor
    or borderColor

  _CustomBars_ApplyExternalChrome(
    f.durIconBG,
    f.__puiDurIconBorderTop,
    f.__puiDurIconBorderBottom,
    f.__puiDurIconBorderLeft,
    f.__puiDurIconBorderRight,
    backgroundColor,
    iconBorderColor,
    iconBorderSize
  )
  _CustomBars_ApplyExternalChrome(
    f.spellIconBG,
    f.__puiSpellIconBorderTop,
    f.__puiSpellIconBorderBottom,
    f.__puiSpellIconBorderLeft,
    f.__puiSpellIconBorderRight,
    backgroundColor,
    borderColor,
    borderSize
  )

  local texture = f.__puiTrackedSpellID
    and C_Spell.GetSpellTexture(f.__puiTrackedSpellID)
    or nil

  local showStaticDurationIcon = texture ~= nil
    and f.__puiDurHideSpellIcon ~= true
    and f.__puiShowOnlyWhenActive ~= true
  local showStaticSpellIcon = texture ~= nil
    and f.__puiShowSpellIconNextToBar == true
    and f.__puiShowOnlyWhenActive ~= true

  f.durIconTex:SetTexture(texture)
  f.durIconTex:SetShown(showStaticDurationIcon)
  f.spellIconTex:SetTexture(texture)
  f.spellIconTex:SetShown(showStaticSpellIcon)
end

local _CustomBars_ApplyVisibility
local _CustomBars_IsTrackedSpellAvailable
local _CustomBars_BindBarsToIcon
local _CustomBars_CompleteFrameRetirement
local _customBarsAuraDriver

local function _CustomBars_CreateChrome(frame)
  local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  background:SetAllPoints(frame)

  local top = frame:CreateTexture(nil, "BORDER")
  top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

  local bottom = frame:CreateTexture(nil, "BORDER")
  bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  local left = frame:CreateTexture(nil, "BORDER")
  left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)

  local right = frame:CreateTexture(nil, "BORDER")
  right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  return background, top, bottom, left, right
end

local function _CustomBars_CreateNativeAnchor(parent)
  local frame = CreateFrame("Frame", nil, parent)
  return frame, _CustomBars_CreateChrome(frame)
end

local function _CustomBars_EnsureFrame(id)
  local f = _CustomBars.frames[id]
  if f then
    return f
  end

  local retiredIndex = #_CustomBars.retiredFrames
  if retiredIndex > 0 then
    f = _CustomBars.retiredFrames[retiredIndex]
    _CustomBars.retiredFrames[retiredIndex] = nil
    f.__puiBarId = id
    f.__puiRetiredBarID = nil
    _CustomBars.frames[id] = f
    return f
  end

  local name = "PleebUI_PCM_CustomBar_" .. tostring(id)
  f = CreateFrame("Frame", name, UIParent)
  f:SetSize(180, 10)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f.__puiBorderThickness = 2

  f.cdmStackBar = CreateFrame("StatusBar", nil, f)
  f.cdmStackBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  f.cdmStackBar:SetMinMaxValues(0, 1)
  f.cdmStackBar:SetValue(0)
  f.cdmStackBar:Hide()

  f.bg,
    f.__puiBorderTop,
    f.__puiBorderBottom,
    f.__puiBorderLeft,
    f.__puiBorderRight = _CustomBars_CreateChrome(f)

  f.durFrame,
    f.durBG,
    f.__puiDurBorderTop,
    f.__puiDurBorderBottom,
    f.__puiDurBorderLeft,
    f.__puiDurBorderRight = _CustomBars_CreateNativeAnchor(f)

  f.durIconFrame,
    f.durIconBG,
    f.__puiDurIconBorderTop,
    f.__puiDurIconBorderBottom,
    f.__puiDurIconBorderLeft,
    f.__puiDurIconBorderRight = _CustomBars_CreateNativeAnchor(f)

  f.durIconTex = f.durIconFrame:CreateTexture(nil, "ARTWORK")
  f.durIconTex:SetAllPoints(f.durIconFrame)
  f.durIconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  f.spellIconFrame,
    f.spellIconBG,
    f.__puiSpellIconBorderTop,
    f.__puiSpellIconBorderBottom,
    f.__puiSpellIconBorderLeft,
    f.__puiSpellIconBorderRight = _CustomBars_CreateNativeAnchor(f)

  f.spellIconTex = f.spellIconFrame:CreateTexture(nil, "ARTWORK")
  f.spellIconTex:SetAllPoints(f.spellIconFrame)
  f.spellIconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  f.__puiBarId = id
  f.__puiPCMBarPresentation = PCMPresentation.BindCustomBar(f)
  _CustomBars.frames[id] = f
  return f
end

_CustomBars_CompleteFrameRetirement = function(f)
  if not (f and f.__puiRetiredBarID ~= nil) then
    return
  end

  f.__puiRetiredBarID = nil
  f.__puiBarId = nil
  f.__puiCBBVisShown = nil
  f.__puiCBBVisHidden = true
  f.__puiCBBVisAlpha = nil
  f:Hide()
  f:ClearAllPoints()
  _CustomBars.retiredFrames[#_CustomBars.retiredFrames + 1] = f
end

local function _CustomBars_LayoutNativeFrame(f, cfg)
  local geometry = _CustomBars_GetLayoutGeometry(cfg)
  local isVertical = geometry.isVertical
  local gap = geometry.gap

  f:SetSize(geometry.frameWidth, geometry.frameHeight)

  local border = Round(tonumber(cfg.borderSize) or 2)
  if border < 0 then border = 0 end
  if border > 12 then border = 12 end
  f.__puiBorderThickness = border

  if cfg.kind == "duration" then
    f.durFrame:ClearAllPoints()
    f.durFrame:SetPoint("TOPLEFT", f, "TOPLEFT", border, -border)
    f.durFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -border, border)

    local hideIconFrame = cfg.durationHideIconFrame == true
    local iconSize = geometry.inlineIconSize

    f.durIconFrame:ClearAllPoints()
    if iconSize > 0 then
      if isVertical then
        f.durIconFrame:SetPoint("TOP", f, "BOTTOM", 0, -gap)
      else
        f.durIconFrame:SetPoint("RIGHT", f, "LEFT", -gap, 0)
      end
      f.durIconFrame:SetSize(iconSize, iconSize)
    end
    f.durIconFrame:SetShown(not hideIconFrame and iconSize > 0)

    f.spellIconFrame:Hide()
    f.__puiIsDurationOnly = true
    f.__puiDurEnabled = true
    f.__puiDurAnchor = "DURATION_ONLY"
    f.__puiDurUseIcon = false
    f.__puiDurHideIconFrame = hideIconFrame
    return
  end

  f.__puiIsDurationOnly = false

  local durationEnabled = cfg.showDuration == true
  local durationAnchor = tostring(cfg.durationAnchor or "BOTTOM"):upper()
  local durationUsesIcon = geometry.inlineKind == "duration"
  f.__puiDurEnabled = durationEnabled
  f.__puiDurAnchor = durationAnchor
  f.__puiDurUseIcon = durationUsesIcon
  f.__puiDurHideIconFrame = false
  f.__puiShowSpellIconNextToBar = cfg.showSpellIconNextToBar == true

  f.durFrame:ClearAllPoints()
  if durationEnabled and not durationUsesIcon then
    if durationAnchor == "TOP" then
      f.durFrame:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, gap)
      f.durFrame:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, gap)
    else
      f.durFrame:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -gap)
      f.durFrame:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -gap)
    end
    f.durFrame:SetHeight(Round(tonumber(cfg.durationHeight) or 10))
    f.durFrame:Show()
  else
    f.durFrame:Hide()
  end

  f.durIconFrame:ClearAllPoints()
  if durationUsesIcon then
    local iconSize = geometry.inlineIconSize

    if isVertical then
      f.durIconFrame:SetPoint("TOP", f, "BOTTOM", 0, -gap)
    elseif geometry.inlineAnchor == "LEFT" then
      f.durIconFrame:SetPoint("RIGHT", f, "LEFT", -gap, 0)
    else
      f.durIconFrame:SetPoint("LEFT", f, "RIGHT", gap, 0)
    end
    f.durIconFrame:SetSize(iconSize, iconSize)
    f.durIconFrame:Show()
  else
    f.durIconFrame:Hide()
  end

  f.spellIconFrame:ClearAllPoints()
  if geometry.inlineKind == "spell" then
    local iconSize = geometry.inlineIconSize
    if isVertical then
      f.spellIconFrame:SetPoint("TOP", f, "BOTTOM", 0, -gap)
    else
      f.spellIconFrame:SetPoint("RIGHT", f, "LEFT", -gap, 0)
    end
    f.spellIconFrame:SetSize(iconSize, iconSize)
    f.spellIconFrame:Show()
  else
    f.spellIconFrame:Hide()
  end
end

local function _CustomBars_RebuildSegments(f, cfg)
  if not (f and cfg) then
    return
  end

  _CustomBars_LayoutNativeFrame(f, cfg)
  _CustomBars_ApplyAppearance(f, cfg)
end

local function _CustomBars_RegisterMover(id, f, cfg)
  if not _PCM_BB_Enabled() then
    return
  end

  local key = "PCM_CustomStackBar_" .. tostring(id)
  local moverOpts = {
    label = ns.Modules.CooldownManager:GetCustomBarDisplayName(cfg),
    optionsString = "CooldownManager,custom_bars,bb:" .. tostring(id),
    liveFrame = function()
      return f
    end,
    shouldShow = function()
      return cfg and cfg.enabled ~= false and _CustomBars_IsTrackedSpellAvailable(cfg)
    end,
    onDragStop = function(frame)
      _CustomBars_SaveAnchor(frame or f, cfg)
      _CustomBars_ApplyAnchor(f, cfg)
      FrameUtil:RefreshGhostMover(key)
    end,
    quickSettings = function()
      local function RefreshGeometry()
        _CustomBars_RebuildSegments(f, cfg)
        FrameUtil:RefreshGhostMover(key)
        FrameUtil.RefreshSmartSnapState(key)
      end

      local function Rebuild()
        API.RebuildCustomBars()
        FrameUtil:RefreshGhostMover(key)
        FrameUtil.RefreshSmartSnapState(key)
      end

      return {
        ownerKey = key,
        title = ns.Modules.CooldownManager:GetCustomBarDisplayName(cfg),
        description = "Live aura bar settings.",
        controls = {
          {
            type = "slider",
            label = "Total width",
            min = 50,
            max = 600,
            step = 1,
            commitOnRelease = true,
            get = function() return cfg.width or 250 end,
            set = function(value) cfg.width = value RefreshGeometry() end,
          },
          {
            type = "slider",
            label = "Height",
            min = 5,
            max = 50,
            step = 1,
            commitOnRelease = true,
            get = function() return cfg.height or 25 end,
            set = function(value) cfg.height = value RefreshGeometry() end,
          },
          {
            type = "statusbar",
            label = "Texture",
            values = ns.OptionsUtil.BuildStatusbarValues(false),
            get = function() return cfg.stackTexture or cfg.durationTexture or "Pleebar" end,
            set = function(value)
              cfg.stackTexture = value
              cfg.durationTexture = value
              Rebuild()
            end,
          },
          {
            type = "slider",
            label = "Border size",
            min = 0,
            max = 12,
            step = 1,
            get = function() return cfg.borderSize or 2 end,
            set = function(value) cfg.borderSize = value Rebuild() end,
          },
          {
            type = "slider",
            label = "Font size",
            min = 0,
            max = 30,
            step = 1,
            get = function() return cfg.fontSize or 14 end,
            set = function(value) cfg.fontSize = value Rebuild() end,
          },
        },
      }
    end,
    smartSnap = {
      family = "combatBars",
      syncAxis = "WIDTH",
      syncWidthMin = cfg.orientation == "vertical" and 5 or 50,
      syncWidthMax = cfg.orientation == "vertical" and 50 or 600,
      getSyncWidth = function()
        if cfg.orientation == "vertical" then
          return cfg.height
        end
        return cfg.width
      end,
      applySyncWidth = function(width)
        if cfg.orientation == "vertical" then
          cfg.height = Round(width)
        else
          cfg.width = Round(width)
        end
        _CustomBars_RebuildSegments(f, cfg)
        FrameUtil:RefreshGhostMover(key)
      end,
      getDesign = function()
        local function CopyColor(color)
          if type(color) ~= "table" then return nil end
          return { color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a }
        end
        return {
          texture = cfg.stackTexture or cfg.durationTexture,
          borderSize = cfg.borderSize,
          borderColor = CopyColor(cfg.borderColor),
          backgroundColor = CopyColor(cfg.backgroundColor),
        }
      end,
      applyDesign = function(design)
        if type(design) ~= "table" then return end
        local function CopyColor(color)
          if type(color) ~= "table" then return nil end
          return { color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a }
        end
        if design.texture ~= nil then
          cfg.stackTexture = design.texture
          cfg.durationTexture = design.texture
        end
        if design.borderSize ~= nil then cfg.borderSize = Round(design.borderSize) end
        if type(design.borderColor) == "table" then cfg.borderColor = CopyColor(design.borderColor) end
        if type(design.backgroundColor) == "table" then cfg.backgroundColor = CopyColor(design.backgroundColor) end
        API.RebuildCustomBars()
        FrameUtil:RefreshGhostMover(key)
      end,
    },
  }

  FrameUtil:EnsureGhostMover(key, moverOpts)
end


_CustomBars_ApplyVisibility = function(f, cfg, isInCombat)
  if isInCombat == nil then
    isInCombat = UnitAffectingCombat("player") == true
  end
  CustomIcons:RefreshVisibility("aura:" .. tostring(f.__puiBarId), isInCombat)
  if cfg.presentation ~= "BAR" then
    f:Hide()
    f.__puiCBBVisShown = nil
    f.__puiCBBVisHidden = true
    return
  end

  if f.__puiCBBVisShown ~= true then
    f:Show()
    f.__puiCBBVisShown = true
    f.__puiCBBVisHidden = nil
  end

  local hideWhenInactive = false
  if f.__puiShowOnlyWhenActive == true then
    if f.__puiIsDurationOnly then
      hideWhenInactive = f.__puiHasActiveDurationObject ~= true
    else
      hideWhenInactive = f.__puiHasActiveAura ~= true
    end
  end

  local alpha = 1
  if hideWhenInactive then
    alpha = 0
  elseif cfg and (cfg.hideOutOfCombat == true or cfg.hideOutOfCombat == 1) then
    if isInCombat == nil then
      isInCombat = UnitAffectingCombat("player") == true
    end
    if isInCombat ~= true then
      local value = tonumber(cfg.outOfCombatAlpha) or 0
      if value < 0 then value = 0 end
      if value > 100 then value = 100 end
      alpha = value / 100
    end
  end

  if f.__puiCBBVisAlpha ~= alpha then
    f.__puiCBBVisAlpha = alpha
    f:SetAlpha(alpha)
  end
  local attachment = _customBarsAuraDriver.attachments[f]
  local auraButton = attachment and attachment.slot and attachment.slot.button
  if auraButton then
    local activeAlpha = cfg.activeAuraEnabled == true
      and (tonumber(cfg.activeAlpha) or 100) / 100 or 1
    auraButton:SetAlpha(alpha * activeAlpha)
  end
  PCMPresentation.SetCustomBarBuffGlowContextAlpha(
    "buff:" .. tostring(f.__puiBarId),
    alpha
  )
end

local function _CustomBars_ApplyConfig(id, cfg)
  if not cfg then
    return
  end

  local isLoaded = cfg.enabled ~= false
    and (cfg.presentation == "BAR" or cfg.presentation == "BUTTON")
    and _CustomBars_IsTrackedSpellAvailable(cfg)
  if not isLoaded then
    local f = _CustomBars.frames[id]
    if f then
      PCMPresentation.DisableCustomBarBuffGlow("buff:" .. tostring(id))
      CustomIcons:Release("aura:" .. tostring(id))
      _customBarsAuraDriver:Detach(f)
      f.__puiCfg = nil
      f.__puiIsActive = false
      f.__puiHasActiveAura = false
      f.__puiHasActiveDurationObject = false
      f:SetAlpha(0)
      f:Hide()
      f.__puiCBBVisHidden = true
      f.__puiCBBVisShown = nil
      f.__puiCBBVisAlpha = 0
    end

    local moverKey = "PCM_CustomStackBar_" .. tostring(id)
    local ghost = FrameUtil:RefreshGhostMover(moverKey)
    if ghost then
      ghost:Hide()
    end
    FrameUtil:UnregisterMover(moverKey)
    return
  end

  local f = _CustomBars_EnsureFrame(id)
  _CustomBars_ApplyAnchor(f, cfg)

  f.__puiTrackedSpellID = tonumber(cfg.trackedSpellID) or nil
  f.__puiShowSpellIconNextToBar = cfg.showSpellIconNextToBar == true
  f.__puiDurHideSpellIcon = cfg.durationHideSpellIcon == true
  f.__puiDurHideIconFrame = cfg.durationHideIconFrame == true
  f.__puiIsDurationOnly = cfg.kind == "duration"
  f.__puiDurAnchor = f.__puiIsDurationOnly
    and "DURATION_ONLY"
    or tostring(cfg.durationAnchor or "BOTTOM"):upper()
  f.__puiDurEnabled = cfg.showDuration ~= false
  f.__puiShowOnlyWhenActive = cfg.showOnlyWhenActive == true or cfg.showOnlyWhenActive == 1
  f.__puiFontSize = tonumber(cfg.fontSize) or 14
  f.__puiCfg = cfg

  _CustomBars_RebuildSegments(f, cfg)
  if cfg.presentation == "BAR" then
    PCMPresentation.ConfigureCustomBarBuffGlow("buff:" .. tostring(id), f, cfg)
    _customBarsAuraDriver:Attach(f, cfg)
    f:Show()
    _CustomBars_RegisterMover(id, f, cfg)
  else
    PCMPresentation.DisableCustomBarBuffGlow("buff:" .. tostring(id))
    _customBarsAuraDriver:Detach(f)
    f:Hide()
    FrameUtil:UnregisterMover("PCM_CustomStackBar_" .. tostring(id))
  end

  if cfg.presentation == "BUTTON" then
    local unit, filter = _CustomBars_GetAuraTrackUnitAndFilter(cfg)
    local candidate = _customBarsAuraDriver:ResolveCandidate(cfg)
    CustomIcons:ConfigureAura("aura:" .. tostring(id), cfg, {
      auraKind = cfg.kind,
      label = ns.Modules.CooldownManager:GetCustomBarDisplayName(cfg) .. " icon",
      optionsString = "CooldownManager,custom_bars,bb:" .. tostring(id),
      moverKey = "PCM_CustomAuraIcon_" .. tostring(id),
      defaultY = -60 - ((id - 1) * 50),
      spellID = tonumber(cfg.trackedSpellID),
      texture = C_Spell.GetSpellTexture(cfg.trackedSpellID),
      inCombat = UnitAffectingCombat("player") == true,
      unit = unit,
      filter = filter,
      candidateSpellIDs = candidate.spellIDs,
      maximum = cfg.kind == "duration" and 1 or cfg.maxStacks,
    })
  else
    CustomIcons:Release("aura:" .. tostring(id))
  end

  _CustomBars_ApplyVisibility(f, cfg, nil)
end

local function _CustomBars_AddSourceIndex(index, key, id)
  if type(key) ~= "number" then
    return
  end

  local bucket = index[key]
  if not bucket then
    bucket = {}
    index[key] = bucket
  end

  bucket[id] = true
end

local function _CustomBars_RebuildAll()
  local db = _GetStackBarsDB()
  if not db then
    return
  end

  wipe(_CustomBars.barsByCooldownID)
  wipe(_CustomBars.barsBySpellID)
  wipe(_CustomBars.barsByIcon)

  for id, cfg in pairs(db) do
    if type(id) == "number" and type(cfg) == "table" then
      db[id] = _CustomBars_EnsureDefaults(cfg, id)
      _CustomBars_ApplyConfig(id, db[id])

      local appliedCfg = db[id]
      local f = _CustomBars.frames[id]
      if f and f.__puiCfg == appliedCfg then
        _CustomBars_AddSourceIndex(_CustomBars.barsByCooldownID, appliedCfg.__puiCooldownID, id)
        _CustomBars_AddSourceIndex(_CustomBars.barsBySpellID, tonumber(appliedCfg.trackedSpellID), id)
      end
    end
  end

  local staleIDs = {}
  for id in pairs(_CustomBars.frames) do
    if not db[id] then
      staleIDs[#staleIDs + 1] = id
    end
  end

  for i = 1, #staleIDs do
    local id = staleIDs[i]
    local f = _CustomBars.frames[id]
    if f then
      PCMPresentation.ReleaseCustomBarBuffGlow("buff:" .. tostring(id))
      CustomIcons:Delete("aura:" .. tostring(id))
      f.__puiCfg = nil
      f.__puiRetiredBarID = id
      _CustomBars.frames[id] = nil
      _customBarsAuraDriver:Release(f)
    end
  end
end

local _BB_EnsureViewerAuraHooks
local _CustomBars_SetViewerIconHidden
local _CustomBars_GetIconCooldownID
local _CustomBars_GetIconSpellID
local _GetViewerIcons

local _BB_EnsureViewerAuraIconHook

local function ApplyConfiguredViewerHiddenState(icon, bucket)
  local hide = false

  if bucket then
    local db = _GetStackBarsDB()
    for id in pairs(bucket) do
      local cfg = db[id]
      if cfg and cfg.enabled ~= false and cfg.hideViewerIcon == true then
        hide = true
        break
      end
    end
  end

  _CustomBars_SetViewerIconHidden(icon, hide)
end

_BB_EnsureViewerAuraIconHook = function(icon)
  if not icon or (icon.IsForbidden and icon:IsForbidden()) then
    return nil
  end

  local bucket = _CustomBars_BindBarsToIcon(icon)
  ApplyConfiguredViewerHiddenState(icon, bucket)
  return bucket
end

local function _BB_ResetViewerIconIdentity(icon)
  if not icon then
    return
  end

  local state = _BB_State(icon)
  state.cooldownID = nil
  state.spellID = nil
  state.identityDirty = nil
  state.refreshPending = nil
  _CustomBars.barsByIcon[icon] = nil

  local bucket = _BB_EnsureViewerAuraIconHook(icon)
  if not bucket then
    _CustomBars_SetViewerIconHidden(icon, false)
  end
end


_BB_EnsureViewerAuraHooks = function(viewer)
  local v = viewer or _cache.viewer or _GetViewer()
  if not v then
    return
  end

  local children = _GetViewerIcons(v)
  if type(children) ~= "table" then
    return
  end

  for i = 1, #children do
    _BB_EnsureViewerAuraIconHook(children[i])
  end
end

local __PUI_PCM_BB_ActiveFrameBuffer = {}

local function _BB_ClearActiveFrameBuffer()
  wipe(__PUI_PCM_BB_ActiveFrameBuffer)
end

_GetViewerIcons = function(viewer)
  if not viewer or (viewer.IsForbidden and viewer:IsForbidden()) then
    return nil
  end

  _BB_ClearActiveFrameBuffer()

  local items = PCMRuntime:GetViewerItems(viewer)
  for index = 1, #items do
    local itemFrame = items[index]
    if itemFrame and not (itemFrame.IsForbidden and itemFrame:IsForbidden()) then
      __PUI_PCM_BB_ActiveFrameBuffer[#__PUI_PCM_BB_ActiveFrameBuffer + 1] = itemFrame
    end
  end

  return __PUI_PCM_BB_ActiveFrameBuffer
end




_CustomBars_IsTrackedSpellAvailable = function(cfg)
  if not ns.Modules.CooldownManager:AllowsCurrentSpecialization(cfg) then
    cfg.__puiCooldownID = nil
    cfg.__puiTrackedAvailable = false
    return false
  end

  local trackedSpellID = tonumber(cfg.trackedSpellID)
  if not trackedSpellID or trackedSpellID <= 0 then
    cfg.__puiCooldownID = nil
    cfg.__puiTrackedAvailable = false
    return false
  end

  if InCombatLockdown() then
    return cfg.__puiTrackedAvailable == true
  end

  local cooldownID = ns.Modules.CooldownManager:ResolveCustomBarAuraEntry(
    trackedSpellID,
    cfg.__puiCooldownID
  )
  local available = false

  if cooldownID then
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
    if info and info.isKnown ~= nil then
      available = info.isKnown == true
    end
  end

  if not available then
    available = ns.Modules.CooldownManager:DoesPlayerKnowSavedSpell(trackedSpellID) == true
  end

  cfg.__puiCooldownID = cooldownID
  cfg.__puiTrackedAvailable = available
  return available
end

_CustomBars_GetIconCooldownID = function(icon)
  local cooldownID = icon:GetCooldownID()
  if IsSecret(cooldownID) or type(cooldownID) ~= "number" then
    return nil
  end

  _BB_State(icon).cooldownID = cooldownID
  return cooldownID
end

_CustomBars_GetIconSpellID = function(icon)
  local spellID = icon:GetSpellID()
  if IsSecret(spellID) or type(spellID) ~= "number" then
    return nil
  end

  _BB_State(icon).spellID = spellID
  return spellID
end

_CustomBars_BindBarsToIcon = function(icon)
  if not icon then
    return nil
  end

  local cooldownID = _CustomBars_GetIconCooldownID(icon)
  local spellID = _CustomBars_GetIconSpellID(icon)
  local current = _CustomBars.barsByIcon[icon]

  if type(cooldownID) ~= "number" and type(spellID) ~= "number" then
    return current
  end

  local bucket = current
  if not bucket then
    bucket = {}
    _CustomBars.barsByIcon[icon] = bucket
  else
    wipe(bucket)
  end

  if type(cooldownID) == "number" then
    local cooldownBucket = _CustomBars.barsByCooldownID[cooldownID]
    if cooldownBucket then
      for id in pairs(cooldownBucket) do
        bucket[id] = true
      end
    end
  end

  if type(spellID) == "number" then
    local spellBucket = _CustomBars.barsBySpellID[spellID]
    if spellBucket then
      for id in pairs(spellBucket) do
        bucket[id] = true
      end
    end
  end

  if next(bucket) == nil then
    _CustomBars.barsByIcon[icon] = nil
    return nil
  end

  return bucket
end

local function _CustomBars_NormalizeAuraTrackMode(mode)
  if mode == "target_debuff" then
    return "target_debuff"
  end

  return "player_buff"
end

local function _CustomBars_GetAuraTrackUnitAndFilter(cfg)
  local mode = _CustomBars_NormalizeAuraTrackMode(type(cfg) == "table" and cfg.auraTrackMode or cfg)

  if mode == "target_debuff" then
    return "target", "HARMFUL|PLAYER", mode
  end

  return "player", "HELPFUL|PLAYER", "player_buff"
end

_customBarsAuraDriver = {
  attachments = setmetatable({}, { __mode = "k" }),
  slotCache = setmetatable({}, { __mode = "k" }),
  candidateCache = setmetatable({}, { __mode = "k" }),
  styleDeferred = setmetatable({}, { __mode = "k" }),
}

function _customBarsAuraDriver:IsButtonRestyleLocked()
  return C_Secrets.ShouldAurasBeSecret() == true
end

function _customBarsAuraDriver:InvalidateCandidateCache()
  wipe(self.candidateCache)
end

function _customBarsAuraDriver:ResolveCandidate(cfg)
  local trackedSpellID = tonumber(cfg.trackedSpellID)
  local cooldownID = tonumber(cfg.__puiCooldownID)
  local candidate = self.candidateCache[cfg]

  if candidate
    and candidate.trackedSpellID == trackedSpellID
    and candidate.cooldownID == cooldownID
  then
    return candidate
  end

  local resolvedCooldownID, spellIDs = ns.Modules.CooldownManager:ResolveCustomBarAuraEntry(
    trackedSpellID,
    cooldownID
  )
  if resolvedCooldownID then
    cooldownID = resolvedCooldownID
    cfg.__puiCooldownID = cooldownID
  end

  if type(spellIDs) ~= "table" then
    spellIDs = { [trackedSpellID] = true }
  end

  local signatureParts = {}
  for spellID in pairs(spellIDs) do
    signatureParts[#signatureParts + 1] = spellID
  end
  table.sort(signatureParts)

  candidate = {
    trackedSpellID = trackedSpellID,
    cooldownID = cooldownID,
    spellIDs = spellIDs,
    signature = table.concat(signatureParts, ":"),
  }
  self.candidateCache[cfg] = candidate
  return candidate
end

local function _CustomBars_HasEnabledStackColorThreshold(cfg)
  local thresholds = cfg and cfg.stackColorThresholds
  if type(thresholds) ~= "table" then
    return false
  end

  for index = 1, #thresholds do
    if thresholds[index].enabled == true then
      return true
    end
  end

  return false
end

function _customBarsAuraDriver:SetSlotAttached(sub, attached)
  attached = attached == true
  if sub.attached == attached then
    return
  end

  sub.attached = attached
  AuraSlotDriver:SetSlotActive(sub.auraSlot, attached)
end

function _customBarsAuraDriver:ApplyFont(target, fontKey, fontSize, fontFlags)
  if fontKey == Theme.STANDARD_FONT_KEY then
    fontKey = nil
  end

  local fontPath = fontKey and LSM:Fetch("font", fontKey, true)
    or LSM:Fetch("font", Theme.STANDARD_FONT_KEY, true)
  if not fontPath and GameFontNormal then
    fontPath = GameFontNormal:GetFont()
  end

  if fontFlags == "NONE" then
    fontFlags = nil
  end

  fontSize = tonumber(fontSize) or 14
  if target.__puiFontPath ~= fontPath
    or target.__puiFontSize ~= fontSize
    or target.__puiFontFlags ~= fontFlags
  then
    target.__puiFontPath = fontPath
    target.__puiFontSize = fontSize
    target.__puiFontFlags = fontFlags
    target:SetFont(fontPath, fontSize, fontFlags)
  end

  target:SetTextColor(1, 1, 1, 1)
  target:SetShadowColor(0, 0, 0, 1)
  target:SetShadowOffset(1, -1)
end

function _customBarsAuraDriver:GetBarAppearance(cfg, duration)
  local textureKey = duration and cfg.durationTexture or cfg.stackTexture
  local texturePath = BarWidget.ResolveStatusBarTexture(textureKey)
  local orientation = cfg.orientation == "vertical" and "VERTICAL" or "HORIZONTAL"
  local direction = tostring(cfg.fillDirection or ""):upper()
  local reverseFill = orientation == "VERTICAL" and direction == "DOWN"
    or orientation == "HORIZONTAL" and direction == "LEFT"

  local r, g, b, a = _CustomBars_GetAccentRGBA()
  if cfg.useClassColor ~= false then
    local classColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
    r, g, b = classColor.r, classColor.g, classColor.b
  elseif type(cfg.barColor) == "table" then
    r = cfg.barColor[1] or cfg.barColor.r or r
    g = cfg.barColor[2] or cfg.barColor.g or g
    b = cfg.barColor[3] or cfg.barColor.b or b
    a = cfg.barColor[4] or cfg.barColor.a or a
  end

  if duration and type(cfg.durationBarColor) == "table" then
    r = cfg.durationBarColor[1] or cfg.durationBarColor.r or r
    g = cfg.durationBarColor[2] or cfg.durationBarColor.g or g
    b = cfg.durationBarColor[3] or cfg.durationBarColor.b or b
    a = cfg.durationBarColor[4] or cfg.durationBarColor.a or a
  end

  return texturePath, orientation, reverseFill, r, g, b, a
end


function _customBarsAuraDriver:CreateChrome(button)
  return {
    background = button:CreateTexture(nil, "BACKGROUND", nil, -8),
    top = button:CreateTexture(nil, "OVERLAY", nil, 7),
    bottom = button:CreateTexture(nil, "OVERLAY", nil, 7),
    left = button:CreateTexture(nil, "OVERLAY", nil, 7),
    right = button:CreateTexture(nil, "OVERLAY", nil, 7),
  }
end

function _customBarsAuraDriver:ApplyChrome(chrome, target, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA, borderSize, shown)
  chrome.background:ClearAllPoints()
  chrome.background:SetAllPoints(target)
  chrome.background:SetColorTexture(bgR, bgG, bgB, bgA)

  chrome.top:ClearAllPoints()
  chrome.top:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
  chrome.top:SetPoint("TOPRIGHT", target, "TOPRIGHT", 0, 0)
  chrome.top:SetHeight(borderSize)
  chrome.top:SetColorTexture(borderR, borderG, borderB, borderA)

  chrome.bottom:ClearAllPoints()
  chrome.bottom:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", 0, 0)
  chrome.bottom:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
  chrome.bottom:SetHeight(borderSize)
  chrome.bottom:SetColorTexture(borderR, borderG, borderB, borderA)

  chrome.left:ClearAllPoints()
  chrome.left:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
  chrome.left:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", 0, 0)
  chrome.left:SetWidth(borderSize)
  chrome.left:SetColorTexture(borderR, borderG, borderB, borderA)

  chrome.right:ClearAllPoints()
  chrome.right:SetPoint("TOPRIGHT", target, "TOPRIGHT", 0, 0)
  chrome.right:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
  chrome.right:SetWidth(borderSize)
  chrome.right:SetColorTexture(borderR, borderG, borderB, borderA)

  chrome.background:SetShown(shown)
  chrome.top:SetShown(shown)
  chrome.bottom:SetShown(shown)
  chrome.left:SetShown(shown)
  chrome.right:SetShown(shown)
end

function _customBarsAuraDriver:SetExternalChromeShown(background, top, bottom, left, right, shown)
  background:SetShown(shown)
  top:SetShown(shown)
  bottom:SetShown(shown)
  left:SetShown(shown)
  right:SetShown(shown)
end

function _customBarsAuraDriver:GetChromeColors(cfg)
  local bgR, bgG, bgB, bgA = 0.12, 0.12, 0.12, 0.95
  local borderR, borderG, borderB, borderA = 0.20, 0.20, 0.24, 1.00

  if cfg.kind == "duration" then
    local background = cfg.backgroundColor
    if type(background) == "table" then
      bgR = background[1] or background.r or bgR
      bgG = background[2] or background.g or bgG
      bgB = background[3] or background.b or bgB
      bgA = background[4] or background.a or bgA
    end

    local border = cfg.borderColor
    if type(border) == "table" then
      borderR = border[1] or border.r or borderR
      borderG = border[2] or border.g or borderG
      borderB = border[3] or border.b or borderB
      borderA = border[4] or border.a or borderA
    end
  end

  return bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA
end

function _customBarsAuraDriver:UpdateActivity(f)
  local attachment = self.attachments[f]
  local sub = attachment and attachment.slot or nil
  local configured = sub ~= nil and sub.attached == true
  local durationEnabled = f.__puiDurEnabled ~= false
  local durationOnly = f.__puiIsDurationOnly == true
  local durationUsesIcon = f.__puiDurUseIcon == true
  local hideIconFrame = f.__puiDurHideIconFrame == true
  local showOnlyWhenActive = f.__puiShowOnlyWhenActive == true
  local hideDurationWhenMissing = f.__puiHideDurWhenMissing == true

  if f.__puiAuraDriverActive == configured
    and f.__puiAuraDriverDurationEnabled == durationEnabled
    and f.__puiAuraDriverDurationOnly == durationOnly
    and f.__puiAuraDriverUsesIcon == durationUsesIcon
    and f.__puiAuraDriverHideIconFrame == hideIconFrame
    and f.__puiAuraDriverShowOnlyWhenActive == showOnlyWhenActive
    and f.__puiAuraDriverHideDurationWhenMissing == hideDurationWhenMissing
  then
    return
  end

  f.__puiAuraDriverActive = configured
  f.__puiAuraDriverDurationEnabled = durationEnabled
  f.__puiAuraDriverDurationOnly = durationOnly
  f.__puiAuraDriverUsesIcon = durationUsesIcon
  f.__puiAuraDriverHideIconFrame = hideIconFrame
  f.__puiAuraDriverShowOnlyWhenActive = showOnlyWhenActive
  f.__puiAuraDriverHideDurationWhenMissing = hideDurationWhenMissing
  f.__puiHasActiveAura = configured
  f.__puiHasActiveDurationObject = configured and durationEnabled
  f.__puiIsActive = configured

  if durationOnly then
    f.durFrame:SetShown(configured and durationEnabled)
    f.durIconFrame:SetShown(configured and durationEnabled and not hideIconFrame)
  elseif durationUsesIcon then
    f.durFrame:Hide()
    f.durIconFrame:SetShown(configured and durationEnabled)
  else
    f.durIconFrame:Hide()
    f.durFrame:SetShown(configured and durationEnabled)
  end

  _CustomBars_ApplyVisibility(f, f.__puiCfg, _CustomBars._lastCombatState)
end

function _customBarsAuraDriver:ApplyCombinedStyle(sub, f, cfg)
  local button = sub.button
  local applicationsEnabled = sub.applicationsEnabled
  local textEnabled = cfg.showText ~= false
  local applicationTextEnabled = textEnabled
    and applicationsEnabled
    and (tonumber(cfg.fontSize) or 0) > 0
  local durationBarEnabled = sub.durationEnabled and (sub.mode == "bar" or sub.mode == "bar+icon")
  local durationTextEnabled = textEnabled and durationBarEnabled and sub.textEnabled
  local durationFrameEnabled = sub.durationEnabled and (sub.mode == "icon" or sub.mode == "bar+icon")
  local durationIconEnabled = durationFrameEnabled and cfg.durationHideSpellIcon ~= true
  local secretVisibility = f.__puiShowOnlyWhenActive == true
  local secretDurationVisibility = secretVisibility or f.__puiHideDurWhenMissing == true
  local activeOnlySpellIconEnabled = applicationsEnabled
    and f.__puiShowSpellIconNextToBar == true
    and not durationFrameEnabled
    and secretVisibility
  local auraIconTarget = durationFrameEnabled and f.durIconFrame
    or activeOnlySpellIconEnabled and f.spellIconFrame
    or nil
  local auraIconEnabled = durationIconEnabled or activeOnlySpellIconEnabled
  local bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA = self:GetChromeColors(cfg)
  local borderSize = Round(f.__puiBorderThickness or 2)

  self:ApplyChrome(
    sub.applicationChrome,
    f,
    bgR, bgG, bgB, bgA,
    borderR, borderG, borderB, borderA,
    borderSize,
    secretVisibility
  )
  self:SetExternalChromeShown(
    f.bg,
    f.__puiBorderTop,
    f.__puiBorderBottom,
    f.__puiBorderLeft,
    f.__puiBorderRight,
    not secretVisibility
  )

  self:ApplyChrome(
    sub.durationChrome,
    f.durFrame,
    bgR, bgG, bgB, bgA,
    borderR, borderG, borderB, borderA,
    borderSize,
    durationBarEnabled and secretDurationVisibility
  )
  self:SetExternalChromeShown(
    f.durBG,
    f.__puiDurBorderTop,
    f.__puiDurBorderBottom,
    f.__puiDurBorderLeft,
    f.__puiDurBorderRight,
    durationBarEnabled and not secretDurationVisibility
  )

  local iconBorderSize = tonumber(cfg.durationIconBorderSize) or 0
  if iconBorderSize < 0 then iconBorderSize = 0 end
  if iconBorderSize > 12 then iconBorderSize = 12 end
  if iconBorderSize <= 0 then iconBorderSize = borderSize end

  local iconBorderR, iconBorderG, iconBorderB, iconBorderA = borderR, borderG, borderB, borderA
  local iconBorder = cfg.durationIconBorderColor
  if type(iconBorder) == "table" then
    iconBorderR = iconBorder[1] or iconBorder.r or iconBorderR
    iconBorderG = iconBorder[2] or iconBorder.g or iconBorderG
    iconBorderB = iconBorder[3] or iconBorder.b or iconBorderB
    iconBorderA = iconBorder[4] or iconBorder.a or iconBorderA
  end

  self:ApplyChrome(
    sub.iconChrome,
    auraIconTarget or f.durIconFrame,
    bgR, bgG, bgB, bgA,
    iconBorderR, iconBorderG, iconBorderB, iconBorderA,
    iconBorderSize,
    (durationFrameEnabled and secretDurationVisibility) or activeOnlySpellIconEnabled
  )
  self:SetExternalChromeShown(
    f.durIconBG,
    f.__puiDurIconBorderTop,
    f.__puiDurIconBorderBottom,
    f.__puiDurIconBorderLeft,
    f.__puiDurIconBorderRight,
    durationFrameEnabled and not secretDurationVisibility
  )
  self:SetExternalChromeShown(
    f.spellIconBG,
    f.__puiSpellIconBorderTop,
    f.__puiSpellIconBorderBottom,
    f.__puiSpellIconBorderLeft,
    f.__puiSpellIconBorderRight,
    applicationsEnabled
      and f.__puiShowSpellIconNextToBar == true
      and not durationFrameEnabled
      and not activeOnlySpellIconEnabled
  )

  if applicationsEnabled then
    local engineBar = sub.applicationBar
    local cdmStackBar = f.cdmStackBar
    sub.applicationBase:Hide()

    local texturePath, orientation, reverseFill, r, g, b, a = self:GetBarAppearance(cfg, false)
    if sub.applicationTexture ~= texturePath then
      sub.applicationTexture = texturePath
      engineBar:SetStatusBarTexture(texturePath)
      cdmStackBar:SetStatusBarTexture(texturePath)
    end

    if sub.applicationOrientation ~= orientation then
      sub.applicationOrientation = orientation
      engineBar:SetOrientation(orientation)
      cdmStackBar:SetOrientation(orientation)
    end

    if sub.applicationReverseFill ~= reverseFill then
      sub.applicationReverseFill = reverseFill
      engineBar:SetReverseFill(reverseFill)
      cdmStackBar:SetReverseFill(reverseFill)
    end

    if sub.applicationR ~= r
      or sub.applicationG ~= g
      or sub.applicationB ~= b
      or sub.applicationA ~= a
    then
      sub.applicationR = r
      sub.applicationG = g
      sub.applicationB = b
      sub.applicationA = a
      engineBar:SetStatusBarColor(r, g, b, a)
      cdmStackBar:SetStatusBarColor(r, g, b, a)
    end

    local inset = Round(f.__puiBorderThickness or 2)
    if sub.applicationInset ~= inset then
      sub.applicationInset = inset
      engineBar:ClearAllPoints()
      engineBar:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
      engineBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
      cdmStackBar:ClearAllPoints()
      cdmStackBar:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
      cdmStackBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    end

    local applicationFrameLevel = button:GetFrameLevel() + 1
    if sub.applicationFrameLevel ~= applicationFrameLevel then
      sub.applicationFrameLevel = applicationFrameLevel
      engineBar:SetFrameLevel(applicationFrameLevel)
    end
    cdmStackBar:SetFrameStrata(f:GetFrameStrata())
    cdmStackBar:SetFrameLevel(button:GetFrameLevel() + 2)

    local maxStacks = tonumber(cfg.maxStacks) or 1
    if maxStacks < 1 then
      maxStacks = 1
    end

    local useCDMStackColorSource = _CustomBars_HasEnabledStackColorThreshold(cfg)
    local displayBar

    if useCDMStackColorSource then
      AuraWidget.SetApplicationThresholdBar(sub, cdmStackBar)
      sub.applicationThresholdInterpolation = Enum.StatusBarInterpolation.Immediate
      engineBar:SetAlpha(0)
      cdmStackBar:SetAlpha(1)
      displayBar = cdmStackBar
    else
      AuraWidget.DisableApplicationThresholdSource(sub)
      AuraWidget.ClearApplicationThresholdBar(sub)
      cdmStackBar:Hide()
      engineBar:SetAlpha(1)
      displayBar = engineBar
    end

    local engineTexture = engineBar:GetStatusBarTexture()
    if engineTexture then
      engineTexture:SetAlpha(1)
    end

    AuraWidget.ConfigureApplicationThresholds(
      sub,
      useCDMStackColorSource and cfg.stackColorThresholds or nil,
      texturePath,
      orientation,
      reverseFill,
      PLAYER_CLASS_COLOR,
      maxStacks
    )

    AuraWidget.ConfigureApplicationBar(
      sub,
      maxStacks,
      Enum.StatusBarInterpolation.Immediate
    )

    if useCDMStackColorSource then
      AuraWidget.ConfigureApplicationThresholdSource(
        sub,
        sub.candidate.spellIDs,
        sub.candidate.cooldownID,
        VIEWER_KEY,
        sub.unit
      )
    end

    local dividerFrame = sub.applicationDividerFrame
    dividerFrame:ClearAllPoints()
    dividerFrame:SetAllPoints(displayBar)
    dividerFrame:SetFrameStrata(displayBar:GetFrameStrata())

    sub.applicationThresholdTopFrameLevel =
      displayBar:GetFrameLevel() + (sub.applicationThresholdLayerCount or 0)
    dividerFrame:SetFrameLevel(math.max(
      displayBar:GetFrameLevel() + 3,
      sub.applicationThresholdTopFrameLevel + 1
    ))
    dividerFrame:Show()

    sub.dividers = sub.dividers or {}
    local width = f:GetWidth() - (inset * 2)
    local height = f:GetHeight() - (inset * 2)

    if sub.dividerMax ~= maxStacks
      or sub.dividerOrientation ~= orientation
      or sub.dividerWidth ~= width
      or sub.dividerHeight ~= height
    then
      sub.dividerMax = maxStacks
      sub.dividerOrientation = orientation
      sub.dividerWidth = width
      sub.dividerHeight = height

      local dividerSize = Round(1)
      for i = 1, maxStacks - 1 do
        local divider = sub.dividers[i]
        if not divider then
          divider = dividerFrame:CreateTexture(nil, "OVERLAY")
          divider:SetColorTexture(0, 0, 0, 0.65)
          sub.dividers[i] = divider
        end

        divider:ClearAllPoints()
        if orientation == "VERTICAL" then
          local y = Round((height * i) / maxStacks)
          divider:SetPoint("BOTTOMLEFT", dividerFrame, "BOTTOMLEFT", 0, y)
          divider:SetPoint("BOTTOMRIGHT", dividerFrame, "BOTTOMRIGHT", 0, y)
          divider:SetHeight(dividerSize)
        else
          local x = Round((width * i) / maxStacks)
          divider:SetPoint("TOPLEFT", dividerFrame, "TOPLEFT", x, 0)
          divider:SetPoint("BOTTOMLEFT", dividerFrame, "BOTTOMLEFT", x, 0)
          divider:SetWidth(dividerSize)
        end
        divider:Show()
      end

      for i = maxStacks, #sub.dividers do
        sub.dividers[i]:Hide()
      end
    end

    if applicationTextEnabled then
      if not sub.applicationFormatter then
        local formatter = C_StringUtil.CreateNumericRuleFormatter()
        formatter:AddBreakpoint({ threshold = 0, format = "%.0f" })
        sub.applicationFormatter = formatter
      end

      AuraWidget.ConfigureApplicationCount(sub, sub.applicationFormatter)

      self:ApplyFont(sub.applicationText, cfg.font, cfg.fontSize, cfg.outline)
      local x = tonumber(cfg.fontOffsetX) or 0
      local y = 2 + (tonumber(cfg.fontOffsetY) or 0)
      if sub.applicationTextPoint ~= "BOTTOM"
        or sub.applicationTextX ~= x
        or sub.applicationTextY ~= y
      then
        sub.applicationTextPoint = "BOTTOM"
        sub.applicationTextX = x
        sub.applicationTextY = y
        sub.applicationText:ClearAllPoints()
        sub.applicationText:SetPoint("BOTTOM", sub.applicationHolder, "TOP", x, y)
      end

      local strata = f:GetFrameStrata()
      local level = math.max(
        f:GetFrameLevel() + 12,
        sub.applicationThresholdTopFrameLevel + 2
      )
      if sub.applicationHolderStrata ~= strata then
        sub.applicationHolderStrata = strata
        sub.applicationHolder:SetFrameStrata(strata)
      end
      if sub.applicationHolderLevel ~= level then
        sub.applicationHolderLevel = level
        sub.applicationHolder:SetFrameLevel(level)
      end
    else
      AuraWidget.DisableApplicationCount(sub)
    end
  else
    AuraWidget.DisableApplicationThresholdSource(sub)
    AuraWidget.ClearApplicationThresholdBar(sub)
    f.cdmStackBar:Hide()
    AuraWidget.DisableApplicationBar(sub)
    AuraWidget.DisableApplicationCount(sub)
    sub.applicationDividerFrame:Hide()
    if sub.dividers then
      for i = 1, #sub.dividers do
        sub.dividers[i]:Hide()
      end
      sub.dividerMax = nil
    end
  end

  if durationBarEnabled then
    local target = f.durFrame
    local engineBar = sub.durationBar
    local texturePath, orientation, reverseFill, r, g, b, a = self:GetBarAppearance(cfg, true)
    if sub.durationTexture ~= texturePath then
      sub.durationTexture = texturePath
      engineBar:SetStatusBarTexture(texturePath)
    end

    if sub.durationOrientation ~= orientation then
      sub.durationOrientation = orientation
      engineBar:SetOrientation(orientation)
    end

    if sub.durationReverseFill ~= reverseFill then
      sub.durationReverseFill = reverseFill
      engineBar:SetReverseFill(reverseFill)
    end

    if sub.durationR ~= r
      or sub.durationG ~= g
      or sub.durationB ~= b
      or sub.durationA ~= a
    then
      sub.durationR = r
      sub.durationG = g
      sub.durationB = b
      sub.durationA = a
      engineBar:SetStatusBarColor(r, g, b, a)
    end

    if sub.durationBarTarget ~= target then
      sub.durationBarTarget = target
      engineBar:ClearAllPoints()
      engineBar:SetAllPoints(target)
    end

    local strata = target:GetFrameStrata()
    local level = target:GetFrameLevel() + 1
    if sub.durationBarStrata ~= strata then
      sub.durationBarStrata = strata
      engineBar:SetFrameStrata(strata)
    end
    if sub.durationBarLevel ~= level then
      sub.durationBarLevel = level
      engineBar:SetFrameLevel(level)
    end

    local timerDirection = cfg.durationBarFillMode == "fill"
      and Enum.StatusBarTimerDirection.ElapsedTime
      or Enum.StatusBarTimerDirection.RemainingTime

    AuraWidget.ConfigureDurationBar(
      sub,
      Enum.StatusBarInterpolation.None,
      timerDirection
    )

    if durationTextEnabled then
      AuraWidget.ConfigureDurationText(sub, BarWidget.GetDurationFormatter())

      self:ApplyFont(
        sub.durationText,
        cfg.durationFont,
        cfg.durationCountFontSize,
        cfg.durationOutline
      )
      if sub.durationTextTarget ~= target then
        sub.durationTextTarget = target
        sub.durationTextHolder:ClearAllPoints()
        sub.durationTextHolder:SetAllPoints(target)
      end

      level = target:GetFrameLevel() + 2
      if sub.durationTextStrata ~= strata then
        sub.durationTextStrata = strata
        sub.durationTextHolder:SetFrameStrata(strata)
      end
      if sub.durationTextLevel ~= level then
        sub.durationTextLevel = level
        sub.durationTextHolder:SetFrameLevel(level)
      end
    else
      AuraWidget.DisableDurationText(sub)
    end
  else
    AuraWidget.DisableDurationBar(sub)
    AuraWidget.DisableDurationText(sub)
  end

  if auraIconTarget then
    if sub.iconTarget ~= auraIconTarget then
      sub.iconTarget = auraIconTarget
      sub.icon:ClearAllPoints()
      sub.icon:SetAllPoints(auraIconTarget)
    end

    if auraIconEnabled then
      AuraWidget.ConfigureIcon(sub)
    else
      AuraWidget.DisableIcon(sub)
    end
  else
    AuraWidget.DisableIcon(sub)
  end

  if durationFrameEnabled then
    local target = f.durIconFrame

    if sub.durationCooldownTarget ~= target then
      sub.durationCooldownTarget = target
      sub.durationCooldown:ClearAllPoints()
      sub.durationCooldown:SetAllPoints(target)
    end

    local strata = target:GetFrameStrata()
    local level = target:GetFrameLevel() + 2
    if sub.durationCooldownStrata ~= strata then
      sub.durationCooldownStrata = strata
      sub.durationCooldown:SetFrameStrata(strata)
    end
    if sub.durationCooldownLevel ~= level then
      sub.durationCooldownLevel = level
      sub.durationCooldown:SetFrameLevel(level)
    end

    local hideNumbers = cfg.showText == false
      or (tonumber(cfg.durationCountFontSize) or 0) <= 0
    if sub.durationNumbersHidden ~= hideNumbers then
      sub.durationNumbersHidden = hideNumbers
      sub.durationCooldown:SetHideCountdownNumbers(hideNumbers)
    end

    AuraWidget.ConfigureDurationCooldown(sub)

    local engineText = PUI_GetCooldownNumbersFontString(sub.durationCooldown)
    self:ApplyFont(
      engineText,
      cfg.durationFont,
      cfg.durationCountFontSize,
      cfg.durationOutline
    )
  else
    AuraWidget.DisableDurationCooldown(sub)
  end

  local activeAppearanceEnabled = cfg.activeAuraEnabled == true
  local activeDesaturated = activeAppearanceEnabled and cfg.desaturateActive == true
  local activeAlpha = activeAppearanceEnabled and (tonumber(cfg.activeAlpha) or 100) / 100 or 1
  button:SetAlpha(activeAlpha)
  f.cdmStackBar:SetAlpha(activeAlpha)
  sub.icon:SetDesaturated(activeDesaturated)
  if sub.applicationBar and sub.applicationBar:GetStatusBarTexture() then
    sub.applicationBar:GetStatusBarTexture():SetDesaturated(activeDesaturated)
  end
  if f.cdmStackBar:GetStatusBarTexture() then
    f.cdmStackBar:GetStatusBarTexture():SetDesaturated(activeDesaturated)
  end
  if sub.durationBar and sub.durationBar:GetStatusBarTexture() then
    sub.durationBar:GetStatusBarTexture():SetDesaturated(activeDesaturated)
  end
end

function _customBarsAuraDriver:ApplyStyle(f, cfg)
  local attachment = self.attachments[f]
  if not attachment then
    return
  end

  if self:IsButtonRestyleLocked() then
    self.styleDeferred[f] = cfg
    return
  end

  self.styleDeferred[f] = nil
  self:ApplyCombinedStyle(attachment.slot, f, cfg)
end

function _customBarsAuraDriver:WireCombinedButton(button, f, cfg, sub)
  AuraWidget.BindApplicationDurationButton(button, sub)
  sub.applicationChrome = self:CreateChrome(button)
  sub.durationChrome = self:CreateChrome(button)
  sub.iconChrome = self:CreateChrome(button)
  sub.applicationDividerFrame = CreateFrame("Frame", nil, button)
  sub.applicationDividerFrame:EnableMouse(false)

  sub.applicationTexture = nil
  sub.applicationOrientation = nil
  sub.applicationReverseFill = nil
  sub.applicationR = nil
  sub.applicationG = nil
  sub.applicationB = nil
  sub.applicationA = nil
  sub.applicationInset = nil
  sub.applicationFrameLevel = nil
  sub.applicationBarEnabled = false
  sub.applicationCountEnabled = false
  sub.maxApplications = nil
  sub.applicationTextPoint = nil
  sub.applicationTextX = nil
  sub.applicationTextY = nil
  sub.applicationHolderStrata = nil
  sub.applicationHolderLevel = nil
  sub.dividers = nil
  sub.dividerMax = nil
  sub.dividerOrientation = nil
  sub.dividerWidth = nil
  sub.dividerHeight = nil

  sub.durationTexture = nil
  sub.durationOrientation = nil
  sub.durationReverseFill = nil
  sub.durationR = nil
  sub.durationG = nil
  sub.durationB = nil
  sub.durationA = nil
  sub.durationBarTarget = nil
  sub.durationBarStrata = nil
  sub.durationBarLevel = nil
  sub.durationBarEnabled = false
  sub.durationTextEnabled = false
  sub.durationTextTarget = nil
  sub.durationTextStrata = nil
  sub.durationTextLevel = nil
  sub.iconTarget = nil
  sub.iconEnabled = false
  sub.durationCooldownTarget = nil
  sub.durationCooldownStrata = nil
  sub.durationCooldownLevel = nil
  sub.durationNumbersHidden = nil
  sub.durationCooldownEnabled = false

  button:ClearAllPoints()
  button:SetAllPoints(f)
  button:SetFrameStrata(f:GetFrameStrata())
  button:SetFrameLevel(f:GetFrameLevel() + 1)
  button:EnableMouse(false)

  self:ApplyCombinedStyle(sub, f, cfg)
end

function _customBarsAuraDriver:CreateSlot(unit, filter, candidate, f, cfg, applicationsEnabled, durationEnabled, mode, textEnabled)
  local frameCache = self.slotCache[f]
  if not frameCache then
    frameCache = {}
    self.slotCache[f] = frameCache
  end

  local sub = frameCache[unit]
  if sub then
    sub.unit = unit
    sub.applicationsEnabled = applicationsEnabled
    sub.durationEnabled = durationEnabled
    sub.mode = mode
    sub.textEnabled = textEnabled

    if sub.filter ~= filter then
      sub.filter = filter
      AuraSlotDriver:SetSlotFilter(sub.auraSlot, filter)
    end

    if sub.candidateSignature ~= candidate.signature or sub.attached ~= true then
      sub.candidate = candidate
      sub.candidateSignature = candidate.signature
      AuraSlotDriver:SetSlotCandidates(sub.auraSlot, {
        includeSpellIDs = candidate.spellIDs,
      })
    end

    self:SetSlotAttached(sub, true)

    if self:IsButtonRestyleLocked() then
      self.styleDeferred[f] = cfg
    else
      self.styleDeferred[f] = nil
      self:ApplyCombinedStyle(sub, f, cfg)
    end

    return sub
  end

  sub = {
    filter = filter,
    candidate = candidate,
    candidateSignature = candidate.signature,
    unit = unit,
    attached = false,
    applicationsEnabled = applicationsEnabled,
    durationEnabled = durationEnabled,
    mode = mode,
    textEnabled = textEnabled,
  }
  frameCache[unit] = sub

  sub.auraSlot = AuraSlotDriver:CreateSlot(unit, filter, {
    candidateFilters = { includeSpellIDs = candidate.spellIDs },
    templateNames = { "PUI_AuraApplicationDurationTemplate" },
    initializeFrame = function(button)
      self:WireCombinedButton(button, f, cfg, sub)
    end,
  })

  self:SetSlotAttached(sub, true)
  return sub
end

function _customBarsAuraDriver:GetMode(f, cfg)
  if cfg.kind == "duration" then
    return cfg.durationHideIconFrame == true and "bar" or "bar+icon"
  end

  return f.__puiDurUseIcon == true and "icon" or "bar"
end

function _customBarsAuraDriver:Detach(f)
  self.styleDeferred[f] = nil

  local attachment = self.attachments[f]
  if not attachment then
    return
  end

  local sub = attachment.slot
  AuraWidget.DisableApplicationThresholdSource(sub)
  AuraWidget.ClearApplicationThresholdBar(sub)
  self:SetSlotAttached(sub, false)
  sub.applicationsEnabled = false
  sub.durationEnabled = false
  sub.candidate = nil
  sub.candidateSignature = nil

  self.attachments[f] = nil
  self:UpdateActivity(f)
end

function _customBarsAuraDriver:Release(f)
  self.styleDeferred[f] = nil

  local frameCache = self.slotCache[f]
  if frameCache then
    self.attachments[f] = nil

    for _, sub in pairs(frameCache) do
      AuraWidget.DisableApplicationThresholdSource(sub)
      AuraWidget.ClearApplicationThresholdBar(sub)
      self:SetSlotAttached(sub, false)
      sub.applicationsEnabled = false
      sub.durationEnabled = false
      sub.candidate = nil
      sub.candidateSignature = nil
    end
  else
    self.attachments[f] = nil
  end

  if f.__puiCfg then
    self:UpdateActivity(f)
  else
    f.__puiAuraDriverActive = false
    f.__puiHasActiveAura = false
    f.__puiHasActiveDurationObject = false
    f.__puiIsActive = false
    f.durFrame:Hide()
    f.durIconFrame:Hide()
    f.spellIconFrame:Hide()
    f:Hide()
  end

  _CustomBars_CompleteFrameRetirement(f)
end

function _customBarsAuraDriver:Attach(f, cfg)
  local applicationsEnabled = cfg.enabled ~= false and cfg.kind ~= "duration"
  local durationEnabled = cfg.enabled ~= false and (cfg.kind == "duration" or cfg.showDuration == true)
  if (not applicationsEnabled and not durationEnabled) or not _CustomBars_IsTrackedSpellAvailable(cfg) then
    self:Detach(f)
    return
  end

  local unit, filter = _CustomBars_GetAuraTrackUnitAndFilter(cfg)
  local candidate = self:ResolveCandidate(cfg)
  local mode = self:GetMode(f, cfg)
  local textEnabled = (tonumber(cfg.durationCountFontSize) or 0) > 0
  local previous = self.attachments[f]

  if previous and previous.slot.unit ~= unit then
    local oldSub = previous.slot
    AuraWidget.DisableApplicationThresholdSource(oldSub)
    AuraWidget.ClearApplicationThresholdBar(oldSub)
    self:SetSlotAttached(oldSub, false)
    oldSub.applicationsEnabled = false
    oldSub.durationEnabled = false
    oldSub.candidate = nil
    oldSub.candidateSignature = nil
  end

  local slot = self:CreateSlot(
    unit,
    filter,
    candidate,
    f,
    cfg,
    applicationsEnabled,
    durationEnabled,
    mode,
    textEnabled
  )

  self.attachments[f] = {
    unit = unit,
    slot = slot,
  }

  self:UpdateActivity(f)
end

function _customBarsAuraDriver:FlushDeferred()
  if self:IsButtonRestyleLocked() then
    return
  end

  local deferred = {}
  for f, cfg in pairs(self.styleDeferred) do
    deferred[#deferred + 1] = { f, cfg }
  end
  for i = 1, #deferred do
    self:ApplyStyle(deferred[i][1], deferred[i][2])
  end
end

function _customBarsAuraDriver:DetachAll()
  wipe(self.styleDeferred)

  local frames = {}
  for f in pairs(self.attachments) do
    frames[#frames + 1] = f
  end
  for i = 1, #frames do
    self:Detach(frames[i])
  end
end

_CustomBars_SetViewerIconHidden = function(icon, hidden)
  if not icon then
    return
  end

  local state = _BB_State(icon)
  local changed = false

  if hidden then
    if not state.hidden then
      state.hidden = true
      state.mouseClickEnabled = icon:IsMouseClickEnabled()
      state.mouseMotionEnabled = icon:IsMouseMotionEnabled()
      changed = true
    end
    Hooks.SetBBIconHidden(icon, true, icon:IsShown())
    icon:EnableMouse(false)
  else
    local wasHidden = state.hidden == true
    state.hidden = nil
    Hooks.SetBBIconHidden(icon, false)

    if wasHidden then
      icon:SetMouseClickEnabled(state.mouseClickEnabled == true)
      icon:SetMouseMotionEnabled(state.mouseMotionEnabled == true)
      state.mouseClickEnabled = nil
      state.mouseMotionEnabled = nil
    end

    changed = wasHidden
  end

  if changed then
    ns.Modules.PCM_Buffs:ScheduleRecenter(nil, icon)
  end
end

local _manualHiddenByCooldownID = {}
local _manualHiddenBySpellID    = {}

local function _BB_ApplyViewerIconHiddenState(viewer)
  local v = viewer or _GetViewer()
  if not v then
    return
  end

  local icons = _GetViewerIcons(v)
  if type(icons) ~= "table" then
    return
  end

  for i = 1, #icons do
    local icon = icons[i]
    if icon and icon.GetObjectType then
      local cdID = _CustomBars_GetIconCooldownID(icon)
      if type(cdID) == "string" then cdID = tonumber(cdID) end

      local sid = _CustomBars_GetIconSpellID(icon)

      local hide = false
      if type(cdID) == "number" and _manualHiddenByCooldownID and _manualHiddenByCooldownID[cdID] then
        hide = true
      end
      if (not hide) and type(sid) == "number" and _manualHiddenBySpellID and _manualHiddenBySpellID[sid] then
        hide = true
      end

      _CustomBars_SetViewerIconHidden(icon, hide)
    end
  end
end

function API.SetViewerIconHiddenByCooldownID(cooldownID, hidden)
  local cdID = cooldownID
  if type(cdID) == "string" then cdID = tonumber(cdID) end
  if type(cdID) ~= "number" then return end

  if hidden then
    _manualHiddenByCooldownID[cdID] = true
  else
    _manualHiddenByCooldownID[cdID] = nil
  end

  _BB_ApplyViewerIconHiddenState(_GetViewer())
end

function API.SetViewerIconHiddenBySpellID(spellID, hidden)
  local sid = spellID
  if type(sid) == "string" then sid = tonumber(sid) end
  if type(sid) ~= "number" then return end

  if hidden then
    _manualHiddenBySpellID[sid] = true
  else
    _manualHiddenBySpellID[sid] = nil
  end

  _BB_ApplyViewerIconHiddenState(_GetViewer())
end


local function _CustomBars_DeleteRuntimeBar(id)
  local key = id
  local f = _CustomBars.frames[key]

  if not f then
    key = tonumber(id)
    f = key and _CustomBars.frames[key]
  end
  if not f then
    return
  end

  PCMPresentation.ReleaseCustomBarBuffGlow("buff:" .. tostring(key))
  CustomIcons:Delete("aura:" .. tostring(key))
  f.__puiCfg = nil
  f.__puiRetiredBarID = key
  _CustomBars.frames[key] = nil
  _customBarsAuraDriver:Release(f)

  local moverKey = "PCM_CustomStackBar_" .. tostring(key)
  local ghost = FrameUtil:RefreshGhostMover(moverKey)
  if ghost then
    ghost:Hide()
  end
  FrameUtil:UnregisterMover(moverKey)
end

-- NOTE: API exports for stack bar creation/defaults are wired after the helper
-- functions are defined (later in this file).

local function _BB_RebuildCustomBars()
  if not _PCM_BB_Enabled() then
    return
  end

  _CustomBars_RebuildAll()

  local needsViewerIdentity = false
  local db = _GetStackBarsDB()
  for id, cfg in pairs(db) do
    if type(cfg) == "table" and cfg.enabled ~= false then
      FrameUtil.RefreshSmartSnapState("PCM_CustomStackBar_" .. tostring(id))
    end
  end

  for _, cfg in pairs(db) do
    if type(cfg) == "table" and cfg.enabled ~= false and cfg.hideViewerIcon == true then
      needsViewerIdentity = true
      break
    end
  end
  BB.__puiNeedsViewerIdentity = needsViewerIdentity

  local viewer = _GetViewer()
  if needsViewerIdentity then
    _BB_EnsureViewerAuraHooks(viewer)
  else
    _BB_ApplyViewerIconHiddenState(viewer)
  end
end

API.RebuildCustomBars = _BB_RebuildCustomBars

function API.DeleteCustomBar(id)
  FrameUtil.ClearSmartSnapForKey("PCM_CustomStackBar_" .. tostring(id))

  local db = _GetStackBarsDB()
  if db then
    db[id] = nil

    local numID = tonumber(id)
    if numID ~= nil then
      db[numID] = nil
    end
  end

  _CustomBars_DeleteRuntimeBar(id)
  API.RebuildCustomBars()
end


-- Ensure custom bars are built on reload without needing to open options.
local _bbStartupDid = false
local _bbRebuildQueued = false
local _bbAvailabilityRefreshQueued = false
local _bbDeferredFlushQueued = false
local _bbWorkFrame = _G.CreateFrame("Frame")
_bbWorkFrame:Hide()

local function _BB_QueueWork()
  _bbWorkFrame:Show()
end

local function _BB_ScheduleRebuildPasses()
  if _bbRebuildQueued then
    return
  end

  _bbRebuildQueued = true
  _BB_QueueWork()
end

local function _BB_StartupRebuild()
  if not _PCM_BB_Enabled() or _bbStartupDid then
    return
  end

  _bbStartupDid = true
  API.RebuildCustomBars()
end


function API.RefreshCustomBarStyle(id)
  local frame = _CustomBars.frames[id]
  if not frame or not frame.__puiCfg then
    return
  end

  _customBarsAuraDriver:ApplyStyle(frame, frame.__puiCfg)
end

function BB:ApplySettings(flags)
  if not _PCM_BB_Enabled() then
    return
  end

  if not flags then
    return
  end

  if flags.profile == true then
    _cache.cm = nil
    _cache.viewer = nil
  end

  if flags.theme == true then
    for _, frame in pairs(_CustomBars.frames) do
      local cfg = frame and frame.__puiCfg
      if cfg then
        _CustomBars_ApplyAppearance(frame, cfg)
        _customBarsAuraDriver:ApplyStyle(frame, cfg)
      end
    end
  end
end

function BB:SoftRebuild(flags)
  if not _PCM_BB_Enabled() then
    return
  end

  if not flags then
    return
  end

  if flags.profile == true or flags.layout == true or flags.movers == true then
    _BB_ScheduleRebuildPasses()
  end
end

function BB:_OnVisibilityEvent(event)
  local isInCombat = event == "PLAYER_REGEN_DISABLED"
  _CustomBars._lastCombatState = isInCombat

  for _, f in pairs(_CustomBars.frames) do
    if f and f.__puiCfg then
      _CustomBars_ApplyVisibility(f, f.__puiCfg, isInCombat)
    end
  end
end

local function _BB_RefreshTrackedSpellAvailability()
  if not _PCM_BB_Enabled() then
    return false
  end

  _customBarsAuraDriver:InvalidateCandidateCache()

  local db = _GetStackBarsDB()
  if type(db) ~= "table" then
    return false
  end

  local changed = false

  for _, cfg in pairs(db) do
    if type(cfg) == "table" and cfg.enabled ~= false then
      local previousCooldownID = cfg.__puiCooldownID
      local previousAvailable = cfg.__puiTrackedAvailable == true
      local available = _CustomBars_IsTrackedSpellAvailable(cfg)

      if available ~= previousAvailable or cfg.__puiCooldownID ~= previousCooldownID then
        changed = true
      end
    end
  end

  if changed then
    API.RebuildCustomBars()
  end

  return changed
end

local function _BB_QueueTrackedSpellAvailabilityRefresh()
  if InCombatLockdown() then
    BB.__puiPendingTrackedAvailabilityRefresh = true
    return
  end

  if _bbAvailabilityRefreshQueued then
    return
  end

  _bbAvailabilityRefreshQueued = true
  _BB_QueueWork()
end

_bbWorkFrame:SetScript("OnUpdate", function(frame)
  frame:Hide()

  local rebuild = _bbRebuildQueued
  local availability = _bbAvailabilityRefreshQueued
  local deferred = _bbDeferredFlushQueued

  _bbRebuildQueued = false
  _bbAvailabilityRefreshQueued = false
  _bbDeferredFlushQueued = false

  if rebuild and _PCM_BB_Enabled() then
    API.RebuildCustomBars()
  end

  if availability then
    _BB_RefreshTrackedSpellAvailability()
  end

  if deferred then
    _customBarsAuraDriver:FlushDeferred()
    CustomIcons:FlushAuraStyles()
  end
end)

function API.RefreshAfterTalentSwap()
  _customBarsAuraDriver:InvalidateCandidateCache()
  API.RebuildCustomBars()
end


function BB:_OnPlayerRegenEnabled()
  self:_OnVisibilityEvent("PLAYER_REGEN_ENABLED")

  if self.__puiPendingTrackedAvailabilityRefresh then
    self.__puiPendingTrackedAvailabilityRefresh = nil
    _BB_QueueTrackedSpellAvailabilityRefresh()
  end
end

function BB:_OnSpellsChanged()
  if ns.PCM_IsTransitionPending() then
    return
  end

  _BB_QueueTrackedSpellAvailabilityRefresh()
end

function BB:_OnCooldownViewerDataLoaded()
  if ns.PCM_IsTransitionPending() then
    return
  end

  _BB_QueueTrackedSpellAvailabilityRefresh()
end

function BB:_OnCooldownViewerSpellOverrideUpdated()
  if ns.PCM_IsTransitionPending() then
    return
  end

  _BB_QueueTrackedSpellAvailabilityRefresh()
end

function BB:_OnCooldownViewerTableHotfixed()
  if ns.PCM_IsTransitionPending() then
    return
  end

  _BB_QueueTrackedSpellAvailabilityRefresh()
end

PCMRuntime:RegisterSubscriber("CustomBuffBars", {
  OnViewerChanged = function(key, viewer)
    if key ~= VIEWER_KEY then
      return
    end

    _cache.viewer = viewer

    if viewer and _PCM_BB_Enabled() then
      API.RebuildCustomBars()
    end
  end,

  OnItemAcquired = function(key, viewer, itemFrame)
    if key ~= VIEWER_KEY or not _PCM_BB_Enabled() then
      return
    end

    if BB.__puiNeedsViewerIdentity then
      _BB_EnsureViewerAuraIconHook(itemFrame)
    end
  end,

  OnItemReleased = function(key, _, itemFrame)
    if key ~= VIEWER_KEY then
      return
    end

    _CustomBars.barsByIcon[itemFrame] = nil
    _CustomBars_SetViewerIconHidden(itemFrame, false)
  end,

  OnItemRebound = function(key, _, itemFrame)
    if key == VIEWER_KEY and _PCM_BB_Enabled() then
      _BB_ResetViewerIconIdentity(itemFrame)
    end
  end,

  OnLifecycleEvent = function(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
      _BB_StartupRebuild()
    elseif event == "PLAYER_REGEN_DISABLED" then
      BB:_OnVisibilityEvent(event)
    elseif event == "PLAYER_REGEN_ENABLED" then
      BB:_OnPlayerRegenEnabled()
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
      _bbDeferredFlushQueued = true
      _BB_QueueWork()
    elseif event == "SPELLS_CHANGED" then
      BB:_OnSpellsChanged()
    elseif event == "COOLDOWN_VIEWER_DATA_LOADED" then
      BB:_OnCooldownViewerDataLoaded()
    elseif event == "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED" then
      BB:_OnCooldownViewerSpellOverrideUpdated()
    elseif event == "COOLDOWN_VIEWER_TABLE_HOTFIXED" then
      BB:_OnCooldownViewerTableHotfixed()
    end
  end,
})

function BB:OnInitialize()
  self:SetEnabledState(_PCM_BB_Enabled())
end

function BB:OnEnable()
  if not _PCM_BB_Enabled() then
    self:Disable()
    return
  end

  if not self.__puiCustomBarsScaleListener then
    self.__puiCustomBarsScaleListener = function()
      API.RebuildCustomBars()
    end
    FrameScale:RegisterScaleListener(self.__puiCustomBarsScaleListener)
  end

  PCMRuntime:SetSubscriberEnabled("CustomBuffBars", true)
  _BB_StartupRebuild()
end

function BB:OnDisable()
  PCMRuntime:SetSubscriberEnabled("CustomBuffBars", false)

  _bbWorkFrame:Hide()
  _bbRebuildQueued = false
  _bbAvailabilityRefreshQueued = false
  _bbDeferredFlushQueued = false
  _bbStartupDid = false
  _cache.viewer = nil

  if self.__puiCustomBarsScaleListener then
    FrameScale:UnregisterScaleListener(self.__puiCustomBarsScaleListener)
    self.__puiCustomBarsScaleListener = nil
  end

  _customBarsAuraDriver:DetachAll()

  for id, f in pairs(_CustomBars.frames) do
    if f then
      PCMPresentation.DisableCustomBarBuffGlow("buff:" .. tostring(id))
      CustomIcons:Release("aura:" .. tostring(id))
      if f.Hide then
        f:Hide()
      end
    end
  end
end


local function EnsureStackBarDefaults(bar, id)
  if not bar then
    bar = {}
  end

  if id and not bar.id then
    bar.id = id
  end

  if bar.enabled == nil then
    bar.enabled = true
  end

  if bar.showOnlyWhenActive == nil then
    bar.showOnlyWhenActive = false
  end

  bar.viewerName = (type(bar.viewerName) == "string" and bar.viewerName ~= "") and bar.viewerName or "BuffIconCooldownViewer"

  ns.Modules.CooldownManager:NormalizeSpecAssignments(bar)
  ns.Modules.CooldownManager:NormalizeCustomBarBuffGlow(bar)

  if bar.auraTrackMode ~= "target_debuff" then
    bar.auraTrackMode = "player_buff"
  end

  bar.kind = (type(bar.kind) == "string" and bar.kind ~= "") and bar.kind or "stack"
  ns.Modules.CooldownManager:NormalizeCustomTrackerPresentation(bar, bar.kind)

  if type(bar.label) ~= "string" or bar.label == "" then
    if bar.kind == "duration" then
      bar.label = "Duration Bar " .. tostring(bar.id or id or "")
    else
      bar.label = "Stack Duration Bar " .. tostring(bar.id or id or "")
    end
  end

  bar.maxStacks = bar.maxStacks or 3
  if bar.kind == "duration" then
    bar.maxStacks = 1
  end

  bar.width     = bar.width or 250
  bar.height    = bar.height or 25
  bar.fontSize  = bar.fontSize or 14

  if bar.showSpellIconNextToBar == nil then
    bar.showSpellIconNextToBar = true
  end

  if bar.kind == "duration" then
    bar.showDuration = true
  else
    bar.showDuration = bar.showDuration == true
  end
  if bar.hideDurationWhenMissing == nil then
    bar.hideDurationWhenMissing = true
  end
  bar.durationAnchor = (type(bar.durationAnchor) == "string" and bar.durationAnchor ~= "") and bar.durationAnchor or "BOTTOM"
  bar.durationHeight = tonumber(bar.durationHeight) or 10
  if bar.durationHeight < 2 then bar.durationHeight = 2 end
  if bar.durationHeight > 40 then bar.durationHeight = 40 end

  bar.durationIconSize = tonumber(bar.durationIconSize) or nil
  if bar.durationIconSize ~= nil then
    if bar.durationIconSize < 8 then bar.durationIconSize = 8 end
    if bar.durationIconSize > 86 then bar.durationIconSize = 86 end
  end

  bar.durationCountFontSize = tonumber(bar.durationCountFontSize) or 14

  if bar.durationHideIconFrame == nil then
    bar.durationHideIconFrame = false
  end
  if bar.durationCountFontSize < 0 then bar.durationCountFontSize = 0 end
  if bar.durationCountFontSize > 32 then bar.durationCountFontSize = 32 end

  bar.durationGap = tonumber(bar.durationGap) or 2
  if bar.durationGap < 0 then bar.durationGap = 0 end
  if bar.durationGap > 20 then bar.durationGap = 20 end

  if bar.durationBarFillMode ~= "fill" and bar.durationBarFillMode ~= "drain" then
    bar.durationBarFillMode = "drain"
  end

  bar.fontOffsetX = tonumber(bar.fontOffsetX) or 0
  bar.fontOffsetY = tonumber(bar.fontOffsetY) or 0

  bar.stackTexture    = (bar.stackTexture ~= "") and bar.stackTexture or nil
  bar.durationTexture = (bar.durationTexture ~= "") and bar.durationTexture or nil

  if not bar.stackTexture then
    bar.stackTexture = "Pleebar"
  end
  if not bar.durationTexture then
    bar.durationTexture = "Pleebar"
  end

  if bar.useClassColor == nil then
    bar.useClassColor = true
  end

  -- Only used when useClassColor is false.
  bar.barColor  = (type(bar.barColor) == "table") and bar.barColor or nil

  -- Duration-only settings.
  bar.orientation = (type(bar.orientation) == "string" and bar.orientation ~= "") and bar.orientation or "horizontal"
  if bar.orientation ~= "vertical" then
    bar.orientation = "horizontal"
  end

  bar.fillDirection = (type(bar.fillDirection) == "string" and bar.fillDirection ~= "") and bar.fillDirection or nil
  if bar.fillDirection ~= "LEFT" and bar.fillDirection ~= "RIGHT" and bar.fillDirection ~= "UP" and bar.fillDirection ~= "DOWN" then
    bar.fillDirection = nil
  end
  if not bar.fillDirection then
    bar.fillDirection = (bar.orientation == "vertical") and "UP" or "RIGHT"
  end

  bar.borderSize = tonumber(bar.borderSize) or 2
  if bar.borderSize < 0 then bar.borderSize = 0 end
  if bar.borderSize > 12 then bar.borderSize = 12 end
  bar.borderColor = (type(bar.borderColor) == "table") and bar.borderColor or nil
  bar.backgroundColor = (type(bar.backgroundColor) == "table") and bar.backgroundColor or nil

  bar.font      = bar.font or nil
  bar.outline   = bar.outline or "OUTLINE"

  return bar
end

local function CreateNewStackBar()
  local stackBars = _GetStackBarsDB()
  if not stackBars then
    return nil, nil
  end

  local nextId = 1
  for id in pairs(stackBars) do
    if type(id) == "number" and id >= nextId then
      nextId = id + 1
    end
  end

  local cfg = EnsureStackBarDefaults({
    id             = nextId,
    label          = "Stack Duration Bar " .. nextId,
    viewerName     = "BuffIconCooldownViewer",
    specAssignments = {
      [ns.Modules.CooldownManager:GetCurrentSpecializationID()] = { enabled = true },
    },
    maxStacks      = 3,
  }, nextId)

  -- Write into the options root (may be a live ref or a copy, depending on PCM_ConfigExports).
  stackBars[nextId] = cfg



  return nextId, cfg
end

local function CreateNewDurationBar()
  local stackBars = _GetStackBarsDB()
  if not stackBars then
    return nil, nil
  end

  local nextId = 1
  for id in pairs(stackBars) do
    if type(id) == "number" and id >= nextId then
      nextId = id + 1
    end
  end

  local cfg = EnsureStackBarDefaults({
    id             = nextId,
    label          = "Duration Bar " .. nextId,
    viewerName     = "BuffIconCooldownViewer",
    specAssignments = {
      [ns.Modules.CooldownManager:GetCurrentSpecializationID()] = { enabled = true },
    },
    maxStacks      = 1,
  }, nextId)

  cfg.kind = "duration"

  -- Defaults requested for duration-only:
  cfg.width  = 250
  cfg.height = 25

  -- Prefer this LSM key if present in the user's media list.
  cfg.durationTexture = cfg.durationTexture or "Pleebar"

  -- Duration-only bars always show the spell icon on the LEFT (outside the bar).
  -- (Runtime layout enforces this regardless of durationAnchor.)
  cfg.showDuration = true
  cfg.durationAnchor = "LEFT"

  -- Write into the options root (may be a live ref or a copy, depending on PCM_ConfigExports).
  stackBars[nextId] = cfg
  return nextId, cfg
end


_PCM_BB_Enabled = P:Def("_PCM_BB_Enabled", _PCM_BB_Enabled)
_BB_State = P:Def("_BB_State", _BB_State)
_GetBuffsDB = P:Def("_GetBuffsDB", _GetBuffsDB)
_GetViewer = P:Def("_GetViewer", _GetViewer)
_GetStackBarsDB = P:Def("_GetStackBarsDB", _GetStackBarsDB)
PUI_GetCooldownNumbersFontString = P:Def("PUI_GetCooldownNumbersFontString", PUI_GetCooldownNumbersFontString)
_CustomBars_EnsureDefaults = P:Def("_CustomBars_EnsureDefaults", _CustomBars_EnsureDefaults)
_CustomBars_GetAccentRGBA = P:Def("_CustomBars_GetAccentRGBA", _CustomBars_GetAccentRGBA)
_CustomBars_GetLayoutGeometry = P:Def("_CustomBars_GetLayoutGeometry", _CustomBars_GetLayoutGeometry)
_CustomBars_GetAnchorVisualOffset = P:Def("_CustomBars_GetAnchorVisualOffset", _CustomBars_GetAnchorVisualOffset)
_CustomBars_ApplyAnchor = P:Def("_CustomBars_ApplyAnchor", _CustomBars_ApplyAnchor)
_CustomBars_SaveAnchor = P:Def("_CustomBars_SaveAnchor", _CustomBars_SaveAnchor)
_CustomBars_ApplyExternalChrome = P:Def("_CustomBars_ApplyExternalChrome", _CustomBars_ApplyExternalChrome)
_CustomBars_ApplyAppearance = P:Def("_CustomBars_ApplyAppearance", _CustomBars_ApplyAppearance)
_CustomBars_CreateChrome = P:Def("_CustomBars_CreateChrome", _CustomBars_CreateChrome)
_CustomBars_CreateNativeAnchor = P:Def("_CustomBars_CreateNativeAnchor", _CustomBars_CreateNativeAnchor)
_CustomBars_EnsureFrame = P:Def("_CustomBars_EnsureFrame", _CustomBars_EnsureFrame)
_CustomBars_CompleteFrameRetirement = P:Def("_CustomBars_CompleteFrameRetirement", _CustomBars_CompleteFrameRetirement)
_CustomBars_LayoutNativeFrame = P:Def("_CustomBars_LayoutNativeFrame", _CustomBars_LayoutNativeFrame)
_CustomBars_RebuildSegments = P:Def("_CustomBars_RebuildSegments", _CustomBars_RebuildSegments)
_CustomBars_RegisterMover = P:Def("_CustomBars_RegisterMover", _CustomBars_RegisterMover)
_CustomBars_ApplyVisibility = P:Def("_CustomBars_ApplyVisibility", _CustomBars_ApplyVisibility)
_CustomBars_ApplyConfig = P:Def("_CustomBars_ApplyConfig", _CustomBars_ApplyConfig)
_CustomBars_AddSourceIndex = P:Def("_CustomBars_AddSourceIndex", _CustomBars_AddSourceIndex)
_CustomBars_RebuildAll = P:Def("_CustomBars_RebuildAll", _CustomBars_RebuildAll)
_BB_EnsureViewerAuraIconHook = P:Def("_BB_EnsureViewerAuraIconHook", _BB_EnsureViewerAuraIconHook)
_BB_ResetViewerIconIdentity = P:Def("_BB_ResetViewerIconIdentity", _BB_ResetViewerIconIdentity)
_BB_EnsureViewerAuraHooks = P:Def("_BB_EnsureViewerAuraHooks", _BB_EnsureViewerAuraHooks)
_GetViewerIcons = P:Def("_GetViewerIcons", _GetViewerIcons)
_BB_ClearActiveFrameBuffer = P:Def("_BB_ClearActiveFrameBuffer", _BB_ClearActiveFrameBuffer)
_CustomBars_IsTrackedSpellAvailable = P:Def("_CustomBars_IsTrackedSpellAvailable", _CustomBars_IsTrackedSpellAvailable)
_CustomBars_GetIconCooldownID = P:Def("_CustomBars_GetIconCooldownID", _CustomBars_GetIconCooldownID)
_CustomBars_GetIconSpellID = P:Def("_CustomBars_GetIconSpellID", _CustomBars_GetIconSpellID)
_CustomBars_BindBarsToIcon = P:Def("_CustomBars_BindBarsToIcon", _CustomBars_BindBarsToIcon)
_CustomBars_NormalizeAuraTrackMode = P:Def("_CustomBars_NormalizeAuraTrackMode", _CustomBars_NormalizeAuraTrackMode)
_CustomBars_GetAuraTrackUnitAndFilter = P:Def("_CustomBars_GetAuraTrackUnitAndFilter", _CustomBars_GetAuraTrackUnitAndFilter)
_CustomBars_SetViewerIconHidden = P:Def("_CustomBars_SetViewerIconHidden", _CustomBars_SetViewerIconHidden)
_BB_ApplyViewerIconHiddenState = P:Def("_BB_ApplyViewerIconHiddenState", _BB_ApplyViewerIconHiddenState)
_CustomBars_DeleteRuntimeBar = P:Def("_CustomBars_DeleteRuntimeBar", _CustomBars_DeleteRuntimeBar)
_BB_RebuildCustomBars = P:Def("_BB_RebuildCustomBars", _BB_RebuildCustomBars)
_BB_ScheduleRebuildPasses = P:Def("_BB_ScheduleRebuildPasses", _BB_ScheduleRebuildPasses)
_BB_StartupRebuild = P:Def("_BB_StartupRebuild", _BB_StartupRebuild)
_BB_RefreshTrackedSpellAvailability = P:Def("_BB_RefreshTrackedSpellAvailability", _BB_RefreshTrackedSpellAvailability)
_BB_QueueTrackedSpellAvailabilityRefresh = P:Def("_BB_QueueTrackedSpellAvailabilityRefresh", _BB_QueueTrackedSpellAvailabilityRefresh)
EnsureStackBarDefaults = P:Def("EnsureStackBarDefaults", EnsureStackBarDefaults)
CreateNewStackBar = P:Def("CreateNewStackBar", CreateNewStackBar)
CreateNewDurationBar = P:Def("CreateNewDurationBar", CreateNewDurationBar)

BB.ApplySettings = P:Def("BB:ApplySettings", BB.ApplySettings)
BB.SoftRebuild = P:Def("BB:SoftRebuild", BB.SoftRebuild)
BB._OnVisibilityEvent = P:Def("BB:_OnVisibilityEvent", BB._OnVisibilityEvent)
BB._OnPlayerRegenEnabled = P:Def("BB:_OnPlayerRegenEnabled", BB._OnPlayerRegenEnabled)
BB._OnSpellsChanged = P:Def("BB:_OnSpellsChanged", BB._OnSpellsChanged)
BB._OnCooldownViewerDataLoaded = P:Def("BB:_OnCooldownViewerDataLoaded", BB._OnCooldownViewerDataLoaded)
BB._OnCooldownViewerSpellOverrideUpdated = P:Def("BB:_OnCooldownViewerSpellOverrideUpdated", BB._OnCooldownViewerSpellOverrideUpdated)
BB._OnCooldownViewerTableHotfixed = P:Def("BB:_OnCooldownViewerTableHotfixed", BB._OnCooldownViewerTableHotfixed)
BB.OnInitialize = P:Def("BB:OnInitialize", BB.OnInitialize)
BB.OnEnable = P:Def("BB:OnEnable", BB.OnEnable)
BB.OnDisable = P:Def("BB:OnDisable", BB.OnDisable)

_customBarsAuraDriver.IsButtonRestyleLocked = P:Def("_customBarsAuraDriver:IsButtonRestyleLocked", _customBarsAuraDriver.IsButtonRestyleLocked)
_customBarsAuraDriver.InvalidateCandidateCache = P:Def("_customBarsAuraDriver:InvalidateCandidateCache", _customBarsAuraDriver.InvalidateCandidateCache)
_customBarsAuraDriver.ResolveCandidate = P:Def("_customBarsAuraDriver:ResolveCandidate", _customBarsAuraDriver.ResolveCandidate)
_CustomBars_HasEnabledStackColorThreshold = P:Def("_CustomBars_HasEnabledStackColorThreshold", _CustomBars_HasEnabledStackColorThreshold)
_customBarsAuraDriver.ApplyFont = P:Def("_customBarsAuraDriver:ApplyFont", _customBarsAuraDriver.ApplyFont)
_customBarsAuraDriver.GetBarAppearance = P:Def("_customBarsAuraDriver:GetBarAppearance", _customBarsAuraDriver.GetBarAppearance)
_customBarsAuraDriver.CreateChrome = P:Def("_customBarsAuraDriver:CreateChrome", _customBarsAuraDriver.CreateChrome)
_customBarsAuraDriver.ApplyChrome = P:Def("_customBarsAuraDriver:ApplyChrome", _customBarsAuraDriver.ApplyChrome)
_customBarsAuraDriver.SetExternalChromeShown = P:Def("_customBarsAuraDriver:SetExternalChromeShown", _customBarsAuraDriver.SetExternalChromeShown)
_customBarsAuraDriver.GetChromeColors = P:Def("_customBarsAuraDriver:GetChromeColors", _customBarsAuraDriver.GetChromeColors)
_customBarsAuraDriver.UpdateActivity = P:Def("_customBarsAuraDriver:UpdateActivity", _customBarsAuraDriver.UpdateActivity)
_customBarsAuraDriver.ApplyCombinedStyle = P:Def("_customBarsAuraDriver:ApplyCombinedStyle", _customBarsAuraDriver.ApplyCombinedStyle)
_customBarsAuraDriver.ApplyStyle = P:Def("_customBarsAuraDriver:ApplyStyle", _customBarsAuraDriver.ApplyStyle)
_customBarsAuraDriver.WireCombinedButton = P:Def("_customBarsAuraDriver:WireCombinedButton", _customBarsAuraDriver.WireCombinedButton)
_customBarsAuraDriver.CreateSlot = P:Def("_customBarsAuraDriver:CreateSlot", _customBarsAuraDriver.CreateSlot)
_customBarsAuraDriver.GetMode = P:Def("_customBarsAuraDriver:GetMode", _customBarsAuraDriver.GetMode)
_customBarsAuraDriver.Detach = P:Def("_customBarsAuraDriver:Detach", _customBarsAuraDriver.Detach)
_customBarsAuraDriver.Release = P:Def("_customBarsAuraDriver:Release", _customBarsAuraDriver.Release)
_customBarsAuraDriver.Attach = P:Def("_customBarsAuraDriver:Attach", _customBarsAuraDriver.Attach)
_customBarsAuraDriver.FlushDeferred = P:Def("_customBarsAuraDriver:FlushDeferred", _customBarsAuraDriver.FlushDeferred)
_customBarsAuraDriver.DetachAll = P:Def("_customBarsAuraDriver:DetachAll", _customBarsAuraDriver.DetachAll)

API.EnsureStackBarDefaults = EnsureStackBarDefaults
API.CreateNewStackBar = CreateNewStackBar
API.CreateNewDurationBar = CreateNewDurationBar
API.GetStackBarsDB = _GetStackBarsDB
API.IsTrackedSpellAvailable = _CustomBars_IsTrackedSpellAvailable
API.RebuildCustomBars = _BB_RebuildCustomBars
API.RefreshCustomBarStyle = P:Def("API.RefreshCustomBarStyle", API.RefreshCustomBarStyle)
API.DeleteCustomBar = P:Def("API.DeleteCustomBar", API.DeleteCustomBar)
API.SetViewerIconHiddenByCooldownID = P:Def("API.SetViewerIconHiddenByCooldownID", API.SetViewerIconHiddenByCooldownID)
API.SetViewerIconHiddenBySpellID = P:Def("API.SetViewerIconHiddenBySpellID", API.SetViewerIconHiddenBySpellID)
API.RefreshAfterTalentSwap = P:Def("API.RefreshAfterTalentSwap", API.RefreshAfterTalentSwap)
