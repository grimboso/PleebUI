local _, ns = ...
local Skins = ns.BlizzardSkins

local layout = {
  Panel = { "QuestsFrame.ScrollFrame", "QuestsFrame.CampaignOverview", "DetailsFrame", "MapLegend.ScrollFrame",
    "EventsFrame.ScrollBox" },
  StripRegions = { "DetailsFrame.BackFrame", "DetailsFrame.RewardsFrameContainer.RewardsFrame", "EventsFrame" },
  Hide = { "Background", "VerticalSeparator", "QuestsFrame.ScrollFrame.Edge", "QuestsFrame.ScrollFrame.Background",
    "QuestsFrame.ScrollFrame.Contents.Separator", "DetailsFrame.SealMaterialBG", "MapLegend.BorderFrame", "EventsFrame.BorderFrame",
    "QuestSessionManagement.BG" },
  Button = { "DetailsFrame.AbandonButton", "DetailsFrame.ShareButton", "DetailsFrame.TrackButton", "DetailsFrame.BackFrame.BackButton" },
  EditBox = { "QuestsFrame.ScrollFrame.SearchBox" },
  ScrollBar = { "QuestsFrame.ScrollFrame.ScrollBar", "QuestsFrame.CampaignOverview.ScrollFrame.ScrollBar",
    "DetailsFrame.ScrollFrame.ScrollBar", "MapLegend.ScrollFrame.ScrollBar", "EventsFrame.ScrollBar" },
  Font = { "MapLegend.TitleText", "EventsFrame.TitleText", "QuestSessionManagement.CommandText", "QuestSessionManagement.HelpText" },
}

local function SkinQuestHeader(row)
  Skins.Hide(row.Background)
  Skins.Hide(row.TopFiligree)
  Skins.Hide(row.Divider)
  Skins.Surface(row, true)
  Skins.Texts(row)
end

local function RefreshQuestRows()
  if not Skins.CanStyle() then return end
  for _, pool in ipairs({ QuestScrollFrame.headerFramePool, QuestScrollFrame.campaignHeaderFramePool,
    QuestScrollFrame.campaignHeaderMinimalFramePool }) do
    for header in pool:EnumerateActive() do SkinQuestHeader(header) end
  end
  for row in QuestScrollFrame.titleFramePool:EnumerateActive() do
    for _, region in ipairs({ row:GetRegions() }) do
      if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
    end
    Skins.Surface(row, true)
    Skins.CheckBox(row.Checkbox)
  end
end

local function RefreshQuestDetails()
  if not Skins.CanStyle() then return end
  Skins.Texts(QuestMapFrame.DetailsFrame.ScrollFrame.Contents)
  Skins.Texts(QuestMapFrame.DetailsFrame.RewardsFrameContainer.RewardsFrame)
end

local function RefreshQuestLog(frame)
  Skins.Apply(frame, layout)
  Skins.Dropdown(frame.QuestsFrame.ScrollFrame.SettingsDropdown)
  for _, key in ipairs({ "QuestsTab", "EventsTab", "MapLegendTab" }) do
    local tab = frame[key]
    Skins.Surface(tab, true)
    Skins.Icon(tab.Icon)
    Skins.Selection(tab.SelectedTexture)
    Skins.Selection(tab.HighlightTexture)
    Skins.Hide(tab.TabGlow)
  end
  SkinQuestHeader(QuestScrollFrame.Contents.StoryHeader)
  RefreshQuestRows()
  RefreshQuestDetails()
  Skins.Hook(_G, "QuestLogQuests_Update", RefreshQuestRows)
  Skins.Hook(_G, "QuestMapFrame_ShowQuestDetails", RefreshQuestDetails)
end

Skins.Register("Blizzard_UIPanels_Game", "QuestMapFrame", RefreshQuestLog)
