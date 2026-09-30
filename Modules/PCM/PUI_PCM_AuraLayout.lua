local _, ns = ...

local AuraLayout = {}
ns.PCMAuraLayout = AuraLayout

local CreateFrame = CreateFrame
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min
local tonumber = tonumber

local Round = ns.Pixel.Round

local BUFF_ICON_VIEWER = "BuffIconCooldownViewer"
local BUFF_BAR_VIEWER = "BuffBarCooldownViewer"

local registrations = {}
local pending = {}
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

local function ResolveIconStyle(style)
  local size = Clamp(Round(tonumber(style.iconSize) or 36), 12, 86)
  local spacing = Clamp(Round(tonumber(style.spacing) or 1), 0, 128)
  local columns = Clamp(math.floor(tonumber(style.columns) or 0), 0, 40)
  local growth = style.growth
  if growth ~= "LEFT" and growth ~= "RIGHT" then
    growth = "CENTER"
  end
  return size, spacing, columns, growth
end

local function PlanIcons(frames, style)
  local size, spacing, columns, growth = ResolveIconStyle(style)
  local count = #frames
  local plan = { width = 1, height = 1, items = {} }
  if count == 0 then
    return plan
  end

  local rowLimit = columns > 0 and columns or count
  local rowCount = math_ceil(count / rowLimit)
  local widestRow = math_min(count, rowLimit)
  plan.width = math_max(1, widestRow * size + (widestRow - 1) * spacing)
  plan.height = math_max(1, rowCount * size + (rowCount - 1) * spacing)

  local itemIndex = 1
  local topY = ((rowCount - 1) * (size + spacing)) / 2
  for row = 1, rowCount do
    local rowItems = math_min(rowLimit, count - itemIndex + 1)
    local direction = growth == "LEFT" and -1 or 1
    local startX
    if growth == "CENTER" then
      local rowWidth = rowItems * size + (rowItems - 1) * spacing
      startX = -(rowWidth / 2) + (size / 2)
    else
      startX = 0
    end

    for column = 1, rowItems do
      plan.items[itemIndex] = {
        frame = frames[itemIndex],
        x = Round(startX + ((column - 1) * (size + spacing) * direction)),
        y = Round(topY - ((row - 1) * (size + spacing))),
        width = size,
        height = size,
      }
      itemIndex = itemIndex + 1
    end
  end
  return plan
end

local function ResolveBarGeometry(style)
  local vertical = style.orientation == "VERTICAL"
  local length = Clamp(Round(tonumber(style.width) or 250), 120, 500)
  local thickness = Clamp(Round(tonumber(style.height) or 20), 8, 40)
  local spacing = Clamp(Round(tonumber(style.rowSpacing) or 1), -20, 40)
  local width = vertical and thickness or length
  local height = vertical and length or thickness
  local growth = style.growthDirection
  if vertical then
    growth = growth == "LEFT" and "LEFT" or "RIGHT"
  else
    growth = growth == "UP" and "UP" or "DOWN"
  end
  return vertical, width, height, spacing, growth
end

local function PlanBars(frames, style)
  local vertical, width, height, spacing, growth = ResolveBarGeometry(style)
  local count = #frames
  local plan = { width = 1, height = 1, items = {} }
  if count == 0 then
    return plan
  end

  if vertical then
    plan.width = count * width + (count - 1) * spacing
    plan.height = height
  else
    plan.width = width
    plan.height = count * height + (count - 1) * spacing
  end

  for index = 1, count do
    local x = 0
    local y = 0
    local point
    if vertical then
      local direction = growth == "LEFT" and -1 or 1
      x = (index - 1) * (width + spacing) * direction
      point = growth == "LEFT" and "TOPRIGHT" or "TOPLEFT"
    else
      local direction = growth == "UP" and 1 or -1
      y = (index - 1) * (height + spacing) * direction
      point = growth == "UP" and "BOTTOMLEFT" or "TOPLEFT"
    end
    plan.items[index] = {
      frame = frames[index],
      point = point,
      x = Round(x),
      y = Round(y),
      width = width,
      height = height,
    }
  end
  return plan
end

local function ApplyPlan(container, plan)
  container:SetSize(math_max(1, Round(plan.width)), math_max(1, Round(plan.height)))
  for index = 1, #plan.items do
    local item = plan.items[index]
    local frame = item.frame
    frame:SetSize(item.width, item.height)
    frame:ClearAllPoints()
    local point = item.point or "CENTER"
    frame:SetPoint(point, container, point, item.x, item.y)
  end
end

local function FlushViewer(viewerKey)
  local registration = registrations[viewerKey]
  if not registration then
    return
  end

  local frames = registration.getFrames()
  local style = registration.getStyle()
  local plan
  if viewerKey == BUFF_ICON_VIEWER then
    plan = PlanIcons(frames, style)
  else
    plan = PlanBars(frames, style)
  end
  ApplyPlan(registration.container, plan)
  registration.lastPlan = plan
  if registration.onApplied then
    registration.onApplied(plan)
  end
end

function AuraLayout:RegisterViewer(viewerKey, container, getFrames, getStyle, onApplied)
  if viewerKey ~= BUFF_ICON_VIEWER and viewerKey ~= BUFF_BAR_VIEWER then
    return
  end
  registrations[viewerKey] = {
    container = container,
    getFrames = getFrames,
    getStyle = getStyle,
    onApplied = onApplied,
  }
end

function AuraLayout:UnregisterViewer(viewerKey)
  registrations[viewerKey] = nil
  pending[viewerKey] = nil
end

function AuraLayout:GetLastPlan(viewerKey)
  local registration = registrations[viewerKey]
  return registration and registration.lastPlan or nil
end

function AuraLayout:RequestLayout(viewerKey)
  if not registrations[viewerKey] then
    return
  end
  pending[viewerKey] = true
  if not flushFrame then
    flushFrame = CreateFrame("Frame")
    flushFrame:Hide()
    flushFrame:SetScript("OnUpdate", function(frame)
      frame:Hide()
      AuraLayout:Flush()
    end)
  end
  flushFrame:Show()
end

function AuraLayout:Flush()
  if pending[BUFF_ICON_VIEWER] then
    pending[BUFF_ICON_VIEWER] = nil
    FlushViewer(BUFF_ICON_VIEWER)
  end
  if pending[BUFF_BAR_VIEWER] then
    pending[BUFF_BAR_VIEWER] = nil
    FlushViewer(BUFF_BAR_VIEWER)
  end
end

local P = select(1, ns.Pleebug:DropIn(AuraLayout, { name = "PCM", bucket = "AuraLayout" }))
AuraLayout.RegisterViewer = P:Def("AuraLayout:RegisterViewer", AuraLayout.RegisterViewer)
AuraLayout.UnregisterViewer = P:Def("AuraLayout:UnregisterViewer", AuraLayout.UnregisterViewer)
AuraLayout.GetLastPlan = P:Def("AuraLayout:GetLastPlan", AuraLayout.GetLastPlan)
AuraLayout.RequestLayout = P:Def("AuraLayout:RequestLayout", AuraLayout.RequestLayout)
AuraLayout.Flush = P:Def("AuraLayout:Flush", AuraLayout.Flush)
