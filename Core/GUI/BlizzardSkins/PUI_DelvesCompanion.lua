local _, ns = ...
local Skins = ns.BlizzardSkins
local Theme = ns.Theme

local function InstallOption(row)
  Theme.ApplyFont(row.Name, "body")
end

local function InstallSlot(slot)
  -- Native rings and label colors distinguish locked, empty and selected curios.
  Theme.ApplyFont(slot.Label, "body")
  Theme.ApplyFont(slot.Value, "body")
  local list = slot.OptionsList
  list:SetFrameStrata("HIGH")
  Skins.Hide(list.Top)
  Skins.Hide(list.Middle)
  Skins.Hide(list.Bottom)
  Skins.Surface(list)
  Skins.ScrollRows(list.ScrollBox, InstallOption, false)
end

Skins.Register("Blizzard_DelvesCompanionConfiguration", "DelvesCompanionConfigurationFrame", {
  label = "Delves companion",
  category = "Delves",
  install = function(frame)
    Skins.Panel(frame)
    Theme.WidgetSkins.CloseButton(frame.CloseButton)
    Skins.Hide(frame.CompanionInfoFrame.InfoFrameShadow)
    Skins.Hide(_G.CompanionInfoGLine)
    Skins.Font(frame.CompanionInfoFrame.CompanionName, "header")
    Skins.Font(frame.CompanionInfoFrame.CompanionDescription)
    Theme.ApplyFont(frame.CompanionLevelFrame.CompanionLevel, "header")
    Skins.Button(frame.CompanionConfigShowAbilitiesButton)
    local slots = frame.CompanionSlots
    InstallSlot(slots.CompanionCombatRoleSlot)
    InstallSlot(slots.CompanionFlavorSlot)
    InstallSlot(slots.CompanionCombatTrinketSlot)
    InstallSlot(slots.CompanionUtilityTrinketSlot)
  end,
})
