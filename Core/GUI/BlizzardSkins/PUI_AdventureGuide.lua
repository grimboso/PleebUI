local _, ns = ...
local Skins = ns.BlizzardSkins

local layout = {
  Panel = { "inset", "MonthlyActivitiesFrame.FilterList",
    "TutorialsFrame.Contents", "searchResults" },
  StripRegions = { "encounter.info", "LootJournal", "LootJournalItems", "JourneysFrame" },
  Hide = { "searchResults.leftBorderBar", "instanceSelect.bg", "instanceSelect.evergreenBg", "encounter.info.leftShadow", "encounter.info.rightShadow",
    "encounter.info.model.dungeonBG", "encounter.instance.titleBG", "JourneysFrame.BorderFrame", "MonthlyActivitiesFrame.Bg",
    "MonthlyActivitiesFrame.Divider", "MonthlyActivitiesFrame.DividerVertical", "MonthlyActivitiesFrame.ThemeContainer",
    "MonthlyActivitiesFrame.ShadowLeft", "MonthlyActivitiesFrame.ShadowRight",
    "MonthlyActivitiesFrame.ThresholdContainer.BarBackground", "MonthlyActivitiesFrame.ThresholdContainer.BarBorder" },
  EditBox = { "searchBox" },
  Dropdown = { "LootJournalViewDropdown", "instanceSelect.ExpansionDropdown", "encounter.info.difficulty", "encounter.info.LootContainer.filter",
    "encounter.info.LootContainer.slotFilter", "LootJournal.ClassDropdown", "LootJournal.RuneforgePowerDropdown",
    "LootJournalItems.ItemSetsFrame.ClassDropdown" },
  ScrollBar = { "instanceSelect.ScrollBar", "encounter.info.BossesScrollBar", "encounter.instance.LoreScrollBar",
    "encounter.info.overviewScroll.ScrollBar", "encounter.info.detailsScroll.ScrollBar", "encounter.info.LootContainer.ScrollBar",
    "LootJournal.ScrollBar", "LootJournalItems.ItemSetsFrame.ScrollBar", "JourneysFrame.ScrollBar", "MonthlyActivitiesFrame.ScrollBar",
    "MonthlyActivitiesFrame.FilterList.ScrollBar", "searchResults.ScrollBar" },
  Tab = { "JourneysTab", "MonthlyActivitiesTab", "suggestTab", "dungeonsTab", "raidsTab", "LootJournalTab", "TutorialsTab" },
  Button = { "TutorialsFrame.Contents.StartButton", "suggestFrame.Suggestion1.button",
    "suggestFrame.Suggestion2.centerDisplay.button", "suggestFrame.Suggestion3.centerDisplay.button",
    "JourneysFrame.JourneyProgress.OverviewBtn", "JourneysFrame.JourneyOverview.OverviewBtn",
    "JourneysFrame.JourneyProgress.LevelSkipButton" },
  Bar = { "MonthlyActivitiesFrame.ThresholdContainer.ThresholdBar", "JourneysFrame.JourneyProgress.DelveRewardProgressBar" },
  Font = { "encounter.info.detailsScroll.child.description", "encounter.info.overviewScroll.child.loreDescription",
    "encounter.info.overviewScroll.child.overviewDescription.Text", "TutorialsFrame.Contents.Header", "TutorialsFrame.Contents.Description" },
}

local function SkinLootRow(row)
  Skins.Hide(row.bossTexture)
  Skins.Hide(row.bosslessTexture)
  Skins.Surface(row, true)
  Skins.Icon(row.icon)
  Skins.Texts(row)
end

local function SkinGuideRow(row)
  Skins.Surface(row, true)
  Skins.Texts(row)
  if row:IsObjectType("Button") then Skins.IconButton(row, row.Icon) end
  if row.WatchedFactionToggleFrame then
    Skins.CheckBox(row.WatchedFactionToggleFrame.WatchFactionCheckbox)
  end
  if row.JourneyCardProgressBar then Skins.Bar(row.JourneyCardProgressBar) end
end

local function RefreshGuide(frame)
  Skins.Shell(frame)
  Skins.Apply(frame, layout)
  Skins.Navigation(frame.navBar)
  Skins.ScrollRows(frame.instanceSelect.ScrollBox, SkinGuideRow)
  Skins.ScrollRows(frame.encounter.info.BossesScrollBox, SkinGuideRow)
  Skins.ScrollRows(frame.encounter.info.LootContainer.ScrollBox, SkinLootRow)
  Skins.ScrollRows(frame.JourneysFrame.JourneysList, SkinGuideRow)
  Skins.ScrollRows(frame.MonthlyActivitiesFrame.ScrollBox, SkinGuideRow)
  Skins.ScrollRows(frame.MonthlyActivitiesFrame.FilterList.ScrollBox, SkinGuideRow)
  Skins.ScrollRows(frame.LootJournal.ScrollBox, SkinGuideRow)
  Skins.ScrollRows(frame.LootJournalItems.ItemSetsFrame.ScrollBox, SkinGuideRow)
  for _, key in ipairs({ "overviewTab", "lootTab", "bossTab", "modelTab" }) do
    local tab = frame.encounter.info[key]
    -- The normal texture carries the tab pictogram; retain it inside a square holder.
    Skins.Surface(tab, true)
    Skins.Hide(tab:GetPushedTexture())
  end
  for index = 1, 3 do
    local suggestion = frame.suggestFrame["Suggestion" .. index]
    Skins.Hide(suggestion.bg)
    Skins.Surface(suggestion)
    Skins.Font(suggestion.centerDisplay.title.text, "header")
    Skins.Font(suggestion.centerDisplay.description.text)
    Skins.Hide(suggestion.reward.iconRing)
    Skins.Hide(suggestion.reward.iconRingHighlight)
  end
end

Skins.Register("Blizzard_EncounterJournal", "EncounterJournal", RefreshGuide)
