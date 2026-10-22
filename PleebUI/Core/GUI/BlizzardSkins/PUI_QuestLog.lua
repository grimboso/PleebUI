local _, ns = ...
local Skins = ns.BlizzardSkins
local styledQuestRows = setmetatable({}, { __mode = "k" })
local styledSessionDialogs = setmetatable({}, { __mode = "k" })
local eventBackgrounds = setmetatable({}, { __mode = "k" })
local sessionAtlases = {
  [Enum.QuestSessionCommand.Start] = "QuestSharing-DialogIcon",
  [Enum.QuestSessionCommand.Stop] = "QuestSharing-Stop-DialogIcon",
}

local layout = {
  Panel = { "QuestsFrame.ScrollFrame", "QuestsFrame.CampaignOverview", "MapLegend.ScrollFrame", "EventsFrame.ScrollBox" },
  StripRegions = { "DetailsFrame.BackFrame", "EventsFrame" },
  Hide = { "Background", "VerticalSeparator", "QuestsFrame.ScrollFrame.Edge", "QuestsFrame.ScrollFrame.Background",
    "QuestsFrame.ScrollFrame.Contents.Separator", "MapLegend.BorderFrame", "EventsFrame.BorderFrame", "QuestSessionManagement.BG" },
  Button = { "DetailsFrame.AbandonButton", "DetailsFrame.ShareButton", "DetailsFrame.TrackButton", "DetailsFrame.BackFrame.BackButton" },
  EditBox = { "QuestsFrame.ScrollFrame.SearchBox" },
  ScrollBar = { "QuestsFrame.ScrollFrame.ScrollBar", "QuestsFrame.CampaignOverview.ScrollFrame.ScrollBar",
    "DetailsFrame.ScrollFrame.ScrollBar", "MapLegend.ScrollFrame.ScrollBar", "EventsFrame.ScrollBar" },
  Font = { "MapLegend.TitleText", "EventsFrame.TitleText", "QuestSessionManagement.CommandText", "QuestSessionManagement.HelpText" },
}

local function HideQuestPortrait(frame)
  local portrait = QuestModelScene
  if frame:GetParent() == portrait:GetParent() then
    portrait:SetParent(nil)
    portrait:Hide()
  end
end

local function SkinStoryHeader(header)
  Skins.Hide(header.Background)
  Skins.Hide(header.TopFiligree)
  Skins.Hide(header.Divider)
  header.HighlightTexture:SetAllPoints(header.Background)
  header.HighlightTexture:SetAlpha(0)
  local collapse = header.CollapseButton
  if collapse then
    Skins.Surface(collapse, true)
    collapse:GetHighlightTexture():SetAlpha(0)
  end
end

local function RefreshQuestRows()
  for row in QuestScrollFrame.headerFramePool:EnumerateActive() do
    if row.ButtonText and not styledQuestRows[row] then
      Skins.StripRegions(row)
      Skins.Selection(row:GetHighlightTexture(), 0.25)
      Skins.Font(row.ButtonText, "header")
      styledQuestRows[row] = true
    end
  end
  for row in QuestScrollFrame.titleFramePool:EnumerateActive() do
    if not styledQuestRows[row] then
      if row.Checkbox then Skins.CheckBox(row.Checkbox) end
      styledQuestRows[row] = true
    end
  end
  for row in QuestScrollFrame.campaignHeaderFramePool:EnumerateActive() do
    if row.Text and not styledQuestRows[row] then
      Skins.Font(row.Text, "header")
      Skins.Font(row.Progress)
      styledQuestRows[row] = true
    end
  end
  for row in QuestScrollFrame.campaignHeaderMinimalFramePool:EnumerateActive() do
    if row.CollapseButton and not styledQuestRows[row] then
      Skins.StripRegions(row)
      Skins.Surface(row)
      Skins.Selection(row.Highlight, 0.75)
      styledQuestRows[row] = true
    end
  end
end

local function RefreshSessionCommand(frame, command)
  local button = frame.ExecuteSessionCommand
  Skins.Hide(button:GetNormalTexture())
  Skins.Hide(button:GetPushedTexture())
  Skins.Hide(button:GetDisabledTexture())
  local atlas = sessionAtlases[command]
  if atlas then button.normalIcon:SetAtlas(atlas) end
end

local function SkinSessionDialog(_, dialog)
  if styledSessionDialogs[dialog] then return end
  styledSessionDialogs[dialog] = true
  Skins.StripRegions(dialog)
  Skins.Button(dialog.ButtonContainer.Confirm)
  Skins.Button(dialog.ButtonContainer.Decline)
  if dialog.MinimizeButton then
    Skins.Arrow(dialog.MinimizeButton, "-")
  end
end

local function PositionQuestTab(tab, point, relativeTo, relativePoint, x, y)
  if x ~= 1 or y ~= 0 then
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", QuestMapFrame, "TOPRIGHT", 1, 0)
  end
end

local function PositionQuestTabIcon(icon, point, relativeTo)
  if relativeTo and point ~= "CENTER" then icon:SetPoint("CENTER") end
end

local function RefreshEventBackground(texture)
  local colors = ns.Theme.GetColors()
  texture:SetColorTexture(colors.background[1], colors.background[2], colors.background[3], 0.5)
  local row = texture:GetParent()
  if row and row.Highlight then Skins.Selection(row.Highlight, 0.2) end
end

local function SkinEventRow(_, row, elementData)
  local data = elementData.data
  if not data then return end
  if data.entryType == 1 or data.entryType == 3 then
    Skins.Surface(row)
    row.Label:SetTextColor(1, 1, 1)
  elseif data.entryType == 2 then
    if not eventBackgrounds[row.Background] then
      eventBackgrounds[row.Background] = true
      hooksecurefunc(row.Background, "SetAtlas", RefreshEventBackground)
    end
  elseif data.entryType == 4 and row.Highlight then
    Skins.Selection(row.Highlight, 0.2)
  end
end

local function InstallQuestLog(frame)
  frame:SetScript("OnHide", HideQuestPortrait)
  Skins.Apply(frame, layout)
  SkinStoryHeader(QuestScrollFrame.Contents.StoryHeader)

  local questScroll = frame.QuestsFrame.ScrollFrame
  local scrollBar = questScroll.ScrollBar
  questScroll.scrollBarX = 5
  scrollBar:ClearAllPoints()
  scrollBar:SetPoint("TOPLEFT", questScroll, "TOPRIGHT",
    questScroll.scrollBarX, questScroll.scrollBarTopY)
  scrollBar:SetPoint("BOTTOMLEFT", questScroll, "BOTTOMRIGHT",
    questScroll.scrollBarX, questScroll.scrollBarBottomY)

  local session = frame.QuestSessionManagement
  local command = session.ExecuteSessionCommand
  Skins.Surface(command, true)
  command.normalIcon = command:CreateTexture(nil, "ARTWORK")
  command.normalIcon:SetAllPoints(command)
  hooksecurefunc(session, "UpdateExecuteCommandAtlases", RefreshSessionCommand)
  hooksecurefunc(QuestSessionManager, "NotifyDialogShow", SkinSessionDialog)
  hooksecurefunc("QuestLogQuests_Update", RefreshQuestRows)

  for index, key in ipairs({ "QuestsTab", "EventsTab", "MapLegendTab" }) do
    local tab = frame[key]
    Skins.Panel(tab)
    tab:SetSize(40, 50)
    if index == 1 then
      tab:ClearAllPoints()
      tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 11, 24)
      hooksecurefunc(tab, "SetPoint", PositionQuestTab)
    end
    if tab.Icon then
      tab.Icon:ClearAllPoints()
      tab.Icon:SetPoint("CENTER")
      hooksecurefunc(tab.Icon, "SetPoint", PositionQuestTabIcon)
    end

    local selected = tab.SelectedTexture
    selected:ClearAllPoints()
    selected:SetAllPoints(tab)
    selected:SetDrawLayer("ARTWORK", -1)
    selected:SetBlendMode("BLEND")
    Skins.Selection(selected, 0.15)

    local highlight = tab.HighlightTexture
    highlight:ClearAllPoints()
    highlight:SetAllPoints(tab)
    highlight:SetBlendMode("BLEND")
    Skins.Selection(highlight, 0.08)

    Skins.Hide(tab.TabGlow)
  end
  if frame.EventsFrame then
    ScrollUtil.AddAcquiredFrameCallback(frame.EventsFrame.ScrollBox, SkinEventRow, frame.EventsFrame, true)
  end
end

Skins.Register("Blizzard_UIPanels_Game", "QuestMapFrame", {
  install = InstallQuestLog,
  installOnLoad = true,
  manageControls = false,
})
