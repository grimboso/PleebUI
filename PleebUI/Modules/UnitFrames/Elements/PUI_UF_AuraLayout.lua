local _, ns = ...

local _G = _G
local AuraLayout = {}
ns.UFAuraLayout = AuraLayout

local math_ceil = _G.math.ceil
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local tonumber = _G.tonumber

local function Round(value)
  return ns.Pixel.Round(tonumber(value) or 0)
end

function AuraLayout.ResolveAttachTarget(frame, attachTo)
  if attachTo == "HEALTH" then
    return frame.Health or frame
  elseif attachTo == "POWER" then
    return frame.Power and frame.Power:IsShown() and frame.Power or frame
  end

  return frame
end

function AuraLayout.ResolveIconSize(healthHeight, display)
  if not display.autoIconSize then
    return tonumber(display.iconSize) or 20
  end

  healthHeight = math_max(1, tonumber(healthHeight) or 1)

  if display.autoIconSizeMode == "HEALTH" then
    return healthHeight
  end

  local size = math_floor(healthHeight * 0.62 + 0.5)

  if size < 18 then
    return 18
  elseif size > 30 then
    return 30
  end

  return size
end

function AuraLayout.ResolveDisplayMetrics(frameWidth, healthHeight, scale, grouped, display)
  scale = tonumber(scale) or 1

  local rawSize = math_max(1, AuraLayout.ResolveIconSize(healthHeight, display))
  local rawSpacing = math_max(0, tonumber(display.spacing) or 0)
  local size = math_max(Round(1), Round(rawSize * scale))
  local spacing = math_max(0, Round(rawSpacing * scale))
  local maxIcons = display.displayType == "slot"
    and 1
    or math_max(1, math_floor(tonumber(display.maxIcons) or 1))
  local iconsPerLine

  if grouped then
    iconsPerLine = maxIcons
  else
    local rawMaximumLineSize = math_max(rawSize, tonumber(frameWidth) or rawSize)

    iconsPerLine = math_max(
      1,
      math_floor((rawMaximumLineSize + rawSpacing) / (rawSize + rawSpacing))
    )
    iconsPerLine = math_min(iconsPerLine, maxIcons)
  end

  local maximumLineSize = size * iconsPerLine + spacing * (iconsPerLine - 1)

  return {
    size = size,
    spacing = spacing,
    maxIcons = maxIcons,
    maximumLineSize = maximumLineSize,
    iconsPerLine = iconsPerLine,
    lineCount = math_ceil(maxIcons / iconsPerLine),
    growthX = display.growthX == "LEFT" and "LEFT" or "RIGHT",
    growthY = display.growthY == "UP" and "UP" or "DOWN",
  }
end

function AuraLayout.GetSyntheticDisplayIconCount(display, maximum)
  maximum = math_max(0, math_floor(tonumber(maximum) or 0))

  if display.specialType ~= "DEFENSIVES_EXTERNALS" then
    return maximum
  end

  local count = 0

  if display.showDefensives ~= false then
    count = count + 1
  end

  if display.showExternals ~= false then
    count = count + 1
  end

  return math_min(maximum, count)
end

function AuraLayout.GetSyntheticDisplayAnchorOffset(metrics, display, anchorPoint, iconCount)
  anchorPoint = anchorPoint or display.anchorPoint or "TOPLEFT"

  if display.specialType ~= "DEFENSIVES_EXTERNALS" or anchorPoint ~= "CENTER" then
    return 0, 0
  end

  iconCount = math_max(0, math_floor(tonumber(iconCount) or 0))
  if iconCount == 0 then
    return 0, 0
  end

  local iconsInFirstLine = math_min(iconCount, metrics.iconsPerLine)
  local lineWidth = metrics.size * iconsInFirstLine
    + metrics.spacing * math_max(0, iconsInFirstLine - 1)
  local xOffset = (lineWidth - metrics.size) * 0.5

  if metrics.growthX == "RIGHT" then
    xOffset = -xOffset
  end

  return Round(xOffset), 0
end

function AuraLayout.GetIconOffset(metrics, index)
  local column = (index - 1) % metrics.iconsPerLine
  local row = math_floor((index - 1) / metrics.iconsPerLine)
  local xDirection = metrics.growthX == "LEFT" and -1 or 1
  local yDirection = metrics.growthY == "UP" and 1 or -1
  local step = metrics.size + metrics.spacing

  return column * step * xDirection, row * step * yDirection
end

local P = select(1, ns.Pleebug:DropIn(AuraLayout, { name = "UnitFrames.AuraLayout" }))
AuraLayout.ResolveAttachTarget = P:Def("AuraLayout.ResolveAttachTarget", AuraLayout.ResolveAttachTarget)
AuraLayout.ResolveIconSize = P:Def("AuraLayout.ResolveIconSize", AuraLayout.ResolveIconSize)
AuraLayout.ResolveDisplayMetrics = P:Def("AuraLayout.ResolveDisplayMetrics", AuraLayout.ResolveDisplayMetrics)
AuraLayout.GetSyntheticDisplayIconCount = P:Def(
  "AuraLayout.GetSyntheticDisplayIconCount",
  AuraLayout.GetSyntheticDisplayIconCount
)
AuraLayout.GetSyntheticDisplayAnchorOffset = P:Def(
  "AuraLayout.GetSyntheticDisplayAnchorOffset",
  AuraLayout.GetSyntheticDisplayAnchorOffset
)
AuraLayout.GetIconOffset = P:Def("AuraLayout.GetIconOffset", AuraLayout.GetIconOffset)
Round = P:Def("AuraLayout.Round", Round)
