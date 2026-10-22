local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_Communities", "CommunitiesAvatarPickerDialog", function(frame)
  Skins.Panel(frame)
  Skins.StripRegions(frame.Selector)
  Skins.Button(frame.Selector.OkayButton)
  Skins.Button(frame.Selector.CancelButton)
  Skins.ScrollBar(frame.ScrollBar)
  Skins.ScrollRows(frame.ScrollBox, function(button)
    Skins.IconButton(button, button.Icon)
    Skins.Selection(button.Selected)
  end)
end)
