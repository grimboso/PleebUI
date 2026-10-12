local _, ns = ...
local Skins = ns.BlizzardSkins

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

local function SkinCollectionRow(row)
  Skins.Hide(row.background)
  Skins.Surface(row, true)
  Skins.Icon(row.icon)
  Skins.Selection(row.selectedTexture)
  Skins.Texts(row)
end

local function SkinSetRow(row)
  Skins.Hide(row.Background)
  Skins.Surface(row, true)
  Skins.Surface(row.IconFrame, true)
  Skins.Icon(row.IconFrame.Icon)
  Skins.Selection(row.SelectedTexture)
  Skins.Texts(row)
end

local function SkinCollectionSpell(button)
  if not Skins.CanStyle() then return end
  Skins.Hide(button.slotFrameCollected)
  Skins.Hide(button.slotFrameUncollected)
  Skins.Hide(button.slotFrameUncollectedInnerGlow)
  Skins.IconButton(button, button.iconTexture)
  Skins.Icon(button.iconTextureUncollected)
  Skins.Font(button.name)
end

local function SkinCampsite(row)
  Skins.Hide(row.Border)
  Skins.Hide(row.NameBackground)
  Skins.IconButton(row, row.Icon)
  Skins.Font(row.Name)
end

local function RefreshCampsites()
  if not Skins.CanStyle() then return end
  for _, row in WarbandSceneJournal.IconsFrame.Icons:EnumerateFrames() do SkinCampsite(row) end
end

local function RefreshCollections(frame)
  Skins.Shell(frame)
  for index = 1, 6 do Skins.Tab(_G["CollectionsJournalTab" .. index]) end
  Skins.Apply(_G, layout)
  Skins.ScrollRows(MountJournal.ScrollBox, SkinCollectionRow)
  Skins.ScrollRows(PetJournal.ScrollBox, SkinCollectionRow)
  Skins.ScrollRows(WardrobeCollectionFrame.SetsCollectionFrame.ListContainer.ScrollBox, SkinSetRow)
  for index = 1, 18 do SkinCollectionSpell(ToyBox.iconsFrame["spellButton" .. index]) end
  for _, content in ipairs(WardrobeCollectionFrame.ContentFrames) do
    if content.Models then
      for _, model in ipairs(content.Models) do
        Skins.Hide(model.Border)
        Skins.Surface(model, true)
      end
    end
  end
  for _, spell in ipairs({ MountJournal.SummonRandomFavoriteSpellFrame.Button,
    PetJournal.HealPetSpellFrame.Button, PetJournal.SummonRandomPetSpellFrame.Button }) do
    Skins.IconButton(spell, spell.Icon)
  end
  for index = 1, 3 do
    local pet = PetJournal.Loadout["Pet" .. index]
    Skins.IconButton(pet, pet.icon)
    Skins.Texts(pet)
    Skins.Texts(pet.healthFrame)
    Skins.Bar(pet.healthFrame.healthBar)
    Skins.Bar(pet.xpBar)
    for spellIndex = 1, 3 do
      local spell = pet["spell" .. spellIndex]
      Skins.IconButton(spell, spell.icon)
    end
  end
  RefreshCampsites()
  Skins.Hook(_G, "ToySpellButton_UpdateButton", SkinCollectionSpell)
  Skins.Hook(HeirloomsJournal, "UpdateButton", function(_, button) SkinCollectionSpell(button) end)
  Skins.Hook(WarbandSceneJournal.IconsFrame.Icons, "DisplayViewsForCurrentPage", RefreshCampsites)
end

Skins.Register("Blizzard_Collections", "CollectionsJournal", RefreshCollections)
