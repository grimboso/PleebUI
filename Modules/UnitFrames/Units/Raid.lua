local ADDON_NAME, ns = ...

local Addon = ns.Addon
local oUF = ns.oUF
local UF = ns.UnitFrames
local UFDefaults = ns.UFDefaults
local UFAuraContainers = ns.UFAuraContainers
local UFStyle = ns.UFStyle
local UFMouseover = ns.UFMouseover
local UFThreat = ns.UFThreat
local UFFrameGlow = ns.UFFrameGlow
local UFLayout = ns.UFLayout
local FrameUtil = ns.FrameUtil
local UFIndicators = ns.UFIndicators
local UFText = ns.UFText
local Range = ns.Range

local _G = _G
local UIParent = _G.UIParent
local CreateFrame = _G.CreateFrame
local C_AddOns = _G.C_AddOns
local C_Timer = _G.C_Timer
local InCombatLockdown = _G.InCombatLockdown
local hooksecurefunc = _G.hooksecurefunc
local tostring = _G.tostring
local tonumber = _G.tonumber
local type = _G.type
local ipairs = _G.ipairs
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local table_concat = _G.table.concat
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local MAX_RAID_MEMBERS = _G.MAX_RAID_MEMBERS

local RaidFrames = Addon:NewModule("RaidFrames", "NumyAceEvent-3.0")
ns.Modules.RaidFrames = RaidFrames

local BlizzardRaidFramesHiddenParent = CreateFrame("Frame", nil, UIParent)
BlizzardRaidFramesHiddenParent:Hide()

local RF_GROUP_LABEL_HEIGHT = 14
local RF_GROUP_SIDE_LABEL_WIDTH = 26
local RF_GROUP_SIDE_LABEL_OFFSET = 6

local Pixel = ns.Pixel
local Round = Pixel.Round

local function MoveBlizzardRaidFrameToHiddenParent(frame)
  if not frame or frame:IsForbidden() then
    return
  end

  frame:UnregisterAllEvents()
  frame:SetParent(BlizzardRaidFramesHiddenParent)
end

local function DisableBlizzardRaidUnitFrame(frame)
  if not frame or frame:IsForbidden() then
    return
  end

  frame:UnregisterAllEvents()
  frame:SetScript("OnEvent", nil)
  frame:SetScript("OnUpdate", nil)
end

local function SuppressBlizzardRaidGroup(frame)
  if RaidFrames:IsEnabled()
    and RaidFrames.db.profile.hideBlizzard == true
    and frame
    and not frame:IsForbidden()
  then
    frame:UnregisterAllEvents()
  end
end

function RaidFrames:DisableBlizzardRaidFrames()
  if self.db.profile.hideBlizzard ~= true then
    return
  end

  local _, loaded = C_AddOns.IsAddOnLoaded("Blizzard_CompactRaidFrames")
  if not loaded then
    return
  end

  if not self._compactRaidGroupHooked then
    hooksecurefunc("CompactRaidGroup_InitializeForGroup", SuppressBlizzardRaidGroup)
    self._compactRaidGroupHooked = true
  end

  if InCombatLockdown() then
    self.pendingBlizzardRaidSuppression = true
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  self.pendingBlizzardRaidSuppression = nil

  MoveBlizzardRaidFrameToHiddenParent(_G.CompactRaidFrameManager)
  MoveBlizzardRaidFrameToHiddenParent(_G.CompactRaidFrameContainer)

  for groupIndex = 1, _G.MAX_RAID_GROUPS do
    SuppressBlizzardRaidGroup(_G["CompactRaidGroup" .. groupIndex])

    local memberIndex = 1
    local memberFrame = _G["CompactRaidGroup" .. groupIndex .. "Member" .. memberIndex]

    while memberFrame do
      DisableBlizzardRaidUnitFrame(memberFrame)
      memberIndex = memberIndex + 1
      memberFrame = _G["CompactRaidGroup" .. groupIndex .. "Member" .. memberIndex]
    end
  end

  local frameIndex = 1
  local frame = _G["CompactRaidFrame" .. frameIndex]

  while frame do
    DisableBlizzardRaidUnitFrame(frame)
    frameIndex = frameIndex + 1
    frame = _G["CompactRaidFrame" .. frameIndex]
  end
end

local function ReadRaidProfile(_, key)
  return RaidFrames.db.profile[key]
end

local RaidFrameConfig = setmetatable({}, { __index = ReadRaidProfile })
local RaidBoundsConfig = setmetatable({}, { __index = ReadRaidProfile })

local function EnsureRaidDesignDefaults(db)
  UFLayout.EnsureRaidLayoutConfig(db)

  db.width = Round(db.width or 80)
  db.height = Round(db.height or 44)
  db.rowSpacing = Round(db.rowSpacing or 3)
  db.columnSpacing = Round(db.columnSpacing or 3)
  db.numGroups = Round(db.numGroups or 5)
end

local function IsRaidGroupAllowed(db, groupIndex)
  local enabledGroups = type(db and db.enabledGroups) == "table" and db.enabledGroups or nil

  if enabledGroups then
    local shown = enabledGroups[groupIndex]
    if shown == nil then
      shown = enabledGroups[tostring(groupIndex)]
    end

    if shown ~= nil then
      return shown == true
    end
  end

  return true
end

local function GetConfiguredRaidGroups(db, maxGroups)
  local groups = {}
  local configuredGroups = math_min(maxGroups, UFLayout.GetRaidEffectiveNumGroups(db))

  for groupIndex = 1, configuredGroups do
    if IsRaidGroupAllowed(db, groupIndex) then
      groups[#groups + 1] = groupIndex
    end
  end

  return groups
end

local function GetShownRaidGroups(db)
  local maxGroups = UFLayout.GetRaidMaxAllowedGroups()
  local groups = GetConfiguredRaidGroups(db, maxGroups)

  return groups, #groups
end

local function GetActiveHeaderCount(db)
  local activeGroups, activeCount = GetShownRaidGroups(db)

  if db.lockMembersToGroup == false then
    return 1, activeGroups, activeCount
  end

  return activeCount, activeGroups, activeCount
end

local function GetGroupsPerRowCol(db, numGroups)
  local groupsPerRowCol = tonumber(db.groupsPerRowCol) or 1

  if groupsPerRowCol < 1 then
    groupsPerRowCol = 1
  elseif groupsPerRowCol > numGroups then
    groupsPerRowCol = numGroups
  end

  return groupsPerRowCol
end

local function GetRaidGrowthParts(db)
  local orientation = UFLayout.GetGroupSortOrientation(db)
  local xDirection, yDirection = FrameUtil.GetGroupedLayoutDirectionParts(db)

  xDirection = (xDirection == "LEFT") and "LEFT" or "RIGHT"
  yDirection = (yDirection == "UP") and "UP" or "DOWN"

  return orientation, xDirection, yDirection
end

local function GetHeaderChildLayout(db)
  local orientation, xDirection, yDirection = GetRaidGrowthParts(db)
  local growsVertically = orientation == "VERTICAL"
  local xMultiplier = (xDirection == "LEFT") and -1 or 1
  local yMultiplier = (yDirection == "UP") and 1 or -1
  local point
  local columnAnchorPoint

  if growsVertically then
    point = (yDirection == "UP") and "BOTTOM" or "TOP"

    if db.lockMembersToGroup == false and db.invertGroupingOrder == true then
      columnAnchorPoint = xDirection
    else
      columnAnchorPoint = (xDirection == "LEFT") and "RIGHT" or "LEFT"
    end
  else
    point = (xDirection == "LEFT") and "RIGHT" or "LEFT"

    if db.lockMembersToGroup == false and db.invertGroupingOrder == true then
      columnAnchorPoint = (yDirection == "UP") and "TOP" or "BOTTOM"
    else
      columnAnchorPoint = (yDirection == "UP") and "BOTTOM" or "TOP"
    end
  end

  local rowSpacing = Round(db.rowSpacing or 3)
  local columnSpacing = Round(db.columnSpacing or 3)
  local xOffset = 0
  local yOffset = 0
  local columnSpacingAttr

  if growsVertically then
    yOffset = rowSpacing * yMultiplier
    columnSpacingAttr = columnSpacing
  else
    xOffset = columnSpacing * xMultiplier
    columnSpacingAttr = rowSpacing
  end

  return point, xOffset, yOffset, columnSpacingAttr, columnAnchorPoint, xMultiplier, yMultiplier
end

local function GetGroupAnchorPoint(db)
  local orientation, xDirection, yDirection = GetRaidGrowthParts(db)

  if db.startFromCenter == true then
    if orientation == "VERTICAL" then
      return (xDirection == "LEFT") and "RIGHT" or "LEFT"
    end

    return (yDirection == "UP") and "BOTTOM" or "TOP"
  end

  local verticalAnchor = (yDirection == "UP") and "BOTTOM" or "TOP"
  local horizontalAnchor = (xDirection == "LEFT") and "RIGHT" or "LEFT"

  return verticalAnchor .. horizontalAnchor
end

local function GetHeaderSize(db, raidWideSorting)
  if raidWideSorting then
    local _, _, layoutGroups = GetActiveHeaderCount(db)
    RaidBoundsConfig.numGroups = layoutGroups

    return UFLayout.GetRaidConfiguredHeaderBounds(RaidBoundsConfig, {
      groupLabelHeight = RF_GROUP_LABEL_HEIGHT,
      groupSideLabelWidth = RF_GROUP_SIDE_LABEL_WIDTH,
      groupSideLabelOffset = RF_GROUP_SIDE_LABEL_OFFSET,
    })
  end

  local point = GetHeaderChildLayout(db)
  local width = Round(db.width or 80)
  local height = Round(db.height or 44)
  local rowSpacing = Round(db.rowSpacing or 3)
  local columnSpacing = Round(db.columnSpacing or 3)

  if point == "LEFT" or point == "RIGHT" then
    return (width * 5) + (columnSpacing * 4), height
  end

  return width, (height * 5) + (rowSpacing * 4)
end

local function GetHeaderPlacement(db, headerIndex)
  local raidWideSorting = db.lockMembersToGroup == false
  if raidWideSorting then
    return FrameUtil.GetGroupedMoverAnchorPoint(db), 0, 0
  end

  local _, _, numGroups = GetActiveHeaderCount(db)
  local point, _, _, _, _, xMultiplier, yMultiplier = GetHeaderChildLayout(db)
  local anchorPoint = GetGroupAnchorPoint(db)
  local groupsPerRowCol = GetGroupsPerRowCol(db, numGroups)
  local unitWidth = Round(db.width or 80)
  local unitHeight = Round(db.height or 44)
  local rowSpacing = Round(db.rowSpacing or 3)
  local columnSpacing = Round(db.columnSpacing or 3)
  local orientation = UFLayout.GetGroupSortOrientation(db)
  local groupSpacing = Round(db.groupSpacing or ((orientation == "VERTICAL") and columnSpacing or rowSpacing))
  local widthStep = unitWidth + columnSpacing
  local heightStep = unitHeight + rowSpacing
  local widthFive = widthStep * 5
  local heightFive = heightStep * 5
  local layoutWidth = 0
  local layoutHeight = 0
  local newCols = 0
  local newRows = 0
  local x = 0
  local y = 0

  for i = 1, headerIndex do
    local lastIndex = i - 1
    local lastGroup = lastIndex % groupsPerRowCol

    if lastGroup == 0 then
      if point == "LEFT" or point == "RIGHT" then
        x = 0
        y = layoutHeight * yMultiplier
        layoutHeight = layoutHeight + heightStep + groupSpacing
        newRows = newRows + 1
      else
        x = layoutWidth * xMultiplier
        y = 0
        layoutWidth = layoutWidth + widthStep + groupSpacing
        newCols = newCols + 1
      end
    else
      if point == "LEFT" or point == "RIGHT" then
        if newRows == 1 then
          x = layoutWidth * xMultiplier
          y = 0
          layoutWidth = layoutWidth + widthFive + groupSpacing
          newCols = newCols + 1
        else
          x = ((widthFive * lastGroup) + lastGroup * groupSpacing) * xMultiplier
          y = ((heightStep + groupSpacing) * (newRows - 1)) * yMultiplier
        end
      else
        if newCols == 1 then
          x = 0
          y = layoutHeight * yMultiplier
          layoutHeight = layoutHeight + heightFive + groupSpacing
          newRows = newRows + 1
        else
          x = ((widthStep + groupSpacing) * (newCols - 1)) * xMultiplier
          y = ((heightFive * lastGroup) + lastGroup * groupSpacing) * yMultiplier
        end
      end
    end

    if layoutHeight == 0 then
      layoutHeight = layoutHeight + heightFive + groupSpacing
    end

    if layoutWidth == 0 then
      layoutWidth = layoutWidth + widthFive + groupSpacing
    end
  end

  return anchorPoint, x, y
end

local function BuildHeaderAttributes(db, groupIndex)
  EnsureRaidDesignDefaults(db)

  local point, xOffset, yOffset, columnSpacingAttr, columnAnchorPoint = GetHeaderChildLayout(db)
  local activeHeaders, activeGroups, numGroups = GetActiveHeaderCount(db)
  local raidWideSorting = db.lockMembersToGroup == false
  local groupsPerRowCol = GetGroupsPerRowCol(db, numGroups)
  local groupFilter = tostring(activeGroups[groupIndex] or groupIndex)
  local unitsPerColumn = 5
  local maxColumns = 1
  local precreateCount = 5

  if raidWideSorting then
    groupFilter = table_concat(activeGroups, ",")
    unitsPerColumn = groupsPerRowCol * 5
    maxColumns = #activeGroups
    precreateCount = math_min(numGroups * unitsPerColumn, MAX_RAID_MEMBERS)
  end

  return {
    showRaid = true,
    showParty = false,
    showSolo = false,
    showPlayer = db.showPlayer == true,
    groupFilter = groupFilter,
    groupBy = raidWideSorting and (db.groupBy or "GROUP") or "GROUP",
    groupingOrder = "1,2,3,4,5,6,7,8",
    sortMethod = (db.sortOrder == "NAME") and "NAME" or "INDEX",
    sortDir = db.sortDir or "ASC",
    point = point,
    xOffset = xOffset,
    yOffset = yOffset,
    maxColumns = maxColumns,
    unitsPerColumn = unitsPerColumn,
    columnSpacing = columnSpacingAttr,
    columnAnchorPoint = columnAnchorPoint,
    precreateCount = precreateCount,
    ["oUF-initialConfigFunction"] = "self:SetWidth(" .. Round(db.width or 80) .. "); self:SetHeight(" .. Round(db.height or 44) .. ");",
    activeHeaders = activeHeaders,
  }
end

local function SetHeaderAttribute(header, name, value)
  local ownedAttributes = header.__puiRaidOwnedAttributes
  if not ownedAttributes then
    ownedAttributes = {}
    header.__puiRaidOwnedAttributes = ownedAttributes
  end

  ownedAttributes[name] = true

  if header:GetAttribute(name) ~= value then
    header:SetAttribute(name, value)
  end
end

local function ApplyHeaderAttributes(header, db, groupIndex)
  header.__puiRaidHeaderReset = nil

  local attrs = BuildHeaderAttributes(db, groupIndex)

  SetHeaderAttribute(header, "oUF-initialConfigFunction", attrs["oUF-initialConfigFunction"])
  SetHeaderAttribute(header, "showRaid", attrs.showRaid)
  SetHeaderAttribute(header, "showParty", attrs.showParty)
  SetHeaderAttribute(header, "showSolo", attrs.showSolo)
  SetHeaderAttribute(header, "showPlayer", attrs.showPlayer)
  SetHeaderAttribute(header, "groupingOrder", attrs.groupingOrder)
  SetHeaderAttribute(header, "sortMethod", attrs.sortMethod)
  SetHeaderAttribute(header, "sortDir", attrs.sortDir)
  SetHeaderAttribute(header, "point", attrs.point)
  SetHeaderAttribute(header, "xOffset", attrs.xOffset)
  SetHeaderAttribute(header, "yOffset", attrs.yOffset)
  SetHeaderAttribute(header, "maxColumns", attrs.maxColumns)
  SetHeaderAttribute(header, "unitsPerColumn", attrs.unitsPerColumn)
  SetHeaderAttribute(header, "columnSpacing", attrs.columnSpacing)
  SetHeaderAttribute(header, "columnAnchorPoint", attrs.columnAnchorPoint)
  SetHeaderAttribute(header, "groupFilter", attrs.groupFilter)
  SetHeaderAttribute(header, "groupBy", attrs.groupBy)

  if not header.__puiRaidHeaderInitialized then
    SetHeaderAttribute(header, "startingIndex", -attrs.precreateCount + 1)
    header:Show()
    header.__puiRaidHeaderInitialized = true
  end

  SetHeaderAttribute(header, "startingIndex", 1)

  if header.__puiRaidVisibility ~= "raid" then
    header.__puiRaidVisibility = "raid"
    header:SetVisibility("raid")
  end
end

local function RF_ClearHeaderChildPoints(header)
  if not header or not header.GetAttribute then
    return
  end

  local index = 1
  local child = header:GetAttribute("child1")

  while child do
    child:ClearAllPoints()

    index = index + 1
    child = header:GetAttribute("child" .. index)
  end
end

local function RF_ResetHeader(header)
  if not header or header.__puiRaidHeaderReset == true then
    return
  end

  RF_ClearHeaderChildPoints(header)
  header:ClearAllPoints()

  local ownedAttributes = header.__puiRaidOwnedAttributes
  if ownedAttributes then
    for name in pairs(ownedAttributes) do
      header:SetAttribute(name, nil)
    end
  end

  header:SetAttribute("showRaid", true)
  header:SetAttribute("showParty", true)
  header:SetAttribute("showSolo", true)
  header:SetAttribute("showPlayer", true)
  header:SetAttribute("sortMethod", "NAME")
  header:Hide()
  header.__puiRaidHeaderReset = true
end

local function BuildRaidFrameConfig(db)
  EnsureRaidDesignDefaults(db)

  RaidFrameConfig.width = Round(db.width or 80)
  RaidFrameConfig.height = Round(db.height or 44)
  RaidFrameConfig.showPower = db.showPower == true and (tonumber(db.powerHeight) or 0) > 0
  RaidFrameConfig.powerHeight = RaidFrameConfig.showPower and Round(db.powerHeight or 0) or 0

  return RaidFrameConfig
end

function RaidFrames:GetTestFrameConfig()
  local db = RaidFrames.db.profile
  local cfg = BuildRaidFrameConfig(db)
  local _, _, layoutGroups = GetActiveHeaderCount(db)

  return cfg, db, cfg.showPower ~= true, math_max(1, layoutGroups)
end

function RaidFrames:LayoutTestFrames(frames, groupFrames, groupCount, membersPerGroup)
  if InCombatLockdown() then
    return false
  end

  local db = RaidFrames.db.profile
  local anchor = self:EnsureAnchor()
  local orientation = GetRaidGrowthParts(db)
  local childPoint, _, _, _, _, xMultiplier, yMultiplier = GetHeaderChildLayout(db)
  local width = Round(db.width or 80)
  local height = Round(db.height or 44)
  local rowSpacing = Round(db.rowSpacing or 3)
  local columnSpacing = Round(db.columnSpacing or 3)
  local lockedGroups = db.lockMembersToGroup ~= false

  groupCount = math_min(8, math_max(1, tonumber(groupCount) or 1))
  membersPerGroup = math_min(5, math_max(1, tonumber(membersPerGroup) or 1))

  self:ApplyAnchor()

  local visibleCount = groupCount * membersPerGroup
  RaidBoundsConfig.numGroups = groupCount
  local totalWidth, totalHeight = UFLayout.GetRaidConfiguredHeaderBounds(RaidBoundsConfig, {
    groupLabelHeight = RF_GROUP_LABEL_HEIGHT,
    groupSideLabelWidth = RF_GROUP_SIDE_LABEL_WIDTH,
    groupSideLabelOffset = RF_GROUP_SIDE_LABEL_OFFSET,
  })

  if lockedGroups then
    local layoutMembersPerGroup = 5
    local groupSpacing = Round(db.groupSpacing or ((orientation == "VERTICAL") and columnSpacing or rowSpacing))
    local groupsPerRowCol = GetGroupsPerRowCol(db, groupCount)
    local groupAnchorPoint = GetGroupAnchorPoint(db)
    local groupWidth = orientation == "VERTICAL"
      and width
      or ((width * layoutMembersPerGroup) + (columnSpacing * (layoutMembersPerGroup - 1)))
    local groupHeight = orientation == "VERTICAL"
      and ((height * layoutMembersPerGroup) + (rowSpacing * (layoutMembersPerGroup - 1)))
      or height

    for groupIndex, groupFrame in ipairs(groupFrames or {}) do
      groupFrame:SetParent(UIParent)
      groupFrame:ClearAllPoints()

      if groupIndex <= groupCount then
        local groupOffset = groupIndex - 1
        local groupColumn
        local groupRow
        local x
        local y

        if orientation == "VERTICAL" then
          groupRow = groupOffset % groupsPerRowCol
          groupColumn = math_floor(groupOffset / groupsPerRowCol)
          x = groupColumn * (width + columnSpacing + groupSpacing) * xMultiplier
          y = groupRow * (((height + rowSpacing) * layoutMembersPerGroup) + groupSpacing) * yMultiplier
        else
          groupColumn = groupOffset % groupsPerRowCol
          groupRow = math_floor(groupOffset / groupsPerRowCol)
          x = groupColumn * (((width + columnSpacing) * layoutMembersPerGroup) + groupSpacing) * xMultiplier
          y = groupRow * (height + rowSpacing + groupSpacing) * yMultiplier
        end

        Pixel.Size(groupFrame, groupWidth, groupHeight)
        Pixel.Point(groupFrame, groupAnchorPoint, anchor, groupAnchorPoint, x, y)
        groupFrame:Show()
      else
        groupFrame:Hide()
      end
    end

    for index, frame in ipairs(frames or {}) do
      frame:SetParent(UIParent)
      frame:ClearAllPoints()

      if index <= visibleCount then
        local groupIndex = math_floor((index - 1) / membersPerGroup) + 1
        local memberIndex = ((index - 1) % membersPerGroup) + 1
        local groupFrame = groupFrames and groupFrames[groupIndex]

        if groupFrame then
          if childPoint == "LEFT" or childPoint == "RIGHT" then
            Pixel.Point(
              frame,
              childPoint,
              groupFrame,
              childPoint,
              (memberIndex - 1) * (width + columnSpacing) * xMultiplier,
              0
            )
          else
            Pixel.Point(
              frame,
              childPoint,
              groupFrame,
              childPoint,
              0,
              (memberIndex - 1) * (height + rowSpacing) * yMultiplier
            )
          end
          frame:Show()
        else
          frame:Hide()
        end
      else
        frame:Hide()
      end
    end
  else
    local anchorPoint = FrameUtil.GetGroupedMoverAnchorPoint(db)

    for _, groupFrame in ipairs(groupFrames or {}) do
      groupFrame:Hide()
      groupFrame:ClearAllPoints()
    end

    local outerXMultiplier = xMultiplier
    local outerYMultiplier = yMultiplier

    if db.invertGroupingOrder == true then
      if orientation == "VERTICAL" then
        outerXMultiplier = -outerXMultiplier
      else
        outerYMultiplier = -outerYMultiplier
      end
    end

    for index, frame in ipairs(frames or {}) do
      frame:SetParent(UIParent)
      frame:ClearAllPoints()

      if index <= visibleCount then
        local groupIndex = math_floor((index - 1) / membersPerGroup) + 1
        local memberIndex = ((index - 1) % membersPerGroup) + 1
        local x
        local y

        if orientation == "VERTICAL" then
          x = (groupIndex - 1) * (width + columnSpacing) * outerXMultiplier
          y = (memberIndex - 1) * (height + rowSpacing) * yMultiplier
        else
          x = (memberIndex - 1) * (width + columnSpacing) * xMultiplier
          y = (groupIndex - 1) * (height + rowSpacing) * outerYMultiplier
        end

        Pixel.Point(frame, anchorPoint, anchor, anchorPoint, x, y)
        frame:Show()
      else
        frame:Hide()
      end
    end
  end

  Pixel.Size(anchor, totalWidth, totalHeight)
  if self.mover then
    Pixel.Size(self.mover, totalWidth, totalHeight)
    FrameUtil:RefreshMoverOverlay("RaidFrames")
  end

  return true
end



local function GetRaidProfile()
  return RaidFrames.db.profile
end

local function InvalidateRaidAuraDB()
  RaidFrames._auraDBCache = nil
end

local function BuildRaidAuraDB(unit)
  local aDB = RaidFrames._auraDBCache

  if not aDB then
    aDB = ns.UFAuraFilters.BuildGroupedAuraDB("raid", GetRaidProfile(), unit)
    RaidFrames._auraDBCache = aDB
  end

  return aDB
end


local function ConstructRaidStyledFrame(frame, unit, cfg)
  local db = RaidFrames.db.profile

  frame.__puiGroupKind = "raid"
  frame.__puiUseClassColor = db.useClassColor ~= false

  UF:ConstructUnitFrame(frame, unit, cfg, {
    db = db,
    groupKind = "raid",
    skipPosition = true,
    useClassColor = db.useClassColor ~= false,
    forceNoPower = cfg.showPower ~= true,
    roleConfigProvider = GetRaidProfile,
    roleDefaults = UFDefaults.RaidRoleIcon,
    auraDBBuilder = BuildRaidAuraDB,
  })

  frame:RegisterEvent("UNIT_AREA_CHANGED", UFAuraContainers.RefreshAvailability)
  frame:RegisterEvent("UNIT_CONNECTION", UFAuraContainers.RefreshAvailability)
  frame:RegisterEvent("UNIT_PHASE", UFAuraContainers.RefreshAvailability)
end

function RaidFrames:Construct_RaidFrames(frame)
  local db = RaidFrames.db.profile
  local unit = frame.__unit
  ConstructRaidStyledFrame(frame, unit, BuildRaidFrameConfig(db))
end

local function UpdateRaidStyledFrame(frame, unit, cfg)
  local db = RaidFrames.db.profile

  UF:RefreshUnitFrame(frame, unit, cfg, {
    db = db,
    groupKind = "raid",
    skipPosition = true,
    useClassColor = db.useClassColor ~= false,
    forceNoPower = cfg.showPower ~= true,
    auraDBBuilder = BuildRaidAuraDB,
    rangeOwner = RaidFrames,
  }, "all")
end

function RaidFrames:Update_RaidFrames(frame)
  local db = RaidFrames.db.profile
  local unit = frame.__unit
  if not unit then
    return
  end

  UpdateRaidStyledFrame(frame, unit, BuildRaidFrameConfig(db))
end

function RaidFrames:RegisterStyle()
  if self.styleRegistered then
    return
  end

  self.styleRegistered = true

  oUF:RegisterStyle("PleebUI_RaidFrames", function(frame)
    frame.__puiIsMainTankFrame = nil

    RaidFrames:Construct_RaidFrames(frame)
  end)

  oUF:RegisterStyle("PleebUI_RaidMainTankFrames", function(frame)
    frame.__puiIsMainTankFrame = true

    RaidFrames:Construct_RaidFrames(frame)
  end)
end

function RaidFrames:EnsureAnchor()
  if self.anchor then
    return self.anchor
  end

  self.anchor = CreateFrame("Frame", "PleebUI_RaidFramesAnchor", UIParent)
  Pixel.Size(self.anchor, 1, 1)
  return self.anchor
end

function RaidFrames:ApplyAnchor()
  local db = RaidFrames.db.profile
  local width, height

  EnsureRaidDesignDefaults(db)

  local _, _, layoutGroups = GetActiveHeaderCount(db)
  RaidBoundsConfig.numGroups = layoutGroups

  width, height = UFLayout.GetRaidConfiguredHeaderBounds(RaidBoundsConfig, {
    groupLabelHeight = RF_GROUP_LABEL_HEIGHT,
    groupSideLabelWidth = RF_GROUP_SIDE_LABEL_WIDTH,
    groupSideLabelOffset = RF_GROUP_SIDE_LABEL_OFFSET,
  })

  self.anchor:ClearAllPoints()
  Pixel.Point(self.anchor, db.point or "BOTTOMLEFT", _G[db.relativeTo or "UIParent"] or UIParent, db.relativePoint or db.point or "BOTTOMLEFT", db.x or 0, db.y or 0)
  Pixel.Size(self.anchor, width or 1, height or 1)

  FrameUtil.EnsureHeaderMover(self, "RaidFrames", "PleebUI_RaidFramesMover", self.anchor, db, {
    defaultPoint = db.point or "BOTTOMLEFT",
    defaultRelativePoint = db.relativePoint or db.point or "BOTTOMLEFT",
    anchorPoint = db.point or "BOTTOMLEFT",
    anchorRelativePoint = db.point or "BOTTOMLEFT",
    label = "Raid Frames",
    optionsString = "unitframes,raid",
    overlayBelowFrame = true,
    getDB = function()
      return RaidFrames.db.profile
    end,
    smartSnap = {
      family = "positionOnly",
      isRuntimeActive = function()
        return RaidFrames:IsEnabled() and RaidFrames.db.profile.enabled ~= false
      end,
    },
    quickSettings = function()
      return ns.UnitFrameTest:OpenQuickSettings("RaidFrames")
    end,
    resetPosition = function()
      local defaults = UFDefaults.GetRaidDefaults().profile
      local current = RaidFrames.db.profile
      current.point = defaults.point
      current.relativeTo = defaults.relativeTo
      current.relativePoint = defaults.relativePoint
      current.x = defaults.x
      current.y = defaults.y
      RaidFrames:ApplyAnchor()
    end,
    onDragStop = function()
      if ns.TestMode:IsActive() then
        ns.TestMode:Refresh("unitframes", "mover", "uf.raidSettings")
      end
    end,
  })
end

function RaidFrames:CreateHeaders()
  if self.headers then
    return
  end

  self:RegisterStyle()
  self:EnsureAnchor()

  local db = RaidFrames.db.profile
  local maxHeaders = UFLayout.GetRaidMaxAllowedGroups()
  local previousStyle = oUF:GetActiveStyle()

  EnsureRaidDesignDefaults(db)

  self.headers = {}

  oUF:SetActiveStyle("PleebUI_RaidFrames")

  for index = 1, maxHeaders do
    local header = oUF:SpawnHeader("PleebUI_RaidHeader" .. index, nil)
    header:SetParent(self.anchor)
    self.headers[index] = header
    ApplyHeaderAttributes(header, db, index)
  end

  oUF:SetActiveStyle(previousStyle)

  self:ConfigureHeaders()
end

function RaidFrames:ConfigureHeaders()
  if not self.headers then
    return
  end

  local db = RaidFrames.db.profile
  local count = GetActiveHeaderCount(db)

  EnsureRaidDesignDefaults(db)

  for index = 1, count do
    local header = self.headers[index]
    if header then
      ApplyHeaderAttributes(header, db, index)
    end
  end

  for index = count + 1, #self.headers do
    local header = self.headers[index]
    if header then
      RF_ResetHeader(header)
    end
  end
end

function RaidFrames:LayoutHeaders()
  local db = RaidFrames.db.profile
  local activeHeaders = GetActiveHeaderCount(db)
  local raidWideSorting = db.lockMembersToGroup == false

  EnsureRaidDesignDefaults(db)

  for index = 1, activeHeaders do
    local header = self.headers and self.headers[index]

    if header then
      local width, height = GetHeaderSize(db, raidWideSorting)
      local point, x, y = GetHeaderPlacement(db, index)

      header:SetParent(self.anchor)
      header:ClearAllPoints()
      RF_ClearHeaderChildPoints(header)

      Pixel.Size(header, width or 1, height or 1)
      Pixel.Point(header, point, self.anchor, point, x or 0, y or 0)
      header:Show()
    end
  end

  for index = activeHeaders + 1, #(self.headers or {}) do
    if self.headers[index] then
      RF_ResetHeader(self.headers[index])
    end
  end
end

local RAID_GROUP_LABEL_OPTIONS

local function RF_GetGroupLabelProfile()
  return RaidFrames.db.profile
end

local function RF_GetGroupLabelCount()
  return RAID_GROUP_LABEL_OPTIONS.activeCount or 0
end

local function RF_GetGroupLabelNumber(owner, headerIndex)
  local groups = RAID_GROUP_LABEL_OPTIONS.activeGroups
  return groups and groups[headerIndex] or headerIndex
end

local function RF_IterateGroupLabelChildren(header, callback)
  UF:IterateHeaderChildren(header, callback)
end

local function RF_GetGroupLabelUnit(frame)
  return frame and frame:GetAttribute("unit") or nil
end

RAID_GROUP_LABEL_OPTIONS = {
  getProfile = RF_GetGroupLabelProfile,
  getGroupSortOrientation = UFLayout.GetGroupSortOrientation,
  getLayoutDirectionParts = FrameUtil.GetGroupedLayoutDirectionParts,
  getEffectiveNumGroups = RF_GetGroupLabelCount,
  getGroupNumber = RF_GetGroupLabelNumber,
  iterateHeaderChildren = RF_IterateGroupLabelChildren,
  getCurrentUnit = RF_GetGroupLabelUnit,
}

function RaidFrames:UpdateGroupLabels()
  local db = RaidFrames.db.profile
  local _, activeGroups, activeCount = GetActiveHeaderCount(db)

  RAID_GROUP_LABEL_OPTIONS.activeGroups = activeGroups
  RAID_GROUP_LABEL_OPTIONS.activeCount = activeCount
  UFIndicators.UpdateRaidGroupLabels(self, RAID_GROUP_LABEL_OPTIONS)
  RAID_GROUP_LABEL_OPTIONS.activeGroups = nil
  RAID_GROUP_LABEL_OPTIONS.activeCount = nil
end

local function IterateActiveRaidHeaderChildren(owner, callback)
  local activeHeaders = GetActiveHeaderCount(RaidFrames.db.profile)

  for index = 1, activeHeaders do
    local header = owner.headers and owner.headers[index]
    if header then
      UF:IterateHeaderChildren(header, callback)
    end
  end
end

function RaidFrames:ConfigureChildren()
  IterateActiveRaidHeaderChildren(self, function(frame)
    self:Update_RaidFrames(frame)
  end)

  self:UpdateGroupLabels()
end

local function RefreshRaidFrameConfiguration(owner, frame, mode)
  local db = RaidFrames.db.profile
  local unit = frame.__unit
  if not unit then
    return
  end

  local cfg = BuildRaidFrameConfig(db)

  UF:RefreshUnitFrame(frame, unit, cfg, {
    db = db,
    groupKind = "raid",
    skipPosition = true,
    useClassColor = db.useClassColor ~= false,
    forceNoPower = cfg.showPower ~= true,
    auraDBBuilder = BuildRaidAuraDB,
    rangeOwner = owner,
  }, mode)
end

function RaidFrames:RefreshRosterPresentation()
  if InCombatLockdown() then
    self.pendingGroupLabelRefresh = true
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end

  self:UpdateGroupLabels()
end

function RaidFrames:RefreshVisibility()
  local db = RaidFrames.db.profile
  local showCustomFrames = db.enabled ~= false

  if not showCustomFrames then
    if self.anchor then
      self.anchor:Hide()
    end

    if self.headers then
      for _, header in pairs(self.headers) do
        UF:IterateHeaderChildren(header, function(frame)
          UF:DisableFrameRuntime(frame)
        end)
        RF_ResetHeader(header)
      end
    end

    ns.UFTankFrames.IterateFrames(self, function(frame)
      UF:DisableFrameRuntime(frame)
    end)

    return false
  end

  if not self.headers then
    return false
  end

  self:ConfigureHeaders()
  self:ApplyAnchor()
  self:LayoutHeaders()
  self.anchor:Show()
  return true
end

function RaidFrames:RefreshText()
  self._fontRev = (self._fontRev or 0) + 1

  IterateActiveRaidHeaderChildren(self, function(frame)
    UFText.RefreshTextForFrame(frame, self._fontRev)
  end)

  ns.UFTankFrames.IterateFrames(self, function(frame)
    UFText.RefreshTextForFrame(frame, self._fontRev)
  end)
end

local function IterateRaidFrames(owner, callback)
  IterateActiveRaidHeaderChildren(owner, callback)
  ns.UFTankFrames.IterateFrames(owner, callback)
end

local function RefreshRaidAuraFrame(frame, request)
  local fullRefresh = request.display or request.filters or request.highlight
  local highlightCovered = false

  if fullRefresh then
    UFAuraContainers.RefreshFrame(frame)
  elseif request.displayRequests then
    for _, displayRequest in pairs(request.displayRequests) do
      UFAuraContainers.RefreshFrame(frame, displayRequest)

      if displayRequest.displayID == ns.UFAuraFilters.BUILT_IN_DISPLAY_IDS.DEFAULT_DEBUFF then
        highlightCovered = true
      end
    end
  end

  if (request.highlightState or request.highlightPresentation)
    and not fullRefresh
    and not highlightCovered
  then
    UFAuraContainers.RefreshHighlight(frame)
  end
end

function RaidFrames:RefreshAuraDisplay(flags)
  if not flags
    or (
      flags.highlight ~= true
      and flags.highlightState ~= true
      and flags.highlightPresentation ~= true
    )
  then
    InvalidateRaidAuraDB()
  end

  local request = self._pendingAuraRefresh
  if not request then
    request = {}
    self._pendingAuraRefresh = request
  end

  if flags and flags.highlight then
    request.highlight = true
  end

  if flags and flags.highlightState then
    request.highlightState = true
  end

  if flags and flags.highlightPresentation then
    request.highlightPresentation = true
  end

  if flags and tonumber(flags.displayID) and flags.auraChange ~= "topology" then
    request.displayRequests = request.displayRequests or {}
    local displayID = tonumber(flags.displayID)
    local previousRequest = request.displayRequests[displayID]
    local auraChange = flags.auraChange or "display"

    if previousRequest
      and (previousRequest.auraChange == "sharedAppearance" or auraChange == "sharedAppearance")
    then
      auraChange = "sharedAppearance"
    elseif previousRequest and previousRequest.auraChange ~= auraChange then
      auraChange = "display"
    end

    request.displayRequests[displayID] = {
      displayID = displayID,
      auraChange = auraChange,
      auraType = flags.auraType or (previousRequest and previousRequest.auraType),
    }
  elseif flags and flags.rebuildDB then
    request.filters = true
  elseif not flags
    or (
      flags.highlight ~= true
      and flags.highlightState ~= true
      and flags.highlightPresentation ~= true
    )
  then
    request.display = true
  end

  if self._auraRefreshScheduled then
    return
  end

  self._auraRefreshScheduled = true
  C_Timer.After(0, function()
    self._auraRefreshScheduled = nil

    if not self:IsEnabled() then
      self._pendingAuraRefresh = nil
      return
    end

    local pending = self._pendingAuraRefresh
    self._pendingAuraRefresh = nil
    if not pending then
      return
    end

    IterateRaidFrames(self, function(frame)
      RefreshRaidAuraFrame(frame, pending)
    end)
  end)
end

function RaidFrames:RefreshTextures()
  UFStyle.ResolveMedia(UF)

  IterateRaidFrames(self, function(frame)
    UFStyle.UpdateFrameStyleElement(frame)
  end)
end

function RaidFrames:RefreshMouseoverSettings()
  UFMouseover.InvalidateRuntimeConfigCache()

  IterateRaidFrames(self, function(frame)
    UFMouseover.RefreshFrame(frame)
  end)
end

function RaidFrames:RefreshTargetHighlight()
  IterateRaidFrames(self, function(frame)
    UFFrameGlow.UpdateSharedTargetHighlight(frame)
  end)
end

function RaidFrames:RefreshRoleIcons(flags)
  IterateRaidFrames(self, function(frame)
    UFIndicators.RefreshSharedUnitIndicators(frame, flags)
  end)
end

function RaidFrames:RefreshThreat()
  IterateRaidFrames(self, function(frame)
    UFThreat.Refresh(frame)
  end)
end

function RaidFrames:RefreshColors(flags)
  local db = RaidFrames.db.profile

  IterateRaidFrames(self, function(frame)
    frame.__puiUseClassColor = db.useClassColor ~= false
    UF:RefreshFrameColors(frame, flags)
  end)
end

function RaidFrames:RefreshPowerLayout()
  local db = RaidFrames.db.profile

  local function RefreshFrame(frame)
    if not frame then
      return
    end

    local unit = frame:GetAttribute("unit")
    if not unit then
      return
    end

    frame.__puiUseClassColor = db.useClassColor ~= false

    UF:RefreshFramePowerLayout(frame, BuildRaidFrameConfig(db), {
      db = db,
      groupKind = "raid",
    })
  end

  IterateActiveRaidHeaderChildren(self, RefreshFrame)
  ns.UFTankFrames.IterateFrames(self, RefreshFrame)
end

function RaidFrames:RefreshLayout()
  if InCombatLockdown() then
    UF.QueueDeferredRefresh(self, "layout")
    return
  end

  if self.db.profile.enabled == false then
    return
  end

  if not self.headers then
    return
  end

  self:ConfigureHeaders()
  self:ApplyAnchor()
  self:LayoutHeaders()
  self:UpdateGroupLabels()
  ns.UFTankFrames.RefreshLayout(self)
end

function RaidFrames:RefreshResizeGeometry()
  if InCombatLockdown() then
    UF.QueueDeferredRefresh(self, "resize")
    return
  end

  local db = self.db.profile
  if db.enabled == false or not self.headers then
    return
  end

  local activeHeaders = GetActiveHeaderCount(db)
  local initialConfig = "self:SetWidth(" .. Round(db.width or 80) .. "); self:SetHeight(" .. Round(db.height or 44) .. ");"

  self:ApplyAnchor()

  for index = 1, activeHeaders do
    local header = self.headers[index]
    if header then
      SetHeaderAttribute(header, "oUF-initialConfigFunction", initialConfig)
    end
  end

  self:LayoutHeaders()
  self:UpdateGroupLabels()
  ns.UFTankFrames.RefreshResizeGeometry(self)
end

function RaidFrames:RefreshFrames(mode)
  mode = mode or "all"

  if InCombatLockdown() then
    UF.QueueDeferredRefresh(self, mode)
    return
  end

  if self.db.profile.enabled == false or not self.headers then
    self:Refresh()
    return
  end

  if mode == "resize" then
    self:RefreshResizeGeometry()
  end

  IterateRaidFrames(self, function(frame)
    RefreshRaidFrameConfiguration(self, frame, mode)
  end)
end

function RaidFrames:SafeRefresh(mode)
  if mode == "text" then
    self:RefreshText()
    return
  elseif mode == "range" then
    Range.RefreshRangeOwnerConfig(self, RaidFrames.db.profile.range)
    return
  elseif mode == "layout" then
    self:RefreshLayout()
    return
  elseif mode == "resize" or mode == "appearance" or mode == "data" then
    self:RefreshFrames(mode)
    return
  end

  self:Refresh()
end

function RaidFrames:Refresh()
  InvalidateRaidAuraDB()

  if InCombatLockdown() then
    UF.QueueDeferredRefresh(self, "all")
    return
  end

  if self:RefreshVisibility() then
    self:ConfigureChildren()
    ns.UFTankFrames.Refresh(self)
  else
    ns.UFTankFrames.Hide(self)
  end

  self._initialRefreshComplete = true
end

function RaidFrames:RefreshAuraAvailability()
  IterateRaidFrames(self, function(frame)
    UFAuraContainers.RefreshAvailability(frame)
  end)
end

function RaidFrames:GROUP_ROSTER_UPDATE()
  if self.db.profile.hideBlizzard == true then
    self:DisableBlizzardRaidFrames()
  end

  self:RefreshRosterPresentation()
end

function RaidFrames:PLAYER_ENTERING_WORLD()
  if self.db.profile.hideBlizzard == true then
    self:DisableBlizzardRaidFrames()
  end

  if self._initialRefreshComplete ~= true then
    self.__puiDeferredRefresh = nil
    self.pendingGroupLabelRefresh = nil
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:Refresh()
    return
  end

  self:RefreshAuraAvailability()
  self:RefreshRosterPresentation()
end

function RaidFrames:PLAYER_REGEN_ENABLED()
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")

  if self.pendingBlizzardRaidSuppression then
    self.pendingBlizzardRaidSuppression = nil
    self:DisableBlizzardRaidFrames()
  end

  if self.__puiTopologyCreationPending then
    self.__puiTopologyCreationPending = nil

    if not self:IsEnabled() then
      return
    end

    self:CreateHeaders()
    self:Refresh()
    self.__puiDeferredRefresh = nil
    self.pendingGroupLabelRefresh = nil
    return
  end

  local flushed = UF.FlushDeferredRefreshes(self, function(mode)
    self:SafeRefresh(mode)
  end)

  if flushed and not self:IsEnabled() then
    return
  end

  if self.pendingGroupLabelRefresh then
    self.pendingGroupLabelRefresh = nil
    self:RefreshRosterPresentation()
  end
end

function RaidFrames:ADDON_LOADED(_, addonName)
  if addonName ~= "Blizzard_CompactRaidFrames" or self.db.profile.hideBlizzard ~= true then
    return
  end

  self:DisableBlizzardRaidFrames()
end

function RaidFrames:OnInitialize()
  self.db = Addon.db:RegisterNamespace("RaidFrames", UFDefaults.GetRaidDefaults())
end

function RaidFrames:OnEnable()
  self:RegisterEvent("ADDON_LOADED")
  self:RegisterEvent("GROUP_ROSTER_UPDATE")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("PARTY_MEMBER_ENABLE", "RefreshAuraAvailability")
  self:RegisterEvent("PARTY_MEMBER_DISABLE", "RefreshAuraAvailability")

  if self.db.profile.hideBlizzard == true then
    self:DisableBlizzardRaidFrames()
  end

  oUF:Factory(function()
    if InCombatLockdown() then
      self.__puiTopologyCreationPending = true
      self:RegisterEvent("PLAYER_REGEN_ENABLED")
      return
    end

    self:CreateHeaders()
    self:Refresh()
  end)
end

function RaidFrames:SetMoversVisible(show)
  if show and not ns.TestMode:IsActive() then
    self:Refresh()
  end

  if self.mover then
    FrameUtil.SetMoverFrameVisible(
      self.mover,
      show == true and self:IsEnabled() and self.db.profile.enabled ~= false
    )
  end

  ns.UFTankFrames.SetMoverVisible(self, show == true)
end

function RaidFrames:OnDisable()
  self:UnregisterAllEvents()
  self.__puiDeferredRefresh = nil
  self.__puiTopologyCreationPending = nil
  self.pendingGroupLabelRefresh = nil
  self.pendingBlizzardRaidSuppression = nil
  self._pendingAuraRefresh = nil
  self._auraRefreshScheduled = nil

  IterateRaidFrames(self, function(frame)
    UF:DisableFrameRuntime(frame)
  end)

  if self.anchor then
    self.anchor:Hide()
  end

  if self.headers then
    for _, header in pairs(self.headers) do
      RF_ResetHeader(header)
    end
  end

  ns.UFTankFrames.Hide(self)
end



local P = select(1, ns.Pleebug:DropIn(RaidFrames, { name = "UnitFrames.Raid" }))


  RaidFrames.Construct_RaidFrames = P:Def("RaidFrames.Construct_RaidFrames", RaidFrames.Construct_RaidFrames)
  RaidFrames.DisableBlizzardRaidFrames = P:Def("RaidFrames.DisableBlizzardRaidFrames", RaidFrames.DisableBlizzardRaidFrames)
  RaidFrames.Update_RaidFrames = P:Def("RaidFrames.Update_RaidFrames", RaidFrames.Update_RaidFrames)
  RaidFrames.RegisterStyle = P:Def("RaidFrames.RegisterStyle", RaidFrames.RegisterStyle)
  RaidFrames.EnsureAnchor = P:Def("RaidFrames.EnsureAnchor", RaidFrames.EnsureAnchor)
  RaidFrames.ApplyAnchor = P:Def("RaidFrames.ApplyAnchor", RaidFrames.ApplyAnchor)
  RaidFrames.CreateHeaders = P:Def("RaidFrames.CreateHeaders", RaidFrames.CreateHeaders)
  RaidFrames.ConfigureHeaders = P:Def("RaidFrames.ConfigureHeaders", RaidFrames.ConfigureHeaders)
  RaidFrames.LayoutHeaders = P:Def("RaidFrames.LayoutHeaders", RaidFrames.LayoutHeaders)
  RaidFrames.GetTestFrameConfig = P:Def("RaidFrames.GetTestFrameConfig", RaidFrames.GetTestFrameConfig)
  RaidFrames.LayoutTestFrames = P:Def("RaidFrames.LayoutTestFrames", RaidFrames.LayoutTestFrames)
  RaidFrames.UpdateGroupLabels = P:Def("RaidFrames.UpdateGroupLabels", RaidFrames.UpdateGroupLabels)
  RaidFrames.ConfigureChildren = P:Def("RaidFrames.ConfigureChildren", RaidFrames.ConfigureChildren)
  RaidFrames.RefreshRosterPresentation = P:Def("RaidFrames.RefreshRosterPresentation", RaidFrames.RefreshRosterPresentation)
  RaidFrames.RefreshVisibility = P:Def("RaidFrames.RefreshVisibility", RaidFrames.RefreshVisibility)
  RaidFrames.RefreshText = P:Def("RaidFrames.RefreshText", RaidFrames.RefreshText)
  RaidFrames.RefreshAuraDisplay = P:Def("RaidFrames.RefreshAuraDisplay", RaidFrames.RefreshAuraDisplay)
  RaidFrames.RefreshTextures = P:Def("RaidFrames.RefreshTextures", RaidFrames.RefreshTextures)
  RaidFrames.RefreshMouseoverSettings = P:Def("RaidFrames.RefreshMouseoverSettings", RaidFrames.RefreshMouseoverSettings)
  RaidFrames.RefreshTargetHighlight = P:Def("RaidFrames.RefreshTargetHighlight", RaidFrames.RefreshTargetHighlight)
  RaidFrames.RefreshRoleIcons = P:Def("RaidFrames.RefreshRoleIcons", RaidFrames.RefreshRoleIcons)
  RaidFrames.RefreshThreat = P:Def("RaidFrames.RefreshThreat", RaidFrames.RefreshThreat)
  RaidFrames.RefreshColors = P:Def("RaidFrames.RefreshColors", RaidFrames.RefreshColors)
  RaidFrames.RefreshPowerLayout = P:Def("RaidFrames.RefreshPowerLayout", RaidFrames.RefreshPowerLayout)
  RaidFrames.RefreshLayout = P:Def("RaidFrames.RefreshLayout", RaidFrames.RefreshLayout)
  RaidFrames.RefreshResizeGeometry = P:Def("RaidFrames.RefreshResizeGeometry", RaidFrames.RefreshResizeGeometry)
  RaidFrames.RefreshFrames = P:Def("RaidFrames.RefreshFrames", RaidFrames.RefreshFrames)
  RaidFrames.SafeRefresh = P:Def("RaidFrames.SafeRefresh", RaidFrames.SafeRefresh)
  RaidFrames.Refresh = P:Def("RaidFrames.Refresh", RaidFrames.Refresh)
  RaidFrames.RefreshAuraAvailability = P:Def("RaidFrames.RefreshAuraAvailability", RaidFrames.RefreshAuraAvailability)
  RaidFrames.GROUP_ROSTER_UPDATE = P:Def("RaidFrames.GROUP_ROSTER_UPDATE", RaidFrames.GROUP_ROSTER_UPDATE)
  RaidFrames.PLAYER_ENTERING_WORLD = P:Def("RaidFrames.PLAYER_ENTERING_WORLD", RaidFrames.PLAYER_ENTERING_WORLD)
  RaidFrames.PLAYER_REGEN_ENABLED = P:Def("RaidFrames.PLAYER_REGEN_ENABLED", RaidFrames.PLAYER_REGEN_ENABLED)
  RaidFrames.ADDON_LOADED = P:Def("RaidFrames.ADDON_LOADED", RaidFrames.ADDON_LOADED)
  RaidFrames.OnInitialize = P:Def("RaidFrames.OnInitialize", RaidFrames.OnInitialize)
  RaidFrames.OnEnable = P:Def("RaidFrames.OnEnable", RaidFrames.OnEnable)
  RaidFrames.SetMoversVisible = P:Def("RaidFrames.SetMoversVisible", RaidFrames.SetMoversVisible)
  RaidFrames.OnDisable = P:Def("RaidFrames.OnDisable", RaidFrames.OnDisable)
  MoveBlizzardRaidFrameToHiddenParent = P:Def("MoveBlizzardRaidFrameToHiddenParent", MoveBlizzardRaidFrameToHiddenParent)
  DisableBlizzardRaidUnitFrame = P:Def("DisableBlizzardRaidUnitFrame", DisableBlizzardRaidUnitFrame)
  SuppressBlizzardRaidGroup = P:Def("SuppressBlizzardRaidGroup", SuppressBlizzardRaidGroup)
  ReadRaidProfile = P:Def("ReadRaidProfile", ReadRaidProfile)
  EnsureRaidDesignDefaults = P:Def("EnsureRaidDesignDefaults", EnsureRaidDesignDefaults)
  IsRaidGroupAllowed = P:Def("IsRaidGroupAllowed", IsRaidGroupAllowed)
  GetConfiguredRaidGroups = P:Def("GetConfiguredRaidGroups", GetConfiguredRaidGroups)
  GetShownRaidGroups = P:Def("GetShownRaidGroups", GetShownRaidGroups)
  GetActiveHeaderCount = P:Def("GetActiveHeaderCount", GetActiveHeaderCount)
  GetGroupsPerRowCol = P:Def("GetGroupsPerRowCol", GetGroupsPerRowCol)
  GetRaidGrowthParts = P:Def("GetRaidGrowthParts", GetRaidGrowthParts)
  GetHeaderChildLayout = P:Def("GetHeaderChildLayout", GetHeaderChildLayout)
  GetGroupAnchorPoint = P:Def("GetGroupAnchorPoint", GetGroupAnchorPoint)
  GetHeaderSize = P:Def("GetHeaderSize", GetHeaderSize)
  GetHeaderPlacement = P:Def("GetHeaderPlacement", GetHeaderPlacement)
  BuildHeaderAttributes = P:Def("BuildHeaderAttributes", BuildHeaderAttributes)
  SetHeaderAttribute = P:Def("SetHeaderAttribute", SetHeaderAttribute)
  ApplyHeaderAttributes = P:Def("ApplyHeaderAttributes", ApplyHeaderAttributes)
  RF_ClearHeaderChildPoints = P:Def("RF_ClearHeaderChildPoints", RF_ClearHeaderChildPoints)
  RF_ResetHeader = P:Def("RF_ResetHeader", RF_ResetHeader)
  BuildRaidFrameConfig = P:Def("BuildRaidFrameConfig", BuildRaidFrameConfig)
  GetRaidProfile = P:Def("GetRaidProfile", GetRaidProfile)
  InvalidateRaidAuraDB = P:Def("InvalidateRaidAuraDB", InvalidateRaidAuraDB)
  BuildRaidAuraDB = P:Def("BuildRaidAuraDB", BuildRaidAuraDB)
  ConstructRaidStyledFrame = P:Def("ConstructRaidStyledFrame", ConstructRaidStyledFrame)
  UpdateRaidStyledFrame = P:Def("UpdateRaidStyledFrame", UpdateRaidStyledFrame)
  RF_GetGroupLabelProfile = P:Def("RF_GetGroupLabelProfile", RF_GetGroupLabelProfile)
  RF_GetGroupLabelCount = P:Def("RF_GetGroupLabelCount", RF_GetGroupLabelCount)
  RF_GetGroupLabelNumber = P:Def("RF_GetGroupLabelNumber", RF_GetGroupLabelNumber)
  RF_IterateGroupLabelChildren = P:Def("RF_IterateGroupLabelChildren", RF_IterateGroupLabelChildren)
  RF_GetGroupLabelUnit = P:Def("RF_GetGroupLabelUnit", RF_GetGroupLabelUnit)
  IterateActiveRaidHeaderChildren = P:Def("IterateActiveRaidHeaderChildren", IterateActiveRaidHeaderChildren)
  RefreshRaidFrameConfiguration = P:Def("RefreshRaidFrameConfiguration", RefreshRaidFrameConfiguration)
  IterateRaidFrames = P:Def("IterateRaidFrames", IterateRaidFrames)
  RefreshRaidAuraFrame = P:Def("RefreshRaidAuraFrame", RefreshRaidAuraFrame)

_G.PleebUIAPI:RegisterPlugin("PleebUI_UnitFrames", {
  name = "Unit Frames",
}):RegisterEditModeParticipant("raid", {
  order = 120,
  onChanged = function(enable)
    RaidFrames:SetMoversVisible(enable)
  end,
})
