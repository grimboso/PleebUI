local _, ns = ...
local Skins = ns.BlizzardSkins

local layout = {
  Hide = { "HonorFrame.BonusFrame.WorldBattlesTexture", "HonorFrame.BonusFrame.ShadowOverlay",
    "ConquestFrame.RatedBGTexture", "ConquestFrame.ShadowOverlay", "TrainingGroundsFrame.BonusTrainingGroundList.WorldBattlesTexture",
    "TrainingGroundsFrame.BonusTrainingGroundList.ShadowOverlay", "PlunderstormFrame.Background", "PVPQueueFrame.HonorInset.Background" },
  Panel = { "PlunderstormFrame.Inset", "PVPQueueFrame.HonorInset" },
  Dropdown = { "HonorFrame.TypeDropdown", "TrainingGroundsFrame.TypeDropdown" },
  Button = { "HonorFrame.QueueButton", "ConquestFrame.JoinButton", "TrainingGroundsFrame.QueueButton", "PlunderstormFrame.StartQueue",
    "PVPQueueFrame.HonorInset.PlunderstormPanel.PlunderstoreButton" },
  ScrollBar = { "HonorFrame.SpecificScrollBar", "TrainingGroundsFrame.SpecificTrainingGroundList.ScrollBar" },
}

local function SkinActivity(button)
  Skins.IconButton(button, button.Icon)
  Skins.Hide(button.Anchor)
  if button.NormalTexture then
    button.NormalTexture:SetTexture(nil)
  end
  Skins.Selection(button.SelectedTexture)
  Skins.Texts(button)
end

Skins.Register("Blizzard_PVPUI", "PVPQueueFrame", function(frame)
  Skins.Apply(_G, layout)
  for index = 1, 5 do
    local button = frame["CategoryButton" .. index]
    button.Background:SetAlpha(0.25)
    button:GetHighlightTexture():SetAlpha(0.12)
    ns.Theme.ApplyFont(button.Name, "header")
  end
  for _, key in ipairs({ "RatedSoloShuffle", "RatedBGBlitz", "Arena2v2", "Arena3v3", "RatedBG" }) do
    SkinActivity(ConquestFrame[key])
  end
  for _, key in ipairs({ "RandomBGButton", "RandomEpicBGButton", "Arena1Button", "BrawlButton", "BrawlButton2" }) do
    SkinActivity(HonorFrame.BonusFrame[key])
  end
  for _, key in ipairs({ "RandomTrainingGroundBGButton", "RandomTrainingGroundArenaButton" }) do
    SkinActivity(TrainingGroundsFrame.BonusTrainingGroundList[key])
  end
  for _, key in ipairs({ "CasualPanel", "RatedPanel", "PlunderstormPanel", "TrainingGroundsPanel" }) do
    Skins.Texts(frame.HonorInset[key])
  end
  Skins.ScrollRows(HonorFrame.SpecificScrollBox, SkinActivity)
  Skins.ScrollRows(TrainingGroundsFrame.SpecificTrainingGroundList.ScrollBox, SkinActivity)
end)
