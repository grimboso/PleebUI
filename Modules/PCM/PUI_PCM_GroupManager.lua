local _, ns = ...

local GroupManager = {}
ns.PCMGroupManager = GroupManager

local Addon = ns.Addon
local DB = ns.PCM_DBExports
local FrameUtil = ns.FrameUtil
local PCMRuntime = ns.PCMRuntime
local AbilityLayout = ns.PCMAbilityLayout
local AbilityRuntime = ns.PCMAbilityRuntime
local AuraRuntime = ns.PCMAuraRuntime
local Pixel = ns.Pixel

local CreateFrame = CreateFrame
local C_Secrets = C_Secrets
local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown
local issecretvalue = issecretvalue
local UIParent = UIParent
local ipairs = ipairs
local pairs = pairs
local table_sort = table.sort
local tonumber = tonumber
local type = type

local DEFAULT_GROUP_BY_VIEWER = {
  EssentialCooldownViewer = "essential",
  UtilityCooldownViewer = "utility",
  BuffIconCooldownViewer = "buff-icons",
  BuffBarCooldownViewer = "buff-bars",
}

local VIEWER_KIND = {
  EssentialCooldownViewer = "ICON",
  UtilityCooldownViewer = "ICON",
  BuffIconCooldownViewer = "ICON",
  BuffBarCooldownViewer = "BAR",
}

local VIEWER_PRIORITY = {
  EssentialCooldownViewer = 1,
  UtilityCooldownViewer = 2,
  BuffIconCooldownViewer = 3,
  BuffBarCooldownViewer = 4,
}

local enabled = false
local editing = false
local ready = false
local pendingLayout = false
local profileDB
local groupFrames = {}
local activeGroups = {}
local activeRecordsByKey = {}
local editHandles = {}
local activeRestrictions = {}
local optionsTreeDirty = false
local optionsTreeTargetGroupID
local flushFrame = CreateFrame("Frame")
local dynamicBoundsEventFrame = CreateFrame("Frame")
local dynamicBoundsRows = {}
local dynamicBoundsRecords = {}
local centeredRowFrames = {}
local dynamicBoundsActive = false
local dynamicBoundsRefreshPasses = 0

local DYNAMIC_BOUNDS_SETTLE_PASSES = 2

local STRUCTURE_RESTRICTION_TYPES = {
  [Enum.AddOnRestrictionType.Combat] = true,
  [Enum.AddOnRestrictionType.Encounter] = true,
  [Enum.AddOnRestrictionType.ChallengeMode] = true,
  [Enum.AddOnRestrictionType.PvPMatch] = true,
  [Enum.AddOnRestrictionType.Map] = true,
}

flushFrame:Hide()

local function IsStructureLocked()
  return InCombatLockdown() and not PCMRuntime:IsInitializing()
end

local function GetDB()
  local current = DB.GetCooldownGroupsDB()
  if profileDB ~= current then
    profileDB = current
  end
  return profileDB
end

local function GetRecordKey(record)
  local entry = record and record.entry
  return entry and entry.catalogKey or nil
end

local function GetGroupFrame(group)
  if group.isDefault then
    if group.defaultViewerKey == "EssentialCooldownViewer"
      or group.defaultViewerKey == "UtilityCooldownViewer"
    then
      return AbilityRuntime:GetViewerFrame(group.defaultViewerKey)
    end
    return AuraRuntime:GetViewerFrame(group.defaultViewerKey)
  end

  local frame = groupFrames[group.id]
  if not frame then
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(40, 40)
    groupFrames[group.id] = frame
  end
  return frame
end

local function ApplyCustomGroupPosition(group, frame)
  local position = group.position
  if type(position) ~= "table" then
    position = {
      point = "CENTER",
      relativePoint = "CENTER",
      x = 0,
      y = 0,
    }
    group.position = position
  end

  frame:ClearAllPoints()
  frame:SetPoint(
    position.point or "CENTER",
    UIParent,
    position.relativePoint or position.point or "CENTER",
    Pixel.Round(tonumber(position.x) or 0),
    Pixel.Round(tonumber(position.y) or 0)
  )
end

local function SaveCustomGroupPosition(group, frame)
  local x, y = FrameUtil.GetMoverOffsets(frame)
  group.position = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = Pixel.Round(x or 0),
    y = Pixel.Round(y or 0),
  }
  ApplyCustomGroupPosition(group, frame)
end

local function RegisterCustomGroupMover(group, frame)
  local moverKey = "PCM_Group_" .. group.id
  FrameUtil:RegisterMover(moverKey, frame, {
    label = group.name,
    optionsString = "CooldownManager," .. group.id,
    useOverlayDrag = true,
    smartSnap = {
      family = "combatBars",
      syncAxis = "NONE",
      isRuntimeActive = function()
        return enabled
      end,
    },
    savePosition = function()
      SaveCustomGroupPosition(group, frame)
    end,
    onDragStop = function()
      SaveCustomGroupPosition(group, frame)
    end,
  })
end

local function ResolveIconLayout(group)
  if group.isDefault then
    if group.defaultViewerKey == "EssentialCooldownViewer"
      or group.defaultViewerKey == "UtilityCooldownViewer"
    then
      return ns.Modules.CooldownManager:_ResolveOwnedViewerStyle(group.defaultViewerKey)
    end

    local style = DB.GetProfileBuffsDB().style
    return {
      iconSize = tonumber(style.viewerSizes.BuffIconCooldownViewer or style.iconSize) or 36,
      spacing = tonumber(style.viewerSpacing.BuffIconCooldownViewer or style.iconSpacing) or 1,
      columns = tonumber(style.viewerColumns.BuffIconCooldownViewer) or 0,
      growth = style.viewerGrowth.BuffIconCooldownViewer or "CENTER",
      rowGrowth = "DOWN",
    }
  end

  group.layout = type(group.layout) == "table" and group.layout or {}
  local layout = group.layout
  if layout.iconSize == nil then layout.iconSize = 36 end
  if layout.spacing == nil then layout.spacing = 2 end
  if layout.columns == nil then layout.columns = 0 end
  if layout.growth == nil then layout.growth = "CENTER" end
  if layout.rowGrowth == nil then layout.rowGrowth = "DOWN" end
  return layout
end

local function ResolveBarLayout(group)
  if group.isDefault then
    return DB.GetStyleDB().buffBar
  end

  group.layout = type(group.layout) == "table" and group.layout or {}
  local layout = group.layout
  if layout.width == nil then layout.width = 250 end
  if layout.height == nil then layout.height = 20 end
  if layout.rowSpacing == nil then layout.rowSpacing = 1 end
  if layout.orientation == nil then layout.orientation = "HORIZONTAL" end
  if layout.growthDirection == nil then layout.growthDirection = "DOWN" end
  return layout
end

local function PlanIconGrid(records, style)
  local count = #records
  local size = math.max(8, math.min(96, Pixel.Round(tonumber(style.iconSize) or 36)))
  local spacing = math.max(-20, math.min(40, Pixel.Round(tonumber(style.spacing) or 2)))
  local columns = math.max(0, math.min(40, math.floor(tonumber(style.columns) or 0)))
  local rowLimit = columns > 0 and columns or math.max(count, 1)
  local rows = count > 0 and math.ceil(count / rowLimit) or 0
  local widest = math.min(count, rowLimit)
  local width = math.max(1, widest * size + math.max(0, widest - 1) * spacing)
  local height = math.max(1, rows * size + math.max(0, rows - 1) * spacing)
  local growth = style.growth
  local growUp = style.rowGrowth == "UP"
  local plan = { width = width, height = height, items = {} }

  local index = 1
  for row = 1, rows do
    local rowCount = math.min(rowLimit, count - index + 1)
    local rowWidth = rowCount * size + math.max(0, rowCount - 1) * spacing
    local startX
    if growth == "LEFT" then
      startX = (width / 2) - (size / 2)
    elseif growth == "RIGHT" then
      startX = -(width / 2) + (size / 2)
    else
      startX = -(rowWidth / 2) + (size / 2)
    end
    local direction = growth == "LEFT" and -1 or 1
    local rowY = (height / 2) - (size / 2) - ((row - 1) * (size + spacing))
    if growUp then
      rowY = -(height / 2) + (size / 2) + ((row - 1) * (size + spacing))
    end

    for column = 1, rowCount do
      plan.items[index] = {
        x = Pixel.Round(startX + ((column - 1) * (size + spacing) * direction)),
        y = Pixel.Round(rowY),
        width = size,
        height = size,
      }
      index = index + 1
    end
  end
  return plan
end

local function PlanIcons(group, records)
  local style = ResolveIconLayout(group)
  if group.isDefault
    and (group.defaultViewerKey == "EssentialCooldownViewer"
      or group.defaultViewerKey == "UtilityCooldownViewer")
  then
    local entries = {}
    for index = 1, #records do
      entries[index] = records[index].entry
    end
    local abilityPlan = AbilityLayout:Plan(group.defaultViewerKey, entries, style)
    local plan = { width = abilityPlan.width, height = abilityPlan.height, items = {} }
    for index = 1, #abilityPlan.items do
      local item = abilityPlan.items[index]
      plan.items[index] = {
        x = item.x,
        y = item.y,
        width = item.size,
        height = item.size,
      }
    end
    return plan
  end
  return PlanIconGrid(records, style)
end

local function PlanBars(group, records)
  local style = ResolveBarLayout(group)
  local vertical = style.orientation == "VERTICAL"
  local length = math.max(120, math.min(500, Pixel.Round(tonumber(style.width) or 250)))
  local thickness = math.max(8, math.min(40, Pixel.Round(tonumber(style.height) or 20)))
  local spacing = math.max(-20, math.min(40, Pixel.Round(tonumber(style.rowSpacing) or 1)))
  local itemWidth = vertical and thickness or length
  local itemHeight = vertical and length or thickness
  local count = #records
  local plan = { width = 1, height = 1, items = {} }

  if count == 0 then
    return plan
  end

  if vertical then
    plan.width = count * itemWidth + math.max(0, count - 1) * spacing
    plan.height = itemHeight
  else
    plan.width = itemWidth
    plan.height = count * itemHeight + math.max(0, count - 1) * spacing
  end

  for index = 1, count do
    local x = 0
    local y = 0
    local point
    if vertical then
      local direction = style.growthDirection == "LEFT" and -1 or 1
      x = (index - 1) * (itemWidth + spacing) * direction
      point = style.growthDirection == "LEFT" and "TOPRIGHT" or "TOPLEFT"
    else
      local direction = style.growthDirection == "UP" and 1 or -1
      y = (index - 1) * (itemHeight + spacing) * direction
      point = style.growthDirection == "UP" and "BOTTOMLEFT" or "TOPLEFT"
    end
    plan.items[index] = {
      point = point,
      x = Pixel.Round(x),
      y = Pixel.Round(y),
      width = itemWidth,
      height = itemHeight,
    }
  end
  return plan
end

local function PrepareRecordLayout(record, width, height, horizontalPadding)
  if record.viewerKey == "BuffIconCooldownViewer"
    or record.viewerKey == "BuffBarCooldownViewer"
  then
    return AuraRuntime:PrepareRecordLayout(
      record,
      width,
      height,
      horizontalPadding
    )
  end

  local frame = record.parts.frame
  frame:SetSize(width, height)
  if horizontalPadding ~= nil then
    local layoutFrame = record.pcmGroupLayoutFrame
    if not layoutFrame then
      layoutFrame = CreateFrame("Frame", nil, frame:GetParent())
      record.pcmGroupLayoutFrame = layoutFrame
    end
    layoutFrame:SetSize(math.max(0.001, width + horizontalPadding), height)
    layoutFrame:Show()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", layoutFrame, "CENTER")
    return layoutFrame
  end
  if record.pcmGroupLayoutFrame then
    record.pcmGroupLayoutFrame:Hide()
  end
  return frame
end

local function GroupUsesCollapsedAuraLayout(group, records)
  if group.data.kind ~= "ICON" then
    return false
  end
  for index = 1, #records do
    if AuraRuntime:UsesCollapsedLayout(records[index]) then
      return true
    end
  end
  return false
end

local function GetCenteredRowFrame(group, rowIndex)
  local rows = centeredRowFrames[group.id]
  if not rows then
    rows = {}
    centeredRowFrames[group.id] = rows
  end

  local row = rows[rowIndex]
  if not row then
    row = CreateFrame("Frame", nil, group.frame)
    row:SetSize(0.001, 0.001)
    row:SetIgnoringChildrenForBounds(true)
    local startAssistant = CreateFrame(
      "Frame",
      nil,
      row,
      "DisableUntrustedLayoutScriptsTemplate"
    )
    startAssistant:SetSize(0.001, 0.001)
    local endAssistant = CreateFrame(
      "Frame",
      nil,
      row,
      "DisableUntrustedLayoutScriptsTemplate"
    )
    endAssistant:SetSize(0.001, 0.001)
    row.__puiPCMStartAssistant = startAssistant
    row.__puiPCMEndAssistant = endAssistant
    rows[rowIndex] = row
  end
  return row
end

local function ApplyCollapsedAuraIconRows(group, records)
  local style = ResolveIconLayout(group.data)
  local size = math.max(8, math.min(96, Pixel.Round(tonumber(style.iconSize) or 36)))
  local spacing = math.max(-20, math.min(40, Pixel.Round(tonumber(style.spacing) or 2)))
  local columns = math.max(0, math.min(40, math.floor(tonumber(style.columns) or 0)))
  local count = #records
  local rowLimit = columns > 0 and columns or math.max(count, 1)
  local rowCount = count > 0 and math.ceil(count / rowLimit) or 0
  local growUp = style.rowGrowth == "UP"
  local growth = style.growth
  local fullWidth = math.max(1, math.min(count, rowLimit) * size + math.max(0, math.min(count, rowLimit) - 1) * spacing)
  local fullHeight = math.max(1, rowCount * size + math.max(0, rowCount - 1) * spacing)
  group.frame:SetSize(fullWidth, fullHeight)

  local rows = centeredRowFrames[group.id]
  if rows then
    for index = rowCount + 1, #rows do
      rows[index]:Hide()
    end
  end

  local recordIndex = 1
  for rowIndex = 1, rowCount do
    local row = GetCenteredRowFrame(group, rowIndex)
    row:ClearAllPoints()
    local y = (fullHeight / 2) - (size / 2) - ((rowIndex - 1) * (size + spacing))
    if growUp then
      y = -(fullHeight / 2) + (size / 2) + ((rowIndex - 1) * (size + spacing))
    end
    if growth == "LEFT" then
      row:SetPoint("RIGHT", group.frame, "RIGHT", 0, Pixel.Round(y))
    elseif growth == "RIGHT" then
      row:SetPoint("LEFT", group.frame, "LEFT", 0, Pixel.Round(y))
    else
      row:SetPoint("CENTER", group.frame, "CENTER", 0, Pixel.Round(y))
    end
    row:Show()
    dynamicBoundsRows[#dynamicBoundsRows + 1] = row

    local first
    local previous
    local rowItems = math.min(rowLimit, count - recordIndex + 1)
    for _ = 1, rowItems do
      local record = records[recordIndex]
      local layoutFrame = PrepareRecordLayout(record, size, size, spacing)
      layoutFrame:ClearAllPoints()
      if growth == "LEFT" then
        if previous then
          layoutFrame:SetPoint("RIGHT", previous, "LEFT", 0, 0)
        else
          layoutFrame:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        end
      else
        if previous then
          layoutFrame:SetPoint("LEFT", previous, "RIGHT", 0, 0)
        else
          layoutFrame:SetPoint("LEFT", row, "LEFT", 0, 0)
        end
      end
      AuraRuntime:FinalizeRecordLayout(record)
      first = first or layoutFrame
      previous = layoutFrame
      if AuraRuntime:UsesCollapsedLayout(record) then
        dynamicBoundsRecords[#dynamicBoundsRecords + 1] = record
      end
      recordIndex = recordIndex + 1
    end

    row.__puiPCMStartAssistant:ClearAllPoints()
    row.__puiPCMEndAssistant:ClearAllPoints()
    if growth == "LEFT" then
      row.__puiPCMStartAssistant:SetPoint("TOPRIGHT", first, "TOPRIGHT")
      row.__puiPCMEndAssistant:SetPoint("BOTTOMLEFT", previous, "BOTTOMLEFT")
    else
      row.__puiPCMStartAssistant:SetPoint("TOPLEFT", first, "TOPLEFT")
      row.__puiPCMEndAssistant:SetPoint("BOTTOMRIGHT", previous, "BOTTOMRIGHT")
    end
  end

  if not group.data.isDefault then
    group.frame:SetShown(enabled)
    RegisterCustomGroupMover(group.data, group.frame)
    FrameUtil.RefreshSmartSnapRuntimeLayout("PCM_Group_" .. group.id)
  else
    FrameUtil.RefreshSmartSnapRuntimeLayout(group.data.defaultViewerKey)
  end
end

local function RefreshDynamicBounds()
  for index = 1, #dynamicBoundsRecords do
    AuraRuntime:RefreshRecordLayoutBounds(dynamicBoundsRecords[index])
  end
  for index = 1, #dynamicBoundsRows do
    local row = dynamicBoundsRows[index]
    row:SetIgnoringChildrenForBounds(false)
    row:SetSize(0.001, 0.001)
    row:ResizeToBoundsRect()
    row:SetIgnoringChildrenForBounds(true)
  end
end

local function IsDynamicBoundsRestrictionActive()
  return next(activeRestrictions) ~= nil
    or InCombatLockdown()
    or C_Secrets.ShouldAurasBeSecret() == true
end

local function QueueDynamicBoundsRefresh()
  if not enabled or not dynamicBoundsActive then
    return
  end
  dynamicBoundsRefreshPasses = DYNAMIC_BOUNDS_SETTLE_PASSES
  flushFrame:Show()
end

local function UpdateDynamicBoundsDriver()
  dynamicBoundsEventFrame:UnregisterAllEvents()
  dynamicBoundsEventFrame:SetScript("OnUpdate", nil)

  if not dynamicBoundsActive then
    return
  end

  if IsDynamicBoundsRestrictionActive() then
    dynamicBoundsEventFrame:SetScript("OnUpdate", RefreshDynamicBounds)
    return
  end

  dynamicBoundsEventFrame:RegisterUnitEvent("UNIT_AURA", "player", "target")
  dynamicBoundsEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
end

local function SetDynamicBoundsActive(active)
  active = active == true
  if dynamicBoundsActive ~= active then
    dynamicBoundsActive = active
    UpdateDynamicBoundsDriver()
    if not active then
      dynamicBoundsRefreshPasses = 0
    end
  end
  if active and not IsDynamicBoundsRestrictionActive() then
    QueueDynamicBoundsRefresh()
  end
  flushFrame:SetShown(enabled and (pendingLayout or dynamicBoundsRefreshPasses > 0))
end

local function ApplyPlan(group, records, plan)
  local frame = group.frame
  local minimum = not group.data.isDefault and 40 or 1
  frame:SetSize(math.max(minimum, plan.width), math.max(minimum, plan.height))
  if not group.data.isDefault then
    frame:SetShown(enabled)
  end

  for index = 1, #records do
    local record = records[index]
    local item = plan.items[index]
    local recordFrame = PrepareRecordLayout(record, item.width, item.height)
    recordFrame:ClearAllPoints()
    local point = item.point or "CENTER"
    recordFrame:SetPoint(point, frame, point, item.x, item.y)
    if record.viewerKey == "BuffIconCooldownViewer"
      or record.viewerKey == "BuffBarCooldownViewer"
    then
      AuraRuntime:FinalizeRecordLayout(record)
    end
  end

  if not group.data.isDefault then
    RegisterCustomGroupMover(group.data, frame)
    FrameUtil.RefreshSmartSnapRuntimeLayout("PCM_Group_" .. group.id)
  elseif group.data.defaultViewerKey == "EssentialCooldownViewer"
    or group.data.defaultViewerKey == "UtilityCooldownViewer"
  then
    local owner = ns.Modules.CooldownManager
    local anchor = owner:GetViewerAnchorFrame(group.data.defaultViewerKey)
    if anchor then
      anchor:SetSize(frame:GetSize())
    end
    FrameUtil.RefreshSmartSnapRuntimeLayout("PCM_" .. group.data.defaultViewerKey)
  else
    FrameUtil.RefreshSmartSnapRuntimeLayout(group.data.defaultViewerKey)
  end
end

local function RemoveMemberFromOrders(db, recordKey)
  for _, group in pairs(db.byID) do
    if type(group) == "table" and type(group.members) == "table" then
      for index = #group.members, 1, -1 do
        if group.members[index] == recordKey then
          table.remove(group.members, index)
        end
      end
    end
  end
end

local function GetAssignedGroup(db, record)
  local recordKey = GetRecordKey(record)
  local assigned = recordKey and db.assignments[recordKey] or nil
  local group = assigned and db.byID[assigned] or nil
  if type(group) == "table"
    and group.isDefault ~= true
    and group.kind == VIEWER_KIND[record.viewerKey]
  then
    return group
  end
  if recordKey and assigned then
    db.assignments[recordKey] = nil
  end
  return db.byID[DEFAULT_GROUP_BY_VIEWER[record.viewerKey]]
end

local function AddRuntimeRecords(target)
  for _, viewerKey in ipairs({
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "BuffBarCooldownViewer",
  }) do
    local runtime = (viewerKey == "BuffIconCooldownViewer"
      or viewerKey == "BuffBarCooldownViewer") and AuraRuntime or AbilityRuntime
    local records = runtime:GetOrderedRecords(viewerKey) or {}
    for index = 1, #records do
      target[#target + 1] = records[index]
    end
  end
end

local function SortGroupRecords(group)
  local order = {}
  if group.data.isDefault ~= true then
    for index = 1, #(group.data.members or {}) do
      order[group.data.members[index]] = index
    end
  end

  table_sort(group.records, function(first, second)
    local firstKey = GetRecordKey(first)
    local secondKey = GetRecordKey(second)
    local firstOrder = order[firstKey]
    local secondOrder = order[secondKey]
    if firstOrder and secondOrder then
      return firstOrder < secondOrder
    elseif firstOrder then
      return true
    elseif secondOrder then
      return false
    end

    local firstViewer = VIEWER_PRIORITY[first.viewerKey] or 99
    local secondViewer = VIEWER_PRIORITY[second.viewerKey] or 99
    if firstViewer ~= secondViewer then
      return firstViewer < secondViewer
    end
    return (first.entry.viewerOrder or 0) < (second.entry.viewerOrder or 0)
  end)
end

local function RebuildActiveGroups()
  local db = GetDB()
  local retainedCustomGroups = {}
  activeGroups = {}
  activeRecordsByKey = {}

  for index = 1, #db.order do
    local groupID = db.order[index]
    local data = db.byID[groupID]
    if type(data) == "table" then
      local frame = GetGroupFrame(data)
      if not data.isDefault then
        retainedCustomGroups[groupID] = true
        ApplyCustomGroupPosition(data, frame)
      end
      activeGroups[groupID] = {
        id = groupID,
        data = data,
        frame = frame,
        records = {},
      }
    end
  end

  for groupID, frame in pairs(groupFrames) do
    if not retainedCustomGroups[groupID] then
      FrameUtil:UnregisterMover("PCM_Group_" .. groupID)
      frame:Hide()
    end
  end

  local records = {}
  AddRuntimeRecords(records)
  for index = 1, #records do
    local record = records[index]
    local recordKey = GetRecordKey(record)
    local groupData = GetAssignedGroup(db, record)
    local group = groupData and activeGroups[groupData.id] or nil
    if recordKey and group then
      group.records[#group.records + 1] = record
      activeRecordsByKey[recordKey] = record
      record.__puiPCMGroupID = group.id
    end
  end

  for _, group in pairs(activeGroups) do
    SortGroupRecords(group)
  end
end

local function HideEditHandles()
  for _, handle in pairs(editHandles) do
    handle:Hide()
    handle:EnableMouse(false)
  end
end

local function HideGroupLayoutFrames()
  for _, record in pairs(activeRecordsByKey) do
    if record.pcmGroupLayoutFrame then
      record.pcmGroupLayoutFrame:Hide()
    end
  end
end

local function IsPointInsideFrame(x, y, frame)
  if x == nil or y == nil then
    return false
  end
  local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
  if issecretvalue(left) or issecretvalue(right) or issecretvalue(top) or issecretvalue(bottom) then
    return false
  end
  return left and right and top and bottom
    and x >= left and x <= right and y >= bottom and y <= top
end

local function FindDropGroup(record, x, y)
  local kind = VIEWER_KIND[record.viewerKey]
  local best
  local bestArea
  for _, group in pairs(activeGroups) do
    local defaultMatches = group.data.isDefault ~= true
      or group.data.defaultViewerKey == record.viewerKey
    if group.data.kind == kind
      and defaultMatches
      and IsPointInsideFrame(x, y, group.frame)
    then
      local area = group.frame:GetWidth() * group.frame:GetHeight()
      if not bestArea or area < bestArea then
        best = group
        bestArea = area
      end
    end
  end
  return best
end

local function GetInsertIndex(group, x, y, movingKey)
  local remaining = {}
  for index = 1, #group.records do
    local record = group.records[index]
    if GetRecordKey(record) ~= movingKey then
      remaining[#remaining + 1] = record
    end
  end

  for index = 1, #remaining do
    local centerX, centerY = remaining[index].parts.frame:GetCenter()
    if not issecretvalue(centerX) and not issecretvalue(centerY) and centerX and centerY then
      if group.data.kind == "BAR" then
        if y > centerY then
          return index
        end
      elseif y > centerY + 2 or math.abs(y - centerY) <= 2 and x < centerX then
        return index
      end
    end
  end
  return #remaining + 1
end

local STATIC_OPTIONS_NODES = {
  overview = true,
  customTrackers = true,
  consumables = true,
  developer = true,
}

local function GroupContainsRecord(groupID, recordKey)
  local group = activeGroups[groupID]
  if not group then
    return false
  end

  for index = 1, #group.records do
    if GetRecordKey(group.records[index]) == recordKey then
      return true
    end
  end
  return false
end

local function GetOptionsRefreshPath(groupID)
  local db = GetDB()
  local activePath = ns._PUIActiveOptionsPath
  local activeGroupID = type(activePath) == "table"
    and activePath[1] == "CooldownManager"
    and activePath[2]
    or nil

  if groupID and db.byID[groupID] then
    if activeGroupID == groupID then
      local childKey = activePath[3]
      if type(childKey) == "string" and GroupContainsRecord(groupID, childKey) then
        return activePath
      end
    end
    return { "CooldownManager", groupID }
  end

  if activeGroupID and db.byID[activeGroupID] then
    local childKey = activePath[3]
    if type(childKey) == "string" and GroupContainsRecord(activeGroupID, childKey) then
      return activePath
    end
    return { "CooldownManager", activeGroupID }
  end

  if activeGroupID and STATIC_OPTIONS_NODES[activeGroupID] then
    return activePath
  end

  return { "CooldownManager", "overview" }
end

local function MarkOptionsTreeDirty(groupID)
  optionsTreeDirty = true
  if groupID then
    optionsTreeTargetGroupID = groupID
  end
end

local function NotifyOptionsChanged(groupID)
  if ns.Flags.__puiPCM_OptionsOpen then
    Addon:NotifyOptionsTreeChanged(
      "CooldownManager",
      GetOptionsRefreshPath(groupID)
    )
  else
    Addon:InvalidateOptionsRender("CooldownManager")
  end
end

local function FlushOptionsTreeChange()
  if not optionsTreeDirty then
    return
  end

  local groupID = optionsTreeTargetGroupID
  optionsTreeDirty = false
  optionsTreeTargetGroupID = nil
  NotifyOptionsChanged(groupID)
end

local function CreateCustomGroup(kind, x, y, name)
  local db = GetDB()
  local id
  repeat
    id = "custom-" .. tostring(db.nextID)
    db.nextID = db.nextID + 1
  until db.byID[id] == nil

  local group = {
    id = id,
    name = name or (kind == "BAR" and "New bar group" or "New icon group"),
    kind = kind,
    members = {},
    position = {
      point = "CENTER",
      relativePoint = "CENTER",
      x = Pixel.Round(x or 0),
      y = Pixel.Round(y or 0),
    },
    layout = kind == "BAR" and {
      width = 250,
      height = 20,
      rowSpacing = 1,
      orientation = "HORIZONTAL",
      growthDirection = "DOWN",
    } or {
      iconSize = 36,
      spacing = 2,
      columns = 0,
      growth = "CENTER",
      rowGrowth = "DOWN",
    },
  }
  db.byID[id] = group
  db.order[#db.order + 1] = id
  return group
end

local function MoveRecord(recordKey, groupID, insertIndex)
  local db = GetDB()
  local record = activeRecordsByKey[recordKey]
  local target = db.byID[groupID]
  if not record or not target or target.kind ~= VIEWER_KIND[record.viewerKey] then
    return false
  end

  if target.isDefault then
    if target.defaultViewerKey ~= record.viewerKey then
      return false
    end
    RemoveMemberFromOrders(db, recordKey)
    db.assignments[recordKey] = nil
    GroupManager:RequestLayout(true, groupID)
    return true
  end

  local orderedKeys = {}
  local activeTarget = activeGroups[groupID]
  if activeTarget then
    for index = 1, #activeTarget.records do
      local key = GetRecordKey(activeTarget.records[index])
      if key and key ~= recordKey then
        orderedKeys[#orderedKeys + 1] = key
      end
    end
  else
    for index = 1, #(target.members or {}) do
      local key = target.members[index]
      if key ~= recordKey then
        orderedKeys[#orderedKeys + 1] = key
      end
    end
  end

  RemoveMemberFromOrders(db, recordKey)
  insertIndex = math.max(1, math.min(#orderedKeys + 1, tonumber(insertIndex) or (#orderedKeys + 1)))
  table.insert(orderedKeys, insertIndex, recordKey)
  target.members = orderedKeys
  db.assignments[recordKey] = groupID
  GroupManager:RequestLayout(true, groupID)
  return true
end

local function FinishHandleDrag(handle)
  handle:StopMovingOrSizing()
  local recordKey = handle.recordKey
  local record = activeRecordsByKey[recordKey]
  if not record or IsStructureLocked() or not editing then
    GroupManager:RefreshEditHandles()
    return
  end

  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  local x, y = cursorX / scale, cursorY / scale
  local target = FindDropGroup(record, x, y)
  if not target then
    local uiX, uiY = UIParent:GetCenter()
    local group = CreateCustomGroup(
      VIEWER_KIND[record.viewerKey],
      x - uiX,
      y - uiY,
      record.entry.name
    )
    MoveRecord(recordKey, group.id, 1)
    return
  end

  MoveRecord(recordKey, target.id, GetInsertIndex(target, x, y, recordKey))
end

local function EnsureEditHandle(record)
  local recordKey = GetRecordKey(record)
  local handle = editHandles[recordKey]
  if not handle then
    handle = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    handle:SetFrameStrata("HIGH")
    handle:SetMovable(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetClampedToScreen(true)
    handle:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    handle:SetBackdropColor(0.15, 0.65, 1, 0.22)
    handle:SetBackdropBorderColor(0.15, 0.8, 1, 0.9)
    handle:SetScript("OnDragStart", function(self)
      if IsStructureLocked() or not editing then
        return
      end
      local centerX, centerY = self:GetCenter()
      if issecretvalue(centerX) or issecretvalue(centerY) or not centerX or not centerY then
        return
      end
      self:ClearAllPoints()
      self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
      self:StartMoving()
    end)
    handle:SetScript("OnDragStop", FinishHandleDrag)
    editHandles[recordKey] = handle
  end

  handle.recordKey = recordKey
  handle:ClearAllPoints()
  handle:SetAllPoints(record.parts.frame)
  handle:EnableMouse(true)
  handle:Show()
end

function GroupManager:RefreshEditHandles()
  HideEditHandles()
  if not enabled or not editing or IsStructureLocked() then
    return
  end

  for _, group in pairs(activeGroups) do
    for index = 1, #group.records do
      local record = group.records[index]
      if record.parts.frame:IsShown() then
        EnsureEditHandle(record)
      end
    end
  end
end

function GroupManager:RequestLayout(structureChanged, targetGroupID)
  if structureChanged then
    MarkOptionsTreeDirty(targetGroupID)
  end
  if not enabled then
    FlushOptionsTreeChange()
    return
  end
  pendingLayout = true
  flushFrame:Show()
end

function GroupManager:Flush()
  if not enabled then
    flushFrame:Hide()
    return
  end
  if not pendingLayout then
    flushFrame:SetShown(dynamicBoundsRefreshPasses > 0)
    return
  end
  pendingLayout = false
  RebuildActiveGroups()
  wipe(dynamicBoundsRows)
  wipe(dynamicBoundsRecords)
  for _, rows in pairs(centeredRowFrames) do
    for index = 1, #rows do
      rows[index]:Hide()
    end
  end

  for _, group in pairs(activeGroups) do
    if GroupUsesCollapsedAuraLayout(group, group.records) then
      ApplyCollapsedAuraIconRows(group, group.records)
    else
      local plan = group.data.kind == "BAR"
        and PlanBars(group.data, group.records)
        or PlanIcons(group.data, group.records)
      ApplyPlan(group, group.records, plan)
    end
  end

  RefreshDynamicBounds()
  SetDynamicBoundsActive(#dynamicBoundsRows > 0)

  ready = ns.PCMCatalog:GetGeneration() > 0
  AbilityRuntime:SetGroupLayoutReady(ready)
  AuraRuntime:SetGroupLayoutReady(ready)
  self:RefreshEditHandles()
  FlushOptionsTreeChange()
  flushFrame:SetShown(pendingLayout or dynamicBoundsRefreshPasses > 0)
end

function GroupManager:GetGroups()
  return GetDB()
end

function GroupManager:GetActiveGroup(groupID)
  return activeGroups[groupID]
end

function GroupManager:GetActiveRecord(recordKey)
  return activeRecordsByKey[recordKey]
end

function GroupManager:IsStructureLocked()
  return IsStructureLocked()
end

function GroupManager:CreateGroup(kind)
  if IsStructureLocked() then
    return nil
  end
  local group = CreateCustomGroup(kind == "BAR" and "BAR" or "ICON", 0, 0)
  self:RequestLayout(true, group.id)
  return group.id
end

function GroupManager:CreateGroupForRecord(recordKey)
  if IsStructureLocked() then
    return nil
  end

  local record = activeRecordsByKey[recordKey]
  if not record then
    return nil
  end

  local db = GetDB()
  local group = CreateCustomGroup(
    VIEWER_KIND[record.viewerKey],
    0,
    0
  )

  RemoveMemberFromOrders(db, recordKey)
  group.members[1] = recordKey
  db.assignments[recordKey] = group.id
  self:RequestLayout(true, group.id)
  return group.id
end

function GroupManager:RenameGroup(groupID, name)
  if IsStructureLocked() then
    return false
  end
  local group = GetDB().byID[groupID]
  if not group or type(name) ~= "string" then
    return false
  end
  name = name:match("^%s*(.-)%s*$")
  if name == "" then
    return false
  end
  group.name = name
  self:RequestLayout(true, groupID)
  return true
end

function GroupManager:DeleteGroup(groupID)
  if IsStructureLocked() then
    return false
  end
  local db = GetDB()
  local group = db.byID[groupID]
  if not group or group.isDefault then
    return false
  end

  for recordKey, assignedID in pairs(db.assignments) do
    if assignedID == groupID then
      db.assignments[recordKey] = nil
    end
  end
  db.byID[groupID] = nil
  for index = #db.order, 1, -1 do
    if db.order[index] == groupID then
      table.remove(db.order, index)
    end
  end
  FrameUtil.ClearSmartSnapForKey("PCM_Group_" .. groupID)
  FrameUtil:UnregisterMover("PCM_Group_" .. groupID)
  if groupFrames[groupID] then
    groupFrames[groupID]:Hide()
  end
  self:RequestLayout(true, "essential")
  return true
end

function GroupManager:MoveRecord(recordKey, groupID, insertIndex)
  if IsStructureLocked() then
    return false
  end
  return MoveRecord(recordKey, groupID, insertIndex)
end

function GroupManager:ResetGroups()
  if IsStructureLocked() then
    return false
  end
  local root = DB.GetPCMRoot()
  root.groups = nil
  profileDB = nil
  for groupID, frame in pairs(groupFrames) do
    FrameUtil.ClearSmartSnapForKey("PCM_Group_" .. groupID)
    FrameUtil:UnregisterMover("PCM_Group_" .. groupID)
    frame:Hide()
  end
  self:RequestLayout(true, "essential")
  return true
end

function GroupManager:IsReady()
  return enabled and ready
end

function GroupManager:RefreshProfile()
  profileDB = nil
  self:RequestLayout(true)
end

function GroupManager:OnEditModeChanged(active)
  editing = active == true
  self:RefreshEditHandles()
end

function GroupManager:Enable()
  if enabled then
    return
  end
  enabled = true
  ready = false
  AbilityRuntime:SetGroupLayoutEnabled(true)
  AuraRuntime:SetGroupLayoutEnabled(true)
  PCMRuntime:SetSubscriberEnabled("GroupManager", true)
  self:RequestLayout(true)
end

function GroupManager:Disable()
  if not enabled then
    return
  end
  enabled = false
  ready = false
  pendingLayout = false
  editing = false
  flushFrame:Hide()
  SetDynamicBoundsActive(false)
  wipe(dynamicBoundsRows)
  wipe(dynamicBoundsRecords)
  PCMRuntime:SetSubscriberEnabled("GroupManager", false)
  wipe(activeRestrictions)
  HideEditHandles()
  HideGroupLayoutFrames()
  for groupID, frame in pairs(groupFrames) do
    FrameUtil:UnregisterMover("PCM_Group_" .. groupID)
    frame:Hide()
  end
  AbilityRuntime:SetGroupLayoutEnabled(false)
  AuraRuntime:SetGroupLayoutEnabled(false)
end

FrameUtil.RegisterEditModeParticipant("PCM.Groups", GroupManager, 45)

PCMRuntime:RegisterSubscriber("GroupManager", {
  OnLifecycleEvent = function(event, restrictionType, state)
    local restrictionsCleared = false
    if event == "ADDON_RESTRICTION_STATE_CHANGED" then
      if not STRUCTURE_RESTRICTION_TYPES[restrictionType] then
        return
      end
      if state == Enum.AddOnRestrictionState.Inactive then
        activeRestrictions[restrictionType] = nil
        restrictionsCleared = next(activeRestrictions) == nil
      else
        activeRestrictions[restrictionType] = true
      end
      UpdateDynamicBoundsDriver()
    end

    if event == "PLAYER_ENTERING_WORLD"
      or event == "PLAYER_REGEN_ENABLED"
      or restrictionsCleared
    then
      UpdateDynamicBoundsDriver()
      GroupManager:RequestLayout()
      GroupManager:Flush()
    elseif editing then
      HideEditHandles()
    end
  end,
})

flushFrame:SetScript("OnUpdate", function()
  if pendingLayout then
    GroupManager:Flush()
  end
  if dynamicBoundsRefreshPasses > 0 then
    RefreshDynamicBounds()
    dynamicBoundsRefreshPasses = dynamicBoundsRefreshPasses - 1
  end
  flushFrame:SetShown(enabled and (
    dynamicBoundsRefreshPasses > 0 or pendingLayout
  ))
end)

dynamicBoundsEventFrame:SetScript("OnEvent", QueueDynamicBoundsRefresh)

local P = select(1, ns.Pleebug:DropIn(GroupManager, { name = "PCM", bucket = "Groups" }))
GroupManager.RefreshEditHandles = P:Def("GroupManager:RefreshEditHandles", GroupManager.RefreshEditHandles)
GroupManager.RequestLayout = P:Def("GroupManager:RequestLayout", GroupManager.RequestLayout)
GroupManager.Flush = P:Def("GroupManager:Flush", GroupManager.Flush)
GroupManager.GetGroups = P:Def("GroupManager:GetGroups", GroupManager.GetGroups)
GroupManager.GetActiveGroup = P:Def("GroupManager:GetActiveGroup", GroupManager.GetActiveGroup)
GroupManager.GetActiveRecord = P:Def("GroupManager:GetActiveRecord", GroupManager.GetActiveRecord)
GroupManager.IsStructureLocked = P:Def("GroupManager:IsStructureLocked", GroupManager.IsStructureLocked)
GroupManager.CreateGroup = P:Def("GroupManager:CreateGroup", GroupManager.CreateGroup)
GroupManager.CreateGroupForRecord = P:Def("GroupManager:CreateGroupForRecord", GroupManager.CreateGroupForRecord)
GroupManager.RenameGroup = P:Def("GroupManager:RenameGroup", GroupManager.RenameGroup)
GroupManager.DeleteGroup = P:Def("GroupManager:DeleteGroup", GroupManager.DeleteGroup)
GroupManager.MoveRecord = P:Def("GroupManager:MoveRecord", GroupManager.MoveRecord)
GroupManager.ResetGroups = P:Def("GroupManager:ResetGroups", GroupManager.ResetGroups)
GroupManager.IsReady = P:Def("GroupManager:IsReady", GroupManager.IsReady)
GroupManager.RefreshProfile = P:Def("GroupManager:RefreshProfile", GroupManager.RefreshProfile)
GroupManager.OnEditModeChanged = P:Def("GroupManager:OnEditModeChanged", GroupManager.OnEditModeChanged)
GroupManager.Enable = P:Def("GroupManager:Enable", GroupManager.Enable)
GroupManager.Disable = P:Def("GroupManager:Disable", GroupManager.Disable)
