local _, ns = ...
local Skins = ns.BlizzardSkins

local function RepaintMerchantItems()
  for index = 1, BUYBACK_ITEMS_PER_PAGE do
    ns.Theme.ApplyFont(_G["MerchantItem" .. index].Name, "body")
  end
  ns.Theme.ApplyFont(MerchantBuyBackItem.Name, "body")
end

Skins.Register("Blizzard_UIPanels_Game", "MerchantFrame", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.Hide(MerchantFramePortrait)
    Skins.Hide(MerchantFrameBottomLeftBorder)
    Skins.Hide(BuybackBG)
    for _, pane in ipairs({ MerchantExtraCurrencyInset, MerchantExtraCurrencyBg, MerchantMoneyInset, MerchantMoneyBg }) do
      Skins.Chrome(pane)
      for _, suffix in ipairs({ "Left", "Middle", "Right" }) do Skins.Hide(_G[pane:GetName() .. suffix]) end
    end
    Skins.Dropdown(frame.FilterDropdown)
    Skins.Tab(MerchantFrameTab1)
    Skins.Tab(MerchantFrameTab2)
    for _, entry in ipairs({ { MerchantPrevPageButton, "<" }, { MerchantNextPageButton, ">" } }) do
      for _, region in ipairs({ entry[1]:GetRegions() }) do Skins.Hide(region) end
      Skins.Arrow(entry[1], entry[2])
    end
    Skins.Font(MerchantPageText)
    for index = 1, BUYBACK_ITEMS_PER_PAGE do
      local item = _G["MerchantItem" .. index]
      Skins.Hide(item.SlotTexture)
      Skins.Hide(_G["MerchantItem" .. index .. "NameFrame"])
      Skins.IconButton(item.ItemButton, item.ItemButton.icon, true)
    end
    Skins.Hide(MerchantBuyBackItem.SlotTexture)
    Skins.Hide(MerchantBuyBackItemNameFrame)
    Skins.IconButton(MerchantBuyBackItem.ItemButton, MerchantBuyBackItem.ItemButton.icon, true)
    for _, button in ipairs({ MerchantRepairItemButton, MerchantRepairAllButton, MerchantGuildBankRepairButton, MerchantSellAllJunkButton }) do
      -- Icon and availability are native; only the decorative empty slot is removed.
      for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") and region ~= button.Icon
          and region ~= button:GetHighlightTexture() and region ~= button:GetPushedTexture() then
          Skins.Hide(region)
        end
      end
      Skins.IconButton(button, button.Icon, true)
    end
    RepaintMerchantItems()
    Skins.Hook(_G, "MerchantFrame_UpdateMerchantInfo", RepaintMerchantItems)
    Skins.Hook(_G, "MerchantFrame_UpdateBuybackInfo", RepaintMerchantItems)
  end,
  onShow = RepaintMerchantItems,
})
