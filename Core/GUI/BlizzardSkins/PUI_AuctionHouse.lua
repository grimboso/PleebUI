local _, ns = ...
local Skins, Templates = ns.BlizzardSkins, ns.AuctionSkins
local preference

local function RefreshPreference()
  preference:SetChecked(ns.Modules.Quality:GetQuickSetupValue("auctionHouseCurrentExpansionOnly"))
end

local function PaintCategory(button)
  if not Skins.CanStyle() then return end
  Skins.Hide(button.NormalTexture)
  button.SelectedTexture:SetDrawLayer("BACKGROUND", 1)
  button.SelectedTexture:SetAllPoints(button)
  button.SelectedTexture:SetBlendMode("BLEND")
  Skins.Selection(button.SelectedTexture, 0.08)
  button.HighlightTexture:SetDrawLayer("BACKGROUND", 2)
  button.HighlightTexture:SetAllPoints(button)
  button.HighlightTexture:SetBlendMode("BLEND")
  button.HighlightTexture:SetColorTexture(1, 1, 1, 0.06)
  ns.Theme.ApplyFont(button.Text, "body")
  button.Text:SetHeight(0)
  button.Text:SetDrawLayer("OVERLAY")
end

Skins.Register("Blizzard_AuctionHouseUI", "AuctionHouseFrame", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.Chrome(frame.MoneyFrameInset)
    Skins.Chrome(frame.MoneyFrameBorder)
    -- ThinGoldEdgeTemplate's direct textures are only the money surround.
    for _, region in ipairs({ frame.MoneyFrameBorder:GetRegions() }) do
      if region:IsObjectType("Texture") then Skins.Hide(region) end
    end
    Templates.Fonts(frame.MoneyFrameBorder.MoneyFrame)
    local previous
    for _, tab in ipairs({ frame.BuyTab, frame.SellTab, frame.AuctionsTab }) do
      Skins.Tab(tab)
      if previous then
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", previous, "RIGHT", 4, 0)
      end
      previous = tab
    end
    local search = frame.SearchBar
    Skins.EditBox(search.SearchBox)
    Skins.Dropdown(search.FilterButton)
    Skins.Button(search.SearchButton, true)
    -- Favorites star and filter-clear X retain their native action glyphs.
    Skins.Chrome(frame.CategoriesList)
    Skins.ScrollBar(frame.CategoriesList.ScrollBar)
    Skins.Hook(_G, "AuctionHouseFilterButton_SetUp", PaintCategory)
    Skins.ScrollRows(frame.CategoriesList.ScrollBox, PaintCategory, PaintCategory)
    preference = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    preference:SetSize(20, 20)
    preference:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 184, 5)
    preference.Text:SetText("Always use current expansion")
    Skins.CheckBox(preference)
    preference:SetScript("OnClick", function(button)
      ns.Modules.Quality:SetQuickSetupValue("auctionHouseCurrentExpansionOnly", button:GetChecked())
    end)
    preference:SetScript("OnEnter", function(button)
      GameTooltip:SetOwner(button, "ANCHOR_TOP")
      GameTooltip:SetText("Always use current expansion")
      GameTooltip:AddLine("Apply the current-expansion filter when opening the Auction House. This is the same setting as Quality of Life.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    preference:SetScript("OnLeave", GameTooltip_Hide)
    Skins.Hook(ns.Modules.Quality, "RefreshAuctionHousePreference", RefreshPreference)
  end,
  onShow = function(frame)
    RefreshPreference()
    Skins.ScrollRows(frame.CategoriesList.ScrollBox, PaintCategory, PaintCategory)
  end,
})
