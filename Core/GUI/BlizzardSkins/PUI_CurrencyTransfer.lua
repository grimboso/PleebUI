local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_TokenUI", "CurrencyTransferMenu", {
  install = function(frame)
    Skins.Shell(frame)
    local content = frame.Content
    Skins.Dropdown(content.SourceSelector.Dropdown)
    Skins.Button(content.AmountSelector.MaxQuantityButton)
    Skins.EditBox(content.AmountSelector.InputBox)
    Skins.Button(content.ConfirmButton)
    Skins.Button(content.CancelButton)
    Skins.Font(content.SourceSelector.SourceLabel)
    ns.Theme.ApplyFont(content.SourceSelector.PlayerName, "body")
    Skins.Font(content.AmountSelector.TransferAmountLabel)
    for _, preview in ipairs({ content.SourceBalancePreview, content.PlayerBalancePreview }) do
      Skins.Icon(preview.BalanceInfo.CurrencyIcon)
      ns.Theme.ApplyFont(preview.Label, "body")
      ns.Theme.ApplyFont(preview.BalanceInfo.Amount, "body")
    end
    -- Native fees, warnings, loading and transaction celebration remain intact.
  end,
  manageControls = false,
})
