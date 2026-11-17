local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.ProfessionSkins
local isForever = ns.Client.IsForever

local function SkinSideTab(tab)
  Skins.Hide(tab.Background)
  Skins.Surface(tab, true)
  tab.Icon:RemoveMaskTexture(tab.Mask)
  Skins.Icon(tab.Icon)
  Skins.Hook(tab, "UpdateIconInterior", function() Skins.Icon(tab.Icon) end)

  local selected = tab.SelectedTexture
  selected:ClearAllPoints()
  selected:SetPoint("BOTTOMLEFT", tab.Icon, "BOTTOMLEFT", 0, 1)
  selected:SetPoint("BOTTOMRIGHT", tab.Icon, "BOTTOMRIGHT", 0, 1)
  selected:SetHeight(2)
  Skins.Selection(selected, 1)

  tab.HighlightTexture:ClearAllPoints()
  tab.HighlightTexture:SetAllPoints(tab.Icon)
  Skins.Selection(tab.HighlightTexture, 0.15)
  tab.TabGlow:ClearAllPoints()
  tab.TabGlow:SetAllPoints(tab.Icon)
  Skins.Selection(tab.TabGlow, 0.25)
end

local function SkinOverview(page)
  local content = page.ProfessionsContentFrame
  for _, entry in ipairs({
    content.PrimaryProfession1, content.PrimaryProfession2,
    content.SecondaryProfession1, content.SecondaryProfession2, content.SecondaryProfession3,
  }) do
    Skins.Hide(entry.Background)
    Skins.Surface(entry, true)
    Skins.Font(entry.ProfessionName, "header")
    Skins.Font(entry.missingHeader, "header")
    Skins.Font(entry.missingText)
    Skins.Font(entry.specialization)
    Templates.Rank(entry.StatusBar)
    for _, button in ipairs(entry.spellButtons) do
      Skins.Hide(button.IconBorder)
      Skins.Hide(button.IconTextureOverlay)
      Skins.Icon(button.IconTexture)
      ns.Theme.ApplyFont(button.spellString, "body")
      ns.Theme.ApplyFont(button.subSpellString, "tiny")
    end
  end
end

local function RefreshProfessions(frame)
  if not isForever then Templates.Tabs(frame.TabSystem) end
  Templates.RecipeRows(frame.CraftingPage.RecipeList)
  Templates.RefreshForm(frame.CraftingPage.SchematicForm)
end

Skins.Register("Blizzard_Professions", "ProfessionsFrame", {
  install = function(frame)
    Skins.Shell(frame)
    local page = frame.CraftingPage
    if isForever then
      SkinSideTab(frame.ProfessionsOverviewTab)
      for _, tab in ipairs(frame.rightProfessionTabs) do SkinSideTab(tab) end
      SkinOverview(frame.BookPage)
      for _, region in ipairs({ page:GetRegions() }) do
        if region:IsObjectType("Texture") and region:GetAtlas() == "Profession-Background-Template2" then
          Skins.Hide(region)
        end
      end
    else
      Templates.Tabs(frame.TabSystem)
      Skins.Hook(frame, "UpdateTabs", function() Templates.Tabs(frame.TabSystem) end)
    end

    for _, button in ipairs({ page.CreateButton, page.CreateAllButton, page.ViewGuildCraftersButton }) do Skins.Button(button, true) end
    Templates.Spinner(page.CreateMultipleInputBox)
    Skins.EditBox(page.MinimizedSearchBox)
    Templates.RecipeList(page.RecipeList)
    Templates.Schematic(page.SchematicForm)
    Templates.Rank(page.RankBar)
    Templates.Fonts(page.ConcentrationDisplay)
    for _, button in ipairs(page.InventorySlots) do
      Skins.Surface(button, true, true)
      Skins.Icon(button.icon)
    end
    -- Native help, profession-link, maximize/minimize and cast-bar handlers stay intact.
  end,
  onShow = RefreshProfessions,
})
