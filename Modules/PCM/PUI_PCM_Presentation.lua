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
local C_DurationUtil = C_DurationUtil
local C_Secrets = C_Secrets
local issecretvalue = issecretvalue
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
local OWNED_PROC_GLOW_KEY = "PUI_PCM_OwnedProcGlow"

local CustomBarPresentation = setmetatable({}, { __mode = "k" })

local function ApplyRuntimeRootLayer(frame, parent)
  if parent == UIParent then
    frame:SetFrameStrata("LOW")
    frame:SetFrameLevel(1)
  end
end

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

  if type(color) == "table" then
    texture:SetColorTexture(
      tonumber(color[1] or color.r) or 1,
      tonumber(color[2] or color.g) or 1,
      tonumber(color[3] or color.b) or 1,
      tonumber(color[4] or color.a) or 1
    )
    return
  end

  texture:SetColorTexture(0.12, 0.12, 0.12, 0.95)
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

  local owner = parent or UIParent
  local frame = CreateFrame("Frame", name, owner, "PUI_DurationBarTemplate")
  ApplyRuntimeRootLayer(frame, owner)
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

  local owner = parent or UIParent
  local frame = CreateFrame("Frame", name, owner, "PUI_ChargeBarTemplate")
  ApplyRuntimeRootLayer(frame, owner)
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
  local texture = BarWidget.ResolveStatusBarTexture(cfg.texture or "Pleebar", FALLBACK_BAR_TEXTURE)
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
  local inset = borderSize * ns.Pixel.GetOnePixel()
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
    parts.status:SetStatusBarTexture(BarWidget.ResolveStatusBarTexture(textureKey, FALLBACK_BAR_TEXTURE))
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
  local borderInset = borderSize * ns.Pixel.GetOnePixel()
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
  ApplyRuntimeRootLayer(frame, parent)
  local background = frame:CreateTexture(nil, "BACKGROUND")
  local icon = frame:CreateTexture(nil, "ARTWORK")
  local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  local chargeCooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  local cooldownText = cooldown:CreateFontString(nil, "OVERLAY")
  local chargeHolder = CreateFrame("Frame", nil, frame)
  local chargeText = chargeHolder:CreateFontString(nil, "OVERLAY")
  local keybindHolder = CreateFrame("Frame", nil, frame)
  local keybindText = keybindHolder:CreateFontString(nil, "OVERLAY")
  local glow = frame:CreateTexture(nil, "OVERLAY", nil, 5)

  ApplyFont(cooldownText, nil, "cooldown", 11)
  ApplyFont(chargeText, nil, "tiny", 10)
  ApplyFont(keybindText, nil, "tiny", 8)
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

  chargeCooldown:SetAllPoints(icon)
  chargeCooldown:SetDrawBling(false)
  chargeCooldown:SetDrawEdge(false)
  chargeCooldown:SetHideCountdownNumbers(true)
  chargeCooldown:SetSwipeColor(0, 0, 0, 0.72)
  chargeCooldown:SetSwipeTexture(WHITE_TEXTURE)
  IconSkin.SquareCooldown(chargeCooldown)

  cooldownText:SetPoint("CENTER", frame, "CENTER", 0, 0)
  chargeText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
  keybindText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
  chargeHolder:SetAllPoints(frame)
  chargeHolder:EnableMouse(false)
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
    chargeCooldown = chargeCooldown,
    cooldownText = cooldownText,
    chargeHolder = chargeHolder,
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
  if parts.chargeCooldown then
    parts.chargeCooldown:ClearAllPoints()
    parts.chargeCooldown:SetAllPoints(parts.icon)
    IconSkin.SquareCooldown(parts.chargeCooldown)
  end

  ApplyFont(parts.cooldownText, state.cooldownFont, "cooldown", 11)
  ApplyFont(parts.chargeText, state.chargeFont, "tiny", 10)
  ApplyFont(parts.keybindText, state.keybindFont, "tiny", 8)

  if parts.keybindHolder then
    parts.keybindHolder:SetFrameLevel(parts.frame:GetFrameLevel() + 12)
  end
  if parts.chargeHolder then
    parts.chargeHolder:SetFrameLevel(parts.frame:GetFrameLevel() + 5)
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

function PCMPresentation.CreateOwnedIcon(parent)
  local parts = Presentation.Create("PCMIcon", parent, {})
  parts.itemDuration = C_DurationUtil.CreateDuration()

  parts.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  parts.cooldownText:Hide()
  parts.chargeCooldown:SetFrameLevel(parts.frame:GetFrameLevel() + 3)
  parts.cooldown:SetFrameLevel(parts.frame:GetFrameLevel() + 4)
  parts.chargeHolder:SetFrameLevel(parts.frame:GetFrameLevel() + 5)
  parts.keybindHolder:SetFrameLevel(parts.frame:GetFrameLevel() + 12)
  parts.qualityHolder:SetFrameLevel(parts.frame:GetFrameLevel() + 2)

  local unavailable = parts.frame:CreateTexture(nil, "OVERLAY", nil, 3)
  unavailable:SetAllPoints(parts.icon)
  unavailable:SetTexture(WHITE_TEXTURE)
  unavailable:SetVertexColor(0, 0, 0, 1)
  unavailable:SetAlpha(0)

  local outOfRange = parts.frame:CreateTexture(nil, "OVERLAY", nil, 4)
  outOfRange:SetAllPoints(parts.icon)
  outOfRange:SetTexture(WHITE_TEXTURE)
  outOfRange:SetVertexColor(0.65, 0.05, 0.05, 1)
  outOfRange:SetBlendMode("MOD")
  outOfRange:SetAlpha(0)

  parts.unavailable = unavailable
  parts.outOfRange = outOfRange
  parts.glow:Show()
  parts.glow:SetAlpha(0)
  return parts
end

function PCMPresentation.CreateOwnedAuraIcon(parent)
  local frame = CreateFrame("Frame", nil, parent)
  ApplyRuntimeRootLayer(frame, parent)
  frame:EnableMouse(false)

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(frame)

  return {
    frame = frame,
    background = background,
    icon = icon,
  }
end

local function ApplyOwnedTextStyle(fontString, parent, config, role, fallbackSize)
  ApplyFont(fontString, config, role, fallbackSize)
  local point, x, y = IconSkin.ResolveTextAnchor(
    role,
    config and config.point,
    config and config.offsetX,
    config and config.offsetY
  )
  fontString:ClearAllPoints()
  fontString:SetPoint(point, parent, point, x, y)
end

function PCMPresentation.ApplyOwnedIconStyle(parts, style, isOnGCD)
  local size = math_max(Round(1), Round(tonumber(style.size) or 36))
  local borderSize = math_max(0, tonumber(style.borderSize) or 2)

  SetBackground(parts.background, style.backgroundColor)
  BarWidget.ApplyBorder(parts.frame, borderSize, style.borderColor)

  IconSkin.StyleCooldownText(parts.cooldown, style.cooldownFont)
  IconSkin.StyleCooldownText(parts.chargeCooldown, style.cooldownFont)
  ApplyOwnedTextStyle(parts.chargeText, parts.frame, style.chargeFont, "charge", 10)
  ApplyOwnedTextStyle(parts.keybindText, parts.frame, style.keybindFont, "keybind", 8)

  parts.qualityTexture:ClearAllPoints()
  local qualityOffset = Round(size * 11 / 36)
  parts.qualityTexture:SetPoint(
    "CENTER",
    parts.qualityHolder,
    "TOPLEFT",
    qualityOffset,
    -qualityOffset
  )
  parts.qualityTexture:SetScale(size / 36)

  parts.tooltipsEnabled = style.tooltips == true
  parts.frame:SetMouseMotionEnabled(parts.tooltipsEnabled)

  local swipe = style.swipe
  local viewerSwipe = style.viewerSwipe
  local show = swipe and swipe.show
  if show == nil then
    show = viewerSwipe == nil or viewerSwipe.cooldown ~= false
  end
  local showGCD = swipe and swipe.showGCD
  if showGCD == nil then
    showGCD = swipe and swipe.show
  end
  if showGCD == nil then
    showGCD = viewerSwipe == nil or viewerSwipe.gcd ~= false
  end
  parts.showCooldownSwipe = show == true
  parts.showGCDSwipe = showGCD == true
  local showSwipe = parts.showCooldownSwipe
  if isOnGCD == true then
    showSwipe = parts.showGCDSwipe
  end
  parts.cooldown:SetDrawSwipe(showSwipe)
  parts.chargeCooldown:SetDrawSwipe(parts.showCooldownSwipe)

  local drawEdge = swipe and swipe.drawEdge
  if drawEdge == nil then
    drawEdge = viewerSwipe == nil or viewerSwipe.drawEdge ~= false
  end
  parts.drawCooldownEdge = drawEdge == true
  parts.cooldown:SetDrawEdge(showSwipe and parts.drawCooldownEdge)

  local rechargeEdge = drawEdge
  if style.hasCharges and swipe and swipe.rechargeEdge ~= nil then
    rechargeEdge = swipe.rechargeEdge == true
  end
  parts.chargeCooldown:SetDrawEdge(parts.showCooldownSwipe and rechargeEdge == true)

  local reverse = swipe and swipe.reverse == true
  parts.cooldown:SetReverse(reverse)
  parts.chargeCooldown:SetReverse(reverse)

  local swipeColor = swipe and swipe.color
    or viewerSwipe and viewerSwipe.swipeColor
  local swipeR, swipeG, swipeB, swipeA
  if type(swipeColor) == "table" then
    swipeR = tonumber(swipeColor[1] or swipeColor.r) or 1
    swipeG = tonumber(swipeColor[2] or swipeColor.g) or 1
    swipeB = tonumber(swipeColor[3] or swipeColor.b) or 1
    swipeA = tonumber(swipeColor[4] or swipeColor.a) or 1
  else
    swipeR, swipeG, swipeB, swipeA = 0, 0, 0, 0.8
  end
  parts.cooldown:SetSwipeColor(swipeR, swipeG, swipeB, swipeA)
  parts.chargeCooldown:SetSwipeColor(swipeR, swipeG, swipeB, swipeA)

  local counts = style.viewerCounts
  local cooldownCount = style.cooldown and style.cooldown.show
  if cooldownCount == nil then
    cooldownCount = counts == nil or counts.cooldown ~= false
  end
  parts.cooldown:SetHideCountdownNumbers(cooldownCount ~= true)

  local rechargeCount = cooldownCount
  if style.hasCharges
    and style.cooldown
    and style.cooldown.rechargeShow ~= nil
  then
    rechargeCount = style.cooldown.rechargeShow == true
  end
  parts.chargeCooldown:SetHideCountdownNumbers(rechargeCount ~= true)

  local chargeCount = style.charge and style.charge.show
  if chargeCount == nil then
    chargeCount = counts == nil or counts.charge ~= false
  end
  parts.chargeText:SetShown(chargeCount == true)

  parts.customTexture = style.appearance and style.appearance.texture or nil
end

function PCMPresentation.ApplyOwnedAuraIconStyle(parts, style)
  local size = math_max(Round(1), Round(tonumber(style.size) or 36))
  local inset = math_max(0, Round(tonumber(style.inset) or 0))
  local borderSize = math_max(0, tonumber(style.borderSize) or 2)

  if style.manageFrameSize ~= false then
    parts.frame:SetSize(size, size)
  end
  SetBackground(parts.background, style.backgroundColor)
  BarWidget.ApplyBorder(parts.frame, borderSize, style.borderColor)

  parts.icon:ClearAllPoints()
  parts.icon:SetPoint("TOPLEFT", parts.frame, "TOPLEFT", inset, -inset)
  parts.icon:SetPoint("BOTTOMRIGHT", parts.frame, "BOTTOMRIGHT", -inset, inset)
  IconSkin.StripIconMasks(parts.icon)
  IconSkin.MakeIconSquare(parts.icon, { crop = 0.08 })

  parts.customTexture = style.appearance and style.appearance.texture or nil
end

function PCMPresentation.ApplyOwnedIconVisibility(parts, style)
  parts.frame:SetShown(style.visible ~= false)
end

function PCMPresentation.ConfigureOwnedAuraLayer(parts, button, unit, style)
  local auraParts = AuraWidget.BindApplicationDurationButton(button)
  local isTotem = unit == "totem"
  button:ClearAllPoints()
  button:SetPoint("TOPLEFT", parts.frame, "TOPLEFT")
  button:SetSize(style.size, style.size)
  button:SetFrameStrata(parts.frame:GetFrameStrata())
  button:SetFrameLevel(parts.frame:GetFrameLevel() + (unit == "player" and 7 or 6))

  if isTotem then
    auraParts.icon:Show()
  else
    AuraWidget.ConfigureIcon(auraParts)
  end
  auraParts.icon:SetAllPoints(button)
  if not auraParts.ownedCustomTexture then
    auraParts.ownedCustomTexture = button:CreateTexture(nil, "ARTWORK", nil, 2)
    auraParts.ownedCustomTexture:SetAllPoints(auraParts.icon)
  end
  auraParts.ownedCustomTexture:SetTexture(parts.customTexture)
  auraParts.ownedCustomTexture:SetShown(parts.customTexture ~= nil)
  if isTotem then
    auraParts.durationCooldown:Show()
  else
    AuraWidget.ConfigureDurationCooldown(auraParts)
  end
  auraParts.durationCooldown:SetAllPoints(button)
  auraParts.durationCooldown:SetReverse(true)
  local swipe = style.swipe or {}
  local viewerSwipe = style.viewerSwipe or {}
  local showDurationSwipe = swipe.show
  if showDurationSwipe == nil then
    showDurationSwipe = viewerSwipe.duration ~= false
  end
  local drawEdge = swipe.drawEdge
  if drawEdge == nil then
    drawEdge = viewerSwipe.drawEdge ~= false
  end
  auraParts.durationCooldown:SetDrawEdge(showDurationSwipe == true and drawEdge == true)
  auraParts.durationCooldown:SetDrawSwipe(showDurationSwipe == true)

  local showDurationCount = style.cooldown and style.cooldown.show
  if showDurationCount == nil then
    showDurationCount = style.viewerDurationCount ~= false
  end
  auraParts.durationCooldown:SetHideCountdownNumbers(showDurationCount ~= true)
  IconSkin.StyleCooldownText(auraParts.durationCooldown, style.cooldownFont)

  local swipeColor = CopyColor(swipe.color or viewerSwipe.swipeColor, { 0, 0, 0, 0.72 })
  auraParts.durationCooldown:SetSwipeColor(
    swipeColor[1],
    swipeColor[2],
    swipeColor[3],
    swipeColor[4]
  )

  local charge = style.charge or {}
  local counts = style.viewerCounts or {}
  local showApplications = charge.show
  if showApplications == nil then
    showApplications = counts.charge ~= false
  end
  auraParts.applicationHolder:ClearAllPoints()
  auraParts.applicationHolder:SetAllPoints(button)
  auraParts.applicationHolder:SetFrameLevel(button:GetFrameLevel() + 5)
  ApplyOwnedTextStyle(
    auraParts.applicationText,
    auraParts.applicationHolder,
    style.chargeFont,
    "charge",
    10
  )
  if isTotem then
    auraParts.applicationHolder:Hide()
  elseif showApplications then
    AuraWidget.ConfigureApplicationCount(auraParts)
  else
    AuraWidget.DisableApplicationCount(auraParts)
  end

  local appearance = style.appearance or {}
  local auraAlpha = tonumber(appearance.auraAlpha) or 1
  button:SetAlpha(auraAlpha)
  button:SetMouseMotionEnabled(style.tooltips == true and auraAlpha > 0)
  local saturation = tonumber(appearance.auraSaturation)
  local desaturation = saturation and (1 - math.max(0, math.min(1, saturation))) or 0
  auraParts.icon:SetDesaturation(desaturation)
  auraParts.ownedCustomTexture:SetDesaturation(desaturation)

  local glowStyle = appearance.auraGlowStyle or "NONE"
  local glowColor = CopyColor(appearance.auraGlowColor, { 1, 1, 1, 1 })
  local auraSize = math_max(1, tonumber(style.size) or 1)
  if auraParts.ownedAuraGlow then
    AuraWidget.ConfigureSlotGlow(
      auraParts.ownedAuraGlow,
      auraSize,
      auraSize,
      glowStyle,
      glowColor
    )
  elseif glowStyle ~= "NONE" then
    auraParts.ownedAuraGlow = AuraWidget.CreateSlotGlow(
      button,
      auraSize,
      auraSize,
      glowStyle,
      glowColor
    )
  end
end

function PCMPresentation.CreateOwnedAuraBar(parent)
  local frame = CreateFrame("Frame", nil, parent)
  ApplyRuntimeRootLayer(frame, parent)
  frame:SetSize(250, 20)
  frame:EnableMouse(false)
  return {
    frame = frame,
  }
end

function PCMPresentation.ConfigureOwnedAuraBar(parts, button, style, isTotem)
  local auraParts = AuraWidget.BindApplicationDurationButton(button)
  local vertical = style.orientation == "VERTICAL"
  local length = math_max(1, tonumber(style.width) or 250)
  local thickness = math_max(1, tonumber(style.height) or 20)
  local iconPlacement = style.iconPlacement or (vertical and "TOP" or "LEFT")
  local showIcon = iconPlacement ~= "HIDE"
  local iconSize = showIcon and thickness or 0
  local barLength = showIcon and math_max(1, length - iconSize) or length
  local barWidth = vertical and thickness or barLength
  local barHeight = vertical and barLength or thickness

  button:ClearAllPoints()
  button:SetAllPoints(parts.frame)
  button:SetFrameStrata(parts.frame:GetFrameStrata())
  button:SetFrameLevel(parts.frame:GetFrameLevel() + 1)
  button:EnableMouse(style.tooltips == true)

  ApplyFont(auraParts.durationText, style.durationFont, "body", 12)
  ApplyFont(auraParts.applicationText, style.applicationFont, "tiny", 10)

  if isTotem then
    auraParts.durationBar:Show()
    auraParts.durationTextHolder:Show()
    auraParts.durationText:Show()
    auraParts.durationCooldown:Hide()
    if not auraParts.totemDurationBinding then
      auraParts.totemDurationBinding = BarWidget.CreateDurationBinding(auraParts.durationText)
    end
  else
    AuraWidget.ConfigureDurationBar(
      auraParts,
      nil,
      Enum.StatusBarTimerDirection.RemainingTime
    )
    AuraWidget.ConfigureDurationText(auraParts, BarWidget.GetDurationFormatter())
    AuraWidget.ConfigureIcon(auraParts)
  end

  auraParts.durationBar:ClearAllPoints()
  auraParts.durationBar:SetSize(barWidth, barHeight)
  auraParts.durationBar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
  auraParts.durationBar:SetReverseFill(
    vertical and style.drainDirection == "TOP_TO_BOTTOM"
      or not vertical and style.drainDirection == "LEFT_TO_RIGHT"
  )
  auraParts.durationBar:SetStatusBarTexture(
    BarWidget.ResolveStatusBarTexture(style.texture or "Pleebar", FALLBACK_BAR_TEXTURE)
  )
  local color = CopyColor(style.color, { 1, 0.6, 0, 1 })
  auraParts.durationBar:SetStatusBarColor(color[1], color[2], color[3], color[4])

  if not auraParts.ownedBackground then
    auraParts.ownedBackground = auraParts.durationBar:CreateTexture(nil, "BACKGROUND")
    auraParts.ownedBackground:SetAllPoints(auraParts.durationBar)
  end
  SetBackground(auraParts.ownedBackground, style.backgroundColor)
  auraParts.ownedBackground:Show()

  if not auraParts.ownedBarBorder then
    auraParts.ownedBarBorder = CreateFrame("Frame", nil, button)
  end
  auraParts.ownedBarBorder:ClearAllPoints()
  auraParts.ownedBarBorder:SetAllPoints(auraParts.durationBar)
  auraParts.ownedBarBorder:SetFrameLevel(auraParts.durationBar:GetFrameLevel() + 2)
  BarWidget.ApplyBorder(
    auraParts.ownedBarBorder,
    tonumber(style.borderThickness) or 2,
    CopyColor(style.borderColor, { 0.20, 0.20, 0.24, 1 })
  )

  auraParts.icon:ClearAllPoints()
  if showIcon then
    auraParts.icon:SetSize(iconSize, iconSize)
    if vertical then
      if iconPlacement == "BOTTOM" then
        auraParts.icon:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
        auraParts.durationBar:SetPoint("BOTTOM", auraParts.icon, "TOP", 0, 0)
      else
        auraParts.icon:SetPoint("TOP", button, "TOP", 0, 0)
        auraParts.durationBar:SetPoint("TOP", auraParts.icon, "BOTTOM", 0, 0)
      end
    elseif iconPlacement == "RIGHT" then
      auraParts.icon:SetPoint("RIGHT", button, "RIGHT", 0, 0)
      auraParts.durationBar:SetPoint("RIGHT", auraParts.icon, "LEFT", 0, 0)
    else
      auraParts.icon:SetPoint("LEFT", button, "LEFT", 0, 0)
      auraParts.durationBar:SetPoint("LEFT", auraParts.icon, "RIGHT", 0, 0)
    end
    IconSkin.StripIconMasks(auraParts.icon)
    IconSkin.MakeIconSquare(auraParts.icon, { crop = 0.08 })
    auraParts.icon:Show()
  else
    auraParts.durationBar:SetPoint("CENTER", button, "CENTER", 0, 0)
    if isTotem then
      auraParts.icon:Hide()
    else
      AuraWidget.DisableIcon(auraParts)
    end
  end

  if not auraParts.ownedIconBorder then
    auraParts.ownedIconBorder = CreateFrame("Frame", nil, button)
  end
  auraParts.ownedIconBorder:ClearAllPoints()
  auraParts.ownedIconBorder:SetAllPoints(auraParts.icon)
  auraParts.ownedIconBorder:SetFrameLevel(button:GetFrameLevel() + 3)
  BarWidget.ApplyBorder(
    auraParts.ownedIconBorder,
    showIcon and (tonumber(style.borderThickness) or 2) or 0,
    CopyColor(style.borderColor, { 0.20, 0.20, 0.24, 1 })
  )
  auraParts.ownedIconBorder:SetShown(showIcon)

  if not auraParts.ownedName then
    auraParts.ownedName = button:CreateFontString(nil, "OVERLAY")
    auraParts.ownedName:SetWordWrap(false)
    ApplyFont(auraParts.ownedName, style.nameFont, "body", 12)
    if not isTotem then
      button:SetSpellName(auraParts.ownedName)
    end
  else
    ApplyFont(auraParts.ownedName, style.nameFont, "body", 12)
  end
  auraParts.ownedName:ClearAllPoints()
  auraParts.durationTextHolder:ClearAllPoints()
  auraParts.durationTextHolder:SetAllPoints(auraParts.durationBar)
  auraParts.durationText:ClearAllPoints()
  if vertical then
    auraParts.ownedName:Hide()
    auraParts.durationText:SetPoint("CENTER", auraParts.durationBar, "CENTER", 0, 0)
  else
    auraParts.ownedName:SetPoint("LEFT", auraParts.durationBar, "LEFT", 5, 0)
    auraParts.ownedName:SetPoint("RIGHT", auraParts.durationBar, "RIGHT", -32, 0)
    auraParts.ownedName:SetJustifyH("LEFT")
    auraParts.ownedName:Show()
    auraParts.durationText:SetPoint("RIGHT", auraParts.durationBar, "RIGHT", -8, 0)
  end

  auraParts.applicationHolder:ClearAllPoints()

  local counts = style.counts or {}
  if isTotem then
    auraParts.applicationHolder:Hide()
  elseif showIcon and counts.buff ~= false then
    auraParts.applicationHolder:SetAllPoints(auraParts.icon)
    AuraWidget.ConfigureApplicationCount(auraParts)

    auraParts.applicationText:ClearAllPoints()
    auraParts.applicationText:SetPoint(
      "BOTTOMRIGHT",
      auraParts.applicationHolder,
      "BOTTOMRIGHT",
      -5,
      5
    )
    auraParts.applicationText:SetJustifyH("RIGHT")
  else
    AuraWidget.DisableApplicationCount(auraParts)
  end

  auraParts.durationTextHolder:SetFrameLevel(button:GetFrameLevel() + 4)
  auraParts.applicationHolder:SetFrameLevel(button:GetFrameLevel() + 5)
  return auraParts
end

function PCMPresentation.SetBuffTotemDuration(auraParts, duration)
  if auraParts.totemDurationBinding then
    if duration == nil then
      auraParts.totemDurationBinding:Disable()
      BarWidget.StopTimerBar(auraParts.durationBar)
      auraParts.durationText:SetText("")
      return
    end

    auraParts.durationBar:SetTimerDuration(
      duration,
      Enum.StatusBarInterpolation.Immediate,
      Enum.StatusBarTimerDirection.RemainingTime
    )
    auraParts.totemDurationBinding:SetDuration(duration)
    auraParts.totemDurationBinding:Enable()
  elseif duration == nil then
    auraParts.durationCooldown:Clear()
  else
    auraParts.durationCooldown:SetCooldownFromDurationObject(duration, true)
  end
end

function PCMPresentation.SetStaticIcon(parts, texture)
  parts.icon:SetTexture(parts.customTexture or texture)
end

function PCMPresentation.SetSpellCooldownDuration(parts, duration, isOnGCD)
  local showSwipe = parts.showCooldownSwipe
  if isOnGCD == true then
    showSwipe = parts.showGCDSwipe
  end
  parts.cooldown:SetDrawSwipe(showSwipe)
  parts.cooldown:SetDrawEdge(showSwipe and parts.drawCooldownEdge)

  if duration == nil then
    parts.cooldown:Clear()
    return
  end
  parts.cooldown:SetCooldownFromDurationObject(duration, true)
end

function PCMPresentation.SetChargeDuration(parts, duration)
  if duration == nil then
    parts.chargeCooldown:Clear()
    return
  end
  parts.chargeCooldown:SetCooldownFromDurationObject(duration, true)
end

function PCMPresentation.SetDisplayCount(parts, displayCount)
  parts.chargeText:SetText(displayCount)
end

function PCMPresentation.SetUsableState(parts, usable)
  if not issecretvalue(usable) and type(usable) ~= "boolean" then
    parts.unavailable:SetAlpha(0)
  else
    parts.unavailable:SetAlphaFromBoolean(usable, 0, 0.45)
  end
end

function PCMPresentation.SetRangeState(parts, inRange)
  if not issecretvalue(inRange) and type(inRange) ~= "boolean" then
    parts.outOfRange:SetAlpha(0)
    return
  end
  parts.outOfRange:SetAlphaFromBoolean(inRange, 0, 0.35)
end

local function StopOwnedProcGlow(parts)
  local glowType = parts.ownedProcGlowType
  if glowType == "pixel" then
    LCG.PixelGlow_Stop(parts.frame, OWNED_PROC_GLOW_KEY)
  elseif glowType == "autocast" then
    LCG.AutoCastGlow_Stop(parts.frame, OWNED_PROC_GLOW_KEY)
  elseif glowType == "actionbutton" then
    LCG.ButtonGlow_Stop(parts.frame)
  elseif glowType == "proc" then
    LCG.ProcGlow_Stop(parts.frame, OWNED_PROC_GLOW_KEY)
  end
  parts.ownedProcGlowType = nil
  parts.ownedProcGlowSignature = nil
end

function PCMPresentation.SetProcState(parts, active, config)
  if active ~= true or not config or config.enabled == false then
    StopOwnedProcGlow(parts)
    return
  end

  local glowType = tostring(config.type or "pixel")
  local color = CopyColor(config.color, { 0.95, 0.95, 0.32, 1 })
  local speed = math.max(20, math.min(200, tonumber(config.speed) or 100))
  local scale = math.max(0.5, math.min(2, tonumber(config.scale) or 1))
  local lines = math.max(2, math.min(16, tonumber(config.lines) or 8))
  local thickness = math.max(1, math.min(6, tonumber(config.thickness) or 2))
  local speedMultiplier = speed / 100
  local frequency = (glowType == "autocast" and 0.6 or glowType == "pixel" and 0.25 or 1)
    * speedMultiplier
  local duration = math.max(0.05, 1 / speedMultiplier)
  local signature = table.concat({
    glowType,
    color[1], color[2], color[3], color[4],
    frequency, scale, lines, thickness, duration,
  }, ":")

  if parts.ownedProcGlowSignature == signature then
    return
  end

  StopOwnedProcGlow(parts)
  if glowType == "pixel" then
    LCG.PixelGlow_Start(parts.frame, color, lines, frequency, nil, thickness, 0, 0, true, OWNED_PROC_GLOW_KEY, 8)
  elseif glowType == "autocast" then
    LCG.AutoCastGlow_Start(parts.frame, color, lines, frequency, scale, 0, 0, OWNED_PROC_GLOW_KEY, 8)
  elseif glowType == "actionbutton" then
    LCG.ButtonGlow_Start(parts.frame, color, frequency, 8)
  elseif glowType == "proc" then
    LCG.ProcGlow_Start(parts.frame, {
      key = OWNED_PROC_GLOW_KEY,
      color = color,
      startAnim = true,
      xOffset = 0,
      yOffset = 0,
      duration = duration,
      frameLevel = 8,
    })
  else
    return
  end

  parts.ownedProcGlowType = glowType
  parts.ownedProcGlowSignature = signature
end

function PCMPresentation.DeactivateOwnedIcon(parts)
  StopOwnedProcGlow(parts)
  if parts.ownedStateGlowKey then
    PCMPresentation.ApplyCustomTrackerStateGlow(parts.ownedStateGlowKey, nil)
  end
  parts.cooldown:Clear()
  parts.chargeCooldown:Clear()
  parts.cooldownText:SetText(nil)
  parts.chargeText:SetText(nil)
  parts.keybindText:SetText(nil)
  parts.frame:SetAlpha(1)
  parts.frame:SetMouseMotionEnabled(false)
  parts.icon:SetDesaturation(0)
  parts.unavailable:SetAlpha(0)
  parts.outOfRange:SetAlpha(0)
  parts.glow:SetAlpha(0)
end

function PCMPresentation.DeactivateOwnedAuraIcon(parts)
  parts.frame:SetAlpha(1)
  parts.frame:SetMouseMotionEnabled(false)
  parts.icon:SetDesaturation(0)
end

function PCMPresentation.SetTotemDuration(parts, duration)
  if duration == nil then
    parts.cooldown:Clear()
    return
  end
  parts.cooldown:SetCooldownFromDurationObject(duration, true)
end

function PCMPresentation.SetItemCooldown(parts, startTime, duration)
  if startTime == 0 then
    parts.cooldown:Clear()
    return
  end
  parts.itemDuration:SetTimeFromStart(startTime, duration)
  parts.cooldown:SetCooldownFromDurationObject(parts.itemDuration, true)
end

function PCMPresentation.SetKeybindText(parts, text)
  parts.keybindText:SetText(text)
end

local CustomBarBuffGlowTracks = {}
local CustomBarBuffGlowTrackPool = {}
local CustomBarBuffGlowPending = {}
local CustomBarBuffGlowEventFrame = CreateFrame("Frame")
local CustomTrackerStateGlows = {}
local CUSTOM_TRACKER_STATE_GLOW_KEY = "PUI_CustomTrackerState"

local function ReleaseCustomTrackerStateGlow(trackKey)
  trackKey = tostring(trackKey)
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

  ReleaseCustomTrackerStateGlow(trackKey)
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

function PCMPresentation.ApplyOwnedStateAppearance(parts, cooldownID, appearance, stateName, atMaxCharges)
  appearance = appearance or {}
  local alpha = 1
  local saturation
  local glowStyle
  local glowColor

  if stateName == "AURA" then
    alpha = tonumber(appearance.auraAlpha) or 1
    saturation = tonumber(appearance.auraSaturation)
    glowStyle = appearance.auraGlowStyle
    glowColor = appearance.auraGlowColor
  elseif stateName == "COOLDOWN" then
    alpha = tonumber(appearance.cooldownAlpha) or 1
    saturation = tonumber(appearance.cooldownSaturation)
    glowStyle = appearance.cooldownGlowStyle
    glowColor = appearance.cooldownGlowColor
  elseif stateName == "READY" then
    alpha = tonumber(appearance.readyAlpha) or 1
    saturation = tonumber(appearance.readySaturation)
    if atMaxCharges == true and appearance.maxChargeGlowStyle ~= nil then
      glowStyle = appearance.maxChargeGlowStyle
      glowColor = appearance.maxChargeGlowColor
    else
      glowStyle = appearance.readyGlowStyle
      glowColor = appearance.readyGlowColor
    end
  else
    return
  end

  parts.frame:SetAlpha(alpha)
  parts.frame:SetMouseMotionEnabled(parts.tooltipsEnabled == true and alpha > 0)
  parts.icon:SetDesaturation(
    saturation and (1 - math.max(0, math.min(1, saturation))) or 0
  )

  parts.ownedStateGlowKey = parts.ownedStateGlowKey or ("pcm-owned:" .. tostring(cooldownID))
  PCMPresentation.ApplyCustomTrackerStateGlow(
    parts.ownedStateGlowKey,
    parts.frame,
    glowStyle,
    glowColor
  )
end

local function CustomBarBuffGlowRestyleLocked()
  return C_Secrets.ShouldAurasBeSecret() == true
end

local function IsCustomBarAuraGlowEnabled(cfg)
  if not cfg or cfg.presentation ~= "BAR" then
    return false
  end

  if cfg.kind == "duration" or cfg.kind == "stack" then
    return cfg.buffGlowEnabled == true
  end

  return cfg.activeAuraEnabled == true and cfg.activeGlowStyle ~= "NONE"
end

local function ResolveCustomBarAuraGlow(track)
  local cfg = track.config
  if not IsCustomBarAuraGlowEnabled(cfg) then
    return "NONE", { 1, 0.55, 0.1, 1 }
  end

  local auraTracker = cfg.kind == "duration" or cfg.kind == "stack"
  local style = cfg.activeGlowStyle
  if auraTracker and (style == nil or style == "NONE") then
    style = "PIXEL"
  end

  if style == nil or style == "NONE" then
    return "NONE", { 1, 0.55, 0.1, 1 }
  end

  if auraTracker then
    return style, CopyColor(cfg.buffGlowColor, { 0.25, 0.75, 1, 1 })
  end

  return style, CopyColor(cfg.activeGlowColor, { 1, 0.55, 0.1, 1 })
end

local function GetCustomBarAuraGlowOptions(track)
  return {
    pixelThickness = tonumber(track.config and track.config.buffGlowThickness) or 2,
  }
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

  track.buttonBaseAlpha = 1
  button:SetAlpha(track.contextAlpha or 1)

  local glowStyle, glowColor = ResolveCustomBarAuraGlow(track)
  local glowOptions = GetCustomBarAuraGlowOptions(track)
  local width = math_max(1, anchorFrame:GetWidth())
  local height = math_max(1, anchorFrame:GetHeight())

  if initializing == true then
    track.auraGlow = AuraWidget.CreateSlotGlow(
      button,
      width,
      height,
      glowStyle,
      glowColor,
      glowOptions
    )
  elseif track.auraGlow then
    AuraWidget.ConfigureSlotGlow(
      track.auraGlow,
      width,
      height,
      glowStyle,
      glowColor,
      glowOptions
    )
  end

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
    track.stylePending = nil
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
  track.enabled = IsCustomBarAuraGlowEnabled(cfg)
  track.spellID = track.enabled and tonumber(cfg.buffGlowSpellID or cfg.trackedSpellID) or nil

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
  track.enabled = IsCustomBarAuraGlowEnabled(track.config)
  if not track.enabled then
    ApplyCustomBarBuffGlowTrack(track)
    CustomBarBuffGlowPending[trackKey] = nil
    StopCustomBarBuffGlowPendingEvents()
    return
  end

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
  local texture = BarWidget.ResolveStatusBarTexture(cfg.stackTexture or "Pleebar", FALLBACK_BAR_TEXTURE)
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
  local parts = CustomBarPresentation[frame]
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
  CustomBarPresentation[frame] = parts
  return parts
end

Presentation.Register("PCMBar", PCMBarAdapter)
Presentation.Register("PCMIcon", PCMIconAdapter)

local P = select(1, ns.Pleebug:DropIn(PCMPresentation, { name = "PCM.Presentation" }))
PCMPresentation.CreateOwnedIcon = P:Def("PCMPresentation.CreateOwnedIcon", PCMPresentation.CreateOwnedIcon)
PCMPresentation.CreateOwnedAuraIcon = P:Def("PCMPresentation.CreateOwnedAuraIcon", PCMPresentation.CreateOwnedAuraIcon)
PCMPresentation.ApplyOwnedIconStyle = P:Def("PCMPresentation.ApplyOwnedIconStyle", PCMPresentation.ApplyOwnedIconStyle)
PCMPresentation.ApplyOwnedAuraIconStyle = P:Def("PCMPresentation.ApplyOwnedAuraIconStyle", PCMPresentation.ApplyOwnedAuraIconStyle)
PCMPresentation.ApplyOwnedIconVisibility = P:Def("PCMPresentation.ApplyOwnedIconVisibility", PCMPresentation.ApplyOwnedIconVisibility)
PCMPresentation.ConfigureOwnedAuraLayer = P:Def("PCMPresentation.ConfigureOwnedAuraLayer", PCMPresentation.ConfigureOwnedAuraLayer)
PCMPresentation.CreateOwnedAuraBar = P:Def("PCMPresentation.CreateOwnedAuraBar", PCMPresentation.CreateOwnedAuraBar)
PCMPresentation.ConfigureOwnedAuraBar = P:Def("PCMPresentation.ConfigureOwnedAuraBar", PCMPresentation.ConfigureOwnedAuraBar)
PCMPresentation.SetBuffTotemDuration = P:Def("PCMPresentation.SetBuffTotemDuration", PCMPresentation.SetBuffTotemDuration)
PCMPresentation.SetStaticIcon = P:Def("PCMPresentation.SetStaticIcon", PCMPresentation.SetStaticIcon)
PCMPresentation.SetSpellCooldownDuration = P:Def("PCMPresentation.SetSpellCooldownDuration", PCMPresentation.SetSpellCooldownDuration)
PCMPresentation.SetChargeDuration = P:Def("PCMPresentation.SetChargeDuration", PCMPresentation.SetChargeDuration)
PCMPresentation.SetDisplayCount = P:Def("PCMPresentation.SetDisplayCount", PCMPresentation.SetDisplayCount)
PCMPresentation.SetUsableState = P:Def("PCMPresentation.SetUsableState", PCMPresentation.SetUsableState)
PCMPresentation.SetRangeState = P:Def("PCMPresentation.SetRangeState", PCMPresentation.SetRangeState)
PCMPresentation.SetProcState = P:Def("PCMPresentation.SetProcState", PCMPresentation.SetProcState)
PCMPresentation.DeactivateOwnedIcon = P:Def("PCMPresentation.DeactivateOwnedIcon", PCMPresentation.DeactivateOwnedIcon)
PCMPresentation.DeactivateOwnedAuraIcon = P:Def("PCMPresentation.DeactivateOwnedAuraIcon", PCMPresentation.DeactivateOwnedAuraIcon)
PCMPresentation.SetTotemDuration = P:Def("PCMPresentation.SetTotemDuration", PCMPresentation.SetTotemDuration)
PCMPresentation.SetItemCooldown = P:Def("PCMPresentation.SetItemCooldown", PCMPresentation.SetItemCooldown)
PCMPresentation.SetKeybindText = P:Def("PCMPresentation.SetKeybindText", PCMPresentation.SetKeybindText)
PCMPresentation.ApplyOwnedStateAppearance = P:Def("PCMPresentation.ApplyOwnedStateAppearance", PCMPresentation.ApplyOwnedStateAppearance)
PCMPresentation.EnsureStackSegments = P:Def("PCMPresentation.EnsureStackSegments", EnsureStackSegments)
PCMPresentation.LayoutStackSegments = P:Def("PCMPresentation.LayoutStackSegments", PCMPresentation.LayoutStackSegments)
PCMPresentation.EnsureChargeSlots = P:Def("PCMPresentation.EnsureChargeSlots", EnsureChargeSlots)
PCMPresentation.LayoutChargeSlots = P:Def("PCMPresentation.LayoutChargeSlots", LayoutChargeSlots)
PCMPresentation.ApplyChargeCount = P:Def("PCMPresentation.ApplyChargeCount", PCMPresentation.ApplyChargeCount)
PCMPresentation.AnchorChargeTimerText = P:Def("PCMPresentation.AnchorChargeTimerText", PCMPresentation.AnchorChargeTimerText)
PCMPresentation.BindCustomBar = P:Def("PCMPresentation.BindCustomBar", PCMPresentation.BindCustomBar)
PCMPresentation.ConfigureCustomBarBuffGlow = P:Def("PCMPresentation.ConfigureCustomBarBuffGlow", PCMPresentation.ConfigureCustomBarBuffGlow)
PCMPresentation.RefreshCustomBarBuffGlowStyle = P:Def("PCMPresentation.RefreshCustomBarBuffGlowStyle", PCMPresentation.RefreshCustomBarBuffGlowStyle)
PCMPresentation.DisableCustomBarBuffGlow = P:Def("PCMPresentation.DisableCustomBarBuffGlow", PCMPresentation.DisableCustomBarBuffGlow)
PCMPresentation.ReleaseCustomBarBuffGlow = P:Def("PCMPresentation.ReleaseCustomBarBuffGlow", PCMPresentation.ReleaseCustomBarBuffGlow)
PCMPresentation.ApplyCustomTrackerStateGlow = P:Def("PCMPresentation.ApplyCustomTrackerStateGlow", PCMPresentation.ApplyCustomTrackerStateGlow)
PCMPresentation.ReleaseCustomTrackerStateGlow = P:Def("PCMPresentation.ReleaseCustomTrackerStateGlow", ReleaseCustomTrackerStateGlow)
PCMPresentation.SetCustomBarBuffGlowContextAlpha = P:Def("PCMPresentation.SetCustomBarBuffGlowContextAlpha", PCMPresentation.SetCustomBarBuffGlowContextAlpha)
