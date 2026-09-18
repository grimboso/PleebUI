
-- File: PUI_Minimap.lua
-- Purpose:
--   - Apply a simple square mask to the minimap.
--   - Optionally resize the minimap.
--   - Hide Blizzard's circular borders so the whole thing is square.
--   - Override GetMinimapShape() so button placements use a square layout.
--   - Provide an Edit Mode mover for the minimap anchor.
-- Credits to Unhalted to letting me learn from his addon and code


local ADDON_NAME, ns = ...



local Addon     = ns.Addon

local FrameUtil = ns.FrameUtil
local Theme     = ns.Theme
local Pixel     = ns.Pixel

local MinimapModule = Addon:NewModule("Minimap", "NumyAceEvent-3.0")
ns.Registry.Minimap = MinimapModule


local P = select(1, ns.Pleebug:DropIn(MinimapModule, { name = "Modules.Minimap" }))



function MinimapModule:OnInitialize()
  self.db = Addon.db:RegisterNamespace("Minimap", {
    profile = {
      enabled               = true,
      size                  = 200,      -- square width/height

      -- Position is stored as TOPRIGHT offsets (20px from top-right by default).
      x                     = -20,
      y                     = -20,


      -- Minimap-attached element toggles
      hideBorderTop         = false,
      hideInstanceDifficulty= false,
      instanceDifficultyOffsetY = 0,
      hideTracking          = false,
      hideClock             = false,
      clockFontSize         = 20,        -- default = 20 (0 = Blizzard default)
      hideCalendar          = false,
      hideZoneText          = false,
      zoneTextFontSize      = 14,

      -- Clock/Coords top box
      clockBoxEnabled       = true,
      clockBoxShowCoords    = true,
      clockBoxHeight        = 36,        -- default = 36 (0 = auto)
      clockBoxBorderSize    = 2,
      clockBoxBG            = { 0, 0, 0, 0.55 }, -- r,g,b,a
      clockBoxCoordDecimals = true,
      clockBoxCoordFontSize = 10,

      -- PleebUI minimap launcher icon (LibDBIcon)
      hide                  = false,
      minimapPos            = 220,

      -- Minimap button bucket (PUI_MinimapData.lua)
      bucketEnabled         = true,
      pleebUIButtonOnMinimap= false,

    },
  })


  ns.MinimapData.Initialize()
  _G.PleebUIAPI:RegisterPlugin("PleebUI_Minimap", {
    name = "Minimap",
  }):RegisterEditModeParticipant("runtime", {
    order = 10,
    onChanged = function(enable)
      self:OnEditModeChanged(enable)
    end,
  })
end


-- Helpers
-- Track the last computed top box height so we can reserve space in MinimapCluster
-- (keeps Blizzard Edit Mode happy and makes the mover cover the box).
local function _SetLastBoxHeight(boxHeight)
  local cluster = _G.MinimapCluster
  if not cluster or cluster:IsForbidden() then
    return
  end

  local bh = tonumber(boxHeight) or 0
  if bh < 0 then bh = 0 end
  cluster.__pui_lastBoxHeight = bh
end

local function _SyncMinimapCompositeBounds(db)
  local cluster = _G.MinimapCluster
  local map = _G.Minimap
  if not cluster or cluster:IsForbidden() or not map or map:IsForbidden() then
    return
  end

  local base = tonumber(cluster.__pui_baseSize)
  if not base or base <= 0 then
    return
  end

  local boxOn = db and db.clockBoxEnabled == true

  local boxH = 0
  if boxOn then
    boxH = tonumber(cluster.__pui_lastBoxHeight) or 0
    if boxH < 0 then boxH = 0 end
  end

  local btH = 0
  if not boxOn and cluster.BorderTop and cluster.BorderTop.GetHeight then
    btH = tonumber(cluster.BorderTop:GetHeight()) or 0
    if btH < 0 then btH = 0 end
  end

  local extraH = boxOn and boxH or btH
  cluster:SetSize(base, base + extraH)

  local container = cluster.MinimapContainer
  if container then
    container:SetSize(base, base)
    container:ClearAllPoints()

    if extraH > 0 then
      container:SetPoint("BOTTOM", cluster, "BOTTOM", 0, 0)
    else
      container:SetPoint("CENTER", cluster, "CENTER", 0, 0)
    end
  end

  map:SetSize(base, base)
  map:ClearAllPoints()

  if container then
    map:SetPoint("CENTER", container, "CENTER", 0, 0)
  elseif extraH > 0 then
    map:SetPoint("BOTTOM", cluster, "BOTTOM", 0, 0)
  else
    map:SetPoint("CENTER", cluster, "CENTER", 0, 0)
  end
end

local function ApplyMinimapInstanceDifficultyPosition(db)
  local cluster = _G.MinimapCluster
  local map = _G.Minimap
  if not cluster or cluster:IsForbidden() or not map or map:IsForbidden() then
    return
  end

  local diff = cluster.InstanceDifficulty
  if not diff or (diff.IsForbidden and diff:IsForbidden()) then
    return
  end

  local y = math.floor(tonumber(db and db.instanceDifficultyOffsetY) or 0)

  diff:ClearAllPoints()
  diff:SetPoint("TOPRIGHT", map, "TOPRIGHT", 0, y)

  local strata = (map.GetFrameStrata and map:GetFrameStrata()) or "MEDIUM"
  if diff.SetFrameStrata then
    diff:SetFrameStrata(strata)
  end
  if diff.SetFrameLevel and map.GetFrameLevel then
    diff:SetFrameLevel((map:GetFrameLevel() or 0) + 60)
  end
end

local ApplyExpansionLandingButton

local function GetExpansionLandingButton()
  local btn = _G.ExpansionLandingPageMinimapButton
  if btn and btn.IsForbidden and btn:IsForbidden() then
    return nil
  end
  return btn
end

local function ReapplyExpansionLandingButton()
  local db = MinimapModule.db.profile
  if db.enabled == false then
    return
  end

  C_Timer.After(0, function()
    ApplyExpansionLandingButton(db)
  end)
end

local function HookExpansionLandingButton()
  local btn = GetExpansionLandingButton()
  if btn and btn.UpdateIcon and not btn.__pui_expansionLandingHooked then
    btn.__pui_expansionLandingHooked = true
    hooksecurefunc(btn, "UpdateIcon", ReapplyExpansionLandingButton)
  end
end

local function StyleExpansionLandingButton(btn)
  if not btn then
    return
  end

  btn:SetScale(1)
  btn:SetSize(31, 31)
  btn:EnableMouse(true)

  if btn.RegisterForClicks then
    btn:RegisterForClicks("AnyUp")
  end

  if btn.SetHitRectInsets then
    btn:SetHitRectInsets(0, 0, 0, 0)
  end

  local icon = btn:GetNormalTexture()
  if icon then
    icon:ClearAllPoints()
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -6)
    if icon.SetTexCoord then
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
  end

  if not btn.__puiExpansionLandingBorder then
    btn.__puiExpansionLandingBorder = btn:CreateTexture(nil, "BACKGROUND")
    btn.__puiExpansionLandingBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  end

  local border = btn.__puiExpansionLandingBorder
  border:ClearAllPoints()
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
  border:Show()
end

ApplyExpansionLandingButton = function(db)
  if db.bucketEnabled ~= false then
    return
  end

  local map = _G.Minimap
  local btn = GetExpansionLandingButton()
  if not map or map:IsForbidden() or not btn then
    return
  end

  HookExpansionLandingButton()

  if not btn.__pui_expLandingOrig then
    local p1, relTo, p2, x, y = btn:GetPoint(1)
    btn.__pui_expLandingOrig = {
      parent = btn:GetParent(),
      p1 = p1,
      relTo = relTo,
      p2 = p2,
      x = x,
      y = y,
    }
  end

  local x = db.pleebUIButtonOnMinimap == true and 34 or 2

  btn:SetParent(map)
  btn:ClearAllPoints()
  btn:SetPoint("BOTTOMLEFT", map, "BOTTOMLEFT", x, 2)
  StyleExpansionLandingButton(btn)

  if btn.SetFrameStrata and map.GetFrameStrata then
    btn:SetFrameStrata(map:GetFrameStrata() or "MEDIUM")
  end
  if btn.SetFrameLevel and map.GetFrameLevel then
    btn:SetFrameLevel((map:GetFrameLevel() or 0) + 70)
  end
end

local function ApplyMinimapAnchor(db)
  local cluster = _G.MinimapCluster
  if cluster:IsForbidden() then
    return
  end

  local x = db.x or 0
  local y = db.y or 0

  -- Anchor the real Blizzard system frame directly.
  -- We reserve extra height for the top box via cluster:SetSize() in ApplySquareMask().
  cluster:ClearAllPoints()
  cluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
end

local function ApplyMinimapClockFont(db)
  local btn = _G.TimeManagerClockButton
  local fs = _G.TimeManagerClockTicker
  if not btn or btn:IsForbidden() or not fs then
    return
  end

  btn.__pui_clockFS = fs

  if not btn.__pui_clockFont then
    local font, size, flags = fs:GetFont()
    btn.__pui_clockFont = {
      font = font,
      size = size,
      flags = flags,
    }
  end

  local configuredSize = tonumber(db and db.clockFontSize) or 0
  if configuredSize > 0 then
    configuredSize = math.floor(configuredSize + 0.5)
  else
    configuredSize = 0
  end

  local original = btn.__pui_clockFont
  if not original or not original.font or not original.size then
    return
  end

  local baseSize = configuredSize > 0 and configuredSize or original.size
  local appliedSize = Theme.ResolveFontSize(baseSize, "minimap")
  if btn.__pui_clockFontAppliedSize == appliedSize then
    return
  end

  fs:SetFont(original.font, appliedSize, original.flags)
  btn.__pui_clockFontAppliedSize = appliedSize
end

local function _GetMinimapAnchorFrame()
  local cluster = _G.MinimapCluster
  if cluster and not cluster:IsForbidden() then
    -- IMPORTANT:
    -- Parent the top box to MinimapCluster (same scale space as the minimap).
    -- Parenting to __pui_moverRoot can desync scale vs MinimapCluster:SetScale(),
    -- causing the top box to appear wider than the minimap.
    return cluster
  end
  return UIParent
end

local function _ResolveClockButton()
  local btn = _G.TimeManagerClockButton
  if not btn or btn:IsForbidden() then
    return nil
  end
  return btn
end

local function _EnsureClockBox()
  local parent = _GetMinimapAnchorFrame()
  local map = _G.Minimap
  if not parent or not map or map:IsForbidden() then
    return nil
  end

  if parent.__pui_clockBox and not parent.__pui_clockBox:IsForbidden() then
    return parent.__pui_clockBox
  end

  local box = CreateFrame("Frame", nil, parent)
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      _G.GameTimeFrame:Click()
    end
  end)
  box.CoordsText = box:CreateFontString(nil, "OVERLAY")
  box.CoordsText:SetJustifyH("LEFT")

  parent.__pui_clockBox = box
  return box
end

local function _ClockBox_UpdateCoords(box)
  if not box or not box.CoordsText then
    return
  end

  local mapID = MinimapModule.playerMapID
  local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player") or nil
  if not position then
    if box.__pui_hasCoordinates then
      box.CoordsText:SetText("")
    end
    box.__pui_hasCoordinates = nil
    box.__pui_prevCoordX = nil
    box.__pui_prevCoordY = nil
    box.__pui_prevCoordDecimals = nil
    return
  end

  local showDecimals = box.__pui_coordDecimals ~= false
  local x = position.x
  local y = position.y

  if showDecimals then
    local rx = math.floor(x * 1000 + 0.5) / 10
    local ry = math.floor(y * 1000 + 0.5) / 10

    if box.__pui_prevCoordX == rx and box.__pui_prevCoordY == ry and box.__pui_prevCoordDecimals == true then
      return
    end

    box.__pui_prevCoordX = rx
    box.__pui_prevCoordY = ry
    box.__pui_prevCoordDecimals = true
    box.__pui_hasCoordinates = true

    if box.CoordsText.SetFormattedText then
      box.CoordsText:SetFormattedText("%.1f, %.1f", rx, ry)
    else
      box.CoordsText:SetText(string.format("%.1f, %.1f", rx, ry))
    end
  else
    local rx = math.floor(x * 100 + 0.5)
    local ry = math.floor(y * 100 + 0.5)

    if box.__pui_prevCoordX == rx and box.__pui_prevCoordY == ry and box.__pui_prevCoordDecimals == false then
      return
    end

    box.__pui_prevCoordX = rx
    box.__pui_prevCoordY = ry
    box.__pui_prevCoordDecimals = false
    box.__pui_hasCoordinates = true

    if box.CoordsText.SetFormattedText then
      box.CoordsText:SetFormattedText("%d, %d", rx, ry)
    else
      box.CoordsText:SetText(string.format("%d, %d", rx, ry))
    end
  end
end

local function _CancelClockCoordinateTicker(box)
  if not box or not box.__pui_coordTicker then
    return
  end

  box.__pui_coordTicker:Cancel()
  box.__pui_coordTicker = nil
end

local function ApplyClockCoordsBox(db)
  local map = _G.Minimap
  if not map or map:IsForbidden() then
    return
  end

  local btn = _ResolveClockButton()
  local box = _EnsureClockBox()
  if not box then
    return
  end

  local enableBox  = db.clockBoxEnabled and true or false
  local showCoords = db.clockBoxShowCoords and true or false
  -- Top box mode: always show clock. (No user toggle.)
  local showClock  = true

  -- If nothing would be shown, disable the box entirely.
  if (not enableBox) or ((not showCoords) and (not showClock)) then
    _CancelClockCoordinateTicker(box)
    box:Hide()
    box:SetScript("OnUpdate", nil)

    -- Restore clock to its original parent/anchor if we previously moved it.
    if btn and btn.__pui_clockOrig then
      local o = btn.__pui_clockOrig
      btn:SetParent(o.parent)
      btn:ClearAllPoints()
      if o.p1 then
        btn:SetPoint(o.p1, o.relTo, o.p2, o.x, o.y)
      end
      btn.__pui_clockBoxed = nil
    end

    local zoneBtn = _G.MinimapCluster.ZoneTextButton
    if zoneBtn.__pui_zoneOrig then
      local o = zoneBtn.__pui_zoneOrig
      zoneBtn:SetParent(o.parent)
      zoneBtn:ClearAllPoints()
      if o.p1 then
        zoneBtn:SetPoint(o.p1, o.relTo, o.p2, o.x, o.y)
      end
      zoneBtn.__pui_zoneBoxed = nil
    end

    local zoneText = _G.MinimapZoneText
    if zoneText.__pui_zoneTextOrig then
      local o = zoneText.__pui_zoneTextOrig
      zoneText:SetParent(o.parent)
      zoneText:ClearAllPoints()
      if o.p1 then
        zoneText:SetPoint(o.p1, o.relTo, o.p2, o.x, o.y)
      end
      zoneText.__pui_zoneTextOrig = nil
    end

    -- Restore Tracking + Calendar if we previously boxed them.
    local cluster = _G.MinimapCluster
    local tracking = (cluster and cluster.Tracking) or nil
    local calendar = _G.GameTimeFrame
    local mail = cluster and cluster.IndicatorFrame.MailFrame

    if tracking and not (tracking.IsForbidden and tracking:IsForbidden()) and tracking.__pui_trackOrig then
      local o = tracking.__pui_trackOrig
      tracking:SetParent(o.parent)
      tracking:ClearAllPoints()
      if o.p1 then
        tracking:SetPoint(o.p1, o.relTo, o.p2, o.x, o.y)
      end
      tracking.__pui_trackBoxed = nil
    end

    if calendar and not (calendar.IsForbidden and calendar:IsForbidden()) and calendar.__pui_calOrig then
      local o = calendar.__pui_calOrig
      calendar:SetParent(o.parent)
      calendar:ClearAllPoints()
      if o.p1 then
        calendar:SetPoint(o.p1, o.relTo, o.p2, o.x, o.y)
      end
      calendar.__pui_calBoxed = nil
    end

    if mail and not (mail.IsForbidden and mail:IsForbidden()) and mail.__pui_mailOrig then
      local o = mail.__pui_mailOrig
      mail:ClearAllPoints()
      if o.p1 then
        mail:SetPoint(o.p1, o.relTo, o.p2, o.x, o.y)
      end
      mail.__pui_mailBoxed = nil
    end

    if box.__pui_trackWrap then box.__pui_trackWrap:Hide() end
    if box.__pui_calWrap then box.__pui_calWrap:Hide() end

    -- When top box is NOT enabled, do not touch clock/tracking/calendar/zone at all.
    -- But we must ensure Zone Text is visible again if we previously hid it while boxed.
    local cluster = _G.MinimapCluster
    local zbtn = (cluster and cluster.ZoneTextButton) or nil
    local zt = _G.MinimapZoneText

    if zbtn and not (zbtn.IsForbidden and zbtn:IsForbidden()) then
      zbtn:Show()
      if zbtn.SetAlpha then zbtn:SetAlpha(1) end
    end
    if zt and zt.Show then
      zt:Show()
      if zt.SetAlpha then zt:SetAlpha(1) end
    end

    _SetLastBoxHeight(0)
    return
  end

  -- Anchor OUTSIDE the minimap: box spans the minimap width and grows upward.
  box:ClearAllPoints()
  box:SetPoint("BOTTOMLEFT", map, "TOPLEFT", 0, 0)
  box:SetPoint("BOTTOMRIGHT", map, "TOPRIGHT", 0, 0)

  -- Ensure the box renders above the minimap.
  local strata = (map.GetFrameStrata and map:GetFrameStrata()) or "MEDIUM"
  if box.SetFrameStrata then
    box:SetFrameStrata(strata)
  end
  if box.SetFrameLevel and map.GetFrameLevel then
    box:SetFrameLevel((map:GetFrameLevel() or 0) + 50)
  end

  -- Apply backdrop via Theme (border size from DB, bg color/alpha from DB).
  local edge = tonumber(db.clockBoxBorderSize) or 1
  if edge < 0 then edge = 0 end
  if edge > 16 then edge = 16 end

  Theme.SetSquareBackdrop(box, nil, edge)

  local bgFrame = box._puiBg or box
  local c = db.clockBoxBG or { 0, 0, 0, 0.55 }
  if bgFrame and bgFrame.SetBackdropColor then
    bgFrame:SetBackdropColor(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.55)
  end

  local pad = 2

  -- Resolve optional buttons we want inside the box.
  local cluster = _G.MinimapCluster
  local tracking = (cluster and cluster.Tracking) or nil
  local calendar = _G.GameTimeFrame
  local mail = cluster and cluster.IndicatorFrame.MailFrame
  local addonCompartment = _G.AddonCompartmentFrame

  if tracking and tracking.IsForbidden and tracking:IsForbidden() then
    tracking = nil
  end
  if calendar and calendar.IsForbidden and calendar:IsForbidden() then
    calendar = nil
  end
  if mail and mail.IsForbidden and mail:IsForbidden() then
    mail = nil
  end
  if addonCompartment and addonCompartment.IsForbidden and addonCompartment:IsForbidden() then
    addonCompartment = nil
  end

  -- Hide Blizzard Addon Compartment button.
  if addonCompartment then
    addonCompartment:Hide()
    if not addonCompartment.__pui_hideHooked then
      addonCompartment.__pui_hideHooked = true
      hooksecurefunc(addonCompartment, "Show", function(self)
        self:Hide()
      end)
    end
  end

  -- Respect the existing hide toggles.
  -- Top box mode: always show these when present. (No user toggles.)
  local showTracking = tracking and true or false
  local showCalendar = calendar and true or false

  -- Coords FS (top-right).
  local coordsFS = box.CoordsText
  if coordsFS then
    coordsFS:ClearAllPoints()
    coordsFS:SetPoint("TOPRIGHT", box, "TOPRIGHT", -pad, -pad)
    if coordsFS.SetJustifyH then
      coordsFS:SetJustifyH("RIGHT")
    end
  end

  if coordsFS and coordsFS.SetFont then
    local f, s, fl = nil, nil, nil

    if btn and btn.__pui_clockFS and btn.__pui_clockFS.GetFont then
      f, s, fl = btn.__pui_clockFS:GetFont()
    end

    if (not f or not s) and _G.GameFontNormalSmall and _G.GameFontNormalSmall.GetFont then
      f, s, fl = _G.GameFontNormalSmall:GetFont()
    end

    if f and s then
      local want = tonumber(db.clockBoxCoordFontSize) or 12
      if want < 8 then want = 8 end
      if want > 20 then want = 20 end
      local appliedSize = Theme.ResolveFontSize(want, "minimap")
      coordsFS:SetFont(f, math.floor(appliedSize + 0.5), fl)
    end
  end

  if coordsFS then
    if showCoords then
      coordsFS:Show()
    else
      coordsFS:SetText("")
      coordsFS:Hide()
    end
  end

  -- Normalize small button sizing for Tracking/Calendar.
  local _btnFontSize = nil
  if btn and btn.__pui_clockFS and btn.__pui_clockFS.GetFont then
    local _, s = btn.__pui_clockFS:GetFont()
    _btnFontSize = tonumber(s)
  end
  local iconSizeBase = math.max(12, ((_btnFontSize or 12) + 4))
  if iconSizeBase > 18 then
    iconSizeBase = 18
  end
  local iconSize = Pixel.Round(iconSizeBase)

  -- Wrappers to give BOTH Tracking and Calendar consistent Theme borders.
  if not box.__pui_trackWrap or box.__pui_trackWrap:IsForbidden() then
    box.__pui_trackWrap = CreateFrame("Frame", nil, box)
    box.__pui_trackWrap:EnableMouse(false)
  end
  if not box.__pui_calWrap or box.__pui_calWrap:IsForbidden() then
    box.__pui_calWrap = CreateFrame("Frame", nil, box)
    box.__pui_calWrap:EnableMouse(false)
  end

  Theme.SetSquareBackdrop(box.__pui_trackWrap, nil, 1)
  Theme.SetSquareBackdrop(box.__pui_calWrap, nil, 1)

  -- Tracking: top-left (inside a themed wrapper so it matches Calendar).
  if tracking then
    local wrap = box.__pui_trackWrap
    wrap:ClearAllPoints()
    wrap:SetPoint("TOPLEFT", box, "TOPLEFT", pad, -pad)
    wrap:SetSize(iconSize, iconSize)

    if not tracking.__pui_trackOrig then
      local p1, relTo, p2, x, y = tracking:GetPoint(1)
      tracking.__pui_trackOrig = {
        parent = tracking:GetParent(),
        p1 = p1, relTo = relTo, p2 = p2, x = x, y = y,
      }
    end

    tracking:SetParent(wrap)
    tracking:ClearAllPoints()
    tracking:SetPoint("CENTER", wrap, "CENTER", 0, 0)
    tracking.__pui_trackBoxed = true
    if tracking.SetSize then
      tracking:SetSize(iconSize, iconSize)
    end
    if tracking.Icon and tracking.Icon.SetAllPoints then
      tracking.Icon:SetAllPoints(tracking)
    end

    if showTracking then
      wrap:Show()
      tracking:Show()
    else
      tracking:Hide()
      wrap:Hide()
    end
  elseif box.__pui_trackWrap then
    box.__pui_trackWrap:Hide()
  end

  -- Calendar: next to tracking (inside a themed wrapper so it matches Tracking).
  if calendar then
    local wrap = box.__pui_calWrap
    wrap:ClearAllPoints()

    if tracking and showTracking and box.__pui_trackWrap and box.__pui_trackWrap:IsShown() then
      wrap:SetPoint("LEFT", box.__pui_trackWrap, "RIGHT", pad, 0)
    else
      wrap:SetPoint("TOPLEFT", box, "TOPLEFT", pad, -pad)
    end

    wrap:SetSize(iconSize, iconSize)

    if not calendar.__pui_calOrig then
      local p1, relTo, p2, x, y = calendar:GetPoint(1)
      calendar.__pui_calOrig = {
        parent = calendar:GetParent(),
        p1 = p1, relTo = relTo, p2 = p2, x = x, y = y,
      }
    end

    calendar:SetParent(wrap)
    calendar:ClearAllPoints()
    calendar:SetPoint("CENTER", wrap, "CENTER", 0, 0)
    calendar.__pui_calBoxed = true

    if calendar.SetSize then
      calendar:SetSize(iconSize, iconSize)
    end

    local nt = calendar.GetNormalTexture and calendar:GetNormalTexture()
    if nt and nt.SetAllPoints then
      nt:SetAllPoints(calendar)
    end
    local pt = calendar.GetPushedTexture and calendar:GetPushedTexture()
    if pt and pt.SetAllPoints then
      pt:SetAllPoints(calendar)
    end
    local ht = calendar.GetHighlightTexture and calendar:GetHighlightTexture()
    if ht and ht.SetAllPoints then
      ht:SetAllPoints(calendar)
    end

    if showCalendar then
      wrap:Show()
      calendar:Show()
    else
      calendar:Hide()
      wrap:Hide()
    end
  elseif box.__pui_calWrap then
    box.__pui_calWrap:Hide()
  end

  -- Mail: bottom-left inside the box (so it does not sit behind the box).
  if mail then
    if not mail.__pui_mailOrig then
      local p1, relTo, p2, x, y = mail:GetPoint(1)
      mail.__pui_mailOrig = {
        parent = mail:GetParent(),
        p1 = p1, relTo = relTo, p2 = p2, x = x, y = y,
      }
    end

    -- IMPORTANT: Do NOT reparent MailFrame (Blizzard calls self:Layout() on it).
    -- Just anchor it to our box and raise its level so it renders inside.
    mail:ClearAllPoints()
    mail:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", pad, pad)
    mail.__pui_mailBoxed = true

    if mail.SetFrameStrata and box.GetFrameStrata then
      mail:SetFrameStrata(box:GetFrameStrata() or "MEDIUM")
    end
    if mail.SetFrameLevel and box.GetFrameLevel then
      mail:SetFrameLevel((box:GetFrameLevel() or 0) + 20)
    end

    -- Keep the icon sized to the MailFrame without overriding Blizzard's unread-mail visibility.
    if mail.SetSize then
      mail:SetSize(iconSize, iconSize)
    end

    local icon = mail.MailIcon
    icon:SetAllPoints(mail)
    icon:SetAlpha(1)
  end

  do
    local zoneBtn = _G.MinimapCluster.ZoneTextButton
    local zoneFS = _G.MinimapZoneText

    if not zoneBtn.__pui_zoneOrig then
      local p1, relTo, p2, x, y = zoneBtn:GetPoint(1)
      zoneBtn.__pui_zoneOrig = {
        parent = zoneBtn:GetParent(),
        p1 = p1, relTo = relTo, p2 = p2, x = x, y = y,
      }
    end

    if not zoneFS.__pui_zoneTextOrig then
      local p1, relTo, p2, x, y = zoneFS:GetPoint(1)
      zoneFS.__pui_zoneTextOrig = {
        parent = zoneFS:GetParent(),
        p1 = p1, relTo = relTo, p2 = p2, x = x, y = y,
      }
    end

    zoneBtn:SetParent(box)
    zoneBtn:ClearAllPoints()
    zoneBtn:SetPoint("BOTTOM", box, "BOTTOM", 0, pad)
    zoneBtn:SetWidth(box:GetWidth() or 1)

    zoneFS:SetParent(box)
    zoneFS:ClearAllPoints()
    zoneFS:SetPoint("BOTTOM", box, "BOTTOM", 0, pad)
    zoneFS:SetJustifyH("CENTER")
    zoneFS:SetWidth(math.max(1, box:GetWidth() - (pad * 2)))
    zoneFS:SetWordWrap(false)
    zoneFS:SetMaxLines(1)
    box.__pui_zoneFS = zoneFS

    if btn and btn.__pui_clockFS then
      local f, s, fl = btn.__pui_clockFS:GetFont()
      if f and s then
        local want = tonumber(db.zoneTextFontSize) or 14
        if want < 8 then want = 8 end
        if want > 32 then want = 32 end
        local appliedSize = Theme.ResolveFontSize(want, "minimap")
        zoneFS:SetFont(f, math.floor(appliedSize + 0.5), fl)
      end

      local r, g, b, a = btn.__pui_clockFS:GetTextColor()
      zoneFS:SetTextColor(r or 1, g or 1, b or 1, a or 1)
    end

    if db.hideZoneText == true then
      zoneFS:Hide()
      zoneBtn:Hide()
    else
      zoneFS:Show()
      zoneFS:SetAlpha(1)
      zoneBtn:Show()
      zoneBtn:SetAlpha(1)
    end
  end

  -- Clock: after tracking/calendar, and before coords (or right aligned if coords hidden).
  if btn then

    if not btn.__pui_clockOrig then
      local p1, relTo, p2, x, y = btn:GetPoint(1)
      btn.__pui_clockOrig = {
        parent = btn:GetParent(),
        p1 = p1, relTo = relTo, p2 = p2, x = x, y = y,
      }
    end

    btn:SetParent(box)
    btn:ClearAllPoints()

    -- Clock: centered at the top of the box.
    btn:SetPoint("TOP", box, "TOP", 0, -pad)


    -- Anchor clock text to TOP with 2px padding (prevents "centered text" height assumptions).
    if btn.__pui_clockFS and btn.__pui_clockFS.ClearAllPoints and btn.__pui_clockFS.SetPoint then
      btn.__pui_clockFS:ClearAllPoints()
      btn.__pui_clockFS:SetPoint("TOP", btn, "TOP", 0, 0)
      if btn.__pui_clockFS.SetJustifyH then
        btn.__pui_clockFS:SetJustifyH("CENTER")
      end
    end

    -- Ensure the clock button itself is tall enough for the chosen font size.
    if btn.__pui_clockFS and btn.__pui_clockFS.GetStringHeight and btn.SetHeight then
      local th = btn.__pui_clockFS:GetStringHeight() or 0
      btn:SetHeight(math.ceil(th + 0.5))
    end

    if showClock then
      btn:Show()
    else
      btn:Hide()
    end
  end


  local h = tonumber(db.clockBoxHeight) or 0
  if h <= 0 then
    local thClock = 0
    local thZone = 0

    if btn and btn.__pui_clockFS and btn.__pui_clockFS.GetStringHeight then
      thClock = btn.__pui_clockFS:GetStringHeight() or 0
    end

    do
      local zfs = box.__pui_zoneFS
      if zfs and zfs.GetStringHeight then
        thZone = zfs:GetStringHeight() or 0
      end
    end

    h = math.ceil((thClock + thZone) + 6)
  end
  box:SetHeight(h)
  _SetLastBoxHeight(h)
  _SyncMinimapCompositeBounds(db)

  _CancelClockCoordinateTicker(box)
  box:SetScript("OnUpdate", nil)
  box.__pui_coordDecimals = db.clockBoxCoordDecimals ~= false

  if showCoords then
    box.__pui_coordTicker = C_Timer.NewTicker(1, function()
      _ClockBox_UpdateCoords(box)
    end)
    _ClockBox_UpdateCoords(box)
  end

  box:Show()
end

local function ApplyMinimapElementHides(db)

  local cluster = _G.MinimapCluster
  local boxOn = (db and db.clockBoxEnabled) and true or false

  -- BorderTop is mutually exclusive with our top box:
  -- - box enabled: hide BorderTop
  -- - box disabled: show BorderTop (default behavior)
  if cluster and not cluster:IsForbidden() and cluster.BorderTop then
    local bt = cluster.BorderTop
    local map = _G.Minimap

    if boxOn then
      bt:Hide()
    else
      bt:Show()

      -- Force it to be above the minimap visually.
      if map and not map:IsForbidden() then
        bt:SetParent(map)
        bt:ClearAllPoints()
        bt:SetPoint("BOTTOMLEFT", map, "TOPLEFT", 0, 0)
        bt:SetPoint("BOTTOMRIGHT", map, "TOPRIGHT", 0, 0)

        local strata = (map.GetFrameStrata and map:GetFrameStrata()) or "MEDIUM"
        if bt.SetFrameStrata then
          bt:SetFrameStrata(strata)
        end
        if bt.SetFrameLevel and map.GetFrameLevel then
          bt:SetFrameLevel((map:GetFrameLevel() or 0) + 60)
        end
      end
    end
  end

  if cluster and not cluster:IsForbidden() and cluster.InstanceDifficulty then
    if db.hideInstanceDifficulty then
      cluster.InstanceDifficulty:Hide()
    else
      cluster.InstanceDifficulty:Show()
      ApplyMinimapInstanceDifficultyPosition(db)
    end
  end

  -- When the top box is NOT enabled, do not touch zone text, calendar, tracking, or clock.
  -- But we still need to ensure our box is disabled/restored if it was previously enabled.
  if not boxOn then
    ApplyClockCoordsBox(db)
    ApplyExpansionLandingButton(db)
    return
  end

  -- Top box enabled: apply our custom box behavior.
  if cluster and not cluster:IsForbidden() then
    if cluster.Tracking then
      cluster.Tracking:Show()
    end
  end

  ApplyMinimapClockFont(db)
  ApplyClockCoordsBox(db)

  if _G.GameTimeFrame then
    _G.GameTimeFrame:Show()
  end

  ApplyExpansionLandingButton(db)

  do
    local zt = _G.MinimapZoneText
    local zbtn = (cluster and cluster.ZoneTextButton) or nil

    if db.hideZoneText then
      if zt then zt:Hide() end
      if zbtn then zbtn:Hide() end
    else
      if zbtn then
        zbtn:Show()
        if zbtn.SetAlpha then zbtn:SetAlpha(1) end

        local map = _G.Minimap
        if map and map.GetFrameLevel and zbtn.SetFrameLevel then
          zbtn:SetFrameLevel((map:GetFrameLevel() or 0) + 50)
        end
        if map and map.GetFrameStrata and zbtn.SetFrameStrata then
          zbtn:SetFrameStrata(map:GetFrameStrata() or "LOW")
        end
      end

      if zt then
        zt:Show()
        if zt.SetAlpha then zt:SetAlpha(1) end
      end
    end
  end

end


local function ApplySquareMask(db)
  local map = _G.Minimap
  if not map or map:IsForbidden() then
    return
  end

  local cluster = _G.MinimapCluster

  -- Square mask (must be on the real Minimap)
  map:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
  map:SetHitRectInsets(0, 0, 0, 0)


  -- Optional size tweak
  local size = db.size or 200

  -- Resize the visible container (Cluster) AND the real Minimap.
  if cluster and not cluster:IsForbidden() then
    -- Cluster is layout-driven. The most stable way to make *all attached widgets*
    -- move with the minimap is to keep a base size and scale the whole cluster.
    local base = cluster.__pui_baseSize
    if not base then
      local natural = 0

      -- Try to match the natural Blizzard top row width so Tracking + BorderTop + Calendar line up with the map.
      if cluster.BorderTop and cluster.BorderTop.GetWidth then
        natural = tonumber(cluster.BorderTop:GetWidth()) or 0
      end

      local tw = 0
      if cluster.Tracking and cluster.Tracking.GetWidth then
        tw = tonumber(cluster.Tracking:GetWidth()) or 0
      end

      local cw = 0
      local cal = _G.GameTimeFrame
      if cal and not (cal.IsForbidden and cal:IsForbidden()) and cal.GetWidth then
        cw = tonumber(cal:GetWidth()) or 0
      end

      if (tw > 0) and (cw > 0) then
        -- Add a small cushion so the two buttons don't feel squeezed.
        natural = math.max(natural, tw + cw + 8)
      end

      base = math.floor(math.max((map:GetWidth() or 200), natural, 200) + 0.5)
      if base <= 0 then base = 200 end
      cluster.__pui_baseSize = base
    end

    local scale = (tonumber(size) or base) / base
    if scale <= 0 then scale = 1 end

    cluster:SetScale(scale)
    cluster.__pui_effectiveSize = tonumber(size) or base

    _SyncMinimapCompositeBounds(db)
  else
    map:SetSize(size, size)
  end




  -- Hide round Blizzard art so it does not clash with the square map
  _G.MinimapBackdrop:Hide()
  _G.MinimapCompassTexture:Hide()

  -- Hybrid minimap (world map overlay) also needs a square mask
  local HybridMinimap = _G.HybridMinimap
  if HybridMinimap and HybridMinimap.MapCanvas and HybridMinimap.CircleMask then
    HybridMinimap.CircleMask:SetTexture("Interface\\Buttons\\WHITE8X8")
    HybridMinimap.MapCanvas:SetUseMaskTexture(true)
  end

  -- Minimap border (same border sizing as the top box).
  do
    local edge = tonumber(db and db.clockBoxBorderSize) or 1
    if edge < 0 then edge = 0 end
    if edge > 16 then edge = 16 end

    local cluster = _G.MinimapCluster
    local map = _G.Minimap
    if cluster and map and not cluster:IsForbidden() and not map:IsForbidden() then
      cluster.__pui_mmBorder = cluster.__pui_mmBorder or CreateFrame("Frame", nil, cluster)
      local b = cluster.__pui_mmBorder
      b:SetFrameStrata((map.GetFrameStrata and map:GetFrameStrata()) or "MEDIUM")
      if b.SetFrameLevel and map.GetFrameLevel then
        b:SetFrameLevel((map:GetFrameLevel() or 0) + 40)
      end

      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
      b:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", 0, 0)

      Theme.SetSquareBackdrop(b, nil, edge)

      local bgFrame = b._puiBg or b
      if bgFrame and bgFrame.SetBackdropColor then
        bgFrame:SetBackdropColor(0, 0, 0, 0)
      end
      b:Show()
    end
  end

  ApplyMinimapElementHides(db)
end


-- Simple global override so other addons know we are square
local OriginalGetMinimapShape = _G.GetMinimapShape
local function PleebUI_GetMinimapShape()
  return "SQUARE"
end

local function GetMinimapMoverGeometry(minimapCluster)
  local left = minimapCluster:GetLeft()
  local right = minimapCluster:GetRight()
  local top = minimapCluster:GetTop()
  local bottom = minimapCluster:GetBottom()

  if left and right and top and bottom then
    local scale = minimapCluster:GetScale() or 1
    local uiLeft = UIParent:GetLeft() or 0
    local uiBottom = UIParent:GetBottom() or 0
    return
      (right - left) * scale,
      (top - bottom) * scale,
      (left * scale) - uiLeft,
      (bottom * scale) - uiBottom
  end

  local width, height = minimapCluster:GetSize()
  return width, height
end

local function RegisterMinimapMover()
  local mm = _G.MinimapCluster
  if mm:IsForbidden() then
    return
  end

  local function GetDB()
    return MinimapModule.db.profile
  end

  local function SavePosition(mover)
    local db = GetDB()
    local scale = mm:GetScale() or 1
    db.x = Pixel.Round(((mover:GetRight() or UIParent:GetRight()) - UIParent:GetRight()) / scale)
    db.y = Pixel.Round(((mover:GetTop() or UIParent:GetTop()) - UIParent:GetTop()) / scale)
    ApplyMinimapAnchor(db)
  end

  FrameUtil:EnsureGhostMover("Minimap", {
    frameName = "PleebUI_MinimapGhostMover",
    label = "Minimap",
    liveFrame = mm,
    useOverlayDrag = true,
    smartSnap = {
      family = "positionOnly",
      isRuntimeActive = function()
        local db = GetDB()
        return MinimapModule:IsEnabled() and db.enabled ~= false
      end,
    },
    getSize = function()
      return GetMinimapMoverGeometry(mm)
    end,
    getPoint = function()
      local _, _, left, bottom = GetMinimapMoverGeometry(mm)
      if left and bottom then
        return "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom
      end

      local db = GetDB()
      return "TOPRIGHT", UIParent, "TOPRIGHT", db.x or -20, db.y or -20
    end,
    shouldShow = function()
      local db = GetDB()
      return MinimapModule:IsEnabled()
        and db.enabled ~= false
        and ns.Flags.IsEditing == true
    end,
    savePosition = SavePosition,
    onDragStop = function()
      FrameUtil:RefreshGhostMover("Minimap")
    end,
    resetPosition = function()
      local db = GetDB()
      db.x = -20
      db.y = -20
      ApplyMinimapAnchor(db)
      FrameUtil:RefreshGhostMover("Minimap")
    end,
    optionsString = "Minimap",
    quickSettings = function()
      return {
        ownerKey = "Minimap",
        title = "Minimap",
        description = "Live minimap settings.",
        controls = {
          {
            type = "slider",
            label = "Size",
            min = 120,
            max = 800,
            step = 1,
            get = function()
              return tonumber(db.size) or 200
            end,
            set = function(value)
              db.size = math.floor(tonumber(value) or 200)
              ApplySquareMask(db)
              ApplyMinimapAnchor(db)
              FrameUtil:RefreshGhostMover("Minimap")
            end,
          },
          {
            type = "slider",
            label = "Border size",
            min = 0,
            max = 16,
            step = 1,
            get = function()
              return tonumber(db.clockBoxBorderSize) or 2
            end,
            set = function(value)
              db.clockBoxBorderSize = math.floor(tonumber(value) or 2)
              ApplySquareMask(db)
            end,
          },
        },
      }
    end,
  })
end

function MinimapModule:OnEditModeChanged(enable)
  if enable and self.db.profile.enabled then
    RegisterMinimapMover()
  else
    FrameUtil:RefreshGhostMover("Minimap")
  end
end

-- Edit Mode can re-apply Blizzard's MinimapCluster layout when exiting,
-- which resets our saved anchor. Re-apply on exit/hide.
local function HookMinimapEditModeReapply()
  if MinimapModule.__pui_editModeHooked then return end
  MinimapModule.__pui_editModeHooked = true

  local function ReapplyNextFrame()
    if not MinimapModule.db.profile.enabled then return end

    if Addon:IsBlizzardEditModeActive() then
      return
    end

    C_Timer.After(0, function()
      if Addon:IsBlizzardEditModeActive() then
        return
      end

      local db = MinimapModule.db.profile
      if not db.enabled then
        return
      end

      ApplySquareMask(db)
      ApplyMinimapAnchor(db)
      FrameUtil:RefreshGhostMover("Minimap")
      FrameUtil.RefreshSmartSnapRuntimeLayout("Minimap")
    end)
  end

  EventRegistry:RegisterCallback("EditMode.Exit", function()
    ReapplyNextFrame()
  end)
end


function MinimapModule:PLAYER_MAP_CHANGED(event, oldMapID, newMapID)
  self.playerMapID = newMapID

  local db = self.db.profile
  if db.enabled == false or db.clockBoxEnabled == false or db.clockBoxShowCoords == false then
    return
  end

  local cluster = _G.MinimapCluster
  local box = cluster and cluster.__pui_clockBox
  if box then
    _ClockBox_UpdateCoords(box)
  end
end

function MinimapModule:OnProfileChanged()
  local db = self.db.profile

  ns.MinimapData.Initialize()

  if not db.enabled then
    local cluster = _G.MinimapCluster
    _CancelClockCoordinateTicker(cluster and cluster.__pui_clockBox)
    return
  end

  ApplySquareMask(db)
  ApplyMinimapAnchor(db)
  RegisterMinimapMover()
end

function MinimapModule:RefreshFromOptions(flags)
  local db = self.db.profile

  ns.MinimapData.SetLauncherOnMinimap(db.pleebUIButtonOnMinimap == true)
  ns.MinimapData.SetBucketEnabled(db.bucketEnabled ~= false)

  if not db.enabled then
    local cluster = _G.MinimapCluster
    _CancelClockCoordinateTicker(cluster and cluster.__pui_clockBox)
    return
  end

  ApplySquareMask(db)
  ApplyMinimapAnchor(db)
  RegisterMinimapMover()
end

function MinimapModule:RefreshFonts()
  local db = self.db.profile
  if not db.enabled then
    return
  end

  ApplyMinimapClockFont(db)

  local cluster = _G.MinimapCluster
  local box = cluster and cluster.__pui_clockBox
  if not box then
    return
  end

  local btn = _ResolveClockButton()
  local sourceFontString = btn and btn.__pui_clockFS or _G.GameFontNormalSmall
  if not sourceFontString or not sourceFontString.GetFont then
    return
  end

  local fontPath, _, flags = sourceFontString:GetFont()
  if not fontPath then
    return
  end

  local coordsFS = box.CoordsText
  if coordsFS and coordsFS.SetFont then
    local baseSize = tonumber(db.clockBoxCoordFontSize) or 12
    if baseSize < 8 then baseSize = 8 end
    if baseSize > 20 then baseSize = 20 end

    coordsFS:SetFont(
      fontPath,
      math.floor(Theme.ResolveFontSize(baseSize, "minimap") + 0.5),
      flags or ""
    )
  end

  local zoneFS = box.__pui_zoneFS
  if zoneFS and zoneFS.SetFont then
    local baseSize = tonumber(db.zoneTextFontSize) or 14
    if baseSize < 8 then baseSize = 8 end
    if baseSize > 32 then baseSize = 32 end

    zoneFS:SetFont(
      fontPath,
      math.floor(Theme.ResolveFontSize(baseSize, "minimap") + 0.5),
      flags or ""
    )
  end
end

function MinimapModule:OnEnable()
  ns.MinimapData.Initialize()

  self.playerMapID = C_Map.GetBestMapForUnit("player")
  self:RegisterEvent("PLAYER_MAP_CHANGED")

  if not self.db.profile.enabled then
    return
  end

  ApplySquareMask(self.db.profile)
  ApplyMinimapAnchor(self.db.profile)
  RegisterMinimapMover()
  HookMinimapEditModeReapply()


  -- Only override once
  if _G.GetMinimapShape ~= PleebUI_GetMinimapShape then
    _G.GetMinimapShape = PleebUI_GetMinimapShape
  end

end

function MinimapModule:OnDisable()
  self:UnregisterEvent("PLAYER_MAP_CHANGED")
  self.playerMapID = nil

  local cluster = _G.MinimapCluster
  _CancelClockCoordinateTicker(cluster and cluster.__pui_clockBox)

  if _G.GetMinimapShape == PleebUI_GetMinimapShape and OriginalGetMinimapShape then
    _G.GetMinimapShape = OriginalGetMinimapShape
  end
end


local function MinimapProvider(AddonObj)
  local provider = {}

  function provider:GetOptions()
    local db = MinimapModule.db.profile

    local function Refresh()
      AddonObj:ApplyOptionsChange("Minimap", {})
    end

    return {
      type = "group",
      name = "Minimap",
      order = 10,
      args = {
        general = {
          type = "group",
          name = "General",
          order = 10,
          inline = true,
          args = {
            enabled = {
              type = "toggle",
              name = "Enable PleebUI minimap",
              order = 10,
              get = function()
                return db.enabled and true or false
              end,
              set = function(_, v)
                db.enabled = not not v
                Refresh()
              end,
            },
            bucketEnabled = {
              type = "toggle",
              name = "Collect addon buttons",
              order = 20,
              get = function()
                return db.bucketEnabled ~= false
              end,
              set = function(_, v)
                db.bucketEnabled = not not v
                Refresh()
              end,
            },
            pleebUIButtonOnMinimap = {
              type = "toggle",
              name = "Anchor PleebUI button to minimap",
              desc = "Pins the PleebUI button to the bottom-left corner of the minimap instead of placing it in the addon button bucket.",
              order = 30,
              get = function()
                return db.pleebUIButtonOnMinimap == true
              end,
              set = function(_, v)
                db.pleebUIButtonOnMinimap = not not v
                Refresh()
              end,
            },
            size = {
              type = "range",
              name = "Minimap size",
              min = 120,
              max = 800,
              step = 1,
              order = 40,
              get = function()
                return tonumber(db.size) or 200
              end,
              set = function(_, v)
                db.size = math.floor(tonumber(v) or 200)
                Refresh()
              end,
            },
            clockBoxEnabled = {
              type = "toggle",
              name = "Show top panel",
              order = 50,
              get = function()
                return db.clockBoxEnabled and true or false
              end,
              set = function(_, v)
                db.clockBoxEnabled = not not v
                Refresh()
              end,
            },
          },
        },
        difficulty = {
          type = "group",
          name = "Difficulty icon",
          order = 20,
          inline = true,
          args = {
            hideInstanceDifficulty = {
              type = "toggle",
              name = "Hide difficulty icon",
              order = 10,
              get = function()
                return not not db.hideInstanceDifficulty
              end,
              set = function(_, v)
                db.hideInstanceDifficulty = not not v
                Refresh()
              end,
            },
            instanceDifficultyOffsetY = {
              type = "range",
              name = "Vertical offset",
              min = -40,
              max = 40,
              step = 1,
              order = 20,
              disabled = function()
                return db.hideInstanceDifficulty == true
              end,
              get = function()
                return tonumber(db.instanceDifficultyOffsetY) or 0
              end,
              set = function(_, v)
                db.instanceDifficultyOffsetY = math.floor(tonumber(v) or 0)
                Refresh()
              end,
            },
          },
        },
        topPanelText = {
          type = "group",
          name = "Top panel text",
          order = 30,
          inline = true,
          disabled = function()
            return db.clockBoxEnabled ~= true
          end,
          args = {
            clockFontSize = {
              type = "range",
              name = "Clock text size",
              desc = "Set to 0 to use Blizzard's default size.",
              min = 0,
              max = 40,
              step = 1,
              order = 10,
              get = function()
                return tonumber(db.clockFontSize) or 0
              end,
              set = function(_, v)
                db.clockFontSize = math.floor(tonumber(v) or 0)
                Refresh()
              end,
            },
            zoneTextFontSize = {
              type = "range",
              name = "Zone text size",
              min = 8,
              max = 40,
              step = 1,
              order = 20,
              get = function()
                return tonumber(db.zoneTextFontSize) or 12
              end,
              set = function(_, v)
                db.zoneTextFontSize = math.floor(tonumber(v) or 12)
                Refresh()
              end,
            },
            hideZoneText = {
              type = "toggle",
              name = "Hide zone text",
              order = 30,
              get = function()
                return db.hideZoneText and true or false
              end,
              set = function(_, v)
                db.hideZoneText = not not v
                Refresh()
              end,
            },
          },
        },
        coordinates = {
          type = "group",
          name = "Coordinates",
          order = 40,
          inline = true,
          disabled = function()
            return db.clockBoxEnabled ~= true
          end,
          args = {
            clockBoxShowCoords = {
              type = "toggle",
              name = "Show coordinates",
              order = 10,
              get = function()
                return db.clockBoxShowCoords and true or false
              end,
              set = function(_, v)
                db.clockBoxShowCoords = not not v
                Refresh()
              end,
            },
            clockBoxCoordDecimals = {
              type = "toggle",
              name = "Show decimals",
              order = 20,
              disabled = function()
                return db.clockBoxShowCoords ~= true
              end,
              get = function()
                return db.clockBoxCoordDecimals ~= false
              end,
              set = function(_, v)
                db.clockBoxCoordDecimals = not not v
                Refresh()
              end,
            },
            clockBoxCoordFontSize = {
              type = "range",
              name = "Coordinate text size",
              min = 8,
              max = 20,
              step = 1,
              order = 30,
              disabled = function()
                return db.clockBoxShowCoords ~= true
              end,
              get = function()
                return tonumber(db.clockBoxCoordFontSize) or 12
              end,
              set = function(_, v)
                db.clockBoxCoordFontSize = math.floor(tonumber(v) or 12)
                Refresh()
              end,
            },
          },
        },
        topPanelAppearance = {
          type = "group",
          name = "Top panel appearance",
          order = 50,
          inline = true,
          disabled = function()
            return db.clockBoxEnabled ~= true
          end,
          args = {
            clockBoxHeight = {
              type = "range",
              name = "Panel height",
              desc = "Set to 0 to size the panel automatically.",
              min = 0,
              max = 60,
              step = 1,
              order = 10,
              get = function()
                return tonumber(db.clockBoxHeight) or 0
              end,
              set = function(_, v)
                db.clockBoxHeight = math.floor(tonumber(v) or 0)
                Refresh()
              end,
            },
            clockBoxBorderSize = {
              type = "range",
              name = "Border size",
              min = 0,
              max = 16,
              step = 1,
              order = 20,
              get = function()
                return tonumber(db.clockBoxBorderSize) or 1
              end,
              set = function(_, v)
                db.clockBoxBorderSize = math.floor(tonumber(v) or 1)
                Refresh()
              end,
            },
            clockBoxBG = {
              type = "color",
              name = "Background color",
              order = 30,
              hasAlpha = true,
              get = function()
                local c = db.clockBoxBG or { 0, 0, 0, 0.55 }
                return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.55
              end,
              set = function(_, r, g, b, a)
                db.clockBoxBG = { r, g, b, a }
                Refresh()
              end,
            },
          },
        },
      },
    }
  end

  return provider
end

  MinimapModule.OnInitialize = P:Def("MinimapModule.OnInitialize", MinimapModule.OnInitialize)
  _SetLastBoxHeight = P:Def("_SetLastBoxHeight", _SetLastBoxHeight)
  _SyncMinimapCompositeBounds = P:Def("_SyncMinimapCompositeBounds", _SyncMinimapCompositeBounds)
  ApplyMinimapInstanceDifficultyPosition = P:Def("ApplyMinimapInstanceDifficultyPosition", ApplyMinimapInstanceDifficultyPosition)
  GetExpansionLandingButton = P:Def("GetExpansionLandingButton", GetExpansionLandingButton)
  ReapplyExpansionLandingButton = P:Def("ReapplyExpansionLandingButton", ReapplyExpansionLandingButton)
  HookExpansionLandingButton = P:Def("HookExpansionLandingButton", HookExpansionLandingButton)
  StyleExpansionLandingButton = P:Def("StyleExpansionLandingButton", StyleExpansionLandingButton)
  ApplyExpansionLandingButton = P:Def("ApplyExpansionLandingButton", ApplyExpansionLandingButton)
  ApplyMinimapAnchor = P:Def("ApplyMinimapAnchor", ApplyMinimapAnchor)
  ApplyMinimapClockFont = P:Def("ApplyMinimapClockFont", ApplyMinimapClockFont)
  _GetMinimapAnchorFrame = P:Def("_GetMinimapAnchorFrame", _GetMinimapAnchorFrame)
  _ResolveClockButton = P:Def("_ResolveClockButton", _ResolveClockButton)
  _EnsureClockBox = P:Def("_EnsureClockBox", _EnsureClockBox)
  _ClockBox_UpdateCoords = P:Def("_ClockBox_UpdateCoords", _ClockBox_UpdateCoords)
  _CancelClockCoordinateTicker = P:Def("_CancelClockCoordinateTicker", _CancelClockCoordinateTicker)
  ApplyClockCoordsBox = P:Def("ApplyClockCoordsBox", ApplyClockCoordsBox)
  ApplyMinimapElementHides = P:Def("ApplyMinimapElementHides", ApplyMinimapElementHides)
  ApplySquareMask = P:Def("ApplySquareMask", ApplySquareMask)
  PleebUI_GetMinimapShape = P:Def("PleebUI_GetMinimapShape", PleebUI_GetMinimapShape)
  GetMinimapMoverGeometry = P:Def("GetMinimapMoverGeometry", GetMinimapMoverGeometry)
  RegisterMinimapMover = P:Def("RegisterMinimapMover", RegisterMinimapMover)
  MinimapModule.OnEditModeChanged = P:Def("MinimapModule.OnEditModeChanged", MinimapModule.OnEditModeChanged)
  HookMinimapEditModeReapply = P:Def("HookMinimapEditModeReapply", HookMinimapEditModeReapply)
  MinimapModule.PLAYER_MAP_CHANGED = P:Def("MinimapModule.PLAYER_MAP_CHANGED", MinimapModule.PLAYER_MAP_CHANGED)
  MinimapModule.OnProfileChanged = P:Def("MinimapModule.OnProfileChanged", MinimapModule.OnProfileChanged)
  MinimapModule.RefreshFromOptions = P:Def("MinimapModule.RefreshFromOptions", MinimapModule.RefreshFromOptions)
  MinimapModule.RefreshFonts = P:Def("MinimapModule.RefreshFonts", MinimapModule.RefreshFonts)
  MinimapModule.OnEnable = P:Def("MinimapModule.OnEnable", MinimapModule.OnEnable)
  MinimapModule.OnDisable = P:Def("MinimapModule.OnDisable", MinimapModule.OnDisable)
  MinimapProvider = P:Def("MinimapProvider", MinimapProvider)


-- Keep the key as "Minimap" so existing movers/openOptions calls still work.
Addon:RegisterOptionsSection("Minimap", MinimapProvider, 70, "Minimap", nil, {
  preview = false,
})


