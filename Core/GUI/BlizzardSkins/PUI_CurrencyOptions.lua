local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_TokenUI", "TokenFramePopup", {
  install = function(frame)
    Skins.Shell(frame)
    Skins.Font(frame.Title, "header")
    Skins.CheckBox(frame.InactiveCheckbox)
    Skins.CheckBox(frame.BackpackCheckbox)
    Skins.Button(frame.CurrencyTransferToggleButton)
  end,
  manageControls = false,
})
