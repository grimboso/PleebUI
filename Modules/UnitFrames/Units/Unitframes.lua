local ADDON_NAME, ns = ...

local Addon = ns.Addon
local oUF = ns.oUF
local UFDefaults = ns.UFDefaults
local UFStyle = ns.UFStyle
local UFHealth = ns.UFHealth
local UFPower = ns.UFPower
local UFPortrait = ns.UFPortrait
local UFText = ns.UFText
local Presentation = ns.Presentation
local UFTags = ns.UFTags
local UFIndicators = ns.UFIndicators
local UFAuraContainers = ns.UFAuraContainers
local UFAuraLayout = ns.UFAuraLayout

local UFHealPrediction = ns.UFHealPrediction
local UFThreat = ns.UFThreat
local UFFrameGlow = ns.UFFrameGlow
local FrameUtil = ns.FrameUtil
local PRD = ns.Modules.PRD
local Range = ns.Range
local UFMouseover = ns.UFMouseover


local _G = _G
local UIParent = _G.UIParent
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local UnitExists = _G.UnitExists
local tostring = _G.tostring
local tonumber = _G.tonumber
local type = _G.type
local pairs = _G.pairs
local ipairs = _G.ipairs
local math_max = _G.math.max
local math_min = _G.math.min

local UF = Addon:NewModule("UnitFrames", "NumyAceEvent-3.0")
local MAX_BOSS_FRAMES = 5
local BossHeader = CreateFrame("Frame", "PleebUI_BossHeader", UIParent)

ns.UnitFrames = UF
ns.Modules.UnitFrames = UF

local SINGLE_UNITS = {
  "player",
  "pet",
  "target",
  "targettarget",
  "focus",
  "focustarget",
  "boss1",
  "boss2",
  "boss3",
  "boss4",
  "boss5",
}

local BLIZZARD_DISABLE_UNITS = {
  player = true,
  pet = true,
  target = true,
  focus = true,
  boss1 = true,
}

local function DisableBlizzardUnit(unit)
  if BLIZZARD_DISABLE_UNITS[unit] then
    oUF:DisableBlizzard(unit)
  end
end

local GHOST_LABELS = {
  player = "Player",
  pet = "Pet",
  target = "Target",
  targettarget = "Target of Target",
  focus = "Focus",
  focustarget = "Focus Target",
  boss1 = "Boss Frames",
}

local BASE_TEXT_SIZES = {
  player = { 14, 14, 12 },
  pet = { 8, 8, 8 },
  target = { 14, 14, 12 },
  targettarget = { 11, 12, 11 },
  focus = { 8, 8, 8 },
  focustarget = { 11, 12, 11 },
  boss1 = { 12, 12, 12 },
  boss2 = { 12, 12, 12 },
  boss3 = { 12, 12, 12 },
  boss4 = { 12, 12, 12 },
  boss5 = { 12, 12, 12 },
}

local FORCE_NO_POWER = {
  pet = true,
  targettarget = true,
  focus = true,
  focustarget = true,
}

local INDIVIDUAL_RANGE_UNITS = {
  target = true,
  focus = true,
  boss1 = true,
  boss2 = true,
  boss3 = true,
  boss4 = true,
  boss5 = true,
}

local ROOT_SINGLE_UNIT_ANCHORS = {
  player = true,
  target = true,
  focus = true,
  boss1 = true,
}

local CHILD_SINGLE_UNIT_ANCHORS = {
  pet = "player",
  targettarget = "target",
  focustarget = "focus",
  boss2 = "boss1",
  boss3 = "boss2",
  boss4 = "boss3",
  boss5 = "boss4",
}

local TAG_TEXT_FIELDS = {
  "NameText",
  "HealthText",
  "PowerText",
}

local DEFERRED_REFRESH_ORDER = {
  "appearance",
  "resize",
  "layout",
  "visibility",
  "data",
  "text",
  "range",
  "spawns",
}

local DEFERRED_REFRESH_MODES = {
  appearance = true,
  resize = true,
  layout = true,
  visibility = true,
  data = true,
  text = true,
  range = true,
  spawns = true,
}

local function ResolveDeferredRefreshRequest(request)
  local unit
  local mode

  if type(request) == "table" then
    unit = request.unit

    if request.mode then
      mode = request.mode
    elseif request.resize then
      mode = "resize"
    elseif request.layout then
      mode = "layout"
    elseif request.appearance then
      mode = "appearance"
    elseif request.visibility then
      mode = "visibility"
    elseif request.data then
      mode = "data"
    elseif request.text then
      mode = "text"
    elseif request.range then
      mode = "range"
    end
  else
    mode = request
  end

  mode = mode or "all"
  if mode ~= "all" and DEFERRED_REFRESH_MODES[mode] ~= true then
    mode = "all"
  end

  return unit, mode
end

local function AddDeferredMode(modes, mode)
  if modes.all == true then
    return
  end

  if mode == "all" then
    for key in pairs(modes) do
      modes[key] = nil
    end
    modes.all = true
    return
  end

  modes[mode] = true
end

local function QueueDeferredRefresh(owner, request)
  local unit, mode = ResolveDeferredRefreshRequest(request)
  local pending = owner.__puiDeferredRefresh

  if not pending then
    pending = {
      global = {},
      units = {},
    }
    owner.__puiDeferredRefresh = pending
  end

  if pending.all ~= true then
    if unit then
      local modes = pending.units[unit]
      if not modes then
        modes = {}
        pending.units[unit] = modes
      end

      AddDeferredMode(modes, mode)
    elseif mode == "all" then
      pending.all = true
      pending.global = {}
      pending.units = {}
    else
      AddDeferredMode(pending.global, mode)
    end
  end

  owner:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function RunDeferredModes(modes, callback)
  if modes.all == true then
    callback("all")
    return
  end

  for index = 1, #DEFERRED_REFRESH_ORDER do
    local mode = DEFERRED_REFRESH_ORDER[index]
    if modes[mode] == true then
      callback(mode)
    end
  end
end

local function FlushDeferredRefreshes(owner, refreshGlobal, refreshUnit)
  local pending = owner.__puiDeferredRefresh
  owner.__puiDeferredRefresh = nil

  if not pending then
    return false
  end

  if pending.all == true then
    refreshGlobal("all")
    return true
  end

  RunDeferredModes(pending.global, refreshGlobal)

  if refreshUnit then
    for unit, modes in pairs(pending.units) do
      RunDeferredModes(modes, function(mode)
        refreshUnit(unit, mode)
      end)
    end
  end

  return true
end

local function CopyTable(src)
  local out = {}

  if type(src) ~= "table" then
    return out
  end

  for key, value in pairs(src) do
    if type(value) == "table" then
      out[key] = CopyTable(value)
    else
      out[key] = value
    end
  end

  return out
end

local function MergeMissing(dst, src)
  if type(dst) ~= "table" or type(src) ~= "table" then
    return dst
  end

  for key, value in pairs(src) do
    if type(value) == "table" then
      if type(dst[key]) ~= "table" then
        dst[key] = {}
      end
      MergeMissing(dst[key], value)
    elseif dst[key] == nil then
      dst[key] = value
    end
  end

  return dst
end



local Round = ns.Pixel.Round

local function ResolveRelativeToObject(cfg, frame, unit)
  if ROOT_SINGLE_UNIT_ANCHORS[unit] then
    cfg.relativeTo = "UIParent"
    cfg.relativePoint = cfg.relativePoint or cfg.point or "CENTER"
  end

  local relTo = cfg and cfg.relativeTo
  local parent = UIParent

  if type(relTo) == "table" then
    parent = relTo
  elseif type(relTo) == "string" and relTo ~= "" and relTo ~= "UIParent" then
    parent = _G[relTo] or UIParent
  end

  local parentName = parent.GetName and parent:GetName() or nil
  if parent == frame
    or (type(parentName) == "string" and parentName:match("^PleebUI_UnitFrame_"))
    or (type(parentName) == "string" and parentName:match("^PleebUI_UF_Ghost_"))
  then
    cfg.relativeTo = "UIParent"
    cfg.relativePoint = cfg.relativePoint or cfg.point or "CENTER"
    return UIParent
  end

  local check = parent
  while check do
    if check == frame then
      cfg.relativeTo = "UIParent"
      cfg.relativePoint = cfg.relativePoint or cfg.point or "CENTER"
      return UIParent
    end

    check = check.GetParent and check:GetParent() or nil
  end

  return parent
end

local function GetSingleUnitHolderName(unit)
  return "PleebUI_UnitFrame_" .. unit .. "_Holder"
end

local function GetSingleUnitHolder(unit)
  return _G[GetSingleUnitHolderName(unit)]
end

local function IsBossUnit(unit)
  return type(unit) == "string" and unit:match("^boss%d+$") ~= nil
end

local function GetBossIndex(unit)
  return tonumber(type(unit) == "string" and unit:match("^boss(%d+)$")) or nil
end

local function GetBossGrowthDirection(cfg)
  local growthDirection = cfg and cfg.growthDirection or "DOWN"

  if growthDirection == "UP" or growthDirection == "LEFT" or growthDirection == "RIGHT" then
    return growthDirection
  end

  return "DOWN"
end

local function GetBossHeaderSize()
  local shared = UF.db.profile.units.boss
  local width, height = UFStyle.ResolveFrameSize(shared)
  local spacing = Round(shared and shared.spacing or 30)
  local growthDirection = GetBossGrowthDirection(shared)

  if growthDirection == "UP" or growthDirection == "DOWN" then
    return width, height + ((height + spacing) * (MAX_BOSS_FRAMES - 1)), growthDirection, spacing
  end

  return width + ((width + spacing) * (MAX_BOSS_FRAMES - 1)), height, growthDirection, spacing
end

local function ConfigureBossHeader()
  local anchor = UF.db.profile.units.boss1
  local width, height, growthDirection, spacing = GetBossHeaderSize()

  BossHeader:SetSize(width, height)

  if anchor then
    local parent = ResolveRelativeToObject(anchor, BossHeader, "boss1")
    local point = anchor.point or "CENTER"
    BossHeader:ClearAllPoints()
    BossHeader:SetPoint(point, parent, anchor.relativePoint or point, Round(anchor.x or 0), Round(anchor.y or 0))
  end

  BossHeader:Show()

  return BossHeader, growthDirection, spacing
end

local function GetAnchorCoordinate(width, height, point)
  point = point or "CENTER"

  local x = width * 0.5
  if point:find("LEFT", 1, true) then
    x = 0
  elseif point:find("RIGHT", 1, true) then
    x = width
  end

  local y = height * 0.5
  if point:find("TOP", 1, true) then
    y = height
  elseif point:find("BOTTOM", 1, true) then
    y = 0
  end

  return x, y
end

local function GetAnchoredIconBounds(anchorX, anchorY, anchorPoint, size)
  anchorPoint = anchorPoint or "CENTER"

  local left = anchorX - (size * 0.5)
  if anchorPoint:find("LEFT", 1, true) then
    left = anchorX
  elseif anchorPoint:find("RIGHT", 1, true) then
    left = anchorX - size
  end

  local bottom = anchorY - (size * 0.5)
  if anchorPoint:find("TOP", 1, true) then
    bottom = anchorY - size
  elseif anchorPoint:find("BOTTOM", 1, true) then
    bottom = anchorY
  end

  return left, left + size, bottom + size, bottom
end

local function GetAuraDisplayBounds(frameWidth, frameHeight, healthHeight, display)
  local metrics = UFAuraLayout.ResolveDisplayMetrics(
    frameWidth,
    healthHeight,
    1,
    false,
    display
  )
  local anchorX, anchorY = GetAnchorCoordinate(
    frameWidth,
    frameHeight,
    display.relativePoint or display.anchorPoint
  )
  anchorX = anchorX + Round(display.xOffset or 0)
  anchorY = anchorY + Round(display.yOffset or 0)

  local left
  local right
  local top
  local bottom

  for index = 1, metrics.maxIcons do
    local xOffset, yOffset = UFAuraLayout.GetIconOffset(metrics, index)
    local iconLeft, iconRight, iconTop, iconBottom = GetAnchoredIconBounds(
      anchorX + xOffset,
      anchorY + yOffset,
      display.anchorPoint,
      metrics.size
    )

    left = left and math_min(left, iconLeft) or iconLeft
    right = right and math_max(right, iconRight) or iconRight
    top = top and math_max(top, iconTop) or iconTop
    bottom = bottom and math_min(bottom, iconBottom) or iconBottom
  end

  return left, right, top, bottom
end

local function GetUnitFrameAuraSnapInsets(unitKey, owner)
  if unitKey ~= "target" and unitKey ~= "focus" and unitKey ~= "boss1" then
    return 0, 0, 0, 0
  end

  local unit = unitKey == "boss1" and "boss1" or unitKey
  local frame = owner.frames and owner.frames[unit]
  local cfg = owner:ResolveUnitConfig(unit)
  if not frame or not cfg then
    return 0, 0, 0, 0
  end

  local frameWidth, frameHeight = UFStyle.ResolveFrameSize(cfg)
  local healthHeight = frame.Health and frame.Health:GetHeight()
  if not healthHeight or healthHeight <= 0 then
    local layout = UFStyle.CalculateFrameLayout(cfg, owner.db.profile, {
      forceNoPower = FORCE_NO_POWER[unit] == true,
    })
    healthHeight = layout.healthHeight
  end

  local auraDB = ns.UFAuraFilters.BuildFrameAuraDB(frame, unit)
  if auraDB.enabled == false then
    return 0, 0, 0, 0
  end

  local left = 0
  local right = frameWidth
  local top = frameHeight
  local bottom = 0

  for _, display in pairs(auraDB.customDisplays or {}) do
    if UFAuraContainers.IsDisplayEnabled(auraDB, display) then
      local displayLeft, displayRight, displayTop, displayBottom = GetAuraDisplayBounds(
        frameWidth,
        frameHeight,
        healthHeight,
        display
      )
      left = math_min(left, displayLeft)
      right = math_max(right, displayRight)
      top = math_max(top, displayTop)
      bottom = math_min(bottom, displayBottom)
    end
  end

  return
    Round(math_max(0, -left)),
    Round(math_max(0, right - frameWidth)),
    Round(math_max(0, top - frameHeight)),
    Round(math_max(0, -bottom))
end

local function PositionBossHolder(holder, unit, cfg)
  local header, growthDirection, spacing = ConfigureBossHeader()
  local bossMover = ns.TestMode:IsActive() and UF.ghosts and UF.ghosts.boss1 or nil
  if bossMover then
    header:ClearAllPoints()
    header:SetAllPoints(bossMover)
  end
  local index = GetBossIndex(unit) or 1
  local width, height = UFStyle.ResolveFrameSize(cfg)

  holder:SetParent(UIParent)
  holder:SetSize(width, height)
  holder:ClearAllPoints()

  if index == 1 then
    if growthDirection == "UP" then
      holder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    elseif growthDirection == "RIGHT" then
      holder:SetPoint("LEFT", header, "LEFT", 0, 0)
    elseif growthDirection == "LEFT" then
      holder:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    else
      holder:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    end
  else
    local previous = GetSingleUnitHolder("boss" .. (index - 1)) or header

    if growthDirection == "UP" then
      holder:SetPoint("BOTTOMRIGHT", previous, "TOPRIGHT", 0, spacing)
    elseif growthDirection == "RIGHT" then
      holder:SetPoint("LEFT", previous, "RIGHT", spacing, 0)
    elseif growthDirection == "LEFT" then
      holder:SetPoint("RIGHT", previous, "LEFT", -spacing, 0)
    else
      holder:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -spacing)
    end
  end

  holder:Show()
end

local function ResolveSingleUnitHolderParent(cfg, frame, unit)
  local parentUnit = CHILD_SINGLE_UNIT_ANCHORS[unit]
  if parentUnit then
    local relativeTo = cfg and cfg.relativeTo
    local defaultRelativeTo = "PleebUI_UnitFrame_" .. parentUnit
    local defaultHolderName = GetSingleUnitHolderName(parentUnit)

    if relativeTo == nil
      or relativeTo == ""
      or relativeTo == defaultRelativeTo
      or relativeTo == defaultHolderName
    then
      return GetSingleUnitHolder(parentUnit) or UIParent
    end
  end

  return ResolveRelativeToObject(cfg, frame, unit)
end

local function EnsureSingleUnitPositionHolder(frame, unit, cfg)
  local holder = frame.__puiPositionHolder or GetSingleUnitHolder(unit) or CreateFrame("Frame", GetSingleUnitHolderName(unit), UIParent)

  frame.__puiPositionHolder = holder

  if IsBossUnit(unit) then
    PositionBossHolder(holder, unit, cfg)
    return holder
  end

  local parent = ResolveSingleUnitHolderParent(cfg, frame, unit)
  local point = cfg.point or "CENTER"
  local relativePoint = cfg.relativePoint or point
  local width, height = UFStyle.ResolveFrameSize(cfg)

  holder:SetParent(UIParent)
  holder:SetSize(width, height)
  holder:ClearAllPoints()
  holder:SetPoint(point, parent, relativePoint, Round(cfg.x or 0), Round(cfg.y or 0))
  holder:Show()

  return holder
end

local function ApplySingleUnitFlags(frame, unit)
  frame.__puiSingleUnitKey = unit
  frame.__puiBossIndex = GetBossIndex(unit)
  frame.__puiForceNoPower = FORCE_NO_POWER[unit] == true
  frame.__puiUseIndividualRange = INDIVIDUAL_RANGE_UNITS[unit] == true

  if unit == "player" or unit == "pet" then
    frame.__puiSingleUnitFamily = "player"
  elseif unit == "target" or unit == "targettarget" then
    frame.__puiSingleUnitFamily = "target"
  elseif unit == "focus" or unit == "focustarget" then
    frame.__puiSingleUnitFamily = "focus"
  elseif IsBossUnit(unit) then
    frame.__puiSingleUnitFamily = "boss"
  end
end

function UF:EnsureConfigDefaults(db)
  db = db or self.db.profile

  MergeMissing(db, UFDefaults.Profile)
  db.units = db.units or {}
  db.units.player = db.units.player or {}

  for unit, defaults in pairs(UFDefaults.Player or {}) do
    db.units[unit] = db.units[unit] or {}
    MergeMissing(db.units[unit], defaults)
  end

  for unit, defaults in pairs(UFDefaults.Target or {}) do
    db.units[unit] = db.units[unit] or {}
    MergeMissing(db.units[unit], defaults)
  end

  for unit, defaults in pairs(UFDefaults.Focus or {}) do
    db.units[unit] = db.units[unit] or {}
    MergeMissing(db.units[unit], defaults)
  end

  db.units.boss = db.units.boss or {}
  MergeMissing(db.units.boss, UFDefaults.Boss.boss)

  for index = 1, 5 do
    local unit = "boss" .. index
    db.units[unit] = db.units[unit] or {}
    MergeMissing(db.units[unit], UFDefaults.Boss[unit])
  end

  ns.UFAuraFilters.NormalizeDisplays(db.auras)

  for _, config in pairs(db.units) do
    if type(config) == "table" and type(config.auras) == "table" then
      ns.UFAuraFilters.NormalizeDisplays(config.auras)
    end
  end

  return db
end

function UF:GetConfigUnit(unit)
  local db = self.db.profile

  if unit == "boss" then
    return db.units.boss
  end

  return self:ResolveUnitConfig(unit, db)
end

function UF:GetDefaultUnitConfig(unit)
  if UFDefaults.Player[unit] then
    return UFDefaults.Player[unit]
  elseif UFDefaults.Target[unit] then
    return UFDefaults.Target[unit]
  elseif UFDefaults.Focus[unit] then
    return UFDefaults.Focus[unit]
  elseif unit == "boss" then
    return UFDefaults.Boss.boss
  elseif UFDefaults.Boss[unit] then
    return UFDefaults.Boss[unit]
  end
end

function UF:GetBaseTextSizesForUnit(unit)
  local sizes = BASE_TEXT_SIZES[unit] or BASE_TEXT_SIZES.player
  return sizes[1], sizes[2], sizes[3]
end

function UF:ResolveUnitConfig(unit, db)
  db = db or self.db.profile

  if not unit or not db or not db.units then
    return nil
  end

  if unit == "boss" then
    return db.units.boss
  end

  if IsBossUnit(unit) then
    self._bossConfigProxy = self._bossConfigProxy or {}

    local proxy = self._bossConfigProxy[unit]
    if not proxy then
      proxy = {}
      self._bossConfigProxy[unit] = proxy

      setmetatable(proxy, {
        __index = function(t, key)
          local per = rawget(t, "__per")
          local shared = rawget(t, "__shared")

          if key == "enabled" or key == "point" or key == "relativeTo" or key == "relativePoint" or key == "x" or key == "y" then
            return per and per[key]
          end

          if per and per[key] ~= nil then
            return per[key]
          end

          return shared and shared[key]
        end,
      })
    end

    proxy.__per = db.units[unit]
    proxy.__shared = db.units.boss
    return proxy
  end

  return db.units[unit]
end

function UF:GetTestFrameConfig(unit)
  local db = self.db.profile
  local cfg = self:ResolveUnitConfig(unit, db)

  return cfg, db, FORCE_NO_POWER[unit] == true
end

function UF:LayoutTestFrame(frame, unit)
  if InCombatLockdown() then
    return false
  end

  local cfg = self:ResolveUnitConfig(unit)
  if not frame or not cfg then
    return false
  end

  local mover = not IsBossUnit(unit) and self.ghosts and self.ghosts[unit] or nil
  if mover then
    frame:SetParent(UIParent)
    frame:ClearAllPoints()
    frame:SetAllPoints(mover)
    frame:Show()
    return true
  end

  local holder = EnsureSingleUnitPositionHolder(frame, unit, cfg)
  frame:SetParent(UIParent)
  frame:ClearAllPoints()
  frame:SetAllPoints(holder)
  frame:Show()
  return true
end

function UF:RefreshFrameColors(frame, flags)
  if not frame or not frame.config or not frame.__puiFrameLayout then
    return
  end

  local colors = UFStyle.GetUFThemeColors()

  if flags then
    local targeted = false

    if flags.healthColor then
      UFHealth.RefreshColors(frame, frame.config, colors)
      targeted = true
    elseif flags.healthMissingColor then
      UFHealth.RefreshMissingColor(frame, frame.config, colors)
      targeted = true
    end

    if flags.powerMissingColor then
      UFPower.RefreshColors(frame, frame.config, colors)
      targeted = true
    end

    if targeted then
      return
    end
  end

  ns.UFPresentation.ApplyStyle(frame, {
    config = frame.config,
    layout = frame.__puiFrameLayout,
    colors = colors,
    textColors = self.db.profile.colors,
    refreshOnly = true,
  })
end

function UF:RefreshFramePowerLayout(frame, cfg, opts)
  if not frame or not cfg then
    return
  end

  opts = type(opts) == "table" and opts or {}

  local unit = frame.__puiConfigUnit
  if not unit then
    return
  end

  local db = opts.db or self.db.profile
  local forceNoPower = opts.forceNoPower == true or FORCE_NO_POWER[unit] == true or frame.__puiForceNoPower == true
  local layout = UFStyle.CalculateFrameLayout(cfg, db, {
    forceNoPower = forceNoPower,
  })
  local colors = UFStyle.GetUFThemeColors()
  local powerWasEnabled = frame:IsElementEnabled("Power")

  frame.config = cfg
  frame.__puiFrameLayout = layout
  frame.__puiUseConfigText = opts.groupKind == "party" or opts.groupKind == "raid" or frame.__puiUseConfigText == true

  Presentation.Apply("UnitFrame", frame, {
    unit = unit,
    config = cfg,
    layout = layout,
    colors = colors,
    textColors = db and db.colors,
    fontRevision = self._fontRev or 0,
    skipVisibility = true,
    options = {
      forceNoPower = forceNoPower,
      groupKind = opts.groupKind,
      useConfigText = opts.groupKind == "party" or opts.groupKind == "raid",
    },
  })

  local power = frame.Power:IsShown() and frame.Power or nil

  if power and not powerWasEnabled then
    power:ForceUpdate()
  end
end

function UF:ConstructUnitFrame(frame, unit, cfg, opts)
  opts = opts or {}

  frame.__puiUF_oUFInitialized = false
  frame.__puiConfigUnit = unit
  frame.config = cfg
  frame.__puiGroupKind = opts.groupKind
  frame.__puiUseClassColor = opts.useClassColor
  frame.__puiUseConfigText = opts.groupKind == "party" or opts.groupKind == "raid"
  frame.__puiAuraDBBuilder = opts.auraDBBuilder
  frame.__puiTrackingDBBuilder = opts.trackingDBBuilder
  frame.__puiTrackingDB = opts.trackingDBBuilder and opts.trackingDBBuilder(unit) or cfg.tracking
  frame.__puiEnableMouseover = nil


  if opts.singleUnit then
    ApplySingleUnitFlags(frame, unit)
  end

  frame:SetFrameStrata("LOW")
  frame:RegisterForClicks("AnyUp")

  UFStyle.BuildUnitFrameVisuals(frame, unit, cfg)

  UFMouseover.ApplyScripts(frame)

  if opts.groupKind == "party" or opts.groupKind == "raid" then
    UFIndicators.EnsureSharedUnitIndicators(
      frame,
      frame.TextureParent or frame.RaisedElementParent or frame,
      opts.roleConfigProvider,
      opts.roleDefaults,
      {
        role = frame.TextureParent or frame.RaisedElementParent or frame,
        leader = frame.RaisedElementParent or frame,
        raidTarget = frame.TextureParent or frame.RaisedElementParent or frame,
        status = frame.TextureParent or frame.RaisedElementParent or frame,
        readyCheck = frame.TextureParent or frame.RaisedElementParent or frame,
      }
    )
    UFThreat.Construct(frame)
  end

  frame.__puiAuraContainerDB = ns.UFAuraFilters.BuildFrameAuraDB(frame, unit)

  if ns.Modules.CastBar.UnitLookup[unit] then
    ns.Modules.CastBar:AttachToUnitFrame(frame, unit)
  end

  if opts.groupKind == "party" or opts.groupKind == "raid" then
    UFFrameGlow.ConstructTargetHighlight(frame)
  end
end

function UF:PrepareFrameState(frame, unit, cfg, opts)
  opts = type(opts) == "table" and opts or {}

  local db = opts.db or self.db.profile
  cfg = cfg or self:ResolveUnitConfig(unit, db)

  if not frame or not unit or not cfg or cfg.enabled == false then
    return nil
  end

  frame.__puiConfigUnit = unit
  frame.config = cfg
  frame.__puiGroupKind = opts.groupKind or frame.__puiGroupKind

  if opts.useClassColor ~= nil then
    frame.__puiUseClassColor = opts.useClassColor
  elseif unit == "player" then
    frame.__puiUseClassColor = cfg.useClassColor ~= false
  else
    frame.__puiUseClassColor = true
  end

  frame.__puiUseConfigText = opts.useConfigText == true
    or opts.groupKind == "party"
    or opts.groupKind == "raid"
  frame.__puiAuraDBBuilder = opts.auraDBBuilder or frame.__puiAuraDBBuilder
  frame.__puiTrackingDBBuilder = opts.trackingDBBuilder or frame.__puiTrackingDBBuilder
  frame.__puiTrackingDB = frame.__puiTrackingDBBuilder
    and frame.__puiTrackingDBBuilder(unit)
    or cfg.tracking
  frame.__puiEnableMouseover = nil

  local forceNoPower = opts.forceNoPower == true
    or FORCE_NO_POWER[unit] == true
    or frame.__puiForceNoPower == true
  local layout = UFStyle.CalculateFrameLayout(cfg, db, {
    forceNoPower = forceNoPower,
  })

  frame.__puiFrameLayout = layout

  return {
    unit = unit,
    config = cfg,
    db = db,
    layout = layout,
    colors = UFStyle.GetUFThemeColors(),
    forceNoPower = forceNoPower,
    options = opts,
  }
end

function UF:ApplyFrameAppearance(frame, state, refreshOnly)
  ns.UFPresentation.ApplyStyle(frame, {
    config = state.config,
    layout = state.layout,
    colors = state.colors,
    textColors = state.db.colors,
    useClassColor = frame.__puiUseClassColor,
    refreshOnly = refreshOnly == true,
  })
end

function UF:ApplyFrameLayout(frame, state)
  ns.UFPresentation.ApplyGeometry(frame, {
    unit = state.unit,
    config = state.config,
    layout = state.layout,
    colors = state.colors,
    textColors = state.db.colors,
    fontRevision = self._fontRev or 0,
    options = {
      forceNoPower = state.forceNoPower,
      groupKind = state.options.groupKind,
      useConfigText = state.options.groupKind == "party" or state.options.groupKind == "raid",
    },
  })
end

function UF:ApplyFrameIndicators(frame, state)
  local absorbTexture = UFStyle.ResolveStatusbarTexture("absorb", state.unit, state.config)
  UFHealPrediction.Configure(frame, absorbTexture)
  UFIndicators.ConstructNativeStatusElements(frame, state.unit, state.config)

  if state.options.groupKind == "party" or state.options.groupKind == "raid" then
    UFIndicators.ConfigureSharedUnitIndicators(frame, state.layout)
    UFFrameGlow.UpdateSharedTargetHighlight(frame)
    UFThreat.Configure(frame)
  end

  if ns.Modules.CastBar.UnitLookup[state.unit] then
    ns.Modules.CastBar:UpdateUnitLayout(state.unit)
  end
end

function UF:ApplyFramePosition(frame, state)
  if state.options.skipPosition == true then
    return
  end

  local holder = EnsureSingleUnitPositionHolder(frame, state.unit, state.config)
  frame:ClearAllPoints()
  frame:SetAllPoints(holder)
end

function UF:ApplyFrameVisibilityAndRange(frame, state)
  frame:SetAlpha(1)

  if state.options.groupKind == nil then
    if frame.isForced == true or UnitExists(state.unit) or state.unit == "player" then
      frame:Show()
    else
      frame:Hide()
    end
  end

  if state.options.groupKind ~= nil or frame.__puiUseIndividualRange == true then
    Range.RegisterFrame(
      state.options.rangeOwner or self,
      frame,
      state.db.range
    )
  end
end

function UF:SuspendFrameElements(frame)
  if not frame or frame.__puiElementsPaused == true then
    return
  end

  frame.__puiElementsPaused = true
  frame:PauseAllElements()

  for index = 1, #TAG_TEXT_FIELDS do
    local fontString = frame[TAG_TEXT_FIELDS[index]]
    if fontString and fontString.__puiTagString then
      frame:Untag(fontString)
      fontString.__puiTagString = nil
    end
  end
end

function UF:RestoreFrameElements(frame, unit)
  if not frame or frame.__puiElementsPaused ~= true or type(unit) ~= "string" then
    return
  end

  frame.__puiElementsPaused = nil
  frame:ResumeAllElements()
  UFText.RefreshTextForFrame(frame, self._fontRev or 0)

  UFAuraContainers.RestoreConfiguredState(frame)
end

function UF:ForceUnitData(frame, event)
  if not frame then
    return
  end

  frame:UpdateAllElements(event or "PUI_UNITFRAME_DATA")
end

function UF:RefreshUnitFrame(frame, unit, cfg, opts, mode)
  mode = mode or "all"

  if not frame or not unit then
    return
  end

  if mode == "data" then
    local activeUnit = frame.__unit
    frame.config = cfg or frame.config
    self:RestoreFrameElements(frame, activeUnit)
    self:ForceUnitData(frame, "PUI_UNITFRAME_DATA")
    return
  elseif mode == "text" then
    frame.config = cfg or frame.config
    UFText.RefreshTextForFrame(frame, self._fontRev or 0)
    return
  end

  local state = self:PrepareFrameState(frame, unit, cfg, opts)
  if not state then
    self:DisableFrameRuntime(frame)
    return
  end

  self:RestoreFrameElements(frame, frame.__unit)
  UFMouseover.ApplyScripts(frame)

  if mode == "visibility" then
    self:ApplyFramePosition(frame, state)
    self:ApplyFrameVisibilityAndRange(frame, state)
    return
  elseif mode == "appearance" then
    self:ApplyFrameAppearance(frame, state, true)
    return
  elseif mode == "healthPrediction" then
    local predictionTexture = UFStyle.ResolveStatusbarTexture("absorb", state.unit, state.config)
    UFHealPrediction.Configure(frame, predictionTexture)
    return
  elseif mode == "indicators" then
    UFIndicators.ConstructNativeStatusElements(frame, state.unit, state.config)
    return
  elseif mode == "resize" then
    self:ApplyFrameAppearance(frame, state, false)
    self:ApplyFrameLayout(frame, state)

    local absorbTexture = UFStyle.ResolveStatusbarTexture("absorb", state.unit, state.config)
    UFHealPrediction.Configure(frame, absorbTexture)
    UFIndicators.ConstructNativeStatusElements(frame, state.unit, state.config)

    self:ApplyFramePosition(frame, state)
    UFAuraContainers.Configure(frame)
    return
  elseif mode == "layout" then
    self:ApplyFramePosition(frame, state)
    return
  end

  self:ApplyFrameAppearance(frame, state, false)
  self:ApplyFrameLayout(frame, state)
  self:ApplyFrameIndicators(frame, state)
  self:ApplyFramePosition(frame, state)
  UFAuraContainers.Configure(frame)
  self:ApplyFrameVisibilityAndRange(frame, state)

  if mode == "all" then
    self:ForceUnitData(frame, "PUI_UNITFRAME_UPDATE")
  end
end

function UF:DisableFrameRuntime(frame)
  if not frame then
    return
  end

  Range.Detach(frame)
  self:SuspendFrameElements(frame)

  frame:Hide()
end

function UF:RegisterSingleStyle()
  if self._singleStyleRegistered then
    return
  end

  self._singleStyleRegistered = true

  oUF:RegisterStyle("PleebUI_SingleUnitFrame", function(frame, unit)
    local cfg = UF:ResolveUnitConfig(unit)
    UF:ConstructUnitFrame(frame, unit, cfg, {
      singleUnit = true,
    })
  end)
end

function UF:SpawnUnit(unit)
  if InCombatLockdown() then
    QueueDeferredRefresh(self, {
      unit = unit,
      mode = "all",
    })
    return nil
  end

  local cfg = self:ResolveUnitConfig(unit)
  if self.db.profile.enabled == false then
    if self.frames and self.frames[unit] then
      self.frames[unit]:Hide()
    end
    return nil
  end

  if not cfg or cfg.enabled == false then
    if self.db.profile.hideBlizzard == true then
      DisableBlizzardUnit(unit)
    end

    if self.frames and self.frames[unit] then
      self.frames[unit]:Hide()
    end
    return nil
  end

  self.frames = self.frames or {}

  if self.frames[unit] then
    self.units = self.units or {}
    self.units[unit] = self.frames[unit]
    self[unit] = self.frames[unit]

    self:RefreshUnitFrame(self.frames[unit], unit, cfg, {
      singleUnit = true,
    }, "all")
    return self.frames[unit]
  end

  self:RegisterSingleStyle()

  local previousStyle = oUF:GetActiveStyle()
  oUF:SetActiveStyle("PleebUI_SingleUnitFrame")

  local frame = oUF:Spawn(unit, "PleebUI_UnitFrame_" .. unit)

  oUF:SetActiveStyle(previousStyle)

  self.frames[unit] = frame
  self.units = self.units or {}
  self.units[unit] = frame
  self[unit] = frame

  self:RefreshUnitFrame(frame, unit, cfg, {
    singleUnit = true,
  }, "all")

  return frame
end

function UF:HideSingleUnitFrame(unit)
  local frame = self.frames and self.frames[unit]
  if frame then
    self:DisableFrameRuntime(frame)
  end
end

function UF:LoadSingleUnits()
  for index = 1, #SINGLE_UNITS do
    self:SpawnUnit(SINGLE_UNITS[index])
  end
end


function UF:IterateSingleFrames(callback)
  for _, frame in pairs(self.frames or {}) do
    callback(frame)
  end
end

function UF:IterateHeaderChildren(header, callback)
  if not header then
    return
  end

  local index = 1
  local frame = header:GetAttribute("child1")

  while frame do
    if frame.__puiUF_oUFInitialized == true then
      callback(frame, index)
    end

    index = index + 1
    frame = header:GetAttribute("child" .. index)
  end
end



function UF:RefreshNameTags()
  UFTags.RefreshNameTags(self)

  self:IterateSingleFrames(function(frame)
    UFText.RefreshTextForFrame(frame, self._fontRev or 0)
  end)
end


function UF:RefreshMouseoverSettings()
  UFMouseover.InvalidateRuntimeConfigCache()

  self:IterateSingleFrames(function(frame)
    UFMouseover.RefreshFrame(frame)
  end)
end

local function RefreshAuraSnapMovers(unit)
  if InCombatLockdown() then
    return
  end

  if unit == "target" or unit == "focus" then
    FrameUtil:RefreshGhostMover("UF_" .. unit)
  elseif unit == "boss" or IsBossUnit(unit) then
    FrameUtil:RefreshGhostMover("UF_boss1")
  elseif unit == nil then
    FrameUtil:RefreshGhostMover("UF_target")
    FrameUtil:RefreshGhostMover("UF_focus")
    FrameUtil:RefreshGhostMover("UF_boss1")
  end
end

function UF:RefreshAuraDisplay(flags)
  local unit = flags and flags.unit

  if unit == "boss" then
    for index = 1, MAX_BOSS_FRAMES do
      local frame = self.frames["boss" .. index]
      if frame then
        UFAuraContainers.RefreshFrame(frame, flags)
      end
    end
    RefreshAuraSnapMovers(unit)
    return
  end

  if unit then
    local frame = self.frames[unit]
    if frame then
      UFAuraContainers.RefreshFrame(frame, flags)
    end
    RefreshAuraSnapMovers(unit)
    return
  end

  self:IterateSingleFrames(function(frame)
    UFAuraContainers.RefreshFrame(frame, flags)
  end)
  RefreshAuraSnapMovers(nil)
end


local function GetUnitFrameOptionsTab(unitKey)
  if unitKey == "player" then
    return "player"
  elseif unitKey == "target" then
    return "target"
  elseif unitKey == "targettarget" then
    return "targettarget"
  elseif unitKey == "focus" then
    return "focus"
  elseif unitKey == "focustarget" then
    return "focustarget"
  elseif unitKey == "boss1" then
    return "boss"
  elseif unitKey == "pet" then
    return "special"
  end

  return "general"
end

function UF:EnsureMovers()
  local function SavePosition(unitKey, owner, mover)
    if not owner.db or not owner.db.profile or not owner.db.profile.units then
      return
    end

    local cfg = owner.db.profile.units[unitKey]
    if not cfg then
      return
    end

    local xOfs, yOfs = FrameUtil.GetMoverOffsets(mover)

    cfg.point = "CENTER"
    cfg.relativeTo = "UIParent"
    cfg.relativePoint = "CENTER"
    cfg.x = Round(xOfs or 0)
    cfg.y = Round(yOfs or 0)

    if InCombatLockdown() then
      return
    end

    if unitKey == "boss1" then
      ConfigureBossHeader()
      owner:RefreshSingleUnit("boss", "layout")
      return
    end

    local real = owner.frames and owner.frames[unitKey]
    if real then
      local holder = EnsureSingleUnitPositionHolder(real, unitKey, cfg)

      real:ClearAllPoints()
      real:SetAllPoints(holder)
    end
  end

  FrameUtil.EnsureGhostMovers(self, {
    labels = GHOST_LABELS,
    keyPrefix = "UF_",
    frameNamePrefix = "PleebUI_UF_Ghost_",
    optionsString = function(unitKey)
      return "unitframes," .. GetUnitFrameOptionsTab(unitKey)
    end,
    overlayBelowFrame = false,
    quickSettings = function(unitKey)
      return ns.UnitFrameTest:OpenQuickSettings("UF_" .. unitKey)
    end,
    smartSnap = function(unitKey, owner)
      local function IsActive()
        local db = owner.db and owner.db.profile
        local cfg = owner:ResolveUnitConfig(unitKey)
        return db
          and db.enabled ~= false
          and cfg
          and cfg.enabled ~= false
      end

      if unitKey == "player" then
        return {
          family = "unitFramesPlayer",
          families = { combatBars = true },
          isRuntimeActive = IsActive,
          syncAxis = "WIDTH",
          syncWidthMin = 120,
          syncWidthMax = 600,
          getSyncWidth = function()
            local cfg = owner:ResolveUnitConfig("player")
            return cfg and cfg.width or nil
          end,
          applySyncWidth = function(width)
            local cfg = owner:ResolveUnitConfig("player")
            if not cfg then
              return
            end

            cfg.width = Round(width)
            owner:RefreshSingleUnit("player", "resize")

            if ns.TestMode:IsActive() then
              ns.TestMode:Refresh("unitframes", "smart-snap-width", "uf.singleSettings")
            end
          end,
        }
      elseif unitKey == "target" or unitKey == "targettarget" then
        return {
          family = "unitFramesTarget",
          isRuntimeActive = IsActive,
          getSnapInsets = function()
            return GetUnitFrameAuraSnapInsets(unitKey, owner)
          end,
        }
      elseif unitKey == "focus" or unitKey == "focustarget" then
        return {
          family = "unitFramesFocus",
          isRuntimeActive = IsActive,
          getSnapInsets = function()
            return GetUnitFrameAuraSnapInsets(unitKey, owner)
          end,
        }
      elseif unitKey == "pet" then
        return {
          family = "unitFramesPet",
          isRuntimeActive = IsActive,
        }
      elseif unitKey == "boss1" then
        return {
          family = "unitFramesBoss",
          families = {
            unitFramesFocus = true,
            unitFramesTarget = true,
          },
          isRuntimeActive = IsActive,
          syncAxis = "NONE",
          getSnapInsets = function()
            return GetUnitFrameAuraSnapInsets(unitKey, owner)
          end,
        }
      end

      return nil
    end,
    overlayInsets = function(unitKey, owner)
      return GetUnitFrameAuraSnapInsets(unitKey, owner)
    end,
    liveFrame = function(unitKey, owner)
      if unitKey == "boss1" then
        return BossHeader
      end

      return owner.frames and owner.frames[unitKey]
    end,
    getSize = function(unitKey, owner)
      local cfg = owner:ResolveUnitConfig(unitKey)
      if not cfg or cfg.enabled == false then
        return nil, nil
      end

      if unitKey == "boss1" then
        local width, height = GetBossHeaderSize()
        return Round(width), Round(height)
      end

      return UFStyle.ResolveFrameSize(cfg)
    end,
    getPoint = function(unitKey, owner)
      local cfg = owner:ResolveUnitConfig(unitKey)
      if not cfg then
        return nil
      end

      local frame = owner.frames and owner.frames[unitKey]
      local relTo = ResolveSingleUnitHolderParent(cfg, frame, unitKey)
      return cfg.point or "CENTER", relTo, cfg.relativePoint or cfg.point or "CENTER", Round(cfg.x or 0), Round(cfg.y or 0)
    end,
    shouldShow = function(unitKey, owner)
      local db = owner.db and owner.db.profile
      local cfg = owner:ResolveUnitConfig(unitKey)
      return db
        and db.enabled ~= false
        and cfg
        and cfg.enabled ~= false
        and ns.Flags.IsEditing == true
    end,
    onGhostSavePosition = SavePosition,
    onGhostResetPosition = function(unitKey, owner)
      local cfg = owner.db
        and owner.db.profile
        and owner.db.profile.units
        and owner.db.profile.units[unitKey]
      local defaults = owner:GetDefaultUnitConfig(unitKey)
      if not cfg or not defaults then
        return
      end

      cfg.point = defaults.point
      cfg.relativeTo = defaults.relativeTo
      cfg.relativePoint = defaults.relativePoint
      cfg.x = defaults.x
      cfg.y = defaults.y

      if unitKey == "boss1" then
        ConfigureBossHeader()
        owner:RefreshSingleUnit("boss", "layout")
      else
        owner:RefreshSingleUnit(unitKey, "layout")
      end

      FrameUtil:RefreshGhostMover("UF_" .. unitKey)
    end,
    onGhostDragStop = function()
      if ns.TestMode:IsActive() then
        ns.TestMode:Refresh("unitframes", "mover", "uf.singleSettings")
      end
    end,
  })
end

function UF:SetMoversVisible(show)
  if show then
    self:EnsureMovers()
  end

  FrameUtil.SetGhostMoversVisible(self, show, {
    isEnabled = function(owner)
      return owner and owner.db and owner.db.profile and owner.db.profile.enabled ~= false
    end,
  })
end

function UF:RefreshSingleUnit(unit, mode)
  if InCombatLockdown() then
    QueueDeferredRefresh(self, {
      unit = unit,
      mode = mode or "resize",
    })
    return
  end

  local db = self.db.profile
  mode = mode or "resize"

  if db.enabled == false then
    if unit == "boss" then
      for index = 1, 5 do
        self:HideSingleUnitFrame("boss" .. index)
      end
    else
      self:HideSingleUnitFrame(unit)
    end

    if unit == "player" and self.__puiPRDReplacementRefresh ~= true then
      PRD:RefreshPlayerHealthReplacement()
    end
    return
  end

  if mode == "all" or mode == "appearance" then
    UFStyle.ResolveMedia(self)
  end

  local function RefreshUnit(unitToken)
    local cfg = self:ResolveUnitConfig(unitToken, db)
    local frame = self.frames and self.frames[unitToken]

    if not cfg or cfg.enabled == false then
      self:HideSingleUnitFrame(unitToken)

      if db.hideBlizzard == true then
        DisableBlizzardUnit(unitToken)
      end

      return
    end

    if not frame or mode == "all" or mode == "spawns" then
      self:SpawnUnit(unitToken)
      return
    end

    self:RefreshUnitFrame(frame, unitToken, cfg, {
      db = db,
      singleUnit = true,
    }, mode)
  end

  if unit == "boss" then
    for index = 1, 5 do
      RefreshUnit("boss" .. index)
    end

    FrameUtil:RefreshGhostMover("UF_boss1")
    FrameUtil.RefreshSmartSnapState("UF_boss1")
    return
  end

  RefreshUnit(unit)

  if unit == "player" then
    FrameUtil:RefreshGhostMover("UF_player")
    FrameUtil.RefreshSmartSnapState("UF_player")

    if self.__puiPRDReplacementRefresh ~= true then
      PRD:RefreshPlayerHealthReplacement()
    end
  elseif unit == "target" or unit == "focus" then
    FrameUtil:RefreshGhostMover("UF_" .. unit)
    FrameUtil.RefreshSmartSnapState("UF_" .. unit)
  end
end

function UF:RefreshPlayerPRDReplacement()
  if not self.db or not self.db.profile then
    return
  end

  if InCombatLockdown() then
    QueueDeferredRefresh(self, {
      unit = "player",
      mode = "resize",
    })
    return
  end

  self.__puiPRDReplacementRefresh = true
  self:RefreshSingleUnit("player", "resize")
  self.__puiPRDReplacementRefresh = nil
  self:EnsureMovers()
end

function UF:SafeRefresh(mode)
  local flags = type(mode) == "table" and mode or nil
  if flags then
    if flags.mode then
      mode = flags.mode
    elseif flags.resize then
      mode = "resize"
    elseif flags.layout then
      mode = "layout"
    elseif flags.appearance then
      mode = "appearance"
    elseif flags.visibility then
      mode = "visibility"
    elseif flags.data then
      mode = "data"
    elseif flags.text then
      mode = "text"
    elseif flags.range then
      mode = "range"
    else
      mode = "all"
    end
  end

  if InCombatLockdown() then
    QueueDeferredRefresh(self, flags or mode or "all")
    return
  end

  local db = self.db.profile
  mode = mode or "all"
  local completesInitialRefresh = mode == "all" and (not flags or not flags.unit)

  if flags and flags.unit then
    self:RefreshSingleUnit(flags.unit, mode)
    return
  end

  if db.enabled == false then
    self:IterateSingleFrames(function(frame)
      self:DisableFrameRuntime(frame)
    end)
    PRD:RefreshPlayerHealthReplacement()
    if completesInitialRefresh then
      self._initialRefreshComplete = true
    end
    return
  end

  if mode == "text" then
    self._fontRev = (self._fontRev or 0) + 1
    self:IterateSingleFrames(function(frame)
      UFText.RefreshTextForFrame(frame, self._fontRev)
    end)
  elseif mode == "range" then
    Range.RefreshRangeOwnerConfig(self, db.range)
  else
    for index = 1, #SINGLE_UNITS do
      self:RefreshSingleUnit(SINGLE_UNITS[index], mode)
    end
  end

  if mode == "visibility" or mode == "all" then
    self:EnsureMovers()
  end

  if mode == "data" or mode == "all" then
    self:RefreshNameTags()
  end

  if completesInitialRefresh then
    self._initialRefreshComplete = true
  end
end



function UF.AfterStyleCallback(frame)
  frame.__puiUF_oUFInitialized = true

  if frame.__puiGroupKind == "party" then
    if frame.childType ~= "pet" then
      ns.Modules.PartyFrames:Update_PartyFrames(frame)
    end
  elseif frame.__puiGroupKind == "raid" then
    if frame.__puiIsRaidSpotlight == true then
      ns.Modules.RaidFrames:Update_SpotlightFrames(frame)
    else
      ns.Modules.RaidFrames:Update_RaidFrames(frame)
    end
  end
end

function UF:PLAYER_ENTERING_WORLD()
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")

  if self._initialRefreshComplete == true then
    return
  end

  self.__puiDeferredRefresh = nil
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  self:SafeRefresh("all")
end

function UF:PLAYER_REGEN_ENABLED()
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")

  FlushDeferredRefreshes(
    self,
    function(mode)
      self:SafeRefresh(mode)
    end,
    function(unit, mode)
      self:RefreshSingleUnit(unit, mode)
    end
  )
end

function UF:OnInitialize()
  self.db = Addon.db:RegisterNamespace("UnitFrames", {
    profile = CopyTable(UFDefaults.Profile),
  })

  self.frames = self.frames or {}
  self.units = self.units or {}
  self.headers = self.headers or {}

  self:EnsureConfigDefaults(self.db.profile)
  UFStyle.ResolveMedia(self)

  if not self.__puiInitCallbackRegistered then
    self.__puiInitCallbackRegistered = true
    oUF:RegisterInitCallback(UF.AfterStyleCallback)
  end

  UFTags.RegisterOUFTags()
end

function UF:OnEnable()
  self.__puiRuntimeAvailable = true

  if self._initialRefreshComplete ~= true then
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
  end

  oUF:Factory(function()
    self:RegisterSingleStyle()
    self:SafeRefresh("all")
  end)

  self.__puiLastFrameScale = ns.FrameScale:BestOnePixel()

  if not self.__puiFrameScaleListener then
    self.__puiFrameScaleListener = function(_, scale)
      if self.__puiLastFrameScale == scale then
        return
      end

      self.__puiLastFrameScale = scale
      self:SafeRefresh("all")

      local party = ns.Modules.PartyFrames
      if party.db then
        party:SafeRefresh("all")
      end

      local raid = ns.Modules.RaidFrames
      if raid.db then
        raid:SafeRefresh("all")
      end
    end
  end

  ns.FrameScale:RegisterScaleListener(self.__puiFrameScaleListener)
  UFTags.RegisterNicknameCallback()
  UFTags.RefreshNicknames()
  PRD:RefreshPlayerHealthReplacement()
end

function UF:OnDisable()
  self.__puiRuntimeAvailable = nil
  UFTags.UnregisterNicknameCallback()

  if self.__puiFrameScaleListener then
    ns.FrameScale:UnregisterScaleListener(self.__puiFrameScaleListener)
  end

  self:UnregisterAllEvents()
  self.__puiDeferredRefresh = nil
  self.__puiLastFrameScale = nil

  self:IterateSingleFrames(function(frame)
    self:DisableFrameRuntime(frame)
  end)

  PRD:RefreshPlayerHealthReplacement()
end

function UF:OnProfileChanged()
  self:EnsureConfigDefaults(self.db.profile)
  self:SafeRefresh("all")
  UFTags.RefreshNicknames()
end

function UF:ApplySettings(flags)
  if flags and flags.profile then
    self:OnProfileChanged()
  end
end

function UF:SoftRebuild(flags)
  if flags and (flags.profile or flags.layout or flags.movers) then
    self:OnProfileChanged()
  end
end

local P = select(1, ns.Pleebug:DropIn(UF, { name = "UnitFrames.Core" }))


  UF.EnsureConfigDefaults = P:Def("UF.EnsureConfigDefaults", UF.EnsureConfigDefaults)
  UF.GetConfigUnit = P:Def("UF.GetConfigUnit", UF.GetConfigUnit)
  UF.GetDefaultUnitConfig = P:Def("UF.GetDefaultUnitConfig", UF.GetDefaultUnitConfig)
  UF.GetBaseTextSizesForUnit = P:Def("UF.GetBaseTextSizesForUnit", UF.GetBaseTextSizesForUnit)
  UF.ResolveUnitConfig = P:Def("UF.ResolveUnitConfig", UF.ResolveUnitConfig)
  UF.GetTestFrameConfig = P:Def("UF.GetTestFrameConfig", UF.GetTestFrameConfig)
  UF.LayoutTestFrame = P:Def("UF.LayoutTestFrame", UF.LayoutTestFrame)
  UF.RefreshFrameColors = P:Def("UF.RefreshFrameColors", UF.RefreshFrameColors)
  UF.RefreshFramePowerLayout = P:Def("UF.RefreshFramePowerLayout", UF.RefreshFramePowerLayout)
  UF.ConstructUnitFrame = P:Def("UF.ConstructUnitFrame", UF.ConstructUnitFrame)
  UF.PrepareFrameState = P:Def("UF.PrepareFrameState", UF.PrepareFrameState)
  UF.ApplyFrameAppearance = P:Def("UF.ApplyFrameAppearance", UF.ApplyFrameAppearance)
  UF.ApplyFrameLayout = P:Def("UF.ApplyFrameLayout", UF.ApplyFrameLayout)
  UF.ApplyFrameIndicators = P:Def("UF.ApplyFrameIndicators", UF.ApplyFrameIndicators)
  UF.ApplyFramePosition = P:Def("UF.ApplyFramePosition", UF.ApplyFramePosition)
  UF.ApplyFrameVisibilityAndRange = P:Def("UF.ApplyFrameVisibilityAndRange", UF.ApplyFrameVisibilityAndRange)
  UF.SuspendFrameElements = P:Def("UF.SuspendFrameElements", UF.SuspendFrameElements)
  UF.RestoreFrameElements = P:Def("UF.RestoreFrameElements", UF.RestoreFrameElements)
  UF.ForceUnitData = P:Def("UF.ForceUnitData", UF.ForceUnitData)
  UF.RefreshUnitFrame = P:Def("UF.RefreshUnitFrame", UF.RefreshUnitFrame)
  UF.DisableFrameRuntime = P:Def("UF.DisableFrameRuntime", UF.DisableFrameRuntime)
  UF.RegisterSingleStyle = P:Def("UF.RegisterSingleStyle", UF.RegisterSingleStyle)
  UF.SpawnUnit = P:Def("UF.SpawnUnit", UF.SpawnUnit)
  UF.HideSingleUnitFrame = P:Def("UF.HideSingleUnitFrame", UF.HideSingleUnitFrame)
  UF.LoadSingleUnits = P:Def("UF.LoadSingleUnits", UF.LoadSingleUnits)
  UF.IterateSingleFrames = P:Def("UF.IterateSingleFrames", UF.IterateSingleFrames)
  UF.IterateHeaderChildren = P:Def("UF.IterateHeaderChildren", UF.IterateHeaderChildren)
  UF.RefreshNameTags = P:Def("UF.RefreshNameTags", UF.RefreshNameTags)
  UF.RefreshMouseoverSettings = P:Def("UF.RefreshMouseoverSettings", UF.RefreshMouseoverSettings)
  UF.RefreshAuraDisplay = P:Def("UF.RefreshAuraDisplay", UF.RefreshAuraDisplay)
  UF.EnsureMovers = P:Def("UF.EnsureMovers", UF.EnsureMovers)
  UF.SetMoversVisible = P:Def("UF.SetMoversVisible", UF.SetMoversVisible)
  UF.RefreshSingleUnit = P:Def("UF.RefreshSingleUnit", UF.RefreshSingleUnit)
  UF.RefreshPlayerPRDReplacement = P:Def("UF.RefreshPlayerPRDReplacement", UF.RefreshPlayerPRDReplacement)
  UF.SafeRefresh = P:Def("UF.SafeRefresh", UF.SafeRefresh)
  UF.AfterStyleCallback = P:Def("UF.AfterStyleCallback", UF.AfterStyleCallback)
  UF.PLAYER_ENTERING_WORLD = P:Def("UF.PLAYER_ENTERING_WORLD", UF.PLAYER_ENTERING_WORLD)
  UF.PLAYER_REGEN_ENABLED = P:Def("UF.PLAYER_REGEN_ENABLED", UF.PLAYER_REGEN_ENABLED)
  UF.OnInitialize = P:Def("UF.OnInitialize", UF.OnInitialize)
  UF.OnEnable = P:Def("UF.OnEnable", UF.OnEnable)
  UF.OnDisable = P:Def("UF.OnDisable", UF.OnDisable)
  UF.OnProfileChanged = P:Def("UF.OnProfileChanged", UF.OnProfileChanged)
  UF.ApplySettings = P:Def("UF.ApplySettings", UF.ApplySettings)
  UF.SoftRebuild = P:Def("UF.SoftRebuild", UF.SoftRebuild)
  ResolveDeferredRefreshRequest = P:Def("ResolveDeferredRefreshRequest", ResolveDeferredRefreshRequest)
  AddDeferredMode = P:Def("AddDeferredMode", AddDeferredMode)
  QueueDeferredRefresh = P:Def("QueueDeferredRefresh", QueueDeferredRefresh)
  RunDeferredModes = P:Def("RunDeferredModes", RunDeferredModes)
  FlushDeferredRefreshes = P:Def("FlushDeferredRefreshes", FlushDeferredRefreshes)
  UF.QueueDeferredRefresh = QueueDeferredRefresh
  UF.FlushDeferredRefreshes = FlushDeferredRefreshes
  CopyTable = P:Def("CopyTable", CopyTable)
  MergeMissing = P:Def("MergeMissing", MergeMissing)
  ResolveRelativeToObject = P:Def("ResolveRelativeToObject", ResolveRelativeToObject)
  GetSingleUnitHolderName = P:Def("GetSingleUnitHolderName", GetSingleUnitHolderName)
  GetSingleUnitHolder = P:Def("GetSingleUnitHolder", GetSingleUnitHolder)
  IsBossUnit = P:Def("IsBossUnit", IsBossUnit)
  GetBossIndex = P:Def("GetBossIndex", GetBossIndex)
  GetBossGrowthDirection = P:Def("GetBossGrowthDirection", GetBossGrowthDirection)
  GetBossHeaderSize = P:Def("GetBossHeaderSize", GetBossHeaderSize)
  ConfigureBossHeader = P:Def("ConfigureBossHeader", ConfigureBossHeader)
  GetAnchorCoordinate = P:Def("GetAnchorCoordinate", GetAnchorCoordinate)
  GetAnchoredIconBounds = P:Def("GetAnchoredIconBounds", GetAnchoredIconBounds)
  GetAuraDisplayBounds = P:Def("GetAuraDisplayBounds", GetAuraDisplayBounds)
  GetUnitFrameAuraSnapInsets = P:Def("GetUnitFrameAuraSnapInsets", GetUnitFrameAuraSnapInsets)
  PositionBossHolder = P:Def("PositionBossHolder", PositionBossHolder)
  ResolveSingleUnitHolderParent = P:Def("ResolveSingleUnitHolderParent", ResolveSingleUnitHolderParent)
  EnsureSingleUnitPositionHolder = P:Def("EnsureSingleUnitPositionHolder", EnsureSingleUnitPositionHolder)
  ApplySingleUnitFlags = P:Def("ApplySingleUnitFlags", ApplySingleUnitFlags)
  DisableBlizzardUnit = P:Def("DisableBlizzardUnit", DisableBlizzardUnit)
  GetUnitFrameOptionsTab = P:Def("GetUnitFrameOptionsTab", GetUnitFrameOptionsTab)
  RefreshAuraSnapMovers = P:Def("RefreshAuraSnapMovers", RefreshAuraSnapMovers)

_G.PleebUIAPI:RegisterPlugin("PleebUI_UnitFrames", {
  name = "Unit Frames",
}):RegisterEditModeParticipant("singleUnits", {
  order = 100,
  onChanged = function(enable)
    UF:SetMoversVisible(enable)
  end,
})
