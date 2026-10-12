local _, ns = ...
local Skins = ns.BlizzardSkins

Skins.Register("Blizzard_Communities", "CommunitiesFrame.NotificationSettingsDialog", function(frame)
  Skins.Panel(frame)
  Skins.StripRegions(frame.Selector)
  Skins.Texts(frame)
  Skins.Button(frame.Selector.OkayButton)
  Skins.Button(frame.Selector.CancelButton)
  Skins.Dropdown(frame.CommunitiesListDropdown)
end)
