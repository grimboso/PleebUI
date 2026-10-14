local _, ns = ...
local Skins = ns.BlizzardSkins

local function InstallAlert(frame)
  Skins.Surface(frame)
  Skins.Font(frame.Unlocked, "tiny")
  Skins.Font(frame.Name)
  Skins.Icon(frame.Icon.Texture)
  Skins.Hide(frame.Icon.Overlay)
  Skins.Hide(frame.Icon.Bling)
end

local function PaintAlert(frame)
  Skins.Hide(frame.Background)
  frame.glow:SetVertexColor(1, 1, 1, 0)
  frame.shine:SetVertexColor(1, 1, 1, 0)
  Skins.Hide(frame.Icon.Overlay)
end

ns.NotificationSkins.Register("AchievementNotifications", "Achievement notifications", "AchievementAlertSystem",
  function(frame)
    InstallAlert(frame)
    Skins.Font(frame.GuildName)
  end,
  function(frame)
    PaintAlert(frame)
    ns.Theme.ApplyFont(frame.Shield.Points, "body")
  end)

ns.NotificationSkins.Register("AchievementProgressNotifications", "Achievement progress notifications", "CriteriaAlertSystem",
  InstallAlert, PaintAlert)
