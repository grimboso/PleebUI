local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_WeeklyRewards", "WeeklyRewardExpirationWarningDialog", {
  install = function(frame)
    Skins.Panel(frame)
    ns.Theme.ApplyFont(frame.Description, "body")
  end,
})
