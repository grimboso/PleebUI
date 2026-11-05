local _, ns = ...
if not ns.Client.IsForever then return end

local Skins, Theme, IconSkin = ns.BlizzardSkins, ns.Theme, ns.IconSkin
local gearSlots = {}

local function HideAtlas(frame, atlas)
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:IsObjectType("Texture") and region:GetAtlas() == atlas then
      Skins.Hide(region)
    end
  end
end

local function PaintGearSlot(slot)
  if not gearSlots[slot] then return end
  Skins.Hide(slot.IconBorder)
  local color = Theme.GetColors().border
  local quality = GetInventoryItemQuality("player", slot:GetID())
  if not issecretvalue(quality) and quality and quality > Enum.ItemQuality.Common then
    local r, g, b = C_Item.GetItemQualityColor(quality)
    color = { r, g, b, 1 }
  end
  IconSkin.ApplySimpleBorder(slot, Theme.GetEdgeSize(), color)
end

local function InstallGearSlot(slot)
  gearSlots[slot] = true
  Skins.Hide(slot.BorderFrame)
  local normal = slot:GetNormalTexture()
  if normal then normal:Hide() end
  IconSkin.MakeIconSquare(slot)
end

local function AnchorTabIndicator(texture, icon)
  texture:ClearAllPoints()
  texture:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 1)
  texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 1)
  texture:SetHeight(2)
end

local function InstallTabs(frame)
  for _, tab in ipairs(frame.ModeTabs.Tabs) do
    Skins.Hide(tab.Background)
    tab.Icon:RemoveMaskTexture(tab.Mask)
    AnchorTabIndicator(tab.SelectedTexture, tab.Icon)
    tab.HighlightTexture:ClearAllPoints()
    tab.HighlightTexture:SetAllPoints(tab.Icon)
    tab.TabGlow:ClearAllPoints()
    tab.TabGlow:SetAllPoints(tab.Icon)
  end
  for _, tab in ipairs(PaperDollSidebarTabs.Tabs) do
    HideAtlas(tab, "UI-Character-Info-StatTab")
    AnchorTabIndicator(tab:GetCheckedTexture(), tab.Icon)
  end
end

local function PaintCharacterSheet(frame)
  local colors = Theme.GetColors()
  local border, accent = colors.controlBorder, colors.accent
  for _, tab in ipairs(frame.ModeTabs.Tabs) do
    IconSkin.ApplySimpleBorder(tab.Icon, Theme.GetEdgeSize(), border)
    tab.SelectedTexture:SetColorTexture(accent[1], accent[2], accent[3], 1)
    tab.HighlightTexture:SetColorTexture(accent[1], accent[2], accent[3], 0.15)
    tab.TabGlow:SetColorTexture(accent[1], accent[2], accent[3], 0.2)
  end
  for _, tab in ipairs(PaperDollSidebarTabs.Tabs) do
    IconSkin.ApplySimpleBorder(tab.Icon, Theme.GetEdgeSize(), border)
    tab:GetCheckedTexture():SetColorTexture(accent[1], accent[2], accent[3], 1)
  end
  for slot in pairs(gearSlots) do PaintGearSlot(slot) end
end

local function SkinStatRow(row)
  Skins.Hide(row.Background)
  Skins.Font(row.Title, "nav")
  -- The game colors some stat values to convey their state.
  if row.Label then Theme.ApplyFont(row.Label, "body") end
  if row.Value then Theme.ApplyFont(row.Value, "body") end
end

local function SkinTitleRow(row)
  Skins.Hide(row.Stripe)
  Skins.Surface(row, true)
  Skins.Font(row.text)
  Skins.Selection(row.SelectedBar, 0.25)
  Skins.Selection(row:GetHighlightTexture(), 0.15)
end

local function SkinEquipmentSetRow(row)
  HideAtlas(row, "UI-Character-Info-OutfitCard")
  HideAtlas(row, "UI-Character-Info-OutfitIcon-Frame")
  Skins.Surface(row, true)
  Skins.Font(row.text)
  Skins.Icon(row.icon)
  Skins.Selection(row.SelectedBar, 0.25)
  Skins.Selection(row.HighlightBar, 0.15)
end

local function InstallCharacterSheet(frame)
  Skins.Chrome(frame)
  Skins.Hide(frame:GetPortrait())
  Skins.Surface(frame)
  Theme.ApplyFont(frame.TitleContainer.TitleText, "title")
  Theme.WidgetSkins.CloseButton(frame.CloseButton)

  for _, pane in ipairs({ frame.LeftPaneHost, frame.RightPaneHost }) do
    for _, region in ipairs({ pane:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
  end
  for _, child in ipairs({ frame.RightPaneHost:GetChildren() }) do
    HideAtlas(child, "common-framedivider")
  end
  Skins.Hide(CharacterStatsPaneScrollBox.ClassBackground)
  for _, list in ipairs({ CharacterStatsPaneScrollBox, CharacterStatsPanePetScrollBox }) do
    Skins.Hide(list.Border)
    Skins.ScrollBar(list.ScrollBar)
    Skins.ScrollRows(list.ScrollBox, SkinStatRow, false)
  end
  local titles = PaperDollFrame.TitleManagerPane
  Skins.Hide(titles.Border)
  Skins.ScrollBar(titles.ScrollBar)
  Skins.ScrollRows(titles.ScrollBox, SkinTitleRow, false)

  local equipment = PaperDollFrame.EquipmentManagerPane
  Skins.Hide(equipment.Border)
  HideAtlas(equipment, "UI-Character-Info-ScrollLine")
  Skins.ScrollBar(equipment.ScrollBar)
  Skins.ScrollRows(equipment.ScrollBox, SkinEquipmentSetRow, false)
  Skins.Button(equipment.EquipSet)
  Skins.Button(equipment.SaveSet)
  Skins.Button(equipment.NewSet)
  InstallTabs(frame)
  for _, slot in ipairs(PaperDollItemsFrame.EquipmentSlots) do InstallGearSlot(slot) end
  for _, slot in ipairs(PaperDollItemsFrame.WeaponSlots) do InstallGearSlot(slot) end
  HideAtlas(CharacterAmmoSlot, "UI-Character-Info-GearSlotSmall")
  InstallGearSlot(CharacterAmmoSlot)
  Skins.Hook(_G, "PaperDollItemSlotButton_Update", PaintGearSlot)
  PaintCharacterSheet(frame)
end

Skins.Register("Blizzard_UIPanels_Game", "CharacterFrame", {
  install = InstallCharacterSheet,
  onTheme = PaintCharacterSheet,
  manageControls = false,
})

local function SkinListRow(row)
  if row.Content then
    Skins.Font(row.Content.Name)
    Skins.Font(row.Content.Value)
  else
    Skins.Font(row.Name or row.Text, "nav")
  end
end

local function SkinSkillRow(row)
  SkinListRow(row)
  if row.Content then
    Skins.ColoredProgressBar(row.Content.SkillsBar)
  end
end

local function SkinList(frame)
  Skins.ScrollBar(frame.ScrollBar)
  Skins.ScrollRows(frame.ScrollBox, SkinListRow, false)
end

Skins.Register("Blizzard_UIPanels_Game", "SkillsFrame", {
  install = function(frame)
    Skins.ScrollBar(frame.ScrollBar)
    Skins.ScrollRows(frame.ScrollBox, SkinSkillRow, false)
    Skins.ColoredProgressBar(frame.SkillDetailFrame.RankBar)
  end,
  manageControls = false,
})

Skins.Register("Blizzard_UIPanels_Game", "PVPRankFrame", {
  install = function(frame)
    Skins.Font(frame.SeasonTimerField)
    Skins.Font(frame.MainInfoFrame.CurrentSeasonField, "nav")
    Skins.Font(frame.MainInfoFrame.CurrentRankField, "header")
    Skins.Font(frame.MainInfoFrame.CurrentRankProgressField)
  end,
  manageControls = false,
})

Skins.Register("Blizzard_Statistics", "StatisticsFrame", {
  install = SkinList,
  manageControls = false,
})
