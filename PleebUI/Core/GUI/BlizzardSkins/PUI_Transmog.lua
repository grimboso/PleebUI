local _, ns = ...
local Skins = ns.BlizzardSkins
local situationRows = setmetatable({}, { __mode = "k" })

local function RepaintOutfit(row)
  local text = row.OutfitButton.TextContent
  ns.Theme.ApplyFont(text.Name, "body")
  ns.Theme.ApplyFont(text.SituationInfo, "body")
end

local function InstallOutfit(row)
  -- Keep the active/locked outfit overlays, spell cooldown and saved-outfit animations.
  Skins.Hide(row.OutfitButton:GetNormalTexture())
  Skins.Surface(row.OutfitButton, true, true)
  Skins.Icon(row.OutfitIcon.Icon)
  RepaintOutfit(row)
end

local function RefreshSituations(frame)
  for row in frame.SituationFramePool:EnumerateActive() do
    if not situationRows[row] then
      situationRows[row] = true
      Skins.Dropdown(row.Dropdown)
    end
    ns.Theme.ApplyFont(row.Title, "body")
  end
  ns.Theme.ApplyFont(frame.EnabledToggle.Text, "body")
end

Skins.Register("Blizzard_Transmog", "TransmogFrame", {
  install = function(frame)
    Skins.Shell(frame)
    local outfits = frame.OutfitCollection
    for _, key in ipairs({ "Background", "GradientTop", "GradientBottom", "DividerBar" }) do
      Skins.Hide(outfits[key])
    end
    Skins.Surface(outfits, false, true)
    Skins.Hide(outfits.OutfitList.DividerTop)
    Skins.Hide(outfits.OutfitList.DividerBottom)
    Skins.ScrollBar(outfits.OutfitList.ScrollBar)
    Skins.ScrollRows(outfits.OutfitList.ScrollBox, InstallOutfit, RepaintOutfit)
    Skins.Button(outfits.SaveOutfitButton, true)
    Skins.Button(outfits.PurchaseOutfitButton, true)
    Skins.Hide(outfits.MoneyFrame.Background)
    Skins.Surface(outfits.MoneyFrame, true, true)
    ns.Theme.ApplyFont(outfits.UsableDiscountText, "body")

    local preview = frame.CharacterPreview
    Skins.Hide(preview.Background)
    Skins.Hide(preview.Gradients)
    Skins.Surface(preview, false, true)
    Skins.Button(preview.ClearAllPendingButton, true)
    for _, toggle in ipairs({ preview.ToggleOptions.HideIgnoredToggle,
      preview.ToggleOptions.SheatheWeaponToggle, preview.ToggleOptions.PreviewedWeaponToggle }) do
      Skins.CheckBox(toggle.Checkbox)
      ns.Theme.ApplyFont(toggle.Text, "body")
    end

    local wardrobe = frame.WardrobeCollection
    Skins.Hide(wardrobe.Background)
    Skins.Surface(wardrobe, false, true)
    Skins.TabSystem(wardrobe.TabHeaders)
    for _, tab in ipairs({ wardrobe.TabHeaders:GetChildren() }) do
      if tab:IsObjectType("Button") then Skins.Hide(tab.SelectedHighlight) end
    end
    local content = wardrobe.TabContent
    Skins.Hide(content.Background)
    Skins.Hide(content.Border)
    for _, page in ipairs({ content.ItemsFrame, content.SetsFrame }) do
      Skins.EditBox(page.SearchBox)
      Skins.Dropdown(page.FilterButton)
      Skins.Paging(page.PagedContent.PagingControls)
    end
    Skins.Dropdown(content.ItemsFrame.WeaponDropdown)
    Skins.Dropdown(content.ItemsFrame.WeaponSheatheDropdown)
    Skins.CheckBox(content.ItemsFrame.SecondaryAppearanceToggle.Checkbox)
    ns.Theme.ApplyFont(content.ItemsFrame.SecondaryAppearanceToggle.Text, "body")
    Skins.Font(content.ItemsFrame.ActiveSlotTitle, "header")
    Skins.Button(content.CustomSetsFrame.NewCustomSetButton, true)
    Skins.Paging(content.CustomSetsFrame.PagedContent.PagingControls)

    local situations = content.SituationsFrame
    Skins.Hide(situations.Situations.Background)
    Skins.Surface(situations.Situations, true, true)
    Skins.CheckBox(situations.EnabledToggle.Checkbox)
    Skins.Button(situations.DefaultsButton, true)
    Skins.Button(situations.ApplyButton, true)
    ns.Theme.ApplyFont(situations.DescriptionText, "body")
    Skins.Hook(situations, "Init", RefreshSituations)
    Skins.Hook(situations, "Refresh", RefreshSituations)
    RefreshSituations(situations)
    -- Appearance cards, slot selection/pending art, models, help and undo glyphs remain native.
  end,
  onShow = function(frame)
    RefreshSituations(frame.WardrobeCollection.TabContent.SituationsFrame)
  end,
})
