local addonName = ...
local pleebug = LibStub("LibPleebug-1")
pleebug:RegisterAddon(addonName, "Combat Tools", {
  PUI_HunterTools = "Hunter Tools",
  PUI_MovementWarning = "Movement Warnings",
  PUI_RaidUtility = "Group Utility",
}, 6)
