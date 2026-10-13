local _, ns = ...
local Skins = ns.BlizzardSkins
local achievementCards = setmetatable({}, { __mode = "k" })
local achievementRows = setmetatable({}, { __mode = "k" })

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

local function RepaintAchievementCard(card)
  if not Skins.CanStyle() then return end
  local keep = {}
  if card.Check then keep[card.Check] = true end
  if card.PlusMinus then keep[card.PlusMinus] = true end
  FadeArtwork(card, keep)
  if card.Icon then
    Skins.Hide(card.Icon.frame)
    Skins.Hide(card.Icon.bling)
    Skins.Icon(card.Icon.texture)
  end
  Skins.Texts(card)
  if card.Shield then Skins.Texts(card.Shield) end
end

local function SkinAchievementCard(card)
  if not Skins.CanStyle() then return end
  if achievementCards[card] then
    RepaintAchievementCard(card)
    return
  end
  achievementCards[card] = true
  local host = Skins.Surface(card, true, true)
  host:ClearAllPoints()
  host:SetPoint("TOPLEFT", card, "TOPLEFT", 2, -2)
  host:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -2, 2)
  if card.Highlight then
    SkinHighlight(card.Highlight)
  end
  RepaintAchievementCard(card)
  if card.Tracked then Skins.CheckBox(card.Tracked) end
  -- These templates repaint parchment and text when completed or recycled.
  if card.Init then Skins.Hook(card, "Init", RepaintAchievementCard) end
  if card.Saturate then Skins.Hook(card, "Saturate", RepaintAchievementCard) end
  if card.Desaturate then Skins.Hook(card, "Desaturate", RepaintAchievementCard) end
end

local function SkinCategoryRow(row)
  if not Skins.CanStyle() then return end
  if not achievementRows[row] then
    achievementRows[row] = true
    Skins.Button(row.Button, true)
    Skins.Hook(row, "Init", SkinCategoryRow)
  end
  Skins.Font(row.Button.Label)
end

local function SkinStatRow(row)
  if not Skins.CanStyle() then return end
  FadeArtwork(row)
  if not achievementRows[row] then
    achievementRows[row] = true
    Skins.Surface(row, true, true)
    Skins.Hook(row, "Init", SkinStatRow)
  end
  Skins.Texts(row)
end

local function SkinComparisonRow(row)
  SkinAchievementCard(row.Player)
  SkinAchievementCard(row.Friend)
  Skins.Hook(row, "Init", SkinComparisonRow)
end

local function SkinSearchRow(row)
  if not Skins.CanStyle() then return end
  if not achievementRows[row] then
    achievementRows[row] = true
    Skins.Button(row, true)
    Skins.Selection(row.SelectedTexture)
  end
  Skins.Hide(row.IconFrame)
  Skins.Icon(row.Icon)
  Skins.Texts(row)
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

local function RefreshAchievementControls()
  if not Skins.CanStyle() then return end
  local frame = AchievementFrame
  for _, tab in ipairs({ frame.Tab1, frame.Tab2, frame.Tab3 }) do Skins.Tab(tab) end
  local dropdown = frame.HeaderDetails.Filters.FilterDropdown
  Skins.Dropdown(dropdown)
  dropdown.Text:ClearAllPoints()
  dropdown.Text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
  dropdown.Text:SetPoint("RIGHT", dropdown, "RIGHT", -24, 0)
end

local function RefreshRows()
  RefreshAchievementControls()
  Skins.ScrollRows(AchievementFrame.Categories.ScrollBox, SkinCategoryRow, SkinCategoryRow)
  Skins.ScrollRows(AchievementFrameAchievements.ScrollBox, SkinAchievementCard, RepaintAchievementCard)
  Skins.ScrollRows(AchievementFrameStats.ScrollBox, SkinStatRow, SkinStatRow)
  Skins.ScrollRows(AchievementFrameComparison.AchievementContainer.ScrollBox, SkinComparisonRow, SkinComparisonRow)
  Skins.ScrollRows(AchievementFrameComparison.StatContainer.ScrollBox, SkinStatRow, SkinStatRow)
  Skins.ScrollRows(AchievementFrame.SearchResults.ScrollBox, SkinSearchRow, SkinSearchRow)
  RefreshSummary()
  RefreshSearchPreview()
  RefreshCriteria(AchievementFrameAchievementsObjectives)
end

local function InstallAchievements(frame)
  FadeArtwork(frame, {
    [AchievementFrameGuildEmblemLeft] = true,
    [AchievementFrameGuildEmblemRight] = true,
  })
  local shell = Skins.Surface(frame)
  shell:ClearAllPoints()
  shell:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 40)
  shell:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
  ns.Theme.WidgetSkins.CloseButton(AchievementFrameCloseButton)
  AchievementFrameCloseButton:ClearAllPoints()
  AchievementFrameCloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, 36)
  FadeArtwork(frame.Header, { [frame.Header.Shield] = true })
  frame.Header:ClearAllPoints()
  frame.Header:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, 36)
  frame.Header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, 36)
  frame.Header:SetHeight(32)
  frame.Header.Title:SetAlpha(0)
  frame.Header.Points:ClearAllPoints()
  frame.Header.Points:SetPoint("CENTER", frame.Header, "CENTER")
  frame.Header.Points:SetWidth(0)
  frame.Header.Points:SetHeight(28)
  Skins.Texts(frame.Header)
  ns.Theme.ApplyFont(frame.Header.Points, "title", 22)
  FadeArtwork(frame.HeaderDetails)
  Skins.Button(frame.HeaderDetails.Back)
  local dropdown = frame.HeaderDetails.Filters.FilterDropdown
  dropdown:SetHeight(26)
  dropdown.topPadding = 2
  local search = frame.HeaderDetails.Filters.SearchBox
  Skins.EditBox(search)
  search.searchIcon:ClearAllPoints()
  search.searchIcon:SetPoint("LEFT", search, "LEFT", 7, 0)
  search:SetTextInsets(23, 22, 0, 0)
  search.Instructions:ClearAllPoints()
  search.Instructions:SetPoint("LEFT", search, "LEFT", 23, 0)
  search.Instructions:SetPoint("RIGHT", search, "RIGHT", -22, 0)
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
  RefreshAchievementControls()
  Skins.Hook(_G, "AchievementFrame_UpdateTabs", RefreshAchievementControls)
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
})
