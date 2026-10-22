local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_GroupFinder", "PVPReadyDialog", function(dialog)
  Skins.Panel(dialog)
  Skins.Apply(dialog, {
    Hide = { "background", "bottomArt", "instanceInfo.underline" },
    Button = { "enterButton", "leaveButton" },
    Font = { "label", "roleDescription", "roleLabel", "instanceInfo.name", "instanceInfo.statusText" },
  })
  ns.Theme.WidgetSkins.CloseButton(PVPReadyDialogCloseButton)
end)
