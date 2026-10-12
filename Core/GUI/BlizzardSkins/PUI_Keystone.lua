local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_ChallengesUI", "ChallengesKeystoneFrame", function(frame)
  Skins.StripRegions(frame)
  Skins.Texts(frame)
  Skins.Button(frame.StartButton)
  ns.Theme.WidgetSkins.CloseButton(frame.CloseButton)
  frame.KeystoneSlot.Texture:RemoveMaskTexture(frame.KeystoneSlot.CircleMask)
  Skins.IconButton(frame.KeystoneSlot, frame.KeystoneSlot.Texture)
end)
