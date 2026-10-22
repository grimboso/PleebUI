local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.AuctionSkins

Skins.Register("Blizzard_AuctionHouseUI", "AuctionHouseFrame.CommoditiesBuyFrame", {
  install = function(frame)
    Skins.Button(frame.BackButton, true)
    local display = frame.BuyDisplay
    Skins.Chrome(display)
    Templates.ItemDisplay(display.ItemDisplay)
    Templates.Quantity(display.QuantityInput)
    Skins.Button(display.BuyButton, true)
    Templates.Fonts(display.UnitPrice)
    Templates.Fonts(display.TotalPrice)
    Templates.List(frame.ItemList)
  end,
  onShow = function(frame) Templates.ListRows(frame.ItemList) end,
})
