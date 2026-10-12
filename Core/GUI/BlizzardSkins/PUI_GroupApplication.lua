local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_GroupFinder", "LFGListApplicationDialog", function(dialog)
  Skins.Panel(dialog)
  Skins.Button(dialog.SignUpButton)
  Skins.Button(dialog.CancelButton)
  Skins.StripRegions(dialog.Description)
  Skins.EditBox(dialog.Description.EditBox)
  Skins.Texts(dialog)
  for _, role in ipairs({ "TankButton", "HealerButton", "DamagerButton" }) do
    local button = dialog[role]
    Skins.Surface(button, true)
    Skins.CheckBox(button.CheckButton)
  end
end)
