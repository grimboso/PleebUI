
local ADDON_NAME, ns = ...

ns.UFFrameGlow = ns.UFFrameGlow or {}

local UFFrameGlow = ns.UFFrameGlow

local _G = _G
local C_Secrets = _G.C_Secrets
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local UnitIsUnit = _G.UnitIsUnit
local issecretvalue = _G.issecretvalue
local pairs = _G.pairs
local tonumber = _G.tonumber
local type = _G.type
local CanCompareUnitTokens = C_Secrets.CanCompareUnitTokens
local TargetGlowFrames = {}
local TargetGlowDriver
local TargetGlowRosterTimer
local P = select(1, ns.Pleebug:DropIn(UFFrameGlow, { name = "UnitFrames.FrameGlow" }))
local __PUI_SHARED_TARGET_BORDER_SIZE = 3
local __PUI_SHARED_THREAT_BORDER_SIZE = 3
local __PUI_SHARED_THREAT_FRAME_GLOW_SIZE = 3
local __PUI_SHARED_AURA_HIGHLIGHT_SIZE = 3
local __PUI_SHARED_MOUSEOVER_FRAME_GLOW_SIZE = 3
local Round = ns.Pixel.Round

local function ClampBorderSize(value, fallback)
  value = tonumber(value)
  if value == nil then
    value = fallback or 3
  end

  if value < 0 then
    return 0
  elseif value > 12 then
    return 12
  end

  return value
end

local function ScaleBorderSize(value)
  return Round(value * ns.FrameScale:BestOnePixel())
end

local function GetGlobalUFProfile()
  local unitFrames = ns.UnitFrames
  return unitFrames and unitFrames.db and unitFrames.db.profile or nil
end

local function GetGroupedProfile(frame)
  local source = frame and frame.__puiGroupKind or nil

  if source == "party" then
    return ns.Modules.PartyFrames.db.profile
  end

  if source == "raid" then
    return ns.Modules.RaidFrames.db.profile
  end

  return nil
end

local __PUI_LAYER_MOUSEOVER = 40
local __PUI_LAYER_THREAT = 41
local __PUI_LAYER_TARGET = 42
local __PUI_LAYER_AURA_HIGHLIGHT = 43

function UFFrameGlow.InvalidateAnchorCache(frame)
  if not frame then
    return
  end

  frame.__puiFrameGlowAnchorCacheReady = false

  if frame.__puiBorderHighlights then
    for _, border in pairs(frame.__puiBorderHighlights) do
      if border then
        border.__puiForcePositionRefresh = true
        border.__puiPositionReady = false
      end
    end
  end

  local mouseover = frame.__puiMouseoverHighlight
  local texture = mouseover and mouseover.Texture or nil
  if texture then
    texture.__puiCachedHealthAnchor = nil
    texture.__puiCachedFillAnchor = nil
    texture.__puiPositionReady = false
  end
end

local function RefreshFrameAnchorCache(frame)
  if not frame then
    return
  end

  local health = frame.Health or frame
  local power = frame.Power
  local raised = frame.RaisedElementParent or frame
  local textureParent = frame.TextureParent or health or raised or frame
  local powerVisible = power and power:IsShown() and power:GetHeight() > 0 or false
  local topAnchor = health or frame
  local bottomAnchor = powerVisible and power or topAnchor

  if frame.__puiFrameGlowAnchorCacheReady == true
    and frame.__puiCachedHealthAnchor == health
    and frame.__puiCachedPowerAnchor == power
    and frame.__puiCachedRaisedAnchor == raised
    and frame.__puiCachedMouseoverTextureParent == textureParent
    and frame.__puiCachedHighlightTopAnchor == topAnchor
    and frame.__puiCachedHighlightBottomAnchor == bottomAnchor
  then
    return
  end

  frame.__puiCachedHealthAnchor = health
  frame.__puiCachedPowerAnchor = power
  frame.__puiCachedRaisedAnchor = raised
  frame.__puiCachedMouseoverTextureParent = textureParent
  frame.__puiCachedHighlightTopAnchor = topAnchor
  frame.__puiCachedHighlightBottomAnchor = bottomAnchor
  frame.__puiFrameGlowAnchorCacheReady = true
end


function UFFrameGlow.PositionBorderHighlight(frame, border, edge, levelOffset)
  if not frame or not border then
    return
  end

  local logicalEdge = ClampBorderSize(
    edge or border.__puiLogicalEdge,
    __PUI_SHARED_TARGET_BORDER_SIZE
  )
  local physicalEdge = ScaleBorderSize(logicalEdge)
  levelOffset = levelOffset or border.__puiCachedLevelOffset or 1

  if border.__puiPositionReady == true
    and border.__puiForcePositionRefresh ~= true
    and border.__puiLogicalEdge == logicalEdge
    and border.__puiCachedEdge == physicalEdge
    and border.__puiCachedLevelOffset == levelOffset
  then
    return
  end

  RefreshFrameAnchorCache(frame)

  if border.__puiBackdropEdgeSize ~= physicalEdge and border.SetBackdrop then
    border:SetBackdrop({
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = physicalEdge,
    })
    border:SetBackdropColor(0, 0, 0, 0)
    border.__puiBackdropEdgeSize = physicalEdge
  end

  local parent = frame.__puiCachedRaisedAnchor or frame
  local topAnchor = frame.__puiCachedHighlightTopAnchor or frame
  local bottomAnchor = frame.__puiCachedHighlightBottomAnchor or topAnchor
  local strata = (parent and parent.GetFrameStrata and parent:GetFrameStrata()) or (frame.GetFrameStrata and frame:GetFrameStrata()) or "MEDIUM"
  local baseLevel = ((parent and parent.GetFrameLevel and parent:GetFrameLevel()) or (frame.GetFrameLevel and frame:GetFrameLevel()) or 1) + levelOffset

  if border.__puiCachedFrameStrata ~= strata then
    border:SetFrameStrata(strata)
    border.__puiCachedFrameStrata = strata
  end

  if border.__puiCachedFrameLevel ~= baseLevel then
    border:SetFrameLevel(baseLevel)
    border.__puiCachedFrameLevel = baseLevel
  end

  if border.__puiCachedTopAnchor ~= topAnchor
    or border.__puiCachedBottomAnchor ~= bottomAnchor
    or border.__puiCachedEdge ~= physicalEdge
    or border.__puiForcePositionRefresh == true
  then
    border:ClearAllPoints()
    border:SetPoint(
      "TOPLEFT",
      topAnchor,
      "TOPLEFT",
      -physicalEdge,
      physicalEdge
    )
    border:SetPoint(
      "BOTTOMRIGHT",
      bottomAnchor,
      "BOTTOMRIGHT",
      physicalEdge,
      -physicalEdge
    )
    border.__puiCachedTopAnchor = topAnchor
    border.__puiCachedBottomAnchor = bottomAnchor
    border.__puiCachedEdge = physicalEdge
  end

  border.__puiLogicalEdge = logicalEdge
  border.__puiCachedLevelOffset = levelOffset
  border.__puiPositionReady = true
  border.__puiForcePositionRefresh = false
end

function UFFrameGlow.EnsureSharedBorderHighlight(frame, key, edge)
  if not frame then
    return nil
  end

  if frame[key] then
    return frame[key]
  end

  RefreshFrameAnchorCache(frame)

  local logicalEdge = ClampBorderSize(
    edge,
    __PUI_SHARED_TARGET_BORDER_SIZE
  )
  local physicalEdge = ScaleBorderSize(logicalEdge)

  local border = CreateFrame("Frame", nil, frame.__puiCachedRaisedAnchor or frame, "BackdropTemplate")
  border:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = physicalEdge,
  })
  border:EnableMouse(false)
  border:Hide()
  border.__puiLogicalEdge = logicalEdge
  border.__puiCachedEdge = physicalEdge
  border.__puiBackdropEdgeSize = physicalEdge
  border.__puiForcePositionRefresh = true

  frame.__puiBorderHighlights = frame.__puiBorderHighlights or {}
  frame.__puiBorderHighlights[key] = border
  frame[key] = border

  return border
end

local DEFAULT_TARGET_COLOR = { 1, 1, 1, 1 }

local function ApplyBorderColor(border, color, fallback)
  if not border or not border.SetBackdropBorderColor then
    return
  end

  color = color or fallback or DEFAULT_TARGET_COLOR

  if color.GetRGBA then
    border:SetBackdropBorderColor(color:GetRGBA())
  else
    border:SetBackdropBorderColor(
      color.r or color[1] or 1,
      color.g or color[2] or 1,
      color.b or color[3] or 1,
      color.a or color[4] or 1
    )
  end
end

function UFFrameGlow.ShowPreparedBorderHighlight(border, r, g, b, a)
  if not border then
    return
  end

  if border.__puiCachedBorderR ~= r
    or border.__puiCachedBorderG ~= g
    or border.__puiCachedBorderB ~= b
    or border.__puiCachedBorderA ~= a
  then
    border:SetBackdropBorderColor(r, g, b, a)
    border.__puiCachedBorderR = r
    border.__puiCachedBorderG = g
    border.__puiCachedBorderB = b
    border.__puiCachedBorderA = a
  end

  if border.__puiBorderShown ~= true then
    border.__puiBorderShown = true

    if not border:IsShown() then
      border:Show()
    end
  end
end

function UFFrameGlow.GetBorderSize(kind, frame)
  if kind == "aura" or kind == "dispel" then
    if frame and frame.__puiAuraHighlightBorderSize ~= nil then
      return ClampBorderSize(frame.__puiAuraHighlightBorderSize, __PUI_SHARED_AURA_HIGHLIGHT_SIZE)
    end

    local profile = GetGroupedProfile(frame) or GetGlobalUFProfile()
    local debuffHighlight = profile and profile.debuffHighlight or nil
    return ClampBorderSize(debuffHighlight and debuffHighlight.borderSize, __PUI_SHARED_AURA_HIGHLIGHT_SIZE)
  end

  if kind == "mouseover" then
    if frame and frame.__puiMouseoverBorderSize ~= nil then
      return ClampBorderSize(frame.__puiMouseoverBorderSize, __PUI_SHARED_MOUSEOVER_FRAME_GLOW_SIZE)
    end

    local globalProfile = GetGlobalUFProfile()
    return ClampBorderSize(globalProfile and globalProfile.mouseoverHighlightBorderSize, __PUI_SHARED_MOUSEOVER_FRAME_GLOW_SIZE)
  end

  if kind == "threat" or kind == "threatFrame" then
    local fallback = kind == "threatFrame" and __PUI_SHARED_THREAT_FRAME_GLOW_SIZE or __PUI_SHARED_THREAT_BORDER_SIZE
    if frame and frame.__puiThreatBorderSize ~= nil then
      return ClampBorderSize(frame.__puiThreatBorderSize, fallback)
    end

    local profile = GetGroupedProfile(frame) or GetGlobalUFProfile()
    local threatIndicator = profile and profile.threatIndicator or nil
    return ClampBorderSize(threatIndicator and threatIndicator.borderSize, fallback)
  end

  local globalProfile = GetGlobalUFProfile()
  return ClampBorderSize(globalProfile and globalProfile.targetHighlightBorderSize, __PUI_SHARED_TARGET_BORDER_SIZE)
end

function UFFrameGlow.GetLayerLevelOffset(kind)
  if kind == "aura" or kind == "dispel" then
    return __PUI_LAYER_AURA_HIGHLIGHT
  end

  if kind == "mouseover" then
    return __PUI_LAYER_MOUSEOVER
  end

  if kind == "threat" or kind == "threatFrame" then
    return __PUI_LAYER_THREAT
  end

  return __PUI_LAYER_TARGET
end

function UFFrameGlow.HideBorderHighlight(border)
  if not border then
    return
  end

  if border.__puiBorderShown ~= false then
    border.__puiBorderShown = false

    if border:IsShown() then
      border:Hide()
    end
  end
end

function UFFrameGlow.ShowBorderHighlight(frame, border, color, fallback, edge, levelOffset)
  if not frame or not border then
    return
  end

  local logicalEdge = ClampBorderSize(
    edge,
    __PUI_SHARED_TARGET_BORDER_SIZE
  )
  if logicalEdge <= 0 then
    UFFrameGlow.HideBorderHighlight(border)
    return
  end

  UFFrameGlow.PositionBorderHighlight(
    frame,
    border,
    logicalEdge,
    levelOffset or 1
  )

  ApplyBorderColor(border, color, fallback or DEFAULT_TARGET_COLOR)

  if border.__puiBorderShown ~= true then
    border.__puiBorderShown = true

    if not border:IsShown() then
      border:Show()
    end
  end
end

local function UnitTokensAreSame(unit1, unit2)
  if issecretvalue(unit1) or issecretvalue(unit2) then
    return false
  end

  if type(unit1) ~= "string" or unit1 == "" or type(unit2) ~= "string" or unit2 == "" then
    return false
  end

  local canCompare = CanCompareUnitTokens(unit1, unit2)
  if issecretvalue(canCompare) or canCompare ~= true then
    return false
  end

  local isUnit = UnitIsUnit(unit1, unit2)
  if issecretvalue(isUnit) then
    return false
  end

  return isUnit == true
end

local function IsGroupedFrameGlowFrame(frame)
  local kind = frame and frame.__puiGroupKind or nil
  return kind == "party" or kind == "raid"
end

local function ShouldShowTargetGlow(frame)
  if not frame or not frame:IsVisible() then
    return false
  end

  if not IsGroupedFrameGlowFrame(frame) then
    return false
  end

  return UnitTokensAreSame(frame.__unit, "target")
end

function UFFrameGlow.HideTargetHighlight(frame)
  local glow = frame and frame.__puiTargetHighlight or nil
  if glow then
    UFFrameGlow.HideBorderHighlight(glow)
  end

  if frame then
    frame.__puiTargetHighlightShown = false
    frame.__puiTargetHighlightEdge = nil
  end
end

function UFFrameGlow.UpdateTargetHighlight(frame)
  if not frame then
    return
  end

  if not ShouldShowTargetGlow(frame) then
    if frame.__puiTargetHighlightShown == true then
      UFFrameGlow.HideTargetHighlight(frame)
    end
    return
  end

  local glow = frame.__puiTargetHighlight or UFFrameGlow.EnsureSharedBorderHighlight(frame, "__puiTargetHighlight", __PUI_SHARED_TARGET_BORDER_SIZE)
  if not glow then
    return
  end

  local edge = UFFrameGlow.GetBorderSize("target", frame)
  frame.__puiTargetHighlightEdgeConfig = edge

  if edge <= 0 then
    UFFrameGlow.HideTargetHighlight(frame)
    return
  end

  if glow.__puiPositionReady ~= true
    or glow.__puiForcePositionRefresh == true
    or glow.__puiLogicalEdge ~= edge
  then
    UFFrameGlow.PositionBorderHighlight(frame, glow, edge, UFFrameGlow.GetLayerLevelOffset("target"))
  end

  if frame.__puiTargetHighlightShown == true
    and frame.__puiTargetHighlightEdge == edge
    and glow.__puiBorderShown == true
  then
    return
  end

  frame.__puiTargetHighlightShown = true
  frame.__puiTargetHighlightEdge = edge

  UFFrameGlow.ShowPreparedBorderHighlight(glow, 1, 1, 1, 0.95)
end

local function TargetGlow_Refresh()
  for frame in pairs(TargetGlowFrames) do
    UFFrameGlow.UpdateTargetHighlight(frame)
  end
end

local function QueueTargetGlowRosterRefresh()
  if InCombatLockdown() then
    if TargetGlowRosterTimer then
      return
    end
  elseif TargetGlowRosterTimer then
    TargetGlowRosterTimer:Cancel()
  end

  TargetGlowRosterTimer = C_Timer.NewTimer(0, function()
    TargetGlowRosterTimer = nil
    TargetGlow_Refresh()
  end)
end

local function TargetGlow_OnEvent(_, event)
  if event == "GROUP_ROSTER_UPDATE" then
    QueueTargetGlowRosterRefresh()
    return
  end

  TargetGlow_Refresh()
end

local function HasTargetGlowFrames()
  for _ in pairs(TargetGlowFrames) do
    return true
  end

  return false
end

local function EnsureFrameGlowDriver()
  local driver = TargetGlowDriver
  if not driver then
    driver = CreateFrame("Frame")
    driver:SetScript("OnEvent", TargetGlow_OnEvent)
    TargetGlowDriver = driver
  end

  driver:RegisterEvent("PLAYER_TARGET_CHANGED")
  driver:RegisterEvent("GROUP_ROSTER_UPDATE")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")

  return driver
end

local function RegisterTargetGlowFrame(frame)
  if not TargetGlowFrames[frame] then
    TargetGlowFrames[frame] = true
    EnsureFrameGlowDriver()
  end

  UFFrameGlow.UpdateTargetHighlight(frame)
end

local function UnregisterTargetGlowFrame(frame)
  TargetGlowFrames[frame] = nil

  if frame.__puiTargetHighlightShown == true then
    UFFrameGlow.HideTargetHighlight(frame)
  end

  if TargetGlowDriver and not HasTargetGlowFrames() then
    TargetGlowDriver:UnregisterAllEvents()

    if TargetGlowRosterTimer then
      TargetGlowRosterTimer:Cancel()
      TargetGlowRosterTimer = nil
    end
  end
end

local function TargetGlowFrame_OnShow(frame)
  if not IsGroupedFrameGlowFrame(frame) then
    return
  end

  local edge = UFFrameGlow.GetBorderSize("target", frame)
  frame.__puiTargetHighlightEdgeConfig = edge

  if edge > 0 then
    RegisterTargetGlowFrame(frame)
  else
    UnregisterTargetGlowFrame(frame)
  end
end

local function TargetGlowFrame_OnHide(frame)
  UnregisterTargetGlowFrame(frame)
end

function UFFrameGlow.ConstructTargetHighlight(frame)
  if not IsGroupedFrameGlowFrame(frame) then
    return nil
  end

  local glow = frame.__puiTargetHighlight or UFFrameGlow.EnsureSharedBorderHighlight(frame, "__puiTargetHighlight", __PUI_SHARED_TARGET_BORDER_SIZE)
  local edge = UFFrameGlow.GetBorderSize("target", frame)

  frame.__puiTargetHighlightEdgeConfig = edge

  if glow and edge > 0 then
    UFFrameGlow.PositionBorderHighlight(frame, glow, edge, UFFrameGlow.GetLayerLevelOffset("target"))
  end

  if frame.__puiTargetGlowLifecycleHooked ~= true then
    frame.__puiTargetGlowLifecycleHooked = true
    frame:HookScript("OnShow", TargetGlowFrame_OnShow)
    frame:HookScript("OnHide", TargetGlowFrame_OnHide)
  end

  if frame:IsVisible() and edge > 0 then
    RegisterTargetGlowFrame(frame)
  else
    UnregisterTargetGlowFrame(frame)
  end

  return glow
end

function UFFrameGlow.DisableTargetHighlight(frame)
  UnregisterTargetGlowFrame(frame)
  UFFrameGlow.HideTargetHighlight(frame)
end

function UFFrameGlow.UpdateSharedTargetHighlight(frame)
  if not frame then
    return
  end

  if not IsGroupedFrameGlowFrame(frame) then
    UFFrameGlow.DisableTargetHighlight(frame)
    return
  end

  UFFrameGlow.ConstructTargetHighlight(frame)
end






  ClampBorderSize = P:Def("ClampBorderSize", ClampBorderSize)
  ScaleBorderSize = P:Def("ScaleBorderSize", ScaleBorderSize)
  GetGlobalUFProfile = P:Def("GetGlobalUFProfile", GetGlobalUFProfile)
  GetGroupedProfile = P:Def("GetGroupedProfile", GetGroupedProfile)
  UFFrameGlow.InvalidateAnchorCache = P:Def("UFFrameGlow.InvalidateAnchorCache", UFFrameGlow.InvalidateAnchorCache)
  RefreshFrameAnchorCache = P:Def("RefreshFrameAnchorCache", RefreshFrameAnchorCache)
  ApplyBorderColor = P:Def("ApplyBorderColor", ApplyBorderColor)
  UFFrameGlow.ShowPreparedBorderHighlight = P:Def("UFFrameGlow.ShowPreparedBorderHighlight", UFFrameGlow.ShowPreparedBorderHighlight)
  UFFrameGlow.PositionBorderHighlight = P:Def("UFFrameGlow.PositionBorderHighlight", UFFrameGlow.PositionBorderHighlight)
  UFFrameGlow.EnsureSharedBorderHighlight = P:Def("UFFrameGlow.EnsureSharedBorderHighlight", UFFrameGlow.EnsureSharedBorderHighlight)
  UFFrameGlow.GetBorderSize = P:Def("UFFrameGlow.GetBorderSize", UFFrameGlow.GetBorderSize)
  UFFrameGlow.GetLayerLevelOffset = P:Def("UFFrameGlow.GetLayerLevelOffset", UFFrameGlow.GetLayerLevelOffset)
  UFFrameGlow.HideBorderHighlight = P:Def("UFFrameGlow.HideBorderHighlight", UFFrameGlow.HideBorderHighlight)
  UFFrameGlow.ShowBorderHighlight = P:Def("UFFrameGlow.ShowBorderHighlight", UFFrameGlow.ShowBorderHighlight)
  IsGroupedFrameGlowFrame = P:Def("IsGroupedFrameGlowFrame", IsGroupedFrameGlowFrame)
  UFFrameGlow.HideTargetHighlight = P:Def("UFFrameGlow.HideTargetHighlight", UFFrameGlow.HideTargetHighlight)
  UFFrameGlow.UpdateTargetHighlight = P:Def("UFFrameGlow.UpdateTargetHighlight", UFFrameGlow.UpdateTargetHighlight)
  TargetGlow_Refresh = P:Def("TargetGlow_Refresh", TargetGlow_Refresh)
  QueueTargetGlowRosterRefresh = P:Def("QueueTargetGlowRosterRefresh", QueueTargetGlowRosterRefresh)
  TargetGlow_OnEvent = P:Def("TargetGlow_OnEvent", TargetGlow_OnEvent)
  EnsureFrameGlowDriver = P:Def("EnsureFrameGlowDriver", EnsureFrameGlowDriver)
  RegisterTargetGlowFrame = P:Def("RegisterTargetGlowFrame", RegisterTargetGlowFrame)
  UnregisterTargetGlowFrame = P:Def("UnregisterTargetGlowFrame", UnregisterTargetGlowFrame)
  UFFrameGlow.ConstructTargetHighlight = P:Def("UFFrameGlow.ConstructTargetHighlight", UFFrameGlow.ConstructTargetHighlight)
  UFFrameGlow.DisableTargetHighlight = P:Def("UFFrameGlow.DisableTargetHighlight", UFFrameGlow.DisableTargetHighlight)
  UFFrameGlow.UpdateSharedTargetHighlight = P:Def("UFFrameGlow.UpdateSharedTargetHighlight", UFFrameGlow.UpdateSharedTargetHighlight)
  UnitTokensAreSame = P:Def("UnitTokensAreSame", UnitTokensAreSame)
  ShouldShowTargetGlow = P:Def("ShouldShowTargetGlow", ShouldShowTargetGlow)
  HasTargetGlowFrames = P:Def("HasTargetGlowFrames", HasTargetGlowFrames)
  TargetGlowFrame_OnShow = P:Def("TargetGlowFrame_OnShow", TargetGlowFrame_OnShow)
  TargetGlowFrame_OnHide = P:Def("TargetGlowFrame_OnHide", TargetGlowFrame_OnHide)



