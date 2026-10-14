local _, ns = ...
local Skins = ns.BlizzardSkins

local layout = {
  Panel = { "QuestsFrame.ScrollFrame", "QuestsFrame.CampaignOverview", "MapLegend.ScrollFrame",
    "EventsFrame.ScrollBox" },
  StripRegions = { "DetailsFrame.BackFrame", "EventsFrame" },
  Hide = { "Background", "VerticalSeparator", "QuestsFrame.ScrollFrame.Edge", "QuestsFrame.ScrollFrame.Background",
    "QuestsFrame.ScrollFrame.Contents.Separator", "MapLegend.BorderFrame", "EventsFrame.BorderFrame",
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

local function SkinQuestHeaderSurface(row, bottomInset)
  local host = Skins.Surface(row, false, true)
  -- Campaign headers resize from their children; the backdrop must not affect layout.
  host.ignoreInLayout = true
  host:ClearAllPoints()
  host:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  host:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, bottomInset)
  host:SetWidth(QuestScrollFrame.Contents:GetWidth() - 4)
  return host
end

local function SkinQuestHeader(row)
  Skins.Hide(row.Background)
  Skins.Hide(row.TopFiligree)
  Skins.Hide(row.Divider)
  if row:IsObjectType("Button") and row.CollapseButton then
    Skins.Button(row, true)
    Skins.Hook(row, "CheckHighlightTitle", RefreshHeaderTitle)
  end
  local host = SkinQuestHeaderSurface(row, row.LoreButton and 10 or 0)
  if row.LoreButton then
    Skins.Selection(row.SelectedHighlight, 0.07)
    row.SelectedHighlight:SetAllPoints(host)
    Skins.Selection(row.HighlightTexture, 0.05)
    row.HighlightTexture:SetAllPoints(host)
  end
  if row.CollapseButton then
    Skins.Button(row.CollapseButton)
    RefreshHeaderCollapse(row.CollapseButton)
    Skins.Hook(row.CollapseButton, "UpdateCollapsedState", RefreshHeaderCollapse)
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
end

local function RefreshQuestDetails()
  if not Skins.CanStyle() then return end
  local details = QuestMapFrame.DetailsFrame
  if not details:IsShown() or not QuestInfoFrame.questLog then return end
  details.Bg:SetAtlas(QuestTextContrast.GetDefaultDetailsBackgroundAtlas())
  details:AdjustBackgroundTexture(details.Bg)
  QuestInfo_Display(QUEST_TEMPLATE_MAP_DETAILS, details.ScrollFrame.Contents)
  QuestInfo_Display(QUEST_TEMPLATE_MAP_REWARDS, details.RewardsFrameContainer.RewardsFrame, nil, nil, true)
end

local function RefreshQuestLog(frame)
  Skins.Apply(frame, layout)
  Skins.Dropdown(frame.QuestsFrame.ScrollFrame.SettingsDropdown)
  for _, key in ipairs({ "QuestsTab", "EventsTab", "MapLegendTab" }) do
    local tab = frame[key]
    Skins.Panel(tab)
    Skins.Icon(tab.Icon)
    Skins.Selection(tab.SelectedTexture, 0.08)
    Skins.Selection(tab.HighlightTexture, 0.05)
    Skins.Hide(tab.TabGlow)
  end
  SkinQuestHeader(QuestScrollFrame.Contents.StoryHeader)
  RefreshQuestRows()
  RefreshQuestDetails()
  Skins.Hook(_G, "QuestLogQuests_Update", RefreshQuestRows)
  if not frame.__puiQuestAccessibilityRegistered then
    frame.__puiQuestAccessibilityRegistered = true
    CVarCallbackRegistry:RegisterCallback("questTextContrast", RefreshQuestDetails, frame)
    EventRegistry:RegisterCallback("TextSizeManager.OnTextScaleUpdated", RefreshQuestDetails, frame)
  end
end

Skins.Register("Blizzard_UIPanels_Game", "QuestMapFrame", RefreshQuestLog)
