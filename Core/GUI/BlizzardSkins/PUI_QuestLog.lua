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

local function RefreshHeaderCollapse(button)
  if not Skins.CanStyle() then return end
  local collapsed = button.collapsed
  if issecretvalue(collapsed) then return end
  ns.Theme.ApplyExpandCollapseTexture(button.Icon, not collapsed)
  local highlight = button:GetHighlightTexture()
  highlight:SetColorTexture(1, 1, 1, 0.12)
  highlight:SetAlpha(1)
  highlight:SetAllPoints(button)
end

local function RefreshHeaderTitle(row)
  if Skins.CanStyle() then Skins.Font(row:GetTitleRegion(), "header") end
end

local function SkinQuestHeader(row)
  Skins.Hide(row.Background)
  Skins.Hide(row.TopFiligree)
  Skins.Hide(row.Divider)
  if row:IsObjectType("Button") and row.CollapseButton then
    Skins.Button(row)
    Skins.Button(row.CollapseButton)
    RefreshHeaderCollapse(row.CollapseButton)
    Skins.Hook(row.CollapseButton, "UpdateCollapsedState", RefreshHeaderCollapse)
    Skins.Hook(row, "CheckHighlightTitle", RefreshHeaderTitle)
  else
    Skins.Surface(row, true)
  end
  Skins.Texts(row)
  if row.CheckHighlightTitle then RefreshHeaderTitle(row) end
end

local function RefreshQuestRows()
  if not Skins.CanStyle() then return end
  for _, pool in ipairs({ QuestScrollFrame.headerFramePool, QuestScrollFrame.campaignHeaderFramePool,
    QuestScrollFrame.campaignHeaderMinimalFramePool, QuestScrollFrame.covenantCallingsHeaderFramePool }) do
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
    Skins.Panel(tab)
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
