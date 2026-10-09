local _, ns = ...

local Addon = ns.Addon
local BuffBars = Addon:NewModule("PCM_BuffBars")
ns.Modules.PCM_BuffBars = BuffBars

local VIEWER_KEY = "BuffBarCooldownViewer"
local Round = ns.Pixel.Round

function BuffBars.GetLayoutGeometry(bb)
  local vertical = bb and bb.orientation == "VERTICAL"
  local length = tonumber(bb and bb.width) or 250
  local thickness = tonumber(bb and bb.height) or 20
  length = Round(math.max(120, math.min(500, length)))
  thickness = Round(math.max(8, math.min(40, thickness)))
  local iconPlacement = bb and bb.iconPlacement or (vertical and "TOP" or "LEFT")
  local showIcon = iconPlacement ~= "HIDE"
  local iconSize = showIcon and thickness or 0
  local barLength = showIcon and math.max(1, length - iconSize) or length
  local barWidth = vertical and thickness or barLength
  local barHeight = vertical and barLength or thickness
  local rowWidth = vertical and thickness or length
  local rowHeight = vertical and length or thickness
  return vertical, length, thickness, iconPlacement, showIcon, iconSize, barWidth, barHeight, rowWidth, rowHeight
end

local function GetClassColor()
  local _, class = UnitClass("player")
  local color = RAID_CLASS_COLORS[class]
  return { color.r, color.g, color.b, 1 }
end

local function GetStyle()
  local owner = ns.Modules.CooldownManager
  local root = ns.PCM_DBExports.GetStyleDB()
  local bb = root.buffBar
  local color = root.buffBarUseClassColor ~= false
    and GetClassColor()
    or root.buffBarColor or { 1, 0.6, 0, 1 }

  return {
    width = bb.width,
    height = bb.height,
    rowSpacing = bb.rowSpacing,
    orientation = bb.orientation,
    layoutMode = bb.layoutMode,
    growthDirection = bb.growthDirection,
    drainDirection = bb.drainDirection,
    texture = bb.texture,
    iconPlacement = bb.iconPlacement,
    borderThickness = bb.borderThickness,
    borderColor = bb.borderColor,
    backgroundColor = root.buffBarBgColor or { 0.12, 0.12, 0.12, 0.95 },
    color = color,
    showName = bb.showName == true,
    nameFont = owner._ResolveFontOpts("cooldown", VIEWER_KEY),
    durationFont = owner._ResolveFontOpts("cooldown", VIEWER_KEY),
    applicationFont = owner._ResolveFontOpts("charge", VIEWER_KEY),
    counts = ns.PCM_DBExports.GetViewerCountDB(VIEWER_KEY),
    tooltips = owner:GetViewerTooltipsEnabled(VIEWER_KEY),
    hideWhenInactive = owner:GetViewerHideWhenInactive(VIEWER_KEY),
  }
end

local function GrowthAnchor(style)
  if style.orientation == "VERTICAL" then
    return style.growthDirection == "LEFT" and "TOPRIGHT" or "TOPLEFT"
  end
  return style.growthDirection == "UP" and "BOTTOMLEFT" or "TOPLEFT"
end

local function ApplyAnchor(frame)
  local bb = ns.PCM_DBExports.GetStyleDB().buffBar
  local pos = bb.pos
  if type(pos) ~= "table" or not pos.point then
    pos = {
      point = "CENTER",
      rel = "UIParent",
      relPoint = "CENTER",
      x = 0,
      y = -110,
    }
    bb.pos = pos
  end
  local relative = _G[pos.rel or "UIParent"] or UIParent
  frame:ClearAllPoints()
  frame:SetPoint(
    pos.point,
    relative,
    pos.relPoint or pos.point,
    Round(tonumber(pos.x) or 0),
    Round(tonumber(pos.y) or 0)
  )

  if bb.layoutMode ~= "GROW" then
    return
  end

  local point = GrowthAnchor(bb)
  if pos.point ~= point then
    local x, y = ns.FrameUtil.GetPointOffsetsForFrame(frame, point)
    pos = {
      point = point,
      rel = "UIParent",
      relPoint = point,
      x = Round(x or 0),
      y = Round(y or 0),
    }
    bb.pos = pos
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, pos.x, pos.y)
  end
end

local function SavePosition(frame)
  local bb = ns.PCM_DBExports.GetStyleDB().buffBar
  local point = bb.layoutMode == "GROW"
    and GrowthAnchor(bb) or (bb.pos and bb.pos.point or "CENTER")
  local x, y = ns.FrameUtil.GetPointOffsetsForFrame(frame, point)
  bb.pos = {
    point = point,
    rel = "UIParent",
    relPoint = point,
    x = Round(x or 0),
    y = Round(y or 0),
  }
  ApplyAnchor(frame)
end

local function RegisterMover(frame)
  ns.FrameUtil:RegisterMover(VIEWER_KEY, frame, {
    label = "Tracked Buff Bars",
    optionsString = "CooldownManager,buff-bars",
    smartSnap = {
      family = "combatBars",
      syncAxis = "NONE",
      isRuntimeActive = function()
        return ns.PCMAuraRuntime:IsReady()
      end,
    },
    savePosition = function()
      SavePosition(frame)
    end,
    onDragStop = function()
      SavePosition(frame)
      ns.PCMAuraRuntime:RefreshLayout(VIEWER_KEY)
    end,
    resetPosition = function()
      ns.PCM_DBExports.GetStyleDB().buffBar.pos = {
        point = "CENTER",
        rel = "UIParent",
        relPoint = "CENTER",
        x = 0,
        y = -110,
      }
      ApplyAnchor(frame)
    end,
    quickSettings = function()
      local bb = ns.PCM_DBExports.GetStyleDB().buffBar
      local vertical = bb.orientation == "VERTICAL"
      local controls = {
        {
          type = "select",
          label = "Bar layout",
          values = { FIXED = "Fixed positions", GROW = "Grow active bars" },
          sorting = { "FIXED", "GROW" },
          get = function() return bb.layoutMode end,
          set = function(value)
            bb.layoutMode = value
            BuffBars:RefreshSettings()
          end,
        },
      }
      if bb.layoutMode == "GROW" then
        controls[#controls + 1] = {
          type = "select",
          label = "Grow from",
          values = vertical
            and { RIGHT = "Left", LEFT = "Right" }
            or { DOWN = "Top", UP = "Bottom" },
          sorting = vertical and { "RIGHT", "LEFT" } or { "DOWN", "UP" },
          get = function() return bb.growthDirection end,
          set = function(value)
            bb.growthDirection = value
            BuffBars:RefreshSettings()
          end,
        }
      end
      return {
        ownerKey = VIEWER_KEY,
        title = "Tracked Buff Bars",
        controls = controls,
      }
    end,
  })
end

function BuffBars:RefreshSettings()
  local runtime = ns.PCMAuraRuntime
  local frame = runtime:InitializeViewer(VIEWER_KEY, UIParent)
  ApplyAnchor(frame)
  RegisterMover(frame)
  runtime:SetViewerStyle(VIEWER_KEY, GetStyle())
end

function BuffBars:ApplySettings(flags)
  if flags == nil
    or flags.profile == true
    or flags.layout == true
    or flags.movers == true
    or flags.fonts == true
    or flags.theme == true
  then
    self:RefreshSettings()
  end
end

function BuffBars:OnInitialize()
  self:SetEnabledState(ns.PCM_DBExports.IsPCMEnabled() == true)
end

function BuffBars:OnEnable()
  self:RefreshSettings()
end

function BuffBars:OnDisable()
end

local P = select(1, ns.Pleebug:DropIn(BuffBars, { name = "PCM", bucket = "BuffBarViewer" }))
BuffBars.GetLayoutGeometry = P:Def("BuffBars.GetLayoutGeometry", BuffBars.GetLayoutGeometry)
BuffBars.RefreshSettings = P:Def("BuffBars:RefreshSettings", BuffBars.RefreshSettings)
BuffBars.ApplySettings = P:Def("BuffBars:ApplySettings", BuffBars.ApplySettings)
BuffBars.OnInitialize = P:Def("BuffBars:OnInitialize", BuffBars.OnInitialize)
BuffBars.OnEnable = P:Def("BuffBars:OnEnable", BuffBars.OnEnable)
BuffBars.OnDisable = P:Def("BuffBars:OnDisable", BuffBars.OnDisable)
