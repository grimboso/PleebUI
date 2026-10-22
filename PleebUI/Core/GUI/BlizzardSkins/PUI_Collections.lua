local _, ns = ...
local Skins = ns.BlizzardSkins
local collectionButtons = setmetatable({}, { __mode = "k" })
local collectionModels = setmetatable({}, { __mode = "k" })

local layout = {
  Panel = { "MountJournal.LeftInset", "MountJournal.RightInset", "MountJournal.BottomLeftInset",
    "PetJournal.LeftInset", "PetJournal.RightInset", "PetJournal.PetCardInset", "PetJournal.PetCard",
    "WardrobeCollectionFrame.SetsCollectionFrame.LeftInset", "WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame" },
  StripRegions = { "ToyBox.iconsFrame", "HeirloomsJournal.iconsFrame", "WardrobeCollectionFrame.ItemsCollectionFrame",
    "WardrobeCollectionFrame.SetsCollectionFrame.RightInset", "WarbandSceneJournal.IconsFrame",
    "MountJournal.MountCount", "PetJournal.PetCount", "PetJournal.loadoutBorder" },
  Button = { "MountJournal.MountButton", "PetJournal.FindBattleButton", "PetJournal.SummonButton" },
  EditBox = { "MountJournal.searchBox", "PetJournal.searchBox", "ToyBox.searchBox", "HeirloomsJournal.SearchBox",
    "WardrobeCollectionFrame.SearchBox" },
  Dropdown = { "MountJournal.FilterDropdown", "PetJournal.FilterDropdown", "ToyBox.FilterDropdown",
    "HeirloomsJournal.ClassDropdown", "HeirloomsJournal.FilterDropdown", "WardrobeCollectionFrame.ClassDropdown",
    "WardrobeCollectionFrame.FilterButton", "WardrobeCollectionFrame.ItemsCollectionFrame.WeaponDropdown",
    "WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame.VariantSetsDropdown" },
  ScrollBar = { "MountJournal.ScrollBar", "PetJournal.ScrollBar", "WardrobeCollectionFrame.SetsCollectionFrame.ListContainer.ScrollBar" },
  Bar = { "ToyBox.progressBar", "HeirloomsJournal.progressBar", "WardrobeCollectionFrame.progressBar",
    "PetJournal.PetCard.HealthFrame.healthBar", "PetJournal.PetCard.xpBar" },
  Paging = { "ToyBox.PagingFrame", "HeirloomsJournal.PagingFrame", "WardrobeCollectionFrame.ItemsCollectionFrame.PagingFrame",
    "WarbandSceneJournal.IconsFrame.Icons.Controls.PagingControls" },
  Tab = { "WardrobeCollectionFrame.ItemsTab", "WardrobeCollectionFrame.SetsTab" },
  CheckBox = { "MountJournal.MountDisplay.ModelScene.TogglePlayer", "WarbandSceneJournal.IconsFrame.Icons.Controls.ShowOwned.Checkbox" },
  Hide = { "MountJournal.MountDisplay.ShadowOverlay", "WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame.ModelFadeTexture",
    "WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame.IconRowBackground" },
}

local function RepaintCollectionRow(row)
  Skins.Hide(row.background)
  if row.dragButton then Skins.Hide(row.dragButton.levelBG) end
  -- The native initializer changes font objects for collected and unavailable entries.
  for _, region in ipairs({ row:GetRegions() }) do
    if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
  end
end

local function SkinCollectionRow(row)
  Skins.Hide(row.background)
  Skins.IconButton(row, row.icon)
  if row.dragButton then
    Skins.Hide(row.dragButton.levelBG)
    Skins.Selection(row.dragButton.ActiveTexture)
    local highlight = row.dragButton:GetHighlightTexture()
    highlight:SetColorTexture(1, 1, 1, 0.12)
    highlight:SetAllPoints(row.icon)
    Skins.Font(row.dragButton.level)
  end
  Skins.Selection(row.selectedTexture)
  RepaintCollectionRow(row)
end

local function RepaintSetRow(row)
  Skins.Hide(row.Background)
  for _, region in ipairs({ row:GetRegions() }) do
    if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
  end
end

local function SkinSetRow(row)
  Skins.Hide(row.Background)
  Skins.Surface(row, true)
  Skins.Surface(row.IconFrame, true)
  Skins.Icon(row.IconFrame.Icon)
  Skins.Selection(row.SelectedTexture)
  RepaintSetRow(row)
end

local function RefreshCollectionRows()
  Skins.ScrollRows(MountJournal.ScrollBox, SkinCollectionRow, RepaintCollectionRow)
  Skins.ScrollRows(PetJournal.ScrollBox, SkinCollectionRow, RepaintCollectionRow)
  Skins.ScrollRows(WardrobeCollectionFrame.SetsCollectionFrame.ListContainer.ScrollBox, SkinSetRow, RepaintSetRow)
end

local function SkinCollectionSpell(button)
  Skins.Hide(button.slotFrameCollected)
  Skins.Hide(button.slotFrameUncollected)
  Skins.Hide(button.slotFrameUncollectedInnerGlow)
  if not collectionButtons[button] then
    collectionButtons[button] = true
    Skins.IconButton(button, button.iconTexture)
    Skins.Icon(button.iconTextureUncollected)
  end
  ns.Theme.ApplyFont(button.name, "body")
end

local function SkinCampsite(row)
  Skins.Hide(row.Border)
  Skins.Hide(row.NameBackground)
  if not collectionButtons[row] then
    collectionButtons[row] = true
    Skins.IconButton(row, row.Icon)
  end
  ns.Theme.ApplyFont(row.Name, "body")
end

local function RefreshCampsites()
  for _, row in WarbandSceneJournal.IconsFrame.Icons:EnumerateFrames() do SkinCampsite(row) end
end

local function SkinPetSpell(button)
  local checked = button:IsObjectType("CheckButton") and button:GetCheckedTexture()
  local highlight = button:GetHighlightTexture()
  for _, region in ipairs({ button:GetRegions() }) do
    if region:IsObjectType("Texture") and region ~= button.icon and region ~= button.BlackCover
      and region ~= button.selected and region ~= checked and region ~= highlight then
      Skins.Hide(region)
    end
  end
  Skins.IconButton(button, button.icon)
  Skins.Selection(button.selected)
  Skins.Selection(checked)
  if button.LevelRequirement then ns.Theme.ApplyFont(button.LevelRequirement, "body") end
end

local function SkinPetSlot(pet)
  for _, region in ipairs({ pet:GetRegions() }) do
    if region:IsObjectType("Texture") and region ~= pet.icon and region ~= pet.petTypeIcon
      and region ~= pet.qualityBorder and region ~= pet.isDead and region ~= pet.favorite
      and region ~= pet.newGlow then
      Skins.Hide(region)
    end
  end
  Skins.IconButton(pet, pet.icon)
  Skins.Texts(pet)
end

local function SkinPetExperience(bar)
  local fill = bar:GetStatusBarTexture()
  for _, region in ipairs({ bar:GetRegions() }) do
    if region:IsObjectType("Texture") and region ~= fill then Skins.Hide(region) end
  end
  Skins.Bar(bar)
end

local function RefreshCollectionModels()
  for _, content in ipairs(WardrobeCollectionFrame.ContentFrames) do
    if content.Models then
      for _, model in ipairs(content.Models) do
        if not collectionModels[model] then
          collectionModels[model] = true
          Skins.Hide(model.Border)
          Skins.Surface(model, true)
        end
      end
    end
  end
end

local function ShowFilterResetTooltip(button)
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  GameTooltip:SetText("Clear filters")
  GameTooltip:Show()
end

local function AlignCollectionFilters()
  for _, pair in ipairs({
    { MountJournal.FilterDropdown, MountJournal.searchBox },
    { PetJournal.FilterDropdown, PetJournal.searchBox },
    { ToyBox.FilterDropdown, ToyBox.searchBox },
    { HeirloomsJournal.FilterDropdown, HeirloomsJournal.SearchBox },
    { WardrobeCollectionFrame.FilterButton, WardrobeCollectionFrame.SearchBox },
  }) do
    local dropdown, search = pair[1], pair[2]
    dropdown:SetHeight(search:GetHeight())
    dropdown.Text:ClearAllPoints()
    dropdown.Text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    dropdown.Text:SetPoint("RIGHT", dropdown, "RIGHT", -21, 0)
    dropdown.Text:SetJustifyH("LEFT")
    Skins.DropdownMenu(dropdown)
    dropdown.ResetButton:SetSize(search:GetHeight(), search:GetHeight())
    dropdown.ResetButton:HookScript("OnEnter", ShowFilterResetTooltip)
    dropdown.ResetButton:HookScript("OnLeave", GameTooltip_Hide)
  end

  for _, dropdown in ipairs({
    HeirloomsJournal.ClassDropdown,
    WardrobeCollectionFrame.ClassDropdown,
    WardrobeCollectionFrame.ItemsCollectionFrame.WeaponDropdown,
    WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame.VariantSetsDropdown,
  }) do
    Skins.DropdownMenu(dropdown)
  end

  MountJournal.FilterDropdown:ClearAllPoints()
  MountJournal.FilterDropdown:SetPoint("TOPRIGHT", MountJournal.LeftInset, "TOPRIGHT", -5, -9)
  PetJournal.FilterDropdown:ClearAllPoints()
  PetJournal.FilterDropdown:SetPoint("TOPRIGHT", PetJournal.LeftInset, "TOPRIGHT", -5, -9)

  HeirloomsJournal.ClassDropdown:SetHeight(HeirloomsJournal.SearchBox:GetHeight())
  HeirloomsJournal.ClassDropdown:ClearAllPoints()
  HeirloomsJournal.ClassDropdown:SetPoint("TOPLEFT", HeirloomsJournal, "TOPLEFT", 70, -35)
  HeirloomsJournal.ClassDropdown.Arrow:ClearAllPoints()
  HeirloomsJournal.ClassDropdown.Arrow:SetPoint("RIGHT", HeirloomsJournal.ClassDropdown, "RIGHT", 1, 0)
  HeirloomsJournal.ClassDropdown.Text:ClearAllPoints()
  HeirloomsJournal.ClassDropdown.Text:SetPoint("LEFT", HeirloomsJournal.ClassDropdown, "LEFT", 8, 0)
  HeirloomsJournal.ClassDropdown.Text:SetPoint("RIGHT", HeirloomsJournal.ClassDropdown.Arrow, "LEFT", -2, 0)
end

local function AlignCollectionNavigation()
  local controls = WarbandSceneJournal.IconsFrame.Icons.Controls
  local campsitePaging = controls.PagingControls
  local showOwned = controls.ShowOwned
  controls:MarkIgnoreInLayout(campsitePaging, showOwned)
  campsitePaging:MarkIgnoreInLayout(campsitePaging.PageText, campsitePaging.PrevPageButton, campsitePaging.NextPageButton)

  for _, paging in ipairs({
    ToyBox.PagingFrame,
    HeirloomsJournal.PagingFrame,
    WardrobeCollectionFrame.ItemsCollectionFrame.PagingFrame,
    campsitePaging,
  }) do
    paging:ClearAllPoints()
    paging:SetPoint("BOTTOM", CollectionsJournal, "BOTTOM", 0, 43)
    paging.PrevPageButton:ClearAllPoints()
    paging.PrevPageButton:SetPoint("RIGHT", CollectionsJournal, "BOTTOM", -1.5, 59)
    paging.NextPageButton:ClearAllPoints()
    paging.NextPageButton:SetPoint("LEFT", CollectionsJournal, "BOTTOM", 1.5, 59)
    paging.PageText:ClearAllPoints()
    paging.PageText:SetPoint("RIGHT", paging.PrevPageButton, "LEFT", -11, 0)
  end

  showOwned:ClearAllPoints()
  showOwned:SetPoint("LEFT", campsitePaging.NextPageButton, "RIGHT", 25, 0)
  Skins.Font(showOwned.Text)

  local scrollBar = MountJournal.ScrollBar
  scrollBar:ClearAllPoints()
  scrollBar:SetPoint("TOPLEFT", MountJournal.ScrollBox, "TOPRIGHT", 11, 31)
  scrollBar:SetPoint("BOTTOMLEFT", MountJournal.ScrollBox, "BOTTOMRIGHT", 11, -1)
end

local function InstallCollections(frame)
  Skins.Shell(frame)
  for index = 1, 6 do Skins.Tab(_G["CollectionsJournalTab" .. index]) end
  Skins.Apply(_G, layout)
  AlignCollectionFilters()
  AlignCollectionNavigation()
  RefreshCollectionRows()
  for index = 1, 18 do SkinCollectionSpell(ToyBox.iconsFrame["spellButton" .. index]) end
  RefreshCollectionModels()
  for _, spell in ipairs({ MountJournal.SummonRandomFavoriteSpellFrame.Button,
    PetJournal.HealPetSpellFrame.Button, PetJournal.SummonRandomPetSpellFrame.Button }) do
    Skins.IconButton(spell, spell.Icon)
  end
  Skins.StripRegions(PetJournal.PetCard)
  SkinPetSlot(PetJournal.PetCard.PetInfo)
  for index = 1, 6 do SkinPetSpell(PetJournal.PetCard["spell" .. index]) end
  SkinPetExperience(PetJournal.PetCard.xpBar)
  Skins.StripRegions(PetJournal.SpellSelect)
  for index = 1, 2 do SkinPetSpell(PetJournal.SpellSelect["Spell" .. index]) end
  for index = 1, 3 do
    local pet = PetJournal.Loadout["Pet" .. index]
    SkinPetSlot(pet)
    Skins.Texts(pet.healthFrame)
    Skins.Bar(pet.healthFrame.healthBar)
    SkinPetExperience(pet.xpBar)
    for spellIndex = 1, 3 do
      local spell = pet["spell" .. spellIndex]
      SkinPetSpell(spell)
    end
  end
  RefreshCampsites()
  Skins.Hook(_G, "ToySpellButton_UpdateButton", SkinCollectionSpell)
  Skins.Hook(HeirloomsJournal, "UpdateButton", function(_, button) SkinCollectionSpell(button) end)
  Skins.Hook(WarbandSceneJournal.IconsFrame.Icons, "DisplayViewsForCurrentPage", RefreshCampsites)
end

Skins.Register("Blizzard_Collections", "CollectionsJournal", {
  install = InstallCollections,
  onShow = function()
    RefreshCollectionRows()
    RefreshCollectionModels()
    RefreshCampsites()
  end,
})
