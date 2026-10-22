local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.AuctionSkins

local function RefreshLists(frame)
  for _, list in ipairs({ frame.AllAuctionsList, frame.BidsList, frame.ItemList, frame.CommoditiesList }) do Templates.ListRows(list) end
  Skins.ScrollRows(frame.SummaryList.ScrollBox, Templates.Fonts, Templates.Fonts)
end

Skins.Register("Blizzard_AuctionHouseUI", "AuctionHouseFrame.AuctionsFrame", {
  install = function(frame)
    Skins.Tab(frame.AuctionsTab)
    Skins.Tab(frame.BidsTab)
    frame.BidsTab:ClearAllPoints()
    frame.BidsTab:SetPoint("LEFT", frame.AuctionsTab, "RIGHT", 4, 0)
    Templates.ItemDisplay(frame.ItemDisplay)
    Skins.Button(frame.CancelAuctionButton, true)
    Skins.Button(frame.BuyoutFrame.BuyoutButton, true)
    Skins.Button(frame.BidFrame.BidButton, true)
    Templates.MoneyInputs(frame.BidFrame.BidAmount)
    Skins.Chrome(frame.SummaryList)
    Skins.Surface(frame.SummaryList.ScrollBox, true, true)
    Skins.ScrollBar(frame.SummaryList.ScrollBar)
    for _, list in ipairs({ frame.AllAuctionsList, frame.BidsList, frame.ItemList, frame.CommoditiesList }) do Templates.List(list) end
  end,
  onShow = RefreshLists,
})
