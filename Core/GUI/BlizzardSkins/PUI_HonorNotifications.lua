local _, ns = ...
local Skins = ns.BlizzardSkins

ns.NotificationSkins.Register("HonorNotifications", "Honor notifications", "HonorAwardedAlertSystem",
  function(frame)
    Skins.Surface(frame)
    Skins.Font(frame.Label)
    Skins.Font(frame.Amount)
    Skins.Icon(frame.Icon)
    Skins.Hide(frame.IconBorder)
  end,
  function(frame) Skins.Hide(frame.Background) end)
