local ADDON_NAME, ns = ...

local AbilityLayout = {}
ns.PCMAbilityLayout = AbilityLayout

local _G = _G
local CreateFrame = _G.CreateFrame
local ipairs = _G.ipairs
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local tonumber = _G.tonumber
local type = _G.type

local Round = ns.Pixel.Round

local VIEWER_ORDER = {
  "EssentialCooldownViewer",
  "UtilityCooldownViewer",
}

local VIEWER_SET = {
  EssentialCooldownViewer = true,
  UtilityCooldownViewer = true,
}

local MIN_ICON_SIZE = 8
local MAX_ICON_SIZE = 96
local MIN_SPACING = -20
local MAX_SPACING = 40
local MIN_FIRST_ROW = 0
local MAX_FIRST_ROW = 40
local MIN_BORDER = 0
local MAX_BORDER = 8
local MIN_FIXED_WIDTH = 1
local MAX_FIXED_WIDTH = 1000

local registeredViewers = {}
local pendingViewers = {}
local flushFrame

local function Clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  end
  if value > maximum then
    return maximum
  end
  return value
end

local function IsViewerKey(viewerKey)
  return VIEWER_SET[viewerKey] == true
end

local function RoundPixel(value)
  return Round(value)
end

local function FloorToPixel(value)
  local onePixel = ns.Pixel.GetOnePixel()
  return math_floor(value / onePixel) * onePixel
end

local function ResolveStyle(resolvedStyle)
  if type(resolvedStyle) ~= "table" then
    return nil
  end

  local widthMode = resolvedStyle.widthMode
  if widthMode ~= "icon" and widthMode ~= "fixed" then
    return nil
  end

  local iconSize = tonumber(resolvedStyle.iconSize)
  local spacing = tonumber(resolvedStyle.spacing)
  local firstRowLimit = tonumber(resolvedStyle.firstRowLimit)
  local borderThickness = tonumber(resolvedStyle.borderThickness)

  if iconSize == nil
    or spacing == nil
    or firstRowLimit == nil
    or borderThickness == nil
  then
    return nil
  end

  iconSize = Clamp(RoundPixel(iconSize), MIN_ICON_SIZE, MAX_ICON_SIZE)
  spacing = Clamp(RoundPixel(spacing), MIN_SPACING, MAX_SPACING)
  firstRowLimit = Clamp(math_floor(firstRowLimit), MIN_FIRST_ROW, MAX_FIRST_ROW)
  borderThickness = Clamp(RoundPixel(borderThickness), MIN_BORDER, MAX_BORDER)

  local fixedWidth
  if widthMode == "fixed" then
    fixedWidth = tonumber(resolvedStyle.fixedWidth)
    if fixedWidth == nil then
      return nil
    end
    fixedWidth = Clamp(RoundPixel(fixedWidth), MIN_FIXED_WIDTH, MAX_FIXED_WIDTH)
  end

  return {
    widthMode = widthMode,
    fixedWidth = fixedWidth,
    iconSize = iconSize,
    spacing = spacing,
    firstRowLimit = firstRowLimit,
    rowGrowth = resolvedStyle.rowGrowth == "UP" and "UP" or "DOWN",
    borderThickness = borderThickness,
  }
end

local function GetEntryCount(orderedEntries)
  if type(orderedEntries) ~= "table" then
    return nil
  end

  for index = 1, #orderedEntries do
    if type(orderedEntries[index]) ~= "table" then
      return nil
    end
  end

  return #orderedEntries
end

function AbilityLayout:Plan(viewerKey, orderedEntries, resolvedStyle)
  if not IsViewerKey(viewerKey) then
    return nil
  end

  local count = GetEntryCount(orderedEntries)
  if count == nil then
    return nil
  end

  local style = ResolveStyle(resolvedStyle)
  if not style then
    return nil
  end

  local plan = {
    viewerKey = viewerKey,
    width = 1,
    height = 1,
    items = {},
  }

  if count == 0 then
    return plan
  end

  local row1Count
  if style.firstRowLimit == 0 then
    row1Count = count
  else
    row1Count = math_min(style.firstRowLimit, count)
  end

  local row2Count = math_max(count - row1Count, 0)

  local row1Size = style.iconSize
  if style.widthMode == "fixed" then
    row1Size = FloorToPixel(
      (style.fixedWidth - ((row1Count - 1) * style.spacing)) / row1Count
    )
  end
  if row1Size < 1 then
    row1Size = 1
  end

  local row2Size = row1Size
  if row2Count > 0 and style.widthMode == "fixed" then
    local row2Fitted = (
      style.fixedWidth - ((row2Count - 1) * style.spacing)
    ) / row2Count
    row2Size = math_min(row1Size, FloorToPixel(row2Fitted))
    if row2Size < 1 then
      row2Size = 1
    end
  end

  local row1Width = (row1Count * row1Size)
    + ((row1Count - 1) * style.spacing)
  local row2Width = row2Count > 0
    and ((row2Count * row2Size) + ((row2Count - 1) * style.spacing))
    or 0

  local contentWidth
  if style.widthMode == "fixed" then
    contentWidth = style.fixedWidth
  else
    contentWidth = math_max(row1Width, row2Width, row1Size)
  end

  local contentHeight = row1Size
  if row2Count > 0 then
    contentHeight = contentHeight + style.spacing + row2Size
  end

  local borderPad = style.borderThickness * 2
  local containerWidth = math_max(1, RoundPixel(contentWidth + borderPad))
  local containerHeight = math_max(1, RoundPixel(contentHeight + borderPad))

  local row1Y = (containerHeight / 2) - (row1Size / 2)
  local row2Y = row1Y - (row1Size / 2) - style.spacing - (row2Size / 2)

  if row2Count > 0 and style.rowGrowth == "UP" then
    row1Y = -(containerHeight / 2) + (row1Size / 2)
    row2Y = row1Y + (row1Size / 2) + style.spacing + (row2Size / 2)
  end

  local row1StartX = -(row1Width / 2) + (row1Size / 2)
  for index = 1, row1Count do
    local entry = orderedEntries[index]
    plan.items[index] = {
      cooldownID = entry.cooldownID,
      x = RoundPixel(row1StartX + ((index - 1) * (row1Size + style.spacing))),
      y = RoundPixel(row1Y),
      size = row1Size,
    }
  end

  if row2Count > 0 then
    local row2StartX = -(row2Width / 2) + (row2Size / 2)
    for column = 1, row2Count do
      local index = row1Count + column
      local entry = orderedEntries[index]
      plan.items[index] = {
        cooldownID = entry.cooldownID,
        x = RoundPixel(row2StartX + ((column - 1) * (row2Size + style.spacing))),
        y = RoundPixel(row2Y),
        size = row2Size,
      }
    end
  end

  plan.width = containerWidth
  plan.height = containerHeight
  return plan
end

function AbilityLayout:ApplyPlan(container, orderedFrames, plan)
  if not container
    or not container.SetSize
    or type(orderedFrames) ~= "table"
    or type(plan) ~= "table"
    or type(plan.items) ~= "table"
    or #orderedFrames ~= #plan.items
  then
    return false
  end

  for index, frame in ipairs(orderedFrames) do
    local item = plan.items[index]
    if not frame
      or not frame.SetSize
      or not frame.ClearAllPoints
      or not frame.SetPoint
      or type(item) ~= "table"
    then
      return false
    end
  end

  container:SetSize(plan.width, plan.height)

  for index, frame in ipairs(orderedFrames) do
    local item = plan.items[index]
    frame:SetSize(item.size, item.size)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", container, "CENTER", item.x, item.y)
  end

  return true
end

function AbilityLayout:RegisterOwnedViewer(viewerKey, container, sources)
  if not IsViewerKey(viewerKey)
    or not container
    or not container.SetSize
    or not container.ClearAllPoints
    or not container.SetPoint
    or type(sources) ~= "table"
    or type(sources.getOrderedEntries) ~= "function"
    or type(sources.getOrderedFrames) ~= "function"
    or type(sources.getResolvedStyle) ~= "function"
  then
    return false
  end

  registeredViewers[viewerKey] = {
    container = container,
    sources = sources,
    lastPlan = nil,
  }
  return true
end

function AbilityLayout:UnregisterOwnedViewer(viewerKey)
  if not IsViewerKey(viewerKey) then
    return
  end

  registeredViewers[viewerKey] = nil
  pendingViewers[viewerKey] = nil
end

function AbilityLayout:GetLastPlan(viewerKey)
  local registration = registeredViewers[viewerKey]
  return registration and registration.lastPlan or nil
end

local function FlushViewer(viewerKey)
  local registration = registeredViewers[viewerKey]
  if not registration then
    return false
  end

  local sources = registration.sources
  local entries = sources.getOrderedEntries(viewerKey)
  local frames = sources.getOrderedFrames(viewerKey)
  local style = sources.getResolvedStyle(viewerKey)
  local plan = AbilityLayout:Plan(viewerKey, entries, style)
  if not plan then
    return false
  end

  if not AbilityLayout:ApplyPlan(registration.container, frames, plan) then
    return false
  end

  registration.lastPlan = plan

  if type(sources.layoutApplied) == "function" then
    sources.layoutApplied(viewerKey, plan)
  end

  return true
end

function AbilityLayout:FlushPendingLayouts()
  local flushNow = {}
  for _, viewerKey in ipairs(VIEWER_ORDER) do
    if pendingViewers[viewerKey] then
      flushNow[viewerKey] = true
      pendingViewers[viewerKey] = nil
    end
  end

  for _, viewerKey in ipairs(VIEWER_ORDER) do
    if flushNow[viewerKey] then
      FlushViewer(viewerKey)
    end
  end

  if flushFrame then
    for _, viewerKey in ipairs(VIEWER_ORDER) do
      if pendingViewers[viewerKey] then
        flushFrame:Show()
        return
      end
    end
  end
end

local function EnsureFlushFrame()
  if flushFrame then
    return flushFrame
  end

  flushFrame = CreateFrame("Frame")
  flushFrame:Hide()
  flushFrame:SetScript("OnUpdate", function(frame)
    frame:Hide()
    AbilityLayout:FlushPendingLayouts()
  end)
  return flushFrame
end

function AbilityLayout:RequestLayout(viewerKey)
  if not IsViewerKey(viewerKey) or not registeredViewers[viewerKey] then
    return false
  end

  pendingViewers[viewerKey] = true
  EnsureFlushFrame():Show()
  return true
end

local P = select(1, ns.Pleebug:DropIn(AbilityLayout, { name = "PCM", bucket = "AbilityLayout" }))
AbilityLayout.Plan = P:Def("AbilityLayout:Plan", AbilityLayout.Plan)
AbilityLayout.ApplyPlan = P:Def("AbilityLayout:ApplyPlan", AbilityLayout.ApplyPlan)
AbilityLayout.RegisterOwnedViewer = P:Def("AbilityLayout:RegisterOwnedViewer", AbilityLayout.RegisterOwnedViewer)
AbilityLayout.UnregisterOwnedViewer = P:Def("AbilityLayout:UnregisterOwnedViewer", AbilityLayout.UnregisterOwnedViewer)
AbilityLayout.GetLastPlan = P:Def("AbilityLayout:GetLastPlan", AbilityLayout.GetLastPlan)
AbilityLayout.FlushPendingLayouts = P:Def("AbilityLayout:FlushPendingLayouts", AbilityLayout.FlushPendingLayouts)
AbilityLayout.RequestLayout = P:Def("AbilityLayout:RequestLayout", AbilityLayout.RequestLayout)
