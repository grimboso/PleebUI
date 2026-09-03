-- File: PUI_FrameUtil.lua

local ADDON_NAME, ns = ...

-- Core addon (created in PUI_Core.lua)
local Addon = ns.Addon
ns.Addon = Addon



-- Locals
local _G = _G
local UIParent = _G.UIParent
local CreateFrame = _G.CreateFrame
local LibStub = _G.LibStub
local InCombatLockdown = _G.InCombatLockdown
local IsAltKeyDown = _G.IsAltKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local IsShiftKeyDown = _G.IsShiftKeyDown
local GetCursorPosition = _G.GetCursorPosition
local GetTime = _G.GetTime
local C_Timer = _G.C_Timer
local UISpecialFrames = _G.UISpecialFrames
local YES = _G.YES
local NO = _G.NO
local select = _G.select
local type = _G.type
local tonumber = _G.tonumber
local tostring = _G.tostring
local pairs = _G.pairs
local ipairs = _G.ipairs
local next = _G.next
local wipe = _G.wipe
local setmetatable = _G.setmetatable
local table_insert = _G.table.insert
local table_remove = _G.table.remove
local table_sort = _G.table.sort
local hooksecurefunc = _G.hooksecurefunc
local string_format = _G.string.format
local math_abs = _G.math.abs
local math_min = _G.math.min
local math_max = _G.math.max
local math_floor = _G.math.floor
local math_ceil = _G.math.ceil
local math_pi = _G.math.pi

local Pixel  = ns.Pixel
local Round  = Pixel.Round
local FrameScale = ns.FrameScale
local LSM = ns.LSM

ns.FrameUtil = ns.FrameUtil or {}
local FrameUtil = ns.FrameUtil

-- Internal mover storage
local MoversByKey = {}
local MoversList  = {}
local GhostFrameState = setmetatable({}, { __mode = "k" })

-- Forward declarations used by ghost helpers / public API before the helper blocks below.
local ShowOverlay
local EnableDrag
local GhostMoverHelpers

-- Dimmer config
local DIM_FADE_DURATION = 1.5
FrameUtil._dimAlpha       = FrameUtil._dimAlpha or 0.7
FrameUtil._disableDimming = FrameUtil._disableDimming or false

-- Nudge config and selection state
local NUDGE_MIN, NUDGE_MAX, NUDGE_DEFAULT = 1, 10, 1

local SelectedEntry
local SelectedEntries = {}

FrameUtil._nudgeStep           = FrameUtil._nudgeStep or NUDGE_DEFAULT
FrameUtil._nudgePanel          = FrameUtil._nudgePanel or nil
FrameUtil._nudgeSlider         = FrameUtil._nudgeSlider or nil
FrameUtil._nudgeXInput         = FrameUtil._nudgeXInput or nil
FrameUtil._nudgeYInput         = FrameUtil._nudgeYInput or nil
FrameUtil._keyboardMoveEnabled = FrameUtil._keyboardMoveEnabled or false
FrameUtil._keyboardMoveCheck   = FrameUtil._keyboardMoveCheck or nil

-- New: collapsible settings panel state
FrameUtil._settingsCollapsed   = FrameUtil._settingsCollapsed or false
FrameUtil._instructionsCollapsed = FrameUtil._instructionsCollapsed or false
FrameUtil._keybindsCollapsed   = FrameUtil._keybindsCollapsed or false

-- Persistent config helpers (Edit Mode dialog state)
local function GetEditModeDB()
  Addon.db.profile.EditMode = Addon.db.profile.EditMode or {}
  return Addon.db.profile.EditMode
end

local _configInitialized = false
local function InitEditModeConfig()
  if _configInitialized then
    return
  end
  _configInitialized = true

  local db = GetEditModeDB()

  if db.keyboardMoveEnabled ~= nil then
    FrameUtil._keyboardMoveEnabled = not not db.keyboardMoveEnabled
  end
  if db.snapToGrid ~= nil then
    FrameUtil._snapToGrid = not not db.snapToGrid
  end
  if db.snapToFrame ~= nil then
    FrameUtil._snapToFrame = not not db.snapToFrame
  end
  if db.smartSnapEnabled ~= nil then
    FrameUtil._smartSnapEnabled = not not db.smartSnapEnabled
  end
  if db.snapTolerance then
    FrameUtil._snapTolerance = db.snapTolerance
  end
  if db.nudgeStep then
    FrameUtil._nudgeStep = db.nudgeStep
  end
  if db.gridSize then
    FrameUtil._gridSize = db.gridSize
  end
  if db.showGrid ~= nil then
    FrameUtil._showGrid = not not db.showGrid
  end
  if db.dimAlpha then
    FrameUtil._dimAlpha = db.dimAlpha
  end
  if db.disableDimming ~= nil then
    FrameUtil._disableDimming = not not db.disableDimming
  end
  if db.settingsCollapsed ~= nil then
    FrameUtil._settingsCollapsed = not not db.settingsCollapsed
  end
  if db.instructionsCollapsed ~= nil then
    FrameUtil._instructionsCollapsed = not not db.instructionsCollapsed
  end
  if db.keybindsCollapsed ~= nil then
    FrameUtil._keybindsCollapsed = not not db.keybindsCollapsed
  end
end

FrameUtil._GetEditModeDB      = GetEditModeDB
FrameUtil._InitEditModeConfig = InitEditModeConfig

local function ApplyGlobalEditFont(fs, sizeOverride, flagsOverride)
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

FrameUtil.ApplyGlobalEditFont = ApplyGlobalEditFont


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

local function MoveEntryTo(entry, x, y, silent)
  local frame = entry.frame

  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

  if not silent then
    if type(entry.onDragStop) == "function" then
      entry.onDragStop(frame, entry.key)
    end

    FrameUtil._OnMoverMoved(entry)
  end

end

FrameUtil._GetOffsetsForFrame = GetOffsetsForFrame

-- Shared mover helpers
local function MoverRound(v)
  return Round(tonumber(v) or 0)
end

local function GetMoverChromeStrata()
  return "HIGH"
end

local function GetSelectionSurfaceStrata()
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

local function ApplyMoverChromeLayer(entry)
  if not entry then
    return
  end

  local strata = GetMoverChromeStrata()

  if entry.overlay then
    entry.overlay:SetFrameStrata(strata)
  end

  if entry.chrome then
    entry.chrome:SetFrameStrata("HIGH")
    entry.chrome:SetFrameLevel(190)
  end

  if entry.nudgeGroup then
    entry.nudgeGroup:SetFrameStrata(strata)
  end

  if entry.frame and entry.frame.__puiEditMoverHelper then
    entry.frame:SetFrameStrata(strata)
  end
end

function FrameUtil.RefreshMoverLayering()
  for _, entry in ipairs(MoversList) do
    ApplyMoverChromeLayer(entry)
  end

  if FrameUtil._selectionSurface then
    FrameUtil._selectionSurface:SetFrameStrata(GetSelectionSurfaceStrata())
  end

  if FrameUtil._selectionBox then
    FrameUtil._selectionBox:SetFrameStrata(GetMoverChromeStrata())
  end
end


function FrameUtil.GetMoverOffsets(frame)
  local x, y = GetOffsetsForFrame(frame)
  return x or 0, y or 0
end

function FrameUtil.SetMoverFrameVisible(frame, show)
  if not frame then
    return
  end

  show = show and true or false

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

  owner.anchor:SetSize(totalWidth, totalHeight)

  if owner.mover then
    owner.mover:SetSize(totalWidth, totalHeight)
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

  if point == "TOPRIGHT" then
    local right = frame:GetRight()
    local top = frame:GetTop()
    if not right or not top then
      return 0, 0
    end
    return MoverRound(right - parentRight), MoverRound(top - parentTop)
  elseif point == "BOTTOMLEFT" then
    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    if not left or not bottom then
      return 0, 0
    end
    return MoverRound(left - parentLeft), MoverRound(bottom - parentBottom)
  elseif point == "BOTTOMRIGHT" then
    local right = frame:GetRight()
    local bottom = frame:GetBottom()
    if not right or not bottom then
      return 0, 0
    end
    return MoverRound(right - parentRight), MoverRound(bottom - parentBottom)
  end

  local left = frame:GetLeft()
  local top = frame:GetTop()
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

  local mover = owner.mover
  if not mover then
    mover = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    owner.mover = mover
  end

  local point = db.point or opts.defaultPoint or "CENTER"
  local relativeTo = _G[db.relativeTo or "UIParent"] or UIParent
  local relativePoint = db.relativePoint or opts.defaultRelativePoint or point
  local anchorPoint = opts.anchorPoint or point
  local anchorRelativePoint = opts.anchorRelativePoint or anchorPoint

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
    t:SetAllPoints(mover)
    mover.__pui_bg = t
  end
  mover.__pui_bg:SetColorTexture(0, 0, 0, opts.overlayBelowFrame and 0 or 0.35)

  ApplyHeaderMoverTheme(mover, opts.overlayBelowFrame == true)

  mover:ClearAllPoints()
  mover:SetPoint(point, relativeTo, relativePoint, MoverRound(db.x or 0), MoverRound(db.y or 0))
  mover:SetSize(MoverRound(width or 0), MoverRound(height or 0))
  mover.__puiUseOverlayDrag = opts.useOverlayDrag ~= false

  local editing = ns.Flags.IsEditing == true
  FrameUtil.SetMoverFrameVisible(mover, editing)

  anchor:ClearAllPoints()
  anchor:SetPoint(anchorPoint, mover, anchorRelativePoint, 0, 0)

  FrameUtil:RegisterMover(key, mover, {
    label = opts.label,
    optionsString = opts.optionsString,
    quickSettings = opts.quickSettings,
    overlayBelowFrame = opts.overlayBelowFrame,
    useOverlayDrag = true,
    onDragStop = function(frame)
      local x, y = FrameUtil.GetMoverOffsets(frame)

      db.point = "CENTER"
      db.relativeTo = "UIParent"
      db.relativePoint = "CENTER"
      db.x = MoverRound(x or 0)
      db.y = MoverRound(y or 0)

      if InCombatLockdown() then
        return
      end

      if owner.anchor and owner.mover then
        owner.anchor:ClearAllPoints()
        owner.anchor:SetPoint(anchorPoint, owner.mover, anchorRelativePoint, 0, 0)
      end

      if type(opts.onDragStop) == "function" then
        opts.onDragStop(frame, db, owner)
      end
    end,
  })

  return mover
end

function FrameUtil.EnsureGhostMovers(owner, opts)
  if InCombatLockdown() then
    return
  end

  owner.ghosts = owner.ghosts or {}

  for moverKey, label in pairs(opts.labels) do
    owner.ghosts[moverKey] = FrameUtil:EnsureGhostMover(opts.keyPrefix .. tostring(moverKey), {
      frameName = opts.frameNamePrefix .. tostring(moverKey),
      label = label,
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
      getSize = function()
        return opts.getSize(moverKey, owner)
      end,
      getPoint = function()
        return opts.getPoint(moverKey, owner)
      end,
      shouldShow = function()
        return opts.shouldShow(moverKey, owner)
      end,
      onDragStop = function(mover)
        opts.onGhostDragStop(moverKey, owner, mover)
      end,
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
  FrameUtil:RefreshAllGhostMovers()
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
local overlayFadeIn
local overlayFadeOut
local overlayFadeInAlpha
local overlayFadeOutAlpha

local function EnsureDimmer()
  if overlayFrame then
    return overlayFrame
  end

  local f = CreateFrame("Frame", "PUI_EditModeDimmer", UIParent)
  overlayFrame = f
  FrameUtil._dimmer = f  -- keep a reference on FrameUtil for later if needed

  -- Dim the world behind the UI without washing out Edit Mode widgets.
  f:SetFrameStrata("BACKGROUND")
  f:SetFrameLevel(0)
  f:SetAllPoints(UIParent)
  f:EnableMouse(false)
  f:Hide()
  f:SetAlpha(0)

  local tex = f:CreateTexture(nil, "BACKGROUND")
  tex:SetAllPoints()
  tex:SetColorTexture(0, 0, 0, 1) -- full black; frame alpha controls final opacity
  f._tex = tex

  local targetAlpha = FrameUtil._dimAlpha or 0.7

  -- Fade-in group: 0 -> targetAlpha, then stay
  local agIn = f:CreateAnimationGroup()
  overlayFadeIn = agIn
  local fadeIn = agIn:CreateAnimation("Alpha")
  overlayFadeInAlpha = fadeIn
  fadeIn:SetFromAlpha(0)
  fadeIn:SetToAlpha(targetAlpha)
  fadeIn:SetDuration(DIM_FADE_DURATION)
  fadeIn:SetSmoothing("IN_OUT")

  agIn:SetScript("OnPlay", function()
    f:SetAlpha(0)
    f:Show()
  end)

  agIn:SetScript("OnFinished", function()
    -- Stay at target alpha while Edit Mode is active
    f:SetAlpha(FrameUtil._dimAlpha or 0.7)
    f:Show()
  end)

  -- Fade-out group: targetAlpha -> 0, then hide
  local agOut = f:CreateAnimationGroup()
  overlayFadeOut = agOut
  local fadeOut = agOut:CreateAnimation("Alpha")
  overlayFadeOutAlpha = fadeOut
  fadeOut:SetFromAlpha(targetAlpha)
  fadeOut:SetToAlpha(0)
  fadeOut:SetDuration(DIM_FADE_DURATION)
  fadeOut:SetSmoothing("IN_OUT")

  agOut:SetScript("OnPlay", function()
    -- Ensure we start from the target alpha
    f:SetAlpha(FrameUtil._dimAlpha or 0.7)
    f:Show()
  end)

  agOut:SetScript("OnFinished", function()
    f:SetAlpha(0)
    f:Hide()
  end)

  return f
end

local function RefreshDimmerAlpha()
  local alpha = FrameUtil._dimAlpha or 0.7

  if overlayFadeInAlpha then
    overlayFadeInAlpha:SetToAlpha(alpha)
  end
  if overlayFadeOutAlpha then
    overlayFadeOutAlpha:SetFromAlpha(alpha)
  end

  if overlayFrame and overlayFrame:IsShown() then
    overlayFrame:SetAlpha(alpha)
  end
end

FrameUtil._RefreshDimmerAlpha = RefreshDimmerAlpha

local function PlayDimmerFade(show)
  local f = EnsureDimmer()

  RefreshDimmerAlpha()

  if show then
    if overlayFadeOut and overlayFadeOut:IsPlaying() then
      overlayFadeOut:Stop()
    end
    if overlayFadeIn then
      overlayFadeIn:Play()
    end
  else
    if overlayFadeIn and overlayFadeIn:IsPlaying() then
      overlayFadeIn:Stop()
    end
    if overlayFadeOut then
      overlayFadeOut:Play()
    end
  end
end


FrameUtil._gridSize      = FrameUtil._gridSize or 16
FrameUtil._showGrid      = FrameUtil._showGrid or false
FrameUtil._snapToGrid    = FrameUtil._snapToGrid or false
FrameUtil._snapToFrame   = FrameUtil._snapToFrame or false
FrameUtil._snapTolerance = FrameUtil._snapTolerance or 8
FrameUtil._smartSnapEnabled = FrameUtil._smartSnapEnabled ~= false

local GRID_SIZES = { 8, 16, 32, 64 }

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
  if not l or not r or not t or not b then return end
  return l, r, t, b
end

local function RoundToNearestGrid(value, size)
  local scaled = value / size
  if scaled >= 0 then
    return MoverRound(math_floor(scaled + 0.5) * size)
  end

  return MoverRound(math_ceil(scaled - 0.5) * size)
end

local function GetGridCornerDelta(cornerX, cornerY, parentLeft, parentTop, maxGridX, maxGridY, size)
  local gridOffsetX = RoundToNearestGrid(cornerX - parentLeft, size)
  local gridOffsetY = RoundToNearestGrid(parentTop - cornerY, size)

  gridOffsetX = math_max(0, math_min(gridOffsetX, maxGridX))
  gridOffsetY = math_max(0, math_min(gridOffsetY, maxGridY))

  local dx = (parentLeft + gridOffsetX) - cornerX
  local dy = (parentTop - gridOffsetY) - cornerY
  local distance = (dx * dx) + (dy * dy)

  return dx, dy, distance
end

local function ApplyGridSnap(entry)
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
    GetGridCornerDelta(fl, ft, parentLeft, parentTop, maxGridX, maxGridY, size)

  local dx, dy, distance =
    GetGridCornerDelta(fr, ft, parentLeft, parentTop, maxGridX, maxGridY, size)
  if distance < bestDistance then
    bestDx, bestDy, bestDistance = dx, dy, distance
  end

  dx, dy, distance =
    GetGridCornerDelta(fl, fb, parentLeft, parentTop, maxGridX, maxGridY, size)
  if distance < bestDistance then
    bestDx, bestDy, bestDistance = dx, dy, distance
  end

  dx, dy, distance =
    GetGridCornerDelta(fr, fb, parentLeft, parentTop, maxGridX, maxGridY, size)
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

local function ApplyFrameSnap(entry, live, ignoreEntries)
  if not entry or not entry.frame then return end
  if not FrameUtil._snapToFrame then return end

  local tol = FrameUtil._snapTolerance or 8

  local f = entry.frame
  local fl, fr, ft, fb = GetFrameEdges(f)
  if not fl then return end

  local bestDx, bestDy
  local bestPeer
  local bestAxis -- "H" or "V"

  for _, other in ipairs(MoversList) do
    if other ~= entry
       and not (ignoreEntries and ignoreEntries[other])
       and other.frame
       and other.frame:IsShown()
       and not other._editSessionHidden then
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
            end
          end

          local absDx2 = math_abs(dx2)
          if absDx2 <= tol then
            if not bestDx or absDx2 < math_abs(bestDx) then
              bestDx, bestDy, bestPeer, bestAxis = dx2, nil, other, "H"
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
            end
          end

          local absDy2 = math_abs(dy2)
          if absDy2 <= tol then
            if not bestDy or absDy2 < math_abs(bestDy) then
              bestDy, bestDx, bestPeer, bestAxis = dy2, nil, other, "V"
            end
          end
        end
      end
    end
  end

  if not bestPeer then
    return
  end

  local ox, oy = GetOffsetsForFrame(f)
  local nx, ny = ox, oy

  if bestAxis == "H" and bestDx then
    nx = ox + bestDx
  elseif bestAxis == "V" and bestDy then
    ny = oy + bestDy
  end

  if nx == ox and ny == oy then
    return
  end

  MoveEntryTo(entry, nx, ny, live and true or false)

  FrameUtil._InitEditModeConfig()
end

FrameUtil._ApplyGridSnap  = ApplyGridSnap
FrameUtil._ApplyFrameSnap = ApplyFrameSnap

local FinalizeMovedGroup

FrameUtil._smartSnapEnabled = FrameUtil._smartSnapEnabled ~= false
FrameUtil._SmartSnapLinks = FrameUtil._SmartSnapLinks or {}
FrameUtil._SmartSnapMasters = FrameUtil._SmartSnapMasters or {}
FrameUtil._smartSnapLoaded = FrameUtil._smartSnapLoaded or false
FrameUtil._smartSnapApplying = FrameUtil._smartSnapApplying or false
FrameUtil._pendingSmartSnapRelayouts = FrameUtil._pendingSmartSnapRelayouts or {}
FrameUtil._pendingSmartSnapRuntimeRelayouts = FrameUtil._pendingSmartSnapRuntimeRelayouts or {}

local SmartSnapLinks = FrameUtil._SmartSnapLinks
local SmartSnapMasters = FrameUtil._SmartSnapMasters
local PendingSmartSnapRelayouts = FrameUtil._pendingSmartSnapRelayouts
local PendingSmartSnapRuntimeRelayouts = FrameUtil._pendingSmartSnapRuntimeRelayouts
local SmartSnapRuntimeRelayoutScheduled = false
local SmartSnapWorldReady = false
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

  local migratedMasters = false
  for persistedKey, persistedMaster in pairs(db.masters) do
    if persistedMaster == true then
      SmartSnapMasters[persistedKey] = true
    elseif type(persistedMaster) == "string" then
      SmartSnapMasters[persistedMaster] = true
      migratedMasters = true
    end
  end

  if migratedMasters then
    wipe(db.masters)
    for masterKey in pairs(SmartSnapMasters) do
      if SmartSnapLinks[masterKey] then
        db.masters[masterKey] = true
      end
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
  if not entry or not entry.frame or entry._suppressed then
    return false
  end

  local smartSnap = GetSmartSnapOptions(entry)
  if smartSnap
    and type(smartSnap.isRuntimeActive) == "function"
    and smartSnap.isRuntimeActive(entry.frame, entry.key) ~= true
  then
    return false
  end

  local helper = GhostMoverHelpers and GhostMoverHelpers[entry.key]
  if not helper then
    return true
  end

  local opts = helper.opts or {}
  local ghost = helper.frame
  local liveFrame = opts.liveFrame
  if type(liveFrame) == "function" then
    liveFrame = liveFrame(ghost, entry.key, helper)
  end

  if type(opts.getSize) == "function" then
    local width, height = opts.getSize(ghost, liveFrame)
    return tonumber(width) ~= nil
      and tonumber(height) ~= nil
      and width > 0
      and height > 0
  end

  return liveFrame ~= nil
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

local function CanSmartSnap(first, second)
  if first == second or not first or not second then
    return false
  end
  if first._suppressed
    or second._suppressed
    or first._editSessionHidden
    or second._editSessionHidden
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
  if not firstEntry or not secondEntry then
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
    if current then
      cluster[current] = true
    end

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

function FrameUtil.GetSmartSnapCluster(keyOrEntry)
  local entry = type(keyOrEntry) == "table" and keyOrEntry or MoversByKey[keyOrEntry]
  return GetSmartSnapCluster(entry)
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
    if IsSmartSnapRuntimeEntryActive(current) and SmartSnapAllowsSizeSync(current) then
      cluster[current] = true
    end

    local peers = SmartSnapLinks[key]
    if peers then
      for peerKey, link in pairs(peers) do
        local peer = MoversByKey[peerKey]
        if SmartSnapLinkSyncsSize(current, peer, link) then
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
  local topology = GetSmartSnapTopologyKeys(startKey)
  local masterKey = GetSmartSnapClusterMasterKey(startKey)
  if masterKey and topology[masterKey] then
    local masterEntry = MoversByKey[masterKey]
    if IsSmartSnapRuntimeEntryActive(masterEntry) and GetSmartSnapGeometry(masterEntry) then
      return masterEntry, true
    end
  end

  local bestEntry
  local bestTop
  local bestLeft

  for key in pairs(topology) do
    local entry = MoversByKey[key]
    if IsSmartSnapRuntimeEntryActive(entry) then
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
  local visited = { [startKey] = true }
  local queue = {}

  for peerKey, link in pairs(SmartSnapLinks[startKey] or {}) do
    if link.relation == relation then
      queue[#queue + 1] = {
        key = peerKey,
        alignment = link.alignment,
        gap = NormalizeSmartSnapGap(link.gap),
        sideOffset = NormalizeSmartSnapSideOffset(link.sideOffset),
        syncSize = link.syncSize == true,
        syncDesign = link.syncDesign == true,
      }
    end
  end

  local index = 1
  while queue[index] do
    local current = queue[index]
    index = index + 1

    if not visited[current.key] then
      visited[current.key] = true

      local entry = MoversByKey[current.key]
      if IsSmartSnapRuntimeEntryActive(entry) then
        results[#results + 1] = {
          entry = entry,
          relation = relation,
          alignment = current.alignment,
          gap = current.gap,
          sideOffset = current.sideOffset,
          syncSize = current.syncSize,
          syncDesign = current.syncDesign,
        }
      else
        for peerKey, link in pairs(SmartSnapLinks[current.key] or {}) do
          if not visited[peerKey] and link.relation == relation then
            queue[#queue + 1] = {
              key = peerKey,
              alignment = current.alignment or link.alignment,
              gap = current.gap + NormalizeSmartSnapGap(link.gap),
              sideOffset = current.sideOffset + NormalizeSmartSnapSideOffset(link.sideOffset),
              syncSize = current.syncSize and link.syncSize == true,
              syncDesign = current.syncDesign and link.syncDesign == true,
            }
          end
        end
      end
    end
  end

  table_sort(results, function(first, second)
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
  local helper = GhostMoverHelpers and GhostMoverHelpers[entry.key]
  if not helper or not helper.frame then
    return
  end

  local opts = helper.opts or {}
  if type(opts.onRuntimePosition) == "function" then
    opts.onRuntimePosition(helper.frame, entry.key, helper)
    return
  end

  local liveFrame = opts.liveFrame
  if type(liveFrame) == "function" then
    liveFrame = liveFrame(helper.frame, entry.key, helper)
  end

  local positionFrame = liveFrame and (liveFrame.__puiPositionHolder or liveFrame) or nil
  if not positionFrame
    or positionFrame == helper.frame
    or not positionFrame.ClearAllPoints
    or not positionFrame.SetPoint
    or (positionFrame.IsForbidden and positionFrame:IsForbidden())
  then
    return
  end

  local x, y = GetRawOffsetsForFrame(helper.frame)
  positionFrame:ClearAllPoints()
  positionFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function RelayoutSmartSnapCluster(startEntry, finalize, syncSize)
  if not startEntry or not startEntry.key then
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
          moved[peer] = true
          queue[#queue + 1] = peer
        end
      end
    end
  end

  for _, step in ipairs(layoutSteps) do
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
    FinalizeMovedGroup(moved, finalizePrimary)
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

local function FlushPendingSmartSnapRelayouts()
  SmartSnapRuntimeRelayoutScheduled = false

  if InCombatLockdown()
    or not SmartSnapWorldReady
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
        syncSize = false,
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
  if SmartSnapRuntimeRelayoutScheduled
    or not SmartSnapWorldReady
    or InCombatLockdown()
  then
    return
  end

  SmartSnapRuntimeRelayoutScheduled = true
  C_Timer.After(0, FlushPendingSmartSnapRelayouts)
end

local function QueueSmartSnapRuntimeRelayout(key)
  if not key then
    return
  end

  PendingSmartSnapRuntimeRelayouts[key] = true
  SchedulePendingSmartSnapRelayouts()
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

  if FrameUtil._smartSnapApplying or not previousState or not SmartSnapLinks[key] then
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
  if not entry then
    return nil
  end

  EnsureSmartSnapLoaded()

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
  if not state or not state.entry then
    return false
  end

  local committed = false
  if state.suppressSnap then
    ClearSmartSnapCandidate(state.entry)
  else
    committed = FrameUtil.CommitSmartSnapCandidate(state.entry)
  end

  if not committed then
    FinalizeMovedGroup(state.group or { [state.entry] = true }, state.entry)
  end

  return committed
end

function FrameUtil.CancelExternalSmartSnapDrag(state)
  if not state or not state.entry then
    return false
  end

  ClearSmartSnapCandidate(state.entry)
  return true
end

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

  spec.controls[#spec.controls + 1] = {
    type = "heading",
    label = "Smart Snap",
  }

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
    table_sort(linkedMovers, function(first, second)
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

function FrameUtil.HideMoverForEditSession(key)
  local entry = MoversByKey[key]
  if not entry or not ns.Flags.IsEditing then
    return
  end

  entry._editSessionHidden = true
  ClearSmartSnapCandidate(entry)
  ShowOverlay(entry, false)
  EnableDrag(entry, false)

  if entry.nudgeGroup then
    entry.nudgeGroup:Hide()
  end

  if FrameUtil._IsMoverSelected(entry) then
    FrameUtil._RemoveMoverSelection(entry)
  end

  ns.EditModeQuickSettings:Hide()
end

function FrameUtil.SetMoverSuppressed(key, suppressed)
  local entry = MoversByKey[key]
  if not entry then
    return
  end

  entry._suppressed = suppressed == true or nil
  local visible = ns.Flags.IsEditing
    and not entry._suppressed
    and not entry._editSessionHidden
  if entry._ghostManaged then
    visible = visible and entry._ghostVisible and true or false
  end

  ShowOverlay(entry, visible)
  EnableDrag(entry, visible)

  if entry._suppressed and FrameUtil._IsMoverSelected(entry) then
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

local function GetSelectedMoverCount()
  local count = 0

  for entry in pairs(SelectedEntries) do
    if IsSelectableEntry(entry) then
      count = count + 1
    end
  end

  return count
end

local function RefreshSelectionVisuals()
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

  local selectedCount = GetSelectedMoverCount()

  for _, entry in ipairs(MoversList) do
    local visual = entry.chrome or entry.overlay
    if visual then
      if SelectedEntries[entry] and selectedCount > 1 then
        SetEditModeVisualColors(visual, 0.28, 1.00)
      elseif entry == SelectedEntry then
        SetEditModeVisualColors(visual, 0.38, 1.00)
      else
        SetEditModeVisualColors(visual, 0.16, 0.82)
      end
    end

    if entry.nudgeGroup and entry ~= SelectedEntry then
      entry.nudgeGroup:Hide()
    end
  end

  if SelectedEntry then
    FrameUtil._ShowNudgeControls(SelectedEntry, true)
  end

  FrameUtil._UpdateNudgeUI(SelectedEntry)
end

local function AddEntryToMoveGroup(group, entry, includeSmartSnap)
  if not IsSelectableEntry(entry) then
    return
  end

  group[entry] = true

  if includeSmartSnap then
    local cluster = FrameUtil.GetSmartSnapCluster(entry)
    for peer in pairs(cluster) do
      if IsSelectableEntry(peer) then
        group[peer] = true
      end
    end
  end
end

local function GetSelectedMoveGroup(primary, includeSmartSnap)
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

FinalizeMovedGroup = function(group, primary)
  if not group then
    return
  end

  local function FinalizeEntry(entry)
    if type(entry.onDragStop) == "function" then
      entry.onDragStop(entry.frame, entry.key)
    end

    FrameUtil._OnMoverMoved(entry)
  end

  if primary and group[primary] then
    FinalizeEntry(primary)
  end

  for entry in pairs(group) do
    if entry ~= primary then
      FinalizeEntry(entry)
    end
  end
end

local function MoveGroupBy(group, dx, dy, primary)
  if not group then
    return
  end

  dx = dx or 0
  dy = dy or 0

  for entry in pairs(group) do
    local x, y = GetRawOffsetsForFrame(entry.frame)
    MoveEntryTo(entry, x + dx, y + dy, true)
  end

  FinalizeMovedGroup(group, primary)
end

FrameUtil._IsMoverSelected = function(entry)
  return SelectedEntries[entry] == true
end

FrameUtil._GetSelectedMoverCount = GetSelectedMoverCount
FrameUtil._RefreshSelectionVisuals = RefreshSelectionVisuals
FrameUtil._GetSelectedMoveGroup = GetSelectedMoveGroup
FrameUtil._FinalizeMovedGroup = FinalizeMovedGroup
FrameUtil._MoveGroupBy = MoveGroupBy
FrameUtil._GetMoverEntry = function(key) return MoversByKey[key] end
FrameUtil._GetMoversList = function() return MoversList end
FrameUtil._MoveEntryTo = MoveEntryTo

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
  local x, y = GetCursorPosition()
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
  RefreshSelectionVisuals()
end

local function EnsureSelectionSurface()
  if FrameUtil._selectionSurface then
    return FrameUtil._selectionSurface
  end

  local surface = CreateFrame("Frame", "PUI_EditModeSelectionSurface", UIParent)
  FrameUtil._selectionSurface = surface

  surface:SetAllPoints(UIParent)
  surface:SetFrameStrata(GetSelectionSurfaceStrata())
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

function FrameUtil._SetSelectionSurfaceVisible(enable)
  local surface = EnsureSelectionSurface()
  surface:SetShown(enable and true or false)
end


local function UpdateEditDialogKeyboardState()
  local dlg = FrameUtil._editDialog
  if not dlg or InCombatLockdown() then
    return
  end

  dlg:EnableKeyboard(FrameUtil._keyboardMoveEnabled and true or false)
end


FrameUtil._UpdateEditDialogKeyboardState = UpdateEditDialogKeyboardState

local function CreatePleebCheckbox(parent, label, initial, onClick)
  local wrap = CreateFrame("Frame", nil, parent)
  wrap:SetSize(Round(220), Round(20))
  wrap:EnableMouse(true)

  local cb = LibStub("AceGUI-3.0"):Create("CheckBox")
  cb:SetFullWidth(true)
  cb:SetLabel(label or "")
  cb:SetValue(initial and true or false)

  local cbFrame = cb.frame
  cbFrame:SetParent(wrap)
  cbFrame:ClearAllPoints()
  cbFrame:SetPoint("LEFT", wrap, "LEFT", 0, 0)
  cbFrame:Show()

  wrap:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" then
      return
    end

    cb:SetValue(not cb:GetValue())
    onClick(wrap)
  end)

  cb:SetCallback("OnValueChanged", function()
    onClick(wrap)
  end)

  wrap._checkbox = cb
  wrap.SetChecked = function(_, value)
    cb:SetValue(value and true or false)
  end
  wrap.GetChecked = function()
    return cb:GetValue() and true or false
  end

  return wrap
end


local function EnsureEditDialog()
  if FrameUtil._editDialog and FrameUtil._editDialog:IsObjectType("Frame") then
    return FrameUtil._editDialog
  end

  local AceGUI = LibStub("AceGUI-3.0")

  FrameUtil._InitEditModeConfig()

  local f = CreateFrame("Frame", "PUI_EditModeFrame", UIParent, "BackdropTemplate")
  FrameUtil._editDialog = f

  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetSize(Round(440), Round(300))
  f:SetPoint("TOP", UIParent, "TOP", 0, -40)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop",  f.StopMovingOrSizing)

  table_insert(UISpecialFrames, f:GetName())

  ns.Theme.WidgetSkins.Frame(f)


  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  f.title = title
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
  title:SetText("Edit Mode")

  FrameUtil.ApplyGlobalEditFont(title, 18, nil)

  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.hint = hint
  hint:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
  hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 56)
  hint:SetJustifyH("LEFT")
  hint:SetJustifyV("TOP")
  hint:SetText(
    "Tips:\n" ..
    "• Left-click a mover to select it and open quick settings; click it again to close them.\n" ..
    "• Ctrl+Left-click adds or removes movers from the selection.\n" ..
    "• Left-drag empty space to box-select multiple movers.\n" ..
    "• Drag any selected mover to move the full selection.\n" ..
    "• Right-click opens that mover's settings.\n" ..
    "• Ctrl+Right-click resets the mover to its default position.\n" ..
    "• Alt+Right-click detaches Smart Snap links for that mover.\n" ..
    "• Shift+Left-drag detaches Smart Snap links and disables snapping for that drag.\n" ..
    "• Use the nudge arrows and X/Y boxes for precise positioning.\n" ..
    "• (Optional) Enable keyboard movement for Tab / Shift-Tab and arrow keys."
  )

  FrameUtil.ApplyGlobalEditFont(hint, 13, nil)

  local selFrame = CreateFrame("Frame", "PUI_EditModeSelectionFrame", f, "BackdropTemplate")
  FrameUtil._selectionFrame = selFrame
  selFrame:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -4)
  selFrame:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -4)
  selFrame:SetHeight(52)

  ns.Theme.WidgetSkins.Frame(selFrame)


  local selLabel = selFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  selLabel:SetPoint("LEFT", selFrame, "LEFT", 12, 2)
  selLabel:SetJustifyH("LEFT")
  selLabel:SetText("Selected: none")
  FrameUtil._selectedLabel = selLabel

  FrameUtil.ApplyGlobalEditFont(selLabel, 12, nil)

  local xBox = AceGUI:Create("EditBox")
  FrameUtil._nudgeXInput = xBox
  xBox:SetLabel("") -- label drawn manually next to box
  xBox:SetWidth(100)
  xBox:SetCallback("OnEnterPressed", function()
    FrameUtil._ApplyNudgeFromInputs()
  end)

  local xbFrame = xBox.frame
  xbFrame:SetParent(selFrame)
  xbFrame:ClearAllPoints()
  xbFrame:SetPoint("RIGHT", selFrame, "RIGHT", -140, 0)
  xbFrame:Show()
  ns.AceHooks.TakeOwnership(xBox)

  local xLabel = selFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  FrameUtil._nudgeXLabel = xLabel
  xLabel:SetPoint("RIGHT", xbFrame, "LEFT", -6, 0)
  xLabel:SetJustifyH("RIGHT")
  xLabel:SetText("X")
  FrameUtil.ApplyGlobalEditFont(xLabel, 12, nil)

  local yBox = AceGUI:Create("EditBox")
  FrameUtil._nudgeYInput = yBox
  yBox:SetLabel("") -- label drawn manually next to box
  yBox:SetWidth(100)
  yBox:SetCallback("OnEnterPressed", function()
    FrameUtil._ApplyNudgeFromInputs()
  end)

  local ybFrame = yBox.frame
  ybFrame:SetParent(selFrame)
  ybFrame:ClearAllPoints()
  ybFrame:SetPoint("RIGHT", selFrame, "RIGHT", -16, 0)
  ybFrame:Show()
  ns.AceHooks.TakeOwnership(yBox)

  local yLabel = selFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  FrameUtil._nudgeYLabel = yLabel
  yLabel:SetPoint("RIGHT", ybFrame, "LEFT", -6, 0)
  yLabel:SetJustifyH("RIGHT")
  yLabel:SetText("Y")
  FrameUtil.ApplyGlobalEditFont(yLabel, 12, nil)


  local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  FrameUtil._nudgePanel = panel
  panel:SetSize(Round(330), Round(250))
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", f, "TOPRIGHT", 8, 0)

  panel:SetFrameStrata("FULLSCREEN_DIALOG")
  panel:SetFrameLevel(f:GetFrameLevel() + 1)

  ns.Theme.WidgetSkins.Frame(panel)


  local snapHint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.snapHint = snapHint
  snapHint:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -6)
  snapHint:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -6)
  snapHint:SetJustifyH("CENTER")
  snapHint:SetText("Shift+Left-drag detaches a Smart Snap frame and disables snapping for that drag.")
  snapHint:SetShown(FrameUtil._smartSnapEnabled and true or false)

  FrameUtil.ApplyGlobalEditFont(snapHint, 11, nil)

  local colLeftX  = 16
  local colRightX = 170
  local rowTopY   = -24

  local dbGetter = FrameUtil._GetEditModeDB

  local kb = CreatePleebCheckbox(panel, "Keyboard movement", FrameUtil._keyboardMoveEnabled, function(self)
    FrameUtil._keyboardMoveEnabled = self:GetChecked() and true or false
    dbGetter().keyboardMoveEnabled = FrameUtil._keyboardMoveEnabled
    FrameUtil._UpdateEditDialogKeyboardState()
  end)
  FrameUtil._keyboardMoveCheck = kb
  kb:SetPoint("TOPLEFT", panel, "TOPLEFT", colLeftX, rowTopY + 2)

  local dimmingCheckbox = CreatePleebCheckbox(panel, "Disable screen dimming", FrameUtil._disableDimming, function(self)
    FrameUtil._disableDimming = self:GetChecked() and true or false
    dbGetter().disableDimming = FrameUtil._disableDimming

    if ns.Flags.IsEditing then
      if FrameUtil._disableDimming then
        PlayDimmerFade(false)
        if FrameUtil._dimmer then
          FrameUtil._dimmer:Hide()
        end
      else
        PlayDimmerFade(true)
      end
    end
  end)
  dimmingCheckbox:SetPoint("TOPLEFT", kb, "BOTTOMLEFT", 0, -10)

  local snapFrames = CreatePleebCheckbox(panel, "Snap to frames", FrameUtil._snapToFrame, function(self)
    FrameUtil._snapToFrame = self:GetChecked() and true or false
    dbGetter().snapToFrame = FrameUtil._snapToFrame
  end)
  snapFrames:SetPoint("TOPLEFT", dimmingCheckbox, "BOTTOMLEFT", 0, -10)
  snapFrames:SetChecked(FrameUtil._snapToFrame and true or false)

  local smartSnap = CreatePleebCheckbox(panel, "Smart Snap", FrameUtil._smartSnapEnabled, function(self)
    FrameUtil.SetSmartSnapEnabled(self:GetChecked())
    panel.snapHint:SetShown(FrameUtil._smartSnapEnabled)
  end)
  smartSnap:SetPoint("TOPLEFT", snapFrames, "BOTTOMLEFT", 0, -10)
  smartSnap:SetChecked(FrameUtil._smartSnapEnabled and true or false)

  local snapGrid = CreatePleebCheckbox(panel, "Snap to grid", FrameUtil._snapToGrid, function(self)
    FrameUtil._snapToGrid = self:GetChecked() and true or false
    dbGetter().snapToGrid = FrameUtil._snapToGrid
  end)
  snapGrid:SetPoint("TOPLEFT", smartSnap, "BOTTOMLEFT", 0, -10)



  panel.snapHint:SetShown(FrameUtil._smartSnapEnabled and true or false)

  local nudgeSlider = AceGUI:Create("PUI_Slider")
  FrameUtil._nudgeSlider = nudgeSlider
  nudgeSlider:SetLabel("Nudge step (pixels)")
  nudgeSlider:SetSliderValues(NUDGE_MIN, NUDGE_MAX, 1)
  nudgeSlider:SetValue(FrameUtil._nudgeStep or NUDGE_DEFAULT)
  nudgeSlider:SetCallback("OnValueChanged", function(_, _, value)
    FrameUtil._SetNudgeStepFromSlider(value)
  end)

  local nsFrame = nudgeSlider.frame
  nsFrame:SetParent(panel)
  nsFrame:ClearAllPoints()
  nsFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", colRightX, rowTopY)
  nsFrame:SetWidth(140)
  nsFrame:Show()
  ns.AceHooks.TakeOwnership(nudgeSlider)

  local tolSlider = AceGUI:Create("PUI_Slider")
  tolSlider:SetLabel("Snap distance (pixels)")
  tolSlider:SetSliderValues(2, 20, 1)
  tolSlider:SetValue(FrameUtil._snapTolerance or 8)
  tolSlider:SetCallback("OnValueChanged", function(_, _, value)
    FrameUtil.SetSnapTolerance(value)
  end)

  local tsFrame = tolSlider.frame
  tsFrame:SetParent(panel)
  tsFrame:ClearAllPoints()
  tsFrame:SetPoint("TOPLEFT", nsFrame, "BOTTOMLEFT", 0, -18)
  tsFrame:SetWidth(140)
  tsFrame:Show()
  ns.AceHooks.TakeOwnership(tolSlider)

  local fadeSlider = AceGUI:Create("PUI_Slider")
  fadeSlider:SetLabel("Fade to black alpha")
  fadeSlider:SetSliderValues(0, 1, 0.05)
  fadeSlider:SetValue(FrameUtil._dimAlpha or 0.7)
  fadeSlider:SetCallback("OnValueChanged", function(_, _, value)
    local v = tonumber(value) or 0.7
    if v < 0 then v = 0 elseif v > 1 then v = 1 end

    FrameUtil._dimAlpha = v
    dbGetter().dimAlpha = v
    FrameUtil._RefreshDimmerAlpha()
  end)

  local fsFrame = fadeSlider.frame
  fsFrame:SetParent(panel)
  fsFrame:ClearAllPoints()
  fsFrame:SetPoint("TOPLEFT", tsFrame, "BOTTOMLEFT", 0, -18)
  fsFrame:SetWidth(140)
  fsFrame:Show()
  ns.AceHooks.TakeOwnership(fadeSlider)

  local gridLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  gridLabel:SetPoint("TOPLEFT", snapGrid, "BOTTOMLEFT", 2, -6)
  gridLabel:SetText("Grid:")
  FrameUtil.ApplyGlobalEditFont(gridLabel, 11, nil)

  local gridDropdown = AceGUI:Create("Dropdown")
  gridDropdown:SetFullWidth(false)
  gridDropdown:SetWidth(90)
  local sizeList = {}
  for _, s in ipairs(GRID_SIZES) do
    sizeList[s] = tostring(s)
  end
  sizeList["off"] = "Off"

  gridDropdown:SetList(sizeList)
  gridDropdown:SetLabel("")
  gridDropdown:SetCallback("OnValueChanged", function(_, _, key)
    if key == "off" then
      FrameUtil.ShowGrid(false)
    else
      local val = tonumber(key)
      if val then
        FrameUtil.SetGridSize(val)
        FrameUtil.ShowGrid(true)
      end
    end

    local db = dbGetter()
    db.gridSize = FrameUtil._gridSize
    db.showGrid = FrameUtil._showGrid
  end)

  local gdFrame = gridDropdown.frame
  gdFrame:SetParent(panel)
  gdFrame:ClearAllPoints()
  gdFrame:SetPoint("TOPLEFT", gridLabel, "TOPRIGHT", 4, -2)
  gdFrame:SetWidth(90)
  gdFrame:Show()
  ns.AceHooks.TakeOwnership(gridDropdown)

  if FrameUtil._showGrid and FrameUtil._gridSize then
    gridDropdown:SetValue(FrameUtil._gridSize)
  else
    gridDropdown:SetValue("off")
  end

  local buttonRow = CreateFrame("Frame", nil, f)
  buttonRow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
  buttonRow:SetSize(Round(280), Round(32))

  -- IMPORTANT: CreateFrame wants "Button" as a STRING.
  local exitBtn = CreateFrame("Button", nil, buttonRow, "UIPanelButtonTemplate")
  f.exitBtn = exitBtn
  exitBtn:SetText("Exit Edit Mode")
  exitBtn:SetSize(Round(130), Round(28))
  exitBtn:SetPoint("RIGHT", buttonRow, "RIGHT", 0, 0)
  exitBtn:SetScript("OnClick", function()
    Addon:SetEditMode(false)
  end)

  local openBtn = CreateFrame("Button", nil, buttonRow, "UIPanelButtonTemplate")
  f.openBtn = openBtn
  openBtn:SetText("Open Blizzard Settings")
  openBtn:SetSize(Round(150), Round(28))
  openBtn:SetPoint("RIGHT", exitBtn, "LEFT", -8, 0)
  openBtn:SetScript("OnClick", function()
    _G.CooldownViewerSettings:ShowUIPanel(false)
  end)

  ns.Theme.WidgetSkins.UIButton(openBtn)
  ns.Theme.WidgetSkins.UIButton(exitBtn)

  local toggleBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  FrameUtil._settingsToggle = toggleBtn
  toggleBtn:SetSize(140, 22)
  toggleBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -10)
  toggleBtn:SetText("Edit Mode Settings")

  ns.Theme.WidgetSkins.UIButton(toggleBtn)

  local keybindsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.keybindsBtn = keybindsBtn
  keybindsBtn:SetSize(80, 22)
  keybindsBtn:SetPoint("RIGHT", toggleBtn, "LEFT", -8, 0)
  keybindsBtn:SetText("Keybinds")

  ns.Theme.WidgetSkins.UIButton(keybindsBtn)

  local minimizeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.minimizeBtn = minimizeBtn
  minimizeBtn:SetSize(24, 22)
  minimizeBtn:SetPoint("RIGHT", keybindsBtn, "LEFT", -8, 0)

  ns.Theme.WidgetSkins.UIButton(minimizeBtn)

  local function UpdateInstructionsVisibility()
    local collapsed = FrameUtil._instructionsCollapsed and true or false
    hint:SetShown(not collapsed)
    buttonRow:SetShown(not collapsed)
    f:SetHeight(Round(collapsed and 44 or 300))
    minimizeBtn:SetText(collapsed and "+" or "-")
  end

  minimizeBtn:SetScript("OnClick", function()
    FrameUtil._instructionsCollapsed = not FrameUtil._instructionsCollapsed
    local db = FrameUtil._GetEditModeDB()
    db.instructionsCollapsed = FrameUtil._instructionsCollapsed and true or false

    if FrameUtil._instructionsCollapsed then
      FrameUtil._settingsCollapsed = true
      FrameUtil._keybindsCollapsed = true
      db.settingsCollapsed = true
      db.keybindsCollapsed = true
    end

    UpdateInstructionsVisibility()
    FrameUtil._UpdateSettingsPanelVisibility()
    FrameUtil._UpdateKeyboardHelpPanelVisibility()
  end)

  UpdateInstructionsVisibility()


  local function UpdateSettingsPanelVisibility()
    local collapsed = FrameUtil._settingsCollapsed and true or false
    if panel then
      panel:SetShown(not collapsed)
    end
  end
  FrameUtil._UpdateSettingsPanelVisibility = UpdateSettingsPanelVisibility

  toggleBtn:SetScript("OnClick", function()
    FrameUtil._settingsCollapsed = not FrameUtil._settingsCollapsed
    local db = FrameUtil._GetEditModeDB()
    db.settingsCollapsed = FrameUtil._settingsCollapsed and true or false
    UpdateSettingsPanelVisibility()
  end)

  keybindsBtn:SetScript("OnClick", function()
    FrameUtil._keybindsCollapsed = not FrameUtil._keybindsCollapsed
    local db = FrameUtil._GetEditModeDB()
    db.keybindsCollapsed = FrameUtil._keybindsCollapsed and true or false
    FrameUtil._UpdateKeyboardHelpPanelVisibility()
  end)

  UpdateSettingsPanelVisibility()

  f:EnableKeyboard(FrameUtil._keyboardMoveEnabled and true or false)
  f:SetPropagateKeyboardInput(true)

  f:HookScript("OnKeyDown", function(self, key)
    if not FrameUtil._keyboardMoveEnabled then
      return
    end

    if key == "1" or key == "2" or key == "3"
       or key == "4" or key == "5" or key == "6"
       or key == "7" or key == "8" or key == "9" then
      FrameUtil._SetNudgeStepFromSlider(tonumber(key))
      return
    end

    if key == "TAB" then
      FrameUtil._SelectNextMover(not IsShiftKeyDown())
      return
    end

    if key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT" then
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
  end)

  f:HookScript("OnHide", function()
    if ns.Flags.IsEditing then
      Addon:SetEditMode(false)
    end
  end)

  return f
end


local function EnsureKeyboardHelpPanel()
  if FrameUtil._kbHelpPanel and FrameUtil._kbHelpPanel:IsObjectType("Frame") then
    return FrameUtil._kbHelpPanel
  end

  local f = FrameUtil._editDialog
  if not f or not f.IsObjectType or not f:IsObjectType("Frame") then
    return nil
  end

  local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  FrameUtil._kbHelpPanel = panel

  panel:SetSize(Round(260), Round(210))
  panel:ClearAllPoints()
  panel:SetPoint("TOPRIGHT", f, "TOPLEFT", -8, 0)

  panel:SetFrameStrata("FULLSCREEN_DIALOG")
  panel:SetFrameLevel(f:GetFrameLevel() + 1)

  ns.Theme.WidgetSkins.Frame(panel)


  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -10)
  title:SetJustifyH("LEFT")
  title:SetText("Keyboard shortcuts")

  FrameUtil.ApplyGlobalEditFont(title, 14, nil)

  local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  text:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 12)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("TOP")
  text:SetText(
    "• /pek: Enter Edit Mode with keyboard movement.\n" ..
    "• ESC: Exit Edit Mode.\n" ..
    "• Tab / Shift-Tab: Cycle movers.\n" ..
    "• Arrow keys: Nudge selected frame.\n" ..
    "• 1–9: Set nudge step (pixels)."
  )

  FrameUtil.ApplyGlobalEditFont(text, 11, nil)

  return panel
end

FrameUtil.EnsureKeyboardHelpPanel = EnsureKeyboardHelpPanel

local function UpdateKeyboardHelpPanelVisibility()
  local panel = EnsureKeyboardHelpPanel()
  if not panel then
    return
  end

  panel:SetShown(
    ns.Flags.IsEditing
      and not FrameUtil._keybindsCollapsed
  )
end

FrameUtil._UpdateKeyboardHelpPanelVisibility = UpdateKeyboardHelpPanelVisibility

-- Edit dialog
local function ShowEditDialog(show)
  if not show then
    local dlg = FrameUtil._editDialog
    if dlg then
      dlg:Hide()
    end
    return
  end

  local dlg = EnsureEditDialog()
  FrameUtil._UpdateEditDialogKeyboardState()
  dlg:Show()
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

  entry.overlay = o
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

local function BuildQuickSettingsSpecForEntry(entry, providerFrame)
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

function FrameUtil.GetMoverQuickSettingsSpec(key, providerFrame)
  return BuildQuickSettingsSpecForEntry(MoversByKey[key], providerFrame)
end

local function OpenQuickSettingsForEntry(entry, frame)
  local anchor = entry.overlay or frame
  local spec = BuildQuickSettingsSpecForEntry(entry, frame)
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

      if IsAltKeyDown() then
        if entry.key then
          FrameUtil.ClearSmartSnapForKey(entry.key)
          Addon:Print("|cffd0ff00[PUI]|r Detached Smart Snap links for '" .. tostring(entry.label or entry.key) .. "'.")
        end
        return
      end

      if IsControlKeyDown() then
        if type(entry.resetPosition) == "function" then
          entry.resetPosition(frame, entry.key)
        elseif entry.opts and type(entry.opts.resetPosition) == "function" then
          entry.opts.resetPosition(frame, entry.key)
        else
          Addon:Print("|cffd0ff00[PUI]|r No resetPosition handler for mover '" .. tostring(entry.key) .. "'.")
        end

        FrameUtil._OnMoverMoved(entry)
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
      local now = GetTime()
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
    else
      FrameUtil.UpdateSmartSnapCandidate(entry, entry._dragMoveGroup)
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

        FrameUtil._ApplyFrameSnap(entry, true, moveGroup)
        FrameUtil._ApplyGridSnap(entry)

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
          if type(peer.onDragStop) == "function" then
            peer.onDragStop(peer.frame, peer.key)
          end
          FrameUtil._OnMoverMoved(peer)
        end
      end
      FrameUtil._OnMoverMoved(entry)
    end

    entry._dragMoveGroup = nil
    entry._dragPeersStart = nil
    entry._dragStartX = nil
    entry._dragStartY = nil
    entry._dragSnapSuppressed = nil
    entry.__puiShiftDrag = nil
  end)
end

EnableDrag = function(entry, enable)
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

    if dragOverlay and dragOverlay.EnableMouse then
      dragOverlay:EnableMouse(false)
    end

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
  g.up    = CreateArrowTextureButton(g, atlasNormal, atlasPressed, math_pi / 2)
  g.right = CreateArrowTextureButton(g, atlasNormal, atlasPressed, math_pi)
  g.down  = CreateArrowTextureButton(g, atlasNormal, atlasPressed, (math_pi * 3) / 2)

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

      local now = GetTime()
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
    g._holdPending = true
    g._holdDx = dx or 0
    g._holdDy = dy or 0

    g._holdDelayTimer = C_Timer.NewTimer(HOLD_DELAY, function()
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

  local onePixel = FrameScale:BestOnePixel()
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

  local slider = FrameUtil._nudgeSlider
  if slider and slider.GetValue then
    local sliderValue = tonumber(slider:GetValue()) or NUDGE_DEFAULT
    if math_floor(sliderValue + 0.5) ~= v then
      slider:SetValue(v)
    end
  end

  local db = FrameUtil._GetEditModeDB()
  db.nudgeStep = v
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
  local xText = string_format("%.0f", x)
  local yText = string_format("%.0f", y)
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

  if FrameUtil._nudgeSlider then
    FrameUtil._nudgeSlider:SetValue(FrameUtil._nudgeStep or NUDGE_DEFAULT)
  end
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

  local width, height
  if type(opts.getSize) == "function" then
    width, height = opts.getSize(ghost, liveFrame)
  elseif liveFrame and liveFrame.GetSize then
    width, height = liveFrame:GetSize()
  end

  if width and height and width > 0 and height > 0 then
    ghost:SetSize(Round(width), Round(height))
  end

  ghost:ClearAllPoints()

  local point, relativeTo, relativePoint, x, y
  if type(opts.getPoint) == "function" then
    point, relativeTo, relativePoint, x, y = opts.getPoint(ghost, liveFrame)
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
    shouldShow = opts.shouldShow(ghost, liveFrame) and true or false
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
      local moverVisible = entry._ghostVisible
        and not entry._suppressed
        and not entry._editSessionHidden

      ShowOverlay(entry, moverVisible)
      EnableDrag(entry, moverVisible)

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
    ghost = opts.ghost and true or false,
    useOverlayDrag = opts.useOverlayDrag ~= false,
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

  if not entry then
    entry = {
      key           = key,
      frame         = frame,
      opts          = opts,
      ghost         = opts.ghost and true or false,
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

    entry.onDragStop    = opts.onDragStop
    entry.resetPosition = opts.resetPosition
    entry.openOptions   = opts.openOptions
    entry.quickSettings = opts.quickSettings
    entry.label         = label
  end

  ns.Registry.Movers[key] = { frame = frame, opts = entry.opts }

  EnsureSmartSnapLoaded()

  if ns.Flags.IsEditing then
    local moverVisible = not entry._suppressed
      and not entry._editSessionHidden
    if entry._ghostManaged then
      moverVisible = moverVisible and entry._ghostVisible and true or false
    end

    ShowOverlay(entry, moverVisible)
    EnableDrag(entry, moverVisible)
    FrameUtil._OnMoverMoved(entry)
    FrameUtil._RefreshSelectionVisuals()
  end

  FrameUtil.RefreshSmartSnapState(key)

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

  local relayoutSmartSnap = SmartSnapLinks[key] ~= nil

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
  ns.Registry.Movers[key] = nil

  -- Remove from linear list
  for i = #MoversList, 1, -1 do
    if MoversList[i] == entry then
      table.remove(MoversList, i)
      break
    end
  end

  if relayoutSmartSnap and not FrameUtil._smartSnapApplying then
    QueueSmartSnapRuntimeRelayout(key)
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

  local check = FrameUtil._keyboardMoveCheck
  if check then
    check:SetChecked(enable)
  end

  if not noPersist then
    FrameUtil._GetEditModeDB().keyboardMoveEnabled = enable
  end

  FrameUtil._UpdateEditDialogKeyboardState()
end

local OBJECTIVE_TRACKER_MOVER_KEY = "ObjectiveTracker"

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
  FrameUtil:RefreshGhostMover(OBJECTIVE_TRACKER_MOVER_KEY)
end

local function EnsureObjectiveTrackerMover()
  local tracker = _G.ObjectiveTrackerFrame
  local manager = _G.EditModeManagerFrame
  if not tracker or not manager or not manager:IsInitialized() then
    return
  end

  FrameUtil:EnsureGhostMover(OBJECTIVE_TRACKER_MOVER_KEY, {
    label = "Objective Tracker",
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
    onDragStop = function(mover)
      SaveObjectiveTrackerMoverPosition(mover, tracker)
    end,
    onDragUpdate = function(mover)
      ApplyObjectiveTrackerMoverPosition(mover, tracker)
    end,
  })
end

function FrameUtil.OnEditModeChanged(enable)
  enable = not not enable

  if not enable then
    ns.TestMode:SetActive(false, "edit-mode")
  end

  for _, participant in pairs(ns.Registry.EditModeParticipants) do
    if type(participant.OnEditModeChanged) == "function" then
      participant:OnEditModeChanged(enable)
    end
  end

  FrameUtil._InitEditModeConfig()
  if enable then
    EnsureObjectiveTrackerMover()
  end
  FrameUtil:RefreshAllGhostMovers()
  FrameUtil.RefreshMoverLayering()

  for _, entry in ipairs(MoversList) do
    local moverVisible = enable
      and not entry._suppressed
      and not entry._editSessionHidden
    if entry._ghostManaged then
      moverVisible = moverVisible and entry._ghostVisible and true or false
    end

    ShowOverlay(entry, moverVisible)
    EnableDrag(entry, moverVisible)

    if not enable then
      entry._editSessionHidden = nil

      if entry.nudgeGroup then
        entry.nudgeGroup:Hide()
      end
    end
  end

  if not enable then
    ns.EditModeQuickSettings:Hide()
    FrameUtil._SetSelectionSurfaceVisible(false)
    FrameUtil._ClearSelection()
    ClearSmartSnapCandidate(nil)
    FrameUtil.ShowGrid(false)
  end

  if enable then
    if not FrameUtil._disableDimming then
      PlayDimmerFade(true)
    elseif FrameUtil._dimmer then
      FrameUtil._dimmer:Hide()
    end

    ShowEditDialog(true)
    FrameUtil._SetSelectionSurfaceVisible(true)
    FrameUtil._UpdateSettingsPanelVisibility()
    FrameUtil._UpdateKeyboardHelpPanelVisibility()
    FrameUtil._UpdateEditDialogKeyboardState()
  else
    if not FrameUtil._disableDimming then
      PlayDimmerFade(false)
    elseif FrameUtil._dimmer then
      FrameUtil._dimmer:Hide()
    end

    ShowEditDialog(false)

    if FrameUtil._nudgePanel then
      FrameUtil._nudgePanel:Hide()
    end
    if FrameUtil._kbHelpPanel then
      FrameUtil._kbHelpPanel:Hide()
    end

    if FrameUtil._keyboardMoveTempSession then
      FrameUtil._keyboardMoveTempSession = nil
      FrameUtil.SetKeyboardMovementEnabled(false, true)
    else
      FrameUtil._UpdateEditDialogKeyboardState()
    end
  end

  local unitFrames = ns.Modules.UnitFrames
  unitFrames:SetMoversVisible(enable)
  ns.Modules.PartyFrames:SetMoversVisible(enable)
  ns.Modules.RaidFrames:SetMoversVisible(enable)
  ns.Modules.CastBar:SetMoversVisible(enable)

  ns.Modules.Dragonriding:SetMoversVisible(enable)

  if enable then
    ns.TestMode:SetActive(true, "edit-mode")
    ns.Modules.PlayerBuffs:EnsureMovers()

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
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
      SmartSnapWorldReady = true
      SchedulePendingSmartSnapRelayouts()
      return
    end

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
