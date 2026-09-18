-- File: PUI_MinimapData.lua
-- Purpose:
-- 1) PleebUI minimap icon (LDB + LibDBIcon)
-- 2) PUIBucket under minimap that captures and lays out addon minimap buttons

local ADDON_NAME, ns = ...
local Addon = ns.Addon

local MinimapData = {}
ns.MinimapData = MinimapData

local LibStub = _G.LibStub
local P = select(1, ns.Pleebug:DropIn(MinimapData, { name = "Modules.MinimapData" }))
local _G = _G
local UIParent = UIParent
local Minimap = _G.Minimap

-- Forward declare so SetBucketEnabled() can hide/show it live.
local PUIBucket

-- Forward declare (implemented later)
local ScanMinimapChildren
local ScanLibDBIcon
local RescanButtons
local SetRescanEventsEnabled
local SetLibDBIconCallbackEnabled
local InstallExpansionLandingButtonHook

-- Runtime state changes only through SetBucketEnabled().
local _bucketEnabled
local _launcherOnMinimap
local _launcherProfile
local _launcherAnchorQueued = false
local _rescanEventFrame
local _rescanQueued = false

-- Cache child counts so repeated lifecycle events can skip unchanged parents.
local _lastMinimapChildCount   = -1
local _lastBackdropChildCount  = -1


local function _GetMinimapProfile()
  local mm = ns.Registry.Minimap
  local db = mm and mm.db
  return db and db.profile or nil
end


local function _IsBucketEnabled()
  return _bucketEnabled == true
end

local function _SetBucketEnabledDB(enabled)
  local p = _GetMinimapProfile()
  if p then
    p.bucketEnabled = enabled and true or false
  end
end

local RestoreCapturedButtons
local LayoutButtons


-- Minimap click routing and shared quick menu
local function BuildQuickMenu(_, rootDescription)
  rootDescription:CreateTitle("PleebUI Quick Menu")

  local hiddenUI = rootDescription:CreateButton("Hidden UI")
  hiddenUI:CreateButton("Calendar", function()
    _G.GameTimeFrame:Click()
  end)
  hiddenUI:CreateButton(_G.TIMEMANAGER_TITLE, function()
    _G.ToggleFrame(_G.TimeManagerFrame)
  end)
  hiddenUI:CreateButton(_G.CHAT_CHANNELS, _G.ToggleChannelFrame)
  hiddenUI:CreateButton("Currency", function()
    _G.ToggleCharacter("TokenFrame")
  end)
  hiddenUI:CreateButton("Reputation", function()
    _G.ToggleCharacter("ReputationFrame")
  end)
  hiddenUI:CreateButton(_G.PROFESSIONS_BUTTON, _G.ToggleProfessionsBook)

  local expansionButton = _G.ExpansionLandingPageMinimapButton
  if expansionButton
    and expansionButton:IsShown()
    and type(expansionButton.title) == "string"
    and expansionButton.title ~= ""
  then
    hiddenUI:CreateButton("Expansion Overview", function()
      expansionButton:ToggleLandingPage()
    end)
  end

  if _G.C_Housing.IsHousingServiceEnabled() then
    hiddenUI:CreateButton(_G.HOUSING_MICRO_BUTTON, function()
      _G.HousingFramesUtil.ToggleHousingDashboard()
    end)
  end

  local game = rootDescription:CreateButton("Game")
  game:CreateButton(_G.CHARACTER_BUTTON, function()
    _G.ToggleCharacter("PaperDollFrame")
  end)
  game:CreateButton(_G.SPELLBOOK, _G.PlayerSpellsUtil.ToggleSpellBookFrame)
  game:CreateButton(_G.TALENTS_BUTTON, _G.PlayerSpellsUtil.ToggleClassTalentFrame)
  game:CreateButton(_G.QUESTLOG_BUTTON, _G.ToggleQuestLog)
  game:CreateButton(_G.LFG_TITLE, _G.ToggleLFDParentFrame)
  game:CreateButton(_G.COLLECTIONS, _G.ToggleCollectionsJournal)
  game:CreateButton(_G.ACHIEVEMENT_BUTTON, _G.ToggleAchievementFrame)
  game:CreateButton(_G.ENCOUNTER_JOURNAL, function()
    if not _G.C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal") then
      _G.LoadAddOnWithErrorHandling("Blizzard_EncounterJournal")
    end
    _G.ToggleFrame(_G.EncounterJournal)
  end)
  game:CreateButton(_G.SOCIAL_BUTTON, _G.ToggleFriendsFrame)
  game:CreateButton(_G.GUILD, _G.ToggleGuildFrame)

  local pleebUI = rootDescription:CreateButton("PleebUI")
  pleebUI:CreateButton("Open settings", function()
    Addon:OpenOptions()
  end)
  pleebUI:CreateButton("Edit Mode", function()
    Addon:SetEditMode(not Addon:IsEditMode())
  end)
  pleebUI:CreateButton("PleebUI test mode", function()
    Addon:SetEditMode(not Addon:IsEditMode())
  end)
  pleebUI:CreateButton(_IsBucketEnabled() and "Disable addon button bucket" or "Enable addon button bucket", function()
    MinimapData.SetBucketEnabled(not _IsBucketEnabled())
  end)
  pleebUI:CreateButton("Reload UI", _G.ReloadUI)
end

local function Minimap_OnMouseUp(self, button)
  if button == "RightButton" then
    if _G.IsShiftKeyDown() then
      _G.MenuUtil.CreateContextMenu(self, BuildQuickMenu)
    else
      _G.MinimapCluster.Tracking.Button:OpenMenu()
    end
    return
  end

  if button == "MiddleButton" then
    _G.GameTimeFrame:Click()
    return
  end

  MinimapData.__puiOriginalMinimapOnMouseUp(self, button)
end

function MinimapData.InstallMinimapClicks()
  if MinimapData.__puiMinimapClicksInstalled then
    return
  end

  MinimapData.__puiMinimapClicksInstalled = true
  MinimapData.__puiOriginalMinimapOnMouseUp = Minimap:GetScript("OnMouseUp")
  Minimap:SetScript("OnMouseUp", Minimap_OnMouseUp)
end


-- PleebUI minimap icon via LDB + LibDBIcon
function MinimapData.SetBucketEnabled(enabled)
  local v = enabled and true or false

  if _bucketEnabled == v then
    return
  end

  _bucketEnabled = v
  _SetBucketEnabledDB(v)

  if not v then
    SetRescanEventsEnabled(false)
    SetLibDBIconCallbackEnabled(false)

    _lastMinimapChildCount = -1
    _lastBackdropChildCount = -1

    RestoreCapturedButtons()

    if PUIBucket then
      if PUIBucket.__puiPanel then PUIBucket.__puiPanel:Hide() end
      if PUIBucket.__puiToggleText then PUIBucket.__puiToggleText:SetText("+") end
      PUIBucket:Hide()
    end
    return
  end

  if not PUIBucket then
    MinimapData.InitializePUIBucket()
  end

  if PUIBucket then
    PUIBucket:Show()
  end

  SetLibDBIconCallbackEnabled(true)

  RescanButtons(true)

  LayoutButtons()

  SetRescanEventsEnabled(true)
end



function MinimapData.InitializeLauncher()
  if MinimapData.__puiLauncherInitialized then
    return true
  end

  local db = _GetMinimapProfile()
  if not db then
    return false
  end

  local LDB = LibStub("LibDataBroker-1.1")
  local LDBIcon = LibStub("LibDBIcon-1.0")

  local iconPath = [[Interface\AddOns\PleebUI\Media\logo.tga]]

  local dataObj = LDB:NewDataObject("PleebUI", {
    type = "launcher",
    text = "PleebUI",
    icon = iconPath,
    OnClick = function(frame, btn)
      if btn == "LeftButton" then
        Addon:OpenOptions()
      elseif btn == "MiddleButton" then
        _G.GameTimeFrame:Click()
      elseif btn == "RightButton" then
        _G.MenuUtil.CreateContextMenu(frame, BuildQuickMenu)
      end
    end,


    OnTooltipShow = function(tt)
      tt:AddLine("PleebUI", 1, 1, 1)
      tt:AddLine("Left-click: Open Settings", 0.7, 0.7, 0.7)
      tt:AddLine("Middle-click: Calendar", 0.7, 0.7, 0.7)
      tt:AddLine("Right-click: Quick Menu", 0.7, 0.7, 0.7)
    end,
  })

  LDBIcon:Register("PleebUI", dataObj, db)
  MinimapData.__puiLauncherInitialized = true

  -- Store the actual button frame so the dropdown can anchor correctly.
  MinimapData.IconButton =
      (LDBIcon.GetMinimapButton and LDBIcon:GetMinimapButton("PleebUI"))
      or _G["LibDBIcon10_PleebUI"]

  return true
end

-- PUIBucket under minimap that captures addon minimap buttons
local captured = setmetatable({}, { __mode = "k" }) -- weak keys (frames)
local buttons  = setmetatable({}, { __mode = "v" }) -- weak values (frames)
local BTN_SIZE = 26
local BTN_PAD = 6
local MARGIN = 6
local MAX_COLS = 6 -- 6 icons per row when expanded

local HANDLE_SIZE = 20
local COLLAPSE_SECONDS = 20

local _bucketExpanded = false
local _bucketAutoCollapseTimer = nil


local function _BucketCancelAutoCollapse()
  if _bucketAutoCollapseTimer and _bucketAutoCollapseTimer.Cancel then
    _bucketAutoCollapseTimer:Cancel()
  end
  _bucketAutoCollapseTimer = nil
end

local function _BucketScheduleAutoCollapse()
  _BucketCancelAutoCollapse()
  if not _bucketExpanded then
    return
  end
  _bucketAutoCollapseTimer = C_Timer.NewTimer(COLLAPSE_SECONDS, function()
    if PUIBucket and PUIBucket.__puiHandle and PUIBucket.__puiHandle:IsMouseOver() then
      _BucketScheduleAutoCollapse()
      return
    end
    if PUIBucket and PUIBucket.__puiPanel and PUIBucket.__puiPanel:IsMouseOver() then
      _BucketScheduleAutoCollapse()
      return
    end
    _bucketExpanded = false
    if PUIBucket then
      if PUIBucket.__puiPanel then PUIBucket.__puiPanel:Hide() end
      if PUIBucket.__puiToggleText then PUIBucket.__puiToggleText:SetText("+") end
    end
  end)
end

local function _BucketSetExpanded(expanded)
  _bucketExpanded = expanded and true or false

  if not PUIBucket then
    return
  end

  if _bucketExpanded then
    RescanButtons(true)
  end

  if PUIBucket.__puiPanel then
    if _bucketExpanded then
      PUIBucket.__puiPanel:Show()
      if PUIBucket.__puiToggleText then PUIBucket.__puiToggleText:SetText("-") end
      _BucketScheduleAutoCollapse()
    else
      PUIBucket.__puiPanel:Hide()
      if PUIBucket.__puiToggleText then PUIBucket.__puiToggleText:SetText("+") end
      _BucketCancelAutoCollapse()
    end
  end

  -- Relayout (sizes and positions depend on expanded/collapsed)
  LayoutButtons()
end


local ignoreList = {
  ["GameTimeFrame"] = true,
  ["MinimapBackdrop"] = true,
  ["MiniMapWorldMapButton"] = true,
  ["MinimapZoomIn"] = true,
  ["MinimapZoomOut"] = true,
  ["MiniMapTracking"] = true,
  ["MiniMapMailFrame"] = true,
  ["MiniMapBattlefieldFrame"] = true,
  ["MinimapZoneTextButton"] = true,
  ["TimeManagerClockButton"] = true,
  ["QueueStatusButton"] = true,
  ["AddonCompartmentFrame"] = true,
  ["PleebUI_MinimapPUIBucket"] = true,
}

local ignorePatterns = {
  "^GatherMatePin%d+$",
  "^HandyNotes.*Pin$",
}

local function ShouldIgnore(frame)
  if frame == Minimap.ZoomIn
    or frame == Minimap.ZoomOut
  then
    return true
  end

  local p = _GetMinimapProfile()
  if frame == MinimapData.IconButton and p and p.pleebUIButtonOnMinimap == true then
    return true
  end

  local name = frame:GetName()
  if not name then return false end
  if ignoreList[name] then return true end
  for i = 1, #ignorePatterns do
    if name:match(ignorePatterns[i]) then
      return true
    end
  end
  return false
end

local function LooksLikeButton(frame)
  if frame:IsForbidden() then return false end
  local name = frame:GetName()

  -- Fast-path: many addons use obvious names even if scripts are on subregions.
  if name and (name:find("Minimap", 1, true) or name:find("MiniMap", 1, true)) then
    if name:find("Button", 1, true) or name:find("Icon", 1, true) then
      return true
    end
  end

  local w, h = frame:GetSize()
  if not w or not h then return false end
  if w < 16 or h < 16 then return false end
  if w > 60 or h > 60 then return false end
  if math.abs(w - h) > 10 then return false end

  local hasClick = false
  if (frame:HasScript("OnClick") and frame:GetScript("OnClick")) or
     (frame:HasScript("OnMouseUp") and frame:GetScript("OnMouseUp")) or
     (frame:HasScript("OnMouseDown") and frame:GetScript("OnMouseDown")) then
    hasClick = true
  end

  if not hasClick then
    local children = { frame:GetChildren() }
    for i = 1, #children do
      local c = children[i]
      if (c:HasScript("OnClick") and c:GetScript("OnClick")) or
         (c:HasScript("OnMouseUp") and c:GetScript("OnMouseUp")) or
         (c:HasScript("OnMouseDown") and c:GetScript("OnMouseDown")) then
        hasClick = true
        break
      end
    end
  end

  return hasClick
end

local function UnfreezeButton(btn)
  if not btn or not btn.__puiFrozen then
    return
  end

  local f = btn.__puiOrigFuncs
  btn.SetPoint = f.SetPoint
  btn.ClearAllPoints = f.ClearAllPoints
  btn.SetParent = f.SetParent
  btn.SetScale = f.SetScale
  btn.SetSize = f.SetSize
  btn.SetWidth = f.SetWidth
  btn.SetHeight = f.SetHeight

  btn.__puiFrozen = nil
  btn.__puiOrigFuncs = nil
end

local function RestoreCapturedButton(btn)
  if not btn or not captured[btn] then
    return false
  end

  local orig = btn.__puiOrig
  local wasShown = btn:IsShown()

  UnfreezeButton(btn)

  if orig then
    if orig.parent then
      btn:SetParent(orig.parent)
    end

    btn:ClearAllPoints()

    if orig.points then
      for p = 1, #orig.points do
        local pt = orig.points[p]
        if pt then
          btn:SetPoint(unpack(pt))
        end
      end
    end

    if orig.strata then
      btn:SetFrameStrata(orig.strata)
    end
    if orig.level then
      btn:SetFrameLevel(orig.level)
    end
    if orig.scale then
      btn:SetScale(orig.scale)
    end
    if orig.alpha then
      btn:SetAlpha(orig.alpha)
    end
    if orig.width and orig.height then
      btn:SetSize(orig.width, orig.height)
    end
    if orig.hitRect and btn.SetHitRectInsets then
      btn:SetHitRectInsets(unpack(orig.hitRect))
    end
    if btn.__puiExpansionLandingBorder and orig.expansionBorderShown ~= nil then
      if orig.expansionBorderShown then
        btn.__puiExpansionLandingBorder:Show()
      else
        btn.__puiExpansionLandingBorder:Hide()
      end
    end

    if btn == _G.ExpansionLandingPageMinimapButton then
      if wasShown then
        btn:Show()
      else
        btn:Hide()
      end
    elseif orig.shown == false then
      btn:Hide()
    else
      btn:Show()
    end
  end

  btn.__puiOrig = nil
  captured[btn] = nil

  for i = #buttons, 1, -1 do
    if buttons[i] == btn then
      table.remove(buttons, i)
      break
    end
  end

  return true
end

RestoreCapturedButtons = function()
  for i = #buttons, 1, -1 do
    local btn = buttons[i]
    if btn then
      RestoreCapturedButton(btn)
    else
      table.remove(buttons, i)
    end
  end

  for k in pairs(captured) do
    captured[k] = nil
  end
end


local function PUIBucket_NoOp()
end

local function FreezeButton(btn)
  if btn.__puiFrozen then return end
  btn.__puiFrozen = true

  btn.__puiOrigFuncs = {
    SetPoint = btn.SetPoint,
    ClearAllPoints = btn.ClearAllPoints,
    SetParent = btn.SetParent,
    SetScale = btn.SetScale,
    SetSize = btn.SetSize,
    SetWidth = btn.SetWidth,
    SetHeight = btn.SetHeight,
  }

  local w, h = btn:GetSize()
  if w and h then
    btn.__puiOrigSize = { w, h }
  end

  btn.SetPoint = PUIBucket_NoOp
  btn.ClearAllPoints = PUIBucket_NoOp
  btn.SetParent = PUIBucket_NoOp
  btn.SetScale = PUIBucket_NoOp
  btn.SetSize = PUIBucket_NoOp
  btn.SetWidth = PUIBucket_NoOp
  btn.SetHeight = PUIBucket_NoOp

  btn:SetFixedFrameStrata(false)
  btn:SetFixedFrameLevel(false)
end

local function GrabButton(btn)
  if not btn or captured[btn] then return end
  if ShouldIgnore(btn) then return end

  captured[btn] = true

  -- Capture original state so we can restore on disable
  local pts
  local count = btn:GetNumPoints()
  if count and count > 0 then
    pts = {}
    for i = 1, count do
      pts[i] = { btn:GetPoint(i) }
    end
  end

  local w, h = btn:GetSize()
  local hitRect
  if btn.GetHitRectInsets then
    hitRect = { btn:GetHitRectInsets() }
  end

  btn.__puiOrig = {
    parent = btn:GetParent(),
    points = pts,
    strata = btn:GetFrameStrata(),
    level  = btn:GetFrameLevel(),
    scale  = btn:GetScale(),
    alpha  = btn:GetAlpha(),
    width  = w,
    height = h,
    shown  = btn:IsShown() or nil,
    hitRect = hitRect,
    expansionBorderShown = btn.__puiExpansionLandingBorder and btn.__puiExpansionLandingBorder:IsShown() or nil,
  }

  FreezeButton(btn)

  -- Reparent into panel (icons live in the expandable area)
  local parent = (PUIBucket and PUIBucket.__puiPanel) or PUIBucket
  btn.__puiOrigFuncs.SetParent(btn, parent)
  btn.__puiOrigFuncs.SetSize(btn, BTN_SIZE, BTN_SIZE)

  if btn == _G.ExpansionLandingPageMinimapButton then
    if btn.SetHitRectInsets then
      btn:SetHitRectInsets(0, 0, 0, 0)
    end
    if btn.__puiExpansionLandingBorder then
      btn.__puiExpansionLandingBorder:Hide()
    end
  end

  buttons[#buttons + 1] = btn
end

local function AnchorLauncherToMinimap()
  if not _launcherOnMinimap then
    return
  end

  local btn = MinimapData.IconButton
  btn:ClearAllPoints()
  btn:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -2, 0)
end

local function QueueLauncherAnchor()
  if _launcherAnchorQueued then
    return
  end

  _launcherAnchorQueued = true
  C_Timer.After(0, function()
    _launcherAnchorQueued = false
    AnchorLauncherToMinimap()
  end)
end

function MinimapData.SetLauncherOnMinimap(enabled)
  local p = _GetMinimapProfile()
  if not p then
    return false
  end

  local v = enabled and true or false
  p.pleebUIButtonOnMinimap = v

  if not MinimapData.__puiLauncherInitialized and not MinimapData.InitializeLauncher() then
    return false
  end

  if _launcherOnMinimap == v and _launcherProfile == p then
    if v then
      AnchorLauncherToMinimap()
      QueueLauncherAnchor()
    end
    return true
  end

  local btn = MinimapData.IconButton
  if not btn then
    return false
  end

  if captured[btn] then
    RestoreCapturedButton(btn)
  end

  local LDBIcon = LibStub("LibDBIcon-1.0")

  if v then
    p.lock = true
  else
    p.lock = nil
  end

  LDBIcon:Refresh("PleebUI", p)

  if v then
    LDBIcon:SetButtonSize("PleebUI", BTN_SIZE)
    LDBIcon:Lock("PleebUI")

    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 80)
  else
    LDBIcon:ResetButtonSize("PleebUI")
    LDBIcon:Unlock("PleebUI")
  end

  _launcherOnMinimap = v
  _launcherProfile = p

  if v then
    AnchorLauncherToMinimap()
    -- LibDBIcon reapplies minimapPos during login, after the launcher is created.
    QueueLauncherAnchor()
  end

  if not v and _bucketEnabled then
    GrabButton(btn)
  end

  if _bucketEnabled then
    LayoutButtons()
  end

  return true
end

InstallExpansionLandingButtonHook = function()
  local btn = _G.ExpansionLandingPageMinimapButton
  if btn.__puiBucketHooked then
    return
  end

  btn.__puiBucketHooked = true

  btn:HookScript("OnShow", function(self)
    if not _IsBucketEnabled() then
      return
    end

    if not captured[self] then
      GrabButton(self)
    end

    LayoutButtons()
  end)

  btn:HookScript("OnHide", function(self)
    if _IsBucketEnabled() and captured[self] and not self:IsShown() then
      LayoutButtons()
    end
  end)

  if btn:IsShown() and not captured[btn] then
    GrabButton(btn)
  end
end

ScanMinimapChildren = function(parent)
  if not parent or not parent.GetChildren then return end

  -- GetChildren() is expensive; do it once, not once per index.
  local children = { parent:GetChildren() }
  local n = #children
  if n <= 0 then
    return
  end

  local expansionButton = _G.ExpansionLandingPageMinimapButton

  for i = 1, n do
    local child = children[i]
    if child
      and not captured[child]
      and LooksLikeButton(child)
      and (child ~= expansionButton or child:IsShown())
    then
      GrabButton(child)
    end
  end
end


ScanLibDBIcon = function()
  local LDBIcon = LibStub("LibDBIcon-1.0")

  local list = LDBIcon:GetButtonList()
  if type(list) ~= "table" then return end

  for i = 1, #list do
    local name = list[i]
    local btn = LDBIcon:GetMinimapButton(name)
    if btn and not captured[btn] then
      GrabButton(btn)
    end
  end
end


RescanButtons = function(force)
  if not _bucketEnabled or not PUIBucket or not PUIBucket.__puiPanel then
    return false
  end

  local mmCount = (Minimap and Minimap.GetNumChildren and Minimap:GetNumChildren()) or 0
  local bdCount = (_G.MinimapBackdrop and _G.MinimapBackdrop.GetNumChildren and _G.MinimapBackdrop:GetNumChildren()) or 0

  if not force
    and mmCount == _lastMinimapChildCount
    and bdCount == _lastBackdropChildCount
  then
    return false
  end

  _lastMinimapChildCount = mmCount
  _lastBackdropChildCount = bdCount

  ScanLibDBIcon()
  ScanMinimapChildren(Minimap)

  if _G.MinimapBackdrop then
    ScanMinimapChildren(_G.MinimapBackdrop)
  end

  return true
end


SetRescanEventsEnabled = function(enabled)
  if not _rescanEventFrame then
    _rescanEventFrame = CreateFrame("Frame")

    _rescanEventFrame:SetScript("OnEvent", function()
      if not _bucketEnabled or _rescanQueued then
        return
      end

      _rescanQueued = true

      C_Timer.After(0, function()
        _rescanQueued = false

        if not _bucketEnabled then
          return
        end

        if RescanButtons(true) then
          LayoutButtons()
        end
      end)
    end)
  end

  if enabled then
    _rescanEventFrame:RegisterEvent("ADDON_LOADED")
    _rescanEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  else
    _rescanEventFrame:UnregisterAllEvents()
    _rescanQueued = false
  end
end


LayoutButtons = function()
  if not PUIBucket then return end

  -- Handle always exists and is same width as minimap
  local mmw = (Minimap and Minimap.GetWidth and Minimap:GetWidth()) or 140

  -- Collapsed: small square toggle only (bottom-right of minimap)
  if not _bucketExpanded then
    if PUIBucket.__puiPanel then
      PUIBucket.__puiPanel:Hide()
      PUIBucket.__puiPanel:SetSize(mmw, 1)
    end

    if PUIBucket.__puiHandle then
      PUIBucket.__puiHandle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
    end
    PUIBucket:SetSize(HANDLE_SIZE, HANDLE_SIZE)
    return
  end

  -- Expanded: keep handle square (no full-width top bar)
  if PUIBucket.__puiHandle then
    PUIBucket.__puiHandle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
  end

  local expansionButton = _G.ExpansionLandingPageMinimapButton
  local visibleButtons = {}

  for i = 1, #buttons do
    local btn = buttons[i]
    if btn and (btn ~= expansionButton or btn:IsShown()) then
      visibleButtons[#visibleButtons + 1] = btn
    end
  end

  -- Expanded: size panel to fit visible icons, width matches minimap, rows expand down
  local count = #visibleButtons
  local cols = MAX_COLS
  if cols < 1 then cols = 1 end

  local rows = 0
  if count > 0 then
    rows = math.ceil(count / cols)
  end

  local panelW = mmw
  local panelH
  if count == 0 then
    panelH = (MARGIN * 2) + BTN_SIZE
  else
    panelH = (MARGIN * 2) + (rows * BTN_SIZE) + ((rows - 1) * BTN_PAD)
  end

  if PUIBucket.__puiPanel then
    PUIBucket.__puiPanel:Show()
    PUIBucket.__puiPanel:SetSize(panelW, panelH)
  end

  PUIBucket:SetSize(HANDLE_SIZE, HANDLE_SIZE)

  -- Layout icons inside panel
  local panel = PUIBucket.__puiPanel or PUIBucket
  for i = 1, count do
    local btn = visibleButtons[i]
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)

    btn.__puiOrigFuncs.ClearAllPoints(btn)
    btn.__puiOrigFuncs.SetPoint(btn, "TOPLEFT", panel, "TOPLEFT",
      MARGIN + col * (BTN_SIZE + BTN_PAD),
      -(MARGIN + row * (BTN_SIZE + BTN_PAD))
    )
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(200)

    if btn ~= expansionButton then
      btn:Show()
    end
  end
end


local function OnLibDBIconCreated(_, btn)
  -- Do not capture new buttons if the bucket is disabled
  if not _IsBucketEnabled() then
    return
  end

  if btn and not captured[btn] then
    GrabButton(btn)
    LayoutButtons()
  end
end

SetLibDBIconCallbackEnabled = function(enabled)
  local LDBIcon = LibStub("LibDBIcon-1.0")

  if enabled then
    if MinimapData.__puiLibDBIconCallbackRegistered then
      return
    end

    LDBIcon.RegisterCallback(MinimapData, "LibDBIcon_IconCreated", OnLibDBIconCreated)
    MinimapData.__puiLibDBIconCallbackRegistered = true
    return
  end

  if not MinimapData.__puiLibDBIconCallbackRegistered then
    return
  end

  LDBIcon.UnregisterCallback(MinimapData, "LibDBIcon_IconCreated")
  MinimapData.__puiLibDBIconCallbackRegistered = nil
end


function MinimapData.InitializePUIBucket()
  if PUIBucket then return end
  if not _IsBucketEnabled() then return end
  if not Minimap then return end

  PUIBucket = CreateFrame("Frame", "PleebUI_MinimapPUIBucket", UIParent)
  PUIBucket:SetFrameStrata("MEDIUM")
  PUIBucket:SetFrameLevel(190)
  PUIBucket:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -2, 2)

  -- Handle (always visible)
  local handle = CreateFrame("Frame", nil, PUIBucket, "BackdropTemplate")
  PUIBucket.__puiHandle = handle
  handle:SetPoint("TOPRIGHT", PUIBucket, "TOPRIGHT", 0, 0)
  handle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
  handle:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  handle:SetBackdropColor(0.06, 0.06, 0.06, 0.90)
  handle:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)

  handle:EnableMouse(true)
  handle:SetScript("OnEnter", function()
    _BucketCancelAutoCollapse()
  end)
  handle:SetScript("OnLeave", function()
    _BucketScheduleAutoCollapse()
  end)

  -- Toggle button
  local toggle = CreateFrame("Button", nil, handle)
  toggle:SetAllPoints(handle)
  toggle:EnableMouse(true)

  local t = toggle:CreateFontString(nil, "OVERLAY")
  PUIBucket.__puiToggleText = t
  t:SetPoint("CENTER", toggle, "CENTER", 0, 0)
  t:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
  t:SetText("+")
  t:SetJustifyH("CENTER")
  t:SetJustifyV("MIDDLE")

  toggle:SetScript("OnClick", function()
    _BucketSetExpanded(not _bucketExpanded)
  end)

  -- Panel (expandable, icons live here)
  local panel = CreateFrame("Frame", nil, PUIBucket, "BackdropTemplate")
  PUIBucket.__puiPanel = panel
  panel:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, -2)
  panel:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -2)
  panel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  panel:SetBackdropColor(0.06, 0.06, 0.06, 0.90)
  panel:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)

  panel:EnableMouse(true)
  panel:SetScript("OnEnter", function()
    _BucketCancelAutoCollapse()
  end)
  panel:SetScript("OnLeave", function()
    _BucketScheduleAutoCollapse()
  end)

  panel:Hide()


  InstallExpansionLandingButtonHook()
  _BucketSetExpanded(false)

end
function MinimapData.Initialize()
  local p = _GetMinimapProfile()
  if not p then
    return false
  end

  MinimapData.InitializeLauncher()
  MinimapData.InstallMinimapClicks()
  MinimapData.SetLauncherOnMinimap(p.pleebUIButtonOnMinimap == true)
  MinimapData.SetBucketEnabled(p.bucketEnabled ~= false)

  return true
end


  _GetMinimapProfile = P:Def("_GetMinimapProfile", _GetMinimapProfile)
  _IsBucketEnabled = P:Def("_IsBucketEnabled", _IsBucketEnabled)
  _SetBucketEnabledDB = P:Def("_SetBucketEnabledDB", _SetBucketEnabledDB)
  BuildQuickMenu = P:Def("BuildQuickMenu", BuildQuickMenu)
  Minimap_OnMouseUp = P:Def("Minimap_OnMouseUp", Minimap_OnMouseUp)
  MinimapData.InstallMinimapClicks = P:Def("MinimapData.InstallMinimapClicks", MinimapData.InstallMinimapClicks)
  MinimapData.SetBucketEnabled = P:Def("MinimapData.SetBucketEnabled", MinimapData.SetBucketEnabled)
  MinimapData.InitializeLauncher = P:Def("MinimapData.InitializeLauncher", MinimapData.InitializeLauncher)
  MinimapData.SetLauncherOnMinimap = P:Def("MinimapData.SetLauncherOnMinimap", MinimapData.SetLauncherOnMinimap)
  _BucketCancelAutoCollapse = P:Def("_BucketCancelAutoCollapse", _BucketCancelAutoCollapse)
  _BucketScheduleAutoCollapse = P:Def("_BucketScheduleAutoCollapse", _BucketScheduleAutoCollapse)
  _BucketSetExpanded = P:Def("_BucketSetExpanded", _BucketSetExpanded)
  ShouldIgnore = P:Def("ShouldIgnore", ShouldIgnore)
  LooksLikeButton = P:Def("LooksLikeButton", LooksLikeButton)
  UnfreezeButton = P:Def("UnfreezeButton", UnfreezeButton)
  RestoreCapturedButton = P:Def("RestoreCapturedButton", RestoreCapturedButton)
  RestoreCapturedButtons = P:Def("RestoreCapturedButtons", RestoreCapturedButtons)
  FreezeButton = P:Def("FreezeButton", FreezeButton)
  GrabButton = P:Def("GrabButton", GrabButton)
  AnchorLauncherToMinimap = P:Def("AnchorLauncherToMinimap", AnchorLauncherToMinimap)
  QueueLauncherAnchor = P:Def("QueueLauncherAnchor", QueueLauncherAnchor)
  ScanMinimapChildren = P:Def("ScanMinimapChildren", ScanMinimapChildren)
  ScanLibDBIcon = P:Def("ScanLibDBIcon", ScanLibDBIcon)
  InstallExpansionLandingButtonHook = P:Def("InstallExpansionLandingButtonHook", InstallExpansionLandingButtonHook)
  LayoutButtons = P:Def("LayoutButtons", LayoutButtons)
  OnLibDBIconCreated = P:Def("OnLibDBIconCreated", OnLibDBIconCreated)
  MinimapData.InitializePUIBucket = P:Def("MinimapData.InitializePUIBucket", MinimapData.InitializePUIBucket)
  MinimapData.Initialize = P:Def("MinimapData.Initialize", MinimapData.Initialize)


