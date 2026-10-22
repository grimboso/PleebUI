local _, ns = ...
local Skins = ns.BlizzardSkins

local function PaintAlert(frame)
  Skins.Hide(frame.Background)
  Skins.Hide(frame.BGAtlas)
  Skins.Hide(frame.PvPBackground)
  Skins.Hide(frame.RatedPvPBackground)
  -- Native animations change alpha; vertex alpha suppresses only ornamental flashes.
  frame.glow:SetVertexColor(1, 1, 1, 0)
  frame.shine:SetVertexColor(1, 1, 1, 0)
  frame.lootItem.Icon:SetDrawLayer("ARTWORK")
end

ns.NotificationSkins.Register("LootNotifications", "Loot and currency notifications", "LootAlertSystem",
  function(frame)
    Skins.Surface(frame)
    Skins.Font(frame.Label)
    ns.Theme.ApplyFont(frame.ItemName, "body")
    ns.Theme.ApplyFont(frame.RollValue, "tiny")
    Skins.Font(frame.lootItem.Count, "tiny")
    Skins.Icon(frame.lootItem.Icon)
  end, PaintAlert)
