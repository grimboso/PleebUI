local addonName = ...
local pleebug = LibStub("LibPleebug-1")
pleebug:RegisterAddon(addonName, "PleebUI", {
  EditMode_QuickSettings = "Edit Mode Quick Settings",
  EditMode_TestMode = "Edit Mode Test Mode",
  PUI_UnitFramesDefaults = "Unit Frame Defaults",
  PUI_AuraWidget = "Aura Widgets",
  PUI_BarWidget = "Bar Widgets",
  PUI_Presentation = "Widget Presentation",
  PUI_MinimapData = "Minimap Data Buttons",
  PUI_Minimap = "Minimap",
  PUI_Dragonriding = "Skyriding",
  PUI_Chat = "Chat Settings",
  PUI_CharacterSheet = "Character Sheet",
  PUI_Bags = "Bags",
  PUI_EnchantTargets = "Enchant Targets",
}, 1)
pleebug.CPU:SetOverviewAddonName(addonName)
