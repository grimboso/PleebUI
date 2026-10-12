local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_ChallengesUI", "ChallengesKeystoneFrame", function(frame)
  -- Reset and the insertion animations restore alpha; remove their artwork itself.
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("Texture") then region:SetTexture(nil) end
  end
  Skins.StripRegions(frame)
  Skins.Texts(frame)
  Skins.Button(frame.StartButton)
  ns.Theme.WidgetSkins.CloseButton(frame.CloseButton)
  frame.KeystoneSlot.Texture:RemoveMaskTexture(frame.KeystoneSlot.CircleMask)
  Skins.IconButton(frame.KeystoneSlot, frame.KeystoneSlot.Texture)
end)
