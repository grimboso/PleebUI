-- File: PUI_PCM_BuffBars.lua

local ADDON_NAME, ns = ...



local Addon = ns.Addon
local BuffBars = Addon:NewModule("PCM_BuffBars")
ns.Modules.PCM_BuffBars = BuffBars


local P, TrackThis = ns.Pleebug:DropIn(BuffBars, { name = "PCM", bucket = "BuffBarViewer" })

local function _PCM_BuffBarsEnabled()
  if ns.PCM_IsTransitionPending() then
    return false
  end

  return ns.PCM_IsModuleEnabledFast() == true
end

local Theme     = ns.Theme
local IconSkin  = ns.IconSkin
local FrameUtil = ns.FrameUtil
local LSM       = ns.LSM
local PCMHooks  = ns.PCMHooks
local PCMRuntime = ns.PCMRuntime
local Round     = ns.Pixel.Round
local math_abs          = math.abs
local math_max          = math.max
local UnitClass         = UnitClass
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local C_CooldownViewer  = C_CooldownViewer
local CooldownViewerCategory = Enum.CooldownViewerCategory

local _buffBarHolder = nil

local _Init
local _buffBarStyleRev = 1
local _buffBarLayoutRev = 1
local _buffBarStyleCached = false
local _buffBarStyleCache
local _buffBarDBCache
local _buffBarConfiguredSlotsViewer
local _buffBarConfiguredSlotsGeneration = -1
local _buffBarConfiguredSlots = 0

local function _InvalidateBuffBarStyleCache()
  _buffBarStyleCached = false
  _buffBarStyleCache = nil
  _buffBarDBCache = nil
end

local function _GetBuffBarStyle()
  if not _buffBarStyleCached then
    _buffBarStyleCache = ns.PCM_DBExports.GetStyleDB()
    _buffBarDBCache = _buffBarStyleCache and _buffBarStyleCache.buffBar or nil
    _buffBarStyleCached = true
  end

  return _buffBarStyleCache, _buffBarDBCache
end

local function _GetBuffBarGeometry(bb)
  local vertical = bb and bb.orientation == "VERTICAL"

  local length = (bb and bb.width ~= nil) and (tonumber(bb.width) or 250) or 250
  if length < 120 then length = 120 end
  if length > 500 then length = 500 end

  local thickness = (bb and bb.height ~= nil) and (tonumber(bb.height) or 20) or 20
  if thickness < 8 then thickness = 8 end
  if thickness > 40 then thickness = 40 end

  local gap = tonumber(bb and bb.iconGap) or tonumber(bb and bb.padding) or 1
  if gap < 0 then gap = 0 end
  if gap > 20 then gap = 20 end

  local iconPlacement = bb and bb.iconPlacement or (vertical and "TOP" or "LEFT")
  local showIcon = iconPlacement ~= "HIDE"
  local iconSize = thickness
  if bb and bb.iconSize ~= nil then
    iconSize = tonumber(bb.iconSize) or iconSize
  end
  if iconSize < 8 then iconSize = 8 end
  if iconSize > 80 then iconSize = 80 end

  length = Round(length)
  thickness = Round(thickness)
  gap = Round(gap)
  iconSize = Round(iconSize)

  local barWidth = vertical and thickness or length
  local barHeight = vertical and length or thickness
  local rowWidth = barWidth
  local rowHeight = barHeight

  if showIcon then
    if vertical then
      rowWidth = math_max(rowWidth, iconSize)
      rowHeight = rowHeight + iconSize + gap
    else
      rowWidth = rowWidth + iconSize + gap
      rowHeight = math_max(rowHeight, iconSize)
    end
  end

  return vertical, length, thickness, gap, iconPlacement, showIcon, iconSize, barWidth, barHeight, rowWidth, rowHeight
end

local function _GetConfiguredBuffBarSlots(viewer)
  local itemGeneration = PCMRuntime:GetViewerGenerations(viewer)
  if _buffBarConfiguredSlotsViewer ~= viewer or _buffBarConfiguredSlotsGeneration ~= itemGeneration then
    _buffBarConfiguredSlotsViewer = viewer
    _buffBarConfiguredSlotsGeneration = itemGeneration
    _buffBarConfiguredSlots = #C_CooldownViewer.GetCooldownViewerCategorySet(CooldownViewerCategory.TrackedBar, false)
  end

  return _buffBarConfiguredSlots
end

local function _GetBuffBarGrowthPoints(bb, vertical)
  local growthDirection = bb and bb.growthDirection or (vertical and "RIGHT" or "DOWN")

  if vertical then
    local growLeft = growthDirection == "LEFT"
    return growthDirection, growLeft and "RIGHT" or "LEFT", growLeft and "LEFT" or "RIGHT"
  end

  local growUp = growthDirection == "UP"
  return growthDirection, growUp and "BOTTOM" or "TOP", growUp and "TOP" or "BOTTOM"
end

local function _AnchorBuffBarHolderToGrowthOrigin(holder, rowPoint)
  local point, relativeTo, relativePoint = holder:GetPoint(1)
  if holder:GetNumPoints() == 1
    and point == rowPoint
    and relativeTo == UIParent
    and relativePoint == "CENTER"
  then
    return
  end

  local centerX, centerY = holder:GetCenter()
  local parentX, parentY = UIParent:GetCenter()
  local x = centerX - parentX
  local y = centerY - parentY

  if rowPoint == "TOP" then
    y = y + (holder:GetHeight() / 2)
  elseif rowPoint == "BOTTOM" then
    y = y - (holder:GetHeight() / 2)
  elseif rowPoint == "LEFT" then
    x = x - (holder:GetWidth() / 2)
  else
    x = x + (holder:GetWidth() / 2)
  end

  holder:ClearAllPoints()
  holder:SetPoint(rowPoint, UIParent, "CENTER", x, y)
end

local function _BuffBarUsesReverseFill(bb)
  if bb and bb.orientation == "VERTICAL" then
    return bb.drainDirection == "TOP_TO_BOTTOM"
  end

  return bb and bb.drainDirection == "LEFT_TO_RIGHT"
end

local function _GetBuffBarHolder()
  if _buffBarHolder then
    _buffBarHolder:Show()
    return _buffBarHolder
  end

  local _, bb = _GetBuffBarStyle()
  local _, _, _, _, _, _, _, _, _, rowWidth, rowHeight = _GetBuffBarGeometry(bb)

  _buffBarHolder = _G.CreateFrame("Frame", nil, UIParent)
  _buffBarHolder:SetSize(rowWidth, rowHeight)
  _buffBarHolder:Show()

  return _buffBarHolder
end


-- Color resolution
local function _GetBuffBarColor()
  local r, g, b, a = 0.2, 0.6, 1.0, 1.0 -- fallback

  local style, bb = _GetBuffBarStyle()
  local useClass = true
  local override

  if style then
    local bbUse =
         (bb and bb.useClassColor)
      or (bb and bb.useClassColors)
      or (bb and bb.useClass)
      or (bb and bb.classColor)

    if bbUse ~= nil then
      useClass = not not bbUse
    else
      useClass = style.buffBarUseClassColor ~= false
    end

    local manual =
         (bb and bb.color)
      or (bb and bb.barColor)
      or (bb and bb.foregroundColor)
      or style.buffBarColor

    if not useClass then
      override = manual
    else
      override = nil
    end
  end

  if type(override) == "table" then
    r = override.r or override[1] or r
    g = override.g or override[2] or g
    b = override.b or override[3] or b
    a = override.a or override[4] or a
    return r, g, b, a
  end

  if useClass then
    local _, class = UnitClass("player")
    local cc = class and RAID_CLASS_COLORS[class]
    if cc then
      r, g, b, a = cc.r or r, cc.g or g, cc.b or b, 1
      return r, g, b, a
    end
  end

  local colors = Theme.colors or Theme.Colors or Theme.bars
  if colors then
    local c = colors.cooldownBar or colors.cooldowns
    if not c and colors.bars then
      c = colors.bars.primary or colors.bars.cooldowns
    end
    if type(c) == "table" then
      r = c.r or c[1] or r
      g = c.g or c[2] or g
      b = c.b or c[3] or b
      a = c.a or c[4] or a
    end
  end

  return r, g, b, a
end

local function _GetBuffBarBackgroundColor()
  local r, g, b, a = 0.12, 0.12, 0.12, 0.95
  local style, bb = _GetBuffBarStyle()
  if style then
    local c =
         (bb and bb.bgColor)
      or (bb and bb.backgroundColor)
      or style.buffBarBgColor

    if type(c) == "table" then
      r = c.r or c[1] or r
      g = c.g or c[2] or g
      b = c.b or c[3] or b
      a = c.a or c[4] or a
    end
  end
  return r, g, b, a
end

-- Row discovery (no PCM helpers)
local function _IsUsableRow(f)
  if not f then return false end
  if f.IsForbidden and f:IsForbidden() then return false end
  if f.GetObjectType and not f:GetObjectType() then return false end

  -- A BuffBar row usually has one of these
  local bar = f.Bar or f.StatusBar or f.ProgressBar
  if not (bar and bar.SetStatusBarTexture) then
    return false
  end

  return true
end

local __PUI_PCM_BuffBarRows = {}
local __PUI_PCM_BuffBarRowState = setmetatable({}, { __mode = "k" })
local _buffBarRowsDirty = true
local _buffBarRowsViewer = nil
local _RequestBuffBarRefresh

local function _MarkBuffBarRowsDirty(viewer)
  _buffBarRowsDirty = true
  if viewer then
    _buffBarRowsViewer = viewer
  end
end

local function _SortBuffBarRows(a, b)
  local ai = a and (a.layoutIndex or (a.GetID and a:GetID()) or 0) or 0
  local bi = b and (b.layoutIndex or (b.GetID and b:GetID()) or 0) or 0
  return ai < bi
end

local function _GetBuffBarRows(viewer)
  if not viewer or (viewer.IsForbidden and viewer:IsForbidden()) then
    return __PUI_PCM_BuffBarRows
  end

  if (not _buffBarRowsDirty) and _buffBarRowsViewer == viewer then
    return __PUI_PCM_BuffBarRows
  end

  wipe(__PUI_PCM_BuffBarRows)
  _buffBarRowsViewer = viewer

  local items = PCMRuntime:GetViewerItems(viewer)
  for index = 1, #items do
    local row = items[index]
    if _IsUsableRow(row) then
      __PUI_PCM_BuffBarRows[#__PUI_PCM_BuffBarRows + 1] = row
    end
  end

  if #__PUI_PCM_BuffBarRows > 1 then
    table.sort(__PUI_PCM_BuffBarRows, _SortBuffBarRows)
  end

  _buffBarRowsDirty = false
  return __PUI_PCM_BuffBarRows
end


local function _GetRowState(rowFrame)
  if not rowFrame then
    return nil
  end

  local state = __PUI_PCM_BuffBarRowState[rowFrame]
  if not state then
    state = {}
    __PUI_PCM_BuffBarRowState[rowFrame] = state
  end

  if not state.layoutHooks and rowFrame.HookScript then
    state.layoutHooks = true

    rowFrame:HookScript("OnShow", function()
      _RequestBuffBarRefresh("row-show")
    end)

    rowFrame:HookScript("OnHide", function()
      _RequestBuffBarRefresh("row-hide")
    end)
  end

  return state
end

local function _DimensionsDiffer(frame, width, height)
  if not frame or not frame.GetWidth or not frame.GetHeight then
    return false
  end

  return math_abs((frame:GetWidth() or 0) - width) > 0.01
    or math_abs((frame:GetHeight() or 0) - height) > 0.01
end



-- Styling
local function _ApplyBorder(target, thickness, color)
  IconSkin.ApplyBorder(target, {
    enabled = (thickness and thickness > 0),
    thickness = thickness or 0,
    color = color,
    useThemeColor = false,
  })
end

local function _StyleRow_StripChrome(rowFrame)
  local pip = rowFrame.Bar and rowFrame.Bar.Pip or nil
  if pip then
    pip:SetTexture(nil)
    pip:Hide()
  end
end

local function _StyleRow_ApplyBar(rowFrame, bar, bb)
  if not (bar and bar.SetStatusBarTexture) then
    return
  end

  local tex
  local texName = bb and bb.texture or "Pleebar"
  if texName then
    tex = LSM:Fetch("statusbar", texName)
  end
  if tex then
    bar:SetStatusBarTexture(tex)
  end

  local r, g, b, a = _GetBuffBarColor()
  bar:SetStatusBarColor(r, g, b, a)
  bar:SetOrientation(bb and bb.orientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL")
  bar:SetReverseFill(_BuffBarUsesReverseFill(bb))

  -- Remove extra Blizzard art regions (keep statusbar texture)
  local barTex = bar.GetStatusBarTexture and bar:GetStatusBarTexture() or nil
  if bar.GetRegions then
    local num = bar:GetNumRegions() or 0
    for i = 1, num do
      local region = select(i, bar:GetRegions())
      if region
         and region.GetObjectType
         and region:GetObjectType() == "Texture"
         and region ~= barTex then
        region:SetTexture(nil)
        region:Hide()
      end
    end
  end

  local bgR, bgG, bgB, bgA = _GetBuffBarBackgroundColor()
  local bg = bar.__PUIBuffBarBG
  if not bg and bar.CreateTexture then
    bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.__PUIBuffBarBG = bg
  end
  if bg then
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    bg:SetColorTexture(bgR, bgG, bgB, bgA)
    bg:Show()
  end
end

local function _StyleRow_ApplyIcon(rowFrame)
  local iconContainer = rowFrame.Icon or rowFrame.icon or rowFrame.IconContainer
  local icon = iconContainer and (iconContainer.Icon or iconContainer.icon) or nil
  local cd = iconContainer and (iconContainer.Cooldown or iconContainer.cooldown) or nil

  if icon then
    IconSkin.StripIconMasks(icon)
    if icon.SetTexCoord then
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
  end

  if iconContainer then
    IconSkin.StripAllVisualLayers(iconContainer, { keepBackdrop = false })
    IconSkin.MakeIconSquare(iconContainer, { crop = 0.08 })
    if icon then
      IconSkin.MakeIconSquare(icon, { crop = 0.08 })
    end
    if cd then
      IconSkin.SquareCooldown(cd)
    end
  end

  return iconContainer
end

local function _StyleRow_ApplyFonts(rowFrame, iconContainer)

  local nameFS = rowFrame.Bar and rowFrame.Bar.Name or nil
  local durFS  = rowFrame.Bar and rowFrame.Bar.Duration or nil

  local appsFS
  if iconContainer then
    local apps = iconContainer.Applications
    if apps and apps.Applications then
      appsFS = apps.Applications
    elseif apps and apps.SetText then
      appsFS = apps
    end
  end

  if nameFS then Theme.ApplyFont(nameFS, "body") end
  if durFS  then Theme.ApplyFont(durFS,  "body") end
  if appsFS then Theme.ApplyFont(appsFS, "nav")  end
end

local function _ApplyRowTextLayout(bar, vertical)
  if not bar then
    return
  end

  local nameFS = bar.Name
  if nameFS then
    nameFS:SetAlpha(vertical and 0 or 1)
    if not vertical then
      nameFS:ClearAllPoints()
      nameFS:SetPoint("TOPLEFT", bar, "TOPLEFT", 5, 0)
      nameFS:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -25, 0)
      nameFS:SetJustifyH("LEFT")
    end
  end

  local durFS = bar.Duration
  if durFS then
    durFS:ClearAllPoints()
    if vertical then
      durFS:SetPoint("CENTER", bar, "CENTER", 0, 0)
      durFS:SetJustifyH("CENTER")
    else
      durFS:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
      durFS:SetJustifyH("LEFT")
    end
  end
end

local function _StyleRow_ApplyBorders(bar, iconContainer, bb)
  local thickness = bb and tonumber(bb.borderThickness) or 2
  local color = bb and bb.borderColor or { 1, 1, 1, 1 }

  if bar then
    _ApplyBorder(bar, thickness, color)
  end
  if iconContainer then
    _ApplyBorder(iconContainer, thickness, color)
  end
end

local function _ApplyRowSizing(rowFrame, bar, iconContainer, bb, state)
  if not state then
    return
  end

  local vertical, length, thickness, gap, iconPlacement, showIcon, iconSize, barWidth, barHeight, rowWidth, rowHeight = _GetBuffBarGeometry(bb)
  local orientation = vertical and "VERTICAL" or "HORIZONTAL"

  local needsSizing =
       state.sizingRev ~= _buffBarLayoutRev
    or state.lastOrientation ~= orientation
    or state.lastLength ~= length
    or state.lastThickness ~= thickness
    or state.lastIconSize ~= iconSize
    or state.lastRowWidth ~= rowWidth
    or state.lastRowHeight ~= rowHeight
    or state.lastIconPlacement ~= iconPlacement
    or state.lastIconShown ~= showIcon
    or state.lastIconGap ~= gap
    or _DimensionsDiffer(rowFrame, rowWidth, rowHeight)
    or _DimensionsDiffer(bar, barWidth, barHeight)
    or (showIcon and iconContainer and _DimensionsDiffer(iconContainer, iconSize, iconSize))

  if not needsSizing then
    return
  end

  if rowFrame and rowFrame.SetSize then
    rowFrame:SetSize(rowWidth, rowHeight)
  elseif rowFrame then
    if rowFrame.SetWidth then rowFrame:SetWidth(rowWidth) end
    if rowFrame.SetHeight then rowFrame:SetHeight(rowHeight) end
  end

  state.sizingRev = _buffBarLayoutRev
  state.lastOrientation = orientation
  state.lastLength = length
  state.lastThickness = thickness
  state.lastIconSize = iconSize
  state.lastRowWidth = rowWidth
  state.lastRowHeight = rowHeight
  state.lastIconPlacement = iconPlacement
  state.lastIconShown = showIcon
  state.lastIconGap = gap

  if showIcon and iconContainer then
    if iconContainer.SetShown then
      iconContainer:SetShown(true)
    elseif iconContainer.Show then
      iconContainer:Show()
    end

    if iconContainer.ClearAllPoints and iconContainer.SetPoint then
      iconContainer:ClearAllPoints()
      if vertical then
        if iconPlacement == "BOTTOM" then
          iconContainer:SetPoint("BOTTOM", rowFrame, "BOTTOM", 0, 0)
        else
          iconContainer:SetPoint("TOP", rowFrame, "TOP", 0, 0)
        end
      elseif iconPlacement == "RIGHT" then
        iconContainer:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
      else
        iconContainer:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)
      end
    end
    if iconContainer.SetSize then
      iconContainer:SetSize(iconSize, iconSize)
    end

    local icon = iconContainer.Icon or iconContainer.icon
    if icon and icon.SetAllPoints then
      icon:ClearAllPoints()
      icon:SetAllPoints(iconContainer)
    end
  elseif iconContainer and iconContainer.Hide then
    iconContainer:Hide()
  end

  if bar then
    if bar.ClearAllPoints and bar.SetPoint then
      bar:ClearAllPoints()
      if showIcon and iconContainer then
        if vertical then
          if iconPlacement == "BOTTOM" then
            bar:SetPoint("BOTTOM", iconContainer, "TOP", 0, gap)
          else
            bar:SetPoint("TOP", iconContainer, "BOTTOM", 0, -gap)
          end
        elseif iconPlacement == "RIGHT" then
          bar:SetPoint("RIGHT", iconContainer, "LEFT", -gap, 0)
        else
          bar:SetPoint("LEFT", iconContainer, "RIGHT", gap, 0)
        end
      else
        bar:SetPoint("CENTER", rowFrame, "CENTER", 0, 0)
      end
    end
    if bar.SetSize then
      bar:SetSize(barWidth, barHeight)
    elseif bar.SetHeight then
      bar:SetHeight(barHeight)
    end

    _ApplyRowTextLayout(bar, vertical)
  end
end

local function _StyleRow(rowFrame)
  if not rowFrame or (rowFrame.IsForbidden and rowFrame:IsForbidden()) then
    return nil
  end

  local state = _GetRowState(rowFrame)
  if state and state.styledRev == _buffBarStyleRev then
    return state
  end

  local _, bb = _GetBuffBarStyle()

  local bar = rowFrame.Bar or rowFrame.StatusBar or rowFrame.ProgressBar

  _StyleRow_StripChrome(rowFrame)
  _StyleRow_ApplyBar(rowFrame, bar, bb)
  local iconContainer = _StyleRow_ApplyIcon(rowFrame)
  _StyleRow_ApplyFonts(rowFrame, iconContainer)
  _StyleRow_ApplyBorders(bar, iconContainer, bb)

  state.styledRev = _buffBarStyleRev
  return state
end

local _ApplySavedViewerPos

-- Layout + refresh
local function _Refresh()
  if not _PCM_BuffBarsEnabled() then
    return
  end

  local viewer = PCMRuntime:GetViewer("BuffBarCooldownViewer")
  if not viewer or (viewer.IsForbidden and viewer:IsForbidden()) then
    -- If Blizzard hasn't created the viewer yet, make sure we keep trying to init.
    _Init()
    return
  end

  local holder = _GetBuffBarHolder()
  if not holder then
    return
  end

  if holder.SetFrameStrata and viewer.GetFrameStrata then
    holder:SetFrameStrata(viewer:GetFrameStrata())
  end
  if holder.SetFrameLevel and viewer.GetFrameLevel then
    holder:SetFrameLevel((viewer:GetFrameLevel() or 0) + 1)
  end

  if PCMHooks.InBlizzardEditMode() then
    return
  end

  local _, bb = _GetBuffBarStyle()
  local vertical, _, _, _, _, _, _, _, _, rowWidth, rowHeight = _GetBuffBarGeometry(bb)

  local rowSpacing = 4
  if bb and bb.rowSpacing ~= nil then
    rowSpacing = tonumber(bb.rowSpacing) or rowSpacing
  end
  if rowSpacing < -20 then rowSpacing = -20 end
  if rowSpacing > 40  then rowSpacing = 40  end
  rowSpacing = Round(rowSpacing)

  local growthDirection = bb and bb.growthDirection or (vertical and "RIGHT" or "DOWN")
  local rowPoint
  local previousPoint
  local stepX = 0
  local stepY = 0

  if vertical then
    local growLeft = growthDirection == "LEFT"
    rowPoint = growLeft and "RIGHT" or "LEFT"
    previousPoint = growLeft and "LEFT" or "RIGHT"
    stepX = growLeft and -rowSpacing or rowSpacing
  else
    local growUp = growthDirection == "UP"
    rowPoint = growUp and "BOTTOM" or "TOP"
    previousPoint = growUp and "TOP" or "BOTTOM"
    stepY = growUp and rowSpacing or -rowSpacing
  end

  local rows = _GetBuffBarRows(viewer)
  local prev
  local anchorIndex = 0

  for i = 1, #rows do
    local row = rows[i]
    if row then
      local state = _StyleRow(row) or _GetRowState(row)
      local bar = row.Bar or row.StatusBar or row.ProgressBar
      local iconContainer = row.Icon or row.icon or row.IconContainer

      if row.SetParent and row.GetParent and row:GetParent() ~= holder then
        row:SetParent(holder)
      end

      _ApplyRowSizing(row, bar, iconContainer, bb, state)

      local isShown = row.IsShown and row:IsShown()
      if isShown then
        anchorIndex = anchorIndex + 1

        local expectedRelative = prev or holder
        local expectedRelativePoint = prev and previousPoint or rowPoint
        local expectedX = prev and stepX or 0
        local expectedY = prev and stepY or 0
        local point, relativeTo, relativePoint, x, y = row:GetPoint(1)
        local anchorChanged = row:GetNumPoints() ~= 1
          or point ~= rowPoint
          or relativeTo ~= expectedRelative
          or relativePoint ~= expectedRelativePoint
          or math_abs((x or 0) - expectedX) > 0.01
          or math_abs((y or 0) - expectedY) > 0.01

        local needsAnchor = true
        if state then
          needsAnchor = anchorChanged
            or (state.layoutRev ~= _buffBarLayoutRev)
            or (state.lastShown ~= true)
            or (state.lastAnchorIndex ~= anchorIndex)
            or (state.lastPrevRow ~= prev)
            or (state.lastRowSpacing ~= rowSpacing)
            or (state.lastGrowthDirection ~= growthDirection)
        end

        if needsAnchor and row.ClearAllPoints and row.SetPoint then
          row:ClearAllPoints()
          if not prev then
            row:SetPoint(rowPoint, holder, rowPoint, 0, 0)
          else
            row:SetPoint(rowPoint, prev, previousPoint, expectedX, expectedY)
          end
        end

        if state then
          state.layoutRev = _buffBarLayoutRev
          state.lastShown = true
          state.lastAnchorIndex = anchorIndex
          state.lastPrevRow = prev
          state.lastRowSpacing = rowSpacing
          state.lastGrowthDirection = growthDirection
        end

        prev = row
      elseif state then
        state.lastShown = false
        state.lastAnchorIndex = nil
        state.lastPrevRow = nil
        state.lastRowSpacing = rowSpacing
        state.lastGrowthDirection = growthDirection
      end
    end
  end

  if holder and holder.SetSize then
    local totalSlots = viewer.itemFramePool:GetNumActive()
    local holderWidth = totalSlots > 0 and rowWidth or 1
    local holderHeight = totalSlots > 0 and rowHeight or 1

    if totalSlots > 0 then
      if vertical then
        holderWidth = (totalSlots * rowWidth) + ((totalSlots - 1) * rowSpacing)
      else
        holderHeight = (totalSlots * rowHeight) + ((totalSlots - 1) * rowSpacing)
      end
    end

    if holder.__puiBuffBarWidth ~= holderWidth or holder.__puiBuffBarHeight ~= holderHeight then
      holder:SetSize(holderWidth, holderHeight)
      holder.__puiBuffBarWidth = holderWidth
      holder.__puiBuffBarHeight = holderHeight
      FrameUtil.RefreshSmartSnapRuntimeLayout("BuffBarCooldownViewer")
    end
  end

  -- Re-apply saved position in case Blizzard layout moved the holder.
  _ApplySavedViewerPos()
end

function BuffBars:RefreshSettings()
  _InvalidateBuffBarStyleCache()
  _buffBarStyleRev = _buffBarStyleRev + 1
  _buffBarLayoutRev = _buffBarLayoutRev + 1
  _Refresh()
end

function _ApplySavedViewerPos()
  local holder = _GetBuffBarHolder()
  if not holder then
    return false
  end

  local _, bb = _GetBuffBarStyle()
  local pos = bb and bb.pos
  if type(pos) ~= "table" then
    return false
  end

  local point = pos.point or "CENTER"
  local relName = pos.rel or "UIParent"
  local relPoint = pos.relPoint or point
  local x = Round(tonumber(pos.x or 0) or 0)
  local y = Round(tonumber(pos.y or 0) or 0)

  local rel = _G[relName] or UIParent
  if not rel then
    rel = UIParent
  end

  if holder.__puiBuffBarPoint == point
    and holder.__puiBuffBarRelFrame == rel
    and holder.__puiBuffBarRelPoint == relPoint
    and holder.__puiBuffBarPosX == x
    and holder.__puiBuffBarPosY == y
  then
    return true
  end

  if holder.ClearAllPoints and holder.SetPoint then
    holder:ClearAllPoints()
    holder:SetPoint(point, rel, relPoint, x, y)
    holder.__puiBuffBarPoint = point
    holder.__puiBuffBarRelName = relName
    holder.__puiBuffBarRelFrame = rel
    holder.__puiBuffBarRelPoint = relPoint
    holder.__puiBuffBarPosX = x
    holder.__puiBuffBarPosY = y
    return true
  end

  return false
end

local function _EnsureDefaultViewerPos()
  local _, bb = _GetBuffBarStyle()
  if not bb then
    return false
  end

  if type(bb.pos) == "table" and bb.pos.point then
    return _ApplySavedViewerPos()
  end

  local relName = "UIParent"
  local point = "CENTER"
  local relPoint = "CENTER"
  local x = 0
  local y = -110

  bb.pos = bb.pos or {}
  bb.pos.point = point
  bb.pos.rel = relName
  bb.pos.relPoint = relPoint
  bb.pos.x = x
  bb.pos.y = y
  bb.__puiNeedDefaultPos = nil
  bb.__puiDidDefaultPos = true

  return _ApplySavedViewerPos()
end

local function _SaveViewerPos()
  local holder = _GetBuffBarHolder()
  if not holder then
    return
  end
  if not holder.GetPoint then
    return
  end

  local point, relTo, relPoint, x, y = holder:GetPoint(1)
  if not point then
    return
  end

  local relName = "UIParent"
  if relTo and relTo.GetName then
    local n = relTo:GetName()
    if n and n ~= "" then
      relName = n
    end
  end

  local _, bb = _GetBuffBarStyle()
  if not bb then
    return
  end

  bb.pos = bb.pos or {}
  bb.pos.point = point
  bb.pos.rel = relName
  bb.pos.relPoint = relPoint or point
  bb.pos.x = tonumber(x or 0) or 0
  bb.pos.y = tonumber(y or 0) or 0
end

local function _RegisterMover()
  if not _PCM_BuffBarsEnabled() then
    return
  end

  local holder = _GetBuffBarHolder()
  if not holder then
    return
  end

  -- Minimal mover registration: position persistence + edit overlay.
  FrameUtil:RegisterMover("BuffBarCooldownViewer", holder, {
    label = "Tracked Buff Bars",
    optionsString = "CooldownManager,buff_bars",
    smartSnap = {
      family = "combatBars",
      syncAxis = "NONE",
    },
    onDragStop = function()
      _SaveViewerPos()
      _ApplySavedViewerPos()
      _Refresh()
    end,
    resetPosition = function()
      local _, bb = _GetBuffBarStyle()
      if not bb then
        return
      end

      bb.pos = {
        point = "CENTER",
        rel = "UIParent",
        relPoint = "CENTER",
        x = 0,
        y = -110,
      }

      _ApplySavedViewerPos()
      _Refresh()
    end,
    quickSettings = function()
      local _, bb = _GetBuffBarStyle()
      local vertical = bb and bb.orientation == "VERTICAL"
      local iconValues = vertical
        and { TOP = "Show on top", BOTTOM = "Show on bottom", HIDE = "Hide" }
        or { LEFT = "Show on left", RIGHT = "Show on right", HIDE = "Hide" }
      local iconSorting = vertical
        and { "TOP", "BOTTOM", "HIDE" }
        or { "LEFT", "RIGHT", "HIDE" }
      local drainValues = vertical
        and { BOTTOM_TO_TOP = "Bottom to top", TOP_TO_BOTTOM = "Top to bottom" }
        or { RIGHT_TO_LEFT = "Right to left", LEFT_TO_RIGHT = "Left to right" }
      local drainSorting = vertical
        and { "BOTTOM_TO_TOP", "TOP_TO_BOTTOM" }
        or { "RIGHT_TO_LEFT", "LEFT_TO_RIGHT" }
      local growthValues = vertical
        and { RIGHT = "Right", LEFT = "Left" }
        or { DOWN = "Down", UP = "Up" }
      local growthSorting = vertical
        and { "RIGHT", "LEFT" }
        or { "DOWN", "UP" }

      return {
        ownerKey = "BuffBarCooldownViewer",
        title = "Tracked Buff Bars",
        description = "Live Cooldown Manager settings.",
        controls = {
          {
            type = "select",
            label = "Orientation",
            values = {
              HORIZONTAL = "Horizontal",
              VERTICAL = "Vertical",
            },
            sorting = { "HORIZONTAL", "VERTICAL" },
            get = function() return vertical and "VERTICAL" or "HORIZONTAL" end,
            set = function(value)
              bb.orientation = value == "VERTICAL" and "VERTICAL" or "HORIZONTAL"
              ns.PCM_DBExports.GetStyleDB()
              BuffBars:RefreshSettings()
              ns.EditModeQuickSettings:Hide()
            end,
          },
          {
            type = "slider",
            label = "Bar length",
            min = 120,
            max = 400,
            step = 4,
            get = function() return bb.width or 200 end,
            set = function(value)
              bb.width = math.floor(tonumber(value) or 200)
              BuffBars:RefreshSettings()
            end,
          },
          {
            type = "slider",
            label = "Bar thickness",
            min = 8,
            max = 40,
            step = 1,
            get = function() return bb.height or 12 end,
            set = function(value)
              bb.height = math.floor(tonumber(value) or 12)
              BuffBars:RefreshSettings()
            end,
          },
          {
            type = "select",
            label = "Icon",
            values = iconValues,
            sorting = iconSorting,
            get = function() return bb.iconPlacement end,
            set = function(value)
              if vertical then
                bb.iconPlacement = value == "BOTTOM" and "BOTTOM" or value == "HIDE" and "HIDE" or "TOP"
              else
                bb.iconPlacement = value == "RIGHT" and "RIGHT" or value == "HIDE" and "HIDE" or "LEFT"
              end
              BuffBars:RefreshSettings()
            end,
          },
          {
            type = "select",
            label = "Drain direction",
            values = drainValues,
            sorting = drainSorting,
            get = function() return bb.drainDirection end,
            set = function(value)
              if vertical then
                bb.drainDirection = value == "TOP_TO_BOTTOM" and "TOP_TO_BOTTOM" or "BOTTOM_TO_TOP"
              else
                bb.drainDirection = value == "LEFT_TO_RIGHT" and "LEFT_TO_RIGHT" or "RIGHT_TO_LEFT"
              end
              BuffBars:RefreshSettings()
            end,
          },
          {
            type = "select",
            label = "Growth direction",
            values = growthValues,
            sorting = growthSorting,
            get = function() return bb.growthDirection end,
            set = function(value)
              if vertical then
                bb.growthDirection = value == "LEFT" and "LEFT" or "RIGHT"
              else
                bb.growthDirection = value == "UP" and "UP" or "DOWN"
              end
              BuffBars:RefreshSettings()
            end,
          },
          {
            type = "statusbar",
            label = "Texture",
            values = ns.OptionsUtil.BuildStatusbarValues(false),
            get = function() return bb.texture end,
            set = function(value)
              bb.texture = value
              BuffBars:RefreshSettings()
            end,
          },
          {
            type = "slider",
            label = "Border size",
            min = 0,
            max = 6,
            step = 1,
            get = function() return bb.borderThickness or 2 end,
            set = function(value)
              bb.borderThickness = math.floor(tonumber(value) or 2)
              BuffBars:RefreshSettings()
            end,
          },
          {
            type = "toggle",
            label = "Show tooltips",
            get = function() return ns.Modules.CooldownManager:GetViewerTooltipsEnabled("BuffBarCooldownViewer") end,
            set = function(value)
              ns.Modules.CooldownManager:SetViewerTooltipsEnabled("BuffBarCooldownViewer", value)
              ns.Modules.CooldownManager:FlushPendingEditModeChanges()
            end,
          },
          {
            type = "toggle",
            label = "Hide when inactive",
            get = function() return ns.Modules.CooldownManager:GetViewerHideWhenInactive("BuffBarCooldownViewer") end,
            set = function(value)
              ns.Modules.CooldownManager:SetViewerHideWhenInactive("BuffBarCooldownViewer", value)
              ns.Modules.CooldownManager:FlushPendingEditModeChanges()
            end,
          },
        },
      }
    end,
  })
end


local function _ApplyBuffBarViewerDirty(viewer, mask)
  _buffBarRowsViewer = viewer or _buffBarRowsViewer

  if PCMRuntime:MaskHas(mask, PCMRuntime.Dirty.ITEMS) then
    _MarkBuffBarRowsDirty(_buffBarRowsViewer)
  end

  _Refresh()
end

_RequestBuffBarRefresh = function(mode)
  if not _PCM_BuffBarsEnabled() then
    return
  end

  local mask = PCMRuntime.Dirty.LAYOUT
  if mode == "items" or mode == "all" then
    mask = mask + PCMRuntime.Dirty.ITEMS
  elseif mode == "style" then
    mask = mask + PCMRuntime.Dirty.SKIN + PCMRuntime.Dirty.FONT
  elseif mode == "row-show" or mode == "row-hide" or mode == "show" then
    mask = mask + PCMRuntime.Dirty.VISIBILITY
  end

  PCMRuntime:MarkViewerDirty("BuffBarCooldownViewer", mask, "buff-bars")
end

_Init = function()
  if not _PCM_BuffBarsEnabled() then
    return
  end

  local viewer = PCMRuntime:GetViewer("BuffBarCooldownViewer")
  if not viewer or (viewer.IsForbidden and viewer:IsForbidden()) then
    return
  end

  local holder = _GetBuffBarHolder()
  if not holder then
    return
  end

  _EnsureDefaultViewerPos()
  _MarkBuffBarRowsDirty(viewer)
  _RegisterMover()
  _RequestBuffBarRefresh("all")
end

function BuffBars:RetakeBlizzardEditModeOwnership()
  if not _PCM_BuffBarsEnabled() then
    return
  end

  local viewer = PCMRuntime:GetViewer("BuffBarCooldownViewer")
  if not viewer or (viewer.IsForbidden and viewer:IsForbidden()) then
    return
  end

  _InvalidateBuffBarStyleCache()
  _buffBarLayoutRev = _buffBarLayoutRev + 1
  _MarkBuffBarRowsDirty(viewer)
  _RegisterMover()
  _Refresh()
end

function BuffBars:ApplySettings(flags)
  if not _PCM_BuffBarsEnabled() then
    return
  end

  if not flags then
    return
  end
  if flags.profile == true or flags.theme == true or flags.fonts == true then
    _InvalidateBuffBarStyleCache()
    _buffBarStyleRev = _buffBarStyleRev + 1
    _RequestBuffBarRefresh("style")
  end
end

function BuffBars:SoftRebuild(flags)
  if not _PCM_BuffBarsEnabled() then
    return
  end

  if not flags then
    return
  end

  if flags.profile == true or flags.layout == true or flags.movers == true then
    _InvalidateBuffBarStyleCache()
    _buffBarLayoutRev = _buffBarLayoutRev + 1
    _MarkBuffBarRowsDirty(PCMRuntime:GetViewer("BuffBarCooldownViewer"))
    _RegisterMover()
    _RequestBuffBarRefresh("all")
  end
end

function BuffBars:RefreshAfterTalentSwap()
  if not _PCM_BuffBarsEnabled() then
    return
  end

  local viewer = PCMRuntime:GetViewer("BuffBarCooldownViewer")
  if not viewer or (viewer.IsForbidden and viewer:IsForbidden()) then
    return
  end

  _InvalidateBuffBarStyleCache()
  _buffBarStyleRev = _buffBarStyleRev + 1
  _buffBarLayoutRev = _buffBarLayoutRev + 1
  _MarkBuffBarRowsDirty(viewer)
  _RegisterMover()
  _RequestBuffBarRefresh("all")
end

function BuffBars:OnInitialize()
  self:SetEnabledState(_PCM_BuffBarsEnabled())
end

function BuffBars:OnEnable()
  if not _PCM_BuffBarsEnabled() then
    self:Disable()
    return
  end

  PCMRuntime:SetSubscriberEnabled("BuffBars", true)
  _Init()
end

function BuffBars:OnDisable()
  PCMRuntime:SetSubscriberEnabled("BuffBars", false)
  wipe(__PUI_PCM_BuffBarRows)
  _buffBarRowsViewer = nil
  _buffBarRowsDirty = true
  _InvalidateBuffBarStyleCache()

  if _buffBarHolder then
    _buffBarHolder:Hide()
  end
end

PCMRuntime:RegisterSubscriber("BuffBars", {
  OnItemAcquired = function(key, viewer, rowFrame)
    if key ~= "BuffBarCooldownViewer" or not _IsUsableRow(rowFrame) then
      return
    end

    _MarkBuffBarRowsDirty(viewer)
    local state = _GetRowState(rowFrame)
    state.styledRev = nil
    state.sizingRev = nil
    state.layoutRev = nil

    _StyleRow(rowFrame)
  end,

  OnItemReleased = function(key, viewer, rowFrame)
    if key ~= "BuffBarCooldownViewer" then
      return
    end

    _MarkBuffBarRowsDirty(viewer)
  end,

  OnViewerChanged = function(key, viewer)
    if key ~= "BuffBarCooldownViewer" then
      return
    end

    wipe(__PUI_PCM_BuffBarRows)
    _buffBarRowsViewer = viewer
    _buffBarRowsDirty = true

    if viewer then
      _Init()
    end
  end,

  OnViewerDirty = function(key, viewer, mask)
    if key == "BuffBarCooldownViewer" and _PCM_BuffBarsEnabled() then
      _ApplyBuffBarViewerDirty(viewer, mask or 0)
    end
  end,

  OnLifecycleEvent = function(event)
    if event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
      _Init()
    end
  end,
})



  _PCM_BuffBarsEnabled = P:Def('_PCM_BuffBarsEnabled', _PCM_BuffBarsEnabled)
  _InvalidateBuffBarStyleCache = P:Def('_InvalidateBuffBarStyleCache', _InvalidateBuffBarStyleCache)
  _GetBuffBarStyle = P:Def('_GetBuffBarStyle', _GetBuffBarStyle)
  _GetBuffBarGeometry = P:Def('_GetBuffBarGeometry', _GetBuffBarGeometry)
  _GetConfiguredBuffBarSlots = P:Def('_GetConfiguredBuffBarSlots', _GetConfiguredBuffBarSlots)
  _GetBuffBarGrowthPoints = P:Def('_GetBuffBarGrowthPoints', _GetBuffBarGrowthPoints)
  _AnchorBuffBarHolderToGrowthOrigin = P:Def('_AnchorBuffBarHolderToGrowthOrigin', _AnchorBuffBarHolderToGrowthOrigin)
  _BuffBarUsesReverseFill = P:Def('_BuffBarUsesReverseFill', _BuffBarUsesReverseFill)
  _GetBuffBarHolder = P:Def('_GetBuffBarHolder', _GetBuffBarHolder)
  _GetBuffBarColor = P:Def('_GetBuffBarColor', _GetBuffBarColor)
  _GetBuffBarBackgroundColor = P:Def('_GetBuffBarBackgroundColor', _GetBuffBarBackgroundColor)
  _IsUsableRow = P:Def('_IsUsableRow', _IsUsableRow)
  _MarkBuffBarRowsDirty = P:Def('_MarkBuffBarRowsDirty', _MarkBuffBarRowsDirty)
  _SortBuffBarRows = P:Def('_SortBuffBarRows', _SortBuffBarRows)
  _GetBuffBarRows = P:Def('_GetBuffBarRows', _GetBuffBarRows)
  _GetRowState = P:Def('_GetRowState', _GetRowState)
  _DimensionsDiffer = P:Def('_DimensionsDiffer', _DimensionsDiffer)
  _ApplyBorder = P:Def('_ApplyBorder', _ApplyBorder)
  _StyleRow_StripChrome = P:Def('_StyleRow_StripChrome', _StyleRow_StripChrome)
  _StyleRow_ApplyBar = P:Def('_StyleRow_ApplyBar', _StyleRow_ApplyBar)
  _StyleRow_ApplyIcon = P:Def('_StyleRow_ApplyIcon', _StyleRow_ApplyIcon)
  _StyleRow_ApplyFonts = P:Def('_StyleRow_ApplyFonts', _StyleRow_ApplyFonts)
  _StyleRow_ApplyBorders = P:Def('_StyleRow_ApplyBorders', _StyleRow_ApplyBorders)
  _ApplyRowTextLayout = P:Def('_ApplyRowTextLayout', _ApplyRowTextLayout)
  _ApplyRowSizing = P:Def('_ApplyRowSizing', _ApplyRowSizing)
  _StyleRow = P:Def('_StyleRow', _StyleRow)
  _Refresh = P:Def('_Refresh', _Refresh)
  BuffBars.RefreshSettings = P:Def('BuffBars:RefreshSettings', BuffBars.RefreshSettings)
  BuffBars.RetakeBlizzardEditModeOwnership = P:Def('BuffBars:RetakeBlizzardEditModeOwnership', BuffBars.RetakeBlizzardEditModeOwnership)
  _ApplySavedViewerPos = P:Def('_ApplySavedViewerPos', _ApplySavedViewerPos)
  _EnsureDefaultViewerPos = P:Def('_EnsureDefaultViewerPos', _EnsureDefaultViewerPos)
  _SaveViewerPos = P:Def('_SaveViewerPos', _SaveViewerPos)
  _RegisterMover = P:Def('_RegisterMover', _RegisterMover)
  _ApplyBuffBarViewerDirty = P:Def('_ApplyBuffBarViewerDirty', _ApplyBuffBarViewerDirty)
  _RequestBuffBarRefresh = P:Def('_RequestBuffBarRefresh', _RequestBuffBarRefresh)
  BuffBars.ApplySettings = P:Def('BuffBars:ApplySettings', BuffBars.ApplySettings)
  BuffBars.SoftRebuild = P:Def('BuffBars:SoftRebuild', BuffBars.SoftRebuild)
  BuffBars.RefreshAfterTalentSwap = P:Def('BuffBars:RefreshAfterTalentSwap', BuffBars.RefreshAfterTalentSwap)
  BuffBars.OnInitialize = P:Def('BuffBars:OnInitialize', BuffBars.OnInitialize)
  BuffBars.OnEnable = P:Def('BuffBars:OnEnable', BuffBars.OnEnable)
  BuffBars.OnDisable = P:Def('BuffBars:OnDisable', BuffBars.OnDisable)
  _Init = P:Def('_Init', _Init)
