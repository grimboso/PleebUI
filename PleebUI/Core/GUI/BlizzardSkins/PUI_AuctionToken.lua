local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.AuctionSkins

Skins.Register("Blizzard_AuctionHouseUI", "AuctionHouseFrame.WoWTokenResults", {
  install = function(frame)
    Skins.Chrome(frame)
    Templates.ItemDisplay(frame.TokenDisplay)
    Skins.Button(frame.Buyout, true)
    Skins.ScrollBar(frame.DummyScrollBar)
    Templates.Fonts(frame)
  end,
})

Skins.Register("Blizzard_AuctionHouseUI", "AuctionHouseFrame.WoWTokenSellFrame", {
  install = function(frame)
    Skins.Chrome(frame)
    Skins.Hide(frame.CreateAuctionTabLeft)
    Skins.Hide(frame.CreateAuctionTabMiddle)
    Skins.Hide(frame.CreateAuctionTabRight)
    Templates.ItemDisplay(frame.ItemDisplay)
    Skins.Button(frame.PostButton, true)
    Skins.Chrome(frame.DummyItemList)
    Skins.ScrollBar(frame.DummyItemList.DummyScrollBar)
    Templates.Fonts(frame)
  end,
})
