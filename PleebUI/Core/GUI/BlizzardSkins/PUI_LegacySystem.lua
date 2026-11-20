local _, ns = ...
if not ns.Client.IsForever then return end
local Skins = ns.BlizzardSkins
local rewardCards = setmetatable({}, { __mode = "k" })

local layout = {
  Hide = { "RewardTrackPage.Background", "RewardTrackPage.ProgressBarBackground", "RewardTrackPage.LegacyRewardProgressBar.ProgressBarFrame",
    "ChallengesPage.Background", "ChallengesPage.VerticalDivider", "ChallengesPage.LegacyChallengePointSummary.ProgressBarBackground",
    "ChallengesPage.LegacyChallengePointSummary.PointsBar.ProgressBarFrame", "TreePage.Background", "TreePage.VerticalDivider" },
  Bar = { "RewardTrackPage.LegacyRewardProgressBar", "ChallengesPage.LegacyChallengePointSummary.PointsBar" },
  Font = { "RewardTrackPage.Points", "RewardTrackPage.PointsLabel", "RewardTrackPage.LegacyRewardProgressBar.Text",
    "ChallengesPage.CategoryList.NoResultsText", "ChallengesPage.LegacyChallengePointSummary.PointsBar.Text",
    "ChallengesPage.LegacyChallengePointSummary.Shield.Points", "TreePage.LegacyTreePointSummary.AvailablePointsLabel",
    "TreePage.LegacyTreePointSummary.Shield.Points", "TreePage.LegacyTreeTraitPanel.SelectedTreeIcon.SelectedTreeLabel",
    "TreePage.LegacyTreeTraitPanel.SpentPointsFrame.Text" },
  Panel = { "ChallengesPage.CategoryList", "ChallengesPage.DetailPane" },
  EditBox = { "ChallengesPage.CategoryList.SearchBox", "TreePage.LegacyTreeTraitPanel.SearchBox" },
  Dropdown = { "ChallengesPage.CategoryList.FilterDropdown" },
  Button = { "TreePage.LegacyTreeTraitPanel.ApplyButton", "TreePage.LegacyTreeTraitPanel.ResetButton", "TreePage.LegacyTreeTraitPanel.UndoButton" },
  ScrollBar = { "ChallengesPage.CategoryList.ScrollBar", "ChallengesPage.DetailPane.ScrollBar" },
}

local function RepaintRow(row)
  for _, region in ipairs({ row:GetRegions() }) do
    if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
  end
end

local function SkinCategory(row)
  Skins.Hide(row.Background)
  Skins.Surface(row, true)
  RepaintRow(row)
end

local function SkinChallenge(row)
  Skins.Hide(row.Background)
  Skins.Hide(row.BackgroundMiddle)
  Skins.Hide(row.BackgroundTop)
  Skins.Hide(row.BackgroundBottom)
  Skins.Hide(row.TitleBar)
  Skins.Surface(row, true)
  Skins.Selection(row.SelectedOverlay)
  Skins.Hide(row.Icon.frame)
  row.Icon.texture:RemoveMaskTexture(row.Icon.TextureMask)
  Skins.Icon(row.Icon.texture)
  Skins.Surface(row.Icon, true)
  RepaintRow(row)
  RepaintRow(row.Shield)
end

local function RepaintReward(card)
  Skins.Hide(card.RewardCardBG)
  Skins.Hide(card.LevelSquare)
  Skins.Hide(card.IconBorder)
  RepaintRow(card)
end

local function SkinRewards(page)
  local cards = page.LegacyRewardProgressFrame:GetElements()
  if not cards then return end
  for _, card in ipairs(cards) do
    if not rewardCards[card] then
      rewardCards[card] = true
      Skins.Surface(card, true)
      Skins.Icon(card.Icon)
    end
    RepaintReward(card)
  end
end

local function PaintLegacy(frame)
  Skins.Shell(frame)
  Skins.Apply(frame, layout)
end

Skins.Register("Blizzard_LegacySystem", "LegacySystemFrame", {
  label = "Progress Legacy", category = "Character & items",
  install = function(frame)
    PaintLegacy(frame)
    for _, tab in ipairs(frame.Tabs) do Skins.SideTab(tab) end
    Skins.ScrollRows(frame.ChallengesPage.CategoryList.ScrollBox, SkinCategory, RepaintRow)
    Skins.ScrollRows(frame.ChallengesPage.DetailPane.ScrollBox, SkinChallenge, RepaintRow)
    SkinRewards(frame.RewardTrackPage)
    Skins.Hook(frame.RewardTrackPage, "SetupRewardTrack", SkinRewards)
    local progress = frame.RewardTrackPage.LegacyRewardProgressFrame
    Skins.Arrow(progress.LeftButton, "<")
    Skins.Arrow(progress.RightButton, ">")
    Skins.Arrow(progress.JumpLeftButton, "<<")
    Skins.Arrow(progress.JumpRightButton, ">>")
  end,
  onTheme = PaintLegacy,
})
