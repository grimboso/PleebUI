local ns = LibStub("AceAddon-3.0"):GetAddon("PleebUI").ModuleNamespace

local class = UnitClassBase("player")
local Extras = {
  hasFormMana = ns.Client.IsForever and class == "DRUID",
  hasTotems = ns.Client.IsForever and class == "SHAMAN",
}
ns.PRDForeverExtras = Extras

local GAP = 2
local MANA_HEIGHT = 5
local ICON_SIZE = 24
local ICON_GAP = 3
local MANA = Enum.PowerType.Mana
local TRACKER = ns.TotemTracker

local function WantsFormMana(profile)
  if not Extras.hasFormMana or profile.primary.hideAlternateMana then return false end
  local form = GetShapeshiftFormID()
  return form == DRUID_CAT_FORM or form == DRUID_BEAR_FORM
end

local function UpdateMana(bar, event, _, token)
  if event and token ~= "MANA" then return end
  if event ~= "UNIT_POWER_UPDATE" then
    bar:SetMinMaxValues(0, UnitPowerMax("player", MANA))
  end
  bar:SetValue(UnitPower("player", MANA))
end

local function CreateManaBar(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar.background = bar:CreateTexture(nil, "BACKGROUND")
  bar.background:SetAllPoints()
  local color = PowerBarColor.MANA
  bar:SetStatusBarColor(color.r, color.g, color.b)
  return bar
end

local function StyleManaBar(bar, profile)
  local config = profile.primary
  bar:SetStatusBarTexture(ns.BarWidget.ResolveStatusBarTexture(config.texture))
  bar.background:SetColorTexture(unpack(config.style.bgColor))
end

local function CreateTotemRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  local count = GetNumTotemSlots()
  row.icons = {}
  for slot = 1, count do
    local cell = CreateFrame("Frame", nil, row)
    cell:SetSize(ICON_SIZE, ICON_SIZE)
    cell:SetPoint("CENTER", row, "CENTER", (slot - (count + 1) / 2) * (ICON_SIZE + ICON_GAP), 0)
    local background = cell:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.08, 0.08, 0.8)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetAllPoints()
    cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell.text:SetPoint("CENTER")
    row.icons[slot] = cell
  end
  return row
end

local function UpdateTotems(row)
  for slot, cell in ipairs(row.icons) do
    local totem = TRACKER.activeSlots[slot]
    cell.icon:SetShown(totem ~= nil)
    if totem then
      cell.icon:SetTexture(totem.icon or 134400)
      if cell.duration ~= totem.duration then
        cell.duration = totem.duration
        cell.binding:SetDuration(totem.duration)
        cell.binding:Enable()
      end
    elseif cell.duration then
      cell.duration = nil
      cell.binding:Disable()
      cell.text:SetText("")
    end
  end
end

local function StopMana()
  local bar = Extras.mana
  if bar and bar:IsShown() then
    bar:UnregisterAllEvents()
    bar:Hide()
  end
end

local function StopTotems()
  local row = Extras.totems
  if row and row:IsShown() then
    TRACKER:UnregisterListener(row)
    for _, cell in ipairs(row.icons) do
      cell.duration = nil
      cell.binding:Disable()
      cell.text:SetText("")
    end
    row:Hide()
  end
end

function Extras.Stop()
  StopMana()
  StopTotems()
end

function Extras.RefreshManaStyle(profile)
  local bar = Extras.mana
  if bar and bar:IsShown() then
    StyleManaBar(bar, profile)
  end
end

function Extras.RefreshManaVisibility(owner)
  if not Extras.hasFormMana or not owner._puiRuntimeStarted then return end
  local shown = Extras.mana ~= nil and Extras.mana:IsShown()
  if shown ~= WantsFormMana(owner.db.profile) then
    owner:ApplyLayout()
  end
end

local function AnchorRow(row, parent, point, offset, height)
  row:ClearAllPoints()
  row:SetPoint(point .. "LEFT", parent, point .. "LEFT", 0, offset)
  row:SetPoint(point .. "RIGHT", parent, point .. "RIGHT", 0, offset)
  row:SetHeight(height)
end

function Extras.Layout(owner, profile, swingHeight)
  local extraHeight = 0
  if owner._puiRuntimeStarted and Extras.hasTotems and profile.showTotems then
    local row = Extras.totems
    if not row then
      row = CreateTotemRow(owner.frame)
      row:Hide()
      for _, cell in ipairs(row.icons) do
        cell.binding = ns.BarWidget.CreateDurationBinding(cell.text)
      end
      Extras.totems = row
    end
    AnchorRow(row, owner.frame, "BOTTOM", swingHeight, ICON_SIZE)
    if not row:IsShown() then
      row:Show()
      TRACKER:RegisterListener(row, UpdateTotems, true)
    end
    extraHeight = ICON_SIZE + GAP
  else
    StopTotems()
  end

  if owner._puiRuntimeStarted and WantsFormMana(profile) then
    local bar = Extras.mana
    if not bar then
      bar = CreateManaBar(owner.frame)
      bar:Hide()
      bar:SetScript("OnEvent", UpdateMana)
      Extras.mana = bar
    end
    AnchorRow(bar, owner.frame, "BOTTOM", swingHeight + extraHeight, MANA_HEIGHT)
    StyleManaBar(bar, profile)
    if not bar:IsShown() then
      bar:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
      bar:RegisterUnitEvent("UNIT_MAXPOWER", "player")
      UpdateMana(bar)
      bar:Show()
    end
    extraHeight = extraHeight + MANA_HEIGHT + GAP
  else
    StopMana()
  end
  return extraHeight
end

function Extras.LayoutPreview(box, root, profile, offset)
  local height = 0
  if WantsFormMana(profile) then
    local bar = box.foreverMana
    if not bar then
      bar = CreateManaBar(root)
      bar:SetMinMaxValues(0, 100)
      bar:SetValue(65)
      box.foreverMana = bar
    end
    StyleManaBar(bar, profile)
    AnchorRow(bar, root, "TOP", -offset - GAP, MANA_HEIGHT)
    bar:Show()
    height = MANA_HEIGHT + GAP
  elseif box.foreverMana then
    box.foreverMana:Hide()
  end
  if Extras.hasTotems and profile.showTotems then
    local row = box.foreverTotems
    if not row then
      row = CreateTotemRow(root)
      box.foreverTotems = row
      local spells = { 8071, 5394, 3599, 8512 }
      for slot, cell in ipairs(row.icons) do
        local spellID = spells[slot]
        if spellID then
          cell.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
          cell.text:SetText(tostring(12 * slot))
        end
      end
    end
    AnchorRow(row, root, "TOP", -offset - height - GAP, ICON_SIZE)
    row:Show()
    height = height + ICON_SIZE + GAP
  elseif box.foreverTotems then
    box.foreverTotems:Hide()
  end
  return height
end
