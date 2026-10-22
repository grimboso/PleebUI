local _, ns = ...
local Skins = ns.BlizzardSkins

ns.NotificationSkins.Register("QuestNotifications", "World quest completion notifications", "WorldQuestCompleteAlertSystem",
  function(frame)
    Skins.Surface(frame)
    Skins.Font(frame.ToastText, "tiny")
    Skins.Font(frame.QuestName)
    Skins.Icon(frame.QuestTexture)
  end,
  function(frame)
    Skins.Hide(frame.ToastBackground)
    frame.shine:SetVertexColor(1, 1, 1, 0)
  end)
