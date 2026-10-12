local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_GroupFinder", "LFGDungeonReadyStatus", function(frame)
  Skins.Panel(frame)
  Skins.Font(LFGDungeonReadyStatusLabel, "header")
  ns.Theme.WidgetSkins.CloseButton(LFGDungeonReadyStatusCloseButton)
end)
