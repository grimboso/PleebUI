local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_AuctionHouseUI", "AuctionHouseMultisellProgressFrame", {
  install = function(frame)
    for _, key in ipairs({ "Fill", "Left", "Middle", "Right" }) do Skins.Hide(frame[key]) end
    Skins.Surface(frame)
    Skins.Bar(frame.ProgressBar)
    Skins.Hide(frame.ProgressBar.TextBorder)
    Skins.Font(frame.ProgressBar.Text)
    -- Native progress values, item icon and cancel glyph remain unchanged.
  end,
})
