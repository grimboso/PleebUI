local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_ItemUpgradeUI", "ItemUpgradeFrame", {
  install = function(frame)
    Skins.Shell(frame)
    for _, key in ipairs({ "BottomBG", "BottomBGShadow", "TopBG", "IdleGlow", "MicaFleckSheen" }) do
      Skins.Hide(frame[key])
    end
    Skins.Hide(frame.UpgradeCostFrame.BGTex)
    Skins.Hide(frame.PlayerCurrenciesBorder)
    Skins.Hide(frame.UpgradeItemButton.ButtonFrame)
    Skins.Surface(frame.UpgradeItemButton, true)
    Skins.Icon(frame.UpgradeItemButton.icon)
    Skins.Dropdown(frame.ItemInfo.Dropdown)
    Skins.Button(frame.UpgradeButton)
    Skins.Hide(frame.UpgradeButton.Glow)
    -- Comparison tooltips, quality borders, empty-slot cues and upgrade effects stay native.
    for _, text in ipairs({ frame.MissingDescription, frame.FrameErrorText,
      frame.LeftPreviewBigText, frame.RightPreviewBigText, frame.ItemInfo.MissingItemText,
      frame.ItemInfo.ItemName, frame.ItemInfo.UpgradeProgress, frame.ItemInfo.UpgradeTo }) do
      ns.Theme.ApplyFont(text, "body")
    end
  end,
})
