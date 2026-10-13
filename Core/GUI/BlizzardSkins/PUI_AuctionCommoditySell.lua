local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.AuctionSkins

Skins.Register("Blizzard_AuctionHouseUI", "AuctionHouseFrame.CommoditiesSellFrame", {
  install = function(frame)
    Skins.Chrome(frame)
    Skins.Hide(frame.CreateAuctionTabLeft)
    Skins.Hide(frame.CreateAuctionTabMiddle)
    Skins.Hide(frame.CreateAuctionTabRight)
    Templates.ItemDisplay(frame.ItemDisplay)
    Templates.Quantity(frame.QuantityInput)
    Templates.MoneyInputs(frame.PriceInput.MoneyInputFrame)
    Skins.Dropdown(frame.Duration.Dropdown)
    Skins.Button(frame.PostButton, true)
    Templates.Fonts(frame)
  end,
})

Skins.Register("Blizzard_AuctionHouseUI", "AuctionHouseFrame.CommoditiesSellList", {
  install = Templates.List,
  onShow = Templates.ListRows,
})
