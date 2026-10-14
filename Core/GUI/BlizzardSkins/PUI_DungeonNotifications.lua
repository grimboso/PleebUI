local _, ns = ...
local Skins = ns.BlizzardSkins

ns.NotificationSkins.Register("DungeonNotifications", "Dungeon completion notifications", "DungeonCompletionAlertSystem",
  function(frame)
    Skins.Surface(frame)
    Skins.Font(frame.completionText, "tiny")
    Skins.Font(frame.instanceName)
    Skins.Icon(frame.dungeonTexture)
  end,
  function(frame)
    Skins.Hide(frame.raidArt)
    Skins.Hide(frame.dungeonArt)
    frame.shine:SetVertexColor(1, 1, 1, 0)
    frame.glowFrame.glow:SetVertexColor(1, 1, 1, 0)
  end)
