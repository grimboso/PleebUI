-- File: PUI_Dragonriding.lua

local ADDON_NAME, ns = ...
local Addon  = ns.Addon
local LSM = ns.LSM
local Theme     = ns.Theme
local BarWidget = ns.BarWidget
local FrameUtil = ns.FrameUtil
local FrameScale = ns.FrameScale
local Round = ns.Pixel.Round
local Dragonriding = Addon:NewModule("Dragonriding", "NumyAceEvent-3.0")
ns.Modules.Dragonriding = Dragonriding
ns.Registry.Modules.Dragonriding = Dragonriding


local P = ns.Pleebug:DropIn(Dragonriding, { name = "Modules.Dragonriding" })

local VIGOR_SPELL_ID = 372608
local SECOND_WIND_SPELL_ID = 425782
local WHIRLING_SURGE_SPELL_ID = 361584

local function _SeedDB(root)
  root.dragonriding = root.dragonriding or {}
  local db = root.dragonriding

  if db.enabled == nil then db.enabled = true end

  if db.width   == nil then db.width   = 300 end
  if db.height  == nil then db.height  = 20 end
  if db.texture == nil then db.texture = "Pleebar" end

  if db.showSegments == nil then db.showSegments = true end
  if db.segmentThickness == nil then db.segmentThickness = 2 end

  if db.showVigorText == nil then db.showVigorText = true end
  if db.showSpeedText == nil then db.showSpeedText = true end

  if db.point == nil then db.point = "CENTER" end
  if db.relativeTo == nil then db.relativeTo = "UIParent" end
  if db.relativePoint == nil then db.relativePoint = "CENTER" end
  if db.x == nil then db.x = 0 end
  if db.y == nil then db.y = 350 end

  -- Main bar colors
  db.barColor    = db.barColor    or { 0.2, 0.8, 1.0, 1.0 }
  db.bgColor     = db.bgColor     or { 0.08, 0.08, 0.08, 0.85 }
  db.borderColor = db.borderColor or { 0, 0, 0, 1 }

  -- Second Wind mini bar (below)
  if db.swEnabled == nil then db.swEnabled = true end
  if db.swHeight  == nil then db.swHeight  = 8 end
  if db.swGap     == nil then db.swGap     = 2 end
  db.swColor = db.swColor or { 1.0, 0.8, 0.2, 1.0 }

  -- Whirling Surge cooldown bar (below Second Wind)
  if db.wsEnabled == nil then db.wsEnabled = true end
  db.wsColor = db.wsColor or { 0.65, 0.45, 1.0, 1.0 }

  return db
end

local _DB_ROOT
local _DB_CACHED
local _runtime = {}

local function GetDB()
  local root = Addon.db.profile

  -- Avoid reseeding on every call
  if root == _DB_ROOT and _DB_CACHED then
    return _DB_CACHED
  end

  _DB_ROOT = root
  _DB_CACHED = _SeedDB(root)
  return _DB_CACHED
end

local function _CompileRuntimeConfig(db)
  _runtime.enabled = db.enabled ~= false
  _runtime.showSegments = db.showSegments ~= false
  _runtime.segmentThickness = tonumber(db.segmentThickness) or 2
  if _runtime.segmentThickness < 1 then
    _runtime.segmentThickness = 1
  end
  _runtime.showVigorText = db.showVigorText == true
  _runtime.showSpeedText = db.showSpeedText == true
  _runtime.swEnabled = db.swEnabled ~= false
  _runtime.wsEnabled = db.wsEnabled ~= false
end

local frame
local vigorBar, vigorRechargeBar, bgTex, borderFrame
local segmentMarkers = {}
local vigorText, speedText

-- Second Wind mini bar (below)
local swBar, swRechargeBar, swBgTex, swBorderFrame
local swSegmentMarkers = {}

-- Whirling Surge cooldown bar (below Second Wind)
local wsBar, wsBgTex, wsBorderFrame

-- Ghost mover (visible in Edit Mode even when Skyriding UI is hidden)
local moverGhost
local moverGhostBg

-- Speed text driver only. Charge and cooldown bars are duration-object driven.
local SPEED_UPDATE_STEP = 0.25

local _Tick -- forward declare
local _BuildStatusbarList

local _textTicker
local _ticking = false
local _spellEventsRegistered = false

local function _CancelTextTicker()
  if _textTicker then
    _textTicker:Cancel()
  end
  _textTicker = nil
end

local function _SetTicking(want)
  want = want and true or false

  if want == _ticking then
    return
  end

  _ticking = want

  if not want then
    _CancelTextTicker()
    return
  end

  _textTicker = C_Timer.NewTicker(SPEED_UPDATE_STEP, function()
    _Tick()
  end)
end


local function _GetVigorInfo()
  local data = C_Spell.GetSpellCharges(VIGOR_SPELL_ID)
  if not data then
    return 0, 6, 0, 0, 1
  end

  return tonumber(data.currentCharges) or 0,
         tonumber(data.maxCharges) or 6,
         tonumber(data.cooldownStartTime) or 0,
         tonumber(data.cooldownDuration) or 0,
         tonumber(data.chargeModRate) or 1
end

local function _GetSecondWindInfo()
  local data = C_Spell.GetSpellCharges(SECOND_WIND_SPELL_ID)
  if not data then
    return 0, 0, 0, 0, 1
  end

  return tonumber(data.currentCharges) or 0,
         tonumber(data.maxCharges) or 0,
         tonumber(data.cooldownStartTime) or 0,
         tonumber(data.cooldownDuration) or 0,
         tonumber(data.chargeModRate) or 1
end


local function _GetGlidingInfo()
  local gliding, _, speed = C_PlayerInfo.GetGlidingInfo()
  local forwardSpeed = tonumber(speed) or 0

  local displaySpeed = 0
  if forwardSpeed > 0 then
    displaySpeed = forwardSpeed * 14.285
  end

  return gliding and true or false, displaySpeed
end

local _WS_INTERP = Enum.StatusBarInterpolation.ExponentialEaseOut
local _TIMER_DIRECTION_ELAPSED = Enum.StatusBarTimerDirection.ElapsedTime
local _CHARGE_INTERP = Enum.StatusBarInterpolation.ExponentialEaseOut

local function _ClearRechargeBar(rechargeBar)
  if not rechargeBar then
    return
  end

  BarWidget.StopTimerBar(rechargeBar)
  rechargeBar:Hide()
end

local function _LayoutRechargeBar(baseBar, rechargeBar, maxCharges)
  if not baseBar or not rechargeBar then
    return false
  end

  maxCharges = tonumber(maxCharges) or 0
  if maxCharges <= 0 then
    return false
  end

  local trackerTexture = baseBar:GetStatusBarTexture()
  if not trackerTexture then
    return false
  end

  local width = baseBar:GetWidth()
  if rechargeBar.__puiDragonridingLayoutTexture == trackerTexture
    and rechargeBar.__puiDragonridingLayoutMax == maxCharges
    and rechargeBar.__puiDragonridingLayoutWidth == width
  then
    return true
  end

  rechargeBar.__puiDragonridingLayoutTexture = trackerTexture
  rechargeBar.__puiDragonridingLayoutMax = maxCharges
  rechargeBar.__puiDragonridingLayoutWidth = width

  rechargeBar:ClearAllPoints()
  rechargeBar:SetPoint("LEFT", trackerTexture, "RIGHT", 0, 0)
  rechargeBar:SetPoint("TOP", baseBar, "TOP", 0, 0)
  rechargeBar:SetPoint("BOTTOM", baseBar, "BOTTOM", 0, 0)
  rechargeBar:SetWidth(Round(width / maxCharges))
  return true
end

local function _ApplyChargeBarState(baseBar, rechargeBar, spellID, currentCharges, maxCharges, charging)
  if not baseBar or not rechargeBar then
    return
  end

  maxCharges = tonumber(maxCharges) or 0
  if maxCharges <= 0 then
    baseBar:SetMinMaxValues(0, 1)
    baseBar:SetValue(0)
    _ClearRechargeBar(rechargeBar)
    return
  end

  baseBar:SetMinMaxValues(0, maxCharges)
  baseBar:SetValue(currentCharges)

  if charging ~= true or not _LayoutRechargeBar(baseBar, rechargeBar, maxCharges) then
    _ClearRechargeBar(rechargeBar)
    return
  end

  local durationObject = C_Spell.GetSpellChargeDuration(spellID)
  if not durationObject then
    _ClearRechargeBar(rechargeBar)
    return
  end

  rechargeBar:SetMinMaxValues(0, 1)
  rechargeBar:SetTimerDuration(durationObject, _CHARGE_INTERP, _TIMER_DIRECTION_ELAPSED)
  rechargeBar:Show()
end

-- Marker refresh (set-and-forget)
local _RefreshMarkerLayout -- forward declare
local _vigorMarkerSig = { max = nil, w = nil, h = nil, show = nil, th = nil }
local _swMarkerSig    = { max = nil, w = nil, h = nil, show = nil, th = nil }

-- Cached state (avoid C_* polling in the ticker)
local _cache = {
  gliding = false,
  speed   = 0,

  vigorCur   = 0,
  vigorMax   = 6,
  vigorStart = 0,
  vigorDur   = 0,
  vigorRate  = 1,

  swCur   = 0,
  swMax   = 0,
  swStart = 0,
  swDur   = 0,
  swRate  = 1,
}

local function _RefreshGlidingState()
  local gliding, speed = _GetGlidingInfo()
  _cache.gliding = gliding and true or false
  _cache.speed   = tonumber(speed) or 0
end

local function _RefreshVigorState()
  local cur, max, start, dur, rate = _GetVigorInfo()
  _cache.vigorCur   = tonumber(cur) or 0
  _cache.vigorMax   = tonumber(max) or 6
  _cache.vigorStart = tonumber(start) or 0
  _cache.vigorDur   = tonumber(dur) or 0
  _cache.vigorRate  = tonumber(rate) or 1
end

local function _RefreshSecondWindState()
  local cur, max, start, dur, rate = _GetSecondWindInfo()
  _cache.swCur   = tonumber(cur) or 0
  _cache.swMax   = tonumber(max) or 0
  _cache.swStart = tonumber(start) or 0
  _cache.swDur   = tonumber(dur) or 0
  _cache.swRate  = tonumber(rate) or 1
end

local function _RefreshTickerState(runtime)
  _SetTicking(
    runtime.enabled
    and runtime.showSpeedText
    and (_cache.gliding and true or false)
  )
end


local function _ApplyStyle()
  if not frame then return end
  local db = GetDB()

  local wMain = Round(tonumber(db.width) or 300)
  local hMain = Round(tonumber(db.height) or 20)

  frame:SetSize(wMain, hMain)

  local isEditing = ns.Flags.IsEditing and true or false

  -- In Edit Mode: FrameUtil owns moverGhost position. The bar follows the ghost.
  frame:ClearAllPoints()
  if isEditing and moverGhost then
    frame:SetPoint("CENTER", moverGhost, "CENTER", 0, 0)
  else
    frame:SetPoint(
      db.point or "CENTER",
      _G[db.relativeTo or "UIParent"] or UIParent,
      db.relativePoint or "CENTER",
      Round(tonumber(db.x) or 0),
      Round(tonumber(db.y) or 350)
    )
  end

  -- Keep ghost mover sized to match the full widget footprint.
  -- DO NOT re-anchor it in Edit Mode (FrameUtil is dragging it live).
  if moverGhost then
    local w   = wMain
    local h   = hMain
    local gap = tonumber(db.swGap) or 2
    local swH = tonumber(db.swHeight) or 8
    if gap < 0 then gap = 0 end
    if swH < 1 then swH = 1 end
    gap = Round(gap)
    swH = Round(swH)

    local anyBelow = false

    if db.swEnabled ~= false then
      h = h + gap + swH
      anyBelow = true
    end

    if db.wsEnabled ~= false then
      h = h + (anyBelow and gap or gap) + swH
      anyBelow = true
    end

    moverGhost:SetSize(w, h)

    if not isEditing then
      moverGhost:ClearAllPoints()
      moverGhost:SetPoint(
        db.point or "CENTER",
        _G[db.relativeTo or "UIParent"] or UIParent,
        db.relativePoint or "CENTER",
        tonumber(db.x) or 0,
        tonumber(db.y) or 350
      )
    end
  end

  local texPath = BarWidget.ResolveStatusBarTexture(db.texture)
  vigorBar:SetStatusBarTexture(texPath)
  vigorRechargeBar:SetStatusBarTexture(texPath)

  local bc = db.barColor or { 0.2, 0.8, 1.0, 1.0 }
  local br = tonumber(bc[1]) or 0.2
  local bgreen = tonumber(bc[2]) or 0.8
  local bb = tonumber(bc[3]) or 1.0
  local ba = tonumber(bc[4]) or 1.0
  vigorBar:SetStatusBarColor(br, bgreen, bb, ba)
  vigorRechargeBar:SetStatusBarColor(br, bgreen, bb, ba)
  if vigorRechargeBar:IsShown() then
    _LayoutRechargeBar(vigorBar, vigorRechargeBar, _cache.vigorMax)
  end

  local bg = db.bgColor or { 0.08, 0.08, 0.08, 0.85 }
  bgTex:SetColorTexture(tonumber(bg[1]) or 0.08, tonumber(bg[2]) or 0.08, tonumber(bg[3]) or 0.08, tonumber(bg[4]) or 0.85)

  local bo = db.borderColor or { 0, 0, 0, 1 }
  if borderFrame and borderFrame.SetBackdropBorderColor then
    borderFrame:SetBackdropBorderColor(tonumber(bo[1]) or 0, tonumber(bo[2]) or 0, tonumber(bo[3]) or 0, tonumber(bo[4]) or 1)
  end

  -- Second Wind bar (below main bar)
  if swBar and db.swEnabled ~= false then
    local swH = tonumber(db.swHeight) or 8
    local gap = tonumber(db.swGap) or 2
    if swH < 1 then swH = 1 end
    if gap < 0 then gap = 0 end
    swH = Round(swH)
    gap = Round(gap)

    swBar:ClearAllPoints()
    swBar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -gap)
    swBar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -gap)
    swBar:SetHeight(swH)

    swBar:SetStatusBarTexture(texPath)
    swRechargeBar:SetStatusBarTexture(texPath)

    local sc = db.swColor or { 1.0, 0.8, 0.2, 1.0 }
    local sr = tonumber(sc[1]) or 1.0
    local sg = tonumber(sc[2]) or 0.8
    local sb = tonumber(sc[3]) or 0.2
    local sa = tonumber(sc[4]) or 1.0
    swBar:SetStatusBarColor(sr, sg, sb, sa)
    swRechargeBar:SetStatusBarColor(sr, sg, sb, sa)
    if swRechargeBar:IsShown() then
      _LayoutRechargeBar(swBar, swRechargeBar, _cache.swMax)
    end

    if swBgTex then
      swBgTex:SetColorTexture(tonumber(bg[1]) or 0.08, tonumber(bg[2]) or 0.08, tonumber(bg[3]) or 0.08, tonumber(bg[4]) or 0.85)
    end

    if swBorderFrame and swBorderFrame.SetBackdropBorderColor then
      swBorderFrame:SetBackdropBorderColor(tonumber(bo[1]) or 0, tonumber(bo[2]) or 0, tonumber(bo[3]) or 0, tonumber(bo[4]) or 1)
    end
  end

  -- Whirling Surge cooldown bar (below Second Wind, matching sizing/gaps)
  if wsBar and db.wsEnabled ~= false then
    local swH = tonumber(db.swHeight) or 8
    local gap = tonumber(db.swGap) or 2
    if swH < 1 then swH = 1 end
    if gap < 0 then gap = 0 end
    swH = Round(swH)
    gap = Round(gap)

    wsBar:ClearAllPoints()

    local anchor = (swBar and db.swEnabled ~= false) and swBar or frame
    wsBar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
    wsBar:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -gap)
    wsBar:SetHeight(swH)

    wsBar:SetStatusBarTexture(texPath)

    local wc = db.wsColor or { 0.65, 0.45, 1.0, 1.0 }
    wsBar:SetStatusBarColor(tonumber(wc[1]) or 0.65, tonumber(wc[2]) or 0.45, tonumber(wc[3]) or 1.0, tonumber(wc[4]) or 1.0)

    if wsBgTex then
      wsBgTex:SetColorTexture(tonumber(bg[1]) or 0.08, tonumber(bg[2]) or 0.08, tonumber(bg[3]) or 0.08, tonumber(bg[4]) or 0.85)
    end

    if wsBorderFrame and wsBorderFrame.SetBackdropBorderColor then
      wsBorderFrame:SetBackdropBorderColor(tonumber(bo[1]) or 0, tonumber(bo[2]) or 0, tonumber(bo[3]) or 0, tonumber(bo[4]) or 1)
    end
  end

  -- Markers are "set and forget" - update only when size/style/maxCharges changed.
  _RefreshMarkerLayout(db)
end

local function _UpdateSegmentMarkers(db, maxCharges)
  if not db then return end
  local show = (db.showSegments ~= false)
  local w = frame:GetWidth()
  local h = frame:GetHeight()
  local thickness = tonumber(db.segmentThickness) or 2
  if thickness < 1 then thickness = 1 end
  thickness = Round(thickness)

  -- More solid/visible markers (not dependent on bar color)
  local r, g, b, a = 0, 0, 0, 0.75

  local segW = w / math.max(1, maxCharges)

  for i = 1, 10 do
    local m = segmentMarkers[i]
    if show and i < maxCharges then
      local x = Round(i * segW - (thickness * 0.5))
      m:ClearAllPoints()
      m:SetPoint("LEFT", vigorBar, "LEFT", x, 0)
      m:SetWidth(thickness)
      m:SetHeight(h)
      m:SetVertexColor(r, g, b, a)
      m:Show()
    else
      m:Hide()
    end
  end
end

local function _UpdateSecondWindSegmentMarkers(db, maxCharges)
  if not swBar then return end
  if not db then return end
  local show = (db.showSegments ~= false)
  local w = swBar:GetWidth()
  local h = swBar:GetHeight()
  local thickness = tonumber(db.segmentThickness) or 2
  if thickness < 1 then thickness = 1 end
  thickness = Round(thickness)

  local r, g, b, a = 0, 0, 0, 0.75
  local segW = w / math.max(1, maxCharges)

  for i = 1, 5 do
    local m = swSegmentMarkers[i]
    if m and show and i < maxCharges then
      local x = i * segW
      m:ClearAllPoints()
      m:SetPoint("LEFT", swBar, "LEFT", x - (thickness * 0.5), 0)
      m:SetWidth(thickness)
      m:SetHeight(h)
      m:SetVertexColor(r, g, b, a)
      m:Show()
    elseif m then
      m:Hide()
    end
  end
end

_RefreshMarkerLayout = function(db)
  if not db then return end

  -- Vigor markers
  if frame and vigorBar then
    local max = tonumber(_cache.vigorMax) or 0
    local w   = frame:GetWidth()
    local h   = frame:GetHeight()
    local show = (db.showSegments ~= false) and true or false
    local th   = tonumber(db.segmentThickness) or 2
    if th < 1 then th = 1 end

    local sig = _vigorMarkerSig
    if sig.max ~= max or sig.w ~= w or sig.h ~= h or sig.show ~= show or sig.th ~= th then
      sig.max, sig.w, sig.h, sig.show, sig.th = max, w, h, show, th
      _UpdateSegmentMarkers(db, max)
    end
  end

  -- Second Wind markers
  if swBar then
    local max = tonumber(_cache.swMax) or 0
    local w   = swBar:GetWidth()
    local h   = swBar:GetHeight()
    local show = (db.showSegments ~= false) and true or false
    local th   = tonumber(db.segmentThickness) or 2
    if th < 1 then th = 1 end

    local sig = _swMarkerSig
    if sig.max ~= max or sig.w ~= w or sig.h ~= h or sig.show ~= show or sig.th ~= th then
      sig.max, sig.w, sig.h, sig.show, sig.th = max, w, h, show, th
      _UpdateSecondWindSegmentMarkers(db, max)
    end
  end
end

local function _EnsureFrame()
  if frame then return end

  frame = CreateFrame("Frame", "PUI_DragonridingFrame", UIParent)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)

  bgTex = frame:CreateTexture(nil, "BACKGROUND")
  bgTex:SetAllPoints(frame)

  vigorBar = CreateFrame("StatusBar", nil, frame)
  vigorBar:SetAllPoints(frame)
  vigorBar:SetMinMaxValues(0, 1)
  vigorBar:SetValue(0)

  vigorRechargeBar = CreateFrame("StatusBar", nil, vigorBar)
  vigorRechargeBar:SetMinMaxValues(0, 1)
  vigorRechargeBar:SetValue(0)
  vigorRechargeBar:SetFrameLevel(vigorBar:GetFrameLevel())
  vigorRechargeBar:Hide()

  borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  borderFrame:SetPoint("TOPLEFT", -1, 1)
  borderFrame:SetPoint("BOTTOMRIGHT", 1, -1)
  borderFrame:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  if borderFrame.Center then borderFrame.Center:Hide() end

  vigorText = vigorBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  vigorText:SetPoint("LEFT", vigorBar, "LEFT", 4, 0)

  speedText = vigorBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  speedText:SetPoint("RIGHT", vigorBar, "RIGHT", -4, 0)

  for i = 1, 10 do
    local m = vigorBar:CreateTexture(nil, "ARTWORK", nil, 3)
    m:SetTexture("Interface\\Buttons\\WHITE8x8")
    m:Hide()
    segmentMarkers[i] = m
  end

  -- Second Wind bar
  swBar = CreateFrame("StatusBar", nil, UIParent)
  swBar:SetFrameStrata("MEDIUM")
  swBar:SetMinMaxValues(0, 1)
  swBar:SetValue(0)

  swRechargeBar = CreateFrame("StatusBar", nil, swBar)
  swRechargeBar:SetMinMaxValues(0, 1)
  swRechargeBar:SetValue(0)
  swRechargeBar:SetFrameLevel(swBar:GetFrameLevel())
  swRechargeBar:Hide()

  swBgTex = swBar:CreateTexture(nil, "BACKGROUND")
  swBgTex:SetAllPoints(swBar)

  swBorderFrame = CreateFrame("Frame", nil, swBar, "BackdropTemplate")
  swBorderFrame:SetPoint("TOPLEFT", -1, 1)
  swBorderFrame:SetPoint("BOTTOMRIGHT", 1, -1)
  swBorderFrame:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  if swBorderFrame.Center then swBorderFrame.Center:Hide() end

  for i = 1, 5 do
    local m = swBar:CreateTexture(nil, "ARTWORK", nil, 3)
    m:SetTexture("Interface\\Buttons\\WHITE8x8")
    m:Hide()
    swSegmentMarkers[i] = m
  end

  -- Whirling Surge cooldown bar
  wsBar = CreateFrame("StatusBar", nil, UIParent)
  wsBar:SetFrameStrata("MEDIUM")
  wsBar:SetMinMaxValues(0, 1)
  wsBar:SetValue(1)

  wsBgTex = wsBar:CreateTexture(nil, "BACKGROUND")
  wsBgTex:SetAllPoints(wsBar)

  wsBorderFrame = CreateFrame("Frame", nil, wsBar, "BackdropTemplate")
  wsBorderFrame:SetPoint("TOPLEFT", -1, 1)
  wsBorderFrame:SetPoint("BOTTOMRIGHT", 1, -1)
  wsBorderFrame:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  if wsBorderFrame.Center then wsBorderFrame.Center:Hide() end

  -- Ghost mover (Edit Mode visible even when real frame hidden)
  if not moverGhost then
    moverGhost = CreateFrame("Frame", "PUI_DragonridingMover", UIParent, "BackdropTemplate")
    moverGhost.__puiEditMoverHelper = true
    moverGhost:SetFrameStrata("HIGH")
    moverGhost:SetClampedToScreen(true)

    moverGhostBg = moverGhost:CreateTexture(nil, "BACKGROUND")
    moverGhostBg:SetAllPoints(moverGhost)
    moverGhostBg:SetColorTexture(0, 0, 0, 0.35)

    moverGhost:Hide()
  end

  -- Mover (FrameUtil Edit Mode) - register on the ghost, not the real bar frame
  if ns.Flags.OptionsBuilding then
    return
  end

  _ApplyStyle()
  frame:Hide()
  swBar:Hide()
  wsBar:Hide()
end

local function _RefreshVisibility(runtime)
  if not frame then return end

  local isEditing = ns.Flags.IsEditing and true or false

  -- In Edit Mode: keep frames stable and visible so dragging does not "spasm".
  if isEditing then
    frame:Show()

    if swBar and runtime.enabled and runtime.swEnabled then
      swBar:Show()
    elseif swBar then
      swBar:Hide()
    end

    if wsBar and runtime.enabled and runtime.wsEnabled then
      wsBar:Show()
    elseif wsBar then
      wsBar:Hide()
    end

    _RefreshTickerState(runtime)
    return
  end

  if not runtime.enabled then
    frame:Hide()
    if swBar then swBar:Hide() end
    if wsBar then wsBar:Hide() end
    _SetTicking(false)
    return
  end

  local gliding = _cache.gliding and true or false

  if gliding then
    frame:Show()
    _RefreshTickerState(runtime)
  else
    frame:Hide()
    if swBar then swBar:Hide() end
    if wsBar then wsBar:Hide() end
    _SetTicking(false)
  end
end

local _lastVigorStr, _lastSpeedStr
local _lastShowVigor, _lastShowSpeed
local _lastVigorCur, _lastVigorMax, _lastSpeedPct

local function _UpdateSpeedText(speed)
  local pct = math.floor((tonumber(speed) or 0) + 0.5)
  if pct ~= _lastSpeedPct then
    _lastSpeedPct = pct
    local s = tostring(pct) .. "%"
    _lastSpeedStr = s
    speedText:SetText(s)
  end
end

local function _UpdateTexts(runtime, cur, max, speed)
  local showV = runtime.showVigorText
  local showS = runtime.showSpeedText

  if showV then
    if cur ~= _lastVigorCur or max ~= _lastVigorMax then
      _lastVigorCur = cur
      _lastVigorMax = max
      local s = tostring(cur) .. "/" .. tostring(max)
      _lastVigorStr = s
      vigorText:SetText(s)
    end
    if _lastShowVigor ~= true then
      _lastShowVigor = true
      vigorText:Show()
    end
  elseif _lastShowVigor ~= false then
    _lastShowVigor = false
    vigorText:Hide()
  end

  if showS then
    _UpdateSpeedText(speed)
    if _lastShowSpeed ~= true then
      _lastShowSpeed = true
      speedText:Show()
    end
  elseif _lastShowSpeed ~= false then
    _lastShowSpeed = false
    speedText:Hide()
  end
end

local function _WS_SetReady(interp)
  if not wsBar then return end

  BarWidget.StopTimerBar(wsBar)

  if interp then
    wsBar:SetMinMaxValues(0, 1, interp)
    wsBar:SetValue(1, interp)
  else
    wsBar:SetMinMaxValues(0, 1)
    wsBar:SetValue(1)
  end
end

local _vigorTimerCur, _vigorTimerMax, _vigorTimerStart, _vigorTimerDur, _vigorTimerRate
local _swTimerCur, _swTimerMax, _swTimerStart, _swTimerDur, _swTimerRate

local function _ApplyVigorChargeState()
  if not vigorBar or not vigorRechargeBar then
    return
  end

  local cur = _cache.vigorCur or 0
  local max = _cache.vigorMax or 0
  local startTime = _cache.vigorStart or 0
  local duration = _cache.vigorDur or 0
  local rate = _cache.vigorRate or 1

  if _vigorTimerCur == cur
    and _vigorTimerMax == max
    and _vigorTimerStart == startTime
    and _vigorTimerDur == duration
    and _vigorTimerRate == rate
  then
    return
  end

  _vigorTimerCur = cur
  _vigorTimerMax = max
  _vigorTimerStart = startTime
  _vigorTimerDur = duration
  _vigorTimerRate = rate

  local charging = max > 0 and cur < max and duration > 0 and startTime > 0
  _ApplyChargeBarState(vigorBar, vigorRechargeBar, VIGOR_SPELL_ID, cur, max, charging)
end

local function _ApplySecondWindChargeState()
  if not swBar or not swRechargeBar then
    return
  end

  local cur = _cache.swCur or 0
  local max = _cache.swMax or 0
  local startTime = _cache.swStart or 0
  local duration = _cache.swDur or 0
  local rate = _cache.swRate or 1

  if _swTimerCur == cur
    and _swTimerMax == max
    and _swTimerStart == startTime
    and _swTimerDur == duration
    and _swTimerRate == rate
  then
    return
  end

  _swTimerCur = cur
  _swTimerMax = max
  _swTimerStart = startTime
  _swTimerDur = duration
  _swTimerRate = rate

  local charging = max > 0 and cur < max and duration > 0 and startTime > 0
  _ApplyChargeBarState(swBar, swRechargeBar, SECOND_WIND_SPELL_ID, cur, max, charging)
end

local function _RefreshWhirlingSurgeTimer()
  if not wsBar then
    return
  end

  local durationObject = C_Spell.GetSpellCooldownDuration(WHIRLING_SURGE_SPELL_ID, true)
  if not durationObject then
    _WS_SetReady(_WS_INTERP)
    return
  end

  wsBar:SetMinMaxValues(0, 1)
  wsBar:SetTimerDuration(durationObject, _WS_INTERP, _TIMER_DIRECTION_ELAPSED)
end

local function _ApplyChargeBars(runtime)
  if not frame or not runtime.enabled then
    return
  end

  local visible = (ns.Flags.IsEditing and true or false) or (_cache.gliding and true or false)

  _ApplyVigorChargeState()

  if swBar and runtime.swEnabled and visible and (_cache.swMax or 0) > 0 then
    if not swBar:IsShown() then
      swBar:Show()
    end
    _ApplySecondWindChargeState()
  elseif swBar and swBar:IsShown() then
    swBar:Hide()
  end
end

local function _ApplyWhirlingSurgeBar(runtime)
  if not frame or not runtime.enabled then
    return
  end

  local visible = (ns.Flags.IsEditing and true or false) or (_cache.gliding and true or false)

  if wsBar and runtime.wsEnabled and visible then
    if not wsBar:IsShown() then
      wsBar:Show()
    end
    _RefreshWhirlingSurgeTimer()
  elseif wsBar and wsBar:IsShown() then
    wsBar:Hide()
  end
end

_Tick = function()
  local runtime = _runtime

  if not runtime.enabled or not runtime.showSpeedText or not _cache.gliding then
    _SetTicking(false)
    return
  end

  local _, _, rawSpeed = C_PlayerInfo.GetGlidingInfo()
  local forwardSpeed = tonumber(rawSpeed) or 0
  local displaySpeed = 0

  if forwardSpeed > 0 then
    displaySpeed = forwardSpeed * 14.285
  end

  _cache.speed = displaySpeed
  _UpdateSpeedText(displaySpeed)
end

local function _RefreshRuntimeState(owner)
  if Addon:IsBlizzardEditModeActive() then
    owner:_SetSpellStateEventsRegistered(false)
    if frame then frame:Hide() end
    if swBar then swBar:Hide() end
    if wsBar then wsBar:Hide() end
    if moverGhost then moverGhost:Hide() end
    _SetTicking(false)
    return
  end

  local isEditing = ns.Flags.IsEditing and true or false

  _RefreshGlidingState()
  local gliding = _cache.gliding and true or false

  if not gliding then
    owner:_SetSpellStateEventsRegistered(false)
    _SetTicking(false)

    if not isEditing then
      if frame then frame:Hide() end
      if swBar then swBar:Hide() end
      if wsBar then wsBar:Hide() end
      return
    end
  end

  _EnsureFrame()

  if gliding and _runtime.enabled then
    local previousVigorMax = _cache.vigorMax
    local previousSecondWindMax = _cache.swMax

    _RefreshVigorState()
    _RefreshSecondWindState()

    if previousVigorMax ~= _cache.vigorMax or previousSecondWindMax ~= _cache.swMax then
      _RefreshMarkerLayout(_runtime)
    end

    owner:_SetSpellStateEventsRegistered(true)
  else
    owner:_SetSpellStateEventsRegistered(false)
  end

  _RefreshVisibility(_runtime)

  if gliding then
    _ApplyChargeBars(_runtime)
    _ApplyWhirlingSurgeBar(_runtime)
  end

  _UpdateTexts(
    _runtime,
    _cache.vigorCur or 0,
    _cache.vigorMax or 0,
    _cache.speed or 0
  )
end

function Dragonriding:Refresh()
  _CompileRuntimeConfig(GetDB())

  if frame then
    _ApplyStyle()
  end

  _RefreshRuntimeState(self)
end

function Dragonriding:_OnSpellUpdateCharges()
  if not _cache.gliding then
    return
  end

  local previousVigorMax = _cache.vigorMax
  local previousSecondWindMax = _cache.swMax

  _RefreshVigorState()

  if _runtime.swEnabled then
    _RefreshSecondWindState()
  end

  if previousVigorMax ~= _cache.vigorMax
    or (_runtime.swEnabled and previousSecondWindMax ~= _cache.swMax)
  then
    _RefreshMarkerLayout(_runtime)
  end

  _ApplyChargeBars(_runtime)

  if _runtime.showVigorText then
    _UpdateTexts(
      _runtime,
      _cache.vigorCur or 0,
      _cache.vigorMax or 0,
      _cache.speed or 0
    )
  end
end

function Dragonriding:_OnSpellUpdateCooldown(event, spellID, baseSpellID)
  if not _cache.gliding then
    return
  end

  if spellID ~= nil
    and spellID ~= WHIRLING_SURGE_SPELL_ID
    and baseSpellID ~= WHIRLING_SURGE_SPELL_ID
  then
    return
  end

  _ApplyWhirlingSurgeBar(_runtime)
end

function Dragonriding:_SetSpellStateEventsRegistered(want)
  want = want and true or false

  if want == _spellEventsRegistered then
    return
  end

  _spellEventsRegistered = want

  if want then
    self:RegisterEvent("SPELL_UPDATE_CHARGES", "_OnSpellUpdateCharges")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "_OnSpellUpdateCooldown")
  else
    self:UnregisterEvent("SPELL_UPDATE_CHARGES")
    self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
  end
end

function Dragonriding:OnEnable()
  _SetTicking(false)
  self:_SetSpellStateEventsRegistered(false)
  self:RegisterEvent("PLAYER_IS_GLIDING_CHANGED", _RefreshRuntimeState, self)
  self:RegisterEvent("PLAYER_ENTERING_WORLD", _RefreshRuntimeState, self)
  self:Refresh()
end

function Dragonriding:OnDisable()
  self:UnregisterEvent("PLAYER_IS_GLIDING_CHANGED")
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  self:_SetSpellStateEventsRegistered(false)
  _SetTicking(false)

  if frame then
    frame:Hide()
  end
  _ClearRechargeBar(vigorRechargeBar)
  _vigorTimerCur = nil
  _vigorTimerMax = nil
  _vigorTimerStart = nil
  _vigorTimerDur = nil
  _vigorTimerRate = nil

  if swBar then
    swBar:Hide()
  end
  _ClearRechargeBar(swRechargeBar)
  _swTimerCur = nil
  _swTimerMax = nil
  _swTimerStart = nil
  _swTimerDur = nil
  _swTimerRate = nil

  if wsBar then
    BarWidget.StopTimerBar(wsBar)
    wsBar:Hide()
  end

  if moverGhost then
    moverGhost:Hide()
  end
end

function Dragonriding:EnsureMovers()
  _EnsureFrame()
  if not moverGhost then
    return
  end

  local function SavePosition(movedFrame)
    local db = GetDB()
    local x, y = FrameUtil.GetMoverOffsets(movedFrame)
    db.point = "CENTER"
    db.relativeTo = "UIParent"
    db.relativePoint = "CENTER"
    db.x = x
    db.y = y
  end

  FrameUtil:RegisterMover("Dragonriding", moverGhost, {
    label = "Skyriding",
    useOverlayDrag = true,
    optionsString = "Dragonriding",
    smartSnap = {
      family = "positionOnly",
      isRuntimeActive = function()
        return GetDB().enabled ~= false
      end,
    },
    savePosition = SavePosition,
    onDragStop = function()
      _ApplyStyle()
    end,
    resetPosition = function()
      local db = GetDB()
      db.point = "CENTER"
      db.relativeTo = "UIParent"
      db.relativePoint = "CENTER"
      db.x = 0
      db.y = 350
      _ApplyStyle()
    end,
    quickSettings = function()
      local db = GetDB()
      return {
        ownerKey = "Dragonriding",
        title = "Skyriding",
        description = "Live Skyriding bar settings.",
        controls = {
          {
            type = "slider",
            label = "Width",
            min = 120,
            max = 800,
            step = 1,
            get = function() return db.width end,
            set = function(value)
              db.width = math.floor(tonumber(value) or 300)
              _ApplyStyle()
            end,
          },
          {
            type = "slider",
            label = "Height",
            min = 6,
            max = 60,
            step = 1,
            get = function() return db.height end,
            set = function(value)
              db.height = math.floor(tonumber(value) or 20)
              _ApplyStyle()
            end,
          },
          {
            type = "statusbar",
            label = "Texture",
            values = _BuildStatusbarList(),
            get = function() return db.texture end,
            set = function(value)
              db.texture = value
              _ApplyStyle()
            end,
          },
        },
      }
    end,
  })
end


function Dragonriding:SetMoversVisible(show)
  self:EnsureMovers()
  if moverGhost then
    FrameUtil.SetMoverFrameVisible(moverGhost, show == true)
  end
  self:Refresh()
end

_BuildStatusbarList = function()
  local out = {}

  local names = LSM:List(LSM.MediaType.STATUSBAR)
  if type(names) ~= "table" then
    return out
  end

  table.sort(names)
  for _, n in ipairs(names) do
    out[n] = n
  end
  return out
end

local function _Clamp01(v)
  v = tonumber(v) or 0
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

local function _RefreshDragonriding()
  if ns.Flags.OptionsBuilding then
    return
  end

  Addon:ApplyOptionsChange("Dragonriding", {})
end

local function DragonridingProvider(AddonObj)
  local provider = {}

  function provider:GetOptions()
    local db = GetDB()

    local options = {
      type = "group",
      name = "Skyriding",
      order = 30,
      args = {
        general = {
          type = "group",
          name = "General",
          order = 10,
          inline = true,
          args = {
            enabled = {
              type = "toggle",
              name = "Enable skyriding bar",
              order = 10,
              get = function()
                return db.enabled and true or false
              end,
              set = function(_, v)
                db.enabled = v and true or false
                _RefreshDragonriding()
              end,
            },
          },
        },
        layout = {
          type = "group",
          name = "Layout",
          order = 20,
          inline = true,
          args = {
            width = {
              type = "range",
              name = "Width",
              min = 120,
              max = 600,
              step = 1,
              order = 10,
              get = function()
                return tonumber(db.width) or 300
              end,
              set = function(_, v)
                db.width = tonumber(v) or 300
                _RefreshDragonriding()
              end,
            },
            height = {
              type = "range",
              name = "Height",
              min = 6,
              max = 40,
              step = 1,
              order = 20,
              get = function()
                return tonumber(db.height) or 20
              end,
              set = function(_, v)
                db.height = tonumber(v) or 20
                _RefreshDragonriding()
              end,
            },
          },
        },
        appearance = {
          type = "group",
          name = "Appearance",
          order = 30,
          inline = true,
          args = {
            texture = {
              type = "select",
              name = "Bar texture",
              order = 10,
              values = function()
                return _BuildStatusbarList()
              end,
              get = function()
                return db.texture
              end,
              set = function(_, val)
                if not val or val == "" then
                  return
                end
                db.texture = val
                _RefreshDragonriding()
              end,
            },
            barColor = {
              type = "color",
              name = "Vigor bar color",
              order = 20,
              hasAlpha = true,
              get = function()
                local c = db.barColor or { 0.2, 0.8, 1.0, 1.0 }
                return _Clamp01(c[1]), _Clamp01(c[2]), _Clamp01(c[3]), _Clamp01(c[4] == nil and 1 or c[4])
              end,
              set = function(_, r, g, b, a)
                db.barColor = { _Clamp01(r), _Clamp01(g), _Clamp01(b), _Clamp01(a) }
                _RefreshDragonriding()
              end,
            },
            showSegments = {
              type = "toggle",
              name = "Show segments",
              order = 30,
              get = function()
                return db.showSegments ~= false
              end,
              set = function(_, v)
                db.showSegments = v and true or false
                _RefreshDragonriding()
              end,
            },
            segmentThickness = {
              type = "range",
              name = "Segment thickness",
              min = 1,
              max = 6,
              step = 1,
              order = 40,
              get = function()
                return tonumber(db.segmentThickness) or 2
              end,
              set = function(_, v)
                db.segmentThickness = tonumber(v) or 2
                _RefreshDragonriding()
              end,
            },
          },
        },
        text = {
          type = "group",
          name = "Text",
          order = 40,
          inline = true,
          args = {
            showVigorText = {
              type = "toggle",
              name = "Show vigor text",
              order = 10,
              get = function()
                return db.showVigorText and true or false
              end,
              set = function(_, v)
                db.showVigorText = v and true or false
                _RefreshDragonriding()
              end,
            },
            showSpeedText = {
              type = "toggle",
              name = "Show speed text",
              order = 20,
              get = function()
                return db.showSpeedText and true or false
              end,
              set = function(_, v)
                db.showSpeedText = v and true or false
                _RefreshDragonriding()
              end,
            },
          },
        },
        secondWind = {
              type = "group",
              name = "Second Wind",
              order = 50,
              inline = true,
              args = {
                swEnabled = {
                  type = "toggle",
                  name = "Show Second Wind",
                  order = 10,
                  get = function()
                    return db.swEnabled ~= false
                  end,
                  set = function(_, v)
                    db.swEnabled = v and true or false
                    _RefreshDragonriding()
                  end,
                },
                swHeight = {
                  type = "range",
                  name = "Height",
                  min = 4,
                  max = 16,
                  step = 1,
                  order = 20,
                  get = function()
                    return tonumber(db.swHeight) or 8
                  end,
                  set = function(_, v)
                    db.swHeight = tonumber(v) or 8
                    _RefreshDragonriding()
                  end,
                },
                swGap = {
                  type = "range",
                  name = "Gap",
                  min = 0,
                  max = 10,
                  step = 1,
                  order = 30,
                  get = function()
                    return tonumber(db.swGap) or 2
                  end,
                  set = function(_, v)
                    db.swGap = tonumber(v) or 2
                    _RefreshDragonriding()
                  end,
                },
                swColor = {
                  type = "color",
                  name = "Bar color",
                  order = 40,
                  hasAlpha = true,
                  get = function()
                    local c = db.swColor or { 1.0, 0.8, 0.2, 1.0 }
                    return _Clamp01(c[1]), _Clamp01(c[2]), _Clamp01(c[3]), _Clamp01(c[4] == nil and 1 or c[4])
                  end,
                  set = function(_, r, g, b, a)
                    db.swColor = { _Clamp01(r), _Clamp01(g), _Clamp01(b), _Clamp01(a) }
                    _RefreshDragonriding()
                  end,
                },
              },
            },
            whirlingSurge = {
              type = "group",
              name = "Whirling Surge",
              order = 60,
              inline = true,
              args = {
                wsEnabled = {
                  type = "toggle",
                  name = "Show Whirling Surge",
                  order = 10,
                  get = function()
                    return db.wsEnabled ~= false
                  end,
                  set = function(_, v)
                    db.wsEnabled = v and true or false
                    _RefreshDragonriding()
                  end,
                },
                wsColor = {
                  type = "color",
                  name = "Bar color",
                  order = 20,
                  hasAlpha = true,
                  get = function()
                    local c = db.wsColor or { 0.65, 0.45, 1.0, 1.0 }
                    return _Clamp01(c[1]), _Clamp01(c[2]), _Clamp01(c[3]), _Clamp01(c[4] == nil and 1 or c[4])
                  end,
                  set = function(_, r, g, b, a)
                    db.wsColor = { _Clamp01(r), _Clamp01(g), _Clamp01(b), _Clamp01(a) }
                    _RefreshDragonriding()
                  end,
                },
              },
            },
      },
    }

    return options
  end

  return provider
end



  _SeedDB = P:Def("_SeedDB", _SeedDB)
  GetDB = P:Def("GetDB", GetDB)
  _CompileRuntimeConfig = P:Def("_CompileRuntimeConfig", _CompileRuntimeConfig)
  _CancelTextTicker = P:Def("_CancelTextTicker", _CancelTextTicker)
  _SetTicking = P:Def("_SetTicking", _SetTicking)
  _GetVigorInfo = P:Def("_GetVigorInfo", _GetVigorInfo)
  _GetSecondWindInfo = P:Def("_GetSecondWindInfo", _GetSecondWindInfo)
  _GetGlidingInfo = P:Def("_GetGlidingInfo", _GetGlidingInfo)
  _ClearRechargeBar = P:Def("_ClearRechargeBar", _ClearRechargeBar)
  _LayoutRechargeBar = P:Def("_LayoutRechargeBar", _LayoutRechargeBar)
  _ApplyChargeBarState = P:Def("_ApplyChargeBarState", _ApplyChargeBarState)
  _RefreshGlidingState = P:Def("_RefreshGlidingState", _RefreshGlidingState)
  _RefreshVigorState = P:Def("_RefreshVigorState", _RefreshVigorState)
  _RefreshSecondWindState = P:Def("_RefreshSecondWindState", _RefreshSecondWindState)
  _RefreshTickerState = P:Def("_RefreshTickerState", _RefreshTickerState)
  _ApplyStyle = P:Def("_ApplyStyle", _ApplyStyle)
  _UpdateSegmentMarkers = P:Def("_UpdateSegmentMarkers", _UpdateSegmentMarkers)
  _UpdateSecondWindSegmentMarkers = P:Def("_UpdateSecondWindSegmentMarkers", _UpdateSecondWindSegmentMarkers)
  _RefreshMarkerLayout = P:Def("_RefreshMarkerLayout", _RefreshMarkerLayout)
  _EnsureFrame = P:Def("_EnsureFrame", _EnsureFrame)
  _RefreshVisibility = P:Def("_RefreshVisibility", _RefreshVisibility)
  _UpdateTexts = P:Def("_UpdateTexts", _UpdateTexts)
  _WS_SetReady = P:Def("_WS_SetReady", _WS_SetReady)
  _ApplyVigorChargeState = P:Def("_ApplyVigorChargeState", _ApplyVigorChargeState)
  _ApplySecondWindChargeState = P:Def("_ApplySecondWindChargeState", _ApplySecondWindChargeState)
  _RefreshWhirlingSurgeTimer = P:Def("_RefreshWhirlingSurgeTimer", _RefreshWhirlingSurgeTimer)
  _ApplyChargeBars = P:Def("_ApplyChargeBars", _ApplyChargeBars)
  _ApplyWhirlingSurgeBar = P:Def("_ApplyWhirlingSurgeBar", _ApplyWhirlingSurgeBar)
  _Tick = P:Def("_Tick", _Tick)
  _RefreshRuntimeState = P:Def("_RefreshRuntimeState", _RefreshRuntimeState)
  Dragonriding.Refresh = P:Def("Dragonriding.Refresh", Dragonriding.Refresh)
  Dragonriding._OnSpellUpdateCharges = P:Def("Dragonriding._OnSpellUpdateCharges", Dragonriding._OnSpellUpdateCharges)
  Dragonriding._OnSpellUpdateCooldown = P:Def("Dragonriding._OnSpellUpdateCooldown", Dragonriding._OnSpellUpdateCooldown)
  Dragonriding._SetSpellStateEventsRegistered = P:Def("Dragonriding._SetSpellStateEventsRegistered", Dragonriding._SetSpellStateEventsRegistered)
  Dragonriding.OnEnable = P:Def("Dragonriding.OnEnable", Dragonriding.OnEnable)
  Dragonriding.OnDisable = P:Def("Dragonriding.OnDisable", Dragonriding.OnDisable)
  Dragonriding.EnsureMovers = P:Def("Dragonriding.EnsureMovers", Dragonriding.EnsureMovers)
  Dragonriding.SetMoversVisible = P:Def("Dragonriding.SetMoversVisible", Dragonriding.SetMoversVisible)
  _BuildStatusbarList = P:Def("_BuildStatusbarList", _BuildStatusbarList)
  _Clamp01 = P:Def("_Clamp01", _Clamp01)
  _RefreshDragonriding = P:Def("_RefreshDragonriding", _RefreshDragonriding)
  DragonridingProvider = P:Def("DragonridingProvider", DragonridingProvider)


_G.PleebUIAPI:RegisterPlugin("PleebUI_Skyriding", {
  name = "Skyriding",
}):RegisterEditModeParticipant("runtime", {
  order = 140,
  onChanged = function(enable)
    Dragonriding:SetMoversVisible(enable)
  end,
})



Addon:RegisterOptionsSection("Dragonriding", DragonridingProvider, 30, "Skyriding", nil, {
  preview = false,
})
