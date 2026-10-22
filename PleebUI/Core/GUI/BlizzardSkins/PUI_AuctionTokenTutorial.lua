local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_AuctionHouseUI", "AuctionHouseFrame.WoWTokenResults.GameTimeTutorial", {
  install = function(frame)
    Skins.Shell(frame)
    -- The illustrated instructions require their original background and contrast.
    for _, display in ipairs({ frame.LeftDisplay, frame.RightDisplay }) do
      for _, region in ipairs({ display:GetRegions() }) do
        if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
      end
    end
    Skins.Button(frame.RightDisplay.StoreButton, true)
  end,
})
