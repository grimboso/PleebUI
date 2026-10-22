local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_GuildBankUI", "GuildBankFrame", {
  label = "Guild bank", category = "Bags",
  manageControls = false,
  install = function(frame)
    Skins.StripRegions(frame, { [frame.Portrait] = true })
    Skins.Shell(frame)
    Skins.Icon(frame.Portrait)
    Skins.Hide(frame.Emblem)
    Skins.Texts(frame)
    Skins.EditBox(GuildItemSearchBox)
    Skins.Button(frame.DepositButton)
    Skins.Button(frame.WithdrawButton)
    Skins.StripRegions(frame.MoneyFrameBG)
    Skins.Font(frame.MoneyFrameBG.LimitLabel)
    Skins.Font(frame.MoneyFrameBG.UnlimitedLabel)

    for _, column in ipairs(frame.Columns) do
      Skins.Hide(column.Background)
      for _, button in ipairs(column.Buttons) do Skins.BankItemButton(button) end
    end
    for _, tab in ipairs(frame.BankTabs) do
      for _, region in ipairs({ tab:GetRegions() }) do
        if region:IsObjectType("Texture") then Skins.Hide(region) end
      end
      local button = tab.Button
      Skins.IconButton(button, button.IconTexture)
      local checked = button:GetCheckedTexture()
      checked:SetAllPoints(button)
      Skins.Selection(checked, 0.25)
    end
    Skins.WindowTabs(frame, frame.Tabs)

    Skins.Texts(frame.BuyInfo)
    Skins.Button(frame.BuyInfo.PurchaseButton)
    Skins.ScrollBar(frame.Log.ScrollBar)
    ns.Theme.ApplyFont(frame.Log.MessageFrame, "body")
    Skins.Button(frame.Info.SaveButton)
    Skins.Font(frame.Info.ScrollFrame.EditBox)
    Skins.ScrollBar(frame.Info.ScrollFrame.ScrollBar)
  end,
})
