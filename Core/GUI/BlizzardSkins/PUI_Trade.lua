local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_UIPanels_Game", "TradeFrame", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.Hide(TradeRecipientBotLeftCorner)
    Skins.Hide(TradeRecipientLeftBorder)
    Skins.Hide(TradeRecipientBG)
    Skins.Hide(frame.RecipientOverlay.portraitFrame)
    local portrait = frame.RecipientOverlay.portrait
    portrait:ClearAllPoints()
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 172, -6)
    portrait:SetSize(36, 36)
    Skins.Button(TradeFrameTradeButton, true)
    Skins.Button(TradeFrameCancelButton, true)
    Skins.Font(TradeFramePlayerNameText, "header")
    Skins.Font(TradeFrameRecipientNameText, "header")
    Skins.Font(TradeFramePlayerEnchantText)
    Skins.Font(TradeFrameRecipientEnchantText)
    for _, pane in ipairs({ TradeRecipientItemsInset, TradePlayerItemsInset,
      TradePlayerInputMoneyInset, TradePlayerEnchantInset, TradeRecipientEnchantInset,
      TradeRecipientMoneyInset, TradeRecipientMoneyBg }) do
      Skins.Chrome(pane)
    end
    for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
      Skins.Hide(_G["TradeRecipientMoneyBg" .. suffix])
    end
    -- TradePlayerInputMoneyFrame is forbidden. Its fields and handlers stay native.
    -- Native green acceptance highlights and offer-change warnings remain visible.
    for _, side in ipairs({ "TradePlayerItem", "TradeRecipientItem" }) do
      for index = 1, MAX_TRADE_ITEMS do
        local name = side .. index
        local item = _G[name]
        local button = _G[name .. "ItemButton"]
        Skins.Hide(item.SlotTexture)
        Skins.Hide(_G[name .. "NameFrame"])
        Skins.IconButton(button, button.icon, true)
        ns.Theme.ApplyFont(_G[name .. "Name"], "body")
        ns.Theme.ApplyFont(button.Count, "body")
      end
    end
  end,
})
