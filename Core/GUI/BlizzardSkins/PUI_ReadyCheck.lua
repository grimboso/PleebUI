local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_GroupFinder", "LFGReadyCheckPopup", function(popup)
  Skins.Panel(popup)
  Skins.Font(popup.Text, "header")
  Skins.Button(popup.YesButton)
  Skins.Button(popup.NoButton)
end)
