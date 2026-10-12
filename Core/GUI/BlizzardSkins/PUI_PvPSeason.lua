local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_PVPUI", "PVPQueueFrame.NewSeasonPopup", function(popup)
  Skins.StripRegions(popup)
  Skins.Texts(popup)
  Skins.Button(popup.Leave)
end)
