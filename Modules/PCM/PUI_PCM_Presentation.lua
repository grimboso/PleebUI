local _, ns = ...

local Presentation = ns.Presentation
local BarWidget = ns.BarWidget
local IconSkin = ns.IconSkin
local AuraSlotDriver = ns.AuraSlotDriver
local AuraWidget = ns.AuraWidget
local Theme = ns.Theme
local LSM = ns.LSM
local Round = ns.Pixel.Round
local LCG = LibStub("LibCustomGlow-1.0")

local PCMPresentation = {}
ns.PCMPresentation = PCMPresentation

local CreateFrame = CreateFrame
local UIParent = UIParent
local C_Secrets = C_Secrets
local math_max = math.max
local math_floor = math.floor
local next = next
local pairs = pairs
local tonumber = tonumber
local type = type
local tostring = tostring

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local FALLBACK_BAR_TEXTURE = Theme.GetBarTexture()
local InstanceIndex = 0

local CHARGE_SLOT_DEFAULT_COLORS = {
  [1] = { 0.8, 0.2, 0.2, 1 },
  [2] = { 0.8, 0.8, 0.2, 1 },
  [3] = { 0.2, 0.8, 0.2, 1 },
  [4] = { 0.2, 0.6, 0.8, 1 },
  [5] = { 0.6, 0.2, 0.8, 1 },
}

local function CopyColor(color, fallback)
  color = type(color) == "table" and color or fallback or {}
  return {
    tonumber(color[1] or color.r) or 1,
    tonumber(color[2] or color.g) or 1,
    tonumber(color[3] or color.b) or 1,
    tonumber(color[4] or color.a) or 1,
  }
end

local function ResolveTexture(key)
  return BarWidget.ResolveStatusBarTexture(key, FALLBACK_BAR_TEXTURE)
end

local function ResolveFont(config, role, fallbackSize)
  config = config or {}
  local isDuration = config.kind == "duration"
  local key = isDuration and config.durationFont or config.font
  local path = key and LSM:Fetch("font", key, true) or nil

  if not path then
    path = LSM:Fetch("font", Theme.GetFont(role), true) or STANDARD_TEXT_FONT
  end

  local size = tonumber(
    config.size
      or (isDuration and config.durationFontSize)
      or config.fontSize
  ) or fallbackSize or 12
  local flags = config.flags
    or (isDuration and config.durationOutline)
    or config.fontOutline
    or config.outline
    or "OUTLINE"

  return path, size, flags
end

local function ApplyFont(fontString, config, role, fallbackSize)
  if not fontString then
    return
  end

  local path, size, flags = ResolveFont(config, role, fallbackSize)
  fontString:SetFont(path, size, flags)
  fontString:SetShadowColor(0, 0, 0, 1)
  fontString:SetShadowOffset(1, -1)

  local color = config and (
    config.color
      or (config.kind == "duration" and config.durationColor)
      or config.fontColor
  )
  if type(color) == "table" then
    fontString:SetTextColor(
      color[1] or color.r or 1,
      color[2] or color.g or 1,
      color[3] or color.b or 1,
      color[4] or color.a or 1
    )
  end
end

local function SetBackground(texture, color)
  if not texture then
    return
  end

  local c = CopyColor(color, { 0.12, 0.12, 0.12, 0.95 })
  texture:SetColorTexture(c[1], c[2], c[3], c[4])
end


local function ApplyTemplateBorder(borderFrame, thickness, color, edges)
  if not borderFrame then
    return
  end

  thickness = math_max(0, tonumber(thickness) or 0)
  local shown = thickness > 0
  local c = CopyColor(color, { 0.20, 0.20, 0.24, 1 })
  edges = edges or {}

  local topShown = shown and edges.top ~= false
  local bottomShown = shown and edges.bottom ~= false
  local leftShown = shown and edges.left ~= false
  local rightShown = shown and edges.right ~= false

  local top = borderFrame.top or borderFrame.Top
  local bottom = borderFrame.bottom or borderFrame.Bottom
  local left = borderFrame.left or borderFrame.Left
  local right = borderFrame.right or borderFrame.Right

  if top then
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", borderFrame, "TOPRIGHT", 0, 0)
    top:SetHeight(thickness)
    top:SetColorTexture(c[1], c[2], c[3], c[4])
    top:SetShown(topShown)
  end
  if bottom then
    bottom:ClearAllPoints()
    if edges.centerBottom == true then
      bottom:SetPoint("LEFT", borderFrame, "BOTTOMLEFT", 0, 0)
      bottom:SetPoint("RIGHT", borderFrame, "BOTTOMRIGHT", 0, 0)
    else
      bottom:SetPoint("BOTTOMLEFT", borderFrame, "BOTTOMLEFT", 0, 0)
      bottom:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", 0, 0)
    end
    bottom:SetHeight(thickness)
    bottom:SetColorTexture(c[1], c[2], c[3], c[4])
    bottom:SetShown(bottomShown)
  end
  if left then
    left:ClearAllPoints()
    if edges.centerLeft == true then
      left:SetPoint("TOP", borderFrame, "TOPLEFT", 0, 0)
      left:SetPoint("BOTTOM", borderFrame, "BOTTOMLEFT", 0, 0)
    else
      left:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", 0, 0)
      left:SetPoint("BOTTOMLEFT", borderFrame, "BOTTOMLEFT", 0, 0)
    end
    left:SetWidth(thickness)
    left:SetColorTexture(c[1], c[2], c[3], c[4])
    left:SetShown(leftShown)
  end
  if right then
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", borderFrame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(thickness)
    right:SetColorTexture(c[1], c[2], c[3], c[4])
    right:SetShown(rightShown)
  end

  borderFrame:SetShown(topShown or bottomShown or leftShown or rightShown)
end

local function CreateDurationParts(parent, context)
  InstanceIndex = InstanceIndex + 1
  local name = context.name
  if not name and context.named == true then
    name = "PleebUI_PCMPresentationBar" .. InstanceIndex
  end

  local frame = CreateFrame("Frame", name, parent or UIParent, "PUI_DurationBarTemplate")
  local parts = BarWidget.BindDurationBarFrame(frame, {})

  parts.kind = context.kind or "duration"
  parts.status = parts.cooldownBar
  parts.background = parts.bg
  parts.valueTextFrame = parts.textFrame
  parts.valueText = parts.text
  parts.stackSegments = {}
  parts.chargeSlots = {}

  parts.label = frame:CreateFontString(nil, "OVERLAY")
  parts.label:SetJustifyH("RIGHT")
  parts.label:Hide()

  parts.barFrame:SetFrameStrata(frame:GetFrameStrata())
  parts.barFrame:SetFrameLevel(frame:GetFrameLevel())
  parts.barFrame:EnableMouse(false)
  parts.background:SetAllPoints(parts.barFrame)

  parts.iconFrame:SetFrameStrata(frame:GetFrameStrata())
  parts.iconFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
  parts.iconFrame:EnableMouse(false)
  parts.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  parts.status:SetFrameStrata(frame:GetFrameStrata())
  parts.status:SetFrameLevel(frame:GetFrameLevel())
  parts.status:SetMinMaxValues(0, 1)
  parts.status:SetValue(1)
  parts.status:SetStatusBarTexture(FALLBACK_BAR_TEXTURE)
  parts.status:GetStatusBarTexture():SetDrawLayer("ARTWORK", 0)

  parts.valueTextFrame:SetFrameStrata(frame:GetFrameStrata())
  parts.valueTextFrame:SetFrameLevel(frame:GetFrameLevel() + 20)
  parts.valueTextFrame:EnableMouse(false)
  parts.valueText:SetDrawLayer("OVERLAY", 7)

  return parts
end

local function CreateChargeParts(parent, context)
  InstanceIndex = InstanceIndex + 1
  local name = context.name
  if not name and context.named == true then
    name = "PleebUI_PCMChargePresentation" .. InstanceIndex
  end

  local frame = CreateFrame("Frame", name, parent or UIParent, "PUI_ChargeBarTemplate")
  local parts = BarWidget.BindChargeBarFrame(frame, {})

  parts.kind = "charge"
  parts.chargeRoot = parts.slotsContainer
  parts.valueTextFrame = parts.timerTextContainer
  parts.valueText = parts.timerText
  parts.chargeSlots = {}
  parts.chargeSlotPool = {}
  parts.stackSegments = {}

  parts.iconFrame:SetFrameLevel(frame:GetFrameLevel() + 4)
  parts.icon:SetAllPoints(parts.iconFrame)
  parts.slotsContainer:SetFrameLevel(frame:GetFrameLevel() + 2)
  parts.chargeTrackerBar:SetFrameLevel(parts.slotsContainer:GetFrameLevel())
  parts.timerTextContainer:SetFrameStrata(frame:GetFrameStrata())
  parts.timerTextContainer:SetFrameLevel(frame:GetFrameLevel() + 24)
  parts.timerTextContainer:EnableMouse(false)
  parts.timerText:SetDrawLayer("OVERLAY", 7)
  parts.timerText:SetShadowOffset(1, -1)

  return parts
end

local function EnsureStackSegments(parts, count)
  count = math_max(1, math_floor(tonumber(count) or 1))
  parts.stackSegments = parts.stackSegments or {}

  for index = #parts.stackSegments + 1, count do
    local segment = CreateFrame("StatusBar", nil, parts.status)
    segment:SetMinMaxValues(0, 1)
    segment:SetValue(0)
    segment:SetFrameLevel(parts.status:GetFrameLevel() + 1)
    parts.stackSegments[index] = segment
  end

  for index = count + 1, #parts.stackSegments do
    parts.stackSegments[index]:Hide()
  end

  return parts.stackSegments
end

local function BindChargeSlot(frame, state)
  state = BarWidget.BindChargeSlotFrame(frame, state or {})
  state.rechargeBar:SetMinMaxValues(0, 1)
  state.fullBar:SetMinMaxValues(0, 1)
  state.fullBar:SetValue(1)
  state.rechargeBar:SetValue(0)
  return state
end

local function EnsureChargeSlots(parts, count)
  count = math_max(1, math_floor(tonumber(count) or 1))
  parts.chargeSlots = parts.chargeSlots or {}
  parts.chargeSlotPool = parts.chargeSlotPool or {}

  for index = #parts.chargeSlots + 1, count do
    local slot = table.remove(parts.chargeSlotPool)
    if not slot then
      local frame = CreateFrame("Frame", nil, parts.slotsContainer, "PUI_ChargeSlotTemplate")
      slot = BindChargeSlot(frame)
    else
      slot.frame:SetParent(parts.slotsContainer)
    end

    parts.chargeSlots[index] = slot
  end

  for index = #parts.chargeSlots, count + 1, -1 do
    local slot = table.remove(parts.chargeSlots, index)
    slot.frame:Hide()
    slot.borderFrame:Hide()
    parts.chargeSlotPool[#parts.chargeSlotPool + 1] = slot
  end

  return parts.chargeSlots
end

local function LayoutChargeSlots(parts, state)
  local cfg = state.config or {}
  local count = math_max(1, math_floor(tonumber(state.maxCharges or cfg.maxCharges) or 2))
  local vertical = cfg.orientation == "vertical"
  local scale = math_max(0.01, tonumber(state.scale) or 1)
  local totalSize = vertical and parts.slotsContainer:GetHeight() or parts.slotsContainer:GetWidth()
  local thickness = vertical and parts.slotsContainer:GetWidth() or parts.slotsContainer:GetHeight()
  local spacing = (tonumber(cfg.slotSpacing) or 0) * scale
  local available = math_max(1, totalSize - spacing * (count - 1))
  local span = available / count
  local slots = EnsureChargeSlots(parts, count)
  local texture = ResolveTexture(cfg.texture or "Pleebar")
  local background = CopyColor(cfg.slotBackgroundColor, { 0.12, 0.12, 0.12, 0.95 })
  local opacity = tonumber(cfg.opacity) or 1
  local barColor = CopyColor(state.color or cfg.barColor, { 1, 1, 1, 1 })
  barColor[4] = barColor[4] * opacity
  local fullColor = cfg.useDifferentFullColor == true
    and CopyColor(cfg.fullChargeColor, barColor)
    or CopyColor(barColor)
  fullColor[4] = (cfg.useDifferentFullColor == true and fullColor[4] * opacity) or fullColor[4]
  local borderColor = CopyColor(cfg.slotBorderColor, { 0.20, 0.20, 0.24, 1 })
  borderColor[4] = borderColor[4] * opacity
  local borderSize = cfg.showSlotBorder == true
    and math_max(0, tonumber(cfg.slotBorderThickness) or 2) * scale
    or 0
  local inset = borderSize * ns.FrameScale:BestOnePixel()
  local joinedSlots = spacing == 0
  local fillDirection = tostring(
    cfg.fillDirection or (vertical and "UP" or "RIGHT")
  ):upper()
  local reverseFill = vertical and fillDirection == "DOWN"
    or not vertical and fillDirection == "LEFT"
  local rotateTexture = cfg.rotateTexture == true or (cfg.rotateTexture ~= false and vertical)

  parts.chargeTrackerBar:ClearAllPoints()
  parts.chargeTrackerBar:SetPoint("BOTTOMLEFT", parts.slotsContainer, "BOTTOMLEFT", 0, 0)
  parts.chargeTrackerBar:SetMinMaxValues(0, count)
  parts.chargeTrackerBar:SetValue(0)
  parts.chargeTrackerBar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
  parts.chargeTrackerBar:SetSize(vertical and thickness or totalSize, vertical and totalSize or thickness)
  parts.chargeTrackerBar:Show()

  for index = 1, count do
    local slot = slots[index]
    local offset = (index - 1) * (span + spacing)
    local size = index == count and math_max(1, totalSize - offset) or span
    local width = vertical and thickness or size
    local height = vertical and size or thickness
    local leftInset = inset
    local rightInset = inset
    local bottomInset = inset
    local topInset = inset
    local slotColor = barColor

    if joinedSlots and vertical then
      bottomInset = index == 1 and inset or 0
      topInset = index == count and inset or 0
    elseif joinedSlots then
      leftInset = index == 1 and inset or 0
      rightInset = index == count and inset or 0
    end

    local contentWidth = math_max(1, width - leftInset - rightInset)
    local contentHeight = math_max(1, height - bottomInset - topInset)

    if cfg.usePerSlotColors == true then
      local configured = cfg["chargeSlot" .. index .. "Color"]
      slotColor = CopyColor(configured, CHARGE_SLOT_DEFAULT_COLORS[index] or barColor)
      slotColor[4] = slotColor[4] * opacity
    end

    slot.slotIndex = index
    slot.contentWidth = contentWidth
    slot.contentHeight = contentHeight
    slot.contentInset = vertical and bottomInset or leftInset

    slot.frame:ClearAllPoints()
    slot.frame:SetSize(width, height)
    slot.frame:SetPoint("BOTTOMLEFT", parts.slotsContainer, "BOTTOMLEFT", vertical and 0 or offset, vertical and offset or 0)
    slot.frame:SetFrameLevel(parts.slotsContainer:GetFrameLevel() + 1)
    slot.frame:SetClipsChildren(true)

    slot.background:ClearAllPoints()
    slot.background:SetAllPoints(slot.frame)
    local slotBackground = CopyColor(background)
    slotBackground[4] = slotBackground[4] * opacity
    SetBackground(slot.background, slotBackground)
    slot.background:Show()

    slot.rechargeBar:SetParent(slot.frame)
    slot.rechargeBar:ClearAllPoints()
    slot.rechargeBar:SetSize(contentWidth, contentHeight)
    if vertical then
      slot.rechargeBar:SetPoint("BOTTOM", parts.chargeTrackerTexture, "TOP", 0, bottomInset)
    else
      slot.rechargeBar:SetPoint("LEFT", parts.chargeTrackerTexture, "RIGHT", leftInset, 0)
    end
    slot.rechargeBar:SetStatusBarTexture(texture)
    slot.rechargeBar:SetStatusBarColor(slotColor[1], slotColor[2], slotColor[3], slotColor[4])
    slot.rechargeBar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
    slot.rechargeBar:SetReverseFill(reverseFill)
    slot.rechargeBar:SetRotatesTexture(rotateTexture)
    slot.rechargeBar:SetFrameLevel(slot.frame:GetFrameLevel() + 1)

    slot.fullBar:SetParent(slot.frame)
    slot.fullBar:ClearAllPoints()
    slot.fullBar:SetSize(contentWidth, contentHeight)
    slot.fullBar:SetPoint("BOTTOMLEFT", slot.frame, "BOTTOMLEFT", leftInset, bottomInset)
    slot.fullBar:SetStatusBarTexture(texture)
    local resolvedFull = cfg.usePerSlotColors == true and cfg.useDifferentFullColor ~= true and slotColor or fullColor
    slot.fullBar:SetStatusBarColor(resolvedFull[1], resolvedFull[2], resolvedFull[3], resolvedFull[4])
    slot.fullBar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
    slot.fullBar:SetReverseFill(reverseFill)
    slot.fullBar:SetRotatesTexture(rotateTexture)
    slot.fullBar:SetFrameLevel(slot.frame:GetFrameLevel() + 2)
    slot.fullBar:SetMinMaxValues(index - 0.01, index)
    slot.fullBar:SetValue(0)

    slot.borderFrame:SetParent(parts.slotsContainer)
    slot.borderFrame:ClearAllPoints()
    slot.borderFrame:SetAllPoints(slot.frame)
    slot.borderFrame:SetFrameLevel(slot.frame:GetFrameLevel() + 3)

    local edges
    if joinedSlots and vertical then
      edges = {
        top = index == count,
        bottom = true,
        left = true,
        right = true,
        centerBottom = index > 1,
      }
    elseif joinedSlots then
      edges = {
        top = true,
        bottom = true,
        left = true,
        right = index == count,
        centerLeft = index > 1,
      }
    end

    ApplyTemplateBorder(slot.borderFrame, inset, borderColor, edges)
    slot.fullBar:Show()
    slot.frame:Show()
  end
end

function PCMPresentation.ApplyChargeCount(parts, currentCharges)
  if not parts or not parts.chargeTrackerBar then
    return
  end

  parts.chargeTrackerBar:SetValue(currentCharges)

  for index = 1, #(parts.chargeSlots or {}) do
    local slot = parts.chargeSlots[index]
    if slot and slot.fullBar then
      slot.fullBar:SetValue(currentCharges)
    end
  end
end

function PCMPresentation.AnchorChargeTimerText(parts, cfg, isRecharging)
  if not parts or not parts.timerTextContainer or not parts.slotsContainer then
    return
  end

  cfg = cfg or {}
  local container = parts.timerTextContainer
  local slots = parts.chargeSlots or {}
  local firstSlot = slots[1]
  local lastSlot = slots[#slots]

  container:ClearAllPoints()

  if cfg.dynamicTextOnSlot == false then
    container:SetAllPoints(parts.slotsContainer)
    return
  end

  if isRecharging and firstSlot and parts.chargeTrackerTexture then
    container:SetSize(firstSlot.contentWidth, firstSlot.contentHeight)
    if cfg.orientation == "vertical" then
      container:SetPoint("BOTTOM", parts.chargeTrackerTexture, "TOP", 0, firstSlot.contentInset or 0)
    else
      container:SetPoint("LEFT", parts.chargeTrackerTexture, "RIGHT", firstSlot.contentInset or 0, 0)
    end
    return
  end

  if lastSlot and lastSlot.fullBar then
    container:SetAllPoints(lastSlot.fullBar)
  else
    container:SetAllPoints(parts.slotsContainer)
  end
end

local PCMBarAdapter = {}

function PCMBarAdapter.Create(parent, context)
  context = context or {}
  if context.template == "charge" then
    return CreateChargeParts(parent, context)
  end
  return CreateDurationParts(parent, context)
end

function PCMBarAdapter.BindDataProvider(parts, provider)
  parts.provider = provider
end

function PCMBarAdapter.ApplyStyle(parts, state)
  if state.skipStyle == true then
    return
  end

  local cfg = state.config or {}

  if parts.kind == "charge" then
    ApplyFont(parts.valueText, state.font or cfg, "cooldown", 14)
    if parts.icon then
      IconSkin.StripIconMasks(parts.icon)
      IconSkin.MakeIconSquare(parts.icon, { crop = 0.08 })
    end
    return
  end

  local color = CopyColor(state.color or cfg.barColor or cfg.durationBarColor, { 0.28, 0.67, 0.95, 1 })
  local background = CopyColor(state.backgroundColor or cfg.backgroundColor or cfg.borderColor, { 0.12, 0.12, 0.12, 0.95 })
  local border = CopyColor(state.borderColor or cfg.borderColor, { 0.20, 0.20, 0.24, 1 })
  local borderSize = tonumber(state.borderSize or cfg.borderSize or cfg.borderThickness) or 2
  local textureKey = state.texture or cfg.texture or cfg.stackTexture or cfg.durationTexture or "Pleebar"

  if state.applyBackground ~= false then
    SetBackground(parts.background, background)
    parts.background:Show()
  end
  if parts.status then
    parts.status:SetStatusBarTexture(ResolveTexture(textureKey))
    parts.status:SetStatusBarColor(color[1], color[2], color[3], color[4])
  end
  if state.applyBorder ~= false then
    BarWidget.ApplyBorder(parts.barFrame, borderSize, border)
  end
  ApplyFont(parts.valueText, state.font or cfg, "cooldown", 14)
  ApplyFont(parts.label, state.labelFont or cfg, "tiny", 10)

  if parts.icon then
    IconSkin.StripIconMasks(parts.icon)
    IconSkin.MakeIconSquare(parts.icon, { crop = 0.08 })
  end
end

function PCMBarAdapter.ApplyGeometry(parts, state)
  if state.skipGeometry == true then
    return
  end

  local cfg = state.config or {}
  local minimumSize = Round(1)
  local width = math_max(minimumSize, Round(tonumber(state.width or cfg.width) or 240))
  local height = math_max(minimumSize, Round(tonumber(state.height or cfg.height) or 12))
  local vertical = cfg.orientation == "vertical"
  local showIcon = state.showIcon
  if showIcon == nil then
    showIcon = cfg.showIcon == true
  end
  local iconSize = showIcon
    and math_max(minimumSize, Round(tonumber(state.iconSize) or height))
    or 0

  if parts.kind == "charge" then
    if iconSize >= width then
      iconSize = math_max(1, width - 1)
    end

    local barSize = showIcon and math_max(1, width - iconSize) or width
    if vertical then
      parts.frame:SetSize(math_max(height, iconSize), width)
      parts.slotsContainer:SetSize(height, barSize)
    else
      parts.frame:SetSize(width, math_max(height, iconSize))
      parts.slotsContainer:SetSize(barSize, height)
    end

    parts.iconFrame:ClearAllPoints()
    parts.slotsContainer:ClearAllPoints()
    if showIcon then
      parts.iconFrame:SetSize(iconSize, iconSize)
      if vertical then
        parts.iconFrame:SetPoint("BOTTOM", parts.frame, "BOTTOM", 0, 0)
        parts.slotsContainer:SetPoint("BOTTOM", parts.iconFrame, "TOP", 0, 0)
      else
        parts.iconFrame:SetPoint("LEFT", parts.frame, "LEFT", 0, 0)
        parts.slotsContainer:SetPoint("LEFT", parts.iconFrame, "RIGHT", 0, 0)
      end
      parts.iconFrame:Show()
    else
      parts.iconFrame:Hide()
      if vertical then
        parts.slotsContainer:SetPoint("BOTTOM", parts.frame, "BOTTOM", 0, 0)
      else
        parts.slotsContainer:SetPoint("LEFT", parts.frame, "LEFT", 0, 0)
      end
    end

    LayoutChargeSlots(parts, state)

    parts.timerTextContainer:SetParent(parts.slotsContainer)
    PCMPresentation.AnchorChargeTimerText(parts, cfg, true)
    return
  end

  if iconSize >= width then
    iconSize = math_max(1, width - 1)
  end

  local barLength = showIcon and math_max(1, width - iconSize) or width
  if vertical then
    parts.frame:SetSize(math_max(height, iconSize), width)
    parts.barFrame:SetSize(height, barLength)
  else
    parts.frame:SetSize(width, math_max(height, iconSize))
    parts.barFrame:SetSize(barLength, height)
  end

  parts.barFrame:ClearAllPoints()
  parts.iconFrame:ClearAllPoints()

  if showIcon then
    local anchor = cfg.iconAnchor or (vertical and "top" or "left")
    parts.iconFrame:SetSize(iconSize, iconSize)

    if vertical then
      if anchor == "bottom" then
        parts.iconFrame:SetPoint("BOTTOM", parts.frame, "BOTTOM", 0, 0)
        parts.barFrame:SetPoint("BOTTOM", parts.iconFrame, "TOP", 0, 0)
      else
        parts.iconFrame:SetPoint("TOP", parts.frame, "TOP", 0, 0)
        parts.barFrame:SetPoint("TOP", parts.iconFrame, "BOTTOM", 0, 0)
      end
    elseif anchor == "right" then
      parts.iconFrame:SetPoint("RIGHT", parts.frame, "RIGHT", 0, 0)
      parts.barFrame:SetPoint("RIGHT", parts.iconFrame, "LEFT", 0, 0)
    else
      parts.iconFrame:SetPoint("LEFT", parts.frame, "LEFT", 0, 0)
      parts.barFrame:SetPoint("LEFT", parts.iconFrame, "RIGHT", 0, 0)
    end

    parts.icon:ClearAllPoints()
    parts.icon:SetAllPoints(parts.iconFrame)
    parts.iconFrame:Show()
    parts.icon:Show()
  else
    parts.iconFrame:Hide()
    parts.icon:Hide()
    parts.barFrame:SetAllPoints(parts.frame)
  end

  parts.status:ClearAllPoints()
  local borderSize = math_max(
    0,
    tonumber(state.borderSize or cfg.borderSize or cfg.borderThickness) or 2
  )
  local borderInset = borderSize * ns.FrameScale:BestOnePixel()
  parts.status:SetPoint("TOPLEFT", parts.barFrame, "TOPLEFT", borderInset, -borderInset)
  parts.status:SetPoint("BOTTOMRIGHT", parts.barFrame, "BOTTOMRIGHT", -borderInset, borderInset)
  parts.status:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")

  local direction = tostring(
    cfg.fillDirection or (vertical and "UP" or "RIGHT")
  ):lower()
  parts.status:SetReverseFill(vertical and direction ~= "up" or not vertical and direction == "left")

  parts.valueText:ClearAllPoints()
  parts.valueText:SetPoint("CENTER", parts.barFrame, "CENTER", 0, 0)
  parts.label:ClearAllPoints()
  parts.label:SetPoint("RIGHT", parts.frame, "LEFT", -6, 0)
end

function PCMBarAdapter.ApplyVisibility(parts, state)
  if state.skipVisibility == true then
    return
  end

  local visible = state.visible ~= false and not (state.config and state.config.enabled == false)
  parts.frame:SetShown(visible)
  if not visible then
    return
  end

  parts.frame:SetAlpha(tonumber(state.alpha) or 1)

  local provider = parts.provider
  local iconTexture = Presentation.Read(provider, "icon", nil, parts, state)
  if iconTexture and parts.icon then
    parts.icon:SetTexture(iconTexture)
  end

  local minimum = tonumber(Presentation.Read(provider, "minimum", 0, parts, state)) or 0
  local maximum = tonumber(Presentation.Read(provider, "maximum", 1, parts, state)) or 1
  local value = tonumber(Presentation.Read(provider, "value", maximum, parts, state)) or maximum
  if parts.status then
    parts.status:SetMinMaxValues(minimum, maximum)
    parts.status:SetValue(value)
  end

  if parts.valueText then
    parts.valueText:SetText(Presentation.Read(provider, "text", "", parts, state) or "")
    parts.valueText:SetShown(state.showText ~= false)
  end

  if parts.label then
    local label = Presentation.Read(provider, "label", nil, parts, state)
    parts.label:SetText(label or "")
    parts.label:SetShown(label ~= nil and label ~= "")
  end
end

function PCMBarAdapter.Release(parts)
  parts.provider = nil
  parts.frame:Hide()
  parts.frame:ClearAllPoints()
end

local PCMIconAdapter = {}

function PCMIconAdapter.Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  local background = frame:CreateTexture(nil, "BACKGROUND")
  local icon = frame:CreateTexture(nil, "ARTWORK")
  local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  local cooldownText = cooldown:CreateFontString(nil, "OVERLAY")
  local chargeText = frame:CreateFontString(nil, "OVERLAY")
  local keybindHolder = CreateFrame("Frame", nil, frame)
  local keybindText = keybindHolder:CreateFontString(nil, "OVERLAY")
  local glow = frame:CreateTexture(nil, "OVERLAY", nil, 5)
  local qualityHolder = CreateFrame("Frame", nil, frame)
  local qualityTexture = qualityHolder:CreateTexture(nil, "OVERLAY", nil, 7)

  background:SetAllPoints(frame)
  icon:SetAllPoints(frame)
  cooldown:SetAllPoints(icon)
  cooldown:SetDrawBling(false)
  cooldown:SetDrawEdge(false)
  cooldown:SetHideCountdownNumbers(true)
  cooldown:SetSwipeColor(0, 0, 0, 0.72)
  cooldown:SetSwipeTexture(WHITE_TEXTURE)
  IconSkin.SquareCooldown(cooldown)

  cooldownText:SetPoint("CENTER", frame, "CENTER", 0, 0)
  chargeText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
  keybindText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
  keybindHolder:SetAllPoints(frame)
  keybindHolder:EnableMouse(false)
  glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
  glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
  glow:SetTexture(WHITE_TEXTURE)
  glow:SetBlendMode("ADD")
  glow:Hide()
  qualityHolder:SetAllPoints(frame)
  qualityHolder:EnableMouse(false)
  qualityHolder:Hide()

  return {
    frame = frame,
    background = background,
    icon = icon,
    cooldown = cooldown,
    cooldownText = cooldownText,
    chargeText = chargeText,
    keybindHolder = keybindHolder,
    keybindText = keybindText,
    glow = glow,
    qualityHolder = qualityHolder,
    qualityTexture = qualityTexture,
  }
end

function PCMIconAdapter.BindDataProvider(parts, provider)
  parts.provider = provider
end

function PCMIconAdapter.ApplyStyle(parts, state)
  local size = math_max(Round(1), Round(tonumber(state.size) or 36))
  local inset = math_max(0, Round(tonumber(state.inset) or 0))
  local background = CopyColor(state.backgroundColor, { 0.03, 0.03, 0.04, 1 })
  local border = CopyColor(state.borderColor, { 0.10, 0.10, 0.12, 1 })
  local borderSize = math_max(0, tonumber(state.borderSize) or 2)

  if state.manageFrameSize ~= false then
    parts.frame:SetSize(size, size)
  end
  SetBackground(parts.background, background)
  BarWidget.ApplyBorder(parts.borderFrame or parts.frame, borderSize, border)

  parts.icon:ClearAllPoints()
  parts.icon:SetPoint("TOPLEFT", parts.frame, "TOPLEFT", inset, -inset)
  parts.icon:SetPoint("BOTTOMRIGHT", parts.frame, "BOTTOMRIGHT", -inset, inset)
  IconSkin.StripIconMasks(parts.icon)
  IconSkin.MakeIconSquare(parts.icon, { crop = 0.08 })

  if parts.cooldown then
    parts.cooldown:ClearAllPoints()
    parts.cooldown:SetAllPoints(parts.icon)
    IconSkin.SquareCooldown(parts.cooldown)
  end

  ApplyFont(parts.cooldownText, state.cooldownFont, "cooldown", 11)
  ApplyFont(parts.chargeText, state.chargeFont, "tiny", 10)
  ApplyFont(parts.keybindText, state.keybindFont, "tiny", 8)

  if parts.keybindHolder then
    parts.keybindHolder:SetFrameLevel(parts.frame:GetFrameLevel() + 12)
  end

  if parts.qualityHolder then
    parts.qualityHolder:SetFrameLevel(parts.frame:GetFrameLevel() + 2)
    parts.qualityTexture:ClearAllPoints()
    local qualityOffset = Round(size * 11 / 36)
    parts.qualityTexture:SetPoint("CENTER", parts.qualityHolder, "TOPLEFT", qualityOffset, -qualityOffset)
    parts.qualityTexture:SetScale(size / 36)
  end
end

function PCMIconAdapter.ApplyGeometry() end

function PCMIconAdapter.ApplyVisibility(parts, state)
  if state.skipVisibility == true then
    return
  end

  local provider = parts.provider
  local visible = state.visible ~= false
  parts.frame:SetShown(visible)
  if not visible then
    return
  end

  local texture = Presentation.Read(provider, "icon", nil, parts, state)
  if texture then
    parts.icon:SetTexture(texture)
  end
  if parts.cooldownText then
    parts.cooldownText:SetText(Presentation.Read(provider, "cooldownText", "", parts, state) or "")
  end
  if parts.chargeText then
    parts.chargeText:SetText(Presentation.Read(provider, "chargeText", "", parts, state) or "")
  end
  if parts.keybindText then
    parts.keybindText:SetText(Presentation.Read(provider, "keybindText", "", parts, state) or "")
  end
  if parts.glow then
    parts.glow:SetShown(Presentation.Read(provider, "glow", false, parts, state) == true)
  end
  if parts.qualityHolder then
    local qualityAtlas = Presentation.Read(provider, "qualityAtlas", nil, parts, state)
    if qualityAtlas then
      parts.qualityTexture:SetAtlas(qualityAtlas, true)
      parts.qualityHolder:Show()
    else
      parts.qualityHolder:Hide()
    end
  end
end

function PCMIconAdapter.Release(parts)
  parts.provider = nil
  parts.frame:Hide()
  parts.frame:ClearAllPoints()
end

local CustomBarBuffGlowTracks = {}
local CustomBarBuffGlowTrackPool = {}
local CustomBarBuffGlowPending = {}
local CustomBarBuffGlowEventFrame = CreateFrame("Frame")
local CustomTrackerStateGlows = {}
local CUSTOM_TRACKER_STATE_GLOW_KEY = "PUI_CustomTrackerState"
local CUSTOM_TRACKER_ACTIVE_AURA_GLOW_KEY = "PUI_CustomTrackerActiveAura"

local function StopCustomTrackerStateGlow(trackKey)
  local state = CustomTrackerStateGlows[trackKey]
  if not state then return end
  if state.style == "PIXEL" then
    LCG.PixelGlow_Stop(state.frame, CUSTOM_TRACKER_STATE_GLOW_KEY)
  elseif state.style == "AUTOCAST" then
    LCG.AutoCastGlow_Stop(state.frame, CUSTOM_TRACKER_STATE_GLOW_KEY)
  elseif state.style == "PROC" then
    LCG.ProcGlow_Stop(state.frame, CUSTOM_TRACKER_STATE_GLOW_KEY)
  end
  CustomTrackerStateGlows[trackKey] = nil
end

function PCMPresentation.ApplyCustomTrackerStateGlow(trackKey, targetFrame, style, color)
  trackKey = tostring(trackKey)
  color = type(color) == "table" and color or nil
  local r = color and tonumber(color[1] or color.r) or 1
  local g = color and tonumber(color[2] or color.g) or 1
  local b = color and tonumber(color[3] or color.b) or 1
  local a = color and tonumber(color[4] or color.a) or 1
  local state = CustomTrackerStateGlows[trackKey]
  if state
    and state.frame == targetFrame
    and state.style == style
    and state.r == r
    and state.g == g
    and state.b == b
    and state.a == a
  then
    return
  end

  StopCustomTrackerStateGlow(trackKey)
  if not targetFrame or style == nil or style == "NONE" then return end
  local glowColor = { r, g, b, a }
  if style == "PIXEL" then
    LCG.PixelGlow_Start(targetFrame, glowColor, 8, 0.25, nil, 2, 0, 0, true, CUSTOM_TRACKER_STATE_GLOW_KEY, 8)
  elseif style == "AUTOCAST" then
    LCG.AutoCastGlow_Start(targetFrame, glowColor, 8, 0.25, 1, 0, 0, CUSTOM_TRACKER_STATE_GLOW_KEY, 8)
  elseif style == "PROC" then
    LCG.ProcGlow_Start(targetFrame, {
      key = CUSTOM_TRACKER_STATE_GLOW_KEY,
      color = glowColor,
      startAnim = true,
      xOffset = 0,
      yOffset = 0,
      duration = 1,
      frameLevel = 8,
    })
  else
    return
  end
  CustomTrackerStateGlows[trackKey] = {
    frame = targetFrame,
    style = style,
    r = r,
    g = g,
    b = b,
    a = a,
  }
end

function PCMPresentation.ReleaseCustomTrackerStateGlow(trackKey)
  StopCustomTrackerStateGlow(tostring(trackKey))
end

local function StopCustomTrackerActiveAuraGlow(track)
  local target = track and track.activeAuraGlowTarget
  if not target then
    if track then track.activeAuraGlowStyle = nil end
    return
  end
  if track.activeAuraGlowStyle == "PIXEL" then
    LCG.PixelGlow_Stop(target, CUSTOM_TRACKER_ACTIVE_AURA_GLOW_KEY)
  elseif track.activeAuraGlowStyle == "AUTOCAST" then
    LCG.AutoCastGlow_Stop(target, CUSTOM_TRACKER_ACTIVE_AURA_GLOW_KEY)
  elseif track.activeAuraGlowStyle == "PROC" then
    LCG.ProcGlow_Stop(target, CUSTOM_TRACKER_ACTIVE_AURA_GLOW_KEY)
  end
  track.activeAuraGlowStyle = nil
end

local function ApplyCustomTrackerActiveAuraGlow(track, style, color)
  StopCustomTrackerActiveAuraGlow(track)
  local target = track.activeAuraGlowTarget
  if not target or style == nil or style == "NONE" then return end
  color = CopyColor(color, { 1, 0.55, 0.1, 1 })
  if style == "PIXEL" then
    LCG.PixelGlow_Start(
      target,
      color,
      8,
      0.25,
      nil,
      2,
      0,
      0,
      true,
      CUSTOM_TRACKER_ACTIVE_AURA_GLOW_KEY,
      8
    )
  elseif style == "AUTOCAST" then
    LCG.AutoCastGlow_Start(
      target,
      color,
      8,
      0.25,
      1,
      0,
      0,
      CUSTOM_TRACKER_ACTIVE_AURA_GLOW_KEY,
      8
    )
  elseif style == "PROC" then
    LCG.ProcGlow_Start(target, {
      key = CUSTOM_TRACKER_ACTIVE_AURA_GLOW_KEY,
      color = color,
      startAnim = true,
      xOffset = 0,
      yOffset = 0,
      duration = 1,
      frameLevel = 8,
    })
  else
    return
  end
  track.activeAuraGlowStyle = style
end

local function CustomBarBuffGlowRestyleLocked()
  return C_Secrets.ShouldAurasBeSecret() == true
end

local function CreateCustomBarBuffGlowBorder(button)
  local function CreateEdge()
    local edge = button:CreateTexture(nil, "OVERLAY", nil, 7)
    edge:SetBlendMode("ADD")
    return edge
  end

  return {
    top = CreateEdge(),
    bottom = CreateEdge(),
    left = CreateEdge(),
    right = CreateEdge(),
  }
end

local function ConfigureCustomBarBuffGlowBorder(border, button, cfg, scale)
  if not border or not button or not cfg then
    return
  end

  local thickness = tonumber(cfg.buffGlowThickness) or 2
  thickness = math_floor(thickness + 0.5)
  if thickness < 1 then
    thickness = 1
  elseif thickness > 8 then
    thickness = 8
  end

  thickness = thickness * math_max(0.01, tonumber(scale) or 1)
  local offset = thickness

  border.top:ClearAllPoints()
  border.top:SetHeight(thickness)
  border.top:SetPoint("TOPLEFT", button, "TOPLEFT", -offset, offset)
  border.top:SetPoint("TOPRIGHT", button, "TOPRIGHT", offset, offset)

  border.bottom:ClearAllPoints()
  border.bottom:SetHeight(thickness)
  border.bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -offset, -offset)
  border.bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", offset, -offset)

  border.left:ClearAllPoints()
  border.left:SetWidth(thickness)
  border.left:SetPoint("TOPLEFT", border.top, "BOTTOMLEFT", 0, 0)
  border.left:SetPoint("BOTTOMLEFT", border.bottom, "TOPLEFT", 0, 0)

  border.right:ClearAllPoints()
  border.right:SetWidth(thickness)
  border.right:SetPoint("TOPRIGHT", border.top, "BOTTOMRIGHT", 0, 0)
  border.right:SetPoint("BOTTOMRIGHT", border.bottom, "TOPRIGHT", 0, 0)

  local color = cfg.buffGlowEnabled == true and cfg.buffGlowColor
    or cfg.activeGlowColor
    or { 0.25, 0.75, 1, 1 }
  local r = tonumber(color[1] or color.r) or 0.25
  local g = tonumber(color[2] or color.g) or 0.75
  local b = tonumber(color[3] or color.b) or 1
  local a = tonumber(color[4] or color.a) or 1

  border.top:SetColorTexture(r, g, b, a)
  border.bottom:SetColorTexture(r, g, b, a)
  border.left:SetColorTexture(r, g, b, a)
  border.right:SetColorTexture(r, g, b, a)
end

function PCMPresentation.CreateCustomBarBuffGlowBorder(frame)
  if not frame then
    return nil
  end

  return CreateCustomBarBuffGlowBorder(frame)
end

function PCMPresentation.ConfigureCustomBarBuffGlowBorder(border, frame, cfg, scale)
  ConfigureCustomBarBuffGlowBorder(border, frame, cfg, scale)
end

local function ConfigureCustomBarBuffGlowButton(track, initializing)
  if initializing ~= true and CustomBarBuffGlowRestyleLocked() then
    track.stylePending = true
    return false
  end

  track.stylePending = nil

  local button = track.button
  local anchorFrame = track.anchorFrame
  if not button or not anchorFrame then
    return false
  end

  button:ClearAllPoints()
  button:SetAllPoints(anchorFrame)
  button:SetFrameStrata(anchorFrame:GetFrameStrata())
  button:SetFrameLevel(anchorFrame:GetFrameLevel() + 6)
  button:EnableMouse(false)
  if not track.activeAuraGlowTarget then
    track.activeAuraGlowTarget = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
    track.activeAuraGlowTarget:SetAllPoints(button)
    track.activeAuraGlowTarget:EnableMouse(false)
  end
  track.activeAuraGlowTarget:SetFrameLevel(button:GetFrameLevel() + 8)

  local cfg = track.config
  local auraTracker = cfg and (cfg.kind == "duration" or cfg.kind == "stack")
  local showActiveBar = cfg and cfg.presentation == "BAR" and not auraTracker
    and cfg.activeAuraEnabled == true
  local showActiveBarGlow = cfg and cfg.presentation == "BAR"
    and cfg.activeAuraEnabled == true
  local buttonAlpha = 1
  if showActiveBar then
    track.auraParts = track.auraParts or {}
    AuraWidget.BindApplicationDurationButton(button, track.auraParts)
    AuraWidget.DisableIcon(track.auraParts)
    AuraWidget.DisableDurationCooldown(track.auraParts)
    AuraWidget.ConfigureDurationBar(
      track.auraParts,
      Enum.StatusBarInterpolation.None,
      Enum.StatusBarTimerDirection.RemainingTime
    )
    track.auraParts.durationBar:ClearAllPoints()
    track.auraParts.durationBar:SetAllPoints(button)
    track.auraParts.durationBar:SetStatusBarTexture(
      LSM:Fetch("statusbar", cfg.texture or "Pleebar", true) or FALLBACK_BAR_TEXTURE
    )
    local activeColor = CopyColor(cfg.barColor, { 0.25, 0.75, 1, 1 })
    track.auraParts.durationBar:SetStatusBarColor(
      activeColor[1], activeColor[2], activeColor[3], activeColor[4]
    )
    track.auraParts.durationBar:GetStatusBarTexture():SetDesaturated(cfg.desaturateActive == true)
    buttonAlpha = (tonumber(cfg.activeAlpha) or 100) / 100
  else
    if track.auraParts then
      AuraWidget.DisableIcon(track.auraParts)
      AuraWidget.DisableDurationCooldown(track.auraParts)
      AuraWidget.DisableDurationBar(track.auraParts)
    end
  end

  track.buttonBaseAlpha = buttonAlpha
  button:SetAlpha(buttonAlpha * (track.contextAlpha or 1))

  local activeGlowStyle = showActiveBarGlow and cfg.activeGlowStyle or "NONE"
  local activeGlowColor = showActiveBarGlow and cfg.activeGlowColor or nil
  ApplyCustomTrackerActiveAuraGlow(track, activeGlowStyle, activeGlowColor)

  ConfigureCustomBarBuffGlowBorder(track.cueBorder, button, track.config)
  local showBorder = cfg and cfg.buffGlowEnabled == true and activeGlowStyle == "NONE"
  track.cueBorder.top:SetShown(showBorder)
  track.cueBorder.bottom:SetShown(showBorder)
  track.cueBorder.left:SetShown(showBorder)
  track.cueBorder.right:SetShown(showBorder)
  return true
end

local function ResolveCustomBarBuffGlowSpellIDs(track)
  local cfg = track.config
  local spellID = tonumber(track.spellID)
  if not cfg or not spellID or spellID <= 0 then
    return nil
  end

  if cfg.buffGlowSource == "CUSTOM" then
    return {
      [spellID] = true,
    }
  end

  local _, spellIDs = ns.Modules.CooldownManager:ResolveCustomBarAuraEntry(spellID)
  return spellIDs
end

local function CustomBarBuffGlowSpellSetsMatch(left, right)
  if left == right then
    return true
  end
  if type(left) ~= "table" or type(right) ~= "table" then
    return false
  end

  for spellID in pairs(left) do
    if right[spellID] ~= true then
      return false
    end
  end
  for spellID in pairs(right) do
    if left[spellID] ~= true then
      return false
    end
  end
  return true
end

local function ApplyCustomBarBuffGlowTrack(track)
  local spellID = tonumber(track.spellID)
  if track.enabled ~= true or not track.anchorFrame or not spellID or spellID <= 0 then
    if track.auraSlot then
      AuraSlotDriver:SetSlotActive(track.auraSlot, false)
    end
    return
  end

  local spellIDs = ResolveCustomBarBuffGlowSpellIDs(track)
  if type(spellIDs) ~= "table" or next(spellIDs) == nil then
    if track.auraSlot then
      AuraSlotDriver:SetSlotActive(track.auraSlot, false)
    end
    return
  end

  if not track.auraSlot then
    track.auraSlot = AuraSlotDriver:CreateSlot("player", "HELPFUL|PLAYER", {
      candidateFilters = {
        includeSpellIDs = spellIDs,
      },
      templateNames = { "PUI_AuraApplicationDurationTemplate" },
      initializeFrame = function(button)
        track.button = button
        track.cueBorder = CreateCustomBarBuffGlowBorder(button)
        ConfigureCustomBarBuffGlowButton(track, true)
      end,
    })
    track.candidateSpellIDs = spellIDs
  else
    if track.auraSlot.active ~= true
      or not CustomBarBuffGlowSpellSetsMatch(track.candidateSpellIDs, spellIDs)
    then
      AuraSlotDriver:SetSlotCandidates(track.auraSlot, {
        includeSpellIDs = spellIDs,
      })
      track.candidateSpellIDs = spellIDs
    end
    ConfigureCustomBarBuffGlowButton(track, false)
  end

  AuraSlotDriver:SetSlotActive(track.auraSlot, true)
end

local function StopCustomBarBuffGlowPendingEvents()
  if next(CustomBarBuffGlowPending) then
    return
  end

  CustomBarBuffGlowEventFrame:UnregisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
end

local function QueueCustomBarBuffGlow(trackKey)
  CustomBarBuffGlowPending[trackKey] = true
  CustomBarBuffGlowEventFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
end

local function FlushCustomBarBuffGlows()
  if CustomBarBuffGlowRestyleLocked() then
    return
  end

  for trackKey in pairs(CustomBarBuffGlowPending) do
    local track = CustomBarBuffGlowTracks[trackKey]
    if track and track.stylePending then
      ConfigureCustomBarBuffGlowButton(track, false)
    end
    CustomBarBuffGlowPending[trackKey] = nil
  end

  StopCustomBarBuffGlowPendingEvents()
end

CustomBarBuffGlowEventFrame:SetScript("OnEvent", FlushCustomBarBuffGlows)

function PCMPresentation.ConfigureCustomBarBuffGlow(trackKey, targetFrame, cfg)
  if trackKey == nil then
    return
  end

  trackKey = tostring(trackKey)
  local track = CustomBarBuffGlowTracks[trackKey]
  if not track then
    track = table.remove(CustomBarBuffGlowTrackPool) or {}
    CustomBarBuffGlowTracks[trackKey] = track
  end

  track.anchorFrame = targetFrame
  track.config = cfg
  track.contextAlpha = 1
  local auraTracker = cfg and (cfg.kind == "duration" or cfg.kind == "stack")
  local activeBarEnabled = cfg and cfg.presentation == "BAR" and not auraTracker
    and cfg.activeAuraEnabled == true
  local barCueEnabled = cfg and cfg.presentation == "BAR" and cfg.buffGlowEnabled == true
  track.enabled = barCueEnabled or activeBarEnabled
  track.spellID = cfg and tonumber(
    cfg.buffGlowSpellID or (activeBarEnabled or barCueEnabled) and cfg.trackedSpellID
  ) or nil

  ApplyCustomBarBuffGlowTrack(track)

  if track.stylePending then
    QueueCustomBarBuffGlow(trackKey)
  else
    CustomBarBuffGlowPending[trackKey] = nil
    StopCustomBarBuffGlowPendingEvents()
  end
end

function PCMPresentation.SetCustomBarBuffGlowContextAlpha(trackKey, alpha)
  if trackKey == nil then
    return
  end

  trackKey = tostring(trackKey)
  local track = CustomBarBuffGlowTracks[trackKey]
  if not track then
    return
  end

  track.contextAlpha = tonumber(alpha) or 1
  if track.contextAlpha < 0 then track.contextAlpha = 0 end
  if track.contextAlpha > 1 then track.contextAlpha = 1 end

  if not track.button then
    return
  end

  if CustomBarBuffGlowRestyleLocked() then
    track.stylePending = true
    QueueCustomBarBuffGlow(trackKey)
    return
  end

  track.button:SetAlpha((track.buttonBaseAlpha or 1) * track.contextAlpha)
end

function PCMPresentation.RefreshCustomBarBuffGlowStyle(trackKey, cfg)
  if trackKey == nil then
    return
  end

  trackKey = tostring(trackKey)
  local track = CustomBarBuffGlowTracks[trackKey]
  if not track then
    return
  end

  track.config = cfg or track.config

  if not ConfigureCustomBarBuffGlowButton(track, false) then
    QueueCustomBarBuffGlow(trackKey)
    return
  end

  CustomBarBuffGlowPending[trackKey] = nil
  StopCustomBarBuffGlowPendingEvents()
end

function PCMPresentation.DisableCustomBarBuffGlow(trackKey)
  if trackKey == nil then
    return
  end

  trackKey = tostring(trackKey)
  local track = CustomBarBuffGlowTracks[trackKey]
  if not track then
    return
  end

  track.enabled = false
  StopCustomTrackerActiveAuraGlow(track)
  track.stylePending = nil
  CustomBarBuffGlowPending[trackKey] = nil
  ApplyCustomBarBuffGlowTrack(track)
  StopCustomBarBuffGlowPendingEvents()
end

function PCMPresentation.ReleaseCustomBarBuffGlow(trackKey)
  if trackKey == nil then
    return
  end

  trackKey = tostring(trackKey)
  local track = CustomBarBuffGlowTracks[trackKey]
  if not track then
    return
  end

  track.enabled = false
  StopCustomTrackerActiveAuraGlow(track)
  track.stylePending = nil
  CustomBarBuffGlowPending[trackKey] = nil
  ApplyCustomBarBuffGlowTrack(track)

  track.anchorFrame = nil
  track.config = nil
  track.spellID = nil
  track.candidateSpellIDs = nil
  track.contextAlpha = nil
  track.buttonBaseAlpha = nil
  CustomBarBuffGlowTracks[trackKey] = nil
  CustomBarBuffGlowTrackPool[#CustomBarBuffGlowTrackPool + 1] = track
  StopCustomBarBuffGlowPendingEvents()
end

function PCMPresentation.BindViewerIcon(itemFrame, regions, borderFrame)
  local parts = itemFrame.__puiPCMIconPresentation
  if not parts then
    parts = {
      owner = itemFrame,
      frame = regions and regions.iconContainer or itemFrame,
      borderFrame = borderFrame or itemFrame,
      icon = regions and regions.icon,
      cooldown = regions and regions.cd,
    }
    itemFrame.__puiPCMIconPresentation = parts
  else
    parts.owner = itemFrame
    parts.frame = regions and regions.iconContainer or itemFrame
    parts.borderFrame = borderFrame or parts.borderFrame or itemFrame
    parts.icon = regions and regions.icon or parts.icon
    parts.cooldown = regions and regions.cd or parts.cooldown
  end

  parts.__puiPresentationKey = "PCMIcon"
  return parts
end

function PCMPresentation.LayoutStackSegments(parts, state)
  local cfg = state.config or {}
  local count = math_max(1, math_floor(tonumber(state.maxStacks or cfg.maxStacks) or 3))
  local segments = EnsureStackSegments(parts, count)
  local vertical = cfg.orientation == "vertical"
  local gap = math_max(0, tonumber(state.gap or cfg.segmentGap) or 1)
  local width = math_max(1, parts.status:GetWidth())
  local height = math_max(1, parts.status:GetHeight())
  local totalSize = vertical and height or width
  local usableSize = math_max(count, totalSize - gap * (count - 1))
  local span = usableSize / count
  local texture = ResolveTexture(cfg.stackTexture or "Pleebar")
  local color = CopyColor(state.color or cfg.barColor, { 0.74, 0.48, 0.92, 1 })

  for index = 1, count do
    local segment = segments[index]
    local offset = (index - 1) * (span + gap)
    segment:ClearAllPoints()

    if vertical then
      segment:SetPoint("BOTTOMLEFT", parts.status, "BOTTOMLEFT", 0, offset)
      segment:SetPoint("BOTTOMRIGHT", parts.status, "BOTTOMRIGHT", 0, offset)
      segment:SetHeight(math_max(1, span))
    else
      segment:SetPoint("TOPLEFT", parts.status, "TOPLEFT", offset, 0)
      segment:SetPoint("BOTTOMLEFT", parts.status, "BOTTOMLEFT", offset, 0)
      segment:SetWidth(math_max(1, span))
    end

    segment:SetStatusBarTexture(texture)
    segment:SetStatusBarColor(color[1], color[2], color[3], color[4])
    segment:SetMinMaxValues(0, 1)
    segment:SetValue(0)
    segment:Show()
  end

  parts.status:SetMinMaxValues(0, 1)
  parts.status:SetValue(0)
  parts.maxStacks = count
  parts.stackReverse = vertical
      and tostring(cfg.fillDirection or "UP"):upper() == "DOWN"
    or not vertical
      and tostring(cfg.fillDirection or "RIGHT"):upper() == "LEFT"

  return segments
end

function PCMPresentation.BindCustomBar(frame)
  local parts = frame.__puiPCMBarPresentation
  if parts then
    parts.background = frame.bg
    parts.status = frame.bar
    parts.valueText = frame.text
    parts.iconFrame = frame.spellIconFrame
    parts.icon = frame.spellIconTex
    parts.stackSegments = frame.stackSegments or parts.stackSegments or {}
    return parts
  end

  parts = {
    frame = frame,
    barFrame = frame,
    background = frame.bg,
    status = frame.bar,
    valueTextFrame = frame,
    valueText = frame.text,
    label = frame.tickText,
    iconFrame = frame.spellIconFrame,
    icon = frame.spellIconTex,
    stackSegments = frame.stackSegments or {},
    chargeSlots = {},
    kind = frame.__puiIsDurationOnly and "duration" or "stack",
  }
  parts.__puiPresentationKey = "PCMBar"
  frame.__puiPCMBarPresentation = parts
  return parts
end

function PCMPresentation.BindDurationFrame(frame, state)
  state = BarWidget.BindDurationBarFrame(frame, state or {})
  state.kind = state.kind or "duration"
  state.status = state.cooldownBar
  state.background = state.bg
  state.valueTextFrame = state.textFrame
  state.valueText = state.text
  state.stackSegments = state.stackSegments or {}
  state.chargeSlots = state.chargeSlots or {}
  state.label = state.label or frame:CreateFontString(nil, "OVERLAY")
  return state
end

function PCMPresentation.BindChargeFrame(frame, state)
  state = BarWidget.BindChargeBarFrame(frame, state or {})
  state.kind = "charge"
  state.chargeRoot = state.slotsContainer
  state.valueTextFrame = state.timerTextContainer
  state.valueText = state.timerText
  state.chargeSlots = state.chargeSlots or {}
  state.chargeSlotPool = state.chargeSlotPool or {}
  state.stackSegments = state.stackSegments or {}
  return state
end

Presentation.Register("PCMBar", PCMBarAdapter)
Presentation.Register("PCMIcon", PCMIconAdapter)

local P = select(1, ns.Pleebug:DropIn(PCMPresentation, { name = "PCM.Presentation" }))
PCMPresentation.BindViewerIcon = P:Def("PCMPresentation.BindViewerIcon", PCMPresentation.BindViewerIcon)
PCMPresentation.EnsureStackSegments = P:Def("PCMPresentation.EnsureStackSegments", EnsureStackSegments)
PCMPresentation.LayoutStackSegments = P:Def("PCMPresentation.LayoutStackSegments", PCMPresentation.LayoutStackSegments)
PCMPresentation.EnsureChargeSlots = P:Def("PCMPresentation.EnsureChargeSlots", EnsureChargeSlots)
PCMPresentation.LayoutChargeSlots = P:Def("PCMPresentation.LayoutChargeSlots", LayoutChargeSlots)
PCMPresentation.ApplyChargeCount = P:Def("PCMPresentation.ApplyChargeCount", PCMPresentation.ApplyChargeCount)
PCMPresentation.AnchorChargeTimerText = P:Def("PCMPresentation.AnchorChargeTimerText", PCMPresentation.AnchorChargeTimerText)
PCMPresentation.BindCustomBar = P:Def("PCMPresentation.BindCustomBar", PCMPresentation.BindCustomBar)
PCMPresentation.BindDurationFrame = P:Def("PCMPresentation.BindDurationFrame", PCMPresentation.BindDurationFrame)
PCMPresentation.BindChargeFrame = P:Def("PCMPresentation.BindChargeFrame", PCMPresentation.BindChargeFrame)
PCMPresentation.CreateCustomBarBuffGlowBorder = P:Def("PCMPresentation.CreateCustomBarBuffGlowBorder", PCMPresentation.CreateCustomBarBuffGlowBorder)
PCMPresentation.ConfigureCustomBarBuffGlowBorder = P:Def("PCMPresentation.ConfigureCustomBarBuffGlowBorder", PCMPresentation.ConfigureCustomBarBuffGlowBorder)
PCMPresentation.ConfigureCustomBarBuffGlow = P:Def("PCMPresentation.ConfigureCustomBarBuffGlow", PCMPresentation.ConfigureCustomBarBuffGlow)
PCMPresentation.RefreshCustomBarBuffGlowStyle = P:Def("PCMPresentation.RefreshCustomBarBuffGlowStyle", PCMPresentation.RefreshCustomBarBuffGlowStyle)
PCMPresentation.DisableCustomBarBuffGlow = P:Def("PCMPresentation.DisableCustomBarBuffGlow", PCMPresentation.DisableCustomBarBuffGlow)
PCMPresentation.ReleaseCustomBarBuffGlow = P:Def("PCMPresentation.ReleaseCustomBarBuffGlow", PCMPresentation.ReleaseCustomBarBuffGlow)
PCMPresentation.ApplyCustomTrackerStateGlow = P:Def("PCMPresentation.ApplyCustomTrackerStateGlow", PCMPresentation.ApplyCustomTrackerStateGlow)
PCMPresentation.ReleaseCustomTrackerStateGlow = P:Def("PCMPresentation.ReleaseCustomTrackerStateGlow", PCMPresentation.ReleaseCustomTrackerStateGlow)
PCMPresentation.SetCustomBarBuffGlowContextAlpha = P:Def("PCMPresentation.SetCustomBarBuffGlowContextAlpha", PCMPresentation.SetCustomBarBuffGlowContextAlpha)
