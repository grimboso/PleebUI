local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.AuctionSkins

Skins.Register("Blizzard_AuctionHouseUI", "AuctionHouseFrame.ItemBuyFrame", {
  install = function(frame)
    Skins.Button(frame.BackButton, true)
    Templates.ItemDisplay(frame.ItemDisplay)
    Skins.Button(frame.BuyoutFrame.BuyoutButton, true)
    Skins.Button(frame.BidFrame.BidButton, true)
    Templates.MoneyInputs(frame.BidFrame.BidAmount)
    Templates.List(frame.ItemList)
  end,
  onShow = function(frame) Templates.ListRows(frame.ItemList) end,
})
