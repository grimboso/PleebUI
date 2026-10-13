local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.AuctionSkins

Skins.Register("Blizzard_AuctionHouseUI", "AuctionHouseFrame.BuyDialog", {
  install = function(frame)
    Skins.Panel(frame)
    for _, button in ipairs({ frame.BuyNowButton, frame.CancelButton, frame.OkayButton }) do Skins.Button(button, true) end
    Templates.Fonts(frame)
    -- Notification, expiry text, spinner and transaction-blocking overlays remain native.
  end,
})
