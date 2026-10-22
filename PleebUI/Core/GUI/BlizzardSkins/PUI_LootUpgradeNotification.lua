local _, ns = ...
local Skins = ns.BlizzardSkins

ns.NotificationSkins.Register("LootUpgradeNotifications", "Item upgrade notifications", "LootUpgradeAlertSystem",
  function(frame)
    Skins.Surface(frame)
    Skins.Icon(frame.Icon)
    -- Quality colors, arrows and upgrade animations remain native.
    for _, text in ipairs({ frame.BaseQualityItemName, frame.UpgradeQualityItemName,
      frame.TitleText, frame.WhiteText, frame.WhiteText2 }) do
      ns.Theme.ApplyFont(text, "body")
    end
  end,
  function(frame) Skins.Hide(frame.Background) end)
