-- File: PUI_FrameUtil.lua

local ns = select(2, ...)

local Addon = ns.Addon

local _G = _G
local UIParent = _G.UIParent
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local IsControlKeyDown = _G.IsControlKeyDown
local IsShiftKeyDown = _G.IsShiftKeyDown
local type = _G.type
local tonumber = _G.tonumber
local tostring = _G.tostring
local pairs = _G.pairs
local ipairs = _G.ipairs
local next = _G.next
local wipe = _G.wipe
local math_abs = _G.math.abs
local math_min = _G.math.min
local math_max = _G.math.max
local math_floor = _G.math.floor

local Pixel = ns.Pixel
local Round = Pixel.Round
local LSM = ns.LSM

ns.FrameUtil = ns.FrameUtil or {}
local FrameUtil = ns.FrameUtil

local MoversByKey = {}
local MoversByFrame = _G.setmetatable({}, { __mode = "k" })
local MoversList = {}
local MoverLayerOrder = {}
local moverLayeringPending
local GhostFrameState = _G.setmetatable({}, { __mode = "k" })

local ShowOverlay
local EnableDrag
local GhostMoverHelpers

FrameUtil._dimAlpha = FrameUtil._dimAlpha or 0.7
FrameUtil._disableDimming = FrameUtil._disableDimming or false

local NUDGE_MIN, NUDGE_MAX, NUDGE_DEFAULT = 1, 10, 1

local SelectedEntry
local SelectedEntries = {}

FrameUtil._nudgeStep           = FrameUtil._nudgeStep or NUDGE_DEFAULT
FrameUtil._nudgeXInput         = FrameUtil._nudgeXInput or nil
FrameUtil._nudgeYInput         = FrameUtil._nudgeYInput or nil
FrameUtil._keyboardMoveEnabled = FrameUtil._keyboardMoveEnabled or false

function FrameUtil._GetEditModeDB()
  Addon.db.profile.EditMode = Addon.db.profile.EditMode or {}
  return Addon.db.profile.EditMode
end

local VISIBILITY_SET_NAMES = { "Custom", "Solo", "Party", "Raid" }
local moverVisibilityDB

function FrameUtil.GetMoverVisibilityConfig()
  local db = FrameUtil._GetEditModeDB()
  if moverVisibilityDB == db.moverVisibility and moverVisibilityDB then
    return moverVisibilityDB
  end
  db.moverVisibility = db.moverVisibility or {}
  local config = db.moverVisibility
  config.sets = config.sets or {}
  config.expanded = config.expanded or {}

  for _, name in ipairs(VISIBILITY_SET_NAMES) do
    local set = config.sets[name]
    if not set then
      set = {}
      config.sets[name] = set
    end
    set.modules = set.modules or {}
    set.groups = set.groups or {}
    set.movers = set.movers or {}
  end

  if not config.sets[config.selectedSet] then
    config.selectedSet = "Custom"
  end

  moverVisibilityDB = config
  return config
end

function FrameUtil.GetMoverVisibilitySetNames()
  return VISIBILITY_SET_NAMES
end

function FrameUtil.GetRegisteredMoverEntries()
  local entries = {}
  for _, entry in ipairs(MoversList) do
    entries[#entries + 1] = entry
  end
  return entries
end

function FrameUtil.GetMoverVisibilityChoice(entry, setName)
  local config = FrameUtil.GetMoverVisibilityConfig()
  local set = config.sets[setName or config.selectedSet]
  local selected = set.movers[entry.key]
  if selected ~= nil then
    return selected == true
  end

  local defaults = entry.opts.defaultVisibility
  return not (defaults and defaults[setName or config.selectedSet] == false)
end

function FrameUtil.IsMoverAvailable(entry)
  local available = entry.opts.isAvailable
  return type(available) ~= "function" or available(entry.frame, entry.key) ~= false
end

function FrameUtil.IsMoverPreviewVisible(key)
  if not ns.Flags.IsEditing then
    return true
  end

  local entry = MoversByKey[key]
  if not entry then
    return true
  end
  if entry._editSessionHidden then
    return false
  end
  return FrameUtil.IsMoverVisibleInPreset(entry)
end

function FrameUtil.IsMoverVisibleInPreset(entry)
  if not FrameUtil.IsMoverAvailable(entry) then
    return false
  end
  local config = FrameUtil.GetMoverVisibilityConfig()
  local set = config.sets[config.selectedSet]
  local opts = entry.opts

  if set.modules[opts.moduleKey] == false then
    return false
  end

  if opts.groupKey and set.groups[opts.moduleKey .. ":" .. opts.groupKey] == false then
    return false
  end

  return FrameUtil.GetMoverVisibilityChoice(entry, config.selectedSet)
end

function FrameUtil.GetMoverVisibilityNodeChoice(kind, key)
  local config = FrameUtil.GetMoverVisibilityConfig()
  local set = config.sets[config.selectedSet]
  return set[kind][key] ~= false
end

function FrameUtil.SelectMoverVisibilitySet(name)
  local config = FrameUtil.GetMoverVisibilityConfig()
  config.selectedSet = name
  FrameUtil.ApplyMoverVisibilityPreset()
end

function FrameUtil.SetMoverVisibilityNode(kind, key, visible)
  local history = FrameUtil.BeginEditHistory("Mover visibility")
  local config = FrameUtil.GetMoverVisibilityConfig()
  local set = config.sets[config.selectedSet]
  set[kind][key] = visible == true
  FrameUtil.ApplyMoverVisibilityPreset()
  FrameUtil.CommitEditHistory(history)
end

function FrameUtil.ResetMoverVisibilitySet()
  local history = FrameUtil.BeginEditHistory("Reset preset")
  local config = FrameUtil.GetMoverVisibilityConfig()
  config.sets[config.selectedSet] = { modules = {}, groups = {}, movers = {} }
  FrameUtil.ApplyMoverVisibilityPreset()
  FrameUtil.CommitEditHistory(history)
end

function FrameUtil.SelectGroupMoverVisibilitySet()
  local config = FrameUtil.GetMoverVisibilityConfig()
  if config.followGroup ~= true then
    return
  end
  if _G.IsInRaid() then
    config.selectedSet = "Raid"
  elseif _G.IsInGroup() then
    config.selectedSet = "Party"
  else
    config.selectedSet = "Solo"
  end
end

function FrameUtil._InitEditModeConfig()
  local db = FrameUtil._GetEditModeDB()
  if FrameUtil._editModeConfigDB == db then
    return
  end
  FrameUtil._editModeConfigDB = db

  FrameUtil._keyboardMoveEnabled = db.keyboardMoveEnabled == true
  FrameUtil._snapToGrid = db.snapToGrid == true
  FrameUtil._snapToFrame = db.snapToFrame == true
  FrameUtil._smartSnapEnabled = db.smartSnapEnabled ~= false
  FrameUtil._snapTolerance = db.snapTolerance or 8
  FrameUtil._nudgeStep = db.nudgeStep or NUDGE_DEFAULT
  FrameUtil._gridSize = db.gridSize or 16
  FrameUtil._showGrid = db.showGrid == true
  FrameUtil._dimAlpha = db.dimAlpha or 0.7
  FrameUtil._disableDimming = db.disableDimming == true
  FrameUtil._compactMovers = db.compactMovers == true
end

function FrameUtil.ApplyGlobalEditFont(fs, sizeOverride, flagsOverride)
  if not fs then
    return
  end

  local fontPath, size, flags = fs:GetFont()
  local globalFontKey, globalFlags = ns.Theme.GetIconTextGlobal()

  size = sizeOverride or size or 14
  flags = flagsOverride or flags or "OUTLINE"

  if globalFlags and globalFlags ~= "" then
    flags = globalFlags
  end

  local fetched = LSM:Fetch(LSM.MediaType.FONT, globalFontKey, true)
  if fetched then
    fontPath = fetched
  end

  if fontPath then
    fs:SetFont(fontPath, size, flags)
  end
end


local function GetRawOffsetsForFrame(frame)
  local cx, cy = frame:GetCenter()
  if not cx or not cy then
    return 0, 0
  end

  local ux, uy = UIParent:GetCenter()
  return cx - ux, cy - uy
end

local function GetOffsetsForFrame(frame)
  local x, y = GetRawOffsetsForFrame(frame)
  return Round(x), Round(y)
end

local function FinalizeEntryMove(entry)
  if type(entry.savePosition) == "function" then
    entry.savePosition(entry.frame, entry.key)
  end

  if type(entry.onDragStop) == "function" then
    entry.onDragStop(entry.frame, entry.key)
  end

  FrameUtil._OnMoverMoved(entry)
end

local function MoveEntryTo(entry, x, y, silent)
  local frame = entry.frame

  frame:ClearAllPoints()
  -- Preserve half-pixel centers; each mover owner handles its anchor alignment.
  Pixel.DisableSnap(frame)
  frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

  if not silent then
    FinalizeEntryMove(entry)
  end
end

-- Shared mover helpers
local function MoverRound(v)
  return Round(tonumber(v) or 0)
end

local function GetMoverChromeStrata()
  return "HIGH"
end

local function SetEditModeVisualColors(visual, fillAlpha, borderAlpha)
  local selection = ns.Theme.GetColors().selection
  local alpha = selection[4] or 1

  visual:SetBackdropColor(
    selection[1],
    selection[2],
    selection[3],
    alpha * fillAlpha
  )
  visual:SetBackdropBorderColor(
    selection[1],
    selection[2],
    selection[3],
    alpha * borderAlpha
  )
end

local function ApplyHeaderMoverTheme(mover, overlayBelowFrame)
  local selection = ns.Theme.GetColors().selection
  local alpha = selection[4] or 1

  ns.IconSkin.ApplyBorder(mover, {
    enabled = overlayBelowFrame ~= true,
    thickness = 1,
    color = {
      selection[1],
      selection[2],
      selection[3],
      alpha * 0.75,
    },
  })
end

function FrameUtil.RefreshMoverLayering()
  local strata = GetMoverChromeStrata()
  wipe(MoverLayerOrder)
  for _, entry in ipairs(MoversList) do
    local overlay = entry.overlay
    if overlay and overlay:IsShown() then
      local width, height = overlay:GetWidth(), overlay:GetHeight()
      if not _G.issecretvalue(width) and not _G.issecretvalue(height) then
        entry._editOverlayArea = width * height
        MoverLayerOrder[#MoverLayerOrder + 1] = entry
      else
        overlay:SetFrameLevel(1000)
      end
    end
  end
  _G.table.sort(MoverLayerOrder, function(first, second)
    if first._editOverlayArea == second._editOverlayArea then
      return first.key < second.key
    end
    return first._editOverlayArea > second._editOverlayArea
  end)
  local selectedLevel = 1001 + #MoverLayerOrder
  for index, entry in ipairs(MoverLayerOrder) do
    entry.overlay:SetFrameLevel(1000 + index)
  end

  for _, entry in ipairs(MoversList) do
    if entry.overlay then
      entry.overlay:SetFrameStrata(strata)
      if SelectedEntries[entry] then
        entry.overlay:SetFrameLevel(selectedLevel)
      end
    end

    if entry.chrome then
      entry.chrome:SetFrameStrata("HIGH")
      entry.chrome:SetFrameLevel(190)
    end

    if entry.nudgeGroup then
      entry.nudgeGroup:SetFrameStrata(strata)
      entry.nudgeGroup:SetFrameLevel(selectedLevel + 10)
    end

    if entry.frame and entry.frame.__puiEditMoverHelper then
      entry.frame:SetFrameStrata(strata)
    end
  end

  if FrameUtil._selectionSurface then
    FrameUtil._selectionSurface:SetFrameStrata("HIGH")
  end

  if FrameUtil._selectionBox then
    FrameUtil._selectionBox:SetFrameStrata(GetMoverChromeStrata())
    FrameUtil._selectionBox:SetFrameLevel(selectedLevel + 20)
  end
  if FrameUtil._frameSnapFeedback then
    FrameUtil._frameSnapFeedback:SetFrameLevel(selectedLevel + 1)
  end
end


local function QueueMoverLayeringRefresh()
  if not ns.Flags.IsEditing or moverLayeringPending then return end
  moverLayeringPending = true
  _G.C_Timer.After(0, function()
    moverLayeringPending = nil
    if ns.Flags.IsEditing then
      FrameUtil.RefreshMoverLayering()
    else
      wipe(MoverLayerOrder)
    end
  end)
end

function FrameUtil.GetMoverOffsets(frame)
  local x, y = GetOffsetsForFrame(frame)
  return x or 0, y or 0
end

function FrameUtil.SetMoverFrameVisible(frame, show, applyPolicy)
  if not frame then
    return
  end

  show = show and true or false
  if not applyPolicy and frame.__puiEditMoverHelper then
    frame.__puiEditMoverAvailable = show
  end
  local entry = MoversByFrame[frame]
  if show and ns.Flags.IsEditing and entry
    and (entry._presetHidden or entry._editSessionHidden or entry._suppressed)
  then
    show = false
  end

  local useOverlayDrag = frame.__puiUseOverlayDrag == true

  frame:SetShown(show)
  frame:EnableMouse(show and not useOverlayDrag)

  if frame.EnableMouseWheel then
    frame:EnableMouseWheel(show and not useOverlayDrag)
  end

  if show and not useOverlayDrag then
    if frame.RegisterForDrag then
      frame:RegisterForDrag("LeftButton")
    end

    if frame.RegisterForClicks then
      frame:RegisterForClicks("AnyUp")
    end

    if frame.Raise then
      frame:Raise()
    end
  end
end

function FrameUtil.SetMoverFramesVisible(frames, show)
  for _, frame in pairs(frames) do
    FrameUtil.SetMoverFrameVisible(frame, show)
  end
end

function FrameUtil.UpdateLinearHeaderAnchorSize(owner, opts)
  if not owner or not owner.anchor then
    return
  end

  opts = opts or {}

  local count = tonumber(opts.count) or 1
  if count < 1 then
    count = 1
  end

  local width = MoverRound(opts.width or 0)
  local height = MoverRound(opts.height or 0)
  local spacing = MoverRound(opts.spacing or 0)
  local isHorizontal = opts.isHorizontal == true or opts.orientation == "HORIZONTAL"

  local totalWidth = width
  local totalHeight = height

  if isHorizontal then
    totalWidth = (width * count) + (spacing * (count - 1))
  else
    totalHeight = (height * count) + (spacing * (count - 1))
  end

  Pixel.Size(owner.anchor, totalWidth, totalHeight)

  if owner.mover then
    Pixel.Size(owner.mover, totalWidth, totalHeight)
  end
end

function FrameUtil.GetGroupedLayoutDirectionParts(db)
  local dir = db and db.growthDirection or "RIGHT_DOWN"

  local xDir = "RIGHT"
  local yDir = "DOWN"

  if dir == "LEFT_DOWN" then
    xDir = "LEFT"
    yDir = "DOWN"
  elseif dir == "RIGHT_UP" then
    xDir = "RIGHT"
    yDir = "UP"
  elseif dir == "LEFT_UP" then
    xDir = "LEFT"
    yDir = "UP"
  end

  return xDir, yDir
end

function FrameUtil.GetGroupedMoverAnchorPoint(db)
  local xDir, yDir = FrameUtil.GetGroupedLayoutDirectionParts(db)

  if xDir == "LEFT" then
    return (yDir == "UP") and "BOTTOMRIGHT" or "TOPRIGHT"
  end

  return (yDir == "UP") and "BOTTOMLEFT" or "TOPLEFT"
end

function FrameUtil.GetPointOffsetsForFrame(frame, point)
  if not frame or not UIParent then
    return 0, 0
  end

  local parentLeft = UIParent:GetLeft()
  local parentBottom = UIParent:GetBottom()
  local parentWidth = UIParent:GetWidth()
  local parentHeight = UIParent:GetHeight()
  if not parentLeft or not parentBottom or not parentWidth or not parentHeight then
    return 0, 0
  end

  local parentRight = parentLeft + parentWidth
  local parentTop = parentBottom + parentHeight
  local parentCenterX = parentLeft + (parentWidth * 0.5)
  local parentCenterY = parentBottom + (parentHeight * 0.5)
  local left = frame:GetLeft()
  local right = frame:GetRight()
  local top = frame:GetTop()
  local bottom = frame:GetBottom()
  local centerX, centerY = frame:GetCenter()

  if point == "TOP" then
    if not centerX or not top then
      return 0, 0
    end
    return MoverRound(centerX - parentCenterX), MoverRound(top - parentTop)
  elseif point == "TOPRIGHT" then
    if not right or not top then
      return 0, 0
    end
    return MoverRound(right - parentRight), MoverRound(top - parentTop)
  elseif point == "RIGHT" then
    if not right or not centerY then
      return 0, 0
    end
    return MoverRound(right - parentRight), MoverRound(centerY - parentCenterY)
  elseif point == "BOTTOMRIGHT" then
    if not right or not bottom then
      return 0, 0
    end
    return MoverRound(right - parentRight), MoverRound(bottom - parentBottom)
  elseif point == "BOTTOM" then
    if not centerX or not bottom then
      return 0, 0
    end
    return MoverRound(centerX - parentCenterX), MoverRound(bottom - parentBottom)
  elseif point == "BOTTOMLEFT" then
    if not left or not bottom then
      return 0, 0
    end
    return MoverRound(left - parentLeft), MoverRound(bottom - parentBottom)
  elseif point == "LEFT" then
    if not left or not centerY then
      return 0, 0
    end
    return MoverRound(left - parentLeft), MoverRound(centerY - parentCenterY)
  elseif point == "CENTER" then
    if not centerX or not centerY then
      return 0, 0
    end
    return MoverRound(centerX - parentCenterX), MoverRound(centerY - parentCenterY)
  end

  if not left or not top then
    return 0, 0
  end

  return MoverRound(left - parentLeft), MoverRound(top - parentTop)
end

function FrameUtil.EnsureHeaderMover(owner, key, frameName, anchor, db, opts)
  if not owner or not key or not frameName or not anchor or type(db) ~= "table" then
    return nil
  end

  opts = opts or {}

  local function GetDB()
    if type(opts.getDB) == "function" then
      local current = opts.getDB(owner)
      if type(current) == "table" then
        return current
      end
    end

    return db
  end

  local function GetMoverAnchorPoint(current)
    if type(opts.getMoverAnchorPoint) == "function" then
      return opts.getMoverAnchorPoint(owner, current)
    end

    return nil
  end

  local mover = owner.mover
  if not mover then
    mover = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    owner.mover = mover
  end

  local point = db.point or opts.defaultPoint or "CENTER"
  local relativeTo = _G[db.relativeTo or "UIParent"] or UIParent
  local relativePoint = db.relativePoint or opts.defaultRelativePoint or point
  local moverAnchorPoint = GetMoverAnchorPoint(db)
  local anchorPoint = moverAnchorPoint or opts.anchorPoint or point
  local anchorRelativePoint = moverAnchorPoint or opts.anchorRelativePoint or anchorPoint

  local width, height
  if type(opts.getSize) == "function" then
    width, height = opts.getSize(owner, db, anchor)
  end

  if not width or not height then
    width, height = anchor:GetSize()
  end

  mover.__puiEditMoverHelper = true
  mover.__puiHeaderMoverHelper = true
  mover:SetFrameStrata(GetMoverChromeStrata())
  mover:SetFrameLevel(900)
  mover:SetToplevel(true)
  mover:SetClampedToScreen(true)

  if not mover.__pui_bg then
    local t = mover:CreateTexture(nil, "BACKGROUND")
    Pixel.AllPoints(t, mover)
    mover.__pui_bg = t
  end
  Pixel.SetColorTexture(mover.__pui_bg, 0, 0, 0, opts.overlayBelowFrame and 0 or 0.35)

  ApplyHeaderMoverTheme(mover, opts.overlayBelowFrame == true)

  mover:ClearAllPoints()
  Pixel.Point(mover, point, relativeTo, relativePoint, db.x or 0, db.y or 0)
  Pixel.Size(mover, width or 0, height or 0)
  mover.__puiUseOverlayDrag = opts.useOverlayDrag ~= false

  if moverAnchorPoint
    and (
      point ~= moverAnchorPoint
      or relativeTo ~= UIParent
      or relativePoint ~= moverAnchorPoint
    )
  then
    local x, y = FrameUtil.GetPointOffsetsForFrame(mover, moverAnchorPoint)

    db.point = moverAnchorPoint
    db.relativeTo = "UIParent"
    db.relativePoint = moverAnchorPoint
    db.x = MoverRound(x or 0)
    db.y = MoverRound(y or 0)

    mover:ClearAllPoints()
    Pixel.Point(mover, moverAnchorPoint, UIParent, moverAnchorPoint, db.x, db.y)
  end

  local editing = ns.Flags.IsEditing == true
  FrameUtil.SetMoverFrameVisible(mover, editing)

  anchor:ClearAllPoints()
  Pixel.Point(anchor, anchorPoint, mover, anchorRelativePoint, 0, 0)

  local function SavePosition(frame)
    local current = GetDB()
    local currentMoverAnchorPoint = GetMoverAnchorPoint(current)

    if currentMoverAnchorPoint then
      local x, y = FrameUtil.GetPointOffsetsForFrame(frame, currentMoverAnchorPoint)

      current.point = currentMoverAnchorPoint
      current.relativeTo = "UIParent"
      current.relativePoint = currentMoverAnchorPoint
      current.x = MoverRound(x or 0)
      current.y = MoverRound(y or 0)

      frame:ClearAllPoints()
      Pixel.Point(frame, currentMoverAnchorPoint, UIParent, currentMoverAnchorPoint, current.x, current.y)
    else
      local x, y = FrameUtil.GetMoverOffsets(frame)

      current.point = "CENTER"
      current.relativeTo = "UIParent"
      current.relativePoint = "CENTER"
      current.x = MoverRound(x or 0)
      current.y = MoverRound(y or 0)
    end

    if InCombatLockdown() then
      return
    end

    if owner.anchor and owner.mover then
      local currentAnchorPoint = currentMoverAnchorPoint or anchorPoint
      local currentAnchorRelativePoint = currentMoverAnchorPoint or anchorRelativePoint

      owner.anchor:ClearAllPoints()
      Pixel.Point(owner.anchor, currentAnchorPoint, owner.mover, currentAnchorRelativePoint, 0, 0)
    end
  end

  FrameUtil:RegisterMover(key, mover, {
    label = opts.label,
    moduleKey = opts.moduleKey,
    moduleLabel = opts.moduleLabel,
    groupKey = opts.groupKey,
    groupLabel = opts.groupLabel,
    defaultVisibility = opts.defaultVisibility,
    isAvailable = opts.isAvailable,
    onPreviewVisibilityChanged = opts.onPreviewVisibilityChanged,
    snapGroup = opts.snapGroup,
    optionsString = opts.optionsString,
    quickSettings = opts.quickSettings,
    overlayBelowFrame = opts.overlayBelowFrame,
    useOverlayDrag = true,
    smartSnap = opts.smartSnap,
    savePosition = SavePosition,
    resetPosition = type(opts.resetPosition) == "function" and function(frame)
      opts.resetPosition(frame, GetDB(), owner)
    end or nil,
    onDragStop = function(frame)
      if type(opts.onDragStop) == "function" then
        opts.onDragStop(frame, GetDB(), owner)
      end
    end,
  })

  return mover
end

function FrameUtil.EnsureGhostMovers(owner, opts)
  -- Ghosts are addon-owned; initial load must register them before SmartSnap restores its topology.
  if InCombatLockdown() and FrameUtil._smartSnapWorldReady then
    return
  end

  owner.ghosts = owner.ghosts or {}

  for moverKey, label in pairs(opts.labels) do
    owner.ghosts[moverKey] = FrameUtil:EnsureGhostMover(opts.keyPrefix .. tostring(moverKey), {
      frameName = opts.frameNamePrefix .. tostring(moverKey),
      label = label,
      moduleKey = opts.moduleKey,
      moduleLabel = opts.moduleLabel,
      groupKey = opts.groupKey,
      groupLabel = opts.groupLabel,
      defaultVisibility = opts.defaultVisibility,
      useOverlayDrag = opts.useOverlayDrag ~= false,
      optionsString = opts.optionsString(moverKey, owner),
      quickSettings = type(opts.quickSettings) == "function" and function(frame, key, entry)
        return opts.quickSettings(moverKey, owner, frame, key, entry)
      end or nil,
      smartSnap = type(opts.smartSnap) == "function"
        and opts.smartSnap(moverKey, owner)
        or opts.smartSnap,
      overlayInsets = type(opts.overlayInsets) == "function" and function()
        return opts.overlayInsets(moverKey, owner)
      end or opts.overlayInsets,
      overlayBelowFrame = opts.overlayBelowFrame == true,
      liveFrame = function()
        return opts.liveFrame(moverKey, owner)
      end,
      getConfig = type(opts.getConfig) == "function" and function()
        return opts.getConfig(moverKey, owner)
      end or nil,
      getSize = function(_, _, config)
        return opts.getSize(moverKey, owner, config)
      end,
      getPoint = function(_, _, config)
        return opts.getPoint(moverKey, owner, config)
      end,
      shouldShow = function(_, _, config)
        return opts.shouldShow(moverKey, owner, config)
      end,
      savePosition = type(opts.onGhostSavePosition) == "function" and function(mover)
        opts.onGhostSavePosition(moverKey, owner, mover)
      end or nil,
      resetPosition = type(opts.onGhostResetPosition) == "function" and function(mover)
        opts.onGhostResetPosition(moverKey, owner, mover)
      end or nil,
      onDragStop = type(opts.onGhostDragStop) == "function" and function(mover)
        opts.onGhostDragStop(moverKey, owner, mover)
      end or nil,
    })
  end
end

function FrameUtil.SetGhostMoversVisible(owner, show, opts)
  if not owner.ghosts then
    return
  end

  if not opts.isEnabled(owner) then
    show = false
  end

  FrameUtil.SetMoverFramesVisible(owner.ghosts, show and true or false)
  for unitKey in pairs(owner.ghosts) do
    FrameUtil:RefreshGhostMover(opts.keyPrefix .. unitKey)
  end
end

function FrameUtil.SetFrameGhosted(frame, enabled, opts)
  if not frame or (frame.IsForbidden and frame:IsForbidden()) then
    return
  end

  opts = type(opts) == "table" and opts or {}

  local state = GhostFrameState[frame]
  if not state then
    state = {}
    GhostFrameState[frame] = state
  end

  local wasEnabled = state.enabled == true
  state.enabled = enabled and true or false
  state.opts = opts

  local function CaptureState(self)
    state.alpha = self:GetAlpha()
    state.mouseClickEnabled = self:IsMouseClickEnabled()
    state.mouseMotionEnabled = self:IsMouseMotionEnabled()
    state.mouseWheelEnabled = self:IsMouseWheelEnabled()
  end

  local function ApplyGhost(self, activeOpts)
    if not self or (self.IsForbidden and self:IsForbidden()) then
      return
    end

    self:SetMouseClickEnabled(false)
    self:SetMouseMotionEnabled(false)
    self:EnableMouseWheel(false)
    self:SetAlpha(tonumber(activeOpts.alpha) or 0)
  end

  local function ClearGhost(self)
    if not self or (self.IsForbidden and self:IsForbidden()) then
      return
    end

    self:SetAlpha(state.alpha)
    self:SetMouseClickEnabled(state.mouseClickEnabled)
    self:SetMouseMotionEnabled(state.mouseMotionEnabled)
    self:EnableMouseWheel(state.mouseWheelEnabled)
  end

  if state.enabled then
    if not wasEnabled then
      CaptureState(frame)
    end

    ApplyGhost(frame, opts)

    if opts.reapplyOnShow ~= false and not state.hooked then
      state.hooked = true
      frame:HookScript("OnShow", function(self)
        local current = GhostFrameState[self]
        if current and current.enabled then
          ApplyGhost(self, current.opts or {})
        end
      end)
    end
  elseif wasEnabled then
    ClearGhost(frame)
  end
end




local overlayFrame
local overlayFade
local overlayFadeAlpha

local function EnsureDimmer()
  if overlayFrame then
    return overlayFrame
  end

  local frame = CreateFrame("Frame", "PUI_EditModeDimmer", UIParent)
  overlayFrame = frame
  FrameUtil._dimmer = frame
  frame:SetFrameStrata("BACKGROUND")
  frame:SetFrameLevel(0)
  frame:SetAllPoints(UIParent)
  frame:EnableMouse(false)
  frame:SetAlpha(0)
  frame:Hide()

  local texture = frame:CreateTexture(nil, "BACKGROUND")
  texture:SetAllPoints()
  texture:SetColorTexture(0, 0, 0, 1)

  overlayFade = frame:CreateAnimationGroup()
  overlayFadeAlpha = overlayFade:CreateAnimation("Alpha")
  overlayFadeAlpha:SetDuration(0.35)
  overlayFadeAlpha:SetSmoothing("IN_OUT")
  overlayFade:SetScript("OnFinished", function()
    frame:SetAlpha(frame._puiTargetAlpha)
    if frame._puiTargetAlpha == 0 then
      frame:Hide()
    end
  end)
  return frame
end

function FrameUtil._RefreshDimmerAlpha()
  if overlayFrame and overlayFrame:IsShown() then
    if overlayFade:IsPlaying() then
      overlayFade:Stop()
    end
    local alpha = FrameUtil._disableDimming and 0 or (FrameUtil._dimAlpha or 0.7)
    overlayFrame._puiTargetAlpha = alpha
    overlayFrame:SetAlpha(alpha)
    if alpha == 0 then
      overlayFrame:Hide()
    end
  end
end

local function PlayDimmerFade(show)
  local frame = EnsureDimmer()
  local startingAlpha = frame:IsShown() and frame:GetAlpha() or 0
  if overlayFade:IsPlaying() then
    overlayFade:Stop()
  end

  local targetAlpha = show and (FrameUtil._dimAlpha or 0.7) or 0
  frame._puiTargetAlpha = targetAlpha
  if startingAlpha == targetAlpha then
    frame:SetAlpha(targetAlpha)
    frame:SetShown(targetAlpha > 0)
    return
  end

  frame:SetAlpha(startingAlpha)
  frame:Show()
  overlayFadeAlpha:SetFromAlpha(startingAlpha)
  overlayFadeAlpha:SetToAlpha(targetAlpha)
  overlayFade:Play()
end

FrameUtil._gridSize      = FrameUtil._gridSize or 16
FrameUtil._showGrid      = FrameUtil._showGrid or false
FrameUtil._snapToGrid    = FrameUtil._snapToGrid or false
FrameUtil._snapToFrame   = FrameUtil._snapToFrame or false
FrameUtil._snapTolerance = FrameUtil._snapTolerance or 8
FrameUtil._smartSnapEnabled = FrameUtil._smartSnapEnabled ~= false

local GridOverlay
local GridLines = {}

local function ClearGrid()
  if not GridOverlay then return end

  for i = 1, #GridLines do
    GridLines[i]:Hide()
  end
end

local function AcquireGridLine(index)
  local line = GridLines[index]
  if not line then
    line = GridOverlay:CreateTexture(nil, "BACKGROUND")
    GridLines[index] = line
  end

  line:ClearAllPoints()
  line:Show()
  return line
end

local function TrimGridLines(activeCount)
  for i = activeCount + 1, #GridLines do
    GridLines[i]:Hide()
  end
end

local function EnsureGridOverlay()
  if GridOverlay then
    return GridOverlay
  end

  local f = CreateFrame("Frame", "PUI_EditModeGrid", UIParent)
  f:SetAllPoints(UIParent)
  f:SetFrameStrata("FULLSCREEN")
  f:SetFrameLevel(5)
  f:EnableMouse(false)
  f:Hide()
  GridOverlay = f
  return f
end

local function BuildGrid(size)
  local f = EnsureGridOverlay()
  ClearGrid()

  if not size or size <= 0 then
    return
  end
  local w = UIParent:GetWidth()
  local h = UIParent:GetHeight()
  if not w or not h or w <= 0 or h <= 0 then
    return
  end

  local index = 0

  for x = 0, w, size do
    index = index + 1
    local l = AcquireGridLine(index)
    l:SetColorTexture(1, 1, 1, 0.08)
    l:SetPoint("TOPLEFT", f, "TOPLEFT", x, 0)
    l:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", x + 1, -h)
  end

  for y = 0, h, size do
    index = index + 1
    local l = AcquireGridLine(index)
    l:SetColorTexture(1, 1, 1, 0.08)
    l:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
    l:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", w, -(y + 1))
  end

  TrimGridLines(index)
end

function FrameUtil.SetGridSize(size)
  size = tonumber(size)
  if not size or size <= 0 then
    FrameUtil._gridSize = 16
  else
    FrameUtil._gridSize = size
  end

  local db = FrameUtil._GetEditModeDB()
  db.gridSize = FrameUtil._gridSize

  if FrameUtil._showGrid and ns.Flags.IsEditing then
    BuildGrid(FrameUtil._gridSize)
    EnsureGridOverlay():Show()
  end
end

function FrameUtil.ShowGrid(show)
  FrameUtil._showGrid = show and true or false

  local db = FrameUtil._GetEditModeDB()
  db.showGrid = FrameUtil._showGrid

  local f = EnsureGridOverlay()

  if FrameUtil._showGrid and ns.Flags.IsEditing then
    BuildGrid(FrameUtil._gridSize)
    f:Show()
  else
    f:Hide()
  end
end

function FrameUtil.SetSnapTolerance(px)
  px = tonumber(px)
  if not px or px < 1 then
    px = 1
  end
  FrameUtil._snapTolerance = Round(px)

  local db = FrameUtil._GetEditModeDB()
  db.snapTolerance = FrameUtil._snapTolerance
end

local function GetFrameEdges(frame)
  local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
  if _G.issecretvalue(l) or _G.issecretvalue(r) or _G.issecretvalue(t) or _G.issecretvalue(b) then return end
  if not l or not r or not t or not b then return end
  return l, r, t, b
end

local function RoundToNearestGrid(value, size)
  local scaled = value / size
  if scaled >= 0 then
    return MoverRound(math_floor(scaled + 0.5) * size)
  end

  return MoverRound(_G.math.ceil(scaled - 0.5) * size)
end

local function GetGridCornerDelta(cornerX, cornerY, parentLeft, parentTop, maxGridX, maxGridY, size, preserveAxis)
  local gridOffsetX = RoundToNearestGrid(cornerX - parentLeft, size)
  local gridOffsetY = RoundToNearestGrid(parentTop - cornerY, size)

  gridOffsetX = math_max(0, math_min(gridOffsetX, maxGridX))
  gridOffsetY = math_max(0, math_min(gridOffsetY, maxGridY))

  local dx = (parentLeft + gridOffsetX) - cornerX
  local dy = (parentTop - gridOffsetY) - cornerY
  if preserveAxis == "H" then dx = 0 end
  if preserveAxis == "V" then dy = 0 end
  local distance = (dx * dx) + (dy * dy)

  return dx, dy, distance
end

function FrameUtil._ApplyGridSnap(entry, preserveAxis)
  if not entry or not entry.frame then return end
  if not FrameUtil._snapToGrid then return end

  local size = FrameUtil._gridSize or 16
  if size <= 0 then return end

  local frame = entry.frame
  local fl, fr, ft, fb = GetFrameEdges(frame)
  if not fl then return end

  local parentLeft = UIParent:GetLeft()
  local parentTop = UIParent:GetTop()
  local parentWidth = UIParent:GetWidth()
  local parentHeight = UIParent:GetHeight()
  if not parentLeft or not parentTop or not parentWidth or not parentHeight then
    return
  end

  local maxGridX = math_floor(parentWidth / size) * size
  local maxGridY = math_floor(parentHeight / size) * size

  local bestDx, bestDy, bestDistance =
    GetGridCornerDelta(fl, ft, parentLeft, parentTop, maxGridX, maxGridY, size, preserveAxis)

  local dx, dy, distance =
    GetGridCornerDelta(fr, ft, parentLeft, parentTop, maxGridX, maxGridY, size, preserveAxis)
  if distance < bestDistance then
    bestDx, bestDy, bestDistance = dx, dy, distance
  end

  dx, dy, distance =
    GetGridCornerDelta(fl, fb, parentLeft, parentTop, maxGridX, maxGridY, size, preserveAxis)
  if distance < bestDistance then
    bestDx, bestDy, bestDistance = dx, dy, distance
  end

  dx, dy, distance =
    GetGridCornerDelta(fr, fb, parentLeft, parentTop, maxGridX, maxGridY, size, preserveAxis)
  if distance < bestDistance then
    bestDx, bestDy = dx, dy
  end

  if bestDx == 0 and bestDy == 0 then
    return
  end

  local cx, cy = frame:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if not cx or not cy or not ux or not uy then
    return
  end

  MoveEntryTo(entry, (cx - ux) + bestDx, (cy - uy) + bestDy, true)
end

-- Helpers: "near in Y" / "near in X" using EDGE distance with tolerance.
local function IsVerticallyNear(ft, fb, ot, ob, tol)
  -- Using same separation logic as FramesTouching but with a tolerance band.
  if fb > ot then
    -- A below B
    return (fb - ot) <= tol
  elseif ob > ft then
    -- B below A
    return (ob - ft) <= tol
  else
    -- Overlapping vertically
    return true
  end
end

local function IsHorizontallyNear(fl, fr, ol, orr, tol)
  if fr < ol then
    -- A left of B
    return (ol - fr) <= tol
  elseif orr < fl then
    -- B left of A
    return (fl - orr) <= tol
  else
    -- Overlapping horizontally
    return true
  end
end

local function FindFrameSnap(entry, ignoreEntries)
  if not entry or not entry.frame then return end
  if not FrameUtil._snapToFrame then return end

  local tol = FrameUtil._snapTolerance or 8

  local f = entry.frame
  local fl, fr, ft, fb = GetFrameEdges(f)
  if not fl then return end

  local bestDx, bestDy
  local bestPeer, guidePosition
  local bestAxis -- "H" or "V"

  for _, other in ipairs(MoversList) do
    if other ~= entry
       and not (ignoreEntries and ignoreEntries[other])
       and other.frame
       and other.frame:IsShown()
       and not other._editSessionHidden
       and not other._suppressed
       and not other._presetHidden
       and FrameUtil.CanMoversShareSnapGroup(entry, other) then
      local ol, orr, ot, ob = GetFrameEdges(other.frame)
      if ol then
        local nearVert  = IsVerticallyNear(ft, fb, ot, ob, tol)
        local nearHoriz = IsHorizontallyNear(fl, fr, ol, orr, tol)

        -- Horizontal snap (left/right) – only if vertically near.
        if nearVert then
          local dx1 = ol  - fr
          local dx2 = orr - fl

          local absDx1 = math_abs(dx1)
          if absDx1 <= tol then
            if not bestDx or absDx1 < math_abs(bestDx) then
              bestDx, bestDy, bestPeer, bestAxis = dx1, nil, other, "H"
              guidePosition = ol
            end
          end

          local absDx2 = math_abs(dx2)
          if absDx2 <= tol then
            if not bestDx or absDx2 < math_abs(bestDx) then
              bestDx, bestDy, bestPeer, bestAxis = dx2, nil, other, "H"
              guidePosition = orr
            end
          end
        end

        -- Vertical snap (top/bottom) – only if horizontally near.
        if nearHoriz then
          local dy1 = ot - fb
          local dy2 = ob - ft

          local absDy1 = math_abs(dy1)
          if absDy1 <= tol then
            if not bestDy or absDy1 < math_abs(bestDy) then
              bestDy, bestDx, bestPeer, bestAxis = dy1, nil, other, "V"
              guidePosition = ot
            end
          end

          local absDy2 = math_abs(dy2)
          if absDy2 <= tol then
            if not bestDy or absDy2 < math_abs(bestDy) then
              bestDy, bestDx, bestPeer, bestAxis = dy2, nil, other, "V"
              guidePosition = ob
            end
          end
        end
      end
    end
  end

  if not bestPeer then
    return
  end

  return bestPeer, bestAxis, bestDx, bestDy, guidePosition
end

local function ClearFrameSnapFeedback()
  local feedback = FrameUtil._frameSnapFeedback
  if feedback then
    feedback.ownerKey, feedback.targetKey = nil, nil
    feedback.highlight:ClearAllPoints()
    feedback.guide:ClearAllPoints()
    feedback:Hide()
  end
end

local function UpdateFrameSnapFeedback(entry, ignoreEntries)
  local peer, axis, _, _, position = FindFrameSnap(entry, ignoreEntries)
  if not peer then
    ClearFrameSnapFeedback()
    return
  end
  local scale, parentScale = peer.frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
  if _G.issecretvalue(scale) or _G.issecretvalue(parentScale) then
    ClearFrameSnapFeedback()
    return
  end
  local feedback = FrameUtil._frameSnapFeedback
  if not feedback then
    feedback = CreateFrame("Frame", nil, UIParent)
    feedback:EnableMouse(false)
    feedback:SetFrameStrata(GetMoverChromeStrata())
    feedback.highlight = CreateFrame("Frame", nil, feedback, "BackdropTemplate")
    feedback.highlight:EnableMouse(false)
    ns.Theme.SetSquareBackdrop(feedback.highlight, {
      bg = { 0, 0, 0, 0 }, border = { 0, 0, 0, 0 },
    }, 1)
    feedback.guide = feedback:CreateTexture(nil, "OVERLAY")
    FrameUtil._frameSnapFeedback = feedback
    FrameUtil.RefreshMoverLayering()
  end
  local accent = ns.Theme.GetColors().accent
  feedback.highlight:SetBackdropColor(accent[1], accent[2], accent[3], 0.06)
  feedback.highlight:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.85)
  feedback.highlight:ClearAllPoints()
  feedback.highlight:SetPoint("TOPLEFT", peer.frame, "TOPLEFT", -2, 2)
  feedback.highlight:SetPoint("BOTTOMRIGHT", peer.frame, "BOTTOMRIGHT", 2, -2)
  feedback.guide:ClearAllPoints()
  feedback.guide:SetColorTexture(accent[1], accent[2], accent[3], 0.45)
  position = position * scale / parentScale
  if axis == "H" then
    feedback.guide:SetSize(1, UIParent:GetHeight())
    feedback.guide:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", position, 0)
  else
    feedback.guide:SetSize(UIParent:GetWidth(), 1)
    feedback.guide:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, position)
  end
  feedback.ownerKey, feedback.targetKey = entry.key, peer.key
  feedback:Show()
end

function FrameUtil._ApplyFrameSnap(entry, live, ignoreEntries)
  local bestPeer, bestAxis, bestDx, bestDy = FindFrameSnap(entry, ignoreEntries)
  if not bestPeer then return end
  local f = entry.frame
  local ox, oy = GetOffsetsForFrame(f)
  local nx, ny = ox, oy

  if bestAxis == "H" and bestDx then
    nx = ox + bestDx
  elseif bestAxis == "V" and bestDy then
    ny = oy + bestDy
  end

  if nx ~= ox or ny ~= oy then
    MoveEntryTo(entry, nx, ny, live and true or false)
  end

  FrameUtil._InitEditModeConfig()
  return bestAxis
end

FrameUtil._smartSnapEnabled = FrameUtil._smartSnapEnabled ~= false
FrameUtil._SmartSnapLinks = FrameUtil._SmartSnapLinks or {}
FrameUtil._SmartSnapMasters = FrameUtil._SmartSnapMasters or {}
FrameUtil._smartSnapLoaded = FrameUtil._smartSnapLoaded or false
FrameUtil._smartSnapApplying = FrameUtil._smartSnapApplying or false
FrameUtil._pendingSmartSnapRelayouts = FrameUtil._pendingSmartSnapRelayouts or {}
FrameUtil._pendingSmartSnapRuntimeRelayouts = FrameUtil._pendingSmartSnapRuntimeRelayouts or {}
FrameUtil._startupLayoutParticipants = FrameUtil._startupLayoutParticipants or {}
FrameUtil._startupLayoutParticipantOrder = FrameUtil._startupLayoutParticipantOrder or {}

local SmartSnapLinks = FrameUtil._SmartSnapLinks
local SmartSnapMasters = FrameUtil._SmartSnapMasters
local PendingSmartSnapRelayouts = FrameUtil._pendingSmartSnapRelayouts
local PendingSmartSnapRuntimeRelayouts = FrameUtil._pendingSmartSnapRuntimeRelayouts
local StartupLayoutParticipants = FrameUtil._startupLayoutParticipants
local StartupLayoutParticipantOrder = FrameUtil._startupLayoutParticipantOrder
FrameUtil._smartSnapRuntimeRelayoutScheduled = false
FrameUtil._smartSnapWorldReady = false

function FrameUtil:RegisterStartupLayoutParticipant(key, prepare, complete)
  if self._smartSnapWorldReady then
    return
  end

  if not StartupLayoutParticipants[key] then
    StartupLayoutParticipantOrder[#StartupLayoutParticipantOrder + 1] = key
  end

  StartupLayoutParticipants[key] = {
    prepare = prepare,
    complete = complete,
  }
end

function FrameUtil.BeginProfileTransition()
  FrameUtil.ClearEditHistory()
  FrameUtil._profileTransitionActive = true
  FrameUtil._editModeConfigDB = nil
  FrameUtil._smartSnapDBRef = nil
  wipe(PendingSmartSnapRelayouts)
  wipe(PendingSmartSnapRuntimeRelayouts)
end

local SMART_SNAP_RELATIONS = {
  ABOVE = true,
  BELOW = true,
  LEFT = true,
  RIGHT = true,
}
local SMART_SNAP_OPPOSITE = {
  ABOVE = "BELOW",
  BELOW = "ABOVE",
  LEFT = "RIGHT",
  RIGHT = "LEFT",
}
local SMART_SNAP_ALIGNMENTS = {
  LEFT = true,
  CENTER = true,
  RIGHT = true,
  TOP = true,
  BOTTOM = true,
}
local SMART_SNAP_RELATION_ORDER = {
  "ABOVE",
  "BELOW",
  "LEFT",
  "RIGHT",
}
local SMART_SNAP_GAP_MAX = 200
local SMART_SNAP_SIDE_OFFSET_MAX = 200

local function NormalizeSmartSnapGap(value)
  return Round(math_min(
    SMART_SNAP_GAP_MAX,
    math_max(-SMART_SNAP_GAP_MAX, tonumber(value) or 0)
  ))
end

local function NormalizeSmartSnapSideOffset(value)
  return Round(math_min(
    SMART_SNAP_SIDE_OFFSET_MAX,
    math_max(-SMART_SNAP_SIDE_OFFSET_MAX, tonumber(value) or 0)
  ))
end

local function CopyValue(value)
  if type(value) ~= "table" then
    return value
  end

  local out = {}
  for key, child in pairs(value) do
    out[key] = CopyValue(child)
  end
  return out
end

local function ValuesEqual(first, second)
  if first == second then
    return true
  end
  if type(first) ~= type(second) then
    return false
  end
  if type(first) ~= "table" then
    return false
  end

  for key, value in pairs(first) do
    if not ValuesEqual(value, second[key]) then
      return false
    end
  end
  for key in pairs(second) do
    if first[key] == nil then
      return false
    end
  end
  return true
end

local function ApplyEditHistoryDelta(current, saved, opposite)
  for key, value in pairs(saved) do
    if not ValuesEqual(value, opposite[key]) then
      if type(value) == "table" and type(opposite[key]) == "table" and type(current[key]) == "table" then
        ApplyEditHistoryDelta(current[key], value, opposite[key])
      else
        current[key] = CopyValue(value)
      end
    end
  end
  for key in pairs(opposite) do
    if saved[key] == nil then current[key] = nil end
  end
end

local function GetSmartSnapDB()
  local db = FrameUtil._GetEditModeDB()
  db.smartSnap = db.smartSnap or {}
  db.smartSnap.links = db.smartSnap.links or {}
  db.smartSnap.masters = db.smartSnap.masters or {}
  db.smartSnap.widthSyncDisabled = db.smartSnap.widthSyncDisabled or {}
  return db.smartSnap
end

local function EnsureSmartSnapLoaded()
  local db = GetSmartSnapDB()
  if FrameUtil._smartSnapLoaded and FrameUtil._smartSnapDBRef == db then
    return
  end

  wipe(SmartSnapLinks)
  wipe(SmartSnapMasters)
  FrameUtil._smartSnapLoaded = true
  FrameUtil._smartSnapDBRef = db

  local persisted = db.links
  for keyA, peers in pairs(persisted) do
    if type(peers) == "table" then
      for keyB, link in pairs(peers) do
        if type(link) == "table" and SMART_SNAP_RELATIONS[link.relation] then
          SmartSnapLinks[keyA] = SmartSnapLinks[keyA] or {}
          SmartSnapLinks[keyA][keyB] = {
            relation = link.relation,
            alignment = SMART_SNAP_ALIGNMENTS[link.alignment] and link.alignment or "CENTER",
            gap = NormalizeSmartSnapGap(link.gap),
            sideOffset = NormalizeSmartSnapSideOffset(link.sideOffset),
            syncSize = link.syncSize == true,
            syncDesign = link.syncDesign == true,
          }
        end
      end
    end
  end

  for key, isMaster in pairs(db.masters) do
    if isMaster == true then
      SmartSnapMasters[key] = true
    end
  end
end

local function PersistSmartSnapLinks()
  local db = GetSmartSnapDB()
  wipe(db.links)

  for keyA, peers in pairs(SmartSnapLinks) do
    if next(peers) then
      db.links[keyA] = {}
      for keyB, link in pairs(peers) do
        db.links[keyA][keyB] = {
          relation = link.relation,
          alignment = SMART_SNAP_ALIGNMENTS[link.alignment] and link.alignment or "CENTER",
          gap = NormalizeSmartSnapGap(link.gap),
          sideOffset = NormalizeSmartSnapSideOffset(link.sideOffset),
          syncSize = link.syncSize == true,
          syncDesign = link.syncDesign == true,
        }
      end
    end
  end
end

function FrameUtil.HasSmartSnapLinks(key)
  EnsureSmartSnapLoaded()
  return SmartSnapLinks[key] ~= nil and next(SmartSnapLinks[key]) ~= nil
end

local function GetSmartSnapTopologyKeys(startKey)
  EnsureSmartSnapLoaded()

  local keys = {}
  local function AddKey(key)
    if not key or keys[key] then
      return
    end

    keys[key] = true
    local peers = SmartSnapLinks[key]
    if peers then
      for peerKey in pairs(peers) do
        AddKey(peerKey)
      end
    end
  end

  AddKey(startKey)
  return keys
end

local function PersistSmartSnapMasters()
  local db = GetSmartSnapDB()
  wipe(db.masters)

  for masterKey, isMaster in pairs(SmartSnapMasters) do
    if isMaster == true and SmartSnapLinks[masterKey] then
      db.masters[masterKey] = true
    end
  end
end

local function GetSmartSnapClusterMasterKey(startKey)
  if not startKey then
    return nil
  end

  local topology = GetSmartSnapTopologyKeys(startKey)
  local masterKey
  local duplicateMaster = false

  for memberKey in pairs(topology) do
    if SmartSnapMasters[memberKey] == true then
      if not masterKey or tostring(memberKey) < tostring(masterKey) then
        if masterKey then
          duplicateMaster = true
        end
        masterKey = memberKey
      else
        duplicateMaster = true
      end
    end
  end

  if duplicateMaster then
    for memberKey in pairs(topology) do
      if memberKey ~= masterKey then
        SmartSnapMasters[memberKey] = nil
      end
    end
    PersistSmartSnapMasters()
  end

  return masterKey
end

local function SetSmartSnapClusterMaster(startKey, masterKey)
  if not startKey or not masterKey then
    return
  end

  local topology = GetSmartSnapTopologyKeys(startKey)
  if not topology[masterKey] then
    return
  end

  for memberKey in pairs(topology) do
    SmartSnapMasters[memberKey] = nil
  end
  SmartSnapMasters[masterKey] = true

  PersistSmartSnapMasters()
end

local function ClearSmartSnapClusterMaster(startKey)
  if not startKey then
    return
  end

  for memberKey in pairs(GetSmartSnapTopologyKeys(startKey)) do
    SmartSnapMasters[memberKey] = nil
  end

  PersistSmartSnapMasters()
end

local function GetSmartSnapOptions(entry)
  local opts = entry and entry.opts
  local smartSnap = opts and opts.smartSnap
  if type(smartSnap) ~= "table" or type(smartSnap.family) ~= "string" or smartSnap.family == "" then
    return nil
  end
  return smartSnap
end

local function GetSmartSnapInsets(entry)
  local smartSnap = GetSmartSnapOptions(entry)
  if not smartSnap or type(smartSnap.getSnapInsets) ~= "function" then
    return 0, 0, 0, 0
  end

  local left, right, top, bottom = smartSnap.getSnapInsets(entry.frame, entry)
  return
    math_max(0, Round(tonumber(left) or 0)),
    math_max(0, Round(tonumber(right) or 0)),
    math_max(0, Round(tonumber(top) or 0)),
    math_max(0, Round(tonumber(bottom) or 0))
end

local function GetSmartSnapGeometry(entry)
  if not entry or not entry.frame then
    return nil
  end

  local left, right, top, bottom = GetFrameEdges(entry.frame)
  if not left then
    return nil
  end

  local insetLeft, insetRight, insetTop, insetBottom = GetSmartSnapInsets(entry)
  left = left - insetLeft
  right = right + insetRight
  top = top + insetTop
  bottom = bottom - insetBottom

  return {
    left = left,
    right = right,
    top = top,
    bottom = bottom,
    centerX = (left + right) * 0.5,
    centerY = (top + bottom) * 0.5,
    insetLeft = insetLeft,
    insetRight = insetRight,
    insetTop = insetTop,
    insetBottom = insetBottom,
  }
end

local function SmartSnapHasFamily(smartSnap, family)
  if not smartSnap or type(family) ~= "string" or family == "" then
    return false
  end

  if smartSnap.family == family then
    return true
  end

  local families = smartSnap.families
  return type(families) == "table" and families[family] == true
end

local function SmartSnapSharesSyncFamily(firstOpts, secondOpts)
  if not firstOpts or not secondOpts then
    return false
  end

  if firstOpts.family == "positionOnly" or secondOpts.family == "positionOnly" then
    return false
  end

  if SmartSnapHasFamily(secondOpts, firstOpts.family)
    or SmartSnapHasFamily(firstOpts, secondOpts.family)
  then
    return true
  end

  local families = firstOpts.families
  if type(families) == "table" then
    for family, enabled in pairs(families) do
      if enabled == true and SmartSnapHasFamily(secondOpts, family) then
        return true
      end
    end
  end

  return false
end

local function SmartSnapSupportsSize(smartSnap)
  if not smartSnap or smartSnap.syncAxis == "NONE" then
    return false
  end

  if smartSnap.syncAxis == "WIDTH" then
    return type(smartSnap.getSyncWidth) == "function"
      and type(smartSnap.applySyncWidth) == "function"
  end

  return type(smartSnap.copySizeFrom) == "function"
    or type(smartSnap.applyDimensions) == "function"
end

local function IsSmartSnapWidthSyncAllowed(entry)
  local smartSnap = GetSmartSnapOptions(entry)
  if not smartSnap or smartSnap.syncAxis ~= "WIDTH" then
    return true
  end

  local db = GetSmartSnapDB()
  return db.widthSyncDisabled[entry.key] ~= true
end

local function SmartSnapAllowsSizeSync(entry)
  local smartSnap = GetSmartSnapOptions(entry)
  if not SmartSnapSupportsSize(smartSnap) then
    return false
  end

  if smartSnap.syncAxis == "WIDTH" then
    return IsSmartSnapWidthSyncAllowed(entry)
  end

  return true
end

local function SmartSnapCanSyncSize(firstEntry, secondEntry)
  local firstOpts = GetSmartSnapOptions(firstEntry)
  local secondOpts = GetSmartSnapOptions(secondEntry)
  return SmartSnapSharesSyncFamily(firstOpts, secondOpts)
    and SmartSnapSupportsSize(firstOpts)
    and SmartSnapSupportsSize(secondOpts)
end

local function SmartSnapUsesRelationSizeSync(firstEntry, secondEntry)
  local firstOpts = GetSmartSnapOptions(firstEntry)
  local secondOpts = GetSmartSnapOptions(secondEntry)
  return SmartSnapCanSyncSize(firstEntry, secondEntry)
    and firstOpts.relationSizeSync == true
    and secondOpts.relationSizeSync == true
end

local function SmartSnapLinkSyncsSize(firstEntry, secondEntry, link)
  return SmartSnapCanSyncSize(firstEntry, secondEntry)
    and (SmartSnapUsesRelationSizeSync(firstEntry, secondEntry)
      or (link and link.syncSize == true))
end

local function SmartSnapCanSyncDesign(firstEntry, secondEntry)
  local firstOpts = GetSmartSnapOptions(firstEntry)
  local secondOpts = GetSmartSnapOptions(secondEntry)
  if not SmartSnapSharesSyncFamily(firstOpts, secondOpts) then
    return false
  end

  return (
    type(firstOpts.getDesign) == "function"
      and type(secondOpts.applyDesign) == "function"
  ) or (
    type(secondOpts.getDesign) == "function"
      and type(firstOpts.applyDesign) == "function"
  )
end

local function IsSmartSnapRuntimeEntryActive(entry)
  -- Presets filter edit interactions; saved links still drive runtime layouts.
  if not entry or not entry.frame or entry._suppressed
    or (ns.Flags.IsEditing and entry._presetHidden)
  then
    return false
  end

  local smartSnap = GetSmartSnapOptions(entry)
  if smartSnap
    and type(smartSnap.isRuntimeActive) == "function"
    and smartSnap.isRuntimeActive(entry.frame, entry.key) ~= true
  then
    return false
  end

  if GhostMoverHelpers[entry.key] then
    return entry._smartSnapRuntimeActive == true
  end

  return true
end

function FrameUtil.GetSmartSnapWidthSyncAllowed(key)
  local entry = key and MoversByKey[key]
  if not entry then
    return true
  end

  return IsSmartSnapWidthSyncAllowed(entry)
end

local function IsSmartSnapMoverVisible(entry)
  if not entry.frame then
    return false
  end
  if entry.frame:IsShown() then
    return true
  end
  return ns.Flags.IsEditing == true
    and entry.overlay
    and entry.overlay:IsShown()
end

function FrameUtil.CanMoversShareSnapGroup(first, second)
  if first.opts.snapGroup ~= second.opts.snapGroup then
    return false
  end

  local uf = ns.Modules.UnitFrames
  return not (uf and uf.HasSeparatePosition and (
    uf:HasSeparatePosition(first.key) or uf:HasSeparatePosition(second.key)
  ))
end

local function CanSmartSnap(first, second)
  if first == second or not first or not second then
    return false
  end
  if not FrameUtil.CanMoversShareSnapGroup(first, second)
    or first._suppressed
    or second._suppressed
    or first._editSessionHidden
    or second._editSessionHidden
    or (ns.Flags.IsEditing and (first._presetHidden or second._presetHidden))
  then
    return false
  end
  if not IsSmartSnapMoverVisible(first) or not IsSmartSnapMoverVisible(second) then
    return false
  end

  if not ns.Flags.IsEditing then
    local firstSnap = GetSmartSnapOptions(first)
    local secondSnap = GetSmartSnapOptions(second)
    if not firstSnap
      or not secondSnap
      or firstSnap.family ~= secondSnap.family
    then
      return false
    end
  end

  return true
end

local function SetSmartSnapLink(firstKey, secondKey, relation, alignment, syncSize, syncDesign, gap, sideOffset)
  if not firstKey or not secondKey or firstKey == secondKey or not SMART_SNAP_RELATIONS[relation] then
    return
  end

  alignment = SMART_SNAP_ALIGNMENTS[alignment] and alignment or "CENTER"
  gap = NormalizeSmartSnapGap(gap)
  sideOffset = NormalizeSmartSnapSideOffset(sideOffset)

  local firstEntry = MoversByKey[firstKey]
  local secondEntry = MoversByKey[secondKey]
  syncSize = syncSize == true and SmartSnapCanSyncSize(firstEntry, secondEntry)
  syncDesign = syncDesign == true and SmartSnapCanSyncDesign(firstEntry, secondEntry)

  SmartSnapLinks[firstKey] = SmartSnapLinks[firstKey] or {}
  SmartSnapLinks[secondKey] = SmartSnapLinks[secondKey] or {}

  SmartSnapLinks[firstKey][secondKey] = {
    relation = SMART_SNAP_OPPOSITE[relation],
    alignment = alignment,
    gap = gap,
    sideOffset = -sideOffset,
    syncSize = syncSize == true,
    syncDesign = syncDesign == true,
  }
  SmartSnapLinks[secondKey][firstKey] = {
    relation = relation,
    alignment = alignment,
    gap = gap,
    sideOffset = sideOffset,
    syncSize = syncSize == true,
    syncDesign = syncDesign == true,
  }

  PersistSmartSnapLinks()
end

function FrameUtil.SeedSmartSnapLink(firstKey, secondKey, relation, syncSize, syncDesign, alignment, gap, sideOffset)
  if not firstKey or not secondKey or firstKey == secondKey or not SMART_SNAP_RELATIONS[relation] then
    return false
  end

  EnsureSmartSnapLoaded()

  local firstEntry = MoversByKey[firstKey]
  local secondEntry = MoversByKey[secondKey]
  if not firstEntry or not secondEntry
    or not FrameUtil.CanMoversShareSnapGroup(firstEntry, secondEntry)
  then
    return false
  end

  local existing = SmartSnapLinks[firstKey] and SmartSnapLinks[firstKey][secondKey]
  if existing then
    return true
  end

  local masterKey = GetSmartSnapClusterMasterKey(secondKey) or secondKey
  alignment = SMART_SNAP_ALIGNMENTS[alignment] and alignment or "CENTER"

  local opposite = SMART_SNAP_OPPOSITE[relation]
  for peerKey, link in pairs(SmartSnapLinks[firstKey] or {}) do
    if peerKey ~= secondKey
      and link.relation == opposite
      and link.alignment == alignment
    then
      return false
    end
  end
  for peerKey, link in pairs(SmartSnapLinks[secondKey] or {}) do
    if peerKey ~= firstKey
      and link.relation == relation
      and link.alignment == alignment
    then
      return false
    end
  end

  SetSmartSnapLink(firstKey, secondKey, relation, alignment, syncSize, syncDesign, gap, sideOffset)
  SetSmartSnapClusterMaster(secondKey, masterKey)
  return true
end

local function RemoveSmartSnapLink(firstKey, secondKey)
  local firstLinks = SmartSnapLinks[firstKey]
  if firstLinks then
    firstLinks[secondKey] = nil
    if not next(firstLinks) then
      SmartSnapLinks[firstKey] = nil
    end
  end

  local secondLinks = SmartSnapLinks[secondKey]
  if secondLinks then
    secondLinks[firstKey] = nil
    if not next(secondLinks) then
      SmartSnapLinks[secondKey] = nil
    end
  end
end

function FrameUtil.ClearSmartSnapForKey(key)
  if not key then
    return
  end

  EnsureSmartSnapLoaded()
  local previousMasterKey = GetSmartSnapClusterMasterKey(key)
  ClearSmartSnapClusterMaster(key)

  local bridgeFirstKey
  local bridgeSecondKey
  local bridgeRelation
  local bridgeAlignment
  local bridgeGap
  local bridgeSideOffset
  local bridgeSyncSize
  local bridgeSyncDesign
  local peers = SmartSnapLinks[key]

  if peers then
    local peerRecords = {}
    for peerKey, link in pairs(peers) do
      peerRecords[#peerRecords + 1] = {
        key = peerKey,
        link = link,
      }
    end

    if #peerRecords == 2 then
      local first = peerRecords[1]
      local second = peerRecords[2]

      if SMART_SNAP_OPPOSITE[first.link.relation] == second.link.relation then
        bridgeFirstKey = first.key
        bridgeSecondKey = second.key
        bridgeRelation = second.link.relation
        bridgeAlignment = first.link.alignment == second.link.alignment and first.link.alignment or "CENTER"
        bridgeGap = NormalizeSmartSnapGap(first.link.gap) + NormalizeSmartSnapGap(second.link.gap)
        bridgeSideOffset = NormalizeSmartSnapSideOffset(second.link.sideOffset)
          - NormalizeSmartSnapSideOffset(first.link.sideOffset)
        bridgeSyncSize = first.link.syncSize == true and second.link.syncSize == true
        bridgeSyncDesign = first.link.syncDesign == true and second.link.syncDesign == true
      end
    end

    for _, record in ipairs(peerRecords) do
      RemoveSmartSnapLink(key, record.key)
    end
  end

  SmartSnapLinks[key] = nil

  if bridgeFirstKey and bridgeSecondKey then
    SetSmartSnapLink(
      bridgeSecondKey,
      bridgeFirstKey,
      bridgeRelation,
      bridgeAlignment,
      bridgeSyncSize,
      bridgeSyncDesign,
      bridgeGap,
      bridgeSideOffset
    )
  else
    PersistSmartSnapLinks()
  end

  if previousMasterKey
    and previousMasterKey ~= key
    and SmartSnapLinks[previousMasterKey]
  then
    SetSmartSnapClusterMaster(previousMasterKey, previousMasterKey)
  end

  if bridgeFirstKey and bridgeSecondKey then
    FrameUtil.RelayoutSmartSnapCluster(bridgeFirstKey, true)
  end
end

local function GetSmartSnapCluster(entry)
  EnsureSmartSnapLoaded()

  local cluster = {}
  if not entry or not entry.key then
    return cluster
  end

  local visited = {}
  local function AddKey(key)
    if not key or visited[key] then
      return
    end
    visited[key] = true

    local current = MoversByKey[key]
    if not IsSmartSnapRuntimeEntryActive(current) then
      return
    end

    cluster[current] = true

    local peers = SmartSnapLinks[key]
    if peers then
      for peerKey in pairs(peers) do
        AddKey(peerKey)
      end
    end
  end

  AddKey(entry.key)
  return cluster
end

local function GetSmartSnapSizeSyncCluster(entry)
  local cluster = {}
  if not entry or not entry.key then
    return cluster
  end

  local visited = {}
  local function AddKey(key)
    if not key or visited[key] then
      return
    end

    visited[key] = true
    local current = MoversByKey[key]
    if not IsSmartSnapRuntimeEntryActive(current) or not SmartSnapAllowsSizeSync(current) then
      return
    end

    cluster[current] = true

    local peers = SmartSnapLinks[key]
    if peers then
      for peerKey, link in pairs(peers) do
        local peer = MoversByKey[peerKey]
        if IsSmartSnapRuntimeEntryActive(peer)
          and SmartSnapLinkSyncsSize(current, peer, link)
        then
          AddKey(peerKey)
        end
      end
    end
  end

  AddKey(entry.key)
  return cluster
end

local function ClampSmartSnapWidthForEntry(entry, width)
  width = tonumber(width)
  if not width then
    return nil
  end

  local opts = GetSmartSnapOptions(entry)
  local minimum = opts and tonumber(opts.syncWidthMin) or nil
  local maximum = opts and tonumber(opts.syncWidthMax) or nil

  if minimum and width < minimum then
    width = minimum
  end
  if maximum and width > maximum then
    width = maximum
  end

  return Round(width)
end

local function GetSmartSnapClusterWidthBounds(entry)
  local minimum
  local maximum

  for member in pairs(GetSmartSnapSizeSyncCluster(entry)) do
    local opts = GetSmartSnapOptions(member)
    if SmartSnapSupportsSize(opts) and opts.syncAxis == "WIDTH" then
      local memberMinimum = tonumber(opts.syncWidthMin)
      local memberMaximum = tonumber(opts.syncWidthMax)

      if memberMinimum then
        minimum = minimum and math_max(minimum, memberMinimum) or memberMinimum
      end
      if memberMaximum then
        maximum = maximum and math_min(maximum, memberMaximum) or memberMaximum
      end
    end
  end

  return minimum, maximum
end

local function ClampSmartSnapClusterWidth(entry, width)
  width = tonumber(width)
  if not width then
    return nil
  end

  local minimum, maximum = GetSmartSnapClusterWidthBounds(entry)
  if minimum and width < minimum then
    width = minimum
  end
  if maximum and width > maximum then
    width = maximum
  end

  return Round(width)
end

local function CaptureSmartSnapState(entry)
  local smartSnap = GetSmartSnapOptions(entry)
  if not smartSnap then
    return nil
  end

  local sizeState
  if smartSnap.syncAxis == "WIDTH" and type(smartSnap.getSyncWidth) == "function" then
    sizeState = {
      width = Round(smartSnap.getSyncWidth(entry.frame, entry.key) or 0),
      frameWidth = entry.frame and Round(entry.frame:GetWidth() or 0) or 0,
      frameHeight = entry.frame and Round(entry.frame:GetHeight() or 0) or 0,
    }
  elseif type(smartSnap.getSizeState) == "function" then
    sizeState = smartSnap.getSizeState(entry.frame, entry.key)
  elseif entry.frame then
    sizeState = {
      width = Round(entry.frame:GetWidth() or 0),
      height = Round(entry.frame:GetHeight() or 0),
    }
  end

  local designState
  if type(smartSnap.getDesign) == "function" then
    designState = smartSnap.getDesign(entry.frame, entry.key)
  end

  return {
    size = CopyValue(sizeState),
    design = CopyValue(designState),
  }
end

local function CopySmartSnapSize(targetEntry, sourceEntry, relation, fullSize, allowCustomDefault)
  local targetOpts = GetSmartSnapOptions(targetEntry)
  local sourceOpts = GetSmartSnapOptions(sourceEntry)
  if not SmartSnapSharesSyncFamily(targetOpts, sourceOpts) then
    return
  end

  if SmartSnapUsesRelationSizeSync(targetEntry, sourceEntry) then
    fullSize = false
  end

  if targetOpts.syncAxis == "WIDTH" and sourceOpts.syncAxis == "WIDTH" then
    if not IsSmartSnapWidthSyncAllowed(targetEntry) or not IsSmartSnapWidthSyncAllowed(sourceEntry) then
      return
    end

    if (fullSize == true or allowCustomDefault == true)
      and type(targetOpts.getSyncWidth) == "function"
      and type(targetOpts.applySyncWidth) == "function"
      and type(sourceOpts.getSyncWidth) == "function"
    then
      local width = Round(sourceOpts.getSyncWidth(sourceEntry.frame, sourceEntry.key) or 0)
      width = ClampSmartSnapWidthForEntry(targetEntry, width)
      local currentWidth = Round(targetOpts.getSyncWidth(targetEntry.frame, targetEntry.key) or 0)
      if width and width > 0 and width ~= currentWidth then
        targetOpts.applySyncWidth(width, sourceEntry)
      end
    end
    return
  end

  if type(targetOpts.copySizeFrom) == "function" then
    if fullSize == true or allowCustomDefault == true then
      targetOpts.copySizeFrom(sourceEntry, relation, fullSize == true)
    end
    return
  end

  if type(targetOpts.applyDimensions) ~= "function" or not sourceEntry.frame then
    return
  end

  local width
  local height
  if fullSize == true or relation == "ABOVE" or relation == "BELOW" then
    width = Round(sourceEntry.frame:GetWidth() or 0)
  end
  if fullSize == true or relation == "LEFT" or relation == "RIGHT" then
    height = Round(sourceEntry.frame:GetHeight() or 0)
  end

  if (width and width > 0) or (height and height > 0) then
    targetOpts.applyDimensions(width, height, sourceEntry)
  end
end

function FrameUtil.SetSmartSnapWidthSyncAllowed(key, allowed)
  local entry = key and MoversByKey[key]
  local smartSnap = GetSmartSnapOptions(entry)
  if not entry or not smartSnap or smartSnap.syncAxis ~= "WIDTH" then
    return
  end

  local db = GetSmartSnapDB()
  if allowed == false then
    db.widthSyncDisabled[key] = true
  else
    db.widthSyncDisabled[key] = nil
  end

  entry._smartSnapState = CaptureSmartSnapState(entry)

  if SmartSnapLinks[key] then
    FrameUtil.RelayoutSmartSnapCluster(key, true)
  end
end

local function ApplySmartSnapDesign(targetEntry, design, sourceEntry)
  local targetOpts = GetSmartSnapOptions(targetEntry)
  local sourceOpts = GetSmartSnapOptions(sourceEntry)
  if not SmartSnapSharesSyncFamily(targetOpts, sourceOpts)
    or type(targetOpts.applyDesign) ~= "function"
    or type(design) ~= "table"
  then
    return
  end

  targetOpts.applyDesign(CopyValue(design), sourceEntry)
end

local function GetSmartSnapPosition(entry, target, relation, alignment, gap, sideOffset)
  if not entry or not target or not entry.frame or not target.frame then
    return nil
  end

  local entryGeometry = GetSmartSnapGeometry(entry)
  local targetGeometry = GetSmartSnapGeometry(target)
  local width = entry.frame:GetWidth()
  local height = entry.frame:GetHeight()
  local uiCenterX, uiCenterY = UIParent:GetCenter()
  if not entryGeometry or not targetGeometry or not width or not height or not uiCenterX or not uiCenterY then
    return nil
  end

  alignment = SMART_SNAP_ALIGNMENTS[alignment] and alignment or "CENTER"
  gap = NormalizeSmartSnapGap(gap)
  sideOffset = NormalizeSmartSnapSideOffset(sideOffset)

  local centerX = targetGeometry.centerX
    - ((entryGeometry.insetRight - entryGeometry.insetLeft) * 0.5)
  local centerY = targetGeometry.centerY
    - ((entryGeometry.insetTop - entryGeometry.insetBottom) * 0.5)

  if relation == "ABOVE" then
    centerY = targetGeometry.top + gap + entryGeometry.insetBottom + (height * 0.5)
    if alignment == "LEFT" then
      centerX = targetGeometry.left + entryGeometry.insetLeft + (width * 0.5)
    elseif alignment == "RIGHT" then
      centerX = targetGeometry.right - entryGeometry.insetRight - (width * 0.5)
    end
    centerX = centerX + sideOffset
  elseif relation == "BELOW" then
    centerY = targetGeometry.bottom - gap - entryGeometry.insetTop - (height * 0.5)
    if alignment == "LEFT" then
      centerX = targetGeometry.left + entryGeometry.insetLeft + (width * 0.5)
    elseif alignment == "RIGHT" then
      centerX = targetGeometry.right - entryGeometry.insetRight - (width * 0.5)
    end
    centerX = centerX + sideOffset
  elseif relation == "LEFT" then
    centerX = targetGeometry.left - gap - entryGeometry.insetRight - (width * 0.5)
    if alignment == "TOP" then
      centerY = targetGeometry.top - entryGeometry.insetTop - (height * 0.5)
    elseif alignment == "BOTTOM" then
      centerY = targetGeometry.bottom + entryGeometry.insetBottom + (height * 0.5)
    end
    centerY = centerY + sideOffset
  elseif relation == "RIGHT" then
    centerX = targetGeometry.right + gap + entryGeometry.insetLeft + (width * 0.5)
    if alignment == "TOP" then
      centerY = targetGeometry.top - entryGeometry.insetTop - (height * 0.5)
    elseif alignment == "BOTTOM" then
      centerY = targetGeometry.bottom + entryGeometry.insetBottom + (height * 0.5)
    end
    centerY = centerY + sideOffset
  else
    return nil
  end

  return centerX - uiCenterX, centerY - uiCenterY
end

local function PositionSmartSnapEntry(entry, target, relation, alignment, gap, sideOffset)
  local x, y = GetSmartSnapPosition(entry, target, relation, alignment, gap, sideOffset)
  if x == nil or y == nil then
    return
  end

  MoveEntryTo(entry, x, y, true)
end

local function GetStableSmartSnapRoot(startKey)
  local startEntry = MoversByKey[startKey]
  local cluster = GetSmartSnapCluster(startEntry)
  local masterKey = GetSmartSnapClusterMasterKey(startKey)

  if masterKey then
    local masterEntry = MoversByKey[masterKey]
    if masterEntry and cluster[masterEntry] and GetSmartSnapGeometry(masterEntry) then
      return masterEntry, true
    end
  end

  local bestEntry
  local bestTop
  local bestLeft

  for entry in pairs(cluster) do
    local geometry = GetSmartSnapGeometry(entry)
    if geometry then
      local left, top = geometry.left, geometry.top
      if not bestEntry
        or bestTop == nil
        or top > bestTop
        or (top == bestTop and left < bestLeft)
      then
        bestEntry = entry
        bestTop = top
        bestLeft = left
      end
    elseif not bestEntry then
      bestEntry = entry
    end
  end

  if bestEntry and not masterKey then
    SetSmartSnapClusterMaster(startKey, bestEntry.key)
    return bestEntry, true
  end

  return bestEntry, false
end

local function GetSmartSnapAlignmentOrder(relation, alignment)
  if relation == "ABOVE" or relation == "BELOW" then
    if alignment == "LEFT" then
      return 1
    elseif alignment == "RIGHT" then
      return 3
    end
    return 2
  end

  if alignment == "TOP" then
    return 1
  elseif alignment == "BOTTOM" then
    return 3
  end
  return 2
end

local function GetNextActiveSmartSnapPeers(startKey, relation)
  local results = {}

  for peerKey, link in pairs(SmartSnapLinks[startKey] or {}) do
    local entry = MoversByKey[peerKey]
    if link.relation == relation and IsSmartSnapRuntimeEntryActive(entry) then
      results[#results + 1] = {
        entry = entry,
        relation = relation,
        alignment = link.alignment,
        gap = NormalizeSmartSnapGap(link.gap),
        sideOffset = NormalizeSmartSnapSideOffset(link.sideOffset),
        syncSize = link.syncSize == true,
        syncDesign = link.syncDesign == true,
      }
    end
  end

  _G.table.sort(results, function(first, second)
    local firstOrder = GetSmartSnapAlignmentOrder(relation, first.alignment)
    local secondOrder = GetSmartSnapAlignmentOrder(relation, second.alignment)
    if firstOrder ~= secondOrder then
      return firstOrder < secondOrder
    end
    return tostring(first.entry.key) < tostring(second.entry.key)
  end)

  return results
end

local function GetSmartSnapSizeSource(startEntry)
  if IsSmartSnapRuntimeEntryActive(startEntry) and SmartSnapAllowsSizeSync(startEntry) then
    return startEntry
  end

  local bestEntry
  local bestTop
  local bestLeft

  for entry in pairs(GetSmartSnapSizeSyncCluster(startEntry)) do
    local left, _, top = GetFrameEdges(entry.frame)
    if left and top then
      if not bestEntry
        or bestTop == nil
        or top > bestTop
        or (top == bestTop and left < bestLeft)
      then
        bestEntry = entry
        bestTop = top
        bestLeft = left
      end
    elseif not bestEntry then
      bestEntry = entry
    end
  end

  return bestEntry
end

local function ApplySmartSnapSizeSync(sourceEntry)
  if not sourceEntry or not SmartSnapAllowsSizeSync(sourceEntry) then
    return {}
  end

  local affected = { [sourceEntry] = true }
  local sourceOpts = GetSmartSnapOptions(sourceEntry)

  if sourceOpts.syncAxis == "WIDTH"
    and type(sourceOpts.getSyncWidth) == "function"
    and type(sourceOpts.applySyncWidth) == "function"
  then
    local currentWidth = Round(sourceOpts.getSyncWidth(sourceEntry.frame, sourceEntry.key) or 0)
    local clampedWidth = ClampSmartSnapClusterWidth(sourceEntry, currentWidth)
    if clampedWidth and clampedWidth > 0 and clampedWidth ~= currentWidth then
      sourceOpts.applySyncWidth(clampedWidth, sourceEntry)
    end
  end

  if sourceOpts.relationSizeSync == true then
    local visited = {
      WIDTH = { [sourceEntry.key] = true },
      HEIGHT = { [sourceEntry.key] = true },
    }
    local queue = {
      { key = sourceEntry.key, axis = "WIDTH" },
      { key = sourceEntry.key, axis = "HEIGHT" },
    }
    local index = 1

    while queue[index] do
      local state = queue[index]
      index = index + 1

      local current = MoversByKey[state.key]
      local peers = SmartSnapLinks[state.key]
      if peers then
        for peerKey, link in pairs(peers) do
          local peer = MoversByKey[peerKey]
          local relationMatchesAxis = (
            state.axis == "WIDTH"
              and (link.relation == "ABOVE" or link.relation == "BELOW")
          ) or (
            state.axis == "HEIGHT"
              and (link.relation == "LEFT" or link.relation == "RIGHT")
          )

          if relationMatchesAxis
            and not visited[state.axis][peerKey]
            and SmartSnapUsesRelationSizeSync(current, peer)
          then
            visited[state.axis][peerKey] = true

            if IsSmartSnapRuntimeEntryActive(peer) and SmartSnapAllowsSizeSync(peer) then
              CopySmartSnapSize(peer, sourceEntry, link.relation, false, false)
              affected[peer] = true
            end

            queue[#queue + 1] = {
              key = peerKey,
              axis = state.axis,
            }
          end
        end
      end
    end

    return affected
  end

  local visited = { [sourceEntry.key] = true }
  local queue = { sourceEntry.key }
  local index = 1

  while queue[index] do
    local currentKey = queue[index]
    index = index + 1

    local current = MoversByKey[currentKey]
    local peers = SmartSnapLinks[currentKey]
    if peers then
      for peerKey, link in pairs(peers) do
        local peer = MoversByKey[peerKey]
        if link.syncSize == true
          and not visited[peerKey]
          and SmartSnapCanSyncSize(current, peer)
        then
          visited[peerKey] = true

          if IsSmartSnapRuntimeEntryActive(peer) and SmartSnapAllowsSizeSync(peer) then
            CopySmartSnapSize(peer, sourceEntry, link.relation, true, false)
            affected[peer] = true
          end

          queue[#queue + 1] = peerKey
        end
      end
    end
  end

  return affected
end

local function ApplySmartSnapRuntimePosition(entry)
  if type(entry.savePosition) == "function" then
    entry.savePosition(entry.frame, entry.key)
  end
end

local function BuildSmartSnapLayoutSteps(layoutRoot)
  local visited = { [layoutRoot.key] = true }
  local queue = { layoutRoot }
  local index = 1
  local layoutSteps = {}

  while queue[index] do
    local current = queue[index]
    index = index + 1

    for _, relation in ipairs(SMART_SNAP_RELATION_ORDER) do
      for _, link in ipairs(GetNextActiveSmartSnapPeers(current.key, relation)) do
        local peer = link.entry
        if peer and not visited[peer.key] then
          visited[peer.key] = true
          layoutSteps[#layoutSteps + 1] = {
            entry = peer,
            target = current,
            relation = link.relation,
            alignment = link.alignment,
            gap = link.gap,
            sideOffset = link.sideOffset,
          }
          queue[#queue + 1] = peer
        end
      end
    end
  end

  return layoutSteps
end

local function RelayoutSmartSnapCluster(startEntry, finalize, syncSize)
  if FrameUtil._profileTransitionActive == true or not startEntry or not startEntry.key then
    return
  end

  EnsureSmartSnapLoaded()

  if InCombatLockdown() then
    local shouldFinalize = finalize ~= false
    if shouldFinalize or PendingSmartSnapRelayouts[startEntry.key] == nil then
      PendingSmartSnapRelayouts[startEntry.key] = shouldFinalize
    end
    return
  end

  local layoutRoot, pinnedRoot = GetStableSmartSnapRoot(startEntry.key)
  if not layoutRoot then
    return
  end

  local pinnedX
  local pinnedY
  if pinnedRoot then
    pinnedX, pinnedY = GetRawOffsetsForFrame(layoutRoot.frame)
  end

  FrameUtil._smartSnapApplying = true

  local moved = syncSize == false and {} or ApplySmartSnapSizeSync(GetSmartSnapSizeSource(startEntry))
  if pinnedRoot then
    moved[layoutRoot] = nil
    MoveEntryTo(layoutRoot, pinnedX, pinnedY, true)
  else
    moved[layoutRoot] = true
  end

  local layoutSteps = BuildSmartSnapLayoutSteps(layoutRoot)

  for _, step in ipairs(layoutSteps) do
    moved[step.entry] = true
    PositionSmartSnapEntry(
      step.entry,
      step.target,
      step.relation,
      step.alignment,
      step.gap,
      step.sideOffset
    )
  end

  FrameUtil._smartSnapApplying = false

  if not finalize then
    for entry in pairs(moved) do
      ApplySmartSnapRuntimePosition(entry)
    end
  end

  for entry in pairs(moved) do
    entry._smartSnapState = CaptureSmartSnapState(entry)
  end
  if pinnedRoot then
    layoutRoot._smartSnapState = CaptureSmartSnapState(layoutRoot)
  end

  if finalize then
    local finalizePrimary = startEntry ~= layoutRoot and moved[startEntry] and startEntry or nil
    FrameUtil._FinalizeMovedGroup(moved, finalizePrimary)
  end
end

function FrameUtil.RelayoutSmartSnapCluster(key, finalize)
  if not key then
    return
  end

  EnsureSmartSnapLoaded()

  local entry = MoversByKey[key] or GetStableSmartSnapRoot(key)
  if entry then
    RelayoutSmartSnapCluster(entry, finalize ~= false)
  end
end

local function FlushPendingSmartSnapRelayouts(allowStartup)
  FrameUtil._smartSnapRuntimeRelayoutScheduled = false

  if InCombatLockdown() then
    return
  end

  local startup = allowStartup == true and not FrameUtil._smartSnapWorldReady
  if (not startup and not FrameUtil._smartSnapWorldReady)
    or (not next(PendingSmartSnapRelayouts) and not next(PendingSmartSnapRuntimeRelayouts))
  then
    return
  end

  local roots = {}
  for key, finalize in pairs(PendingSmartSnapRelayouts) do
    local root = GetStableSmartSnapRoot(key)
    if root then
      local current = roots[root.key]
      if not current or finalize == true then
        roots[root.key] = {
          finalize = finalize == true,
          syncSize = true,
        }
      end
    end
  end
  wipe(PendingSmartSnapRelayouts)

  for key in pairs(PendingSmartSnapRuntimeRelayouts) do
    local root = GetStableSmartSnapRoot(key)
    if root and not roots[root.key] then
      roots[root.key] = {
        finalize = false,
        syncSize = startup,
      }
    end
  end
  wipe(PendingSmartSnapRuntimeRelayouts)

  for rootKey, options in pairs(roots) do
    local root = MoversByKey[rootKey]
    if root then
      RelayoutSmartSnapCluster(root, options.finalize, options.syncSize)
    end
  end
end

local function SchedulePendingSmartSnapRelayouts()
  if FrameUtil._smartSnapRuntimeRelayoutScheduled
    or not FrameUtil._smartSnapWorldReady
    or InCombatLockdown()
  then
    return
  end

  FrameUtil._smartSnapRuntimeRelayoutScheduled = true
  _G.C_Timer.After(0, FlushPendingSmartSnapRelayouts)
end

function FrameUtil:CompleteStartupLayout()
  if self._smartSnapWorldReady then
    return true
  end

  if InCombatLockdown() then
    return false
  end

  FlushPendingSmartSnapRelayouts(true)

  for index = 1, #StartupLayoutParticipantOrder do
    local participant = StartupLayoutParticipants[StartupLayoutParticipantOrder[index]]
    if participant.prepare then
      participant.prepare()
    end
  end

  FlushPendingSmartSnapRelayouts(true)

  for index = 1, #StartupLayoutParticipantOrder do
    local participant = StartupLayoutParticipants[StartupLayoutParticipantOrder[index]]
    if participant.complete then
      participant.complete()
    end
  end

  wipe(StartupLayoutParticipants)
  wipe(StartupLayoutParticipantOrder)

  self._smartSnapWorldReady = true
  SchedulePendingSmartSnapRelayouts()
  return true
end

local function QueueSmartSnapRuntimeRelayout(key)
  if FrameUtil._profileTransitionActive == true or not key then
    return
  end

  PendingSmartSnapRuntimeRelayouts[key] = true
  if FrameUtil._smartSnapWorldReady then
    SchedulePendingSmartSnapRelayouts()
  end
end

function FrameUtil.RefreshSmartSnapRuntimeLayout(key)
  if not key then
    return
  end

  EnsureSmartSnapLoaded()

  if not MoversByKey[key] or not SmartSnapLinks[key] then
    return
  end

  QueueSmartSnapRuntimeRelayout(key)
end

local function PropagateSmartSnapDesign(startEntry)
  EnsureSmartSnapLoaded()

  local sourceOpts = GetSmartSnapOptions(startEntry)
  if not sourceOpts or type(sourceOpts.getDesign) ~= "function" then
    return
  end

  local design = sourceOpts.getDesign(startEntry.frame, startEntry.key)
  if type(design) ~= "table" then
    return
  end

  local visited = { [startEntry.key] = true }
  local queue = { startEntry.key }
  local index = 1

  FrameUtil._smartSnapApplying = true

  while queue[index] do
    local currentKey = queue[index]
    index = index + 1

    local current = MoversByKey[currentKey]
    local peers = SmartSnapLinks[currentKey]
    if peers then
      for peerKey, link in pairs(peers) do
        local peer = MoversByKey[peerKey]
        if link.syncDesign == true
          and not visited[peerKey]
          and SmartSnapCanSyncDesign(current, peer)
        then
          visited[peerKey] = true

          if IsSmartSnapRuntimeEntryActive(peer) then
            ApplySmartSnapDesign(peer, design, startEntry)
          end

          queue[#queue + 1] = peerKey
        end
      end
    end
  end

  FrameUtil._smartSnapApplying = false

  for key in pairs(visited) do
    local entry = MoversByKey[key]
    if entry then
      entry._smartSnapState = CaptureSmartSnapState(entry)
    end
  end
end

function FrameUtil.RefreshSmartSnapState(key)
  local entry = MoversByKey[key]
  if not entry or not GetSmartSnapOptions(entry) then
    return
  end

  local nextState = CaptureSmartSnapState(entry)
  local previousState = entry._smartSnapState
  entry._smartSnapState = nextState

  if FrameUtil._profileTransitionActive == true
    or FrameUtil._smartSnapApplying
    or not previousState
    or not SmartSnapLinks[key]
  then
    return
  end

  if not ValuesEqual(previousState.size, nextState.size) then
    RelayoutSmartSnapCluster(entry, true)
  end

  if not ValuesEqual(previousState.design, nextState.design) then
    PropagateSmartSnapDesign(entry)
  end
end

local function GetSmartSnapCompatibility(option)
  if option == "syncSize" then
    return SmartSnapCanSyncSize
  elseif option == "syncDesign" then
    return SmartSnapCanSyncDesign
  end
  return nil
end

local function GetSmartSnapCompatibleCluster(entry, compatibility)
  local cluster = {}
  if not entry or not entry.key or type(compatibility) ~= "function" then
    return cluster
  end

  local visited = {}
  local function AddKey(key)
    if not key or visited[key] then
      return
    end

    visited[key] = true
    local current = MoversByKey[key]
    if not current then
      return
    end

    cluster[current] = true

    for peerKey in pairs(SmartSnapLinks[key] or {}) do
      local peer = MoversByKey[peerKey]
      if peer and compatibility(current, peer) then
        AddKey(peerKey)
      end
    end
  end

  AddKey(entry.key)
  return cluster
end

local function GetSmartSnapGroupOption(entry, option)
  EnsureSmartSnapLoaded()

  local compatibility = GetSmartSnapCompatibility(option)
  if not entry or not entry.key or not compatibility then
    return false
  end

  local cluster = GetSmartSnapCompatibleCluster(entry, compatibility)
  local found = false

  for member in pairs(cluster) do
    local peers = SmartSnapLinks[member.key]
    if peers then
      for peerKey, link in pairs(peers) do
        local peer = MoversByKey[peerKey]
        if peer and cluster[peer] and compatibility(member, peer) then
          found = true
          if link[option] ~= true then
            return false
          end
        end
      end
    end
  end

  return found
end

local function SmartSnapGroupSupportsSize(entry)
  if not SmartSnapSupportsSize(GetSmartSnapOptions(entry)) then
    return false
  end

  local cluster = GetSmartSnapCompatibleCluster(entry, SmartSnapCanSyncSize)
  for member in pairs(cluster) do
    if member ~= entry then
      return true
    end
  end
  return false
end

local function SmartSnapGroupUsesWidthSync(entry)
  local cluster = GetSmartSnapCompatibleCluster(entry, SmartSnapCanSyncSize)
  local count = 0

  for member in pairs(cluster) do
    local opts = GetSmartSnapOptions(member)
    if SmartSnapSupportsSize(opts) then
      if opts.syncAxis ~= "WIDTH" then
        return false
      end
      count = count + 1
    end
  end

  return count > 1
end

local function SmartSnapGroupSupportsDesign(entry)
  local sourceOpts = GetSmartSnapOptions(entry)
  if not sourceOpts or type(sourceOpts.getDesign) ~= "function" then
    return false
  end

  local cluster = GetSmartSnapCompatibleCluster(entry, SmartSnapCanSyncDesign)
  for member in pairs(cluster) do
    if member ~= entry then
      local opts = GetSmartSnapOptions(member)
      if SmartSnapSharesSyncFamily(sourceOpts, opts)
        and type(opts.applyDesign) == "function"
      then
        return true
      end
    end
  end

  return false
end

local function SetSmartSnapOptionForCluster(entry, option, value)
  local compatibility = GetSmartSnapCompatibility(option)
  if not compatibility then
    return
  end

  local cluster = GetSmartSnapCompatibleCluster(entry, compatibility)
  for member in pairs(cluster) do
    local peers = SmartSnapLinks[member.key]
    if peers then
      for peerKey, link in pairs(peers) do
        local peer = MoversByKey[peerKey]
        if peer and cluster[peer] and compatibility(member, peer) then
          link[option] = value == true
        end
      end
    end
  end
end

function FrameUtil.SetSmartSnapGroupOptions(key, syncSize, syncDesign)
  if syncSize == nil and syncDesign == nil then
    return
  end

  local entry = MoversByKey[key]
  if not entry then
    return
  end

  EnsureSmartSnapLoaded()

  if syncSize ~= nil then
    SetSmartSnapOptionForCluster(entry, "syncSize", syncSize)
  end
  if syncDesign ~= nil then
    SetSmartSnapOptionForCluster(entry, "syncDesign", syncDesign)
  end
  PersistSmartSnapLinks()

  if syncSize == true then
    RelayoutSmartSnapCluster(entry, true)
  end
  if syncDesign == true then
    PropagateSmartSnapDesign(entry)
  end
end

function FrameUtil.GetSmartSnapLinkGap(firstKey, secondKey)
  EnsureSmartSnapLoaded()

  local link = firstKey
    and secondKey
    and SmartSnapLinks[firstKey]
    and SmartSnapLinks[firstKey][secondKey]
  return link and NormalizeSmartSnapGap(link.gap) or 0
end

function FrameUtil.SetSmartSnapLinkGap(firstKey, secondKey, gap, finalize)
  EnsureSmartSnapLoaded()

  local firstLink = firstKey
    and secondKey
    and SmartSnapLinks[firstKey]
    and SmartSnapLinks[firstKey][secondKey]
  local secondLink = firstKey
    and secondKey
    and SmartSnapLinks[secondKey]
    and SmartSnapLinks[secondKey][firstKey]
  if not firstLink or not secondLink then
    return
  end

  gap = NormalizeSmartSnapGap(gap)
  local changed = firstLink.gap ~= gap or secondLink.gap ~= gap
  local shouldFinalize = finalize ~= false

  if changed then
    firstLink.gap = gap
    secondLink.gap = gap
  end

  if shouldFinalize then
    PersistSmartSnapLinks()
  end

  local firstEntry = MoversByKey[firstKey]
  local secondEntry = MoversByKey[secondKey]
  if firstEntry and secondEntry and (changed or shouldFinalize) then
    RelayoutSmartSnapCluster(firstEntry, shouldFinalize, shouldFinalize)
  end
end

function FrameUtil.GetSmartSnapLinkSideOffset(firstKey, secondKey)
  EnsureSmartSnapLoaded()

  local link = firstKey
    and secondKey
    and SmartSnapLinks[secondKey]
    and SmartSnapLinks[secondKey][firstKey]
  return link and NormalizeSmartSnapSideOffset(link.sideOffset) or 0
end

function FrameUtil.SetSmartSnapLinkSideOffset(firstKey, secondKey, sideOffset, finalize)
  EnsureSmartSnapLoaded()

  local firstLink = firstKey
    and secondKey
    and SmartSnapLinks[firstKey]
    and SmartSnapLinks[firstKey][secondKey]
  local secondLink = firstKey
    and secondKey
    and SmartSnapLinks[secondKey]
    and SmartSnapLinks[secondKey][firstKey]
  if not firstLink or not secondLink then
    return
  end

  sideOffset = NormalizeSmartSnapSideOffset(sideOffset)
  local changed = firstLink.sideOffset ~= -sideOffset or secondLink.sideOffset ~= sideOffset
  local shouldFinalize = finalize ~= false

  if changed then
    firstLink.sideOffset = -sideOffset
    secondLink.sideOffset = sideOffset
  end

  if shouldFinalize then
    PersistSmartSnapLinks()
  end

  local firstEntry = MoversByKey[firstKey]
  local secondEntry = MoversByKey[secondKey]
  if firstEntry and secondEntry and (changed or shouldFinalize) then
    RelayoutSmartSnapCluster(firstEntry, shouldFinalize, shouldFinalize)
  end
end

local function EnsureSmartSnapHighlight()
  if FrameUtil._smartSnapHighlight then
    return FrameUtil._smartSnapHighlight
  end

  local highlight = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  highlight:SetFrameStrata("TOOLTIP")
  highlight:SetFrameLevel(1300)
  highlight:EnableMouse(false)
  highlight:Hide()

  ns.Theme.SetSquareBackdrop(highlight, {
    bg = { 0.10, 0.55, 1.00, 0.12 },
    border = { 0.20, 0.72, 1.00, 1.00 },
  }, math_max(2, ns.Theme.GetEdgeSize()))

  FrameUtil._smartSnapHighlight = highlight
  return highlight
end

local function EnsureSmartSnapPreview()
  if FrameUtil._smartSnapPreview then
    return FrameUtil._smartSnapPreview
  end

  local preview = CreateFrame("Frame", nil, UIParent)
  preview:SetFrameStrata("TOOLTIP")
  preview:SetFrameLevel(1299)
  preview:EnableMouse(false)
  preview:Hide()

  local fill = preview:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(preview)
  fill:SetTexture(LSM:Fetch("statusbar", "PUI Thin Stripes", true) or "Interface\\Buttons\\WHITE8x8")
  fill:SetVertexColor(0.20, 0.72, 1.00, 0.18)
  if fill.SetHorizTile then
    fill:SetHorizTile(true)
  end
  if fill.SetVertTile then
    fill:SetVertTile(true)
  end
  preview.fill = fill

  preview.dashes = {}
  for index = 1, 20 do
    local dash = preview:CreateTexture(nil, "OVERLAY")
    dash:SetColorTexture(0.20, 0.72, 1.00, 0.92)
    preview.dashes[index] = dash
  end

  FrameUtil._smartSnapPreview = preview
  return preview
end

local function LayoutSmartSnapPreview(preview, width, height)
  width = math_max(1, Round(width or 0))
  height = math_max(1, Round(height or 0))
  preview:SetSize(width, height)

  local inset = 2
  local borderThickness = 4
  local horizontalSegments = 6
  local verticalSegments = 4
  local horizontalGap = 4
  local verticalGap = 4
  local usableWidth = math_max(0, width - (inset * 2))
  local usableHeight = math_max(0, height - (inset * 2))
  local horizontalLength = math_max(
    8,
    Round((usableWidth - ((horizontalSegments - 1) * horizontalGap)) / horizontalSegments)
  )
  local verticalLength = math_max(
    8,
    Round((usableHeight - ((verticalSegments - 1) * verticalGap)) / verticalSegments)
  )

  for _, dash in ipairs(preview.dashes) do
    dash:Hide()
    dash:ClearAllPoints()
  end

  local dashIndex = 1

  for index = 1, horizontalSegments do
    local x = inset + ((index - 1) * (horizontalLength + horizontalGap))

    local topDash = preview.dashes[dashIndex]
    topDash:SetSize(horizontalLength, borderThickness)
    topDash:SetPoint("TOPLEFT", preview, "TOPLEFT", x, -inset)
    topDash:Show()
    dashIndex = dashIndex + 1

    local bottomDash = preview.dashes[dashIndex]
    bottomDash:SetSize(horizontalLength, borderThickness)
    bottomDash:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", x, inset)
    bottomDash:Show()
    dashIndex = dashIndex + 1
  end

  for index = 1, verticalSegments do
    local y = inset + ((index - 1) * (verticalLength + verticalGap))

    local leftDash = preview.dashes[dashIndex]
    leftDash:SetSize(borderThickness, verticalLength)
    leftDash:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", inset, y)
    leftDash:Show()
    dashIndex = dashIndex + 1

    local rightDash = preview.dashes[dashIndex]
    rightDash:SetSize(borderThickness, verticalLength)
    rightDash:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", -inset, y)
    rightDash:Show()
    dashIndex = dashIndex + 1
  end
end

local function ClearSmartSnapCandidate(entry)
  if entry then
    entry._smartSnapCandidate = nil
  end
  if FrameUtil._smartSnapHighlight then
    FrameUtil._smartSnapHighlight:Hide()
  end
  if FrameUtil._smartSnapPreview then
    FrameUtil._smartSnapPreview:Hide()
  end
end

local function GetNearestSmartSnapAlignment(entry, target, relation)
  local frameGeometry = GetSmartSnapGeometry(entry)
  local targetGeometry = GetSmartSnapGeometry(target)
  if not frameGeometry or not targetGeometry then
    return "CENTER"
  end

  local fl, fr, ft, fb = frameGeometry.left, frameGeometry.right, frameGeometry.top, frameGeometry.bottom
  local tl, tr, tt, tb = targetGeometry.left, targetGeometry.right, targetGeometry.top, targetGeometry.bottom

  if relation == "ABOVE" or relation == "BELOW" then
    local leftDistance = math_abs(fl - tl)
    local centerDistance = math_abs(((fl + fr) * 0.5) - ((tl + tr) * 0.5))
    local rightDistance = math_abs(fr - tr)

    if leftDistance <= centerDistance and leftDistance <= rightDistance then
      return "LEFT"
    elseif rightDistance <= centerDistance then
      return "RIGHT"
    end

    return "CENTER"
  end

  local topDistance = math_abs(ft - tt)
  local centerDistance = math_abs(((ft + fb) * 0.5) - ((tt + tb) * 0.5))
  local bottomDistance = math_abs(fb - tb)

  if topDistance <= centerDistance and topDistance <= bottomDistance then
    return "TOP"
  elseif bottomDistance <= centerDistance then
    return "BOTTOM"
  end

  return "CENTER"
end

local function FindSmartSnapCandidate(entry, ignoreEntries)
  if not FrameUtil._smartSnapEnabled or not entry then
    return nil
  end

  local frameGeometry = GetSmartSnapGeometry(entry)
  if not frameGeometry then
    return nil
  end

  local fl, fr, ft, fb = frameGeometry.left, frameGeometry.right, frameGeometry.top, frameGeometry.bottom

  local tolerance = FrameUtil._snapTolerance or 8
  local best
  local bestDistance

  local function Consider(other, relation, distance)
    local absoluteDistance = math_abs(distance)
    if absoluteDistance <= tolerance and (not bestDistance or absoluteDistance < bestDistance) then
      best = {
        target = other,
        relation = relation,
        alignment = GetNearestSmartSnapAlignment(entry, other, relation),
      }
      bestDistance = absoluteDistance
    end
  end

  for _, other in ipairs(MoversList) do
    if not (ignoreEntries and ignoreEntries[other]) and CanSmartSnap(entry, other) then
      local otherGeometry = GetSmartSnapGeometry(other)
      if otherGeometry then
        local ol, orr = otherGeometry.left, otherGeometry.right
        local ot, ob = otherGeometry.top, otherGeometry.bottom
        local verticalOverlap = math_min(ft, ot) - math_max(fb, ob)
        local horizontalOverlap = math_min(fr, orr) - math_max(fl, ol)

        if verticalOverlap > 0 then
          Consider(other, "LEFT", ol - fr)
          Consider(other, "RIGHT", orr - fl)
        end
        if horizontalOverlap > 0 then
          Consider(other, "ABOVE", ot - fb)
          Consider(other, "BELOW", ob - ft)
        end
      end
    end
  end

  return best
end

function FrameUtil.UpdateSmartSnapCandidate(entry, ignoreEntries)
  ClearSmartSnapCandidate(entry)

  local candidate = FindSmartSnapCandidate(entry, ignoreEntries)
  if not candidate then
    return false
  end

  entry._smartSnapCandidate = candidate
  local highlight = EnsureSmartSnapHighlight()
  local left, right, top, bottom = GetSmartSnapInsets(candidate.target)
  highlight:ClearAllPoints()
  highlight:SetPoint("TOPLEFT", candidate.target.frame, "TOPLEFT", -left - 3, top + 3)
  highlight:SetPoint("BOTTOMRIGHT", candidate.target.frame, "BOTTOMRIGHT", right + 3, -bottom - 3)
  highlight:Show()

  local previewX, previewY = GetSmartSnapPosition(
    entry,
    candidate.target,
    candidate.relation,
    candidate.alignment,
    0,
    0
  )
  if previewX ~= nil and previewY ~= nil then
    local preview = EnsureSmartSnapPreview()
    LayoutSmartSnapPreview(preview, entry.frame:GetWidth(), entry.frame:GetHeight())
    preview:ClearAllPoints()
    preview:SetPoint("CENTER", UIParent, "CENTER", previewX, previewY)
    preview:Show()
  end

  return true
end

function FrameUtil.CommitSmartSnapCandidate(entry)
  local candidate = entry and entry._smartSnapCandidate
  ClearSmartSnapCandidate(entry)
  if not candidate or not CanSmartSnap(entry, candidate.target) then
    return false
  end

  local target = candidate.target
  local smartSnap = GetSmartSnapOptions(entry)
  local targetSmartSnap = GetSmartSnapOptions(target)
  local targetHasLinks = SmartSnapLinks[target.key] ~= nil
  local canSyncSize = SmartSnapCanSyncSize(entry, target)
  local canSyncDesign = SmartSnapCanSyncDesign(entry, target)
  local syncSize = canSyncSize and (
    targetHasLinks
      and GetSmartSnapGroupOption(target, "syncSize")
      or ((smartSnap and smartSnap.defaultSyncSize == true)
        or (targetSmartSnap and targetSmartSnap.defaultSyncSize == true))
  ) or false
  local syncDesign = canSyncDesign
    and targetHasLinks
    and GetSmartSnapGroupOption(target, "syncDesign")
    or false

  local occupiedPeerKey
  local occupiedLink
  local targetPeers = SmartSnapLinks[target.key]
  if targetPeers then
    for peerKey, link in pairs(targetPeers) do
      if link.relation == candidate.relation
        and link.alignment == candidate.alignment
      then
        occupiedPeerKey = peerKey
        occupiedLink = link
        break
      end
    end
  end

  if occupiedPeerKey then
    RemoveSmartSnapLink(target.key, occupiedPeerKey)
  end

  SetSmartSnapLink(entry.key, target.key, candidate.relation, candidate.alignment, syncSize, syncDesign)

  if occupiedPeerKey and occupiedLink then
    SetSmartSnapLink(
      occupiedPeerKey,
      entry.key,
      candidate.relation,
      occupiedLink.alignment or "CENTER",
      occupiedLink.syncSize == true,
      occupiedLink.syncDesign == true,
      occupiedLink.gap,
      occupiedLink.sideOffset
    )
  end

  SetSmartSnapClusterMaster(target.key, target.key)

  FrameUtil._smartSnapApplying = true
  CopySmartSnapSize(entry, target, candidate.relation, syncSize, true)
  FrameUtil._smartSnapApplying = false

  RelayoutSmartSnapCluster(target, true)
  return true
end

function FrameUtil.GetMoverEntry(key)
  return key and MoversByKey[key] or nil
end

function FrameUtil.GetMoverKeyForAnchor(anchor)
  if not anchor then
    return nil
  end

  for _, entry in ipairs(MoversList) do
    if entry.frame == anchor
      or entry.overlay == anchor
      or entry.chrome == anchor
    then
      return entry.key
    end
  end

  return nil
end

function FrameUtil.BeginExternalSmartSnapDrag(key, breakSnap)
  local entry = key and MoversByKey[key]
  if not entry or InCombatLockdown() or not IsSmartSnapRuntimeEntryActive(entry) then
    return nil
  end

  local history = FrameUtil.BeginEditHistory("Move " .. entry.label)
  EnsureSmartSnapLoaded()
  local snapBefore = CopyValue(GetSmartSnapDB())

  local suppressSnap = breakSnap == true
  if suppressSnap then
    FrameUtil.ClearSmartSnapForKey(key)
  end

  local group = GetSmartSnapCluster(entry)
  group[entry] = true

  local start = {}
  for member in pairs(group) do
    if member.frame then
      local x, y = GetOffsetsForFrame(member.frame)
      start[member] = { x = x, y = y }
    end
  end

  return {
    key = key,
    entry = entry,
    group = group,
    start = start,
    suppressSnap = suppressSnap,
    history = history,
    snapBefore = snapBefore,
  }
end

function FrameUtil.UpdateExternalSmartSnapDrag(state, deltaX, deltaY)
  if not state or not state.entry then
    return
  end

  deltaX = tonumber(deltaX) or 0
  deltaY = tonumber(deltaY) or 0

  for member, point in pairs(state.start or {}) do
    if member.frame then
      MoveEntryTo(member, point.x + deltaX, point.y + deltaY, true)
    end
  end

  if state.suppressSnap then
    ClearSmartSnapCandidate(state.entry)
  else
    FrameUtil.UpdateSmartSnapCandidate(state.entry, state.group)
  end
end

function FrameUtil.FinishExternalSmartSnapDrag(state)
  if not state or not state.entry or InCombatLockdown() then
    return false
  end

  local committed = false
  if state.suppressSnap then
    ClearSmartSnapCandidate(state.entry)
  else
    committed = FrameUtil.CommitSmartSnapCandidate(state.entry)
  end

  if not committed then
    FrameUtil._FinalizeMovedGroup(state.group or { [state.entry] = true }, state.entry)
  end

  FrameUtil.CommitEditHistory(state.history)
  return committed
end

function FrameUtil.CancelExternalSmartSnapDrag(state)
  if not state or not state.entry then
    return false
  end

  ClearSmartSnapCandidate(state.entry)

  if InCombatLockdown() then
    return false
  end

  local history = FrameUtil._editHistory
  if state.history and state.history == history.pending then
    local changed = FrameUtil.CaptureEditHistoryState(state.history.before)
    history.pending = nil
    history.replaying = true
    FrameUtil.RestoreEditHistoryState(state.history.before, changed)
    history.replaying = nil
    ns.TestMode:RefreshEditControlButtons()
    return true
  end

  local snap = GetSmartSnapDB()
  ApplyEditHistoryDelta(snap, state.snapBefore, CopyValue(snap))
  FrameUtil._smartSnapLoaded = false
  EnsureSmartSnapLoaded()

  for member, point in pairs(state.start or {}) do
    if member.frame then
      MoveEntryTo(member, point.x, point.y, true)
    end
  end

  return true
end

local SmartSnapQuickSettingsExpanded = {}

function FrameUtil.AugmentSmartSnapQuickSettings(entry, spec)
  EnsureSmartSnapLoaded()
  if not entry then
    return spec
  end

  local smartSnap = GetSmartSnapOptions(entry)
  local hasLinks = SmartSnapLinks[entry.key] ~= nil
  local supportsLocalWidthSync = SmartSnapSupportsSize(smartSnap)
    and smartSnap.syncAxis == "WIDTH"

  if not hasLinks and not supportsLocalWidthSync then
    return spec
  end

  spec = type(spec) == "table" and spec or {
    ownerKey = entry.key,
    title = entry.label or entry.key,
    description = "Mover settings.",
    controls = {},
  }
  spec.controls = spec.controls or {}

  local supportsSize = hasLinks and SmartSnapGroupSupportsSize(entry)
  local supportsDesign = hasLinks and SmartSnapGroupSupportsDesign(entry)
  local widthSync = supportsSize and SmartSnapGroupUsesWidthSync(entry)
  local designLabel = smartSnap and smartSnap.syncDesignLabel or "Sync visuals"

  local expanded = SmartSnapQuickSettingsExpanded[entry.key] == true
  spec.controls[#spec.controls + 1] = {
    type = "button",
    label = expanded and "Smart Snap  [-]" or "Smart Snap  [+]",
    action = function()
      SmartSnapQuickSettingsExpanded[entry.key] = not expanded
      local panel = ns.EditModeQuickSettings.panel
      if panel and panel:IsShown() then
        ns.EditModeQuickSettings:Refresh(panel.ownerKey, panel.anchor, function()
          return FrameUtil.GetMoverQuickSettingsSpec(entry, entry.frame)
        end)
      end
    end,
  }
  if not expanded then
    return spec
  end

  if hasLinks then
    spec.controls[#spec.controls + 1] = {
      type = "description",
      text = "Snapped frames move together. Gap moves them toward or away from the snapped edge; side offset moves them along it. Shift-click detaches; Shift-drag detaches and disables snapping for that drag.",
    }

    local linkedMovers = {}
    for peerKey in pairs(SmartSnapLinks[entry.key]) do
      local peer = MoversByKey[peerKey]
      if peer then
        linkedMovers[#linkedMovers + 1] = {
          key = peerKey,
          label = peer.label or peerKey,
        }
      end
    end
    _G.table.sort(linkedMovers, function(first, second)
      return tostring(first.label) < tostring(second.label)
    end)

    for _, linkedMover in ipairs(linkedMovers) do
      local peerKey = linkedMover.key
      spec.controls[#spec.controls + 1] = {
        type = "slider",
        label = "Gap to " .. tostring(linkedMover.label),
        min = -SMART_SNAP_GAP_MAX,
        max = SMART_SNAP_GAP_MAX,
        step = 1,
        commitOnRelease = true,
        get = function()
          return FrameUtil.GetSmartSnapLinkGap(entry.key, peerKey)
        end,
        liveSet = function(value)
          FrameUtil.SetSmartSnapLinkGap(entry.key, peerKey, value, false)
        end,
        set = function(value)
          FrameUtil.SetSmartSnapLinkGap(entry.key, peerKey, value, true)
        end,
      }

      spec.controls[#spec.controls + 1] = {
        type = "slider",
        label = "Side offset from " .. tostring(linkedMover.label),
        min = -SMART_SNAP_SIDE_OFFSET_MAX,
        max = SMART_SNAP_SIDE_OFFSET_MAX,
        step = 1,
        commitOnRelease = true,
        get = function()
          return FrameUtil.GetSmartSnapLinkSideOffset(entry.key, peerKey)
        end,
        liveSet = function(value)
          FrameUtil.SetSmartSnapLinkSideOffset(entry.key, peerKey, value, false)
        end,
        set = function(value)
          FrameUtil.SetSmartSnapLinkSideOffset(entry.key, peerKey, value, true)
        end,
      }
    end
  end

  if supportsLocalWidthSync then
    spec.controls[#spec.controls + 1] = {
      type = "toggle",
      label = "Allow width sync",
      get = function()
        return FrameUtil.GetSmartSnapWidthSyncAllowed(entry.key)
      end,
      set = function(value)
        FrameUtil.SetSmartSnapWidthSyncAllowed(entry.key, value)
      end,
    }
  end

  if supportsSize and smartSnap.relationSizeSync ~= true then
    spec.controls[#spec.controls + 1] = {
      type = "toggle",
      label = widthSync and "Sync width" or "Sync size",
      get = function()
        return GetSmartSnapGroupOption(entry, "syncSize")
      end,
      set = function(value)
        FrameUtil.SetSmartSnapGroupOptions(entry.key, value, nil)
      end,
    }
  end

  if supportsDesign then
    spec.controls[#spec.controls + 1] = {
      type = "toggle",
      label = designLabel,
      get = function()
        return GetSmartSnapGroupOption(entry, "syncDesign")
      end,
      set = function(value)
        FrameUtil.SetSmartSnapGroupOptions(entry.key, nil, value)
      end,
    }
  end

  if hasLinks then
    spec.controls[#spec.controls + 1] = {
      type = "button",
      label = "Detach",
      action = function()
        FrameUtil.ClearSmartSnapForKey(entry.key)
        ns.EditModeQuickSettings:Hide()
      end,
    }
  end

  return spec
end

local function SetMoverEditSessionHidden(entry, hidden)
  if not entry then
    return false
  end

  hidden = hidden == true
  if hidden == (entry._editSessionHidden == true) then
    return false
  end

  entry._editSessionHidden = hidden and true or nil

  local frame = entry.frame
  if frame and frame.__puiEditMoverHelper then
    if hidden then
      entry._editSessionHelperAlpha = frame:GetAlpha()
      frame:SetAlpha(0)
    elseif entry._editSessionHelperAlpha ~= nil then
      frame:SetAlpha(entry._editSessionHelperAlpha)
      entry._editSessionHelperAlpha = nil
    end
  end

  return true
end

local function RefreshMoverEditSessionVisibility(entry)
  if not entry then
    return false
  end

  local visible = ns.Flags.IsEditing
    and not entry._suppressed
    and not entry._editSessionHidden
    and not entry._presetHidden

  if entry.frame.__puiHeaderMoverHelper then
    visible = visible and entry.frame.__puiEditMoverAvailable == true
  end

  if entry._ghostManaged then
    visible = visible and entry._ghostVisible and true or false
  end

  ShowOverlay(entry, visible)
  EnableDrag(entry, visible)

  if entry.frame and entry.frame.__puiEditMoverHelper then
    FrameUtil.SetMoverFrameVisible(entry.frame, visible, true)
  end

  if not visible and entry.nudgeGroup then
    entry.nudgeGroup:Hide()
  end

  local previewVisible = ns.Flags.IsEditing == true and FrameUtil.IsMoverPreviewVisible(entry.key)
  if entry._previewVisible ~= previewVisible then
    local wasInitialized = entry._previewVisible ~= nil
    entry._previewVisible = previewVisible
    local callback = entry.opts.onPreviewVisibilityChanged
    if type(callback) == "function" and (wasInitialized or ns.Flags.IsEditing) then
      callback(previewVisible, entry.frame, entry.key)
    end
    if ns.TestMode:IsActive() then
      ns.TestMode:QueuePreviewRefresh()
    end
  end

  return visible
end

function FrameUtil.ApplyMoverVisibilityPreset()
  for _, entry in ipairs(MoversList) do
    entry._presetHidden = not FrameUtil.IsMoverVisibleInPreset(entry)
    local visible = RefreshMoverEditSessionVisibility(entry)
    if not visible then
      ClearSmartSnapCandidate(entry)
      if FrameUtil._IsMoverSelected(entry) then
        FrameUtil._RemoveMoverSelection(entry)
      end
    end
  end

  if ns.Flags.IsEditing then
    ns.EditModeQuickSettings:Hide()
    FrameUtil._RefreshSelectionVisuals()
    ns.TestMode:QueuePreviewRefresh()
    ns.TestMode:QueueToolbarRefresh()
  end
end

function FrameUtil.HideMoverForEditSession(key)
  local entry = MoversByKey[key]
  if not entry or not ns.Flags.IsEditing then
    return
  end

  if not SetMoverEditSessionHidden(entry, true) then
    return
  end

  ClearSmartSnapCandidate(entry)
  RefreshMoverEditSessionVisibility(entry)

  if FrameUtil._IsMoverSelected(entry) then
    FrameUtil._RemoveMoverSelection(entry)
  end

  ns.TestMode:RefreshEditControlButtons()
  ns.EditModeQuickSettings:Hide()
end

function FrameUtil.HideSelectedMoversForEditSession()
  if not ns.Flags.IsEditing then
    return
  end

  local keys = {}
  for entry in pairs(SelectedEntries) do
    keys[#keys + 1] = entry.key
  end

  for _, key in ipairs(keys) do
    FrameUtil.HideMoverForEditSession(key)
  end
end

function FrameUtil.HideUnselectedMoversForEditSession()
  if not ns.Flags.IsEditing or not next(SelectedEntries) then
    return
  end

  for _, entry in ipairs(MoversList) do
    local hidden = SelectedEntries[entry] ~= true

    if SetMoverEditSessionHidden(entry, hidden) and hidden then
      ClearSmartSnapCandidate(entry)
    end

    RefreshMoverEditSessionVisibility(entry)
  end

  FrameUtil._RefreshSelectionVisuals()
end

function FrameUtil.ShowAllMoversForEditSession()
  if not ns.Flags.IsEditing then
    return
  end

  for _, entry in ipairs(MoversList) do
    SetMoverEditSessionHidden(entry, false)
    RefreshMoverEditSessionVisibility(entry)
  end

  FrameUtil._RefreshSelectionVisuals()
end

function FrameUtil.SetMoverSuppressed(key, suppressed)
  local entry = MoversByKey[key]
  if not entry then
    return
  end

  entry._suppressed = suppressed == true or nil
  local visible = RefreshMoverEditSessionVisibility(entry)

  if not visible and FrameUtil._IsMoverSelected(entry) then
    FrameUtil._RemoveMoverSelection(entry)
  end
end

function FrameUtil.SetSmartSnapEnabled(enabled)
  FrameUtil._smartSnapEnabled = enabled == true
  FrameUtil._GetEditModeDB().smartSnapEnabled = FrameUtil._smartSnapEnabled
end

local function IsSelectableEntry(entry)
  if not entry
    or not entry.frame
    or entry._editSessionHidden
    or entry._presetHidden
    or entry._suppressed
  then
    return false
  end

  if entry.opts and entry.opts.ghost then
    return false
  end

  if not entry.frame:IsShown()
     and not (ns.Flags.IsEditing and entry.overlay and entry.overlay:IsShown()) then
    return false
  end

  return true
end

function FrameUtil._GetSelectedMoverCount()
  local count = 0

  for entry in pairs(SelectedEntries) do
    if IsSelectableEntry(entry) then
      count = count + 1
    end
  end

  return count
end

local function RefreshMoverPresentation(entry)
  local visual = entry.chrome or entry.overlay
  if not visual then return end
  local active = SelectedEntries[entry] or entry._editHovered
  if entry == SelectedEntry then
    SetEditModeVisualColors(visual, 0.38, 1.00)
  elseif SelectedEntries[entry] then
    SetEditModeVisualColors(visual, 0.28, 1.00)
  elseif entry._editHovered then
    SetEditModeVisualColors(visual, 0.22, 1.00)
  elseif FrameUtil._compactMovers then
    SetEditModeVisualColors(visual, 0.05, 0.35)
  else
    SetEditModeVisualColors(visual, 0.16, 0.82)
  end
  entry.overlay._labelFS:SetAlpha(FrameUtil._compactMovers and not active and 0.28 or 1)
end

function FrameUtil._RefreshSelectionVisuals()
  for _, entry in ipairs(MoversList) do
    if SelectedEntries[entry] and not IsSelectableEntry(entry) then
      SelectedEntries[entry] = nil
    end
  end

  if not SelectedEntries[SelectedEntry] or not IsSelectableEntry(SelectedEntry) then
    SelectedEntry = nil

    for _, entry in ipairs(MoversList) do
      if SelectedEntries[entry] and IsSelectableEntry(entry) then
        SelectedEntry = entry
        break
      end
    end
  end

  for _, entry in ipairs(MoversList) do
    RefreshMoverPresentation(entry)

    if entry.nudgeGroup and entry ~= SelectedEntry then
      entry.nudgeGroup:Hide()
    end
  end

  if SelectedEntry then
    FrameUtil._ShowNudgeControls(SelectedEntry, true)
  end

  FrameUtil._UpdateNudgeUI(SelectedEntry)

  FrameUtil.RefreshMoverLayering()
  ns.TestMode:RefreshEditControlButtons()
end

local function AddEntryToMoveGroup(group, entry, includeSmartSnap)
  if not IsSelectableEntry(entry) then
    return
  end

  group[entry] = true

  if includeSmartSnap then
    local cluster = GetSmartSnapCluster(entry)
    for peer in pairs(cluster) do
      if peer.frame
        and not peer._suppressed
        and not peer._presetHidden
        and IsSmartSnapRuntimeEntryActive(peer)
        and (
          peer._editSessionHidden
          or peer.frame:IsShown()
          or (ns.Flags.IsEditing and peer.overlay and peer.overlay:IsShown())
        )
      then
        group[peer] = true
      end
    end
  end
end

function FrameUtil._GetSelectedMoveGroup(primary, includeSmartSnap)
  local group = {}

  if SelectedEntries[primary] then
    for entry in pairs(SelectedEntries) do
      AddEntryToMoveGroup(group, entry, includeSmartSnap)
    end
  else
    AddEntryToMoveGroup(group, primary, includeSmartSnap)
  end

  return group
end

function FrameUtil._FinalizeMovedGroup(group, primary)
  if not group then
    return
  end

  if primary and group[primary] then
    FinalizeEntryMove(primary)
  end

  for entry in pairs(group) do
    if entry ~= primary then
      FinalizeEntryMove(entry)
    end
  end
end

function FrameUtil._MoveGroupBy(group, dx, dy, primary)
  if not group then
    return
  end

  local history = FrameUtil.BeginEditHistory("Move " .. (primary and primary.label or "movers"))
  dx = dx or 0
  dy = dy or 0

  for entry in pairs(group) do
    local x, y = GetRawOffsetsForFrame(entry.frame)
    MoveEntryTo(entry, x + dx, y + dy, true)
  end

  FrameUtil._FinalizeMovedGroup(group, primary)
  FrameUtil.CommitEditHistory(history)
end

FrameUtil._IsMoverSelected = function(entry)
  return SelectedEntries[entry] == true
end

function FrameUtil.RefreshTheme()
  local textColor = ns.Theme.GetColors().text

  for _, entry in ipairs(MoversList) do
    if entry.overlay and entry.overlay._labelFS then
      entry.overlay._labelFS:SetTextColor(
        textColor[1],
        textColor[2],
        textColor[3],
        textColor[4]
      )
    end

    if entry.frame and entry.frame.__puiHeaderMoverHelper then
      ApplyHeaderMoverTheme(
        entry.frame,
        entry.opts and entry.opts.overlayBelowFrame == true
      )
    end
  end

  if FrameUtil._selectionBox then
    SetEditModeVisualColors(FrameUtil._selectionBox, 0.18, 0.95)
  end

  FrameUtil._RefreshSelectionVisuals()
end

local function GetCursorUIPosition()
  local x, y = _G.GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()

  if not scale or scale <= 0 then
    scale = 1
  end

  return x / scale, y / scale
end

local function ApplyBoxSelection(left, right, bottom, top, additive)
  if not additive then
    wipe(SelectedEntries)
    SelectedEntry = nil
  end

  local primary = additive and SelectedEntry or nil

  for _, entry in ipairs(MoversList) do
    if IsSelectableEntry(entry) then
      local frameLeft, frameRight, frameTop, frameBottom = GetFrameEdges(entry.frame)
      if frameLeft
         and frameRight >= left
         and frameLeft <= right
         and frameTop >= bottom
         and frameBottom <= top then
        SelectedEntries[entry] = true
        primary = primary or entry
      end
    end
  end

  SelectedEntry = primary
  FrameUtil._RefreshSelectionVisuals()
end

local function EnsureSelectionSurface()
  if FrameUtil._selectionSurface then
    return FrameUtil._selectionSurface
  end

  local surface = CreateFrame("Frame", "PUI_EditModeSelectionSurface", UIParent)
  FrameUtil._selectionSurface = surface

  surface:SetAllPoints(UIParent)
  surface:SetFrameStrata("HIGH")
  surface:SetFrameLevel(0)
  surface:EnableMouse(true)
  surface:Hide()

  local box = CreateFrame("Frame", "PUI_EditModeSelectionBox", UIParent, "BackdropTemplate")
  FrameUtil._selectionBox = box

  box:SetFrameStrata(GetMoverChromeStrata())
  box:SetFrameLevel(1200)
  box:EnableMouse(false)
  box:SetBackdrop({
    bgFile = "Interface/ChatFrame/ChatFrameBackground",
    edgeFile = "Interface/ChatFrame/ChatFrameBackground",
    edgeSize = 1,
  })
  SetEditModeVisualColors(box, 0.18, 0.95)
  box:Hide()

  local function StopSelection(self, apply)
    if self._selecting and apply then
      if self._moved then
        local left = math_min(self._startX, self._currentX)
        local right = math_max(self._startX, self._currentX)
        local bottom = math_min(self._startY, self._currentY)
        local top = math_max(self._startY, self._currentY)

        ApplyBoxSelection(left, right, bottom, top, self._additive)
      elseif not self._additive then
        FrameUtil._ClearSelection()
      end
    end

    self:SetScript("OnUpdate", nil)
    self._selecting = nil
    self._startX = nil
    self._startY = nil
    self._currentX = nil
    self._currentY = nil
    self._additive = nil
    self._moved = nil

    box:Hide()
  end

  surface:SetScript("OnMouseDown", function(self, button)
    if ns.Flags.IsEditing and (button == "LeftButton" or button == "RightButton") then
      ns.EditModeQuickSettings:Hide()
    end

    if button ~= "LeftButton"
       or not ns.Flags.IsEditing
       or InCombatLockdown() then
      return
    end

    local x, y = GetCursorUIPosition()

    self._selecting = true
    self._startX = x
    self._startY = y
    self._currentX = x
    self._currentY = y
    self._additive = IsControlKeyDown() and true or false
    self._moved = false

    self:SetScript("OnUpdate", function(selectionSurface)
      if not ns.Flags.IsEditing then
        StopSelection(selectionSurface, false)
        return
      end

      local currentX, currentY = GetCursorUIPosition()
      selectionSurface._currentX = currentX
      selectionSurface._currentY = currentY

      local dx = currentX - (selectionSurface._startX or currentX)
      local dy = currentY - (selectionSurface._startY or currentY)

      if not selectionSurface._moved
         and (math_abs(dx) >= 4 or math_abs(dy) >= 4) then
        selectionSurface._moved = true
        box:Show()
      end

      if selectionSurface._moved then
        local left = math_min(selectionSurface._startX, currentX)
        local right = math_max(selectionSurface._startX, currentX)
        local bottom = math_min(selectionSurface._startY, currentY)
        local top = math_max(selectionSurface._startY, currentY)

        box:ClearAllPoints()
        box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        box:SetSize(math_max(1, right - left), math_max(1, top - bottom))
      end
    end)
  end)

  surface:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
      StopSelection(self, true)
    end
  end)

  surface:SetScript("OnHide", function(self)
    StopSelection(self, false)
  end)

  return surface
end


function FrameUtil._UpdateEditDialogKeyboardState()
  local panel = ns.TestMode.toolbar
  if panel and not InCombatLockdown() then
    panel:EnableKeyboard(ns.Flags.IsEditing == true)
  end
end

function FrameUtil.HandleEditModeKeyDown(key)
  if not ns.Flags.IsEditing or InCombatLockdown() then return false end
  if _G.GetCurrentKeyBoardFocus() then return false end
  if IsControlKeyDown() and (key == "Z" or key == "Y") then
    FrameUtil.ReplayEditHistory(key == "Y" or IsShiftKeyDown())
    return true
  end
  if not FrameUtil._keyboardMoveEnabled then
    return
  end
  if key == "1" or key == "2" or key == "3"
    or key == "4" or key == "5" or key == "6"
    or key == "7" or key == "8" or key == "9"
  then
    FrameUtil._SetNudgeStepFromSlider(tonumber(key))
  elseif key == "TAB" then
    FrameUtil._SelectNextMover(not IsShiftKeyDown())
  elseif key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT" then
    local step = FrameUtil._nudgeStep or NUDGE_DEFAULT
    if not SelectedEntry then
      FrameUtil._SelectNextMover(true)
    end
    if key == "UP" then
      FrameUtil._NudgeSelected(0, step)
    elseif key == "DOWN" then
      FrameUtil._NudgeSelected(0, -step)
    elseif key == "LEFT" then
      FrameUtil._NudgeSelected(-step, 0)
    else
      FrameUtil._NudgeSelected(step, 0)
    end
  end
end

function FrameUtil.EnsureEditCoordinates()
  if FrameUtil._coordinatePanel then
    return FrameUtil._coordinatePanel
  end

  local AceGUI = _G.LibStub("AceGUI-3.0")
  local popup = CreateFrame("Frame", "PUI_EditModeSelectionFrame", UIParent, "BackdropTemplate")
  FrameUtil._coordinatePanel = popup
  popup:SetSize(Round(300), 84)
  popup:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
  popup:SetFrameStrata("FULLSCREEN_DIALOG")
  popup:SetClampedToScreen(true)
  popup:SetMovable(true)
  popup:EnableMouse(true)
  popup:RegisterForDrag("LeftButton")
  popup:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then
      self:StartMoving()
    end
  end)
  popup:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if x and y and cx and cy then
      local db = FrameUtil._GetEditModeDB()
      db.coordinates = { x = x - cx, y = y - cy }
      self:ClearAllPoints()
      self:SetPoint("CENTER", UIParent, "CENTER", db.coordinates.x, db.coordinates.y)
    end
  end)
  ns.Theme.WidgetSkins.Frame(popup)

  local label = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -10)
  label:SetJustifyH("LEFT")
  label:SetText("Selected: none")
  FrameUtil.ApplyGlobalEditFont(label, 12, nil)
  FrameUtil._selectedLabel = label

  local function AddCoordinate(labelText, xOffset)
    local box = AceGUI:Create("PUI_EditBox")
    box:SetLabel("")
    box:SetWidth(100)
    box:SetCallback("OnEnterPressed", FrameUtil._ApplyNudgeFromInputs)
    box.frame:SetParent(popup)
    box.frame:ClearAllPoints()
    box.frame:SetPoint("TOPRIGHT", popup, "TOPRIGHT", xOffset, -32)
    box.frame:Show()
    ns.AceHooks.TakeOwnership(box)
    local caption = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    caption:SetPoint("RIGHT", box.frame, "LEFT", -6, 0)
    caption:SetText(labelText)
    FrameUtil.ApplyGlobalEditFont(caption, 12, nil)
    return box
  end
  FrameUtil._nudgeXInput = AddCoordinate("X", -164)
  FrameUtil._nudgeYInput = AddCoordinate("Y", -16)
  popup:Hide()
  return popup
end

local function ShowEditDialog(show)
  if not show then
    if FrameUtil._coordinatePanel then
      FrameUtil._coordinatePanel:Hide()
    end
    return
  end
  local popup = FrameUtil.EnsureEditCoordinates()
  local db = FrameUtil._GetEditModeDB()
  if FrameUtil._coordinateProfile ~= db then
    FrameUtil._coordinateProfile = db
    local saved = db.coordinates or {}
    popup:ClearAllPoints()
    popup:SetPoint("CENTER", UIParent, "CENTER", saved.x or 0, saved.y or 160)
  end
  FrameUtil._UpdateNudgeUI(SelectedEntry)
end

function FrameUtil.SetEditDimmingDisabled(disabled)
  FrameUtil._disableDimming = disabled == true
  FrameUtil._GetEditModeDB().disableDimming = FrameUtil._disableDimming
  if ns.Flags.IsEditing then
    if FrameUtil._disableDimming then
      PlayDimmerFade(false)
    else
      PlayDimmerFade(true)
    end
  end
end

function FrameUtil.SetEditDimAlpha(value)
  local alpha = tonumber(value) or 0.7
  FrameUtil._dimAlpha = math_min(1, math_max(0, alpha))
  FrameUtil._GetEditModeDB().dimAlpha = FrameUtil._dimAlpha
  FrameUtil._RefreshDimmerAlpha()
end

function FrameUtil.SetCompactMovers(enabled)
  FrameUtil._compactMovers = enabled == true
  FrameUtil._GetEditModeDB().compactMovers = FrameUtil._compactMovers
  FrameUtil._RefreshSelectionVisuals()
end

function FrameUtil.SetEditFrameSnap(enabled)
  FrameUtil._snapToFrame = enabled == true
  FrameUtil._GetEditModeDB().snapToFrame = FrameUtil._snapToFrame
  if not FrameUtil._snapToFrame then ClearFrameSnapFeedback() end
end

function FrameUtil.SetEditGridSnap(enabled)
  FrameUtil._snapToGrid = enabled == true
  FrameUtil._GetEditModeDB().snapToGrid = FrameUtil._snapToGrid
end

function FrameUtil.GetEditSessionHiddenMoverCount()
  local count = 0
  for _, entry in ipairs(MoversList) do
    if entry._editSessionHidden then
      count = count + 1
    end
  end
  return count
end

local function ResolveOverlayLabel(entry)
  if not entry then
    return ""
  end

  local label = entry.label or entry.key or ""

  if type(label) == "table" then
    if label.GetName then
      label = label:GetName() or ""
    else
      label = tostring(label)
    end
  elseif label == nil then
    label = ""
  else
    label = tostring(label)
  end

  return label
end

local function GetOverlayInsets(entry)
  local insets = entry and entry.opts and entry.opts.overlayInsets

  if type(insets) == "function" then
    local left, right, top, bottom = insets(entry.frame, entry)
    return
      MoverRound(left),
      MoverRound(right),
      MoverRound(top),
      MoverRound(bottom)
  end

  if type(insets) == "table" then
    return
      MoverRound(insets.left),
      MoverRound(insets.right),
      MoverRound(insets.top),
      MoverRound(insets.bottom)
  end

  return 0, 0, 0, 0
end

local function SyncOverlay(entry, overlay)
  local frame = entry and entry.frame
  if not overlay
     or not frame
     or (frame.IsForbidden and frame:IsForbidden())
     or not frame.GetObjectType
     or not frame:IsObjectType("Frame") then
    return
  end

  local left, right, top, bottom = GetOverlayInsets(entry)

  overlay:ClearAllPoints()
  overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -left, top)
  overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, -bottom)
end

local function EnsureOverlay(entry)
  local frame = entry.frame
  if not frame
     or not frame.GetObjectType
     or not frame:IsObjectType("Frame") then
    return nil
  end

  if entry.overlay and entry.overlay:IsObjectType("Frame") then
    -- Keep label + font in sync if the entry changed
    if entry.overlay._labelFS then
      entry.overlay._labelFS:SetText(ResolveOverlayLabel(entry))
      FrameUtil.ApplyGlobalEditFont(entry.overlay._labelFS)
    end
    SyncOverlay(entry, entry.overlay)
    if entry.chrome then
      SyncOverlay(entry, entry.chrome)
    end
    return entry.overlay
  end

  local o = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  o:SetFrameStrata(GetMoverChromeStrata())
  o:SetFrameLevel(1000)

  -- Edit Mode routes all mover input through this overlay.
  o:EnableMouse(false)
  o:SetClampedToScreen(true)

  local visual = o
  if entry.opts and entry.opts.overlayBelowFrame == true then
    visual = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    visual:SetFrameStrata("HIGH")
    visual:SetFrameLevel(190)
    visual:EnableMouse(false)
    entry.chrome = visual
  end

  visual:SetBackdrop({
    bgFile   = "Interface/ChatFrame/ChatFrameBackground",
    edgeFile = "Interface/ChatFrame/ChatFrameBackground",
    edgeSize = 2,
  })
  SetEditModeVisualColors(visual, 0.16, 0.82)

  -- Centered label: starts from GameFontHighlightLarge, then we apply
  -- outline + shadow and finally the global /pui font on top.
  local labelFS = visual:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  labelFS:SetPoint("CENTER", visual, "CENTER", 0, 0)
  labelFS:SetJustifyH("CENTER")
  labelFS:SetJustifyV("MIDDLE")
  labelFS:SetText(ResolveOverlayLabel(entry))

  local font, size, flags = labelFS:GetFont()
  if font and size then
    labelFS:SetFont(font, size, "OUTLINE")
  end
  local textColor = ns.Theme.GetColors().text
  labelFS:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
  labelFS:SetShadowColor(0, 0, 0, 1)
  labelFS:SetShadowOffset(1, -1)

  FrameUtil.ApplyGlobalEditFont(labelFS)

  o._labelFS = labelFS

  local function Sync()
    SyncOverlay(entry, o)
    if entry.chrome then
      SyncOverlay(entry, entry.chrome)
    end
  end

  Sync()
  o:SetScript("OnShow",  Sync)
  o:SetScript("OnEvent", Sync)
  o:RegisterEvent("UI_SCALE_CHANGED")
  o:SetScript("OnSizeChanged", QueueMoverLayeringRefresh)

  entry.overlay = o
  o:SetScript("OnEnter", function()
    entry._editHovered = true
    RefreshMoverPresentation(entry)
  end)
  o:SetScript("OnLeave", function()
    entry._editHovered = nil
    RefreshMoverPresentation(entry)
  end)
  o:SetScript("OnHide", function()
    entry._editHovered = nil
    RefreshMoverPresentation(entry)
  end)
  RefreshMoverPresentation(entry)
  return o
end

ShowOverlay = function(entry, show)
  local o = EnsureOverlay(entry)
  if not o then return end

  if show then
    SyncOverlay(entry, o)
    if entry.chrome then
      SyncOverlay(entry, entry.chrome)
    end
  end

  o:SetShown(show and true or false)
  QueueMoverLayeringRefresh()
  if entry.chrome then
    entry.chrome:SetShown(show and true or false)
  end
end

local function OpenOptionsForEntry(entry, frame)
  local opts = entry.opts

  if entry.openOptions then
    entry.openOptions(frame, entry.key)
    return
  end

  if opts.optionsString or opts.optionsRoute or opts.optionsSection then
    local section, tab, key
    local route = opts.optionsString or opts.optionsRoute

    if route and route ~= "" then
      local parts = {}
      for token in route:gmatch("([^,]+)") do
        token = token:gsub("^%s+", ""):gsub("%s+$", "")
        if token ~= "" then
          parts[#parts + 1] = token
        end
      end

      section = parts[1]
      tab = parts[2]
      key = parts[3]
    else
      section = opts.optionsSection
      tab = opts.optionsTab
      key = opts.optionsKey or opts.optionsSubKey
    end

    if tab ~= nil and type(tab) ~= "string" then
      tab = tostring(tab)
    end

    local routeKey = tostring(section or "") .. "," .. tostring(tab or "") .. "," .. tostring(key or "")
    local win = Addon._OptionsWindow

    if win and win:IsShown() and Addon.__puiLastOptionsRoute == routeKey then
      win:Hide()
      Addon.__puiLastOptionsRoute = nil
      return
    end

    if section and key ~= nil then
      Addon:OpenOptionsSection(section, tab, key)
    elseif section and tab ~= nil then
      Addon:OpenOptionsSection(section, tab)
    elseif section then
      Addon:OpenOptionsSection(section)
    end
    return
  end

  Addon:OpenOptions()
end

function FrameUtil.GetMoverQuickSettingsSpec(keyOrEntry, providerFrame)
  local entry = type(keyOrEntry) == "table" and keyOrEntry or MoversByKey[keyOrEntry]
  if not entry then
    return nil
  end

  local provider = entry.quickSettings or (entry.opts and entry.opts.quickSettings)
  local spec
  if type(provider) == "function" then
    spec = provider(providerFrame or entry.frame, entry.key, entry)
    if spec == false then
      return false
    end
  end

  spec = FrameUtil.AugmentSmartSnapQuickSettings(entry, spec)
  if type(spec) ~= "table" then
    return nil
  end

  if spec.openAllSettings == nil then
    spec.openAllSettings = function()
      OpenOptionsForEntry(entry, entry.frame)
    end
  end

  return spec
end

FrameUtil._editHistory = { undo = {}, redo = {} }
FrameUtil._editHistoryParticipants = {}

function FrameUtil.RegisterEditHistoryParticipant(key, capture, restore)
  FrameUtil._editHistoryParticipants[key] = { capture = capture, restore = restore }
end

function FrameUtil.ClearEditHistory()
  local history = FrameUtil._editHistory
  wipe(history.undo)
  wipe(history.redo)
  history.pending = nil
  history.replaying = nil
  for _, entry in ipairs(MoversList) do entry._editHistoryDrag = nil end
end

function FrameUtil.CaptureEditHistoryState(previous)
  EnsureSmartSnapLoaded()
  local visibility = FrameUtil.GetMoverVisibilityConfig()
  local state = { movers = {}, settings = {}, participants = {}, snap = CopyValue(GetSmartSnapDB()),
    visibility = { sets = CopyValue(visibility.sets), selectedSet = visibility.selectedSet,
      followGroup = visibility.followGroup } }
  for _, entry in ipairs(MoversList) do
    local frame = entry.frame
    local x, y = frame:GetCenter()
    local width, height = frame:GetSize()
    if not _G.issecretvalue(x) and not _G.issecretvalue(y)
      and not _G.issecretvalue(width) and not _G.issecretvalue(height) and x and y
    then
      local ux, uy = UIParent:GetCenter()
      state.movers[entry.key] = { entry = entry, x = x - ux, y = y - uy,
        snapState = CaptureSmartSnapState(entry) }
    end
    if not previous then
      local spec = FrameUtil.GetMoverQuickSettingsSpec(entry, frame)
      for _, control in ipairs(spec and spec.controls or {}) do
        if control.get and control.set then
          state.settings[#state.settings + 1] = { get = control.get, set = control.set,
            ownerKey = entry.key, color = control.type == "color", value = CopyValue(control.get()) }
        end
      end
    end
  end
  for key, participant in pairs(FrameUtil._editHistoryParticipants) do
    state.participants[key] = CopyValue(participant.capture())
  end
  if previous then
    for _, control in ipairs(previous.settings) do
      state.settings[#state.settings + 1] = { get = control.get, set = control.set,
        ownerKey = control.ownerKey, color = control.color, value = CopyValue(control.get()) }
    end
  else
    for _, control in ipairs(ns.TestMode:GetEditHistoryControls()) do
      state.settings[#state.settings + 1] = { get = control.get, set = control.set,
        value = CopyValue(control.get()) }
    end
  end
  return state
end

function FrameUtil.BeginEditHistory(label)
  local history = FrameUtil._editHistory
  if not ns.Flags.IsEditing or InCombatLockdown() or history.replaying then return end
  if history.pending then return end
  local transaction = { label = label, before = FrameUtil.CaptureEditHistoryState() }
  history.pending = transaction
  return transaction
end

function FrameUtil.CommitEditHistory(transaction)
  local history = FrameUtil._editHistory
  if not transaction or history.pending ~= transaction then return end
  history.pending = nil
  if not ns.Flags.IsEditing or InCombatLockdown() then return end
  transaction.after = FrameUtil.CaptureEditHistoryState(transaction.before)
  if ValuesEqual(transaction.before, transaction.after) then return end
  history.undo[#history.undo + 1] = transaction
  if #history.undo > 100 then _G.table.remove(history.undo, 1) end
  wipe(history.redo)
  ns.TestMode:RefreshEditControlButtons()
end

function FrameUtil.RemoveMoverEditHistory(key)
  local history = FrameUtil._editHistory
  if history.pending then
    FrameUtil.CommitEditHistory(history.pending)
  end
  for _, stack in ipairs({ history.undo, history.redo }) do
    for index = #stack, 1, -1 do
      local transaction = stack[index]
      local before, after = transaction.before, transaction.after
      local first, last = before.movers[key], after.movers[key]
      local affected = not ValuesEqual(first, last)
        or not ValuesEqual(before.snap.links[key], after.snap.links[key])
        or before.snap.masters[key] ~= after.snap.masters[key]
        or before.snap.widthSyncDisabled[key] ~= after.snap.widthSyncDisabled[key]
      for controlIndex, control in ipairs(before.settings) do
        if control.ownerKey == key and not ValuesEqual(control.value, after.settings[controlIndex].value) then
          affected = true
        end
      end
      if affected then
        _G.table.remove(stack, index)
      else
        for _, snapshot in ipairs({ before, after }) do
          snapshot.movers[key] = nil
          for controlIndex = #snapshot.settings, 1, -1 do
            if snapshot.settings[controlIndex].ownerKey == key then
              _G.table.remove(snapshot.settings, controlIndex)
            end
          end
          snapshot.snap.links[key] = nil
          snapshot.snap.masters[key] = nil
          snapshot.snap.widthSyncDisabled[key] = nil
          for _, peers in pairs(snapshot.snap.links) do peers[key] = nil end
        end
      end
    end
  end
  ns.TestMode:RefreshEditControlButtons()
end

function FrameUtil.RestoreEditHistoryState(state, other)
  local db = FrameUtil._GetEditModeDB()
  FrameUtil._smartSnapApplying = true
  wipe(PendingSmartSnapRelayouts)
  wipe(PendingSmartSnapRuntimeRelayouts)
  ApplyEditHistoryDelta(db.smartSnap, state.snap, other.snap)
  FrameUtil._smartSnapLoaded = false
  EnsureSmartSnapLoaded()
  for key, value in pairs(state.participants) do
    if not ValuesEqual(value, other.participants[key]) then
      FrameUtil._editHistoryParticipants[key].restore(CopyValue(value))
    end
  end
  for index, control in ipairs(state.settings) do
    if not ValuesEqual(control.value, other.settings[index].value) then
      if control.color then
        control.set(_G.unpack(CopyValue(control.value)))
      else
        control.set(CopyValue(control.value))
      end
    end
  end
  for key, point in pairs(state.movers) do
    local entry = MoversByKey[key]
    local opposite = other.movers[key]
    if entry == point.entry and opposite then
      local saved, changed = point.snapState, opposite.snapState
      local current = CaptureSmartSnapState(entry)
      local options = GetSmartSnapOptions(entry)
      if saved and changed and current and not ValuesEqual(saved.size, changed.size)
        and not ValuesEqual(saved.size, current.size) then
        if options.syncAxis == "WIDTH" and options.applySyncWidth then
          options.applySyncWidth(saved.size.width, entry)
        elseif options.copySizeFrom then
          options.copySizeFrom({ frame = entry.frame, key = entry.key,
            opts = { smartSnap = { getSizeState = function() return CopyValue(saved.size) end } } })
        elseif options.applyDimensions then
          options.applyDimensions(saved.size.width, saved.size.height, entry)
        end
      end
      if saved and changed and current and options.applyDesign
        and not ValuesEqual(saved.design, changed.design)
        and not ValuesEqual(saved.design, current.design) then
        options.applyDesign(CopyValue(saved.design), entry)
      end
    end
  end
  for key, point in pairs(state.movers) do
    local entry = MoversByKey[key]
    local opposite = other.movers[key]
    if entry == point.entry and opposite and (point.x ~= opposite.x or point.y ~= opposite.y
      or not ValuesEqual(point.snapState, opposite.snapState)) then
      MoveEntryTo(entry, point.x, point.y, true)
      FinalizeEntryMove(entry)
      entry._smartSnapState = CaptureSmartSnapState(entry)
    end
  end
  FrameUtil._smartSnapApplying = false
  if not ValuesEqual(state.visibility, other.visibility) then
    local visibility = FrameUtil.GetMoverVisibilityConfig()
    visibility.sets = CopyValue(state.visibility.sets)
    visibility.selectedSet = state.visibility.selectedSet
    visibility.followGroup = state.visibility.followGroup
    FrameUtil.ApplyMoverVisibilityPreset()
  end
  local panel = ns.EditModeQuickSettings.panel
  if panel and panel:IsShown() and panel.fadeDirection ~= "out" then
    local key = FrameUtil.GetMoverKeyForAnchor(panel.anchor)
    local entry = key and MoversByKey[key]
    if IsSelectableEntry(entry) then
      if not ns.EditModeQuickSettings:Refresh(panel.ownerKey, panel.anchor,
        FrameUtil.GetMoverQuickSettingsSpec(entry, entry.frame)) then
        ns.EditModeQuickSettings:Hide(true)
      end
    else
      ns.EditModeQuickSettings:Hide(true)
    end
  end
  ns.TestMode:QueueToolbarRefresh()
  FrameUtil._RefreshSelectionVisuals()
end

function FrameUtil.ReplayEditHistory(redo)
  local history = FrameUtil._editHistory
  if not ns.Flags.IsEditing or InCombatLockdown() or history.pending or history.replaying then return false end
  local from, to = history.undo, history.redo
  if redo then from, to = history.redo, history.undo end
  local transaction = from[#from]
  if not transaction then return false end
  history.replaying = true
  FrameUtil._StopAllNudgeHolds()
  if redo then
    FrameUtil.RestoreEditHistoryState(transaction.after, transaction.before)
  else
    FrameUtil.RestoreEditHistoryState(transaction.before, transaction.after)
  end
  history.replaying = nil
  from[#from] = nil
  to[#to + 1] = transaction
  ns.TestMode:RefreshEditControlButtons()
  return true
end

local function OpenQuickSettingsForEntry(entry, frame)
  local anchor = entry.overlay or frame
  local spec = FrameUtil.GetMoverQuickSettingsSpec(entry, frame)
  if spec == false then
    return true
  end
  if type(spec) ~= "table" then
    return false
  end

  local panel = ns.EditModeQuickSettings.panel
  if panel
    and panel:IsShown()
    and panel.anchor == anchor
    and panel.ownerKey == spec.ownerKey
  then
    ns.EditModeQuickSettings:Hide()
    return true
  end

  ns.EditModeQuickSettings:Hide()
  return ns.EditModeQuickSettings:Open(anchor, spec)
end

local function GetMoverOverlapEdges(entry)
  local left, right, top, bottom = GetFrameEdges(entry.frame)
  if not left then return end
  local scale = entry.frame:GetEffectiveScale()
  if _G.issecretvalue(scale) then return end
  scale = scale / UIParent:GetEffectiveScale()
  return left * scale, right * scale, top * scale, bottom * scale
end

function FrameUtil.GetOverlappingMovers()
  local entries = {}
  if not ns.Flags.IsEditing or not IsSelectableEntry(SelectedEntry) then return entries end
  local left, right, top, bottom = GetMoverOverlapEdges(SelectedEntry)
  if not left then return entries end
  for _, entry in ipairs(MoversList) do
    if IsSelectableEntry(entry) then
      local l, r, t, b = GetMoverOverlapEdges(entry)
      if l and r > left and l < right and t > bottom and b < top then
        entries[#entries + 1] = entry
      end
    end
  end
  _G.table.sort(entries, function(first, second)
    if first.label == second.label then return first.key < second.key end
    return first.label < second.label
  end)
  return entries
end

function FrameUtil.ShowOverlappingMoverChooser()
  if InCombatLockdown() then return false end
  local entries = FrameUtil.GetOverlappingMovers()
  if #entries < 2 then return false end
  local choices, order = {}, {}
  for _, entry in ipairs(entries) do
    choices[entry.key] = entry.label
    order[#order + 1] = entry.key
  end
  return ns.EditModeQuickSettings:Open(SelectedEntry.overlay or SelectedEntry.frame, {
    ownerKey = "overlapping-movers", title = "Overlapping movers",
    description = "Choose a mover to select it and open its settings.",
    controls = {{ type = "select", label = "Mover", values = choices, sorting = order,
      get = function() return SelectedEntry.key end,
      set = function(key)
        local entry = MoversByKey[key]
        if IsSelectableEntry(entry) then
          FrameUtil._SelectMover(entry, false)
          ns.EditModeQuickSettings:Hide(true)
          OpenQuickSettingsForEntry(entry, entry.frame)
        end
      end,
    }},
  })
end

local function AttachDrag(entry)
  local frame = entry.frame
  if not frame or not frame.SetMovable or not frame.EnableMouse then
    return
  end

  if entry.ghost or frame._puiMoverInit then
    return
  end
  frame._puiMoverInit = true

  frame._puiPrevMovable = frame:IsMovable()
  frame._puiPrevMouse   = frame:IsMouseEnabled()

  frame:SetMovable(true)
  frame:EnableMouse(true)
  if frame.SetClampedToScreen then
    frame:SetClampedToScreen(true)
  end

  local dragFrame = entry.overlay or EnsureOverlay(entry) or frame
  dragFrame:EnableMouse(true)
  dragFrame:RegisterForDrag("LeftButton")

  dragFrame:HookScript("OnMouseDown", function(_, button)
    if not ns.Flags.IsEditing then
      return
    end

    if button == "LeftButton" then
      local controlClick = IsControlKeyDown()
      local shiftClick = IsShiftKeyDown()
      entry.__puiLeftDragStarted = nil
      entry.__puiPendingSelectionAction = nil
      entry.__puiPendingQuickSettings = not controlClick and not shiftClick
      entry.__puiShiftDrag = shiftClick and true or nil

      if shiftClick and entry.key then
        entry._editHistoryDrag = FrameUtil.BeginEditHistory("Detach and move")
        FrameUtil.ClearSmartSnapForKey(entry.key)
      end

      if controlClick then
        if FrameUtil._IsMoverSelected(entry) then
          entry.__puiPendingSelectionAction = "REMOVE"
        else
          FrameUtil._SelectMover(entry, true)
        end
      elseif FrameUtil._IsMoverSelected(entry) then
        if FrameUtil._GetSelectedMoverCount() > 1 then
          entry.__puiPendingSelectionAction = "SINGLE"
        end
      else
        FrameUtil._SelectMover(entry, false)
      end
    elseif button == "RightButton" then
      if IsShiftKeyDown() then
        FrameUtil.HideMoverForEditSession(entry.key)
        return
      end

      if _G.IsAltKeyDown() then
        if entry.key then
          local history = FrameUtil.BeginEditHistory("Detach mover")
          FrameUtil.ClearSmartSnapForKey(entry.key)
          FrameUtil.CommitEditHistory(history)
          Addon:Print("|cffd0ff00[PUI]|r Detached Smart Snap links for '" .. tostring(entry.label or entry.key) .. "'.")
        end
        return
      end

      if IsControlKeyDown() then
        local resetPosition = entry.resetPosition
          or (entry.opts and entry.opts.resetPosition)
        if type(resetPosition) == "function" then
          local history = FrameUtil.BeginEditHistory("Reset mover position")
          FrameUtil.ClearSmartSnapForKey(entry.key)
          resetPosition(frame, entry.key)
          FrameUtil._OnMoverMoved(entry)
          FrameUtil.CommitEditHistory(history)
        else
          Addon:Print("|cffd0ff00[PUI]|r No resetPosition handler for mover '" .. tostring(entry.key) .. "'.")
        end
        return
      end

      entry.__puiPendingRightClickOpen = true
    end
  end)

  dragFrame:HookScript("OnMouseUp", function(_, button)
    if not ns.Flags.IsEditing then
      return
    end

    if button == "LeftButton" then
      if not entry.__puiLeftDragStarted then
        if entry.__puiPendingSelectionAction == "REMOVE" then
          FrameUtil._RemoveMoverSelection(entry)
        elseif entry.__puiPendingSelectionAction == "SINGLE" then
          FrameUtil._SelectMover(entry, false)
        end

        if entry.__puiPendingQuickSettings then
          OpenQuickSettingsForEntry(entry, frame)
        end
      end

      if not entry.__puiLeftDragStarted then
        FrameUtil.CommitEditHistory(entry._editHistoryDrag)
        entry._editHistoryDrag = nil
      end
      entry.__puiLeftDragStarted = nil
      entry.__puiPendingSelectionAction = nil
      entry.__puiPendingQuickSettings = nil
      entry.__puiShiftDrag = nil
      return
    end

    if button == "RightButton" and entry.__puiPendingRightClickOpen then
      entry.__puiPendingRightClickOpen = nil
      OpenOptionsForEntry(entry, frame)
    end
  end)

  dragFrame:HookScript("OnDragStart", function()
    if not ns.Flags.IsEditing or InCombatLockdown() then
      return
    end

    if not FrameUtil._IsMoverSelected(entry) then
      FrameUtil._SelectMover(entry, false)
    end

    entry._editHistoryDrag = entry._editHistoryDrag or FrameUtil.BeginEditHistory("Move " .. entry.label)
    entry.__puiLeftDragStarted = true
    entry.__puiPendingSelectionAction = nil
    entry.__puiPendingQuickSettings = nil

    if dragFrame.SetScript and entry._puiDragOnUpdate then
      dragFrame:SetScript("OnUpdate", entry._puiDragOnUpdate)
    end

    entry._dragSnapSuppressed = entry.__puiShiftDrag == true or IsShiftKeyDown()
    if entry._dragSnapSuppressed then
      FrameUtil.ClearSmartSnapForKey(entry.key)
      ClearSmartSnapCandidate(entry)
    end

    entry._dragStartX, entry._dragStartY = GetOffsetsForFrame(frame)

    local moveGroup = FrameUtil._GetSelectedMoveGroup(entry, not entry._dragSnapSuppressed)
    moveGroup[entry] = true

    entry._dragMoveGroup = moveGroup
    entry._dragPeersStart = {}

    for peer in pairs(moveGroup) do
      if peer ~= entry and peer.frame then
        local px, py = GetOffsetsForFrame(peer.frame)
        entry._dragPeersStart[peer] = { x = px, y = py }
      end
    end

    if entry.opts and type(entry.opts.onDragStart) == "function" then
      entry.opts.onDragStart(frame, entry.key)
    end

    if frame.StartMoving then
      frame:StartMoving()
    end
  end)

  entry._puiDragOnUpdate = function()
    if not ns.Flags.IsEditing then
      return
    end

    if entry == SelectedEntry then
      local now = _G.GetTime()
      if not entry._puiLiveCoordNext or now >= entry._puiLiveCoordNext then
        entry._puiLiveCoordNext = now + 0.05
        FrameUtil._UpdateNudgeUI(entry)
      end
    end

    if not entry._dragPeersStart then
      return
    end

    local cx, cy = GetOffsetsForFrame(frame)
    local dx = cx - (entry._dragStartX or cx)
    local dy = cy - (entry._dragStartY or cy)

    for peer, data in pairs(entry._dragPeersStart) do
      if peer.frame then
        MoveEntryTo(peer, data.x + dx, data.y + dy, true)
      end
    end

    local attachmentActive = false
    if entry.opts and type(entry.opts.onDragUpdate) == "function" then
      attachmentActive = entry.opts.onDragUpdate(frame, entry.key, entry) == true
    end

    if attachmentActive or entry._dragSnapSuppressed then
      ClearSmartSnapCandidate(entry)
      ClearFrameSnapFeedback()
    elseif FrameUtil.UpdateSmartSnapCandidate(entry, entry._dragMoveGroup) then
      ClearFrameSnapFeedback()
    else
      UpdateFrameSnapFeedback(entry, entry._dragMoveGroup)
    end
  end

  dragFrame:HookScript("OnDragStop", function()
    if frame.StopMovingOrSizing then
      frame:StopMovingOrSizing()
    end

    if dragFrame.SetScript then
      dragFrame:SetScript("OnUpdate", nil)
    end

    local moveGroup = entry._dragMoveGroup or { [entry] = true }
    local peersStart = entry._dragPeersStart

    local currentX, currentY = GetOffsetsForFrame(frame)
    local dx = currentX - (entry._dragStartX or currentX)
    local dy = currentY - (entry._dragStartY or currentY)

    if peersStart then
      for peer, data in pairs(peersStart) do
        if peer.frame then
          MoveEntryTo(peer, data.x + dx, data.y + dy, true)
        end
      end
    end

    local attachmentCommitted = false
    if entry.opts and type(entry.opts.onDrop) == "function" then
      attachmentCommitted = entry.opts.onDrop(frame, entry.key, entry) == true
    end

    local smartSnapCommitted = false
    if not attachmentCommitted and not entry._dragSnapSuppressed then
      smartSnapCommitted = FrameUtil.CommitSmartSnapCandidate(entry)
    else
      ClearSmartSnapCandidate(entry)
    end

    if not attachmentCommitted and not smartSnapCommitted then
      if not entry._dragSnapSuppressed then
        local beforeSnapX, beforeSnapY = GetOffsetsForFrame(frame)

        local snapAxis = FrameUtil._ApplyFrameSnap(entry, true, moveGroup)
        FrameUtil._ApplyGridSnap(entry, snapAxis)

        local afterSnapX, afterSnapY = GetOffsetsForFrame(frame)
        local snapDx = afterSnapX - beforeSnapX
        local snapDy = afterSnapY - beforeSnapY

        if snapDx ~= 0 or snapDy ~= 0 then
          for peer in pairs(moveGroup) do
            if peer ~= entry and peer.frame then
              local peerX, peerY = GetOffsetsForFrame(peer.frame)
              MoveEntryTo(peer, peerX + snapDx, peerY + snapDy, true)
            end
          end
        end
      end

      FrameUtil._FinalizeMovedGroup(moveGroup, entry)
    elseif attachmentCommitted then
      for peer in pairs(moveGroup) do
        if peer ~= entry then
          FinalizeEntryMove(peer)
        end
      end
      FrameUtil._OnMoverMoved(entry)
    end

    ClearFrameSnapFeedback()
    FrameUtil.CommitEditHistory(entry._editHistoryDrag)
    entry._editHistoryDrag = nil
    entry._dragMoveGroup = nil
    entry._dragPeersStart = nil
    entry._dragStartX = nil
    entry._dragStartY = nil
    entry._dragSnapSuppressed = nil
    entry.__puiShiftDrag = nil
  end)
end

EnableDrag = function(entry, enable)
  local feedback = FrameUtil._frameSnapFeedback
  if not enable and feedback and (feedback.ownerKey == entry.key or feedback.targetKey == entry.key) then
    ClearFrameSnapFeedback()
  end
  local frame = entry.frame
  if not frame then return end

  if entry.ghost then
    return
  end

  local dragOverlay = entry.overlay or EnsureOverlay(entry) or nil

  if enable then
    AttachDrag(entry)
    frame:SetMovable(true)

    if dragOverlay and dragOverlay.EnableMouse then
      frame:EnableMouse(false)
      dragOverlay:EnableMouse(true)
    else
      frame:EnableMouse(true)
    end
  else
    if frame.IsMoving and frame:IsMoving() and frame.StopMovingOrSizing then
      frame:StopMovingOrSizing()
    end

    if dragOverlay then
      dragOverlay:SetScript("OnUpdate", nil)
      dragOverlay:EnableMouse(false)
    end
    entry._dragMoveGroup = nil
    entry._dragPeersStart = nil

    if frame._puiPrevMovable ~= nil then
      frame:SetMovable(frame._puiPrevMovable)
    end
    if frame._puiPrevMouse ~= nil then
      frame:EnableMouse(frame._puiPrevMouse)
    end
  end
end


local function PositionNudgeControls(entry)
  if not entry or not entry.frame or not entry.nudgeGroup then
    return
  end
  local frame = entry.frame
  local g     = entry.nudgeGroup

  local cx, cy = frame:GetCenter()
  local ux, uy = UIParent:GetCenter()
  ux = ux or 0
  uy = uy or 0

  local leftBtn  = g.left
  local rightBtn = g.right
  local upBtn    = g.up
  local downBtn  = g.down
  if not (leftBtn and rightBtn and upBtn and downBtn) then
    return
  end

  leftBtn:ClearAllPoints()
  rightBtn:ClearAllPoints()
  upBtn:ClearAllPoints()
  downBtn:ClearAllPoints()

  if cy and uy and cy > uy then
    leftBtn:SetPoint("BOTTOMRIGHT", frame, "TOP", -14, 6)
    rightBtn:SetPoint("BOTTOMLEFT", frame, "TOP", 14, 6)
  else
    leftBtn:SetPoint("TOPRIGHT", frame, "BOTTOM", -14, -6)
    rightBtn:SetPoint("TOPLEFT", frame, "BOTTOM", 14, -6)
  end

  if cx and ux and cx > ux then
    upBtn:SetPoint("TOPRIGHT", frame, "LEFT", -6, -4)
    downBtn:SetPoint("BOTTOMRIGHT", frame, "LEFT", -6, 4)
  else
    upBtn:SetPoint("TOPLEFT", frame, "RIGHT", 6, -4)
    downBtn:SetPoint("BOTTOMLEFT", frame, "RIGHT", 6, 4)
  end
end


local function CreateArrowTextureButton(parent, atlasNormal, atlasPressed, rotationRadians)
  -- IMPORTANT: CreateFrame expects the frame type as a STRING.
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(Round(22), Round(22))

  local tex = b:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetAtlas(atlasNormal)
  if rotationRadians and tex.SetRotation then
    tex:SetRotation(rotationRadians)
  end
  b.tex = tex

  if atlasPressed then
    local ptex = b:CreateTexture(nil, "ARTWORK")
    ptex:SetAllPoints()
    ptex:SetAtlas(atlasPressed)
    if rotationRadians and ptex.SetRotation then
      ptex:SetRotation(rotationRadians)
    end
    b:SetPushedTexture(ptex)
    b.ptex = ptex
  end

  return b
end

local function StopHoldGroup(g)
  if not g then return end

  if g._holdDelayTimer then
    g._holdDelayTimer:Cancel()
    g._holdDelayTimer = nil
  end
  if g._holdTicker then
    g._holdTicker:Cancel()
    g._holdTicker = nil
  end
  local history = g._editHistoryHold
  g._editHistoryHold = nil
  FrameUtil.CommitEditHistory(history)
  g._holdPending = nil
  g._holdDx = nil
  g._holdDy = nil

  local cf = g._captureFrame
  if cf then
    cf:Hide()
    cf:SetScript("OnMouseUp", nil)
    cf:SetScript("OnHide", nil)
    cf:SetScript("OnUpdate", nil)
  end

end

function FrameUtil._StopAllNudgeHolds()
  for _, e in ipairs(MoversList) do
    if e.nudgeGroup then
      StopHoldGroup(e.nudgeGroup)
    end
  end
end

local function EnsureNudgeControls(entry)
  if not entry or not entry.frame then
    return nil
  end
  if entry.nudgeGroup and entry.nudgeGroup:IsObjectType("Frame") then
    return entry.nudgeGroup
  end

  local g = CreateFrame("Frame", nil, UIParent)
  g:SetFrameStrata(GetMoverChromeStrata())
  g:SetFrameLevel(1100)
  g:SetSize(Round(1), Round(1))

  local atlasNormal  = "CovenantSanctum-Renown-Arrow"
  local atlasPressed = "CovenantSanctum-Renown-Arrow-Depressed"

  g.left  = CreateArrowTextureButton(g, atlasNormal, atlasPressed, 0)
  g.up    = CreateArrowTextureButton(g, atlasNormal, atlasPressed, _G.math.pi / 2)
  g.right = CreateArrowTextureButton(g, atlasNormal, atlasPressed, _G.math.pi)
  g.down  = CreateArrowTextureButton(g, atlasNormal, atlasPressed, (_G.math.pi * 3) / 2)

  local HOLD_DELAY = 0.25
  local HOLD_RATE  = 0.03

  local function EnsureHoldCaptureFrame()
    if g._captureFrame and g._captureFrame:IsObjectType("Frame") then
      return g._captureFrame
    end

    local cf = CreateFrame("Frame", nil, UIParent)
    cf:SetAllPoints(UIParent)
    cf:SetFrameStrata("TOOLTIP")
    cf:SetFrameLevel(5000)
    cf:EnableMouse(true)
    cf:Hide()

    g._captureFrame = cf
    return cf
  end

  local function StopHold()
    StopHoldGroup(g)
  end

  local function StartRepeat(dx, dy)
    if SelectedEntry ~= entry then
      StopHold()
      return
    end

    local cf = EnsureHoldCaptureFrame()
    cf:Show()
    cf:SetScript("OnMouseUp", function() StopHold() end)
    cf:SetScript("OnHide", function() StopHold() end)

    -- No tickers: use OnUpdate while holding, throttled by HOLD_RATE.
    g._holdDx = dx
    g._holdDy = dy
    g._holdNext = 0

    cf:SetScript("OnUpdate", function(_, elapsed)
      if not ns.Flags.IsEditing then
        StopHold()
        return
      end
      if SelectedEntry ~= entry then
        StopHold()
        return
      end

      local now = _G.GetTime()
      if now >= (g._holdNext or 0) then
        g._holdNext = now + HOLD_RATE
        FrameUtil._NudgeSelected(g._holdDx or 0, g._holdDy or 0)
      end
    end)
  end


  local function OnArrowMouseDown(dx, dy)
    if SelectedEntry ~= entry then
      return
    end

    StopHold()
    g._editHistoryHold = FrameUtil.BeginEditHistory("Nudge movers")
    g._holdPending = true
    g._holdDx = dx or 0
    g._holdDy = dy or 0

    g._holdDelayTimer = _G.C_Timer.NewTimer(HOLD_DELAY, function()
      g._holdDelayTimer = nil
      if g._holdPending and SelectedEntry == entry then
        g._holdPending = nil
        StartRepeat(g._holdDx, g._holdDy)
      end
    end)
  end

  local function OnArrowMouseUp()
    if g._holdPending and SelectedEntry == entry then
      FrameUtil._NudgeSelected(g._holdDx or 0, g._holdDy or 0)
    end
    StopHold()
  end

  local function WireHold(button, dirX, dirY)
    if not button then return end

    button:SetScript("OnMouseDown", function(_, btn)
      if btn ~= "LeftButton" then return end
      local step = FrameUtil._nudgeStep or NUDGE_DEFAULT
      OnArrowMouseDown((dirX or 0) * step, (dirY or 0) * step)
    end)

    button:SetScript("OnMouseUp", function()
      OnArrowMouseUp()
    end)

    button:HookScript("OnHide", function()
      StopHold()
    end)
  end

  WireHold(g.left,  -1, 0)
  WireHold(g.right,  1, 0)
  WireHold(g.up,     0, -1)
  WireHold(g.down,   0, 1)

  g:Hide()
  entry.nudgeGroup = g

  PositionNudgeControls(entry)
  return g
end


function FrameUtil._ShowNudgeControls(entry, show)
  if not entry then
    return
  end
  local g = EnsureNudgeControls(entry)
  if not g then
    return
  end

  if show and SelectedEntry == entry then
    PositionNudgeControls(entry)
    g:Show()
  else
    g:Hide()
  end
end

function FrameUtil._NudgeSelected(dx, dy)
  dx = dx or 0
  dy = dy or 0

  if not SelectedEntry then
    return
  end

  local onePixel = ns.Pixel.GetOnePixel()
  local moveGroup = FrameUtil._GetSelectedMoveGroup(SelectedEntry, true)
  FrameUtil._MoveGroupBy(
    moveGroup,
    dx * onePixel,
    dy * onePixel,
    SelectedEntry
  )
end

function FrameUtil._SetNudgeStepFromSlider(value)
  local v = tonumber(value) or NUDGE_DEFAULT
  if v < NUDGE_MIN then
    v = NUDGE_MIN
  elseif v > NUDGE_MAX then
    v = NUDGE_MAX
  end
  v = math_floor(v + 0.5)
  FrameUtil._nudgeStep = v

  local db = FrameUtil._GetEditModeDB()
  db.nudgeStep = v
  ns.TestMode:QueueToolbarRefresh()
end

function FrameUtil._ApplyNudgeFromInputs()
  if not SelectedEntry then
    return
  end

  local xBox = FrameUtil._nudgeXInput
  local yBox = FrameUtil._nudgeYInput
  if not xBox or not yBox then
    return
  end

  local x = tonumber(xBox:GetText() or "")
  local y = tonumber(yBox:GetText() or "")
  if not x or not y then
    return
  end

  local history = FrameUtil.BeginEditHistory("Set mover position")
  local oldX, oldY = GetOffsetsForFrame(SelectedEntry.frame)
  local dx = x - oldX
  local dy = y - oldY
  local moveGroup = FrameUtil._GetSelectedMoveGroup(SelectedEntry, true)

  for entry in pairs(moveGroup) do
    local entryX, entryY = GetOffsetsForFrame(entry.frame)

    if entry == SelectedEntry then
      MoveEntryTo(entry, x, y, true)
    else
      MoveEntryTo(entry, entryX + dx, entryY + dy, true)
    end
  end

  FrameUtil._FinalizeMovedGroup(moveGroup, SelectedEntry)
  FrameUtil.CommitEditHistory(history)
end

function FrameUtil._UpdateNudgeUI(entry)
  local labelFS = FrameUtil._selectedLabel
  local xBox    = FrameUtil._nudgeXInput
  local yBox    = FrameUtil._nudgeYInput

  if not labelFS or not xBox or not yBox then
    return
  end

  local xFrame = xBox.frame
  local yFrame = yBox.frame

  if FrameUtil._coordinatePanel then
    FrameUtil._coordinatePanel:SetShown(ns.Flags.IsEditing and IsSelectableEntry(entry))
  end

  if not IsSelectableEntry(entry) then
    if labelFS.__puiLastText ~= "Selected: none" then
      labelFS:SetText("Selected: none")
      labelFS.__puiLastText = "Selected: none"
    end

    if xBox.__puiLastText ~= "" then
      xBox:SetText("")
      xBox.__puiLastText = ""
    end
    if yBox.__puiLastText ~= "" then
      yBox:SetText("")
      yBox.__puiLastText = ""
    end
    if xFrame then xFrame:Show() end
    if yFrame then yFrame:Show() end

    return
  end

  local selectedCount = FrameUtil._GetSelectedMoverCount()
  local selectedText

  if selectedCount > 1 then
    selectedText = "Selected: " .. tostring(selectedCount) .. " movers"
  else
    local label = entry.label or entry.key or "unnamed"
    selectedText = "Selected: " .. tostring(label)
  end

  if labelFS.__puiLastText ~= selectedText then
    labelFS:SetText(selectedText)
    labelFS.__puiLastText = selectedText
  end

  local x, y = GetOffsetsForFrame(entry.frame)
  local xText = _G.string.format("%.0f", x)
  local yText = _G.string.format("%.0f", y)
  if xBox.__puiLastText ~= xText then
    xBox:SetText(xText)
    xBox.__puiLastText = xText
  end
  if yBox.__puiLastText ~= yText then
    yBox:SetText(yText)
    yBox.__puiLastText = yText
  end

  if xFrame then xFrame:Show() end
  if yFrame then yFrame:Show() end

end

function FrameUtil._ClearSelection()
  wipe(SelectedEntries)
  SelectedEntry = nil

  FrameUtil._StopAllNudgeHolds()
  FrameUtil._RefreshSelectionVisuals()
end

function FrameUtil._RemoveMoverSelection(entry)
  if not entry or not SelectedEntries[entry] then
    return
  end

  SelectedEntries[entry] = nil

  if SelectedEntry == entry then
    SelectedEntry = nil
  end

  FrameUtil._StopAllNudgeHolds()
  FrameUtil._RefreshSelectionVisuals()
end

function FrameUtil._OnMoverMoved(entry)
  if not entry then
    return
  end

  if entry.nudgeGroup and entry == SelectedEntry then
    PositionNudgeControls(entry)
  end

  if entry == SelectedEntry then
    FrameUtil._UpdateNudgeUI(entry)
  end
end

function FrameUtil._SelectMover(entry, additive)
  if not IsSelectableEntry(entry) then
    return
  end

  FrameUtil._StopAllNudgeHolds()

  if not additive then
    wipe(SelectedEntries)
  end

  SelectedEntries[entry] = true
  SelectedEntry = entry

  FrameUtil._RefreshSelectionVisuals()
end


function FrameUtil._SelectNextMover(forward)
  forward = (forward ~= false)
  local count = #MoversList
  if count == 0 then
    return
  end

  local idx = 0
  if SelectedEntry then
    for i, e in ipairs(MoversList) do
      if e == SelectedEntry then
        idx = i
        break
      end
    end
  end

  if idx == 0 then
    idx = 1
  else
    idx = idx + (forward and 1 or -1)
    if idx < 1 then
      idx = count
    elseif idx > count then
      idx = 1
    end
  end

  local start = idx
  local step  = forward and 1 or -1

  local entry = MoversList[idx]
  if IsSelectableEntry(entry) then
    FrameUtil._SelectMover(entry)
    return
  end

  local i = idx
  while true do
    i = i + step
    if i < 1 then
      i = count
    elseif i > count then
      i = 1
    end
    if i == start then
      break
    end

    local e = MoversList[i]
    if IsSelectableEntry(e) then
      FrameUtil._SelectMover(e)
      return
    end
  end
end

FrameUtil._GhostMoverHelpers = FrameUtil._GhostMoverHelpers or {}
GhostMoverHelpers = FrameUtil._GhostMoverHelpers

local function GhostAnchorDependsOnFrame(startFrame, targetFrame)
  if not startFrame or not targetFrame or startFrame == targetFrame then
    return true
  end

  local current = startFrame
  local seen = {}

  for _ = 1, 16 do
    if not current or seen[current] then
      break
    end

    seen[current] = true

    if current == targetFrame then
      return true
    end

    if not current.GetPoint then
      break
    end

    local _, relativeTo = current:GetPoint(1)
    if type(relativeTo) == "string" then
      relativeTo = _G[relativeTo]
    end

    if not relativeTo then
      break
    end

    if relativeTo == targetFrame then
      return true
    end

    current = relativeTo
  end

  return false
end

local function ResolveSafeGhostRelativeTo(ghost, relativeTo, opts)
  if type(relativeTo) == "string" then
    relativeTo = _G[relativeTo] or UIParent
  end

  if not relativeTo or relativeTo == ghost then
    local fallback = opts and opts.fallbackAnchor or nil
    local fallbackTo = fallback and fallback.relativeTo or nil
    if type(fallbackTo) == "string" then
      fallbackTo = _G[fallbackTo] or UIParent
    end
    return fallbackTo or UIParent
  end

  if GhostMoverHelpers then
    for _, helper in pairs(GhostMoverHelpers) do
      local helperFrame = helper and helper.frame or nil
      if helperFrame and helperFrame == relativeTo then
        if GhostAnchorDependsOnFrame(relativeTo, ghost) then
          local fallback = opts and opts.fallbackAnchor or nil
          local fallbackTo = fallback and fallback.relativeTo or nil
          if type(fallbackTo) == "string" then
            fallbackTo = _G[fallbackTo] or UIParent
          end
          return fallbackTo or UIParent
        end
        break
      end
    end
  end

  return relativeTo
end

function FrameUtil:RefreshGhostMover(key)
  local helper = GhostMoverHelpers[key]
  if not helper then
    return nil
  end

  EnsureSmartSnapLoaded()

  local ghost = helper.frame
  local opts = helper.opts or {}
  local liveFrame = opts.liveFrame

  if type(liveFrame) == "function" then
    liveFrame = liveFrame(ghost, key, helper)
  end

  if not ghost then
    return nil
  end

  local config = type(opts.getConfig) == "function" and opts.getConfig(ghost, liveFrame) or nil

  local width, height
  if type(opts.getSize) == "function" then
    width, height = opts.getSize(ghost, liveFrame, config)
  elseif liveFrame and liveFrame.GetSize then
    width, height = liveFrame:GetSize()
  end

  if width and height and width > 0 and height > 0 then
    ghost:SetSize(Round(width), Round(height))
  end

  ghost:ClearAllPoints()

  local point, relativeTo, relativePoint, x, y
  if type(opts.getPoint) == "function" then
    point, relativeTo, relativePoint, x, y = opts.getPoint(ghost, liveFrame, config)
  elseif liveFrame and liveFrame.GetPoint then
    point, relativeTo, relativePoint, x, y = liveFrame:GetPoint(1)
  end

  relativeTo = ResolveSafeGhostRelativeTo(ghost, relativeTo, opts)

  if point and relativePoint then
    ghost:SetPoint(point, relativeTo or UIParent, relativePoint, x or 0, y or 0)
  else
    local fallback = opts.fallbackAnchor or {}
    local fallbackTo = fallback.relativeTo
    if type(fallbackTo) == "string" then
      fallbackTo = _G[fallbackTo] or UIParent
    end

    ghost:SetPoint(
      fallback.point or "CENTER",
      fallbackTo or UIParent,
      fallback.relativePoint or "CENTER",
      fallback.x or 0,
      fallback.y or 0
    )
  end

  local runtimeActive
  if type(opts.getSize) == "function" then
    runtimeActive = width ~= nil
      and height ~= nil
      and width > 0
      and height > 0
  else
    runtimeActive = liveFrame ~= nil
  end

  local shouldShow = false
  if type(opts.shouldShow) == "function" then
    shouldShow = opts.shouldShow(ghost, liveFrame, config) and true or false
  elseif opts.show ~= nil then
    shouldShow = opts.show and true or false
  end

  ghost:SetShown(shouldShow)
  if not shouldShow and ghost.EnableMouse then
    ghost:EnableMouse(false)
  end
  if ghost.EnableMouseWheel then
    ghost:EnableMouseWheel(false)
  end

  local entry = MoversByKey[key]
  if entry then
    entry._ghostManaged = true
    entry._ghostVisible = shouldShow and true or false
    entry._smartSnapRuntimeActive = runtimeActive and true or false

    if ns.Flags.IsEditing then
      local moverVisible = RefreshMoverEditSessionVisibility(entry)

      if not moverVisible and FrameUtil._IsMoverSelected(entry) then
        FrameUtil._RemoveMoverSelection(entry)
      end
    end

    if SmartSnapLinks[key]
      and not FrameUtil._smartSnapApplying
    then
      QueueSmartSnapRuntimeRelayout(key)
    end
  end

  return ghost
end

function FrameUtil:EnsureGhostMover(key, opts)
  if not key then
    return nil
  end

  opts = type(opts) == "table" and opts or {}

  local helper = GhostMoverHelpers[key]
  if not helper then
    helper = {}
    GhostMoverHelpers[key] = helper
  end

  helper.opts = opts

  local ghost = helper.frame
  if not ghost then
    local frameName = opts.frameName
    if frameName == "" then
      frameName = nil
    end

    ghost = CreateFrame("Frame", frameName, UIParent)
    helper.frame = ghost

    ghost.__puiEditMoverHelper = true
    ghost:SetFrameStrata(GetMoverChromeStrata())
    ghost:SetFrameLevel(900)
    ghost:SetToplevel(true)
    ghost:SetClampedToScreen(true)
    ghost:SetAlpha(0)

    ghost:EnableMouse(false)
    if ghost.EnableMouseWheel then
      ghost:EnableMouseWheel(false)
    end
    ghost:Hide()
  end

  ghost.__puiUseOverlayDrag = opts.useOverlayDrag ~= false

  self:RefreshGhostMover(key)

  self:RegisterMover(key, ghost, {
    label = opts.label,
    moduleKey = opts.moduleKey,
    moduleLabel = opts.moduleLabel,
    groupKey = opts.groupKey,
    groupLabel = opts.groupLabel,
    defaultVisibility = opts.defaultVisibility,
    isAvailable = opts.isAvailable,
    onPreviewVisibilityChanged = opts.onPreviewVisibilityChanged,
    snapGroup = opts.snapGroup,
    ghost = opts.ghost and true or false,
    useOverlayDrag = opts.useOverlayDrag ~= false,
    savePosition = opts.savePosition,
    onDragStop = opts.onDragStop,
    resetPosition = opts.resetPosition,
    openOptions = opts.openOptions,
    quickSettings = opts.quickSettings,
    smartSnap = opts.smartSnap,
    overlayInsets = opts.overlayInsets,
    onDragUpdate = opts.onDragUpdate,
    onDrop = opts.onDrop,
    overlayBelowFrame = opts.overlayBelowFrame,
    optionsString = opts.optionsString,
    optionsSection = opts.optionsSection,
    optionsTab = opts.optionsTab,
    optionsKey = opts.optionsKey,
  })

  return self:RefreshGhostMover(key)
end

function FrameUtil:RefreshAllGhostMovers()
  for key in pairs(GhostMoverHelpers) do
    self:RefreshGhostMover(key)
  end
end

function FrameUtil:ReleaseGhostMover(key)
  if not key then
    return false
  end

  local helper = GhostMoverHelpers[key]
  local ghost = helper and helper.frame or nil

  self:UnregisterMover(key)
  GhostMoverHelpers[key] = nil

  if ghost then
    ghost:Hide()
    ghost:EnableMouse(false)
    if ghost.EnableMouseWheel then
      ghost:EnableMouseWheel(false)
    end
    ghost:ClearAllPoints()
  end

  return true
end

function FrameUtil.CompleteProfileTransition()
  if FrameUtil._profileTransitionActive ~= true then
    return
  end

  FrameUtil._editModeConfigDB = nil
  FrameUtil._smartSnapDBRef = nil
  FrameUtil._InitEditModeConfig()
  EnsureSmartSnapLoaded()
  FrameUtil.ApplyMoverVisibilityPreset()
  FrameUtil:RefreshAllGhostMovers()

  if ns.TestMode.toolbar and ns.TestMode.toolbar:IsShown() then
    ns.TestMode:QueueToolbarRefresh()
  end

  local roots = {}
  for key in pairs(SmartSnapLinks) do
    local root = GetStableSmartSnapRoot(key)
    if root then
      roots[root.key] = true
    end
  end

  FrameUtil._profileTransitionActive = nil

  for rootKey in pairs(roots) do
    local root = MoversByKey[rootKey]
    if root then
      if InCombatLockdown() then
        QueueSmartSnapRuntimeRelayout(rootKey)
      else
        RelayoutSmartSnapCluster(root, false, false)
      end
    end
  end
end


function FrameUtil:RegisterMover(key, frame, opts)
  if not key or not frame then
    return
  end

  opts = type(opts) == "table" and opts or {}

  local smartSnap = opts.smartSnap
  if type(smartSnap) ~= "table"
    or type(smartSnap.family) ~= "string"
    or smartSnap.family == ""
  then
    opts.smartSnap = {
      family = "positionOnly",
    }
  end

  local label = opts.label
  if (not label or label == "") and frame and frame.GetName then
    label = frame:GetName()
  end
  if not label or label == "" then
    label = key
  end

  local entry = MoversByKey[key]
  local smartSnapRegistrationChanged = not entry or entry.frame ~= frame
  local editSessionHidden = entry and entry._editSessionHidden == true

  if not entry then
    entry = {
      key           = key,
      frame         = frame,
      opts          = opts,
      ghost         = opts.ghost and true or false,
      savePosition  = opts.savePosition or nil,
      onDragStop    = opts.onDragStop or nil,
      resetPosition = opts.resetPosition or nil,
      openOptions   = opts.openOptions or nil,
      quickSettings = opts.quickSettings or nil,
      label         = label,
    }

    local dx, dy = GetOffsetsForFrame(frame)
    entry.defaultX = dx
    entry.defaultY = dy

    MoversByKey[key] = entry
    table.insert(MoversList, entry)
  else
    if entry.frame ~= frame then
      MoversByFrame[entry.frame] = nil
      if editSessionHidden then
        SetMoverEditSessionHidden(entry, false)
      end

      ClearSmartSnapCandidate(entry)

      if entry.overlay then
        entry.overlay:Hide()
        entry.overlay:SetParent(nil)
      end
      entry.overlay = nil

      if entry.chrome then
        entry.chrome:Hide()
        entry.chrome:SetParent(nil)
      end
      entry.chrome = nil

      if entry.nudgeGroup then
        entry.nudgeGroup:Hide()
        entry.nudgeGroup:SetParent(nil)
      end
      entry.nudgeGroup = nil

      if entry.frame and entry.frame._puiMoverInit then
        entry.frame._puiMoverInit = nil
      end
      if frame then
        frame._puiMoverInit = nil
      end

      local dx, dy = GetOffsetsForFrame(frame)
      entry.defaultX = dx
      entry.defaultY = dy
    elseif entry.defaultX == nil or entry.defaultY == nil then
      local dx, dy = GetOffsetsForFrame(frame)
      entry.defaultX = dx
      entry.defaultY = dy
    end

    entry.frame = frame
    entry.opts  = opts
    entry.ghost = opts.ghost and true or false

    entry.savePosition  = opts.savePosition
    entry.onDragStop    = opts.onDragStop
    entry.resetPosition = opts.resetPosition
    entry.openOptions   = opts.openOptions
    entry.quickSettings = opts.quickSettings
    entry.label         = label

    if editSessionHidden and not entry._editSessionHidden then
      SetMoverEditSessionHidden(entry, true)
    end
  end

  MoversByFrame[frame] = entry
  ns.Registry.Movers[key] = { frame = frame, opts = entry.opts }
  entry._presetHidden = not FrameUtil.IsMoverVisibleInPreset(entry)

  EnsureSmartSnapLoaded()

  if ns.Flags.IsEditing then
    RefreshMoverEditSessionVisibility(entry)
    FrameUtil._OnMoverMoved(entry)
    FrameUtil._RefreshSelectionVisuals()
  end

  FrameUtil.RefreshSmartSnapState(key)

  if ns.TestMode.toolbar and ns.TestMode.toolbar:IsShown() then
    ns.TestMode:QueueToolbarRefresh()
  end

  if smartSnapRegistrationChanged
    and SmartSnapLinks[key]
    and not GhostMoverHelpers[key]
    and not FrameUtil._smartSnapApplying
  then
    QueueSmartSnapRuntimeRelayout(key)
  end
end

function FrameUtil:RefreshMoverOverlay(key)
  local entry = key and MoversByKey[key]
  if not entry then
    return
  end

  if entry.overlay then
    SyncOverlay(entry, entry.overlay)
  end
  if entry.chrome then
    SyncOverlay(entry, entry.chrome)
  end

  FrameUtil._OnMoverMoved(entry)
  FrameUtil._RefreshSelectionVisuals()
end


function FrameUtil:UnregisterMover(key)
  if not key then
    return
  end

  EnsureSmartSnapLoaded()

  local entry = MoversByKey[key]
  if not entry then
    return
  end

  FrameUtil.RemoveMoverEditHistory(key)

  local feedback = FrameUtil._frameSnapFeedback
  if feedback and (feedback.ownerKey == key or feedback.targetKey == key) then
    ClearFrameSnapFeedback()
  end
  local relayoutSmartSnap = SmartSnapLinks[key] ~= nil

  SetMoverEditSessionHidden(entry, false)

  -- Clear current selection if this was selected
  if FrameUtil._IsMoverSelected(entry) then
    FrameUtil._RemoveMoverSelection(entry)
  end

  ClearSmartSnapCandidate(entry)

  -- Kill overlay
  if entry.overlay then
    entry.overlay:Hide()
    entry.overlay:SetParent(nil)
    entry.overlay = nil
  end


  if entry.chrome then
    entry.chrome:Hide()
    entry.chrome:SetParent(nil)
    entry.chrome = nil
  end

  -- Kill nudge group
  if entry.nudgeGroup then
    entry.nudgeGroup:Hide()
    entry.nudgeGroup:SetParent(nil)
    entry.nudgeGroup = nil
  end

  -- Clear marker on the frame itself
  if entry.frame and entry.frame._puiMoverInit then
    entry.frame._puiMoverInit = nil
  end

  -- Remove from key map and global registry
  MoversByKey[key] = nil
  MoversByFrame[entry.frame] = nil
  ns.Registry.Movers[key] = nil

  -- Remove from linear list
  for i = #MoversList, 1, -1 do
    if MoversList[i] == entry then
      table.remove(MoversList, i)
      break
    end
  end

  FrameUtil.RefreshMoverLayering()

  if relayoutSmartSnap and not FrameUtil._smartSnapApplying then
    QueueSmartSnapRuntimeRelayout(key)
  end

  if ns.TestMode.toolbar and ns.TestMode.toolbar:IsShown() then
    ns.TestMode:QueueToolbarRefresh()
  end
end


function FrameUtil.SetKeyboardMovementEnabled(enable, noPersist)
  enable = not not enable

  if type(noPersist) == "table" then
    noPersist = not not noPersist.noPersist
  else
    noPersist = not not noPersist
  end

  FrameUtil._keyboardMoveEnabled = enable

  if not noPersist then
    FrameUtil._GetEditModeDB().keyboardMoveEnabled = enable
  end

  FrameUtil._UpdateEditDialogKeyboardState()
  ns.TestMode:QueueToolbarRefresh()
end

local function ApplyObjectiveTrackerMoverPosition(mover, tracker)
  if not mover or not tracker then
    return
  end

  local x, y = GetOffsetsForFrame(mover)
  tracker:ClearAllPoints()
  tracker:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function SaveObjectiveTrackerMoverPosition(mover, tracker)
  local manager = _G.EditModeManagerFrame
  if InCombatLockdown() or not manager or not manager:IsInitialized() then
    return
  end

  tracker:ClearFrameSnap()
  ApplyObjectiveTrackerMoverPosition(mover, tracker)
  tracker:OnSystemPositionChange()
  tracker:UpdateHeight()
  manager:SaveLayoutChanges()
end

function FrameUtil._EnsureObjectiveTrackerMover()
  local tracker = _G.ObjectiveTrackerFrame
  local manager = _G.EditModeManagerFrame
  if not tracker or not manager or not manager:IsInitialized() then
    return
  end

  FrameUtil:EnsureGhostMover("ObjectiveTracker", {
    label = "Objective Tracker",
    moduleKey = "objectiveTracker",
    moduleLabel = "Objective Tracker",
    useOverlayDrag = true,
    smartSnap = {
      family = "positionOnly",
    },
    liveFrame = function()
      return tracker
    end,
    getSize = function(_, liveFrame)
      return liveFrame:GetSize()
    end,
    getPoint = function(_, liveFrame)
      return liveFrame:GetPoint(1)
    end,
    shouldShow = function()
      return ns.Flags.IsEditing == true
    end,
    savePosition = function(mover)
      SaveObjectiveTrackerMoverPosition(mover, tracker)
    end,
    onDragStop = function()
      FrameUtil:RefreshGhostMover("ObjectiveTracker")
    end,
    onDragUpdate = function(mover)
      ApplyObjectiveTrackerMoverPosition(mover, tracker)
    end,
  })
end

function FrameUtil.RegisterEditModeParticipant(key, participant, order)
  if type(key) ~= "string"
    or key == ""
    or type(participant) ~= "table"
    or type(participant.OnEditModeChanged) ~= "function"
  then
    return false
  end

  ns.Registry.EditModeParticipants[key] = {
    key = key,
    order = tonumber(order) or 50,
    participant = participant,
  }

  if ns.Flags.IsEditing then
    participant:OnEditModeChanged(true)
  end

  return true
end

function FrameUtil.UnregisterEditModeParticipant(key)
  local registration = key and ns.Registry.EditModeParticipants[key] or nil
  if not registration then
    return false
  end

  if ns.Flags.IsEditing then
    registration.participant:OnEditModeChanged(false)
  end

  ns.Registry.EditModeParticipants[key] = nil
  return true
end

local function GetSortedEditModeParticipants()
  local participants = {}

  for _, registration in pairs(ns.Registry.EditModeParticipants) do
    participants[#participants + 1] = registration
  end

  _G.table.sort(participants, function(first, second)
    if first.order == second.order then
      return first.key < second.key
    end
    return first.order < second.order
  end)

  return participants
end

function FrameUtil.OnEditModeChanged(enable)
  FrameUtil.ClearEditHistory()
  enable = not not enable

  if not enable then
    ns.TestMode:SetActive(false, "edit-mode")
  end

  if enable then
    FrameUtil.SelectGroupMoverVisibilitySet()
  end

  local participants = GetSortedEditModeParticipants()
  for index = 1, #participants do
    participants[index].participant:OnEditModeChanged(enable)
  end

  FrameUtil._InitEditModeConfig()
  if enable then
    FrameUtil._EnsureObjectiveTrackerMover()
  end
  FrameUtil:RefreshAllGhostMovers()
  FrameUtil.RefreshMoverLayering()

  for _, entry in ipairs(MoversList) do
    if not enable then
      SetMoverEditSessionHidden(entry, false)
    end

    entry._presetHidden = not FrameUtil.IsMoverVisibleInPreset(entry)
    RefreshMoverEditSessionVisibility(entry)
  end

  if not enable then
    _G.wipe(SmartSnapQuickSettingsExpanded)
    ns.EditModeQuickSettings:Hide()
    EnsureSelectionSurface():SetShown(false)
    FrameUtil._ClearSelection()
    ClearSmartSnapCandidate(nil)
    ClearFrameSnapFeedback()
    FrameUtil.ShowGrid(false)
  end

  if enable then
    PlayDimmerFade(not FrameUtil._disableDimming)

    ShowEditDialog(true)
    EnsureSelectionSurface():SetShown(true)
    FrameUtil._UpdateEditDialogKeyboardState()
  else
    PlayDimmerFade(false)

    ShowEditDialog(false)
    if FrameUtil._coordinatePanel then
      FrameUtil._coordinatePanel:Hide()
    end

    if FrameUtil._keyboardMoveTempSession then
      FrameUtil._keyboardMoveTempSession = nil
      FrameUtil.SetKeyboardMovementEnabled(false, true)
    else
      FrameUtil._UpdateEditDialogKeyboardState()
    end
  end

  if enable then
    ns.TestMode:SetActive(true, "edit-mode")
    FrameUtil._RefreshSelectionVisuals()
  end
end

function Addon:IsEditMode()
  return ns.Flags.IsEditing
end

function Addon:SetEditMode(enable)
  enable = not not enable

  if enable == ns.Flags.IsEditing then
    return
  end

  if enable and InCombatLockdown() then
    self:Print("|cffff4444[PUI]|r Cannot enable Edit Mode while in combat.")
    return
  end

  if enable and self:IsBlizzardEditModeActive() then
    self:Print("|cffff4444[PUI]|r Cannot enable Edit Mode while Blizzard Edit Mode is active.")
    return
  end

  if enable then
    if FrameUtil._keyboardMoveTempSession then
      FrameUtil.SetKeyboardMovementEnabled(true, true)
    else
      FrameUtil.SetKeyboardMovementEnabled(false)
    end
  end

  ns.Flags.IsEditing = enable

  if enable then
    self:Print("Edit Mode |cff00ff00ON|r")
  else
    self:Print("Edit Mode |cffff0000OFF|r")
  end

  FrameUtil.OnEditModeChanged(enable)
end

do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
      if ns.Flags.IsEditing then
        Addon:SetEditMode(false)
      end
      return
    end

    FrameUtil._UpdateEditDialogKeyboardState()
    SchedulePendingSmartSnapRelayouts()
  end)
end

SLASH_PUIEDITMODEKEYBOARD1 = "/pek"
SlashCmdList["PUIEDITMODEKEYBOARD"] = function(msg)
  if Addon:IsEditMode() then
    Addon:SetEditMode(false)
    return
  end

  if InCombatLockdown() then
    Addon:Print("Cannot enable Edit Mode while in combat.")
    return
  end

  FrameUtil._keyboardMoveTempSession = true
  FrameUtil.SetKeyboardMovementEnabled(true, true)
  Addon:SetEditMode(true)
end
