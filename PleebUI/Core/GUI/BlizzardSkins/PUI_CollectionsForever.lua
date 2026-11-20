local _, ns = ...
if not ns.Client.IsForever then return end
local Skins = ns.BlizzardSkins
local spellButtons = setmetatable({}, { __mode = "k" })
local models = setmetatable({}, { __mode = "k" })

local layout = {
  Panel = { "MountJournal.LeftInset", "MountJournal.RightInset", "MountJournal.BottomLeftInset",
    "PetJournal.LeftInset", "PetJournal.RightInset", "PetJournal.PetCard",
    "WardrobeCollectionFrame.SetsCollectionFrame.LeftInset", "WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame" },
  StripRegions = { "MountJournal.MountCount", "PetJournal.PetCount", "ToyBox.iconsFrame", "HeirloomsJournal.iconsFrame",
    "WardrobeCollectionFrame.ItemsCollectionFrame", "WardrobeCollectionFrame.SetsCollectionFrame.RightInset", "ToyBox.ProgressTracker" },
  Texts = { "MountJournal.MountCount", "PetJournal.PetCount", "ToyBox.ProgressTracker" },
  Hide = { "MountJournal.MountDisplay.ShadowOverlay", "PetJournal.PetCard.ShadowOverlay", "PetJournal.PetCard.PetBackground",
    "WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame.ModelFadeTexture",
    "WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame.IconRowBackground" },
  Button = { "MountJournal.MountButton", "PetJournal.SummonButton" },
  EditBox = { "MountJournal.searchBox", "PetJournal.searchBox", "ToyBox.searchBox", "HeirloomsJournal.SearchBox",
    "WardrobeCollectionFrame.SearchBox" },
  Dropdown = { "MountJournal.FilterDropdown", "PetJournal.FilterDropdown", "ToyBox.FilterDropdown",
    "HeirloomsJournal.ClassDropdown", "HeirloomsJournal.FilterDropdown", "WardrobeCollectionFrame.ClassDropdown",
    "WardrobeCollectionFrame.FilterButton", "WardrobeCollectionFrame.ItemsCollectionFrame.WeaponDropdown",
    "WardrobeCollectionFrame.SetsCollectionFrame.DetailsFrame.VariantSetsDropdown" },
  ScrollBar = { "MountJournal.ScrollBar", "PetJournal.ScrollBar", "WardrobeCollectionFrame.SetsCollectionFrame.ListContainer.ScrollBar" },
  Bar = { "HeirloomsJournal.progressBar", "WardrobeCollectionFrame.progressBar" },
  Paging = { "ToyBox.PagingFrame", "HeirloomsJournal.PagingFrame", "WardrobeCollectionFrame.ItemsCollectionFrame.PagingFrame" },
  Tab = { "WardrobeCollectionFrame.ItemsTab", "WardrobeCollectionFrame.SetsTab" },
  CheckBox = { "MountJournal.MountDisplay.ModelScene.TogglePlayer" },
}

local function RepaintRow(row)
  for _, region in ipairs({ row:GetRegions() }) do
    if region:IsObjectType("FontString") then ns.Theme.ApplyFont(region, "body") end
  end
end

local function SkinCompanionRow(row)
  Skins.Hide(row.background)
  Skins.IconButton(row, row.icon)
  Skins.Selection(row.selectedTexture)
  if row.dragButton then Skins.Selection(row.dragButton.ActiveTexture) end
  RepaintRow(row)
end

local function SkinSetRow(row)
  Skins.Hide(row.Background)
  Skins.Surface(row, true)
  Skins.Surface(row.IconFrame, true)
  Skins.Icon(row.IconFrame.Icon)
  Skins.Selection(row.SelectedTexture)
  RepaintRow(row)
end

local function SkinSpell(button)
  Skins.Hide(button.slotFrameCollected)
  Skins.Hide(button.slotFrameUncollected)
  Skins.Hide(button.slotFrameUncollectedInnerGlow)
  if not spellButtons[button] then
    spellButtons[button] = true
    Skins.IconButton(button, button.iconTexture)
    Skins.Icon(button.iconTextureUncollected)
  end
  ns.Theme.ApplyFont(button.name, "body")
end

local function SkinModels()
  for _, content in ipairs(WardrobeCollectionFrame.ContentFrames) do
    if content.Models then
      for _, model in ipairs(content.Models) do
        if not models[model] then
          models[model] = true
          Skins.Hide(model.Border)
          Skins.Surface(model, true)
        end
      end
    end
  end
end

local function PaintCollections(frame)
  Skins.Shell(frame)
  Skins.Apply(_G, layout)
  Skins.Texts(PetJournal.PetCard.PetInfo)
end

Skins.Register("Blizzard_Collections", "CollectionsJournal", {
  install = function(frame)
    PaintCollections(frame)
    for _, tab in ipairs(frame.TabContainer.Tabs) do Skins.SideTab(tab) end
    Skins.ScrollRows(MountJournal.ScrollBox, SkinCompanionRow, RepaintRow)
    Skins.ScrollRows(PetJournal.ScrollBox, SkinCompanionRow, RepaintRow)
    Skins.ScrollRows(WardrobeCollectionFrame.SetsCollectionFrame.ListContainer.ScrollBox, SkinSetRow, RepaintRow)
    Skins.Icon(PetJournal.PetCard.PetInfo.icon)
    Skins.Arrow(PetJournal.PetCard.modelScene.RotateLeftButton, "<")
    Skins.Arrow(PetJournal.PetCard.modelScene.RotateRightButton, ">")
    for _, spell in ipairs({ MountJournal.SummonRandomFavoriteSpellFrame.Button, PetJournal.SummonRandomPetSpellFrame.Button }) do
      Skins.IconButton(spell, spell.Icon)
    end
    for index = 1, 18 do SkinSpell(ToyBox.iconsFrame["spellButton" .. index]) end
    Skins.Hook(_G, "ToySpellButton_UpdateButton", SkinSpell)
    Skins.Hook(HeirloomsJournal, "UpdateButton", function(_, button) SkinSpell(button) end)
    SkinModels()
  end,
  onShow = SkinModels,
  onTheme = PaintCollections,
})
