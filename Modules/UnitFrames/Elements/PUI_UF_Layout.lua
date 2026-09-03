
-- File: PUI_UF_Layout.lua
-- Purpose: Shared UnitFrames layout resolution helpers.


local ADDON_NAME, ns = ...


ns.UFLayout = ns.UFLayout or {}
local Layout = ns.UFLayout

local _G = _G
local type = _G.type
local tonumber = _G.tonumber
local math_min = _G.math.min
local Round = ns.Pixel.Round

function Layout.EnsureRaidLayoutConfig(db)
  if type(db) ~= "table" then
    return
  end

  if db.groupSortOrientation ~= "VERTICAL" then
    db.groupSortOrientation = "HORIZONTAL"
  end

  if db.lockMembersToGroup == nil then
    db.lockMembersToGroup = true
  else
    db.lockMembersToGroup = db.lockMembersToGroup == true
  end

  db.moveGroupsSeparately = false

  if db.showGroupNumbers == nil then
    db.showGroupNumbers = true
  else
    db.showGroupNumbers = db.showGroupNumbers == true
  end
end

function Layout.GetRaidMainFrameSize(db)
  if type(db) ~= "table" then
    return 0, 0
  end

  return Round(db.width or 80), Round(db.height or 44)
end

function Layout.GetRaidMaxAllowedGroups()
  return 8
end

function Layout.GetRaidEffectiveNumGroups(db)
  local numGroups = math_min(Layout.GetRaidMaxAllowedGroups(), tonumber(db and db.numGroups) or 5)
  if numGroups < 1 then
    numGroups = 1
  end

  return numGroups
end

function Layout.IsLockedGroupLayout(db)
  return not not (db and db.lockMembersToGroup ~= false)
end

function Layout.GetGroupSortOrientation(db)
  return (db and db.groupSortOrientation == "VERTICAL") and "VERTICAL" or "HORIZONTAL"
end

function Layout.GetRaidDisplayGridDimensions(db)
  if Layout.IsLockedGroupLayout(db) then
    local numGroups = Layout.GetRaidEffectiveNumGroups(db)
    local orientation = Layout.GetGroupSortOrientation(db)

    if orientation == "VERTICAL" then
      return numGroups, 5
    end

    return 5, numGroups
  end

  local numGroups = Layout.GetRaidEffectiveNumGroups(db)
  local unitsPerColumn = math_min(5, tonumber(db and db.unitsPerColumn) or 5)

  return numGroups, unitsPerColumn
end

function Layout.GetRaidConfiguredHeaderBounds(db, opts)
  opts = type(opts) == "table" and opts or {}

  local groupLabelHeight = Round(opts.groupLabelHeight or 14)
  local groupSideLabelWidth = Round(opts.groupSideLabelWidth or 26)
  local groupSideLabelOffset = Round(opts.groupSideLabelOffset or 6)

  if Layout.IsLockedGroupLayout(db) then
    local numGroups = Layout.GetRaidEffectiveNumGroups(db)
    local orientation = Layout.GetGroupSortOrientation(db)
    local width, height = Layout.GetRaidMainFrameSize(db)
    local rowSpacing = Round(db and db.rowSpacing or 3)
    local columnSpacing = Round(db and db.columnSpacing or 3)
    local horizontalSpacing = columnSpacing
    local verticalSpacing = rowSpacing
    local groupSpacing = Round(db and db.groupSpacing or ((orientation == "VERTICAL") and columnSpacing or rowSpacing))
    local groupsPerRowCol = tonumber(db and db.groupsPerRowCol) or 1
    local showGroupNumbers = db and db.showGroupNumbers ~= false
    local xDir = "RIGHT"
    local yDir = "DOWN"

    if db and db.growthDirection == "LEFT_DOWN" then
      xDir = "LEFT"
      yDir = "DOWN"
    elseif db and db.growthDirection == "RIGHT_UP" then
      xDir = "RIGHT"
      yDir = "UP"
    elseif db and db.growthDirection == "LEFT_UP" then
      xDir = "LEFT"
      yDir = "UP"
    end

    if groupsPerRowCol < 1 then
      groupsPerRowCol = 1
    elseif groupsPerRowCol > numGroups then
      groupsPerRowCol = numGroups
    end

    local x = (xDir == "LEFT") and -1 or 1
    local y = (yDir == "UP") and 1 or -1
    local point

    if orientation == "VERTICAL" then
      point = (yDir == "UP") and "BOTTOM" or "TOP"
    else
      point = (xDir == "LEFT") and "RIGHT" or "LEFT"
    end
    local frameWidth = width + horizontalSpacing
    local frameHeight = height + verticalSpacing
    local widthFive = frameWidth * 5
    local heightFive = frameHeight * 5
    local totalWidth = 0
    local totalHeight = 0
    local newCols = 0
    local newRows = 0

    for i = 1, numGroups do
      local lastIndex = i - 1
      local lastGroup = lastIndex % groupsPerRowCol

      if lastGroup == 0 then
        if point == "LEFT" or point == "RIGHT" then
          totalHeight = totalHeight + frameHeight + groupSpacing
          newRows = newRows + 1
        else
          totalWidth = totalWidth + frameWidth + groupSpacing
          newCols = newCols + 1
        end
      else
        if point == "LEFT" or point == "RIGHT" then
          if newRows == 1 then
            totalWidth = totalWidth + widthFive + groupSpacing
            newCols = newCols + 1
          end
        elseif newCols == 1 then
          totalHeight = totalHeight + heightFive + groupSpacing
          newRows = newRows + 1
        end
      end

      if totalHeight == 0 then
        totalHeight = totalHeight + heightFive + groupSpacing
      end

      if totalWidth == 0 then
        totalWidth = totalWidth + widthFive + groupSpacing
      end
    end

    totalWidth = totalWidth - horizontalSpacing - groupSpacing
    totalHeight = totalHeight - verticalSpacing - groupSpacing

    if showGroupNumbers then
      if orientation == "VERTICAL" then
        totalHeight = totalHeight + groupLabelHeight
      else
        totalWidth = totalWidth + groupSideLabelWidth + groupSideLabelOffset
      end
    end

    return totalWidth, totalHeight
  end

  local width, height = Layout.GetRaidMainFrameSize(db)
  local numGroups, unitsPerColumn = Layout.GetRaidDisplayGridDimensions(db)
  local columnSpacing = Round(db and db.columnSpacing or 3)
  local rowSpacing = Round(db and db.rowSpacing or 3)

  local totalWidth = (width * numGroups) + (columnSpacing * (numGroups - 1))
  local totalHeight = (height * unitsPerColumn) + (rowSpacing * (unitsPerColumn - 1))

  return totalWidth, totalHeight
end


local P = select(1, ns.Pleebug:DropIn(Layout, { name = "UnitFrames.Layout" }))


  Layout.EnsureRaidLayoutConfig = P:Def("Layout.EnsureRaidLayoutConfig", Layout.EnsureRaidLayoutConfig)
  Layout.GetRaidMainFrameSize = P:Def("Layout.GetRaidMainFrameSize", Layout.GetRaidMainFrameSize)
  Layout.GetRaidMaxAllowedGroups = P:Def("Layout.GetRaidMaxAllowedGroups", Layout.GetRaidMaxAllowedGroups)
  Layout.GetRaidEffectiveNumGroups = P:Def("Layout.GetRaidEffectiveNumGroups", Layout.GetRaidEffectiveNumGroups)
  Layout.IsLockedGroupLayout = P:Def("Layout.IsLockedGroupLayout", Layout.IsLockedGroupLayout)
  Layout.GetGroupSortOrientation = P:Def("Layout.GetGroupSortOrientation", Layout.GetGroupSortOrientation)
  Layout.GetRaidDisplayGridDimensions = P:Def("Layout.GetRaidDisplayGridDimensions", Layout.GetRaidDisplayGridDimensions)
  Layout.GetRaidConfiguredHeaderBounds = P:Def("Layout.GetRaidConfiguredHeaderBounds", Layout.GetRaidConfiguredHeaderBounds)


