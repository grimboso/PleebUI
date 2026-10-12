local _, ns = ...
local Skins = ns.BlizzardSkins

local function FadeArtwork(frame, keep)
  Skins.Chrome(frame)
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("Texture") and not (keep and keep[region]) then Skins.Hide(region) end
  end
end

local function SkinHighlight(frame)
  local fill
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("Texture") then
      if not fill then
        fill = region
        Skins.Selection(fill)
        fill:SetAllPoints(frame)
        fill:SetAlpha(1)
      else
        Skins.Hide(region)
      end
    end
  end
end

local function SkinProgressBar(bar)
  FadeArtwork(bar, { [bar:GetStatusBarTexture()] = true })
  Skins.Bar(bar)
  Skins.Texts(bar)
end

local function SkinAchievementCard(card)
  if not Skins.CanStyle() then return end
  local keep = {}
  if card.Check then keep[card.Check] = true end
  if card.PlusMinus then keep[card.PlusMinus] = true end
  FadeArtwork(card, keep)
  local host = Skins.Surface(card, true, true)
  host:ClearAllPoints()
  host:SetPoint("TOPLEFT", card, "TOPLEFT", 2, -2)
  host:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -2, 2)
  if card.Highlight then
    SkinHighlight(card.Highlight)
  end
  if card.Icon then
    Skins.Hide(card.Icon.frame)
    Skins.Hide(card.Icon.bling)
    Skins.Icon(card.Icon.texture)
  end
  Skins.Texts(card)
  if card.Shield then Skins.Texts(card.Shield) end
  if card.Tracked then Skins.CheckBox(card.Tracked) end
  -- These templates repaint parchment and text when completed or recycled.
  if card.Init then Skins.Hook(card, "Init", SkinAchievementCard) end
  if card.Saturate then Skins.Hook(card, "Saturate", SkinAchievementCard) end
  if card.Desaturate then Skins.Hook(card, "Desaturate", SkinAchievementCard) end
end

local function SkinCategoryRow(row)
  if not Skins.CanStyle() then return end
  Skins.Button(row.Button, true)
  Skins.Font(row.Button.Label)
  Skins.Hook(row, "Init", SkinCategoryRow)
end

local function SkinStatRow(row)
  if not Skins.CanStyle() then return end
  FadeArtwork(row)
  Skins.Surface(row, true, true)
  Skins.Texts(row)
  Skins.Hook(row, "Init", SkinStatRow)
end

local function SkinComparisonRow(row)
  SkinAchievementCard(row.Player)
  SkinAchievementCard(row.Friend)
  Skins.Hook(row, "Init", SkinComparisonRow)
end

local function SkinSearchRow(row)
  if not Skins.CanStyle() then return end
  Skins.Button(row, true)
  Skins.Hide(row.IconFrame)
  Skins.Icon(row.Icon)
  Skins.Texts(row)
  Skins.Selection(row.SelectedTexture)
end

local function RefreshCriteria(objectives)
  if not Skins.CanStyle() then return end
  Skins.Font(objectives.RepCriteria)
  -- Use realized widgets, without querying or deriving achievement criteria state.
  for _, criterion in ipairs(objectives.criterias) do Skins.Font(criterion.Name) end
  for _, meta in ipairs(objectives.metas) do
    Skins.Font(meta.Label)
    Skins.Hide(meta.Border)
    Skins.Icon(meta.Icon)
  end
  for _, mini in ipairs(objectives.miniAchivements) do
    Skins.Hide(mini.Border)
    Skins.Icon(mini.Icon)
    Skins.Font(mini.Points)
  end
  for _, bar in ipairs(objectives.progressBars) do SkinProgressBar(bar) end
end

local function RefreshSummary()
  if not Skins.CanStyle() then return end
  for _, card in ipairs(AchievementFrameSummaryAchievements.buttons or {}) do SkinAchievementCard(card) end
end

local function RefreshSearchPreview()
  if not Skins.CanStyle() then return end
  local preview = AchievementFrame.HeaderDetails.Filters.SearchBox.SearchPreviewContainer
  for _, row in ipairs(preview.searchPreviews) do SkinSearchRow(row) end
  Skins.Button(preview.ShowAllSearchResults, true)
end

local function RefreshRows()
  Skins.ScrollRows(AchievementFrame.Categories.ScrollBox, SkinCategoryRow)
  Skins.ScrollRows(AchievementFrameAchievements.ScrollBox, SkinAchievementCard)
  Skins.ScrollRows(AchievementFrameStats.ScrollBox, SkinStatRow)
  Skins.ScrollRows(AchievementFrameComparison.AchievementContainer.ScrollBox, SkinComparisonRow)
  Skins.ScrollRows(AchievementFrameComparison.StatContainer.ScrollBox, SkinStatRow)
  Skins.ScrollRows(AchievementFrame.SearchResults.ScrollBox, SkinSearchRow)
  RefreshSummary()
  RefreshSearchPreview()
  RefreshCriteria(AchievementFrameAchievementsObjectives)
end

local function InstallAchievements(frame)
  FadeArtwork(frame, {
    [AchievementFrameGuildEmblemLeft] = true,
    [AchievementFrameGuildEmblemRight] = true,
  })
  Skins.Surface(frame)
  ns.Theme.WidgetSkins.CloseButton(AchievementFrameCloseButton)
  FadeArtwork(frame.Header, { [frame.Header.Shield] = true })
  Skins.Surface(frame.Header, false, true)
  Skins.Texts(frame.Header)
  FadeArtwork(frame.HeaderDetails)
  Skins.Button(frame.HeaderDetails.Back)
  Skins.Dropdown(frame.HeaderDetails.Filters.FilterDropdown)
  local search = frame.HeaderDetails.Filters.SearchBox
  Skins.EditBox(search)
  Skins.Panel(search.SearchPreviewContainer)
  for _, pane in ipairs({ frame.Categories, AchievementFrameAchievements, AchievementFrameStats,
    AchievementFrameSummary, AchievementFrameComparison }) do
    FadeArtwork(pane)
    Skins.Texts(pane)
    for _, child in ipairs({ pane:GetChildren() }) do
      if child.NineSlice then Skins.Chrome(child) end
    end
    Skins.ScrollBar(pane.ScrollBar)
  end
  FadeArtwork(AchievementFrameStatsBG)
  for _, header in ipairs({ AchievementFrameSummaryAchievementsHeader, AchievementFrameSummaryCategoriesHeader }) do
    FadeArtwork(header)
    Skins.Texts(header)
  end
  for _, tab in ipairs({ frame.Tab1, frame.Tab2, frame.Tab3 }) do Skins.Tab(tab) end
  Skins.Shell(frame.SearchResults)
  FadeArtwork(frame.SearchResults)
  Skins.ScrollBar(frame.SearchResults.ScrollBar)
  local comparison = AchievementFrameComparison
  FadeArtwork(AchievementFrameComparisonHeader, { [AchievementFrameComparisonHeaderPortrait] = true })
  Skins.Texts(AchievementFrameComparisonHeader)
  Skins.ScrollBar(comparison.AchievementContainer.ScrollBar)
  Skins.ScrollBar(comparison.StatContainer.ScrollBar)
  FadeArtwork(comparison.Summary)
  for _, side in ipairs({ comparison.Summary.Player, comparison.Summary.Friend }) do
    FadeArtwork(side)
    SkinProgressBar(side.StatusBar)
  end
  SkinProgressBar(AchievementFrameSummaryCategoriesStatusBar)
  for i = 1, 12 do
    local name = "AchievementFrameSummaryCategoriesCategory" .. i
    SkinProgressBar(_G[name])
    SkinHighlight(_G[name .. "ButtonHighlight"])
  end
  Skins.Hook(_G, "AchievementFrameSummary_UpdateAchievements", RefreshSummary)
  Skins.Hook(_G, "AchievementFrame_UpdateSearchPreview", RefreshSearchPreview)
  Skins.Hook(_G, "AchievementObjectives_DisplayCriteria", RefreshCriteria)
  Skins.Hook(_G, "AchievementObjectives_DisplayProgressiveAchievement", RefreshCriteria)
end

Skins.Register("Blizzard_AchievementUI", "AchievementFrame", {
  install = InstallAchievements,
  onShow = RefreshRows,
  onTheme = RefreshRows,
})
