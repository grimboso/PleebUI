local addonName = ...
local pleebug = LibStub("LibPleebug-1")
pleebug:RegisterAddon(addonName, "Action Bars", {
  ActionBarsCore = "Action Bars Core",
  ActionButton = "Action Buttons",
  ActionBars = "Main and Additional Bars",
  PetActionBar = "Pet Bar",
  StanceActionBar = "Stance Bar",
  SpecialActionBar = "Extra, Zone and Vehicle Buttons",
  ActionBars_Preview = "Previews",
  ActionBars_config = "Settings",
}, 2)
