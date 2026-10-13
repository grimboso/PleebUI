-- File: PUI_MinimapData.lua
-- Purpose:
-- 1) PleebUI minimap icon (LDB + LibDBIcon)
-- 2) PUIBucket under minimap that captures and lays out addon minimap buttons

local ADDON_NAME, ns = ...
local Addon = ns.Addon
local Theme = ns.Theme

local MinimapData = {}
ns.MinimapData = MinimapData

local LibStub = _G.LibStub
local P = select(1, ns.Pleebug:DropIn(MinimapData, { name = "Modules.MinimapData" }))
local _G = _G
local issecretvalue = _G.issecretvalue
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
local _BucketSetExpanded

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
    local profile = _GetMinimapProfile()
    profile.bucketEnabled = not profile.bucketEnabled
    MinimapData.Initialize()
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
    if v then LayoutButtons() end
    return
  end

  _bucketEnabled = v
  if not v then
    MinimapData.SetButtonArrangement(false)
    _BucketSetExpanded(false)
    SetRescanEventsEnabled(false)
    SetLibDBIconCallbackEnabled(false)

    _lastMinimapChildCount = -1
    _lastBackdropChildCount = -1

    RestoreCapturedButtons()

    if PUIBucket then
      if PUIBucket.__puiPanel then PUIBucket.__puiPanel:Hide() end
      Theme.ApplyExpandCollapseButton(PUIBucket.__puiToggle, false)
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
local pinnedButtons = {}
local overflowButtons = {}
local buttonsByName = {}
local pinnedMembership = {}
local _arrangingButtons = false
local dragGhost
local draggedButton

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
  if not _bucketEnabled or not _bucketExpanded or _arrangingButtons then
    return
  end
  _bucketAutoCollapseTimer = C_Timer.NewTimer(COLLAPSE_SECONDS, function()
    if PUIBucket and PUIBucket.__puiHandle and PUIBucket.__puiHandle:IsMouseOver() then
      _BucketScheduleAutoCollapse()
      return
    end
    if PUIBucket and PUIBucket.__puiAddonPanel and PUIBucket.__puiAddonPanel:IsMouseOver() then
      _BucketScheduleAutoCollapse()
      return
    end
    _BucketSetExpanded(false)
  end)
end

_BucketSetExpanded = function(expanded)
  _bucketExpanded = expanded and true or false

  if not PUIBucket then
    return
  end

  if not _bucketExpanded then
    MinimapData.SetButtonArrangement(false)
  end

  if _bucketExpanded then
    RescanButtons(true)
  end

  if PUIBucket.__puiPanel then
    if _bucketExpanded then
      PUIBucket.__puiPanel:Show()
      Theme.ApplyExpandCollapseButton(PUIBucket.__puiToggle, true)
      _BucketScheduleAutoCollapse()
    else
      PUIBucket.__puiPanel:Hide()
      Theme.ApplyExpandCollapseButton(PUIBucket.__puiToggle, false)
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
  local forbidden = frame:IsForbidden()
  if issecretvalue(forbidden) then
    return true
  end
  if forbidden then
    return true
  end

  local hasSecretAspect = frame:HasAnySecretAspect()
  if issecretvalue(hasSecretAspect) then
    return true
  end
  if hasSecretAspect then
    return true
  end

  local hasSecretValues = frame:HasSecretValues()
  if issecretvalue(hasSecretValues) then
    return true
  end
  if hasSecretValues then
    return true
  end

  local anchoringSecret = frame:IsAnchoringSecret()
  if issecretvalue(anchoringSecret) then
    return true
  end
  if anchoringSecret then
    return true
  end

  local protected = frame:IsProtected()
  if issecretvalue(protected) then
    return true
  end
  if protected then
    return true
  end

  if frame == Minimap.ZoomIn
    or frame == Minimap.ZoomOut
  then
    return true
  end

  if frame == MinimapData.IconButton and _launcherOnMinimap then
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
  if ShouldIgnore(frame) then return false end
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

  if btn.__puiArrangeOverlay then
    btn.__puiArrangeOverlay:Hide()
  end

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
    btn:SetScript("OnDragStart", orig.onDragStart)
    btn:SetScript("OnDragStop", orig.onDragStop)
    if btn.__puiExpansionLandingBorder and orig.expansionBorderShown ~= nil then
      if orig.expansionBorderShown then
        btn.__puiExpansionLandingBorder:Show()
      else
        btn.__puiExpansionLandingBorder:Hide()
      end
    end

    if btn == MinimapData.IconButton then
      btn:SetShown(_GetMinimapProfile().hide ~= true)
    elseif btn == _G.ExpansionLandingPageMinimapButton then
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

function MinimapData.IsArrangingButtons()
  return _arrangingButtons
end

function MinimapData.SetButtonArrangement(enabled)
  _arrangingButtons = enabled == true and _bucketEnabled == true
    and _GetMinimapProfile().pinnedAddonRows > 0

  if draggedButton then
    dragGhost:StopMovingOrSizing()
    dragGhost:Hide()
    draggedButton = nil
  end

  if not _arrangingButtons then
    for i = 1, #buttons do
      local overlay = buttons[i].__puiArrangeOverlay
      if overlay then overlay:Hide() end
    end
    if PUIBucket then
      PUIBucket.__puiAddonPanel:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)
      _BucketScheduleAutoCollapse()
    end
    return
  end

  _BucketCancelAutoCollapse()
  _BucketSetExpanded(true)
end

local function BeginButtonDrag(overlay)
  if not _arrangingButtons then return end

  draggedButton = overlay.__puiButton
  local x, y = GetCursorPosition()
  local scale = dragGhost:GetEffectiveScale()
  dragGhost:ClearAllPoints()
  dragGhost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
  dragGhost.Text:SetText((draggedButton.__puiBucketKey:gsub("^LibDBIcon10_", "")))
  dragGhost:Show()
  dragGhost:StartMoving()
  _G.GameTooltip:Hide()
  _BucketCancelAutoCollapse()
end

local function FinishButtonDrag()
  if not draggedButton then return end

  local btn = draggedButton
  draggedButton = nil
  dragGhost:StopMovingOrSizing()
  dragGhost:Hide()

  local addonPanel = PUIBucket.__puiAddonPanel
  local inToolbox = PUIBucket.__puiPanel:IsShown() and PUIBucket.__puiPanel:IsMouseOver()
  local inPinned = _GetMinimapProfile().pinnedAddonRows > 0
    and addonPanel:IsShown() and addonPanel:IsMouseOver() and not inToolbox
  if not inPinned and not inToolbox then return end

  local pins = _GetMinimapProfile().pinnedAddonButtons
  local key = btn.__puiBucketKey
  for i = #pins, 1, -1 do
    if pins[i] == key then table.remove(pins, i) end
  end

  if inPinned then
    local x, y = GetCursorPosition()
    local scale = addonPanel:GetEffectiveScale()
    local cols = PUIBucket.__puiColumns
    local col = math.max(0, math.min(cols - 1,
      math.floor((x / scale - addonPanel:GetLeft() - MARGIN + BTN_PAD / 2) / (BTN_SIZE + BTN_PAD))))
    local row = math.max(0, math.min(_GetMinimapProfile().pinnedAddonRows - 1,
      math.floor((addonPanel:GetTop() - y / scale - MARGIN + BTN_PAD / 2) / (BTN_SIZE + BTN_PAD))))
    local slot = row * cols + col + 1
    local visibleIndex = 0
    local beforeKey
    for i = 1, #pinnedButtons do
      local other = pinnedButtons[i]
      if other ~= btn then
        visibleIndex = visibleIndex + 1
        if visibleIndex == slot then
          beforeKey = other.__puiBucketKey
          break
        end
      end
    end
    local insertAt = #pins + 1
    if beforeKey then
      for i = 1, #pins do
        if pins[i] == beforeKey then insertAt = i; break end
      end
    end
    table.insert(pins, insertAt, key)
  end

  LayoutButtons()
end

local function EnsureArrangementOverlay(btn)
  if btn.__puiArrangeOverlay or not btn.__puiBucketKey then return end

  -- Addon click and tooltip scripts keep their original owner; only this overlay handles arranging.
  local overlay = CreateFrame("Button", nil, btn, "BackdropTemplate")
  btn.__puiArrangeOverlay = overlay
  overlay.__puiButton = btn
  overlay:SetAllPoints(btn)
  overlay:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  overlay:SetBackdropBorderColor(0.3, 0.7, 1, 1)
  overlay:RegisterForDrag("LeftButton")
  overlay:SetScript("OnDragStart", BeginButtonDrag)
  overlay:SetScript("OnDragStop", FinishButtonDrag)
  overlay:SetScript("OnEnter", function(self)
    _G.GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    _G.GameTooltip:AddLine(btn.__puiBucketKey:gsub("^LibDBIcon10_", ""), 1, 1, 1)
    _G.GameTooltip:AddLine("Drag between Pinned addons and the toolbox.", 0.7, 0.7, 0.7)
    _G.GameTooltip:AddLine("Right-click the toolbox arrow when finished.", 0.7, 0.7, 0.7)
    _G.GameTooltip:Show()
  end)
  overlay:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
  overlay:Hide()
end

local function GrabButton(btn)
  if not btn or captured[btn] then return end
  if ShouldIgnore(btn) then return end

  captured[btn] = true
  btn.__puiBucketKey = btn:GetName()

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
    shown  = btn:IsShown(),
    onDragStart = btn:GetScript("OnDragStart"),
    onDragStop = btn:GetScript("OnDragStop"),
    hitRect = hitRect,
    expansionBorderShown = btn.__puiExpansionLandingBorder and btn.__puiExpansionLandingBorder:IsShown() or nil,
  }

  FreezeButton(btn)
  btn:SetScript("OnDragStart", nil)
  btn:SetScript("OnDragStop", nil)

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
  EnsureArrangementOverlay(btn)
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

  local pinnedActive = p.enabled ~= false and p.bucketEnabled ~= false and p.pinnedAddonRows > 0
  local v = enabled == true and not pinnedActive

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

function MinimapData.SetLauncherHidden(hidden)
  local profile = _GetMinimapProfile()
  profile.hide = hidden == true
  local icon = LibStub("LibDBIcon-1.0")
  if profile.hide then icon:Hide("PleebUI") else icon:Show("PleebUI") end
  if _bucketEnabled then LayoutButtons() end
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
  if not _bucketEnabled or not PUIBucket then return end

  local profile = _GetMinimapProfile()
  local mmw = Minimap:GetWidth()
  local cols = math.max(1, math.floor((mmw - MARGIN * 2 + BTN_PAD) / (BTN_SIZE + BTN_PAD)))
  local pinnedRows = profile.pinnedAddonRows
  local capacity = cols * pinnedRows
  local addonPanel = PUIBucket.__puiAddonPanel
  local panel = PUIBucket.__puiPanel
  PUIBucket.__puiColumns = cols
  PUIBucket.__puiHandle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
  PUIBucket:SetSize(HANDLE_SIZE, HANDLE_SIZE)

  wipe(pinnedButtons)
  wipe(overflowButtons)
  wipe(buttonsByName)
  wipe(pinnedMembership)
  local expansionButton = _G.ExpansionLandingPageMinimapButton
  for i = 1, #buttons do
    local btn = buttons[i]
    if btn.__puiBucketKey and (btn ~= expansionButton or btn:IsShown())
      and (btn ~= MinimapData.IconButton or profile.hide ~= true)
    then
      buttonsByName[btn.__puiBucketKey] = btn
    end
  end

  for i = 1, #profile.pinnedAddonButtons do
    local btn = buttonsByName[profile.pinnedAddonButtons[i]]
    if btn and not pinnedMembership[btn] and #pinnedButtons < capacity then
      pinnedButtons[#pinnedButtons + 1] = btn
      pinnedMembership[btn] = true
    end
  end

  for i = 1, #buttons do
    local btn = buttons[i]
    if not pinnedMembership[btn] and (btn ~= expansionButton or btn:IsShown())
      and (btn ~= MinimapData.IconButton or profile.hide ~= true)
    then
      overflowButtons[#overflowButtons + 1] = btn
    end
  end

  local pinnedHeight = 0
  if pinnedRows > 0 then
    pinnedHeight = MARGIN * 2 + pinnedRows * BTN_SIZE + (pinnedRows - 1) * BTN_PAD
  end
  addonPanel:SetBackdropBorderColor(_arrangingButtons and 0.3 or 0.12,
    _arrangingButtons and 0.7 or 0.12, _arrangingButtons and 1 or 0.12, 1)

  local overflowTop = pinnedHeight > 0 and pinnedHeight - MARGIN or 0
  local rows = math.max(1, math.ceil(#overflowButtons / cols))
  local overflowHeight = MARGIN * 2 + rows * BTN_SIZE + (rows - 1) * BTN_PAD
  addonPanel:SetSize(mmw, _bucketExpanded and overflowTop + overflowHeight or pinnedHeight)
  addonPanel:SetShown(pinnedRows > 0 or _bucketExpanded)

  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", addonPanel, "TOPLEFT", 0, -overflowTop)
  panel:SetSize(mmw, overflowHeight)
  panel:SetShown(_bucketExpanded)

  for group = 1, 2 do
    local list = group == 1 and pinnedButtons or overflowButtons
    local parent = group == 1 and addonPanel or panel
    for i = 1, #list do
      local btn = list[i]
      local col = (i - 1) % cols
      local row = math.floor((i - 1) / cols)
      btn.__puiOrigFuncs.SetParent(btn, parent)
      btn.__puiOrigFuncs.ClearAllPoints(btn)
      btn.__puiOrigFuncs.SetPoint(btn, "TOPLEFT", parent, "TOPLEFT",
        MARGIN + col * (BTN_SIZE + BTN_PAD), -(MARGIN + row * (BTN_SIZE + BTN_PAD)))
      btn:SetFrameStrata(PUIBucket:GetFrameStrata())
      btn:SetFrameLevel(parent:GetFrameLevel() + 1)
      if btn ~= expansionButton then btn:Show() end
      local overlay = btn.__puiArrangeOverlay
      if overlay then
        overlay:SetFrameStrata(btn:GetFrameStrata())
        overlay:SetFrameLevel(btn:GetFrameLevel() + 10)
        overlay:SetShown(_arrangingButtons)
      end
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

  PUIBucket = CreateFrame("Frame", "PleebUI_MinimapPUIBucket", _G.MinimapCluster)
  PUIBucket:SetFrameStrata("HIGH")
  PUIBucket:SetFrameLevel(1)
  PUIBucket:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -2, 2)

  -- Keep the handle on the bucket's strata when the minimap is raised.
  local handle = CreateFrame("Frame", nil, PUIBucket, "BackdropTemplate")
  PUIBucket.__puiHandle = handle
  handle:SetFrameLevel(PUIBucket:GetFrameLevel() + 1)
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
  PUIBucket.__puiToggle = toggle
  toggle:SetAllPoints(handle)
  toggle:SetFrameLevel(handle:GetFrameLevel() + 1)
  toggle:EnableMouse(true)
  toggle:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  Theme.ApplyExpandCollapseButton(toggle, false)

  toggle:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      MinimapData.SetButtonArrangement(not _arrangingButtons)
    else
      _BucketSetExpanded(not _bucketExpanded)
    end
  end)
  toggle:SetScript("OnEnter", function(self)
    _BucketCancelAutoCollapse()
    _G.GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    _G.GameTooltip:AddLine("Addon toolbox", 1, 1, 1)
    _G.GameTooltip:AddLine("Left-click: Open or close", 0.7, 0.7, 0.7)
    _G.GameTooltip:AddLine(_arrangingButtons and "Right-click: Finish arranging" or "Right-click: Arrange buttons", 0.7, 0.7, 0.7)
    _G.GameTooltip:Show()
  end)
  toggle:SetScript("OnLeave", function()
    _G.GameTooltip:Hide()
    _BucketScheduleAutoCollapse()
  end)

  local addonPanel = CreateFrame("Frame", nil, PUIBucket, "BackdropTemplate")
  PUIBucket.__puiAddonPanel = addonPanel
  addonPanel:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", 0, 0)
  addonPanel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  addonPanel:SetBackdropColor(0.06, 0.06, 0.06, 0.90)
  addonPanel:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)

  dragGhost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  dragGhost:SetFrameStrata("TOOLTIP")
  dragGhost:SetSize(160, 30)
  dragGhost:SetMovable(true)
  dragGhost:EnableMouse(false)
  dragGhost:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
  dragGhost:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
  dragGhost.Text = dragGhost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  dragGhost.Text:SetPoint("LEFT", 4, 0)
  dragGhost.Text:SetPoint("RIGHT", -4, 0)
  dragGhost:Hide()

  local panel = CreateFrame("Frame", nil, addonPanel)
  PUIBucket.__puiPanel = panel

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
  if not p.pinnedAddonButtons then
    -- Seed once, outside AceDB array defaults, so removed pins stay removed after reload.
    p.pinnedAddonButtons = {
      "LibDBIcon10_PleebUI Damage Meters",
      "LibDBIcon10_PleebUI",
      "LibDBIcon10_BugSack",
      "LibDBIcon10_BigWigs",
      "LibDBIcon10_DBM",
    }
  end
  MinimapData.SetButtonArrangement(false)
  MinimapData.SetLauncherOnMinimap(p.pleebUIButtonOnMinimap == true)
  MinimapData.SetBucketEnabled(p.enabled ~= false and p.bucketEnabled ~= false)

  return true
end


  _GetMinimapProfile = P:Def("_GetMinimapProfile", _GetMinimapProfile)
  _IsBucketEnabled = P:Def("_IsBucketEnabled", _IsBucketEnabled)
  BuildQuickMenu = P:Def("BuildQuickMenu", BuildQuickMenu)
  Minimap_OnMouseUp = P:Def("Minimap_OnMouseUp", Minimap_OnMouseUp)
  MinimapData.InstallMinimapClicks = P:Def("MinimapData.InstallMinimapClicks", MinimapData.InstallMinimapClicks)
  MinimapData.SetBucketEnabled = P:Def("MinimapData.SetBucketEnabled", MinimapData.SetBucketEnabled)
  MinimapData.InitializeLauncher = P:Def("MinimapData.InitializeLauncher", MinimapData.InitializeLauncher)
  MinimapData.SetLauncherOnMinimap = P:Def("MinimapData.SetLauncherOnMinimap", MinimapData.SetLauncherOnMinimap)
  MinimapData.SetLauncherHidden = P:Def("MinimapData.SetLauncherHidden", MinimapData.SetLauncherHidden)
  _BucketCancelAutoCollapse = P:Def("_BucketCancelAutoCollapse", _BucketCancelAutoCollapse)
  _BucketScheduleAutoCollapse = P:Def("_BucketScheduleAutoCollapse", _BucketScheduleAutoCollapse)
  _BucketSetExpanded = P:Def("_BucketSetExpanded", _BucketSetExpanded)
  ShouldIgnore = P:Def("ShouldIgnore", ShouldIgnore)
  LooksLikeButton = P:Def("LooksLikeButton", LooksLikeButton)
  UnfreezeButton = P:Def("UnfreezeButton", UnfreezeButton)
  RestoreCapturedButton = P:Def("RestoreCapturedButton", RestoreCapturedButton)
  RestoreCapturedButtons = P:Def("RestoreCapturedButtons", RestoreCapturedButtons)
  FreezeButton = P:Def("FreezeButton", FreezeButton)
  MinimapData.IsArrangingButtons = P:Def("MinimapData.IsArrangingButtons", MinimapData.IsArrangingButtons)
  MinimapData.SetButtonArrangement = P:Def("MinimapData.SetButtonArrangement", MinimapData.SetButtonArrangement)
  BeginButtonDrag = P:Def("BeginButtonDrag", BeginButtonDrag)
  FinishButtonDrag = P:Def("FinishButtonDrag", FinishButtonDrag)
  EnsureArrangementOverlay = P:Def("EnsureArrangementOverlay", EnsureArrangementOverlay)
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


