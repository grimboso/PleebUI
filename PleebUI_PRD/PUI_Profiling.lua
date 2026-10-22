local addonName = ...
local pleebug = LibStub("LibPleebug-1")
pleebug:RegisterAddon(addonName, "Resource Display", {
  PUI_PRD_AuraSlotDriver = "Aura Slot Updates",
  PUI_PRD_AuraWidget = "Aura Widgets",
  PUI_PRD = "Resource Display Core",
  PUI_PRD_Primary = "Primary Bars",
  PUI_PRD_Secondary_Registry = "Resource Definitions",
  PUI_PRD_Secondary = "Secondary Resource Frames",
  PUI_PRD_Secondary_Power = "Class Power",
  PUI_PRD_Secondary_AuraStacks = "Aura Stacks",
  PUI_PRD_Secondary_SpellCount = "Spell Counts",
  PUI_PRD_Secondary_Stagger = "Stagger",
  PUI_PRD_Secondary_Runes = "Runes",
  PUI_PRD_Secondary_Essence = "Essence",
  PUI_PRD_Secondary_Core = "Resource Events and Updates",
  PUI_PRD_Config = "Settings and Previews",
}, 4)
