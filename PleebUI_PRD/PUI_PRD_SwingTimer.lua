local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace

local SwingTimer = {}
ns.PRDSwingTimer = SwingTimer
SwingTimer.available = ns.Client.IsForever and C_EventUtils.IsEventValid("PLAYER_SWING")

if not SwingTimer.available then return end

local PRD = ns.Modules.PRD
local SwingType = Enum.PlayerSwingType
local ROWS = {
  { swingType = SwingType.MainHand, colorKey = "mainHandColor" },
  { swingType = SwingType.OffHand, colorKey = "offHandColor" },
  { swingType = SwingType.Ranged, colorKey = "rangedColor" },
}
local ROW_GAP = 2
local EVENTS = {
  "PLAYER_SWING", "WEAPON_SLOT_CHANGED", "PLAYER_ENTERING_WORLD",
  "PLAYER_DEAD", "PLAYER_LEAVE_COMBAT", "PLAYER_REGEN_ENABLED", "STOP_AUTOREPEAT_SPELL",
}

local function PositionWindupZone(row, width)
  if row.windupFraction then
    row.windupZone:SetWidth(width * row.windupFraction)
  end
end

local function UpdateWindupZone(row, config)
  local show = config.showWindup and row.swingSeconds ~= nil
  row.windupFraction = show and math.min(1, config.windupLead / row.swingSeconds) or nil
  PositionWindupZone(row, row:GetWidth())
  row.windupZone:SetShown(show)
  row.windupEdge:SetShown(show)
end

local function CreateRows(parent)
  local container = CreateFrame("Frame", nil, parent)
  container:Hide()
  container.rows = {}
  container.byType = {}

  for index, definition in ipairs(ROWS) do
    local row = CreateFrame("Frame", nil, container)
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.65)
    local fill = CreateFrame("StatusBar", nil, row)
    fill:SetAllPoints()
    fill:SetFrameLevel(row:GetFrameLevel())
    fill:Hide()
    local text = fill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    row.fill = fill
    row.text = text
    if definition.swingType == SwingType.Ranged then
      local zone = fill:CreateTexture(nil, "ARTWORK", nil, 1)
      zone:SetPoint("TOPLEFT", fill)
      zone:SetPoint("BOTTOMLEFT", fill)
      zone:SetColorTexture(1, 0.42, 0.12, 0.48)
      local edge = fill:CreateTexture(nil, "ARTWORK", nil, 2)
      edge:SetPoint("TOPRIGHT", zone)
      edge:SetPoint("BOTTOMRIGHT", zone)
      edge:SetWidth(ns.Pixel.GetOnePixel())
      edge:SetColorTexture(1, 0.70, 0.26, 1)
      row.windupZone = zone
      row.windupEdge = edge
      zone:Hide()
      edge:Hide()
      row:SetScript("OnSizeChanged", PositionWindupZone)
    end
    container.rows[index] = row
    container.byType[definition.swingType] = row
  end
  return container
end

local function LayoutRows(container, config)
  local texture = ns.BarWidget.ResolveStatusBarTexture(config.texture)
  local font = ns.OptionsUtil.FetchFontPath(config.font, false)
  local rowHeight = ns.Pixel.Round(config.height)
  local height = 0
  for index, row in ipairs(container.rows) do
    row:SetShown(row.available == true)
    if row.available then
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -height)
      row:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -height)
      row:SetHeight(rowHeight)
      row.fill:SetStatusBarTexture(texture)
      row.fill:SetStatusBarColor(unpack(config[ROWS[index].colorKey]))
      PRD:ApplyBarBorder(row, PRD:GetBarBorderThickness(config, row), config.borderColor)
      row.text:SetFont(font or STANDARD_TEXT_FONT, config.fontSize, "OUTLINE")
      row.text:SetShown(config.showCountdown)
      if row.windupZone then UpdateWindupZone(row, config) end
      if row.binding and row.fill:IsShown() and config.showCountdown then
        row.binding:Enable()
      elseif row.binding then
        row.binding:Disable()
      end
      height = height + rowHeight + ROW_GAP
    end
  end
  return height - ROW_GAP
end

local function ClearRow(row)
  row.swingSeconds = nil
  row.binding:Disable()
  row.fill:Hide()
end

local function SetWeaponAvailability(row, speed)
  -- Attack speeds may be restricted in combat. Keep the last readable state.
  if issecretvalue(speed) then return false end
  local available = speed ~= nil and speed > 0
  if row.available == available then return false end
  row.available = available
  if not available then ClearRow(row) end
  return true
end

local function RefreshWeapons(container)
  local _, offHand, ranged = UnitAttackSpeed("player")
  local offHandChanged = SetWeaponAvailability(container.byType[SwingType.OffHand], offHand)
  local rangedChanged = SetWeaponAvailability(container.byType[SwingType.Ranged], ranged)
  return offHandChanged or rangedChanged
end

local function LayoutChangedWeapons(container)
  if container.config.detached then
    container:SetHeight(LayoutRows(container, container.config))
  else
    PRD:ApplyLayout()
  end
end

local function OnEvent(container, event, duration, swingType)
  if event == "PLAYER_SWING" then
    if issecretvalue(swingType) or issecretvalue(duration) then return end
    local row = container.byType[swingType]
    if not row or duration <= 0 then return end
    if not row.available then
      row.available = true
      LayoutChangedWeapons(container)
    end
    row.duration:SetTimeFromStart(GetTime(), duration)
    row.fill:SetTimerDuration(row.duration, nil, Enum.StatusBarTimerDirection.RemainingTime)
    if swingType == SwingType.Ranged then
      row.swingSeconds = duration
      UpdateWindupZone(row, container.config)
    end
    row.binding:SetDuration(row.duration)
    row.fill:Show()
    if row.text:IsShown() then row.binding:Enable() end
  elseif event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_ATTACK_SPEED" or event == "PLAYER_REGEN_ENABLED" then
    if RefreshWeapons(container) then LayoutChangedWeapons(container) end
  elseif event == "PLAYER_LEAVE_COMBAT" then
    ClearRow(container.byType[SwingType.MainHand])
    ClearRow(container.byType[SwingType.OffHand])
  elseif event == "STOP_AUTOREPEAT_SPELL" then
    ClearRow(container.byType[SwingType.Ranged])
  else
    for _, row in ipairs(container.rows) do
      ClearRow(row)
    end
    if RefreshWeapons(container) then LayoutChangedWeapons(container) end
  end
end

function SwingTimer.Stop()
  local container = SwingTimer.container
  if not container or not container.active then return end
  container.active = false
  container.config = nil
  container:UnregisterAllEvents()
  container:Hide()
  for _, row in ipairs(container.rows) do
    ClearRow(row)
  end
end

function SwingTimer.Layout(parent, enabled, config)
  if not enabled then
    SwingTimer.Stop()
    return 0
  end

  local container = SwingTimer.container
  if not container then
    container = CreateRows(parent)
    SwingTimer.container = container
    container:SetScript("OnEvent", OnEvent)
    container.byType[SwingType.MainHand].available = true
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    formatter:AddBreakpoint({ threshold = 0, format = "%.1f" })
    for _, row in ipairs(container.rows) do
      row.duration = C_DurationUtil.CreateDuration()
      row.binding = ns.BarWidget.CreateDurationBinding(row.text)
      row.binding:SetFormatter(formatter)
    end
  end
  container.config = config
  if not container.active then
    container.active = true
    RefreshWeapons(container)
    FrameUtil.RegisterFrameForEvents(container, EVENTS)
    container:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    container:RegisterUnitEvent("UNIT_ATTACK_SPEED", "player")
  end
  container:ClearAllPoints()
  if config.detached then
    local anchor = config.anchor
    container:SetParent(UIParent)
    container:SetPoint(anchor.point, UIParent, anchor.point, anchor.x, anchor.y)
    container:SetWidth(ns.Pixel.Round(config.width))
  else
    container:SetParent(parent)
    container:SetPoint("BOTTOMLEFT")
    container:SetPoint("BOTTOMRIGHT")
  end
  local height = LayoutRows(container, config)
  container:SetHeight(height)
  container:Show()
  return config.detached and 0 or height + ROW_GAP
end

function SwingTimer.LayoutPreview(box, root, enabled, config, offset)
  local container = box.swingTimerPreview
  if not enabled then
    if container then container:Hide() end
    return 0
  end
  if not container then
    container = CreateRows(root)
    box.swingTimerPreview = container
    for index, row in ipairs(container.rows) do
      row.available = true
      row.fill:SetMinMaxValues(0, 1)
      row.fill:SetValue(1 - index * 0.2)
      row.fill:Show()
      row.text:SetText(string.format("%.1f", 4 - index))
    end
    container.byType[SwingType.Ranged].swingSeconds = 2.5
  end
  container:SetParent(root)
  container:ClearAllPoints()
  if config.detached then
    container:SetPoint("TOP", root, "TOP", 0, -offset - ROW_GAP)
    container:SetWidth(config.width)
  else
    container:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -offset - ROW_GAP)
    container:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, -offset - ROW_GAP)
  end
  local height = LayoutRows(container, config)
  container:SetHeight(height)
  container:Show()
  return height + ROW_GAP
end
