local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.AuctionSkins

Skins.Register("Blizzard_AuctionHouseUI", "AuctionHouseFrame.BrowseResultsFrame", {
  install = function(frame) Templates.List(frame.ItemList) end,
  onShow = function(frame) Templates.ListRows(frame.ItemList) end,
})
