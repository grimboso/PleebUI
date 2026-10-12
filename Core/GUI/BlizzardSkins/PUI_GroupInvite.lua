local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_GroupFinder", "LFGListInviteDialog", function(dialog)
  Skins.Panel(dialog)
  Skins.Button(dialog.AcceptButton)
  Skins.Button(dialog.DeclineButton)
  Skins.Button(dialog.AcknowledgeButton)
  Skins.Texts(dialog)
end)
